;(function()
	-- ======== 1.7.3-beta4: the Disenchant Helper resizes by the shared outline too (Shweep: "extend this to all our
	-- windows that resize") ========
	-- The window keeps its size while the grip is held; the outline goes at once on release, even in combat; the window
	-- takes its size then, or when combat ends (a protected window: nothing protected is touched in combat).
	local DEID = 13262
	local function deBoot(skin)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
		M.put(0, 2, { id = 7003, name = "Fine Gloves", q = 2, count = 1, class = 4, subclass = 1, price = 400, ilvl = 22, equip = "INVTYPE_HAND" })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, deEnabled = true, combatFade = false } } }
		_G.IsSpellKnown = function(id) return id == DEID end
		_G.GetNumSkillLines = function() return 2 end
		_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, 150 end
		_G.RegisterStateDriver = function() end
		_G.UnregisterStateDriver = function() end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local DE = n.Disenchant
		DE:Show(); M.runTimers()
		local f = DE.frame
		local blocked = {}
		f.protected = true
		for _, m in ipairs({ "Show", "Hide", "SetPoint", "ClearAllPoints", "SetSize", "StartMoving", "StartSizing", "StopMovingOrSizing" }) do
			local orig = f[m]
			if orig then f[m] = function(self, ...) if M.combat then blocked[#blocked + 1] = m end; return orig(self, ...) end end
		end
		return n, M, DE, f, blocked
	end
	local function combat(M, on) M.combat = on; M.fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED"); M.runTimers() end

	for _, skin in ipairs({ "modern", "classic" }) do
		local S = skin .. ": "
		local n, M, DE, f, blocked = deBoot(skin)
		local O = n.Outline
		f:SetSize(700, 400)
		local w0, h0 = f:GetWidth(), f:GetHeight()

		-- out of combat: press, drag the outline, let go
		f.grip:GetScript("OnMouseDown")(f.grip)
		local o = O.frame
		check(f.bsSizing and o and o:IsShown() and O:Active(f), S .. "pressing the helper's grip shows the outline")
		check(o.w == w0 and o.h == h0 and o.resizeBounds and o.resizeBounds[1] == DE.MIN_W and o.resizeBounds[2] == DE.MIN_H,
			S .. "at the helper's size, with its minimum size")
		local p = o.points[1]
		check(p and p[1] == "TOPLEFT" and p[2] == UIParent and p[3] == "BOTTOMLEFT", S .. "anchored to the screen")
		o:SetSize(760, 450)
		check(f:GetWidth() == w0 and f:GetHeight() == h0, S .. "the helper keeps its size while the outline is dragged")
		f.grip:GetScript("OnMouseUp")(f.grip)
		check(not o:IsShown() and not f.bsSizing, S .. "letting go hides the outline")
		check(f:GetWidth() == 760 and f:GetHeight() == 450 and n.db.deSize and n.db.deSize[1] == 760 and n.db.deSize[2] == 450,
			S .. "the helper takes the outline's size, saved")

		-- released in combat: the outline goes now; the size waits for the end of combat, nothing protected touched
		f.grip:GetScript("OnMouseDown")(f.grip)
		o:SetSize(680, 380)
		combat(M, true)
		f.grip:GetScript("OnMouseUp")(f.grip)
		check(not o:IsShown(), S .. "released in combat: the outline goes at once")
		check(#blocked == 0 and f:GetWidth() == 760 and f.bsSizing, S .. "the helper waits, touching nothing protected (" .. table.concat(blocked, ", ") .. ")")
		combat(M, false)
		check(not f.bsSizing and f:GetWidth() == 680 and f:GetHeight() == 380 and n.db.deSize[1] == 680, S .. "after combat it takes the size, saved")

		-- combat starting while the button is still held: the outline ends; the size follows when combat ends
		f.grip:GetScript("OnMouseDown")(f.grip)
		o:SetSize(700, 390)
		combat(M, true)
		check(not o:IsShown() and #blocked == 0, S .. "combat starting mid-drag ends the outline, nothing protected touched")
		combat(M, false)
		check(f:GetWidth() == 700 and f:GetHeight() == 390 and not f.bsSizing, S .. "and the size follows when combat ends")

		-- closed mid-drag (out of combat): no outline left, the drag dropped
		f.grip:GetScript("OnMouseDown")(f.grip)
		o:SetSize(900, 500)
		f:Hide()
		check(not o:IsShown() and not f.bsSizing and not O:Active(f), S .. "closing the helper mid-drag leaves no outline")
		DE:Show(); M.runTimers()
		check(f:GetWidth() == 700, S .. "and keeps its size")

		-- Lock Windows and combat: the grip does nothing
		n:Set("lockWindows", true); M.runTimers()
		f.grip:GetScript("OnMouseDown")(f.grip)
		check(not o:IsShown() and not f.bsSizing, S .. "Lock Windows: no outline")
		n:Set("lockWindows", false); M.runTimers()
		combat(M, true)
		f.grip:GetScript("OnMouseDown")(f.grip)
		check(not o:IsShown() and not f.bsSizing, S .. "in combat: no outline")
		combat(M, false)

		-- one outline for every window: a bags window drag uses the same frame
		ToggleAllBags(); M.runTimers()
		local main = n.Window.main
		main.grip:GetScript("OnMouseDown")(main.grip)
		check(main.outline == o and O:Active(main.frame), S .. "the bags window uses the same outline")
		main.grip:GetScript("OnMouseUp")(main.grip)
	end
end)()
