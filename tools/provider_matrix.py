#!/usr/bin/env python3
# (1.6.0) The 1.6.0-beta11 audit's provider_boundary_matrix.py (docs/plugins/audit-1.6.0-beta11/independent/), unchanged.
# Usage, from the working copy: python3 tools/provider_matrix.py . BagSmith
"""Fresh provider -> Scanner -> DE Entries probes with exact Decimal14 policy oracle.
No native provider or inventory invocation; executes candidate through supplied client mock."""
from pathlib import Path
from decimal import Decimal,ROUND_HALF_UP
import os,sys,random,json,math
from lupa.lua51 import LuaRuntime
repo,core=[Path(p).resolve() for p in sys.argv[1:3]];os.chdir(repo)
L=LuaRuntime(unpack_returned_tuples=True);L.globals().AUDIT_CORE=str(core)
L.execute('''package.path='./tests/?.lua;'..package.path
package.loaded.mock=nil;M=require('mock')
M.put(0,1,{id=7001,name='Rare Fractional Boots',q=3,count=1,class=4,subclass=1,price=0,ilvl=23,equip='INVTYPE_FEET'})
BagSmithCharDB={version=1,firstSeen={}};BagSmithDB={version=2,chars={},cache={},profiles={Default={deEnabled=true,deLeveling='never'}}}
gross,material,bound=8200.005,9020,false
local function quote(item)local id=tonumber(item)or tonumber(tostring(item):match('item:(%d+)'));return id==7001 and gross or material end
Auctionator={API={v1={GetAuctionPriceByItemLink=function(_,i)return quote(i)end,GetAuctionPriceByItemID=function(_,i)return quote(i)end}}}
BlackthornesTS_API={version=1,GetPrice=quote,GetPriceAge=function()return nil end}
GetNumSkillLines=function()return 1 end;GetSkillLineInfo=function()return 'Enchanting',false,nil,120,0,0,150 end
local ci=C_Container.GetContainerItemInfo
C_Container.GetContainerItemInfo=function(b,s)local v=ci(b,s);if v then v.isBound=bound end;return v end
n=M.loadAddon(AUDIT_CORE);M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers()
function fmt(v)return ('%.14g'):format(v)end
function test(src,g,m,dm,am,lv,b)
 gross,material,bound=g,m,b;n.db.priceSource=src;n.db.deMargin=dm;n.db.deAhMargin=am;n.db.deLeveling=lv and 'always' or 'never'
 n:Scan();local e=n.Disenchant:Entries()[1]
 return e and e.ah,e and e.mats,e and e.verdict,e and e.bound,e and e.vendor
end
''')
f=L.globals().test;fmt=L.globals().fmt;rng=random.Random(161112);cap=2147483647;r={}
def N(x):return int((Decimal(fmt(x))*100).quantize(Decimal(1),rounding=ROUND_HALF_UP))
def check(kind,ok,case):
 d=r.setdefault(kind,{'cases':0,'failures':0,'examples':[]});d['cases']+=1
 if not ok:
  d['failures']+=1
  if len(d['examples'])<10:d['examples'].append(case)
for source in ['auctionator','blackthornes']:
 for bound in [False,True]:
  for i in range(1200):
   c=rng.randrange(cap*25);half=(c+0.5)/100
   quote=[math.nextafter(half,-math.inf),half,math.nextafter(half,math.inf),half-.0001,half+.0001][i%5]
   dm=[0,.005,.05,.1,.144999999995,.145,.155,.25,.995,1.995,2][i%11];am=[0,.145,.2,2][i%4];lv=bool(i%2)
   eq=N(quote)*(90 if lv else 100+N(dm))/(10000 if lv else 10000) # same 95% cut cancels in Never
   if lv:eq*=.95 # leveling materials gross vs AH net
   mats=max(1,int(eq)+[-1,0,1][i%3])
   a,m,got,b,v=f(source,quote,mats,dm,am,lv,bound)
   A=0 if bound else N(quote);M=N(mats);mv=M*(100 if lv else 95)
   want='de' if mv>0 and mv*100 >= A*95*(90 if lv else 100+N(dm))else 'ah' if A>0 else 'vendor'
   case={'source':source,'quote17':format(quote,'.17g'),'written14':fmt(quote),'mats':mats,'dm':dm,'am':am,'lv':lv,'bound':bound,'actual':got,'expected':want}
   check(source+' raw entries',m==mats and (a is None if bound else a==quote) and bool(b)==bound and v==0,case)
   check(source+' recommendation',got==want,case)
print(json.dumps({'seed':161112,'path':'actual mocked provider -> scanner -> Entries','groups':r},indent=2))
sys.exit(1 if any(d['failures']for d in r.values())else 0)
