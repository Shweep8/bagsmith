-- 1.6.0: the 1.6.0-beta11 audit's own probe (independent/bop_confirmation_policy_probe.lua, its checks unchanged), kept in the suite. Evidence and the report:
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
 C_Container.GetContainerItemInfo=function(b,s)local i=ci(b,s);if i and i.itemID==7002 then i.isBound=state.bound end;return i end
 GetNumLootItems=function()return 1 end;GetLootSlotType=function()return 1 end;GetLootSlotLink=function()return '|Hitem:9001:0|h[Waiting Loot]|h'end
 GetLootSlotInfo=function()return 'icon','Waiting Loot',1,nil,2 end;LootSlot=function()M.lootRequested=true end
 C_Container.PickupContainerItem=function(b,s)local it=M.bags[b]and M.bags[b][s];M.cursorItem=it and it.id;M.cursorFrom={b,s}end
 ClearCursor=function()M.cursorItem=nil;M.cursorFrom=nil end
 DeleteCursorItem=function()if M.cursorFrom then M.bags[M.cursorFrom[1]][M.cursorFrom[2]]=nil end;M.cursorItem=nil;M.deleted=(M.deleted or 0)+1 end
 local n=M.loadAddon(AUDIT_CORE);M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers()
 M.fire('LOOT_OPENED');M.runTimers();M.runTimers()
 return n,M,state
end

-- Record the existing settings-driven policy, not an unconditional confirmation requirement.
for _,skin in ipairs({'modern','classic'})do
 local n,M,S=boot(skin,'ah',false);local R=n.MakeRoom
 n:Set('makeRoomAsk',false);S.lootBound=true;S.lootVendor=0;R:Refresh()
 local w=R:Waiting()[1]
 check(w.values.bound=='bop' and R:Rank(w.values)==0,skin..' BOP waiting loot is unpriced')
 check(R.chosen and R.chosen.label=='Destroy Sturdy Boots',skin..' default chooses the green Boots')
 R.frame.act:GetScript('OnClick')(R.frame.act)
 check(M.deleted==1 and not M.bags[0][1] and M.bags[0][2],skin..' Ask Before Destroying off: explicit action deletes nonrare Boots without another question')
 check(not n.Popups.confirm or not n.Popups.confirm:IsShown(),skin..' no extra confirmation is promised by the setting')
 print('POLICY',skin,'unpriced BOP','ask=false','candidate=green Boots','one explicit click','destroyed='..tostring(M.deleted))
end
