-- 1.7.3-beta1: the Modern border driver (realigns only while something can move) and the pixel-size fallback.
-- Standalone: loads Core/Buttons.lua against a small fake client, like core_modern_border_tests.lua.
local passes, fails = 0, 0
local function check(cond, msg) if cond then passes = passes + 1 else fails = fails + 1; print("FAIL: " .. msg) end end

local ns = { db = { skin = "modern", border = "all" }, OnSignal = function() end, views = {} }
C_Item = { GetItemQualityColor = function() return 0, 1, 0 end }
PixelUtil = { GetPixelToUIUnitFactor = function() return 768 / 1080 end }
local frames = {}
CreateFrame = function()
	local f = { scripts = {}, events = {} }
	function f:SetScript(k, fn) self.scripts[k] = fn end
	function f:GetScript(k) return self.scripts[k] end
	function f:RegisterEvent(e) self.events[e] = true end
	frames[#frames + 1] = f
	return f
end
assert(loadfile("BagSmith/Core/Buttons.lua"))("BagSmith", ns)
local B = ns.Buttons

local function texture()
	return setmetatable({ points = {} }, { __index = {
		SetTexture = function() end, SetVertexColor = function(t, ...) t.color = { ... } end,
		Show = function(t) t.shown = true end, Hide = function(t) t.shown = false end,
		SetPoint = function(t, ...) t.points[#t.points + 1] = { ... } end, ClearAllPoints = function(t) t.points = {} end,
		SetAllPoints = function() end, SetSize = function(t, w, h) t.width, t.height = w, h end,
		SetWidth = function(t, v) t.width = v end, SetHeight = function(t, v) t.height = v end,
		GetRect = function(t) return t.rx or 10.3, 20.7, 37.2, 37.2 end, GetWidth = function() return 37.2 end,
		GetHeight = function() return 37.2 end, SetRoundLayoutToNearestPixel = function() end,
		GetTexCoord = function() return 0, 0, 0, 1, 1, 0, 1, 1 end, SetTexCoord = function() end,
	} })
end
local hooked = {}
local function button()
	local b = { mode = "cell", icon = texture(), CreateTexture = function() return texture() end,
		GetEffectiveScale = function() return 1 end, HookScript = function(_, ev) hooked[#hooked + 1] = ev end }
	B.AddFrame(b); return b
end

-- 1. no per-button OnUpdate any more
local b1, b2 = button(), button()
check(#hooked == 0, "item buttons get no OnUpdate hook (was one per button, every frame)")

-- 2. drawing a border starts the driver; it realigns, then switches itself off when nothing moves
B:ApplyFrame(b1); B:ApplyQuality(b1, { quality = 3 }); B:ApplyQuality(b2, { quality = 2 })
local driver = frames[1]
check(driver and B.BorderDriverRunning(), "a drawn border wakes the driver")
check(driver and driver.events.UI_SCALE_CHANGED and driver.events.DISPLAY_SIZE_CHANGED, "a UI scale or display change wakes it too")
b1.icon.rx = 11.9
local ticks = 0
while B.BorderDriverRunning() and ticks < 100 do driver.scripts.OnUpdate(driver, 0.016); ticks = ticks + 1 end
check(ticks == 10, "the driver stops itself after 10 quiet frames: " .. ticks)
check(b1.borderX == 11.9, "a moved icon was realigned while the driver ran")

-- 3. while a window is moved or resized it keeps running, then settles
ns.views.main = { dragMoving = true }
B:WakeModernBorders()
for _ = 1, 50 do driver.scripts.OnUpdate(driver, 0.016) end
check(B.BorderDriverRunning(), "the driver keeps running while a window is being moved")
b1.icon.rx = 14.2; driver.scripts.OnUpdate(driver, 0.016)
check(b1.borderX == 14.2, "borders follow the window while it moves")
ns.views.main = { sizing = true }
for _ = 1, 50 do driver.scripts.OnUpdate(driver, 0.016) end
check(B.BorderDriverRunning(), "... and while it is being resized")
ns.views.main = {}
ticks = 0
while B.BorderDriverRunning() and ticks < 100 do driver.scripts.OnUpdate(driver, 0.016); ticks = ticks + 1 end
check(ticks == 10, "after the drag it settles for 10 frames and stops: " .. ticks)

-- 4. an emptied or Classic button leaves the driver's list
B:ApplyQuality(b2, nil)
local before = b2.borderX
b2.icon.rx = 99; B:RealignModernBorders()
check(b2.borderX == before, "an empty slot's hidden border isn't realigned")

-- 5. pixel size without PixelUtil: from the screen height, else one UI unit
local function thickness(b) return b.modernBorder[1].height end
PixelUtil = nil
GetPhysicalScreenSize = function() return 2560, 1440 end
local b3 = button(); B:ApplyQuality(b3, { quality = 2 })
check(math.abs(thickness(b3) - 768 / 1440) < 1e-9, "without PixelUtil: one pixel from the screen height (768/1440)")
GetPhysicalScreenSize = nil
local b4 = button(); B:ApplyQuality(b4, { quality = 2 })
check(thickness(b4) == 1, "without either: one UI unit, and no error")
local ok = pcall(B.ApplyQuality, B, button(), { quality = 4 })
check(ok, "ApplyQuality never errors for lack of PixelUtil")

print(("%d passed, %d failed"):format(passes, fails))
os.exit(fails == 0 and 0 or 1)
