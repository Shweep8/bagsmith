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
	-- ======== 1.9.0-beta1 (Shweep, 16 Nov): what BagSmith knows about an item, in its tooltip ========
	-- Item tooltips list your characters on this realm (Forever's ruleset) and their counts by place: bags, bank, what
	-- they wear. You first, then the most. The footer's gold lists each character's gold, Shift for the account.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
	local LINEN, SWORD = 2589, 1001
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, profiles = { Default = {} }, cache = {
		["Brannoc - Forever"] = { name = "Brannoc", realm = "Forever", class = "PRIEST", level = 20, gold = 500000,
			items = { { bag = 0, slot = 1, itemID = LINEN, count = 3 } }, bank = { { bag = 6, slot = 1, itemID = LINEN, count = 2 } },
			equipped = { { slot = 16, itemID = SWORD, count = 1 }, { slot = "x", itemID = 5 } } },
		["Corwin - Forever"] = { name = "Corwin", realm = "Forever", class = "WARRIOR", level = 10, gold = 1000,
			items = { { bag = 0, slot = 2, itemID = LINEN, count = 20 } } },
		["Elsewhere - Other Realm"] = { name = "Elsewhere", realm = "Other Realm", class = "PRIEST", level = 30, gold = 9000000,
			items = { { bag = 0, slot = 1, itemID = LINEN, count = 99 } } },
	} }
	local n = M.loadAddon("BagSmith"); n.SettingsPanel.NEW = NEW19()
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local Inv = n.Inventory
	check(n.db.tipInventory == true, "Show Inventory in Item Tooltips: on by default")
	check(#BagSmithDB.cache["Brannoc - Forever"].equipped == 1, "a saved equipped list keeps only good entries")

	-- the counts
	local list, total = Inv:Counts(LINEN)
	check(total == 30 and #list == 3, "Linen Cloth: 5 + 3 + 2 + 20 = 30 on this realm, the other realm left out (" .. total .. ")")
	check(list[1].isMe and list[1].bags == 5, "you first")
	check(list[2].name == "Corwin" and list[2].total == 20 and list[3].name == "Brannoc" and list[3].bags == 3 and list[3].bank == 2, "then the most")
	check(Inv.Places(list[3]) == "Bags: 3, Bank: 2", "places read Bags, Bank, Equipped: " .. Inv.Places(list[3]))
	local s = Inv:Counts(SWORD)
	check(s[1] and s[1].name == "Brannoc" and s[1].equipped == 1, "what another character wears counts")

	-- the tooltip, on any item (a chat link here)
	local function tipFor(id)
		GameTooltip.GetItem = function() return "x", "|cffffffff|Hitem:" .. id .. "::::|h[x]|h|r" end
		GameTooltip:SetHyperlink("item:" .. id)
		return table.concat(GameTooltip.lines or {}, " | ")
	end
	local t = tipFor(LINEN)
	check(t:find("Inventory Total: 30", 1, true), "the Inventory block and its total: " .. t)
	check(t:find("Corwin|r Bags: 20", 1, true) and t:find("Brannoc|r Bags: 3, Bank: 2", 1, true), "each character's line, by name only")
	check(not t:find("Elsewhere", 1, true) and not t:find("Forever", 1, true), "no other realm's characters, and no realm in a name")
	check(t:find("UI-CHARACTERCREATE-CLASSES", 1, true), "with each character's class icon")
	-- (beta2, Shweep: the character you're on had no icon) your own line: its class icon and class color
	local mine = ""
	for _, l in ipairs(GameTooltip.lines or {}) do if l:find("Aldren", 1, true) then mine = l end end
	check(mine:find("UI-CHARACTERCREATE-CLASSES", 1, true) and mine:find("Aldren", 1, true) and not mine:find("|cffcccccc", 1, true), "your own line has its class icon and color: " .. mine)
	check(not tipFor(424242):find("Inventory", 1, true), "an item nobody has: no block")
	n:Set("tipInventory", false)
	check(not tipFor(LINEN):find("Inventory", 1, true), "the setting off: no block")
	n:Set("tipInventory", true)

	-- your own counts follow your bags and what you wear
	M.put(0, 2, { id = LINEN, name = "Linen Cloth", q = 1, count = 4, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
	M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	list, total = Inv:Counts(LINEN)
	check(list[1].isMe and list[1].bags == 9 and total == 34, "a new stack in your bags counts at once (" .. tostring(list[1].bags) .. ")")
	_G.GetInventoryItemID = function(_, slot) if slot == 16 then return SWORD end end
	M.fire("PLAYER_EQUIPMENT_CHANGED", 16)
	s = Inv:Counts(SWORD)
	check(s[1] and s[1].isMe and s[1].equipped == 1, "and what you wear")
	n:SaveCache()
	local saved = BagSmithDB.cache[n:CharKey()].equipped
	check(saved and saved[1] and saved[1].slot == 16 and saved[1].itemID == SWORD, "what you wear is saved with you")

	-- the gold tooltip
	n.Window:Show(); M.runTimers(); M.runTimers()
	local mb = n.Window.main.moneyButton
	mb:GetScript("OnEnter")(mb)
	local g = table.concat(GameTooltip.lines or {}, " | ")
	check(g:find("Realm-wide gold " .. (123456 + 500000 + 1000) .. "c", 1, true), "Realm-wide gold: this realm's total: " .. g)
	local me = g:find("123456c", 1, true)
	check(me and g:find("Brannoc|r 500000c", 1, true) and me < g:find("Brannoc", 1, true) and g:find("Brannoc", 1, true) < g:find("Corwin", 1, true), "you first, then the most")
	check(not g:find("Elsewhere", 1, true) and g:find("Shift - See all Rulesets", 1, true), "another realm's gold waits behind Shift, and the tooltip says so (beta2's wording, Shweep)")
	local first = GameTooltip.lines[2] or ""
	check(first:find("UI-CHARACTERCREATE-CLASSES", 1, true) and first:find("123456c", 1, true), "your own gold line has its class icon (beta2)")
	_G.IsShiftKeyDown = function() return true end
	M.fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
	g = table.concat(GameTooltip.lines or {}, " | ")
	check(g:find("Account-wide gold " .. (123456 + 500000 + 1000 + 9000000) .. "c", 1, true) and g:find("Elsewhere", 1, true), "Shift: the account, every realm: " .. g)
	check(not g:find("Shift - See", 1, true), "holding Shift: the hint steps aside")
	_G.IsShiftKeyDown = function() return false end
	mb:GetScript("OnLeave")(mb)
	check(n.Inventory.goldOwner == nil, "leaving the gold lets go")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- Disenchant results shared by your characters: each character's own log (from before 1.9) is added once
	package.loaded.mock = nil
	local M = require("mock")
	local function deep(t) if type(t) ~= "table" then return t end local o = {} for k, v in pairs(t) do o[k] = deep(v) end return o end
	_G.BagSmithCharDB = { version = 1, firstSeen = {}, deResultsVersion = 3, deMaterials = { [90001] = true },
		deResults = { ["2:2:a"] = { n = 63, mats = { [10940] = 112, [10939] = 25 }, seen = { [10940] = 45, [10939] = 15 } } } }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {} } }
	local n = M.loadAddon("BagSmith"); n.SettingsPanel.NEW = NEW19()
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE = n.Disenchant
	local log = DE:Log()
	check(log["2:2:a"] and log["2:2:a"].n == 63 and log["2:2:a"].mats[10940] == 112, "this character's results join the shared log")
	check(next(n.cdb.deResults) == nil and next(n.cdb.deMaterials) == nil and BagSmithDB.deShared.materials[90001], "and its own copy is emptied (it can't be added twice)")
	DE:Record("2:2:a", { { id = 10940, count = 2 } })
	local account, char1 = deep(BagSmithDB), deep(BagSmithCharDB)
	-- another character, its own older log
	package.loaded.mock = nil; M = require("mock")
	M.charName = "Brannoc Vale"
	_G.BagSmithCharDB = { version = 1, firstSeen = {}, deResultsVersion = 3, deResults = { ["2:2:a"] = { n = 7, mats = { [10940] = 10 }, seen = { [10940] = 7 } } } }
	_G.BagSmithDB = account
	n = M.loadAddon("BagSmith"); n.SettingsPanel.NEW = NEW19()
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	log = n.Disenchant:Log()
	check(log["2:2:a"].n == 63 + 1 + 7 and log["2:2:a"].mats[10940] == 112 + 2 + 10, "a second character adds its own, and sees the first's (" .. log["2:2:a"].n .. ")")
	check(n.Disenchant:LearnedMaterials()[90001], "and the materials the first learned")
	-- the first character again: nothing added twice
	account = deep(BagSmithDB)
	package.loaded.mock = nil; M = require("mock")
	_G.BagSmithCharDB, _G.BagSmithDB = char1, account
	n = M.loadAddon("BagSmith"); n.SettingsPanel.NEW = NEW19()
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	check(n.Disenchant:Log()["2:2:a"].n == 71, "back on the first: still 71, nothing counted twice")
	-- a broken shared log is checked on load
	account.deShared.results["bad"] = { n = "x" }; account.deShared.materials["y"] = true
	package.loaded.mock = nil; M = require("mock")
	_G.BagSmithCharDB, _G.BagSmithDB = deep(char1), account
	n = M.loadAddon("BagSmith"); n.SettingsPanel.NEW = NEW19()
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers()
	check(BagSmithDB.deShared.results.bad == nil and BagSmithDB.deShared.materials.y == nil and BagSmithDB.deShared.results["2:2:a"].n == 71, "a bad entry in the shared log is dropped, the rest kept")
	-- Forget Learned Results empties the shared log
	n.Disenchant:ResetLearned()
	check(next(n.Disenchant:Log()) == nil and n.Disenchant:LearnedMaterials()[90001], "Forget: the shared results go, the learned materials stay")

	-- item level 5 to 15: Forever's odds (a player's 60 disenchants of green armor)
	local DE2 = n.Disenchant
	local list = DE2:Expectation({ quality = 2, ilvl = 12, classID = 4 })
	check(#list == 2 and list[1][2] == 0.65 and list[2][2] == 0.35, "armor 5 to 15: dust 65%, essence 35%, no shard")
	list = DE2:Expectation({ quality = 2, ilvl = 12, classID = 2 })
	check(#list == 2 and list[1][2] == 0.20 and list[2][2] == 0.80, "weapons 5 to 15: dust 20%, essence 80%, no shard")
	list = DE2:Expectation({ quality = 2, ilvl = 18, classID = 4 })
	check(#list == 3 and list[1][2] == 0.75 and list[3][2] == 0.05, "16 to 20 unchanged (the player's 63 matched it)")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- Bag Slot Count: Exclude Special Bags (1.8's count, the default) or All Free Slots
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[3] = 6; M.bagNames[3] = "Herb Pouch"
	M.put(3, 1, { id = 2447, name = "Peacebloom", q = 1, count = 3, class = 7, subclass = 9, type = "Tradeskill", sub = "Herb", price = 5 })
	local realInstant = C_Item.GetItemInfoInstant
	C_Item.GetItemInfoInstant = function(item)
		if type(item) == "string" and item:find("%[Herb Pouch%]") then return 1, "Container", "", "INVTYPE_BAG", 1, 1, 2 end
		return realInstant(item)
	end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith"); n.SettingsPanel.NEW = NEW19()
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers(); n:RefreshViews(true); M.runTimers()
	local main = n.Window.main
	local g, gt = 0, 0
	for _, b in ipairs({ 0, 1, 2 }) do g, gt = g + n.bagInfo[b].free, gt + n.bagInfo[b].size end
	check(n.db.bagSlotCount == "exclude", "Exclude Special Bags by default")
	local txt = main.freeText.text or ""
	check(txt:find(("%d / %d"):format(g, gt), 1, true) and txt:find("+", 1, true), "excluded: the general count and a + : " .. txt)
	n:Set("bagSlotCount", "all"); M.runTimers()
	txt = main.freeText.text or ""
	check(txt:find(("%d / %d"):format(g + 5, gt + 6), 1, true) and not txt:find("+", 1, true), "All Free Slots: the herb bag's room counts too, no + : " .. txt)
	main.btnBags:GetScript("OnEnter")(main.btnBags)
	check(table.concat(GameTooltip.lines or {}, " | "):find("Herb Bag 5 / 6", 1, true), "the hover still lists it by kind")
	check(n:Set("bagSlotCount", "most") == false and n.db.bagSlotCount == "all", "only the two choices")
	n.SettingsPanel:Show(); n.SettingsPanel:ShowPage("window")
	local seg
	for _, w in ipairs(n.SettingsPanel.pools.seg) do if w:IsShown() and w.key == "bagSlotCount" then seg = w end end
	check(seg and seg.text.text == "Bag Slot Count" and seg.btns[1].label.text == "Exclude Special Bags" and seg.btns[2].label.text == "All Free Slots", "Settings > Windows: Bag Slot Count")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- 1.9's NEW list (replacing 1.8's, as each release does): Show Inventory in Item Tooltips (General), Bag Slot Count
	-- (Windows) and Jeor's Icon Border Weight (Item Icons)
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {} }, whatsNewSeen = "1.8.0" }
	local n = M.loadAddon("BagSmith"); n.SettingsPanel.NEW = NEW19()
	n.version = "1.9.0-beta1"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local P = n.SettingsPanel
	check(P.NEW.release == "1.9" and P:IsNew("keys", "tipInventory") and P:IsNew("keys", "bagSlotCount") and P:IsNew("keys", "borderWeight"), "1.9's three settings are NEW")
	check(not P:IsNew("keys", "textScale") and not P:IsNew("heads", "Special Bag Slot Indicators"), "1.8's aren't any more")
	P.page = "about"; P:Show()
	local tags = {}
	for _, b in ipairs(P.navButtons) do if b.newTag and b.newTag:IsShown() then tags[#tags + 1] = b.page end end
	table.sort(tags)
	-- (by design since 1.9.0-beta5) and Style, for Icon Layout; (beta6) Sections, Columns and Sheets, for their Global pages
	-- (by design since 1.9.0-beta8) the Global Inv pages' longer names, with their icons, reach the tag: their pages
	-- above and their headings show NEW instead
	check(table.concat(tags, ",") == "columns,general,icons,look,sections,sheets,window", "NEW beside General, Item Icons, Style, Windows, Sections, Columns and Sheets: " .. table.concat(tags, ","))
	check((n.errors or 0) == 0, "no errors")
end)()
