local function boot(skin)
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 40
	for s = 1, 20 do
		local class = s == 1 and 15 or (s <= 12 and 0 or 7)
		M.put(0, s, { id = 81000 + s, name = "Sample " .. s, q = 1, class = class, subclass = 0, price = 12 })
	end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {
		skin = skin, view = "icons", grp = "type", sizeMode = "fixed", fixW = 720, recentSection = false, mergeStacks = false,
	} } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	n.Window.main.frame.IsMouseOver = function() return false end
	return n, M, n.Window.main
end

local function headers(V)
	local out = {}
	for _, h in ipairs(V.used) do if h.laneId and h.text and h:IsShown() then out[#out + 1] = h end end
	return out
end
local function signature(V)
	local out = {}
	for _, h in ipairs(headers(V)) do
		local p = h.points[1]
		out[#out + 1] = table.concat({ h.laneId, h:GetWidth(), p[4], p[5] }, ":")
	end
	return table.concat(out, "|")
end
local n = boot("modern")
check(n.db.compactCategories == false, "compact categories defaults off")
check(n.CompactCategories and n.CompactCategories.Rows, "compact row planner is loaded")
assert(n.CompactCategories, "compact planner not implemented")
local pack = n.CompactCategories.Rows
local boxes = { { count = 1, minWidth = 100 }, { count = 11, minWidth = 120 }, { count = 13, minWidth = 110 }, { count = 1, minWidth = 80 } }
local rows = pack(boxes, 600, 40, 4, 3, 16)
check(#rows < #boxes and #rows[1] > 1, "different-sized categories share rows")
local pair = pack({{count=1,minWidth=40}, {count=11,minWidth=120}}, 600, 40, 4, 0, 16)
check(pair[1][1].width < pair[1][2].width, "small categories consume less width when headings allow")
for _, width in ipairs({ 90, 240, 420, 600, 900 }) do
	local index = 0
	for _, row in ipairs(pack(boxes, width, 40, 4, 3, 16)) do
		local used = 0
		for j, p in ipairs(row) do
			index = index + 1
			check(p.index == index, "packing preserves order at " .. width)
			check(p.across >= 1 and p.across * 44 - 4 + 6 <= p.width, "icons fit the category width")
			used = used + p.width + (j > 1 and 16 or 0)
		end
		check(used <= width, "row fits viewport at " .. width)
	end
	check(index == #boxes, "all categories placed exactly once")
end
rows = pack({ { count = 0, minWidth = 100 }, { count = 1, minWidth = 999 }, { count = 3, minWidth = 100, fullWidth = true }, { count = 1, minWidth = 80 } }, 400, 40, 4, 0, 16)
check(rows[1][1].across == 1, "empty categories have a usable shape")
check(#rows[2] == 1 and rows[2][1].width == 400, "long headings are bounded by viewport")
check(#rows[3] == 1 and rows[3][1].width == 400, "special section keeps its own full-width row")
check(#pack({}, 400, 40, 4, 0, 16) == 0, "empty result has no rows")
-- A greedy one-row lookahead leaves the six-item group on another row.
-- Wrapping it to three across fits all four groups in one two-line row.
local sizing = { {count=1,minWidth=90}, {count=1,minWidth=90}, {count=1,minWidth=90}, {count=6,minWidth=90} }
local arranged = pack(sizing, 560, 40, 4, 0, 16, 40)
check(#arranged == 1 and #arranged[1] == 4 and arranged[1][4].across == 3, "planner chooses shorter total layout over a greedy row")
local aligned = pack({{count=1,minWidth=91}}, 400, 40, 4, 3, 16, 40)[1][1]
check(aligned.width == 134, "heading-driven width rounds up to whole icon columns")
local balanced = pack({{count=7,minWidth=60}}, 300, 40, 4, 0, 16, 40)[1][1]
check(balanced.across == 4 and balanced.width == 172, "seven icons wrap four plus three, not six plus one")
local longBalanced = pack({{count=7,minWidth=240}}, 300, 40, 4, 0, 16, 40)[1][1]
check(longBalanced.across == 4 and longBalanced.width == 260, "wide heading does not force an orphan icon")
for count = 2, 40 do
	local p = pack({{count=count,minWidth=60}}, 300, 40, 4, 0, 16, 40)[1][1]
	local rows = math.ceil(count / p.across)
	check(rows == math.ceil(count / 6), "balanced wrapping does not add item rows")
	check(p.across == math.ceil(count / rows), "item rows use the smallest balanced column count")
end
-- Independent exhaustive oracle: try every column count and row break for
-- small inventories, rather than repeating the planner's binary search.
local function bruteHeight(boxes, width)
	local capacity = math.floor((width + 4) / 44)
	local function suffix(first)
		if first > #boxes then return 0 end
		local best = math.huge
		for last = first, #boxes do
			local function columns(i, used, depth)
				if i > last then best = math.min(best, 40 + depth * 44 + suffix(last + 1)); return end
				for across = 1, math.min(capacity, boxes[i].count) do
					local headingCols = math.ceil((boxes[i].minWidth + 4) / 44)
					local w = math.min(width, math.max(headingCols, across) * 44 - 4)
					local nextWidth = used + w + (i > first and 16 or 0)
					if nextWidth <= width then columns(i + 1, nextWidth, math.max(depth, math.ceil(boxes[i].count / across))) end
				end
			end
			columns(first, 0, 0)
		end
		return best
	end
	return suffix(1)
end
for _, a in ipairs({1, 3, 6, 9, 13}) do
	for _, b in ipairs({1, 3, 6, 9, 13}) do
		for _, c in ipairs({1, 3, 6, 9, 13}) do
			local cases = {{count=a,minWidth=60}, {count=b,minWidth=90}, {count=c,minWidth=60}}
			local height = 0
			for _, row in ipairs(pack(cases, 320, 40, 4, 0, 16, 40)) do
				local depth = 0
				for _, p in ipairs(row) do depth = math.max(depth, math.ceil(cases[p.index].count / p.across)) end
				height = height + 40 + depth * 44
			end
			check(height == bruteHeight(cases, 320), ("globally shortest layout for %d/%d/%d"):format(a,b,c))
		end
	end
end

for _, skin in ipairs({ "classic", "modern" }) do
	local n, M, V = boot(skin)
	local baseline = signature(V)
	n:Set("compactCategories", true); M.runTimers()
	check(V.compactCategories == true and not V.twoColumn, skin .. ": compact view activates")
	local hs = headers(V)
	check(#hs >= 3 and hs[2].points[1][4] > 0, skin .. ": categories share a row")
	local seen = {}
	for _, b in ipairs(V.used) do if b.rec and b.rec.itemID then seen[b.rec.itemID] = (seen[b.rec.itemID] or 0) + 1 end end
	local total = 0; for _, count in pairs(seen) do total = total + 1; check(count == 1, skin .. ": item shown once") end
	check(total == 20, skin .. ": all items remain present")
	local first, width, x = hs[1], hs[1]:GetWidth(), hs[1].points[1][4]
	local positions = {}
	for _, h in ipairs(hs) do positions[h.laneId] = { x = h.points[1][4], width = h:GetWidth() } end
	-- (by design since 1.9.4-beta1, Shweep: "prob would use the coin version": the totals leave the header's text for the coin)
	check(not first.sub:IsShown() and not first.vAmt:IsShown() and first.valCoin and first.valCoin:IsShown(), skin .. ": totals leave compact header for the coin")
	first.scripts.OnEnter(first)
	check(GameTooltip.shown and table.concat(GameTooltip.lines or {}, " "):find("V:", 1, true), skin .. ": totals accessible on heading hover")
	V:ToggleLane(first.laneId); M.runTimers()
	local folded = headers(V)[1]
	check(folded:GetWidth() == width and folded.points[1][4] == x, skin .. ": collapsing preserves width and x")
	for _, h in ipairs(headers(V)) do
		check(h.points[1][4] == positions[h.laneId].x and h:GetWidth() == positions[h.laneId].width, skin .. ": collapse keeps neighbor placement")
	end
	V:ToggleLane(folded.laneId); M.runTimers()
	n:Set("splitView", true); M.runTimers()
	check(V.compactCategories and not V.twoColumn, skin .. ": compact takes precedence over split")
	n:Set("compactCategories", false); M.runTimers()
	check(V.twoColumn and not V.compactCategories, skin .. ": disabling restores split")
	n:Set("splitView", false); M.runTimers()
	check(signature(V) == baseline, skin .. ": disabling restores original layout")
	for _, mode in ipairs({ { "view", "list" }, { "grp", "bag" }, { "grp", "none" } }) do
		n:Set(mode[1], mode[2]); M.runTimers(); local before = signature(V)
		n:Set("compactCategories", true); M.runTimers()
		check(not V.compactCategories and signature(V) == before, skin .. ": noncategory layout unchanged")
		n:Set("compactCategories", false); n:Set("view", "icons"); n:Set("grp", "type"); M.runTimers()
	end
	n.SettingsPanel:Show(); n.SettingsPanel:ShowPage("look"); M.runTimers()
	local found = false
	-- (1.9.0-beta5, by design) a 3-way button (Full Width | Split View | Compact View) in place of the dropdown
	for _, w in ipairs(n.SettingsPanel.pools.seg or {}) do if w:IsShown() and w.key == "iconLayout" then found = true end end
	check(found, skin .. ": icon layout selector available in Style")
	n.SettingsPanel:Hide()
	n:Set("compactCategories", true); M.runTimers()
	-- Width changes and long/localized titles must fit without changing the name.
	local label = n.Sections.Label
	n.Sections.Label = function(self, id) return string.rep("Long category ", 12) end
	V.scroll.w = 300; n:RefreshViews(true); M.runTimers()
	for _, h in ipairs(headers(V)) do
		check(h.compactTitle and h.text.width > 0 and h.text.width < h:GetWidth(), skin .. ": long title is constrained")
		check(h.text:GetText() == string.rep("Long category ", 12), skin .. ": complete title retained for hover")
	end
	n.Sections.Label = label
	V.scroll.w = nil; n:Set("compactCategories", false); M.runTimers()
	for _, h in ipairs(headers(V)) do check(not h.compactTitle and (h.text.width or 0) == 0, skin .. ": pooled title width restored") end
	n:Set("compactCategories", true); M.runTimers()
	-- Search keeps category packing, with just the matching items.
	V.st.filters.text = "Sample 20"; n:RefreshViews(true); M.runTimers()
	local matches = 0
	for _, b in ipairs(V.used) do if b.rec and b.rec.itemID then matches = matches + 1; check(b.rec.itemID == 81020, skin .. ": filtered item") end end
	check(matches == 1, skin .. ": search works in compact layout")
	V.st.filters.text = ""; n:RefreshViews(true); M.runTimers()
	-- Recent keeps its existing action button in a full-width row.
	n:Set("recentSection", true)
	n.cdb.recentSince = time() - 100
	for _, r in ipairs(n.items) do if r.guid then n.cdb.firstSeen[r.guid] = time() - 10 end end
	n:RefreshViews(true); M.runTimers()
	local recent
	for _, h in ipairs(headers(V)) do if h.laneId == "~recent" then recent = h end end
	check(recent and recent.points[1][4] == 0 and recent.clearRecent:IsShown(), skin .. ": Recent retains Clear action")
	-- Combat changes defer layout, then apply after leaving combat.
	local beforeCombat = signature(V)
	M.combat = true; M.fire("PLAYER_REGEN_DISABLED")
	n:Set("compactCategories", false); M.runTimers()
	check(signature(V) == beforeCombat, skin .. ": combat defers layout changes")
	M.combat = false; M.fire("PLAYER_REGEN_ENABLED"); M.runTimers(); M.runTimers()
	check(not V.compactCategories, skin .. ": deferred layout applies after combat")
	-- The same category renderer serves the live bank and saved-bank sheet.
	M.put(-1, 1, { id = 91001, name = "Bank cloth", q = 1, class = 7, subclass = 5, price = 20 })
	M.put(-1, 2, { id = 91002, name = "Bank food", q = 1, class = 0, subclass = 5, price = 5 })
	n:Set("compactCategories", true); n:Set("bankView", "icons"); n:Set("bankGrp", "type")
	M.fire("BANKFRAME_OPENED"); M.runTimers(); M.runTimers()
	local bank = n.Window.bank
	check(bank and bank.compactCategories and #headers(bank) >= 2, skin .. ": live bank uses compact categories")
	M.fire("BANKFRAME_CLOSED"); M.runTimers()
	-- (by design since 1.11.0-beta3, Shweep's "1": Always Close closes the bags at every place, whether they opened for it or were open already): opened again to look at the saved bank
	n.Window:Show(); M.runTimers()
	V.st.sheet = "Bank"; n:RefreshViews(true); M.runTimers()
	local cachedItems = 0
	for _, b in ipairs(V.used or {}) do if b.rec and b.rec.itemID then cachedItems = cachedItems + 1 end end
	check(V:IsCached() and V.compactCategories and cachedItems == 2, skin .. ": saved bank retains both items")
end

for _, skin in ipairs({ "classic", "modern" }) do
	local n, M, V = boot(skin)
	-- All eleven shards become one visible icon; their category must shrink too.
	for s = 1, 11 do M.put(0, s, { id = 6265, name = "Soul Shard", q = 1, class = 5, subclass = 0, price = 0 }) end
	M.maxStack = { [6265] = 1 }
	n:Set("compactCategories", true); n:Set("mergeStacks", false)
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	local function shardCategory()
		local id, icons = nil, 0
		for _, b in ipairs(V.used or {}) do if b.rec and b.rec.itemID == 6265 then id = b.inLane; icons = icons + 1 end end
		for _, h in ipairs(headers(V)) do if h.laneId == id then return h, icons end end
	end
	local expanded, expandedIcons = shardCategory()
	local expandedWidth = expanded:GetWidth()
	check(expandedIcons == 11, skin .. ": unmerged shards show eleven icons")
	n:Set("mergeStacks", true); M.runTimers()
	local merged, mergedIcons = shardCategory()
	check(mergedIcons == 1 and merged.count:GetText() == "(1)", skin .. ": merged category counts visible icons")
	check(merged:GetWidth() < expandedWidth and merged:GetWidth() < 300, skin .. ": merged shards use a small category, not a full row")
	n.MakeRoom.IsWarlock = function() return true end
	n.MakeRoom.BagFamily = function() return 0 end
	n.MakeRoom.Shards = function() return 11, 11 end
	n:RefreshViews(true); M.runTimers()
	merged = shardCategory()
	check(merged.clearShards and merged.clearShards:IsShown(), skin .. ": clear-shards action remains available")
	-- (by design since 1.9.4-beta1: each section's minimum also holds the coin, so in this 600 px window Modern moves
	-- Trade Goods to a second row and the first row's two sections widen to fill it; "not a full row" is now checked as
	-- sharing its row, not as under 300 px)
	local sharing = false
	for _, x in ipairs(headers(V)) do if x ~= merged and x.points[1][5] == merged.points[1][5] then sharing = true end end
	check(merged:GetWidth() >= 30 + merged.text:GetStringWidth() + merged.count:GetStringWidth() + 94
		and sharing, skin .. ": reserve actual action width without forcing a row")
	n.MakeRoom.IsWarlock = function() return false end
	n:Set("mergeStacks", false); M.runTimers()
	local restored, restoredIcons = shardCategory()
	check(restoredIcons == 11 and restored:GetWidth() == expandedWidth, skin .. ": unmerge restores category size")
end

for _, skin in ipairs({"classic", "modern"}) do
	local n, M, V = boot(skin)
	local P = n.SettingsPanel
	local function control(pool, key)
		for _, w in ipairs(P.pools[pool] or {}) do if w:IsShown() and w.key == key then return w end end
	end
	n:Set("splitView", true); n:Set("compactCategories", true)
	P:Show(); P:ShowPage("look"); M.runTimers()
	-- (1.9.0-beta5, by design) Shweep: "a 3-way button with Full Width, Split View and Compact View w/ the sub-setting
	-- of Full-Width Recent if Split View or Compact View are selected, otherwise that setting is disabled/greyed out"
	local function seg() return control("seg", "iconLayout") end
	local function active()
		for _, b in ipairs(seg().btns) do if b:IsShown() and b.active then return b.label:GetText() end end
	end
	local function choose(name)
		for _, b in ipairs(seg().btns) do if b:IsShown() and b.label:GetText() == name then b:GetScript("OnClick")(b); M.runTimers(); return end end
		error("Missing layout choice: " .. name)
	end
	local function recentRow()
		local c = control("check", "splitViewRecentWide")
		return c, c and c.box:IsEnabled()
	end
	assert(seg(), "Icon Layout selector missing")
	local labels = {}
	for _, b in ipairs(seg().btns) do if b:IsShown() then labels[#labels + 1] = b.label:GetText() end end
	check(table.concat(labels, "|") == "Full Width|Split View|Compact View", skin .. ": three choices: " .. table.concat(labels, "|"))
	check(active() == "Compact View", skin .. ": old combined flags display Compact View")
	check(not control("check","compactCategories") and not control("check","splitView"), skin .. ": old checkboxes replaced")
	choose("Full Width")
	local row, on = recentRow()
	check(not n.db.splitView and not n.db.compactCategories and active() == "Full Width", skin .. ": Full Width clears both")
	check(row and not on, skin .. ": Full Width: Full-Width Recent shown but greyed")
	choose("Split View")
	row, on = recentRow()
	check(n.db.splitView and not n.db.compactCategories and row and on, skin .. ": Split View enables Full-Width Recent")
	choose("Compact View")
	row, on = recentRow()
	check(not n.db.splitView and n.db.compactCategories and row and on, skin .. ": Compact View enables the same Full-Width Recent")
	-- the font dropdown (Jeor's binding left it its own setting) still picks a font
	local menu, oldMenu = nil, n.ShowMenu
	n.ShowMenu = function(items) menu = items end
	local font = control("dropdown", "fontName")
	font.btn:GetScript("OnClick")(font.btn)
	check(menu[1].checked, skin .. ": regular font dropdown retains saved selection")
	local selectedFont = font.choices[2].key
	menu[2].onClick(); M.runTimers()
	check(n.db.fontName == selectedFont and n.db.compactCategories and not n.db.splitView, skin .. ": font dropdown leaves the layout alone")
	font = control("dropdown", "fontName")
	font.btn:GetScript("OnClick")(font.btn); menu[1].onClick(); M.runTimers()
	check(n.db.fontName == "", skin .. ": and back to Default Font")
	n.ShowMenu = oldMenu; P:Hide()
	n.RecentRecords = function() return { n.items[1] } end
	n:Set("recentSection",true); n:Set("splitViewRecentWide",true); M.runTimers()
	local function recent()
		for _, h in ipairs(headers(V)) do if h.laneId == "~recent" then return h end end
	end
	local full = recent():GetWidth()
	n:Set("splitViewRecentWide",false); M.runTimers()
	local h = recent()
	check(h:GetWidth() < full and h.clearRecent:IsShown(), skin .. ": Recent packs with action when full-width is off")
	check(h:GetWidth() >= 30 + h.text:GetStringWidth() + h.count:GetStringWidth() + 94, skin .. ": packed Recent reserves Clear Recent width")
	check(not h.sub:IsShown(), skin .. ": packed Recent has no overlapping explanation")
	n:Set("splitViewRecentWide",true); M.runTimers()
	check(recent():GetWidth() == full, skin .. ": Recent restores full-width row")
end
