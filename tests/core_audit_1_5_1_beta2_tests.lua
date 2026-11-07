;(function()
	-- 1.5.1-beta3: the 1.5.1-beta2 audit's findings, asserting the corrected behavior (they fail on beta2). L3: turning a
	-- destroy protection on while the Loot Helper is open didn't reach the button already showing (or an unconfirmed
	-- Soul Shard batch). L4: a rare item whose bag data had no quality was treated as common. L5: an item looted by hand
	-- could be credited to BagSmith's own pending request for the same item, and that slot was then skipped for the rest
	-- of the session. (The auditor's evidence is in docs/plugins/audit-1.5.1-beta2/.)
	local ITEMS = {
		-- id = { name, vendor price, max stack, quality }
		[9701] = { "Broken Fang", 3, 1, 0 }, [9702] = { "Linen Belt", 22, 1, 1 }, [9881] = { "Blue Blade", 40, 1, 3 },
		[9882] = { "Prize Ring", 500, 1, 2 }, [9883] = { "Rough Stone", 1, 20, 1 }, [9884] = { "Copper Ore", 5, 20, 1 },
		[6265] = { "Soul Shard", 0, 1, 1 },
	}
	local loot, requested, bagQuality = {}, {}, {}
	local clock, due = 9000, {}
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
	local function boot(stock, size, profile, class)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return class or "Warrior", (class or "Warrior"):upper() end
		for b = 0, 5 do M.sizes[b] = 0 end
		M.sizes[0] = size
		M.maxStack = {}
		for id, it in pairs(ITEMS) do M.maxStack[id] = it[3] end
		bagQuality = {}
		stock(M)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = "modern", makeRoom = true, makeRoomValue = "vendor" }
		for k, v in pairs(profile or {}) do p[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
		-- the bag's own quality can be withheld (bagQuality[id] = false) or changed, apart from the item's cached quality
		local realCI = C_Container.GetContainerItemInfo
		C_Container.GetContainerItemInfo = function(bag, slot)
			local info = realCI(bag, slot)
			if info and bagQuality[info.itemID] ~= nil then info.quality = bagQuality[info.itemID] or nil end
			return info
		end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id)
			local num = tonumber(tostring(id):match("item:(%d+)")) or id
			local it = ITEMS[num]
			if it then return it[1], nil, it[4], nil, nil, nil, nil, it[3], nil, nil, it[2] end
			return realInfo(id)
		end
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id; M.cursorFrom = { bag, slot } end
		_G.ClearCursor = function() M.cursorItem = nil end
		M.deleted = 0
		_G.DeleteCursorItem = function() if M.cursorFrom then M.bags[M.cursorFrom[1]][M.cursorFrom[2]] = nil end; M.cursorItem = nil; M.deleted = M.deleted + 1 end
		_G.GetNumLootItems = function() local c = 0; for i = 1, 6 do if loot[i] then c = i end end; return c end
		_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
		_G.GetLootSlotLink = function(i) local l = loot[i]; return l and ("|Hitem:" .. l.id .. ":0|h[" .. ITEMS[l.id][1] .. "]|h") end
		_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", ITEMS[l.id][1], l.qty or 1, nil, 2 end end
		requested = {}
		_G.LootSlot = function(i) requested[#requested + 1] = i end
		clock, due = 9000, {}
		_G.GetTime = function() return clock end
		C_Timer.After = function(d, fn) due[#due + 1] = { at = clock + (d or 0), fn = fn } end
		return n, M
	end
	local function item(id, extra)
		local it = ITEMS[id]
		local t = { id = id, name = it[1], q = it[4], class = 15, subclass = 0, price = it[2] }
		for k, v in pairs(extra or {}) do t[k] = v end
		return t
	end
	local function asking(n) local c = n.Popups.confirm; return c and c:IsShown() or false end
	local function click(n) local f = n.MakeRoom.frame; f.act:GetScript("OnClick")(f.act) end
	local function openPrize(M) loot = { { id = 9882 } }; M.fire("LOOT_OPENED"); advance(0.2) end
	local function tick(n, key, on)   -- the real settings checkbox
		local P = n.SettingsPanel
		P:Show(); P:ShowPage("loothelper")
		for _, w in ipairs(P.pools.check) do
			if w:IsShown() and w.key == key then w.box:SetChecked(on); w.box:GetScript("OnClick")(w.box) end
		end
		advance(0.3)
	end
	local function asked() return table.concat(requested, ",") end

	-- ---- L3: turning protection on reaches the open panel's button
	local n, M = boot(function(B) B.put(0, 1, item(9702)); B.put(0, 2, item(9881)) end, 2)
	openPrize(M)
	check(n.MakeRoom.frame.act.tip == "Destroyed at once", "L3: a common item, asking off: the button acts at once")
	tick(n, "makeRoomAsk", true)
	check(n.db.makeRoomAsk == true and n.MakeRoom.frame.act.tip == "Asks before destroying", "L3: ticking Ask Before Destroying redraws the open panel's button (" .. tostring(n.MakeRoom.frame.act.tip) .. ")")
	click(n)
	check(asking(n) and M.deleted == 0, "L3: the next click asks, and nothing is destroyed")

	-- a button drawn before the setting changed (no redraw): the click still asks
	n, M = boot(function(B) B.put(0, 1, item(9702)); B.put(0, 2, item(9881)) end, 2)
	openPrize(M)
	n.db.makeRoomAsk = true            -- changed without the settings signal, so the button wasn't redrawn
	click(n)
	check(asking(n) and M.deleted == 0, "L3: the click decides from the current settings, whatever the button remembered")
	-- the other way: a button that said it would ask still asks
	n, M = boot(function(B) B.put(0, 1, item(9702)); B.put(0, 2, item(9881)) end, 2, { makeRoomAsk = true })
	openPrize(M)
	n.db.makeRoomAsk = false
	click(n)
	check(asking(n) and M.deleted == 0, "L3: a button that said it asks never acts at once")

	-- rare protection ticked on while a rare item's button shows
	n, M = boot(function(B) B.put(0, 1, item(9881)); B.put(0, 2, item(9881)) end, 2, { makeRoomAskRare = false })
	openPrize(M)
	check(n.MakeRoom.frame.act.tip == "Destroyed at once", "L3: a blue item with rare protection off acts at once")
	tick(n, "makeRoomAskRare", true)
	click(n)
	check(asking(n) and M.deleted == 0, "L3: ticking Always Ask for Rare or Better makes the next click ask")

	-- the destroy step itself refuses an unasked destroy the settings call for
	n, M = boot(function(B) B.put(0, 1, item(9702)); B.put(0, 2, item(9881)) end, 2)
	openPrize(M)
	local r = n.items[1].itemID == 9702 and n.items[1] or n.items[2]
	local offer = n.MakeRoom:Offer(r, false, "priced")
	n.db.makeRoomAsk = true
	n.MakeRoom:Destroy(offer, false)
	check(M.deleted == 0, "L3: Destroy without a Yes refuses when the settings say to ask")
	n.MakeRoom:Destroy(offer, true)
	check(M.deleted == 1, "L3: and Destroy after a Yes goes ahead")

	-- Soul Shards: an unconfirmed batch doesn't carry on once asking is on; a confirmed one does
	local function shards(profile)
		local nn, MM = boot(function(B) for s = 1, 3 do B.put(0, s, item(6265)) end end, 3, profile, "Warlock")
		nn.MakeRoom.shardQty = 3
		nn.MakeRoom:ShowShards()
		return nn, MM, nn.MakeRoom.frame
	end
	local f
	n, M, f = shards()
	f.shard.go:GetScript("OnClick")(f.shard.go)
	check(M.deleted == 1 and not asking(n), "shards: asking off, the first click destroys one")
	n:Scan(); n:Set("makeRoomAsk", true); advance(0.1)
	f.shard.go:GetScript("OnClick")(f.shard.go)
	check(M.deleted == 1 and asking(n), "shards: after Ask Before Destroying is turned on, the next click asks for the rest")
	n, M, f = shards({ makeRoomAsk = true })
	f.shard.go:GetScript("OnClick")(f.shard.go)
	n.Popups.confirm.yes:GetScript("OnClick")(n.Popups.confirm.yes)
	check(M.deleted == 1, "shards: Yes destroys the first of a confirmed batch")
	n:Scan()
	f.shard.go:GetScript("OnClick")(f.shard.go)
	check(M.deleted == 2 and not asking(n), "shards: a batch you said Yes to carries on without asking again")

	-- ---- L4: quality the bag doesn't report
	n, M = boot(function(B) B.put(0, 1, item(9881)); B.put(0, 2, item(9702)); bagQuality[9881] = false end, 2)
	local blade
	for _, x in ipairs(n.items) do if x.itemID == 9881 then blade = x end end
	check(blade and blade.quality == 3 and not blade.qualityUnknown, "L4: no quality from the bag, so the scanner takes the cached quality (rare) (" .. tostring(blade and blade.quality) .. ")")
	ITEMS[9702][2] = 900   -- make the blade the cheapest, so it's the chosen row
	n, M = boot(function(B) B.put(0, 1, item(9881)); B.put(0, 2, item(9702)); bagQuality[9881] = false end, 2)
	openPrize(M)
	ITEMS[9702][2] = 22
	check(n.MakeRoom.frame.act.label.text == "Destroy Blue Blade", "L4: the rare blade is the chosen row (" .. tostring(n.MakeRoom.frame.act.label.text) .. ")")
	click(n)
	check(asking(n) and M.deleted == 0, "L4: with the defaults, it asks before destroying the rare blade")
	-- quality not known at all: counts as possibly rare
	local realInfo
	n, M = boot(function(B) B.put(0, 1, item(9702)); B.put(0, 2, item(9881)); bagQuality[9702] = false end, 2)
	realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(id) local num = tonumber(tostring(id):match("item:(%d+)")) or id; if num == 9702 then return "Linen Belt", nil, nil, nil, nil, nil, nil, 1, nil, nil, 22 end return realInfo(id) end
	n:Scan(); openPrize(M)
	click(n)
	check(asking(n) and M.deleted == 0, "L4: a quality no source reports asks while rare protection is on")
	if n.Popups.confirm then n.Popups.confirm:Hide() end; n.db.makeRoomAskRare = false; n.MakeRoom:Paint()
	click(n)
	check(not asking(n) and M.deleted == 1, "L4: with rare protection off, it goes at once")
	-- quality that turns rare after the panel drew is read at the click
	n, M = boot(function(B) B.put(0, 1, item(9702)); B.put(0, 2, item(9881)) end, 2)
	openPrize(M)
	bagQuality[9702] = 3
	click(n)
	check(asking(n) and M.deleted == 0, "L4: the bag reporting rare by the time of the click makes it ask")

	-- ---- L5: an item looted by hand doesn't retire BagSmith's request for another slot of the same item
	n, M = boot(function(B) for s = 1, 4 do B.put(0, s, item(9701)) end end, 4)
	loot = { { id = 9883, qty = 20 }, { id = 9883, qty = 20 }, { id = 9884 } }
	M.fire("LOOT_OPENED"); advance(0.2)
	M.bags[0][1] = nil; M.bags[0][2] = nil; M.bags[0][3] = nil; n:Scan(); advance(0)
	check(asked() == "1", "L5: room for all three, BagSmith asks for slot 1 (asked: " .. asked() .. ")")
	advance(0.3); M.put(0, 1, item(9883, { count = 20 })); n:Scan(); advance(0)   -- slot 2, looted by hand, lands first
	advance(0.2); loot[2] = nil; M.fire("LOOT_SLOT_CLEARED", 2); advance(0)      -- then its slot clears
	local again = 0
	for i = 2, #requested do if requested[i] == 1 then again = again + 1 end end
	advance(1); n:Scan(); advance(4); n:Scan(); advance(0)
	for i = 2, #requested do if requested[i] == 1 then again = math.max(again, 1) end end
	check(again >= 1, "L5: slot 1, which never arrived, is asked for again (asked: " .. asked() .. ")")
	check(not (n.MakeRoom.done and n.MakeRoom.done[1]), "L5: and it's never marked done")
end)()
