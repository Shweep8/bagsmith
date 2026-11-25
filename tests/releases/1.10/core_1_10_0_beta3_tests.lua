-- ======== 1.10.0-beta3 (Shweep, 22 Nov) ========
-- The rule editor ("ready for next beta"): a section's name and its rules in one window, with what the rules would do
-- on the right; Add a Rule, with the game's own item types to tick; number rules (Item Level, Vendor Value) as a
-- range. Beside it: the Disenchant Helper no longer offers an item marked as junk ("when you mark an item to vendor
-- in DE Helper it stays in there, it should leave"), and the Classic icon mask from Jeor's pull request is only set
-- when it changes.

local CLOTH, LEATHER = "7:5", "7:6"
-- the game's item type lists, as Forever answers (shortened): names marked OBSOLETE, and the WoW Token
local CLASSES = { [0] = "Consumable", [1] = "Container", [2] = "Weapon", [3] = "Jewelry(OBSOLETE)", [4] = "Armor", [5] = "Reagent",
	[7] = "Trade Goods", [12] = "Quest", [15] = "Miscellaneous", [18] = "WoW Token" }
local SUBS = {
	[0] = { [1] = "Potions", [5] = "Food & Drink" }, [1] = { [0] = "Bag" }, [2] = { [0] = "One-Handed Axes", [15] = "Daggers" },
	[3] = { [0] = "Rings" },
	[4] = { [0] = "Miscellaneous", [1] = "Cloth", [2] = "Leather", [3] = "Mail", [4] = "Plate", [6] = "Shields" },
	[5] = { [0] = "Reagent" }, [7] = { [0] = "Trade Goods(OBSOLETE)", [5] = "Cloth", [6] = "Leather", [9] = "Herb", [12] = "Enchanting" },
	[12] = { [0] = "Quest" }, [15] = { [0] = "Junk", [4] = "Other" },
}
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
	tg(6, 10940, "Strange Dust", 12, "Enchanting", { price = 40 })
	tg(7, 4865, "Ruined Pelt", 6, "Leather", { q = 0 })
	M.put(0, 8, { id = 4040, name = "Glimmering Mail Gauntlets", q = 2, count = 1, class = 4, subclass = 3, type = "Armor", sub = "Mail", equip = "INVTYPE_HAND", bind = 2, price = 300, ilvl = 30 })
	M.put(0, 9, { id = 4329, name = "Seer's Belt", q = 2, count = 1, class = 4, subclass = 1, type = "Armor", sub = "Cloth", equip = "INVTYPE_WAIST", bind = 2, bound = true, price = 200, ilvl = 25 })
	M.put(0, 10, { id = 118, name = "Minor Healing Potion", q = 1, count = 3, class = 0, subclass = 1, type = "Consumable", sub = "Potions", price = 5, ilvl = 5 })
	M.put(0, 11, { id = 9001, name = "Robe of Power", q = 3, count = 1, class = 4, subclass = 1, type = "Armor", sub = "Cloth", equip = "INVTYPE_ROBE", bind = 2, price = 5000, ilvl = 38 })
	M.put(0, 12, { id = 9002, name = "Tough Jerkin", q = 1, count = 1, class = 4, subclass = 2, type = "Armor", sub = "Leather", equip = "INVTYPE_CHEST", price = 15000, ilvl = 20 })
	_G.INVTYPE_HEAD, _G.INVTYPE_HAND, _G.INVTYPE_WAIST, _G.INVTYPE_CHEST, _G.INVTYPE_ROBE = "Head", "Hands", "Waist", "Chest", "Chest"
	-- (the game's quality colors: the mock has none)
	_G.ITEM_QUALITY_COLORS = { [0] = { r = 0.62, g = 0.62, b = 0.62 }, { r = 1, g = 1, b = 1 }, { r = 0.12, g = 1, b = 0 }, { r = 0, g = 0.44, b = 0.87 }, { r = 0.64, g = 0.21, b = 0.93 }, { r = 1, g = 0.5, b = 0 } }
	if opts.lists ~= false then
		C_Item.GetItemClassInfo = function(c) return CLASSES[c] end
		C_Item.GetItemSubClassInfo = function(c, s) return SUBS[c] and SUBS[c][s] end
	end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local prof = { view = "list", grp = "type", favSection = true, recentSection = false }
	for k, v in pairs(opts.prof or {}) do prof[k] = v end
	_G.BagSmithDB = opts.saved or { version = 2, chars = {}, cache = {}, profiles = { Default = prof } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta3"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	return n, M, n.Sections, n.Rules, n.SectionEditor
end
local function cat(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r.cat, r end end end
local function click(b) b:GetScript("OnClick")(b) end
-- (by design since 1.10.0-beta11: + Add a Rule lists its kinds in groups, with five more of them, so a kind is picked
-- by its name here, not by its place in the list)
local function pick(menu, text) for _, it in ipairs(menu or {}) do if it.text == text then return it end end end
local function typeIn(box, text) box:SetText(text); box:GetScript("OnTextChanged")(box, true) end
local function names(list) local t = {}; for i, r in ipairs(list) do t[i] = (r.rec or r).name end; return table.concat(t, ", ") end
local function shownLines(f) local t = {}; for _, l in ipairs(f.lines) do if l:IsShown() then t[#t + 1] = l end end; return t end
local function entry(p, label) for _, e in ipairs(p.list) do if e.label == label then return e end end end
local function chipTexts(r) local t = {}; for _, c in ipairs(r.chips) do if c:IsShown() then t[#t + 1] = (c.label.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) .. (c.active and "*" or "") end end; return table.concat(t, ", ") end

;(function()
	-- number rules: what's kept, what fits, and how they read
	local n, M, S, R = boot()
	check(R.KEY_ORDER[5] == "ilvl" and R.KEY_ORDER[6] == "price" and R.KEYS.ilvl.label == "Item Level" and R.KEYS.price.label == "Vendor Value", "two new kinds of rule: Item Level and Vendor Value")
	local c = R.Clean({ rows = {
		{ k = "ilvl", v = { 30 } }, { k = "ilvl", v = { 40, 20 } }, { k = "ilvl", v = { 30, 30 }, n = true },
		{ k = "ilvl", v = { "x", -1, 2.5, 30, 99999, 45, 50 } }, { k = "ilvl", v = { "x" } }, { k = "price", v = { 0, 15000 } },
	} })
	check(c and #c.rows == 5, "five sound rows kept, the one with no number dropped (" .. tostring(c and #c.rows) .. ")")
	check(c.rows[1].v[1] == 30 and c.rows[1].v[2] == 9999, "one number alone means at least: 30 up to the top")
	check(c.rows[2].v[1] == 20 and c.rows[2].v[2] == 40, "a range given high then low is put in order")
	check(c.rows[3].v[1] == 30 and c.rows[3].v[2] == 30 and c.rows[3].n == nil, "the same number twice is kept as a range of one, and \"is not\" doesn't apply to numbers")
	check(c.rows[4].v[1] == 30 and c.rows[4].v[2] == 45 and #c.rows[4].v == 2, "only its first two sound numbers count (whole, from 0 to 9999)")
	check(c.rows[5].k == "price" and c.rows[5].v[2] == 15000, "Vendor Value in copper")
	local again = R.Clean(c)
	check(again and #again.rows == 5 and again.rows[3].v[2] == 30 and again.rows[1].v[2] == 9999, "cleaning twice changes nothing")
	local function rule(k, lo, hi) return { mode = "all", rows = { { k = k, v = { lo, hi } } } } end
	local _, gloves = cat(n, 4040)   -- item level 30, 3s
	check(R:Fits(rule("ilvl", 30, 9999), gloves) and R:Fits(rule("ilvl", 0, 30), gloves) and R:Fits(rule("ilvl", 30, 30), gloves), "item level 30 fits at least 30, at most 30 and exactly 30")
	check(not R:Fits(rule("ilvl", 31, 9999), gloves) and not R:Fits(rule("ilvl", 0, 29), gloves) and R:Fits(rule("ilvl", 20, 40), gloves), "not at least 31 or at most 29; it is between 20 and 40")
	check(R:Fits(rule("price", 300, 99999999), gloves) and not R:Fits(rule("price", 301, 99999999), gloves) and R:Fits(rule("price", 0, 300), gloves), "Vendor Value the same way, for one of the item")
	check(not R:Fits(rule("ilvl", 0, 9999), { itemID = 1, classID = 7 }) and not R:Fits(rule("price", 0, 99999999), { itemID = 1 }), "an item whose number isn't known yet fits no number rule")
	check(not R:Fits({ rows = { { k = "ilvl", v = { 30 } } } }, gloves), "(a range that was never cleaned, with one number, fits nothing)")
	-- in words
	check(R.Money(0) == "0c" and R.Money(99) == "99c" and R.Money(100) == "1s" and R.Money(15000) == "1g 50s" and R.Money(10203) == "1g 2s 3c", "money in plain words")
	check(R:RowText({ k = "ilvl", v = { 30, 9999 } }) == "Item Level is at least 30" and R:RowText({ k = "ilvl", v = { 0, 30 } }) == "Item Level is at most 30", "at least and at most, in words")
	check(R:RowText({ k = "ilvl", v = { 20, 30 } }) == "Item Level is between 20 and 30" and R:RowText({ k = "ilvl", v = { 30, 30 } }) == "Item Level is 30", "between, and exactly")
	check(R:RowText({ k = "price", v = { 15000, 99999999 } }) == "Vendor Value is at least 1g 50s" and R:RowText({ k = "price", v = { 100, 10000 } }) == "Vendor Value is between 1s and 1g", "Vendor Value in gold, silver and copper")
	check(R:Summary({ mode = "all", rows = { { k = "type", v = { "4:*" } }, { k = "ilvl", v = { 30, 9999 } } } }) == "Fits all: Type is Armor; Item Level is at least 30", "and in a section's one-line summary")
	-- two slots the game gives one name read as one
	check(R:RowText({ k = "slot", v = { "INVTYPE_CHEST", "INVTYPE_ROBE", "INVTYPE_HAND" } }) == "Slot is Chest or Hands", "Chest and Robe, both \"Chest\" in the game, are said once")
	-- New Section From This Item still offers only what two items can have the same
	check(#R:FactsOf(gloves) == 4 and #R:FactsOf(select(2, cat(n, 2589))) == 3, "New Section From This Item: no number to tick, as before")
	-- a section with a number rule sorts the bags, and survives a reload and a profile code
	local id = S:Create("Good Gear")
	S:SetRules(id, { mode = "all", rows = { { k = "type", v = { "4:*" } }, { k = "ilvl", v = { 30 } } } })
	check(cat(n, 4040) == id and cat(n, 9001) == id and cat(n, 4329) == "Gear" and cat(n, 9002) == "Gear", "Armor of item level 30 or more: the gauntlets and the robe, not the belt (25) or the jerkin (20)")
	local code = n.Share:Export()
	local saved = BagSmithDB
	n, M, S, R = boot({ saved = saved })
	local kept = n.db.customSections[1]
	check(kept and kept.rules and kept.rules.rows[2].k == "ilvl" and kept.rules.rows[2].v[1] == 30 and kept.rules.rows[2].v[2] == 9999, "after a reload the rule is as it was saved")
	check(cat(n, 4040) == kept.id and cat(n, 4329) == "Gear", "and sorts the same")
	local name = n.Share:Import(code, "Copied")
	local copied = BagSmithDB.profiles[name or "Copied"]
	check(copied and copied.customSections[1].rules.rows[2].v[1] == 30 and copied.customSections[1].rules.rows[2].v[2] == 9999, "a profile code carries it")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- the lists the editor offers
	local n, M, S, R = boot()
	local groups = R:TypeGroups()
	local labels = {}
	for i, g in ipairs(groups) do labels[i] = g.label .. ":" .. #g.kinds end
	check(table.concat(labels, " ") == "Consumable:2 Container:1 Weapon:2 Armor:6 Reagent:1 Trade Goods:4 Quest:1 Miscellaneous:2",
		"item types from the game's lists, in its order; OBSOLETE names and the WoW Token left out (" .. table.concat(labels, " ") .. ")")
	local tg = groups[6]
	check(tg.any == "7:*" and tg.kinds[1].v == "7:5" and tg.kinds[1].label == "Cloth" and tg.kinds[4].v == "7:12", "Trade Goods: its kinds by the game's numbers, the obsolete one gone")
	local slots = R:Options("slot")
	local byLabel = {}
	for _, o in ipairs(slots) do byLabel[o.label] = o end
	check(#slots == 4 and slots[1].label == "Head" and byLabel.Chest and #byLabel.Chest.v == 2 and byLabel.Chest.v[1] == "INVTYPE_CHEST" and byLabel.Chest.v[2] == "INVTYPE_ROBE",
		"slots this client names, in a worn order; Chest stands for the chest and the robe slot (" .. #slots .. ")")
	local q = R:Options("quality")
	check(#q == 6 and q[1].v[1] == 0 and q[6].v[1] == 5 and q[6].label == "Legendary", "qualities: Poor to Legendary")
	local b = R:Options("bind")
	check(#b == 4 and b[1].label == "Soulbound" and b[2].label == "Binds when equipped" and b[4].label == "No binding", "bindings: the four")
	check(#R:Options("ilvl") == 0, "(a number rule has no list)")
	check((n.errors or 0) == 0, "no errors")
	-- where the game has no lists to ask: the types of your own items
	n, M, S, R = boot({ lists = false })
	groups = R:TypeGroups()
	labels = {}
	for i, g in ipairs(groups) do labels[i] = g.label .. ":" .. #g.kinds end
	check(table.concat(labels, " ") == "Consumable:1 Armor:3 Trade Goods:4", "no lists from the game: the types of the items in your bags (" .. table.concat(labels, " ") .. ")")
	check((n.errors or 0) == 0, "no errors")
end)()

for _, skin in ipairs({ "modern", "classic" }) do
	-- a new section, built in the editor from nothing
	local S0 = skin .. ": "
	local n, M, S, R, E = boot({ prof = { skin = skin } })
	local menu, anchor
	n.ShowMenu = function(items, a) menu, anchor = items, a end
	local f = S:EditSection(); M.runTimers()
	check(f and f:IsShown() and f == E.frame and f.title.text == "New Section" and f.save.label.text == "Create Section" and f.edit:GetText() == "", S0 .. "New: the editor opens empty, titled New Section")
	check(f.ask.text == "Put an item in this section when it fits" and f.all.label.text == "all of these" and f.any.label.text == "any one of these" and f.all.active and not f.any.active, S0 .. "\"when it fits\" all of these (chosen) or any one of these")
	check(f.add.label.text == "+ Add a Rule" and f.foot.text == "Nothing changes in your bags until you save." and f.shownTitle.text == "What this does", S0 .. "+ Add a Rule, What this does, and the promise that nothing changes until you save")
	local lines = shownLines(f)
	check(#lines == 4 and lines[1].name.text == "Goes in this section" and lines[1].count.text == "0" and lines[2].name.text == "Nothing goes here yet. Add a rule to fill it by itself."
		and lines[3].name.text == "Fits, but stays somewhere else" and lines[3].count.text == "0" and lines[4].name.text == "Nothing yet.", S0 .. "no rules yet: both lists say so")
	check(not f.hint:IsShown() and not f.order:IsShown(), S0 .. "no hint about lines, no word on order, while there's nothing to say")
	-- + Add a Rule: what should the rule look at?
	click(f.add)
	local texts = {}
	for i, it in ipairs(menu) do texts[i] = it.text end
	-- (by design since 1.10.0-beta6: one quiet line after them says the optional ItemTree addon adds more)
	check(anchor == f.add and table.concat(texts, " | ") == "What should the rule look at? | About the item | Type | Slot | Quality | Binding | Item Level | Name | What it is for | Food, Drink and Potions | Quest Item | Crafting Material | Usable by Me | Value | Vendor Value | Optional: the ItemTree addon adds more rules here."
		and menu[1].title and pick(menu, "Type").tip:find("Cloth", 1, true) and menu[#menu].disabled, S0 .. "the menu: the kinds of rule, each with a hint")
	-- Quality: every choice on the row
	pick(menu, "Quality").onClick(); M.runTimers()
	local r1 = f.rows[1]
	check(#E.draft.rows == 1 and r1:IsShown() and r1.label.text == "Quality" and r1.verb.label.text == "is" and not r1.verb.active, S0 .. "Quality: a row that says Quality is")
	check(chipTexts(r1) == "Poor, Common, Uncommon, Rare, Epic, Legendary" and not r1.choose:IsShown(), S0 .. "its six choices on the row, none picked (" .. chipTexts(r1) .. ")")
	check(r1.note:IsShown() and r1.note.text == "Pick at least one, or this rule is ignored." and f.hint:IsShown() and f.hint.text == "Pick two or more on one line and either one counts.", S0 .. "nothing picked: the row says it's ignored; the hint about picking two appears")
	check(shownLines(f)[2].name.text == "Nothing goes here yet. Pick something on a rule.", S0 .. "and the list says to pick something")
	click(r1.chips[3]); click(r1.chips[4])
	check(chipTexts(r1) == "Poor, Common, Uncommon*, Rare*, Epic, Legendary" and not r1.note:IsShown() and #E.draft.rows[1].v == 2, S0 .. "Uncommon and Rare picked")
	-- (by design since 1.10.0-beta15, Shweep: "yes gold in classic style": in its own color in Modern; in Classic the
	-- text stays plain and Classic's selected gold shows it)
	check(((skin == "classic" and r1.chips[3].label.text == "Uncommon") or (skin ~= "classic" and r1.chips[3].label.text:find("^|cff%x%x%x%x%x%x") ~= nil)) and not r1.chips[1].label.text:find("|c", 1, true),
		S0 .. "a picked quality lights up: in its own color in Modern, plain text for Classic's gold (" .. tostring(r1.chips[3].label.text) .. ")")
	check(names(E.shown.here) == "Glimmering Mail Gauntlets, Robe of Power, Seer's Belt", S0 .. "the list follows: the three uncommon and rare items, A to Z (" .. names(E.shown.here) .. ")")
	click(r1.verb)
	check(r1.verb.label.text == "is not" and r1.verb.active and E.draft.rows[1].n == true and #E.shown.here == 8 and #E.shown.elsewhere == 1 and E.shown.elsewhere[1].why == "Grey items always go to Junk", S0 .. "is not: everything else, and the grey pelt fits but stays in Junk (" .. #E.shown.here .. ")")
	click(r1.verb)
	check(r1.verb.label.text == "is" and E.draft.rows[1].n == nil, S0 .. "and back to is")
	click(r1.chips[3])
	check(chipTexts(r1) == "Poor, Common, Uncommon, Rare*, Epic, Legendary" and names(E.shown.here) == "Robe of Power", S0 .. "a click on a picked choice takes it off")
	-- Type: picked in the second window
	click(f.add); pick(menu, "Type").onClick(); M.runTimers()
	local p = E.picker
	check(p and p:IsShown() and f.shade:IsShown() and #E.draft.rows == 1, S0 .. "Type: the list opens over the editor, which waits behind a shade; no rule added yet")
	check(p.title.text == "Add a Rule" and p.head.text == "Type" and p.hint.text == "What kind of item it is" and p.ask.text == "Tick every kind you want:" and p.ok.label.text == "Add Rule"
		and p.note:IsShown() and p.note.text == "This list comes from the game itself, so a new kind of item shows up here on its own.", S0 .. "Add a Rule, Type: its words")
	local heads = {}
	for i, e in ipairs(p.list) do heads[i] = (e.head and "+" or "") .. e.label .. (e.count and (" (" .. e.count .. ")") or "") end
	check(table.concat(heads, " | ") == "+Consumable (2 kinds) | Container | +Weapon (2 kinds) | +Armor (6 kinds) | Reagent | +Trade Goods (4 kinds) | Quest | +Miscellaneous (2 kinds)",
		S0 .. "each kind of item, closed, with how many kinds it has; a type with one kind is a single line (" .. table.concat(heads, " | ") .. ")")
	check(p.say.text == "Tick at least one kind." and p.ok.alpha == 0.5, S0 .. "nothing ticked: it says so, and Add Rule is dimmed")
	click(p.ok)
	check(p:IsShown() and #E.draft.rows == 1, S0 .. "Add Rule with nothing ticked adds nothing")
	E:PickerClick(entry(p, "Trade Goods"))
	check(#p.list == 13 and entry(p, "Any kind of Trade Goods") and entry(p, "Herb") and entry(p, "Trade Goods").open, S0 .. "a click opens Trade Goods: Any kind of Trade Goods, then its four kinds")
	E:PickerClick(entry(p, "Cloth")); E:PickerClick(entry(p, "Leather"))
	check(entry(p, "Cloth").on and entry(p, "Leather").on and not entry(p, "Herb").on and entry(p, "Trade Goods").count == "2 of 4 ticked", S0 .. "Cloth and Leather ticked: 2 of 4 ticked")
	check(p.say.text == "Type is Trade Goods: Cloth or Trade Goods: Leather" and p.ok.alpha == 1 and p.sayLabel.text == "Your rule will say", S0 .. "Your rule will say: Type is Trade Goods: Cloth or Trade Goods: Leather")
	-- a row's own check box works like its row
	local row
	for _, w in ipairs(p.rows) do if w:IsShown() and w.entry and w.entry.label == "Herb" then row = w end end
	check(row and row.check:IsShown() and not row.check:GetChecked() and not row.arrow:IsShown(), S0 .. "(Herb's row: a check box, unticked)")
	click(row.check)
	check(entry(p, "Herb").on and entry(p, "Trade Goods").count == "3 of 4 ticked", S0 .. "ticking the box itself ticks it")
	click(row)
	check(not entry(p, "Herb").on, S0 .. "and a click on the row unticks it")
	-- Any kind of Trade Goods stands for all of them
	E:PickerClick(entry(p, "Any kind of Trade Goods"))
	check(#E.pick.v == 1 and E.pick.v[1] == "7:*" and entry(p, "Cloth").on and entry(p, "Cloth").locked and entry(p, "Trade Goods").count == "every kind" and p.say.text == "Type is Trade Goods",
		S0 .. "Any kind of Trade Goods: one value for the whole type; its kinds show ticked and can't be changed")
	E:PickerClick(entry(p, "Cloth"))
	check(#E.pick.v == 1, S0 .. "(a click on a kind does nothing while Any is ticked)")
	E:PickerClick(entry(p, "Any kind of Trade Goods"))
	check(#E.pick.v == 0 and not entry(p, "Cloth").on and not entry(p, "Cloth").locked, S0 .. "unticked again: nothing ticked")
	E:PickerClick(entry(p, "Cloth")); E:PickerClick(entry(p, "Reagent"))
	check(entry(p, "Reagent").on and E.pick.v[2] == "5:*", S0 .. "a single-line type ticks as the whole type")
	E:PickerClick(entry(p, "Reagent"))
	click(p.cancel)
	check(not p:IsShown() and not f.shade:IsShown() and #E.draft.rows == 1 and E.pick == nil, S0 .. "Cancel: the list closes, the shade lifts, nothing added")
	click(f.add); pick(menu, "Type").onClick(); M.runTimers()
	check(#E.pick.v == 0 and #p.list == 8, S0 .. "opened again: it starts clean")
	E:PickerClick(entry(p, "Trade Goods")); E:PickerClick(entry(p, "Cloth")); E:PickerClick(entry(p, "Leather"))
	click(p.ok); M.runTimers()
	local r2 = f.rows[2]
	check(not p:IsShown() and #E.draft.rows == 2 and E.draft.rows[2].k == "type" and E.draft.rows[2].v[1] == CLOTH and E.draft.rows[2].v[2] == LEATHER, S0 .. "Add Rule: the Type rule joins the section")
	check(r2.label.text == "Type" and chipTexts(r2) == "Trade Goods: Cloth*, Trade Goods: Leather*" and r2.choose:IsShown() and r2.choose.label.text == "Choose...", S0 .. "its row: what was picked, and Choose... for the rest (" .. chipTexts(r2) .. ")")
	check(#E.shown.here == 0 and shownLines(f)[2].name.text == "Nothing goes here yet. Pick something else on a rule, or switch to any one of these.", S0 .. "all of these: nothing is both rare and cloth, and the list suggests any one of these")
	click(f.any)
	check(E.draft.mode == "any" and f.any.active and not f.all.active and names(E.shown.here) == "Light Leather, Linen Cloth, Robe of Power, Silk Cloth, Wool Cloth", S0 .. "any one of these: the rare robe, the cloth and the leather (" .. names(E.shown.here) .. ")")
	check(#E.shown.elsewhere == 1 and E.shown.elsewhere[1].rec.name == "Ruined Pelt", S0 .. "the grey pelt fits (leather) but stays in Junk")
	-- the list on the right, as drawn
	lines = shownLines(f)
	check(lines[1].count.text == "5" and lines[2].kind == "item" and lines[2].name.text == "Light Leather" and lines[2].icon:IsShown() and lines[2].id == 2318 and not lines[2].why:IsShown(), S0 .. "Goes in this section 5: each item with its icon")
	check(lines[7].kind == "head" and lines[7].name.text == "Fits, but stays somewhere else" and lines[7].count.text == "1" and lines[8].name.text == "Ruined Pelt" and lines[8].why:IsShown() and lines[8].why.text == "Grey items always go to Junk",
		S0 .. "Fits, but stays somewhere else 1: the item, and why under it")
	check(f.box.points[1] and f.box.h and f.box.h > 40, S0 .. "in its own outline")
	-- Choose... reopens the list for that rule
	click(r2.choose); M.runTimers()
	check(p:IsShown() and p.title.text == "Change a Rule" and p.ok.label.text == "Done" and entry(p, "Trade Goods").open and entry(p, "Cloth").on and entry(p, "Leather").on and #E.pick.v == 2, S0 .. "Choose...: the same list, opened where the ticks are, with Done")
	E:PickerClick(entry(p, "Leather")); E:PickerClick(entry(p, "Armor")); E:PickerClick(entry(p, "Mail"))
	check(#E.draft.rows[2].v == 2, S0 .. "(the rule itself isn't touched until Done)")
	click(p.ok); M.runTimers()
	check(chipTexts(r2) == "Trade Goods: Cloth*, Armor: Mail*", S0 .. "Done: Cloth and Mail (" .. chipTexts(r2) .. ")")
	click(r2.chips[2])
	check(chipTexts(r2) == "Trade Goods: Cloth*" and #E.draft.rows[2].v == 1, S0 .. "a click on a picked type takes it off the rule")
	-- the first rule removed, then saved
	click(r1.remove)
	check(#E.draft.rows == 1 and E.draft.rows[1].k == "type" and f.rows[1].label.text == "Type" and not f.rows[2]:IsShown(), S0 .. "the x removes a rule")
	click(f.save)
	check(f:IsShown() and f.err.text == "Enter a name first." and #S:Customs() == 0, S0 .. "Create with no name: it asks for one, and makes nothing")
	typeIn(f.edit, "Cloth")
	check(f.err.text == "", S0 .. "typing a name clears that")
	click(f.save); M.runTimers()
	local made = S:Customs()[1]
	check(not f:IsShown() and made and made.name == "Cloth" and made.rules and made.rules.mode == "any" and #made.rules.rows == 1 and made.rules.rows[1].v[1] == CLOTH, S0 .. "Create Section: the section and its rule")
	check(cat(n, 2589) == made.id and cat(n, 4306) == made.id and cat(n, 2318) == "TradeGoods", S0 .. "and the cloth is in it")
	check((n.errors or 0) == 0, S0 .. "no errors")
end

;(function()
	-- an existing section: its rules as they were saved, changed and saved again
	local n, M, S, R, E = boot()
	local menu
	n.ShowMenu = function(items) menu = items end
	local mats = S:CreateWithRules("All Materials", { mode = "all", rows = { { k = "type", v = { "7:*" } } } })
	local gear = S:Create("Gear to Sell")
	S:SetRules(gear, { mode = "all", rows = {
		{ k = "type", v = { "4:*" } }, { k = "bind", v = { "bop" }, n = true }, { k = "slot", v = { "INVTYPE_CHEST" } },
		{ k = "ilvl", v = { 30, 9999 } }, { k = "price", v = { 0, 15000 } }, { k = "ilvl", v = { 20, 40 } }, { k = "itemtree_prof", v = { "Tailoring" } },
	} })
	n.Marks:ToggleFavorite(select(2, cat(n, 2592))); M.runTimers()   -- Wool Cloth starred
	local f = S:EditSection(gear); M.runTimers()
	check(f:IsShown() and f.title.text == "Edit Section" and f.save.label.text == "Save Section" and f.edit:GetText() == "Gear to Sell" and #E.draft.rows == 7, "Edit: the section's name and its seven rules")
	local rows = f.rows
	check(rows[1].label.text == "Type" and chipTexts(rows[1]) == "Armor*", "Type is Armor: the whole type as one choice")
	check(rows[2].label.text == "Binding" and rows[2].verb.label.text == "is not" and rows[2].verb.active and chipTexts(rows[2]) == "Soulbound*, Binds when equipped, Binds when used, No binding", "Binding is not Soulbound: its four choices on the row")
	check(rows[3].label.text == "Slot" and chipTexts(rows[3]) == "Chest*" and rows[3].choose:IsShown(), "Slot is Chest, with Choose...")
	-- numbers: at least, at most, between
	local n1 = rows[4].num[1]
	check(rows[4].label.text == "Item Level" and rows[4].verb.label.text == "at least" and n1:IsShown() and n1.boxes[1]:GetText() == "30" and not rows[4].num[2]:IsShown() and not n1.boxes[2]:IsShown() and not rows[4].choose:IsShown(),
		"Item Level at least 30: one box, holding 30")
	local m1 = rows[5].num[1]
	check(rows[5].label.text == "Vendor Value" and rows[5].verb.label.text == "at most" and m1.boxes[1]:GetText() == "1" and m1.boxes[2]:GetText() == "50" and m1.boxes[3]:GetText() == "0" and m1.tags[1]:IsShown() and m1.tags[1].text == "g",
		"Vendor Value at most 1g 50s: gold, silver and copper boxes")
	check(rows[6].verb.label.text == "between" and rows[6].num[1].boxes[1]:GetText() == "20" and rows[6].num[2]:IsShown() and rows[6].num[2].boxes[1]:GetText() == "40" and rows[6].andText:IsShown(), "Item Level between 20 and 40: two boxes with \"and\"")
	check(rows[7].label.text == "Another addon's rule" and not rows[7].verb:IsShown() and rows[7].note:IsShown() and rows[7].note.text == "From another addon or a newer BagSmith. It's kept as it is." and rows[7].remove:IsShown(),
		"a rule this version doesn't know: shown, kept as it is, and it can be removed")
	check(f.hint:IsShown() and f.order:IsShown() and f.order.text == "If an item fits two of your sections, the one higher on your list gets it. All Materials is above this one.", "the order: All Materials is above this one")
	check(#E.shown.here == 0, "(with the unknown rule in \"all of these\", nothing fits)")
	click(rows[7].remove)
	-- (Armor, not soulbound, Chest, item level 30+, at most 1g 50s, between 20 and 40: the robe, 38 and 50s)
	check(#E.draft.rows == 6 and names(E.shown.here) == "", "the unknown rule removed: still nothing, since the Chest rule names the chest slot and not the robe's")
	-- the slot list: Chest stands for both slots
	click(rows[3].choose); M.runTimers()
	local p = E.picker
	check(p:IsShown() and p.head.text == "Slot" and p.ask.text == "Tick every slot you want:" and not p.note:IsShown() and #p.list == 4 and entry(p, "Chest").on, "Slot: its list (no word about the game's type lists), Chest ticked")
	E:PickerClick(entry(p, "Chest"))
	check(#E.pick.v == 0 and p.say.text == "Tick at least one slot.", "unticked: both of Chest's slots come off")
	E:PickerClick(entry(p, "Chest")); E:PickerClick(entry(p, "Hands"))
	check(#E.pick.v == 3 and p.say.text == "Slot is Chest or Hands", "Chest ticked again brings both slots; with Hands: Slot is Chest or Hands")
	click(p.ok); M.runTimers()
	check(chipTexts(rows[3]) == "Chest*, Hands*" and #E.draft.rows[3].v == 3, "Done: two choices on the row, three slots behind them")
	check(names(E.shown.here) == "Glimmering Mail Gauntlets, Robe of Power", "now the gauntlets and the robe fit (" .. names(E.shown.here) .. ")")
	-- typing a number
	typeIn(n1.boxes[1], "35")
	check(E.draft.rows[4].a == 35 and n1.boxes[1]:GetText() == "35" and names(E.shown.here) == "Robe of Power", "at least 35 typed: only the robe (38), and the box is left as typed")
	typeIn(n1.boxes[1], "")
	check(E.draft.rows[4].a == nil and rows[4].note:IsShown() and rows[4].note.text == "Type a number, or this rule is ignored." and names(E.shown.here) == "Glimmering Mail Gauntlets, Robe of Power, Tough Jerkin", "the box emptied: the rule is ignored and says so, and the jerkin (item level 20) fits again")
	-- at least / at most / between
	click(rows[4].verb)
	check(#menu == 3 and menu[1].text == "at least" and menu[1].checked and menu[2].text == "at most" and menu[3].text == "between" and not menu[3].checked, "a click on \"at least\": the three ways to compare")
	typeIn(n1.boxes[1], "30")
	menu[3].onClick(); M.runTimers()
	check(rows[4].verb.label.text == "between" and rows[4].num[2]:IsShown() and rows[4].num[2].boxes[1]:GetText() == "" and rows[4].note:IsShown(), "between: a second box, empty, so the rule waits")
	typeIn(rows[4].num[2].boxes[1], "32")
	check(not rows[4].note:IsShown() and names(E.shown.here) == "Glimmering Mail Gauntlets", "between 30 and 32: the gauntlets (30)")
	click(rows[4].verb); menu[2].onClick(); M.runTimers()
	check(rows[4].verb.label.text == "at most" and not rows[4].num[2]:IsShown() and E.draft.rows[4].b == nil and E.draft.rows[4].a == 30, "at most: one box again, keeping the first number")
	-- money, typed in three boxes
	typeIn(m1.boxes[1], ""); typeIn(m1.boxes[2], "2"); typeIn(m1.boxes[3], "99")
	check(E.draft.rows[5].a == 299 and names(E.shown.here) == "", "at most 2s 99c typed: the gauntlets (3s) no longer fit")
	typeIn(m1.boxes[2], "3"); typeIn(m1.boxes[3], "")
	check(E.draft.rows[5].a == 300 and names(E.shown.here) == "Glimmering Mail Gauntlets", "at most 3s: they do")
	-- a new number rule
	click(f.add); pick(menu, "Item Level").onClick(); M.runTimers()
	check(#E.draft.rows == 7 and rows[7].label.text == "Item Level" and rows[7].verb.label.text == "at least" and rows[7].note.text == "Type a number, or this rule is ignored." and not rows[7].num[1].boxes[2]:IsShown(), "Add a Rule, Item Level: a row waiting for its number")
	click(rows[7].remove)
	-- saved under a new name
	typeIn(f.edit, "all materials")
	click(f.save)
	check(f:IsShown() and f.err.text == "There's already a section with that name.", "a name another section has: it says so, and nothing is saved")
	check(S:Custom(gear).name == "Gear to Sell" and #S:Rules(gear).rows == 7, "(the section is as it was)")
	typeIn(f.edit, "Cheap Gear")
	click(f.save); M.runTimers()
	local c = S:Custom(gear)
	check(not f:IsShown() and c.name == "Cheap Gear" and #c.rules.rows == 6, "Save Section: renamed, six rules")
	check(c.rules.rows[3].k == "slot" and #c.rules.rows[3].v == 3 and c.rules.rows[4].k == "ilvl" and c.rules.rows[4].v[1] == 0 and c.rules.rows[4].v[2] == 30 and c.rules.rows[5].v[1] == 0 and c.rules.rows[5].v[2] == 300 and c.rules.rows[6].v[1] == 20 and c.rules.rows[6].v[2] == 40,
		"each rule saved as it was left: three slots, at most 30, at most 3s, between 20 and 40")
	check(R:Summary(c.rules) == "Fits all: Type is Armor; Binding is not Soulbound; Slot is Chest or Hands; Item Level is at most 30; Vendor Value is at most 3s; Item Level is between 20 and 40", "its summary in words (" .. R:Summary(c.rules) .. ")")
	check(cat(n, 4040) == gear and cat(n, 9001) == "Gear", "and the bags follow: the gauntlets are in it")
	-- opened again: the same, and Cancel leaves it alone
	f = S:EditSection(gear); M.runTimers()
	check(#E.draft.rows == 6 and f.rows[4].verb.label.text == "at most" and f.rows[4].num[1].boxes[1]:GetText() == "30" and f.rows[5].num[1].boxes[2]:GetText() == "3" and f.rows[5].num[1].boxes[1]:GetText() == "0", "opened again: the rules read back the same")
	click(f.rows[1].remove); click(f.any); typeIn(f.edit, "Something Else")
	click(f.cancel)
	check(not f:IsShown() and S:Custom(gear).name == "Cheap Gear" and #S:Rules(gear).rows == 6 and S:Rules(gear).mode == "all", "Cancel: nothing changed")
	-- every rule removed: the section keeps only what you put in it
	f = S:EditSection(gear); M.runTimers()
	for _ = 1, 6 do click(f.rows[1].remove) end
	check(#E.draft.rows == 0 and not f.hint:IsShown(), "(all six removed)")
	click(f.save); M.runTimers()
	check(S:Rules(gear) == nil and S:Custom(gear) ~= nil and cat(n, 4040) == "Gear", "saved with no rules: the section stays, filled by hand only, and its items go back")
	-- the other section: what fits but stays somewhere else, with why
	S:SetRules(gear, { mode = "all", rows = { { k = "type", v = { CLOTH } } } })
	S:Move(4306, gear); M.runTimers()   -- Silk Cloth put in Gear to Sell by hand... and All Materials is first
	f = S:EditSection(gear); M.runTimers()
	local why = {}
	for _, e in ipairs(E.shown.elsewhere) do why[e.rec.name] = e.why end
	check(names(E.shown.here) == "Silk Cloth" and why["Linen Cloth"] == "All Materials is higher on your list" and why["Wool Cloth"] == "You starred it, so it stays in Favorites", "what goes here, and why the rest stay: a higher section, a star (" .. names(E.shown.here) .. ")")
	S:Reorder(gear, -1); M.runTimers()
	check(f:IsShown() and names(E.shown.here) == "Linen Cloth, Silk Cloth" and f.order.text == "If an item fits two of your sections, the one higher on your list gets it. This one is first.", "moved up in Settings while the editor is open: the list and the word on order follow")
	-- the list follows the bags
	M.put(0, 13, { id = 14047, name = "Runecloth", q = 1, count = 20, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 400, ilvl = 50 })
	M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	check(names(E.shown.here) == "Linen Cloth, Runecloth, Silk Cloth", "a new stack of cloth in the bags shows up in the list (" .. names(E.shown.here) .. ")")
	-- the section deleted behind it
	S:Delete(gear); M.runTimers()
	check(not f:IsShown(), "the section deleted while it's being edited: the editor closes")
	-- a long list is cut off with a count
	f = S:EditSection(mats); M.runTimers()
	check(#E.draft.rows == 1 and names(E.shown.here) == "Light Leather, Linen Cloth, Peacebloom, Runecloth, Silk Cloth, Strange Dust" and #E.shown.elsewhere == 2, "All Materials: six go in, two stay (a star, a grey)")
	click(f.cancel)
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- limits, Escape, another profile
	local n, M, S, R, E = boot()
	local menu
	n.ShowMenu = function(items) menu = items end
	local f = S:EditSection(); M.runTimers()
	for _ = 1, R.MAX_ROWS + 2 do E:AddRow("quality") end
	check(#E.draft.rows == R.MAX_ROWS and f.add.alpha == 0.5, "a section holds " .. R.MAX_ROWS .. " rules: + Add a Rule dims at the last")
	click(f.add)
	check(#menu == 1 and menu[1].disabled and menu[1].text == ("A section can have %d rules, and this one has them all."):format(R.MAX_ROWS), "and says why")
	check(f.rulesHeight > 280 and f.rulesChild.h == f.rulesHeight, "(more rules than fit: the list of rules scrolls)")
	for _ = 1, R.MAX_ROWS - 1 do click(f.rows[1].remove) end
	-- Escape closes the list first, then the editor
	E:OpenPicker(nil, "slot"); M.runTimers()
	local proxy = f.bsEscape
	check(proxy and proxy:IsShown() and E.picker:IsShown(), "(the list is up over the editor)")
	proxy:Hide()
	check(not E.picker:IsShown() and f:IsShown() and proxy:IsShown(), "Escape: the list closes and the editor stays")
	proxy:Hide()
	check(not f:IsShown(), "Escape again: the editor closes")
	check(#S:Customs() == 0, "and nothing was made")
	-- the name box: Escape and Enter only leave the box
	f = S:EditSection(); M.runTimers()
	f.edit:GetScript("OnEscapePressed")(f.edit); f.edit:GetScript("OnEnterPressed")(f.edit)
	check(f:IsShown(), "Escape or Enter in the name box doesn't close the editor")
	-- hidden with the list up: both go, and it opens clean
	E:OpenPicker(nil, "type"); M.runTimers()
	f:Hide()
	check(not E.picker:IsShown() and E.pick == nil and not f.shade:IsShown(), "the editor closed with the list up: the list goes with it")
	-- another profile: the editor was for the old one
	f = S:EditSection(); M.runTimers()
	E:AddRow("quality"); click(f.rows[1].chips[2]); typeIn(f.edit, "Whites")
	n.Profiles:Use("Second"); M.runTimers()
	check(not f:IsShown() and #n.db.customSections == 0, "switching profile closes the editor, and nothing is made in the new one")
	check(S:EditSection("c99") == nil, "(a section that doesn't exist opens nothing)")
	check((n.errors or 0) == 0, "no errors")
end)()

for _, skin in ipairs({ "modern", "classic" }) do
	-- where it opens from: Settings > Custom Sections, and a section's own menu
	local S0 = skin .. ": "
	local n, M, S, R, E = boot({ prof = { skin = skin } })
	local cloth = S:CreateWithRules("Cloth", { mode = "all", rows = { { k = "type", v = { CLOTH } } } })
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("custom"); M.runTimers()
	local newBtn, row
	for _, b in ipairs(P.pools.btn) do if b:IsShown() and b.label.text == "New Section..." then newBtn = b end end
	for _, w in ipairs(P.pools.csec or {}) do if w:IsShown() and w.id == cloth then row = w end end
	check(row and row.ren.tip == "Edit this section: its name and its rules" and row.ren.tex.texture:find("ui%-pencil"), S0 .. "the pencil beside a section: Edit this section: its name and its rules")
	click(row.ren); M.runTimers()
	local f = E.frame
	check(f and f:IsShown() and E.draft.id == cloth and f.edit:GetText() == "Cloth" and f.title.text == "Edit Section", S0 .. "it opens the editor for that section")
	check(f.toplevel == true and f.raisedAt ~= nil and f.raisedAt > (P.frame.raisedAt or 0), S0 .. "in front of Settings, which shares its layer")
	-- a rule added there, saved: the page's line for the section follows
	E:AddRow("quality"); click(f.rows[2].chips[2])
	click(f.save); M.runTimers()
	row = nil
	for _, w in ipairs(P.pools.csec or {}) do if w:IsShown() and w.id == cloth then row = w end end
	check(row and row.sub.text == "Fits all: Type is Trade Goods: Cloth; Quality is Common", S0 .. "saved: Settings shows the new rules in words (" .. tostring(row and row.sub.text) .. ")")
	check(newBtn ~= nil, S0 .. "(New Section... is on the page)")
	click(newBtn); M.runTimers()
	check(f:IsShown() and E.draft.id == nil and f.title.text == "New Section" and #E.draft.rows == 0, S0 .. "New Section... opens the editor for a new one")
	typeIn(f.edit, "Keepsakes"); click(f.save); M.runTimers()
	local made = S:Customs()[2]
	check(made and made.name == "Keepsakes" and made.rules == nil and not f:IsShown(), S0 .. "a name and no rules: a section to fill by hand, as before")
	local found
	for _, t in ipairs(P.pools.text or {}) do
		local words = tostring(t.text and t.text.text or t.text)
		if t:IsShown() and words:find("Give it rules with the pencil beside it", 1, true) then found = true end
	end
	check(found, S0 .. "the page says where rules are given")
	P:Hide()
	-- the section's own menu
	local menu
	n.ShowMenu = function(items) menu = items end
	S:SectionMenu(cloth)
	local edit, rename
	for i, it in ipairs(menu) do if it.text == "Edit Section..." then edit = i end if it.text == "Rename..." then rename = i end end
	-- (by design since 1.11.0-beta2: Sections on This Sheet... sits between the two)
	check(edit and rename and edit == rename - 2 and menu[edit + 1].text == "Sections on This Sheet...", S0 .. "a custom section's menu: Edit Section..., above Sections on This Sheet... and Rename...")
	menu[edit].onClick(); M.runTimers()
	check(f:IsShown() and E.draft.id == cloth and #E.draft.rows == 2, S0 .. "and it opens the editor with the section's two rules")
	click(f.cancel)
	S:SectionMenu("TradeGoods")
	edit = nil
	for _, it in ipairs(menu) do if it.text == "Edit Section..." then edit = true end end
	check(not edit, S0 .. "one of BagSmith's own sections has no Edit Section...")
	check((n.errors or 0) == 0, S0 .. "no errors")
end

;(function()
	-- the Disenchant Helper: an item marked as junk isn't offered while it's marked
	package.loaded.mock = nil
	local M = require("mock")
	local DEID = 13262
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
	M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
	M.put(0, 3, { id = 7003, name = "Rare Chest", q = 3, count = 1, class = 4, subclass = 2, price = 2000, ilvl = 45, equip = "INVTYPE_CHEST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
	_G.IsSpellKnown = function(id) return id == DEID end
	_G.GetNumSkillLines = function() return 2 end
	_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, 300 end
	_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
	_G.RegisterStateDriver = function() end
	_G.UnregisterStateDriver = function() end
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta3"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE = n.Disenchant
	local function recOf(id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
	local function offered(id) for _, e in ipairs(DE.entries or {}) do if e.itemID == id then return e end end end
	DE:Show(); M.runTimers()
	check(#DE.entries == 3 and offered(7001) and offered(7002) and offered(7003), "(three pieces to work through)")
	local boots = offered(7001)
	DE:Select(boots)
	DE:JunkCurrent(); M.runTimers()
	check(n.Junk:Marked(7001), "Mark as Junk in the Helper marks the item")
	check(#DE.entries == 2 and not offered(7001) and DE.current and DE.current.itemID ~= 7001, "and it leaves the list: the Helper moves on to the next")
	local ok, why = DE:Eligible(recOf(7001), DE:Skill())
	check(ok == false and why == "junk", "it isn't offered because it's marked as junk")
	check(DE.held and DE.held.by.junk and #DE.held.by.junk == 1 and DE.held.by.junk[1] == "Sturdy Boots" and DE.held.total == 1, "and it's counted with the items not offered")
	local lines = n.Why:Lines(DE.held)
	check(#lines == 1 and lines[1]:find("Marked as junk (1):", 1, true) and lines[1]:find("Sturdy Boots", 1, true), "under its own words: Marked as junk (" .. tostring(lines[1]) .. ")")
	check(n.Why.NOUN.junk[1] == "item you marked as junk" and n.Why.NOUN.junk[2] == "items you marked as junk", "(and the sentence for an empty list has its words)")
	-- marked from the bags, not the Helper: the same
	n.Junk:Toggle(recOf(7002)); M.runTimers(); DE:Refresh()
	check(n.Junk:Marked(7002) and not offered(7002) and #DE.entries == 1 and #DE.held.by.junk == 2, "an item marked as junk from the bags leaves it too")
	-- the mark comes off: it's offered again
	n.Junk:Toggle(recOf(7001)); M.runTimers(); DE:Refresh()
	check(not n.Junk:Marked(7001) and offered(7001) and #DE.entries == 2, "the mark taken off: the boots are offered again")
	check(not (DE.skipped and next(DE.skipped)), "(nothing was skipped for the session: the mark alone decides)")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- the Classic icon mask (Jeor's pull request): set once, and again only when it changes
	local n, M = boot({ prof = { skin = "classic", view = "icon" } })
	local b = n.Buttons:Get(0, 1)
	check(b and b.classicMask ~= nil, "(Classic: the item's icon has its mask)")
	local sets = 0
	local real = b.classicMask.SetTexture
	b.classicMask.SetTexture = function(self, ...) sets = sets + 1; return real(self, ...) end
	for _ = 1, 3 do M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers() end
	n.Buttons:ApplyIconCrop(b); n.Buttons:ApplyIconCrop(b)
	check(sets == 0, "redraws don't set the mask's texture again (" .. sets .. ")")
	n:Set("skin", "modern"); M.runTimers(); M.runTimers()
	n.Buttons:ApplyIconCrop(b)
	check(sets == 1 and b.classicMaskIs == "Interface\\Buttons\\WHITE8X8", "Modern: set once, to no mask at all")
	n:Set("skin", "classic"); M.runTimers(); M.runTimers()
	n.Buttons:ApplyIconCrop(b)
	check(sets == 2 and b.classicMaskIs:find("ui%-icon%-mask"), "back to Classic: set once more, to the mask")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- the TOC and the changelog
	local f = io.open("BagSmith/BagSmith.toc"); local toc = f:read("*a"); f:close()
	-- (by design since 1.10.0-beta4: the rows moved to Frames/RuleList.lua, shared with the Filters window, loaded first)
	check(toc:find("Frames\\SectionsUI.lua\nFrames\\RuleList.lua\nFrames\\SectionEditor.lua\n", 1, true), "the TOC loads the rule list and the editor right after the sections' menus")
	f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	local section = ("\n" .. log):match("\n(## 1%.10%.0\n.-)\n## 1%.9%.8\n") or ""
	check(section:find("rule editor", 1, true) and section:find("item level or\n  vendor value", 1, true) and section:find("Disenchant Helper no longer offers an item you've marked as junk", 1, true) and section:find("Thanks to Jeor!", 1, true),
		"the changelog's 1.10.0 section: the rule editor, the Disenchant Helper's change, and Jeor's cleaner Classic icons")
	check(not section:find("\226\128\148") and not section:find("\226\128\147"), "with no dashes")
end)()
