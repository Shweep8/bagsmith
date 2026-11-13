-- 1.7.1-beta4: the game's bag bar on Forever, from Shweep's /bs debug on beta3. The refusal comes inside the game's
-- bag button handler (the bag's slot unlocks with the bag still on the cursor), and the handler returns with the
-- cursor empty and the bag back in its slot; BagSmith's post-hook claims that refusal and swaps. The harness is
-- beta1's; the game's button is modeled as logged in game. (Replaces beta3's set: its model, the game holding the bag
-- and handing it back later, wasn't what Forever does.)
;(function()
	local LINEN, WOOL, MAGE, TINY = 4238, 4240, 4241, 4999
	local SIZE = { [LINEN] = 4, [WOOL] = 4, [MAGE] = 6, [TINY] = 2 }
	local NAMES = { [LINEN] = "Linen Bag", [WOOL] = "Wool Bag", [MAGE] = "Mageweave Bag", [TINY] = "Tiny Pouch" }
	local function bagItem(id) return { id = id, name = NAMES[id], q = 1, class = 1, subclass = 0, equip = "INVTYPE_BAG", price = 10 } end
	local function boot(opts)
		opts = opts or {}
		package.loaded.mock = nil
		local M = require("mock")
		M.sizes[0], M.sizes[1], M.sizes[2], M.sizes[3], M.sizes[4], M.sizes[5] = 2, 4, 4, 0, 0, 0
		-- the backpack full; bag 1 (a Linen Bag) holds cloth, the new bag and ore; bag 2 (a Wool Bag) has room
		M.put(0, 1, { id = 2770, name = "Copper Ore", q = 1, count = 5, class = 7, subclass = 7, price = 1 })
		M.put(0, 2, { id = 2771, name = "Tin Ore", q = 1, count = 5, class = 7, subclass = 7, price = 1 })
		M.put(1, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 10, class = 7, subclass = 5, price = 1 })
		M.put(1, 2, bagItem(opts.newBag or MAGE))
		M.put(1, 3, { id = 2592, name = "Wool Cloth", q = 1, count = 4, class = 7, subclass = 5, price = 1 })
		if opts.fullBag1 then M.put(1, 4, { id = 2840, name = "Copper Bar", q = 1, count = 2, class = 7, subclass = 7, price = 1 }) end
		M.put(2, 1, { id = 2835, name = "Rough Stone", q = 1, count = 3, class = 7, subclass = 7, price = 1 })
		if opts.noRoom then for s = 2, 4 do M.put(2, s, { id = 2836, name = "Coarse Stone", q = 1, count = 1, class = 7, subclass = 7, price = 1 }) end end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", bagBar = true } } }
		local equipped = { [20] = LINEN, [21] = WOOL }
		_G.GetInventoryItemID = function(_, inv) return equipped[inv] end
		_G.GetInventoryItemTexture = function(_, inv) return equipped[inv] and 133 or nil end
		local st = { cur = nil, puts = {}, mode = opts.mode }
		local function unlockSoon(it) C_Timer.After(0, function() it.locked = nil end) end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id) local num = tonumber(tostring(id):match("item:(%d+)")) or id; if NAMES[num] then return NAMES[num] end return realInfo(id) end
		C_Container.PickupContainerItem = function(bag, slot)
			local it = M.bags[bag][slot]
			if not st.cur then
				if it then st.cur = { id = it.id, bag = bag, slot = slot }; it.locked = true; M.cursorItem = it.id end
				return
			end
			if it then return end   -- an occupied slot: nothing happens, the item stays on the cursor
			local moved
			if st.cur.loose and st.mode == "old_on_cursor_throw" then error("the place failed") end
			if st.cur.loose then moved = bagItem(st.cur.id); M.put(bag, slot, moved)
			else moved = M.bags[st.cur.bag][st.cur.slot]; M.bags[bag][slot] = moved; M.bags[st.cur.bag][st.cur.slot] = nil end
			moved.locked = true; unlockSoon(moved)
			st.cur = nil; M.cursorItem = nil
		end
		_G.ClearCursor = function()
			if st.cur and not st.cur.loose then local it = M.bags[st.cur.bag][st.cur.slot]; if it then it.locked = nil end end
			st.cur = nil; M.cursorItem = nil
		end
		_G.PutItemInBag = function(inv)
			st.puts[#st.puts + 1] = inv
			if st.mode == "throw" then error("the game refused the bag") end
			if not st.cur or st.cur.loose then return end
			local new = M.bags[st.cur.bag][st.cur.slot]
			local x = inv - 19
			-- the game's rule: a bag stored in the bag it would replace is refused, and stays on the cursor
			if st.cur.bag == x then return end
			local count = 0
			for _, it in pairs(M.bags[x]) do if it ~= new then count = count + 1 end end
			if count > (SIZE[new.id] or 0) then return end   -- refused: the new bag stays on the cursor
			local old = equipped[inv]
			equipped[inv] = new.id
			M.sizes[x] = SIZE[new.id]
			local yb, ys = st.cur.bag, st.cur.slot
			M.bags[yb][ys] = nil
			st.cur = nil; M.cursorItem = nil
			if st.mode == "old_on_cursor" or st.mode == "old_on_cursor_throw" then
				st.cur = { id = old, loose = true }; M.cursorItem = old
			else
				local ob = bagItem(old); ob.locked = true; M.put(yb, ys, ob); unlockSoon(ob)
			end
		end
		n.Window:Show(); M.runTimers(); M.runTimers()
		local main = n.Window.main
		local slot1
		for _, s in ipairs(main.bagBar and main.bagBar.slots or {}) do if s.bag == 1 then slot1 = s end end
		-- the player picks up the new bag from bag 1, slot 2
		local function grab(bag, slot) C_Container.PickupContainerItem(bag or 1, slot or 2) end
		local function run() for _ = 1, 40 do M.runTimers() end end
		local function log() return table.concat(M.log, "|") end
		return { n = n, M = M, st = st, equipped = equipped, slot1 = slot1, grab = grab, run = run, log = log }
	end

	-- The game's bag button on Forever, as Shweep's /bs debug on beta3 showed it: dropping a bag on the slot of the bag
	-- it's stored in, the game refuses inside its own handler (the bag's slot unlocks while the bag is still on the
	-- cursor: ITEM_LOCK_CHANGED), and the handler returns with the cursor empty and the bag back in its slot. Then
	-- BagSmith's post-hook runs. Any other drop is the game's ordinary PutItemInBag.
	local function blizzButton(r, i, late)
		local f = CreateFrame("Button", "CharacterBag" .. i .. "Slot", UIParent)
		local function game()
			if not CursorHasItem() then return end
			local cur = r.st.cur
			if cur and not cur.loose and cur.bag == i + 1 then
				r.st.puts[#r.st.puts + 1] = 20 + i
				r.M.bags[cur.bag][cur.slot].locked = nil
				r.M.fire("ITEM_LOCK_CHANGED", cur.bag, cur.slot)   -- refused: unlocked, still on the cursor
				if late then r.M.gameTime = r.M.gameTime + late end
				r.st.cur = nil; r.M.cursorItem = nil                  -- back in its slot
				return
			end
			PutItemInBag(20 + i)
		end
		f:SetScript("OnReceiveDrag", game)
		f:SetScript("OnClick", game)
		return f
	end
	local function setup(opts)
		opts = opts or {}
		local r = boot(opts)
		r.n.db.debug = true
		r.b = blizzButton(r, 0, opts.late)
		r.watching = r.n.SwapHint.HookBagButtons and r.n.SwapHint:HookBagButtons()
		_G.GetMouseFoci = function() return { r.b } end
		return r
	end
	local function pick(r) r.grab(); r.M.fire("ITEM_LOCK_CHANGED", 1, 2) end   -- picked up: the game locks its slot

	-- ---- a drop on the game's slot: refused inside the handler, claimed by the hook, swapped in, nothing explained
	local r = setup()
	check(r.watching == 1, "(setup) BagSmith watches the game's bag slot")
	pick(r)
	r.b:GetScript("OnReceiveDrag")(r.b)
	local L = r.log()
	check(L:find("Swap hint: the bag was released back into bag 1 slot 2; cursor still holds the bag; pointer over CharacterBag0Slot", 1, true)
		and L:find("Swap: a drop on the game's slot for bag 1; cursor empty; bag last picked up: Mageweave Bag from bag 1 slot 2, back, not held; refused just now: yes", 1, true)
		and L:find("Swap: the game refused Mageweave Bag and put it back: swapping it in", 1, true),
		"/bs debug: Shweep's sequence, then the claim (" .. L .. ")")
	r.run()
	check(r.equipped[20] == MAGE and r.M.cursorItem == nil and (r.n.SwapHint.shown or 0) == 0 and r.log():find("Swapped in Mageweave Bag; Linen Bag is in your", 1, true)
		and not r.log():find(r.n.SwapHint.TEXT, 1, true), "swapped in, and the old explanation isn't shown (" .. r.log() .. ")")

	-- ---- a click instead: the same
	r = setup()
	pick(r)
	r.b:GetScript("OnClick")(r.b, "LeftButton")
	r.run()
	check(r.equipped[20] == MAGE and (r.n.SwapHint.shown or 0) == 0, "a click on the game's slot: swapped in")

	-- ---- a cancel over the slot (no handler call): explained on the next frame, nothing moved
	r = setup()
	pick(r)
	ClearCursor(); r.M.fire("ITEM_LOCK_CHANGED", 1, 2)
	check((r.n.SwapHint.shown or 0) == 0, "(the explanation waits one frame for the button's handler)")
	r.run()
	check(r.equipped[20] == LINEN and #r.st.puts == 0 and (r.n.SwapHint.shown or 0) == 1, "a cancel over the slot: explained, nothing moved")
	-- and a click there afterwards, with an empty cursor, claims nothing
	r.b:GetScript("OnClick")(r.b, "LeftButton")
	r.run()
	check(r.equipped[20] == LINEN and #r.st.puts == 0 and r.log():find("the game refused nothing from bag 1 just now: nothing to do", 1, true),
		"a later click with an empty cursor: nothing moved")

	-- ---- a refusal for bag 1 claimed by another bag's button: no
	r = setup()
	local b1 = blizzButton(r, 1); r.n.SwapHint:HookBagButtons()
	pick(r)
	ClearCursor(); r.M.fire("ITEM_LOCK_CHANGED", 1, 2)
	b1:GetScript("OnClick")(b1, "LeftButton")
	r.run()
	check(r.equipped[20] == LINEN and #r.st.puts == 0 and (r.n.SwapHint.shown or 0) == 1, "another bag's button can't claim bag 1's refusal")

	-- ---- the refusal and the hook too far apart: explained, nothing moved
	r = setup({ late = 2 })
	pick(r)
	r.b:GetScript("OnReceiveDrag")(r.b)
	r.run()
	check(r.equipped[20] == LINEN and #r.st.puts == 1 and (r.n.SwapHint.shown or 0) == 1, "a refusal too long before the hook: explained, nothing moved")

	-- ---- the same kind of bag: said, nothing swapped, no explanation
	r = setup({ newBag = LINEN })
	pick(r)
	r.b:GetScript("OnReceiveDrag")(r.b)
	r.run()
	check(r.equipped[20] == LINEN and #r.st.puts == 1 and (r.n.SwapHint.shown or 0) == 0
		and r.log():find("Linen Bag is the same kind of bag as the one in that slot, so there's nothing to swap.", 1, true), "the same kind of bag: said so")
	-- and on BagSmith's Bag Bar too, without handing the drop to the game
	r = boot({ newBag = LINEN })
	r.grab()
	r.slot1:GetScript("OnReceiveDrag")(r.slot1)
	check(#r.st.puts == 0 and r.M.cursorItem == nil and r.log():find("same kind of bag", 1, true), "the same kind on the Bag Bar: said, the bag back in its slot")

	-- ---- no free slot elsewhere: said, nothing moved, no explanation
	r = setup({ noRoom = true })
	pick(r)
	r.b:GetScript("OnReceiveDrag")(r.b)
	r.run()
	check(r.equipped[20] == LINEN and #r.st.puts == 1 and r.log():find("needs a free slot in another bag", 1, true) and (r.n.SwapHint.shown or 0) == 0,
		"no free slot: said, nothing moved")

	-- ---- a bag from another bag dropped there: the game's own swap, BagSmith adds nothing
	r = setup()
	r.M.put(2, 2, bagItem(MAGE))
	r.grab(2, 2); r.M.fire("ITEM_LOCK_CHANGED", 2, 2)
	r.b:GetScript("OnReceiveDrag")(r.b)
	r.run()
	check(r.equipped[20] == MAGE and #r.st.puts == 1 and not r.n.SwapHint.swapping and (r.n.SwapHint.shown or 0) == 0, "a bag from another bag: the game's swap, nothing added")
	_G.GetMouseFoci = nil
	_G.BagSmithDB = nil
end)()
