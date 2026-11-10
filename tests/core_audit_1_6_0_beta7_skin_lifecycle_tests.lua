-- 1.6.0-beta8: the 1.6.0-beta7 audit's own probe (independent/combat_skin_lifecycle_extension.lua, unchanged), kept in the suite. Evidence and the report:
-- docs/plugins/audit-1.6.0-beta7/.
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



-- Combined skin/gesture/visibility/profile extension; actual secure snippet runs in controlled secure context.
for _,skin in ipairs({'modern','classic'}) do
 for _,gesture in ipairs({'none','drag','resize'}) do
  for _,route in ipairs({'open','closed','soft-close','restore','escape'}) do
   for _,last in ipairs({'enabled','disabled','lost-profession'}) do
    local other=skin=='modern' and 'classic' or 'modern'
    local n,M,DE,f,setKnown=boot({skin=skin,combatFade=false,combatLock=false},{Off={skin=other,deEnabled=false,accent='ff0000'},On={skin=other,deEnabled=true,accent='00ff00'}})
    local label=skin..' '..gesture..' '..route..' '..last
    if gesture=='drag' then f:GetScript('OnDragStart')(f) elseif gesture=='resize' then f.grip:GetScript('OnMouseDown')(f.grip) end
    if route=='closed' then DE:Close() end
    combat(M,true)
    n:Set('skin',other);n:Set('accent','ff0000');n:Set('skin',skin);n:Set('skin',other)
    if route=='soft-close' or route=='restore' then DE:Close() elseif route=='escape' then f.bsEscape:Hide() end
    if route=='restore' then DE:Show() end
    if last=='disabled' then n.Profiles:Use('Off')
    elseif last=='lost-profession' then setKnown(false);M.fire('SKILL_LINES_CHANGED')
    else n:Set('accent','00ff00') end
    if gesture=='drag' then f:GetScript('OnDragStop')(f) elseif gesture=='resize' then f.grip:GetScript('OnMouseUp')(f.grip) end
    n:Fire('ITEMS_CHANGED');DE:Paint();DE:SkinNow();M.runTimers()
    check(#n.blockedLog==0,label..' zero insecure protected calls in combat '..table.concat(n.blockedLog,','))
    check(DE.skinPending==true,label..' skin work remains pending in combat')
    combat(M,false)
    local open=(route=='open' or route=='restore') and last~='disabled'
    check(f:IsShown()==open and not f.bsSoftClosed,label..' final visibility')
    check(armed(DE)==(open and last~='lost-profession'),label..' final armed state')
    check(not f.bsMoving and not f.bsSizing,label..' gesture completed')
    check(not DE.skinPending and (f.classicState and f.classicState.on or false)==(other=='classic'),label..' last skin applied even while hidden or disabled')
    check(not n.errorLog or #n.errorLog==0,label..' no guarded callback errors')
    -- Repeat the cycle with the opposite skin, ensuring no stale pending callback resurrects a closed helper.
    combat(M,true);n:Set('skin',skin);combat(M,false)
    check(not DE.skinPending and (f.classicState and f.classicState.on or false)==(skin=='classic'),label..' second combat cycle applies last skin')
    check(f:IsShown()==open and armed(DE)==(open and last~='lost-profession'),label..' second cycle retains visibility/arming')
    if not open then local b=DE:Button();b:GetScript('PreClick')(b);check(not armed(DE) and not DE.castingEntry,label..' hidden direct PreClick is disarmed') end
   end
  end
 end
end
end)()
end
