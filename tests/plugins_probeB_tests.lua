;(function()
	-- Probe B: one key, one logging target; arms only with a verified key, binds only on key-up after quiet samples, releases on conflict/cap/stop/failure, verifies by readback, never reacquires after stop/cap/failure.
	local function forbid(name) return function() error("Probe B must not call " .. name) end end
	local function boot(opts)
		opts = opts or {}
		package.loaded.mock = nil
		local M = require("mock")
		local S = { M = M, style = "Gamepad", core = true, editFocus = nil, keyDown = false, ctxAction = "", ctxKnown = true, overrides = {}, clearCount = 0, setCount = 0 }
		local mgr = { shownFrames = {}, focusedFrame = nil, isUIFocused = false, fallThroughCatcherActive = false, FrameShown = forbid("FrameShown"), FrameHidden = forbid("FrameHidden") }
		S.mgr = mgr
		_G.GamepadMode = { FrameControlsManager = mgr }
		_G.GamepadSharedUtility = { InputBindingManager = { IsOnlyCoreBindingSetActive = function() return S.core end } }
		_G.SmartNavigation = setmetatable({}, { __index = function(_, k) return forbid("SmartNavigation." .. tostring(k)) end })
		_G.InputUtil = { IsGamepadUISupported = function() return true end, IsGamepadUIEnabled = function() return S.style == "Gamepad" end, IsMKBUIEnabled = function() return S.style == "Mkb" end }
		_G.Enum = _G.Enum or {}; _G.Enum.BindingContext = { GamepadModeInGameCore = 9 }
		-- the binding system, as the test's own model: override bindings per owner; readback names the override, else the context action
		_G.SetOverrideBindingClick = function(owner, priority, key, button, mouse)
			if S.combat then error("blocked in combat") end
			S.setCount = S.setCount + 1; S.overrides[key] = { owner = owner, action = "CLICK " .. button .. ":" .. (mouse or "LeftButton") }
			if S.witnessInSet then local w = S.witnessInSet; S.witnessInSet = nil; M.fire(w, "BagSmith", "InsideSetOverrideBindingClick") end
		end
		_G.ClearOverrideBindings = function(owner)
			if S.combat then error("blocked in combat") end
			if S.failClear then return end
			S.clearCount = S.clearCount + 1
			for k, v in pairs(S.overrides) do if v.owner == owner then S.overrides[k] = nil end end
		end
		_G.GetBindingAction = function(key, override, ctx)
			if ctx == 9 then if not S.ctxKnown then error("no context") end return S.ctxAction end
			if S.readbackReturns ~= nil then local v = S.readbackReturns; if v == "throw" then error("readback broke") end return v end
			if override and S.overrides[key] then
				local action = S.overrides[key].action
				if S.witnessInReadback then
					local w = S.witnessInReadback; S.witnessInReadback = nil
					if S.combatAtWitness then S.combat = true end
					M.fire(w, "BagSmith", "InsideVerificationReadback")
				end
				if S.readbackHides then return "" end
				return action
			end
			return ""
		end
		_G.IsKeyDown = function(key) if S.keyDownUnavailable then error("no") end return S.keyDown end
		_G.InCombatLockdown = function() return S.combat and true or false end
		_G.GetCurrentKeyBoardFocus = function() return S.editFocus end
		_G.debugstack = function() return "stack line 1\nstack line 2" end
		_G.ContainerFrameCombinedBags = CreateFrame("Frame", "ContainerFrameCombinedBags", ContainerFrameContainer); ContainerFrameCombinedBags:Hide()
		if not opts.keepReport then _G.BagSmithGamepadDB = nil end
		M.put(0, 1, { id = 7001, name = "Water", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
		local n = M.loadAddon("BagSmith")
		local gpns = dofile("tests/companion_loader.lua")(M, "BagSmith_Gamepad", "BagSmith_Gamepad")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("ADDON_LOADED", "BagSmith_Gamepad"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		S.n, S.GP, S.gpns = n, gpns.Gamepad, gpns
		S.GP.obsEvents.IsEventRegistered = function(self, e) return self.events[e] == true end
		function S.ownerEvents() local f = S.GP.probeOwner; if not f then return 0 end local c = 0; for _ in pairs(f.events) do c = c + 1 end return c end
		function S.press() local b = S.GP.probeButton; b:GetScript("OnClick")(b, "LeftButton", true); b:GetScript("OnClick")(b, "LeftButton", false) end
		function S.setup(key, confirm) S.style = "Mkb"; S.GP:Command("probekey " .. key); if confirm then S.GP:Command("probekey confirm") end; S.GP:Command("probe on"); S.style = "Gamepad" end
		function S.quiet(n) for _ = 1, (n or 5) do M.elapse() end end
		return S
	end
	local function cleanup()
		_G.BagSmithGamepadDB = nil
		_G.GamepadMode, _G.GamepadSharedUtility, _G.SmartNavigation, _G.InputUtil, _G.debugstack, _G.GetBindingAction, _G.IsKeyDown, _G.InCombatLockdown, _G.GetCurrentKeyBoardFocus, _G.ContainerFrameCombinedBags = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
		_G.SetOverrideBindingClick, _G.ClearOverrideBindings = nil, nil
		if _G.Enum then _G.Enum.BindingContext = nil end
	end

	-- a verified suitable key is required, else the probe does not arm
	local S = boot()
	S.style = "Mkb"
	S.GP:Command("probekey PAD1")
	check(S.GP.probeConfig == nil and S.M.log[#S.M.log]:find("is not allowed", 1, true), "a face button is refused as a probe key")
	S.GP:Command("probekey PADLSTICK")
	check(S.GP.probeConfig and S.GP.probeConfig.key == "PADLSTICK" and not S.GP.probeConfig.confirmed and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).config.key == "PADLSTICK", "an allowed key is set and kept in the saved configuration")
	S.GP:Command("probe on"); S.style = "Gamepad"
	S.ctxKnown = false
	BagSmith_Observer()
	check(S.GP.obs.state == "running" and S.GP.probe == nil and S.GP:ObsText():find("probe: not armed: readback unavailable and the key is not confirmed", 1, true) and S.setCount == 0, "with the readback unavailable and no confirmation the observer runs but the probe does not arm")
	BagSmith_Observer(); cleanup()
	S = boot(); S.setup("PADLSTICK"); S.ctxAction = "OPENRADIAL"
	BagSmith_Observer()
	check(S.GP.probe == nil and S.GP:ObsText():find("key carries excluded HUD action OPENRADIAL", 1, true) and S.setCount == 0, "a key carrying an excluded HUD action does not arm")
	BagSmith_Observer(); cleanup()
	S = boot(); S.setup("PADLSTICK"); S.ctxKnown = false; S.style = "Mkb"; S.GP:Command("probekey confirm"); S.style = "Gamepad"
	BagSmith_Observer()
	check(S.GP.probe and S.GP.probe.state == "idle" and S.GP:ObsText():find("probe: armed with PADLSTICK (confirmed by you from the Keybindings screen (readback unavailable))", 1, true), "your confirmation from the Keybindings screen verifies the key when the readback is unavailable")
	BagSmith_Observer(); cleanup()
	-- 1. bind only after quiet samples and on key-up; deliver; verified by readback; release at stop
	S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
	BagSmith_Observer()
	check(S.GP.probe.state == "idle" and S.setCount == 0, "armed but not bound at the start")
	S.quiet(4)
	check(S.setCount == 0, "four quiet samples: not yet")
	S.keyDown = true; S.quiet(1)
	check(S.setCount == 0 and S.GP.probe.state == "idle", "the fifth quiet sample with the key held: deferred, no bind")
	S.keyDown = false; S.quiet(1)
	check(S.setCount == 1 and S.GP.probe.state == "bound" and S.GP.probe.binds == 1 and S.ownerEvents() == 1 and S.GP:ObsText():find("probe: bound PADLSTICK at t+", 1, true) and S.GP:ObsText():find("(readback CLICK BagSmithProbeKeyButton:LeftButton)", 1, true), "bound on the first quiet sample with the key up, verified by readback, combat-end listener registered")
	S.press()
	check(S.GP.probe.ownedDown == 1 and S.GP.probe.ownedUp == 1 and S.GP:ObsText():find("probe: owned down (PADLSTICK)", 1, true) and S.GP:ObsText():find("probe: owned up (PADLSTICK)", 1, true), "a press is logged as owned down and owned up, only as observed")
	local b = S.GP.probeButton
	b:GetScript("OnClick")(b, "LeftButton", false)
	check(S.GP.probe.ignoredUp == 1 and S.GP:ObsText():find("up without an owned down: ignored", 1, true), "an up edge without an owned down is ignored")
	BagSmith_Observer()
	check(S.GP.probe.state == "idle" and S.clearCount == 1 and S.overrides.PADLSTICK == nil and S.ownerEvents() == 0 and S.GP.probe.noReacquire and S.GP:ObsText():find("probe: released (observer stop) at t+", 1, true) and S.GP:ObsText():find("verified by readback (unbound)", 1, true),
		"the observer's stop releases the binding, verified by readback, listener gone, no reacquisition")
	check(S.GP.outcome.lines[6].text:find("^probe: PADLSTICK idle | binds 1 releases 1 pending 0 | owned down 1 up 1 | ignored up 1 unexpected 0"), "the card's probe line reports the counts")
	check((_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).probeSummary:find("binds 1 releases 1", 1, true) and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).config.key == "PADLSTICK", "the saved report carries the probe summary and the configuration")
	cleanup()
	-- 2. conflict (a native frame registers): release on the first sample; reacquisition after 5 clean samples with the key up; a held key defers
	S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
	BagSmith_Observer(); S.quiet(5)
	check(S.GP.probe.state == "bound", "(setup) bound")
	table.insert(S.mgr.shownFrames, S.mgr); S.core = false; S.quiet(1)
	check(S.GP.probe.state == "idle" and S.clearCount == 1 and S.GP:ObsText():find("probe: released (core false)", 1, true), "a native frame taking the pad releases the binding on the next sample, verified")
	S.mgr.shownFrames = {}; S.core = true
	S.keyDown = true; S.quiet(6)
	check(S.GP.probe.state == "idle" and S.setCount == 1, "clean again but the key held: no reacquisition")
	S.keyDown = false; S.quiet(1)
	check(S.GP.probe.state == "bound" and S.setCount == 2 and S.GP.probe.binds == 2 and S.GP:ObsText():find("(reacquired)", 1, true), "released key: reacquired after the quiet period")
	S.editFocus = CreateFrame("EditBox", "BagSmithFrameSearch"); S.quiet(1)
	check(S.GP.probe.state == "idle" and S.GP:ObsText():find("released (edit focus BagSmithFrameSearch)", 1, true), "text focus releases")
	S.editFocus = nil; S.quiet(5)
	check(S.GP.probe.state == "bound" and S.GP.probe.binds == 3, "and it reacquires after focus is lost and the quiet period")
	BagSmith_Observer(); cleanup()
	-- 3. a conflict while bound in combat: the release is pending, the binding stays, the listener stays, then it runs at combat end
	S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
	BagSmith_Observer(); S.quiet(5)
	S.combat = true; S.quiet(1)
	check(S.GP.probe.state == "pending" and S.GP.probe.pending == 1 and S.overrides.PADLSTICK and S.clearCount == 0 and S.ownerEvents() == 1 and S.GP:ObsText():find("probe: release pending (combat) at t+", 1, true) and S.GP:ObsText():find("the binding stays until combat ends and the release is verified", 1, true),
		"combat makes the release pending: the binding stays, the listener stays, nothing is reported released")
	S.quiet(3)
	check(S.GP.probe.state == "pending" and S.clearCount == 0, "it stays pending while combat lasts")
	S.combat = false; S.M.fire("PLAYER_REGEN_ENABLED")
	check(S.GP.probe.state == "idle" and S.clearCount == 1 and S.overrides.PADLSTICK == nil and S.ownerEvents() == 0 and S.GP:ObsText():find("probe: released (combat) at t+", 1, true), "at combat end the pending release runs and is verified; the listener goes")
	S.quiet(5)
	check(S.GP.probe.state == "bound" and S.GP.probe.binds == 2, "then it reacquires")
	BagSmith_Observer(); cleanup()
	-- 4. the cap: release at 60 s, no reacquisition; in combat the cap leaves the binding pending beyond the cap
	S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
	BagSmith_Observer(); S.quiet(5)
	S.M.gameTime = S.M.gameTime + 61; S.quiet(1)
	check(S.GP.probe.state == "idle" and S.GP.probe.noReacquire and S.GP:ObsText():find("released (cap)", 1, true), "at the cap the binding is released and reacquisition is off")
	S.quiet(10)
	check(S.setCount == 1 and S.GP.probe.binds == 1, "no reacquisition after the cap")
	BagSmith_Observer(); cleanup()
	S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
	BagSmith_Observer(); S.quiet(5)
	S.combat = true; S.M.gameTime = S.M.gameTime + 61; S.quiet(1)
	check(S.GP.probe.state == "pending" and S.overrides.PADLSTICK and S.GP:ObsText():find("release pending (combat)", 1, true), "the cap in combat: pending, the binding remains beyond the cap")
	BagSmith_Observer()
	check(S.GP.obs.state == "stopped" and S.GP.probe.state == "pending" and S.ownerEvents() == 1 and S.GP:ObsText():find("probe: ended (observer stop): PADLSTICK pending", 1, true) and S.GP.outcome.lines[6].text:find("PADLSTICK pending", 1, true),
		"stopping the observer in combat leaves the release pending and reports it so; the combat-end listener stays")
	S.combat = false; S.M.fire("PLAYER_REGEN_ENABLED")
	check(S.GP.probe.state == "idle" and S.clearCount == 1 and S.ownerEvents() == 0, "the pending release runs at combat end even after the observer stopped")
	cleanup()
	-- 5. a release that cannot be verified stays pending
	S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
	BagSmith_Observer(); S.quiet(5)
	S.failClear = true
	BagSmith_Observer()
	check(S.GP.probe.state == "pending" and S.ownerEvents() == 1 and S.GP:ObsText():find("release (observer stop) NOT verified: readback still names the button; still pending, listener kept", 1, true), "a clear that the readback does not confirm is never reported as released")
	cleanup()
	-- 6. a failure while bound: no reacquisition; cleanup with one readback, reported honestly
	S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
	BagSmith_Observer(); S.quiet(5)
	S.M.fire("ADDON_ACTION_FORBIDDEN", "BagSmith", "SomeProtectedFunction")
	check(S.GP.obs.state == "failed" and S.GP.probe.noReacquire and S.GP.probe.state == "idle" and S.clearCount == 1 and S.overrides.PADLSTICK == nil and S.GP:ObsText():find("probe: released (failure) at t+", 1, true) and S.GP:ObsText():find("probe: ended (failure)", 1, true),
		"a latched failure releases the probe's own binding, verified, and ends it")
	S.quiet(5)
	check(S.setCount == 1, "no reacquisition after a failure")
	check((_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).probeSummary:find("binds 1 releases 1", 1, true), "the saved failure report carries the probe's outcome")
	cleanup()
	-- 7. a failure in combat: the probe's release stays pending with its listener; the observer is otherwise frozen
	S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
	BagSmith_Observer(); S.quiet(5)
	S.combat = true
	S.M.fire("ADDON_ACTION_BLOCKED", "BagSmith", "SomeProtectedFunction")
	check(S.GP.obs.state == "failed" and S.GP.probe.state == "pending" and S.ownerEvents() == 1 and S.overrides.PADLSTICK, "a failure in combat leaves the probe's release pending with its listener")
	S.combat = false; S.M.fire("PLAYER_REGEN_ENABLED")
	check(S.GP.probe.state == "idle" and S.overrides.PADLSTICK == nil and S.ownerEvents() == 0, "and it completes at combat end")
	cleanup()
	-- 8. the key configuration survives a reload and a clear; the probe never arms when disabled
	S = boot(); S.setup("PADLSTICK", true)
	BagSmith_Observer(); S.quiet(2); BagSmith_Observer()
	local saved = (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report)
	S.style = "Mkb"; S.GP:Command("observe clear")
	check((_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report) and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).lines == nil and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).config.key == "PADLSTICK" and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).config.confirmed, "clearing the report keeps the key configuration")
	cleanup(); _G.BagSmithGamepadDB = { version = 1, report = { version = 1, config = { key = "PADRSHOULDER", confirmed = true, enabled = false, version = 1 } } }
	S = boot({ keepReport = true })
	check(S.GP.probeConfig and S.GP.probeConfig.key == "PADRSHOULDER" and S.GP.obs.restored == nil, "a configuration-only saved table is restored as configuration, not as a report")
	BagSmith_Observer()
	check(S.GP.probe == nil and S.GP:ObsText():find("probe: not enabled for this observation", 1, true), "disabled: the observer runs without the probe")
	BagSmith_Observer(); cleanup()
	-- 9. the slash commands work only in the keyboard-and-mouse style and never during an observation
	S = boot()
	S.GP:Command("probekey PADLSTICK")
	check(S.GP.probeConfig == nil and S.GP:ObsText():find("probe: slash command refused: style Gamepad", 1, true), "probe commands are refused in the Gamepad style")
	S.setup("PADLSTICK"); BagSmith_Observer()
	S.style = "Mkb"; S.GP:Command("probe off"); S.style = "Gamepad"
	check(S.GP.probeConfig.enabled and S.M.log[#S.M.log]:find("not while an observation is running", 1, true), "and refused during an observation")
	BagSmith_Observer(); cleanup()
	-- A. failed readback after installation: the binding is tracked as installed and cleared anyway, verified
	S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
	BagSmith_Observer(); S.readbackHides = true
	S.quiet(5)
	check(S.setCount == 1 and S.clearCount == 1 and S.overrides.PADLSTICK == nil and S.GP.probe.state == "idle" and not S.GP.probe.installed and S.GP.probe.noReacquire
		and S.GP:ObsText():find("bind not confirmed by readback", 1, true) and S.GP:ObsText():find("released (unconfirmed bind)", 1, true),
		"a bind the readback does not confirm is still cleared (the binding was installed) and verified; no reacquisition")
	S.quiet(10)
	check(S.setCount == 1, "and it never binds again")
	S.readbackHides = false; BagSmith_Observer(); cleanup()
	-- B. a restart while a previous probe's cleanup is pending in combat is blocked until the cleanup is verified
	S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
	BagSmith_Observer(); S.quiet(5)
	S.combat = true; BagSmith_Observer()
	check(S.GP.obs.state == "stopped" and S.GP.probe.state == "pending" and S.GP.probe.installed and S.ownerEvents() == 1, "(setup) stopped with the release pending in combat")
	local probeBefore = S.GP.probe
	BagSmith_Observer()
	check(S.GP.obs.state == "stopped" and S.GP.probe == probeBefore and S.GP.probe.installed and S.GP:ObsText():find("not started: the previous probe's cleanup is pending", 1, true), "a new observation is refused while the previous probe's cleanup is pending; the pending probe is kept")
	S.combat = false; S.M.fire("PLAYER_REGEN_ENABLED")
	check(not S.GP.probe.installed and S.GP.probe.state == "idle" and S.overrides.PADLSTICK == nil, "combat ends: the pending release runs and is verified")
	BagSmith_Observer()
	check(S.GP.obs.state == "running" and S.GP.probe ~= probeBefore and S.GP.probe.state == "idle", "then a new observation may start with a fresh probe")
	BagSmith_Observer(); cleanup()
	-- C. configuration and verification changes are refused while cleanup is pending
	S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
	BagSmith_Observer(); S.quiet(5)
	S.combat = true; BagSmith_Observer()
	S.style = "Mkb"
	S.GP:Command("probekey off"); S.GP:Command("probekey PADRSHOULDER"); S.GP:Command("probekey confirm"); S.GP:Command("probe off")
	check(S.GP.probeConfig and S.GP.probeConfig.key == "PADLSTICK" and S.GP.probeConfig.enabled and not S.GP.probeConfig.confirmed and S.M.log[#S.M.log]:find("not while the previous probe's cleanup is pending", 1, true),
		"probe configuration cannot change while cleanup is pending")
	S.style = "Gamepad"; S.combat = false; S.M.fire("PLAYER_REGEN_ENABLED")
	S.style = "Mkb"; S.GP:Command("probe off")
	check(not S.GP.probeConfig.enabled, "once the cleanup is verified, configuration changes again")
	cleanup()
	-- D. saved report and card agree with the eventual cleanup, through reload and export
	S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
	BagSmith_Observer(); S.quiet(5)
	S.combat = true; BagSmith_Observer()
	check((_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).probeCleanup:find("^pending %(observer stop%): in combat") and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).probeSummary:find("pending (binding may exist)", 1, true) and S.GP.outcome.lines[6].text:find("pending (binding may exist)", 1, true),
		"after a stop with the release pending, the saved report and the card both say pending")
	S.combat = false; S.M.fire("PLAYER_REGEN_ENABLED")
	check((_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).probeCleanup:find("^released %(observer stop%), verified by readback") and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).probeSummary:find("PADLSTICK idle |", 1, true) and S.GP.outcome.lines[6].text:find("cleanup: released (observer stop), verified by readback", 1, true),
		"when the cleanup completes after the stop, the saved report and the card are updated to released and verified")
	S.style = "Mkb"; S.GP:Command("show")
	check(S.n.Popups.share.locked:find("== Probe cleanup (kept apart from the observer's log, which may be frozen) ==", 1, true) and S.n.Popups.share.locked:find("released (observer stop), verified by readback", 1, true), "the export shows the cleanup status")
	S.n.Popups.share:Hide()
	local savedReport = (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report)
	cleanup(); _G.BagSmithGamepadDB = { version = 1, report = savedReport }
	S = boot({ keepReport = true })
	check(S.GP.obs.restored and S.GP.obs.restored.probeCleanup:find("^released %(observer stop%), verified by readback") and S.GP.outcome.lines[6].text:find("PADLSTICK idle", 1, true), "after a reload the restored report and card carry the cleanup status")
	cleanup()
	-- E. a witness during binding: the failed state is latched, the binding is cleaned up, and nothing later overwrites it
	for _, which in ipairs({ "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do
		S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
		BagSmith_Observer(); S.witnessInSet = which
		S.quiet(5)
		check(S.GP.obs.state == "failed" and S.GP.obsFailure == which .. " InsideSetOverrideBindingClick (by BagSmith)" and S.GP.probe.state == "idle" and not S.GP.probe.installed and S.GP.probe.binds == 0 and S.clearCount == 1 and S.overrides.PADLSTICK == nil and S.GP.probe.noReacquire
			and not S.GP:ObsText():find("probe: bound", 1, true) and S.GP.probe.cleanupStatus:find("^released %(failure%), verified by readback"),
			which .. " inside the bind call: never reported bound, the binding cleaned up by the failure path and verified (the status lives outside the frozen log), the failure latched")
		S.quiet(10); S.M.fire("PLAYER_REGEN_ENABLED"); BagSmith_Observer()
		check(S.GP.obs.state == "failed" and S.GP.obsFailure == which .. " InsideSetOverrideBindingClick (by BagSmith)" and S.setCount == 1 and S.GP.probe.binds == 0, which .. ": later ticks, events and the key do not overwrite the failed state or bind again")
		check((_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).state == "failed" and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).probeCleanup:find("^released %(failure%), verified"), which .. ": the saved failure report carries the cleanup result")
		cleanup()
	end
	-- F. a witness inside the verification readback: never bound, no counter, immediate cleanup verified
	for _, which in ipairs({ "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do
		S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
		BagSmith_Observer(); S.witnessInReadback = which
		S.quiet(5)
		check(S.GP.obs.state == "failed" and S.GP.obsFailure == which .. " InsideVerificationReadback (by BagSmith)" and S.GP.probe.state == "idle" and not S.GP.probe.installed and S.GP.probe.binds == 0 and S.clearCount == 1 and S.overrides.PADLSTICK == nil
			and not S.GP:ObsText():find("probe: bound", 1, true) and S.GP.probe.cleanupStatus:find("^released %(failure%), verified by readback"),
			which .. " inside the verification readback: never bound, no bind counted, cleaned up by the failure path and verified")
		S.quiet(10); S.M.fire("PLAYER_REGEN_ENABLED"); BagSmith_Observer()
		check(S.GP.obs.state == "failed" and S.GP.probe.binds == 0 and S.setCount == 1 and S.GP.probe.state == "idle", which .. ": nothing later binds or counts")
		cleanup()
		-- the same, with combat beginning at that moment: cleanup deferred, still never bound, verified at combat end
		S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
		BagSmith_Observer(); S.witnessInReadback = which; S.combatAtWitness = true
		S.quiet(5)
		check(S.GP.obs.state == "failed" and S.GP.probe.state == "pending" and S.GP.probe.installed and S.GP.probe.binds == 0 and S.clearCount == 0 and S.overrides.PADLSTICK and S.ownerEvents() == 1
			and not S.GP:ObsText():find("probe: bound", 1, true) and S.GP.probe.cleanupStatus:find("^pending %(failure%): in combat"),
			which .. " inside the verification readback with combat beginning: never bound, the cleanup pending with its listener")
		S.quiet(5); BagSmith_Observer()
		check(S.GP.probe.state == "pending" and S.GP.probe.binds == 0 and S.setCount == 1, which .. ": while pending, nothing binds or counts")
		S.combat = false; S.M.fire("PLAYER_REGEN_ENABLED")
		check(S.GP.probe.state == "idle" and not S.GP.probe.installed and S.clearCount == 1 and S.overrides.PADLSTICK == nil and S.GP.probe.binds == 0 and S.GP.probe.cleanupStatus:find("^released %(failure%), verified by readback")
			and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).probeCleanup:find("^released %(failure%), verified by readback"),
			which .. ": at combat end the release is verified and the saved failure report records it")
		cleanup()
	end
	-- G. an invalid or throwing readback never verifies a release; a later valid readback does
	for _, bad in ipairs({ false, 7, "throw" }) do
		S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
		BagSmith_Observer(); S.quiet(5)
		check(S.GP.probe.state == "bound", "(setup) bound")
		S.readbackReturns = bad
		BagSmith_Observer()
		check(S.GP.probe.state == "pending" and S.GP.probe.installed and S.ownerEvents() == 1 and S.GP.probe.releases == 0 and S.GP:ObsText():find("NOT verified: " .. (bad == "throw" and "readback failed" or ("readback invalid (" .. type(bad) .. ")")), 1, true),
			"a " .. (bad == "throw" and "throwing" or type(bad)) .. " readback keeps the release pending")
		S.readbackReturns = nil
		S.M.fire("PLAYER_REGEN_ENABLED")   -- the retry path
		check(S.GP.probe.state == "idle" and not S.GP.probe.installed and S.GP.probe.releases == 1 and S.GP.probe.cleanupStatus:find("^released", 1, false), "a valid readback later verifies it")
		cleanup()
	end
	-- H. observe clear is refused while cleanup is pending; the saved report keeps the result; restore after a failed observation is consistent
	S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
	BagSmith_Observer(); S.quiet(5)
	S.combat = true; S.M.fire("ADDON_ACTION_FORBIDDEN", "BagSmith", "SomeProtectedFunction")
	check(S.GP.obs.state == "failed" and S.GP.probe.state == "pending", "(setup) failed with the cleanup pending in combat")
	S.style = "Mkb"; S.GP:Command("observe clear")
	check((_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report) and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).state == "failed" and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).probeCleanup:find("^pending %(failure%)") and S.M.log[#S.M.log]:find("not while the probe's cleanup is pending", 1, true), "observe clear is refused while cleanup is pending; the saved report stays")
	S.combat = false; S.M.fire("PLAYER_REGEN_ENABLED")
	check((_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).probeCleanup:find("^released %(failure%), verified by readback") and S.GP.outcome.lines[6].text:find("cleanup: released (failure), verified by readback", 1, true), "when the cleanup completes the saved failure report and the card record it")
	local savedFailed = (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report)
	cleanup(); _G.BagSmithGamepadDB = { version = 1, report = savedFailed }
	S = boot({ keepReport = true })
	check(S.GP.obs.restored.state == "failed" and S.GP.obs.restored.probeCleanup:find("^released %(failure%), verified") and S.GP.outcome.lines[6].text:find("cleanup: released (failure), verified", 1, true) and S.GP.outcome.lines[3].text == "first failure: ADDON_ACTION_FORBIDDEN SomeProtectedFunction (by BagSmith)",
		"after a reload the restored failure report, its cleanup result and the card agree")
	S.style = "Mkb"; S.GP:Command("show")
	check(S.n.Popups.share.locked:find("== Probe cleanup (from the saved report) ==", 1, true) and S.n.Popups.share.locked:find("released (failure), verified by readback", 1, true), "and the export shows the cleanup result")
	S.n.Popups.share:Hide(); cleanup()
	-- a reload while a cleanup is still pending: the restored record says so honestly
	S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"
	BagSmith_Observer(); S.quiet(5)
	S.combat = true; BagSmith_Observer()
	local savedPending = (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report)
	cleanup(); _G.BagSmithGamepadDB = { version = 1, report = savedPending }
	S = boot({ keepReport = true })
	check(S.GP.obs.restored.probeCleanup:find("^pending %(observer stop%)") and S.GP.obs.restored.probeCleanup:find("the release was never verified in%-game"), "a reload before the release was verified is recorded as never verified, not as released")
	cleanup()
	-- F. a witness during binding in combat... the set call is blocked in combat, so the probe never binds there; a failure while bound in combat is case 7 above
	-- key-up unverifiable: never binds
	S = boot(); S.setup("PADLSTICK"); S.ctxAction = "GAMEPADACTIONBUTTON7"; S.keyDownUnavailable = true
	BagSmith_Observer(); S.quiet(6)
	check(S.setCount == 0 and S.GP.probe.noReacquire and S.GP:ObsText():find("key-up cannot be verified", 1, true), "when key-up cannot be verified the probe does not bind")
	BagSmith_Observer(); cleanup()
end)()

