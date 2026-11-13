-- 1.7.1-beta2: the 1.7.1-beta1 audit's own probe (currency/ui_routes.lua), unchanged. Evidence and the report:
-- docs/plugins/audit-1.7.1-beta1/.
;(function()
package.loaded.mock=nil;local M=require('mock')
BagSmithCharDB={version=1};BagSmithDB={version=2,chars={},cache={},profiles={Default={bagBar=true}}}
local n=M.loadAddon('BagSmith');M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');n.Window:Show();M.runTimers()
local calls,puts,backs=0,0,0;local accept=false;local bagarg,invarg
n.SwapHint.Intercept=function(self,bag,inv) calls=calls+1;bagarg,invarg=bag,inv;return accept end
PutItemInBag=function(inv) puts=puts+1;check(inv==invarg,'fallback same inventory slot') end
PutItemInBackpack=function() backs=backs+1 end
local function reset() calls,puts,backs=0,0,0 end
for _,b in ipairs(n.Window.main.bagBar.slots) do
 for _,route in ipairs({'OnClick','OnReceiveDrag'}) do
  for _,a in ipairs({false,true}) do
   reset();accept=a;M.cursorItem=2589;b:GetScript(route)(b,'LeftButton')
   if b.bag==0 then check(calls==0 and puts==0 and backs==1,'backpack bypass '..route)
   elseif b.inv then check(calls==1 and bagarg==b.bag and invarg==b.inv,'bag intercept args '..route);check(puts==(a and 0 or 1),'bag fallback '..route) end
  end
 end
end
n.atBank=true;n.Bank.supported=true;n:Set('replaceBank',true)
local bar=CreateFrame('Frame',nil,UIParent);n.Bank:FillBar(bar)
check(bar.slots and #bar.slots>0,'bank slots constructed')
for _,b in ipairs(bar.slots or {}) do
 for _,route in ipairs({'OnClick','OnReceiveDrag'}) do
  for _,a in ipairs({false,true}) do
   reset();accept=a;M.cursorItem=2589;b:GetScript(route)(b,'LeftButton')
   if b.purchased and b.invID then check(calls==1 and bagarg==nil and invarg==b.invID,'bank intercept args '..route);check(puts==(a and 0 or 1),'bank fallback '..route)
   else check(calls==0 and puts==0,'unbought not swap '..route) end
  end
 end
end
end)()
