-- 1.6.0-beta11: the 1.6.0-beta10 audit's own probe (independent-probe/rounding_provider_probe.lua, its checks unchanged), kept in the suite. Evidence and the
-- report: docs/plugins/audit-1.6.0-beta10/.
-- (Run by the suite's runner, which has no AUDIT_CORE: the working copy's BagSmith. The only line added to the probe.)
AUDIT_CORE = AUDIT_CORE or "BagSmith"
-- Independent beta10 probe. Product sources remain unchanged.
package.loaded.mock=nil;local M=require('mock')
M.put(0,1,{id=7001,name='Rare Fractional Boots',q=3,count=1,class=4,subclass=1,price=0,ilvl=23,equip='INVTYPE_FEET'})
BagSmithCharDB={version=1,firstSeen={}};BagSmithDB={version=2,chars={},cache={},profiles={Default={deEnabled=true,deLeveling='never'}}}
local gross,material=8200.005,9020
local function source(_,item)local id=tonumber(item)or tonumber(tostring(item):match('item:(%d+)'));return id==7001 and gross or material end
Auctionator={API={v1={GetAuctionPriceByItemLink=source,GetAuctionPriceByItemID=source}}};BlackthornesTS_API=nil
GetNumSkillLines=function()return 1 end;GetSkillLineInfo=function()return 'Enchanting',false,nil,120,0,0,150 end
local n=M.loadAddon(AUDIT_CORE);M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers()
n:Set('deMargin',.10)
for _,case in ipairs({{8200.0049,'de'},{8200.005,'ah'},{8200.0051,'ah'}}) do
 gross=case[1];local q=n.AH:Price({itemID=7001,link='item:7001'});local e=n.Disenchant:Entries()[1]
 print('HALF_HUNDREDTH', 'quote='..string.format('%.17g',gross),'rounded='..tostring(math.floor(gross*100+.5)), 'mats='..material,'expected='..case[2],'actual='..tostring(e and e.verdict))
 check(q==gross,'provider quote preserved '..gross)
 check(e and e.ah==gross and e.mats==material,'scanner and Entries retain raw quote and expected materials '..gross)
 check(e and e.verdict==case[2],'nearest hundredth, decimal half up: '..gross)
end
-- Different ordinary margins show this is the input-normalizer, not old cross-product equality.
for _,c in ipairs({{1.005,1,0},{8200.005,8610,.05},{8200.005,9020,.1},{8195.005,9834,.2},{8192.005,10240,.25}})do
 gross,material=c[1],c[2];n:Set('deMargin',c[3]);local e=n.Disenchant:Entries()[1]
 print('PROVIDER_TIE',gross,material,c[3],e and e.verdict)
 check(e and e.verdict=='ah','fractional provider decimal-half '..gross..' margin '..c[3]) -- replaced below
end
