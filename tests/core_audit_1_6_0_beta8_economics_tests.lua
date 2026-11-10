-- 1.6.0-beta9: the 1.6.0-beta8 audit's own probe (independent/de_economics_probe.lua, unchanged), kept in the suite. Evidence and the report:
-- docs/plugins/audit-1.6.0-beta8/. (1.6.0-beta10, adapted by design and marked: Shweep's 10% leveling leeway, so the oracle's
-- forced-leveling Disenchant margin is -10, where it was 0; nothing else changed.)
-- Independent beta8 economics oracle. Product source unchanged. All values are mock copper.
package.loaded.mock=nil
local M=require('mock')
_G.BagSmithCharDB={version=1,firstSeen={}}
_G.BagSmithDB={version=2,chars={},cache={},profiles={Default={deEnabled=true,deLeveling='never'}}}
_G.Auctionator={API={v1={GetAuctionPriceByItemLink=function()return 1 end,GetAuctionPriceByItemID=function()return 1 end}}}
_G.BlackthornesTS_API=nil
local skill={rank=120,cap=150}
_G.GetNumSkillLines=function()return 1 end
_G.GetSkillLineInfo=function()return 'Enchanting',false,nil,skill.rank,0,0,skill.cap end
local n=M.loadAddon(AUDIT_CORE or 'BagSmith')
M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers()
local D=n.Disenchant
local mismatch,examples=0,{}
local kinds,equality,wholeCopper={},0,0
local maxGap=0
local firstKind={};local deWholeCopper=0
local cases=0
-- Integer-scaled independent oracle: net values are hundredths of copper, margins percent.
local function oracle(v,a,m,dm,am,lv)
 if m==nil then return 'unknown' end
 local net=a*95;local value=m*(lv and 100 or 95)
 if value>0 and value*100>=math.max(v*100,net)*(100+(lv and -10 or dm)) then return 'de' end   -- (adapted: -10, was 0)
 if net>v*100 and net*100>=v*100*(100+am) then return 'ah' end
 return 'vendor'
end
local prices={0,1,2,19,20,24,38,48,76,96,95,100,120,190,240,380,480,760,960,1900,2400,19000,24000}
for _,mode in ipairs({'never','always'}) do
 n.db.deLeveling=mode
 for _,dm in ipairs({0,5,10,20,30,100,200}) do
  n.db.deMargin=dm/100
  for _,am in ipairs({0,5,10,20,30,100,200}) do
   n.db.deAhMargin=am/100
   for _,v in ipairs(prices) do for _,a in ipairs(prices) do
    for _,m in ipairs({0,1,19,24,100,120,240,480,1000,24000}) do
     local expected=oracle(v,a,m,dm,am,mode=='always')
     local actual=D:Verdict({vendor=v,ah=a,mats=m});cases=cases+1
     if actual~=expected then
      mismatch=mismatch+1;kinds[expected..'->'..actual]=(kinds[expected..'->'..actual]or 0)+1
      local left,right
      if expected=='de'then left=m*(mode=='always'and 100 or 95)*100;right=math.max(v*100,a*95)*(100+(mode=='always'and -10 or dm))
      else left=a*95*100;right=v*100*(100+am)end
      if left==right then equality=equality+1 end
      if expected=='ah'and a*95%100==0 then wholeCopper=wholeCopper+1 end
      local gap
      if expected=='de'then gap=math.abs(m*(mode=='always'and 1 or .95)-math.max(v,a*.95)*(1+(mode=='always'and -0.10 or dm/100)));if m*(mode=='always'and 100 or 95)%100==0 then deWholeCopper=deWholeCopper+1 end
      else gap=math.abs(a*.95-v*(1+am/100))end
      if gap>maxGap then maxGap=gap end
      local kind=expected..'->'..actual
      if not firstKind[kind]then firstKind[kind]=true;print('FIRST_KIND',kind,mode,'vendor='..v,'ah='..a,'mats='..m,'DEmargin='..dm,'AHmargin='..am,'gap='..string.format('%.17g',gap))end
      if #examples<15 then examples[#examples+1]=table.concat({mode,'vendor='..v,'ah='..a,'mats='..m,'DEmargin='..dm,'AHmargin='..am,'expected='..expected,'actual='..actual},' ') end end
    end
   end end
  end
 end
end
print('ORACLE_CASES',cases,'MISMATCHES',mismatch)
for k,v in pairs(kinds)do print('MISMATCH_KIND',k,v)end
print('EXACT_EQUALITY',equality,'AH_WHOLE_NET_COPPER',wholeCopper,'DE_WHOLE_NET_COPPER',deWholeCopper,'MAX_FLOAT_GAP',maxGap)
for _,e in ipairs(examples)do print('ORACLE_MISMATCH',e)end
check(mismatch==0,'exact-rational 5% cut/percent margin oracle: '..mismatch..' discrepancies out of '..cases)
-- Named user-visible exact-boundary reproductions; each side is retained as a control.
n.db.deLeveling='never';n.db.deMargin=.1;n.db.deAhMargin=.2
for _,a in ipairs({23,24,25})do
 local actual=D:Verdict({vendor=19,ah=a,mats=1})
 print('AH_20_PERCENT_BOUNDARY','vendor=19','ah='..a,'actual='..actual,'net='..string.format('%.17g',a*.95),'threshold='..string.format('%.17g',19*1.2))
 check(actual==(a<24 and 'vendor' or 'ah'),'19c vendor and '..a..'c AH at 20% margin')
end
-- Full integer skill state matrix, using independent bracket arithmetic.
for _,mode in ipairs({'auto','always','never'})do n.db.deLeveling=mode
 for rank=1,300 do
  skill.rank=rank
  for _,given in ipairs({false,75,150,225,300})do
   skill.cap=given or nil
   local expectedcap=given or (math.ceil(rank/75)*75)
   local expected=mode=='always' or (mode=='auto' and rank<expectedcap)
   local got,r,c=D:Leveling()
   check(got==expected and r==rank and c==expectedcap,'skill '..mode..' '..rank..'/'..tostring(given))
  end
 end
end
-- Skill API failures are not interpreted as automatic leveling.
n.db.deLeveling='auto'
for _,fault in ipairs({'count_throw','line_throw','nilrank','nilapi','absentprofession','localized'})do
 _G.GetNumSkillLines=function()return 1 end
 _G.GetSkillLineInfo=function()return 'Enchanting',false,nil,120,0,0,150 end
 _G.GetSpellInfo=function()return nil end
 if fault=='count_throw'then _G.GetNumSkillLines=function()error('count fault')end
 elseif fault=='line_throw'then _G.GetSkillLineInfo=function()error('line fault')end
 elseif fault=='nilrank'then _G.GetSkillLineInfo=function()return 'Enchanting',false end
 elseif fault=='nilapi'then _G.GetSkillLineInfo=nil
 elseif fault=='absentprofession'then _G.GetSkillLineInfo=function()return 'Alchemy',false,nil,120,0,0,150 end
 elseif fault=='localized'then _G.GetSkillLineInfo=function()return 'Verzauberkunst',false,nil,120,0,0,150 end;_G.GetSpellInfo=function(id)if id==7411 then return 'Verzauberkunst' end end end
 local ok,result=pcall(D.Leveling,D)
 check(ok and result==(fault=='localized'),'automatic skill read '..fault..' fails closed or recognizes localized profession')
end
-- Missing material/provider stay distinct from an economic recommendation in each new mode.
for _,mode in ipairs({'auto','always','never'})do
 n.db.deLeveling=mode
 check(D:Verdict({vendor=100,ah=200})=='unknown',mode..' missing mats unknown')
 local saved=Auctionator;Auctionator=nil;n.AH:CheckSource()
 check(D:Verdict({vendor=100,ah=200,mats=300})=='call',mode..' unavailable provider remains your call')
 Auctionator=saved;n.AH:CheckSource()
end
