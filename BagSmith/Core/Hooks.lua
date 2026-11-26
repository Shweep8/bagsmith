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

-- The bags BagSmith stands in for, whatever the setting says. (1.10.1-beta1: split from managed, so Settings can
-- tell which of the game's bag keys open BagSmith.)
local function covers(bag)
	for _, b in ipairs(ns.ALL_BAGS) do
		-- (1.7.5-beta1) Forever's keyring (-1) stays Blizzard's: its keyring button opens Blizzard's keyring window,
		-- as it did when -1 was taken for the bank. The keys also show in BagSmith's bags, in Keys.
		if b == bag and b ~= ns.BANK and not (ns.KEYRING_WAS_BANK and b == ns.KEYRING_WAS_BANK) then return true end
	end
	return false
end
Hooks.Covers = covers
local function managed(bag)
	if not ns.db or not ns.db.replaceBlizzardBags then return false end
	return covers(bag)
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
	-- (1.10.1-beta2) BagSmith's window is open because one of the game's windows opened (a vendor, the mail, a trade,
	-- the auction house, a bank): it closes with that window. False for bags the player opened, and again whenever
	-- the window closes, however it closes.
	local autoOpened = false
	-- What the window was before this frame's first bag call acted: open or shut, and opened for a window or not.
	local frameWasOpen, frameWasAuto
	-- The rest of this frame's bag calls belong to what was just handled.
	local function settle(wasOpen, wasAuto)
		if not handled then frameWasOpen, frameWasAuto = wasOpen, wasAuto end
		handled = true
		C_Timer.After(0, function() handled = false; frameWasOpen, frameWasAuto = nil, nil end)
	end
	ns:OnSignal("MAIN_HIDDEN", function() autoOpened = false end)
	-- (1.11.0-beta2, Shweep: "auto open with, and then list out all the places that BagSmith auto opens when you go
	-- to and default them all to true", the lighter form) Each place BagSmith opens the bags at has its own switch
	-- (Settings > Automations), and the game's window for each is known by name, so that window's OpenAllBags and
	-- CloseAllBags can be told from another's. A window not listed here is followed as it always was.
	local PLACE_SETTING = { vendor = "autoOpenVendor", mail = "autoOpenMail", trade = "autoOpenTrade", ah = "autoOpenAH", bank = "autoOpenBank", guildbank = "autoOpenGuildBank" }
	local WINDOW_PLACE = { MerchantFrame = "vendor", MailFrame = "mail", TradeFrame = "trade", AuctionHouseFrame = "ah", AuctionFrame = "ah", BankFrame = "bank", GuildBankFrame = "guildbank" }
	local function opensAt(place) return not place or not PLACE_SETTING[place] or ns.db[PLACE_SETTING[place]] ~= false end
	local function placeOf(frame)
		if type(frame) ~= "table" or type(frame.GetName) ~= "function" then return nil end
		local ok, name = pcall(frame.GetName, frame)
		return ok and type(name) == "string" and WINDOW_PLACE[name] or nil
	end
	Hooks.OpensAt, Hooks.PlaceOf = opensAt, placeOf
	local function stackSummary()
		local names = {}
		for name in tostring(debugstack and debugstack() or ""):gmatch("in function [`'<]([^'>]+)") do
			if not name:find("BagSmith") then names[#names + 1] = name end
			if #names >= 4 then break end
		end
		return table.concat(names, " < ")
	end
	-- opener (1.10.1-beta1): the call came from one of the game's own windows asking for the bags (a vendor, the
	-- mail, a trade, the auction house: OpenAllBags(thatWindow)). The bags end open for it, whatever a toggle inside
	-- the same call did to BagSmith's window a moment before: when the game believes its own bags are shut, its
	-- OpenAllBags runs ToggleBackpack and ToggleBag, and BagSmith hears those first. The bag key's own OpenAllBags
	-- names no window, so the first press after the game menu still acts as it did.
	-- (1.10.1-beta2, Shweep: "keep it as it is but add a setting default (true) for that so players can turn it off")
	-- A window's CloseAllBags(thatWindow) closes BagSmith whether BagSmith opened for it or the player had the bags
	-- open already: as it always has, now behind Auto-Close Bags I Opened (on). Off, it only closes bags that opened
	-- for a window (autoOpened), which is the game's own rule for its bags. The bag key, Escape and the X never ask.
	-- (1.11.0-beta2) place: which of the listed places the window is, when it is one. With Auto-Open off there, its
	-- OpenAllBags opens nothing: bags that were shut stay shut (and are shut again if the game's own toggle, inside
	-- that call, had just opened them), while bags the player had open are put back as they were. And leaving follows
	-- the "when I leave" choice: Always Close, Close If Auto-Opened (1.10.1's switch, off), or Never Close.
	local function request(call, kind, bag, opener, place)
		if not managed(bag or ns.BACKPACK) then return end
		local before, wasAuto = ns.Window:IsShown(), autoOpened
		local leaving = ns.db.closeOnLeave
		local outcome
		if opener and kind == "open" and not before then
			local restoring = handled and frameWasOpen   -- this frame's toggle had just shut bags that were open
			if restoring or opensAt(place) then
				ns.Window:Show()
				-- open for that window, unless they were the player's own bags: those are his again
				if restoring then autoOpened = frameWasAuto and true or false else autoOpened = true end
				outcome = "opened for the game's window"
			else
				outcome = "left shut (Auto-Open is off for this window)"
			end
			settle(before, wasAuto)
		elseif opener and kind == "close" and before and (leaving == "never" or (leaving == "auto" and not autoOpened)) then
			outcome = leaving == "never" and "left open (When I Leave is Never Close)" or "left open (bags you opened yourself)"
			autoOpened = false   -- (left open: they are the player's from here)
		elseif handled then
			outcome = "ignored (this press is already handled)"
			-- the game's toggle inside a window's OpenAllBags opened BagSmith in this frame: open for that window, or,
			-- with Auto-Open off there, shut again
			if opener and kind == "open" and before and frameWasOpen == false then
				if opensAt(place) then autoOpened = true
				else ns.Window:Hide(); outcome = "shut again (Auto-Open is off for this window)" end
			end
		else
			if kind == "toggle" then ns.Window:Toggle()
			elseif kind == "open" and not before then ns.Window:Show()
			elseif kind == "close" and before then ns.Window:Hide() end
			if ns.Window:IsShown() ~= before then
				settle(before, wasAuto)
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
	hook("OpenAllBags", function(frame) request("OpenAllBags", "open", nil, frame ~= nil, placeOf(frame)) end)
	-- (1.11.0-beta3, Shweep in game: "Never close doesn't seem to work at a mailbox, worked at vendor though") The
	-- vendor, the bank and the auction house close the bags naming themselves; the mail window's close names no window,
	-- which is the call Escape and the game menu make, so BagSmith took it for one of those and closed whatever When I
	-- Leave said. A close with no window that comes as the mail window goes (mailLeaving, below) is the mailbox's.
	local mailLeaving
	hook("CloseAllBags", function(frame)
		if frame == nil and mailLeaving then return request("CloseAllBags (the mail window's)", "close", nil, true, "mail") end
		request("CloseAllBags", "close", nil, frame ~= nil, placeOf(frame))
	end)

	-- Blizzard opens the bags for you at merchants, mail, trade and the bank.
	-- Those paths run OpenAllBags inside other calls, so instead of hooking
	-- them (which double-fires with ToggleAllBags) we listen to the events.
	-- (1.10.1-beta1, a player's report: no bags at a vendor, though the bag key opened BagSmith; his /bs debug read
	-- "ToggleBag acted; window open -> closed", called from the vendor window's OpenAllBags) Where BagSmith hears
	-- the event before the game's window has opened its own bags, the game's OpenAllBags came next, toggled the
	-- backpack, and BagSmith took that toggle as a press of the bag key and shut the window it had just opened. So
	-- the game's bag calls for the rest of this frame are not presses: BagSmith is open for the window, or was
	-- already. (A window that shows a frame or more later is covered by "opener" in request, above.)
	-- (1.11.0-beta2) place: with Auto-Open off for it, nothing opens; the frame is settled all the same, so the game's
	-- own toggle for that window doesn't open the bags either. And with When I Leave on Never Close, nothing closes.
	-- (1.11.0-beta3, Shweep: "1", Always Close closes at every place) Leaving follows When I Leave here too: Always
	-- Close closes the bags whether they opened for the place or were open already, Close If Auto-Opened only the
	-- first, Never Close neither. Before, bags the player already had open were only closed where the game's own
	-- window did it (a vendor, the mailbox, the bank, the auction house), so after a trade or the guild bank, which
	-- BagSmith follows by itself, they stayed open under Always Close. A place is left once for each visit: the game
	-- sends some of these events twice, and some with no visit before them.
	local visiting = {}
	local function autoShow(place)
		if not managed(ns.BACKPACK) then return end
		if place then visiting[place] = true end
		local before, wasAuto = ns.Window:IsShown(), autoOpened
		if not before and opensAt(place) then ns.Window:Show(); autoOpened = true end
		settle(before, wasAuto)
	end
	local function autoHide(place)
		if place then
			if not visiting[place] then return end
			visiting[place] = nil
		end
		if managed(ns.BACKPACK) and ns.Window:IsShown() then
			local leaving = ns.db.closeOnLeave
			if leaving == "always" or (leaving ~= "never" and autoOpened) then ns.Window:Hide() end
		end
		autoOpened = false
	end
	-- (1.10.1-beta2) The bank opens the bags from Window.lua (BANK_OPENED), and on Forever the game's bank window asks
	-- for them too: the same care as autoShow. Bags still open a frame after the bank has closed were not closed with
	-- it, so they are the player's from then on, as they always were.
	-- (1.11.0-beta2) opened: whether the bank did open them (Auto-Open at the Bank)
	function Hooks.OpenedFor(wasShut, opened)
		if not managed(ns.BACKPACK) then return end
		visiting.bank = true
		local wasAuto = autoOpened
		if wasShut and opened ~= false then autoOpened = true end
		settle(not wasShut, wasAuto)
	end
	-- (1.11.0-beta3) the bank closing follows When I Leave like the rest (on Forever the game's bank window had
	-- already closed them under Always Close; a bank that asks the game for nothing now does the same)
	ns:OnSignal("BANK_CLOSED", function() autoHide("bank") end)
	Hooks.AutoOpened = function() return autoOpened end   -- for the tests
	for ev, place in pairs({ MERCHANT_SHOW = "vendor", MAIL_SHOW = "mail", TRADE_SHOW = "trade", AUCTION_HOUSE_SHOW = "ah" }) do
		ns:On(ev, function() autoShow(place) end)
	end
	for ev, place in pairs({ MERCHANT_CLOSED = "vendor", MAIL_CLOSED = "mail", TRADE_CLOSED = "trade", AUCTION_HOUSE_CLOSED = "ah" }) do
		ns:On(ev, function() autoHide(place) end)
	end
	-- (1.11.0-beta3) The mail window going: its own hide (which comes just before its close of the bags, in the same
	-- call) and the game's MAIL_CLOSED. For a moment after either, a close that names no window is the mailbox's; a new
	-- visit ends it at once. The window is the game's own and may load after BagSmith: followed when it is first seen.
	local function mailGoing()
		local token = {}
		mailLeaving = token
		C_Timer.After(0.5, function() if mailLeaving == token then mailLeaving = nil end end)
	end
	local function followMail()
		local f = _G.MailFrame
		if type(f) ~= "table" or not f.HookScript or Hooks.mailFollowed then return end
		Hooks.mailFollowed = true
		f:HookScript("OnHide", function() if managed(ns.BACKPACK) then mailGoing() end end)
	end
	Hooks.FollowMail = followMail   -- for the tests
	followMail()
	ns:On("MAIL_SHOW", function() mailLeaving = nil; followMail() end)
	ns:On("MAIL_CLOSED", function() if managed(ns.BACKPACK) then mailGoing() end end)
	Hooks.MailLeaving = function() return mailLeaving ~= nil end   -- for the tests

	-- (1.8.0-beta23, Shweep, after FlareUI's notes) The guild bank: Forever doesn't open the bags with it, as it does at a
	-- vendor. BagSmith follows its window (Blizzard's, loaded on demand) the way it follows a vendor: shown, the bags
	-- open; closed, they close again, unless they were open already. The window rather than an event: its events differ
	-- between clients, and this is how FlareUI does it on Forever.
	local function followGuildBank()
		local f = _G.GuildBankFrame
		if type(f) ~= "table" or not f.HookScript or Hooks.guildBankFollowed then return end
		Hooks.guildBankFollowed = true
		-- Auto Travel Mode first (Window.lua), so the bags open full
		f:HookScript("OnShow", function() ns:Fire("GUILD_BANK_OPENED"); autoShow("guildbank") end)
		f:HookScript("OnHide", function() autoHide("guildbank"); ns:Fire("GUILD_BANK_CLOSED") end)
	end
	Hooks.FollowGuildBank = followGuildBank   -- for the tests
	local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	if type(loaded) == "function" and loaded("Blizzard_GuildBankUI") then followGuildBank() end
	ns:On("ADDON_LOADED", function(name) if name == "Blizzard_GuildBankUI" then followGuildBank() end end)

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
