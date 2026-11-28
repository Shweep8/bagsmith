-- ======== 1.12.0-beta1 (Shweep, 27 Nov: "let's begin 1.12.0 first beta") ========
-- The first of 1.12's scope as he settled it on 26 Nov: columns in List view that show another addon's answer about
-- an item, with Pawn's as the first, and a By Bag section's heading showing its bag's icon.
--   A registered column (Core/Columns.lua) behaves as BagSmith's own do: listed in Bag Columns and Bank Columns,
--   unticked until ticked, then ordered, resized, set aside by a narrow window and sorted by its header.
--   Pawn's shows how much of an upgrade an item is ("+31%"), "Upgrade" when Pawn gives no number, nothing otherwise.
--   It reads the answers the arrows already have, so Pawn is asked once per item, not twice.
-- Pawn here is a fake with the three functions BagSmith calls, shaped as Pawn 2.14.9 describes them in Pawn.lua.

-- (by design since 1.12.0-beta2, Shweep's feedback on this beta) Four things this set pinned have changed, and its
-- checks follow them where they stand: a cell is the arrow and the number, or the arrow alone where beta1 wrote
-- "Upgrade" (ARROW and arrowed() below; the mock has no atlas, so the arrow is Pawn's own file); the tooltip is "Pawn's
-- upgrade amount."; the column's default place is right after Item, not last; its starting width is 64, not 58.
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

------------------------------------------------------------------------
-- 1. Nothing changes until the column is ticked
------------------------------------------------------------------------
do
	local P = fakePawn()
	local n, M, V = boot()
	local d = n.Columns:Get("pawn")
	check(d ~= nil and d.label == "Pawn" and d.owner == "Pawn" and d.numeric == true and d.width == 64 and n.COL_LABEL.pawn == "Pawn", "the Pawn column is registered: its label, a number column, 64 px to start")
	check(not n.IndexOf(n.db.cols, "pawn") and not n.IndexOf(n.db.bankCols, "pawn"), "a new profile has it unticked, in the bags and in the bank")
	check(n.db.colOrder[n.IndexOf(n.db.colOrder, "n") + 1] == "pawn" and n.db.bankColOrder[n.IndexOf(n.db.bankColOrder, "n") + 1] == "pawn", "it is right after Item in each column order")
	local a = n.db.colAside
	check(a[n.IndexOf(a, "pawn") - 1] == "bd" and a[n.IndexOf(a, "pawn") + 1] == "fv" and n.db.bankColAside[n.IndexOf(n.db.bankColAside, "pawn") + 1] == "fv",
		"and in Narrow Windows' lists after Bind, before the three icon columns")
	check(keys(V) == "c,n,t,bd,v,w,age,fv,cc,jk", "unticked: the List view's columns are what they were: " .. keys(V))
	check(row(V, 9802) ~= nil and row(V, 9802).colX_pawn == nil and row(V, 9802).xcols == nil, "and no row has made a cell for it")
	check(not V.headerLabels.pawn:IsShown(), "its heading exists and is hidden")
	check(P.asks == 6, "Pawn was asked once for each of the six items (its arrows): " .. P.asks)
	check(P.amountCalls == 0, "and never for an amount while the column is off")
	local up = row(V, 9802)
	check(up.pawnArrow and up.pawnArrow:IsShown(), "(the arrow is on the upgrade, as before)")
	check((n.errors or 0) == 0, "no errors")

	---- 2. Ticked: what each cell says
	tick(n, M, "pawn", true)
	check(keys(V) == "c,n,pawn,t,bd,v,w,age,fv,cc,jk", "ticked: Pawn joins the row right after Item: " .. keys(V))
	check(col(V, "pawn").colW == 64 and col(V, "pawn").numeric == true and col(V, "pawn").fs == "colX_pawn", "64 px wide, right-aligned, in its own cell")
	local t, fs = cell(V, 9802)
	check(t == arrowed("+31%"), "an upgrade for two scales shows the larger, rounded: " .. tostring(t))
	check(fs:IsShown() and fs.justifyH == "RIGHT" and fs.textColor[1] == 0.1 and fs.textColor[2] == 1 and fs.textColor[3] == 0.1, "right-aligned, in the game's green")
	check(cell(V, 9804) == arrowed(), "nothing in the slot to compare with (Pawn's huge number): the arrow, no number")
	check(cell(V, 9805) == arrowed(), "a higher item level only (Pawn gives no list): the arrow alone")
	check(cell(V, 9806) == arrowed("+1%"), "under half a percent still reads as an upgrade: +1%")
	check(cell(V, 9801) == "" and cell(V, 2589) == "", "not an upgrade, and not gear: empty")
	check(P.asks == 6, "ticking it asked Pawn nothing more: the column reads what the arrows know (" .. P.asks .. ")")
	check(P.amountCalls == 4 and P.rescans == 0, "the amount was asked once for each of the four upgrades, without a rescan: " .. P.amountCalls)
	n:RefreshViews(true); M.runTimers()
	check(P.asks == 6 and P.amountCalls == 4, "and a redraw asks for neither again")
	local h = V.headerLabels.pawn
	check(h:IsShown() and h.text.text == "Pawn" and h.text.justifyH == "RIGHT", "the heading: Pawn, right-aligned like the cells")
	h:GetScript("OnEnter")(h)
	local tip = table.concat(GameTooltip.lines or {}, " | ")
	check(GameTooltip.owner == h and tip:find("Pawn's upgrade amount.", 1, true) ~= nil,
		"its tooltip says what the column shows: " .. tip)
	h:GetScript("OnLeave")(h)

	---- 3. Sorting by it (Sections: All, so the whole list is one run)
	n:Set("grp", "none"); n:RefreshViews(true); M.runTimers()
	h:GetScript("OnClick")(h); M.runTimers()
	check(V.st.colSort.key == "pawn" and V.st.colSort.dir == "desc", "a click on the heading sorts by it, largest first")
	check(names(V) == "Better Belt | Slight Gloves | First Ring | Level Only | Linen Cloth | Old Belt",
		"numbered upgrades by amount, then upgrades without a number, then the rest, by name: " .. names(V))
	h:GetScript("OnClick")(h); M.runTimers()
	check(V.st.colSort.dir == "asc" and names(V):find("^Linen Cloth | Old Belt | First Ring | Level Only | Slight Gloves | Better Belt$") ~= nil, "a second click turns it round: " .. names(V))
	check(P.asks == 6 and P.amountCalls == 4, "sorting asks Pawn nothing")
	V.st.colSort = nil; n:RefreshViews(true); M.runTimers()

	---- 4. Its width, and a narrow window
	n.db.colWidths.pawn = 90; n:RefreshViews(true)
	check(col(V, "pawn").colW == 90, "a dragged width is used")
	n.db.colWidths.pawn = nil
	V.RowWidth = function() return 520 end
	local plan = V:ColumnPlan()
	check(table.concat(plan.dropped, ",") == "t" and col(V, "pawn") ~= nil, "a narrow window sets columns aside in their order: Type first, Pawn's still there (" .. table.concat(plan.dropped, ",") .. ")")
	local savedAside = n.db.colAside
	n.db.colAside = { "pawn", "t" }
	plan = V:ColumnPlan()
	check(table.concat(plan.dropped, ",") == "pawn" and not col(V, "pawn") and col(V, "t") ~= nil, "put first in Narrow Windows, Pawn's is the one set aside: " .. table.concat(plan.dropped, ","))
	V.RowWidth = function() return 900 end
	check(col(V, "pawn") ~= nil, "and a wider window brings it back")
	-- the window's narrowest width: every column ticked, none set aside
	local all = { "c", "t", "bd", "v", "w", "age", "fv", "cc", "jk", "il", "rq", "sl" }
	n.db.cols = all; n.db.colAside = {}
	local without = n.View.MinWidthFor(false)
	n.db.cols[#n.db.cols + 1] = "pawn"
	local _, base = n.View.MinWidthFor(false)
	check(without > base and n.View.MinWidthFor(false) == without + 30, "kept out of Narrow Windows it counts 30 px toward the window's narrowest width, like any column: " .. without .. " to " .. n.View.MinWidthFor(false))
	n.db.colAside = { "pawn" }
	check(n.View.MinWidthFor(false) == without, "and set aside it counts nothing")
	n.db.colAside = {}
	_G.PawnCommon.ShowBagUpgradeAdvisor = false
	check(n.View.MinWidthFor(false) == without, "nor does it while it can't show (Pawn's advisor off)")
	_G.PawnCommon.ShowBagUpgradeAdvisor = true
	-- The 1.6.0 audits' promise, with Pawn's column among the rest: at the window's own narrowest width, every column
	-- that is ticked, able to show and not set aside is in the row, the row fits, and no column is under its minimum.
	-- Every 37th of the 16,384 ways to set fourteen columns aside, widest saved widths, Pawn able to show and not.
	do
		local opt = {}
		for _, k in ipairs(n.db.colOrder) do if k ~= "n" then opt[#opt + 1] = k end end
		check(#opt == 14 and n.IndexOf(opt, "pawn") ~= nil, "(fourteen optional columns now, Pawn's among them)")
		n.db.cols = opt
		for _, k in ipairs(opt) do n.db.colWidths[k] = 400 end
		local realWidth = V.RowWidth
		for _, pawnOn in ipairs({ true, false }) do
			_G.PawnCommon.ShowBagUpgradeAdvisor = pawnOn
			local bad, tried, sawPawn = 0, 0, 0
			for mask = 0, 2 ^ #opt - 1, 37 do
				local aside = {}
				for i, k in ipairs(opt) do if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then aside[#aside + 1] = k end end
				n.db.colAside = aside
				local min = n.View.MinWidthFor(false)
				V.RowWidth = function() return min - 46 end
				local plan, width = V:ColumnPlan()
				local got, ok, edge = {}, true, 0
				for _, c in ipairs(plan) do got[c.key] = true; ok = ok and c.colW >= (c.key == "n" and 90 or 30); edge = c.colX + c.colW end
				ok = ok and edge <= width and got.n and got.c
				for _, k in ipairs(opt) do
					local mustShow = not n.IndexOf(aside, k) and (k ~= "ah") and (k ~= "pawn" or pawnOn)
					if mustShow and not got[k] then ok = false end
				end
				if got.pawn and not pawnOn then ok = false end
				if got.pawn then sawPawn = sawPawn + 1 end
				tried = tried + 1
				if not ok then bad = bad + 1 end
			end
			check(bad == 0 and tried == 443 and (sawPawn > 0) == pawnOn, ("Pawn %s: %d of %d layouts fit at the narrowest width with every kept column in the row"):format(pawnOn and "able to show" or "not able to show", tried - bad, tried))
		end
		V.RowWidth = realWidth
		_G.PawnCommon.ShowBagUpgradeAdvisor = true
		for _, k in ipairs(opt) do n.db.colWidths[k] = nil end
	end
	n.db.cols = { "c", "t", "bd", "v", "w", "age", "fv", "cc", "jk", "pawn" }; n.db.colAside = savedAside
	n:RefreshViews(true); M.runTimers()

	---- 5. Icons view and back
	n:Set("view", "icons"); n:RefreshViews(true); M.runTimers()
	local b = row(V, 9802)
	check(b.mode == "cell" and b.colX_pawn and not b.colX_pawn:IsShown() and b.xcols == nil, "Icons view: the cell is hidden")
	n:Set("view", "list"); n:RefreshViews(true); M.runTimers()
	check(cell(V, 9802) == arrowed("+31%") and select(2, cell(V, 9802)):IsShown(), "back in List view it shows again")

	---- 6. Unticked again
	tick(n, M, "pawn", false)
	b = row(V, 9802)
	check(not col(V, "pawn") and b.colX_pawn and not b.colX_pawn:IsShown() and b.xcols == nil and not V.headerLabels.pawn:IsShown(), "unticked: the column, its cells and its heading go")
	check((n.errors or 0) == 0, "no errors")
	noPawn()
end

------------------------------------------------------------------------
-- 2. Pawn answering late, and changing its mind
------------------------------------------------------------------------
do
	local P = fakePawn()
	P.answers[9802] = "wait"
	local n, M, V = boot({ db = { cols = { "c", "t", "bd", "v", "pawn" } } })
	check(n.IndexOf(n.db.cols, "pawn") ~= nil and col(V, "pawn") ~= nil, "a saved tick survives loading")
	check(cell(V, 9802) == "" and cell(V, 9806) == arrowed("+1%"), "an item Pawn can't answer for yet is empty; the others are filled")
	local a0 = P.asks
	n:RefreshViews(true)
	check(P.asks - a0 == 1, "a redraw asks Pawn about the waiting item once, for its arrow: the column asks nothing itself (" .. (P.asks - a0) .. ")")
	local h = V.headerLabels.pawn
	h:GetScript("OnClick")(h); M.runTimers()
	check(names(V):find("^Slight Gloves") ~= nil, "(sorted by Pawn: the unanswered item is not among the upgrades yet: " .. names(V) .. ")")
	P.answers[9802] = true
	M.runTimers(); M.runTimers()
	check(cell(V, 9802) == arrowed("+31%"), "when the answer comes in, the cell fills by itself")
	check(names(V):find("^Better Belt | Slight Gloves") ~= nil, "and the window, sorted by the column, sorts again: " .. names(V))
	V.st.colSort = nil; n:RefreshViews(true); M.runTimers()
	-- Pawn's answers forgotten (gear changed) while it is busy: the same item keeps what it showed
	local asked = P.asks
	for id in pairs(P.answers) do P.answers[id] = "wait" end
	n.Pawn:Forget(); n:RefreshViews(true)
	check(cell(V, 9802) == arrowed("+31%") and cell(V, 9806) == arrowed("+1%") and P.asks > asked, "answers forgotten and Pawn busy: each row keeps what it showed for the same item")
	P.answers[9802], P.answers[9806] = false, true
	P.pct[9806] = { { PercentUpgrade = 0.5 } }
	M.runTimers(); M.runTimers()
	check(cell(V, 9802) == "" and cell(V, 9806) == arrowed("+50%"), "the new answers replace them: no longer an upgrade, and a bigger one")
	-- Pawn's amount function failing, and missing
	n.Pawn:Forget(); P.fail = true
	for _, id in ipairs({ 9804, 9805 }) do P.answers[id] = true end
	n:RefreshViews(true); M.runTimers(); M.runTimers()
	check(cell(V, 9806) == arrowed() and (n.errors or 0) == 0, "Pawn's amount function failing: the arrow alone, and no error of BagSmith's")
	P.fail = nil
	n.Pawn:Forget(); _G.PawnGetItemData = nil
	n:RefreshViews(true); M.runTimers(); M.runTimers()
	check(cell(V, 9806) == arrowed() and cell(V, 9801) == "", "a Pawn without that function: the arrow alone for an upgrade, nothing otherwise")
	check(n.Pawn:ColumnText({ itemID = 9806, cached = true, link = row(V, 9806).rec.link }) == "" and n.Pawn:ColumnSort({ cached = true, link = "x" }) == 0,
		"another character's saved items get nothing, as with the arrows")
	check((n.errors or 0) == 0, "no errors")
	noPawn()
end

-- An item that arrives while the list is open: its row's first fill already has the cell, because the cell is filled
-- after the arrow has asked Pawn about the item (the other way round it would stay empty until the next redraw)
do
	local P = fakePawn()
	local n, M, V = boot({ db = { cols = { "c", "t", "pawn" }, fvccCols = true, jkCol = true } })
	check(cell(V, 9806) == arrowed("+1%"), "(setup) the column is showing")
	P.answers[9810] = true; P.pct[9810] = { { PercentUpgrade = 0.2 } }
	M.put(0, 7, { id = 9810, name = "New Helm", q = 2, class = 4, subclass = 1, price = 50, equip = "INVTYPE_HEAD" })
	local asked = P.asks
	M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
	check(row(V, 9810) ~= nil and cell(V, 9810) == arrowed("+20%"), "a newly looted upgrade shows its amount as its row appears: " .. tostring(cell(V, 9810)))
	check(P.asks - asked == 1, "with Pawn asked about it once (" .. (P.asks - asked) .. ")")
	check((n.errors or 0) == 0, "no errors")
	noPawn()
end

------------------------------------------------------------------------
-- 3. Without Pawn, and with its advisor off; the Settings pages
------------------------------------------------------------------------
do
	noPawn()
	local n, M, V = boot({ db = { cols = { "c", "t", "pawn" }, bankCols = { "c", "pawn" }, fvccCols = true, jkCol = true } })
	local ok, why = n.Columns:Available("pawn")
	check(ok == false and why == "Shows when Pawn is installed.", "without Pawn the column can't show, and says why")
	check(keys(V) == "c,n,t" and n.IndexOf(n.db.cols, "pawn") ~= nil and n.IndexOf(n.db.bankCols, "pawn") ~= nil, "it leaves the row; the tick is kept, for the bags and the bank")
	check(not n.Columns:Usable("pawn") and n.Columns:Usable("t") and not n.Columns:Usable("ah"), "(usable: not Pawn's without Pawn, nor AH Price without a price addon; Type always)")
	local Pn = n.SettingsPanel
	Pn:Show(); M.runTimers(); Pn:ShowPage("bagcols"); M.runTimers()
	local function listRow(id)
		for _, l in ipairs(Pn.pools.list or {}) do
			if l:IsShown() then for _, r in ipairs(l.rows) do if r:IsShown() and r.id == id then return r, l end end end
		end
	end
	local r = listRow("pawn")
	check(r ~= nil and plain(r.text.text) == "Pawn" and r.box:GetChecked() and not r.box:IsEnabled() and r.tip == "Shows when Pawn is installed.",
		"Bag Columns lists Pawn, ticked as saved, greyed, with the reason")
	local onPage = 0
	for _, l in ipairs(Pn.pools.list or {}) do if l:IsShown() then for _, x in ipairs(l.rows) do if x:IsShown() and x.id == "pawn" then onPage = onPage + 1 end end end end
	check(onPage == 1, "and the Narrow Windows list under it leaves it out while it can't show (" .. onPage .. ")")
	local ahRow = listRow("ah")
	check(ahRow ~= nil and not ahRow.box:IsEnabled(), "(as AH Price is without a price addon)")
	-- Pawn arrives; its advisor off, then on
	local P = fakePawn()
	_G.PawnCommon.ShowBagUpgradeAdvisor = false
	ok, why = n.Columns:Available("pawn")
	check(ok == false and why == "Pawn's bag upgrade advisor is off, so there is nothing to show. You can turn it on in Pawn's options.", "Pawn's own bag advisor off: nothing to show, and it says so")
	_G.PawnCommon.ShowBagUpgradeAdvisor = true
	Pn:ShowPage("bankcols"); M.runTimers(); Pn:ShowPage("bagcols"); M.runTimers()
	r = listRow("pawn")
	check(r.box:IsEnabled() and r.tip == "Pawn's upgrade amount.", "with Pawn, the row is live and says what the column shows")
	-- the Narrow Windows list under it has Pawn once it shows
	n.db.colAside = { "t", "pawn" }
	Pn:ShowPage("bankcols"); M.runTimers(); Pn:ShowPage("bagcols"); M.runTimers()
	local seen = 0
	for _, l in ipairs(Pn.pools.list or {}) do if l:IsShown() then for _, x in ipairs(l.rows) do if x:IsShown() and x.id == "pawn" then seen = seen + 1 end end end end
	check(seen == 2, "it is in both lists of the page: the columns, and Narrow Windows (" .. seen .. ")")
	-- unticking it from the page
	r = listRow("pawn")
	r.box:SetChecked(false); r.box:GetScript("OnClick")(r.box); M.runTimers()
	check(not n.IndexOf(n.db.cols, "pawn"), "unticking it there turns it off")
	Pn:ShowPage("bankcols"); M.runTimers()
	r = listRow("pawn")
	check(r ~= nil and r.box:GetChecked() and r.box:IsEnabled(), "Bank Columns has it too, with the bank's own tick")
	-- the Addon Sources card says where it is
	Pn:ShowPage("addons"); M.runTimers()
	local t = {}
	for _, w in ipairs(Pn.pools.text or {}) do if w:IsShown() then t[#t + 1] = w.text.text end end
	check(table.concat(t, " | "):find("In List view it can have a column of its own, showing how much of an upgrade each item is: tick Pawn in Settings > Bag Columns or Bank Columns.", 1, true) ~= nil,
		"Addon Sources' Pawn card says where the column is")
	Pn:Hide()
	check((n.errors or 0) == 0, "no errors")
	noPawn()
end

------------------------------------------------------------------------
-- 4. Saved settings: an existing profile, a damaged one
------------------------------------------------------------------------
do
	local P = fakePawn()
	-- a profile from 1.11, never touched in Narrow Windows: both lists are the default every profile had until now
	local OLD = { "t", "age", "v", "ah", "w", "sl", "rq", "il", "bd", "fv", "cc", "jk" }
	local function copy(t) local o = {}; for i, v in ipairs(t) do o[i] = v end; return o end
	local saved = { cols = { "c", "t", "v" }, colOrder = { "n", "c", "t", "bd", "v", "w", "age", "fv", "cc", "jk", "il", "rq", "sl", "ah" },
		colAside = copy(OLD), bankColAside = copy(OLD), colWidths = { t = 120 }, fvccCols = true, jkCol = true }
	local n, M, V = boot({ db = saved })
	check(table.concat(n.db.colOrder, ",") == "n,pawn,c,t,bd,v,w,age,fv,cc,jk,il,rq,sl,ah", "an existing profile: Pawn is added to its column order right after Item, the rest as it was")
	check(table.concat(n.db.cols, ",") == "c,t,v", "unticked: its columns are what they were")
	check(table.concat(n.db.colAside, ",") == "t,age,v,ah,w,sl,rq,il,bd,pawn,fv,cc,jk" and table.concat(n.db.bankColAside, ",") == "t,age,v,ah,w,sl,rq,il,bd,pawn,fv,cc,jk",
		"Narrow Windows' lists, still the untouched default: Pawn joins where a new profile has it, after Bind")
	check(n.db.pawnColAside == true, "and the profile remembers it did")
	check(keys(V) == "n,c,t,v", "the List view is unchanged: " .. keys(V))
	-- the player then takes it out of Narrow Windows; what was saved is loaded again
	local again = _G.BagSmithDB.profiles.Default
	check(type(again) == "table" and again.pawnColAside == true, "(the saved profile itself carries the mark)")
	table.remove(again.colAside, n.IndexOf(again.colAside, "pawn"))
	noPawn(); P = fakePawn()
	n = boot({ db = again, closed = true })
	check(table.concat(n.db.colAside, ",") == table.concat(OLD, ","), "a second load does not put it back, though the list is the old default again: " .. table.concat(n.db.colAside, ","))
	noPawn()
	-- a list the player changed in any way is theirs: loading leaves it exactly as saved (the 1.6.0-beta8 audit's rule)
	for _, c in ipairs({
		{ "one column unticked", { "t", "age", "v", "ah", "w", "sl", "rq", "il", "bd", "fv", "cc" } },
		{ "two columns swapped", { "age", "t", "v", "ah", "w", "sl", "rq", "il", "bd", "fv", "cc", "jk" } },
		{ "1.6.0's first default", { "t", "age", "v", "ah" } },
		{ "everything unticked", {} },
		{ "the default with something unknown after it", { "t", "age", "v", "ah", "w", "sl", "rq", "il", "bd", "fv", "cc", "jk", "zz" }, "t,age,v,ah,w,sl,rq,il,bd,fv,cc,jk" },
	}) do
		P = fakePawn()
		n = boot({ db = { colAside = copy(c[2]), bankColAside = copy(OLD), fvccCols = true, jkCol = true }, closed = true })
		check(table.concat(n.db.colAside, ",") == (c[3] or table.concat(c[2], ",")), "Narrow Windows, " .. c[1] .. ": left as saved, Pawn not added (" .. table.concat(n.db.colAside, ",") .. ")")
		check(n.IndexOf(n.db.bankColAside, "pawn") == 10, "(the bank's, untouched beside it, gets Pawn: each list on its own)")
		noPawn()
	end
	-- the player took it out of Narrow Windows afterwards: it stays out
	P = fakePawn()
	n = boot({ db = { colAside = { "t" }, pawnColAside = true, cols = { "c", "pawn" }, colWidths = { pawn = 9999, zz = 50 }, bankColWidths = { pawn = 44 } }, closed = true })
	check(table.concat(n.db.colAside, ",") == "t", "taken out of Narrow Windows by the player, it is not put back")
	check(n.db.colWidths.pawn == 400 and n.db.colWidths.zz == nil and n.db.bankColWidths.pawn == 44, "its saved width is checked like any column's (400 at most), and an unknown column's is dropped")
	noPawn()
	-- keys nothing knows are still dropped, and Pawn's is not doubled
	P = fakePawn()
	n = boot({ db = { cols = { "c", "pawn", "zz", "pawn", 7 }, colOrder = { "pawn", "n", "zz", "c" }, colAside = { "pawn", "pawn", "zz" }, pawnColAside = true, fvccCols = true, jkCol = true }, closed = true })
	check(table.concat(n.db.cols, ",") == "c,pawn", "a damaged column list keeps what is known, once: " .. table.concat(n.db.cols, ","))
	check(n.db.colOrder[1] == "pawn" and n.db.colOrder[2] == "n" and n.db.colOrder[3] == "c" and #n.db.colOrder == 15, "the player's order is kept, Pawn first where they put it")
	check(table.concat(n.db.colAside, ",") == "pawn", "and Narrow Windows likewise")
	check((n.errors or 0) == 0, "no errors")
	noPawn()
end

------------------------------------------------------------------------
-- 5. Global Inventory, and Dim Junk Items
------------------------------------------------------------------------
do
	local P = fakePawn()
	local n, M, V = boot({ db = { cols = { "c", "t", "bd", "pawn" }, dimJunk = true } })
	check(col(V, "pawn") ~= nil, "(setup) the column shows in the bags")
	-- an upgrade marked as junk: its text dims with the row, and comes back in its own color
	local b = row(V, 9802)
	n.Junk:Toggle(b.rec); n:RefreshViews(true); M.runTimers()
	b = row(V, 9802)
	local c = b.colX_pawn.textColor
	check(n.Junk:IsJunk(b.rec) and c[1] == n.Junk.DIM_TEXT[1] and c[2] == n.Junk.DIM_TEXT[2], "Dim Junk Items: a junk row's Pawn cell dims with the rest of the row")
	n.Junk:Toggle(b.rec); n:RefreshViews(true); M.runTimers()
	c = row(V, 9802).colX_pawn.textColor
	check(c[1] == 0.1 and c[2] == 1 and c[3] == 0.1 and cell(V, 9802) == arrowed("+31%"), "no longer junk: its green is back")
	V:SetGlobal(true); M.runTimers(); M.runTimers()
	check(n.ui.global and not col(V, "pawn"), "Global Inventory has no Pawn column: " .. keys(V))
	V:SetGlobal(false); M.runTimers(); M.runTimers()
	check(col(V, "pawn") ~= nil, "and your own bags have it back")
	check((n.errors or 0) == 0, "no errors")
	noPawn()
end

------------------------------------------------------------------------
-- 6. The registry itself: a second column, registered after the window was made
------------------------------------------------------------------------
do
	noPawn()
	local n, M, V = boot()
	local C = n.Columns
	local calls, boom = 0, false
	check(C:Register("pawn", { text = function() end }) == false and C:Register("c", { text = function() end }) == false and C:Register("n", { text = function() end }) == false,
		"a key that is taken, by a registered column or one of BagSmith's own, is refused")
	check(C:Register("zz", { label = "Zed" }) == false and C:Register("", { text = function() end }) == false and C:Register(7, { text = function() end }) == false, "and so is a column with no text function, or no key")
	check(C:Register("zz", { label = "Zed", owner = "Test", width = 5000, color = { 1, 0.5, 0 }, tip = "What Zed knows.",
		text = function(rec) calls = calls + 1; if boom then error("zed broke") end; if rec.itemID == 9801 then return nil end; if rec.itemID == 2589 then return false end; return "z" .. rec.itemID end,
		sort = function(rec) return rec.itemID end }) == true, "a column registers")
	check(C:Get("zz").width == 400 and C:Get("zz").numeric == false and n.COL_LABEL.zz == "Zed" and C:Field("zz") == "colX_zz", "its width is kept within a column's limits; left-aligned unless it asks")
	check(not V.headerLabels.zz, "(the window was made before it: no heading yet)")
	n.db.cols[#n.db.cols + 1] = "zz"; n.db.colOrder[#n.db.colOrder + 1] = "zz"
	n:RefreshViews(true); M.runTimers()
	check(col(V, "zz") ~= nil and col(V, "zz").colW == 400 and not col(V, "zz").numeric, "ticked, it is in the row at its width")
	local h = V.headerLabels.zz
	check(h ~= nil and h:IsShown() and h.text.text == "Zed" and h.text.justifyH == "LEFT", "its heading is made the first time it is laid out")
	local t, fs = cell(V, 9802, "colX_zz")
	check(t == "z9802" and fs.justifyH == "LEFT" and fs.textColor[1] == 1 and fs.textColor[2] == 0.5, "its cells show its text, in its color")
	check(cell(V, 9801, "colX_zz") == "" and cell(V, 2589, "colX_zz") == "", "nil (not ready) on a row's first fill, and false: empty")
	h:GetScript("OnClick")(h); M.runTimers()
	check(names(V):find("^Slight Gloves | Level Only | First Ring | Better Belt | Old Belt | Linen Cloth$") ~= nil, "it sorts by the number it gives: " .. names(V))
	V.st.colSort = nil
	-- failing: empty cells, then off for the session, and out of the row
	boom = true
	local before = n.errors or 0
	n:RefreshViews(true); M.runTimers()
	check(C:Get("zz").off == true and (n.errors or 0) == before, "a column whose text keeps failing is switched off, with no error of BagSmith's")
	local ok, why = C:Available("zz")
	check(ok == false and why == "This column ran into errors, so it is off until you reload.", "it says so")
	n:RefreshViews(true); M.runTimers()
	check(not col(V, "zz") and not V.headerLabels.zz:IsShown() and not row(V, 9802).colX_zz:IsShown(), "and it leaves the row")
	local c2 = calls
	n:RefreshViews(true); M.runTimers()
	check(calls == c2, "its function is not called again")
	check(C:SortValue("zz", { itemID = 5 }) == 0 and C:Value("zz", { itemID = 5 }) == "" and C:SortValue("nope", {}) == 0, "a column that is off, or unknown, sorts as nothing and shows nothing")
	check((n.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- 7. A By Bag section's heading shows its bag's icon
------------------------------------------------------------------------
do
	noPawn()
	local n, M, V = boot({ bag1 = true })
	local function headers()
		local list = {}
		for _, h in pairs(n.Buttons.lanes[V.child] or {}) do if h:IsShown() and h.laneId then list[#list + 1] = h end end
		return list
	end
	local function header(id) for _, h in ipairs(headers()) do if h.laneId == id then return h end end end
	check(n:BagIcon(0) == "Interface\\Buttons\\Button-Backpack-Up" and n:BagIcon(n.KEYRING) == nil and n:BagIcon("x") == nil, "the backpack has its own picture; the keyring and a non-bag have none")
	-- the mock gives a picture for inventory slot 25 only; give bag 1's slot (20) one too
	local oldTex = _G.GetInventoryItemTexture
	_G.GetInventoryItemTexture = function(unit, inv) if inv == 20 then return 133633 end return oldTex(unit, inv) end
	check(n:BagIcon(1) == 133633 and n:BagIcon(2) == nil, "a worn bag's is its item's icon; an empty bag slot has none")
	_G.GetInventoryItemTexture = function() return 999 end
	check(n:BagIcon(n.KEYRING) == nil and (n.BANK == nil or n:BagIcon(n.BANK) == nil) and n:BagIcon(1) == 999, "the keyring and the bank's own slots never have one, whatever the game says of their slot")
	_G.GetInventoryItemTexture = function(unit, inv) if inv == 20 then return 133633 end return oldTex(unit, inv) end
	n:Set("grp", "type"); n:RefreshViews(true); M.runTimers()
	local any = false
	for _, h in ipairs(headers()) do if h.setIcon and h.setIcon:IsShown() then any = true end end
	check(#headers() > 0 and not any, "By Section: no heading has a bag's icon")
	n:Set("grp", "bag"); n:RefreshViews(true); M.runTimers()
	local h0, h1 = header("bag:0"), header("bag:1")
	check(h0 ~= nil and h1 ~= nil, "(By Bag: a heading for the backpack and one for bag 1)")
	check(h0.setIcon and h0.setIcon:IsShown() and h0.setIcon.texture == "Interface\\Buttons\\Button-Backpack-Up" and h0.textX == 42, "the backpack's heading: its icon, the name moved over for it")
	check(h1.setIcon and h1.setIcon:IsShown() and h1.setIcon.texture == 133633 and h1.textX == 42, "bag 1's heading: the bag's own icon")
	check(not plain(h0.text.text):find("Gear Set:") and plain(h0.text.text) ~= "", "the name is the bag's, as before: " .. plain(h0.text.text))
	-- a bag slot the game gives no picture for: text only, where it was
	_G.GetInventoryItemTexture = function() return nil end
	n:RefreshViews(true); M.runTimers()
	h0, h1 = header("bag:0"), header("bag:1")
	check(h0.setIcon:IsShown() and not (h1.setIcon and h1.setIcon:IsShown()) and (h1.textX or 20) == 20, "no picture for the slot: that heading is text only, the backpack keeps its own")
	_G.GetInventoryItemTexture = function() error("not now") end
	check(n:BagIcon(1) == nil, "the game's call failing gives no icon, not an error")
	-- another character's saved bags: their headings stay text (the icons would be your own bags')
	_G.GetInventoryItemTexture = function() return 133633 end
	local other = "Someone - Elsewhere"
	_G.BagSmithDB.cache[other] = { name = "Someone", realm = "Elsewhere", gold = 5, bags = { ["0"] = { size = 16, free = 15 }, ["1"] = { size = 8, free = 7 } },
		items = { { bag = 0, slot = 1, itemID = 4306, count = 9, name = "Silk Cloth", quality = 1 }, { bag = 1, slot = 1, itemID = 2589, count = 3, name = "Linen Cloth", quality = 1 } } }
	n.ui.owner = other; n:RefreshViews(true); M.runTimers()
	local theirs, withIcon = 0, 0
	for _, h in ipairs(headers()) do
		if tostring(h.laneId):find("^bag:") then theirs = theirs + 1; if h.setIcon and h.setIcon:IsShown() then withIcon = withIcon + 1 end end
	end
	check(V:IsCached() and theirs >= 1 and withIcon == 0, "another character's saved bags: By Bag headings without icons (" .. theirs .. " headings, " .. withIcon .. " with one)")
	n.ui.owner = nil; n:RefreshViews(true); M.runTimers()
	check(header("bag:0").setIcon:IsShown(), "and your own have them back")
	_G.GetInventoryItemTexture = oldTex
	n:Set("grp", "type"); n:RefreshViews(true); M.runTimers()
	any = false
	for _, h in ipairs(headers()) do if h.setIcon and h.setIcon:IsShown() then any = true end end
	check(not any, "back to By Section: the icons are gone from the reused headings")
	check((n.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- 8. The changelog, the version and the load order
------------------------------------------------------------------------
do
	local log = slurp("BagSmith/CHANGELOG.md")
	local top = log:match("^## 1%.12%.0\n(.-)\n## 1%.11%.0\n")
	check(top ~= nil, "the changelog opens with 1.12.0, above 1.11.0")
	top = (top or ""):gsub("\n  ", " ")
	check(top:find("\nNew:\n- A Pawn column for List view (Settings > Bag Columns or Bank Columns, with Pawn installed). Beside a green arrow it shows how much of an upgrade Pawn says each item is for you, such as +15%, or the arrow alone when Pawn gives no number. Click its heading to sort by it. It starts unticked, right after Item in the list, so your columns stay as they are until you tick it.", 1, true) ~= nil,
		"New: the Pawn column, where it is and what it shows")
	check(top:find("\n- With Sections: By Bag, each bag's section shows that bag's icon beside its name.", 1, true) ~= nil, "New: the bag's icon on By Bag sections")
	check(not top:find("\226\128\148") and not top:find("\226\128\147"), "no em or en dashes")
	local toc = slurp("BagSmith/BagSmith.toc")
	check(toc:find("\n## Version: 1%.12%.0"), "the TOC version is 1.12.0's (the exact one is pinned in tests/run.lua)")
	local a, b, c = toc:find("\nCore\\Settings.lua\n", 1, true), toc:find("\nCore\\Columns.lua\n", 1, true), toc:find("\nCore\\Pawn.lua\n", 1, true)
	check(a and b and c and a < b and b < c, "Core/Columns.lua loads after the settings and before Pawn's module, which registers the first column")
	-- (by design since 1.12.0-beta3: columns from other addons are offered now, as API 1.2; in beta1 this read 1.1)
	check(slurp("BagSmith/Core/API.lua"):find("local API = { VERSION = { major = 1, minor = 2 } }", 1, true) ~= nil, "the public API is 1.2, which offers columns from other addons")
end
