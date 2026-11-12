-- 1.7.0-beta14: the 1.7.0-beta13 audit's own probe (drop/tidy_error_ownership.lua), its observed-residual checks turned round to the
-- fixed behavior, each marked; the scenarios and the controls are as delivered. Evidence and the report:
-- docs/plugins/audit-1.7.0-beta13/.
-- Independent beta13 fault/cursor ownership probe.
local function scenario(cancel,newID,throwRead)
 package.loaded.mock=nil
 local M=require('mock')
 for b=1,5 do M.sizes[b]=0 end; M.sizes[0]=3
 for s,c in ipairs({19,11,4}) do M.put(0,s,{id=2589,name='Linen Cloth',q=1,count=c,stack=20,class=7,subclass=5,price=1}) end
 BagSmithCharDB={version=1,firstSeen={}}; BagSmithDB={version=2,chars={},cache={},profiles={Default={}}}
 local n=M.loadAddon('BagSmith'); M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers(); M.runTimers()
 local D=n.Drop; local timers={}; C_Timer.After=function(_,f) timers[#timers+1]=f end
 local held,allowed,done,clears,moves=nil,true,0,0,0
 ClearCursor=function() clears=clears+1; held=nil; M.cursorItem=nil end
 C_Container.SplitContainerItem=function(b,s,a) held={slot=s,n=a}; M.cursorItem=2589 end
 C_Container.PickupContainerItem=function(b,s)
  M.bags[b][s].count=M.bags[b][s].count+held.n; M.bags[b][held.slot].count=M.bags[b][held.slot].count-held.n
  held=nil; M.cursorItem=nil; moves=moves+1
 end
 D:TidyStacks(2589,'Linen Cloth',{{bag=0,slot=1},{bag=0,slot=2},{bag=0,slot=3}},function() return allowed and not M.cursorItem end,function(failed) done=done+1 end)
 check(moves==1 and not M.cursorItem,'setup: own move successfully placed before timer')
 -- User starts a different gesture during the timer gap (possibly same item ID).
 M.cursorItem=newID
 if cancel then allowed=false end
 local real=C_Container.GetContainerItemInfo
 if throwRead then C_Container.GetContainerItemInfo=function() error('synthetic delayed bag-read error') end end
 local ok,err=pcall(function() for tick=1,20 do local ts=timers; timers={}; for _,f in ipairs(ts) do f() end end end)
 print(('cancel=%s newID=%s throw=%s -> ok=%s cursor=%s clears=%d done=%d moves=%d'):format(tostring(cancel),tostring(newID),tostring(throwRead),tostring(ok),tostring(M.cursorItem),clears,done,moves))
 check(ok and done==1 and moves==1,'one completion, no further item moves')
 if throwRead and newID==2589 then
  -- (1.7.0-beta14, R1: turned round to the fixed behavior) the player's same-item stack is left on the cursor
  check(M.cursorItem==newID and clears==0,'fixed: a new same-ID user cursor is left alone by the old job')
 else
  check(M.cursorItem==newID and clears==0,'control: user cursor preserved')
 end
end
scenario(false,2589,false)
scenario(true,2589,false)
scenario(false,2835,true)
scenario(true,2835,true)
scenario(false,2589,true)
scenario(true,2589,true)
