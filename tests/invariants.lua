--[[
	tests/invariants.lua

	Rules that must always hold, checked after every step of the lifecycle
	scenarios (tests/lifecycle.lua). Each returns a list of violations (empty
	when all is well), so a scenario can say which step broke which rule.

	1. Every visible item button shows the item that is really in its own bag
	   slot (a click uses the slot, so display and click must match).
	2. The footer's free-slot count matches the real bags (own bags, own view).
	3. Token currency totals equal what's in the bags plus the bank.
	4. Owned items never lose their first-seen time (ages).
	5. Remembered sheet views only belong to sheets that exist.
	6. Away from the bank, the saved bank matches the last bank scan.
	7. Travel Mode's layout matches its state (out of combat): toolbar and
	   Filter hidden exactly when it's on, the character picker hidden and your
	   own bags showing, search in the title row right after the title, the
	   title saying so; never in the bank window.
	8. Every window's selected sheet exists in the current profile.
	9. In Travel Mode, the character picker's list isn't open.
	10. Junk shows as junk: the coin is on exactly the junk items (grey or
	    marked), and with Dim Junk Items on, exactly those are dimmed.
--]]
local I = {}

local function strip(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

function I.check(ns, M)
	local bad = {}
	-- The saved bank, read directly (so the rules also run against older builds).
	local function savedBank()
		local e = BagSmithDB and BagSmithDB.cache and BagSmithDB.cache[ns:CharKey()]
		return e and e.bank or nil
	end
	local function fail(msg) bad[#bad + 1] = msg end
	local W = ns.Window

	-- 1. Buttons show what's in their own slot.
	local function slotItem(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; return it and it.id or nil end
	local function checkButton(b, what)
		if not (b and b:IsVisible() and b.rec and not b.rec.cached) then return end
		local proxy = b:GetParent()
		local bag, slot = proxy and proxy.GetID and proxy:GetID(), b:GetID()
		if not bag or not slot then return end
		local real = slotItem(bag, slot)
		if b.rec.empty then
			if real then fail(("%s at bag %d slot %d is blank but the slot holds item %d"):format(what, bag, slot, real)) end
		elseif b.rec.itemID ~= real then
			fail(("%s at bag %d slot %d shows item %s but the slot holds %s"):format(what, bag, slot, tostring(b.rec.itemID), tostring(real)))
		end
	end
	for _, b in ipairs(ns.Buttons.all) do if b.secure then checkButton(b, "item button") end end
	for _, b in ipairs(ns.Buttons.recent) do checkButton(b, "Recent copy") end

	-- 2. Footer free slots match the bags (own bags in the main window).
	local main = W and W.main
	if main and main:IsShown() and not ns.ui.owner and main.st.sheet ~= "Bank" and main.freeText then
		local free, total = ns:FreeSlots(ns.BAGS)
		local shown = strip(main.freeText.text)
		local a, b = shown:match("(%d+)%s*/%s*(%d+)")
		if a and (tonumber(a) ~= free or tonumber(b) ~= total) then
			fail(("footer shows %s but the bags have %d / %d"):format(shown, free, total))
		end
	end

	-- 3. Token totals = bags + bank (this session's bank scan, else the saved bank).
	if ns.Currency and not ns.ui.owner then
		local want = {}
		local function add(list) for _, r in ipairs(list or {}) do if r.cat == "Tokens" then want[r.itemID] = (want[r.itemID] or 0) + (r.count or 1) end end end
		add(ns.items)
		add(ns.bankScanned and ns.bankItems or savedBank())
		local got = {}
		for _, e in ipairs(ns.Currency:List()) do if e.key and e.key:find("^i:") then got[e.id] = e.count end end
		for id, n in pairs(want) do
			if got[id] ~= n then fail(("token %d: currency total %s, bags and bank hold %d"):format(id, tostring(got[id]), n)) end
		end
		-- What the footer shows for favorite tokens matches too (catches a
		-- redraw that ran before the totals were recounted).
		if main and main:IsShown() and main.favChips then
			for _, chip in ipairs(main.favChips) do
				local id = chip:IsShown() and chip.key and tonumber(chip.key:match("^i:(%d+)$"))
				if id and want[id] and tonumber((strip(chip.text.text):gsub(",", ""))) ~= want[id] then
					fail(("footer shows %s for token %d, bags and bank hold %d"):format(strip(chip.text.text), id, want[id]))
				end
			end
		end
	end

	-- 4. Owned items keep their ages.
	if ns.cdb then
		local function owned(list, where)
			for _, r in ipairs(list or {}) do
				if r.guid and not ns.cdb.firstSeen[r.guid] then fail(("%s item %s (%s) has no first-seen time"):format(where, tostring(r.itemID), r.guid)) end
			end
		end
		owned(ns.items, "bag")
		if ns.bankScanned then owned(ns.bankItems, "bank") end
		if not ns.bankScanned then
			for _, r in ipairs(savedBank() or {}) do
				if r.guid and r.firstSeen and not ns.cdb.firstSeen[r.guid] then fail(("saved bank item %s (%s) lost its first-seen time"):format(tostring(r.itemID), r.guid)) end
			end
		end
	end

	-- 5. Remembered sheet views belong to sheets that exist.
	local prefs = ns.db.sheetPrefs or {}
	for win, list in pairs(prefs) do
		local sheets = win == "bank" and ns.db.bankSheets or ns.db.sheets
		local exists = {}
		for _, s in ipairs(sheets or {}) do exists[s.n] = true end
		for name in pairs(ns.TAB_LABEL or {}) do exists[name] = true end
		for name in pairs(list or {}) do
			if not exists[name] then fail(("a remembered %s view belongs to a sheet that doesn't exist: %s"):format(win, name)) end
		end
	end
	-- 6. Away from the bank, the saved bank matches what was last scanned there.
	if not ns.atBank and ns.bankScanned then
		local saved = savedBank() or {}
		local key = function(r) return ("%s:%s=%s x%s"):format(r.bag, r.slot, tostring(r.itemID), tostring(r.count or 1)) end
		local a, b = {}, {}
		for _, r in ipairs(ns.bankItems or {}) do a[key(r)] = true end
		for _, r in ipairs(saved) do b[key(r)] = true end
		for k in pairs(a) do if not b[k] then fail("the saved bank is missing " .. k .. " from the last bank scan") end end
		for k in pairs(b) do if not a[k] then fail("the saved bank still has " .. k .. ", gone from the last bank scan") end end
	end
	-- 7. Travel Mode layout matches its state.
	if main and main.TravelOn and main.tools and not InCombatLockdown() then
		local on = main:TravelOn()
		if main.tools:IsShown() == on then fail(("Travel Mode is %s but the toolbar is %s"):format(on and "on" or "off", main.tools:IsShown() and "shown" or "hidden")) end
		if main.btnFilter:IsShown() == on then fail("the Filter button doesn't match Travel Mode") end
		if on then
			if not (main.search.points[1] and main.search.points[1][2] == main.subText) then fail("in Travel Mode the search doesn't start right after the title") end
			if main.charBtn:IsShown() or (main.charReset and main.charReset:IsShown()) then fail("in Travel Mode the character picker is showing") end
			if ns.ui.owner then fail("in Travel Mode another character's bags are showing") end
			local t = (main.classicApplied and main.classicTitle and main.classicTitle.text) or main.titleText.text
			if not tostring(t):find("%(Travel Mode%)$") then fail("in Travel Mode the title doesn't say so: " .. tostring(t)) end
		end
		local bank = W.bank
		if bank and bank.tools and bank:IsShown() and not bank.tools:IsShown() then fail("the bank window lost its toolbar") end
	end
	-- 8. Selected sheets exist in this profile.
	for _, pair in ipairs({ { ns.ui, ns.db.sheets, "bags" }, { ns.uiBank, ns.db.bankSheets, "bank" } }) do
		local name = pair[1] and pair[1].sheet
		if name and name ~= "All" and not (ns.TAB_LABEL or {})[name] then
			local found = false
			for _, sh in ipairs(pair[2] or {}) do if sh.n == name then found = true end end
			if not found then fail(("the %s window's selected sheet %q isn't in this profile"):format(pair[3], name)) end
		end
	end
	-- 9. Travel Mode: no character list open.
	if main and main.TravelOn and main:TravelOn() and ns.Popups and ns.Popups.chars and ns.Popups.chars:IsShown() then
		fail("in Travel Mode the character picker's list is open")
	end
	-- 10. Junk coin and dimming match what's junk.
	if ns.Junk then
		local function look(b, what)
			if not (b and b:IsVisible() and b.rec and not b.rec.empty and b.junkCoin) then return end
			local junk = ns.Junk:IsJunk(b.rec)
			if b.junkCoin:IsShown() ~= junk then fail(("%s for item %s: coin %s but junk %s"):format(what, tostring(b.rec.itemID), tostring(b.junkCoin:IsShown()), tostring(junk))) end
			local dim = (junk and ns.db.dimJunk) and true or false
			if (b.dimmedJunk and true or false) ~= dim then fail(("%s for item %s: dimmed %s but should be %s"):format(what, tostring(b.rec.itemID), tostring(b.dimmedJunk), tostring(dim))) end
		end
		for _, b in ipairs(ns.Buttons.all) do if b.secure then look(b, "item button") end end
		for _, b in ipairs(ns.Buttons.recent) do look(b, "Recent copy") end
	end
	return bad
end

return I
