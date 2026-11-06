--[[
	BagSmith - Core/Skins.lua
	Two skins built from Blizzard's own textures. Every frame draws through
	ns.Skins:Apply so a skin change never touches layout code.
--]]

local ADDON, ns = ...
local Skins = {}
ns.Skins = Skins

Skins.list = {
	modern = {
		bg = { 0.10, 0.095, 0.08, 0.985 }, border = { 0.36, 0.33, 0.28, 1 },
		edge = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, inset = 3,
		text = { 0.84, 0.83, 0.79 }, muted = { 0.56, 0.55, 0.51 }, heading = { 0.93, 0.91, 0.88 },
		accent = { 0.98, 0.78, 0.46 }, line = { 0.23, 0.22, 0.2, 1 }, chip = { 0.15, 0.145, 0.13, 1 },
		font = "GameFontHighlightSmall", headingFont = "GameFontNormal",
	},
	classic = {
		bg = { 0.11, 0.09, 0.06, 0.985 }, border = { 0.62, 0.48, 0.2, 1 },
		edge = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24, inset = 6,
		text = { 0.84, 0.83, 0.79 }, muted = { 0.6, 0.55, 0.45 }, heading = { 0.98, 0.78, 0.46 },
		accent = { 0.98, 0.78, 0.46 }, line = { 0.32, 0.25, 0.12, 1 }, chip = { 0.17, 0.14, 0.09, 1 },
		font = "GameFontHighlightSmall", headingFont = "GameFontNormal",
	},
}

function Skins:Current()
	return self.list[ns.db and ns.db.skin or "modern"] or self.list.modern
end

function Skins:ApplyBackdrop(frame)
	local s = self:Current()
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = s.edge, edgeSize = s.edgeSize,
		insets = { left = s.inset, right = s.inset, top = s.inset, bottom = s.inset },
	})
	frame:SetBackdropColor(unpack(s.bg))
	frame:SetBackdropBorderColor(unpack(s.border))
end

local function hexToRGB(hex)
	hex = (hex or "fac775"):gsub("^#", "")
	local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
	if not (r and g and b) then return 0.98, 0.78, 0.46 end
	return r / 255, g / 255, b / 255
end
Skins.hexToRGB = hexToRGB
Skins.DEFAULT_ACCENT = "fac775"

function Skins:Accent()
	return hexToRGB(ns.db and ns.db.accent or "fac775")
end

function Skins:Color(kind)
	if kind == "accent" then local r, g, b = self:Accent(); return r, g, b, 1 end
	if kind == "heading" and ns.db and ns.db.skin == "classic" then local r, g, b = self:Accent(); return r, g, b, 1 end
	local c = self:Current()[kind] or self:Current().text
	return c[1], c[2], c[3], c[4] or 1
end

-- Registry so every skinned frame refreshes on a skin change.
local registry = {}
function Skins:Register(frame, fn)
	registry[frame] = fn
	fn(frame)
end
function Skins:RefreshAll()
	for frame, fn in pairs(registry) do fn(frame) end
end
-- Repaints everything registered inside one window (the window included).
-- Classic calls this as its very last step when it turns off, so Modern's
-- colors are always painted after Classic has stepped aside, whatever order
-- the skin change reached the pieces in.
function Skins:RefreshWithin(root)
	for frame, fn in pairs(registry) do
		local x = frame
		while x and x ~= root do x = x.GetParent and x:GetParent() or nil end
		if x == root then fn(frame) end
	end
end
ns:OnSignal("SETTINGS_CHANGED", function(key)
	if key == nil or key == "skin" or key == "accent" then Skins:RefreshAll() end
end)
