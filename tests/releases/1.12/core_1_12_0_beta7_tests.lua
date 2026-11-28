-- ======== 1.12.0-beta7 (Shweep, 28 Nov: "build beta  7") ========
-- The third audit (of beta6) cleared the code: both beta5 blockers closed, no new blocker, "advance to the Forever
-- release check". Its one note, Low, B6-A1: a window sorted by a registered column that then becomes unavailable kept
-- that sort. The column left the row, the Sort button still named it, and the list fell to name order. Reproduced on
-- beta6 with the auditor's probe (9 pass, 2 fail there; 11 pass here, unmodified).
-- Now: while the column is away the window uses its configured sort and says so; the choice is kept for its return.
-- The fixtures are the beta1 set's.

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


local function label(V) return tostring(V.btnSort.label.text) end

------------------------------------------------------------------------
-- An addon's column that switches itself off while the list is sorted by it
------------------------------------------------------------------------
do
	noPawn()
	local n, M, V = boot()
	n:Set("grp", "none"); n:Set("sort", "quality"); n:RefreshViews(true); M.runTimers()
	local normal = names(V)
	check(normal == "Better Belt | First Ring | Level Only | Slight Gloves | Linen Cloth | Old Belt" and label(V) == "Sort: Quality", "(the configured sort, by quality: " .. normal .. ")")
	local fail, calls = false, 0
	BagSmith.API.RegisterColumn("External Rank", "rank", function(d) calls = calls + 1; if fail then error("no") end; return "r", d.itemID end)
	local key = "x:rank"
	tick(n, M, key, true)
	local h = V.headerLabels[key]
	h:GetScript("OnClick")(h); M.runTimers()
	check(n:ActiveColSort(V.st) == V.st.colSort and V.st.colSort.key == key and label(V) == "Sort: External Rank" and names(V) ~= normal and V.btnSort.active == true, "sorted by the addon's column: the Sort button names it and is lit")
	local d = n.Columns:Get(key)
	d.fails, d.cache, d.cached, fail = 0, {}, 0, true
	n:RefreshViews(true); M.runTimers(); M.runTimers()
	check(d.off == true and not col(V, key), "(the column failed five times and has left the row)")
	check(n:ActiveColSort(V.st) == nil and V.st.colSort ~= nil and V.st.colSort.key == key, "the window is no longer sorted by it, though the choice is kept")
	check(label(V) == "Sort: Quality" and V.btnSort.active == false, "the Sort button names the sort in use and is no longer lit: " .. label(V))
	check(names(V) == normal, "and the list is in that order, not by name: " .. names(V))
	local stopped = calls
	n:RefreshViews(true); M.runTimers()
	check(calls == stopped and names(V) == normal, "another redraw: the same, and the addon isn't asked")
	-- the Sort button still works: a mode picked there is the player's new choice
	V.btnSort:GetScript("OnClick")(V.btnSort); M.runTimers()
	check(V.st.colSort == nil and not label(V):find("External Rank", 1, true), "clicking the Sort button picks a mode as always, and lets go of the old header sort: " .. label(V))
	check((n.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- Pawn's column: away with its advisor off, back with it on, and its sort with it
------------------------------------------------------------------------
do
	fakePawn()
	local n, M, V = boot()
	n:Set("grp", "none"); n:Set("sort", "quality")
	tick(n, M, "pawn", true)
	local normal = "Better Belt | First Ring | Level Only | Slight Gloves | Linen Cloth | Old Belt"
	local byPawn = "Better Belt | Slight Gloves | First Ring | Level Only | Linen Cloth | Old Belt"
	local h = V.headerLabels.pawn
	h:GetScript("OnClick")(h); M.runTimers()
	n.Pawn:Pass(); M.runTimers()
	check(names(V) == byPawn and label(V) == "Sort: Pawn" and n:ActiveColSort(V.st) ~= nil, "(sorted by Pawn: " .. names(V) .. ")")
	_G.PawnCommon.ShowBagUpgradeAdvisor = false
	n.Pawn:OnPawnRefresh("advisor off"); M.runTimers(); M.runTimers(); M.runTimers()
	check(not col(V, "pawn") and n:ActiveColSort(V.st) == nil and V.st.colSort.key == "pawn", "Pawn's advisor off: the column is away and so is its sort; the choice is kept")
	check(label(V) == "Sort: Quality" and names(V) == normal, "the list is in its configured order and the button says so: " .. label(V) .. " / " .. names(V))
	_G.PawnCommon.ShowBagUpgradeAdvisor = true
	n.Pawn:OnPawnRefresh("advisor on"); M.runTimers(); M.runTimers(); M.runTimers()
	check(col(V, "pawn") ~= nil and n:ActiveColSort(V.st) == V.st.colSort and label(V) == "Sort: Pawn", "the advisor on again: the column is back, and the window is sorted by it again")
	check(names(V) == byPawn, "in Pawn's order: " .. names(V))
	-- with Sort: Off (bag order), the column away means bag order, as the setting says
	n:Set("sort", "off")
	_G.PawnCommon.ShowBagUpgradeAdvisor = false
	n.Pawn:OnPawnRefresh("advisor off"); M.runTimers(); M.runTimers(); M.runTimers()
	check(label(V) == "Sort: Off" and names(V) == "Old Belt | Better Belt | First Ring | Level Only | Slight Gloves | Linen Cloth", "with the configured sort Off, the list is in bag order while the column is away: " .. names(V))
	_G.PawnCommon.ShowBagUpgradeAdvisor = true
	n.Pawn:OnPawnRefresh("advisor on"); M.runTimers(); M.runTimers(); M.runTimers()
	check(names(V) == byPawn, "(and by Pawn again when it returns)")
	-- Icons view with empty slots shown and Sort: Off: empty slots sit where they really are only while no header sort
	-- is in use; with the column away, none is
	n:Set("view", "icons"); n:Set("emptySlots", true)
	M.bags[0][3] = nil; M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
	local function cells() local t = {}; for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec then t[#t + 1] = b.rec.empty and "-" or b.rec.name end end; return table.concat(t, " | ") end
	check(n:ActiveColSort(V.st) ~= nil and not cells():find("^Old Belt | Better Belt | %- | Level Only"), "(sorted by Pawn in Icons view: the emptied slot is not in the middle: " .. cells():sub(1, 70) .. ")")
	_G.PawnCommon.ShowBagUpgradeAdvisor = false
	n.Pawn:OnPawnRefresh("advisor off"); M.runTimers(); M.runTimers(); M.runTimers()
	check(cells():find("^Old Belt | Better Belt | %- | Level Only | Slight Gloves | Linen Cloth") ~= nil, "Pawn away and Sort: Off: the grid follows the bags, the emptied slot where it really is: " .. cells():sub(1, 80))
	_G.PawnCommon.ShowBagUpgradeAdvisor = true
	n.Pawn:OnPawnRefresh("advisor on"); M.runTimers(); M.runTimers(); M.runTimers()
	check((n.errors or 0) == 0, "no errors")
	noPawn()
end

------------------------------------------------------------------------
-- BagSmith's own columns are untouched, and the version
------------------------------------------------------------------------
do
	noPawn()
	local n, M, V = boot()
	n:Set("grp", "none")
	check(n:ActiveColSort(V.st) == nil and n:ActiveColSort({}) == nil, "no header sort: none in use")
	n:SortByColumn(V.st, "c"); n:RefreshViews(true); M.runTimers()
	check(n:ActiveColSort(V.st) == V.st.colSort and label(V) == "Sort: Qty", "a sort by one of BagSmith's own columns is in use as always: " .. label(V))
	local unk = { colSort = { key = "nothing-registered", dir = "asc" } }
	check(n:ActiveColSort(unk) == unk.colSort, "(a key that is no registered column is passed through as before)")
	check(slurp("BagSmith/BagSmith.toc"):find("\n## Version: 1%.12%.0"), "the TOC version is 1.12.0's (the exact one is pinned in tests/run.lua)")
	check((n.errors or 0) == 0, "no errors")
end
