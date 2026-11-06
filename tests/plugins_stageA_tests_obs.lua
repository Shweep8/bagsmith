;(function()
	-- 1.0.0 Stage A (probe): controller diagnostics read capabilities and log events, and change nothing.
	package.loaded.mock = nil
	local M = require("mock")
	-- A deterministic serializer for the saved-data check (sorted keys, recursive). The test fails if it's missing.
	local function ser(v, seen)
		local t = type(v)
		if t ~= "table" then return t .. ":" .. tostring(v) end
		seen = seen or {}
		if seen[v] then return "<cycle>" end
		seen[v] = true
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		local out = {}
		for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. ser(v[k], seen) end
		return "{" .. table.concat(out, ",") .. "}"
	end
	check(ser({ a = { b = "x" } }) ~= ser({ a = { b = "y" } }) and ser({ a = 1, b = 2 }) == ser({ b = 2, a = 1 }), "(self-check) the comparator detects a same-length value change and ignores key order")
	local function forbid(name) return function() error("Stage A must not call " .. name) end end
	_G.GamepadMode = { FrameControlsManager = { FrameShown = forbid("FrameShown"), FrameHidden = forbid("FrameHidden"), GetActiveFrame = forbid("GetActiveFrame"), IsFrameSuspended = forbid("IsFrameSuspended") } }
	_G.SmartNavigation = { HandlePanelOpen = forbid("HandlePanelOpen"), RefreshButtonGroups = forbid("RefreshButtonGroups"), SetUseGridNavigation = forbid("SetUseGridNavigation"),
		SetWrapping = forbid("SetWrapping"), SetTargetButtonForFrame = forbid("SetTargetButtonForFrame"), TrySelectButton = forbid("TrySelectButton"), GetCurrentButton = forbid("GetCurrentButton"), Click = forbid("Click"), RightClick = forbid("RightClick") }
	_G.SmartNavigation_MarkFrameIgnored = forbid("SmartNavigation_MarkFrameIgnored")
	_G.SetOverrideBinding, _G.SetOverrideBindingClick, _G.SetBinding, _G.SaveBindings = forbid("SetOverrideBinding"), forbid("SetOverrideBindingClick"), forbid("SetBinding"), forbid("SaveBindings")
	_G.SetCVar = forbid("SetCVar"); _G.C_CVar = { SetCVar = forbid("C_CVar.SetCVar"), GetCVar = function() return nil end }
	_G.GetCVar = function(name) return name == "GamePadEnable" and "0" or nil end
	_G.GetBuildInfo = function() return "1.60.1", "70450", "Oct 16 2026", 16001 end
	_G.C_GamePad = { IsEnabled = function() return true end, GetActiveDeviceID = function() return 0 end, GetAllDeviceIDs = function() return { 0 } end,
		GetDeviceMappedState = function() return { name = "Fake Pad", labelStyle = "Xbox", buttons = {}, axes = {}, sticks = {} } end,
		ButtonIndexToBinding = function(i) return ({ [0] = "PAD1", [1] = "PAD2" })[i] end }
	_G.C_InputInterfaceStyle = { GetCurrentStyle = function() return 1 end }
	_G.Enum = _G.Enum or {}; _G.Enum.InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 }
	_G.InputUtil = { IsGamepadUISupported = function() return true end, IsGamepadUIEnabled = function() return false end, IsMKBUIEnabled = function() return true end }
	_G.IsUsingGamepad = function() return false end; _G.IsUsingMouse = function() return true end
	_G.C_EventUtils = { IsEventValid = function(name) return name:find("^GAME_PAD_") ~= nil and name ~= "GAME_PAD_POWER_CHANGED" end }
	_G.BagSmithCharDB = { version = 1, firstSeen = {}, junkMarks = { [1] = true } }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local core = M.loadAddon("BagSmith")
	local gpns = dofile("tests/companion_loader.lua")(M, "BagSmith_Gamepad", "BagSmith_Gamepad")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("ADDON_LOADED", "BagSmith_Gamepad"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local n = setmetatable({ Gamepad = gpns.Gamepad }, { __index = core })   -- (the test reads core state through n, the companion through n.Gamepad)
	local function saved() return ser(_G.BagSmithDB) .. "|" .. ser(_G.BagSmithCharDB) end
	local savedBefore = saved()
	local hooksBefore = 0; for _ in pairs(M.hooks) do hooksBefore = hooksBefore + 1 end
	check(n.Gamepad and n.Gamepad.log == nil and n.Gamepad.PROBE == gpns.version, "(setup) the probe exists, identifies itself, and holds no log until asked")
	n.Gamepad:Command("")
	local text = n.Gamepad:Text()
	check(text:find("BagSmith Gamepad " .. gpns.version .. " (a BagSmith companion, API 1.0)", 1, true), "the log's first line names the companion and its version, and the API it runs on")
	local tocf = io.open("BagSmith_Gamepad/BagSmith_Gamepad.toc"); local toc = tocf and tocf:read("*a") or ""; if tocf then tocf:close() end
	check(toc:find("## X%-BagSmith%-Plugin: bagsmith%-gamepad\n") and toc:find("## X%-BagSmith%-API: 1\n") and toc:find("## Dependencies: BagSmith\n") and toc:find("## SavedVariables: BagSmithGamepadDB\n"), "the companion's TOC declares the plugin marker, the API major, the dependency and its own saved variable")
	local coreToc = io.open("BagSmith/BagSmith.toc"):read("*a")
	check(not coreToc:find("Gamepad%.lua") and not coreToc:find("X%-BagSmith%-Probe"), "the core TOC no longer loads a controller runtime or carries the probe field")
	check(text:find("build: version 1.60.1, build 70450, Oct 16 2026, interface 16001", 1, true), "all four GetBuildInfo values are kept")
	check(text:find("project: WOW_PROJECT_ID=", 1, true) and text:find("button bindings: 0:PAD1 1:PAD2", 1, true) and text:find("GamepadMode.FrameControlsManager.FrameShown: function", 1, true)
		and text:find("event GAME_PAD_ACTIVE_CHANGED: true", 1, true) and text:find("event INPUT_DEVICE_INTERFACE_TRANSITION: false", 1, true),
		"the snapshot records the project, binding names, the native surface by presence only, and event validity")
	check(text:find("capture: GAME_PAD_ACTIVE_CHANGED registered", 1, true) and text:find("capture: GAME_PAD_POWER_CHANGED not valid on this client", 1, true)
		and text:find("capture: INPUT_DEVICE_INTERFACE_TRANSITION not valid on this client", 1, true) and text:find("capture: started, 60 s, 4 events", 1, true),
		"each event's registration outcome is logged, valid ones registered and invalid ones named")
	local f = n.Gamepad.frame
	check(f and not f:IsShown() and f.events["GAME_PAD_ACTIVE_CHANGED"] and not f.events["GAME_PAD_POWER_CHANGED"] and not f.events["INPUT_DEVICE_INTERFACE_TRANSITION"], "the capture frame is hidden and registers only what the client called valid")
	-- a repeat while capturing changes nothing
	local before, lines, token = n.Gamepad:Text(), #n.Gamepad.log, n.Gamepad.token
	n.Gamepad:Command("")
	check(n.Gamepad:Text() == before and #n.Gamepad.log == lines and n.Gamepad.token == token and n.Gamepad.capturing, "a repeated /bs gamepad while capturing is rejected and leaves the active log and timer alone")
	M.fire("GAME_PAD_ACTIVE_CHANGED", true); M.fire("GAME_PAD_CONNECTED")
	check(n.Gamepad:Text():find("event GAME_PAD_ACTIVE_CHANGED true", 1, true), "events are logged with their arguments")
	for _ = 1, 500 do M.fire("GAME_PAD_ACTIVE_CHANGED", false) end
	check(#n.Gamepad.log == 400 and n.Gamepad:Text():find("(log full: later events were dropped)", 1, true), "events are capped at 400 lines and the log says so")
	-- stop, then restart: a fresh capture with a new deadline, and the old timer is void
	n.Gamepad:Command("stop")
	check(not n.Gamepad.capturing and next(f.events) == nil and n.Gamepad:Text():find("capture: stopped (stop)", 1, true), "stop ends the capture and unregisters everything")
	n.Gamepad:Command("")
	check(n.Gamepad.capturing and #n.Gamepad.log < 100 and n.Gamepad.token ~= token, "after stop, a new command starts a fresh log and capture with its own timer")
	M.runTimers()   -- both the old (void) and the new timers fire
	local _, stops = n.Gamepad:Text():gsub("capture: stopped %(time's up%)", "")
	check(not n.Gamepad.capturing and stops == 1 and next(f.events) == nil, "only the live timer stops the capture; the old one does nothing")
	local hooksAfter = 0; for _ in pairs(M.hooks) do hooksAfter = hooksAfter + 1 end
	check(hooksAfter == hooksBefore, "no hooks were installed")
	-- show, clear while shown, and the share window's other modes
	n.Gamepad:Command("show")
	local w = n.Popups.share
	check(w and w:IsShown() and w.mode == "text" and w.locked == n.Gamepad:Text() and w.title.text == "Controller Diagnostics", "show opens the existing share window in a read-only text mode holding the log")
	w.edit:SetText("tampered"); w.edit:GetScript("OnTextChanged")(w.edit, true)
	check(w.edit.text == n.Gamepad:Text(), "the window keeps the log as it is")
	n.Gamepad:Command("clear")
	check(n.Gamepad.log == nil and w.locked:find("BagSmith Gamepad", 1, true), "clear drops the log; the copy window keeps the text it was opened with (show opens it again with the current text)")
	n.ShareWindow("share")
	check(w.mode == "share" and w.locked ~= "" and not w.locked:find("controller diagnostics", 1, true) and w.title.text:find("Share Profile", 1, true), "profile share still shows a profile code")
	n.ShareWindow("import")
	check(w.mode == "import" and w.locked == nil and w.edit.text == "" and w.ok:IsShown(), "import still starts empty and editable")
	n.Gamepad:Command("clear")
	check(w.mode == "import" and w.edit.text == "", "clear leaves the import window alone")
	w:Hide()
	check(saved() == savedBefore, "saved data is byte-for-byte unchanged across snapshot, capture, show and clear")
	n.Gamepad:Command(""); M.fire("PLAYER_LOGOUT")
	check(n.Gamepad.log == nil and not n.Gamepad.capturing, "logout drops the log and stops any capture")
	savedBefore = saved()   -- (BagSmith's own logout handler writes saved data; that is baseline behavior, measured from here on)
	-- registration failure without a validator: the error is logged, not swallowed
	_G.C_EventUtils = nil
	M.unknownEvents = { GAME_PAD_POWER_CHANGED = true, INPUT_DEVICE_INTERFACE_TRANSITION = true, INPUT_DEVICE_INTERFACE_STYLE_CHANGED = true }
	n.Gamepad:Command("")
	check(n.Gamepad:Text():find("capture: GAME_PAD_POWER_CHANGED register failed:", 1, true) and n.Gamepad:Text():find("capture: started, 60 s, 4 events", 1, true), "without a validator, a failed registration is logged by name")
	n.Gamepad:Command("clear")
	-- nothing registers: the log says nothing is monitored, and no capture runs
	for _, e in ipairs({ "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED", "GAME_PAD_CONFIGS_CHANGED", "GAME_PAD_ACTIVE_CHANGED" }) do M.unknownEvents[e] = true end
	n.Gamepad:Command("")
	check(not n.Gamepad.capturing and n.Gamepad:Text():find("capture: no events registered; nothing is being monitored", 1, true), "when nothing can be registered the log says so and no capture pretends to run")
	M.unknownEvents = nil
	n.Gamepad:Command("clear")
	-- a client without any of it: the snapshot still completes
	_G.C_GamePad, _G.C_InputInterfaceStyle, _G.InputUtil, _G.GamepadMode, _G.SmartNavigation, _G.IsUsingGamepad = nil, nil, nil, nil, nil, nil
	n.Gamepad:Command("")
	check(n.Gamepad:Text():find("C_GamePad absent", 1, true) and n.Gamepad:Text():find("GamepadMode: absent", 1, true), "with nothing present, the snapshot reports absence rather than failing")
	n.Gamepad:Command("clear")
	check(saved() == savedBefore, "saved data is still unchanged at the end")
	_G.SetOverrideBinding, _G.SetOverrideBindingClick, _G.SetBinding, _G.SaveBindings, _G.SetCVar, _G.GetCVar, _G.GetBuildInfo, _G.C_EventUtils = nil, nil, nil, nil, nil, nil, nil, nil
end)()

