--[[
	Core/Rules.lua (1.10.0-beta1)

	Section rules: what makes an item fit one of your custom sections, beside the items you put there yourself.

	A section's rules are { mode = "all" | "any", rows = { row, ... } }. A row is { k = key, v = { value, ... }, n = true
	or nil }: the item's answer for that key is (or, with n, is not) one of the values. Several values in a row mean any
	of them. "all": every row fits; "any": one does.

	Only facts about the item itself are keys (its type, slot, quality, binding): nothing about the moment or where it
	sits, so an item doesn't hop between sections as time passes. A fact the game hasn't supplied yet, or a key this
	version doesn't know (a newer version's, another addon's that isn't installed), never fits, with or without "not":
	the item waits in its usual section.

	This file decides nothing about which section wins: Core/Sections.lua asks Rules:Fits in priority order.

	(1.10.0-beta3) Number rules (Item Level, Vendor Value): the row's values are a range, v = { lo, hi }, whole numbers
	from 0 to the key's top. "At least 30" is 30 to the top; "at most 30" is 0 to 30. The row has the same shape as the
	others, so nothing else that reads or saves rules needs to know. Also the lists the rule editor offers: R:TypeGroups
	(the game's own item types) and R:Options (slots, qualities, bindings).

	(1.10.0-beta4) The Filters window uses the same rules. Three more keys are for filters only (filterOnly): the
	section an item is in, the bag it sits in, and how long it has been in your bags. They are about the moment or the
	place, so a section never uses them: in a section's rules such a row fits nothing, like a key this version doesn't
	know. Rules:Fits takes a third argument, true when a filter asks.
--]]
local ADDON, ns = ...
local R = {}
ns.Rules = R

R.MAX_ROWS, R.MAX_VALUES = 12, 40

local BIND = { bop = "Soulbound", boe = "Binds when equipped", bou = "Binds when used", none = "No binding" }
local QUALITY = { [0] = "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact", "Heirloom" }
R.BIND_LABEL, R.QUALITY_LABEL = BIND, QUALITY

-- Each key: its name, whether a saved value is sound, and the item's own answers (a list; nil while not known).
R.KEYS = {
	type = {
		label = "Type",
		valid = function(v) return type(v) == "string" and #v <= 12 and (v:match("^%d+:%d+$") ~= nil or v:match("^%d+:%*$") ~= nil) end,
		of = function(rec)
			if type(rec.classID) ~= "number" then return nil end
			local t = { rec.classID .. ":*" }
			if type(rec.subclassID) == "number" then t[2] = rec.classID .. ":" .. rec.subclassID end
			return t
		end,
	},
	slot = {
		label = "Slot",
		valid = function(v) return type(v) == "string" and #v <= 40 and v:match("^INVTYPE_[%u%d_]+$") ~= nil end,
		of = function(rec)
			local e = rec.equipLoc
			if type(e) ~= "string" then return nil end
			if e == "" then return {} end   -- known: it goes in no slot
			return { e }
		end,
	},
	quality = {
		label = "Quality",
		valid = function(v) return type(v) == "number" and v >= 0 and v <= 7 and v == math.floor(v) end,
		of = function(rec) if type(rec.quality) == "number" then return { rec.quality } end end,
	},
	bind = {
		label = "Binding",
		valid = function(v) return BIND[v] ~= nil end,
		of = function(rec)
			if rec.isBound then return { "bop" } end
			local b = rec.bindType
			if type(b) ~= "number" then return nil end
			if b == 1 then return { "bop" } elseif b == 2 then return { "boe" } elseif b == 3 then return { "bou" } end
			return { "none" }
		end,
	},
}
-- (1.10.0-beta3) Number rules: one answer (not a list), and a row's two values are the range it must be inside.
local function wholeTo(top) return function(v) return type(v) == "number" and v >= 0 and v <= top and v == math.floor(v) end end
R.KEYS.ilvl = {
	label = "Item Level", number = true, top = 9999, valid = wholeTo(9999),
	of = function(rec) if type(rec.ilvl) == "number" then return rec.ilvl end end,
}
-- What a vendor pays for one, in copper (0: it can't be sold). The top is 9999g 99s 99c.
R.KEYS.price = {
	label = "Vendor Value", number = true, money = true, top = 99999999, valid = wholeTo(99999999),
	of = function(rec) if type(rec.sellPrice) == "number" then return rec.sellPrice end end,
}
R.KEY_ORDER = { "type", "slot", "quality", "bind", "ilvl", "price" }
-- (1.10.0-beta4) For filters only: where an item is and how long it has been there. Never a section's.
R.KEYS.sec = {
	label = "Section", filterOnly = true,
	valid = function(v) return type(v) == "string" and v ~= "" and #v <= 40 end,
	-- its section, and the section that one is a part of (Potions is part of Consumables)
	-- (1.10.0-beta5) and, on the tab the filter is for, the section it's in there too: one that only shows on some
	-- sheets. Both count, so a sheet filtered by Trade Goods keeps its cloth when a Cloth section splits that sheet.
	of = function(rec, ctx)
		local cat = rec.cat
		if type(cat) ~= "string" then return nil end
		local out = { cat }
		local parent = ns.PARENT_CAT and ns.PARENT_CAT[cat]
		if parent then out[#out + 1] = parent end
		if type(ctx) == "table" and ctx.sheet and ns.Sections then
			local here = ns.Sections:CatOn(rec, ctx.sheet)
			if type(here) == "string" and here ~= cat then out[#out + 1] = here end
		end
		return out
	end,
}
R.KEYS.bag = {
	label = "Bag", filterOnly = true,
	valid = function(v) return type(v) == "string" and v ~= "" and #v <= 80 end,
	of = function(rec) return { type(rec.where) == "string" and rec.where or "" } end,
}
-- Whole hours, 0 to 99; the item's own answer is exact (2.5 hours), so "at most 2" leaves it out.
R.KEYS.age = {
	label = "Time in Bags", number = true, filterOnly = true, top = 99, valid = wholeTo(99), unit = { "hour", "hours" },
	of = function(rec) if type(rec.firstSeen) == "number" then return (time() - rec.firstSeen) / 3600 end end,
}
R.FILTER_KEYS = { "sec", "bag", "age" }
-- (1.10.0-beta6) What ItemTree knows (another addon, optional: Core/ItemTree.lua). Four are yes or no: the one value
-- is "yes", so "is" means yes and "is not" means no. While ItemTree has no answer for an item (it isn't installed, is
-- turned off, isn't ready, or hasn't been asked about that item yet) the answer is nil and the rule fits nothing.
local function itemTree(label, field)
	return {
		label = label, addon = "ItemTree", yesNo = true,
		valid = function(v) return v == "yes" end,
		of = function(rec)
			local e = ns.ItemTree and ns.ItemTree:Facts(rec)
			if not e then return nil end
			return e[field] and { "yes" } or {}
		end,
	}
end
R.KEYS.it_prof = itemTree("Used by My Professions", "prof")
R.KEYS.it_quest = itemTree("Needed for a Quest", "quest")
R.KEYS.it_upgrade = itemTree("An Upgrade for Me", "upgrade")
R.KEYS.it_vendor = itemTree("Sold by Vendors", "vendor")
-- Its advice can change with prices and with how many you hold, so it's a filter's rule only: a section never moves
-- an item about as that changes.
R.KEYS.it_advice = {
	label = "ItemTree's Advice", addon = "ItemTree", filterOnly = true,
	valid = function(v) return type(v) == "string" and #v <= 24 and v:match("^%l+$") ~= nil end,
	of = function(rec)
		local e = ns.ItemTree and ns.ItemTree:Facts(rec)
		if not e then return nil end
		return e.tags
	end,
}
R.ADDON_KEYS = { "it_prof", "it_quest", "it_upgrade", "it_vendor", "it_advice" }
-- ItemTree's own words for its advice, as it tags an item (keep, equip and vendor seen in game, 22 Nov; the rest are
-- the tags its code names).
R.ADVICE = { "keep", "equip", "use", "open", "auction", "vendor", "disenchant", "worthless" }
local ADVICE_LABEL = { keep = "Keep", equip = "Equip", use = "Use", open = "Open", auction = "Auction", vendor = "Vendor",
	disenchant = "Disenchant", worthless = "Worthless", pet = "Pet" }

-- A row's values as a set, built once for each row table (never stored in the row: rows are saved data).
local sets = setmetatable({}, { __mode = "k" })
local function setOf(row)
	local s = sets[row]
	if not s then
		s = {}
		for _, v in ipairs(row.v) do s[v] = true end
		sets[row] = s
	end
	return s
end
local function rowFits(row, rec, filter)
	local def = R.KEYS[row.k]
	if not def then return false end
	if def.filterOnly and not filter then return false end   -- (1.10.0-beta4) a filter's key in a section's rules
	local have = def.of(rec, filter)
	if have == nil then return false end
	if def.number then
		local lo, hi = row.v[1], row.v[2]
		-- (1.10.0-beta4) a range that reaches the key's top has no upper end: "at least 2 hours" takes a week-old item
		return type(lo) == "number" and type(hi) == "number" and have >= lo and (hi >= def.top or have <= hi)
	end
	local set, hit = setOf(row), false
	for _, a in ipairs(have) do if set[a] then hit = true; break end end
	if row.n then return not hit end
	return hit
end
local function usable(row) return type(row) == "table" and type(row.k) == "string" and type(row.v) == "table" and #row.v > 0 end

-- Does the item fit these rules? Rows with no values are skipped; rules with no usable row fit nothing.
-- filter (1.10.0-beta4): true when a filter asks, so the keys that are only a filter's count too. (1.10.0-beta5) Or
-- a table, { sheet = the tab the filter is for }, which a Section rule needs.
function R:Fits(rules, rec, filter)
	if type(rules) ~= "table" or type(rules.rows) ~= "table" or type(rec) ~= "table" then return false end
	local any, used = rules.mode == "any", 0
	for _, row in ipairs(rules.rows) do
		if usable(row) then
			used = used + 1
			local ok = rowFits(row, rec, filter)
			if any and ok then return true end
			if not any and not ok then return false end
		end
	end
	return used > 0 and not any
end
function R:HasRules(rules)
	if type(rules) ~= "table" or type(rules.rows) ~= "table" then return false end
	for _, row in ipairs(rules.rows) do if usable(row) then return true end end
	return false
end

-- A clean copy of saved or imported rules (never trusted as they come), or nil when nothing usable is left. A row with
-- a key this version doesn't know is kept as long as it's sound (it fits nothing here; dropping it would make an "all"
-- section take MORE items than its author meant).
function R.Clean(rules)
	if type(rules) ~= "table" or type(rules.rows) ~= "table" then return nil end
	local out = { mode = rules.mode == "any" and "any" or "all", rows = {} }
	for _, row in ipairs(rules.rows) do
		if #out.rows >= R.MAX_ROWS then break end
		if type(row) == "table" and type(row.k) == "string" and #row.k <= 24 and row.k:match("^[%a_]+$") and type(row.v) == "table" then
			local def = R.KEYS[row.k]
			if def and def.number then
				-- (1.10.0-beta3) a range: its first two sound numbers, low then high (one alone means "at least")
				local lo, hi
				for _, v in ipairs(row.v) do
					if def.valid(v) then
						if lo == nil then lo = v else hi = v; break end
					end
				end
				if lo ~= nil then
					hi = hi or def.top
					if lo > hi then lo, hi = hi, lo end
					out.rows[#out.rows + 1] = { k = row.k, v = { lo, hi } }
				end
			else
				local vals, seen = {}, {}
				for _, v in ipairs(row.v) do
					if #vals >= R.MAX_VALUES then break end
					local ok
					if def then ok = def.valid(v)
					else ok = (type(v) == "string" and #v <= 40) or (type(v) == "number" and v == v and v > -1e9 and v < 1e9) end
					if ok and not seen[v] then seen[v] = true; vals[#vals + 1] = v end
				end
				if #vals > 0 then out.rows[#out.rows + 1] = { k = row.k, v = vals, n = (row.n == true) or nil } end
			end
		end
	end
	if #out.rows == 0 then return nil end
	return out
end

------------------------------------------------------------------------
-- Words
------------------------------------------------------------------------
-- A type's name: the game's own lists where it has them, else what an item of that type in your bags says.
local typeNames = {}
local function gameName(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, name = pcall(fn, ...)
	if ok and type(name) == "string" and name ~= "" and not name:find("OBSOLETE") then return name end
end
local function fromBags(class, sub)
	for _, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
		for _, r in ipairs(list) do
			if r.classID == class and (sub == nil or r.subclassID == sub) and type(r.itemType) == "string" and r.itemType ~= "" then
				return r.itemType, r.itemSubType
			end
		end
	end
end
function R:TypeLabel(v)
	if typeNames[v] then return typeNames[v] end
	local c, s = tostring(v):match("^(%d+):(.+)$")
	c = tonumber(c)
	if not c then return tostring(v) end
	local sub = tonumber(s)
	local class = gameName(C_Item and C_Item.GetItemClassInfo or rawget(_G, "GetItemClassInfo"), c)
	local subName = sub and gameName(C_Item and C_Item.GetItemSubClassInfo or rawget(_G, "GetItemSubClassInfo"), c, sub) or nil
	if not class or (sub and not subName) then
		local t, st = fromBags(c, sub)
		class = class or t
		if sub then subName = subName or (type(st) == "string" and st ~= "" and st or nil) end
	end
	local label
	if not class then label = sub and ("Type %d:%d"):format(c, sub) or ("Type %d"):format(c)
	elseif not sub then label = class
	elseif not subName or subName == class then label = class
	else label = class .. ": " .. subName end
	-- (kept only once the game or an item has named it: a fallback is asked again later)
	if class and (not sub or subName) then typeNames[v] = label end
	return label
end
function R:ValueLabel(k, v)
	if k == "type" then return self:TypeLabel(v)
	elseif k == "slot" then local s = rawget(_G, tostring(v)); return type(s) == "string" and s ~= "" and s or tostring(v)
	elseif k == "quality" then
		local s = rawget(_G, ("ITEM_QUALITY%d_DESC"):format(tonumber(v) or -1))
		return type(s) == "string" and s ~= "" and s or QUALITY[v] or tostring(v)
	elseif k == "bind" then return BIND[v] or tostring(v)
	elseif k == "it_advice" then
		return ADVICE_LABEL[v] or (tostring(v):gsub("^%l", string.upper))
	elseif R.KEYS[k] and R.KEYS[k].yesNo then
		return v == "yes" and "Yes" or tostring(v)
	elseif k == "sec" then
		-- (1.10.0-beta4) a section by its name: BagSmith's own, or yours (a deleted one keeps its id)
		local label = (ns.CAT_LABEL and ns.CAT_LABEL[v]) or (ns.Sections and ns.Sections.IsCustom and ns.Sections:IsCustom(v) and ns.Sections:Label(v))
		return type(label) == "string" and label ~= "" and label or tostring(v)
	end
	return tostring(v)
end
function R:KeyLabel(k) local def = R.KEYS[k]; return def and def.label or "Another addon's rule" end
-- "Type is Trade Goods: Cloth or Trade Goods: Leather", "Binding is not Soulbound"
-- (1.10.0-beta3) Money in plain words: "1g 50s", "20c". A range in words: "is at least 30", "is between 1s and 5s".
function R.Money(copper)
	copper = math.max(0, math.floor(tonumber(copper) or 0))
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local parts = {}
	if g > 0 then parts[#parts + 1] = ("%dg"):format(g) end
	if s > 0 then parts[#parts + 1] = ("%ds"):format(s) end
	if c > 0 or #parts == 0 then parts[#parts + 1] = ("%dc"):format(c) end
	return table.concat(parts, " ")
end
function R:RangeText(k, lo, hi)
	local def = R.KEYS[k]
	-- (1.10.0-beta4) a key with a unit says it: "at least 2 hours", "between 1 and 3 hours"
	local unit = def and def.unit
	local function say(n, bare)
		if def and def.money then return R.Money(n) end
		if unit and not bare then return ("%d %s"):format(n, n == 1 and unit[1] or unit[2]) end
		return ("%d"):format(n)
	end
	if def and hi >= def.top then return "is at least " .. say(lo) end
	if lo == hi then return "is " .. say(lo) end
	if lo <= 0 then return "is at most " .. say(hi) end
	return ("is between %s and %s"):format(say(lo, true), say(hi))
end
function R:RowText(row)
	if not usable(row) then return "" end
	local def = R.KEYS[row.k]
	if def and def.number then
		local lo, hi = row.v[1], row.v[2]
		if type(lo) ~= "number" or type(hi) ~= "number" then return "" end
		return ("%s %s"):format(def.label, self:RangeText(row.k, lo, hi))
	end
	-- (1.10.0-beta3: a name is said once, so two slots the game calls the same, like Chest and Robe, read as one)
	local names, said = {}, {}
	for _, v in ipairs(row.v) do
		local name = self:ValueLabel(row.k, v)
		if not said[name] then said[name] = true; names[#names + 1] = name end
	end
	local list = #names <= 2 and table.concat(names, " or ") or (table.concat(names, ", ", 1, #names - 1) .. " or " .. names[#names])
	return ("%s %s %s"):format(self:KeyLabel(row.k), row.n and "is not" or "is", list)
end
-- One line for a section's rules: "Type is Trade Goods: Cloth"; with more rows, "Fits all: A; B" or "Fits any: A; B".
function R:Summary(rules)
	if not self:HasRules(rules) then return "" end
	local parts = {}
	for _, row in ipairs(rules.rows) do if usable(row) then parts[#parts + 1] = self:RowText(row) end end
	if #parts == 1 then return parts[1] end
	return (rules.mode == "any" and "Fits any: " or "Fits all: ") .. table.concat(parts, "; ")
end

-- What an item says about itself, for "New Section From This Item": { k, v, label, text } for each fact it has.
function R:FactsOf(rec)
	local out = {}
	if type(rec) ~= "table" then return out end
	for _, k in ipairs(R.KEY_ORDER) do
		-- (1.10.0-beta3: a number rule is a range to choose, not something two items have "the same": the editor's)
		local have = not R.KEYS[k].number and R.KEYS[k].of(rec) or nil
		local v = have and have[#have]   -- the most exact answer (a type's class and subclass, not the class alone)
		if v ~= nil then
			local text
			if k == "type" and type(rec.itemType) == "string" and rec.itemType ~= "" then
				-- the item's own words (the game's lists may not be there to ask)
				local st = rec.itemSubType
				text = (type(st) == "string" and st ~= "" and st ~= rec.itemType) and (rec.itemType .. ": " .. st) or rec.itemType
				if not typeNames[v] then typeNames[v] = text end
			else
				text = self:ValueLabel(k, v)
			end
			out[#out + 1] = { k = k, v = v, label = R.KEYS[k].label, text = text }
		end
	end
	return out
end

------------------------------------------------------------------------
-- The lists the rule editor offers (1.10.0-beta3)
------------------------------------------------------------------------
-- Item types, class by class, from the game's own lists (so a new kind of item shows up by itself):
-- { { class = 7, label = "Trade Goods", any = "7:*", kinds = { { v = "7:5", label = "Cloth" }, ... } }, ... }.
-- Names the game marks OBSOLETE are left out, and the WoW Token (no bag holds one). Where the game has no lists to
-- ask, the types of the items in your bags and bank.
local SKIP_CLASS = { [18] = true }
local typeGroups
local function typesInBags()
	local byClass, order = {}, {}
	for _, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
		for _, r in ipairs(list) do
			local c, sub = r.classID, r.subclassID
			if type(c) == "number" and type(r.itemType) == "string" and r.itemType ~= "" and not SKIP_CLASS[c] then
				local g = byClass[c]
				if not g then g = { class = c, label = r.itemType, any = c .. ":*", kinds = {}, has = {} }; byClass[c] = g; order[#order + 1] = g end
				if type(sub) == "number" and not g.has[sub] and type(r.itemSubType) == "string" and r.itemSubType ~= "" then
					g.has[sub] = true
					g.kinds[#g.kinds + 1] = { v = c .. ":" .. sub, label = r.itemSubType, sub = sub }
				end
			end
		end
	end
	table.sort(order, function(a, b) return a.class < b.class end)
	for _, g in ipairs(order) do g.has = nil; table.sort(g.kinds, function(a, b) return a.sub < b.sub end) end
	return order
end
function R:TypeGroups()
	if typeGroups then return typeGroups end
	local classFn = C_Item and C_Item.GetItemClassInfo or rawget(_G, "GetItemClassInfo")
	local subFn = C_Item and C_Item.GetItemSubClassInfo or rawget(_G, "GetItemSubClassInfo")
	local out = {}
	for c = 0, 24 do
		local name = not SKIP_CLASS[c] and gameName(classFn, c) or nil
		if name then
			local g = { class = c, label = name, any = c .. ":*", kinds = {} }
			for sub = 0, 31 do
				local subName = gameName(subFn, c, sub)
				if subName then g.kinds[#g.kinds + 1] = { v = c .. ":" .. sub, label = subName, sub = sub } end
			end
			out[#out + 1] = g
		end
	end
	if #out == 0 then return typesInBags() end
	typeGroups = out
	return out
end
-- Slots, qualities and bindings: { { label = "Chest", v = { "INVTYPE_CHEST", "INVTYPE_ROBE" } }, ... }. An entry can
-- stand for several values: slots the game gives one name (Chest and Robe, the two kinds of Ranged) are one entry.
local SLOTS = { "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK", "INVTYPE_CHEST", "INVTYPE_ROBE", "INVTYPE_BODY",
	"INVTYPE_TABARD", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_FINGER", "INVTYPE_TRINKET",
	"INVTYPE_WEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_2HWEAPON", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE",
	"INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN", "INVTYPE_RELIC", "INVTYPE_AMMO", "INVTYPE_BAG", "INVTYPE_QUIVER" }
local BIND_ORDER = { "bop", "boe", "bou", "none" }
function R:Options(k)
	local out = {}
	if k == "slot" then
		local byLabel, seen = {}, {}
		local function add(token)
			if seen[token] then return end
			local label = rawget(_G, token)
			if type(label) ~= "string" or label == "" then return end
			seen[token] = true
			local o = byLabel[label]
			if not o then o = { label = label, v = {} }; byLabel[label] = o; out[#out + 1] = o end
			o.v[#o.v + 1] = token
		end
		for _, token in ipairs(SLOTS) do add(token) end
		-- and any slot an item of yours names that isn't in that list
		for _, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
			for _, r in ipairs(list) do
				if type(r.equipLoc) == "string" and R.KEYS.slot.valid(r.equipLoc) then add(r.equipLoc) end
			end
		end
	elseif k == "quality" then
		for q = 0, 5 do out[#out + 1] = { label = self:ValueLabel("quality", q), v = { q }, quality = q } end
	elseif k == "bind" then
		for _, b in ipairs(BIND_ORDER) do out[#out + 1] = { label = BIND[b], v = { b } } end
	elseif k == "it_advice" then
		-- (1.10.0-beta6)
		for _, word in ipairs(R.ADVICE) do out[#out + 1] = { label = ADVICE_LABEL[word], v = { word } } end
	elseif R.KEYS[k] and R.KEYS[k].yesNo then
		out[1] = { label = "Yes", v = { "yes" } }
	end
	return out
end
