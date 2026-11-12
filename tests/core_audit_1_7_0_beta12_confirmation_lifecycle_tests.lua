-- 1.7.0-beta13: the 1.7.0-beta12 audit's own probe (target/confirmation_lifecycle.lua), its checks unchanged, kept in the suite. Evidence and the
-- report: docs/plugins/audit-1.7.0-beta12/.
;(function()
	-- ======== 1.7.0-beta10: the Loot Helper's layout (Shweep) ========
	-- What's waiting, the one it's making room for highlighted (click another to switch); one list of the ways to make
	-- room for it under "To make room for <loot>" (free ways first, then items to let go, a cost on the right); one
	-- button, with Protect beside it for an item to let go; a line saying what happens next. Offers are judged against
	-- that loot alone, and a slot you free goes to it first.
	local loot = {}
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("|Hitem:" .. loot[i].id .. ":0|h[" .. loot[i].name .. "]|h") end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, l.qty or 1, nil, l.q or 1 end end
	local looted = {}
	_G.LootSlot = function(i) looted[#looted + 1] = i end
	local deleted = 0
	-- Rough Gem 30c and Shiny Ring 5s wait; Small Egg 1c
	local INFO = { [9740] = { "Rough Gem", 1, 1, 30 }, [9741] = { "Shiny Ring", 2, 1, 500 }, [9742] = { "Small Egg", 1, 20, 1 },
		[9701] = { "Broken Fang", 0, 1, 3 }, [9702] = { "Linen Belt", 1, 1, 22 }, [9720] = { "Gnoll Paw", 1, 20, 2 },
		[9703] = { "Linen Cloth", 1, 20, 1 }, [9731] = { "Fine Ring", 1, 1, 80 }, [6265] = { "Soul Shard", 1, 1, 0 } }
	local function boot(stock, skin, prof, class)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return class or "Warrior", (class or "Warrior"):upper() end
		M.sizes[0] = 6
		for b = 1, 5 do M.sizes[b] = 0 end
		stock(M)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local pr = { skin = skin or "modern", makeRoom = true, makeRoomValue = "vendor", makeRoomAsk = false }
		for k, v in pairs(prof or {}) do pr[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = pr } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id)
			local num = tonumber(tostring(id):match("item:(%d+)")) or id
			local e = INFO[num]
			if e then return e[1], nil, e[2], nil, nil, nil, nil, e[3], nil, nil, e[4] end
			return realInfo(id)
		end
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id; M.cursorSlot = { bag, slot } end
		_G.ClearCursor = function() M.cursorItem = nil end
		_G.DeleteCursorItem = function() deleted = deleted + 1; local p = M.cursorSlot; if p then M.bags[p[1]][p[2]] = nil end; M.cursorItem = nil end
		_G.GetNumQuestLogEntries = function() return 0, 0 end
		return n, M
	end
	local function pack(M)
		M.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
		M.put(0, 2, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
		M.put(0, 3, { id = 9720, name = "Gnoll Paw", q = 1, count = 5, stack = 20, class = 15, subclass = 0, price = 2 })   -- 10c
		M.put(0, 4, { id = 9731, name = "Fine Ring", q = 1, class = 4, subclass = 0, price = 80, equip = "INVTYPE_FINGER" })
		M.put(0, 5, { id = 9703, name = "Linen Cloth", q = 1, count = 5, stack = 20, class = 7, subclass = 5, price = 1 })
		M.put(0, 6, { id = 9703, name = "Linen Cloth", q = 1, count = 7, stack = 20, class = 7, subclass = 5, price = 1 })
	end
	local function heads(f) local t = {}; for _, h in ipairs(f.heads) do if h:IsShown() then t[#t + 1] = h.text end end return table.concat(t, "|") end
	local function offered(f) local t = {}; for _, r in ipairs(f.destroyRows) do if r:IsShown() then t[#t + 1] = r.name.text end end return table.concat(t, ",") end
	local function rowNamed(f, name) for _, r in ipairs(f.destroyRows) do if r:IsShown() and r.name.text == name then return r end end end
	local function waitRow(f, name) for _, r in ipairs(f.waitRows) do if r:IsShown() and r.name.text == name then return r end end end
	local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
	local function topOf(fr) local p = fr.points[1]; return -(p[5] or p[3] or 0) end
	local function openLoot(M) M.fire("LOOT_CLOSED"); M.runTimers(); M.fire("LOOT_OPENED"); M.runTimers() end
 INFO[9731]={ 'Fine Ring',1,20,1 }
 local n,M=boot(function(M)
  pack(M)
  M.put(0,4,{id=9731,name='Fine Ring',q=1,count=20,stack=20,class=15,subclass=0,price=1})
  M.put(0,3,{id=9731,name='Fine Ring',q=1,count=19,stack=20,class=15,subclass=0,price=1})
 end,'modern',{makeRoomAsk=true})
 _G.LootFrame=CreateFrame('Frame','LootFrame',UIParent);LootFrame.GetRight=function()return 500 end;LootFrame.GetTop=function()return 700 end;LootFrame:Show()
 loot={{id=9731,name='Fine Ring',qty=1,q=1},{id=9741,name='Shiny Ring',q=2}}
 openLoot(M)
 local MR,f=n.MakeRoom,n.MakeRoom.frame
 local row
 for _,r in ipairs(f.destroyRows)do if r:IsShown() and r.name.text=='Fine Ring' and r.count.text=='20' then row=r end end
 check(row~=nil,'full old stack offered while incoming same item fits partial stack')
 row:GetScript('OnClick')(row);MR.actRun(f.act)
 local c=n.Popups.confirm
 check(c and c:IsShown() and c.onYes~=nil,'real confirmation open')
 -- Player replaces the partial stack with another item while offered full stack stays unchanged.
 M.put(0,3,{id=9702,name="Linen Belt",q=1,class=4,subclass=1,price=22})
 n:Scan()
 check(not c:IsShown() and c.onYes==nil,'bag scan removes newly waiting item row and clears confirmation callback')
 check(deleted==0,'no delete from confirmation invalidation')
 print('CONFIRMATION: normal ITEMS_CHANGED repaint fully mitigates direct old-offer observation')
 -- A new loot session closes an open confirmation too.
 M.put(0,3,{id=9731,name='Fine Ring',q=1,count=19,stack=20,class=15,subclass=0,price=1});n:Scan();M.runTimers();openLoot(M)
 row=nil;for _,r in ipairs(f.destroyRows)do if r:IsShown() and r.name.text=='Fine Ring' and r.count.text=='20' then row=r end end
 check(row~=nil,'old stack offered again')
 row:GetScript('OnClick')(row);MR.actRun(f.act);check(c:IsShown(),'confirmation reopened')
 M.fire('LOOT_CLOSED');check(not c:IsShown() and c.onYes==nil,'loot close clears confirmation callback')
end)()
