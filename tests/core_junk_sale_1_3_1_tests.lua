;(function()
	-- 1.3.1: the junk sale's check waits for the server to finish before it reports, names what really didn't
	-- sell, and points to the right button (Shweep, 5 Nov 2026: "Sold 8 junk items" then "6 items didn't sell;
	-- click Sell Marked" with nothing marked; the 6 greys sold a moment later).
	local function boot(stock)
		package.loaded.mock = nil
		local M = require("mock")
		M.sizes[0] = 16
		for b = 1, 5 do M.sizes[b] = 0 end
		stock(M)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", autoSellJunk = true } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		_G.MerchantFrame = _G.MerchantFrame or CreateFrame("Frame", "MerchantFrame", UIParent)
		MerchantFrame:Show()
		return n, M
	end
	local function said(M, pat) for _, l in ipairs(M.log) do if l:find(pat) then return l end end end
	local function greys(M, count)
		for s = 1, count do M.put(0, s, { id = 4000 + s, name = "Grey Thing " .. s, q = 0, count = 1, class = 15, subclass = 0, price = 10 }) end
	end
	-- the server: some stacks leave at once, others stay locked for a while before leaving
	local function slowServer(M, slowSlots, ticks)
		local pending = {}
		C_Container.UseContainerItem = function(bag, slot)
			local it = M.bags[bag] and M.bags[bag][slot]
			if not it then return end
			if slowSlots[slot] then it.locked = true; pending[#pending + 1] = { bag = bag, slot = slot, left = ticks }
			else M.bags[bag][slot] = nil end
		end
		return function()   -- one server tick: pending sales finish when their time is up
			for i = #pending, 1, -1 do
				local p = pending[i]; p.left = p.left - 1
				if p.left <= 0 then M.bags[p.bag][p.slot] = nil; table.remove(pending, i) end
			end
		end
	end

	-- ---- Shweep's case: 14 greys, 6 of them slow to leave
	local n, M = boot(function(MM) greys(MM, 14) end)
	local tick = slowServer(M, { [9] = true, [10] = true, [11] = true, [12] = true, [13] = true, [14] = true }, 2)
	local clock = 100; _G.GetTime = function() return clock end
	n:Scan(); M.runTimers()
	n.Junk:Sell("all", "auto")
	for _ = 1, 10 do tick(); clock = clock + 0.6; M.runTimers() end
	check(said(M, "^.-Sold 14 junk items") ~= nil, "a sale whose last stacks leave a moment later reports one total: Sold 14 junk items (" .. tostring(said(M, "Sold %d+")) .. ")")
	check(said(M, "didn't sell") == nil and said(M, "Didn't sell") == nil, "and no warning, since everything sold")
	check(not n.Junk.retry, "nothing is left to retry")

	-- ---- greys that genuinely don't sell: named, with the right button
	n, M = boot(function(MM) greys(MM, 5) end)
	C_Container.UseContainerItem = function(bag, slot) if slot <= 3 then M.bags[bag][slot] = nil end end   -- slots 4 and 5 stay, unlocked
	n:Scan(); M.runTimers()
	n.Junk:Sell("all", "auto")
	for _ = 1, 10 do clock = clock + 0.6; M.runTimers() end
	local warn = said(M, "Didn't sell")
	check(said(M, "Sold 3 junk items") ~= nil, "the three that sold are reported")
	check(warn and warn:find("Grey Thing 4", 1, true) and warn:find("Grey Thing 5", 1, true), "the two that didn't are named (" .. tostring(warn) .. ")")
	check(warn and warn:find("Click Sell Junk", 1, true) and not warn:find("Sell Marked", 1, true), "and greys point to Sell Junk, not Sell Marked")
	check(n.Junk.retry == true and n.Junk.retryJunk == true, "the button offers to try the junk again")
	-- the button says what it will do
	check(n.Junk.ButtonTitle ~= nil and n.Junk:ButtonTitle() == "Sell Junk", "the vendor-window button's title in this state is Sell Junk")
	-- a third: marked (not grey) items that don't sell point to Sell Marked
	n, M = boot(function(MM)
		MM.put(0, 1, { id = 5001, name = "Old Boots", q = 1, count = 1, class = 4, subclass = 1, price = 20, equip = "INVTYPE_FEET" })
	end)
	n:Scan(); M.runTimers()
	local rec; for _, r in ipairs(n.items) do if r.itemID == 5001 then rec = r end end
	n.Junk:Toggle(rec)
	C_Container.UseContainerItem = function() end   -- the vendor takes nothing
	n.Junk:Sell("marked", "button")
	for _ = 1, 10 do clock = clock + 0.6; M.runTimers() end
	warn = said(M, "Didn't sell")
	check(warn and warn:find("Old Boots", 1, true) and warn:find("Click Sell Marked", 1, true), "a marked item that doesn't sell is named and points to Sell Marked (" .. tostring(warn) .. ")")
	check(n.Junk.ButtonTitle ~= nil and n.Junk:ButtonTitle() == "Sell Marked Items", "and the button keeps its usual title")
	-- the check never runs forever: a stack that stays locked is reported after the last look
	n, M = boot(function(MM) greys(MM, 2) end)
	C_Container.UseContainerItem = function(bag, slot) if slot == 1 then M.bags[bag][slot] = nil else M.bags[bag][slot].locked = true end end
	n:Scan(); M.runTimers()
	n.Junk:Sell("all", "auto")
	for _ = 1, 20 do clock = clock + 0.6; M.runTimers() end
	warn = said(M, "Didn't sell")
	check(said(M, "Sold 1 junk item") ~= nil and warn and warn:find("Grey Thing 2", 1, true), "a stack that never settles is reported once, after the last look (" .. tostring(warn) .. ")")
	local count = 0; for _, l in ipairs(M.log) do if l:find("Didn't sell", 1, true) then count = count + 1 end end
	check(count == 1, "exactly once")
end)()
