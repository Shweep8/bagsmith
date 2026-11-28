-- ======== 1.11.0-beta8 (Shweep, 27 Nov: "build") ========
-- Two things in one build.
--
-- 1. The answer to the independent re-audit of 1.11.0-beta7 ("Keep as beta"), each case reproduced on beta7 first
--    with the auditor's own probe:
--      B7-1 (P2) with a cast's attribution open for its five seconds (beta7's fix for B6-3), a "You receive item"
--           receipt of the same material from elsewhere, or a loot window known to be a creature's, was counted
--           for the cast and saved.
--      B7-2 (P3) a saved record with its matched count missing read as "nothing compared" while keeping its
--           totals, and the next disenchant mixed into them.
--      B7-3 (P3, advisory) the Helper's window hidden directly left its question on screen.
--    The auditor asks that how Forever sends a disenchant's loot be checked in game before the chat patterns are
--    changed. Shweep: "I can't test above yet, but after next build I can". So no pattern is removed here, and
--    /bs debug now traces each loot event of an open cast for him to paste.
-- 2. His feedback on beta7: "have the lock be white or something and then colored when selected to tell if
--    selected. instead of offer anyway, have Disenchant button be Disenchant Anyway. think that will be more
--    intuitive". Of the two ways put to him he chose the first ("A"): the button lies over the Disenchant button,
--    a click on it is still only the offer, and the real button comes alive half a second later.
--
-- The fixtures down to the first block are the beta7 set's.

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
	local n = M.loadAddon("BagSmith"); n.version = "1.11.0-beta8"
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
-- B7-1. What may be counted for a cast while it is open
------------------------------------------------------------------------
do
	-- (the control the auditor asks to be kept) a "You receive loot" line two seconds on is the cast's
	local n, M, DE, at = start()
	check(DE.castOpen and DE.castOpen.goneAt == 100 and DE:Results("session").pending, "(a cast open, ten dust in, its item gone at 100)")
	at(102); lootLine(M, 10940, 5); M.fire("LOOT_CLOSED")
	local t = DE:Results("session").tracked
	check(t.matsValue == 1800 and t.ahead == 285 and DE:Stats().mats[10940] == 15, "a later \"You receive loot\" line inside the five seconds is still counted")
	noWindow()
end
do
	-- the auditor's first case: a "You receive item" receipt of the same dust, two seconds after the item left
	local n, M, DE, at = start()
	local from = #M.log + 1
	at(102); pushed(M, 10940, 5); M.fire("LOOT_CLOSED")
	local t = DE:Results("session").tracked
	check(t.cn == 1 and t.matsValue == 1200 and t.ahead == -285 and DE:Stats().mats[10940] == 10, "a \"You receive item\" receipt that long after the item left is not counted for the cast (beta7 counted it and flipped the winner)")
	check(DE:Log()[DE.castOpen and DE.castOpen.key or next(DE:Log())].mats[10940] == 10, "nor does it teach the bracket")
	-- (by design since 1.11.0-beta9: the reason given is the form itself, at any time)
	check(said(M, from, "receipt at +2.0s, Strange Dust x5 (\"receive item\"): not counted, a disenchant's loot is never announced that way"), "/bs debug says so, with the time and the line's form")
	local saved = deep(BagSmithDB.deShared)
	local n2, M2, DE2 = hBoot(function(M) put(M, 1, BOOTS) end, { deShared = saved })
	check(DE2:Results("all").tracked.matsValue == 1200 and DE2:Results("all").tracked.ahead == -285, "and what is saved is the cast's own ten")
	-- within a second of the item leaving, such a receipt counts as it always has
	n, M, DE, at = start()
	at(100.8); pushed(M, 10940, 5)
	-- (by design since 1.11.0-beta9, the beta8 re-audit's B8-2 and Shweep's trace: that form is never a disenchant's,
	-- so the second's allowance beta8 kept is gone)
	check(DE:Stats().mats[10940] == 10, "inside the second after the item left, a \"You receive item\" receipt is not counted either")
	-- and one that names nothing a disenchant gives never does
	at(101); pushed(M, 2589, 3)
	check(DE:Stats().mats[2589] == nil, "(a receipt of something else is no material of the cast's, as ever)")
	noWindow()
end
do
	-- the auditor's second case: a loot window whose source is known, and is a creature
	local n, M, DE, at = start()
	local from = #M.log + 1
	at(102); window("Creature-0-000-0-0-1234-000A", 10940, 15)
	check(not DE.SlotIsCast(1, 10940), "(the window's source is a creature)")
	M.fire("LOOT_READY"); M.fire("LOOT_OPENED"); M.fire("LOOT_CLOSED")
	local t = DE:Results("session").tracked
	check(t.matsValue == 1200 and t.ahead == -285 and DE:Stats().mats[10940] == 10, "a loot window known to be something else's is ignored for the cast (beta7 took its fifteen dust)")
	check(said(M, from, "loot window at +2.0s: not the disenchanted item's, ignored"), "/bs debug says so")
	-- another item's window (a lockbox, say) is as foreign as a creature's
	n, M, DE, at = start({ guid = OWN })
	at(101); window("Item-4-0-0-99999999", 10940, 15)
	M.fire("LOOT_READY"); M.fire("LOOT_OPENED")
	check(DE:Stats().mats[10940] == 10 and not DE.castOpen.ownWindow, "so is a window whose source is another item")
	-- a window whose source can't be read at all keeps the fallback it had: only what the bracket can give
	n, M, DE, at = start()
	at(101); window(nil, 10940, 12)
	local from2 = #M.log + 1
	M.fire("LOOT_OPENED")
	check(DE:Stats().mats[10940] == 12 and said(M, from2, "loot window at +1.0s: its source can't be read"), "a window whose source can't be read is treated as before: a material the bracket gives is counted")
	noWindow()
end
do
	-- the cast's own window, once read, is the cast's loot: receipts add nothing to it
	local n, M, DE, at = start({ guid = OWN, quiet = true })
	local from = #M.log + 1
	at(100.2); window(OWN, 10940, 10)
	M.fire("LOOT_READY"); M.fire("LOOT_OPENED")
	check(DE.castOpen.ownWindow == true and DE:Stats().mats[10940] == 10 and said(M, from, "loot window at +0.2s: the cast's own"), "the disenchant's own loot window is read: ten dust, and /bs debug names it")
	at(100.4); lootLine(M, 10940, 10)
	check(DE:Stats().mats[10940] == 10, "its own receipt line adds nothing to that (as before: the two say the same)")
	at(102); lootLine(M, 10940, 5); pushed(M, 10940, 5)
	check(DE:Stats().mats[10940] == 10 and DE:Results("session").tracked.matsValue == 1200, "nor does any later receipt, of either form")
	check(said(M, from, "receipt at +2.0s, Strange Dust x5 (\"receive loot\"): not counted, the cast's own loot window was read"), "/bs debug says why")
	M.fire("LOOT_CLOSED")
	check(DE:Results("session").tracked.ahead == -285 and DE.castOpen == nil, "the loot closes: selling ahead by 2s85c on the cast's own ten")
	noWindow()
end
do
	-- the trace he is asked for: one ordinary disenchant, /bs debug on
	local n, M, DE, at = start({ quiet = true })
	local from = 1
	at(100.3); lootLine(M, 10940, 2)
	at(100.9); M.fire("LOOT_CLOSED")
	for _, want in ipairs({
		"cast succeeded on Sturdy Boots; its loot is followed for 5 seconds",
		"the item left its slot at +0.0s",
		"receipt at +0.3s, Strange Dust x2 (\"receive loot\")",
		"attribution closed (loot closed) at +0.9s",
	}) do check(said(M, from, want), "/bs debug traces the cast: " .. want) end
	noWindow()
end

------------------------------------------------------------------------
-- B7-2. Totals with no matched count
------------------------------------------------------------------------
do
	-- the auditor's record: a compared disenchant's totals and materials, and no cn
	local broken = { version = 3, results = { ["2:a"] = { n = 1, mats = { [10940] = 10 } } },
		stats = { v = 3, n = 1, vendor = 1425, ah = 1425, ahN = 1, ahU = 0, alt = 1425, mats = { [10940] = 10 } } }
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS) end, { deShared = deep(broken) })
	DE.ARM_HOLD = 0
	local st, before = DE:Stats(), DE:Results("all").tracked
	check(st.gap == true and before.cn == 0 and before.ahead == nil, "totals and materials with no matched count: the record is marked as it loads (beta7 read it as nothing compared, unmarked)")
	check(castArmed(M, DE, b, { { 10940, 14 } }) and DE:Results("session").tracked.ahead == 171, "(a new disenchant: this session, on its own, is ahead by 1s71c)")
	local t = DE:Results("all").tracked
	check(t.gap == true and t.ahead == nil, "All Time still names no winner (beta7 mixed the new cast into the old totals and said selling was ahead by 1s14c)")
	DE:ShowResults(true); DE:SetResultsTab("all")
	check(painted(DE, "Selling Would Have Paid More By") == nil and painted(DE, "No winner named: part of the saved record couldn't be read.") ~= nil, "and the view says why")
	-- reload, then another cast: the mark is still there
	local saved = deep(BagSmithDB.deShared)
	check(saved.stats.gap == true, "(the mark is saved)")
	n, M, DE, f, b = hBoot(function(M) put(M, 3, DAGGER) end, { deShared = saved })
	DE:Select(entryOf(DE, 7002)); castArmed(M, DE, b, { { 10940, 3 } })
	check(DE:Stats().gap == true and DE:Results("all").tracked.ahead == nil, "after a reload and one more disenchant, All Time still names no winner")
	-- each kind of leftover, by itself
	for label, stats in pairs({
		["materials alone"] = { v = 3, n = 1, mats = { [10940] = 4 } },
		["a vendor total alone"] = { v = 3, n = 1, vendor = 500, mats = {} },
		["a priced count alone"] = { v = 3, n = 1, ahN = 1, mats = {} },
		["an unpriced count alone"] = { v = 3, n = 1, ahU = 1, mats = {} },
		["a matched count of zero beside totals"] = { v = 3, n = 1, cn = 0, vendor = 500, ah = 0, ahN = 0, ahU = 0, alt = 500, mats = { [10940] = 4 } },
	}) do
		local _, _, D2 = hBoot(function(M) put(M, 1, BOOTS) end, { deShared = { version = 3, results = {}, stats = stats } })
		check(D2:Stats().gap == true, label .. ": marked")
	end
	-- what must not be marked: nothing compared at all, and a cast whose loot was never seen
	local _, _, D3 = hBoot(function(M) put(M, 1, BOOTS) end, { deShared = { version = 3, results = {}, stats = { v = 3, n = 3, cn = 0, vendor = 0, ah = 0, ahN = 0, ahU = 0, alt = 0, mats = {}, q = { [2] = 3 } } } })
	check(D3:Stats().gap == nil and D3:Stats().n == 3, "a record that compared nothing is not marked")
	local n4, M4, D4, f4, b4 = hBoot(function(M) put(M, 1, BOOTS); put(M, 3, DAGGER) end)
	D4.ARM_HOLD = 0
	D4:Select(entryOf(D4, 7002)); castArmed(M4, D4, b4, {})
	local saved4 = deep(BagSmithDB.deShared)
	n4, M4, D4, f4, b4 = hBoot(function(M) put(M, 1, BOOTS) end, { deShared = saved4 })
	check(D4:Stats().gap == nil and D4:Stats().n == 1 and D4:Stats().cn == 0, "a disenchant whose loot was never seen, saved and read back, is not marked")
	D4:Select(entryOf(D4, 7001)); castArmed(M4, D4, b4, { { 10940, 20 } })
	check(D4:Results("all").tracked.ahead == 855 and line(D4, "Counted: 1 of 2 disenchants. The other gave no materials BagSmith saw.", "all") ~= nil, "and the next one is compared and named as usual")
end

------------------------------------------------------------------------
-- B7-3. The window hidden by any means takes its question with it
------------------------------------------------------------------------
do
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS); put(M, 3, DAGGER) end)
	n.Marks:ToggleFavorite(recOf(n, 7001)); pump(M); DE:Refresh()
	click(bandOf(f)); click(rowFor(f, 7001)); click(f.offer)
	local pop = n.Popups.confirm
	local stale = pop.onYes
	check(pop:IsShown() and DE.askFn == stale, "(a question is up)")
	f:Hide()
	check(not pop:IsShown() and DE.askFn == nil, "the Helper's window hidden directly: its question goes too (it stayed on screen, in beta7)")
	stale()
	check(DE.offered == nil and not armed(b), "and its Yes does nothing")
	DE:Show(); pump(M)
	check(heldOf(DE, 7001) ~= nil and entryOf(DE, 7001) == nil, "opened again, the boots are held back")
	-- someone else's question in the shared box is left alone when the window hides
	click(rowFor(f, 7001)); click(f.offer)
	local other = false
	n.Confirm(nil, "Another question?", function() other = true end)
	f:Hide()
	check(pop:IsShown() and pop.text.text == "Another question?", "a question that isn't the Helper's stays up when its window hides")
	click(pop.yes)
	check(other and DE.offered == nil, "and is answered as ever")
end

------------------------------------------------------------------------
-- Disenchant Anyway, and the lock's colours
------------------------------------------------------------------------
do
	local it = { facts = { [5387] = keepFacts(5387) } }
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS); put(M, 2, CLOAK); put(M, 4, EPIC) end, { it = it })
	check(DE.ARM_HOLD == 0.5, "(the pause after Disenchant Anyway is half a second)")
	local stamp = 100
	_G.GetTime = function() return stamp end
	click(bandOf(f))
	local cloakRow, epicRow = rowFor(f, 5387), rowFor(f, 7010)
	-- the lock: white, and gold on the row in the panel
	local function colour(r) local x, y, z = r.lock:GetVertexColor(); return x .. "," .. y .. "," .. z end
	check(colour(cloakRow) == "1,1,1" and colour(epicRow) == "1,1,1", "every held-back row's lock is white")
	click(cloakRow)
	check(colour(cloakRow) == "1,0.82,0" and colour(epicRow) == "1,1,1" and cloakRow.hl:IsShown(), "the lock of the row in the panel is gold, the other still white")
	click(epicRow)
	check(colour(cloakRow) == "1,1,1" and colour(epicRow) == "1,0.82,0", "pick the other and the colours change places")
	click(cloakRow)
	-- the button: Disenchant Anyway, lying over the Disenchant button
	check(f.offer:IsShown() and f.offer.label.text == "Disenchant Anyway" and f.offer:IsEnabled(), "with a held-back row in the panel the main button reads Disenchant Anyway")
	check(f.offer.points[1][1] == "TOPLEFT" and f.offer.points[1][2] == b and f.offer.points[2][1] == "BOTTOMRIGHT" and f.offer.points[2][2] == b, "it lies exactly over the Disenchant button")
	check(not armed(b) and not b:IsEnabled() and b:GetAttribute("target-slot") == nil, "which is disarmed and greyed under it")
	check(f.offer.tip == "Disenchant this piece anyway" and f.skip.points[1][2] == f.offer, "(its tip; Skip beside it)")
	-- a click is the offer, never the cast: the piece is in the panel and the button is not live yet
	click(f.offer)
	check(entryOf(DE, 5387) ~= nil and DE.current and DE.current.itemID == 5387 and DE.current.offered == "ItemTree: keep", "a click puts the piece in the list and in the panel")
	check(not f.offer:IsShown() and not armed(b) and not b:IsEnabled() and b:GetAttribute("target-slot") == nil, "and the Disenchant button, now in that place, is not live: a second click right away casts nothing")
	check((DE.done or 0) == 0 and DE.castingEntry == nil, "(nothing was cast)")
	stamp = 100.3
	DE:Refresh()
	check(not armed(b) and DE.current.itemID == 5387, "a redraw inside the half second leaves it dead")
	stamp = 100.6
	pump(M)
	check(armed(b) and b:IsEnabled() and b:GetAttribute("target-slot") == 2 and DE.current.itemID == 5387 and DE.armHoldUntil == nil, "half a second on, the Disenchant button is live for that piece")
	check(DE:LiveCheck(DE.current) == true, "and its click passes the check")
	-- a protected reason: the question, then the same pause
	click(rowFor(f, 7010))
	check(f.offer:IsShown() and not armed(b), "(the epic's row: Disenchant Anyway again)")
	stamp = 200
	click(f.offer)
	local pop = n.Popups.confirm
	check(pop:IsShown() and pop.text.text == "Blade of Ages is an epic.\nDisenchant this one anyway? Nothing is disenchanted until you click Disenchant.", "an epic asks first, in the new words: " .. tostring(pop.text.text))
	click(pop.yes)
	check(DE.current.itemID == 7010 and not armed(b) and not b:IsEnabled(), "Yes: the epic is in the panel, the button not live yet")
	stamp = 200.6; pump(M)
	check(armed(b) and b:GetAttribute("target-slot") == 4, "and live half a second later")
	-- what can't be chosen greys the button, under its new name
	local it2 = { facts = {}, ready = false }
	local n2, M2, DE2, f2, b2 = hBoot(function(M) put(M, 1, BOOTS) end, { it = it2 })
	click(f2.empty.heldShow)
	check(f2.offer:IsShown() and not f2.offer:IsEnabled() and f2.offer.offName == "Disenchant Anyway" and f2.offer.offReason == "ItemTree hasn't answered about it yet. This clears by itself in a moment.", "a piece that can't be chosen greys Disenchant Anyway, with the reason")
	-- What's New's bullet names the button
	local items = n2.WhatsNew.ENTRIES[2].items   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
	check(items[8]:find("Disenchant Anyway puts one in the list", 1, true) and not items[8]:find("Offer Anyway", 1, true), "the What's New bullet names Disenchant Anyway")
	check((n.errors or 0) == 0 and (n2.errors or 0) == 0, "no errors")
end
