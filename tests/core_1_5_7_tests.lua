;(function()
	-- 1.5.7: the 1.5.6-beta2 audit's findings (C1 to D1, the wheel advisory), under the strict model the auditor used: the
	-- helper window, its item panel (f.cur, the secure button's parent) and the button are protected, so the mock errors
	-- on Show, Hide, SetPoint, ClearAllPoints or SetSize of any of them in combat, as the game would.
	local DEID = 13262
	local function boot(prof, profiles)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = "modern", deEnabled = true, combatFade = false }
		for k, v in pairs(prof or {}) do p[k] = v end
		local all = { Default = p }
		for k, v in pairs(profiles or {}) do all[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = all }
		local known = true
		_G.IsSpellKnown = function(id) return id == DEID and known end
		_G.GetNumSkillLines = function() return 2 end
		_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, 150 end
		_G.RegisterStateDriver = function() end
		_G.UnregisterStateDriver = function() end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local DE = n.Disenchant
		DE:Show(); M.runTimers()
		local f = DE.frame
		-- every attempt to change a protected frame in combat is recorded (BagSmith's signal handlers catch errors, so a
		-- blocked call inside a refresh wouldn't reach the test otherwise)
		local blocked = {}
		local names = { [f] = "DE.frame", [f.cur] = "DE.frame.cur", [DE:Button()] = "the button" }
		for fr, label in pairs(names) do
			fr.protected = true; fr.IsProtected = function(self) return self.protected end
			for _, m in ipairs({ "Show", "Hide", "SetPoint", "ClearAllPoints", "SetSize", "SetParent", "StartMoving", "StartSizing", "StopMovingOrSizing" }) do
				local orig = fr[m]
				if orig then fr[m] = function(self, ...) if M.combat then blocked[#blocked + 1] = m .. " " .. label end; return orig(self, ...) end end
			end
		end
		n.blockedLog = blocked
		return n, M, DE, f, function(v) known = v end
	end
	local function noBlocked(n) local b = n.blockedLog; return #b == 0, table.concat(b, ", ") end
	local function combat(M, on) M.combat = on; M.fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED"); M.runTimers() end
	local function armed(DE) local b = DE:Button(); return b:GetAttribute("type") == "spell" and b:GetAttribute("target-slot") ~= nil end

	-- ---- C1: turning the helper off closes and disarms it, in combat too, and it doesn't re-arm after combat
	local n, M, DE, f = boot()
	check(armed(DE), "(setup) the helper is open and armed for the boots")
	combat(M, true)
	local ok, err = pcall(n.Set, n, "deEnabled", false); M.runTimers()
	local clean, log = noBlocked(n)
	check(ok and clean, "C1: turning the helper off in combat makes no blocked call (" .. tostring(err or log) .. ")")
	check(f:GetAlpha() == 0 and f.bsSoftClosed, "C1: in combat it closes as far as you can tell")
	combat(M, false)
	check(not f:IsShown() and not armed(DE), "C1: after combat it's closed and stays disarmed (not re-armed while off)")
	local okNow = DE:LiveCheck({ bag = 0, slot = 1, itemID = 7001 })
	check(not okNow, "C1: and the click-time check refuses while the helper is off")
	-- out of combat
	n, M, DE, f = boot()
	n:Set("deEnabled", false); M.runTimers()
	check(not f:IsShown() and not armed(DE), "C1: turning it off out of combat closes and disarms it")
	-- switching to a profile where it's off
	n, M, DE, f = boot(nil, { Off = { skin = "modern", deEnabled = false } })
	ok, err = pcall(function() if n.Profiles and n.Profiles.Use then n.Profiles:Use("Off") else n:Set("__profile", "Off") end end); M.runTimers()
	check(ok and n.db.deEnabled == false, "(setup) the profile switch happened (" .. tostring(err) .. ")")
	check(not f:IsShown() and not armed(DE), "C1: switching to a profile with the helper off closes and disarms it")

	-- ---- C2: no repaint in combat (open or closed as far as you can tell); a fresh look after combat
	n, M, DE, f = boot()
	combat(M, true)
	DE:Close()
	n.items = {}
	ok, err = pcall(n.Fire, n, "ITEMS_CHANGED"); M.runTimers()
	clean, log = noBlocked(n)
	check(ok and clean, "C2: after closing it in combat, the bags emptying makes no blocked call (" .. tostring(err or log) .. ")")
	combat(M, false)
	check(not f:IsShown(), "C2: and after combat it's closed")
	n, M, DE, f = boot()
	combat(M, true)
	n.items = {}
	ok, err = pcall(n.Fire, n, "ITEMS_CHANGED"); M.runTimers()
	clean, log = noBlocked(n)
	check(ok and clean, "C2: with it open in combat, the bags emptying makes no blocked call either (" .. tostring(err or log) .. ")")
	ok, err = pcall(combat, M, false)
	check(ok and #(DE.entries or {}) == 0 and not armed(DE), "C2: after combat it repaints from a fresh look: nothing listed, nothing armed (" .. tostring(err) .. ")")

	-- ---- C3: drag and resize do nothing in combat, whatever the combat lock
	n, M, DE, f = boot({ combatLock = false })
	combat(M, true)
	ok, err = pcall(f:GetScript("OnDragStart"), f)
	local ok2, err2 = pcall(f:GetScript("OnDragStop"), f)
	check(ok and ok2, "C3: dragging in combat makes no blocked call (" .. tostring(err or err2) .. ")")
	ok, err = pcall(f.bsCatcher:GetScript("OnDragStart"), f.bsCatcher)
	check(ok, "C3: nor through its catcher (" .. tostring(err) .. ")")
	ok, err = pcall(f.grip:GetScript("OnMouseDown"), f.grip)
	ok2, err2 = pcall(f.grip:GetScript("OnMouseUp"), f.grip)
	clean, log = noBlocked(n)
	check(ok and ok2 and clean, "C3: resizing in combat makes no blocked call (" .. tostring(err or err2 or log) .. ")")
	combat(M, false)
	f:GetScript("OnDragStart")(f); f:GetScript("OnDragStop")(f)
	check(type(n.db.dePos) == "table", "C3: out of combat dragging still works and remembers the spot")

	-- ---- D1: losing the profession disarms
	local setKnown
	n, M, DE, f, setKnown = boot()
	check(armed(DE), "(setup) armed")
	setKnown(false); M.fire("SKILL_LINES_CHANGED"); M.runTimers()
	check(not armed(DE), "D1: when Disenchant is no longer known, the button is disarmed")

	-- ---- the wheel: closing in combat switches off wheel input too, and opening restores it
	n, M, DE, f = boot()
	combat(M, true)
	DE:Close()
	local wheelOff = false
	for _, c in ipairs({ f:GetChildren() }) do if c.bsWheelOff then wheelOff = true end end
	local deep = f.scroll and f.scroll.bsWheelOff
	check(wheelOff or deep, "wheel: closing in combat switches off wheel input on its parts")
	DE:Show(); M.runTimers()
	local still = false
	local function walk(fr) for _, c in ipairs({ fr:GetChildren() }) do if c.bsWheelOff or c.bsMouseOff then still = true end; walk(c) end end
	walk(f)
	check(not still, "wheel: reopening mid-fight restores mouse and wheel input")
	combat(M, false)

	-- ---- (beta2) the About page shows the TOC's release date (1.5.6 shipped saying 7 November, built on the 8th)
	local toc = {}
	for line in io.lines("BagSmith/BagSmith.toc") do local k, v = line:match("^## ([%w%-]+):%s*(.-)%s*$"); if k then toc[k] = v end end
	_G.C_AddOns.GetAddOnMetadata = function(_, k) return toc[k] end
	local y, mo, d = (toc["X-Date"] or ""):match("^(%d+)%-(%d+)%-(%d+)$")
	local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }
	local want = y and ("released %s %d, %s"):format(MONTHS[tonumber(mo)], tonumber(d), y)
	local line = n.SettingsPanel:VersionLine()
	check(want and line:find(want, 1, true), "About: the version line shows the TOC's release date (" .. tostring(line) .. ")")
end)()
