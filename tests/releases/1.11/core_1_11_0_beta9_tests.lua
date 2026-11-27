-- ======== 1.11.0-beta9 (Shweep, 27 Nov: "B", then "Build") ========
-- The answer to the independent re-audit of 1.11.0-beta8 ("Keep in beta"; B8-1 and B8-2, both about how a
-- disenchant's loot is counted). Shweep, on the plan to rebuild that counting: "I'm already getting the results from
-- disenchanting, so why are we rebuilding anything". Of three ways put to him he chose the second: ONE change, and
-- the rest of the two findings named as known limits in the response.
--   The change: a "You receive item" receipt is never a disenchant's (B8-2's first case). His trace from the game
--   the same day, auto-loot on and off, is why: the disenchant's own loot window is read as it opens, the game says
--   "You receive loot" after that window closes, and "You receive item" never comes.
-- The fixtures down to the first block are the beta8 set's.

local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function deep(t) if type(t) ~= "table" then return t end local c = {}; for k, v in pairs(t) do c[k] = deep(v) end; return c end
local function click(b) b:GetScript("OnClick")(b) end
local function pump(M) for _ = 1, 20 do M.runTimers() end end
local DEID = 13262
local MATNAMES = { [10940] = "Strange Dust", [11083] = "Soul Dust", [10938] = "Lesser Magic Essence", [10939] = "Greater Magic Essence", [10998] = "Lesser Astral Essence", [11082] = "Greater Astral Essence", [10978] = "Small Glimmering Shard", [11084] = "Large Glimmering Shard", [11138] = "Small Glowing Shard" }
local PRICES = { [7001] = 1500, [7002] = 600, [10940] = 120, [10938] = 300, [10939] = 500, [10998] = 400, [11083] = 150, [11082] = 900, [10978] = 800, [11084] = 2000, [11138] = 1200 }

-- ItemTree's real answer for a piece it keeps (a quest piece, as in the 1.10.0-beta8 set), and the fake that gives it.
local function keepFacts(id)
	return { itemId = id, known = true, noDisenchant = true,
		keep = { lines = { "Keep (1)", "A Lost Master (II)", "Not an upgrade" }, always = false, marked = true, line = "Keep (1)",
			gear = { basis = "stats", specs = {}, upgrade = false, labels = {} }, valuable = false, noAuctionData = false, tags = { "keep" }, never = false, state = "keep", off = false, byUse = true, legendary = false },
		vendors = { everywhere = false, count = 0 }, route = { needed = false },
		uses = { reagentSkills = {}, current = 1, stale = 0, professions = {}, kinds = { reagent = 0, lock = 0, spell = 0, quest = 1, tool = 0, teaches = 0 } },
		quests = { stale = false, needs = { 993 }, titles = { [993] = "A Lost Master" }, predicted = {}, starts = {}, keepUpTo = 1, counts = { [993] = 1 }, staleAfter = {} } }
end
local function fakeItemTree(state)
	state.calls, state.asked = 0, {}
	return {
		version = 1,
		IsReady = function() return state.ready ~= false end,
		RequestData = function() end,
		RegisterReadyCallback = function(fn) state.onReady = fn end,
		RegisterChangeCallback = function(fn) state.onChange = fn end,
		GetItemFacts = function(id)
			state.calls = state.calls + 1
			state.asked[id] = (state.asked[id] or 0) + 1
			return deep(state.facts[id]) or { itemId = id, known = false }
		end,
	}
end
local function fakePawn(state)
	state.asked = {}
	_G.PawnShouldItemLinkHaveUpgradeArrow = function(link)
		local id = tonumber(tostring(link):match("item:(%d+)"))
		state.asked[id] = (state.asked[id] or 0) + 1
		if state.pending and state.pending[id] then return nil end
		return state.upgrades[id] or false
	end
	_G.PawnCommon = { ShowBagUpgradeAdvisor = true }
end
local BOOTS = { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 452, ilvl = 23, equip = "INVTYPE_FEET" }
local CLOAK = { id = 5387, name = "Enchanted Moonstalker Cloak", q = 2, count = 1, class = 4, subclass = 1, price = 150, ilvl = 20, equip = "INVTYPE_CLOAK" }
local DAGGER = { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" }
local EPIC = { id = 7010, name = "Blade of Ages", q = 4, count = 1, class = 2, subclass = 7, price = 50000, ilvl = 40, equip = "INVTYPE_WEAPON" }
local function put(M, slot, item) M.put(0, slot, deep(item)) end

-- An enchanter with `stock` in the bags. opts: it (ItemTree's state), pawn (Pawn's), prof (profile keys), rank
-- (Enchanting skill), sets (a function that adds gear sets), trade (a table driving the tradeable tooltip read),
-- deShared, prices, vendor (the boots' vendor price).
local function hBoot(stock, opts)
	opts = opts or {}
	package.loaded.mock = nil
	local M = require("mock")
	stock(M)
	_G.ItemTreeAPI = opts.it and fakeItemTree(opts.it) or nil
	if opts.pawn then fakePawn(opts.pawn) else _G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil end
	M.removeEquipmentSets()
	if opts.sets then M.installEquipmentSets(); opts.sets(M) end
	_G.BIND_TRADE_TIME_REMAINING = nil
	if opts.trade then
		-- the game's tooltip, which the Helper reads for "still tradeable"; the mock's frames have no SetBagItem
		_G.BIND_TRADE_TIME_REMAINING = "You may trade this item with players that were also eligible to loot this item for the next %s."
		local T = opts.trade
		local realCreate = CreateFrame
		_G.CreateFrame = function(kind, name, ...)
			if name ~= "BagSmithDEScanTooltip" then return realCreate(kind, name, ...) end
			local tip = { SetOwner = function() end, ClearLines = function() end, at = nil }
			function tip:SetBagItem(bag, slot) if T.unreadable then error("no tooltip") end self.at = bag .. ":" .. slot end
			function tip:NumLines() return (T.slots and T.slots[self.at]) and 1 or 0 end
			_G[name .. "TextLeft1"] = { GetText = function() return "You may trade this item with players that were also eligible to loot this item for the next 1 hour." end }
			_G[name] = tip
			return tip
		end
	end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local prof = { skin = "modern", deEnabled = true }
	for k, v in pairs(opts.prof or {}) do prof[k] = v end
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = prof }, whatsNewSeen = "1.10.0", deShared = opts.deShared }
	_G.BagSmithWhatsNew = nil
	_G.GuildBankFrame, _G.MailFrame = nil, nil
	_G.IsSpellKnown = function(id) return id == DEID end
	_G.GetNumSkillLines = function() return 2 end
	_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, opts.rank or 300 end
	_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
	_G.RegisterStateDriver = function() end
	_G.UnregisterStateDriver = function() end
	_G.GetMoneyString = function(c) return ("%dg %ds %dc"):format(math.floor(c / 10000), math.floor(c / 100) % 100, c % 100) end
	_G.LOOT_ITEM_SELF = "You receive loot: %s."; _G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
	_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."; _G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
	C_Container.GetContainerItemPurchaseInfo = nil
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(link) local id = tonumber(tostring(link):match("item:(%d+)")) or link; if MATNAMES[id] then return MATNAMES[id], nil, id == 10978 and 3 or 1 end return realInfo(link) end
	local prices = opts.prices or PRICES
	if opts.noAH then _G.Auctionator = nil else
		_G.Auctionator = { API = { v1 = {
			GetAuctionPriceByItemLink = function(_, link) local id = tonumber(link:match("item:(%d+)")); return id and prices[id] end,
			GetAuctionPriceByItemID = function(_, id) return prices[id] end,
			GetAuctionAgeByItemLink = function() return nil end,
		} } }
	end
	local n = M.loadAddon("BagSmith"); n.version = "1.11.0-beta9"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	for _ = 1, 10 do M.runTimers() end
	local DE = n.Disenchant
	DE:Show(); M.runTimers()
	return n, M, DE, DE.frame, DE:Button()
end
local function recOf(n, id, slot) for _, r in ipairs(n.items) do if r.itemID == id and (not slot or r.slot == slot) then return r end end end
local function offered(DE) local t = {}; for _, e in ipairs(DE.entries or {}) do t[#t + 1] = e.name end; table.sort(t); return table.concat(t, ", ") end
local function heldList(DE) local t = {}; for _, e in ipairs(DE.heldEntries or {}) do t[#t + 1] = e.name .. " [" .. e.held .. "]" end; return table.concat(t, ", ") end
local function entryOf(DE, id, slot) for _, e in ipairs(DE.entries or {}) do if e.itemID == id and (not slot or e.slot == slot) then return e end end end
local function heldOf(DE, id, slot) for _, e in ipairs(DE.heldEntries or {}) do if e.itemID == id and (not slot or e.slot == slot) then return e end end end
local function rowsOf(f) local t = {}; for _, r in ipairs(f.rows) do if r:IsShown() then t[#t + 1] = r end end return t end
local function rowFor(f, id, slot) for _, r in ipairs(rowsOf(f)) do if r.entry and r.entry.itemID == id and (not slot or r.entry.slot == slot) then return r end end end
local function armed(b) return b:GetAttribute("type") == "spell" end
-- (By design since 1.11.0-beta7, Shweep's look at beta6 in game: "not sure dimming the held back is a good call ... the
-- button in header is hard to find, end of the reg list would possibly be better". The switch is the Held Back band at
-- the end of the offered rows, there whenever anything is held back; the header's Show button is gone; held-back rows
-- are at full strength with a lock in place of the ring. The checks below that named the old button or the dimming
-- name the band and the lock instead, each marked.)
local function bandOf(f) for _, r in ipairs(rowsOf(f)) do if r.heading then return r end end end
local function lootLine(M, id, count)
	M.fire("CHAT_MSG_LOOT", ("You receive loot: |cffffffff|Hitem:%d:0:0:0:0:0:0:0|h[mat]|h|r%s."):format(id, count > 1 and ("x" .. count) or ""))
end
-- The armed piece disenchanted as the game runs it.
local function castArmed(M, DE, b, loot)
	local e = DE.current
	b:GetScript("PreClick")(b)
	if DE.castingEntry ~= e then return false end
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", DEID)
	for _, l in ipairs(loot or {}) do lootLine(M, l[1], l[2]) end
	M.bags[e.bag][e.slot] = nil; M.fire("BAG_UPDATE_DELAYED"); M.fire("LOOT_CLOSED"); pump(M)
	return true
end
local function lines(DE, which)
	local out = {}
	for _, l in ipairs((DE:ResultLines(which or "session"))) do out[#out + 1] = { plain(l.left), plain(l.right), l.kind, l.id } end
	return out
end
local function line(DE, left, which) for _, l in ipairs(lines(DE, which)) do if l[1] == left then return l end end end
local function painted(DE, left) for _, r in ipairs(DE.frame.results.rows) do if r:IsShown() and plain(r.left.text) == left then return plain(r.right.text) end end end


local function said(M, from, what) for i = from, #M.log do if plain(M.log[i]):find(what, 1, true) then return true end end return false end
local OWN = "Item-4-0-0-00AA11BB"
-- A disenchant of the boots on a clock: cast at 100, ten dust by a "You receive loot" line, the item gone at once.
-- opts.guid gives the boots an instance the game's loot window can name.
local function start(opts)
	opts = opts or {}
	local boots = deep(BOOTS); boots.guid = opts.guid
	local n, M, DE, f, b = hBoot(function(M) M.put(0, 1, boots) end, { prof = { debug = true }, deShared = opts.deShared })
	local stamp = 100
	_G.GetTime = function() return stamp end
	local function at(t) stamp = t end
	DE:Select(entryOf(DE, 7001)); b:GetScript("PreClick")(b)
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", DEID)
	if not opts.quiet then lootLine(M, 10940, 10) end
	DE.pendingLook = true
	M.bags[0][1] = nil; M.fire("BAG_UPDATE_DELAYED"); pump(M)
	return n, M, DE, at
end
local function pushed(M, id, count) M.fire("CHAT_MSG_LOOT", ("You receive item: |cffffffff|Hitem:%d:0:0:0:0:0:0:0|h[mat]|h|rx%d."):format(id, count)) end
local function window(guid, id, qty)
	_G.GetNumLootItems = function() return 1 end
	_G.GetLootSlotInfo = function() return nil, nil, qty end
	_G.GetLootSlotLink = function() return ("|Hitem:%d:0:0:0:0:0:0:0|h[mat]|h"):format(id) end
	_G.GetLootSourceInfo = guid and function() return guid, qty end or nil
end
local function noWindow() _G.GetNumLootItems, _G.GetLootSlotInfo, _G.GetLootSlotLink, _G.GetLootSourceInfo = nil, nil, nil, nil end

------------------------------------------------------------------------
-- "You receive item" is never a disenchant's
------------------------------------------------------------------------
do
	-- the auditor's case: ten dust by a "You receive loot" line, then five by "You receive item" 0.6s after the cast
	local n, M, DE, at = start()
	local from = #M.log + 1
	at(100.6); pushed(M, 10940, 5); M.fire("LOOT_CLOSED")
	local t = DE:Results("session").tracked
	check(t.cn == 1 and t.matsValue == 1200 and t.ahead == -285 and DE:Stats().mats[10940] == 10, "a \"You receive item\" receipt inside the first second is not counted (beta8 counted it and flipped the winner)")
	check(said(M, from, "receipt at +0.6s, Strange Dust x5 (\"receive item\"): not counted, a disenchant's loot is never announced that way"), "/bs debug says why")
	-- nor before the item has left its slot, nor as the only receipt a cast gets
	local n2, M2, DE2, f2, b2 = hBoot(function(M) put(M, 1, BOOTS) end)
	DE2.ARM_HOLD = 0
	DE2:Select(entryOf(DE2, 7001)); b2:GetScript("PreClick")(b2)
	M2.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", DEID)
	pushed(M2, 10940, 5)
	check(DE2.castOpen ~= nil and DE2.castOpen.goneAt == nil and (DE2:Stats().mats[10940] or 0) == 0 and DE2:Stats().cn == 0, "nor with the item still in its slot: the cast has no materials from it and is not compared")
	lootLine(M2, 10940, 3)
	check(DE2:Stats().mats[10940] == 3 and DE2:Stats().cn == 1, "a \"You receive loot\" line is counted as ever")
	noWindow()
end
do
	-- his trace, auto-loot on: the own window read at once, the loot closed at +0.6s, and only then the game's line
	local n, M, DE, at = start({ guid = OWN, quiet = true })
	at(100); window(OWN, 10940, 4)
	M.fire("LOOT_READY"); M.fire("LOOT_OPENED")
	check(DE.castOpen.ownWindow == true and DE:Stats().mats[10940] == 4, "the disenchant's own window, read as it opens: four dust")
	at(100.3); M.fire("LOOT_OPENED")
	at(100.6); M.fire("LOOT_CLOSED")
	check(DE.castOpen == nil, "the loot closes, and the cast with it")
	lootLine(M, 10940, 4)
	local t = DE:Results("session").tracked
	check(DE:Stats().mats[10940] == 4 and t.cn == 1 and t.matsValue == 480, "the game's \"You receive loot\" line, coming after, adds nothing: four dust, counted once")
	-- auto-loot off: the same, the window closed ten seconds on
	n, M, DE, at = start({ guid = OWN, quiet = true })
	at(100); window(OWN, 10978, 1)
	M.fire("LOOT_READY"); M.fire("LOOT_OPENED")
	at(110.8); M.fire("LOOT_CLOSED")
	lootLine(M, 10978, 1)
	check(DE:Stats().mats[10978] == 1 and DE.castOpen == nil, "auto-loot off, the window closed at +10.8s and the line after it: one shard, counted once")
	noWindow()
end
