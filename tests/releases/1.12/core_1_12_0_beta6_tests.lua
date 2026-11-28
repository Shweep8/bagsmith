-- ======== 1.12.0-beta6 (Shweep, 28 Nov: "build") ========
-- The answer to the independent re-audit of 1.12.0-beta5 ("Keep in beta"; beta4's four findings closed, two new ones,
-- both Medium, each reproduced on beta5 first with the auditor's own probes: 15 pass, 4 fail there, 19 pass here).
--   B5-1 a bag offer still waiting on its next-frame timer survived a newer bag being clicked, opened, and could swap.
--   B5-2 a column's fifth failure switched it off in the middle of a sort, the order stopped being one order, and the
--        list's redraw was abandoned (a regression from beta5's answer to an advisory).
-- The fixtures are the beta1 set's (the list) and the beta3 set's (the game's bag moves), as they stand.

local ARROW = "|TInterface\\AddOns\\Pawn\\Textures\\UpgradeArrow:0|t"
local function arrowed(pct) return pct and (ARROW .. " " .. pct) or ARROW end
local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function slurp(p) local f = assert(io.open(p, "r")); local s = f:read("*a"); f:close(); return s end
local function idOf(link) return tonumber(tostring(link):match("item:(%d+)")) end

-- answers[id]: true (an upgrade), false or nil (not one), "wait" (Pawn can't say yet: nil)
local function fakePawn()
	local P = { answers = {}, pct = {}, asks = 0, amountCalls = 0, rescans = 0 }
	_G.PawnShouldItemLinkHaveUpgradeArrow = function(link)
		P.asks = P.asks + 1
		local a = P.answers[idOf(link)]
		if a == "wait" then return nil end
		return a and true or false
	end
	_G.PawnGetItemData = function(link) return { Link = link, ID = idOf(link) } end
	_G.PawnIsItemAnUpgrade = function(item, doNotRescan)
		P.amountCalls = P.amountCalls + 1
		if doNotRescan ~= true then P.rescans = P.rescans + 1 end
		if P.fail then error("Pawn is busy") end
		return P.pct[item.ID]
	end
	_G.PawnBigUpgradeThreshold = 100
	_G.PawnCommon = { ShowBagUpgradeAdvisor = true }
	-- 9802: an upgrade for two scales, 15.4% and 31%; 9804: nothing in the slot (Pawn's huge number); 9805: a higher
	-- item level only (no list at all); 9806: under half a percent
	P.answers[9802], P.answers[9804], P.answers[9805], P.answers[9806] = true, true, true, true
	P.pct[9802] = { { ScaleName = "a", LocalizedScaleName = "A", PercentUpgrade = 0.154 }, { ScaleName = "b", LocalizedScaleName = "B", PercentUpgrade = 0.31 } }
	P.pct[9804] = { { ScaleName = "a", PercentUpgrade = 100 } }
	P.pct[9806] = { { ScaleName = "a", PercentUpgrade = 0.004 } }
	return P
end
local function noPawn()
	_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnGetItemData, _G.PawnIsItemAnUpgrade, _G.PawnBigUpgradeThreshold, _G.PawnCommon = nil, nil, nil, nil, nil
end

local function boot(o)
	o = o or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 9801, name = "Old Belt", q = 1, class = 4, subclass = 1, price = 5, equip = "INVTYPE_WAIST" })
	M.put(0, 2, { id = 9802, name = "Better Belt", q = 2, class = 4, subclass = 1, price = 50, equip = "INVTYPE_WAIST" })
	M.put(0, 3, { id = 9804, name = "First Ring", q = 2, class = 4, subclass = 0, price = 50, equip = "INVTYPE_FINGER" })
	M.put(0, 4, { id = 9805, name = "Level Only", q = 2, class = 4, subclass = 1, price = 50, equip = "INVTYPE_LEGS" })
	M.put(0, 5, { id = 9806, name = "Slight Gloves", q = 2, class = 4, subclass = 1, price = 50, equip = "INVTYPE_HAND" })
	M.put(0, 6, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 13 })
	if o.bag1 then M.put(1, 1, { id = 9807, name = "Spare Boots", q = 1, class = 4, subclass = 1, price = 5, equip = "INVTYPE_FEET" }) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = o.db and { version = 2, chars = {}, cache = {}, profiles = { Default = o.db } } or nil
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local main
	if not o.closed then
		ToggleAllBags(); M.runTimers()
		main = n.Window.main
		main.RowWidth = function() return o.width or 900 end   -- wide enough for every column, unless a case says otherwise
		n:RefreshViews(true); M.runTimers()
	end
	return n, M, main
end
local function row(v, id) for _, b in ipairs(v.used or {}) do if b:IsShown() and b.rec and b.hasItem and b.rec.itemID == id then return b end end end
local function cell(v, id, field) local b = row(v, id); local fs = b and b[field or "colX_pawn"]; return fs and fs.text or nil, fs end
local function keys(v) local t = {}; for _, c in ipairs((v:ColumnPlan())) do t[#t + 1] = c.key end; return table.concat(t, ",") end
local function col(v, key) for _, c in ipairs((v:ColumnPlan())) do if c.key == key then return c end end end
local function names(v) local t = {}; for _, b in ipairs(v.used or {}) do if b:IsShown() and b.rec and b.hasItem then t[#t + 1] = b.rec.name end end; return table.concat(t, " | ") end
local function tick(n, M, key, on, list)
	list = list or n.db.cols
	local i = n.IndexOf(list, key)
	if on and not i then table.insert(list, key) elseif not on and i then table.remove(list, i) end
	n:Fire("SETTINGS_CHANGED", "cols"); n:RefreshViews(true); M.runTimers()
end


local LINEN, WOOL, SILK, MAGE, RUNE, TINY, HERB = 4238, 4240, 4245, 4241, 14046, 4999, 22250
local SIZE = { [LINEN] = 4, [WOOL] = 6, [SILK] = 8, [MAGE] = 10, [RUNE] = 14, [TINY] = 2, [HERB] = 12 }
local NAMES = { [LINEN] = "Linen Bag", [WOOL] = "Wool Bag", [SILK] = "Silk Bag", [MAGE] = "Mageweave Bag", [RUNE] = "Runecloth Bag", [TINY] = "Tiny Pouch", [HERB] = "Herb Pouch" }
local function bagItem(id) return { id = id, name = NAMES[id], q = 1, class = 1, subclass = 0, equip = "INVTYPE_BAG", price = 10 } end
local function ore(n) return { id = 2770, name = "Copper Ore", q = 1, count = n or 5, class = 7, subclass = 7, price = 1 } end
-- worn: bag 1 Silk (8), bag 2 Linen (4), bag 3 Mageweave (10), bag 4 Wool (6). The new bag is at (o.at or backpack 1).
local function bagBoot(o)
	o = o or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0], M.sizes[1], M.sizes[2], M.sizes[3], M.sizes[4], M.sizes[5] = 4, 8, 4, 10, 6, 0
	local newID = o.new or RUNE
	local at = o.at or { 0, 1 }
	M.put(at[1], at[2], bagItem(newID))
	M.put(1, 1, ore()); M.put(1, 2, ore()); M.put(1, 3, ore())      -- the Silk Bag: 3 used
	M.put(2, 1, ore())                                              -- the Linen Bag: 1 used (2 with the new bag inside)
	M.put(4, 1, ore()); M.put(4, 2, ore())                          -- the Wool Bag: 2 used
	if o.fill then o.fill(M) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", debug = true } } }
	local equipped = o.equipped or { [20] = SILK, [21] = LINEN, [22] = MAGE, [23] = WOOL }
	_G.GetInventoryItemID = function(_, inv) return equipped[inv] end
	local clock = 100
	_G.GetTime = function() return clock end
	local st = { cur = nil, puts = {}, places = 0 }
	local function unlockSoon(it) C_Timer.After(0, function() it.locked = nil end) end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(id) local num = tonumber(tostring(id):match("item:(%d+)")) or id; if NAMES[num] then return NAMES[num] end return realInfo(id) end
	C_Container.PickupContainerItem = function(bag, slot)
		local it = M.bags[bag] and M.bags[bag][slot]
		if not st.cur then
			if it then st.cur = { id = it.id, bag = bag, slot = slot }; it.locked = true; M.cursorItem = it.id end
			return
		end
		if it then return end
		st.places = st.places + 1
		local moved = M.bags[st.cur.bag][st.cur.slot]
		M.bags[bag] = M.bags[bag] or {}
		M.bags[bag][slot] = moved; M.bags[st.cur.bag][st.cur.slot] = nil
		moved.locked = true; unlockSoon(moved)
		st.cur = nil; M.cursorItem = nil
	end
	_G.ClearCursor = function()
		if st.cur then local it = M.bags[st.cur.bag][st.cur.slot]; if it then it.locked = nil end end
		st.cur = nil; M.cursorItem = nil
	end
	_G.PutItemInBag = function(inv)
		st.puts[#st.puts + 1] = inv
		if not st.cur then return end
		local new = M.bags[st.cur.bag][st.cur.slot]
		local x = inv - 19
		if st.cur.bag == x then return end                       -- a bag stored in the bag it would replace: refused
		local used = 0
		for _, it in pairs(M.bags[x] or {}) do if it ~= new then used = used + 1 end end
		if used > (SIZE[new.id] or 0) then return end            -- too small for what the old bag holds: refused
		local old = equipped[inv]
		equipped[inv] = new.id
		M.sizes[x] = SIZE[new.id]
		local yb, ys = st.cur.bag, st.cur.slot
		M.bags[yb][ys] = nil
		st.cur = nil; M.cursorItem = nil
		local ob = bagItem(old); ob.locked = true; M.put(yb, ys, ob); unlockSoon(ob)
	end
	local r = { n = n, M = M, st = st, equipped = equipped, H = n.SwapHint, at = at, newID = newID }
	function r.tick(dt) clock = clock + dt end
	function r.run() for _ = 1, 40 do M.runTimers() end end
	-- the game's side of a right-click on the bag: its slot locks and unlocks with nothing on the cursor, then the red line
	function r.lock() M.bags[at[1]][at[2]].locked = true; M.fire("ITEM_LOCK_CHANGED", at[1], at[2]) end
	function r.unlock() M.bags[at[1]][at[2]].locked = nil; M.fire("ITEM_LOCK_CHANGED", at[1], at[2]) end
	function r.red() M.fire("UI_ERROR_MESSAGE", 21, "No equipment slot is available for that item.") end
	function r.rightClick() r.lock(); r.unlock(); r.red(); M.runTimers() end
	function r.menu()
		local m = n.menuFrame
		if not (m and m:IsShown()) then return nil end
		local rows = {}
		for _, x in ipairs(m.rows) do if x:IsShown() then rows[#rows + 1] = x end end
		return rows
	end
	function r.texts() local t = {}; for _, x in ipairs(r.menu() or {}) do t[#t + 1] = plain(x.text.text) end; return table.concat(t, " | ") end
	function r.pick(text) for _, x in ipairs(r.menu() or {}) do if plain(x.text.text):find(text, 1, true) then return x end end end
	function r.where(id) for bag = 0, 4 do for s, it in pairs(M.bags[bag] or {}) do if it.id == id then return bag, s end end end end
	return r
end


local function said(M, from, what) for i = from, #M.log do if plain(M.log[i]):find(what, 1, true) then return true end end return false end
local function press(row) row:GetScript("OnClick")(row) end   -- the menu's own click, as a player makes it

------------------------------------------------------------------------
-- B5-1: an offer belongs to the attempt it was made under
------------------------------------------------------------------------
do
	local function second(r)
		r.M.put(0, 2, bagItem(TINY))
		return function() r.M.bags[0][2].locked = true; r.M.fire("ITEM_LOCK_CHANGED", 0, 2) end,
			function() r.M.bags[0][2].locked = nil; r.M.fire("ITEM_LOCK_CHANGED", 0, 2) end
	end
	-- the report's case: A is refused and its menu is waiting for the next frame; B is clicked, with no error of its own
	local r = bagBoot()
	local lockB, unlockB = second(r)
	r.lock(); r.unlock(); r.red()
	check(r.menu() == nil and #r.st.puts == 0, "(A refused: its menu waits for the next frame)")
	lockB(); unlockB()
	r.run()
	check(r.menu() == nil and r.H.offered == nil, "another bag clicked before that frame: the menu for the first never opens: " .. r.texts())
	check(#r.st.puts == 0 and r.equipped[21] == LINEN, "and nothing can be swapped from it")
	-- the newer bag has its own refusal: its menu, either order, and a pick swaps that bag
	for _, order in ipairs({ "error after the release", "error before the release" }) do
		r = bagBoot()
		lockB, unlockB = second(r)
		r.lock(); r.unlock(); r.red()
		if order == "error after the release" then lockB(); unlockB(); r.red() else lockB(); r.red(); unlockB() end
		r.run()
		check(r.H.offered and r.H.offered.id == TINY and r.texts():find("^Swap in Tiny Pouch for:") ~= nil and #r.st.puts == 0, "the newer bag refused too (" .. order .. "): the menu is its own, and only its own")
		press(r.pick("Mageweave Bag")); r.run()
		check(r.equipped[22] == TINY and #r.st.puts == 1 and r.equipped[21] == LINEN and select(1, r.where(RUNE)) == 0, "(" .. order .. ") a pick swaps the newer bag in, once; the first bag stays where it was")
	end
	-- the same bag clicked again before the frame, this time without an error: the earlier refusal's menu is void
	r = bagBoot()
	r.lock(); r.unlock(); r.red()
	r.lock(); r.unlock()
	r.run()
	check(r.menu() == nil, "the same bag clicked again before the frame, with no error this time: no menu from the earlier click")
	-- a menu already showing, and a pick: an offer from an earlier attempt is refused there too, whatever closed or
	-- didn't close the menu (the withdrawal is switched off here to show the pick's own check)
	r = bagBoot()
	lockB, unlockB = second(r)
	r.rightClick()
	local row = r.pick("Linen Bag")
	local retire = r.H.RetireOffer
	r.H.RetireOffer = function() end
	lockB(); unlockB(); r.M.runTimers()
	r.H.RetireOffer = retire
	check(r.menu() ~= nil and r.H.offered ~= nil, "(the menu left up on purpose after another bag was clicked)")
	local from = #r.M.log + 1
	press(row); r.run()
	check(#r.st.puts == 0 and r.equipped[21] == LINEN and said(r.M, from, "Your bags changed while the menu was open, so nothing was swapped."), "a pick from an earlier attempt's menu swaps nothing, and says so")
	-- controls: a current offer swaps once through the menu's own click; the withdrawal still closes an open menu
	r = bagBoot()
	r.rightClick()
	press(r.pick("Linen Bag")); r.run()
	check(#r.st.puts == 1 and r.equipped[21] == RUNE and r.M.cursorItem == nil and not r.H.swapping, "control: a current offer swaps once")
	r = bagBoot()
	lockB, unlockB = second(r)
	r.rightClick()
	lockB(); r.run()
	check(r.menu() == nil and r.H.offered == nil, "control: another bag locking still closes a menu that is showing")
	check((r.n.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- B5-2: a column that fails part way through a sort
------------------------------------------------------------------------
do
	noPawn()
	local ids = { 1028, 1005, 1006, 1008, 1007, 1011, 1013, 1020, 1006, 1010, 1016, 1004, 1018, 1021, 1028, 1009, 1021, 1001, 1022, 1003, 1008, 1005 }
	local n, M, V = boot()
	local key = "x:flaky"
	local fail, calls, asked = true, 0, {}
	check(BagSmith.API.RegisterColumn("Flaky", "flaky", function(d)
		calls = calls + 1
		asked[d.slotID] = (asked[d.slotID] or 0) + 1
		if fail and d.itemID % 4 == 0 then error("the provider failed for this item") end
		return "OK", d.itemID
	end) == true, "(a column whose answers fail for some items)")
	local d = n.Columns:Get(key)
	local function records() local t = {}; for i, id in ipairs(ids) do t[i] = { name = string.char(64 + i), itemID = id, bag = 0, slot = i } end; return t end
	local function sorter() return n:CurrentSorter({ colSort = { key = key, dir = "desc" } }) end
	local function ordered(rs, cmp) for i = 1, #rs - 1 do if cmp(rs[i + 1], rs[i]) then return false end end return true end

	-- the production comparator, sorting the report's records
	local rs, cmp = records(), sorter()
	local ok, err = pcall(table.sort, rs, cmp)
	check(ok, "the sort finishes when the column fails for the fifth time part way through: " .. tostring(err))
	check(d.off == true and d.fails == 5, "five failures switch the column off, and no more are counted (" .. tostring(d.fails) .. ")")
	check(ordered(rs, cmp), "and what it leaves is in order by the answers that comparator was given")
	local most = 0
	for _, c in pairs(asked) do if c > most then most = c end end
	check(most == 1 and calls <= #ids, "each record was asked once in that sort, however often it was compared (" .. calls .. " calls for " .. #ids .. " records)")
	local settled = calls
	rs = records()
	check(pcall(table.sort, rs, sorter()) and calls == settled, "a second sort, the column off: fine, and the addon isn't called")
	-- one comparator's answers do not outlive it: healthy again, a new sort is by the new answers
	fail, d.fails, d.off, d.cache, d.cached = false, 0, nil, {}, 0
	rs = records()
	check(pcall(table.sort, rs, sorter()) and rs[1].itemID == 1028 and rs[#rs].itemID == 1001, "healthy again, a new sort is right: largest first")
	local up = n:CurrentSorter({ colSort = { key = key, dir = "asc" } })
	rs = records(); table.sort(rs, up)
	check(rs[1].itemID == 1001 and rs[#rs].itemID == 1028 and ordered(rs, up), "and smallest first")

	-- through the real view: the list sorted by the column, the column failing as the list is laid out
	n:Set("grp", "none"); n:Set("view", "list"); n:Set("mergeStacks", false)
	M.bags[0] = {}; M.sizes[0] = #ids
	for i, id in ipairs(ids) do M.put(0, i, { id = 2000 + (id - 1000) * 101 + i * 4, name = string.char(64 + i), q = 1, class = 4, subclass = 1, price = 5, equip = "INVTYPE_HEAD" }) end
	n:Scan()
	if not n.IndexOf(n.db.cols, key) then table.insert(n.db.cols, key) end
	V.st.colSort = { key = key, dir = "desc" }
	d.fails, d.off, d.cache, d.cached, fail = 0, nil, {}, 0, true
	local before = #(n.errorLog or {})
	n:RefreshViews(true)
	check(#(n.errorLog or {}) == before and (n.errors or 0) == 0, "the list's own redraw is not interrupted: " .. tostring(n.errorLog and n.errorLog[#n.errorLog]))
	check(d.off == true, "(the column switched itself off during it)")
	local shownRows = 0
	for _, b in ipairs(V.used or {}) do if b:IsShown() and b.hasItem then shownRows = shownRows + 1 end end
	check(shownRows == #ids, "every item is still in the list (" .. shownRows .. ")")
	M.runTimers(); M.runTimers()
	check(not col(V, key) and not V.headerLabels[key]:IsShown(), "and on the next frame the column and its heading are gone, with no other action")
	for _, b in ipairs(V.used or {}) do if b:IsShown() and b["colX_" .. key] and b["colX_" .. key]:IsShown() then shownRows = -1 end end
	check(shownRows == #ids, "no row is left showing a cell for it")
	check(n.IndexOf(n.db.cols, key) ~= nil, "the player's tick is kept")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- the same when the failures come while drawing, not sorting: off, and the windows and an open Bag Columns page
	-- are told (nothing else here would redraw that page)
	noPawn()
	local n, M, V = boot()
	BagSmith.API.RegisterColumn("Broken", "broken", function() error("boom") end)
	local Pn = n.SettingsPanel
	Pn:Show(); M.runTimers(); Pn:ShowPage("bagcols"); M.runTimers()
	local function listRow()
		for _, l in ipairs(Pn.pools.list or {}) do if l:IsShown() then for _, x in ipairs(l.rows) do if x:IsShown() and x.id == "x:broken" then return x end end end end
	end
	check(listRow() ~= nil and listRow().box:IsEnabled() and not listRow().box:GetChecked(), "(Bag Columns open: the column's row is live, unticked)")
	local told, realChanged = 0, n.Columns.AvailabilityChanged
	n.Columns.AvailabilityChanged = function(self, key) if key == "x:broken" then told = told + 1 end; return realChanged(self, key) end
	-- the player ticks it: the windows draw it, and its answers fail
	n.db.cols[#n.db.cols + 1] = "x:broken"
	n:Fire("SETTINGS_CHANGED", "cols"); n:RefreshViews(true)
	check(n.Columns:Get("x:broken").off == true and told == 1, "five failures while drawing: off, and the layout is told once (" .. told .. ")")
	M.runTimers()
	n.Columns.AvailabilityChanged = realChanged
	check(not col(V, "x:broken") and (n.errors or 0) == 0, "on the next frame the column has left the row by itself")
	local r = listRow()
	check(r ~= nil and not r.box:IsEnabled() and r.box:GetChecked() and r.tip == "This column ran into errors, so it is off until you reload.", "and the open Bag Columns page greys its row, still ticked, saying why")
	Pn:Hide()
end
do
	-- BagSmith's own columns and Pawn's sort as before (their answers never fail; the comparator asks Pawn's once too)
	local P = fakePawn()
	local n, M, V = boot()
	n:Set("grp", "none")
	tick(n, M, "pawn", true)
	local h = V.headerLabels.pawn
	h:GetScript("OnClick")(h); M.runTimers()
	check(names(V) == "Better Belt | Slight Gloves | First Ring | Level Only | Linen Cloth | Old Belt", "sorted by Pawn: as before: " .. names(V))
	n:SortByColumn(V.st, "n"); n:RefreshViews(true); M.runTimers()
	check(names(V):find("^Better Belt | First Ring | Level Only") ~= nil, "sorted by name: as before: " .. names(V))
	check((n.errors or 0) == 0, "no errors")
	noPawn()
end

------------------------------------------------------------------------
-- The version
------------------------------------------------------------------------
do
	check(slurp("BagSmith/BagSmith.toc"):find("\n## Version: 1%.12%.0"), "the TOC version is 1.12.0's (the exact one is pinned in tests/run.lua)")
	local top = slurp("BagSmith/CHANGELOG.md"):match("^## 1%.12%.0\n(.-)\n## 1%.11%.0\n") or ""
	local entries = 0
	for _ in ("\n" .. top):gmatch("\n%- ") do entries = entries + 1 end
	check(entries == 5, "the changelog's 1.12.0 section is unchanged: these are fixes to things 1.12 itself adds")
end
