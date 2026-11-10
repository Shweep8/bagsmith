-- 1.6.0: the 1.6.0-beta11 audit's own probe (independent/bound_lifecycle_probe.lua, its checks unchanged), kept in the suite. Evidence and the report:
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
local function pick(R,name)for _,r in ipairs(R.frame.destroyRows)do if r:IsShown() and r.name.text==name then r.onPick();return end end;error('missing '..name)end
local function click(R)R.frame.act:GetScript('OnClick')(R.frame.act)end
local function offer(R,id)
 local _,ds=R:Suggestions(R:Waiting());for _,d in ipairs(ds)do if d.rec.itemID==id then return R:Offer(d.rec,d.junk,d.noPrice and 'noprice' or 'priced',R:Rank(d.values))end end
end
for _,skin in ipairs({'modern','classic'})do
 for _,bound in ipairs({false,true})do
  local n,M,S=boot(skin,'ah',bound);local R=n.MakeRoom;local tag=skin..' bound='..tostring(bound)
  local o=offer(R,7002);check(o and R:StillOk(o),tag..' original offer valid')
  pick(R,'Common Trinket');click(R);local c=n.Popups.confirm;local stale=c.onYes
  check(c:IsShown() and stale,tag..' confirmation exists')
  S.bound=not bound
  local ok,why=R:StillOk(o);check(not ok and why=='price',tag..' live binding transition changes ranked value and rejects prior offer: '..tostring(why))
  stale();check(not M.deleted and M.bags[0][1] and M.bags[0][2],tag..' stale confirmed callback cannot delete after live binding change')
  n:Scan();n:Fire('ITEMS_CHANGED');M.runTimers();M.runTimers();R:Refresh()
  local fresh=offer(R,7002);check(fresh and fresh.value==(S.bound and 5 or 1000),tag..' fresh offer uses live binding price')
  check(R:Destroy(fresh,true) and M.deleted==1 and M.bags[0][1] and not M.bags[0][2],tag..' renewed action removes exactly new offered item')
 end
 -- Vendor ranking remains unchanged by binding: same exact item, same intended rank, same protection gates.
 for _,bound in ipairs({false,true})do
  local n,M,S=boot(skin,'vendor',bound);S.lootVendor=1000000;local R=n.MakeRoom;R:Refresh();local o=offer(R,7002)
  check(o and o.value==5 and R:StillOk(o),skin..' vendor original offer')
  S.bound=not bound;check(R:StillOk(o),skin..' vendor binding transition preserves exact value')
  n.Marks:ToggleFavorite(n.items[2]);local ok,why=R:StillOk(o)
  check(not ok and why=='favorite',skin..' binding does not bypass new favorite gate')
  check(not R:Destroy(o,true) and not M.deleted,skin..' final favorite protection prevents deletion')
 end
 -- Binding metadata for waiting loot arrives after an explicit selection and confirmation.
 local n,M,S=boot(skin,'ah',false);local R=n.MakeRoom
 pick(R,'Common Trinket');click(R);local c=n.Popups.confirm;local stale=c.onYes;local o=offer(R,7002)
 S.lootBound=true;R:Refresh()
 local w=R:Waiting()[1];check(w and w.values.bound=='bop' and w.values.ah==nil and R:Rank(w.values)==300,skin..' waiting BOP transition drops sale proceeds')
 check(R.chosen==nil and R.sel==nil and not R.selPicked and R.actRun==nil,skin..' new low-value BOP loot clears all offered choices')
 check(not c:IsShown() and c.onYes==nil,skin..' all offers disappearing clears pending confirmation')
 local ok,why=R:StillOk(o);check(not ok and why=='worth',skin..' live BOP change refuses previous value basis')
 stale();check(not M.deleted and M.bags[0][1]and M.bags[0][2],skin..' retained callback cannot delete for newly cheap BOP loot')
 S.lootBound=false;R:Refresh();check(R.chosen and R.chosen.label=='Destroy Sturdy Boots' and not R.selPicked,skin..' metadata recovery chooses cheapest, not old manual pick')
 -- Binding with no vendor price deliberately follows explicit no-price-confirmation path, never automatic deletion.
 S.lootBound=true;S.lootVendor=0;R:Refresh();local w0=R:Waiting()[1]
 check(w0.values.bound=='bop' and R:Rank(w0.values)==0,skin..' no-vendor BOP has no invented AH proceeds')
 pick(R,'Common Trinket');click(R);check(n.Popups.confirm:IsShown() and not M.deleted,skin..' no-price BOP still asks before destruction')
 S.lootVendor=300;R:Refresh();check(not n.Popups.confirm:IsShown()and not M.deleted,skin..' acquiring low vendor price cancels no-price offer')
end
