;(function()
	-- BagSmith Gamepad 0.1.1-alpha: the 1.4.0-beta5 audit's two companion findings, as the auditor wrote them
	-- (audit_gamepad_regressions.lua, adopted with its REPRO prints removed): read-only nav and probe queries must not
	-- fail the companion, and a first start in combat must begin browsing when combat ends with the bag still open.
	-- Fails on 0.1.0-alpha (4 checks).
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


	local S = boot()
	S.style = "Mkb"
	check(S.GP.ctx:GetState() == "active", "setup active")
	S.n.API:DispatchCommand("gamepad", "nav on")
	check(S.GP.probeConfig ~= nil and S.GP.probeConfig.key == nil, "nav creates a keyless configuration")
	S.n.API:DispatchCommand("gamepad", "probe")
	check(S.GP.ctx:GetState() == "active", "querying probe status after nav on should not fail the plugin")
	cleanup()

	S = boot()
	S.style = "Mkb"; S.n.API:DispatchCommand("gamepad", "nav off")
	S.n.API:DispatchCommand("gamepad", "probe")
	check(S.GP.ctx:GetState() == "active", "querying probe status after nav off should not fail the plugin")
	cleanup()

	S = boot()
	S.style = "Mkb"; S.n.API:DispatchCommand("gamepad", "nav")
	S.n.API:DispatchCommand("gamepad", "probe")
	check(S.GP.ctx:GetState() == "active", "two read-only diagnostics queries should not fail the plugin")
	cleanup()

	S = boot()
	S.close(); S.ticks(2)
	S.combat = true
	S.GP:SetBrowseEnabled(true)
	S.open(); S.ticks(5)
	S.combatEnds(); S.ticks(10)
	check(S.sampling() and S.GP.nav and S.GP.nav.state == "bound" and S.ours() == 5, "first open in combat must start opted-in browsing when combat ends with bag still open")
	S.close(); S.open(); S.ticks(5)
	check(S.GP.nav and S.GP.nav.state == "bound", "workaround close/reopen restores browsing")
	cleanup()
end)()
