;(function()
	-- 1.3.0-beta2: the 1.3.0-beta1 audit's findings, asserting the corrected behavior (they fail on beta1)
	local loot = {}
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("|Hitem:" .. loot[i].id .. ":0|h[" .. loot[i].name .. "]|h") end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, l.qty or 1, nil, l.q or 1 end end
	_G.LootSlot = function() end
	local deleted = 0
	_G.DeleteCursorItem = function() deleted = deleted + 1 end
	-- item facts: price, max stack, item family (1 = arrows, fits a quiver)
	local ITEMS = {
		[9701] = { "Broken Fang", 3, 1, 0 }, [9702] = { "Linen Belt", 22, 1, 0 }, [9705] = { "Tough Jerky", 4, 20, 0 },
		[9710] = { "Shiny Ring", 500, 1, 0 }, [9711] = { "Small Egg", 1, 20, 0 }, [9712] = { "Fine Gloves", 300, 1, 0 },
		[2512] = { "Rough Arrow", 1, 200, 1 }, [2515] = { "Jagged Arrow", 300, 200, 1 }, [3030] = { "Razor Arrow", 1, 200, 1 }, [9713] = { "Wool Cloth", 1, 20, 0 },
	}
	local function boot(stock, quiver)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return "Hunter", "HUNTER" end
		M.sizes[0] = 4
		for b = 1, 5 do M.sizes[b] = 0 end
		if quiver then M.sizes[1] = 2 end
		stock(M)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", makeRoom = true, makeRoomValue = "vendor" } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id)
			local num = tonumber(tostring(id):match("item:(%d+)")) or id
			local it = ITEMS[num]
			if it then return it[1], nil, 1, nil, nil, nil, nil, it[3], nil, nil, it[2] end
			return realInfo(id)
		end
		C_Item.GetItemFamily = function(id) local num = tonumber(tostring(id):match("item:(%d+)")) or id; return ITEMS[num] and ITEMS[num][4] or 0 end
		-- bag 1 is a quiver: it takes arrows only
		local realFree = C_Container.GetContainerNumFreeSlots
		C_Container.GetContainerNumFreeSlots = function(bag) local free = realFree(bag); return free, (quiver and bag == 1) and 1 or 0 end
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id end
		_G.ClearCursor = function() M.cursorItem = nil end
		return n, M
	end
	local function offered(f, name) for _, r in ipairs(f.destroyRows) do if r:IsShown() and r.name.text == name then return r end end end
	local function recOf(n, id, bag) for _, r in ipairs(n.items) do if r.itemID == id and (not bag or r.bag == bag) then return r end end end

	-- ---- F1: a candidate is judged only against loot that could use its slot
	local function quiverPack(M)
		M.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
		M.put(0, 2, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
		M.put(0, 3, { id = 9705, name = "Tough Jerky", q = 1, count = 20, stack = 20, class = 0, subclass = 5, price = 4 })
		M.put(0, 4, { id = 9713, name = "Wool Cloth", q = 1, count = 20, stack = 20, class = 7, subclass = 5, price = 1 })
		M.put(1, 1, { id = 2512, name = "Rough Arrow", q = 1, count = 200, stack = 200, class = 6, subclass = 2, price = 1 })
		M.put(1, 2, { id = 2512, name = "Rough Arrow", q = 1, count = 200, stack = 200, class = 6, subclass = 2, price = 1 })
	end
	local n, M = boot(quiverPack, true)
	local MR = n.MakeRoom
	-- (a different arrow from the quiver's: the helper never offers a stack of the very item that's waiting)
	loot = { { id = 9710, name = "Shiny Ring", q = 2 }, { id = 3030, name = "Razor Arrow", q = 1 } }
	local waiting = MR:Waiting()
	check(#waiting == 2, "(setup) the ring and the arrow both wait: the backpack and the quiver are full")
	local _, destroy = MR:Suggestions(waiting)
	local arrowOffered, beltOffered = false, false
	for _, d in ipairs(destroy) do if d.rec.itemID == 2512 then arrowOffered = true end if d.rec.itemID == 9702 then beltOffered = true end end
	check(not arrowOffered, "a 200c stack of arrows in the quiver isn't offered for a 1c arrow just because a 5s ring (which can't use the quiver) is waiting")
	check(beltOffered, "the belt in the backpack is still offered: the ring could use its slot")
	-- the last check applies the same rule
	local o = MR:Offer(recOf(n, 2512, 1), false)
	local ok, why = MR:StillOk(o)
	check(ok == false and why == "worth", "and an offer for the arrows made anyway is refused at the moment of destroying (" .. tostring(why) .. ")")
	-- a valuable compatible item still qualifies the arrows
	loot = { { id = 9710, name = "Shiny Ring", q = 2 }, { id = 2515, name = "Jagged Arrow", q = 1 } }
	waiting = MR:Waiting()
	_, destroy = MR:Suggestions(waiting)
	arrowOffered = false; for _, d in ipairs(destroy) do if d.rec.itemID == 2512 then arrowOffered = true end end
	check(arrowOffered, "with a 3s arrow waiting, the 2s arrow stack is offered: valuable compatible loot still qualifies it")
	-- junk keeps its exception
	check(MR.WorthLettingGo ~= nil and MR:WorthLettingGo(0, 999, true, waiting) == true, "junk is worth letting go whenever its slot helps, whatever its price")

	-- ---- F2: an open confirmation never outlives its reason
	local function plainPack(M)
		M.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
		M.put(0, 2, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
		M.put(0, 3, { id = 9705, name = "Tough Jerky", q = 1, count = 20, stack = 20, class = 0, subclass = 5, price = 4 })
		M.put(0, 4, { id = 9713, name = "Wool Cloth", q = 1, count = 20, stack = 20, class = 7, subclass = 5, price = 1 })
	end
	local function openBeltConfirm(n, M)
		M.fire("LOOT_OPENED"); M.runTimers()
		local f = n.MakeRoom.frame
		local belt = offered(f, "Linen Belt")
		belt:GetScript("OnClick")(belt)
		f.act:GetScript("OnClick")(f.act)
		return f, n.Popups.confirm
	end
	-- the valuable loot is looted by someone else while the confirmation is open
	n, M = boot(plainPack)
	loot = { { id = 9710, name = "Shiny Ring", q = 2 }, { id = 9711, name = "Small Egg", q = 1 } }
	deleted = 0
	local f, c = openBeltConfirm(n, M)
	check(c:IsShown() and c.lootHelper and c.lootHelperKey ~= nil, "(setup) the belt's confirmation is open, and knows which offer it's for")
	local beltOffer = n.MakeRoom:Offer(recOf(n, 9702), false)
	table.remove(loot, 1)
	M.fire("LOOT_SLOT_CLEARED", 1); for _ = 1, 6 do M.runTimers() end
	check(not c:IsShown(), "the ring gone (looted elsewhere): the belt's confirmation closes, since the egg alone doesn't justify it")
	check(n.MakeRoom:Destroy(beltOffer) == false and deleted == 0, "and destroying the belt now is refused at the last check: nothing is deleted")
	-- the valuable loot is skipped while the confirmation is open
	n, M = boot(plainPack)
	loot = { { id = 9710, name = "Shiny Ring", q = 2 }, { id = 9711, name = "Small Egg", q = 1 } }
	deleted = 0
	f, c = openBeltConfirm(n, M)
	beltOffer = n.MakeRoom:Offer(recOf(n, 9702), false)
	local ringRow; for _, r in ipairs(f.waitRows) do if r:IsShown() and r.name.text == "Shiny Ring" then ringRow = r end end
	ringRow.btns[1]:GetScript("OnClick")(ringRow.btns[1]); M.runTimers()
	check(not c:IsShown(), "skipping the ring closes the belt's confirmation")
	check(n.MakeRoom:Destroy(beltOffer) == false and deleted == 0, "and the belt isn't destroyed")
	-- the loot window closes and reopens: the old confirmation is gone (as before)
	n, M = boot(plainPack)
	loot = { { id = 9710, name = "Shiny Ring", q = 2 } }
	f, c = openBeltConfirm(n, M)
	M.fire("LOOT_CLOSED"); M.runTimers(); M.fire("LOOT_OPENED"); M.runTimers()
	check(not c:IsShown(), "a new loot window ends the old confirmation")
	-- enough value remains: the confirmation stays and Yes destroys the belt once
	n, M = boot(plainPack)
	loot = { { id = 9710, name = "Shiny Ring", q = 2 }, { id = 9712, name = "Fine Gloves", q = 2 } }
	deleted = 0
	f, c = openBeltConfirm(n, M)
	table.remove(loot, 1)
	M.fire("LOOT_SLOT_CLEARED", 1); for _ = 1, 6 do M.runTimers() end
	check(c:IsShown(), "with the 3s gloves still waiting, the belt's confirmation stays open")
	c.yes:GetScript("OnClick")(c.yes)
	check(deleted == 1, "and Yes destroys the belt, once")

	-- ---- F3: the header promises no slot count
	n, M = boot(plainPack)
	loot = { { id = 9711, name = "Small Egg", q = 1 }, { id = 9711, name = "Small Egg", q = 1 } }
	M.fire("LOOT_OPENED"); M.runTimers()
	check(n.MakeRoom.frame.sub.text == "2 items won't fit. Make room to finish looting.", "two stackable entries: the header says they won't fit without promising two slots (" .. tostring(n.MakeRoom.frame.sub.text) .. ")")

	-- ---- F4: the Favorites line says exactly what Favorites protect
	local SP = n.SettingsPanel; SP:Show(); SP:ShowPage("loothelper")
	local texts = {}; for _, w in ipairs(SP.pools.text) do if w:IsShown() then texts[#texts + 1] = w.text.text end end
	local all = table.concat(texts, "|")
	check(not all:find("everywhere", 1, true) and all:find("Favorites are never destroyed by the Loot Helper or offered by the Disenchant Helper; junk selling still includes them.", 1, true), "the help no longer claims Favorites protect everywhere, and names junk selling")
	SP:Hide()
end)()
