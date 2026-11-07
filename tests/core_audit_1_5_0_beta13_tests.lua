;(function()
	-- 1.5.0-beta14: the 1.5.0-beta13 audit's G3. A balance found by ID through Import Blizzard Picks, and only displayed
	-- (no save, no currency update since), must still reach the logout save when the list empties and an empty
	-- currency update arrives before logout; an unrelated, already captured currency keeps its balance; the three
	-- controls (plain logout, a normal save first, a valid update first) keep it too; a removed currency stays gone.
	-- (The auditor's reproduction, which asserts the defect, is kept in docs/plugins/audit-1.5.0-beta13/.)
	local function run(teardownEvent, capture)
		package.loaded.mock = nil
		local M = require("mock")
		M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", fav = {} } } }
		local st = { empty = false, removed = false }
		_G.C_CurrencyInfo.GetCurrencyListSize = function() return st.empty and 0 or 3 end
		_G.C_CurrencyInfo.GetCurrencyListInfo = function(i)
			if i == 1 then return { name = "Hidden group", isHeader = true, isHeaderExpanded = false } end
			if i == 2 then return { name = "Visible group", isHeader = true, isHeaderExpanded = true } end
			return { name = "Existing balance", currencyID = 1999, quantity = 7 }
		end
		_G.C_CurrencyInfo.GetCurrencyInfo = function(id)
			if id == 1901 and not st.removed then return { name = "Honor", quantity = 150, discovered = true } end
			if id == 1999 then return { name = "Existing balance", quantity = 7, discovered = true } end
		end
		_G.C_CurrencyInfo.GetBackpackCurrencyInfo = function(i) if i == 1 then return { currencyTypesID = 1901 } end end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		M.elapse(); M.runTimers(); M.elapse(); M.runTimers()   -- the startup saves have run
		n.Window:Show(); n.Drawer:Show(); M.runTimers(); M.runTimers()
		n.Drawer.frame.import:GetScript("OnClick")(n.Drawer.frame.import)
		if capture == "save" then n:SaveCache() end
		if capture == "event" then M.fire("CURRENCY_DISPLAY_UPDATE") end
		return n, M, st
	end
	local function logout(n, M, st, teardownEvent)
		st.empty = true
		if teardownEvent then M.fire("CURRENCY_DISPLAY_UPDATE") end
		M.fire("PLAYER_LOGOUT")
		return BagSmithDB.cache[n:CharKey()].currencies
	end
	local n, M, st = run()
	local snap = logout(n, M, st, true)
	check(snap["c:1901"] and snap["c:1901"].count == 150, "G3: an imported balance, only displayed, reaches the logout save after an empty update before logout")
	check(snap["c:1999"] and snap["c:1999"].count == 7, "G3: and the already captured currency keeps its balance (7)")
	n, M, st = run(); snap = logout(n, M, st, false)
	check(snap["c:1901"] and snap["c:1901"].count == 150 and snap["c:1999"].count == 7, "(control) a plain logout keeps both")
	n, M, st = run(nil, "save"); snap = logout(n, M, st, true)
	check(snap["c:1901"] and snap["c:1901"].count == 150 and snap["c:1999"].count == 7, "(control) a normal save first keeps both")
	n, M, st = run(nil, "event"); snap = logout(n, M, st, true)
	check(snap["c:1901"] and snap["c:1901"].count == 150 and snap["c:1999"].count == 7, "(control) a valid currency update first keeps both")
	-- teardown lookups by ID that report 0 don't overwrite the balance captured during play
	n, M, st = run()
	local realGet = _G.C_CurrencyInfo.GetCurrencyInfo
	_G.C_CurrencyInfo.GetCurrencyListSize = function() return 2 end   -- only the headers are left during logout
	_G.C_CurrencyInfo.GetCurrencyInfo = function(id) if id == 1901 then return { name = "Honor", quantity = 0, discovered = true } end return realGet(id) end
	M.fire("PLAYER_LOGOUT")
	snap = BagSmithDB.cache[n:CharKey()].currencies
	check(snap["c:1901"] and snap["c:1901"].count == 150, "a lookup by ID during logout that reports 0 doesn't replace the balance captured during play")
	check(snap["c:1901"].byId == nil, "and saved entries carry no working marks")
	-- a real spend to 0 during play, found by ID, is saved as 0
	n, M, st = run()
	_G.C_CurrencyInfo.GetCurrencyInfo = function(id) if id == 1901 then return { name = "Honor", quantity = 0, discovered = true } end return realGet(id) end
	M.fire("CURRENCY_DISPLAY_UPDATE")
	snap = logout(n, M, st, true)
	check(snap["c:1901"] and snap["c:1901"].count == 0, "Honor really spent to 0 during play (found by ID) is saved as 0")
	_G.C_CurrencyInfo.GetCurrencyInfo = realGet
	-- a currency the game removes after it was captured isn't brought back by an older capture
	n, M, st = run()
	st.removed = true; n.Currency:Invalidate(); n.Currency:List()   -- a readable list without Honor replaces the capture
	snap = logout(n, M, st, true)
	check(snap["c:1901"] == nil and snap["c:1999"] and snap["c:1999"].count == 7, "a currency the game has removed stays gone (the capture is replaced, not merged)")
end)()
