-- 1.6.0-beta7: the 1.6.0-beta6 audit's own probe (combat/combat_skin_probe.lua, unchanged), kept in the suite so its findings stay fixed. It failed on
-- beta6 as the audit reported; it must pass from beta7 on. Evidence and the report: docs/plugins/audit-1.6.0-beta6/.
-- Independent beta6 audit extension: actual settings callbacks, expanded protected geometry instrumentation.
-- Original combat fixture adapted from the preserved beta5 evidence; product source is unmodified.
do
(function()
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
		local n = M.loadAddon(AUDIT_CORE or "BagSmith")
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
			for _, m in ipairs({ "Show", "Hide", "SetPoint", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight", "SetParent", "StartMoving", "StartSizing", "StopMovingOrSizing", "EnableMouse", "SetAttribute" }) do
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

    -- Execute the candidate's actual state-driver snippet in a controlled secure-context simulation.
    -- The harness's ordinary protected-method checks apply only to insecure addon calls.
    local function driver(M, DE, state)
        local b=DE:Button()
        local was=M.combat; M.combat=false
        local fn=assert(loadstring(b:GetAttribute("_onstate-bscombat")))
        setfenv(fn,{self=b,newstate=state}); fn()
        M.combat=was
    end
    combat = function(M,on)
        local DE=_G.BagSmith.Disenchant
        if not on then M.combat=false end
        driver(M,DE,on and "lock" or "open")
        M.combat=on; M.fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED"); M.runTimers()
    end


for _,skin in ipairs({"modern", "classic"}) do
  for _,case in ipairs({"switch-skin", "change-accent", "same-profile", "closed-switch-skin", "soft-closed-switch-skin", "combat-price-switch"}) do
    local n,M,DE,f = boot({skin=skin, combatFade=false, combatLock=false}, {Other={skin=skin, deEnabled=true}})
    if case=="closed-switch-skin" then DE:Close() end
    combat(M,true)
    if case=="soft-closed-switch-skin" then DE:Close() end
    local ok,err=pcall(function()
      if case:find("switch%-skin") then n:Set("skin",skin=="modern" and "classic" or "modern")
      elseif case=="change-accent" then n:Set("accent","ff0000")
      elseif case=="same-profile" then n.Profiles:Use("Other")
      elseif case=="combat-price-switch" then n:Set("priceSource","blackthornes") end
      M.runTimers(); M.runTimers()
    end)
    print("OBS "..skin.." "..case.." ok="..tostring(ok).." errors="..tostring(err).." calls="..table.concat(n.blockedLog," | "))
    check(ok and #n.blockedLog==0,skin.." "..case.." no insecure protected mutations during combat")
    combat(M,false)
    check(case=="closed-switch-skin" or case=="soft-closed-switch-skin" or armed(DE),skin.." "..case.." helper remains functional after combat")
    if case=="closed-switch-skin" or case=="soft-closed-switch-skin" then check(not f:IsShown() and not armed(DE),skin.." "..case.." stays closed/disarmed") end
  end
end
end)()
end
