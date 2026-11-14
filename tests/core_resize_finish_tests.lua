local ns={View={},db={}}
function ns:OnSignal() end
local deferred
function ns:Safely(_,fn) if self.combat then deferred=fn else fn() end end
function ns:Guard(_,fn,...) return pcall(fn,...) end
assert(loadfile('BagSmith/Frames/Scroll.lua'))('BagSmith',ns)
local calls={}
local function record(s) calls[#calls+1]=s end
local shown=true
local v=setmetatable({name='test',frame={IsShown=function() return shown end}}, {__index=ns.View})
v.scroll={SetScrollChild=function() record('canvas') end}
v.child={GetWidth=function() return 300 end,GetHeight=function() return 200 end,SetSize=function() end}
v.ScrollRange=function() return 0 end
v.ClampScroll=function() end
v.sizing=true
v:RefreshCanvas('resize')
assert(#calls==0,'Canvas must not be reattached while the user is resizing')
assert(type(v.FinishResizeLayout)=='function','Resize completion needs a final canvas repair')
v.PlaceScroll=function() record('place') end
v.Refresh=function() record('refresh') end
v.RefreshCanvas=function() record('canvas') end
v.ScheduleListPlaced=function() record('check') end
v:FinishResizeLayout()
assert(#calls==0,'Skip stale completion during a new drag')
v.sizing=false
v:FinishResizeLayout()
assert(table.concat(calls,',')=='place,refresh,canvas,check','Final layout must precede canvas repair and bounded placement checks')
calls={}; ns.combat=true
v:FinishResizeLayout()
assert(#calls==0 and deferred,'Do not move secure parents in combat')
v.sizing=true; deferred()
assert(#calls==0,'Deferred work must recheck for a new drag')
v.sizing=false; v:FinishResizeLayout(); shown=false; deferred()
assert(#calls==0,'Deferred work must not reopen a hidden view')
print('PASS: resize ordering, no mid-drag repair, combat deferral, stale/hidden callbacks')
