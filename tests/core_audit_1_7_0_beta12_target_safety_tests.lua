-- 1.7.0-beta13: the 1.7.0-beta12 audit's own probe (target/target_safety.lua), its checks unchanged, kept in the suite. Evidence and the
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
 local n,M=boot(pack)
 local MR=n.MakeRoom
 MR.mode='loot'
 local candidate=recOf(n,9731)
 loot={{id=9740,name='Rough Gem',q=1},{id=9741,name='Shiny Ring',q=2}}
 local offer=MR:Offer(candidate,false,'priced',80)
 local assertions=0
 local function ck(ok,msg) check(ok,msg);assertions=assertions+1 end
 -- Current target price, not any higher-price bystander, must justify deleting.
 for _,p1 in ipairs({0,1,79,80,81,500}) do
  for _,p2 in ipairs({0,1,79,80,81,500}) do
   INFO[9740][4]=p1;INFO[9741][4]=p2
   for _,selected in ipairs({false,'1:9740','2:9741'}) do
    MR.target=selected
    local wait=MR:Waiting();local target=MR:Target(wait)
    local expected=selected=='1:9740' and p1 or selected=='2:9741' and p2 or math.max(p1,p2)
    ck(target and target.values.vendor==expected,'target rank selection')
    local ok,why=MR:StillOk(offer)
    ck(ok==(expected>80),'priced offer accepted only for dearer target; actual '..tostring(why))
    local _,des=MR:Suggestions(wait,{target})
    local found=false;for _,d in ipairs(des) do if d.rec.itemID==9731 then found=true end end
    ck(found==(expected==0 or expected>80),'suggestion target threshold/no-price')
   end
  end
 end
 -- Rank setting and AH update: target and live rule follow current choice.
 INFO[9740][4]=30;INFO[9741][4]=500;MR.target='2:9741'
 ck(MR:StillOk(offer),'baseline 80<500')
 INFO[9741][4]=40;ck(not MR:StillOk(offer),'target price drop refuses')
 INFO[9741][4]=500
 MR.skipped['2:9741']=true;ck(not MR:StillOk(offer),'skip selected valuable target falls back to cheaper')
 MR.skipped={};MR:Never()[9741]=true;ck(not MR:StillOk(offer),'exclude selected valuable target falls back')
 MR:Never()[9741]=nil
 -- One slot released: explicit low-value target consumes it before valuable bystander.
 M.bags[0][1]=nil;n:Scan();MR.target='1:9740'
 local w=MR:Waiting();ck(#w==1 and w[1].id==9741,'selected low target gets free slot')
 MR.target='2:9741';w=MR:Waiting();ck(#w==1 and w[1].id==9740,'selected high target gets free slot')
 -- Reserved arrivals consume the only free slot; no new loot request while arrival outstanding.
 MR.ledger={[9742]={last=0,entries={{rem=1}},surplus=0,surplusToken=0}}
 w=MR:Waiting();ck(#w==2,'reservation consumes slot before target')
 MR.pending={[1]=true,[2]=true};looted={};MR:TryLoot();ck(#looted==0,'reserved arrival prevents new request')
 MR.ledger={};MR.request=nil;MR.lootTried={};MR.refused={};MR.target='2:9741'
 MR:TryLoot();ck(#looted==1 and looted[1]==2,'TryLoot requests fitting chosen target only')
 MR:TryLoot();ck(#looted==1,'request in flight blocks second loot')
 -- Two slots same loot ID: target keys remain distinct and no over-allocation.
 MR.request=nil;MR.ledger={};MR.pending={};MR.lootTried={}
 loot={{id=9741,name='Shiny Ring',q=2},{id=9741,name='Shiny Ring',q=2}}
 MR.target='2:9741';w=MR:Waiting();ck(#w==1 and w[1].slot==1,'duplicate loot ID selects exact slot')
 MR.target='1:9741';w=MR:Waiting();ck(#w==1 and w[1].slot==2,'duplicate opposite selection')
 -- Quest reward mode mirrors fitting, without loot slot keys.
 MR.mode='quest';MR.target='q:9740';MR.quest={kind='complete',rewards={{id=9740,name='Rough Gem',qty=1},{id=9741,name='Shiny Ring',qty=1}}}
 w=MR:Waiting();ck(#w==1 and w[1].id==9741,'quest selected reward gets free slot')
 -- Prior quest safety probes separately run; current target does not bypass new Protect.
 MR.mode='loot';MR.target='2:9741';M.put(0,1,{id=9701,name='Broken Fang',q=0,class=15,subclass=0,price=3});n:Scan()
 loot={{id=9740,name='Rough Gem',q=1},{id=9741,name='Shiny Ring',q=2}}
 MR:Protected()[9731]=true;local ok,why=MR:StillOk(offer);ck(not ok and why=='protected','target cannot bypass protected item')
 MR:Protected()[9731]=nil
 -- Observe stale offer of newly waiting item: general pre-existing final-check divergence.
 loot={{id=9731,name='Fine Ring',qty=2,q=1}}
 local _,des=MR:Suggestions(MR:Waiting(),{MR:Target(MR:Waiting())})
 local found=false;for _,d in ipairs(des)do if d.rec.itemID==9731 then found=true end end
 local ok,why=MR:StillOk(offer)
 print('OBSERVATION newly waiting candidate: offered='..tostring(found)..' old offer accepted='..tostring(ok)..' why='..tostring(why))
 print('TARGET ASSERTIONS',assertions)
end)()
