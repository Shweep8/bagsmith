-- ======== 1.10.0-beta15 (Shweep, 23 Nov: "1. yes gold in classic style 2. agreed / build") ========
-- The answer to the beta14 audit, and Shweep's feedback on beta14:
-- B14-1  A slot that gains its item link after the scan (or whose link changes) no longer brings back an offer the
--        click just refused: once the click has validated the slot, the listed item takes the live link, so the list
--        and the click ask ItemTree about one key.
-- B14-2  Global Inventory: a group of copies shows the first copy the game has described, not simply the first; and
--        item data arriving for a row the list had marked "not known yet" rebuilds the list.
-- B14-3  An imported filter's "Binds when used" becomes the Binding rule's choice instead of being dropped; a binding
--        the rule has no word for stays in its field.
-- B14-4  The changelog no longer says a waiting item shows once ItemTree answers (a Keep answer leaves it held).
-- Shweep: NEW beside the New Section... button ("yes just add to that one button please"); a selected Quality chip
--        is gold in Classic like every other selected chip ("yes gold in classic style").

local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function deep(t) if type(t) ~= "table" then return t end local c = {}; for k, v in pairs(t) do c[k] = deep(v) end; return c end
local function click(b) b:GetScript("OnClick")(b) end
local function pump(M) for _ = 1, 40 do M.runTimers() end end
local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
local function recAt(n, bag, slot) for _, r in ipairs(n.items) do if r.bag == bag and r.slot == slot then return r end end end
local function row(list, id) for _, r in ipairs(list or {}) do if r.itemID == id then return r end end end
local function names(list) local t = {}; for i, v in ipairs(list or {}) do t[i] = v end; table.sort(t); return table.concat(t, ", ") end
local QUALITY_COLORS = { [0] = { r = 0.62, g = 0.62, b = 0.62 }, { r = 1, g = 1, b = 1 }, { r = 0.12, g = 1, b = 0 }, { r = 0, g = 0.44, b = 0.87 }, { r = 0.64, g = 0.21, b = 0.93 }, { r = 1, g = 0.5, b = 0 } }

local function fact(id, marked, state)
	return { itemId = id, known = true,
		keep = { marked = marked, state = state or (marked and "keep" or "vendor"), tags = { marked and "keep" or "vendor" } },
		route = { needed = false }, vendors = { buyPrice = 10, everywhere = false, count = 0 },
		uses = { reagentSkills = {}, kinds = { reagent = 0 } }, quests = { needs = {} } }
end
-- ItemTree as BagSmith meets it. state.answer(id, link), when set, is the answer (nil: nothing back); else state.silent
-- answers nothing; else its facts by id, and a table that says "no data" for an id it doesn't have.
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
			if state.answer then return state.answer(id, link) end
			if state.silent then return nil end
			return deep(state.facts[id]) or { itemId = id, known = false }
		end,
	}
end
-- The game's slot info with the link held back for some slots (omit[bag .. ":" .. slot]), or changed (relink).
local function slotInfo(M, omit, relink)
	local real = C_Container.GetContainerItemInfo
	C_Container.GetContainerItemInfo = function(bag, slot)
		local info = real(bag, slot)
		local key = bag .. ":" .. slot
		if info and omit[key] then info.hyperlink = nil end
		if info and info.hyperlink and relink and relink[key] then info.hyperlink = info.hyperlink:gsub("|h%[", ":60|h[", 1) end
		return info
	end
end

-- ======== B14-1: the Disenchant Helper ========
;(function()
	local omit, relink = {}, {}
	local function deBoot(it, two)
		package.loaded.mock = nil
		local M = require("mock")
		M.removeEquipmentSets()
		local DEID = 13262
		M.put(0, 1, { id = 5387, name = "Test Cloak", q = 2, count = 1, class = 4, subclass = 1, price = 150, ilvl = 20, equip = "INVTYPE_CLOAK" })
		if two then M.put(0, 2, { id = 5387, name = "Test Cloak", q = 2, count = 1, class = 4, subclass = 1, price = 150, ilvl = 20, equip = "INVTYPE_CLOAK" }) end
		omit, relink = {}, {}
		slotInfo(M, omit, relink)
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
		n.version = "1.10.0-beta15"
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M, n.Disenchant
	end
	local function armed(DE) return DE.button:GetAttribute("type") ~= nil end
	local function press(DE) DE.button:GetScript("PreClick")(DE.button) end

	-- a slot read before its link was there, then ItemTree answers nothing at the click
	local it = { facts = { [5387] = fact(5387, false) } }
	local n, M, DE = deBoot(it)
	local IT = n.ItemTree
	-- (By design since 1.10.0-beta16, the beta15 audit's B15-1. In beta15 a piece whose slot gave no link was listed on
	-- ItemTree's answer for the item id, and the click then moved it to the live link. Since beta16 a Helper only asks
	-- ItemTree about an item it can name by its link: without one the piece WAITS, is not listed, and ItemTree is not
	-- asked by id at all; the open Helper reads the slot's link by itself when it arrives. The sequences below are the
	-- same ones, as they now go. "Not read with a link yet" also needs the scanner's kept links cleared, as after a
	-- login, since an instance now keeps the link it was last read with.)
	local function forget() for g in pairs(n.instanceLinks) do n.instanceLinks[g] = nil end end
	omit["0:1"] = true
	forget()
	n:Scan()
	DE:Show(); M.runTimers()
	check(#DE.entries == 0 and not armed(DE) and names(DE.held.by.itemtreewait) == "Test Cloak" and recOf(n, 5387).link == nil, "a slot read without a link: the cloak waits for ItemTree and isn't listed (its details were known by id)")
	check(not n.pendingInfo and it.calls == 0, "ItemTree wasn't asked by the item's id, and no rescan is waiting")
	omit["0:1"] = nil   -- the game now gives the slot's link; nothing rescans
	local live = C_Container.GetContainerItemInfo(0, 1).hyperlink
	check(type(live) == "string", "(the slot has its link now)")
	M.runTimers(); M.runTimers()
	local listed = DE.current
	check(listed and listed.itemID == 5387 and listed.link == live and listed.rec.link == live and armed(DE) and it.links[#it.links] == live, "the open Helper reads the link by itself, asks ItemTree with it, and lists and arms the cloak")
	it.silent = true
	press(DE)
	check(not armed(DE) and DE.current == nil, "ItemTree answers nothing as the button is pressed: disarmed, nothing cast")
	check(it.links[#it.links] == live, "(the click asked ItemTree with the live link)")
	check(recOf(n, 5387).link == live and listed.link == live, "the listed piece has taken the live link: the list and the click now ask about one key")
	M.runTimers()
	check(#DE.entries == 0 and not armed(DE) and names(DE.held.by.itemtreewait) == "Test Cloak", "the next frame's list doesn't arm it again: it waits for ItemTree (" .. names(DE.held.by.itemtreewait) .. ")")
	it.silent = nil
	M.runTimers(); M.runTimers()
	check(#DE.entries == 1 and DE.current and DE.current.link == live and armed(DE), "ItemTree answers again: offered and armed again by itself, under the live link")
	press(DE)
	check(armed(DE), "and the click passes its checks")
	DE:Close()

	-- the same slot, and ItemTree says Keep when asked with the link (and nothing to keep when asked by id alone)
	it = { facts = {}, answer = function(id, link) return fact(id, link ~= nil) end }
	n, M, DE = deBoot(it)
	local function forget2() for g in pairs(n.instanceLinks) do n.instanceLinks[g] = nil end end
	omit["0:1"] = true
	forget2()
	n:Scan()
	DE:Show(); M.runTimers()
	check(#DE.entries == 0 and not armed(DE) and it.calls == 0, "(read without a link: it waits, and ItemTree isn't asked by the item's id, where it would have said nothing to keep)")
	omit["0:1"] = nil
	live = C_Container.GetContainerItemInfo(0, 1).hyperlink
	M.runTimers(); M.runTimers()
	local rec = recOf(n, 5387)
	local ok, why = DE:LiveCheck({ rec = rec, bag = rec.bag, slot = rec.slot, itemID = rec.itemID, link = rec.link })
	check(rec.link == live and ok == false and why == "ItemTree says to keep that item", "ItemTree keeps it under its link: a click on it is refused as its Keep")
	press(DE)
	check(not armed(DE) and DE.current == nil, "pressed: nothing is armed")
	M.runTimers()
	check(#DE.entries == 0 and not armed(DE) and names(DE.held.by.itemtree) == "Test Cloak" and DE.held.by.itemtreewait == nil, "the next frame's list holds it under ItemTree says to keep, and arms nothing")
	pump(M)
	check(#DE.entries == 0 and not armed(DE), "and it stays held")
	DE:Close()

	-- a link that changes after the scan (your level is part of an item's link)
	it = { facts = { [5387] = fact(5387, false) } }
	n, M, DE = deBoot(it)
	DE:Show(); M.runTimers()
	local old = DE.current and DE.current.link
	check(type(old) == "string" and armed(DE), "(listed and armed with the link the scan read)")
	relink["0:1"] = true
	live = C_Container.GetContainerItemInfo(0, 1).hyperlink
	check(live ~= old, "(the same slot now reads a different link)")
	it.silent = true
	press(DE)
	check(not armed(DE) and recOf(n, 5387).link == live, "ItemTree answers nothing at the click: disarmed, and the listed piece takes the live link")
	M.runTimers()
	check(#DE.entries == 0 and not armed(DE) and names(DE.held.by.itemtreewait) == "Test Cloak", "not armed again on the old link's answer: it waits")
	it.silent = nil
	M.runTimers(); M.runTimers()
	check(#DE.entries == 1 and armed(DE) and DE.current.link == live, "offered again by itself once ItemTree answers")
	DE:Close()

	-- only that slot: another copy read without a link keeps its own answer
	it = { facts = {}, answer = function(id, link) return fact(id, link ~= nil) end }
	n, M, DE = deBoot(it, true)
	IT = n.ItemTree
	omit["0:1"], omit["0:2"] = true, true
	for g in pairs(n.instanceLinks) do n.instanceLinks[g] = nil end
	n:Scan()
	DE:Show(); M.runTimers()
	check(#DE.entries == 0 and #DE.held.by.itemtreewait == 2, "(two copies of the cloak, both read without a link: both wait)")
	omit["0:1"] = nil   -- the first slot's link arrives; the second's hasn't
	M.runTimers(); M.runTimers()
	local first = recAt(n, 0, 1)
	ok, why = DE:LiveCheck({ rec = first, bag = 0, slot = 1, itemID = 5387, link = first.link })
	check(first.link ~= nil and ok == false and why == "ItemTree says to keep that item", "the first copy, asked with its link, is ItemTree's Keep: refused")
	DE:Refresh()
	check(#DE.entries == 0 and names(DE.held.by.itemtree) == "Test Cloak" and names(DE.held.by.itemtreewait) == "Test Cloak", "the first is held as ItemTree's Keep; the second, still without a link, still waits")
	check(recAt(n, 0, 1).link ~= nil and recAt(n, 0, 2).link == nil and IT:Verdict(recAt(n, 0, 2), nil, true) == "unknown", "only the slot that gave a link took one; the other copy borrowed neither the link nor the Keep")
	check(it.requested == 0 and (n.errors or 0) == 0, "no errors, and ItemTree was never asked to load anything")
	DE:Close()
	_G.ItemTreeAPI = nil
end)()

-- ======== B14-1: the Loot Helper ========
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
		slotInfo(M, omit, relink)
		_G.ItemTreeAPI = it and fakeItemTree(it) or nil
		_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin or "modern", makeRoom = true, makeRoomValue = "vendor", makeRoomAsk = false } } }
		local n = M.loadAddon("BagSmith")
		n.version = "1.10.0-beta15"
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

	for _, skin in ipairs({ "modern", "classic" }) do
		local S0 = skin .. ": "
		-- the belt's slot had no link when the bags were read; ItemTree keeps the belt when asked with its link
		local it = { facts = {}, answer = function(id, link) if id == 9702 then return fact(id, link ~= nil) end return fact(id, id == 9720) end }
		local n, M, MR, f = lootBoot(it, skin, { "0:2" })
		local IT = n.ItemTree
		-- (by design since 1.10.0-beta16, B15-1: read without a link, the belt waits; it was offered on the id's answer)
		check(recOf(n, 9702).link == nil and offered(f) == "Broken Fang" and it.asked[9702] == nil, S0 .. "(the belt, read without a link, waits: ItemTree isn't asked about it by id) (" .. tostring(offered(f)) .. ")")
		local belt = MR:Offer(recOf(n, 9702), false, "priced", 22)
		check(belt.link == nil, S0 .. "(the offer has no link either)")
		omit["0:2"] = nil
		local live = C_Container.GetContainerItemInfo(0, 2).hyperlink
		local ok, why = MR:StillOk(belt)
		check(ok == false and why == "itemtree", S0 .. "the slot has its link at the click, and ItemTree keeps the belt under it: refused (" .. tostring(why) .. ")")
		check(belt.link == live and recOf(n, 9702).link == live, S0 .. "the offer and the listed item have taken the live link")
		check(IT:Verdict(recOf(n, 9702)) == "hold", S0 .. "so the list's own question now gets the same answer")
		local before = deleted
		MR:Destroy(belt, true)
		check(deleted == before, S0 .. "nothing is destroyed")
		MR:Refresh()
		check(offered(f) == "Broken Fang" and f.held.text == "2 protected items aren't offered" and plain(f.heldInfo.lines[1]):find("ItemTree says to keep (2):", 1, true) ~= nil,
			S0 .. "the list drawn again holds the belt with the paw, under ItemTree says to keep (" .. offered(f) .. " / " .. plain(f.heldInfo.lines[1]) .. ")")
		f:Hide()

		-- the same, with ItemTree answering nothing at the click
		it = { facts = { [9702] = fact(9702, false), [9720] = fact(9720, true) } }
		n, M, MR, f = lootBoot(it, skin, { "0:2" })
		check(offered(f) == "Broken Fang" and it.asked[9702] == nil, S0 .. "(read without a link: it waits, by design since beta16)")
		belt = MR:Offer(recOf(n, 9702), false, "priced", 22)
		omit["0:2"] = nil
		live = C_Container.GetContainerItemInfo(0, 2).hyperlink
		it.silent = true
		ok, why = MR:StillOk(belt)
		check(ok == false and why == "itemtreeunknown" and recOf(n, 9702).link == live, S0 .. "ItemTree answers nothing at the click: refused, and the listed belt takes the live link")
		MR:Refresh()
		check(offered(f) == "Broken Fang" and plain(f.heldInfo.lines[#f.heldInfo.lines]):find("Waiting for ItemTree (1): Linen Belt", 1, true) ~= nil, S0 .. "the list drawn again doesn't offer it on the id's old answer: it waits (" .. offered(f) .. ")")
		it.silent = nil
		M.runTimers(); M.runTimers()
		check(offered(f) == "Broken Fang,Linen Belt", S0 .. "ItemTree answers again: offered again by itself")
		check(MR:StillOk(MR:Offer(recOf(n, 9702), false, "priced", 22)) == true, S0 .. "and it passes at the click")
		-- (control, older than this build) an offer that had a link and now reads another is refused as changed
		local withLink = MR:Offer(recOf(n, 9702), false, "priced", 22)
		relink["0:2"] = true
		ok, why = MR:StillOk(withLink)
		check(ok == false and why == "changed", S0 .. "(control) a link that changed under an offer that had one is refused as changed, as before")
		check(it.requested == 0 and (n.errors or 0) == 0, S0 .. "no errors, and ItemTree was never asked to load anything")
		f:Hide()
	end
	_G.ItemTreeAPI = nil
end

-- ======== B14-2: Global Inventory ========
;(function()
	package.loaded.mock = nil
	local M = require("mock")
	M.removeEquipmentSets()
	_G.ItemTreeAPI = nil
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", view = "list" } } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta15"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local Inv, R = n.Inventory, n.Rules
	local realm = n:Realm()
	local chip = n:FilterPredicate(n.CleanFilters({ q = { [1] = true } }))
	local cold = { itemID = 4306, name = "Item 4306", quality = 1, nameUnknown = true, qualityUnknown = true, count = 2, cat = "Other" }
	local known = { itemID = 4306, name = "Silk Cloth", quality = 1, count = 5, cat = "Other" }

	-- (a) the copy that stands for a group
	BagSmithDB.cache.a_cold = { name = "Coldalt", realm = realm, items = { cold } }
	BagSmithDB.cache.b_known = { name = "Knownalt", realm = realm, items = { known } }
	Inv:Touch()
	local g = row(Inv:GlobalRecords(false), 4306)
	check(g and g.count == 7 and #g.globalKids == 2, "(two characters hold Silk Cloth, seven in all; the first one's row is one the game hadn't described)")
	check(g.name == "Silk Cloth" and not g.qualityUnknown and not g.nameUnknown and chip(g) == true, "the group shows the copy that is known, and the Common chip shows it (" .. tostring(g.name) .. ")")
	check(Inv:WaitingOn(4306) == false, "and the list isn't waiting on that item")
	BagSmithDB.cache.a_cold.items, BagSmithDB.cache.b_known.items = { known }, { cold }
	Inv:Touch()
	g = row(Inv:GlobalRecords(false), 4306)
	check(g.count == 7 and g.name == "Silk Cloth" and chip(g) == true, "the other way round: the same answer, whichever copy comes first")
	-- every copy unknown: the group is unknown, and the list waits on the item
	BagSmithDB.cache.a_cold.items = { cold }
	Inv:Touch()
	g = row(Inv:GlobalRecords(false), 4306)
	-- (by design since 1.10.0-beta16, the beta15 audit's B15-2: both copies are saved rows, which building the list again
	-- can't describe, so the list no longer waits on the item; it did)
	check(g.count == 4 and g.qualityUnknown == true and chip(g) == false and Inv:WaitingOn(4306) == false, "no copy known: the group is not known yet and the chip leaves it out (saved rows only: nothing to wait for)")
	-- a whole copy stands for the group: never one copy's name beside another's quality
	BagSmithDB.cache.a_cold.items = { { itemID = 700, name = "Real Name", quality = 1, qualityUnknown = true, count = 1, cat = "Other" } }
	BagSmithDB.cache.b_known.items = { { itemID = 700, name = "Item 700", quality = 3, nameUnknown = true, count = 1, cat = "Other" } }
	Inv:Touch()
	g = row(Inv:GlobalRecords(false), 700)
	check(g.count == 2 and g.name == "Item 700" and g.quality == 3 and g.nameUnknown == true and not g.qualityUnknown, "one copy with only its name, one with only its quality: the better described one stands, whole (" .. tostring(g.name) .. ", quality " .. tostring(g.quality) .. ")")
	check(R.QualityKnown(g) and not R.NameKnown(g) and Inv:WaitingOn(700) == false, "its quality counts, its name doesn't (saved rows only: by design since beta16 the list doesn't wait on them)")
	-- a first copy that is fully known is never replaced
	BagSmithDB.cache.a_cold.items = { { itemID = 701, name = "First Known", quality = 1, count = 1, cat = "Other" } }
	BagSmithDB.cache.b_known.items = { { itemID = 701, name = "Second Known", quality = 1, count = 1, cat = "Other" } }
	Inv:Touch()
	g = row(Inv:GlobalRecords(false), 701)
	check(g.name == "First Known", "(two known copies: the first stands, as it always did)")
	BagSmithDB.cache.a_cold, BagSmithDB.cache.b_known = nil, nil

	-- (b) a worn item the game hasn't described, held nowhere else
	local wornid, loaded = 9876, false
	local oldGet = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(key)
		if key == wornid then
			if loaded then return "Harness Coat", nil, 2, 19, 5, "Armor", "Cloth", 1, "INVTYPE_CHEST", 1, 20, 4, 1 end
			return nil
		end
		return oldGet(key)
	end
	local oldID, oldLink = GetInventoryItemID, GetInventoryItemLink
	_G.GetInventoryItemID = function(u, slot) if slot == 5 then return wornid end if oldID then return oldID(u, slot) end end
	_G.GetInventoryItemLink = function(u, slot) if slot == 5 then return nil end if oldLink then return oldLink(u, slot) end end
	M.fire("PLAYER_EQUIPMENT_CHANGED", 5); pump(M)
	local one = row(Inv:GlobalRecords(false), wornid)
	check(one and one.qualityUnknown == true and one.nameUnknown == true and not n.pendingInfo, "(a worn piece the game hasn't described: marked, and no bag slot is waiting for a rescan)")
	check(Inv:WaitingOn(wornid) == true, "the Global list notes that it is waiting on that item")
	-- data for some other item: nothing is rebuilt
	local builds = Inv.builds
	M.fire("GET_ITEM_INFO_RECEIVED", 2589, true); pump(M)
	Inv:GlobalRecords(false)
	check(Inv.builds == builds, "item data for another item rebuilds nothing")
	-- its data arrives
	local redraws, realRefresh = 0, n.RefreshViews
	n.RefreshViews = function(...) redraws = redraws + 1; return realRefresh(...) end
	loaded = true
	M.fire("GET_ITEM_INFO_RECEIVED", wornid, true); pump(M)
	local two = row(Inv:GlobalRecords(false), wornid)
	check(two ~= one and two.name == "Harness Coat" and two.quality == 2 and not two.qualityUnknown and not two.nameUnknown, "its data arrives: the list is built again and shows Harness Coat, uncommon (" .. tostring(two.name) .. ")")
	check(Inv.builds == builds + 1 and Inv:WaitingOn(wornid) == false, "built once more, and no longer waiting on it")
	check(redraws == 0, "(Global Inventory isn't on screen: nothing is redrawn)")
	-- with Global Inventory on screen, the arrival redraws it
	loaded = false
	Inv:Touch()
	check(row(Inv:GlobalRecords(false), wornid).qualityUnknown == true, "(cold again)")
	n.ui.global = true
	loaded = true
	M.fire("GET_ITEM_INFO_RECEIVED", wornid, true); pump(M)
	check(redraws == 1, "with Global Inventory on screen, the arrival draws it again, once (" .. redraws .. ")")
	n.ui.global = nil
	n.RefreshViews = realRefresh
	C_Item.GetItemInfo = oldGet
	_G.GetInventoryItemID, _G.GetInventoryItemLink = oldID, oldLink
	check((n.errors or 0) == 0, "no errors")
end)()

-- ======== B14-3: an imported Binds when used ========
;(function()
	package.loaded.mock = nil
	local M = require("mock")
	M.removeEquipmentSets()
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 13 })
	_G.ItemTreeAPI = nil
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", view = "list" } } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta15"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); pump(M)
	local R, P, main = n.Rules, n.Popups, n.Window.main
	local used = { bindType = 3, itemID = 21, name = "Bind on Use", quality = 1 }
	local equipped = { bindType = 2, itemID = 22, name = "Bind on Equip", quality = 1 }
	local plainItem = { bindType = 0, itemID = 23, name = "No Binding", quality = 1 }

	local bind = n.CleanFilters({ bd = { BoU = true } })
	check(n:FilterPredicate(bind)(used) == true and n:FilterPredicate(bind)(equipped) == false, "(an imported filter, Binds when used: the item that binds when used shows, the one that binds when equipped doesn't)")
	local folded = n.FoldFilters(bind)
	check(folded.rules and #folded.rules.rows == 1 and folded.rules.rows[1].k == "bind" and folded.rules.rows[1].v[1] == "bou" and #folded.rules.rows[1].v == 1 and not next(folded.bd),
		"the Filters window's fold makes it the Binding rule's own choice, Binds when used")
	check(R:RowText(folded.rules.rows[1]) == "Binding is Binds when used", "in words: " .. R:RowText(folded.rules.rows[1]))
	check(n:FilterPredicate(folded)(used) == true and n:FilterPredicate(folded)(equipped) == false and n:FilterPredicate(folded)(plainItem) == false, "it filters the same after the fold: nothing was widened")
	check(#n.UnfoldedWords(folded) == 0, "(nothing is left to name)")
	-- and back, for a save an older version reads
	local back = n.UnfoldFilters(folded)
	check(back.rules == nil and back.bd.BoU == true and n:FilterPredicate(back)(used) == true and n:FilterPredicate(back)(equipped) == false, "saved the way an older version reads it: the same field it came from")
	-- beside the three the old window offered
	local mixed = n.FoldFilters(n.CleanFilters({ bd = { BoE = true, BoU = true, None = true } }))
	check(mixed.rules and table.concat(mixed.rules.rows[1].v, ",") == "boe,bou,none" and n:FilterPredicate(mixed)(used) and n:FilterPredicate(mixed)(equipped) and n:FilterPredicate(mixed)(plainItem),
		"with the others: one Binding rule with all three (" .. table.concat(mixed.rules and mixed.rules.rows[1].v or {}, ",") .. ")")
	-- the window shows it
	main.st.filters = n.CleanFilters({ bd = { BoU = true } })
	P:OpenFilters(main, "browse"); pump(M)
	local f = P.filter
	check(#f.list.draft.rows == 1 and f.list.draft.rows[1].k == "bind" and f.list.draft.rows[1].v[1] == "bou" and not f.older:IsShown(), "the Filters window shows it as a Binding rule, with no line about older conditions")
	-- a binding the rule has no word for stays in its field, and is named
	local odd = n.CleanFilters({ bd = { BoE = true, Heirloom = true } })
	local heir = { bindType = 2, itemID = 24, name = "Equip", quality = 1 }
	local before = n:FilterPredicate(odd)(heir)
	local kept = n.FoldFilters(odd)
	check(kept == odd and kept.rules == nil and kept.bd.Heirloom and kept.bd.BoE, "a binding the rule can't say (from a hand-edited import) isn't folded: the field stays whole")
	check(n:FilterPredicate(kept)(heir) == before and table.concat(n.UnfoldedWords(kept), ",") == "Binding", "it filters the same, and the window's line names it: Binding")
	main.st.filters = odd
	P:SyncFilters(); pump(M)
	check(f.older:IsShown() and f.older.text:find("also narrows by Binding, kept", 1, true) ~= nil, "the Filters window says so")
	main.st.filters = n.EmptyFilters(); P:SyncFilters(); f:Hide()
	check((n.errors or 0) == 0, "no errors")
end)()

-- ======== Shweep: a selected Quality chip in Classic, and NEW beside New Section... ========
for _, skin in ipairs({ "modern", "classic" }) do
	local S0 = skin .. ": "
	package.loaded.mock = nil
	local M = require("mock")
	M.removeEquipmentSets()
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 13 })
	M.put(0, 2, { id = 9001, name = "Silk Robe", q = 2, count = 1, class = 4, subclass = 1, type = "Armor", sub = "Cloth", equip = "INVTYPE_ROBE", bind = 2, price = 300, ilvl = 20 })
	_G.ITEM_QUALITY_COLORS = QUALITY_COLORS
	_G.ItemTreeAPI = nil
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, view = "list", grp = "type" } }, whatsNewSeen = "1.9.8" }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta15"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); pump(M)
	if n.WhatsNew.Card and n.WhatsNew.Card() then n.WhatsNew:Close() end
	local P, main = n.Popups, n.Window.main
	local classic = skin == "classic"
	local function isGold(c) local t = c.label.textColor; return t and math.abs(t[1] - 1) < 0.01 and math.abs(t[2] - 0.82) < 0.01 and math.abs(t[3]) < 0.01 end

	-- the Quality row at the top of the Filters window
	P:OpenFilters(main, "browse"); pump(M)
	local f = P.filter
	local function chipOf(key) for _, c in ipairs(f.checks) do if c.groupKey == "q" and c.key == key then return c end end end
	local common, poor, rare = chipOf(1), chipOf(0), chipOf(3)
	check(common and poor and rare and common.label.text == "Common" and not common.active, S0 .. "(the Quality chips, none picked)")
	click(common); click(poor); pump(M)
	check(common.active and poor.active and main.st.filters.q[1] and main.st.filters.q[0], S0 .. "(Common and Poor picked)")
	if classic then
		check(common.label.text == "Common" and poor.label.text == "Poor", S0 .. "a picked Quality chip keeps plain text: no quality color written into it (" .. tostring(common.label.text) .. ", " .. tostring(poor.label.text) .. ")")
		if common.classicOn and common.classic then
			check(isGold(common) and isGold(poor) and not isGold(rare), S0 .. "so Classic's gold shows the two picked chips, and the unpicked ones stay cream")
		else
			check(not common.label.text:find("|c", 1, true), S0 .. "(the mock gives this chip no Blizzard art; its text carries no color code)")
		end
	else
		check(common.label.text == "|cffffffffCommon|r" and poor.label.text:find("^|cff9e9e9ePoor|r$") ~= nil and rare.label.text == "Rare", S0 .. "a picked Quality chip is written in its quality's color, as before (" .. tostring(common.label.text) .. ")")
	end
	click(poor); pump(M)
	check(poor.label.text == "Poor" and not poor.active, S0 .. "unpicked again: plain")
	-- a Quality rule's choices, in the Filters window
	local L = f.list
	L:AddRow("quality"); pump(M)
	local r1 = L.rows[1]
	click(r1.chips[2]); click(r1.chips[3]); pump(M)
	check(r1.chips[2].active and r1.chips[3].active, S0 .. "(a Quality rule, Common and Uncommon picked)")
	if classic then
		check(r1.chips[2].label.text == "Common" and r1.chips[3].label.text == "Uncommon" and r1.chips[1].label.text == "Poor", S0 .. "the rule's picked choices keep plain text too")
	else
		check(r1.chips[2].label.text == "|cffffffffCommon|r" and r1.chips[3].label.text:find("^|cff1fff00Uncommon|r$") ~= nil and r1.chips[1].label.text == "Poor", S0 .. "the rule's picked choices are in their quality's color (" .. tostring(r1.chips[3].label.text) .. ")")
	end
	click(f.clearBtn); pump(M)
	f:Hide()
	-- and in the section editor
	local ef = n.Sections:EditSection(); pump(M)
	local E = n.SectionEditor
	E:AddRow("quality"); pump(M)
	local er = E.rows[1]
	click(er.chips[4]); pump(M)
	check(er.chips[4].active and ((classic and er.chips[4].label.text == "Rare") or (not classic and er.chips[4].label.text:find("^|cff0070deRare|r$") ~= nil)), S0 .. "the section editor's Quality rule: " .. (classic and "plain text for Classic's gold" or "its color in Modern") .. " (" .. tostring(er.chips[4].label.text) .. ")")
	click(ef.cancel); pump(M)

	-- NEW beside New Section...
	local SP = n.SettingsPanel
	check(SP.NEW.buttons and SP.NEW.buttons["New Section..."] == "custom" and SP:IsNew("buttons", "New Section...") == true, S0 .. "coming from 1.9.8: New Section... is listed as NEW for 1.10")
	SP:Show(); SP:ShowPage("custom"); M.runTimers()
	local function button(label) for _, b in ipairs(SP.pools.btn or {}) do if b:IsShown() and b.label.text == label then return b end end end
	local newSection = button("New Section...")
	check(newSection and newSection.newTag and newSection.newTag:IsShown(), S0 .. "on Settings > Custom Sections, the New Section... button wears the NEW tag")
	local point, anchor, _, x = newSection.newTag:GetPoint(1)
	if newSection.newTag.scaled then x = x * 0.65 end
	check(point == "LEFT" and anchor == newSection and math.abs(x - (newSection:GetWidth() + 6)) < 0.5, S0 .. "just to the right of the button (" .. tostring(x) .. " from its left edge; the button is " .. tostring(newSection:GetWidth()) .. " wide)")
	local others = {}
	for _, b in ipairs(SP.pools.btn or {}) do if b:IsShown() and b ~= newSection and b.newTag and b.newTag:IsShown() then others[#others + 1] = b.label.text end end
	check(#others == 0 and button("Cloth") ~= nil, S0 .. "and no other button does: not the four examples (" .. table.concat(others, ", ") .. ")")
	-- another page reuses the buttons: no tag is left behind
	SP:ShowPage("sections"); M.runTimers()
	local left = {}
	for _, b in ipairs(SP.pools.btn or {}) do if b:IsShown() and b.newTag and b.newTag:IsShown() then left[#left + 1] = b.label.text end end
	check(#left == 0, S0 .. "another page's buttons wear no tag (" .. table.concat(left, ", ") .. ")")
	-- seen once: gone the next time Settings opens, like every other tag
	SP:Hide(); SP.page = "about"; SP:Show(); SP:ShowPage("custom"); M.runTimers()
	newSection = button("New Section...")
	check(newSection and not (newSection.newTag and newSection.newTag:IsShown()) and SP:IsNew("buttons", "New Section...") == false, S0 .. "the page was opened once: the tag is gone the next time")
	SP:Hide()
	check((n.errors or 0) == 0, S0 .. "no errors")
end

;(function()
	-- a first install: nothing is new, the button included
	package.loaded.mock = nil
	local M = require("mock")
	M.removeEquipmentSets()
	_G.ItemTreeAPI = nil
	_G.BagSmithCharDB, _G.BagSmithDB = nil, nil
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta15"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local SP = n.SettingsPanel
	SP:Show(); SP:ShowPage("custom"); M.runTimers()
	local tagged = false
	for _, b in ipairs(SP.pools.btn or {}) do if b:IsShown() and b.newTag and b.newTag:IsShown() then tagged = true end end
	check(not tagged and SP:IsNew("buttons", "New Section...") == false, "a first install: no NEW tag on the button")
	SP:Hide()

	-- the words
	local f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	local section = ("\n" .. log):match("\n(## 1%.10%.0\n.-)\n## 1%.9%.8\n") or ""
	local flat = section:gsub("%s+", " ")
	check(flat:find("that item is held back under Waiting for ItemTree. The Helper checks again by itself, and offers the item only if ItemTree doesn't say to keep it. Clear Soul Shards is your own action with its own count to keep, and doesn't ask ItemTree.", 1, true),
		"the changelog: the Helper checks again, and offers the item only if ItemTree doesn't say to keep it")
	check(not flat:find("shows by itself once ItemTree answers", 1, true), "it no longer says a waiting item shows once ItemTree answers")
	check(not section:find("\226\128\148") and not section:find("\226\128\147"), "with no dashes")
	f = io.open("BagSmith/BagSmith.toc"); local toc = f:read("*a"); f:close()
	check(toc:find("## Version: 1.10.0", 1, true), "the TOC says 1.10.0 (the exact version is pinned in tests/run.lua)")
end)()
