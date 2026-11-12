-- The known collapsed-header limitation versus the shipped draft What's New promise.
package.loaded.mock=nil
local M=require('mock')
BagSmithCharDB={version=1,firstSeen={}}
BagSmithDB={version=2,chars={},cache={},profiles={Default={}}}
local n=M.loadAddon('BagSmith')
M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers(); M.runTimers()
GetNumQuestLogEntries=function() return 1 end
GetQuestLogTitle=function() return 'Collapsed zone',10,0,true,true,false,0,nil end
local MR=n.MakeRoom; MR.questMemo={}
local needs,complete=MR:QuestObjectives()
check(complete and #needs==0,'documented behavior: unseen quests under collapsed header are absent')
check(not MR:NeededForQuest('Linen Cloth',needs),'collapsed-before-first-read objective cannot protect a material')
local first=n.WhatsNew.ENTRIES[1]
check(first.v=='1.7.0','reviewing draft 1.7 card')
print('FIRST BULLET: '..first.items[1])
check(not first.items[1]:find('never offers what you still need for a quest',1,true) or first.items[1]:find('collapsed',1,true),'draft first bullet must qualify unconditional quest protection')
