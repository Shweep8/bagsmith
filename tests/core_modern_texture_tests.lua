local signals={}
local ns={View={},db={skin='modern'}}
function ns:OnSignal(k,fn) signals[k]=fn end
local function tex(snap,bias)
 return {snap=snap,bias=bias,IsSnappingToPixelGrid=function(s) return s.snap end,GetTexelSnappingBias=function(s) return s.bias end,SetSnapToPixelGrid=function(s,v) s.snap=v end,SetTexelSnappingBias=function(s,v) s.bias=v end}
end
local a,b=tex(true,.3),tex(false,.6)
local regions={a,{}}
local root={GetRegions=function() return unpack(regions) end,GetChildren=function() return {GetRegions=function() return b end} end}
local view={child=root}
SlashCmdList={}
assert(loadfile('BagSmith/Frames/Scroll.lua'))('BagSmith',ns)
assert(signals.VIEW_LAYOUT,'No automatic layout integration')
signals.VIEW_LAYOUT(view)
assert(a.snap==false and a.bias==0 and b.snap==false and b.bias==0)
local c=tex(true,.2); regions[#regions+1]=c
signals.VIEW_LAYOUT(view); assert(c.bias==0,'New overlays must be included')
a.snap=true; a.bias=.4; signals.VIEW_LAYOUT(view); assert(a.snap==false and a.bias==0,'Reapply after template reset')
ns.db.skin='classic'; signals.SETTINGS_CHANGED('skin')
assert(a.snap==true and a.bias==.3 and b.snap==false and b.bias==.6 and c.bias==.2,'Restore exact original texture settings')
signals.VIEW_LAYOUT(view); assert(a.bias==.3,'Classic layout must remain unchanged')
ns.db.skin='modern'; signals.VIEW_LAYOUT(view); assert(a.bias==0)
ns.db.skin='classic'; signals.VIEW_LAYOUT(view); assert(a.bias==.3)
assert(not SlashCmdList.BAGSMITHPIXELTEST,'Remove temporary command')
print('PASS: automatic Modern styling, new overlays, template resets, exact Classic restoration, repeated switching')
