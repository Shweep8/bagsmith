-- ======== 1.11.0-beta1 (Shweep, 24 Nov: "Build beta1") ========
-- 1.11's first beta, as scoped with him the same day:
--   1. Gear sets from the bags. A player: "how do I add another gear set? I can make one, but theres no way to make a
--      second"; Shweep: "I will let you keep doing them in the bags too". The Gear Sets sheet keeps a New Gear Set
--      button under the sets, with how many of the game's limit there are; a set's menu has Rename..., Delete... and
--      New Gear Set...
--   2. New Section From This Item offers the newer kinds of rule, each only when it is true of the item.
--   3. A menu too long for the screen shows arrows (it scrolled by the wheel alone, with no sign of it).
--   4. The window for the long lists (Type, Slot, Section) grows where the screen has room.

local RED, WHITE = { r = 1, g = 0.13, b = 0.13 }, { r = 1, g = 1, b = 1 }
local REAGENT = { [2589] = true, [2447] = true }
local SPELL = { [117] = { "Food", 433 }, [159] = { "Drink", 430 } }
local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function click(b) b:GetScript("OnClick")(b) end
local function pump(M) for _ = 1, 20 do M.runTimers() end end

-- opts: sets (number of gear sets to start with), screen (UIParent's height), itemTree (facts by item id), types
-- (give the game's own lists of item types), prof
local function boot(opts)
	opts = opts or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 10, ilvl = 10 })
	M.put(0, 2, { id = 2447, name = "Peacebloom", q = 1, count = 5, class = 7, subclass = 9, type = "Trade Goods", sub = "Herb", price = 10, ilvl = 10 })
	M.put(0, 3, { id = 117, name = "Tough Jerky", q = 1, count = 5, class = 0, subclass = 5, type = "Consumable", sub = "Food & Drink", price = 5 })
	M.put(0, 4, { id = 159, name = "Refreshing Spring Water", q = 1, count = 5, class = 0, subclass = 5, type = "Consumable", sub = "Food & Drink", price = 5 })
	M.put(0, 5, { id = 9001, name = "Silk Robe", q = 2, count = 1, class = 4, subclass = 1, type = "Armor", sub = "Cloth", equip = "INVTYPE_ROBE", bind = 2, price = 300, ilvl = 20 })
	M.put(0, 6, { id = 9002, name = "Plate Helm", q = 2, count = 1, class = 4, subclass = 4, type = "Armor", sub = "Plate", equip = "INVTYPE_HEAD", bind = 2, price = 400, ilvl = 40 })
	M.put(0, 7, { id = 9003, name = "Sealed Orders", q = 1, count = 1, class = 12, subclass = 0, type = "Quest", sub = "Quest", price = 0 })
	M.put(0, 8, { id = 9004, name = "Odd Trinket Box", q = 1, count = 1, class = 15, subclass = 0, type = "Miscellaneous", sub = "Junk", price = 3 })
	_G.INVTYPE_HEAD, _G.INVTYPE_ROBE = "Head", "Chest"
	_G.ITEM_QUALITY_COLORS = { [0] = { r = 0.62, g = 0.62, b = 0.62 }, { r = 1, g = 1, b = 1 }, { r = 0.12, g = 1, b = 0 }, { r = 0, g = 0.44, b = 0.87 }, { r = 0.64, g = 0.21, b = 0.93 }, { r = 1, g = 0.5, b = 0 } }
	_G.GetSpellInfo = function(id) if id == 430 then return "Drink" elseif id == 433 then return "Food" end end
	_G.UnitLevel = function() return 20 end
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(what)
		local r = { realInfo(what) }
		local id = tonumber(tostring(what):match("item:(%d+)")) or tonumber(what)
		if r[1] then r[17] = REAGENT[id] or false end
		return unpack(r, 1, 17)
	end
	C_Item.GetItemSpell = function(id) local s = SPELL[id]; if s then return s[1], s[2] end end
	_G.C_TooltipInfo = { GetHyperlink = function(link)
		local id = tonumber(tostring(link):match("item:(%d+)"))
		if id == 9002 then return { lines = { { leftText = "Plate Helm" }, { leftText = "Binds when equipped" }, { leftText = "Head", rightText = "Plate", rightColor = RED } } } end
		if id == 9001 then return { lines = { { leftText = "Silk Robe" }, { leftText = "Binds when equipped" }, { leftText = "Chest", rightText = "Cloth", rightColor = WHITE } } } end
		return { lines = { { leftText = "An item" }, { leftText = "Something about it" } } }
	end }
	-- (the slot names a block before this one gave the game: gone, unless this block gives them again)
	for _, t in ipairs({ "NECK", "SHOULDER", "CLOAK", "CHEST", "BODY", "TABARD", "WRIST", "HAND", "WAIST", "LEGS", "FEET", "FINGER", "TRINKET", "WEAPON",
		"WEAPONMAINHAND", "WEAPONOFFHAND", "2HWEAPON", "SHIELD", "HOLDABLE", "RANGED", "THROWN", "RELIC", "AMMO", "BAG", "QUIVER" }) do _G["INVTYPE_" .. t] = nil end
	if opts.types then
		local CLASSES = { [0] = { "Consumable", 9 }, [1] = { "Container", 9 }, [2] = { "Weapon", 21 }, [4] = { "Armor", 11 }, [5] = { "Reagent", 2 },
			[6] = { "Projectile", 4 }, [7] = { "Trade Goods", 17 }, [9] = { "Recipe", 11 }, [11] = { "Quiver", 4 }, [12] = { "Quest", 1 }, [13] = { "Key", 2 }, [15] = { "Miscellaneous", 6 } }
		C_Item.GetItemClassInfo = function(c) return CLASSES[c] and CLASSES[c][1] or nil end
		C_Item.GetItemSubClassInfo = function(c, s) if CLASSES[c] and s < CLASSES[c][2] then return CLASSES[c][1] .. " Kind " .. s end end
		for i, t in ipairs({ "NECK", "SHOULDER", "CLOAK", "CHEST", "BODY", "TABARD", "WRIST", "HAND", "WAIST", "LEGS", "FEET", "FINGER", "TRINKET", "WEAPON",
			"WEAPONMAINHAND", "WEAPONOFFHAND", "2HWEAPON", "SHIELD", "HOLDABLE", "RANGED", "THROWN", "RELIC", "AMMO", "BAG", "QUIVER" }) do _G["INVTYPE_" .. t] = "Slot " .. i end
	end
	if opts.itemTree then
		local facts = opts.itemTree
		_G.ItemTreeAPI = { version = 1, IsReady = function() return true end, RequestData = function() end, RegisterReadyCallback = function() end,
			RegisterChangeCallback = function() end,
			GetItemFacts = function(id)
				local f = facts[id] or {}
				return { itemId = id, known = true, keep = { marked = false, state = "vendor", tags = { "vendor" }, gear = f.upgrade and { upgrade = true } or nil }, route = { needed = false },
					vendors = { buyPrice = 10, everywhere = f.vendor or false, count = f.vendor and 3 or 0 },
					uses = { reagentSkills = f.prof and { 197 } or {}, kinds = { reagent = f.prof and 2 or 0 } }, quests = { needs = f.quest and { 1 } or {} } }
			end }
	else
		_G.ItemTreeAPI = nil
	end
	M.removeEquipmentSets()
	if opts.sets then
		M.installEquipmentSets()
		for i = 1, opts.sets do M.addSet(("Set %02d"):format(i), { [5] = 0x00300000 + 5 }) end   -- its chest piece: the Silk Robe, bag 0 slot 5
	end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local prof = { view = "list", grp = "type", favSection = true, recentSection = false }
	for k, v in pairs(opts.prof or {}) do prof[k] = v end
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = prof }, whatsNewSeen = "1.10.0" }
	_G.BagSmithWhatsNew = nil
	local n = M.loadAddon("BagSmith"); n.version = "1.11.0-beta1"
	if opts.screen then UIParent.GetHeight = function() return opts.screen end end
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); pump(M)
	return n, M, n.Window.main, n.Sections, n.Rules
end
local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
local function menuTexts(n) local t = {}; for _, it in ipairs(n.menuFrame.items or {}) do if it.text then t[#t + 1] = it.text end end return t end
local function menuItem(n, text) for _, it in ipairs(n.menuFrame.items or {}) do if it.text == text then return it end end end
local function shownRows(frame) local out = {}; for _, r in ipairs(frame.rows or {}) do if r:IsShown() then out[#out + 1] = r end end return out end

------------------------------------------------------------------------
-- 1. Gear sets from the bags
------------------------------------------------------------------------
do
	-- no sets yet: the note and its button, as before
	local n, M, main = boot({ sets = 0 })
	main:SetSheet("GearSets"); pump(M)
	local note = main.gsNote
	check(note and note:IsShown() and note.text.text == "No gear sets yet." and note.btn:IsShown() and note.btn.label.text == "Create Gear Set",
		"no gear sets: the Gear Sets sheet says so and offers Create Gear Set, as before")
	click(note.btn)
	local p = n.promptFrame
	check(p and p:IsShown(), "it asks for the set's name")
	p.edit:SetText("Tanking"); click(p.ok); pump(M)
	check(#n.GearSets:Sets() == 1 and n.GearSets:Sets()[1].name == "Tanking", "and makes the set from what you're wearing")
end
do
	-- with sets: the button stays, under them, with the count
	local n, M, main, S = boot({ sets = 2 })
	main:SetSheet("GearSets"); pump(M)
	local note = main.gsNote
	check(#n.GearSets:Sets() == 2, "(set up: two gear sets)")
	check(note and note:IsShown() and note.btn:IsShown(), "with gear sets, the Gear Sets sheet still has the button (it used to go after the first set)")
	check(note.btn.label.text == "New Gear Set" and note.text.text == "2 of 10 gear sets", "it reads New Gear Set, under \"2 of 10 gear sets\": " .. tostring(note.text.text))
	check(note.btn:IsEnabled() and not note.btn.offReason, "and is usable")
	-- under the sets, not over them
	local lowest = 0
	for _, b in ipairs(n.Buttons.all) do if b:IsShown() and b.rec then local _, _, _, _, by = b:GetPoint(1); if by and -by > lowest then lowest = -by end end end
	local _, _, _, _, ny = note:GetPoint(1)
	check(ny and -ny >= lowest, "it sits under the sets' items")
	click(note.btn)
	local p = n.promptFrame
	check(p and p:IsShown(), "a click asks for the new set's name")
	p.edit:SetText("Healing"); click(p.ok); pump(M)
	check(#n.GearSets:Sets() == 3 and n.GearSets:Find("Healing") ~= nil, "and a third set is made, from the bags")
	check(main.gsNote.text.text == "3 of 10 gear sets", "the count follows: " .. tostring(main.gsNote.text.text))
	check(not p:IsShown(), "(the prompt closed)")
	-- a name already used is refused in the prompt, as in Settings
	click(main.gsNote.btn); p.edit:SetText("Healing"); click(p.ok); pump(M)
	check(#n.GearSets:Sets() == 3 and p:IsShown(), "a name already taken is refused, and the prompt stays")
	p:Hide()

	-- a set's menu in the bags
	S:SectionMenu(n.GearSets.LaneId("Set 01"), main.frame)
	local texts = table.concat(menuTexts(n), " | ")
	check(texts:find("Update from What I'm Wearing...", 1, true) and texts:find("Put on Action Bar", 1, true), "a set's menu keeps Update from What I'm Wearing... and Put on Action Bar")
	local ren, del, new = menuItem(n, "Rename..."), menuItem(n, "Delete..."), menuItem(n, "New Gear Set...")
	check(ren and del and new, "and has Rename..., Delete... and New Gear Set... now: " .. texts)
	check(new and not new.disabled and new.tip == "Saves what you're wearing now as a gear set (shirt and tabard left out).", "New Gear Set... is usable and says what it saves")
	n.menuFrame:Hide()
	ren.onClick()
	check(p:IsShown() and p.edit:GetText() == "Set 01", "Rename... asks for the new name, starting from the old")
	p.edit:SetText("Fishing"); click(p.ok); pump(M)
	check(n.GearSets:Find("Fishing") ~= nil and n.GearSets:Find("Set 01") == nil, "and renames the set")
	new.onClick()
	check(p:IsShown(), "New Gear Set... asks for a name")
	p.edit:SetText("Mining"); click(p.ok); pump(M)
	check(#n.GearSets:Sets() == 4, "and makes another set")
	local asked
	local realConfirm = n.Confirm
	n.Confirm = function(anchor, text, yes) asked = text; yes() end
	S:SectionMenu(n.GearSets.LaneId("Mining"), main.frame); menuItem(n, "Delete...").onClick(); pump(M)
	n.Confirm = realConfirm
	check(asked and asked:find("Delete the gear set \"Mining\"?", 1, true) and n.GearSets:Find("Mining") == nil and #n.GearSets:Sets() == 3, "Delete... asks first, then deletes the set")
	n.menuFrame:Hide()
	check((n.errors or 0) == 0, "no errors")
end
do
	-- at the game's limit
	local n, M, main, S = boot({ sets = 10 })
	main:SetSheet("GearSets"); pump(M)
	local note = main.gsNote
	check(note:IsShown() and note.text.text == "10 of 10 gear sets", "at the limit the count says so: " .. tostring(note.text.text))
	check(not note.btn:IsEnabled() and note.btn.offReason == "You have the most sets the game allows (10). Delete one to make another.", "the button is greyed and says why")
	S:SectionMenu(n.GearSets.LaneId("Set 01"), main.frame)
	local new = menuItem(n, "New Gear Set...")
	check(new and new.disabled and new.tip == "You have the most sets the game allows (10). Delete one to make another.", "and so is New Gear Set... in a set's menu")
	n.menuFrame:Hide()
	-- delete one: usable again
	n.GearSets:Delete("Set 10"); pump(M)
	check(main.gsNote.text.text == "9 of 10 gear sets" and main.gsNote.btn:IsEnabled() and not main.gsNote.btn.offReason, "one set fewer: the button is usable again")
	-- back to no sets: the first-time note, with its own words on the button
	for i = 1, 9 do n.GearSets:Delete(("Set %02d"):format(i)) end; pump(M)
	check(main.gsNote.text.text == "No gear sets yet." and main.gsNote.btn.label.text == "Create Gear Set" and main.gsNote.btn:IsEnabled(), "with the last set gone, the first-time note is back")
	-- other tabs don't get it
	M.addSet("Again", { [5] = 0x00300000 + 5 }); n.GearSets:Changed(); pump(M)
	main:SetSheet("All"); pump(M)
	check(not main.gsNote:IsShown(), "the button is on the Gear Sets sheet only")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- another character's bags: no button (their sets aren't yours to make)
	local n, M, main = boot({ sets = 2 })
	main:SetSheet("GearSets"); pump(M)
	n.ui.owner = "Someone - Realm"; main:Refresh(true); pump(M)
	check(not (main.gsNote:IsShown() and main.gsNote.btn:IsShown() and main.gsNote.btn.label.text == "New Gear Set"), "looking at another character's bags: no New Gear Set button")
	n.ui.owner = nil
end

------------------------------------------------------------------------
-- 2. New Section From This Item: the newer kinds of rule
------------------------------------------------------------------------
do
	local n, M, main, S, R = boot()
	local function facts(id) local t = {}; for _, f in ipairs(R:FactsOf(recOf(n, id))) do t[#t + 1] = f.label .. ": " .. f.text end return table.concat(t, " | ") end
	check(facts(2589) == "Type: Trade Goods: Cloth | Quality: Common | Crafting Material: Yes" or facts(2589):find("Crafting Material: Yes", 1, true), "cloth: Crafting Material is offered: " .. facts(2589))
	check(facts(117):find("Consumable: Food", 1, true) and not facts(117):find("Crafting Material", 1, true), "jerky: its kind of consumable, Food: " .. facts(117))
	check(facts(159):find("Consumable: Drink", 1, true), "water: Drink: " .. facts(159))
	check(facts(9003):find("Quest Item: Yes", 1, true), "sealed orders: Quest Item: " .. facts(9003))
	check(facts(9001):find("Usable by Me: Yes", 1, true), "a robe this character can wear: Usable by Me: Yes: " .. facts(9001))
	check(facts(9002):find("Usable by Me: No", 1, true), "a plate helm it can't: Usable by Me: No: " .. facts(9002))
	check(not facts(2589):find("Usable by Me", 1, true) and not facts(117):find("Usable by Me", 1, true) and not facts(9004):find("Usable by Me", 1, true),
		"Usable by Me isn't offered for cloth, food or a trinket box (it is always yes for those)")
	check(not facts(9004):find("Quest Item", 1, true) and not facts(9004):find("Crafting Material", 1, true) and not facts(9004):find("Consumable", 1, true),
		"only what is true of the item is offered: " .. facts(9004))
	check(not facts(2589):find("ItemTree", 1, true) and not facts(2589):find("Used by My Professions", 1, true), "without ItemTree, none of its facts")
	-- the first four are still first, and Type is the one ticked to start
	local f1 = R:FactsOf(recOf(n, 9002))
	check(f1[1].k == "type" and f1[2].k == "slot" and f1[3].k == "quality" and f1[4].k == "bind" and f1[5].k == "usable", "Type, Slot, Quality and Binding come first, then the newer ones")

	-- the window: tick Usable by Me: No on the helm and a section of gear you can't use is made
	local f = S:PromptFromItem(recOf(n, 9002)); pump(M)
	local labels = {}
	for i, c in ipairs(f.checks) do if c:IsShown() then labels[#labels + 1] = plain(c.label.text) end end
	check(table.concat(labels, " | "):find("Usable by Me: No", 1, true), "the window lists it: " .. table.concat(labels, " | "))
	check(f.on.type == true and not f.on.usable, "Type is ticked to start with, the rest are yours to add")
	for _, c in ipairs(f.checks) do if c:IsShown() and c.key == "type" then c:SetChecked(false); click(c) end end
	for _, c in ipairs(f.checks) do if c:IsShown() and c.key == "usable" then c:SetChecked(true); click(c) end end
	local rules = S:FromItemRules()
	check(#rules.rows == 1 and rules.rows[1].k == "usable" and rules.rows[1].v[1] == "yes" and rules.rows[1].n == true, "Usable by Me: No is the rule \"Usable by Me is not Yes\"")
	local names = {}
	for _, r in ipairs(f.preview.here) do names[#names + 1] = r.name end
	check(table.concat(names, ", ") == "Plate Helm", "the list of what would go in follows: " .. table.concat(names, ", "))
	f.edit:SetText("Can't Use"); click(f.create); pump(M)
	local made
	for _, c in ipairs(S:Customs()) do if c.name == "Can't Use" then made = c end end
	check(made and made.rules and made.rules.rows[1].k == "usable" and made.rules.rows[1].n == true, "Create Section makes it with that rule")
	check(recOf(n, 9002).cat == made.id and recOf(n, 9001).cat ~= made.id, "and the helm goes in, the robe doesn't")
	check(R:RowText(made.rules.rows[1]) == "Usable by Me is not Yes" or plain(R:RowText(made.rules.rows[1])):find("Usable by Me", 1, true), "Settings reads the rule in words: " .. tostring(R:RowText(made.rules.rows[1])))

	-- food: a section of food from the jerky
	f = S:PromptFromItem(recOf(n, 117)); pump(M)
	for _, c in ipairs(f.checks) do if c:IsShown() and c.key == "type" then c:SetChecked(false); click(c) end end
	for _, c in ipairs(f.checks) do if c:IsShown() and c.key == "cons" then c:SetChecked(true); click(c) end end
	names = {}
	for _, r in ipairs(f.preview.here) do names[#names + 1] = r.name end
	check(table.concat(names, ", ") == "Tough Jerky", "Consumable: Food from the jerky takes the jerky and not the water: " .. table.concat(names, ", "))
	f:Hide()
	check((n.errors or 0) == 0, "no errors")
end
do
	-- with ItemTree: what it knows of the item, marked as its own
	local n, M, main, S, R = boot({ itemTree = { [2589] = { prof = true, vendor = true }, [9001] = { upgrade = true }, [9003] = { quest = true } } })
	local IT = n.ItemTree
	check(IT and IT:Enabled(), "(set up: ItemTree's rules are in use)")
	pump(M)
	local function facts(id) local t = {}; for _, f in ipairs(R:FactsOf(recOf(n, id))) do t[#t + 1] = f.label .. ": " .. f.text .. (f.addon and " [" .. f.addon .. "]" or "") end return table.concat(t, " | ") end
	facts(2589); facts(9001); facts(9003); pump(M)   -- (ItemTree is asked; its answers come a moment later)
	check(facts(2589):find("Used by My Professions: Yes [ItemTree]", 1, true) and facts(2589):find("Sold by Vendors: Yes [ItemTree]", 1, true), "cloth ItemTree knows: Used by My Professions, Sold by Vendors: " .. facts(2589))
	check(not facts(2589):find("An Upgrade for Me", 1, true) and not facts(2589):find("Needed for a Quest", 1, true), "and not what isn't true of it")
	check(facts(9003):find("Needed for a Quest: Yes [ItemTree]", 1, true), "sealed orders: Needed for a Quest: " .. facts(9003))
	local f = S:PromptFromItem(recOf(n, 2589)); pump(M)
	local teal
	for _, c in ipairs(f.checks) do if c:IsShown() and c.key == "it_prof" then teal = c.label.text end end
	check(teal and teal:find("Used by My Professions: Yes |cff9fe6e1(ItemTree)|r", 1, true), "in the window ItemTree's are marked, in its teal: " .. tostring(teal))
	f:Hide()
	-- its rules turned off: not offered
	n:Set("useItemTree", false); pump(M)
	check(not facts(2589):find("ItemTree", 1, true), "with Section and Filter Rules off for ItemTree, none of them")
	check((n.errors or 0) == 0, "no errors")
end
for _, screen in ipairs({ 768, 668 }) do
	-- the window with a lot to tick still fits the screen: the list of what would go in gives up rows
	local n, M, main, S, R = boot({ screen = screen, itemTree = { [9002] = { prof = true, vendor = true, upgrade = true, quest = true } } })
	for i = 9, 16 do M.put(0, i, { id = 9100 + i, name = "Plate Thing " .. i, q = 2, count = 1, class = 4, subclass = 4, type = "Armor", sub = "Plate", equip = "INVTYPE_HEAD", bind = 2, price = 400, ilvl = 40 }) end
	M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); pump(M)
	R:FactsOf(recOf(n, 9002)); pump(M)
	local f = S:PromptFromItem(recOf(n, 9002)); pump(M)
	local ticks, rows = 0, 0
	for _, c in ipairs(f.checks) do if c:IsShown() then ticks = ticks + 1 end end
	for _, r in ipairs(f.rows) do if r:IsShown() then rows = rows + 1 end end
	check(ticks >= 9, ("screen %d: (set up: %d things to tick)"):format(screen, ticks))
	check(f:GetHeight() <= screen - 40, ("screen %d: the window is %d tall with %d ticks and %d items listed: it fits"):format(screen, f:GetHeight(), ticks, rows))
	check(rows >= 3 and #f.preview.here >= 8, ("screen %d: at least three of the %d items are still listed (%d)"):format(screen, #f.preview.here, rows))
	check(f.more:IsShown() or rows == #f.preview.here, "and the rest are counted (\"and N more\")")
	f:Hide()
end

------------------------------------------------------------------------
-- 3. A menu too long for the screen shows arrows
------------------------------------------------------------------------
do
	local n, M = boot({ screen = 668 })
	local picked
	local items = {}
	for i = 1, 40 do items[i] = { text = "Entry " .. i, onClick = function() picked = i end } end
	n.ShowMenu(items, n.Window.main.frame)
	local m = n.menuFrame
	local rows = shownRows(m)
	check(m:GetHeight() <= 668 - 40, "a menu of 40 entries on a short screen fits it (" .. m:GetHeight() .. " tall)")
	check(rows[1].arrowWhole and rows[#rows].arrowWhole, "its first and last rows are arrows")
	check(rows[1].arrowDir == nil and rows[#rows].arrowDir == 1, "at the top: the up arrow is dim, the down arrow lit")
	check(rows[2].text.text == "Entry 1", "the entries start right under the up arrow")
	local seen, guard = {}, 0
	local function collect() for _, r in ipairs(shownRows(m)) do if not r.arrowWhole and r.text.text ~= "" then seen[r.text.text] = true end end end
	collect()
	while shownRows(m)[#shownRows(m)].arrowDir == 1 and guard < 40 do click(shownRows(m)[#shownRows(m)]); collect(); guard = guard + 1 end
	local count = 0
	for _ in pairs(seen) do count = count + 1 end
	check(count == 40 and seen["Entry 40"], "clicking the down arrow walks to the end: all 40 entries were shown (" .. count .. ")")
	rows = shownRows(m)
	check(rows[#rows].arrowDir == nil and rows[1].arrowDir == -1, "at the end: the down arrow is dim, the up arrow lit")
	check(m:IsShown(), "an arrow doesn't close the menu")
	click(rows[1]); rows = shownRows(m)
	check(rows[#rows].arrowDir == 1, "the up arrow goes back")
	-- the wheel still moves it, and an entry still works
	local wheel = m:GetScript("OnMouseWheel")
	wheel(m, 1); wheel(m, 1); wheel(m, 1); wheel(m, 1); wheel(m, 1); wheel(m, 1); wheel(m, 1); wheel(m, 1)
	rows = shownRows(m)
	check(rows[2].text.text == "Entry 1" and rows[1].arrowDir == nil, "the mouse wheel still scrolls it, back to the top")
	click(rows[4])
	check(picked == 3 and not m:IsShown(), "and an entry still does its job and closes the menu")
	-- a menu that fits has no arrows
	local few = {}
	for i = 1, 8 do few[i] = { text = "Short " .. i, onClick = function() end } end
	n.ShowMenu(few, n.Window.main.frame)
	rows = shownRows(m)
	check(#rows == 8 and not rows[1].arrowWhole and not rows[8].arrowWhole, "a menu that fits has no arrows")
	m:Hide()
	-- a list inside a menu (the sections on an item's menu) keeps its own arrows, and gets no second pair
	local grouped = { { text = "An Item", big = true } }
	for i = 1, 30 do grouped[#grouped + 1] = { text = "Section " .. i, group = true, onClick = function() end } end
	grouped[#grouped + 1] = { text = "Something Else", onClick = function() end }
	n.ShowMenu(grouped, n.Window.main.frame)
	rows = shownRows(m)
	local whole, list = 0, 0
	for _, r in ipairs(rows) do if r.arrow:IsShown() then if r.arrowWhole then whole = whole + 1 else list = list + 1 end end end
	check(list == 2 and whole == 0, "a list inside a menu keeps its two arrows and gets no others")
	check(rows[#rows].text.text == "Something Else", "and what comes after the list stays in reach")
	m:Hide()
end
do
	-- the case that showed it: the Filters window's + Add a Rule with ItemTree's rules, at the game's largest UI scale
	local n, M, main = boot({ screen = 668, itemTree = {} })
	local P = n.Popups
	P:OpenFilters(main, "browse"); pump(M)
	local ff = P.filter
	ff.list:AddMenu(ff.add)
	local m = n.menuFrame
	local rows = shownRows(m)
	check(#m.items > #rows - 2, ("(set up: %d entries, more than the %d rows the screen has room for)"):format(#m.items, #rows))
	check(rows[#rows].arrowWhole and rows[#rows].arrowDir == 1, "the menu ends in a lit down arrow: there is more")
	local guard = 0
	while shownRows(m)[#shownRows(m)].arrowDir == 1 and guard < 20 do click(shownRows(m)[#shownRows(m)]); guard = guard + 1 end
	local last
	for _, r in ipairs(shownRows(m)) do if not r.arrowWhole then last = r.text.text end end
	check(last == m.items[#m.items].text, "and the last entry can be reached: " .. tostring(last))
	m:Hide(); ff:Hide()
	-- on a usual screen the same menu fits, with no arrows
	n, M, main = boot({ screen = 768, itemTree = {} })
	P = n.Popups
	P:OpenFilters(main, "browse"); pump(M)
	ff = P.filter
	ff.list:AddMenu(ff.add)
	rows = shownRows(n.menuFrame)
	check(#rows == #n.menuFrame.items and not rows[1].arrowWhole, "on a usual screen it shows whole, no arrows")
	n.menuFrame:Hide(); ff:Hide()
end

------------------------------------------------------------------------
-- 4. The window for the long lists grows where the screen has room
------------------------------------------------------------------------
for _, case in ipairs({ { 768, 640 }, { 668, 608 }, { 1200, 640 } }) do
	local screen, tall = case[1], case[2]
	local n, M, main, S = boot({ screen = screen, types = true })
	local E = n.SectionEditor
	local f = S:EditSection(); pump(M)
	local p = E:OpenPicker(nil, "type")
	check(p:GetHeight() == tall, ("screen %d: the Type list's window is %d tall (was 440): %d"):format(screen, tall, p:GetHeight()))
	check(p.scroll:GetHeight() == tall - 210, ("its list shows %d (was 230)"):format(tall - 210))
	check(p:GetHeight() <= screen - 60, "and fits the screen")
	local closed = #shownRows(p)
	E.pick.open[2] = true; E:RefreshPicker()
	check(p:GetHeight() == tall and #shownRows(p) > closed, "opening a kind of item doesn't change the window's size")
	check(p.scroll.ScrollBar:IsShown() == (#shownRows(p) * 22 > tall - 210), "the scroll bar shows when the list is longer than its view")
	p:Hide()
	p = E:OpenPicker(nil, "slot")
	check(p:GetHeight() == tall, ("screen %d: the Slot list (%d lines) gets the tall window too"):format(screen, #shownRows(p)))
	p:Hide(); f:Hide()
end
do
	-- a short list keeps the window it had
	local n, M, main, S = boot({ screen = 768 })
	local E = n.SectionEditor
	local f = S:EditSection(); pump(M)
	local p = E:OpenPicker(nil, "slot")
	check(#shownRows(p) <= 10 and p:GetHeight() == 440 and p.scroll:GetHeight() == 230, ("a short list (%d lines) keeps the 440 window"):format(#shownRows(p)))
	p:Hide(); f:Hide()
	check(n.RuleList.PICKER_H == 440 and n.RuleList.PICKER_MAX == 640, "(the two sizes)")
end

------------------------------------------------------------------------
-- 5. The changelog and the version
------------------------------------------------------------------------
do
	local function slurp(p) local f = assert(io.open(p, "r")); local s = f:read("*a"); f:close(); return s end
	local top = slurp("BagSmith/CHANGELOG.md"):match("^## 1%.11%.0\n(.-)\n## 1%.10%.1\n")
	check(top ~= nil, "the changelog opens with 1.11.0, above 1.10.1")
	check(top and top:find("New:\n%- Gear sets can be made from your bags any time%.") and top:find("\n%- New Section From This Item offers more to tick"), "its New lines: gear sets, New Section From This Item")
	check(top and top:find("\nChanged:\n%- A menu too long for your screen shows arrows") and top:find("\n%- The lists for a Type, Slot or Section rule open in a taller window"), "its Changed lines: the arrows, the taller list window")
	check(top and not top:find("\226\128\148"), "no dashes")
	check(slurp("BagSmith/BagSmith.toc"):find("## Version: 1%.11%.0"), "the TOC version is 1.11.0's (the exact one is pinned in tests/run.lua)")
end
