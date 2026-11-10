;(function()
	-- 1.5.0-beta11: the 1.5.0-beta10 audit. Each block is the auditor's reproduction turned into the behaviour that
	-- should hold (the auditor's scripts, which assert the defects, are kept in docs/plugins/audit-1.5.0-beta10/).
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
	M.put(0, 1, { id = 9001, name = "Azure Ring", q = 2, count = 1, class = 4, subclass = 1, ilvl = 24, price = 50, equip = "INVTYPE_FINGER" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local C = n.Corners
	-- ---- F1: other addons' marks get the item's subclass, from records as the scanner makes them
	local seen
	BagSmith.API.RegisterCornerWidget("Subclass Probe", "sub_probe", function(w, d) if d.itemID == 9001 then seen = d.subClassID end return true end, function(b) return b:CreateTexture() end, { corner = "top_left", priority = 1 })
	n.Window:Show(); M.runTimers(); M.runTimers()
	n.Window.main:SetPref("view", "icons"); n:RefreshViews(true); M.runTimers()
	local live
	for _, r in ipairs(n.items) do if r.itemID == 9001 then live = r end end
	check(live and live.subclassID == 1 and seen == 1, "F1: a live item's subclass reaches other addons' marks as subClassID (" .. tostring(seen) .. ")")
	local d = C:Details({}, { itemID = 123, classID = 4, subclassID = 1, cached = true })
	check(d.subClassID == 1, "F1: and an other character's saved item's too")
	-- ---- F2: None empties the whole corner; x removes one backup; the stack count's corner keeps it
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("icons")
	C:Reset()
	local function pick(items, text) for _, it in ipairs(items) do if it.text == text then it.onClick(); return true end end end
	check(pick(P.CornerChoices("bottom_left", 1, "pawn", false), "None") and #n.db.iconCorners.bottom_left == 0, "F2: None on a corner with a backup (Pawn arrow, then gear-set shield) empties it")
	-- (1.6.0, by design) the top left also holds the locked Quest Starter, which None keeps (as the stack count's corner keeps it)
	check(pick(P.CornerChoices("top_left", 1, "junk", false), "None") and table.concat(n.db.iconCorners.top_left, ",") == "quest_start", "F2: None on a corner with one mark empties it")
	C:PlaceAt("junk", "top_left"); C:PlaceAt("pawn", "top_left"); C:PlaceAt("equipment_set", "top_left")
	C:SetSlot("top_left", 3, nil)
	check(table.concat(n.db.iconCorners.top_left, ",") == "quest_start,junk,equipment_set", "F2: x on a backup removes just that one")
	check(pick(P.CornerChoices("top_left", 1, "junk", false), "None") and table.concat(n.db.iconCorners.top_left, ",") == "quest_start", "F2: None with several backups empties the corner")
	C:PlaceAt("pawn", "top_left"); C:PlaceAt("junk", "top_left")
	C:SetSlot("top_left", 1, nil)
	check(table.concat(n.db.iconCorners.top_left, ",") == "quest_start", "F2: the engine's own call, nothing in a corner's first slot, empties it too")
	local q = P.CornerChoices("bottom_right", 1, "quantity", false)
	local offersNone = false; for _, it in ipairs(q) do if it.text == "None" then offersNone = true end end
	C:PlaceAt("item_level", "bottom_right"); C:ClearCorner("bottom_right")
	check(not offersNone and table.concat(n.db.iconCorners.bottom_right, ",") == "quantity", "F2: the stack count's corner offers no None, and clearing it keeps the count")
	C:Reset()
	-- ---- F3: a mark waiting on tooltip data recovers on the same button, without a redraw
	local available, calls = false, 0
	local realTip = _G.C_TooltipInfo
	_G.C_TooltipInfo = { GetHyperlink = function() calls = calls + 1; if available then return { lines = { "loaded" } } end end }
	local b = { cornerFill = 1 }
	local rec = { itemID = 123, link = "item:123", cached = true }
	local w = { isFast = true, onUpdate = function(widget, dt) if not dt.tooltipInfo then return nil end return true end }
	local first = C:Ask(b, rec, "tooltip_test", w, {})
	available = true
	local second = C:Ask(b, rec, "tooltip_test", w, {})
	check(first == nil and second == true and calls == 2, "F3: tooltip data not ready, then ready: the same button's mark asks again and shows (" .. tostring(second) .. ", " .. calls .. " calls)")
	_G.C_TooltipInfo = realTip
end)()

;(function()
	-- ---- F4: currencies under a collapsed wallet header stay (the auditor's harness: the shipped Currency module)
	local function harness(opts)
		opts = opts or {}
		local ns = { items = {}, bankScanned = true, bankItems = {}, db = { customCurrencies = {}, fav = opts.fav or { "c:42" } } }
		function ns:OnSignal() end
		function ns:SavedBank() return {} end
		function ns:CharKey() return "Me - Realm" end
		local st = { collapsed = false, empty = false, byId = 0 }
		_G.BagSmithDB = { cache = { ["Me - Realm"] = { currencies = opts.saved or {} } } }
		_G.C_CurrencyInfo = {
			GetCurrencyListSize = function() if st.empty then return 0 end return st.collapsed and 1 or 3 end,
			GetCurrencyListInfo = function(i)
				if i == 1 then return { isHeader = true, name = "Currencies" } end
				if i == 2 then return { currencyID = 42, name = "Marks", quantity = 150 } end
				return { currencyID = 43, name = "Badges", quantity = 0 }
			end,
			GetCurrencyInfo = function(id)
				st.byId = st.byId + 1
				if id == 42 then return { name = "Marks", quantity = 150, iconFileID = 1 } end
				if id == 43 then return { name = "Badges", quantity = 0, iconFileID = 2 } end
				if id == 77 then return { name = "Old Coins", quantity = 9, iconFileID = 3 } end
			end,
		}
		assert(loadfile("BagSmith/Core/Currency.lua"))("BagSmith", ns)
		return ns, st
	end
	local ns, st = harness()
	check(#ns.Currency:Favorites() == 1 and ns.Currency:Snapshot()["c:42"].count == 150, "(control) an expanded wallet: the favorite and its balance")
	st.collapsed = true; ns.Currency:Invalidate()
	local snap = ns.Currency:Snapshot()
	check(#ns.Currency:Favorites() == 1 and snap["c:42"] and snap["c:42"].count == 150, "F4: collapsing its header keeps the favorite and its balance")
	check(snap["c:43"] and snap["c:43"].count == 0, "F4: a currency at 0 under the collapsed header stays too")
	-- a currency only in this character's last save (not a favorite, not seen this session)
	ns, st = harness({ fav = {}, saved = { ["c:77"] = { id = 77, name = "Old Coins", count = 9 } } })
	st.collapsed = true; ns.Currency:Invalidate()
	check(ns.Currency:Snapshot()["c:77"] and ns.Currency:Snapshot()["c:77"].count == 9, "F4: a currency from this character's last save is found by its ID")
	-- another profile's favorites: what this session has seen still counts
	ns, st = harness()
	ns.Currency:Snapshot()
	ns.db.fav = {}; st.collapsed = true; ns.Currency:Invalidate()
	check(ns.Currency:Snapshot()["c:42"] ~= nil, "F4: after a profile switch, a currency seen this session is still found")
	-- a client with no lookup by ID: a hidden currency keeps the balance last seen this session
	ns, st = harness()
	ns.Currency:Snapshot()
	_G.C_CurrencyInfo.GetCurrencyInfo = nil
	st.collapsed = true; ns.Currency:Invalidate()
	check(#ns.Currency:Favorites() == 1 and ns.Currency:Snapshot()["c:42"] and ns.Currency:Snapshot()["c:42"].count == 150, "F4: without a lookup by ID, a hidden currency keeps its last seen balance instead of being dropped")
	-- a currency the game no longer has is dropped: the lookup finds nothing, or (with no lookup) every header is open
	ns, st = harness({ fav = {} })
	ns.Currency:Snapshot()
	local realGet = _G.C_CurrencyInfo.GetCurrencyInfo
	_G.C_CurrencyInfo.GetCurrencyInfo = function(id) if id == 43 then return nil end return realGet(id) end
	_G.C_CurrencyInfo.GetCurrencyListSize = function() return 2 end
	ns.Currency:Invalidate()
	check(ns.Currency:Snapshot()["c:43"] == nil, "F4: a currency the game no longer has (the lookup finds nothing) is dropped")
	ns, st = harness({ fav = {} })
	ns.Currency:Snapshot()
	_G.C_CurrencyInfo.GetCurrencyInfo = nil
	_G.C_CurrencyInfo.GetCurrencyListInfo = function(i)
		if i == 1 then return { isHeader = true, name = "Currencies", isHeaderExpanded = true } end
		return { currencyID = 42, name = "Marks", quantity = 150 }
	end
	_G.C_CurrencyInfo.GetCurrencyListSize = function() return 2 end
	ns.Currency:Invalidate()
	check(ns.Currency:Snapshot()["c:43"] == nil and ns.Currency:Snapshot()["c:42"] ~= nil, "F4: with no lookup and every header open, a missing currency is dropped")
	-- the logout teardown: an empty list stays unavailable (no lookups by ID, so no zeros)
	ns, st = harness()
	ns.Currency:Snapshot()
	st.empty = true; st.byId = 0; ns.Currency:Invalidate()
	local wallet = 0; for k, e in pairs(ns.Currency:Snapshot()) do if e.source == "Wallet" then wallet = wallet + 1 end end
	check(wallet == 0 and st.byId == 0, "F4: an empty wallet list (the logout teardown) isn't filled in by ID, so the logout rule keeps the last good capture")
end)()
