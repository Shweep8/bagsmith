-- 1.6.0-beta10: the 1.6.0-beta9 audit's own probe (independent-beta9/quest_shadow_preview_matrix.lua, its checks unchanged), kept in the suite. Evidence and the
-- report: docs/plugins/audit-1.6.0-beta9/.
-- (Run by the suite's runner, which has no AUDIT_CORE: the working copy's BagSmith. The only line added to the probe.)
AUDIT_CORE = AUDIT_CORE or "BagSmith"
-- Independent beta9 positive controls: corners, modes, skins, preview sizes and runtime profile corner changes.
local samples=0
for _,skin in ipairs({'modern','classic'})do
 package.loaded.mock=nil;local M=require('mock')
 M.put(0,1,{id=3000,name='Torn Note',q=1,count=1,class=12,subclass=0,price=0})
 _G.BagSmithCharDB={version=1,firstSeen={}}
 _G.BagSmithDB={version=2,chars={},cache={},profiles={Default={view='icons',skin=skin}}}
 _G.Auctionator=nil;_G.BlackthornesTS_API=nil
 local n=M.loadAddon(AUDIT_CORE)
 C_Container.GetContainerItemQuestInfo=function()return {questID=101,isActive=false}end
 M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers();n.Window:Show();M.runTimers();M.runTimers()
 local C=n.Corners;local P=n.SettingsPanel;P:Show();P:ShowPage('icons')
 local b=P.pools.cornerCards[1].preview
 local mark,shade=b.questMark,b.questShade
 local regions=#b.regions
 local function coherent(label)
  local p1={shade:GetPoint(1)};local p2={shade:GetPoint(2)}
  check(mark:IsShown() and shade:IsShown(),label..' both visible')
  check(shade.texture==C.QUEST_ART and shade.layer=='OVERLAY'and shade.sublayer==5 and mark.sublayer==6,label..' art and layers correct')
  check(shade.color[1]==0 and shade.color[2]==0 and shade.color[3]==0 and shade.color[4]==.8,label..' black 80%')
  check(shade:GetNumPoints()==2 and p1[1]=='TOPLEFT' and p1[2]==mark and p1[3]=='TOPLEFT'and p1[4]==1 and p1[5]==-1 and p2[1]=='BOTTOMRIGHT'and p2[2]==mark and p2[3]=='BOTTOMRIGHT'and p2[4]==1 and p2[5]==-1,label..' two fixed offset anchors')
 end
 for _,mode in ipairs({'cell','row'})do for _,corner in ipairs(C.CORNERS)do for _,px in ipairs({8,12,18,32,64,96})do
  samples=samples+1;local label=skin..' '..mode..' '..corner..' '..px
  C:PlaceAt('quest_start',corner);C:DrawPreview(b,mode,px)
  coherent(label)
  local expected=math.min(math.max(10,math.floor(px*.45+.5)),math.floor(px/2))
  check(mark:GetWidth()==expected and mark:GetHeight()==expected,label..' capped marker size follows current requested size')
  check(b.previewShown[corner]=='quest_start' and select(1,mark:GetPoint(1))==({top_left='TOPLEFT',top_right='TOPRIGHT',bottom_left='BOTTOMLEFT',bottom_right='BOTTOMRIGHT'})[corner],label..' correct marker placement')
  check(b.questMark==mark and b.questShade==shade and #b.regions==regions,label..' stable textures no repeated allocation')
 end end end
 -- Profile import/use can rearrange a live preview; caller redraw reads latest profile.
 local profile=n.Copy(n.db);profile.iconCorners={top_left={'quantity'},top_right={},bottom_left={},bottom_right={'quest_start'}}
 local name=n.Profiles:Import('Shadow matrix',profile);n.Profiles:Use(name);C:DrawPreview(b,'cell',32)
 check(b.previewShown.bottom_right=='quest_start',skin..' imported profile places quest starter')
 coherent(skin..' profile')
 C:Reset();C:DrawPreview(b,'row',18)
 check(b.previewShown.top_left=='quest_start',skin..' reset restores quest corner')
 coherent(skin..' reset')
 P:Hide()
end
print('PREVIEW_LAYOUTS',samples)
