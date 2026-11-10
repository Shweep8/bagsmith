#!/usr/bin/env python3
# (1.6.0-beta10) The 1.6.0-beta9 audit's integer oracle (docs/plugins/audit-1.6.0-beta9/independent-beta9/
# economics_integer_oracle.py), adapted by design and marked "(adapted ...)":
#  - Shweep's 10% leveling leeway: the forced-leveling Disenchant margin is -10, where it was 0.
#  Nothing else changed. (Prices are now compared to 1/100 copper, B9 A1: guaranteed exact up to about 3 x 10^9 copper,
#  past the gold cap of 2,147,483,647; the auditor's random group up to 3 x 10^11 still finds no mismatch.)
# Usage, from the working copy: python3 tools/economics_oracle.py . BagSmith
"""Independent arbitrary-precision integer oracle against actual Lua5.1 Verdict.
Arguments: working repository, candidate BagSmith core. Does not edit source.
"""
import os,sys,math,json,random
from pathlib import Path
from lupa.lua51 import LuaRuntime
repo,core=map(lambda x:Path(x).resolve(),sys.argv[1:3]);os.chdir(repo)
L=LuaRuntime(unpack_returned_tuples=True)
L.globals().AUDIT_CORE=str(core)
L.execute('''package.path='./tests/?.lua;'..package.path
package.loaded.mock=nil;M=require('mock')
BagSmithCharDB={version=1,firstSeen={}};BagSmithDB={version=2,chars={},cache={},profiles={Default={deEnabled=true,deLeveling='never'}}}
Auctionator={API={v1={GetAuctionPriceByItemLink=function()return 1 end,GetAuctionPriceByItemID=function()return 1 end}}};BlackthornesTS_API=nil
GetNumSkillLines=function()return 1 end;GetSkillLineInfo=function()return 'Enchanting',false,nil,120,0,0,150 end
n=M.loadAddon(AUDIT_CORE);M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers()
function verdict(v,a,m,dm,am,leveling)
 n.db.deMargin=dm/100;n.db.deAhMargin=am/100;n.db.deLeveling=leveling and 'always' or 'never'
 return n.Disenchant:Verdict({vendor=v,ah=a,mats=m})
end
''')
f=L.globals().verdict;total=0;bad=[];kinds={}
def oracle(v,a,m,dm,am,lv):
 best=max(v*100,a*95);mv=m*(100 if lv else 95)
 if mv>0 and mv*100>=best*(100+(-10 if lv else dm)):return 'de'   # (adapted: -10, was 0)
 if a*95>v*100 and a*95*100>=v*100*(100+am):return 'ah'
 return 'vendor'
def run(v,a,m,dm,am,lv,kind):
 global total
 want=oracle(v,a,m,dm,am,lv);got=f(v,a,m,dm,am,lv);total+=1;kinds[kind]=kinds.get(kind,0)+1
 if want!=got and len(bad)<50:bad.append(dict(v=v,a=a,m=m,dm=dm,am=am,leveling=lv,expected=want,actual=got,kind=kind))
# Every whole percent, generated exact ties and immediate copper neighbors.
scales=[1,2,19,95,100,1234567,1000000000]
for pct in range(201):
 for s in scales:
  # v*100*(100+pct)==a*95*100 and de(v,m) identical equation.
  g=math.gcd(95,100+pct);v=95//g*s;eq=(100+pct)//g*s
  for d in (-1,0,1):
   a=max(0,eq+d);run(v,a,0,10,pct,False,'AH exact tie neighbors')
   run(v,0,a,pct,20,False,'DE vendor exact tie neighbors')
  # common 95% cut cancels exactly for item/material AH ratio.
  g=math.gcd(100,100+pct);a=100//g*s;eq=(100+pct)//g*s
  for d in (-1,0,1):run(0,a,max(0,eq+d),pct,20,False,'DE AH exact tie neighbors')
  # Full-value leveling ties versus vendor and net AH.
  for d in (-1,0,1):
   run(s,0,max(0,s+d),pct,pct,True,'leveling vendor tie neighbors')
   run(0,100*s,max(0,95*s+d),pct,pct,True,'leveling AH tie neighbors')
# Full whole-percent cross-product at independently selected near-boundary values.
for dm in range(201):
 for am in range(201):
  for lv in (False,True):
   for v,a in [(19,24),(100,120),(1234567,1789123),(2147483647,2259999999)]:
    threshold=(max(v*100,a*95)*(100+(-10 if lv else dm))+(100 if lv else 95)*100-1)//((100 if lv else 95)*100)   # (adapted)
    for d in (-1,0,1):run(v,a,max(0,threshold+d),dm,am,lv,'margin cross-product DE boundary')
# Deterministic mixed-scale random nearest-boundary samples through claimed exact range.
rng=random.Random(16609)
for _ in range(100000):
 v=rng.randrange(300000000000);a=rng.randrange(300000000000);dm=rng.randrange(201);am=rng.randrange(201);lv=bool(rng.randrange(2))
 threshold=(max(v*100,a*95)*(100+(-10 if lv else dm))+(100 if lv else 95)*100-1)//((100 if lv else 95)*100)   # (adapted)
 # Keep every input below declared approximate bound; products cannot exceed 9e15.
 m=max(0,threshold+rng.randrange(-1,2))
 if m<300000000000:run(v,a,m,dm,am,lv,'random integer boundaries below 3e11')
print(json.dumps(dict(core=str(core),cases=total,mismatches=len(bad),examples=bad,groups=kinds),indent=2))
raise SystemExit(bool(bad))
