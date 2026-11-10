-- 1.6.0: the 1.6.0-beta11 audit's own probe (ui/bound_surface_probe.lua, its checks unchanged), kept in the suite. Evidence and the report:
-- docs/plugins/audit-1.6.0-beta11/.
-- (Run by the suite's runner, which has no AUDIT_CORE: the working copy's BagSmith. The only line added to the probe.)
AUDIT_CORE = AUDIT_CORE or "BagSmith"
-- Independent bound pricing surface lifecycle. Real Scanner, Buttons, headers, sorter, Entries, cache.
local configs=0
for _,skin in ipairs({'modern','classic'}) do
 package.loaded.mock=nil;local M=require('mock');local bound=false;local calls={}
 M.put(0,1,{id=7003,name='Tradeable Chest',q=3,count=1,class=4,subclass=2,price=2000,ilvl=45,equip='INVTYPE_CHEST'})
 M.put(0,2,{id=7013,name='Changing Chest',q=3,count=1,class=4,subclass=2,price=2000,ilvl=45,equip='INVTYPE_CHEST'})
 _G.BagSmithCharDB={version=1,firstSeen={}}
 _G.BagSmithDB={version=2,chars={},cache={},profiles={Default={skin=skin,view='list',grp='type',cols={'c','v','ah'},deEnabled=true,deLeveling='never'}}}
 _G.IsSpellKnown=function(id)return id==13262 end;_G.GetSpellInfo=function(id)if id==13262 then return 'Disenchant' end end
 _G.GetNumSkillLines=function()return 1 end;_G.GetSkillLineInfo=function()return 'Enchanting',false,nil,300,0,0,300 end
 _G.RegisterStateDriver=function()end;_G.UnregisterStateDriver=function()end;_G.InCombatLockdown=function()return false end
 local prices={[7003]=9000,[7013]=19000,[11177]=1000}
 local function price(v)local id=type(v)=='number' and v or tonumber(v:match('item:(%d+)'));calls[id]=(calls[id] or 0)+1;return prices[id] end
 _G.Auctionator={API={v1={GetAuctionPriceByItemLink=function(_,l)return price(l)end,GetAuctionPriceByItemID=function(_,id)return price(id)end}}}
 _G.BlackthornesTS_API={version=1,GetPrice=price}
 local real=C_Container.GetContainerItemInfo
 C_Container.GetContainerItemInfo=function(b,s)local i=real(b,s);if i and i.itemID==7013 then i.isBound=bound end;return i end
 local n=M.loadAddon(AUDIT_CORE or 'BagSmith');M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers();n.Window:Show();M.runTimers()
 local lanes={};local get=n.Buttons.GetLane;n.Buttons.GetLane=function(self,...)local h=get(self,...);lanes[h]=true;return h end
 for _,source in ipairs({'auctionator','blackthornes'})do
  n:Set('priceSource',source);M.runTimers()
  for _,state in ipairs({false,true,false,true})do
   bound=state;n:Scan();n:RefreshViews(true);M.runTimers();M.runTimers();calls={}
   local by={};for _,r in ipairs(n.items)do by[r.itemID]=r end
   local r=by[7013];local free=by[7003];local tag=skin..'/'..source..'/'..tostring(state);configs=configs+1
   check(r.isBound==state,tag..': Scanner refreshes bound state')
   check((state and n.AH:StackValue(r)==nil)or(not state and n.AH:StackValue(r)==19000),tag..': stack value')
   local b=n.Buttons:Get(0,2);check(b.colAH.text==(state and '' or n.Money(19000)),tag..': actual cell refreshes without stale value')
   local headers=0;for h in pairs(lanes)do if h:IsShown() and h.showAH and h.aAmt.text then headers=headers+1;check(h.aAmt.text==n.Money(state and 9000 or 28000),tag..': actual section aggregate excludes bound item')end end
   check(headers>0,tag..': observed header')
   local tip=0;n.AH:AddTooltipLines({AddLine=function()tip=tip+1 end,AddDoubleLine=function()tip=tip+1 end},r)
   check((state and tip==0)or(not state and tip>0),tag..': tooltip path')
   local sort=n:CurrentSorter({colSort={key='ah',dir='desc'}});local sorted={r,free};table.sort(sorted,sort)
   check(sorted[1]==(state and free or r),tag..': actual AH sorter excludes bound price')
   calls={};local entries=n.Disenchant:Entries();local e,f
   for _,x in ipairs(entries)do if x.itemID==7013 then e=x elseif x.itemID==7003 then f=x end end
   check(e and f and e.mats==f.mats and e.mats==1000,tag..': materials preserve market price')
   check(e and ((state and e.bound and e.ah==nil and e.verdict~='ah' and calls[7013]==nil)or(not state and not e.bound and e.ah==19000)),tag..': Entries bound suppression and no item provider call')
   n:SaveCache();local saved=BagSmithDB.cache[n:CharKey()];local cacheRec
   for _,x in ipairs(saved.items or {})do if x.itemID==7013 then cacheRec=x end end
   check(cacheRec and cacheRec.isBound==state,tag..': cached character preserves state')
   -- A direct market lookup remains available to consumers that price materials.
   check(n.AH:Price(r)==19000,tag..': Price remains raw market API')
  end
 end
end
print('BOUND_SURFACE_CONFIGURATIONS',configs)
