-- Independent beta9 deletion matrix. Models pickup as removing the bag record,
-- ClearCursor as restoring it, and real deletion as consuming held contents.
local function boot(ask)
 package.loaded.mock=nil
 local M=require('mock')
 UnitClass=function() return 'Warlock','WARLOCK' end
 for b=1,5 do M.sizes[b]=0 end
 M.sizes[0]=4
 for s=1,3 do M.put(0,s,{id=6265,name='Soul Shard',q=1,count=1,stack=1,class=15,subclass=0,price=0}) end
 M.put(0,4,{id=2589,name='Linen Cloth',q=1,count=5,stack=20,class=7,subclass=5,price=1})
 BagSmithCharDB={version=1,firstSeen={}}
 BagSmithDB={version=2,chars={},cache={},profiles={Default={makeRoom=true,makeRoomValue='vendor',makeRoomAsk=ask,shardKeep=1}}}
 local n=M.loadAddon('BagSmith')
 M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers(); M.runTimers()
 local state={mode='noop',deleted=0,called=0,restored=0,confirmations=0,said={}}
 C_Container.PickupContainerItem=function(b,s)
  assert(not state.held,'test pickup requires empty cursor')
  state.held=M.bags[b][s]; state.origin={b,s}; M.bags[b][s]=nil
  M.cursorItem=state.held and state.held.id
 end
 ClearCursor=function()
  if state.held then
   local p=state.origin; assert(M.bags[p[1]][p[2]]==nil,'original slot occupied')
   M.bags[p[1]][p[2]]=state.held; state.restored=state.restored+1
  end
  state.held=nil; M.cursorItem=nil
 end
 DeleteCursorItem=function()
  state.called=state.called+1
  if state.mode=='throw' then error('ADDON_ACTION_BLOCKED') end
  if state.mode=='success' then state.deleted=state.deleted+1; state.held=nil; M.cursorItem=nil end
 end
 GetNumQuestLogEntries=function() return 0,0 end
 GetQuestLogLeaderBoard=nil; C_QuestLog=nil
 n.Print=function(self,msg,...) state.said[#state.said+1]=select('#',...)>0 and msg:format(...) or tostring(msg) end
 n.Confirm=function(btn,msg,fn) state.confirmations=state.confirmations+1; state.confirm=fn end
 local MR=n.MakeRoom
 MR.Waiting=function() return {{id=9999,values={vendor=100}}} end
 local r; for _,v in ipairs(n.items) do if v.itemID==2589 then r=v end end
 local offer=MR:Offer(r,false,'priced',5)
 return n,M,MR,offer,state
end
for _,mode in ipairs({'noop','throw'}) do
 for _,ask in ipairs({false,true}) do
  local n,M,MR,o,s=boot(ask); s.mode=mode
  check(MR:StillOk(o),'setup valid offer')
  for attempt=1,2 do
   local ok,res=pcall(function() return MR:Destroy(o,true) end)
   check(ok and res==false,mode..' returns false without exception')
   check(M.bags[0][4] and M.bags[0][4].count==5 and not s.held and not M.cursorItem,mode..' restores full exact stack')
   check(s.deleted==0 and s.restored==attempt,mode..' repeated failure preserves all contents')
  end
  check(table.concat(s.said,'|'):find("back in your bags",1,true),mode..' explanatory message')
  s.mode='success'
  check(MR:Destroy(o,true)==true and M.bags[0][4]==nil and not M.cursorItem and s.deleted==1,'successful retry deletes once')
  check(MR:Destroy(o,true)==false and s.deleted==1,'repeated stale offer does not delete again')
 end
end
-- Confirmation remains mandatory; failed confirmed delete restores the stack.
do
 local n,M,MR,o,s=boot(true)
 check(MR:Destroy(o,false)==false and s.called==0,'unconfirmed direct call rejected')
 MR:TryDestroy(o,{},'Linen Cloth',5,'key',false)
 check(s.confirmations==1 and s.called==0,'TryDestroy asks before pickup')
 s.confirm()
 check(s.called==1 and M.bags[0][4]~=nil and not M.cursorItem,'confirmed failure restores stack')
end
-- Begin batch, successfully delete first, fail second, verify new batch requires
-- new confirmation and never crosses keep=1.
for _,mode in ipairs({'noop','throw'}) do
 local n,M,MR,o,s=boot(true); MR:ShowShards(); MR.shardQty=2
 MR:DestroyNextShard(MR.frame.shard.go)
 check(s.confirmations==1 and s.called==0,'shard batch initial confirmation')
 s.mode='success'; s.confirm(); n:Scan()
 check(s.deleted==1 and MR.shardBatch==1,'first successful shard consumes one batch step')
 s.mode=mode
 local ok=pcall(function() MR:DestroyNextShard(MR.frame.shard.go) end)
 check(ok and MR.shardBatch==nil,'midbatch '..mode..' ends batch safely')
 check(MR:LiveShards()==2 and not M.cursorItem and not s.held,'midbatch restores shard, keeps two')
 local calls=s.called; MR:DestroyNextShard(MR.frame.shard.go)
 check(s.confirmations==2 and s.called==calls,'restart after failure asks again')
 s.mode='success'; s.confirm(); n:Scan()
 check(s.deleted==2 and MR:LiveShards()==1 and MR.shardBatch==nil,'retry consumes one remaining allowed shard')
 MR:DestroyNextShard(MR.frame.shard.go)
 check(s.deleted==2 and MR:LiveShards()==1,'keep limit maintained')
end
-- First-click shard failure with Ask Before Destroying disabled also stops
-- without needing a scan to recover the contents.
for _,mode in ipairs({'noop','throw'}) do
 local n,M,MR,o,s=boot(false); MR:ShowShards(); MR.shardQty=2; s.mode=mode
 local ok=pcall(function() MR:DestroyNextShard(MR.frame.shard.go) end)
 check(ok and MR.shardBatch==nil and s.confirmations==0,'first shard '..mode..' safely stops without confirmation')
 check(MR:LiveShards()==3 and not M.cursorItem and s.deleted==0,'first shard '..mode..' restores exact live count')
 s.mode='success'; MR:DestroyNextShard(MR.frame.shard.go); n:Scan()
 check(MR:LiveShards()==2 and s.deleted==1 and MR.shardBatch==1,'retry after first failure starts clean batch')
end
