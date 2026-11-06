;(function()
	-- 1.4.0-beta6: the 1.4.0-beta5 audit's P1. The Disenchant button's combat guard is run for real: its stored
	-- snippet is compiled and given the values the game's state driver can hand over (numbers included).
	local drivers = {}
	local function boot(registerFails)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
		_G.IsSpellKnown = function(id) return id == 13262 end
		_G.GetSpellInfo = function(id) if id == 13262 then return "Disenchant" end end
		drivers = {}
		_G.RegisterStateDriver = function(frame, state, cond)
			if registerFails then error("no state drivers here") end
			drivers[#drivers + 1] = { frame = frame, state = state, cond = cond }
		end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M
	end
	local n, M = boot()
	local DE = n.Disenchant
	local b = DE:Button()
	local guard; for _, d in ipairs(drivers) do if d.frame == b and d.state == "bscombat" then guard = d end end
	check(guard and guard.cond == "[combat] lock; open" and DE.combatGuard == true, "the guard is registered with word states, not numbers (" .. tostring(guard and guard.cond) .. ")")
	local body = b:GetAttribute("_onstate-bscombat")
	local run = assert(loadstring("return function(self, newstate) " .. body .. " end"))()
	local function armed() return b:GetAttribute("type") == "spell" and b:GetAttribute("target-slot") == 1 end
	for _, state in ipairs({ "lock", 1, "1", 0, "0", "something else" }) do
		DE:Arm({ bag = 0, slot = 1, itemID = 7001 })
		local was = armed()
		run(b, state)
		check(was and b:GetAttribute("type") == nil and b:GetAttribute("target-bag") == nil and b:GetAttribute("target-slot") == nil and b:GetAttribute("target-item") == nil,
			"state " .. tostring(state) .. " (" .. type(state) .. "): the button is disarmed, action and target both")
	end
	-- "open" (combat over) never re-arms by itself: no stale target comes back
	DE:Arm({ bag = 0, slot = 1, itemID = 7001 }); run(b, "lock"); run(b, "open")
	check(b:GetAttribute("type") == nil and b:GetAttribute("target-slot") == nil, "the end of combat doesn't put the old target back")
	DE:Arm({ bag = 0, slot = 1, itemID = 7001 }); run(b, "open")
	check(armed(), "and out of combat an armed button stays armed")
	-- the auditor's sequence: in combat the guard has disarmed, and PreClick (which returns early in combat) changes nothing
	DE:Arm({ bag = 0, slot = 1, itemID = 7001 })
	_G.InCombatLockdown = function() return true end
	run(b, 1)
	b:GetScript("PreClick")(b)
	check(b:GetAttribute("type") == nil and b:GetAttribute("target-slot") == nil, "numeric combat state, then a click in combat: nothing armed")
	_G.InCombatLockdown = function() return false end
	-- combat over: the helper re-arms from a fresh look when something was armed
	DE.current = { bag = 0, slot = 1, itemID = 7001 }
	local refreshed = false
	local realRefresh = DE.Refresh
	DE.Refresh = function(self, ...) refreshed = true; return realRefresh(self, ...) end
	M.fire("PLAYER_REGEN_ENABLED")
	DE.Refresh = realRefresh
	check(refreshed, "when combat ends with something armed, the helper looks again (the guard only disarms)")
	-- a client where the guard can't be registered: the button never arms
	n, M = boot(true)
	DE = n.Disenchant
	b = DE:Button()
	DE:Arm({ bag = 0, slot = 1, itemID = 7001 })
	local said = false; for _, l in ipairs(M.log) do if l:find("wouldn't let BagSmith guard the Disenchant button in combat", 1, true) then said = true end end
	check(DE.combatGuard == false and b:GetAttribute("type") == nil and b:GetAttribute("target-slot") == nil and said, "without the guard the button never arms, and chat says why")
end)()

;(function()
	-- 1.4.0-beta6: the 1.4.0-beta5 audit's two P2s. A drop among All Items is decided by what the slot holds after
	-- the game acts: a rejected drop, a modified click or a same-item merge change no section, and the item judged is
	-- the one that landed, whatever the cursor did in between frames. The game's moves are modeled in the bags.
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 8; for bb = 1, 5 do M.sizes[bb] = 0 end
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
	M.put(0, 2, { id = 117, name = "Tough Jerky", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
	M.put(0, 3, { id = 2592, name = "Wool Cloth", q = 1, count = 3, class = 7, subclass = 5, price = 2 })
	M.put(0, 4, { id = 159, name = "Spring Water", q = 1, count = 3, class = 0, subclass = 5, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", emptySlots = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V, S = n.Window.main, n.Sections
	local function refresh() n:RefreshViews(true); M.runTimers() end
	local test = S:Create("Audit"); S:SetPinned(test, true)
	V:SetPref("grp", "none"); V:SetPref("view", "icons"); V:SetPref("sort", "off")
	local function target(id)
		for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id and b.inLane == "~all" then return b end end
	end
	local function settle() for _ = 1, 5 do M.runTimers() end end
	-- (1.4.0-beta7: a drag is judged by the row it started from, so each drag starts from its row, as in the game)
	local function startDrag(id) for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then b:GetScript("OnDragStart")(b); return b end end end

	-- ---- rejected click: the slot is locked, nothing moves
	S:Move(2589, test); refresh()
	M.bags[0][2].locked = true
	M.cursorItem = 2589
	local t = target(117)
	check(t ~= nil, "(the Tough Jerky slot is in All Items)")
	t:GetScript("OnMouseDown")(t, "LeftButton")
	t:GetScript("OnClick")(t, "LeftButton")
	settle()
	check(S:MovedTo(2589) == test, "a rejected click keeps Linen Cloth in its pinned section")
	-- ---- rejected drag: the same
	startDrag(2589)
	t:GetScript("OnReceiveDrag")(t); settle()
	check(S:MovedTo(2589) == test, "a rejected drag keeps it there too")
	M.bags[0][2].locked = nil
	-- ---- a modified click that does something else (a split, a chat link): the slot is unchanged
	_G.IsModifiedClick = function() return true end
	t:GetScript("OnMouseDown")(t, "LeftButton"); t:GetScript("OnClick")(t, "LeftButton"); settle()
	_G.IsModifiedClick = function() return false end
	check(S:MovedTo(2589) == test, "a modified click that places nothing changes no section")
	M.cursorItem = nil
	-- ---- a merge onto the same item: same item in the slot, nothing to judge
	local w = target(2592)
	M.cursorItem = 2592; M.bags[0][3].count = 6
	w:GetScript("OnReceiveDrag")(w); settle()
	check(S:MovedTo(2592) == nil and S:MovedTo(2589) == test, "a merge onto the same item changes no section")
	M.cursorItem = nil
	-- ---- the cursor changes between frames: the drag's own record decides (it started from Wool's row), not the cursor
	S:Move(2592, test); refresh()
	startDrag(2592)
	M.cursorItem = 2589; M.fire("CURSOR_CHANGED"); M.tick()
	M.cursorItem = 2592; M.fire("CURSOR_CHANGED")            -- no frame in between
	t = target(117)
	M.bags[0][2], M.bags[0][3] = M.bags[0][3], M.bags[0][2]  -- Wool lands in the Jerky slot; Jerky goes back
	M.cursorItem = nil
	t:GetScript("OnReceiveDrag")(t); settle()
	check(S:MovedTo(2592) == nil and S:MovedTo(2589) == test, "the Wool that landed leaves the pinned section; Linen, carried a frame earlier, stays")
	-- ---- a placement the game settles a moment later
	S:Move(2592, test); refresh()
	t = target(159)
	startDrag(2589)
	t:GetScript("OnReceiveDrag")(t)                          -- nothing in the slot has changed yet
	M.bags[0][4], M.bags[0][1] = M.bags[0][1], M.bags[0][4]  -- then Linen arrives in the Spring Water slot
	settle()
	check(S:MovedTo(2589) == nil, "a placement that settles a moment later is still noticed")
	-- ---- and one that never happens is given up on
	S:Move(2589, test); refresh()
	t = target(117) or target(159)
	startDrag(2589)
	if t then t:GetScript("OnReceiveDrag")(t) end
	for _ = 1, 10 do M.runTimers() end
	check(S:MovedTo(2589) == test, "a drop where nothing lands is given up on after a few looks")
end)()
