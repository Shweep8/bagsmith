--[[
	Core/Tutorials.lua

	Blizzard's reagent bag tutorial. After you get a reagent bag, Blizzard
	shows "You've obtained a reagent bag! Open your bag." on the backpack
	button and waits for Blizzard's own bag window to open, which never
	happens while BagSmith replaces your bags, so the tip stays. (From
	Blizzard's UI: Blizzard_TutorialReagentBag.lua and BagTutorialUtil.lua.)

	While BagSmith stands in for Blizzard's bags, the tutorial can't finish
	on its own, so BagSmith finishes it the way Blizzard records it: the
	tutorial's flag in the "closedInfoFrames" setting (so it never comes
	back), and the tip hidden if it's showing (never in combat). Nothing else
	of Blizzard's is touched or triggered. Names that a client doesn't have
	are skipped; /bs check reports what happened.
--]]
local ADDON, ns = ...
local T = {}
ns.Tutorials = T

local SYSTEM = "TutorialReagentBag"   -- the tip's HelpTip system name

function T:ReagentFlag() return rawget(_G, "LE_FRAME_TUTORIAL_EQUIP_REAGENT_BAG") end

-- What /bs check reports.
function T:Status()
	local flag = self:ReagentFlag()
	if not flag or not (C_CVar and C_CVar.SetCVarBitfield) then return "not found on this client (nothing to do)" end
	local done = C_CVar.GetCVarBitfield and C_CVar.GetCVarBitfield("closedInfoFrames", flag)
	if done then return "finished" .. (self.finishedBy and (" (by BagSmith, " .. self.finishedBy .. ")") or "") end
	return "not finished yet (BagSmith finishes it while it replaces Blizzard's bags)"
end

function T:FinishReagentBag(why)
	if not (ns.db and ns.db.replaceBlizzardBags) then return end   -- Blizzard's bags in use: their tutorial works
	local flag = self:ReagentFlag()
	if flag and C_CVar and C_CVar.SetCVarBitfield then
		local done = C_CVar.GetCVarBitfield and C_CVar.GetCVarBitfield("closedInfoFrames", flag)
		if not done then
			C_CVar.SetCVarBitfield("closedInfoFrames", flag, true)
			self.finishedBy = why
			ns:Debug("Blizzard's reagent bag tutorial marked finished (%s)", why)
		end
	end
	-- The tip, if it's up now.
	if not InCombatLockdown() and type(HelpTip) == "table" and type(HelpTip.HideAllSystem) == "function" then
		pcall(HelpTip.HideAllSystem, HelpTip, SYSTEM)
	end
end

ns:OnSignal("ADDON_READY", function()
	-- While BagSmith stands in for Blizzard's bags their tutorial can never
	-- finish on its own, so it's marked finished at login (and when
	-- replacement is turned on). This session's copy of it may already be
	-- running, so its tip is also hidden after bag updates and whenever
	-- BagSmith's bags open.
	ns:On("PLAYER_ENTERING_WORLD", function() T:FinishReagentBag("BagSmith replaces Blizzard's bags") end)
	ns:OnSignal("SETTINGS_CHANGED", function(key)
		if key == nil or key == "replaceBlizzardBags" then T:FinishReagentBag("BagSmith replaces Blizzard's bags") end
	end)
	ns:On("BAG_UPDATE_DELAYED", function()   -- a moment later: Blizzard shows the tip on this event too
		ns:NextFrame("reagentTutorial", function() T:FinishReagentBag("bag update") end)
	end)
	local main = ns.Window and ns.Window.main
	if main and main.frame then main.frame:HookScript("OnShow", function() T:FinishReagentBag("bags opened") end) end
	-- Once now, too: the game's "entered the world" event can come before
	-- BagSmith has finished loading, so the login check above may miss it.
	T:FinishReagentBag("at login")
end)
