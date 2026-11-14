-- 1.7.2: the 1.7.2-beta2 audit's own probe (evidence/independent/tooltip.lua), unchanged (it reproduced F1 on beta2: 1 of 2 failed; it passes with the fix). Evidence and the report:
-- docs/plugins/audit-1.7.2-beta2/.
;(function()
package.loaded.mock=nil
local M=require('mock')
for s=1,3 do M.put(0,s,{id=6265,name='Soul Shard',q=1,count=1,maxStack=1,class=15,subclass=0,price=0}) end
_G.BagSmithCharDB={version=1,firstSeen={}}
_G.BagSmithDB={version=2,chars={},cache={},profiles={Default={skin='modern'}}}
local n=M.loadAddon('BagSmith')
M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers()
n:Set('mergeStacks',true); n.Window:Show(); M.runTimers();M.runTimers()
n.atBank=true
local owner={bsItem=true, rec={itemID=6265,merged=true,stacks=3,members={{bag=0,slot=1},{bag=0,slot=2},{bag=0,slot=3}}}}
local lines={}; local tip={GetOwner=function()return owner end}
n.TipLine=function(_,line) lines[#lines+1]=line end
n.AH.AddTooltipLines=function()end; n.Junk.AddTooltipLines=function()end; n.Marks.AddTooltipLines=function()end
if n.Pawn then n.Pawn.AddTooltipLines=function()end end
n.Buttons.AddTooltipExtras(tip)
for _,line in ipairs(lines)do print('ACTUAL TOOLTIP: '..line) end
check(not table.concat(lines,'\n'):find('Right%-click: move all'), 'Soul Shard must not promise bank movement')
owner.rec.itemID=2592;lines={};n.Buttons.AddTooltipExtras(tip)
check(table.concat(lines,'\n'):find('Right%-click: move all')~=nil,'Control: ordinary merged stack retains bank hint')

end)()
