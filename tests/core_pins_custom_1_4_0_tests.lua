;(function()
	-- 1.4.0-beta3 (Shweep's feedback on beta2): a pinned custom section always shows, empty or not, in All view and
	-- By Section; and an item can go from a pinned section back to All Items by dropping it on that title.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
	M.put(0, 2, { id = 117, name = "Tough Jerky", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
	M.put(0, 3, { id = 2592, name = "Wool Cloth", q = 1, count = 3, class = 7, subclass = 5, price = 2 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", showEmptySections = false } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	_G.ClearCursor = function() M.cursorItem = nil end
	local V, S = n.Window.main, n.Sections
	local function refresh() n:RefreshViews(true); M.runTimers() end
	local function lanes() return table.concat(V.laneIds or {}, ",") end
	local function catOf(id) for _, r in ipairs(n.items) do if r.itemID == id then return r.cat end end end
	local function said(pat) for _, l in ipairs(M.log) do if l:find(pat, 1, true) then return true end end end

	-- ---- an empty pinned custom section shows, with Show When Empty off everywhere
	local farm = S:Create("Farm")
	S:SetShowEmpty(farm, false)
	S:SetPinned(farm, true)
	V:SetPref("grp", "none"); V:SetPref("view", "list"); refresh()
	check(lanes():find("^" .. farm .. ",~all"), "All view (List): the empty pinned custom section shows at the top, then All Items (" .. lanes() .. ")")
	V:SetPref("view", "icons"); refresh()
	check(lanes():find("^" .. farm), "All view (Icons) too (" .. lanes() .. ")")
	V:SetPref("grp", "type"); refresh()
	check((V.laneIds or {})[1] == farm, "By Section: first, even with Show When Empty off (" .. lanes() .. ")")
	-- a search that narrows the window puts it aside, as for any section
	V:SetPref("grp", "none"); V.st.filters.text = "jerky"; refresh()
	check(not lanes():find(farm, 1, true), "a search puts the empty pinned section aside (" .. lanes() .. ")")
	V.st.filters.text = ""; refresh()

	-- ---- drop onto its title in All view: the item moves in
	M.cursorItem = 2589
	check(S:DropOnSection(farm) == true and catOf(2589) == farm, "dropping Linen Cloth on the pinned section's title in All view moves it there")
	M.cursorItem = nil; refresh()
	local linenRows = 0; for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 2589 then linenRows = linenRows + 1 end end
	check(lanes():find("^" .. farm) and linenRows == 1, "it shows once, in the pinned section")

	-- ---- and back out to All Items
	check(S:DropHint("~all") == nil, "(no hint without an item on the cursor)")
	M.cursorItem = 2589
	check(S:DropHint("~all") == "Drop to move this item back to All Items" or (S:DropHint("~all") or ""):find("back to All Items", 1, true), "over All Items, the hint says it goes back to All Items")
	check(S:DropOnSection("~all") == true and catOf(2589) == "TradeGoods", "dropping it on All Items sends it back to its own section, so it rejoins All Items")
	M.cursorItem = nil; refresh()
	check(lanes():find("^" .. farm .. ",~all"), "the pinned section stays, empty, at the top (" .. lanes() .. ")")
	-- an item that isn't in a pinned section is already in All Items: nothing changes
	S:Move(2592, farm); S:SetPinned(farm, false); refresh()
	M.cursorItem = 2592
	check(S:DropOnSection("~all") == false and catOf(2592) == farm, "an item in an unpinned custom section isn't touched by an All Items drop")
	M.cursorItem = nil
	S:SetPinned(farm, true)

	-- ---- its own section pinned too: said, nothing changes, the item stays on the cursor
	S:Move(2589, farm); S:SetPinned("TradeGoods", true); refresh()
	M.cursorItem = 2589
	check(S:DropOnSection("~all") == false and catOf(2589) == farm and M.cursorItem == 2589, "with Trade Goods pinned too, Linen Cloth can't go to All Items: nothing changes")
	check(said("its own section, Trade Goods, is pinned too"), "and chat says why, and what to do")
	-- an item in a built-in pinned section (by type): said
	M.cursorItem = 2592
	S:Move(2592, "TradeGoods")
	check(S:DropOnSection("~all") == false and said("Wool Cloth belongs in Trade Goods, which is pinned"), "an item in a pinned built-in section: said, nothing changes")
	M.cursorItem = nil
end)()
