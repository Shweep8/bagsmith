#!/usr/bin/env python3
# (1.6.0) The 1.6.0-beta11 audit's decimal_policy_oracle.py (docs/plugins/audit-1.6.0-beta11/independent/), unchanged.
# Usage, from the working copy: python3 tools/decimal_oracle.py . BagSmith
"""Independent decimal-policy probe. Decimal arithmetic consumes Lua's %.14g representation,
not implementation string-parsing; candidate source unchanged. Does not exercise live prices."""
from pathlib import Path
from decimal import Decimal, ROUND_HALF_UP
import os,sys,random,json,math
from lupa.lua51 import LuaRuntime
repo,core=[Path(p).resolve() for p in sys.argv[1:3]];os.chdir(repo)
L=LuaRuntime(unpack_returned_tuples=True);L.globals().AUDIT_CORE=str(core)
L.execute('''package.path='./tests/?.lua;'..package.path
package.loaded.mock=nil;local M=require('mock')
BagSmithCharDB={version=1,firstSeen={}};BagSmithDB={version=2,chars={},cache={},profiles={Default={deEnabled=true,deLeveling='never'}}}
Auctionator={API={v1={GetAuctionPriceByItemLink=function()return 1 end,GetAuctionPriceByItemID=function()return 1 end}}};BlackthornesTS_API=nil
n=M.loadAddon(AUDIT_CORE);M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers()
function fmt(v)return ('%.14g'):format(v)end
function verdict(v,a,m,dm,am,lv,bound)
 n.db.deMargin=dm;n.db.deAhMargin=am;n.db.deLeveling=lv and 'always' or 'never'
 return n.Disenchant:Verdict({vendor=v,ah=a,mats=m,bound=bound})
end''')
f=L.globals().verdict;norm=L.globals().n.Disenchant.DecimalHundredths;fmt=L.globals().fmt
r={};rng=random.Random(161111);cap=2147483647
# Use Python's arbitrary decimal quantization to implement the documented policy independently.
def want(v):return int((Decimal(fmt(v))*100).quantize(Decimal(1),rounding=ROUND_HALF_UP))
def record(kind,ok,case):
 d=r.setdefault(kind,{'cases':0,'failures':0,'examples':[]});d['cases']+=1
 if not ok:
  d['failures']+=1
  if len(d['examples'])<12:d['examples'].append(case)
def test(v,kind):
 got=norm(v);w=want(v);record(kind,got==w,{'value17':format(v,'.17g'),'written14':fmt(v),'want':w,'got':got})
 # normalization must be stable at the documented supported cap.
 record('idempotence within cap',norm(got/100)==got,{'value':v,'normalized':got,'renormalized':norm(got/100)})
for i in range(100000):
 c=rng.randrange(cap*100);half=(c+0.5)/100
 for x in [math.nextafter(half,-math.inf),half,math.nextafter(half,math.inf),half-0.0001,half+0.0001]:test(x,'price-half neighborhood across cap')
for i in range(100000):test(rng.random()*cap,'arbitrary provider doubles within cap')
for boundary in [0,0.005,0.015,0.995,1.005,9.995,99.995,999.995,9999.995,99999.995,999999.995,9999999.995,99999999.995,999999999.995,cap-0.005,cap]:
 for k in range(-30,31):
  x=boundary
  for j in range(abs(k)):x=math.nextafter(x,math.inf if k>=0 else -math.inf)
  if 0<=x<=cap:test(x,'decimal carry and significant-digit transitions')
for exponent in range(-323,-3):
 for mant in [1,3,5,9]:
  x=float(f'{mant}e{exponent}');test(x,'tiny exponent fallback')
for p in range(200):
 half=(p+0.5)/100
 for d in [-1e-8,-1e-11,-1e-14,-1e-16,0,1e-16,1e-14,1e-11,1e-8]:test(half+d,'all imported margin half boundaries')
for i in range(100000):
 v=rng.random()*cap;a=rng.random()*cap;m=rng.random()*cap;dm=rng.random()*2;am=rng.random()*2;lv=bool(rng.getrandbits(1));bound=bool(rng.getrandbits(1))
 V,A,M=want(v),0 if bound else want(a),want(m);DM,AM=want(dm),want(am);best=max(V*100,A*95);mv=M*(100 if lv else 95)
 w='de' if mv>0 and mv*100>=best*(90 if lv else 100+DM) else 'ah' if A*95>V*100 and A*95*100>=V*100*(100+AM) else 'vendor'
 got=f(v,a,m,dm,am,lv,bound);record('random full verdict with decimal margins and bound',got==w,{'v':v,'a':a,'m':m,'dm':dm,'am':am,'lv':lv,'bound':bound,'want':w,'got':got})
print(json.dumps({'core':str(core),'policy':'ROUND_HALF_UP(Decimal(Lua %.14g(v))*100)','seed':161111,'groups':r},indent=2))
sys.exit(1 if any(d['failures'] for d in r.values())else 0)
