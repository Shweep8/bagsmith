-- 1.7.1: the 1.7.1-beta4 audit's own probe (ui/message_locations.lua), unchanged. Evidence and the report:
-- docs/plugins/audit-1.7.1-beta4/.
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

-- Independent reporting matrix, sharing only the vendor's inventory simulation setup.
for _,mode in ipairs({'settled','old_locked','old_missing','old_cursor','foreign_cursor','refused_settled','refused_locked','refused_missing'}) do
 local refusing=mode:find('refused',1,true)
 local r=boot(refusing and {newBag=TINY,fullBag1=true} or {})
 local afterRefusal=false
 local actualInventory=GetInventoryItemID
 local delayEquip=false
 GetInventoryItemID=function(u,inv) if delayEquip and inv==20 then return LINEN end return actualInventory(u,inv) end
 local realPickup=C_Container.PickupContainerItem
 C_Container.PickupContainerItem=function(b,s) if mode=='old_cursor' and r.st.cur and r.st.cur.loose then return end return realPickup(b,s) end
 local realPut=PutItemInBag
 PutItemInBag=function(inv)
  realPut(inv)
  if mode=='old_missing' then r.M.bags[2][2]=nil end
  if mode=='old_cursor' then r.M.bags[2][2]=nil;r.M.cursorItem=LINEN;r.st.cur={id=LINEN,loose=true} end
  if mode=='foreign_cursor' then delayEquip=true;C_Timer.After(0,function() delayEquip=false;r.M.cursorItem=2589;r.st.cur={id=2589,loose=true} end) end
 end
 local realInfo=C_Container.GetContainerItemInfo
 C_Container.GetContainerItemInfo=function(b,s)
  local i=realInfo(b,s)
  if i and ((mode=='old_locked' and i.itemID==LINEN) or (mode=='refused_locked' and afterRefusal and b==2 and s==2 and i.itemID==TINY)) then i.isLocked=true end
  return i
 end
 local realClear=ClearCursor
 ClearCursor=function()
  local staged=r.st.cur and r.st.cur.bag==2
  realClear()
  if staged then afterRefusal=true end
  if mode=='refused_missing' and staged then r.M.bags[2][2]=nil end
 end
 r.grab();r.slot1:GetScript('OnReceiveDrag')(r.slot1);r.run()
 local log=r.log(); print(mode..': '..log)
 check(r.n.SwapHint.swapping==nil,mode..' terminates')
 if refusing then
  check(log:find("The game didn't swap the bags",1,true)~=nil,mode..' refusal')
  if mode=='refused_settled' then check(log:find('Tiny Pouch is in your Linen Bag now.',1,true)~=nil,mode..' settled location')
  else check(not log:find('Tiny Pouch is in your',1,true),mode..' no unconfirmed location') end
 else
  check(log:find('Swapped in Mageweave Bag',1,true)~=nil and not log:find("The game didn't swap",1,true),mode..' success not false refusal')
  if mode=='settled' or mode=='foreign_cursor' then check(log:find('Linen Bag is in your Linen Bag now.',1,true)~=nil,mode..' settled location')
  elseif mode=='old_cursor' then check(log:find('Linen Bag is on your cursor',1,true)~=nil,mode..' cursor location')
  else check(not log:find('Linen Bag is in your',1,true),mode..' no unconfirmed location') end
  if mode=='foreign_cursor' then check(r.M.cursorItem==2589,mode..' preserved') end
 end
end
end)()
