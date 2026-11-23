-- ======== 1.10.0-beta8 (Shweep, 22 Nov: "build small beta 8") ========
-- (1) The Disenchant Helper no longer holds back a piece ItemTree keeps in order to disenchant it. His screenshot:
-- Lupine Slippers of the Falcon, "Keep", "Disenchants into Strange Dust", held back with "Nothing to disenchant"
-- ("This doesn't make sense to hold it back for DE helper, right?"). ItemTree's state for that keep is
-- "keepDisenchant"; any other keep (his Enchanted Moonstalker Cloak, kept for a quest) is still held. The Loot Helper
-- holds both, as before.
-- (2) Settings > General: one card, Other Addons, for auction prices, ItemTree and Pawn ("should we consider also
-- putting the AH price stuff under Other Addons?"; "Yes rename the label"): Auction Price Source.
-- (3) Hold Back Pawn Upgrades, off unless you turn it on ("off for holding it back should be default"): the Disenchant
-- Helper won't offer a piece Pawn says is an upgrade. Pawn's arrows and the Loot Helper's protection are as they were.
--
-- The two fact tables below are ItemTree v1.2.8's real answers on Shweep's priest, as his /run printed them (22 Nov).

local TEAL = "|cff9fe6e1ItemTree|r"
local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function deep(t) if type(t) ~= "table" then return t end local c = {}; for k, v in pairs(t) do c[k] = deep(v) end; return c end
local function click(b) b:GetScript("OnClick")(b) end
local function pump(M) for _ = 1, 40 do M.runTimers() end end

local FIVE = { "Cooking", "Enchanting", "First Aid", "Fishing", "Tailoring" }
local function uses(current, quest)
	return { reagentSkills = {}, current = current, stale = 0, professions = FIVE, kinds = { reagent = 0, lock = 0, spell = 0, quest = quest or 0, tool = 0, teaches = 0 } }
end
local function noQuests() return { stale = false, needs = {}, titles = {}, predicted = {}, starts = {}, counts = {}, staleAfter = {} } end
local REAL = {
	[15012] = { itemId = 15012, known = true,   -- Lupine Slippers of the Falcon: kept for its dust
		price = { worthTrip = false, copper = 399, source = "auctionator" },
		keep = { lines = { "Keep", "Disenchants into Strange Dust, Enchanting (skill 20 to 70)", "Not for your class (leather)" }, always = false, marked = true, line = "Keep",
			gear = { specs = {}, upgrade = false, labels = {} }, valuable = false, noAuctionData = false, tags = { "keep" }, never = false, state = "keepDisenchant", off = false, byUse = true, legendary = false },
		route = { needed = false },
		vendors = { buyPrice = 1480, everywhere = false, count = 0 },
		uses = uses(0), quests = noQuests() },
	[5387] = { itemId = 5387, known = true, noDisenchant = true,   -- Enchanted Moonstalker Cloak: kept for a quest (and no price at all)
		keep = { lines = { "Keep (1)", "A Lost Master (II)", "Not an upgrade" }, always = false, marked = true, line = "Keep (1)",
			gear = { basis = "stats", specs = {}, upgrade = false, labels = {} }, valuable = false, noAuctionData = false, tags = { "keep" }, never = false, state = "keep", off = false, byUse = true, legendary = false },
		vendors = { everywhere = false, count = 0 },
		route = { needed = false },
		uses = uses(1, 1),
		quests = { stale = false, needs = { 993 }, titles = { [993] = "A Lost Master" }, predicted = {}, starts = {}, keepUpTo = 1, counts = { [993] = 1 }, staleAfter = {} } },
	[279898] = { itemId = 279898, known = true,   -- Dwarven Tome: an upgrade (his output of 22 Nov, as in the beta6 set)
		keep = { lines = { "Equip (Any spec)", "Upgrade for your Off Hand (slot empty)" }, always = false, marked = true, line = "Equip (Any spec)",
			gear = { basis = "empty", specs = { "discipline", "holy", "shadow" }, upgrade = true, labels = { "Discipline", "Holy", "Shadow" } },
			valuable = false, noAuctionData = false, tags = { "equip" }, never = false, state = "keep", off = false, byUse = true, legendary = false },
		vendors = { buyPrice = 1919, everywhere = false, count = 0 },
		route = { needed = false },
		uses = uses(0), quests = noQuests() },
}
local function fakeItemTree(state)
	state.calls, state.asked, state.requested = 0, {}, 0
	return {
		version = 1,
		IsReady = function() return state.ready ~= false end,
		RequestData = function() state.requested = state.requested + 1 end,
		RegisterReadyCallback = function(fn) state.onReady = fn end,
		RegisterChangeCallback = function(fn) state.onChange = fn end,
		GetItemFacts = function(id, link)
			state.calls = state.calls + 1
			state.asked[id] = (state.asked[id] or 0) + 1
			return deep(state.facts[id])
		end,
	}
end
-- Pawn, as BagSmith meets it: one global function asked by item link. nil is "not yet".
local function fakePawn(state)
	state.asked = {}
	_G.PawnShouldItemLinkHaveUpgradeArrow = function(link)
		local id = tonumber(tostring(link):match("item:(%d+)"))
		state.asked[id] = (state.asked[id] or 0) + 1
		if state.pending and state.pending[id] then return nil end
		return state.upgrades[id] or false
	end
	_G.PawnCommon = { ShowBagUpgradeAdvisor = state.advisor ~= false }
end
local function noPawn() _G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil end

-- The Disenchant Helper on an enchanter, with whatever is in `stock`. opts: it (ItemTree's state), pawn (Pawn's), prof.
local function deBoot(stock, opts)
	opts = opts or {}
	package.loaded.mock = nil
	local M = require("mock")
	local DEID = 13262
	stock(M)
	_G.ItemTreeAPI = opts.it and fakeItemTree(opts.it) or nil
	if opts.pawn then fakePawn(opts.pawn) else noPawn() end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local prof = { skin = "modern", deEnabled = true }
	for k, v in pairs(opts.prof or {}) do prof[k] = v end
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = prof } }
	_G.IsSpellKnown = function(id) return id == DEID end
	_G.GetNumSkillLines = function() return 2 end
	_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, 300 end
	_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
	_G.RegisterStateDriver = function() end
	_G.UnregisterStateDriver = function() end
	_G.INVTYPE_HOLDABLE = "Held In Off-hand"
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta8"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	return n, M, n.Disenchant
end
local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
local function names(list) local t = {}; for i, v in ipairs(list or {}) do t[i] = v end; table.sort(t); return table.concat(t, ", ") end
local function offeredNames(DE) local t = {}; for _, e in ipairs(DE.entries or {}) do t[#t + 1] = e.name end; table.sort(t); return table.concat(t, ", ") end
local function entry(DE, id) for _, e in ipairs(DE.entries or {}) do if e.itemID == id then return e end end end

local function hisBags(M)
	M.put(0, 1, { id = 15012, name = "Lupine Slippers of the Falcon", q = 2, count = 1, class = 4, subclass = 2, price = 296, ilvl = 16, equip = "INVTYPE_FEET", bind = 2 })
	M.put(0, 2, { id = 5387, name = "Enchanted Moonstalker Cloak", q = 2, count = 1, class = 4, subclass = 1, price = 150, ilvl = 20, equip = "INVTYPE_CLOAK" })
	M.put(0, 3, { id = 7003, name = "Rare Chest", q = 3, count = 1, class = 4, subclass = 2, price = 2000, ilvl = 45, equip = "INVTYPE_CHEST" })
	M.put(0, 4, { id = 279898, name = "Dwarven Tome", q = 2, count = 1, class = 4, subclass = 0, price = 480, ilvl = 24, equip = "INVTYPE_HOLDABLE", bind = 2 })
end

;(function()
	-- ItemTree's two kinds of Keep, read from its real answers
	local n, M, DE = deBoot(hisBags, {})
	local IT = n.ItemTree
	local slippers, cloak, tome = IT.Read(deep(REAL[15012])), IT.Read(deep(REAL[5387])), IT.Read(deep(REAL[279898]))
	check(slippers.kept == true and slippers.forDust == true, "Lupine Slippers: ItemTree keeps them, and for their dust (its state is keepDisenchant)")
	check(cloak.kept == true and cloak.forDust == false and cloak.quest == true, "Enchanted Moonstalker Cloak: kept, not for dust: a quest needs it")
	check(tome.kept == true and tome.forDust == false and tome.upgrade == true, "Dwarven Tome: kept, not for dust: an upgrade")
	check(table.concat(slippers.tags, "+") == "keep" and table.concat(cloak.tags, "+") == "keep", "(ItemTree's tags are the same for both keeps: only its state tells them apart)")
	-- the state is read only as ItemTree spells it
	check(IT.Read({ keep = { marked = true, state = "keepDisenchant" } }).forDust == true and IT.Read({ keep = { marked = true, state = "keep" } }).forDust == false, "keepDisenchant is for dust; keep is not")
	check(IT.Read({ keep = { marked = true, state = "KeepDisenchant" } }).forDust == false and IT.Read({ keep = { marked = true, state = 7 } }).forDust == false and IT.Read({ keep = { marked = true } }).forDust == false
		and IT.Read({ keep = "x" }).forDust == false and IT.Read({}).forDust == false, "anything else is not")
	local advice = IT.Read({ keep = { marked = false, state = "disenchant", tags = { "disenchant" } } })
	check(advice.kept == false and advice.forDust == false, "ItemTree's advice to disenchant a piece it doesn't keep: nothing is held either way")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- the Disenchant Helper with his two pieces: the slippers are offered, the cloak is held
	local it = { facts = deep(REAL) }
	local n, M, DE = deBoot(hisBags, { it = it })
	local IT = n.ItemTree
	DE:Show(); M.runTimers()
	check(offeredNames(DE) == "Lupine Slippers of the Falcon, Rare Chest", "the slippers ItemTree keeps for their dust are offered (" .. offeredNames(DE) .. ")")
	check(DE.held and DE.held.total == 2 and names(DE.held.by.itemtree) == "Dwarven Tome, Enchanted Moonstalker Cloak", "the cloak a quest needs and the tome that's an upgrade are held (" .. names(DE.held and DE.held.by.itemtree) .. ")")
	local lines = n.Why:Lines(DE.held)
	check(#lines == 1 and lines[1]:find("ItemTree says to keep (2):", 1, true) and not lines[1]:find("Lupine", 1, true), "Not offered: ItemTree says to keep (2), and the slippers aren't among them (" .. tostring(lines[1]) .. ")")
	local ok, why = DE:Eligible(recOf(n, 15012), DE:Skill())
	check(ok == true and why == nil, "the slippers are eligible")
	ok, why = DE:Eligible(recOf(n, 5387), DE:Skill())
	check(ok == false and why == "itemtree", "the cloak isn't: ItemTree says to keep it")
	check(it.asked[15012] == 1 and it.asked[5387] == 1 and it.asked[279898] == 1 and it.asked[7003] == 1, "each piece was asked about once")
	-- the two questions, one answer: the Loot Helper's is still yes for the slippers
	local asked = it.calls
	check(IT:Holds(recOf(n, 15012)) == true and IT:Holds(recOf(n, 15012), nil, true) == false and it.calls == asked, "the same answer serves both: held from destroying, not from disenchanting")
	check(IT:Holds(recOf(n, 5387)) == true and IT:Holds(recOf(n, 5387), nil, true) == true and it.calls == asked, "the cloak is held from both")
	check(IT:Holds(recOf(n, 7003)) == false and IT:Holds(recOf(n, 7003), nil, true) == false, "a piece ItemTree knows nothing about is held from neither")
	-- at the click
	local slip = entry(DE, 15012)
	DE:Select(slip)
	asked = it.asked[15012]
	check(DE:LiveCheck(slip) == true and it.asked[15012] == asked + 1, "the slippers pass the check at the click, asked fresh")
	it.facts[15012].keep.state = "keep"   -- (say they became an upgrade)
	local okNow, whyNow = DE:LiveCheck(slip)
	check(okNow == false and whyNow == "ItemTree says to keep that item", "ItemTree now keeps them for another reason: the click is refused (" .. tostring(whyNow) .. ")")
	DE:Refresh()
	check(offeredNames(DE) == "Rare Chest" and DE.held.total == 3, "and the list, drawn again, holds them back")
	it.facts[15012].keep.state = "keepDisenchant"
	it.onChange("stock"); pump(M); DE:Refresh()
	check(offeredNames(DE) == "Lupine Slippers of the Falcon, Rare Chest", "kept for their dust again: offered again")
	-- the option off: everything is offered, as in 1.9.8
	n:Set("itemTreeHold", false); M.runTimers()
	check(offeredNames(DE) == "Dwarven Tome, Enchanted Moonstalker Cloak, Lupine Slippers of the Falcon, Rare Chest" and DE.held.total == 0, "Hold Back off: all four are offered (" .. offeredNames(DE) .. ")")
	n:Set("itemTreeHold", true); M.runTimers()
	check(offeredNames(DE) == "Lupine Slippers of the Falcon, Rare Chest", "on again: the cloak and the tome are held, the slippers are not")
	check(it.requested == 0 and (n.errors or 0) == 0, "no errors, and ItemTree was never asked to load anything")
end)()

-- ======== Hold Back Pawn Upgrades ========
local function gear(M)
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
	M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
	M.put(0, 3, { id = 7003, name = "Rare Chest", q = 3, count = 1, class = 4, subclass = 2, price = 2000, ilvl = 45, equip = "INVTYPE_CHEST" })
end

;(function()
	-- off unless you turn it on
	local pawn = { upgrades = { [7002] = true } }
	local n, M, DE = deBoot(gear, { pawn = pawn })
	check(n.db.deHoldPawn == false, "Hold Back Pawn Upgrades is off unless you turn it on")
	DE:Show(); M.runTimers()
	check(offeredNames(DE) == "Rare Chest, Sturdy Boots, Worn Dagger" and DE.held.total == 0, "off: the Helper offers a Pawn upgrade, as it always has (" .. offeredNames(DE) .. ")")
	-- (Pawn is still asked for its arrows on icons; the Helper's own checks don't ask it while the option is off)
	local before = pawn.asked[7002] or 0
	check(DE:Eligible(recOf(n, 7002), DE:Skill()) == true and DE:LiveCheck(entry(DE, 7002)) == true and (pawn.asked[7002] or 0) == before, "and its checks, at the click too, don't ask Pawn")
	-- on
	n:Set("deHoldPawn", true); M.runTimers()
	check(offeredNames(DE) == "Rare Chest, Sturdy Boots", "on: the open Helper stops offering the dagger at once (" .. offeredNames(DE) .. ")")
	local ok, why = DE:Eligible(recOf(n, 7002), DE:Skill())
	check(ok == false and why == "pawn", "it isn't offered because Pawn says it's an upgrade (" .. tostring(why) .. ")")
	check(DE.held.total == 1 and names(DE.held.by.pawn) == "Worn Dagger", "and it's counted with the items not offered")
	local lines = n.Why:Lines(DE.held)
	check(#lines == 1 and lines[1]:find("Pawn upgrades (1):", 1, true) and lines[1]:find("Worn Dagger", 1, true), "under Pawn upgrades (" .. tostring(lines[1]) .. ")")
	local asked = pawn.asked[7001]
	DE:Refresh(); DE:Refresh()
	check(pawn.asked[7001] == asked, "Pawn's answer is remembered: not asked again each time the list is drawn")
	-- at the click: asked fresh; an upgrade, or no answer yet, is a no
	local boots = entry(DE, 7001)
	DE:Select(boots)
	check(DE:LiveCheck(boots) == true and pawn.asked[7001] == asked + 1, "(control) the boots pass at the click, with Pawn asked fresh")
	pawn.upgrades[7001] = true
	local okNow, whyNow = DE:LiveCheck(boots)
	check(okNow == false and whyNow == "Pawn says that item is an upgrade", "Pawn changes its mind: the click is refused (" .. tostring(whyNow) .. ")")
	pawn.upgrades[7001] = nil
	pawn.pending = { [7001] = true }
	okNow, whyNow = DE:LiveCheck(boots)
	check(okNow == false and whyNow == "Pawn hasn't decided yet whether that item is an upgrade", "Pawn can't say yet: the click is refused too (" .. tostring(whyNow) .. ")")
	pawn.pending = nil
	-- your gear changed: Pawn is asked again, and the list follows its new answers
	pawn.upgrades[7002] = false
	M.fire("PLAYER_EQUIPMENT_CHANGED"); pump(M)
	check(offeredNames(DE) == "Rare Chest, Sturdy Boots, Worn Dagger" and DE.held.total == 0, "after a gear change the dagger is no upgrade any more: offered again, with no click (" .. offeredNames(DE) .. ")")
	-- off again
	pawn.upgrades[7002] = true
	M.fire("PLAYER_EQUIPMENT_CHANGED"); pump(M)
	check(offeredNames(DE) == "Rare Chest, Sturdy Boots", "(an upgrade again: held again)")
	n:Set("deHoldPawn", false); M.runTimers()
	check(offeredNames(DE) == "Rare Chest, Sturdy Boots, Worn Dagger", "turned off: offered again at once")
	check((n.errors or 0) == 0, "no errors")
	noPawn()
end)()

;(function()
	-- Pawn says "not yet" the first time, then answers: the list follows without a click
	local pawn = { upgrades = { [7002] = true }, pending = { [7003] = true } }
	local n, M, DE = deBoot(gear, { pawn = pawn, prof = { deHoldPawn = true } })
	DE:Show()
	check(offeredNames(DE) == "Rare Chest, Sturdy Boots" and names(DE.held.by.pawn) == "Worn Dagger", "(Pawn hasn't answered about the chest yet: it's listed for now) (" .. offeredNames(DE) .. ")")
	check(select(2, DE:LiveCheck(entry(DE, 7003))) == "Pawn hasn't decided yet whether that item is an upgrade", "and a click on it is refused until Pawn answers")
	pawn.pending = nil
	pawn.upgrades[7003] = true
	pump(M)
	check(offeredNames(DE) == "Sturdy Boots" and names(DE.held.by.pawn) == "Rare Chest, Worn Dagger", "Pawn answers that it's an upgrade: the chest leaves the list by itself (" .. offeredNames(DE) .. ")")
	check((n.errors or 0) == 0, "no errors")
	noPawn()
end)()

;(function()
	-- Pawn's bag upgrade advisor off, and no Pawn at all, with the option on: nothing is held, nothing breaks
	local pawn = { upgrades = { [7002] = true }, advisor = false }
	local n, M, DE = deBoot(gear, { pawn = pawn, prof = { deHoldPawn = true } })
	DE:Show(); M.runTimers()
	check(offeredNames(DE) == "Rare Chest, Sturdy Boots, Worn Dagger" and DE.held.total == 0 and pawn.asked[7002] == nil, "Pawn's bag upgrade advisor off: nothing to hold back, and Pawn isn't asked")
	check(DE:LiveCheck(entry(DE, 7002)) == true, "and the click goes ahead")
	n, M, DE = deBoot(gear, { prof = { deHoldPawn = true } })
	DE:Show(); M.runTimers()
	check(offeredNames(DE) == "Rare Chest, Sturdy Boots, Worn Dagger" and DE:LiveCheck(entry(DE, 7002)) == true and (n.errors or 0) == 0, "Pawn not installed, the option left on: the Helper as it always was")
	-- both addons hold the same piece: Pawn's reason is given, and ItemTree isn't asked about it
	local it = { facts = { [7002] = deep(REAL[279898]), [7001] = deep(REAL[15012]) } }
	pawn = { upgrades = { [7002] = true } }
	n, M, DE = deBoot(gear, { pawn = pawn, it = it, prof = { deHoldPawn = true } })
	DE:Show(); M.runTimers()
	check(offeredNames(DE) == "Rare Chest, Sturdy Boots" and names(DE.held.by.pawn) == "Worn Dagger" and not DE.held.by.itemtree and it.asked[7002] == nil,
		"a piece both Pawn and ItemTree would hold: counted once, as a Pawn upgrade (" .. offeredNames(DE) .. ")")
	n:Set("deHoldPawn", false); M.runTimers()
	check(offeredNames(DE) == "Rare Chest, Sturdy Boots" and names(DE.held.by.itemtree) == "Worn Dagger", "Pawn's option off: ItemTree's word still holds it")
	check((n.errors or 0) == 0, "no errors")
	noPawn()
end)()

-- ======== the Loot Helper: unchanged ========
do
	local loot = {}
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("|Hitem:" .. loot[i].id .. ":0|h[" .. loot[i].name .. "]|h") end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, l.qty or 1, nil, l.q or 1 end end
	_G.LootSlot = function() end
	local deleted = 0
	_G.DeleteCursorItem = function() deleted = deleted + 1 end
	local INFO = { [9740] = { "Rough Gem", 1, 1, 30 }, [9701] = { "Broken Fang", 0, 1, 3 }, [9702] = { "Linen Belt", 1, 1, 22 }, [9720] = { "Gnoll Paw", 1, 20, 2 },
		[9730] = { "Heavy Stone", 1, 20, 50 }, [9731] = { "Fine Ring", 1, 1, 80 } }
	local function lootBoot(it, pawn)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return "Warrior", "WARRIOR" end
		M.sizes[0] = 5
		for b = 1, 5 do M.sizes[b] = 0 end
		M.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
		M.put(0, 2, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
		M.put(0, 3, { id = 9720, name = "Gnoll Paw", q = 1, count = 5, stack = 20, class = 15, subclass = 0, price = 2 })
		M.put(0, 4, { id = 9730, name = "Heavy Stone", q = 1, count = 1, stack = 20, class = 7, subclass = 7, price = 50 })
		M.put(0, 5, { id = 9731, name = "Fine Ring", q = 1, class = 4, subclass = 0, price = 80, equip = "INVTYPE_FINGER" })
		_G.ItemTreeAPI = it and fakeItemTree(it) or nil
		if pawn then fakePawn(pawn) else noPawn() end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", makeRoom = true, makeRoomValue = "vendor", makeRoomAsk = false } } }
		local n = M.loadAddon("BagSmith")
		n.version = "1.10.0-beta8"
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id)
			local num = tonumber(tostring(id):match("item:(%d+)")) or id
			local e = INFO[num]
			if e then return e[1], nil, e[2], nil, nil, nil, nil, e[3], nil, nil, e[4] end
			return realInfo(id)
		end
		C_Container.PickupContainerItem = function(bag, slot) local item = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = item and item.id end
		_G.ClearCursor = function() M.cursorItem = nil end
		_G.LootFrame = CreateFrame("Frame", "LootFrame", UIParent); LootFrame.GetRight = function() return 500 end; LootFrame.GetTop = function() return 700 end; LootFrame:Show()
		loot = { { id = 9740, name = "Rough Gem", q = 1 } }
		M.fire("LOOT_OPENED"); M.runTimers()
		return n, M, n.MakeRoom, n.MakeRoom.frame
	end
	local function offered(f)
		local t = {}
		for _, r in ipairs(f.destroyRows) do if r:IsShown() then t[#t + 1] = r.name.text end end
		return table.concat(t, ",")
	end
	-- a piece ItemTree keeps for its dust is still not offered for destroying
	do
		local belt = deep(REAL[15012]); belt.itemId = 9702
		local n, M, MR, f = lootBoot({ facts = { [9702] = belt } })
		check(f and f:IsShown() and offered(f) == "Broken Fang,Gnoll Paw", "the Loot Helper doesn't offer a piece ItemTree keeps for its dust (" .. tostring(f and offered(f)) .. ")")
		check((f.heldInfo.lines[1] or ""):find("ItemTree says to keep (1):", 1, true) and f.heldInfo.lines[1]:find("Linen Belt", 1, true), "it's held under ItemTree says to keep")
		local ok, why = n.MakeRoom:StillOk(MR:Offer(recOf(n, 9702), false, "priced", 22))
		check(ok == false and why == "itemtree", "and an offer for it is refused at the click (" .. tostring(why) .. ")")
		check((n.errors or 0) == 0, "no errors")
	end
	-- Pawn's protection here has no switch: with Hold Back Pawn Upgrades off, a Pawn upgrade still isn't offered
	do
		local n, M, MR, f = lootBoot(nil, { upgrades = { [9702] = true } })
		check(n.db.deHoldPawn == false and offered(f) == "Broken Fang,Gnoll Paw", "Hold Back Pawn Upgrades off: the Loot Helper still never offers a Pawn upgrade (" .. offered(f) .. ")")
		check((f.heldInfo.lines[1] or ""):find("Pawn upgrades (1):", 1, true) and f.heldInfo.lines[1]:find("Linen Belt", 1, true), "it's held under Pawn upgrades, as before")
		local ok, why = n.MakeRoom:StillOk(MR:Offer(recOf(n, 9702), false, "priced", 22))
		check(ok == false and why == "upgrade", "and refused at the click, as before (" .. tostring(why) .. ")")
		check((n.errors or 0) == 0, "no errors")
		noPawn()
	end
end

-- ======== Settings > General: one Other Addons card ========
for _, skin in ipairs({ "modern", "classic" }) do
	local S0 = skin .. ": "
	local function boot(opts)
		opts = opts or {}
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
		_G.ItemTreeAPI = opts.it and fakeItemTree(opts.it) or nil
		if opts.pawn then fakePawn(opts.pawn) else noPawn() end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin } } }
		local n = M.loadAddon("BagSmith")
		n.version = "1.10.0-beta8"
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local P = n.SettingsPanel
		P:Show(); P:ShowPage("general"); M.runTimers()
		return n, M, P
	end
	local function row(P, pool, key) for _, w in ipairs(P.pools[pool] or {}) do if w:IsShown() and w.key == key then return w end end end
	local function line(P, starts)
		for _, w in ipairs(P.pools.text or {}) do
			local words = w.text and w.text.text
			if w:IsShown() and type(words) == "string" and plain(words):find(starts, 1, true) == 1 then return w end
		end
	end
	local function x(w) return (select(4, w:GetPoint(1))) end
	local function y(w) return -(select(5, w:GetPoint(1))) end
	local function heads(P)
		local t = {}
		for _, w in ipairs(P.pools.head or {}) do if w:IsShown() then t[#t + 1] = { y(w), tostring(w.text and w.text.text or w.text) } end end
		table.sort(t, function(a, b) return a[1] < b[1] end)
		local out = {}
		for i, h in ipairs(t) do out[i] = h[2] end
		return table.concat(out, " | "), t
	end

	-- nothing else installed
	local n, M, P = boot()
	local hs, list = heads(P)
	check(hs == "Opening BagSmith | Other Addons | Tooltips | Blizzard's Interface | Notices", S0 .. "General's cards: Auction Prices has joined Other Addons (" .. hs .. ")")
	local seg, use, hold, pawn = row(P, "seg", "priceSource"), row(P, "check", "useItemTree"), row(P, "check", "itemTreeHold"), row(P, "check", "deHoldPawn")
	local itLine, pawnLine = line(P, "ItemTree is"), line(P, "Pawn is")
	check(seg and seg.text.text == "Auction Price Source", S0 .. "Price Source is now Auction Price Source (" .. tostring(seg and seg.text.text) .. ")")
	check(seg.btns[1].label.text == "Automatic" and seg.btns[3].label.text == "Blackthornes" and (seg.btns[3]:GetPoint(1)) == "TOPRIGHT", S0 .. "its three choices still sit on the label's line")
	check(tostring(seg.help.text):find("Which addon BagSmith gets auction prices from.", 1, true), S0 .. "with the description it had")
	local otherY, tipsY
	for _, h in ipairs(list) do if h[2] == "Other Addons" then otherY = h[1] elseif h[2] == "Tooltips" then tipsY = h[1] end end
	check(otherY < y(seg) and y(seg) < y(use) and y(use) < y(itLine) and y(itLine) < y(hold) and y(hold) < y(pawn) and y(pawn) < y(pawnLine) and y(pawnLine) < tipsY,
		S0 .. "in order under Other Addons: the price source, Use ItemTree and its line, Hold Back, then Pawn and its line")
	check(x(hold) > x(use) and x(pawn) == x(use) and x(pawnLine) == x(use), S0 .. "ItemTree's Hold Back is indented under Use ItemTree; Pawn's row is not")
	check(pawn.text.text == "Hold Back Pawn Upgrades" and pawn.help.text == "The Disenchant Helper won't offer a piece that the Pawn addon says is an upgrade for you. The Loot Helper already never does.",
		S0 .. "Hold Back Pawn Upgrades says what it does, and that the Loot Helper already holds them (" .. tostring(pawn.help.text) .. ")")
	check(not pawn.box:IsEnabled() and not pawn.box:GetChecked() and pawnLine.text.text == "Pawn isn't installed, so there's nothing to turn on. It's optional." and pawnLine.emphasis == nil,
		S0 .. "Pawn not installed: greyed, with a quiet line that says so (" .. tostring(pawnLine.text.text) .. ")")
	check(hold.help.text == "The Loot Helper and Disenchant Helper won't offer an item that " .. TEAL .. " says to keep. A piece " .. TEAL .. " keeps for its dust still shows in the Disenchant Helper.",
		S0 .. "ItemTree's Hold Back says a piece kept for its dust still shows in the Disenchant Helper")
	check(row(P, "check", "tipAHPrice") and y(row(P, "check", "tipAHPrice")) > tipsY, S0 .. "Show AH Price in Item Tooltips stays under Tooltips")
	P:Hide()

	-- Pawn installed
	local pstate = { upgrades = {} }
	n, M, P = boot({ pawn = pstate, it = { facts = {} } })
	pawn, pawnLine = row(P, "check", "deHoldPawn"), line(P, "Pawn is")
	check(pawn.box:IsEnabled() and not pawn.box:GetChecked() and n.db.deHoldPawn == false, S0 .. "Pawn installed: the box is yours to tick, and starts empty")
	check(pawnLine.text.text == "Pawn is installed, and its upgrade arrows show on your items.", S0 .. "its line says Pawn is installed (" .. tostring(pawnLine.text.text) .. ")")
	pawn.box:SetChecked(true); click(pawn.box); pump(M)
	pawn = row(P, "check", "deHoldPawn")
	check(n.db.deHoldPawn == true and pawn.box:GetChecked() and pawn.box:IsEnabled(), S0 .. "ticked: on")
	check(n.db.itemTreeHold == true and n.db.useItemTree == true and row(P, "check", "itemTreeHold").box:GetChecked(), S0 .. "(ItemTree's switches are their own)")
	pawn.box:SetChecked(false); click(pawn.box); pump(M)
	check(n.db.deHoldPawn == false, S0 .. "unticked: off")
	P:Hide()

	-- Pawn installed, its bag upgrade advisor off
	n, M, P = boot({ pawn = { upgrades = {}, advisor = false } })
	pawn, pawnLine = row(P, "check", "deHoldPawn"), line(P, "Pawn is")
	check(not pawn.box:IsEnabled() and not pawn.box:GetChecked()
		and pawnLine.text.text == "Pawn is installed, but its bag upgrade advisor is off, so it marks no upgrades. You can turn that on in Pawn's options.",
		S0 .. "Pawn's advisor off: greyed, and the line says where to turn it on (" .. tostring(pawnLine.text.text) .. ")")
	P:Hide()
	check((n.errors or 0) == 0, S0 .. "no errors")
	noPawn()
end

;(function()
	-- the words players read elsewhere, the changelog and the TOC
	local f = io.open("BagSmith/Frames/SettingsPanel.lua"); local src = f:read("*a"); f:close()
	local _, tips = src:gsub("Auction Price Source is in General%.", "")
	check(tips == 2 and not src:find("[^n] Price Source is in General", 1) and not src:find("\"Price Source\"", 1, true) and not src:find("Head%(\"Auction Prices\"%)"),
		"the AH Price column's tips say Auction Price Source, and the old label and heading are gone")
	f = io.open("BagSmith/BagSmith.toc"); local toc = f:read("*a"); f:close()
	check(toc:find("## Version: 1.10.0", 1, true), "the TOC says 1.10.0 (the exact version is pinned in tests/run.lua)")
	f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	local section = ("\n" .. log):match("\n(## 1%.10%.0\n.-)\n## 1%.9%.8\n") or ""
	check(section:find("A piece ItemTree keeps for its\n  dust still shows in the Disenchant Helper.", 1, true), "the changelog's 1.10.0 section: a piece kept for its dust still shows in the Disenchant Helper")
	check(section:find("Hold Back Pawn Upgrades, in Settings > General and off until you turn it on", 1, true), "Hold Back Pawn Upgrades, off until you turn it on")
	check(section:find("share one card, Other Addons. Price Source is now called\n  Auction Price Source.", 1, true), "and the one Other Addons card with Auction Price Source")
	check(not section:find("\226\128\148") and not section:find("\226\128\147"), "with no dashes")
end)()
