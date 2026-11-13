-- 1.7.1-beta2: the answers to the 1.7.1-beta1 audit (F1, F2, advisories A and B). The harness is beta1's (the game
-- modeled: a pick-up holds the item, its slot locked; a place moves it; ClearCursor puts it back; PutItemInBag refuses
-- a bag stored in the bag it would replace, leaving it on the cursor). The game's bag buttons are modeled as named
-- buttons whose own handler calls PutItemInBag, hooked by BagSmith (HookScript).
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

	local function blizzButton(i, handler)
		local f = CreateFrame("Button", "CharacterBag" .. i .. "Slot", UIParent)
		-- the game's own handler: a click or drop with an item on the cursor puts it in that bag slot
		local function game() if CursorHasItem() then PutItemInBag(20 + i) end end
		f:SetScript("OnReceiveDrag", game)
		f:SetScript("OnClick", handler or game)
		return f
	end
	local function hooked(r, i, handler)
		local b = blizzButton(i or 0, handler)
		if r.n.SwapHint.HookBagButtons then r.n.SwapHint:HookBagButtons() end   -- (absent before beta2: fails cleanly)
		return b
	end

	-- ---- F1: the game's bag bar swaps only from a real drop on its button
	local r = boot()
	local b = hooked(r)
	r.grab()
	b:GetScript("OnReceiveDrag")(b)
	check(#r.st.puts == 1 and r.M.cursorItem == MAGE and r.equipped[20] == LINEN, "(setup) the game's handler refused the drop; the bag is still on the cursor")
	r.run()
	check(r.equipped[20] == MAGE and #r.st.puts == 2 and r.M.cursorItem == nil and r.log():find("Swapped in Mageweave Bag; Linen Bag is in your", 1, true),
		"a drop on the game's bag button: swapped in on the next frame (" .. r.log() .. ")")

	r = boot(); b = hooked(r)
	r.grab()
	b:GetScript("OnClick")(b, "LeftButton")
	r.run()
	check(r.equipped[20] == MAGE and #r.st.puts == 2, "a click on the game's bag button with the bag on the cursor: swapped in")

	r = boot(); b = hooked(r)
	if r.n.SwapHint.HookBagButtons then r.n.SwapHint:HookBagButtons(); r.n.SwapHint:HookBagButtons() end
	r.grab()
	b:GetScript("OnReceiveDrag")(b)
	r.run()
	check(r.equipped[20] == MAGE and #r.st.puts == 2, "hooking again adds nothing: one swap")

	-- the same drop twice before the next frame: one swap (the newer one)
	r = boot(); b = hooked(r)
	r.grab()
	b:GetScript("OnReceiveDrag")(b); b:GetScript("OnReceiveDrag")(b)
	r.run()
	check(r.equipped[20] == MAGE and #r.st.puts == 3, "two drops before the next frame: one swap")

	-- an empty cursor: a click on the button picks up the equipped bag (the game's own handling), nothing else
	r = boot()
	b = hooked(r, 0, function() if not CursorHasItem() then r.M.cursorItem = LINEN end end)
	b:GetScript("OnClick")(b, "LeftButton")
	r.run()
	check(r.equipped[20] == LINEN and #r.st.puts == 0 and r.M.cursorItem == LINEN and not r.n.SwapHint.swapping,
		"a click with an empty cursor (picking up the equipped bag): BagSmith does nothing")
	r.M.cursorItem = nil

	-- a bag from another bag dropped on the button: the game's own swap, BagSmith does nothing
	r = boot(); b = hooked(r)
	r.M.put(2, 2, bagItem(MAGE))
	r.grab(2, 2)
	b:GetScript("OnReceiveDrag")(b)
	r.run()
	check(r.equipped[20] == MAGE and #r.st.puts == 1 and not r.n.SwapHint.swapping, "a bag from another bag: the game swaps it, BagSmith adds nothing")

	-- a bag of the same kind as the one it would replace: left to the game
	r = boot({ newBag = LINEN }); b = hooked(r)
	r.grab()
	b:GetScript("OnReceiveDrag")(b)
	r.run()
	check(r.equipped[20] == LINEN and #r.st.puts == 1 and not r.n.SwapHint.swapping, "the same kind of bag: nothing swapped")

	-- the player picks up something else before the next frame: no swap
	r = boot(); b = hooked(r)
	r.grab()
	b:GetScript("OnReceiveDrag")(b)
	ClearCursor(); C_Container.PickupContainerItem(1, 1)   -- the bag back, then the Linen Cloth picked up
	r.run()
	check(r.equipped[20] == LINEN and #r.st.puts == 1 and r.M.cursorItem == 2589 and not r.n.SwapHint.swapping,
		"another item on the cursor before the swap starts: nothing swapped, the cursor left alone")
	ClearCursor()

	-- the game handing the refused bag back to its slot before the next frame: still this drop, swapped in
	r = boot(); b = hooked(r)
	r.grab()
	b:GetScript("OnReceiveDrag")(b)
	ClearCursor()
	r.run()
	check(r.equipped[20] == MAGE, "the refused bag back in its slot before the next frame: swapped in")

	-- the hint's clues alone (the slot unlocking with the pointer over the button) explain and move nothing
	r = boot(); b = hooked(r)
	_G.GetMouseFoci = function() return { b } end
	r.grab()
	r.M.fire("ITEM_LOCK_CHANGED", 1, 2)
	r.M.bags[1][2].locked = nil
	r.M.fire("ITEM_LOCK_CHANGED", 1, 2)
	r.M.fire("UI_ERROR_MESSAGE", 1, "You have no target.")
	r.run()
	check(r.equipped[20] == LINEN and #r.st.puts == 0 and (r.n.SwapHint.shown or 0) == 1, "the clues alone: explained once, nothing moved")
	ClearCursor()
	-- and with a real drop the clues stay quiet: one swap, no hint
	r = boot(); b = hooked(r)
	_G.GetMouseFoci = function() return { b } end
	r.grab()
	r.M.fire("ITEM_LOCK_CHANGED", 1, 2)
	b:GetScript("OnReceiveDrag")(b)
	r.M.bags[1][2].locked = nil
	r.M.fire("ITEM_LOCK_CHANGED", 1, 2)
	r.run()
	check(r.equipped[20] == MAGE and (r.n.SwapHint.shown or 0) == 0, "a real drop with the clues: one swap, no hint")
	_G.GetMouseFoci = nil

	-- ---- F2: done when the bag slot holds the new bag, whatever the player picked up meanwhile
	r = boot()
	r.grab()
	r.slot1:GetScript("OnReceiveDrag")(r.slot1)
	-- the game confirms late: the swap's put holds until the player has picked something up
	local realPut = _G.PutItemInBag
	local delayed
	_G.PutItemInBag = function(inv) delayed = inv; r.st.puts[#r.st.puts + 1] = inv; r.M.cursorItem = nil; r.st.cur = nil end
	for _ = 1, 8 do r.M.runTimers() end
	check(delayed == 20 and r.n.SwapHint.swapping, "(setup) the put is waiting for the game")
	r.equipped[20] = MAGE; r.M.sizes[1] = 6; r.M.bags[2][2] = nil; r.M.put(2, 2, bagItem(LINEN))
	C_Container.PickupContainerItem(0, 1)   -- the player picks up the Copper Ore
	r.run()
	_G.PutItemInBag = realPut
	check(r.equipped[20] == MAGE and r.M.cursorItem == 2770 and not r.n.SwapHint.swapping and r.log():find("Swapped in Mageweave Bag", 1, true)
		and not r.log():find("didn't swap", 1, true), "a late confirmation with the player's item on the cursor: reported as done, the cursor left alone (" .. r.log() .. ")")
	ClearCursor()

	-- a place is named only when BagSmith sees the bag settled there: the player holding the new bag gets no place
	r = boot()
	r.grab()
	r.slot1:GetScript("OnReceiveDrag")(r.slot1)
	local nAt
	for s = 1, 4 do local it = r.M.bags[2][s]; if it and it.id == MAGE then nAt = s end end
	r.M.bags[2][nAt].locked = nil
	C_Container.PickupContainerItem(2, nAt)   -- the player takes the new bag while BagSmith waits
	-- (in the game a held item shows locked in its slot: the mock's late unlock from BagSmith's own place is kept off
	-- the held bag by giving the slot a fresh copy of it, locked)
	local copy = {}
	for k, v in pairs(r.M.bags[2][nAt]) do copy[k] = v end
	copy.locked = true; r.M.bags[2][nAt] = copy
	r.run()
	check(r.equipped[20] == LINEN and r.M.cursorItem == MAGE and not r.n.SwapHint.swapping and not r.log():find("Mageweave Bag is in your", 1, true),
		"the new bag on the player's cursor: no place named for it (" .. r.log() .. ")")
	ClearCursor()

	-- ---- A: an error in a later step is kept for /bs errors, ends the swap, and the next swap works
	r = boot()
	r.grab()
	r.slot1:GetScript("OnReceiveDrag")(r.slot1)
	local realLock = _G.InCombatLockdown
	_G.InCombatLockdown = function() error("injected check failure") end
	local okA = pcall(r.run)
	_G.InCombatLockdown = realLock
	check(okA and not r.n.SwapHint.swapping and #(r.n.errorLog or {}) > 0 and r.log():find("Something went wrong swapping the bags", 1, true),
		"an error in a later step: caught, kept for /bs errors, the swap ended, said")
	local magAt
	for b2 = 0, 2 do for s = 1, 4 do local it = r.M.bags[b2] and r.M.bags[b2][s]; if it and it.id == MAGE then magAt = b2 .. ":" .. s end end end
	check(magAt and r.M.cursorItem == nil, "the new bag in a bag slot, nothing on the cursor (" .. tostring(magAt) .. ")")
	local mb, ms = magAt:match("(%d+):(%d+)")
	r.M.bags[tonumber(mb)][tonumber(ms)].locked = nil
	if tonumber(mb) == 1 then
		C_Container.PickupContainerItem(1, tonumber(ms))
		r.slot1:GetScript("OnReceiveDrag")(r.slot1)
		r.run()
		check(r.equipped[20] == MAGE, "the next swap works")
	else
		check(not r.n.SwapHint.swapping, "the next swap isn't blocked")
	end

	-- ---- B: a swap that uses a bank bag ends when the bank closes, or opens again
	local function bankBoot()
		local rb = boot()
		rb.M.fire("BANKFRAME_OPENED"); rb.M.runTimers()
		rb.M.sizes[6] = 4; rb.M.bags[6] = rb.M.bags[6] or {}
		rb.M.put(6, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 3, class = 7, subclass = 5, price = 1 })
		rb.M.put(6, 2, bagItem(WOOL))
		rb.inv6 = C_Container.ContainerIDToInventoryID(6)
		rb.equipped[rb.inv6] = LINEN
		return rb
	end
	for _, how in ipairs({ "closed", "reopened" }) do
		r = bankBoot()
		r.grab(6, 2)
		r.n.SwapHint:Intercept(nil, r.inv6)   -- (the new bag moved out; the game's confirmation still to come)
		if how == "closed" then r.M.fire("BANKFRAME_CLOSED") else r.M.fire("BANKFRAME_CLOSED"); r.M.fire("BANKFRAME_OPENED") end
		r.run()
		check(r.equipped[r.inv6] == LINEN and #r.st.puts == 0 and r.M.cursorItem == nil and not r.n.SwapHint.swapping and r.log():find("the bank closed", 1, true),
			"the bank " .. how .. " during a swap with a bank bag: stopped, nothing put, said (" .. r.log() .. ")")
	end
	-- the bank's own swap, with the bank open throughout, still works
	r = bankBoot()
	r.grab(6, 2)
	r.n.SwapHint:Intercept(nil, r.inv6)
	r.run()
	check(r.equipped[r.inv6] == WOOL and not r.n.SwapHint.swapping, "with the bank open throughout, the bank bag swap is done")
	-- a swap with no bank bag isn't touched by the bank closing
	r = bankBoot()
	r.grab()
	r.slot1:GetScript("OnReceiveDrag")(r.slot1)
	r.M.fire("BANKFRAME_CLOSED")
	r.run()
	check(r.equipped[20] == MAGE, "a swap with no bank bag isn't stopped by the bank closing")
	_G.BagSmithDB = nil
end)()
