;(function()
	-- 1.6.0-beta5 (Shweep's look at beta4): the empty space right of Filter, and Classic's tabs stacking below the window.
	--  * both rows end at the window's edge, at every width: the toolbar's last control (List / Icons) sits at the row's
	--    right end and Filter ends above it; a new step folds Sections into its menu before anything turns into icons
	--  * the sheet tabs keep to one row in both skins: tabs that don't fit fold into a "»" tab with a menu (New Sheet...
	--    at its bottom, the + stepping aside); the tab you're on always stays in view
	local function boot(skin)
		package.loaded.mock = nil
		local M = require("mock")
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, view = "list", grp = "type" } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); M.runTimers(); M.runTimers()
		return n, M, n.Window.main
	end
	-- ---- a horizontal layout resolver: a region's left and right edges in the window's coordinates, from its anchors
	local function natural(r)
		if r.GetStringWidth then
			local sw = r:GetStringWidth() or 0
			if r.width and r.width > 0 then return math.min(r.width, sw) end
			return sw
		end
		return r.w
	end
	local function parentOf(r) return r.parentFrame or r.parent end
	local span
	local function anchorX(rel, rp, root, depth)
		local l, rr = span(rel, root, depth + 1)
		if not l then return nil end
		if rp:find("LEFT") then return l elseif rp:find("RIGHT") then return rr end
		return (l + rr) / 2
	end
	span = function(r, root, depth)
		depth = depth or 0
		if r == root then return 0, root.w or root:GetWidth() end
		if depth > 40 or not r then return nil end
		local L, R, C
		for _, p in ipairs(r.points or {}) do
			local point, rel, rp, x = p[1], p[2], p[3], p[4]
			if type(rel) ~= "table" then rel, rp, x = parentOf(r), point, rel end
			local ax = anchorX(rel, rp or point, root, depth)
			if not ax then return nil end
			ax = ax + (tonumber(x) or 0)
			if point:find("LEFT") then L = ax elseif point:find("RIGHT") then R = ax else C = ax end
		end
		local w = natural(r)
		if L and R then return L, R end
		if not w then return nil end
		if L then return L, L + w end
		if R then return R - w, R end
		if C then return C - w / 2, C + w / 2 end
		return nil
	end
	local function sized(V, W)
		V.frame.w = W
		for _, r in ipairs({ V.title, V.tools, V.footer }) do
			local l, rr = span(r, V.frame)
			if l then r.w = rr - l end
		end
		V:LayoutTools(); V:UpdateFooter(); V:LayoutTitleRow()
		for _, r in ipairs({ V.title, V.tools, V.footer }) do
			local l, rr = span(r, V.frame)
			if l then r.w = rr - l end
		end
		V:LayoutTools(); V:UpdateFooter(); V:LayoutTitleRow()
	end
	local function fmt(x) return x and ("%.1f"):format(x) or "?" end

	for _, skin in ipairs({ "modern", "classic" }) do
		local n, M, V = boot(skin)
		-- ---- the new step: Sections folds into its menu first; Sort, Merge and List | Icons stay as they are
		local full = V:ToolsTotal(0)
		check(V:ToolsTotal(3) <= 420 and V:ToolsTotal(3) < V:ToolsTotal(2), skin .. ": the Sections-menu step needs about 400 px (" .. V:ToolsTotal(3) .. ")")
		V.tools.w = V:ToolsTotal(2) - 1; V:LayoutTools(); V:SyncTools()
		check(V.toolsLevel == 3 and V.btnGrpMenu:IsShown() and not V.segBoxes[1]:IsShown(), skin .. ": a little too narrow for the third step: Sections becomes its menu button")
		check(V.btnSort.label.text == "Sort: Quality" and V.btnMerge:IsShown() and V.btnMerge.label.text == "Merge" and V.segBoxes[2]:IsShown()
			and not V.btnMergeIcon:IsShown() and not V.btnViewIcon:IsShown(), skin .. ": Sort, Merge and List | Icons stay as they are")
		V.tools.w = V:ToolsTotal(3) - 1; V:LayoutTools(); V:SyncTools()
		check(V.toolsLevel == 4 and V.btnMergeIcon:IsShown() and V.btnViewIcon:IsShown() and V.btnSort.label.text == "Quality", skin .. ": only narrower than that do the icons come in")
		V.tools.w = nil; V:LayoutTools()

		-- ---- both rows end at the window's edge, at every width
		for _, W in ipairs({ 440, 520, 620, 900, 1200 }) do
			sized(V, W)
			local tag = ("%s at %d"):format(skin, W)
			local _, rowR = span(V.title, V.frame)
			local tl, tr = span(V.tools, V.frame)
			local lastFrame
			for i = #V.toolItems, 1, -1 do if V.toolItems[i].frame:IsShown() then lastFrame = V.toolItems[i].frame; break end end
			local ll, lr = span(lastFrame, V.frame)
			local fl, fr = span(V.btnFilter, V.frame)
			local sl, sr = span(V.search, V.frame)
			check(math.abs(lr - tr) < 0.5 and math.abs(tr - rowR) < 0.5, tag .. ": the toolbar's last control ends at the window's inner edge (" .. fmt(lr) .. " / " .. fmt(rowR) .. ")")
			check(math.abs(fr - lr) < 0.5 and sr <= fl and sr - sl >= 100, tag .. ": Filter ends there too, the search box filling the row before it (" .. fmt(fr) .. ", search " .. fmt(sr - sl) .. " px)")
			local items = {}
			for _, it in ipairs(V.toolItems) do
				if it.frame:IsShown() then local l, r = span(it.frame, V.frame); items[#items + 1] = { l = l, r = r } end
			end
			table.sort(items, function(a, b) return a.l < b.l end)
			local clean = true
			for i = 2, #items do if items[i].l < items[i - 1].r - 0.01 then clean = false end end
			check(clean and items[1].l >= tl - 0.01, tag .. ": nothing in the toolbar overlaps (level " .. tostring(V.toolsLevel) .. ")")
		end

		-- ---- tabs: one row, the rest in the "»" menu
		for i = 1, 6 do n:SaveSheet("A fairly long sheet name " .. i) end
		V:SetSheet("All"); M.runTimers()
		local rowH = V.classicApplied and 30 or 22
		local function tabsAt(W)
			V.tabs.w = W; V:UpdateTabs()
			local shownIds, right, okInside = {}, 0, true
			for _, b in ipairs(V.tabButtons) do
				if b:IsShown() then
					shownIds[#shownIds + 1] = b.sheet
					local p = b.points[1]; local r = (p[4] or 0) + b:GetWidth()
					if r > right then right = r end
				end
			end
			for _, b in ipairs({ V.tabMore, V.tabAdd, V.tabAddTab, V.tabEdit, V.tabEditTab }) do
				if b and b:IsShown() then local r = (b.points[1][4] or 0) + b:GetWidth(); if r > right then right = r end end
			end
			return shownIds, right
		end
		local order = {}
		for _, id in ipairs(n.db.tabOrder) do
			local hiddenTab = false
			for _, h in ipairs(n.db.hiddenTabs) do if h == id then hiddenTab = true end end
			if not hiddenTab and (id ~= "GearSets" or (n.GearSets and n.GearSets:Available())) then order[#order + 1] = id end
		end
		for _, W in ipairs({ 416, 576, 700 }) do
			local ids, right = tabsAt(W)
			local tag = ("%s, tabs %d px"):format(skin, W)
			check(V.tabs:GetHeight() == rowH, tag .. ": one row (" .. tostring(V.tabs:GetHeight()) .. ")")
			check(right <= W + 0.01, tag .. ": the last tab ends inside the row (" .. fmt(right) .. ")")
			check(#V.tabFolded > 0 and V.tabMore:IsShown() and not (V.tabAdd:IsShown() or (V.tabAddTab and V.tabAddTab:IsShown())), tag .. ": the rest fold into \"»\"; the + steps aside")
			check(#ids + #V.tabFolded == #order and ids[1] == order[1] and V.tabFolded[#V.tabFolded] == order[#order], tag .. ": every tab is either shown or folded, in order")
			-- the menu
			V.tabMore:GetScript("OnClick")(V.tabMore)
			local items = n.menuFrame.items
			check(#items == #V.tabFolded + 1 and items[1].text == (n.TAB_LABEL[V.tabFolded[1]] or V.tabFolded[1]) and items[#items].text == "New Sheet...", tag .. ": its menu lists them, with New Sheet... at the bottom")
			n.menuFrame:Hide()
		end
		-- choosing a folded tab: it comes into view, at the end
		local ids = tabsAt(416)
		local pick = V.tabFolded[1]
		V:SetSheet(pick); M.runTimers()
		ids = tabsAt(416)
		local seen = false
		for _, id in ipairs(ids) do if id == pick then seen = true end end
		local _, right = tabsAt(416)
		check(seen and ids[#ids] == pick and right <= 416.01, skin .. ": the tab you're on always stays in view (" .. tostring(pick) .. "), and still fits")
		check(V.tabEdit:IsShown() or (V.tabEditTab and V.tabEditTab:IsShown()), skin .. ": a custom sheet keeps its pencil")
		V:SetSheet("All"); M.runTimers()
		-- room for everything: no "»", the + back
		local _, rightWide = tabsAt(3000)
		check(#V.tabFolded == 0 and not V.tabMore:IsShown() and (V.tabAdd:IsShown() or (V.tabAddTab and V.tabAddTab:IsShown())), skin .. ": with room for every tab, no \"»\" and the + is back")
		for i = 1, 6 do n:DeleteSheet("A fairly long sheet name " .. i) end
		V.tabs.w = nil; V:UpdateTabs()
	end
end)()
