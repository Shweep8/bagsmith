--[[
	BagSmith - Frames/Window.lua
	Creates the views and coordinates them: which windows exist for the
	current layout, refreshing everything, lane/tab reordering, sheets,
	bank open/close and login initialization.
--]]

local ADDON, ns = ...
local View = ns.View

local Window = {}
ns.Window = Window

function Window:Create()
	if self.main then return end
	self.main = View.New("BagSmithFrame", { kind = "main", title = "Your Bags" })
	self.bank = View.New("BagSmithBankFrame", { kind = "bank", title = "Bank" })
	-- Clean Up Bags When Opened: once per opening, never in combat, at the
	-- bank, or while viewing another character's bags.
	-- 1.2.0: a window that comes up with items in the bags and nothing placed (seen once on the first open
	-- after a character switch, in Icons view) gets one forced rebuild a moment later.
	self.main.frame:HookScript("OnShow", function()
		C_Timer.After(0.3, function()
			local m = self.main
			if not (m and m:IsShown()) then return end
			if (#(ns.items or {}) > 0) and (not m.used or #m.used == 0) and not InCombatLockdown() then
				ns:Debug("main window shown with %d items and nothing placed: rebuilding", #ns.items)
				m:Refresh(true, "first-open-guard")
			end
		end)
	end)
	self.main.frame:HookScript("OnShow", function()
		if not (ns.db and ns.db.cleanOnOpen) then return end
		C_Timer.After(0.1, function()
			local m = self.main
			if m:IsShown() and not InCombatLockdown() and not ns.atBank and not ns.ui.owner and not UnitIsDead("player") and m.st.sheet ~= "Bank" then
				ns.cleanedOnOpen = (ns.cleanedOnOpen or 0) + 1
				m:CleanUp()
			end
		end)
	end)
	self.bagViews = {}
	for _, bag in ipairs(ns.BAGS) do
		if bag ~= ns.KEYRING then
			self.bagViews[bag] = View.New("BagSmithBag" .. (bag < 0 and (100 - bag) or bag), { kind = "bag", title = ns:BagName(bag), bags = { bag },
				width = bag == ns.BACKPACK and 306 or 264, anchor = function() return self.main.frame end })
		end
	end
	-- Bank bags, including the bank's own slots, each in a small window titled "Bank: ...".
	self.bankBagViews = {}
	for _, bag in ipairs(ns.BANK_BAGS) do
		self.bankBagViews[bag] = View.New("BagSmithBankBag" .. (bag < 0 and (100 - bag) or bag), { kind = "bag", bank = true, title = "Bank", bags = { bag },
			anchor = function() return self.bank.frame end })
	end
end

-- Which auxiliary windows should be open right now.
function ns:ApplyLayout()
	local W = Window
	if not W.main then return end
	local mainShown = W.main:IsShown()
	local db = ns.db
	local anyNew = false
	for bag, v in pairs(W.bagViews) do
		local sb, sr = ns.SessionWindows()
		local toggled = ns:IsReagentBag(bag) and sr or (not ns:IsReagentBag(bag) and sb and not (ns.ui.closedBags and ns.ui.closedBags[bag]))
		local size = ns.bagInfo[bag] and ns.bagInfo[bag].size or 0
		local want = mainShown and toggled and ns.ui.sheet ~= "Bank" and not ns.ui.owner and size > 0
		-- /bs debug: why a bag window that's switched on isn't showing (logged when it changes).
		local why
		if toggled and not want then
			why = (not mainShown and "the bags window is closed") or (ns.ui.sheet == "Bank" and "the Bank sheet is showing")
				or (ns.ui.owner and "browsing another character") or (size == 0 and "the game hasn't reported the bag's size yet") or "unknown"
		end
		if why ~= v.lastWhy then
			if why then ns:Debug("Bag window %s not shown: %s", ns:BagName(bag), why) end
			v.lastWhy = why
		end
		if want then
			v.opts.title = ns.bagInfo[bag] and ns.bagInfo[bag].name or ns:BagName(bag)
			if not v:IsShown() and not db.bagPoints[tostring(bag)] then anyNew = true end
			v:Show()
		else v:Hide() end
	end
	-- Bank bag windows: only at a banker, with the bank window open, and only
	-- while the bank window's footer icon has them turned on.
	local bankOpen = W.bank and W.bank:IsShown() and ns.atBank and not ns.ui.owner
	local anyNewBank = false
	for bag, v in pairs(W.bankBagViews or {}) do
		local want = bankOpen and ns.ui.bankBagWindows and not (ns.ui.closedBankBags and ns.ui.closedBankBags[bag])
			and (ns.bagInfo[bag] and ns.bagInfo[bag].size or 0) > 0
		if want then
			v.opts.title = "Bank: " .. (ns.bagInfo[bag] and ns.bagInfo[bag].name or ns:BagName(bag))
			if not v:IsShown() and not db.bagPoints[tostring(bag)] then anyNewBank = true end
			v:Show()
		else v:Hide() end
	end
	if anyNewBank then
		-- First time: a row to the right of the bank window, wrapping under it.
		local bank = W.bank.frame
		local x0 = (bank:GetRight() or 700) + 8
		local x, top = x0, bank:GetTop() or 700
		local rowH = 0
		local screenW = UIParent:GetWidth()
		for _, bag in ipairs(ns.BANK_BAGS) do
			local v = W.bankBagViews[bag]
			if v and v:IsShown() and not db.bagPoints[tostring(bag)] then
				local w, h = v.frame:GetWidth(), v.frame:GetHeight()
				if x + w > screenW then x = x0; top = top - rowH - 8; rowH = 0 end
				v.frame:ClearAllPoints()
				v.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top)
				v.positioned = true
				x = x + w + 8; rowH = math.max(rowH, h)
			end
		end
	end
	-- First-time placement: a row of windows to the left of the main window,
	-- each anchored to the screen so they can be moved independently.
	if anyNew then
		local main = W.main.frame
		local right = (main:GetLeft() or 400) - 8
		local bottom = main:GetBottom() or 200
		for i = #ns.BAGS, 1, -1 do
			local bag = ns.BAGS[i]
			local v = W.bagViews[bag]
			if v and v:IsShown() and not db.bagPoints[tostring(bag)] then
				local w = v.frame:GetWidth()
				v.frame:ClearAllPoints()
				v.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", right - w, bottom)
				v.positioned = true
				right = right - w - 8
			end
		end
	end
end

-- Is any window in the set still open (ignoring the ones closed by hand)?
-- Close one bag's own window: from its X or from the bag strip. Once every
-- window in a set is closed the set is off, so the footer opens it in one click.
function ns:CloseBagWindow(bag, bank)
	if bank then
		ns.ui.closedBankBags = ns.ui.closedBankBags or {}
		ns.ui.closedBankBags[bag] = true
		if not ns:AnyBagWindowOpen(true) then ns.ui.bankBagWindows = false; ns.ui.closedBankBags = {} end
	elseif ns:IsReagentBag(bag) then
		ns.ui.reagentWindow = false
	else
		ns.ui.closedBags = ns.ui.closedBags or {}
		ns.ui.closedBags[bag] = true
		if not ns:AnyBagWindowOpen(false) then ns.ui.bagWindows = false; ns.ui.closedBags = {} end
	end
end

function ns:AnyBagWindowOpen(bank)
	local list, closed = bank and ns.BANK_BAGS or ns.BAGS, bank and ns.ui.closedBankBags or ns.ui.closedBags
	for _, bag in ipairs(list) do
		if (ns.bagInfo[bag] and ns.bagInfo[bag].size or 0) > 0 and not (closed and closed[bag])
			and bag ~= ns.KEYRING and not (not bank and ns:IsReagentBag(bag)) then
			return true
		end
	end
	return false
end

function ns:RepositionPanels()
	if ns.Drawer and ns.Drawer.frame and ns.Drawer.frame:IsShown() then ns.Drawer:Position() end
end

-- While a mouse button is held over a BagSmith window, rebuilding could move
-- the row being clicked; wait until the button is released.
local function mouseHeldOverWindow()
	if not (IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))) then return false end
	for _, v in pairs(ns.views) do if v:IsShown() and v.frame:IsMouseOver() then return true end end
	return false
end
local waiter, waiting   -- one frame, reused
local function waitTick(self)
	if mouseHeldOverWindow() then return end
	self:SetScript("OnUpdate", nil); waiting = false
	local f, r = ns.pendingForce, ns.pendingReason; ns.pendingForce, ns.pendingReason = nil, nil
	-- If every update that waited was an item change, keep rows holding still.
	ns:RefreshViews(f, r == "items" and "items" or nil)
end
local function waitForRelease(force, reason)
	ns.pendingForce = ns.pendingForce or force
	if ns.pendingReason == nil then ns.pendingReason = reason or "full"
	elseif reason ~= "items" then ns.pendingReason = "full" end
	if waiting then return end
	waiter = waiter or CreateFrame("Frame")
	waiting = true
	waiter:SetScript("OnUpdate", waitTick)
end

function ns:RefreshViews(force, reason)
	local W = Window
	if not W.main then return end
	if mouseHeldOverWindow() then waitForRelease(force, reason); return end
	-- Shielded: a failure in one window is recorded (/bs errors) and the other
	-- windows still draw.
	ns:Guard("Window layout", ns.ApplyLayout, ns)
	for _, v in pairs(ns.views) do if v:IsShown() then ns:Guard("Refresh " .. (v.name or "window"), v.Refresh, v, force, reason) end end
	if ns.Drawer and ns.Drawer.frame and ns.Drawer.frame:IsShown() then ns.Drawer:Refresh() end
end

-- Travel Mode (see View:ApplyTravel). Auto Travel Mode holds it off while
-- the bank, the auction house or a vendor is open (each its own setting) and
-- lets go when that window closes.
ns.ui.travelHold = ns.ui.travelHold or {}
function ns:TravelHeld() return next(ns.ui.travelHold) ~= nil end
function ns:ApplyTravel()
	local m = ns.Window and ns.Window.main
	if m then m:ApplyTravel() end
end
-- The signpost: on or off. While Auto Travel Mode has it held off (at a
-- vendor, say), clicking it turns it on right away.
function ns:ToggleTravel()
	if ns.db.travelMode and ns:TravelHeld() then
		wipe(ns.ui.travelHold)
	else
		ns:Set("travelMode", not ns.db.travelMode, true)
	end
	ns:ApplyTravel()
	ns:RefreshViews(true)
end
local TRAVEL_HOLDS = {
	{ "bank", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "travelLeaveBank" },
	{ "ah", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "travelLeaveAH" },
	{ "vendor", "MERCHANT_SHOW", "MERCHANT_CLOSED", "travelLeaveVendor" },
	{ "taxi", nil, nil, "travelLeaveTaxi" },   -- flight paths: see checkTaxi below
	{ "trade", "TRADE_SHOW", "TRADE_CLOSED", "travelLeaveTrade" },
}
local TRAVEL_WHERE = { bank = "at the bank", ah = "at the auction house", vendor = "at the vendor", taxi = "on a flight path", trade = "trading" }
-- The signpost's tooltip: what Travel Mode is, or why Auto Travel Mode has it off.
function ns:TravelTip()
	for _, h in ipairs(TRAVEL_HOLDS) do
		if ns.ui.travelHold[h[1]] and ns.db.travelMode then return ("Off while you're %s. Click to turn it back on now."):format(TRAVEL_WHERE[h[1]]) end
	end
	return "A compact view for adventuring. Click again anytime for your full inventory tools."
end

-- Flight paths: the game says whether you're on one; takeoff and landing
-- fire control events. Checked on those events, at login (a /reload
-- mid-flight), and every few seconds while flying in case a landing event
-- is missed.
local TAXI_RECHECK = 3
local function onTaxi() return UnitOnTaxi and UnitOnTaxi("player") and true or false end
local checkTaxi
local function taxiPoll()
	if ns.ui.travelHold.taxi then checkTaxi(); if ns.ui.travelHold.taxi then C_Timer.After(TAXI_RECHECK, taxiPoll) end end
end
checkTaxi = function()
	if not ns.db then return end
	local flying = onTaxi()
	if flying and ns.db.travelMode and ns.db.travelLeaveTaxi and not ns.ui.travelHold.taxi then
		ns.ui.travelHold.taxi = true
		ns:Debug("Travel Mode: flight path started, Travel Mode off until you land")
		ns:ApplyTravel(); ns:RefreshViews(true)
		C_Timer.After(TAXI_RECHECK, taxiPoll)
	elseif not flying and ns.ui.travelHold.taxi then
		ns.ui.travelHold.taxi = nil
		ns:Debug("Travel Mode: landed, Travel Mode back on")
		ns:ApplyTravel(); ns:RefreshViews(true)
	end
end
ns.CheckTaxi = checkTaxi
for _, event in ipairs({ "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "TAXIMAP_CLOSED", "PLAYER_ENTERING_WORLD" }) do
	ns:On(event, function()
		checkTaxi()
		C_Timer.After(0.5, checkTaxi)   -- the game can report the flight a moment after the event
	end)
end

for _, h in ipairs(TRAVEL_HOLDS) do if h[2] then
	ns:On(h[2], function()
		if ns.db and ns.db.travelMode and ns.db[h[4]] and not ns.ui.travelHold[h[1]] then
			ns.ui.travelHold[h[1]] = true; ns:ApplyTravel(); ns:RefreshViews(true)
		end
	end)
	ns:On(h[3], function()
		if ns.ui.travelHold[h[1]] then ns.ui.travelHold[h[1]] = nil; ns:ApplyTravel(); ns:RefreshViews(true) end
	end)
end end
ns:OnSignal("SETTINGS_CHANGED", function(key)
	-- Turning an Auto Travel Mode setting off while it's holding lets go.
	for _, h in ipairs(TRAVEL_HOLDS) do
		if (key == nil or key == h[4]) and not ns.db[h[4]] and ns.ui.travelHold[h[1]] then ns.ui.travelHold[h[1]] = nil end
	end
	if key == "travelLeaveTaxi" or key == "travelMode" then checkTaxi() end   -- turned on mid-flight: off now
	if key == nil or key == "travelMode" or key == "travelLeaveBank" or key == "travelLeaveAH" or key == "travelLeaveVendor" or key == "travelLeaveTaxi" or key == "travelLeaveTrade" or key == "skin" then ns:ApplyTravel() end
end)

-- After a profile change (switch, reset, copy, delete): a window whose
-- selected sheet doesn't exist in the profile goes back to All, with that
-- sheet's filters and search cleared (else everything is filtered out).
function ns:ReconcileSheets()
	for _, pair in ipairs({ { ns.ui, false, "main" }, { ns.uiBank, true, "bank" } }) do
		local st, bank = pair[1], pair[2]
		local name = st.sheet
		if name and name ~= "All" and not ns.TAB_LABEL[name] then
			local found
			for _, s in ipairs((bank and ns.db.bankSheets or ns.db.sheets) or {}) do if s.n == name then found = s end end
			local v = ns.Window and ns.Window[pair[3]]
			if not found then
				st.sheet, st.filters, st.search = "All", ns.EmptyFilters(), ""
				if v and v.search then v.search:SetText("") end
			else
				-- Same name in this profile: its own filters and search, not the old profile's.
				st.filters = ns.CleanFilters(found.f)
				st.search = st.filters.text or ""
				if v and v.search then v.search:SetText(st.filters.text or "") end
			end
		end
	end
end

function ns:OnMainHidden()
	local W = Window
	ns.ui.owner = nil
	ns.ui.bagWindows, ns.ui.reagentWindow = nil, nil
	ns.ui.closedBags = {}
	if ns.ui.sheet == "Bank" and not ns.atBank then ns.ui.sheet = "All" end
	for _, v in pairs(W.bagViews) do v:Hide() end
	if ns.Drawer then ns.Drawer:Hide() end
	if ns.Popups then ns.Popups:HideAll() end
end

------------------------------------------------------------------------
-- Lanes, tabs, sheets
------------------------------------------------------------------------
local function reorder(list, from, to)
	local fi, ti = ns.IndexOf(list, from), ns.IndexOf(list, to)
	if not fi or not ti or fi == ti then return false end
	table.remove(list, fi)
	table.insert(list, ns.IndexOf(list, to) + (fi < ti and 1 or 0), from)
	return true
end
function ns:ReorderLane(from, to)
	-- Every gear set shares Gear Sets' one place in Section Order.
	if ns.GearSets then from, to = ns.GearSets.OrderId(from), ns.GearSets.OrderId(to) end
	if from == to then return end
	if reorder(ns.db.laneOrder, from, to) then Window.main.animate = true; ns:RefreshViews(true) end
end
function ns:ReorderTab(from, to, view)
	local order = (view and view.isBank) and ns.db.bankTabOrder or ns.db.tabOrder
	if reorder(order, from, to) then ns:RefreshViews(true) end
end
-- Sheets belong to a window: the main window's live in db.sheets, the bank's in db.bankSheets.
function ns:SaveSheet(name, view)
	view = view or Window.main
	local list, order = view.isBank and ns.db.bankSheets or ns.db.sheets, view.isBank and ns.db.bankTabOrder or ns.db.tabOrder
	name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then return false, "Enter a sheet name first." end
	if ns.TAB_LABEL[name] then return false, "That name is taken." end
	for _, s in ipairs(list) do if s.n == name then return false, "That name is taken." end end
	table.insert(list, { n = name, f = ns.CleanFilters(view.st.filters) })
	table.insert(order, name)
	view.st.sheet = name
	ns:RefreshViews(true)
	return true
end
-- Rename and/or replace a sheet's filters with the window's current ones.
function ns:UpdateSheet(oldName, newName, view)
	view = view or Window.main
	local list, order = view.isBank and ns.db.bankSheets or ns.db.sheets, view.isBank and ns.db.bankTabOrder or ns.db.tabOrder
	newName = tostring(newName or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if newName == "" then return false, "Enter a sheet name first." end
	if newName ~= oldName then
		if ns.TAB_LABEL[newName] then return false, "That name is taken." end
		for _, s in ipairs(list) do if s.n == newName then return false, "That name is taken." end end
	end
	for _, s in ipairs(list) do
		if s.n == oldName then
			s.n, s.f = newName, ns.CleanFilters(view.st.filters)
			local oi = ns.IndexOf(order, oldName); if oi then order[oi] = newName end
			local hidden = view.isBank and ns.db.bankHiddenTabs or ns.db.hiddenTabs
			local hi = ns.IndexOf(hidden, oldName); if hi then hidden[hi] = newName end
			-- Its remembered view (Sheets Remember Their View) moves with it.
			local prefs = ns.db.sheetPrefs and ns.db.sheetPrefs[view.isBank and "bank" or "bags"]
			if prefs and oldName ~= newName then prefs[newName], prefs[oldName] = prefs[oldName], nil end
			if view.st.sheet == oldName then view.st.sheet = newName end
			ns:RefreshViews(true)
			return true
		end
	end
	return false, "No sheet named " .. oldName .. "."
end

function ns:DeleteSheet(name, view)
	view = view or Window.main
	local list, order = view.isBank and ns.db.bankSheets or ns.db.sheets, view.isBank and ns.db.bankTabOrder or ns.db.tabOrder
	for i, s in ipairs(list) do if s.n == name then table.remove(list, i) end end
	local ti = ns.IndexOf(order, name); if ti then table.remove(order, ti) end
	local hidden = view.isBank and ns.db.bankHiddenTabs or ns.db.hiddenTabs
	local hi = ns.IndexOf(hidden, name); if hi then table.remove(hidden, hi) end
	-- Forget its remembered view, so a new sheet with the same name starts fresh.
	local prefs = ns.db.sheetPrefs and ns.db.sheetPrefs[view.isBank and "bank" or "bags"]
	if prefs then prefs[name] = nil end
	if view.st.sheet == name then view.st.sheet = "All"; view.st.filters = ns.EmptyFilters(); if view.search then view.search:SetText("") end end
	ns:RefreshViews(true)
end

------------------------------------------------------------------------
-- Combat fade: alpha is not a protected property, so every window can dim
-- the moment combat starts and come back when it ends.
------------------------------------------------------------------------
local function combatFrames()
	local out = {}
	for _, v in pairs(ns.views) do out[#out + 1] = v.frame end
	if ns.Drawer and ns.Drawer.frame then out[#out + 1] = ns.Drawer.frame end
	if ns.Popups then
		if ns.Popups.filter then out[#out + 1] = ns.Popups.filter end
		if ns.Popups.chars then out[#out + 1] = ns.Popups.chars end
	end
	for _, f in ipairs(ns.combatWindows or {}) do out[#out + 1] = f end   -- (1.5.6) every other BagSmith window
	return out
end
-- An invisible shield over each window swallows clicks, drags and wheel
-- input during combat. It is BagSmith's own frame, so showing and hiding
-- it in combat is allowed, unlike touching the secure buttons beneath.
local function shieldFor(f)
	if not f.bsShield then
		local s = CreateFrame("Frame", nil, f)
		s:SetAllPoints(f)
		s:SetFrameLevel((f:GetFrameLevel() or 1) + 500)
		s:EnableMouse(true)
		s:EnableMouseWheel(true)
		s:SetScript("OnMouseWheel", function() end)
		s:Hide()
		f.bsShield = s
	end
	return f.bsShield
end

-- (1.6.0) Opacity, for the bag windows (views) and every other BagSmith window:
--   always       Background Opacity fades the bag windows' frame and background (ApplyBgOpacity); with Whole Window on,
--                it's their whole window instead (items, text and buttons too).
--   while moving Fade While Moving dims the bag windows (only) to Opacity While Moving while the character moves.
--   in combat    the combat fade dims every BagSmith window, helpers included (and can ignore clicks).
-- A fade never makes a window brighter than its normal opacity. (beta3: pointing at a window no longer brings it back
-- while moving: Shweep found it unhelpful; it comes back when the character stops.)
function ns:ApplyCombatFade(inCombat)
	local db = ns.db
	local fade = inCombat and db.combatFade
	local lock = fade and db.combatLock
	local moving = not inCombat and ns.moving and db.fadeMoving and true or false
	local whole = db.bgWhole and (tonumber(db.bgOpacity) or 1) or 1
	for _, f in ipairs(combatFrames()) do
		if not f.bsSoftClosed then   -- (1.5.6) a window closed as far as the player can tell stays that way
			local base = f.view and whole or 1
			local a = base
			if fade then a = math.min(base, db.combatAlpha or 1)
			elseif moving and f.view then a = math.min(base, db.movingAlpha or 0.5) end
			f:SetAlpha(a)
			shieldFor(f):SetShown(lock and true or false)
		end
	end
	ns.combatFaded = fade or false
end
-- (1.6.0) Background Opacity: the bag windows' frame and background only (with Whole Window on, they stay full and the
-- whole window fades instead, in ApplyCombatFade). Modern: the backdrop's own colours. Classic: the game frame's background
-- pieces and BagSmith's own layers over them (the stone tile, the shade, the corner filigree: beta3, Shweep found Classic
-- unchanged because only the pieces underneath were faded); the portrait, title and buttons are untouched.
-- Each layer keeps its own designed opacity (Classic's corner filigree is drawn at 40%): Background Opacity scales from it,
-- so at 100% the window looks exactly as before.
local function scaleAlpha(r, a)
	if not (r and r.SetAlpha) then return end
	if r.bsBaseAlpha == nil then r.bsBaseAlpha = (r.GetAlpha and r:GetAlpha()) or 1 end
	r:SetAlpha(r.bsBaseAlpha * a)
end
function ns:ApplyBgOpacity()
	local db = ns.db or {}
	local a = db.bgWhole and 1 or ((tonumber(db.bgOpacity)) or 1)
	local classic = ns.Classic and ns.Classic.IsOn and ns.Classic.IsOn()
	for _, v in pairs(ns.views or {}) do
		local f = v.frame
		if classic then
			local ch = v.classicChrome
			if ch then for _, k in ipairs({ "Bg", "TopTileStreaks", "NineSlice" }) do scaleAlpha(ch[k], a) end end
			for _, k in ipairs({ "classicStone", "classicTile", "classicShade" }) do scaleAlpha(v[k], a) end
			for _, r in ipairs(v.classicCorners or {}) do scaleAlpha(r, a) end
		elseif f and f.SetBackdropColor and ns.Skins and ns.Skins.Current then
			local s = ns.Skins:Current()
			f:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], (s.bg[4] or 1) * a)
			f:SetBackdropBorderColor(s.border[1], s.border[2], s.border[3], (s.border[4] or 1) * a)
		end
	end
end
-- the movement events (checked natively: PLAYER_STARTED_MOVING exists on this client); registered defensively
pcall(ns.On, ns, "PLAYER_STARTED_MOVING", function() ns.moving = true; ns:ApplyCombatFade(InCombatLockdown()) end)
pcall(ns.On, ns, "PLAYER_STOPPED_MOVING", function() ns.moving = false; ns:ApplyCombatFade(InCombatLockdown()) end)
-- (1.5.6) Every BagSmith window fades in combat like the bags window (Shweep). Windows outside the bag windows register
-- here when they're built: their click shield is made then (before any combat: a protected window's parts are best made
-- outside it), and a window opened during combat fades at once.
ns.combatWindows = ns.combatWindows or {}
function ns:CombatWindow(f)
	if not f or f.bsCombatWindow then return end
	f.bsCombatWindow = true
	ns.combatWindows[#ns.combatWindows + 1] = f
	shieldFor(f)
	f:HookScript("OnShow", function() if InCombatLockdown() and not f.bsSoftClosed then ns:ApplyCombatFade(true) end end)
end
ns:OnSignal("COMBAT_STARTED", function()
	ns:ApplyCombatFade(true)
	if ns.db.combatFade and GameTooltip:IsShown() then
		local owner = GameTooltip:GetOwner()
		local f = owner
		while f do
			if f.view or f == ns.Drawer.frame or f == ns.Popups.filter then GameTooltip:Hide(); break end
			f = f.GetParent and f:GetParent()
		end
	end
end)
ns:OnSignal("COMBAT_ENDED", function() ns:ApplyCombatFade(false) end)
ns:OnSignal("SETTINGS_CHANGED", function(key)
	if key == nil or key == "combatFade" or key == "combatAlpha" or key == "combatLock" or key == "fadeMoving" or key == "movingAlpha"
		or key == "bgOpacity" or key == "bgWhole" then ns:ApplyCombatFade(InCombatLockdown()) end
	-- (1.6.0) Background Opacity, now and after a skin change re-dresses the windows
	if key == nil or key == "bgOpacity" or key == "bgWhole" then ns:ApplyBgOpacity() end
	if key == "skin" and ns.NextFrame then ns:NextFrame("bgOpacity:skin", function() ns:ApplyBgOpacity() end) end
end)

------------------------------------------------------------------------
-- Public toggles used by hooks, slash and minimap
------------------------------------------------------------------------
function Window:Show() self.main:Show() end
function Window:Hide() self.main:Hide() end
function Window:Toggle() self.main:Toggle() end
function Window:IsShown() return self.main and self.main:IsShown() end

------------------------------------------------------------------------
-- Wiring
------------------------------------------------------------------------
ns:OnSignal("ADDON_READY", function() Window:Create() end)

local initialized = false
ns:On("PLAYER_ENTERING_WORLD", function(isInitialLogin)
	if initialized then return end
	initialized = true
	ns.loginTime = time()
	Window:Create()
	ns.Buttons:Create(Window.main.child)
	ns:Scan()
	-- The Recent section's session starts here, after the first scan (a
	-- /reload keeps the session that's already running).
	ns:StartRecentSession(isInitialLogin)
	Window.main.frame:Show()
	C_Timer.After(0, function()
		Window.main.frame:Hide()
		ns.ready = true
		if not ns.db.quiet then
			ns:Print("v%s loaded. %d items in %d bags, %d buttons ready. Press B or type /bs.",
				ns.version, #ns.items, #ns.BAGS, #ns.Buttons.all)
			ns:Print("Say |cfffac775/bs quiet|r to stop showing this line.")
		end
	end)
end)

ns:OnSignal("ITEMS_CHANGED", function() ns:RefreshViews(nil, "items") end)
-- Money and currency changes only touch footers; no relayout.
local function refreshFooters()
	for _, v in pairs(ns.views) do if v:IsShown() and v.big then v:UpdateFooter() end end
	if ns.Drawer and ns.Drawer.frame and ns.Drawer.frame:IsShown() then ns.Drawer:Refresh() end
end
ns:OnSignal("CURRENCY_CHANGED", refreshFooters)
ns:OnSignal("MONEY_CHANGED", refreshFooters)
ns:OnSignal("SETTINGS_CHANGED", function(key)
	if not Window.main then return end
	if key == nil or key == "scale" or key == "sizeMode" or key == "fixW" or key == "fixH" or key == "maxW" or key == "maxH" or key == "point"
		or key == "bagCols" or key == "bagScale" or key == "bagMaxH" or key == "iconSize" then
		-- A profile change: small windows go to that profile's saved spots.
		if key == nil then
			-- Windows with a saved spot in this profile go there; others stay where they are.
			for _, v in pairs(ns.views) do
				if v.kind == "bag" and v.opts and v.opts.bags and ns.db.bagPoints[tostring(v.opts.bags[1])] then v.positioned = false end
			end
		end
		for _, v in pairs(ns.views) do v:ApplySize() end
		-- Once the client has applied the new scale or size: each window's
		-- canvas laid out again (see View:RefreshCanvas), next frame and a
		-- moment later with one more rebuild.
		if key ~= "point" then
			local why = key or "profile"
			ns:NextFrame("canvas", function()
				for _, v in pairs(ns.views) do if v.frame:IsShown() then v:RefreshCanvas(why) end end
			end)
			C_Timer.After(0.2, function()
				for _, v in pairs(ns.views) do
					if v.frame:IsShown() then v:RefreshCanvas(why); ns:Guard("Refresh " .. (v.name or "window"), v.Refresh, v, true, "canvas") end
				end
			end)
		end
	end
	ns:RefreshViews(true)
end)
-- (1.6.0-beta7, the beta6 audit's R3) which columns are shown or may be set aside, or whether AH Price can show: the
-- bags and bank windows' narrowest width follows (View.MinWidthFor)
local MINW_KEYS = { cols = true, colAside = true, bankCols = true, bankColAside = true }
local function minWidths() for _, v in pairs(ns.views) do if v.big then v:ApplyMinWidth() end end end
ns:OnSignal("SETTINGS_CHANGED", function(key) if MINW_KEYS[key] then minWidths() end end)
ns:OnSignal("PRICE_SOURCE_CHANGED", minWidths)
-- At a banker the dedicated bank window opens beside the main window.
ns:OnSignal("BANK_OPENED", function()
	if ns.Bank and ns.Bank:Replacing() then Window.bank:Show() end
	Window.main:Show()
end)
ns:OnSignal("BANK_CLOSED", function()
	Window.bank:Hide()
	ns.ui.bankBagWindows = false
	ns.ui.closedBankBags = {}
	ns:ApplyLayout()
end)
-- Flipping "Replace the bank window" while at a banker swaps windows live.
ns:OnSignal("SETTINGS_CHANGED", function(key)
	if (key == nil or key == "replaceBank") and ns.atBank then
		if ns.Bank:Replacing() then Window.bank:Show() else Window.bank.frame:Hide() end
	end
end)
