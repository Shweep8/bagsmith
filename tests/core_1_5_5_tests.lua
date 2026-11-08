;(function()
	-- 1.5.5 (Shweep): the header (search, Filter and the toolbar) didn't always fill the window on the first open of a
	-- session, until the window was resized; Icons view kept empty room for List view's column headers; and Travel
	-- Mode had no Collapse All Sections button (it lives in the toolbar, which Travel Mode hides).
	local function boot(skin, prof)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 3 })
		M.put(0, 2, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
		M.put(0, 3, { id = 118, name = "Minor Healing Potion", q = 1, count = 5, class = 0, subclass = 1, price = 5 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = skin or "modern" }
		for k, v in pairs(prof or {}) do p[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M
	end

	-- ---- 1: the header on the first open
	for _, skin in ipairs({ "modern", "classic" }) do
		local n, M = boot(skin)
		local V = n.Window.main
		local full, noLabels = V:ToolsTotal(0), V:ToolsTotal(1)
		V.tools.w = 0; V:LayoutTools()
		check(V.toolsLevel == 0 and V.btnMerge.label.text == "Merge Stacks", skin .. ": a width that reads 0 (not laid out yet) isn't taken as too narrow: the full header")
		-- the window opens; the real width arrives, but no size event fires (as on this client for a window built closed)
		V.tools.w = noLabels - 1
		n.Window:Show(); M.runTimers(); M.runTimers()
		check(V.toolsLevel == 2, skin .. ": opening the window lays the header out again for its real width (level " .. tostring(V.toolsLevel) .. ")")
		n.Window:Hide()
		V.tools.w = full + 20
		n.Window:Show(); M.runTimers(); M.runTimers()
		check(V.toolsLevel == 0 and V.btnMerge.label.text == "Merge Stacks", skin .. ": and every later open too: with room, the full header (level " .. tostring(V.toolsLevel) .. ")")
	end

	-- ---- 2: Icons view reclaims the column headers' room
	for _, skin in ipairs({ "modern", "classic" }) do
		local n, M = boot(skin, { view = "icons" })
		local V = n.Window.main
		n.Window:Show(); M.runTimers(); M.runTimers()
		local function top(view) local p = view.scroll.points[1]; return p[2], p[3], p[5] end
		local rel, rp, y = top(V)
		check(rel == V.header and rp == "TOPLEFT" and (y or 0) == 0, skin .. ": Icons view: the list starts where the column headers would (" .. tostring(rp) .. ", " .. tostring(y) .. ")")
		V:SetPref("view", "list"); V:Refresh(true); M.runTimers(); M.runTimers()   -- (forced: the mock holds a plain refresh as if the pointer were over the window)
		rel, rp, y = top(V)
		check(V.header:IsShown() and rel == V.header and rp == "BOTTOMLEFT" and y == -2, skin .. ": List view: below the column headers, as before")
		V:SetPref("view", "icons"); V:Refresh(true); M.runTimers(); M.runTimers()
		rel, rp = top(V)
		check(not V.header:IsShown() and rp == "TOPLEFT", skin .. ": back to Icons: the room is reclaimed again")
		n:Set("travelMode", true); M.runTimers(); M.runTimers()
		rel, rp = top(V)
		check(rp == "TOPLEFT", skin .. ": Icons view in Travel Mode reclaims it too")
		n:Set("travelMode", false); M.runTimers()
		M.fire("BANKFRAME_OPENED"); M.runTimers(); M.runTimers()
		local bk = n.Window.bank
		if bk and bk.scroll then
			rel, rp = top(bk)
			check(rp == "TOPLEFT" or bk:Pref("view") == "list", skin .. ": the bank in Icons view reclaims it too")
		end
	end

	-- ---- 3: Collapse All Sections in Travel Mode, at the right end of the search box
	for _, skin in ipairs({ "modern", "classic" }) do
		local n, M = boot(skin, { grp = "type" })
		local V = n.Window.main
		n.Window:Show(); M.runTimers(); M.runTimers()
		local T = V.btnLanesTravel
		check(T and not T:IsShown(), skin .. ": outside Travel Mode the twin button is hidden (the toolbar has its own)")
		n:Set("travelMode", true); M.runTimers(); M.runTimers()
		check(T and T:IsShown() and not V.tools:IsShown(), skin .. ": in Travel Mode, with sections, it shows")
		local sp
		for _, p in ipairs(V.search.points) do if p[1] == "RIGHT" then sp = p end end
		local tp = T and T.points[1]
		check(sp and sp[2] == T and sp[3] == "LEFT", skin .. ": the search box ends at the button's left (the button is on its right)")
		check(tp and tp[2] == V.btnClean and tp[3] == "LEFT", skin .. ": and the button sits just before the Clean Up broom")
		check(T and T.tip == V.btnLanes.tip and T.tip == "Collapse All Sections", skin .. ": it says what the toolbar's says (" .. tostring(T and T.tip) .. ")")
		if T then T:GetScript("OnClick")(T) end; M.runTimers(); M.runTimers()
		check(T and T.tip == "Expand All Sections" and V.btnLanes.tip == "Expand All Sections", skin .. ": clicking it collapses every section, and it turns into Expand All")
		if T then T:GetScript("OnClick")(T) end; M.runTimers(); M.runTimers()
		check(T and T.tip == "Collapse All Sections", skin .. ": and clicking again expands them")
		n:Set("travelMode", false); M.runTimers(); M.runTimers()
		check(T and not T:IsShown() and V.tools:IsShown(), skin .. ": leaving Travel Mode hides it again")
		-- no sections to collapse: no button, the search box reaches the broom as before
		n, M = boot(skin, { grp = "none" })
		V = n.Window.main
		n.Window:Show(); M.runTimers(); M.runTimers()
		n:Set("travelMode", true); M.runTimers(); M.runTimers()
		T = V.btnLanesTravel
		sp = nil
		for _, p in ipairs(V.search.points) do if p[1] == "RIGHT" then sp = p end end
		check(T and not T:IsShown() and sp and sp[2] == V.btnClean, skin .. ": with no sections, no button, and the search box reaches the broom")
		n:Set("travelMode", false); M.runTimers(); M.runTimers()
		n.Window:Hide(); n.Window:Show(); M.runTimers(); M.runTimers()
		check(not V.btnLanes:IsShown(), skin .. ": and the toolbar's own Collapse All Sections stays hidden when the header is laid out again on open")
	end
end)()
