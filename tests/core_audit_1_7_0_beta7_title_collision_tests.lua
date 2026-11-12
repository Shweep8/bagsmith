-- Same valid no-ID quest API data on beta4 and beta7.
package.loaded.mock=nil
local M=require('mock')
BagSmithCharDB={version=1,firstSeen={}}
BagSmithDB={version=2,chars={},cache={},profiles={Default={}}}
local n=M.loadAddon('BagSmith')
M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers(); M.runTimers()
GetNumQuestLogEntries=function() return 2 end
GetQuestLogTitle=function() return 'Same quest title',10,0,false,false,false,0,nil end
GetNumQuestLeaderBoards=function() return 1 end
GetQuestLogLeaderBoard=function(j,i) return i==1 and 'Linen Cloth: 5/20' or 'Gnoll Paw: 2/8','item',false end
C_QuestLog=nil
local MR=n.MakeRoom
local needs=MR:QuestObjectives()
print('OBJECTIVES: '..table.concat(needs,' | '))
check(MR:NeededForQuest('Linen Cloth',needs),'first same-title quest must protect Linen Cloth')
check(MR:NeededForQuest('Gnoll Paw',needs),'second same-title quest must protect Gnoll Paw')
