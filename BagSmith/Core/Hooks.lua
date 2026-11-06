--[[
	BagSmith - Core/Hooks.lua
	Makes the B key, the bag bar and merchant/bank auto-open show BagSmith
	instead of Blizzard's bags, without calling any of Blizzard's bag
	functions ourselves. Only post-hooks (hooksecurefunc) are used, which
	is the approach Bagnon has used for years without taint.

	Blizzard's individual bag frames are parked on a hidden parent when they
	are assigned a bag we manage, and the combined-bags CVar is turned off so
	the combined frame never appears for those bags.
--]]

local ADDON, ns = ...

local Hooks = {}
ns.Hooks = Hooks

local parked = CreateFrame("Frame", nil, UIParent)
parked:Hide()
Hooks.parked = parked   -- (read by the controller probe, to name this frame in its report)
local originalParent = ContainerFrameContainer or UIParent

local function managed(bag)
	if not ns.db or not ns.db.replaceBlizzardBags then return false end
	for _, b in ipairs(ns.ALL_BAGS) do
		if b == bag and b ~= ns.BANK then return true end
	end
	return false
end

function Hooks:Install()
	if self.installed then return end
	self.installed = true

	-- Park Blizzard's bag frames whenever they are (re)assigned one of our bags.
	local function onAssigned(f, bag)
		if managed(bag) then
			if f:GetParent() ~= parked then f:SetParent(parked) end
		elseif f:GetParent() == parked then
			f:SetParent(originalParent)
		end
	end
	-- Never hooksecurefunc a method on a Blizzard frame object: on this client
	-- that breaks the method (SetID and SetBagID both ended up nil). Hook the
	-- global functions that assign and lay out the bag frames instead.
	local function parkAll()
		for i = 1, (NUM_CONTAINER_FRAMES or 13) do
			local f = _G["ContainerFrame" .. i]
			if f and f.GetID then onAssigned(f, f:GetID()) end
		end
		-- Blizzard's "One Bag" window is assigned the backpack, so it parks too.
		if ContainerFrameCombinedBags and ContainerFrameCombinedBags.GetID then
			onAssigned(ContainerFrameCombinedBags, ContainerFrameCombinedBags:GetID())
		end
	end
	if type(ContainerFrame_GenerateFrame) == "function" then
		hooksecurefunc("ContainerFrame_GenerateFrame", function(frame, size, id) onAssigned(frame, id) end)
	end
	if type(UpdateContainerFrameAnchors) == "function" then
		hooksecurefunc("UpdateContainerFrameAnchors", parkAll)
	end
	if type(ContainerFrame_GenerateFrame) ~= "function" and type(UpdateContainerFrameAnchors) ~= "function" then
		ns:Debug("No global bag-frame functions to hook; Blizzard bags will not be parked")
	end

	-- The bag key. One press makes Blizzard run a chain of bag functions
	-- (ToggleAllBags calls ToggleBackpack or Open/CloseAllBags inside it), and
	-- BagSmith hears each one, innermost first. One press must be one toggle.
	-- The first hook in a chain that actually changes BagSmith's window
	-- handles the press; the rest of that chain is ignored. An inner open or
	-- close that would change nothing (BagSmith and Blizzard can disagree
	-- about whether the bags are open, after the game menu closes them
	-- directly) does not count, so the outer toggle still acts. A chain ends
	-- at the next frame.
	-- This replaced skipping calls whose call stack mentioned certain names
	-- ("Manager", "ToggleAllBags"): after the game menu, a real key press
	-- could match and be ignored while Blizzard still played its bag sound
	-- (player report: the first press after the game menu did nothing).
	local handled = false
	local function stackSummary()
		local names = {}
		for name in tostring(debugstack and debugstack() or ""):gmatch("in function [`'<]([^'>]+)") do
			if not name:find("BagSmith") then names[#names + 1] = name end
			if #names >= 4 then break end
		end
		return table.concat(names, " < ")
	end
	local function request(call, kind, bag)
		if not managed(bag or ns.BACKPACK) then return end
		local before = ns.Window:IsShown()
		local outcome
		if handled then
			outcome = "ignored (this press is already handled)"
		else
			if kind == "toggle" then ns.Window:Toggle()
			elseif kind == "open" and not before then ns.Window:Show()
			elseif kind == "close" and before then ns.Window:Hide() end
			if ns.Window:IsShown() ~= before then
				handled = true
				C_Timer.After(0, function() handled = false end)
				outcome = "acted"
			else
				outcome = "no change"
			end
		end
		if ns.db and ns.db.debug then
			ns:Debug("Bag key: %s %s; window %s -> %s (called from: %s)", call, outcome,
				before and "open" or "closed", ns.Window:IsShown() and "open" or "closed", stackSummary())
		end
	end
	Hooks.Request = request   -- for the tests

	local function hook(name, fn)
		if type(_G[name]) == "function" then hooksecurefunc(name, fn) else ns:Debug("No global %s to hook", name) end
	end
	hook("ToggleAllBags", function() request("ToggleAllBags", "toggle") end)
	hook("ToggleBackpack", function() request("ToggleBackpack", "toggle") end)
	hook("ToggleBag", function(bag) request("ToggleBag", "toggle", bag) end)
	-- The Controller UI's bag action (the HUD radial) calls ToggleBackpack_Combined
	-- directly, and in that style ToggleAllBags calls it too, so this hook sits
	-- inside the same one-press chain: the innermost hook acts and the outer
	-- one is ignored. Opening is refused when Blizzard itself would refuse it
	-- (ContainerFrame_AllowedToOpenBags: the bags-disabled game rule, no
	-- fullscreen frame, panels closed); closing is never refused.
	hook("ToggleBackpack_Combined", function()
		if not ns.Window:IsShown() and type(ContainerFrame_AllowedToOpenBags) == "function" then
			local ok, allowed = pcall(ContainerFrame_AllowedToOpenBags)
			if ok and not allowed then
				if ns.db and ns.db.debug then ns:Debug("Bag key: ToggleBackpack_Combined refused (Blizzard would not open the bags)") end
				return
			end
		end
		request("ToggleBackpack_Combined", "toggle")
	end)
	-- Direct calls: cinematics, vehicles, the game menu (CloseAllWindows).
	hook("OpenAllBags", function() request("OpenAllBags", "open") end)
	hook("CloseAllBags", function() request("CloseAllBags", "close") end)

	-- Blizzard opens the bags for you at merchants, mail, trade and the bank.
	-- Those paths run OpenAllBags inside other calls, so instead of hooking
	-- them (which double-fires with ToggleAllBags) we listen to the events.
	local autoOpened = false
	local function autoShow()
		if managed(ns.BACKPACK) and not ns.Window:IsShown() then ns.Window:Show(); autoOpened = true end
	end
	local function autoHide()
		if autoOpened and ns.Window:IsShown() then ns.Window:Hide() end
		autoOpened = false
	end
	for _, ev in ipairs({ "MERCHANT_SHOW", "MAIL_SHOW", "TRADE_SHOW", "AUCTION_HOUSE_SHOW" }) do ns:On(ev, autoShow) end
	for _, ev in ipairs({ "MERCHANT_CLOSED", "MAIL_CLOSED", "TRADE_CLOSED", "AUCTION_HOUSE_CLOSED" }) do ns:On(ev, autoHide) end

end

-- Re-evaluate every Blizzard bag frame against the current setting, so the
-- "open with keybind" toggle takes effect immediately.
function Hooks:ApplyReplace()
	if InCombatLockdown() then ns:Safely("applyReplace", function() Hooks:ApplyReplace() end); return end
	for i = 1, (NUM_CONTAINER_FRAMES or 13) do
		local frame = _G["ContainerFrame" .. i]
		if frame and frame.GetID then
			local bag = frame:GetID()
			if managed(bag) then
				if frame:GetParent() ~= parked then frame:SetParent(parked) end
			elseif frame:GetParent() == parked then
				-- Returning a frame that Blizzard still counts as open would make
				-- the next B press close it invisibly; close it now instead.
				frame:SetParent(originalParent)
				if frame:IsShown() then frame:Hide() end
			end
		end
	end
	if ContainerFrameCombinedBags and ContainerFrameCombinedBags:GetParent() == parked and not managed(ns.BACKPACK) then
		ContainerFrameCombinedBags:SetParent(originalParent)
		if ContainerFrameCombinedBags:IsShown() then ContainerFrameCombinedBags:Hide() end
	end
end


-- Addon compartment (the minimap dropdown that lists addons). Declared in
-- the TOC; the client calls this global by name.
function BagSmith_OnAddonCompartmentClick()
	ns.Window:Toggle()
end

ns:OnSignal("ADDON_READY", function()
	Hooks:Install()
end)
ns:OnSignal("SETTINGS_CHANGED", function(key)
	if key == nil or key == "replaceBlizzardBags" then Hooks:ApplyReplace() end
end)
