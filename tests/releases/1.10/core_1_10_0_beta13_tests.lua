-- ======== 1.10.0-beta13 (Shweep, 22 Nov: "1. yes 2. yes as a reminder 3. okay update 4. yes a note / build for auditor") ========
-- The answer to the beta12 audit, finding by finding:
-- F1  ItemTree is on for a Helper but can't answer (not ready, an error inside it, nothing back): the item is held and
--     the click refused, whatever it said before. Three answers now: hold, clear, unknown (IT:Verdict).
-- F2  A level gained looks at the Usable by Me sections and filters again, also when no tooltip was ever red.
-- F3  (a) Save as Section... with more rules than a section holds names the one left out; the Usable by Me quick
--     pick comes along as a rule. (b) The old No binding box no longer counts an item whose binding isn't known.
--     (c) Older conditions aren't folded into an "any one of these" group; the window says they still apply.
-- F4  ItemTree's answer for an item you no longer hold is let go at once, so it's asked again when one comes back.
-- F5  A name or quality filled in while the game hasn't sent the item ("Item 17", Common) is no fact for a rule.
-- F6  Someone who comes straight from 1.9.7 or earlier gets 1.9.8's note on the 1.10 card, as a reminder.
-- F7  (the packaging: the dev kit's README and RUN-THE-TESTS.md; nothing in the addon)
-- F8  The changelog says Addon Sources; the card's ItemTree bullet names the two exceptions.

local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function deep(t) if type(t) ~= "table" then return t end local c = {}; for k, v in pairs(t) do c[k] = deep(v) end; return c end
local function click(b) b:GetScript("OnClick")(b) end
local function pump(M) for _ = 1, 40 do M.runTimers() end end
local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
local function names(list) local t = {}; for i, v in ipairs(list or {}) do t[i] = v end; table.sort(t); return table.concat(t, ", ") end
local function said(M, words) for _, line in ipairs(M.log or {}) do if tostring(line):find(words, 1, true) then return true end end return false end

-- ItemTree's answer about one item: its Keep mark and its state.
local function fact(id, marked, state)
	return { itemId = id, known = true,
		keep = { marked = marked, state = state or (marked and "keep" or "vendor"), tags = { marked and "keep" or "vendor" } },
		route = { needed = false }, vendors = { buyPrice = 10, everywhere = false, count = 0 },
		uses = { reagentSkills = {}, kinds = { reagent = 0 } }, quests = { needs = {} } }
end
-- ItemTree as BagSmith meets it. state.ready = false: its data isn't loaded. state.raise: GetItemFacts raises an
-- error. state.silent: it returns nothing. state.odd: it returns something that isn't a table. Otherwise it answers
-- as the real one does: its facts, and for an item it has no data for, a table that says so.
local function fakeItemTree(state)
	state.calls, state.asked, state.requested = 0, {}, 0
	return {
		version = 1,
		IsReady = function() return state.ready ~= false end,
		RequestData = function() state.requested = state.requested + 1 end,
		RegisterReadyCallback = function(fn) state.onReady = fn end,
		RegisterChangeCallback = function(fn) state.onChange = fn end,
		GetItemFacts = function(id)
			state.calls = state.calls + 1
			state.asked[id] = (state.asked[id] or 0) + 1
			if state.raise then error("ItemTree broke") end
			if state.silent then return nil end
			if state.odd then return "?" end
			return deep(state.facts[id]) or { itemId = id, known = false }
		end,
	}
end

-- ======== F1: the three answers ========
;(function()
	local function boot(it, prof)
		package.loaded.mock = nil
		local M = require("mock")
		M.removeEquipmentSets()
		M.put(0, 1, { id = 2996, name = "Bolt of Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 10, ilvl = 10 })
		M.put(0, 2, { id = 6530, name = "Nightcrawlers", q = 1, count = 4, class = 0, subclass = 8, type = "Consumable", sub = "Other", price = 25, ilvl = 10 })
		M.put(0, 3, { id = 15012, name = "Lupine Slippers of the Falcon", q = 2, count = 1, class = 4, subclass = 2, price = 296, ilvl = 16, equip = "INVTYPE_FEET", bind = 2 })
		M.put(0, 4, { id = 4000, name = "Odd Trinket", q = 1, count = 1, class = 15, subclass = 0, price = 5 })
		_G.ItemTreeAPI = it and fakeItemTree(it) or nil
		_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = "modern" }
		for k, v in pairs(prof or {}) do p[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
		local n = M.loadAddon("BagSmith")
		n.version = "1.10.0-beta13"
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M, n.ItemTree
	end
	local function facts() return { [2996] = fact(2996, true), [6530] = fact(6530, false), [15012] = fact(15012, true, "keepDisenchant") } end

	-- no ItemTree: no opinion
	local n, M, IT = boot(nil)
	check(IT:Verdict(recOf(n, 2996)) == nil and IT:Verdict(recOf(n, 2996), true, true) == nil and IT:Holds(recOf(n, 2996)) == false, "no ItemTree: no opinion, for either Helper")

	-- ItemTree answering
	local it = { facts = facts() }
	n, M, IT = boot(it)
	check(IT:Verdict(recOf(n, 2996)) == "hold" and IT:Verdict(recOf(n, 2996), nil, true) == "hold", "ItemTree keeps the cloth: hold, for both Helpers")
	check(IT:Verdict(recOf(n, 6530)) == "clear" and IT:Verdict(recOf(n, 6530), nil, true) == "clear", "it doesn't keep the nightcrawlers: clear")
	check(IT:Verdict(recOf(n, 15012)) == "hold" and IT:Verdict(recOf(n, 15012), nil, true) == "clear", "the slippers it keeps for their dust: held from the Loot Helper, clear for the Disenchant Helper")
	check(IT:Verdict(recOf(n, 4000)) == "clear" and it.asked[4000] == 1, "an item ItemTree has no data for still gets its answer (a table that says so): clear")
	check(IT:Verdict(nil) == nil and IT:Verdict({}) == nil and IT:Verdict({ itemID = 2996, global = true }) == nil and IT:Verdict({ itemID = 2996, empty = true }) == nil, "a row that isn't a real item of yours: no opinion")
	check(IT:Holds(recOf(n, 2996)) == true and IT:Holds(recOf(n, 6530)) == false and IT:Holds(recOf(n, 15012), nil, true) == false and IT:Holds(nil) == false, "IT:Holds, the yes or no: held for a Keep, not for a no, not for dust in the Disenchant Helper")
	check(select(2, IT:Holds(recOf(n, 2996))) == "hold" and select(2, IT:Holds(recOf(n, 6530))) == "clear", "(with the verdict as its second answer)")
	local asked = it.calls
	IT:Verdict(recOf(n, 2996)); IT:Verdict(recOf(n, 6530), nil, true)
	check(it.calls == asked, "an answer already held isn't asked for again")

	-- a known Keep, then ItemTree fails when asked afresh (the audit's case)
	for _, how in ipairs({ "raise", "silent", "odd" }) do
		it[how] = true
		check(IT:Verdict(recOf(n, 2996), true) == "unknown" and IT:Verdict(recOf(n, 2996), true, true) == "unknown", how .. ": a known Keep asked afresh, and ItemTree fails: unknown, not clear")
		check(IT:Verdict(recOf(n, 6530), true) == "unknown", how .. ": the same for a known no")
		check(IT:Holds(recOf(n, 2996), true) == true and IT:Holds(recOf(n, 6530), true) == true and IT:Holds(recOf(n, 6530), true, true) == true, how .. ": IT:Holds says hold for both: no answer is never a no")
		-- (by design since 1.10.0-beta14, the beta13 re-audit's R5: the answer held before is still kept, for the rules.
		-- A Helper's list no longer leans on it after a read that failed: it asks again, and says unknown while ItemTree
		-- still fails. Before, this check read the old answers back through IT:Verdict.)
		check(IT:Facts(recOf(n, 2996)).kept == true and IT:Facts(recOf(n, 6530)).kept == false, how .. ": the answers it gave before are still held for the rules (a failed refresh replaces nothing)")
		check(IT:Verdict(recOf(n, 2996)) == "unknown" and IT:Verdict(recOf(n, 6530)) == "unknown", how .. ": and a Helper's list asks again rather than lean on them: unknown while ItemTree fails")
		it[how] = nil
	end
	check(IT:Verdict(recOf(n, 2996), true) == "hold" and IT:Verdict(recOf(n, 6530), true) == "clear", "ItemTree answers again: hold and clear, as before")
	check((n.errors or 0) == 0 and it.requested == 0, "no errors, and ItemTree was never asked to load anything")

	-- never asked before, and it fails
	for _, how in ipairs({ "raise", "silent", "odd" }) do
		it = { facts = facts() }
		n, M, IT = boot(it)
		it[how] = true
		check(IT:Verdict(recOf(n, 2996)) == "unknown" and IT:Verdict(recOf(n, 6530), nil, true) == "unknown", how .. ": nothing known yet and ItemTree fails: unknown")
		local before = it.calls
		it[how] = nil
		check(IT:Verdict(recOf(n, 2996)) == "hold" and it.calls == before + 1, how .. ": asked again the next time, since nothing was learned")
		check((n.errors or 0) == 0, how .. ": no errors")
	end

	-- its data isn't loaded
	it = { facts = facts(), ready = false }
	n, M, IT = boot(it)
	check(IT:Verdict(recOf(n, 2996)) == "unknown" and IT:Verdict(recOf(n, 6530), true, true) == "unknown" and it.calls == 0, "ItemTree installed, its data not loaded: unknown, and it isn't asked for facts")
	check(it.requested == 0, "and BagSmith doesn't make it load")
	local heard = 0
	n:OnSignal("ITEMTREE_READY", function() heard = heard + 1 end)
	it.ready = true
	it.onReady(); M.runTimers()
	check(heard == 1 and IT:Verdict(recOf(n, 2996)) == "hold" and IT:Verdict(recOf(n, 6530)) == "clear", "it says it's ready: BagSmith hears it, and the answers come")

	-- a Helper's switch off: no opinion, and nothing is asked
	it = { facts = facts(), raise = true }
	n, M, IT = boot(it, { makeRoomHoldItemTree = false })
	check(IT:Verdict(recOf(n, 2996)) == nil and IT:Verdict(recOf(n, 2996), true) == nil and it.calls == 0, "the Loot Helper's switch off: no opinion there, and ItemTree isn't asked")
	check(IT:Verdict(recOf(n, 2996), nil, true) == "unknown", "the Disenchant Helper's is still on: unknown there")
	n:Set("deHoldItemTree", false)
	local c = it.calls
	check(IT:Verdict(recOf(n, 2996), true, true) == nil and it.calls == c, "off too: no opinion, nothing asked")
	check((n.errors or 0) == 0, "no errors")
	_G.ItemTreeAPI = nil
end)()

-- ======== F1: the Loot Helper ========
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
		M.removeEquipmentSets()
		_G.UnitClass = function() return "Warrior", "WARRIOR" end
		M.sizes[0] = 5
		for b = 1, 5 do M.sizes[b] = 0 end
		M.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
		M.put(0, 2, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
		M.put(0, 3, { id = 9720, name = "Gnoll Paw", q = 1, count = 5, stack = 20, class = 15, subclass = 0, price = 2 })   -- 10c
		M.put(0, 4, { id = 9730, name = "Heavy Stone", q = 1, count = 1, stack = 20, class = 7, subclass = 7, price = 50 })   -- 50c
		M.put(0, 5, { id = 9731, name = "Fine Ring", q = 1, class = 4, subclass = 0, price = 80, equip = "INVTYPE_FINGER" })
		_G.ItemTreeAPI = it and fakeItemTree(it) or nil
		_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = skin or "modern", makeRoom = true, makeRoomValue = "vendor", makeRoomAsk = false }
		for k, v in pairs(prof or {}) do p[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
		local n = M.loadAddon("BagSmith")
		n.version = "1.10.0-beta13"
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
	-- ItemTree keeps the paw, the grey fang and the stone; not the belt
	local function facts() return { [9701] = fact(9701, true), [9702] = fact(9702, false), [9720] = fact(9720, true), [9730] = fact(9730, true) } end
	local REFUSAL = "ItemTree couldn't be asked about that item just now, so nothing was destroyed. Try again in a moment, or untick its Hold Back in the Loot Helper in Settings > Addon Sources."

	-- (control) no ItemTree
	do
		local n, M, MR, f = lootBoot(nil)
		check(f and f:IsShown() and offered(f) == "Broken Fang,Gnoll Paw,Linen Belt", "(control) no ItemTree: the Loot Helper offers what it always has (" .. tostring(f and offered(f)) .. ")")
		check(MR:StillOk(MR:Offer(recOf(n, 9720), false, "priced", 10)) == true, "(control) and the paw can be destroyed")
	end

	for _, skin in ipairs({ "modern", "classic" }) do
		local S0 = skin .. ": "
		-- ItemTree's data isn't loaded when the loot window opens
		local it = { facts = facts(), ready = false }
		local n, M, MR, f = lootBoot(it, skin)
		check(f and f:IsShown() and offered(f) == "Broken Fang", S0 .. "ItemTree on but not ready: what it would be asked about waits, and only your junk is offered (" .. tostring(f and offered(f)) .. ")")
		check(f.held:IsShown() and f.held.text == "2 protected items aren't offered", S0 .. "the two are counted with what isn't offered (" .. tostring(f.held.text) .. ")")
		local line = plain(f.heldInfo.lines[1])
		-- (by design since 1.10.0-beta14, Shweep: "agreed": a heading of its own that names ItemTree; it was "Couldn't be
		-- checked right now")
		check(line:find("Waiting for ItemTree (2):", 1, true) and line:find("Gnoll Paw", 1, true) and line:find("Linen Belt", 1, true) and #f.heldInfo.lines == 1, S0 .. "under Waiting for ItemTree (" .. line .. ")")
		check(it.calls == 0 and it.requested == 0, S0 .. "ItemTree wasn't asked for facts, or to load")
		local ok, why = MR:StillOk(MR:Offer(recOf(n, 9702), false, "priced", 22))
		check(ok == false and why == "itemtreeunknown", S0 .. "an offer for the belt is refused at the click (" .. tostring(why) .. ")")
		-- it becomes ready: the open Helper asks, with no click
		it.ready = true
		it.onReady(); M.runTimers()
		check(offered(f) == "Broken Fang,Linen Belt" and f.held.text == "1 protected item isn't offered", S0 .. "ItemTree says it's ready: the open Helper offers the belt, and holds the paw it keeps (" .. offered(f) .. " / " .. tostring(f.held.text) .. ")")
		check(plain(f.heldInfo.lines[1]):find("ItemTree says to keep (1):", 1, true) ~= nil, S0 .. "the paw under ItemTree's own reason now")

		-- at the click, ItemTree fails: nothing is destroyed, and it says how to go on
		local belt = MR:Offer(recOf(n, 9702), false, "priced", 22)
		check(MR:StillOk(belt) == true, S0 .. "(control) the belt passes at the click")
		for _, how in ipairs({ "raise", "silent", "odd" }) do
			it[how] = true
			ok, why = MR:StillOk(belt)
			check(ok == false and why == "itemtreeunknown", S0 .. how .. ": the belt's click is refused (" .. tostring(why) .. ")")
			local before, lines = deleted, #(M.log or {})
			MR:Destroy(belt, true)
			check(deleted == before and said(M, REFUSAL), S0 .. how .. ": even after a Yes nothing is destroyed, and it says why and what to do")
			it[how] = nil
		end
		check(MR:StillOk(belt) == true, S0 .. "ItemTree answers again: the belt passes")
		-- the audit's case: a known Keep, and ItemTree fails when asked at the click
		local paw = MR:Offer(recOf(n, 9720), false, "priced", 10)
		ok, why = MR:StillOk(paw)
		check(ok == false and why == "itemtree", S0 .. "(control) the paw ItemTree keeps is refused at the click")
		for _, how in ipairs({ "raise", "silent", "odd" }) do
			it[how] = true
			ok, why = MR:StillOk(paw)
			check(ok == false and why == "itemtreeunknown", S0 .. how .. ": a known Keep, then ItemTree fails at the click: still refused (" .. tostring(why) .. ")")
			local before = deleted
			MR:Destroy(paw, true)
			check(deleted == before, S0 .. how .. ": and nothing is destroyed")
			it[how] = nil
		end
		ok, why = MR:StillOk(paw)
		check(ok == false and why == "itemtree", S0 .. "ItemTree answers again: refused as its Keep, as before")
		-- your junk is your word: no ItemTree needed, so its silence doesn't matter
		it.raise = true
		local fang = MR:Offer(recOf(n, 9701), true)
		check(MR:StillOk(fang) == true and it.asked[9701] == nil, S0 .. "the grey fang, offered as junk, passes while ItemTree fails: it isn't asked about junk")
		-- the list drawn while it fails: answers it already gave stand; what it's never said waits
		MR:Refresh()
		check(offered(f) == "Broken Fang,Linen Belt", S0 .. "the list drawn again while ItemTree fails: its earlier answers stand (" .. offered(f) .. ")")
		-- (by design since 1.10.0-beta14: ItemTree's change notice now redraws the open Helper itself, so the failure is
		-- in place before the notice here, and the heading names ItemTree)
		it.onChange("stock"); pump(M)
		check(offered(f) == "Broken Fang" and plain(f.heldInfo.lines[1]):find("Waiting for ItemTree (2):", 1, true) ~= nil, S0 .. "ItemTree says its answers changed while it fails: both wait again (" .. offered(f) .. ")")
		-- the switch off: the Helper is as it was without ItemTree, and it isn't asked
		local calls = it.calls
		n:Set("makeRoomHoldItemTree", false); M.runTimers()
		check(offered(f) == "Broken Fang,Gnoll Paw,Linen Belt" and not f.held:IsShown() and it.calls == calls, S0 .. "Hold Back off: everything is offered again, and ItemTree isn't asked (" .. offered(f) .. ")")
		check(MR:StillOk(MR:Offer(recOf(n, 9720), false, "priced", 10)) == true and it.calls == calls, S0 .. "and the paw passes at the click, whatever ItemTree would do")
		check(it.requested == 0 and (n.errors or 0) == 0, S0 .. "no errors, and ItemTree was never asked to load anything")
		f:Hide()
	end
	_G.ItemTreeAPI = nil
end

-- ======== F1: the Disenchant Helper ========
;(function()
	local function deBoot(it, prof)
		package.loaded.mock = nil
		local M = require("mock")
		M.removeEquipmentSets()
		local DEID = 13262
		M.put(0, 1, { id = 15012, name = "Lupine Slippers of the Falcon", q = 2, count = 1, class = 4, subclass = 2, price = 296, ilvl = 16, equip = "INVTYPE_FEET", bind = 2 })
		M.put(0, 2, { id = 5387, name = "Enchanted Moonstalker Cloak", q = 2, count = 1, class = 4, subclass = 1, price = 150, ilvl = 20, equip = "INVTYPE_CLOAK" })
		M.put(0, 3, { id = 7003, name = "Rare Chest", q = 3, count = 1, class = 4, subclass = 2, price = 2000, ilvl = 45, equip = "INVTYPE_CHEST" })
		_G.ItemTreeAPI = it and fakeItemTree(it) or nil
		_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = "modern", deEnabled = true }
		for k, v in pairs(prof or {}) do p[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
		_G.IsSpellKnown = function(id) return id == DEID end
		_G.GetNumSkillLines = function() return 2 end
		_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, 300 end
		_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
		_G.RegisterStateDriver = function() end
		_G.UnregisterStateDriver = function() end
		local n = M.loadAddon("BagSmith")
		n.version = "1.10.0-beta13"
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M, n.Disenchant
	end
	local function offeredNames(DE) local t = {}; for _, e in ipairs(DE.entries or {}) do t[#t + 1] = e.name end; table.sort(t); return table.concat(t, ", ") end
	local function entry(DE, id) for _, e in ipairs(DE.entries or {}) do if e.itemID == id then return e end end end
	-- ItemTree keeps the slippers for their dust; says nothing to keep about the cloak (yet), and has no data on the chest
	local function facts() return { [15012] = fact(15012, true, "keepDisenchant"), [5387] = fact(5387, false) } end
	local REFUSAL = "ItemTree couldn't be asked about that item just now (try again in a moment, or untick its Hold Back in the Disenchant Helper in Settings > Addon Sources)"

	-- (control) no ItemTree
	local n, M, DE = deBoot(nil)
	DE:Show(); M.runTimers()
	check(offeredNames(DE) == "Enchanted Moonstalker Cloak, Lupine Slippers of the Falcon, Rare Chest", "(control) no ItemTree: the Disenchant Helper offers all three pieces (" .. offeredNames(DE) .. ")")
	check(DE:LiveCheck(entry(DE, 7003)) == true, "(control) and the chest passes at the click")

	-- not ready when the Helper opens
	local it = { facts = facts(), ready = false }
	n, M, DE = deBoot(it)
	DE:Show(); M.runTimers()
	-- (by design since 1.10.0-beta14: the reason and its heading name ItemTree; they were "unknown" and "Couldn't be
	-- checked right now")
	check(offeredNames(DE) == "" and DE.held and DE.held.total == 3 and names(DE.held.by.itemtreewait) == "Enchanted Moonstalker Cloak, Lupine Slippers of the Falcon, Rare Chest",
		"ItemTree on but not ready: nothing is offered, and all three wait (" .. offeredNames(DE) .. " / " .. names(DE.held and DE.held.by.itemtreewait) .. ")")
	local lines = n.Why:Lines(DE.held)
	check(#lines == 1 and plain(lines[1]):find("Waiting for ItemTree (3):", 1, true) ~= nil, "Not offered: Waiting for ItemTree (3) (" .. plain(lines[1]) .. ")")
	check(it.calls == 0 and it.requested == 0, "ItemTree wasn't asked for facts, or to load")
	it.ready = true
	it.onReady(); M.runTimers()
	check(offeredNames(DE) == "Enchanted Moonstalker Cloak, Lupine Slippers of the Falcon, Rare Chest" and (DE.held == nil or DE.held.total == 0),
		"it says it's ready: the open Helper offers them, the slippers it keeps for their dust among them (" .. offeredNames(DE) .. ")")

	-- at the click
	local chest, slippers, cloak = entry(DE, 7003), entry(DE, 15012), entry(DE, 5387)
	check(DE:LiveCheck(chest) == true and DE:LiveCheck(slippers) == true and DE:LiveCheck(cloak) == true, "(control) each passes at the click")
	for _, how in ipairs({ "raise", "silent", "odd" }) do
		it[how] = true
		local ok, why = DE:LiveCheck(chest)
		check(ok == false and why == REFUSAL, how .. ": the chest's click is refused, and it says what to do (" .. tostring(why) .. ")")
		ok, why = DE:LiveCheck(slippers)
		check(ok == false and why == REFUSAL, how .. ": so is the slippers': kept for their dust is an answer too, and there is none")
		it[how] = nil
	end
	check(DE:LiveCheck(chest) == true and DE:LiveCheck(slippers) == true, "ItemTree answers again: both pass")
	-- the audit's case: ItemTree comes to keep the cloak, then fails when asked at the click
	it.facts[5387] = fact(5387, true)
	local ok, why = DE:LiveCheck(cloak)
	check(ok == false and why == "ItemTree says to keep that item", "ItemTree now keeps the cloak: its click is refused (" .. tostring(why) .. ")")
	for _, how in ipairs({ "raise", "silent", "odd" }) do
		it[how] = true
		ok, why = DE:LiveCheck(cloak)
		check(ok == false and why == REFUSAL, how .. ": a known Keep, then ItemTree fails at the click: still refused (" .. tostring(why) .. ")")
		it[how] = nil
	end
	ok, why = DE:LiveCheck(cloak)
	check(ok == false and why == "ItemTree says to keep that item", "ItemTree answers again: refused as its Keep")
	DE:Refresh()
	check(offeredNames(DE) == "Lupine Slippers of the Falcon, Rare Chest" and names(DE.held.by.itemtree) == "Enchanted Moonstalker Cloak", "the list drawn again holds the cloak under ItemTree says to keep")
	-- the list while ItemTree fails about something it never answered
	-- (by design since 1.10.0-beta14: the change notice redraws the open Helper itself, so the failure is in place first)
	it.raise = true
	it.onChange("stock"); pump(M)
	check(offeredNames(DE) == "" and DE.held.total == 3 and #(DE.held.by.itemtreewait or {}) == 3, "its answers were let go while it fails: all three wait again (" .. offeredNames(DE) .. ")")
	-- the switch off
	local calls = it.calls
	n:Set("deHoldItemTree", false); M.runTimers()
	check(offeredNames(DE) == "Enchanted Moonstalker Cloak, Lupine Slippers of the Falcon, Rare Chest" and it.calls == calls, "Hold Back off: all three are offered, and ItemTree isn't asked (" .. offeredNames(DE) .. ")")
	check(DE:LiveCheck(entry(DE, 5387)) == true and it.calls == calls, "and the cloak passes at the click")
	check(it.requested == 0 and (n.errors or 0) == 0, "no errors, and ItemTree was never asked to load anything")
	if DE.frame then DE.frame:Hide() end
	_G.ItemTreeAPI = nil
end)()

-- ======== F4: the last copy leaves, and one comes back ========
;(function()
	package.loaded.mock = nil
	local M = require("mock")
	M.removeEquipmentSets()
	M.put(0, 1, { id = 2996, name = "Bolt of Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 10, ilvl = 10 })
	M.put(0, 2, { id = 6530, name = "Nightcrawlers", q = 1, count = 4, class = 0, subclass = 8, type = "Consumable", sub = "Other", price = 25, ilvl = 10 })
	local it = { facts = { [2996] = fact(2996, true), [6530] = fact(6530, false) } }
	_G.ItemTreeAPI = fakeItemTree(it)
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta13"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local IT = n.ItemTree
	check(IT:Verdict(recOf(n, 2996)) == "hold" and IT:Verdict(recOf(n, 6530)) == "clear" and it.asked[2996] == 1 and IT:Count() == 2, "(ItemTree keeps the cloth; two answers are held)")
	-- the cloth leaves the bags altogether
	local cloth = M.bags[0][1]
	M.bags[0][1] = nil
	n:Scan(); pump(M)
	check(recOf(n, 2996) == nil and IT:Count() == 1, "your last cloth leaves: its answer is let go at once (" .. IT:Count() .. " held)")
	-- ItemTree changes its mind meanwhile, with no word (nothing of yours changed for it to speak of)
	it.facts[2996] = fact(2996, false)
	M.bags[0][1] = cloth
	n:Scan(); pump(M)
	check(IT:Verdict(recOf(n, 2996)) == "clear" and it.asked[2996] == 2, "cloth comes back: ItemTree is asked again, and its answer now is the one used (asked " .. tostring(it.asked[2996]) .. " times)")
	-- a stack that only changes size is still asked again, as before
	cloth.count = 3
	n:Scan(); pump(M)
	it.facts[2996] = fact(2996, true)
	check(IT:Verdict(recOf(n, 2996)) == "hold" and it.asked[2996] == 3, "(and a stack that changed size is asked about again, as before)")
	check(it.requested == 0 and (n.errors or 0) == 0, "no errors")
	_G.ItemTreeAPI = nil
end)()

-- ======== F2: a level gained, with nothing red ========
;(function()
	local level = 20
	local WHITE = { r = 1, g = 1, b = 1 }
	package.loaded.mock = nil
	local M = require("mock")
	M.removeEquipmentSets()
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 13 })
	M.put(0, 2, { id = 9010, name = "Journeyman Staff", q = 2, count = 1, class = 2, subclass = 10, type = "Weapon", sub = "Staves", equip = "INVTYPE_2HWEAPON", bind = 2, price = 500, ilvl = 26, req = 21 })
	M.put(0, 3, { id = 9011, name = "Novice Wand", q = 2, count = 1, class = 2, subclass = 19, type = "Weapon", sub = "Wands", equip = "INVTYPE_RANGEDRIGHT", bind = 2, price = 300, ilvl = 15, req = 10 })
	_G.UnitLevel = function() return level end
	_G.C_TooltipInfo = { GetHyperlink = function() return { lines = { { leftText = "An item" }, { leftText = "Something about it", leftColor = WHITE } } } end }
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", view = "list", grp = "type" } } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta13"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); pump(M)
	local S, U, main = n.Sections, n.Usability, n.Window.main
	local function inSection(id)
		local t = {}
		for _, r in ipairs(n.items) do if r.itemID and r.cat == id then t[#t + 1] = r.name end end
		table.sort(t)
		return table.concat(t, ", ")
	end
	check(U:Usable(recOf(n, 9010)) == false and U:Usable(recOf(n, 9011)) == true, "(level 20: the staff needs 21 and can't be used yet; the wand can. No tooltip is red.)")
	local later = S:CreateWithRules("For Later", { mode = "all", rows = { { k = "bind", v = { "boe" } }, { k = "usable", v = { "yes" }, n = true } } }); pump(M)
	local now = S:CreateWithRules("Can Use", { mode = "all", rows = { { k = "bind", v = { "boe" } }, { k = "usable", v = { "yes" } } } }); pump(M)
	check(inSection(later) == "Journeyman Staff" and inSection(now) == "Novice Wand", "the staff is in For Later, the wand in Can Use (" .. inSection(later) .. " / " .. inSection(now) .. ")")
	-- a filter asks too
	local shownNow
	local real = n.Popups.UpdateCount
	n.Popups.UpdateCount = function(self, view, shown, total) if view == main and shown then shownNow = shown end return real(self, view, shown, total) end
	main.st.filters = n.CleanFilters({ rules = { mode = "all", rows = { { k = "usable", v = { "yes" } } } } })
	n:RefreshViews(true); pump(M)
	check(shownNow == 2, "a filter, Usable by Me is Yes: the cloth and the wand show (" .. tostring(shownNow) .. ")")
	-- level 21
	local reapplied = 0
	local realRe = S.Reapply
	S.Reapply = function(...) reapplied = reapplied + 1; return realRe(...) end
	level = 21
	M.fire("PLAYER_LEVEL_UP", 21); pump(M)
	check(U:Usable(recOf(n, 9010)) == true, "(level 21: the staff can be used)")
	check(reapplied == 1, "a level gained: the sections are looked at again, once (" .. reapplied .. ")")
	check(inSection(later) == "" and inSection(now) == "Journeyman Staff, Novice Wand", "the staff leaves For Later for Can Use by itself (" .. inSection(later) .. " / " .. inSection(now) .. ")")
	check(shownNow == 3, "and the filter shows it too (" .. tostring(shownNow) .. ")")
	-- another level, nothing to change: still one look, and no more
	reapplied = 0
	level = 22
	M.fire("PLAYER_LEVEL_UP", 22); pump(M)
	check(reapplied == 1 and inSection(now) == "Journeyman Staff, Novice Wand", "another level: one more look, and nothing moves (" .. reapplied .. ")")
	-- skills and spells still compare first: with the same answers, nothing is redone
	reapplied = 0
	M.fire("SKILL_LINES_CHANGED"); pump(M); M.fire("SPELLS_CHANGED"); pump(M); M.fire("UPDATE_FACTION"); pump(M)
	check(reapplied == 0, "a skill, a spell or reputation changing with the same answers: the sections aren't redone (" .. reapplied .. ")")
	-- no rule asks: a level asks nothing of the sections
	S.Reapply = realRe
	main.st.filters = n.EmptyFilters(); n:RefreshViews(true)
	S:Delete(later); S:Delete(now); pump(M)
	reapplied = 0
	S.Reapply = function(...) reapplied = reapplied + 1; return realRe(...) end
	level = 23
	M.fire("PLAYER_LEVEL_UP", 23); pump(M)
	check(reapplied == 0, "with no Usable by Me rule anywhere, a level gained asks nothing of the sections")
	S.Reapply = realRe
	n.Popups.UpdateCount = real
	check((n.errors or 0) == 0, "no errors")
	_G.UnitLevel = function() return 23 end
end)()

-- ======== F3 and F5: rules, filters and Save as Section ========
;(function()
	package.loaded.mock = nil
	local M = require("mock")
	M.removeEquipmentSets()
	M.sizes[0] = 16
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 13, ilvl = 5 })
	M.put(0, 2, { id = 4306, name = "Silk Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 150, ilvl = 30 })
	M.put(0, 3, { id = 9001, name = "Silk Robe", q = 2, count = 1, class = 4, subclass = 1, type = "Armor", sub = "Cloth", equip = "INVTYPE_ROBE", bind = 2, price = 300, ilvl = 20 })
	M.put(0, 4, { id = 2447, name = "Peacebloom", q = 1, count = 5, class = 7, subclass = 9, type = "Trade Goods", sub = "Herb", price = 10, ilvl = 5 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", view = "list", grp = "type" } } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta13"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); pump(M)
	local R, P, main = n.Rules, n.Popups, n.Window.main
	local function one(k, v, neg) return R.Clean({ mode = "all", rows = { { k = k, v = v, n = neg } } }) end

	-- F5: a placeholder is no fact
	local cold = { itemID = 17, name = "Item 17", quality = 1, qualityUnknown = true }
	check(R.NameKnown(cold) == false and R.NameKnown({ itemID = 17, name = "Item 18" }) == true and R.NameKnown({ itemID = 17, name = "" }) == false and R.NameKnown({ itemID = 17 }) == false and R.NameKnown(recOf(n, 2589)) == true,
		"\"Item 17\" for item 17 is what BagSmith shows while the game hasn't named it: not a name. Any other text is.")
	check(not R:Fits(one("name", { "item" }), cold) and not R:Fits(one("name", { "cloth" }, true), cold), "a Name rule fits it neither way: it waits for its name")
	check(not R:Fits(one("quality", { 1 }), cold) and not R:Fits(one("quality", { 2 }, true), cold), "nor does a Quality rule: Common was filled in for showing, not learned")
	check(R:Fits(one("quality", { 1 }), { itemID = 17, name = "Real Thing", quality = 1 }) and R:Fits(one("name", { "item" }), { itemID = 17, name = "Item Box" }), "(a real Common item, and a real name with Item in it, fit as ever)")
	local sec = n.Sections:CreateWithRules("Not Cloth", { mode = "all", rows = { { k = "name", v = { "cloth" }, n = true }, { k = "quality", v = { 1 } } } }); pump(M)
	check(recOf(n, 2447).cat == sec and recOf(n, 2589).cat ~= sec, "(a section, Name does not contain cloth and Quality is Common: the peacebloom, not the cloth)")
	-- the same through the scanner: two slots the game hasn't sent yet (no link, no name, no quality)
	local realSlot = C_Container.GetContainerItemInfo
	C_Container.GetContainerItemInfo = function(bag, slot)
		local info = realSlot(bag, slot)
		if info and (info.itemID == 4306 or info.itemID == 2447) then info.hyperlink, info.quality = nil, nil end
		return info
	end
	-- (by design since 1.10.0-beta16, the beta15 audit's B15-1: the scanner now keeps the link an item instance was
	-- last read with, so holding the link back from a slot that has already been read no longer makes it nameless.
	-- These checks are about a slot the game has NOT described yet, as after a login: what was kept is cleared first.)
	for g in pairs(n.instanceLinks) do n.instanceLinks[g] = nil end
	M.uncached[4306], M.uncached[2447] = true, true
	n:Scan(); pump(M)
	local silk, herb = recOf(n, 4306), recOf(n, 2447)
	check(silk.name == "Item 4306" and silk.nameUnknown == true and silk.qualityUnknown == true and silk.quality == 1, "a slot the game hasn't sent: it shows as Item 4306, Common, and both are marked as not known")
	check(silk.cat ~= sec and herb.cat ~= sec, "neither goes in the section: \"Item 4306\" has no cloth in it, and that is not the item's name")
	C_Container.GetContainerItemInfo = realSlot
	M.uncached[4306], M.uncached[2447] = nil, nil
	n:Scan(); pump(M)
	silk, herb = recOf(n, 4306), recOf(n, 2447)
	check(silk.name == "Silk Cloth" and not silk.nameUnknown and not silk.qualityUnknown, "the game sends them: the real name and quality, and the marks are gone")
	check(herb.cat == sec and silk.cat ~= sec, "now the peacebloom goes in, and the silk cloth, which has cloth in its name, stays out")
	n.Sections:Delete(sec); pump(M)

	-- F3b: the old No binding box and an item whose binding the game hasn't sent
	local pending = { itemID = 500, name = "Pending Thing", quality = 1, classID = 7 }
	local none = { itemID = 501, name = "Plain Thing", quality = 1, classID = 7, bindType = 0 }
	local old = n.CleanFilters({ bd = { None = true } })
	local folded = n.FoldFilters(n.CleanFilters({ bd = { None = true } }))
	check(folded.rules and folded.rules.rows[1].k == "bind" and not next(folded.bd), "(the old No binding box shows as a Binding rule in the Filters window)")
	check(n:FilterPredicate(old)(pending) == false and n:FilterPredicate(folded)(pending) == false, "an item whose binding isn't known yet: left out by the box, and by the rule it becomes. The same answer either way.")
	check(n:FilterPredicate(old)(none) == true and n:FilterPredicate(folded)(none) == true, "an item known not to bind: shown by both")
	check(n:FilterPredicate(old)(recOf(n, 2589)) == true and n:FilterPredicate(old)(recOf(n, 9001)) == false, "(in the bags: the cloth doesn't bind and shows; the robe binds and doesn't)")

	-- F3c: an older condition beside "any one of these"
	local legacy = n.CleanFilters({ cat = { ["Trade Goods"] = true }, rules = { mode = "any", rows = { { k = "ilvl", v = { 20 }, op = "min" }, { k = "bind", v = { "boe" } } } } })
	check(legacy.rules and legacy.rules.mode == "any" and #legacy.rules.rows == 2 and next(legacy.cat) ~= nil, "(a filter no version saves: an old Section box beside two rules under \"any one of these\")")
	local function shownBy(f)
		local t, fits = {}, n:FilterPredicate(f)
		for _, r in ipairs(n.items) do if r.itemID and fits(r) then t[#t + 1] = r.name end end
		table.sort(t)
		return table.concat(t, ", ")
	end
	local before = shownBy(legacy)
	local after = n.FoldFilters(legacy)
	check(after == legacy and next(after.cat) ~= nil and #after.rules.rows == 2, "it isn't folded: the Section box can't become a third rule of an \"any\" group without changing what shows")
	check(shownBy(after) == before, "it filters the same before and after the Filters window opens (" .. before .. ")")
	check(table.concat(n.UnfoldedWords(legacy), ",") == "Section" and #n.UnfoldedWords(n.EmptyFilters()) == 0 and #n.UnfoldedWords(nil) == 0, "the older condition is named: Section")
	check(table.concat(n.UnfoldedWords(n.CleanFilters({ cat = { Junk = true }, bd = { None = true }, w = { bags = true }, ageMin = 1 })), ",") == "Section,Binding,Bag,Time in Bags", "(each of the four older conditions has its name)")
	main.st.filters = legacy
	P:OpenFilters(main, "browse"); pump(M)
	local f = P.filter
	check(main.st.filters == legacy and shownBy(main.st.filters) == before, "the Filters window open on it: the filter is untouched")
	check(f.older:IsShown() and f.older.text == "This filter also narrows by Section, kept from an older version. That still applies, though it can't be shown as a rule here. Clear All removes it.",
		"and the window says so (" .. tostring(f.older.text) .. ")")
	check(not f.older.text:find("\226\128\148"), "with no dashes")
	-- under "all of these" the same box folds in, and there is nothing to say
	main.st.filters = n.CleanFilters({ cat = { ["Trade Goods"] = true }, rules = { mode = "all", rows = { { k = "bind", v = { "boe" } } } } })
	P:SyncFilters(); pump(M)
	check(not f.older:IsShown() and #f.list.draft.rows == 2, "the same box beside \"all of these\": it shows as one more rule, and no note")
	-- Clear All removes an older condition
	main.st.filters = legacy
	P:SyncFilters(); pump(M)
	check(f.older:IsShown(), "(back on the older filter: the note)")
	click(f.clearBtn); pump(M)
	check(not f.older:IsShown() and not next(main.st.filters.cat) and main.st.filters.rules == nil, "Clear All: the older condition is gone, and so is the note")
	-- Save as Section... leaves it behind, and says so
	local rs, note = P:SectionRules(legacy)
	check(rs and rs.mode == "any" and #rs.rows == 2 and note == "Left out, kept from an older version: Section.", "Save as Section... on it: the two rules, and what stayed behind by name (" .. tostring(note) .. ")")

	-- F3a: more rules than a section holds
	local twelve = {}
	for i = 1, 12 do twelve[i] = { k = "name", v = { "word" .. i } } end
	local full = n.CleanFilters({ q = { [1] = true }, rules = { mode = "all", rows = twelve } })
	check(#full.rules.rows == 12 and R.MAX_ROWS == 12, "(a filter with twelve rules, the most there can be, and a Quality chip)")
	rs, note = P:SectionRules(full)
	check(rs and #rs.rows == 12 and rs.rows[1].k == "quality" and rs.rows[12].v[1] == "word11", "Save as Section...: Quality comes along as a rule, which makes thirteen; a section holds twelve")
	check(note == "A section can have 12 rules, so the last one was left out: Name contains \"word12\".", "the one that didn't fit is named (" .. tostring(note) .. ")")
	-- the audit's point: the section would take more than the filter showed, so the player must be told
	local wide, narrow = { itemID = 1, name = "word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11", quality = 1 }, nil
	check(R:Fits(rs, wide) and not R:Fits(R.Clean({ mode = "all", rows = twelve }), wide), "(an item that lacks the twelfth word fits the section's rules and not the filter's: hence the note)")
	-- the Usable by Me quick pick is a rule now
	rs, note = P:SectionRules({ usable = true, rules = { mode = "all", rows = { { k = "type", v = { "7:5" } } } } })
	check(rs and #rs.rows == 2 and rs.rows[2].k == "usable" and rs.rows[2].v[1] == "yes" and not rs.rows[2].n and note == nil, "Usable by Me, ticked in the Filters window, comes along as the rule Usable by Me is Yes, with nothing to say")
	rs, note = P:SectionRules({ usable = true })
	check(rs and rs.mode == "all" and #rs.rows == 1 and rs.rows[1].k == "usable" and note == nil, "by itself it makes a section's one rule")
	rs, note = P:SectionRules({ usable = true, new = true, rules = { mode = "any", rows = { { k = "bind", v = { "boe" } }, { k = "ilvl", v = { 20 }, op = "min" } } } })
	check(rs and rs.mode == "any" and #rs.rows == 2 and note == "Left out, since a section's rules are about the item itself: New and Usable by Me.", "under \"any one of these\" it can't join the rules: left out and named, as Quality is (" .. tostring(note) .. ")")
	-- both at once: thirteen and fourteen
	local eleven = {}
	for i = 1, 11 do eleven[i] = twelve[i] end
	rs, note = P:SectionRules({ q = { [1] = true }, usable = true, rules = { mode = "all", rows = eleven } })
	check(rs and #rs.rows == 12 and note == "A section can have 12 rules, so the last one was left out: Usable by Me is Yes.", "eleven rules, Quality and Usable by Me: the last is left out and named (" .. tostring(note) .. ")")
	rs, note = P:SectionRules({ q = { [1] = true }, usable = true, new = true, text = "x", rules = { mode = "all", rows = twelve } })
	check(rs and #rs.rows == 12 and note == "A section can have 12 rules, so the last 2 were left out: Name contains \"word12\"; Usable by Me is Yes. Left out, since a section's rules are about the item itself: the search and New.",
		"twelve rules and both: two are left out, each named, beside what a section can't use (" .. tostring(note) .. ")")
	check(not note:find("\226\128\148"), "with no dashes")

	-- in the editor: the note shows, and a long one takes its room from the rules, never over them
	main.st.filters = n.CleanFilters({ q = { [1] = true }, usable = true, new = true, text = "x", rules = { mode = "all", rows = twelve } })
	P:SyncFilters(); pump(M)
	f.sheetBox:SetText("Many Words")
	click(f.sectionBtn); pump(M)
	local E = n.SectionEditor
	local ef = E.frame
	check(ef and ef:IsShown() and ef.title.text == "New Section" and #E.draft.rows == 12 and ef.err.text == note, "Save as Section... opens the editor with twelve rules and that note")
	local noteH, listH = ef.err:GetStringHeight(), ef.rules:GetHeight()
	check(noteH > 27 and (ef.noteExtra or 0) == math.ceil(noteH) - 27 and listH == 470 - 136 - 54 - ef.noteExtra, "the note is taller than the 27 px kept for it: the rules above give up exactly the difference (" .. noteH .. " tall, list " .. tostring(listH) .. ")")
	check(27 + noteH <= 54 + ef.noteExtra, "so the note ends where the rules begin, and never lies over them")
	-- a change to the rules clears the note, and the rules get their room back
	E:Changed(); pump(M)
	check(ef.err.text == "" and (ef.noteExtra or 0) == 0 and ef.rules:GetHeight() == 470 - 136 - 54, "the rules are changed: the note goes, and the list is its full height again")
	click(ef.cancel); pump(M)
	-- a short note needs no room
	main.st.filters = n.CleanFilters({ new = true, rules = { mode = "all", rows = { { k = "type", v = { "7:5" } } } } })
	P:SyncFilters(); pump(M)
	click(f.sectionBtn); pump(M)
	local shortH = math.ceil(ef.err:GetStringHeight())
	check(ef:IsShown() and ef.err.text == "Left out, since a section's rules are about the item itself: New." and (ef.noteExtra or 0) == math.max(0, shortH - 27) and ef.rules:GetHeight() == 470 - 136 - 54 - (ef.noteExtra or 0),
		"a shorter note takes only what it needs past its 27 px (" .. shortH .. " tall here, " .. tostring(ef.noteExtra) .. " taken)")
	E:Info("One line.")
	check((ef.noteExtra or 0) == 0 and ef.rules:GetHeight() == 470 - 136 - 54, "a note of one line takes nothing: the list keeps its height")
	E:Error("Give the section a name.")
	check((ef.noteExtra or 0) == 0 and ef.rules:GetHeight() == 470 - 136 - 54, "nor does an error's one line")
	click(ef.cancel); pump(M)
	main.st.filters = n.EmptyFilters(); P:SyncFilters(); f:Hide()
	check((n.errors or 0) == 0, "no errors")
end)()

-- ======== F6: the reminder for someone who never saw 1.9.8 ========
;(function()
	local function boot(seen, skin, fresh)
		package.loaded.mock = nil
		local M = require("mock")
		M.removeEquipmentSets()
		M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 13 })
		_G.ItemTreeAPI = nil
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin or "modern", view = "list" } }, whatsNewSeen = seen }
		if fresh then _G.BagSmithDB = nil end
		local n = M.loadAddon("BagSmith")
		n.version = "1.10.0-beta13"
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M, n.WhatsNew
	end
	local REMINDER = "|cfff09595Reminder:|r if two of your characters share a first name, Global Inventory and tooltips won't be 100% accurate until you've logged in to each of them and visited the bank on each. Apologies, I wish this had been caught sooner."
	-- how many of the card's shown lines are the reminder
	local function reminders(c)
		local k = 0
		for _, l in ipairs(c.lines or {}) do if l:IsShown() and type(l.text) == "string" and l.text:find("Reminder:", 1, true) then k = k + 1 end end
		return k
	end

	for _, skin in ipairs({ "modern", "classic" }) do
		local S0 = skin .. ": "
		-- straight from 1.9.7: the 1.10 card opens, with 1.9.8's note as one more bullet
		local n, M, WN = boot("1.9.7", skin)
		local e = WN.ENTRIES[4]   -- (by design since 1.10.1: one more place down, after 1.10.1's entry)   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
		-- (by design since 1.10.0-beta16, Shweep: the card rewritten as seven bullets; "we lost the reminder": it stays,
		-- last, for the same accounts. It was nine and ten.)
		check(e.v == "1.10.0" and #e.items == 7 and e.remind and e.remind.before == "1.9.8" and e.remind.text == REMINDER, S0 .. "the 1.10 card has seven bullets of its own, and a reminder from 1.9.8")
		local items = WN:Items(e)
		check(#items == 8 and items[8] == REMINDER and items[7] == e.items[7], S0 .. "coming from 1.9.7: eight bullets, the reminder last")
		check(WN.ENTRIES[4].items[8] == nil, S0 .. "(the card's own list is untouched)")   -- (by design since 1.10.1: one more place down, after 1.10.1's entry)   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
		-- 1.9.8's own words, under Reminder instead of Important
		local own
		for _, en in ipairs(WN.ENTRIES) do if en.v == "1.9.8" then own = en.items[2] end end
		check(own and REMINDER == own:gsub("Important:", "Reminder:", 1) and REMINDER:find("|cfff09595Reminder:|r", 1, true) == 1, S0 .. "it is 1.9.8's note word for word, headed Reminder, in the same soft red")
		n.Window:Show(); M.runTimers(); M.runTimers()
		local c = WN.Card and WN.Card()
		check(c and c:IsShown() and c.entries[c.sel].v == "1.10.0", S0 .. "the bags open: the 1.10 card shows")
		local drawn = reminders(c)
		check(drawn == 1, S0 .. "with the reminder drawn on it, once (" .. drawn .. ")")
		-- closing it marks 1.10 seen; the reminder stays for the rest of the session
		WN:Close()
		check(BagSmithDB.whatsNewSeen == "1.10.0" and #WN:Items(e) == 8, S0 .. "closed: 1.10 is seen, and opening What's New again this session still shows the reminder")
		check(BagSmithDB.whatsNewRemind == nil, S0 .. "nothing new is saved for it")
		check((n.errors or 0) == 0, S0 .. "no errors")

		-- from 1.9.8: nine bullets, no reminder
		n, M, WN = boot("1.9.8", skin)
		check(#WN:Items(WN.ENTRIES[4]) == 7 and next(WN.owed) == nil, S0 .. "coming from 1.9.8, which showed the note itself: seven bullets, no reminder")   -- (by design since 1.10.1: one more place down, after 1.10.1's entry)   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
		n.Window:Show(); M.runTimers(); M.runTimers()
		c = WN.Card and WN.Card()
		check(c and c:IsShown() and reminders(c) == 0, S0 .. "the card shows without it")
		if c then WN:Close() end
	end

	-- who is owed it, and who isn't
	local n, M, WN = boot("1.9.0")
	check(#WN:Items(WN.ENTRIES[4]) == 8, "from 1.9.0: owed")   -- (by design since 1.10.1: one more place down, after 1.10.1's entry)   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
	n, M, WN = boot("0.0.0")
	check(#WN:Items(WN.ENTRIES[4]) == 8, "saved data from before What's New existed: owed")   -- (by design since 1.10.1: one more place down, after 1.10.1's entry)   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
	n, M, WN = boot("1.10.0")
	check(#WN:Items(WN.ENTRIES[4]) == 7, "already on 1.10 (a beta, or the next login after closing the card): not owed")   -- (by design since 1.10.1: one more place down, after 1.10.1's entry)   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
	n, M, WN = boot(nil, "modern", true)
	check(#WN:Items(WN.ENTRIES[4]) == 7 and BagSmithDB.whatsNewSeen == "1.10.0", "a first install: nothing was skipped, so nothing to remind")   -- (by design since 1.10.1: one more place down, after 1.10.1's entry)   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
	-- other cards have no reminder, and a card without one is returned as it is
	n, M, WN = boot("1.9.7")
	for i = 5, #WN.ENTRIES do   -- (by design since 1.10.1, and again since 1.11.0-beta4: from the fourth, the 1.10 card being the third now)   -- (and since 1.12.0-beta4: from the fifth, the 1.10 card being the fourth now)
		check(WN.ENTRIES[i].remind == nil and WN:Items(WN.ENTRIES[i]) == WN.ENTRIES[i].items, "BagSmith " .. WN.ENTRIES[i].v .. ": its own bullets only")
		if i >= 5 then break end
	end
	-- the hidden test command sets things as a player updating would have them
	n, M, WN = boot("1.10.0")
	check(#WN:Items(WN.ENTRIES[4]) == 7, "(seen 1.10: no reminder)")   -- (by design since 1.10.1: one more place down, after 1.10.1's entry)   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
	WN:ResetForTesting()
	check(BagSmithDB.whatsNewSeen == "1.9.0" and #WN:Items(WN.ENTRIES[4]) == 8, "/bs new reset goes back to before 1.10, and the reminder a player from there would get comes with it")   -- (by design since 1.10.1: one more place down, after 1.10.1's entry)   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
	check((n.errors or 0) == 0, "no errors")
end)()

-- ======== F8: the words ========
;(function()
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } }, whatsNewSeen = "1.9.8" }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers()
	local e = n.WhatsNew.ENTRIES[4]   -- (by design since 1.10.1: one more place down, after 1.10.1's entry)   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
	-- (by design since 1.10.0-beta16: the card's rewrite. The sentence about the Helpers keeps the two exceptions.)
	check(e.items[6]:find("and the Loot Helper and Disenchant Helper won't offer what it says to keep, apart from your junk and gear it keeps for its dust.", 1, true) ~= nil,
		"the card's ItemTree bullet says what the Helpers do, with the two exceptions")
	local all = table.concat(n.WhatsNew:Items(e), " ") .. " " .. e.remind.text
	check(not all:find("\226\128\148") and not all:find("\226\128\147"), "no dashes on the card")
	local f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	local section = ("\n" .. log):match("\n(## 1%.10%.0\n.-)\n## 1%.9%.8\n") or ""
	local flat = section:gsub("%s+", " ")
	check(not flat:find("Other Addons", 1, true) and flat:find("and for filters ItemTree's Advice. Settings > Addon Sources turns it on or off.", 1, true), "the changelog's ItemTree line says Settings > Addon Sources")
	-- (by design since 1.10.0-beta14: the second sentence names the heading and what happens next, and a third says
	-- Clear Soul Shards is separate)
	-- (by design since 1.10.0-beta15, the beta14 audit's B14-4: "shows by itself once ItemTree answers" was too much: a
	-- Keep answer leaves it held)
	check(flat:find("A piece ItemTree keeps for its dust still shows in the Disenchant Helper, and the Loot Helper still offers your junk. While its switch is on and ItemTree hasn't answered about an item yet, that item is held back under Waiting for ItemTree. The Helper checks again by itself, and offers the item only if ItemTree doesn't say to keep it.", 1, true),
		"and says what happens when ItemTree can't answer")
	check(not section:find("\226\128\148") and not section:find("\226\128\147"), "with no dashes")
	-- the words a player reads at a refused click
	local mr = io.open("BagSmith/Core/MakeRoom.lua"); local src = mr:read("*a"); mr:close()
	check(src:find("ItemTree couldn't be asked about that item just now, so nothing was destroyed. Try again in a moment, or untick its Hold Back in the Loot Helper in Settings > Addon Sources.", 1, true), "the Loot Helper's refusal says how to go on")
	-- (by design since 1.10.0-beta14: its own heading)
	check(n.Why.LABEL.itemtreewait == "Waiting for ItemTree" and n.Why.LABEL.unknown == "Couldn't be checked right now", "and the list's heading for what waits names ItemTree")
	f = io.open("BagSmith/BagSmith.toc"); local toc = f:read("*a"); f:close()
	check(toc:find("## Version: %d+%.%d+%.%d+"), "the TOC has a version (by design since 1.11.0: later releases too; the exact one is pinned in tests/run.lua)")
end)()
