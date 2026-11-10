-- 1.6.0-beta8: the 1.6.0-beta7 audit's own probe (independent/disenchant_fault_extension.lua, unchanged), kept in the suite. Evidence and the report:
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



for _,skin in ipairs({'modern','classic'}) do
 for _,mode in ipairs({'normal','container_throw','container_nil','guid_throw','guid_changed','refund_throw','equipment_throw'}) do
  _G.C_EquipmentSet=nil -- isolate the optional mock service between fault cases
  local n,M,DE,f=boot({skin=skin})
  local b=DE:Button();check(armed(DE),skin..' '..mode..' setup armed')
  if mode=='container_throw' then C_Container.GetContainerItemInfo=function()error('AUDIT bag read failure')end
  elseif mode=='container_nil' then C_Container.GetContainerItemInfo=function()return nil end
  elseif mode=='guid_throw' then C_Item.GetItemGUID=function()error('AUDIT GUID failure')end
  elseif mode=='guid_changed' then C_Item.GetItemGUID=function()return 'REPLACED-COPY' end
  elseif mode=='refund_throw' then C_Container.GetContainerItemPurchaseInfo=function()error('AUDIT refund read failure')end
  elseif mode=='equipment_throw' then C_EquipmentSet={GetEquipmentSetIDs=function()error('AUDIT equipment set read failure')end,GetEquipmentSetInfo=function()end,GetItemLocations=function()end,UseEquipmentSet=function()end};n.GearSets.dirty=true end
  local ok,err=pcall(b:GetScript('PreClick'),b)
  check(ok,skin..' '..mode..' PreClick handles known safety read failure '..tostring(err))
  if mode=='normal' then check(armed(DE) and DE.castingEntry~=nil,skin..' ordinary PreClick remains armed')
  else check(not armed(DE) and DE.current==nil and DE.castingEntry==nil,skin..' '..mode..' disarmed in the same PreClick, before timers') end
  print('OBS',skin,mode,'ok',ok,'armed',armed(DE),'reason',tostring(DE.lastDisarm))
 end
end
end)()
end
