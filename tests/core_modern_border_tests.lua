local ns={db={skin='modern',border='unc'},OnSignal=function() end}
C_Item={GetItemQualityColor=function() return 0,1,0 end}
PixelUtil={GetPixelToUIUnitFactor=function() return 768/1440 end}
assert(loadfile('BagSmith/Core/Buttons.lua'))('BagSmith',ns)
local function texture()
  return setmetatable({points={}}, {__index={
    SetTexture=function() end,SetDrawLayer=function() end,
    SetVertexColor=function(t,...) t.color={...} end,
    Show=function(t) t.shown=true end,Hide=function(t) t.shown=false end,
    SetPoint=function(t,...) t.points[#t.points+1]={...} end,
    ClearAllPoints=function(t) t.points={} end,SetAllPoints=function() end,
    SetWidth=function(t,v) t.width=v end,SetHeight=function(t,v) t.height=v end,
    SetSize=function(t,w,h) t.width=w; t.height=h end,
    GetRect=function() return 100.3,200.7,37.2,37.2 end,
    GetWidth=function() return 37.2 end,GetHeight=function() return 37.2 end,
    SetRoundLayoutToNearestPixel=function(t,v) t.rounded=v end,
  }})
end
for _, scale in ipairs({0.64,0.8,1,1.25,1.5}) do
 for _, mode in ipairs({'cell','row'}) do
  local b={mode=mode,icon=texture(),CreateTexture=function() return texture() end,GetEffectiveScale=function() return scale end,
    HookScript=function(b,event,fn) b[event]=fn end}
  b.icon.GetTexCoord=function() return 0,0,0,1,1,0,1,1 end
  b.icon.SetTexCoord=function() end
  ns.Buttons.AddFrame(b)
  ns.db.skin='modern'
  ns.Buttons:ApplyFrame(b)
  local readyRect=b.icon.GetRect
  b.icon.GetRect=function() return nil end
  ns.Buttons:ApplyQuality(b,{quality=2})
  assert(#b.modernBorder[1].points==0,'Initial missing geometry must wait')
  b.icon.GetRect=readyRect
  assert(b.OnUpdate,'Initial borders need a geometry update without an item refresh')
  b:OnUpdate()
  assert(b.modernBorder and #b.modernBorder==4,'Modern must have four explicit border edges')
  assert(not b.qRing.shown and not b.qFrame.shown and not b.frameEdge.shown and not b.frameBG.shown,'No doubled frame behind Modern border')
  for i,t in ipairs(b.modernBorder) do
    local thickness=(i<=2 and t.height or t.width)*scale/PixelUtil.GetPixelToUIUnitFactor()
    assert(math.abs(thickness-1)<0.00001,'Every side must be one physical pixel at any scale')
    assert(t.shown and t.color[2]==1,'Quality color preserved')
    local p=t.points[1]
    assert(#t.points==1 and p[1]=='BOTTOMLEFT' and p[3]=='BOTTOMLEFT','Each edge must use one shared origin')
    local unit=PixelUtil.GetPixelToUIUnitFactor()/scale
    for _,position in ipairs({(100.3+p[4])/unit,(200.7+p[5])/unit,t.width/unit,t.height/unit}) do
      assert(math.abs(position-math.floor(position+0.5))<0.00001,'Edges must land on whole screen pixels')
    end
  end
  assert(b.OnUpdate,'Visible icons must realign after parent movement without an item update')
  local old=b.modernBorder[4].points[1][4]
  b.icon.GetRect=function() return 100.47,200.83,41.3,23.7 end
  b:OnUpdate()
  assert(b.modernBorder[4].points[1][4]~=old,'Movement/resize must update right edge')
  local point=b.modernBorder[4].points[1]
  b:OnUpdate()
  assert(b.modernBorder[4].points[1]==point,'Unchanged geometry must not reset anchors')
  local oldWidth=b.modernBorder[4].width
  b.GetEffectiveScale=function() return scale*1.1 end
  b:OnUpdate()
  assert(b.modernBorder[4].width~=oldWidth,'Scale changes must recompute physical thickness')
  ns.db.border='off'
  ns.Buttons:ApplyQuality(b,{quality=2})
  assert(b.modernBorder[1].color[1]==0.28,'Off uses neutral border')
  ns.Buttons:ApplyQuality(b,nil)
  for _,t in ipairs(b.modernBorder) do assert(not t.shown,'Empty slots hide item outline') end
  b:OnUpdate()
  for _,t in ipairs(b.modernBorder) do assert(not t.shown,'Empty slots stay unoutlined on update') end
  ns.db.skin='classic'; ns.db.border='unc'
  ns.Buttons:ApplyQuality(b,{quality=2})
  assert((mode=='cell' and b.qFrame.shown) or (mode=='row' and b.qRing.shown),'Classic keeps original frame for its view')
  for _,t in ipairs(b.modernBorder) do assert(not t.shown,'Modern strips cannot leak into Classic') end
  b:OnUpdate()
  for _,t in ipairs(b.modernBorder) do assert(not t.shown,'Classic update must not restore Modern edges') end
 end
end
print('PASS: cell/list, five scales, move/resize, idle caching, empty slots, rarity/off, Classic')
