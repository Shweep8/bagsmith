;(function()
	-- 1.4.1-beta3 (Shweep's feedback on beta2): with Sort: Off in All view, moving items between a pinned section and
	-- All Items never makes All Items jump within a session. A slot that joins All Items (its item left a pinned
	-- section or Favorites) goes to the end; a slot that leaves (its item went into a pinned section) closes up and
	-- the item stays where it is in the bags. A fresh layout puts everything back in true bag order.
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
	M.put(0, 3, { id = 117, name = "Tough Jerky", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
	M.put(0, 5, { id = 2592, name = "Wool Cloth", q = 1, count = 3, class = 7, subclass = 5, price = 2 })
	M.put(0, 7, { id = 159, name = "Spring Water", q = 1, count = 3, class = 0, subclass = 5, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", emptySlots = true, favSection = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	_G.ClearCursor = function() M.cursorItem = nil end
	_G.PlaySound = function() end
	C_Container.SortBags = function() end
	local V, S = n.Window.main, n.Sections
	local function refresh() n:Scan(); n:RefreshViews(true); M.runTimers() end
	local function grid()
		local t = {}
		for _, b in ipairs(V.used or {}) do
			if b:IsShown() and b.rec and b.mode == "cell" and (b.inLane == "~all" or b.inLane == "") then
				t[#t + 1] = b.rec.bag .. ":" .. b.rec.slot .. (b.rec.empty and "*" or "")
			end
		end
		return table.concat(t, ",")
	end
	local function rowOf(id, lane) for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id and (not lane or b.inLane == lane) then return b end end end
	local function tileAt(slot) for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.slot == slot and (b.inLane == "~all" or b.inLane == "") then return b end end end

	local test = S:Create("Test"); S:Move(2592, test); S:SetPinned(test, true)
	V:SetPref("grp", "none"); V:SetPref("view", "icons"); V:SetPref("sort", "off"); refresh()
	check(grid() == "0:1,0:2*,0:3,0:4*,0:6*,0:7,0:8*", "(start) Wool, pinned, is left out of All Items (" .. grid() .. ")")

	-- ---- out of the pinned section into the gap at slot 2: no tile moves; the freed slot goes to the end
	local wool = rowOf(2592, test); wool:GetScript("OnDragStart")(wool)
	local gap = tileAt(2)
	M.bags[0][2], M.bags[0][5] = M.bags[0][5], nil
	gap:GetScript("OnReceiveDrag")(gap); refresh()
	check(S:MovedTo(2592) == nil and grid() == "0:1,0:2,0:3,0:4*,0:6*,0:7,0:8*,0:5*", "Wool lands in slot 2, nothing else moves, and its old slot is at the end (" .. grid() .. ")")

	-- ---- into a pinned section: the gap closes, and the item stays where it is in the bags
	S:Move(117, test); refresh()
	check(grid() == "0:1,0:2,0:4*,0:6*,0:7,0:8*,0:5*" and M.bags[0][3] and M.bags[0][3].id == 117, "Jerky into the pinned section: All Items closes up, Jerky stays in slot 3 (" .. grid() .. ")")

	-- ---- a swap: Jerky (pinned) dropped onto Spring Water in All Items; Water takes Jerky's old slot, at the end
	local jerky = rowOf(117, test); jerky:GetScript("OnDragStart")(jerky)
	local water = tileAt(7)
	M.bags[0][3], M.bags[0][7] = M.bags[0][7], M.bags[0][3]
	water:GetScript("OnReceiveDrag")(water); refresh()
	check(S:MovedTo(117) == nil and grid() == "0:1,0:2,0:4*,0:6*,0:7,0:8*,0:5*,0:3", "the swap: Jerky in Water's place, Water (in Jerky's old slot) at the end (" .. grid() .. ")")

	-- ---- Favorites: favoriting closes up; unfavoriting sends the slot to the end
	n.Marks:ToggleFavorite({ itemID = 2589 }); refresh()
	check(grid() == "0:2,0:4*,0:6*,0:7,0:8*,0:5*,0:3", "favoriting Linen closes up All Items (" .. grid() .. ")")
	n.Marks:ToggleFavorite({ itemID = 2589 }); refresh()
	check(grid() == "0:2,0:4*,0:6*,0:7,0:8*,0:5*,0:3,0:1", "unfavoriting it: Linen's slot goes to the end, nothing else moves (" .. grid() .. ")")

	-- ---- fresh layouts put everything back in its true order
	local TRUE = "0:1,0:2,0:3,0:4*,0:5*,0:6*,0:7,0:8*"
	n.Window:Hide(); M.runTimers(); n.Window:Show(); M.runTimers(); M.runTimers(); refresh()
	check(grid() == TRUE, "closing and reopening the bags: true bag order (" .. grid() .. ")")
	-- (a new end-of-list slot, then a Clean Up)
	n.Marks:ToggleFavorite({ itemID = 159 }); refresh(); n.Marks:ToggleFavorite({ itemID = 159 }); refresh()
	check(grid() ~= TRUE, "(a slot at the end again)")
	V:CleanUp(); refresh()
	check(grid() == TRUE, "a Clean Up: true bag order (" .. grid() .. ")")
	-- (and a change of sort)
	n.Marks:ToggleFavorite({ itemID = 159 }); refresh(); n.Marks:ToggleFavorite({ itemID = 159 }); refresh()
	V:SetPref("sort", "quality"); refresh(); V:SetPref("sort", "off"); refresh()
	check(grid() == TRUE, "a change of sort and back: true bag order (" .. grid() .. ")")
	-- ---- other sorts: free slots after the items, as always
	V:SetPref("sort", "quality"); refresh()
	check(grid():find("%*") and not grid():find("%*,[^,]*[^*],"), "with any other sort, free slots follow the items as before (" .. grid() .. ")")
end)()
