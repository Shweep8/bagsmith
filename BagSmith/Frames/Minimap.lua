--[[
	BagSmith - Frames/Minimap.lua
	The minimap button. Made the standard way, through LibDataBroker-1.1 and
	LibDBIcon-1.0 (embedded in Libs), so UI addons and minimap button managers
	(MayronUI, ElvUI, SexyMap, button bags) can fade, hide or collect it like
	other addons' buttons. Left-click opens the bags, right-click opens
	Settings; drag it around the minimap. "Show Minimap Button" hides it, and
	"Fade Minimap Button" shows it only while the pointer is over the minimap
	(LibDBIcon's own show-on-mouseover). The addon compartment entry (declared
	in the TOC) always remains. If the libraries are somehow missing, the old
	hand-made button is used instead.
--]]

local ADDON, ns = ...
local Minimap_ = {}
ns.MinimapButton = Minimap_

local function position(b)
	local angle = math.rad(ns.db.minimapAngle or 220)
	local r = (Minimap:GetWidth() / 2) + 5
	b:ClearAllPoints()
	b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

function Minimap_:Create()
	if self.button or not Minimap then return end
	local b = CreateFrame("Button", "BagSmithMinimapButton", Minimap)
	b:SetSize(32, 32)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetSize(54, 54)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(24, 24)
	bg:SetPoint("CENTER", 0, 1)
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetVertexColor(0, 0, 0, 1)
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER", 0, 1)
	icon:SetTexture("Interface\\AddOns\\BagSmith\\Media\\minimap.tga")
	b.icon = icon
	b:SetScript("OnClick", function(_, button)
		if button == "RightButton" then ns.SettingsPanel:Toggle() else ns.Window:Toggle() end
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		ns.TipText(GameTooltip, "BagSmith")
		ns.TipLine(GameTooltip, "Left-click: open bags", 1, 1, 1)
		ns.TipLine(GameTooltip, "Right-click: settings", 1, 1, 1)
		ns.TipLine(GameTooltip, "Drag to move around the minimap", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function(btn)
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			cx, cy = cx / scale, cy / scale
			local angle = math.deg(math.atan2(cy - my, cx - mx))
			if angle < 0 then angle = angle + 360 end
			ns:Set("minimapAngle", angle, true)
			position(btn)
		end)
	end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	self.button = b
	self:Update()
end

-- The hand-made button's own update (used only if the libraries are missing).
function Minimap_:UpdateOwn()
	if not self.button then return end
	if ns.db.minimap then position(self.button); self.button:Show() else self.button:Hide() end
end

------------------------------------------------------------------------
-- The standard way: LibDataBroker + LibDBIcon
------------------------------------------------------------------------
local NAME = "BagSmith"

-- LibDBIcon reads and writes a small table; this one reads and writes
-- BagSmith's own settings, so profiles, Show Minimap Button and the saved
-- position keep working exactly as before.
local extra = {}
local iconDB = setmetatable({}, {
	__index = function(_, k)
		if k == "hide" then return not ns.db.minimap
		elseif k == "minimapPos" then return ns.db.minimapAngle
		elseif k == "showOnMouseover" then return ns.db.minimapFade end
		return extra[k]
	end,
	__newindex = function(_, k, v)
		if k == "minimapPos" then
			if type(v) == "number" then ns:Set("minimapAngle", (v % 360), true) end
		elseif k == "hide" then
			ns:Set("minimap", not v)
		else
			extra[k] = v
		end
	end,
})

function Minimap_:CreateLDB()
	local LibStub = rawget(_G, "LibStub")
	local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
	local icon = LibStub and LibStub("LibDBIcon-1.0", true)
	if not (ldb and icon) then return false end
	local obj = ldb:GetDataObjectByName(NAME) or ldb:NewDataObject(NAME, {
		type = "launcher",
		text = "BagSmith",
		icon = "Interface\\AddOns\\BagSmith\\Media\\minimap.tga",
		OnClick = function(_, button)
			if button == "RightButton" then ns.SettingsPanel:Toggle() else ns.Window:Toggle() end
		end,
		OnTooltipShow = function(tip)
			ns.TipLine(tip, "BagSmith")
			ns.TipLine(tip, "Left-click: open bags", 1, 1, 1)
			ns.TipLine(tip, "Right-click: settings", 1, 1, 1)
			ns.TipLine(tip, "Drag to move around the minimap", 0.6, 0.6, 0.6)
		end,
	})
	if not obj then return false end
	if not icon:IsRegistered(NAME) then icon:Register(NAME, obj, iconDB) end
	self.lib, self.ldbIcon = icon, true
	self.button = icon:GetMinimapButton(NAME)
	self:Update()
	return true
end

function Minimap_:Update()
	if self.ldbIcon then
		self.lib:Refresh(NAME, iconDB)   -- position and shown/hidden from the settings
		self.lib:ShowOnEnter(NAME, ns.db.minimapFade and true or false)
		return
	end
	self:UpdateOwn()
end

ns:OnSignal("ADDON_READY", function()
	if not Minimap_:CreateLDB() then Minimap_:Create() end
end)
ns:OnSignal("SETTINGS_CHANGED", function(key)
	if key == nil or key == "minimap" or key == "minimapAngle" or key == "minimapFade" then Minimap_:Update() end
end)
