;(function()
	-- ======== 1.7.3-beta2: resizing drags an outline (Shweep's choice, 14 Nov) ========
	-- 1.7.3-beta1 laid the window out up to 20 times a second while its corner was dragged (Jeor's #4) and it flickered,
	-- worst in Classic. Now the grip sizes a thin outline anchored to the screen; the window keeps its size, spot and
	-- contents until the button is let go, then takes the outline's size and lays out once.
	for _, skin in ipairs({ "modern", "classic" }) do
		package.loaded.mock = nil
		local M = require("mock")
		for s = 1, 6 do M.put(0, s, { id = 9900 + s, name = "Item" .. s, q = 2, class = 15, subclass = 0, price = 1 }) end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, sizeMode = "fixed", fixW = 900, fixH = 700, view = "icons" } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		ToggleAllBags(); M.runTimers()
		local main = n.Window.main
		local f = main.frame
		local S = skin .. ": "
		local laid = 0
		local realLayout = main.Layout
		main.Layout = function(...) laid = laid + 1; return realLayout(...) end

		-- press: the outline appears where the window is, at its size; the window is untouched
		local points = #f.points
		main.grip:GetScript("OnMouseDown")(main.grip)
		local o = main.outline
		check(main.sizing and o and o:IsShown(), S .. "pressing the grip shows the outline")
		local p = o and o.points and o.points[1]
		check(p and p[1] == "TOPLEFT" and p[2] == UIParent and p[3] == "BOTTOMLEFT" and p[4] == 400 and p[5] == 700,
			S .. "anchored to the screen at the window's top-left (never to the window)")
		check(o.w == 900 and o.h == 700, S .. "at the window's size")
		check(o.resizeBounds and o.resizeBounds[1] == (main.minWidth or n.View.MinWidthFor(false)) and o.resizeBounds[2] == 300
			and o.resizeBounds[3] == 1400 and o.resizeBounds[4] == 1200, S .. "with the window's size limits")
		check(o.clamped ~= false and o.strata == "TOOLTIP", S .. "kept on screen, drawn above everything")

		-- the drag: only the outline changes; nothing is laid out, whatever asks
		o:SetSize(640, 430)
		for _ = 1, 5 do M.tick(); n:RefreshViews(true); M.runTimers() end
		check(laid == 0, S .. "no layout at all while the outline is dragged: " .. laid)
		check(f:GetWidth() == 900 and f:GetHeight() == 700 and #f.points == points, S .. "the window keeps its size and spot mid-drag")

		-- release: the window takes the outline's size from the same top-left, saved, laid out now and once more
		main.grip:GetScript("OnMouseUp")(main.grip)
		local now = laid
		M.runTimers()
		check(not main.sizing and not o:IsShown(), S .. "letting go hides the outline")
		check(f:GetWidth() == 640 and f:GetHeight() == 430 and n.db.fixW == 640 and n.db.fixH == 430, S .. "the window takes the outline's size, saved")
		check(now >= 1 and laid > now, S .. "laid out at once, and again once sizes settle")

		-- a drag cut short (the window hidden mid-drag): no outline left behind, nothing waiting
		main.grip:GetScript("OnMouseDown")(main.grip)
		check(o:IsShown(), S .. "a second drag shows it again")
		f:Hide()
		check(not o:IsShown() and not main.sizing, S .. "hiding the window mid-drag removes the outline")
		f:Show(); M.runTimers()

		-- Lock Windows: the grip does nothing
		n:Set("lockWindows", true); M.runTimers()
		main.grip:GetScript("OnMouseDown")(main.grip)
		check(not o:IsShown() and not main.sizing, S .. "Lock Windows: no outline")
		main.grip:GetScript("OnMouseUp")(main.grip)
		check(n.db.fixW == 640, S .. "and no size change")
		n:Set("lockWindows", false)
		main.Layout = realLayout
	end
	-- no live-preview code left behind
	local src = io.open("BagSmith/Frames/Scroll.lua"):read("*a") .. io.open("BagSmith/Frames/View.lua"):read("*a")
	check(not src:find("UpdateResizePreview") and not src:find("resize preview"), "beta1's live resize preview is gone")
end)()
