;(function()
	-- 1.2.0-beta12: the beta11 audit's findings, asserting the corrected behavior (they fail on beta11)
	local DEID = 13262
	local function deepcopy(t) if type(t) ~= "table" then return t end local o = {}; for k, v in pairs(t) do o[k] = deepcopy(v) end return o end
	local function boot(charDB, extra)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
		M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
		M.put(0, 3, { id = 7005, name = "Plain Tunic", q = 2, count = 1, class = 4, subclass = 1, price = 300, ilvl = 24, equip = "INVTYPE_CHEST" })
		_G.BagSmithCharDB = charDB or { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
		_G.IsSpellKnown = function(id) return id == DEID end
		_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
		_G.RegisterStateDriver = function() end
		_G.LOOT_ITEM_SELF = "You receive loot: %s."; _G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
		_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."; _G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
		if extra then extra(M) end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return M, n
	end
	-- ---- P1: the never list, the learned results and the declined offer survive a reload
	local M, n = boot()
	local DE = n.Disenchant
	DE:Show(); DE:Refresh()
	local function entryOf(id) for _, e in ipairs(DE.entries) do if e.itemID == id then return e end end end
	DE:Select(entryOf(7005)); DE:NeverCurrent()
	DE:OfferAnswer("never")
	for _ = 1, 20 do DE:Record("2:5:w", { { id = 11082, count = 2 } }) end
	check(DE:Never()[7005] == true and n.cdb.deOfferDeclined == true and DE:Log()["2:5:w"].n == 20 and n.cdb.deResultsVersion == DE.LOG_VERSION, "(session one) a never'd item, a declined offer and twenty results on record")
	local saved = deepcopy(_G.BagSmithCharDB)
	-- session two: the saved character database comes back through normal initialization
	M, n = boot(saved)
	DE = n.Disenchant
	check(DE:Never()[7005] == true, "the never list survives a reload")
	check(n.cdb.deOfferDeclined == true and DE:OfferDue() == false, "the declined offer survives a reload")
	local log = DE:Log()["2:5:w"]
	check(log and log.n == 20 and log.mats[11082] == 40 and n.cdb.deResultsVersion == DE.LOG_VERSION, "current-version learned results survive a reload")
	local list, basis = DE:Expected({ quality = 2, ilvl = 33, classID = 2 })
	check(basis == "yours", "and still drive the estimate")
	DE:Show(); DE:Refresh()
	check(entryOf(7005) == nil, "the never'd item is not listed after the reload")
	local b = DE:Button()
	DE:Arm({ bag = 0, slot = 3, itemID = 7005, name = "Plain Tunic", rec = n.items[3] })
	b:GetScript("PreClick")(b)
	check(b:GetAttribute("type") == nil and DE.lastDisarm == "that item is on your DE Exclusion List", "and a forced arm of it is disarmed by the live check after the reload")
	DE.frame:Hide()
	-- a legacy record (no schema version) is cleared once at load, with the chat line
	M, n = boot({ version = 1, firstSeen = {}, deResults = { ["2:5:w"] = { n = 3, mats = { [20725] = 9 } } }, deNever = { [7005] = true } })
	DE = n.Disenchant
	local told = false; for _, l in ipairs(M.log) do if l:find("learned results from the beta builds were cleared", 1, true) then told = true end end
	check(next(DE:Log()) == nil and n.cdb.deResultsVersion == DE.LOG_VERSION and told, "a legacy record is cleared once at startup, and said in chat")
	check(DE:Never()[7005] == true, "while the never list from that beta is kept")
	-- ---- conditional robustness: a record without an instance, where the client gives instances
	M, n = boot(nil, function(M)
		_G.ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { item = M.bags[bag] and M.bags[bag][slot] } end }
	end)
	DE = n.Disenchant; DE:Show(); DE:Refresh(); b = DE:Button()
	DE:Select(entryOf(7001))
	DE.current.rec.guid = nil   -- the scan could not read it at the time
	b:GetScript("PreClick")(b)
	check(b:GetAttribute("type") == nil and DE.lastDisarm == "that item could not be identified", "an armed record with no instance, where the client gives instances, is not trusted")
	M.runTimers(); n:Scan(); M.runTimers(); DE:Refresh(); DE:Select(entryOf(7001))
	-- a refund read that throws is unknown, and unknown is a no
	C_Container.GetContainerItemPurchaseInfo = function() error("boom") end
	b:GetScript("PreClick")(b)
	check(b:GetAttribute("type") == nil and DE.lastDisarm == "whether that item is refundable could not be checked", "a refund read that throws disarms (" .. tostring(DE.lastDisarm) .. ")")
	C_Container.GetContainerItemPurchaseInfo = nil; M.runTimers(); DE:Refresh(); DE:Select(entryOf(7001))
	-- gear sets answering with malformed data are a failed read
	local GS = n.GearSets
	local realAvail = GS.Available; GS.Available = function() return true end
	_G.C_EquipmentSet = { GetEquipmentSetIDs = function() return nil end }
	GS:Rebuild()
	check(GS.readFailed == true, "equipment-set IDs that are not a table count as a failed read")
	_G.C_EquipmentSet = { GetEquipmentSetIDs = function() return { 1 } end, GetEquipmentSetInfo = function() return nil end }
	GS:Rebuild()
	check(GS.readFailed == true, "a set whose info is nil counts as a failed read")
	local _, unreadable = GS:SetsAt(0, 1)
	check(unreadable == true, "and SetsAt says so")
	b:GetScript("PreClick")(b)
	check(b:GetAttribute("type") == nil and DE.lastDisarm == "gear sets could not be checked", "which disarms the click")
	_G.C_EquipmentSet = nil; GS.Available = realAvail; GS:Rebuild(); M.runTimers(); DE:Refresh()
	-- ---- loot: chat receipts add up; chat and window are two views of one loot
	DE:Select(entryOf(7002)); b:GetScript("PreClick")(b)
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", DEID)
	local key = DE.castOpen.key
	local matId = DE:Expectation(DE.castOpen.entry.rec)[1][1]
	local line = function(cnt) return ("You receive loot: |cffffffff|Hitem:%d:0:0:0:0:0:0:0|h[mat]|h|rx%d."):format(matId, cnt) end
	M.fire("CHAT_MSG_LOOT", line(1)); M.fire("CHAT_MSG_LOOT", line(2))
	check(DE:Log()[key].mats[matId] == 3, "two chat receipts of 1 and 2 record 3")
	local lootNow = { { matId, 3 } }
	_G.GetNumLootItems = function() return #lootNow end
	_G.GetLootSlotLink = function(i) return lootNow[i] and ("|Hitem:" .. lootNow[i][1] .. ":0|h[m]|h") end
	_G.GetLootSlotInfo = function(i) return nil, "m", lootNow[i] and lootNow[i][2] or 1 end
	M.fire("LOOT_OPENED")
	check(DE:Log()[key].mats[matId] == 3, "the loot window then showing the same three records nothing more")
	M.fire("LOOT_CLOSED")
	DE.frame:Hide()
	-- ---- P3: the bags window's scale is applied to the opening position
	local main = n.Window.main.frame
	n.Window:Show(); M.runTimers()
	main.GetLeft = function() return 1200 end; main.GetTop = function() return 1000 end; main.GetRight = function() return 1800 end
	main.GetEffectiveScale = function() return 0.8 end
	n.db.dePos = nil; DE:Show()
	local f = DE.frame
	check(f.points[1][2] == UIParent and f.points[1][5] == 800 and (f.points[1][4] == 1200 * 0.8 - 12 or f.points[1][4] == 1800 * 0.8 + 12), "a bags window at scale 0.8 places the helper by its scaled edges (" .. tostring(f.points[1][4]) .. ", " .. tostring(f.points[1][5]) .. ")")
	f:Hide(); main.GetEffectiveScale = nil; main.GetLeft = nil; main.GetTop = nil; main.GetRight = nil
	-- ---- P2: trade evidence is the item itself in the window; a vanished first source ends the job cleanly
	M, n = boot(nil, function(M)
		_G.TradeFrame = CreateFrame("Frame", "TradeFrame", UIParent); TradeFrame:Hide()
		_G.MAX_TRADE_ITEMS = 7
	end)
	local D = n.Drop
	for s = 4, 6 do M.put(0, s, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 3 }) end
	n:Scan(); M.runTimers()
	local tradeSlots = {}
	_G.GetTradePlayerItemInfo = function(i) local t = tradeSlots[i]; if t then return t.name, nil, t.count end end
	_G.GetTradePlayerItemLink = function(i) local t = tradeSlots[i]; return t and ("|Hitem:" .. t.id .. ":0|h[" .. t.name .. "]|h") end
	M.fire("TRADE_SHOW"); TradeFrame:Show()
	local used = {}
	local realUse = C_Container.UseContainerItem
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot end
	-- a trade already holding an unrelated item; the clicked stack locked but not in the window
	tradeSlots = { { id = 2589, name = "Linen Cloth", count = 5 } }
	M.bags[0][4].locked = true
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 4 }, { bag = 0, slot = 5 }, { bag = 0, slot = 6 } }, name = "Wool Cloth", where = "trade", first = { bag = 0, slot = 4 } })
	for _ = 1, 10 do M.runTimers() end
	check(#used == 0 and (M.log[#M.log] or ""):find("nothing moved", 1, true) and D.active == nil, "an unrelated item already in the trade is not evidence the clicked stack was placed (" .. tostring(M.log[#M.log]) .. ")")
	-- the clicked stack really in the window: the rest follow, each counted only when the window gains that item
	tradeSlots = { { id = 2589, name = "Linen Cloth", count = 5 } }
	D:NoteTradeBaseline({ itemID = 2592, name = "Wool Cloth" })   -- mouse-down: no Wool in the trade yet
	tradeSlots[2] = { id = 2592, name = "Wool Cloth", count = 20 }   -- the game placed the clicked stack
	for i = #M.log, 1, -1 do M.log[i] = nil end
	used = {}
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; tradeSlots[#tradeSlots + 1] = { id = 2592, name = "Wool Cloth", count = 20 }; M.bags[bag][slot].locked = true end
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 4 }, { bag = 0, slot = 5 }, { bag = 0, slot = 6 } }, name = "Wool Cloth", where = "trade", first = { bag = 0, slot = 4 } })
	for _ = 1, 14 do M.runTimers() end
	check(#used == 2 and D.active == nil and not (M.log[#M.log] or ""):find("Moved %d of"), "with the clicked stack in the window the other two follow, each landing as that item (" .. #used .. ")")
	-- a follower that locks while the window gains an unrelated item does not count
	for s = 4, 6 do M.bags[0][s].locked = nil end
	tradeSlots = {}
	D:NoteTradeBaseline({ itemID = 2592, name = "Wool Cloth" })
	tradeSlots[1] = { id = 2592, name = "Wool Cloth", count = 20 }
	M.bags[0][4].locked = true
	used = {}
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; tradeSlots[#tradeSlots + 1] = { id = 2589, name = "Linen Cloth", count = 1 }; M.bags[bag][slot].locked = true end
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 4 }, { bag = 0, slot = 5 }, { bag = 0, slot = 6 } }, name = "Wool Cloth", where = "trade", first = { bag = 0, slot = 4 } })
	for _ = 1, 14 do M.runTimers() end
	check(#used == 1 and (M.log[#M.log] or ""):find("Moved 1 of 3 stacks", 1, true) and D.active == nil, "a follower whose lock comes with some other item entering the window is not counted, and the job stops (" .. tostring(M.log[#M.log]) .. ")")
	-- the clicked stack vanishing before the proof: no error, a clean end, and the next job is accepted
	for s = 4, 6 do if M.bags[0][s] then M.bags[0][s].locked = nil end end
	tradeSlots = {}
	D:NoteTradeBaseline({ itemID = 2592, name = "Wool Cloth" }); tradeSlots[1] = { id = 2592, name = "Wool Cloth", count = 20 }
	used = {}
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot end
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 4 }, { bag = 0, slot = 5 }, { bag = 0, slot = 6 } }, name = "Wool Cloth", where = "trade", first = { bag = 0, slot = 4 } })
	M.bags[0][4] = nil
	local okRun = pcall(function() for _ = 1, 10 do M.runTimers() end end)
	check(okRun and #used == 0 and D.active == nil and (M.log[#M.log] or ""):find("could not be found", 1, true), "the clicked stack vanishing before the proof ends the job cleanly, with no error (" .. tostring(M.log[#M.log]) .. ")")
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 5 }, { bag = 0, slot = 6 } }, name = "Wool Cloth", where = "trade", first = { bag = 0, slot = 5 } })
	check(not (M.log[#M.log] or ""):find("Still moving", 1, true), "and a following job is not refused as still moving")
	M.fire("TRADE_CLOSED"); TradeFrame:Hide()
	C_Container.UseContainerItem = realUse
end)()

