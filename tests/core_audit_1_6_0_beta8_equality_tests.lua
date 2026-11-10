-- 1.6.0-beta9: the 1.6.0-beta8 audit's own probe (independent/de_equality_control.lua, unchanged), kept in the suite. Evidence and the report:
-- docs/plugins/audit-1.6.0-beta8/.
-- The common 5% factor should cancel when comparing AH item and AH material totals.
-- This expectation is unchanged in beta7 and beta8: a 20% materials premium meets a 20% DE margin.
package.loaded.mock=nil
local M=require('mock')
_G.BagSmithCharDB={version=1,firstSeen={}}
_G.BagSmithDB={version=2,chars={},cache={},profiles={Default={deEnabled=true,deLeveling='never',deMargin=.2,deAhMargin=0}}}
_G.Auctionator={API={v1={GetAuctionPriceByItemLink=function()return 1 end,GetAuctionPriceByItemID=function()return 1 end}}}
_G.BlackthornesTS_API=nil
_G.GetNumSkillLines=function()return 1 end
_G.GetSkillLineInfo=function()return 'Enchanting',false,nil,150,0,0,150 end
local n=M.loadAddon(AUDIT_CORE or 'BagSmith')
M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers()
for _,x in ipairs({{20,23},{20,24},{20,25},{40,48},{80,96},{100,120},{200,240}})do
 local got=n.Disenchant:Verdict({vendor=0,ah=x[1],mats=x[2]})
 local want=x[2]*100>=x[1]*120 and 'de'or'ah'
 print('COMMON_CUT_CONTROL','item='..x[1],'materials='..x[2],'expected='..want,'actual='..got)
 check(got==want,'AH item '..x[1]..', AH mats '..x[2]..', 20% DE margin (same ratio before/after common 5% cut)')
end
