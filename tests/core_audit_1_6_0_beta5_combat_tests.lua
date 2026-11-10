-- 1.6.0-beta6: the 1.6.0-beta5 audit's own probe (combat/independent_combat_probes_driver.lua, unchanged), kept in the suite so its findings stay fixed. It failed on
-- beta5 as the audit reported; it must pass from beta6 on. Evidence and the report: docs/plugins/audit-1.6.0-beta5/.
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

    local function result(label, n, ok, err)
        local clean, log = noBlocked(n)
        check(ok and clean, label .. ": " .. (clean and tostring(err or "no blocked calls") or log))
    end
    for _, skin in ipairs({"modern", "classic"}) do
        -- Controls are permitted by configuration, except protected operations themselves.
        local n, M, DE, f = boot({skin=skin, combatFade=false, combatLock=false})
        combat(M, true)
        local r = assert(f.rows[1], "boot must provide a real row")
        local ok, err = pcall(r:GetScript("OnClick"), r)
        result(skin .. " row click during combat", n, ok, err)

        n, M, DE, f = boot({skin=skin, combatFade=false, combatLock=false})
        f:GetScript("OnDragStart")(f)
        assert(f.bsMoving, "boot must start dragging before combat")
        combat(M, true)
        ok, err = pcall(f:GetScript("OnDragStop"), f)
        result(skin .. " drag release after combat starts", n, ok, err)

        n, M, DE, f = boot({skin=skin, combatFade=false, combatLock=false})
        f.grip:GetScript("OnMouseDown")(f.grip)
        assert(f.bsSizing, "boot must start sizing before combat")
        combat(M, true)
        ok, err = pcall(f.grip:GetScript("OnMouseUp"), f.grip)
        result(skin .. " resize release after combat starts", n, ok, err)

        for _, softClose in ipairs({false, true}) do
            n, M, DE, f = boot({skin=skin, combatFade=false, combatLock=false})
            _G.LOOT_ITEM_SELF = "You receive loot: %s."
            _G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
            DE:Button():GetScript("PreClick")(DE:Button())
            assert(DE.castingEntry, "cast must be stamped")
            M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "audit-cast", DEID)
            assert(DE.castOpen, "cast attribution must be open")
            local mat = DE:Expectation(DE.castOpen.entry.rec)[1][1]
            -- Do not advance synthetic timers: loot arrives within the documented five-second window.
            driver(M,DE,"lock"); M.combat = true; M.fire("PLAYER_REGEN_DISABLED")
            if softClose then DE:Close() end
            ok, err = pcall(M.fire, "CHAT_MSG_LOOT", ("You receive loot: |Hitem:%d:0|h[material]|h."):format(mat))
            assert(DE.session.mats[mat] == 1, "loot must reach the real attribution path")
            result(skin .. " loot receipt during combat, soft-closed=" .. tostring(softClose), n, ok, err)
        end

        n, M, DE, f = boot({skin=skin}, {Off={skin=skin, deEnabled=false}})
        combat(M, true)
        ok, err = pcall(n.Profiles.Use, n.Profiles, "Off")
        M.runTimers()
        result(skin .. " switch to helper-off profile in combat", n, ok, err)
        check(f.bsSoftClosed and f:GetAlpha()==0, skin .. " profile change immediately soft-closes")
        combat(M, false)
        check(not f:IsShown() and not armed(DE), skin .. " helper stays closed and disarmed after combat")
    end
end)()
