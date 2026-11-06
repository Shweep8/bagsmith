;(function()
	-- 1.2.0-beta11: the first-open guard: a shown window with items and nothing placed rebuilds once
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 3 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", view = "icons" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local m = n.Window.main
	check(m.used and #m.used > 0, "(control) a normal open places the item")
	-- the bad state: the open's own refresh places nothing (whatever the cause); the guard notices and rebuilds
	n.Window:Hide()
	local refreshed = false; local realRefresh = m.Refresh
	m.Refresh = function(self, force, reason)
		if reason == "first-open-guard" then refreshed = true; return realRefresh(self, force, reason) end
		m.used = {}   -- the broken open: nothing placed
	end
	n.Window:Show(); M.runTimers(); M.runTimers()
	m.Refresh = realRefresh
	check(refreshed and #m.used > 0, "a window shown with items and nothing placed is rebuilt by the guard")
	-- a healthy open does not trigger it
	refreshed = false; m.Refresh = function(self, force, reason) if reason == "first-open-guard" then refreshed = true end return realRefresh(self, force, reason) end
	n.Window:Hide(); n.Window:Show(); M.runTimers(); M.runTimers()
	m.Refresh = realRefresh
	check(not refreshed, "a healthy open is left alone")
end)()

