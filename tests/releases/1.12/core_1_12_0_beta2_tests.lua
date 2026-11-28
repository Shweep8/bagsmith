-- ======== 1.12.0-beta2 (Shweep, 28 Nov: "Build") ========
-- His feedback on beta1's Pawn column, three things:
--   "Think a small green up arrow beside this would be good" / "Yes in the cell": the arrow the icons carry, before
--   the number, and alone where beta1 wrote "Upgrade".
--   "This is far too long..", of the heading's tooltip; his pick of three: "Pawn's upgrade amount."
--   "Also default position should be after item name": Pawn's column right after Item, for a new profile and, once,
--   for an existing one (and for a profile that loaded beta1, which has it last).
-- The fake Pawn is the beta1 set's.

local function slurp(p) local f = assert(io.open(p, "r")); local s = f:read("*a"); f:close(); return s end
local function idOf(link) return tonumber(tostring(link):match("item:(%d+)")) end
local function fakePawn()
	local P = { answers = { [9802] = true, [9804] = true }, pct = { [9802] = { { PercentUpgrade = 0.31 } }, [9804] = { { PercentUpgrade = 100 } } } }
	_G.PawnShouldItemLinkHaveUpgradeArrow = function(link) return P.answers[idOf(link)] and true or false end
	_G.PawnGetItemData = function(link) return { Link = link, ID = idOf(link) } end
	_G.PawnIsItemAnUpgrade = function(item) return P.pct[item.ID] end
	_G.PawnBigUpgradeThreshold = 100
	_G.PawnCommon = { ShowBagUpgradeAdvisor = true }
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
	if o.atlas ~= nil then
		local real = C_Texture.GetAtlasInfo
		C_Texture.GetAtlasInfo = function(name) if name == "bags-greenarrow" then return o.atlas and { width = 15, height = 16 } or nil end return real(name) end
	end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = o.db and { version = 2, chars = {}, cache = {}, profiles = { Default = o.db } } or nil
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local main
	if not o.closed then
		ToggleAllBags(); M.runTimers()
		main = n.Window.main
		main.RowWidth = function() return 900 end
		n:RefreshViews(true); M.runTimers()
	end
	return n, M, main
end
local function row(v, id) for _, b in ipairs(v.used or {}) do if b:IsShown() and b.rec and b.hasItem and b.rec.itemID == id then return b end end end
local function cell(v, id) local b = row(v, id); local fs = b and b.colX_pawn; return fs and fs.text or nil, fs end
local function keys(v) local t = {}; for _, c in ipairs((v:ColumnPlan())) do t[#t + 1] = c.key end; return table.concat(t, ",") end
local function names(v) local t = {}; for _, b in ipairs(v.used or {}) do if b:IsShown() and b.rec and b.hasItem then t[#t + 1] = b.rec.name end end; return table.concat(t, " | ") end
local function seq(t) return table.concat(t, ",") end
local OLD_ORDER = { "c", "n", "t", "bd", "v", "w", "age", "fv", "cc", "jk", "il", "rq", "sl", "ah" }   -- every profile's default until 1.12
local function with(t, extra) local o = {}; for i, v in ipairs(t) do o[i] = v end; for k, v in pairs(extra or {}) do o[k] = v end; return o end
local function profile(extra) local o = { fvccCols = true, jkCol = true }; for k, v in pairs(extra or {}) do o[k] = v end; return o end

------------------------------------------------------------------------
-- 1. The arrow in the cell
------------------------------------------------------------------------
for _, atlas in ipairs({ true, false }) do
	local ARROW = atlas and "|A:bags-greenarrow:0:0|a" or "|TInterface\\AddOns\\Pawn\\Textures\\UpgradeArrow:0|t"
	local label = atlas and "the game's arrow art" or "Pawn's own arrow (no atlas)"
	local P = fakePawn()
	local n, M, V = boot({ db = profile({ cols = { "c", "t", "pawn" } }), atlas = atlas })
	check(n.Pawn:ArrowMarkup() == ARROW, label .. ": the picture the cell uses, sized by the text (0)")
	local t, fs = cell(V, 9802)
	check(t == ARROW .. " +31%", label .. ": an upgrade is the arrow, then the number: " .. tostring(t))
	check(cell(V, 9804) == ARROW, label .. ": an upgrade Pawn gives no number for is the arrow alone")
	check(cell(V, 9801) == "", label .. ": not an upgrade: empty, no arrow")
	check(fs.justifyH == "RIGHT" and fs.textColor[1] == 0.1 and fs.textColor[2] == 1, label .. ": the number is still right-aligned and green")
	local any = false
	for _, b in ipairs(V.used or {}) do if b.colX_pawn and tostring(b.colX_pawn.text):find("Upgrade", 1, true) and not tostring(b.colX_pawn.text):find("UpgradeArrow", 1, true) then any = true end end
	check(not any, label .. ": the word Upgrade is in no cell")
	-- the arrow on the icon uses the same art
	local up = row(V, 9802)
	check(up.pawnArrow and up.pawnArrow:IsShown() and ((atlas and up.pawnArrow.atlas == "bags-greenarrow") or (not atlas and up.pawnArrow.texture == "Interface\\AddOns\\Pawn\\Textures\\UpgradeArrow")),
		label .. ": the same art as the arrow on the icon")
	-- sorting is by the amount, as before, not by the text
	n:Set("grp", "none"); n:RefreshViews(true); M.runTimers()
	local h = V.headerLabels.pawn
	h:GetScript("OnClick")(h); M.runTimers()
	check(names(V) == "Better Belt | First Ring | Old Belt", label .. ": sorted by it: the numbered upgrade, the one without a number, the rest: " .. names(V))
	check(n.Columns:Get("pawn").width == 64, "(the column starts 64 px wide: room for the arrow)")
	check((n.errors or 0) == 0, "no errors")
	noPawn()
end

------------------------------------------------------------------------
-- 2. The tooltip
------------------------------------------------------------------------
do
	local P = fakePawn()
	local n, M, V = boot({ db = profile({ cols = { "c", "t", "pawn" } }) })
	check(n.Pawn.COLUMN_TIP == "Pawn's upgrade amount.", "the sentence, as he picked it")
	local h = V.headerLabels.pawn
	h:GetScript("OnEnter")(h)
	local lines = table.concat(GameTooltip.lines or {}, " | ")
	check(lines:find("Pawn's upgrade amount.", 1, true) ~= nil and not lines:find("for the scale it helps most", 1, true), "the heading's tooltip has it, and not beta1's sentence: " .. lines)
	h:GetScript("OnLeave")(h)
	local Pn = n.SettingsPanel
	Pn:Show(); M.runTimers(); Pn:ShowPage("bagcols"); M.runTimers()
	local r
	for _, l in ipairs(Pn.pools.list or {}) do if l:IsShown() then for _, x in ipairs(l.rows) do if x:IsShown() and x.id == "pawn" and not r then r = x end end end end
	check(r ~= nil and r.tip == "Pawn's upgrade amount.", "and so does its row in Bag Columns")
	-- where the row is: right after Item
	local ids, list = {}, nil
	for _, l in ipairs(Pn.pools.list or {}) do if l:IsShown() and not list then for _, x in ipairs(l.rows) do if x:IsShown() and x.id == "n" then list = l end end end end
	for _, x in ipairs(list and list.rows or {}) do if x:IsShown() then ids[#ids + 1] = x.id end end
	check(seq(ids):find("^c,n,pawn,t,") ~= nil, "Bag Columns lists it right after Item: " .. seq(ids))
	Pn:Hide()
	check((n.errors or 0) == 0, "no errors")
	noPawn()
end

------------------------------------------------------------------------
-- 3. Its default place: right after Item
------------------------------------------------------------------------
do
	local P = fakePawn()
	-- a new profile
	local n, M, V = boot()
	check(seq(n.db.colOrder) == "c,n,pawn,t,bd,v,w,age,fv,cc,jk,il,rq,sl,ah" and seq(n.db.bankColOrder) == seq(n.db.colOrder), "a new profile: Pawn right after Item, in the bags and the bank")
	check(not n.IndexOf(n.db.cols, "pawn") and keys(V) == "c,n,t,bd,v,w,age,fv,cc,jk", "still unticked: the row is what it was")
	table.insert(n.db.cols, "pawn"); n:Fire("SETTINGS_CHANGED", "cols"); n:RefreshViews(true); M.runTimers()
	check(keys(V) == "c,n,pawn,t,bd,v,w,age,fv,cc,jk", "ticked, it shows right after Item: " .. keys(V))
	check(n.db.pawnColPlace == true, "(a new profile is marked as placed)")
	noPawn()

	-- existing profiles, each loaded closed
	local cases = {
		{ "a 1.11 profile, the default order", with(OLD_ORDER), "c,n,pawn,t,bd,v,w,age,fv,cc,jk,il,rq,sl,ah" },
		{ "a 1.11 profile, Item first", { "n", "c", "t", "bd", "v", "w", "age", "fv", "cc", "jk", "il", "rq", "sl", "ah" }, "n,pawn,c,t,bd,v,w,age,fv,cc,jk,il,rq,sl,ah" },
		{ "a 1.11 profile, Item in the middle", { "c", "t", "bd", "n", "v", "w", "age", "fv", "cc", "jk", "il", "rq", "sl", "ah" }, "c,t,bd,n,pawn,v,w,age,fv,cc,jk,il,rq,sl,ah" },
		{ "a 1.11 profile, Item last", { "c", "t", "bd", "v", "w", "age", "fv", "cc", "jk", "il", "rq", "sl", "ah", "n" }, "c,t,bd,v,w,age,fv,cc,jk,il,rq,sl,ah,n,pawn" },
		{ "a profile that loaded beta1 (Pawn last)", { "c", "n", "t", "bd", "v", "w", "age", "fv", "cc", "jk", "il", "rq", "sl", "ah", "pawn" }, "c,n,pawn,t,bd,v,w,age,fv,cc,jk,il,rq,sl,ah" },
		{ "beta1, with Item moved", { "t", "c", "n", "bd", "v", "w", "age", "fv", "cc", "jk", "il", "rq", "sl", "ah", "pawn" }, "t,c,n,pawn,bd,v,w,age,fv,cc,jk,il,rq,sl,ah" },
		{ "beta1, Pawn already moved by the player", { "pawn", "c", "n", "t", "bd", "v", "w", "age", "fv", "cc", "jk", "il", "rq", "sl", "ah" }, "pawn,c,n,t,bd,v,w,age,fv,cc,jk,il,rq,sl,ah" },
		{ "beta1, Pawn moved one up from the end", { "c", "n", "t", "bd", "v", "w", "age", "fv", "cc", "jk", "il", "rq", "sl", "pawn", "ah" }, "c,n,t,bd,v,w,age,fv,cc,jk,il,rq,sl,pawn,ah" },
		{ "an order with no Item in it", { "c", "t" }, "c,t,n,pawn,bd,v,w,age,fv,cc,jk,il,rq,sl,ah" },
		{ "an order with something unknown in it", { "c", "zz", "n", "t" }, "c,n,pawn,t,bd,v,w,age,fv,cc,jk,il,rq,sl,ah" },
	}
	for _, c in ipairs(cases) do
		P = fakePawn()
		local saved = profile({ colOrder = with(c[2]), bankColOrder = with(OLD_ORDER), cols = { "c", "t", "v" }, pawnColAside = true })
		n = boot({ db = saved, closed = true })
		check(seq(n.db.colOrder) == c[3], c[1] .. ": " .. seq(n.db.colOrder))
		check(seq(n.db.bankColOrder) == "c,n,pawn,t,bd,v,w,age,fv,cc,jk,il,rq,sl,ah" and seq(n.db.cols) == "c,t,v", "(" .. c[1] .. ": the bank's order placed on its own, and nothing ticked)")
		noPawn()
	end

	-- once: the player then moves it to the end by hand, and what was saved is loaded again
	P = fakePawn()
	n = boot({ db = profile({ colOrder = with(OLD_ORDER), bankColOrder = with(OLD_ORDER) }), closed = true })
	local again = _G.BagSmithDB.profiles.Default
	check(type(again) == "table" and again.pawnColPlace == true and seq(again.colOrder) == "c,n,pawn,t,bd,v,w,age,fv,cc,jk,il,rq,sl,ah", "(the saved profile carries the mark and the new order)")
	table.remove(again.colOrder, n.IndexOf(again.colOrder, "pawn")); again.colOrder[#again.colOrder + 1] = "pawn"
	noPawn(); P = fakePawn()
	n = boot({ db = again, closed = true })
	check(n.db.colOrder[#n.db.colOrder] == "pawn" and seq(n.db.bankColOrder) == "c,n,pawn,t,bd,v,w,age,fv,cc,jk,il,rq,sl,ah", "moved to the end by the player afterwards, it stays there: the step runs once")
	-- a profile imported from 1.11 is placed the same way
	local name = n.Profiles:Import("old", { colOrder = { "n", "c", "t", "bd", "v", "w", "age", "fv", "cc", "jk", "il", "rq", "sl", "ah" }, fvccCols = true, jkCol = true })
	n.Profiles:Use(name)
	check(seq(n.db.colOrder) == "n,pawn,c,t,bd,v,w,age,fv,cc,jk,il,rq,sl,ah", "a 1.11 profile brought in by its code: right after Item too: " .. seq(n.db.colOrder))
	check((n.errors or 0) == 0, "no errors")
	noPawn()
end

------------------------------------------------------------------------
-- 4. The changelog and the version
------------------------------------------------------------------------
do
	local top = slurp("BagSmith/CHANGELOG.md"):match("^## 1%.12%.0\n(.-)\n## 1%.11%.0\n")
	top = (top or ""):gsub("\n  ", " ")
	check(top:find("\nNew:\n- A Pawn column for List view (Settings > Bag Columns or Bank Columns, with Pawn installed). Beside a green arrow it shows how much of an upgrade Pawn says each item is for you, such as +15%, or the arrow alone when Pawn gives no number. Click its heading to sort by it. It starts unticked, right after Item in the list, so your columns stay as they are until you tick it.", 1, true) ~= nil,
		"the changelog's Pawn entry: the arrow, and where the column starts")
	check(not top:find("or Upgrade when", 1, true) and not top:find("\226\128\148") and not top:find("\226\128\147"), "beta1's wording is gone; no dashes")
	check(slurp("BagSmith/BagSmith.toc"):find("\n## Version: 1%.12%.0"), "the TOC version is 1.12.0's (the exact one is pinned in tests/run.lua)")
end
