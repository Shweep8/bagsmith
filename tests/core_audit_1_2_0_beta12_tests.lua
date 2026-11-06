;(function()
	-- 1.2.0: the beta12 audit's findings, asserting the corrected behavior (they fail on beta12)
	package.loaded.mock = nil
	local M = require("mock")
	local DEID = 13262
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
	M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
	for s = 4, 6 do M.put(0, s, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 3 }) end
	-- malformed saved helper data from a hand-edited file, beside a good record
	_G.BagSmithCharDB = { version = 1, firstSeen = {}, deResultsVersion = 3,
		deResults = { ["2:5:w"] = { n = "twenty", mats = {} }, ["2:3:a"] = { n = 4 }, ["2:4:a"] = { n = 6, mats = { [10940] = 12, bad = "x" } }, ["3:5"] = { n = 2, mats = { [11138] = 2 }, seen = { [11138] = 2 } } },
		deNever = { [7005] = true, ["7006"] = true, [7007] = "yes" }, deOfferDeclined = "yes" }
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
	_G.TradeFrame = CreateFrame("Frame", "TradeFrame", UIParent); TradeFrame:Hide()
	_G.MAX_TRADE_ITEMS = 7
	local tradeSlots = {}
	_G.GetTradePlayerItemInfo = function(i) local t = tradeSlots[i]; if t then return t.name, nil, t.count end end
	_G.GetTradePlayerItemLink = function(i) local t = tradeSlots[i]; return t and ("|Hitem:" .. t.id .. ":0|h[" .. t.name .. "]|h") end
	local clock = 1000; _G.GetTime = function() return clock end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE, D = n.Disenchant, n.Drop
	-- ---- nested validation: the good record stays, the malformed ones go, the never list keeps only item IDs
	local log = DE:Log()
	check(log["3:5"] and log["3:5"].n == 2 and log["3:5"].mats[11138] == 2 and log["3:5"].seen[11138] == 2, "a well-formed learned record survives validation")
	check(log["2:5:w"] == nil and log["2:3:a"] == nil and log["2:4:a"] == nil, "records with a string count, no materials table, or a malformed material are dropped")
	check(DE:Never()[7005] == true and DE:Never()["7006"] == nil and DE:Never()[7007] == nil, "the never list keeps only item IDs marked true")
	check(n.cdb.deOfferDeclined == false, "a declined flag that is not a boolean reads as not declined")
	check(n.cdb.deResultsVersion == DE.LOG_VERSION, "the schema version is the current one")
	-- ---- loot accounting: the window is a snapshot (two reads of one window are one), chat adds up, no doubling between them
	DE:Show(); DE:Refresh()
	local b = DE:Button()
	local function entryOf(id) for _, e in ipairs(DE.entries) do if e.itemID == id then return e end end end
	DE:Select(entryOf(7002)); b:GetScript("PreClick")(b)
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", DEID)
	local key = DE.castOpen.key
	local matId = DE:Expectation(DE.castOpen.entry.rec)[1][1]
	lootNow = { { matId, 2 } }
	M.fire("LOOT_READY"); M.fire("LOOT_OPENED")
	check(DE:Log()[key].mats[matId] == 2, "LOOT_READY then LOOT_OPENED on one window of x2 record 2, not 4")
	lootNow = { { matId, 2 }, { matId, 1 } }; M.fire("LOOT_OPENED")
	check(DE:Log()[key].mats[matId] == 3, "a larger snapshot of the same window (3) replaces the earlier 2")
	lootNow = { { matId, 1 } }; M.fire("LOOT_OPENED")
	check(DE:Log()[key].mats[matId] == 3, "a smaller later snapshot (a slot taken) adds nothing")
	M.fire("CHAT_MSG_LOOT", ("You receive loot: |cffffffff|Hitem:%d:0:0:0:0:0:0:0|h[mat]|h|rx1."):format(matId))
	M.fire("CHAT_MSG_LOOT", ("You receive loot: |cffffffff|Hitem:%d:0:0:0:0:0:0:0|h[mat]|h|rx2."):format(matId))
	check(DE:Log()[key].mats[matId] == 3, "chat receipts of 1 and 2 for the same loot do not add to the window's 3")
	M.fire("LOOT_CLOSED")
	DE.frame:Hide()
	-- ---- trade: the clicked stack's placement is told from a pre-click baseline taken on mouse-down
	n:Set("mergeStacks", true); M.runTimers(); n.Window:Show(); M.runTimers(); M.runTimers()
	local function wool() n:Scan(); M.runTimers(); n.Window.main:Refresh(true, "test"); M.runTimers(); for _, bt in ipairs(n.Buttons.all) do if bt:IsShown() and bt.rec and bt.rec.itemID == 2592 and bt.rec.merged then return bt end end end
	M.fire("TRADE_SHOW"); TradeFrame:Show()
	local used = {}
	local realUse = C_Container.UseContainerItem
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot end
	-- a trade already holding the same item; the clicked stack locks but is not placed
	tradeSlots = { { id = 2592, name = "Wool Cloth", count = 20 } }
	local btn = wool()
	btn:GetScript("OnMouseDown")(btn, "RightButton")   -- the baseline: one Wool already there
	check(D.tradeBaseline and D.tradeBaseline.itemID == 2592 and D.tradeBaseline.count == 1, "mouse-down in a trade notes how many of the item the trade already holds")
	M.bags[0][4].locked = true
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 4 }, { bag = 0, slot = 5 }, { bag = 0, slot = 6 } }, name = "Wool Cloth", where = "trade", first = { bag = 0, slot = 4 } })
	for _ = 1, 10 do M.runTimers() end
	check(#used == 0 and (M.log[#M.log] or ""):find("nothing moved", 1, true) and D.active == nil, "a stack of the same item already in the trade is not evidence the clicked stack was placed (" .. tostring(M.log[#M.log]) .. ")")
	-- the clicked stack really placed: the count grew past the baseline
	tradeSlots = { { id = 2592, name = "Wool Cloth", count = 20 } }
	btn = wool(); btn:GetScript("OnMouseDown")(btn, "RightButton")
	tradeSlots[2] = { id = 2592, name = "Wool Cloth", count = 20 }   -- the game placed it
	used = {}
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; tradeSlots[#tradeSlots + 1] = { id = 2592, name = "Wool Cloth", count = 20 }; M.bags[bag][slot].locked = true end
	for i = #M.log, 1, -1 do M.log[i] = nil end
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 4 }, { bag = 0, slot = 5 }, { bag = 0, slot = 6 } }, name = "Wool Cloth", where = "trade", first = { bag = 0, slot = 4 } })
	for _ = 1, 14 do M.runTimers() end
	check(#used == 2 and D.active == nil and #M.log == 0, "with the count grown past the baseline the other two follow (" .. #used .. ")")
	-- no baseline (a path that never saw mouse-down): nothing follows
	for s = 4, 6 do M.bags[0][s].locked = nil end
	tradeSlots = { { id = 2592, name = "Wool Cloth", count = 20 }, { id = 2592, name = "Wool Cloth", count = 20 } }
	D.tradeBaseline = nil
	M.bags[0][4].locked = true
	used = {}
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 4 }, { bag = 0, slot = 5 }, { bag = 0, slot = 6 } }, name = "Wool Cloth", where = "trade", first = { bag = 0, slot = 4 } })
	for _ = 1, 10 do M.runTimers() end
	check(#used == 0 and (M.log[#M.log] or ""):find("could not be confirmed", 1, true), "without a baseline the clicked stack's placement cannot be confirmed and nothing follows")
	-- a stale baseline (from long before) does not count either
	btn = wool(); btn:GetScript("OnMouseDown")(btn, "RightButton"); clock = clock + 30
	used = {}
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 4 }, { bag = 0, slot = 5 }, { bag = 0, slot = 6 } }, name = "Wool Cloth", where = "trade", first = { bag = 0, slot = 4 } })
	for _ = 1, 10 do M.runTimers() end
	check(#used == 0, "a baseline older than the click window does not count")
	-- a follower that vanishes from its slot is ambiguous in a trade: the job stops there
	for s = 4, 6 do if M.bags[0][s] then M.bags[0][s].locked = nil end end
	tradeSlots = { { id = 2592, name = "Wool Cloth", count = 20 } }
	btn = wool(); btn:GetScript("OnMouseDown")(btn, "RightButton")
	tradeSlots[2] = { id = 2592, name = "Wool Cloth", count = 20 }; M.bags[0][4].locked = true
	used = {}
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; M.bags[bag][slot] = nil end   -- the slot empties, the window does not grow
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 4 }, { bag = 0, slot = 5 }, { bag = 0, slot = 6 } }, name = "Wool Cloth", where = "trade", first = { bag = 0, slot = 4 } })
	for _ = 1, 14 do M.runTimers() end
	check(#used == 1 and (M.log[#M.log] or ""):find("could not be found after its click", 1, true) and D.active == nil, "a follower that vanishes without the window growing stops the job with a message (" .. tostring(M.log[#M.log]) .. ")")
	M.fire("TRADE_CLOSED"); TradeFrame:Hide()
	C_Container.UseContainerItem = realUse
	-- ---- Junk: a failed gear-set read means not markable and not sold
	local GS = n.GearSets
	local rec = n.items[1]
	check(n.Junk:Markable(rec) == true, "(control) the boots are markable")
	GS.readFailed = true
	check(n.Junk:Markable(rec) == false, "with the game's sets unreadable nothing is markable")
	GS.readFailed = false
end)()

