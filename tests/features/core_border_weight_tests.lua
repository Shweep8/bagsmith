package.path = 'tests/?.lua;' .. package.path
package.loaded.mock = nil
local M = require('mock')
BagSmithDB = { version = 2, profiles = { Default = {} }, chars = {}, cache = {} }
BagSmithCharDB = nil
local n = M.loadAddon('BagSmith')
M.fire('ADDON_LOADED', 'BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers()
assert(n.db.borderWeight == 'normal', 'Existing profiles default to Normal')
assert(n:Set('borderWeight', 'bold') ~= false and n.db.borderWeight == 'bold', 'Bold is a valid profile setting')
assert(n:Set('borderWeight', 'wide') == false and n.db.borderWeight == 'bold', 'Invalid weights are rejected')
local calls = 0
local refresh = n.Buttons.RefreshSkin
n.Buttons.RefreshSkin = function(self) calls = calls + 1; return refresh(self) end
n:Set('borderWeight', 'normal')
assert(calls > 0, 'Weight changes repaint existing button pools immediately')
local fixed = n.validateSettings({ borderWeight = 'wide' }, n.DEFAULTS)
assert(fixed.borderWeight == 'normal', 'Corrupt saved weight falls back to Normal')
n.Profiles:Use('Bold test'); n:Set('borderWeight', 'bold')
n.Profiles:Use('Default')
assert(n.db.borderWeight == 'normal', 'Profile switching restores Normal')
n.Profiles:Use('Bold test')
assert(n.db.borderWeight == 'bold', 'Profile switching restores Bold')
-- Each button pool must receive the change, even if it is currently hidden.
local pools = { n.Buttons.all, {}, {}, n.Buttons.recent }
n.Buttons.cached.weightTest = pools[2]; n.Buttons.mirrors.weightTest = pools[3]
for _,pool in ipairs(pools) do
 local b = CreateFrame('Button'); b:SetSize(37,37); b.icon=M.tex(); b.icon:SetSize(37,37)
 function b:GetRegions() return unpack(self.regions) end
 b.Count=M.fs(); b.mode='cell'; b.hasItem=true; b.rec={quality=2}
 n.Buttons.AddFrame(b); pool[#pool+1]=b
end
for _,skin in ipairs({'modern','classic'}) do
 n:Set('skin',skin)
 for _,weight in ipairs({'normal','bold','normal'}) do
  n:Set('borderWeight',weight)
  for _,pool in ipairs(pools) do
   local b=pool[#pool]
   assert(#n.Buttons:TemplateLeftovers(b)==0,'Owned border regions must not be reported as template leftovers')
   if skin=='modern' then
    assert(b.modernBorder[1]:IsShown() and b.borderThickness==n.Buttons.PixelSize(b)*(weight=='bold' and 2 or 1),'Every pool updates Modern weight')
   else
    assert(b.qFrame:IsShown() and not b.classicBold, 'Classic uses one frame regardless of saved border weight')
   end
  end
 end
end
print('Border weight profile and refresh checks passed')
