--[[
	Core/GearSets.lua

	Gear sets are the game's own equipment sets (C_EquipmentSet, the Equipment
	Manager in the character window). BagSmith doesn't keep sets of its own; it
	reads them and adds:
	  - each set as a section in your bags, holding its items that are in your
	    bags (matched by exact location, so two identical rings land right);
	    an item in two sets shows under the first by name;
	  - Equip (Blizzard's own swap) with a one-line note about anything that
	    couldn't come along;
	  - protection: set items can't be marked as junk, are never sold by
	    BagSmith and are never offered by the Loot Helper;
	  - New, Update from What I'm Wearing, Rename, Delete and Put on Action Bar,
	    all through Blizzard's functions (sets are saved by the game).

	Section ids are "~gs:<name>" (Section Order holds one "~gs" entry for all
	of them). Each record in a set carries rec.gearSets, a list of set names in
	display order; it's saved with the character's bags, so an alt's bags and
	the saved bank group the same way.
--]]
local ADDON, ns = ...
local GS = {}
ns.GearSets = GS

GS.list = {}     -- sets, sorted by name: { id, name, icon, isEquipped, slots = { [invSlot] = where } }
GS.byLoc = {}    -- ["bag:slot"] = { set names, in display order }
GS.MAX_NAME = 16

local SLOT_NAME = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Shirt", [5] = "Chest", [6] = "Waist", [7] = "Legs",
	[8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Ring", [12] = "Ring", [13] = "Trinket", [14] = "Trinket", [15] = "Back",
	[16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged", [19] = "Tabard" }
GS.SLOT_NAME = SLOT_NAME

local function ES() return _G.C_EquipmentSet end
-- Everything BagSmith needs to read and use sets.
function GS:Available()
	local es = ES()
	return type(es) == "table" and type(es.GetEquipmentSetIDs) == "function" and type(es.GetEquipmentSetInfo) == "function"
		and type(es.GetItemLocations) == "function" and type(es.UseEquipmentSet) == "function" or false
end
local function call(name, ...)
	local es = ES()
	local fn = es and es[name]
	if type(fn) ~= "function" then return false end
	return pcall(fn, ...)
end

function GS.LaneId(name) return "~gs:" .. name end
function GS.IsLane(id) return type(id) == "string" and id:sub(1, 4) == "~gs:" end
function GS.NameOf(id) return GS.IsLane(id) and id:sub(5) or nil end
-- The place in Section Order a lane takes ("~gs" for every set).
function GS.OrderId(id) if GS.IsLane(id) then return "~gs" end return id end

------------------------------------------------------------------------
-- Reading the sets
------------------------------------------------------------------------
-- An item location from GetItemLocations, as { bag, slot, bank } for bags
-- and the bank, { equipped = invSlot } for what you're wearing, or nil for a
-- missing (-1), empty (0) or ignored (1) slot. Blizzard's own decoder when the
-- client has it (it knows this client's bank layout); otherwise the same
-- rule from the documented bit layout.
local function decode(loc)
	if type(loc) ~= "number" or loc <= 1 then return nil end
	local d
	if type(_G.EquipmentManager_GetLocationData) == "function" then
		local ok, data = pcall(_G.EquipmentManager_GetLocationData, loc)
		if ok and type(data) == "table" and next(data) then d = data end
	end
	if not d then
		local P = _G.ITEM_INVENTORY_LOCATION_PLAYER or 0x00100000
		local B = _G.ITEM_INVENTORY_LOCATION_BAGS or 0x00200000
		local K = _G.ITEM_INVENTORY_LOCATION_BANK or 0x00400000
		d = { isPlayer = math.floor(loc / P) % 2 == 1, isBags = math.floor(loc / B) % 2 == 1, isBank = math.floor(loc / K) % 2 == 1 }
		local low = loc % P
		if d.isBags then
			local shift = 2 ^ (_G.ITEM_INVENTORY_BAG_BIT_OFFSET or 8)
			d.bag = math.floor(low / shift)
			d.slot = low - d.bag * shift
			if d.isBank then d.bag = d.bag + (_G.ITEM_INVENTORY_BANK_BAG_OFFSET or _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5) end
		else
			d.slot = low
		end
	end
	if d.isBags and d.bag and d.slot then return { bag = d.bag, slot = d.slot, bank = d.isBank and true or false } end
	if d.isPlayer and d.slot then return { equipped = d.slot } end
	if d.isBank and d.slot then return { bag = ns.BANK or -1, slot = d.slot, bank = true } end
end
GS.Decode = decode

local function key(bag, slot) return bag .. ":" .. slot end
local function nameSort(a, b)
	local la, lb = a.name:lower(), b.name:lower()
	if la ~= lb then return la < lb end
	return a.id < b.id
end

function GS:Rebuild()
	local list, byLoc = {}, {}
	self.readFailed = false
	if self:Available() then
		local ok, ids = call("GetEquipmentSetIDs")
		if not ok or type(ids) ~= "table" then self.readFailed = true end
		for _, id in ipairs((ok and type(ids) == "table") and ids or {}) do
			local okI, name, icon, _, isEquipped = call("GetEquipmentSetInfo", id)
			if not okI or type(name) ~= "string" then self.readFailed = true end
			if okI and type(name) == "string" and name ~= "" then
				local set = { id = id, name = name, icon = icon, isEquipped = isEquipped and true or false, slots = {} }
				local okL, locs = call("GetItemLocations", id)
				if not okL or type(locs) ~= "table" then self.readFailed = true end
				for slot, loc in pairs((okL and type(locs) == "table") and locs or {}) do
					if type(slot) == "number" then set.slots[slot] = { loc = loc, where = decode(loc) } end
				end
				list[#list + 1] = set
			end
		end
	end
	table.sort(list, nameSort)
	for _, set in ipairs(list) do
		for _, s in pairs(set.slots) do
			local w = s.where
			if w and w.bag and w.slot then
				local k = key(w.bag, w.slot)
				local names = byLoc[k]
				if not names then names = {}; byLoc[k] = names end
				if names[#names] ~= set.name then names[#names + 1] = set.name end
			end
		end
	end
	self.list, self.byLoc = list, byLoc
	return list
end
function GS:Sets() return self.list end
function GS:Find(name)
	for _, set in ipairs(self.list) do if set.name == name then return set end end
end
-- Where a set's items are: { total, bags, worn, bank, missing } (slots the
-- set leaves out or keeps empty don't count).
function GS:Tally(set)
	local t = { total = 0, bags = 0, worn = 0, bank = 0, missing = 0 }
	for _, s in pairs(set and set.slots or {}) do
		local w = s.where
		if s.loc == -1 then t.total, t.missing = t.total + 1, t.missing + 1
		elseif w then
			t.total = t.total + 1
			if w.equipped then t.worn = t.worn + 1 elseif w.bank then t.bank = t.bank + 1 else t.bags = t.bags + 1 end
		end
	end
	return t
end
function GS:Count(set) return self:Tally(set).total end
local function placesOf(t)
	local parts = {}
	if t.bags > 0 then parts[#parts + 1] = ("%d in bags"):format(t.bags) end
	if t.worn > 0 then parts[#parts + 1] = ("%d worn"):format(t.worn) end
	if t.bank > 0 then parts[#parts + 1] = ("%d in the bank"):format(t.bank) end
	if t.missing > 0 then parts[#parts + 1] = ("%d not found"):format(t.missing) end
	return table.concat(parts, ", ")
end
-- "3 in bags, 6 worn, 1 in the bank" (the Gear Sets sheet's titles).
function GS:Places(set) return placesOf(self:Tally(set)) end
-- For Settings: "10 items, all worn" or "10 items: 3 in bags, 7 worn".
function GS:Summary(set)
	local t = self:Tally(set)
	if t.total == 0 then return "no items" end
	local items = ("%d %s"):format(t.total, t.total == 1 and "item" or "items")
	if t.worn == t.total then return items .. (t.total == 1 and ", worn" or ", all worn") end
	if t.bags == t.total then return items .. (t.total == 1 and ", in your bags" or ", all in your bags") end
	return items .. ": " .. placesOf(t)
end
-- For a set's title when none of its items are in your bags.
function GS:EmptyNote(set)
	local t = self:Tally(set)
	if t.total == 0 then return "No items saved in this set", false end
	if t.worn == t.total then return t.total == 1 and "Its item is worn" or ("All %d items worn"):format(t.total), true end
	return placesOf(t), false
end

-- Live records: their set names from where they are now.
function GS:Tag(rec)
	if not (rec and rec.bag and rec.slot) or rec.empty then return end
	rec.gearSets = self.byLoc[key(rec.bag, rec.slot)]
end
-- After the sets change: retag what's scanned without a rescan. Bank items
-- keep the tags from their bank scan while you're away from the bank.
function GS:Retag()
	for _, rec in ipairs(ns.items or {}) do self:Tag(rec) end
	if ns.atBank then for _, rec in ipairs(ns.bankItems or {}) do self:Tag(rec) end end
end
-- Set names for a record (live: where it is now; saved: as saved).
function GS:SetsOf(rec)
	if not rec or rec.empty then return nil end
	local sets = rec.gearSets
	if type(sets) == "table" and #sets > 0 then return sets end
end
function GS:InSet(rec) return self:SetsOf(rec) ~= nil end
-- By slot, from what the game says right now (for checks just before acting).
-- Re-read every set's locations from the game now (before selling or
-- destroying: never trust membership from before a bag move).
function GS:Refresh() self:Rebuild(); self.dirty = false end
-- The sets holding the item at a slot, or nil; the second value is true when the game's answer could not
-- be read (a destructive action must then treat membership as unknown, not as none).
function GS:SetsAt(bag, slot)
	if not (bag and slot) then return nil end
	if self.dirty then self:Rebuild(); self.dirty = false end
	return self.byLoc[key(bag, slot)], self.readFailed == true
end
-- Whether each set's section shows (the setting; on by default).
function GS:Showing() return ns.db and ns.db.gearSetSections ~= false or false end

------------------------------------------------------------------------
-- The Gear Sets sheet: every set with all its slots
------------------------------------------------------------------------
local SLOT_KEY = { [1] = "HeadSlot", [2] = "NeckSlot", [3] = "ShoulderSlot", [4] = "ShirtSlot", [5] = "ChestSlot", [6] = "WaistSlot",
	[7] = "LegsSlot", [8] = "FeetSlot", [9] = "WristSlot", [10] = "HandsSlot", [11] = "Finger0Slot", [12] = "Finger1Slot",
	[13] = "Trinket0Slot", [14] = "Trinket1Slot", [15] = "BackSlot", [16] = "MainHandSlot", [17] = "SecondaryHandSlot",
	[18] = "RangedSlot", [19] = "TabardSlot" }
-- The empty slot's picture from the character window, for a missing piece.
local function emptySlotArt(slot)
	if GetInventorySlotInfo and SLOT_KEY[slot] then
		local ok, _, tex = pcall(GetInventorySlotInfo, SLOT_KEY[slot])
		if ok and tex then return tex end
	end
	return "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
end
local function copy(r) local c = {}; for k, v in pairs(r) do c[k] = v end; return c end
-- Records for the sheet, in set order then slot order. Items in your bags
-- are the real items (a copy of the live record, so its button still works);
-- an item in a second set shows there as a display-only copy, and so do worn
-- and banked items; a missing piece is a display-only row. Each record says
-- its set (sheetSet) and slot (setSlot).
function GS:SheetRecords()
	if self.dirty then self:Rebuild(); self.dirty = false end
	local out, live, bank, placed = {}, {}, {}, {}
	for _, r in ipairs(ns.items or {}) do if r.bag and r.slot then live[key(r.bag, r.slot)] = r end end
	local bankList = ns.bankItems
	if not (ns.atBank or ns.bankScanned) then bankList = ns:CachedRecords(ns:CharKey(), true) end
	for _, r in ipairs(bankList or {}) do if r.bag and r.slot then bank[key(r.bag, r.slot)] = r end end
	local function display(rec, why)
		rec.display, rec.cached, rec.maxStack, rec.displayWhy = true, true, 1, why
		return rec
	end
	for _, set in ipairs(self.list) do
		for slot = 1, 19 do
			local s = set.slots[slot]
			local w = s and s.where
			local rec
			if s and s.loc == -1 then
				rec = display({ name = ("%s: not found"):format(SLOT_NAME[slot] or "Slot"), icon = emptySlotArt(slot), quality = 0, count = 1,
					missing = true, where = "", itemSubType = SLOT_NAME[slot], cat = "Gear", ownCat = "Gear" },
					"That piece wasn't found in your bags, your bank or on you.")
			elseif w and w.equipped then
				local inv = w.equipped
				local link = GetInventoryItemLink and GetInventoryItemLink("player", inv)
				local id = GetInventoryItemID and GetInventoryItemID("player", inv)
				rec = { itemID = id, link = link, icon = GetInventoryItemTexture and GetInventoryItemTexture("player", inv), count = 1,
					quality = (GetInventoryItemQuality and GetInventoryItemQuality("player", inv)) or 1,
					name = (link and link:match("%[(.-)%]")) or SLOT_NAME[slot] or "?", where = "Worn", cat = "Gear", ownCat = "Gear", isBound = true }
				if id and C_Item and C_Item.GetItemInfoInstant then
					local ok, _, iType, iSub, iEquip = pcall(C_Item.GetItemInfoInstant, id)
					if ok then rec.itemType, rec.itemSubType, rec.equipLoc = iType, iSub, iEquip end
				end
				display(rec, "You're wearing it.")
			elseif w and w.bank then
				local b = bank[key(w.bag, w.slot)]
				rec = b and copy(b) or { name = ("%s: in your bank"):format(SLOT_NAME[slot] or "Slot"), icon = emptySlotArt(slot), quality = 0, count = 1,
					itemSubType = SLOT_NAME[slot], cat = "Gear", ownCat = "Gear" }
				rec.where = "Bank"
				display(rec, "It's in your bank.")
			elseif w then
				local r = live[key(w.bag, w.slot)]
				if r then
					-- In several sets it shows in each: the first is its own
					-- button, the others copies that work the same.
					rec = copy(r)
					if placed[r] then rec.setCopy = true end
					placed[r] = true
				end
			end
			if rec then
				rec.sheetSet, rec.setSlot = set.name, slot
				if rec.display then rec.gearSets = { set.name } end
				out[#out + 1] = rec
			end
		end
	end
	return out
end

------------------------------------------------------------------------
-- Changes from the game
------------------------------------------------------------------------
function GS:Changed()
	self.dirty = true
	ns:NextFrame("gearSets", function()
		self:Rebuild(); self.dirty = false
		self:Retag()
		ns:RefreshViews(true)
		if ns.SettingsPanel and ns.SettingsPanel.frame and ns.SettingsPanel.frame:IsShown() and (ns.SettingsPanel.page == "dynamic" or ns.SettingsPanel.page == "sections") then ns.SettingsPanel:Refresh() end
	end)
end

------------------------------------------------------------------------
-- Equip
------------------------------------------------------------------------
local function joinNames(list)
	if #list <= 1 then return list[1] or "" end
	return table.concat(list, ", ", 1, #list - 1) .. " and " .. list[#list]
end
function GS:InCombat() return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) or false end
-- Why Equip can't run right now, or nil.
function GS:EquipBlocked()
	if self:InCombat() then return "Gear can't be changed in combat." end
end
-- What won't come along: slot names in your bank, and ones not found.
function GS:Leftovers(set)
	local bank, missing = {}, {}
	for slot = 1, 19 do
		local s = set.slots[slot]
		if s then
			if s.loc == -1 then missing[#missing + 1] = SLOT_NAME[slot] or ("Slot " .. slot)
			elseif s.where and s.where.bank then bank[#bank + 1] = SLOT_NAME[slot] or ("Slot " .. slot) end
		end
	end
	return bank, missing
end
function GS:Equip(name)
	if self.dirty then self:Rebuild(); self.dirty = false end
	local set = self:Find(name)
	if not set then ns:Print("No gear set named %s.", tostring(name)); return false end
	local why = self:EquipBlocked()
	if why then ns:Print(why); return false end
	local okL, locked = call("EquipmentSetContainsLockedItems", set.id)
	if okL and locked then ns:Print("Some of %s's items are busy right now. Try again in a moment.", set.name); return false end
	if UnitCastingInfo and UnitCastingInfo("player") then ns:Print("Finish casting first, then equip %s.", set.name); return false end
	local bank, missing = self:Leftovers(set)
	if ns.MarkAction then ns.MarkAction("gear set") end
	local ok, used = call("UseEquipmentSet", set.id)
	if not ok or used == false then ns:Print("Couldn't equip %s right now.", set.name); return false end
	-- One note once the swap is done, only if something didn't come along.
	local parts = {}
	if #bank > 0 then parts[#parts + 1] = joinNames(bank) .. " (in your bank)" end
	if #missing > 0 then parts[#parts + 1] = joinNames(missing) .. " (not found)" end
	local token = {}
	self.pending = { id = set.id, name = set.name, note = #parts > 0 and table.concat(parts, "; ") or nil, token = token }
	C_Timer.After(3, function() if self.pending and self.pending.token == token then self:SwapFinished(true, set.id) end end)
	return true
end
function GS:SwapFinished(result, setID)
	local p = self.pending
	if not p or (setID ~= nil and setID ~= p.id) then return end
	self.pending = nil
	if result == false then ns:Print("Couldn't finish equipping %s.", p.name)
	elseif p.note then ns:Print("Equipped %s, except %s.", p.name, p.note) end
end

-- The Equip buttons on section titles follow combat.
GS.buttons = setmetatable({}, { __mode = "k" })
function GS:PaintButton(b)
	local why = self:EquipBlocked()
	b:SetAlpha(why and 0.45 or 1)
	b.tip = why or "Put on this whole set"
end
function GS:UpdateButtons() for b in pairs(self.buttons) do if b:IsShown() then self:PaintButton(b) end end end

------------------------------------------------------------------------
-- Managing sets (all through Blizzard's functions)
------------------------------------------------------------------------
local function cleanName(name)
	name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then return nil, "Enter a name first." end
	if #name > GS.MAX_NAME then return nil, ("Use up to %d characters."):format(GS.MAX_NAME) end
	return name
end
local function taken(name, exceptID)
	local low = name:lower()
	for _, set in ipairs(GS:Rebuild()) do if set.id ~= exceptID and set.name:lower() == low then return true end end
	return false
end
function GS:MaxSets() return tonumber(_G.MAX_EQUIPMENT_SETS_PER_PLAYER) or 10 end
-- The ignore-slot list is the game's, shared with its Equipment Manager: set
-- it up for this save only, then clear it again.
local function withIgnored(slots, fn)
	call("ClearIgnoredSlotsForSave")
	for slot, ignored in pairs(slots or {}) do
		if ignored then call("IgnoreSlotForSave", slot) else call("UnignoreSlotForSave", slot) end
	end
	local ok, result = fn()
	call("ClearIgnoredSlotsForSave")
	return ok, result
end
local function wornIcon()
	for _, slot in ipairs({ 5, 16, 1 }) do
		local tex = GetInventoryItemTexture and GetInventoryItemTexture("player", slot)
		if tex then return tex end
	end
	return 134400   -- the question mark
end
-- Saves what you're wearing as a new set (shirt and tabard left out, as the
-- game's own New Set does). Returns true, or nil and why not.
function GS:Create(name)
	if not self:Available() then return nil, "This game client doesn't have equipment sets." end
	local why
	name, why = cleanName(name)
	if not name then return nil, why end
	if taken(name) then return nil, "You already have a set with that name." end
	if #self.list >= self:MaxSets() then return nil, ("You have the most sets the game allows (%d)."):format(self:MaxSets()) end
	local ok = withIgnored({ [4] = true, [19] = true }, function() return call("CreateEquipmentSet", name, wornIcon()) end)
	if not ok then return nil, "The game didn't save the set." end
	self:Changed()
	return true
end
function GS:Rename(oldName, newName)
	local set = self:Find(oldName)
	if not set then return nil, "That set is gone." end
	local why
	newName, why = cleanName(newName)
	if not newName then return nil, why end
	if newName == set.name then return true end
	if taken(newName, set.id) then return nil, "You already have a set with that name." end
	local ok = call("ModifyEquipmentSet", set.id, newName, set.icon)
	if not ok then return nil, "The game didn't rename the set." end
	-- This profile's choices for it follow the new name.
	self:MoveState(self.LaneId(oldName), self.LaneId(newName))
	self:Changed()
	return true
end
function GS:Delete(name)
	local set = self:Find(name)
	if not set then return false end
	if not call("DeleteEquipmentSet", set.id) then return false end
	self:MoveState(self.LaneId(name), nil)
	self:Changed()
	return true
end
-- Saves what you're wearing into the set, keeping the slots it leaves out.
function GS:Update(name)
	local set = self:Find(name)
	if not set then return false end
	local _, ignored = call("GetIgnoredSlots", set.id)
	local ok = withIgnored(type(ignored) == "table" and ignored or {}, function() return call("SaveEquipmentSet", set.id) end)
	if ok then self:Changed() end
	return ok and true or false
end
-- Puts the set on the cursor: the next click on an action bar slot places it.
function GS:PickUp(name)
	local set = self:Find(name)
	if not set then return false end
	if self:InCombat() then ns:Print("Gear sets can't go on your action bars during combat."); return false end
	if ClearCursor then ClearCursor() end
	return call("PickupEquipmentSet", set.id) and true or false
end
-- Renames or forgets this profile's collapsed state for a set's section, in
-- any window or sheet (Show at Vendor / AH is one choice for all sets).
function GS:MoveState(from, to)
	local db = ns.db
	if not db then return end
	local lists = { db.collapsed or {}, db.bankCollapsed or {}, (ns.ui and ns.ui.collapsed) or {}, (ns.uiBank and ns.uiBank.collapsed) or {} }
	for _, win in ipairs({ "bags", "bank" }) do
		for _, p in pairs((db.sheetPrefs or {})[win] or {}) do
			if type(p) == "table" and type(p.collapsed) == "table" then lists[#lists + 1] = p.collapsed end
		end
	end
	for _, list in ipairs(lists) do
		for i = #list, 1, -1 do
			if list[i] == from then if to then list[i] = to else table.remove(list, i) end end
		end
	end
end

------------------------------------------------------------------------
-- Prompts and confirmations
------------------------------------------------------------------------
function GS:PromptNew()
	return ns.Prompt("New Gear Set", "", function(text)
		local ok, why = GS:Create(text)
		if not ok then return false, why end
		return true
	end, GS.MAX_NAME, "Saves what you're wearing now.")
end
function GS:PromptRename(name)
	return ns.Prompt("Rename Gear Set", name, function(text) return GS:Rename(name, text) end, GS.MAX_NAME)
end
function GS:ConfirmDelete(name, anchor)
	ns.Confirm(anchor or UIParent, ("Delete the gear set \"%s\"? This also removes it from the game's Equipment Manager. Your items aren't affected."):format(name),
		function() GS:Delete(name) end)
end
function GS:ConfirmUpdate(name, anchor)
	ns.Confirm(anchor or UIParent, ("Save what you're wearing as \"%s\"? This replaces the items saved in it."):format(name), function() GS:Update(name) end)
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
ns:OnSignal("ADDON_READY", function()
	if not GS:Available() then return end
	GS:Rebuild()
	local function changed() GS:Changed() end
	ns:On("EQUIPMENT_SETS_CHANGED", changed)
	-- Any bag or bank change may move a set's item: the next slot check
	-- re-reads the game's set locations (a scan may still be queued).
	local stale = function() GS.dirty = true end
	for _, e in ipairs({ "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "ITEM_LOCK_CHANGED", "BAG_CONTAINER_UPDATE" }) do ns:On(e, stale) end
	ns:On("PLAYER_EQUIPMENT_CHANGED", changed)
	ns:On("EQUIPMENT_SWAP_FINISHED", function(result, setID) GS:SwapFinished(result, setID); GS:Changed() end)
	ns:OnSignal("COMBAT_STARTED", function() GS:UpdateButtons() end)
	ns:OnSignal("COMBAT_ENDED", function() GS:UpdateButtons() end)
end)
