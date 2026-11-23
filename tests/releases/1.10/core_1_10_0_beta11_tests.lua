-- ======== 1.10.0-beta11 (Shweep, 22 Nov: "build beta 11"; in scope by his "I think 5 and 6 should be done too") ========
-- (1) Five more kinds of rule, from the mockup's Add a Rule list: Name (its name contains a word you type), Food,
-- Drink and Potions (BagSmith's kinds of consumable), Quest Item, Crafting Material and Usable by Me. + Add a Rule
-- lists every kind in groups. A long rule name takes the room it needs on its row.
-- (2) Settings > Custom Sections: "start from an example" (Cloth, Herbs, Gear to Sell, Food and Drink), each opening
-- the editor filled in, and "How an Item Finds Its Section".

local RED, WHITE = { r = 1, g = 0.13, b = 0.13 }, { r = 1, g = 1, b = 1 }
local REAGENT = { [2589] = true, [4306] = true, [4305] = true, [2447] = true }
local SPELL = { [117] = { "Food", 433 }, [159] = { "Drink", 430 } }
local function click(b) b:GetScript("OnClick")(b) end
local function pump(M) for _ = 1, 40 do M.runTimers() end end

-- opts: prof, skin, tip (function(id) -> tooltip lines or nil for the usual), level
local function boot(opts)
	opts = opts or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.removeEquipmentSets()
	M.sizes[0] = 16
	local function tg(slot, id, name, sub, subName)
		M.put(0, slot, { id = id, name = name, q = 1, count = 5, class = 7, subclass = sub, type = "Trade Goods", sub = subName, price = 10, ilvl = 10 })
	end
	tg(1, 2589, "Linen Cloth", 5, "Cloth")
	tg(2, 4306, "Silk Cloth", 5, "Cloth")
	tg(3, 4305, "Bolt of Silk Cloth", 5, "Cloth")
	tg(4, 2447, "Peacebloom", 9, "Herb")
	M.put(0, 5, { id = 117, name = "Tough Jerky", q = 1, count = 5, class = 0, subclass = 5, type = "Consumable", sub = "Food & Drink", price = 5 })
	M.put(0, 6, { id = 159, name = "Refreshing Spring Water", q = 1, count = 5, class = 0, subclass = 5, type = "Consumable", sub = "Food & Drink", price = 5 })
	M.put(0, 7, { id = 118, name = "Minor Healing Potion", q = 1, count = 2, class = 0, subclass = 1, type = "Consumable", sub = "Potion", price = 5 })
	M.put(0, 8, { id = 1251, name = "Linen Bandage", q = 1, count = 4, class = 0, subclass = 7, type = "Consumable", sub = "Bandage", price = 5 })
	M.put(0, 9, { id = 9001, name = "Silk Robe", q = 2, count = 1, class = 4, subclass = 1, type = "Armor", sub = "Cloth", equip = "INVTYPE_ROBE", bind = 2, price = 300, ilvl = 20 })
	M.put(0, 10, { id = 9002, name = "Plate Helm", q = 2, count = 1, class = 4, subclass = 4, type = "Armor", sub = "Plate", equip = "INVTYPE_HEAD", bind = 2, price = 400, ilvl = 40 })
	M.put(0, 11, { id = 9003, name = "Sealed Orders", q = 1, count = 1, class = 12, subclass = 0, type = "Quest", sub = "Quest", price = 0 })
	_G.INVTYPE_HEAD, _G.INVTYPE_ROBE = "Head", "Chest"
	_G.ITEM_QUALITY_COLORS = { [0] = { r = 0.62, g = 0.62, b = 0.62 }, { r = 1, g = 1, b = 1 }, { r = 0.12, g = 1, b = 0 }, { r = 0, g = 0.44, b = 0.87 }, { r = 0.64, g = 0.21, b = 0.93 }, { r = 1, g = 0.5, b = 0 } }
	_G.GetSpellInfo = function(id) if id == 430 then return "Drink" elseif id == 433 then return "Food" end end
	_G.UnitLevel = function() return opts.level and opts.level() or 20 end
	-- the game's own word on each item: a crafting reagent or not, and what using it does
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(what)
		local r = { realInfo(what) }
		local id = tonumber(tostring(what):match("item:(%d+)")) or tonumber(what)
		if r[1] then r[17] = REAGENT[id] or false end
		return unpack(r, 1, 17)
	end
	C_Item.GetItemSpell = function(id) local s = SPELL[id]; if s and not (opts.noSpell and opts.noSpell[id]) then return s[1], s[2] end end
	-- tooltips: the plate helm's type is red on this character unless a test says otherwise
	_G.C_TooltipInfo = { GetHyperlink = function(link)
		local id = tonumber(tostring(link):match("item:(%d+)"))
		local own = opts.tip and opts.tip(id)
		if own ~= nil then return own end
		if id == 9002 then return { lines = { { leftText = "Plate Helm" }, { leftText = "Binds when equipped" }, { leftText = "Head", rightText = "Plate", rightColor = RED } } } end
		if id == 9001 then return { lines = { { leftText = "Silk Robe" }, { leftText = "Binds when equipped" }, { leftText = "Chest", rightText = "Cloth", rightColor = WHITE } } } end
		return { lines = { { leftText = "An item" }, { leftText = "Something about it" } } }
	end }
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local prof = { view = "list", grp = "type", favSection = true, recentSection = false, skin = opts.skin or "modern" }
	for k, v in pairs(opts.prof or {}) do prof[k] = v end
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = prof } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta11"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	return n, M, n.Window.main, n.Sections, n.Rules
end
local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
local function inSection(n, id)
	local t = {}
	for _, r in ipairs(n.items) do if r.itemID and r.cat == id then t[#t + 1] = r.name end end
	table.sort(t)
	return table.concat(t, ", ")
end
local function one(k, v, n) return { mode = "all", rows = { { k = k, v = v, n = n } } } end
local CLOTH = "Bolt of Silk Cloth, Linen Cloth, Silk Cloth"

;(function()
	-- the rules themselves, item by item
	local n, M, main, S, R = boot()
	local function fits(rules, id) return R:Fits(R.Clean(rules), recOf(n, id)) end
	-- Name
	check(fits(one("name", { "cloth" }), 2589) and fits(one("name", { "CLOTH" }), 4305) and fits(one("name", { "silk c" }), 4306), "Name: the word anywhere in the name, whatever the capitals")
	check(not fits(one("name", { "cloth" }), 2447) and fits(one("name", { "cloth" }, true), 2447) and not fits(one("name", { "cloth" }, true), 2589), "does not contain: the items without the word")
	check(fits(one("name", { "peace", "jerky" }), 2447) and fits(one("name", { "peace", "jerky" }), 117) and not fits(one("name", { "peace", "jerky" }), 159), "several words: any one of them")
	check(not R:Fits(R.Clean(one("name", { "a" })), { itemID = 1, name = "" }) and not R:Fits(R.Clean(one("name", { "a" }, true)), { itemID = 1 }), "an item with no name yet fits neither way: it waits")
	check(fits(one("name", { "silk" }), 9001) and not R:Fits(R.Clean(one("name", { "s.lk" })), recOf(n, 9001)) and not R:Fits(R.Clean(one("name", { "%a+" })), recOf(n, 9001)), "a word is plain letters: a dot or a percent sign is only itself")
	local cleaned = R.Clean({ rows = { { k = "name", v = { "cloth", "", "   ", "a|cffff0000b", "line\nbreak", ("x"):rep(41), 7, "Silk" } } } })
	check(cleaned and table.concat(cleaned.rows[1].v, "/") == "cloth/Silk", "what's kept of a saved Name rule: real words only (no empty one, no color code, no line break, none past 40 letters)")
	check(R:RowText({ k = "name", v = { "silk", "linen" } }) == "Name contains \"silk\" or \"linen\"" and R:RowText({ k = "name", v = { "bolt" }, n = true }) == "Name does not contain \"bolt\"", "in words: Name contains \"silk\" or \"linen\"; Name does not contain \"bolt\"")
	-- Food, Drink and Potions
	check(fits(one("cons", { "Food" }), 117) and fits(one("cons", { "Drink" }), 159) and not fits(one("cons", { "Food" }), 159), "Consumable: Tough Jerky is Food, Refreshing Spring Water is Drink (the game's one Food & Drink type, told apart)")
	check(fits(one("cons", { "Potion" }), 118) and fits(one("cons", { "Bandage" }), 1251) and fits(one("cons", { "Food", "Drink" }), 159), "a potion, a bandage; two kinds in one rule")
	check(not fits(one("cons", { "Food" }), 2589) and fits(one("cons", { "Food" }, true), 2589), "cloth is no consumable: it isn't Food, and it is not Food")
	local labels = {}
	for i, o in ipairs(R:Options("cons")) do labels[i] = o.label end
	check(table.concat(labels, ", ") == "Food, Drink, Potions, Elixirs, Flasks, Scrolls, Bandages, Item Enhancements, Other", "its choices, as Split Consumables names them (" .. table.concat(labels, ", ") .. ")")
	check(R:RowText({ k = "cons", v = { "Food", "Drink" } }) == "Consumable is Food or Drink" and R.Clean(one("cons", { "Food", "Soup", 3 })).rows[1].v[2] == nil, "in words: Consumable is Food or Drink; a kind BagSmith doesn't have isn't kept")
	-- Quest Item
	check(fits(one("quest", { "yes" }), 9003) and not fits(one("quest", { "yes" }), 2589) and fits(one("quest", { "yes" }, true), 2589), "Quest Item: the sealed orders are, cloth is not")
	check(R:Fits(R.Clean(one("quest", { "yes" })), { itemID = 5, classID = 7, isQuest = true }) and R:Fits(R.Clean(one("quest", { "yes" })), { itemID = 5, classID = 7, bindType = 4 }), "an item the game flags for a quest, or that binds to one, is a quest item whatever its type")
	check(not R:Fits(R.Clean(one("quest", { "yes" })), { itemID = 5 }) and not R:Fits(R.Clean(one("quest", { "yes" }, true)), { itemID = 5 }), "an item the game hasn't described yet fits neither way")
	-- Crafting Material
	check(fits(one("mat", { "yes" }), 2589) and fits(one("mat", { "yes" }), 2447) and not fits(one("mat", { "yes" }), 117) and fits(one("mat", { "yes" }, true), 117), "Crafting Material: cloth and herbs are, jerky is not")
	check(not R:Fits(R.Clean(one("mat", { "yes" })), { itemID = 5, classID = 7 }) and not R:Fits(R.Clean(one("mat", { "yes" }, true)), { itemID = 5, classID = 7 }), "not known yet: neither way")
	-- Usable by Me
	check(fits(one("usable", { "yes" }), 9001) and not fits(one("usable", { "yes" }), 9002) and fits(one("usable", { "yes" }, true), 9002), "Usable by Me: the silk robe is, the plate helm is not")
	check(fits(one("usable", { "yes" }), 2589), "something with nothing to meet, like cloth, is usable")
	check(R:RowText({ k = "usable", v = { "yes" }, n = true }) == "Usable by Me is not Yes" and R:RowText({ k = "quest", v = { "yes" } }) == "Quest Item is Yes" and R:RowText({ k = "mat", v = { "yes" } }) == "Crafting Material is Yes", "in words: Usable by Me is not Yes; Quest Item is Yes; Crafting Material is Yes")
	-- none of them is a filter's only: a section may use each
	for _, k in ipairs(R.MORE_KEYS) do check(R.KEYS[k] and not R.KEYS[k].filterOnly and not R.KEYS[k].addon, "(" .. k .. ": a section's rule too, with no other addon)") end
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- sections that fill by the new rules
	local n, M, main, S, R = boot()
	local cloth = S:CreateWithRules("Cloth Things", one("name", { "cloth" })); pump(M)
	check(inSection(n, cloth) == CLOTH, "Name contains \"cloth\": the three cloths (" .. inSection(n, cloth) .. ")")
	S:SetRules(cloth, one("name", { "bolt" }, true)); pump(M)
	check(not inSection(n, cloth):find("Bolt", 1, true) and inSection(n, cloth):find("Linen Cloth", 1, true) and inSection(n, cloth):find("Peacebloom", 1, true), "does not contain \"bolt\": everything else that a rule may take")
	S:Delete(cloth); pump(M)
	local food = S:CreateWithRules("Food and Drink", one("cons", { "Food", "Drink" })); pump(M)
	check(inSection(n, food) == "Refreshing Spring Water, Tough Jerky", "Consumable is Food or Drink (" .. inSection(n, food) .. ")")
	local mats = S:CreateWithRules("Mats", one("mat", { "yes" })); pump(M)
	check(inSection(n, mats) == "Bolt of Silk Cloth, Linen Cloth, Peacebloom, Silk Cloth", "Crafting Material is Yes (" .. inSection(n, mats) .. ")")
	local quest = S:CreateWithRules("Errands", one("quest", { "yes" })); pump(M)
	check(inSection(n, quest) == "Sealed Orders", "Quest Item is Yes: a quest item can go to a section of yours (" .. inSection(n, quest) .. ")")
	local sell = S:CreateWithRules("Gear to Sell", { mode = "all", rows = { { k = "bind", v = { "boe" } }, { k = "usable", v = { "yes" }, n = true } } }); pump(M)
	check(inSection(n, sell) == "Plate Helm" and recOf(n, 9001).cat == "Gear", "Gear to Sell (binds when equipped, and not usable by me): the plate helm, not the silk robe (" .. inSection(n, sell) .. ")")
	-- Settings says each in words
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("custom"); M.runTimers()
	local subs = {}
	for _, w in ipairs(P.pools.csec or {}) do if w:IsShown() then subs[#subs + 1] = w.sub.text end end
	local all = table.concat(subs, " | ")
	check(all:find("Consumable is Food or Drink", 1, true) and all:find("Crafting Material is Yes", 1, true) and all:find("Quest Item is Yes", 1, true)
		and all:find("Fits all: Binding is Binds when equipped; Usable by Me is not Yes", 1, true), "Settings > Custom Sections reads each rule out (" .. all .. ")")
	P:Hide()
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- Usable by Me follows your character: a level gained, and a tooltip the game was slow to send
	local level, helmRed = 20, true
	local loading = false
	local n, M, main, S, R = boot({ level = function() return level end, tip = function(id)
		if id ~= 9002 then return nil end
		if loading then return { lines = {} } end
		return { lines = { { leftText = "Plate Helm" }, { leftText = "Binds when equipped" }, { leftText = "Head", rightText = "Plate", rightColor = helmRed and RED or WHITE } } }
	end })
	local sell = S:CreateWithRules("Gear to Sell", { mode = "all", rows = { { k = "bind", v = { "boe" } }, { k = "usable", v = { "yes" }, n = true } } }); pump(M)
	check(inSection(n, sell) == "Plate Helm", "(the plate helm is in Gear to Sell)")
	check(n.Usability.RuleWanted() == true, "(a section asks whether items are usable)")
	-- you learn plate: the game says so, and the section lets the helm go
	helmRed = false
	M.fire("SKILL_LINES_CHANGED"); pump(M)
	check(inSection(n, sell) == "" and recOf(n, 9002).cat == "Gear", "the helm becomes usable (a skill learned): it leaves Gear to Sell by itself (" .. inSection(n, sell) .. ")")
	-- nothing red any more: another level changes nothing
	-- (by design since 1.10.0-beta13, the beta12 audit's F2: beta11 asked nothing of the sections here, since no
	-- tooltip was red. That missed an item out of reach by its level alone, which has no red tooltip to find. A level
	-- gained now always looks once; skills, spells and reputation still compare the answers first.)
	local reapplied = 0
	local real = S.Reapply
	S.Reapply = function(...) reapplied = reapplied + 1; return real(...) end
	M.fire("PLAYER_LEVEL_UP", 21); pump(M)
	check(reapplied == 1 and inSection(n, sell) == "" and recOf(n, 9002).cat == "Gear", "with nothing unusable in the bags, a level gained looks at the sections once, and nothing moves (" .. reapplied .. ")")
	reapplied = 0
	M.fire("SKILL_LINES_CHANGED"); pump(M); M.fire("SPELLS_CHANGED"); pump(M)
	check(reapplied == 0, "a skill or a spell changing with the same answers still asks nothing of them")
	S.Reapply = real
	-- no rule asks: nothing is looked at again either
	S:Delete(sell); pump(M)
	check(n.Usability.RuleWanted() == false, "(no rule asks any more)")
	-- a tooltip the game hasn't sent yet: the item waits in its usual section, then joins
	helmRed, loading = true, true
	n.Usability:Invalidate()
	sell = S:CreateWithRules("Gear to Sell", { mode = "all", rows = { { k = "bind", v = { "boe" } }, { k = "usable", v = { "yes" }, n = true } } }); pump(M)
	check(inSection(n, sell) == "" and n.Usability:Usable(recOf(n, 9002)) == nil, "the helm's tooltip isn't there yet: no answer, and it waits in Gear")
	local keep = S:CreateWithRules("Wearable", { mode = "all", rows = { { k = "slot", v = { "INVTYPE_HEAD" } }, { k = "usable", v = { "yes" } } } }); pump(M)
	check(inSection(n, keep) == "", "and it isn't taken as usable either: a rule either way waits")
	-- the game's tooltip news keeps coming while that one item still has none: the sections aren't redone over and over
	local redone = 0
	local realRe = S.Reapply
	S.Reapply = function(...) redone = redone + 1; return realRe(...) end
	for _ = 1, 6 do M.fire("TOOLTIP_DATA_UPDATE"); pump(M) end
	check(redone <= 1, "tooltip news for other things, six times over: the sections are looked at once at most (" .. redone .. ")")
	S.Reapply = realRe
	loading = false
	M.fire("GET_ITEM_INFO_RECEIVED", 9002, true); pump(M)
	check(inSection(n, sell) == "Plate Helm", "the tooltip arrives: it joins Gear to Sell (" .. inSection(n, sell) .. ")")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- food or drink the game hasn't described yet waits too
	local n, M, main, S, R = boot({ noSpell = { [159] = true } })
	local drinks = S:CreateWithRules("Drinks", one("cons", { "Drink" })); pump(M)
	check(inSection(n, drinks) == "" and R.KEYS.cons.of(recOf(n, 159)) == nil, "the water's use isn't known yet: no kind, and it waits")
	check(R.KEYS.cons.of(recOf(n, 118))[1] == "Potion", "(a potion needs no such answer)")
	check((n.errors or 0) == 0, "no errors")
end)()

for _, skin in ipairs({ "modern", "classic" }) do
	-- the editor: the grouped menu, a Name rule's row, the other new rows
	local S0 = skin .. ": "
	local n, M, main, S, R = boot({ skin = skin })
	local E = n.SectionEditor
	local menu
	n.ShowMenu = function(items) menu = items end
	local f = S:EditSection(); M.runTimers()
	click(f.add)
	local texts = {}
	for i, item in ipairs(menu) do texts[i] = item.text end
	check(table.concat(texts, " | ") == "What should the rule look at? | About the item | Type | Slot | Quality | Binding | Item Level | Name | What it is for | Food, Drink and Potions | Quest Item | Crafting Material | Usable by Me | Value | Vendor Value | Optional: the ItemTree addon adds more rules here.",
		S0 .. "+ Add a Rule, in groups (" .. table.concat(texts, " | ") .. ")")
	local function entry(text) for _, item in ipairs(menu) do if item.text == text then return item end end end
	check(entry("About the item").disabled and not entry("About the item").onClick and entry("What it is for").disabled and entry("Value").disabled, S0 .. "each group's name is a quiet line, not a choice")
	check(entry("Name").tip == "Its name contains a word you type." and entry("Food, Drink and Potions").tip == "What kind of consumable it is: Food, Drink, Potions, Bandages..."
		and entry("Quest Item").tip == "Needed for a quest, or starts one." and entry("Crafting Material").tip == "Used to craft something." and entry("Usable by Me").tip == "Your class and level can use it.", S0 .. "each new kind says what it looks at")
	-- Name
	entry("Name").onClick(); M.runTimers()
	local r = f.rows[1]
	check(#E.draft.rows == 1 and r.label.text == "Name" and r.verb.label.text == "contains" and r.word:IsShown() and r.wordAdd:IsShown() and r.wordAdd.label.text == "Add" and not r.choose:IsShown(),
		S0 .. "Name: a row that says contains, with a box for a word and Add")
	check(r.note:IsShown() and r.note.text == "Type a word and press Enter, or this rule is ignored.", S0 .. "with no word yet, it says what to do")
	r.word:SetText("cloth"); r.word:GetScript("OnEnterPressed")(r.word); pump(M)
	check(E.draft.rows[1].v[1] == "cloth" and r.word:GetText() == "" and r.chips[1]:IsShown() and r.chips[1].label.text == "\"cloth\"" and not r.note:IsShown(), S0 .. "Enter: the word becomes a chip, and the box is ready for another")
	local names = {}
	for i, x in ipairs(E.shown.here) do names[i] = x.name end
	check(table.concat(names, ", ") == CLOTH, S0 .. "and the list on the right shows what would go in (" .. table.concat(names, ", ") .. ")")
	r.word:SetText("  Peace  "); click(r.wordAdd); pump(M)
	check(E.draft.rows[1].v[2] == "Peace" and r.chips[2].label.text == "\"Peace\"", S0 .. "Add does the same, and the spaces around a word are dropped")
	r.word:SetText("CLOTH"); click(r.wordAdd); pump(M)
	r.word:SetText("a|cffff0000b"); click(r.wordAdd); pump(M)
	check(#E.draft.rows[1].v == 3 and E.draft.rows[1].v[3] == "acffff0000b", S0 .. "a word already there isn't added twice (whatever its capitals), and a color code's bar is taken out")
	click(r.chips[3]); pump(M)
	check(#E.draft.rows[1].v == 2, S0 .. "clicking a word's chip takes it off")
	click(r.verb); pump(M)
	names = {}
	for i, x in ipairs(E.shown.here) do names[i] = x.name end
	check(r.verb.label.text == "does not contain" and not table.concat(names, ", "):find("Cloth", 1, true) and not table.concat(names, ", "):find("Peacebloom", 1, true) and table.concat(names, ", "):find("Tough Jerky", 1, true),
		S0 .. "does not contain: everything without either word")
	click(r.verb)
	-- a word typed and not added still counts when the section is created
	click(r.chips[2]); pump(M)
	r.word:SetText("jerky")
	f.edit:SetText("By Name"); click(f.save); pump(M)
	local made = S:Customs()[1]
	check(made and made.name == "By Name" and table.concat(made.rules.rows[1].v, "/") == "cloth/jerky" and inSection(n, made.id) == CLOTH .. ", Tough Jerky", S0 .. "Create Section with a word still in the box: it counts (" .. tostring(made and table.concat(made.rules.rows[1].v, "/")) .. ")")
	-- the other new rows
	f = S:EditSection(); M.runTimers()
	E:AddRow("cons"); E:AddRow("quest"); E:AddRow("mat"); E:AddRow("usable"); pump(M)
	local chips = {}
	for _, c in ipairs(f.rows[1].chips) do if c:IsShown() then chips[#chips + 1] = c.label.text end end
	check(f.rows[1].label.text == "Consumable" and table.concat(chips, ", ") == "Food, Drink, Potions, Elixirs, Flasks, Scrolls, Bandages, Item Enhancements, Other" and f.rows[1].note.text == "Pick at least one, or this rule is ignored.",
		S0 .. "Food, Drink and Potions: a Consumable row with every kind to tick (" .. table.concat(chips, ", ") .. ")")
	for i, label in ipairs({ "Quest Item", "Crafting Material", "Usable by Me" }) do
		local row = f.rows[i + 1]
		check(row.label.text == label and row.verb.label.text == "is" and row.chips[1]:IsShown() and row.chips[1].label.text == "Yes" and row.chips[1].active and not row.word:IsShown(), S0 .. label .. ": a row that says is Yes")
	end
	-- a long name has the room it needs: the rest of the line starts after it
	local mat = f.rows[3]
	local need = mat.label:GetStringWidth()
	-- a point's x offset, written short ("TOPLEFT", x, y) or long ("TOPLEFT", frame, "TOPLEFT", x, y)
	local function px(w) local p = w.points and w.points[1]; if not p then return nil end return type(p[2]) == "number" and p[2] or p[4] end
	check((mat.label.width or 0) >= need and px(mat.verb) >= need and px(f.rows[2].verb) == 88, S0 .. "Crafting Material isn't cut short: its row's verb starts after it (" .. tostring(px(mat.verb)) .. " for " .. need .. "); a short name keeps the usual place")
	click(f.rows[1].chips[1]); click(f.rows[1].chips[2]); pump(M)
	names = {}
	for i, x in ipairs(E.shown.here) do names[i] = x.name end
	check(table.concat(names, ", ") == "", S0 .. "(food or drink, a quest item, a material and usable, all at once: nothing is all four)")
	click(f.cancel)
	-- the Filters window offers them too, with its own group
	local Po = n.Popups
	Po:OpenFilters(main, "browse"); M.runTimers()
	local ff = Po.filter
	click(ff.add)
	texts = {}
	for i, item in ipairs(menu) do texts[i] = item.text end
	check(table.concat(texts, " | "):find("Usable by Me | Value | Vendor Value | Where it is | Section | Bag | Time in Bags | Optional: the ItemTree addon adds more rules here.$"), S0 .. "the Filters window's + Add a Rule: the same groups, and Where it is")
	entry("Name").onClick(); pump(M)
	local L = ff.list
	L.rows[1].word:SetText("silk"); L.rows[1].word:GetScript("OnEnterPressed")(L.rows[1].word); pump(M)
	local shown = {}
	for i, x in ipairs((main:Filtered())) do shown[i] = x.name end
	table.sort(shown)
	check(table.concat(shown, ", ") == "Bolt of Silk Cloth, Silk Cloth, Silk Robe", S0 .. "a filter by name: silk (" .. table.concat(shown, ", ") .. ")")
	click(ff.clearBtn); ff:Hide(); pump(M)
	check((n.errors or 0) == 0, S0 .. "no errors")
end

for _, skin in ipairs({ "modern", "classic" }) do
	-- Settings > Custom Sections: start from an example, and how an item finds its section
	local S0 = skin .. ": "
	local n, M, main, S, R = boot({ skin = skin })
	local E = n.SectionEditor
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("custom"); M.runTimers()
	local function texts()
		local t = {}
		for _, w in ipairs(P.pools.text or {}) do if w:IsShown() then t[#t + 1] = w.text.text end end
		return table.concat(t, "\n")
	end
	local function button(label) for _, b in ipairs(P.pools.btn or {}) do if b:IsShown() and b.label.text == label then return b end end end
	check(texts():find("Or start from an example. It opens filled in for you to look over, and nothing is made until you create it:", 1, true), S0 .. "the page offers examples, and says nothing is made until you create it")
	local row
	for _, label in ipairs({ "Cloth", "Herbs", "Gear to Sell", "Food and Drink" }) do
		local b = button(label)
		check(b ~= nil, S0 .. "an example: " .. label)
		if b then row = row or select(5, b:GetPoint(1)); check(select(5, b:GetPoint(1)) == row, S0 .. label .. " sits on the examples' one row") end
	end
	-- an example opens the editor filled in; nothing exists until Create Section
	click(button("Gear to Sell")); M.runTimers()
	local f = E.frame
	check(f and f:IsShown() and f.title.text == "New Section" and f.edit:GetText() == "Gear to Sell" and #S:Customs() == 0, S0 .. "Gear to Sell opens a new section's editor with its name, and nothing is made yet")
	check(#E.draft.rows == 2 and f.rows[1].label.text == "Binding" and f.rows[2].label.text == "Usable by Me" and f.rows[2].verb.label.text == "is not", S0 .. "with its two rules: Binding, and Usable by Me is not Yes")
	local names = {}
	for i, x in ipairs(E.shown.here) do names[i] = x.name end
	check(table.concat(names, ", ") == "Plate Helm", S0 .. "and what would go in it (" .. table.concat(names, ", ") .. ")")
	click(f.save); pump(M)
	local made = S:Customs()[1]
	check(made and made.name == "Gear to Sell" and R:Summary(made.rules) == "Fits all: Binding is Binds when equipped; Usable by Me is not Yes" and inSection(n, made.id) == "Plate Helm", S0 .. "Create Section makes it (" .. tostring(made and R:Summary(made.rules)) .. ")")
	-- the other three, by their rules
	local want = { Cloth = { "Type is Trade Goods: Cloth", CLOTH }, Herbs = { "Type is Trade Goods: Herb", "Peacebloom" }, ["Food and Drink"] = { "Consumable is Food or Drink", "Refreshing Spring Water, Tough Jerky" } }
	for _, label in ipairs({ "Cloth", "Herbs", "Food and Drink" }) do
		P:Show(); P:ShowPage("custom"); M.runTimers()
		click(button(label)); M.runTimers()
		names = {}
		for i, x in ipairs(E.shown.here) do names[i] = x.name end
		check(E.frame.edit:GetText() == label and R:Summary(R.Clean(E:Rules())) == want[label][1] and table.concat(names, ", ") == want[label][2], S0 .. label .. ": " .. tostring(R:Summary(R.Clean(E:Rules()))) .. " (" .. table.concat(names, ", ") .. ")")
		click(E.frame.cancel)
	end
	check(#S:Customs() == 1, S0 .. "looking at an example and cancelling makes nothing")
	-- the same example twice: the editor says the name is taken, as for any section
	P:Show(); P:ShowPage("custom"); M.runTimers()
	click(button("Gear to Sell")); M.runTimers()
	click(E.frame.save); pump(M)
	check(#S:Customs() == 1 and E.frame:IsShown() and (E.frame.err.text or "") ~= "", S0 .. "an example whose name you already have: the editor asks for another name (" .. tostring(E.frame.err.text) .. ")")
	click(E.frame.cancel)
	-- how an item finds its section
	P:Show(); P:ShowPage("custom"); M.runTimers()
	local head
	for _, w in ipairs(P.pools.head or {}) do if w:IsShown() and w.text.text == "How an Item Finds Its Section" then head = w end end
	check(head ~= nil and texts():find("Junk  >  Favorites  >  Moved by hand  >  Your sections, top to bottom  >  Its usual section", 1, true)
		and texts():find("The first one that fits wins, so an item is only ever in one section.", 1, true), S0 .. "How an Item Finds Its Section: the order, and that the first one wins")
	n:Set("favSection", false); pump(M)
	check(texts():find("Junk  >  Moved by hand  >  Your sections, top to bottom  >  Its usual section", 1, true) and not texts():find("Favorites  >", 1, true), S0 .. "with Favorites off as a section, it isn't in the order")
	n:Set("favSection", true); pump(M)
	-- the Sections page's own sentence has your sections in it
	P:ShowPage("sections"); M.runTimers()
	check(texts():find("the section you moved it to, one of your sections whose rules it fits, or its usual section.", 1, true), S0 .. "Settings > Sections: its sentence names your sections' rules too")
	P:Hide()
	check((n.errors or 0) == 0, S0 .. "no errors")
end

;(function()
	-- gear sets as sections come first in the order
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets()
	M.put(0, 1, { id = 104, guid = "g4", name = "Ring", q = 2, class = 4, subclass = 0, price = 50, equip = "INVTYPE_FINGER" })
	M.addSet("Tank", { [11] = M.bagLoc(0, 1) })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { gearSetSections = true, favSection = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("custom"); M.runTimers()
	local t = {}
	for _, w in ipairs(P.pools.text or {}) do if w:IsShown() then t[#t + 1] = w.text.text end end
	check(table.concat(t, "\n"):find("Its gear set  >  Junk  >  Favorites  >  Moved by hand  >  Your sections, top to bottom  >  Its usual section", 1, true), "with gear sets showing as sections, an item's gear set comes first")
	P:Hide()
	M.removeEquipmentSets()
end)()

;(function()
	-- the changelog
	local f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	local section = ("\n" .. log):match("\n(## 1%.10%.0\n.-)\n## 1%.9%.8\n") or ""
	check(section:find("More rules for your sections and filters: Name (its name contains a word you type), Food, Drink and Potions", 1, true) and section:find("Quest Item, Crafting Material and Usable by Me", 1, true),
		"the changelog's 1.10.0 section: the five new rules")
	check(section:find("can start a section from an example (Cloth, Herbs, Gear to Sell, Food and Drink)", 1, true) and section:find("The page also shows the order an item finds its section in.", 1, true), "the examples, and the order an item finds its section in")
	check(section:find("The rule editor no longer cuts a long rule name short, such as Used by My Professions.", 1, true), "and the long rule names")
	check(not section:find("\226\128\148") and not section:find("\226\128\147"), "with no dashes")
end)()
