--[[
	Classic must not change by accident while Modern is worked on (the mirror
	of modern_check.lua). Lays out every window in Classic and records the
	position, size, layer and colors of every piece the player sees, in two
	situations:
	  classic     a session that starts in Classic
	  toClassic   a session that starts in Modern, then switches to Classic
	Each must match tests/classic_baseline.txt. Re-record it only when a
	Classic change is intended, and note why at the top of the file.
--]]
return function(scenario)
	package.loaded.mock = nil
	local M = require("mock")
	M.childrenStartShown = true
	M.put(0, 1, { id = 1001, name = "Staff", q = 3, class = 2, subclass = 10, price = 810 })
	M.put(0, 2, { id = 1002, name = "Potion", q = 1, count = 5, class = 0, subclass = 1, price = 5 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, profiles = { Default = { skin = "modern" } }, chars = {}, cache = {} }   -- starts in Modern (toClassic switches)
	if scenario == "classic" then _G.BagSmithDB = { version = 2, profiles = { Default = { skin = "classic" } }, chars = {}, cache = {} } end
	local ns = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags()
	if scenario == "toClassic" then ns:Set("skin", "classic") end
	ns:RefreshViews(true)
	local L = dofile("tests/look.lua")
	local out = {}
	local main = ns.Window.main
	L.snap(out, { { "main", main.frame, skip = { [main.scroll.child] = true } } }, { layout = true })
	ns.Drawer:Show()
	L.snap(out, { { "drawer", ns.Drawer.frame } }, { layout = true })
	ns.Drawer:Hide()
	ns.SettingsPanel:Show(); ns.SettingsPanel:ShowPage("look")
	local sp = ns.SettingsPanel
	L.snap(out, { { "settings", sp.frame, skip = { [sp.scroll.child] = true } } }, { layout = true })
	ns.SettingsPanel:Hide()
	ns.Popups:OpenFilters(main, "browse")
	L.snap(out, { { "filter", ns.Popups.filter } }, { layout = true })
	ns.Popups.filter:Hide()
	ns.ui.bagWindows = true; ns:RefreshViews(true)
	local bw = ns.Window.bagViews[1]
	L.snap(out, { { "bagwin", bw.frame, skip = { [bw.scroll.child] = true } } }, { layout = true })
	ns.ui.bagWindows = false; ns:RefreshViews(true)
	M.fire("BANKFRAME_OPENED"); M.runTimers()
	local bk = ns.Window.bank
	L.snap(out, { { "bank", bk.frame, skip = { [bk.scroll.child] = true } } }, { layout = true })
	M.fire("BANKFRAME_CLOSED"); M.runTimers()
	return table.concat(out, "\n")
end
