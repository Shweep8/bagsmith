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
ns.COL_LABEL.who = "Who"   -- (1.9.0-beta2) Global Inventory's own column (not offered in Bag Columns)
-- (1.9.0-beta6) the columns Global Inventory can show besides its fixed ones: not Age, Favorite, Currency or Junk,
-- which are about one character's items. (beta7, Shweep: "allow AH to be turned off ... Vendor always") Item, Who,
-- Where and Vendor are fixed; AH Price is one of these, greyed without a price source as in Bag Columns.
ns.GLOBAL_COLS = { "c", "il", "rq", "t", "sl", "bd", "ah" }
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
	borderWeight = "normal",   -- normal | bold
	rtext = true, newdot = true, dense = false,
	-- layout
	view = "list",             -- list | icons
	bagWindows = false,        -- also open one window per bag
	bagPoints = {},            -- bag id (string) -> anchor
	side = "left",             -- left | right
	reagent = "lane",          -- inline (Mixed In) | lane (Own Section)
	keys = true, emptySlots = true,
	splitView = false,         -- icon view with sections: sections side by side in two columns (Sections page)
	footerTextScale = 1,       -- (1.9.0-beta8) Footer Text Size: the footer's text, 80% to 150% (Style page)
	globalResize = true,       -- (1.9.0-beta13) Resize for Global Inventory: its own size while it shows (Windows page)
	compactCategories = false, -- Icons + By Section: variable-width category rows
	splitViewRecentWide = false,   -- (1.7.0-beta2) Split View: Recent spans both columns instead of pairing
	splitViewPinnedWide = false,   -- (1.9.1-beta2, Shweep) Split and Compact View: each pinned section a full-width row
	recentSection = true,      -- a Recent section pinned at the top of the bags window (Sections page)
	recentWindow = "session",  -- session | 1h | 15m
	recentMax = 0,             -- how many recent items (0 = all)
	sheetViews = false,        -- each sheet tab remembers its own view (Sheets page)
	sheetPrefs = {},           -- { bags = { [sheet] = { grp, sort, view, mergeStacks, collapsed } }, bank = { ... } }
	whatsNew = true,           -- show the What's New card after notable updates
	travelMode = false,        -- Travel Mode (the signpost beside the close button): toolbar hidden, search in the title row
	travelLeaveBank = true,    -- Auto Travel Mode: off while the bank is open, back on after
	travelLeaveGuildBank = true,   -- ... the guild bank (1.8.0-beta23)
	-- Settings > Addon Sources (1.10.0-beta9: one switch per job, none depending on another)
	useItemTree = true,    -- (1.10.0-beta6) with the ItemTree addon installed, sections and filters can use what it knows
	makeRoomHoldItemTree = true,   -- (1.10.0-beta9; was itemTreeHold, beta7) the Loot Helper holds back what ItemTree says to keep
	deHoldItemTree = true,         -- ... and the Disenchant Helper, except what ItemTree keeps for its dust
	makeRoomHoldPawn = true,       -- (1.10.0-beta9) the Loot Helper holds back Pawn upgrades: as it always has, now a switch
	deHoldPawn = false,    -- (1.10.0-beta8, Shweep: "off ... should be default") the Disenchant Helper holds back Pawn upgrades
	tipInventory = true,   -- (1.9.0-beta1) item tooltips list your characters' counts
	tipAHPrice = true,     -- (1.9.0-beta2) an item's tooltip shows its AH price (with a price source); was only with the AH Price column
	bagSlotCount = "exclude",   -- (1.9.0-beta1, Shweep) the footer's free count: "exclude" special bags (1.8) or "all" free slots
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
	sectionValues = true,      -- (1.9.4-beta2, Shweep) Show Section Values: V and AH on section headers (off: on the name's hover)
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
	-- (1.11.0-beta2, Shweep: "something more like auto open with, and then list out all the places", then "The lighter
	-- version is good") Auto-Open and Auto-Close (Settings > Automations): a switch for each place BagSmith opens the
	-- bags at, all on, and one choice for what leaving does to them: "always" closes them (as ever), "auto" only closes
	-- bags that opened by themselves, "never" leaves them. The choice takes over from 1.10.1's Auto-Close Bags I Opened
	-- (autoCloseOwnBags: on is "always", off is "auto"; validateProfile carries a saved one across).
	autoOpenVendor = true, autoOpenMail = true, autoOpenTrade = true, autoOpenAH = true, autoOpenBank = true, autoOpenGuildBank = true,
	closeOnLeave = "always",
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
	customSections = {},       -- your own sections: { id = "c1", name = "Professions" }, ...; (1.10.0-beta1) in priority order,
	                           -- each with optional rules = { mode = "all" | "any", rows = { { k, v = {...}, n }, ... } }
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
	-- (1.10.0-beta10) "~all" is All Items, the list Sections: All shows: a section beside it there shows above it when
	-- it comes before it here, below when after. By Section and By Bag have no All Items and pass over it.
	laneOrder = { "~recent", "~fav", "Gear", "Consumables", "Reagents", "TradeGoods", "Recipes", "Quest", "Tokens", "Other", "Junk", "~all", "~ky", "~rb", "~gs" },
	tabOrder = { "All", "Gear", "Consumables", "TradeGoods", "Quest", "Junk", "GearSets", "Bank" },
	hiddenTabs = {},
	sheets = {},               -- { { n = name, f = filters } }
	bankSheets = {},           -- the bank window's own saved sheets
	bankTabOrder = {},
	bankHiddenTabs = {},
	fav = {},                  -- currency keys, e.g. "c:3402" or "i:20558"
	blizzUnpinned = {},        -- (1.7.1-beta1) currency ID -> true: unpinned in this profile, never pinned again by the game's picks
	-- size
	textScale = 1.0, fontName = "",   -- (1.8.0) Text Size (80% to 150%) and Font ("" = the game's) for the item windows
	scale = 1.0, sizeMode = "fixed", maxW = 680, maxH = 720, fixW = 620, fixH = 560,   -- new players start Scalable ("fixed")
	iconSize = 37, rowHeight = 26,
	iconItemLevel = false,        -- Icons view: the item level in the icon's top-right corner, for weapons and armor (1.0.2)
	iconItemLevelColor = "3598db", -- hex; its own color so it reads apart from the stack count
	unusableOverlayOpacity = 0.35, -- strength of the red wash (0 to 1); (1.9.2-beta2, Shweep: "default should be 35% opacity", was 50%)
	unusableOverlay = true,      -- red wash for unmet character requirements
	questFrame = true,         -- (1.8.0-beta11, Shweep) a gold frame on quest items, both skins
	point = { "BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -80, 140 },
	bankPoint = { "TOPLEFT", "UIParent", "TOPLEFT", 40, -120 },
	bankW = 620, bankH = 520,
	bagCols = 6, bagScale = 1.0, bagMaxH = 320,   -- the small bag and reagent windows
	settingsPoint = { "CENTER", "UIParent", "CENTER", 0, 40 },
	minimapAngle = 220,
	minimapFade = false,   -- show the minimap button only while the pointer is over the minimap
}
local CHAR_DEFAULTS = { version = 1, realm = "", realmFor = "", own = {}, firstSeen = {}, seen = {}, seenSlots = {}, recentSince = 0, recentSticky = {}, junkMarks = {}, makeRoomNever = {}, makeRoomProtect = {}, professionMats = {},
	deNever = {}, deResults = {}, deResultsVersion = 0, deOfferDeclined = false,
	deMaterials = {},   -- (1.8.0) the Disenchant Helper's learned materials: item ID -> true
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
LANE_SET["~all"] = true  -- (1.10.0-beta10) All Items, for Sections: All
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
-- (1.11.0-beta3) The Disenchant Helper's Results record (Core/Disenchant.lua, DE:Stats): how many disenchants, by
-- quality, what the items would have sold for, the materials they gave, and the most valuable item. Whole amounts, none
-- below zero; a piece that isn't is dropped (or reads as none), and the materials are capped at 200 kinds.
local function deStatsValidator(v)
	if type(v) ~= "table" then return nil end
	local function amount(x) return (finite(x) and x >= 0 and x < 1e15) and math.floor(x) or 0 end
	local function itemID(id) return type(id) == "number" and id > 0 and id < 10000000 and id == math.floor(id) end
	local out = { n = amount(v.n), vendor = amount(v.vendor), ah = amount(v.ah), ahN = amount(v.ahN), alt = amount(v.alt), q = {}, mats = {} }
	if type(v.q) == "table" then
		for q = 0, 7 do if finite(v.q[q]) and v.q[q] >= 1 then out.q[q] = math.floor(v.q[q]) end end
	end
	if type(v.mats) == "table" then
		local kept = 0
		for id, c in pairs(v.mats) do
			if kept < 200 and itemID(id) and finite(c) and c >= 1 then out.mats[id] = math.floor(c); kept = kept + 1 end
		end
	end
	local b = v.best
	if type(b) == "table" and itemID(b.id) and finite(b.worth) and b.worth >= 1 then
		out.best = {
			id = b.id, name = (type(b.name) == "string" and #b.name <= 120) and b.name or nil,
			q = (finite(b.q) and b.q >= 0 and b.q <= 7) and math.floor(b.q) or 1,
			vendor = amount(b.vendor), ah = (finite(b.ah) and b.ah >= 0) and math.floor(b.ah) or nil, worth = math.floor(b.worth),
		}
	end
	return out
end
-- (1.8.0) The Disenchant Helper's learned materials: whole positive item IDs marked true; anything else is dropped.
local function deMaterialsValidator(v)
	if type(v) ~= "table" then return nil end
	local out = {}
	for id, on in pairs(v) do
		if type(id) == "number" and id > 0 and id < 10000000 and id == math.floor(id) and on == true then out[id] = true end
	end
	return out
end
local validators = {
	deNever = deNeverValidator, deResults = deResultsValidator, deMaterials = deMaterialsValidator,
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
	skin = oneOf("modern", "classic"), border = oneOf("all", "unc", "off"), borderWeight = oneOf("normal", "bold"),
	accent = function(v) v = type(v) == "string" and v:lower():gsub("^#", "") or ""; return v:match("^%x%x%x%x%x%x$") and v or nil end,
	iconItemLevelColor = function(v) v = type(v) == "string" and v:lower():gsub("^#", "") or ""; return v:match("^%x%x%x%x%x%x$") and v or nil end,
	view = oneOf("list", "icons"), side = oneOf("left", "right"), bagSlotCount = oneOf("exclude", "all"),
	bagPoints = function(v)
		if type(v) ~= "table" then return nil end
		local out = {}
		for k, p in pairs(v) do local pv = pointV(p); if pv then out[tostring(k)] = pv end end
		return out
	end,
	reagent = oneOf("inline", "lane"), makeRoomValue = oneOf("ah", "vendor"), priceSource = oneOf("auto", "auctionator", "blackthornes"), deMargin = num(0, 2), deAhMargin = num(0, 2), deLeveling = oneOf("auto", "always", "never"), autoConfirmKey = oneOf("always", "shift", "ctrl", "custom"), grp = oneOf("none", "type", "bag"),
	recentWindow = oneOf("session", "1h", "15m"), recentMax = num(0, 200, true),
	closeOnLeave = oneOf("always", "auto", "never"),   -- (1.11.0-beta2)
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
	combatAlpha = num(0.05, 1), bgOpacity = num(0, 1), unusableOverlayOpacity = num(0, 1), pinnedHighlightAlpha = num(0.05, 0.5), movingAlpha = num(0.05, 1), scale = num(0.5, 1.5), textScale = num(0.8, 1.5), footerTextScale = num(0.8, 1.5), fontName = function(v) if type(v) == "string" and #v <= 100 then return v end end, bagCols = num(4, 12, true), bagScale = num(0.5, 1.5), bagMaxH = num(200, 800, true), shardKeep = num(0, 40, true), maxW = num(440, 1400, true), maxH = num(300, 1200, true),
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
				-- (1.10.0-beta1) its rules, cleaned (Core/Rules.lua): a saved or imported profile is never trusted as it comes
				if c.rules ~= nil and ns.Rules and ns.Rules.Clean then entry.rules = ns.Rules.Clean(c.rules) end
				-- (1.10.0-beta5) the sheets it's set to show on: sound names only; none means every sheet
				if c.sheets ~= nil and ns.Sections and ns.Sections.CleanSheets then entry.sheets = ns.Sections.CleanSheets(c.sheets) end
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
-- (1.8.0-beta5) Special bags' inner glow: each kind off until turned on, in its own color (Init.lua, ns.BAG_KINDS).
for _, k in ipairs(ns.BAG_KINDS or {}) do
	DEFAULTS["glow_" .. k.key] = false
	DEFAULTS["glowColor_" .. k.key] = k.color
	validators["glowColor_" .. k.key] = validators.accent
	DEFAULTS["glowAlpha_" .. k.key] = 1      -- (beta6 feedback, Shweep) and its own opacity, 10% to 100%
	validators["glowAlpha_" .. k.key] = num(0.1, 1)
	-- (beta10 feedback, Shweep) empty and filled slots each: "glow" (Inner Glow), "frame" (Frame Color) or "off"
	-- (replacing beta9's one style and beta5's items switch; a beta profile's choices carry over, validateProfile)
	DEFAULTS["glowEmpty_" .. k.key] = "glow"
	DEFAULTS["glowFilled_" .. k.key] = "glow"
	validators["glowEmpty_" .. k.key] = oneOf("glow", "frame", "off")
	validators["glowFilled_" .. k.key] = oneOf("glow", "frame", "off")
end
-- (1.8.0-beta7, Shweep) What every character using a profile shares, part by part (share<Part>: true shared, false
-- each character keeps its own copy, BagSmithCharDB.own[profile][key]; defaults below). The keys
-- that go together move together: moved items name custom sections; tab order and hidden tabs name sheets.
ns.PROFILE_PARTS = {
	{ key = "Favorites", label = "Favorites", help = "The items you've starred.", keys = { "favItems" }, shared = false },
	{ key = "Sections", label = "Custom Sections", help = "Your own sections, and the items you've moved from one section to another.", keys = { "customSections", "sectionMoves", "sectionNextId" } },
	{ key = "PinnedSections", label = "Pinned Sections", help = "Which sections are pinned to the top.", keys = { "pinnedSections" }, shared = false },
	{ key = "SectionOrder", label = "Section Order and Hidden Sections", help = "The order of your sections, and the ones you've hidden.", keys = { "laneOrder", "sectionHide" } },
	{ key = "Currencies", label = "Custom Currencies", help = "The items you track as currencies.", keys = { "customCurrencies" }, shared = false },
	{ key = "PinnedCurrencies", label = "Pinned Currencies", help = "The currencies pinned to the footer, and the ones you've unpinned.", keys = { "fav", "blizzUnpinned" }, shared = false },
	{ key = "Sheets", label = "Custom Sheets", help = "Your saved sheets for the bags and the bank, and the order of the tabs.", keys = { "sheets", "bankSheets", "tabOrder", "hiddenTabs", "bankTabOrder", "bankHiddenTabs" } },
}
-- (beta8, Shweep) Favorites, Pinned Sections, Custom Currencies and Pinned Currencies are each character's own unless
-- the profile shares them; the rest are shared. A profile saved before 1.8 has no choice saved, so it takes these: on
-- each character's first login, its own copy starts from the profile's (nothing is lost; What's New says so).
for _, part in ipairs(ns.PROFILE_PARTS) do DEFAULTS["share" .. part.key] = part.shared ~= false end
-- (1.8.0-beta16, the beta15 audit's F1) A profile's identity, apart from its name: a character's own copies are kept
-- under it, so a deleted profile's copies never come back when its name is reused (also for a character that logs in
-- later). Given at login to a profile that has none (profileIdLegacy: it existed before ids, so copies kept under its
-- name move to it once), and anew whenever a profile's content is replaced (new, imported, reset, copied over).
DEFAULTS.profileId = ""
DEFAULTS.profileIdLegacy = false
validators.profileId = function(v) if type(v) == "string" and #v <= 40 and v:match("^p[%d%.]+$") then return v end end
local idCount = 0
local function newProfileId(taken)
	local id
	repeat
		idCount = idCount + 1
		id = ("p%d.%d.%d"):format(time and time() or 0, idCount, math.random and math.random(1, 999999) or idCount)
	until not (taken and taken[id])
	return id
end
ns.NewProfileId = newProfileId

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
	-- (1.11.0-beta2) 1.10.1's Auto-Close Bags I Opened is the "when I leave" choice now: off becomes Close If
	-- Auto-Opened, on is Always Close, the default.
	if type(saved) == "table" and saved.autoCloseOwnBags ~= nil then
		if saved.autoCloseOwnBags == false and saved.closeOnLeave == nil then saved.closeOnLeave = "auto" end
		saved.autoCloseOwnBags = nil
	end
	-- (1.10.0-beta9) Hold Back What ItemTree Says to Keep (beta7 and beta8 only) became one switch per Helper. A
	-- profile that had it off, or had Use ItemTree off (which switched the hold off too), keeps both off.
	if type(saved) == "table" and saved.itemTreeHold ~= nil then
		if saved.itemTreeHold == false or saved.useItemTree == false then
			if saved.makeRoomHoldItemTree == nil then saved.makeRoomHoldItemTree = false end
			if saved.deHoldItemTree == nil then saved.deHoldItemTree = false end
		end
		saved.itemTreeHold = nil
	end
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
		-- (1.10.0-beta10) All Items joins where it keeps Sections: All looking as it did: right before the first dynamic
		-- section that follows your item sections (Keys, Reagent Bag and Gear Sets in the usual order), so what came
		-- before your items still shows above All Items and what came after still shows below. A pinned section
		-- further down than that stays above All Items, as pinned sections always were.
		if not ns.IndexOf(saved.laneOrder, "~all") then
			local order = saved.laneOrder
			local firstItem, at, lastPin
			for i, id in ipairs(order) do if type(id) == "string" and id:sub(1, 1) ~= "~" then firstItem = i; break end end
			if firstItem then
				for i = firstItem + 1, #order do
					if type(order[i]) == "string" and order[i]:sub(1, 1) == "~" then at = i; break end
				end
			end
			local pins = type(saved.pinnedSections) == "table" and saved.pinnedSections or {}
			for i, id in ipairs(order) do if pins[id] == true then lastPin = i end end
			if at and lastPin and lastPin >= at then at = lastPin + 1 end
			table.insert(order, at or (#order + 1), "~all")
		end
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
	-- (1.8.0-beta11) A beta profile's indicator choices carry over: beta9's style for empty slots, and for filled
	-- slots too unless beta5's items switch was off.
	if type(saved) == "table" then
		for _, k in ipairs(ns.BAG_KINDS or {}) do
			local style, items = saved["glowStyle_" .. k.key], saved["glowItems_" .. k.key]
			if saved["glowEmpty_" .. k.key] == nil and (style ~= nil or items ~= nil) then
				style = (style == "frame") and "frame" or "glow"
				saved["glowEmpty_" .. k.key] = style
				saved["glowFilled_" .. k.key] = items == false and "off" or style
			end
		end
	end
	local out, repaired = validate(saved, DEFAULTS)
	-- A sheet's custom-section categories are checked against THIS profile's
	-- sections (never the active profile's: this may be an import).
	for _, key in ipairs({ "sheets", "bankSheets" }) do
		for _, sh in ipairs(type(out[key]) == "table" and out[key] or {}) do
			if type(sh) == "table" and ns.PruneFilterCategories then ns.PruneFilterCategories(sh.f, out.customSections) end
		end
	end
	-- (1.10.0-beta5) A section's sheets are checked against THIS profile's tabs the same way: a name that is neither
	-- one of BagSmith's tabs nor one of the profile's sheets is dropped (a section left with none shows on every sheet).
	do
		local have = {}
		for id in pairs(ns.TAB_LABEL) do have[id] = true end
		for _, key in ipairs({ "sheets", "bankSheets" }) do
			for _, sh in ipairs(type(out[key]) == "table" and out[key] or {}) do
				if type(sh) == "table" and type(sh.n) == "string" then have[sh.n] = true end
			end
		end
		for _, c in ipairs(type(out.customSections) == "table" and out.customSections or {}) do
			if type(c) == "table" and type(c.sheets) == "table" then
				local kept = {}
				for _, name in ipairs(c.sheets) do if have[name] then kept[#kept + 1] = name end end
				c.sheets = #kept > 0 and kept or nil
			end
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
	-- (1.9.2-beta1) What's New: the updates opened (a version each), and the version when Settings' button was last clicked
	if type(saved) == "table" and type(saved.whatsNewPatchSeen) == "table" then
		local keep, n = {}, 0
		for v, on in pairs(saved.whatsNewPatchSeen) do
			if type(v) == "string" and #v <= 16 and v:find("^%d+%.%d+%.%d+$") and on == true and n < 64 then keep[v] = true; n = n + 1 end
		end
		db.whatsNewPatchSeen = keep
	end
	if type(saved) == "table" and type(saved.whatsNewButtonSeen) == "string" and #saved.whatsNewButtonSeen <= 16 and saved.whatsNewButtonSeen:find("^%d+%.%d+%.%d+$") then
		db.whatsNewButtonSeen = saved.whatsNewButtonSeen
	end
	-- (1.8.0-beta18) The Settings pages whose "NEW" tags this account has opened, per release ({ ["1.8"] = { look = true } }).
	-- (1.9.0-beta1) The Disenchant Helper's log, shared by your characters: results and learned materials, checked as the
	-- per-character ones are.
	if type(saved) == "table" and type(saved.deShared) == "table" then
		local d = saved.deShared
		db.deShared = { version = finite(d.version) and d.version or 0, results = deResultsValidator(d.results) or {}, materials = deMaterialsValidator(d.materials) or {},
			stats = deStatsValidator(d.stats) }   -- (1.11.0-beta3) the Results view's record
	end
	-- (1.9.0-beta4) Global Inventory's own settings (outside every profile), checked as a profile's are
	if type(saved) == "table" and type(saved.globalInv) == "table" then
		local g = saved.globalInv
		local out = { allRealms = g.allRealms == true, colWidths = {}, collapsed = {}, pins = {}, ahOn = g.ahOn == true }
		-- (1.9.0-beta13) the size you gave it there
		if finite(g.w) and g.w >= 440 and g.w <= 1400 then out.w = math.floor(g.w + 0.5) end
		if finite(g.h) and g.h >= 300 and g.h <= 1200 then out.h = math.floor(g.h + 0.5) end
		if type(g.sort) == "string" and #g.sort <= 20 then out.sort = g.sort end
		if g.grp == "type" or g.grp == "none" then out.grp = g.grp end
		for k, w in pairs(type(g.colWidths) == "table" and g.colWidths or {}) do
			if type(k) == "string" and #k <= 8 and finite(w) and w >= 10 and w <= 2000 then out.colWidths[k] = w end
		end
		for _, id in ipairs(type(g.collapsed) == "table" and g.collapsed or {}) do if type(id) == "string" and #id <= 100 then out.collapsed[#out.collapsed + 1] = id end end
		for _, k in ipairs(type(g.pins) == "table" and g.pins or {}) do if type(k) == "string" and #k <= 40 then out.pins[#out.pins + 1] = k end end
		-- (1.9.0-beta6) its own columns and tabs: known ids only, no repeats; a missing list starts from your bags'
		local function ids(list, known)
			if type(list) ~= "table" then return nil end
			local o, seen = {}, {}
			for _, id in ipairs(list) do if type(id) == "string" and known(id) and not seen[id] then seen[id] = true; o[#o + 1] = id end end
			return o
		end
		local function isCol(id) return ns.COL_LABEL[id] ~= nil or id == "n" end
		local function isTab(id) return ns.TAB_LABEL[id] ~= nil end
		out.cols, out.colOrder = ids(g.cols, isCol), ids(g.colOrder, isCol)
		out.tabOrder, out.hiddenTabs = ids(g.tabOrder, isTab), ids(g.hiddenTabs, isTab)
		if out.tabOrder then for _, id in ipairs(ns.BASE_TABS) do if not ns.IndexOf(out.tabOrder, id) then out.tabOrder[#out.tabOrder + 1] = id end end end
		db.globalInv = out
	end
	if type(saved) == "table" and type(saved.newSeen) == "table" then
		local keep, releases = {}, 0
		for rel, seen in pairs(saved.newSeen) do
			if type(rel) == "string" and rel:find("^%d+%.%d+$") and type(seen) == "table" and releases < 16 then
				local t, n = {}, 0
				for k, v in pairs(seen) do
					-- (1.9.1-beta3) true (an older save) or the version the page was opened at
					local ok = v == true or (type(v) == "string" and #v <= 16 and v:find("^%d+%.%d+%.%d+$"))
					if type(k) == "string" and #k <= 32 and k:find("^%w+$") and ok and n < 64 then t[k] = v; n = n + 1 end
				end
				keep[rel], releases = t, releases + 1
			end
		end
		db.newSeen = keep
	end
	-- (1.9.6) the realm each server number stands for ("6925" -> "Forever"), learned as characters log in: see
	-- ns:Realm in Core/Init.lua. One realm, one server: a realm listed twice is forgotten and learned again.
	if type(saved) == "table" and type(saved.servers) == "table" then
		local keep, times, n = {}, {}, 0
		for server, realm in pairs(saved.servers) do
			if n < 64 and type(server) == "string" and #server <= 12 and server:find("^%d+$") and type(realm) == "string"
				and realm ~= "" and #realm <= 64 and realm ~= "Unknown" and not ns.RealmLabelServer(realm) then
				keep[server] = realm; times[realm] = (times[realm] or 0) + 1; n = n + 1
			end
		end
		for server, realm in pairs(keep) do if times[realm] > 1 then keep[server] = nil end end
		db.servers = keep
	end
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
									-- (1.7.5-beta1) Before 1.7.5, Forever's keys were read as bank items (container -1, see
									-- Init.lua): they leave the saved bank; each character's keys come back in its bags (the
									-- keyring) the next time it logs in. Not a repair of bad data, so no message.
									if not (key == "bank" and ns.KEYRING_WAS_BANK and r.bag == ns.KEYRING_WAS_BANK) then good[#good + 1] = r end
								else repaired = true end
							end
							data[key] = good
						end
					end
					-- (1.9.0-beta1) what each character wears: { slot, itemID, link, count }, anything else dropped
					if data.equipped ~= nil then
						local good = {}
						if type(data.equipped) == "table" then
							for _, r in ipairs(data.equipped) do
								if type(r) == "table" and type(r.itemID) == "number" and type(r.slot) == "number" and (r.link == nil or type(r.link) == "string") then
									good[#good + 1] = { slot = r.slot, itemID = r.itemID, link = r.link, count = 1 }
								else repaired = true end
							end
						else repaired = true end
						data.equipped = good
					end
					for _, key in ipairs({ "bags", "bankBags", "currencies" }) do
						if data[key] ~= nil and type(data[key]) ~= "table" then data[key] = nil; repaired = true end
					end
					-- (1.9.6) the character's GUID, as the game gave it
					if data.guid ~= nil and (type(data.guid) ~= "string" or #data.guid > 64 or not data.guid:find("^Player%-")) then data.guid = nil; repaired = true end
					-- (1.7.5-beta1) and the keyring's slots leave the saved bank's space
					if ns.KEYRING_WAS_BANK and type(data.bankBags) == "table" then data.bankBags[tostring(ns.KEYRING_WAS_BANK)] = nil end
					db.cache[char] = data
				end
			end
		end
	elseif type(saved) == "table" then
		local v, r = validateProfile(saved); db.profiles[DEFAULT_PROFILE] = v; repaired = repaired or r
	end
	if not db.profiles[DEFAULT_PROFILE] then db.profiles[DEFAULT_PROFILE] = fixTabs(copy(DEFAULTS)) end
	-- (1.8.0-beta16) every profile has its own id; one without (saved before ids) gets one, marked as inherited; a
	-- duplicate (copied saved data) gets a new one
	local taken, names = {}, {}
	for name in pairs(db.profiles) do names[#names + 1] = name end
	table.sort(names)
	for _, name in ipairs(names) do
		local prof = db.profiles[name]
		if prof.profileId == "" then prof.profileId = newProfileId(taken); prof.profileIdLegacy = true
		elseif taken[prof.profileId] then prof.profileId = newProfileId(taken); prof.profileIdLegacy = false end
		taken[prof.profileId] = true
	end
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
-- (1.8.0-beta7, Shweep) A profile's parts a character keeps for itself (ns.PROFILE_PARTS, the profile's share<Part>
-- off). Only one character plays at a time, so for the session its own copies stand in the profile's table, where the
-- rest of BagSmith reads and writes them as before; the profile's own values wait aside and go back before the game
-- writes the saved data (PLAYER_LOGOUT, which /reload sends too), before another profile is used, and when a part is
-- shared again. A character's copy is kept when a part is shared again, so it comes back if that part is unshared later.
local Own = { swap = nil }   -- swap = { tbl = the profile's table, id = its profileId, keys = { [key] = the profile's value } }
ns.OwnParts = Own
local function partKeys()
	local set = {}
	for _, part in ipairs(ns.PROFILE_PARTS) do for _, k in ipairs(part.keys) do set[k] = part.key end end
	return set
end
function Own:Restore()
	local sw = self.swap
	if not sw then return end
	self.swap = nil
	local cdb = ns.cdb
	local mine = cdb and cdb.own and cdb.own[sw.id]
	for k, profileValue in pairs(sw.keys) do
		if mine then mine[k] = sw.tbl[k] end   -- the character's copy, as it is now
		sw.tbl[k] = profileValue
	end
end
function Own:Apply()
	self:Restore()
	local tbl, cdb = ns.db, ns.cdb
	if not (tbl and cdb) then return end
	if type(tbl.profileId) ~= "string" or tbl.profileId == "" then tbl.profileId = newProfileId() end   -- (beta16)
	local name = tbl.profileId   -- (beta16) the copies are kept under the profile's id, not its name
	local keys
	for _, part in ipairs(ns.PROFILE_PARTS) do
		if tbl["share" .. part.key] == false then
			cdb.own = type(cdb.own) == "table" and cdb.own or {}
			local mine = cdb.own[name] or {}
			cdb.own[name] = mine
			for _, k in ipairs(part.keys) do
				keys = keys or {}
				keys[k] = tbl[k]
				if mine[k] == nil then mine[k] = copy(tbl[k]) end   -- the first time: a copy of what the profile has now
				tbl[k] = mine[k]
			end
		end
	end
	if keys then
		self.swap = { tbl = tbl, id = name, keys = keys }
		fixTabs(tbl)   -- this character's sheets and tabs agree (it may replace a list: the copies follow)
		local mine = cdb.own[name]
		for k in pairs(keys) do mine[k] = tbl[k] end
	end
end
-- (beta8) A profile reset or copied over: this character's own copies of its parts go too (the profile's values back
-- first), so what the character sees is the reset or copied profile. Other characters' copies live in their own
-- saved data and stay until they log in (a reset profile shares nothing new with them).
function Own:Forget(name)
	local prof = BagSmithDB and BagSmithDB.profiles and BagSmithDB.profiles[name]
	local id = prof and prof.profileId
	if not id or id == "" then return end
	if self.swap and self.swap.id == id then self:Restore() end
	local cdb = ns.cdb
	if cdb and type(cdb.own) == "table" then cdb.own[id] = nil end
end
-- What a character keeps for itself is checked as the profile's own settings are: anything else is dropped. Copies
-- for a profile that no longer exists go.
local function validateOwn(cdb)
	local allowed = partKeys()
	local own = type(cdb.own) == "table" and cdb.own or {}
	local out = {}
	-- (beta16) kept under profile ids; a beta's copies kept under a profile's name move to its id, only when that
	-- profile is the same one (it got its id at login, inherited): never to a new profile that reuses the name
	local ids = {}
	for _, prof in pairs(BagSmithDB.profiles) do if prof.profileId ~= "" then ids[prof.profileId] = true end end
	local moved = {}
	for key, t in pairs(own) do
		local prof = type(key) == "string" and not ids[key] and BagSmithDB.profiles[key]
		if prof and prof.profileIdLegacy and type(t) == "table" and own[prof.profileId] == nil then moved[prof.profileId] = t end
	end
	for id, t in pairs(moved) do own[id] = t end
	for name, t in pairs(own) do
		if type(name) == "string" and type(t) == "table" and ids[name] then
			local keep = {}
			for k, v in pairs(t) do
				if allowed[k] then
					if validators[k] then keep[k] = validators[k](v)
					elseif type(v) == type(DEFAULTS[k]) then keep[k] = copy(v) end
				end
			end
			out[name] = keep
		end
	end
	cdb.own = out
end

local function activate()
	Own:Restore()   -- (1.8.0-beta7) the old profile gets its own values back first
	local name, settings = Profiles:Active()
	ns.db, ns.profileName = settings, name
	Own:Apply()
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
		fresh.profileId, fresh.profileIdLegacy = newProfileId(), false   -- (beta16) a new profile is a new identity
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
	v.profileId, v.profileIdLegacy = newProfileId(), false   -- (beta16) never another profile's identity
	BagSmithDB.profiles[name] = fixTabs(v)
	return name
end
function Profiles:CopyFrom(name)
	name = cleanName(name)
	local src = name and BagSmithDB.profiles[name]
	if not src then return false, "No profile named " .. tostring(name) .. "." end
	if name == ns.profileName then return false, "That is already the active profile." end
	Own:Forget(ns.profileName)   -- (beta8) this character's own copies take the copied profile's too
	BagSmithDB.profiles[ns.profileName] = copy(src)
	-- (beta16) replaced content is a new identity: every character's own copies start again from it
	BagSmithDB.profiles[ns.profileName].profileId, BagSmithDB.profiles[ns.profileName].profileIdLegacy = newProfileId(), false
	ns.ui.collapseReset = true   -- the active profile's content is replaced
	activate()
	return true
end
function Profiles:Delete(name)
	name = cleanName(name)
	if not name or not BagSmithDB.profiles[name] then return false, "No profile named " .. tostring(name) .. "." end
	if name == DEFAULT_PROFILE then return false, "The Default profile cannot be deleted." end
	if name == self:Active() then ns.ui.collapseReset = true end   -- this character falls back to Default
	Own:Forget(name)   -- (beta16) this character's copies of it go; other characters' go at their next login
	BagSmithDB.profiles[name] = nil
	for char, prof in pairs(BagSmithDB.chars) do if prof == name then BagSmithDB.chars[char] = nil end end
	activate()
	return true
end
function Profiles:Reset(name)
	name = name or ns.profileName
	if not BagSmithDB.profiles[name] then return false, "No profile named " .. tostring(name) .. "." end
	if name == self:Active() then ns.ui.collapseReset = true end   -- the active profile is replaced
	Own:Forget(name)   -- (beta8) and this character's own copies of its parts start again from the reset profile
	BagSmithDB.profiles[name] = fixTabs(copy(DEFAULTS))
	BagSmithDB.profiles[name].profileId = newProfileId()   -- (beta16) a new identity: other characters' copies don't attach
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
	validateOwn(cdb)   -- (1.8.0-beta7) this character's own copies of parts its profile doesn't share
	Own:Apply()
	if repaired then ns:Print("Some saved settings were invalid and have been reset to defaults.") end
	ns.loaded = true
	ns:Fire("ADDON_READY")
	ns:Fire("PROFILE_ACTIVATED")
end)

-- (1.9.0-beta6, Shweep: Global Inventory "uses the game's defaults" for sections) While Global Inventory works out and
-- draws its sections, these settings read as BagSmith's defaults, never your profile's: standard order, no splits,
-- Keys and the reagent bag their own sections, no custom sections, moves or pins, and no Favorites, Recent or gear set
-- sections (they belong to one character). Swapped in for the call only and always put back, even on an error.
local GLOBAL_SECTIONS = { splitCons = false, splitGear = false, keys = true, reagent = "lane", customSections = {},
	sectionMoves = {}, pinnedSections = {}, favSection = false, recentSection = false, gearSetSections = false,
	showEmptySections = false, pinnedHighlight = false }
function ns:WithDefaultSections(fn, ...)
	local db = ns.db
	if type(db) ~= "table" or ns.inDefaultSections then return fn(...) end
	local saved = {}
	for k, v in pairs(GLOBAL_SECTIONS) do saved[k] = db[k]; db[k] = v end
	saved.laneOrder = db.laneOrder
	local order = {}
	for i, id in ipairs(DEFAULTS.laneOrder) do order[i] = id end
	db.laneOrder = order
	ns.inDefaultSections = true
	local res = { pcall(fn, ...) }
	ns.inDefaultSections = nil
	for k, v in pairs(saved) do db[k] = v end
	if not res[1] then error(res[2], 0) end
	return unpack(res, 2)
end

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

-- (1.8.0-beta7) Saving: the profile's own values go back before the game writes them, whatever else runs at logout.
ns:On("PLAYER_LOGOUT", function() pcall(Own.Restore, Own) end)
-- A part shared or unshared: swap again, then everything redraws from the right copy (as a profile switch does).
ns:OnSignal("SETTINGS_CHANGED", function(key)
	if type(key) ~= "string" or not key:find("^share") then return end
	Own:Apply()
	if ns.Currency then ns.Currency:Invalidate() end
	if ns.ReconcileSheets then ns:ReconcileSheets() end
	ns:Fire("SETTINGS_CHANGED")
end)
