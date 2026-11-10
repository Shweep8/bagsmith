-- 1.6.0-beta9: the 1.6.0-beta8 audit's own probe (independent/selection_lifecycle_beta8.lua, unchanged), kept in the suite. Evidence and the report:
-- docs/plugins/audit-1.6.0-beta8/.
-- Independent release audit. Run from the unmodified candidate repository with tools/run_tests.py.
-- This file intentionally fails unmet requirements; it never invokes native inventory APIs.
local function boot(skin)
 package.loaded.mock=nil
 local M=require('mock')
 for b=0,5 do M.sizes[b]=0 end; M.sizes[0]=2
 M.maxStack={[7001]=1,[7002]=1,[9001]=1}
 M.put(0,1,{id=7001,name='Sturdy Boots',q=2,count=1,class=4,subclass=1,price=500,ilvl=23,equip='INVTYPE_FEET'})
 M.put(0,2,{id=7002,name='Common Trinket',q=1,count=1,class=15,subclass=0,price=5})
 _G.BagSmithCharDB={version=1,firstSeen={}}
 _G.BagSmithDB={version=2,chars={},cache={},profiles={Default={skin=skin,deEnabled=true,makeRoom=true,priceSource='auctionator',makeRoomValue='ah'},Other={skin=skin,deEnabled=true,makeRoom=true,priceSource='blackthornes',makeRoomValue='ah'}}}
 _G.IsSpellKnown=function(id) return id==13262 end
 _G.GetNumSkillLines=function() return 1 end
 _G.GetSkillLineInfo=function() return 'Enchanting',false,nil,150 end
 _G.RegisterStateDriver=function() end; _G.UnregisterStateDriver=function() end
 _G.UnitClass=function() return 'Warrior','WARRIOR' end
 local function idOf(v) return type(v)=='number' and v or tonumber(tostring(v):match('item:(%d+)')) end
 local function ap(v) local id=idOf(v); if id==7001 then return 600 elseif id==7002 then return 1000 elseif id==9001 then return 1000000 else return 10000 end end
 local function bp(v) local id=idOf(v); if id==7001 then return 100000 elseif id==7002 then return 1 elseif id==9001 then return 1000000 else return 10 end end
 _G.Auctionator={API={v1={GetAuctionPriceByItemLink=function(c,l) return ap(l) end,GetAuctionPriceByItemID=function(c,id) return ap(id) end}}}
 _G.BlackthornesTS_API={version=1,GetPrice=bp,GetPriceAge=function() return nil end}
 local real=C_Item.GetItemInfo
 C_Item.GetItemInfo=function(v) if idOf(v)==9001 then return 'Waiting Loot','item:9001',1,1,0,'Misc','Misc',1,'',1,1000000,15,0 end; return real(v) end
 _G.GetNumLootItems=function() return 1 end
 _G.GetLootSlotType=function() return 1 end
 _G.GetLootSlotLink=function() return '|Hitem:9001:0|h[Waiting Loot]|h' end
 _G.GetLootSlotInfo=function() return 'icon','Waiting Loot',1,nil,1 end
 _G.LootSlot=function() M.lootRequested=true end
 C_Container.PickupContainerItem=function(bag,slot) local it=M.bags[bag] and M.bags[bag][slot]; M.cursorItem=it and it.id; M.cursorFrom={bag,slot} end
 _G.ClearCursor=function() M.cursorItem=nil; M.cursorFrom=nil end
 _G.DeleteCursorItem=function() if M.cursorFrom then M.bags[M.cursorFrom[1]][M.cursorFrom[2]]=nil end; M.cursorItem=nil; M.deleted=(M.deleted or 0)+1 end
 local n=M.loadAddon(AUDIT_CORE or 'BagSmith')
 M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers(); M.runTimers()
 n.Disenchant:Show(); M.runTimers()
 M.fire('LOOT_OPENED'); M.runTimers(); M.runTimers()
 return n,M
end
local function firstShown(rows) for _,r in ipairs(rows or {}) do if r:IsShown() then return r.name.text,r.value.text end end end


-- beta8 independent A1 extension: two skins, complete/partial removal, confirmation/no-confirmation, real reset events.
local function pick(R,name)for _,r in ipairs(R.frame.destroyRows)do if r:IsShown() and r.name.text==name then r.onPick();return end end;error('missing '..name)end
local function click(R)R.frame.act:GetScript('OnClick')(R.frame.act)end
for _,skin in ipairs({'modern','classic'})do
 for _,cause in ipairs({'favorites','price','fullreplacement'})do
  for _,confirm in ipairs({false,true})do
   local n,M=boot(skin);local R=n.MakeRoom
   pick(R,'Common Trinket');n:Set('makeRoomAsk',confirm)
   if confirm then click(R);check(n.Popups.confirm:IsShown(),skin..cause..' question shown')end
   local prices,oldItems
   if cause=='favorites'then
    for _,r in ipairs(n.items)do if r.itemID==7001 or r.itemID==7002 then n.Marks:ToggleFavorite(r)end end
    n:Fire('ITEMS_CHANGED')
   elseif cause=='price'then
    local old=Auctionator.API.v1.GetAuctionPriceByItemID;prices={link=Auctionator.API.v1.GetAuctionPriceByItemLink,id=old}
    local function p(v)local id=type(v)=='number' and v or tonumber(v:match('item:(%d+)'));return id==9001 and 1 or (id==7001 and 600 or 1000)end
    Auctionator.API.v1.GetAuctionPriceByItemLink=function(_,v)return p(v)end;Auctionator.API.v1.GetAuctionPriceByItemID=function(_,v)return p(v)end;R:Refresh()
   else oldItems=n.items;n.items={};R:Refresh()end
   check(R.chosen==nil and R.sel==nil and not R.selPicked and R.actRun==nil,skin..cause..' all options disappear: full reset')
   check(not R.frame.act:IsShown(),skin..cause..' empty action hidden')
   if confirm then local c=n.Popups.confirm;check(not c:IsShown() and c.onYes==nil,skin..cause..' pending confirmation invalidated');c.yes:GetScript('OnClick')(c.yes);check(not M.deleted,skin..cause..' stale Yes cannot delete')end
   if cause=='favorites'then
    for _,r in ipairs(n.items)do if r.itemID==7001 or r.itemID==7002 then n.Marks:ToggleFavorite(r)end end;n:Fire('ITEMS_CHANGED')
   elseif cause=='price'then Auctionator.API.v1.GetAuctionPriceByItemLink=prices.link;Auctionator.API.v1.GetAuctionPriceByItemID=prices.id;R:Refresh()
   else n.items=oldItems;R:Refresh()end
   check(R.chosen and R.chosen.label=='Destroy Sturdy Boots' and not R.selPicked,skin..cause..' reappearance chooses cheapest')
   click(R);if confirm then local c=n.Popups.confirm;c.yes:GetScript('OnClick')(c.yes)end
   check(M.bags[0][1]==nil and M.bags[0][2]~=nil and M.deleted==1,skin..cause..' deletes only newly displayed Boots')
  end
 end
 for _,event in ipairs({'LOOT_OPENED','LOOT_CLOSED','QUEST_DETAIL','QUEST_COMPLETE'})do
  local n,M=boot(skin);local R=n.MakeRoom;pick(R,'Common Trinket');n:Set('makeRoomAsk',true);click(R)
  local c=n.Popups.confirm;local stale=R.actRun;local token=R.offerToken
  M.fire(event)
  check(R.sel==nil and not R.selPicked and R.offerToken~=token,skin..event..' clears pick synchronously')
  check(not c:IsShown() and c.onYes==nil,skin..event..' clears confirmation synchronously')
  n:Set('makeRoomAsk',false);stale(R.frame.act)
  if c:IsShown()then c.yes:GetScript('OnClick')(c.yes)end
  check(not M.deleted and M.bags[0][1] and M.bags[0][2],skin..event..' previous action cannot destroy across token change')
  M.runTimers();M.runTimers();R:Refresh()
  check(not R.selPicked,skin..event..' queued work does not restore manual pick')
 end
end
