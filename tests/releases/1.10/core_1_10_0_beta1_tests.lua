-- ======== 1.10.0-beta1 (Shweep, 20 Nov) ========
-- Custom sections that fill themselves (a player's idea, built Shweep's way: "rules on custom sections", "an item can
-- only appear in one category", "incredibly user-friendly"). Core/Rules.lua: a section's rules, { mode, rows }; the
-- first custom section in your list whose rules an item fits gets it, after junk, Favorites and the items you moved by
-- hand; grey items are left to Junk; a hand move always sticks. "New Section From This Item" makes one from an item's
-- own details, with a list of what would go in it. The Custom Sections page shows each section's rules and has arrows
-- for their order.

local CLOTH, LEATHER, HERB, DUST = "7:5", "7:6", "7:9", "7:12"
local function boot(saved)
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 16
	local function tg(slot, id, name, sub, subName, extra)
		local it = { id = id, name = name, q = 1, count = 5, class = 7, subclass = sub, type = "Trade Goods", sub = subName, price = 10 }
		for k, v in pairs(extra or {}) do it[k] = v end
		M.put(0, slot, it)
	end
	tg(1, 2589, "Linen Cloth", 5, "Cloth")
	tg(2, 2592, "Wool Cloth", 5, "Cloth")
	tg(3, 4306, "Silk Cloth", 5, "Cloth")
	tg(4, 2318, "Light Leather", 6, "Leather")
	tg(5, 2447, "Peacebloom", 9, "Herb")
	tg(6, 10940, "Strange Dust", 12, "Enchanting")
	tg(7, 4865, "Ruined Pelt", 6, "Leather", { q = 0 })
	M.put(0, 8, { id = 4040, name = "Glimmering Mail Gauntlets", q = 2, count = 1, class = 4, subclass = 3, type = "Armor", sub = "Mail", equip = "INVTYPE_HAND", bind = 2, price = 300 })
	M.put(0, 9, { id = 4329, name = "Seer's Belt", q = 2, count = 1, class = 4, subclass = 1, type = "Armor", sub = "Cloth", equip = "INVTYPE_WAIST", bind = 2, bound = true, price = 200 })
	M.put(0, 10, { id = 118, name = "Minor Healing Potion", q = 1, count = 3, class = 0, subclass = 1, type = "Consumable", sub = "Potion", price = 5 })
	_G.INVTYPE_HAND, _G.INVTYPE_WAIST = "Hands", "Waist"
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = saved or { version = 2, chars = {}, cache = {}, profiles = { Default = { view = "list", grp = "type", favSection = true, recentSection = false } } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta1"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	return n, M, n.Sections, n.Rules
end
local function cat(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r.cat, r end end end
local function typeRule(...) return { mode = "all", rows = { { k = "type", v = { ... } } } } end

;(function()
	-- the rules themselves: what's kept from saved or imported data
	local n, M, S, R = boot()
	check(R.Clean(nil) == nil and R.Clean("x") == nil and R.Clean({}) == nil and R.Clean({ rows = {} }) == nil, "nothing usable: no rules")
	local c = R.Clean({ mode = "sideways", rows = {
		{ k = "type", v = { CLOTH, CLOTH, "7:*", "cloth", 7, "7:5:1", "" } },
		{ k = "quality", v = { 1, 2.5, 9, -1, "1", 3 }, n = true },
		{ k = "bind", v = { "boe", "glue" }, n = "yes" },
		{ k = "slot", v = { "INVTYPE_HAND", "hand", "INVTYPE_" } },
		{ k = "type", v = {} }, { k = "quality" }, "junk", { k = 5, v = { 1 } }, { k = "bad key!", v = { 1 } },
	} })
	check(c and c.mode == "all" and #c.rows == 4, "a damaged rule set: the mode set right, four sound rows kept (" .. tostring(c and #c.rows) .. ")")
	check(#c.rows[1].v == 2 and c.rows[1].v[1] == CLOTH and c.rows[1].v[2] == "7:*", "Type: its two real values, once each")
	check(#c.rows[2].v == 2 and c.rows[2].v[1] == 1 and c.rows[2].v[2] == 3 and c.rows[2].n == true, "Quality: whole numbers 0 to 7 only; \"is not\" kept")
	check(#c.rows[3].v == 1 and c.rows[3].n == nil, "Binding: known words only; \"is not\" only when it's exactly true")
	check(#c.rows[4].v == 1 and c.rows[4].v[1] == "INVTYPE_HAND", "Slot: the game's slot names only")
	local many = { rows = {} }
	for i = 1, 20 do many.rows[i] = { k = "quality", v = { i % 8 } } end
	local wide = { rows = { { k = "type", v = {} } } }
	for i = 1, 60 do wide.rows[1].v[i] = "7:" .. i end
	check(#R.Clean(many).rows == R.MAX_ROWS and #R.Clean(wide).rows[1].v == R.MAX_VALUES, "at most " .. R.MAX_ROWS .. " rows and " .. R.MAX_VALUES .. " values a row")
	check(R.Clean({ mode = "any", rows = { { k = "quality", v = { 2 } } } }).mode == "any", "\"any\" kept")
	-- a rule this version doesn't know (a newer version's, another addon's): kept, and it fits nothing
	local unknown = R.Clean({ rows = { { k = "type", v = { CLOTH } }, { k = "itemtree_prof", v = { "Tailoring", 3 } } } })
	check(unknown and #unknown.rows == 2 and unknown.rows[2].k == "itemtree_prof" and #unknown.rows[2].v == 2, "a rule this version doesn't know is kept as it is")
	local cloth = select(2, cat(n, 2589))
	check(R:Fits(typeRule(CLOTH), cloth) and not R:Fits(unknown, cloth), "and makes its section take nothing (never more than its author meant)")
	check(R:Fits({ mode = "any", rows = unknown.rows }, cloth), "(with \"any\", the rows it does know still count)")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- what fits
	local n, M, S, R = boot()
	local linen, leather, gloves, belt, potion = select(2, cat(n, 2589)), select(2, cat(n, 2318)), select(2, cat(n, 4040)), select(2, cat(n, 4329)), select(2, cat(n, 118))
	check(R:Fits(typeRule(CLOTH), linen) and not R:Fits(typeRule(CLOTH), leather), "Type is Cloth: the cloth, not the leather")
	check(R:Fits(typeRule(CLOTH, LEATHER), leather), "two values in a row: either one counts")
	check(R:Fits(typeRule("7:*"), linen) and R:Fits(typeRule("7:*"), leather) and not R:Fits(typeRule("7:*"), potion), "a whole kind (every Trade Goods type)")
	check(not R:Fits(typeRule("4:5"), linen), "Trade Goods cloth is not Armor's subtype 5")
	local function row(k, v, no) return { mode = "all", rows = { { k = k, v = v, n = no } } } end
	check(R:Fits(row("quality", { 2 }), gloves) and not R:Fits(row("quality", { 2 }), linen), "Quality")
	check(R:Fits(row("bind", { "boe" }), gloves) and R:Fits(row("bind", { "bop" }), belt) and R:Fits(row("bind", { "none" }), linen), "Binding: binds when equipped, soulbound (a worn BoE), none")
	check(R:Fits(row("slot", { "INVTYPE_HAND" }), gloves) and not R:Fits(row("slot", { "INVTYPE_HAND" }), belt) and not R:Fits(row("slot", { "INVTYPE_HAND" }), linen), "Slot")
	check(R:Fits(row("bind", { "bop" }, true), gloves) and not R:Fits(row("bind", { "bop" }, true), belt), "\"is not\"")
	check(R:Fits(row("slot", { "INVTYPE_HAND" }, true), linen), "an item that goes in no slot \"is not\" a hand slot item")
	local both = { mode = "all", rows = { { k = "type", v = { "4:*" } }, { k = "bind", v = { "boe" } } } }
	check(R:Fits(both, gloves) and not R:Fits(both, belt) and not R:Fits(both, linen), "all of these: every row")
	local either = { mode = "any", rows = both.rows }
	check(R:Fits(either, gloves) and R:Fits(either, belt) and not R:Fits(either, linen), "any one of these: one row is enough")
	check(not R:Fits({ mode = "all", rows = {} }, linen) and not R:Fits({ mode = "any", rows = { { k = "type", v = {} } } }, linen), "no rows, or rows with nothing picked: fits nothing")
	-- a detail the game hasn't supplied yet never fits, with or without "is not"
	local blank = { itemID = 1, quality = 1 }
	check(not R:Fits(typeRule(CLOTH), blank) and not R:Fits(row("type", { CLOTH }, true), blank) and not R:Fits(row("bind", { "bop" }, true), blank), "a detail not known yet never fits, even with \"is not\"")
	-- words
	check(R:RowText({ k = "bind", v = { "bop" }, n = true }) == "Binding is not Soulbound", "in words: Binding is not Soulbound")
	check(R:RowText({ k = "quality", v = { 1, 2, 3 } }) == "Quality is Common, Uncommon or Rare", "Quality is Common, Uncommon or Rare")
	check(R:Summary(typeRule(CLOTH)) == "Type is Trade Goods: Cloth", "a type named from an item in your bags: " .. R:Summary(typeRule(CLOTH)))
	check(R:Summary(both):find("^Fits all: Type is Armor; Binding is Binds when equipped$"), "more than one row: \"Fits all: ...\" (" .. R:Summary(both) .. ")")
	check(R:Summary(either):find("^Fits any: "), "or \"Fits any: ...\"")
	-- the game's own lists are asked first
	_G.C_Item = _G.C_Item or {}
	local oldC, oldS = C_Item.GetItemClassInfo, C_Item.GetItemSubClassInfo
	C_Item.GetItemClassInfo = function(c) return c == 15 and "Miscellaneous" or nil end
	C_Item.GetItemSubClassInfo = function(c, s) return (c == 15 and s == 2) and "Pet" or nil end
	check(R:TypeLabel("15:2") == "Miscellaneous: Pet" and R:TypeLabel("15:*") == "Miscellaneous", "a type with no item in your bags: named by the game's own list")
	check(R:TypeLabel("99:3") == "Type 99:3", "one nothing can name yet: a plain stand-in")
	C_Item.GetItemClassInfo, C_Item.GetItemSubClassInfo = oldC, oldS
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- one section for every item: junk, your own moves, then your sections from the top
	local n, M, S, R = boot()
	local cloth = S:CreateWithRules("Cloth", typeRule(CLOTH))
	check(cloth and cat(n, 2589) == cloth and cat(n, 2592) == cloth and cat(n, 4306) == cloth, "a Cloth section with a rule: the three cloths are in it")
	check(cat(n, 2318) == "TradeGoods" and cat(n, 118) == "Consumables", "the rest stay where they were")
	check(n.db.sectionMoves[2589] == nil, "(nothing was moved by hand)")
	-- priority: the higher section first
	local mats = S:CreateWithRules("All Materials", typeRule("7:*"))
	check(S:Priority(cloth) == 1 and S:Priority(mats) == 2, "a new section goes last")
	check(cat(n, 2589) == cloth and cat(n, 2318) == mats and cat(n, 2447) == mats and cat(n, 10940) == mats, "cloth fits both: the higher one (Cloth) gets it; the rest go to All Materials")
	check(cat(n, 4865) == "Junk", "a grey item stays in Junk whatever fits (Ruined Pelt is leather)")
	check(S:Reorder(mats, -1) and S:Priority(mats) == 1, "All Materials moved up")
	check(cat(n, 2589) == mats and cat(n, 4306) == mats, "now it gets the cloth first")
	check(not S:Reorder(mats, -1) and not S:Reorder(cloth, 1), "(the ends don't move further)")
	S:Reorder(mats, 1)
	check(cat(n, 2589) == cloth, "moved back down: Cloth gets its cloth again")
	-- your own moves come first
	S:Move(2592, "Other")
	check(cat(n, 2592) == "Other", "an item you move by hand goes where you put it, rule or not")
	S:Clear(2592)
	check(cat(n, 2592) == cloth, "its move undone: back under the rule")
	-- moving one back to its usual section sticks (the rule would take it straight back otherwise)
	S:Move(4306, "TradeGoods")
	check(cat(n, 4306) == "TradeGoods" and n.db.sectionMoves[4306] == "TradeGoods", "Silk Cloth moved back to Trade Goods by hand: it stays there")
	S:Clear(4306)
	check(cat(n, 4306) == cloth and n.db.sectionMoves[4306] == nil, "that move undone: the rule has it again")
	-- with no rule in the way, moving an item back just forgets the move, as before
	S:Move(118, "Other"); S:Move(118, "Consumables")
	check(n.db.sectionMoves[118] == nil and cat(n, 118) == "Consumables", "no rule involved: a move back is forgotten, as before")
	-- junk marks still win
	local _, linen = cat(n, 2589)
	n.Junk:Toggle(linen); M.runTimers()
	check(cat(n, 2589) == "Junk", "marked as junk: Junk")
	n.Junk:Toggle(select(2, cat(n, 2589))); M.runTimers()
	check(cat(n, 2589) == cloth, "unmarked: back in Cloth")
	-- the count, and taking rules or the section away
	check(S:SectionCount(cloth) == 3 and S:SectionCount(mats) == 3, "each section counts its items once (3 and 3)")
	S:SetRules(mats, nil)
	check(S:Rules(mats) == nil and cat(n, 2318) == "TradeGoods", "rules removed: its items go back")
	S:Delete(cloth)
	check(cat(n, 2589) == "TradeGoods", "the section deleted: its items go back")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- saved and loaded back, and passed on as a profile code
	local n, M, S, R = boot()
	local cloth = S:CreateWithRules("Cloth", typeRule(CLOTH))
	local gear = S:CreateWithRules("Gear to Sell", { mode = "all", rows = { { k = "type", v = { "4:*" } }, { k = "bind", v = { "bop" }, n = true } } })
	local saved = BagSmithDB
	local prof = saved.profiles.Default
	prof.customSections[1].rules.rows[2] = "nonsense"
	prof.customSections[1].rules.surprise = { 1, 2, 3 }
	prof.customSections[#prof.customSections + 1] = { id = "c77", name = "Broken", rules = "not a table" }
	local code = n.Share:Export()
	check(type(code) == "string", "a profile code is made with rules in it")
	n, M, S, R = boot(saved)
	local list = n.db.customSections
	check(#list == 3 and list[1].name == "Cloth" and list[2].name == "Gear to Sell", "after a reload: the sections, in their order")
	check(list[1].rules and #list[1].rules.rows == 1 and list[1].rules.rows[1].v[1] == CLOTH and list[1].rules.surprise == nil, "Cloth's rule kept; the damage to it dropped")
	check(list[2].rules and #list[2].rules.rows == 2 and list[2].rules.rows[2].n == true, "Gear to Sell's two rows kept, \"is not\" included")
	check(list[3].name == "Broken" and list[3].rules == nil, "a section whose rules were unreadable: kept, with none")
	check(cat(n, 2589) == list[1].id and cat(n, 4040) == list[2].id and cat(n, 4329) == "Gear", "and they sort the bags as before the reload (the soulbound belt isn't for sale)")
	local name = n.Share:Import(code, "Copied")
	local copy = BagSmithDB.profiles[name or "Copied"]
	check(copy and copy.customSections[1].rules and copy.customSections[1].rules.rows[1].v[1] == CLOTH and copy.customSections[2].rules.rows[2].n == true, "the code imports with its rules")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- New Section From This Item
	local n, M, S, R = boot()
	local _, silk = cat(n, 4306)
	local _, gloves = cat(n, 4040)
	-- the item menu offers it, and says where a rule put an item
	local menu
	n.ShowMenu = function(items) menu = items end
	S:ItemMenu(silk)
	local offer
	for _, it in ipairs(menu) do if it.text == "   New Section From This Item..." then offer = it end end
	check(offer ~= nil, "the item menu (Alt+Left-click): New Section From This Item...")
	n.Marks:ToggleFavorite(select(2, cat(n, 2592))); M.runTimers()   -- Wool Cloth starred
	offer.onClick(); M.runTimers()
	local f = S.fromFrame
	check(f and f:IsShown() and f.item.text == "Silk Cloth", "it opens for that item")
	check(#f.facts == 3 and f.facts[1].k == "type" and f.facts[1].text == "Trade Goods: Cloth" and f.facts[2].text == "Common" and f.facts[3].text == "No binding", "its details: Type, Quality, Binding (no slot: it isn't worn)")
	check(f.edit:GetText() == "Cloth", "the name starts as the kind of item: Cloth")
	check(f.checks[1]:GetChecked() and not f.checks[2]:GetChecked() and f.checks[1].label.text == "Type: Trade Goods: Cloth", "Type is ticked to start with, the rest aren't")
	check(#f.preview.here == 2 and f.head.text == "Would go in this section: 2 items", "the list: Linen and Silk (" .. tostring(f.head.text) .. ")")
	check(#f.preview.elsewhere == 1 and f.preview.elsewhere[1].why == "You starred it, so it stays in Favorites" and f.also:IsShown() and f.also.text:find("Wool Cloth (You starred it, so it stays in Favorites)", 1, true),
		"and the one that fits but stays put, with why (the starred Wool Cloth)")
	-- ticking changes the list at once
	f.checks[1]:SetChecked(false); f.checks[1]:GetScript("OnClick")(f.checks[1])
	check(#f.preview.here == 0 and f.sub.text == "Tick at least one to see what goes in.", "nothing ticked: nothing listed, and it says to tick one")
	f.create:GetScript("OnClick")(f.create)
	check(f:IsShown() and f.err.text == "Tick at least one thing for the items to have in common." and #n.db.customSections == 0, "Create with nothing ticked: it says why, and makes nothing")
	f.checks[1]:SetChecked(true); f.checks[1]:GetScript("OnClick")(f.checks[1])
	f.checks[2]:SetChecked(true); f.checks[2]:GetScript("OnClick")(f.checks[2])
	check(f.err.text == "" and #f.preview.here == 2, "Type and Quality ticked: the same two")
	f.edit:SetText("   ")
	f.create:GetScript("OnClick")(f.create)
	check(f:IsShown() and f.err.text == "Enter a name first.", "no name: it asks for one")
	f.edit:SetText("Cloth")
	f.create:GetScript("OnClick")(f.create); M.runTimers()
	local made = n.db.customSections[1]
	check(not f:IsShown() and made and made.name == "Cloth" and made.rules.mode == "all" and #made.rules.rows == 2 and made.rules.rows[1].k == "type" and made.rules.rows[1].v[1] == CLOTH and made.rules.rows[2].k == "quality" and made.rules.rows[2].v[1] == 1,
		"Create Section: the section, with the two ticked details as its rules")
	check(cat(n, 4306) == made.id and cat(n, 2589) == made.id and cat(n, 2318) == "TradeGoods", "and the cloth is in it")
	-- the menu marks the section a rule put the item in
	S:ItemMenu(select(2, cat(n, 4306)))
	local marked
	for _, it in ipairs(menu) do if it.checked then marked = it.text end end
	check(marked == "   Cloth", "the item menu ticks the section its rules put it in (" .. tostring(marked) .. ")")
	-- a name already used
	S:PromptFromItem(select(2, cat(n, 2318))); M.runTimers()
	check(f:IsShown() and f.edit:GetText() == "Leather" and #f.preview.here == 1, "for Light Leather: named Leather, one item")
	f.edit:SetText("cloth"); f.create:GetScript("OnClick")(f.create)
	check(f:IsShown() and f.err.text == "There's already a section with that name.", "a name already used: it says so")
	f.cancel:GetScript("OnClick")(f.cancel)
	check(not f:IsShown() and #n.db.customSections == 1, "Cancel: nothing made")
	-- gear has a slot to tick
	S:PromptFromItem(gloves); M.runTimers()
	check(#f.facts == 4 and f.facts[2].k == "slot" and f.facts[2].text == "Hands" and f.facts[4].text == "Binds when equipped", "a piece of gear: Type, Slot, Quality and Binding")
	f.cancel:GetScript("OnClick")(f.cancel)
	check((n.errors or 0) == 0, "no errors")
end)()

for _, skin in ipairs({ "modern", "classic" }) do
	-- Settings > Custom Sections: each section's rules in words, and arrows for their order
	local S0 = skin .. ": "
	local n, M, S, R = boot()
	n:Set("skin", skin); M.runTimers()
	local cloth = S:CreateWithRules("Cloth", typeRule(CLOTH))
	local byHand = S:Create("Keepsakes")
	local mats = S:CreateWithRules("All Materials", typeRule("7:*"))
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("custom"); M.runTimers()
	local rows = {}
	for _, w in ipairs(P.pools.csec or {}) do if w:IsShown() then rows[#rows + 1] = w end end
	table.sort(rows, function(a, b) return (S:Priority(a.id) or 0) < (S:Priority(b.id) or 0) end)
	check(#rows == 3 and rows[1].id == cloth and rows[2].id == byHand and rows[3].id == mats, S0 .. "the three sections, in their order")
	check(rows[1].text.text:find("^Cloth") and rows[1].text.text:find("(3 items)", 1, true), S0 .. "Cloth counts the three cloths its rule brings in (" .. rows[1].text.text .. ")")
	check(rows[1].sub:IsShown() and rows[1].sub.text == "Type is Trade Goods: Cloth", S0 .. "its rule in words under its name")
	check(not rows[2].sub:IsShown() and rows[2].text.text:find("(0 items)", 1, true), S0 .. "a section with no rules: no line, as before")
	check(rows[1].up.alpha == 0.3 and rows[1].down.alpha == 1 and rows[3].up.alpha == 1 and rows[3].down.alpha == 0.3, S0 .. "the arrows: the first can't go up, the last can't go down")
	local found = false
	for _, t in ipairs(P.pools.text or {}) do if t:IsShown() and tostring(t.text and t.text.text or t.text):find("the higher one gets it", 1, true) then found = true end end
	check(found, S0 .. "the page says the higher section gets an item first")
	rows[3].up:GetScript("OnClick")(rows[3].up); M.runTimers()
	check(S:Priority(mats) == 2 and S:Priority(byHand) == 3, S0 .. "All Materials moved up one")
	P:Hide()
	check((n.errors or 0) == 0, S0 .. "no errors")
end
