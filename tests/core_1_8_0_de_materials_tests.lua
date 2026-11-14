;(function()
	-- ======== 1.8.0: the Disenchant Helper learns materials it doesn't know, and items past its table ========
	-- A material the cast's own loot window holds is the cast's, known or not: it's recorded and learned (by item ID,
	-- per character). The loot chat counts the shipped materials and the learned ones, and nothing else. Gear past the
	-- shipped table gets a bracket key of its own ("f:..."), so its casts are recorded and your own results take over.
	local DEID = 13262
	local NEW, NEW2, CLOTH = 90001, 90002, 2589   -- two materials a server added (not in the table), and Linen Cloth
	local function deepcopy(t) if type(t) ~= "table" then return t end local o = {}; for k, v in pairs(t) do o[k] = deepcopy(v) end return o end
	local lootNow, clock = {}, 1000
	local function boot(charDB, extra)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
		M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
		-- past the shipped table: an uncommon helm at 112 (the table's uncommon brackets end at 99)
		M.put(0, 3, { id = 7010, name = "Starforged Helm", q = 2, count = 1, class = 4, subclass = 4, price = 900, ilvl = 112, equip = "INVTYPE_HEAD" })
		_G.BagSmithCharDB = charDB or { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
		_G.IsSpellKnown = function(id) return id == DEID end
		_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
		_G.RegisterStateDriver = function() end
		_G.UnregisterStateDriver = function() end
		_G.ITEM_QUALITY_COLORS = { [1] = { r = 1, g = 1, b = 1 }, [2] = { r = 0.12, g = 1, b = 0 }, [3] = { r = 0, g = 0.44, b = 0.87 }, [4] = { r = 0.64, g = 0.21, b = 0.93 } }
		_G.LOOT_ITEM_SELF = "You receive loot: %s."; _G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
		_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."; _G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
		lootNow = {}
		_G.GetNumLootItems = function() return #lootNow end
		_G.GetLootSlotLink = function(i) return lootNow[i] and ("|Hitem:" .. lootNow[i][1] .. ":0|h[m]|h") end
		_G.GetLootSlotInfo = function(i) return nil, "m", lootNow[i] and lootNow[i][2] or 1 end
		_G.GetLootSlotType, _G.GetLootSourceInfo, _G.IsFishingLoot, _G.LOOT_SLOT_MONEY = nil, nil, nil, nil
		_G.GetItemInfoInstant = nil
		_G.Auctionator = nil
		clock = 1000; _G.GetTime = function() return clock end
		GameTooltip.ClearLines = GameTooltip.ClearLines or function(self) self.lines = {} end   -- (the mock's tooltip has none)
		if extra then extra(M) end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return M, n
	end
	local function chat(id, cnt) return ("You receive loot: |cffffffff|Hitem:%d:0:0:0:0:0:0:0|h[mat]|h|rx%d."):format(id, cnt or 1) end
	local function entryOf(DE, id) for _, e in ipairs(DE.entries or {}) do if e.itemID == id then return e end end end
	-- one cast on an item, through the secure button's PreClick and the game's success event; the item stays (the mock)
	local function cast(M, DE, id)
		clock = clock + 10
		DE:Refresh(); DE:Select(entryOf(DE, id))
		local b = DE:Button(); b:GetScript("PreClick")(b)
		M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", DEID)
		return DE.castOpen
	end

	-- ---- the fallback key: gear past the table, by quality and a band of 5 item levels
	local M, n = boot()
	local DE = n.Disenchant
	check(DE:FallbackKey({ quality = 2, ilvl = 112, classID = 4 }) == "f:2:111:a" and DE:FallbackKey({ quality = 2, ilvl = 115, classID = 2 }) == "f:2:111:w",
		"uncommon past the table: f:2, the band's first item level (111 to 115), armor and weapons apart")
	check(DE:FallbackKey({ quality = 3, ilvl = 120, classID = 4 }) == "f:3:116" and DE:FallbackKey({ quality = 4, ilvl = 101, classID = 2 }) == "f:4:101",
		"rare and epic: f:3 and f:4 with the band")
	check(DE:FallbackKey({ quality = 5, ilvl = 120, classID = 4 }) == nil and DE:FallbackKey({ quality = 1, ilvl = 120, classID = 4 }) == nil
		and DE:FallbackKey({ quality = 2, ilvl = 120, classID = 0 }) == nil and DE:FallbackKey(nil) == nil,
		"no fallback key for legendary or common items, for anything but weapons and armor, or for nothing")
	local list, key = DE:Expectation({ quality = 2, ilvl = 112, classID = 4 })
	check(list == nil and key == "f:2:111:a", "no table for the helm at 112: no list, the fallback key")
	list, key = DE:Expectation({ quality = 3, ilvl = 120, classID = 4 })
	check(list == nil and key == "f:3:116", "a rare past the table's item levels: the fallback key")
	check(select(2, DE:Expectation({ quality = 2, ilvl = 23, classID = 4 })) == "2:3:a" and select(2, DE:Expectation({ quality = 2, ilvl = 70, classID = 4 })) == "2:11:a"
		and select(2, DE:Expectation({ quality = 4, ilvl = 112, classID = 2 })) == "4:crystal",
		"(control) items the table covers keep their keys")

	-- ---- an unknown material in the cast's own loot window is recorded and learned
	DE:Show(); DE:Refresh()
	local c = cast(M, DE, 7001)
	check(c and c.key == "2:3:a" and c.allowed and not c.allowed[NEW], "(setup) a cast on the boots, under 2:3:a; the table doesn't predict the new material")
	lootNow = { { 10940, 3 }, { NEW, 1 } }
	M.fire("LOOT_READY"); M.fire("LOOT_OPENED")
	local log = DE:Log()["2:3:a"]
	check(log.mats[10940] == 3 and log.mats[NEW] == 1 and log.seen[NEW] == 1, "the window's new material is recorded with the cast, once across LOOT_READY and LOOT_OPENED")
	check(DE:LearnedMaterials()[NEW] == true and n.cdb.deMaterials[NEW] == true and not DE:LearnedMaterials()[10940], "and learned, by item ID, per character (a shipped one isn't stored)")
	check(DE.session.mats[NEW] == 1, "the sitting's haul counts it too")
	check(DE:SessionSummary():find("item 90001 x1", 1, true), "a material the game hasn't named yet reads as its item number")
	M.fire("LOOT_CLOSED")

	-- ---- the same ID later by chat is counted; an unrelated pickup by chat is still ignored
	c = cast(M, DE, 7001)
	M.fire("CHAT_MSG_LOOT", chat(NEW, 2))
	check(DE:Log()["2:3:a"].mats[NEW] == 3 and DE:Log()["2:3:a"].seen[NEW] == 2, "the learned material arriving by loot chat is counted for the next cast")
	M.fire("CHAT_MSG_LOOT", chat(CLOTH, 4))
	check(DE:Log()["2:3:a"].mats[CLOTH] == nil and not DE:LearnedMaterials()[CLOTH] and (DE.session.mats[CLOTH] or 0) == 0, "Linen Cloth by chat in the same window is not the cast's")
	M.fire("CHAT_MSG_LOOT", chat(20725, 9))
	check(DE:Log()["2:3:a"].mats[20725] == nil, "nor is a shipped material the table puts in other brackets (Nexus Crystals on low boots), as before")
	M.fire("CHAT_MSG_LOOT", chat(NEW2, 1))
	check(DE:Log()["2:3:a"].mats[NEW2] == nil, "nor a material nobody has learned yet")
	M.fire("LOOT_CLOSED")
	-- a learned material is counted by chat in another bracket too (the table can't predict it anywhere)
	c = cast(M, DE, 7002)
	M.fire("CHAT_MSG_LOOT", chat(NEW, 1))
	check(c.key == "2:5:w" and DE:Log()["2:5:w"].mats[NEW] == 1, "a learned material by chat on the dagger (2:5:w) counts as well")
	M.fire("LOOT_CLOSED")
	-- a shipped material the window showed in an unexpected bracket: the chat counts it there from then on
	c = cast(M, DE, 7002)
	lootNow = { { 11178, 1 } }   -- Large Radiant Shard: the table puts it at item levels 46 to 50, not 33
	M.fire("LOOT_OPENED")
	check(DE:Log()["2:5:w"].mats[11178] == 1, "a shipped material the table didn't predict for the bracket, in the cast's own window, counts")
	check(not DE:LearnedMaterials()[11178], "(a shipped material is never stored as learned)")
	M.fire("LOOT_CLOSED")
	c = cast(M, DE, 7002)
	M.fire("CHAT_MSG_LOOT", chat(11178, 1))
	check(DE:Log()["2:5:w"].mats[11178] == 2, "and by chat afterward in that bracket, since its own results have had it")
	M.fire("LOOT_CLOSED")

	-- ---- a window the game says can't be the disenchant's: nothing new is learned from it
	local function windowCase(label, setup)
		c = cast(M, DE, 7001)
		local before = DE:Log()["2:3:a"].mats[10940] or 0
		lootNow = { { 10940, 2 }, { NEW2, 1 } }
		setup()
		M.fire("LOOT_OPENED")
		check(DE:Log()["2:3:a"].mats[NEW2] == nil and not DE:LearnedMaterials()[NEW2], label .. ": the unknown item is not recorded or learned")
		check(DE:Log()["2:3:a"].mats[10940] == before + 2, label .. ": a shipped material the bracket gives still counts, as before")
		M.fire("LOOT_CLOSED")
		_G.GetLootSlotType, _G.GetLootSourceInfo, _G.IsFishingLoot, _G.LOOT_SLOT_MONEY = nil, nil, nil, nil
		C_Item.GetItemInfoInstant = M.realInstant
	end
	M.realInstant = C_Item.GetItemInfoInstant
	windowCase("fishing loot", function() _G.IsFishingLoot = function() return true end end)
	windowCase("a window with coin", function()
		_G.LOOT_SLOT_MONEY = 2; lootNow[3] = { 0, 0 }
		_G.GetLootSlotType = function(i) return i == 3 and 2 or 1 end
		_G.GetLootSlotLink = function(i) return i < 3 and lootNow[i] and ("|Hitem:" .. lootNow[i][1] .. ":0|h[m]|h") or nil end
	end)
	_G.GetLootSlotLink = function(i) return lootNow[i] and ("|Hitem:" .. lootNow[i][1] .. ":0|h[m]|h") end
	windowCase("loot from a creature", function() _G.GetLootSourceInfo = function() return "Creature-0-1-2-3-4-5" end end)
	windowCase("a window holding armor", function()
		lootNow[3] = { 7777, 1 }
		C_Item.GetItemInfoInstant = function(id) if id == 7777 then return id, "Armor", "Cloth", "INVTYPE_CHEST", 1, 4, 1 end return M.realInstant(id) end
	end)
	-- the client answering oddly is no reason to doubt the cast's own window: an item source, or reads that throw
	c = cast(M, DE, 7001)
	lootNow = { { NEW2, 2 } }
	_G.GetLootSourceInfo = function() return "Item-0-1-2" end
	_G.IsFishingLoot = function() error("no fishing here") end
	_G.LOOT_SLOT_MONEY = 2; _G.GetLootSlotType = function() error("no slot types") end
	C_Item.GetItemInfoInstant = function() error("no instant info") end
	local ok, err = pcall(M.fire, "LOOT_OPENED")
	_G.GetLootSlotType, _G.GetLootSourceInfo, _G.IsFishingLoot, _G.LOOT_SLOT_MONEY = nil, nil, nil, nil
	C_Item.GetItemInfoInstant = M.realInstant
	check(ok and DE:Log()["2:3:a"].mats[NEW2] == 2 and DE:LearnedMaterials()[NEW2] == true, "loot from an item, with the other reads throwing: counted and learned, no error (" .. tostring(err) .. ")")
	M.fire("LOOT_CLOSED")

	-- ---- an enchanting reagent by the game's own item class counts by chat; without the class names, it doesn't
	local REAGENT = 90007
	C_Item.GetItemInfoInstant = function(id) if id == REAGENT then return id, "Trade Goods", "Enchanting", "", 1, 7, 12 end return M.realInstant(id) end
	c = cast(M, DE, 7001)
	M.fire("CHAT_MSG_LOOT", chat(REAGENT, 1))
	check(DE:Log()["2:3:a"].mats[REAGENT] == nil, "a client without the item class names: an unknown reagent by chat is not counted (unknown is a no)")
	_G.Enum.ItemClass = { Tradegoods = 7 }; _G.Enum.ItemTradeGoodsSubclass = { Enchanting = 12 }
	M.fire("CHAT_MSG_LOOT", chat(REAGENT, 1))
	check(DE:Log()["2:3:a"].mats[REAGENT] == 1 and not DE:LearnedMaterials()[REAGENT], "with them, the game's enchanting reagent by chat is counted (and not stored: only the cast's window teaches)")
	_G.Enum.ItemTradeGoodsSubclass = { Enchanting = 99 }
	M.fire("CHAT_MSG_LOOT", chat(CLOTH, 1))
	check(DE:Log()["2:3:a"].mats[CLOTH] == nil, "(a trade good of another kind is not)")
	M.fire("LOOT_CLOSED")
	_G.Enum.ItemClass, _G.Enum.ItemTradeGoodsSubclass = nil, nil
	C_Item.GetItemInfoInstant = M.realInstant

	-- ---- an item with no table: recorded under its fallback key, "still learning", then your own results
	local savedLog = deepcopy(DE:Log())
	c = cast(M, DE, 7010)
	check(c and c.key == "f:2:111:a" and c.allowed == nil and DE:Log()["f:2:111:a"].n == 1, "a cast on the helm at 112 is counted under f:2:111:a")
	lootNow = { { NEW2, 2 }, { 16204, 1 } }
	M.fire("LOOT_OPENED")
	check(DE:Log()["f:2:111:a"].mats[NEW2] == 2 and DE:Log()["f:2:111:a"].mats[16204] == 1, "its loot window's materials are recorded there")
	M.fire("LOOT_CLOSED")
	for _ = 1, 2 do cast(M, DE, 7010); lootNow = { { NEW2, 2 } }; M.fire("LOOT_OPENED"); M.fire("LOOT_CLOSED") end
	local exp, basis, cnt, ekey = DE:Expected(entryOf(DE, 7010).rec)
	check(exp == nil and basis == "learning" and cnt == 3 and ekey == "f:2:111:a", "three casts in: still learning, no estimate")
	local mv, why = DE:MatsValue(entryOf(DE, 7010).rec)
	check(mv == nil and why == "no-table", "no materials value while learning, as with no table")
	DE:Refresh(); DE:Select(entryOf(DE, 7010))
	local f = DE.frame
	check(f.cur.likely.text == "Still learning: 3 of 20 disenchants in this range.", "the panel says it's still learning, not that there's no table (" .. tostring(f.cur.likely.text) .. ")")
	check(f.cur.basis.text == "Learning from your results" and f.cur.info:IsShown(), "the basis line says it's learning from your results, with its (i)")
	local shown = 0; for _, r in ipairs(f.cur.likelyRows or {}) do if r:IsShown() then shown = shown + 1 end end
	check(shown == 0, "no result rows yet")
	check(entryOf(DE, 7010).mats == nil and entryOf(DE, 7010).verdict == "call", "no Auctionator: the helm's verdict is Your call, as for any item")
	-- with prices: no estimate means no recommendation to disenchant, as with no table
	_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function() return 100 end, GetAuctionPriceByItemID = function() return 100 end, GetAuctionAgeByItemLink = function() return nil end } } }
	n:Fire("PRICE_SOURCE_CHANGED"); DE:Refresh()
	local helm = entryOf(DE, 7010)
	check(helm.mats == nil and helm.verdict == "unknown" and DE:ValueText(helm.mats, "mats", helm) == "-", "with prices, no estimate yet: no materials value, no Disenchant verdict (as with no table)")
	_G.Auctionator = nil; n:Fire("PRICE_SOURCE_CHANGED")
	-- the row's tooltip says so too
	local r = f.rows[1]; for _, row in ipairs(f.rows) do if row.entry and row.entry.itemID == 7010 then r = row end end
	DE:RowTip(r)
	local tipText = table.concat(GameTooltip.lines or {}, "|")
	check(tipText:find("Likely results (learning from your results):", 1, true) and tipText:find("Still learning: 3 of 20", 1, true), "the row's tooltip says it's still learning")
	-- seventeen more casts make twenty: your own results take over
	for _ = 1, 17 do cast(M, DE, 7010); lootNow = { { NEW2, 2 } }; M.fire("LOOT_OPENED"); M.fire("LOOT_CLOSED") end
	exp, basis, cnt = DE:Expected(entryOf(DE, 7010).rec)
	check(basis == "yours" and cnt == 20 and exp[1][1] == NEW2 and math.abs(exp[1][2] - 2) < 1e-9 and exp[1].seen == 20, "twenty casts: your own results (2 of the new material per cast, in 20 of 20)")
	DE:Refresh(); DE:Select(entryOf(DE, 7010))
	check(f.cur.likely.text == "" and f.cur.basis.text == "From 20 of your results", "the panel shows your results now")
	local rows = {}; for _, row in ipairs(f.cur.likelyRows or {}) do if row:IsShown() then rows[row.id] = row end end
	check(rows[NEW2] and rows[NEW2].rest.text == ": 2.0 per cast, in 20 of 20" and rows[16204] and rows[16204].rest.text == ": 0.1 per cast, in 1 of 20", "one row per material from your results")
	-- rarity: the game's quality when it has the item, BagSmith's table for a shipped one, else common
	check(rows[NEW2].c[1] == 1 and rows[NEW2].c[2] == 1 and rows[NEW2].c[3] == 1 and rows[NEW2].name.text == "item 90002", "a new material the game hasn't loaded: common white, its item number for a name")
	check(rows[16204].c[1] == 1 and rows[16204].c[3] == 1, "(Illusion Dust: common, from BagSmith's table)")
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(link) local id = tonumber(tostring(link):match("item:(%d+)")) or link; if id == NEW2 then return "Starlight Dust", "item:90002", 3 end return realInfo(link) end
	DE:Paint()
	rows = {}; for _, row in ipairs(f.cur.likelyRows or {}) do if row:IsShown() then rows[row.id] = row end end
	check(rows[NEW2].name.text == "Starlight Dust" and rows[NEW2].c[3] == 0.87, "once the game has it: its name and its own quality's color (rare blue)")
	-- item info that throws: no error, the item number and common white
	C_Item.GetItemInfo = function() error("item info broke") end
	ok, err = pcall(function() DE:Paint() end)
	rows = {}; for _, row in ipairs(f.cur.likelyRows or {}) do if row:IsShown() then rows[row.id] = row end end
	check(ok and rows[NEW2] and rows[NEW2].name.text == "item 90002" and rows[NEW2].c[1] == 1, "item info that throws: no error, the item number in common white (" .. tostring(err) .. ")")
	C_Item.GetItemInfo = realInfo
	-- with prices, your results drive the value and verdict like any bracket's
	_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function(_, link) local id = tonumber(link:match("item:(%d+)")); return id == NEW2 and 5000 or id == 16204 and 100 or id == 7010 and 1000 or nil end,
		GetAuctionPriceByItemID = function(_, id) return id == NEW2 and 5000 or id == 16204 and 100 or id == 7010 and 1000 or nil end, GetAuctionAgeByItemLink = function() return nil end } } }
	n:Fire("PRICE_SOURCE_CHANGED"); DE:Refresh()
	helm = entryOf(DE, 7010)
	check(helm.mats == math.floor(2 * 5000 + 0.05 * 100 + 0.5) and helm.basis == "yours" and helm.verdict == "de", "with prices, your results value the helm's materials, and Disenchant wins")
	_G.Auctionator = nil; n:Fire("PRICE_SOURCE_CHANGED")
	check(DE:Log()["2:3:a"].n == savedLog["2:3:a"].n, "(the helm's casts left the boots' bracket alone)")
	DE.frame:Hide()

	-- ---- what was learned survives a reload, and the chat counts it from the first cast
	local saved = deepcopy(_G.BagSmithCharDB)
	M, n = boot(saved)
	DE = n.Disenchant
	check(DE:LearnedMaterials()[NEW] == true and DE:LearnedMaterials()[NEW2] == true and DE:Log()["f:2:111:a"].n == 20, "learned materials and the fallback key's results survive a reload")
	DE:Show(); DE:Refresh()
	c = cast(M, DE, 7002)
	M.fire("CHAT_MSG_LOOT", chat(NEW2, 1))
	check(DE:Log()["2:5:w"].mats[NEW2] == 1, "after the reload, a learned material by chat counts at once")
	M.fire("LOOT_CLOSED")
	-- forgetting the learned results keeps the learned materials (they say what a material is)
	DE:ResetLearned()
	check(next(DE:Log()) == nil and DE:LearnedMaterials()[NEW] == true, "Reset forgets the results and keeps the learned materials")
	DE.frame:Hide()

	-- ---- old saved results (before 1.8.0: no learned materials) still load as they were
	M, n = boot({ version = 1, firstSeen = {}, deResultsVersion = 3,
		deResults = { ["2:3:a"] = { n = 20, mats = { [10940] = 40 }, seen = { [10940] = 20 } }, ["3:5"] = { n = 2, mats = { [11177] = 2 }, seen = { [11177] = 2 } } } })
	DE = n.Disenchant
	local told = false; for _, l in ipairs(M.log) do if l:find("were cleared", 1, true) then told = true end end
	check(not told and DE:Log()["2:3:a"].n == 20 and DE:Log()["2:3:a"].mats[10940] == 40 and DE:Log()["3:5"].n == 2 and n.cdb.deResultsVersion == DE.LOG_VERSION and DE.LOG_VERSION == 3,
		"results saved before 1.8.0 load untouched, with no message (the schema version is unchanged)")
	check(type(n.cdb.deMaterials) == "table" and next(n.cdb.deMaterials) == nil, "and the learned materials start empty")
	exp, basis = DE:Expected({ quality = 2, ilvl = 23, classID = 4 })
	check(basis == "yours" and exp[1][1] == 10940, "and still drive their bracket's estimate")
	-- malformed learned materials from a hand-edited file: only whole item IDs marked true stay
	M, n = boot({ version = 1, firstSeen = {}, deResultsVersion = 3, deResults = {},
		deMaterials = { [NEW] = true, ["90003"] = true, [90004] = "yes", [-5] = true, [1.5] = true } })
	DE = n.Disenchant
	check(DE:LearnedMaterials()[NEW] == true and DE:LearnedMaterials()["90003"] == nil and DE:LearnedMaterials()[90004] == nil
		and DE:LearnedMaterials()[-5] == nil and DE:LearnedMaterials()[1.5] == nil, "saved learned materials keep only whole item IDs marked true")
	M, n = boot({ version = 1, firstSeen = {}, deMaterials = "nonsense" })
	check(type(n.cdb.deMaterials) == "table" and next(n.cdb.deMaterials) == nil, "learned materials that are not a table start empty")

	-- ---- no item info at all: no errors anywhere
	M, n = boot()
	DE = n.Disenchant
	DE:Show(); DE:Refresh()   -- (the bags are read with the mock's item info; then it goes away)
	C_Item.GetItemInfoInstant = nil; C_Item.RequestLoadItemDataByID = nil
	ok, err = pcall(function()
		c = cast(M, DE, 7001)
		lootNow = { { NEW, 1 } }; M.fire("LOOT_OPENED")
		M.fire("CHAT_MSG_LOOT", chat(NEW2, 1))
		M.fire("LOOT_CLOSED")
		c = cast(M, DE, 7010)
		DE:Refresh(); DE:Select(entryOf(DE, 7010)); DE:Paint()
	end)
	check(ok and DE:LearnedMaterials()[NEW] == true and DE:Log()["2:3:a"].mats[NEW] == 1 and DE:Log()["2:3:a"].mats[NEW2] == nil, "without instant item info: the window still teaches, the chat still filters, no error (" .. tostring(err) .. ")")
	check(DE.frame.cur.likely.text == "Still learning: 1 of 20 disenchants in this range.", "and the learning line shows")
	DE.frame:Hide()
end)()
