-- ======== 1.10.0-beta14 (Shweep, 23 Nov: "1. leave as is and say so as you recommend 2. agreed 3. both are fine / okay build") ========
-- The answer to the beta13 re-audit, finding by finding:
-- R1  A lookup still waiting in ItemTree's queue for an item that has left is cancelled; before, it answered for the
--     absent item and that answer was found when a copy came back.
-- R2  The Usable by Me quick pick in the Filters window follows a level gained, as the rule does.
-- R3  A saved row keeps "quality not known" and "name not known"; a row saved before those marks, with a made-up
--     name beside Common, isn't read as a known Common either.
-- R4  (a) The old Type condition is named wherever older conditions are. (b) The Quality chips don't count a quality
--     that isn't known, as the rule they become doesn't. (c) An old condition with more choices than a rule holds
--     isn't folded into one.
-- R5  (a) An open Helper draws its list again when ItemTree says its answers changed, and looks again by itself while
--     items wait; they wait under a heading that names ItemTree. (b) After a read that failed at the click, the list
--     no longer leans on the answer held before.
-- R6  Clear Soul Shards doesn't ask ItemTree: Shweep's decision ("leave as is and say so"), said in the Hold Back
--     help line and the changelog.

local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function deep(t) if type(t) ~= "table" then return t end local c = {}; for k, v in pairs(t) do c[k] = deep(v) end; return c end
local function click(b) b:GetScript("OnClick")(b) end
local function pump(M) for _ = 1, 40 do M.runTimers() end end
local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
local function find(list, id) for _, r in ipairs(list or {}) do if r.itemID == id then return r end end end
local function names(list) local t = {}; for i, v in ipairs(list or {}) do t[i] = v end; table.sort(t); return table.concat(t, ", ") end

-- ItemTree's answer about one item: its Keep mark, its state, and whether one of your professions uses it.
local function fact(id, marked, state, prof)
	return { itemId = id, known = true,
		keep = { marked = marked, state = state or (marked and "keep" or "vendor"), tags = { marked and "keep" or "vendor" } },
		route = { needed = false }, vendors = { buyPrice = 10, everywhere = false, count = 0 },
		uses = { reagentSkills = prof and { 197 } or {}, kinds = { reagent = 0 } }, quests = { needs = {} } }
end
-- ItemTree as BagSmith meets it (the beta13 set's stand-in): ready = false, raise, silent and odd are the ways it can
-- fail; otherwise it answers as the real one does, with a table for an item it has no data for.
local function fakeItemTree(state)
	state.calls, state.asked, state.requested = 0, {}, 0
	return {
		version = 1,
		IsReady = function() return state.ready ~= false end,
		RequestData = function() state.requested = state.requested + 1 end,
		RegisterReadyCallback = function(fn) state.onReady = fn end,
		RegisterChangeCallback = function(fn) state.onChange = fn end,
		GetItemFacts = function(id)
			state.calls = state.calls + 1
			state.asked[id] = (state.asked[id] or 0) + 1
			if state.raise then error("ItemTree broke") end
			if state.silent then return nil end
			if state.odd then return "?" end
			return deep(state.facts[id]) or { itemId = id, known = false }
		end,
	}
end

-- ======== R1: a lookup still waiting when the item leaves ========
;(function()
	package.loaded.mock = nil
	local M = require("mock")
	M.removeEquipmentSets()
	M.sizes[0] = 16
	M.put(0, 1, { id = 2996, name = "Bolt of Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 10, ilvl = 10 })
	M.put(0, 2, { id = 6530, name = "Nightcrawlers", q = 1, count = 4, class = 0, subclass = 8, type = "Consumable", sub = "Other", price = 25, ilvl = 10 })
	local it = { facts = { [2996] = fact(2996, true, nil, true), [6530] = fact(6530, false), [2304] = fact(2304, true, nil, true) } }
	_G.ItemTreeAPI = fakeItemTree(it)
	_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", view = "list", grp = "type" } } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta14"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local IT, S = n.ItemTree, n.Sections
	local kit = { id = 2304, name = "Light Armor Kit", q = 1, count = 1, class = 7, subclass = 6, type = "Trade Goods", sub = "Other", price = 6 }
	local function inSection(id)
		local t = {}
		for _, r in ipairs(n.items) do if r.itemID and r.cat == id then t[#t + 1] = r.name end end
		table.sort(t)
		return table.concat(t, ", ")
	end

	-- (control) asked, and still yours when the answer comes
	M.put(0, 3, kit); n:Scan()
	check(IT:Facts(recOf(n, 2304)) == nil and select(2, IT:Count()) == 1, "(a new item is asked about; its answer is on its way)")
	pump(M)
	check(IT:Facts(recOf(n, 2304)).tags[1] == "keep" and it.asked[2304] == 1, "(control) still yours when the answer comes: it is kept")
	M.bags[0][3] = nil; n:Scan(); pump(M)
	check(IT:Count() == 0, "(it leaves: let go, as since beta13)")

	-- the first lookup is still waiting when the last copy leaves
	M.put(0, 3, kit); n:Scan()
	check(IT:Facts(recOf(n, 2304)) == nil and select(2, IT:Count()) == 1, "(asked about again; the answer is on its way)")
	M.bags[0][3] = nil; n:Scan()
	pump(M)
	check(it.asked[2304] == 1 and IT:Count() == 0, "it leaves before the answer comes: the lookup is cancelled. ItemTree isn't asked about an item you no longer hold, and nothing is kept for it (asked " .. tostring(it.asked[2304]) .. " time in all)")
	it.facts[2304] = fact(2304, false)   -- ItemTree changes its mind meanwhile, with no word
	M.put(0, 3, kit); n:Scan()
	check(IT:Facts(recOf(n, 2304)) == nil, "a copy comes back: there is no old answer to find")
	pump(M)
	check(IT:Facts(recOf(n, 2304)).tags[1] == "vendor" and it.asked[2304] == 2, "it is asked about, and ItemTree's answer now is the one used (" .. tostring(IT:Facts(recOf(n, 2304)).tags[1]) .. ")")

	-- the same when a rule asks during the look at the bags (the order the game gives: asked first, then seen as yours)
	it.facts[2304] = fact(2304, true, nil, true)
	it.onChange("stock"); pump(M)   -- (ItemTree says so, which lets the answer held go)
	local mats = S:CreateWithRules("Profession Mats", { mode = "all", rows = { { k = "it_prof", v = { "yes" } } } }); pump(M)
	check(inSection(mats) == "Bolt of Linen Cloth, Light Armor Kit", "(a section, Used by My Professions: the cloth and the kit, " .. inSection(mats) .. ")")
	M.bags[0][3] = nil; n:Scan(); pump(M)
	local asked = it.asked[2304]
	M.put(0, 3, kit); n:Scan()   -- the section's rule asks about the kit while the bags are read
	check(select(2, IT:Count()) >= 1 and recOf(n, 2304).cat ~= mats, "(the kit is back and the rule has asked; no answer yet, so it waits outside the section)")
	M.bags[0][3] = nil; n:Scan()   -- and it is gone again before the answer
	pump(M)
	check(it.asked[2304] == asked, "asked by a rule, gone before the answer: cancelled too")
	it.facts[2304] = fact(2304, false)
	M.put(0, 3, kit); n:Scan(); pump(M)
	check(it.asked[2304] == asked + 1 and recOf(n, 2304).cat ~= mats, "back again: asked afresh, and with ItemTree's new answer the kit stays out of the section")

	-- a re-ask still waiting when the last copy leaves (ItemTree's own notice, then a stack that changed size)
	it.facts[2304] = fact(2304, true, nil, true)
	it.onChange("stock"); pump(M)
	check(recOf(n, 2304).cat == mats, "(ItemTree says its answers changed, and now a profession uses the kit: it joins the section)")
	asked = it.asked[2304]
	it.onChange("stock")           -- every answer is asked for again: the kit's is waiting in the queue
	M.bags[0][3] = nil; n:Scan()   -- and the kit leaves before its turn
	pump(M)
	check(it.asked[2304] == asked and recOf(n, 2304) == nil, "a re-ask waiting when the last copy leaves: cancelled, and ItemTree isn't asked")
	it.facts[2304] = fact(2304, false)
	M.put(0, 3, kit); n:Scan(); pump(M)
	check(it.asked[2304] == asked + 1 and recOf(n, 2304).cat ~= mats, "it comes back: asked afresh; the answer held before the re-ask is not found again")
	it.facts[2304] = fact(2304, true, nil, true)
	it.onChange("stock"); pump(M)
	asked = it.asked[2304]
	kit.count = 2; n:Scan()        -- the stack changes size: asked again
	M.bags[0][3] = nil; n:Scan()   -- and leaves before the answer
	pump(M)
	check(it.asked[2304] == asked, "the same after a stack changed size: cancelled")
	kit.count = 1
	-- the others were never disturbed
	check(inSection(mats) == "Bolt of Linen Cloth", "the cloth, which never left, is where it was (" .. inSection(mats) .. ")")
	S:Delete(mats); pump(M)

	-- a row read from saved data (the bank away from the bank) was never among your items: it is answered all the same
	local saved = { itemID = 4000, link = "|cffffffff|Hitem:4000|h[Odd Trinket]|h|r", name = "Odd Trinket" }
	it.facts[4000] = fact(4000, true)
	check(IT:Facts(saved) == nil, "(a saved row is asked about)")
	n:Scan()   -- the bags are looked at while it waits
	pump(M)
	check(it.asked[4000] == 1, "a saved row's lookup is not cancelled by a look at the bags: it was never one of the items held")
	check(it.requested == 0 and (n.errors or 0) == 0, "no errors, and ItemTree was never asked to load anything")
	_G.ItemTreeAPI = nil
end)()

-- ======== R2: the Usable by Me quick pick and a level gained ========
;(function()
	local level = 20
	package.loaded.mock = nil
	local M = require("mock")
	M.removeEquipmentSets()
	M.put(0, 1, { id = 9010, name = "Journeyman Staff", q = 2, count = 1, class = 2, subclass = 10, type = "Weapon", sub = "Staves", equip = "INVTYPE_2HWEAPON", bind = 2, price = 500, ilvl = 26, req = 21 })
	M.put(0, 2, { id = 9011, name = "Novice Wand", q = 2, count = 1, class = 2, subclass = 19, type = "Weapon", sub = "Wands", equip = "INVTYPE_RANGEDRIGHT", bind = 2, price = 300, ilvl = 15, req = 10 })
	_G.UnitLevel = function() return level end
	_G.C_TooltipInfo = { GetHyperlink = function() return { lines = { { leftText = "Weapon" }, { leftText = "Durability" } } } end }
	_G.ItemTreeAPI = nil
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", view = "list", grp = "type" } } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta14"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); pump(M)
	n.Window:Show(); pump(M)
	local main, P, S, U = n.Window.main, n.Popups, n.Sections, n.Usability
	local shown
	local realCount = P.UpdateCount
	P.UpdateCount = function(self, v, count, total) if v == main and count then shown = count end return realCount(self, v, count, total) end
	P:OpenFilters(main, "browse"); pump(M)
	local usable
	for _, c in ipairs(P.filter.checks or {}) do if c.groupKey == "usable" then usable = c end end
	check(usable ~= nil and usable:GetScript("OnClick") ~= nil, "(the Filters window has its Usable by Me quick pick)")
	check(U.RuleWanted() == false, "(nothing asks whether items are usable yet)")
	click(usable); pump(M)
	check(main.st.filters.usable == true and main.st.filters.rules == nil and shown == 1, "Usable by Me, clicked: at level 20 the wand shows and the staff, which needs 21, doesn't (" .. tostring(shown) .. " shown)")
	check(U.RuleWanted() == true, "the quick pick counts as asking, with no rule anywhere")
	local reapplied = 0
	local realRe = S.Reapply
	S.Reapply = function(...) reapplied = reapplied + 1; return realRe(...) end
	level = 21
	M.fire("PLAYER_LEVEL_UP", 21); pump(M)
	check(reapplied == 1 and shown == 2, "level 21: the list is looked at again by itself, once, and the staff shows (" .. reapplied .. " look, " .. tostring(shown) .. " shown)")
	-- skills and spells with the same answers: nothing is redone, as for a rule
	reapplied = 0
	M.fire("SKILL_LINES_CHANGED"); pump(M); M.fire("SPELLS_CHANGED"); pump(M)
	check(reapplied == 0 and shown == 2, "a skill or a spell changing with the same answers: nothing is redone")
	-- unticked: nothing asks any more
	click(usable); pump(M)
	check(main.st.filters.usable ~= true and U.RuleWanted() == false, "(unticked: nothing asks)")
	reapplied = 0
	level = 22
	M.fire("PLAYER_LEVEL_UP", 22); pump(M)
	check(reapplied == 0, "and a level gained asks nothing of the list")
	S.Reapply = realRe
	P.UpdateCount = realCount
	P.filter:Hide()
	check((n.errors or 0) == 0, "no errors")
	_G.UnitLevel = function() return 23 end
end)()

-- ======== R3 and R4: saved rows, the Quality chips, the old Type condition, a field too wide for a rule ========
;(function()
	package.loaded.mock = nil
	local M = require("mock")
	M.removeEquipmentSets()
	M.sizes[0] = 16
	M.put(0, 1, { id = 4306, name = "Silk Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 150 })
	M.put(0, 2, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 13 })
	M.put(0, 3, { id = 2447, name = "Peacebloom", q = 1, count = 5, class = 7, subclass = 9, type = "Trade Goods", sub = "Herb", price = 10 })
	M.put(-1, 1, { id = 4338, name = "Mageweave Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 250 })
	_G.ItemTreeAPI = nil
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", view = "list", grp = "type" } } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta14"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); pump(M)
	local R, P, main = n.Rules, n.Popups, n.Window.main
	local common = R.Clean({ mode = "all", rows = { { k = "quality", v = { 1 } } } })
	local notUncommon = R.Clean({ mode = "all", rows = { { k = "quality", v = { 2 }, n = true } } })
	local notCloth = R.Clean({ mode = "all", rows = { { k = "name", v = { "cloth" }, n = true } } })
	local chip = n.CleanFilters({ q = { [1] = true } })

	-- one meaning for "the quality is known"
	check(R.QualityKnown({ itemID = 1, name = "Real Thing", quality = 1 }) == true and R.QualityKnown({ itemID = 1, name = "Real Thing", quality = 1, qualityUnknown = true }) == false
		and R.QualityKnown({ itemID = 1, name = "Real Thing" }) == false, "a quality is known when the game gave it: not when it is marked unknown, not when there is none")
	check(R.QualityKnown({ itemID = 17, name = "Item 17", quality = 1 }) == false and R.QualityKnown({ itemID = 17, name = "?", quality = 1 }) == false and R.QualityKnown({ itemID = 17, name = "Item 17", quality = 3 }) == true,
		"nor a Common beside a made-up name, which is how a row saved before the marks looks. A rare beside one came from the bag itself.")

	-- R3: the bags and the bank, saved while the game hasn't sent two of the items, and read back
	local realSlot = C_Container.GetContainerItemInfo
	C_Container.GetContainerItemInfo = function(bag, slot)
		local i = realSlot(bag, slot)
		if i and (i.itemID == 4306 or i.itemID == 4338) then i.hyperlink, i.quality = nil, nil end
		return i
	end
	-- (by design since 1.10.0-beta16, the beta15 audit's B15-1: the scanner now keeps the link an item instance was
	-- last read with, so holding the link back from a slot that has already been read no longer makes it nameless.
	-- These checks are about a slot the game has NOT described yet, as after a login: what was kept is cleared first.)
	for g in pairs(n.instanceLinks) do n.instanceLinks[g] = nil end
	M.uncached[4306], M.uncached[4338] = true, true
	M.fire("BANKFRAME_OPENED"); M.runTimers(); M.runTimers()
	n:Scan()
	local live = recOf(n, 4306)
	local liveBank = find(n.bankItems, 4338)
	check(live and live.qualityUnknown == true and live.nameUnknown == true and liveBank and liveBank.qualityUnknown == true, "(two items the game hasn't sent, one in the bags and one in the bank: shown as Common, marked not known)")
	check(not R:Fits(common, live) and not R:Fits(notUncommon, live), "(live: Quality is Common and Quality is not Uncommon both wait)")
	n:SaveCache()
	local key = n:CharKey()
	for _, where in ipairs({ "bags", "bank" }) do
		local id = where == "bank" and 4338 or 4306
		local saved = find(n:CachedRecords(key, where == "bank"), id)
		check(saved and saved.qualityUnknown == true and saved.nameUnknown == true and saved.quality == 1, where .. ": saved and read back, it is still marked: its quality and name are not known")
		check(not R:Fits(common, saved) and not R:Fits(notUncommon, saved) and not R:Fits(notCloth, saved), where .. ": no Quality rule and no Name rule reads the saved row as a Common item named Item " .. id)
		check(n:FilterPredicate(chip)(saved) == false, where .. ": nor does the Common chip")
	end
	local raw = find(n:SavedBank(), 4338)
	check(raw and raw.qualityUnknown == true and not R:Fits(common, raw), "the bank's saved rows as the section preview reads them carry the mark too")
	-- a known item saved beside them reads back as it was
	local linen = find(n:CachedRecords(key, false), 2589)
	check(linen and not linen.qualityUnknown and not linen.nameUnknown and R:Fits(common, linen) and n:FilterPredicate(chip)(linen) == true, "(a Common item the game has described is saved and read back as Common)")
	-- rows saved before the marks existed, and rows with gaps
	local items = BagSmithDB.cache[key].items
	items[#items + 1] = { itemID = 17, name = "Item 17", quality = 1, count = 1, bag = 0, slot = 9 }
	items[#items + 1] = { itemID = 18, name = "Real Thing", quality = 1, count = 1, bag = 0, slot = 10 }
	items[#items + 1] = { itemID = 19, count = 1, bag = 0, slot = 11 }
	items[#items + 1] = { itemID = 20, name = "Item 20", quality = 3, count = 1, bag = 0, slot = 12 }
	local old = n:CachedRecords(key, false)
	local made, real, bare, rare = find(old, 17), find(old, 18), find(old, 19), find(old, 20)
	check(made and not R:Fits(common, made) and not R:Fits(notUncommon, made) and n:FilterPredicate(chip)(made) == false, "a row saved before the marks, Common beside the made-up name Item 17: not read as a known Common")
	check(real and R:Fits(common, real) and n:FilterPredicate(chip)(real) == true, "one with a real name and Common is")
	check(bare and bare.qualityUnknown == true and bare.nameUnknown == true and bare.name == "?" and bare.quality == 1 and not R:Fits(common, bare) and not R:Fits(notCloth, bare),
		"a row with no quality and no name at all is shown as ? and Common, marked, and fits no rule about either")
	check(rare and R:Fits(R.Clean({ mode = "all", rows = { { k = "quality", v = { 3 } } } }), rare) and not R:Fits(notCloth, rare), "a rare beside a made-up name: its quality came from the bag and counts; its name still doesn't")
	-- a worn item the game hasn't described (Global Inventory's rows)
	local worn = n.Inventory.WornRecord({ itemID = 4338 })
	check(worn.qualityUnknown == true and worn.nameUnknown == true and not R:Fits(common, worn), "a worn item the game hasn't described: Common and its name are only for showing")
	C_Container.GetContainerItemInfo = realSlot
	M.uncached[4306], M.uncached[4338] = nil, nil
	local wornKnown = n.Inventory.WornRecord({ itemID = 4306, link = "|Hitem:4306|h[Silk Cloth]|h" })
	check(not wornKnown.qualityUnknown and not wornKnown.nameUnknown, "(one it has described carries no mark)")
	n:Scan(); pump(M)
	n:SaveCache()
	local again = find(n:CachedRecords(key, false), 4306)
	check(again and not again.qualityUnknown and not again.nameUnknown and again.name == "Silk Cloth" and R:Fits(common, again), "the game sends the item: saved again, the marks are gone and it is a Common Silk Cloth")

	-- R4b: the Quality chips and the rule Save as Section... makes of them mean the same
	local pending = { itemID = 500, name = "Item 500", quality = 1, qualityUnknown = true, nameUnknown = true }
	local known = { itemID = 501, name = "Plain Thing", quality = 1 }
	local converted, note = P:SectionRules(chip)
	check(converted and #converted.rows == 1 and converted.rows[1].k == "quality" and note == nil, "(the Common chip becomes the rule Quality is Common)")
	check(n:FilterPredicate(chip)(pending) == false and R:Fits(converted, pending) == false, "an item whose quality isn't known: left out by the chip, and by the rule. The same answer either way.")
	check(n:FilterPredicate(chip)(known) == true and R:Fits(converted, known) == true, "a known Common item: shown by both")
	check(n:FilterPredicate(n.CleanFilters({ q = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true } }))(pending) == false, "every chip ticked still leaves it out until its quality is known")
	check(n:FilterPredicate(n.EmptyFilters())(pending) == true, "(with no chip ticked it shows, as everything does)")

	-- R4a: the old Type condition
	local herb = { itemID = 700, name = "Linen-scented herb", itemSubType = "Herb", quality = 1, cat = "Other" }
	local cloth = { itemID = 701, name = "Linen scrap", itemSubType = "Cloth", quality = 1, cat = "Other" }
	local typed = n.CleanFilters({ t = { Cloth = true }, rules = { mode = "all", rows = { { k = "name", v = { "Linen" } } } } })
	check(n:FilterPredicate(typed)(herb) == false and n:FilterPredicate(typed)(cloth) == true, "(a filter from long ago: Type is Cloth, beside a Name rule. The herb is left out, the cloth shows.)")
	check(table.concat(n.UnfoldedWords(typed), ",") == "Type", "the old Type condition is named")
	local folded = n.FoldFilters(typed)
	check(next(folded.t) ~= nil and n:FilterPredicate(folded)(herb) == false and table.concat(n.UnfoldedWords(folded), ",") == "Type", "it never becomes a rule: it stays, still applies, and is still named after the window's fold")
	converted, note = P:SectionRules(typed)
	check(converted and #converted.rows == 1 and converted.rows[1].k == "name" and note == "Left out, kept from an older version: Type.", "Save as Section...: the Name rule comes along, and the note says Type stayed behind (" .. tostring(note) .. ")")
	check(R:Fits(converted, herb) == true, "(the section would take the herb the filter left out: hence the note)")
	main.st.filters = typed
	P:OpenFilters(main, "browse"); pump(M)
	local f = P.filter
	check(f.older:IsShown() and f.older.text == "This filter also narrows by Type, kept from an older version. That still applies, though it can't be shown as a rule here. Clear All removes it.",
		"the Filters window says so (" .. tostring(f.older.text) .. ")")
	-- beside an older Section box under "all of these": the box becomes a rule, Type is what's left to name
	main.st.filters = n.CleanFilters({ t = { Cloth = true }, cat = { ["Trade Goods"] = true } })
	P:SyncFilters(); pump(M)
	check(f.older:IsShown() and f.older.text:find("also narrows by Type, kept", 1, true) ~= nil and #f.list.draft.rows == 1 and f.list.draft.rows[1].k == "sec", "beside an old Section box: the box shows as a rule, and the line names Type alone")
	click(f.clearBtn); pump(M)
	check(not f.older:IsShown() and not next(main.st.filters.t), "Clear All removes it")

	-- R4c: more choices than a rule holds
	local selected = {}
	for i = 101, 141 do selected["c" .. i] = true end
	local wide = n.CleanFilters({ cat = selected })
	local last = { itemID = 702, name = "Known gear", cat = "c141", quality = 2 }
	local first = { itemID = 703, name = "Other gear", cat = "c101", quality = 2 }
	local outside = { itemID = 704, name = "Elsewhere", cat = "c999", quality = 2 }
	check(R.MAX_VALUES == 40 and n:FilterPredicate(wide)(last) == true and n:FilterPredicate(wide)(first) == true and n:FilterPredicate(wide)(outside) == false, "(an old Section box with 41 sections ticked; a rule holds 40 choices)")
	local kept = n.FoldFilters(wide)
	local count = 0
	for _ in pairs(kept.cat) do count = count + 1 end
	check(kept == wide and count == 41 and kept.rules == nil, "it isn't folded into a rule, which would have dropped the 41st: all 41 stay")
	check(n:FilterPredicate(kept)(last) == true and n:FilterPredicate(kept)(first) == true and n:FilterPredicate(kept)(outside) == false, "and it filters the same before and after the Filters window opens")
	check(table.concat(n.UnfoldedWords(kept), ",") == "Section", "the window's line names it: Section")
	main.st.filters = wide
	P:SyncFilters(); pump(M)
	check(f.older:IsShown() and f.older.text:find("also narrows by Section, kept", 1, true) ~= nil and #f.list.draft.rows == 0, "the Filters window: no rule row, and the line saying it still applies")
	converted, note = P:SectionRules(wide)
	check(converted == nil and note == "Left out, kept from an older version: Section.", "Save as Section... names it too (" .. tostring(note) .. ")")
	-- (control) forty fold as before, every one kept
	local forty = {}
	for i = 101, 140 do forty["c" .. i] = true end
	local fits = n.FoldFilters(n.CleanFilters({ cat = forty }))
	check(fits.rules and #fits.rules.rows == 1 and #fits.rules.rows[1].v == 40 and not next(fits.cat) and #n.UnfoldedWords(fits) == 0, "(control) forty choices become one rule with all forty, and nothing is left to name")
	check(n:FilterPredicate(fits)({ itemID = 705, name = "Gear", cat = "c140", quality = 2 }) == true, "(control) the fortieth still fits")
	main.st.filters = n.EmptyFilters(); P:SyncFilters(); f:Hide()
	M.fire("BANKFRAME_CLOSED"); pump(M)
	check((n.errors or 0) == 0, "no errors")
end)()

-- ======== R5 and R6: the Disenchant Helper ========
;(function()
	local function deBoot(it)
		package.loaded.mock = nil
		local M = require("mock")
		M.removeEquipmentSets()
		local DEID = 13262
		M.put(0, 1, { id = 15012, name = "Lupine Slippers of the Falcon", q = 2, count = 1, class = 4, subclass = 2, price = 296, ilvl = 16, equip = "INVTYPE_FEET", bind = 2 })
		M.put(0, 2, { id = 5387, name = "Enchanted Moonstalker Cloak", q = 2, count = 1, class = 4, subclass = 1, price = 150, ilvl = 20, equip = "INVTYPE_CLOAK" })
		M.put(0, 3, { id = 7003, name = "Rare Chest", q = 3, count = 1, class = 4, subclass = 2, price = 2000, ilvl = 45, equip = "INVTYPE_CHEST" })
		_G.ItemTreeAPI = it and fakeItemTree(it) or nil
		_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
		_G.IsSpellKnown = function(id) return id == DEID end
		_G.GetNumSkillLines = function() return 2 end
		_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, 300 end
		_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
		_G.RegisterStateDriver = function() end
		_G.UnregisterStateDriver = function() end
		local n = M.loadAddon("BagSmith")
		n.version = "1.10.0-beta14"
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M, n.Disenchant
	end
	local function offeredNames(DE) local t = {}; for _, e in ipairs(DE.entries or {}) do t[#t + 1] = e.name end; table.sort(t); return table.concat(t, ", ") end
	local function entry(DE, id) for _, e in ipairs(DE.entries or {}) do if e.itemID == id then return e end end end
	local function facts() return { [15012] = fact(15012, true, "keepDisenchant"), [5387] = fact(5387, false) } end
	local ALL = "Enchanted Moonstalker Cloak, Lupine Slippers of the Falcon, Rare Chest"
	local delays = {}
	local function watchTimers()
		local real = C_Timer.After
		C_Timer.After = function(d, fn) delays[#delays + 1] = d; return real(d, fn) end
	end
	local function retries() local k = 0; for _, d in ipairs(delays) do if d == 3 then k = k + 1 end end; return k end

	-- (a) ItemTree is ready and, for a while, answers nothing
	local it = { facts = facts(), silent = true }
	local n, M, DE = deBoot(it)
	local IT = n.ItemTree
	watchTimers()
	DE:Show(); M.runTimers()
	check(offeredNames(DE) == "" and names(DE.held.by.itemtreewait) == ALL and DE.held.by.unknown == nil, "ItemTree ready but answering nothing: all three wait, under their own reason (" .. names(DE.held.by.itemtreewait) .. ")")
	local lines = n.Why:Lines(DE.held)
	check(#lines == 1 and plain(lines[1]):find("^Waiting for ItemTree %(3%): ") ~= nil, "Not offered: Waiting for ItemTree (3), which names the addon they wait for (" .. plain(lines[1]) .. ")")
	check(IT.RETRY == 3 and retries() >= 1, "and the open Helper has set itself to look again in 3 seconds")
	-- it recovers and says its answers changed: no click, no manual refresh
	it.silent = nil
	local before = it.calls
	it.onChange("stock"); M.runTimers(); M.runTimers()
	check(offeredNames(DE) == ALL and (DE.held.total or 0) == 0 and it.calls > before, "ItemTree answers again and says its answers changed: the open Helper asks and offers all three by itself (" .. offeredNames(DE) .. ")")
	-- nothing waits: it stops looking
	pump(M)
	local calls, looked = it.calls, retries()
	pump(M)
	check(it.calls == calls and retries() == looked, "with nothing waiting it stops looking: ItemTree isn't asked again and no timer is set")
	-- a failure that comes and goes with no word from ItemTree
	it.silent = true
	it.onChange("stock"); M.runTimers(); M.runTimers()
	check(offeredNames(DE) == "" and #DE.held.by.itemtreewait == 3, "(it fails again: all three wait)")
	it.silent = nil
	M.runTimers(); M.runTimers()
	check(offeredNames(DE) == ALL, "the failure passes with no word from ItemTree: the Helper's own look finds the answers, and offers all three (" .. offeredNames(DE) .. ")")
	-- closed: it doesn't keep looking
	it.silent = true
	it.onChange("stock"); M.runTimers(); M.runTimers()
	check(#DE.held.by.itemtreewait == 3, "(waiting again)")
	DE:Close(); M.runTimers(); M.runTimers()
	calls = it.calls
	pump(M)
	check(it.calls == calls, "the Helper closed: ItemTree isn't asked while nobody is looking")
	it.silent = nil
	DE:Show(); M.runTimers()
	check(offeredNames(DE) == ALL, "(opened again: all three)")

	-- (b) a "clear" that the click could not confirm is no longer leaned on
	local cloak = entry(DE, 5387)
	check(cloak and DE:LiveCheck(cloak) == true, "(the cloak is offered and passes at the click)")
	it.silent = true
	local ok, why = DE:LiveCheck(cloak)
	check(ok == false and tostring(why):find("ItemTree couldn't be asked about that item just now", 1, true) ~= nil, "ItemTree fails at the click: refused")
	check(IT:Facts(recOf(n, 5387)) ~= nil and IT:Facts(recOf(n, 5387)).kept == false, "the answer held before is kept for the rules")
	DE:Refresh()
	check(entry(DE, 5387) == nil and names(DE.held.by.itemtreewait) == "Enchanted Moonstalker Cloak", "the list drawn again doesn't offer the cloak on the strength of the old answer: it waits (" .. offeredNames(DE) .. ")")
	check(offeredNames(DE) == "Lupine Slippers of the Falcon, Rare Chest", "the two whose answers no click has put in doubt are offered as before")
	it.silent = nil
	M.runTimers(); M.runTimers()
	check(offeredNames(DE) == ALL and (DE.held.total or 0) == 0, "ItemTree answers again: the cloak is offered again by itself")
	-- the same through the button, as the re-audit ran it: disarmed at the click, and not armed again on that piece
	local top = DE.current
	check(top ~= nil and DE.button:GetAttribute("type") ~= nil, "(the Helper is armed on its first piece)")
	it.silent = true
	DE.button:GetScript("PreClick")(DE.button)
	check(DE.button:GetAttribute("type") == nil and DE.current == nil, "ItemTree fails as the button is pressed: disarmed, nothing cast")
	M.runTimers()
	check(entry(DE, top.itemID) == nil and (DE.current == nil or DE.current.itemID ~= top.itemID), "the next frame's list doesn't arm the same piece again: it waits for ItemTree")
	check(names(DE.held.by.itemtreewait):find(top.name, 1, true) ~= nil, "under Waiting for ItemTree (" .. names(DE.held.by.itemtreewait) .. ")")
	it.silent = nil
	M.runTimers(); M.runTimers()
	check(entry(DE, top.itemID) ~= nil, "and comes back by itself once ItemTree answers")
	check(it.requested == 0 and (n.errors or 0) == 0, "no errors, and ItemTree was never asked to load anything")
	DE:Close()
	_G.ItemTreeAPI = nil
end)()

-- ======== R5 and R6: the Loot Helper, and Clear Soul Shards ========
do
	local loot = {}
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("|Hitem:" .. loot[i].id .. ":0|h[" .. loot[i].name .. "]|h") end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, l.qty or 1, nil, l.q or 1 end end
	_G.LootSlot = function() end
	local deleted = 0
	_G.DeleteCursorItem = function() deleted = deleted + 1 end
	local INFO = { [9740] = { "Rough Gem", 1, 1, 30 }, [9701] = { "Broken Fang", 0, 1, 3 }, [9702] = { "Linen Belt", 1, 1, 22 }, [9720] = { "Gnoll Paw", 1, 20, 2 },
		[9730] = { "Heavy Stone", 1, 20, 50 }, [9731] = { "Fine Ring", 1, 1, 80 } }
	local function lootBoot(it, skin)
		package.loaded.mock = nil
		local M = require("mock")
		M.removeEquipmentSets()
		_G.UnitClass = function() return "Warrior", "WARRIOR" end
		M.sizes[0] = 5
		for b = 1, 5 do M.sizes[b] = 0 end
		M.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
		M.put(0, 2, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
		M.put(0, 3, { id = 9720, name = "Gnoll Paw", q = 1, count = 5, stack = 20, class = 15, subclass = 0, price = 2 })
		M.put(0, 4, { id = 9730, name = "Heavy Stone", q = 1, count = 1, stack = 20, class = 7, subclass = 7, price = 50 })
		M.put(0, 5, { id = 9731, name = "Fine Ring", q = 1, class = 4, subclass = 0, price = 80, equip = "INVTYPE_FINGER" })
		_G.ItemTreeAPI = it and fakeItemTree(it) or nil
		_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin or "modern", makeRoom = true, makeRoomValue = "vendor", makeRoomAsk = false } } }
		local n = M.loadAddon("BagSmith")
		n.version = "1.10.0-beta14"
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
	local function facts() return { [9701] = fact(9701, true), [9702] = fact(9702, false), [9720] = fact(9720, true), [9730] = fact(9730, true) } end

	for _, skin in ipairs({ "modern", "classic" }) do
		local S0 = skin .. ": "
		-- (a) ready, and answering nothing when the loot window opens
		local it = { facts = facts(), silent = true }
		local n, M, MR, f = lootBoot(it, skin)
		local IT = n.ItemTree
		check(f and f:IsShown() and offered(f) == "Broken Fang", S0 .. "ItemTree ready but answering nothing: only your junk is offered (" .. tostring(f and offered(f)) .. ")")
		check(f.held.text == "2 protected items aren't offered" and #f.heldInfo.lines == 1 and plain(f.heldInfo.lines[1]):find("^Waiting for ItemTree %(2%): ") ~= nil,
			S0 .. "the paw and the belt wait under Waiting for ItemTree (" .. plain(f.heldInfo.lines[1]) .. ")")
		-- it recovers with no word: the Helper's own look finds the answers
		it.silent = nil
		M.runTimers(); M.runTimers()
		check(offered(f) == "Broken Fang,Linen Belt" and f.held.text == "1 protected item isn't offered" and plain(f.heldInfo.lines[1]):find("ItemTree says to keep (1):", 1, true) ~= nil,
			S0 .. "it answers again, with no notice: the open Helper offers the belt by itself and holds the paw ItemTree keeps (" .. offered(f) .. ")")
		local calls = it.calls
		pump(M)
		check(it.calls == calls, S0 .. "nothing waits any more: it stops looking")
		-- ItemTree's notice redraws the open Helper
		it.facts[9702] = fact(9702, true)
		it.onChange("stock"); M.runTimers(); M.runTimers()
		check(offered(f) == "Broken Fang" and plain(f.heldInfo.lines[1]):find("ItemTree says to keep (2):", 1, true) ~= nil, S0 .. "ItemTree says its answers changed, and now keeps the belt: the open Helper stops offering it, with no click (" .. offered(f) .. ")")
		it.facts[9702] = fact(9702, false)
		it.onChange("stock"); M.runTimers(); M.runTimers()
		check(offered(f) == "Broken Fang,Linen Belt", S0 .. "(and offers it again when ItemTree lets it go)")

		-- (b) a "clear" the click couldn't confirm
		local belt = MR:Offer(recOf(n, 9702), false, "priced", 22)
		check(MR:StillOk(belt) == true, S0 .. "(the belt passes at the click)")
		it.raise = true
		local ok, why = MR:StillOk(belt)
		check(ok == false and why == "itemtreeunknown", S0 .. "ItemTree fails at the click: refused")
		check(IT:Facts(recOf(n, 9702)) ~= nil and IT:Facts(recOf(n, 9702)).kept == false, S0 .. "the answer held before is kept for the rules")
		MR:Refresh()
		check(offered(f) == "Broken Fang", S0 .. "the list drawn again doesn't offer the belt on the strength of the old answer (" .. offered(f) .. ")")
		check(#f.heldInfo.lines == 2 and plain(f.heldInfo.lines[1]):find("ItemTree says to keep (1): Gnoll Paw", 1, true) ~= nil and plain(f.heldInfo.lines[2]):find("Waiting for ItemTree (1): Linen Belt", 1, true) ~= nil,
			S0 .. "the paw is still held as ItemTree's Keep (no click put that in doubt); the belt waits (" .. plain(f.heldInfo.lines[1]) .. " / " .. plain(f.heldInfo.lines[2]) .. ")")
		it.raise = nil
		M.runTimers(); M.runTimers()
		check(offered(f) == "Broken Fang,Linen Belt", S0 .. "ItemTree answers again: the belt is offered again by itself")
		check(MR:StillOk(belt) == true, S0 .. "and passes at the click")
		check(it.requested == 0 and (n.errors or 0) == 0, S0 .. "no errors, and ItemTree was never asked to load anything")
		f:Hide()
	end

	-- the words for the empty card
	do
		local n = lootBoot(nil)
		local W = n.Why
		local h = W:New(); W:Add(h, "itemtreewait", "A")
		check(W:Phrase(h) == "1 item waiting for ItemTree", "one: 1 item waiting for ItemTree")
		W:Add(h, "itemtreewait", "B"); W:Add(h, "itemtree", "C")
		check(W:Phrase(h) == "1 item ItemTree says to keep and 2 items waiting for ItemTree", "with a Keep beside them: " .. W:Phrase(h))
		check(W.LABEL.itemtreewait == "Waiting for ItemTree" and W.LABEL.unknown == "Couldn't be checked right now", "the heading is Waiting for ItemTree; Couldn't be checked right now stays for what BagSmith itself couldn't read")
		local at = {}
		for i, code in ipairs(W.ORDER) do at[code] = i end
		check(at.itemtreewait == at.itemtree + 1, "it sits right under ItemTree says to keep")
	end

	-- R6: Clear Soul Shards is the player's own action and doesn't ask ItemTree (Shweep: "leave as is and say so")
	do
		local it = { facts = facts() }
		local n, M, MR, f = lootBoot(it)
		local IT = n.ItemTree
		n:Set("shardKeep", 1)
		for i = 1, 3 do M.put(0, i, { id = 6265, name = "Soul Shard", q = 1, count = 1, stack = 1, class = 15, subclass = 0, price = 0 }) end
		n:Scan()
		check(select(2, MR:Shards()) == 2, "(three Soul Shards, one to keep: two may go)")
		local pickups = 0
		C_Container.PickupContainerItem = function() pickups = pickups + 1 end   -- (counted only: nothing is put on the cursor, so nothing is deleted)
		local paint = MR.Paint
		MR.Paint = function() end
		it.facts[6265] = fact(6265, true)
		check(IT:Verdict(recOf(n, 6265), true) == "hold", "(ItemTree, asked, would say keep the shards)")
		local asked, gone = it.asked[6265], deleted
		MR:DestroyNextShard(nil)
		check(pickups == 1 and it.asked[6265] == asked, "Clear Soul Shards goes ahead on its own checks, and ItemTree isn't asked")
		MR.shardBatch = nil
		it.silent = true
		check(IT:Verdict(recOf(n, 6265), true) == "unknown", "(and now ItemTree answers nothing)")
		asked = it.asked[6265]
		MR:DestroyNextShard(nil)
		check(pickups == 2 and it.asked[6265] == asked and deleted == gone, "the same while ItemTree can't answer: its own checks, no question to ItemTree")
		MR.shardBatch = nil
		-- its own count to keep still rules
		n:Set("shardKeep", 3)
		check(select(2, MR:Shards()) == 0, "with three to keep, none may go")
		MR:DestroyNextShard(nil)
		check(pickups == 2, "and none is picked up")
		MR.Paint = paint
		check((n.errors or 0) == 0, "no errors")
		f:Hide()
	end
	_G.ItemTreeAPI = nil
end

-- ======== the words ========
for _, skin in ipairs({ "modern", "classic" }) do
	local S0 = skin .. ": "
	package.loaded.mock = nil
	local M = require("mock")
	M.removeEquipmentSets()
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 13 })
	_G.ItemTreeAPI = fakeItemTree({ facts = {} })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin } } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta14"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("addons"); M.runTimers()
	local function row(key) for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.key == key then return w end end end
	local lootRow, deRow, rulesRow = row("makeRoomHoldItemTree"), row("deHoldItemTree"), row("useItemTree")
	check(lootRow and lootRow.help.text == "Won't offer an item ItemTree says to keep, or one it hasn't answered about yet. Your junk is still offered, and Clear Soul Shards doesn't ask ItemTree.",
		S0 .. "Hold Back in the Loot Helper says what waits, that junk is still offered, and that Clear Soul Shards is separate")
	check(deRow and deRow.help.text == "Won't offer a piece ItemTree says to keep, or one it hasn't answered about yet. Gear it keeps for its dust is still offered.",
		S0 .. "Hold Back in the Disenchant Helper says what waits, and the dust exception")
	check(not (lootRow.help.text .. deRow.help.text):find("\226\128\148"), S0 .. "with no dashes")
	-- the longer lines keep the rows apart
	local function top(w) return select(5, w:GetPoint(1)) or select(3, w:GetPoint(1)) end
	local yRules, yLoot, yDe = top(rulesRow), top(lootRow), top(deRow)
	check(type(yLoot) == "number" and type(yDe) == "number" and yRules > yLoot and yLoot - lootRow:GetHeight() >= yDe, S0 .. "the three rows follow one another without overlapping (" .. tostring(yRules) .. ", " .. tostring(yLoot) .. ", " .. tostring(yDe) .. "; the Loot Helper's row is " .. tostring(lootRow:GetHeight()) .. " tall)")
	P:Hide()
	check((n.errors or 0) == 0, S0 .. "no errors")
	_G.ItemTreeAPI = nil
end

;(function()
	local f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	local section = ("\n" .. log):match("\n(## 1%.10%.0\n.-)\n## 1%.9%.8\n") or ""
	local flat = section:gsub("%s+", " ")
	-- (by design since 1.10.0-beta15, the beta14 audit's B14-4: the middle sentence no longer promises the item shows
	-- once ItemTree answers; a Keep answer leaves it held)
	check(flat:find("While its switch is on and ItemTree hasn't answered about an item yet, that item is held back under Waiting for ItemTree. The Helper checks again by itself, and offers the item only if ItemTree doesn't say to keep it. Clear Soul Shards is your own action with its own count to keep, and doesn't ask ItemTree.", 1, true),
		"the changelog: what waits, that the Helper checks again, and that Clear Soul Shards doesn't ask ItemTree")
	check(not section:find("\226\128\148") and not section:find("\226\128\147"), "with no dashes")
	f = io.open("BagSmith/Core/MakeRoom.lua"); local src = f:read("*a"); f:close()
	local shard = src:match("function MR:DestroyNextShard%(btn%)(.-)\n%-%- Loot what now fits") or ""
	check(#shard > 200 and not shard:find("ItemTree", 1, true), "Clear Soul Shards has no ItemTree call (by Shweep's decision; the help line and the changelog say so)")
	f = io.open("BagSmith/BagSmith.toc"); local toc = f:read("*a"); f:close()
	check(toc:find("## Version: 1.10.0", 1, true), "the TOC says 1.10.0 (the exact version is pinned in tests/run.lua)")
end)()
