;(function()
	-- 1.4.0-beta4 (Shweep's feedback on beta3): with Sort: Off and empty slots shown, the grid follows the bags as
	-- they are: empty slots sit where they really are, not gathered at the end.
	local function boot(stock, profile)
		package.loaded.mock = nil
		local M = require("mock")
		M.sizes[0] = 8; M.sizes[1] = 4
		for b = 2, 5 do M.sizes[b] = 0 end
		stock(M)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = "modern", emptySlots = true }
		for k, v in pairs(profile or {}) do p[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); M.runTimers(); M.runTimers()
		return n, M
	end
	local function spaced(M)
		M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
		M.put(0, 4, { id = 9001, name = "Azure Ring", q = 3, count = 1, class = 4, subclass = 0, price = 50, equip = "INVTYPE_FINGER" })
		M.put(0, 7, { id = 117, name = "Tough Jerky", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
		M.put(1, 2, { id = 2592, name = "Wool Cloth", q = 1, count = 3, class = 7, subclass = 5, price = 2 })
	end
	-- the cells in the order they're laid out: "bag:slot" with a * for an empty slot
	local function grid(V)
		local t = {}
		for _, b in ipairs(V.used or {}) do
			if b:IsShown() and b.rec and b.mode == "cell" then t[#t + 1] = b.rec.bag .. ":" .. b.rec.slot .. (b.rec.empty and "*" or "") end
		end
		return table.concat(t, ",")
	end
	local REAL = "0:1,0:2*,0:3*,0:4,0:5*,0:6*,0:7,0:8*,1:1*,1:2,1:3*,1:4*"

	local n, M = boot(spaced)
	local V = n.Window.main
	V:SetPref("view", "icons"); V:SetPref("grp", "none"); V:SetPref("sort", "off"); n:RefreshViews(true); M.runTimers()
	check(grid(V) == REAL, "Sort: Off in All view: the grid is the bags as they are, gaps in place (" .. grid(V) .. ")")
	-- other sorts: empty slots still follow the items
	V:SetPref("sort", "quality"); n:RefreshViews(true); M.runTimers()
	check(grid(V):find("^0:4,") and grid(V):find("0:2%*") and not grid(V):find("%*,[^,]*[^*],"), "Quality: the items first, the empty slots after them, as before (" .. grid(V) .. ")")
	-- By Bag: each bag laid out as it is
	V:SetPref("sort", "off"); V:SetPref("grp", "bag"); n:RefreshViews(true); M.runTimers()
	check(grid(V) == REAL, "Sort: Off in By Bag: each bag laid out as it is (" .. grid(V) .. ")")
	-- with a Favorites section above, the main list still gets its gaps in place (not a block at the end)
	V:SetPref("grp", "none")
	n:Set("favSection", true)
	n.Marks:ToggleFavorite({ itemID = 117 })
	n:RefreshViews(true); M.runTimers()
	local g = grid(V)
	-- (slot 7 holds the favorite, shown in Favorites: it isn't empty, so All Items shows no gap there)
	check(g:find("0:7", 1, true) == 1 and g:sub(5) == "0:1,0:2*,0:3*,0:4,0:5*,0:6*,0:8*,1:1*,1:2,1:3*,1:4*", "with Favorites above, All Items keeps its real gaps in place, not as a block at the end (" .. g .. ")")
	n.Marks:ToggleFavorite({ itemID = 117 })
	-- a column sort is a sort: empty slots after the items
	n:SortByColumn(V.st, "n"); n:RefreshViews(true); M.runTimers()
	check(grid(V) ~= REAL and grid(V):find("%*$"), "a column sort puts the empty slots after the items again")
	V.st.colSort = nil

	-- ---- Merge Stacks: a merged row sits at its first slot; its other slot isn't shown as a gap
	n, M = boot(function(MM)
		MM.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, stack = 20, class = 7, subclass = 5, price = 1 })
		MM.put(0, 5, { id = 2589, name = "Linen Cloth", q = 1, count = 7, stack = 20, class = 7, subclass = 5, price = 1 })
		MM.put(0, 3, { id = 117, name = "Tough Jerky", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
	end, { mergeStacks = true })
	V = n.Window.main
	V:SetPref("view", "icons"); V:SetPref("grp", "none"); V:SetPref("sort", "off"); V:SetPref("mergeStacks", true); n:RefreshViews(true); M.runTimers()
	g = grid(V)
	check(g:find("^0:1,0:2%*,0:3,0:4%*,0:6%*") and not g:find("0:5", 1, true), "Merge Stacks: the merged Linen row sits at slot 1, and slot 5 isn't shown as a gap (" .. g .. ")")
end)()
