;(function()
	-- 1.6.1 (Shweep): buying a bank bag slot shows the new empty slot the moment the purchase goes through, not when the
	-- pointer leaves the bank window. The purchase ended in an item refresh, which holds the layout still under the pointer;
	-- a bought slot has no bag yet, so it didn't count as a change to the bag set. Now it does (View:BagSetKey).
	for _, skin in ipairs({ "modern", "classic" }) do
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 4, class = 7, subclass = 5, price = 1 })
		M.put(0, 2, { id = 2590, name = "Light Leather", q = 1, count = 2, class = 7, subclass = 6, price = 2 })
		M.put(-1, 1, { id = 2592, name = "Wool Cloth", q = 1, count = 4, class = 7, subclass = 5, price = 2 })
		M.put(-1, 2, { id = 2318, name = "Light Leather Scrap", q = 1, count = 3, class = 7, subclass = 6, price = 1 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, replaceBank = true } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); M.runTimers(); M.runTimers()
		M.fire("BANKFRAME_OPENED"); M.runTimers(); M.runTimers()
		local W, main = n.Window.bank, n.Window.main
		local bar = W.bankBar
		check(bar.hint.text:find("2 of 8 slots", 1, true) and bar.slots[2].purchased and not bar.slots[3].purchased and bar.slots[3].forSale,
			skin .. ": (setup) 2 of 8 bank bag slots bought, the third for sale")
		-- the pointer stays over the bank window (the confirmation is clicked there)
		W.frame.IsMouseOver = function() return true end
		main.frame.IsMouseOver = function() return true end
		-- control: an ordinary item change still holds the rows still under the pointer
		M.bags[-1][2] = nil
		M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
		check(W.held == true, skin .. ": (control) an item leaving the bank still holds the layout under the pointer")
		-- the purchase, as the client reports it
		for i, ev in ipairs({ "BANK_TABS_CHANGED", "BAG_UPDATE_DELAYED" }) do
			M.bankSlots = M.bankSlots + 1
			M.fire(ev); M.runTimers(); M.runTimers()
			local bought = 2 + i
			check(not W.held and bar.slots[bought].purchased and not bar.slots[bought].forSale and bar.slots[bought].icon.shown ~= nil,
				("%s: bought through %s, slot %d shows at once, bought and empty, with the pointer still over the window"):format(skin, ev, bought))
			check(bar.slots[bought + 1].forSale and bar.slots[bought + 1].plus.shown and bar.slots[bought + 1].secureBuy:IsShown(),
				("%s: and slot %d is the one for sale now, its + and purchase click with it"):format(skin, bought + 1))
			check(bar.hint.text:find(("%d of 8 slots"):format(bought), 1, true) ~= nil, ("%s: the line says %d of 8 slots (%s)"):format(skin, bought, tostring(bar.hint.text)))
		end
		-- the bags window has no bank strip: an item change there still holds as before
		M.bags[0][2] = nil
		M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
		check(main.held == true, skin .. ": the bags window still holds an item change under the pointer")
		-- and the bank window's own item changes keep holding after the purchases
		M.bags[-1][1] = nil
		M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
		check(W.held == true, skin .. ": the bank window too, after the purchases")
		M.fire("BANKFRAME_CLOSED"); M.runTimers()
	end
end)()
