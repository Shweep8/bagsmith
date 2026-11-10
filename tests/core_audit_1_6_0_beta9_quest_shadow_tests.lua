-- 1.6.0-beta10: the 1.6.0-beta9 audit's own probe (independent-beta9/quest_shadow_lifecycle.lua, its checks unchanged), kept in the suite. Evidence and the
-- report: docs/plugins/audit-1.6.0-beta9/.
-- (Run by the suite's runner, which has no AUDIT_CORE: the working copy's BagSmith. The only line added to the probe.)
AUDIT_CORE = AUDIT_CORE or "BagSmith"
-- Independent beta9 probe: source untouched. Real addon event/Blank paths with supplied WoW fixture.
local caseNo=0
local function boot(skin,view,empty)
 package.loaded.mock=nil;local M=require('mock')
 M.put(0,1,{id=3000,name='Torn Note',q=1,count=1,class=12,subclass=0,price=0})
 _G.BagSmithCharDB={version=1,firstSeen={}}
 _G.BagSmithDB={version=2,chars={},cache={},profiles={Default={view=view,skin=skin,emptySlots=empty,grp='none'}}}
 _G.Auctionator=nil;_G.BlackthornesTS_API=nil
 local quests={[1]={questID=101,isActive=false}}
 local n=M.loadAddon(AUDIT_CORE)
 C_Container.GetContainerItemQuestInfo=function(bag,slot)return quests[slot] or {isQuestItem=false} end
 M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers();n.Window:Show();M.runTimers();M.runTimers()
 return n,M,quests
end
for _,skin in ipairs({'modern','classic'})do for _,view in ipairs({'icons','list'})do
 for _,corner in ipairs({'top_left','top_right','bottom_left','bottom_right'})do
  for _,route in ipairs({'combat_gone','ordinary_gone','grid_gone','replacement','accepted'})do
   caseNo=caseNo+1
   local n,M,quests=boot(skin,view,route=='grid_gone')
   n.Corners:PlaceAt('quest_start',corner);M.runTimers();M.runTimers()
   local b=n.Buttons:Get(0,1);n.Corners:Apply(b,true)
   local label=skin..' '..view..' '..corner..' '..route
   check(b:IsVisible() and b.questMark and b.questMark:IsShown(),label..' setup visible mark')
   local shade=b.questShade
   if shade then check(shade:IsShown(),label..' setup shadow shown')end
   if route=='combat_gone'then M.combat=true;M.fire('PLAYER_REGEN_DISABLED')end
   if route=='replacement'then
    M.put(0,1,{id=3001,name='Stone',q=1,count=1,class=15,subclass=0,price=1});quests[1]=nil
   elseif route=='accepted'then quests[1]={questID=101,isActive=true}
   else M.bags[0][1]=nil;quests[1]=nil end
   M.fire('BAG_UPDATE_DELAYED');M.runTimers();M.runTimers()
   local visible=b:IsVisible()
   local markShown=b.questMark and b.questMark:IsShown()or false
   local shadeShown=shade and shade:IsShown()or false
   print('QUEST_CASE',label,'visible='..tostring(visible),'hasItem='..tostring(b.hasItem),'empty='..tostring(b.rec and b.rec.empty),'mark='..tostring(markShown),'shade='..tostring(shadeShown))
   check(not(visible and markShown),label..' no quest mark on absent/accepted/nonquest item')
   if shade then check(not(visible and shadeShown),label..' no shadow on absent/accepted/nonquest item')end
   if route=='combat_gone'then
    check(not b.hasItem and b.rec and b.rec.empty and not b.icon:IsShown(),label..' actual item is blanked')
    M.combat=false;M.fire('PLAYER_REGEN_ENABLED');M.runTimers();M.runTimers()
    check(not b:IsVisible(),label..' normal postcombat layout hides old button')
   end
  end
 end
end end
print('QUEST_LIFECYCLE_CASES',caseNo)
