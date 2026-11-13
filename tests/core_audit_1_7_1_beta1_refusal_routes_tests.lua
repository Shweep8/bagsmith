-- 1.7.1-beta2: the 1.7.1-beta1 audit's own probe (routes/refusal_routes.lua). Its four F1 scenarios (a canceled drag,
-- an unrelated error, a cancel over the button, an error while holding) are as delivered and pass; its two controls
-- that swapped from the refusal's clues are turned round by design (marked): the clues explain only, and the same
-- refused drop made through the bag button's own handler swaps once. Evidence and the report:
-- docs/plugins/audit-1.7.1-beta1/.
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
 local function pointer(name)
  local f=CreateFrame('Button',name,UIParent)
  _G.GetMouseFoci=function()return {f}end
 end
 -- A normal canceled drag must not authorize an unrelated later error to equip the bag.
 local r=boot()
 pointer('WorldFrame')
 r.grab();r.M.fire('ITEM_LOCK_CHANGED',1,2)
 ClearCursor();r.M.fire('ITEM_LOCK_CHANGED',1,2)
 check(r.M.cursorItem==nil and not r.n.SwapHint.swapping,'setup: canceled drag, no cursor or swap')
 pointer('CharacterBag0Slot')
 r.M.fire('UI_ERROR_MESSAGE',1,'You have no target.')
 r.run()
 print('STALE ERROR ROUTE: equipped='..tostring(r.equipped[20])..' calls='..#r.st.puts..' '..r.log())
 check(r.equipped[20]==LINEN and #r.st.puts==0,'unrelated error after canceled drag does not auto-equip bag')
 -- Same canceled-elsewhere sequence without any unlock event: error path alone must reject stale pickup.
 r=boot();pointer('WorldFrame')
 r.grab();r.M.fire('ITEM_LOCK_CHANGED',1,2)
 ClearCursor()
 pointer('CharacterBag0Slot');r.M.fire('UI_ERROR_MESSAGE',1,'You have no target.')
 r.run()
 print('STALE ERROR WITHOUT UNLOCK: equipped='..tostring(r.equipped[20])..' calls='..#r.st.puts)
 check(r.equipped[20]==LINEN and #r.st.puts==0,'unrelated error after cancellation cannot use stale pickup without unlock')
 -- Escape while merely hovering the bag button is not a drop onto that button.
 r=boot();pointer('CharacterBag0Slot')
 r.grab();r.M.fire('ITEM_LOCK_CHANGED',1,2)
 ClearCursor();r.M.fire('ITEM_LOCK_CHANGED',1,2)
 r.run()
 print('CANCEL OVER BUTTON: equipped='..tostring(r.equipped[20])..' calls='..#r.st.puts..' '..r.log())
 check(r.equipped[20]==LINEN and #r.st.puts==0,'canceling drag over equipped bag button does not swap')
 -- Held cursor route also treats any unrelated error as a drop; no unlock event involved.
 r=boot();pointer('WorldFrame')
 r.grab();r.M.fire('ITEM_LOCK_CHANGED',1,2)
 pointer('CharacterBag0Slot');r.M.fire('UI_ERROR_MESSAGE',1,'You have no target.')
 r.run()
 print('UNRELATED ERROR WHILE HOLDING: equipped='..tostring(r.equipped[20])..' calls='..#r.st.puts)
 check(r.equipped[20]==LINEN and #r.st.puts==0,'hover plus unrelated error while holding bag is not a drop')
 -- Control: real same-bag refusal still works.
 -- (1.7.1-beta2, by design, F1: the refusal's clues alone explain and move nothing)
 r=boot();pointer('CharacterBag0Slot')
 r.grab();r.M.fire('ITEM_LOCK_CHANGED',1,2)
 r.M.bags[1][2].locked=nil;r.M.fire('ITEM_LOCK_CHANGED',1,2)
 r.run()
 check(r.equipped[20]==LINEN and #r.st.puts==0 and (r.n.SwapHint.shown or 0)==1,'the refusal clues alone explain once, nothing moved')
 -- (1.7.1-beta2) the same refused drop made through the bag button: the game's handler refuses (the bag stays on the
 -- cursor), BagSmith's post-hook swaps it in once, the refusal's clues adding nothing
 local function blizzButton()
  local f=CreateFrame('Button','CharacterBag0Slot',UIParent)
  f:SetScript('OnReceiveDrag',function() PutItemInBag(20) end)
  _G.GetMouseFoci=function()return {f}end
  return f
 end
 r=boot();local b=blizzButton();if r.n.SwapHint.HookBagButtons then r.n.SwapHint:HookBagButtons() end
 r.grab();r.M.fire('ITEM_LOCK_CHANGED',1,2)
 b:GetScript('OnReceiveDrag')(b)
 r.run()
 check(r.equipped[20]==MAGE and #r.st.puts==2 and r.M.cursorItem==nil,'a real refused drop on the button is swapped in once (the refused put by the game and the one by BagSmith)')
 -- Both routes for one actual refusal must not duplicate the operation.
 r=boot();b=blizzButton();if r.n.SwapHint.HookBagButtons then r.n.SwapHint:HookBagButtons() end
 r.grab();r.M.fire('ITEM_LOCK_CHANGED',1,2)
 b:GetScript('OnReceiveDrag')(b)
 r.M.bags[1][2].locked=nil;r.M.fire('ITEM_LOCK_CHANGED',1,2)
 r.M.fire('UI_ERROR_MESSAGE',1,'Cannot equip that bag.')
 r.run()
 check(r.equipped[20]==MAGE and #r.st.puts==2 and (r.n.SwapHint.shown or 0)==0,'duplicate routes perform only one swap, and no extra hint')
 -- Other bag pointer is not handled.
 r=boot();pointer('CharacterBag1Slot')
 r.grab();r.M.fire('ITEM_LOCK_CHANGED',1,2)
 ClearCursor();r.M.fire('ITEM_LOCK_CHANGED',1,2);r.M.fire('UI_ERROR_MESSAGE',1,'You have no target.')
 r.run();check(#r.st.puts==0 and r.equipped[20]==LINEN,'different bag pointer does not swap')
 _G.GetMouseFoci=nil
end)()
