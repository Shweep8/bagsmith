--[[
	BagSmith - Core/Settings.lua
	BagSmithDB = { version, profiles = { name = settings }, chars = { charKey = profile }, cache = { charKey = data } }
	ns.db is the active profile. Every field is validated; broken values fall back to defaults.
--]]

local ADDON, ns = ...
local DB_VERSION = 2
local DEFAULT_PROFILE = "Default"

ns.CATS = { "Gear", "Consumables", "Reagents", "TradeGoods", "Recipes", "Quest", "Tokens", "Keys", "Junk", "Other" }
ns.CAT_LABEL = { Gear = "Gear", Consumables = "Consumables", Reagents = "Reagents", TradeGoods = "Trade Goods",
	Recipes = "Recipes", Quest = "Quest", Tokens = "Tokens", Keys = "Keys", Junk = "Junk", Other = "Other" }
-- (1.5.0-beta9) Split Consumables: the sections Consumables can split into, by the game's own consumable types
-- (Food and Drink share the game's "Food & Drink" type; the item's use spell tells them apart). Each counts as part
-- of Consumables for the Consumables tab and category filters (ns.PARENT_CAT).
ns.CONS_KINDS = { "Food", "Drink", "Potion", "Elixir", "Flask", "Scroll", "Bandage", "Enhance", "Other" }
ns.CONS_LABEL = { Food = "Food", Drink = "Drink", Potion = "Potions", Elixir = "Elixirs", Flask = "Flasks", Scroll = "Scrolls",
	Bandage = "Bandages", Enhance = "Item Enhancements", Other = "Consumables: Other" }   -- (1.7.0-beta10, Shweep: was "Other Consumables", to match Gear: Other)
ns.CONS_ID, ns.PARENT_CAT = {}, {}
for _, k in ipairs(ns.CONS_KINDS) do
	local id = "Cons" .. k
	ns.CONS_ID[k] = id; ns.CAT_LABEL[id] = ns.CONS_LABEL[k]; ns.PARENT_CAT[id] = "Consumables"
end
-- (1.7.0-beta6, Shweep) Split Gear by Binding: Gear splits by the Bind column's facts. Bound to you (bind on pickup, or
-- bound since: a BoE you equipped) goes to Gear: Soulbound; bind on equip, not yet bound, to Gear: BoE; binds when used,
-- or doesn't bind, stays in Gear. Each counts as part of Gear for the Gear tab and category filters (ns.PARENT_CAT).
ns.GEAR_KINDS = { "Soulbound", "BoE" }
ns.GEAR_LABEL = { Soulbound = "Gear: Soulbound", BoE = "Gear: BoE" }
ns.GEAR_ID = {}
for _, k in ipairs(ns.GEAR_KINDS) do
	local id = "Gear" .. k
	ns.GEAR_ID[k] = id; ns.CAT_LABEL[id] = ns.GEAR_LABEL[k]; ns.PARENT_CAT[id] = "Gear"
end
ns.COLS = { { "c", "Qty" }, { "il", "iLvl" }, { "rq", "Req lvl" }, { "t", "Type" }, { "sl", "Slot" }, { "bd", "Bind" }, { "v", "Vendor" }, { "w", "Where" }, { "age", "Age" }, { "ah", "AH Price" }, { "fv", "Favorite" }, { "cc", "Currency" }, { "jk", "Junk" } }
ns.COL_LABEL = {}
for _, c in ipairs(ns.COLS) do ns.COL_LABEL[c[1]] = c[2] end
ns.BASE_TABS = { "All", "Gear", "Consumables", "TradeGoods", "Quest", "Junk", "GearSets", "Bank" }
ns.TAB_LABEL = { All = "All", Gear = "Gear", GearSets = "Gear Sets", Consumables = "Consumables", TradeGoods = "Trade Goods", Quest = "Quest", Junk = "Junk", Bank = "Bank" }
-- Tabs the bank window doesn't have (its own Bank tab is the window itself; gear sets are equipped from your bags).
local NOT_BANK_TABS = { Bank = true, GearSets = true }

local DEFAULTS = {
	debug = false,
	quiet = false,
	-- appearance
	skin = "classic",          -- modern | classic; new players start in Classic (existing profiles keep theirs)
	accent = "fac775",         -- hex, used by both skins
	mergeStacks = false,       -- show one row per item with the total count
	bankGrp = "type", bankSort = "quality", bankView = "list", bankMerge = false,   -- the bank window's own
	reagentWindow = false,     -- also show the reagent bag in its own window (set with bagWindows by "When the Main Window Opens")
	border = "all",            -- all | unc | off
	rtext = true, newdot = true, dense = false,
	-- layout
	view = "list",             -- list | icons
	bagWindows = false,        -- also open one window per bag
	bagPoints = {},            -- bag id (string) -> anchor
	side = "left",             -- left | right
	reagent = "lane",          -- inline (Mixed In) | lane (Own Section)
	keys = true, emptySlots = true,
	splitView = false,         -- icon view with sections: sections side by side in two columns (Sections page)
	splitViewRecentWide = false,   -- (1.7.0-beta2) Split View: Recent spans both columns instead of pairing
	recentSection = true,      -- a Recent section pinned at the top of the bags window (Sections page)
	recentWindow = "session",  -- session | 1h | 15m
	recentMax = 0,             -- how many recent items (0 = all)
	sheetViews = false,        -- each sheet tab remembers its own view (Sheets page)
	sheetPrefs = {},           -- { bags = { [sheet] = { grp, sort, view, mergeStacks, collapsed } }, bank = { ... } }
	whatsNew = true,           -- show the What's New card after notable updates
	travelMode = false,        -- Travel Mode (the signpost beside the close button): toolbar hidden, search in the title row
	travelLeaveBank = true,    -- Auto Travel Mode: off while the bank is open, back on after
	travelLeaveAH = true,      -- ... the auction house
	travelLeaveVendor = true,  -- ... a vendor
	travelLeaveTaxi = true,    -- ... a flight path (back on after landing)
	travelLeaveTrade = true,   -- ... a trade window
	dimJunk = false,           -- junk items (grey and marked) shown greyed out and faded
	cleanOnOpen = false,       -- run Blizzard's Clean Up Bags each time the bags window opens
	makeRoom = true,           -- show the Loot Helper when loot won't fit
	autoSellJunk = false,      -- sell grey and junk-marked items on opening a vendor
	makeRoomValue = "ah",      -- rank Make Room's suggestions by "ah" (AH price when known, else vendor) or "vendor"
	priceSource = "auto",      -- (1.6.0) auction prices from "auto" (the installed one; Auctionator when both), "auctionator" or "blackthornes"
	shardKeep = 0,             -- Clear Soul Shards never offers your last N shards
	makeRoomAsk = false,       -- (1.5.1-beta2) the Loot Helper asks before destroying anything but junk (off: at once)
	makeRoomAskRare = true,    -- (1.5.1-beta2) ...and while that's off, still asks for rare quality or better, as the game does
	-- 1.2.0: auto-confirming the game's yes/no boxes (Core/Prompts.lua)
	autoConfirm = false,       -- off: nothing is ever clicked for you
	autoConfirmEverywhere = false, -- the boxes BagSmith confirms, wherever they come from (not only after a BagSmith action)
	autoConfirmEquip = true, autoConfirmUse = true, autoConfirmEnchant = true, autoConfirmRoll = false,
	autoConfirmKey = "always",   -- or "shift" / "ctrl" / "custom": the box is confirmed only while that key is held (custom: the Confirm Prompts keybinding)
	autoConfirmSrcGear = true, autoConfirmSrcItem = true, autoConfirmSrcJunk = true, autoConfirmSrcDE = true,   -- which BagSmith actions count
	-- 1.2.0: the Disenchant Helper (Core/Disenchant.lua)
	deEnabled = false,
	deMargin = 0.10,           -- disenchanting must beat selling by this fraction (shown as a percent) to be recommended
	deAhMargin = 0.20,         -- (1.6.0-beta8) selling at the AH, after its 5% cut, must beat the vendor by this fraction
	deLeveling = "auto",       -- (1.6.0-beta8) leveling Enchanting: "auto" (below the rank's cap), "always", "never"
	deIncludeEpics = false,
	deSkipRefundable = true,   -- refundable and still-tradeable items are left out
	makeRoomPos = false,
	bagBar = false,            -- the bag strip in the bags window (the footer button shows or hides it)
	hideBlizzBagBar = false,   -- fade out Blizzard's own bag bar (click-through; back at once when off)       -- where Make Room was dragged to ({ point, relPoint, x, y }), or false (beside the loot window)
	grp = "type",              -- none | type | bag
	sort = "quality",          -- quality | name | newest | oldest | ilvl | off (bag order)
	remember = true,
	collapsed = {},
	bankCollapsed = {},   -- the bank window's own collapsed sections
	hideJunk = false, minimap = true, animations = true,
	combatFade = true, combatAlpha = 0.15,   -- fade every BagSmith window during combat
	combatLock = true,                       -- and ignore clicks while faded
	lockWindows = false,                     -- (1.7.0-beta2) BagSmith's windows can't be moved or resized
	bgOpacity = 1,                           -- (1.6.0) the bag windows' frame and backdrop (items and text stay crisp)
	bgWhole = false,                         -- (1.6.0) Whole Window: the bag windows' items, text and buttons follow it too
	fadeMoving = false, movingAlpha = 0.5,   -- (1.6.0) the bag windows fade while the character moves (back on hover)
	helpTips = true,                         -- (1.6.0) tooltips on BagSmith's own controls (item tooltips always show)
	replaceBlizzardBags = true,   -- open with the bag keybind and stand in for Blizzard's bags
	-- Plugin preferences: one bounded plain-data namespace per plugin ID ({ schemaVersion, data }), owned by
	-- the plugin through BagSmith.API; core only persists and validates the shape.
	plugins = {},
	-- Legacy (0.15 development builds): controller browsing lived here. Kept, hidden, through the migration
	-- window so an explicit value can migrate once into plugins["bagsmith-gamepad"]; the setting has no UI.
	gamepadBrowse = false,
	replaceBank = true,           -- stand in for Blizzard's bank window too
	-- columns, lanes, tabs
	cols = { "c", "t", "bd", "v", "w", "age", "fv", "cc", "jk" },
	colOrder = { "c", "n", "t", "bd", "v", "w", "age", "fv", "cc", "jk", "il", "rq", "sl", "ah" },
	colWidths = {},            -- key -> pixels, set by dragging header edges
	-- (1.6.0-beta6, Shweep) the columns a narrow window may set aside, first to go first; the rest shrink to fit instead
	-- (1.6.0-beta8, Shweep) every column ticked; wide text columns go first, the small icon columns last. Qty and Item
	-- are never set aside.
	colAside = { "t", "age", "v", "ah", "w", "sl", "rq", "il", "bd", "fv", "cc", "jk" },
	bankColAside = { "t", "age", "v", "ah", "w", "sl", "rq", "il", "bd", "fv", "cc", "jk" },
	-- The bank window's own column layout (the Bank tab in the bags window uses the bags layout).
	bankCols = { "c", "t", "bd", "v", "w", "age", "fv", "cc", "jk" },
	bankColOrder = { "c", "n", "t", "bd", "v", "w", "age", "fv", "cc", "jk", "il", "rq", "sl", "ah" },
	fvccCols = true,           -- the Favorite and Currency columns have been added to this profile's columns once (0.13)
	favItems = {},             -- favorited items (item IDs), shown in the Favorites section
	customSections = {},       -- your own sections: { id = "c1", name = "Professions" }, ...
	sectionMoves = {},         -- [itemID] = section id: items moved to another section
	sectionHide = {},          -- [section id] = { vendor = true, ah = true }: hidden there
	newdotClearRecent = true,  -- Clear Recent also clears the green dots
	showEmptySections = true,  -- custom sections show even when empty (each can opt out)
	itemMenuButton = true,     -- the item menu button (three dots) on list rows
	sectionNextId = 1,         -- the next custom section number (ids are never reused)
	favSection = true,         -- the Favorites section at the top
	gearSetSections = true,    -- each of the game's gear sets shows as a section (0.15)
	gearSetsPlaced = true,     -- Gear Sets moved to the bottom of Section Order and its tab before Bank, once (0.15)
	customCurrencies = {},     -- items tracked as currencies (item IDs), kept even when none are carried
	jkCol = true,              -- the Junk column has been added to this profile's columns once (0.13)
	bankColWidths = {},
	pinnedSections = {},       -- section id -> true: shown at the top, after Recent (1.4.0)
	pinnedHighlight = false, pinnedHighlightAlpha = 0.15,   -- (1.7.0-beta2) an accent background behind pinned sections
	-- Icon corners (1.5.0): each corner's widgets in priority order; corners the player has arranged; widgets from
	-- other addons already placed once (one removed stays removed)
	iconCorners = { top_left = { "junk" }, top_right = { "item_level" }, bottom_left = { "pawn", "equipment_set" }, bottom_right = { "quantity" } },
	iconCornersTouched = {},
	iconCornersInserted = {},
	iconCornersSeen = {},
	splitCons = false,         -- (1.5.0-beta9) Split Consumables by Type
	splitConsTypes = {},       -- kind -> false to keep that type in Consumables (missing means split)      -- (1.5.0-beta8) other addons' marks the player has done something with (no longer "new")
	splitGear = false,         -- (1.7.0-beta6) Split Gear by Binding
	splitGearTypes = {},       -- (1.7.0-beta6) Soulbound/BoE -> false to keep it in Gear (missing means split)
	laneOrder = { "~recent", "~fav", "Gear", "Consumables", "Reagents", "TradeGoods", "Recipes", "Quest", "Tokens", "Other", "Junk", "~ky", "~rb", "~gs" },
	tabOrder = { "All", "Gear", "Consumables", "TradeGoods", "Quest", "Junk", "GearSets", "Bank" },
	hiddenTabs = {},
	sheets = {},               -- { { n = name, f = filters } }
	bankSheets = {},           -- the bank window's own saved sheets
	bankTabOrder = {},
	bankHiddenTabs = {},
	fav = {},                  -- currency keys, e.g. "c:3402" or "i:20558"
	blizzUnpinned = {},        -- (1.7.1-beta1) currency ID -> true: unpinned in this profile, never pinned again by the game's picks
	-- size
	scale = 1.0, sizeMode = "fixed", maxW = 680, maxH = 720, fixW = 620, fixH = 560,   -- new players start Scalable ("fixed")
	iconSize = 37, rowHeight = 26,
	iconItemLevel = false,        -- Icons view: the item level in the icon's top-right corner, for weapons and armor (1.0.2)
	iconItemLevelColor = "3598db", -- hex; its own color so it reads apart from the stack count
	point = { "BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -80, 140 },
	bankPoint = { "TOPLEFT", "UIParent", "TOPLEFT", 40, -120 },
	bankW = 620, bankH = 520,
	bagCols = 6, bagScale = 1.0, bagMaxH = 320,   -- the small bag and reagent windows
	settingsPoint = { "CENTER", "UIParent", "CENTER", 0, 40 },
	minimapAngle = 220,
	minimapFade = false,   -- show the minimap button only while the pointer is over the minimap
}
local CHAR_DEFAULTS = { version = 1, firstSeen = {}, seen = {}, seenSlots = {}, recentSince = 0, recentSticky = {}, junkMarks = {}, makeRoomNever = {}, makeRoomProtect = {}, professionMats = {},
	deNever = {}, deResults = {}, deResultsVersion = 0, deOfferDeclined = false,
	blizzPicksSeen = {} }   -- (1.7.0-beta14) currency ID -> true: the game's Show on Backpack picks already pinned once   -- the Disenchant Helper's per-character data (1.2.0): the never list, learned results and their schema version, the declined offer   -- recentSince: start of the Recent section's session (0 = not set)   -- seen: guid -> count at dismissal; seenSlots: "bag:slot" -> "itemID:count"

local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
local function oneOf(...) local set = {}; for i = 1, select("#", ...) do set[select(i, ...)] = true end
	return function(v) return set[v] and v or nil end end
local function num(lo, hi, int) return function(v)
	if type(v) ~= "number" then return nil end
	if int then v = math.floor(v + 0.5) end
	return clamp(v, lo, hi) end end
-- A list of item IDs (whole positive numbers), duplicates dropped.
local function idList(v)
	if type(v) ~= "table" then return nil end
	local out, seen = {}, {}
	for _, id in ipairs(v) do
		if type(id) == "number" and id > 0 and id < 10000000 and id == math.floor(id) and not seen[id] then seen[id] = true; out[#out + 1] = id end
	end
	return out
end
local function strList(allowed) return function(v)
	if type(v) ~= "table" then return nil end
	local out, seen = {}, {}
	for _, x in ipairs(v) do if type(x) == "string" and (not allowed or allowed[x]) and not seen[x] then out[#out + 1] = x; seen[x] = true end end
	return out end end
local function ordered(allowed, all) return function(v)
	local out = strList(allowed)(v) or {}
	local seen = {}
	for _, x in ipairs(out) do seen[x] = true end
	for _, x in ipairs(all) do if not seen[x] then out[#out + 1] = x end end
	return out end end
local ANCHORS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }
local function finite(n) return type(n) == "number" and n == n and n > -1e6 and n < 1e6 end
local function pointV(v)
	if type(v) ~= "table" or not ANCHORS[v[1]] or not ANCHORS[v[3]] or not finite(v[4]) or not finite(v[5]) then return nil end
	return { v[1], "UIParent", v[3], v[4], v[5] }
end
local COL_SET, LANE_SET = {}, {}
for _, c in ipairs(ns.COLS) do COL_SET[c[1]] = true end
local ORDER_SET = { n = true }
local ASIDE_SET = {}   -- (1.6.0-beta8) the columns Narrow Windows may set aside: all but Qty (and Item, which isn't in COL_SET)
for k in pairs(COL_SET) do if k ~= "c" then ASIDE_SET[k] = true end end
for k in pairs(COL_SET) do ORDER_SET[k] = true end
for _, c in ipairs(ns.CATS) do if c ~= "Keys" then LANE_SET[c] = true end end
LANE_SET["~ky"], LANE_SET["~rb"], LANE_SET["~recent"], LANE_SET["~fav"] = true, true, true, true
LANE_SET["~gs"] = true   -- every gear set takes this one place in Section Order
-- (1.6.3-beta1, Shweep: an item moved to Food went back after a /reload) Split Consumables' sections (1.5.0-beta9) are
-- built-in sections too: the check at load now keeps moves to them, their place in Section Order and their vendor and
-- AH hiding (it dropped all three, so every reload undid them; profile sharing runs the same check).
for _, k in ipairs(ns.CONS_KINDS) do LANE_SET[ns.CONS_ID[k]] = true end
for _, k in ipairs(ns.GEAR_KINDS) do LANE_SET[ns.GEAR_ID[k]] = true end   -- (1.7.0-beta6) from the start (the 1.6.3 lesson)

-- One rule for sheet names, used by Save Sheet, rename, import and load: some
-- text, and not a built-in tab's name. (No length or count limit, so a sheet
-- that could be saved is never dropped later.)
function ns.SheetNameOK(name)
	return type(name) == "string" and name:match("%S") ~= nil and not (ns.TAB_LABEL and ns.TAB_LABEL[name])
end
local function sheetsValidator(v)
	if type(v) ~= "table" then return nil end
	local out, seen = {}, {}
	for _, s in ipairs(v) do
		if type(s) == "table" and ns.SheetNameOK(s.n) and not seen[s.n] and type(s.f) == "table" then
			seen[s.n] = true
			out[#out + 1] = { n = s.n, f = ns.CleanFilters and ns.CleanFilters(s.f) or s.f }
		end
	end
	return out
end

-- The Disenchant Helper's per-character records (1.2.0): a never list of item IDs, learned results per bracket
-- (a count and a materials table of counts), the schema version and the declined offer. Malformed parts are
-- dropped rather than kept to error later.
local function deNeverValidator(v)
	if type(v) ~= "table" then return nil end
	local out = {}
	for id, on in pairs(v) do if type(id) == "number" and on == true then out[id] = true end end
	return out
end
local function finite(x) return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge end
local function deResultsValidator(v)
	if type(v) ~= "table" then return nil end
	local out = {}
	for key, e in pairs(v) do
		if type(key) == "string" and type(e) == "table" and finite(e.n) and e.n >= 0 and type(e.mats) == "table" then
			local mats, seen, okEntry = {}, {}, true
			for id, c in pairs(e.mats) do if finite(id) and finite(c) and c >= 0 then mats[id] = c else okEntry = false end end
			if type(e.seen) == "table" then for id, c in pairs(e.seen) do if finite(id) and finite(c) and c >= 0 then seen[id] = c end end end
			if okEntry then out[key] = { n = math.floor(e.n), mats = mats, seen = seen } end
		end
	end
	return out
end
local validators = {
	deNever = deNeverValidator, deResults = deResultsValidator,
	makeRoomProtect = deNeverValidator,   -- (1.7.0-beta1) the Loot Helper's Protected Items: item ID -> true, like the DE list
	blizzPicksSeen = deNeverValidator,   -- (1.7.0-beta14) currency ID -> true
	blizzUnpinned = deNeverValidator,    -- (1.7.1-beta1) currency ID -> true, per profile
	-- (1.7.0-beta3) the materials each profession's recipes use: profession name -> item ID -> true
	professionMats = function(v)
		if type(v) ~= "table" then return nil end
		local out = {}
		for prof, set in pairs(v) do
			if type(prof) == "string" and type(set) == "table" then
				local ids = {}
				for id, on in pairs(set) do if type(id) == "number" and on == true then ids[id] = true end end
				out[prof] = ids
			end
		end
		return out
	end,
	deResultsVersion = function(v) return finite(v) and v or nil end,
	deOfferDeclined = function(v) return v == true or false end,
	bankSheets = sheetsValidator,
	skin = oneOf("modern", "classic"), border = oneOf("all", "unc", "off"),
	accent = function(v) v = type(v) == "string" and v:lower():gsub("^#", "") or ""; return v:match("^%x%x%x%x%x%x$") and v or nil end,
	iconItemLevelColor = function(v) v = type(v) == "string" and v:lower():gsub("^#", "") or ""; return v:match("^%x%x%x%x%x%x$") and v or nil end,
	view = oneOf("list", "icons"), side = oneOf("left", "right"),
	bagPoints = function(v)
		if type(v) ~= "table" then return nil end
		local out = {}
		for k, p in pairs(v) do local pv = pointV(p); if pv then out[tostring(k)] = pv end end
		return out
	end,
	reagent = oneOf("inline", "lane"), makeRoomValue = oneOf("ah", "vendor"), priceSource = oneOf("auto", "auctionator", "blackthornes"), deMargin = num(0, 2), deAhMargin = num(0, 2), deLeveling = oneOf("auto", "always", "never"), autoConfirmKey = oneOf("always", "shift", "ctrl", "custom"), grp = oneOf("none", "type", "bag"),
	recentWindow = oneOf("session", "1h", "15m"), recentMax = num(0, 200, true),
	sheetPrefs = function(v)
		if type(v) ~= "table" then return nil end
		local out = {}
		for _, win in ipairs({ "bags", "bank" }) do
			out[win] = {}
			if type(v[win]) == "table" then
				for sheet, p in pairs(v[win]) do
					if type(sheet) == "string" and type(p) == "table" then
						local q = {}
						if oneOf("none", "type", "bag")(p.grp) then q.grp = p.grp end
						if oneOf("quality", "name", "newest", "oldest", "ilvl", "off")(p.sort) then q.sort = p.sort end
						if oneOf("list", "icons")(p.view) then q.view = p.view end
						if type(p.mergeStacks) == "boolean" then q.mergeStacks = p.mergeStacks end
						q.collapsed = strList(nil)(p.collapsed) or {}
						out[win][sheet] = q
					end
				end
			end
		end
		return out
	end,
	sort = oneOf("quality", "name", "newest", "oldest", "ilvl", "off"), sizeMode = oneOf("auto", "fixed"),
	bankGrp = oneOf("none", "type", "bag"), bankSort = oneOf("quality", "name", "newest", "oldest", "ilvl", "off"), bankView = oneOf("list", "icons"),
	combatAlpha = num(0.05, 1), bgOpacity = num(0, 1), pinnedHighlightAlpha = num(0.05, 0.5), movingAlpha = num(0.05, 1), scale = num(0.5, 1.5), bagCols = num(4, 12, true), bagScale = num(0.5, 1.5), bagMaxH = num(200, 800, true), shardKeep = num(0, 40, true), maxW = num(440, 1400, true), maxH = num(300, 1200, true),
	fixW = num(440, 1400, true), bankW = num(500, 1400, true), bankH = num(300, 1200, true), fixH = num(300, 1200, true), iconSize = num(24, 48, true), rowHeight = num(20, 32, true),
	minimapAngle = num(0, 360), point = pointV, bankPoint = pointV, settingsPoint = pointV,
	makeRoomPos = function(v) if v == false then return false end return pointV(v) end,
	cols = strList(COL_SET), colOrder = ordered(ORDER_SET, DEFAULTS.colOrder), colAside = strList(ASIDE_SET),
	colWidths = function(v)
		if type(v) ~= "table" then return nil end
		local out = {}
		for k, w in pairs(v) do if COL_SET[k] and type(w) == "number" then out[k] = clamp(math.floor(w), 30, 400) end end
		return out
	end, iconCorners = function(v)
		if type(v) ~= "table" then return nil end
		local out, seen = {}, {}
		-- (1.6.0-beta6, the beta5 audit's F6) up to 16 marks a corner, not counting the locked built-ins (Quest Starter, Stack
		-- Count), which every profile carries: adding Quest Starter to a full corner never pushes a mark out
		local C = ns.Corners
		local function locked(id) if C and C.IsLocked then return C:IsLocked(id) end return id == "quest_start" or id == "quantity" end
		for _, corner in ipairs({ "top_left", "top_right", "bottom_left", "bottom_right" }) do
			out[corner] = {}
			local others = 0
			for _, id in ipairs(type(v[corner]) == "table" and v[corner] or {}) do
				if type(id) == "string" and id ~= "" and #id <= 64 and id:match("^[%w_%-%.:]+$") and not seen[id] then
					local isLocked = locked(id)
					if isLocked or others < 16 then
						seen[id] = true; out[corner][#out[corner] + 1] = id
						if not isLocked then others = others + 1 end
					end
				end
			end
		end
		return out
	end, iconCornersTouched = function(v)
		if type(v) ~= "table" then return nil end
		local out = {}
		for _, corner in ipairs({ "top_left", "top_right", "bottom_left", "bottom_right" }) do if v[corner] == true then out[corner] = true end end
		return out
	end, splitConsTypes = function(v)
		if type(v) ~= "table" then return nil end
		local out = {}
		for k, on in pairs(v) do if ns.CONS_ID[k] and type(on) == "boolean" then out[k] = on end end
		return out
	end, splitGearTypes = function(v)   -- (1.7.0-beta6)
		if type(v) ~= "table" then return nil end
		local out = {}
		for k, on in pairs(v) do if ns.GEAR_ID[k] and type(on) == "boolean" then out[k] = on end end
		return out
	end, iconCornersSeen = function(v)
		if type(v) ~= "table" then return nil end
		local out = {}
		for id, on in pairs(v) do if type(id) == "string" and id ~= "" and #id <= 64 and on == true then out[id] = true end end
		return out
	end, iconCornersInserted = function(v)
		if type(v) ~= "table" then return nil end
		local out = {}
		for id, on in pairs(v) do if type(id) == "string" and id ~= "" and #id <= 64 and on == true then out[id] = true end end
		return out
	end, pinnedSections = function(v)
		if type(v) ~= "table" then return nil end
		local out = {}
		for id, on in pairs(v) do if type(id) == "string" and id ~= "" and id:sub(1, 1) ~= "~" and on == true then out[id] = true end end
		return out
	end, laneOrder = function(v)
		-- Built-in and special sections, plus custom ones ("c1"...).
		local out = ordered(setmetatable({}, { __index = function(_, k) return LANE_SET[k] or (type(k) == "string" and k:match("^c%d+$") ~= nil) end }), DEFAULTS.laneOrder)(v)
		return out
	end,
	customSections = function(v)
		if type(v) ~= "table" then return nil end
		local out, seen = {}, {}
		for _, c in ipairs(v) do
			if type(c) == "table" and type(c.id) == "string" and c.id:match("^c%d+$") and not seen[c.id]
				and type(c.name) == "string" and c.name:match("%S") then
				seen[c.id] = true
				-- showEmpty: only "false" is stored (missing means on).
				local entry = { id = c.id, name = c.name:sub(1, 40) }
				if c.showEmpty == false then entry.showEmpty = false end
				out[#out + 1] = entry
			end
		end
		return out
	end,
	sectionMoves = function(v)
		if type(v) ~= "table" then return nil end
		local out = {}
		for id, to in pairs(v) do
			if type(id) == "number" and id > 0 and id < 10000000 and id == math.floor(id) and type(to) == "string"
				and (LANE_SET[to] or to:match("^c%d+$")) and not to:match("^~") and to ~= "Junk" then out[id] = to end
		end
		return out
	end,
	sectionNextId = function(v) return type(v) == "number" and v >= 1 and v <= 1000000 and math.floor(v) or nil end,
	sectionHide = function(v)
		if type(v) ~= "table" then return nil end
		local out = {}
		for id, h in pairs(v) do
			if type(id) == "string" and (LANE_SET[id] or id:match("^c%d+$")) and type(h) == "table" then
				local x = { vendor = h.vendor == true or nil, ah = h.ah == true or nil }
				if next(x) then out[id] = x end
			end
		end
		return out
	end,
	collapsed = strList(nil), fav = strList(nil), hiddenTabs = strList(nil), favItems = idList, customCurrencies = idList,
	tabOrder = strList(nil), bankTabOrder = strList(nil), bankHiddenTabs = strList(nil),

	sheets = function(v)
		if type(v) ~= "table" then return nil end
		local out, seen = {}, {}
		for _, s in ipairs(v) do
			if type(s) == "table" and ns.SheetNameOK(s.n) and not seen[s.n] and type(s.f) == "table" then
				seen[s.n] = true
				out[#out + 1] = { n = s.n, f = ns.CleanFilters and ns.CleanFilters(s.f) or s.f }
			end
		end
		return out
	end,
}

local copy = ns.Copy
validators.bankCols = validators.cols
validators.bankCollapsed = validators.collapsed
validators.bankColOrder = validators.colOrder
validators.bankColAside = validators.colAside
validators.bankColWidths = validators.colWidths

-- Plugin preference data: plain and bounded. Strings, booleans, finite numbers and plain tables with string or
-- number keys, at most 6 levels deep and 64 KB when serialized; no functions, userdata, threads, cycles or
-- metatables. Returns a clean copy, or nil and why.
local PLUGIN_DEPTH, PLUGIN_BYTES, PLUGIN_STRING = 6, 64 * 1024, 4096
local function cleanPluginData(v, depth, seen, budget)
	local t = type(v)
	if t == "string" then if #v > PLUGIN_STRING then return nil, "a string is longer than " .. PLUGIN_STRING end budget.n = budget.n + #v; return v end
	if t == "boolean" then return v end
	if t == "number" then if v ~= v or v == math.huge or v == -math.huge then return nil, "a number is not finite" end budget.n = budget.n + 8; return v end
	if t ~= "table" then return nil, "a " .. t .. " is not plain data" end
	if getmetatable(v) ~= nil then return nil, "a table has a metatable" end
	if seen[v] then return nil, "a table refers to itself" end
	if depth > PLUGIN_DEPTH then return nil, "data is nested deeper than " .. PLUGIN_DEPTH end
	seen[v] = true
	local out = {}
	for k, x in pairs(v) do
		local kt = type(k)
		if kt ~= "string" and kt ~= "number" then return nil, "a key is a " .. kt end
		if kt == "number" and (k ~= k or k == math.huge or k == -math.huge) then return nil, "a numeric key is not finite" end
		if kt == "string" then budget.n = budget.n + #k else budget.n = budget.n + 8 end
		local c, why = cleanPluginData(x, depth + 1, seen, budget)
		if why then return nil, why end
		out[k] = c
	end
	seen[v] = nil
	if budget.n > PLUGIN_BYTES then return nil, "data is larger than " .. PLUGIN_BYTES .. " bytes" end
	return out
end
function ns.ValidatePluginData(v)
	if type(v) ~= "table" then return nil, "preferences must be a table" end
	local budget = { n = 0 }
	local clean, why = cleanPluginData(v, 1, {}, budget)
	if why then return nil, why end
	return clean, nil, budget.n
end
-- The size (the same measure the validator uses) of plugin data already stored; for the aggregate cap.
function ns.PluginDataSize(v)
	if type(v) ~= "table" then return 0 end
	local budget = { n = 0 }
	local _, why = cleanPluginData(v, 1, {}, budget)
	if why then return 0 end
	return budget.n
end
ns.PLUGIN_DATA_AGGREGATE = 192 * 1024   -- all plugin namespaces of one profile together (keeps every profile exportable)
-- A schema version is a finite non-negative integer (so every saved profile round-trips through export/import).
function ns.ValidSchemaVersion(v)
	return type(v) == "number" and v == v and v >= 0 and v < 2^31 and math.floor(v) == v
end
-- The whole container: { [id] = { schemaVersion = n, data = {...} } }; damaged entries are dropped one by one.
local function cleanPluginContainer(v)
	local out, repaired = {}, false
	if type(v) ~= "table" then return out, v ~= nil end
	for id, entry in pairs(v) do
		if type(id) == "string" and id:match("^[%w%-%._]+$") and type(entry) == "table" then
			local data = ns.ValidatePluginData(entry.data)
			local sv = entry.schemaVersion
			if data and ns.ValidSchemaVersion(sv) then out[id] = { schemaVersion = sv, data = data } else repaired = true end
		else repaired = true end
	end
	return out, repaired
end
validators.plugins = function(v) local out = cleanPluginContainer(v); return out end
local function validate(saved, defaults)
	local out = copy(defaults)
	if type(saved) ~= "table" then return out, false end
	local repaired = false
	for key, def in pairs(defaults) do
		local v = saved[key]
		if v == nil then
		elseif validators[key] then
			local ok = validators[key](v)
			if ok ~= nil then out[key] = ok else repaired = true end
		elseif type(v) == type(def) then
			out[key] = type(v) == "table" and copy(v) or v
		else
			repaired = true
		end
	end
	return out, repaired
end

-- Tab order and hidden tabs depend on the sheet list, so they are fixed up
-- after field validation and only for profile tables.
local function fixTabs(out)
	if type(out.sheets) ~= "table" then out.sheets = {} end
	if type(out.tabOrder) ~= "table" then out.tabOrder = {} end
	if type(out.hiddenTabs) ~= "table" then out.hiddenTabs = {} end
	local known = {}
	for _, t in ipairs(ns.BASE_TABS) do known[t] = true end
	for _, s in ipairs(out.sheets) do known[s.n] = true end
	local tabs, seen = {}, {}
	for _, t in ipairs(out.tabOrder) do if known[t] and not seen[t] then tabs[#tabs + 1] = t; seen[t] = true end end
	for _, t in ipairs(ns.BASE_TABS) do if not seen[t] then tabs[#tabs + 1] = t; seen[t] = true end end
	for _, s in ipairs(out.sheets) do if not seen[s.n] then tabs[#tabs + 1] = s.n; seen[s.n] = true end end
	out.tabOrder = tabs
	local hid = {}
	for _, t in ipairs(out.hiddenTabs) do if known[t] and t ~= "All" then hid[#hid + 1] = t end end
	out.hiddenTabs = hid
	-- Bank tabs: built-ins except Bank, then the bank's own sheets.
	if type(out.bankSheets) ~= "table" then out.bankSheets = {} end
	if type(out.bankTabOrder) ~= "table" then out.bankTabOrder = {} end
	local bknown = {}
	for _, t in ipairs(ns.BASE_TABS) do if not NOT_BANK_TABS[t] then bknown[t] = true end end
	for _, s in ipairs(out.bankSheets) do bknown[s.n] = true end
	local btabs, bseen = {}, {}
	for _, t in ipairs(out.bankTabOrder) do if bknown[t] and not bseen[t] then btabs[#btabs + 1] = t; bseen[t] = true end end
	for _, t in ipairs(ns.BASE_TABS) do if not NOT_BANK_TABS[t] and not bseen[t] then btabs[#btabs + 1] = t; bseen[t] = true end end
	for _, s in ipairs(out.bankSheets) do if not bseen[s.n] then btabs[#btabs + 1] = s.n; bseen[s.n] = true end end
	out.bankTabOrder = btabs
	if type(out.bankHiddenTabs) ~= "table" then out.bankHiddenTabs = {} end
	local bhid = {}
	for _, t in ipairs(out.bankHiddenTabs) do if bknown[t] and t ~= "All" then bhid[#bhid + 1] = t end end
	out.bankHiddenTabs = bhid
	return out
end

-- Profile tables get field validation plus the tab fixup.
ns.MAX_SECTION_ID = 999999
-- A saved sheet whose name a built-in tab now uses (0.15 added "GearSets",
-- a name a 0.14 sheet could have) is renamed, never dropped: "GearSets (2)",
-- or the next free number. Its tab order entry, hidden state and saved view
-- move with it, bags and bank. Runs before anything else reads tab names,
-- so the 0.15 migration then adds the built-in tab as for any profile. A
-- second load finds nothing to rename.
local function renameClashingSheets(saved)
	if type(saved) ~= "table" then return end
	for _, w in ipairs({ { "sheets", "tabOrder", "hiddenTabs", "bags" }, { "bankSheets", "bankTabOrder", "bankHiddenTabs", "bank" } }) do
		local list = saved[w[1]]
		if type(list) == "table" then
			local taken = {}
			for _, s in ipairs(list) do if type(s) == "table" and type(s.n) == "string" then taken[s.n] = true end end
			for _, s in ipairs(list) do
				if type(s) == "table" and type(s.n) == "string" and ns.TAB_LABEL[s.n] then
					local old, n, new = s.n, 2, nil
					repeat new = ("%s (%d)"):format(old, n); n = n + 1 until not taken[new] and not ns.TAB_LABEL[new]
					taken[new] = true
					s.n = new
					for _, key in ipairs({ w[2], w[3] }) do
						local t = saved[key]
						if type(t) == "table" then for i, v in ipairs(t) do if v == old then t[i] = new end end end
					end
					local prefs = type(saved.sheetPrefs) == "table" and saved.sheetPrefs[w[4]]
					if type(prefs) == "table" and prefs[old] ~= nil and prefs[new] == nil then prefs[new], prefs[old] = prefs[old], nil end
				end
			end
		end
	end
end

local function validateProfile(saved)
	renameClashingSheets(saved)
	-- 0.13: the Favorite and Currency columns join once, just before Junk.
	if type(saved) == "table" and saved.fvccCols == nil then
		for _, key in ipairs({ "cols", "bankCols", "colOrder", "bankColOrder" }) do
			local list = saved[key]
			if type(list) == "table" then
				for _, add in ipairs({ "fv", "cc" }) do
					if not ns.IndexOf(list, add) then
						local at = ns.IndexOf(list, "jk") or (#list + 1)
						table.insert(list, at, add)
					end
				end
			end
		end
		saved.fvccCols = true
	end
	-- 0.13: the Junk column joins each profile's columns once (players can
	-- turn it off afterwards; the flag stops it coming back).
	if type(saved) == "table" and saved.jkCol == nil then
		for _, key in ipairs({ "cols", "bankCols" }) do
			if type(saved[key]) == "table" and not ns.IndexOf(saved[key], "jk") then table.insert(saved[key], "jk") end
		end
		saved.jkCol = true
	end
	-- An earlier test version had "Icon Columns" (1 or 2); two columns becomes Icon Split View.
	if type(saved) == "table" and saved.iconColumns == 2 and saved.splitView == nil then saved.splitView = true end
	-- Bag windows on open: "all bags" includes the reagent bag. The old Reagent
	-- Bag: Own Window becomes Own Section with the reagent bag's window opening
	-- with the bags.
	if type(saved) == "table" then
		if saved.reagent == "pop" then saved.reagent = "lane"; saved.reagentWindow = true end
		if saved.bagWindows == true then saved.reagentWindow = true end
	end
	-- Recent joins the section order at the top (a missing entry would
	-- otherwise be added at the bottom).
	if type(saved) == "table" and type(saved.laneOrder) == "table" then
		local has = false
		for _, id in ipairs(saved.laneOrder) do if id == "~recent" then has = true end end
		if not has then table.insert(saved.laneOrder, 1, "~recent") end
		-- Favorites joins right after Recent.
		local fav = false
		for _, id in ipairs(saved.laneOrder) do if id == "~fav" then fav = true end end
		if not fav then
			local at = 1
			for i, id in ipairs(saved.laneOrder) do if id == "~recent" then at = i + 1 end end
			table.insert(saved.laneOrder, at, "~fav")
		end
		-- (beta2 and beta3 kept Show at Vendor / AH per set; now every set shares
		-- "~gs": a set hidden anywhere keeps Gear Sets hidden there.)
		local hide = type(saved.sectionHide) == "table" and saved.sectionHide
		if hide then
			local old = {}
			for id, h in pairs(hide) do if type(id) == "string" and id:sub(1, 4) == "~gs:" then old[#old + 1] = id end end
			for _, id in ipairs(old) do
				local h = hide[id]
				if type(h) == "table" then
					local g = type(hide["~gs"]) == "table" and hide["~gs"] or {}
					g.vendor = (g.vendor == true or h.vendor == true) or nil
					g.ah = (g.ah == true or h.ah == true) or nil
					if next(g) then hide["~gs"] = g end
				end
				hide[id] = nil
			end
		end
		-- Gear Sets (0.15) joins at the very bottom.
		if not ns.IndexOf(saved.laneOrder, "~gs") then table.insert(saved.laneOrder, "~gs") end
	end
	-- The Gear Sets tab (0.15) joins just before Bank (else last).
	local function beforeBank(order)
		local at = #order + 1
		for i, t in ipairs(order) do if t == "Bank" then at = i end end
		table.insert(order, at, "GearSets")
	end
	if type(saved) == "table" and type(saved.tabOrder) == "table" and not ns.IndexOf(saved.tabOrder, "GearSets") then beforeBank(saved.tabOrder) end
	-- Once: beta2 to beta5 put Gear Sets right after Favorites and its tab
	-- right after Gear. Where they still are, they move to their new places;
	-- anywhere else, you moved them yourself, so they stay.
	if type(saved) == "table" and saved.gearSetsPlaced == nil then
		local lanes, tabs = saved.laneOrder, saved.tabOrder
		if type(lanes) == "table" then
			local i, f = ns.IndexOf(lanes, "~gs"), ns.IndexOf(lanes, "~fav")
			if i and f and i == f + 1 then table.remove(lanes, i); table.insert(lanes, "~gs") end
		end
		if type(tabs) == "table" then
			local i, g = ns.IndexOf(tabs, "GearSets"), ns.IndexOf(tabs, "Gear")
			if i and g and i == g + 1 then table.remove(tabs, i); beforeBank(tabs) end
		end
		saved.gearSetsPlaced = true
	end
	local out, repaired = validate(saved, DEFAULTS)
	-- A sheet's custom-section categories are checked against THIS profile's
	-- sections (never the active profile's: this may be an import).
	for _, key in ipairs({ "sheets", "bankSheets" }) do
		for _, sh in ipairs(type(out[key]) == "table" and out[key] or {}) do
			if type(sh) == "table" and ns.PruneFilterCategories then ns.PruneFilterCategories(sh.f, out.customSections) end
		end
	end
	-- Section numbers are never reused: start this profile's counter above
	-- every custom-section id it still refers to (profiles from 0.14.0-beta1
	-- and imported codes have no counter of their own). Only the fields that
	-- hold section ids count, never names or search text; numbers past
	-- MAX_SECTION_ID are ignored.
	local high = 0
	local function id(v)
		local n = type(v) == "string" and tonumber(v:match("^c(%d%d?%d?%d?%d?%d?)$"))
		if n and n <= ns.MAX_SECTION_ID and n > high then high = n end
	end
	local function eachKey(t) if type(t) == "table" then for k in pairs(t) do id(k) end end end
	local function eachValue(t) if type(t) == "table" then for _, v in pairs(t) do id(v) end end end
	for _, c in ipairs(type(out.customSections) == "table" and out.customSections or {}) do id(c.id) end
	eachValue(out.sectionMoves); eachKey(out.sectionHide); eachValue(out.laneOrder)
	eachValue(out.collapsed); eachValue(out.bankCollapsed)
	for _, key in ipairs({ "sheets", "bankSheets" }) do
		for _, sh in ipairs(type(out[key]) == "table" and out[key] or {}) do
			if type(sh) == "table" and type(sh.f) == "table" then eachKey(sh.f.cat) end
		end
	end
	-- Each sheet's own collapse list (Sheet-Specific Views), bags and bank.
	for _, win in ipairs({ "bags", "bank" }) do
		local prefs = type(out.sheetPrefs) == "table" and out.sheetPrefs[win]
		if type(prefs) == "table" then
			for _, p in pairs(prefs) do if type(p) == "table" then eachValue(p.collapsed) end end
		end
	end
	if (out.sectionNextId or 1) <= high then out.sectionNextId = high + 1 end
	-- Legacy controller browsing (0.15 development builds): an explicit boolean migrates once into the
	-- Gamepad plugin's preferences, only when that namespace is absent; an existing destination always wins;
	-- the legacy field itself is kept for the rollback window. Runs for every profile and every import.
	if type(saved) == "table" and type(saved.gamepadBrowse) == "boolean" then
		out.plugins = type(out.plugins) == "table" and out.plugins or {}
		if out.plugins["bagsmith-gamepad"] == nil then out.plugins["bagsmith-gamepad"] = { schemaVersion = 1, data = { browse = saved.gamepadBrowse } } end
	end
	return fixTabs(out), repaired
end
ns.DEFAULTS, ns.validateSettings = DEFAULTS, validate

------------------------------------------------------------------------
-- Profiles
------------------------------------------------------------------------
local Profiles = {}
ns.Profiles = Profiles
local function cleanName(name)
	name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" or #name > 32 then return nil end
	return name
end
local function loadDB(saved)
	local repaired = false
	local db = { version = DB_VERSION, profiles = {}, chars = {}, cache = {} }
	-- The last What's New version seen, per account. Saved data from before
	-- What's New existed counts as "seen nothing yet"; no saved data at all
	-- (a first install) stays empty and is marked seen once loaded.
	if type(saved) == "table" then db.whatsNewSeen = type(saved.whatsNewSeen) == "string" and saved.whatsNewSeen or "0.0.0" end
	if type(saved) == "table" and type(saved.profiles) == "table" then
		for name, prof in pairs(saved.profiles) do
			local n = cleanName(name)
			if n then local v, r = validateProfile(prof); db.profiles[n] = v; repaired = repaired or r else repaired = true end
		end
		if type(saved.chars) == "table" then
			for char, prof in pairs(saved.chars) do
				if type(char) == "string" and type(prof) == "string" and db.profiles[prof] then db.chars[char] = prof else repaired = true end
			end
		end
		if type(saved.cache) == "table" then
			for char, data in pairs(saved.cache) do
				-- Skip entries saved before the realm was known (" - Unknown").
				if type(char) == "string" and type(data) == "table" and type(data.name) == "string"
					and not char:find(" %- Unknown$") and data.realm ~= "Unknown" then
					for _, key in ipairs({ "items", "bank" }) do
						if data[key] ~= nil and type(data[key]) ~= "table" then data[key] = nil; repaired = true end
						if type(data[key]) == "table" then
							local good = {}
							for _, r in ipairs(data[key]) do
								if type(r) == "table" and type(r.itemID) == "number" and type(r.bag) == "number" and type(r.slot) == "number" then
									if r.gearSets ~= nil and type(r.gearSets) ~= "table" then r.gearSets = nil; repaired = true end
									good[#good + 1] = r
								else repaired = true end
							end
							data[key] = good
						end
					end
					for _, key in ipairs({ "bags", "bankBags", "currencies" }) do
						if data[key] ~= nil and type(data[key]) ~= "table" then data[key] = nil; repaired = true end
					end
					db.cache[char] = data
				end
			end
		end
	elseif type(saved) == "table" then
		local v, r = validateProfile(saved); db.profiles[DEFAULT_PROFILE] = v; repaired = repaired or r
	end
	if not db.profiles[DEFAULT_PROFILE] then db.profiles[DEFAULT_PROFILE] = fixTabs(copy(DEFAULTS)) end
	return db, repaired
end
function Profiles:Active()
	local name = BagSmithDB.chars[ns:CharKey()] or DEFAULT_PROFILE
	if not BagSmithDB.profiles[name] then name = DEFAULT_PROFILE end
	return name, BagSmithDB.profiles[name]
end
function Profiles:List()
	local names = {}
	for name in pairs(BagSmithDB.profiles) do names[#names + 1] = name end
	table.sort(names, function(a, b)
		if a == b then return false end
		if a == DEFAULT_PROFILE then return true elseif b == DEFAULT_PROFILE then return false end
		return a < b end)
	return names
end
local function activate()
	local name, settings = Profiles:Active()
	ns.db, ns.profileName = settings, name
	-- A confirmation asked about the old profile state; it no longer applies.
	local c = ns.Popups and ns.Popups.confirm
	if c and c:IsShown() then c:Hide() end
	if ns.KeyBinds then ns.KeyBinds:CancelCapture() end
	-- Profile-dependent caches first, so nothing redraws from the old profile.
	if ns.Currency then ns.Currency:Invalidate() end
	-- Selected sheets that don't exist in this profile go back to All.
	if ns.ReconcileSheets then ns:ReconcileSheets() end
	ns:Fire("PROFILE_ACTIVATED")   -- (the plugin API's profile token and PROFILE_CHANGED notice)
	ns:Fire("SETTINGS_CHANGED")
end
function Profiles:Use(name)
	name = cleanName(name)
	if not name then return false, "Profile names must be 1 to 32 characters." end
	if name ~= self:Active() then ns.ui.collapseReset = true end   -- a real switch
	if not BagSmithDB.profiles[name] then
		local fresh = fixTabs(copy(ns.db))
		fresh.debug = false   -- a tester's debug setting never carries into a new profile
		BagSmithDB.profiles[name] = fresh
	end
	BagSmithDB.chars[ns:CharKey()] = name ~= DEFAULT_PROFILE and name or nil
	activate()
	return true
end
-- Profile Sharing: a decoded code becomes a new profile (never overwrites);
-- it goes through the same checks as saved settings at login.
function Profiles:Import(name, data)
	if type(data) ~= "table" then return nil, "That code is damaged." end
	name = cleanName(name) or "Imported"
	local base, n = name, 2
	while BagSmithDB.profiles[name] do
		name = cleanName(("%s (%d)"):format(base:sub(1, 26), n))
		n = n + 1
	end
	local v = validateProfile(data)
	v.debug = false
	BagSmithDB.profiles[name] = fixTabs(v)
	return name
end
function Profiles:CopyFrom(name)
	name = cleanName(name)
	local src = name and BagSmithDB.profiles[name]
	if not src then return false, "No profile named " .. tostring(name) .. "." end
	if name == ns.profileName then return false, "That is already the active profile." end
	BagSmithDB.profiles[ns.profileName] = copy(src)
	ns.ui.collapseReset = true   -- the active profile's content is replaced
	activate()
	return true
end
function Profiles:Delete(name)
	name = cleanName(name)
	if not name or not BagSmithDB.profiles[name] then return false, "No profile named " .. tostring(name) .. "." end
	if name == DEFAULT_PROFILE then return false, "The Default profile cannot be deleted." end
	if name == self:Active() then ns.ui.collapseReset = true end   -- this character falls back to Default
	BagSmithDB.profiles[name] = nil
	for char, prof in pairs(BagSmithDB.chars) do if prof == name then BagSmithDB.chars[char] = nil end end
	activate()
	return true
end
function Profiles:Reset(name)
	name = name or ns.profileName
	if not BagSmithDB.profiles[name] then return false, "No profile named " .. tostring(name) .. "." end
	if name == self:Active() then ns.ui.collapseReset = true end   -- the active profile is replaced
	BagSmithDB.profiles[name] = fixTabs(copy(DEFAULTS))
	activate()
	return true
end
function ns:ResetSettings() Profiles:Reset() end

------------------------------------------------------------------------
-- Load and write-through
------------------------------------------------------------------------
ns:On("ADDON_LOADED", function(name)
	if name ~= ADDON then return end
	local db, repaired = loadDB(BagSmithDB)
	BagSmithDB = db
	local cdb = validate(BagSmithCharDB, CHAR_DEFAULTS)
	if type(cdb.firstSeen) ~= "table" then cdb.firstSeen = {} end
	if type(cdb.seen) ~= "table" then cdb.seen = {} end
	if type(cdb.seenSlots) ~= "table" then cdb.seenSlots = {} end
	-- Damaged entries (edited or corrupted saved data) are dropped one by one;
	-- the rest of the history is kept.
	local dropped = 0
	local function keep(t, ok) for k, v in pairs(t) do if not ok(k, v) then t[k] = nil; dropped = dropped + 1 end end end
	local function num(v) return type(v) == "number" and v == v and v >= 0 and v < 1e12 end
	keep(cdb.firstSeen, function(k, v) return type(k) == "string" and num(v) end)
	keep(cdb.seen, function(k, v) return type(k) == "string" and num(v) end)
	keep(cdb.seenSlots, function(k, v) return type(k) == "string" and type(v) == "string" and v:match("^%d+:%d+$") ~= nil end)
	if dropped > 0 then repaired = true end
	BagSmithCharDB, ns.cdb = cdb, cdb
	local pname, settings = Profiles:Active()
	ns.db, ns.profileName = settings, pname
	if repaired then ns:Print("Some saved settings were invalid and have been reset to defaults.") end
	ns.loaded = true
	ns:Fire("ADDON_READY")
	ns:Fire("PROFILE_ACTIVATED")
end)

function ns:Set(key, value, silent)
	if DEFAULTS[key] == nil then error(("BagSmith: unknown setting %q"):format(tostring(key))) end
	if validators[key] then
		local v = validators[key](value)
		if v == nil then return false end
		ns.db[key] = v
	else
		if type(value) ~= type(DEFAULTS[key]) then return false end
		ns.db[key] = value
	end
	if not silent then ns:Fire("SETTINGS_CHANGED", key) end
	return true
end
function ns:Toggle(key) return ns:Set(key, not ns.db[key]) end
