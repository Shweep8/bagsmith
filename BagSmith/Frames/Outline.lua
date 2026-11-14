-- BagSmith: the resize outline (1.7.3). Every resizable BagSmith window (the bags and bank windows, the Disenchant
-- Helper) is resized by dragging this outline, not the window itself: the window keeps its size and contents while the
-- button is held, then takes the outline's size once when it's let go. Resizing the window itself re-laid its contents
-- as the size passed through, and it flickered (1.7.3-beta1, worst in Classic), or left them stale or blank (1.7.2).
--
-- The look (1.7.3-beta3, Shweep): a light line 3 screen pixels wide with a 1-pixel dark edge outside it, so it shows on
-- any background whatever the accent color, and a faint fill. The same in both skins. (1.7.3-beta5, Shweep) The line and
-- the fill are #fffaed, a warm white (beta3: pure white).
-- It is anchored to the screen (a frame anchored to another frame leaps when sized on this client), at the window's
-- scale, so its sizes are in the window's own units, with the window's size limits. One outline serves every window:
-- only one resize happens at a time.
local ADDON, ns = ...
local Outline = {}
ns.Outline = Outline

local LINE_PX, EDGE_PX = 3, 1
Outline.COLOR = { 0xff / 255, 0xfa / 255, 0xed / 255 }   -- #fffaed

local function build()
	local o = CreateFrame("Frame", nil, UIParent)
	o:SetFrameStrata("TOOLTIP")
	o:SetClampedToScreen(true)
	o:SetMovable(true)
	o:SetResizable(true)
	o:EnableMouse(false)
	local function tex(layer)
		local t = o:CreateTexture(nil, layer)
		t:SetTexture("Interface\\Buttons\\WHITE8X8")
		return t
	end
	o.fill = tex("BACKGROUND")
	o.fill:SetAllPoints()
	local r, g, b = unpack(Outline.COLOR)
	o.fill:SetVertexColor(r, g, b, 0.06)
	o.lines, o.edges = {}, {}
	for i = 1, 4 do
		o.lines[i] = tex("ARTWORK"); o.lines[i]:SetVertexColor(r, g, b, 0.9)
		o.edges[i] = tex("BORDER"); o.edges[i]:SetVertexColor(0, 0, 0, 0.8)
	end
	-- the white lines, inside the box: top, bottom, left, right
	o.lines[1]:SetPoint("TOPLEFT"); o.lines[1]:SetPoint("TOPRIGHT")
	o.lines[2]:SetPoint("BOTTOMLEFT"); o.lines[2]:SetPoint("BOTTOMRIGHT")
	o.lines[3]:SetPoint("TOPLEFT"); o.lines[3]:SetPoint("BOTTOMLEFT")
	o.lines[4]:SetPoint("TOPRIGHT"); o.lines[4]:SetPoint("BOTTOMRIGHT")
	o:Hide()
	return o
end

-- Line widths in screen pixels at the outline's scale (set on each drag: the scale can change between them).
local function sizeLines(o)
	local px = ns.Buttons and ns.Buttons.PixelSize and ns.Buttons.PixelSize(o) or 1
	local line, edge = LINE_PX * px, EDGE_PX * px
	o.lineWidth, o.edgeWidth = line, edge
	o.lines[1]:SetHeight(line); o.lines[2]:SetHeight(line); o.lines[3]:SetWidth(line); o.lines[4]:SetWidth(line)
	-- the dark edge, just outside the box, its corners closed
	local e = o.edges
	for _, t in ipairs(e) do t:ClearAllPoints() end
	e[1]:SetPoint("BOTTOMLEFT", o, "TOPLEFT", -edge, 0); e[1]:SetPoint("BOTTOMRIGHT", o, "TOPRIGHT", edge, 0); e[1]:SetHeight(edge)
	e[2]:SetPoint("TOPLEFT", o, "BOTTOMLEFT", -edge, 0); e[2]:SetPoint("TOPRIGHT", o, "BOTTOMRIGHT", edge, 0); e[2]:SetHeight(edge)
	e[3]:SetPoint("TOPRIGHT", o, "TOPLEFT"); e[3]:SetPoint("BOTTOMRIGHT", o, "BOTTOMLEFT"); e[3]:SetWidth(edge)
	e[4]:SetPoint("TOPLEFT", o, "TOPRIGHT"); e[4]:SetPoint("BOTTOMLEFT", o, "BOTTOMRIGHT"); e[4]:SetWidth(edge)
end

function Outline:Frame()
	self.frame = self.frame or build()
	return self.frame
end

-- Starts sizing the outline over window f, from f's bottom-right corner. Returns false (nothing shown) when f's
-- place can't be read yet.
function Outline:Start(f, minW, minH, maxW, maxH)
	local L, T, w, h = f:GetLeft(), f:GetTop(), f:GetWidth(), f:GetHeight()
	if not (L and T and w and h) then return false end
	local o = self:Frame()
	if self.owner and self.owner ~= f then self:Cancel(self.owner) end
	local us = UIParent:GetEffectiveScale()
	o:SetScale((us and us > 0) and f:GetEffectiveScale() / us or 1)
	if o.SetResizeBounds then o:SetResizeBounds(minW or 1, minH or 1, maxW, maxH)
	elseif o.SetMinResize then o:SetMinResize(minW or 1, minH or 1); if maxW and o.SetMaxResize then o:SetMaxResize(maxW, maxH) end end
	sizeLines(o)
	o:ClearAllPoints()
	o:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", L, T)
	o:SetSize(w, h)
	o:Show()
	o:StartSizing("BOTTOMRIGHT")
	self.owner, self.from = f, { L, T }
	return true
end

function Outline:Active(f) return self.owner ~= nil and self.owner == f end

-- Ends f's outline: stops and hides it. Returns its size and where f's top-left was (f's units), or nil when there
-- was none (or no size to give).
function Outline:Finish(f)
	if not self:Active(f) then return nil end
	local o, from = self.frame, self.from
	self.owner, self.from = nil, nil
	o:StopMovingOrSizing()
	local w, h = o:GetWidth(), o:GetHeight()
	o:Hide()
	if not (w and h and w > 0 and h > 0) then return nil end
	return w, h, from[1], from[2]
end

function Outline:Cancel(f)
	if not self:Active(f) then return end
	self.owner, self.from = nil, nil
	self.frame:StopMovingOrSizing()
	self.frame:Hide()
end
