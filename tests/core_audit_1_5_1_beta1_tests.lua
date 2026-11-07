;(function()
	-- 1.5.1-beta2: the 1.5.1-beta1 audit's Loot Helper findings, asserting the corrected behavior (they fail on
	-- beta1). L1: a second stack of the same item counted as arrived when the first one landed. L2: a loot slot whose
	-- link was missing was requested anyway and slipped past the one-at-a-time guard. Also: an unanswered request
	-- was asked again every few seconds without end; a confirmation opened while valuable loot waited stayed valid
	-- after only no-price loot remained; the final check didn't repeat the no-vendor-price protection; partial and
	-- early arrivals. (The auditor's own harness and diagnostics are in docs/plugins/audit-1.5.1-beta1/.)
	local ITEMS = {
		-- id = { name, vendor price, max stack, bag family, crafting reagent }
		[9701] = { "Broken Fang", 3, 1, 0 }, [9702] = { "Linen Belt", 22, 1, 0 }, [9712] = { "Fine Gloves", 300, 1, 0 },
		[9713] = { "Worn Boots", 40, 1, 0 }, [9861] = { "Rough Stone", 1, 20, 0 }, [9862] = { "Copper Ore", 5, 20, 0 },
		[9863] = { "Silver Ring", 100, 1, 0 }, [9864] = { "Odd Egg", 0, 1, 0 }, [9865] = { "Small Ring", 10, 1, 0 },
	}
	local loot, requested, linkless = {}, {}, {}
	local clock, due = 8000, {}
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
	local function boot(stock, size, profile)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return "Warrior", "WARRIOR" end
		for b = 0, 5 do M.sizes[b] = 0 end
		M.sizes[0] = size
		M.maxStack = {}
		for id, it in pairs(ITEMS) do M.maxStack[id] = it[3] end
		stock(M)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = "modern", makeRoom = true, makeRoomValue = "vendor" }
		for k, v in pairs(profile or {}) do p[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id)
			local num = tonumber(tostring(id):match("item:(%d+)")) or id
			local it = ITEMS[num]
			if it then return it[1], nil, 1, nil, nil, nil, nil, it[3], nil, nil, it[2], nil, nil, nil, nil, nil, it[5] or false end
			return realInfo(id)
		end
		C_Item.GetItemFamily = function() return 0 end
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id; M.cursorFrom = { bag, slot } end
		_G.ClearCursor = function() M.cursorItem = nil end
		M.deleted = 0
		_G.DeleteCursorItem = function() if M.cursorFrom then M.bags[M.cursorFrom[1]][M.cursorFrom[2]] = nil end; M.cursorItem = nil; M.deleted = M.deleted + 1 end
		_G.GetNumLootItems = function() local c = 0; for i = 1, 6 do if loot[i] then c = i end end; return c end
		_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
		_G.GetLootSlotLink = function(i) local l = loot[i]; if l and not linkless[i] then return "|Hitem:" .. l.id .. ":0|h[" .. ITEMS[l.id][1] .. "]|h" end end
		_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", ITEMS[l.id][1], l.qty or 1, nil, 1 end end
		requested, linkless = {}, {}
		_G.LootSlot = function(i) requested[#requested + 1] = i end
		_G.ERR_INV_FULL = "Inventory is full."
		clock, due = 8000, {}
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
	local function firstFree(M) for s = 1, M.sizes[0] do if not M.bags[0][s] then return s end end end
	local function land(M, n, id, count) M.put(0, firstFree(M), item(id, { count = count })); n:Scan(); advance(0) end
	local function clear(M, slot) loot[slot] = nil; M.fire("LOOT_SLOT_CLEARED", slot); advance(0) end

	-- ---- L1: two stacks of the same item, looted by hand one after the other
	local n, M = boot(function(MM) MM.put(0, 1, item(9702)) end, 3)
	openLoot(M, { { id = 9861, qty = 20 }, { id = 9861, qty = 20 }, { id = 9862 } })
	local f = n.MakeRoom.frame
	check(f and f:IsShown(), "L1: two stacks of Rough Stone fit, Copper Ore waits")
	advance(0.1); clear(M, 1)                    -- the first stack, looted by hand...
	advance(0.2); land(M, n, 9861, 20)           -- ...lands
	advance(0.2); clear(M, 2)                    -- the second clears before it lands
	check(asked() == "", "L1: the first stack's arrival doesn't count for the second: Copper Ore isn't asked for (asked: " .. asked() .. ")")
	advance(0.3); land(M, n, 9861, 20)
	check(asked() == "", "L1: once the second lands the bags are full, and Copper Ore still waits (asked: " .. asked() .. ")")
	M.bags[0][1] = nil; n:Scan(); advance(0)
	check(asked() == "3", "L1: freeing a slot then takes Copper Ore (asked: " .. asked() .. ")")

	-- ---- L1, both stacks cleared before either lands
	n, M = boot(function(MM) MM.put(0, 1, item(9702)) end, 3)
	openLoot(M, { { id = 9861, qty = 20 }, { id = 9861, qty = 20 }, { id = 9862 } })
	advance(0.1); clear(M, 1); clear(M, 2)
	advance(0.2); land(M, n, 9861, 20)
	check(asked() == "", "L1 (both cleared): one stack's arrival leaves the other still owed (asked: " .. asked() .. ")")
	advance(0.2); land(M, n, 9861, 20); M.bags[0][1] = nil; n:Scan(); advance(0)
	check(asked() == "3", "L1 (both cleared): after both land and a slot frees, Copper Ore is taken (asked: " .. asked() .. ")")

	-- ---- a partial arrival: 20 of 40 isn't the whole stack
	n, M = boot(function(MM) for s = 1, 4 do MM.put(0, s, item(9701, { q = 0 })) end end, 4)
	openLoot(M, { { id = 9861, qty = 40 }, { id = 9862 } })
	M.bags[0][1] = nil; M.bags[0][2] = nil; M.bags[0][3] = nil; n:Scan(); advance(0)
	check(asked() == "1", "partial: room for both, the 40 stones are asked for first (asked: " .. asked() .. ")")
	advance(0.3); clear(M, 1); advance(0.2); land(M, n, 9861, 20)
	check(asked() == "1", "partial: 20 of 40 arrived, so Copper Ore waits (asked: " .. asked() .. ")")
	advance(0.2); land(M, n, 9861, 20)
	check(asked() == "1,2", "partial: all 40 arrived, Copper Ore is taken (asked: " .. asked() .. ")")

	-- ---- an item that lands before its slot clears isn't asked for again
	n, M = boot(function(MM) for s = 1, 3 do MM.put(0, s, item(9701, { q = 0 })) end end, 3)
	openLoot(M, { { id = 9861, qty = 5 }, { id = 9862 } })
	M.bags[0][1] = nil; M.bags[0][2] = nil; n:Scan(); advance(0)
	advance(0.3); land(M, n, 9861, 5)            -- lands; its loot slot hasn't cleared yet
	check(asked() == "1,2", "landed before its slot cleared: it counts as arrived, and Copper Ore is taken next (asked: " .. asked() .. ")")
	advance(2); n:Scan(); advance(0)
	check(asked() == "1,2", "and slot 1 isn't asked for again while its slot is still showing (asked: " .. asked() .. ")")
	clear(M, 1); advance(4)
	check(asked() == "1,2", "its late clear changes nothing (asked: " .. asked() .. ")")

	-- ---- L2: a queued slot whose link goes missing is never requested, and only one request goes out
	n, M = boot(function(MM) for s = 1, 3 do MM.put(0, s, item(9701, { q = 0 })) end end, 3)
	openLoot(M, { { id = 9861 }, { id = 9862 } })
	linkless[1] = true
	M.bags[0][1] = nil; n:Scan(); advance(0)
	check(asked() == "2", "L2: with one slot free and slot 1's link missing, only one request goes out, never for the unidentified slot (asked: " .. asked() .. ")")

	-- ---- an unanswered request isn't asked again until something changes
	n, M = boot(function(MM) for s = 1, 3 do MM.put(0, s, item(9701, { q = 0 })) end end, 3)
	openLoot(M, { { id = 9861 }, { id = 9862 } })
	M.bags[0][1] = nil; n:Scan(); advance(0)
	M.fire("LOOT_BIND_CONFIRM", 1)               -- e.g. a bind box the player leaves open
	advance(12.1)
	check(asked() == "1", "no clear, no error, no bag change for 12 seconds: asked once, not again and again (asked: " .. asked() .. ")")
	M.bags[0][2] = nil; n:Scan(); advance(0)
	check(asked() == "1,1", "once the bags change, it's asked for again (asked: " .. asked() .. ")")

	-- ---- a confirmation opened under one basis doesn't survive a change to another
	local function confirmSetup()
		local nn, MM = boot(function(B) B.put(0, 1, item(9865)); B.put(0, 2, item(9712)) end, 2, { makeRoomAsk = true })
		openLoot(MM, { { id = 9863 }, { id = 9864 } })   -- a 1s ring and an egg with no price
		local ff = nn.MakeRoom.frame
		check(ff:IsShown() and ff.act:IsShown() and ff.act.label.text == "Destroy Small Ring", "confirm: the 10c ring is offered for the 1s ring (" .. tostring(ff.act.label.text) .. ")")
		ff.act:GetScript("OnClick")(ff.act)
		return nn, MM, ff, nn.Popups.confirm
	end
	local c
	n, M, f, c = confirmSetup()
	check(c and c:IsShown(), "confirm: Ask Before Destroying on, the question opens")
	f.waitRows[1].btns[1]:GetScript("OnClick")(f.waitRows[1].btns[1])   -- Skip the valuable ring
	check(not c:IsShown() and M.bags[0][1] ~= nil, "confirm: skipping the valuable loot leaves only no-price loot, so the old question closes")
	n, M, f, c = confirmSetup()
	loot[1] = nil                                 -- the valuable ring goes (someone else took it) with no repaint yet
	c.yes:GetScript("OnClick")(c.yes)
	check(M.deleted == 0 and M.bags[0][1] ~= nil, "confirm: Yes after the basis changed underneath destroys nothing")
	n, M, f, c = confirmSetup()
	c.yes:GetScript("OnClick")(c.yes)
	check(M.deleted == 1 and M.bags[0][1] == nil, "confirm (control): Yes with nothing changed destroys the ring")

	-- ---- the final check repeats the no-vendor-price protection
	n, M = boot(function(B) B.put(0, 1, item(9865)); B.put(0, 2, item(9712)) end, 2)
	openLoot(M, { { id = 9863 } })
	f = n.MakeRoom.frame
	ITEMS[9865][2] = 0                           -- its vendor price reads as none by the time you click
	f.act:GetScript("OnClick")(f.act)
	c = n.Popups.confirm
	if c and c:IsShown() then c.yes:GetScript("OnClick")(c.yes) end   -- whichever way it asks, the final check decides
	check(M.deleted == 0 and M.bags[0][1] ~= nil, "an item that has no vendor price at the moment of destroying is kept")
	ITEMS[9865][2] = 10
end)()
