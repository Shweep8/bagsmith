-- The generic client mock returns constant screen coordinates. Model anchor
-- geometry here so a height change can actually move the bottom edge.
local anchors = {
	TOPLEFT = { 0, 1 }, TOP = { .5, 1 }, TOPRIGHT = { 1, 1 },
	LEFT = { 0, .5 }, CENTER = { .5, .5 }, RIGHT = { 1, .5 },
	BOTTOMLEFT = { 0, 0 }, BOTTOM = { .5, 0 }, BOTTOMRIGHT = { 1, 0 },
}
local function geometry(f)
	f.GetEffectiveScale = function(self) return (self.scale or 1) * UIParent:GetEffectiveScale() end
	local function bounds(self)
		local point, _, relative, x, y = self:GetPoint()
		local a, r = anchors[point], anchors[relative]
		local ratio = UIParent:GetEffectiveScale() / self:GetEffectiveScale()
		return UIParent:GetWidth() * ratio * r[1] + x - self:GetWidth() * a[1],
			UIParent:GetHeight() * ratio * r[2] + y - self:GetHeight() * a[2]
	end
	f.GetLeft = function(self) local l = bounds(self); return l end
	f.GetBottom = function(self) local _, b = bounds(self); return b end
	f.GetRight = function(self) return self:GetLeft() + self:GetWidth() end
	f.GetTop = function(self) return self:GetBottom() + self:GetHeight() end
end
local function near(a, b) return math.abs(a - b) < .001 end

for _, skin in ipairs({ "modern", "classic" }) do
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local v, f = n.Window.main, n.Window.main.frame
	geometry(f)
	UIParent:SetSize(1600, 1000)
	UIParent.GetWidth = function() return 1600 end
	UIParent.GetEffectiveScale = function() return .75 end
	n.db.sizeMode, n.db.maxW, n.db.maxH = "auto", 680, 720

	-- Removing normalization must make shrinking/growing move the bottom.
	-- Different relative anchors catch conversions that assume both ends match.
	for point in pairs(anchors) do
		for _, relative in ipairs({ point, "CENTER", "BOTTOMLEFT" }) do
			for _, scale in ipairs({ .8, 1, 1.25 }) do
				n.db.scale = scale; f:SetScale(scale); f:SetSize(680, 600)
				n.db.point = { point, "UIParent", relative, 37, 150 }
				f:ClearAllPoints(); f:SetPoint(point, UIParent, relative, 37, 150)
				local left, bottom = f:GetLeft(), f:GetBottom()
				for _, h in ipairs({ 300, 650, 400, 900, 300 }) do
					v.autoHeight = h; v:ApplySize()
					check(near(f:GetBottom(), bottom), skin .. ": bottom stays fixed: " .. point .. "/" .. relative .. "/" .. scale .. "/" .. h)
					check(near(f:GetLeft(), left), skin .. ": horizontal position stays fixed")
					check(f:GetHeight() == math.min(h, 720), skin .. ": automatic height still capped")
				end
			end
		end
	end

	-- First construction has no old height: retain the initial full-size
	-- placement, then shrink upwards. CENTER at (800,650), height 600 => bottom 350.
	n.db.scale = 1; f:SetScale(1); f:SetSize(0, 0)
	n.db.maxH = 600
	n.db.point = { "CENTER", "UIParent", "CENTER", 0, 150 }
	v.autoHeight = 600; v:ApplySize()
	check(near(f:GetBottom(), 350), skin .. ": first placement does not jump")
	v.autoHeight = 300; v:ApplySize()
	check(near(f:GetBottom(), 350), skin .. ": first shrink preserves initial bottom")
	n.db.maxH = 720

	-- StopMovingOrSizing can choose TOP/CENTER. Saving a drag must immediately
	-- restore a bottom anchor, or a subsequent layout can move the clicked tabs.
	f:SetSize(680, 600); f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -50)
	v.dragMoving = true
	v.dragArea:GetScript("OnDragStop")()
	check(near(f:GetLeft(), 100) and near(f:GetBottom(), 350), skin .. ": drag save does not move frame")
	check(n.db.point[1] == "BOTTOMLEFT", skin .. ": drag stores bottom anchor")
	v.autoHeight = 300; v:ApplySize()
	check(near(f:GetBottom(), 350), skin .. ": shrink after drag holds bottom")
	-- Restoring saved position into a fresh geometry must not depend on old size.
	f:SetSize(0, 0); v:ApplySize()
	check(near(f:GetBottom(), 350), skin .. ": saved anchor survives recreation")

	-- Manual resize persists the new bottom, including unequal frame/UI scales.
	n.db.scale = .8; f:SetScale(.8); f:SetSize(680, 400)
	f:ClearAllPoints(); f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -60)
	n.db.point = { "CENTER", "UIParent", "CENTER", 0, 0 }
	v:SaveSizedPosition()
	v.autoHeight = 300; v:ApplySize()
	check(near(f:GetRight(), 1960) and near(f:GetBottom(), 790), skin .. ": resize stores actual bottom at scale")

	-- Mode changes keep the current bottom, but fixed-size anchors are preserved.
	n.db.scale = 1; n.db.sizeMode = "fixed"; n.db.fixW, n.db.fixH = 680, 600
	n.db.point = { "TOPLEFT", "UIParent", "TOPLEFT", 100, -50 }
	v:ApplySize(); v:SavePosition()
	check(n.db.point[1] == "TOPLEFT", skin .. ": fixed drag retains top anchor")
	n.db.sizeMode = "auto"; v.autoHeight = 300; v:ApplySize()
	check(near(f:GetBottom(), 350), skin .. ": fixed to auto holds bottom")
	n.db.sizeMode = "fixed"; v:ApplySize()
	check(f:GetHeight() == 600, skin .. ": fixed dimensions still restored")
	local bank = n.Window.bank
	n.db.bankPoint = { "TOPLEFT", "UIParent", "TOPLEFT", 40, -120 }
	bank:ApplySize(); bank:SavePosition()
	check(n.db.bankPoint[1] == "TOPLEFT", skin .. ": bank keeps its anchor")

	-- The native resize gesture owns geometry until mouse-up.
	n.db.sizeMode = "auto"; v.sizing = true
	f:SetSize(710, 555); v.autoHeight = 300; v:ApplySize()
	check(f:GetWidth() == 710 and f:GetHeight() == 555, skin .. ": active resize is untouched")
	v.sizing = false

	-- Incoming legacy profiles must migrate as on first creation, independent
	-- of the outgoing window's height and cached content height (even hidden).
	for _, outgoing in ipairs({ 400, 600 }) do
		for _, incoming in ipairs({ { 300, 650 }, { 720, 230 } }) do
			n.Profiles:Use("Default")
			f:SetSize(680, outgoing); v.autoHeight = outgoing
			local name = n.Profiles:Import("Legacy " .. outgoing .. "/" .. incoming[1], {
				skin = skin, sizeMode = "auto", maxH = incoming[1],
				point = { "TOPLEFT", "UIParent", "TOPLEFT", 100, -50 },
			})
			n.Profiles:Use(name)
			check(near(f:GetBottom(), incoming[2]), skin .. ": legacy profile bottom independent of outgoing height " .. outgoing .. "/" .. incoming[1])
			v.autoHeight = 300; v:ApplySize()
			check(near(f:GetBottom(), incoming[2]), skin .. ": incoming layout preserves migrated bottom")
		end
	end
end
