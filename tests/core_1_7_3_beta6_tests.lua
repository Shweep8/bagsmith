;(function()
	-- ======== 1.7.3-beta6: the Settings panel follows a resize of the bags window (Shweep) ========
	-- With Settings open on the Bag Window page, Width and Height (Max Width and Max Height in Fit to Items) show the
	-- outline's size while it's dragged (nothing saved), then the saved size when the button is let go; a drag cut
	-- short shows the saved values again.
	for _, skin in ipairs({ "modern", "classic" }) do
		package.loaded.mock = nil
		local M = require("mock")
		for s = 1, 4 do M.put(0, s, { id = 9900 + s, name = "Item" .. s, q = 1, class = 15, subclass = 0, price = 1 }) end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, sizeMode = "fixed", fixW = 900, fixH = 700 } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		ToggleAllBags(); M.runTimers()
		local main, P = n.Window.main, n.SettingsPanel
		P:Show(); P:ShowPage("window"); M.runTimers()
		local function box(key) for _, w in ipairs(P.pools.step) do if w:IsShown() and w.key == key then return w.value.text end end end
		local S = skin .. ": "
		check(box("fixW") == "900" and box("fixH") == "700", S .. "(control) the panel shows the saved size")

		local function drag(w, h)
			local o = n.Outline.frame
			o:SetSize(w, h); o.scripts.OnSizeChanged(o, w, h)
		end
		-- Scalable: Width and Height follow the outline, nothing saved yet
		main.grip:GetScript("OnMouseDown")(main.grip)
		drag(640.4, 430.6)
		check(box("fixW") == "640" and box("fixH") == "431", S .. "while dragging, Width and Height show the outline's size")
		check(n.db.fixW == 900 and n.db.fixH == 700, S .. "nothing is saved mid-drag")
		main.grip:GetScript("OnMouseUp")(main.grip); M.runTimers()
		check(n.db.fixW == 640 and n.db.fixH == 431 and box("fixW") == "640" and box("fixH") == "431", S .. "letting go saves it, and the panel shows the saved size")

		-- a drag cut short: back to the saved values
		main.grip:GetScript("OnMouseDown")(main.grip)
		drag(820, 520)
		check(box("fixW") == "820", S .. "(a second drag shows its size)")
		main.frame:Hide()
		check(box("fixW") == "640" and box("fixH") == "431", S .. "closing the window mid-drag shows the saved size again")
		main.frame:Show(); M.runTimers()

		-- Fit to Items: Max Width and Max Height
		n:Set("sizeMode", "auto"); M.runTimers()
		P:ShowPage("window"); M.runTimers()
		main.grip:GetScript("OnMouseDown")(main.grip)
		drag(700, 600)
		check(box("maxW") == "700" and box("maxH") == "600", S .. "Fit to Items: Max Width and Max Height follow the outline")
		main.grip:GetScript("OnMouseUp")(main.grip); M.runTimers()
		check(n.db.maxW == 700 and n.db.maxH == 600 and box("maxW") == "700", S .. "and show the saved max size after")

		-- a box being typed in is left alone
		main.grip:GetScript("OnMouseDown")(main.grip)
		local wrow
		for _, w in ipairs(P.pools.step) do if w:IsShown() and w.key == "maxW" then wrow = w end end
		wrow.value.HasFocus = function() return true end
		wrow.value:SetText("12")
		drag(760, 610)
		check(box("maxW") == "12" and box("maxH") == "610", S .. "a box you're typing in isn't overwritten")
		wrow.value.HasFocus = nil
		main.grip:GetScript("OnMouseUp")(main.grip); M.runTimers()

		-- the bank window's size isn't in Settings: its drag leaves the panel alone
		P:Hide()
	end
end)()
