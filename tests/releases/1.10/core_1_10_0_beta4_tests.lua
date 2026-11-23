-- ======== 1.10.0-beta4 (Shweep, 22 Nov: "go ahead w/ next beta") ========
-- The Filters window, rebuilt on the rules a custom section has: Search, Quality and Quick picks at the top, then
-- "Only show items that fit [all of these | any one of these]" with the same rule rows as the section editor
-- (Frames/RuleList.lua, shared), "+ Add a Rule", a count of what's left, and Save as Sheet or Save as Section....
-- Three kinds of rule are only a filter's: Section, Bag and Time in Bags. The boxes the window used to have (Type /
-- Sections, Bind, Where, Age) are rules now: a sheet an older version saved shows them as rules and filters the same,
-- and a sheet that only uses what an older version knows is still saved the way that version reads it.

local CLOTH, LEATHER = "7:5", "7:6"
local CLASSES = { [0] = "Consumable", [2] = "Weapon", [4] = "Armor", [7] = "Trade Goods" }
local SUBS = { [0] = { [1] = "Potions", [5] = "Food & Drink" }, [2] = { [0] = "One-Handed Axes", [15] = "Daggers" },
	[4] = { [1] = "Cloth", [2] = "Leather", [3] = "Mail" }, [7] = { [5] = "Cloth", [6] = "Leather", [9] = "Herb", [12] = "Enchanting" } }
local function boot(opts)
	opts = opts or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 16
	local function tg(slot, id, name, sub, subName, extra)
		local it = { id = id, name = name, q = 1, count = 5, class = 7, subclass = sub, type = "Trade Goods", sub = subName, price = 10, ilvl = 10 }
		for k, v in pairs(extra or {}) do it[k] = v end
		M.put(0, slot, it)
	end
	tg(1, 2589, "Linen Cloth", 5, "Cloth")
	tg(2, 2592, "Wool Cloth", 5, "Cloth")
	tg(3, 4306, "Silk Cloth", 5, "Cloth", { price = 25 })
	tg(4, 2318, "Light Leather", 6, "Leather")
	tg(5, 2447, "Peacebloom", 9, "Herb", { price = 5 })
	M.put(0, 8, { id = 4040, name = "Glimmering Mail Gauntlets", q = 2, count = 1, class = 4, subclass = 3, type = "Armor", sub = "Mail", equip = "INVTYPE_HAND", bind = 2, price = 300, ilvl = 30 })
	M.put(0, 9, { id = 4329, name = "Seer's Belt", q = 2, count = 1, class = 4, subclass = 1, type = "Armor", sub = "Cloth", equip = "INVTYPE_WAIST", bind = 2, bound = true, price = 200, ilvl = 25 })
	M.put(0, 10, { id = 118, name = "Minor Healing Potion", q = 1, count = 3, class = 0, subclass = 1, type = "Consumable", sub = "Potions", price = 5, ilvl = 5 })
	-- one more in the first bag (the mock's "Linen Bag")
	M.put(1, 1, { id = 9001, name = "Robe of Power", q = 3, count = 1, class = 4, subclass = 1, type = "Armor", sub = "Cloth", equip = "INVTYPE_ROBE", bind = 2, price = 5000, ilvl = 38 })
	_G.INVTYPE_HAND, _G.INVTYPE_WAIST, _G.INVTYPE_CHEST, _G.INVTYPE_ROBE = "Hands", "Waist", "Chest", "Chest"
	_G.ITEM_QUALITY_COLORS = { [0] = { r = 0.62, g = 0.62, b = 0.62 }, { r = 1, g = 1, b = 1 }, { r = 0.12, g = 1, b = 0 }, { r = 0, g = 0.44, b = 0.87 }, { r = 0.64, g = 0.21, b = 0.93 }, { r = 1, g = 0.5, b = 0 } }
	C_Item.GetItemClassInfo = function(c) return CLASSES[c] end
	C_Item.GetItemSubClassInfo = function(c, s) return SUBS[c] and SUBS[c][s] end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local prof = { view = "list", grp = "type", favSection = true, recentSection = false }
	for k, v in pairs(opts.prof or {}) do prof[k] = v end
	_G.BagSmithDB = opts.saved or { version = 2, chars = {}, cache = {}, profiles = { Default = prof } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta4"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	return n, M, n.Window.main, n.Popups, n.Rules
end
local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
local function click(b) b:GetScript("OnClick")(b) end
-- (by design since 1.10.0-beta11: + Add a Rule lists its kinds in groups, with five more of them, so a kind is picked
-- by its name here, not by its place in the list)
local function pick(menu, text) for _, it in ipairs(menu or {}) do if it.text == text then return it end end end
local function typeIn(box, text) box:SetText(text); box:GetScript("OnTextChanged")(box, true) end
local function entry(p, label) for _, e in ipairs(p.list) do if e.label == label then return e end end end
local function chipOf(f, group, key) for _, c in ipairs(f.checks) do if c.groupKey == group and c.key == key then return c end end end
local function plain(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function chipTexts(r) local t = {}; for _, c in ipairs(r.chips) do if c:IsShown() then t[#t + 1] = plain(c.label.text) .. (c.active and "*" or "") end end; return table.concat(t, ", ") end
-- the names the window's list shows, A to Z
local function shown(main)
	local list = main:Filtered()
	local t = {}
	for i, r in ipairs(list) do t[i] = r.name end
	table.sort(t)
	return table.concat(t, ", ")
end
local ALL = "Glimmering Mail Gauntlets, Light Leather, Linen Cloth, Minor Healing Potion, Peacebloom, Robe of Power, Seer's Belt, Silk Cloth, Wool Cloth"

;(function()
	-- the rules a filter can ask, and a section can't
	local n, M, main, P, R = boot()
	check(R.KEYS.sec.filterOnly and R.KEYS.bag.filterOnly and R.KEYS.age.filterOnly and R.KEYS.sec.label == "Section" and R.KEYS.bag.label == "Bag" and R.KEYS.age.label == "Time in Bags",
		"three kinds of rule are only a filter's: Section, Bag and Time in Bags")
	check(#R.KEY_ORDER == 6 and #R.FILTER_KEYS == 3, "(a section's six kinds are as they were)")
	local gloves, potion = recOf(n, 4040), recOf(n, 118)
	local function rule(k, ...) return { mode = "all", rows = { { k = k, v = { ... } } } } end
	check(R:Fits(rule("sec", "Gear"), gloves, true) and not R:Fits(rule("sec", "Gear"), potion, true), "as a filter: Section is Gear takes the gauntlets, not the potion")
	check(not R:Fits(rule("sec", "Gear"), gloves) and not R:Fits(rule("sec", "Gear"), gloves, false), "among a section's rules it fits nothing: a section is never decided by where an item is")
	check(R:Fits({ mode = "any", rows = { { k = "sec", v = { "Gear" } }, { k = "type", v = { "4:*" } } } }, gloves), "(with \"any one of these\", a section's other rules still count)")
	check(R:Fits(rule("bag", "Backpack"), gloves, true) and not R:Fits(rule("bag", "Linen Bag (1)"), gloves, true) and R:Fits(rule("bag", recOf(n, 9001).where), recOf(n, 9001), true), "Bag is the bag an item sits in, by its name")
	-- time in bags: whole hours asked, the item's own time exact
	local now = time()
	local function aged(hours) return { itemID = 1, firstSeen = now - hours * 3600 } end
	check(R:Fits(rule("age", 0, 3), aged(2.5), true) and not R:Fits(rule("age", 0, 2), aged(2.5), true), "two and a half hours in your bags: at most 3, not at most 2")
	check(R:Fits(rule("age", 2, 99), aged(2.5), true) and R:Fits(rule("age", 2, 99), aged(24 * 30), true) and not R:Fits(rule("age", 2, 99), aged(1), true), "at least 2 hours has no upper end: a month-old item fits")
	check(R:Fits(rule("age", 1, 3), aged(2), true) and not R:Fits(rule("age", 1, 3), aged(4), true) and not R:Fits(rule("age", 0, 99), { itemID = 1 }, true), "between 1 and 3; an item with no time recorded fits no such rule")
	check(R:Fits(rule("price", 10000, 99999999), { itemID = 1, sellPrice = 300000000 }), "(the same for the other numbers: \"at least\" has no upper end)")
	check(R:RowText({ k = "age", v = { 2, 99 } }) == "Time in Bags is at least 2 hours" and R:RowText({ k = "age", v = { 0, 1 } }) == "Time in Bags is at most 1 hour" and R:RowText({ k = "age", v = { 1, 3 } }) == "Time in Bags is between 1 and 3 hours",
		"in words, with its unit (" .. R:RowText({ k = "age", v = { 1, 3 } }) .. ")")
	check(R:RowText({ k = "sec", v = { "Gear", "TradeGoods" } }) == "Section is Gear or Trade Goods" and R:RowText({ k = "bag", v = { "Backpack" } }) == "Bag is Backpack", "Section by its name, Bag by its own")
	check(R:RowText({ k = "ilvl", v = { 30, 9999 } }) == "Item Level is at least 30" and R:RowText({ k = "ilvl", v = { 30, 30 } }) == "Item Level is 30", "(the other numbers read as before)")
	local c = R.Clean({ rows = { { k = "sec", v = { "Gear", "Gear", "", 5 } }, { k = "bag", v = { "Backpack" } }, { k = "age", v = { 7, 2 } }, { k = "age", v = { 120 } } } })
	check(c and #c.rows == 3 and #c.rows[1].v == 1 and c.rows[3].v[1] == 2 and c.rows[3].v[2] == 7, "kept like any rule: sound values once, a range in order, whole hours 0 to 99")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- the saved form: what an older version kept as boxes and what is a rule mean the same
	local n, M, main, P, R = boot()
	local e = n.EmptyFilters()
	check(e.rules == nil and e.usable == nil and next(e.q) == nil and e.text == "", "no filters: no rules, nothing else")
	local c = n.CleanFilters({ usable = "yes", rules = { mode = "any", rows = { { k = "type", v = { CLOTH, "x" } }, "junk", { k = "sec", v = { "Gear" } } } }, surprise = 1 })
	check(c.usable == nil and c.rules and c.rules.mode == "any" and #c.rules.rows == 2 and #c.rules.rows[1].v == 1 and c.surprise == nil, "saved filters are cleaned like any saved data: sound rules kept, the rest dropped")
	check(n.CleanFilters({ usable = true }).usable == true and n.CleanFilters({ rules = "x" }).rules == nil, "Usable by Me only when it's exactly on; unreadable rules are none")
	-- the count on the Filter button: the same in either form
	local old = n.CleanFilters({ cat = { Gear = true, TradeGoods = true }, bd = { BoE = true }, w = { Backpack = true }, ageMin = 1, q = { [2] = true }, new = true })
	check(n.FilterCount(old) == 7, "(seven things ticked, as an older version counts them)")
	local items = {}
	for _, r in ipairs(n.items) do if r.itemID then items[#items + 1] = r end end
	local function passing(f) local fp, t = n:FilterPredicate(f), {}; for _, r in ipairs(items) do if fp(r) then t[#t + 1] = r.name end end; table.sort(t); return table.concat(t, ", ") end
	local cases = {
		{ cat = { Gear = true } }, { cat = { Gear = true, Consumables = true }, bd = { BoE = true } }, { bd = { BoP = true, None = true } },
		{ w = { Backpack = true } }, { cat = { TradeGoods = true }, w = { ["Linen Bag (1)"] = true } }, { ageMin = 0, ageMax = 3 }, { ageMin = 2 }, { ageMax = 1 },
		{ cat = { Gear = true }, q = { [3] = true }, text = "robe" }, { bd = { BoE = true }, rules = { mode = "all", rows = { { k = "type", v = { "4:*" } } } } },
	}
	for _, r in ipairs(n.items) do if r.itemID == 2589 and r.guid then n.cdb.firstSeen[r.guid] = time() - 5 * 3600 end end
	n:Scan(); items = {}
	for _, r in ipairs(n.items) do if r.itemID then items[#items + 1] = r end end
	local same, counted, back = true, true, true
	for _, case in ipairs(cases) do
		local before = n.CleanFilters(case)
		local folded = n.FoldFilters(n.CleanFilters(case))
		if passing(before) ~= passing(folded) then same = false; print("DIFFERS folded", passing(before), "|", passing(folded)) end
		if n.FilterCount(before) ~= n.FilterCount(folded) then counted = false end
		if next(folded.cat) or next(folded.bd) or next(folded.w) or folded.ageMin or folded.ageMax then same = false; print("NOT FOLDED") end
		local unfolded = n.UnfoldFilters(folded)
		if passing(unfolded) ~= passing(before) or n.FilterCount(unfolded) ~= n.FilterCount(before) then back = false; print("DIFFERS unfolded", passing(before), "|", passing(unfolded)) end
	end
	check(same, "the older boxes turned into rules let the same items through (ten cases)")
	check(counted, "and count the same on the Filter button")
	check(back, "and turned back for saving, the same again")
	local f = n.FoldFilters(n.CleanFilters({ cat = { Gear = true, Consumables = true }, bd = { BoE = true, None = true }, w = { Backpack = true }, ageMin = 2 }))
	check(f.rules and f.rules.mode == "all" and #f.rules.rows == 4 and R:Summary(f.rules) == "Fits all: Section is Consumables or Gear; Binding is Binds when equipped or No binding; Bag is Backpack; Time in Bags is at least 2 hours",
		"as rules: " .. tostring(f.rules and R:Summary(f.rules)))
	-- saving: back to the older form wherever that says the same
	local u = n.UnfoldFilters(f)
	check(u.rules == nil and u.cat.Gear and u.cat.Consumables and u.bd.BoE and u.bd.None and u.w.Backpack and u.ageMin == 2 and u.ageMax == nil, "saved the way an older version reads it, with no rules left over")
	local function stays(rules) local out = n.UnfoldFilters({ rules = rules }); return out.rules ~= nil and not next(out.cat) and not next(out.bd) and not next(out.w) and not out.ageMin and not out.ageMax end
	check(stays({ mode = "all", rows = { { k = "sec", v = { "Gear" }, n = true } } }), "\"is not\" stays a rule (an older version has no word for it)")
	check(stays({ mode = "any", rows = { { k = "sec", v = { "Gear" } }, { k = "bag", v = { "Backpack" } } } }), "so do rules under \"any one of these\"")
	check(stays({ mode = "all", rows = { { k = "sec", v = { "Gear" } }, { k = "sec", v = { "Junk" }, n = true } } }), "and two rules of one kind")
	check(stays({ mode = "all", rows = { { k = "bind", v = { "bou" } } } }) and stays({ mode = "all", rows = { { k = "age", v = { 2, 24 } } } }), "and a binding or a time an older version doesn't know (Binds when used; more than 9 hours)")
	local mixed = n.UnfoldFilters({ rules = { mode = "all", rows = { { k = "type", v = { CLOTH } }, { k = "sec", v = { "TradeGoods" } } } } })
	check(mixed.cat.TradeGoods and mixed.rules and #mixed.rules.rows == 1 and mixed.rules.rows[1].k == "type", "a Type rule stays a rule beside a Section that went back to its box")
	-- a deleted section leaves a Section rule
	local S = n.Sections
	local mine = S:Create("Mine")
	local pf = n.CleanFilters({ rules = { mode = "all", rows = { { k = "sec", v = { mine, "Gear" } }, { k = "sec", v = { mine } } } } })
	n.PruneFilterCategories(pf, {})
	check(pf.rules and #pf.rules.rows == 1 and #pf.rules.rows[1].v == 1 and pf.rules.rows[1].v[1] == "Gear", "a section that's gone comes off a Section rule; a rule left with nothing goes")
	check((n.errors or 0) == 0, "no errors")
end)()

for _, skin in ipairs({ "modern", "classic" }) do
	-- the window
	local S0 = skin .. ": "
	local n, M, main, P, R = boot({ prof = { skin = skin } })
	local menu
	n.ShowMenu = function(items) menu = items end
	local unusable = {}
	n.Usability.IsUnusable = function(_, rec) return unusable[rec.itemID] == true end
	P:OpenFilters(main, "browse"); M.runTimers()
	local f = P.filter
	local L = f.list
	check(f:IsShown() and f.title.text == "Filters" and f.where.text == "Bags, on the All tab", S0 .. "Filters, and which window and tab they're for: Bags, on the All tab")
	local q, picks = {}, {}
	for _, c in ipairs(f.checks) do
		if c.groupKey == "q" then q[#q + 1] = c.label.text elseif c:IsShown() then picks[#picks + 1] = c.label.text end
	end
	check(table.concat(q, ", ") == "Poor, Common, Uncommon, Rare, Epic, Legendary", S0 .. "Quality: Poor to Legendary, as chips")
	check(table.concat(picks, ", ") == "New, Usable by Me" and not f.realmsCheck:IsShown(), S0 .. "Quick picks: New and Usable by Me (Include Other Rulesets only in Global Inventory)")
	check(f.ask.text == "Only show items that fit" and f.all.label.text == "all of these" and f.any.label.text == "any one of these" and f.all.active and not f.any.active and f.add.label.text == "+ Add a Rule" and not f.hint:IsShown(),
		S0 .. "Only show items that fit [all of these] [any one of these], and + Add a Rule")
	check(f.count.text == "All 9 items shown" and f.sheetLabel.text == "Keep these filters:" and f.saveBtn.label.text == "Save as Sheet" and f.sectionBtn.label.text == "Save as Section..."
		and f.saveHint.text == "A sheet is a tab that shows only these items. A section groups them together wherever they show." and not f.deleteBtn:IsShown(),
		S0 .. "the count, and Keep these filters: Save as Sheet, Save as Section..., with what each one is")
	local h0 = f:GetHeight()
	-- Quality
	click(chipOf(f, "q", 2)); M.runTimers()
	check(main.st.filters.q[2] == true and chipOf(f, "q", 2).active and chipOf(f, "q", 2).label.text:find("^|cff") and shown(main) == "Glimmering Mail Gauntlets, Seer's Belt" and f.count.text == "2 of 9 items shown",
		S0 .. "Uncommon lit: the two green items, 2 of 9 items shown")
	check(main.btnFilter.label.text == "Filter (1)", S0 .. "and the Filter button counts it")
	click(chipOf(f, "q", 3)); M.runTimers()
	check(shown(main) == "Glimmering Mail Gauntlets, Robe of Power, Seer's Belt", S0 .. "Rare too: either quality")
	-- Quick picks
	unusable[9001] = true
	click(chipOf(f, "usable")); M.runTimers()
	check(main.st.filters.usable == true and shown(main) == "Glimmering Mail Gauntlets, Seer's Belt" and main.btnFilter.label.text == "Filter (3)", S0 .. "Usable by Me: the robe your character can't wear yet is left out")
	click(chipOf(f, "usable")); M.runTimers()
	check(main.st.filters.usable == nil and shown(main) == "Glimmering Mail Gauntlets, Robe of Power, Seer's Belt", S0 .. "and off again")
	click(chipOf(f, "q", 2)); click(chipOf(f, "q", 3)); M.runTimers()
	check(shown(main) == ALL and not chipOf(f, "q", 2).active and not chipOf(f, "q", 2).label.text:find("|c", 1, true), S0 .. "the chips off: everything again")
	-- + Add a Rule
	click(f.add)
	local texts = {}
	for i, it in ipairs(menu) do texts[i] = it.text end
	-- (by design since 1.10.0-beta6: one quiet line after them says the optional ItemTree addon adds more)
	check(table.concat(texts, " | ") == "What should the rule look at? | About the item | Type | Slot | Quality | Binding | Item Level | Name | What it is for | Food, Drink and Potions | Quest Item | Crafting Material | Usable by Me | Value | Vendor Value | Where it is | Section | Bag | Time in Bags | Optional: the ItemTree addon adds more rules here."
		and menu[#menu].disabled, S0 .. "the kinds of rule: a section's, then Section, Bag and Time in Bags")
	-- Binding: every choice on the row, live
	pick(menu, "Binding").onClick(); M.runTimers()
	local r1 = L.rows[1]
	check(#L.draft.rows == 1 and r1:IsShown() and r1.label.text == "Binding" and chipTexts(r1) == "Soulbound, Binds when equipped, Binds when used, No binding" and r1.note.text == "Pick at least one, or this rule is ignored.", S0 .. "Binding: its four choices, none picked")
	check(shown(main) == ALL and main.st.filters.rules == nil and f:GetHeight() > h0 and f.hint:IsShown(), S0 .. "a rule with nothing picked filters nothing, and the window grows to hold it")
	click(r1.chips[2]); M.runTimers()
	check(shown(main) == "Glimmering Mail Gauntlets, Robe of Power" and f.count.text == "2 of 9 items shown" and R:Summary(main.st.filters.rules) == "Binding is Binds when equipped", S0 .. "Binds when equipped: the list behind follows at once (the belt is already soulbound)")
	click(r1.verb); M.runTimers()
	check(r1.verb.label.text == "is not" and #main:Filtered() == 7, S0 .. "is not: everything else")
	click(r1.verb); M.runTimers()
	-- Type, picked in the second window, over this one
	click(f.add); pick(menu, "Type").onClick(); M.runTimers()
	local p = L.picker
	check(p and p:IsShown() and f.shade:IsShown() and p.title.text == "Add a Rule" and p.head.text == "Type" and #L.draft.rows == 1, S0 .. "Type: the same list as the section editor's, over the Filters window")
	L:PickerClick(entry(p, "Armor")); L:PickerClick(entry(p, "Any kind of Armor")); click(p.ok); M.runTimers()
	check(not p:IsShown() and not f.shade:IsShown() and #L.draft.rows == 2 and chipTexts(L.rows[2]) == "Armor*" and shown(main) == "Glimmering Mail Gauntlets, Robe of Power", S0 .. "Add Rule: Type is Armor joins, and both rules must fit")
	-- Section: a list of your sections; Bag: the bags this window shows; Time in Bags: hours
	local mine = n.Sections:Create("Keepsakes"); M.runTimers()
	click(f.add); pick(menu, "Section").onClick(); M.runTimers()
	check(p:IsShown() and p.head.text == "Section" and p.ask.text == "Tick every section you want:" and not p.note:IsShown() and entry(p, "Gear") and entry(p, "Trade Goods") and entry(p, "Keepsakes"), S0 .. "Section: BagSmith's sections and yours, to tick")
	L:PickerClick(entry(p, "Trade Goods")); L:PickerClick(entry(p, "Keepsakes"))
	check(p.say.text == "Section is Trade Goods or Keepsakes", S0 .. "Your rule will say: Section is Trade Goods or Keepsakes")
	click(p.ok); M.runTimers()
	check(#L.draft.rows == 3 and chipTexts(L.rows[3]) == "Trade Goods*, Keepsakes*" and L.rows[3].choose:IsShown() and shown(main) == "", S0 .. "all three rules: nothing is armor in Trade Goods")
	click(f.any); M.runTimers()
	check(f.any.active and main.st.filters.rules.mode == "any" and #main:Filtered() == 8, S0 .. "any one of these: the three pieces of armor and the five trade goods")
	click(f.all); M.runTimers()
	click(L.rows[3].remove); click(L.rows[1].remove); M.runTimers()
	check(#L.draft.rows == 1 and L.rows[1].label.text == "Type" and shown(main) == "Glimmering Mail Gauntlets, Robe of Power, Seer's Belt", S0 .. "two rules removed: Type is Armor alone")
	click(f.add); pick(menu, "Bag").onClick(); M.runTimers()
	local r2 = L.rows[2]
	check(r2.label.text == "Bag" and chipTexts(r2):find("^Backpack, Linen Bag") and not r2.choose:IsShown(), S0 .. "Bag: the bags this window shows, on the row (" .. chipTexts(r2) .. ")")
	click(r2.chips[1]); M.runTimers()
	check(shown(main) == "Glimmering Mail Gauntlets, Seer's Belt" and R:Summary(main.st.filters.rules) == "Fits all: Type is Armor; Bag is Backpack", S0 .. "Bag is Backpack: the robe in the other bag is left out")
	click(L.rows[2].remove); M.runTimers()
	for _, r in ipairs(n.items) do if r.itemID == 4040 and r.guid then n.cdb.firstSeen[r.guid] = time() - 5 * 3600 end end
	n:Scan(); M.runTimers()
	click(f.add); pick(menu, "Time in Bags").onClick(); M.runTimers()
	r2 = L.rows[2]
	check(r2.label.text == "Time in Bags" and r2.verb.label.text == "at least" and r2.unitText:IsShown() and r2.unitText.text == "hours" and r2.note.text == "Type a number, or this rule is ignored.", S0 .. "Time in Bags: at least, a box, and \"hours\"")
	typeIn(r2.num[1].boxes[1], "4"); M.runTimers()
	check(shown(main) == "Glimmering Mail Gauntlets" and R:Summary(main.st.filters.rules) == "Fits all: Type is Armor; Time in Bags is at least 4 hours", S0 .. "at least 4 hours: the gauntlets, five hours in your bags")
	click(r2.verb); menu[2].onClick(); M.runTimers()
	check(r2.verb.label.text == "at most" and shown(main) == "Robe of Power, Seer's Belt", S0 .. "at most 4 hours: the other two")
	check(main.btnFilter.label.text == "Filter (2)", S0 .. "the Filter button: two rules")
	-- Clear All
	click(f.clearBtn); M.runTimers()
	check(#L.draft.rows == 0 and main.st.filters.rules == nil and shown(main) == ALL and f.count.text == "All 9 items shown" and main.btnFilter.label.text == "Filter" and f:GetHeight() == h0, S0 .. "Clear All: no rules, no chips, everything shown, the window its first size")
	-- more rules than fit scroll inside the window
	for _ = 1, 6 do L:AddRow("quality") end
	M.runTimers()
	check(f.rulesHeight > 190 and f:GetHeight() == h0 - 28 + 190, S0 .. "many rules: the window stops growing and the rules scroll")
	click(f.clearBtn); M.runTimers()
	check((n.errors or 0) == 0, S0 .. "no errors")
end

;(function()
	-- a sheet an older version saved; saving from the new window; Save as Section...
	local saved = { version = 2, chars = {}, cache = {}, profiles = { Default = { view = "list", grp = "type", favSection = true, recentSection = false,
		sheets = { { n = "Old Gear", f = { q = {}, cat = { Gear = true }, t = {}, bd = { BoE = true }, w = { Backpack = true }, new = false, text = "", ageMin = 0, ageMax = 3 } } },
		tabOrder = { "All", "Old Gear" } } } }
	local n, M, main, P, R = boot({ saved = saved })
	local stored = n.db.sheets[1]
	check(stored and stored.n == "Old Gear" and stored.f.cat.Gear and stored.f.bd.BoE and stored.f.w.Backpack and stored.f.ageMax == 3 and stored.f.rules == nil, "an older version's sheet loads as it was saved")
	main:SetSheet("Old Gear"); M.runTimers()
	local before = shown(main)
	check(before == "Glimmering Mail Gauntlets" and main.btnFilter.label.text == "Filter (4)", "and filters as it did: Gear, Binds when equipped, in the Backpack, up to 3 hours (" .. before .. ")")
	-- opened for editing: its boxes show as rules, and nothing about the list changes
	P:OpenFilters(main, "edit", "Old Gear"); M.runTimers()
	local f = P.filter
	local L = f.list
	check(f.title.text == "Sheet: Old Gear" and f.where.text == "Bags, on the Old Gear tab" and f.sheetLabel.text == "Edit Sheet" and f.saveBtn.label.text == "Save Changes" and f.deleteBtn:IsShown() and f.sheetBox:GetText() == "Old Gear"
		and f.saveHint.text == "Change the name or the filters above, then save. Delete removes the tab.", "the pencil: the sheet's name, Save Changes and Delete Sheet")
	check(#L.draft.rows == 4 and L.rows[1].label.text == "Section" and L.rows[2].label.text == "Binding" and L.rows[3].label.text == "Bag" and L.rows[4].label.text == "Time in Bags", "its four boxes are four rules: Section, Binding, Bag, Time in Bags")
	check(L.rows[2].verb.label.text == "is" and L.rows[4].verb.label.text == "at most" and L.rows[4].num[1].boxes[1]:GetText() == "3" and f.all.active, "Binding is Binds when equipped; Time in Bags at most 3 hours; all of these")
	check(shown(main) == before and main.btnFilter.label.text == "Filter (4)" and f.count.text == "1 of 9 items shown", "the list and the count on the Filter button are as they were")
	check(stored.f.cat.Gear and stored.f.rules == nil, "(the saved sheet isn't touched by being looked at)")
	-- saved unchanged: still the way an older version reads it
	click(f.saveBtn); M.runTimers()
	stored = n.db.sheets[1]
	check(not f:IsShown() and stored.f.rules == nil and stored.f.cat.Gear and stored.f.bd.BoE and stored.f.w.Backpack and stored.f.ageMin == 0 and stored.f.ageMax == 3, "Save Changes with nothing changed: saved in the older form, rule for rule")
	check(shown(main) == before, "and it filters the same")
	-- a rule an older version has no box for is saved as a rule, beside the ones it has
	P:OpenFilters(main, "edit", "Old Gear"); M.runTimers()
	L:AddRow("ilvl"); typeIn(L.rows[5].num[1].boxes[1], "20"); M.runTimers()
	click(L.rows[3].remove); click(L.rows[3].remove); M.runTimers()   -- Bag and Time in Bags
	f.sheetBox:SetText("Good Gear")
	click(f.saveBtn); M.runTimers()
	stored = n.db.sheets[1]
	check(stored.n == "Good Gear" and stored.f.cat.Gear and stored.f.bd.BoE and not next(stored.f.w) and stored.f.ageMax == nil and stored.f.rules and #stored.f.rules.rows == 1 and stored.f.rules.rows[1].k == "ilvl" and stored.f.rules.rows[1].v[1] == 20,
		"renamed and changed: Section and Binding in the older form, Item Level at least 20 as a rule")
	check(main.st.sheet == "Good Gear" and shown(main) == "Glimmering Mail Gauntlets, Robe of Power", "the tab follows: gear that binds when equipped, item level 20 or more")
	-- after a reload, and through a profile code
	local code = n.Share:Export()
	n, M, main, P, R = boot({ saved = BagSmithDB })
	stored = n.db.sheets[1]
	check(stored and stored.n == "Good Gear" and stored.f.rules and stored.f.rules.rows[1].v[1] == 20 and stored.f.rules.rows[1].v[2] == 9999 and stored.f.cat.Gear, "after a reload the sheet has its rule")
	main:SetSheet("Good Gear"); M.runTimers()
	check(shown(main) == "Glimmering Mail Gauntlets, Robe of Power", "and filters the same")
	local name = n.Share:Import(code, "Copied")
	local copied = BagSmithDB.profiles[name or "Copied"]
	check(copied and copied.sheets[1].f.rules and copied.sheets[1].f.rules.rows[1].k == "ilvl", "a profile code carries a sheet's rules")
	-- a new sheet from the window: the plus beside the tabs
	main:SetSheet("All"); M.runTimers()
	P:OpenFilters(main, "new"); M.runTimers()
	f = P.filter; L = f.list
	check(f.sheetBox:GetText() == "" and f.saveBtn.label.text == "Save as Sheet" and #L.draft.rows == 0 and f.where.text == "Bags, on the All tab", "the plus: a clean window, waiting for a name")
	L:AddRow("type"); L:PickerClick(entry(L.picker, "Trade Goods")); L:PickerClick(entry(L.picker, "Cloth")); click(L.picker.ok); M.runTimers()
	click(chipOf(f, "q", 1)); M.runTimers()
	check(shown(main) == "Linen Cloth, Silk Cloth, Wool Cloth", "Type is Trade Goods: Cloth, Common")
	-- Save as Section...: the section editor, with what a section can use
	main.search:SetText("cloth"); main.st.filters.text = "cloth"
	click(chipOf(f, "new")); L:AddRow("bag"); click(L.rows[2].chips[1]); M.runTimers()
	f.sheetBox:SetText("Cloth")
	local rules, note = P:SectionRules(main.st.filters)
	check(rules and rules.mode == "all" and #rules.rows == 2 and rules.rows[1].k == "quality" and rules.rows[1].v[1] == 1 and rules.rows[2].k == "type" and rules.rows[2].v[1] == CLOTH, "what a section can use: the Quality chips as a rule, and the Type rule")
	check(note == "Left out, since a section's rules are about the item itself: the search, Bag and New.", "and what it can't, by name (" .. tostring(note) .. ")")
	click(f.sectionBtn); M.runTimers()
	local E = n.SectionEditor
	local ef = E.frame
	check(ef and ef:IsShown() and ef.title.text == "New Section" and ef.edit:GetText() == "Cloth" and #E.draft.rows == 2 and E.draft.rows[1].k == "quality" and E.draft.rows[2].k == "type" and E.draft.id == nil,
		"Save as Section...: the section editor opens for a new section, named from the box, with those rules")
	check(ef.err.text == note and #E.shown.here == 3, "it says what was left out, and lists what would go in the section")
	click(ef.save); M.runTimers()
	local sec = n.Sections:Customs()[1]
	check(not ef:IsShown() and sec and sec.name == "Cloth" and sec.rules and #sec.rules.rows == 2 and recOf(n, 2589).cat == sec.id, "Create Section: the section is made, and the cloth is in it")
	check(f:IsShown() and #n.db.sheets == 1, "the Filters window is still there, and no sheet was made")
	-- "any one of these" with the Quality chips: they can't be one more rule, so they're left out and named
	local r2, note2 = P:SectionRules({ q = { [2] = true }, rules = { mode = "any", rows = { { k = "type", v = { CLOTH } }, { k = "bind", v = { "boe" } } } } })
	check(r2 and r2.mode == "any" and #r2.rows == 2 and note2 == "Left out, since a section's rules are about the item itself: Quality.", "under \"any one of these\" the Quality chips can't join the rules: left out, and said so")
	local r3 = P:SectionRules({ q = { [2] = true, [3] = true } })
	check(r3 and #r3.rows == 1 and r3.rows[1].k == "quality" and #r3.rows[1].v == 2, "the chips alone make a Quality rule")
	local r4, note4 = P:SectionRules({ text = "x", new = true })
	check(r4 == nil and note4 == "Left out, since a section's rules are about the item itself: the search and New.", "nothing a section can use: no rules, and it says why")
	-- saved as a sheet too
	click(f.saveBtn); M.runTimers()
	local sheet = n.db.sheets[2]
	check(sheet and sheet.n == "Cloth" and sheet.f.q[1] and sheet.f.new == true and sheet.f.text == "cloth" and sheet.f.w.Backpack and sheet.f.rules and #sheet.f.rules.rows == 1 and sheet.f.rules.rows[1].k == "type",
		"Save as Sheet: the chips and the search as before, Bag in the older form, the Type rule as a rule")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- the window follows its tab, its sections and its profile; the bank's own; Global Inventory
	local n, M, main, P, R = boot()
	local S = n.Sections
	local mine = S:Create("Keepsakes")
	n:SaveSheet("Armor", main)   -- (made with no filters, then given some)
	n.db.sheets[1].f = n.CleanFilters({ rules = { mode = "all", rows = { { k = "type", v = { "4:*" } }, { k = "sec", v = { mine, "Gear" } } } } })
	main:SetSheet("All"); M.runTimers()
	P:OpenFilters(main, "browse"); M.runTimers()
	local f = P.filter
	local L = f.list
	L:AddRow("quality"); M.runTimers()
	check(#L.draft.rows == 1, "(a rule being filled in on the All tab)")
	main:SetSheet("Armor"); M.runTimers()
	check(f:IsShown() and #L.draft.rows == 2 and L.rows[1].label.text == "Type" and L.rows[2].label.text == "Section" and f.where.text == "Bags, on the Armor tab", "another tab picked with the window open: it shows that tab's rules")
	local texts = {}
	for _, c in ipairs(L.rows[2].chips) do if c:IsShown() then texts[#texts + 1] = c.label.text end end
	check(table.concat(texts, ", ") == "Gear, Keepsakes", "a Section rule names your section (" .. table.concat(texts, ", ") .. ")")
	S:Rename(mine, "Treasures"); M.runTimers()
	texts = {}
	for _, c in ipairs(L.rows[2].chips) do if c:IsShown() then texts[#texts + 1] = c.label.text end end
	check(table.concat(texts, ", ") == "Gear, Treasures", "renamed: the rule follows")
	S:Delete(mine); M.runTimers()
	texts = {}
	for _, c in ipairs(L.rows[2].chips) do if c:IsShown() then texts[#texts + 1] = c.label.text end end
	check(table.concat(texts, ", ") == "Gear" and #main.st.filters.rules.rows[2].v == 1, "deleted: it comes off the rule")
	main:SetSheet("All"); M.runTimers()
	check(#L.draft.rows == 0 and f.where.text == "Bags, on the All tab", "back on All: no rules")
	-- a sheet being edited, and another tab picked: the edit is over (Save Changes can't put that tab's filters in it)
	main:SetSheet("Armor"); M.runTimers()
	P:OpenFilters(main, "edit", "Armor"); M.runTimers()
	check(P.editing == "Armor" and f.title.text == "Sheet: Armor" and f.saveBtn.label.text == "Save Changes", "(the Armor sheet is being edited)")
	main:SetSheet("All"); M.runTimers()
	check(P.editing == nil and f:IsShown() and f.title.text == "Filters" and f.saveBtn.label.text == "Save as Sheet" and not f.deleteBtn:IsShown() and #L.draft.rows == 0, "another tab picked while a sheet is edited: the edit ends, and the window is that tab's")
	check(n.db.sheets[1].f.rules and #n.db.sheets[1].f.rules.rows == 2, "and the sheet is as it was saved")
	-- closed with the second window up: that one goes too
	L:AddRow("type"); M.runTimers()
	check(L.picker:IsShown(), "(the type list is up)")
	f:Hide()
	check(not L.picker:IsShown() and L.pick == nil, "the Filters window closed: the list over it goes too")
	-- a filter set while the window is closed still filters (and shows when it opens)
	main.st.filters.cat.Gear = true; n:RefreshViews(true); M.runTimers()
	check(shown(main) == "Glimmering Mail Gauntlets, Robe of Power, Seer's Belt", "(a filter in the older form, set with the window closed, filters)")
	P:OpenFilters(main, "browse"); M.runTimers()
	check(#L.draft.rows == 1 and L.rows[1].label.text == "Section" and shown(main) == "Glimmering Mail Gauntlets, Robe of Power, Seer's Belt", "and shows as a Section rule when the window opens")
	click(f.clearBtn); f:Hide()
	-- another profile
	P:OpenFilters(main, "browse"); L:AddRow("quality"); click(L.rows[1].chips[2]); M.runTimers()
	n.Profiles:Use("Second"); M.runTimers()
	check((n.errors or 0) == 0, "switching profile with the window open: no errors")
	-- the bank has its own window
	M.fire("BANKFRAME_OPENED"); M.runTimers(); M.runTimers()
	local bank = n.Window.bank
	if bank and bank.frame:IsShown() then
		P:OpenFilters(bank, "browse"); M.runTimers()
		local bf = P.filter
		check(bf ~= f and bf:IsShown() and not f:IsShown() and bf.title.text == "Bank Filters" and bf.where.text == "Bank, on the All tab" and bf.list ~= L, "the bank's Filters window is its own: Bank Filters, Bank, on the All tab")
		bf.list:AddRow("bind"); click(bf.list.rows[1].chips[1]); M.runTimers()
		check(bank.st.filters.rules and main.st.filters.rules == nil or (main.st.filters.rules ~= bank.st.filters.rules), "its rules are the bank's, not the bags'")
		bf:Hide()
	else
		check(true, "(no bank window in this run)")
	end
	M.fire("BANKFRAME_CLOSED"); M.runTimers()
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- a filter's own rule among a section's rules: kept, said, and it fits nothing
	local n, M, main, P, R = boot()
	local S = n.Sections
	local id = S:Create("Odd")
	n.db.customSections[1].rules = R.Clean({ mode = "all", rows = { { k = "type", v = { CLOTH } }, { k = "bag", v = { "Backpack" } } } })
	S:Reapply(); M.runTimers()
	check(recOf(n, 2589).cat == "TradeGoods", "a section whose rules hold a filter's rule takes nothing")
	local f = S:EditSection(id); M.runTimers()
	local E = n.SectionEditor
	check(#E.draft.rows == 2 and E.draft.rows[2].kept and f.rows[2].label.text == "Bag" and not f.rows[2].verb:IsShown() and f.rows[2].note.text == "Only a filter can use this rule. Here it fits nothing.", "the section editor shows it and says so")
	click(f.rows[2].remove); click(f.save); M.runTimers()
	check(#S:Rules(id).rows == 1 and recOf(n, 2589).cat == id, "removed and saved: the cloth goes in")
	-- the section editor's own + Add a Rule doesn't offer a filter's kinds
	local menu
	n.ShowMenu = function(items) menu = items end
	f = S:EditSection(id); M.runTimers()
	click(f.add)
	-- (by design since 1.10.0-beta6: and one quiet line about the optional ItemTree addon)
	check(pick(menu, "Vendor Value") and not pick(menu, "Section") and not pick(menu, "Bag") and not pick(menu, "Time in Bags") and menu[#menu].disabled, "the section editor offers a section's kinds only, as before")
	click(f.cancel)
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- the TOC and the changelog
	local f = io.open("BagSmith/BagSmith.toc"); local toc = f:read("*a"); f:close()
	check(toc:find("Frames\\SectionsUI.lua\nFrames\\RuleList.lua\nFrames\\SectionEditor.lua\n", 1, true), "the TOC loads the shared rule list before the section editor")
	f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	local section = ("\n" .. log):match("\n(## 1%.10%.0\n.-)\n## 1%.9%.8\n") or ""
	check(section:find("The Filters window is rebuilt", 1, true) and section:find("Save as Section...", 1, true) and section:find("Section, Bag and Time in Bags", 1, true) and section:find("Sheets you saved\n  before show them as rules and filter the same", 1, true),
		"the changelog's 1.10.0 section: the rebuilt Filters window, Save as Section..., and what became of the old boxes")
	check(not section:find("\226\128\148") and not section:find("\226\128\147"), "with no dashes")
end)()
