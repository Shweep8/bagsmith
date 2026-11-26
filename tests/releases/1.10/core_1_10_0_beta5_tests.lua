-- ======== 1.10.0-beta5 (Shweep, 22 Nov: "build next beta") ========
-- Tabs by kind, and sections on sheets (both settled 20 Nov: "yes as suggested"; "sections on sheets in 1.10").
-- (1) A built-in tab (Gear, Consumables, Trade Goods, Quest, Junk) shows every item of its kind, grouped under your
-- own sections where you have them; before, an item in one of your sections left its tab. (2) A section shows on every
-- sheet or only on some. Where it isn't shown it isn't there at all: its items go where they otherwise would, whether a
-- rule or your own hand put them in it. A record's saved section (rec.cat) is its section everywhere; S:CatOn(rec,
-- sheet) is its section on one tab.

local CLOTH, LEATHER = "7:5", "7:6"
local function boot(opts)
	opts = opts or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 16
	local function tg(bag, slot, id, name, sub, subName, extra)
		local it = { id = id, name = name, q = 1, count = 5, class = 7, subclass = sub, type = "Trade Goods", sub = subName, price = 10, ilvl = 10 }
		for k, v in pairs(extra or {}) do it[k] = v end
		M.put(bag, slot, it)
	end
	tg(0, 1, 2589, "Linen Cloth", 5, "Cloth")
	tg(0, 2, 2592, "Wool Cloth", 5, "Cloth")
	tg(0, 3, 4306, "Silk Cloth", 5, "Cloth")
	tg(0, 4, 2318, "Light Leather", 6, "Leather")
	tg(0, 5, 2447, "Peacebloom", 9, "Herb")
	tg(0, 7, 4865, "Ruined Pelt", 6, "Leather", { q = 0 })
	M.put(0, 8, { id = 4040, name = "Glimmering Mail Gauntlets", q = 2, count = 1, class = 4, subclass = 3, type = "Armor", sub = "Mail", equip = "INVTYPE_HAND", bind = 2, price = 300, ilvl = 30 })
	M.put(0, 9, { id = 4329, name = "Seer's Belt", q = 2, count = 1, class = 4, subclass = 1, type = "Armor", sub = "Cloth", equip = "INVTYPE_WAIST", bind = 2, bound = true, price = 200, ilvl = 25 })
	M.put(0, 10, { id = 118, name = "Minor Healing Potion", q = 1, count = 3, class = 0, subclass = 1, type = "Consumable", sub = "Potions", price = 5, ilvl = 5 })
	-- in the bank
	tg(-1, 1, 4338, "Mageweave Cloth", 5, "Cloth")
	_G.INVTYPE_HAND, _G.INVTYPE_WAIST = "Hands", "Waist"
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local prof = { view = "list", grp = "type", favSection = true, recentSection = false, showEmptySections = true }
	for k, v in pairs(opts.prof or {}) do prof[k] = v end
	_G.BagSmithDB = opts.saved or { version = 2, chars = {}, cache = {}, profiles = { Default = prof } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta5"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	M.fire("BANKFRAME_OPENED"); M.runTimers(); M.runTimers(); M.fire("BANKFRAME_CLOSED"); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	return n, M, n.Window.main, n.Sections, n.Rules
end
local function recOf(n, id) for _, list in ipairs({ n.items, n.bankItems or {} }) do for _, r in ipairs(list) do if r.itemID == id then return r end end end end
local function click(b) b:GetScript("OnClick")(b) end
-- what a tab shows, A to Z; and the sections it draws, as names
local function tab(main, M, sheet)
	main:SetSheet(sheet); M.runTimers(); M.runTimers()
	local t = {}
	for i, r in ipairs((main:Filtered())) do t[i] = r.name end
	table.sort(t)
	return table.concat(t, ", ")
end
local function lanes(n, main)
	local t = {}
	for i, id in ipairs(main.laneIds or {}) do t[i] = n.Sections:Label(id) end
	table.sort(t)
	return table.concat(t, ", ")
end
local function inLane(n, main, id)
	local out = {}
	for _, r in ipairs((main:Filtered())) do if n.Sections:CatOn(r, main.st.sheet) == id then out[#out + 1] = r.name end end
	table.sort(out)
	return table.concat(out, ", ")
end
local function typeRule(...) return { mode = "all", rows = { { k = "type", v = { ... } } } } end

;(function()
	-- tabs by kind
	local n, M, main, S, R = boot()
	check(tab(main, M, "TradeGoods") == "Light Leather, Linen Cloth, Peacebloom, Silk Cloth, Wool Cloth", "(the Trade Goods tab, before any section of your own)")
	check(tab(main, M, "Gear") == "Glimmering Mail Gauntlets, Seer's Belt" and tab(main, M, "Consumables") == "Minor Healing Potion" and tab(main, M, "Junk") == "Ruined Pelt", "(Gear, Consumables and Junk)")
	-- an item you put in one of your sections stays on its kind's tab
	local kit = S:Create("Tailoring Kit")
	S:Move(2589, kit); M.runTimers()
	check(recOf(n, 2589).cat == kit and S:KindOf(recOf(n, 2589)) == "TradeGoods", "Linen Cloth in your own section is still a trade good by kind")
	check(tab(main, M, "TradeGoods") == "Light Leather, Linen Cloth, Peacebloom, Silk Cloth, Wool Cloth", "the Trade Goods tab still shows it (it used to leave the tab)")
	check(lanes(n, main) == "Tailoring Kit, Trade Goods" and inLane(n, main, kit) == "Linen Cloth", "grouped there under your section, beside Trade Goods (" .. lanes(n, main) .. ")")
	check(tab(main, M, "Gear") == "Glimmering Mail Gauntlets, Seer's Belt", "and it's on no other kind's tab")
	-- a section that fills itself: the same
	local greens = S:CreateWithRules("Greens", { mode = "all", rows = { { k = "quality", v = { 2 } } } }); M.runTimers()
	check(recOf(n, 4040).cat == greens and tab(main, M, "Gear") == "Glimmering Mail Gauntlets, Seer's Belt" and lanes(n, main) == "Greens", "gear your rule section took stays on the Gear tab, under that section")
	check(tab(main, M, "TradeGoods"):find("Glimmering") == nil, "and doesn't show on Trade Goods")
	-- an item moved to one of BagSmith's own sections goes by that section, as before
	S:Move(118, "TradeGoods"); M.runTimers()
	check(S:KindOf(recOf(n, 118)) == "TradeGoods" and tab(main, M, "TradeGoods"):find("Minor Healing Potion", 1, true) and tab(main, M, "Consumables") == "", "a potion you moved to Trade Goods is on the Trade Goods tab, not Consumables (as before)")
	S:Clear(118); M.runTimers()
	-- junk is Junk, whatever section it would be in
	n.Junk:Toggle(recOf(n, 2589)); M.runTimers()
	check(recOf(n, 2589).cat == "Junk" and tab(main, M, "Junk") == "Linen Cloth, Ruined Pelt" and not tab(main, M, "TradeGoods"):find("Linen Cloth", 1, true), "an item marked as junk is on the Junk tab only")
	n.Junk:Toggle(recOf(n, 2589)); M.runTimers()
	-- All and your own sheets are as they were
	check(#(main:Filtered()) >= 0 and select(2, tab(main, M, "All"):gsub(",", ",")) == 8, "the All tab: everything (" .. tab(main, M, "All") .. ")")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- a section on some sheets only
	local n, M, main, S, R = boot()
	local cloth = S:CreateWithRules("Cloth", typeRule(CLOTH)); M.runTimers()
	check(recOf(n, 2589).cat == cloth and S:Sheets(cloth) == nil and not S:AnyScoped(), "(a section on every sheet: the cloth is in it everywhere)")
	check(S:SetSheets(cloth, { "TradeGoods", "TradeGoods", "", 7, "x" }) and #S:Sheets(cloth) == 2 and S:Sheets(cloth)[1] == "TradeGoods", "(set to some sheets: sound names, once each)")
	S:SetSheets(cloth, { "TradeGoods" }); M.runTimers()
	local linen = recOf(n, 2589)
	check(S:AnyScoped() and linen.cat == "TradeGoods", "set to show only on Trade Goods: everywhere else the cloth is back in Trade Goods (its saved section)")
	check(S:CatOn(linen, "TradeGoods") == cloth and S:CatOn(linen, "All") == "TradeGoods" and S:CatOn(linen, nil) == "TradeGoods" and S:CatOn(linen, "Gear") == "TradeGoods", "on the Trade Goods tab it's in Cloth; on All, or with no tab asked, in Trade Goods")
	check(tab(main, M, "All") ~= "" and lanes(n, main):find("Cloth", 1, true) == nil and lanes(n, main):find("Trade Goods", 1, true), "the All tab: Trade Goods stays whole, with no Cloth section (" .. lanes(n, main) .. ")")
	check(tab(main, M, "TradeGoods") == "Light Leather, Linen Cloth, Peacebloom, Silk Cloth, Wool Cloth" and lanes(n, main) == "Cloth, Trade Goods" and inLane(n, main, cloth) == "Linen Cloth, Silk Cloth, Wool Cloth",
		"the Trade Goods tab: split into Cloth and what's left (" .. lanes(n, main) .. ")")
	check(S:SectionCount(cloth) == 4, "its count is what it holds on its tab: the three cloths and the one in the bank (" .. S:SectionCount(cloth) .. ")")
	-- the next section that is shown here gets the item where the first isn't
	local common = S:CreateWithRules("Common Things", { mode = "all", rows = { { k = "quality", v = { 1 } } } }); M.runTimers()
	check(linen.cat == common and S:CatOn(linen, "TradeGoods") == cloth and S:CatOn(linen, "All") == common, "a second section, on every sheet, that fits too: it has the cloth everywhere but on Trade Goods, where Cloth comes first")
	S:Reorder(common, -1); M.runTimers()
	check(S:Priority(common) == 1 and S:CatOn(linen, "TradeGoods") == common, "moved above Cloth: it gets the cloth on Trade Goods too")
	S:Reorder(common, 1); M.runTimers()
	S:Delete(common); M.runTimers()
	-- your own hand
	S:Move(2318, cloth); M.runTimers()
	local leather = recOf(n, 2318)
	check(leather.cat == "TradeGoods" and S:CatOn(leather, "TradeGoods") == cloth and S:CatOn(leather, "All") == "TradeGoods", "Light Leather put in Cloth by hand: in Cloth on its tab, in its usual section elsewhere")
	check(S:SectionCount(cloth) == 5, "(and it counts)")
	S:Clear(2318); M.runTimers()
	S:Move(2589, "TradeGoods"); M.runTimers()
	check(n.db.sectionMoves[2589] == "TradeGoods" and S:CatOn(linen, "TradeGoods") == "TradeGoods", "Linen moved back to Trade Goods by hand, on the tab where Cloth takes it: the move is kept, and it stays")
	S:Clear(2589); M.runTimers()
	check(S:CatOn(linen, "TradeGoods") == cloth, "(cleared: Cloth has it again)")
	-- a filter by section means the section on that tab
	local f = n.CleanFilters({ rules = { mode = "all", rows = { { k = "sec", v = { cloth } } } } })
	check(n:FilterPredicate(f, "TradeGoods")(linen) and not n:FilterPredicate(f, "All")(linen) and not n:FilterPredicate(f)(linen), "Section is Cloth, as a filter: fits on Trade Goods, not on All")
	local old = n.CleanFilters({ cat = { [cloth] = true } })
	check(n:FilterPredicate(old, "TradeGoods")(linen) and not n:FilterPredicate(old, "All")(linen), "(the older form of that filter too)")
	-- (its section everywhere counts too, so a sheet filtered by Trade Goods keeps the cloth when Cloth splits it)
	local tgf = n.CleanFilters({ cat = { TradeGoods = true } })
	local tgr = n.CleanFilters({ rules = { mode = "all", rows = { { k = "sec", v = { "TradeGoods" } } } } })
	check(n:FilterPredicate(tgf, "All")(linen) and n:FilterPredicate(tgf, "TradeGoods")(linen) and n:FilterPredicate(tgr, "TradeGoods")(linen), "Section is Trade Goods still finds the cloth on the tab where Cloth splits it out")
	-- hidden at vendors follows the tab too
	S:SetShown(cloth, "vendor", false)
	M.fire("MERCHANT_SHOW"); M.runTimers(); M.runTimers()
	check(S:WouldHide(linen, "TradeGoods") and not S:WouldHide(linen, "All") and S:EffectiveSection(linen, "TradeGoods") == cloth and S:EffectiveSection(linen, "All") == "TradeGoods", "Cloth hidden at vendors: the cloth is hidden on the Trade Goods tab, where it's in Cloth, and not on All")
	check(tab(main, M, "TradeGoods") == "Light Leather, Peacebloom" and tab(main, M, "All"):find("Linen Cloth", 1, true), "and the tabs show it so")
	M.fire("MERCHANT_CLOSED"); M.runTimers()
	-- (by design since 1.11.0-beta3, Shweep's "1": Always Close closes the bags at every place, whether they opened for it or were open already): opened again after the vendor
	n.Window:Show(); M.runTimers()
	S:SetShown(cloth, "vendor", true)
	-- an empty section shows only where it's set to
	local ore = S:Create("Ore")
	S:SetSheets(ore, { "TradeGoods" }); M.runTimers()
	tab(main, M, "TradeGoods")
	check(lanes(n, main) == "Cloth, Ore, Trade Goods", "an empty section set to show on Trade Goods has its empty heading there (" .. lanes(n, main) .. ")")
	tab(main, M, "All")
	check(lanes(n, main):find("Ore", 1, true) == nil, "and not on All")
	tab(main, M, "Gear")
	check(lanes(n, main) == "Gear", "nor on another kind's tab")
	S:Delete(ore); M.runTimers()
	-- the Bank tab, and a sheet of your own
	S:SetSheets(cloth, { "Bank" }); M.runTimers()
	local mage = recOf(n, 4338)
	check(S:CatOn(mage, "Bank") == cloth and S:CatOn(linen, "TradeGoods") == "TradeGoods" and S:SectionCount(cloth) == 1, "set to the Bank tab instead: the bank's cloth is in it there, and it counts that one")
	n:SaveSheet("Mats", main)
	n.db.sheets[1].f = n.CleanFilters({ cat = { TradeGoods = true } })
	S:SetSheets(cloth, { "Mats" }); M.runTimers()
	check(tab(main, M, "Mats") == "Light Leather, Linen Cloth, Peacebloom, Silk Cloth, Wool Cloth" and lanes(n, main) == "Cloth, Trade Goods" and S:SectionCount(cloth) == 3, "set to one of your sheets: split there (" .. lanes(n, main) .. ")")
	-- the sheet renamed, then deleted
	main:SetSheet("All"); M.runTimers()
	n:UpdateSheet("Mats", "Materials", main); M.runTimers()
	check(S:Sheets(cloth)[1] == "Materials" and #S:Sheets(cloth) == 1, "the sheet renamed: the section follows it")
	M.log = {}
	n:DeleteSheet("Materials", main); M.runTimers()
	local said
	for _, line in ipairs(M.log) do if line:find("The section \"Cloth\" was only shown on the sheet Materials; it now shows on every sheet.", 1, true) then said = true end end
	check(S:Sheets(cloth) == nil and said and linen.cat == cloth, "the sheet deleted: the section shows on every sheet again, and chat says so")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- saved, loaded back, shared
	local n, M, main, S, R = boot()
	local cloth = S:CreateWithRules("Cloth", typeRule(CLOTH))
	n:SaveSheet("Mats", main); main:SetSheet("All")
	S:SetSheets(cloth, { "TradeGoods", "Mats" })
	local saved = BagSmithDB
	saved.profiles.Default.customSections[1].sheets[3] = "No Such Sheet"
	saved.profiles.Default.customSections[2] = { id = "c7", name = "Odd", sheets = "everywhere" }
	saved.profiles.Default.customSections[3] = { id = "c8", name = "Gone", sheets = { "Deleted Sheet" } }
	local code = n.Share:Export()
	n, M, main, S, R = boot({ saved = saved })
	local list = n.db.customSections
	check(#list == 3 and list[1].sheets and #list[1].sheets == 2 and list[1].sheets[1] == "TradeGoods" and list[1].sheets[2] == "Mats", "after a reload: the section's two sheets, and a name that is no tab of this profile dropped")
	check(list[2].sheets == nil and list[3].sheets == nil, "unreadable sheets are none; a section left with none shows on every sheet")
	check(S:CatOn(recOf(n, 2589), "TradeGoods") == list[1].id and recOf(n, 2589).cat == "TradeGoods", "and it sorts the same")
	local name = n.Share:Import(code, "Copied")
	local copied = BagSmithDB.profiles[name or "Copied"]
	check(copied and copied.customSections[1].sheets and copied.customSections[1].sheets[1] == "TradeGoods" and copied.customSections[1].sheets[2] == "Mats", "a profile code carries where a section shows")
	check((n.errors or 0) == 0, "no errors")
end)()

for _, skin in ipairs({ "modern", "classic" }) do
	-- the editor: Show this section on [every sheet] [only some sheets]
	local S0 = skin .. ": "
	local n, M, main, S, R = boot({ prof = { skin = skin } })
	local E = n.SectionEditor
	n:SaveSheet("Mats", main); main:SetSheet("All"); M.runTimers()
	local cloth = S:CreateWithRules("Cloth", typeRule(CLOTH)); M.runTimers()
	local f = S:EditSection(cloth); M.runTimers()
	check(f.scopeLabel:IsShown() and f.scopeLabel.text == "Show this section on" and f.scopeAll.label.text == "every sheet" and f.scopeSome.label.text == "only some sheets" and f.scopeAll.active and not f.scopeSome.active,
		S0 .. "Show this section on [every sheet] [only some sheets], every sheet to start with")
	check(not f.scopeNote:IsShown() and not (f.sheetChips[1] and f.sheetChips[1]:IsShown()) and f.shownSub.text == "Looking at your bags and bank" and #E.shown.here == 4, S0 .. "every sheet: no tabs to tick; the list counts your bags and bank (4 cloths)")
	local h0 = f.rulesHeight
	click(f.scopeSome); M.runTimers()
	local chips = {}
	for _, c in ipairs(f.sheetChips) do if c:IsShown() then chips[#chips + 1] = c.label.text .. (c.active and "*" or "") end end
	check(f.scopeSome.active and table.concat(chips, ", ") == "All, Gear, Consumables, Trade Goods, Quest, Junk, Bank, Mats", S0 .. "only some sheets: your tabs to tick, BagSmith's and yours (" .. table.concat(chips, ", ") .. ")")
	check(f.scopeNote:IsShown() and f.scopeNote.text == "Tick at least one, or this section shows on every sheet." and f.rulesHeight > h0 and #E.shown.here == 4, S0 .. "none ticked yet: it says so, and nothing changes")
	local function chipFor(label) for _, c in ipairs(f.sheetChips) do if c:IsShown() and c.label.text == label then return c end end end
	click(chipFor("Trade Goods")); M.runTimers()
	check(chipFor("Trade Goods").active and f.scopeNote.text == "On your other sheets, these items stay in their usual section." and f.shownSub.text == "Looking at your bags and bank, on Trade Goods", S0 .. "Trade Goods ticked: On your other sheets, these items stay in their usual section.")
	check(#E.shown.here == 4, S0 .. "the list: the cloth on that tab, the bank's too")
	click(chipFor("Bank")); M.runTimers()
	check(f.shownSub.text == "Looking at your bags and bank, on Trade Goods and Bank" and #E.shown.here == 4, S0 .. "Bank ticked too: named in the line above the list")
	click(chipFor("Trade Goods")); M.runTimers()
	check(#E.shown.here == 1 and E.shown.here[1].name == "Mageweave Cloth", S0 .. "only Bank: just the cloth in the bank")
	click(chipFor("Bank")); click(chipFor("Trade Goods")); M.runTimers()
	check(S:Sheets(cloth) == nil and recOf(n, 2589).cat == cloth, S0 .. "(nothing is changed until Save)")
	click(f.save); M.runTimers()
	check(not f:IsShown() and S:Sheets(cloth) and #S:Sheets(cloth) == 1 and S:Sheets(cloth)[1] == "TradeGoods" and recOf(n, 2589).cat == "TradeGoods" and S:CatOn(recOf(n, 2589), "TradeGoods") == cloth,
		S0 .. "Save Section: Cloth shows only on Trade Goods")
	-- Settings says where
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("custom"); M.runTimers()
	local row
	for _, w in ipairs(P.pools.csec or {}) do if w:IsShown() and w.id == cloth then row = w end end
	check(row and row.sub:IsShown() and row.sub.text == "Type is Trade Goods: Cloth (only on Trade Goods)" and row.text.text:find("(4 items)", 1, true), S0 .. "Settings > Custom Sections: its rule, and where it shows (" .. tostring(row and row.sub.text) .. ")")
	local hand = S:Create("Keepsakes"); S:SetSheets(hand, { "All", "Mats" }); M.runTimers()
	row = nil
	for _, w in ipairs(P.pools.csec or {}) do if w:IsShown() and w.id == hand then row = w end end
	check(row and row.sub:IsShown() and row.sub.text == "Only on All and Mats", S0 .. "a section with no rules says only where it shows")
	P:Hide()
	-- opened again: its tab is ticked; a rule that looks past the tab's kind lists only what's on the tab
	f = S:EditSection(cloth); M.runTimers()
	check(f.scopeSome.active and chipFor("Trade Goods").active and not chipFor("All").active, S0 .. "opened again: only some sheets, Trade Goods ticked")
	click(f.rows[1].remove); E:AddRow("quality"); click(f.rows[1].chips[2]); M.runTimers()
	local names = {}
	for i, r in ipairs(E.shown.here) do names[i] = r.name end
	check(table.concat(names, ", ") == "Light Leather, Linen Cloth, Mageweave Cloth, Peacebloom, Silk Cloth, Wool Cloth", S0 .. "Quality is Common, on Trade Goods: the common trade goods, not the potion (" .. table.concat(names, ", ") .. ")")
	-- back to every sheet
	click(f.scopeAll); M.runTimers()
	check(f.scopeAll.active and not f.scopeNote:IsShown() and #E.shown.here == 7, S0 .. "every sheet again: the potion too")
	click(f.cancel)
	f = S:EditSection(cloth); M.runTimers()
	click(f.scopeAll); click(f.save); M.runTimers()
	check(S:Sheets(cloth) == nil and recOf(n, 2589).cat == cloth, S0 .. "saved on every sheet: the cloth is in it everywhere again")
	-- only some sheets with none ticked is every sheet
	f = S:EditSection(cloth); M.runTimers()
	click(f.scopeSome); click(f.save); M.runTimers()
	check(S:Sheets(cloth) == nil, S0 .. "only some sheets with none ticked saves as every sheet")
	-- a new section, set to a tab before it exists
	f = S:EditSection(); M.runTimers()
	check(f.scopeAll.active and not f.scopeSome.active, S0 .. "a new section starts on every sheet")
	f.edit:SetText("Leather"); E:AddRow("type"); E:PickerClick(E.picker.list[1] and E.picker.list[1])
	E:ClosePicker()
	E.draft.rows[1] = { k = "type", v = { LEATHER } }; E:Changed()
	click(f.scopeSome); click(chipFor("Trade Goods")); M.runTimers()
	click(f.save); M.runTimers()
	local made = S:Customs()[#S:Customs()]
	check(made.name == "Leather" and made.sheets and made.sheets[1] == "TradeGoods" and S:CatOn(recOf(n, 2318), "TradeGoods") == made.id and recOf(n, 2318).cat == "TradeGoods", S0 .. "Create Section: made, and only on Trade Goods")
	check((n.errors or 0) == 0, S0 .. "no errors")
end

;(function()
	-- the item menu says where an item is on the tab it was opened from
	local n, M, main, S, R = boot()
	local menu
	n.ShowMenu = function(items) menu = items end
	local cloth = S:CreateWithRules("Cloth", typeRule(CLOTH))
	S:SetSheets(cloth, { "TradeGoods" }); M.runTimers()
	local linen = recOf(n, 2589)
	local function ticked() for _, it in ipairs(menu) do if it.checked then return it.text end end end
	local function has(text) for _, it in ipairs(menu) do if it.text == text then return true end end return false end
	main:SetSheet("All"); M.runTimers()
	S:ItemMenu(linen, { view = main })
	check(ticked() == "   Trade Goods (default)" and has("   Cloth (on Trade Goods)"), "from the All tab: the cloth is in Trade Goods, and Cloth says where it shows (" .. tostring(ticked()) .. ")")
	main:SetSheet("TradeGoods"); M.runTimers()
	S:ItemMenu(linen, { view = main })
	check(ticked() == "   Cloth" and has("   Cloth") and not has("   Cloth (on Trade Goods)"), "from the Trade Goods tab: it's in Cloth")
	-- an owner some frames down from its window still finds the tab
	local owner = { GetParent = function() return { GetParent = function() return { view = main } end } end }
	S:ItemMenu(linen, owner)
	check(ticked() == "   Cloth", "(a button inside the window finds its tab)")
	S:ItemMenu(linen, nil)
	check(ticked() == "   Trade Goods (default)", "(with no window to ask, the plain answer)")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- the changelog
	local f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	local section = ("\n" .. log):match("\n(## 1%.10%.0\n.-)\n## 1%.9%.8\n") or ""
	check(section:find("A section can show on every sheet, or only on some", 1, true) and section:find("show every item of their kind", 1, true), "the changelog's 1.10.0 section: sections on sheets, and tabs by kind")
	check(not section:find("\226\128\148") and not section:find("\226\128\147"), "with no dashes")
end)()
