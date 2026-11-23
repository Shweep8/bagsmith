-- ======== 1.9.0-beta6 (Shweep, 16 Nov) ========
-- Global Inventory's own pages in Settings (Global Sections, Global Columns, Global Sheets: the bare minimum, each under
-- a heading with the globe saying they live outside profiles), its sections by BagSmith's defaults, its own columns
-- and tabs, Settings 5% taller; the title note's V and AH stacked as two text pieces; Compact View's rows fill the width.
local function boot(skin, extra)
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
	M.put(0, 2, { id = 118, name = "Minor Healing Potion", q = 1, count = 3, class = 0, subclass = 1, type = "Consumable", sub = "Potion", price = 5 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local prof = { skin = skin or "modern", splitCons = true, cols = { "c", "age", "jk", "v" },
		customSections = { { id = "c1", name = "Cloth Pile" } }, sectionMoves = { [2589] = "c1" }, pinnedSections = { Consumables = true },
		sheets = { { n = "Mats", f = { text = "cloth" } } } }
	for k, v in pairs(extra or {}) do prof[k] = v end
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = prof }, whatsNewSeen = "1.8.0" }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	return n, M, n.Window.main
end
local function lanes(V)
	local t = {}
	for _, h in ipairs(V.used or {}) do if h.laneId and h.text and h:IsShown() then t[#t + 1] = h.laneId end end
	return t
end

;(function()
	-- Global Inventory's sections: BagSmith's defaults, whatever the profile says; the profile untouched
	local n, M, V = boot()
	check(n.IndexOf(n.db.tabOrder, "Mats") or true, "(setup)")
	n:RefreshViews(true); M.runTimers()
	check(n.IndexOf(lanes(V), "c1") ~= nil, "(setup) your bags: the custom section shows, with the moved Linen Cloth")
	local order = n.db.laneOrder
	V.btnGlobal:GetScript("OnClick")(V.btnGlobal); M.runTimers(); M.runTimers()
	V:SetPref("grp", "type"); n:RefreshViews(true); M.runTimers()
	local L = lanes(V)
	check(not n.IndexOf(L, "c1"), "Global Inventory: no custom section: " .. table.concat(L, ","))
	local by = {}
	for _, r in ipairs(V:Filtered()) do by[r.itemID] = r end
	check(by[2589] and by[2589].cat == "TradeGoods", "Linen Cloth in its own section, not the one you moved it to: " .. tostring(by[2589] and by[2589].cat))
	check(by[118] and by[118].cat == "Consumables", "the potion in Consumables, not split: " .. tostring(by[118] and by[118].cat))
	check(not n.IndexOf(L, "~fav") and not n.IndexOf(L, "~recent"), "no Favorites or Recent")
	local pinned = false
	for _, h in ipairs(V.used or {}) do if h:IsShown() and h.laneId == "Consumables" and h.count and tostring(h.count.text):find("Pinned", 1, true) then pinned = true end end
	check(not pinned, "and no pinned sections")
	check(n.db.splitCons == true and n.db.laneOrder == order and n.db.customSections[1].id == "c1" and n.db.sectionMoves[2589] == "c1" and n.db.pinnedSections.Consumables,
		"your profile's section settings are untouched")
	-- an error inside still puts them back
	local ok = pcall(n.WithDefaultSections, n, function() error("boom") end)
	check(not ok and n.db.splitCons == true and n.db.laneOrder == order and not n.inDefaultSections, "an error inside: the profile's settings come back all the same")
	V.btnGlobal:GetScript("OnClick")(V.btnGlobal); M.runTimers(); M.runTimers()
	check(n.IndexOf(lanes(V), "c1") ~= nil, "back in your bags: the custom section again")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- Global Inventory's own columns and tabs
	local n, M, V = boot()
	V:SetSheet("Mats"); M.runTimers()
	check(V.st.sheet == "Mats" and V.st.filters.text == "cloth", "(setup) on your own sheet")
	V.btnGlobal:GetScript("OnClick")(V.btnGlobal); M.runTimers(); M.runTimers()
	check(V.st.sheet == "All" and V.st.filters.text == "", "from your own sheet: All, its filters set aside")
	local G = n.Inventory:Settings()
	check(G.cols and G.colOrder and G.tabOrder and G.hiddenTabs, "its own columns and tabs")
	local tabs = {}
	for _, b in ipairs(V.tabButtons) do if b:IsShown() then tabs[#tabs + 1] = b.sheet end end
	check(not n.IndexOf(tabs, "Mats") and n.IndexOf(tabs, "Gear"), "the built-in tabs only: " .. table.concat(tabs, ","))
	check(not (V.tabAdd:IsShown() or (V.tabAddTab and V.tabAddTab:IsShown())), "no New Sheet button there")
	V:SetSheet("Mats")
	check(V.st.sheet == "All", "and your sheet can't open there")
	local tab
	for _, b in ipairs(V.tabButtons) do if b:IsShown() and b.sheet == "Gear" then tab = b end end
	tab:GetScript("OnDragStart")(tab)
	check(n.dragTab == nil, "tabs don't drag there (order is in Global Sheets)")
	-- columns: only those that mean something for every character
	local keys = {}
	for _, c in ipairs(V:ColumnPlan()) do keys[#keys + 1] = c.key end
	check(n.IndexOf(keys, "c") and not n.IndexOf(keys, "age") and not n.IndexOf(keys, "jk"), "Age and Junk don't show there: " .. table.concat(keys, ","))
	-- Settings > Columns > Global Columns
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("globalcols")
	-- (by design since 1.9.0-beta8: "Global Inv Columns", the globe its own icon beside the heading, not in its text)
	local head
	for _, h in ipairs(P.pools.head) do if h:IsShown() and tostring(h.text.text):find("Global Inv Columns", 1, true) then head = h end end
	check(head and head.icon and head.icon:IsShown() and tostring(head.icon.texture):find("ui%-globe%.tga"), "Global Inv Columns' heading, with the globe")
	local said = false
	for _, w in ipairs(P.pools.text or {}) do if w:IsShown() and tostring(w.text and w.text.text or w.text):find("outside your profiles", 1, true) then said = true end end
	check(said, "saying these live outside your profiles")
	local rows = {}
	for _, l in ipairs(P.pools.list or {}) do if l:IsShown() then for _, r in ipairs(l.rows) do if r:IsShown() then rows[r.id] = r end end end end
	check(rows.il and rows.c and not rows.age and not rows.jk and not rows.who and not rows.w and not rows.n, "offers the columns that apply, not the fixed ones")
	rows.il.box:SetChecked(true); rows.il.box:GetScript("OnClick")(rows.il.box); M.runTimers()
	keys = {}
	for _, c in ipairs(V:ColumnPlan()) do keys[#keys + 1] = c.key end
	check(n.IndexOf(keys, "il") and n.IndexOf(G.cols, "il") and not n.IndexOf(n.db.cols, "il"), "iLvl on: in Global Inventory, not in your bags")
	-- Global Sheets
	P:ShowPage("globalsheets")
	rows = {}
	for _, l in ipairs(P.pools.list or {}) do if l:IsShown() then for _, r in ipairs(l.rows) do if r:IsShown() then rows[r.id] = r end end end end
	check(rows.All and rows.Gear and rows.GearSets and not rows.Mats, "the built-in tabs, not your own sheets")
	rows.Junk.box:SetChecked(false); rows.Junk.box:GetScript("OnClick")(rows.Junk.box); M.runTimers()
	tabs = {}
	for _, b in ipairs(V.tabButtons) do if b:IsShown() then tabs[#tabs + 1] = b.sheet end end
	check(n.IndexOf(G.hiddenTabs, "Junk") and not n.IndexOf(tabs, "Junk") and not n.IndexOf(n.db.hiddenTabs, "Junk"), "Junk unticked: gone from Global Inventory only")
	-- Global Sections
	P:ShowPage("globalsections")
	local seg
	for _, w in ipairs(P.pools.seg or {}) do if w:IsShown() and w.key == "__globalGrp" then seg = w end end
	check(seg ~= nil, "Global Sections: Open with Sections")
	local before = n.db.grp
	for _, b in ipairs(seg.btns) do if b:IsShown() and b.value == "none" then b:GetScript("OnClick")(b) end end
	M.runTimers()
	check(G.grp == "none" and n.db.grp == before and V:Pref("grp") == "none", "All: Global Inventory's, not your profile's")
	P:Hide()
	-- leaving: your sheet and its filters back
	V.btnGlobal:GetScript("OnClick")(V.btnGlobal); M.runTimers(); M.runTimers()
	check(V.st.sheet == "Mats" and V.st.filters.text == "cloth", "leaving: your own sheet again, its filters too")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- saved: Global Inventory's lists checked at load (unknown ids dropped, the built-in tabs all there)
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {} },
		globalInv = { cols = { "c", "bogus", 7, "c" }, colOrder = { "n", "c" }, tabOrder = { "Gear", "Nope" }, hiddenTabs = { "Junk", "Nope" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local G = BagSmithDB.globalInv
	check(#G.cols == 1 and G.cols[1] == "c", "columns: unknown and repeated ones dropped")
	check(G.tabOrder[1] == "Gear" and not n.IndexOf(G.tabOrder, "Nope") and n.IndexOf(G.tabOrder, "All") and n.IndexOf(G.tabOrder, "Bank"), "tabs: unknown dropped, every built-in one there")
	check(#G.hiddenTabs == 1 and G.hiddenTabs[1] == "Junk", "hidden tabs: known ones only")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- Settings 5% taller (588): the side list keeps full spacing with a Global page open, in both skins; Global pages NEW
	for _, skin in ipairs({ "modern", "classic" }) do
		local n, M = boot(skin)
		n.version = "1.9.0-beta6"
		local P = n.SettingsPanel
		P:Show()
		-- (by design since 1.10.0-beta9: one more page, Other Addons, so 17 entries, and Settings 612 tall to keep the
		-- full spacing this check is about)
		check(P.frame:GetHeight() == 612, skin .. ": Settings is 612 tall")
		for _, page in ipairs({ "globalsections", "globalcols", "globalsheets" }) do
			P:ShowPage(page)
			local shown = 0
			for _, b in ipairs(P.navButtons) do if b:IsShown() then shown = shown + 1 end end
			local need = (shown - 1) * 28 + 26
			check(shown == 17 and P:NavRoom() >= need, skin .. ": " .. page .. ": 17 entries fit at full spacing (" .. P:NavRoom() .. " for " .. need .. ")")
		end
		check(P:NewPage("globalsections") and P:NewPage("globalcols") and P:NewPage("globalsheets") and P:NewPage("sections"), skin .. ": the Global pages are NEW, and the pages they're under")
		check((n.errors or 0) == 0, skin .. ": no errors")
	end
end)()

;(function()
	-- (by design since 1.9.0-beta8) the stacked note is gone: Global Inventory's worth is its Total row (beta8's set)
	local n, M, V = boot()
	V.btnGlobal:GetScript("OnClick")(V.btnGlobal); M.runTimers(); M.runTimers()
	check(V.totalRow and V.totalRow:IsShown() and V.subTop == nil, "a Total row; no stacked note")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- Compact View: rows with room to spare use it (Shweep: "can it better utilize the width of the window?")
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {} } }
	local n = M.loadAddon("BagSmith")
	local C = n.CompactCategories
	local W, CELL, GAP, GUT, GG = 560, 40, 4, 3, 16
	local boxes = { { count = 3, minWidth = 120 }, { count = 8, minWidth = 90 }, { count = 1, minWidth = 80 }, { count = 4, minWidth = 100 }, { count = 6, minWidth = 100 } }
	local rows = C.Rows(boxes, W, CELL, GAP, GUT, GG, 40)
	local before = {}
	for i, row in ipairs(rows) do before[i] = {}; for j, p in ipairs(row) do before[i][j] = { across = p.across, width = p.width } end end
	C.Justify(rows, boxes, W, CELL, GAP, GUT, GG)
	for i, row in ipairs(rows) do
		local used, fits, grew = 0, true, true
		for j, p in ipairs(row) do
			used = used + p.width + (j > 1 and GG or 0)
			if p.across * (CELL + GAP) - GAP + 2 * GUT > p.width then fits = false end
			if p.width < before[i][j].width or p.across < before[i][j].across then grew = false end
		end
		if #row > 1 then check(used == W, "row " .. i .. " reaches the right edge: " .. used) end
		check(fits and grew, "row " .. i .. ": icons still fit, nothing shrank")
	end
	-- a line saved: two sections two lines deep, room for both on one
	local two = { { count = 3, minWidth = 60 }, { count = 4, minWidth = 60 } }
	local r2 = { { { index = 1, across = 2, width = 2 * 44 - 4 + 6 }, { index = 2, across = 2, width = 2 * 44 - 4 + 6 } } }
	C.Justify(r2, two, W, CELL, GAP, GUT, GG)
	check(r2[1][1].across == 3 and r2[1][2].across == 4, "a whole line of icons saved when the row has room: " .. r2[1][1].across .. ", " .. r2[1][2].across)
	check((n.errors or 0) == 0, "no errors")
end)()
