;(function()
	-- 1.5.0 (rebuilt): the 1.5.0 release audit's G6. On a cold session, a saved balance BagSmith knows only from this
	-- character's last save survives logout when the first readable read gives no answer for it (nil, or a blank
	-- name), with or without an earlier good capture; removal and update controls still hold. (The auditor's
	-- reproduction, which asserts the defect, is kept in docs/plugins/audit-1.5.0-release/.)
	local key = "Aldren - Forever"
	local function boot(answer, rowsOther)
		package.loaded.mock = nil
		local M = require("mock")
		M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = { [key] = { name = "Aldren", realm = "Forever", items = {},
			currencies = { ["c:1901"] = { id = 1901, name = "Honor", count = 150, quality = 1, source = "Wallet" } } } },
			profiles = { Default = { skin = "modern", fav = {} } } }
		local st = { answer = answer }
		_G.C_CurrencyInfo.GetCurrencyListSize = function() return rowsOther and 2 or 1 end
		_G.C_CurrencyInfo.GetCurrencyListInfo = function(i)
			if i == 1 then return { name = "Hidden group", isHeader = true, isHeaderExpanded = false } end
			return { name = "Other", currencyID = 1999, quantity = 7 }
		end
		_G.C_CurrencyInfo.GetCurrencyListLink = function() return nil end
		_G.C_CurrencyInfo.GetCurrencyInfo = function(id) if id == 1901 then return st.answer end end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M, st
	end
	local function saved(k) return BagSmithDB.cache[key].currencies[k] end
	-- the auditor's case: no answer on the first read, then logout before any save or capture
	local n, M, st = boot(nil)
	check(n:CharKey() == key and saved("c:1901").count == 150, "(control) the saved Honor 150 is there before logout")
	n.Window:Show(); n.Drawer:Show(); M.runTimers(); M.runTimers()
	M.fire("PLAYER_LOGOUT")
	check(saved("c:1901") and saved("c:1901").count == 150, "G6: an unanswered first read doesn't erase the saved 150 at logout")
	-- a blank name on the first read is unanswered too
	n, M, st = boot({ name = "", quantity = 0 })
	n.Window:Show(); n.Drawer:Show(); M.runTimers(); M.runTimers()
	M.fire("PLAYER_LOGOUT")
	check(saved("c:1901") and saved("c:1901").count == 150, "G6: a blank-name first read keeps the saved 150 too")
	-- with an earlier good capture this session, then no answer: the capture's value carries over
	n, M, st = boot({ name = "Honor", quantity = 160, discovered = true })
	M.fire("CURRENCY_DISPLAY_UPDATE")
	st.answer = nil; M.fire("CURRENCY_DISPLAY_UPDATE")
	M.fire("PLAYER_LOGOUT")
	check(saved("c:1901") and saved("c:1901").count == 160, "G6: after a good capture (160), no answer keeps the captured value")
	-- controls: a valid answer saves it; an explicit removal removes it, with or without a save first
	n, M, st = boot({ name = "Honor", quantity = 23, discovered = true })
	M.fire("CURRENCY_DISPLAY_UPDATE"); M.fire("PLAYER_LOGOUT")
	check(saved("c:1901") and saved("c:1901").count == 23, "(control) a valid answer on the first read is saved (23)")
	for _, withSave in ipairs({ false, true }) do
		n, M, st = boot({ name = "Honor", quantity = 150, discovered = false })
		M.fire("CURRENCY_DISPLAY_UPDATE")
		if withSave then n:SaveCache() end
		M.fire("PLAYER_LOGOUT")
		check(saved("c:1901") == nil, "(control) the game saying it isn't discovered still removes it" .. (withSave and " (with a save first)" or " (no save first)"))
	end
	-- partial removal: currency rows shown, Honor gone; the other currency keeps 7
	n, M, st = boot({ name = "Honor", quantity = 150, discovered = false }, true)
	M.fire("CURRENCY_DISPLAY_UPDATE"); M.fire("PLAYER_LOGOUT")
	check(saved("c:1901") == nil and saved("c:1999") and saved("c:1999").count == 7, "(control) partial removal: Honor gone, the other keeps 7")
end)()
