;(function()
	-- 1.5.0-beta9 (a player's request, shaped with Shweep): Split Consumables by Type, any subset; Food and Drink told
	-- apart by the item's use spell in the player's language; search keywords; the Consumables tab and filters still
	-- include split items; custom moves win; other characters' saved bags follow the profile's split.
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 16; for b = 1, 5 do M.sizes[b] = 0 end
	local items = {
		{ id = 4540, name = "Tough Hunk of Bread", sub = 5, spell = "Food" },
		{ id = 159, name = "Refreshing Spring Water", sub = 5, spell = "Drink" },
		{ id = 8079, name = "Conjured Crystal Water Cake", sub = 5, spell = "Refreshment" },
		{ id = 118, name = "Minor Healing Potion", sub = 1 },
		{ id = 2454, name = "Elixir of Lion's Strength", sub = 2 },
		{ id = 13510, name = "Flask of the Titans", sub = 3 },
		{ id = 955, name = "Scroll of Intellect", sub = 4 },
		{ id = 3239, name = "Rough Weightstone", sub = 6 },
		{ id = 1251, name = "Linen Bandage", sub = 7 },
		{ id = 9312, name = "Blue Firework", sub = 8 },
		-- (1.5.0-beta10) alcohol: Weak Alcohol by its spell ID (confirmed on WoW Forever), a stronger one by name
		{ id = 2723, name = "Bottle of Dalaran Noir", sub = 5, spell = "Weak Alcohol", spellID = 11007 },
		{ id = 2594, name = "Flagon of Dwarven Honeymead", sub = 5, spell = "Strong Alcohol", spellID = 90001 },
	}
	local spells, spellIDs = {}, {}
	for i, it in ipairs(items) do
		spellIDs[it.id] = it.spellID
		M.put(0, i, { id = it.id, name = it.name, q = 1, count = 5, class = 0, subclass = it.sub, type = "Consumable", sub = "Sub" .. it.sub, price = 1 })
		spells[it.id] = it.spell or ("Use " .. it.name)
	end
	M.put(0, 16, { id = 2512, name = "Rough Arrow", q = 1, count = 200, class = 6, subclass = 2, type = "Projectile", sub = "Arrow", price = 1 })
	C_Item.GetItemSpell = function(id) return spells[id], spells[id] and (spellIDs[id] or 1000 + id) or nil end
	local spellNames = { [433] = "Food", [430] = "Drink" }
	_G.GetSpellInfo = function(id) return spellNames[id] end
	-- (1.5.0-beta10: the client keeps this lookup under C_Item; there's no global)
	_G.GetItemSubClassInfo = nil
	C_Item.GetItemSubClassInfo = function(class, i) if class == 0 then return ({ [0] = "Consumable", "Potion", "Elixir", "Flask", "Scroll", "Food & Drink", "Item Enhancement", "Bandage", "Other" })[i] end end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local function rec(id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
	local function cat(id) return rec(id) and rec(id).cat end
	-- off by default
	local allCons = true
	for _, it in ipairs(items) do if cat(it.id) ~= "Consumables" then allCons = false end end
	check(allCons and cat(2512) == "Consumables" and not n.db.splitCons, "off by default: every consumable is in Consumables")
	-- search keywords work with the split off
	local drink, food, potion = n:ParseSearch("drink"), n:ParseSearch("food"), n:ParseSearch("potion")
	check(drink(rec(159)) and not drink(rec(4540)) and not drink(rec(8079)), "\"drink\" finds drinks only, not food (they share the game's Food & Drink type)")
	check(food(rec(4540)) and food(rec(8079)) and not food(rec(159)), "\"food\" finds food, including items that are both")
	check(potion(rec(118)) and not potion(rec(2454)), "\"potion\" finds potions")
	check(not drink(rec(2723)) and not drink(rec(2594)) and not food(rec(2723)), "alcohol is neither a drink nor food for search (it doesn't restore mana)")
	-- on: every type splits out
	n:Set("splitCons", true); M.runTimers()
	local want = { [4540] = "ConsFood", [159] = "ConsDrink", [8079] = "ConsFood", [118] = "ConsPotion", [2454] = "ConsElixir", [13510] = "ConsFlask",
		[955] = "ConsScroll", [3239] = "ConsEnhance", [1251] = "ConsBandage", [9312] = "ConsOther", [2723] = "ConsOther", [2594] = "ConsOther" }
	local ok, wrong = true, {}
	for id, c in pairs(want) do if cat(id) ~= c then ok = false; wrong[#wrong + 1] = id .. "=" .. tostring(cat(id)) end end
	check(ok, "on: each consumable goes to its type's section (" .. table.concat(wrong, ", ") .. ")")
	check(cat(2512) == "Consumables", "ammunition stays in Consumables")
	check(n.Sections:Label("ConsDrink") == "Drink" and n.Sections:Label("ConsEnhance") == "Item Enhancements", "the sections have plain names")
	local order = n.db.laneOrder
	local ci = n.IndexOf(order, "Consumables")
	check(ci and order[ci + 1] == "ConsFood" and order[ci + 2] == "ConsDrink" and order[ci + 9] == "ConsOther", "they join Section Order right after Consumables")
	-- the Consumables tab and a Consumables filter still include them
	local f = n:FilterPredicate(n.CleanFilters({ cat = { Consumables = true } }))
	check(f(rec(159)) and f(rec(118)) and not f({ cat = "Gear" }), "a Consumables filter still includes the split sections")
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V = n.Window.main
	V:SetPref("grp", "type"); V:SetSheet("Consumables"); n:RefreshViews(true); M.runTimers()
	local seen = {}
	for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec then seen[b.rec.itemID] = true end end
	check(seen[159] and seen[4540] and seen[118] and seen[2512], "the Consumables tab still shows them all, in their sections")
	V:SetSheet("All")
	-- only some types split out
	n:Set("splitConsTypes", { Potion = false, Elixir = false, Flask = false, Scroll = false, Bandage = false, Enhance = false, Other = false }); M.runTimers()
	check(cat(4540) == "ConsFood" and cat(159) == "ConsDrink" and cat(118) == "Consumables" and cat(1251) == "Consumables", "with only Food and Drink ticked, the rest stays in Consumables")
	-- a custom move wins
	local S = n.Sections
	local mine = S:Create("My Drinks"); S:Move(159, mine); M.runTimers()
	check(cat(159) == mine, "an item you moved to a custom section stays there")
	S:Move(159, "ConsDrink"); M.runTimers()
	-- an item whose use spell hasn't loaded waits in Consumables, then moves
	local realSpell = spells[159]; spells[159] = nil
	n.Sections:ReclassifyConsumables(); M.runTimers()
	check(cat(159) == "Consumables" and n.pendingInfo, "an item whose details haven't loaded waits in Consumables")
	spells[159] = realSpell
	M.fire("GET_ITEM_INFO_RECEIVED", 159); M.runTimers(); M.runTimers()
	check(cat(159) == "ConsDrink", "and moves once the game sends them")
	-- the player's language
	spellNames[430] = "Trinken"; spells[159] = "Trinken"
	n.Sections:ReclassifyConsumables(); M.runTimers()
	check(cat(159) == "ConsDrink", "drinking is recognised by the game's own name for it, in any language")
	spellNames[430] = "Drink"; spells[159] = "Drink"
	-- other characters' saved bags follow this profile's split
	local saved = { ownCat = "Consumables", classID = 0, subclassID = 5, itemID = 159 }
	check(S:OwnCategory(saved) == "ConsDrink", "other characters' saved bags follow the split too")
	-- the settings rows
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("sections")
	local master, subs = nil, {}
	for _, c in ipairs(P.pools.check) do
		if c:IsShown() and c.key == "splitCons" then master = c end
		if c:IsShown() and type(c.key) == "string" and c.key:find("^splitCons_") then subs[c.key] = c end
	end
	check(master and master.box:GetChecked() and subs.splitCons_Food and subs.splitCons_Other and subs.splitCons_Food.box:GetChecked() and not subs.splitCons_Potion.box:GetChecked(), "Settings > Sections: the switch, and a box per type")
	subs.splitCons_Potion.box:SetChecked(true); subs.splitCons_Potion.box:GetScript("OnClick")(subs.splitCons_Potion.box); M.runTimers()
	check(cat(118) == "ConsPotion", "ticking Potions splits them out")
	-- off again: everything back
	n:Set("splitCons", false); M.runTimers()
	allCons = true
	for _, it in ipairs(items) do if cat(it.id) ~= "Consumables" then allCons = false end end
	check(allCons, "turning it off puts everything back in Consumables")
	P:ShowPage("sections")
	local subsShown = false
	for _, c in ipairs(P.pools.check) do if c:IsShown() and type(c.key) == "string" and c.key:find("^splitCons_") then subsShown = true end end
	check(not subsShown, "the type boxes show only while it's on")
	P:Hide()
	-- /bs consumables
	M.log = {}
	SlashCmdList.BAGSMITH("consumables")
	local said = { types = false, names = false, water = false }
	for _, l in ipairs(M.log) do
		if l:find("5 Food & Drink", 1, true) then said.types = true end
		if l:find("Eating is called \"Food\", drinking \"Drink\"", 1, true) then said.names = true end
		if l:find("Refreshing Spring Water: type 5", 1, true) and l:find("use spell Drink", 1, true) then said.water = true end
	end
	check(said.types and said.names and said.water, "/bs consumables lists the client's consumable types, its names for eating and drinking, and each consumable")
end)()
