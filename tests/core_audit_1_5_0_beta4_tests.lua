;(function()
	-- 1.5.0-beta5: the 1.5.0-beta4 audit. Each block is the auditor's reproduction turned into the behaviour
	-- that should hold (the auditor's own scripts, which assert the defects, are kept in the dev kit's
	-- docs/plugins/audit-1.5.0-beta4/ with their before and after output).

	-- ---- F1: opted-in widgets get their scale every time; widgets that didn't opt in keep their own size
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
	M.put(0, 1, { id = 9001, name = "Azure Ring", q = 2, count = 1, class = 4, subclass = 0, ilvl = 24, price = 50, equip = "INVTYPE_FINGER" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V = n.Window.main; V:SetPref("view", "icons"); V:SetPref("grp", "none")
	local own
	BagSmith.API.RegisterCornerWidget("Scaled frame", "scaled_frame", function() return true end, function(b) local w = CreateFrame("Frame", nil, b); w:SetSize(14, 14); w.bagsmithScale = true; return w end, { corner = "top_right", priority = 1 })
	BagSmith.API.RegisterCornerWidget("Scaled texture", "scaled_texture", function() return true end, function(b) local w = b:CreateTexture(); w:SetSize(14, 14); w.bagsmithScale = true; return w end, { corner = "top_left", priority = 1 })
	BagSmith.API.RegisterCornerWidget("Own size", "own_size", function(w) w:SetSize(own or 14, own or 14); return true end, function(b) local w = b:CreateTexture(); w:SetSize(14, 14); return w end, { corner = "bottom_left", priority = 1 })
	local function find() for _, b in ipairs(V.used) do if b:IsShown() and b.rec and b.rec.itemID == 9001 then return b end end end
	local okFrame, okTex, okOwn = true, true, true
	for _, step in ipairs({ { 24 }, { 37 }, { 48 }, { 37 }, { 37 } }) do
		n:Set("iconSize", step[1]); n:RefreshViews(true); M.runTimers()
		local b = find()
		local f, t = b.cornerWidgets.scaled_frame, b.cornerWidgets.scaled_texture
		local want = n.Corners:Scale(b, "cell")
		if math.abs((f.scale or 1) - want) > 1e-6 then okFrame = false end
		if math.abs(t:GetWidth() - 14 * want) > 1e-6 then okTex = false end
		if step[1] == 37 and ((f.scale or 1) ~= 1 or t:GetWidth() ~= 14) then okFrame, okTex = false, false end
	end
	check(okFrame, "F1: an opted-in frame's scale follows the icon both ways, back to exactly 1 at the default size (24, 37, 48, 37, 37)")
	check(okTex, "F1: an opted-in texture is resized from the size it was made at, back to 14 at the default size")
	own = 18; n:RefreshViews(true); M.runTimers()
	local ob = find().cornerWidgets.own_size
	check(ob:GetWidth() == 18, "F1: a widget that didn't opt in keeps the size its own addon gives it, even as that changes")

	-- ---- F2: a slow first corner doesn't starve later corners; answers last for the button's fill
	package.loaded.mock = nil
	M = require("mock")
	M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
	M.put(0, 1, { id = 9001, name = "Azure Ring", q = 2, count = 1, class = 4, subclass = 0, ilvl = 24, price = 50, equip = "INVTYPE_FINGER" })
	M.put(0, 2, { id = 2589, name = "Linen Cloth", q = 1, count = 1, class = 7, subclass = 5, price = 1 })
	local now = 0
	_G.debugprofilestop = function() return now end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	V = n.Window.main; V:SetPref("view", "icons"); V:SetPref("grp", "none"); n:RefreshViews(true); M.runTimers()
	local calls1, calls2, ready = {}, {}, false
	BagSmith.API.RegisterCornerWidget("Slow first", "slow_first", function(w, d) calls1[d.itemID] = (calls1[d.itemID] or 0) + 1; now = now + 5; return true end, function(b) return b:CreateTexture() end, { corner = "top_left", priority = 1 })
	BagSmith.API.RegisterCornerWidget("Later corner", "later", function(w, d) calls2[d.itemID] = (calls2[d.itemID] or 0) + 1; if not ready then return nil end; return true end, function(b) return b:CreateTexture() end, { corner = "top_right", priority = 1 })
	n:RefreshViews(true); M.runTimers(); M.runTimers()   -- (registering asks for a refresh of its own: let it settle)
	local base1 = { [9001] = calls1[9001] or 0, [2589] = calls1[2589] or 0 }
	local fillBefore
	for _, b in ipairs(V.used) do if b:IsShown() and b.rec and b.rec.itemID == 9001 then fillBefore = b.cornerFill end end
	for _ = 1, 10 do M.runTimers(); n.Corners:RunRetries() end
	local fillAfter
	for _, b in ipairs(V.used) do if b:IsShown() and b.rec and b.rec.itemID == 9001 then fillAfter = b.cornerFill end end
	check((calls2[9001] or 0) >= 1 and (calls2[2589] or 0) >= 1, "F2: a later corner gets asked for every button, though a slow first corner uses the frame's budget")
	-- (the fill's first ask may itself have waited a frame for budget; after that it isn't asked again)
	check(fillBefore == fillAfter and calls1[9001] - base1[9001] <= 1 and calls1[2589] - base1[2589] <= 1, "F2: across ten retry frames of the same fill, a widget is asked at most once")
	ready = true
	for _ = 1, 4 do M.runTimers(); n.Corners:RunRetries() end
	local ring
	for _, b in ipairs(V.used) do if b:IsShown() and b.rec and b.rec.itemID == 9001 then ring = b end end
	check(ring.cornerWidgets.later:IsShown() and ring.cornerWidgets.slow_first:IsShown() and next(n.Corners.retries) == nil, "F2: not ready, then ready: the later corner shows, and nothing is left queued")
	local was = calls1[9001]
	n:RefreshViews(true)
	check(calls1[9001] == was + 1, "F2: a fresh fill asks again, once")
end)()

;(function()
	-- ---- F3 and F4: the wallet at logout (the auditor's reproduction, as the behaviour that should hold)
	local function boot(custom)
		package.loaded.mock = nil
		local M = require("mock")
		M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
		M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 12, class = 7, subclass = 5, price = 1 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", customCurrencies = custom or {} } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n:SaveCache()
		return n, M, n:CharKey()
	end
	local n, M, key = boot({ 2589 })
	check(BagSmithDB.cache[key].currencies["c:1901"].count == 1250 and BagSmithDB.cache[key].currencies["i:2589"].count == 12, "(control) a play-time save has Honor and the tracked Linen")
	M.currencies = {}; M.fire("CURRENCY_DISPLAY_UPDATE"); M.fire("PLAYER_LOGOUT")
	local saved = BagSmithDB.cache[key].currencies
	check(saved["c:1901"] and saved["c:1901"].count == 1250, "F3: the wallet unavailable at logout keeps the last good capture, even with a tracked item listed")
	check(saved["i:2589"] and saved["i:2589"].count == 12, "F3: and the tracked item keeps its own count")
	-- a tracked item at 0 doesn't stand in for the wallet either
	n, M, key = boot({ 2589, 4306 })
	M.currencies = {}; M.fire("CURRENCY_DISPLAY_UPDATE"); M.fire("PLAYER_LOGOUT")
	saved = BagSmithDB.cache[key].currencies
	check(saved["c:1901"] and saved["c:1901"].count == 1250 and saved["i:4306"] and saved["i:4306"].count == 0, "F3: with a tracked item at 0, the wallet is still kept")
	-- F4: spent to zero right before logout, before the delayed save
	n, M, key = boot()
	M.currencies[2].quantity = 0
	M.fire("CURRENCY_DISPLAY_UPDATE")
	check(n.liveWallet["c:1901"].count == 0, "F4: a currency change is captured the moment it happens")
	M.currencies = {}; M.fire("PLAYER_LOGOUT")
	check(BagSmithDB.cache[key].currencies["c:1901"] and BagSmithDB.cache[key].currencies["c:1901"].count == 0, "F4: a currency spent to 0 just before logout is saved as 0")
	-- (control) with the delayed save allowed to run
	n, M, key = boot()
	M.currencies[2].quantity = 0; M.fire("CURRENCY_DISPLAY_UPDATE"); M.runTimers(); M.elapse()
	M.currencies = {}; n.Currency:Invalidate(); M.fire("PLAYER_LOGOUT")
	check(BagSmithDB.cache[key].currencies["c:1901"].count == 0, "(control) the delayed save keeps the 0 too")
	-- positive to positive, and a normal logout with the wallet still there
	n, M, key = boot()
	M.currencies[2].quantity = 1300; M.fire("CURRENCY_DISPLAY_UPDATE"); M.fire("PLAYER_LOGOUT")
	check(BagSmithDB.cache[key].currencies["c:1901"].count == 1300, "a change from one amount to another, then a normal logout, saves the new amount")
	-- a currency removed from the wallet while others remain is gone
	n, M, key = boot()
	local before = #M.currencies
	table.remove(M.currencies, 2)
	M.fire("CURRENCY_DISPLAY_UPDATE")
	check(before > 1 and n.liveWallet["c:1901"] == nil, "a currency the game stops listing (others still there) is dropped from the capture")
	-- teardown before logout: an empty wallet event doesn't replace the capture
	n, M, key = boot()
	M.currencies = {}; M.fire("CURRENCY_DISPLAY_UPDATE")
	check(n.liveWallet["c:1901"] and n.liveWallet["c:1901"].count == 1250, "an event with nothing listed at all (the teardown) keeps the last good capture")
end)()

;(function()
	-- ---- F5: a bag-window gesture cancels an older main-window section-drop check (the auditor's reproduction)
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
	M.put(0, 2, { id = 117, name = "Tough Jerky", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", emptySlots = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V, S = n.Window.main, n.Sections
	local c = S:Create("Audit"); S:SetPinned(c, true); S:Move(2589, c)
	V:SetPref("grp", "none"); V:SetPref("view", "icons"); V:SetPref("sort", "off"); n:RefreshViews(true); M.runTimers()
	local main = n.Buttons:Get(0, 2)
	M.cursorItem = 2589; M.bags[0][2].locked = true
	main:GetScript("OnMouseDown")(main, "LeftButton"); main:GetScript("OnClick")(main, "LeftButton")
	local generation = S.dropGen
	check(S:MovedTo(2589) == c, "(control) the refused main-window placement keeps the assignment")
	M.bags[0][2].locked = nil
	local mirror = n.Buttons:GetMirror(CreateFrame("Frame", nil, UIParent), 1)
	mirror.bag = 0; mirror:SetID(2)
	local realPickup = C_Container.PickupContainerItem
	C_Container.PickupContainerItem = function(bag, slot)
		M.bags[0][slot], M.bags[0][1] = M.bags[0][1], M.bags[0][slot]
		M.cursorItem = 117
	end
	mirror:GetScript("OnClick")(mirror, "LeftButton")
	check(S.dropGen > generation, "F5: a bag-window gesture counts as a new gesture")
	for _ = 1, 4 do M.runTimers() end
	check(S:MovedTo(2589) == c, "F5: so the older main-window check is cancelled, and Linen keeps its pinned section")
	-- a bag-window drag and a drop on the overlay count too
	local g = S.dropGen
	mirror:GetScript("OnDragStart")(mirror)
	check(S.dropGen > g, "F5: a bag-window drag counts as a gesture")
	g = S.dropGen
	n.Drop:Place(V)
	check(S.dropGen > g, "F5: a drop on the window's overlay counts as a gesture")
	C_Container.PickupContainerItem = realPickup
	-- (control) an accepted main-window placement onto All Items still takes the item out of the pinned section
	M.cursorItem = nil
	n:Scan(); n:RefreshViews(true); M.runTimers()
	local linenRow
	for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 2589 and b.inLane == c then linenRow = b end end
	local gap
	for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.empty and (b.inLane == "~all" or b.inLane == "") then gap = b; break end end
	if linenRow and gap then
		linenRow:GetScript("OnDragStart")(linenRow)
		local from = linenRow.rec
		M.bags[gap.rec.bag][gap.rec.slot], M.bags[from.bag][from.slot] = M.bags[from.bag][from.slot], nil
		gap:GetScript("OnReceiveDrag")(gap)
	end
	check(linenRow and gap and S:MovedTo(2589) == nil, "(control) an accepted placement onto All Items still takes Linen out of its pinned section")
end)()
