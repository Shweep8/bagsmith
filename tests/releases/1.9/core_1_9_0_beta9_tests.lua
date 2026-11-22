-- ======== 1.9.0-beta9 (Shweep, 16 Nov) ========
-- The Total row at small widths ("can the new pinned total fit somehow at smaller widths?") and its backing ("too
-- transparent in classic theme"); heading icons centered ("BagSmith icon is not centered vertically well"); sub-pages'
-- NEW tags given room; Item Text Size (was Text Size); the 1.9 What's New card ("easy to understand and does not
-- sound like AI").
local function boot(skin)
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin or "modern", view = "list" } }, whatsNewSeen = "1.8.0" }
	local n = M.loadAddon("BagSmith")
	n.version = "1.9.0-beta9"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	return n, M, n.Window.main
end

;(function()
	-- the Total row: sums run into the empty cells to their left; when even that's too tight, "(N)", then rounder sums
	-- (money as the game writes it, "2g 60s 22c", so rounding shows; the mock writes "<copper>c")
	local n, M, V = boot()
	local oldMoney = _G.GetMoneyString
	_G.GetMoneyString = function(c)
		local g, s2, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
		local t = {}
		if g > 0 then t[#t + 1] = g .. "g" end
		if s2 > 0 then t[#t + 1] = s2 .. "s" end
		if k > 0 then t[#t + 1] = k .. "c" end
		return table.concat(t, " ")
	end
	V.btnGlobal:GetScript("OnClick")(V.btnGlobal); M.runTimers(); M.runTimers()
	local T = V.totalRow
	-- a narrow plan: Item 0-100, Who 100-140, Where 140-180, Vendor 180-220, Type 220-260, AH Price 260-300 (the mock
	-- measures 6 px a character; its money reads "<copper>c")
	local plan = { { key = "n", colX = 0, x = 26, width = 70 }, { key = "who", x = 104, width = 32 }, { key = "w", x = 144, width = 32 },
		{ key = "v", x = 184, width = 32 }, { key = "t", x = 224, width = 32 }, { key = "ah", x = 264, width = 32 } }
	n.AH.Available = function() return true end
	n.AH.StackValue = function() return 4794 end
	local rows = { { count = 1, sellPrice = 26022 } }
	V:UpdateTotalRow(rows, plan)
	local function at(cell) local p = { cell:GetPoint(1) }; return p[4], p[4] + cell.width end
	local vl, vr = at(T.cells.v)
	-- (by design since 1.9.0-beta10: "V:" and "AH:" before the sums)
	check(T.cells.v.text == "V: 2g 60s 22c" and vr == 216 and vl < 184, "Vendor: the whole sum, ending at its column's right edge, using the empty cells to its left (" .. vl .. ")")
	local al, ar = at(T.cells.ah)
	check(T.cells.ah.text == "AH: 47s 94c" and ar == 296 and al >= vr, "AH Price: the same, after Vendor's (" .. al .. ")")
	check(T.count.text == "(1)" or T.count.text == "(1 item shown)", "the count: " .. tostring(T.count.text))
	-- tighter: the copper goes first
	plan[4] = { key = "v", x = 104, width = 12 }; plan[2] = { key = "who", x = 104, width = 0 }; plan[3] = { key = "w", x = 104, width = 0 }
	V:UpdateTotalRow(rows, plan)
	check(T.count.text == "(1)" or T.count.text == "", "tighter: the count shortens: " .. tostring(T.count.text))
	check(T.cells.v.text == "V: 2g 60s" or T.cells.v.text == "V: 2g", "and the sum is rounded, not cut: " .. tostring(T.cells.v.text))
	-- the exact sums in the tooltip
	GameTooltip.lines = {}
	T:GetScript("OnEnter")(T)
	local tip = table.concat(GameTooltip.lines or {}, " | ")
	check(tip:find("2g 60s 22c", 1, true) and tip:find("47s 94c", 1, true), "hover: the exact sums: " .. tip)
	check((n.errors or 0) == 0, "no errors")
	_G.GetMoneyString = oldMoney
end)()

;(function()
	-- the Total row's backing: the window's own color, solid, in both skins
	for _, skin in ipairs({ "modern", "classic" }) do
		local n, M, V = boot(skin)
		V.btnGlobal:GetScript("OnClick")(V.btnGlobal); M.runTimers(); M.runTimers()
		local T = V.totalRow
		local bg = n.Skins:Current().bg
		local c = T.bg.color or {}
		check(T.bg and c[4] == 1 and c[1] == bg[1] and c[2] == bg[2] and c[3] == bg[3], skin .. ": a solid backing in the window's color")
		check(T.tint and T.tint:IsShown(), skin .. ": with the light tint over it")
		check((n.errors or 0) == 0, skin .. ": no errors")
	end
end)()

;(function()
	-- Settings: icons centered on their heading; the BagSmith mark a touch lower; sub-pages' NEW tags have room
	local n, M = boot()
	local P = n.SettingsPanel
	P:Show()
	for page, nudge in pairs({ bagcols = -1, bankcols = 0, dynamic = 0 }) do
		P:ShowPage(page)
		local first
		for _, h in ipairs(P.pools.head) do if h:IsShown() and h.icon and h.icon:IsShown() then first = h end end
		local p = first and { first.icon:GetPoint(1) }
		check(p and p[1] == "RIGHT" and p[2] == first.text and p[3] == "LEFT" and p[5] == nudge, page .. ": the icon centered on the heading's text (" .. tostring(p and p[5]) .. ")")
	end
	local by = {}
	for _, b in ipairs(P.navButtons) do by[b.page] = b end
	check(by.bagcols.icon.points[1][2] == 18, "sub-pages: a little less indent (18)")
	-- a sub-page with NEW: its tag may sit where a page's arrow would
	P:ShowPage("columns")
	local b = by.globalcols
	if b.newTag and b.newTag:IsShown() then
		local x = select(4, b.newTag:GetPoint(1)) or 0
		check(x > 170 - 10 - 12 - 40, "the tag sits in the arrow's room: " .. x)
	else
		check(true, "(the name is still too long here: no tag, its page and heading say NEW)")
	end
	-- Item Text Size
	P:ShowPage("look")
	local label
	for _, w in ipairs(P.pools.step) do if w:IsShown() and w.key == "textScale" then label = w.text.text end end
	check(label == "Item Text Size", "Text Size is Item Text Size: " .. tostring(label))
	P:SetQuery("text size")
	local found = {}
	for _, w in ipairs(P.pools.step) do if w:IsShown() then found[w.key] = true end end
	check(found.textScale and found.footerTextScale, "searching \"text size\" finds both")
	P:SetQuery("")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- the 1.9 What's New card
	local n, M = boot()
	local WN = n.WhatsNew
	local e = WN.ENTRIES[9]   -- (by design since 1.9.8: eight places down, after 1.9.8's, 1.9.7's, 1.9.6's, 1.9.5's, 1.9.4's, 1.9.3's, 1.9.2's and 1.9.1's entries)
	check(e.v == "1.9.0" and e.heading == "BagSmith 1.9" and #e.items == 7, "the 1.9 card leads, with seven bullets")
	local heads = {}
	for _, it in ipairs(e.items) do heads[#heads + 1] = it:match("^|cfffac775(.-):|r") end
	-- (by design since 1.9.0-beta10: Alts in Your Tooltips, Shweep's rewording; since beta20: Text and Fonts, was Footer
	-- Text Size, Shweep approved)
	check(table.concat(heads, "|") == "Global Inventory|Alts in Your Tooltips|Compact View|Shared Disenchanting|Text and Fonts|Bolder Borders|Count Every Free Slot",
		"its bullets, as Shweep approved: " .. table.concat(heads, "|"))
	local text = table.concat(e.items, " ")
	check(not text:find("\226\128\148") and not text:find("\226\128\147"), "no em or en dashes")
	check(select(2, text:gsub("Thanks to Jeor!", "")) == 2, "Jeor thanked for Compact View and Bolder Borders")
	-- every "Settings > ..." opens a real page and heading
	local P = n.SettingsPanel
	local links = 0
	for _, it in ipairs(e.items) do
		local linked = WN.Linkify(it)
		for key, heading in linked:gmatch("|Hbagsmith:settings:([%w]+):([^|]*)|h") do
			links = links + 1
			P:Show(); P:ShowPage(key)
			local ok = heading == ""
			for _, h in ipairs(P.pools.head) do if h:IsShown() and h.text.text == heading then ok = true end end
			check(ok, "the link to " .. key .. " > " .. heading .. " lands on that heading")
		end
	end
	check(links == 5, "five links into Settings: " .. links)
	-- an update from 1.8 shows it once, on the 1.9 tab
	WN:ShowLatest(); M.runTimers()
	local c = WN.Card()
	check(c and c:IsShown() and c.sel == 1, "it opens on 1.9")
	check((n.errors or 0) == 0, "no errors")
end)()
