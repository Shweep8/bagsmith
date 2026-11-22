-- Classic keeps an untinted default frame; only uncommon+ and quests get color.
local ns = { db = { skin = "classic", border = "all" }, OnSignal = function() end }
C_Item = { GetItemQualityColor = function(q) return q == 2 and 0 or 1, 1, q == 2 and 0 or 1 end }
assert(loadfile("BagSmith/Core/Buttons.lua"))("BagSmith", ns)
local B = ns.Buttons
local function texture()
	return setmetatable({ points = {}, coords = { 0, 0, 0, 1, 1, 0, 1, 1 } }, { __index = {
		SetTexture = function(t, f) t.file, t.atlas = f, nil end,
		GetTexture = function(t) return t.file end,
		SetAtlas = function(t, a) t.atlas = a end,
		GetAtlas = function(t) return t.atlas end,
		SetTexCoord = function(t, ...) t.coords = { ... } end,
		GetTexCoord = function(t) return unpack(t.coords) end,
		SetVertexColor = function(t, ...) t.color = { ... } end,
		Show = function(t) t.shown = true end, Hide = function(t) t.shown = false end,
		ClearAllPoints = function(t) t.points = {}; t.allPoints = nil end,
		SetPoint = function(t, ...) t.points[#t.points + 1] = { ... } end,
		SetAllPoints = function(t, relative) t.allPoints = relative end,
		SetSize = function(t, w, h) t.w, t.h = w, h end,
		SetWidth = function(t, w) t.w = w end, SetHeight = function(t, h) t.h = h end,
		GetRect = function() return 100, 200, 37, 37 end,
	} })
end
local function button(source)
	local b = { mode = "cell", icon = texture(), IconBorder = source,
		CreateTexture = function(_, name, layer, template, sub) local t = texture(); t.layer, t.sub = layer, sub; return t end, GetEffectiveScale = function() return 1 end }
	B.AddFrame(b)
	check(b.defaultFrame and b.defaultFrame.allPoints == b.icon and b.defaultFrame.layer == "OVERLAY" and b.defaultFrame.sub == 2, "default frame follows the picture above artwork but below number sublayer 3")
	return b
end
for _, setting in ipairs({ "all", "unc", "off" }) do
	for _, source in ipairs({ texture(), false }) do
		local b = button(source or nil)
		ns.db.skin, ns.db.border = "classic", setting
		for _, quality in ipairs({ 0, 1 }) do
			B:ApplyQuality(b, { quality = quality })
			check(not b.qFrame.shown and not b.qRing, "poor/common items have no rarity tint")
			check(b.defaultFrame and b.defaultFrame.shown and b.defaultFrame.color[1] == .72 and b.defaultFrame.color[2] == .72 and b.defaultFrame.color[3] == .72, "poor/common items retain a visible silver-gray default frame")
		end
		for quality = 2, 5 do
			B:ApplyQuality(b, { quality = quality })
			check(b.qFrame.shown == (setting ~= "off"), "green and above respect rarity setting")
			check(b.defaultFrame and b.defaultFrame.shown == (setting == "off"), "disabled rarity coloring falls back to default frame")
		end
		for _, rec in ipairs({
			{ quality = 1, classID = 12 }, { quality = 1, bindType = 4 },
			{ quality = 2, isQuest = true },
		}) do
			B:ApplyQuality(b, rec)
			check(b.qFrame.shown and b.qFrame.color[1] == 1 and b.qFrame.color[2] == .82 and b.qFrame.color[3] == 0, "quest class/binding/flag all receive gold")
			check(b.defaultFrame and not b.defaultFrame.shown, "quest frame replaces default frame without doubling")
		end
		B:ApplyQuality(b, { quality = 1, cat = "Quest" })
		check(not b.qFrame.shown, "moving an ordinary item to Quest does not change its border")
		B:ApplyQuality(b, { quality = 1, isQuest = true })
		check(b.qFrame.shown and b.qFrame.color[1] == 1 and b.qFrame.color[2] == .82 and b.qFrame.color[3] == 0, "quest items have gold borders")
		check(b.qFrame.points[1][2] == b.icon and b.qFrame.points[1][4] == 0 and b.qFrame.points[2][4] == 0, "frame matches the icon bounds")
		B:ApplyQuality(b, { quality = 1 })
		check(not b.qFrame.shown, "reusing quest cell removes added border")
		B:ApplyQuality(b, nil)
		check(not b.qFrame.shown, "empty cells hide item frame")
		check(b.defaultFrame and not b.defaultFrame.shown, "empty cells hide default item outline")
		ns.db.skin = "modern"; B:ApplyQuality(b, { quality = 1, isQuest = true })
		check(not b.qFrame.shown and b.modernBorder[1].shown, "Modern retains its pixel outline")
		check(b.defaultFrame and not b.defaultFrame.shown, "default Classic frame cannot leak into Modern")
		-- (1.8.0-beta11, by design, Shweep) quest items are gold in Modern too (Gold Frame for Quest Items, on by default)
		check(b.modernBorder[1].color[1] == 1 and math.abs(b.modernBorder[1].color[2] - 0.82) < 1e-9 and b.modernBorder[1].color[3] == 0, "Modern quest items are gold too")
		ns.db.skin = "classic"; B:ApplyQuality(b, { quality = 1 })
		check(not b.qFrame.shown and not b.modernBorder[1].shown, "skin switch restores default Classic common slot")
		b.mode = "row"; B:ApplyQuality(b, { quality = 1 })
		check(b.defaultFrame.shown and not b.qFrame.shown and b.defaultFrame.color[1] == .72 and b.defaultFrame.color[2] == .72 and b.defaultFrame.color[3] == .72, "common list rows use the neutral textured frame")
		check(b.defaultFrame and b.defaultFrame.shown, "list icons share the textured default frame")
		for _, rec in ipairs({ { quality = 1, isQuest = true }, { quality = 1, classID = 12 }, { quality = 1, bindType = 4 } }) do
			B:ApplyQuality(b, rec)
			check(b.qFrame.shown and not b.defaultFrame.shown and b.qFrame.color[1] == 1 and b.qFrame.color[2] == .82 and b.qFrame.color[3] == 0, "Classic list quest ring is gold for all quest criteria")
		end
		B:ApplyQuality(b, { quality = 2 })
		check((setting == "off" and b.defaultFrame.shown and not b.qFrame.shown) or (setting ~= "off" and b.qFrame.shown and not b.defaultFrame.shown), "disabled list rarity coloring retains a neutral ring")
		if setting ~= "off" then check(b.qFrame.color[1] == 0 and b.qFrame.color[2] == 1, "list uncommon ring is green") end
		B:ApplyQuality(b, { quality = 0 })
		check(b.defaultFrame.shown and b.defaultFrame.color[1] == .72 and b.defaultFrame.color[2] == .72 and not b.qFrame.shown, "reused list rows clear quest/rarity tint")
	end
end

-- Exercise real secure and cached pools despite changes to the native region.
package.loaded.mock = nil
local M = require("mock")
local create = CreateFrame
CreateFrame = function(kind, name, parent, template)
	local f = create(kind, name, parent, template)
	if template and template:find("ContainerFrameItemButtonTemplate", 1, true) then
		f.IconBorder = f.IconBorder or f:CreateTexture(nil, "OVERLAY")
		f.IconBorder:SetAtlas("pool-template-border")
		f.IconBorder.GetAtlas = function(t) return t.atlas end
	end
	return f
end
BagSmithCharDB = { version = 1, firstSeen = {} }
BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "classic" } } }
local addon = M.loadAddon("BagSmith")
M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
local pool = addon.Buttons
local live = pool:Get(0, 1)

live.IconBorder:SetAtlas("item-update-border")
local cached = pool:GetCached(addon.Window.main.child, 1)
for _, b in ipairs({ live, cached }) do
	pool:SetMode(b, "cell"); pool:ApplyQuality(b, { quality = 2 })
	check(b.qFrame.texture == "Interface\\AddOns\\BagSmith\\Media\\ui-icon-frame.tga", "live/cached pool uses matching frame despite native updates")
	check(not b.IconBorder or not b.IconBorder:IsShown(), "native region stays hidden to avoid duplicate borders")
end
check(live.IconBorder:GetAlpha() == 0, "secure template cannot restore a second visible frame")
CreateFrame = create

-- Live and cached Classic icons fill the slot at every rarity; skin switches
-- restore the Modern inset and do not leave Classic with a second dark rim.
for _, b in ipairs({live, cached}) do
 for _, q in ipairs({0, 1, 2}) do
  addon.db.skin = "classic"; pool:SetMode(b, "cell"); pool:ApplyQuality(b, {quality=q})
  check(b.icon.points[1][2] == b and b.icon.points[1][4] == 0 and b.icon.points[2][4] == 0, "Classic artwork fills slot for every rarity")
  if q == 2 then check(b.qFrame.points[1][2] == b.icon and b.qFrame.points[1][4] == 0 and b.qFrame.points[2][4] == 0, "rarity frame matches the icon bounds") end
 end
 addon.db.skin = "modern"; pool:ApplyFrame(b)
 check(b.icon.points[1][4] == 2 and b.icon.points[2][4] == -2, "Modern retains inset after Classic")
 addon.db.skin = "classic"; pool:ApplyFrame(b)
 check(b.icon.points[1][2] == b and b.icon.points[1][4] == 0 and b.icon.points[2][4] == 0, "switching back restores full Classic artwork")
end

-- Delayed visibility/layout changes wake the shared driver after it has gone idle.
pool:WakeModernBorders()
for i=1,12 do M.tick() end
check(not pool.BorderDriverRunning(), "alignment driver settles instead of polling forever")
live:Hide(); live:Show()
check(pool.BorderDriverRunning(), "showing a reused item wakes alignment after settling")
for i=1,12 do M.tick() end
check(not pool.BorderDriverRunning(), "show-triggered alignment settles again")
local resized=live:GetScript("OnSizeChanged")
check(type(resized)=="function", "secure item size changes have an alignment hook")
if resized then resized(live) end
check(pool.BorderDriverRunning(), "late item size change wakes alignment")
for i=1,12 do M.tick() end
check(not pool.BorderDriverRunning(), "size-triggered alignment settles again")
