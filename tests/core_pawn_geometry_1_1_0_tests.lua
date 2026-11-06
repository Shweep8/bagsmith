;(function()
	-- 1.1.0-beta4: the Pawn arrow beside the multi-set shield stays inside its row or cell at every supported size (beta3 audit)
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local oldUpgrade = n.Pawn.IsUpgrade; n.Pawn.IsUpgrade = function() return true end
	local rec = { itemID = 7001, link = "item:7001", gearSets = { "Tank", "DPS" } }
	local plain = { itemID = 7001, link = "item:7001" }
	local function rect(t) local p, rel, rp, x, y = t:GetPoint(1); return { x, y, x + t:GetWidth(), y + t:GetHeight(), p } end
	local function place(mode, iconSize, rowH)
		local b = CreateFrame("Button", nil, UIParent)
		b.mode = mode; b.hasItem = true; b.rec = rec
		b.icon:SetSize(iconSize, iconSize)
		if rowH then b:SetHeight(rowH) else b:SetHeight(iconSize) end
		n.Buttons:LinkMark(b, rec); n.Pawn:Decorate(b, rec)
		return b
	end
	local function judge(b, label, limit)
		local a, s = rect(b.pawnArrow), rect(b.linkMark)
		local overlapW = math.max(0, math.min(a[3], s[3]) - math.max(a[1], s[1]))
		local overlapH = math.max(0, math.min(a[4], s[4]) - math.max(a[2], s[2]))
		check(b.pawnArrow:IsShown() and b.linkMark:IsShown() and (overlapW == 0 or overlapH == 0) and a[4] <= limit + 1e-9 and a[1] >= 0 and b.pawnArrow:GetWidth() >= 6,
			("%s: arrow (%dpx, top %.1f) above the shield, inside its bounds (limit %.1f), no overlap"):format(label, b.pawnArrow:GetWidth(), a[4], limit))
	end
	-- list rows. (1.5.0-beta3) List rows follow the icon corners too: one mark per corner, the arrow first by
	-- default, in the corner at full size, inside the row's icon; the shield waits.
	for _, rowH in ipairs({ 20, 22, 26, 32 }) do
		local iconSize = math.max(14, math.min(24, rowH - 6))
		local b = place("row", iconSize, rowH)
		local a = rect(b.pawnArrow)
		-- (1.5.0-beta4: BagSmith's marks stop at half the icon, inside their quarter)
		local want = math.min(math.max(10, math.floor(iconSize * 0.45 + 0.5)), math.floor(iconSize / 2))
		check(b.pawnArrow:IsShown() and not b.linkMark:IsShown() and a[1] == 0 and a[2] == 0 and b.pawnArrow:GetWidth() == want,
			("row %d (icon %d): the arrow in the corner (%d px), the shield waits (one mark per corner)"):format(rowH, iconSize, b.pawnArrow:GetWidth()))
	end
	-- cells, the supported icon sizes. (1.5.0) In Icons view the icon corners give the bottom-left to one mark at a
	-- time: the arrow (first by default) shows in the corner at full size and the shield waits; no stacking there.
	for _, size in ipairs({ 24, 33, 42, 48 }) do
		local b = place("cell", size)
		local a = rect(b.pawnArrow)
		check(b.pawnArrow:IsShown() and not b.linkMark:IsShown() and a[1] == 0 and a[2] == 0 and b.pawnArrow:GetWidth() == math.max(10, math.floor(size * 0.45 + 0.5)),
			("cell %d: the arrow in the corner at full size, the shield waits (one mark per corner)"):format(size))
	end
	-- transitions: the shield gone, the arrow is back in the corner at full size; the shield back, it rises again
	local b = place("cell", 33)
	local withShield = b.pawnArrow:GetWidth()
	n.Buttons:LinkMark(b, plain)
	local a = rect(b.pawnArrow)
	check(not b.linkMark:IsShown() and a[2] == 0 and a[1] == 0 and b.pawnArrow:GetWidth() == math.max(10, math.floor(33 * 0.45 + 0.5)), "shield off: the arrow returns to the corner at full size")
	n.Buttons:LinkMark(b, rec)
	a = rect(b.pawnArrow)
	check(not b.linkMark:IsShown() and a[2] == 0 and b.pawnArrow:GetWidth() == withShield, "shield on again: in Icons view the arrow keeps the corner and the shield waits (1.5.0)")
	local r = place("row", 14, 20)
	n.Buttons:LinkMark(r, plain)
	check(r.pawnArrow:GetWidth() == math.floor(14 / 2) and rect(r.pawnArrow)[2] == 0, "a compact row's arrow fills its quarter (half the icon) once the shield goes")
	n.Pawn.IsUpgrade = oldUpgrade
end)()

