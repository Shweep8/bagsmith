-- 1.7.0-beta13: the 1.7.0-beta12 audit's own probe (drop/tidy_faults.lua), its injected-error checks turned round to the
-- fixed behavior (A1), each marked; the scenarios and the controls are as delivered. Evidence and the report:
-- docs/plugins/audit-1.7.0-beta12/.
-- Independent fault probes for new beta12 TidyStacks. Realistic cursor state:
-- split immediately removes units from the bag, ClearCursor restores them.
local function boot(mode)
 package.loaded.mock=nil
 local M=require('mock')
 for b=1,5 do M.sizes[b]=0 end
 M.sizes[0]=4
 for s,c in ipairs({20,19,11}) do M.put(0,s,{id=2589,name='Linen Cloth',q=1,count=c,stack=20,class=7,subclass=5,price=1}) end
 BagSmithCharDB={version=1,firstSeen={}}
 BagSmithDB={version=2,chars={},cache={},profiles={Default={}}}
 MailFrame=CreateFrame('Frame'); SendMailFrame=CreateFrame('Frame'); TradeFrame=CreateFrame('Frame'); TradeFrame:Hide()
 local mail={}
 GetSendMailItem=function(i) local a=mail[i]; if a then return 'Linen Cloth',2589,nil,a end end
 GetSendMailItemLink=function(i) if mail[i] then return 'item:2589:0' end end
 local n=M.loadAddon('BagSmith'); M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers(); M.runTimers()
 local D=n.Drop
 local st={held=nil,calls=0,splits=0,places=0,attached=0,clears=0}
 ClearCursor=function()
  st.clears=st.clears+1
  if st.held then local h=st.held; local src=M.bags[0][h.slot]; src.count=src.count+h.n; src.locked=nil end
  st.held=nil; M.cursorItem=nil
 end
 C_Container.SplitContainerItem=function(b,s,amount)
  st.splits=st.splits+1
  if mode=='split_throw' then error('ADDON_ACTION_BLOCKED SplitContainerItem') end
  if mode=='split_noop' then return end
  local src=M.bags[b][s]; st.held={slot=s,n=amount}; src.count=src.count-amount; src.locked=true; M.cursorItem=2589
 end
 C_Container.PickupContainerItem=function(b,s)
  st.places=st.places+1
  if mode=='place_throw' then error('ADDON_ACTION_BLOCKED PickupContainerItem') end
  if mode=='place_noop' then return end
  local h=st.held; local src=M.bags[b][h.slot]; local dst=M.bags[b][s]
  dst.count=dst.count+h.n; src.locked=nil; st.held=nil; M.cursorItem=nil
  if mode=='cancel_after_place' then D:BumpSession('mail') end
  if mode=='user_cursor_after_place' then C_Timer.After(0,function() M.cursorItem=2835 end) end
  if mode=='count_changed_after_place' then dst.count=dst.count-1; src.count=src.count+1 end
 end
 C_Container.UseContainerItem=function(b,s)
  st.attached=st.attached+1; mail[#mail+1]=M.bags[b][s].count; M.bags[b][s].locked=true
 end
 D:NoteTradeBaseline({itemID=2589,name='Linen Cloth'})
 mail[1]=20; M.bags[0][1].locked=true
 D:MoveRest({itemID=2589,name='Linen Cloth',where='mail',first={bag=0,slot=1},members={{bag=0,slot=1},{bag=0,slot=2},{bag=0,slot=3}}})
 local ok,err=pcall(function() for i=1,30 do M.runTimers() end end)
 local active=D.active~=nil
 print(mode..': ok='..tostring(ok)..', active='..tostring(active)..', cursor='..tostring(M.cursorItem)..', attached='..st.attached..', error='..tostring(err))
 if mode=='cancel_after_place' then
  check(ok and not active and not st.held and not M.cursorItem and st.attached==0,'cancel after place: no later attach, no held cursor')
  check(M.bags[0][2].count+M.bags[0][3].count==30,'cancel after place conserves all remaining units')
 elseif mode=='user_cursor_after_place' then
  check(ok and not active and M.cursorItem==2835 and st.attached==0,'new user cursor during wait is preserved; no later attach')
 elseif mode=='count_changed_after_place' then
  check(ok and not active and not st.held and not M.cursorItem and st.attached==2,'reverted counts stop tidy and attach actual live stacks')
  check(mail[2]+mail[3]==30,'reverted counts conserve quantities')
 elseif mode=='split_noop' or mode=='place_noop' then
  check(ok and not active and not st.held and st.attached==2,'control: '..mode..' cleaned up and followers attached')
 elseif mode=='success' then
  check(ok and not active and not st.held and st.attached==2 and mail[2]==20 and mail[3]==10,'control: successful tidy sends 20,20,10')
 else
  -- (1.7.0-beta13, A1: turned round to the fixed behavior) the error is caught, the tidy and the job end, nothing more is
  -- attached, it's said and kept for /bs errors
  check(ok and not active and st.attached==0 and table.concat(M.log,'|'):find('something went wrong while topping up the stacks',1,true) and #(n.errorLog or {})>0,'fixed: '..mode..' is caught and ends the job, said, kept for /bs errors')
  if mode=='place_throw' then check(not st.held and not M.cursorItem and M.bags[0][3].count==11 and M.bags[0][2].count==19,'fixed: place throw takes the split unit off the cursor, back where it was') end
  -- (1.7.0-beta13, A1: turned round) a later movement is not refused
  D:MoveRest({itemID=2589,name='Linen Cloth',where='mail',first={bag=0,slot=1},members={{bag=0,slot=1},{bag=0,slot=2}}})
  check(not table.concat(M.log,'|'):find('Still moving',1,true),'fixed: a follow-up attempt is not refused as still moving')
 end
end
for _,mode in ipairs({'success','split_noop','place_noop','split_throw','place_throw','cancel_after_place','user_cursor_after_place','count_changed_after_place'}) do boot(mode) end
