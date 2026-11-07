;(function()
	-- 1.5.0 production: the 1.5.0-beta14 audit. G4: at logout, teardown lookups by ID never replace the balance captured
	-- during play, even on a cold cache (closed windows, a bag update); G5: a currency the game says is gone stays gone
	-- at logout, even when it was the last one, with or without a save in between; P3: saved entries carry no working
	-- marks on any path. Controls: partial removal, and an unavailable teardown keeping the value. (The auditor's
	-- scripts, which assert the defects, are kept in docs/plugins/audit-1.5.0-beta14/.)
	local function boot(opts)
		opts = opts or {}
		package.loaded.mock = nil
		local M = require("mock")
		M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", fav = {} } } }
		local st = { empty = false, headersOnly = false, honor = 150, removed = false, noAnswer = false, calls = 0, other = opts.other ~= false }
		_G.C_CurrencyInfo.GetCurrencyListSize = function()
			if st.empty then return 0 end
			if st.headersOnly or not st.other then return 2 end
			return 3
		end
		_G.C_CurrencyInfo.GetCurrencyListInfo = function(i)
			if i == 1 then return { name = "Hidden group", isHeader = true, isHeaderExpanded = false } end
			if i == 2 then return { name = "Visible group", isHeader = true, isHeaderExpanded = true } end
			return { name = "Existing balance", currencyID = 1999, quantity = 7 }
		end
		_G.C_CurrencyInfo.GetCurrencyListLink = function() return nil end
		_G.C_CurrencyInfo.GetCurrencyInfo = function(id)
			st.calls = st.calls + 1
			if id == 1901 then
				if st.noAnswer then return nil end
				return { name = "Honor", quantity = st.honor, discovered = not st.removed }
			end
			if id == 1999 and st.other then return { name = "Existing balance", quantity = 7, discovered = true } end
		end
		_G.C_CurrencyInfo.GetBackpackCurrencyInfo = function(i) if i == 1 then return { currencyTypesID = 1901 } end end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		M.elapse(); M.runTimers(); M.elapse(); M.runTimers()
		n.Window:Show(); n.Drawer:Show(); M.runTimers(); M.runTimers()
		n.Drawer.frame.import:GetScript("OnClick")(n.Drawer.frame.import)
		return n, M, st
	end
	local function saved(n, k) return BagSmithDB.cache[n:CharKey()].currencies[k] end
	-- ---- G4: a cold cache at logout (the closed-window bag-update path), headers still there, lookups reporting 0
	local n, M, st = boot()
	n.Drawer:Hide(); n.Window:Hide()
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
	st.headersOnly = true; st.honor = 0
	local before = st.calls
	M.fire("PLAYER_LOGOUT")
	check(st.calls > before, "(control) the cold cache really made fresh lookups during logout")
	check(saved(n, "c:1901") and saved(n, "c:1901").count == 150, "G4: lookups by ID reporting 0 during logout don't replace the 150 captured during play")
	-- the direct invalidation variant
	n, M, st = boot()
	n.Currency:Invalidate(); st.headersOnly = true; st.honor = 0
	M.fire("PLAYER_LOGOUT")
	check(saved(n, "c:1901") and saved(n, "c:1901").count == 150 and saved(n, "c:1999") and saved(n, "c:1999").count == 7, "G4: and after a plain invalidation too (the other currency keeps 7)")
	-- ---- G5: the game says the last currency is gone; it stays gone at logout, with or without a save first
	for _, withSave in ipairs({ false, true }) do
		n, M, st = boot({ other = false })
		M.fire("CURRENCY_DISPLAY_UPDATE")
		st.removed = true; M.fire("CURRENCY_DISPLAY_UPDATE"); M.runTimers()
		local gone = n.Currency:Snapshot()["c:1901"] == nil
		if withSave then n:SaveCache() end
		st.empty = true; M.fire("CURRENCY_DISPLAY_UPDATE"); M.fire("PLAYER_LOGOUT")
		check(gone and saved(n, "c:1901") == nil, "G5: the last currency, reported gone, stays gone at logout" .. (withSave and " (with a save in between)" or " (no save in between)"))
	end
	-- partial removal control
	n, M, st = boot()
	M.fire("CURRENCY_DISPLAY_UPDATE")
	st.removed = true; M.fire("CURRENCY_DISPLAY_UPDATE"); M.runTimers()
	st.empty = true; M.fire("CURRENCY_DISPLAY_UPDATE"); M.fire("PLAYER_LOGOUT")
	check(saved(n, "c:1901") == nil and saved(n, "c:1999") and saved(n, "c:1999").count == 7, "(control) removing one of two: it stays gone, the other keeps 7")
	-- unavailable teardown control: no currency rows and no answer is unavailable, not gone
	n, M, st = boot({ other = false })
	M.fire("CURRENCY_DISPLAY_UPDATE")
	st.noAnswer = true; M.fire("CURRENCY_DISPLAY_UPDATE"); M.runTimers()
	st.empty = true; M.fire("CURRENCY_DISPLAY_UPDATE"); M.fire("PLAYER_LOGOUT")
	check(saved(n, "c:1901") and saved(n, "c:1901").count == 150, "(control) headers only and no answer from the game: unavailable, so the 150 is kept")
	-- ---- P3: saved entries carry only the saved fields, on the capture path
	n, M, st = boot()
	st.empty = true; M.fire("CURRENCY_DISPLAY_UPDATE"); M.fire("PLAYER_LOGOUT")
	local e = saved(n, "c:1901")
	local extra = {}
	for k in pairs(e or {}) do if not ({ id = 1, name = 1, icon = 1, count = 1, quality = 1, source = 1 })[k] then extra[#extra + 1] = k end end
	check(e and e.count == 150 and #extra == 0, "P3: an imported balance saved through the logout fallback has only the saved fields (" .. table.concat(extra, ",") .. ")")
end)()
