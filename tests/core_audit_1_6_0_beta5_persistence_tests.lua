-- 1.6.0-beta6: the 1.6.0-beta5 audit's own probe (persistence_opacity_probe.lua, unchanged), kept in the suite so its findings stay fixed. It failed on
-- beta5 as the audit reported; it must pass from beta6 on. Evidence and the report: docs/plugins/audit-1.6.0-beta5/.
-- Independent matrix, unmodified core; mocked frame state, not native pixels.
local function boot(skin,profile)
 package.loaded.mock=nil; local M=require('mock')
 _G.Auctionator=nil; _G.BlackthornesTS_API=nil
 _G.BagSmithCharDB={version=1,firstSeen={}}
 profile=profile or {}; profile.skin=skin
 _G.BagSmithDB={version=2,chars={},cache={},profiles={Default=profile}}
 local n=M.loadAddon('BagSmith'); M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers(); M.runTimers()
 return n,M
end
for _,skin in ipairs({'modern','classic'}) do
 local n,M=boot(skin); n.Window:Show(); M.runTimers(); local f=n.Window.main.frame
 for _,whole in ipairs({false,true}) do for _,base in ipairs({0,0.2,0.5,1}) do for _,moving in ipairs({false,true}) do for _,combat in ipairs({false,true}) do for _,fadeCombat in ipairs({false,true}) do for _,lock in ipairs({false,true}) do
  n.db.bgWhole=whole;n.db.bgOpacity=base;n.db.fadeMoving=true;n.db.movingAlpha=0.3;n.db.combatAlpha=0.1;n.db.combatFade=fadeCombat;n.db.combatLock=lock;n.moving=moving
  n:ApplyBgOpacity();n:ApplyCombatFade(combat)
  local want=whole and base or 1
  if combat and fadeCombat then want=math.min(want,0.1) elseif not combat and moving then want=math.min(want,0.3) end
  check(math.abs(f:GetAlpha()-want)<1e-9,'alpha matrix '..skin)
  check((f.bsShield:IsShown() and true or false)==(combat and fadeCombat and lock),'shield matrix '..skin)
 end end end end end end
 -- Existing 620 widths retained, malformed/small values clamp to new minima.
 local name=n.Profiles:Import('Widths',{fixW=1,maxW=1,bankW=1,priceSource='unknown'});n.Profiles:Use(name);M.runTimers()
 check(n.db.fixW==440 and n.db.maxW==440 and n.db.bankW==500 and n.db.priceSource=='auto','width/source validation '..skin)
 name=n.Profiles:Import('Old620',{fixW=620,maxW=620,bankW=620});n.Profiles:Use(name);M.runTimers()
 check(n.db.fixW==620 and n.db.maxW==620 and n.db.bankW==620,'existing widths retained '..skin)
 local C=n.Corners
 for _,corner in ipairs(C.CORNERS) do
  C:PlaceAt('quest_start',corner);C:PlaceAt('quantity',corner)
  check(n.db.iconCorners[corner][1]=='quest_start' and n.db.iconCorners[corner][2]=='quantity','locked order '..skin..' '..corner)
  C:ClearCorner(corner);check(n.db.iconCorners[corner][1]=='quest_start' and n.db.iconCorners[corner][2]=='quantity','None preserves locked marks '..skin..' '..corner)
 end
 C:Reset();check(C:CornerOf('quest_start')=='top_left' and C:CornerOf('quantity')=='bottom_right','Reset restores locked homes '..skin)
 local fn=function() return false end
 check(not n.API.RegisterCornerWidget('Replace quest','quest_start',fn,fn,{corner='top_left',priority=1}),'plugin cannot claim built-in quest id '..skin)
 check(n.API.RegisterCornerWidget('Priority','audit.priority',fn,fn,{corner='top_left',priority=-100}),'plugin valid priority accepted '..skin)
 check(n.db.iconCorners.top_left[1]=='quest_start','plugin cannot outrank locked quest '..skin)
 -- Existing valid full corner has 16 placements; migration adds one, then sharing/reload sanitizer clips 17th.
 local raw={iconCorners={top_left={},top_right={},bottom_left={},bottom_right={'quantity'}},iconCornersInserted={}}
 raw.iconCornersInserted['audit.priority']=true
 for i=1,16 do local id='audit.tail'..i;raw.iconCorners.top_left[i]=id;raw.iconCornersInserted[id]=true end
 name=n.Profiles:Import('FullOld',raw);n.Profiles:Use(name);M.runTimers()
 check(#n.db.iconCorners.top_left==17 and C:CornerOf('audit.tail16')=='top_left','setup: old full corner migrated with quest inserted '..skin)
 local round=n.Profiles:Import('RoundTrip',n.Copy(n.db));n.Profiles:Use(round);M.runTimers()
 print('OBS '..skin..' corner roundtrip length='..#n.db.iconCorners.top_left..' tail16='..tostring(C:CornerOf('audit.tail16')))
 check(C:CornerOf('audit.tail16')=='top_left','New quest migration preserves all existing placements across sharing/reload ('..skin..')')
end
