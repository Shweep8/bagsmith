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
;(function()
	-- ======== 1.9.0-beta5 (Shweep, 16 Nov): Global Inventory, simpler ========
	-- "What if we just only have the accordion view and simplify this": beta4's All Rows is gone. "disabled buttons, tabs
	-- etc, need tooltips explaining not available in global inventory": Merge Stacks, Icons, Gear Sets (its tab shown,
	-- not hidden), the bag bar and the bag windows are greyed, each saying so and why, and the game runs a disabled
	-- button's hover only when asked (beta4's reasons were never seen). "worth about should show V and AH stack (if you
	-- can) if window narrows".
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, profiles = { Default = { view = "icons", mergeStacks = true } },
		globalInv = { sort = "name", grp = "type", rows = true, allRealms = false },   -- a beta4 player with All Rows on
		cache = {
		["Brannoc - Forever"] = { name = "Brannoc", realm = "Forever", class = "PRIEST", level = 20,
			items = { { bag = 0, slot = 1, itemID = 2589, count = 3, name = "Linen Cloth", quality = 1, sellPrice = 10, link = "|Hitem:2589|h[Linen Cloth]|h" } },
			bank = { { bag = 6, slot = 1, itemID = 2589, count = 2, name = "Linen Cloth", quality = 1, sellPrice = 10, link = "|Hitem:2589|h[Linen Cloth]|h" } } },
	} }
	local oldES = _G.C_EquipmentSet   -- a client with equipment sets, so Gear Sets shows
	_G.C_EquipmentSet = { GetEquipmentSetIDs = function() return {} end, GetEquipmentSetInfo = function() end, GetItemLocations = function() end, UseEquipmentSet = function() end }
	local n = M.loadAddon("BagSmith"); n.SettingsPanel.NEW = NEW19()
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	check(BagSmithDB.globalInv.rows == nil, "a saved All Rows is dropped at load")
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V = n.Window.main
	V.btnGlobal:GetScript("OnClick")(V.btnGlobal); M.runTimers(); M.runTimers()
	local linen = {}
	for _, r in ipairs(V:Filtered()) do if r.itemID == 2589 then linen[#linen + 1] = r end end
	check(#linen == 1 and linen[1].count == 10 and linen[1].globalKids and #linen[1].globalKids == 2, "one row per item, opening into each character's (the accordion only)")

	-- every greyed control: disabled, its hover still runs, the tooltip names it and says why
	local OFF = n.View.GLOBAL_OFF
	check(OFF == "Not available in Global Inventory", "the words: " .. tostring(OFF))
	local function tab(id) for _, b in ipairs(V.tabButtons) do if b:IsShown() and b.sheet == id then return b end end end
	local icons
	for _, b in ipairs(V.viewSegBtns or {}) do if b.value == "icons" then icons = b end end
	local list
	for _, b in ipairs(V.viewSegBtns or {}) do if b.value == "list" then list = b end end
	local controls = {
		{ "Merge Stacks", V.btnMerge, "each item once" }, { "Merge Stacks (icon)", V.btnMergeIcon, "each item once" },
		{ "Icons", icons, "is a list" }, { "Icons (icon)", V.btnViewIcon, "is a list" },
		{ "Gear Sets icon", V.btnGearSets, "Gear sets" }, { "Gear Sets tab", tab("GearSets"), "Gear sets" },
		{ "bag bar", V.btnBagBar, "bag bar" }, { "bag windows", V.btnBags, "Bag windows" }, { "reagent bag", V.btnReagent, "Bag windows" },
	}
	n:Set("helpTips", false)   -- information, not help: shown either way
	for _, c in ipairs(controls) do
		local name, b, why = c[1], c[2], c[3]
		if b then
			GameTooltip:Hide(); GameTooltip.lines = {}
			local ran = M.enter(b)
			local lines = table.concat(GameTooltip.lines or {}, " | ")
			check(not b:IsEnabled() and b:GetAlpha() < 1, name .. ": greyed and disabled")
			check(ran and GameTooltip:IsShown() and lines:find(OFF, 1, true) and lines:find(why, 1, true), name .. ": its tooltip says so and why: " .. lines)
		else
			check(false, name .. ": missing")
		end
	end
	n:Set("helpTips", true)
	check(list and list.active and list:IsEnabled(), "View: List chosen, and usable")
	check(tab("GearSets") ~= nil, "the Gear Sets tab is shown (beta4 hid it)")
	tab("GearSets"):GetScript("OnClick")(tab("GearSets"))
	check(V.st.sheet ~= "GearSets", "and can't open")

	-- (Shweep: "right clicking a section header in global shows a menu that makes no sense") no section menu, no dragging
	local menus = 0
	local oldMenu = n.Sections.SectionMenu
	n.Sections.SectionMenu = function() menus = menus + 1 end
	local h
	for _, x in ipairs(V.used) do if x.laneId and x.text and x:IsShown() and x.laneId:sub(1, 1) ~= "~" then h = x end end
	check(h ~= nil, "(setup) a section header in Global Inventory")
	h:GetScript("OnClick")(h, "RightButton")
	check(menus == 0, "right-click: no section menu (its every entry changes your profile)")
	h:GetScript("OnDragStart")(h)
	check(n.dragLane == nil, "and no dragging to reorder")
	local id = h.laneId
	h:GetScript("OnClick")(h, "LeftButton"); M.runTimers()
	check(n.IndexOf(n.Inventory:Settings().collapsed, id), "a click still collapses it")
	h:GetScript("OnClick")(h, "LeftButton"); M.runTimers()

	-- (by design since 1.9.0-beta8, Shweep: the note "is getting lost") the worth is a Total row under the Vendor and AH
	-- Price columns, not a note beside the title (the stacking that note needed is gone with it)
	n.AH.Available = function() return true end
	n.AH.StackValue = function(_, r) return 100 * (r.count or 1) end
	n:RefreshViews(true); M.runTimers()
	local T = V.totalRow
	check(T and T:IsShown() and T.cells.v:IsShown() and T.cells.ah:IsShown() and not (V.subText.text or ""):find("V: ", 1, true),
		"the worth: a Total row with Vendor and AH, no note by the title")
	n.AH.Available = function() return false end
	n:RefreshViews(true); M.runTimers()
	check(T.cells.v:IsShown() and not T.cells.ah:IsShown(), "no price source: Vendor only")

	-- leaving: everything usable again, tooltips as before
	V.btnGlobal:GetScript("OnClick")(V.btnGlobal); M.runTimers(); M.runTimers()
	for _, c in ipairs(controls) do
		local name, b = c[1], c[2]
		if b then
			check(b:IsEnabled() and b:GetAlpha() == 1 and b.offReason == nil, "left Global Inventory: " .. name .. " usable again")
		end
	end
	h = nil
	for _, x in ipairs(V.used) do if x.laneId and x.text and x:IsShown() and x.laneId:sub(1, 1) ~= "~" then h = x end end
	h:GetScript("OnClick")(h, "RightButton")
	check(menus == 1, "outside it, right-click opens the section menu as before")
	n.Sections.SectionMenu = oldMenu
	GameTooltip.lines = {}
	M.enter(V.btnMerge)
	check(not table.concat(GameTooltip.lines or {}, " "):find(OFF, 1, true), "Merge Stacks' tooltip is its own again")
	check(V:Pref("view") == "icons" and V:Pref("mergeStacks") == true, "your bags as they were")
	check((n.errors or 0) == 0, "no errors")
	_G.C_EquipmentSet = oldES
end)()

;(function()
	-- Icon Layout (Jeor's compact layout, as a 3-way button) is NEW in 1.9, and Global Inventory stays a list whatever it is
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { view = "icons", grp = "type", compactCategories = true } }, whatsNewSeen = "1.8.0" }
	local n = M.loadAddon("BagSmith"); n.SettingsPanel.NEW = NEW19()
	n.version = "1.9.0-beta5"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	check(n.SettingsPanel:IsNew("keys", "iconLayout"), "Icon Layout is NEW in 1.9")
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V = n.Window.main
	check(V.compactCategories == true, "(setup) Compact View in your bags")
	V.btnGlobal:GetScript("OnClick")(V.btnGlobal); M.runTimers(); M.runTimers()
	check(V:Pref("view") == "list" and not V.compactCategories, "Global Inventory: a list, Compact View doesn't apply")
	V.btnGlobal:GetScript("OnClick")(V.btnGlobal); M.runTimers(); M.runTimers()
	check(V.compactCategories == true, "back: Compact View again")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- (Shweep: "not seeing a Global button in Classic Style ... globe goes beside the Travel Mode in Classic") in Classic
	-- the signpost goes up beside the red close button, and the globe with it, but it stayed Modern-styled at the title's
	-- level, hidden behind the strip's art. It's a red button like the signpost now, drawn above the art.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "classic" } } }
	local n = M.loadAddon("BagSmith"); n.SettingsPanel.NEW = NEW19()
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V = n.Window.main
	local G = V.btnGlobal
	check(V.classicApplied, "(setup) Classic")
	check(G:IsShown() and select(2, G:GetPoint(1)) == V.btnTravel, "Classic: the globe beside the signpost, in the title strip")
	check(G.redOn and G:GetWidth() == V.btnTravel:GetWidth(), "a red button like the signpost, the same size")
	check(G:GetFrameLevel() == V.btnTravel:GetFrameLevel(), "drawn at the signpost's level, above the strip's art")
	check(select(2, V.btnSettings:GetPoint(1)) == V.closeBtn, "Settings stays where it was")
	G:GetScript("OnClick")(G); M.runTimers(); M.runTimers()
	check(n.ui.global == true, "and it opens Global Inventory")
	G:GetScript("OnClick")(G); M.runTimers(); M.runTimers()
	n:Set("skin", "modern"); M.runTimers(); M.runTimers()
	if not V.classicApplied then
		check(select(2, G:GetPoint(1)) == V.btnTravel and select(2, V.titleDivider:GetPoint(1)) == G, "back to Modern: left of Travel Mode again, the divider beside it")
	end
	check((n.errors or 0) == 0, "no errors")
end)()
