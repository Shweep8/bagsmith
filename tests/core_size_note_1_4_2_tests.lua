;(function()
	-- 1.4.2-beta3 (Shweep's feedback): Style > Size explains, with a small info icon on Icon Size, that cooldown times
	-- show only when they fit inside an icon (the only thing that hides at small sizes).
	for _, skin in ipairs({ "modern", "classic" }) do
		package.loaded.mock = nil
		local M = require("mock")
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local P = n.SettingsPanel
		P:Show(); P:ShowPage("icons")   -- (1.5.0: Icon Size moved to the Item Icons page)
		local iconRow, others = nil, 0
		for _, w in ipairs(P.pools.step) do
			if w:IsShown() then
				if w.key == "iconSize" then iconRow = w elseif w.info and w.info:IsShown() then others = others + 1 end
			end
		end
		check(iconRow and iconRow.info and iconRow.info:IsShown(), skin .. ": Icon Size has an info icon")
		local lines = iconRow and iconRow.info.lines or {}
		check(iconRow and iconRow.info.title == "Smaller icons" and (lines[1] or ""):find("only when they fit inside it", 1, true) and (lines[1] or ""):find("darkening sweep", 1, true) and (lines[1] or ""):find("List rows work the same way", 1, true), skin .. ": its tooltip explains cooldown times at small sizes")
		check((lines[2] or ""):find("game's own option for cooldown numbers", 1, true), skin .. ": and that they follow the game's option")
		check(others == 0, skin .. ": the other size rows (Scale, Row Height) have no info icon")
		-- the settings search finds it from "cooldown"
		local box = P.frame.search
		box:SetText("cooldown"); box:GetScript("OnTextChanged")(box, true)
		local found = false
		for _, w in ipairs(P.pools.step) do if w:IsShown() and w.key == "iconSize" then found = true end end
		check(found, skin .. ": searching for \"cooldown\" finds the Icon Size row")
		box:SetText(""); box:GetScript("OnTextChanged")(box, true)
		P:Hide()
	end
end)()
