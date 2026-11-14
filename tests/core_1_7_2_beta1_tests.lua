;(function()
	-- ======== 1.7.2-beta1: Soul Shards merged by Merge Stacks (a player's request via Shweep) ========
	-- The game keeps one Soul Shard to a slot (stack size 1), so Merge Stacks used to show every one. Every shard is
	-- the same, so they now show once with the total. Nothing wider: other one-to-a-slot items keep their own rows.
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0], M.sizes[1], M.sizes[2], M.sizes[3], M.sizes[4], M.sizes[5] = 8, 4, 4, 0, 0, 0
	M.maxStack = { [6265] = 1, [4632] = 1 }
	local function shard() return { id = 6265, name = "Soul Shard", q = 1, class = 15, subclass = 0, price = 0 } end
	-- bag 1 is a soul bag (3 shards); bag 2 an ordinary bag (2 shards); the backpack: 1 shard, two lockboxes, cloth
	for s = 1, 3 do M.put(1, s, shard()) end
	M.put(2, 1, shard()); M.put(2, 2, shard())
	M.put(0, 1, shard())
	M.put(0, 2, { id = 4632, name = "Ornate Bronze Lockbox", q = 1, class = 15, subclass = 0, price = 1 })
	M.put(0, 3, { id = 4632, name = "Ornate Bronze Lockbox", q = 1, class = 15, subclass = 0, price = 1 })
	M.put(0, 4, { id = 2589, name = "Linen Cloth", q = 1, count = 10, class = 7, subclass = 5, price = 1 })
	M.put(0, 5, { id = 2589, name = "Linen Cloth", q = 1, count = 4, class = 7, subclass = 5, price = 1 })
	_G.UnitClass = function() return "Warlock", "WARLOCK" end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local realFree = C_Container.GetContainerNumFreeSlots
	C_Container.GetContainerNumFreeSlots = function(bag) local free = realFree(bag); return free, bag == 1 and 4 or 0 end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers()
	local main = n.Window.main
	local function rows(id)
		local out = {}
		for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then out[#out + 1] = b.rec end end
		return out
	end
	n:Set("view", "list"); n:Set("grp", "type"); n:Set("mergeStacks", true); n:RefreshViews(true); M.runTimers()
	local s = rows(6265)
	check(#s == 1 and s[1].merged and s[1].count == 6 and s[1].stacks == 6 and #s[1].members == 6,
		"Merge Stacks: the six Soul Shards show once, with the total (" .. #s .. " rows)")
	check(#rows(4632) == 2, "other one-to-a-slot items (the lockboxes) keep their own rows")
	local l = rows(2589)
	check(#l == 1 and l[1].count == 14, "stackable items merge as before")
	check(n.MergeKey({ itemID = 6265, quality = 1, maxStack = 1, bag = 0, slot = 1 }) == n.MergeKey({ itemID = 6265, quality = 1, maxStack = 1, bag = 2, slot = 1 }),
		"the merge key is the same for every shard, wherever it is")
	local function clearShardsShown()
		for _, pool in pairs(n.Buttons.lanes or {}) do
			for _, h in ipairs(pool) do if h:IsShown() and h.clearShards and h.clearShards:IsShown() then return true end end
		end
		return false
	end
	check(clearShardsShown(), "the section holding the merged shards has its Clear Shards button")
	-- the backpack's shard gone: the merged row stands on a shard in the soul bag, and the button still shows (its
	-- members in the ordinary bag decide, not the row's own slot)
	M.bags[0][1] = nil; n:Scan(); n:RefreshViews(true); M.runTimers()
	local rep = rows(6265)[1]
	check(rep and rep.bag == 1 and rep.count == 5, "(setup) the merged row stands on a soul bag shard (bag " .. tostring(rep and rep.bag) .. ")")
	check(clearShardsShown(), "Clear Shards still shows for the shards in the ordinary bag")
	M.put(0, 1, shard()); n:Scan(); n:RefreshViews(true); M.runTimers()
	-- Merge Stacks off: every shard on its own row again
	n:Set("mergeStacks", false); n:RefreshViews(true); M.runTimers()
	check(#rows(6265) == 6, "Merge Stacks off: six shard rows")
	n:Set("mergeStacks", true); n:RefreshViews(true); M.runTimers()
	-- at the bank, a right-click on the merged row: (by design in 1.7.2-beta2, Shweep: shards can't be banked, so nothing
	-- follows; this check used to expect the other five to follow, marked)
	local D = n.Drop
	n.atBank = true
	local used = {}
	local realUse = C_Container.UseContainerItem
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; M.bags[bag][slot] = nil end
	local first = rows(6265)[1]
	D:MoveRest({ itemID = 6265, members = first.members, name = "Soul Shard", first = { bag = first.bag, slot = first.slot }, token = D:NewGesture() })
	for _ = 1, 20 do M.runTimers() end
	check(#used == 0 and D.active == nil and not table.concat(M.log, "|"):find("Moved 0 of", 1, true),
		"at the bank, nothing follows a merged shard row, and no \"Moved 0 of\" line (" .. #used .. ")")
	C_Container.UseContainerItem = realUse
	n.atBank = false
	_G.UnitClass = function() return "Warrior", "WARRIOR" end
	C_Container.GetContainerNumFreeSlots = realFree
	_G.BagSmithDB = nil
end)()

;(function()
	-- ======== 1.7.2-beta1: the 1.7.1-beta4 audit's advisories A and B (see core_audit_1_7_1_beta4_routes_tests.lua) ========
	-- What /bs debug says in each, with the game's bag button modeled as on Forever (1.7.1-beta4's set).
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0], M.sizes[1], M.sizes[2], M.sizes[3], M.sizes[4], M.sizes[5] = 2, 4, 4, 0, 0, 0
	local LINEN, MAGE = 4238, 4241
	local function bagItem(id) return { id = id, name = id == MAGE and "Mageweave Bag" or "Linen Bag", q = 1, class = 1, subclass = 0, equip = "INVTYPE_BAG", price = 10 } end
	M.put(0, 1, { id = 2770, name = "Copper Ore", q = 1, count = 5, class = 7, subclass = 7, price = 1 })
	M.put(0, 2, { id = 2771, name = "Tin Ore", q = 1, count = 5, class = 7, subclass = 7, price = 1 })
	M.put(1, 2, bagItem(MAGE))
	M.put(2, 3, bagItem(MAGE))
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", debug = true } } }
	local equipped = { [20] = LINEN, [21] = 4240 }
	_G.GetInventoryItemID = function(_, inv) return equipped[inv] end
	local cur
	local puts = 0
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	C_Container.PickupContainerItem = function(bag, slot)
		local it = M.bags[bag][slot]
		if not cur then if it then cur = { bag = bag, slot = slot, id = it.id }; it.locked = true; M.cursorItem = it.id end return end
		if it then return end
		M.bags[bag][slot] = M.bags[cur.bag][cur.slot]; M.bags[cur.bag][cur.slot] = nil; M.bags[bag][slot].locked = nil
		cur = nil; M.cursorItem = nil
	end
	_G.ClearCursor = function() if cur then local it = M.bags[cur.bag][cur.slot]; if it then it.locked = nil end end cur = nil; M.cursorItem = nil end
	_G.PutItemInBag = function() puts = puts + 1 end
	local b = CreateFrame("Button", "CharacterBag0Slot", UIParent)
	b:SetScript("OnClick", function() end)   -- an empty cursor: the game's handler does nothing here
	n.SwapHint:HookBagButtons()
	_G.GetMouseFoci = function() return { b } end
	local function log() return table.concat(M.log, "|") end
	-- A: picked up, canceled over the slot (the cursor empties first), then a click there in the same frame
	C_Container.PickupContainerItem(1, 2); M.fire("ITEM_LOCK_CHANGED", 1, 2)
	ClearCursor(); M.fire("ITEM_LOCK_CHANGED", 1, 2)
	b:GetScript("OnClick")(b, "LeftButton")
	for _ = 1, 10 do M.runTimers() end
	check(equipped[20] == LINEN and puts == 0 and log():find("came back with the cursor empty (a cancel, not a refusal): nothing to do", 1, true),
		"A: a cancel then a click in the same frame swaps nothing, and /bs debug says why")
	-- B: a queued swap (the bag still on the cursor at the drop), then the other Mageweave Bag picked up first
	C_Container.PickupContainerItem(1, 2); M.fire("ITEM_LOCK_CHANGED", 1, 2)
	n.SwapHint:OnBagButton(b, "a drop")
	check(n.SwapHint.swapping == nil, "(setup) the swap is queued for the next frame")
	ClearCursor(); M.fire("ITEM_LOCK_CHANGED", 1, 2)
	C_Container.PickupContainerItem(2, 3); M.fire("ITEM_LOCK_CHANGED", 2, 3)
	for _ = 1, 10 do M.runTimers() end
	check(equipped[20] == LINEN and puts == 0 and M.cursorItem == MAGE and cur and cur.bag == 2 and cur.slot == 3
		and log():find("Swap: another item was picked up; not swapping", 1, true), "B: the newer bag stays on the cursor, nothing swapped, and /bs debug says why")
	ClearCursor()
	_G.GetMouseFoci = nil; _G.CharacterBag0Slot = nil
	_G.BagSmithDB = nil
end)()
