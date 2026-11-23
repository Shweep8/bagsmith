-- (by design since 1.10.0-beta12) this set tests the NEW tags with 1.9's list, which the panel's own list (each
-- release's) replaced: 1.9's, as it stood at 1.9.8, is put back after the addon loads
local function NEW19()
	return { release = "1.9",
		pages = { general = true, window = true, icons = true, look = true, sections = true, columns = true, sheets = true,
			globalsections = true, globalcols = true, globalsheets = true },
		heads = {},
		keys = { tipInventory = "general", tipAHPrice = "general", bagSlotCount = "window", borderWeight = "icons", iconLayout = "look", footerTextScale = "look", globalResize = "window" },
		added = {
			["1.9.1"] = { keys = { splitViewPinnedWide = "look" } },
			["1.9.2"] = { keys = { unusableOverlay = "icons" } },
			["1.9.4"] = { keys = { sectionValues = "sections" } },
		} }
end
-- ======== 1.9.1-beta2 (Shweep, 18 Nov) ========
-- "let's have pinned also get a sub-setting under icon layout so like recent can decide if full width or not":
-- Full-Width Pinned (splitViewPinnedWide, off by default), under Icon Layout after Full-Width Recent. In Split View and
-- Compact View each pinned section gets a full-width row of its own; greyed under Full Width.

local function boot(skin, prof)
	package.loaded.mock = nil
	local M = require("mock")
	-- texts measured as the game does an inline icon: the mock counts a |T...|t texture code as ~50 characters of text,
	-- so a pinned section's header ("(n)  [pin] Pinned") read about 460 px wide and could never share a row; the game
	-- draws a 12 px icon
	local mk = M.fs
	M.fs = function()
		local fs = mk()
		fs.GetStringWidth = function(self) return #(tostring(self.text or ""):gsub("|T.-|t", "xx")) * 6 end
		return fs
	end
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
	M.put(0, 2, { id = 118, name = "Minor Healing Potion", q = 1, count = 3, class = 0, subclass = 1, price = 5 })
	M.put(1, 1, { id = 2318, name = "Light Leather", q = 1, count = 2, class = 7, subclass = 6, price = 2 })
	M.put(1, 2, { id = 2592, name = "Wool Cloth", q = 1, count = 4, class = 7, subclass = 5, price = 3 })
	M.put(1, 3, { id = 6948, name = "Hearthstone", q = 1, count = 1, class = 15, subclass = 0, price = 0 })
	M.put(1, 4, { id = 159, name = "Refreshing Spring Water", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local pr = { skin = skin, view = "icons", grp = "type", sizeMode = "fixed", fixW = 900 }
	for k, v in pairs(prof or {}) do pr[k] = v end
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = pr } }
	local n = M.loadAddon("BagSmith"); n.SettingsPanel.NEW = NEW19()
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	return n, M, n.Window.main
end
local function lanes(n, V)
	local t = {}
	for _, h in pairs(n.Buttons.lanes[V.child] or {}) do if h:IsShown() and h.laneId then t[#t + 1] = h end end
	return t
end
local function lane(n, V, id) for _, h in ipairs(lanes(n, V)) do if h.laneId == id then return h end end end

for _, skin in ipairs({ "modern", "classic" }) do
	local S = skin .. ": "
	-- Split View
	local n, M, V = boot(skin, { splitView = true })
	n.Sections:SetPinned("Consumables", true); n:RefreshViews(true); M.runTimers()
	local full = V.child:GetWidth()
	local pin = lane(n, V, "Consumables")
	check(V.twoColumn and pin and #lanes(n, V) >= 3, S .. "(setup) Split View, Consumables pinned, with other sections")
	check(n.db.splitViewPinnedWide == false and pin:GetWidth() < full * 0.6, S .. "Split View, off by default: the pinned section takes one column (" .. pin:GetWidth() .. " of " .. full .. ")")
	n:Set("splitViewPinnedWide", true); M.runTimers()
	pin = lane(n, V, "Consumables")
	check(pin:GetWidth() > full * 0.9 and pin.points[1][4] == 0, S .. "Split View, on: the pinned section spans both columns (" .. pin:GetWidth() .. ")")
	local others = {}
	for _, h in ipairs(lanes(n, V)) do if h.laneId ~= "Consumables" then others[#others + 1] = h end end
	local paired = false
	for i = 1, #others do for j = i + 1, #others do
		if others[i].points[1][5] == others[j].points[1][5] then paired = true end
	end end
	check(paired, S .. "the other sections still pair, two to a row")
	for _, h in ipairs(others) do check(h.points[1][5] ~= pin.points[1][5], S .. h.laneId .. " isn't beside it") end
	-- two pinned sections: each its own row
	n.Sections:SetPinned("TradeGoods", true); n:RefreshViews(true); M.runTimers()
	local a, b = lane(n, V, "Consumables"), lane(n, V, "TradeGoods")
	check(a and b and a:GetWidth() > full * 0.9 and b:GetWidth() > full * 0.9 and a.points[1][5] ~= b.points[1][5], S .. "two pinned sections: a full-width row each")
	check((n.errors or 0) == 0, S .. "Split View: no errors")

	-- Compact View
	n, M, V = boot(skin, { compactCategories = true })
	n.Sections:SetPinned("Consumables", true); n:RefreshViews(true); M.runTimers()
	full = V.child:GetWidth()
	pin = lane(n, V, "Consumables")
	local sharing = false
	for _, h in ipairs(lanes(n, V)) do if h ~= pin and h.points[1][5] == pin.points[1][5] then sharing = true end end
	check(pin and sharing and pin:GetWidth() < full * 0.9, S .. "Compact View, off: the pinned section shares its row (" .. (pin and pin:GetWidth() or 0) .. " of " .. full .. ")")
	n:Set("splitViewPinnedWide", true); M.runTimers()
	pin = lane(n, V, "Consumables")
	sharing = false
	for _, h in ipairs(lanes(n, V)) do if h ~= pin and h.points[1][5] == pin.points[1][5] then sharing = true end end
	check(not sharing and pin:GetWidth() > full * 0.9, S .. "Compact View, on: a full-width row of its own (" .. pin:GetWidth() .. ")")
	check((n.errors or 0) == 0, S .. "Compact View: no errors")

	-- Settings: after Full-Width Recent, greyed under Full Width
	local P = n.SettingsPanel; P:Show(); P:ShowPage("look"); M.runTimers()
	local function box(key) for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.key == key then return w end end end
	local c, r = box("splitViewPinnedWide"), box("splitViewRecentWide")
	check(c and c.text.text == "Full-Width Pinned" and c.help.text == "Gives each pinned section its own full-width row instead of sharing space with other sections." and c.box:IsEnabled(),
		S .. "Settings > Style: Full-Width Pinned, as worded")
	check(r and c.points[1][5] < r.points[1][5] and c.points[1][4] == r.points[1][4], S .. "right under Full-Width Recent, indented the same")
	n.version = "1.9.1-beta2"
	check(P:InRelease("keys", "splitViewPinnedWide"), S .. "on 1.9's NEW list")
	n:Set("compactCategories", false); n:Set("splitView", false); M.runTimers()
	c = box("splitViewPinnedWide")
	check(c and not c.box:IsEnabled() and c.box:GetChecked(), S .. "greyed under Full Width, showing its setting")
	P:Hide()
	check((n.errors or 0) == 0, S .. "no errors")
end
