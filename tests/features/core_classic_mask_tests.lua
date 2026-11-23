package.path = 'tests/?.lua;' .. package.path
local TGA = require('tga')
local base = 'BagSmith/Media/ui-icon-'
local normal = assert(TGA.load(base .. 'frame.tga'))
local bold = assert(TGA.load(base .. 'frame-bold.tga'))
local mask = assert(TGA.load(base .. 'mask.tga'))
assert(normal.w == bold.w and normal.h == bold.h and normal.w == mask.w and normal.h == mask.h,
 'Normal, Bold and mask must share both dimensions')
local brighter = 0
for i = 1, #normal.pixels, 4 do
 local a, ba = normal.pixels:byte(i+3), bold.pixels:byte(i+3)
 assert(a == ba, 'Bold must preserve exact alpha and geometry')
 if a > 0 then
  for channel=0,2 do
   assert(bold.pixels:byte(i+channel) > normal.pixels:byte(i+channel), 'Bold brightens every RGB channel')
  end
  brighter = brighter + 1
 end
end
assert(brighter > 0)
assert(mask.pixels:byte(4) == 0, 'Corners clip artwork')
local center = math.floor(mask.h/2)*mask.w + math.floor(mask.w/2)
assert(mask.pixels:byte(center*4+4) == 255, 'Center stays opaque')
-- Flood the transparent exterior to verify every edge and clipped corner.
local pending, seen = {0}, {[0]=true}
while #pending > 0 do
 local i = table.remove(pending)
 assert(mask.pixels:byte(i*4+4) == 0, 'Artwork cannot escape outside the frame')
 local x, y = i % normal.w, math.floor(i/normal.w)
 local neighbors = {}
 if x > 0 then neighbors[#neighbors+1]=i-1 end
 if x+1 < normal.w then neighbors[#neighbors+1]=i+1 end
 if y > 0 then neighbors[#neighbors+1]=i-normal.w end
 if y+1 < normal.h then neighbors[#neighbors+1]=i+normal.w end
 for _,j in ipairs(neighbors) do
  if not seen[j] and normal.pixels:byte(j*4+4)==0 then seen[j]=true; pending[#pending+1]=j end
 end
end
package.loaded.mock = nil
local M = require('mock')
BagSmithDB = {version=2, profiles={Default={skin='classic'}}, chars={}, cache={}}
BagSmithCharDB = nil
local n = M.loadAddon('BagSmith')
M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers()
for _, b in ipairs({n.Buttons:Get(0,1), n.Buttons:GetCached(n.Window.main.child,1)}) do
 n.db.skin='classic'; n.Buttons:SetMode(b,'cell')
 assert(b.icon.mask == b.classicMask and b.classicMask.texture:find('ui-icon-mask',1,true))
 assert(b.slotBG and b.slotBG.mask == b.classicMask, 'Slot artwork shares the icon mask')
 local originalMask = b.classicMask
 for _, weight in ipairs({'normal','bold','normal'}) do
  n.db.borderWeight=weight; n.Buttons:ApplyQuality(b,{quality=2})
  local suffix=weight=='bold' and 'frame-bold.tga' or 'frame.tga'
  assert(b.qFrame.texture:find(suffix,1,true))
 end
 n.db.skin='modern'; n.Buttons:ApplyFrame(b)
 assert(b.classicMask.texture == 'Interface\\Buttons\\WHITE8X8')
 n.db.skin='classic'; n.Buttons:SetMode(b,'row')
 assert(b.classicMask.texture:find('ui-icon-mask',1,true))
 n.Buttons:SetMode(b,'cell')
 assert(b.classicMask.texture:find('ui-icon-mask',1,true))
 b.globalChildIcon=true
 b.icon:SetTexCoord(.25,.5,.5,.75)
 n.Buttons:ApplyIconCrop(b)
 assert(b.classicMask.texture == 'Interface\\Buttons\\WHITE8X8', 'Class icons bypass the mask')
 local left, top = b.icon:GetTexCoord()
 assert(left == .25 and top == .5, 'Class atlas coordinates are preserved')
 b.globalChildIcon=nil
 n.Buttons:ApplyIconCrop(b)
 assert(b.classicMask == originalMask and b.classicMask.texture:find('ui-icon-mask',1,true),
  'Reused item restores the original mask without allocating another')
end
print('Classic mask containment, brightness and reuse checks passed')
