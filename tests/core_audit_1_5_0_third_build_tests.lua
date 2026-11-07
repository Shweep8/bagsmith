;(function()
	-- 1.5.1-beta1: G8 from the 1.5.0 third-build audit, asserting the corrected behavior (it fails on 1.5.0). A
	-- currency known only from this character's save, hidden under a collapsed header, whose lookup by ID gives no
	-- answer (nil, or a blank name with discovered = true) while another currency row is visible, is unavailable,
	-- not gone: its last value carries over, it stays saved, it keeps being asked about, and a later answer is
	-- shown and saved. Gone still means the game said so (discovered = false), or every header is open and the
	-- lookup finds nothing. The auditor's fixture (docs/plugins/audit-1.5.0-third-build) is the starting point.
	local K = "Aldren - Forever"
	local HONOR = { id = 1901, name = "Honor", count = 150, quality = 1, source = "Wallet" }
	local function copy(t) local o = {}; for k, v in pairs(t) do o[k] = type(v) == "table" and copy(v) or v end; return o end
	local function boot(o)
		package.loaded.mock = nil
		local M = require("mock")
		M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = o.db or { version = 2, chars = {}, cache = { [K] = { name = "Aldren", realm = "Forever", items = {}, currencies = copy(o.saved) } },
			profiles = { Default = { skin = "modern", fav = o.fav or {} } } }
		local st = { calls = {} }
		C_CurrencyInfo.GetCurrencyListSize = function() return #o.rows end
		C_CurrencyInfo.GetCurrencyListInfo = function(i) return o.rows[i] end
		C_CurrencyInfo.GetCurrencyListLink = function() return nil end
		C_CurrencyInfo.GetCurrencyInfo = function(id) st.calls[id] = (st.calls[id] or 0) + 1; return o.lookup(id) end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); n.Drawer:Show(); M.runTimers(); M.runTimers()
		return n, M, st
	end
	local function saved(key) local c = BagSmithDB.cache[K]; return c and c.currencies and c.currencies[key] end
	local function shown(n, key) n.Currency:Invalidate(); for _, e in ipairs(n.Currency:List()) do if e.key == key then return e end end end
	local COLLAPSED = { name = "Honor group", isHeader = true, isHeaderExpanded = false }
	local OPEN = { name = "Other group", isHeader = true, isHeaderExpanded = true }
	local OTHER = { name = "Visible other currency", currencyID = 1999, quantity = 7 }

	-- ---- G8: partial collapse with an unrelated readable row, nil and blank answers
	local afterG8
	for _, status in ipairs({ "missing", "blank" }) do
		local ready = false
		local o = { saved = { ["c:1901"] = HONOR }, rows = { COLLAPSED, OPEN, OTHER } }
		o.lookup = function(id)
			if id == 1999 then return { name = "Visible other currency", quantity = 7, discovered = true } end
			if id == 1901 then
				if ready then return { name = "Honor", quantity = 23, discovered = true } end
				if status == "blank" then return { name = "", quantity = 0, discovered = true } end
			end
		end
		local n, M, st = boot(o)
		local tag = "G8 (" .. status .. "): "
		check(n.liveWallet["c:1901"] and n.liveWallet["c:1901"].count == 150 and n.liveWallet["c:1999"].count == 7,
			tag .. "Honor under a collapsed header with no answer is carried at its saved 150 beside the visible 7")
		check(shown(n, "c:1901") == nil and shown(n, "c:1999") ~= nil, tag .. "the display is unchanged: Honor isn't listed until the game answers")
		M.elapse(); M.runTimers()
		check(saved("c:1901") and saved("c:1901").count == 150, tag .. "the delayed save keeps Honor's saved entry (it isn't gone)")
		local before = st.calls[1901] or 0
		ready = true; M.fire("CURRENCY_DISPLAY_UPDATE"); M.runTimers()
		local snap = n.Currency:Snapshot()
		check((st.calls[1901] or 0) > before and snap["c:1901"] and snap["c:1901"].count == 23,
			tag .. "when the game answers later, Honor is asked for and shows 23 (asked " .. ((st.calls[1901] or 0) - before) .. " times)")
		check(snap["c:1999"] and snap["c:1999"].count == 7, tag .. "the other currency is unchanged")
		M.fire("PLAYER_LOGOUT")
		check(saved("c:1901") and saved("c:1901").count == 23 and saved("c:1999") and saved("c:1999").count == 7, tag .. "logout saves Honor 23 and the other 7")
		afterG8 = copy(BagSmithDB)
	end

	-- ---- a real reload: the next session starts from that save, Honor unanswered again
	do
		local o = { db = afterG8, rows = { COLLAPSED, OPEN, OTHER } }
		o.lookup = function(id) if id == 1999 then return { name = "Visible other currency", quantity = 7, discovered = true } end end
		local n, M = boot(o)
		check(n.liveWallet["c:1901"] and n.liveWallet["c:1901"].count == 23, "after a reload, Honor (still unanswered) carries over from the save at 23")
		M.elapse(); M.runTimers(); M.fire("PLAYER_LOGOUT")
		check(saved("c:1901") and saved("c:1901").count == 23, "and a save and a logout without an answer keep it at 23")
	end

	-- ---- unreported header state counts as possibly collapsed
	do
		local o = { saved = { ["c:1901"] = HONOR }, rows = { { name = "Some group", isHeader = true }, OTHER } }
		o.lookup = function(id) if id == 1999 then return { name = "Visible other currency", quantity = 7, discovered = true } end end
		local n, M = boot(o)
		M.elapse(); M.runTimers()
		check(n.liveWallet["c:1901"] and saved("c:1901") and saved("c:1901").count == 150, "a header that doesn't report its state may be hiding Honor: kept at 150")
	end

	-- ---- removal controls (unchanged)
	do -- every header open, Honor not listed, the lookup finds nothing: gone
		local o = { saved = { ["c:1901"] = HONOR }, rows = { OPEN, OTHER } }
		o.lookup = function(id) if id == 1999 then return { name = "Visible other currency", quantity = 7, discovered = true } end end
		local n, M = boot(o)
		M.elapse(); M.runTimers()
		check(not n.liveWallet["c:1901"] and not saved("c:1901"), "control: with every header open and no answer, Honor is gone (capture and save)")
		M.fire("PLAYER_LOGOUT")
		check(not saved("c:1901") and saved("c:1999"), "control: and stays gone at logout")
	end
	do -- the game says it isn't discovered, even under a collapsed header: gone
		local o = { saved = { ["c:1901"] = HONOR }, rows = { COLLAPSED, OPEN, OTHER } }
		o.lookup = function(id)
			if id == 1999 then return { name = "Visible other currency", quantity = 7, discovered = true } end
			if id == 1901 then return { name = "Honor", quantity = 0, discovered = false } end
		end
		local n, M = boot(o)
		M.elapse(); M.runTimers()
		check(not n.liveWallet["c:1901"] and not saved("c:1901"), "control: discovered = false under a collapsed header is gone")
	end
	do -- the final currency: no currency rows, the game says not discovered: gone
		local o = { saved = { ["c:1901"] = HONOR }, rows = { OPEN } }
		o.lookup = function(id) if id == 1901 then return { name = "Honor", quantity = 0, discovered = false } end end
		local n, M = boot(o)
		M.elapse(); M.runTimers()
		check(not n.liveWallet["c:1901"] and not saved("c:1901"), "control: the last currency, reported not discovered, is gone")
	end
	do -- no currency rows and no answer: unavailable, carried (G5's rule, unchanged)
		local o = { saved = { ["c:1901"] = HONOR }, rows = { OPEN } }
		o.lookup = function() end
		local n, M = boot(o)
		M.elapse(); M.runTimers()
		check(n.liveWallet["c:1901"] and saved("c:1901") and saved("c:1901").count == 150, "control: no currency rows and no answer keeps Honor at 150")
	end
	do -- partial removal with every header open: one of two saved currencies goes, the other stays
		local o = { saved = { ["c:1901"] = HONOR, ["c:1902"] = { id = 1902, name = "Marks", count = 4, quality = 1, source = "Wallet" } },
			rows = { OPEN, OTHER, { name = "Marks", currencyID = 1902, quantity = 5 } } }
		o.lookup = function(id)
			if id == 1999 then return { name = "Visible other currency", quantity = 7, discovered = true } end
			if id == 1902 then return { name = "Marks", quantity = 5, discovered = true } end
		end
		local n, M = boot(o)
		M.elapse(); M.runTimers()
		check(not saved("c:1901") and saved("c:1902") and saved("c:1902").count == 5, "control: with every header open, the missing one is gone and the listed one is saved at 5")
	end
end)()
