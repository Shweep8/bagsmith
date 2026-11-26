;(function()
	-- ======== 1.8.0-beta5: special bags (a player's request via Shweep) ========
	-- A bag's kind comes from its item's class and subclass (Forever's types, from Shweep's probe). The free-slot count
	-- shows only slots anything fits in; a "+" and the Bags button's tooltip give the rest by kind. Each kind can glow
	-- inside its slots, in its own color, every glow off until turned on.
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[3] = 6; M.bagNames[3] = "Herb Pouch"
	M.sizes[4] = 4; M.bagNames[4] = "Light Quiver"
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
	M.put(3, 1, { id = 2447, name = "Peacebloom", q = 1, count = 3, class = 7, subclass = 9, type = "Tradeskill", sub = "Herb", price = 5 })
	M.put(3, 2, { id = 765, name = "Silverleaf", q = 1, count = 2, class = 7, subclass = 9, type = "Tradeskill", sub = "Herb", price = 5 })
	local types = { ["Herb Pouch"] = { 1, 2 }, ["Light Quiver"] = { 11, 2 }, ["Linen Bag"] = { 1, 0 } }
	local realInstant = C_Item.GetItemInfoInstant
	C_Item.GetItemInfoInstant = function(item)
		local name = type(item) == "string" and item:match("%[(.-)%]")
		local t = name and types[name]
		if t then return 1, "Container", "", "INVTYPE_BAG", 1, t[1], t[2] end
		return realInstant(item)
	end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()

	check(#n.BAG_KINDS == 12 and n.BAG_KIND.herb.class == 1 and n.BAG_KIND.herb.sub == 2 and n.BAG_KIND.quiver.class == 11
		and n.BAG_KIND.trinket.sub == 12 and n.BAG_KIND.fishing.sub == 9 and n.BAG_KIND.cooking.sub == 10, "the twelve kinds Forever defines, by class and subclass")
	check(n:BagKind(3) == "herb" and n:BagKind(4) == "quiver", "a Herb Pouch is a herb bag, a Light Quiver a quiver")
	check(n:BagKind(1) == nil and n:BagKind(0) == nil, "an ordinary bag and the backpack have no kind")
	check(n:IsReagentBag(5) and n:BagKind(5) == "reagent", "the reagent bag's slot is a reagent bag")
	check(n.bagInfo[3].kind == "herb" and n.bagInfo[4].kind == "quiver" and n.bagInfo[1].kind == nil, "the scan records each bag's kind")
	check(n:BagKindName("herb") == "Herb Bag" and n:BagKindName("fishing") == "Tackle Box", "names: the game's own when it has them, else English")
	n.BAG_KIND.herb.localName = nil
	_G.C_Item.GetItemSubClassInfo = function(c, s) if c == 1 and s == 2 then return "Kräutertasche" end end
	check(n:BagKindName("herb") == "Kräutertasche", "the game's translated name when it gives one")
	_G.C_Item.GetItemSubClassInfo = nil; n.BAG_KIND.herb.localName = nil

	-- the counts
	local g, gt, r, rt, special = n:FreeSlots()
	local wantG, wantGT = 0, 0
	for _, b in ipairs({ 0, 1, 2 }) do wantG, wantGT = wantG + n.bagInfo[b].free, wantGT + n.bagInfo[b].size end
	check(g == wantG and gt == wantGT, "general slots: the backpack and ordinary bags only: " .. g .. " / " .. gt)
	check(special and special.herb and special.herb.free == 4 and special.herb.total == 6 and special.quiver.free == 4 and special.quiver.total == 4,
		"the herb bag and the quiver counted by kind")
	check(rt == 6 and not special.reagent, "the reagent bag keeps its own count")

	n.Window:Show(); M.runTimers(); M.runTimers()
	local main = n.Window.main
	n:RefreshViews(true); M.runTimers()
	local txt = main.freeText.text or ""
	check(txt:find(("%d / %d"):format(wantG, wantGT), 1, true) and txt:find("+", 1, true), "the footer: the general count, then a quiet +: " .. txt)
	main.btnBags:GetScript("OnEnter")(main.btnBags)
	local lines = table.concat(GameTooltip.lines or {}, " | ")
	check(lines:find("Free slots") and lines:find(("Bags (anything fits) %d / %d"):format(wantG, wantGT), 1, true) and lines:find("Herb Bag 4 / 6", 1, true)
		and lines:find("Quiver 4 / 4", 1, true), "hovering the count lists the free slots by kind: " .. lines)
	-- (beta7 feedback, by design) alphabetical: Herb Bag before Quiver
	check(lines:find("Herb Bag") < lines:find("Quiver"), "in alphabetical order (Herb Bag, then Quiver)")
	-- with Show Help Tips off the breakdown still shows (it's information, not help)
	n:Set("helpTips", false)
	GameTooltip.lines = {}; GameTooltip.shown = false
	main.btnBags:GetScript("OnEnter")(main.btnBags)
	lines = table.concat(GameTooltip.lines or {}, " | ")
	check(GameTooltip.shown and lines:find("Herb Bag 4 / 6", 1, true), "Show Help Tips off: the breakdown still shows")
	n:Set("helpTips", true)

	-- the glow: off by default for every kind (seen in the bag windows, which show every slot)
	n.ui.bagWindows = true; n:RefreshViews(true); M.runTimers()
	check(n.Window.bagViews[3]:IsShown() and n.Window.bagViews[4]:IsShown(), "(setup) the herb bag's and the quiver's windows are open")
	local function cell(bag, slot) return n.Buttons.mirrors[n.Window.bagViews[bag].child][slot] end
	local function glowing(bag, slot) local b = cell(bag, slot); return b and b.bagGlow and b.bagGlow:IsShown() and true or false end
	local any = false
	for _, pool in pairs(n.Buttons.mirrors) do for _, b in pairs(pool) do if b.bagGlow and b.bagGlow:IsShown() then any = true end end end
	check(not any, "every glow is off until turned on")
	for _, k in ipairs(n.BAG_KINDS) do check(n.db["glow_" .. k.key] == false and n.db["glowColor_" .. k.key] == k.color, "(defaults) " .. k.key .. ": off, its own color") end
	n:Set("glow_herb", true); M.runTimers()
	-- (beta5 feedback, by design) each kind's items glow too unless that kind's own "Glow on ... Items Too" is off
	check(glowing(3, 4) and glowing(3, 1), "Herb Bag on: its empty slots and its items glow (items on by default)")
	-- (beta11, by design) empty and filled slots each choose (Inner Glow, Frame Color, Off)
	n:Set("glowFilled_herb", "off"); M.runTimers()
	check(glowing(3, 4) and not glowing(3, 1), "Filled Herb Bag Slots off: only its empty slots")
	check(not glowing(4, 1) and not glowing(1, 1), "a quiver (still off) and an ordinary bag don't")
	local hr, hg, hb = n:BagKindColor("herb")
	check(math.abs(hr - 0x6c / 255) < 1e-6 and math.abs(hb - 0x4f / 255) < 1e-6, "in the herb bag's default color")
	n:Set("glowColor_herb", "ff0000"); M.runTimers()
	check(select(1, n:BagKindColor("herb")) == 1 and select(2, n:BagKindColor("herb")) == 0, "a color of your own")
	n:Set("glowFilled_herb", "glow"); M.runTimers()
	check(glowing(3, 1) and glowing(3, 4), "and back to Inner Glow: the herbs glow again")
	n:Set("glowEmpty_herb", "off"); M.runTimers()
	check(glowing(3, 1) and not glowing(3, 4), "Empty Herb Bag Slots off: only the herbs")
	n:Set("glowEmpty_herb", "glow"); M.runTimers()
	check(n.db.glowFilled_quiver == "glow" and n.db.glowEmpty_quiver == "glow" and n.db.glowItems_quiver == nil, "every kind has its own empty and filled choices (Inner Glow); the old switch is gone")
	n.ui.bagWindows = false; main:SetPref("view", "list"); n:RefreshViews(true); M.runTimers()
	-- (1.8.0-beta12, by design, Shweep: "not seeing the bag indicators in list view") a herb bag item's row glows too
	local herbRow, otherRow = false, false
	for _, b in ipairs(n.Buttons.all) do
		if b:IsShown() and b.mode == "row" and b.bagGlow and b.bagGlow:IsShown() then
			if b.smithBag == 3 then herbRow = true else otherRow = true end
		end
	end
	check(herbRow and not otherRow, "List view: a herb bag item's row shows the indicator, an ordinary bag's doesn't")
	check((n.errors or 0) == 0, "no errors")

	-- saved: each bag's kind, so another character's footer splits its counts the same way
	n:SaveCache()
	local mine = BagSmithDB.cache[n:CharKey()]
	check(mine.bags["3"].kind == "herb" and mine.bags["4"].kind == "quiver" and mine.bags["1"].kind == nil, "the saved bags carry their kinds")
end)()

;(function()
	-- settings: a bad saved glow color or switch falls back to the default
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { glow_herb = "yes", glowColor_herb = "zz00zz", glowColor_soul = "#A0B0C0", glow_soul = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith")
	check(n.db.glow_herb == false and n.db.glowColor_herb == n.BAG_KIND.herb.color, "a bad switch or color: the defaults")
	check(n.db.glow_soul == true and n.db.glowColor_soul == "a0b0c0", "a good one is kept (the hex tidied)")

	-- no special bags: no +; (beta11, by design: Shweep couldn't find it) the breakdown still shows, bags and reagent bag
	M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local main = n.Window.main
	check(not (main.freeText.text or ""):find("+", 1, true), "no special bags: no +")
	GameTooltip.lines = {}
	main.btnBags:GetScript("OnEnter")(main.btnBags)
	local tl = table.concat(GameTooltip.lines or {}, " | ")
	check(tl:find("Bags (anything fits)", 1, true) and tl:find("Reagent Bag", 1, true), "but hovering the count still breaks it down: " .. tl)
	-- the Settings page shows the section
	n.SettingsPanel:Show(); n.SettingsPanel:ShowPage("icons"); M.runTimers()
	local seen = 0
	for _, w in ipairs(n.SettingsPanel.pools.check or {}) do if w:IsShown() and w.key and w.key:find("^glow_") then seen = seen + 1 end end
	-- (by design since 1.11.0-beta3, Shweep: "select which Special Bag to edit first ... and then the settings show up for
	-- it": a Special Bag list of the twelve kinds, and under it the picked kind's switch and settings only)
	local listed = 0
	for _, w in ipairs(n.SettingsPanel.pools.dropdown or {}) do if w:IsShown() and w.key == "bagKindPick" then listed = #w.choices end end
	check(listed == 12 and seen == 1, "Settings > Item Icons lists the twelve kinds, and shows the glow switch of the one picked: " .. listed .. ", " .. seen)
	-- a kind turned on shows its own items switch and color, each naming the kind
	n.SettingsPanel.bagKind = "herb"
	n:Set("glow_herb", true); n.SettingsPanel:Show(); n.SettingsPanel:ShowPage("icons"); M.runTimers()
	local itemsRow, colorRow
	for _, w in ipairs(n.SettingsPanel.pools.seg or {}) do if w:IsShown() and w.key == "glowFilled_herb" then itemsRow = w end end
	for _, w in ipairs(n.SettingsPanel.pools.color or {}) do if w:IsShown() and w.key == "glowColor_herb" then colorRow = w end end
	-- (beta9, by design) "indicator" wording (Shweep: an inner glow or a frame color)
	check(itemsRow and itemsRow.text.text == "Filled Herb Bag Slots", "its filled-slot choice names the kind: " .. tostring(itemsRow and itemsRow.text.text))
	check(colorRow and colorRow.text.text == "Herb Bag Indicator Color", "and so does its color: " .. tostring(colorRow and colorRow.text.text))
	local others = 0
	for _, w in ipairs(n.SettingsPanel.pools.seg or {}) do if w:IsShown() and w.key and w.key:find("^glowFilled_") then others = others + 1 end end
	check(others == 1, "only the kind picked shows its options (soul is on in this profile too, and has its own turn in the list): " .. others)
	n.SettingsPanel:Hide()
	n.SettingsPanel:Hide()
	check((n.errors or 0) == 0, "no errors")
end)()
