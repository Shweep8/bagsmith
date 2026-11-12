;(function()
 -- The 1.7.0-beta4 audit's probes/loot_safety.lua (docs/plugins/audit-1.7.0-beta4/), its scenarios kept and its checks
 -- turned round to the fixed behavior (1.7.0-beta5): on beta4 the shard scenario deleted the last shard despite a keep of
 -- one (F1), and the quest scenario destroyed Linen Cloth a quest asked for once the objective read failed (F2).
 package.loaded.mock=nil
 local M=require('mock')
 UnitClass=function() return 'Warlock','WARLOCK' end
 for b=1,5 do M.sizes[b]=0 end
 M.sizes[0]=3
 M.put(0,1,{id=6265,name='Soul Shard',q=1,count=1,stack=1,class=15,subclass=0,price=0})
 M.put(0,2,{id=6265,name='Soul Shard',q=1,count=1,stack=1,class=15,subclass=0,price=0})
 M.put(0,3,{id=2589,name='Linen Cloth',q=1,count=1,stack=20,class=7,subclass=5,price=1})
 BagSmithCharDB={version=1,firstSeen={}}
 BagSmithDB={version=2,chars={},cache={},profiles={Default={makeRoom=true,makeRoomValue='vendor',makeRoomAsk=false,shardKeep=1}}}
 local n=M.loadAddon('BagSmith')
 M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers(); M.runTimers()
 local MR=n.MakeRoom
 local deleted=0
 C_Container.PickupContainerItem=function(b,s) local i=M.bags[b][s]; M.cursorItem=i and i.id; M.cursorSlot={b,s} end
 ClearCursor=function() M.cursorItem=nil end
 DeleteCursorItem=function() deleted=deleted+1; local p=M.cursorSlot; M.bags[p[1]][p[2]]=nil; M.cursorItem=nil end
 MR:ShowShards()
 check(select(2,MR:Shards())==1,'initial allowance is one shard above keep=1')
 -- Ordinary bag removal/consumption while cleanup's scan throttle is active.
 n:NoteCleanup(); M.bags[0][2]=nil; M.fire('BAG_UPDATE_DELAYED')
 check(n.cleanupScanQueued and #n.items==3,'scan is pending with old item records')
 MR:DestroyNextShard(MR.frame.shard.go)
 check(deleted==0 and M.bags[0][1]~=nil,'FIXED: the last live shard is kept (keep=1), counted live before the delete')
 -- Ordinary material quest check: an objective read that fails keeps the protection the last good reading gave.
 n:Scan()
 local r; for _,v in ipairs(n.items) do if v.itemID==2589 then r=v end end
 MR.Waiting=function() return {{id=9999,values={vendor=100}}} end
 local o=MR:Offer(r,false,'priced',1)
 GetNumQuestLogEntries=function() return 1 end
 GetQuestLogTitle=function() return 'A Donation of Wool',10,0,false,false,false,0,123 end
 GetNumQuestLeaderBoards=function() return 1 end
 GetQuestLogLeaderBoard=function() return 'Linen Cloth: 1/20','item',false end
 local ok,why=MR:StillOk(o)
 check(not ok and why=='questneed','readable objective protects ordinary quest material')
 GetQuestLogLeaderBoard=function() error('objective temporarily unreadable') end
 ok,why=MR:StillOk(o)
 check(not ok and why=='questneed','FIXED: an objective read error keeps the last good reading; '..tostring(why))
 check(not MR:Destroy(o,true) and deleted==0,'FIXED: a confirmed old offer still destroys nothing while the objective cannot be read')
 GetNumQuestLogEntries,GetQuestLogTitle,GetNumQuestLeaderBoards,GetQuestLogLeaderBoard=nil,nil,nil,nil
end)()
