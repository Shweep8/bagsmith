--[[
	Modern must not change while Classic is built. This lays out the bags
	window in Modern and writes down the position, size and visibility of
	every key piece, in three situations:
	  fresh       a session that never touches Classic
	  switched    Modern -> Classic -> Modern
	  startClassic a session that starts in Classic, then switches to Modern
	Each must match tests/modern_baseline.txt (the current prod).
	Besides layout, "look" lines record colors (backdrop fill and border,
	text, textures) for every window, so a lost outline or a wrong color
	fails the check too, not just a moved piece.
--]]
return function(scenario)
	package.loaded.mock = nil
	local M = require("mock")
	M.childrenStartShown = true   -- as on the real client, so hidden-then-restored pieces come back shown
	M.put(0, 1, { id = 1001, name = "Staff", q = 3, class = 2, subclass = 10, price = 810 })
	M.put(0, 2, { id = 1002, name = "Potion", q = 1, count = 5, class = 0, subclass = 1, price = 5 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, profiles = { Default = { skin = "modern" } }, chars = {}, cache = {} }   -- Modern (new players start in Classic)
	if scenario == "startClassic" then _G.BagSmithDB = { version = 2, profiles = { Default = { skin = "classic" } }, chars = {}, cache = {} } end
	local ns = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags()
	if scenario == "switched" then
		ns:Set("skin", "classic")
		ns.SettingsPanel:Show(); ns.SettingsPanel:ShowPage("look"); ns.SettingsPanel:Hide()
		ns.Popups:OpenFilters(ns.Window.main, "browse"); ns.Popups.filter:Hide()
		ns.ui.bagWindows = true; ns:RefreshViews(true); ns.ui.bagWindows = false; ns:RefreshViews(true)
		ns.Drawer:Show(); ns.Drawer:Hide()
		ns:Set("skin", "modern")
	end
	if scenario == "startClassic" then ns:Set("skin", "modern") end
	ns:RefreshViews(true)
	local main = ns.Window.main
	local function name(v)
		if type(v) ~= "table" then return tostring(v) end
		if v == main.frame then return "window" end
		for k, f in pairs({ title = main.title, tabs = main.tabs, footer = main.footer, header = main.header, scroll = main.scroll, tools = main.tools }) do
			if v == f then return k end
		end
		return v.name or v.kind or "frame"
	end
	local out = {}
	local function snap(label, f)
		if not f then return end
		local pts = {}
		for _, p in ipairs(f.points or {}) do
			-- "TOPLEFT", 12, -12 and "TOPLEFT", parent, "TOPLEFT", 12, -12 are the same place
			if type(p[2]) == "number" or p[2] == nil then p = { p[1], f.parent, p[1], p[2] or 0, p[3] or 0 } end
			pts[#pts + 1] = ("%s,%s,%s,%s,%s"):format(tostring(p[1]), name(p[2] or f.parent), tostring(p[3] or p[1]), tostring(p[4] or 0), tostring(p[5] or 0))
		end
		out[#out + 1] = ("%s | w=%s h=%s shown=%s | %s"):format(label, tostring(f.w), tostring(f.h), tostring(f.shown ~= false), table.concat(pts, " ; "))
	end
	snap("title", main.title); snap("scroll", main.scroll); snap("tabs", main.tabs); snap("tabAdd", main.tabAdd); snap("tabEdit", main.tabEdit)
	snap("footer", main.footer); snap("header", main.header); snap("btnSort", main.btnSort); snap("btnMerge", main.btnMerge); snap("btnFilter", main.btnFilter)
	snap("scrollbar", main.scroll.ScrollBar); snap("search", main.search); snap("tools", main.tools)
	for i, b in ipairs(main.tabButtons or {}) do snap("tab" .. i, b) end
	local L = dofile("tests/look.lua")
	local looks = {}
	L.snap(looks, { { "main", main.frame, skip = { [main.scroll] = true } } })
	-- The currency drawer.
	ns.Drawer:Show()
	local dr = ns.Drawer.frame
	snap("drawer.scroll", _G.BagSmithDrawerScroll); snap("drawer.import", dr.import); snap("drawer.hint", dr.hint)
	out[#out + 1] = ("drawer.rows | w=%s"):format(tostring(dr.rows[1] and dr.rows[1].w))
	L.snap(looks, { { "drawer", dr } })
	ns.Drawer:Hide()
	-- The other windows, in Modern.
	ns.SettingsPanel:Show(); ns.SettingsPanel:ShowPage("look")
	local sp = ns.SettingsPanel
	snap("settings.title", sp.frame.title); snap("settings.nav", sp.nav); snap("settings.scroll", sp.scroll); snap("settings.sub", sp.frame.sub)
	L.snap(looks, { { "settings", sp.frame, skip = { [sp.scroll] = true } } })
	ns.SettingsPanel:Hide()
	ns.Popups:OpenFilters(main, "browse")
	local fp = ns.Popups.filter
	snap("filter.title", fp.title); snap("filter.search", fp.search)
	L.snap(looks, { { "filter", fp } })
	fp:Hide()
	ns.ui.bagWindows = true; ns:RefreshViews(true)
	local bw = ns.Window.bagViews[1]
	snap("bagwin.title", bw.title); snap("bagwin.scroll", bw.scroll); snap("bagwin.titleText", bw.titleText)
	L.snap(looks, { { "bagwin", bw.frame, skip = { [bw.scroll] = true } } })
	ns.ui.bagWindows = false; ns:RefreshViews(true)
	-- The bank window.
	M.fire("BANKFRAME_OPENED"); M.runTimers()
	local bk = ns.Window.bank
	local function bname(v) if v == bk.frame then return "bankwindow" elseif v == bk.tools then return "banktools" elseif v == bk.bankBar then return "bankBar" elseif v == bk.header then return "bankheader" end return name(v) end
	for _, pair in ipairs({ { "bank.tools", bk.tools }, { "bank.bankBar", bk.bankBar }, { "bank.header", bk.header }, { "bank.scroll", bk.scroll } }) do
		local f = pair[2]
		local pts = {}
		for _, p in ipairs(f.points or {}) do
			if type(p[2]) == "number" or p[2] == nil then p = { p[1], f.parent, p[1], p[2] or 0, p[3] or 0 } end
			pts[#pts + 1] = ("%s,%s,%s,%s,%s"):format(tostring(p[1]), bname(p[2] or f.parent), tostring(p[3] or p[1]), tostring(p[4] or 0), tostring(p[5] or 0))
		end
		out[#out + 1] = ("%s | h=%s | %s"):format(pair[1], tostring(f.h), table.concat(pts, " ; "))
	end
	L.snap(looks, { { "bank", bk.frame, skip = { [bk.scroll] = true } } })
	M.fire("BANKFRAME_CLOSED"); M.runTimers()
	for _, line in ipairs(looks) do out[#out + 1] = line end
	return table.concat(out, "\n")
end
