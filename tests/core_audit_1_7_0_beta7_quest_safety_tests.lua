-- Independent beta7 quest-safety tests. Deliberately failing checks assert safe behavior.
-- Run from repository root using tools/run_tests.py and this absolute path.
package.loaded.mock = nil
local M = require('mock')
UnitClass = function() return 'Warrior', 'WARRIOR' end
for b=1,5 do M.sizes[b]=0 end
M.sizes[0]=2
M.put(0,1,{id=2589,name='Linen Cloth',q=1,count=5,stack=20,class=7,subclass=5,price=1})
M.put(0,2,{id=9720,name='Gnoll Paw',q=1,count=2,stack=20,class=15,subclass=0,price=2})
BagSmithCharDB={version=1,firstSeen={}}
BagSmithDB={version=2,chars={},cache={},profiles={Default={makeRoom=true,makeRoomValue='vendor',makeRoomAsk=false}}}
local n=M.loadAddon('BagSmith')
M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers(); M.runTimers()
local MR=n.MakeRoom
MR.Waiting=function() return {{id=9999,values={vendor=100}}} end
local cloth
for _,r in ipairs(n.items) do if r.itemID==2589 then cloth=MR:Offer(r,false,'priced',5) end end
local deleted=0
C_Container.PickupContainerItem=function(b,s) local i=M.bags[b][s]; M.cursorItem=i and i.id; M.cursorSlot={b,s} end
ClearCursor=function() M.cursorItem=nil end
DeleteCursorItem=function() deleted=deleted+1; local p=M.cursorSlot; M.bags[p[1]][p[2]]=nil; M.cursorItem=nil end
local log
local function reset(t)
 log=t; MR.questMemo={}
 GetNumQuestLogEntries=function() return #log end
 GetQuestLogTitle=function(i) local q=log[i]; return q.title,10,0,q.header,q.collapsed,false,0,q.id end
 GetNumQuestLeaderBoards=function(i) return #(log[i].objs or {}) end
 GetQuestLogLeaderBoard=function(j,i) local q=log[i]; if q.error then error('objective unavailable') end; return q.objs[j],'item',false end
 C_QuestLog=nil
end
local function clothNeeded()
 local needs,complete=MR:QuestObjectives()
 return MR:NeededForQuest('Linen Cloth',needs),complete,table.concat(needs,' | ')
end
-- Control: numeric IDs keep same-titled quests separate.
reset({{title='Shared title',id=1001,objs={'Linen Cloth: 5/20'}},{title='Shared title',id=1002,objs={'Gnoll Paw: 2/8'}}})
local kept,complete,text=clothNeeded()
check(kept and complete,'control: distinct quest IDs preserve both objectives')
check(select(2,MR:StillOk(cloth))=='questneed','control: identified quest prevents destruction')
-- F1: no-ID fallback aliases two quests sharing a title, even when both reads succeed.
reset({{title='Shared title',objs={'Linen Cloth: 5/20'}},{title='Shared title',objs={'Gnoll Paw: 2/8'}}})
kept,complete,text=clothNeeded()
print('DUPLICATE TITLE: complete='..tostring(complete)..'; needs='..text..'; cloth protected='..tostring(kept))
check(kept,'same-title/no-ID quests must preserve first quest objective')
check(not MR:StillOk(cloth),'same-title/no-ID quest must prevent destruction of needed Cloth')
-- Failure in the colliding second quest is masked by a memo for the first.
reset({{title='Shared title',objs={'Gnoll Paw: 2/8'}},{title='Shared title',objs={'Linen Cloth: 5/20'},error=true}})
kept,complete,text=clothNeeded()
print('DUPLICATE TITLE + ERROR: complete='..tostring(complete)..'; needs='..text)
check(not complete,'failed distinct quest must not inherit another quest memo as a complete reading')
-- Control: valid titles/IDs and throwing objective reader fail closed on a new quest.
reset({{title='Donation',id=1001,objs={'Linen Cloth: 5/20'},error=true}})
check(not select(2,MR:QuestObjectives()),'control: thrown objective error with no memo is incomplete')
check(select(2,MR:StillOk(cloth))=='questlog','control: throwing objective error refuses old offer')
-- F2: a nonthrowing nil count silently declares the whole log empty, prunes known protection.
reset({{title='Donation',id=1001,objs={'Linen Cloth: 5/20'}}})
check(clothNeeded(),'control: known quest is remembered before count becomes unreadable')
GetNumQuestLogEntries=function() return nil end
kept,complete,text=clothNeeded()
print('NIL QUEST COUNT: complete='..tostring(complete)..'; needs='..text)
check(not complete,'nil log count must not be a successful complete reading')
check(not MR:StillOk(cloth),'nil log count must refuse destruction')
-- A missing objective count likewise clears the remembered objective.
reset({{title='Donation',id=1001,objs={'Linen Cloth: 5/20'}}})
check(clothNeeded(),'control: remembered objective before missing objective count')
GetNumQuestLeaderBoards=function() return nil end
kept,complete,text=clothNeeded()
print('NIL OBJECTIVE COUNT: complete='..tostring(complete)..'; needs='..text)
check(kept or not complete,'nil objective count must retain protection or mark the reading incomplete')
check(not MR:StillOk(cloth),'nil objective count must refuse destruction')
-- Most direct: advertised objective missing text, no Lua error.
reset({{title='Donation',id=1001,objs={'Linen Cloth: 5/20'}}})
check(clothNeeded(),'control: remembered objective before objective returns no data')
GetQuestLogLeaderBoard=function() return nil end
kept,complete,text=clothNeeded()
print('NIL OBJECTIVE: complete='..tostring(complete)..'; needs='..text)
check(kept or not complete,'missing advertised objective must retain protection or mark incomplete')
local ok,why=MR:StillOk(cloth)
check(not ok,'missing advertised objective must refuse destruction (reason='..tostring(why)..')')
local result=MR:Destroy(cloth,true)
print('NIL OBJECTIVE DESTRUCTION: result='..tostring(result)..'; deletes='..deleted..'; cloth exists='..tostring(M.bags[0][1]~=nil))
check(not result and deleted==0 and M.bags[0][1]~=nil,'confirmed old offer must not destroy Cloth after objective becomes unreadable')

-- A usable alternate reader is skipped because the primary returned without throwing.
M.put(0,1,{id=2589,name='Linen Cloth',q=1,count=5,stack=20,class=7,subclass=5,price=1})
n:Scan()
for _,r in ipairs(n.items) do if r.itemID==2589 then cloth=MR:Offer(r,false,'priced',5) end end
reset({{title='Donation',id=1001,objs={'Linen Cloth: 5/20'}}})
GetQuestLogLeaderBoard=function() return nil end
local fallbackCalls=0
C_QuestLog={GetQuestObjectives=function(id) fallbackCalls=fallbackCalls+1; return {{type='item',text='Linen Cloth: 5/20'}} end}
kept,complete,text=clothNeeded()
print('NIL PRIMARY + GOOD FALLBACK: calls='..fallbackCalls..'; complete='..tostring(complete)..'; cloth protected='..tostring(kept))
check(fallbackCalls>0 and kept,'missing primary objective should try valid fallback and preserve protection')
-- End-to-end deletion for the separate title-collision defect.
reset({{title='Shared title',objs={'Linen Cloth: 5/20'}},{title='Shared title',objs={'Gnoll Paw: 2/8'}}})
local before=deleted
result=MR:Destroy(cloth,true)
print('DUPLICATE TITLE DESTRUCTION: result='..tostring(result)..'; new deletes='..(deleted-before)..'; cloth exists='..tostring(M.bags[0][1]~=nil))
check(not result and deleted==before and M.bags[0][1]~=nil,'same-title/no-ID quests must not allow confirmed destruction of needed Cloth')
