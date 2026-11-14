local ns={View={},db={}}
function ns:OnSignal() end
function ns:Guard(_,fn,...) return pcall(fn,...) end
InCombatLockdown=function() return false end
assert(loadfile('BagSmith/Frames/Scroll.lua'))('BagSmith',ns)
local valid=false
local order={}
local v=setmetatable({name='test',sizing=true,resizeWidth=600,resizeHeight=400,
frame={IsShown=function() return true end,GetWidth=function() return 600 end,GetHeight=function() return 400 end},
scroll={IsRectValid=function() return valid end,GetWidth=function() return valid and 570 or 0 end}}, {__index=ns.View})
function v:PlaceScroll() order[#order+1]='place'; valid=true end
function v:Refresh() assert(valid,'Layout must not use invalid scroll geometry'); order[#order+1]='layout' end
function v:RefreshCanvas() assert(valid); order[#order+1]='canvas' end
v:UpdateResizePreview(.05)
assert(table.concat(order,',')=='place,layout,canvas','Invalid viewport must be placed even when outer dimensions are unchanged')
order={}; v:UpdateResizePreview(.05); assert(#order==0,'Valid unchanged viewport must not rebuild')
valid=false; v.PlaceScroll=function() order[#order+1]='place' end
v:UpdateResizePreview(.05); assert(table.concat(order,',')=='place','Do not lay out until placement succeeds')
order={}; v.PlaceScroll=function() order[#order+1]='place'; valid=true end
v:UpdateResizePreview(.05); assert(table.concat(order,',')=='place,layout,canvas','Retry unresolved placement on next tick')
print('PASS: zero-size viewport repair, layout ordering, unchanged-size recovery, bounded retry per preview tick')
