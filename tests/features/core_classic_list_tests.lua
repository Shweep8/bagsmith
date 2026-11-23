package.path = 'tests/?.lua;' .. package.path
package.loaded.mock = nil
local M = require('mock')
M.put(0,1,{id=2589,name='Linen Cloth',q=1,count=5,class=7,subclass=5,price=13})
BagSmithDB = {version=2, profiles={Default={skin='classic'}}, chars={}, cache={}}
BagSmithCharDB = nil
local n = M.loadAddon('BagSmith')
M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers()
for _,b in ipairs({n.Buttons:Get(0,1),n.Buttons:GetCached(n.Window.main.child,1)}) do
 for _,size in ipairs({16,18,20,24}) do
  n.db.skin='classic'; n.Buttons:SetMode(b,'row'); b.iconPx=size
  for _,weight in ipairs({'normal','bold','normal'}) do
   n.db.borderWeight=weight
   for _,rec in ipairs({{quality=1},{quality=2},{quality=3},{quality=4},{quality=1,isQuest=true}}) do
    n.Buttons:ApplyQuality(b,rec)
    local frame=rec.quality==1 and not rec.isQuest and b.defaultFrame or b.qFrame
    assert(frame:IsShown() and not b.qRing, 'List uses one textured frame')
    assert(not b.modernBorder[1]:IsShown(), 'No old Bold outline remains')
    local suffix=weight=='bold' and 'frame-bold.tga' or 'frame.tga'
    assert(frame.texture:find(suffix,1,true) and frame.color[4]==1)
    if rec.isQuest then assert(frame.color[1]==1 and frame.color[2]==.82 and frame.color[3]==0) end
    assert(b.classicMask.texture:find('ui-icon-mask',1,true))
   end
  end
 end
 n.Buttons:ApplyQuality(b,nil)
 assert(not b.qFrame:IsShown() and not b.defaultFrame:IsShown(), 'Blank rows clear item frames')
 n.db.skin='modern'; n.Buttons:ApplyFrame(b); n.Buttons:ApplyQuality(b,{quality=3})
 assert(b.modernBorder[1]:IsShown() and not b.qFrame:IsShown())
 assert(b.classicMask.texture=='Interface\\Buttons\\WHITE8X8')
end
print('Classic List: sizes, qualities, quest, weights and skin transitions passed')

local b=n.Buttons:GetCached(n.Window.main.child,1)
n.db.skin='classic'; n.Buttons:SetMode(b,'row')
local rec=n.items[1]
n.Buttons:Fill(b,rec)
local mask=b.classicMask
local child={}
for k,v in pairs(rec) do child[k]=v end
child.globalChild=true; child.global=true; child.who='Test'; child.whoClass='MAGE'
CLASS_ICON_TCOORDS={MAGE={.25,.5,.5,.75}}
n.Buttons:Fill(b,child)
assert(b.globalChildIcon and mask.texture=='Interface\\Buttons\\WHITE8X8', 'Class row fill immediately disables item masking')
local left,top=b.icon:GetTexCoord()
assert(left==.25 and top==.5, 'Class row fill preserves atlas coordinates')
n.Buttons:Fill(b,rec)
assert(not b.globalChildIcon and b.classicMask==mask and mask.texture:find('ui-icon-mask',1,true), 'Item fill restores the same mask')
