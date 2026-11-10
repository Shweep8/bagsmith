-- 1.6.0-beta10: the 1.6.0-beta9 audit's own probe (independent-beta9/economics_offstep_control.lua, its checks unchanged), kept in the suite. Evidence and the
-- report: docs/plugins/audit-1.6.0-beta9/.
-- (Run by the suite's runner, which has no AUDIT_CORE: the working copy's BagSmith. The only line added to the probe.)
AUDIT_CORE = AUDIT_CORE or "BagSmith"
-- Scope probes outside normal whole-copper/5%-slider use. Source unchanged.
package.loaded.mock=nil;local M=require('mock')
M.put(0,1,{id=7001,name='Rare Boundary Boots',q=3,count=1,class=4,subclass=1,price=0,ilvl=23,equip='INVTYPE_FEET'})
_G.BagSmithCharDB={version=1,firstSeen={}}
_G.BagSmithDB={version=2,chars={},cache={},profiles={Default={deEnabled=true,deLeveling='never'}}}
local gross=8.8
local function source(_,item) local id=tonumber(item)or tonumber(tostring(item):match('item:(%d+)'));return id==7001 and gross or 11 end
_G.Auctionator={API={v1={GetAuctionPriceByItemLink=source,GetAuctionPriceByItemID=source}}}
_G.BlackthornesTS_API=nil
_G.GetNumSkillLines=function()return 1 end
_G.GetSkillLineInfo=function()return 'Enchanting',false,nil,120,0,0,150 end
local n=M.loadAddon(AUDIT_CORE);M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers()
local D=n.Disenchant
-- A publicly accepted finite positive fractional provider quote.
n:Set('deMargin',.25)
local quoted=n.AH:Price({itemID=7001,link='item:7001'})
print('FRACTIONAL_PROVIDER','AH='..tostring(quoted),'mats=11','DEmargin=25%','expected=de','actual='..D:Verdict({vendor=0,ah=quoted,mats=11}))
print('FLOAT_OPERANDS',string.format('%.17g',11*95*100),string.format('%.17g',quoted*95*125))
check(quoted==8.8,'fractional finite positive provider quote is accepted unchanged')
check(D:Verdict({vendor=0,ah=quoted,mats=11})=='de','exact decimal tie 8.8c item AH / 11c mats at 25% qualifies for disenchant')
local entries=D:Entries();local entry=entries[1]
check(entry and entry.itemID==7001 and entry.ah==8.8 and entry.mats==11,'real scanner/Entries path keeps fractional item quote and whole material estimate')
check(entry and entry.verdict=='de','real entry should recommend DE at 25% decimal equality')
-- Nearest whole percent policy for supported saved/imported off-step margins.
local profile=n.Copy(n.db);profile.deMargin=.145;profile.deAhMargin=.145
local name=n.Profiles:Import('Half percent control',profile);n.Profiles:Use(name)
check(n.db.deMargin==.145 and n.db.deAhMargin==.145,'profile import/use preserves supported off-step half-percent values')
print('HALF_PERCENT_DE','saved='..tostring(n.db.deMargin),'scaled='..string.format('%.17g',n.db.deMargin*100),'vendor=95','mats=114','expected=vendor','actual='..D:Verdict({vendor=95,ah=0,mats=114}))
check(n.db.deMargin==.145,'settings validator keeps 14.5%')
check(D:Verdict({vendor=95,ah=0,mats=114})=='vendor','14.5% should round to 15%, not 14%')
n:Set('deMargin',.10);n:Set('deAhMargin',.145)
print('HALF_PERCENT_AH','saved='..tostring(n.db.deAhMargin),'vendor=95','ah=114','expected=vendor','actual='..D:Verdict({vendor=95,ah=114,mats=0}))
check(D:Verdict({vendor=95,ah=114,mats=0})=='vendor','AH margin 14.5% should round to 15%, not 14%')
-- Adjacent representable choices show the narrow half-percent scope.
for _,pct in ipairs({.1449,.1451,.14,.15,.20,.25})do
 n:Set('deMargin',pct)
 local expected=pct>=.145 and 'vendor' or 'de'
 check(D:Verdict({vendor=95,ah=0,mats=114})==expected,'neighbor margin '..tostring(pct))
end
