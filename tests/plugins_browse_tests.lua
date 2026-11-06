;(function()
	-- Browse mode: the navigation prototype as the opt-in "Controller Browsing (beta)" setting, without the observer, with East closing the bag, tooltips, and the secure combat release modeled.
	local function forbid(name) return function() error("browse mode must not call " .. name) end end
	local function boot(opts)
		opts = opts or {}
		package.loaded.mock = nil
		local M = require("mock")
		if opts.afterMock then opts.afterMock() end
		local S = { M = M, style = "Gamepad", core = true, editFocus = nil, keysDown = {}, overrides = {}, clearCount = 0, setCount = 0, drivers = {} }
		local mgr = { shownFrames = {}, focusedFrame = nil, isUIFocused = false, fallThroughCatcherActive = false, FrameShown = forbid("FrameShown"), FrameHidden = forbid("FrameHidden") }
		S.mgr = mgr
		_G.GamepadMode = { FrameControlsManager = mgr }
		_G.GamepadSharedUtility = { InputBindingManager = { IsOnlyCoreBindingSetActive = function() return S.core end } }
		_G.SmartNavigation = setmetatable({}, { __index = function(_, k) return forbid("SmartNavigation." .. tostring(k)) end })
		_G.InputUtil = { IsGamepadUISupported = function() return true end, IsGamepadUIEnabled = function() return S.style == "Gamepad" end, IsMKBUIEnabled = function() return S.style == "Mkb" end }
		_G.Enum = _G.Enum or {}; _G.Enum.BindingContext = { GamepadModeInGameCore = 9 }
		_G.SetOverrideBindingClick = function(owner, priority, key, button, mouse)
			if S.combat then error("blocked in combat") end
			S.setCount = S.setCount + 1; S.overrides[key] = { owner = owner, action = "CLICK " .. button .. ":" .. (mouse or "LeftButton") }
		end
		_G.ClearOverrideBindings = function(owner) if S.combat then error("blocked in combat") end S.clearCount = S.clearCount + 1; for k, v in pairs(S.overrides) do if v.owner == owner then S.overrides[k] = nil end end end
		_G.GetBindingAction = function(key, override, ctx)
			if ctx == 9 then return "" end
			if override and S.overrides[key] then return S.overrides[key].action end
			return ""
		end
		-- the secure state driver, modeled: registration is recorded; "combat begins" runs the snippet's effect (a clear by the owner) outside the addon's Lua
		if not opts.noDriver then
			_G.RegisterStateDriver = function(frame, state, cond) S.drivers[#S.drivers + 1] = { frame = frame, state = state, cond = cond } end
			_G.UnregisterStateDriver = function() end
		end
		function S.combatBegins(driverFires)
			S.combat = true
			if driverFires ~= false and #S.drivers > 0 then
				local owner = S.drivers[1].frame
				for k, v in pairs(S.overrides) do if v.owner == owner then S.overrides[k] = nil end end   -- the snippet: self:ClearBindings(), in secure execution
				S.driverCleared = (S.driverCleared or 0) + 1
			end
			M.fire("PLAYER_REGEN_DISABLED")
		end
		function S.combatEnds() S.combat = false; M.fire("PLAYER_REGEN_ENABLED") end
		_G.IsKeyDown = function(key) return S.keysDown[key] and true or false end
		_G.InCombatLockdown = function() return S.combat and true or false end
		_G.GetCurrentKeyBoardFocus = function() return S.editFocus end
		_G.debugstack = function() return "stack line 1\nstack line 2" end
		_G.ContainerFrameCombinedBags = CreateFrame("Frame", "ContainerFrameCombinedBags", ContainerFrameContainer); ContainerFrameCombinedBags:Hide()
		_G.BagSmithGamepadDB = nil
		for s = 1, 6 do M.put(0, s, { id = 7000 + s, name = "Item" .. s, q = 1, count = 1, class = 0, subclass = 5, price = 1 }) end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", gamepadBrowse = opts.setting } } }
		local n = M.loadAddon("BagSmith")
		local gpns = dofile("tests/companion_loader.lua")(M, "BagSmith_Gamepad", "BagSmith_Gamepad")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("ADDON_LOADED", "BagSmith_Gamepad"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		S.n, S.GP, S.gpns = n, gpns.Gamepad, gpns
		S.item = {}
		for s = 1, 6 do
			local b = n.Buttons.byBag[0][s]; S.item[s] = b
			local col, row = (s - 1) % 3, math.floor((s - 1) / 3)
			b.GetCenter = function() return 100 + col * 40, 300 - row * 40 end
		end
		function S.ownerEvents() local f = S.GP.navOwner; if not f then return 0 end local c = 0; for _ in pairs(f.events) do c = c + 1 end return c end
		function S.press(dir) local b = S.GP.navButtons[dir]; b:GetScript("OnClick")(b, "LeftButton", true); b:GetScript("OnClick")(b, "LeftButton", false) end
		function S.ticks(k) for _ = 1, (k or 5) do M.elapse() end end
		function S.open() n.Window:Show(); M.runTimers(); M.runTimers() end
		function S.close() n.Window:Hide(); M.runTimers() end
		function S.focusSlot() local f = S.GP.nav and S.GP.nav.focus; for s = 1, 6 do if S.item[s] == f then return s end end return nil end
		function S.ours() local c = 0; for _, k in ipairs({ "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PAD2" }) do if S.overrides[k] then c = c + 1 end end return c end
		function S.sampling() return S.GP.browse ~= nil and S.GP.browse.timer ~= nil end
		return S
	end
	local function cleanup()
		_G.BagSmithGamepadDB = nil
		_G.GamepadMode, _G.GamepadSharedUtility, _G.SmartNavigation, _G.InputUtil, _G.debugstack, _G.GetBindingAction, _G.IsKeyDown, _G.InCombatLockdown, _G.GetCurrentKeyBoardFocus, _G.ContainerFrameCombinedBags = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
		_G.SetOverrideBindingClick, _G.ClearOverrideBindings, _G.RegisterStateDriver, _G.UnregisterStateDriver = nil, nil, nil, nil
		if _G.Enum then _G.Enum.BindingContext = nil end
	end

	-- off by default: opening the bag starts nothing; the setting exists and validates
	local S = boot()
	check(S.n.db.plugins["bagsmith-gamepad"] == nil and not S.GP:BrowseEnabled(), "a fresh user is opted out: no preference namespace, browsing off")
	S.open(); S.ticks(10)
	check(not S.sampling() and S.setCount == 0 and S.GP.nav == nil, "with the setting off, opening the bag binds nothing and samples nothing")
	S.close(); cleanup()
	-- on: opening the bag starts the sampler without the observer; the keys bind after five clean samples; the highlight and tooltip follow
	S = boot({ setting = true })
	check(S.n.db.plugins["bagsmith-gamepad"].data.browse == true and S.GP:BrowseEnabled() and S.GP.browseHooked, "a legacy explicit true migrated into the plugin's preference; the companion reads it and subscribes to the view at activation")
	S.open()
	check(S.sampling() and S.GP.nav and S.GP.nav.browse and S.GP.obs.state == "idle" and #S.drivers == 1 and S.drivers[1].state == "combat" and S.drivers[1].cond == "[combat] 1; 0", "opening the bag starts browse sampling with no observer; the secure combat driver is registered on the owner")
	S.ticks(5)
	check(S.GP.nav.state == "bound" and S.ours() == 5 and S.focusSlot() == 1 and S.GP.navHighlight:IsShown() and GameTooltip.owner == S.item[1] and GameTooltip.shown, "the D-pad and East bind, the highlight sits on the first item and its tooltip is shown")
	S.press("right")
	check(S.focusSlot() == 2 and GameTooltip.owner == S.item[2], "a move shows the newly focused item's tooltip")
	check(S.GP.navHighlight.points[1][2] == S.item[2] and S.GP.navHighlight:GetParent() ~= S.item[2], "the highlight is anchored inside the item's own rect, not parented into BagSmith's frames")
	-- East closes the bag; the next sample releases, verified, hides the highlight and the tooltip; sampling stops
	S.press("back")
	check(not S.n.Window.main:IsShown() and S.GP:BrowseText():find("nav: back: closing the bag", 1, true), "East closes the bag")
	S.ticks(1)
	check(S.GP.nav.state == "idle" and not S.GP.nav.installed and S.ours() == 0 and S.clearCount == 1 and not S.GP.navHighlight:IsShown() and not GameTooltip.shown, "the next sample releases all five, verified, and hides the highlight and tooltip")
	S.ticks(1)
	check(not S.sampling() and S.GP:BrowseText():find("browse: sampling stopped (window closed)", 1, true), "sampling stops once the window is closed and nothing is left to clean up")
	-- reopening starts again and reacquires
	S.open(); S.ticks(5)
	check(S.sampling() and S.GP.nav.state == "bound" and S.GP.nav.binds == 2, "reopening the bag starts sampling and reacquires")
	-- yields to another window and to text entry, reacquires after
	table.insert(S.mgr.shownFrames, S.mgr); S.core = false; S.ticks(1)
	check(S.GP.nav.state == "idle" and S.ours() == 0, "another window taking the pad releases the keys")
	S.mgr.shownFrames = {}; S.core = true; S.ticks(5)
	check(S.GP.nav.state == "bound", "and they come back when it is gone")
	S.editFocus = CreateFrame("EditBox", "BagSmithFrameSearch"); S.ticks(1)
	check(S.GP.nav.state == "idle" and S.ours() == 0, "text entry releases the keys")
	S.editFocus = nil; S.ticks(5)
	check(S.GP.nav.state == "bound", "and they come back after it")
	-- combat: the secure driver clears at combat start; the Lua side verifies by readback and makes no binding call; after combat the keys reacquire
	local clearsBefore = S.clearCount
	S.combatBegins()
	check(S.driverCleared == 1 and S.GP.nav.state == "idle" and not S.GP.nav.installed and S.ours() == 0 and S.clearCount == clearsBefore and S.GP:BrowseText():find("released by the secure combat driver at combat start, verified by readback", 1, true),
		"at combat start the driver's clear is verified by readback: no binding call from Lua, the game has its keys back")
	S.ticks(5)
	check(S.GP.nav.state == "idle" and S.setCount == 20, "in combat nothing rebinds")
	S.combatEnds(); S.ticks(5)
	check(S.GP.nav.state == "bound" and S.GP.nav.binds == 5, "after combat, with the bag still open, the keys reacquire")
	-- a combat start where the driver did not clear: pending, no binding call, verified at combat end; the limitation is reported
	S.combatBegins(false)
	check(S.GP.nav.state == "pending" and S.ours() == 5 and S.GP:BrowseText():find("the secure driver did not clear the bindings", 1, true), "if the driver does not clear, the release is pending and the report says so")
	S.combatEnds()
	check(S.GP.nav.state == "idle" and S.ours() == 0, "and it is released and verified at combat end")
	S.close(); S.ticks(2); cleanup()
	-- the driver unavailable: browse mode refuses to arm; the setting stays, nothing binds
	S = boot({ setting = true, noDriver = true })
	S.open(); S.ticks(6)
	check(S.GP.nav == nil and S.setCount == 0 and S.GP:BrowseText():find("browse mode not armed: the secure combat release could not be installed (unavailable on this client)", 1, true), "without a secure combat release available, browse mode does not bind at all")
	S.close(); cleanup()
	-- a blocked or forbidden action attributed to BagSmith ends browse mode for the session, with a verified release and one notice
	for _, which in ipairs({ "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do
		S = boot({ setting = true })
		S.open(); S.ticks(5)
		local chat0 = #S.M.log
		S.M.fire(which, "BagSmith", "SomeProtectedFunction")
		check(S.GP.browseFailed == which .. " SomeProtectedFunction" and S.GP.nav.noReacquire and not S.GP.nav.installed and S.ours() == 0 and #S.M.log == chat0 + 1 and S.M.log[#S.M.log]:find("Controller browsing stopped", 1, true), which .. ": browse mode ends with a verified release and one notice")
		S.ticks(5)
		check(not S.sampling() and S.setCount == 5, which .. ": sampling stops and nothing rebinds")
		S.close(); S.open(); S.ticks(6)
		check(S.setCount == 5, which .. ": reopening the bag does not restart browse mode until a reload")
		cleanup()
	end
	-- the observer takes precedence while it runs; browse resumes on the next open after it stops
	S = boot({ setting = true })
	S.style = "Mkb"; S.GP:Command("nav on"); S.style = "Gamepad"
	BagSmith_Observer()
	check(S.GP.obs.state == "running" and S.GP.nav and not S.GP.nav.browse, "the observer arms its own diagnostics nav")
	S.open(); S.ticks(5)
	check(not S.sampling() and S.GP.nav.state == "bound" and not S.GP.nav.browse and S.GP:ObsText():find("nav: bound D-pad and back", 1, true), "with the observer running, the bag's nav is the observer's and browse sampling does not start")
	S.press("down"); BagSmith_Observer()
	check(S.GP.obs.state == "stopped" and S.GP.nav.state == "idle", "the observer stops and releases its nav")
	S.close(); S.open(); S.ticks(5)
	check(S.sampling() and S.GP.nav.browse and S.GP.nav.state == "bound", "the next open after the observer stops resumes browse mode")
	S.press("back"); S.ticks(2); cleanup()
	-- turning the setting off releases and stops; the slash command needs the keyboard-and-mouse style
	S = boot({ setting = true })
	S.open(); S.ticks(5)
	S.GP:Command("browse off")
	check(S.GP:BrowseEnabled() and S.GP:BrowseText():find("slash command refused: style Gamepad", 1, true), "the slash command is refused in the Gamepad style")
	S.GP:SetBrowseEnabled(false)
	check(S.n.db.plugins["bagsmith-gamepad"].data.browse == false and (S.GP.nav == nil or (not S.GP.nav.installed and S.ours() == 0)), "turning the option off (the plugin's own preference) releases the keys")
	S.ticks(2)
	check(not S.sampling() and S.ours() == 0, "and stops sampling")
	S.GP:SetBrowseEnabled(true); S.ticks(6)
	check(S.sampling() and S.GP.nav and S.GP.nav.state == "bound", "turning it on with the bag open starts browse mode again")
	S.close(); S.ticks(2); cleanup()
	-- the report after browsing: GP:Text includes the browsing section without error
	S = boot({ setting = true })
	S.open(); S.ticks(5); S.press("right"); S.press("back"); S.ticks(2)
	local okT, text = pcall(function() return S.GP:Text() end)
	check(okT and type(text) == "string" and text:find("== Controller browsing (last 60 lines) ==", 1, true) and text:find("nav: back: closing the bag", 1, true), "/bs gamepad show's text includes the browsing lines after browsing, without error")
	S.style = "Mkb"; S.GP:Command("show")
	check(S.n.Popups.share and S.n.Popups.share:IsShown() and S.n.Popups.share.locked:find("Controller browsing", 1, true), "and the copy window opens with it")
	S.n.Popups.share:Hide(); cleanup()
	-- the tooltip comes back when control is reacquired, not on every tick, and goes before the focus is cleared
	S = boot({ setting = true })
	S.open(); S.ticks(5); S.press("right")
	check(GameTooltip.owner == S.item[2] and GameTooltip.shown, "(setup) the tooltip is on the focused item")
	-- the mouse takes the tooltip: ticks do not take it back
	local other = CreateFrame("Frame", "SomethingUnderTheMouse"); GameTooltip:SetOwner(other, "ANCHOR_RIGHT"); GameTooltip:Show()
	S.ticks(5)
	check(GameTooltip.owner == other and GameTooltip.shown and S.GP.nav.state == "bound", "while bound, the sampling ticks never take the tooltip back from the mouse")
	-- close and reopen: hidden on release, back on reacquisition, on the same item
	GameTooltip:SetOwner(S.item[2], "ANCHOR_RIGHT"); GameTooltip:Show()
	S.press("back"); S.ticks(1)
	check(not GameTooltip.shown and S.GP.nav.state == "idle", "closing the bag releases and hides the focused tooltip")
	S.ticks(1); S.open(); S.ticks(5)
	check(S.GP.nav.state == "bound" and S.focusSlot() == 2 and GameTooltip.owner == S.item[2] and GameTooltip.shown, "reopening reacquires and restores the focused item's tooltip")
	-- the game menu: hidden on yield, back on reacquisition
	table.insert(S.mgr.shownFrames, S.mgr); S.core = false; S.ticks(1)
	check(not GameTooltip.shown and S.GP.nav.state == "idle", "yielding to the game menu hides the tooltip")
	S.mgr.shownFrames = {}; S.core = true; S.ticks(5)
	check(S.GP.nav.state == "bound" and GameTooltip.owner == S.item[2] and GameTooltip.shown, "reacquiring after the menu restores it")
	-- text entry: the same
	S.editFocus = CreateFrame("EditBox", "BagSmithFrameSearch"); S.ticks(1)
	check(not GameTooltip.shown and S.GP.nav.state == "idle", "yielding to text entry hides the tooltip")
	S.editFocus = nil; S.ticks(5)
	check(S.GP.nav.state == "bound" and GameTooltip.owner == S.item[2] and GameTooltip.shown, "reacquiring after text entry restores it")
	-- no items remain: the owned tooltip is hidden before the focus is cleared
	for i = 1, 6 do S.item[i]:Hide() end
	S.ticks(1)
	check(S.GP.nav.focus == nil and not GameTooltip.shown and not S.GP.navHighlight:IsShown(), "when no item remains, the tooltip is hidden before the focus is cleared")
	for i = 1, 6 do S.item[i]:Show() end
	S.press("back"); S.ticks(2); cleanup()
	-- edge case 1: a close and reopen within one sample never reaches the sampler; the view lifecycle restores the presentation
	S = boot({ setting = true })
	S.open(); S.ticks(5); S.press("right")
	check(S.GP.nav.state == "bound" and S.focusSlot() == 2 and GameTooltip.owner == S.item[2] and GameTooltip.shown, "(setup) bound with the tooltip on item 2")
	local binds0 = S.GP.nav.binds
	S.n.Window:Hide()
	check(not GameTooltip.shown and not S.GP.navHighlight:IsShown() and S.GP.nav.state == "bound", "the hide drops the highlight and our tooltip at once, before any sample")
	S.n.Window:Show()
	check(S.GP.nav.state == "bound" and S.GP.nav.binds == binds0 and S.focusSlot() == 2 and S.GP.navHighlight:IsShown() and GameTooltip.owner == S.item[2] and GameTooltip.shown and S.GP:BrowseText():find("nav: focus 0:2 Item2 (view shown)", 1, true),
		"reopened before the sampler saw the close: the bound state survives and the presentation is restored on the same item from the new snapshot")
	S.ticks(3)
	check(S.GP.nav.state == "bound" and S.GP.nav.binds == binds0 and S.ours() == 5, "and sampling carries on with the keys still bound")
	S.press("down")
	check(S.focusSlot() == 5 and GameTooltip.owner == S.item[5], "moves work from the new tokens")
	S.press("back"); S.ticks(2); cleanup()
	-- edge case 2: a focused item disappearing is background resolution: the highlight moves, the mouse's tooltip is not stolen
	S = boot({ setting = true })
	S.open(); S.ticks(5); S.press("right")
	local other = CreateFrame("Frame", "UnderTheMouse"); GameTooltip:SetOwner(other, "ANCHOR_RIGHT"); GameTooltip:Show()
	S.item[2]:Hide(); S.ticks(1)
	check(S.focusSlot() ~= 2 and S.focusSlot() ~= nil and S.GP.navHighlight:IsShown() and GameTooltip.owner == other and GameTooltip.shown, "the highlight moved to the nearest item while the mouse kept its tooltip")
	S.press("down")
	check(GameTooltip.owner == S.GP.nav.focus and GameTooltip.shown, "the next controller move presents the tooltip again, intentionally")
	S.item[2]:Show(); S.press("back"); S.ticks(2); cleanup()
	-- the active latch: a refused registration leaves every controller entry point inert, with a bounded explanation
	local function refusingClient()
		_G.Enum = _G.Enum or {}; _G.Enum.AddOnEnableState = { None = 0, Some = 1, All = 2 }
		local entries = { { name = "BagSmith_Gamepad", meta = { ["X-BagSmith-Plugin"] = "bagsmith-gamepad", ["X-BagSmith-API"] = "2" } } }
		local function find(x) if type(x) == "number" then return entries[x] end for _, e in ipairs(entries) do if e.name == x then return e end end end
		_G.C_AddOns = { GetNumAddOns = function() return #entries end, GetAddOnInfo = function(x) local e = find(x); if not e then return nil end return e.name, e.name, "", true, "" end, GetAddOnMetadata = function(x, f) local e = find(x); return e and e.meta[f] end, IsAddOnLoaded = function() return true end, GetAddOnEnableState = function() return 2 end, EnableAddOn = function() end, DisableAddOn = function() end, GetAddOnDependencies = function() end }
	end
	S = boot({ setting = true, afterMock = refusingClient })
	check(S.GP.handle == nil and not S.GP.active and S.GP.inactiveReason:find("registration refused: manifest%-mismatch"), "a companion whose TOC disagrees with its manifest is refused and stays inactive")
	S.style = "Mkb"; S.GP:Command("probekey PADLSTICK"); S.GP:Command("probe on"); S.style = "Gamepad"
	local chat0 = #S.M.log
	for _ = 1, 5 do BagSmith_Observer() end
	check(S.GP.obs.state == "idle" and S.GP.probe == nil and S.setCount == 0 and #S.M.log - chat0 == 4 and S.M.log[chat0 + 1]:find("The Observer is unavailable: BagSmith Gamepad is not active", 1, true),
		"the Observer keybinding refuses while inactive, with a bounded explanation (three notices, then one closing line), and binds nothing")
	S.open(); S.ticks(8)
	check(not S.sampling() and S.setCount == 0 and S.GP.nav == nil, "opening the bag starts no browsing while inactive")
	S.close(); cleanup(); _G.C_AddOns = nil
	-- shutdown while bound out of combat: everything released, the latch down, nothing rebinds on reopen, presses do nothing
	S = boot({ setting = true })
	S.open(); S.ticks(5)
	check(S.GP.active and S.GP.nav.state == "bound" and S.ours() == 5, "(setup) active and bound")
	S.n.API:Shutdown("bagsmith-gamepad", "test fault")
	check(not S.GP.active and S.ours() == 0 and S.clearCount == 1 and not S.sampling() and S.GP.nav.noReacquire and not S.GP.navHighlight:IsShown(), "a shutdown releases the five keys, verified, stops sampling, hides the highlight and lowers the latch")
	S.ticks(6); S.press("right"); S.press("down"); S.press("back")
	check(S.setCount == 5 and S.ours() == 0 and S.n.Window.main:IsShown(), "later ticks and presses install nothing and close nothing")
	S.close(); S.open(); S.ticks(8)
	check(S.setCount == 5 and not S.sampling(), "reopening the bag after a shutdown starts nothing")
	S.GP:SetBrowseEnabled(true); S.n.Profiles:Use("P2"); S.ticks(6)
	check(S.setCount == 5 and not S.sampling(), "a profile change after a shutdown starts nothing")
	S.close(); cleanup()
	-- shutdown during a pending combat release: the listener completes the cleanup and nothing rearms, bag still open
	S = boot({ setting = true })
	S.open(); S.ticks(5)
	S.combatBegins(false)
	check(S.GP.nav.state == "pending" and S.ours() == 5, "(setup) in combat with the release pending")
	S.n.API:Shutdown("bagsmith-gamepad", "fault in combat")
	check(not S.GP.active and S.GP.nav.state == "pending" and S.ours() == 5 and S.ownerEvents() == 2, "a shutdown in combat lowers the latch, keeps the pending release and its listener, and makes no binding call")
	S.press("down")
	check(S.GP.nav.unexpected == 1 and S.GP.nav.moves == 0, "a press while pending after the shutdown is ignored and counted")
	S.combatEnds()
	check(S.ours() == 0 and S.clearCount == 1 and S.GP.nav.state == "idle" and not S.GP.nav.installed and S.ownerEvents() == 0, "at combat end the pending release runs and is verified")
	S.ticks(8)
	check(S.setCount == 5 and not S.sampling() and not S.GP.active and S.n.Window.main:IsShown(), "with the bag still open, nothing rebinds and sampling does not restart: the registry still says failed")
	for _ = 1, 4 do S.press("right") end
	check(S.setCount == 5 and S.ours() == 0, "repeated presses after the shutdown install nothing")
	S.close(); cleanup()
	-- a profile switch that turns browsing off hides the companion's tooltip and releases the keys, in that order
	S = boot({ setting = true })
	S.open(); S.ticks(5); S.press("right")
	check(GameTooltip.shown and GameTooltip.owner == S.item[2], "(setup) the companion's tooltip is shown")
	S.n.Profiles:Use("Quiet")   -- a copy of the current profile; browsing is then turned off in it
	S.GP:SetBrowseEnabled(false)
	check(not GameTooltip.shown and S.ours() == 0 and not S.GP:BrowseEnabled(), "turning browsing off in the new profile hides the tooltip and releases the keys")
	S.GP:SetBrowseEnabled(true); S.ticks(6); S.press("right")
	local other2 = CreateFrame("Frame", "MouseTarget"); GameTooltip:SetOwner(other2, "ANCHOR_RIGHT"); GameTooltip:Show()
	S.n.Profiles:Use("Default")
	check(GameTooltip.shown and GameTooltip.owner == other2, "a profile switch leaves a mouse-owned tooltip alone")
	S.close(); S.ticks(2); cleanup()
	-- the highlight lives in BagSmith's clipped overlay parent for the view, anchored to the item
	S = boot({ setting = true })
	S.open(); S.ticks(5)
	local overlay = S.GP.ctx:GetOverlayParent("main")
	check(overlay and S.GP.navHighlight:GetParent() == overlay and overlay:GetParent() == S.n.Window.main.child and S.GP.navHighlight.points[1][2] == S.item[1], "the highlight is parented to the API's overlay frame inside the list and anchored to the item, never to the item frame itself")
	S.n.Window:Hide()
	check(not S.GP.navHighlight:IsVisible(), "hiding the view hides the overlay and the highlight with it")
	S.n.Window:Show(); S.press("back"); S.ticks(2); cleanup()
	-- a real inventory refresh (BAG_UPDATE_DELAYED, the scanner, a layout, VIEW_UPDATED) with the focused slot's item replaced:
	-- the controller's tooltip for the old item goes, the focus stays on the slot as a background replacement with no tooltip
	S = boot({ setting = true })
	S.open(); S.ticks(5); S.press("right")
	local oldLease = S.GP.nav.tooltipLease
	check(oldLease and S.n.API:TooltipLeaseValid(oldLease) and GameTooltip.shown and GameTooltip.owner == S.item[2], "(setup) a controller lease on item 2's tooltip")
	S.M.put(0, 2, { id = 7999, name = "Replacement", q = 1, count = 1, class = 0, subclass = 5, price = 1 })
	S.M.fire("BAG_UPDATE_DELAYED"); S.M.runTimers(); S.M.runTimers()
	check(not S.n.API:TooltipLeaseValid(oldLease) and not GameTooltip.shown, "after the refresh the old lease is gone and the stale controller tooltip is hidden")
	check(S.focusSlot() == 2 and S.GP.nav.focusCand.name == "Replacement" and S.GP.nav.tooltipLease == nil and S.GP:BrowseText():find("item replaced in place", 1, true), "the focus is the replacement in the same slot, as a background change with no tooltip")
	S.press("down")
	check(GameTooltip.shown and GameTooltip.owner == S.GP.nav.focus, "the next controller move presents a tooltip again")
	S.M.put(0, 2, { id = 7002, name = "Item2", q = 1, count = 1, class = 0, subclass = 5, price = 1 })
	S.press("back"); S.ticks(2); cleanup()
	-- the same refresh with a mouse-owned tooltip: untouched
	S = boot({ setting = true })
	S.open(); S.ticks(5); S.press("right")
	S.item[5]:GetScript("OnEnter")(S.item[5])   -- the mouse took the tooltip (another item)
	check(GameTooltip.shown and GameTooltip.owner == S.item[5] and S.GP.nav.tooltipLease and not S.n.API:TooltipLeaseValid(S.GP.nav.tooltipLease), "(setup) the mouse owns the tooltip; the controller's lease already ended")
	S.M.put(0, 2, { id = 7999, name = "Replacement", q = 1, count = 1, class = 0, subclass = 5, price = 1 })
	S.M.fire("BAG_UPDATE_DELAYED"); S.M.runTimers(); S.M.runTimers()
	check(GameTooltip.shown and GameTooltip.owner == S.item[5] and S.focusSlot() == 2, "the refresh leaves the mouse's tooltip alone while the focus follows the replacement")
	S.M.put(0, 2, { id = 7002, name = "Item2", q = 1, count = 1, class = 0, subclass = 5, price = 1 })
	S.press("back"); S.ticks(2); cleanup()
	-- the companion's own option, through the real Options page: the box shows the saved state and follows toggles
	S = boot({ setting = true })
	local P = S.n.SettingsPanel
	local function gpBox() for _, w in ipairs(P.pools.check) do if w:IsShown() and w.onSet then return w end end end
	local function userClick(box) if not box:IsEnabled() then return false end box:SetChecked(not box:GetChecked()); box:GetScript("OnClick")(box); return true end
	P:Show(); P:ShowPluginOptions("bagsmith-gamepad", "BagSmith_Gamepad")
	check(gpBox() and gpBox().text.text == "Controller browsing (alpha)" and gpBox().box:GetChecked() == true and gpBox().box:IsEnabled(), "with browsing on, the Gamepad option shows checked")
	check(userClick(gpBox().box) and not S.GP:BrowseEnabled() and gpBox().box:GetChecked() == false, "unticking it turns browsing off and the redraw shows it unchecked")
	check(userClick(gpBox().box) and S.GP:BrowseEnabled() and gpBox().box:GetChecked() == true, "ticking it turns browsing on and the redraw shows it checked")
	P:Hide(); cleanup()
	S = boot()
	P = S.n.SettingsPanel
	P:Show(); P:ShowPluginOptions("bagsmith-gamepad", "BagSmith_Gamepad")
	check(gpBox() and gpBox().box:GetChecked() == false and gpBox().box:IsEnabled(), "a fresh user's option shows unchecked and usable")
	P:Hide(); cleanup()
	-- audit finding 4: entering the Controller UI with the bag already open starts opted-in browsing (no reopen needed)
	S = boot({ setting = true })
	S.close(); S.ticks(3)   -- (the harness starts with the window shown; the game starts with it closed)
	check(not S.sampling(), "(setup) bag closed, nothing sampling")
	S.style = "Mkb"
	S.open(); S.ticks(6)
	check(not S.sampling() and S.setCount == 0, "(setup) in the keyboard-and-mouse style the open bag starts nothing and binds nothing")
	S.style = "Gamepad"; S.M.fire("GAME_PAD_ACTIVE_CHANGED", true); S.ticks(10)
	check(S.sampling() and S.GP.nav.state == "bound" and S.ours() == 5 and S.GP:BrowseText():find("sampling started (style transition)", 1, true), "switching into the Gamepad UI with the bag open starts browsing and binds")
	local t1 = S.GP.browse.timer
	S.M.fire("GAME_PAD_ACTIVE_CHANGED", true); S.M.fire("GAME_PAD_ACTIVE_CHANGED", true)
	check(S.GP.browse and S.GP.browse.timer == t1 and S.GP.nav.binds == 1, "repeated transition events start no second sampler (the timer captured before them is still the one) and bind nothing twice")
	S.press("back"); S.ticks(2)
	-- the latches still rule the transition path
	S.n.API:Shutdown("bagsmith-gamepad", "test")
	S.open(); S.style = "Mkb"; S.ticks(2); S.style = "Gamepad"; S.M.fire("GAME_PAD_ACTIVE_CHANGED", true); S.ticks(8)
	check(not S.sampling() and S.setCount == 5, "after a shutdown a style transition starts nothing")
	S.close(); cleanup()
	-- mouse and keyboard untouched; the highlight takes no input; the item buttons keep their scripts
	S = boot({ setting = true })
	S.open(); S.ticks(5)
	check(S.item[1].scripts.OnClick and S.GP.navHighlight ~= S.item[1] and S.M.hooks["FrameShown"] == nil, "item buttons keep their own OnClick; the highlight is a separate frame; no native hook")
	S.close(); S.ticks(2); cleanup()
end)()

