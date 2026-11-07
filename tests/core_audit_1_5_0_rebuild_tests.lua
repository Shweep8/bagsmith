;(function()
	-- 1.5.0 (third build): the 1.5.0 rebuild audit's G7. A currency known only from this character's last save, hidden
	-- under a collapsed header while the game isn't answering for it, must survive the routine delayed save and be
	-- asked about again, so a later real balance (23) is shown and saved; a real reload asks again; an explicit
	-- removal stays removed through saves and missing data. (The auditor's scripts, which assert the defect, are kept
	-- in docs/plugins/audit-1.5.0-rebuild/.)
	local key = "Aldren - Forever"
	local function boot(answer, savedDB)
		package.loaded.mock = nil
		local M = require("mock")
		M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = savedDB or { version = 2, chars = {}, cache = { [key] = { name = "Aldren", realm = "Forever", items = {},
			currencies = { ["c:1901"] = { id = 1901, name = "Honor", count = 150, quality = 1, source = "Wallet" } } } },
			profiles = { Default = { skin = "modern", fav = {} } } }
		local st = { answer = answer, calls = 0 }
		_G.C_CurrencyInfo.GetCurrencyListSize = function() return 1 end
		_G.C_CurrencyInfo.GetCurrencyListInfo = function() return { name = "Hidden group", isHeader = true, isHeaderExpanded = false } end
		_G.C_CurrencyInfo.GetCurrencyListLink = function() return nil end
		_G.C_CurrencyInfo.GetCurrencyInfo = function(id) st.calls = st.calls + 1; if id == 1901 then return st.answer end end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); n.Drawer:Show(); M.runTimers(); M.runTimers()
		return n, M, st
	end
	local function saved(k) return BagSmithDB.cache[key].currencies[k] end
	-- the auditor's sequence
	local n, M, st = boot(nil)
	M.elapse(); M.runTimers()   -- the delayed startup save runs while the game isn't answering
	check(saved("c:1901") and saved("c:1901").count == 150, "G7: the routine delayed save keeps the saved Honor (150) while the game isn't answering")
	st.answer = { name = "Honor", quantity = 23, discovered = true }
	local before = st.calls
	M.fire("CURRENCY_DISPLAY_UPDATE"); M.runTimers()
	check(st.calls > before and n.Currency:Snapshot()["c:1901"] and n.Currency:Snapshot()["c:1901"].count == 23, "G7: when the game answers (23), BagSmith asks again and shows it")
	M.fire("PLAYER_LOGOUT")
	check(saved("c:1901") and saved("c:1901").count == 23, "G7: and logout saves 23")
	-- a real reload after the delayed save asks again
	n, M, st = boot(nil)
	M.elapse(); M.runTimers()
	local db = BagSmithDB
	n, M, st = boot({ name = "Honor", quantity = 23, discovered = true }, db)
	check(st.calls > 0 and n.Currency:Snapshot()["c:1901"] and n.Currency:Snapshot()["c:1901"].count == 23, "G7: after a real reload, BagSmith asks for it again and shows 23")
	-- controls: an earlier good read; explicit removal through a save and later missing data
	n, M, st = boot({ name = "Honor", quantity = 30, discovered = true })
	M.elapse(); M.runTimers()
	check(saved("c:1901") and saved("c:1901").count == 30, "(control) a good first read is saved by the delayed save (30)")
	n, M, st = boot(nil)
	M.elapse(); M.runTimers()
	st.answer = { name = "Honor", quantity = 150, discovered = false }
	M.fire("CURRENCY_DISPLAY_UPDATE"); M.runTimers()
	n:SaveCache()
	check(saved("c:1901") == nil, "(control) the game saying it isn't discovered removes it, and a save records that")
	st.answer = nil
	M.fire("CURRENCY_DISPLAY_UPDATE"); M.runTimers(); M.fire("PLAYER_LOGOUT")
	check(saved("c:1901") == nil, "(control) later missing data doesn't bring a removed currency back")
end)()
