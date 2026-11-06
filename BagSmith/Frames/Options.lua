--[[
	BagSmith - Frames/Options.lua
	An entry under the game's Options > AddOns list. BagSmith's settings live
	in their own window, so this panel just points there: the mark, an Open
	Settings button and the other ways to get to them.
--]]

local ADDON, ns = ...
local Options = {}
ns.Options = Options

local MEDIA = "Interface\\AddOns\\BagSmith\\Media\\"

local function build()
	local panel = CreateFrame("Frame")
	panel.name = "BagSmith"

	local mark = panel:CreateTexture(nil, "ARTWORK")
	mark:SetSize(96, 96)
	mark:SetPoint("TOP", 0, -60)
	mark:SetTexture(MEDIA .. "mark128.tga")

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	title:SetPoint("TOP", mark, "BOTTOM", 0, -14)
	title:SetText("BagSmith")

	local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	button:SetSize(220, 30)
	button:SetPoint("TOP", title, "BOTTOM", 0, -22)
	button:SetText("Open Settings")
	button:SetScript("OnClick", function() Options:OpenSettings() end)

	local how = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	how:SetPoint("TOP", button, "BOTTOM", 0, -26)
	how:SetWidth(520)
	how:SetJustifyH("CENTER")
	how:SetText("You can also open settings by typing |cffffd200/bs settings|r, right-clicking the minimap button, or clicking the gear in the bag window.")

	panel.button, panel.mark = button, mark
	return panel
end

-- Close the game's Options window, then open BagSmith's settings. The game's
-- window cannot be closed safely in combat, so that waits for combat to end.
function Options:OpenSettings()
	local function go()
		if SettingsPanel and SettingsPanel:IsShown() then
			if SettingsPanel.Close then SettingsPanel:Close(true) elseif HideUIPanel then HideUIPanel(SettingsPanel) end
		end
		ns.SettingsPanel:Show()
	end
	if InCombatLockdown() then
		ns:Print("Settings will open when combat ends.")
		ns:Safely("openSettings", go)
	else
		go()
	end
end

ns:OnSignal("ADDON_READY", function()
	local panel = build()
	Options.panel = panel
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, "BagSmith")
		Settings.RegisterAddOnCategory(category)
		Options.category = category
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
end)
