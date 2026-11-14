local ns={View={C={}},Buttons={created=true},db={}}
function ns:OnSignal() end
function ns:Guard(_,fn,...) return pcall(fn,...) end
local combat=false
InCombatLockdown=function() return combat end
assert(loadfile('BagSmith/Frames/Scroll.lua'))('BagSmith',ns)
local w,h,shown=500,400,true
local calls=0
local v=setmetatable({name='test',sizing=true,frame={GetWidth=function() return w end,GetHeight=function() return h end,IsShown=function() return shown end}}, {__index=ns.View})
v.Refresh=function(self,force,reason) assert(self.sizing and force and reason=='resize preview'); calls=calls+1 end
assert(v.UpdateResizePreview,'Live resize update missing')
v:UpdateResizePreview(.02); assert(calls==0)
v:UpdateResizePreview(.03); assert(calls==1)
v:UpdateResizePreview(.05); assert(calls==1,'Stationary grip must not rebuild')
w=520; v:UpdateResizePreview(.05); assert(calls==2)
combat=true; w=530; v:UpdateResizePreview(.1); assert(calls==2)
combat=false; v:UpdateResizePreview(.05); assert(calls==3)
v.sizing=false; w=540; v:UpdateResizePreview(.1); assert(calls==3)
v.sizing=true; v:UpdateResizePreview(.05); assert(calls==4)
shown=false; w=550; v:UpdateResizePreview(.1); assert(calls==4)
-- Exercise the actual refresh entry point without rebuilding a mock UI.
assert(loadfile('BagSmith/Frames/ViewList.lua'))('BagSmith',ns)
shown=true; v.Refresh=nil
local reached={}
v.Filtered=function() error(reached) end
local ok,err=pcall(v.Refresh,v,true,'resize preview'); assert(not ok and err==reached,'Preview must enter layout during sizing')
local ok=pcall(v.Refresh,v,true,'items'); assert(ok and v.refreshWanted,'Ordinary updates must still wait')
print('PASS: throttled live layout, unchanged-size skip, combat/hidden guards, resize-only refresh bypass')
