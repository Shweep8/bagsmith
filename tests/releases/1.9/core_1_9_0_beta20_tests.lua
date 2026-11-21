-- ======== 1.9.0-beta20 (Shweep, 17 Nov) ========
-- The 1.9 What's New card: currencies with Global Inventory's "who has how many", and Text and Fonts (was Footer Text
-- Size), as Shweep approved ("yeah these are good"). Settings: "when you scroll in settings things scroll under the
-- header... a soft shadow or line there would help give the header some indication of existing": a line under the
-- header in the skin's line color, and a soft shadow under it once the page is scrolled.

local function boot(skin)
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin or "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	return n, M
end

;(function()
	-- the card
	local n = boot()
	local e = n.WhatsNew.ENTRIES[7]   -- (by design since 1.9.6: six places down, after 1.9.6's, 1.9.5's, 1.9.4's, 1.9.3's, 1.9.2's and 1.9.1's entries)
	check(e.v == "1.9.0" and #e.items == 7, "the 1.9 card: still seven bullets")
	check(e.items[1]:find("Click an item more than one character has to see how many each of them has, and the same goes for currencies in the currency drawer. Down at the bottom", 1, true),
		"Global Inventory: currencies too, the rest as before")
	check(e.items[5] == "|cfffac775Text and Fonts:|r make your gold, pinned currencies and free slots bigger or smaller on their own, in Settings > Style > Size. The font you pick there now shows on the buttons along the top of your bags too, and every font you have now shows up in the list.",
		"Text and Fonts, word for word as approved")
	local text = table.concat(e.items, " ")
	check(not text:find("Footer Text Size:", 1, true), "no Footer Text Size bullet of its own")
	check(not text:find("\226\128\148") and not text:find("\226\128\147"), "no em or en dashes")
	check((n.errors or 0) == 0, "no errors")
end)()

for _, skin in ipairs({ "modern", "classic" }) do
	local S = skin .. ": "
	local n, M = boot(skin)
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("look"); M.runTimers()
	local f = P.frame
	local shade, sf = f.headShade, P.scroll
	check(shade and shade.line and shade.fade, S .. "the header has its line and shadow")
	-- the line: under the header, at the page's top edge, across the window, in the side menu's divider color
	local p1 = { shade:GetPoint(1) }
	check(p1[1] == "TOPLEFT" and p1[2] == P.nav and p1[3] == "TOPLEFT" and p1[5] == 1, S .. "the line sits on the page's top edge, from the side menu's left")
	local p2 = { shade:GetPoint(2) }
	check(p2[1] == "TOPRIGHT" and p2[2] == sf and p2[4] == 22, S .. "and runs to the window's right, past the scroll bar")
	local lc, nc = shade.line.color or shade.line.colorTexture, P.nav.line.color or P.nav.line.colorTexture
	check(lc and nc and lc[1] == nc[1] and lc[2] == nc[2] and lc[3] == nc[3], S .. "in the skin's line color, as the side menu's divider")
	check(shade:GetFrameLevel() > sf:GetFrameLevel() + 20, S .. "drawn above the page's rows")
	-- the shadow: clear at the top of a page, in once scrolled
	check(shade.fade.alpha == 0, S .. "top of the page: no shadow")
	sf:SetVerticalScroll(6); sf:GetScript("OnVerticalScroll")(sf, 6)
	check(math.abs(shade.fade.alpha - 0.5) < 0.01, S .. "6 px down: half in (" .. tostring(shade.fade.alpha) .. ")")
	sf.GetVerticalScrollRange = function() return 800 end
	sf:SetVerticalScroll(0)
	sf:GetScript("OnMouseWheel")(sf, -1)
	check(shade.fade.alpha == 1, S .. "a notch of the wheel: the shadow in full")
	P:ShowPage("general"); M.runTimers()
	check(shade.fade.alpha == 0, S .. "another page, from its top: no shadow")
	sf:SetVerticalScroll(40); sf:GetScript("OnVerticalScroll")(sf, 40)
	P:SetQuery("font"); M.runTimers()
	check(shade.fade.alpha == 0, S .. "a search starts at the top: no shadow")
	P:SetQuery("")
	if skin == "modern" then
		-- Modern's band (Classic hides it): down to the line (its bottom 11 px under the title row, the page 12 under)
		local band
		for _, r in ipairs(P.classicSpec.hide or {}) do
			for _, q in ipairs(r.points or {}) do
				if q[1] == "BOTTOM" and q[5] == -11 then band = r end
			end
		end
		check(band ~= nil, S .. "the title band reaches down to the line")
	end
	check((n.errors or 0) == 0, S .. "no errors")
end
