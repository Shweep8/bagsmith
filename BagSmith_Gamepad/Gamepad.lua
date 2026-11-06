--[[
	Gamepad: Stage A diagnostics only (1.0.0 controller work, probe build).

	What this file does: reads what the client offers for controllers and
	keeps a bounded, in-memory log of controller events for one minute, for
	you to copy out of a read-only window.

	What this file never does: it registers no frame with the native
	navigation, installs no hooks, captures no input, changes no binding,
	CVar, UI style or saved data, and activates nothing. It creates one
	plain frame of its own, only to receive the game's gamepad events, and
	that frame unregisters everything when the capture stops. The log lives
	in a Lua table only: it is dropped on stop plus clear, on logout, and it
	never touches BagSmithDB or BagSmithCharDB.

	Commands (hidden, not in /bs help):
	  /bs gamepad          capability snapshot, then a 60 s event capture
	  /bs gamepad show     the log in a read-only copy window
	  /bs gamepad stop     end the capture early (events unregistered)
	  /bs gamepad clear    drop the log
]]
local ADDON, ns = ...
local GP = {}
ns.Gamepad = GP
_G.BagSmithGamepad = ns   -- (the companion's namespace, for its own tests and tooling; not a public contract)
ns.PLUGIN_ID, ns.HOST = "bagsmith-gamepad", "BagSmith"
ns.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "dev"
-- The companion's own small helpers. BagSmith's own namespace is not ours: nothing of it is used here;
-- every read of BagSmith's state goes through the plugin context (GP.ctx) from BagSmith.API.
function ns:Print(fmt, ...) local msg = (select("#", ...) > 0) and fmt:format(...) or fmt; if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("|cffd9a33cBagSmith Gamepad:|r " .. msg) else print("BagSmith Gamepad: " .. msg) end end
function ns:Debug() end
local eventFrame = CreateFrame("Frame")
local handlers = {}
eventFrame:SetScript("OnEvent", function(_, name, ...) local list = handlers[name]; if list then for _, fn in ipairs(list) do fn(...) end end end)
function ns:On(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn); eventFrame:RegisterEvent(name) end
local pendingFrame = {}
function ns:NextFrame(key, fn) pendingFrame[key] = fn; C_Timer.After(0, function() local f = pendingFrame[key]; if f then pendingFrame[key] = nil; f() end end) end
GP.ctx = nil
-- The active latch: true only between a successful activation by BagSmith.API and the first shutdown or
-- failure. Every controller entry point (browsing, the Observer, probe and navigation arming, binding
-- installation, profile-triggered starts, combat-end reacquisition) requires it. Cleanup of bindings already
-- installed never requires it, and never reactivates anything.
GP.active = false
GP.inactiveReason = "not yet activated by BagSmith"
local GATE_MESSAGES = 3
local gateMessages = 0
function GP:Gate(what)
	if self.active then return true end
	if gateMessages < GATE_MESSAGES then
		gateMessages = gateMessages + 1
		ns:Print("%s is unavailable: BagSmith Gamepad is not active (%s). See Settings > Plugins.", what, tostring(self.inactiveReason))
		if gateMessages == GATE_MESSAGES then ns:Print("(no further notices this session)") end
	end
	return false
end
local function viewOpen() local ctx = GP.ctx; if not ctx then return false end local st = ctx:GetViewState("main"); return st ~= nil and st.open == true end
-- The companion's saved variable: the diagnostics report and key configuration (large and temporary, outside
-- profile sharing), plus the one-time copy of the legacy BagSmithProbeReport (see Gamepad-migration.md).
local function db() if type(BagSmithGamepadDB) ~= "table" then BagSmithGamepadDB = { version = 1 } end return BagSmithGamepadDB end
local function reportGet() return db().report end
local function reportSet(v) db().report = v end

local MAX_LINES, CAPTURE_SECONDS = 400, 60
local BROWSE_LINES = 60   -- the browse-mode ring shown by /bs gamepad show (declared here: GP:Text uses it)
local EVENTS = { "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED", "GAME_PAD_CONFIGS_CHANGED", "GAME_PAD_POWER_CHANGED", "GAME_PAD_ACTIVE_CHANGED" }
-- Names the research brief gave for the native style change; the snapshot
-- records whether this client knows each one. None is registered blindly.
local STYLE_EVENT_CANDIDATES = { "INPUT_DEVICE_INTERFACE_TRANSITION", "INPUT_DEVICE_INTERFACE_STYLE_CHANGED" }

local function stamp() return (GetTime and GetTime()) or 0 end
-- Events are capped at MAX_LINES (later ones are dropped, and the window
-- says so); the few control lines (snapshot, start, stop) always land.
local function put(force, fmt, ...)
	local log = GP.log
	if not log then return end
	if not force and #log >= MAX_LINES then log.full = true; return end
	log[#log + 1] = ("%8.2f  %s"):format(stamp(), (select("#", ...) > 0) and fmt:format(...) or fmt)
end
local function add(fmt, ...) put(true, fmt, ...) end       -- control lines
local function event(fmt, ...) put(false, fmt, ...) end    -- capped
local function has(path)
	local v = _G
	for part in path:gmatch("[^.]+") do
		if type(v) ~= "table" then return nil end
		v = v[part]
	end
	return v
end
local function describe(path)
	local v = has(path)
	return v == nil and "absent" or type(v)
end
-- Every return value is kept (GetBuildInfo has four); nils stay in place.
local function pack(...) return { n = select("#", ...), ... } end
local function safe(fn, ...)
	local r = pack(pcall(fn, ...))
	if r[1] then return unpack(r, 2, r.n) end
	return "error: " .. tostring(r[2])
end


-- The device part of the snapshot (read only), repeated when a pad connects:
-- the first read can precede the device being reported.
function GP:DeviceSnapshot(when)
	add("device (%s): C_GamePad %s", when, describe("C_GamePad"))
	if type(C_GamePad) == "table" then
		add("  IsEnabled: %s; active device: %s", tostring(C_GamePad.IsEnabled and safe(C_GamePad.IsEnabled)), tostring(C_GamePad.GetActiveDeviceID and safe(C_GamePad.GetActiveDeviceID)))
		local ids = C_GamePad.GetAllDeviceIDs and safe(C_GamePad.GetAllDeviceIDs)
		add("  devices: %s", type(ids) == "table" and tostring(#ids) or tostring(ids))
		if C_GamePad.GetDeviceMappedState then
			local dev = C_GamePad.GetActiveDeviceID and safe(C_GamePad.GetActiveDeviceID)
			local st = type(dev) == "number" and safe(C_GamePad.GetDeviceMappedState, dev)
			if type(st) == "table" then
				add("  mapped state: name=%s labelStyle=%s buttons=%s axes=%s sticks=%s", tostring(st.name), tostring(st.labelStyle),
					type(st.buttons) == "table" and tostring(#st.buttons) or "?", type(st.axes) == "table" and tostring(#st.axes) or "?", type(st.sticks) == "table" and tostring(#st.sticks) or "?")
			else
				add("  mapped state: %s", tostring(st))
			end
		end
		if C_GamePad.ButtonIndexToBinding then
			local names = {}
			for i = 0, 31 do
				local n = safe(C_GamePad.ButtonIndexToBinding, i)
				if type(n) == "string" and n ~= "" then names[#names + 1] = i .. ":" .. n end
			end
			add("  button bindings: %s", #names > 0 and table.concat(names, " ") or "none")
		end
	end
	add("  IsUsingGamepad: %s; IsUsingMouse: %s", tostring(IsUsingGamepad and safe(IsUsingGamepad)), tostring(IsUsingMouse and safe(IsUsingMouse)))
end

-- The capability snapshot: every read guarded, nothing written.
GP.PROBE = ns.version   -- the diagnostics build identity written into reports: the companion's own version
function GP:Snapshot()
	local probe = (C_AddOns and C_AddOns.GetAddOnMetadata and safe(C_AddOns.GetAddOnMetadata, ADDON, "X-BagSmith-Probe")) or (GetAddOnMetadata and safe(GetAddOnMetadata, ADDON, "X-BagSmith-Probe"))
	add("BagSmith Gamepad %s (a BagSmith companion, API %s): controller diagnostics, Stage A", tostring(ns.version), GP.ctx and "1.0" or "none", tostring(probe))
	if GetBuildInfo then
		local v, build, date, interface = safe(GetBuildInfo)
		add("build: version %s, build %s, %s, interface %s", tostring(v), tostring(build), tostring(date), tostring(interface))
	end
	add("project: WOW_PROJECT_ID=%s CAMELOT=%s MAINLINE=%s", tostring(WOW_PROJECT_ID), tostring(WOW_PROJECT_CAMELOT), tostring(WOW_PROJECT_MAINLINE))
	-- native style (read only)
	add("C_InputInterfaceStyle: %s; GetCurrentStyle: %s", describe("C_InputInterfaceStyle"), tostring(has("C_InputInterfaceStyle.GetCurrentStyle") and safe(C_InputInterfaceStyle.GetCurrentStyle)))
	local enumT = has("Enum.InputDeviceInterfaceType")
	if type(enumT) == "table" then
		local parts = {}
		for k, v in pairs(enumT) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(v) end
		table.sort(parts)
		add("Enum.InputDeviceInterfaceType: %s", table.concat(parts, " "))
	else
		add("Enum.InputDeviceInterfaceType: absent")
	end
	add("InputUtil.IsGamepadUISupported: %s; IsGamepadUIEnabled: %s; IsMKBUIEnabled: %s",
		tostring(has("InputUtil.IsGamepadUISupported") and safe(InputUtil.IsGamepadUISupported)),
		tostring(has("InputUtil.IsGamepadUIEnabled") and safe(InputUtil.IsGamepadUIEnabled)),
		tostring(has("InputUtil.IsMKBUIEnabled") and safe(InputUtil.IsMKBUIEnabled)))
	add("CVar GamePadEnable=%s InputDeviceInterfaceStyle=%s (read only)", tostring(GetCVar and safe(GetCVar, "GamePadEnable")), tostring(GetCVar and safe(GetCVar, "InputDeviceInterfaceStyle")))
	self:DeviceSnapshot("at start")
	-- the native navigation surface (presence only; nothing is called on it)
	for _, path in ipairs({
		"GamepadMode", "GamepadMode.FrameControlsManager", "GamepadMode.FrameControlsManager.FrameShown", "GamepadMode.FrameControlsManager.FrameHidden",
		"GamepadMode.FrameControlsManager.GetActiveFrame", "GamepadMode.FrameControlsManager.IsFrameSuspended",
		"SmartNavigation", "SmartNavigation.HandlePanelOpen", "SmartNavigation.RefreshButtonGroups", "SmartNavigation.SetUseGridNavigation", "SmartNavigation.SetWrapping",
		"SmartNavigation.SetTargetButtonForFrame", "SmartNavigation.TrySelectButton", "SmartNavigation.GetCurrentButton", "SmartNavigation.Click", "SmartNavigation.RightClick",
		"SmartNavigation_MarkFrameIgnored", "SmartNavigation_SetButtonFrame",
		"GamepadSharedUtility.CreatePromptedBinding", "GamepadSharedUtility.CreatePromptedBindingFooter", "GamepadSharedUtility.CreateMoreActionsPromptedBinding",
		"InputDeviceIconSetManager.GetActiveInputDeviceIconSet", "InputDeviceIconSetManager.RegisterActiveInputDeviceIconSetUpdatedCallback",
	}) do
		add("  %s: %s", path, describe(path))
	end
	for _, name in ipairs(STYLE_EVENT_CANDIDATES) do
		local valid = has("C_EventUtils.IsEventValid") and safe(C_EventUtils.IsEventValid, name)
		add("  event %s: %s", name, tostring(valid))
	end
	for _, name in ipairs(EVENTS) do
		local valid = has("C_EventUtils.IsEventValid") and safe(C_EventUtils.IsEventValid, name)
		add("  event %s: %s", name, tostring(valid))
	end
end

-- One minute of controller events, then everything is unregistered.
function GP:Start()
	if self.capturing then return end
	local f = self.frame
	if not f then
		f = CreateFrame("Frame")   -- plain, unnamed, never shown; receives events only
		f:Hide()
		f:SetScript("OnEvent", function(_, name, ...)
			local args = {}
			for i = 1, select("#", ...) do args[i] = tostring((select(i, ...))) end
			event("event %s %s", name, table.concat(args, " "))
			-- The first snapshot can precede the device: read it again on connection.
			if name == "GAME_PAD_CONNECTED" then GP:DeviceSnapshot("on connect") end
		end)
		self.frame = f
	end
	-- Each event is validated where the client can say, then registered;
	-- the outcome is logged per event, so an empty capture can never pass
	-- for a quiet one.
	local registered = 0
	local validator = has("C_EventUtils.IsEventValid") and C_EventUtils.IsEventValid or nil
	local function try(name)
		if validator then
			local valid = safe(validator, name)
			if valid ~= true then add("capture: %s not valid on this client (%s)", name, tostring(valid)); return end
		end
		local ok, ret = pcall(f.RegisterEvent, f, name)
		-- (a client may refuse by return value rather than by error)
		if ok and ret == false then add("capture: %s refused (RegisterEvent returned false)", name)
		elseif ok then registered = registered + 1; add("capture: %s registered%s", name, ret == nil and " (no return value)" or "")
		else add("capture: %s register failed: %s", name, tostring(ret)) end
	end
	for _, name in ipairs(EVENTS) do try(name) end
	for _, name in ipairs(STYLE_EVENT_CANDIDATES) do try(name) end
	if registered == 0 then
		add("capture: no events registered; nothing is being monitored")
		return
	end
	self.capturing = true
	self.deadline = stamp() + CAPTURE_SECONDS
	add("capture: started, %d s, %d events", CAPTURE_SECONDS, registered)
	local token = (self.token or 0) + 1
	self.token = token
	C_Timer.After(CAPTURE_SECONDS, function() if self.token == token then self:Stop("time's up") end end)
end

function GP:Stop(why)
	if not self.capturing then return end
	self.capturing = false
	self.token = (self.token or 0) + 1   -- the old timer is void
	if self.frame then self.frame:UnregisterAllEvents() end
	add("capture: stopped (%s)", why or "stop")
	ns:Print("Controller diagnostics captured: /bs gamepad show to copy, /bs gamepad clear to drop.")
end

function GP:Clear()
	self:Stop("clear")
	self.log = nil
	-- (the copy window shows the text it was opened with; /bs gamepad show opens it again with the current text)
end

function GP:Text()
	local log = self.log
	local out
	if not log then out = "Stage A diagnostics capture: none in memory (type /bs gamepad to collect one). The observer's report, if any, follows."
	else
		out = table.concat(log, "\n")
		if log.full then out = out .. "\n(log full: later events were dropped)" end
	end
	if #self.obs.log > 0 then out = out .. "\n\n== Observer ==\n" .. self:ObsText() end
	local r = self.obs.restored
	if r then out = out .. ("\n\n== Observer (restored from the saved report: %s, saved on %s) ==\n"):format(r.state or "?", tostring(r.how)) .. r.text end
	local cs = self:ActiveCleanupStatus()
	if cs then out = out .. "\n\n== Probe cleanup (kept apart from the observer's log, which may be frozen) ==\n" .. cs end
	local bt = self:BrowseText()
	if bt then out = out .. ("\n\n== Controller browsing (last %d lines) ==\n"):format(BROWSE_LINES) .. bt end
	if r and r.probeCleanup then out = out .. "\n\n== Probe cleanup (from the saved report) ==\n" .. tostring(r.probeCleanup) end
	return out
end


------------------------------------------------------------------------
-- Probe A: read-only observation of the existing BagSmith window under the
-- Controller UI.
--
-- What it does: for one observation, bounded by a wall-clock deadline, it
-- reads native state and BagSmith state every 0.1 s and logs the changes,
-- with a full snapshot at start and at a normal stop (including the
-- binding readback for every pad key). It is started and stopped by one
-- game keybinding ("BagSmith: Observer (test build)"), pressed in the
-- Controller UI, so no slash command is typed there; it also stops by
-- itself at the first execution opportunity at or after the deadline. No
-- timer can run while the game is frozen, so nothing is promised then.
--
-- What it never does: it sets no binding, calls no frame-manager method,
-- registers nothing with the native navigation, hooks no native frame, and
-- writes no saved data. Its reads are plain Lua field reads and guarded
-- query calls (IsOnlyCoreBindingSetActive, GetBindingAction,
-- GetCurrentKeyBoardFocus); a read that fails is logged as unknown.
--
-- On any blocked or forbidden action attributed to BagSmith: the first
-- event's addon, event, function, stack and the last-observed snapshot
-- (with its time) are captured, the failure is latched first, the timer
-- is cancelled, every observer listener is unregistered, no further native
-- query is made, and the report is frozen. The latch is terminal until a
-- reload. The report stays available: the passive outcome card stays on
-- screen, and /bs gamepad show opens the read-only copy window only once
-- the keyboard-and-mouse style is positively confirmed (an unknown style
-- opens nothing).
--
-- The observer keeps its own log, apart from the Stage A diagnostics log,
-- so the legacy diagnostics commands cannot reset or drop its evidence;
-- those commands are refused while an observation is active or failed.
--
-- The report persists across an orderly reload in its own saved variable,
-- BagSmithProbeReport (declared in the TOC; BagSmith's settings validator
-- never touches it): written at start, every 50 samples, at a normal stop,
-- at a failure (from the frozen log, with no native query) and at logout.
-- A report found at load is restored for the copy window and the card,
-- labeled by how it ended (stopped, failed, or interrupted by a reload
-- mid-run), and is kept until explicitly replaced by a new observation or
-- cleared with /bs gamepad observe clear. A saved failure report must be
-- cleared before a new observation can start. A hard freeze or crash can
-- still prevent the game from saving it.
------------------------------------------------------------------------
local REPORT_VERSION = 1
local OBS_TICK, OBS_MAX_SECONDS, OBS_MAX_EVENTS = 0.1, 180, 400
local OBS_EVENTS = { "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
	"MERCHANT_SHOW", "MERCHANT_CLOSED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "INPUT_DEVICE_INTERFACE_TRANSITION", "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_DISCONNECTED" }
local PAD_KEYS = { "PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6", "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",
	"PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER", "PADLSTICK", "PADRSTICK",
	"PADLSTICKUP", "PADLSTICKDOWN", "PADLSTICKLEFT", "PADLSTICKRIGHT", "PADRSTICKUP", "PADRSTICKDOWN", "PADRSTICKLEFT", "PADRSTICKRIGHT",
	"PADBACK", "PADFORWARD", "PADSYSTEM", "PADSOCIAL", "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4" }

-- The UI style, positively: "Gamepad", "Mkb", or nil when it cannot be
-- confirmed (a query absent, failing, answering something other than a
-- boolean, or the two queries disagreeing). Unknown permits nothing.
-- Only the two boolean queries, agreeing, confirm a style; there is no
-- fallback (a nil style compared with an absent enum member would "agree").
-- During an in-flight observation read, once a failure is latched no second
-- query is made here either; a later explicit request (opening the report)
-- still confirms the style normally.
local function styleOf(inFlight)
	if inFlight and GP.obsFailed then return nil end
	local g, m
	local fg, fm = has("InputUtil.IsGamepadUIEnabled"), has("InputUtil.IsMKBUIEnabled")
	if type(fg) ~= "function" or type(fm) ~= "function" then return nil end
	local ok, v = pcall(fg); if ok and type(v) == "boolean" then g = v end
	if inFlight and GP.obsFailed then return nil end
	ok, v = pcall(fm); if ok and type(v) == "boolean" then m = v end
	if g == true and m == false then return "Gamepad" end
	if g == false and m == true then return "Mkb" end
	return nil
end
local function gamepadStyle() return styleOf() == "Gamepad" end
local function mkbStyle() return styleOf() == "Mkb" end
local function u(v) if v == nil then return "unknown" end return tostring(v) end
-- A frame's name, by one getter at a time: nothing is asked of a frame once
-- a failure is latched (a getter can itself be the witness and return
-- normally), and no fallback getter runs after the first one if the latch
-- was set meanwhile. Only in-flight observation reads use this.
local function frameName(f)
	if type(f) ~= "table" then return tostring(f) end
	if GP.obsFailed then return "(unqueried)" end
	local n
	if type(f.GetDebugName) == "function" then
		local ok, v = pcall(f.GetDebugName, f)
		if ok and v and v ~= "" then n = v end
	end
	if n == nil and not GP.obsFailed and type(f.GetName) == "function" then
		local ok, v = pcall(f.GetName, f)
		if ok and v and v ~= "" then n = v end
	end
	if n ~= nil then return tostring(n) end
	return GP.obsFailed and "(unqueried)" or "(unnamed)"
end
local function shown(f)
	if type(f) ~= "table" or not f.IsShown then return nil end
	local ok, v = pcall(f.IsShown, f)
	if ok then return v and true or false end
	return nil
end

-- The observer's own log (separate from the diagnostics log). Frozen after a failure.
GP.obs = { state = "idle", samples = 0, changes = 0, log = {} }   -- idle | running | stopped | failed (terminal until a reload)
GP.obsFailed = false
local function oput(force, fmt, ...)
	local o = GP.obs
	if o.frozen then return end
	if not force then
		o.eventLines = (o.eventLines or 0) + 1
		if o.eventLines > OBS_MAX_EVENTS then o.log.full = true; return end
	end
	o.log[#o.log + 1] = ("%8.2f  %s"):format(stamp(), (select("#", ...) > 0) and fmt:format(...) or fmt)
end
local function oadd(fmt, ...) oput(true, fmt, ...) end
local function oevent(fmt, ...) oput(false, fmt, ...) end
local function osay(fmt, ...)   -- the observer's log always; chat only when the keyboard-and-mouse style is confirmed
	oadd(fmt, ...)
	if mkbStyle() then ns:Print(fmt, ...) end
end
function GP:ObsText()
	local o = self.obs
	if #o.log == 0 then return "(no observation)" end
	local out = table.concat(o.log, "\n")
	if o.log.full then out = out .. "\n(observer events full: later events were dropped)" end
	return out
end

-- One read of everything observed, every value guarded; nil means unknown.
-- Stops early, without further queries, once a failure is latched.
function GP:ObsRead()
	local r = {}
	r.style = styleOf(true)
	if self.obsFailed then return r end
	local ibm = has("GamepadSharedUtility.InputBindingManager")
	if type(ibm) == "table" and type(ibm.IsOnlyCoreBindingSetActive) == "function" then
		local ok, v = pcall(ibm.IsOnlyCoreBindingSetActive, ibm); if ok and not self.obsFailed then r.core = v and true or false end
	end
	if self.obsFailed then return r end
	local mgr = has("GamepadMode.FrameControlsManager")
	if type(mgr) == "table" then
		local ok, names, n = pcall(function()
			local out, count = {}, 0
			for _, f in ipairs(mgr.shownFrames) do
				if self.obsFailed then break end
				count = count + 1; out[#out + 1] = frameName(f)
			end
			return table.concat(out, ","), count
		end)
		if ok then r.shownNames, r.shownCount = names, n end
		if self.obsFailed then return r end
		local okF, fn = pcall(function() return mgr.focusedFrame and frameName(mgr.focusedFrame) or "none" end); if okF then r.focused = fn end
		if self.obsFailed then return r end
		local okU, uf = pcall(function() return mgr.isUIFocused and true or false end); if okU then r.uiFocused = uf end
		if self.obsFailed then return r end
		local okC, c = pcall(function() return mgr.fallThroughCatcherActive and true or false end); if okC then r.catcher = c end
	end
	if self.obsFailed then return r end
	if GetCurrentKeyBoardFocus then local ok, f = pcall(GetCurrentKeyBoardFocus); if ok then r.editFocus = f and frameName(f) or "none" end end
	if self.obsFailed then return r end
	r.combat = InCombatLockdown and (InCombatLockdown() and true or false) or false
	if self.obsFailed then return r end
	r.bsMain = viewOpen()   -- (BagSmith.API view state; the bank is outside API 1.0 and no longer sampled)
	if self.obsFailed then return r end
	local cb = _G.ContainerFrameCombinedBags
	r.nativeCombinedShown = shown(cb)
	if self.obsFailed then return r end
	if type(cb) == "table" then
		local ok, where = pcall(function()
			local parent = cb:GetParent()
			if parent == nil then return "none" end
			if parent == _G.ContainerFrameContainer then return "ContainerFrameContainer" end
			if parent == UIParent then return "UIParent" end
			return frameName(parent)
		end)
		if ok then r.nativeCombinedParent = where end
	end
	if self.obsFailed then return r end
	local n = 0
	for i = 1, (NUM_CONTAINER_FRAMES or 13) do
		if self.obsFailed then return r end
		local f = _G["ContainerFrame" .. i]; if shown(f) then n = n + 1 end
	end
	r.nativeFramesShown = n
	if self.obsFailed then return r end
	r.gameMenu = shown(_G.GameMenuFrame)
	local popups = 0
	for i = 1, 4 do
		if self.obsFailed then return r end
		if shown(_G["StaticPopup" .. i]) then popups = popups + 1 end
	end
	r.popups = popups
	return r
end
local OBS_FIELDS = { "style", "core", "shownCount", "shownNames", "focused", "uiFocused", "catcher", "editFocus", "combat", "bsMain", "nativeCombinedShown", "nativeCombinedParent", "nativeFramesShown", "gameMenu", "popups" }
local function readText(r)
	local parts = {}
	for _, k in ipairs(OBS_FIELDS) do parts[#parts + 1] = k .. "=" .. u(r[k]) end
	return table.concat(parts, " ")
end
local function cardState(r) return ("style %s core %s shown %s native bag %s"):format(u(r.style), u(r.core), u(r.shownCount), u(r.nativeCombinedParent)) end

-- The binding readback for every pad key, as supporting evidence; a failing call is "unknown", never "unbound".
function GP:ObsBindings(label)
	if type(GetBindingAction) ~= "function" then oadd("bindings (%s): GetBindingAction absent", label); return end
	-- The HUD's pad bindings live in the gamepad binding context (Blizzard_Gamepad/Core.lua activates
	-- Enum.BindingContext.GamepadModeInGameCore), so the default-context readback shows "-" for them; a
	-- third column asks that context when the enum names it.
	local ctx = has("Enum.BindingContext.GamepadModeInGameCore")
	local out = {}
	local function fmt(ok, v) if not ok then return "unknown" end if v == nil or v == "" then return "-" end return tostring(v) end
	for _, key in ipairs(PAD_KEYS) do
		if self.obsFailed then break end
		local ok1, o = pcall(GetBindingAction, key, true)
		if self.obsFailed then break end   -- the first read may itself have triggered the witness: no second read
		local ok2, b = pcall(GetBindingAction, key)
		if self.obsFailed then break end
		local ok3, g = true, nil
		if ctx ~= nil then ok3, g = pcall(GetBindingAction, key, true, ctx) end
		out[#out + 1] = key .. "=" .. fmt(ok1, o) .. "/" .. fmt(ok2, b) .. "/" .. (ctx == nil and "noctx" or fmt(ok3, g))
	end
	if self.obsFailed then return end
	oadd("bindings (%s; override/base/gamepad-context): %s", label, table.concat(out, " "))
end
function GP:ObsSnapshot(label)
	local r = self:ObsRead()
	oadd("snapshot (%s): %s", label, readText(r))
	self:ObsBindings(label)
	return r
end
local function elapsed(o) return (stamp() - (o.startedAt or stamp())) end

-- Persistence: the report as a bounded, versioned table in BagSmithGamepadDB.report (the companion's own
-- saved variable; the legacy BagSmithProbeReport is copied in once, see GP:MigrateLegacyReport).
function GP:ReportSave(how)
	local o = self.obs
	if how == "cleanup" then   -- only the probe's outcome and cleanup status change; the report's lines are kept as they are
		local r = reportGet()
		if type(r) == "table" and r.lines then r.probeSummary = (self.probe or self.nav) and self:ActiveSummary() or r.probeSummary; r.probeCleanup = self:ActiveCleanupStatus() or r.probeCleanup end
		return r
	end
	if how == "config" then   -- only the key configuration changes; a saved report, if any, is kept as it is
		local r = reportGet()
		if type(r) ~= "table" then r = { version = REPORT_VERSION } end
		r.config = self:ProbeConfig()
		if r.config == nil and r.lines == nil then r = nil end
		reportSet(r)
		return r
	end
	local lines = {}
	for i = 1, #o.log do lines[i] = o.log[i] end
	local last = o.final or o.lastObserved or o.last
	reportSet({
		version = REPORT_VERSION, probe = GP.PROBE, how = how, savedAt = stamp(),
		state = o.state, failed = self.obsFailed and true or false, failure = self.obsFailure, firstStack = self.obsFirstStack,
		samples = o.samples, changes = o.changes, elapsed = o.elapsed or (o.startedAt and (stamp() - o.startedAt)) or 0,
		startedFrom = o.from, lastObservedAt = o.lastObservedAt,
		lastState = last and cardState(last) or nil,
		lines = lines, full = o.log.full and true or false,
		config = self:ProbeConfig(), probeSummary = (self.probe or self.nav) and self:ActiveSummary() or nil, probeCleanup = self:ActiveCleanupStatus(),
	})
	return reportGet()
end
local function reportValid(r)
	return type(r) == "table" and r.version == REPORT_VERSION and type(r.lines) == "table" and type(r.state) == "string"
end
-- Restore at load: a report found in the saved variable is kept for the copy window and the card.
function GP:ReportRestore()
	local r = reportGet()
	if r == nil then return nil end
	if type(r) == "table" and r.lines == nil and r.config ~= nil then self.probeConfig = r.config; return nil end   -- configuration only, no report
	if not reportValid(r) then
		self.obs.restored = { bad = true, text = "(a saved probe report was present but not readable: version " .. tostring(type(r) == "table" and r.version or "?") .. ")" }
		self:OutcomeShowRestored()
		return self.obs.restored
	end
	local ended = r.state
	if r.state == "running" or r.state == "registering" or r.how == "logout" or r.how == "progress" or r.how == "start" then ended = "interrupted" end   -- a reload or logout mid-run, or a run that never reached a stop
	self.probeConfig = r.config
	if type(r.probeCleanup) == "string" and r.probeCleanup:find("^pending") then
		r.probeCleanup = r.probeCleanup .. " | the UI was reloaded before this release was verified; override bindings do not survive a reload, but the release was never verified in-game"
	end
	self.obs.restored = { state = ended, failed = r.failed, failure = r.failure, firstStack = r.firstStack, samples = r.samples or 0, changes = r.changes or 0,
		elapsed = r.elapsed or 0, lastState = r.lastState, lastObservedAt = r.lastObservedAt, probe = r.probe, how = r.how, probeState = r.probeSummary, probeCleanup = r.probeCleanup,
		text = table.concat(r.lines, "\n") .. (r.full and "\n(observer events full: later events were dropped)" or "") }
	self:OutcomeShowRestored()
	return self.obs.restored
end
function GP:ReportClear()
	local cfg = self:ProbeConfig()
	reportSet(cfg and { version = REPORT_VERSION, config = cfg } or nil)   -- the key configuration survives a clear
	self.obs.restored = nil
end

function GP:ObsListenFrame()
	local f = self.obsEvents
	if not f then
		f = CreateFrame("Frame"); f:Hide()
		f:SetScript("OnEvent", function(_, name, ...) GP:ObsEvent(name, ...) end)
		self.obsEvents = f
	end
	return f
end
function GP:ObsListen()
	local f = self:ObsListenFrame()
	local validator = has("C_EventUtils.IsEventValid") and C_EventUtils.IsEventValid or nil
	local missing = {}
	for _, name in ipairs(OBS_EVENTS) do
		local reason
		if validator and safe(validator, name) ~= true then reason = "not valid on this client"
		else
			local ok, ret = pcall(f.RegisterEvent, f, name)
			if not ok then reason = "register failed: " .. tostring(ret) elseif ret == false then reason = "refused (RegisterEvent returned false)" end
		end
		if reason then missing[#missing + 1] = name .. " (" .. reason .. ")" end
	end
	-- The two witness events are required; the rest are context and may be missing on a given client.
	local fatal = {}
	for _, m in ipairs(missing) do if m:find("^ADDON_ACTION_") then fatal[#fatal + 1] = m end end
	if #fatal > 0 then f:UnregisterAllEvents(); return false, table.concat(fatal, "; ") end
	if #missing > 0 then oadd("observer: context events not registered: %s", table.concat(missing, "; ")) end
	return true
end
function GP:ObsUnlisten() if self.obsEvents then self.obsEvents:UnregisterAllEvents() end end
function GP:ObsListeners()
	local f = self.obsEvents
	if not (f and type(f.IsEventRegistered) == "function") then return nil end
	local n = 0
	for _, name in ipairs(OBS_EVENTS) do local ok, reg = pcall(f.IsEventRegistered, f, name); if not ok then return nil end; if reg then n = n + 1 end end
	return n
end

-- Start: explicit, logged with its deadline; only in a confirmed Gamepad style; never after a latched failure.
function GP:ObsStart(from)
	if not self.active then oadd("observer: not started: the companion is not active (%s)", tostring(self.inactiveReason)); return false end
	local o = self.obs
	if self.obsFailed or o.state == "failed" then oadd("observer: start ignored: terminal until a reload (%s)", tostring(self.obsFailure)); return false end
	if o.state == "running" then oadd("observer: start ignored: already running"); return false end
	local st = styleOf()
	if st ~= "Gamepad" then osay("Observer: not started: the interface style is %s; press its key with the Controller style confirmed.", st or "unknown"); return false end
	if self:ProbeCleanupPending() then oadd("observer: not started: the previous probe's cleanup is pending (%s); it completes when combat ends and is verified", tostring(self:ActiveCleanupStatus())); return false end
	if self.nav and self.nav.browse then self:BrowseStop("observer starting"); self.nav = nil end   -- (idle: nothing installed, checked just above)
	local rs = o.restored
	if rs and (rs.failed or rs.bad) then oadd("observer: not started: a saved %s report is on file; /bs gamepad observe clear it first, in the keyboard-and-mouse style", rs.bad and "unreadable" or "failure"); return false end
	o.log, o.eventLines, o.frozen = {}, 0, nil   -- a fresh report for this observation (the previous one was a normal stop)
	if rs then oadd("observer: the saved %s report (%d samples) is replaced by this observation", rs.state, rs.samples or 0); o.restored = nil end
	local ok, why = self:ObsListen()
	if not ok then osay("Observer: required monitoring unavailable (%s); not started.", why); return false end
	self:OutcomeHide()
	o.state, o.samples, o.changes, o.startedAt, o.from, o.final, o.lastObserved = "running", 0, 0, stamp(), from, nil, nil
	o.deadline = o.startedAt + OBS_MAX_SECONDS
	oadd("OBSERVER START (%s): PROBE %s; sample every %.1f s; deadline %d s of elapsed time (stops at the first opportunity at or after it); stop by the key, by /bs gamepad observe stop in the keyboard-and-mouse style, or by the deadline", from or "?", GP.PROBE, OBS_TICK, OBS_MAX_SECONDS)
	o.last = self:ObsSnapshot("start"); o.lastAt = elapsed(o)
	if o.state == "running" then
		if self.probeConfig and self.probeConfig.nav then
			self.probe = nil; oadd("probe: not armed: the navigation prototype is enabled instead")
			self:NavArm()
		elseif self.probeConfig and self.probeConfig.enabled then self.nav = nil; self:ProbeArm()
		else self.probe = nil; self.nav = nil; oadd("probe: not enabled for this observation") end
		self:ReportSave("start"); self:ObsSchedule()
	end   -- (a failure during the start snapshot has already ended it, and saved itself)
	return true
end
function GP:ObsSchedule()
	local o = self.obs
	if o.timer then o.timer:Cancel() end
	o.timer = C_Timer.NewTimer(OBS_TICK, function() GP:ObsTick() end)
end
function GP:ObsTick()
	local o = self.obs
	o.timer = nil
	if o.state ~= "running" then return end
	o.samples = o.samples + 1
	local r = self:ObsRead()
	if o.state ~= "running" then return end   -- a failure latched during the read: nothing logged, nothing rescheduled
	local now = elapsed(o)
	local diff = {}
	for _, k in ipairs(OBS_FIELDS) do if r[k] ~= o.last[k] then diff[#diff + 1] = k .. ": " .. u(o.last[k]) .. " -> " .. u(r[k]) end end
	if #diff > 0 then o.changes = o.changes + 1; oevent("t+%.1fs sample %d change: %s", now, o.samples, table.concat(diff, "; ")) end
	o.last, o.lastAt = r, now
	self:ProbeTick(r, now)
	self:NavTick(r, now)
	if o.state ~= "running" then return end   -- (the probe's cleanup verification may have ended the session)
	if o.samples % 50 == 0 then self:ReportSave("progress") end
	if now >= OBS_MAX_SECONDS then self:ObsStop("deadline"); return end
	self:ObsSchedule()
end
-- Normal stop: from the key, the slash command (keyboard-and-mouse style), the deadline, or logout.
function GP:ObsStop(why)
	local o = self.obs
	if o.state ~= "running" then return false end
	if o.timer then o.timer:Cancel(); o.timer = nil end
	o.final = self:ObsSnapshot("stop")   -- the stop snapshot is what the card and the report show
	if o.state ~= "running" then return true end   -- (a failure during the stop snapshot has taken over)
	o.elapsed = elapsed(o)
	o.state = "stopped"
	oadd("OBSERVER STOP (%s): %d samples, %.1f s elapsed, %d changes", why, o.samples, o.elapsed, o.changes)
	self:ProbeEnd("observer stop")   -- (no reacquisition from here on; the binding is released, or its release left pending in combat)
	self:NavEnd("observer stop")
	self:ObsUnlisten()
	self:ReportSave(why == "logout" and "logout" or "stop")   -- a logout or reload mid-run is saved as an interruption
	self:OutcomeShow(why)
	return true
end
-- Failure: latch first; cancel the timer; unregister every observer listener; no further native query; freeze the report.
function GP:ObsFail(name, addon, func, stack)
	local o = self.obs
	if self.obsFailed then return end
	self.obsFailed = true
	self.obsFailure = ("%s %s (by %s)"):format(name, tostring(func), tostring(addon))
	local lines = {}
	for line in tostring(stack or ""):gmatch("[^\n]+") do lines[#lines + 1] = line; if #lines == 2 then break end end
	self.obsFirstStack = #lines > 0 and table.concat(lines, " | "):sub(1, 160) or nil
	if o.timer then o.timer:Cancel(); o.timer = nil end
	self:ObsUnlisten()
	o.lastObserved, o.lastObservedAt = o.last, o.lastAt
	o.elapsed = elapsed(o)
	oadd("OBSERVER FAILED at %.1f s (sample %d, state %s): %s", o.elapsed, o.samples, o.state, self.obsFailure)
	if stack and stack ~= "" then oadd("stack: %s", (stack:gsub("\n", " | "))) end
	oadd("last observed (t+%.1fs, before the failure): %s", o.lastObservedAt or 0, o.lastObserved and readText(o.lastObserved) or "none")
	-- The probe's own binding is cleaned up before the report freezes: this is cleanup, with one readback to
	-- verify it, not observation; it is logged as such.
	self:ProbeEnd("failure")
	self:NavEnd("failure")
	oadd("report frozen; terminal until a reload")
	o.state = "failed"
	o.frozen = true
	self:ReportSave("failure")   -- from the frozen log; no native query
	self:OutcomeShow(name)
end
function GP:ObsEvent(name, ...)
	if name == "ADDON_ACTION_FORBIDDEN" or name == "ADDON_ACTION_BLOCKED" then
		local addon, func = ...
		if not (addon == ADDON or addon == ns.HOST) then return end   -- a blocked action attributed to the companion or to BagSmith itself
		if self.obsFailed then return end   -- (the listeners are gone by now; a straggler is ignored)
		local stack = debugstack and (debugstack(2, 12, 0) or "") or ""
		self:ObsFail(name, addon, func, stack)
		return
	end
	if self.obs.state ~= "running" then return end
	local args = {}
	for i = 1, select("#", ...) do args[i] = tostring((select(i, ...))) end
	oevent("t+%.1fs event %s %s", elapsed(self.obs), name, table.concat(args, " "))
end

-- The passive outcome card (text only, precreated, no scripts, never registered).
function GP:OutcomeCard()
	if self.outcome then return self.outcome end
	local f = CreateFrame("Frame", "BagSmithGamepadProbeOutcome", UIParent, "BackdropTemplate")
	f:SetSize(660, 158); f:SetPoint("TOP", 0, -80); f:Hide()
	f:SetFrameStrata("DIALOG")
	if f.SetBackdrop then f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); f:SetBackdropColor(0.08, 0.08, 0.08, 0.95); f:SetBackdropBorderColor(0.6, 0.5, 0.25, 1) end
	f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	f.close:SetPoint("TOPRIGHT", 2, 2)
	f.close:SetScript("OnClick", function() f:Hide() end)
	f.lines = {}
	for i = 1, 6 do
		local t = f:CreateFontString(nil, "OVERLAY", i == 1 and "GameFontNormal" or "GameFontHighlightSmall")
		t:SetPoint("TOPLEFT", 12, -10 - (i - 1) * 24); t:SetPoint("TOPRIGHT", -12, -10 - (i - 1) * 24)
		t:SetJustifyH("LEFT"); t:SetWordWrap(false)
		f.lines[i] = t
	end
	self.outcome = f
	return f
end
function GP:OutcomeShow(why)
	local f = self:OutcomeCard()
	local o = self.obs
	local n = self:ObsListeners()
	f.lines[1]:SetText(("BagSmith Gamepad %s: observation over (%s)"):format(GP.PROBE, why or "?"))
	if o.state == "failed" then
		f.lines[2]:SetText(("state failed | failure latch SET | last observed at t+%.1fs (before the failure): %s"):format(o.lastObservedAt or 0, o.lastObserved and cardState(o.lastObserved) or "none"))
	else
		f.lines[2]:SetText(("state %s | failure latch %s | at stop: %s"):format(o.state, self.obsFailed and "SET" or "clear", o.final and cardState(o.final) or "none"))
	end
	f.lines[3]:SetText("first failure: " .. (self.obsFailure or "none"))
	f.lines[4]:SetText("stack: " .. (self.obsFirstStack or "n/a"))
	f.lines[5]:SetText(("samples %d | elapsed %.1f s | changes %d | listeners still registered %s"):format(o.samples, o.elapsed or elapsed(o), o.changes, n == nil and "unknown" or tostring(n)))
	f.lines[6]:SetText(self:ActiveSummary())
	f:Show()
end
function GP:OutcomeShowRestored()
	local f = self:OutcomeCard()
	local r = self.obs.restored
	if not r then return end
	if r.bad then
		f.lines[1]:SetText(("BagSmith Gamepad %s: saved report"):format(GP.PROBE)); f.lines[2]:SetText("unreadable; /bs gamepad observe clear it in the keyboard-and-mouse style"); f.lines[3]:SetText(""); f.lines[4]:SetText(""); f.lines[5]:SetText(""); f:Show(); return
	end
	f.lines[1]:SetText(("BagSmith Gamepad %s: saved report restored (%s)"):format(tostring(r.probe), r.state))
	if r.state == "failed" then
		f.lines[2]:SetText(("state failed | failure latch SET | last observed at t+%.1fs (before the failure): %s"):format(r.lastObservedAt or 0, r.lastState or "none"))
	else
		f.lines[2]:SetText(("state %s | failure latch %s | %s: %s"):format(r.state, r.failed and "SET" or "clear", r.state == "interrupted" and "last saved" or "at stop", r.lastState or "none"))
	end
	f.lines[3]:SetText("first failure: " .. (r.failure or "none"))
	f.lines[4]:SetText("stack: " .. (r.firstStack or "n/a"))
	f.lines[5]:SetText(("samples %d | elapsed %.1f s | changes %d | listeners still registered 0 (fresh load)"):format(r.samples or 0, r.elapsed or 0, r.changes or 0))
	f.lines[6]:SetText("probe: " .. (r.probeState or "not armed"))
	-- a report that ended normally is kept for /bs gamepad show without putting the card on screen at every login;
	-- a failure or an interrupted run is shown, since it needs attention
	if r.state == "failed" or r.state == "interrupted" or r.failed then f:Show() else f:Hide() end
end
function GP:OutcomeHide() if self.outcome then self.outcome:Hide() end end


------------------------------------------------------------------------
-- Probe B: one key, one logging target.
--
-- During an observation, and only then, the probe places one priority
-- override binding on one pad key, pointing at one plain BagSmith button
-- that only logs its click edges. It arms only with a verified suitable
-- key (section below), only when every condition from the observer's
-- current sample holds, only with the key observed up, and only after the
-- conditions have held for 5 consecutive samples. It releases on the first
-- sample where any condition fails, at the cap, at the observer's stop, and
-- at a latched failure. Reacquisition is automatic within the session under
-- the same conditions, and never after a stop, the cap, or a failure.
--
-- Guarantees, stated narrowly: the probe waits for key-up before binding
-- or rebinding; it ignores an up edge it did not see the down edge for;
-- it reports only what its button observed. It does not claim where a
-- press went that its button did not see. A release is reported as
-- verified only after a readback no longer names the button; while a
-- release cannot run (combat), it is reported as pending, the binding may
-- remain beyond the cap, and the combat-end listener stays registered
-- until the release is verified.
--
-- Nothing else: no second key, no real BagSmith control, no item action,
-- no native-manager call, no analog capture, no secure handler.
------------------------------------------------------------------------
local PROBE_CAP = 60          -- seconds from the first bind of the session; the release may be delayed by combat
local PROBE_QUIET = 5         -- consecutive clean samples before (re)binding
local PROBE_BUTTON = "BagSmithProbeKeyButton"
-- Keys a probe may use, by identity; everything else is refused.
local PROBE_KEYS_ALLOWED = { PADLSTICK = true, PADRSTICK = true, PADPADDLE1 = true, PADPADDLE2 = true, PADPADDLE3 = true, PADPADDLE4 = true, PADLSHOULDER = true, PADRSHOULDER = true }
-- HUD actions a probe key must not carry, when the readback names one.
local PROBE_ACTIONS_EXCLUDED = { OPENRADIAL = true, TOGGLEUIFOCUS = true, GAMEPADLEFTMOD = true, GAMEPADRIGHTMOD = true, GAMEPADLEFTTARGETMODIFIER = true, GAMEPADRIGHTTARGETMODIFIER = true, TOGGLEPINGSYSTEM = true }

function GP:ProbeConfig() return self.probeConfig end
-- The key is set in the keyboard-and-mouse style and kept in the saved report's config, so it survives the
-- style switch's reload. "confirm" records that you read the key's HUD assignment on the Keybindings screen.
function GP:ProbeSetKey(key, confirm)
	key = key and key:upper()
	if key == "OFF" then self.probeConfig = nil; self:ReportSave("config"); osay("Probe key cleared."); return end
	if key == "CONFIRM" then
		if not (self.probeConfig and type(self.probeConfig.key) == "string") then osay("Probe key: set a key first."); return end   -- (0.1.1-alpha: a nav-only config has none)
		self.probeConfig.confirmed = true; self.probeConfig.confirmedAt = stamp()
		self:ReportSave("config")
		osay("Probe key %s: confirmed by you from the Keybindings screen.", self.probeConfig.key); return
	end
	if not PROBE_KEYS_ALLOWED[key or ""] then osay("Probe key %s is not allowed; allowed: a stick-click (PADLSTICK, PADRSTICK), a paddle (PADPADDLE1-4), or a shoulder (PADLSHOULDER, PADRSHOULDER).", tostring(key)); return end
	self.probeConfig = { key = key, confirmed = false, version = REPORT_VERSION }
	self:ReportSave("config")
	osay("Probe key set to %s (not yet verified). It is verified at arm time by the gamepad-context readback, or by /bs gamepad probekey confirm after you read its assignment on the Keybindings screen.", key)
end

-- Verification at arm time: the key is allowed, and either the gamepad-context readback names what it does
-- (and that is not an excluded action), or you confirmed it. Otherwise the probe does not arm.
function GP:ProbeVerifyKey()
	local cfg = self.probeConfig
	if not cfg or not PROBE_KEYS_ALLOWED[cfg.key or ""] then return nil, "no allowed key configured" end
	local ctx = has("Enum.BindingContext.GamepadModeInGameCore")
	local known, action = false, nil
	if type(GetBindingAction) == "function" and ctx ~= nil then
		local ok, v = pcall(GetBindingAction, cfg.key, true, ctx)
		if ok and type(v) == "string" then known, action = true, v end
	end
	if known and action ~= "" and PROBE_ACTIONS_EXCLUDED[action] then return nil, ("key carries excluded HUD action %s"):format(action) end
	if known then return cfg.key, ("readback: %s"):format(action == "" and "unbound in the gamepad context" or action) end
	if cfg.confirmed then return cfg.key, "confirmed by you from the Keybindings screen (readback unavailable)" end
	return nil, "readback unavailable and the key is not confirmed"
end

function GP:ProbeButton()
	if self.probeButton then return self.probeButton end
	local b = CreateFrame("Button", PROBE_BUTTON)   -- created without a parent, parented afterwards
	b:SetParent(UIParent); b:SetSize(1, 1); b:SetPoint("TOPLEFT"); b:Hide()
	b:RegisterForClicks("AnyDown", "AnyUp")
	b:SetScript("OnClick", function(_, mouseButton, down) GP:ProbeClick(mouseButton, down) end)
	self.probeButton = b
	return b
end
function GP:ProbeOwner()
	if self.probeOwner then return self.probeOwner end
	local f = CreateFrame("Frame"); f:Hide()
	f:SetScript("OnEvent", function(_, name) if name == "PLAYER_REGEN_ENABLED" then GP:ProbePendingRelease() end end)
	self.probeOwner = f
	return f
end
local function pkeyDown(key) if type(IsKeyDown) == "function" then local ok, v = pcall(IsKeyDown, key); if ok then return v and true or false end end return nil end

-- Arm for this observation: a verified key, else nothing.
function GP:ProbeArm()
	if not self.active then oadd("probe: not armed: the companion is not active"); return false end
	if self:ProbeCleanupPending() then oadd("probe: not armed: the previous probe's cleanup is pending"); return false end
	local key, why = self:ProbeVerifyKey()
	if not key then oadd("probe: not armed: %s", why); self.probe = nil; return false end
	self.probe = { key = key, why = why, state = "idle", quiet = 0, binds = 0, releases = 0, pending = 0, ownedDown = 0, ownedUp = 0, ignoredUp = 0, unexpected = 0, noReacquire = false, firstBindAt = nil }
	self:ProbeButton(); self:ProbeOwner()
	oadd("probe: armed with %s (%s); cap %d s from the first bind; releases pending in combat may keep the binding beyond the cap", key, why, PROBE_CAP)
	return true
end
function GP:ProbeSummary()
	local pb = self.probe
	if not pb then return "not armed" end
	return ("%s %s%s | binds %d releases %d pending %d | owned down %d up %d | ignored up %d unexpected %d | cleanup: %s"):format(pb.key, pb.state, pb.installed and " (binding may exist)" or "", pb.binds, pb.releases, pb.pending, pb.ownedDown, pb.ownedUp, pb.ignoredUp, pb.unexpected, pb.cleanupStatus or "none needed yet")
end
function GP:ProbeCleanupPending()
	local pb, nv = self.probe, self.nav
	return (pb ~= nil and pb.installed == true) or (nv ~= nil and nv.installed == true)
end
function GP:ActiveSummary()
	if self.nav then return "nav: " .. self:NavSummary() end
	if self.probe then return "probe: " .. self:ProbeSummary() end
	return "probe: not armed"
end
function GP:ActiveCleanupStatus()
	if self.nav then return self.nav.cleanupStatus end
	if self.probe then return self.probe.cleanupStatus end
	return nil
end
local function probeConditions(r)
	if r.style ~= "Gamepad" then return "style " .. u(r.style) end
	if r.core ~= true then return "core " .. u(r.core) end
	if r.shownCount ~= 0 then return "shown " .. u(r.shownCount) end
	if r.combat then return "combat" end
	if r.editFocus ~= "none" then return "edit focus " .. u(r.editFocus) end
	if r.gameMenu then return "game menu" end
	if (r.popups or 1) ~= 0 then return "popups " .. u(r.popups) end
	return nil
end
function GP:ProbeBind(now)
	local pb = self.probe
	if not self.active then pb.noReacquire = true; oadd("probe: not binding: the companion is not active"); return end
	self:ProbeButton()
	-- From here on a binding may exist, whatever the call reports: only a verified clear resets this.
	pb.installed = true
	self:ProbeOwner():RegisterEvent("PLAYER_REGEN_ENABLED")   -- the cleanup listener exists before the binding does
	local ok, err = pcall(SetOverrideBindingClick, self:ProbeOwner(), true, pb.key, PROBE_BUTTON, "LeftButton")
	if self.obsFailed or pb.noReacquire then
		-- a witness fired during the call, or the probe was ended meanwhile: never bound; clean up whatever exists
		oadd("probe: bind interrupted (%s); cleaning up, no reacquisition", self.obsFailed and "failure latched" or "probe ended")
		pb.noReacquire = true
		self:ProbeRelease("interrupted bind", now)
		return
	end
	if not ok then
		oadd("probe: bind call failed: %s; cleaning up, no reacquisition", tostring(err))
		pb.noReacquire = true
		self:ProbeRelease("failed bind call", now)
		return
	end
	-- verified by readback before it is called bound
	local okR, action = pcall(GetBindingAction, pb.key, true)
	-- The readback itself can be the witness: a failure latched, or the probe ended, during that call means the
	-- cleanup has already run or is pending. Never accept success, set bound or count a bind after that.
	if self.obsFailed or pb.noReacquire or pb.state == "pending" or not pb.installed then
		oadd("probe: bind interrupted during verification (%s); %s, no reacquisition", self.obsFailed and "failure latched" or "probe ended",
			pb.installed and (pb.state == "pending" and "cleanup pending" or "cleaning up") or "already cleaned up")
		pb.noReacquire = true
		if pb.installed and pb.state ~= "pending" then self:ProbeRelease("interrupted verification", now) end
		return
	end
	if not (okR and type(action) == "string" and action:find(PROBE_BUTTON, 1, true)) then
		oadd("probe: bind not confirmed by readback (%s); cleaning up, no reacquisition", okR and tostring(action) or "readback failed")
		pb.noReacquire = true
		self:ProbeRelease("unconfirmed bind", now)
		return
	end
	pb.state = "bound"; pb.binds = pb.binds + 1; pb.firstBindAt = pb.firstBindAt or now; pb.ownedPress = false
	oadd("probe: bound %s at t+%.1fs (readback %s)%s", pb.key, now, action, pb.binds > 1 and " (reacquired)" or "")
end
-- Release: outside combat, clear and verify by readback; in combat, pending. The combat-end listener stays until verified.
-- Release whenever a binding may exist (installed), whatever the state says.
function GP:ProbeRelease(reason, now)
	local pb = self.probe
	if not pb or not pb.installed then return end
	if InCombatLockdown and InCombatLockdown() then
		if pb.state ~= "pending" then
			pb.state = "pending"; pb.pending = pb.pending + 1; pb.pendingReason = reason
			oadd("probe: release pending (%s) at t+%.1fs: in combat; the binding stays until combat ends and the release is verified", reason, now or 0)
			self:ProbeCleanupStatus(("pending (%s): in combat"):format(reason))
		end
		return
	end
	local ok, err = pcall(ClearOverrideBindings, self:ProbeOwner())
	local okR, action = pcall(GetBindingAction, pb.key, true)
	local validReadback = okR and type(action) == "string"
	local stillOurs = validReadback and action:find(PROBE_BUTTON, 1, true)
	if ok and validReadback and not stillOurs then
		pb.installed = false
		pb.state = "idle"; pb.releases = pb.releases + 1; pb.ownedPress = false; pb.quiet = 0
		self:ProbeOwner():UnregisterAllEvents()
		oadd("probe: released (%s) at t+%.1fs, verified by readback (%s)", reason, now or 0, action == "" and "unbound" or action)
		self:ProbeCleanupStatus(("released (%s), verified by readback"):format(reason))
	else
		pb.state = "pending"; pb.pendingReason = reason
		local why = not ok and ("clear failed: " .. tostring(err)) or (not okR and "readback failed" or (not validReadback and ("readback invalid (" .. type(action) .. ")") or "readback still names the button"))
		oadd("probe: release (%s) NOT verified: %s; still pending, listener kept", reason, why)
		self:ProbeCleanupStatus(("pending (%s): %s"):format(reason, why))
	end
end
-- The eventual cleanup status, kept outside the observer's log (which may be frozen), saved with the report and shown on the card.
function GP:ProbeCleanupStatus(text)
	local pb = self.probe
	if not pb then return end
	pb.cleanupStatus = ("%s (at %.2f)"):format(text, stamp())
	if self.obs.state ~= "running" then
		self:ReportSave("cleanup")
		if self.outcome and self.outcome:IsShown() then self.outcome.lines[6]:SetText(self:ActiveSummary()) end
	end
end
function GP:ProbePendingRelease()
	local pb = self.probe
	if pb and pb.state == "pending" then self:ProbeRelease(pb.pendingReason or "pending", self.obs.startedAt and (stamp() - self.obs.startedAt) or 0) end
end
-- Every sample: release on the first failing condition or at the cap; otherwise count quiet samples and (re)bind on key-up.
function GP:ProbeTick(r, now)
	local pb = self.probe
	if not pb then return end
	if pb.state == "pending" or (pb.installed and pb.state ~= "bound") then self:ProbeRelease(pb.pendingReason or "pending", now); return end
	local conflict = probeConditions(r)
	if pb.state == "bound" then
		if conflict then self:ProbeRelease(conflict, now); return end
		if pb.firstBindAt and now - pb.firstBindAt >= PROBE_CAP then pb.noReacquire = true; self:ProbeRelease("cap", now); return end
		return
	end
	-- idle
	if pb.noReacquire then return end
	if conflict then pb.quiet = 0; return end
	pb.quiet = pb.quiet + 1
	if pb.quiet < PROBE_QUIET then return end
	if pb.firstBindAt and now - pb.firstBindAt >= PROBE_CAP then pb.noReacquire = true; oadd("probe: cap reached before reacquisition; no reacquisition"); return end
	local down = pkeyDown(pb.key)
	if down ~= false then if down == nil then oadd("probe: key-up cannot be verified (IsKeyDown unavailable); not binding"); pb.noReacquire = true end; return end
	self:ProbeBind(now)
end
-- The button: logs only what it observed.
function GP:ProbeClick(mouseButton, down)
	local pb = self.probe
	local now = self.obs.startedAt and (stamp() - self.obs.startedAt) or 0
	if not pb then oevent("t+%.1fs probe button delivery with no probe armed (%s %s)", now, tostring(mouseButton), down and "down" or "up"); return end
	if down then
		if pb.state == "bound" then pb.ownedDown = pb.ownedDown + 1; pb.ownedPress = true; oevent("t+%.1fs probe: owned down (%s)", now, pb.key)
		else pb.unexpected = pb.unexpected + 1; oevent("t+%.1fs probe: unexpected down while %s", now, pb.state) end
	else
		if pb.ownedPress then pb.ownedDown = pb.ownedDown; pb.ownedUp = pb.ownedUp + 1; pb.ownedPress = false; oevent("t+%.1fs probe: owned up (%s)", now, pb.key)
		else pb.ignoredUp = pb.ignoredUp + 1; oevent("t+%.1fs probe: up without an owned down: ignored", now) end
	end
end
-- End: no reacquisition from here on; release now, or leave it pending (combat) with the listener kept.
function GP:ProbeEnd(reason)
	local pb = self.probe
	if not pb then return end
	pb.noReacquire = true
	if pb.installed then self:ProbeRelease(reason, self.obs.startedAt and (stamp() - self.obs.startedAt) or 0) end
	oadd("probe: ended (%s): %s", reason, self:ProbeSummary())
end


------------------------------------------------------------------------
-- Probe C: the visible navigation prototype.
--
-- While BagSmith's bag window is open and eligible, and only then, four
-- priority overrides on the D-pad keys point at four BagSmith buttons that
-- move a highlight between the real item buttons in that window. Nothing
-- else is bound: no activation, use, sale, deletion or move of anything,
-- no face button, no close key (the bag action and the keyboard close the
-- window as before). Mouse and keyboard behave as before; the highlight is
-- a passive frame over the focused button and takes no input.
--
-- Ownership is the one-key probe's, unchanged: bind only in the Gamepad
-- style with core-only bindings, nothing registered with the native
-- manager, no combat, no text focus, no game menu or popup, every D-pad
-- key observed up, after 5 clean samples, and only while the bag window is
-- shown; release on the first failing sample (the window closing is one),
-- at the observer's stop, and at a latched failure; verify every release
-- by readback; in combat the release is pending and the binding stays,
-- which means the D-pad keys stay shadowed (on this client they carry
-- GAMEPADACTIONBUTTON1 to 4) until combat ends and the release is verified.
-- No binding call is ever made in combat; moves are only accepted while
-- bound. The secure state-driver release that would end the shadowing at
-- combat start is the next inert check, not part of this prototype.
--
-- The prototype is exclusive with the one-key probe for an observation,
-- shares its cleanup record and its restart and clear guards, and arms
-- only when enabled with /bs gamepad nav on.
------------------------------------------------------------------------
local NAV_KEYS = { up = "PADDUP", down = "PADDDOWN", left = "PADDLEFT", right = "PADDRIGHT", back = "PAD2" }
local NAV_ORDER = { "up", "down", "left", "right", "back" }
-- Nav lines go to the observer's log while it runs (diagnostics), else to a bounded ring for browse mode.
local function nlog(force, fmt, ...)
	-- a diagnostics nav (the observer's) logs to the observer, start to stop included; a browse nav to the ring
	if not (GP.nav and GP.nav.browse) and (GP.obs.state == "running" or GP.obs.state == "stopped" or GP.obs.state == "failed") then
		if force then oadd(fmt, ...) else oevent(fmt, ...) end
		return
	end
	local ring = GP.browseLog
	if not ring then ring = {}; GP.browseLog = ring end
	ring[#ring + 1] = ("%8.2f  %s"):format(stamp(), (select("#", ...) > 0) and fmt:format(...) or fmt)
	if #ring > BROWSE_LINES then table.remove(ring, 1) end
end
local function nadd(fmt, ...) nlog(true, fmt, ...) end
local function nevent(fmt, ...) nlog(false, fmt, ...) end
local NAV_BUTTON = "BagSmithNavButton"
local NAV_QUIET = 5
local navReadbackOurs   -- (defined below; used by the combat check above it)

function GP:NavButtons()
	if self.navButtons then return self.navButtons end
	local t = {}
	for _, dir in ipairs(NAV_ORDER) do   -- (four directions and "back": East closes the bag)
		local b = CreateFrame("Button", NAV_BUTTON .. dir)   -- created without a parent, parented afterwards
		b:SetParent(UIParent); b:SetSize(1, 1); b:SetPoint("TOPLEFT"); b:Hide()
		b:RegisterForClicks("AnyDown", "AnyUp")
		b:SetScript("OnClick", function(_, mouseButton, down) GP:NavClick(dir, down) end)
		t[dir] = b
	end
	self.navButtons = t
	return t
end
-- The owner frame is a secure handler with a combat state driver: when combat begins, the driver's snippet
-- clears the owner's override bindings in secure execution, so the D-pad and East return to the game without
-- any binding call from addon Lua. The Lua side only verifies (a readback) and reacquires after combat.
-- Not atomic with input: a press in the same frame may still reach BagSmith. Unverified live until the
-- combat test; browse mode refuses to arm if the driver cannot be installed.
function GP:NavOwner()
	if self.navOwner then return self.navOwner end
	local f
	local ok, made = pcall(CreateFrame, "Frame", "BagSmithNavOwner", UIParent, "SecureHandlerStateTemplate")
	if ok and made then f = made else f = CreateFrame("Frame", "BagSmithNavOwner", UIParent) end
	f:Hide()
	f:SetScript("OnEvent", function(_, name)
		if name == "PLAYER_REGEN_ENABLED" then GP:NavPendingRelease(); GP:BrowseAfterCombat()
		elseif name == "PLAYER_REGEN_DISABLED" then GP:NavCombatStarted() end
	end)
	self.navOwner = f
	return f
end
function GP:NavInstallCombatDriver()
	if self.navDriver ~= nil then return self.navDriver end
	local f = self:NavOwner()
	if type(RegisterStateDriver) ~= "function" or type(f.SetAttribute) ~= "function" then self.navDriver = false; return false end
	if InCombatLockdown and InCombatLockdown() then return nil end   -- not now; try again out of combat
	local ok1 = pcall(f.SetAttribute, f, "_onstate-combat", [[ if newstate == 1 then self:ClearBindings() end ]])
	local ok2 = pcall(RegisterStateDriver, f, "combat", "[combat] 1; 0")
	self.navDriver = (ok1 and ok2) and true or false
	return self.navDriver
end
-- Combat began: did the secure driver clear the bindings? Verified by readback, never assumed.
function GP:NavCombatStarted(reason)
	local nv = self.nav
	if not (nv and nv.installed) then return end
	reason = reason or "combat"
	local cleared = true
	for _, dir in ipairs(NAV_ORDER) do local ours = navReadbackOurs(NAV_KEYS[dir]); if ours ~= false then cleared = false; break end end
	if cleared then
		nv.installed = false; nv.state = "idle"; nv.releases = nv.releases + 1; nv.quiet = 0
		self:NavShowHighlight(nil); self:NavTooltipHide()
		nadd("nav: released by the secure combat driver at combat start, verified by readback")
		self:NavCleanupStatus("released (combat driver), verified by readback")
	else
		if nv.state ~= "pending" then nv.pending = nv.pending + 1 end
		nv.state = "pending"; nv.pendingReason = reason
		if self.navDriver == true then
			nadd("nav: release pending (%s): combat began and the secure driver did not clear the bindings (readback still names a button); the D-pad and East stay shadowed until combat ends and the release is verified", reason)
			self:NavCleanupStatus(("pending (%s): in combat; the secure driver did not clear"):format(reason))
		else
			nadd("nav: release pending (%s): in combat and no secure combat driver is installed; the D-pad and East stay shadowed until combat ends and the release is verified", reason)
			self:NavCleanupStatus(("pending (%s): in combat, no secure driver"):format(reason))
		end
	end
end
-- The highlight: a passive border over the focused item button, parented to it so it follows and hides with it.
function GP:NavHighlight()
	if self.navHighlight then return self.navHighlight end
	local h = CreateFrame("Frame", "BagSmithGamepadFocus", UIParent)
	h:Hide(); h:EnableMouse(false)
	h.edges = {}
	for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local t = h:CreateTexture(nil, "OVERLAY")
		t:SetTexture("Interface\\Buttons\\WHITE8x8")
		t:SetVertexColor(0.98, 0.82, 0.30, 1)
		if side == "TOP" or side == "BOTTOM" then t:SetHeight(3); t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT")
		else t:SetWidth(3); t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side) end
		h.edges[i] = t
	end
	self.navHighlight = h
	return h
end
function GP:NavShowHighlight(cand)
	local h = self:NavHighlight()
	if not cand or not cand.b then h:Hide(); return end
	local b = cand.b
	-- inside BagSmith's overlay parent for this view: the list clips it as it clips the items, and it hides with
	-- the view; the item frame itself is only anchored to, never parented into or changed
	if self.ctx and not h.overlayParent then
		local overlay = self.ctx:GetOverlayParent("main")
		if overlay then h:SetParent(overlay); h.overlayParent = overlay; h:SetFrameLevel((overlay.GetFrameLevel and overlay:GetFrameLevel() or 0) + 1) end
	end
	if not h.overlayParent and cand.inViewport == false then h:Hide(); return end   -- without the clipped parent, the sampled viewport flag decides
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)      -- anchored inside the item's own rect: never clipped by the list's edges
	h:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	h:Show()
end

local function navKey(bag, slot) return (bag or 0) * 1000 + (slot or 0) end
-- The focused item's tooltip, shown the way the mouse would show it; never an action. Hidden when the focus
-- is released, the bag closes, or the mouse takes the tooltip for something else.
-- The focused item's tooltip through BagSmith's tooltip bridge: a lease that hides only what we showed.
function GP:NavTooltip(cand)
	if not (self.ctx and cand and cand.token) then return end
	local lease = self.ctx:ShowTargetTooltip("main", cand.token)
	self.nav.tooltipLease = lease or nil
end
function GP:NavTooltipHide()
	local nv = self.nav
	if not (nv and nv.tooltipLease and self.ctx) then return end
	self.ctx:ReleaseTooltip(nv.tooltipLease)   -- a stale lease (the mouse took the tooltip) hides nothing
	nv.tooltipLease = nil
end
-- The real item buttons currently shown in the main window, with their centers (screen coordinates).
-- The item targets of the open bag view, from the API snapshot: a detached list with a token per target, the
-- item's bag, slot and name, its center, and a borrowed anchor (used only to place the highlight; never
-- reparented, resized, re-scripted or activated).
function GP:NavCandidates()
	local out = {}
	local ctx = self.ctx
	if not ctx then return out end
	local snap = ctx:GetTargets("main")
	if not snap then return out end
	for _, t in ipairs(snap.targets) do
		out[#out + 1] = { b = t.anchor, x = t.x, y = t.y, key = navKey(t.bag, t.slot), token = t.token, name = t.name or "item", link = t.link, inViewport = t.inViewport ~= false }
	end
	self.navGeneration = snap.generation
	return out
end
local function navName(cand) return (type(cand) == "table" and cand.name) or "item" end
-- First item: top-most, then left-most.
-- First item: top-most, then left-most. Presentation (the tooltip) only when the caller says it is intentional.
function GP:NavFocusFirst(why, present)
	local c = self:NavCandidates()
	if #c == 0 then self:NavTooltipHide(); self.nav.focus = nil; self.nav.focusCand = nil; self:NavShowHighlight(nil); nevent("nav: nothing to focus (%s)", why); return false end
	table.sort(c, function(a, b) if a.y ~= b.y then return a.y > b.y end return a.x < b.x end)
	self:NavSetFocus(c[1], why, present)
	return true
end
-- A focus change. present = true for a user move or an intentional reacquisition (the tooltip is shown);
-- false for background replacement after a refresh (the highlight moves, the mouse keeps its tooltip).
function GP:NavSetFocus(cand, why, present)
	local nv = self.nav
	nv.focus = cand.b; nv.focusCand = cand; nv.focusKey = cand.key; nv.focusLink = cand.link; nv.focusX, nv.focusY = cand.x, cand.y
	self:NavShowHighlight(cand)
	nevent("nav: focus %d:%d %s (%s)", math.floor(cand.key / 1000), cand.key % 1000, navName(cand), why)
	self:NavEnsureVisible(cand)   -- only here, on an actual focus change: a surviving focus after a refresh is left where the wheel put it
	if present then self:NavTooltip(cand) end
end
-- Keep a newly focused item inside the list's scroll window: the smallest move that shows it whole, with a
-- one-row margin, clamped to the list's own range, through the view's own tagged scroll (so the scrollbar
-- follows and BagSmith can tell it from the wheel). Never in combat.
-- Keep a newly focused item inside the list's scroll window: BagSmith's API owns the scroll details (the
-- smallest move, the row margin, the range, the tagged scroll and the player-scroll precedence); refused
-- in combat, and a stale target is a harmless refusal.
function GP:NavEnsureVisible(cand)
	local nv = self.nav
	if not (nv and cand and cand.token and self.ctx) then return end
	local ok, changed, code = self.ctx:EnsureTargetVisible("main", cand.token)
	if not ok then
		if changed == "combat" then nevent("nav: not scrolling: in combat") end
		return
	end
	if changed then
		nv.scrolls = (nv.scrolls or 0) + 1
		nevent("nav: scrolled to keep %s in view", navName(cand))
		self:NavRefreshFocusCenter()   -- the list moved: the focused item's recorded center is refreshed so the rest of this move uses where it is now
	end
end
function GP:NavRefreshFocusCenter()
	local nv = self.nav
	if not (nv and nv.focus) then return end
	for _, cand in ipairs(self:NavCandidates()) do
		if cand.key == nv.focusKey and cand.b == nv.focus and cand.link == nv.focusLink then nv.focusCand = cand; nv.focusX, nv.focusY = cand.x, cand.y; return end
	end
end
-- After a refresh the focused button may be hidden or reused: keep it if it still shows, else the nearest to where it was.
-- After a refresh the focused button may be hidden or reused: keep it if it still shows the same item, else
-- the nearest to where it was. Background resolution: the highlight moves, the tooltip is never shown here.
function GP:NavResolve()
	local nv = self.nav
	if not nv.focus then return end
	local c = self:NavCandidates()
	for _, cand in ipairs(c) do
		if cand.b == nv.focus and cand.key == nv.focusKey then
			if cand.link == nv.focusLink then nv.focusCand = cand; nv.focusX, nv.focusY = cand.x, cand.y; self:NavShowHighlight(cand); return end
			-- the same frame and slot now show another item: a replacement, not a survivor; the old tooltip (ours, if
			-- the mouse did not take it) goes, the highlight stays on the slot, and no tooltip is shown from here
			self:NavTooltipHide()
			self:NavSetFocus(cand, "item replaced in place", false)
			return
		end
	end
	if #c == 0 then self:NavTooltipHide(); nv.focus = nil; nv.focusCand = nil; self:NavShowHighlight(nil); nevent("nav: focused item gone, nothing left to focus"); return end
	local best, bd
	for _, cand in ipairs(c) do local d = (cand.x - (nv.focusX or 0)) ^ 2 + (cand.y - (nv.focusY or 0)) ^ 2; if not bd or d < bd then best, bd = cand, d end end
	self:NavTooltipHide()   -- our tooltip for an item that is gone; the mouse's, if it has one, is not ours to hide
	self:NavSetFocus(best, "focused item gone, nearest", false)
end
-- One move: the nearest item in that direction (primary distance plus twice the sideways offset); none means no move.
function GP:NavMove(dir)
	local nv = self.nav
	if not nv.focus then self:NavFocusFirst("move " .. dir, true); return end
	self:NavResolve()   -- may replace a vanished focus and scroll; the center is re-read below, never the cached one
	if not nv.focus then return end
	self:NavRefreshFocusCenter()
	local fx, fy = nv.focusX, nv.focusY
	local best, bs
	for _, cand in ipairs(self:NavCandidates()) do
		if cand.b ~= nv.focus then
			local dx, dy = cand.x - fx, cand.y - fy
			local primary, side
			if dir == "right" then primary, side = dx, math.abs(dy) elseif dir == "left" then primary, side = -dx, math.abs(dy)
			elseif dir == "up" then primary, side = dy, math.abs(dx) else primary, side = -dy, math.abs(dx) end
			if primary > 0.5 then local score = primary + 2 * side; if not bs or score < bs then best, bs = cand, score end end
		end
	end
	if best then nv.moves = nv.moves + 1; self:NavSetFocus(best, dir, true) else nv.blocked = nv.blocked + 1; nevent("nav: no item to the %s", dir) end
end

function GP:NavArm(opts)
	opts = opts or {}
	if not self.active then nadd("nav: not armed: the companion is not active"); return false end
	if self:ProbeCleanupPending() then nadd("nav: not armed: a previous cleanup is pending"); return false end
	self:NavButtons(); self:NavOwner(); self:NavHighlight()
	local driver = self:NavInstallCombatDriver()
	-- (0.1.1-alpha, the 1.4.0-beta5 audit) In combat with no driver yet (a first start): nothing can be installed
	-- now, so ask to be woken when combat ends; the combat-end handler restarts browsing if the window is still open.
	if opts.browse and driver == nil then pcall(self:NavOwner().RegisterEvent, self:NavOwner(), "PLAYER_REGEN_ENABLED") end
	if opts.browse and driver ~= true then nadd("nav: browse mode not armed: the secure combat release could not be installed (%s)", driver == false and "unavailable on this client" or "in combat"); return false end
	self.nav = { state = "idle", quiet = 0, binds = 0, releases = 0, pending = 0, moves = 0, blocked = 0, scrolls = 0, ownedDown = 0, unexpected = 0, noReacquire = false, installed = false, browse = opts.browse and true or false }
	nadd("nav: armed on PADDUP PADDDOWN PADDLEFT PADDRIGHT and PAD2 (back); binds only while the bag window is shown and eligible; no activation of anything; secure combat driver %s%s", driver == true and "installed" or "NOT installed", opts.browse and " (browse mode)" or "")
	return true
end
function GP:NavSummary()
	local nv = self.nav
	if not nv then return "not armed" end
	return ("D-pad%s %s%s | binds %d releases %d pending %d | moves %d blocked %d scrolls %d | owned down %d unexpected %d | cleanup: %s"):format(nv.browse and " (browse)" or "", nv.state, nv.installed and " (bindings may exist)" or "", nv.binds, nv.releases, nv.pending, nv.moves, nv.blocked, nv.scrolls or 0, nv.ownedDown, nv.unexpected, nv.cleanupStatus or "none needed yet")
end
function GP:NavCleanupStatus(text)
	local nv = self.nav
	if not nv then return end
	nv.cleanupStatus = ("%s (at %.2f)"):format(text, stamp())
	if self.obs.state ~= "running" then
		self:ReportSave("cleanup")
		if self.outcome and self.outcome:IsShown() then self.outcome.lines[6]:SetText("nav: " .. self:NavSummary()) end
	end
end
navReadbackOurs = function(key)   -- (the forward local above)
	local ok, action = pcall(GetBindingAction, key, true)
	if not ok then return nil, "readback failed" end
	if type(action) ~= "string" then return nil, "readback invalid (" .. type(action) .. ")" end
	return action:find(NAV_BUTTON, 1, true) and true or false, action
end
function GP:NavBind(now)
	local nv = self.nav
	if not self.active then nv.noReacquire = true; nadd("nav: not binding: the companion is not active"); return end
	nv.installed = true   -- from here on bindings may exist; only a verified clear resets this
	self:NavOwner():RegisterEvent("PLAYER_REGEN_ENABLED"); self:NavOwner():RegisterEvent("PLAYER_REGEN_DISABLED")
	local owner = self:NavOwner()
	local failed
	for _, dir in ipairs(NAV_ORDER) do
		local ok, err = pcall(SetOverrideBindingClick, owner, true, NAV_KEYS[dir], NAV_BUTTON .. dir, "LeftButton")
		if self.obsFailed or nv.noReacquire then failed = "interrupted"; break end
		if not ok then failed = "bind call failed: " .. tostring(err); break end
	end
	if not failed then
		for _, dir in ipairs(NAV_ORDER) do
			local ours, info = navReadbackOurs(NAV_KEYS[dir])
			if self.obsFailed or nv.noReacquire or nv.state == "pending" or not nv.installed then failed = "interrupted during verification"; break end
			if ours ~= true then failed = ("%s not confirmed by readback (%s)"):format(NAV_KEYS[dir], tostring(info)); break end
		end
	end
	if failed then
		nadd("nav: bind %s; cleaning up, no reacquisition", failed)
		nv.noReacquire = true
		if nv.installed and nv.state ~= "pending" then self:NavRelease("failed bind", now) end
		return
	end
	nv.state = "bound"; nv.binds = nv.binds + 1
	nadd("nav: bound D-pad and back at t+%.1fs, all five verified by readback%s", now, nv.binds > 1 and " (reacquired)" or "")
	if not nv.focus then self:NavFocusFirst("bound", true)
	else
		self:NavResolve()
		if nv.focusCand then self:NavTooltip(nv.focusCand) end   -- control reacquired: the focused item's tooltip comes back (only here, never per tick)
	end
end
function GP:NavRelease(reason, now)
	local nv = self.nav
	if not nv or not nv.installed then return end
	if InCombatLockdown and InCombatLockdown() then
		self:NavCombatStarted(reason)   -- the secure driver may already have cleared the bindings: verified by readback; else pending with this reason
		return
	end
	local ok, err = pcall(ClearOverrideBindings, self:NavOwner())
	local clean, why = ok, ok and nil or ("clear failed: " .. tostring(err))
	if clean then
		for _, dir in ipairs(NAV_ORDER) do
			local ours, info = navReadbackOurs(NAV_KEYS[dir])
			if ours == nil then clean, why = false, info; break end
			if ours then clean, why = false, NAV_KEYS[dir] .. " readback still names the button"; break end
		end
	end
	if clean then
		nv.installed = false; nv.state = "idle"; nv.releases = nv.releases + 1; nv.quiet = 0
		self:NavOwner():UnregisterAllEvents()
		self:NavShowHighlight(nil); self:NavTooltipHide()
		nadd("nav: released (%s) at t+%.1fs, all five verified by readback", reason, now or 0)
		self:NavCleanupStatus(("released (%s), verified by readback"):format(reason))
	else
		nv.state = "pending"; nv.pendingReason = reason
		nadd("nav: release (%s) NOT verified: %s; still pending, listener kept", reason, tostring(why))
		self:NavCleanupStatus(("pending (%s): %s"):format(reason, tostring(why)))
	end
end
function GP:NavPendingRelease()
	local nv = self.nav
	if nv and nv.state == "pending" then self:NavRelease(nv.pendingReason or "pending", self.obs.startedAt and (stamp() - self.obs.startedAt) or 0) end
end
local function navConditions(r)
	local c = probeConditions(r)
	if c then return c end
	if r.bsMain ~= true then return "window closed" end
	return nil
end
function GP:NavTick(r, now)
	local nv = self.nav
	if not nv then return end
	if nv.state == "pending" or (nv.installed and nv.state ~= "bound") then self:NavRelease(nv.pendingReason or "pending", now); return end
	local conflict = navConditions(r)
	if nv.state == "bound" then
		if conflict then self:NavRelease(conflict, now); return end
		self:NavResolve()
		return
	end
	if nv.noReacquire then return end
	if conflict then nv.quiet = 0; return end
	nv.quiet = nv.quiet + 1
	if nv.quiet < NAV_QUIET then return end
	for _, dir in ipairs(NAV_ORDER) do
		local down = pkeyDown(NAV_KEYS[dir])
		if down == nil then nadd("nav: key-up cannot be verified (IsKeyDown unavailable); not binding"); nv.noReacquire = true; return end
		if down then return end   -- a held key defers the bind until it is released
	end
	self:NavBind(now)
end
function GP:NavClick(dir, down)
	local nv = self.nav
	if not nv then return end
	if not down then return end   -- only the down edge acts; the up edge is not an action
	if nv.state ~= "bound" then nv.unexpected = nv.unexpected + 1; nevent("nav: %s while %s: ignored", dir, nv.state); return end
	nv.ownedDown = nv.ownedDown + 1
	if dir == "back" then
		nevent("nav: back: closing the bag")
		if self.ctx then self.ctx:CloseView("main") end   -- BagSmith's normal close path; the next sample releases ("window closed")
		return
	end
	self:NavMove(dir)
end
function GP:NavEnd(reason)
	local nv = self.nav
	if not nv then return end
	nv.noReacquire = true
	if nv.installed then self:NavRelease(reason, self.obs.startedAt and (stamp() - self.obs.startedAt) or 0) end
	self:NavShowHighlight(nil); self:NavTooltipHide()
	nadd("nav: ended (%s): %s", reason, self:NavSummary())
end


------------------------------------------------------------------------
-- Browse mode: the navigation prototype as an opt-in feature (the
-- "Controller browsing (alpha)" option), without the observer.
--
-- While the setting is on and the game's Controller UI is on, opening the
-- bag window starts a 0.1 s sampler that runs the same ownership rules as
-- the diagnostics session: bind the D-pad and East only while the window is
-- shown and eligible, release on the first failing sample (another window,
-- text entry, the window closing), verify every release by readback, and
-- hand the keys back to the game at combat start through the secure state
-- driver (verified by readback, never assumed). The sampler stops once the
-- window is hidden and nothing is left to clean up. The diagnostics session
-- (the observer) takes precedence while it runs; browse mode resumes when
-- the window is next opened after it stops.
--
-- A blocked or forbidden action attributed to BagSmith ends browse mode for
-- the session (release attempted and verified, no reacquisition) and says
-- so once; a reload clears that.
------------------------------------------------------------------------
local BROWSE_TICK = 0.1
function GP:BrowseEnabled() if not self.ctx then return false end local prefs = self.ctx:ReadPreferences(); return prefs.browse == true end
function GP:SetBrowseEnabled(on)
	if not self.ctx then return false, "not active" end
	local prefs, token = self.ctx:ReadPreferences()
	prefs.browse = on and true or false
	local ok, code, msg = self.ctx:ReplacePreferences(prefs, token, 1)
	if not ok then return false, msg or code end
	self:BrowseApplySetting()
	return true
end
-- The setting changed (checkbox, slash, or a profile switch): start if the bag is open, else end browse mode.
function GP:BrowseApplySetting()
	if not self.active then return end
	if self:BrowseEnabled() then if viewOpen() then self:BrowseStart("setting on") end
	elseif self.nav and self.nav.browse then self:NavEnd("browse off"); self:BrowseStop("browse off") end
end
function GP:BrowseHookWindow()
	if self.browseHooked then return true end
	if not self.ctx then return false end
	self.ctx:Subscribe("VIEW_SHOWN", function() GP:NavViewShown(); GP:BrowseStart("window shown") end)
	self.ctx:Subscribe("VIEW_HIDDEN", function() GP:NavViewHidden(); GP:BrowseWindowHidden() end)
	self.ctx:Subscribe("VIEW_UPDATED", function() GP:NavViewUpdated() end)
	self.browseHooked = true
	return true
end
function GP:BrowseListenFrame()
	local f = self.browseEvents
	if not f then
		f = CreateFrame("Frame"); f:Hide()
		f:SetScript("OnEvent", function(_, name, ...)
			if name == "ADDON_ACTION_FORBIDDEN" or name == "ADDON_ACTION_BLOCKED" then
				local addon, func = ...
				if not (addon == ADDON or addon == ns.HOST) then return end   -- a blocked action attributed to the companion or to BagSmith itself
				GP:BrowseFail(name .. " " .. tostring(func))
			end
		end)
		self.browseEvents = f
	end
	return f
end
function GP:BrowseFail(what)
	local nv = self.nav
	if not (nv and nv.browse) then return end
	if self.browseFailed then return end
	self.browseFailed = what
	nadd("browse: %s attributed to BagSmith: browse mode ends for this session (reload to reset)", what)
	self:NavEnd("failure: " .. what)
	ns:Print("Controller browsing stopped: the game blocked %s. It stays off until you reload.", what)
end
function GP:BrowseStart(why)
	if not self.active then return false end   -- the gate: an inactive companion never starts browsing, whatever triggered it
	if not self:BrowseEnabled() then return false end
	if self.browseFailed then return false end
	if self.obs.state == "running" then return false end              -- the diagnostics session owns the nav while it runs
	if styleOf() ~= "Gamepad" then return false end
	local nv = self.nav
	if nv and not nv.browse then
		if nv.installed then return false end                            -- a diagnostics nav still cleaning up
		self.nav = nil; nv = nil
	elseif nv and nv.noReacquire then
		if nv.installed then return false end                            -- a finished browse nav still cleaning up
		self.nav = nil; nv = nil                                         -- finished (the setting was off, or the observer took over): start afresh
	end
	if not nv then
		if not self:NavArm({ browse = true }) then return false end
		nv = self.nav
	end
	self.browse = self.browse or { startedAt = stamp() }
	if not self.browse.timer then
		local f = self:BrowseListenFrame()
		for _, e in ipairs({ "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do pcall(f.RegisterEvent, f, e) end
		nadd("browse: sampling started (%s)", why)
		self:BrowseSchedule()
	end
	return true
end
function GP:BrowseSchedule()
	local b = self.browse
	if not b then return end
	if b.timer then b.timer:Cancel() end
	b.timer = C_Timer.NewTimer(BROWSE_TICK, function() GP:BrowseTick() end)
end
function GP:BrowseTick()
	local b = self.browse
	if not b then return end
	b.timer = nil
	local nv = self.nav
	if not (nv and nv.browse) then self:BrowseStop("no browse nav"); return end
	if self.obs.state == "running" then self:BrowseStop("observer running"); return end
	local r = self:ObsRead()
	self:NavTick(r, stamp() - b.startedAt)
	-- done when the window is hidden and nothing remains installed or pending
	if r.bsMain ~= true and not nv.installed and nv.state == "idle" then self:BrowseStop("window closed"); return end
	if nv.noReacquire and not nv.installed then self:BrowseStop("nav ended"); return end
	self:BrowseSchedule()
end
function GP:BrowseStop(why)
	local b = self.browse
	if not b then return end
	if b.timer then b.timer:Cancel(); b.timer = nil end
	if self.browseEvents then self.browseEvents:UnregisterAllEvents() end
	nadd("browse: sampling stopped (%s)", why)
	self.browse = nil
end
-- The view's own lifecycle, from the API: a close that the sampler never saw (closed and reopened within one
-- sample) still gets its presentation restored on reopen, and a hide drops the highlight and our tooltip at once.
function GP:NavViewShown()
	local nv = self.nav
	if not nv then return end
	if nv.state == "bound" then
		-- the bound state survived a quick close and reopen: the snapshot is new, so re-resolve by bag and slot and present again
		local key = nv.focusKey
		nv.focus, nv.focusCand = nil, nil
		local found
		for _, cand in ipairs(self:NavCandidates()) do if cand.key == key then found = cand; break end end
		if found then self:NavSetFocus(found, "view shown", true) else self:NavFocusFirst("view shown", true) end
	end
end
function GP:NavViewHidden()
	local nv = self.nav
	if not nv then return end
	self:NavShowHighlight(nil); self:NavTooltipHide()
end
function GP:NavViewUpdated()
	local nv = self.nav
	if nv and nv.state == "bound" then self:NavResolve() end   -- background: geometry is valid now; no tooltip from here
end
function GP:BrowseWindowHidden()
	-- the next sample releases on "window closed"; keep sampling until that is verified
	local nv = self.nav
	if nv and nv.browse and self.browse and not self.browse.timer then self:BrowseSchedule() end
	self:NavTooltipHide()
end
-- Entering the Controller UI with the bag already open: the view events will not fire again, so a style
-- transition is a start trigger too. Only events this client reports as valid are registered (GAME_PAD_ACTIVE_
-- CHANGED is known on Forever; the two style-event names are candidates checked with C_EventUtils); the start
-- goes through BrowseStart, so the active latch, the opt-in, the open bag and the no-duplicate-timer guard all
-- still apply, and a style change out of the Gamepad UI is handled by the sampler's conditions as before.
function GP:BrowseListenForStyle()
	if self.styleListening then return end
	self.styleListening = true
	local function onStyle() if GP.active and GP:BrowseEnabled() and viewOpen() and styleOf() == "Gamepad" and not (GP.browse and GP.browse.timer) then GP:BrowseStart("style transition") end end
	local names = { "GAME_PAD_ACTIVE_CHANGED" }
	for _, cand in ipairs(STYLE_EVENT_CANDIDATES) do
		local valid = has("C_EventUtils.IsEventValid")
		if type(valid) == "function" then local ok, v = pcall(valid, cand); if ok and v then names[#names + 1] = cand end end
	end
	for _, name in ipairs(names) do pcall(function() ns:On(name, onStyle) end) end
end
function GP:BrowseAfterCombat()
	-- combat ended: if the companion is still active, the window still open and browse mode on, sampling resumes
	-- so the keys reacquire; a deactivated companion's combat-end listener only completed its cleanup
	if self.active and viewOpen() then self:BrowseStart("combat ended") end
end
function GP:BrowseText()
	local ring = self.browseLog
	if not ring or #ring == 0 then return nil end
	return table.concat(ring, "\n")
end

-- The keybinding: start, or stop, the observation. The only control used in the Controller UI.
BINDING_NAME_BAGSMITH_OBSERVER = "Observer (controller diagnostics)"   -- the same binding ID as the 0.15 development builds: user assignments survive
function BagSmith_Observer()
	if not GP:Gate("The Observer") then return end
	if GP.obs.state == "running" then GP:ObsStop("key") else GP:ObsStart("key") end
end

function GP:Command(arg)
	local arg2
	arg, arg2 = (arg or ""):lower():match("^%s*(%S*)%s*(%S*)")
	local o = self.obs
	local busy = (o.state == "running" or o.state == "failed" or (o.restored and (o.restored.failed or o.restored.bad)))
	if arg == "observe" then
		-- Keyboard-and-mouse style only, positively confirmed; the key is the control in the Controller UI.
		if not mkbStyle() then oadd("observer: slash command refused: style %s (needs the keyboard-and-mouse style confirmed); use the key", styleOf() or "unknown"); return end
		if arg2 == "stop" then if not self:ObsStop("slash stop") then osay("Observer: not running (state %s).", o.state) end
		elseif arg2 == "clear" then
			if o.state == "running" then osay("Observer: stop it first."); return end
			if self:ProbeCleanupPending() then osay("Observer: not while the probe's cleanup is pending (%s); the saved report records its result when it completes.", tostring(self:ActiveCleanupStatus())); return end
			if o.state == "failed" then osay("Observer: the failure report is kept until a reload; nothing cleared (its saved copy is cleared after the reload, with this command)."); return end
			self:ReportClear(); self:OutcomeHide(); o.state = "idle"
			osay("Observer: cleared (the saved report too).")
		else osay("Observer: its key starts and stops an observation in the Controller UI; /bs gamepad observe stop | clear here.") end
	elseif arg == "browse" then
		if not mkbStyle() then nadd("browse: slash command refused: style %s (needs the keyboard-and-mouse style confirmed); use the Settings checkbox", styleOf() or "unknown"); return end
		if arg2 == "on" or arg2 == "off" then
			local ok, why = self:SetBrowseEnabled(arg2 == "on")
			if ok then osay("Controller browsing %s (the \"Controller browsing (alpha)\" option in Settings > Plugins > BagSmith Gamepad > Options).", arg2 == "on" and "enabled" or "disabled")
			else osay("Controller browsing could not be changed: %s", tostring(why)) end
		else osay("Controller browsing is %s. /bs gamepad browse on|off, or Settings > Plugins > BagSmith Gamepad > Options.", self:BrowseEnabled() and "on" or "off") end
	elseif arg == "nav" then
		if not mkbStyle() then oadd("nav: slash command refused: style %s (needs the keyboard-and-mouse style confirmed)", styleOf() or "unknown"); return end
		if o.state == "running" then osay("Nav: not while an observation is running."); return end
		if self:ProbeCleanupPending() then osay("Nav: not while a cleanup is pending (%s).", tostring(self:ActiveCleanupStatus())); return end
		-- (0.1.1-alpha) only on and off create the settings; a status query reads them
		if arg2 == "on" or arg2 == "off" then self.probeConfig = self.probeConfig or { version = REPORT_VERSION } end
		if arg2 == "on" then self.probeConfig.nav = true; self:ReportSave("config"); osay("Navigation prototype enabled for the next observation (D-pad only; it replaces the one-key probe while enabled).")
		elseif arg2 == "off" then self.probeConfig.nav = nil; self:ReportSave("config"); osay("Navigation prototype disabled.")
		else osay("Nav: /bs gamepad nav on|off. Status: %s", (self.probeConfig and self.probeConfig.nav) and "enabled" or "disabled") end
	elseif arg == "probekey" or arg == "probe" then
		if not mkbStyle() then oadd("probe: slash command refused: style %s (needs the keyboard-and-mouse style confirmed)", styleOf() or "unknown"); return end
		if o.state == "running" then osay("Probe: not while an observation is running."); return end
		if self:ProbeCleanupPending() then osay("Probe: not while the previous probe's cleanup is pending (%s).", tostring(self:ActiveCleanupStatus())); return end
		if arg == "probekey" then self:ProbeSetKey(arg2 ~= "" and arg2 or nil, nil)
		else
			if arg2 == "on" then
				-- (0.1.1-alpha) a nav-only configuration has no key: a key is what probe needs, not just settings
				if not (self.probeConfig and type(self.probeConfig.key) == "string") then osay("Probe: set a key first (/bs gamepad probekey PADLSTICK, then confirm or rely on the readback)."); return end
				self.probeConfig.enabled = true; self:ReportSave("config"); osay("Probe enabled for the next observation (key %s).", self.probeConfig.key)
			elseif arg2 == "off" then if self.probeConfig then self.probeConfig.enabled = nil; self:ReportSave("config") end; osay("Probe disabled.")
			else osay("Probe: /bs gamepad probekey <KEY|confirm|off>; /bs gamepad probe on|off. Status: %s", (self.probeConfig and type(self.probeConfig.key) == "string") and (self.probeConfig.key .. (self.probeConfig.enabled and " enabled" or " disabled") .. (self.probeConfig.confirmed and " confirmed" or "")) or "no key") end
		end
	elseif arg == "show" then
		-- The report: only with the keyboard-and-mouse style positively confirmed (the window focuses an EditBox), never during an observation.
		local st = styleOf()
		if st ~= "Mkb" then oadd("show refused: style %s (needs the keyboard-and-mouse style confirmed)", st or "unknown"); return end
		if o.state == "running" then osay("Controller diagnostics: stop the observer first (its key, or /bs gamepad observe stop)."); return end
		if GP.ctx then GP.ctx:ShowCopyableText("Controller Diagnostics", "Read only. Copy this and send it along. It is kept in memory only and is dropped on logout or /bs gamepad clear (the observer's report is kept while it is active or failed).", self:Text()) else ns:Print("Not active: BagSmith's API is not available.") end
	elseif arg == "stop" then
		self:Stop("stop")
	elseif arg == "clear" then
		if busy then osay("Controller diagnostics: the observer is %s; its report is kept. Not cleared.", o.state); return end
		self:Clear(); ns:Print("Controller diagnostics dropped.")
	elseif self.capturing then
		local left = math.max(0, math.ceil((self.deadline or 0) - stamp()))
		ns:Print("Controller diagnostics are still capturing (%d s left). /bs gamepad stop first, or wait.", left)
	else
		if busy then osay("Controller diagnostics: the observer is %s; its report is kept. Not started.", o.state); return end
		self.log = {}
		self:Snapshot()
		self:Start()
		ns:Print("Controller diagnostics (probe %s): use the mouse, keyboard and pad for a minute; then /bs gamepad show.", GP.PROBE)
	end
end

-- Legacy report migration: BagSmithProbeReport (declared by BagSmith's TOC through one more release) is copied
-- once into the companion's own saved variable, verified, and left in place for the rollback window.
local function deepCopy(v, d) if type(v) ~= "table" then return v end d = d or 0; if d > 12 then return nil end local o = {}; for k, x in pairs(v) do o[k] = deepCopy(x, d + 1) end return o end
local function same(a, b, d)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	d = d or 0; if d > 12 then return true end
	for k, v in pairs(a) do if not same(v, b[k], d + 1) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end
function GP:MigrateLegacyReport()
	local store = db()
	local legacy = _G.BagSmithProbeReport
	if store.legacyMigrated then return "done" end
	if type(legacy) ~= "table" then return "nothing" end
	local c = deepCopy(legacy)
	if not same(c, legacy) then return "not verified" end   -- (the original stays; nothing is claimed migrated)
	store.legacyReport = c
	if store.report == nil then store.report = deepCopy(legacy) end
	store.legacyMigrated = { at = (time and time()) or 0, verified = true, from = "BagSmithProbeReport" }
	return "migrated"
end
-- Activation, from BagSmith.API after registration (once, after BagSmith is ready).
function GP:Activate(ctx)
	self.ctx = ctx
	self.active, self.inactiveReason = true, nil
	ctx:RegisterCommand("gamepad", function(arg) GP:Command(arg) end)   -- the diagnostics' name, kept
	ctx:RegisterOptions({ title = "BagSmith Gamepad (alpha)", render = function(ui)
		ui:Text(("BagSmith Gamepad %s, alpha: incomplete, and not yet verified in this client. The addon being enabled and controller browsing being on are two different things: browsing stays off until you turn it on here."):format(tostring(ns.version)))
		ui:Check("Controller browsing (alpha)", "With the game's Controller UI on: the D-pad moves a highlight between items and shows their tooltips, and East closes the bag. No item actions. Alpha: the hand-back of the D-pad at combat start is implemented but not yet verified in this client; use it out of combat.",
			function() return GP:BrowseEnabled() end, function(v) local ok, why = GP:SetBrowseEnabled(v); if not ok then ns:Print("Could not change controller browsing: %s", tostring(why)) end end)
		ui:Text("Diagnostics (not needed for browsing): /bs gamepad in the keyboard-and-mouse style; the Observer keybinding under BagSmith in the game's key bindings.")
	end })
	ctx:Subscribe("PROFILE_CHANGED", function() GP:NavTooltipHide(); GP:BrowseApplySetting() end)   -- one listener; the new profile's preference is read once by BrowseApplySetting
	self:BrowseHookWindow()
	self:BrowseListenForStyle()
	if self:BrowseEnabled() and viewOpen() then self:BrowseStart("activated with the bag open") end
end
function GP:Deactivate(reason)
	-- the latch first, so nothing started by the cleanup below (or by a later combat end) can rearm anything;
	-- the context is kept for read-only queries and the release of what is still installed
	self.active, self.inactiveReason = false, "shut down: " .. tostring(reason)
	if self.nav then self:NavEnd("plugin shutdown: " .. tostring(reason)) end
	self:BrowseStop("plugin shutdown")
	if self.obs and self.obs.state == "running" then self:ObsStop("plugin shutdown") end
	if self.probe then self:ProbeEnd("plugin shutdown") end
end
ns:On("ADDON_LOADED", function(name)
	if name ~= ADDON then return end
	db()
	GP:MigrateLegacyReport()
	ns:On("PLAYER_LOGOUT", function() GP:ObsStop("logout"); GP:Clear() end)   -- the observer's report persists (saved as interrupted); the diagnostics log never does
	GP:ObsListenFrame()   -- exists from the start, hidden, nothing registered
	GP:OutcomeCard()      -- the passive card exists before anything is observed
	GP:ReportRestore()    -- a report saved before an orderly reload is kept for the copy window
	-- register with BagSmith: the activation callback runs once, deferred, when BagSmith is ready (early or late)
	local api = _G.BagSmith and _G.BagSmith.API
	if not (api and api.RegisterPlugin) then ns:Print("BagSmith (with plugin API 1.0 or later) is required and was not found; the companion is idle."); return end
	local handle, code, msg = api:RegisterPlugin({ id = ns.PLUGIN_ID, addon = ADDON, apiMajor = 1, apiMinor = 0, name = "BagSmith Gamepad", version = ns.version },
		{ onEnable = function(ctx) GP:Activate(ctx) end, onShutdown = function(_, reason) GP:Deactivate(reason) end })
	if not handle then GP.inactiveReason = ("registration refused: %s"):format(tostring(code)); ns:Print("Could not register with BagSmith (%s): %s. The companion is idle; see Settings > Plugins.", tostring(code), tostring(msg)) end
	GP.handle = handle
end)
