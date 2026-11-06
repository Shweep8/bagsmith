;(function()
	-- 1.4.0-beta2: an item picked up from the window's own bags (a split stack) can be dropped into a free slot when
	-- the view shows no empty slots (By Section, List view); it never rejoins its own stack.
	local function boot(fill)
		package.loaded.mock = nil
		local M = require("mock")
		M.sizes[0] = 6
		for b = 1, 5 do M.sizes[b] = 0 end
		M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 10, stack = 20, class = 7, subclass = 5, price = 1 })
		M.put(0, 2, { id = 2592, name = "Wool Cloth", q = 1, count = 3, stack = 20, class = 7, subclass = 5, price = 2 })
		M.put(0, 4, { id = 2589, name = "Linen Cloth", q = 1, count = 5, stack = 20, class = 7, subclass = 5, price = 1 })   -- a Linen stack with room
		if fill then for s = 3, 6 do if not M.bags[0][s] then M.put(0, s, { id = 117, name = "Tough Jerky", q = 1, count = 20, stack = 20, class = 0, subclass = 5, price = 1 }) end end end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", emptySlots = true } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); M.runTimers(); M.runTimers()
		return n, M
	end
	-- the game, on a split: the source stack locks and part of it is on the cursor
	local function split(n, M)
		M.bags[0][1].locked = true
		for _, r in ipairs(n.items) do if r.bag == 0 and r.slot == 1 then r.isLocked = true end end
		M.cursorItem = 2589
		M.fire("ITEM_LOCK_CHANGED", 0, 1)
	end
	local function settle(M) for _ = 1, 12 do M.tick() end end

	-- ---- By Section, icons view: no empty slots shown, so the overlay offers a free slot
	local n, M = boot()
	local V = n.Window.main
	V:SetPref("grp", "type"); V:SetPref("view", "icons"); n:RefreshViews(true); M.runTimers()
	check(V.emptyShown == false, "(By Section shows no empty slots)")
	split(n, M)
	V.scroll.IsMouseOver = function() return true end
	settle(M)
	local o = V.dropOverlay
	check(o and o:IsShown() and o.label.text == "Drop to put it in a free slot" and o.sub.text:find("not back onto its stack", 1, true), "a split stack over the By Section list gets the free-slot drop")
	local before = #M.pickups
	o:GetScript("OnMouseUp")(o)
	local placed = M.pickups[before + 1]
	check(placed and placed ~= "0:1" and placed ~= "0:4" and (placed == "0:3" or placed == "0:5" or placed == "0:6"), "dropping it puts it in an empty slot, never back onto a Linen stack (" .. tostring(placed) .. ")")
	-- over an item, the game's own swap or stack: no overlay
	settle(M)
	local btn; for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and not b.rec.empty then btn = b; break end end
	btn.IsMouseOver = function() return true end
	settle(M)
	check(not o:IsShown(), "over an item the overlay stays away, so the game's swap or stack happens")
	btn.IsMouseOver = function() return false end
	-- over a section title: the title's own drop
	local head; for _, h in pairs(n.Buttons.lanes[V.child] or {}) do if type(h) == "table" and h.IsShown and h:IsShown() and h.laneId then head = h; break end end
	if head then
		head.IsMouseOver = function() return true end
		settle(M)
		check(not o:IsShown(), "over a section title the overlay stays away, so a custom section's drop still works")
		head.IsMouseOver = function() return false end
	end
	-- in combat: nothing
	_G.InCombatLockdown = function() return true end
	settle(M)
	check(not o:IsShown(), "in combat the overlay is off, as before")
	_G.InCombatLockdown = function() return false end

	-- ---- List view shows no empty slots either: the same drop
	V:SetPref("grp", "none"); V:SetPref("view", "list"); n:RefreshViews(true); M.runTimers()
	split(n, M); settle(M)
	check(V.emptyShown == false and o:IsShown() and o.label.text == "Drop to put it in a free slot", "List view (All) offers it too")

	-- ---- where empty slots are visible (All, icons), nothing changes: you drop into a slot
	V:SetPref("grp", "none"); V:SetPref("view", "icons"); n:RefreshViews(true); M.runTimers()
	check(V.emptyShown == true, "(All in icons view shows empty slots)")
	split(n, M); settle(M)
	check(not o:IsShown(), "with empty slots visible the overlay stays away for the window's own items")

	-- ---- no free slot: said, and nothing is placed
	n, M = boot(true)
	V = n.Window.main
	V:SetPref("grp", "type"); V:SetPref("view", "icons"); n:RefreshViews(true); M.runTimers()
	split(n, M)
	V.scroll.IsMouseOver = function() return true end
	settle(M)
	o = V.dropOverlay
	check(o and o:IsShown() and o.label.text == "No free slot", "with every slot full the overlay says No free slot (it doesn't offer the Linen stack)")
	before = #M.pickups
	o:GetScript("OnMouseUp")(o)
	local said = false; for _, l in ipairs(M.log) do if l:find("No free slot in your bags.", 1, true) then said = true end end
	check(#M.pickups == before and said, "dropping anyway places nothing and says so")
end)()
