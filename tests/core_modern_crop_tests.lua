local ns = { db = { skin = 'modern', border = 'unc' }, OnSignal = function() end }
C_Item = { GetItemQualityColor = function() return 0, 1, 0 end }
PixelUtil = { GetPixelToUIUnitFactor = function() return 768/1440 end }
assert(loadfile('BagSmith/Core/Buttons.lua'))('BagSmith', ns)
local function texture()
  return setmetatable({ coords = {0,0,0,1,1,0,1,1} }, { __index = {
    GetTexCoord = function(t) return unpack(t.coords) end,
    SetTexCoord = function(t, ...) local c={...}; if #c==4 then c={c[1],c[3],c[1],c[4],c[2],c[3],c[2],c[4]} end; t.coords=c end,
    Show = function(t) t.shown=true end, Hide = function(t) t.shown=false end,
    SetShown = function(t,v) t.shown=v end,
    SetTexture = function(t) t:SetTexCoord(0,1,0,1) end,
    SetDesaturated=function() end, SetText=function() end,
    ClearAllPoints=function() end, SetPoint=function() end, SetAllPoints=function() end,
    SetVertexColor=function() end,
    SetHeight=function() end, SetWidth=function() end,
    SetSize=function() end, GetRect=function() return 100.3,200.7,37.2,37.2 end,
  } })
end
local function button(secure)
  local b={secure=secure, mode='cell', SetAlpha=function() end, GetNormalTexture=function() end, slotArtSet=true}
  for _, k in ipairs({'icon','Count','newDot','frameBG','frameEdge','qRing','qFrame','slotRing','slotBG','IconBorder'}) do b[k]=texture() end
  b.GetEffectiveScale=function() return 1 end
  b.modernBorder={texture(),texture(),texture(),texture()}
  for _,key in ipairs(ns.Buttons.COL_KEYS) do b[key]=texture() end
  return b
end
SetItemButtonTexture=function(b) b.icon:SetTexCoord(0,1,0,1) end
SetItemButtonCount=function() end
SetItemButtonQuality=function() end
SetItemButtonDesaturated=function() end
ns.Buttons.ItemLevel=function() end
ns.Buttons.Cooldown=function() end
ns.Buttons.LinkMark=function() end
ns.Buttons.slotArt={atlas='bags-item-slot64'}
local record={quality=2, count=1}
for _, secure in ipairs({true,false}) do
  local b=button(secure)
  ns.db.skin='modern'
  for i=1,3 do
    ns.Buttons:Fill(b, record)
    assert(b.icon.coords[1]==0.08 and b.icon.coords[8]==0.92, 'Modern crop must survive item texture updates')
    assert(b.modernBorder[1].shown and not b.qFrame.shown, 'Modern quality highlight survives')
  end
  ns.db.skin='classic'
  ns.Buttons:ApplyFrame(b)
  ns.Buttons:ApplyQuality(b,record)
  assert(b.icon.coords[1]==0 and b.icon.coords[8]==1, 'Classic restores original full artwork immediately')
  assert(b.qFrame.shown and not b.qRing.shown, 'Classic quality frame survives')
  ns.Buttons:Fill(b,record)
  assert(b.icon.coords[1]==0 and b.icon.coords[8]==1, 'Classic updates remain unchanged')
  ns.db.skin='modern'
  ns.Buttons:ApplyFrame(b)
  assert(b.icon.coords[1]==0.08, 'Switching to Modern reapplies crop immediately')
  ns.Buttons:Blank(b)
  for _,edge in ipairs(b.modernBorder) do assert(not edge.shown,'Blanking a pooled button hides its outline') end
  ns.Buttons:Fill(b,record)
  assert(b.icon.coords[1]==0.08 and b.modernBorder[4].shown,'Reused button restores crop and right edge')
end
print('PASS: repeated item updates, both button types, style switching, rarity frames')
