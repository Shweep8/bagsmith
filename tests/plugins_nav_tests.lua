;(function()
	-- Probe C: the navigation prototype moves a highlight between the real item buttons while the bag window is open and eligible; four D-pad overrides, verified; nothing activated.
	local function forbid(name) return function() error("the prototype must not call " .. name) end end
	local function boot(opts)
		opts = opts or {}
		package.loaded.mock = nil
		local M = require("mock")
		local S = { M = M, style = "Gamepad", core = true, editFocus = nil, keysDown = {}, overrides = {}, clearCount = 0, setCount = 0 }
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
			if S.witnessInSet then local w = S.witnessInSet; S.witnessInSet = nil; M.fire(w, "BagSmith", "InsideSetOverrideBindingClick") end
		end
		_G.ClearOverrideBindings = function(owner) if S.combat then error("blocked in combat") end S.clearCount = S.clearCount + 1; for k, v in pairs(S.overrides) do if v.owner == owner then S.overrides[k] = nil end end end
		_G.GetBindingAction = function(key, override, ctx)
			if ctx == 9 then return ({ PADDUP = "GAMEPADACTIONBUTTON2", PADDDOWN = "GAMEPADACTIONBUTTON4", PADDLEFT = "GAMEPADACTIONBUTTON1", PADDRIGHT = "GAMEPADACTIONBUTTON3" })[key] or "" end
			if override and S.overrides[key] then return S.overrides[key].action end
			return ""
		end
		_G.IsKeyDown = function(key) return S.keysDown[key] and true or false end
		_G.InCombatLockdown = function() return S.combat and true or false end
		_G.GetCurrentKeyBoardFocus = function() return S.editFocus end
		_G.debugstack = function() return "stack line 1\nstack line 2" end
		_G.ContainerFrameCombinedBags = CreateFrame("Frame", "ContainerFrameCombinedBags", ContainerFrameContainer); ContainerFrameCombinedBags:Hide()
		_G.BagSmithGamepadDB = nil
		for s = 1, 6 do M.put(0, s, { id = 7000 + s, name = "Item" .. s, q = 1, count = 1, class = 0, subclass = 5, price = 1 }) end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
		local n = M.loadAddon("BagSmith")
		local gpns = dofile("tests/companion_loader.lua")(M, "BagSmith_Gamepad", "BagSmith_Gamepad")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("ADDON_LOADED", "BagSmith_Gamepad"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		S.n, S.GP, S.gpns = n, gpns.Gamepad, gpns
		S.GP.obsEvents.IsEventRegistered = function(self, e) return self.events[e] == true end
		-- a 3 by 2 grid of the six items: slot s at column (s-1)%3, row floor((s-1)/3); screen y grows upward
		S.item = {}
		for s = 1, 6 do
			local b = n.Buttons.byBag[0][s]; S.item[s] = b
			local col, row = (s - 1) % 3, math.floor((s - 1) / 3)
			b.GetCenter = function() return 100 + col * 40, 300 - row * 40 end
		end
		function S.ownerEvents() local f = S.GP.navOwner; if not f then return 0 end local c = 0; for _ in pairs(f.events) do c = c + 1 end return c end
		function S.press(dir) local b = S.GP.navButtons[dir]; b:GetScript("OnClick")(b, "LeftButton", true); b:GetScript("OnClick")(b, "LeftButton", false) end
		function S.quiet(k) for _ = 1, (k or 5) do M.elapse() end end
		function S.open() n.Window:Show(); M.runTimers(); M.runTimers() end
		function S.close() n.Window:Hide(); M.runTimers() end
		function S.enable() S.style = "Mkb"; S.GP:Command("nav on"); S.style = "Gamepad" end
		function S.focusSlot() local f = S.GP.nav and S.GP.nav.focus; for s = 1, 6 do if S.item[s] == f then return s end end return nil end
		function S.ours() local c = 0; for _, k in ipairs({ "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PAD2" }) do if S.overrides[k] then c = c + 1 end end return c end
		return S
	end
	local function cleanup()
		_G.BagSmithGamepadDB = nil
		_G.GamepadMode, _G.GamepadSharedUtility, _G.SmartNavigation, _G.InputUtil, _G.debugstack, _G.GetBindingAction, _G.IsKeyDown, _G.InCombatLockdown, _G.GetCurrentKeyBoardFocus, _G.ContainerFrameCombinedBags = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
		_G.SetOverrideBindingClick, _G.ClearOverrideBindings = nil, nil
		if _G.Enum then _G.Enum.BindingContext = nil end
	end

	-- arming: exclusive with the one-key probe; nothing bound while the window is closed
	local S = boot(); S.enable()
	BagSmith_Observer()
	check(S.GP.nav and S.GP.nav.state == "idle" and S.GP.probe == nil and S.GP:ObsText():find("probe: not armed: the navigation prototype is enabled instead", 1, true) and S.GP:ObsText():find("nav: armed on PADDUP PADDDOWN PADDLEFT PADDRIGHT", 1, true), "with nav enabled the prototype arms and the one-key probe does not")
	S.quiet(10)
	check(S.setCount == 0 and S.GP.nav.state == "idle", "with the bag window closed nothing is bound, however long the conditions hold")
	-- the window opens: bind after five clean samples, four overrides verified, the highlight on the first item
	S.open()
	S.quiet(4)
	check(S.setCount == 0, "four clean samples with the window open: not yet")
	S.quiet(1)
	check(S.GP.nav.state == "bound" and S.setCount == 5 and S.ours() == 5 and S.GP.nav.binds == 1 and S.ownerEvents() == 2 and S.GP:ObsText():find("nav: bound D-pad and back at t+", 1, true) and S.GP:ObsText():find("all five verified by readback", 1, true),
		"with the window open the four D-pad overrides and East bind on the fifth clean sample, all verified, both combat listeners registered")
	check(S.focusSlot() == 1 and S.GP.navHighlight:IsShown() and S.GP.navHighlight.points[1][2] == S.item[1] and S.GP.navHighlight:GetParent() ~= S.item[1] and S.GP:ObsText():find("nav: focus 0:1 Item1 (bound)", 1, true), "the highlight sits on the top-left item, anchored to it and not parented into BagSmith's frames")
	-- moves by geometry; blocked moves counted; the up edge does nothing
	S.press("right"); check(S.focusSlot() == 2, "right moves to the next item")
	S.press("right"); check(S.focusSlot() == 3, "and the next")
	S.press("right"); check(S.focusSlot() == 3 and S.GP.nav.blocked == 1 and S.GP:ObsText():find("nav: no item to the right", 1, true), "at the edge the move is blocked and counted")
	S.press("down"); check(S.focusSlot() == 6, "down moves to the item below")
	S.press("left"); check(S.focusSlot() == 5, "left")
	S.press("up"); check(S.focusSlot() == 2, "up")
	check(S.GP.nav.moves == 5 and S.GP.nav.ownedDown == 6 and S.GP.navHighlight.points[1][2] == S.item[2], "five moves, six owned presses, the highlight follows")
	-- nothing else happens on a press: no item action of any kind
	check(S.GP.nav.unexpected == 0 and S.GP.navHighlight.EnableMouse and true, "the highlight takes no input and presses only move it")
	-- a refresh that hides the focused item: the highlight moves to the nearest remaining item on the next sample
	S.item[2]:Hide(); S.quiet(1)
	check(S.focusSlot() ~= 2 and S.focusSlot() ~= nil and S.GP:ObsText():find("focused item gone, nearest", 1, true), "when the focused item disappears the highlight moves to the nearest item")
	S.item[2]:Show()
	-- a held D-pad key defers reacquisition; the window closing releases, verified, highlight hidden; reopening reacquires
	S.close(); S.quiet(1)
	check(S.GP.nav.state == "idle" and not S.GP.nav.installed and S.clearCount == 1 and S.ours() == 0 and not S.GP.navHighlight:IsShown() and S.GP:ObsText():find("nav: released (window closed) at t+", 1, true) and S.GP:ObsText():find("all five verified by readback", 1, true),
		"closing the window releases all five, verified, and hides the highlight")
	S.open(); S.keysDown.PADDDOWN = true; S.quiet(6)
	check(S.GP.nav.state == "idle" and S.setCount == 5, "a held D-pad key defers reacquisition")
	S.keysDown.PADDDOWN = nil; S.quiet(1)
	check(S.GP.nav.state == "bound" and S.GP.nav.binds == 2 and S.GP.navHighlight:IsShown(), "released: reacquired, the highlight back on the focused item")
	-- another window (the game menu) takes the pad: release; after it closes, reacquisition
	table.insert(S.mgr.shownFrames, S.mgr); S.core = false; S.quiet(1)
	check(S.GP.nav.state == "idle" and S.clearCount == 2 and S.GP:ObsText():find("nav: released (core false)", 1, true), "another window taking the pad releases the D-pad")
	S.mgr.shownFrames = {}; S.core = true; S.quiet(5)
	check(S.GP.nav.state == "bound" and S.GP.nav.binds == 3, "and it reacquires when the window is gone")
	-- entering combat: no binding call; the release is pending; presses are ignored; combat end releases and verifies
	S.combat = true; S.quiet(1)
	check(S.GP.nav.state == "pending" and S.ours() == 5 and S.clearCount == 2 and S.ownerEvents() == 2 and S.GP:ObsText():find("nav: release pending (combat): in combat and no secure combat driver is installed", 1, true) and S.GP:ObsText():find("the D-pad and East stay shadowed until combat ends", 1, true),
		"without the secure driver (diagnostics nav), combat makes the release pending: no binding call, the five overrides stay, the listeners stay")
	S.press("right")
	check(S.GP.nav.unexpected == 1 and S.GP.nav.moves == 5 and S.GP:ObsText():find("nav: right while pending: ignored", 1, true), "a press during the pending release is ignored and counted, not acted on")
	S.combat = false; S.M.fire("PLAYER_REGEN_ENABLED")
	check(S.GP.nav.state == "idle" and S.clearCount == 3 and S.ours() == 0 and S.ownerEvents() == 0, "at combat end the release runs and is verified")
	S.quiet(5)
	check(S.GP.nav.state == "bound" and S.GP.nav.binds == 4, "then it reacquires")
	-- the stop: release verified, the card and the saved report carry the nav summary
	BagSmith_Observer()
	check(S.GP.nav.state == "idle" and S.clearCount == 4 and S.ours() == 0 and not S.GP.navHighlight:IsShown() and S.GP.nav.noReacquire and S.GP:ObsText():find("nav: released (observer stop)", 1, true), "the stop releases, verified, and hides the highlight")
	check(S.GP.outcome.lines[6].text:find("^nav: D%-pad idle | binds 4 releases 4 pending 1 | moves 5 blocked 1 scrolls 0 | owned down 6 unexpected 1 | cleanup: released %(observer stop%), verified by readback"), "the card's sixth line is the nav summary")
	check((_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).probeSummary:find("^nav: D%-pad idle | binds 4 releases 4", 1, false) and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).probeCleanup:find("^released %(observer stop%), verified by readback"), "the saved report carries the nav summary and cleanup")
	cleanup()
	-- a witness during binding: never bound, cleaned up and verified, terminal
	for _, which in ipairs({ "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED" }) do
		S = boot(); S.enable(); BagSmith_Observer(); S.open(); S.witnessInSet = which
		S.quiet(5)
		check(S.GP.obs.state == "failed" and S.GP.nav.state == "idle" and not S.GP.nav.installed and S.GP.nav.binds == 0 and S.ours() == 0 and S.clearCount == 1 and not S.GP.navHighlight:IsShown() and S.GP.nav.cleanupStatus:find("^released %(failure%), verified by readback"),
			which .. " during the bind: never bound, all overrides cleaned up and verified, the failure latched")
		S.quiet(10); S.press("right"); BagSmith_Observer()
		check(S.GP.obs.state == "failed" and S.GP.nav.binds == 0 and S.GP.nav.moves == 0 and S.setCount <= 4, which .. ": nothing later binds or moves")
		cleanup()
	end
	-- a stop in combat leaves the release pending and blocks a new run and the nav commands until verified
	S = boot(); S.enable(); BagSmith_Observer(); S.open(); S.quiet(5)
	S.combat = true; BagSmith_Observer()
	check(S.GP.obs.state == "stopped" and S.GP.nav.state == "pending" and S.GP.nav.installed and S.ownerEvents() == 2 and S.GP.outcome.lines[6].text:find("pending (bindings may exist)", 1, true), "a stop in combat leaves the release pending; the card says so")
	BagSmith_Observer()
	check(S.GP.obs.state == "stopped" and S.GP:ObsText():find("not started: the previous probe's cleanup is pending", 1, true), "a new run is refused while the cleanup is pending")
	S.style = "Mkb"; S.GP:Command("nav off"); S.GP:Command("observe clear")
	check(S.GP.probeConfig.nav and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).lines, "nav commands and clear are refused while the cleanup is pending")
	S.style = "Gamepad"; S.combat = false; S.M.fire("PLAYER_REGEN_ENABLED")
	check(S.GP.nav.state == "idle" and not S.GP.nav.installed and S.ours() == 0 and (_G.BagSmithGamepadDB and _G.BagSmithGamepadDB.report).probeCleanup:find("^released %(observer stop%), verified"), "at combat end the pending release completes and the saved report records it")
	cleanup()
	-- scrolling: a focus change to an item outside the scroll window scrolls it into view through the view's tagged scroll, clamped; a surviving focus does not scroll; never in combat
	S = boot(); S.enable(); BagSmith_Observer(); S.open()
	local view = S.n.Window.main
	local sf = view.scroll
	-- the scroll window spans y 200..300 on screen; items are 24 px tall in a single column, 30 px apart: slots 1-3 wholly visible (bottoms at 272, 242, 212), 4-6 below the window
	sf.GetTop = function() return 300 end; sf.GetBottom = function() return 200 end; sf.h = 100
	view.contentHeight = 340   -- range 240
	local tagged = {}
	local origTagged = view.SetScrollTagged
	view.SetScrollTagged = function(self, value, tag) tagged[#tagged + 1] = { value = value, tag = tag }; return origTagged(self, value, tag) end
	local function place(s, cy) local b = S.item[s]; b.GetCenter = function() return 100, cy end; b.GetTop = function() return cy + 12 end; b.GetBottom = function() return cy - 12 end; b.h = 24 end
	for s = 1, 6 do place(s, 284 - (s - 1) * 30) end   -- centers 284, 254, 224 visible; 194, 164, 134 below
	S.quiet(5)
	check(S.GP.nav.state == "bound" and S.focusSlot() == 1 and #tagged == 0 and S.GP.nav.scrolls == 0, "the first item is in view: no scroll on the first focus")
	S.press("down"); S.press("down")
	check(S.focusSlot() == 3 and #tagged == 0, "moves inside the window do not scroll")
	S.press("down")
	check(S.focusSlot() == 4 and #tagged == 1 and tagged[1].tag == "plugin" and tagged[1].value == 42 and S.GP.nav.scrolls == 1 and S.GP:ObsText():find("nav: scrolled to keep Item4 in view", 1, true),
		"a move to an item below the window (bottom at 182, window bottom 200) scrolls down by the 18 px that hide it plus a one-row margin of 24, through the API's tagged scroll")
	-- the window has moved with the scroll: model it, then keep going down to the clamp
	for s = 1, 6 do place(s, 284 + 42 - (s - 1) * 30) end
	sf.verticalScroll = 42
	S.press("down"); S.press("down")
	check(S.focusSlot() == 6 and #tagged == 3 and tagged[3].value <= 240, "further moves keep scrolling and never exceed the range")
	-- a surviving focus after a refresh does not scroll, wherever the wheel put the list
	sf.verticalScroll = 0; for s = 1, 6 do place(s, 284 - (s - 1) * 30) end   -- the wheel scrolled back to the top: item 6 is off-screen again
	local before = #tagged
	S.quiet(2)
	check(S.focusSlot() == 6 and #tagged == before, "a surviving focused item is left where the wheel put the list: no scroll from the refresh path")
	-- a refresh that hides the focused item: the nearest remaining item is an actual focus change and is scrolled into view
	S.item[6]:Hide(); S.quiet(1)
	check(S.focusSlot() == 5 and #tagged == before + 1 and S.GP:ObsText():find("to keep Item5 in view", 1, true), "when the focused item disappears, the nearest remaining item is focused and scrolled into view")
	S.item[6]:Show()
	-- clamp at the top: an item above the window
	sf.verticalScroll = 200; for s = 1, 6 do place(s, 284 + 200 - (s - 1) * 30) end   -- items 1-3 are now above the window
	S.press("up"); S.press("up"); S.press("up"); S.press("up")
	check(S.focusSlot() == 1 and tagged[#tagged].value >= 0 and tagged[#tagged].tag == "plugin", "moving up to an item above the window scrolls up, clamped at zero")
	-- finding 1: a rebuild's deferred restore does not undo a newer gamepad scroll
	sf.verticalScroll = 0; for s = 1, 6 do place(s, 284 - (s - 1) * 30) end
	S.GP.nav.focus = S.item[1]; S.GP.nav.focusKey = 1; S.GP:NavRefreshFocusCenter()
	view:RestoreScroll(0, 340, 100)          -- a rebuild restores 0 now and again on the next frame
	S.press("down"); S.press("down"); S.press("down")   -- the D-pad scrolls to show item 4 before that next frame
	local gamepadValue = sf:GetVerticalScroll()
	check(S.focusSlot() == 4 and gamepadValue == 42, "(setup) the gamepad scrolled to 42 after the rebuild's first restore")
	S.M.runTimers()                          -- the rebuild's deferred restore runs now
	check(sf:GetVerticalScroll() == 42, "the rebuild's deferred restore steps aside for the newer gamepad scroll (stamped as a scroll by the player)")
	view:RestoreScroll(42, 340, 100); S.M.runTimers()
	check(sf:GetVerticalScroll() == 42, "a later rebuild keeps the position the gamepad left (it became the trusted position)")
	-- finding 2: replacing a vanished focused item mid-move uses the replacement's current center, after its scroll, for the rest of that move
	sf.verticalScroll = 0; for s = 1, 6 do place(s, 284 - (s - 1) * 30) end
	place(3, 214)                              -- the focused item sits nearer to item 4 (20 px) than to item 2 (40 px)
	S.GP.nav.focus = S.item[3]; S.GP.nav.focusKey = 3; S.GP:NavRefreshFocusCenter()
	local function shifted(value) place(1, 284 + value); place(2, 254 + value); place(3, 214 + value); place(4, 194 + value); place(5, 164 + value); place(6, 134 + value) end
	view.SetScrollTagged = function(self, value, tag)   -- the list moves when scrolled: items shift with the scrolled amount
		tagged[#tagged + 1] = { value = value, tag = tag }
		origTagged(self, value, tag)
		shifted(value)
	end
	S.item[3]:Hide()                           -- the focused item vanishes; the nearest remaining is item 4, below the window
	S.press("down")
	-- with a stale center (194, before the 42 px scroll) "down" would have picked item 6; from item 4's current center (236) it is item 5
	check(S.focusSlot() == 5 and S.GP:ObsText():find("focus 0:4 Item4 (focused item gone, nearest)", 1, true) and S.GP:ObsText():find("focus 0:5 Item5 (down)", 1, true),
		"mid-move, the vanished focus is replaced by item 4, scrolled into view, and the move continues from item 4's current position to item 5")
	check(S.GP.nav.focusY == select(2, S.item[5]:GetCenter()), "the recorded focus center is the current one after the scroll")
	S.item[3]:Show()
	view.SetScrollTagged = function(self, value, tag) tagged[#tagged + 1] = { value = value, tag = tag }; return origTagged(self, value, tag) end
	-- in combat: no scroll change, the focus still moves
	S.combat = true; S.quiet(1)   -- (combat makes the release pending; presses are ignored, so scrolling cannot be reached by a press)
	local tag0 = #tagged
	local cand6; for _, c in ipairs(S.GP:NavCandidates()) do if c.b == S.item[6] then cand6 = c end end
	S.GP:NavEnsureVisible(cand6)
	check(#tagged == tag0 and S.GP:ObsText():find("nav: not scrolling: in combat", 1, true), "in combat the scroll position is never changed (the API refuses with the combat code)")
	S.combat = false; S.M.fire("PLAYER_REGEN_ENABLED")
	BagSmith_Observer(); cleanup()
	-- mouse and keyboard untouched: the prototype installs no hook and no script on BagSmith's own frames or buttons
	S = boot(); S.enable(); BagSmith_Observer(); S.open(); S.quiet(5)
	check(S.M.hooks["FrameShown"] == nil and S.item[1].scripts.OnClick and S.GP.navHighlight ~= nil and S.GP.navHighlight ~= S.item[1], "item buttons keep their own OnClick; the highlight is a separate frame; no native hook")
	BagSmith_Observer(); cleanup()
end)()

