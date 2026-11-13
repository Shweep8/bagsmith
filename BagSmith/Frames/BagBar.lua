--[[
	Frames/BagBar.lua

	The bag strip in the bags window, like the bank window's Bank Bags strip
	and in the same place (just under the toolbar): the backpack, the four bag
	slots and the reagent bag slot, after a narrow Keys slot (Forever has no
	keyring: hover lists your keys, click shows only them), in Blizzard's bag
	bar order (backpack at the far right). Hover a bag for its
	name and free slots;
	drag a bag on to equip or swap it,
	drag it off to take it out; click to open or close that bag's own window.
	(No highlight of the bag's items on hover for now, by Shweep's call.)
	A wide button left of the footer counts shows or hides the strip; the
	choice is remembered. It works in Travel Mode too (the strip sits under
	the title row there).

	Optional (Settings > General): hide Blizzard's own bag bar. It's faded out
	and made click-through rather than removed, so Edit Mode isn't disturbed
	and turning the setting off brings it back at once.
--]]
local ADDON, ns = ...
local BB = {}
ns.BagBar = BB

local SLOT = 34
local KEY_W = 18   -- the narrow Keys slot at the left, like the button's icon
-- The classic client's keyring button art (narrow and tall, made for this
-- spot), if Forever still has it; otherwise BagSmith's drawn vertical key.
local KEYRING_ART = "Interface\\Buttons\\UI-Button-KeyRing"
local KEYRING_COORDS = { 0, 0.5625, 0, 0.609375 }
local DRAWN_KEY = "Interface\\AddOns\\BagSmith\\Media\\ui-key.tga"
function BB:KeyArt()
	if BB.keyArt == nil then
		local id = type(GetFileIDFromPath) == "function" and GetFileIDFromPath(KEYRING_ART)
		BB.keyArt = (id and id ~= 0) and "blizzard" or "drawn"
	end
	return BB.keyArt
end
local EMPTY = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
BB.EMPTY = EMPTY   -- the empty bag slot picture (the bank strip uses it too, in Classic)
local BACKPACK = "Interface\\Buttons\\Button-Backpack-Up"

-- Blizzard's bag bar order, right to left from the backpack: the reagent bag
-- at the left, then bags 4 down to 1, the backpack at the far right.
local function bags()
	local reagent, normal = {}, {}
	for _, b in ipairs(ns.BAGS) do
		if b ~= ns.KEYRING then
			if ns:IsReagentBag(b) then reagent[#reagent + 1] = b else normal[#normal + 1] = b end
		end
	end
	table.sort(normal, function(a, b) return a > b end)
	for _, b in ipairs(normal) do reagent[#reagent + 1] = b end
	return reagent
end
local function invFor(bag)
	if bag == 0 then return nil end
	return C_Container.ContainerIDToInventoryID and C_Container.ContainerIDToInventoryID(bag) or nil
end
local function bagName(bag) return ns:BagName(bag) or ("Bag " .. bag) end

function BB:Open() return ns.db and ns.db.bagBar and true or false end   -- in Travel Mode too

-- Open or close one bag's own window (only that one, if none were open).
function BB:ToggleWindow(bag)
	if ns:IsReagentBag(bag) then
		local _, r = ns.SessionWindows(); ns.ui.reagentWindow = not r
	else
		local v = rawget(ns.Window.bagViews, bag)   -- (1.6.2-beta1) only looks: a window not built yet isn't open
		ns.ui.closedBags = ns.ui.closedBags or {}
		if v and v:IsShown() then
			ns:CloseBagWindow(bag, false)   -- the same as its X
		else
			local b = ns.SessionWindows()
			if not b then
				ns.ui.bagWindows = true
				for _, other in ipairs(ns.BAGS) do if other ~= bag then ns.ui.closedBags[other] = true end end
			end
			ns.ui.closedBags[bag] = nil
		end
	end
	if ns.Window.main then ns.Window.main:SyncTools() end
	ns:RefreshViews(true)
end

local function tooltip(btn)
	if not ns.TooltipsOK() then return end
	GameTooltip:SetOwner(btn, "ANCHOR_TOP")
	local info = ns.bagInfo[btn.bag]
	if btn.inv and GetInventoryItemLink("player", btn.inv) then
		GameTooltip:SetInventoryItem("player", btn.inv)
	elseif btn.bag == 0 then
		ns.TipText(GameTooltip, bagName(0), 1, 1, 1)
	else
		ns.TipText(GameTooltip, ns:IsReagentBag(btn.bag) and "Empty Reagent Bag Slot" or "Empty Bag Slot", 1, 1, 1)
		ns.TipLine(GameTooltip, "Drop a bag here", 0.6, 0.6, 0.6)
	end
	if info and (info.size or 0) > 0 then
		ns.TipLine(GameTooltip, ("%d of %d slots free"):format(info.free or 0, info.size), 0.6, 0.6, 0.6)
		ns.TipLine(GameTooltip, "Click to open or close its own window", 0.6, 0.6, 0.6)
	end
	GameTooltip:Show()
end

-- Classic: each slot gets the frame art of Blizzard's own bag bar slots,
-- read from Blizzard's bag button (its normal texture's atlas or file and
-- its size relative to the button); if that can't be read, the classic slot
-- border (UI-Quickslot2). Modern keeps BagSmith's flat thin border.
function BB:SlotFrameArt()
	if BB.slotFrame ~= nil then return BB.slotFrame end
	local art
	for _, name in ipairs({ "CharacterBag0Slot", "MainMenuBarBackpackButton" }) do
		local btn = _G[name]
		local nt = type(btn) == "table" and btn.GetNormalTexture and btn:GetNormalTexture()
		if nt then
			local atlas = nt.GetAtlas and nt:GetAtlas()
			local file = nt.GetTexture and nt:GetTexture()
			local bw, nw = btn.GetWidth and btn:GetWidth(), nt.GetWidth and nt:GetWidth()
			local scale = (bw and nw and bw > 0 and nw > 0) and (nw / bw) or 1
			if atlas and atlas ~= "" then art = { atlas = atlas, scale = scale, from = name .. " (" .. atlas .. ")" }
			elseif file and file ~= "" then art = { file = file, scale = scale, from = name } end
			if art then break end
		end
	end
	BB.slotFrame = art or { file = "Interface\\Buttons\\UI-Quickslot2", scale = 64 / 37, from = "classic slot border (UI-Quickslot2)" }
	return BB.slotFrame
end
-- One helper for both strips (this one and the bank window's Bank Bags):
-- the frame is made the first time Classic is on for that slot, then only
-- shown or hidden. sublevel (optional) puts it under the slot's own overlay
-- art (the bank's plus on the slot for sale).
function BB:ClassicFrame(b, on, sublevel)
	if on and not b.classicFrame then
		local art = BB:SlotFrameArt()
		local t = b:CreateTexture(nil, "OVERLAY", nil, sublevel)
		if art.atlas then t:SetAtlas(art.atlas) else t:SetTexture(art.file) end
		t:SetSize(b:GetWidth() * art.scale, b:GetHeight() * art.scale); t:SetPoint("CENTER")
		b.classicFrame = t
	end
	if b.classicFrame then b.classicFrame:SetShown(on and true or false) end
end

local function drop(btn)
	if not CursorHasItem() then return false end
	if btn.bag == 0 then if PutItemInBackpack then PutItemInBackpack() end
	elseif btn.inv then
		-- (1.7.1-beta1) a bag stored in the bag it should replace: BagSmith moves it out first and swaps it in
		if not (ns.SwapHint and ns.SwapHint.Intercept and ns.SwapHint:Intercept(btn.bag, btn.inv)) then PutItemInBag(btn.inv) end
	end
	return true
end

local function makeSlot(parent, bag)
	local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
	b:SetSize(SLOT, SLOT)
	b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnClick", function(self)
		if drop(self) then return end
		if (ns.bagInfo[self.bag] and ns.bagInfo[self.bag].size or 0) > 0 then BB:ToggleWindow(self.bag) end
	end)
	b:SetScript("OnDragStart", function(self) if self.inv and GetInventoryItemID and GetInventoryItemID("player", self.inv) then PickupBagFromSlot(self.inv) end end)
	b:SetScript("OnReceiveDrag", function(self) drop(self) end)
	b:SetScript("OnEnter", tooltip)
	b:SetScript("OnLeave", function() GameTooltip:Hide(); ResetCursor() end)
	ns.HoverWash(b, 0)
	b.bag = bag
	return b
end

-- The narrow Keys slot. Forever has no keyring (keys are ordinary items in
-- your bags), so this slot gives the narrow slot a job: hover lists the keys
-- you carry; click shows only your keys, click again shows everything.
local function keys()
	local out = {}
	for _, r in ipairs(ns.items or {}) do if r.cat == "Keys" then out[#out + 1] = r end end
	table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
	return out
end
local function keysOnly()
	local f = ns.ui.filters
	if not (f and f.cat and f.cat.Keys) then return false end
	for k in pairs(f.cat) do if k ~= "Keys" then return false end end
	return true
end
function BB:ToggleKeys()
	local f = ns.ui.filters
	if keysOnly() then
		-- Back to the categories you had, but only in the same filter set
		-- (a sheet or profile switch replaces it; then this just clears Keys).
		local saved = BB.catsBeforeKeys
		f.cat = (saved and saved.filters == f) and saved.cat or {}
		BB.catsBeforeKeys = nil
	else
		local before = {}
		for k, v in pairs(f.cat or {}) do before[k] = v end
		BB.catsBeforeKeys = { filters = f, cat = before }
		f.cat = { Keys = true }
	end
	if ns.Window.main then ns.Window.main:SyncTools() end
	ns:RefreshViews(true)
end
local function keyTooltip(btn)
	if not ns.TooltipsOK() then return end
	GameTooltip:SetOwner(btn, "ANCHOR_TOP")
	ns.TipText(GameTooltip, "Keys", 1, 1, 1)
	local list = keys()
	if #list == 0 then
		ns.TipLine(GameTooltip, "No keys in your bags", 0.6, 0.6, 0.6)
	else
		for i, r in ipairs(list) do
			if i > 12 then ns.TipLine(GameTooltip, ("and %d more"):format(#list - 12), 0.6, 0.6, 0.6); break end
			local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[r.quality or 1]
			local name = (r.count or 1) > 1 and ("%s x%d"):format(r.name or "?", r.count) or (r.name or "?")
			if c then ns.TipLine(GameTooltip, name, c.r, c.g, c.b) else ns.TipLine(GameTooltip, name, 1, 1, 1) end
		end
		ns.TipLine(GameTooltip, keysOnly() and "Click to show everything again" or "Click to show only your keys", 0.6, 0.6, 0.6)
	end
	GameTooltip:Show()
end
local function makeKeySlot(parent)
	local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
	b:SetSize(KEY_W, SLOT)
	b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	b.icon = b:CreateTexture(nil, "ARTWORK")
	if BB:KeyArt() == "blizzard" then
		b.icon:SetAllPoints(b)
		b.icon:SetTexture(KEYRING_ART); b.icon:SetTexCoord(unpack(KEYRING_COORDS))
		b:SetHighlightTexture(KEYRING_ART .. "-Highlight")
		local hl = b:GetHighlightTexture(); if hl then hl:SetTexCoord(unpack(KEYRING_COORDS)) end
	else
		b.icon:SetSize(14, 28); b.icon:SetPoint("CENTER")
		b.icon:SetTexture(DRAWN_KEY)
		b.drawn = true
	end
	b:SetScript("OnClick", function() BB:ToggleKeys() end)
	b:SetScript("OnEnter", keyTooltip)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	ns.HoverWash(b, 0)
	return b
end

-- The strip's status only (free slots, bag icons, key dimming, open-window
-- borders), with no layout: used while rows hold still under the pointer.
function BB:UpdateStatus(bar)
	if not (bar and bar.label and bar:IsShown()) then return end
	local free, total = 0, 0
	for _, bag in ipairs(bags()) do
		local info = ns.bagInfo[bag]
		if info then free, total = free + (info.free or 0), total + (info.size or 0) end
	end
	bar.hint:SetText(("%d of %d slots free"):format(free, total))
	local ks = bar.keySlot
	if ks then ks.icon:SetAlpha(#keys() > 0 and 1 or 0.5); if not ks.drawn then ks.icon:SetDesaturated(#keys() == 0) end end
	for _, b in ipairs(bar.slots or {}) do
		if b:IsShown() and b.bag then
			b.inv = invFor(b.bag)
			local tex = b.bag == 0 and BACKPACK or (b.inv and GetInventoryItemTexture("player", b.inv))
			b.icon:SetTexture(tex or EMPTY); b.icon:SetDesaturated(tex == nil); b.icon:SetAlpha(tex and 1 or 0.5)
		end
	end
end

-- Fills the strip for the bags window. Returns the height it needs (0 = hidden).
function BB:FillBar(bar)
	if not self:Open() or ns.ui.owner or ns.ui.sheet == "Bank" then
		for _, b in ipairs(bar.slots or {}) do b:Hide() end
		if bar.keySlot then bar.keySlot:Hide() end
		if bar.label then bar.label:Hide(); bar.hint:Hide() end
		return 0
	end
	bar.slots = bar.slots or {}
	if not bar.label then
		bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		bar.label:SetPoint("LEFT", 10, 6)
		bar.hint = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		bar.hint:SetPoint("LEFT", 10, -8)
	end
	local free, total = 0, 0
	for _, bag in ipairs(bags()) do
		local info = ns.bagInfo[bag]
		if info then free, total = free + (info.free or 0), total + (info.size or 0) end
	end
	bar.label:SetText("Bags")
	bar.label:SetTextColor(ns.Skins:Color("accent"))
	bar.hint:SetText(("%d of %d slots free"):format(free, total))
	bar.hint:SetTextColor(ns.Skins:Color("muted"))
	bar.label:Show(); bar.hint:Show()
	local x = math.max(bar.label:GetStringWidth(), bar.hint:GetStringWidth()) + 24
	-- The narrow Keys slot first, then the bags.
	bar.keySlot = bar.keySlot or makeKeySlot(bar)
	local ks = bar.keySlot
	local hasKeys = #keys() > 0
	ks:SetBackdropColor(0, 0, 0, 0.35)
	if keysOnly() then local r, g, bl = ns.Skins:Accent(); ks:SetBackdropBorderColor(r, g, bl, 0.9)
	else ks:SetBackdropBorderColor(1, 1, 1, 0.12) end
	if ks.drawn then
		-- The drawn key: gold in Classic, a soft light in Modern.
		if ns.Classic and ns.Classic.IsOn and ns.Classic.IsOn() then ks.icon:SetVertexColor(1, 0.82, 0)
		else ks.icon:SetVertexColor(0.85, 0.83, 0.78) end
	else
		ks.icon:SetDesaturated(not hasKeys)
	end
	ks.icon:SetAlpha(hasKeys and 1 or 0.5)
	ks:ClearAllPoints(); ks:SetPoint("LEFT", bar, "LEFT", x, 0); ks:Show()
	x = x + KEY_W + 4
	local list = bags()
	for i, bag in ipairs(list) do
		local b = bar.slots[i]
		if not b then b = makeSlot(bar, bag); bar.slots[i] = b end
		b.bag, b.inv = bag, invFor(bag)
		local tex = bag == 0 and BACKPACK or (b.inv and GetInventoryItemTexture("player", b.inv))
		local classic = ns.Classic and ns.Classic.IsOn and ns.Classic.IsOn()
		b:SetBackdropColor(0, 0, 0, 0.35)
		BB:ClassicFrame(b, classic)
		-- A bag whose own window is open: the accent border (Modern), or a
		-- brighter gold frame (Classic).
		local v = ns.Window.bagViews and rawget(ns.Window.bagViews, bag)   -- (1.6.2-beta1) only looks, never builds
		local open = v and v:IsShown()
		if classic then
			b:SetBackdropBorderColor(0, 0, 0, 0)
			if open then b.classicFrame:SetVertexColor(1, 0.9, 0.55) else b.classicFrame:SetVertexColor(1, 1, 1) end
		elseif open then local r, g, bl = ns.Skins:Accent(); b:SetBackdropBorderColor(r, g, bl, 0.9)
		else b:SetBackdropBorderColor(1, 1, 1, 0.12) end
		b.icon:SetTexture(tex or EMPTY); b.icon:SetDesaturated(tex == nil); b.icon:SetAlpha(tex and 1 or 0.5)
		b:ClearAllPoints(); b:SetPoint("LEFT", bar, "LEFT", x, 0)
		b:Show()
		x = x + SLOT + 4
	end
	for j = #list + 1, #bar.slots do bar.slots[j]:Hide() end
	return SLOT + 14
end

------------------------------------------------------------------------
-- Blizzard's bag bar (optional: faded out and click-through)
------------------------------------------------------------------------
local BLIZZ = { "BagsBar" }   -- (not MicroButtonAndBagsBar: on clients that have it, it also holds the micro menu)
local BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
	"CharacterReagentBag0Slot", "BagBarExpandToggle" }
function BB:BlizzardFrames()
	local out, found = {}, {}
	for _, name in ipairs(BLIZZ) do
		local f = _G[name]
		if type(f) == "table" and f.SetAlpha then out[#out + 1] = f; found[#found + 1] = name; break end
	end
	for _, name in ipairs(BUTTONS) do
		local f = _G[name]
		if type(f) == "table" and f.SetAlpha then out[#out + 1] = f; if #found < 2 then found[#found + 1] = name end end
	end
	BB.blizzFound = #found > 0 and table.concat(found, ", ") or "none found"
	return out
end
function BB:ApplyBlizzard()
	if InCombatLockdown() then ns:Safely("bagBarBlizzard", function() BB:ApplyBlizzard() end); return end
	local hide = ns.db and ns.db.hideBlizzBagBar and true or false
	if not hide and not BB.blizzHidden then return end   -- never touch it unless asked
	for _, f in ipairs(self:BlizzardFrames()) do
		if hide then
			-- Remember what we found, to put it back exactly.
			if f.bagSmithSaved == nil then
				f.bagSmithSaved = { alpha = f.GetAlpha and f:GetAlpha() or 1, mouse = (f.IsMouseEnabled and f:IsMouseEnabled()) }
			end
			f:SetAlpha(0)
			if f.EnableMouse then f:EnableMouse(false) end
		elseif f.bagSmithSaved then
			f:SetAlpha(f.bagSmithSaved.alpha or 1)
			if f.EnableMouse and f.bagSmithSaved.mouse ~= nil then f:EnableMouse(f.bagSmithSaved.mouse) end
			f.bagSmithSaved = nil
		end
	end
	BB.blizzHidden = hide
end

ns:OnSignal("ADDON_READY", function()
	ns:On("PLAYER_ENTERING_WORLD", function() BB:ApplyBlizzard() end)
	ns:OnSignal("SETTINGS_CHANGED", function(key)
		if key == nil or key == "hideBlizzBagBar" then BB:ApplyBlizzard() end
	end)
end)
