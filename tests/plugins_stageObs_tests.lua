;(function()
	-- 1.0.0 Probe A (probeObs): a bounded, read-only observation under the Controller UI; it sets nothing, stops at a wall-clock deadline, fails terminally with frozen evidence, and opens nothing unless the style is confirmed.
	local function ser(v, seen)
		local t = type(v); if t ~= "table" then return t .. ":" .. tostring(v) end
		seen = seen or {}; if seen[v] then return "<cycle>" end; seen[v] = true
		local keys = {}; for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		local out = {}; for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. ser(v[k], seen) end
		return "{" .. table.concat(out, ",") .. "}"
	end
	local function forbid(name) return function() error("Probe A must not call " .. name) end end
	local function boot(opts)
		opts = opts or {}
		package.loaded.mock = nil
		local M = require("mock")
		local S = { M = M, style = "Gamepad", core = true, editFocus = nil, coreCalls = 0, focusCalls = 0 }
		local mgr = { shownFrames = {}, focusedFrame = nil, isUIFocused = false, fallThroughCatcherActive = false,
			FrameShown = forbid("FrameShown"), FrameHidden = forbid("FrameHidden"), FocusFrame = forbid("FocusFrame"), SuspendFrame = forbid("SuspendFrame") }
		S.mgr = mgr
		_G.GamepadMode = { FrameControlsManager = mgr, ActivateBindingGroup = forbid("ActivateBindingGroup"), DeactivateBindingGroup = forbid("DeactivateBindingGroup") }
		_G.GamepadSharedUtility = { InputBindingManager = { IsOnlyCoreBindingSetActive = function()
			S.coreCalls = S.coreCalls + 1
			if S.failInQuery then S.failInQuery = nil; M.fire("ADDON_ACTION_FORBIDDEN", "BagSmith", "InsideQuery") end
			return S.core end, AddBindingSet = forbid("AddBindingSet"), RemoveSet = forbid("RemoveSet"), BindToCoreBindingActive = forbid("BindToCoreBindingActive") } }
		_G.SmartNavigation = setmetatable({}, { __index = function(_, k) return forbid("SmartNavigation." .. tostring(k)) end })
		-- the style, as a pair of queries the probe must agree with each other; opts.styleMode varies it
		local mode = opts.styleMode or "ok"
		if mode == "mkbQueryMissing" or mode == "mkbQueryMissingOdd" then
			-- the review's example: IsGamepadUIEnabled false, IsMKBUIEnabled unavailable, GetCurrentStyle nil (or unrecognized), Enum lacking Mkb
			_G.InputUtil = { IsGamepadUISupported = function() return true end, IsGamepadUIEnabled = function() return false end }
			_G.C_InputInterfaceStyle = { GetCurrentStyle = function() if mode == "mkbQueryMissingOdd" then return 7 end return nil end }
			_G.Enum = _G.Enum or {}; _G.Enum.InputDeviceInterfaceType = { Gamepad = 1 }
		elseif mode == "gamepadQueryMissing" then
			-- the mirror: IsGamepadUIEnabled true, IsMKBUIEnabled unavailable, GetCurrentStyle nil, Enum lacking Gamepad
			_G.InputUtil = { IsGamepadUISupported = function() return true end, IsGamepadUIEnabled = function() return true end }
			_G.C_InputInterfaceStyle = { GetCurrentStyle = function() return nil end }
			_G.Enum = _G.Enum or {}; _G.Enum.InputDeviceInterfaceType = { Mkb = 0 }
		elseif mode ~= "absent" then
			_G.InputUtil = {
				IsGamepadUISupported = function() return true end,
				IsGamepadUIEnabled = function()
					if mode == "throws" then error("no") end
					if mode == "odd" then return "yes" end
					if mode == "inconsistent" then return true end
					return S.style == "Gamepad" end,
				IsMKBUIEnabled = function()
					if mode == "inconsistent" then return true end
					return S.style == "Mkb" end }
			_G.C_InputInterfaceStyle = { GetCurrentStyle = function() return S.style == "Gamepad" and 1 or 0 end }
			_G.Enum = _G.Enum or {}; _G.Enum.InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 }
		end
		_G.SetOverrideBinding, _G.SetOverrideBindingClick, _G.ClearOverrideBindings, _G.SetBinding, _G.SetCVar = forbid("SetOverrideBinding"), forbid("SetOverrideBindingClick"), forbid("ClearOverrideBindings"), forbid("SetBinding"), forbid("SetCVar")
		_G.EnableGamePadButton, _G.EnableGamePadStick = forbid("EnableGamePadButton"), forbid("EnableGamePadStick")
		S.overrideReads, S.baseReads = 0, 0
		_G.GetBindingAction = opts.getBindingAction or function(key, override)
			if override then S.overrideReads = S.overrideReads + 1 else S.baseReads = S.baseReads + 1 end
			if S.witnessOnFirstRead and override then local w = S.witnessOnFirstRead; S.witnessOnFirstRead = nil; M.fire(w, "BagSmith", "InsideBindingRead") end
			if key == "PAD1" then return override and "CLICK SomeNativeButton:LeftButton" or "GAMEPAD_JUMP" end return "" end
		_G.GetCurrentKeyBoardFocus = function() S.focusCalls = S.focusCalls + 1; return S.editFocus end
		_G.debugstack = function() return "stack line 1\nstack line 2" end
		_G.C_EventUtils = opts.validator and { IsEventValid = opts.validator } or nil
		M.unknownEvents = opts.unknownEvents
		local parked = CreateFrame("Frame", "SomeHiddenParent", UIParent); parked:Hide()
		local cb = CreateFrame("Frame", "ContainerFrameCombinedBags", opts.parked and parked or ContainerFrameContainer); cb:Hide()
		_G.ContainerFrameCombinedBags = cb
		S.cb = cb
		M.put(0, 1, { id = 7001, name = "Water", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
		if not opts.keepReport then _G.BagSmithGamepadDB = nil end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
		local n = M.loadAddon("BagSmith")
		local gpns = dofile("tests/companion_loader.lua")(M, "BagSmith_Gamepad", "BagSmith_Gamepad")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("ADDON_LOADED", "BagSmith_Gamepad"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		S.n, S.GP, S.gpns = n, gpns.Gamepad, gpns
		-- count every call into the share window and any EditBox focus
		S.shareCalls = 0
		local orig = n.ShareWindow
		n.ShareWindow = function(...) S.shareCalls = S.shareCalls + 1; return orig(...) end
		if not opts.noIsEventRegistered then S.GP.obsEvents.IsEventRegistered = function(self, e) return self.events[e] == true end end
		function S.events() local c = 0; for _ in pairs(S.GP.obsEvents.events) do c = c + 1 end; return c end
		function S.timers() local t = S.GP.obs.timer; return (t and not t.cancelled) and 1 or 0 end   -- the observer's own timer handle
		function S.saved() return ser(_G.BagSmithDB) .. "|" .. ser(_G.BagSmithCharDB) end
		return S
	end
	local function cleanup()
		_G.BagSmithGamepadDB = nil   -- (a fresh install for the next scenario; the reload scenarios keep it on purpose)
		_G.GamepadMode, _G.GamepadSharedUtility, _G.SmartNavigation, _G.InputUtil, _G.C_InputInterfaceStyle, _G.debugstack, _G.C_EventUtils = nil, nil, nil, nil, nil, nil, nil
		_G.SetOverrideBinding, _G.SetOverrideBindingClick, _G.ClearOverrideBindings, _G.SetBinding, _G.SetCVar, _G.EnableGamePadButton, _G.EnableGamePadStick = nil, nil, nil, nil, nil, nil, nil
		_G.GetBindingAction, _G.GetCurrentKeyBoardFocus, _G.ContainerFrameCombinedBags = nil, nil, nil
	end

	local function reload(opts)
		-- an orderly reload: the saved globals survive, the Lua state does not
		local saved = (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report)
		_G.GamepadMode, _G.GamepadSharedUtility, _G.SmartNavigation, _G.InputUtil, _G.C_InputInterfaceStyle, _G.debugstack, _G.C_EventUtils = nil, nil, nil, nil, nil, nil, nil
		_G.SetOverrideBinding, _G.SetOverrideBindingClick, _G.ClearOverrideBindings, _G.SetBinding, _G.SetCVar, _G.EnableGamePadButton, _G.EnableGamePadStick = nil, nil, nil, nil, nil, nil, nil
		_G.GetBindingAction, _G.GetCurrentKeyBoardFocus, _G.ContainerFrameCombinedBags = nil, nil, nil
		_G.BagSmithGamepadDB = { version = 1, report = saved }
		opts = opts or {}; opts.keepReport = true
		return boot(opts)
	end
	-- persistence: stop, reload, export
	local S = boot()
	BagSmith_Observer(); for _ = 1, 3 do S.M.elapse() end
	table.insert(S.mgr.shownFrames, S.cb); S.M.elapse()
	BagSmith_Observer()
	local r = (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report)
	check(r and r.version == 1 and r.probe == S.gpns.version and r.how == "stop" and r.state == "stopped" and r.failed == false and r.samples == 4 and r.changes == 1 and #r.lines > 0 and r.lastState:find("shown 1", 1, true), "a normal stop saves a versioned report with its outcome and lines")
	S.GP.log = nil
	check(S.GP:Text():find("^Stage A diagnostics capture: none in memory") and S.GP:Text():find("== Observer ==", 1, true), "with no diagnostics capture the report says so without implying the observer's report is missing")
	check(ser(_G.BagSmithDB):find("ProbeReport", 1, true) == nil, "BagSmithDB is not where the report lives")
	S = reload()
	check(S.GP.obs.restored and S.GP.obs.restored.state == "stopped" and S.GP.obs.state == "idle" and not S.GP.outcome:IsShown() and S.GP.outcome.lines[1].text == "BagSmith Gamepad " .. S.gpns.version .. ": saved report restored (stopped)" and S.GP.outcome.lines[5].text:find("^samples 4 |"),
		"after a reload the stopped report is restored for the copy window without putting the card on screen")
	check(S.GP.outcome.close and S.GP.outcome.close:GetScript("OnClick") ~= nil, "the card has a close button")
	S.style = "Mkb"; S.GP:Command("show")
	check(S.shareCalls == 1 and S.n.Popups.share.locked:find("== Observer (restored from the saved report: stopped, saved on stop) ==", 1, true) and S.n.Popups.share.locked:find("OBSERVER STOP (key): 4 samples", 1, true), "the restored report exports through the unchanged keyboard-and-mouse-only copy window")
	S.n.Popups.share:Hide()
	S.style = "Gamepad"; S.GP:Command("show")
	check(S.shareCalls == 1, "the copy-window guard is unchanged: nothing opens in the Gamepad style")
	-- a new observation replaces a stopped report explicitly; the old one is gone from the saved variable
	BagSmith_Observer()
	check(S.GP.obs.state == "running" and S.GP.obs.restored == nil and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).how == "start" and S.GP:ObsText():find("the saved stopped report (4 samples) is replaced by this observation", 1, true), "a new start replaces a stopped report, saying so")
	BagSmith_Observer(); cleanup()
	-- persistence: failure, reload, export; a saved failure must be cleared before any new start; legacy clear cannot drop it
	S = boot()
	BagSmith_Observer(); for _ = 1, 2 do S.M.elapse() end
	S.M.fire("ADDON_ACTION_FORBIDDEN", "BagSmith", "SomeProtectedFunction")
	r = (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report)
	check(r and r.how == "failure" and r.state == "failed" and r.failed == true and r.failure == "ADDON_ACTION_FORBIDDEN SomeProtectedFunction (by BagSmith)" and r.firstStack == "stack line 1 | stack line 2" and r.lastObservedAt and r.lastState:find("style Gamepad core true", 1, true),
		"a failure saves the frozen report with the first failure, its stack and the last-observed state")
	local coreBefore = S.coreCalls
	S = reload()
	check(S.GP.obs.restored.state == "failed" and S.GP.outcome.lines[2].text:find("^state failed | failure latch SET | last observed at t%+") and S.GP.outcome.lines[3].text == "first failure: ADDON_ACTION_FORBIDDEN SomeProtectedFunction (by BagSmith)" and S.GP.outcome.lines[4].text == "stack: stack line 1 | stack line 2",
		"after a reload the failure report is restored with its evidence on the card")
	check(S.coreCalls == 0 and S.focusCalls == 0 and S.overrideReads == 0, "restoring a report queries nothing native")
	BagSmith_Observer()
	check(S.GP.obs.state == "idle" and S.events() == 0 and S.GP:ObsText():find("a saved failure report is on file; /bs gamepad observe clear it first", 1, true), "a saved failure report blocks a new observation until cleared")
	S.style = "Mkb"
	S.GP:Command("clear"); S.GP:Command("")
	check((_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report) ~= nil and S.GP.obs.restored.state == "failed", "the legacy clear and bare commands cannot drop a saved failure report")
	S.GP:Command("show")
	check(S.shareCalls == 1 and S.n.Popups.share.locked:find("== Observer (restored from the saved report: failed, saved on failure) ==", 1, true) and S.n.Popups.share.locked:find("OBSERVER FAILED at", 1, true), "the restored failure report exports")
	S.n.Popups.share:Hide()
	S.GP:Command("observe clear")
	check((_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report) == nil and S.GP.obs.restored == nil and not S.GP.outcome:IsShown(), "observe clear in the keyboard-and-mouse style clears the saved report explicitly")
	S.style = "Gamepad"; BagSmith_Observer()
	check(S.GP.obs.state == "running", "after the explicit clear a new observation may start")
	BagSmith_Observer(); cleanup()
	-- persistence: an interrupted run (reload mid-run) is recovered from the progress saves and from the logout stop
	S = boot()
	BagSmith_Observer(); for _ = 1, 50 do S.M.elapse() end
	check((_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).how == "progress" and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).samples == 50 and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).state == "running", "every 50 samples the report is saved mid-run")
	for _ = 1, 7 do S.M.elapse() end
	S.M.fire("PLAYER_LOGOUT")
	r = (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report)
	check(r.how == "logout" and r.state == "stopped" and r.samples == 57 and S.GP.obs.state == "stopped", "a logout or reload mid-run saves the run as of that moment")
	S = reload()
	check(S.GP.obs.restored.state == "interrupted" and S.GP.outcome.lines[1].text:find("restored (interrupted)", 1, true) and S.GP.outcome.lines[2].text:find("last saved:", 1, true) and S.GP.outcome.lines[5].text:find("^samples 57 |"), "after the reload the run is restored as interrupted, with its last saved state")
	S.style = "Mkb"; S.GP:Command("show")
	check(S.shareCalls == 1 and S.n.Popups.share.locked:find("restored from the saved report: interrupted, saved on logout", 1, true), "an interrupted run exports")
	S.n.Popups.share:Hide(); cleanup()
	-- a run cut off before the logout handler (a progress save only) is also interrupted
	S = boot()
	BagSmith_Observer(); for _ = 1, 50 do S.M.elapse() end
	S = reload()
	check(S.GP.obs.restored.state == "interrupted" and S.GP.obs.restored.samples == 50 and S.GP.obs.restored.how == "progress", "a run that only reached a progress save is restored as interrupted")
	cleanup()
	-- an unreadable saved report is reported, blocks nothing but a new start until cleared, and clears
	_G.BagSmithGamepadDB = { version = 1, report = { version = 99 } }
	S = boot({ keepReport = true })
	check(S.GP.obs.restored and S.GP.obs.restored.bad and S.GP.outcome.lines[2].text:find("unreadable", 1, true), "an unreadable saved report is said to be unreadable")
	BagSmith_Observer()
	check(S.GP.obs.state == "idle" and S.GP:ObsText():find("a saved unreadable report is on file", 1, true), "it blocks a new start until cleared")
	S.style = "Mkb"; S.GP:Command("observe clear"); S.style = "Gamepad"; BagSmith_Observer()
	check((_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).how == "start" and S.GP.obs.state == "running", "after clearing it a new observation starts and saves")
	BagSmith_Observer(); cleanup()

	-- identity, the key, nothing registered until started
	S = boot()
	check(S.GP.PROBE == S.gpns.version and BINDING_NAME_BAGSMITH_OBSERVER and type(BagSmith_Observer) == "function" and S.GP.obsEvents and S.events() == 0 and S.GP.outcome and not S.GP.outcome:IsShown(),
		"probeObs identifies itself, offers the observer key, has its listener frame with nothing registered and its card precreated and hidden")
	S.style = "Mkb"
	BagSmith_Observer()
	check(S.GP.obs.state == "idle" and S.events() == 0 and S.M.log[#S.M.log]:find("not started: the interface style is Mkb", 1, true), "the key in the keyboard-and-mouse style starts nothing and says so in chat")
	-- start: explicit, logged with the deadline; a full snapshot and the binding readback; no saved data
	S.style = "Gamepad"
	local chat0, saved0 = #S.M.log, S.saved()
	BagSmith_Observer()
	local text = S.GP:ObsText()
	check(S.GP.obs.state == "running" and text:find("OBSERVER START (key): PROBE " .. S.gpns.version .. "; sample every 0.1 s; deadline 180 s of elapsed time", 1, true), "the key starts an observation, logging its sample interval and elapsed-time deadline")
	check(text:find("snapshot (start): style=Gamepad core=true shownCount=0 shownNames= focused=none uiFocused=false catcher=false editFocus=none combat=false bsMain=false nativeCombinedShown=false nativeCombinedParent=ContainerFrameContainer nativeFramesShown=", 1, true) and text:find(" gameMenu=unknown popups=0", 1, true),
		"the start snapshot reads native and BagSmith state, with unknowns labeled")
	check(text:find("bindings (start; override/base/gamepad-context): PAD1=CLICK SomeNativeButton:LeftButton/GAMEPAD_JUMP/noctx PAD2=-/-/noctx", 1, true), "the binding readback lists the override and base action per pad key, and says when the gamepad binding context cannot be asked")
	check(S.events() == 11 and #S.M.log == chat0 and S.saved() == saved0 and S.timers() == 1, "eleven listeners, nothing printed to chat, no saved data written, one timer pending")
	-- samples: only changes are logged
	for _ = 1, 5 do S.M.elapse() end
	check(S.GP.obs.samples == 5 and S.GP.obs.changes == 0 and not S.GP:ObsText():find("change:", 1, true), "quiet samples log nothing")
	table.insert(S.mgr.shownFrames, S.cb); S.mgr.focusedFrame = S.cb; S.core = false
	S.M.elapse()
	check(S.GP.obs.changes == 1 and S.GP:ObsText():find("sample 6 change: core: true -> false; shownCount: 0 -> 1; shownNames:  -> ContainerFrameCombinedBags; focused: none -> ContainerFrameCombinedBags", 1, true), "a native frame appearing is logged as one change with every differing field")
	S.n.Window:Show(); S.M.elapse()
	check(S.GP:ObsText():find("bsMain: false -> true", 1, true), "BagSmith's own window showing is logged")
	S.editFocus = CreateFrame("EditBox", "BagSmithSearchBoxMock"); S.M.elapse()
	check(S.GP:ObsText():find("editFocus: none -> BagSmithSearchBoxMock", 1, true), "an EditBox taking focus is logged")
	S.M.fire("MERCHANT_SHOW")
	check(S.GP:ObsText():find("event MERCHANT_SHOW", 1, true), "context events are logged")
	-- the report is refused during the observation, whatever the style
	S.GP:Command("show")
	S.style = "Mkb"; S.GP:Command("show"); S.style = "Gamepad"
	check(S.shareCalls == 0, "show never opens the window during an observation")
	-- an unsampled change right before a normal stop: the stop snapshot captures it, and card and report agree
	S.mgr.isUIFocused = true
	local savedBeforeStop = S.saved()
	BagSmith_Observer()
	text = S.GP:ObsText()
	check(S.GP.obs.state == "stopped" and text:find("snapshot (stop): style=Gamepad core=false shownCount=1 shownNames=ContainerFrameCombinedBags focused=ContainerFrameCombinedBags uiFocused=true", 1, true) and not text:find("uiFocused: false -> true", 1, true),
		"the stop snapshot captures a change that no sample saw, without a fabricated change line")
	check(text:find("OBSERVER STOP (key): 8 samples, ", 1, true) and text:find(" s elapsed, 3 changes", 1, true) and S.events() == 0 and S.timers() == 0, "the key stops it: samples, elapsed time and changes reported separately, listeners released, timer cancelled")
	local card = S.GP.outcome
	check(card:IsShown() and card.lines[1].text == "BagSmith Gamepad " .. S.gpns.version .. ": observation over (key)" and card.lines[2].text == "state stopped | failure latch clear | at stop: style Gamepad core false shown 1 native bag ContainerFrameContainer"
		and card.lines[3].text == "first failure: none" and card.lines[4].text == "stack: n/a" and card.lines[5].text:find("^samples 8 | elapsed ") and card.lines[5].text:find("| changes 3 | listeners still registered 0", 1, true),
		"the outcome card shows the stop snapshot's state and the separate sample and elapsed counts")
	S.style = "Mkb"
	S.GP:Command("show")
	check(S.shareCalls == 1 and S.n.Popups.share:IsShown() and S.n.Popups.share.locked == S.GP:Text() and S.GP:Text():find("== Observer ==", 1, true), "after the stop, in a confirmed keyboard-and-mouse style, the report opens read-only with the observer section")
	S.n.Popups.share:Hide()
	check(S.n.Window.main:IsShown() == true and S.saved() == savedBeforeStop, "the observer never changed the window's state (the test showed it); stop, show and clear wrote no saved data")
	S.GP:Command("observe clear")
	check(S.GP.obs.state == "idle" and not card:IsShown(), "clear hides the card and allows a new observation")
	cleanup()
	-- the deadline is wall-clock: a clock jump stops it with fewer samples
	S = boot()
	BagSmith_Observer()
	for _ = 1, 3 do S.M.elapse() end
	S.M.gameTime = S.M.gameTime + 300
	S.M.elapse()
	check(S.GP.obs.state == "stopped" and S.GP.obs.samples == 4 and S.GP.obs.elapsed >= 180 and S.GP:ObsText():find("OBSERVER STOP (deadline): 4 samples, ", 1, true) and S.events() == 0 and S.timers() == 0,
		"a clock jump past the deadline stops the observation at the next opportunity, with the real elapsed time and only four samples, nothing rescheduled")
	S.M.elapse()
	check(S.GP.obs.samples == 4, "no sample runs after the stop")
	cleanup()
	-- failure: evidence first, latch, timer cancelled, every listener gone, no further query, report frozen, terminal
	for _, which in ipairs({ "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do
		S = boot()
		BagSmith_Observer(); for _ = 1, 3 do S.M.elapse() end
		S.mgr.isUIFocused = true   -- (an unsampled change: it must not appear as "sampled after the failure")
		local savedBeforeAbort, coreBefore, focusBefore = S.saved(), S.coreCalls, S.focusCalls
		S.M.fire(which, "OtherAddon", "Irrelevant")
		check(S.GP.obs.state == "running" and not S.GP.obsFailed, "another addon's " .. which .. " is ignored")
		S.M.fire(which, "BagSmith", "SomeProtectedFunction")
		text = S.GP:ObsText()
		check(S.GP.obsFailed and S.GP.obs.state == "failed" and S.GP.obsFailure == which .. " SomeProtectedFunction (by BagSmith)" and S.GP.obsFirstStack == "stack line 1 | stack line 2", which .. ": the first event's addon, event, function and stack are captured and the failure latched")
		check(text:find("OBSERVER FAILED at ", 1, true) and text:find("(sample 3, state running): " .. which .. " SomeProtectedFunction (by BagSmith)", 1, true) and text:find("last observed (t+", 1, true) and text:find("before the failure): style=Gamepad core=true shownCount=0", 1, true) and text:find("uiFocused=false", 1, true) and text:find("report frozen; terminal until a reload", 1, true),
			which .. ": the report records the last-observed snapshot as observed before the failure, not a new one")
		check(S.events() == 0 and S.timers() == 0 and S.coreCalls == coreBefore and S.focusCalls == focusBefore, which .. ": every listener unregistered, the timer cancelled, no native query made on the failure path")
		S.M.fire(which, "BagSmith", "AnotherFunction"); S.M.elapse()
		check(S.GP.obsFailure == which .. " SomeProtectedFunction (by BagSmith)" and S.GP.obs.samples == 3 and S.coreCalls == coreBefore and S.GP:ObsText() == text, which .. ": repeated events and later timers change nothing; the report is frozen")
		card = S.GP.outcome
		check(card:IsShown() and card.lines[2].text:find("^state failed | failure latch SET | last observed at t%+") and card.lines[2].text:find("(before the failure): style Gamepad core true shown 0 native bag ContainerFrameContainer", 1, true)
			and card.lines[3].text == "first failure: " .. which .. " SomeProtectedFunction (by BagSmith)" and card.lines[4].text == "stack: stack line 1 | stack line 2" and card.lines[5].text:find("| listeners still registered 0", 1, true),
			which .. ": the card shows the latch, the last-observed state labeled as such, the first failure, its stack and zero listeners")
		BagSmith_Observer()
		check(S.GP.obs.state == "failed" and S.GP.obs.samples == 3 and S.coreCalls == coreBefore, which .. ": the key is ignored after a latched failure")
		S.style = "Mkb"
		S.GP:Command("observe clear"); S.GP:Command("clear"); S.GP:Command("")
		check(S.GP.obs.state == "failed" and S.GP.obsFailed and S.GP:ObsText() == text and S.GP.log == nil or S.GP:ObsText() == text, which .. ": observe clear, the legacy clear and the bare command cannot drop or overwrite the failure report")
		S.GP:Command("show")
		check(S.shareCalls == 1 and S.n.Popups.share:IsShown() and S.n.Popups.share.locked:find(text, 1, true), which .. ": the frozen report stays copyable")
		S.n.Popups.share:Hide()
		check(S.saved() == savedBeforeAbort, which .. ": the failure path wrote no saved data")
		cleanup()
	end
	-- failure during a query: the read stops without further queries; nothing logged as a sample
	S = boot()
	BagSmith_Observer(); S.M.elapse()
	local focusBefore = S.focusCalls
	S.failInQuery = true
	S.M.elapse()
	check(S.GP.obs.state == "failed" and S.GP.obsFailure == "ADDON_ACTION_FORBIDDEN InsideQuery (by BagSmith)" and S.focusCalls == focusBefore and S.events() == 0 and S.timers() == 0 and not S.GP:ObsText():find("sample 2 change", 1, true),
		"a failure raised inside a query latches at once: the rest of the read makes no further query, nothing is rescheduled")
	cleanup()
	-- a witness fired by the very first binding read: no second read, no later query of any kind
	for _, which in ipairs({ "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do
		S = boot()
		S.witnessOnFirstRead = which
		local coreBefore, focusBefore = S.coreCalls, S.focusCalls
		BagSmith_Observer()
		check(S.GP.obs.state == "failed" and S.GP.obsFailure == which .. " InsideBindingRead (by BagSmith)" and S.overrideReads == 1 and S.baseReads == 0,
			which .. " from the first binding read: the second read of that key never runs, and no further key is read")
		check(S.coreCalls == coreBefore + 1 and S.focusCalls == focusBefore + 1 and S.events() == 0 and S.timers() == 0, which .. ": the start snapshot's earlier queries ran once, nothing ran afterwards, listeners and timer gone")
		S.M.elapse()
		check(S.coreCalls == coreBefore + 1 and S.focusCalls == focusBefore + 1 and S.overrideReads == 1 and S.GP.obs.samples == 0, which .. ": no sample, no query after the latch")
		check(S.GP:ObsText():find("last observed (t+", 1, true) and not S.GP:ObsText():find("bindings (start", 1, true), which .. ": the report keeps the last-observed snapshot and no partial binding line")
		S.style = "Mkb"
		S.GP:Command("show")
		check(S.shareCalls == 1 and S.n.Popups.share:IsShown(), which .. ": a later explicit request in the confirmed keyboard-and-mouse style still opens the frozen report")
		S.n.Popups.share:Hide()
		cleanup()
	end
	-- a witness fired by a naming getter, a focus query or a parent query that then returns normally: no further getter runs
	local function namedThing(S, label, witnessFrom)
		-- a frame-like table whose getters count their calls; one of them may emit the witness and return nil/normally
		local t = { debugCalls = 0, nameCalls = 0 }
		t.GetDebugName = function() t.debugCalls = t.debugCalls + 1; if witnessFrom == "debug" then S.M.fire(S.witness, "BagSmith", "InsideGetDebugName"); return nil end return label end
		t.GetName = function() t.nameCalls = t.nameCalls + 1; return label end
		return t
	end
	local function assertTerminal(S, which, what, coreBefore, focusBefore)
		check(S.GP.obs.state == "failed" and S.GP.obsFailed and S.events() == 0 and S.timers() == 0 and S.GP:ObsText():find("report frozen; terminal until a reload", 1, true), which .. " " .. what .. ": terminal failure, zero listeners, no timer, frozen evidence")
		local text = S.GP:ObsText()
		S.M.elapse()
		check(S.GP.obs.samples == (S.expectedSamples or 0) and S.coreCalls == coreBefore and S.focusCalls == focusBefore and S.GP:ObsText() == text, which .. " " .. what .. ": no reschedule, no subsequent observation getter, report unchanged")
	end
	for _, which in ipairs({ "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do
		-- (a) a shown frame whose GetDebugName emits the witness and returns nil: its GetName never runs
		S = boot(); S.witness = which
		local victim = namedThing(S, "Victim", "debug")
		local after = namedThing(S, "After", nil)
		table.insert(S.mgr.shownFrames, victim); table.insert(S.mgr.shownFrames, after)
		local coreBefore = S.coreCalls
		BagSmith_Observer()
		check(victim.debugCalls == 1 and victim.nameCalls == 0 and after.debugCalls == 0 and after.nameCalls == 0, which .. " from GetDebugName: the fallback GetName never runs, and the next shown frame is never named")
		check(S.GP.obsFailure == which .. " InsideGetDebugName (by BagSmith)" and S.coreCalls == coreBefore + 1 and S.focusCalls == 0, which .. " from GetDebugName: the core query had run once before it; the keyboard-focus query never ran")
		S.expectedSamples = 0
		assertTerminal(S, which, "from GetDebugName", S.coreCalls, S.focusCalls)
		cleanup()
		-- (b) GetCurrentKeyBoardFocus emits the witness and returns a frame: neither of that frame's naming getters runs
		S = boot(); S.witness = which
		local focused = namedThing(S, "Focused", nil)
		_G.GetCurrentKeyBoardFocus = function() S.focusCalls = S.focusCalls + 1; S.M.fire(which, "BagSmith", "InsideKeyboardFocus"); return focused end
		BagSmith_Observer()
		check(focused.debugCalls == 0 and focused.nameCalls == 0 and S.focusCalls == 1, which .. " from GetCurrentKeyBoardFocus: the returned frame is never named")
		check(S.GP.obsFailure == which .. " InsideKeyboardFocus (by BagSmith)" and S.overrideReads == 0, which .. " from GetCurrentKeyBoardFocus: nothing after it ran (no binding read)")
		S.expectedSamples = 0
		assertTerminal(S, which, "from GetCurrentKeyBoardFocus", S.coreCalls, S.focusCalls)
		cleanup()
		-- (c) the combined bag's GetParent emits the witness and returns a different parent: neither parent naming getter runs
		S = boot(); S.witness = which
		local parent = namedThing(S, "Elsewhere", nil)
		local parentCalls = 0
		S.cb.GetParent = function() parentCalls = parentCalls + 1; S.M.fire(which, "BagSmith", "InsideGetParent"); return parent end
		local focusBefore = S.focusCalls
		BagSmith_Observer()
		check(parentCalls == 1 and parent.debugCalls == 0 and parent.nameCalls == 0, which .. " from GetParent: the returned parent is never named")
		check(S.GP.obsFailure == which .. " InsideGetParent (by BagSmith)" and S.focusCalls == focusBefore + 1 and S.overrideReads == 0, which .. " from GetParent: the focus query had run once before it; nothing after it ran")
		S.expectedSamples = 0
		assertTerminal(S, which, "from GetParent", S.coreCalls, S.focusCalls)
		cleanup()
		-- (d) the first style query emits the witness during a sample: the second style query does not run
		S = boot(); S.witness = which
		BagSmith_Observer(); S.M.elapse()
		local mkbCalls = 0
		local origG = _G.InputUtil.IsGamepadUIEnabled
		_G.InputUtil.IsGamepadUIEnabled = function() local v = origG(); S.M.fire(which, "BagSmith", "InsideStyleQuery"); return v end
		_G.InputUtil.IsMKBUIEnabled = function() mkbCalls = mkbCalls + 1; return false end
		local coreBefore2 = S.coreCalls
		S.M.elapse()
		check(S.GP.obsFailure == which .. " InsideStyleQuery (by BagSmith)" and mkbCalls == 0 and S.coreCalls == coreBefore2, which .. " from the first style query: the second style query and the core query never run")
		S.expectedSamples = 2
		assertTerminal(S, which, "from the first style query", S.coreCalls, S.focusCalls)
		cleanup()
	end
	-- absent enum members never confirm a style
	for _, mode in ipairs({ "mkbQueryMissing", "mkbQueryMissingOdd", "gamepadQueryMissing" }) do
		S = boot({ styleMode = mode })
		BagSmith_Observer()
		check(S.GP.obs.state == "idle" and S.events() == 0 and S.GP:ObsText():find("not started: the interface style is unknown", 1, true), "style " .. mode .. ": one boolean query alone never confirms a style, so the key starts nothing")
		S.GP:Command("show"); S.GP:Command("observe stop")
		check(S.shareCalls == 0 and not (S.n.Popups.share and S.n.Popups.share:IsShown()) and S.GP:ObsText():find("show refused: style unknown", 1, true), "style " .. mode .. ": the report is not opened and nothing is focused")
		cleanup()
	end
	-- the style must be positively confirmed: unknown permits neither a start nor the report
	for _, mode in ipairs({ "absent", "throws", "odd", "inconsistent" }) do
		S = boot({ styleMode = mode })
		BagSmith_Observer()
		check(S.GP.obs.state == "idle" and S.events() == 0 and S.GP:ObsText():find("not started: the interface style is unknown", 1, true), "style " .. mode .. ": the key starts nothing")
		S.GP:Command("show"); S.GP:Command("observe stop")
		check(S.shareCalls == 0 and not (S.n.Popups.share and S.n.Popups.share:IsShown()) and S.GP:ObsText():find("show refused: style unknown", 1, true), "style " .. mode .. ": the report is not opened and nothing is focused")
		cleanup()
	end
	S = boot()
	BagSmith_Observer(); BagSmith_Observer()
	S.style = "Mkb"; S.GP:Command("show")
	check(S.shareCalls == 1, "a confirmed keyboard-and-mouse style after a stop opens the report")
	S.n.Popups.share:Hide()
	S.style = "Gamepad"; S.GP:Command("observe clear")
	S.style = "Mkb"; S.GP:Command("observe clear"); S.GP:Command("show")
	check(S.shareCalls == 2, "the slash commands work only with the keyboard-and-mouse style confirmed")
	S.n.Popups.share:Hide()
	-- the copy window must be closed before another observation
	S.GP:Command("show"); S.style = "Gamepad"
	BagSmith_Observer()
	check(S.GP.obs.state == "running" and S.n.Popups.share:IsShown(), "an open copy window (BagSmith's, opened through the API's copy helper) no longer blocks an observation: the companion does not read BagSmith's popups")
	BagSmith_Observer()
	S.n.Popups.share:Hide()
	cleanup()
	-- the native bag's parent is named exactly: BagSmith's own parking frame, the container, UIParent, or the frame's name
	S = boot({ parked = true })
	BagSmith_Observer()
	check(S.GP:ObsText():find("nativeCombinedParent=SomeHiddenParent", 1, true), "an unrelated parent is reported by name")
	BagSmith_Observer(); cleanup()
	S = boot()
	S.cb:SetParent(S.n.Hooks.parked); BagSmith_Observer()
	check(S.GP:ObsText():find("nativeCombinedParent=(unnamed)", 1, true) and not S.GP:ObsText():find("BagSmith-parked", 1, true), "the native bag's parent is reported by its frame name (BagSmith's parking frame is unnamed); the BagSmith-parked label, a private hook read, is retired")
	BagSmith_Observer(); cleanup()
	S = boot()
	S.cb:SetParent(UIParent); BagSmith_Observer()
	check(S.GP:ObsText():find("nativeCombinedParent=UIParent", 1, true), "UIParent is named, never called parked")
	BagSmith_Observer(); cleanup()
	-- the gamepad binding context is asked when the enum names it
	S = boot()
	_G.Enum.BindingContext = { GamepadModeInGameCore = 9 }
	_G.GetBindingAction = function(key, override, ctx) if ctx == 9 and key == "PAD1" then return "GAMEPAD_HUD_THING" end return "" end
	BagSmith_Observer()
	check(S.GP:ObsText():find("PAD1=-/-/GAMEPAD_HUD_THING PAD2=-/-/-", 1, true), "the third column reads the gamepad binding context")
	BagSmith_Observer(); _G.Enum.BindingContext = nil; cleanup()
	-- readback failures are unknown, never unbound; an absent API is said so
	S = boot({ getBindingAction = function() error("no") end })
	BagSmith_Observer()
	check(S.GP:ObsText():find("PAD1=unknown/unknown", 1, true), "a throwing GetBindingAction reads as unknown")
	BagSmith_Observer(); cleanup()
	S = boot(); _G.GetBindingAction = nil
	BagSmith_Observer()
	check(S.GP:ObsText():find("bindings (start): GetBindingAction absent", 1, true), "an absent GetBindingAction is reported as absent")
	BagSmith_Observer(); cleanup()
	-- the witness listeners are required; context listeners may be missing
	S = boot({ unknownEvents = { ADDON_ACTION_BLOCKED = true } })
	BagSmith_Observer()
	check(S.GP.obs.state == "idle" and S.events() == 0 and S.GP:ObsText():find("required monitoring unavailable (ADDON_ACTION_BLOCKED", 1, true), "a missing witness listener prevents the observation and leaves nothing registered")
	cleanup()
	S = boot({ unknownEvents = { BANKFRAME_OPENED = true } })
	BagSmith_Observer()
	check(S.GP.obs.state == "running" and S.events() == 10 and S.GP:ObsText():find("context events not registered: BANKFRAME_OPENED (register failed:", 1, true), "a missing context listener is logged and the observation still runs")
	BagSmith_Observer(); cleanup()
	-- logout stops a running observation
	S = boot()
	BagSmith_Observer(); S.M.fire("PLAYER_LOGOUT")
	check(S.GP.obs.state == "stopped" and S.events() == 0, "logout stops the observation")
	cleanup()
end)()

