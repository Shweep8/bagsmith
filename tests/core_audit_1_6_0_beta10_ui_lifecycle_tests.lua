-- 1.6.0-beta11: the 1.6.0-beta10 audit's own probe (independent-beta10/ui_lifecycle_extension.lua, its checks unchanged), kept in the suite. Evidence and the
-- report: docs/plugins/audit-1.6.0-beta10/.
-- (Run by the suite's runner, which has no AUDIT_CORE: the working copy's BagSmith. The only line added to the probe.)
AUDIT_CORE = AUDIT_CORE or "BagSmith"
-- Independent beta10 synthetic UI regression coverage. Source is not modified.
-- Text metrics are a deterministic fixture, NOT native font/render evidence.
local layouts=0
for _,skin in ipairs({'modern','classic'}) do
 for _,height in ipairs({480,600,720,768,1080,1440}) do
  for _,scale in ipairs({0.75,1,1.5,2}) do
   package.loaded.mock=nil;local M=require('mock');M.faithfulVisibility=true
   local oldFs=M.fs
   M.fs=function()
    local fs=oldFs()
    local function clean(s)return tostring(s or ''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')end
    fs.GetStringWidth=function(self)return #clean(self.text)*6*scale end
    fs.GetStringHeight=function(self)return 14*scale*math.max(1,math.ceil(#clean(self.text)*6*scale/math.max(self.width or 300,1)))end
    return fs
   end
   UIParent:SetHeight(height)
   BagSmithCharDB={version=1,firstSeen={}};BagSmithDB={version=2,chars={},cache={},profiles={Default={skin=skin}}}
   Auctionator=nil;BlackthornesTS_API=nil
   local n=M.loadAddon(AUDIT_CORE);M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers()
   n.version='1.6.0-beta10';local WN=n.WhatsNew;WN:ShowLatest();local c=WN.Card();local label=skin..' h='..height..' font='..scale
   layouts=layouts+1
   check(c:IsShown() and c.sel==1 and #c.entries==5,label..' opens current release with five tabs')
   check(c.lines[7] and c.lines[7]:IsShown() and c.lines[7]:GetText():find('Smarter Disenchant Advice',1,true),label..' sixth bullet rendered in content')
   check(c:GetHeight()<=height,label..' card fits logical screen height')
   check(c.contentH>=c.bodyH or not c.scrolls,label..' scroll flag matches content')
   local p=c.lines[7].points[1];local lastBottom=-(p[5] or 0)+c.lines[7]:GetStringHeight()
   check(lastBottom<=c.contentH,label..' final bullet is inside content bounds')
   local wheel=c.body:GetScript('OnMouseWheel');wheel(c.body,-100000)
   check(c.body:GetVerticalScroll()==math.max(0,c.contentH-c.bodyH),label..' mousewheel reaches content bottom')
   wheel(c.body,100000);check(c.body:GetVerticalScroll()==0,label..' mousewheel returns to top')
   local h=c:GetHeight();WN:Select(2)
   check(c.sel==2 and c:GetHeight()==h and c.body:GetVerticalScroll()==0,label..' tab preserves card size and resets scroll')
   check(not c.lines[7]:IsShown(),label..' unused bullet is hidden on shorter tab')
   WN:Select(1);check(c.lines[7]:IsShown(),label..' sixth bullet restores after tab return')
   WN:Close();check(not c:IsShown() and BagSmithDB.whatsNewSeen=='1.6.0',label..' close marks release seen')
   WN:ShowLatest();check(WN.Card()==c and c:IsShown(),label..' reopen reuses card')
  end
 end
end
print('WHATS_NEW_LAYOUTS',layouts)

-- Exercise every non-live gate with initialized quest textures; record that the
-- early-return path only hides regions and does not allocate or mutate geometry.
local gates=0
for _,skin in ipairs({'modern','classic'})do
 for _,view in ipairs({'icons','list'})do
  package.loaded.mock=nil;local M=require('mock');M.faithfulVisibility=true
  M.put(0,1,{id=3000,name='Quest Note',q=1,count=1,class=12,subclass=0,price=0})
  BagSmithCharDB={version=1,firstSeen={}};BagSmithDB={version=2,chars={},cache={},profiles={Default={skin=skin,view=view,emptySlots=true,grp='none'}}}
  Auctionator=nil;BlackthornesTS_API=nil
  local q={questID=101,isActive=false};local n=M.loadAddon(AUDIT_CORE)
  C_Container.GetContainerItemQuestInfo=function()return q end
  M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers();n.Window:Show();M.runTimers();M.runTimers()
  local b=n.Buttons:Get(0,1);n.Corners:Apply(b,true)
  check(b.questMark:IsShown() and b.questShade:IsShown(),skin..' '..view..' quest setup')
  local rec,mode,has,db,corners=b.rec,b.mode,b.hasItem,n.db,n.db.iconCorners
  for _,gate in ipairs({'noRec','empty','noItem','noMode','noDb','noCorners'})do
   gates=gates+1;b.rec=rec;b.mode=mode;b.hasItem=has;n.db=db;db.iconCorners=corners;rec.empty=nil
   if gate=='noRec'then b.rec=nil elseif gate=='empty'then rec.empty=true elseif gate=='noItem'then b.hasItem=nil elseif gate=='noMode'then b.mode=nil elseif gate=='noDb'then n.db=nil elseif gate=='noCorners'then db.iconCorners=nil end
   b.questMark:Show();b.questShade:Show();local allocations=#b.regions
   local saved={};for _,method in ipairs({'SetPoint','ClearAllPoints','SetSize','SetParent','CreateTexture'})do saved[method]=b[method];b[method]=function()error('unexpected frame operation '..method)end end
   local ok,err=pcall(function()n.Corners:Apply(b,true)end)
   for method,fn in pairs(saved)do b[method]=fn end
   check(ok,skin..' '..view..' '..gate..' no frame geometry/allocation operation '..tostring(err))
   check(not b.questMark:IsShown() and not b.questShade:IsShown(),skin..' '..view..' '..gate..' both initialized marks hidden')
   check(#b.regions==allocations,skin..' '..view..' '..gate..' texture allocation stable')
   b.rec=rec;b.mode=mode;b.hasItem=has;n.db=db;db.iconCorners=corners;rec.empty=nil;n.Corners:Apply(b,true)
   check(b.questMark:IsShown() and b.questShade:IsShown(),skin..' '..view..' '..gate..' restores when live again')
  end
 end
end
print('NONLIVE_GATES',gates)
