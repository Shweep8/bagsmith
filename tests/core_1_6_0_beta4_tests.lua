;(function()
	-- 1.6.0-beta4 (the 1.6.0 plan, agreed with Shweep on 9 Nov): narrower windows, and the approved Settings wording.
	--  * the bags window's minimum 620 -> 440 (both skins); the bank 620 -> 500 (its bag strip needs the room)
	--  * a fourth toolbar step: Sections as one button with a menu, Sort without "Sort:", Merge Stacks and List / Icons as
	--    icons; everything comes back as the window widens
	--  * List view sets aside Type, then Age, Vendor and AH Price as it narrows, and brings them back (saved widths kept)
	--  * the title row: the character picker narrows, the title shortens, the note after it is cut short
	--  * the footer's pinned currencies fold into "+N" first, and "+N" never covers the buttons on the right
	--  * anchor-following overlap checks at the minimum: every frame's place is worked out by following its anchors back
	--    to the window, so a row that moved because its anchor moved is caught (the layout snapshots can't see that)
	local function boot(skin, profile)
		package.loaded.mock = nil
		local M = require("mock")
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = skin, view = "list", grp = "type" }
		for k, v in pairs(profile or {}) do p[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
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
	local function overlaps(list)
		table.sort(list, function(a, b) return a.l < b.l end)
		for i = 2, #list do if list[i].l < list[i - 1].r - 0.01 then return list[i - 1].name .. " / " .. list[i].name end end
	end
	local function fmt(x) return x and ("%.0f"):format(x) or "?" end

	-- ---- minimum sizes and saved sizes
	local n, M, V = boot("modern")
	check(V.frame.resizeBounds and V.frame.resizeBounds[1] == 440, "the bags window can be dragged down to 440 px wide (was 620)")
	local B = n.Window.bank or (n.views and n.views.BagSmithBank)
	if not B then for _, v in pairs(n.views) do if v.isBank then B = v end end end
	check(B and B.frame.resizeBounds and B.frame.resizeBounds[1] == 500, "the bank window down to 500 (its bag strip needs the room)")
	n:Set("fixW", 400); check(n.db.fixW == 440, "a Width below 440 is raised to it (" .. tostring(n.db.fixW) .. ")")
	n:Set("maxW", 300); check(n.db.maxW == 440, "and so is Max Width")
	n:Set("fixW", 460); check(n.db.fixW == 460, "460 is kept")
	n:Set("bankW", 450); check(n.db.bankW == 500, "the bank's width below 500 is raised to it")
	check(n.View.MIN_W.main == 440 and n.View.MIN_W.bank == 500, "the minimums in one place")

	-- ---- the toolbar's narrowest step ((beta5, by design) the fifth: a step with the Sections menu came before it)
	for _, skin in ipairs({ "modern", "classic" }) do
		n, M, V = boot(skin)
		local full = V:ToolsTotal(0)
		check(V:ToolsTotal(4) <= 300, skin .. ": the narrowest toolbar needs about 300 px (" .. V:ToolsTotal(4) .. ")")
		check(V:ToolsTotal(4) < V:ToolsTotal(3) and V:ToolsTotal(3) < V:ToolsTotal(2) and V:ToolsTotal(2) < V:ToolsTotal(1) and V:ToolsTotal(1) < full, skin .. ": each step is narrower than the one before")
		V.tools.w = V:ToolsTotal(3) - 1; V:LayoutTools()
		check(V.toolsLevel == 4, skin .. ": too narrow for the fourth step: the fifth")
		check(V.btnGrpMenu:IsShown() and V.btnMergeIcon:IsShown() and V.btnViewIcon:IsShown() and V.btnSort:IsShown(), skin .. ": Sections button, Sort, Merge Stacks and List / Icons icons show")
		check(not V.btnMerge:IsShown() and not V.segBoxes[1]:IsShown() and not V.segBoxes[2]:IsShown(), skin .. ": the joined groups and the Merge Stacks button step aside")
		check(V.btnGrpMenu.label.text == "By Section" and V.btnSort.label.text == "Quality", skin .. ": the Sections button names the choice; Sort drops \"Sort:\" (" .. tostring(V.btnSort.label.text) .. ")")
		check(V.btnViewIcon.tex.texture:find("ui%-list") and V.btnViewIcon.tip == "List View", skin .. ": the view icon shows List")
		-- the Sections menu
		V.btnGrpMenu:GetScript("OnClick")(V.btnGrpMenu)
		local m = n.menuFrame
		local texts, checked = {}, nil
		for _, it in ipairs(m.items or {}) do texts[#texts + 1] = it.text; if it.checked then checked = it.text end end
		check(m:IsShown() and table.concat(texts, "|") == "All|By Section|By Bag" and checked == "By Section", skin .. ": its menu: All, By Section, By Bag, with the current one ticked")
		m.items[3].onClick(); m:Hide()
		check(V:Pref("grp") == "bag" and V.btnGrpMenu.label.text == "By Bag", skin .. ": choosing By Bag sets it and the button says so")
		-- the icons
		local merged = V:Pref("mergeStacks") and true or false
		V.btnMergeIcon:GetScript("OnClick")(V.btnMergeIcon)
		check((V:Pref("mergeStacks") and true or false) ~= merged and V.btnMergeIcon.active == (not merged), skin .. ": the Merge Stacks icon toggles it and lights while on")
		V.btnViewIcon:GetScript("OnClick")(V.btnViewIcon)
		check(V:Pref("view") == "icons" and V.btnViewIcon.tex.texture:find("ui%-grid") and V.btnViewIcon.tip == "Icons View", skin .. ": the view icon switches to Icons and shows it")
		V.btnViewIcon:GetScript("OnClick")(V.btnViewIcon)
		check(V:Pref("view") == "list", skin .. ": and back to List")
		-- widening brings everything back
		V.tools.w = full + 20; V:LayoutTools(); V:SyncTools()
		check(V.toolsLevel == 0 and V.btnMerge:IsShown() and V.segBoxes[1]:IsShown() and V.segBoxes[2]:IsShown() and V.btnMerge.label.text == "Merge Stacks", skin .. ": room for everything: the full toolbar again")
		check(not V.btnGrpMenu:IsShown() and not V.btnMergeIcon:IsShown() and not V.btnViewIcon:IsShown() and V.btnSort.label.text == "Sort: Quality", skin .. ": and the narrow controls hide; Sort says \"Sort:\" again")
		V.tools.w = nil; V:LayoutTools()
	end

	-- ---- anchor-following overlap checks at the minimum width (both skins; widest title row: gear sets and the helper)
	for _, skin in ipairs({ "modern", "classic" }) do
		M = nil
		package.loaded.mock = nil
		local MM = require("mock")
		MM.installEquipmentSets()
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, view = "list", grp = "type", deEnabled = true } } }
		n = MM.loadAddon("BagSmith")
		MM.fire("ADDON_LOADED", "BagSmith"); MM.fire("PLAYER_ENTERING_WORLD"); MM.runTimers(); MM.runTimers()
		n.Window:Show(); MM.runTimers(); MM.runTimers()
		V = n.Window.main
		local realMoney = _G.GetMoney
		_G.GetMoney = function() return 12345 * 10000 + 6789 end
		n.db.fav = { "c:3402", "c:1901", "i:20558" }
		V.charBtn:Show(); V:RefreshToolbar()
		for _, W in ipairs({ 440, 520, 620 }) do
			sized(V, W)
			local tag = ("%s at %d"):format(skin, W)
			-- the toolbar: inside its row, nothing overlapping
			local tl, tr = span(V.tools, V.frame)
			local items, inside = {}, true
			for _, it in ipairs(V.toolItems) do
				if it.frame:IsShown() then
					local l, r = span(it.frame, V.frame)
					items[#items + 1] = { l = l, r = r, name = it.frame.label and it.frame.label.text or it.frame.tip or "?" }
					if l < tl - 0.01 or r > tr + 0.01 then inside = false end
				end
			end
			check(inside and not overlaps(items), tag .. ": every toolbar control sits inside the row, none overlapping (" .. tostring(overlaps(items) or "none") .. ", level " .. tostring(V.toolsLevel) .. ")")
			if W == 440 then check(V.toolsLevel >= 3, tag .. ": the Sections menu step or narrower (" .. tostring(V.toolsLevel) .. ")") end
			-- the search row ends with the toolbar, inside the window
			local sl, sr = span(V.search, V.frame)
			local fl, fr = span(V.btnFilter, V.frame)
			check(sl and fl and sr <= fl and fr <= tr + 0.01 and sr - sl >= 100, tag .. ": the search box (" .. fmt(sr and sr - sl) .. " px) and Filter fit, Filter ending by the toolbar's end")
			-- the title row: everything on the left ends before the icons on the right begin
			local rightMost = math.huge
			for _, b in ipairs({ V.btnClean, V.btnDisenchant, V.btnGearSets, V.btnBank, V.btnCurrency, V.btnSettings }) do
				local l = span(b, V.frame); if l and l < rightMost then rightMost = l end
			end
			local leftEnd, parts = 0, {}
			local lefts = { V.charBtn }
			if not V.classicApplied then lefts[#lefts + 1] = V.titleText; lefts[#lefts + 1] = V.mark end
			if V.subText.shown then lefts[#lefts + 1] = V.subText end
			for _, r in ipairs(lefts) do local _, rr = span(r, V.frame); if rr and rr > leftEnd then leftEnd = rr end end
			check(leftEnd <= rightMost, tag .. ": the title row's left side (to " .. fmt(leftEnd) .. ") ends before its icons (from " .. fmt(rightMost) .. ")")
			check(V.charBtn:GetWidth() >= 110 and V.charBtn:GetWidth() <= 170, tag .. ": the character picker is 110 to 170 px (" .. fmt(V.charBtn:GetWidth()) .. ")")
			-- the footer: pinned currencies between the gold and the buttons
			local _, moneyR = span(V.moneyText, V.frame)
			local barL = span(V.btnBagBar, V.frame)
			local chipsOK = true
			for _, c in ipairs(V.favChips) do
				if c:IsShown() then local l, r = span(c, V.frame); if l < moneyR or r > barL then chipsOK = false end end
			end
			if V.favMore and V.favMore:IsShown() then local l, r = span(V.favMore, V.frame); if l < moneyR or r > barL then chipsOK = false end end
			check(chipsOK, tag .. ": pinned currencies and \"+N\" stay between the gold and the bag strip's button")
		end
		-- the narrowest window with a long note after the title: it's cut short, the picker keeps 110
		n.ui.filters.text = "x"
		V.subText:SetText("Someone, read only, saved bank, 12 of 80 shown")
		sized(V, 440)
		local leftEnd = select(2, span(V.subText.shown and V.subText or V.charBtn, V.frame))
		local _, cr = span(V.charBtn, V.frame)
		local rightMost = span(V.btnClean, V.frame)
		for _, b in ipairs({ V.btnDisenchant, V.btnGearSets }) do local l = span(b, V.frame); if l < rightMost then rightMost = l end end
		check(cr <= rightMost and V.charBtn:GetWidth() >= 110, skin .. " at 440 with a long note: the picker keeps 110 px and stays clear of the icons (" .. fmt(cr) .. " / " .. fmt(rightMost) .. ")")
		check(not V.subText.shown or (V.subText.width and V.subText.width > 0), skin .. ": the note is cut short (or hidden)")
		n.ui.filters.text = ""
		sized(V, 620)
		check(V.charBtn:GetWidth() == 170 or V.subText.width ~= nil, skin .. " at 620: the picker back to its full width")
		-- Travel Mode at the minimum: the search box keeps its room, the title shortens
		if not V.classicApplied then
			n:Set("travelMode", true); MM.runTimers(); MM.runTimers()
			V.subText:SetText("")
			sized(V, 440)
			local sl, sr = span(V.search, V.frame)
			local _, tEnd = span(V.titleText, V.frame)
			local cl = span(V.btnClean, V.frame)
			check(sl >= tEnd and sr <= cl and sr - sl >= 120, ("%s Travel Mode at 440: the search box (%s px) sits between the title (%q) and the icons"):format(skin, fmt(sr - sl), tostring(V.titleText.text)))
			check(V.titleText.text ~= "Your Bags (Travel Mode)", skin .. " Travel Mode at 440: the title shortens (" .. tostring(V.titleText.text) .. ")")
			sized(V, 900)
			check(V.titleText.text == "Your Bags (Travel Mode)", skin .. " Travel Mode at 900: the full title")
			n:Set("travelMode", false); MM.runTimers()
		end
		_G.GetMoney = realMoney; n.db.fav = {}
		MM.removeEquipmentSets()
	end

	-- ---- the title's forms
	n, M, V = boot("modern")
	local forms = V:TitleForms()
	check(table.concat(forms, "|") == "Your Bags|Bags", "the bags window's title: Your Bags, then Bags")
	V.st.sheet = "Bank"; forms = V:TitleForms(); V.st.sheet = "All"
	check(table.concat(forms, "|") == "Bank (Saved)|Bank", "the saved bank: Bank (Saved), then Bank")
	n:Set("travelMode", true); M.runTimers()
	check(table.concat(V:TitleForms(), "|") == "Your Bags (Travel Mode)|Your Bags|Bags", "Travel Mode: \"(Travel Mode)\" goes first")
	V.title.w = 600; V:LayoutTitleRow()
	check(V.titleText.text == "Your Bags (Travel Mode)", "with room, the full title, as before")
	n:Set("travelMode", false); M.runTimers()

	-- ---- List view sets columns aside as it narrows
	n, M, V = boot("modern", { cols = { "c", "t", "bd", "v", "w", "age", "fv", "cc", "jk", "ah" } })
	_G.Auctionator = nil
	local function planAt(rowW)
		V.scroll.w = rowW; V.trustedRowWidth = nil
		local plan = V:ColumnPlan()
		local keys = {}
		for _, c in ipairs(plan) do keys[#keys + 1] = c.key end
		return plan, table.concat(keys, ","), table.concat(plan.dropped or {}, ",")
	end
	local plan, keys, dropped = planAt(574)   -- the 620 window
	check(dropped == "" and keys == "c,n,t,bd,v,w,age,fv,cc,jk", "at 620 nothing is set aside: as before (" .. keys .. ")")
	plan, keys, dropped = planAt(394)         -- the 440 window
	check(dropped == "t" and not keys:find("t,", 1, true) and keys:find("age", 1, true), "at 440, Type is set aside first (" .. dropped .. ")")
	local w = 0; for _, c in ipairs(plan) do w = w + c.colW end
	check(math.abs(w - 394) < 1 and not plan.squeezed, "and the rest fit the row at their widths (" .. w .. ")")
	V:LayoutHeader(plan)
	check(not V.headerLabels.t:IsShown() and V.headerLabels.age:IsShown(), "the header hides Type and keeps Age")
	plan, keys, dropped = planAt(250)
	check(dropped == "t,age,v" and plan.squeezed ~= nil, "narrower still: Type, then Age, then Vendor (" .. dropped .. ")")
	plan, keys, dropped = planAt(900)
	check(dropped == "" and keys:find("t,", 1, true), "wide again: every column back")
	-- with an AH price source installed, AH Price is the last to go
	_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function() return 1 end, GetAuctionPriceByItemID = function() return 1 end, GetAuctionAgeByItemLink = function() return 1 end, GetAuctionAgeByItemID = function() return 1 end } } }
	n.db.colWidths = { w = 120, bd = 80 }
	n.db.colAside = { "t", "age", "v", "ah" }   -- (1.6.0-beta8, by design) beta4's order, now one player's choice (the default ticks every column)
	plan, keys, dropped = planAt(260)
	check(dropped == "t,age,v,ah", "AH Price goes last (" .. dropped .. ")")
	check(n.db.colWidths.w == 120 and n.db.colWidths.bd == 80 and n.db.colWidths.t == nil, "nothing saved changes")
	_G.Auctionator = nil

	-- ---- the approved Settings wording (9 Nov, all 54 items): a sample, read from the pages players see
	n, M, V = boot("modern", { newdot = true })
	local P = n.SettingsPanel
	P:Show(); M.runTimers()
	local function pageText(id)
		P:ShowPage(id); M.runTimers()
		local out = {}
		local function walk(f, depth)
			if depth > 6 or not f then return end
			for _, r in ipairs(f.regions or {}) do if r.text and r.text ~= "" then out[#out + 1] = r.text end end
			for _, c in ipairs(f.children or {}) do if c:IsShown() then walk(c, depth + 1) end end
		end
		for _, pool in pairs(P.pools) do for _, w in ipairs(pool) do if w:IsShown() then walk(w, 0) end end end
		return table.concat(out, "\n")
	end
	local SAMPLE = {
		{ "general", "Turn off to keep Blizzard's bags on B. You can still open BagSmith from the minimap button or /bs." },
		{ "general", "Which addon BagSmith gets auction prices from. Automatic uses the one you have, or Auctionator if you have both." },
		{ "general", "Stops BagSmith's hello in chat when you log in." },
		{ "look", "Shows sections side by side in two columns. Works with By Section or By Bag when the window is wide enough." },
		{ "icons", "Clearing your Recent Items also removes the green dots." },
		{ "icons", "Choose what shows in each corner of your item icons, with a backup for items the first choice doesn't apply to. In List view, item level and stack count have their own columns." },
		{ "automation", "Sells your grey and junk-marked items when you visit a vendor. You can buy back the last 12. Like Blizzard's own Sell All Junk, it includes grey favorites." },
		{ "automation", "Choose when BagSmith answers: always, or only while you hold Shift, Ctrl or a key you pick." },
		{ "loothelper", "Blue and purple items always ask first, as they do in the game." },
		{ "dehelper", "Estimates start from typical disenchant results. After 20 disenchants of the same kind of item, BagSmith uses your own results instead. Each character keeps its own." },
		{ "keys", "Click Set Key and press a key. Shift, Ctrl and Alt combinations work, and Esc cancels. These are also in the game's Keybindings under BagSmith." },
		{ "sections", "An item goes to the first of these that fits: its gear set, Junk if you marked it, Favorites if starred, the section you moved it to, or its usual section." },
		{ "custom", "Make your own sections. Drag an item onto a section's title, or Alt+Left-click it, to move it there. Every copy of the item moves with it." },
		{ "sorting", "Click a column header to sort by it. Click again to reverse the order." },
		{ "plugins", "Want to build on BagSmith? The guide and a starter example are in the docs/plugins folder of the source." },
	}
	local cache = {}
	for _, s in ipairs(SAMPLE) do
		cache[s[1]] = cache[s[1]] or pageText(s[1])
		check(cache[s[1]]:find(s[2], 1, true) ~= nil, "Settings > " .. s[1] .. " reads: " .. s[2])
	end
	check(cache.general:find("Now using", 1, true) or cache.general:find("is installed", 1, true), "Price Source still says which source is in use")
	local GONE = { "Turn off to use Blizzard's bags on B", "Tooltips that explain BagSmith's buttons", "Click any column header to sort by it; click again to flip the direction.", "Plugins work through a small public API" }
	local all = table.concat({ cache.general, cache.sorting, cache.plugins }, "\n")
	local stale
	for _, g in ipairs(GONE) do if all:find(g, 1, true) then stale = g end end
	check(stale == nil, "the old lines are gone (" .. tostring(stale) .. ")")
	P:Hide()
end)()
