local ns={View={},db={}}
function ns:OnSignal() end
function ns:Guard(_,f,...) return pcall(f,...) end
function ns:Safely(_,f) f() end
InCombatLockdown=function() return false end
assert(loadfile('BagSmith/Frames/Scroll.lua'))('BagSmith',ns)
local order={}
local v=setmetatable({name='test',sizing=true,frame={IsShown=function() return true end,GetWidth=function() return 600 end,GetHeight=function() return 400 end},scroll={GetWidth=function() return 570 end,IsRectValid=function() return true end,SetScrollChild=function() order[#order+1]='repair' end},child={GetWidth=function() return 500 end,GetHeight=function() return 300 end,SetSize=function() end}}, {__index=ns.View})
function v:ClampScroll() end
function v:ScrollRange() return 0 end
function v:Refresh(_,reason) assert(reason=='resize preview' and self.sizing); order[#order+1]='layout' end
v:RefreshCanvas('resize'); assert(#order==0,'Uncoordinated mid-drag repair remains blocked')
v:UpdateResizePreview(.05)
assert(table.concat(order,',')=='layout,repair','Each successful preview must repair its canvas after layout')
order={}; v.resizeWidth=nil; v.Refresh=function() error('layout failure') end
v:UpdateResizePreview(.05); assert(#order==0,'Failed layout must not repair its canvas')
print('PASS: live preview repairs only after successful layout; ordinary mid-drag repair stays blocked')
