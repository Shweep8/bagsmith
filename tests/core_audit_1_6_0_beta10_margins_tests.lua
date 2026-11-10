-- 1.6.0-beta11: the 1.6.0-beta10 audit's own probe (independent-probe/margin_rounding_probe.lua, its checks unchanged), kept in the suite. Evidence and the
-- report: docs/plugins/audit-1.6.0-beta10/.
-- (Run by the suite's runner, which has no AUDIT_CORE: the working copy's BagSmith. The only line added to the probe.)
AUDIT_CORE = AUDIT_CORE or "BagSmith"
-- Independent check of imported margins and decimal-half normalizer tolerance.
package.loaded.mock=nil;local M=require('mock')
BagSmithCharDB={version=1,firstSeen={}};BagSmithDB={version=2,chars={},cache={},profiles={Default={deEnabled=true,deLeveling='never'}}}
Auctionator={API={v1={GetAuctionPriceByItemLink=function()return 1 end,GetAuctionPriceByItemID=function()return 1 end}}};BlackthornesTS_API=nil
GetNumSkillLines=function()return 1 end;GetSkillLineInfo=function()return 'Enchanting',false,nil,120,0,0,150 end
local n=M.loadAddon(AUDIT_CORE);M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers()
local whole
for i=1,30 do local name,fn=debug.getupvalue(n.Disenchant.Verdict,i);if name=='wholePct' then whole=fn end end
assert(whole,'actual candidate margin helper')
for pct=0,199 do
 for _,side in ipairs({-1,0,1})do
  local x=(pct+.5+side*.000001)/100
  check(whole(x,.1)==(side<0 and pct or pct+1),'whole percent decimal half and clear neighbor '..pct..' side '..side)
 end
end
local raw=n.Copy(n.db);raw.deMargin=.144999999995;raw.deAhMargin=.144999999995
local name=n.Profiles:Import('Sub-half margin tolerance',raw);n.Profiles:Use(name)
check(n.db.deMargin==.144999999995 and n.db.deAhMargin==.144999999995,'profile accepts margin infinitesimally below decimal half')
print('MARGIN_TOLERANCE','saved='..string.format('%.17g',n.db.deMargin),'percent='..string.format('%.17g',n.db.deMargin*100),'normalized='..tostring(whole(n.db.deMargin,.1)))
check(n.Disenchant:Verdict({vendor=95,ah=0,mats=114})=='de','strict half-up: 14.4999999995% stays14%, not15%, DE boundary')
check(n.Disenchant:Verdict({vendor=95,ah=114,mats=0})=='ah','strict half-up: 14.4999999995% stays14%, not15%, AH boundary')
