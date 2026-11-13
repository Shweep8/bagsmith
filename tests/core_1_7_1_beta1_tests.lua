;(function()
	-- ======== 1.7.1-beta1: a bag swapped in with one drag (Shweep, from a player's review) ========
	-- The game won't put a new bag in the slot of the bag it's stored in. BagSmith now moves the new bag to a free slot
	-- in another bag first, then puts it in the slot; the game swaps them (the old bag's contents move into the new
	-- one, the old bag goes where the new one came from). The game is modeled here: a pick-up holds the item (its slot
	-- locked), a place moves it, ClearCursor puts it back, PutItemInBag swaps when the new bag has room for the old
	-- one's contents, else refuses and leaves the new bag on the cursor.
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

	-- ---- the Bag Bar: drop the Mageweave Bag (stored in the Linen Bag) on the Linen Bag's slot
	local r = boot()
	check(r.slot1 and r.slot1.inv == 20, "(setup) the Bag Bar's slot for bag 1")
	r.grab()
	r.slot1:GetScript("OnReceiveDrag")(r.slot1)
	r.run()
	check(r.equipped[20] == MAGE and r.M.sizes[1] == 6, "the Mageweave Bag is in bag 1's slot, now 6 slots")
	local wasLinen
	for s = 1, 4 do local it = r.M.bags[2][s]; if it and it.id == LINEN then wasLinen = s end end
	check(wasLinen == 2 and r.M.bags[1][1] and r.M.bags[1][1].id == 2589 and r.M.bags[1][3] and r.M.bags[1][3].id == 2592,
		"the Linen Bag went to the free slot in bag 2; bag 1's cloth stayed with it")
	check(#r.st.puts == 1 and r.st.puts[1] == 20 and r.M.cursorItem == nil and not r.n.SwapHint.swapping, "one PutItemInBag, nothing left on the cursor, the swap over")
	check(r.log():find("Swapped in Mageweave Bag; Linen Bag is in your", 1, true) and not r.log():find("The game can't swap a bag", 1, true),
		"chat says it's swapped in and where the old bag went; the old hint isn't shown (" .. r.log() .. ")")

	-- ---- no free slot outside the bag: said, nothing moves
	r = boot({ noRoom = true })
	r.grab()
	r.slot1:GetScript("OnReceiveDrag")(r.slot1)
	r.run()
	check(r.equipped[20] == LINEN and #r.st.puts == 0 and r.M.bags[1][2].id == MAGE and not r.M.bags[1][2].locked and r.M.cursorItem == nil,
		"no free slot in another bag: nothing moves, the new bag back in its slot")
	check(r.log():find("needs a free slot in another bag", 1, true), "and chat says to free one (" .. r.log() .. ")")

	-- ---- too small for what the old bag holds: the game refuses; said; the new bag left where it was moved
	r = boot({ newBag = TINY, fullBag1 = true })
	r.grab()
	r.slot1:GetScript("OnReceiveDrag")(r.slot1)
	r.run()
	local tinyAt
	for s = 1, 4 do local it = r.M.bags[2][s]; if it and it.id == TINY then tinyAt = s end end
	check(r.equipped[20] == LINEN and #r.st.puts == 1 and tinyAt and r.M.cursorItem == nil and not r.n.SwapHint.swapping,
		"a bag too small: the game refuses, the bag is put back in bag 2 (where it was moved), nothing on the cursor")
	check(r.log():find("The game didn't swap the bags (Tiny Pouch may be too small for what Linen Bag holds)", 1, true), "said (" .. r.log() .. ")")

	-- ---- a client that hands the old bag back on the cursor: set down in the free slot
	r = boot({ mode = "old_on_cursor" })
	r.grab()
	r.slot1:GetScript("OnReceiveDrag")(r.slot1)
	r.run()
	local linenAt
	for s = 1, 4 do local it = r.M.bags[2][s]; if it and it.id == LINEN then linenAt = s end end
	check(r.equipped[20] == MAGE and linenAt == 2 and r.M.cursorItem == nil, "the old bag handed back on the cursor is set down in the free slot")

	-- ---- an error while setting the old bag down: the cursor isn't cleared (the old bag's slot is taken), said
	r = boot({ mode = "old_on_cursor_throw" })
	r.grab()
	r.slot1:GetScript("OnReceiveDrag")(r.slot1)
	local okT = pcall(r.run)
	check(okT and r.equipped[20] == MAGE and r.M.cursorItem == LINEN and not r.n.SwapHint.swapping
		and r.log():find("Linen Bag is on your cursor: set it down in a free slot. See /bs errors.", 1, true),
		"an error setting the old bag down leaves it on the cursor and says so (" .. r.log() .. ")")

	-- ---- in combat: said, nothing moves
	r = boot()
	local realCombat = InCombatLockdown
	_G.InCombatLockdown = function() return true end
	r.grab()
	r.slot1:GetScript("OnReceiveDrag")(r.slot1)
	_G.InCombatLockdown = realCombat
	r.run()
	check(#r.st.puts == 0 and r.equipped[20] == LINEN and r.log():find("Bags can't be swapped in combat", 1, true), "in combat: nothing moves, said")
	_G.ClearCursor()

	-- ---- not the bag it's stored in, or not a bag: the drop goes to the game as before
	r = boot()
	r.grab(1, 2)
	local b2
	for _, s in ipairs(r.n.Window.main.bagBar.slots) do if s.bag == 2 then b2 = s end end
	b2:GetScript("OnReceiveDrag")(b2)
	check(#r.st.puts == 1 and r.st.puts[1] == 21, "a bag dropped on another bag's slot goes to the game, as before")
	r = boot()
	r.grab(1, 1)   -- Linen Cloth
	r.slot1:GetScript("OnReceiveDrag")(r.slot1)
	check(#r.st.puts == 1 and r.st.puts[1] == 20, "an item that isn't a bag goes to the game, as before")

	-- ---- an error from the game while swapping: caught, the new bag put back, said; the next try works
	r = boot({ mode = "throw" })
	r.grab()
	r.slot1:GetScript("OnReceiveDrag")(r.slot1)
	local ok = pcall(r.run)
	local magAt
	for s = 1, 4 do local it = r.M.bags[2][s]; if it and it.id == MAGE then magAt = s end end
	check(ok and r.M.cursorItem == nil and magAt and not r.n.SwapHint.swapping and r.log():find("Something went wrong swapping the bags; see /bs errors.", 1, true),
		"an error in the swap: caught, the new bag back in the slot it was moved to, said")
	check(#(r.n.errorLog or {}) > 0 and r.n.errorLog[1]:find("Swapping bags", 1, true), "kept for /bs errors")
	r.st.mode = nil
	C_Container.PickupContainerItem(2, magAt)
	-- (now it's in bag 2, not in bag 1: an ordinary drop the game takes)
	r.slot1:GetScript("OnReceiveDrag")(r.slot1)
	r.run()
	check(r.equipped[20] == MAGE, "the next drop works")

	-- ---- Blizzard's bag bar: the refused drop noticed, and the swap done
	r = boot()
	local blizz = CreateFrame("Button", "CharacterBag0Slot", UIParent)
	_G.GetMouseFoci = function() return { blizz } end
	r.grab()
	r.M.fire("ITEM_LOCK_CHANGED", 1, 2)   -- picked up: remembered
	-- the game refuses the drop on bag 1's slot: on Forever the bag stays on the cursor while its slot unlocks
	r.M.bags[1][2].locked = nil
	r.M.fire("ITEM_LOCK_CHANGED", 1, 2)
	r.run()
	-- (by design in 1.7.1-beta2, the 1.7.1-beta1 audit's F1: the refusal's clues explain only, as in 1.7.0; the swap
	-- from the game's bag bar starts from its buttons' own handlers, core_1_7_1_beta2_tests.lua)
	check(r.equipped[20] == LINEN and #r.st.puts == 0 and (r.n.SwapHint.shown or 0) == 1,
		"Blizzard's bag bar: the refusal's clues alone explain, and move nothing (" .. r.log() .. ")")
	_G.GetMouseFoci = nil

	-- ---- the Bank Bags strip: a bag stored in the bank bag it should replace (bank bag 6, a Linen Bag)
	r = boot()
	r.n.atBank = true
	r.M.sizes[6] = 4; r.M.bags[6] = r.M.bags[6] or {}
	r.M.put(6, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 3, class = 7, subclass = 5, price = 1 })
	r.M.put(6, 2, bagItem(WOOL))
	local inv6 = C_Container.ContainerIDToInventoryID(6)
	r.equipped[inv6] = LINEN
	r.grab(6, 2)
	check(r.n.SwapHint:Intercept(nil, inv6) == true, "the Bank Bags strip's drop is taken by BagSmith")
	r.run()
	local oldAt
	for b = 0, 4 do for s = 1, 4 do local it = r.M.bags[b] and r.M.bags[b][s]; if it and it.id == LINEN then oldAt = b .. ":" .. s end end end
	check(r.equipped[inv6] == WOOL and #r.st.puts == 1 and r.st.puts[1] == inv6 and r.M.cursorItem == nil and oldAt and not r.n.SwapHint.swapping,
		"the Wool Bag swapped into bank bag 6's slot, the Linen Bag set down in a free slot (" .. tostring(oldAt) .. "; " .. r.log() .. ")")
	-- both of the strip's drop handlers ask BagSmith first, then hand the drop to the game
	local src = io.open("BagSmith/Frames/Bank.lua"):read("*a")
	local _, calls = src:gsub("ns%.SwapHint:Intercept%(nil, [%w%.]+%.invID%)%) then PutItemInBag%(", "")
	check(calls == 2, "the strip's click and its drop both try the swap before the game (" .. calls .. ")")
	r.n.atBank = false

	-- ---- one swap at a time
	r = boot()
	r.grab()
	r.slot1:GetScript("OnReceiveDrag")(r.slot1)
	check(r.n.SwapHint.swapping ~= nil and r.n.SwapHint:SwapIn(1, 20, 2, MAGE) == true and #r.st.puts == 0, "a second swap while one runs is ignored")
	r.run()
	check(r.equipped[20] == MAGE and #r.st.puts == 1, "and the first finishes")
	_G.BagSmithDB = nil
end)()

;(function()
	-- ======== 1.7.1-beta1: a currency unpinned stays unpinned in that profile, for every character (the 1.7.0-beta14
	-- audit's advisory, option 2) ========
	package.loaded.mock = nil
	local M = require("mock")
	local names = { [1901] = "Honor", [1902] = "Arena Points" }
	local function boot(char, account)
		package.loaded.mock = nil
		M = require("mock")
		_G.C_CurrencyInfo.GetCurrencyInfo = function(id) if names[id] then return { name = names[id], quantity = 9, iconFileID = 8, quality = 1 } end end
		M.backpackPicks = { 1901, 1902 }
		_G.BagSmithCharDB = char or { version = 1, firstSeen = {} }
		_G.BagSmithDB = account or { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", fav = {} } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers()
		return n
	end
	local n = boot()
	local function fav(id) return n.Currency:IsFavorite("c:" .. id) end
	n.Window:Show()
	check(fav(1901) and fav(1902), "(setup) the first character's picks pinned on open")
	n.Currency:ToggleFavorite("c:1901")
	check(not fav(1901) and n.db.blizzUnpinned[1901] == true, "unpinning one is remembered in the profile")
	-- a second character sharing the profile, with the same pick
	local account = _G.BagSmithDB
	n = boot(nil, account)
	n.Window:Show()
	check(not fav(1901) and fav(1902) and n.cdb.blizzPicksSeen[1901], "a second character sharing the profile doesn't pin it again")
	-- pinned again by hand: no longer held back
	n.Currency:ToggleFavorite("c:1901")
	check(fav(1901) and n.db.blizzUnpinned[1901] == nil, "pinning it again by hand forgets the unpin")
	n.Currency:ToggleFavorite("c:1901")
	check(n.db.blizzUnpinned[1901] == true, "(unpinned again)")
	-- the button: pins every pick and forgets the unpins
	n.Drawer:Show()
	n.Drawer.frame.import:GetScript("OnClick")(n.Drawer.frame.import)
	check(fav(1901) and n.db.blizzUnpinned[1901] == nil, "Import Blizzard Picks pins it and forgets the unpin")
	-- items tracked as currencies aren't wallet currencies: no record
	n.Currency:ToggleFavorite("i:2589"); n.Currency:ToggleFavorite("i:2589")
	local count = 0; for _ in pairs(n.db.blizzUnpinned) do count = count + 1 end
	check(count == 0, "an item tracked as a currency isn't recorded")
	-- the saved record keeps only currency IDs; another profile is unaffected
	account.profiles.Default.blizzUnpinned = { [1902] = true, junk = true, [7] = "yes" }
	n = boot(nil, account)
	check(n.db.blizzUnpinned[1902] == true and n.db.blizzUnpinned.junk == nil and n.db.blizzUnpinned[7] == nil, "the saved record keeps only currency IDs")
	_G.BagSmithDB = nil
end)()
