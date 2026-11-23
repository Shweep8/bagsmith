;(function()
	-- ======== 1.8.0-beta12 (Shweep): click the gold to open the currency drawer; the reagent count's tooltip ========
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local main = n.Window.main
	check(main.moneyButton and main.moneyButton:GetScript("OnClick"), "the gold is a button")
	local function open() return n.Drawer.frame and n.Drawer.frame:IsShown() and true or false end
	check(not open(), "(setup) the currency drawer is closed")
	main.moneyButton:GetScript("OnClick")(main.moneyButton, "LeftButton"); M.runTimers()
	check(open(), "clicking the gold opens the currency drawer")
	main.moneyButton:GetScript("OnClick")(main.moneyButton, "LeftButton"); M.runTimers()
	check(not open(), "and clicking again closes it")
	GameTooltip.lines = {}
	main.moneyButton:GetScript("OnEnter")(main.moneyButton)
	local gl = table.concat(GameTooltip.lines or {}, " | ")
	check(GameTooltip.shown and gl:find("currency drawer", 1, true), "hovering the gold says so: " .. gl)
	-- the reagent count shows the same breakdown as the bags count
	n:RefreshViews(true); M.runTimers()
	GameTooltip.lines = {}; GameTooltip.shown = false
	main.btnReagent:GetScript("OnEnter")(main.btnReagent)
	local tl = table.concat(GameTooltip.lines or {}, " | ")
	check(GameTooltip.shown and tl:find("Bags (anything fits)", 1, true) and tl:find("Reagent Bag", 1, true), "hovering the reagent count: the free-slot breakdown: " .. tl)
	-- (by design since 1.9.1-beta1, Shweep: the bank's gold has the bags' gold tooltip) it still opens nothing: the drawer
	-- belongs to the bags window
	local bmb = n.Window.bank and n.Window.bank.moneyButton
	check(bmb == nil or bmb:GetScript("OnClick") == nil, "the bank window's gold opens nothing (the drawer belongs to the bags window)")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- (1.8.0-beta12, Shweep) the special bag indicators in List view, both skins: rows follow the Filled choice
	for _, weight in ipairs({ "normal", "bold" }) do
		for _, skin in ipairs({ "modern", "classic" }) do
			local S = skin .. " " .. weight .. ": "
			package.loaded.mock = nil
			local M = require("mock")
			M.sizes[3] = 6; M.bagNames[3] = "Herb Pouch"
			M.put(3, 1, { id = 2447, name = "Peacebloom", q = 2, count = 3, class = 7, subclass = 9, type = "Tradeskill", sub = "Herb", price = 5 })
			M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
			local realInstant = C_Item.GetItemInfoInstant
			C_Item.GetItemInfoInstant = function(item)
				if type(item) == "string" and item:find("%[Herb Pouch%]") then return 1, "Container", "", "INVTYPE_BAG", 1, 1, 2 end
				return realInstant(item)
			end
			_G.BagSmithCharDB = { version = 1, firstSeen = {} }
			_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, borderWeight = weight, view = "list", glow_herb = true } } }
			local n = M.loadAddon("BagSmith")
			M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
			n.Window:Show(); n:RefreshViews(true); M.runTimers(); M.runTimers()
			local herb, cloth = n.Buttons:Get(3, 1), n.Buttons:Get(0, 1)
			check(herb.mode == "row" and herb:IsShown(), S .. "(setup) the Peacebloom is a List row")
			check(herb.bagGlow and herb.bagGlow:IsShown() and not (cloth.bagGlow and cloth.bagGlow:IsShown()), S .. "Inner Glow on the herb bag item's row icon, not the cloth's")
			n:Set("glowFilled_herb", "frame"); M.runTimers()
			local hr = n:BagKindColor("herb")
			local frame
			if skin == "modern" then local e = herb.modernBorder and herb.modernBorder[1]; frame = e and e:IsShown() and e.color
			else frame = herb.qFrame:IsShown() and herb.qFrame.color end
			check(frame and math.abs(frame[1] - hr) < 1e-6 and not (herb.bagGlow and herb.bagGlow:IsShown()), S .. "Frame Color: the row icon's frame in the herb bag's color")
			if skin == "modern" and weight == "bold" then check(herb.borderThickness == 2 * n.Buttons.PixelSize(herb), S .. "special-bag rows use Bold weight") end
			n:Set("glowFilled_herb", "off"); M.runTimers()
			check(not (herb.bagGlow and herb.bagGlow:IsShown()), S .. "Filled off: nothing on the row")
			check((n.errors or 0) == 0, S .. "no errors")
		end
	end
end)()
