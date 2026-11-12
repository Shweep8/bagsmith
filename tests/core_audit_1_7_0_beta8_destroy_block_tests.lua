-- The 1.7.0-beta8 audit's destroy_block_probe.lua, its checks turned round to the fixed behavior (1.7.0-beta9, A1 and
-- F1): each changed check is marked; the scenarios and the control are as delivered.
package.loaded.mock=nil
local M=require('mock')
UnitClass=function() return 'Warlock','WARLOCK' end
for b=1,5 do M.sizes[b]=0 end
M.sizes[0]=3
M.put(0,1,{id=6265,name='Soul Shard',q=1,count=1,stack=1,class=15,subclass=0,price=0})
M.put(0,2,{id=6265,name='Soul Shard',q=1,count=1,stack=1,class=15,subclass=0,price=0})
M.put(0,3,{id=2589,name='Linen Cloth',q=1,count=1,stack=20,class=7,subclass=5,price=1})
BagSmithCharDB={version=1,firstSeen={}}
BagSmithDB={version=2,chars={},cache={},profiles={Default={makeRoom=true,makeRoomValue='vendor',makeRoomAsk=false,shardKeep=0}}}
local n=M.loadAddon('BagSmith')
M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers(); M.runTimers()
local MR=n.MakeRoom
local clears,deletes=0,0
C_Container.PickupContainerItem=function(b,s) local i=M.bags[b][s]; M.cursorItem=i and i.id; M.cursorSlot={b,s} end
ClearCursor=function() clears=clears+1; M.cursorItem=nil end
GetNumQuestLogEntries=function() return 0,0 end
GetQuestLogLeaderBoard=nil; C_QuestLog=nil
MR.Waiting=function() return {{id=9999,values={vendor=100}}} end
local r; for _,v in ipairs(n.items) do if v.itemID==2589 then r=v end end
local o=MR:Offer(r,false,'priced',1)
check(MR:StillOk(o),'setup: offer valid')
DeleteCursorItem=function() deletes=deletes+1 end
local ok,result=pcall(function() return MR:Destroy(o,true) end)
print('silent block: pcall='..tostring(ok)..', returned='..tostring(result)..', cursor='..tostring(M.cursorItem)..', clears='..clears..', item remains='..tostring(M.bags[0][3]~=nil))
check(ok and result==false and M.cursorItem==nil and clears>=1 and M.bags[0][3]~=nil,'fixed: a silent refusal reports failure and puts the item back')   -- (1.7.0-beta9, turned round)
ClearCursor(); clears=0
DeleteCursorItem=function() error('ADDON_ACTION_BLOCKED') end
ok,result=pcall(function() return MR:Destroy(o,true) end)
print('throw block: pcall='..tostring(ok)..', cursor='..tostring(M.cursorItem)..', clears='..clears)
check(ok and result==false and M.cursorItem==nil and M.bags[0][3]~=nil,'fixed: an error is caught, the item put back')   -- (1.7.0-beta9, turned round)
ClearCursor(); clears=0
DeleteCursorItem=function() deletes=deletes+1 end
MR:ShowShards(); MR.shardQty=2
MR:DestroyNextShard(MR.frame.shard.go)
print('shard silent block: batch='..tostring(MR.shardBatch)..', cursor='..tostring(M.cursorItem)..', item remains='..tostring(M.bags[0][1]~=nil))
check(MR.shardBatch==nil and M.cursorItem==nil and M.bags[0][1]~=nil,'fixed: a refused shard delete ends the batch and puts the shard back')   -- (1.7.0-beta9, turned round)
ClearCursor()
DeleteCursorItem=function() local p=M.cursorSlot; M.bags[p[1]][p[2]]=nil; M.cursorItem=nil end
MR:DestroyNextShard(MR.frame.shard.go)
check(M.bags[0][1]==nil and M.cursorItem==nil,'control: successful delete clears cursor')
-- Optional modern API diagnostic counts nonpositive IDs as IDs, unlike actual reader.
C_QuestLog={GetNumQuestLogEntries=function() return 2 end, GetInfo=function(i) return {title='Q'..i,isHeader=false,questID=i==1 and 0 or -1} end}
local said={}; n.Print=function(self,msg,...) said[#said+1]=select('#',...)>0 and msg:format(...) or tostring(msg) end
SlashCmdList.BAGSMITH('questlog')
print(table.concat(said,'\n'))
check(table.concat(said,'\n'):find('C_QuestLog lists 2 quests, 0 with an ID.',1,true),'fixed: the diagnostic counts only positive IDs')   -- (1.7.0-beta9, turned round)
