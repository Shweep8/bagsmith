-- 1.7.0-beta13: the 1.7.0-beta12 audit's own probe (target/fitting_matrix.lua), its checks unchanged, kept in the suite. Evidence and the
-- report: docs/plugins/audit-1.7.0-beta12/.
local n={OnSignal=function()end, BAGS={0,1,2}, KEYRING=-2,db={makeRoomValue='vendor'},cdb={},items={},IsReagentBag=function()return false end}
local sizes={};local fams={[0]=0,[1]=1,[2]=2}
C_Container={GetContainerNumFreeSlots=function(b)return sizes[b] or 0,fams[b]end}
local info={[101]={stack=20,price=1,fam=1},[102]={stack=20,price=2,fam=2}}
C_Item={GetItemInfo=function(id)local e=info[id];return 'Item '..id,nil,1,nil,nil,nil,nil,e.stack,nil,nil,e.price end,GetItemFamily=function(id)return info[id].fam end}
local loot={}
GetNumLootItems=function()return #loot end
GetLootSlotType=function(i)return loot[i] and 1 or 0 end
GetLootSlotLink=function(i)return 'item:'..loot[i].id end
GetLootSlotInfo=function(i)local e=loot[i];return nil,'Item '..e.id,e.qty,nil,1 end
assert(loadfile('BagSmith/Core/MakeRoom.lua'))('BagSmith',n)
local MR=n.MakeRoom;MR.mode='loot'
local checks=0
local function ck(ok,msg)check(ok,msg);checks=checks+1 end
for same=0,1 do
 for ordinary=0,2 do for herb=0,2 do for ore=0,2 do
  for _,q1 in ipairs({1,19,20,21,40})do for _,q2 in ipairs({1,19,20,21,40})do
   for selected=1,2 do
    sizes={[0]=ordinary,[1]=herb,[2]=ore}
    n.items={};MR.ledger={};MR.slotItem={};MR.skipped={};MR.target=selected..':'..(selected==1 and 101 or (same==1 and 101 or 102))
    loot={{id=101,qty=q1},{id=same==1 and 101 or 102,qty=q2}}
    local left={[0]=ordinary,[1]=herb,[2]=ore};local room={};local expected={}
    -- Independent arithmetic capacity accounting, target first.
    for _,idx in ipairs({selected,3-selected})do
     local e=loot[idx];local family=info[e.id].fam
     local overflow=math.max(0,e.qty-(room[e.id] or 0));local need=math.ceil(overflow/20)
     if need<=left[0]+left[family] then
      local specialist=math.min(need,left[family]);left[family]=left[family]-specialist;left[0]=left[0]-(need-specialist)
      room[e.id]=(room[e.id] or 0)+need*20-e.qty
     else expected[idx]=true end
    end
    local w=MR:Waiting();local got={};local last=0
    for _,e in ipairs(w)do got[e.slot]=true;ck(e.slot>last,'waiting order remains original');last=e.slot end
    ck((got[1] or false)==(expected[1]or false) and (got[2]or false)==(expected[2]or false),'capacity matrix target order')
    -- A reserved entry cannot become the target even if higher valued or an explicit key matches it.
    local a={id=101,slot=1,values={vendor=1}};local r={reserved=true,id=102,slot=2,values={vendor=10000}}
    MR.target='2:102';ck(MR:Target({r,a})==a,'reserved never target')
   end
  end end
 end end end
end
print('FITTING ASSERTIONS',checks)
