;(function()
	-- 1.6.0 (production, Shweep's screenshot): the toolbar's "View" label goes with List / Icons to the row's right end,
	-- keeping its 6 px gap, wherever the labels show; narrower windows hide it as before.
	for _, skin in ipairs({ "modern", "classic" }) do
		package.loaded.mock = nil
		local M = require("mock")
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); M.runTimers(); M.runTimers()
		local V = n.Window.main
		local lbl, box
		for i, it in ipairs(V.toolItems) do if it.isLabel and it.frame.text == "View" then lbl, box = it, V.toolItems[i + 1] end end
		check(lbl and box, skin .. ": (setup) the View label and its List / Icons group")
		local function x(f) return select(4, f:GetPoint(1)) end
		for _, W in ipairs({ 700, 900, 1100 }) do
			V.tools.w = W; V:LayoutTools()
			local who = ("%s, a %d px toolbar"):format(skin, W)
			check(V.toolsLevel == 0 and lbl.frame:IsShown(), who .. ": (setup) the labels show")
			check(x(box.frame) + box.width == W, who .. ": List / Icons ends at the row's right end")
			check(math.abs(x(lbl.frame) + lbl.width + lbl.gap - x(box.frame)) < 0.01,
				who .. ": \"View\" sits right before it, 6 px apart (" .. tostring(x(lbl.frame)) .. " / " .. tostring(x(box.frame)) .. ")")
			check(x(lbl.frame) > x(V.btnMerge) + V.btnMerge:GetWidth(), who .. ": and no longer back after Merge Stacks")
		end
		V.tools.w = 416; V:LayoutTools()
		check(V.toolsLevel >= 1 and not lbl.frame:IsShown(), skin .. ", a narrow toolbar: the label is hidden, as before")
	end
end)()
