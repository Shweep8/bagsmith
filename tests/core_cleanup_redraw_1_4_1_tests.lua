;(function()
	-- 1.4.1 (Shweep's feedback on 1.4.1-beta1): after a Clean Up, items showed both in a pinned section and in All Items
	-- until the pointer left the window, because the window held its layout under the pointer. A Clean Up now lays
	-- out at once. And All Items is BagSmith's OneBag of what isn't shown elsewhere: with Sort: Off, a pinned item's
	-- slot is simply left out (the 1.4.1-beta1 placeholders are gone).
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
	M.put(0, 3, { id = 117, name = "Tough Jerky", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
	M.put(0, 5, { id = 2592, name = "Wool Cloth", q = 1, count = 3, class = 7, subclass = 5, price = 2 })
	M.put(0, 7, { id = 159, name = "Spring Water", q = 1, count = 3, class = 0, subclass = 5, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", emptySlots = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local clock = 1000; _G.GetTime = function() return clock end
	local V, S = n.Window.main, n.Sections
	local test = S:Create("Test"); S:Move(2592, test); S:SetPinned(test, true)
	V:SetPref("grp", "none"); V:SetPref("view", "icons"); V:SetPref("sort", "off"); n:RefreshViews(true); M.runTimers()
	local function grid(lane)
		local t = {}
		for _, b in ipairs(V.used or {}) do
			if b:IsShown() and b.rec and b.mode == "cell" and (not lane or b.inLane == lane) then
				t[#t + 1] = b.rec.bag .. ":" .. b.rec.slot .. (b.rec.placeholder and "p" or (b.rec.empty and "*" or ""))
			end
		end
		return table.concat(t, ",")
	end
	local function shownCount(id) local c = 0; for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then c = c + 1 end end return c end

	-- ---- All Items leaves the pinned item's slot out: no placeholder
	check(grid("~all") == "0:1,0:2*,0:3,0:4*,0:6*,0:7,0:8*", "Sort: Off, All view: Wool's slot (pinned) is left out of All Items, with no placeholder (" .. grid("~all") .. ")")
	check(not grid():find("p", 1, true), "no placeholder tile anywhere")

	-- ---- a plain item change under the pointer still holds the layout (unchanged behavior)
	V.frame.IsMouseOver = function() return true end
	M.bags[0][2], M.bags[0][1] = M.bags[0][1], nil         -- Linen moves from slot 1 to slot 2
	n:Scan(); n:RefreshViews(false, "items"); M.runTimers()
	check(V.held == true, "(control) an item change with the pointer over the window holds the layout, as before")

	-- ---- a Clean Up lays out at once, even under the pointer
	C_Container.SortBags = function()
		-- the game rearranges: Wool (pinned) to slot 1, Linen to slot 3, Jerky to slot 5
		local linen, jerky, wool = M.bags[0][2], M.bags[0][3], M.bags[0][5]
		M.bags[0][1], M.bags[0][2], M.bags[0][3], M.bags[0][5] = wool, nil, linen, jerky
	end
	_G.PlaySound = function() end
	local forced = false
	local realRefresh = n.RefreshViews
	n.RefreshViews = function(self, force, reason) if force then forced = true end return realRefresh(self, force, reason) end
	V:CleanUp()
	forced = false
	n:Scan(); n:RefreshViews(false, "items")                 -- the bags change while the Clean Up runs
	check(V.held == false, "during a Clean Up the window doesn't hold its layout under the pointer")
	check(shownCount(2592) == 1 and grid("~all") == "0:2*,0:3,0:4*,0:5,0:6*,0:7,0:8*", "after it, Wool shows once (in its pinned section) and All Items matches the bags (" .. grid("~all") .. ")")
	-- ---- when its time is up (the mock runs timers at once), a final layout runs and the hold returns
	M.runTimers()
	n.RefreshViews = realRefresh
	check(forced and n.cleanupUntil == nil, "when the Clean Up's time is up, the windows lay out once more")
	M.bags[0][4], M.bags[0][7] = M.bags[0][7], nil
	n:Scan(); n:RefreshViews(false, "items"); M.runTimers()
	check(V.held == true, "afterwards an item change under the pointer holds the layout again")
	-- ---- the Loot Helper's Clean Up Bags does the same
	n.MakeRoom:CleanUp()
	check(n.cleanupUntil ~= nil and n.cleanupUntil > clock, "the Loot Helper's Clean Up Bags starts the same window")
end)()
