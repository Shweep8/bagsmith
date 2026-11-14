-- 1.7.1: the 1.7.1-beta4 audit's own probe (routes/beta4_routes.lua). Its two race advisories, A (a cancel over the
-- game's bag slot claimed by an empty click in the same frame) and B (a newer pick-up of the same item before the
-- queued start), were accepted for 1.7.1 by Shweep (13 Nov: "we can go to prod and handle these in next build"): their
-- two checks were turned round in 1.7.1 to record that behavior; 1.7.2-beta1 fixes both and turns them back to the
-- auditor's own checks (marked). The other eleven are as delivered. Evidence and the report: docs/plugins/audit-1.7.1-beta4/.
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
 -- Old F1: cancellation and unrelated errors alone no longer move inventory.
 local r=setup();pick(r);ClearCursor();r.M.fire('ITEM_LOCK_CHANGED',1,2)
 r.M.fire('UI_ERROR_MESSAGE',1,'You have no target.');r.run()
 check(r.equipped[20]==LINEN and #r.st.puts==0,'F1 cancel/error alone makes no move')
 r=setup();pick(r);r.M.fire('UI_ERROR_MESSAGE',1,'You have no target.');r.run()
 check(r.equipped[20]==LINEN and #r.st.puts==0,'F1 held unrelated error makes no move')
 -- Empty clicks without any recent refusal are inert.
 r=setup();r.b:GetScript('OnClick')(r.b,'LeftButton');r.run()
 check(r.equipped[20]==LINEN and #r.st.puts==0,'empty click alone inert')
 -- Critical difference: cancel then empty click in the same frame, before timer expiry.
 r=setup();pick(r);ClearCursor();r.M.fire('ITEM_LOCK_CHANGED',1,2)
 check(r.M.cursorItem==nil and not r.n.SwapHint.swapping,'setup: canceled, no drop, cursor empty')
 r.b:GetScript('OnClick')(r.b,'LeftButton');r.run()
 print('CANCEL THEN SAME-FRAME EMPTY CLICK: equipped='..r.equipped[20]..' puts='..#r.st.puts..' '..r.log())
 -- (1.7.2-beta1, advisory A fixed: the auditor's check, turned back)
 check(r.equipped[20]==LINEN and #r.st.puts==0,'cancel plus empty bag-toggle click must not equip canceled bag')
 -- Delayed empty click serves as control and must not claim canceled drag.
 r=setup();pick(r);ClearCursor();r.M.fire('ITEM_LOCK_CHANGED',1,2);r.M.runTimers()
 r.b:GetScript('OnClick')(r.b,'LeftButton');r.run()
 check(r.equipped[20]==LINEN and #r.st.puts==0,'next-frame empty click does not swap')
 -- Expired timestamp, even without timers, must be discarded.
 r=setup();pick(r);ClearCursor();r.M.fire('ITEM_LOCK_CHANGED',1,2);r.M.gameTime=r.M.gameTime+1
 r.b:GetScript('OnClick')(r.b,'LeftButton');r.run()
 check(r.equipped[20]==LINEN and #r.st.puts==0,'stale timestamp not claimed')
 -- Real refused drop followed by duplicate hook/click: exactly one extra swap.
 r=setup();pick(r);r.b:GetScript('OnReceiveDrag')(r.b);r.b:GetScript('OnClick')(r.b,'LeftButton');r.run()
 check(r.equipped[20]==MAGE and #r.st.puts==2,'actual refusal+duplicate hook only one automatic swap')
 -- Hook installation twice cannot duplicate the posthook.
 r=setup();r.n.SwapHint:HookBagButtons();r.n.SwapHint:HookBagButtons();pick(r);r.b:GetScript('OnReceiveDrag')(r.b);r.run()
 check(r.equipped[20]==MAGE and #r.st.puts==2,'repeated hook install is idempotent')
 -- New held different item prevents deferred takeover.
 r=setup();pick(r);r.b:GetScript('OnReceiveDrag')(r.b);r.grab(1,1);r.run()
 check(r.equipped[20]==LINEN and #r.st.puts==1 and r.M.cursorItem==2589,'new cursor item preserved; deferred swap canceled')
 -- Relocating source before next frame cancels when no same-ID item is held.
 r=setup();pick(r);r.b:GetScript('OnReceiveDrag')(r.b)
 r.M.bags[2][2]=r.M.bags[1][2];r.M.bags[1][2]=nil;r.run()
 check(r.equipped[20]==LINEN and #r.st.puts==1,'source moved before next frame stops deferred swap')
 -- A newer same-ID drag must be treated like a newer different-ID drag, not swallowed.
 r=setup();r.M.put(2,3,bagItem(MAGE));pick(r);r.b:GetScript('OnReceiveDrag')(r.b)
 r.grab(2,3);r.M.fire('ITEM_LOCK_CHANGED',2,3);r.run()
 print('NEWER SAME-ID DRAG: equipped='..r.equipped[20]..' puts='..#r.st.puts..' cursor='..tostring(r.M.cursorItem)..' newerSource='..tostring(r.M.bags[2][3] and r.M.bags[2][3].id))
 -- (1.7.2-beta1, advisory B fixed: the auditor's check, turned back)
 check(r.equipped[20]==LINEN and #r.st.puts==1 and r.M.cursorItem==MAGE and r.st.cur and r.st.cur.bag==2 and r.st.cur.slot==3,'newer same-ID cursor belongs to player and cancels prior deferred swap')
 -- Two actual drops in one frame: only the newest matching drop should proceed.
 r=setup();r.M.put(2,3,bagItem(MAGE));local b2=blizzButton(r,1);r.n.SwapHint:HookBagButtons()
 pick(r);r.b:GetScript('OnReceiveDrag')(r.b)
 r.grab(2,3);r.M.fire('ITEM_LOCK_CHANGED',2,3);_G.GetMouseFoci=function()return {b2}end
 b2:GetScript('OnReceiveDrag')(b2);r.run()
 check(r.equipped[20]==LINEN and r.equipped[21]==MAGE and #r.st.puts==3,'newer actual drop generation supersedes old pending drop')
 _G.GetMouseFoci=nil
end)()
