;(function()
	-- ======== 1.8.0-beta9: each special bag's indicator style: Inner Glow (default) or Frame Color (Shweep) ========
	-- Frame Color: the slot's frame in the kind's color and opacity instead of the item's rarity color, empty slots too.
	for _, weight in ipairs({ "normal", "bold" }) do
		for _, skin in ipairs({ "modern", "classic" }) do
			local S = skin .. " " .. weight .. ": "
			package.loaded.mock = nil
			local M = require("mock")
			M.sizes[3] = 6; M.bagNames[3] = "Herb Pouch"
			M.put(3, 1, { id = 2447, name = "Peacebloom", q = 2, count = 3, class = 7, subclass = 9, type = "Tradeskill", sub = "Herb", price = 5 })
			local realInstant = C_Item.GetItemInfoInstant
			C_Item.GetItemInfoInstant = function(item)
				if type(item) == "string" and item:find("%[Herb Pouch%]") then return 1, "Container", "", "INVTYPE_BAG", 1, 1, 2 end
				return realInstant(item)
			end
			_G.BagSmithCharDB = { version = 1, firstSeen = {} }
			_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, borderWeight = weight, glow_herb = true, border = "all" } } }
			local n = M.loadAddon("BagSmith")
			M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
			n.Window:Show(); n.ui.bagWindows = true; n:RefreshViews(true); M.runTimers(); M.runTimers()
			local function cell(slot) return n.Buttons.mirrors[n.Window.bagViews[3].child][slot] end
			local function frameColor(b)
				if skin == "modern" then
					local e = b.modernBorder and b.modernBorder[1]
					return (e and e:IsShown() and e.color) or nil
				end
				local frame = b.qFrame
				return (frame and frame:IsShown() and frame.color) or nil
			end
			-- (beta11, by design) empty and filled slots each choose; "both" sets them together as beta9's one style did
			local function both(v) n:Set("glowEmpty_herb", v); n:Set("glowFilled_herb", v) end
			check(n.db.glowEmpty_herb == "glow" and n.db.glowFilled_herb == "glow", S .. "Inner Glow by default")
			check(cell(2).bagGlow and cell(2).bagGlow:IsShown(), S .. "(setup) Inner Glow: the empty slot glows")
			local hr, hg, hb = n:BagKindColor("herb")
			both("frame"); M.runTimers()
			check(not (cell(2).bagGlow and cell(2).bagGlow:IsShown()) and not (cell(1).bagGlow and cell(1).bagGlow:IsShown()), S .. "Frame Color: no glow")
			local c = frameColor(cell(1))
			check(c and math.abs(c[1] - hr) < 1e-6 and math.abs(c[2] - hg) < 1e-6 and math.abs(c[3] - hb) < 1e-6, S .. "the Peacebloom's frame is the herb bag's color, not its rarity green")
			local e = frameColor(cell(2))
			check(e and math.abs(e[1] - hr) < 1e-6, S .. "an empty slot gets the frame too")
			n:Set("glowAlpha_herb", 0.5); M.runTimers()
			check(math.abs(frameColor(cell(1))[4] - 0.5) < 1e-9, S .. "at the kind's opacity")
			n:Set("glowFilled_herb", "off"); M.runTimers()
			c = frameColor(cell(1))
			check(c and math.abs(c[1] - hr) > 0.01, S .. "Filled Herb Bag Slots off: the Peacebloom's frame is its rarity color again")
			check(frameColor(cell(2)) ~= nil, S .. "and the empty slot keeps the indicator")
			n:Set("glow_herb", false); M.runTimers()
			check(frameColor(cell(2)) == nil, S .. "the indicator off: an empty slot has no frame again")
			check(n:Set("glowEmpty_herb", "sparkles") == false and n.db.glowEmpty_herb == "frame", S .. "only Inner Glow, Frame Color or Off")
			-- mixed: empty slots glow, items get the frame
			n:Set("glow_herb", true); n:Set("glowEmpty_herb", "glow"); n:Set("glowFilled_herb", "frame"); M.runTimers()
			check(cell(2).bagGlow and cell(2).bagGlow:IsShown() and frameColor(cell(2)) == nil, S .. "Empty: Inner Glow, no frame")
			c = frameColor(cell(1))
			check(c and math.abs(c[1] - hr) < 1e-6 and not (cell(1).bagGlow and cell(1).bagGlow:IsShown()), S .. "Filled: Frame Color, no glow")
			-- Integration: special-bag frames share the adaptive pixel geometry,
			-- and inner glow keeps its one-pixel inset after an effective-scale change.
			n:Set("glow_herb", true)
			for _, scale in ipairs({ .3, .64, .9, 1, 1.5 }) do
				for _, slot in ipairs({ 1, 2 }) do
					local b = cell(slot)
					b.GetEffectiveScale = function() return scale end
					both("frame"); n.Buttons:RefreshGlows()
					if skin == "classic" then
						check(b.qFrame.points[1][4] == 0 and b.qFrame.points[2][4] == 0,
							S .. "bag frame shares icon bounds at " .. scale)
					end
					both("glow"); n.Buttons:RefreshGlows()
					b.GetEffectiveScale = function() return scale * .9 end
					n.Buttons:RealignModernBorders()
					local pixel = n.Buttons.PixelSize(b)
					check(math.abs(b.bagGlow.points[1][4] - pixel) < 1e-9 and math.abs(b.bagGlow.points[2][4] + pixel) < 1e-9,
						S .. "inner glow follows effective scale without refilling the item")
				end
			end
			check((n.errors or 0) == 0, S .. "no errors")
		end
	end
end)()
