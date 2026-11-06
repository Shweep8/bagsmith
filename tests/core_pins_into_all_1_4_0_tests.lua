;(function()
	-- 1.4.0-beta5 (Shweep's feedback on beta4): a pinned custom section with items showed twice in All view (once
	-- empty); and an item moved from it onto All Items' slots jumped back into it when the window refreshed.
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 10
	for b = 1, 5 do M.sizes[b] = 0 end
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
	M.put(0, 2, { id = 117, name = "Tough Jerky", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
	M.put(0, 3, { id = 2592, name = "Wool Cloth", q = 1, count = 3, class = 7, subclass = 5, price = 2 })
	M.put(0, 4, { id = 159, name = "Spring Water", q = 1, count = 3, class = 0, subclass = 5, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", emptySlots = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	_G.ClearCursor = function() M.cursorItem = nil end
	local V, S = n.Window.main, n.Sections
	local function refresh() n:RefreshViews(true); M.runTimers() end
	local function count(list, id) local c = 0; for _, x in ipairs(list or {}) do if x == id then c = c + 1 end end return c end
	local function said(pat) for _, l in ipairs(M.log) do if l:find(pat, 1, true) then return true end end end
	local function cellIn(lane, empty)
		for _, b in ipairs(V.used or {}) do
			if b:IsShown() and b.inLane == lane and b.rec and ((empty and b.rec.empty) or (not empty and not b.rec.empty)) then return b end
		end
	end

	local test = S:Create("Test")
	S:Move(2589, test); S:Move(117, test)
	S:SetPinned(test, true)
	V:SetPref("grp", "none"); V:SetPref("view", "icons"); V:SetPref("sort", "off"); refresh()
	-- ---- one section, not two
	check(count(V.laneIds, test) == 1, "All view (Icons): the pinned custom section with items shows once (" .. table.concat(V.laneIds or {}, ",") .. ")")
	V:SetPref("view", "list"); refresh()
	check(count(V.laneIds, test) == 1, "All view (List): once")
	V:SetPref("grp", "type"); refresh()
	check(count(V.laneIds, test) == 1, "By Section: once")
	V:SetPref("grp", "none"); V:SetPref("view", "icons"); refresh()

	-- ---- dragged onto an empty slot among All Items: it leaves the pinned section and stays in All Items
	-- (1.4.0-beta6: the game's move is modeled in the bags, since the decision is now made from the slot)
	local slot = cellIn("~all", true)
	check(slot ~= nil, "(an empty slot in All Items)")
	-- (1.4.0-beta7: a drag is judged by the row it started from, so each drag starts from its row, as in the game)
	local function startDrag(id) for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then b:GetScript("OnDragStart")(b); return b end end end
	local function land(target, fromBag, fromSlot)
		local b, s = target.rec.bag, target.rec.slot
		local carried = M.bags[fromBag][fromSlot]
		M.bags[fromBag][fromSlot] = M.bags[b][s]
		M.bags[b][s] = carried
	end
	startDrag(2589)
	land(slot, 0, 1)   -- Linen Cloth from slot 1 into the empty slot
	slot:GetScript("OnReceiveDrag")(slot)
	check(S:MovedTo(2589) == nil, "dropping Linen Cloth on an empty slot in All Items takes it out of the pinned section")
	refresh()
	local inAll = false; for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 2589 then inAll = b.inLane == "~all" end end
	check(inAll, "after the window refreshes it's still in All Items (no bounce)")
	-- ---- clicked down onto an item among All Items (pick up, then click to place): the same
	local onItem = cellIn("~all", false)
	M.cursorItem = 117
	onItem:GetScript("OnMouseDown")(onItem, "LeftButton")
	M.cursorItem = nil   -- the game places it: Tough Jerky (slot 2) swaps into that item's slot
	land(onItem, 0, 2)
	onItem:GetScript("OnClick")(onItem, "LeftButton")
	check(S:MovedTo(117) == nil, "clicking Tough Jerky down on an item in All Items takes it out too")
	-- ---- what's left alone
	S:Move(2592, test); refresh()
	local inPinned = cellIn(test, false)
	inPinned:GetScript("OnReceiveDrag")(inPinned)
	check(S:MovedTo(2592) == test, "a drop inside the pinned section leaves the item there")
	V:SetPref("grp", "type"); refresh()
	local other; for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and not b.rec.empty and b.inLane ~= test then other = b; break end end
	other:GetScript("OnReceiveDrag")(other)
	check(S:MovedTo(2592) == test, "By Section has no All Items: a drop there doesn't change sections")
	V:SetPref("grp", "none"); refresh()
	S:Move(159, "Other"); S:SetPinned(test, false); refresh()
	local plain = cellIn("~all", true) or cellIn("", true)
	if plain then plain:GetScript("OnReceiveDrag")(plain) end
	check(S:MovedTo(2592) == test, "with the section unpinned, a drop among the items doesn't undo its move")
	S:SetPinned(test, true)
	-- ---- its own section pinned too: said, nothing changes
	S:SetPinned("TradeGoods", true); refresh()
	slot = cellIn("~all", true)
	local woolSlot; for s2 = 1, 10 do if M.bags[0][s2] and M.bags[0][s2].id == 2592 then woolSlot = s2 end end
	startDrag(2592)
	land(slot, 0, woolSlot)
	slot:GetScript("OnReceiveDrag")(slot)
	check(S:MovedTo(2592) == test and said("its own section, Trade Goods, is pinned too"), "with Trade Goods pinned too, Wool Cloth stays in Test and chat says why")
end)()
