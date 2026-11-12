--[[
	Core/MakeRoom.lua

	The Loot Helper. When a loot window opens with items that won't fit (free slots
	counted per bag type, including room in existing stacks), a panel appears
	beside the loot window: the loot waiting (Skip, Exclude),
	and ways to make room, free ones first:
	  - combine two partial stacks of the same item,
	  - Blizzard's Clean Up Bags (merges stacks),
	  - warlocks: destroy Soul Shards kept in ordinary bags (one click each,
	    after one confirmation for the number chosen),
	  - destroy a low-value item: junk first, then the cheapest; only items
	    worth less than the loot. Grey and junk-marked items go in one click;
	    anything else asks first.
	When there's room, BagSmith loots the waiting items itself.

	The game only lets an addon delete an item from a click or key press, so
	every destroy happens from a click on this panel. Nothing is ever deleted
	on its own. Settings live under Automations & Actions.
--]]
local ADDON, ns = ...
local MR = { skipped = {}, pending = {} }
ns.MakeRoom = MR

local SHARD = 6265
local VISIBLE_ROWS = 6  -- (1.7.0-beta3) "let go" rows shown at once; the rest scroll (every candidate is listed)
local SCROLLBAR_W = 26  -- the room the list's scrollbar takes on the right while it scrolls
local MAT_WEIGHT, SPARE_WEIGHT = 3, 0.5   -- (1.7.0-beta3) the ranking's two weights (MR:Suggestions)
local MAX_COMBINE = 3   -- combine suggestions shown at once
local SETTLE = 0.6      -- s to wait after a loot slot clears if the bags don't update first (an item BagSmith can't name)
local ARRIVE = 3.0      -- (1.5.1) s to wait for a looted item to reach the bags before judging again anyway
local QUEST_GRACE = 5   -- s after a quest window closes that "Inventory is full" still counts as the quest's
local W = 360

local function band(a, b)
	local r, bit = 0, 1
	while a > 0 and b > 0 do
		if a % 2 == 1 and b % 2 == 1 then r = r + bit end
		a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
	end
	return r
end
local function itemInfo(id) if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(id) end end
local function itemFamily(id) return (C_Item and C_Item.GetItemFamily and C_Item.GetItemFamily(id)) or (GetItemFamily and GetItemFamily(id)) or 0 end
local function maxStack(id) local stack = select(8, itemInfo(id)); return stack or 1 end
local function sellPrice(id) return select(11, itemInfo(id)) or 0 end
local function money(v) return (GetCoinTextureString and GetCoinTextureString(v)) or ns.Money(v) end
-- (1.5.1) how many of an item your bags hold, by BagSmith's scan
local function bagCount(id)
	local c = 0
	for _, r in ipairs(ns.items or {}) do if r.itemID == id then c = c + (r.count or 1) end end
	return c
end
function MR:IsWarlock() local _, c = UnitClass("player"); return c == "WARLOCK" end

------------------------------------------------------------------------
-- The Loot Exclusion List (per character): loot the Loot Helper never asks you to make room for
------------------------------------------------------------------------
function MR:Never()
	if not ns.cdb then return {} end
	if type(ns.cdb.makeRoomNever) ~= "table" then ns.cdb.makeRoomNever = {} end
	return ns.cdb.makeRoomNever
end
local function sortedList(t)
	local out = {}
	for id in pairs(t) do out[#out + 1] = { id = id, name = (itemInfo(id)) or ("Item " .. id) } end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end
local function settingsRefresh()
	if ns.SettingsPanel and ns.SettingsPanel.frame and ns.SettingsPanel.frame:IsShown() then ns.SettingsPanel:Refresh() end
end
function MR:NeverList() return sortedList(self:Never()) end
function MR:Unnever(id)
	self:Never()[id] = nil
	self:RefreshNeverWindow()
	settingsRefresh()
end
function MR:ClearNever()
	local t = self:Never()
	for id in pairs(t) do t[id] = nil end
	self:RefreshNeverWindow()
end

------------------------------------------------------------------------
-- (1.7.0-beta1, Shweep) Protected Items (per character): items in your bags the Loot Helper never suggests destroying,
-- without making them favorites or putting them in a gear set. The Protect button (beside Destroy since 1.7.0-beta10) adds one ("Don't
-- suggest again"); it then counts with the other protected items. Not the Loot Exclusion List, which is about loot.
------------------------------------------------------------------------
function MR:Protected()
	if not ns.cdb then return {} end
	if type(ns.cdb.makeRoomProtect) ~= "table" then ns.cdb.makeRoomProtect = {} end
	return ns.cdb.makeRoomProtect
end
function MR:IsProtected(id) return id ~= nil and self:Protected()[id] == true end
function MR:ProtectedList() return sortedList(self:Protected()) end
function MR:Protect(id)
	if type(id) ~= "number" then return end
	self:Protected()[id] = true
	self:RefreshProtectedWindow()
	settingsRefresh()
	self:Refresh()
end
function MR:Unprotect(id)
	self:Protected()[id] = nil
	self:RefreshProtectedWindow()
	settingsRefresh()
	self:Refresh()
end
function MR:ClearProtected()
	local t = self:Protected()
	for id in pairs(t) do t[id] = nil end
	self:RefreshProtectedWindow()
	self:Refresh()
end

-- The two list windows (the Loot Exclusion List, Protected Items): the list, A to Z, with a search box; each row's
-- button takes that item off. Each is made once; rows are reused.
local NW, NROW = 300, 24
local LISTS = {
	never = { frameKey = "neverFrame", global = "BagSmithNeverAsk", title = "Loot Exclusion List",
		list = function() return MR:NeverList() end, remove = function(id) MR:Unnever(id) end,
		removeTip = "Remove from your Loot Exclusion List",
		count = function(n) return n == 1 and "1 item on your Loot Exclusion List." or ("%d items on your Loot Exclusion List."):format(n) end,
		empty = "Your Loot Exclusion List is empty. Use Exclude in the Loot Helper to add items." },
	protect = { frameKey = "protectFrame", global = "BagSmithProtected", title = "Protected Items",
		list = function() return MR:ProtectedList() end, remove = function(id) MR:Unprotect(id) end,
		removeTip = "Stop protecting it: the Loot Helper can suggest it again",
		count = function(n) return n == 1 and "1 item the Loot Helper won't suggest destroying." or ("%d items the Loot Helper won't suggest destroying."):format(n) end,
		empty = "Nothing is protected yet. Use Protect in the Loot Helper to add items." },
}
MR.LISTS = LISTS
local function listWindow(kind)
	local spec = LISTS[kind]
	local f = MR[spec.frameKey]
	if f then return f end
	f = CreateFrame("Frame", spec.global, UIParent, "BackdropTemplate")
	f.kind = kind
	f:SetSize(NW, 360); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	f:SetMovable(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", 12, -12); f.title:SetText(spec.title)
	f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
	f.sub:SetWidth(NW - 24); f.sub:SetJustifyH("LEFT")
	f.search = CreateFrame("EditBox", spec.global .. "Search", f, "SearchBoxTemplate")
	f.search:SetSize(NW - 32, 22); f.search:SetAutoFocus(false); f.search:SetPoint("TOPLEFT", 18, -58)
	f.search:SetScript("OnTextChanged", function(box) if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(box) end; MR:RefreshListWindow(kind) end)
	f.search:SetScript("OnEscapePressed", function(box) box:SetText(""); box:ClearFocus() end)
	f.scroll = CreateFrame("ScrollFrame", spec.global .. "Scroll", f, "UIPanelScrollFrameTemplate")
	f.scroll:SetPoint("TOPLEFT", 10, -88); f.scroll:SetPoint("BOTTOMRIGHT", -30, 44)
	f.child = CreateFrame("Frame", nil, f.scroll); f.child:SetSize(NW - 44, 1); f.scroll:SetScrollChild(f.child)
	f.rows = {}
	f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.empty:SetPoint("TOPLEFT", 16, -96)
	f.empty:SetWidth(NW - 32); f.empty:SetJustifyH("LEFT")
	f.close = ns.TextButton(f, "Close", 70, function() f:Hide() end); f.close:SetHeight(22); f.close:SetPoint("BOTTOMRIGHT", -12, 12)
	f.classicSpec = ns.Classic.DialogSpec(f, { restore = function() ns.Skins:ApplyBackdrop(f); local s = ns.Skins:Current(); f:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1) end })
	ns.Skins:Register(f, function(fr)
		ns.Skins:ApplyBackdrop(fr); local s = ns.Skins:Current(); fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)
		fr.title:SetTextColor(unpack(s.heading)); fr.sub:SetTextColor(unpack(s.muted)); fr.empty:SetTextColor(unpack(s.muted))
		ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
	end)
	f:Hide()
	ns:CloseOnEscape(f, function() f:Hide() end)   -- (1.5.4) Escape closes it like its Close button
	ns:CombatWindow(f)   -- (1.5.6) fades in combat like the bags window
	MR[spec.frameKey] = f
	return f
end
local function listRow(f, i)
	local r = f.rows[i]
	if r then return r end
	local spec = LISTS[f.kind]
	r = CreateFrame("Frame", nil, f.child); r:SetSize(NW - 44, NROW - 2)
	r:EnableMouse(true)
	r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT", 2, 0)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.name:SetPoint("RIGHT", -28, 0); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
	r.remove = ns.IconButton(r, "Interface\\AddOns\\BagSmith\\Media\\ui-close.tga", spec.removeTip, function(b) spec.remove(b:GetParent().id) end)
	r.remove:SetSize(16, 16); r.remove:SetPoint("RIGHT", -4, 0)
	r:SetScript("OnEnter", function(self)
		if not (self.id and ns.TooltipsOK()) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. self.id); GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.rows[i] = r
	return r
end
function MR:RefreshListWindow(kind)
	local spec = LISTS[kind]
	local f = self[spec.frameKey]
	if not (f and f:IsShown()) then return end
	local all = spec.list()
	local text = (f.search:GetText() or ""):lower()
	local list = {}
	for _, e in ipairs(all) do if text == "" or e.name:lower():find(text, 1, true) then list[#list + 1] = e end end
	f.sub:SetText(spec.count(#all))
	for i, e in ipairs(list) do
		local r = listRow(f, i)
		r.id = e.id
		local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id)) or (C_Item and C_Item.GetItemInfoInstant and select(5, C_Item.GetItemInfoInstant(e.id)))
		r.icon:SetTexture(icon)
		r.name:SetText(e.name); r.name:SetTextColor(unpack(ns.Skins:Current().text))
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", f.child, "TOPLEFT", 0, -(i - 1) * NROW); r:Show()
	end
	for i = #list + 1, #f.rows do f.rows[i]:Hide() end
	f.child:SetHeight(math.max(1, #list * NROW))
	f.empty:SetShown(#list == 0)
	f.empty:SetText(#all == 0 and spec.empty or "No items match.")
end
local function manage(kind)
	local f = listWindow(kind)
	f.search:SetText("")
	f:Show()
	MR:RefreshListWindow(kind)
end
function MR:NeverWindow() return listWindow("never") end
function MR:RefreshNeverWindow() self:RefreshListWindow("never") end
function MR:ManageNever() manage("never") end
function MR:ProtectedWindow() return listWindow("protect") end
function MR:RefreshProtectedWindow() self:RefreshListWindow("protect") end
function MR:ManageProtected() manage("protect") end

------------------------------------------------------------------------
-- Value: vendor and AH (when Auctionator knows it); the setting picks which ranks.
------------------------------------------------------------------------
-- (1.6.0-beta11, Shweep: "handle everywhere") bound: "soulbound" (an item in your bags, AH:Sellable) or "bop" (loot that
-- binds when picked up). Neither can be sold at the auction house, so it has no AH value and ranks at its vendor price,
-- whatever Rank Suggestions By says.
function MR:Values(id, count, link, bound)
	count = count or 1
	local v = { vendor = sellPrice(id) * count, bound = bound or nil }
	if ns.AH and ns.AH:Available() and not bound then
		local p = ns.AH:Price({ itemID = id, link = link })
		if p then v.ah = p * count end
	end
	return v
end
local function bindsOnPickup(id) return id and select(14, itemInfo(id)) == 1 end   -- (Enum.ItemBind: 1 is on pickup)
function MR:Rank(v)
	if (ns.db.makeRoomValue or "ah") == "ah" and v.ah then return v.ah end
	return v.vendor
end
function MR:ValueText(v)
	local vt = "Vendor " .. ((v.vendor or 0) > 0 and money(v.vendor) or "-")
	if not (ns.AH and ns.AH:Available()) then return "|cffffffff" .. vt .. "|r" end
	if v.bound then   -- (1.6.0-beta11) the vendor price is the one that counts
		return "|cffffffff" .. vt .. "|r   AH " .. (v.bound == "bop" and (ITEM_BIND_ON_PICKUP or "Binds when picked up") or (ITEM_SOULBOUND or "Soulbound"))
	end
	local at = "AH " .. (v.ah and money(v.ah) or "no price yet")
	-- the price the ranking follows is the brighter one
	if (ns.db.makeRoomValue or "ah") == "ah" and v.ah then return vt .. "   |cffffffff" .. at .. "|r" end
	return "|cffffffff" .. vt .. "|r   " .. at
end

------------------------------------------------------------------------
-- Space
------------------------------------------------------------------------
function MR:BagFamily(bag)
	local _, family = C_Container.GetContainerNumFreeSlots(bag)
	return family or 0
end
local function freeSpace()
	local out = {}
	for _, bag in ipairs(ns.BAGS) do
		if bag ~= ns.KEYRING then
			local free, family = C_Container.GetContainerNumFreeSlots(bag)
			-- The reagent bag only takes crafting reagents, whatever family it reports.
			if (free or 0) > 0 then out[#out + 1] = { bag = bag, free = free, family = family or 0, reagent = ns:IsReagentBag(bag) } end
		end
	end
	return out
end
local function isReagent(id) return select(17, itemInfo(id)) and true or false end
-- Loot that won't fit (skipped and never-asked items left out).
-- What's asking for room: the loot window's items, or (quest mode) the
-- quest's reward items, or the item a quest hands you on accepting.
local function lootEntries(self)
	local out = {}
	local n = GetNumLootItems and GetNumLootItems() or 0
	local never = self:Never()
	-- (1.5.1) Items on their way to the bags come first: the room they'll take still looks free, so it's reserved
	-- for them (they never show as waiting). (1.5.1-beta2) Per item: what has left the loot window and not arrived.
	for id in pairs(self.ledger or {}) do
		local owed = self:Owed(id)
		if owed > 0 then out[#out + 1] = { reserved = true, id = id, qty = owed, name = "" } end
	end
	local covered = self:Covered()
	for slot = 1, n do
		if GetLootSlotType and GetLootSlotType(slot) == (LOOT_SLOT_ITEM or 1) then
			local link = GetLootSlotLink(slot)
			local icon, name, qty, _, quality, _, isQuestItem = GetLootSlotInfo(slot)
			local id = link and tonumber(link:match("item:(%d+)"))
			-- (1.5.1) what each slot holds, so an item looted by hand is accounted for when its slot clears; and
			-- (1.5.1-beta2) the item's arrivals are counted from when the loot window first showed it
			if id then
				self.slotItem = self.slotItem or {}
				self.slotItem[slot] = { id = id, qty = qty or 1 }
				self:Ledger(id)
			end
			-- (a slot whose items already reached the bags before it cleared isn't counted again)
			if id and not covered[slot] and not self.skipped[slot .. ":" .. id] and not never[id] then
				out[#out + 1] = { slot = slot, id = id, name = name or "?", qty = qty or 1, quality = quality, icon = icon, link = link,
					questItem = isQuestItem == true or nil }   -- (1.7.0-beta12) for the note: a quest item never has a price
			end
		end
	end
	return out
end
-- A quest's reward items, read while its turn-in window is open (kept, so
-- they're known after the window closes).
local function readRewards()
	local out = {}
	for i = 1, (GetNumQuestRewards and GetNumQuestRewards() or 0) do
		local name, icon, qty, quality = GetQuestItemInfo("reward", i)
		local link = GetQuestItemLink and GetQuestItemLink("reward", i)
		local id = link and tonumber(link:match("item:(%d+)"))
		out[#out + 1] = { id = id, name = name or "?", qty = qty or 1, quality = quality, icon = icon, link = link }
	end
	-- One slot for the reward you'll choose (any of them).
	if (GetNumQuestChoices and GetNumQuestChoices() or 0) > 0 then
		out[#out + 1] = { name = "Your choice of reward", qty = 1, icon = "Interface\\Icons\\INV_Misc_QuestionMark" }
	end
	return out
end
MR.ReadRewards = readRewards
local function questEntries(self)
	local q = self.quest
	if not q then return {} end
	local out = {}
	if q.kind == "complete" then
		for _, e in ipairs(q.rewards or {}) do
			out[#out + 1] = { id = e.id, name = e.name, qty = e.qty, quality = e.quality, icon = e.icon, link = e.link }
		end
	else
		-- The game doesn't say which item a quest hands you on accepting.
		out[#out + 1] = { name = "An item from this quest", qty = 1, icon = "Interface\\Icons\\INV_Misc_QuestionMark" }
	end
	return out
end
-- The entries that won't fit (room in existing stacks first, then special
-- bags that take them, then ordinary bags), each counted against the last.
-- (1.7.0-beta10) first: the order slots are handed out in (the target, then the rest); the answer keeps the loot
-- window's order
local function fitting(self, entries, first)
	local out = {}
	if #entries == 0 then return out end
	if first then
		local ordered = {}
		for _, e in ipairs(entries) do if e.reserved then ordered[#ordered + 1] = e end end
		ordered[#ordered + 1] = first
		for _, e in ipairs(entries) do if not e.reserved and e ~= first then ordered[#ordered + 1] = e end end
		local at = {}
		for i, e in ipairs(entries) do at[e] = i end
		local res = fitting(self, ordered)
		table.sort(res, function(a, b) return at[a] < at[b] end)
		return res
	end
	local free = freeSpace()
	local room = {}
	for _, r in ipairs(ns.items or {}) do
		if r.itemID then room[r.itemID] = (room[r.itemID] or 0) + math.max(0, maxStack(r.itemID) - (r.count or 1)) end
	end
	for _, e in ipairs(entries) do
		local id, qty = e.id, e.qty or 1
		local max = id and maxStack(id) or 1
		-- First into room left in existing (or just-planned) stacks...
		local fromRoom = id and math.min(room[id] or 0, qty) or 0
		local rest = qty - fromRoom
		-- ...then as many new slots as the rest needs, special bags first.
		local need = rest > 0 and math.ceil(rest / max) or 0
		local fam, reagent = id and itemFamily(id) or 0, id and isReagent(id) or false
		local taken = {}
		for pass = 1, 2 do
			for _, b in ipairs(free) do
				local takes
				if b.reagent then takes = pass == 1 and reagent
				elseif pass == 1 then takes = b.family ~= 0 and band(fam, b.family) ~= 0
				else takes = b.family == 0 end
				while need > 0 and b.free > 0 and takes do b.free = b.free - 1; need = need - 1; taken[#taken + 1] = b end
			end
		end
		if need > 0 then
			for _, b in ipairs(taken) do b.free = b.free + 1 end   -- it won't fit: give the slots back
			if not e.reserved then
				e.values = id and self:Values(id, qty, e.link, bindsOnPickup(id) and "bop" or nil) or { vendor = 0 }
				out[#out + 1] = e
			end
		elseif id then
			-- It fits; the new stacks' spare room is there for the next entry.
			room[id] = (room[id] or 0) - fromRoom + (#taken * max - rest)
		end
	end
	return out
end
-- (1.7.0-beta10, Shweep: "better understand which item you are determining for") The loot the Loot Helper makes room
-- for: the waiting entry you clicked (MR.target, until the loot window changes), else the most valuable. It gets the
-- free slots first, so a slot you free goes to it (MR:Waiting), and every offer is judged against it alone.
function MR:TargetKey(e) return tostring(e.slot or "q") .. ":" .. tostring(e.id or e.name) end
local function entryRank(self, e)
	if not e.values then e.values = e.id and self:Values(e.id, e.qty or 1, e.link, bindsOnPickup(e.id) and "bop" or nil) or { vendor = 0 } end
	return self:Rank(e.values)
end
-- (1.7.0-beta12) Loot that's a quest item (the loot window says so, or its item class is Quest): it never has a price.
local QUEST_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Questitem) or 12
function MR:IsQuestItem(e)
	if not (e and e.id) then return false end
	if e.questItem then return true end
	local classID = C_Item and C_Item.GetItemInfoInstant and select(6, C_Item.GetItemInfoInstant(e.id))
	if classID == nil then classID = select(12, itemInfo(e.id)) end
	return classID == QUEST_CLASS
end
function MR:Target(list)
	if self.target then
		for _, e in ipairs(list or {}) do if not e.reserved and self:TargetKey(e) == self.target then return e end end
	end
	local best, bestRank
	for _, e in ipairs(list or {}) do
		if not e.reserved then
			local r = entryRank(self, e)
			if not best or r > bestRank then best, bestRank = e, r end
		end
	end
	return best
end
function MR:Waiting()
	local entries = self.mode == "quest" and questEntries(self) or lootEntries(self)
	return fitting(self, entries, self:Target(entries))
end

-- Soul Shards in ordinary bags (never soul bags), and how many may go.
function MR:Shards()
	local list = {}
	for _, r in ipairs(ns.items or {}) do
		if r.itemID == SHARD and r.bag and self:BagFamily(r.bag) == 0 then list[#list + 1] = r end
	end
	local total = 0
	for _, r in ipairs(ns.items or {}) do if r.itemID == SHARD then total = total + (r.count or 1) end end
	local keep = ns.db.shardKeep or 0
	local can = math.max(0, math.min(#list, total - keep))
	return list, can, total
end

------------------------------------------------------------------------
-- Suggestions
------------------------------------------------------------------------
-- Can a slot in this bag hold this waiting entry? (The same rules as the
-- fit check: the reagent bag only takes reagents, a special bag only what its
-- family takes, an ordinary bag anything.)
function MR:BagHolds(bag, w)
	if ns:IsReagentBag(bag) then return w.id and isReagent(w.id) or false end
	local family = self:BagFamily(bag)
	if family ~= 0 then return w.id and band(itemFamily(w.id), family) ~= 0 or false end
	return true
end
-- Freeing a slot in this bag helps only if some waiting entry could use it.
function MR:SlotHelps(bag, waiting)
	for _, w in ipairs(waiting) do if self:BagHolds(bag, w) then return true end end
	return false
end
-- The rank of the most valuable waiting entry that could use a slot in this bag, or 0. A candidate is judged
-- only against loot that could take its place (1.3.0-beta2: a quiver's arrows aren't let go for a ring).
function MR:BestFor(bag, waiting)
	local best = 0
	for _, w in ipairs(waiting) do
		if self:BagHolds(bag, w) then best = math.max(best, self:Rank(w.values or { vendor = 0 })) end
	end
	return best
end
-- The one rule, shared by the suggestions and the last check before destroying: an item is worth letting go
-- when it's junk (and its slot helps), or when it's cheaper than the most valuable waiting loot that could use
-- its slot.
function MR:WorthLettingGo(bag, rank, junk, waiting)
	if not self:SlotHelps(bag, waiting) then return false end
	if junk then return true end
	local best = self:BestFor(bag, waiting)
	-- (1.5.1) Loot with no price (no vendor price and no AH price yet) has nothing to compare with. Rather than offer
	-- nothing, the cheapest items are offered, cheapest first. (1.6.0, the beta11 audit's D1) Destroying one follows the
	-- same rules as any other (MR:AsksFirst): junk in one click; with Ask Before Destroying on, everything asks; otherwise
	-- rare or better asks while Always Ask for Rare or Better is on. This comment used to say each one asks.
	if best <= 0 then return true, true end
	return (rank or 0) < best
end

-- (1.7.0-beta10) judge: the loot it's making room for ({ MR:Target(waiting) }); slots and values are judged against it
-- alone. Waiting loot of any kind is never offered itself. Also returns how many items were left out only for being
-- worth more than it (pricier), for the note.
function MR:Suggestions(waiting, judge)
	judge = judge or waiting
	local loot = {}
	for _, w in ipairs(waiting) do
		if w.id then loot[w.id] = true end
	end
	local combine, destroy = {}, {}
	-- Two partial stacks of the same item that fit in one: frees a slot for nothing.
	local partial = {}
	for _, r in ipairs(ns.items or {}) do
		if r.itemID and r.bag and not r.isLocked then
			local max = maxStack(r.itemID)
			if max > 1 and (r.count or 1) < max then partial[r.itemID] = partial[r.itemID] or {}; table.insert(partial[r.itemID], r) end
		end
	end
	for id, list in pairs(partial) do
		if #list >= 2 then
			table.sort(list, function(a, b) return (a.count or 1) < (b.count or 1) end)
			local max = maxStack(id)
			-- The smallest stack whose slot helps, poured into the largest stack it fits in.
			local found
			for i = 1, #list do
				local src = list[i]
				if self:SlotHelps(src.bag, judge) then
					for j = #list, 1, -1 do
						local dst = list[j]
						if j ~= i and (src.count or 1) + (dst.count or 1) <= max then found = { src = src, dst = dst, name = src.name }; break end
					end
				end
				if found then break end
			end
			if found then combine[#combine + 1] = found end
		end
	end
	table.sort(combine, function(a, b) return a.name < b.name end)
	for i = #combine, MAX_COMBINE + 1, -1 do combine[i] = nil end
	-- Items to let go (1.7.0-beta3, Shweep: "how much it's really worth to you", not its price alone). Offered: junk,
	-- whatever it's worth, and anything else worth less than the loot that could use its slot. Protected items that would
	-- otherwise have qualified are counted by reason instead (1.3.0), and so is anything an active quest still asks for
	-- ("questneed"). The order, least missed first: the value the setting ranks by, counted MAT_WEIGHT times over for a
	-- material one of your professions uses (MR:Materials) and at SPARE_WEIGHT for a spare stack (a smaller stack of an
	-- item you carry more of). Junk ranks by value with everything else. The weights only order the list: what may be
	-- offered, and the check at the click, still go by plain value. Every candidate is listed (the panel scrolls).
	local held = ns.Why:New()
	local pricier = 0
	local needs, questsRead = self:QuestObjectives()
	local mats = self:Materials()
	local mainStack = {}
	for _, r in ipairs(ns.items or {}) do
		if r.itemID and r.bag then
			local m = mainStack[r.itemID]
			if not m or (r.count or 1) > (m.count or 1) then mainStack[r.itemID] = r end
		end
	end
	for _, r in ipairs(ns.items or {}) do
		if r.itemID and r.bag and not r.isLocked and not loot[r.itemID] and r.itemID ~= SHARD and self:SlotHelps(r.bag, judge) then
			local v = self:Values(r.itemID, r.count or 1, r.link, r.isBound and "soulbound" or nil)
			local rank = self:Rank(v)
			local junk = ns.Junk and ns.Junk:IsJunk(r)
			local worth, noPrice = self:WorthLettingGo(r.bag, rank, junk, judge)
			if not worth and not junk then pricier = pricier + 1 end
			local why
			if r.isQuest then why = "quest"
			elseif not questsRead then why = "unknown"   -- (1.7.0-beta5, F2) the quest log couldn't be read: nothing is offered
			elseif self:NeededForQuest(r.name, needs) then why = "questneed"
			elseif r.hasNoValue or (r.sellPrice or 0) <= 0 then why = "novalue"
			elseif ns.Marks and ns.Marks:IsFavorite(r.itemID) then why = "favorite"
			elseif self:IsProtected(r.itemID) then why = "protected"
			elseif ns.Pawn and ns.Pawn:IsUpgrade(r) then why = "pawn"
			elseif ns.GearSets then
				local sets, unreadable = ns.GearSets:SetsAt(r.bag, r.slot)
				if unreadable then why = "unknown" elseif sets then why = "gearset" end
			end
			if why then
				if worth then ns.Why:Add(held, why, r.name) end
			elseif worth then
				local mat = (not junk) and mats[r.itemID] or false
				local spare = mainStack[r.itemID] ~= r
				local order = rank * (mat and MAT_WEIGHT or 1) * (spare and SPARE_WEIGHT or 1)
				destroy[#destroy + 1] = { rec = r, values = v, rank = rank, order = order, junk = junk, mat = mat, spare = spare, noPrice = noPrice and not junk }
			end
		end
	end
	table.sort(destroy, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		if a.rank ~= b.rank then return a.rank < b.rank end
		if (a.rec.name or "") ~= (b.rec.name or "") then return (a.rec.name or "") < (b.rec.name or "") end
		if a.rec.bag ~= b.rec.bag then return a.rec.bag < b.rec.bag end
		return (a.rec.slot or 0) < (b.rec.slot or 0)
	end)
	local noPrice = false
	for _, d in ipairs(destroy) do if d.noPrice then noPrice = true end end
	return combine, destroy, held, noPrice, pricier
end

-- (1.7.0-beta4, Shweep's wording) How the "let go" list is ordered, said plainly: the footer's (i), and Settings >
-- Loot Helper says the same.
function MR:HowItDecides()
	local ahPrices = (ns.db and (ns.db.makeRoomValue or "ah") == "ah") and ns.AH and ns.AH:Available()
	return {
		"Mostly it goes by price, cheapest first. Things you craft with stay further down, and if you have two stacks of something, the smaller one goes first.",
		"Junk always shows up, even when it's worth more than what you're looting.",
		"Anything you still need for a quest is never on the list, unless its heading is collapsed in your quest log.",
		ahPrices and "Prices come from the AH when it has one, otherwise the vendor." or "Prices come from the vendor.",
		"It learns what you craft with when you open your profession window.",
	}
end

-- (1.7.0-beta3) What your quests still ask you to bring: the item objectives in your quest log, finished or not (they're
-- handed in). The game words them by name ("Linen Cloth: 3/10").
-- (1.7.0-beta5, the beta4 audit's F2) It fails closed. Returns the objectives and whether the reading is complete. A
-- quest's last good reading this session is remembered (MR.questMemo): a quest whose read fails keeps it, and so does a
-- quest whose heading has been collapsed since (the game doesn't list those). A failed read with nothing remembered makes
-- the reading incomplete, and nothing is destroyed until it can be read. A client without the quest log functions has
-- nothing to read (complete, no needs). A quest leaves the memory when it's turned in or abandoned, or when the whole log
-- is in view and it isn't there.
-- (1.7.0-beta8, the beta7 audit's F1 and A1) A quest is remembered by its quest ID (a positive number). One without an ID
-- never borrows a reading: if it can't be read, the reading is incomplete; quests that share a title keep all their
-- objectives together (by title, objective name -> text), replaced only by a full read with nothing collapsed. Every
-- answer is checked: a count must be a number, each declared objective a text and a kind, C_QuestLog's entries tables
-- with a type (and an item's text). Anything else is a failed read, which tries C_QuestLog next. A real 0 or an empty
-- list is still an answer. report (optional, /bs questlog): each quest listed, with how it was read.
-- (1.7.0-beta9, the beta8 audit's A2) An item objective with blank text, or C_QuestLog's list with a hole in it, is a
-- failed read too (a non-item objective's blank text is fine).
MR.questMemo = MR.questMemo or {}
local function objectiveName(text) return text:match("^(.-):%s*%d+%s*/%s*%d+%s*$") or text end
-- (1.7.0-beta9) A usable quest ID: a positive number (also for /bs questlog's count), else nil.
function MR.QuestID(v)
	v = tonumber(v)
	if v and v > 0 then return v end
	return nil
end
-- (1.7.0-beta9, the beta8 audit's A2) an item objective's text must name something
local function blank(text) return not text:find("%S") end
-- The quest log's lines for quest i: nil unless every declared objective came back.
local function logTexts(i)
	local okN, m = pcall(GetNumQuestLeaderBoards, i)
	m = okN and tonumber(m) or nil
	if not m or m < 0 then return nil end
	local texts = {}
	for j = 1, m do
		local okL, text, kind = pcall(GetQuestLogLeaderBoard, j, i)
		if not okL or type(text) ~= "string" or type(kind) ~= "string" then return nil end
		if kind == "item" then
			if blank(text) then return nil end
			texts[#texts + 1] = text
		end
	end
	return texts
end
-- C_QuestLog's objectives for a quest ID: nil unless every entry is well formed.
-- (1.7.0-beta9, A2) and the list has no holes: its keys are exactly 1 to n (ipairs would stop at a hole)
local function apiTexts(questID)
	local okO, objs = pcall(C_QuestLog.GetQuestObjectives, questID)
	if not okO or type(objs) ~= "table" then return nil end
	local n = 0
	for k in pairs(objs) do
		if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then return nil end
		n = n + 1
	end
	local texts = {}
	for i = 1, n do
		local o = objs[i]
		if type(o) ~= "table" or type(o.type) ~= "string" then return nil end
		if o.type == "item" then
			if type(o.text) ~= "string" or blank(o.text) then return nil end
			texts[#texts + 1] = o.text
		end
	end
	return texts
end
function MR:QuestObjectives(report)
	local memo = self.questMemo
	if not GetNumQuestLogEntries then return {}, true end
	local okC, n = pcall(GetNumQuestLogEntries)
	n = okC and tonumber(n) or nil
	local complete = n ~= nil and n >= 0
	local hasLog = GetNumQuestLeaderBoards and GetQuestLogLeaderBoard
	local hasApi = C_QuestLog and C_QuestLog.GetQuestObjectives
	local seen, byTitle, collapsed = {}, {}, false
	for i = 1, (complete and n or 0) do
		local ok, title, _, _, isHeader, isCollapsed, _, _, questID = pcall(GetQuestLogTitle, i)
		if not ok or type(title) ~= "string" or title == "" then
			complete = false
			if report then report[#report + 1] = { line = i, failed = true } end
		elseif isHeader then
			if isCollapsed then collapsed = true end
		else
			questID = MR.QuestID(questID)
			local texts, via
			if hasLog then texts = logTexts(i); via = texts and "log" end
			if not texts and questID and hasApi then texts = apiTexts(questID); via = texts and "C_QuestLog" end
			if not texts and not (GetQuestLogLeaderBoard or hasApi) then texts, via = {}, "none" end   -- nothing to read objectives with
			if questID then
				seen[questID] = true
				if texts then memo[questID] = texts elseif not memo[questID] then complete = false end
			else
				local key = "t:" .. title
				seen[key] = true
				if texts then
					local u = byTitle[key] or {}
					byTitle[key] = u
					for _, t in ipairs(texts) do u[objectiveName(t)] = t end
				else
					complete = false   -- no ID: never take another quest's reading for this one
				end
			end
			if report then report[#report + 1] = { title = title, questID = questID, via = via, texts = texts } end
		end
	end
	local full = complete and not collapsed
	for key, u in pairs(byTitle) do
		if not full then for _, t in ipairs(memo[key] or {}) do local k = objectiveName(t); if u[k] == nil then u[k] = t end end end
		local list = {}
		for _, t in pairs(u) do list[#list + 1] = t end
		memo[key] = list
	end
	-- the whole log in view and read: anything remembered that isn't in it has left it
	if full then for key in pairs(memo) do if not seen[key] then memo[key] = nil end end end
	local out = {}
	for _, texts in pairs(memo) do for _, t in ipairs(texts) do out[#out + 1] = t end end
	return out, complete, collapsed, n
end
function MR:ForgetQuest(questID) local id = MR.QuestID(questID); if id then self.questMemo[id] = nil end end
-- Does a quest objective ask for this item? "Linen Cloth: 3/10" names it exactly; an objective worded some other way
-- (another language's order) counts if it contains the name, which can only keep more, never less.
function MR:NeededForQuest(name, objectives)
	if type(name) ~= "string" or name == "" then return false end
	for _, text in ipairs(objectives or {}) do
		local named = text:match("^(.-):%s*%d+%s*/%s*%d+%s*$")
		if named then
			if named == name then return true end
		elseif text:find(name, 1, true) then
			return true
		end
	end
	return false
end

-- (1.7.0-beta3) Materials your crafting professions use, learned per character from the recipes you know each time a
-- profession window opens or changes (BagSmithCharDB.professionMats: profession -> item ID -> true). A recipe list
-- narrowed by a search or filter only adds; a material never seen in a window isn't known.
function MR:Materials()
	local out = {}
	local t = ns.cdb and ns.cdb.professionMats
	if type(t) == "table" then
		for _, set in pairs(t) do if type(set) == "table" then for id in pairs(set) do out[id] = true end end end
	end
	return out
end
local function remember(prof, set)
	if not (ns.cdb and type(prof) == "string" and prof ~= "" and next(set)) then return end
	if type(ns.cdb.professionMats) ~= "table" then ns.cdb.professionMats = {} end
	local t = ns.cdb.professionMats[prof]
	if type(t) ~= "table" then t = {}; ns.cdb.professionMats[prof] = t end
	for id in pairs(set) do t[id] = true end
end
local function itemIdOf(link) return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil end
function MR:LearnTradeSkill()
	if not (GetTradeSkillLine and GetNumTradeSkills and GetTradeSkillNumReagents and GetTradeSkillReagentItemLink) then return end
	local okP, prof = pcall(GetTradeSkillLine)
	if not okP or type(prof) ~= "string" or prof == "" or prof == "UNKNOWN" then return end
	local set = {}
	local okN, n = pcall(GetNumTradeSkills)
	for i = 1, (okN and tonumber(n) or 0) do
		local okI, _, kind = pcall(GetTradeSkillInfo, i)
		if okI and kind ~= "header" then
			local okR, m = pcall(GetTradeSkillNumReagents, i)
			for j = 1, (okR and tonumber(m) or 0) do
				local okL, link = pcall(GetTradeSkillReagentItemLink, i, j)
				local id = okL and itemIdOf(link)
				if id then set[id] = true end
			end
		end
	end
	remember(prof, set)
end
-- Enchanting's window is the craft window on this client.
function MR:LearnCraft()
	if not (GetNumCrafts and GetCraftNumReagents and GetCraftReagentItemLink) then return end
	local getName = GetCraftDisplaySkillLine or GetCraftName
	local okP, prof = pcall(getName or function() end)
	if not okP or type(prof) ~= "string" or prof == "" then return end
	local set = {}
	local okN, n = pcall(GetNumCrafts)
	for i = 1, (okN and tonumber(n) or 0) do
		local okI, _, _, kind = pcall(GetCraftInfo, i)
		if okI and kind ~= "header" then
			local okR, m = pcall(GetCraftNumReagents, i)
			for j = 1, (okR and tonumber(m) or 0) do
				local okL, link = pcall(GetCraftReagentItemLink, i, j)
				local id = okL and itemIdOf(link)
				if id then set[id] = true end
			end
		end
	end
	remember(prof, set)
end

-- (1.5.1) The bags this loot can't go in (a quiver, a reagent bag for loot that isn't a reagent), by name, for
-- the card: their free slots and their items can't make room for it.
function MR:BagsLootCantUse(waiting)
	local names = {}
	for _, bag in ipairs(ns.BAGS) do
		if bag ~= ns.KEYRING and (C_Container.GetContainerNumSlots(bag) or 0) > 0 and not self:SlotHelps(bag, waiting) then
			names[#names + 1] = ns:BagName(bag)
		end
	end
	if #names == 0 then return nil end
	if #names > 3 then return ("%s, %s, %s and %d more"):format(names[1], names[2], names[3], #names - 3) end
	if #names == 1 then return names[1] end
	return table.concat(names, ", ", 1, #names - 1) .. " or " .. names[#names]
end

-- How many slots Blizzard's Clean Up Bags would free: stacks merging into
-- fewer, plus items in ordinary bags moving into special bags with room
-- (a crafting reagent into the reagent bag, a shard into a soul bag...).
function MR:CleanUpGain()
	local gain = 0
	local byItem = {}
	for _, r in ipairs(ns.items or {}) do
		if r.itemID and r.bag then
			local e = byItem[r.itemID] or { stacks = 0, total = 0 }
			e.stacks, e.total = e.stacks + 1, e.total + (r.count or 1)
			byItem[r.itemID] = e
		end
	end
	for id, e in pairs(byItem) do
		local max = maxStack(id)
		if max > 1 then gain = gain + math.max(0, e.stacks - math.ceil(e.total / max)) end
	end
	for _, b in ipairs(freeSpace()) do
		if b.reagent or b.family ~= 0 then
			local movable = 0
			for _, r in ipairs(ns.items or {}) do
				if r.itemID and r.bag and not ns:IsReagentBag(r.bag) and self:BagFamily(r.bag) == 0 then
					local fits
					if b.reagent then fits = isReagent(r.itemID) else fits = band(itemFamily(r.itemID), b.family) ~= 0 end
					if fits then movable = movable + 1 end
				end
			end
			gain = gain + math.min(b.free, movable)
		end
	end
	return gain
end
-- Offer Clean Up Bags only when it would free more than the Combine
-- suggestions already do (and never in combat, where the game blocks it).
function MR:CleanUpHelps(combineCount)
	if InCombatLockdown() or not C_Container.SortBags then return false end
	return self:CleanUpGain() > (combineCount or 0)
end

------------------------------------------------------------------------
-- Actions (each from a click on the panel)
------------------------------------------------------------------------
local function pickUp(bag, slot, id, link)
	ClearCursor()
	C_Container.PickupContainerItem(bag, slot)
	local kind, cid, clink = GetCursorInfo()
	if kind == "item" and cid == id and (not link or not clink or clink == link) then return true end
	ClearCursor()
	return false
end
-- (1.7.0-beta9, the beta8 audit's A1) Delete the item just picked up, and check it went: the game can refuse an addon's
-- delete (another Forever addon's author found it blocked on one client), silently or with an error. An error, or the
-- item still on the cursor, means it wasn't destroyed: it goes back to its slot (ClearCursor) and the answer is false,
-- so nothing counts it as gone.
local function deleteHeld(id)
	local ok = pcall(DeleteCursorItem)
	local kind, cid = GetCursorInfo()
	if ok and not (kind == "item" and cid == id) then return true end
	ClearCursor()
	return false
end
local function guidAt(bag, slot)
	if not (C_Item and C_Item.GetItemGUID and ItemLocation) then return nil end
	local ok, guid = pcall(function()
		local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
		if loc and C_Item.DoesItemExist(loc) then return C_Item.GetItemGUID(loc) end
	end)
	return ok and guid or nil
end
-- What a destroy offer was about: this exact item, this many.
-- (1.5.1-beta2) basis: why it's offered ("junk", "priced": worth less than the loot, or "noprice": the loot has no
-- price to compare with). An offer is only good while that reason still holds.
-- (1.6.0-beta6, the beta5 audit's F1; Shweep) value: the value the offer was ranked by (MR:Rank) when it was made. A
-- different value at the click (another price source, a fresh scan, Rank Suggestions By changed) means it's no longer the
-- offer that was shown, and nothing is destroyed.
function MR:Offer(rec, junk, basis, value)
	return { bag = rec.bag, slot = rec.slot, itemID = rec.itemID, count = rec.count or 1, link = rec.link,
		guid = rec.guid or guidAt(rec.bag, rec.slot), name = rec.name, junk = junk and true or false, session = MR.offerToken,
		basis = junk and "junk" or basis or "priced",   -- (no reason given: only the strict rule, worth less than the loot)
		value = (not junk) and value or nil }
end
-- (1.5.1-beta2) Does destroying this ask first? Junk never does; with Ask Before Destroying on, everything else does;
-- otherwise rare quality or better does while Always Ask for Rare or Better is on, as the game asks for those.
function MR:AsksFirst(rec, junk)
	if junk then return false end
	local db = ns.db or {}
	if db.makeRoomAsk then return true end
	-- (1.5.1-beta3, L4) a quality that isn't known counts as possibly rare
	return db.makeRoomAskRare ~= false and (rec.qualityUnknown or (rec.quality or 1) >= 3)
end
-- (1.5.1-beta3, the beta2 audit's L3 and L4) The same decision at the moment of the click, from the current settings and
-- the item's current quality (the bag's, else the cached one; unknown counts as possibly rare), whatever the row
-- remembered when it was drawn.
function MR:LiveQuality(o)
	local info = C_Container.GetContainerItemInfo(o.bag, o.slot)
	local q = info and info.quality
	if q == nil then q = select(3, itemInfo(o.link or o.itemID)) end
	return q
end
function MR:AsksFirstLive(o)
	if o.junk then return false end
	local db = ns.db or {}
	if db.makeRoomAsk then return true end
	if db.makeRoomAskRare == false then return false end
	local q = self:LiveQuality(o)
	return q == nil or q >= 3
end
-- At the moment of destroying: is it still exactly what was offered, and
-- still allowed? Anything changed means nothing is destroyed.
function MR:StillOk(o)
	local info = C_Container.GetContainerItemInfo(o.bag, o.slot)
	if not info or info.itemID ~= o.itemID then return false, "moved" end
	if (info.stackCount or 1) ~= (o.count or 1) then return false, "changed" end
	if o.link and info.hyperlink and info.hyperlink ~= o.link then return false, "changed" end
	if info.isLocked then return false, "changed" end
	-- The offer belongs to the loot (or quest) it was made for.
	if o.session ~= MR.offerToken then return false, "stale" end
	local guid = guidAt(o.bag, o.slot)
	if o.guid and guid and guid ~= o.guid then return false, "changed" end
	-- An item that had a unique ID but no longer reads as one counts as changed; so does an offer recorded
	-- without one where the client gives instances (1.3.0: it can't be told from another copy).
	if o.guid and not guid and C_Item and C_Item.GetItemGUID then return false, "changed" end
	if not o.guid and C_Item and C_Item.GetItemGUID and ItemLocation then return false, "changed" end
	-- Freeing this slot must still help what's waiting now.
	-- (1.7.0-beta10) judged against the loot it's making room for now (the target), as the list is: if that loot is
	-- looted or skipped, the next one takes its place, and the offer must still be worth letting go for it
	local waitingNow = self:Waiting()
	local target = self:Target(waitingNow)
	local judge = target and { target } or waitingNow
	if not self:SlotHelps(o.bag, judge) then return false, "nohelp" end
	if ns.Marks and ns.Marks:IsFavorite(o.itemID) then return false, "favorite" end
	if self:IsProtected(o.itemID) then return false, "protected" end   -- (1.7.0-beta1)
	do   -- (1.7.0-beta3) what a quest still asks for; (1.7.0-beta5, F2) a quest log that can't be read is a no
		local needs, questsRead = self:QuestObjectives()
		if not questsRead then return false, "questlog" end
		if self:NeededForQuest(o.name or select(1, itemInfo(o.itemID)), needs) then return false, "questneed" end
	end
	-- (set membership re-read from the game right before destroying)
	if ns.GearSets and ns.GearSets.Refresh then ns.GearSets:Refresh() end
	if ns.GearSets then
		local sets, unreadable = ns.GearSets:SetsAt(o.bag, o.slot)
		if unreadable then return false, "unknown" end   -- couldn't be checked is a no (1.3.0)
		if sets then return false, "gearset" end
	end
	if C_Container.GetContainerItemQuestInfo then
		local ok, q = pcall(C_Container.GetContainerItemQuestInfo, o.bag, o.slot)
		-- (1.6.0-beta7, the beta6 audit's advisory) a check that errors is a no, like an unreadable gear-set check
		if not ok then return false, "questunknown" end
		if type(q) == "table" and (q.isQuestItem or q.questID) then return false, "quest" end
	end
	-- (1.5.1-beta2) an item with no vendor price is kept: protected when suggestions are made, and checked again here
	if info.hasNoValue or (select(11, itemInfo(o.itemID)) or 0) <= 0 then return false, "novalue" end
	if o.junk then
		-- Offered as junk (one click): it must still be junk. (1.5.2, L7) Its quality from the bag, else the cache, as
		-- the offer read it; a quality no source reports isn't taken as junk.
		local rec = { itemID = o.itemID, quality = self:LiveQuality(o), sellPrice = select(11, itemInfo(o.itemID)) }
		if ns.Junk and not ns.Junk:IsJunk(rec) then return false, "changed" end
	end
	-- Never destroy something Pawn calls an upgrade, or hasn't decided on yet,
	-- junk-marked or not.
	if ns.Pawn and ns.Pawn:Active() then
		local up = ns.Pawn:IsUpgradeLink(info.hyperlink or o.link, true)   -- asked fresh, right before destroying
		if up == true then return false, "upgrade" end
		if up == nil then return false, "pawn" end
	end
	-- Last: it must still be worth letting go for what's waiting now. The valuable item that justified the offer
	-- may have been looted by someone else or skipped since (1.3.0-beta2). Protections are checked first, so a
	-- protected item says why it's protected.
	if not o.junk then
		local v = self:Values(o.itemID, o.count or 1, o.link, info.isBound and "soulbound" or nil)   -- (bound as the bag says now)
		local worth, noPrice = self:WorthLettingGo(o.bag, self:Rank(v), false, judge)
		if not worth then return false, "worth" end
		-- (1.5.1-beta2, the beta1 audit) and for the same reason it was offered: an offer made because valuable loot was
		-- waiting isn't carried out on the no-price fallback (or the other way round) without being offered again
		if o.basis and o.basis ~= "junk" and o.basis ~= (noPrice and "noprice" or "priced") then return false, "basis" end
		-- (1.6.0-beta6, F1) and at the value it was offered at
		if o.value ~= nil and self:Rank(v) ~= o.value then return false, "price" end
	end
	return true
end
local REFUSED = {
	moved = "That item moved, so nothing was destroyed. The Loot Helper has updated.",
	changed = "That item changed since it was offered, so nothing was destroyed. The Loot Helper has updated.",
	favorite = "That item is a favorite now, so nothing was destroyed.",
	protected = "You protected that item, so nothing was destroyed.",   -- (1.7.0-beta1)
	questneed = "One of your quests still asks for that item, so nothing was destroyed.",   -- (1.7.0-beta3)
	questlog = "BagSmith couldn't check your quests just now, so nothing was destroyed. Try again in a moment.",   -- (1.7.0-beta5)
	gearset = "That item is in one of your gear sets, so nothing was destroyed.",
	quest = "That's a quest item, so nothing was destroyed.",
	upgrade = "Pawn says that item is an upgrade, so nothing was destroyed.",
	pawn = "Pawn hasn't decided yet whether that item is an upgrade. Try again in a moment.",
	stale = "That offer was for a different loot window, so nothing was destroyed.",
	nohelp = "Destroying that wouldn't make room for what's waiting now, so nothing was destroyed.",
	unknown = "BagSmith couldn't check your gear sets just now, so nothing was destroyed. Try again in a moment.",
	questunknown = "BagSmith couldn't check whether that's a quest item just now, so nothing was destroyed. Try again in a moment.",   -- (1.6.0-beta7, Shweep)
	worth = "That item is now worth more than what's waiting for its slot, so nothing was destroyed. The Loot Helper has updated.",
	basis = "What's waiting changed since that was offered, so nothing was destroyed. The Loot Helper has updated.",
	price = "That item's price changed since it was offered, so nothing was destroyed. The Loot Helper has updated.",   -- (1.6.0-beta6, Shweep's wording)
	novalue = "That item has no vendor price, so it's kept. Nothing was destroyed.",
	ask = "Your settings say to ask before destroying that, so nothing was destroyed. Click it again to be asked.",
	-- (1.7.0-beta9, the beta8 audit's A1; Shweep's wording) the game refused the delete
	blocked = "The game wouldn't let BagSmith destroy that, so it's back in your bags. You can still drag it out of your bags to destroy it yourself.",
}
local SHARD_BLOCKED = "The game wouldn't let BagSmith destroy that Soul Shard, so it's back in your bags. You can still drag it out of your bags to destroy it yourself."
-- The row's click: asks first if the current settings and quality call for it, or if the button said it would ask
-- (a button drawn before a setting changed is only ever more careful, never less); otherwise destroys at once.
function MR:TryDestroy(o, btn, what, value, key, shownAsk)
	if shownAsk or self:AsksFirstLive(o) then
		ns.Confirm(btn, ("Destroy %s (%s)?"):format(what, money(value or 0)), function() MR:Destroy(o, true) end)
		if ns.Popups.confirm then ns.Popups.confirm.lootHelper = true; ns.Popups.confirm.lootHelperKey = key end
		return false
	end
	return self:Destroy(o, false)
end
-- confirmed: the player said Yes to a question about this offer. (1.5.1-beta3) Without that, nothing is destroyed
-- that the current settings say should ask first, whatever path called this.
function MR:Destroy(o, confirmed)
	local ok, why = self:StillOk(o)
	if not ok then ns:Print(REFUSED[why] or REFUSED.changed); self:Refresh(); return false end
	if not confirmed and self:AsksFirstLive(o) then ns:Print(REFUSED.ask); self:Refresh(); return false end
	if pickUp(o.bag, o.slot, o.itemID, o.link) then
		if deleteHeld(o.itemID) then return true end
		ns:Print(REFUSED.blocked); self:Refresh()
		return false
	end
	ns:Print(REFUSED.changed); self:Refresh()
	return false
end
function MR:Combine(c)
	local function same(r)
		local info = C_Container.GetContainerItemInfo(r.bag, r.slot)
		return info and info.itemID == r.itemID and (info.stackCount or 1) == (r.count or 1) and not info.isLocked
	end
	if not (same(c.src) and same(c.dst)) then ns:Print(REFUSED.changed); self:Refresh(); return end
	ClearCursor()
	C_Container.PickupContainerItem(c.src.bag, c.src.slot)
	C_Container.PickupContainerItem(c.dst.bag, c.dst.slot)
	ClearCursor()
end
function MR:CleanUp()
	if InCombatLockdown() then ns:Print("Can't clean up during combat."); return end
	if ns.NoteCleanup then ns:NoteCleanup() end   -- (1.4.1) the bags window redraws as it goes, even under the pointer
	if C_Container.SortBags then C_Container.SortBags() end
end
function MR:Skip(w) self.skipped[w.slot .. ":" .. w.id] = true; self.pending[w.slot] = nil; self:Refresh() end
function MR:NeverAsk(w)
	self:Never()[w.id] = true
	self:RefreshNeverWindow()
	-- Every queued copy of that item goes, not just this one.
	for slot in pairs(self.pending) do
		local link = GetLootSlotLink and GetLootSlotLink(slot)
		if link and tonumber(link:match("item:(%d+)")) == w.id then self.pending[slot] = nil end
	end
	self:Refresh()
end

-- Soul Shards: choose how many, confirm once, then one click per shard.
-- (1.7.0-beta5, the beta4 audit's F1) The Soul Shards in your bags, counted live (soul bags included: the keep counts
-- them), for the check right before each delete; nil when a bag can't be read. MR:Shards counts from the last scan,
-- which can be behind (a shard used or moved since, or a scan held while a Clean Up runs).
function MR:LiveShards()
	local total = 0
	for _, bag in ipairs(ns.BAGS or {}) do
		local okN, n = pcall(C_Container.GetContainerNumSlots, bag)
		if not okN then return nil end
		for slot = 1, (tonumber(n) or 0) do
			local okI, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
			if not okI then return nil end
			if info and info.itemID == SHARD then total = total + (info.stackCount or 1) end
		end
	end
	return total
end
function MR:DestroyNextShard(btn)
	local list, can = self:Shards()
	-- (1.5.1-beta3, L3) a batch started without a question isn't carried on once Ask Before Destroying is on: this
	-- click asks for the shards left. A batch you said Yes to carries on.
	if self.shardBatch and not self.shardConfirmed and ns.db and ns.db.makeRoomAsk then self.shardBatch = nil end
	if not self.shardBatch then
		local qty = math.max(1, math.min(self.shardQty or 1, can))
		if can < 1 then return end
		if ns.db and ns.db.makeRoomAsk then
			ns.Confirm(btn, ("Destroy %d Soul %s? You'll click once for each."):format(qty, qty == 1 and "Shard" or "Shards"), function()
				self.shardBatch, self.shardConfirmed = qty, true
				self:DestroyNextShard(btn)   -- the Yes click destroys the first
			end)
			if ns.Popups.confirm then ns.Popups.confirm.lootHelper = true end
			return
		end
		self.shardBatch, self.shardConfirmed = qty, false   -- (1.5.1-beta2) Ask Before Destroying off: this click destroys the first
	end
	local r = list[1]
	if r and can > 0 then
		-- (1.7.0-beta5, F1) never below the keep: the shards are counted live, right before the delete
		local keep, live = (ns.db and ns.db.shardKeep) or 0, self:LiveShards()
		if not live or live - 1 < keep then
			ns:Print(not live and "BagSmith couldn't count your Soul Shards just now, so nothing was destroyed. Try again in a moment."
				or ("That would leave you with fewer than %d Soul %s, so nothing was destroyed."):format(keep, keep == 1 and "Shard" or "Shards"))
			self.shardBatch = nil
			self:Paint()
			return
		end
		local info = C_Container.GetContainerItemInfo(r.bag, r.slot)
		if info and info.itemID == SHARD and not info.isLocked and self:BagFamily(r.bag) == 0 and pickUp(r.bag, r.slot, SHARD) then
			-- (1.7.0-beta9, A1) counted only once it's really gone; a refused delete ends the batch
			if not deleteHeld(SHARD) then
				ns:Print(SHARD_BLOCKED)
				self.shardBatch = nil
				self:Paint()
				return
			end
			self.shardBatch = self.shardBatch - 1
		end
	end
	if not self.shardBatch or self.shardBatch <= 0 or can <= 1 then self.shardBatch = nil end
	self:Paint()
end

-- Loot what now fits: one item per bag update, so each is counted against
-- the bags as they really are.
-- The queue: loot this session found it couldn't take. An entry stays until
-- its loot slot clears (looted by us or by hand), it's skipped, or the loot
-- window closes, so items that start to fit are still taken.
local RETRY_LOOT = 1.0   -- s before asking the game for the same slot again
-- (1.5.1) One item at a time, and the next only once the last has landed. The server can clear a loot slot (and
-- even print "You receive loot") well before the item reaches the bags, and until it does, the slot it will take
-- still looks free: asking for the next item then gets "your bags are full".
-- (1.5.1-beta2, the beta1 audit's L1 and L2) Arrivals are accounted per item, not per loot slot. For each item
-- BagSmith counts what has left the loot window (a slot that cleared, looted by BagSmith or by hand) and credits
-- each increase in your bags once, oldest first. Whatever has left and not arrived is owed: it's reserved in the
-- fit check and holds the next request. So one stack's arrival can't also count for another stack of the same item,
-- 20 of 40 isn't the whole stack, and an item that arrives before its slot clears counts when the slot clears.
-- BagSmith's own request is tracked on its own, whatever is known about the item, until its slot clears, its items
-- arrive first, the game refuses it, or nothing happens for ARRIVE seconds; a refused or unanswered request isn't
-- made again until the bags or the loot window change. An item it can't identify is never requested. A slot that
-- cleared but whose items never arrive (someone else took them) is written off after ARRIVE seconds.
function MR:Ledger(id)
	self.ledger = self.ledger or {}
	local l = self.ledger[id]
	if not l then l = { last = bagCount(id), entries = {}, surplus = 0, surplusToken = 0 }; self.ledger[id] = l end
	return l
end
function MR:Owed(id)
	local l = self.ledger and self.ledger[id]
	if not l then return 0 end
	local owed = 0
	for _, e in ipairs(l.entries) do owed = owed + e.rem end
	return owed
end
-- Credit new arrivals of one item to what left the loot window, oldest first; the rest waits as surplus (an item
-- that arrived before its slot cleared).
local function credit(l, amount)
	while amount > 0 and l.entries[1] do
		local e = l.entries[1]
		local take = math.min(e.rem, amount)
		e.rem, amount = e.rem - take, amount - take
		if e.rem <= 0 then table.remove(l.entries, 1) end
	end
	if amount > 0 then
		-- (1.5.1-beta3, L5) held unassigned until a slot of this item clears and claims it; unclaimed after ARRIVE
		-- seconds, it stops counting
		l.surplus = l.surplus + amount
		l.surplusToken = l.surplusToken + 1
		local tok = l.surplusToken
		C_Timer.After(ARRIVE, function()
			if l.surplusToken == tok and l.surplus > 0 then
				l.surplus = 0
				ns:Debug("Loot Helper: arrivals no loot slot claimed stop counting; judging again")
				MR:AfterBags()
			end
		end)
	end
end
-- (1.5.1-beta3, L5) The loot slots that unclaimed arrivals could belong to, in slot order: such a slot isn't asked
-- for again and isn't counted in the fit check (its items may already be in the bags), until a slot's clear claims
-- the arrivals or they stop counting. Bag counts can't say which of two slots of the same item arrived, so no slot
-- is ever marked done on that basis.
function MR:Covered()
	local out, left = {}, {}
	for id, l in pairs(self.ledger or {}) do if l.surplus > 0 then left[id] = l.surplus end end
	if not next(left) then return out end
	for slot = 1, (GetNumLootItems and GetNumLootItems() or 0) do
		local link = GetLootSlotType and GetLootSlotType(slot) ~= 0 and GetLootSlotLink and GetLootSlotLink(slot)
		local id = link and tonumber(link:match("item:(%d+)"))
		local si = self.slotItem and self.slotItem[slot]
		local qty = (si and si.id == id and si.qty) or 1
		if id and left[id] and left[id] >= qty then out[slot] = true; left[id] = left[id] - qty end
	end
	return out
end
local function lootPresent()
	local c = 0
	for slot = 1, (GetNumLootItems and GetNumLootItems() or 0) do if GetLootSlotType and GetLootSlotType(slot) ~= 0 then c = c + 1 end end
	return c
end
local function bagSig(id)
	local t = {}
	for _, bag in ipairs(ns.BAGS) do
		if bag ~= ns.KEYRING then t[#t + 1] = tostring((C_Container.GetContainerNumFreeSlots(bag))) end
	end
	return table.concat(t, ",") .. ":" .. bagCount(id) .. ":" .. lootPresent()
end
-- A loot slot left the window: its quantity is owed (after any surplus that already arrived) until it arrives, or
-- written off after ARRIVE seconds.
function MR:LeftWindow(slot, id, qty)
	local l = self:Ledger(id)
	local e = { rem = qty or 1, slot = slot }
	local early = math.min(e.rem, l.surplus)
	e.rem, l.surplus = e.rem - early, l.surplus - early
	if e.rem <= 0 then return end
	l.entries[#l.entries + 1] = e
	C_Timer.After(ARRIVE, function()
		for i, x in ipairs(l.entries) do
			if x == e then
				table.remove(l.entries, i)
				ns:Debug("Loot Helper: %d from slot %d never reached the bags; judging again", e.rem, slot)
				MR:AfterBags()
				return
			end
		end
	end)
end
-- BagSmith's own request, made just before LootSlot (so it holds even for events the call fires at once).
function MR:Request(slot, id, qty)
	self.reqToken = (self.reqToken or 0) + 1
	local r = { slot = slot, id = id, qty = qty or 1, token = self.reqToken }
	self.request = r
	C_Timer.After(ARRIVE, function()
		if MR.request == r then
			MR.request = nil
			MR.refused = MR.refused or {}
			MR.refused[slot] = bagSig(id)
			ns:Debug("Loot Helper: no answer for slot %d; not asked again until your bags or the loot window change", slot)
			MR:AfterBags()
		end
	end)
end
function MR:Arriving()
	if self.request then return true end
	for id in pairs(self.ledger or {}) do if self:Owed(id) > 0 then return true end end
	return false
end
-- After a bag scan: new arrivals are credited (to slots that cleared, oldest first, the rest held unassigned).
function MR:CheckArrivals()
	for id, l in pairs(self.ledger or {}) do
		local now = bagCount(id)
		local d = now - l.last
		l.last = now
		if d > 0 then credit(l, d) end   -- (a decrease is items leaving the bags, nothing owed)
	end
	-- BagSmith's request may have arrived before its slot cleared: the request stops holding the next one, but the
	-- slot isn't marked done (another slot of the same item may be what arrived); its own clear will settle it.
	local r = self.request
	if r and self:Covered()[r.slot] then
		self.request = nil
		ns:Debug("Loot Helper: slot %d may have landed; waiting for a loot slot to clear", r.slot)
	end
end
function MR:QueueHas()
	for slot in pairs(self.pending) do
		if GetLootSlotType and GetLootSlotType(slot) ~= 0 then return true end
	end
	return false
end
function MR:TryLoot()
	if not (GetNumLootItems and GetNumLootItems() > 0) then return end
	local still = {}
	for _, w in ipairs(self:Waiting()) do if w.slot then still[w.slot] = true end end
	local slots = {}
	for slot in pairs(self.pending) do slots[#slots + 1] = slot end
	table.sort(slots)
	self.lootTried = self.lootTried or {}
	self.refused = self.refused or {}
	local now = GetTime()
	if self:Arriving() then return end   -- one at a time: the last request or arrival isn't settled yet
	local never = self:Never()
	local covered = self:Covered()
	local soonest
	for _, slot in ipairs(slots) do
		local present = GetLootSlotType and GetLootSlotType(slot) ~= 0
		local link = present and GetLootSlotLink and GetLootSlotLink(slot)
		local id = link and tonumber(link:match("item:(%d+)"))
		if not present or (id and (never[id] or self.skipped[slot .. ":" .. id])) then
			self.pending[slot] = nil   -- gone, skipped or never-asked: not ours to take
		elseif covered[slot] then
			-- (1.5.1-beta3) its items may already be in the bags: not asked for until a clear settles it
		elseif not id then
			-- (1.5.1-beta2, L2) an item BagSmith can't identify right now isn't requested: it stays queued
		elseif not still[slot] and LootSlot and self.refused[slot] ~= bagSig(id) then
			local wait = RETRY_LOOT - (now - (self.lootTried[slot] or -10))
			if wait > 0 then
				-- (1.5.2, the 1.5.1-beta3 audit's L6) eligible and fitting, held back only by the retry cooldown: look again
				-- once it ends (one recheck, not a stream: a newer one replaces it)
				soonest = math.min(soonest or wait, wait)
			else
				self.lootTried[slot] = now
				self.refused[slot] = nil
				local _, _, qty = GetLootSlotInfo(slot)
				self:Request(slot, id, qty)
				ns:Debug("Loot Helper: looting slot %d", slot)
				pcall(LootSlot, slot)
				return
			end
		end
	end
	if soonest then
		self.recheckToken = (self.recheckToken or 0) + 1
		local tok = self.recheckToken
		C_Timer.After(soonest + 0.05, function() if MR.recheckToken == tok then MR:AfterBags() end end)
	end
end

------------------------------------------------------------------------
-- The panel
------------------------------------------------------------------------
local ROW_H = 38
local PROTECT_W = 76
local MEDIA = "Interface\\AddOns\\BagSmith\\Media\\"
local function row(f, list, i, make)
	local r = list[i]
	if not r then r = make(); list[i] = r end
	r:Show()
	return r
end
local function qualityColor(q)
	local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end
-- One row (1.3.0): a selection dot on rows you can choose (the space is kept on the waiting rows so the icons
-- line up), the item's icon with its count on it, the name in its quality color, a value line beneath, and on
-- waiting rows their own small buttons at the right.
local COST_W = 70
local function makeItemRow(parent, opts)
	opts = opts or {}
	local buttons = opts.buttons or {}
	local r = CreateFrame("Button", nil, parent)
	r:SetSize(W - 12, ROW_H)
	r:EnableMouse(true)
	r:SetScript("OnEnter", function(self)
		if not (self.tipFn and ns.TooltipsOK()) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		self.tipFn(GameTooltip)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	r.choosable = opts.choosable and true or false
	if r.choosable then r:SetScript("OnClick", function(self) if self.onPick then self.onPick() end end) end
	r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 1, 1, 0.07); r.hl:Hide()
	r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetSize(12, 12); r.dot:SetPoint("LEFT", 6, 0)
	r.dot:SetTexture("Interface\\Buttons\\UI-RadioButton"); r.dot:SetTexCoord(0, 0.25, 0, 1)
	r.dotFill = r:CreateTexture(nil, "OVERLAY"); r.dotFill:SetSize(12, 12); r.dotFill:SetPoint("LEFT", 6, 0)
	r.dotFill:SetTexture("Interface\\Buttons\\UI-RadioButton"); r.dotFill:SetTexCoord(0.25, 0.5, 0, 1); r.dotFill:Hide()
	r.dot:SetShown(r.choosable)
	r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(28, 28); r.icon:SetPoint("LEFT", 26, 0)
	r.count = r:CreateFontString(nil, "OVERLAY", "NumberFontNormal"); r.count:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", -1, 1)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
	r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
	r.value = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.value:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 1)
	r.value:SetJustifyH("LEFT"); r.value:SetWordWrap(false)
	r.btns = {}
	local prev, used = nil, 0
	-- (1.7.0-beta10) a cost column on the right: "Free", "Junk 3c", "8c"
	if opts.cost then
		r.cost = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.cost:SetPoint("RIGHT", -8, 0); r.cost:SetJustifyH("RIGHT")
		used = COST_W
	end
	for i = #buttons, 1, -1 do
		local b = ns.TextButton(r, buttons[i][1], buttons[i][2], function(btn) btn.onClick(btn) end)
		b:SetHeight(20)
		if prev then b:SetPoint("RIGHT", prev, "LEFT", -4, 0) else b:SetPoint("RIGHT", -6, 0) end
		prev = b
		used = used + buttons[i][2] + 4
		r.btns[i] = b
	end
	-- the name and value get the room left of the buttons (the full name is in the item's tooltip)
	r.btnUsed = used
	local textW = (W - 12) - 62 - used - 8
	r.name:SetWidth(textW); r.value:SetWidth(textW)
	return r
end
-- (1.7.0-beta3) a row at another width (the "let go" list, narrower while its scrollbar shows)
local function fitRow(r, w)
	if r.fitW == w then return end
	r.fitW = w
	r:SetWidth(w)
	local textW = w - 62 - (r.btnUsed or 0) - 8
	r.name:SetWidth(textW); r.value:SetWidth(textW)
end
-- A frame anchored to another frame leaps when it's dragged: put it on the screen at its own spot first.
function MR.ToScreen(f)
	if not (f and f.GetLeft and f.GetTop) then return end
	local left, top = f:GetLeft(), f:GetTop()
	if not (left and top) then return end
	local w, h = f:GetWidth(), f:GetHeight()
	local fs, us = f.GetEffectiveScale and f:GetEffectiveScale() or 1, UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
	if fs ~= us and us > 0 then local k = fs / us; left, top = left * k, top * k end
	f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top); f:SetSize(w, h)
end
local function hrule(f) local t = f:CreateTexture(nil, "ARTWORK"); t:SetHeight(1); t:SetColorTexture(1, 1, 1, 0.12); t:Hide(); return t end
local function line(f) local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); t:SetJustifyH("LEFT"); t:Hide(); return t end
function MR:Frame()
	local f = self.frame
	if f then return f end
	f = CreateFrame("Frame", "BagSmithMakeRoom", UIParent, "BackdropTemplate")
	f:SetSize(W, 200); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true)
	if f.SetToplevel then f:SetToplevel(true) end   -- above the bags window, and forward when clicked
	-- Drag to move; the spot is remembered (beside the loot window until then).
	f:SetMovable(true); f:RegisterForDrag("LeftButton")
	-- (1.7.0-beta2) not while Lock Windows is on
	f:SetScript("OnDragStart", function(self) if ns:WindowsLocked() then return end; self.bsDragging = true; MR.ToScreen(self); self:StartMoving() end)
	f:SetScript("OnDragStop", function(self)
		if ns:WindowsLocked() and not self.bsDragging then return end   -- (locked: it never started, so no spot to save)
		self.bsDragging = nil
		self:StopMovingOrSizing()
		local point, _, rel, x, yy = self:GetPoint(1)
		if point then ns.db.makeRoomPos = { point, "UIParent", rel or point, math.floor(x + 0.5), math.floor(yy + 0.5) } end
	end)
	f.closeX = ns.IconButton(f, MEDIA .. "ui-close.tga", "Close", function() f:Hide() end)
	f.closeX:SetSize(18, 18); f.closeX:SetPoint("TOPRIGHT", -10, -10)
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", 12, -12)
	f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
	f.sub:SetWidth(W - 24); f.sub:SetJustifyH("LEFT"); f.sub:SetWordWrap(true)
	f.heads = {}
	f.waitRows, f.combineRows, f.destroyRows = {}, {}, {}
	f.note = line(f); f.note:SetWidth(W - 24); f.note:SetWordWrap(true)
	f.excl = line(f); f.exclInfo = ns.Why.InfoButton(f); f.exclInfo:Hide()
	f.held = line(f); f.heldInfo = ns.Why.InfoButton(f); f.heldInfo:Hide()
	-- (1.7.0-beta3, Shweep) the "let go" rows scroll: VISIBLE_ROWS at a time, every candidate listed
	f.letGo = CreateFrame("ScrollFrame", "BagSmithMakeRoomLetGo", f, "UIPanelScrollFrameTemplate")
	f.letGo.scrollBarHideable = true
	f.letGo.child = CreateFrame("Frame", nil, f.letGo); f.letGo.child:SetSize(W - 12, 1); f.letGo:SetScrollChild(f.letGo.child)
	f.letGo:Hide()
	-- (1.7.0-beta3) the footer's (i): how the list is ordered
	f.footInfo = ns.Why.InfoButton(f); f.footInfo:Hide()
	f.rule1, f.rule2 = hrule(f), hrule(f)
	-- Clean Up Bags is a way to free a slot like the others: a row you can choose.
	-- (1.7.0-beta10) in the one list of ways to make room, with a cost column
	f.cleanup = makeItemRow(f.letGo.child, { choosable = true, cost = true }); f.cleanup:Hide()
	f.cleanup.icon:SetTexture(MEDIA .. "ui-broom.tga"); f.cleanup.name:SetText("Clean Up Bags")
	f.cleanup.tipFn = function(tip) ns.TipText(tip, "Clean Up Bags", 1, 1, 1); ns.TipLine(tip, "Blizzard's Clean Up Bags merges partial stacks, which can free a slot or two.", 0.9, 0.9, 0.9, true) end
	-- The one action, for the row you've chosen.
	f.act = ns.TextButton(f, "", W - 24, function(btn) if MR.actRun then MR.actRun(btn) end end); f.act:SetHeight(24); f.act:Hide()
	-- (1.7.0-beta10, Shweep: Protect "a secondary choice to the destroy button") beside it, for the chosen item to let go
	f.protect = ns.TextButton(f, "Protect", PROTECT_W, function() if MR.protectRun then MR.protectRun() end end); f.protect:SetHeight(24); f.protect:Hide()
	f.protect:SetSecondary(true)   -- 1.7.0-beta11: gray in both skins, a second choice beside the main button
	f.protect.tip = "Don't suggest again"
	f.protect.tipSub = "The Loot Helper won't offer this item again. Settings > Loot Helper lists what you've protected."
	f.foot = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.foot:SetJustifyH("CENTER"); f.foot:SetWordWrap(false); f.foot:Hide()
	-- Soul Shards row
	f.shard = CreateFrame("Frame", nil, f); f.shard:SetSize(W - 24, 24)
	f.shard.text = f.shard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.shard.text:SetPoint("TOPLEFT", 0, 0)
	f.shard.text:SetWidth(W - 24); f.shard.text:SetJustifyH("LEFT")
	f.shard.minus = ns.IconButton(f.shard, MEDIA .. "ui-minus.tga", "Fewer", function() MR.shardQty = math.max(1, (MR.shardQty or 1) - 1); MR:Paint() end)
	f.shard.minus:SetSize(20, 20); f.shard.minus:SetPoint("TOPLEFT", 0, -16)
	f.shard.qty = f.shard:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); f.shard.qty:SetPoint("LEFT", f.shard.minus, "RIGHT", 6, 0)
	f.shard.plus = ns.IconButton(f.shard, MEDIA .. "ui-plus.tga", "More", function() local _, can = MR:Shards(); MR.shardQty = math.min(can, (MR.shardQty or 1) + 1); MR:Paint() end)
	f.shard.plus:SetSize(20, 20); f.shard.plus:SetPoint("LEFT", f.shard.qty, "RIGHT", 6, 0)
	f.shard.go = ns.TextButton(f.shard, "Destroy Shards", 150, function(b) MR:DestroyNextShard(b) end)
	f.shard.go:SetHeight(20); f.shard.go:SetPoint("LEFT", f.shard.plus, "RIGHT", 8, 0)
	f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.status:SetPoint("BOTTOMLEFT", 12, 12)
	f.status:SetWidth(W - 24); f.status:SetJustifyH("CENTER")
	-- When nothing can free a slot: the card, with BagSmith's mark.
	f.card = CreateFrame("Frame", nil, f); f.card:SetSize(W - 24, 150); f.card:Hide()
	f.card.mark = f.card:CreateTexture(nil, "ARTWORK"); f.card.mark:SetSize(48, 48); f.card.mark:SetPoint("TOP", 0, -8); f.card.mark:SetTexture(MEDIA .. "mark128.tga")
	f.card.head = f.card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.card.head:SetPoint("TOP", f.card.mark, "BOTTOM", 0, -8); f.card.head:SetText("Nothing here frees a slot.")
	f.card.text = f.card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.card.text:SetPoint("TOP", f.card.head, "BOTTOM", 0, -6)
	f.card.text:SetWidth(W - 60); f.card.text:SetJustifyH("CENTER"); f.card.text:SetWordWrap(true)
	f.classicSpec = ns.Classic.DialogSpec(f, { hide = { f.closeX }, restore = function() ns.Skins:ApplyBackdrop(f); local s = ns.Skins:Current(); f:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1) end })
	ns.Skins:Register(f, function(fr)
		ns.Skins:ApplyBackdrop(fr); local s = ns.Skins:Current(); fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)
		fr.title:SetTextColor(unpack(s.heading)); fr.sub:SetTextColor(unpack(s.text)); fr.status:SetTextColor(unpack(s.muted))
		for _, t in ipairs({ fr.note, fr.excl, fr.held, fr.foot, fr.card.text }) do t:SetTextColor(unpack(s.muted)) end
		if ns.Classic.DressScrollBar then ns.Classic:DressScrollBar(fr.letGo, ns.Classic.IsOn()) end
		fr.card.head:SetTextColor(unpack(s.heading))
		do local ar, ag, ab = ns.Skins:Accent(); fr.card.mark:SetVertexColor(ar, ag, ab) end
		ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
	end)
	f:SetScript("OnHide", function()
		MR.shardBatch = nil
		-- Its destroy confirmations close with it.
		local c = ns.Popups and ns.Popups.confirm
		if c and c:IsShown() and c.lootHelper then c:Hide() end
	end)
	f:Hide()
	ns:CloseOnEscape(f, function() f:Hide() end)   -- (1.5.4) Escape closes it like its close button
	ns:CombatWindow(f)   -- (1.5.6) fades in combat like the bags window
	self.frame = f
	return f
end

local function head(f, i, text, y)
	local h = f.heads[i]
	if not h then h = f:CreateFontString(nil, "OVERLAY", "GameFontNormal"); f.heads[i] = h end
	-- left-justified (1.7.0-beta11): a heading given a width (the target's, so a long name truncates) would otherwise
	-- center its text, and the (i) placed after the text's width would sit over it
	h:SetJustifyH("LEFT")
	h:SetText(text); h:ClearAllPoints(); h:SetPoint("TOPLEFT", 12, -y); h:Show()
	h:SetTextColor(unpack(ns.Skins:Current().heading))
	return y + 18
end
local function placeRule(f, t, y)
	t:ClearAllPoints(); t:SetPoint("TOPLEFT", 12, -y); t:SetPoint("TOPRIGHT", -12, -y); t:Show()
end
-- Loot on the Loot Exclusion List stays in the loot window: its names, for the quiet line under the waiting rows.
function MR:ExcludedLoot()
	local out, never = {}, self:Never()
	local n = (GetNumLootItems and GetNumLootItems()) or 0
	for slot = 1, n do
		local link = GetLootSlotLink and GetLootSlotLink(slot)
		local id = link and tonumber(link:match("item:(%d+)"))
		if id and never[id] then out[#out + 1] = link:match("%[(.-)%]") or ("item " .. id) end
	end
	return out
end

function MR:Paint()
	local f = self:Frame()
	local s = ns.Skins:Current()
	for _, h in ipairs(f.heads) do h:Hide() end
	for _, list in ipairs({ f.waitRows, f.combineRows, f.destroyRows }) do for _, r in ipairs(list) do r:Hide() end end
	for _, w in ipairs({ f.cleanup, f.shard, f.note, f.excl, f.exclInfo, f.held, f.heldInfo, f.letGo, f.footInfo, f.rule1, f.rule2, f.act, f.protect, f.foot, f.card }) do w:Hide() end
	local shardsOnly = self.mode == "shards"
	local waiting = shardsOnly and {} or self:Waiting()
	-- Add to the session's queue (never drop from it here: an item that now
	-- fits stays queued until it's actually looted).
	for _, w in ipairs(waiting) do if w.slot then self.pending[w.slot] = true end end
	local quest = self.mode == "quest"
	local n = #waiting
	if shardsOnly then
		f.title:SetText("Clear Soul Shards"); if ns.Classic then ns.Classic:RefreshTitle(f) end
		f.sub:SetText("Soul Shards in your ordinary bags. Shards in a soul bag are never touched.")
	elseif quest then
		-- Quest mode: BagSmith never completes or accepts for you.
		f.title:SetText("Loot Helper"); if ns.Classic then ns.Classic:RefreshTitle(f) end
		local q = self.quest or {}
		local click = q.kind == "accept" and "Accept" or "Complete Quest"
		-- The quest window may have closed (clicking Accept closes it at once).
		local how = q.closedAt and ("talk to the quest giver and click " .. click) or ("click " .. click)
		local from = q.title and q.title ~= "" and q.title or "this quest"
		if n > 0 then
			f.sub:SetText(("Your bags are full: %d %s from %s won't fit. Make room, then %s."):format(n, n == 1 and "item" or "items", from, how))
		else
			f.sub:SetText(("There's room now: %s."):format(how))
		end
	else
		f.title:SetText("Loot Helper"); if ns.Classic then ns.Classic:RefreshTitle(f) end
		f.sub:SetText(n > 0 and ("%d %s won't fit. Make room to finish looting."):format(n, n == 1 and "item" or "items")
			or "Everything fits now.")
	end
	local y, hi = 12 + (f.title:GetStringHeight() or 18) + 4 + (f.sub:GetStringHeight() or 14) + 12, 0
	if n > 0 then
		hi = hi + 1; y = head(f, hi, "Waiting to loot", y)
		-- (1.7.0-beta10, Shweep) the loot it's making room for is the highlighted row; click another to switch
		local target = self:Target(waiting)
		local ar, ag, ab = ns.Skins:Accent()
		for i, w in ipairs(waiting) do
			local r = row(f, f.waitRows, i, function() return makeItemRow(f, { buttons = { { "Skip", 46 }, { "Exclude", 62 } } }) end)
			r:ClearAllPoints(); r:SetPoint("TOPLEFT", 6, -y)
			r.icon:SetTexture(w.icon); r.count:SetText((w.qty or 1) > 1 and tostring(w.qty) or "")
			r.name:SetText(w.name); r.name:SetTextColor(qualityColor(w.quality))
			r.value:SetText(w.id and self:ValueText(w.values) or ""); r.value:SetTextColor(unpack(s.muted))
			local isTarget = w == target
			if not r.bar then
				r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetPoint("TOPLEFT", 0, -2); r.bar:SetPoint("BOTTOMLEFT", 0, 2); r.bar:SetWidth(3)
				r.bar:SetTexture("Interface\\Buttons\\WHITE8X8")
				r:SetScript("OnClick", function(self) if self.onTarget then self.onTarget() end end)
			end
			r.bar:SetVertexColor(ar, ag, ab, 1); r.bar:SetShown(isTarget); r.hl:SetShown(isTarget)
			r.isTarget = isTarget
			local key = self:TargetKey(w)
			r.onTarget = (n > 1 and not isTarget) and function() MR.target = key; MR.sel, MR.selPicked = nil, nil; MR:Paint() end or nil
			r.tipFn = function(tip)
				if w.slot and tip.SetLootItem then tip:SetLootItem(w.slot) elseif w.link then tip:SetHyperlink(w.link) else ns.TipText(tip, w.name) end
				if n > 1 and not isTarget then ns.TipLine(tip, "Click to make room for this instead.", 0.4, 0.8, 1, true) end
			end
			-- Skip and Exclude are about leaving loot behind: not for quests.
			r.btns[1]:SetShown(not quest); r.btns[2]:SetShown(not quest)
			if ns.Pawn then ns.Pawn:DecorateIcon(r, r.icon, ns.Pawn:IsUpgradeLink(w.link)) end
			r.btns[1].onClick = function() MR:Skip(w) end
			r.btns[1].tip = "Leave it in the loot window this time"
			r.btns[2].onClick = function() MR:NeverAsk(w) end
			r.btns[2].tip = "Add it to your Loot Exclusion List"
			y = y + ROW_H
		end
	end
	self:PaintSections(f, waiting, shardsOnly, y, hi)
end

function MR:PaintSections(f, waiting, shardsOnly, y, hi)
	local s = ns.Skins:Current()
	local quest = self.mode == "quest"
	-- (1.7.0-beta10, Shweep's layout) The loot it's making room for, the target: offers are judged against it alone.
	local target = (not shardsOnly) and self:Target(waiting) or nil
	local judge = target and { target } or waiting
	local combine, destroy, held, noPrice, pricier = {}, {}, nil, false, 0
	if not shardsOnly and #waiting > 0 then combine, destroy, held, noPrice, pricier = self:Suggestions(waiting, judge) end
	local cleanUp = not shardsOnly and #waiting > 0 and self:CleanUpHelps(#combine)
	self.offeredCleanUp = cleanUp
	-- Under the waiting rows: the target has no price (1.5.1), the target is worth less than anything else you could let
	-- go, and loot the Exclusion List leaves behind.
	if noPrice then
		f.note:ClearAllPoints(); f.note:SetPoint("TOPLEFT", 12, -(y + 2))
		-- (1.7.0-beta12, Shweep) a quest item will never have a price: "yet" would promise one
		f.note:SetText(target and target.id and (self:IsQuestItem(target)
				and ("%s is a quest item, so it has no price. These are simply your cheapest items."):format(target.name)
				or ("%s has no price yet, so these are simply your cheapest items."):format(target.name))
			or "There's no price to compare with, so these are simply your cheapest items.")
		f.note:Show()
		y = y + (f.note:GetStringHeight() or 12) + 4
	elseif target and target.id and not quest and (pricier or 0) > 0 then
		local priced = false
		for _, d in ipairs(destroy) do if not d.junk then priced = true end end
		if not priced then
			f.note:ClearAllPoints(); f.note:SetPoint("TOPLEFT", 12, -(y + 2))
			f.note:SetText(("%s is worth less than anything you'd let go."):format(target.name)); f.note:Show()
			y = y + (f.note:GetStringHeight() or 12) + 4
		end
	end
	if self.mode == "loot" and #waiting > 0 then
		local excluded = self:ExcludedLoot()
		if #excluded > 0 then
			f.excl:ClearAllPoints(); f.excl:SetPoint("TOPLEFT", 12, -(y + 2))
			f.excl:SetText(("%d excluded %s in the loot window"):format(#excluded, #excluded == 1 and "item stays" or "items stay")); f.excl:Show()
			f.exclInfo:ClearAllPoints(); f.exclInfo:SetPoint("LEFT", f.excl, "LEFT", (f.excl:GetStringWidth() or 150) + 4, 0)
			f.exclInfo.title = "Left in the loot window"; f.exclInfo.lines = { ns.Why:Line("lootExcluded", excluded) }; f.exclInfo:Show()
			y = y + 16
		end
	end
	local options = {}
	if #waiting > 0 then placeRule(f, f.rule1, y + 6); y = y + 14 end
	local heldN = held and held.total or 0
	-- (1.7.0-beta10) One list of the ways to make room for the target: free ways first (combining stacks, Clean Up Bags),
	-- then items to let go, least missed first; the cost on the right. One choice, one button.
	local n = shardsOnly and 0 or (#combine + (cleanUp and 1 or 0) + #destroy)
	if n > 0 then
		hi = hi + 1; y = head(f, hi, ("To make room for %s"):format(target and target.name or "this loot"), y)
		local h = f.heads[hi]
		h:SetWidth(W - 24 - 22); h:SetWordWrap(false)
		f.footInfo.title = "How it decides"
		f.footInfo.lines = MR:HowItDecides()
		f.footInfo:ClearAllPoints(); f.footInfo:SetPoint("LEFT", h, "LEFT", math.min(h:GetStringWidth() or 160, W - 24 - 22) + 4, 0)
		f.footInfo:Show()
		-- the rows sit in a scrolling list (1.7.0-beta3): VISIBLE_ROWS tall at most, narrower while its scrollbar shows;
		-- the scroll position is kept as the list repaints (clamped when it gets shorter)
		local list = f.letGo
		local scrolling = n > VISIBLE_ROWS
		local rowW = (W - 12) - (scrolling and SCROLLBAR_W or 0)
		local viewH = math.min(n, VISIBLE_ROWS) * ROW_H
		list:ClearAllPoints(); list:SetPoint("TOPLEFT", 6, -y); list:SetSize(rowW, math.max(1, viewH))
		list.child:SetSize(rowW, math.max(1, n * ROW_H))
		if list.ScrollBar then list.ScrollBar:SetShown(scrolling) end
		list:Show()
		local at = 0
		local function place(r)
			fitRow(r, rowW)
			r:ClearAllPoints(); r:SetPoint("TOPLEFT", list.child, "TOPLEFT", 0, -at * ROW_H)
			at = at + 1
		end
		for i, c in ipairs(combine) do
			local r = row(f, f.combineRows, i, function() return makeItemRow(list.child, { choosable = true, cost = true }) end)
			place(r)
			r.icon:SetTexture(c.src.icon); r.count:SetText("")
			r.name:SetText(c.name); r.name:SetTextColor(qualityColor(c.src.quality))
			r.value:SetText("Combine 2 stacks into 1. Frees 1 slot."); r.value:SetTextColor(unpack(s.muted))
			r.cost:SetText("Free"); r.cost:SetTextColor(unpack(s.text))
			r.tipFn = function(tip) tip:SetBagItem(c.src.bag, c.src.slot) end
			if ns.Pawn then ns.Pawn:DecorateIcon(r, r.icon, ns.Pawn:IsUpgrade(c.src)) end
			options[#options + 1] = { key = ("c:%d:%d"):format(c.src.bag, c.src.slot), row = r, accent = true, label = "Combine " .. (c.name or "Stacks"),
				tip = "Pours the smaller stack into the larger one", run = function() MR:Combine(c) end }
		end
		if cleanUp then
			local r = f.cleanup
			place(r); r:Show()
			r.name:SetTextColor(unpack(s.text)); r.value:SetText("Sort and stack everything. Can free a slot or two."); r.value:SetTextColor(unpack(s.muted))
			r.cost:SetText("Free"); r.cost:SetTextColor(unpack(s.text))
			options[#options + 1] = { key = "cleanup", row = r, accent = true, label = "Clean Up Bags", tip = "Blizzard's Clean Up Bags merges partial stacks", run = function() MR:CleanUp() end }
		end
		for i, d in ipairs(destroy) do
			local r = row(f, f.destroyRows, i, function() return makeItemRow(list.child, { choosable = true, cost = true }) end)
			place(r)
			local rec = d.rec
			r.icon:SetTexture(rec.icon); r.count:SetText((rec.count or 1) > 1 and tostring(rec.count) or "")
			r.name:SetText(rec.name or "?"); r.name:SetTextColor(qualityColor(rec.quality))
			r.value:SetText(self:ValueText(d.values)); r.value:SetTextColor(unpack(s.muted))
			r.cost:SetText((d.junk and "Junk  " or "") .. ((d.rank or 0) > 0 and money(d.rank) or "-")); r.cost:SetTextColor(unpack(s.text))
			r.tipFn = function(tip) tip:SetBagItem(rec.bag, rec.slot) end
			if ns.Pawn then ns.Pawn:DecorateIcon(r, r.icon, ns.Pawn:IsUpgrade(rec)) end
			-- The offer is this exact item and count; it's checked again at the moment of destroying.
			-- (1.5.1-beta2) the offer and its row's key carry why it's offered, so a change of reason closes an open question
			local basis = d.junk and "junk" or (d.noPrice and "noprice" or "priced")
			local offer = MR:Offer(rec, d.junk, basis, (not d.junk) and MR:Rank(d.values) or nil)
			local key = ("d:%d:%d:%d:%s"):format(rec.bag, rec.slot, rec.itemID, basis)
			local ask = MR:AsksFirst(rec, d.junk)   -- for the button's words; the click decides afresh (1.5.1-beta3)
			local what = (rec.name or "this item") .. ((rec.count or 1) > 1 and (" x" .. rec.count) or "")
			options[#options + 1] = { key = key, row = r, accent = false, label = "Destroy " .. what, protect = rec.itemID,
				tip = d.junk and "Junk: destroyed in one click" or (ask and "Asks before destroying" or "Destroyed at once"),
				run = function(btn) MR:TryDestroy(offer, btn, what, d.values.vendor, key, ask) end }
		end
		list:SetVerticalScroll(math.max(0, math.min(list:GetVerticalScroll() or 0, n * ROW_H - viewH)))
		y = y + viewH
		if heldN > 0 then
			f.held:ClearAllPoints(); f.held:SetPoint("TOPLEFT", 12, -(y + 4))
			f.held:SetText(("%d protected %s offered"):format(heldN, heldN == 1 and "item isn't" or "items aren't")); f.held:Show()
			f.heldInfo:ClearAllPoints(); f.heldInfo:SetPoint("LEFT", f.held, "LEFT", (f.held:GetStringWidth() or 150) + 4, 0)
			f.heldInfo.title = "Kept out of these suggestions"; f.heldInfo.lines = ns.Why:Lines(held); f.heldInfo:Show()
			y = y + 18
		end
	end
	-- Nothing can free a slot: say why, plainly.
	local shards, can = self:Shards()
	local shardRow = self:IsWarlock() and can > 0
	if self.mode == "loot" and #waiting > 0 and #options == 0 and not shardRow then
		f.card:ClearAllPoints(); f.card:SetPoint("TOPLEFT", 12, -(y + 4))
		-- (1.5.1) and the bags this loot can't go in, whose free slots and items can't make room for it
		local cant = self:BagsLootCantUse(judge)
		f.card.text:SetText((heldN > 0 and ("Everything left is protected: %s. "):format(ns.Why:Phrase(held)) or "")
			.. (cant and ("This loot can't go in your %s. "):format(cant) or "")
			.. "Take what fits from the loot window, or make room by hand."
			-- (1.7.0-beta10) nothing frees a slot for this one; another waiting item may have a way
			.. (#waiting > 1 and " Or click another waiting item to make room for it instead." or ""))
		local ch = math.max(150, 8 + 48 + 8 + (f.card.head:GetStringHeight() or 18) + 6 + (f.card.text:GetStringHeight() or 36) + 12)
		f.card:SetHeight(ch)
		f.card:Show()
		y = y + 4 + ch
	end
	-- An open destroy confirmation whose item is no longer offered (the loot that justified it is gone) closes.
	do
		local c = ns.Popups and ns.Popups.confirm
		if c and c:IsShown() and c.lootHelper and c.lootHelperKey then
			local still = false
			for _, o in ipairs(options) do if o.key == c.lootHelperKey then still = true end end
			if not still then c:Hide() end
		end
	end
	-- The one action, for the chosen row; Protect beside it when that's an item to let go (1.7.0-beta10).
	if #options > 0 then
		-- (1.6.0-beta7, the beta6 audit's R1) The default is always the first option, the cheapest as ranked now: it follows
		-- every repaint. A row the player picked stays chosen while it's offered, until what the ranking follows changes
		-- (Rank Suggestions By, or the price source in use), by whatever route: a setting, a profile, a price addon.
		local basis = (ns.db.makeRoomValue or "ah") .. "|" .. tostring(ns.AH and ns.AH:Source())
		if self.rankBasis ~= basis then self.rankBasis = basis; self.sel, self.selPicked = nil, nil end
		local chosen
		if self.selPicked then for _, o in ipairs(options) do if o.key == self.sel then chosen = o end end end
		if not chosen then self.selPicked = nil end
		chosen = chosen or options[1]
		self.sel = chosen.key
		for _, o in ipairs(options) do
			local on = o == chosen
			o.row.hl:SetShown(on); o.row.dotFill:SetShown(on)
			o.row.onPick = function() MR.sel = o.key; MR.selPicked = true; MR:Paint() end
		end
		placeRule(f, f.rule2, y + 6); y = y + 14
		local withProtect = chosen.protect ~= nil
		local actW = (W - 24) - (withProtect and (PROTECT_W + 6) or 0)
		f.act:ClearAllPoints(); f.act:SetPoint("TOPLEFT", 12, -y); f.act:SetWidth(actW)
		f.act.label:SetText(chosen.label); f.act.tip = chosen.tip
		if f.act.SetActive then f.act:SetActive(chosen.accent) end
		MR.actRun = chosen.run
		f.act:Show()
		if withProtect then
			local id = chosen.protect
			f.protect:ClearAllPoints(); f.protect:SetPoint("TOPLEFT", 12 + actW + 6, -y); f.protect:Show()
			MR.protectRun = function() MR:Protect(id) end
		else
			MR.protectRun = nil
		end
		y = y + 24 + 8
		self.chosen = chosen
	else
		-- (1.6.0-beta8, the beta7 audit's A1) nothing offered: a pick ends, as when its own row goes, so the list starts
		-- from the cheapest when items come back
		MR.actRun, MR.protectRun = nil, nil; self.chosen = nil
		self.sel, self.selPicked = nil, nil
	end
	-- The footer: what happens next (1.7.0-beta10), or a status line when there is one.
	local st = f.status:GetText()
	local hasStatus = st ~= nil and st ~= ""
	f.status:ClearAllPoints(); f.status:SetPoint("TOPLEFT", 12, -y); f.status:SetPoint("TOPRIGHT", -12, -y)
	if not shardsOnly and #options > 0 and target then
		f.foot:ClearAllPoints(); f.foot:SetPoint("TOPLEFT", 12, -y); f.foot:SetPoint("TOPRIGHT", -12, -y)
		f.foot:SetJustifyH("LEFT")
		f.foot:SetText((quest and "Then there's room for %s." or "Then %s goes in your bags."):format(target.name))
		f.foot:SetShown(not hasStatus)
		y = y + 16
	elseif hasStatus then y = y + 16 end
	-- Soul Shards (warlocks with shards in ordinary bags, above the minimum), below the list and its button.
	if shardRow then
		if not shardsOnly then hi = hi + 1; y = head(f, hi, "Soul Shards", y + 6) end
		self.shardQty = math.max(1, math.min(self.shardQty or math.max(1, #waiting), can))
		f.shard:ClearAllPoints(); f.shard:SetPoint("TOPLEFT", 12, -y); f.shard:Show()
		local keep = ns.db.shardKeep or 0
		f.shard.text:SetText(("%d in ordinary bags%s"):format(#shards, keep > 0 and (" (keeping at least " .. keep .. ")") or ""))
		f.shard.qty:SetText(tostring(self.shardQty))
		f.shard.go.label:SetText(self.shardBatch and ("Destroy Next Shard (%d left)"):format(self.shardBatch) or "Destroy Shards")
		y = y + 42
	elseif shardsOnly then
		f.sub:SetText("No Soul Shards to clear in your ordinary bags" .. ((ns.db.shardKeep or 0) > 0 and " beyond the ones you keep." or "."))
	end
	f:SetHeight(y + 10)
end

function MR:Show(mode)
	self.mode = mode or "loot"
	if self.mode == "loot" then self.lootActive = true end
	local f = self:Frame()
	f.status:SetText("")
	self:Paint()
	f:ClearAllPoints()
	local pos = ns.db.makeRoomPos
	if type(pos) == "table" and pos[1] then f:SetPoint(pos[1], UIParent, pos[3] or pos[1], pos[4] or 0, pos[5] or 0)
	elseif self.mode == "loot" and LootFrame and LootFrame:IsShown() and LootFrame.GetRight and LootFrame:GetRight() and LootFrame.GetTop and LootFrame:GetTop() then
		-- beside the loot window, anchored to the screen (a frame anchored to another frame leaps when dragged)
		local k = (LootFrame.GetEffectiveScale and LootFrame:GetEffectiveScale() or 1) / (f.GetEffectiveScale and f:GetEffectiveScale() or 1)
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", LootFrame:GetRight() * k + 8, LootFrame:GetTop() * k)
	else f:SetPoint("CENTER", UIParent, "CENTER", 200, 0) end
	if f.Raise then f:Raise() end
	f:Show()
end
function MR:Refresh()
	local f = self.frame
	if not (f and f:IsShown()) then return end
	-- Loot: close once everything fits, but never between a loot slot
	-- clearing and the bags updating (the slot it will take still looks free).
	if self.mode == "loot" and not self.settling and not self:Arriving() and #self:Waiting() == 0 then
		if self:QueueHas() then self:TryLoot()   -- it all fits now: take what's queued
		else f:Hide(); return end
	end
	self:Paint()
end
-- After the bags change: take the next item that fits, repaint, or bring the
-- panel back if something still won't fit (loot window still open).
function MR:AfterBags()
	local f = self.frame
	if self.mode == "quest" then if f and f:IsShown() then self:Refresh() end return end
	if not (GetNumLootItems and GetNumLootItems() > 0) then
		-- Everything's been taken: close.
		if f and f:IsShown() and self.mode == "loot" and not self.settling and not self:Arriving() then self:Refresh() end
		return
	end
	if f and f:IsShown() and self.mode == "loot" then
		self:TryLoot(); self:Refresh()
	elseif self.lootActive and ns.db.makeRoom then
		self.mode = "loot"
		if #self:Waiting() > 0 then self:Show("loot") end
	end
end
function MR:ShowShards() self:Show("shards") end

-- When loot opens (or the game says your bags are full): does anything not fit?
function MR:Check()
	if not (ns.db and ns.db.makeRoom) then return end
	self.mode = "loot"
	if #self:Waiting() > 0 then self:Show("loot") end
end

function MR:Install()
	if self.installed then return end
	self.installed = true
	-- Destroy offers belong to the loot or quest they were made for: a new
	-- window (or the old one closing) ends them, and closes their confirmation.
	local function newOffers()
		MR.offerToken = (MR.offerToken or 0) + 1
		MR.sel, MR.selPicked = nil, nil   -- (1.6.0-beta8, A1) a new loot window starts from the cheapest
		MR.target = nil   -- (1.7.0-beta10) and makes room for the most valuable item again
		local c = ns.Popups and ns.Popups.confirm
		if c and c:IsShown() and c.lootHelper then c:Hide() end
	end
	MR.NewOffers = newOffers
	ns:On("LOOT_OPENED", function()
		newOffers()
		MR.session = (MR.session or 0) + 1
		MR.skipped, MR.pending, MR.lootTried, MR.lootActive = {}, {}, {}, false
		MR.ledger, MR.request, MR.refused, MR.slotItem = {}, nil, {}, {}
		local token = MR.session
		C_Timer.After(0.1, function() if MR.session == token then MR:Check() end end)
	end)
	-- A loot slot clearing: the item is on its way to the bags. Wait for them
	-- (or a moment) before judging what fits.
	ns:On("LOOT_SLOT_CLEARED", function(slot)
		if slot then MR.pending[slot] = nil end
		if MR.mode ~= "loot" then return end
		-- (1.5.1, beta2 accounting) its items have left the loot window: owed until they arrive (an item BagSmith
		-- asked for, or one looted by hand that the loot window showed)
		local r = MR.request
		local known = slot and MR.slotItem and MR.slotItem[slot]
		if r and r.slot == slot then
			MR.request = nil
			MR:LeftWindow(slot, r.id, r.qty)
			if MR.slotItem then MR.slotItem[slot] = nil end
			MR:AfterBags()
			return
		elseif known then
			MR:LeftWindow(slot, known.id, known.qty)
			MR.slotItem[slot] = nil
			MR:AfterBags()
			return
		end
		MR.settling = true
		MR.settleToken = (MR.settleToken or 0) + 1
		local token = MR.settleToken
		C_Timer.After(SETTLE, function() if MR.settling and MR.settleToken == token then MR.settling = false; MR:AfterBags() end end)
	end)
	ns:On("LOOT_CLOSED", function()
		newOffers()
		MR.lootActive, MR.settling = false, false
		MR.ledger, MR.request, MR.refused = {}, nil, {}
		local f = MR.frame
		if f and f:IsShown() and MR.mode == "loot" then
			if next(MR.pending) then f.status:SetText("The loot window closed. Loot again to pick up the rest.") end
			local token = MR.session
			C_Timer.After(4, function()
				-- Only if no newer loot window has opened since.
				if MR.session == token and MR.mode == "loot" and not (GetNumLootItems and GetNumLootItems() > 0) then f:Hide() end
			end)
		end
		MR.pending = {}
	end)
	-- Quests: the accept screen (an item handed to you) and the turn-in screen
	-- (rewards). Remembered when the window opens, and for a few seconds after
	-- it closes: clicking Accept closes the window at once, and the server's
	-- "Inventory is full" arrives a moment later.
	local function title() return (GetTitleText and GetTitleText()) or "" end
	ns:On("QUEST_DETAIL", function() newOffers(); MR.quest = { kind = "accept", title = title() } end)
	ns:On("QUEST_COMPLETE", function() newOffers(); MR.quest = { kind = "complete", title = title(), rewards = readRewards() } end)
	ns:On("QUEST_FINISHED", function() if MR.quest then MR.quest.closedAt = GetTime() end end)
	local function questDone()
		if MR.mode == "quest" and MR.frame then MR.frame:Hide() end
		MR.quest = nil
	end
	ns:On("QUEST_ACCEPTED", questDone)
	ns:On("QUEST_TURNED_IN", questDone)
	local function questFull(failedTitle)
		local q = MR.quest
		local recent = q and (not q.closedAt or GetTime() - q.closedAt <= QUEST_GRACE)
		if not recent then
			if not failedTitle then return end
			-- Only the game's "<quest> failed: Inventory is full." to go on.
			MR.quest = { kind = "accept", title = failedTitle, closedAt = GetTime() }
		end
		ns:Debug("Loot Helper (quest %s, %s): %d reward items remembered", MR.quest.kind, tostring(MR.quest.title), #(MR.quest.rewards or {}))
		MR:Show("quest")
	end
	MR.QuestFull = questFull
	ns:On("UI_ERROR_MESSAGE", function(id, msg)
		local full = (ERR_INV_FULL and msg == ERR_INV_FULL) or (LE_GAME_ERR_INV_FULL and id == LE_GAME_ERR_INV_FULL)
		if not full or not (ns.db and ns.db.makeRoom) then return end
		-- (1.5.1) the game refused an item BagSmith just asked for: not asked for again until the bags or the loot
		-- window change
		local r = MR.request
		if r then
			MR.request = nil
			MR.refused = MR.refused or {}
			MR.refused[r.slot] = bagSig(r.id)
			ns:Debug("Loot Helper: the game refused slot %d (bags full); waiting for the bags to change", r.slot)
		end
		if GetNumLootItems and GetNumLootItems() > 0 then MR:Check() else questFull(nil) end
	end)
	-- The game's own line, "Report to Goldshire failed: Inventory is full."
	local failPattern, failFrom
	local function pattern()
		local fmt = ERR_QUEST_FAILED_BAG_FULL_S
		if type(fmt) ~= "string" then return nil end
		if fmt ~= failFrom then
			local escaped = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
			failPattern, failFrom = "^" .. escaped:gsub("%%s", "(.+)") .. "$", fmt
		end
		return failPattern
	end
	ns:On("CHAT_MSG_SYSTEM", function(msg)
		local failPattern = pattern()
		if not (failPattern and ns.db and ns.db.makeRoom and type(msg) == "string") then return end
		local t = msg:match(failPattern)
		if t and not (MR.frame and MR.frame:IsShown() and MR.mode == "quest") then questFull(t) end
	end)
	-- (1.7.0-beta5, F2) a quest turned in or abandoned leaves the remembered readings
	ns:On("QUEST_TURNED_IN", function(questID) MR:ForgetQuest(questID) end)
	ns:On("QUEST_REMOVED", function(questID) MR:ForgetQuest(questID) end)
	-- (1.7.0-beta3) the materials your recipes use, learned whenever a profession window opens or changes
	local function learn(fn) ns:NextFrame("mr:" .. fn, function() pcall(MR[fn], MR) end) end
	ns:On("TRADE_SKILL_SHOW", function() learn("LearnTradeSkill") end)
	ns:On("TRADE_SKILL_UPDATE", function() learn("LearnTradeSkill") end)
	ns:On("CRAFT_SHOW", function() learn("LearnCraft") end)
	ns:On("CRAFT_UPDATE", function() learn("LearnCraft") end)
	-- Item names arriving from the game: the Loot Exclusion List window shows them.
	ns:On("GET_ITEM_INFO_RECEIVED", function()
		if MR.neverFrame and MR.neverFrame:IsShown() then MR:RefreshNeverWindow() end
		if MR.protectFrame and MR.protectFrame:IsShown() then MR:RefreshProtectedWindow() end
		-- (1.5.1) the panel too: a price or a bag rule may only now be known (once per moment, however many arrive)
		if MR.frame and MR.frame:IsShown() and not MR.infoQueued then
			MR.infoQueued = true
			C_Timer.After(0.1, function() MR.infoQueued = nil; if MR.frame:IsShown() then MR:Refresh() end end)
		end
	end)
	-- Bags changed (a combine, a clean up, a destroy, an item landing).
	ns:OnSignal("ITEMS_CHANGED", function() MR.settling = false; MR:CheckArrivals(); MR:AfterBags() end)
	-- (1.5.1-beta3, L3) a change to either destroy setting, or another profile, shows at once in the open panel; a shard
	-- batch started without a question ends when asking turns on (the next click asks)
	-- (1.6.0-beta6, the beta5 audit's F1) a different price source, or a different price to rank by: the open panel's values,
	-- order and chosen action are redone together from it, and an open question about an offer is closed (its offer was
	-- for the old values)
	local function repriced()
		MR.sel, MR.selPicked = nil, nil
		local c = ns.Popups and ns.Popups.confirm
		if c and c:IsShown() and c.lootHelper and c.lootHelperKey then c:Hide() end
		if MR.frame and MR.frame:IsShown() then MR:Refresh() end
	end
	ns:OnSignal("PRICE_SOURCE_CHANGED", repriced)
	ns:OnSignal("SETTINGS_CHANGED", function(key)
		if key == "makeRoomValue" then repriced(); return end
		if key ~= nil and key ~= "makeRoomAsk" and key ~= "makeRoomAskRare" then return end
		if MR.shardBatch and not MR.shardConfirmed and ns.db and ns.db.makeRoomAsk then MR.shardBatch = nil end
		if MR.frame and MR.frame:IsShown() then MR:Refresh() end
	end)
end
ns:OnSignal("ADDON_READY", function() MR:Install() end)
