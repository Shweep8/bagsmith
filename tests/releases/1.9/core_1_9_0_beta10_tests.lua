-- (by design since 1.10.0-beta12: the 1.10 card leads What's New, so every older entry is one place further down)
-- ======== 1.9.0-beta10 (Shweep, 17 Nov) ========
-- Settings: an icon for each main page (Shweep's concepts, drawn twice), a title with its icon at the top of each main
-- page, every Settings icon in the accent color, dimmed ("maybe 80-50%"), the open page's at full strength. The Total
-- row's sums read "V:" and "AH:". The What's New card: "ruleset", and the tooltip bullet about tooltips and alts.
local function boot(skin)
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin or "modern", view = "list" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	return n, M, n.Window.main
end

;(function()
	for _, skin in ipairs({ "modern", "classic" }) do
		local S = skin .. ": "
		local n, M = boot(skin)
		local P = n.SettingsPanel
		P:Show(); P:ShowPage("general")
		local by = {}
		for _, b in ipairs(P.navButtons) do by[b.page] = b end
		local main = { general = "general", look = "style", icons = "icons", window = "windows", sections = "sections", columns = "columns",
			sheets = "sheets", sorting = "filter", automation = "auto", keys = "keys", plugins = "plugins", profile = "profile", advanced = "advanced" }
		local all = true
		for page, f in pairs(main) do
			local b = by[page]
			if not (b and b.icon and tostring(b.icon.texture):find("ui%-set%-" .. f .. "%.tga")) then all = false; check(false, S .. page .. ": its icon") end
		end
		check(all, S .. "each of the 13 main pages has its icon in the list")
		-- the accent, dimmed; the open page's at full strength
		local ar, ag, ab = n.Skins:Accent()
		local on, off = by.general.icon.color or {}, by.look.icon.color or {}
		check(on[1] == ar and on[2] == ag and on[3] == ab and on[4] == 1, S .. "the open page's icon: the accent, full")
		check(off[1] == ar and off[4] == P.ICON_DIM and P.ICON_DIM >= 0.5 and P.ICON_DIM <= 0.8, S .. "the others: the accent, dimmed (" .. tostring(off[4]) .. ")")
		-- a title with its icon at the top of a main page, snug above the first section
		local title
		for _, t in ipairs(P.pools.pagetitle) do if t:IsShown() then title = t end end
		check(title and title.text.text == "General" and tostring(title.icon.texture):find("ui%-set%-general") and (title.icon.color or {})[4] == 1, S .. "General's title, with its icon")
		local top
		for _, h in ipairs(P.pools.head) do if h:IsShown() then local y = -select(5, h:GetPoint(1)); if not top or y < top then top = y end end end
		local ty = -select(5, title:GetPoint(1))
		check(top and top - ty <= 20, S .. "the first section right under it (" .. tostring(top and top - ty) .. " px)")
		-- not on a page under another (its first heading has its icon), nor while searching
		P:ShowPage("bagcols")
		local shown = false
		for _, t in ipairs(P.pools.pagetitle) do if t:IsShown() then shown = true end end
		check(not shown, S .. "Bag Columns: no title (its heading has the icon)")
		local hc
		for _, h in ipairs(P.pools.head) do if h:IsShown() and h.icon and h.icon:IsShown() then hc = h.icon.color end end
		check(hc and hc[1] == ar and hc[4] == P.ICON_DIM, S .. "a heading's icon: the accent, dimmed")
		P:SetQuery("bag")
		shown = false
		for _, t in ipairs(P.pools.pagetitle) do if t:IsShown() then shown = true end end
		check(not shown, S .. "searching: no title")
		P:SetQuery("")
		check((n.errors or 0) == 0, S .. "no errors")
	end
	for _, f in ipairs({ "general", "style", "icons", "windows", "sections", "columns", "sheets", "filter", "auto", "keys", "plugins", "profile", "advanced" }) do
		local h = io.open("BagSmith/Media/ui-set-" .. f .. ".tga", "rb")
		local head = h and h:read(18)
		if h then h:close() end
		-- (by design since 1.9.5-beta1: stored compressed, type 10, or plainly, type 2)
		check(head and (head:byte(3) == 2 or head:byte(3) == 10) and head:byte(13) == 64 and head:byte(15) == 64 and head:byte(17) == 32, "ui-set-" .. f .. ".tga: 64x64, 32-bit")
	end
end)()

;(function()
	-- the Total row: "V:" and "AH:"
	local n, M, V = boot()
	n.AH.Available = function() return true end
	n.AH.StackValue = function(_, r) return 100 * (r.count or 1) end
	V.btnGlobal:GetScript("OnClick")(V.btnGlobal); M.runTimers(); M.runTimers()
	local T = V.totalRow
	check(tostring(T.cells.v.text):find("^V: ") and tostring(T.cells.ah.text):find("^AH: "), "the sums read V: and AH:, as section headers write theirs")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- What's New: Shweep's rewording
	local n = boot()
	local e = n.WhatsNew.ENTRIES[11]   -- (by design since 1.9.8: eight places down, after 1.9.8's, 1.9.7's, 1.9.6's, 1.9.5's, 1.9.4's, 1.9.3's, 1.9.2's and 1.9.1's entries)   -- (by design since 1.10.1: one more place down, after 1.10.1's entry)
	check(e.items[1]:find("on this ruleset", 1, true) and not e.items[1]:find("realm", 1, true), "Global Inventory: \"ruleset\", not \"realm\"")
	check(e.items[1]:find("Down at the bottom, the Total tells you what it's all worth.", 1, true), "its last sentence, reworded")
	check(e.items[2]:find("^|cfffac775Alts in Your Tooltips:|r") and e.items[2]:find("you and your alts", 1, true) and e.items[2]:find("Settings > General > Tooltips", 1, true),
		"the tooltip bullet: about tooltips and alts")
	check(not table.concat(e.items, " "):find("\226\128\148"), "no em dashes")
	check((n.errors or 0) == 0, "no errors")
end)()
