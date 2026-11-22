;(function()
	-- ======== 1.9.0-beta4 (Shweep, 16 Nov): Global Inventory's own settings, its footer and currencies ========
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
	local function deep(t) if type(t) ~= "table" then return t end local o = {} for k, v in pairs(t) do o[k] = deep(v) end return o end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, profiles = { Default = { sort = "name", grp = "bag", fav = { "c:42" } } }, cache = {
		["Brannoc - Forever"] = { name = "Brannoc", realm = "Forever", class = "PRIEST", level = 20, gold = 500000,
			bags = { ["0"] = { size = 16, free = 4 }, ["1"] = { size = 10, free = 10, kind = "herb" } },
			items = { { bag = 0, slot = 1, itemID = 2589, count = 3, name = "Linen Cloth", quality = 1, sellPrice = 10, link = "|Hitem:2589|h[Linen Cloth]|h" } },
			bank = { { bag = 6, slot = 1, itemID = 2589, count = 2, name = "Linen Cloth", quality = 1, sellPrice = 10, link = "|Hitem:2589|h[Linen Cloth]|h" },
				{ bag = 6, slot = 2, itemID = 2592, count = 7, name = "Wool Cloth", quality = 1, sellPrice = 33, link = "|Hitem:2592|h[Wool Cloth]|h" } },
			currencies = { ["c:42"] = { id = 42, name = "Honor", icon = 1, count = 300 } } },
		["Elsewhere - Other Realm"] = { name = "Elsewhere", realm = "Other Realm", class = "PRIEST", level = 30, gold = 9000000,
			items = { { bag = 0, slot = 1, itemID = 4306, count = 9, name = "Silk Cloth", quality = 1 } },
			currencies = { ["c:42"] = { id = 42, name = "Honor", icon = 1, count = 50 } } },
	} }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V = n.Window.main
	V.btnGlobal:GetScript("OnClick")(V.btnGlobal); M.runTimers(); M.runTimers()
	local G = BagSmithDB.globalInv
	check(G and G.sort == "name" and G.grp == "type" and G.allRealms == false and #G.pins == 0, "its own settings, started from the profile's (sections by bag becomes by section), no pins")

	-- its settings are its own
	V:SetPref("sort", "quality"); V:SetPref("grp", "none")
	check(G.sort == "quality" and G.grp == "none" and n.db.sort == "name" and n.db.grp == "bag", "sort and sections change Global Inventory's, never the profile's")
	check(V:Pref("colWidths") == G.colWidths, "its own column widths")
	V:ToggleLane("Gear")
	check(n.IndexOf(G.collapsed, "Gear") and not n.IndexOf(n.db.collapsed or {}, "Gear"), "its own collapsed sections")
	V:SetPref("grp", "type")

	-- (by design since 1.9.0-beta5, Shweep: "only have the accordion view") All Rows is gone: Merge is greyed there
	V:SyncTools()
	check(V.btnMerge.label.text == "Merge Stacks" and not V.btnMerge:IsEnabled() and not V.btnMerge.active, "Merge Stacks greyed in Global Inventory")
	local shown = V:Filtered()
	local linen = 0
	for _, r in ipairs(shown) do if r.itemID == 2589 then linen = linen + 1 end end
	check(linen == 1, "Linen Cloth: one row (" .. linen .. ")")

	-- the Bank tab or icon: only what's in banks
	V.btnBank:GetScript("OnClick")(V.btnBank); M.runTimers()
	check(n.ui.global and V.st.sheet == "Bank", "Bank in Global Inventory: still Global Inventory")
	shown = V:Filtered()
	local by = {}
	for _, r in ipairs(shown) do by[r.itemID] = r end
	check(by[2589] and by[2589].count == 2 and by[2589].where == "Bank" and by[2592] and not by[4306], "only what's in banks, its count there (Linen Cloth: 2)")
	V.btnBank:GetScript("OnClick")(V.btnBank); M.runTimers()
	check(V.st.sheet == "All", "and back")

	-- Gear Sets: the tab hidden, the icon greyed out
	V:SetSheet("GearSets")
	check(V.st.sheet ~= "GearSets", "Gear Sets can't open in Global Inventory")

	-- the value column and what it's all worth
	local plan = V:ColumnPlan()
	local keys = {}
	for _, c in ipairs(plan) do keys[#keys + 1] = c.key end
	local at = n.IndexOf(keys, "n")
	check(keys[at + 3] == "v", "Who, Where, then a value (Vendor, with no price source): " .. table.concat(keys, ","))
	n:RefreshViews(true); M.runTimers()
	-- (by design since 1.9.0-beta8: a Total row under the columns, not a note by the title)
	check(V.totalRow and V.totalRow:IsShown() and tostring(V.totalRow.cells.v.text) ~= "-", "the Total row says what it's worth: " .. tostring(V.totalRow and V.totalRow.cells.v.text))

	-- the footer: gold, free slots, pins
	local _, realmGold = n.Inventory:Gold(false)
	check(realmGold == 123456 + 500000, "(the realm's gold)")
	check(V.moneyText.text == tostring(realmGold) .. "c", "the footer's gold: this ruleset's total (" .. tostring(V.moneyText.text) .. ")")
	local free, total = n.Inventory:FreeSlots(false)
	local mineF, mineT = n:FreeSlots()
	check(free == mineF + 4 and total == mineT + 16, "free slots: yours and Brannoc's, his herb bag excluded (Bag Slot Count)")
	check((V.freeText.text or ""):find(("%d / %d"):format(free, total), 1, true), "the footer shows them: " .. tostring(V.freeText.text))
	local tipFn = V:FreeTip()
	GameTooltip:SetOwner(V.btnBags); tipFn(GameTooltip, false)
	local tl = table.concat(GameTooltip.lines or {}, " | ")
	check(tl:find("Brannoc", 1, true) and tl:find("Total", 1, true), "hovering: each character's, then the total")

	-- currencies: Global Inventory's own pins (none at first), everyone's totals
	local favs = n.Currency:Favorites()
	check(#favs == 0, "no pins in Global Inventory at first (your character's Honor pin isn't one)")
	n.Drawer:Show(); M.runTimers()
	check(n.Drawer.frame.title.text == "Global Currencies", "the drawer says whose: Global Currencies")
	n.Currency:ToggleFavorite("c:42"); M.runTimers()
	favs = n.Currency:Favorites()
	check(#favs == 1 and favs[1].count == 300 and G.pins[1] == "c:42" and n.db.fav[1] == "c:42" and #n.db.fav == 1, "pinned for Global Inventory: Honor, everyone's 300; your character's pins untouched")
	n.Inventory:Settings().allRealms = true
	favs = n.Currency:Favorites()
	check(favs[1].count == 350, "with other rulesets: 350")
	n.Inventory:Settings().allRealms = false

	-- leaving: your character's again
	V.btnGlobal:GetScript("OnClick")(V.btnGlobal); M.runTimers(); M.runTimers()
	n.Drawer:Refresh()
	check(n.Drawer.frame.title.text == "Aldren's Currencies", "outside Global Inventory: your character's (" .. tostring(n.Drawer.frame.title.text) .. ")")
	check(V.moneyText.text == "123456c", "and your own gold in the footer")
	check(V:Pref("sort") == "name" and V:Pref("grp") == "bag", "your bags' own sort and sections")

	-- saved, and checked on load
	local saved = deep(BagSmithDB)
	saved.globalInv.colWidths.bad = "x"; saved.globalInv.pins[2] = 5; saved.globalInv.grp = "bag"
	package.loaded.mock = nil; M = require("mock")
	_G.BagSmithCharDB, _G.BagSmithDB = { version = 1, firstSeen = {} }, saved
	n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers()
	local g2 = BagSmithDB.globalInv
	check(g2.sort == "quality" and g2.pins[1] == "c:42" and #g2.pins == 1 and g2.colWidths.bad == nil and g2.grp == nil and n.IndexOf(g2.collapsed, "Gear"), "kept across a reload, bad entries dropped")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- The Travel Mode signpost in Global Inventory leaves it, into Travel Mode; Include Other Rulesets in the Filter panel
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, profiles = { Default = { travelMode = true } }, cache = {
		["Elsewhere - Other Realm"] = { name = "Elsewhere", realm = "Other Realm", class = "PRIEST", level = 30,
			items = { { bag = 0, slot = 1, itemID = 4306, count = 9, name = "Silk Cloth", quality = 1 } } } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V = n.Window.main
	check(V:TravelOn(), "(setup) Travel Mode on")
	V:SetGlobal(true); M.runTimers()
	check(n.ui.global and not V:TravelOn(), "Global Inventory holds Travel Mode off")
	-- Include Other Rulesets
	n.Popups:OpenFilters(V, "browse"); M.runTimers()
	local rc = n.Popups.filter.realmsCheck
	check(rc and rc:IsShown() and not rc:GetChecked(), "the Filter panel: Include Other Rulesets, off")
	-- (by design since 1.10.0-beta4: the Filters window's boxes are chips now, so one click turns it on, another off)
	rc:GetScript("OnClick")(rc); M.runTimers()
	local found = false
	for _, r in ipairs(V:Filtered()) do if r.itemID == 4306 then found = true end end
	check(n.Inventory:Settings().allRealms and found, "on: the other ruleset's character's items too")
	rc:GetScript("OnClick")(rc); M.runTimers()
	check(not rc:GetChecked() and not n.Inventory:Settings().allRealms, "and off again")
	n.Popups.filter:Hide()
	-- the signpost
	V.btnTravel:GetScript("OnClick")(V.btnTravel); M.runTimers(); M.runTimers()
	check(not n.ui.global and V:TravelOn() and n.db.travelMode, "the signpost: out of Global Inventory, into Travel Mode")
	n.Popups:OpenFilters(V, "browse"); M.runTimers()
	check(not n.Popups.filter.realmsCheck:IsShown(), "outside Global Inventory the filter isn't offered")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- Travel Mode (Shweep): too narrow for the search box in the title row, the search folds into an icon; clicked, it
	-- opens as its own full-width row under the title, the list below it; cleared and left, it folds back. The globe
	-- shows in Travel Mode again.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { travelMode = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V = n.Window.main
	check(V:TravelOn() and V.btnGlobal:IsShown() and select(2, V.titleDivider:GetPoint(1)) == V.btnGlobal, "the globe shows in Travel Mode, the divider at its left")
	V.title.w = 900; V:LayoutTitleRow()
	check(not V.searchFolded and V.search:IsShown() and not V.btnSearchFold:IsShown(), "wide: the search box in the title row, as before")
	V.title.w = 250; V:LayoutTitleRow()
	check(V.searchFolded and not V.search:IsShown() and V.btnSearchFold:IsShown(), "narrow: the search folds into its icon")
	V.btnSearchFold:GetScript("OnClick")(V.btnSearchFold); M.runTimers()
	local p = {}
	for i = 1, V.search:GetNumPoints() do local pt = { V.search:GetPoint(i) }; p[pt[1]] = pt end
	check(V.searchOpen and V.search:IsShown() and p.TOPLEFT and p.TOPLEFT[2] == V.title and p.TOPRIGHT and p.TOPRIGHT[2] == V.title and p.TOPRIGHT[3] == "BOTTOMRIGHT", "clicked: the search opens as its own row under the title, full width")
	check(select(2, V.header:GetPoint(1)) == V.search, "the list sits below it")
	V.search:SetText("linen")
	V.search:GetScript("OnEditFocusLost")(V.search)
	check(V.searchOpen, "a search in use stays open")
	V.search:SetText("")
	V.search:GetScript("OnEditFocusLost")(V.search); M.runTimers()
	check(not V.searchOpen and not V.search:IsShown() and V.btnSearchFold:IsShown(), "cleared and left: it folds back")
	check(select(2, V.header:GetPoint(1)) == V.title, "and the list moves back up")
	V.title.w = 900; V:LayoutTitleRow()
	check(not V.searchFolded and V.search:IsShown() and not V.btnSearchFold:IsShown(), "wide again: the box is back in the title row")
	n:Set("travelMode", false); M.runTimers(); M.runTimers()
	check(not V.btnSearchFold:IsShown() and V.search:IsShown(), "out of Travel Mode: the usual search row")
	check((n.errors or 0) == 0, "no errors")
end)()
