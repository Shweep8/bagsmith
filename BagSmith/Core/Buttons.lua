--[[
	BagSmith - Core/Buttons.lua
	Item cells and rows.

	Secure pool: one ContainerFrameItemButtonTemplate per possible slot of
	every managed bag (inventory and bank), created once at login, parented
	to a per-bag proxy frame whose ID is the bag. Never created, re-parented,
	shown, hidden or moved during combat.

	Cached pool: plain buttons for browsing other characters. Not secure,
	created on demand.

	Both kinds expose the same surface: SetMode("row"|"cell"), Fill(rec),
	Blank(), plus the text column font strings for rows.
--]]

local ADDON, ns = ...
local Buttons = {}
ns.Buttons = Buttons

Buttons.proxies, Buttons.byBag, Buttons.all = {}, {}, {}
Buttons.cached, Buttons.lanes = {}, {}   -- keyed by host frame
Buttons.created = false

local ICON_ROW = 20
local COL_KEYS = { "colName", "colQty", "colLevel", "colReq", "colType", "colSlot", "colBind", "colValue", "colWhere", "colAge", "colAH" }
Buttons.COL_KEYS = COL_KEYS

local QCOL = {}
local function qcolor(q)
	q = q or 1
	if not QCOL[q] then
		local r, g, b = C_Item.GetItemQualityColor(q)
		QCOL[q] = { r or 1, g or 1, b or 1 }
	end
	return unpack(QCOL[q])
end

local function hideRegion(r) if r then r:SetAlpha(0); if r.Hide then r:Hide() end end end

-- Empty-slot art for the Classic skin: the classic-era slot texture, cropped,
-- drawn inside Blizzard's Quickslot ring (the ring comes from ApplyFrame).
-- This is the look the main window had in 0.8.0; every window uses it.
-- Forever draws empty bag slots with newer art than the classic-era texture.
-- Read it from Blizzard's own bag button template (BagSmith's secure buttons
-- are built from it), so every empty slot matches the game exactly.
function Buttons.TemplateSlotArt()
	if Buttons.slotArt ~= nil then return Buttons.slotArt or nil end
	local art = false
	local probe = Buttons.all and Buttons.all[1]
	local tex = probe and (probe.ItemSlotBackground or probe.SlotBackground)
	if tex then
		local atlas = tex.GetAtlas and tex:GetAtlas()
		local file = tex.GetTexture and tex:GetTexture()
		if atlas and atlas ~= "" then art = { atlas = atlas, from = "template (" .. atlas .. ")" }
		elseif file then art = { file = file, from = "template" } end
	end
	if not art and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("bags-item-slot64") then
		art = { atlas = "bags-item-slot64", from = "bags-item-slot64" }
	end
	Buttons.slotArt = art
	return art or nil
end

function Buttons.SetSlotArt(tex)
	local art = Buttons.TemplateSlotArt()
	if art and art.atlas then tex:SetAtlas(art.atlas); return true end
	if art and art.file then tex:SetTexture(art.file); tex:SetTexCoord(0, 1, 0, 1); return true end
	tex:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
	tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	return false
end

-- Modern items use a cropped icon and four edges aligned to physical pixels.
-- Classic skin: Blizzard's own empty-slot art in cell mode, nothing in rows.
local function updateModernBorder(b)
	if b.modernBorderActive then Buttons:UpdateModernBorderGeometry(b) end
end

function Buttons.AddFrame(b)
	b:HookScript("OnUpdate", updateModernBorder)
	b.frameBG = b:CreateTexture(nil, "BACKGROUND", nil, -2)
	b.frameBG:SetTexture("Interface\\Buttons\\WHITE8X8")
	b.frameEdge = b:CreateTexture(nil, "BACKGROUND", nil, -1)
	b.frameEdge:SetTexture("Interface\\Buttons\\WHITE8X8")
	b.frameBG:Hide(); b.frameEdge:Hide()
	-- Classic list rows retain their original quality ring.
	b.qRing = b:CreateTexture(nil, "BACKGROUND", nil, 0)
	b.qRing:SetTexture("Interface\\Buttons\\WHITE8X8")
	b.qRing:Hide()
	-- Classic cells: Blizzard's own slot ring (UI-Quickslot2) and its white
	-- icon frame tinted by rarity, exactly what the default bags draw.
	b.slotRing = b:CreateTexture(nil, "OVERLAY", nil, 1)
	b.slotRing:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	b.slotRing:Hide()
	b.qFrame = b:CreateTexture(nil, "OVERLAY", nil, 2)
	b.qFrame:SetTexture("Interface\\Common\\WhiteIconFrame")
	b.qFrame:Hide()
	b.modernBorder = {}
	for i = 1, 4 do
		local edge = b:CreateTexture(nil, "OVERLAY", nil, -1)
		edge:SetTexture("Interface\\Buttons\\WHITE8X8")
		if edge.SetRoundLayoutToNearestPixel then edge:SetRoundLayoutToNearestPixel(false) end
		edge:Hide()
		b.modernBorder[i] = edge
	end
end

Buttons.NEUTRAL_FRAME = { 0.28, 0.27, 0.25 }

-- Item tooltips go where Blizzard's own rule puts them. Blizzard's bag
-- button refreshes its tooltip a few times a second and re-places it by that
-- rule each time, so any other placement visibly jumps (the bags window sits
-- on the right half of the screen, where the rule picks the left side). The
-- client's own anchor calculation is used when it has one; otherwise the same
-- rule: left of items on the right half of the screen, right of the rest.
-- BagSmith's display cells (bag windows, alt view) use it too, so every
-- window behaves the same wherever it is.
function Buttons.PlaceTooltip(b)
	local calc = _G.ContainerFrameItemButton_CalculateItemTooltipAnchors
	if type(calc) == "function" then
		GameTooltip:SetOwner(b, "ANCHOR_NONE")
		if pcall(calc, b, GameTooltip) then Buttons.tipPlacement = "Blizzard's anchor calculation"; return end
	end
	local x = b.GetRight and b:GetRight()
	local w = GetScreenWidth and GetScreenWidth()
	GameTooltip:SetOwner(b, (x and w and x >= w / 2) and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
	Buttons.tipPlacement = "BagSmith's copy of Blizzard's rule"
end

-- Applies the rarity border for the current skin and setting. Blizzard's own
-- IconBorder is hidden so both skins draw the same way for every cell kind.
local function placeBorderEdge(edge, icon, x, y, width, height)
	edge:ClearAllPoints()
	edge:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", x, y)
	edge:SetSize(width, height)
end

function Buttons:UpdateModernBorderGeometry(b)
	local x, y, width, height = b.icon:GetRect()
	if not (x and y and width and height) then return end
	local pixel = PixelUtil.GetPixelToUIUnitFactor() / b:GetEffectiveScale()
	if b.borderX == x and b.borderY == y and b.borderW == width and b.borderH == height and b.borderPixel == pixel then return end
	b.borderX, b.borderY, b.borderW, b.borderH, b.borderPixel = x, y, width, height, pixel
	local left = math.floor(x / pixel + 0.5) * pixel
	local bottom = math.floor(y / pixel + 0.5) * pixel
	local x0, y0 = left - x, bottom - y
	local w = math.max(2 * pixel, math.floor((x + width) / pixel + 0.5) * pixel - left)
	local h = math.max(2 * pixel, math.floor((y + height) / pixel + 0.5) * pixel - bottom)
	-- Side strips exclude corners, so translucent borders never double up.
	placeBorderEdge(b.modernBorder[1], b.icon, x0, y0 + h - pixel, w, pixel)
	placeBorderEdge(b.modernBorder[2], b.icon, x0, y0, w, pixel)
	placeBorderEdge(b.modernBorder[3], b.icon, x0, y0 + pixel, pixel, h - 2 * pixel)
	placeBorderEdge(b.modernBorder[4], b.icon, x0 + w - pixel, y0 + pixel, pixel, h - 2 * pixel)
end

function Buttons:DrawModernBorder(b, r, g, bl)
	b.modernBorderActive = true
	self:UpdateModernBorderGeometry(b)
	for _, edge in ipairs(b.modernBorder) do
		edge:SetVertexColor(r, g, bl, 0.95)
		edge:Show()
	end
end

function Buttons:ApplyQuality(b, rec)
	b.modernBorderActive = nil
	for _, edge in ipairs(b.modernBorder or {}) do edge:Hide() end
	if b.IconBorder then b.IconBorder:Hide() end
	if not b.qRing then return end
	-- No item, no frame: empty slots and blank rows keep their own look.
	if not rec then
		b.qRing:Hide(); b.qFrame:Hide()
		if (ns.db and ns.db.skin or "modern") == "modern" then self:ApplyFrame(b) end
		return
	end
	local q = rec.quality or 1
	local setting = ns.db and ns.db.border or "all"
	local colored = setting == "all" or (setting == "unc" and q >= 2)
	-- Icons the setting leaves uncolored still get a thin frame, in the same
	-- style as the rarity border, in a dark neutral grey (darker than Poor's
	-- grey, so it never reads as a rarity).
	local r, g, bl
	if colored then r, g, bl = qcolor(q) else r, g, bl = Buttons.NEUTRAL_FRAME[1], Buttons.NEUTRAL_FRAME[2], Buttons.NEUTRAL_FRAME[3] end
	b.qNeutral = not colored
	local icon = b.icon
	local classicCell = (ns.db and ns.db.skin or "modern") == "classic" and b.mode == "cell"
	if (ns.db and ns.db.skin or "modern") == "modern" then
		b.qRing:Hide(); b.qFrame:Hide(); b.frameEdge:Hide(); b.frameBG:Hide()
		self:DrawModernBorder(b, r, g, bl)
	elseif classicCell then
		-- Blizzard's rarity frame, 2 px larger than the icon on every side so its
		-- rounded corners cover the icon's square corners (icons whose art runs
		-- to the edge, such as capes, showed a corner outside the frame).
		b.qFrame:ClearAllPoints()
		b.qFrame:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2); b.qFrame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
		b.qFrame:SetVertexColor(r, g, bl, 1)
		b.qFrame:Show(); b.qRing:Hide()
	else
		-- Classic rows retain the original ring.
		b.qRing:ClearAllPoints()
		b.qRing:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1); b.qRing:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
		b.qRing:SetVertexColor(r, g, bl, 0.95)
		b.qRing:Show(); b.qFrame:Hide()
	end
end

local function near(a, b) return math.abs(a - b) < 0.00001 end
function Buttons:ApplyIconCrop(b)
	if not b.icon then return end
	if (ns.db and ns.db.skin or "modern") == "modern" then
		local a, c, d, e, f, g, h, i = b.icon:GetTexCoord()
		if not (near(a, 0.08) and near(c, 0.08) and near(d, 0.08) and near(e, 0.92)
			and near(f, 0.92) and near(g, 0.08) and near(h, 0.92) and near(i, 0.92)) then
			-- Item updates reset the crop; retain those coordinates for Classic.
			local coords = b.classicIconCoords or {}
			coords[1], coords[2], coords[3], coords[4] = a, c, d, e
			coords[5], coords[6], coords[7], coords[8] = f, g, h, i
			b.classicIconCoords = coords
			b.modernCropActive = true
			b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
	elseif b.modernCropActive then
		b.icon:SetTexCoord(unpack(b.classicIconCoords))
		b.modernCropActive = nil
	end
end

function Buttons:ApplyFrame(b)
	self:ApplyIconCrop(b)
	if not b.frameBG then return end
	local modern = (ns.db and ns.db.skin or "modern") == "modern"
	local icon, cell = b.icon, b.mode == "cell"
	local normal = b.GetNormalTexture and b:GetNormalTexture()
	if modern then
		-- Shaded frame. In cells the icon is inset so the frame stays inside
		-- the cell and never clips against a neighbour; in rows it hugs the icon.
		b.frameEdge:ClearAllPoints(); b.frameBG:ClearAllPoints()
		if cell then
			b.frameEdge:SetAllPoints(b)
			b.frameBG:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1); b.frameBG:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
		else
			b.frameEdge:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2); b.frameEdge:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
			b.frameBG:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1); b.frameBG:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
		end
		b.frameEdge:SetVertexColor(1, 1, 1, 0.10); b.frameBG:SetVertexColor(0, 0, 0, 0.55)
		b.frameEdge:Show(); b.frameBG:Show()
		if b.slotBG then b.slotBG:Hide() end
		b.slotRing:Hide()
		if normal then normal:SetAlpha(0) end
	else
		b.frameEdge:Hide(); b.frameBG:Hide()
		if cell then
			-- Blizzard's regular slot: empty-slot art under the icon and the
			-- Quickslot ring around it (the secure button's own normal texture).
			if b.slotBG then
				-- (Re)apply the art: the template's art is read once the first button exists.
				if not b.slotArtSet then b.slotArtSet = true; Buttons.SetSlotArt(b.slotBG) end
				b.slotBG:Show()
			end
			if Buttons.TemplateSlotArt() then
				-- Forever's newer art has its own bevel: no old Quickslot ring.
				if normal then normal:SetAlpha(0) end
				b.slotRing:Hide()
			elseif normal and b.secure then
				normal:SetAlpha(1); b.slotRing:Hide()
			else
				local w = b:GetWidth() or 37
				b.slotRing:ClearAllPoints(); b.slotRing:SetPoint("CENTER", b, "CENTER", 0, 0)
				b.slotRing:SetSize(w * 1.72, w * 1.72); b.slotRing:Show()
			end
		else
			-- Rows: a plain icon, no slot art.
			if b.slotBG then b.slotBG:Hide() end
			b.slotRing:Hide()
			if normal then normal:SetAlpha(0) end
		end
	end
end

------------------------------------------------------------------------
-- Shared decoration
------------------------------------------------------------------------
local function addText(b)
	for _, key in ipairs(COL_KEYS) do
		local s = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		s:SetWordWrap(false)
		s:Hide()
		-- Its normal color, so Dim Junk Items can put it back.
		local r, g, bl = 1, 1, 1
		if s.GetTextColor then local cr, cg, cb = s:GetTextColor(); if cr then r, g, bl = cr, cg, cb end end
		s.baseColor = { r, g, bl }
		b[key] = s
	end
	b.colQty:SetJustifyH("RIGHT"); b.colLevel:SetJustifyH("RIGHT"); b.colReq:SetJustifyH("RIGHT"); b.colValue:SetJustifyH("RIGHT"); b.colAge:SetJustifyH("RIGHT"); b.colAH:SetJustifyH("RIGHT")
	b.newDot = b:CreateTexture(nil, "OVERLAY", nil, 7)
	b.newDot:SetSize(11, 11)
	b.newDot:SetTexture("Interface\\AddOns\\BagSmith\\Media\\ui-newdot.tga")
	b.newDot:Hide()
	-- Junk: Blizzard's coin on the icon (both views), and in list view a
	-- clickable Sell All Junk icon in the Junk column to mark or unmark.
	b.junkCoin = b:CreateTexture(nil, "OVERLAY", nil, 6)
	b.junkCoin:Hide()
	if ns.Junk then ns.Junk:SetCoin(b.junkCoin) end
	-- The Junk, Favorite and Currency cells are made the first time a row
	-- lays out that column (Buttons.EnsureCell), not for every button.
end

-- The clickable icon for a Junk, Favorite or Currency column, made once.
function Buttons.EnsureCell(b, key)
	if key == "jk" then
		if b.colJunk then return b.colJunk end
		local jc = CreateFrame("Button", nil, b)
		jc:SetSize(16, 16)
		jc.tex = jc:CreateTexture(nil, "OVERLAY"); jc.tex:SetAllPoints(jc)
		ns.Junk:SetColumnIcon(jc.tex)
		jc:SetScript("OnClick", function(self) ns.Junk:Toggle(self:GetParent().rec) end)
		jc:SetScript("OnEnter", function(self) ns.Junk:CellEnter(self) end)
		jc:SetScript("OnLeave", function(self) ns.Junk:CellLeave(self) end)
		jc:Hide()
		b.colJunk = jc
		if b.rec then ns.Junk:Decorate(b, b.hasItem and b.rec or nil) end
		return jc
	end
	return ns.Marks:MakeCell(b, key)
end

-- The item menu button: three muted dots at the left of a list row that open
-- the item menu (the same as Alt+Left-click). Made once per row button; never
-- made, moved, shown or hidden in combat (the row is a secure button).
local function kebabAlpha(b)
	local k = b.kebab
	if not k then return end
	local function over(f) return f.IsMouseOver and f:IsMouseOver() end
	k:SetAlpha(over(k) and 1 or (over(b) and 0.85 or 0.35))
end
function Buttons:PlaceKebab(b, x)
	if InCombatLockdown() then return end
	if not x then
		if b.kebab then b.kebab:Hide() end
		b.kebabOn = nil
		return
	end
	local k = b.kebab
	if not k then
		k = CreateFrame("Button", nil, b)
		k:SetSize(12, 18)
		k.dots = {}
		for i = 1, 3 do
			local d = k:CreateTexture(nil, "OVERLAY")
			d:SetTexture("Interface\\Buttons\\WHITE8X8"); d:SetSize(2, 2)
			d:SetPoint("CENTER", k, "CENTER", 0, (2 - i) * 4)
			d:SetVertexColor(0.85, 0.83, 0.78)
			k.dots[i] = d
		end
		k:SetScript("OnClick", function(self)
			local row = self:GetParent()
			if row.rec and not row.rec.empty and ns.Sections then ns.Sections:ItemMenu(row.rec, self) end
		end)
		k:SetScript("OnEnter", function(self)
			kebabAlpha(self:GetParent())
			if not ns.HelpTipsOK() then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			ns.TipText(GameTooltip, "Item menu", 1, 1, 1)
			ns.TipLine(GameTooltip, "Move to Section, Favorite, Mark as Junk, Track as Currency", 0.8, 0.8, 0.8, true)
			GameTooltip:Show()
		end)
		k:SetScript("OnLeave", function(self) GameTooltip:Hide(); kebabAlpha(self:GetParent()) end)
		b:HookScript("OnEnter", kebabAlpha)
		b:HookScript("OnLeave", kebabAlpha)
		b.kebab = k
	end
	k:ClearAllPoints(); k:SetPoint("LEFT", b, "LEFT", x, 0)
	b.kebabOn = true
	k:SetShown(b.rec and not b.rec.empty and true or false)
	kebabAlpha(b)
end

local function applyMode(b, mode, size)
	b.mode = mode
	b.colSig = nil   -- (1.6.2-beta1) the row's columns are placed afresh after a change of mode (ApplyColumns)
	local icon = b.icon
	icon:ClearAllPoints()
	if mode == "row" then
		icon:SetSize(ICON_ROW, ICON_ROW)
		icon:SetPoint("LEFT", b, "LEFT", 2, 0)
		if b.IconBorder then
			b.IconBorder:ClearAllPoints()
			b.IconBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -3, 3)
			b.IconBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 3, -3)
		end
		if b.Count then b.Count:ClearAllPoints(); b.Count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -1); b.Count:SetAlpha(1) end
		-- The bottom center of the icon: clear of the junk coin, Pawn's arrow
		-- and the count, and never clipped by the list edge.
		b.newDot:SetSize(9, 9)
		b.newDot:ClearAllPoints(); b.newDot:SetPoint("BOTTOM", icon, "BOTTOM", 0, 1)
		for _, key in ipairs(COL_KEYS) do b[key]:Show() end
		if b.slotBG then b.slotBG:Hide() end
		Buttons:ApplyFrame(b)
	else
		icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2); icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
		if b.IconBorder then b.IconBorder:ClearAllPoints(); b.IconBorder:SetAllPoints(b) end
		if b.Count then b.Count:ClearAllPoints(); b.Count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2); b.Count:SetAlpha(1) end
		b.newDot:SetSize(10, 10)
		b.newDot:ClearAllPoints(); b.newDot:SetPoint("BOTTOM", icon, "BOTTOM", 0, 1)
		for _, key in ipairs(COL_KEYS) do b[key]:Hide() end
		if b.kebab and not InCombatLockdown() then b.kebab:Hide(); b.kebabOn = nil end
		if b.colJunk then b.colJunk:Hide() end
		if b.colFav then b.colFav:Hide() end
		if b.colCurr then b.colCurr:Hide() end
		for _, sep in ipairs(b.seps or {}) do sep:Hide() end
		if b.slotBG then b.slotBG:Show() end
		Buttons:ApplyFrame(b)
	end
	if b.Cooldown then b.Cooldown:ClearAllPoints(); b.Cooldown:SetAllPoints(icon) end
	Buttons:FitCountdown(b)   -- (1.4.2-beta2) the number fits this icon size
end

Buttons.NEW_DISMISS_SECONDS = 0.5

-- An item can be on screen more than once (its Recent copy, a bag window's
-- cell). Dismissing its "new" pip on one clears it on every copy.
function Buttons:ClearNewEverywhere(rec)
	if not rec then return end
	local function same(r)
		if not r then return false end
		if r == rec then return true end
		if rec.guid and r.guid then return r.guid == rec.guid end
		if r.bag == rec.bag and r.slot == rec.slot then return true end
		return (rec.merged or r.merged) and ns.MergeKey(r) == ns.MergeKey(rec)   -- the same identity as Merge Stacks
	end
	local function clear(x)
		if x and x.rec and same(x.rec) then x.rec.isNew = false; if x.newDot then x.newDot:Hide() end end
	end
	for _, b in ipairs(self.all) do clear(b) end
	for _, b in ipairs(self.recent) do clear(b) end
	for _, pool in pairs(self.mirrors) do for _, b in pairs(pool) do clear(b) end end
end

function Buttons:StartNewDismiss(b)
	self:CancelNewDismiss(b)
	local rec = b.rec
	if not (C_Timer and C_Timer.NewTimer) then ns:DismissNew(rec); b.newDot:Hide(); self:ClearNewEverywhere(rec); return end
	-- Match by item identity, not by record object: a bag update during the
	-- hover replaces the record, and that must not cancel the dismissal.
	local guid, bag, slot = rec.guid, rec.bag, rec.slot
	b.newTimer = C_Timer.NewTimer(self.NEW_DISMISS_SECONDS, function()
		b.newTimer = nil
		local cur = b.rec
		if cur and cur.isNew and ((guid and cur.guid == guid) or (not guid and cur.bag == bag and cur.slot == slot)) then
			ns:DismissNew(cur); b.newDot:Hide()
			Buttons:ClearNewEverywhere(cur)
		end
	end)
end
function Buttons:CancelNewDismiss(b)
	if b.newTimer then b.newTimer:Cancel(); b.newTimer = nil end
end

-- Every live item button on screen: the windows, Recent copies, and the small
-- bag windows' mirrors (not other characters' saved bags).
function Buttons:EachLive(fn)
	for _, b in ipairs(self.all) do fn(b) end
	for _, b in ipairs(self.recent) do fn(b) end
	for _, pool in pairs(self.mirrors) do for _, b in pairs(pool) do fn(b) end end
end

function Buttons:SetMode(b, mode)
	if b.mode ~= mode then applyMode(b, mode) end
	if mode ~= "row" and b.stripe then b.stripe:Hide() end
end

function Buttons:RefreshSkin()
	-- Blank slots keep their record (bag and slot) but have no item: no frame.
	local function each(b) self:ApplyFrame(b); self:ApplyQuality(b, b.hasItem and b.rec or nil) end
	for _, b in ipairs(self.all) do each(b) end
	for _, pool in pairs(self.cached) do for _, b in pairs(pool) do each(b) end end
	for _, pool in pairs(self.mirrors) do for _, b in pairs(pool) do each(b) end end
	for _, b in ipairs(self.recent) do each(b) end
end
ns:OnSignal("SETTINGS_CHANGED", function(key) if key == nil or key == "skin" or key == "border" then Buttons:RefreshSkin() end end)
-- The item-level setting redraws every placed button's level text in place (no layout pass needed).
function Buttons:RefreshItemLevels()
	local function each(b) self:ItemLevel(b, b.hasItem and b.rec or nil) end
	for _, b in ipairs(self.all) do each(b) end
	for _, pool in pairs(self.cached) do for _, b in pairs(pool) do each(b) end end
	for _, pool in pairs(self.mirrors) do for _, b in pairs(pool) do each(b) end end
	for _, b in ipairs(self.recent) do each(b) end
end
ns:OnSignal("SETTINGS_CHANGED", function(key) if key == nil or key == "iconItemLevel" or key == "iconItemLevelColor" then Buttons:RefreshItemLevels() end end)

-- Faint alternating row background, list mode only.
function Buttons:SetStripe(b, on)
	if not b.stripe then
		b.stripe = b:CreateTexture(nil, "BACKGROUND", nil, -1)
		b.stripe:SetAllPoints(b)
		b.stripe:SetTexture("Interface\\Buttons\\WHITE8X8")
		b.stripe:SetVertexColor(1, 1, 1, 0.025)
	end
	b.stripe:SetShown(on and b.mode == "row")
end

-- Position the text columns for one row; hide the rest; draw faint separators.
local NUMERIC = { c = true, il = true, rq = true, v = true, age = true, ah = true }
-- (1.6.2-beta1) What a row's column placement depends on: the plan's columns and their places, and the row height.
-- Made once per plan (a fresh plan each layout), then compared per row.
local function planSig(plan, rowH)
	local sig = plan.sig
	if not sig then
		local parts = { tostring(plan.kebab) }
		for _, col in ipairs(plan) do
			parts[#parts + 1] = table.concat({ tostring(col.key), tostring(col.fs), tostring(col.x), tostring(col.width),
				tostring(col.colX), tostring(col.colW), tostring(col.iconX), tostring(col.kebabX) }, ":")
		end
		sig = table.concat(parts, ";")
		plan.sig = sig
	end
	return sig .. "|" .. tostring(rowH)
end
function Buttons:ApplyColumns(b, plan, rowH)
	-- (1.6.2-beta1) A row's columns are placed again only when they change. An item change redraws every row, and
	-- placing every column of every row each time was most of List view's cost; the same plan and row height as the
	-- last placement leave the row as it is. Icons view forgets it (applyMode), and nothing is remembered in combat
	-- (the item menu's dots can't be placed then).
	local sig = planSig(plan, rowH)
	if b.mode == "row" and b.colSig == sig then return end
	local inPlan = {}
	local iconSize = math.max(14, math.min(24, rowH - 6))
	b.icon:SetSize(iconSize, iconSize)
	b.iconPx = iconSize
	Buttons:FitCountdown(b)   -- (1.4.2-beta2) the number fits the row's icon
	b.seps = b.seps or {}
	local si = 0
	for i, col in ipairs(plan) do
		if col.key == "jk" or col.key == "fv" or col.key == "cc" then
			Buttons.EnsureCell(b, col.key)
		end
		local fs = b[col.fs]
		inPlan[col.fs] = true
		if col.key == "jk" or col.key == "fv" or col.key == "cc" then
			-- The Favorite, Currency and Junk columns: a small clickable icon, centered.
			fs:ClearAllPoints(); fs:SetPoint("CENTER", b, "LEFT", col.colX + col.colW / 2, 0)
		else
			fs:ClearAllPoints(); fs:SetPoint("LEFT", b, "LEFT", col.x, 0); fs:SetWidth(math.max(10, col.width))
			fs:SetJustifyH(NUMERIC[col.key] and "RIGHT" or "LEFT")
			fs:Show()
		end
		if col.key == "n" then
			b.icon:ClearAllPoints(); b.icon:SetPoint("LEFT", b, "LEFT", col.iconX, 0)
			Buttons:PlaceKebab(b, plan.kebab and col.kebabX or nil)
		end
		if i > 1 then
			si = si + 1
			local sep = b.seps[si]
			if not sep then
				sep = b:CreateTexture(nil, "BACKGROUND", nil, 1)
				sep:SetTexture("Interface\\Buttons\\WHITE8X8")
				sep:SetVertexColor(1, 1, 1, 0.04)
				sep:SetWidth(1)
				b.seps[si] = sep
			end
			sep:ClearAllPoints(); sep:SetPoint("TOP", b, "TOPLEFT", col.colX, 0); sep:SetPoint("BOTTOM", b, "BOTTOMLEFT", col.colX, 0)
			sep:Show()
		end
	end
	for j = si + 1, #b.seps do b.seps[j]:Hide() end
	for _, key in ipairs(COL_KEYS) do if not inPlan[key] then b[key]:Hide() end end
	b.junkColumn = inPlan.colJunk and true or false
	if not inPlan.colJunk and b.colJunk then b.colJunk:Hide() end
	b.favColumn, b.currColumn = inPlan.colFav and true or false, inPlan.colCurr and true or false
	if not inPlan.colFav and b.colFav then b.colFav:Hide() end
	if not inPlan.colCurr and b.colCurr then b.colCurr:Hide() end
	-- The icon's own count is redundant next to a Qty column; show it only when Qty is hidden.
	b.countOnIcon = not inPlan.colQty
	b.colSig = (not InCombatLockdown()) and sig or nil
end

------------------------------------------------------------------------
-- Secure buttons
------------------------------------------------------------------------
------------------------------------------------------------------------
-- BagSmith's tooltip lines (AH Price, Marked as junk, the key hint). The
-- modern client rebuilds item tooltips on its own (when item data arrives,
-- on its refresh), which wipes lines added once on hover, so they're added
-- every time an item tooltip is built, through the game's tooltip
-- post-processing; only for tooltips owned by BagSmith's item buttons.
------------------------------------------------------------------------
function Buttons.AddTooltipExtras(tip)
	local owner = tip and tip.GetOwner and tip:GetOwner()
	local rec = owner and owner.bsItem and owner.rec
	if not rec or rec.empty then return end
	ns.AH:AddTooltipLines(tip, rec)
	ns.Junk:AddTooltipLines(tip, rec)
	ns.Marks:AddTooltipLines(tip, rec)
	if ns.Pawn then ns.Pawn:AddTooltipLines(tip, rec) end
	-- In more than one gear set: it's one item, shown in each set's section.
	local sets = ns.GearSets and ns.GearSets:Showing() and ns.GearSets:SetsOf(rec)
	if sets and #sets > 1 then
		local names = table.concat(sets, ", ", 1, #sets - 1) .. " and " .. sets[#sets]
		ns.TipLine(tip, ("In gear sets %s: one item, shown in each set."):format(names), 0.6, 0.85, 1, true)
	end
	-- A live merged row at the bank: right-click moves every stack it shows.
	-- (Saved rows, other characters' or the saved Bank sheet, can't move anything.)
	-- (1.7.2, the 1.7.2-beta2 audit's F1) Nor items that never leave the bags (Soul Shards): the same check as the move.
	if ns.atBank and rec.merged and (rec.stacks or 1) > 1 and not rec.cached and not owner.cached and rec.members and #rec.members > 1
		and not (ns.CanMoveRest and not ns.CanMoveRest(rec.itemID)) then
		ns.TipLine(tip, ("Right-click: move all %d stacks"):format(rec.stacks), 0.6, 0.85, 1)
	end
end
function Buttons.InstallTooltipHook()
	if Buttons.tooltipHook then return end
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip) if tip == GameTooltip then Buttons.AddTooltipExtras(tip) end end)
		Buttons.tooltipHook = "TooltipDataProcessor"
	elseif GameTooltip and GameTooltip.HookScript then
		GameTooltip:HookScript("OnTooltipSetItem", function(tip) Buttons.AddTooltipExtras(tip) end)
		Buttons.tooltipHook = "OnTooltipSetItem"
	end
end

local function decorateSecure(b)
	b.bsItem = true   -- tooltips owned by this button get BagSmith's lines
	-- Alt+Left-click: BagSmith's item menu (Move to Section and the marks).
	-- Left, not right: the game turns a modified right-click into a normal one
	-- (using the item) when the auto-loot key is held over a lootable item,
	-- but a modified left-click never becomes a normal click.
	b:HookScript("OnClick", function(self, button)
		if self.hasItem and ns.MarkAction then ns.MarkAction("item click") end   -- a box that follows is BagSmith's (1.2.0)
		if button == "LeftButton" and IsAltKeyDown() and self.rec and self.hasItem and ns.Sections then ns.Sections:ItemMenu(self.rec, self) end
		-- A merged row right-clicked at the bank, the mailbox or the trade window (1.2.0 for the last two): the
		-- game moved the stack behind it; the rest of that item's stacks follow.
		local where = ns.Drop and ns.Drop.Where and ns.Drop:Where()
		if button == "RightButton" and not IsModifiedClick() and where and self.rec and self.rec.merged and (self.rec.stacks or 1) > 1 and self.rec.members and ns.Drop then
			local rec = self.rec
			local fromBank = false
			for _, r in ipairs(ns.bankItems or {}) do if r.bag == rec.bag and r.slot == rec.slot then fromBank = true; break end end
			local members = {}
			for _, m in ipairs(rec.members) do members[#members + 1] = { bag = m.bag, slot = m.slot, itemID = m.itemID, count = m.count } end
			ns.Drop:MoveRest({ itemID = rec.itemID, members = members, fromBank = fromBank, name = rec.name, where = where,
				first = { bag = rec.bag, slot = rec.slot }, token = ns.Drop:NewGesture() })
		end
	end)
	-- Where a drag starts (so a drop can expand only a genuinely merged row).
	b:HookScript("OnDragStart", function(self)
		if ns.Sections and ns.Sections.NoteGesture then ns.Sections:NoteGesture() end   -- (1.4.0-beta7) a new gesture ends older drop checks
		if ns.Drop then ns.Drop:NoteDrag(self) end
	end)
	-- Before the game acts on a right-click in a trade: how many of this item the trade already holds, so the
	-- clicked stack's placement can be told from a stack that was there before (1.2.0).
	b:HookScript("OnMouseDown", function(self, button)
		if button == "RightButton" and self.rec and self.hasItem and ns.Drop and ns.Drop.NoteTradeBaseline then ns.Drop:NoteTradeBaseline(self.rec) end
		-- (1.4.0-beta5) the item about to be placed here by a click, read before the game places it; (1.4.0-beta7) and
		-- this click is a new gesture, which ends any older pending drop check
		self.placing = nil
		self.gesture = ns.Sections and ns.Sections.NoteGesture and ns.Sections:NoteGesture() or nil
		if button == "LeftButton" and CursorHasItem and CursorHasItem() and GetCursorInfo then
			local kind, id = GetCursorInfo()
			if kind == "item" then self.placing = id end
		end
	end)
	-- Into All Items: an item from a pinned custom section put down among All Items in All view leaves that section,
	-- so it stays there instead of jumping back when the window refreshes. These run after the game acts, and
	-- (1.4.0-beta6, the beta5 audit's P2s) decide by what the slot holds afterwards, never by the cursor: only an
	-- item that actually landed there counts, and it is that item, whatever the cursor did in between.
	-- (1.4.0-beta7, the beta6 audit) Each check belongs to its gesture and expects one item: for a click, the item
	-- the cursor held at mouse-down; for a drag, the item of the BagSmith row the drag started from (Drop's record of
	-- this very drag). A drag from anywhere BagSmith can't identify changes no section.
	b:HookScript("OnClick", function(self)
		local placing, gen = self.placing, self.gesture; self.placing = nil
		if placing and ns.Sections and ns.Sections.WatchAllItemsDrop then ns.Sections:WatchAllItemsDrop(self, placing, gen) end
	end)
	b:HookScript("OnReceiveDrag", function(self)
		if not (ns.Sections and ns.Sections.WatchAllItemsDrop) then return end
		local gen = ns.Sections:NoteGesture()
		local from = ns.Drop and ns.Drop.dragFrom
		if from and from.itemID and from.token == ns.Drop.gesture then ns.Sections:WatchAllItemsDrop(self, from.itemID, gen) end
	end)
	b:SetScript("OnEvent", nil); b:SetScript("OnShow", nil); b:SetScript("OnHide", nil)
	b:UnregisterAllEvents()
	local normal, pushed = b:GetNormalTexture(), b:GetPushedTexture()
	if normal then normal:SetAlpha(0) end
	if pushed then pushed:SetAlpha(0) end
	if b.icon then b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
	-- (1.5.0-beta4) the game's rarity border (on this client a white frame on common items too) is made fully
	-- transparent as well: ApplyQuality hides it, but the template's own updates show it again
	if b.IconBorder then b.IconBorder:SetAlpha(0) end
	for _, key in ipairs({ "NewItemTexture", "BattlepayItemTexture", "UpgradeIcon", "JunkIcon", "IconQuestTexture",
		"IconOverlay", "IconOverlay2", "ItemContextOverlay", "ExtendedSlot", "ExtendedOverlay", "ExtendedOverlay2", "BagIndicator", "flash", "searchOverlay" }) do
		hideRegion(b[key])
	end
	b.slotBG = b:CreateTexture(nil, "BACKGROUND")
	b.slotBG:SetAllPoints(b)
	Buttons.SetSlotArt(b.slotBG)
	b.slotBG:Hide()
	Buttons.AddFrame(b)
	b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
	local hl = b:GetHighlightTexture()
	hl:SetVertexColor(1, 1, 1, 0.08)
	hl:SetAllPoints(b)
	addText(b)
	b:SetScript("OnEnter", function(self)
		if not self.hasItem then return end
		ns:Fire("ITEM_MOUSE_ENTER", self)   -- the mouse owns this item's presentation from here (the plugin API's tooltip lease ends)
		if ns.TooltipsOK() then
			Buttons.PlaceTooltip(self)
			GameTooltip:SetBagItem(self:GetParent():GetID(), self:GetID())   -- BagSmith's lines come from the tooltip hook below
			GameTooltip:Show()
		end
		ns.Junk:RowHover(self, true); ns.Marks:RowHover(self, true)
		CursorUpdate(self)
		-- Hover for a moment to clear the "new" marker; a pass-through does not.
		if self.rec and self.rec.isNew then Buttons:StartNewDismiss(self) end
	end)
	b:SetScript("OnLeave", function(self) GameTooltip:Hide(); ResetCursor(); Buttons:CancelNewDismiss(self); ns.Junk:RowHover(self, false); ns.Marks:RowHover(self, false) end)
	applyMode(b, "row")
	-- (1.5.0-beta4) /bs debug: hovering lists any game-template piece still visible on the slot (hooked after the
	-- button's own OnEnter is set, so it isn't replaced)
	if b.HookScript then b:HookScript("OnEnter", function(self) Buttons:ReportTemplate(self) end) end
end

local function makeButton(self, bag, slot)
	local proxy = self.proxies[bag]
	local name = ("BagSmithItem%d_%d"):format(bag < 0 and (100 - bag) or bag, slot)
	local b = CreateFrame("ItemButton", name, proxy, "ContainerFrameItemButtonTemplate")
	b:SetID(slot)
	-- Never store "bagID" on the button: Blizzard's GetBagID() reads that field
	-- first, and a value written by an addon taints item use. Blizzard falls
	-- back to the proxy's C-side ID, which is taint free.
	b.smithBag, b.secure = bag, true
	decorateSecure(b)
	b:Hide()
	self.byBag[bag][slot] = b
	self.all[#self.all + 1] = b
	return b
end

function Buttons:Create(scrollChild)
	if self.created then return end
	if InCombatLockdown() then ns:Safely("createButtons", function() Buttons:Create(scrollChild) end); return end
	local maxSlots = ns.MAX_SLOTS_FLOOR
	for _, bag in ipairs(ns.ALL_BAGS) do if bag ~= ns.BANK then maxSlots = math.max(maxSlots, C_Container.GetContainerNumSlots(bag) or 0) end end
	if ns.KEYRING and type(GetKeyRingSize) == "function" then maxSlots = math.max(maxSlots, GetKeyRingSize() or 0) end
	local bankSlots = NUM_BANKGENERIC_SLOTS or 48
	self.maxSlots = maxSlots
	self.host = scrollChild
	for _, bag in ipairs(ns.ALL_BAGS) do
		local proxy = CreateFrame("Frame", nil, scrollChild)
		proxy:SetID(bag)
		proxy:SetSize(1, 1)
		proxy:SetPoint("TOPLEFT")
		self.proxies[bag] = proxy
		self.byBag[bag] = {}
		local count = (bag == ns.BANK) and math.max(bankSlots, C_Container.GetContainerNumSlots(bag) or 0) or maxSlots
		for slot = 1, count do makeButton(self, bag, slot) end
	end
	self.created = true
	ns:Debug("Created %d item buttons", #self.all)
end

function Buttons:Get(bag, slot)
	local t = self.byBag[bag]
	return t and t[slot]
end

-- The Recent section's copies: real secure item buttons (right-click use,
-- drag, links, tooltips all work), one per Recent position, created as
-- needed and reused, never recreated. A copy is pointed at its bag slot by
-- parenting it to that bag's proxy and setting its ID, which the game only
-- allows out of combat (layout never runs in combat).
-- Each window has its own copies (copyPools[owner]): the bank window's
-- redraw must never take one the bags window is showing. Buttons.recent
-- lists every copy, whichever window owns it, for the loops that touch all.
Buttons.recent = {}
Buttons.copyPools = {}
function Buttons:GetRecent(i, bag, slot, owner)
	local proxy = self.proxies[bag]
	if not proxy then return nil end
	owner = owner or "main"
	local pool = self.copyPools[owner]
	if not pool then pool = {}; self.copyPools[owner] = pool end
	local b = pool[i]
	if InCombatLockdown() then
		-- Can't create or re-point now: only reuse a copy already on this slot.
		if b and b.smithBag == bag and b:GetID() == slot then return b end
		return nil
	end
	if not b then
		local n = #self.recent + 1
		b = CreateFrame("ItemButton", ("BagSmithRecent%d"):format(n), proxy, "ContainerFrameItemButtonTemplate")
		-- As with the main pool, never store "bagID": the proxy carries the bag.
		b.secure, b.isRecentCopy, b.copyOwner = true, true, owner
		decorateSecure(b)
		b:Hide()
		self.recent[n] = b
		pool[i] = b
	end
	if b.smithBag ~= bag or b:GetParent() ~= proxy then b:SetParent(proxy) end
	if b:GetID() ~= slot then b:SetID(slot) end
	b.smithBag = bag
	return b
end

-- A bigger bag than we planned for (a 20-slot bag equipped after login):
-- create the missing buttons, out of combat only. Returns true when the bag
-- is fully covered.
function Buttons:EnsureCapacity(bag, size)
	local pool = self.byBag[bag]
	if not pool or not self.created then return false end
	if #pool >= size then return true end
	if InCombatLockdown() then
		ns:Safely("grow:" .. bag, function() Buttons:EnsureCapacity(bag, size); ns:RefreshViews(true) end)
		return false
	end
	for slot = #pool + 1, size do makeButton(self, bag, slot) end
	ns:Debug("Grew bag %d to %d buttons", bag, size)
	return true
end

-- Move a bag's proxy (and therefore its buttons) under a view's scroll child.
-- Proxies are ours, so re-parenting them out of combat is safe.
function Buttons:AttachBag(bag, host)
	local proxy = self.proxies[bag]
	if not proxy or proxy:GetParent() == host then return true end
	if InCombatLockdown() then return false end
	proxy:SetParent(host)
	proxy:ClearAllPoints()
	proxy:SetPoint("TOPLEFT")
	return true
end

------------------------------------------------------------------------
-- Cached (read-only) buttons
------------------------------------------------------------------------
local function decorateCached(b)
	b.bsItem = true   -- tooltips owned by this button get BagSmith's lines
	-- Same layering as the secure buttons: frame and slot art in BACKGROUND,
	-- the icon in ARTWORK, only the count and new-dot above it.
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.icon:SetVertexColor(1, 1, 1, 1)
	b.Count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	b.Count:SetJustifyH("RIGHT")
	b.slotBG = b:CreateTexture(nil, "BACKGROUND")
	b.slotBG:SetAllPoints(b)
	Buttons.SetSlotArt(b.slotBG)
	b.slotBG:Hide()
	Buttons.AddFrame(b)
	b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
	local hl = b:GetHighlightTexture()
	hl:SetVertexColor(1, 1, 1, 0.06)
	hl:SetAllPoints(b)
	addText(b)
	b:RegisterForClicks("AnyUp")
	b:SetScript("OnClick", function(self, button)
		if button == "LeftButton" and IsAltKeyDown() and self.rec and ns.Sections then
			ns.Sections:ItemMenu(self.rec, self)
		elseif self.rec and self.rec.link and IsModifiedClick("CHATLINK") then
			if ChatEdit_InsertLink then ChatEdit_InsertLink(self.rec.link) end
		elseif button == "RightButton" then
			-- (the Gear Sets sheet's display-only rows say where the item is)
			ns:Print(self.rec and self.rec.displayWhy or "Viewing another character. Log in as them to use items.")
		end
	end)
	b:SetScript("OnEnter", function(self)
		if not self.rec or not ns.TooltipsOK() then return end
		if not self.rec.link then
			-- A missing gear set piece: its name and where it was looked for.
			if not self.rec.displayWhy then return end
			Buttons.PlaceTooltip(self)
			ns.TipText(GameTooltip, self.rec.name or "", 1, 1, 1)
			ns.TipLine(GameTooltip, self.rec.displayWhy, nil, nil, nil, true)
			GameTooltip:Show()
			return
		end
		Buttons.PlaceTooltip(self)
		GameTooltip:SetHyperlink(self.rec.link)
		if self.rec.display and self.rec.displayWhy then ns.TipLine(GameTooltip, self.rec.displayWhy, 0.6, 0.6, 0.6, true) end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	applyMode(b, "row")
end

function Buttons:GetCached(host, i)
	local pool = self.cached[host]
	if not pool then pool = {}; self.cached[host] = pool end
	local b = pool[i]
	if not b then
		b = CreateFrame("Button", nil, host)
		decorateCached(b)
		b.secure = false
		pool[i] = b
	end
	return b
end

------------------------------------------------------------------------
-- Mirror cells: plain buttons that reflect a live bag slot. Picking up and
-- dropping items goes through C_Container.PickupContainerItem, which is not
-- protected, so a bag window can be a drop target while the secure buttons
-- stay in the main window. Using an item still needs the secure button.
------------------------------------------------------------------------
Buttons.mirrors = {}
-- Cooldowns (1.4.2): BagSmith's item buttons aren't in Blizzard's bag frames, so nothing else tells their cooldown
-- swipe when a potion or a Hearthstone goes on cooldown. It's asked when a button is filled or blanked and whenever
-- the game says cooldowns changed. Empty slots, other characters' items and display tiles show none.
function Buttons:Cooldown(b)
	local cd = b and b.Cooldown
	if not cd then return end
	local rec = b.rec
	local start, duration, enable = 0, 0, 0
	if b.hasItem and rec and not rec.empty and not rec.cached and not rec.display and rec.bag and rec.slot
		and C_Container and C_Container.GetContainerItemCooldown then
		start, duration, enable = C_Container.GetContainerItemCooldown(rec.bag, rec.slot)
	end
	start, duration = start or 0, duration or 0
	self:FitCountdown(b)
	if CooldownFrame_Set then
		CooldownFrame_Set(cd, start, duration, enable)
	elseif cd.SetCooldown then
		if duration > 0 and (enable == 1 or enable == true) then cd:SetCooldown(start, duration)
		elseif cd.Clear then cd:Clear() else cd:SetCooldown(0, 0) end
	end
end
-- Cooldown numbers (1.4.2-beta2): the game draws its countdown ("53m") at the size it uses for a full bag slot,
-- which spills out of List rows and small icons. So each button's number uses a font fitted to its icon: the widest
-- short form the game shows, measured at that size, must fit inside the picture with a margin on every side, and
-- the number stays under 40% of the icon's height. When nothing legible fits, the number hides and the sweep alone
-- shows. The numbers follow the game's own option for cooldown numbers, and a cooldown-text addon (OmniCC, tullaCC)
-- keeps full control of them.
Buttons.COUNTDOWN_SAMPLES = { "9", "59", "59m", "10h", "2d" }
Buttons.COUNTDOWN_MARGIN = 3      -- px clear of the frame on every side
Buttons.COUNTDOWN_HEIGHT = 0.40   -- of the icon's height, at most
Buttons.COUNTDOWN_MIN = 8         -- the smallest legible size
local countdownFonts = {}         -- icon size (whole px) -> font object name, or false: no number fits
local function textAddon()
	local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	if not loaded then return false end
	for _, name in ipairs({ "OmniCC", "tullaCC" }) do if loaded(name) then return true end end
	return false
end
local function gameShowsNumbers()
	local get = (C_CVar and C_CVar.GetCVarBool) or GetCVarBool
	if not get then return true end
	return get("countdownForCooldowns") ~= false
end
function Buttons:CountdownFontFor(iconSize)
	local key = math.floor((iconSize or 0) + 0.5)
	if countdownFonts[key] ~= nil then return countdownFonts[key] end
	local path = (NumberFontNormal and NumberFontNormal.GetFont and NumberFontNormal:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
	local m = self.measure
	if not m then m = UIParent:CreateFontString(nil, "OVERLAY"); m:Hide(); self.measure = m end
	local inner = key - 2 * self.COUNTDOWN_MARGIN
	local chosen = false
	for size = math.floor(key * self.COUNTDOWN_HEIGHT), self.COUNTDOWN_MIN, -1 do
		m:SetFont(path, size, "OUTLINE")
		local widest = 0
		for _, sample in ipairs(self.COUNTDOWN_SAMPLES) do
			m:SetText(sample)
			widest = math.max(widest, m:GetStringWidth() or 0)
		end
		if widest <= inner then
			local name = "BagSmithCountdown" .. size
			if not _G[name] and CreateFont then local f = CreateFont(name); f:SetFont(path, size, "OUTLINE") end
			chosen = _G[name] and name or false
			break
		end
	end
	countdownFonts[key] = chosen
	return chosen
end
-- The picture's size in px: a row's icon is set by its columns; a cell's icon fills the button inside a 2 px inset
-- (read from the button, whose size is set before it's filled, rather than the icon texture, which may not have
-- been laid out yet).
function Buttons:IconPx(b)
	if b.mode == "row" then
		local w = b.icon and b.icon.GetWidth and b.icon:GetWidth()   -- a row's icon has an explicit size
		if w and w > 0 then return w end
		return b.iconPx or ICON_ROW
	end
	return math.max(0, (b:GetWidth() or 0) - 4)
end
-- forget the fitted sizes (they depend on the font and UI scale); the next fit measures again
function Buttons:ResetCountdownFonts() countdownFonts = {} end
function Buttons:FitCountdown(b)
	local cd = b and b.Cooldown
	if not (cd and cd.SetHideCountdownNumbers) or textAddon() then return end
	local font = gameShowsNumbers() and self:CountdownFontFor(self:IconPx(b)) or false
	if font and cd.SetCountdownFont then
		if b.countdownFont ~= font then cd:SetCountdownFont(font); b.countdownFont = font end
		cd:SetHideCountdownNumbers(false)
	else
		cd:SetHideCountdownNumbers(true)
	end
end
-- (1.5.0-beta4) /bs debug: hovering a bag slot lists any piece of the game's item-button template that's still
-- visible on it (BagSmith draws its own frame; anything listed here is the game's art showing through).
function Buttons:TemplateLeftovers(b)
	local known = {}
	for _, k in ipairs({ "icon", "Count", "frameBG", "frameEdge", "qRing", "qFrame", "slotRing", "slotBG", "newDot", "junkCoin",
		"ilvlText", "pawnArrow", "linkMark", "linkCount", "stripe" }) do if b[k] then known[b[k]] = true end end
	for _, k in ipairs(COL_KEYS) do if b[k] then known[b[k]] = true end end
	for _, sep in ipairs(b.seps or {}) do known[sep] = true end
	if b.GetHighlightTexture then local h = b:GetHighlightTexture(); if h then known[h] = true end end
	local names = {}
	for k, v in pairs(b) do if type(v) == "table" and type(k) == "string" then names[v] = names[v] or k end end
	local out = {}
	if b.GetRegions then
		for _, r in ipairs({ b:GetRegions() }) do
			if r and not known[r] and r.IsShown and r:IsShown() and (not r.GetAlpha or (r:GetAlpha() or 1) > 0.01) then
				local what = (r.GetAtlas and r:GetAtlas()) or (r.GetTexture and r:GetTexture()) or (r.GetText and r:GetText()) or "?"
				out[#out + 1] = ("%s (%s)"):format(names[r] or (r.GetDebugName and r:GetDebugName()) or "unnamed", tostring(what))
			end
		end
	end
	return out
end
function Buttons:ReportTemplate(b)
	if not (ns.db and ns.db.debug and ns.Debug) then return end
	local now = GetTime and GetTime() or 0
	if b.templateReported and now - b.templateReported < 2 then return end
	b.templateReported = now
	local out = self:TemplateLeftovers(b)
	local where = b.rec and b.rec.bag and ("%s:%s"):format(tostring(b.rec.bag), tostring(b.rec.slot)) or "?"
	ns:Debug("Slot %s: %s", where, #out > 0 and ("game template pieces still visible: " .. table.concat(out, ", ")) or "no game template pieces visible")
end
-- (1.6.2-beta1) Only buttons that can be seen: the game sends this with every spell cast, and a closed window's buttons
-- keep their own shown flag, so this updated every item's cooldown in combat with the bags closed. A window that opens
-- catches its buttons up (View: OnShow). The Recent copies follow it too.
function Buttons:RefreshCooldowns()
	for _, b in ipairs(self.all or {}) do if b:IsVisible() then self:Cooldown(b) end end
	for _, b in ipairs(self.recent or {}) do if b:IsVisible() then self:Cooldown(b) end end
	for _, pool in pairs(self.mirrors or {}) do for _, b in pairs(pool) do if b:IsVisible() then self:Cooldown(b) end end end
end
ns:OnSignal("ADDON_READY", function()
	ns:On("BAG_UPDATE_COOLDOWN", function() Buttons:RefreshCooldowns() end)
	-- the game's own cooldown-numbers option changed: follow it
	ns:On("CVAR_UPDATE", function(name) if name == "countdownForCooldowns" or name == "COUNTDOWN_FOR_COOLDOWNS" then Buttons:RefreshCooldowns() end end)
end)

local function decorateMirror(b)
	-- (1.5.0-beta4) like a real bag slot: other addons that read the bag (and GetID for the slot) work here too
	b.GetBagID = function(self) return self.bag end
	-- (1.4.2) a cooldown swipe of its own (the secure buttons have the game's)
	if not b.Cooldown and CreateFrame then
		local ok, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
		if ok and cd then b.Cooldown = cd; if cd.SetAllPoints then cd:SetAllPoints(b) end end
	end
	b.bsItem = true   -- tooltips owned by this button get BagSmith's lines
	decorateCached(b)
	b:RegisterForDrag("LeftButton")
	-- (1.5.0-beta5, audit F5) every gesture in a bag window counts as a new gesture: a pending section-drop check
	-- from an older one (in the main window) is cancelled
	local function gesture() if ns.Sections and ns.Sections.NoteGesture then ns.Sections:NoteGesture() end end
	local function pickup(self)
		gesture()
		if not self.bag then return end
		if InCombatLockdown() and not CursorHasItem() then return end
		C_Container.PickupContainerItem(self.bag, self:GetID())
	end
	b:SetScript("OnClick", function(self, button)
		if button == "LeftButton" and IsAltKeyDown() and self.rec and ns.Sections then ns.Sections:ItemMenu(self.rec, self) return end
		if button == "RightButton" then
			if self.rec then ns:Print("Right-click items in the main window to use them.") end
			return
		end
		-- Shift-click, like the game's own bags (1.4.1): a link into an open chat box; otherwise split the stack.
		-- A modified click never picks the item up.
		if self.rec and self.rec.link and IsModifiedClick("CHATLINK") then
			if ChatEdit_InsertLink and ChatEdit_InsertLink(self.rec.link) then return end
		end
		if IsModifiedClick("SPLITSTACK") then
			gesture()
			if self.bag and self.rec and not CursorHasItem() and not InCombatLockdown() then
				local info = C_Container.GetContainerItemInfo(self.bag, self:GetID())
				local count = info and info.stackCount or 0
				if count > 1 and not info.isLocked then
					self.SplitStack = function(btn, split)
						if split and split > 0 and btn.bag then C_Container.SplitContainerItem(btn.bag, btn:GetID(), split) end
					end
					if StackSplitFrame and StackSplitFrame.OpenStackSplitFrame then StackSplitFrame:OpenStackSplitFrame(count, self, "BOTTOMLEFT", "TOPLEFT")
					elseif OpenStackSplitFrame then OpenStackSplitFrame(count, self, "BOTTOMLEFT", "TOPLEFT") end
				end
			end
			return
		end
		if self.rec and self.rec.link and IsModifiedClick("CHATLINK") then return end   -- (a link with no chat box open)
		pickup(self)
	end)
	b:SetScript("OnDragStart", pickup)
	b:SetScript("OnReceiveDrag", pickup)
	b:SetScript("OnEnter", function(self)
		if not self.bag then return end
		if ns.TooltipsOK() then
			Buttons.PlaceTooltip(self)
			if self.rec then GameTooltip:SetBagItem(self.bag, self:GetID()) else ns.TipText(GameTooltip, ns:BagName(self.bag), 1, 1, 1) end
			GameTooltip:Show()
		end
		CursorUpdate(self)
		-- Bag windows clear the "new" marker on hover too.
		if self.rec and self.rec.isNew then Buttons:StartNewDismiss(self) end
	end)
	b:SetScript("OnLeave", function(self) GameTooltip:Hide(); ResetCursor(); Buttons:CancelNewDismiss(self) end)
end
function Buttons:GetMirror(host, i)
	local pool = self.mirrors[host]
	if not pool then pool = {}; self.mirrors[host] = pool end
	local b = pool[i]
	if not b then
		b = CreateFrame("Button", nil, host)
		decorateMirror(b)
		b.secure, b.mirror = false, true
		pool[i] = b
	end
	return b
end

------------------------------------------------------------------------
-- Lane headers (plain buttons: collapse on click, drag to reorder)
------------------------------------------------------------------------
local function decorateLane(h)
	h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	h.text:SetPoint("LEFT", 20, 0)
	h.accent = h:CreateTexture(nil, "ARTWORK")
	h.accent:SetPoint("TOPLEFT", 0, -3); h.accent:SetPoint("BOTTOMLEFT", 0, 3); h.accent:SetWidth(3)
	h.accent:SetTexture("Interface\\Buttons\\WHITE8X8"); h.accent:SetVertexColor(1, 1, 1, 0.9)
	h.text:SetJustifyH("LEFT")
	h.sub = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	h.sub:SetPoint("RIGHT", -4, 0)
	h.sub:SetJustifyH("RIGHT")
	-- The section's item count, right after its name: "Trade Goods (11)".
	h.count = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	h.count:SetPoint("LEFT", h.text, "RIGHT", 6, 0)
	h.count:SetJustifyH("LEFT")
	-- Stacked values (see writeHeaderValues in ViewList.lua): a small table of
	-- "V:" and "AH:" labels with their amounts, right-aligned in columns.
	for _, key in ipairs({ "vLabel", "vAmt", "aLabel", "aAmt" }) do
		h[key] = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		h[key]:SetJustifyH("RIGHT")
		h[key]:Hide()
	end
	h.arrow = h:CreateTexture(nil, "OVERLAY")
	h.arrow:SetSize(12, 12)
	h.arrow:SetPoint("LEFT", 8, 0)
	h.line = h:CreateTexture(nil, "ARTWORK")
	h.line:SetPoint("BOTTOMLEFT"); h.line:SetPoint("BOTTOMRIGHT"); h.line:SetHeight(1)
	h.band = h:CreateTexture(nil, "BACKGROUND")
	h.band:SetAllPoints(); h.band:SetTexture("Interface\\Buttons\\WHITE8X8"); h.band:SetVertexColor(1, 1, 1, 0.06)
	h:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
	h:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.05)
	if ns.HoverWash then ns.HoverWash(h, 0.05) end   -- Modern: a clearer hover
	h:RegisterForDrag("LeftButton")
	h.anim = h:CreateAnimationGroup()
	h.slide = h.anim:CreateAnimation("Translation")
	h.slide:SetDuration(0.16)
	h.slide:SetSmoothing("OUT")
end

function Buttons:GetLane(host, i)
	local pool = self.lanes[host]
	if not pool then pool = {}; self.lanes[host] = pool end
	local h = pool[i]
	if not h then
		h = CreateFrame("Button", nil, host)
		decorateLane(h)
		pool[i] = h
	end
	return h
end

------------------------------------------------------------------------
-- Fill and blank. Texture/text only: safe in combat.
------------------------------------------------------------------------
-- The item level on an icon (Icons view, the setting on, gear with a real level): a small number in the icon's
-- top-right corner, drawn on ARTWORK just above the icon itself and below every OVERLAY region (quality ring,
-- count at bottom-right, junk coin at top-left, new dot at the bottom), inset inside the ring. Hidden otherwise.
-- (1.5.0) whether the item level would show on this button, for the icon corners
function Buttons:ItemLevelShows(b, rec)
	return (rec and b.mode == "cell" and ns.db and ns.db.iconItemLevel == true and (rec.ilvl or 0) > 1 and (rec.classID == 2 or rec.classID == 4)) and true or false
end
function Buttons:ItemLevel(b, rec)
	-- gear means weapons (class 2) and armor (class 4): an equip-slot string is not reliable on this client, which
	-- reports one for everything, and potions and cloth have item levels of their own
	local show = self:ItemLevelShows(b, rec)
	if show and not b.ilvlText then
		local t = b:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmall")
		if t.SetDrawLayer then t:SetDrawLayer("ARTWORK", 1) end
		t:SetPoint("TOPRIGHT", b.icon, "TOPRIGHT", -2, -1)
		if t.SetShadowOffset then t:SetShadowOffset(1, -1) end
		if t.SetShadowColor then t:SetShadowColor(0, 0, 0, 1) end
		b.ilvlText = t
	end
	if not b.ilvlText then return end
	if show then
		local r, g, bl = ns.Skins.hexToRGB(ns.db.iconItemLevelColor or "3598db")
		b.ilvlText:SetTextColor(r, g, bl, 1)
		b.ilvlText:SetText(tostring(rec.ilvl)); b.ilvlText:Show()
	else b.ilvlText:SetText(""); b.ilvlText:Hide() end
end
function Buttons:Fill(b, rec, opts)
	b.rec, b.hasItem, b.readable = rec, true, rec.isReadable
	local db = ns.db
	self:ItemLevel(b, rec)
	b.icon:Show()
	if b.slotBG and b.mode == "cell" and (ns.db and ns.db.skin) == "classic" then b.slotBG:Show() end
	if b.mode == "row" then Buttons:ApplyFrame(b) end
	if b.secure then
		SetItemButtonTexture(b, rec.icon)
		SetItemButtonCount(b, (b.mode == "row" and not b.countOnIcon) and 0 or rec.count)
		SetItemButtonQuality(b, rec.quality, rec.link, true, rec.isBound)
		SetItemButtonDesaturated(b, rec.isLocked)
	else
		b.icon:SetTexture(rec.icon)
		b.icon:SetDesaturated(rec.isLocked and true or false)
		b.Count:SetText((rec.count > 1 and (b.mode ~= "row" or b.countOnIcon)) and rec.count or "")
	end
	Buttons:ApplyQuality(b, rec)
	Buttons:Cooldown(b)   -- (1.4.2)
	if b.mode == "row" then
		local r, g, bl = 0.84, 0.83, 0.79
		if db.rtext then r, g, bl = qcolor(rec.quality) end
		b.colName:SetText(rec.name); b.colName:SetTextColor(r, g, bl)
		b.colName.baseColor = { r, g, bl }
		b.colQty:SetText(rec.count > 1 and rec.count or "")
		-- the item level only where it means something, weapons and armor with a real level (the same rule as the
		-- icon's level); "-" otherwise, so the column reads as answered rather than missing (1.1.0)
		b.colLevel:SetText(((rec.classID == 2 or rec.classID == 4) and (rec.ilvl or 0) > 1) and tostring(rec.ilvl) or "-")
		b.colReq:SetText((rec.minLevel or 0) > 1 and rec.minLevel or "")
		b.colType:SetText(ns:TypeLabel(rec))
		b.colSlot:SetText(ns:SlotText(rec))
		b.colBind:SetText(ns:BindText(rec))
		b.colValue:SetText((rec.hasNoValue or not rec.sellPrice) and "" or ns.Money(rec.sellPrice * rec.count))
		b.colWhere:SetText(rec.where or "")
		b.colAge:SetText(ns.AgeText(rec.firstSeen))
		-- AH Price: the stack's value from Auctionator's last scan, "-" when it has none.
		if ns.AH:Available() then
			local v = ns.AH:StackValue(rec)
			-- (1.6.0-beta11, Shweep) a soulbound item can't be sold there: empty, like the Vendor column for no value
			b.colAH:SetText(v and ns.Money(v) or (ns.AH:Sellable(rec) and "-" or ""))
		else
			b.colAH:SetText("")
		end
	end
	b.newDot:SetShown(db.newdot and rec.isNew or false)
	if b.kebab and b.kebabOn and not InCombatLockdown() then b.kebab:SetShown(not rec.empty); kebabAlpha(b) end
	b:SetAlpha(opts and opts.dim and 0.3 or 1)
	b.inFill = true
	if ns.Junk then ns.Junk:Decorate(b, rec) end
	Buttons:LinkMark(b, rec)
	if ns.Marks then ns.Marks:Decorate(b, rec) end
	if ns.Pawn then ns.Pawn:Decorate(b, rec) end
	b.inFill = nil
	if ns.Corners then ns.Corners:Apply(b, true) end   -- (1.5.0) icon corners: which mark shows where
	self:ApplyIconCrop(b)
end


-- An item shown in more than one gear set (one item, in each set's section):
-- a small shield at the bottom left of its icon with the number of sets it's
-- in, on every showing. Made the first time a button needs it, then only
-- shown or hidden.
Buttons.MARK_ART = "Interface\\AddOns\\BagSmith\\Media\\ui-sword-shield-mark.tga"
-- (1.5.0-beta4) about 40% of the icon, inside its corner, with the set count as a small badge on the shield's
-- upper corner (it used to be a fixed 15 px, 2 px outside the icon, with the count trailing to the right).
Buttons.SHIELD_SIZE = 0.40
-- (1.5.0-beta6) the shield image has empty margin left and right (columns 6 to 58 of 64 are drawn): it's cropped
-- to what's drawn, so the shield's visible edge is the one that sits flush in its corner.
Buttons.SHIELD_ART_X = { 6 / 64, 58 / 64 }
function Buttons:StyleShield(b, n, px)
	px = px or self:IconPx(b)
	local s = math.max(9, math.floor(px * Buttons.SHIELD_SIZE + 0.5))
	if b.linkMark.SetTexCoord then b.linkMark:SetTexCoord(Buttons.SHIELD_ART_X[1], Buttons.SHIELD_ART_X[2], 0, 1) end
	b.linkMark:SetSize(math.floor(s * (Buttons.SHIELD_ART_X[2] - Buttons.SHIELD_ART_X[1]) + 0.5), s)
	b.linkCount:ClearAllPoints(); b.linkCount:SetPoint("CENTER", b.linkMark, "TOPRIGHT", -2, -3)   -- tucked in: stays inside the quarter
	b.linkCount:SetText(tostring(n)); b.linkCount:SetTextColor(1, 1, 1)
	if b.linkCount.SetScale then b.linkCount:SetScale(0.85) end
end
function Buttons:LinkMark(b, rec)
	local GS = ns.GearSets
	local sets = rec and not rec.empty and GS and GS:Showing() and GS:SetsOf(rec)
	local n = sets and #sets or 0
	local on = n > 1
	if on and not b.linkMark then
		b.linkMark = b:CreateTexture(nil, "OVERLAY", nil, 3)
		b.linkMark:SetTexture(Buttons.MARK_ART)
		b.linkMark:SetVertexColor(1, 0.86, 0.45)
		b.linkCount = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		b.linkCount:SetJustifyH("LEFT")
	end
	b.linkOn = on   -- (1.5.0) for the icon corners
	if not b.linkMark then return end
	if on then
		b.linkMark:ClearAllPoints(); b.linkMark:SetPoint("BOTTOMLEFT", b.icon or b, "BOTTOMLEFT", 0, 0)
		Buttons:StyleShield(b, n)
	end
	b.linkMark:SetShown(on); b.linkCount:SetShown(on)
	b.linkOn = on   -- (1.5.0) for the icon corners
	-- the Pawn arrow shares the corner and rides above the shield while it shows: place it again
	if b.pawnArrow and b.pawnArrow:IsShown() and ns.Pawn and ns.Pawn.Decorate and b.hasItem then ns.Pawn:Decorate(b, b.rec) end
end
function Buttons:Blank(b, rec)
	b.rec, b.hasItem, b.readable = rec, nil, nil
	Buttons:Cooldown(b)   -- (1.4.2) an empty slot shows no cooldown
	self:ItemLevel(b, nil)
	if ns.Junk then ns.Junk:Decorate(b, nil) end
	Buttons:LinkMark(b, nil)
	if ns.Marks then ns.Marks:Decorate(b, nil) end
	if ns.Pawn then ns.Pawn:Decorate(b, nil) end
	if ns.Corners then ns.Corners:Apply(b, true) end   -- (1.5.0) an empty slot shows no corner widgets
	local classic = (ns.db and ns.db.skin or "modern") == "classic"
	if b.secure then
		SetItemButtonTexture(b, nil)
		SetItemButtonCount(b, 0)
		SetItemButtonQuality(b, nil, nil)
	else
		b.icon:SetDesaturated(false); b.Count:SetText("")
	end
	-- Empty look follows the skin, whatever kind of cell this is: Modern is
	-- the plain shaded square; Classic is Blizzard's clawed-bag slot art.
	b.icon:SetTexture(nil); b.icon:Hide()
	if b.slotBG then b.slotBG:SetShown(classic and b.mode == "cell") end
	Buttons:ApplyQuality(b, nil)
	-- A blank list row is a true gap: no shaded square, slot ring or border
	-- left behind. Icon cells keep their empty-slot look.
	if b.mode == "row" then
		if b.frameBG then b.frameBG:Hide(); b.frameEdge:Hide() end
		if b.slotRing then b.slotRing:Hide() end
		local normal = b.GetNormalTexture and b:GetNormalTexture()
		if normal then normal:SetAlpha(0) end
	end
	for _, key in ipairs(COL_KEYS) do b[key]:SetText("") end
	b.newDot:Hide()
	b:SetAlpha(1)
	if b.kebab and not InCombatLockdown() then b.kebab:Hide() end
end

-- Hide every frame we own (out of combat only).
function Buttons:HideAll()
	if InCombatLockdown() then return end
	for _, b in ipairs(self.all) do if b:IsShown() then b:Hide() end end
	for _, pool in pairs(self.cached) do for _, b in pairs(pool) do b:Hide() end end
	for _, pool in pairs(self.lanes) do for _, h in pairs(pool) do h:Hide() end end
	for _, pool in pairs(self.mirrors) do for _, b in pairs(pool) do b:Hide() end end
	for _, b in ipairs(self.recent) do if b:IsShown() then b:Hide() end end
end
