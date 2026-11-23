-- ======== 1.10.0-beta16 (Shweep, 23 Nov: "agreed, build") ========
-- The answer to the beta15 audit, and Shweep's feedback on the What's New card:
-- B15-1  (a) The scanner keeps the link an item instance was last read with, so a later read that can't give one
--        doesn't make the item nameless again. (b) A Helper only asks ItemTree about an item it can name by its link
--        (the record's, or the slot's now for the same instance): without one the item waits and a click is refused;
--        an answer by item id alone never decides a destroy or a disenchant. (c) Where the client gives no instances,
--        a link that changed under an armed piece is refused instead of taken as the same piece.
-- B15-2  Global Inventory only waits on an item where building the list again can describe it (a worn row).
-- Shweep: the 1.10 What's New card rewritten ("more technical than sells the new features"; "rest looks better tho"),
--        seven bullets, the reminder kept ("we lost the reminder"); and in Classic the card's tabs start beside the
--        portrait ("in classic style we waste a ton of space at top").

local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function deep(t) if type(t) ~= "table" then return t end local c = {}; for k, v in pairs(t) do c[k] = deep(v) end; return c end
local function pump(M) for _ = 1, 40 do M.runTimers() end end
local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
local function recAt(n, bag, slot) for _, r in ipairs(n.items) do if r.bag == bag and r.slot == slot then return r end end end
local function row(list, id) for _, r in ipairs(list or {}) do if r.itemID == id then return r end end end
local function names(list) local t = {}; for i, v in ipairs(list or {}) do t[i] = v end; table.sort(t); return table.concat(t, ", ") end
local function count(t) local k = 0; for _ in pairs(t or {}) do k = k + 1 end; return k end

local function fact(id, marked, state)
	return { itemId = id, known = true,
		keep = { marked = marked, state = state or (marked and "keep" or "vendor"), tags = { marked and "keep" or "vendor" } },
		route = { needed = false }, vendors = { buyPrice = 10, everywhere = false, count = 0 },
		uses = { reagentSkills = {}, kinds = { reagent = 0 } }, quests = { needs = {} } }
end
-- ItemTree as BagSmith meets it. state.answer(id, link) is the answer; state.links records what each question was
-- asked with (false: by item id alone).
local function fakeItemTree(state)
	state.calls, state.asked, state.links, state.requested = 0, {}, {}, 0
	return {
		version = 1,
		IsReady = function() return state.ready ~= false end,
		RequestData = function() state.requested = state.requested + 1 end,
		RegisterReadyCallback = function(fn) state.onReady = fn end,
		RegisterChangeCallback = function(fn) state.onChange = fn end,
		GetItemFacts = function(id, link)
			state.calls = state.calls + 1
			state.asked[id] = (state.asked[id] or 0) + 1
			state.links[#state.links + 1] = link or false
			if state.silent then return nil end
			if state.answer then return state.answer(id, link) end
			return deep(state.facts[id]) or { itemId = id, known = false }
		end,
	}
end
local function askedById(it) for _, l in ipairs(it.links) do if l == false then return true end end return false end
-- ItemTree keeps an item when it is asked with its link, and has nothing to keep when asked by the id alone: the
-- disagreement the audit's conditional case needs.
local function keepsByLink(id, link) return fact(id, link ~= nil) end
local function slotInfo(omit, relink)
	local real = C_Container.GetContainerItemInfo
	C_Container.GetContainerItemInfo = function(bag, slot)
		local info = real(bag, slot)
		local key = bag .. ":" .. slot
		if info and omit[key] then info.hyperlink = nil end
		if info and info.hyperlink and relink[key] then info.hyperlink = info.hyperlink:gsub("|h%[", ":60|h[", 1) end
		return info
	end
end

-- ======== B15-1: the Disenchant Helper ========
;(function()
	local omit, relink = {}, {}
	local function deBoot(it, opts)
		opts = opts or {}
		package.loaded.mock = nil
		local M = require("mock")
		M.removeEquipmentSets()
		local DEID = 13262
		M.put(0, 1, { id = 5387, name = "Test Cloak", q = 2, count = 1, class = 4, subclass = 1, price = 150, ilvl = 20, equip = "INVTYPE_CLOAK" })
		if opts.two then M.put(0, 2, { id = 5387, name = "Test Cloak", q = 2, count = 1, class = 4, subclass = 1, price = 150, ilvl = 20, equip = "INVTYPE_CLOAK" }) end
		omit, relink = {}, {}
		for _, key in ipairs(opts.omit or {}) do omit[key] = true end
		slotInfo(omit, relink)
		local getter = C_Item.GetItemGUID
		if opts.noGuid then C_Item.GetItemGUID = nil end   -- a client that gives no item instances
		_G.ItemTreeAPI = fakeItemTree(it)
		_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
		_G.IsSpellKnown = function(id) return id == DEID end
		_G.GetNumSkillLines = function() return 2 end
		_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, 300 end
		_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
		_G.RegisterStateDriver = function() end
		_G.UnregisterStateDriver = function() end
		local n = M.loadAddon("BagSmith")
		n.version = "1.10.0-beta16"
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M, n.Disenchant, getter
	end
	local function armed(DE) return DE.button:GetAttribute("type") ~= nil end
	local function press(DE) DE.button:GetScript("PreClick")(DE.button) end
	local function entryFor(rec) return { rec = rec, bag = rec.bag, slot = rec.slot, itemID = rec.itemID, link = rec.link } end
	local WAIT = "ItemTree couldn't be asked about that item just now (try again in a moment, or untick its Hold Back in the Disenchant Helper in Settings > Addon Sources)"

	-- the audit's sequence: no link, then a link with a Keep, then no link again
	local it = { facts = {}, answer = keepsByLink }
	local n, M, DE = deBoot(it, { omit = { "0:1" } })
	local IT = n.ItemTree
	local rec = recOf(n, 5387)
	check(rec.link == nil and rec.guid ~= nil and count(n.instanceLinks) == 0, "(the cloak's slot has given no link since login: its record has none, and none is kept for the instance)")
	DE:Show(); M.runTimers()
	check(#DE.entries == 0 and not armed(DE) and names(DE.held.by.itemtreewait) == "Test Cloak", "with no link the cloak waits for ItemTree and isn't listed")
	check(it.calls == 0, "ItemTree isn't asked by the item's id (where this ItemTree would have said there is nothing to keep)")
	local ok, why = DE:LiveCheck(entryFor(rec))
	check(ok == false and why == WAIT and it.calls == 0, "a click on it, with the slot still giving no link, is refused, and still ItemTree isn't asked by id")
	-- the link arrives; nothing rescans
	omit["0:1"] = nil
	local live = C_Container.GetContainerItemInfo(0, 1).hyperlink
	M.runTimers(); M.runTimers()
	check(rec.link == live and n.instanceLinks[rec.guid] == live, "the slot's link arrives: the open Helper reads it by itself, the record takes it and the instance keeps it")
	check(#DE.entries == 0 and not armed(DE) and names(DE.held.by.itemtree) == "Test Cloak" and DE.held.by.itemtreewait == nil and it.links[#it.links] == live, "asked with the link, ItemTree keeps it: held under ItemTree says to keep")
	-- a later scan reads the same slot and instance without a link again
	omit["0:1"] = true
	n:Scan(); pump(M)
	local again = recOf(n, 5387)
	check(again ~= rec and again.guid == rec.guid and again.link == live and again.name == "Test Cloak" and not again.nameUnknown, "a later scan can't read the link: the new record keeps the instance's link, and its name")
	check(#DE.entries == 0 and not armed(DE) and names(DE.held.by.itemtree) == "Test Cloak", "the list drawn again still holds it as ItemTree's Keep: it isn't listed or armed again")
	-- both live reads at a click on it
	ok, why = DE:LiveCheck(entryFor(again))
	check(ok == false and why == "ItemTree says to keep that item", "a click while the slot also gives no link (the audit's conditional case): asked with the kept link, refused as its Keep")
	omit["0:1"] = nil
	ok, why = DE:LiveCheck(entryFor(again))
	check(ok == false and why == "ItemTree says to keep that item", "a click with the link back: refused as its Keep")
	check(not askedById(it), "in all of this ItemTree was never asked about the cloak by its id alone (" .. it.calls .. " questions, each with the link)")
	DE:Close()

	-- the same instance where ItemTree has nothing to keep: listed once it can be named, and stays listed
	it = { facts = { [5387] = fact(5387, false) } }
	n, M, DE = deBoot(it, { omit = { "0:1" } })
	DE:Show(); M.runTimers()
	check(#DE.entries == 0 and it.calls == 0, "(no link: waits)")
	omit["0:1"] = nil
	live = C_Container.GetContainerItemInfo(0, 1).hyperlink
	M.runTimers(); M.runTimers()
	check(#DE.entries == 1 and DE.current.link == live and armed(DE), "the link arrives and ItemTree has nothing to keep: listed and armed")
	omit["0:1"] = true
	n:Scan(); pump(M)
	check(#DE.entries == 1 and DE.current.link == live and armed(DE), "a later scan without the link: still listed, under the link the instance keeps")
	press(DE)
	check(armed(DE), "pressed while the slot gives no link: the question goes out with the kept link, and the click passes its checks")
	check(not askedById(it), "never asked by id alone")
	DE:Close()

	-- the kept link is the instance's own
	it = { facts = { [5387] = fact(5387, false) } }
	n, M, DE = deBoot(it, { two = true })
	local a, b = recAt(n, 0, 1), recAt(n, 0, 2)
	check(a.guid ~= b.guid and n.instanceLinks[a.guid] == a.link and n.instanceLinks[b.guid] == b.link and count(n.instanceLinks) == 2, "(two cloaks, each read with its link: each instance keeps its own)")
	-- one leaves: its link goes with it
	local gone = a.guid
	M.bags[0][1] = nil
	n:Scan(); pump(M)
	check(n.instanceLinks[gone] == nil and count(n.instanceLinks) == 1, "one leaves the bags: the link kept for it is let go")
	-- a new copy of the same item arrives, and its slot gives no link: it has none, whatever other copies have
	omit["0:1"] = true
	M.put(0, 1, { id = 5387, name = "Test Cloak", q = 2, count = 1, class = 4, subclass = 1, price = 150, ilvl = 20, equip = "INVTYPE_CLOAK" })
	n:Scan(); pump(M)
	local fresh = recAt(n, 0, 1)
	check(fresh.guid ~= gone and fresh.guid ~= b.guid and fresh.link == nil and n.instanceLinks[fresh.guid] == nil, "another copy of the same item, read without a link: it borrows no link from the copy beside it or the one that left")
	check(n.ItemTree:Verdict(fresh, nil, true) == "unknown" and n.ItemTree:Verdict(recAt(n, 0, 2), nil, true) == "clear", "it waits; the copy that has its own link is answered")
	-- a kept link that isn't for this item is never used
	omit["0:2"] = true
	n.instanceLinks[b.guid] = "|cffffffff|Hitem:999|h[Something Else]|h|r"
	n:Scan(); pump(M)
	check(recAt(n, 0, 2).link == nil, "a kept link for a different item id is not given to the slot's item")
	check((n.errors or 0) == 0 and it.requested == 0, "no errors, and ItemTree was never asked to load anything")

	-- a client that gives no item instances
	it = { facts = { [5387] = fact(5387, false) } }
	local getter
	n, M, DE, getter = deBoot(it, { noGuid = true, omit = { "0:1" } })
	rec = recOf(n, 5387)
	check(rec.guid == nil and rec.link == nil and count(n.instanceLinks) == 0, "(no instances on this client: the record has none, and nothing is kept)")
	DE:Show(); M.runTimers()
	check(#DE.entries == 0 and names(DE.held.by.itemtreewait) == "Test Cloak" and it.calls == 0, "no link: it waits there too")
	omit["0:1"] = nil
	M.runTimers(); M.runTimers()
	check(#DE.entries == 1 and DE.current.link ~= nil and armed(DE), "the slot's link arrives: read, asked with, listed")
	-- its link changes under the armed piece: nothing says it is the same piece
	local old = DE.current.link
	relink["0:1"] = true
	local changed = C_Container.GetContainerItemInfo(0, 1).hyperlink
	check(changed ~= old, "(the slot now reads a different link)")
	local e = DE.current
	ok, why = DE:LiveCheck(e)
	check(ok == false and why == "that item's link changed and it couldn't be confirmed as the same piece", "a different link under the armed piece, with no instance to confirm it: refused (" .. tostring(why) .. ")")
	check(e.link == old and e.rec.link == old, "and the armed piece's link is left as it was")
	check(n.rescanPending == true, "the bags are set to be read again")
	pump(M)
	check(recOf(n, 5387).link == changed, "read again, the record is the slot's item as it is now")
	C_Item.GetItemGUID = getter
	DE:Close()
	_G.ItemTreeAPI = nil
end)()

-- ======== B15-1: the Loot Helper ========
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
	local omit, relink = {}, {}
	local function lootBoot(it, skin, omitAtStart)
		package.loaded.mock = nil
		local M = require("mock")
		M.removeEquipmentSets()
		_G.UnitClass = function() return "Warrior", "WARRIOR" end
		M.sizes[0] = 5
		for b = 1, 5 do M.sizes[b] = 0 end
		M.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
		M.put(0, 2, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
		M.put(0, 3, { id = 9720, name = "Gnoll Paw", q = 1, count = 5, stack = 20, class = 15, subclass = 0, price = 2 })
		M.put(0, 4, { id = 9730, name = "Heavy Stone", q = 1, count = 1, stack = 20, class = 7, subclass = 7, price = 50 })
		M.put(0, 5, { id = 9731, name = "Fine Ring", q = 1, class = 4, subclass = 0, price = 80, equip = "INVTYPE_FINGER" })
		omit, relink = {}, {}
		for _, key in ipairs(omitAtStart or {}) do omit[key] = true end
		slotInfo(omit, relink)
		_G.ItemTreeAPI = it and fakeItemTree(it) or nil
		_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin or "modern", makeRoom = true, makeRoomValue = "vendor", makeRoomAsk = false } } }
		local n = M.loadAddon("BagSmith")
		n.version = "1.10.0-beta16"
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
	local function heldLine(f, words) for _, l in ipairs(f.heldInfo.lines or {}) do if plain(l):find(words, 1, true) then return plain(l) end end end

	for _, skin in ipairs({ "modern", "classic" }) do
		local S0 = skin .. ": "
		-- the belt (kept by ItemTree when asked with its link) and the grey fang, both in slots that gave no link
		local it = { facts = {}, answer = function(id, link) if id == 9702 then return fact(id, link ~= nil) end return fact(id, false) end }
		local n, M, MR, f = lootBoot(it, skin, { "0:1", "0:2" })
		local IT = n.ItemTree
		check(recOf(n, 9702).link == nil and recOf(n, 9701).link == nil, S0 .. "(the belt and the fang were read without links)")
		check(offered(f) == "Broken Fang,Gnoll Paw" and heldLine(f, "Waiting for ItemTree (1): Linen Belt") ~= nil, S0 .. "the belt waits for ItemTree; your junk is offered all the same, link or no link (" .. tostring(offered(f)) .. ")")
		check(it.asked[9702] == nil and it.asked[9701] == nil, S0 .. "ItemTree isn't asked about either by id: not the belt, and never about junk")
		local nolink = MR:Offer(recOf(n, 9702), false, "priced", 22)
		local ok, why = MR:StillOk(nolink)
		check(ok == false and why == "itemtreeunknown" and it.asked[9702] == nil, S0 .. "an offer for the belt while its slot still gives no link is refused, and ItemTree still isn't asked by id")
		local before = deleted
		MR:Destroy(nolink, true)
		check(deleted == before, S0 .. "nothing is destroyed")
		-- the link arrives
		omit["0:2"] = nil
		local live = C_Container.GetContainerItemInfo(0, 2).hyperlink
		M.runTimers(); M.runTimers()
		check(recOf(n, 9702).link == live and offered(f) == "Broken Fang,Gnoll Paw" and heldLine(f, "ItemTree says to keep (1): Linen Belt") ~= nil, S0 .. "the belt's link arrives: read by the open Helper, asked with, and held as ItemTree's Keep (" .. tostring(offered(f)) .. ")")
		-- a later scan can't read the link
		omit["0:2"] = true
		n:Scan(); pump(M)
		check(recOf(n, 9702).link == live and heldLine(f, "ItemTree says to keep (1): Linen Belt") ~= nil and offered(f) == "Broken Fang,Gnoll Paw", S0 .. "a later scan without the link: the belt keeps its link and stays held as ItemTree's Keep")
		local held = MR:Offer(recOf(n, 9702), false, "priced", 22)
		ok, why = MR:StillOk(held)
		check(held.link == live and ok == false and why == "itemtree", S0 .. "a click while the slot also gives no link: asked with the kept link, refused as its Keep (" .. tostring(why) .. ")")
		check(not askedById(it), S0 .. "ItemTree was never asked by item id alone")
		check(it.requested == 0 and (n.errors or 0) == 0, S0 .. "no errors, and ItemTree was never asked to load anything")
		f:Hide()
	end

	-- with Hold Back off, a slot without a link changes nothing: ItemTree has no say
	do
		local it = { facts = {}, answer = keepsByLink }
		local n, M, MR, f = lootBoot(it, "modern", { "0:2" })
		local calls = it.calls
		n:Set("makeRoomHoldItemTree", false); M.runTimers()
		check(offered(f) == "Broken Fang,Gnoll Paw,Linen Belt" and it.calls == calls and it.asked[9702] == nil, "Hold Back off: the belt without a link is offered as it always was, and ItemTree isn't asked (" .. offered(f) .. ")")
		check(MR:StillOk(MR:Offer(recOf(n, 9702), false, "priced", 22)) == true and it.calls == calls, "and passes at the click")
		f:Hide()
	end
	_G.ItemTreeAPI = nil
end

-- ======== B15-2: Global Inventory waits only where waiting can help ========
;(function()
	package.loaded.mock = nil
	local M = require("mock")
	M.removeEquipmentSets()
	_G.ItemTreeAPI = nil
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", view = "list" } } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta16"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local Inv, R = n.Inventory, n.Rules
	local realm = n:Realm()
	local alt = { name = "Coldalt", realm = realm, items = {}, bank = { { itemID = 703, name = "Item 703", quality = 1, qualityUnknown = true, nameUnknown = true, count = 1 } }, equipped = { { itemID = 700 } } }
	BagSmithDB.cache.a_cold = alt
	local provider = {}
	local real = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(key)
		if provider[key] then return provider[key], nil, 2, 1, 1, "Armor", "Cloth", 1 end
		return real(key)
	end
	Inv:Touch()
	local list = Inv:GlobalRecords(false)
	local bank, worn = row(list, 703), row(list, 700)
	check(bank and not R.QualityKnown(bank) and worn and not R.QualityKnown(worn), "(another character's bank row and a worn piece, neither described by the game yet)")
	check(Inv:WaitingOn(700) == true, "the list waits on the worn piece: it is read from the game each time the list is built")
	check(Inv:WaitingOn(703) == false, "it doesn't wait on the bank row: that comes from a saved snapshot, which building again can't describe")
	-- data arrives for the saved row: nothing is rebuilt (it would change nothing)
	local builds = Inv.builds
	provider[703] = "Bank Thing"
	M.fire("GET_ITEM_INFO_RECEIVED", 703, true); pump(M)
	list = Inv:GlobalRecords(false)
	check(Inv.builds == builds and not R.QualityKnown(row(list, 703)), "item data for the saved row: no rebuild, and the row is as it was saved (until that character is seen again)")
	-- data arrives for the worn piece: rebuilt once, described
	provider[700] = "Worn Thing"
	M.fire("GET_ITEM_INFO_RECEIVED", 700, true); pump(M)
	list = Inv:GlobalRecords(false)
	check(Inv.builds == builds + 1 and row(list, 700).name == "Worn Thing" and R.QualityKnown(row(list, 700)) and Inv:WaitingOn(700) == false, "item data for the worn piece: built once more, and described")
	-- a saved cold copy beside a worn cold copy of the same item: waiting helps, since the worn one can be described
	alt.bank = { { itemID = 705, name = "Item 705", quality = 1, qualityUnknown = true, nameUnknown = true, count = 2 } }
	alt.equipped = { { itemID = 705 } }
	Inv:Touch()
	local g = row(Inv:GlobalRecords(false), 705)
	check(g.count == 3 and not R.QualityKnown(g) and Inv:WaitingOn(705) == true, "a saved copy and a worn copy of one item, both cold: the list waits, for the worn one's sake")
	provider[705] = "Both Places"
	M.fire("GET_ITEM_INFO_RECEIVED", 705, true); pump(M)
	g = row(Inv:GlobalRecords(false), 705)
	check(g.count == 3 and g.name == "Both Places" and R.QualityKnown(g), "its data arrives: the worn copy, now described, stands for the three (" .. tostring(g.name) .. ")")
	C_Item.GetItemInfo = real
	BagSmithDB.cache.a_cold = nil
	check((n.errors or 0) == 0, "no errors")
end)()

-- ======== Shweep: the What's New card, its words and its Classic top ========
local CARD = {
	"|cfffac775Sections That Sort Themselves:|r done dragging every new item to the right spot? Tell a section what belongs in it, like cloth, or gear that binds when equipped, and your loot files itself from then on. Click the pencil beside a section in Settings > Custom Sections. You'll see what lands there before you save.",
	"|cfffac775Start in One Click:|r Alt+Left-click any item and pick New Section From This Item, and BagSmith sets up a section for things like it. Or pick a ready-made one in Settings > Custom Sections: Cloth, Herbs, Gear to Sell, or Food and Drink.",
	"|cfffac775Simpler Filters:|r the Filters window is rebuilt around the same rules. Narrow your bags down in a couple of clicks, and when you like what you see, Save as Section keeps it for good.",
	"|cfffac775Tabs Your Way:|r show a section on every tab or only the ones you pick, so Cloth, Leather and Herbs can break up your Trade Goods tab while All stays tidy. Your Gear, Consumables, Trade Goods, Quest and Junk tabs now show everything of their kind, too.",
	"|cfffac775All Items, Where You Want It:|r using Sections: All? Drag the All Items title to put your pinned sections and Favorites above or below it. Pin to Top is now called Pin Section.",
	"|cfffac775Friends With Your Other Addons:|r have ItemTree? Your sections can sort by what it knows, like Used by My Professions or Needed for a Quest, and the Loot Helper and Disenchant Helper won't offer what it says to keep, apart from your junk and gear it keeps for its dust. Everything BagSmith does with Auctionator, Blackthornes Tradeskills, ItemTree and Pawn now lives in Settings > Addon Sources, each with its own switch. Auction Price Source moved there too. All of it is optional.",
	"|cfffac775A Cleaner Classic Look:|r sharper item icons and borders in the Classic skin. Thanks to Jeor!",
}
local REMINDER = "|cfff09595Reminder:|r if two of your characters share a first name, Global Inventory and tooltips won't be 100% accurate until you've logged in to each of them and visited the bank on each. Apologies, I wish this had been caught sooner."

for _, skin in ipairs({ "modern", "classic" }) do
	local S0 = skin .. ": "
	local function boot(seen)
		package.loaded.mock = nil
		local M = require("mock")
		M.removeEquipmentSets()
		M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 13 })
		_G.ItemTreeAPI = nil
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, view = "list" } }, whatsNewSeen = seen }
		local n = M.loadAddon("BagSmith")
		n.version = "1.10.0-beta16"
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M, n.WhatsNew
	end
	local n, M, WN = boot("1.9.8")
	local e = WN.ENTRIES[1]
	check(e.v == "1.10.0" and #e.items == 7, S0 .. "the 1.10 card has seven bullets")
	for i, want in ipairs(CARD) do check(e.items[i] == want, S0 .. "bullet " .. i .. ", word for word, as Shweep approved it: " .. (want:match("^|cfffac775(.-):|r") or "?")) end
	local text = table.concat(e.items, " ")
	check(not text:find("\226\128\148") and not text:find("\226\128\147"), S0 .. "no dashes")
	check(select(2, text:gsub("Thanks to Jeor!", "")) == 1, S0 .. "Jeor is thanked for the Classic icons")
	check(text:find("apart from your junk and gear it keeps for its dust", 1, true) ~= nil, S0 .. "what the Helpers hold back is still said with its two exceptions (the beta12 audit's F8)")
	check(not text:find("Disenchant Helper and Junk", 1, true), S0 .. "the junk line is off the card (it stays in the changelog)")
	-- its links open real pages
	local P = n.SettingsPanel
	local pages = {}
	for _, it in ipairs(e.items) do
		for key, heading in WN.Linkify(it):gmatch("|Hbagsmith:settings:([%w]+):([^|]*)|h") do
			pages[#pages + 1] = key
			P:Show(); P:ShowPage(key); M.runTimers()
			check(heading == "" and P.page == key, S0 .. "the link to " .. key .. " opens that page")
		end
	end
	P:Hide()
	check(table.concat(pages, ",") == "custom,custom,addons", S0 .. "its links: Custom Sections twice, Addon Sources (" .. table.concat(pages, ",") .. ")")
	-- the top of the card
	n.Window:Show(); M.runTimers(); M.runTimers()
	local c = WN.Card()
	check(c and c:IsShown() and c.entries[c.sel].v == "1.10.0", S0 .. "(the card is open on 1.10)")
	local _, _, _, tx, ty = c.tabs[1]:GetPoint(1)
	local _, _, _, ix, iy = c.intro:GetPoint(1)
	local right = tx
	for _, b in ipairs(c.tabs) do if b:IsShown() then right = math.max(right, select(4, b:GetPoint(1)) + b:GetWidth()) end end
	if skin == "classic" then
		check(tx == 60 and ty == -30, S0 .. "the tabs start beside the portrait, just under the title strip (" .. tostring(tx) .. ", " .. tostring(ty) .. "); they started at 16, 60 down")
		check(tx >= 53 + 5, S0 .. "clear of the portrait, which reaches 53 across")
		check(right <= 512 - 16, S0 .. "and the row still fits the card (" .. tostring(right) .. " of 496)")
		check(ix == 16 and iy == -88, S0 .. "the notes start 88 down, where they started 116: 28 back (" .. tostring(iy) .. ")")
		-- a release with updates: its buttons start at the left edge, under the portrait's foot
		for i, en in ipairs(c.entries) do if en.v == "1.9.0" then WN:Select(i) end end
		M.runTimers()
		local sub = c.subTabs and c.subTabs[1]
		local _, _, _, sx, sy = sub:GetPoint(1)
		check(sub:IsShown() and sx == 16 and sy == -60, S0 .. "1.9's update buttons start at the left edge 60 down, below the portrait, which ends at 51 (" .. tostring(sx) .. ", " .. tostring(sy) .. ")")
	else
		check(tx == 16 and ty == -54, S0 .. "Modern's tabs are where they were, under the logo and title (" .. tostring(tx) .. ", " .. tostring(ty) .. ")")
		check(ix == 16 and iy == -110, S0 .. "and its notes start where they did (" .. tostring(iy) .. ")")
	end
	WN:Close()
	check((n.errors or 0) == 0, S0 .. "no errors")
	-- the reminder is not lost
	check(e.remind and e.remind.before == "1.9.8" and e.remind.text == REMINDER and #WN:Items(e) == 7, S0 .. "the reminder is still on the entry; someone coming from 1.9.8 doesn't get it")
	local n2, M2, WN2 = boot("1.9.7")
	local items = WN2:Items(WN2.ENTRIES[1])
	check(#items == 8 and items[8] == REMINDER and items[7] == CARD[7], S0 .. "someone coming from 1.9.7 gets it as the eighth and last bullet")
	n2.Window:Show(); M2.runTimers(); M2.runTimers()
	local c2 = WN2.Card()
	local drawn = 0
	for _, l in ipairs(c2 and c2.lines or {}) do if l:IsShown() and type(l.text) == "string" and l.text:find("Reminder:", 1, true) then drawn = drawn + 1 end end
	check(c2 and c2:IsShown() and drawn == 1, S0 .. "and it is drawn on the card, once")
	WN2:Close()

	check((n2.errors or 0) == 0, S0 .. "no errors")
end

;(function()
	local f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	local section = ("\n" .. log):match("\n(## 1%.10%.0\n.-)\n## 1%.9%.8\n") or ""
	check(section:find("The Disenchant Helper no longer offers an item you've marked as junk.", 1, true) ~= nil, "the junk line that left the card is in the changelog")
	f = io.open("BagSmith/BagSmith.toc"); local toc = f:read("*a"); f:close()
	check(toc:find("## Version: 1.10.0", 1, true), "the TOC says 1.10.0 (the exact version is pinned in tests/run.lua)")
end)()
