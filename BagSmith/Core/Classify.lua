--[[
	BagSmith - Core/Classify.lua
	Item categories, bind text, search syntax and filter predicates.
--]]

local ADDON, ns = ...

-- Item IDs that are currencies-in-disguise (battleground marks, raid tokens, tickets).
-- Filled in from beta dumps; anything here lands in the Tokens category and the currency drawer.
-- Items that act as currencies but are ordinary items (marks, coins, tickets).
-- By item ID so it works in every client language; /bs dump prints IDs so
-- the list can grow. Starting set: classic-era PvP marks, event tickets,
-- Argent Dawn tokens and scourgestones, Zul'Gurub coins and bijous, AQ scarabs.
ns.TOKEN_IDS = {}
for _, id in ipairs({
	20558, 20559, 20560,                                   -- Warsong Gulch, Arathi Basin, Alterac Valley marks
	19182,                                                 -- Darkmoon Faire Prize Ticket
	12844, 12840, 12841, 12843,                            -- Argent Dawn Valor Token, scourgestones
	19698, 19699, 19700, 19701, 19702, 19703, 19704, 19705, 19706,   -- Zul'Gurub coins
	19707, 19708, 19709, 19710, 19711, 19712, 19713, 19714, 19715,   -- Zul'Gurub bijous
	20858, 20859, 20860, 20861, 20862, 20863, 20864, 20865,           -- Ahn'Qiraj scarabs
}) do ns.TOKEN_IDS[id] = true end

-- Blizzard's named item classes, with the classic numbers as fallback.
local IC = Enum and Enum.ItemClass or {}
local CLASS = {
	Consumable = IC.Consumable or 0, Container = IC.Container or 1, Weapon = IC.Weapon or 2,
	Gem = IC.Gem or 3, Armor = IC.Armor or 4, Reagent = IC.Reagent or 5, Projectile = IC.Projectile or 6,
	Tradegoods = IC.Tradegoods or 7, Recipe = IC.Recipe or 9, CurrencyTokenObsolete = IC.CurrencyTokenObsolete or 10,
	Quiver = IC.Quiver or 11, Questitem = IC.Questitem or 12, Key = IC.Key or 13, Miscellaneous = IC.Miscellaneous or 15,
}
local MISC = Enum and Enum.ItemMiscellaneousSubclass or {}
local MISC_REAGENT = MISC.Reagent or 1
ns.ITEM_CLASS = CLASS

-- (1.5.0-beta9) What kind of consumable an item is, by the game's own consumable types (the same numbers on Classic
-- and Retail): 1 Potion, 2 Elixir, 3 Flask, 4 Scroll, 5 Food & Drink, 6 Item Enhancement, 7 Bandage; anything else
-- (0 Generic, 8 Other, and Retail's newer kinds) is Other. Food & Drink is split by the item's use spell, compared
-- with the game's own names for eating and drinking in the player's language: drinking is Drink; eating, both, or
-- anything else is Food. nil while the game hasn't loaded the item's use spell yet (it stays in Consumables until then).
local CONS_SUB = { [1] = "Potion", [2] = "Elixir", [3] = "Flask", [4] = "Scroll", [5] = "FoodDrink", [6] = "Enhance", [7] = "Bandage" }
ns.FOOD_SPELL_ID, ns.DRINK_SPELL_ID = 433, 430
-- (1.5.0-beta10) Alcohol goes to Other Consumables, so Drink stays mana drinks (Shweep's call). Recognised by the use
-- spell's ID in any language (11007 Weak Alcohol, confirmed on WoW Forever); other strengths by the English word
-- "Alcohol" in the spell name until their IDs are confirmed with /bs consumables.
ns.ALCOHOL_SPELL_IDS = { [11007] = true }
local function spellName(id)
	local n = GetSpellInfo and GetSpellInfo(id)
	if not n and C_Spell and C_Spell.GetSpellName then n = C_Spell.GetSpellName(id) end
	return n
end
function ns:ItemUseSpell(itemID)
	local get = (C_Item and C_Item.GetItemSpell) or GetItemSpell
	if not (get and itemID) then return nil end
	return get(itemID)
end
function ns:ConsumableKind(rec)
	if not rec or rec.classID ~= CLASS.Consumable then return nil end
	local kind = CONS_SUB[rec.subclassID] or "Other"
	if kind ~= "FoodDrink" then return kind end
	local name, spellID = ns:ItemUseSpell(rec.itemID)
	if not name then
		if rec.itemID and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(rec.itemID) end
		return nil
	end
	if (spellID and ns.ALCOHOL_SPELL_IDS[spellID]) or name:find("Alcohol", 1, true) then return "Other" end
	if name == (spellName(ns.DRINK_SPELL_ID) or "Drink") then return "Drink" end
	return "Food"   -- eating, both (a mana cake's combined spell), or anything else in Food & Drink
end
-- The section a consumable splits into, when Split Consumables is on for its kind; and whether the answer has to wait
-- for the item's use spell (then nothing is cached).
local consGen = 0
function ns:ConsSplitChanged() consGen = consGen + 1 end
local function consSection(rec)
	local db = ns.db
	if not (db and db.splitCons) then return nil, false end
	local kind = ns:ConsumableKind(rec)
	if not kind then ns.pendingInfo = true; return nil, true end   -- (a rescan follows when the game sends the item's details)
	if (db.splitConsTypes or {})[kind] == false then return nil, false end
	return ns.CONS_ID[kind], false
end

-- (1.7.0-beta6) The section a piece of gear splits into, when Split Gear by Binding is on for its binding.
local function gearSection(rec)
	local db = ns.db
	if not (db and db.splitGear) then return nil end
	local kind
	if rec.isBound or rec.bindType == 1 then kind = "Soulbound" elseif rec.bindType == 2 then kind = "BoE" end
	if not kind or (db.splitGearTypes or {})[kind] == false then return nil end
	return ns.GEAR_ID[kind]
end

-- Category results are cached per item and every detail the answer uses
-- (quality, quest flag, class, subclass, binding, crafting reagent).
local catCache, catCount = {}, 0
function ns:Categorize(rec)
	if rec.quality == 0 then return "Junk" end
	local class, sub = rec.classID, rec.subclassID
	-- The key holds everything the answer uses, so an item first seen before
	-- the game supplied all its details gets a fresh answer once it has them.
	local key = rec.itemID and (rec.itemID .. ":" .. tostring(rec.quality) .. ":" .. (rec.isQuest and 1 or 0) .. ":" .. tostring(rec.classID)
		.. ":" .. tostring(rec.subclassID) .. ":" .. tostring(rec.bindType) .. ":" .. (rec.isCraftingReagent and 1 or 0) .. ":" .. consGen
		.. ":" .. (rec.isBound and 1 or 0)) or nil   -- (1.7.0-beta6) bound or not: a BoE you equip moves to Gear: Soulbound
	if key and catCache[key] then return catCache[key] end
	local cat
	if rec.itemID and ns.TOKEN_IDS[rec.itemID] then cat = "Tokens"
	elseif rec.isQuest or class == CLASS.Questitem or rec.bindType == 4 then cat = "Quest"
	elseif class == CLASS.Key then cat = "Keys"
	elseif class == CLASS.Weapon or class == CLASS.Armor then cat = gearSection(rec) or "Gear"
	elseif class == CLASS.Consumable or class == CLASS.Projectile then
		cat = "Consumables"
		if class == CLASS.Consumable then
			local split, waiting = consSection(rec)
			if split then cat = split end
			if waiting then key = nil end   -- ask again once the game has the item's use spell
		end
	elseif class == CLASS.Tradegoods or class == CLASS.Gem then cat = "TradeGoods"
	elseif class == CLASS.Recipe then cat = "Recipes"
	elseif class == CLASS.CurrencyTokenObsolete then cat = "Tokens"
	elseif class == CLASS.Reagent then cat = "Reagents"
	elseif class == CLASS.Miscellaneous then
		if sub == MISC_REAGENT then cat = "Reagents"
		elseif rec.isCraftingReagent then cat = "TradeGoods"
		else cat = "Other" end
	elseif rec.isCraftingReagent then cat = "TradeGoods"
	else cat = "Other" end
	if key and class ~= nil then
		if catCount > 2000 then catCache, catCount = {}, 0 end
		catCache[key] = cat; catCount = catCount + 1
	end
	return cat
end

function ns:BindText(rec)
	if rec.isBound then return "BoP" end
	local b = rec.bindType
	if b == 2 then return "BoE" elseif b == 1 then return "BoP" elseif b == 3 then return "BoU" end
	return ""
end

local SLOT_NAME = {
	INVTYPE_HEAD = "Head", INVTYPE_NECK = "Neck", INVTYPE_SHOULDER = "Shoulder", INVTYPE_BODY = "Shirt", INVTYPE_CHEST = "Chest",
	INVTYPE_ROBE = "Chest", INVTYPE_WAIST = "Waist", INVTYPE_LEGS = "Legs", INVTYPE_FEET = "Feet", INVTYPE_WRIST = "Wrist",
	INVTYPE_HAND = "Hands", INVTYPE_FINGER = "Finger", INVTYPE_TRINKET = "Trinket", INVTYPE_CLOAK = "Back", INVTYPE_WEAPON = "One-Hand",
	INVTYPE_SHIELD = "Off Hand", INVTYPE_2HWEAPON = "Two-Hand", INVTYPE_WEAPONMAINHAND = "Main Hand", INVTYPE_WEAPONOFFHAND = "Off Hand",
	INVTYPE_HOLDABLE = "Held", INVTYPE_RANGED = "Ranged", INVTYPE_RANGEDRIGHT = "Ranged", INVTYPE_THROWN = "Thrown",
	INVTYPE_RELIC = "Relic", INVTYPE_TABARD = "Tabard", INVTYPE_BAG = "Bag", INVTYPE_QUIVER = "Quiver", INVTYPE_AMMO = "Ammo",
}
function ns:SlotText(rec)
	return SLOT_NAME[rec.equipLoc or ""] or ""
end

-- What the Type column shows: long words shortened for the column only.
-- Search still reads the full item type, so "miscellaneous" and "misc" both match.
local SHORT_TYPE = { Miscellaneous = "Misc." }
function ns:TypeLabel(rec)
	local t = ns:TypeText(rec)
	return SHORT_TYPE[t] or t
end

-- Type column text: Blizzard's subtype, except where it is unhelpful.
function ns:TypeText(rec)
	local sub = rec.itemSubType or rec.itemType or ""
	-- (1.7.0-beta6) Split Gear by Binding's sections are Gear too
	local own = rec.ownCat or rec.cat
	if (own == "Gear" or ns.PARENT_CAT[own] == "Gear") and sub == "Miscellaneous" then return ns:SlotText(rec) ~= "" and ns:SlotText(rec) or sub end
	if sub == "Junk" and (rec.quality or 1) > 0 then return rec.itemType or "Miscellaneous" end
	return sub
end

------------------------------------------------------------------------
-- Search: plain words match name, type, and section (the item's own and,
-- if moved, the one it's in now). Shortcuts:
--   boe bop new  q:rare  t:herb  il>20 il<10 il=15
------------------------------------------------------------------------
local QUALITY_NAMES = { poor = 0, common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5 }
-- (1.5.0-beta9) Consumable keywords: "drink" finds drinks only (not food, which shares the game's Food & Drink type),
-- "food" finds food, and so on, whether or not Split Consumables is on. An item whose name has the word still matches.
local KIND_WORDS = { food = "Food", drink = "Drink", drinks = "Drink", potion = "Potion", potions = "Potion", elixir = "Elixir",
	elixirs = "Elixir", flask = "Flask", flasks = "Flask", scroll = "Scroll", scrolls = "Scroll", bandage = "Bandage", bandages = "Bandage" }
-- The section words a search matches: the item's own category and, if you
-- moved it, the section it's in now (a custom section's name included).
-- (and the names of any gear sets it's in)
local function sectionWords(r)
	local own = ns.CAT_LABEL[r.ownCat or r.cat] or ""
	local now = (ns.Sections and r.cat and ns.Sections:Label(r.cat)) or ns.CAT_LABEL[r.cat] or ""
	local words = (now == own) and own or (own .. " " .. now)
	local sets = ns.GearSets and ns.GearSets:SetsOf(r)
	if sets then words = words .. " " .. table.concat(sets, " ") end
	return words
end
local parseCache, parseCount = {}, 0
function ns:ParseSearch(text)
	text = text or ""
	local cached = parseCache[text]
	if cached then return cached end
	local preds = {}
	for tok in (text or ""):lower():gmatch("%S+") do
		if tok == "boe" then preds[#preds + 1] = function(r) return ns:BindText(r) == "BoE" end
		elseif tok == "bop" then preds[#preds + 1] = function(r) return ns:BindText(r) == "BoP" end
		elseif tok == "new" then preds[#preds + 1] = function(r) return r.isNew end
		elseif KIND_WORDS[tok] then
			local kind, word = KIND_WORDS[tok], tok
			preds[#preds + 1] = function(r) return ns:ConsumableKind(r) == kind or ((r.name or ""):lower():find(word, 1, true) ~= nil) end
		else
			local op, n = tok:match("^il([<>=]=?)(%d+)$")
			if op then
				n = tonumber(n)
				preds[#preds + 1] = function(r)
					local il = r.ilvl or 0
					if op == ">" then return il > n elseif op == "<" then return il < n
					elseif op == ">=" then return il >= n elseif op == "<=" then return il <= n end
					return il == n
				end
			else
				local q = tok:match("^q:(%a+)$")
				local t = tok:match("^t:(.+)$")
				if q then
					local want
					for name, id in pairs(QUALITY_NAMES) do if name:sub(1, #q) == q then want = id end end
					preds[#preds + 1] = function(r) return want ~= nil and r.quality == want end
				elseif t then
					preds[#preds + 1] = function(r) return ((r.itemSubType or "") .. " " .. (r.itemType or "") .. " " .. ns:TypeText(r) .. " " .. sectionWords(r)):lower():find(t, 1, true) ~= nil end
				else
					preds[#preds + 1] = function(r)
						-- Match the full type words, including the one the Type column shows (in full, never shortened).
						return ((r.name or "") .. " " .. (r.itemSubType or "") .. " " .. (r.itemType or "") .. " " .. ns:TypeText(r) .. " " .. sectionWords(r)):lower():find(tok, 1, true) ~= nil
					end
				end
			end
		end
	end
	local fn = function(r)
		for i = 1, #preds do if not preds[i](r) then return false end end
		return true
	end
	if parseCount > 200 then parseCache, parseCount = {}, 0 end
	parseCache[text] = fn; parseCount = parseCount + 1
	return fn
end

------------------------------------------------------------------------
-- Structured filters: { q = {[3]=true}, cat = {Gear=true}, t = {}, bd = {}, w = {}, new = false, text = "" }
------------------------------------------------------------------------
local function setOf(v, wantNumber)
	local out = {}
	if type(v) == "table" then
		for k, x in pairs(v) do
			local key = (type(k) == "number" and type(x) ~= "boolean") and x or k
			if wantNumber then key = tonumber(key) end
			if key ~= nil and x then out[key] = true end
		end
	end
	return out
end
-- Age window in whole hours, 0 to 9; nil means that end is open.
local function hour(v)
	v = tonumber(v)
	if not v or v ~= math.floor(v) or v < 0 or v > 9 then return nil end
	return v
end
function ns.CleanFilters(f)
	f = type(f) == "table" and f or {}
	local lo, hi = hour(f.ageMin), hour(f.ageMax)
	if lo and hi and lo > hi then lo, hi = hi, lo end
	return { q = setOf(f.q, true), cat = setOf(f.cat), t = setOf(f.t), bd = setOf(f.bd), w = setOf(f.w),
		new = f.new and true or false, text = type(f.text) == "string" and f.text or "", ageMin = lo, ageMax = hi }
end
function ns.EmptyFilters() return ns.CleanFilters(nil) end
-- Drops custom-section categories that aren't in the given sections (a list
-- of { id = ... }), keeping built-in ones. Called only where the profile the
-- filters belong to is known: never against whatever profile happens to be
-- active (an imported profile's sheets belong to that profile).
function ns.PruneFilterCategories(f, customs)
	if not (type(f) == "table" and type(f.cat) == "table") then return f end
	local have = {}
	for _, c in ipairs(customs or {}) do if type(c) == "table" and c.id then have[c.id] = true end end
	for k in pairs(f.cat) do
		if type(k) == "string" and k:match("^c%d+$") and not have[k] then f.cat[k] = nil end
	end
	return f
end
function ns.FilterCount(f)
	local n = 0
	for _, key in ipairs({ "q", "cat", "t", "bd", "w" }) do for _ in pairs(f[key]) do n = n + 1 end end
	if f.new then n = n + 1 end
	if f.ageMin or f.ageMax then n = n + 1 end
	return n
end
function ns:FilterPredicate(f)
	local text = ns:ParseSearch(f.text)
	local hasQ, hasCat, hasT, hasBd, hasW = next(f.q) ~= nil, next(f.cat) ~= nil, next(f.t) ~= nil, next(f.bd) ~= nil, next(f.w) ~= nil
	return function(r)
		if hasQ and not f.q[r.quality] then return false end
		if hasCat and not (f.cat[r.cat] or (ns.PARENT_CAT[r.cat] and f.cat[ns.PARENT_CAT[r.cat]])) then return false end
		if hasT and not f.t[r.itemSubType or ""] then return false end
		if hasBd and not f.bd[ns:BindText(r) ~= "" and ns:BindText(r) or "None"] then return false end
		if hasW and not f.w[r.where or ""] then return false end
		if f.new and not r.isNew then return false end
		if f.ageMin or f.ageMax then
			-- Only the ends that are set apply ("at least 1 hour" has no upper limit).
			if not r.firstSeen then return false end
			local lo, hi = f.ageMin, f.ageMax
			if lo and hi and lo > hi then lo, hi = hi, lo end
			local age = time() - r.firstSeen
			if lo and age < lo * 3600 then return false end
			if hi and age > hi * 3600 then return false end
		end
		return text(r)
	end
end

-- Relative age from a first-seen timestamp: "now", "5m", "3h", "2d", "3w".
function ns.AgeText(seen)
	if not seen then return "" end
	local d = time() - seen
	if d < 60 then return "now" end
	if d < 3600 then return math.floor(d / 60) .. "m" end
	if d < 86400 then return math.floor(d / 3600) .. "h" end
	if d < 86400 * 14 then return math.floor(d / 86400) .. "d" end
	return math.floor(d / (86400 * 7)) .. "w"
end

------------------------------------------------------------------------
-- Sorting
------------------------------------------------------------------------
local sorters = {
	quality = function(a, b) if a.quality ~= b.quality then return a.quality > b.quality end return a.name < b.name end,
	name = function(a, b) return a.name < b.name end,
	ilvl = function(a, b) local x, y = a.ilvl or 0, b.ilvl or 0; if x ~= y then return x > y end return a.name < b.name end,
	newest = function(a, b) local x, y = a.firstSeen or 0, b.firstSeen or 0; if x ~= y then return x > y end return a.name < b.name end,
	oldest = function(a, b) local x, y = a.firstSeen or 0, b.firstSeen or 0; if x ~= y then return x < y end return a.name < b.name end,
	-- Off (1.4.0): bag order, bag by bag and slot by slot, so items show where they sit
	off = function(a, b)
		local x, y = a.bagIndex or 99, b.bagIndex or 99
		if x ~= y then return x < y end
		local s, t = a.slot or 0, b.slot or 0
		if s ~= t then return s < t end
		return (a.name or "") < (b.name or "")
	end,
}
function ns:Sorter(mode) return sorters[mode] or sorters.quality end

-- Header-click sorting: any column, either direction. Cleared by picking a
-- sort mode from the toolbar.
local colValue = {
	n = function(r) return r.name end, c = function(r) return r.count or 0 end, il = function(r) return r.ilvl or 0 end,
	rq = function(r) return r.minLevel or 0 end, t = function(r) return ns:TypeText(r) end, sl = function(r) return ns:SlotText(r) end,
	bd = function(r) return ns:BindText(r) end, v = function(r) return (r.sellPrice or 0) * (r.count or 1) end, w = function(r) return r.where or "" end,
	age = function(r) return -(r.firstSeen or 0) end,
	ah = function(r) return ns.AH:StackValue(r) or -1 end,   -- unscanned items sort below the cheapest
	jk = function(r) return ns.Junk and ns.Junk:IsJunk(r) and 1 or 0 end,   -- junk first
	fv = function(r) return ns.Marks and ns.Marks:IsFavorite(r.itemID) and 1 or 0 end,   -- favorites first
	cc = function(r) return ns.Marks and (ns.Marks:IsTracked(r.itemID) or ns.Marks:IsBuiltInCurrency(r)) and 1 or 0 end,   -- currencies first
}
function ns:CurrentSorter(st, sortMode)
	st = st or ns.ui
	local cs = st.colSort
	if not cs or not colValue[cs.key] then return ns:Sorter(sortMode or ns.db.sort) end
	local get, asc = colValue[cs.key], cs.dir == "asc"
	return function(a, b)
		local x, y = get(a), get(b)
		if x == y then return a.name < b.name end
		if asc then return x < y else return x > y end
	end
end
function ns:SortByColumn(st, key)
	st = st or ns.ui
	local cs = st.colSort
	if cs and cs.key == key then cs.dir = cs.dir == "asc" and "desc" or "asc"
	else st.colSort = { key = key, dir = (key == "n" or key == "t" or key == "w" or key == "sl" or key == "bd") and "asc" or "desc" } end
end

------------------------------------------------------------------------
-- Lanes
------------------------------------------------------------------------
-- Returns lane id and label for a record under the given grouping.
function ns:LaneOf(rec, grp, opts)
	if opts.reagentLane and ns:IsReagentBag(rec.bag) then return "~rb", opts.reagentName or "Reagent Bag", true end
	-- Keys: their own section in By Type always (at their Section Order place);
	-- in All and By Bag only with Keys in Their Own Section.
	if rec.cat == "Keys" and (ns.db.keys or grp == "type") then return "~ky", "Keys", true end
	if grp == "type" then return rec.cat, (ns.Sections and ns.Sections:Label(rec.cat)) or ns.CAT_LABEL[rec.cat] or rec.cat, false end
	if grp == "bag" then return "bag:" .. tostring(rec.bag), rec.where or tostring(rec.bag), false end
	return "", "", false
end

function ns:BuildLanes(records, grp, opts)
	local lanes, byId = {}, {}
	for _, rec in ipairs(records) do
		local id, label, pinned = ns:LaneOf(rec, grp, opts)
		local lane = byId[id]
		if not lane then
			lane = { id = id, label = label, pinned = pinned, items = {}, bagIndex = rec.bagIndex or 0 }
			byId[id] = lane
			lanes[#lanes + 1] = lane
		end
		lane.items[#lane.items + 1] = rec
	end
	local order = ns.db.laneOrder
	local function rank(l)
		local i = ns.IndexOf(order, l.id)
		return i or 999
	end
	table.sort(lanes, function(a, b)
		if grp == "type" then return rank(a) < rank(b) end
		if a.pinned ~= b.pinned then return not a.pinned end
		if a.pinned then return rank(a) < rank(b) end
		return a.bagIndex < b.bagIndex
	end)
	local sorter = opts.sorter or ns:CurrentSorter()
	for _, lane in ipairs(lanes) do table.sort(lane.items, sorter) end
	return lanes
end

-- Merge Stacks joins stacks of the same stackable item. Items that don't
-- stack (gear, and random-suffix pieces like "...of the Bear" / "...of the
-- Eagle", which share an item ID) keep their own rows. Used for showing,
-- totals, arrivals and dismissing "new", so they always agree.
function ns.MergeKey(r)
	local stackable = (r.maxStack and r.maxStack > 1) or (r.maxStack == nil and (r.equipLoc == nil or r.equipLoc == ""))
	if stackable then return tostring(r.itemID) .. ":" .. tostring(r.quality) end
	return "slot:" .. tostring(r.bag) .. ":" .. tostring(r.slot) .. ":" .. tostring(r.itemID)
end
