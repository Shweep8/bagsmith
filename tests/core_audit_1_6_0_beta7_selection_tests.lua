-- 1.6.0-beta8: the 1.6.0-beta7 audit's own probe (independent/selection_fault_extension.lua, unchanged), kept in the suite. Evidence and the report:
-- docs/plugins/audit-1.6.0-beta7/.
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


-- Independent beta7 extension. This is additive test code; shipped product code is not modified.
local function act(R) R.frame.act:GetScript('OnClick')(R.frame.act) end
local function rowFor(R,name) for _,r in ipairs(R.frame.destroyRows) do if r:IsShown() and r.name.text==name then return r end end end
local function useProfile(n,rank)
 local raw=n.Copy(n.db);raw.makeRoomValue=rank
 local p=n.Profiles:Import('Probe '..rank,raw);n.Profiles:Use(p)
end
local function priceControl(prices)
 local function p(v)local id=type(v)=='number' and v or tonumber(tostring(v):match('item:(%d+)')); return prices[id] end
 Auctionator.API.v1.GetAuctionPriceByItemLink=function(c,v)return p(v)end
 Auctionator.API.v1.GetAuctionPriceByItemID=function(c,v)return p(v)end
end
for _,skin in ipairs({'modern','classic'}) do
 for _,pick in ipairs({false,true}) do
  for _,from in ipairs({'ah','vendor'}) do
   local n,M=boot(skin);local R=n.MakeRoom;n:Set('makeRoomValue',from)
   if pick then rowFor(R,from=='ah' and 'Common Trinket' or 'Sturdy Boots').onPick() end
   n:Set('makeRoomAsk',true);act(R)
   local c=n.Popups.confirm;check(c and c:IsShown(),skin..' pending question opens')
   useProfile(n,from=='ah' and 'vendor' or 'ah');M.runTimers()
   local expected=from=='ah' and 'Common Trinket' or 'Sturdy Boots'
   check(not c:IsShown() and c.onYes==nil,skin..' profile drops old pending question')
   check(R.chosen.row.name.text==expected and not R.selPicked,skin..' profile basis change clears '..tostring(pick)..' pick '..from)
   act(R);check(c:IsShown(),skin..' replacement question opens')
   c.yes:GetScript('OnClick')(c.yes)
   check(M.bags[0][expected=='Sturdy Boots' and 1 or 2]==nil and M.bags[0][expected=='Sturdy Boots' and 2 or 1]~=nil,skin..' confirmation deletes newly named item only')
  end
 end
 -- Same basis profiles preserve a manual choice, unlike rank or effective source changes.
 do local n,M=boot(skin);local R=n.MakeRoom;rowFor(R,'Common Trinket').onPick();useProfile(n,'ah');M.runTimers()
  check(R.chosen.row.name.text=='Common Trinket' and R.selPicked,skin..' same basis profile preserves manual pick')
 end
 -- An available source disappearing, then arriving again, changes effective basis without direct rank-setting changes.
 for _,pick in ipairs({false,true}) do
  local n,M=boot(skin);local R=n.MakeRoom
  if pick then rowFor(R,'Common Trinket').onPick() end
  local savedA=Auctionator;Auctionator=nil;n.AH:CheckSource();M.runTimers()
  check(R.chosen.row.name.text=='Common Trinket' and not R.selPicked,skin..' effective fallback resets pick')
  BlackthornesTS_API=nil;n.AH:CheckSource();M.runTimers()
  check(R.chosen.row.name.text=='Common Trinket' and R.frame.foot.text=='Ranked by vendor price',skin..' no providers uses vendor ordering')
  Auctionator=savedA;M.fire('ADDON_LOADED','Auctionator');M.runTimers()
  check(R.chosen.row.name.text=='Sturdy Boots' and not R.selPicked,skin..' provider late load reselects cheapest')
 end
 -- A fresh scan can promote or demote the default, but an explicit choice stays if still offered.
 for _,pick in ipairs({false,true}) do
  local n,M=boot(skin);local R=n.MakeRoom
  if pick then rowFor(R,'Sturdy Boots').onPick() end
  local prices={[7001]=600,[7002]=100,[9001]=1000000};priceControl(prices);R:Refresh()
  check(R.chosen.row.name.text==(pick and 'Sturdy Boots' or 'Common Trinket'),skin..' fresh-scan repaint honors automatic/manual distinction')
  prices[7001]=2000000;R:Refresh()
  check(R.chosen.row.name.text=='Common Trinket' and not R.selPicked,skin..' ineligible picked row resets selection')
  prices[7001]=600;R:Refresh()
  check(R.chosen.row.name.text=='Common Trinket',skin..' returning more costly row does not resurrect manual selection')
 end
 -- Fault arrives after the displayed offer, including after the confirmation question.
 for _,confirm in ipairs({false,true}) do
  for _,mode in ipairs({'throws','knownquest','ordinary','absent'}) do
   local n,M=boot(skin);local R=n.MakeRoom
   if confirm then n:Set('makeRoomAsk',true);act(R);check(n.Popups.confirm:IsShown(),skin..' fault setup confirmation') end
   if mode=='throws' then C_Container.GetContainerItemQuestInfo=function()error('AUDIT transient final quest read failure')end
   elseif mode=='knownquest' then M.bags[0][1].quest=true
   elseif mode=='absent' then C_Container.GetContainerItemQuestInfo=nil end
   if confirm then local c=n.Popups.confirm;c.yes:GetScript('OnClick')(c.yes) else act(R) end
   local keep=mode=='throws' or mode=='knownquest'
   check((M.bags[0][1]~=nil)==keep,skin..' '..mode..' final check confirmed='..tostring(confirm))
   if mode=='throws' then
    C_Container.GetContainerItemQuestInfo=function()return {isQuestItem=false}end
    R:Refresh();act(R)
    if confirm then local c=n.Popups.confirm;c.yes:GetScript('OnClick')(c.yes) end
    check(M.bags[0][1]==nil,skin..' transient read can recover after fresh user action')
   end
  end
 end
 -- Junk's no-confirmation path still uses the final quest guard.
 do local n,M=boot(skin);local R=n.MakeRoom
  n.Junk.IsJunk=function(self,r)return r.itemID==7001 end;R:Refresh()
  check(R.chosen.row.name.text=='Sturdy Boots',skin..' junk setup')
  C_Container.GetContainerItemQuestInfo=function()error('AUDIT junk quest status failure')end
  act(R);check(M.bags[0][1]~=nil and not M.deleted,skin..' junk is not exempt from quest read error')
 end
end
