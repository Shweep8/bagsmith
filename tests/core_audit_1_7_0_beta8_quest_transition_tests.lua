local ns={OnSignal=function()end}
assert(loadfile('BagSmith/Core/MakeRoom.lua'))('BagSmith',ns)
local MR=ns.MakeRoom
local log={}
GetNumQuestLogEntries=function() return #log,#log end
GetQuestLogTitle=function(i) local q=log[i]; return q.title,1,0,q.header,q.collapsed,false,0,q.id end
GetNumQuestLeaderBoards=function(i) local q=log[i]; if q.fail then return nil end return #(q.items or {}) end
GetQuestLogLeaderBoard=function(j,i) return log[i].items[j],'item' end
local passes=0
local function check(ok,msg) assert(ok,msg); passes=passes+1 end
local function read(items,expect,full)
 log=items; local needs,complete=MR:QuestObjectives()
 check(complete==full,'completeness')
 for _,name in ipairs(expect) do check(MR:NeededForQuest(name,needs),'missing '..name) end
 return needs,complete
end
local A='Linen Cloth: 5/20';local B='Gnoll Paw: 2/8'
-- identity transitions and mixed same-title identity
for _,id1 in ipairs({false,0,1001,'1001'}) do
 for _,id2 in ipairs({false,0,1002,'1002'}) do
  MR.questMemo={}
  read({{title='Shared',id=id1,items={A}},{title='Shared',id=id2,items={B}}},{'Linen Cloth','Gnoll Paw'},true)
  read({{title='Shared',id=id1,items={A}},{title='Shared',id=id2,fail=true}},{'Linen Cloth','Gnoll Paw'},tonumber(id2)~=nil and tonumber(id2)>0)
 end
end
for _,from in ipairs({false,0,1001,'1001'}) do
 for _,to in ipairs({false,0,1001,'1001'}) do
  MR.questMemo={}
  read({{title='Old',id=from,items={A}}},{'Linen Cloth'},true)
  read({{title='New',id=to,items={A}}},{'Linen Cloth'},true)
  read({{title='Zone',header=true,collapsed=true}},{'Linen Cloth'},true)
  local needs=read({}, {},true);check(#needs==0,'full empty log prunes')
 end
end
-- objective names with punctuation, Unicode, progress changes, duplicate title union
for _,name in ipairs({'A:B','C++','[Thing]','Étoffe','100% Cloth'}) do
 MR.questMemo={}
 read({{title='Shared',items={name..': 0/5'}},{title='Shared',items={B}}},{name,'Gnoll Paw'},true)
 read({{title='Zone',header=true,collapsed=true},{title='Shared',items={name..': 5/5'}}},{name,'Gnoll Paw'},true)
end
print('TRANSITION ASSERTIONS PASSED',passes)
-- malformed-but-successful responses: observations, not failures of established API contract
MR.questMemo={};read({{title='Quest',id=1001,items={A}}},{'Linen Cloth'},true)
local needs,complete=read({{title='Quest',id=1001,items={''}}},{},true)
print('EMPTY ITEM TEXT: complete='..tostring(complete)..' protected='..tostring(MR:NeededForQuest('Linen Cloth',needs)))
MR.questMemo={};GetNumQuestLeaderBoards=nil;GetQuestLogLeaderBoard=nil
C_QuestLog={GetQuestObjectives=function() return {[2]={type='item',text=A}} end}
log={{title='Quest',id=1001}}
needs,complete=MR:QuestObjectives()
print('SPARSE API ARRAY: complete='..tostring(complete)..' protected='..tostring(MR:NeededForQuest('Linen Cloth',needs)))
