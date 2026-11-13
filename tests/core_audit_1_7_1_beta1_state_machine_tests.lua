-- 1.7.1-beta2: the 1.7.1-beta1 audit's own probe (swap/state_machine_probe.lua). Its checks that recorded F2 and the
-- two advisories are turned round to the fixed behavior (marked); the scenarios and the controls are as delivered.
-- Evidence and the report: docs/plugins/audit-1.7.1-beta1/.
-- Independent swap state-machine fixture: controlled timer queue and cursor,
-- source slots remain locked while held, destination updates settle on request.
local NEW,OLD,OTHER=4241,4238,2589
local function boot()
 package.loaded.mock=nil; local M=require('mock'); InCombatLockdown=function() return false end; M.bags[-1]={};M.sizes[-1]=0
 for b=0,12 do M.bags[b]={}; M.sizes[b]=0 end
 M.sizes[0],M.sizes[1],M.sizes[2]=1,4,2
 local function put(b,s,id,bag) M.put(b,s,{id=id,name=bag and ('Bag '..id) or 'Cloth',q=1,count=1,stack=bag and 1 or 20,class=bag and 1 or 7,subclass=0,equip=bag and 'INVTYPE_BAG' or '',price=1}) end
 put(0,1,OTHER,false); put(1,1,OTHER,false); put(1,2,NEW,true); put(2,1,OTHER,false)
 BagSmithDB={version=2,chars={},cache={},profiles={Default={}}}; BagSmithCharDB={version=1,firstSeen={}}
 local equipped={[20]=OLD,[21]=4998}
 GetInventoryItemID=function(_,inv) return equipped[inv] end
 local n=M.loadAddon('BagSmith'); M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers();M.runTimers()
 local q={}; C_Timer.After=function(t,f) q[#q+1]=f end
 local st={held=nil,picks=0,puts=0,clears=0,mode='success'}
 local realInstant=C_Item.GetItemInfoInstant
 C_Item.GetItemInfoInstant=function(id) if id==NEW or id==OLD then return id,nil,nil,'INVTYPE_BAG',1,1 end return realInstant(id) end
 local realInfo=C_Item.GetItemInfo
 C_Item.GetItemInfo=function(id) if id==NEW or id==OLD then return 'Bag '..id end return realInfo(id) end
 ClearCursor=function() st.clears=st.clears+1; if st.held and st.held.bag then local it=M.bags[st.held.bag][st.held.slot]; if it then it.locked=nil end end; st.held=nil;M.cursorItem=nil end
 C_Container.PickupContainerItem=function(b,s)
  st.picks=st.picks+1
  local it=M.bags[b][s]
  if not st.held then if it then st.held={id=it.id,bag=b,slot=s};it.locked=true;M.cursorItem=it.id end;return end
  if it then return end
  local h=st.held; local obj=M.bags[h.bag][h.slot];M.bags[h.bag][h.slot]=nil;M.bags[b][s]=obj;obj.locked=true; st.held=nil;M.cursorItem=nil
 end
 PutItemInBag=function(inv)
  st.puts=st.puts+1
  if st.mode=='refuse' then return end
  if st.mode=='throw' then error('injected PutItemInBag error') end
  local h=st.held;local old=equipped[inv];if st.mode=='async_equip' then st.pendingEquip={inv=inv,id=h.id} else equipped[inv]=h.id end
  put(h.bag,h.slot,old,true); M.bags[h.bag][h.slot].locked=true
  st.held=nil;M.cursorItem=nil
 end
 local function tick() local old=q;q={}; for _,f in ipairs(old) do f() end end
 local function run() for i=1,20 do tick() end end
 local function start() C_Container.PickupContainerItem(1,2); n.SwapHint:Intercept(1,20) end
 local function logs() return table.concat(M.log,'|') end
 return {M=M,n=n,H=n.SwapHint,st=st,eq=equipped,tick=tick,run=run,start=start,put=put,log=logs}
end
-- Successful normal route (source cleared synchronously; staging slot locked until game update).
do local r=boot();r.start(); check(r.H.swapping~=nil and r.M.bags[2][2].id==NEW,'setup: staged in another bag')
 r.M.bags[2][2].locked=nil;r.run()
 check(r.eq[20]==NEW and r.M.bags[2][2].id==OLD and not r.M.cursorItem and not r.H.swapping,'successful swap conserved both bags') end
-- Player picks staged NEW during the wait: preserved, but location message is wrong.
do local r=boot();r.start();r.M.bags[2][2].locked=nil;C_Container.PickupContainerItem(2,2);r.run()
 check(r.eq[20]==OLD and r.st.puts==0 and r.M.cursorItem==NEW and not r.H.swapping,'player pickup cancels future equip and preserves cursor')
 print('user takes new bag: '..r.log())
 check(r.log():find("didn't confirm",1,true) and not r.log():find("is in your",1,true),'cancelled user take leaves a timeout notice')   -- (1.7.1-beta2, F2: and names no place: the bag is on the cursor)
 end
-- Player picks a different item during wait: preserved with no automatic equip.
do local r=boot();r.start();r.M.bags[2][2].locked=nil;C_Container.PickupContainerItem(0,1);r.run()
 check(r.st.puts==0 and r.M.cursorItem==OTHER and not r.H.swapping,'different user cursor preserved') end
-- Combat during staging wait prevents equip.
do local r=boot();r.start();r.M.bags[2][2].locked=nil;InCombatLockdown=function() return true end;r.run()
 check(r.st.puts==0 and r.eq[20]==OLD and not r.H.swapping,'combat prevents second phase') end
-- A bank-assisted swap does not check bank state after staging.
do local r=boot();r.n.atBank=true;r.M.sizes[2]=1;r.M.sizes[6]=2
 r.start(); check(r.M.bags[6][1] and r.M.bags[6][1].id==NEW,'setup: temporary destination in bank')
 r.n.atBank=false;r.M.bags[6][1].locked=nil;r.M.fire('BANKFRAME_CLOSED');r.run()
 print('bank closed: puts='..r.st.puts..' equipped='..tostring(r.eq[20]))
 check(r.st.puts==0 and r.eq[20]==OLD and not r.H.swapping and r.log():find('the bank closed',1,true),'bank close ends a bank-dependent swap, said')   -- (1.7.1-beta2, advisory B: turned round)
 end
-- Error in confirmation predicate is caught, but not sent through ns:Guard/errorLog.
do local r=boot();r.start();local real=C_Container.GetContainerItemInfo
 C_Container.GetContainerItemInfo=function(b,s) if b==2 and s==2 then error('injected await read error') end return real(b,s) end
 local ok=pcall(r.run)
 print('await error: ok='..tostring(ok)..' logged='..#(r.n.errorLog or {})..' '..r.log())
 check(ok and not r.H.swapping,'await error ends swap')
 check(#(r.n.errorLog or {})>0,'await error kept for /bs errors')   -- (1.7.1-beta2, advisory A: turned round)
 end
-- PutItemInBag exception remains safely handled and logged.
do local r=boot();r.st.mode='throw';r.start();r.M.bags[2][2].locked=nil;r.run()
 check(not r.H.swapping and not r.M.cursorItem and r.M.bags[2][2].id==NEW and r.eq[20]==OLD,'exception restores own new bag')
 check(#(r.n.errorLog or {})>0,'step error logged') end
-- Native-style delayed inventory confirmation; user begins another drag while
-- confirmation is pending. No API error needed for false refusal message.
do local r=boot();r.st.mode='async_equip';r.start();r.M.bags[2][2].locked=nil;r.tick()
 check(r.st.pendingEquip and r.H.swapping,'setup: equip operation waiting for inventory confirmation')
 r.eq[20]=NEW;C_Container.PickupContainerItem(0,1);r.run()
 print('successful equip + user cursor: eq='..r.eq[20]..' cursor='..tostring(r.M.cursorItem)..' '..r.log())
 check(r.eq[20]==NEW and r.M.cursorItem==OTHER,'successful swap and unrelated user cursor preserved')
 check(not r.log():find("The game didn't swap the bags",1,true) and r.log():find("Swapped in",1,true) and not r.H.swapping,'a swap confirmed by the bag slot is reported as done, the cursor left alone')   -- (1.7.1-beta2, F2: turned round)
 end
-- The final success callback is not protected when reached from a timer.
do local r=boot();r.st.mode='async_equip';r.start();r.M.bags[2][2].locked=nil;r.tick()
 r.eq[20]=NEW
 local real=C_Container.GetContainerItemInfo
 C_Container.GetContainerItemInfo=function(b,s) if b==2 and s==2 then error('injected final location-read error') end return real(b,s) end
 local ok,err=pcall(r.run)
 print('step4 error: ok='..tostring(ok)..' active='..tostring(r.H.swapping~=nil)..' logged='..#(r.n.errorLog or {})..' err='..tostring(err))
 check(ok and r.H.swapping==nil,'a final callback error is caught and ends the swap')   -- (1.7.1-beta2, advisory A: turned round)
 check(#(r.n.errorLog or {})>0,'final callback error kept for /bs errors')   -- (1.7.1-beta2, advisory A: turned round)
 end
