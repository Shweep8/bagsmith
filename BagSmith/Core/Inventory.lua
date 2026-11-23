--[[
	BagSmith - Core/Inventory.lua (1.9.0)
	What BagSmith knows about an item, in its tooltip (Shweep, 16 Nov): an Inventory block with the total and each of
	your characters' counts by place (Bags, Bank, Equipped), on any item tooltip (your bags, the auction house, a vendor,
	a chat link, loot). And your gold, on the footer's gold: each character's on this realm, Shift for the account.

	Whose: your characters on this realm (on WoW Forever the realm is the ruleset, Normal and the others, and characters
	on one can mail each other), the one you're playing included, by name only. Where: the bags (with the keyring and
	the reagent bag), the bank (as of that character's last visit) and what they're wearing. Mail is left out: it
	expires, returns and moves between characters unseen, so its counts could be wrong.

	The counts are worked out once and kept: your other characters' when their saved data changes, yours when your
	bags, bank or gear change. A tooltip only looks its item up.
--]]

local ADDON, ns = ...
local Inv = {}
ns.Inventory = Inv

Inv.PLACES = { "bags", "bank", "equipped" }
Inv.PLACE_LABEL = { bags = "Bags", bank = "Bank", equipped = "Equipped" }
Inv.COUNT_COLOR = { 0.55, 0.78, 1 }   -- the counts' soft blue (as the screenshot Shweep sent)

local others, mine = nil, nil   -- itemID -> { [charKey] = { bags = n, bank = n, equipped = n } }

local function realm() return ns:Realm() end   -- (1.9.6) the game's answer, or what stands in for it (Core/Init.lua)
local function add(index, id, key, place, n)
	id = tonumber(id)
	if not id or (n or 0) <= 0 then return end
	local byChar = index[id]
	if not byChar then byChar = {}; index[id] = byChar end
	local c = byChar[key]
	if not c then c = {}; byChar[key] = c end
	c[place] = (c[place] or 0) + n
end
local function addList(index, list, key, place)
	for _, r in ipairs(list or {}) do
		if type(r) == "table" and r.itemID then add(index, r.itemID, key, place, tonumber(r.count) or 1) end
	end
end

-- Your other characters on this realm, from their saved data.
function Inv:Others()
	if others then return others end
	others = {}
	local me, here = ns:CharKey(), realm()
	for key, data in pairs(BagSmithDB and BagSmithDB.cache or {}) do
		if key ~= me and not ns:IsOwnKey(key) and type(data) == "table" and data.realm == here then
			addList(others, data.items, key, "bags")
			addList(others, data.bank, key, "bank")
			addList(others, data.equipped, key, "equipped")
		end
	end
	return others
end
-- The one you're playing, live: the bags now, the bank as last seen (this session, or saved), what you're wearing.
function Inv:Mine()
	if mine then return mine end
	mine = {}
	local me = ns:CharKey()
	addList(mine, ns.items, me, "bags")
	-- (1.9.0-beta24, the beta23 audit's P2) the bank seen this session decides, even empty: an emptied bank looked
	-- unseen (no records) and fell back to the saved one, so its last items still counted. As Currency reads it.
	local bank = ns.bankScanned and ns.bankItems or (ns.SavedBank and ns:SavedBank())
	addList(mine, bank, me, "bank")
	addList(mine, Inv.Worn(), me, "equipped")
	return mine
end
function Inv:Invalidate(all) mine = nil; if all then others = nil end; Inv:Touch() end   -- (1.9.5-beta1) and the Global list

-- What you're wearing (slots 1 to 19), as { slot, itemID, link, count }: saved with each character, counted live.
function Inv.Worn()
	local out = {}
	if type(GetInventoryItemID) ~= "function" then return out end
	for slot = 1, 19 do
		local id = GetInventoryItemID("player", slot)
		if id then out[#out + 1] = { slot = slot, itemID = id, link = GetInventoryItemLink and GetInventoryItemLink("player", slot) or nil, count = 1 } end
	end
	return out
end

-- One item's counts: a list of { key, name, class, isMe, total, bags, bank, equipped }, you first, then the most, then
-- by name; and the total.
function Inv:Counts(itemID)
	itemID = tonumber(itemID)
	if not itemID then return {}, 0 end
	local me = ns:CharKey()
	local list, total = {}, 0
	local function take(byChar)
		for key, c in pairs(byChar or {}) do
			local data = BagSmithDB and BagSmithDB.cache and BagSmithDB.cache[key]
			local e = { key = key, isMe = key == me, bags = c.bags or 0, bank = c.bank or 0, equipped = c.equipped or 0 }
			e.total = e.bags + e.bank + e.equipped
			if key == me then
				e.name = ns.DisplayName and ns:DisplayName("player") or (UnitName and UnitName("player")) or "?"
				-- (beta2, Shweep: the character you're on showed no class icon) both of UnitClass's values: "x and f()" keeps only one
				local class
				if UnitClass then class = select(2, UnitClass("player")) end
				e.class = class
			else
				e.name, e.class = data and data.name or key:match("^(.-) %- ") or key, data and data.class
			end
			if e.total > 0 then list[#list + 1] = e; total = total + e.total end
		end
	end
	take(self:Mine()[itemID])
	take(self:Others()[itemID])
	table.sort(list, function(a, b)
		if a.isMe ~= b.isMe then return a.isMe end
		if a.total ~= b.total then return a.total > b.total end
		return (a.name or "") < (b.name or "")
	end)
	return list, total
end

-- A class's icon, inline in a tooltip line (the game's class icons sheet).
function Inv.ClassIcon(class, size)
	local c = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
	if not c then return "" end
	size = size or 14
	return ("|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:%d:%d:0:0:256:256:%d:%d:%d:%d|t "):format(size, size,
		math.floor(c[1] * 256 + 0.5), math.floor(c[2] * 256 + 0.5), math.floor(c[3] * 256 + 0.5), math.floor(c[4] * 256 + 0.5))
end
local function hex(r, g, b) return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)) end
function Inv.Places(e)
	local parts = {}
	for _, p in ipairs(Inv.PLACES) do if (e[p] or 0) > 0 then parts[#parts + 1] = ("%s: %d"):format(Inv.PLACE_LABEL[p], e[p]) end end
	return table.concat(parts, ", ")
end

-- The Inventory block, on an item's tooltip.
function Inv:AddTooltipLines(tip, itemID)
	if not (tip and ns.db and ns.db.tipInventory) then return end
	local list, total = self:Counts(itemID)
	if total <= 0 then return end
	local br, bg, bb = unpack(self.COUNT_COLOR)
	if tip.AddLine then tip:AddLine(" ") end
	if tip.AddDoubleLine then
		tip:AddDoubleLine("Inventory", ("Total: %d"):format(total), 1, 0.82, 0, br, bg, bb)
		for _, e in ipairs(list) do
			local r, g, b = ns.ClassColor(e.class)
			tip:AddDoubleLine(self.ClassIcon(e.class) .. hex(r, g, b) .. (e.name or "?") .. "|r", self.Places(e), 1, 1, 1, br, bg, bb)
		end
	end
	if tip.Show then tip:Show() end
end

-- The tooltip's item: the game's tooltip data when it has it, else its link.
local function itemOf(tip, data)
	if type(data) == "table" and tonumber(data.id) then return tonumber(data.id) end
	local link = tip and tip.GetItem and select(2, tip:GetItem())
	local id = link and link:match("item:(%d+)")
	return tonumber(id)
end
Inv.ItemOf = itemOf
-- The game's own item tooltips: the one you hover with, and a chat link's (shopping comparisons and other addons' are left alone).
local function ours(tip) return tip ~= nil and (tip == _G.GameTooltip or tip == _G.ItemRefTooltip) end
function Inv:InstallTooltipHook()
	if self.hooked then return end
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, data)
			if ours(tip) then ns:Guard("Inventory tooltip", Inv.AddTooltipLines, Inv, tip, itemOf(tip, data)) end
		end)
		self.hooked = "TooltipDataProcessor"
	else
		for _, name in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
			local tip = _G[name]
			if tip and tip.HookScript then
				tip:HookScript("OnTooltipSetItem", function(t) ns:Guard("Inventory tooltip", Inv.AddTooltipLines, Inv, t, itemOf(t)) end)
			end
		end
		self.hooked = "OnTooltipSetItem"
	end
end

------------------------------------------------------------------------
-- Global Inventory (1.9.0-beta2): every item on your characters, as read-only rows
------------------------------------------------------------------------
-- A worn item as a record (the game's item info when it has it).
local function wornRecord(e)
	local id = tonumber(e.itemID)
	local rec = { itemID = id, link = e.link, count = 1, quality = 1, name = (e.link and e.link:match("%[(.-)%]")) or ("item " .. tostring(id)) }
	local info = C_Item and C_Item.GetItemInfo or GetItemInfo
	if type(info) == "function" then
		local ok, name, _, quality, ilvl, minLevel, iType, iSub, _, equipLoc, icon, sellPrice, classID, subclassID = pcall(info, e.link or id)
		if ok and name then
			rec.name, rec.quality, rec.ilvl, rec.minLevel, rec.itemType, rec.itemSubType = name, quality, ilvl, minLevel, iType, iSub
			rec.equipLoc, rec.icon, rec.sellPrice, rec.classID, rec.subclassID = equipLoc, icon, sellPrice, classID, subclassID
		end
		-- (1.10.0-beta14, R3) the Common above, and a name that is only "item 1234", are for showing until the game
		-- describes the item
		if not (ok and name and quality) then rec.qualityUnknown = true end
		if not (ok and name) and not (e.link and (e.link:match("%[(.-)%]") or "") ~= "") then rec.nameUnknown = true end
	end
	if not rec.icon and GetItemIcon then rec.icon = GetItemIcon(id) end
	rec.isBound = true
	rec.ownCat = (ns.Sections and ns.Sections:OwnCategory(rec)) or ns:Categorize(rec)
	rec.cat = ns.Sections and ns.Sections:Apply(rec, rec.ownCat) or rec.ownCat
	return rec
end
Inv.WornRecord = wornRecord
-- Each character's lists: { key, name, class, isMe, bags = {...}, bank = {...}, equipped = {...} }, this realm's
-- (every realm's with all = true), you first.
function Inv:Characters(all)
	local me, here = ns:CharKey(), realm()
	local out = {}
	local myClass
	if UnitClass then myClass = select(2, UnitClass("player")) end
	local bank = ns.bankScanned and ns.bankItems or select(1, ns:CachedRecords(me, true))   -- (beta24, as Mine)
	local worn = {}
	for _, e in ipairs(Inv.Worn()) do worn[#worn + 1] = wornRecord(e) end
	out[1] = { key = me, isMe = true, class = myClass, name = ns.DisplayName and ns:DisplayName("player") or "?", bags = ns.items or {}, bank = bank or {}, equipped = worn }
	local keys = {}
	for key, data in pairs(BagSmithDB and BagSmithDB.cache or {}) do
		if key ~= me and not ns:IsOwnKey(key) and type(data) == "table" and (all or data.realm == here) then keys[#keys + 1] = key end
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local data = BagSmithDB.cache[key]
		local e = { key = key, class = data.class, name = data.name or key, bags = select(1, ns:CachedRecords(key, false)) or {}, bank = select(1, ns:CachedRecords(key, true)) or {}, equipped = {} }
		for _, w in ipairs(data.equipped or {}) do if type(w) == "table" and w.itemID then e.equipped[#e.equipped + 1] = wornRecord(w) end end
		out[#out + 1] = e
	end
	return out
end
-- (1.9.0-beta4, Shweep: "a hidden shared profile") Global Inventory's own settings, saved for the account
-- (BagSmithDB.globalInv), outside every profile: sort, Sections or All, other rulesets, its column
-- widths, collapsed sections and its own pinned currencies (none at first). The first time, sort and sections start
-- from the profile in use; after that nothing here touches a profile, and a profile never touches this.
function Inv:Settings()
	if type(BagSmithDB) ~= "table" then return { colWidths = {}, collapsed = {}, pins = {} } end
	local g = BagSmithDB.globalInv
	if type(g) ~= "table" then
		local d = ns.db or {}
		g = { sort = d.sort, grp = (d.grp == "bag") and "type" or d.grp, allRealms = false, colWidths = {}, collapsed = {}, pins = {} }
		BagSmithDB.globalInv = g
	end
	g.colWidths, g.collapsed, g.pins = g.colWidths or {}, g.collapsed or {}, g.pins or {}
	-- (1.9.0-beta6, Shweep: Global Columns and Global Sheets) its own columns (which, and their order) and its own tabs
	-- (which, and their order; the built-in ones only), started from your bags' the first time
	local d = ns.db or {}
	local function copy(t) local o = {}; for i, v in ipairs(type(t) == "table" and t or {}) do o[i] = v end return o end
	if not g.cols then g.cols = copy(d.cols) end
	if not g.colOrder then g.colOrder = copy(d.colOrder) end
	if not g.tabOrder then
		g.tabOrder = {}
		for _, id in ipairs(type(d.tabOrder) == "table" and d.tabOrder or ns.BASE_TABS or {}) do if ns.TAB_LABEL and ns.TAB_LABEL[id] then g.tabOrder[#g.tabOrder + 1] = id end end
		for _, id in ipairs(ns.BASE_TABS or {}) do if not ns.IndexOf(g.tabOrder, id) then g.tabOrder[#g.tabOrder + 1] = id end end
	end
	g.hiddenTabs = g.hiddenTabs or {}
	-- (1.9.0-beta7) AH Price starts on there (it was the fixed value column with a price source), once
	if not g.ahOn then
		if not ns.IndexOf(g.cols, "ah") then g.cols[#g.cols + 1] = "ah" end
		if not ns.IndexOf(g.colOrder, "ah") then g.colOrder[#g.colOrder + 1] = "ah" end
		g.ahOn = true
	end
	return g
end
-- Your characters: { key, name, class, isMe, data }, this realm's (every realm's with all), you first.
function Inv:CharKeys(all)
	local me, here = ns:CharKey(), realm()
	local myClass
	if UnitClass then myClass = select(2, UnitClass("player")) end
	local out = { { key = me, isMe = true, class = myClass, name = ns.DisplayName and ns:DisplayName("player") or "?", data = BagSmithDB and BagSmithDB.cache and BagSmithDB.cache[me] } }
	local keys = {}
	for key, data in pairs(BagSmithDB and BagSmithDB.cache or {}) do
		if key ~= me and not ns:IsOwnKey(key) and type(data) == "table" and (all or data.realm == here) then keys[#keys + 1] = key end
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local data = BagSmithDB.cache[key]
		out[#out + 1] = { key = key, name = data.name or key, class = data.class, data = data }
	end
	return out
end
-- Free bag slots, totalled over your characters (as Bag Slot Count counts them: special bags only with All Free Slots;
-- never the reagent bag or the keyring), and each character's: free, total, { { name, class, free, total } }.
function Inv:FreeSlots(all)
	local every = ns.db and ns.db.bagSlotCount == "all"
	local free, total, list = 0, 0, {}
	for _, c in ipairs(self:CharKeys(all)) do
		local f, t = 0, 0
		if c.isMe then
			local g, gt, _, _, special = ns:FreeSlots()
			f, t = g, gt
			if every then for _, k in pairs(special or {}) do f, t = f + k.free, t + k.total end end
		else
			for bag, info in pairs(c.data and c.data.bags or {}) do
				if type(info) == "table" and not info.reagent and tostring(bag) ~= tostring(ns.KEYRING) and (every or not info.kind) then
					f, t = f + (tonumber(info.free) or 0), t + (tonumber(info.size) or 0)
				end
			end
		end
		free, total = free + f, total + t
		list[#list + 1] = { name = c.name, class = c.class, free = f, total = t, isMe = c.isMe }
	end
	return free, total, list
end
-- The rows: one per item, every character and place together, opening into a row per character (beta5, Shweep: "only
-- have the accordion view and simplify this": beta4's All Rows is gone). Each is a display row: read only, with who (a
-- name, or "N characters") and where. only: the places to take (beta4: the Bank tab's bank-only filter), every place
-- when nil.
-- (1.9.5-beta1, Shweep's optimization review: opening Global Inventory and searching cost a 53 ms frame) the list is
-- built once and kept until something it's made of changes: your bags (each scan), the bank opening, what you wear,
-- a character's data saved, or any setting (sections, profiles). Kept per realm choice and tab (All or Bank). As a
-- safety net it's also rebuilt whenever the live bag or bank lists have been replaced since it was built. Each
-- caller gets its own list (the same records): sorting or filtering it never touches the kept one. Inv.builds counts
-- the builds.
local kept, generation = {}, 0
function Inv:Touch() generation = generation + 1 end
Inv.builds = 0
function Inv:GlobalRecords(all, only)
	local key = (all and "all" or "realm") .. ((only and only.bank) and ":bank" or "") .. ((only and only.bags) and ":bags" or "") .. ((only and only.equipped) and ":equipped" or "")
	local k = kept[key]
	if not (k and k.generation == generation and k.items == ns.items and k.bank == ns.bankItems) then
		k = { generation = generation, items = ns.items, bank = ns.bankItems, list = self:BuildGlobalRecords(all, only) }
		kept[key] = k
		Inv.builds = Inv.builds + 1
	end
	local out = {}
	for i, r in ipairs(k.list) do out[i] = r end
	return out
end
function Inv:BuildGlobalRecords(all, only)
	local out, byKey, order = {}, {}, {}
	for _, c in ipairs(self:Characters(all)) do
		for _, place in ipairs(self.PLACES) do
			if not only or only[place] then
			for _, r in ipairs(c[place] or {}) do
				if type(r) == "table" and r.itemID then
					local k = tostring(r.itemID)
					local g = byKey[k]
					if not g then
						g = { rep = r, count = 0, chars = {}, charList = {}, places = {}, placeList = {} }
						byKey[k] = g; order[#order + 1] = k
					end
					g.count = g.count + (tonumber(r.count) or 1)
					if not g.chars[c.key] then g.chars[c.key] = c; g.charList[#g.charList + 1] = c end
					-- (beta3) each character's own count and places, for the accordion
					g.per = g.per or {}
					local pc = g.per[c.key]
					if not pc then pc = { count = 0, places = {} }; g.per[c.key] = pc end
					pc.count = pc.count + (tonumber(r.count) or 1)
					pc.places[place] = true
					if not g.places[place] then g.places[place] = true; g.placeList[#g.placeList + 1] = place end
				end
			end
			end
		end
	end
	for _, k in ipairs(order) do
		local g = byKey[k]
		local rec = {}
		for key, v in pairs(g.rep) do rec[key] = v end
		rec.bag, rec.slot, rec.guid, rec.members, rec.merged, rec.stacks = nil, nil, nil, nil, nil, nil
		rec.count = g.count
		rec.display, rec.cached, rec.global, rec.maxStack, rec.isNew = true, true, true, 1, nil
		if #g.charList == 1 then rec.who, rec.whoClass = g.charList[1].name, g.charList[1].class
		else rec.who = ("%d characters"):format(#g.charList) end
		local labels = {}
		for _, p in ipairs(self.PLACES) do if g.places[p] then labels[#labels + 1] = self.PLACE_LABEL[p] end end
		rec.where = table.concat(labels, ", ")
		rec.displayWhy = "In Global Inventory: every item on your characters, read only."
		-- (1.9.0-beta6) its section by BagSmith's defaults: no character's moves, splits or junk marks
		if ns.Sections then
			local cat = ns:WithDefaultSections(function() return ns.Sections:OwnCategory(rec) end) or rec.cat
			rec.cat = ns.PARENT_CAT[cat] or cat   -- a split section saved with the item: its parent (no splits there)
		end
		-- (1.9.0-beta3, Shweep) the accordion: an item more than one character has opens into a row per character (their
		-- class icon and name first, indented; their count and places)
		if #g.charList > 1 then
			rec.displayWhy = "Click to see each character's."
			local kids = {}
			for _, c in ipairs(g.charList) do
				local pc = g.per[c.key]
				local kid = {}
				for key, v in pairs(rec) do kid[key] = v end
				kid.globalChild, kid.globalKids, kid.who, kid.whoClass = true, nil, c.name, c.class
				kid.count = pc.count
				local where = {}
				for _, p in ipairs(self.PLACES) do if pc.places[p] then where[#where + 1] = self.PLACE_LABEL[p] end end
				kid.where = table.concat(where, ", ")
				kid.displayWhy = ("%s has %d (%s)."):format(c.name or "?", pc.count, kid.where)
				kids[#kids + 1] = kid
			end
			rec.globalKids = kids
		end
		out[#out + 1] = rec
	end
	return out
end

------------------------------------------------------------------------
-- Gold
------------------------------------------------------------------------
-- Your gold: { key, name, class, gold, isMe } for this realm's characters (or every realm's, account = true), you first
-- then the most; and the total.
function Inv:Gold(account)
	local me, here = ns:CharKey(), realm()
	local list, total = {}, 0
	local function push(e) list[#list + 1] = e; total = total + e.gold end
	local live = GetMoney and GetMoney() or 0
	local myClass
	if UnitClass then myClass = select(2, UnitClass("player")) end
	push({ key = me, isMe = true, gold = live, class = myClass, name = ns.DisplayName and ns:DisplayName("player") or (UnitName and UnitName("player")) or "?" })
	for key, data in pairs(BagSmithDB and BagSmithDB.cache or {}) do
		if key ~= me and not ns:IsOwnKey(key) and type(data) == "table" and (account or data.realm == here) then
			local g = tonumber(data.gold) or 0
			if g > 0 then push({ key = key, gold = g, class = data.class, name = data.name or key }) end
		end
	end
	table.sort(list, function(a, b)
		if a.isMe ~= b.isMe then return a.isMe end
		if a.gold ~= b.gold then return a.gold > b.gold end
		return (a.name or "") < (b.name or "")
	end)
	return list, total
end
local function coins(v) return (GetMoneyString and GetMoneyString(v or 0, true)) or (GetCoinTextureString and GetCoinTextureString(v or 0)) or tostring(v or 0) end
-- The gold tooltip's lines (the footer's gold button). Shift shows the account.
function Inv:AddGoldLines(tip)
	local account = IsShiftKeyDown and IsShiftKeyDown() and true or false
	local list, total = self:Gold(account)
	tip:AddDoubleLine(account and "Account-wide gold" or "Realm-wide gold", coins(total), 1, 0.82, 0, 1, 1, 1)
	for _, e in ipairs(list) do
		local r, g, b = ns.ClassColor(e.class)
		tip:AddDoubleLine(self.ClassIcon(e.class) .. hex(r, g, b) .. (e.name or "?") .. "|r", coins(e.gold), 1, 1, 1, 1, 1, 1)
	end
	-- (beta2, Shweep) what Shift does, always said, small and dim
	if not account then
		tip:AddLine("Shift - See all Rulesets", 0.5, 0.5, 0.5)
		Inv.SmallLine(tip)
	end
end
-- The tooltip's last line in the small font; put back the next time the tooltip is cleared (its lines are reused).
function Inv.SmallLine(tip)
	local n = tip and tip.NumLines and tip:NumLines()
	local name = tip and tip.GetName and tip:GetName()
	local fs = n and name and _G[name .. "TextLeft" .. n]
	if not (fs and fs.SetFontObject and _G.GameTooltipTextSmall) then return end
	fs:SetFontObject(_G.GameTooltipTextSmall)
	Inv.smallLines = Inv.smallLines or {}
	Inv.smallLines[fs] = true
	if not Inv.restoreHooked and tip.HookScript then
		Inv.restoreHooked = true
		local function restore() for line in pairs(Inv.smallLines) do if _G.GameTooltipText then line:SetFontObject(_G.GameTooltipText) end end; Inv.smallLines = {} end
		tip:HookScript("OnHide", restore)
		pcall(tip.HookScript, tip, "OnTooltipCleared", restore)
	end
end

------------------------------------------------------------------------
-- Keeping the counts current
------------------------------------------------------------------------
ns:OnSignal("ADDON_READY", function()
	Inv:InstallTooltipHook()
	ns:OnSignal("ITEMS_CHANGED", function() Inv:Invalidate() end)
	ns:OnSignal("BANK_OPENED", function() Inv:Invalidate() end)
	ns:On("PLAYER_EQUIPMENT_CHANGED", function() Inv:Invalidate() end)
	-- (1.9.5-beta1) the kept Global list: any setting (its sections come from the defaults, and a profile change
	-- reloads everything), a new zone or login (a character's data saved: SaveCache, Scanner.lua)
	ns:OnSignal("SETTINGS_CHANGED", function() Inv:Touch() end)
	ns:On("PLAYER_ENTERING_WORLD", function() Inv:Touch() end)
	-- the gold tooltip follows Shift while it's up
	ns:On("MODIFIER_STATE_CHANGED", function(key)
		local owner = Inv.goldOwner
		if owner and GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(owner) and owner.ShowGoldTip and tostring(key or ""):find("SHIFT") then
			owner:ShowGoldTip(true)
		end
	end)
end)
