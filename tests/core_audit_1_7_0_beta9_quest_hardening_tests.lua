local ns={OnSignal=function()end}
assert(loadfile('BagSmith/Core/MakeRoom.lua'))('BagSmith',ns)
local MR=ns.MakeRoom
local passes,fails=0,0
local function ck(ok,msg) if ok then passes=passes+1 else fails=fails+1;print('FAIL '..msg) end end
local obj,apiObj,id,title='Linen Cloth: 3/10',nil,1001,'Quest'
GetNumQuestLogEntries=function()return 1,1 end
GetQuestLogTitle=function()return title,1,0,false,false,false,0,id end
GetNumQuestLeaderBoards=function()return 1 end
GetQuestLogLeaderBoard=function()return obj,'item' end
C_QuestLog={GetQuestObjectives=function()return apiObj end}
local function protected()
 local needs,complete=MR:QuestObjectives()
 return MR:NeededForQuest('Linen Cloth',needs),complete
end
for _,blank in ipairs({'',' ','\t','\r\n','  \t\r\n'}) do
 MR.questMemo={};obj=blank;apiObj=nil
 local keep,complete=protected();ck(not complete,'new blank legacy read incomplete')
 MR.questMemo={};obj='Linen Cloth: 3/10';protected();obj=blank
 keep,complete=protected();ck(keep and complete,'blank preserves remembered ID objective')
 MR.questMemo={};apiObj={{type='item',text='Linen Cloth: 3/10'}}
 keep,complete=protected();ck(keep and complete,'blank legacy falls back to valid API')
 MR.questMemo={};apiObj={{type='item',text=blank}}
 keep,complete=protected();ck(not complete,'blank API incomplete')
 MR.questMemo={};obj='Linen Cloth: 3/10';protected();obj=blank
 keep,complete=protected();ck(keep and complete,'blank both routes retains memo')
 MR.questMemo={};id=nil;obj='Linen Cloth: 3/10';protected();obj=blank
 keep,complete=protected();ck(keep and not complete,'noID blank retains protection but incomplete')
 id=1001
end
-- Explicit fallback-array structure validation. Valid arrays and no objectives remain allowed.
GetQuestLogLeaderBoard=nil;GetNumQuestLeaderBoards=nil
local item={type='item',text='Linen Cloth: 3/10'}
for _,case in ipairs({
 {name='hole at first',v={[2]=item}},
 {name='middle hole',v={[1]=item,[3]=item}},
 {name='zero key',v={[0]=item}},
 {name='negative key',v={[-1]=item}},
 {name='fractional key',v={[1.5]=item}},
 {name='string key',v={['1']=item}},
 {name='metadata key',v={[1]=item,n=1}},
 {name='non-table entry',v={'not objective'}},
 {name='missing type',v={{text='Linen Cloth: 3/10'}}},
}) do
 MR.questMemo={};apiObj=case.v
 local keep,complete=protected();ck(not complete,case.name..' incomplete')
 MR.questMemo={[1001]={'Linen Cloth: 3/10'}}
 keep,complete=protected();ck(keep and complete,case.name..' retains memo')
end
for _,valid in ipairs({{}, {item}, {{type='monster',text=''},item},{{type='monster'},item}}) do
 MR.questMemo={};apiObj=valid
 local keep,complete=protected();ck(complete,'valid dense API accepted')
 if #valid>0 then ck(keep,'valid dense API protects item') end
end
-- Arbitrarily ordered insertion still valid dense list.
MR.questMemo={};apiObj={};apiObj[2]=item;apiObj[1]={type='monster'}
local keep,complete=protected();ck(keep and complete,'insertion order irrelevant')
-- Shared normalization and removal; zero/negative/nonnumeric cannot accidentally delete title keys.
if MR.QuestID then
 for _,v in ipairs({1,'1',1001,'1001',0,-1,'0','abc',false,{},math.huge,0/0}) do
  local normalized=MR.QuestID(v)
  local expected=tonumber(v); if not (expected and expected>0) then expected=nil end
  ck(normalized==expected,'QuestID normalization')
 end
 MR.questMemo={[1001]={'Linen Cloth: 3/10'},['t:Quest']={'Gnoll Paw: 2/8'}}
 MR:ForgetQuest('1001');ck(MR.questMemo[1001]==nil,'numeric-string removal normalized')
 MR:ForgetQuest('t:Quest');ck(MR.questMemo['t:Quest']~=nil,'title key not removed as quest ID')
 MR:ForgetQuest(0);MR:ForgetQuest(nil);MR:ForgetQuest(false);MR:ForgetQuest(0/0)
 ck(MR.questMemo['t:Quest']~=nil,'invalid removal no-op')
else ck(false,'shared QuestID helper exists') end
print(('HARDENING RESULTS: %d passed, %d failed'):format(passes,fails))
