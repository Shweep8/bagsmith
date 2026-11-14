local f=assert(io.open('BagSmith/Frames/View.lua')); local src=f:read('*a'); f:close()
local body=assert(src:match('(function View:ApplySize%(%)%s.-)\nfunction View:SavePosition'))
local View={}
local ns={db={scale=1,sizeMode='fixed',fixW=600,fixH=400,point={'TOPLEFT','UIParent','TOPLEFT',10,20}}}
function ns:WindowsLocked() return false end
local calls={}
local frame={}
for _,k in ipairs({'SetScale','SetSize','ClearAllPoints','SetPoint'}) do frame[k]=function() calls[#calls+1]=k end end
assert(loadstring('return function(View,ns,UIParent) '..body..' end'))()(View,ns,{})
local v=setmetatable({frame=frame,isMain=true,big=true,grip={SetShown=function() end},ApplyMinWidth=function() end},{__index=View})
v.dragMoving=true; v:ApplySize()
assert(#calls==0,'ApplySize reapplies saved position during a title-bar drag')
v.dragMoving=nil; v.sizing=true; v:ApplySize(); assert(#calls==0)
v.sizing=false; v:ApplySize(); assert(table.concat(calls,',')=='SetScale,SetSize,ClearAllPoints,SetPoint')
print('PASS: moving and resizing preserve live geometry; idle layout still applies')
