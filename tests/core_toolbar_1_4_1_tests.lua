;(function()
	-- 1.4.1-beta4 (Shweep's feedback): in Classic, "Merge Stacks" became "Merge" and List / Icons didn't read as a pair;
	-- and the Merge Stacks tooltip only described List view. The toolbar now narrows in two steps (labels first, then
	-- "Merge"), Classic's group buttons touch, and the tooltip covers both views.
	local function boot(skin)
		package.loaded.mock = nil
		local M = require("mock")
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); M.runTimers(); M.runTimers()
		return n, M, n.Window.main
	end
	local function labelsShown(V) local c = 0; for _, it in ipairs(V.toolItems) do if it.isLabel and it.frame:IsShown() then c = c + 1 end end return c end

	for _, skin in ipairs({ "modern", "classic" }) do
		local n, M, V = boot(skin)
		local full, noLabels = V:ToolsTotal(0), V:ToolsTotal(1)
		V.tools.w = full + 20; V:LayoutTools()
		check(V.toolsLevel == 0 and labelsShown(V) == 2 and V.btnMerge.label.text == "Merge Stacks", skin .. ": room for everything: labels and Merge Stacks")
		V.tools.w = full - 1; V:LayoutTools()
		check(V.toolsLevel == 1 and labelsShown(V) == 0 and V.btnMerge.label.text == "Merge Stacks", skin .. ": a little short: the labels go first, Merge Stacks stays")
		V.tools.w = noLabels - 1; V:LayoutTools()
		check(V.toolsLevel == 2 and labelsShown(V) == 0 and V.btnMerge.label.text == "Merge" and V.toolsWidth <= noLabels, skin .. ": shorter still: Merge Stacks becomes Merge")
		V:SyncTools()
		check(V.btnMerge.label.text == "Merge", skin .. ": and a toolbar refresh keeps it that way")
		V.tools.w = full + 20; V:LayoutTools(); V:SyncTools()
		check(V.btnMerge.label.text == "Merge Stacks", skin .. ": widening brings Merge Stacks back")
		check(V.btnMerge.tip == "Combine stacks of the same item into one, with the total count: one row in List view, one icon in Icons", skin .. ": the tooltip covers List and Icons")
		V.tools.w = nil; V:LayoutTools()
	end

	-- ---- Classic: each group's buttons touch, so a pair reads as a pair; groups keep their spacing
	local n, M, V = boot("classic")
	local touching = true
	for _, box in ipairs(V.segBoxes) do
		local prevRight
		for _, b in ipairs(box.btns) do
			local p = b.points and b.points[1]
			local left = p and p[4] or 0
			if prevRight and left ~= prevRight then touching = false end
			prevRight = left + b:GetWidth()
		end
		check(math.abs(box:GetWidth() - prevRight) < 0.5, "classic: the group's frame is exactly its buttons' width")
	end
	check(touching, "classic: All, By Section, By Bag touch, and so do List and Icons")
	-- at the default width Classic now has room for its full toolbar
	check(V.toolsLevel == 0 and V.btnMerge.label.text == "Merge Stacks", "classic at the default width: Merge Stacks, with the labels (" .. tostring(V.toolsLevel) .. ")")
	-- Modern keeps its joined segments as before
	n, M, V = boot("modern")
	local box = V.segBoxes[1]
	check(box.btns[1].points[1][4] == 1 and box.btns[1].divider and box.btns[1].divider:IsShown(), "modern: the joined segments with dividers, as before")
end)()
