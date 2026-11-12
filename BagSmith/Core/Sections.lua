--[[
	Core/Sections.lua

	Custom sections, and moving items between sections (per profile).

	An item's section, first match wins:
	  1. marked as junk: Junk (so junk always sells);
	  2. a favorite, while the Favorites section is on: Favorites;
	  3. the section you moved it to;
	  4. its usual section by type (Core/Classify.lua).

	Moves are by item ID (every copy). Custom sections have ids "c1", "c2"...
	and sit in Section Order with the built-in ones. Each section can be
	hidden at vendors and/or the auction house; hidden items drop out of every
	view only while one is open, and the footer offers to show them.
--]]
local ADDON, ns = ...
local S = {}
ns.Sections = S

-- Built-in sections an item can be moved into (Junk is by marking; Keys has its own setting).
S.BUILTIN = { "Gear", "Consumables", "Reagents", "TradeGoods", "Recipes", "Quest", "Tokens", "Other" }
-- (1.5.0-beta9) Split Consumables' sections are built-in sections too (listed in Section Order only while split)
for _, k in ipairs(ns.CONS_KINDS) do S.BUILTIN[#S.BUILTIN + 1] = ns.CONS_ID[k] end
-- (1.7.0-beta6) and Split Gear by Binding's
for _, k in ipairs(ns.GEAR_KINDS) do S.BUILTIN[#S.BUILTIN + 1] = ns.GEAR_ID[k] end
local BUILTIN_SET = {}
for _, id in ipairs(S.BUILTIN) do BUILTIN_SET[id] = true end
S.BUILTIN_SET = BUILTIN_SET
local SPECIAL_LABEL = { ["~recent"] = "Recent Items", ["~fav"] = "Favorites", ["~gs"] = "Gear Sets", ["~ky"] = "Keys", ["~rb"] = "Reagent Bag", Junk = "Junk" }

function S:Customs() return (ns.db and ns.db.customSections) or {} end
-- Pinned sections (1.4.0): item sections (built-in or custom) shown at the top, after Recent; in All view their
-- items leave the main list for their own section. By Bag ignores pins.
function S:Pinnable(id) return type(id) == "string" and id ~= "" and id:sub(1, 1) ~= "~" and not id:match("^gs:") end
function S:PinnedSet() return (ns.db and type(ns.db.pinnedSections) == "table") and ns.db.pinnedSections or {} end
function S:Pinned(id) return self:PinnedSet()[id] == true end
function S:SetPinned(id, on)
	if not (ns.db and self:Pinnable(id)) then return end
	if type(ns.db.pinnedSections) ~= "table" then ns.db.pinnedSections = {} end
	ns.db.pinnedSections[id] = on and true or nil
	ns:Fire("SETTINGS_CHANGED", "pinnedSections")
	ns:RefreshViews(true)
end
function S:Custom(id)
	for _, c in ipairs(self:Customs()) do if c.id == id then return c end end
end
function S:IsCustom(id) return type(id) == "string" and id:match("^c%d+$") ~= nil and self:Custom(id) ~= nil end
-- Somewhere an item can be moved to.
-- (1.5.0-beta9) Is this split consumable section in use (Split Consumables on, and its type split out)?
-- (1.7.0-beta6) Split Gear by Binding's sections likewise (one question for both splits; the name is from 1.5.0).
function S:ConsSplitActive(id)
	local db = ns.db
	if not (db and ns.PARENT_CAT[id]) then return false end
	for k, cid in pairs(ns.CONS_ID) do if cid == id then return (db.splitCons and (db.splitConsTypes or {})[k] ~= false) and true or false end end
	for k, gid in pairs(ns.GEAR_ID) do if gid == id then return (db.splitGear and (db.splitGearTypes or {})[k] ~= false) and true or false end end
	return false
end
S.SplitActive = S.ConsSplitActive
-- The split sections join Section Order right after Consumables (once; you can move them from there).
-- (1.7.0-beta7) True when it added any (so Settings can draw them).
function S:EnsureConsOrder()
	local order = ns.db and ns.db.laneOrder
	if type(order) ~= "table" then return false end
	local have, added = {}, false
	for _, id in ipairs(order) do have[id] = true end
	local at = (ns.IndexOf(order, "Consumables") or #order) + 1
	for _, k in ipairs(ns.CONS_KINDS) do
		local id = ns.CONS_ID[k]
		if not have[id] then table.insert(order, at, id); at = at + 1; added = true end
	end
	return added
end
-- (1.7.0-beta6) Split Gear by Binding's sections join Section Order right after Gear, the same way
function S:EnsureGearOrder()
	local order = ns.db and ns.db.laneOrder
	if type(order) ~= "table" then return false end
	local have, added = {}, false
	for _, id in ipairs(order) do have[id] = true end
	local at = (ns.IndexOf(order, "Gear") or #order) + 1
	for _, k in ipairs(ns.GEAR_KINDS) do
		local id = ns.GEAR_ID[k]
		if not have[id] then table.insert(order, at, id); at = at + 1; added = true end
	end
	return added
end
function S:CanTake(id) return BUILTIN_SET[id] or self:IsCustom(id) or false end
-- (1.7.0-beta10, Shweep) While Split Gear by Binding splits anything out, Gear holds what's left and reads "Gear: Other",
-- beside Gear: Soulbound and Gear: BoE. (The Gear tab and the category filter keep "Gear": they cover all of it.)
S.GEAR_OTHER = "Gear: Other"
function S:GearSplitOn()
	for _, id in pairs(ns.GEAR_ID) do if self:ConsSplitActive(id) then return true end end
	return false
end
function S:Label(id)
	local c = self:Custom(id)
	if c then return c.name end
	if ns.GearSets and ns.GearSets.IsLane(id) then return ns.GearSets.NameOf(id) end
	if id == "Gear" and self:GearSplitOn() then return S.GEAR_OTHER end
	return SPECIAL_LABEL[id] or ns.CAT_LABEL[id] or id
end
-- Every section you can move items to, in Section Order.
-- (1.5.0-beta9) Split Consumables' sections are targets only while in use.
function S:Targets()
	local out, seen = {}, {}
	local function usable(id) return not ns.PARENT_CAT[id] or self:ConsSplitActive(id) end
	for _, id in ipairs(ns.db.laneOrder or {}) do if self:CanTake(id) and usable(id) and not seen[id] then seen[id] = true; out[#out + 1] = id end end
	for _, id in ipairs(S.BUILTIN) do if usable(id) and not seen[id] then seen[id] = true; out[#out + 1] = id end end
	for _, c in ipairs(self:Customs()) do if not seen[c.id] then seen[c.id] = true; out[#out + 1] = c.id end end
	return out
end

------------------------------------------------------------------------
-- Moves
------------------------------------------------------------------------
function S:Moves() return (ns.db and ns.db.sectionMoves) or {} end
function S:MovedTo(itemID)
	local to = itemID and self:Moves()[itemID]
	if not (to and self:CanTake(to)) then return nil end
	-- (1.6.3-beta1, Shweep's choice) an item moved to a Split Consumables section that isn't in use (the split off, or
	-- that type unticked) shows in Consumables meanwhile, and goes back to its section when it's in use again: the
	-- move is kept. (Before, a lone section appeared for it.)
	if ns.PARENT_CAT[to] and not self:ConsSplitActive(to) then return ns.PARENT_CAT[to] end
	return to
end
-- An item's own category. Live records carry it. Older saved records (from
-- 0.14.0-beta1 and before) don't, and their saved category may have come from
-- a move, so they're classified from the item itself (ID, class, binding),
-- never from any profile's moves. The one exception: two categories depend on
-- flags those saves didn't keep (quest item, crafting reagent), so when the
-- item alone only says Other and the save said Quest or Trade Goods, the
-- saved one is kept.
local FLAG_ONLY = { Quest = true, TradeGoods = true }
function S:OwnCategory(rec)
	-- (1.5.0-beta9) a consumable's own section follows this profile's Split Consumables (other characters' saved bags too)
	-- (1.7.0-beta6) and a piece of gear's follows its Split Gear by Binding
	if rec.ownCat and (rec.ownCat == "Consumables" or rec.ownCat == "Gear" or ns.PARENT_CAT[rec.ownCat]) and rec.classID ~= nil then return ns:Categorize(rec) end
	if rec.ownCat then return rec.ownCat end
	local own = ns:Categorize(rec)
	if own == "Other" and FLAG_ONLY[rec.cat] and rec.isQuest == nil and rec.isCraftingReagent == nil then return rec.cat end
	return own
end

-- The section a record goes to, before junk marks (the scanner applies those).
function S:Apply(rec, own)
	own = own or rec.ownCat or ns:Categorize(rec)
	return self:MovedTo(rec.itemID) or own
end
-- Re-sort what's already scanned after a move, without a rescan.
-- (1.5.0-beta9) Split Consumables changed: every consumable works out its own section again.
-- (1.7.0-beta6) Split Gear by Binding changed: every piece of gear too.
-- (1.7.0-beta7, Shweep) Settings redraws on the same change before this runs, so a split's sections, added to Section
-- Order here the first time it's turned on, weren't in its table until the next redraw: draw it again when they're new.
function S:ReclassifyConsumables()
	ns:ConsSplitChanged()
	local added = false
	if ns.db and ns.db.splitCons and self:EnsureConsOrder() then added = true end
	if ns.db and ns.db.splitGear and self:EnsureGearOrder() then added = true end
	for _, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
		for _, rec in ipairs(list) do
			if rec.itemID and (rec.ownCat == "Consumables" or rec.ownCat == "Gear" or ns.PARENT_CAT[rec.ownCat]) then rec.ownCat = ns:Categorize(rec) end
		end
	end
	self:Reapply()
	local P = ns.SettingsPanel
	if added and P and P.frame and P.frame:IsShown() then P:Refresh() end
end
function S:Reapply()
	for _, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
		for _, rec in ipairs(list) do
			if rec.itemID then
				rec.ownCat = rec.ownCat or ns:Categorize(rec)
				rec.cat = self:Apply(rec)
				if ns.Junk and ns.Junk:Marked(rec.itemID) then rec.cat = "Junk" end
			end
		end
	end
	ns:RefreshViews(true)
end
function S:Move(itemID, to)
	if not (itemID and self:CanTake(to)) then return false end
	local moves = ns.db.sectionMoves
	-- Moving an item to its own section just undoes the move.
	local own
	for _, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
		for _, rec in ipairs(list) do if rec.itemID == itemID then own = rec.ownCat or ns:Categorize(rec); break end end
		if own then break end
	end
	if own and own == to then moves[itemID] = nil else moves[itemID] = to end
	self:Reapply()
	self:RefreshManager()
	return true
end
function S:Clear(itemID)
	if itemID and ns.db.sectionMoves[itemID] then ns.db.sectionMoves[itemID] = nil; self:Reapply(); self:RefreshManager() end
end
function S:ClearAll()
	local moves = ns.db.sectionMoves
	for id in pairs(moves) do moves[id] = nil end
	self:Reapply(); self:RefreshManager()
end
function S:MoveCount() local n = 0; for id, to in pairs(self:Moves()) do if self:CanTake(to) then n = n + 1 end end; return n end

------------------------------------------------------------------------
-- Custom sections
------------------------------------------------------------------------
local function cleanName(name)
	name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then return nil end
	return name:sub(1, 40)
end
function S:NameTaken(name, except)
	local low = name:lower()
	-- (1.5.0-beta9: Split Consumables' names count only while in use, so a section of your own can be called "Potions")
	for _, id in ipairs(S.BUILTIN) do if (not ns.PARENT_CAT[id] or self:ConsSplitActive(id)) and (ns.CAT_LABEL[id] or id):lower() == low then return true end end
	for _, l in pairs(SPECIAL_LABEL) do if l:lower() == low then return true end end
	if self:GearSplitOn() and S.GEAR_OTHER:lower() == low then return true end   -- (1.7.0-beta10)
	for _, c in ipairs(self:Customs()) do if c.id ~= except and c.name:lower() == low then return true end end
	return false
end
-- Returns the new section's id, or nil and why not.
function S:Create(name)
	name = cleanName(name)
	if not name then return nil, "Enter a name first." end
	if self:NameTaken(name) then return nil, "There's already a section with that name." end
	-- Never reuse an id: old sheets, filters and collapse state may still name it.
	local n = (ns.db.sectionNextId or 1) - 1
	for _, c in ipairs(self:Customs()) do local k = tonumber(c.id:match("^c(%d+)$")); if k and k > n then n = k end end
	n = math.floor(n)
	if n < 0 or n >= (ns.MAX_SECTION_ID or 999999) then return nil, "No more sections can be made in this profile." end
	local id = ("c%d"):format(n + 1)
	ns.db.sectionNextId = n + 2
	table.insert(ns.db.customSections, { id = id, name = name })
	-- Into Section Order just before Other (or at the end).
	local order, at = ns.db.laneOrder, nil
	for i, x in ipairs(order) do if x == "Other" then at = i; break end end
	table.insert(order, at or (#order + 1), id)
	ns:Fire("SETTINGS_CHANGED", "customSections")
	return id
end
function S:Rename(id, name)
	local c = self:Custom(id)
	name = cleanName(name)
	if not c then return nil, "That section is gone." end
	if not name then return nil, "Enter a name first." end
	if self:NameTaken(name, id) then return nil, "There's already a section with that name." end
	c.name = name
	ns:Fire("SETTINGS_CHANGED", "customSections")
	return true
end
-- Deleting sends its items back to their own sections.
function S:Delete(id)
	local deleted = self:Custom(id)
	local list = ns.db.customSections
	for i, c in ipairs(list) do if c.id == id then table.remove(list, i); break end end
	for item, to in pairs(ns.db.sectionMoves) do if to == id then ns.db.sectionMoves[item] = nil end end
	for i = #ns.db.laneOrder, 1, -1 do if ns.db.laneOrder[i] == id then table.remove(ns.db.laneOrder, i) end end
	ns.db.sectionHide[id] = nil
	-- Its collapse state and the windows' current category filters go too.
	-- Saved and session collapse lists (Remember Which Sections Are Collapsed off uses the session ones).
	local lists = { ns.db.collapsed or {}, ns.db.bankCollapsed or {}, (ns.ui and ns.ui.collapsed) or {}, (ns.uiBank and ns.uiBank.collapsed) or {} }
	-- Each sheet's own collapse list too (Sheet-Specific Views).
	for _, win in ipairs({ "bags", "bank" }) do
		for _, p in pairs((ns.db.sheetPrefs or {})[win] or {}) do
			if type(p) == "table" and type(p.collapsed) == "table" then lists[#lists + 1] = p.collapsed end
		end
	end
	for _, list in ipairs(lists) do
		for i = #list, 1, -1 do if list[i] == id then table.remove(list, i) end end
	end
	for _, v in pairs(ns.views or {}) do
		local f = v.st and v.st.filters
		if f and f.cat then f.cat[id] = nil end
	end
	-- Saved sheets filtered on it lose it too; one filtered only by it now
	-- shows every category, and chat says so.
	local label = (deleted and deleted.name) or id
	for _, key in ipairs({ "sheets", "bankSheets" }) do
		for _, sh in ipairs(ns.db[key] or {}) do
			local cat = sh.f and sh.f.cat
			if type(cat) == "table" and cat[id] then
				cat[id] = nil
				if not next(cat) then
					ns:Print("Sheet \"%s\" was filtered by the section %s; it now shows every category.", sh.n or "?", label)
				end
			end
		end
	end
	ns:Fire("SETTINGS_CHANGED", "customSections")
	self:Reapply(); self:RefreshManager()
end
-- Show When Empty: the overall setting is the master switch; while it's on,
-- each custom section follows its own choice (on unless turned off).
function S:ShowsEmpty(id)
	local c = self:Custom(id)
	return (ns.db.showEmptySections and c and c.showEmpty ~= false) and true or false
end
function S:SetShowEmpty(id, on)
	local c = self:Custom(id)
	if not c then return end
	-- (only "false" is stored; on means the key is absent)
	if on then c.showEmpty = nil else c.showEmpty = false end
	ns:Fire("SETTINGS_CHANGED", "customSections")
	ns:RefreshViews(true)
end
function S:ItemCount(id)
	local n = 0
	for _, to in pairs(self:Moves()) do if to == id then n = n + 1 end end
	return n
end

------------------------------------------------------------------------
-- Show at Vendor / Show at AH
------------------------------------------------------------------------
function S:Shown(id, where)
	local h = ns.db.sectionHide and ns.db.sectionHide[id]
	return not (h and h[where])
end
function S:SetShown(id, where, show)
	local all = ns.db.sectionHide
	local h = all[id] or {}
	h[where] = (not show) or nil
	all[id] = next(h) and h or nil
	ns:RefreshViews(true)
end
-- "vendor", "ah" or nil: where you are right now.
function S:Where()
	if ns.ui.atVendor then return "vendor" elseif ns.ui.atAH then return "ah" end
end
-- The section a record shows under for hiding (gear sets, all together as
-- "~gs", then Favorites, count as their own).
function S:EffectiveSection(rec)
	local GS = ns.GearSets
	if GS and GS:Showing() and GS:SetsOf(rec) then return "~gs" end
	if rec.cat ~= "Junk" and ns.db.favSection and ns.Marks and rec.itemID and ns.Marks:IsFavorite(rec.itemID) then return "~fav" end
	return rec.cat
end
-- In a section hidden where you are (whether or not Show Them is on).
function S:WouldHide(rec)
	local where = self:Where()
	if not where or not rec or rec.empty then return false end
	return not self:Shown(self:EffectiveSection(rec), where)
end
function S:HiddenNow(rec)
	if ns.ui.showHidden then return false end
	return self:WouldHide(rec)
end
function S:HidingAny()
	local where = self:Where()
	if not where then return false end
	for _, h in pairs(ns.db.sectionHide or {}) do if h[where] then return true end end
	return false
end

-- The moved-items window refreshes itself if it's open (Frames/SectionsUI.lua).
function S:RefreshManager() if self.RefreshMovedWindow then self:RefreshMovedWindow() end end

ns:OnSignal("ADDON_READY", function()
	local function at(flag, on) return function()
		ns.ui[flag] = on
		ns.ui.showHidden = false   -- each visit starts with your hidden sections hidden
		ns:RefreshViews(true)
	end end
	ns:On("MERCHANT_SHOW", at("atVendor", true)); ns:On("MERCHANT_CLOSED", at("atVendor", false))
	ns:On("AUCTION_HOUSE_SHOW", at("atAH", true)); ns:On("AUCTION_HOUSE_CLOSED", at("atAH", false))
	-- A profile switch brings its own moves and sections, and closes anything
	-- open that was acting on the old profile's sections.
	-- (1.5.0-beta9) Split Consumables: on, off, a type ticked or unticked, or another profile
	ns:OnSignal("SETTINGS_CHANGED", function(key)
		if key == "splitCons" or key == "splitConsTypes" or key == "splitGear" or key == "splitGearTypes" or key == nil then S:ReclassifyConsumables() end
	end)
	if ns.db and ns.db.splitCons then S:EnsureConsOrder(); ns:ConsSplitChanged() end
	if ns.db and ns.db.splitGear then S:EnsureGearOrder(); ns:ConsSplitChanged() end
	ns:OnSignal("SETTINGS_CHANGED", function(key)
		if key ~= nil then return end
		-- (each one on its own: any of them may never have been opened)
		-- Session collapse state belongs to the old profile's sections: reset
		-- only when the active profile was really switched, reset or replaced
		-- (deleting another profile re-activates this one and keeps it).
		if ns.ui and ns.ui.collapseReset then
			ns.ui.collapseReset = nil
			if ns.ui.collapsed then wipe(ns.ui.collapsed) end
			if ns.uiBank and ns.uiBank.collapsed then wipe(ns.uiBank.collapsed) end
		end
		-- A window's live filters may name a section this profile doesn't have
		-- (a choice made on All or a built-in tab): it would hide every row.
		for _, v in pairs(ns.views or {}) do
			if v.st and v.st.filters and ns.PruneFilterCategories then ns.PruneFilterCategories(v.st.filters, S:Customs()) end
		end
		if ns.promptFrame and ns.promptFrame:IsShown() then ns.promptFrame:Hide() end
		if ns.menuFrame and ns.menuFrame:IsShown() then ns.menuFrame:Hide() end
		if S.movedFrame and S.movedFrame:IsShown() then S.movedFrame:Hide() end
		local c = ns.Popups and ns.Popups.confirm
		if c and c:IsShown() and c.sections then c:Hide() end
		S:Reapply()
	end)
end)
