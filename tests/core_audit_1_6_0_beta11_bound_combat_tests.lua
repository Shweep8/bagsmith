-- 1.6.0: the 1.6.0-beta11 audit's own probe (independent/bound_combat_probe.lua, its checks unchanged), kept in the suite. Evidence and the report:
-- docs/plugins/audit-1.6.0-beta11/.
-- (Run by the suite's runner, which has no AUDIT_CORE: the working copy's BagSmith. The only line added to the probe.)
AUDIT_CORE = AUDIT_CORE or "BagSmith"
-- Independent beta11 adversarial binding transitions. Mock only; unmodified candidate.
local function boot(skin,rank,initialBound)
 package.loaded.mock=nil;local M=require('mock')
 for b=0,5 do M.sizes[b]=0 end;M.sizes[0]=2
 M.maxStack={[7001]=1,[7002]=1,[9001]=1}
 M.put(0,1,{id=7001,name='Sturdy Boots',q=2,count=1,class=4,subclass=1,price=500,ilvl=23,equip='INVTYPE_FEET'})
 M.put(0,2,{id=7002,name='Common Trinket',q=1,count=1,class=15,subclass=0,price=5})
 local state={bound=initialBound,lootBound=false,lootVendor=300,lootAH=1000000,prices={[7001]=600,[7002]=1000}}
 BagSmithCharDB={version=1,firstSeen={}};BagSmithDB={version=2,chars={},cache={},profiles={Default={skin=skin,deEnabled=true,deLeveling='never',makeRoom=true,makeRoomValue=rank,makeRoomAsk=true,priceSource='auctionator'}}}
 IsSpellKnown=function(id)return id==13262 end;GetSpellInfo=function(id)if id==13262 then return 'Disenchant' end end
 GetNumSkillLines=function()return 1 end;GetSkillLineInfo=function()return 'Enchanting',false,nil,150,0,0,300 end
 RegisterStateDriver=function()end;UnregisterStateDriver=function()end;UnitClass=function()return 'Warrior','WARRIOR'end
 local function idOf(v)return type(v)=='number' and v or tonumber(tostring(v):match('item:(%d+)'))end
 local function p(v)local id=idOf(v);return id==9001 and state.lootAH or state.prices[id] or 1000 end
 Auctionator={API={v1={GetAuctionPriceByItemLink=function(_,v)return p(v)end,GetAuctionPriceByItemID=function(_,v)return p(v)end}}}
 BlackthornesTS_API={version=1,GetPrice=p,GetPriceAge=function()return nil end}
 local real=C_Item.GetItemInfo
 C_Item.GetItemInfo=function(v)if idOf(v)==9001 then return 'Waiting Loot','item:9001',2,20,0,'Armor','Cloth',1,'INVTYPE_CHEST',1,state.lootVendor,4,1,state.lootBound and 1 or 2 end;return real(v)end
 local ci=C_Container.GetContainerItemInfo
 C_Container.GetContainerItemInfo=function(b,s)local i=ci(b,s);if i and i.itemID==(state.boundId or 7002) then i.isBound=state.bound end;return i end
 GetNumLootItems=function()return 1 end;GetLootSlotType=function()return 1 end;GetLootSlotLink=function()return '|Hitem:9001:0|h[Waiting Loot]|h'end
 GetLootSlotInfo=function()return 'icon','Waiting Loot',1,nil,2 end;LootSlot=function()M.lootRequested=true end
 C_Container.PickupContainerItem=function(b,s)local it=M.bags[b]and M.bags[b][s];M.cursorItem=it and it.id;M.cursorFrom={b,s}end
 ClearCursor=function()M.cursorItem=nil;M.cursorFrom=nil end
 DeleteCursorItem=function()if M.cursorFrom then M.bags[M.cursorFrom[1]][M.cursorFrom[2]]=nil end;M.cursorItem=nil;M.deleted=(M.deleted or 0)+1 end
 local n=M.loadAddon(AUDIT_CORE);M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers()
 M.fire('LOOT_OPENED');M.runTimers();M.runTimers()
 return n,M,state
end
local function armed(DE)local b=DE:Button();return b:GetAttribute('type')=='spell' and b:GetAttribute('target-slot')~=nil end
local function driver(M,DE,state)
 local b=DE:Button();local was=M.combat;M.combat=false
 local fn=assert(loadstring(b:GetAttribute('_onstate-bscombat')));setfenv(fn,{self=b,newstate=state});fn();M.combat=was
end
local function combat(M,DE,on)
 if not on then M.combat=false end;driver(M,DE,on and 'lock' or 'open');M.combat=on
 M.fire(on and 'PLAYER_REGEN_DISABLED' or 'PLAYER_REGEN_ENABLED');M.runTimers()
end
for _,skin in ipairs({'modern','classic'})do
 for _,route in ipairs({'open','closed','soft-closed','reopened'})do
  for _,lastBound in ipairs({false,true})do
   local n,M,S=boot(skin,'ah',false);local DE=n.Disenchant;DE:Show();M.runTimers();local f=DE.frame
   local tag=skin..' '..route..' '..tostring(lastBound);local blocked={}
   for fr,label in pairs({[f]='frame',[f.cur]='current',[DE:Button()]='secure button'})do
    fr.protected=true;fr.IsProtected=function(self)return self.protected end
    for _,method in ipairs({'Show','Hide','SetPoint','ClearAllPoints','SetSize','SetWidth','SetHeight','SetParent','StartMoving','StartSizing','StopMovingOrSizing','EnableMouse','SetAttribute'})do
     local old=fr[method]
     if old then fr[method]=function(self,...)if M.combat then blocked[#blocked+1]=label..' '..method end;return old(self,...)end end
    end
   end
   if route=='closed'then DE:Close()end
   combat(M,DE,true);check(not armed(DE),tag..' secure state-driver disarms entering combat')
   S.boundId=7001;S.bound=true;n:Scan();n:Fire('ITEMS_CHANGED')
   S.bound=false;n:Scan();n:Fire('ITEMS_CHANGED')
   n:Set('priceSource','blackthornes');S.prices[7001]=8200.005;n:Set('deMargin',.145)
   S.bound=lastBound;n:Scan();n:Fire('ITEMS_CHANGED')
   if route=='soft-closed' or route=='reopened'then DE:Close()end
   if route=='reopened'then DE:Show()end
   n:Set('skin',skin=='modern'and'classic'or'modern');DE:Paint();M.runTimers();M.runTimers()
   check(#blocked==0,tag..' no protected insecure mutation for binding/provider/skin updates '..table.concat(blocked,','))
   check(not armed(DE),tag..' updates do not rearm during combat')
   combat(M,DE,false)
   local expectedOpen=route=='open' or route=='reopened'
   check(f:IsShown()==expectedOpen and armed(DE)==expectedOpen,tag..' final visibility/arming reflects latest close state')
   DE:Show();M.runTimers();DE:Refresh()
   local found;for _,e in ipairs(DE.entries or {})do if e.itemID==7001 then found=e end end
   check(found and (not not found.bound)==lastBound,tag..' postcombat entries use latest bound state')
   check(found and (lastBound and found.ah==nil and found.verdict~='ah' or not lastBound and found.ah==8200.005),tag..' postcombat sale values use latest source and binding')
   check(not n.errorLog or #n.errorLog==0,tag..' no swallowed callback errors')
   DE:Close();check(not armed(DE),tag..' final close disarmed')
  end
 end
end
