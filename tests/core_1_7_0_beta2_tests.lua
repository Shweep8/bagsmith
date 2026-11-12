;(function()
	-- ======== 1.7.0-beta2 ========
	-- ---- A Clean Up scans and redraws a few times a second, not every frame (a player's report: heavy lag on opening
	-- the bags with Clean Up Bags When Opened on; his addon CPU meter read 4-5% with it on, 1-2% off). Blizzard's Clean Up
	-- moves items one at a time for some seconds; each move used to scan and redraw every window in the next frame. This
	-- set runs its own clock: GetTime and C_Timer.After by due time, one frame at a time.
	local function boot(view, skin)
		package.loaded.mock = nil
		local M = require("mock")
		for b = 0, 3 do M.sizes[b] = 12 end
		for b = 0, 3 do for s = 1, 10 do
			M.put(b, s, { id = 4000 + (b * 12 + s) % 9, name = "Good " .. ((b * 12 + s) % 9), q = 1, count = 1 + s % 4, stack = 20, class = 7, subclass = 5, price = 3 })
		end end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, view = view } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); M.runTimers(); M.runTimers()
		n.Window.main.frame.IsMouseOver = function() return false end
		-- the clock
		local clock, seq, queue = 5000, 0, {}
		_G.GetTime = function() return clock end
		C_Timer.After = function(d, fn) seq = seq + 1; queue[#queue + 1] = { due = clock + math.max(0, tonumber(d) or 0), seq = seq, fn = fn } end
		local function advance(dt)
			local target = clock + dt
			while true do
				local best, bi
				for i, t in ipairs(queue) do if t.due <= target and (not best or t.due < best.due or (t.due == best.due and t.seq < best.seq)) then best, bi = t, i end end
				if not best then break end
				table.remove(queue, bi)
				if best.due > clock then clock = best.due end
				best.fn()
			end
			clock = target
		end
		return n, M, advance
	end
	local FRAME = 1 / 60
	local function shuffle(M, i)
		local b1, s1 = i % 4, (i % 10) + 1
		local b2, s2 = (i * 3 + 1) % 4, ((i * 7) % 12) + 1
		M.bags[b1][s1], M.bags[b2][s2] = M.bags[b2][s2], M.bags[b1][s1]
	end
	local function matches(n, M)
		local want, got = {}, {}
		for b = 0, 3 do for s = 1, 12 do local it = M.bags[b][s]; if it then want[#want + 1] = b .. ":" .. s .. ":" .. it.id end end end
		for _, r in ipairs(n.items) do if r.itemID then got[#got + 1] = r.bag .. ":" .. r.slot .. ":" .. r.itemID end end
		table.sort(want); table.sort(got)
		return table.concat(want, ",") == table.concat(got, ",")
	end
	for _, view in ipairs({ "list", "icons" }) do
		for _, skin in ipairs({ "modern", "classic" }) do
			local who = skin .. ", " .. view
			local n, M, advance = boot(view, skin)
			local V = n.Window.main
			local scans, redraws = 0, 0
			local scan = n.Scan
			n.Scan = function(...) scans = scans + 1; return scan(...) end
			local refresh = V.Refresh
			V.Refresh = function(...) redraws = redraws + 1; return refresh(...) end
			-- (control) without a Clean Up, a change each frame is scanned and drawn each frame, as before
			for i = 1, 30 do shuffle(M, i); M.fire("BAG_UPDATE_DELAYED"); advance(FRAME) end
			check(scans == 30 and redraws >= 30, who .. ": (control) without a Clean Up, every frame's change is scanned and drawn (" .. scans .. ", " .. redraws .. ")")
			-- a Clean Up: two seconds of moves, one a frame
			scans, redraws = 0, 0
			V:CleanUp()
			check(n.cleanupUntil ~= nil, who .. ": (setup) a Clean Up is running")
			for i = 31, 150 do shuffle(M, i); M.fire("BAG_UPDATE_DELAYED"); advance(FRAME) end
			check(scans >= 6 and scans <= 10, who .. ": two seconds of Clean Up moves are scanned about 4 times a second, not 120 times (" .. scans .. ")")
			check(redraws <= scans + 2, who .. ": and drawn no more often (" .. redraws .. ")")
			advance(0.3)
			check(matches(n, M), who .. ": the last move is in the scan a moment after the moves stop")
			-- when it ends: one more layout, and changes are scanned each frame again
			local before = redraws
			advance(n.CLEANUP_SECONDS)
			check(n.cleanupUntil == nil and redraws > before, who .. ": when the Clean Up's time is up, the windows lay out once more")
			scans = 0
			for i = 151, 160 do shuffle(M, i); M.fire("BAG_UPDATE_DELAYED"); advance(FRAME) end
			check(scans == 10 and matches(n, M), who .. ": after it, every frame's change is scanned again (" .. scans .. ")")
			-- the Loot Helper's Clean Up Bags goes the same way
			scans = 0
			n.MakeRoom:CleanUp()
			for i = 161, 220 do shuffle(M, i); M.fire("BAG_UPDATE_DELAYED"); advance(FRAME) end
			check(scans >= 3 and scans <= 6, who .. ": the Loot Helper's Clean Up Bags is held the same way (" .. scans .. ")")
			local changed = 0
			n:OnSignal("ITEMS_CHANGED", function() changed = changed + 1 end)
			shuffle(M, 221); M.fire("BAG_UPDATE_DELAYED"); advance(0.3)
			check(changed >= 1 and matches(n, M), who .. ": its scans still tell the Loot Helper the bags changed")
			advance(n.CLEANUP_SECONDS + 1)
		end
	end

	-- ---- Lock Windows (Shweep): off by default; on, the bags, bank and bag windows and both helpers can't be moved or
	-- resized (their drag and resize handlers check it, the grips hide)
	local function plainBoot(skin, prof)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
		M.put(0, 2, { id = 118, name = "Minor Healing Potion", q = 1, count = 3, class = 0, subclass = 1, price = 5 })
		M.put(1, 1, { id = 2318, name = "Light Leather", q = 1, count = 2, class = 7, subclass = 6, price = 2 })
		M.put(1, 2, { id = 2592, name = "Wool Cloth", q = 1, count = 4, class = 7, subclass = 5, price = 3 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local pr = { skin = skin }
		for k, v in pairs(prof or {}) do pr[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = pr } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); M.runTimers(); M.runTimers()
		return n, M
	end
	local function counting(f)
		local c = { move = 0, size = 0 }
		f.StartMoving = function() c.move = c.move + 1 end
		f.StartSizing = function() c.size = c.size + 1 end
		return c
	end
	for _, skin in ipairs({ "modern", "classic" }) do
		local n, M = plainBoot(skin)
		local V = n.Window.main
		local S = skin .. ": "
		check(n.db.lockWindows == false, S .. "Lock Windows is off by default")
		local c = counting(V.frame)
		local saves = 0
		local save = V.SavePosition
		V.SavePosition = function(...) saves = saves + 1; return save(...) end
		V.dragArea:GetScript("OnDragStart")(V.dragArea); V.dragArea:GetScript("OnDragStop")(V.dragArea)
		check(c.move == 1 and saves == 1 and V.grip:IsShown(), S .. "(control) unlocked: the title band moves the window and saves the spot; the grip shows")
		n:Set("lockWindows", true); M.runTimers()
		check(not V.grip:IsShown(), S .. "locked: the bags window's resize grip hides")
		V.dragArea:GetScript("OnDragStart")(V.dragArea); V.dragArea:GetScript("OnDragStop")(V.dragArea)
		check(c.move == 1 and saves == 1, S .. "locked: dragging the title band doesn't move it, nor save a spot (" .. c.move .. ", " .. saves .. ")")
		local fixW = n.db.fixW
		V.grip:GetScript("OnMouseDown")(V.grip); V.grip:GetScript("OnMouseUp")(V.grip)
		check(c.size == 0 and n.db.fixW == fixW and not V.sizing, S .. "locked: the grip (if reached) doesn't resize it")
		n:RefreshViews(true); M.runTimers()
		check(not V.grip:IsShown(), S .. "and it stays hidden through a redraw")
		-- a bag's own window
		n:Set("__openWindows", "all"); n.Window:Hide(); n:OnMainHidden(); ToggleAllBags(); M.runTimers(); M.runTimers()
		local bw = rawget(n.Window.bagViews, 0)
		if bw then
			local cb = counting(bw.frame)
			bw.dragArea:GetScript("OnDragStart")(bw.dragArea); bw.dragArea:GetScript("OnDragStop")(bw.dragArea)
			check(cb.move == 0, S .. "locked: a bag's own window doesn't move")
		else
			check(false, S .. "(setup) the backpack's window opened")
		end
		-- the Loot Helper
		local MR = n.MakeRoom
		local lf = MR:Frame()
		local cl = counting(lf)
		local pos = n.db.makeRoomPos
		lf:GetScript("OnDragStart")(lf); lf:GetScript("OnDragStop")(lf)
		check(cl.move == 0 and n.db.makeRoomPos == pos, S .. "locked: the Loot Helper doesn't move, its spot unchanged")
		-- the Disenchant Helper
		local DE = n.Disenchant
		local df = DE:Frame()
		local cd = counting(df)
		check(not df.grip:IsShown(), S .. "locked: the Disenchant Helper is made without its grip")
		df:GetScript("OnDragStart")(df); df.bsCatcher:GetScript("OnDragStart")(df.bsCatcher)
		df.grip:GetScript("OnMouseDown")(df.grip)
		check(cd.move == 0 and cd.size == 0 and not df.bsMoving and not df.bsSizing, S .. "locked: the Disenchant Helper doesn't move or resize")
		-- unlocked again; the Disenchant Helper's grip waits for combat to end (a protected window)
		M.inCombat = true; _G.InCombatLockdown = function() return true end
		n:Set("lockWindows", false); M.runTimers()
		check(not df.grip:IsShown(), S .. "unlocked in combat: the Disenchant Helper's grip waits for combat to end")
		_G.InCombatLockdown = function() return false end; M.inCombat = false
		M.fire("PLAYER_REGEN_ENABLED"); M.runTimers()
		check(df.grip:IsShown(), S .. "and shows when it ends")
		n.Window:Show(); n:RefreshViews(true); M.runTimers()
		check(V.grip:IsShown(), S .. "unlocked: the bags window's grip is back")
		lf:GetScript("OnDragStart")(lf); lf:GetScript("OnDragStop")(lf)
		check(cl.move == 1 and type(n.db.makeRoomPos) == "table", S .. "unlocked: the Loot Helper moves and remembers where")
		df:GetScript("OnDragStart")(df)
		check(cd.move == 1, S .. "unlocked: the Disenchant Helper moves")
		-- the setting
		local P = n.SettingsPanel; P:Show(); P:ShowPage("window"); M.runTimers()
		local found
		for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.key == "lockWindows" then found = w end end
		check(found and found.text.text == "Lock Windows" and (found.help.text or ""):find("can't be moved or resized", 1, true), S .. "Settings > Window: Lock Windows, with its help")
		P:Hide()
	end

	-- ---- Highlight Pinned Sections (Shweep): off by default; an accent background at 15% behind each pinned section,
	-- title and items, under everything; its opacity adjustable
	local function shownBacks(V)
		local out = {}
		for _, t in ipairs((V.pinBacks or {})[V.child] or {}) do if t:IsShown() then out[#out + 1] = t end end
		return out
	end
	for _, view in ipairs({ "icons", "list" }) do
		for _, skin in ipairs({ "modern", "classic" }) do
			local S = skin .. ", " .. view .. ": "
			local n, M = plainBoot(skin, { view = view, grp = "type" })
			local V = n.Window.main
			local function lane(id) for _, h in pairs(n.Buttons.lanes[V.child] or {}) do if h:IsShown() and h.laneId == id then return h end end end
			check(n.db.pinnedHighlight == false and n.db.pinnedHighlightAlpha == 0.15, S .. "off by default, 15% when on")
			n.Sections:SetPinned("Consumables", true); n:RefreshViews(true); M.runTimers()
			check(#shownBacks(V) == 0, S .. "off: no highlight behind the pinned section")
			n:Set("pinnedHighlight", true); M.runTimers()
			local b = shownBacks(V)
			local h = lane("Consumables")
			check(#b == 1 and h, S .. "on: one highlight, for the one pinned section (" .. #b .. ")")
			local t = b[1]
			local ar, ag, ab = n.Skins:Accent()
			check(t and t.color and math.abs(t.color[1] - ar) < 1e-6 and math.abs(t.color[2] - ag) < 1e-6 and math.abs(t.color[3] - ab) < 1e-6 and math.abs(t.color[4] - 0.15) < 1e-6,
				S .. "in the accent color at 15%")
			check(t.parentFrame == V.child and t.layer == "BACKGROUND" and t.sublayer == -8, S .. "on the list's canvas, the bottom layer: behind the title and every item")
			local hy = h and h.points[1] and h.points[1][5]
			local ty = t.points[1] and t.points[1][5]
			check(t.points[1][1] == "TOPLEFT" and t.points[1][2] == V.child and ty == hy and t.points[1][4] == (h and h.points[1][4]), S .. "it starts at the section's title (" .. tostring(ty) .. " vs " .. tostring(hy) .. ")")
			check(t:GetWidth() == h:GetWidth() and t:GetHeight() > n.View.C.LANE_H, S .. "as wide as the section, and down past its items (" .. t:GetWidth() .. " x " .. t:GetHeight() .. ")")
			-- opacity
			n:Set("pinnedHighlightAlpha", 0.3); M.runTimers()
			check(math.abs(shownBacks(V)[1].color[4] - 0.3) < 1e-6, S .. "Highlight Opacity changes it")
			check(n:Set("pinnedHighlightAlpha", 2) and n.db.pinnedHighlightAlpha == 0.5 and not n:Set("pinnedHighlightAlpha", "x"), S .. "opacity is kept between 5% and 50%")
			n:Set("pinnedHighlightAlpha", 0.15); M.runTimers()
			-- collapsed: just the title
			V:ToggleLane("Consumables"); M.runTimers()
			t = shownBacks(V)[1]
			check(t and t:GetHeight() <= n.View.C.LANE_H + 4, S .. "a collapsed pinned section: behind its title only (" .. tostring(t and t:GetHeight()) .. ")")
			V:ToggleLane("Consumables"); M.runTimers()
			-- a second pinned section; then unpinned
			n.Sections:SetPinned("TradeGoods", true); n:RefreshViews(true); M.runTimers()
			check(#shownBacks(V) == 2, S .. "two pinned sections, two highlights (" .. #shownBacks(V) .. ")")
			n.Sections:SetPinned("TradeGoods", false); n.Sections:SetPinned("Consumables", false); n:RefreshViews(true); M.runTimers()
			check(#shownBacks(V) == 0, S .. "unpinned: none")
			-- the Sections page
			local P = n.SettingsPanel; P:Show(); P:ShowPage("sections"); M.runTimers()
			local cbox, step
			for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.key == "pinnedHighlight" then cbox = w end end
			for _, w in ipairs(P.pools.step or {}) do if w:IsShown() and w.key == "pinnedHighlightAlpha" then step = w end end
			check(cbox and cbox.text.text == "Highlight Pinned Sections" and step and step.text.text == "Highlight Opacity", S .. "Settings > Sections: Highlight Pinned Sections, with Highlight Opacity under it")
			n:Set("pinnedHighlight", false); M.runTimers()
			step = nil
			for _, w in ipairs(P.pools.step or {}) do if w:IsShown() and w.key == "pinnedHighlightAlpha" then step = w end end
			check(not step, S .. "Highlight Opacity shows only while it's on")
			P:Hide()
		end
	end

	-- ---- Split View: Full-Width Recent (Shweep): off by default; on, Recent spans both columns, a row of its own;
	-- greyed in Settings while Split View is off. Pinned highlights follow each column in Split View.
	for _, skin in ipairs({ "modern", "classic" }) do
		local S = skin .. ": "
		local n, M = plainBoot(skin, { view = "icons", grp = "type", splitView = true, recentSection = true, sizeMode = "fixed", fixW = 900 })
		local V = n.Window.main
		local now = time()
		n.cdb.recentSince = now - 100
		n.cdb.firstSeen[M.bags[0][1].guid] = now - 10
		n:Scan(); n:RefreshViews(true); M.runTimers()
		local function lane(id) for _, h in pairs(n.Buttons.lanes[V.child] or {}) do if h:IsShown() and h.laneId == id then return h end end end
		local rec = lane("~recent")
		check(V.twoColumn and rec, S .. "(setup) Split View is on, with Recent")
		local full = V.child:GetWidth()
		check(n.db.splitViewRecentWide == false and rec:GetWidth() < full * 0.6, S .. "off by default: Recent takes one column, like any section (" .. rec:GetWidth() .. " of " .. full .. ")")
		local first = rec.points[1][5]
		n:Set("splitViewRecentWide", true); M.runTimers()
		rec = lane("~recent")
		check(rec:GetWidth() > full * 0.9 and rec.points[1][4] == 0, S .. "on: Recent spans both columns (" .. rec:GetWidth() .. ")")
		-- the next two sections pair below it
		local below = {}
		for _, h in pairs(n.Buttons.lanes[V.child] or {}) do if h:IsShown() and h.laneId ~= "~recent" then below[#below + 1] = h end end
		table.sort(below, function(a, b) return a.points[1][5] < b.points[1][5] or (a.points[1][5] == b.points[1][5] and a.points[1][4] < b.points[1][4]) end)
		check(#below >= 2 and below[1].points[1][5] == below[2].points[1][5] and below[1].points[1][4] == 0 and below[2].points[1][4] > 0
			and below[1].points[1][5] < rec.points[1][5], S .. "the sections under it still pair, two to a row")
		-- pinned highlights follow the columns
		n:Set("pinnedHighlight", true); n.Sections:SetPinned("Consumables", true); n.Sections:SetPinned("TradeGoods", true); n:RefreshViews(true); M.runTimers()
		local b = shownBacks(V)
		table.sort(b, function(x, y) return x.points[1][4] < y.points[1][4] end)
		check(#b == 2 and b[1].points[1][4] == 0 and b[2].points[1][4] > 0 and b[1]:GetWidth() < full * 0.6, S .. "Split View: each pinned section's highlight fills its own column")
		-- Settings: under Split View, greyed while it's off
		local P = n.SettingsPanel; P:Show(); P:ShowPage("look"); M.runTimers()
		local function box() for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.key == "splitViewRecentWide" then return w end end end
		local c = box()
		check(c and c.text.text == "Full-Width Recent" and c.box:IsEnabled(), S .. "Settings > Style: Full-Width Recent, under Split View")
		n:Set("splitView", false); M.runTimers()
		c = box()
		check(c and not c.box:IsEnabled() and c.box:GetChecked(), S .. "greyed while Split View is off, showing its setting")
		P:Hide()
	end
end)()
