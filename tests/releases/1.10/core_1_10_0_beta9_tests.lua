-- ======== 1.10.0-beta9 (Shweep, 22 Nov: "that works. build") ========
-- Settings > Other Addons, a page of its own ("this needs more consistency and a scalable plan"; "1. own page",
-- "2. agreed", "3. agreed"; "go w/ first icon"; "AH addons doesnt scale if more of those added"):
--   * every card is built the same way: the heading, the state at the right end of its line, one sentence, then a row
--     per job. An addon card for ItemTree and for Pawn; a job card, Auction Prices, where several addons do one job
--     (a list to choose from and a "Works with" line, both made from the list of price addons).
--   * one switch per job, none depending on another: Section and Filter Rules (was Use ItemTree), Hold Back in the
--     Loot Helper and Hold Back in the Disenchant Helper for ItemTree (was one switch for both) and for Pawn (the Loot
--     Helper's was always on with no switch; it is on unless you turn it off).
--   * an addon you don't have shows its heading, state and sentence only.

local function deep(t) if type(t) ~= "table" then return t end local c = {}; for k, v in pairs(t) do c[k] = deep(v) end; return c end
local function click(b) b:GetScript("OnClick")(b) end
local function pump(M) for _ = 1, 40 do M.runTimers() end end

-- ItemTree's answer about one item: its Keep mark and its state, the rest as the game has it.
local function fact(id, marked, state)
	return { itemId = id, known = true,
		keep = { marked = marked, state = state or (marked and "keep" or "vendor"), tags = { marked and "keep" or "vendor" } },
		route = { needed = false }, vendors = { buyPrice = 10, everywhere = false, count = 0 },
		uses = { reagentSkills = marked and { 197 } or {}, kinds = { reagent = 0 } }, quests = { needs = {} } }
end
local function fakeItemTree(state)
	state.calls, state.asked, state.requested = 0, {}, 0
	return {
		version = 1,
		IsReady = function() return true end,
		RequestData = function() state.requested = state.requested + 1 end,
		RegisterReadyCallback = function(fn) state.onReady = fn end,
		RegisterChangeCallback = function(fn) state.onChange = fn end,
		GetItemFacts = function(id)
			state.calls = state.calls + 1
			state.asked[id] = (state.asked[id] or 0) + 1
			return deep(state.facts[id])
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
	_G.PawnCommon = { ShowBagUpgradeAdvisor = state.advisor ~= false }
end
local function fakePrices(which)
	_G.Auctionator, _G.BlackthornesTS_API = nil, nil
	if which and which.auctionator then
		_G.Auctionator = { API = { v1 = {
			GetAuctionPriceByItemLink = function() return 40 end, GetAuctionPriceByItemID = function() return 40 end,
			GetAuctionAgeByItemLink = function() return 1 end, GetAuctionAgeByItemID = function() return 1 end,
		} } }
	end
	if which and which.bts then
		_G.BlackthornesTS_API = { version = 1, GetPrice = function() return 55 end, GetPriceAge = function() return 60 end }
	end
end
local function others(opts)
	_G.ItemTreeAPI = opts.it and fakeItemTree(opts.it) or nil
	if opts.pawn then fakePawn(opts.pawn) else _G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil end
	fakePrices(opts.prices)
end
local function tidy() others({}) end
local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end

-- A plain boot with whatever the profile holds.
local function boot(opts)
	opts = opts or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2996, name = "Bolt of Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 10, ilvl = 10 })
	M.put(0, 2, { id = 6530, name = "Nightcrawlers", q = 1, count = 4, class = 0, subclass = 8, type = "Consumable", sub = "Other", price = 25, ilvl = 10 })
	others(opts)
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local prof = { skin = opts.skin or "modern" }
	for k, v in pairs(opts.prof or {}) do prof[k] = v end
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = prof } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta9"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	return n, M
end

;(function()
	-- the settings, and a profile from beta7 or beta8
	local n = boot()
	check(n.db.useItemTree == true and n.db.makeRoomHoldItemTree == true and n.db.deHoldItemTree == true and n.db.makeRoomHoldPawn == true and n.db.deHoldPawn == false,
		"a fresh profile: ItemTree's rules and both its holds on, Pawn held back in the Loot Helper (as always) and not in the Disenchant Helper")
	check(n.db.itemTreeHold == nil and not pcall(function() n:Set("itemTreeHold", true) end), "the one switch for both Helpers is gone")
	n = boot({ prof = { itemTreeHold = false, useItemTree = true } })
	check(n.db.makeRoomHoldItemTree == false and n.db.deHoldItemTree == false and n.db.useItemTree == true and n.db.itemTreeHold == nil, "a profile that had Hold Back off: off for both Helpers, the rules still on")
	n = boot({ prof = { itemTreeHold = true, useItemTree = false } })
	check(n.db.makeRoomHoldItemTree == false and n.db.deHoldItemTree == false and n.db.useItemTree == false, "one that had Use ItemTree off, which switched the hold off too: everything stays off")
	n = boot({ prof = { itemTreeHold = true, useItemTree = true, deHoldPawn = true } })
	check(n.db.makeRoomHoldItemTree == true and n.db.deHoldItemTree == true and n.db.deHoldPawn == true, "one that had everything on keeps everything on (and Pawn's Disenchant Helper switch as it was)")
	n = boot({ prof = { itemTreeHold = false, makeRoomHoldItemTree = true } })
	check(n.db.makeRoomHoldItemTree == true and n.db.deHoldItemTree == false, "a switch already set by hand isn't overwritten")
	n = boot({ prof = { makeRoomHoldPawn = "yes", deHoldItemTree = 3 } })
	check(n.db.makeRoomHoldPawn == true and n.db.deHoldItemTree == true, "a value that isn't yes or no is put right")
	check((n.errors or 0) == 0, "no errors")
	tidy()
end)()

;(function()
	-- ItemTree: three switches, each its own
	local it = { facts = { [2996] = fact(2996, true), [6530] = fact(6530, false) } }
	local n, M = boot({ it = it })
	local IT, S = n.ItemTree, n.Sections
	local cloth = recOf(n, 2996)
	check(IT:Holds(cloth) == true and IT:Holds(cloth, nil, true) == true, "(everything on: the cloth is held from both Helpers)")
	local mats = S:CreateWithRules("Profession Mats", { mode = "all", rows = { { k = "it_prof", v = { "yes" } } } }); pump(M)
	check(recOf(n, 2996).cat == mats, "(and the rule sorts it)")
	-- the rules off: the holds go on
	n:Set("useItemTree", false); pump(M)
	check(not IT:Enabled() and recOf(n, 2996).cat ~= mats, "Section and Filter Rules off: the rule fits nothing")
	check(IT:Holds(recOf(n, 2996)) == true and IT:Holds(recOf(n, 2996), nil, true) == true, "and both Helpers still hold the cloth back: their switches are their own")
	check(IT:Facts(recOf(n, 2996)) == nil, "(a rule gets no answer while the rules are off)")
	pump(M)
	check((n.errors or 0) == 0, "no errors while the Helpers ask with the rules off")
	n:Set("useItemTree", true); pump(M)
	check(recOf(n, 2996).cat == mats, "on again: the rule sorts it again")
	-- one Helper's switch off: the other's still holds
	n:Set("makeRoomHoldItemTree", false)
	check(IT:Holds(recOf(n, 2996)) == false and IT:Holds(recOf(n, 2996), nil, true) == true and recOf(n, 2996).cat == mats, "the Loot Helper's off: not held there, still held in the Disenchant Helper, the rule untouched")
	n:Set("makeRoomHoldItemTree", true); n:Set("deHoldItemTree", false)
	check(IT:Holds(recOf(n, 2996)) == true and IT:Holds(recOf(n, 2996), nil, true) == false, "the Disenchant Helper's off: the other way round")
	local asked = it.calls
	n:Set("makeRoomHoldItemTree", false)
	check(IT:Holds(recOf(n, 2996), true) == false and IT:Holds(recOf(n, 2996), true, true) == false and it.calls == asked, "both off: ItemTree isn't asked at all")
	check(it.requested == 0 and (n.errors or 0) == 0, "no errors, and ItemTree was never asked to load anything")
	tidy()
end)()

-- ======== the two Helpers, switch by switch ========
do
	local loot = {}
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("|Hitem:" .. loot[i].id .. ":0|h[" .. loot[i].name .. "]|h") end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, l.qty or 1, nil, l.q or 1 end end
	_G.LootSlot = function() end
	_G.DeleteCursorItem = function() end
	local INFO = { [9740] = { "Rough Gem", 1, 1, 30 }, [9701] = { "Broken Fang", 0, 1, 3 }, [9702] = { "Linen Belt", 1, 1, 22 }, [9720] = { "Gnoll Paw", 1, 20, 2 },
		[9730] = { "Heavy Stone", 1, 20, 50 }, [9731] = { "Fine Ring", 1, 1, 80 } }
	local function lootBoot(opts)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return "Warrior", "WARRIOR" end
		M.sizes[0] = 5
		for b = 1, 5 do M.sizes[b] = 0 end
		M.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
		M.put(0, 2, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
		M.put(0, 3, { id = 9720, name = "Gnoll Paw", q = 1, count = 5, stack = 20, class = 15, subclass = 0, price = 2 })
		M.put(0, 4, { id = 9730, name = "Heavy Stone", q = 1, count = 1, stack = 20, class = 7, subclass = 7, price = 50 })
		M.put(0, 5, { id = 9731, name = "Fine Ring", q = 1, class = 4, subclass = 0, price = 80, equip = "INVTYPE_FINGER" })
		others(opts)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local prof = { skin = "modern", makeRoom = true, makeRoomValue = "vendor", makeRoomAsk = false }
		for k, v in pairs(opts.prof or {}) do prof[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = prof } }
		local n = M.loadAddon("BagSmith")
		n.version = "1.10.0-beta9"
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id)
			local num = tonumber(tostring(id):match("item:(%d+)")) or id
			local e = INFO[num]
			if e then return e[1], nil, e[2], nil, nil, nil, nil, e[3], nil, nil, e[4] end
			return realInfo(id)
		end
		C_Container.PickupContainerItem = function(bag, slot) local item = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = item and item.id end
		_G.ClearCursor = function() M.cursorItem = nil end
		_G.LootFrame = CreateFrame("Frame", "LootFrame", UIParent); LootFrame.GetRight = function() return 500 end; LootFrame.GetTop = function() return 700 end; LootFrame:Show()
		loot = { { id = 9740, name = "Rough Gem", q = 1 } }
		M.fire("LOOT_OPENED"); M.runTimers()
		return n, M, n.MakeRoom, n.MakeRoom.frame
	end
	local function offered(f)
		local t = {}
		for _, r in ipairs(f.destroyRows) do if r:IsShown() then t[#t + 1] = r.name.text end end
		return table.concat(t, ",")
	end
	local ALL = "Broken Fang,Gnoll Paw,Linen Belt"

	-- ItemTree keeps the paw
	do
		local it = { facts = { [9720] = fact(9720, true), [9702] = fact(9702, false) } }
		local n, M, MR, f = lootBoot({ it = it })
		check(offered(f) == "Broken Fang,Linen Belt", "(the paw ItemTree keeps isn't offered)")
		-- the rules off: the Loot Helper's hold goes on
		n:Set("useItemTree", false); pump(M); MR:Refresh()
		check(offered(f) == "Broken Fang,Linen Belt" and select(2, MR:StillOk(MR:Offer(recOf(n, 9720), false, "priced", 10))) == "itemtree", "Section and Filter Rules off: the Loot Helper still holds the paw back, at the click too")
		n:Set("useItemTree", true); pump(M)
		-- the Disenchant Helper's switch is not the Loot Helper's
		n:Set("deHoldItemTree", false); M.runTimers(); MR:Refresh()
		check(offered(f) == "Broken Fang,Linen Belt", "the Disenchant Helper's switch off: nothing changes here")
		n:Set("makeRoomHoldItemTree", false); M.runTimers()
		check(offered(f) == ALL and MR:StillOk(MR:Offer(recOf(n, 9720), false, "priced", 10)) == true, "the Loot Helper's own switch off: the open Helper offers the paw at once (" .. offered(f) .. ")")
		n:Set("makeRoomHoldItemTree", true); M.runTimers()
		check(offered(f) == "Broken Fang,Linen Belt", "on again: held again")
		check((n.errors or 0) == 0, "no errors")
	end
	-- Pawn says the belt is an upgrade
	do
		local pawn = { upgrades = { [9702] = true } }
		local n, M, MR, f = lootBoot({ pawn = pawn })
		check(n.db.makeRoomHoldPawn == true and offered(f) == "Broken Fang,Gnoll Paw" and (f.heldInfo.lines[1] or ""):find("Pawn upgrades (1):", 1, true), "Pawn's switch is on unless you turn it off: the upgrade isn't offered, as before (" .. offered(f) .. ")")
		local belt = MR:Offer(recOf(n, 9702), false, "priced", 22)
		check(select(2, MR:StillOk(belt)) == "upgrade", "and refused at the click, as before")
		pawn.pending = { [9702] = true }
		check(select(2, MR:StillOk(belt)) == "pawn", "Pawn can't say yet: refused too, as before")
		pawn.pending = nil
		-- off
		n:Set("makeRoomHoldPawn", false); M.runTimers()
		check(offered(f) == ALL and not f.held:IsShown(), "switched off: the open Helper offers the belt at once (" .. offered(f) .. ")")
		local before = pawn.asked[9702] or 0
		check(MR:StillOk(belt) == true and (pawn.asked[9702] or 0) == before, "and it passes at the click, with no question to Pawn")
		pawn.pending = { [9702] = true }
		check(MR:StillOk(belt) == true, "(nor does Pawn's not-yet hold it up)")
		pawn.pending = nil
		n:Set("deHoldPawn", true); M.runTimers(); MR:Refresh()
		check(offered(f) == ALL, "the Disenchant Helper's switch is not this one")
		n:Set("makeRoomHoldPawn", true); M.runTimers()
		check(offered(f) == "Broken Fang,Gnoll Paw", "on again: held again")
		check((n.errors or 0) == 0, "no errors")
	end
	-- a profile with the Loot Helper's Pawn switch off from the start
	do
		local n, M, MR, f = lootBoot({ pawn = { upgrades = { [9702] = true } }, prof = { makeRoomHoldPawn = false } })
		check(offered(f) == ALL, "a profile with it off: the Helper offers Pawn upgrades (" .. offered(f) .. ")")
	end
	tidy()
end

;(function()
	-- the Disenchant Helper: each addon's switch is its own, and the Loot Helper's switches don't reach it
	package.loaded.mock = nil
	local M = require("mock")
	local DEID = 13262
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
	M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
	M.put(0, 3, { id = 7003, name = "Rare Chest", q = 3, count = 1, class = 4, subclass = 2, price = 2000, ilvl = 45, equip = "INVTYPE_CHEST" })
	local it = { facts = { [7001] = fact(7001, true), [7003] = fact(7003, true, "keepDisenchant") } }
	local pawn = { upgrades = { [7002] = true } }
	others({ it = it, pawn = pawn })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
	_G.IsSpellKnown = function(id) return id == DEID end
	_G.GetNumSkillLines = function() return 2 end
	_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, 300 end
	_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
	_G.RegisterStateDriver = function() end
	_G.UnregisterStateDriver = function() end
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta9"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE = n.Disenchant
	local function list() local t = {}; for _, e in ipairs(DE.entries or {}) do t[#t + 1] = e.name end; table.sort(t); return table.concat(t, ", ") end
	DE:Show(); M.runTimers()
	check(list() == "Rare Chest, Worn Dagger", "as it comes: the boots ItemTree keeps are held; the chest it keeps for its dust and the dagger Pawn likes are offered (" .. list() .. ")")
	n:Set("useItemTree", false); pump(M)
	check(list() == "Rare Chest, Worn Dagger", "Section and Filter Rules off: the boots are still held")
	n:Set("useItemTree", true); pump(M)
	n:Set("makeRoomHoldItemTree", false); n:Set("makeRoomHoldPawn", false); M.runTimers()
	check(list() == "Rare Chest, Worn Dagger", "the Loot Helper's two switches off: nothing changes here")
	n:Set("deHoldItemTree", false); M.runTimers()
	check(list() == "Rare Chest, Sturdy Boots, Worn Dagger", "ItemTree's Disenchant Helper switch off: the open Helper offers the boots at once (" .. list() .. ")")
	n:Set("deHoldPawn", true); M.runTimers()
	check(list() == "Rare Chest, Sturdy Boots", "Pawn's on: the dagger is held (" .. list() .. ")")
	n:Set("deHoldItemTree", true); M.runTimers()
	check(list() == "Rare Chest" and DE.held.total == 2 and DE.held.by.pawn[1] == "Worn Dagger" and DE.held.by.itemtree[1] == "Sturdy Boots", "both on: each held under its own addon's reason")
	check((n.errors or 0) == 0, "no errors")
	tidy()
end)()

-- ======== the page ========
for _, skin in ipairs({ "modern", "classic" }) do
	local S0 = skin .. ": "
	local function open(opts)
		opts = opts or {}; opts.skin = skin
		local n, M = boot(opts)
		local P = n.SettingsPanel
		P:Show(); P:ShowPage("addons"); M.runTimers()
		return n, M, P
	end
	local function y(w) return -(select(5, w:GetPoint(1))) end
	local function x(w) return (select(4, w:GetPoint(1))) end
	-- everything shown on the page, top to bottom: { kind, words, widget }
	local function rows(P)
		local t = {}
		for kind, pool in pairs(P.pools or {}) do
			for _, w in ipairs(pool) do
				if w:IsShown() then t[#t + 1] = { kind = kind, y = y(w), w = w, words = w.text and w.text.text or "" } end
			end
		end
		table.sort(t, function(a, b) return a.y < b.y end)
		return t
	end
	local function outline(P)
		local t = {}
		for _, r in ipairs(rows(P)) do
			if r.kind == "head" then t[#t + 1] = ("[%s | %s]"):format(r.words, r.w.state and r.w.state:IsShown() and r.w.state.text or "")
			elseif r.kind == "check" then t[#t + 1] = ("%s=%s"):format(r.words, r.w.box:GetChecked() and "on" or "off")
			elseif r.kind == "dropdown" then t[#t + 1] = ("%s: %s"):format(r.words, r.w.btn.label.text)
			elseif r.kind == "text" then t[#t + 1] = "\"" .. r.words .. "\"" end
		end
		return table.concat(t, " ")
	end
	local function row(P, kind, key) for _, w in ipairs(P.pools[kind] or {}) do if w:IsShown() and w.key == key then return w end end end
	local function head(P, name) for _, w in ipairs(P.pools.head or {}) do if w:IsShown() and w.text.text == name then return w end end end
	local INTRO = "\"BagSmith works with these addons when you have them. None is needed.\""
	local PRICES, TREE, PAWN = "\"Used for the AH Price column, item tooltips and both Helpers.\"", "\"Knows what your items are for on this character.\"", "\"Knows which gear is an upgrade for you. Its green arrows show on your icons.\""

	-- nothing installed: three cards, each its heading, state and sentence
	local n, M, P = open()
	check(outline(P) == INTRO .. " [Auction Prices | No price addon installed] " .. PRICES .. " \"Works with: Auctionator (not installed), Blackthornes Tradeskills (not installed)\""
		.. " [ItemTree | Not installed] " .. TREE .. " [Pawn | Not installed] " .. PAWN, S0 .. "nothing installed: each card is its heading, state and sentence (" .. outline(P) .. ")")
	local hs = head(P, "ItemTree")
	check((hs.state:GetPoint(1)) == "BOTTOMRIGHT" and select(2, hs.text:GetPoint(1)) ~= nil, S0 .. "the state sits at the right end of the heading's line")
	local mr, mg, mb = n.Skins:Color("muted")
	check(hs.state.textColor[1] == mr and hs.state.textColor[2] == mg and hs.state.textColor[3] == mb, S0 .. "Not installed is in the quiet color")
	P:Hide()

	-- everything installed
	local it, pawn = { facts = {} }, { upgrades = {} }
	n, M, P = open({ it = it, pawn = pawn, prices = { auctionator = true } })
	local HOLD_L, HOLD_D = "Hold Back in the Loot Helper", "Hold Back in the Disenchant Helper"
	check(outline(P) == INTRO .. " [Auction Prices | Using Auctionator] " .. PRICES .. " Auction Price Source: Automatic \"Works with: Auctionator (installed), Blackthornes Tradeskills (not installed)\""
		.. " [ItemTree | Installed] " .. TREE .. " Section and Filter Rules=on " .. HOLD_L .. "=on " .. HOLD_D .. "=on"
		.. " [Pawn | Installed] " .. PAWN .. " " .. HOLD_L .. "=on " .. HOLD_D .. "=off", S0 .. "everything installed: the page, top to bottom (" .. outline(P) .. ")")
	local tr, tg, tb = n.Skins:Color("text")
	hs = head(P, "ItemTree")
	check(hs.state.textColor[1] == tr and hs.state.textColor[2] == tg and hs.state.textColor[3] == tb, S0 .. "Installed is in the text color")
	-- the same job, the same words; every row a plain row (none indented under another), none greyed
	local checks = {}
	for _, r in ipairs(rows(P)) do if r.kind == "check" then checks[#checks + 1] = r.w end end
	local sameX, enabled = true, true
	for _, w in ipairs(checks) do if x(w) ~= x(checks[1]) then sameX = false end; if not w.box:IsEnabled() then enabled = false end end
	check(#checks == 5 and sameX and enabled, S0 .. "five switches, none indented under another, none greyed")
	check(row(P, "check", "useItemTree").help.text == "Adds rules such as Used by My Professions and Needed for a Quest."
		and row(P, "check", "makeRoomHoldItemTree").help.text == "Won't offer an item ItemTree says to keep."
		and row(P, "check", "deHoldItemTree").help.text == "Won't offer a piece ItemTree says to keep, unless it's kept for its dust.", S0 .. "ItemTree's three rows say what each does")
	check(row(P, "check", "makeRoomHoldPawn").help.text == "Won't offer a piece Pawn says is an upgrade." and row(P, "check", "deHoldPawn").help.text == "Won't offer a piece Pawn says is an upgrade.", S0 .. "Pawn's two rows too")
	local colored = false
	for _, r in ipairs(rows(P)) do
		if tostring(r.words):find("|c", 1, true) or (r.w.help and tostring(r.w.help.text or ""):find("|c", 1, true)) then colored = true end
	end
	check(not colored, S0 .. "no name is colored inside a sentence: the heading is the name")
	-- one switch, one thing
	local function tick(key, on) local w = row(P, "check", key); w.box:SetChecked(on); click(w.box); pump(M) end
	tick("useItemTree", false)
	check(n.db.useItemTree == false and n.db.makeRoomHoldItemTree == true and n.db.deHoldItemTree == true
		and row(P, "check", "makeRoomHoldItemTree").box:IsEnabled() and row(P, "check", "makeRoomHoldItemTree").box:GetChecked() and row(P, "check", "deHoldItemTree").box:IsEnabled(),
		S0 .. "Section and Filter Rules unticked: only that; the two Hold Back rows stay as they were, and yours")
	tick("useItemTree", true)
	tick("makeRoomHoldItemTree", false); tick("deHoldPawn", true); tick("makeRoomHoldPawn", false)
	check(n.db.makeRoomHoldItemTree == false and n.db.deHoldItemTree == true and n.db.deHoldPawn == true and n.db.makeRoomHoldPawn == false and n.db.useItemTree == true,
		S0 .. "each Hold Back row sets its own setting and no other")
	tick("makeRoomHoldItemTree", true); tick("deHoldPawn", false); tick("makeRoomHoldPawn", true)
	-- Auction Price Source: a list that names every price addon
	local dd = row(P, "dropdown", "priceSource")
	check(dd and dd.text.text == "Auction Price Source" and dd.help.text == "Automatic uses the first one you have, in the order listed.", S0 .. "Auction Price Source is a list, with its help")
	local menu
	local realMenu = n.ShowMenu
	n.ShowMenu = function(items) menu = items end
	click(dd.btn)
	local texts = {}
	for i, item in ipairs(menu) do texts[i] = item.text .. (item.disabled and " (can't be picked)" or "") .. (item.checked and " *" or "") end
	check(table.concat(texts, " | ") == "Automatic * | Auctionator | Blackthornes Tradeskills (not installed) (can't be picked)", S0 .. "its list: Automatic, then every price addon, one you don't have marked so (" .. table.concat(texts, " | ") .. ")")
	menu[2].onClick(); pump(M)
	dd = row(P, "dropdown", "priceSource")
	check(n.db.priceSource == "auctionator" and dd.btn.label.text == "Auctionator", S0 .. "picking Auctionator sets it")
	n.ShowMenu = realMenu
	-- the real menu doesn't let a greyed line be picked
	click(dd.btn)
	local mf = n.menuFrame
	local greyed
	for _, r in ipairs(mf.rows) do if r:IsShown() and r.text.text == "Blackthornes Tradeskills (not installed)" then greyed = r end end
	check(greyed and greyed.fn == nil, S0 .. "the real menu draws the addon you don't have as a line that does nothing")
	mf:Hide()
	n:Set("priceSource", "auto"); pump(M)
	P:Hide()

	-- a source chosen earlier that isn't installed any more
	n, M, P = open({ prices = { auctionator = true }, prof = { priceSource = "blackthornes" } })
	dd = row(P, "dropdown", "priceSource")
	check(dd.btn.label.text == "Blackthornes Tradeskills (not installed)" and dd.help.text == "Automatic uses the first one you have, in the order listed. Blackthornes Tradeskills isn't installed, so BagSmith uses Auctionator."
		and head(P, "Auction Prices").state.text == "Using Auctionator", S0 .. "a chosen source that's gone: the row says so, and what BagSmith uses instead")
	P:Hide()
	-- both price addons
	n, M, P = open({ prices = { auctionator = true, bts = true }, prof = { priceSource = "blackthornes" } })
	check(head(P, "Auction Prices").state.text == "Using Blackthornes Tradeskills" and outline(P):find("\"Works with: Auctionator (installed), Blackthornes Tradeskills (installed)\"", 1, true)
		and row(P, "dropdown", "priceSource").btn.label.text == "Blackthornes Tradeskills", S0 .. "both installed, Blackthornes chosen: the state, the list and the Works with line agree")
	P:Hide()
	-- the list is made from the price addons BagSmith knows: one more needs no change to the page
	n, M, P = open({ prices = { auctionator = true } })
	n.AH.SOURCES.testhouse = { name = "Test House", available = function() return true end, price = function() return 1 end, age = function() return 0 end, noPrice = "", column = "" }
	table.insert(n.AH.ORDER, "testhouse")
	P:Refresh(); M.runTimers()
	n.ShowMenu = function(items) menu = items end
	click(row(P, "dropdown", "priceSource").btn)
	check(#menu == 4 and menu[4].text == "Test House" and not menu[4].disabled and outline(P):find("Blackthornes Tradeskills (not installed), Test House (installed)\"", 1, true),
		S0 .. "a third price addon shows in the list and the Works with line by itself")
	n.AH.SOURCES.testhouse = nil; table.remove(n.AH.ORDER)
	P:Hide()

	-- Pawn there, its bag upgrade advisor off
	n, M, P = open({ pawn = { upgrades = {}, advisor = false } })
	check(outline(P):find("[Pawn | Installed, bag upgrade advisor off] " .. PAWN .. " \"Pawn's bag upgrade advisor is off, so it marks no upgrades for now. You can turn it on in Pawn's options.\" " .. HOLD_L .. "=on " .. HOLD_D .. "=off", 1, true),
		S0 .. "Pawn's advisor off: the state says so, a line says where to turn it on, and the rows stay (" .. outline(P) .. ")")
	P:Hide()

	-- the list on the left, and General
	local names, at = {}, nil
	for i, b in ipairs(P.navButtons) do names[i] = b.text.text; if b.text.text == "Other Addons" then at = i end end
	check(at and names[at - 1] == "Plugins" and names[at + 1] == "Profile", S0 .. "Other Addons is in the list, between Plugins and Profile")
	check(P.navButtons[at].icon and P.navButtons[at].icon.texture == "Interface\\AddOns\\BagSmith\\Media\\ui-set-addons.tga" and P.navButtons[at]:IsShown(), S0 .. "with its icon")
	P:Show(); P:ShowPage("general"); M.runTimers()
	local heads = {}
	for _, r in ipairs(rows(P)) do if r.kind == "head" then heads[#heads + 1] = r.words end end
	check(table.concat(heads, " | ") == "Opening BagSmith | Tooltips | Blizzard's Interface | Notices", S0 .. "General no longer has an Other Addons card (" .. table.concat(heads, " | ") .. ")")
	check(not row(P, "seg", "priceSource") and not row(P, "dropdown", "priceSource") and not row(P, "check", "useItemTree") and not row(P, "check", "deHoldPawn"), S0 .. "nor any of its rows")
	check(row(P, "check", "tipAHPrice") ~= nil, S0 .. "Show AH Price in Item Tooltips stays on General")
	-- the Loot Helper's page points here
	P:ShowPage("loothelper"); M.runTimers()
	check(outline(P):find("\"Favorites, gear-set items, quest items and items you protect are never suggested for destroying. Settings > Other Addons sets what Pawn and ItemTree hold back.\"", 1, true),
		S0 .. "Settings > Loot Helper says where Pawn's and ItemTree's holds are set")
	P:Hide()
	check((n.errors or 0) == 0, S0 .. "no errors")
	tidy()
end

;(function()
	-- the icon, the words elsewhere, the changelog
	local f = io.open("BagSmith/Media/ui-set-addons.tga", "rb"); local tga = f and f:read("*a"); if f then f:close() end
	check(tga and #tga > 18 and tga:byte(13) + tga:byte(14) * 256 == 64 and tga:byte(15) + tga:byte(16) * 256 == 64 and tga:byte(17) == 32, "the page's icon is a 64 by 64 picture with its own clear background, like the other pages' icons")
	f = io.open("BagSmith/Media/ui-set-plugins.tga", "rb"); local ref = f:read("*a"); f:close()
	check(tga:byte(3) == ref:byte(3) and tga:byte(18) == ref:byte(18), "saved the same way as theirs")
	f = io.open("BagSmith/Frames/SettingsPanel.lua"); local src = f:read("*a"); f:close()
	local _, tips = src:gsub("Auction Price Source is in Settings > Other Addons%.", "")
	check(tips == 2 and not src:find("is in General.", 1, true), "the AH Price column's tips say where Auction Price Source is now")
	check(not src:find("Use ItemTree", 1, true) and not src:find("itemTreeHold", 1, true) and not src:find("|cff9fe6e1", 1, true), "Use ItemTree, the one hold switch and the inline color are gone from Settings")
	f = io.open("BagSmith/Frames/WhatsNew.lua"); local wn = f:read("*a"); f:close()
	check(wn:find("pick one in Settings > Other Addons > Auction Prices.", 1, true) and not wn:find("Settings > General > Price Source", 1, true), "What's New's older line about price addons points at the new page")
	f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	local section = ("\n" .. log):match("\n(## 1%.10%.0\n.-)\n## 1%.9%.8\n") or ""
	check(section:find("A new Settings page, Other Addons,", 1, true) and section:find("each Helper has its own switch in Settings > Other Addons", 1, true), "the changelog's 1.10.0 section: the Other Addons page, a switch per Helper")
	check(section:find("Price Source moved from Settings > General to the new Other Addons page, and is now called Auction Price Source.", 1, true)
		and section:find("The Loot Helper holding back Pawn upgrades is a switch now, in Settings > Other Addons. It's on, as before.", 1, true), "Price Source's move and Pawn's new switch")
	check(not section:find("Settings > General turns it", 1, true) and not section:find("Use ItemTree", 1, true), "and nothing still points at General or Use ItemTree")
	check(not section:find("\226\128\148") and not section:find("\226\128\147"), "with no dashes")
end)()
