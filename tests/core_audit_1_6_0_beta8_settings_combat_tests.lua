-- 1.6.0-beta9: the 1.6.0-beta8 audit's own probe (independent/new_settings_combat_beta8.lua, unchanged), kept in the suite. Evidence and the report:
-- docs/plugins/audit-1.6.0-beta8/.
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




-- beta8-specific settings/profession updates crossing protected combat lifecycles.
for _,skin in ipairs({'modern','classic'})do
 for _,route in ipairs({'open','closed','soft-close','restore','escape'})do
  for _,gesture in ipairs({'none','drag','resize'})do
   for _,change in ipairs({'settings','profile','skill','repeat','finalnever'})do
    _G.Auctionator={API={v1={GetAuctionPriceByItemLink=function()return 600 end,GetAuctionPriceByItemID=function()return 600 end}}}
    _G.BlackthornesTS_API=nil
    local n,M,D,f=boot({skin=skin,deLeveling='auto',deAhMargin=.2,deMargin=.1,combatFade=false,combatLock=false})
    D.MatsValue=function()return 600 end
    local skill={rank=150,cap=150}
    _G.GetSkillLineInfo=function(i)if i==1 then return 'Professions',true end;return 'Enchanting',false,nil,skill.rank,0,0,skill.cap end
    D:Refresh()
    local initial=f.cur.verdict.text
    check(D.current and D.current.verdict=='vendor',skin..route..gesture..change..' setup vendor')
    if gesture=='drag'then f:GetScript('OnDragStart')(f)elseif gesture=='resize'then f.grip:GetScript('OnMouseDown')(f.grip)end
    if route=='closed'then D:Close()end
    combat(M,true)
    local label=table.concat({skin,route,gesture,change},' ')
    if route=='soft-close' or route=='restore'then D:Close()elseif route=='escape'then f.bsEscape:Hide()end
    if route=='restore'then D:Show()end
    if change=='settings'then n:Set('deLeveling','always');n:Set('deMargin',2);n:Set('deAhMargin',2)
    elseif change=='profile'then local raw=n.Copy(n.db);raw.deLeveling='always';raw.deAhMargin=0;local name=n.Profiles:Import('new-setting-switch',raw);n.Profiles:Use(name)
    elseif change=='skill'then skill.rank=149;M.fire('SKILL_LINES_CHANGED')
    elseif change=='repeat'then n:Set('deLeveling','always');n:Set('deLeveling','never');n:Set('deLeveling','auto');skill.rank=149;M.fire('SKILL_LINES_CHANGED')
    elseif change=='finalnever'then n:Set('deLeveling','always');n:Set('deLeveling','never')end
    n:Set('skin',skin=='modern'and'classic'or'modern')
    n:Fire('ITEMS_CHANGED');D:Paint();M.runTimers()
    if gesture=='drag'then f:GetScript('OnDragStop')(f)elseif gesture=='resize'then f.grip:GetScript('OnMouseUp')(f.grip)end
    check(#n.blockedLog==0,label..' no insecure protected mutations in combat '..table.concat(n.blockedLog,','))
    check(f.cur.verdict.text==initial,label..' visible verdict freezes during combat')
    check(not armed(D),label..' combat state snippet disarms')
    combat(M,false)
    local open=route=='open'or route=='restore'
    check(f:IsShown()==open and not f.bsSoftClosed,label..' visibility preserved after unlock')
    check(armed(D)==open,label..' only open helper rearms')
    if open then
     local verdict=change=='finalnever'and'vendor'or'de'
     check(D.current.verdict==verdict,label..' final mode/skill re-evaluated')
     check((f.cur.verdict.text:find('(for leveling)',1,true)~=nil)==(verdict=='de'),label..' verdict label agrees')
     check((f.status.text:find('Leveling Enchanting',1,true)~=nil)==(verdict=='de'),label..' leveling note agrees')
    else local b=D:Button();b:GetScript('PreClick')(b);check(not armed(D)and not D.castingEntry,label..' hidden keybind cannot arm')end
    check(not n.errorLog or #n.errorLog==0,label..' no guarded callback errors')
    check(not f.bsMoving and not f.bsSizing,label..' gesture completed')
   end
  end
 end
end
end)()
end
