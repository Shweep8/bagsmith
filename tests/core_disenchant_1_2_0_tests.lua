;(function()
	-- 1.2.0: the Disenchant Helper: eligibility, expectations, prices, verdicts, the secure button, the cast loop, the log
	package.loaded.mock = nil
	local M = require("mock")
	local DEID = 13262
	-- the bags: boots (uncommon armor 23), a dagger (uncommon weapon 33), a rare chest (ilvl 45), an epic (ilvl 60),
	-- a favorite, a gear-set piece, a potion, a bag, a high-level piece the skill cannot do, a common white sword
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
	M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
	M.put(0, 3, { id = 7003, name = "Rare Chest", q = 3, count = 1, class = 4, subclass = 2, price = 2000, ilvl = 45, equip = "INVTYPE_CHEST" })
	M.put(0, 4, { id = 7004, name = "Epic Blade", q = 4, count = 1, class = 2, subclass = 7, price = 50000, ilvl = 60, equip = "INVTYPE_WEAPON" })
	M.put(0, 5, { id = 7005, name = "Loved Ring", q = 2, count = 1, class = 4, subclass = 0, price = 300, ilvl = 30, equip = "INVTYPE_FINGER" })
	M.put(1, 1, { id = 7006, name = "Set Helm", q = 3, count = 1, class = 4, subclass = 3, price = 900, ilvl = 40, equip = "INVTYPE_HEAD" })
	M.put(1, 2, { id = 7007, name = "Minor Healing Potion", q = 1, count = 5, class = 0, subclass = 1, price = 1, ilvl = 5, equip = "" })
	M.put(1, 3, { id = 7008, name = "Grand Mace", q = 2, count = 1, class = 2, subclass = 4, price = 3000, ilvl = 63, equip = "INVTYPE_2HWEAPON" })
	M.put(1, 4, { id = 7009, name = "Plain Sword", q = 1, count = 1, class = 2, subclass = 7, price = 50, ilvl = 20, equip = "INVTYPE_WEAPON" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
	-- the character: Enchanting 150, Disenchant known
	local known, skill = true, 150
	_G.IsSpellKnown = function(id) return known and id == DEID end
	_G.GetNumSkillLines = function() return 2 end
	_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, skill end
	_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
	local drivers = {}
	_G.RegisterStateDriver = function(frame, state, cond) drivers[#drivers + 1] = { frame, state, cond } end
	_G.UnregisterStateDriver = function() end
	local combat = false; _G.InCombatLockdown = function() return combat end
	_G.GetCVar = function(k) if k == "autoLootDefault" then return "1" end end
	-- Auctionator with prices for items and materials (copper); some missing on purpose
	local prices = { [7001] = 1500, [7002] = 1000, [7003] = 9000, [7004] = 400000, [7008] = 20000,
		[10940] = 120, [10938] = 300, [10939] = 500, [10978] = 800, [11083] = 150, [11082] = 900, [11138] = 1200, [11177] = 2500, [20725] = 90000 }
	_G.Auctionator = { API = { v1 = {
		GetAuctionPriceByItemLink = function(caller, link) assert(caller == "BagSmith"); local id = tonumber(link:match("item:(%d+)")); return id and prices[id] end,
		GetAuctionPriceByItemID = function(caller, id) assert(caller == "BagSmith"); return prices[id] end,
		GetAuctionAgeByItemLink = function() return nil end,
	} } }
	-- the game's loot chat strings, and the loot window for players with auto-loot off
	_G.LOOT_ITEM_SELF = "You receive loot: %s."; _G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
	_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."; _G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
	local lootNow = {}
	_G.GetNumLootItems = function() return #lootNow end
	_G.GetLootSlotLink = function(i) return lootNow[i] and ("|Hitem:" .. lootNow[i][1] .. ":0|h[m]|h") end
	_G.GetLootSlotInfo = function(i) return nil, "m", lootNow[i] and lootNow[i][2] or 1 end
	-- the materials' names, which the mock only knows for items in bags
	local MATNAMES = { [10940] = "Strange Dust", [11083] = "Soul Dust", [11137] = "Vision Dust", [11176] = "Dream Dust", [16204] = "Illusion Dust", [10938] = "Lesser Magic Essence", [10939] = "Greater Magic Essence", [10998] = "Lesser Astral Essence", [11082] = "Greater Astral Essence", [11134] = "Lesser Mystic Essence", [11135] = "Greater Mystic Essence", [11174] = "Lesser Nether Essence", [11175] = "Greater Nether Essence", [16202] = "Lesser Eternal Essence", [16203] = "Greater Eternal Essence", [10978] = "Small Glimmering Shard", [11084] = "Large Glimmering Shard", [11138] = "Small Glowing Shard", [11139] = "Large Glowing Shard", [11177] = "Small Radiant Shard", [11178] = "Large Radiant Shard", [14343] = "Small Brilliant Shard", [14344] = "Large Brilliant Shard", [20725] = "Nexus Crystal" }
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(link) local id = tonumber(tostring(link):match("item:(%d+)")) or link; if MATNAMES[id] then return MATNAMES[id] end return realInfo(link) end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE = n.Disenchant
	n.Marks:ToggleFavorite({ itemID = 7005, name = "Loved Ring", link = "item:7005" })
	local function tagSet() for _, r in ipairs(n.items) do if r.itemID == 7006 then r.gearSets = { "Tank" } end end end   -- (the mock has no equipment sets: re-tagged after each rescan)
	tagSet()
	-- expectations from the shipped table
	local boots = { quality = 2, ilvl = 23, classID = 4 }
	local list, key = DE:Expectation(boots)
	check(key == "2:3:a" and list[1][1] == 10940 and list[1][2] == 0.75 and list[2][1] == 10939 and list[2][2] == 0.20 and list[3][1] == 10978 and list[3][2] == 0.05, "uncommon armor 23: Strange Dust 75%, Greater Magic Essence 20%, Small Glimmering Shard 5%")
	local wl, wk = DE:Expectation({ quality = 2, ilvl = 33, classID = 2 })
	check(wk == "2:5:w" and wl[1][2] == 0.20 and wl[2][1] == 11082 and wl[2][2] == 0.75, "uncommon weapon 33: essence favored over dust")
	check(select(2, DE:Expectation({ quality = 3, ilvl = 45, classID = 4 })) == "3:5" and DE:Expectation({ quality = 3, ilvl = 45, classID = 4 })[1][1] == 11177, "rare 45: a Small Radiant Shard")
	check(DE:Expectation({ quality = 4, ilvl = 60, classID = 2 })[1][1] == 20725 and DE:Expectation({ quality = 4, ilvl = 50, classID = 2 })[1][1] == 11178, "epic 60: a Nexus Crystal; epic 50: the bracket's shard")
	check(DE.SkillFor(23) == 25 and DE.SkillFor(60) == 200 and DE.SkillFor(63) == 225 and DE.SkillFor(5) == 1, "skill gates by item level")
	-- eligibility, one reason each
	local function recOf(id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
	local function why(id) local ok, w = DE:Eligible(recOf(id), DE:Skill()); return ok or w end
	check(why(7001) == true and why(7002) == true and why(7003) == true, "boots, dagger and the rare chest are eligible")
	check(why(7004) == "epic" and why(7005) == "favorite" and why(7006) == "gear set" and why(7007) == "not weapon or armor" and why(7008) == "skill" and why(7009) == "common", "an epic (off by default), a favorite, a gear-set piece, a potion, a piece beyond the skill and a white sword each stay out for their own reason")
	n:Set("deIncludeEpics", true); skill = 300
	check(why(7004) == true, "Include Epics lets the epic in (with the skill for it)")
	n:Set("deIncludeEpics", false); skill = 150
	-- refundable and still-tradeable items: out by default, in when the setting is off
	local refundSlot = nil
	_G.C_Container.GetContainerItemPurchaseInfo = function(bag, slot) if bag == 0 and slot == refundSlot then return 100, 1, 3600 end return 0, 0, 0 end
	refundSlot = 1
	check(why(7001) == "refundable", "an item still inside its refund window is left out")
	n:Set("deSkipRefundable", false)
	check(why(7001) == true, "with the setting off it is considered")
	n:Set("deSkipRefundable", true); refundSlot = nil
	check(why(7001) == true, "(and out of the refund window it is considered again)")
	-- values and verdicts (margin 10%)
	DE:Show()
	local byId = {}; for _, e in ipairs(DE.entries) do byId[e.itemID] = e end
	local eb = byId[7001]
	check(eb and eb.vendor == 500 and eb.ah == 1500 and eb.mats == math.floor(0.75 * 5 * 120 + 0.20 * 2.5 * 500 + 0.05 * 800 + 0.5) and eb.verdict == "ah", ("the boots (bracket 21-25: dust 4-6, essence 2-3): vendor 5s, AH 15s, mats %s: Sell at AH"):format(tostring(eb and eb.mats)))
	local ed = byId[7002]
	check(ed and ed.mats == math.floor(0.20 * 3.5 * 150 + 0.75 * 1.5 * 900 + 0.05 * 1200 + 0.5) and ed.mats >= 1100 and ed.verdict == "de", "the dagger: essence-heavy mats beat 10s on the AH by more than 10%: Disenchant")
	local ec = byId[7003]
	check(ec and ec.mats == 2500 and ec.ah == 9000 and ec.verdict == "ah", "the rare chest: one shard at 25s against 90s on the AH: Sell at AH")
	check(DE.entries[1] == ed and DE.current == ed, "the list leads with the Disenchant verdicts and the first is armed")
	-- the margin setting changes verdicts
	n:Set("deMargin", 2); M.runTimers()
	byId = {}; for _, e in ipairs(DE.entries) do byId[e.itemID] = e end
	check(byId[7002].verdict == "ah", "at a 200% margin the dagger is no longer worth disenchanting: Sell at AH")
	prices[7003] = 1000; DE:Refresh(); byId = {}; for _, e in ipairs(DE.entries) do byId[e.itemID] = e end
	check(byId[7003].verdict == "vendor" and DE.VERDICT_TEXT.vendor == "Vendor" and DE.VERDICT_TEXT.ah == "Sell at AH", "with the vendor paying more than the AH (and the mats not winning) the recommendation is Vendor")
	prices[7003] = nil; DE:Refresh(); byId = {}; for _, e in ipairs(DE.entries) do byId[e.itemID] = e end
	check(byId[7003].verdict == "vendor", "with no AH price for the item it is Vendor too")
	prices[7003] = 9000
	n:Set("deMargin", 0.10); M.runTimers()
	n:Set("deMargin", 10)
	check(n.db.deMargin == 2, "the margin is a fraction (0.10 is 10%); a value past the 200% ceiling is held to it")
	n:Set("deMargin", 0.10); M.runTimers()
	-- a material with no price: the verdict is unknown and names the material
	prices[11082] = nil; DE:Refresh()
	byId = {}; for _, e in ipairs(DE.entries) do byId[e.itemID] = e end
	check(byId[7002].verdict == "unknown" and byId[7002].missing == 11082 and DE:ValueText(byId[7002].mats, "mats", byId[7002]) == "no price yet" and DE.NoPriceTip("Greater Astral Essence"):find("run an Auctionator scan", 1, true), "a material without a price makes the verdict unknown, names the material, and the tooltip says to scan")
	prices[11082] = 900
	-- no Auctionator: dashes, the install note, and "your call" verdicts
	local savedA = _G.Auctionator; _G.Auctionator = nil; DE:Refresh()
	byId = {}; for _, e in ipairs(DE.entries) do byId[e.itemID] = e end
	check(byId[7001].verdict == "call" and DE:ValueText(nil, "ah") == "-" and DE:ValueText(nil, "mats", byId[7001]) == "-" and DE.frame.status.text:find("AH prices need Auctionator", 1, true) and DE.NO_AUCTIONATOR:find("Install Auctionator", 1, true), "without Auctionator the columns show dashes, the note says to install it, and no recommendation is made")
	_G.Auctionator = savedA; DE:Refresh()
	-- the secure button: armed for the current item, type spell, blanked in combat by the state driver, re-armed after
	local b = DE:Button()
	-- (1.5.3, by design) the spell is given by its ID, which works in every language (it was the English name)
	check(b:GetAttribute("type") == "spell" and b:GetAttribute("spell") == DEID and b:GetAttribute("target-bag") == 0 and b:GetAttribute("target-slot") == 2 and #drivers == 1 and drivers[1][3] == "[combat] lock; open", "the secure button is armed for the dagger with a combat state driver")
	combat = true
	DE:Select(DE.entries[2])
	check(DE.armPending == DE.entries[2] and b:GetAttribute("target-slot") == 2, "in combat the arming waits (no attribute changes)")
	combat = false; M.fire("PLAYER_REGEN_ENABLED"); M.runTimers()
	check(DE.armPending == nil and b:GetAttribute("target-slot") ~= nil, "after combat the pending arming lands")
	-- the cast loop: PreClick stamps the action, success waits for the loot, the loot is recorded, the list moves on
	DE:Select(DE.entries[1])
	local cur = DE.current
	b:GetScript("PreClick")(b)
	check(n.Prompts.lastActionWhat == "disenchant" and DE.castingEntry == cur, "clicking the button stamps a BagSmith action and remembers which item is being cast on")
	local clock = GetTime(); local realGetTime = GetTime; _G.GetTime = function() return clock end
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", DEID)
	local log = DE:Log()["2:5:w"]
	check(log and log.n == 1 and next(log.mats) == nil and DE.castOpen and DE.castOpen.key == "2:5:w" and DE.done == 1, "the cast succeeding counts it under its bracket at once, with the materials still to come")
	-- auto-loot: the materials arrive as loot chat lines, matched to the cast within its window
	M.fire("CHAT_MSG_LOOT", "You receive loot: |cff1eff00|Hitem:11082:0:0:0:0:0:0:0|h[Greater Astral Essence]|h|rx2.")
	M.fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:11083:0:0:0:0:0:0:0|h[Soul Dust]|h|r.")
	check(log.mats[11082] == 2 and log.seen[11082] == 1 and log.mats[11083] == 1 and log.n == 1, "the loot chat records each material against the cast (x2 and a single)")
	check(DE.session and DE.session.done == 1 and DE.session.mats[11082] == 2 and DE.session.mats[11083] == 1, "and the sitting's summary counts them")
	-- the item leaving its slot moves the list on, with nothing waited for
	M.bags[0][2] = nil; M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers(); tagSet()
	check(DE.current and DE.current.itemID ~= 7002, "with the dagger gone the next item is armed")
	-- a loot line after the window is not the cast's
	clock = clock + DE.LOOT_WINDOW + 1
	M.fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:11083:0:0:0:0:0:0:0|h[Soul Dust]|h|rx5.")
	check(log.mats[11083] == 1 and DE.castOpen == nil, "a loot line past the window is somebody else's: not recorded")
	-- a player with auto-loot off: the loot window's slots, not the chat, and the chat is then ignored for that cast
	DE:Select(DE.entries[1]); b:GetScript("PreClick")(b); local cur2 = DE.current
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", DEID)
	local key2 = DE.castOpen.key
	-- a material the item's bracket can produce (the bracket's first shipped material)
	local matId = DE:Expectation(cur2.rec)[1][1]
	lootNow = { { matId, 3 } }
	M.fire("LOOT_OPENED")
	M.fire("CHAT_MSG_LOOT", ("You receive loot: |cffffffff|Hitem:%d:0:0:0:0:0:0:0|h[mat]|h|rx3."):format(matId))
	local log2 = DE:Log()[key2]
	check(log2.mats[matId] == 3 and log2.seen[matId] == 1, "the loot window records the materials once, and the chat line for the same loot is not counted twice")
	_G.GetTime = realGetTime
	-- a failed cast re-arms the same item
	M.bags[cur2.bag][cur2.slot] = nil; M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers(); tagSet(); DE:Refresh()
	local before = DE.current
	b:GetScript("PreClick")(b); M.fire("UNIT_SPELLCAST_FAILED", "player", "cast-3", DEID)
	check(DE.castingEntry == nil and DE.current and before and DE.current.itemID == before.itemID and DE.current.slot == before.slot, "a failed cast keeps the same item armed")
	-- calibration: once a bracket has enough of your results they take over
	for i = 1, 19 do DE:Record("2:3:a", { { id = 10940, count = 2 } }) end
	local list2, basis, count = DE:Expected(recOf(7001))
	check(basis == "estimate" and count == 19, "nineteen results: still the estimate")
	DE:Record("2:3:a", { { id = 10940, count = 2 } })
	list2, basis, count = DE:Expected(recOf(7001))
	check(basis == "yours" and count == 20 and list2[1][1] == 10940 and math.abs(list2[1][2] - 2) < 1e-9 and #list2 == 1 and list2[1].seen == 20, "twenty results: your own averages take over for the bracket (2 Strange Dust per cast, seen in 20 of 20)")
	local lines, head = DE:LikelyLines(recOf(7001))
	check(head == "from 20 of your results" and lines[1] == "Strange Dust: 2.0 per cast, in 20 of 20", "the likely lines say how often each material showed up")
	local el, eh = DE:LikelyLines(recOf(7003))
	check(eh == "DE estimate, 0 of 20 in this range" and   -- (1.5.8, by design) the count reads "in this range"
		 el[1]:find("about 100%%", 1) and el[1]:find("^Small Radiant Shard: 1,"), "a bracket without your results shows the range and rough odds as a DE estimate with the progress toward your own results")
	local _, bh = DE:LikelyLines(recOf(7001))
	check(bh == "from 20 of your results", "and a graduated bracket says so")
	-- skip and never
	DE:Refresh(); local first = DE.current
	check(first ~= nil and #DE.entries >= 2, ("(setup) %d items to work through"):format(#DE.entries))
	DE:Skip()
	check(DE.current ~= first and DE.skipped[first.rec.guid or (first.bag .. ":" .. first.slot)], "Skip passes on the item for the session")
	local nv = DE.current
	DE:NeverCurrent()
	check(DE:Never()[nv.itemID] == true and DE.current ~= nv and why(nv.itemID) == "never", "Never keeps the item out for good")
	DE:ClearNever()
	check(next(DE:Never()) == nil, "the never list clears")
	-- mark as junk on a Sell verdict
	DE:Refresh()
	local sellE; for _, e in ipairs(DE.entries) do if e.verdict == "ah" or e.verdict == "vendor" then sellE = e; break end end
	if sellE then DE:Select(sellE); DE:JunkCurrent(); check(n.Junk:Marked(sellE.itemID), "Mark as Junk marks the current item") else check(true, "(no sale verdict to mark)") end
	-- the junk button only on a Vendor verdict, never on Sell at AH
	DE:Refresh(); local ahE, vE
	for _, e in ipairs(DE.entries) do if e.verdict == "ah" and not ahE then ahE = e end if e.verdict == "vendor" and not vE then vE = e end end
	if ahE then DE:Select(ahE); check(not DE.frame.junk:IsShown(), "Sell at AH: no Mark as Junk nudge") else check(true, "(no Sell at AH entry)") end
	-- the helper is off: the window refuses, the setting turning off hides it
	n:Set("deEnabled", false); M.runTimers()
	check(not DE.frame:IsShown(), "turning the helper off closes its window")
	-- a character without Disenchant
	known = false; n:Set("deEnabled", true); DE:Show()
	check(DE.frame.sub.text:find("cannot disenchant", 1, true), "a character without the ability is told so")
	known = true
	-- the keybinding and the settings page
	local names = {}; for _, kb in ipairs(n.KeyBinds.LIST) do names[kb[1]] = kb[2] end
	check(names["CLICK BagSmithDisenchantButton:LeftButton"] == "Disenchant Next Item" and _G["BINDING_NAME_CLICK BagSmithDisenchantButton:LeftButton"] == "Disenchant Next Item", "the Disenchant Next Item keybinding is listed and named")
	local SP = n.SettingsPanel; SP:Show(); SP:ShowPage("dehelper")
	local labels = {}
	for _, pool in ipairs({ SP.pools.check, SP.pools.step }) do for _, w in ipairs(pool) do if w:IsShown() then labels[w.key] = w.text.text end end end
	check(labels.deEnabled == "Disenchant Helper" and labels.deMargin and labels.deIncludeEpics == "Include Epics" and labels.deSkipRefundable, "the Disenchant Helper sub-page has its settings")
	SP:ShowPage("automation"); labels = {}
	for _, w in ipairs(SP.pools.check) do if w:IsShown() then labels[w.key] = w.text.text end end
	check(labels.autoConfirm and labels.autoConfirmEverywhere and not labels.deEnabled, "the Automations page has the Prompts section and not the helper's")
	SP:Hide()
end)()

