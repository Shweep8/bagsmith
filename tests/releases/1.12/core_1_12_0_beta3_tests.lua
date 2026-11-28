-- ======== 1.12.0-beta3 (Shweep, 28 Nov: "build 1 and 2. we can skip itemtree") ========
-- The rest of 1.12's scope.
--   1. Columns from other addons (BagSmith.API 1.2): RegisterColumn, RefreshColumn, IsColumnShown, on the registry
--      beta1 built for Pawn's column. A column is saved as "x:<id>", listed unticked, remembered per item, switched
--      off when it keeps failing, and its saved choices are kept through a session without its addon.
--   2. A bag right-clicked with every bag slot full: a menu of the worn bags to swap it in for (his option A).
-- The game's bag moves are modelled as in tests/releases/1.7/core_1_7_1_beta1_tests.lua.

local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function slurp(p) local f = assert(io.open(p, "r")); local s = f:read("*a"); f:close(); return s end
local function seq(t) return table.concat(t, ",") end
local function profile(extra) local o = { fvccCols = true, jkCol = true }; for k, v in pairs(extra or {}) do o[k] = v end; return o end
local function said(M, from, what) for i = from, #M.log do if plain(M.log[i]):find(what, 1, true) then return true end end return false end
local function count(M, from, what) local c = 0; for i = from, #M.log do if plain(M.log[i]):find(what, 1, true) then c = c + 1 end end; return c end

------------------------------------------------------------------------
-- Part 1: columns from other addons
------------------------------------------------------------------------
local function boot(o)
	o = o or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 9801, name = "Old Belt", q = 1, class = 4, subclass = 1, price = 5, equip = "INVTYPE_WAIST" })
	M.put(0, 2, { id = 9802, name = "Better Belt", q = 2, class = 4, subclass = 1, price = 50, equip = "INVTYPE_WAIST" })
	M.put(0, 3, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 13 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = profile(o.db), Other = profile(o.other) } }
	local n = M.loadAddon("BagSmith")
	if o.early then o.early(BagSmith.API, n, M) end
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local main
	if not o.closed then
		ToggleAllBags(); M.runTimers()
		main = n.Window.main
		main.RowWidth = function() return 900 end
		n:Set("grp", "none"); n:RefreshViews(true); M.runTimers()
	end
	return n, M, main, BagSmith.API
end
local function row(v, id) for _, b in ipairs(v.used or {}) do if b:IsShown() and b.rec and b.hasItem and b.rec.itemID == id then return b end end end
local function cell(v, id, key) local b = row(v, id); local fs = b and b["colX_" .. key]; return fs and fs.text or nil, fs end
local function keys(v) local t = {}; for _, c in ipairs((v:ColumnPlan())) do t[#t + 1] = c.key end; return seq(t) end
local function col(v, key) for _, c in ipairs((v:ColumnPlan())) do if c.key == key then return c end end end
local function names(v) local t = {}; for _, b in ipairs(v.used or {}) do if b:IsShown() and b.rec and b.hasItem then t[#t + 1] = b.rec.name end end; return table.concat(t, " | ") end
local function tick(n, M, key, list)
	list = list or n.db.cols
	if not n.IndexOf(list, key) then list[#list + 1] = key end
	n:Fire("SETTINGS_CHANGED", "cols"); n:RefreshViews(true); M.runTimers()
end

do
	local n, M, V, api = boot()
	local major, minor = api:GetVersion()
	check(major == 1 and minor == 2 and type(api.RegisterColumn) == "function" and type(api.RefreshColumn) == "function" and type(api.IsColumnShown) == "function", "BagSmith.API is 1.2, with the three column functions")
	check(api:Compatible(1, 2) and api:Compatible(1, 1) and api:Compatible(1, 0) and not api:Compatible(1, 3), "a plugin asking for 1.0, 1.1 or 1.2 is compatible; 1.3 is not yet")

	---- refusals, each said once in chat
	local from = #M.log + 1
	local fn = function() return "x" end
	check(api.RegisterColumn("", "a", fn) == false and api.RegisterColumn("   ", "a", fn) == false and api.RegisterColumn(nil, "a", fn) == false, "no label: refused")
	check(api.RegisterColumn("A", "", fn) == false and api.RegisterColumn("A", "has space", fn) == false and api.RegisterColumn("A", "bad:colon", fn) == false and api.RegisterColumn("A", ("i"):rep(41), fn) == false and api.RegisterColumn("A", 7, fn) == false,
		"an id that is empty, has other characters, or is over 40 long: refused")
	check(api.RegisterColumn("A", "a") == false and api.RegisterColumn("A", "a", "text") == false, "no onUpdate: refused")
	check(said(M, from, "An addon's column (has space) couldn't be added to Bag Columns: it needs a label, an id (letters, digits, _ - .) and onUpdate."), "a refusal says why in chat")
	api.RegisterColumn("A", "has space", fn)
	check(count(M, from, "An addon's column (has space) couldn't be added") == 1, "once, however often it is tried")
	check(n.Columns:Get("x:a") == nil and not n.IndexOf(n.db.colOrder, "x:a"), "nothing was registered or saved by any of them")

	---- a column registers: a dot call and a colon call
	local calls, seen = {}, {}
	local function score(d)
		calls[d.itemID] = (calls[d.itemID] or 0) + 1
		seen[d.itemID] = d
		if d.itemID == 2589 then return false end
		return "s" .. d.itemID, d.itemID
	end
	check(api.RegisterColumn("Test: Score", "test_score", score, { width = 70, align = "RIGHT", tooltip = "The test's score." }) == true, "RegisterColumn, dot call")
	check(api:RegisterColumn("Test: Plain", "test.plain-2", function(d) return d.itemName end) == true, "RegisterColumn, colon call, with dots and dashes in the id")
	from = #M.log + 1
	check(api.RegisterColumn("Again", "test_score", fn) == false and said(M, from, "\"test_score\" is already registered"), "an id already registered: refused, the first one kept")
	local d = n.Columns:Get("x:test_score")
	check(d and d.label == "Test: Score" and d.width == 70 and d.numeric == true and d.tip == "The test's score." and d.addon == true, "what it asked for: its label, 70 px, right-aligned, its tooltip")
	local p = n.Columns:Get("x:test.plain-2")
	check(p and p.width == 60 and p.numeric == false and p.tip == "Added by another addon.", "with no options: 60 px, left-aligned, a plain tooltip")
	check(n.db.colOrder[#n.db.colOrder - 1] == "x:test_score" and n.db.colOrder[#n.db.colOrder] == "x:test.plain-2" and n.db.bankColOrder[#n.db.bankColOrder] == "x:test.plain-2",
		"each joins the end of the column order, bags and bank")
	check(not n.IndexOf(n.db.cols, "x:test_score") and not n.IndexOf(n.db.bankCols, "x:test_score") and not n.IndexOf(n.db.colAside, "x:test_score"), "unticked, and not added to Narrow Windows")
	check(keys(V) == "c,n,t,bd,v,w,age,fv,cc,jk" and next(calls) == nil, "until it is ticked the row is unchanged and the addon is asked nothing")
	check(api.IsColumnShown("test_score") == false and api:IsColumnShown("test_score") == false and api.IsColumnShown("nope") == false, "IsColumnShown: not yet")

	---- ticked
	tick(n, M, "x:test_score")
	check(keys(V) == "c,n,t,bd,v,w,age,fv,cc,jk,x:test_score" and col(V, "x:test_score").colW == 70 and col(V, "x:test_score").numeric == true, "ticked: in the row, at its width, right-aligned")
	check(api.IsColumnShown("test_score") == true, "IsColumnShown: yes")
	local t, fs = cell(V, 9802, "x:test_score")
	check(t == "s9802" and fs:IsShown() and fs.justifyH == "RIGHT" and cell(V, 9801, "x:test_score") == "s9801" and cell(V, 2589, "x:test_score") == "", "its cells: the addon's text, and empty where it said false")
	local h = V.headerLabels["x:test_score"]
	check(h ~= nil and h:IsShown() and h.text.text == "Test: Score" and h.text.justifyH == "RIGHT", "its heading")
	h:GetScript("OnEnter")(h)
	check(table.concat(GameTooltip.lines or {}, " | "):find("The test's score.", 1, true) ~= nil, "the heading's tooltip has the addon's sentence")
	h:GetScript("OnLeave")(h)
	local dd = seen[9802]
	check(dd.itemLink ~= nil and dd.itemID == 9802 and dd.bagID == 0 and dd.slotID == 2 and dd.quality == 2 and dd.itemCount == 1 and dd.itemName == "Better Belt" and seen[2589].itemCount == 5,
		"onUpdate is given the details a corner widget gets: link, id, bag and slot, quality, count, name")

	---- remembered per item
	check(calls[9801] == 1 and calls[9802] == 1 and calls[2589] == 1, "asked once for each item")
	n:RefreshViews(true); M.runTimers(); n:RefreshViews(true)
	check(calls[9801] == 1 and calls[9802] == 1 and calls[2589] == 1, "a redraw asks nothing: the answers are kept")
	h:GetScript("OnClick")(h); M.runTimers()
	check(V.st.colSort.key == "x:test_score" and names(V) == "Better Belt | Old Belt | Linen Cloth", "sorted by the number it gave, largest first: " .. names(V))
	h:GetScript("OnClick")(h); M.runTimers()
	check(names(V) == "Linen Cloth | Old Belt | Better Belt", "and smallest first: " .. names(V))
	check(calls[9801] == 1 and calls[9802] == 1 and calls[2589] == 1, "sorting asks nothing either")
	-- RefreshColumn: forgotten and asked again, once however often it is called in a frame
	local redraws, realChanged = 0, n.Columns.Changed
	n.Columns.Changed = function(self, key) redraws = redraws + 1; return realChanged(self, key) end
	check(api.RefreshColumn("test_score") == true and api:RefreshColumn("test_score") == true and api.RefreshColumn("test_score") == true and api.RefreshColumn("nope") == false and api.RefreshColumn(nil) == false,
		"RefreshColumn: true for a registered id, false otherwise")
	M.runTimers()
	check(redraws == 1, "three calls in one frame make one redraw (" .. redraws .. ")")
	check(calls[9801] == 2 and calls[9802] == 2 and calls[2589] == 2, "and each item is asked once more")
	n.Columns.Changed = realChanged
	V.st.colSort = nil; n:RefreshViews(true); M.runTimers()
	-- a changed stack is a different answer to ask for
	M.bags[0][3].count = 7; M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
	check(calls[2589] == 3 and calls[9801] == 2, "an item whose count changed is asked about again; the others are not")
	check((n.errors or 0) == 0, "no errors")
end

-- "not ready yet", odd text, another character's items
do
	local n, M, V, api = boot()
	local ready, calls, others = false, 0, 0
	api.RegisterColumn("Late", "late", function(d)
		calls = calls + 1
		if not ready then return nil end
		if d.itemID == 9801 then return "two\nlines\tand a tab" end
		if d.itemID == 9802 then return ("y"):rep(500), "not a number" end
		return 42
	end)
	api.RegisterColumn("Alts", "alts", function(d) others = others + 1; return d.bagID and "mine" or "theirs" end, { otherCharacters = true })
	tick(n, M, "x:late"); tick(n, M, "x:alts")
	check(cell(V, 9801, "x:late") == "" and calls >= 3, "nil (not ready yet): an empty cell on a first fill")
	local c1 = calls
	n:RefreshViews(true)
	check(calls == c1 + 3, "and nothing is remembered: each of the three items is asked again on the next redraw")
	ready = true
	api.RefreshColumn("late"); M.runTimers()
	check(cell(V, 9801, "x:late") == "two lines and a tab", "control characters in a cell's text become spaces: one line")
	check(#cell(V, 9802, "x:late") == 200, "a very long text is cut to 200 bytes")
	check(cell(V, 2589, "x:late") == "42", "a number is shown as its text")
	check(n.Columns:SortValue("x:late", row(V, 9802).rec) == 0, "a sort value that isn't a number sorts as 0")
	-- another character's saved items
	check(cell(V, 9801, "x:alts") == "mine", "(a column that also answers for other characters: your own items)")
	local c0, o0 = calls, others
	local theirs = { cached = true, itemID = 4306, link = "|cffffffff|Hitem:4306::::::::1:::::|h[Silk Cloth]|h|r", count = 2, name = "Silk Cloth" }
	check(n.Columns:Value("x:late", theirs) == "" and calls == c0, "another character's saved item: empty, and the addon isn't asked")
	check(n.Columns:Value("x:alts", theirs) == "theirs" and others == o0 + 1, "unless the column asked to be (otherCharacters), and then with no bag or slot")
	check((n.errors or 0) == 0, "no errors")
end

-- a column that fails; the cap
do
	local n, M, V, api = boot()
	local bad = 0
	api.RegisterColumn("Broken", "broken", function() bad = bad + 1; error("boom") end)
	tick(n, M, "x:broken")
	n:RefreshViews(true); n:RefreshViews(true); M.runTimers()
	local d = n.Columns:Get("x:broken")
	check(d.off == true and bad == 5, "onUpdate failing five times switches the column off (" .. bad .. " calls)")
	check(not col(V, "x:broken") and (n.errors or 0) == 0, "it leaves the row, and none of it is an error of BagSmith's")
	local Pn = n.SettingsPanel
	Pn:Show(); M.runTimers(); Pn:ShowPage("bagcols"); M.runTimers()
	local r
	for _, l in ipairs(Pn.pools.list or {}) do if l:IsShown() then for _, x in ipairs(l.rows) do if x:IsShown() and x.id == "x:broken" and not r then r = x end end end end
	check(r ~= nil and plain(r.text.text) == "Broken" and not r.box:IsEnabled() and r.tip == "This column ran into errors, so it is off until you reload.", "Bag Columns lists it greyed, saying why")
	Pn:Hide()
	check(api.RefreshColumn("broken") == true and n.Columns:Get("x:broken").off == true, "RefreshColumn doesn't switch it back on")
	-- eight columns from addons at most (one is registered already)
	local from = #M.log + 1
	local ok = 0
	for i = 1, 9 do if api.RegisterColumn("C" .. i, "cap" .. i, function() return "" end) then ok = ok + 1 end end
	check(ok == 7 and n.Columns:Get("x:cap7") ~= nil and n.Columns:Get("x:cap8") == nil, "eight in all: the ninth and tenth are refused (" .. ok .. " more taken)")
	check(said(M, from, "An addon's column (cap8) couldn't be added to Bag Columns: BagSmith takes 8 columns from other addons, and already has them."), "and the refusal says so")
	check(n.Columns:Get("pawn") ~= nil, "(BagSmith's own Pawn column is not one of the eight)")
	check((n.errors or 0) == 0, "no errors")
end

-- saved choices, with and without the addon
do
	-- a profile whose player ticked, placed and sized a column from an addon that isn't loaded this session
	local saved = { cols = { "c", "x:gone", "t" }, bankCols = { "x:gone" }, colOrder = { "c", "n", "x:gone", "t" }, colAside = { "x:gone", "t" },
		colWidths = { ["x:gone"] = 77, t = 120 }, pawnColAside = true, pawnColPlace = true }
	local n, M, V, api = boot({ db = saved })
	check(seq(n.db.cols) == "c,x:gone,t" and seq(n.db.bankCols) == "x:gone" and n.db.colOrder[3] == "x:gone" and seq(n.db.colAside) == "x:gone,t" and n.db.colWidths["x:gone"] == 77,
		"an addon's column that isn't loaded: its tick, place, Narrow Windows tick and width are all kept")
	check(keys(V) == "c,n,t" and n.Columns:Usable("x:gone") == false, "it isn't in the row, and counts nothing toward the window's narrowest width")
	local Pn = n.SettingsPanel
	Pn:Show(); M.runTimers(); Pn:ShowPage("bagcols"); M.runTimers()
	local listed = 0
	for _, l in ipairs(Pn.pools.list or {}) do if l:IsShown() then for _, x in ipairs(l.rows) do if x:IsShown() and x.id == "x:gone" then listed = listed + 1 end end end end
	check(listed == 0, "Bag Columns doesn't list it while nobody answers for it")
	Pn:Hide()
	-- the addon loads after all
	check(api.RegisterColumn("Back Again", "gone", function(d) return "g" .. d.itemID end) == true, "(its addon registers)")
	n:RefreshViews(true); M.runTimers()
	check(keys(V) == "c,n,x:gone,t" and col(V, "x:gone").colW == 77 and cell(V, 9802, "x:gone") == "g9802", "and it is back where the player had it, ticked, at their width")
	check(n.db.colOrder[3] == "x:gone" and #n.db.colOrder == 16, "its saved place is used, not a second one at the end")
	-- another profile gets the registered column in its order when it is switched to
	n.Profiles:Use("Other"); M.runTimers()
	check(n.IndexOf(n.db.colOrder, "x:gone") == #n.db.colOrder and not n.IndexOf(n.db.cols, "x:gone"), "another profile: the column joins the end of its order when it becomes active, unticked")
	check((n.errors or 0) == 0, "no errors")

	-- what the load check keeps and drops
	local many, wide = { "c" }, {}
	for i = 1, 20 do many[#many + 1] = ("x:m%02d"):format(i); wide[("x:m%02d"):format(i)] = 50 + i end
	local junk = { "x:", "x:bad key", "y:zz", "x:" .. ("i"):rep(41), "x:ok", "x:ok", 7, "X:caps" }
	n = boot({ db = { cols = many, colOrder = junk, colAside = junk, colWidths = wide, pawnColAside = true, pawnColPlace = true }, closed = true })
	check(#n.db.cols == 17 and n.db.cols[1] == "c" and n.db.cols[17] == "x:m16", "sixteen addon columns are kept in a list, in order; more are dropped")
	local w = 0
	for k in pairs(n.db.colWidths) do if n.AddonColKey(k) then w = w + 1 end end
	check(w == 16 and n.db.colWidths["x:m01"] == 51 and n.db.colWidths["x:m16"] == 66 and n.db.colWidths["x:m17"] == nil, "and sixteen widths, the same sixteen whatever order the table is walked in")
	check(seq(n.db.colAside) == "x:ok", "a key is kept only in the form x:<id>, once: " .. seq(n.db.colAside))
	check(n.db.colOrder[1] == "x:ok" and #n.db.colOrder == 16, "the order keeps it and gains BagSmith's own that were missing")
	check(n.AddonColKey("x:a_b-c.d") and not n.AddonColKey("pawn") and not n.AddonColKey("x:a b") and not n.AddonColKey(nil), "(the form: x:, then letters, digits, _ - .)")
	check((n.errors or 0) == 0, "no errors")
end

-- registered before settings are ready (an addon that loads first), Global Inventory, the Example Plugin, the docs
do
	local n, M, V, api = boot({ early = function(api) api.RegisterColumn("Early", "early", function(d) return "e" end) end })
	check(n.Columns:Get("x:early") ~= nil and n.db.colOrder[#n.db.colOrder] == "x:early", "a column registered before BagSmith's settings were ready is placed once they are")
	tick(n, M, "x:early")
	check(col(V, "x:early") ~= nil, "(ticked: shown)")
	V:SetGlobal(true); M.runTimers(); M.runTimers()
	check(n.ui.global and not col(V, "x:early"), "Global Inventory has no columns from addons")
	V:SetGlobal(false); M.runTimers(); M.runTimers()
	check((n.errors or 0) == 0, "no errors")
end
do
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local n = M.loadAddon("BagSmith")
	dofile("tests/companion_loader.lua")(M, "BagSmith_ExamplePlugin", "BagSmith_ExamplePlugin")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("ADDON_LOADED", "BagSmith_ExamplePlugin"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local d = n.Columns:Get("x:bagsmith-example-id")
	check(d ~= nil and d.label == "Example: Item ID" and d.numeric == true and d.width == 64, "the Example Plugin registers a column: Example: Item ID")
	check(n.Columns:Value("x:bagsmith-example-id", { itemID = 2589, link = "l", bag = 0, slot = 1 }) == "2589" and n.Columns:SortValue("x:bagsmith-example-id", { itemID = 2589, link = "l", bag = 0, slot = 1 }) == 2589,
		"which shows an item's ID and sorts by it")
	check((n.errors or 0) == 0, "no errors")
	local doc = slurp("docs/API.md")
	check(doc:find("^# BagSmith.API 1%.2 reference\n") and doc:find("\n## List view columns (1.2)\n", 1, true) and doc:find("`RegisterColumn(label, id, onUpdate, options)`", 1, true) and doc:find("`RefreshColumn(id)`", 1, true) and doc:find("`IsColumnShown(id)`", 1, true),
		"docs/API.md is the 1.2 reference, with the three functions")
	check(slurp("docs/API-CHANGES.md"):find("\n## 1.2 (BagSmith 1.12.0)\n", 1, true) and slurp("docs/COMPATIBILITY.md"):find("\n## API 1.2 (BagSmith 1.12.0)\n", 1, true) and slurp("docs/EXAMPLES.md"):find("## A List view column (BagSmith.API 1.2)", 1, true),
		"the changes, the compatibility notes and the examples have 1.2")
	for _, f in ipairs({ "docs/API.md", "docs/API-CHANGES.md", "docs/COMPATIBILITY.md", "docs/EXAMPLES.md" }) do
		check(not slurp(f):find("\226\128\148"), f .. ": no em dashes")
	end
end

------------------------------------------------------------------------
-- Part 2: a bag right-clicked with every bag slot full
------------------------------------------------------------------------
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

do
	-- the new bag in the backpack: the menu, and a swap straight in
	local r = bagBoot()
	local from = #r.M.log + 1
	r.rightClick()
	local rows = r.menu()
	check(rows ~= nil and #rows == 5, "a bag right-clicked with every bag slot full: a menu, a title and the four worn bags")
	check(r.texts() == "Swap in Runecloth Bag for: | Linen Bag (4 slots, 1 used) | Wool Bag (6 slots, 2 used) | Silk Bag (8 slots, 3 used) | Mageweave Bag (10 slots, 0 used)",
		"the worn bags, smallest first, each with its size and how full it is: " .. r.texts())
	check(rows[1].fn == nil and rows[2].fn ~= nil and rows[5].fn ~= nil, "the title does nothing; every bag can be picked")
	check(said(r.M, from, "Swap menu: game error \"No equipment slot is available for that item.\" (21) right after the bag in bag 0 slot 1 was clicked") and said(r.M, from, "Swap menu: offered for the bag in bag 0 slot 1 (4 worn bags)"), "/bs debug says what it saw and that it offered")
	check(#r.st.puts == 0 and r.st.places == 0 and r.equipped[21] == LINEN, "opening the menu moves nothing")
	rows[2].fn(); r.run()
	check(r.equipped[21] == RUNE and r.M.sizes[2] == 14, "picking the Linen Bag puts the Runecloth Bag in its slot")
	local ob, os = r.where(LINEN)
	check(ob == 0 and os == 1 and r.M.bags[2][1] and r.M.bags[2][1].id == 2770, "the Linen Bag is where the new bag was; what it held stayed in the slot's bag")
	check(#r.st.puts == 1 and r.st.puts[1] == 21 and r.st.places == 0 and r.M.cursorItem == nil and not r.H.swapping, "one put, no move first (the new bag was already outside), nothing on the cursor, the swap over")
	check(said(r.M, from, "Swapped in Runecloth Bag; Linen Bag is in your "), "and it says where the old bag went")
	check((r.n.errors or 0) == 0, "no errors")
end
do
	-- the new bag inside the bag it replaces: moved out first, as a drag onto that bag's slot is
	local r = bagBoot({ at = { 2, 3 } })
	r.rightClick()
	check(r.texts():find("Linen Bag (4 slots, 2 used)", 1, true) ~= nil and r.pick("Linen Bag").fn ~= nil, "the bag the new one is inside can be picked while another bag has a free slot")
	r.pick("Linen Bag").fn(); r.run()
	check(r.equipped[21] == RUNE and r.st.places == 1 and #r.st.puts == 1, "picked: the new bag is set down in another bag first, then swapped in")
	local ob = r.where(LINEN)
	check(ob ~= nil and ob ~= 2 and (r.n.errors or 0) == 0, "and the Linen Bag ends up outside its old slot")
	-- with no free slot anywhere else, that row is greyed and says why
	r = bagBoot({ at = { 2, 3 }, fill = function(M)
		for s = 1, 4 do if not M.bags[0][s] then M.put(0, s, ore()) end end
		for s = 1, 8 do if not M.bags[1][s] then M.put(1, s, ore()) end end
		for s = 1, 10 do M.put(3, s, ore()) end
		for s = 1, 6 do if not M.bags[4][s] then M.put(4, s, ore()) end end
	end })
	r.rightClick()
	local x = r.pick("Linen Bag")
	check(x ~= nil and x.fn == nil and x.tipText == "The new bag is inside this one, and no other bag has a free slot to set it down in first.", "no free slot in any other bag: the bag it is inside is greyed, with the reason")
	check(r.pick("Wool Bag").fn ~= nil, "the other bags can still be picked")
end
do
	-- the same kind of bag; a special bag
	local r = bagBoot({ new = WOOL })
	r.rightClick()
	local x = r.pick("Wool Bag (")   -- (the row, not the title, which names the new bag too)
	check(x.fn == nil and x.tipText == "It is the same kind of bag." and r.pick("Linen Bag").fn ~= nil, "a worn bag of the same kind is greyed: nothing to swap")
	r = bagBoot({ new = HERB })
	local fam = { [HERB] = 32, [765] = 32 }
	C_Item.GetItemFamily = function(id) return fam[id] or 0 end
	r.M.put(3, 1, { id = 765, name = "Silverleaf", q = 1, count = 3, class = 7, subclass = 9, price = 1 }); r.M.fire("BAG_UPDATE", 3); r.run()
	r.rightClick()
	check(r.pick("Linen Bag").fn == nil and r.pick("Linen Bag").tipText == "It holds things that can't go in that kind of bag.", "a special bag: a worn bag holding other things is greyed, with the reason")
	check(r.pick("Mageweave Bag").fn ~= nil, "one holding only what the special bag takes can be picked")
end
do
	-- the game refuses anyway (the new bag is too small for what the old one holds): said, and nothing lost
	local r = bagBoot({ new = TINY })
	local from = #r.M.log + 1
	r.rightClick()
	check(r.pick("Silk Bag (8 slots, 3 used)").fn ~= nil, "a bag's own size isn't known to an addon until it is worn, so a too-small bag isn't greyed beforehand")
	r.pick("Silk Bag").fn(); r.run()
	check(r.equipped[20] == SILK and select(1, r.where(TINY)) == 0 and r.M.cursorItem == nil and not r.H.swapping, "the game refuses: the worn bag stays, the new one is back in its slot, nothing on the cursor")
	check(said(r.M, from, "The game didn't swap the bags (Tiny Pouch may be too small for what Silk Bag holds)."), "and the refusal is explained")
	check((r.n.errors or 0) == 0, "no errors")
end
do
	-- when no menu is offered
	local r = bagBoot({ equipped = { [20] = SILK, [21] = LINEN, [22] = MAGE } })
	r.rightClick()
	check(r.menu() == nil, "a bag slot is empty: no menu (the game's refusal was about something else)")
	r = bagBoot()
	r.M.combat = true
	r.rightClick()
	check(r.menu() == nil, "in combat: no menu")
	r = bagBoot()
	_G.MerchantFrame = { IsShown = function() return true end }
	r.rightClick()
	check(r.menu() == nil, "at a vendor (a right-click sells there): no menu")
	_G.MerchantFrame = nil
	r = bagBoot()
	r.n.atBank = true
	r.rightClick()
	check(r.menu() == nil, "at the bank: no menu")
	r = bagBoot()
	r.lock(); r.unlock(); r.tick(0.6); r.red(); r.M.runTimers()
	check(r.menu() == nil, "the red line more than half a second after the click: not that click's")
	r = bagBoot()
	r.lock(); r.unlock(); r.M.runTimers()
	check(r.menu() == nil, "a click with no red line (the game equipped it, or it was put back): no menu")
	r = bagBoot()
	r.red(); r.M.runTimers()
	check(r.menu() == nil, "a red line with no bag clicked: no menu")
	r = bagBoot()
	-- a drag: the bag is on the cursor while its slot is locked, and is put back
	r.M.cursorItem = RUNE; r.lock(); r.M.cursorItem = nil; r.unlock(); r.M.runTimers()
	check(r.menu() == nil, "a bag picked up and put back: no menu")
	r = bagBoot()
	r.M.cursorItem = 2770; r.lock(); r.unlock(); r.red(); r.M.runTimers(); r.M.cursorItem = nil
	check(r.menu() == nil, "something else on the cursor: no menu")
	-- the other order: the red line first, the slot's release right after
	r = bagBoot()
	r.lock(); r.red(); r.unlock(); r.M.runTimers()
	check(r.menu() ~= nil and #r.menu() == 5, "the red line before the slot is released: the same menu")
	check((r.n.errors or 0) == 0, "no errors")
end
do
	-- the bags changed while the menu was open; combat began; a swap already running
	local r = bagBoot()
	r.rightClick()
	local pick = r.pick("Linen Bag").fn
	local from = #r.M.log + 1
	r.M.bags[0][2] = r.M.bags[0][1]; r.M.bags[0][1] = nil      -- the new bag was moved meanwhile
	pick(); r.run()
	check(r.equipped[21] == LINEN and #r.st.puts == 0 and said(r.M, from, "Your bags changed while the menu was open, so nothing was swapped."), "the new bag moved while the menu was open: nothing is swapped, and it says so")
	r = bagBoot()
	r.rightClick()
	pick = r.pick("Linen Bag").fn
	r.equipped[21] = WOOL
	from = #r.M.log + 1
	pick(); r.run()
	check(#r.st.puts == 0 and said(r.M, from, "Your bags changed while the menu was open"), "the worn bag changed while the menu was open: nothing is swapped")
	r = bagBoot()
	r.rightClick()
	pick = r.pick("Linen Bag").fn
	r.M.combat = true
	from = #r.M.log + 1
	pick(); r.run()
	check(#r.st.puts == 0 and r.equipped[21] == LINEN and said(r.M, from, "Bags can't be swapped in combat. Try again after the fight."), "combat began before the pick: nothing is swapped, and it says so")
	r = bagBoot()
	r.H.swapping = { stop = function() end }
	r.rightClick()
	check(r.menu() == nil, "while a swap is running: no menu")
	check((r.n.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- The changelog and the version
------------------------------------------------------------------------
do
	local top = slurp("BagSmith/CHANGELOG.md"):match("^## 1%.12%.0\n(.-)\n## 1%.11%.0\n")
	top = (top or ""):gsub("\n  ", " ")
	check(top:find("\n- Other addons can add columns to List view. One that does shows up in Settings > Bag Columns and Bank Columns, unticked, for you to tick, move, resize and sort by like any other. (For addon authors: BagSmith.API 1.2.)", 1, true) ~= nil,
		"the changelog: columns from other addons")
	check(top:find("\n- Right-click a bag in your bags when every bag slot is full, and BagSmith offers a menu of the bags you are wearing, smallest first, to swap it in for. Before, the game only said there was no slot.", 1, true) ~= nil,
		"the changelog: the menu for a right-clicked bag")
	check(not top:find("\226\128\148") and not top:find("\226\128\147"), "no dashes")
	check(slurp("BagSmith/BagSmith.toc"):find("\n## Version: 1%.12%.0"), "the TOC version is 1.12.0's (the exact one is pinned in tests/run.lua)")
end
