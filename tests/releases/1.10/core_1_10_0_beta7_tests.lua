-- ======== 1.10.0-beta7 (Shweep, 23 Nov: "build and good w/ all above") ========
-- (1) Settings > General > Use ItemTree, reworded ("the description is somewhat confusing"; "hard to read as a sentence
-- with the + Add a rule in middle"; "B is good"; "can we color the addon name?"): one plain sentence, the state on a
-- line of its own, and the word ItemTree in its own color, here and on the + Add a Rule menu's heading.
-- (2) The Loot Helper and the Disenchant Helper hold back an item ItemTree says to keep (its Keep mark). ItemTree can
-- only add a reason to hold an item back, never take one away; junk stays the player's word in the Loot Helper; and
-- both Helpers ask again, fresh, at the click.

local TEAL = "|cff9fe6e1ItemTree|r"
local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function deep(t) if type(t) ~= "table" then return t end local c = {}; for k, v in pairs(t) do c[k] = deep(v) end; return c end
local function click(b) b:GetScript("OnClick")(b) end
local function pump(M) for _ = 1, 40 do M.runTimers() end end

-- ItemTree's answer about one item, as much of it as BagSmith reads: its Keep mark, and the rest as the game had it.
local function fact(id, marked, more)
	local f = { itemId = id, known = true,
		keep = { marked = marked, state = marked and "keep" or "vendor", tags = { marked and "keep" or "vendor" }, line = marked and "Keep" or "Vendor" },
		route = { needed = false }, vendors = { buyPrice = 10, everywhere = false, count = 0 },
		uses = { reagentSkills = {}, kinds = { reagent = 0 } }, quests = { needs = {} } }
	for k, v in pairs(more or {}) do f[k] = v end
	return f
end
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
			if state.raise and state.raise[id] then error("ItemTree broke") end
			if state.ready == false then return nil end
			-- (by design since 1.10.0-beta13, the beta12 audit's F1: an item ItemTree has no data for still gets a table
			-- from the real one, and nothing back now means "couldn't be asked", which holds the item. This fake
			-- answered nil for such items; it answers as ItemTree does.)
			return deep(state.facts[id]) or { itemId = id, known = false }
		end,
	}
end

-- The eight items of Shweep's /run output (22 Nov), by their Keep mark as ItemTree v1.2.8 printed it.
local MARKED = { [3173] = true, [2996] = true, [279898] = true, [3372] = false, [2321] = true, [3371] = true, [6530] = false, [1708] = true }
local NAMES = { [3173] = "Bear Meat", [2996] = "Bolt of Linen Cloth", [279898] = "Dwarven Tome", [3372] = "Leaded Vial", [2321] = "Fine Thread", [3371] = "Empty Vial", [6530] = "Nightcrawlers", [1708] = "Sweet Nectar" }
local function eight() local t = {}; for id, marked in pairs(MARKED) do t[id] = fact(id, marked) end; return t end

-- it: "none" (not installed), or a state table for the fake
local function boot(opts)
	opts = opts or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 16
	local slot = 0
	for _, id in ipairs({ 3173, 2996, 279898, 3372, 2321, 3371, 6530, 1708 }) do
		slot = slot + 1
		M.put(0, slot, { id = id, name = NAMES[id], q = 1, count = 5, class = 7, subclass = 11, type = "Trade Goods", sub = "Other", price = 10, ilvl = 10 })
	end
	M.put(0, 9, { id = 99001, name = "Mystery Dust", q = 1, count = 5, class = 7, subclass = 12, type = "Trade Goods", sub = "Enchanting", price = 10, ilvl = 10 })
	_G.ITEM_QUALITY_COLORS = { [0] = { r = 0.62, g = 0.62, b = 0.62 }, { r = 1, g = 1, b = 1 }, { r = 0.12, g = 1, b = 0 }, { r = 0, g = 0.44, b = 0.87 }, { r = 0.64, g = 0.21, b = 0.93 }, { r = 1, g = 0.5, b = 0 } }
	local state = opts.it ~= "none" and (opts.it or {}) or nil
	if state then state.facts = state.facts or eight() end
	_G.ItemTreeAPI = state and fakeItemTree(state) or nil
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local prof = { view = "list", grp = "type", favSection = true, recentSection = false }
	for k, v in pairs(opts.prof or {}) do prof[k] = v end
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = prof } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta7"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	return n, M, n.Window.main, n.Sections, n.Rules, n.ItemTree, state
end
local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
local function inSection(n, id)
	local t = {}
	for _, r in ipairs(n.items) do if r.itemID and r.cat == id then t[#t + 1] = r.name end end
	table.sort(t)
	return table.concat(t, ", ")
end

;(function()
	-- ItemTree's Keep mark, read from its facts
	local n, M, main, S, R, IT = boot({ it = "none" })
	local got = {}
	for _, id in ipairs({ 3173, 2996, 279898, 3372, 2321, 3371, 6530, 1708 }) do got[#got + 1] = tostring(IT.Read(fact(id, MARKED[id])).kept) end
	check(table.concat(got, " ") == "true true true false true true false true", "ItemTree's Keep mark for the eight real items: all but the Leaded Vial and the Nightcrawlers (" .. table.concat(got, " ") .. ")")
	check(IT.Read({ keep = { state = "keep", tags = { "keep" }, line = "Keep" } }).kept == false, "only the mark itself counts: its other words about keeping don't")
	check(IT.Read({ keep = { marked = "yes" } }).kept == false and IT.Read({ keep = { marked = 1 } }).kept == false and IT.Read({ keep = "x" }).kept == false and IT.Read({}).kept == false,
		"anything but a plain true is a no")
	-- a rule doesn't read the mark, and an answer that only differs by it isn't a change for the views
	check(R.KEYS.it_prof and not R.KEYS.it_kept and not R.KEYS.it_keep, "(no rule reads the mark)")
	-- not installed: the Helpers' question is a plain no
	check(IT:Holds({ itemID = 3173 }) == false and IT:Holds(recOf(n, 3173), true) == false, "ItemTree not installed: nothing is held back")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- IT:Holds: asked on the spot, once; fresh asks again; and every way it says no
	local it = {}
	local n, M, main, S, R, IT = boot({ it = it })
	-- (by design since 1.10.0-beta9: one switch per Helper, and neither depends on the rules' switch)
	check(n.db.makeRoomHoldItemTree == true and n.db.deHoldItemTree == true, "the option is on unless you turn it off")
	check(it.calls == 0, "(nothing asks ItemTree anything until a rule or a Helper does)")
	local meat, vial, dust = recOf(n, 3173), recOf(n, 3372), recOf(n, 99001)
	check(IT:Holds(meat) == true and it.calls == 1, "Bear Meat: ItemTree says keep, asked on the spot")
	check(IT:Holds(meat) == true and IT:Holds(meat) == true and it.calls == 1, "asked once: the answer is kept")
	check(IT:Holds(vial) == false and it.calls == 2, "Leaded Vial: ItemTree doesn't keep it")
	check(IT:Holds(dust) == false and it.calls == 3 and IT:Holds(dust) == false and it.calls == 3, "an item ItemTree knows nothing about: not held, and not asked twice")
	check(IT:Holds(meat, true) == true and it.calls == 4, "fresh: asked again whatever is known")
	-- ItemTree changes its mind: the kept answer stands until it's asked fresh
	it.facts[3372].keep.marked = true
	check(IT:Holds(vial) == false and it.calls == 4, "(ItemTree changed its mind: the kept answer still says no)")
	check(IT:Holds(vial, true) == true and it.calls == 5 and IT:Holds(vial) == true and it.calls == 5, "asked fresh: yes, and that's the answer kept now")
	it.facts[3372].keep.marked = false
	-- rows that are never asked
	local asked = it.calls
	check(IT:Holds({ itemID = 3173, global = true }) == false and IT:Holds({ empty = true }) == false and IT:Holds(nil) == false and IT:Holds({ name = "x" }) == false and it.calls == asked,
		"a Global Inventory row, an empty slot, nothing at all: no, and no question")
	-- by item ID alone (the Loot Helper's click has no record)
	-- (by design since 1.10.0-beta16, the beta15 audit's B15-1: a question by item id alone is no longer put to
	-- ItemTree for a Helper. Without a link the item can't be named, so the answer is "unknown" and it is held; before,
	-- ItemTree was asked by id and its answer taken. With the link, as a click passes it, it is asked as ever.)
	local askedBefore = it.calls
	check(IT:Holds({ itemID = 2996 }, true) == true and IT:Verdict({ itemID = 2996 }, true) == "unknown" and it.calls == askedBefore, "by item ID alone: held as unknown, and ItemTree isn't asked")
	check(IT:Verdict({ itemID = 2996, link = recOf(n, 2996).link }, true) == "hold" and it.calls == askedBefore + 1, "with the item's link: asked, and answered")
	-- an error inside ItemTree is no answer
	it.raise = { [2321] = true }
	-- (by design since 1.10.0-beta13, the beta12 audit's F1: that is no longer "not held, go on as before". ItemTree
	-- is on and couldn't answer, so the item is held and the click refused. The beta13 set checks the Helpers.)
	check(IT:Holds(recOf(n, 2321)) == true and IT:Verdict(recOf(n, 2321)) == "unknown" and (n.errors or 0) == 0, "an error inside ItemTree: it couldn't be asked, so the item is held, and nothing of BagSmith's breaks")
	it.raise = nil
	-- the count changed: the answer is asked again the next time a Helper wants it
	asked = it.calls
	M.put(0, 1, { id = 3173, name = "Bear Meat", q = 1, count = 3, class = 7, subclass = 11, type = "Trade Goods", sub = "Other", price = 10, ilvl = 10 })
	M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); pump(M)
	check(it.calls == asked, "(the stack changed: nothing is asked while no rule and no Helper wants it)")
	check(IT:Holds(recOf(n, 3173)) == true and it.calls == asked + 1, "then a Helper asks: asked again, for the stack as it is now")
	-- your gear, level, quests or skills changed: the same
	asked = it.calls
	M.fire("QUEST_ACCEPTED"); pump(M)
	check(IT:Holds(recOf(n, 3173)) == true and it.calls == asked + 1, "after a quest is accepted, the next question is asked afresh")
	-- the option off
	asked = it.calls
	n:Set("makeRoomHoldItemTree", false)
	check(IT:Holds(meat) == false and IT:Holds(meat, true) == false and it.calls == asked, "Hold Back off: no, and ItemTree isn't asked")
	n:Set("makeRoomHoldItemTree", true)
	check(IT:Holds(recOf(n, 3173)) == true, "on again: held again")
	-- Use ItemTree off
	n:Set("useItemTree", false); pump(M)
	asked = it.calls
	-- (by design since 1.10.0-beta9: the rules' switch no longer switches the Helpers' holds)
	check(IT:Holds(recOf(n, 3173)) == true and it.calls == asked + 1, "the rules switched off: the Helpers' question is still answered")
	n:Set("useItemTree", true); pump(M)
	check(IT:Holds(recOf(n, 3173)) == true, "on again: held again")
	check(it.requested == 0 and (n.errors or 0) == 0, "no errors, and ItemTree was never asked to load anything")
end)()

;(function()
	-- not ready: no; and a Helper answering first doesn't leave a waiting rule without its redraw
	local it = { ready = false }
	local n, M, main, S, R, IT = boot({ it = it })
	-- (by design since 1.10.0-beta13: not ready is "couldn't be asked", and the item is held meanwhile; before, not held)
	check(IT:Holds(recOf(n, 3173)) == true and IT:Verdict(recOf(n, 3173)) == "unknown" and it.calls == 0, "ItemTree installed but not ready: it couldn't be asked, so the item is held, and nothing is asked of it")
	it.ready = true
	it.onReady(); pump(M)
	check(IT:Holds(recOf(n, 3173)) == true and it.calls == 1, "ready: asked, and held")
	-- a rule is waiting for the same items' answers, and a Helper asks first
	it.facts[2996].uses.reagentSkills = { 197 }
	local mats = S:CreateWithRules("Profession Mats", { mode = "all", rows = { { k = "it_prof", v = { "yes" } } } })
	local _, waiting = IT:Count()
	check(waiting > 0 and inSection(n, mats) == "", "(a new section's rule is waiting for ItemTree's answers)")
	check(IT:Holds(recOf(n, 2996)) == true, "a Helper asks about the cloth before the rule's turn comes")
	pump(M)
	check(inSection(n, mats) == "Bolt of Linen Cloth", "and the section still fills: the views hear of an answer a Helper fetched (" .. inSection(n, mats) .. ")")
	-- the other way round: a rule's answer serves the Helper with no second question
	local asked = it.calls
	check(IT:Holds(recOf(n, 2321)) == true and it.calls == asked, "an answer a rule already has serves the Helper: no second question")
	-- a fresh answer that changes what a rule sees redraws the views
	it.facts[2321].uses.reagentSkills = { 197 }
	check(IT:Holds(recOf(n, 2321), true) == true, "(asked fresh, and ItemTree now says Tailoring uses the thread)")
	pump(M)
	check(inSection(n, mats) == "Bolt of Linen Cloth, Fine Thread", "the section follows what the fresh answer said (" .. inSection(n, mats) .. ")")
	check(it.requested == 0 and (n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- the Disenchant Helper: a piece ItemTree says to keep isn't offered
	package.loaded.mock = nil
	local M = require("mock")
	local DEID = 13262
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
	M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
	M.put(0, 3, { id = 7003, name = "Rare Chest", q = 3, count = 1, class = 4, subclass = 2, price = 2000, ilvl = 45, equip = "INVTYPE_CHEST" })
	M.put(0, 4, { id = 7004, name = "Grey Rag", q = 0, count = 1, class = 4, subclass = 1, price = 5, ilvl = 5, equip = "INVTYPE_CHEST" })
	local it = { facts = { [7001] = fact(7001, false), [7002] = fact(7002, true, { keep = { marked = true, state = "keep", tags = { "equip" }, gear = { upgrade = true } } }), [7004] = fact(7004, true) } }
	_G.ItemTreeAPI = fakeItemTree(it)
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
	_G.IsSpellKnown = function(id) return id == DEID end
	_G.GetNumSkillLines = function() return 2 end
	_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, 300 end
	_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
	_G.RegisterStateDriver = function() end
	_G.UnregisterStateDriver = function() end
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta7"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE, IT = n.Disenchant, n.ItemTree
	local function offered(id) for _, e in ipairs(DE.entries or {}) do if e.itemID == id then return e end end end
	DE:Show(); M.runTimers()
	check(#DE.entries == 2 and offered(7001) and offered(7003) and not offered(7002), "the boots and the chest are offered; the dagger ItemTree says to keep is not")
	local ok, why = DE:Eligible(recOf(n, 7002), DE:Skill())
	check(ok == false and why == "itemtree", "it isn't offered because ItemTree says to keep it (" .. tostring(why) .. ")")
	check(DE.held and DE.held.total == 1 and DE.held.by.itemtree and DE.held.by.itemtree[1] == "Worn Dagger", "and it's counted with the items not offered")
	local lines = n.Why:Lines(DE.held)
	check(#lines == 1 and lines[1]:find("ItemTree says to keep (1):", 1, true) and lines[1]:find("Worn Dagger", 1, true), "under its own words: ItemTree says to keep (" .. tostring(lines[1]) .. ")")
	check(n.Why.NOUN.itemtree[1] == "item ItemTree says to keep" and n.Why.NOUN.itemtree[2] == "items ItemTree says to keep" and n.Why:Phrase(DE.held) == "1 item ItemTree says to keep",
		"and the sentence for an empty list has its words (" .. tostring(n.Why:Phrase(DE.held)) .. ")")
	-- asked last, and once: only about what would otherwise be offered
	check(it.asked[7004] == nil, "the grey rag was never a disenchant: ItemTree isn't asked about it")
	check(it.asked[7001] == 1 and it.asked[7002] == 1 and it.asked[7003] == 1, "each piece that would be offered is asked about once")
	DE:Refresh(); DE:Refresh()
	check(it.calls == 3, "and not again when the list is drawn again")
	-- another reason comes first, and then ItemTree isn't asked at all
	local dagger = recOf(n, 7002)
	n.Marks:ToggleFavorite(recOf(n, 7002)); M.runTimers(); DE:Refresh()
	ok, why = DE:Eligible(dagger, DE:Skill())
	check(ok == false and why == "favorite" and DE.held.by.favorite and not DE.held.by.itemtree, "a favorite ItemTree also keeps: it's held as a favorite (" .. tostring(why) .. ")")
	n.Marks:ToggleFavorite(recOf(n, 7002)); M.runTimers(); DE:Refresh()
	check(select(2, DE:Eligible(dagger, DE:Skill())) == "itemtree", "(the favorite mark taken off: ItemTree's word holds it again)")
	-- the option off: offered again at once, with the Helper open
	n:Set("deHoldItemTree", false); M.runTimers()
	check(#DE.entries == 3 and offered(7002) and DE.held.total == 0, "Hold Back off: the open Helper offers the dagger again at once")
	n:Set("deHoldItemTree", true); M.runTimers()
	check(#DE.entries == 2 and not offered(7002), "on again: held back again")
	n:Set("useItemTree", false); M.runTimers(); M.runTimers()
	check(#DE.entries == 2 and not offered(7002), "the rules switched off: the dagger is still held (by design since beta9)")
	n:Set("useItemTree", true); M.runTimers(); M.runTimers()
	check(#DE.entries == 2 and not offered(7002), "on again: held back again")
	-- at the click: ItemTree is asked fresh about the armed item
	local boots = offered(7001)
	DE:Select(boots)
	local asked = it.asked[7001]
	check(DE:LiveCheck(boots) == true and it.asked[7001] == asked + 1, "(control) the boots pass the check at the click, and ItemTree is asked fresh")
	it.facts[7001].keep.marked = true
	check(offered(7001) ~= nil, "(ItemTree changes its mind about the boots while they're listed)")
	local okNow, whyNow = DE:LiveCheck(boots)
	check(okNow == false and whyNow == "ItemTree says to keep that item", "the click is refused: " .. tostring(whyNow))
	DE:Refresh()
	check(not offered(7001) and #DE.held.by.itemtree == 2, "and the list, drawn again, holds the boots back too")
	check(it.requested == 0 and (n.errors or 0) == 0, "no errors, and ItemTree was never asked to load anything")
end)()

-- ======== the Loot Helper ========
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
	local function lootBoot(it, skin, prof)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return "Warrior", "WARRIOR" end
		M.sizes[0] = 5
		for b = 1, 5 do M.sizes[b] = 0 end
		M.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
		M.put(0, 2, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
		M.put(0, 3, { id = 9720, name = "Gnoll Paw", q = 1, count = 5, stack = 20, class = 15, subclass = 0, price = 2 })   -- 10c
		M.put(0, 4, { id = 9730, name = "Heavy Stone", q = 1, count = 1, stack = 20, class = 7, subclass = 7, price = 50 })   -- 50c
		M.put(0, 5, { id = 9731, name = "Fine Ring", q = 1, class = 4, subclass = 0, price = 80, equip = "INVTYPE_FINGER" })
		_G.ItemTreeAPI = it and fakeItemTree(it) or nil
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = skin or "modern", makeRoom = true, makeRoomValue = "vendor", makeRoomAsk = false }
		for k, v in pairs(prof or {}) do p[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
		local n = M.loadAddon("BagSmith")
		n.version = "1.10.0-beta7"
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
	local function said(M, words) for _, line in ipairs(M.log or {}) do if tostring(line):find(words, 1, true) then return true end end return false end
	-- ItemTree keeps the paw, the grey fang and the stone; not the belt; and knows nothing of the ring
	local function facts() return { [9701] = fact(9701, true), [9702] = fact(9702, false), [9720] = fact(9720, true), [9730] = fact(9730, true) } end

	-- (control) with no ItemTree, the Helper offers what it always has
	do
		local n, M, MR, f = lootBoot(nil)
		check(f and f:IsShown() and offered(f) == "Broken Fang,Gnoll Paw,Linen Belt", "(control) no ItemTree: junk, then what's worth less than the 30c loot (" .. tostring(f and offered(f)) .. ")")
		check(MR:StillOk(MR:Offer(recOf(n, 9720), false, "priced", 10)) == true, "(control) and the paw can be destroyed")
	end

	for _, skin in ipairs({ "modern", "classic" }) do
		local S0 = skin .. ": "
		local it = { facts = facts() }
		local n, M, MR, f = lootBoot(it, skin)
		check(f and f:IsShown() and offered(f) == "Broken Fang,Linen Belt", S0 .. "the paw ItemTree says to keep isn't offered (" .. tostring(f and offered(f)) .. ")")
		check(f.held:IsShown() and f.held.text == "1 protected item isn't offered", S0 .. "it's counted with what isn't offered (" .. tostring(f.held.text) .. ")")
		check((f.heldInfo.lines[1] or ""):find("ItemTree says to keep (1):", 1, true) and f.heldInfo.lines[1]:find("Gnoll Paw", 1, true), S0 .. "under its own reason (" .. tostring(f.heldInfo.lines[1]) .. ")")
		-- asked only about what would otherwise be offered
		check(it.asked[9720] == 1 and it.asked[9702] == 1, S0 .. "the paw and the belt, which would be offered, are asked about once each")
		check(it.asked[9730] == nil and it.asked[9731] == nil, S0 .. "the stone and the ring are worth more than the loot: ItemTree isn't asked")
		-- junk is your word: a grey is offered whatever ItemTree says
		check(it.asked[9701] == nil and offered(f):find("Broken Fang", 1, true), S0 .. "a grey item is still offered, and ItemTree isn't asked about it")
		MR:Refresh(); MR:Refresh()
		check(it.calls == 2, S0 .. "nothing is asked again when the list is drawn again")
		-- at the click
		local paw = MR:Offer(recOf(n, 9720), false, "priced", 10)
		local ok, why = MR:StillOk(paw)
		check(ok == false and why == "itemtree", S0 .. "an offer for the paw is refused at the click (" .. tostring(why) .. ")")
		local before = deleted
		MR:Destroy(paw, true)
		check(deleted == before and said(M, "ItemTree says to keep that item, so nothing was destroyed."), S0 .. "even after a Yes, nothing is destroyed, and it says why")
		local belt = MR:Offer(recOf(n, 9702), false, "priced", 22)
		local asked = it.asked[9702]
		check(MR:StillOk(belt) == true and it.asked[9702] == asked + 1, S0 .. "(control) the belt passes, and ItemTree is asked fresh at the click")
		local fang = MR:Offer(recOf(n, 9701), true)
		check(MR:StillOk(fang) == true and it.asked[9701] == nil, S0 .. "the grey fang, offered as junk, passes without a word from ItemTree")
		-- ItemTree changes its mind between the list and the click
		it.facts[9702].keep.marked = true
		check(offered(f):find("Linen Belt", 1, true) ~= nil, S0 .. "(ItemTree changes its mind about the belt while it's listed)")
		ok, why = MR:StillOk(belt)
		check(ok == false and why == "itemtree", S0 .. "the click is refused (" .. tostring(why) .. ")")
		before = deleted
		MR:Destroy(belt, true)
		check(deleted == before, S0 .. "and nothing is destroyed")
		MR:Refresh()
		check(offered(f) == "Broken Fang" and f.held.text == "2 protected items aren't offered", S0 .. "the list, drawn again, holds the belt back too (" .. offered(f) .. " / " .. tostring(f.held.text) .. ")")
		-- ItemTree's own notice that its answers changed: the next list asks afresh
		it.facts[9702].keep.marked = false
		local was = it.asked[9702]
		it.onChange("stock"); pump(M); MR:Refresh()
		check(offered(f) == "Broken Fang,Linen Belt" and it.asked[9702] == was + 1, S0 .. "ItemTree says its answers changed: asked afresh, and the belt is offered again (" .. offered(f) .. ")")
		-- another reason comes first
		n.Marks:ToggleFavorite(recOf(n, 9720)); M.runTimers(); MR:Refresh()
		check((f.heldInfo.lines[1] or ""):find("Favorite", 1, true) and (f.heldInfo.lines[1] or ""):find("Gnoll Paw", 1, true), S0 .. "a favorite ItemTree also keeps is held as a favorite (" .. tostring(f.heldInfo.lines[1]) .. ")")
		n.Marks:ToggleFavorite(recOf(n, 9720)); M.runTimers()
		-- the option off: the open Helper offers it again at once
		n:Set("makeRoomHoldItemTree", false); M.runTimers()
		check(offered(f) == "Broken Fang,Gnoll Paw,Linen Belt" and not f.held:IsShown(), S0 .. "Hold Back off: the open Helper offers the paw again at once (" .. offered(f) .. ")")
		check(MR:StillOk(MR:Offer(recOf(n, 9720), false, "priced", 10)) == true, S0 .. "and it can be destroyed")
		n:Set("makeRoomHoldItemTree", true); M.runTimers()
		check(offered(f) == "Broken Fang,Linen Belt", S0 .. "on again: held back again (" .. offered(f) .. ")")
		n:Set("useItemTree", false); M.runTimers(); M.runTimers(); MR:Refresh()
		check(offered(f) == "Broken Fang,Linen Belt", S0 .. "the rules switched off: the paw is still held (by design since beta9) (" .. offered(f) .. ")")
		n:Set("useItemTree", true); M.runTimers(); M.runTimers()
		check(offered(f) == "Broken Fang,Linen Belt", S0 .. "on again: held back again")
		-- your own junk mark is your word too
		n.Junk:Toggle(recOf(n, 9720)); M.runTimers(); MR:Refresh()
		check(n.Junk:Marked(9720) and offered(f):find("Gnoll Paw", 1, true) ~= nil, S0 .. "the paw marked as junk by you: offered, whatever ItemTree says (" .. offered(f) .. ")")
		check(MR:StillOk(MR:Offer(recOf(n, 9720), true)) == true, S0 .. "and it passes at the click")
		check(it.requested == 0 and (n.errors or 0) == 0, S0 .. "no errors, and ItemTree was never asked to load anything")
		f:Hide()
	end

	-- a profile with the option off from the start
	do
		local it = { facts = facts() }
		local n, M, MR, f = lootBoot(it, "modern", { itemTreeHold = false })
		check(n.db.makeRoomHoldItemTree == false and offered(f) == "Broken Fang,Gnoll Paw,Linen Belt" and it.calls == 0, "a profile with Hold Back off: the Helper is as it was, and ItemTree is asked nothing")
	end
end

for _, skin in ipairs({ "modern", "classic" }) do
	-- (by design since 1.10.0-beta9, Shweep: "this needs more consistency and a scalable plan": the Other Addons card
	-- this checked, the reworded Use ItemTree row with its state line and its indented Hold Back, became a page of its
	-- own, built differently. Its checks are in the beta9 set. The heading's color in + Add a Rule stays.)
	local S0 = skin .. ": "
	local it = {}
	local n, M = boot({ it = it, prof = { skin = skin } })

	-- the + Add a Rule menu's heading is in the same color
	local menu
	n.ShowMenu = function(items) menu = items end
	local f = n.Sections:EditSection(); M.runTimers()
	click(f.add)
	local head
	for _, item in ipairs(menu) do if item.text == "What ItemTree knows" then head = item end end
	check(head and head.title and head.color and math.abs(head.color[1] - 0x9f / 255) < 0.002 and math.abs(head.color[2] - 0xe6 / 255) < 0.002 and math.abs(head.color[3] - 0xe1 / 255) < 0.002,
		S0 .. "+ Add a Rule: the What ItemTree knows heading is in ItemTree's teal")
	local others = 0
	for _, item in ipairs(menu) do if item ~= head and item.color then others = others + 1 end end
	check(others == 0, S0 .. "and nothing else on the menu changed color")
	click(f.cancel)
	check(it.requested == 0 and (n.errors or 0) == 0, S0 .. "no errors")
end

;(function()
	-- a profile saved before beta7 has the option on; one that turned it off keeps it off; other values are put right
	local n = boot({ it = {}, prof = { useItemTree = true } })
	check(n.db.makeRoomHoldItemTree == true and n.db.deHoldItemTree == true, "a profile from before beta7: Hold Back is on")
	n = boot({ it = {}, prof = { itemTreeHold = false } })
	check(n.db.makeRoomHoldItemTree == false and n.db.deHoldItemTree == false, "one that turned it off keeps it off")
	-- the real menu draws the heading in the color it's given
	local n2, M = boot({ it = {} })
	n2.ShowMenu({ { text = "What ItemTree knows", title = true, color = { 0.624, 0.902, 0.882 } }, { text = "Plain heading", title = true }, { text = "A row", onClick = function() end } })
	local m = n2.menuFrame
	local teal, other
	for _, r in ipairs(m.rows) do
		if r:IsShown() and r.text.text == "What ItemTree knows" then teal = r.text.textColor end
		if r:IsShown() and r.text.text == "Plain heading" then other = r.text.textColor end
	end
	check(teal and math.abs(teal[1] - 0.624) < 0.001 and math.abs(teal[2] - 0.902) < 0.001 and math.abs(teal[3] - 0.882) < 0.001, "the menu draws the ItemTree heading in teal")
	check(other and not (math.abs(other[1] - 0.624) < 0.001 and math.abs(other[2] - 0.902) < 0.001), "and other headings in the skin's own color")
	m:Hide()
end)()

;(function()
	-- the changelog, the TOC, and the words players read
	local f = io.open("BagSmith/BagSmith.toc"); local toc = f:read("*a"); f:close()
	check(toc:find("## Version: 1.10.0", 1, true), "the TOC says 1.10.0 (the exact version is pinned in tests/run.lua)")
	f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	local section = ("\n" .. log):match("\n(## 1%.10%.0\n.-)\n## 1%.9%.8\n") or ""
	check(section:find("the Loot Helper and Disenchant Helper also hold back an item ItemTree says to keep", 1, true) and section:find("each Helper has its own switch in Settings > Addon Sources", 1, true),
		"the changelog's 1.10.0 section: the Helpers hold back what ItemTree says to keep")
	check(not section:find("\226\128\148") and not section:find("\226\128\147"), "with no dashes")
	for _, file in ipairs({ "BagSmith/Core/ItemTree.lua", "BagSmith/Core/Why.lua" }) do
		f = io.open(file); local src = f:read("*a"); f:close()
		check(not src:find("RequestData%s*%(") and not src:find("%.RequestData[^:]"), file .. ": ItemTree is never asked to load its data")
	end
	f = io.open("BagSmith/Core/ItemTree.lua"); local src = f:read("*a"); f:close()
	local called = {}
	for name in src:gmatch("A%.([%a]+)") do called[name] = true end
	local names = {}
	for name in pairs(called) do names[#names + 1] = name end
	table.sort(names)
	check(table.concat(names, " ") == "GetItemFacts IsReady RegisterChangeCallback RegisterReadyCallback", "only ItemTree's four public calls are used (" .. table.concat(names, " ") .. ")")
end)()
