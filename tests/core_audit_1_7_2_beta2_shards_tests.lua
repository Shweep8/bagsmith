-- 1.7.2: the 1.7.2-beta2 audit's own probe (evidence/shards.lua), unchanged. Evidence and the report:
-- docs/plugins/audit-1.7.2-beta2/.
;(function()
package.loaded.mock = nil
local M = require('mock')
M.maxStack={ [6265]=1, [9999]=1 }
for s=1,5 do M.put(0,s,{id=6265,name='Soul Shard',q=1,count=1,class=15,subclass=0,price=0}) end
for s=6,7 do M.put(0,s,{id=9999,name='Lockbox',q=1,count=1,class=15,subclass=0,price=0}) end
BagSmithCharDB={version=1,firstSeen={}}
BagSmithDB={version=2,chars={},cache={},profiles={Default={skin='modern',mergeStacks=true}}}
local n=M.loadAddon('BagSmith')
M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers(); M.runTimers()
n.Window:Show(); M.runTimers(); M.runTimers()
local v=n.Window.main
local rows,total=v:Filtered()
local shard, boxes
boxes=0
for _,r in ipairs(rows) do if r.itemID==6265 then check(not shard,'one shard row'); shard=r elseif r.itemID==9999 then boxes=boxes+1 end end
check(shard and shard.count==5 and shard.stacks==5 and #shard.members==5,'five unstackable shards merge with complete membership')
check(boxes==2,'other unstackable items remain separate')
n:Set('mergeStacks',false); M.runTimers()
rows=v:Filtered(); local c=0; for _,r in ipairs(rows) do if r.itemID==6265 then c=c+1 end end
check(c==5,'turning merge off restores all shard slots')
n:Set('mergeStacks',true); M.runTimers()
M.bags[0][2]=nil; n:Scan(); M.runTimers(); rows=v:Filtered()
for _,r in ipairs(rows) do if r.itemID==6265 then check(r.count==4 and #r.members==4,'consuming shard updates total/membership') end end
-- Boundary probe: bank transfers are suppressed even if the client's first move succeeded.
local calls=0; local orig=n.Drop.MoveRestJob
n.Drop.MoveRestJob=function(...) calls=calls+1 end
for _,where in ipairs({'bank','mail','trade'}) do n.Drop:MoveRest({itemID=6265,where=where,members={{bag=0,slot=1},{bag=0,slot=3}}}) end
check(calls==0,'shard follow-up blocked in bank/mail/trade')
n.Drop:MoveRest({itemID=9999,where='bank',members={}})
check(calls==1,'non-shard bank job unaffected')
n.Drop.MoveRestJob=orig
print('INDEPENDENT SHARD CHECKS COMPLETE')

end)()
