-- 1.7.0-beta13: the 1.7.0-beta12 audit's own probe (drop/tidy_matrix.lua), its checks unchanged, kept in the suite. Evidence and the
-- report: docs/plugins/audit-1.7.0-beta12/.
package.loaded.mock=nil
local M=require('mock')
BagSmithCharDB={version=1,firstSeen={}}
BagSmithDB={version=2,chars={},cache={},profiles={Default={}}}
local n=M.loadAddon('BagSmith'); M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers(); M.runTimers()
local D=n.Drop
local function scenario(counts,locked,stopAfter,refuse,delay)
 local jobs={}; C_Timer.After=function(dt,fn) jobs[#jobs+1]=fn end
 M.bags[0]={}; M.cursorItem=nil
 local original,total=0,0
 local slots={}
 for i,c in ipairs(counts) do M.put(0,i,{id=2589,name='Linen Cloth',q=1,count=c,stack=20,class=7,subclass=5,price=1}); M.bags[0][i].locked=locked and locked[i] or nil; slots[i]={bag=0,slot=i}; original=original+c end
 local held,moves,done,allowed,clears=nil,0,0,true,0
 local function unlock(it,ticks)
  if ticks==0 then if it then it.locked=nil end else C_Timer.After(0,function() unlock(it,ticks-1) end) end
 end
 ClearCursor=function()
  clears=clears+1
  if held then local src=M.bags[0][held.slot]; if not src then src=held.obj; src.count=0; M.bags[0][held.slot]=src end; src.count=src.count+held.n; src.locked=nil end
  held=nil; M.cursorItem=nil
 end
 local function take(slot,amount)
  local src=M.bags[0][slot]
  assert(src and not src.locked,'no locked source')
  held={slot=slot,n=amount,obj=src}; src.count=src.count-amount
  if src.count==0 then M.bags[0][slot]=nil else src.locked=true end
  M.cursorItem=2589
 end
 C_Container.SplitContainerItem=function(b,s,a) if refuse=='pickup' then return end; take(s,a) end
 C_Container.PickupContainerItem=function(b,s)
  if not held then if refuse=='pickup' then return end; take(s,M.bags[b][s].count); return end
  if refuse=='place' then return end
  local dst=M.bags[b][s]; assert(dst and not dst.locked and dst.id==2589,'valid unlocked destination')
  dst.count=dst.count+held.n; dst.locked=true
  unlock(dst,delay or 0); unlock(M.bags[0][held.slot],delay or 0)
  moves=moves+1; held=nil; M.cursorItem=nil
  if stopAfter and moves>=stopAfter then allowed=false end
 end
 local function guard() return allowed and not M.cursorItem end
 D:TidyStacks(2589,'Linen Cloth',slots,guard,function() done=done+1 end)
 for rounds=1,100 do local old=jobs; jobs={}; for _,f in ipairs(old) do f() end end
 local partial=0
 for i,it in pairs(M.bags[0]) do
  total=total+it.count
  check(it.count>0 and it.count<=20,'stack capacity preserved')
  if it.count<20 and not (locked and locked[i]) then partial=partial+1 end
 end
 check(total==original and not held and not M.cursorItem,'item quantity conserved; cursor empty')
 check(done==1,'completion exactly once')
 check(moves<=12,'bounded by 12 moves')
 if stopAfter then check(moves<=stopAfter,'no actions after guard cancellation') end
 if not stopAfter and not refuse and not locked and #counts<12 then check(partial<=1,'all possible partials consolidated') end
 if locked then for i in pairs(locked) do check(M.bags[0][i].count==counts[i],'locked attached stack untouched') end end
end
for a=1,19,3 do for b=1,19,3 do scenario({a,b,20,13},nil,nil,nil,2) end end
scenario({19,11,7,3},{[1]=true},nil,nil,1)
scenario({19,11,7,3},nil,1,nil,2)
scenario({19,11,7,3},nil,nil,'pickup',0)
scenario({19,11,7,3},nil,nil,'place',0)
local many={}; for i=1,30 do many[i]=11 end; scenario(many,nil,nil,nil,1)
