;(function()
	-- 1.5.1: the Loot Helper waits for what it looted to reach the bags before taking the next item (a player's
	-- log: it asked for the next loot slot before the first item had landed, and the game said the bags were full);
	-- loot with no price still gets offers, the cheapest first and asking first (it had offered nothing at all);
	-- the card names the bags the loot can't go in; the panel repaints when item info arrives.
	local ITEMS = {
		-- id = { name, vendor price, max stack, bag family, crafting reagent }
		[9701] = { "Broken Fang", 3, 1, 0 }, [9702] = { "Linen Belt", 22, 1, 0 }, [9712] = { "Fine Gloves", 300, 1, 0 },
		[774] = { "Malachite", 25, 20, 0 }, [2770] = { "Copper Ore", 5, 20, 0 },
		[9851] = { "Taillasher Egg", 0, 1, 0 }, [9852] = { "Roasted Haunch", 25, 20, 0 }, [9853] = { "Lucky Charm", 40, 1, 0 },
		[9854] = { "Small Ring", 10, 1, 0 }, [9855] = { "Spotted Egg", 15, 1, 0 }, [9856] = { "Glittering Egg", 500, 1, 0 },
		[2934] = { "Ruined Leather Scraps", 7, 20, 0, true }, [2512] = { "Rough Arrow", 1, 200, 1 },
	}
	local uncached = {}
	local loot, requested = {}, {}
	local clock, due = 5000, {}
	-- Timers that respect their delay: advance(dt) runs whatever falls due, in order, each at its own due time
	-- (1.5.1-beta2, from the beta1 audit: jumping the clock to the end first hid timers that re-arm themselves).
	local function advance(dt)
		local target = clock + (dt or 0)
		while true do
			table.sort(due, function(a, b) return a.at < b.at end)
			local t = due[1]
			if not t or t.at > target then break end
			table.remove(due, 1)
			if t.at > clock then clock = t.at end
			t.fn()
		end
		clock = target
	end
	local function boot(stock, opts)
		opts = opts or {}
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return "Warrior", "WARRIOR" end
		for b = 0, 5 do M.sizes[b] = (opts.sizes and opts.sizes[b]) or 0 end
		for b, name in pairs(opts.names or {}) do M.bagNames[b] = name end
		stock(M)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", makeRoom = true, makeRoomValue = "vendor" } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id)
			local num = tonumber(tostring(id):match("item:(%d+)")) or id
			if uncached[num] then return nil end
			local it = ITEMS[num]
			if it then return it[1], nil, 1, nil, nil, nil, nil, it[3], nil, nil, it[2], nil, nil, nil, nil, nil, it[5] or false end
			return realInfo(id)
		end
		C_Item.GetItemFamily = function(id) local num = tonumber(tostring(id):match("item:(%d+)")) or id; return ITEMS[num] and ITEMS[num][4] or 0 end
		local realFree = C_Container.GetContainerNumFreeSlots
		C_Container.GetContainerNumFreeSlots = function(bag) local free = realFree(bag); return free, (opts.families and opts.families[bag]) or 0 end
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id; M.cursorFrom = { bag, slot } end
		_G.ClearCursor = function() M.cursorItem = nil end
		_G.DeleteCursorItem = function() if M.cursorFrom then M.bags[M.cursorFrom[1]][M.cursorFrom[2]] = nil end; M.cursorItem = nil end
		_G.GetNumLootItems = function() local c = 0; for i = 1, 6 do if loot[i] then c = i end end; return c end
		_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
		_G.GetLootSlotLink = function(i) local l = loot[i]; return l and ("|Hitem:" .. l.id .. ":0|h[" .. ITEMS[l.id][1] .. "]|h") end
		_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", ITEMS[l.id][1], l.qty or 1, nil, 1 end end
		requested = {}
		_G.LootSlot = function(i) requested[#requested + 1] = i end
		_G.ERR_INV_FULL = "Inventory is full."
		clock, due = 5000, {}
		_G.GetTime = function() return clock end
		C_Timer.After = function(d, fn) due[#due + 1] = { at = clock + (d or 0), fn = fn } end
		return n, M
	end
	local function item(id, extra)
		local it = ITEMS[id]
		local t = { id = id, name = it[1], q = 1, class = 15, subclass = 0, price = it[2] }
		for k, v in pairs(extra or {}) do t[k] = v end
		return t
	end
	local function asked() return table.concat(requested, ",") end
	local function openLoot(M, list) loot = list; M.fire("LOOT_OPENED"); advance(0.2) end
	local function waitingNames(f) local t = {}; for _, r in ipairs(f.waitRows) do if r:IsShown() then t[#t + 1] = r.name.text end end return table.concat(t, ",") end
	local function destroyNames(f) local t = {}; for _, r in ipairs(f.destroyRows) do if r:IsShown() then t[#t + 1] = r.name.text end end return table.concat(t, ",") end
	local function threeFull(M)
		M.put(0, 1, item(9701, { q = 0 })); M.put(0, 2, item(9702)); M.put(0, 3, item(9712))
	end

	-- ---- one item at a time: the next loot slot only after the last item has landed
	-- (1) the 0.6 s settle timer running out before the item lands (the player's log)
	local n, M = boot(threeFull, { sizes = { [0] = 3 } })
	openLoot(M, { { id = 774 }, { id = 2770 } })
	local f = n.MakeRoom.frame
	check(f and f:IsShown() and waitingNames(f) == "Malachite,Copper Ore", "full bags: both ores wait (" .. (f and waitingNames(f) or "no panel") .. ")")
	M.bags[0][1] = nil; n:Scan(); advance(0)                       -- the player frees one slot
	check(asked() == "1", "with one slot free it loots slot 1 only (asked: " .. asked() .. ")")
	advance(0.4); loot[1] = nil; M.fire("LOOT_SLOT_CLEARED", 1)    -- the server clears the slot...
	advance(0.7)                                                     -- ...and the item is slow to arrive
	check(asked() == "1", "it doesn't ask for slot 2 while Malachite is still on its way (asked: " .. asked() .. ")")
	M.put(0, 1, item(774, { count = 1 })); n:Scan(); advance(0)    -- it lands in the freed slot
	check(asked() == "1" and f:IsShown() and waitingNames(f) == "Copper Ore", "once it lands, Copper Ore still won't fit and waits (asked: " .. asked() .. ", waiting: " .. waitingNames(f) .. ")")
	advance(10)
	check(asked() == "1", "nothing more is asked for while the bags stay full (asked: " .. asked() .. ")")

	-- (2) a bag scan for another reason before the item lands
	n, M = boot(threeFull, { sizes = { [0] = 3 } })
	openLoot(M, { { id = 774 }, { id = 2770 } })
	f = n.MakeRoom.frame
	M.bags[0][1] = nil; n:Scan(); advance(0)
	advance(0.3); loot[1] = nil; M.fire("LOOT_SLOT_CLEARED", 1)
	advance(0.1); n:Scan(); advance(0)                             -- an unrelated rescan, nothing landed
	check(asked() == "1", "an unrelated bag scan doesn't count as the item landing (asked: " .. asked() .. ")")

	-- (3) room for both: the second is taken as soon as the first lands, not before
	n, M = boot(threeFull, { sizes = { [0] = 3 } })
	openLoot(M, { { id = 774 }, { id = 2770 } })
	f = n.MakeRoom.frame
	M.bags[0][1] = nil; M.bags[0][2] = nil; n:Scan(); advance(0)   -- two slots free at once
	check(asked() == "1", "two slots free: it starts with slot 1 (asked: " .. asked() .. ")")
	advance(0.3); loot[1] = nil; M.fire("LOOT_SLOT_CLEARED", 1); advance(0.7)
	check(asked() == "1", "and waits for it to land (asked: " .. asked() .. ")")
	M.put(0, 1, item(774, { count = 1 })); n:Scan(); advance(0)
	check(asked() == "1,2", "the moment it lands, slot 2 is taken (asked: " .. asked() .. ")")

	-- (4) the game refuses it: not asked again until the bags change
	n, M = boot(threeFull, { sizes = { [0] = 3 } })
	openLoot(M, { { id = 774 }, { id = 2770 } })
	f = n.MakeRoom.frame
	M.bags[0][1] = nil; n:Scan(); advance(0)
	advance(0.3); M.fire("UI_ERROR_MESSAGE", 3, ERR_INV_FULL); advance(0)
	n:Scan(); advance(5); n:Scan(); advance(0)
	check(asked() == "1", "after the game says the bags are full, it doesn't ask for that item again while the bags are unchanged (asked: " .. asked() .. ")")
	M.bags[0][2] = nil; n:Scan(); advance(0)                       -- the player frees another slot
	check(asked() == "1,1", "once the bags change, it tries again (asked: " .. asked() .. ")")

	-- (5) the item never arrives (someone else took it): after a short wait it judges again
	n, M = boot(threeFull, { sizes = { [0] = 3 } })
	openLoot(M, { { id = 774 }, { id = 2770 } })
	f = n.MakeRoom.frame
	M.bags[0][1] = nil; n:Scan(); advance(0)
	advance(0.3); loot[1] = nil; M.fire("LOOT_SLOT_CLEARED", 1); advance(1)
	check(asked() == "1", "still waiting a second after the slot cleared (asked: " .. asked() .. ")")
	advance(3)
	check(asked() == "1,2", "when nothing lands after a few seconds, it judges again and takes Copper Ore into the free slot (asked: " .. asked() .. ")")

	-- (6) looting by hand: the same wait applies
	n, M = boot(function(MM) MM.put(0, 1, item(9702)); MM.put(0, 2, item(9712)) end, { sizes = { [0] = 3 } })
	openLoot(M, { { id = 774 }, { id = 2770 } })
	f = n.MakeRoom.frame
	check(f:IsShown() and waitingNames(f) == "Copper Ore", "one slot free: Malachite fits, Copper Ore waits (" .. waitingNames(f) .. ")")
	advance(1); loot[1] = nil; M.fire("LOOT_SLOT_CLEARED", 1)      -- the player clicks Malachite in the loot window
	advance(0.7); n:Scan(); advance(0)
	check(asked() == "", "after looting by hand, it doesn't ask for Copper Ore before Malachite lands (asked: " .. asked() .. ")")
	M.put(0, 3, item(774, { count = 1 })); n:Scan(); advance(0)
	check(asked() == "" and f:IsShown() and waitingNames(f) == "Copper Ore", "once it lands, Copper Ore waits (asked: " .. asked() .. ")")

	-- (7) the item reaches the bags before its slot clears (it can, with auto-loot): no wait, no slot held for it
	n, M = boot(function(MM) MM.put(0, 1, item(9702)); MM.put(0, 2, item(9712)) end, { sizes = { [0] = 3 } })
	openLoot(M, { { id = 774 }, { id = 2770 } })
	f = n.MakeRoom.frame
	advance(1); M.put(0, 3, item(774, { count = 1 })); n:Scan(); advance(0)   -- Malachite lands first...
	advance(0.1); loot[1] = nil; M.fire("LOOT_SLOT_CLEARED", 1); advance(0)  -- ...then its slot clears
	check(f:IsShown() and waitingNames(f) == "Copper Ore", "Copper Ore still waits (" .. waitingNames(f) .. ")")
	advance(0.2); M.bags[0][1] = nil; n:Scan(); advance(0)                   -- the player frees a slot at once
	check(asked() == "2", "an item already in the bags isn't waited for: freeing a slot right after takes Copper Ore at once (asked: " .. asked() .. ")")

	-- ---- loot with no price: the cheapest items are offered, asking first
	local function pack(MM)
		MM.put(0, 1, item(9852, { count = 8 })); MM.put(0, 2, item(9702)); MM.put(0, 3, item(9853)); MM.put(0, 4, item(9854))
	end
	local function recOf(nn, id) for _, r in ipairs(nn.items) do if r.itemID == id then return r end end end
	n, M = boot(pack, { sizes = { [0] = 4 } })
	n.Marks:ToggleFavorite(recOf(n, 9853))
	openLoot(M, { { id = 9851 } })
	f = n.MakeRoom.frame
	check(f:IsShown() and waitingNames(f) == "Taillasher Egg" and f.waitRows[1].value.text:find("Vendor -", 1, true), "an egg with no vendor price and no AH price waits")
	check(destroyNames(f) == "Small Ring,Linen Belt,Roasted Haunch", "with nothing to compare, the cheapest items are offered, cheapest first (" .. destroyNames(f) .. ")")
	check(not f.card:IsShown(), "so the nothing-frees card doesn't show")
	check(f.note:IsShown() and f.note.text == "Taillasher Egg has no price yet, so these are simply your cheapest items.", "a line says why (" .. tostring(f.note:IsShown() and f.note.text) .. ")")
	check(f.held:IsShown() and f.held.text == "1 protected item isn't offered", "favorites stay protected (" .. tostring(f.held:IsShown() and f.held.text) .. ")")
	check(f.act:IsShown() and f.act.label.text == "Destroy Small Ring", "the cheapest is chosen (" .. tostring(f.act.label.text) .. ")")
	-- (1.5.1-beta2, by design) Ask Before Destroying is off by default: a common item goes at once
	f.act:GetScript("OnClick")(f.act)
	local c = n.Popups.confirm
	check(not (c and c:IsShown()) and M.bags[0][4] == nil, "with the defaults, the common ring is destroyed at once")
	n:Scan(); advance(0)
	check(asked() == "1", "and the egg is looted into the slot (asked: " .. asked() .. ")")

	-- control: priced loot keeps the rule (only what's worth less than the loot)
	n, M = boot(pack, { sizes = { [0] = 4 } })
	openLoot(M, { { id = 9855 } })
	f = n.MakeRoom.frame
	check(destroyNames(f) == "Small Ring" and not f.note:IsShown(), "loot worth 15c: only the 10c ring is offered, and no no-price line (" .. destroyNames(f) .. ")")

	-- ---- the card names the bags the loot can't go in
	n, M = boot(function(MM)
		MM.put(0, 1, item(9854)); MM.put(0, 2, item(9701))   -- worth less than the loot, but favorites
		MM.put(2, 1, item(2512, { count = 200 }))
		MM.put(5, 1, item(2934, { count = 20, craftReagent = true })); MM.put(5, 2, item(2934, { count = 20, craftReagent = true }))
	end, { sizes = { [0] = 2, [2] = 2, [5] = 2 }, families = { [2] = 1 }, names = { [2] = "Light Leather Quiver", [5] = "Linen Reagent Bag" } })
	n.Marks:ToggleFavorite(recOf(n, 9854)); n.Marks:ToggleFavorite(recOf(n, 9701))
	openLoot(M, { { id = 9855 } })
	f = n.MakeRoom.frame
	local cardText = f.card:IsShown() and f.card.text.text or ""
	check(f:IsShown() and f.card:IsShown() and cardText:find("This loot can't go in your Light Leather Quiver or Linen Reagent Bag.", 1, true) ~= nil, "nothing frees a slot: the card says which bags the loot can't go in (" .. cardText .. ")")
	check(cardText:find("^Everything left is protected: 2 favorites%.") and cardText:find("Take what fits from the loot window", 1, true), "the protected count and the advice are still there")
	check(destroyNames(f) == "", "the scraps in the reagent bag aren't offered: their slot can't take the egg")

	-- ---- the panel repaints when the loot's item info arrives
	uncached[9856] = true
	n, M = boot(pack, { sizes = { [0] = 4 } })
	openLoot(M, { { id = 9856 } })
	f = n.MakeRoom.frame
	check(f:IsShown() and f.note:IsShown() and f.waitRows[1].value.text:find("Vendor -", 1, true), "item info not loaded yet: no price, so the no-price line shows")
	uncached[9856] = nil
	M.fire("GET_ITEM_INFO_RECEIVED", 9856, true); advance(0.5)
	check(not f.note:IsShown() and not f.waitRows[1].value.text:find("Vendor -", 1, true), "once the item info arrives, the panel repaints with its price (" .. tostring(f.waitRows[1].value.text) .. ")")
end)()
