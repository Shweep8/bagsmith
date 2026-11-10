#!/usr/bin/env python3
# (1.6.0-beta11) The 1.6.0-beta10 audit's numeric-domain oracle (docs/plugins/audit-1.6.0-beta10/independent-probe/
# numeric_domain_oracle.py), unchanged. Usage, from the working copy: python3 tools/numeric_oracle.py . BagSmith
"""Independent exact-integer oracle for beta10 normalized-cent policy.
Arg1: supplied working repository. Arg2: candidate core. No product edits.
Prices are cents of a copper; expected comparisons use Python arbitrary integers.
The live integration probe is separate; fractional mats here test Verdict's domain.
"""
import os,sys,json,random,math
from pathlib import Path
from lupa.lua51 import LuaRuntime
repo,core=[Path(p).resolve() for p in sys.argv[1:3]];os.chdir(repo)
L=LuaRuntime(unpack_returned_tuples=True);L.globals().AUDIT_CORE=str(core)
L.execute('''package.path='./tests/?.lua;'..package.path
package.loaded.mock=nil;local M=require('mock')
BagSmithCharDB={version=1,firstSeen={}};BagSmithDB={version=2,chars={},cache={},profiles={Default={deEnabled=true,deLeveling='never'}}}
Auctionator={API={v1={GetAuctionPriceByItemLink=function()return 1 end,GetAuctionPriceByItemID=function()return 1 end}}};BlackthornesTS_API=nil
GetNumSkillLines=function()return 1 end;GetSkillLineInfo=function()return 'Enchanting',false,nil,120,0,0,150 end
n=M.loadAddon(AUDIT_CORE);M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers()
function verdict(v,a,m,dm,am,lv)
 n.db.deMargin=dm/100;n.db.deAhMargin=am/100;n.db.deLeveling=lv and 'always' or 'never'
 return n.Disenchant:Verdict({vendor=v,ah=a,mats=m})
end
for i=1,30 do local name,fn=debug.getupvalue(n.Disenchant.Verdict,i);if name=='hundredths' then normalize=fn end end
''')
f=L.globals().verdict;norm=L.globals().normalize;CAP=2147483647*100
results={};rng=random.Random(161010)
def expect(v,a,m,dm,am,lv):
 best=max(v*100,a*95);mv=m*(100 if lv else 95)
 if mv>0 and mv*100>=best*(90 if lv else 100+dm):return 'de'
 if a*95>v*100 and a*95*100>=v*100*(100+am):return 'ah'
 return 'vendor'
def run(v,a,m,dm,am,lv,kind):
 if not all(0<=x<=CAP for x in (v,a,m)):return
 r=results.setdefault(kind,dict(cases=0,mismatches=0,examples=[]));r['cases']+=1
 want=expect(v,a,m,dm,am,lv);got=f(v/100,a/100,m/100,dm,am,lv)
 if got!=want:
  r['mismatches']+=1
  if len(r['examples'])<10:r['examples'].append(dict(cents=[v,a,m],dm=dm,am=am,lv=lv,want=want,got=got))
# Every allowed whole-percent margin. Coprime exact ties, +/- 1 normalized cent.
for dm in range(201):
 for s in [1,2,95,100,1234567,CAP//300]:
  g=math.gcd(95,100+dm);v=95//g*s;eq=(100+dm)//g*s
  for d in [-1,0,1]:
   run(v,eq+d,0,10,dm,False,'whole-percent exact ties and cent neighbors')
   run(v,0,eq+d,dm,20,False,'whole-percent exact ties and cent neighbors')
  g=math.gcd(100,100+dm);a=100//g*s;eq=(100+dm)//g*s
  for d in [-1,0,1]:run(0,a,eq+d,dm,20,False,'whole-percent exact ties and cent neighbors')
  for d in [-1,0,1]:
   run(10*s,0,9*s+d,dm,dm,True,'leveling exact ties and cent neighbors')
   run(0,200*s,171*s+d,dm,dm,True,'leveling exact ties and cent neighbors')
# Both margin settings full cross-product and either side of the exact integer-cent DE boundary.
for dm in range(201):
 for am in range(201):
  for lv in [False,True]:
   for v,a in [(1900,2400),(CAP,0),(0,CAP),(CAP//2,CAP)]:
    den=(100 if lv else 95)*100;num=max(v*100,a*95)*(90 if lv else 100+dm)
    threshold=(num+den-1)//den
    for d in [-1,0,1]:run(v,a,threshold+d,dm,am,lv,'margin cross-product within money cap')
# Random arbitrary hundredth prices within cap.
for _ in range(100000):
 v=rng.randrange(CAP+1);a=rng.randrange(CAP+1);dm=rng.randrange(201);am=rng.randrange(201);lv=bool(rng.randrange(2))
 den=(100 if lv else 95)*100;num=max(v*100,a*95)*(90 if lv else 100+dm);threshold=(num+den-1)//den
 run(v,a,threshold+rng.randrange(-1,2),dm,am,lv,'random cent boundaries within money cap')
# Actual Entries domain: vendor & mats whole copper, provider quote any hundredth.
for _ in range(100000):
 v=rng.randrange(CAP//100+1)*100;a=rng.randrange(CAP+1);dm=rng.randrange(201);am=rng.randrange(201);lv=bool(rng.randrange(2))
 den=(100 if lv else 95)*100;num=max(v*100,a*95)*(90 if lv else 100+dm);threshold=(num+den*100-1)//(den*100)*100
 run(v,a,threshold+rng.randrange(-1,2)*100,dm,am,lv,'reachable whole mats and vendor, fractional provider')
# Inspect actual helper for half-thousandths. Does not count as gameplay scenarios.
if norm:
 for kind,indices in [('decimal half-hundredth normalizer small prices',range(100000)),('decimal half-hundredth normalizer across money cap',[rng.randrange(CAP) for _ in range(100000)])]:
  r=results.setdefault(kind,dict(cases=0,mismatches=0,examples=[]))
  for c in indices:
   text=str((c*10+5)//1000)+'.'+str((c*10+5)%1000).zfill(3);v=float(text);want=c+1;got=norm(v);r['cases']+=1
   if got!=want:
    r['mismatches']+=1
    if len(r['examples'])<10:r['examples'].append(dict(input=text,want=want,got=got))
print(json.dumps(dict(core=str(core),money_cap_copper=CAP//100,seed=161010,groups=results),indent=2))
