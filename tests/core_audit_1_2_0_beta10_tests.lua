;(function()
	-- 1.2.0-beta11: the residuals of the beta10 audit, asserting the corrected behavior (they fail on beta10)
	package.loaded.mock = nil
	local M = require("mock")
	local DEID = 13262
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
	M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
	_G.IsSpellKnown = function(id) return id == DEID end
	_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
	_G.RegisterStateDriver = function() end
	_G.LOOT_ITEM_SELF = "You receive loot: %s."; _G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
	_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."; _G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
	local lootNow = {}
	_G.GetNumLootItems = function() return #lootNow end
	_G.GetLootSlotLink = function(i) return lootNow[i] and ("|Hitem:" .. lootNow[i][1] .. ":0|h[m]|h") end
	_G.GetLootSlotInfo = function(i) return nil, "m", lootNow[i] and lootNow[i][2] or 1 end
	-- item instances: the scanner reads a GUID per slot; the test hands out its own
	local guids = { ["0:1"] = "Item-1-A", ["0:2"] = "Item-2-A" }
	_G.ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
	C_Item.DoesItemExist = function(loc) return M.bags[loc.bag] and M.bags[loc.bag][loc.slot] ~= nil end
	C_Item.GetItemGUID = function(loc) return guids[loc.bag .. ":" .. loc.slot] end
	-- popups, for the prompts residual
	local clicks = {}
	_G.StaticPopup_Show = function(which, arg, _, data) local f = _G["BagSmithTestPopup_" .. which] or CreateFrame("Frame", "BagSmithTestPopup_" .. which, UIParent); f.which = which; f.text = f.text or { text = "", GetText = function(t) return t.text end, SetText = function(t, v) t.text = v end }; f.text:SetText(arg or ""); f.data = data; f:Show(); return f end
	_G.StaticPopup_Visible = function(which) local f = _G["BagSmithTestPopup_" .. which]; if f and f:IsShown() then return "BagSmithTestPopup_" .. which end end
	_G.StaticPopup_OnClick = function(dialog, index) clicks[#clicks + 1] = { dialog.which, index, dialog.text:GetText(), dialog.data }; dialog:Hide() end
	local shift = false; _G.IsShiftKeyDown = function() return shift end
	local clock = 1000; _G.GetTime = function() return clock end
	-- the trade window
	_G.TradeFrame = CreateFrame("Frame", "TradeFrame", UIParent); TradeFrame:Hide()
	_G.MAX_TRADE_ITEMS = 7
	local tradeSlots = {}
	_G.GetTradePlayerItemInfo = function(i) return tradeSlots[i] end
	-- learned results from a beta before the provenance rules
	_G.BagSmithCharDB.deResults = { ["2:5:w"] = { n = 3, mats = { [20725] = 9 } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE, P, D = n.Disenchant, n.Prompts, n.Drop
	-- ---- upgrade hygiene: the old record is dropped once, with a chat line
	local log = DE:Log()
	check(next(log) == nil and n.cdb.deResultsVersion == DE.LOG_VERSION, "learned results from the betas before the provenance rules are cleared once at load")
	local c1 = #M.log; DE:Log()
	check(#M.log == c1, "and only once")
	-- ---- P1 residual: the same item ID in the slot but another instance, or one that is refundable now
	DE:Show(); DE:Refresh()
	local b = DE:Button()
	local function entryOf(id) for _, e in ipairs(DE.entries) do if e.itemID == id then return e end end end
	DE:Select(entryOf(7001))
	check(DE.current.rec.guid == "Item-1-A" and b:GetAttribute("type") == "spell", "(setup) the boots are armed with their instance known")
	guids["0:1"] = "Item-1-B"   -- another copy of the boots now sits in the slot
	b:GetScript("PreClick")(b)
	check(b:GetAttribute("type") == nil and DE.castingEntry == nil and DE.lastDisarm == "that slot holds another copy of the item now", "another copy of the same item in the slot disarms the click (" .. tostring(DE.lastDisarm) .. ")")
	guids["0:1"] = "Item-1-A"; M.runTimers(); DE:Refresh(); DE:Select(entryOf(7001))
	-- the same instance, refundable now (the vendor's return window): the gate the list applies, at click time
	C_Container.GetContainerItemPurchaseInfo = function(bag, slot) if bag == 0 and slot == 1 then return 500, 1, 3600 end return 0, 0, 0 end
	b:GetScript("PreClick")(b)
	check(b:GetAttribute("type") == nil and DE.lastDisarm == "that item is refundable now", "a refundable item disarms the click even with the same instance in the slot (" .. tostring(DE.lastDisarm) .. ")")
	C_Container.GetContainerItemPurchaseInfo = nil; M.runTimers(); DE:Refresh(); DE:Select(entryOf(7001))
	-- the instance cannot be read: fail closed
	local realGUID = C_Item.GetItemGUID; C_Item.GetItemGUID = function() error("boom") end
	b:GetScript("PreClick")(b)
	check(b:GetAttribute("type") == nil and DE.lastDisarm == "that item could not be identified", "an instance that cannot be read fails closed")
	C_Item.GetItemGUID = realGUID; M.runTimers(); DE:Refresh(); DE:Select(entryOf(7001))
	-- gear sets whose membership could not be read: fail closed
	local realAvail, realSetsAt = n.GearSets.Available, n.GearSets.SetsAt
	n.GearSets.Available = function() return true end; n.GearSets.SetsAt = function() return nil, true end
	b:GetScript("PreClick")(b)
	check(b:GetAttribute("type") == nil and DE.lastDisarm == "gear sets could not be checked", "gear sets the game could not report fail closed")
	n.GearSets.Available = realAvail; n.GearSets.SetsAt = realSetsAt; M.runTimers(); DE:Refresh()
	-- ---- loot provenance: only what the bracket can produce; two slots of one material are one count
	DE:Select(entryOf(7002)); b:GetScript("PreClick")(b)
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", DEID)
	local key = DE.castOpen.key
	M.fire("CHAT_MSG_LOOT", "You receive loot: |cffa335ee|Hitem:20725:0:0:0:0:0:0:0|h[Nexus Crystal]|h|rx9.")
	check(DE:Log()[key].mats[20725] == nil, "a material the bracket cannot produce (Nexus Crystals on a low uncommon weapon) is not attributed")
	lootNow = { { 11082, 1 }, { 11082, 2 } }; M.fire("LOOT_OPENED")
	check(DE:Log()[key].mats[11082] == 3 and DE:Log()[key].seen[11082] == 1, "two loot slots of one material count three, once")
	M.fire("LOOT_CLOSED")
	-- ---- prompts: the same frame and words with other data, under Shift at its showing, released before the click
	n:Set("autoConfirm", true)
	n.MarkAction("gear set"); StaticPopup_Show("EQUIP_BIND", "Bind it?", nil, "op-1")
	shift = true; StaticPopup_Show("EQUIP_BIND", "Bind it?", nil, "op-2"); shift = false
	M.runTimers(); M.elapse()
	check(#clicks == 0, "a replacement shown under Shift with the same words is not confirmed by the first box's callback, Shift released or not")
	_G.BagSmithTestPopup_EQUIP_BIND:Hide()
	n.MarkAction("gear set"); StaticPopup_Show("EQUIP_BIND", "Bind it?", nil, "op-3"); M.runTimers(); M.elapse()
	check(#clicks == 1 and clicks[1][4] == "op-3", "(control) an allowed box is confirmed, as its own operation")
	-- two kinds allowed in one batch both confirm (a generation per kind)
	n.MarkAction("item click"); StaticPopup_Show("EQUIP_BIND", "Bind A?", nil, "op-4"); StaticPopup_Show("USE_BIND", "Use B?", nil, "op-5"); M.runTimers(); M.elapse()
	check(#clicks == 3 and clicks[2][1] == "EQUIP_BIND" and clicks[3][1] == "USE_BIND", "two allowed kinds shown in one batch are both confirmed")
	n:Set("autoConfirm", false)
	-- ---- trade: the clicked stack must be in the window, not merely locked
	for s = 1, 3 do M.put(0, s + 2, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 3 }) end
	n:Set("mergeStacks", true); M.runTimers(); n.Window:Show(); M.runTimers(); M.runTimers()
	M.fire("TRADE_SHOW"); TradeFrame:Show(); tradeSlots = {}
	local used = {}
	local realUse = C_Container.UseContainerItem
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot end
	M.bags[0][3].locked = true   -- a generic lock, the window holding nothing
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 3 }, { bag = 0, slot = 4 }, { bag = 0, slot = 5 } }, name = "Wool Cloth", where = "trade", first = { bag = 0, slot = 3 } })
	for _ = 1, 10 do M.runTimers() end
	check(#used == 0 and (M.log[#M.log] or ""):find("nothing moved", 1, true), "a locked first stack with nothing in the trade window moves nothing (" .. tostring(M.log[#M.log]) .. ")")
	M.bags[0][3].locked = nil
	-- ---- a running job and a new gesture: the defined behavior is that the job runs on and a second move is refused;
	-- the mail or trade session ending cancels it with a note
	M.fire("TRADE_CLOSED"); TradeFrame:Hide()
	n.atBank = true
	used = {}
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; M.bags[bag][slot] = nil end
	M.bags[0][3] = nil
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 3 }, { bag = 0, slot = 4 }, { bag = 0, slot = 5 } }, name = "Wool Cloth", first = { bag = 0, slot = 3 }, token = D:NewGesture() })
	M.runTimers(); M.runTimers()   -- one follows
	D:NewGesture()
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 5 } }, name = "Wool Cloth", first = { bag = 0, slot = 5 }, token = D:NewGesture() })
	check((M.log[#M.log] or ""):find("Still moving Wool Cloth", 1, true), "a second move while one runs is refused with a note; the running job is not cancelled by a gesture")
	for _ = 1, 10 do M.runTimers() end
	check(#used == 2 and D.active == nil, "the running job finishes (" .. #used .. " followed)")
	n.atBank = false
	C_Container.UseContainerItem = realUse
	-- the trade session ending cancels a running job with a note
	for s = 3, 5 do M.put(0, s, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 3 }) end
	n:Scan(); M.runTimers()
	M.fire("TRADE_SHOW"); TradeFrame:Show(); tradeSlots = {}
	D:NoteTradeBaseline({ itemID = 2592, name = "Wool Cloth" }); tradeSlots[1] = "Wool Cloth"
	M.bags[0][3].locked = true
	C_Container.UseContainerItem = function(bag, slot) tradeSlots[#tradeSlots + 1] = "Wool Cloth"; M.bags[bag][slot].locked = true end
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 3 }, { bag = 0, slot = 4 }, { bag = 0, slot = 5 } }, name = "Wool Cloth", where = "trade", first = { bag = 0, slot = 3 }, token = D:NewGesture() })
	M.runTimers(); M.runTimers()
	M.fire("TRADE_CLOSED"); TradeFrame:Hide()
	check(D.active == nil and (M.log[#M.log] or ""):find("Stopped moving Wool Cloth: the trade window closed", 1, true), "the trade closing cancels the running job with a note (" .. tostring(M.log[#M.log]) .. ")")
	for s = 3, 5 do if M.bags[0][s] then M.bags[0][s].locked = nil end end
	C_Container.UseContainerItem = realUse
	-- ---- the helper is anchored to the screen beside the bags window, and re-anchored before any drag or resize
	local f = DE.frame
	n.db.dePos = nil; f:Hide(); n.Window:Show(); M.runTimers(); DE:Show()
	check(f.points[1][2] == UIParent and (f.points[1][1] == "TOPRIGHT" or f.points[1][1] == "TOPLEFT") and f.points[1][3] == "BOTTOMLEFT" and f.points[1][5] == n.Window.main.frame:GetTop(), "the helper opens beside the bags window anchored to the screen, never to the bags window")
	f.points[1] = { "TOPRIGHT", n.Window.main.frame, "TOPLEFT", -12, 0 }   -- as a frame anchored to another frame would be
	f:GetScript("OnDragStart")(f)
	check(f.points[1][2] == UIParent and f.points[1][1] == "TOPLEFT", "a drag first puts the frame on the screen at its own spot")
	f.points[1] = { "TOPRIGHT", n.Window.main.frame, "TOPLEFT", -12, 0 }
	f.grip:GetScript("OnMouseDown")(f.grip)
	check(f.points[1][2] == UIParent and f.points[1][1] == "TOPLEFT", "so does a resize")
	f:Hide()
end)()

