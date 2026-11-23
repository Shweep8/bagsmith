--[[
	Core/ItemTree.lua (1.10.0-beta6; the Helpers' question, IT:Holds, 1.10.0-beta7 and beta8)

	ItemTree is another addon, and optional. It knows what an item is for on the character you're playing: whether a
	profession of yours uses it, whether a quest needs it, whether it's an upgrade, whether vendors sell it, and what it
	would do with it. With Section and Filter Rules on (Settings > Other Addons; the setting is useItemTree), section
	and filter rules can ask (Core/Rules.lua, the it_ keys). BagSmith works the same without it: no ItemTree, or the
	setting off, and those rules fit nothing. The two Helpers have switches of their own (IT:Holds).

	Only its public API is used (the global ItemTreeAPI, version 1): IsReady, GetItemFacts(itemId, link),
	RegisterReadyCallback and RegisterChangeCallback. Never RequestData: BagSmith doesn't make ItemTree load anything.

	What the game showed (Shweep's /run output, 22 Nov, ItemTree v1.2.8), and what this file does about it:
	  * GetItemFacts builds a NEW table on every call (about 13 KB), and the first call about an item takes about
	    1.3 ms (51 ms for a 40-item bag), later ones about 0.13 ms. So an item is asked ONCE, a few a frame, and only
	    the few answers the rules read are kept (IT.Read), never ItemTree's table.
	  * Nothing is asked unless a rule asks: IT:Facts is only called by the it_ keys.
	  * ItemTree's change notice doesn't fire for ordinary play (looting, selling). So the answers are also asked
	    again for an item whose count changed, and for everything a moment after your gear, level, quests or skills
	    change. Views are only redrawn when an answer really changed.
	  * uses.kinds holds counts for EVERY profession's recipes, and 0 is true in Lua: it isn't read at all.
	    "Used by My Professions" is uses.reagentSkills (a recipe of one of YOUR professions uses it now) or
	    route.needed (ItemTree keeps it for one).

	An item ItemTree hasn't been asked about yet has no answer: IT:Facts returns nil, the rule doesn't fit (with or
	without "is not"), and the item waits where it otherwise would until the answer is in.
--]]
local ADDON, ns = ...
local IT = {}
ns.ItemTree = IT

local known = {}    -- key (an item's link, or its id) -> its answers, or false when ItemTree had none
local was = {}      -- the answers a key had before it was asked again, to tell whether anything changed
local idOf = {}     -- key -> item id
local counts = {}   -- item id -> how many you held when the bags were last looked at
local queue, queued, head = {}, {}, 1
local changed, ticking, hooked, forgetting = false, false, false, false
local live          -- the keys the bags and bank held when they were last looked at
local MAX_KNOWN = 600   -- answers for keys no item has any more are let go past this many (a link changes with your level)
local BUDGET_MS, PER_TICK = 3, 4   -- a few a frame: by the clock where the game has one, else by count

local function api()
	local A = rawget(_G, "ItemTreeAPI")
	if type(A) == "table" and type(A.GetItemFacts) == "function" then return A end
end
function IT:Installed() return api() ~= nil end
-- Installed, and its rules on (Settings > Other Addons > Section and Filter Rules; on unless you turned it off).
function IT:Enabled() return api() ~= nil and not (ns.db and ns.db.useItemTree == false) end
local wasReady = false   -- (its data doesn't unload: once ready, it isn't asked again on every item)
-- ItemTree is there and its data is ready, whatever BagSmith's own switches say.
local function ready()
	local A = api()
	if not A then return false end
	if not hooked then IT:Hook() end
	if wasReady or type(A.IsReady) ~= "function" then return true end
	local ok, r = pcall(A.IsReady)
	wasReady = ok and r == true
	return wasReady
end
-- For the rules: ready, and the rules switched on.
function IT:Ready() return self:Enabled() and ready() end

-- ItemTree's facts for one item, as the few answers the rules read. Pure. Every field is read only where it's there
-- (v1.2.8 has fields v1.2.7's notes didn't list, and price can be missing altogether).
function IT.Read(f)
	if type(f) ~= "table" then return nil end
	local uses, route, keep, quests, vendors = f.uses, f.route, f.keep, f.quests, f.vendors
	local skills = type(uses) == "table" and uses.reagentSkills
	local needs = type(quests) == "table" and quests.needs
	local gear = type(keep) == "table" and keep.gear
	local e = {
		prof = (type(skills) == "table" and #skills > 0) or (type(route) == "table" and route.needed == true) or false,
		quest = (type(needs) == "table" and #needs > 0) or false,
		upgrade = (type(gear) == "table" and gear.upgrade == true) or false,
		vendor = (type(vendors) == "table" and type(vendors.count) == "number" and vendors.count > 0) or false,
		-- (1.10.0-beta7) its Keep mark, for the Loot Helper and the Disenchant Helper (IT:Holds); no rule reads it
		kept = (type(keep) == "table" and keep.marked == true) or false,
		-- (1.10.0-beta8) ... and whether that Keep is for its dust: ItemTree's state for a piece it keeps in order to
		-- disenchant it (Shweep's Lupine Slippers, 22 Nov: "Keep", "Disenchants into Strange Dust")
		forDust = (type(keep) == "table" and keep.state == "keepDisenchant") or false,
		tags = {},
	}
	local tags = type(keep) == "table" and keep.tags
	if type(tags) == "table" then
		for _, tag in ipairs(tags) do
			if type(tag) == "string" and #tag <= 24 and tag:match("^%l+$") and #e.tags < 8 then e.tags[#e.tags + 1] = tag end
		end
	end
	return e
end
local function same(a, b)
	if a == b or (not a and not b) then return true end   -- (no answer before, none now: nothing changed)
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	return a.prof == b.prof and a.quest == b.quest and a.upgrade == b.upgrade and a.vendor == b.vendor
		and table.concat(a.tags, ",") == table.concat(b.tags, ",")
end

-- Does any section, or any window's filters, have an ItemTree rule right now?
function IT:Wanted()
	local R = ns.Rules
	if not R then return false end
	local function uses(rules)
		if type(rules) ~= "table" or type(rules.rows) ~= "table" then return false end
		for _, row in ipairs(rules.rows) do
			local def = type(row) == "table" and R.KEYS[row.k]
			if def and def.addon == "ItemTree" then return true end
		end
		return false
	end
	for _, c in ipairs(ns.Sections and ns.Sections:Customs() or {}) do if uses(c.rules) then return true end end
	for _, v in pairs(ns.views or {}) do if v.st and v.st.filters and uses(v.st.filters.rules) then return true end end
	return false
end

-- Asking, a few items a frame.
local function settled()
	ticking = false
	if not changed then return end
	changed = false
	ns:Fire("ITEMTREE_FACTS")
	if ns.Sections and ns.Sections.Reapply then ns.Sections:Reapply() end
end
local function tick()
	local A = api()
	if not (A and IT:Ready()) then
		-- (the rules are off, or ItemTree isn't ready: no rule is reading anything, so there is nothing to redraw)
		queue, queued, head, ticking, changed = {}, {}, 1, false, false
		return
	end
	local clock = rawget(_G, "debugprofilestop")
	local t0, n = clock and clock(), 0
	while head <= #queue do
		local key = queue[head]; head = head + 1
		local q = queued[key]; queued[key] = nil
		if q and known[key] == nil then
			local ok, f = pcall(A.GetItemFacts, q.id, q.link)
			local e = ok and IT.Read(f) or false
			known[key], idOf[key] = e, q.id
			if not same(was[key], e) then changed = true end
			was[key] = nil
			n = n + 1
			if clock then
				if clock() - t0 >= BUDGET_MS then break end
			elseif n >= PER_TICK then break end
		end
	end
	if head <= #queue then
		C_Timer.After(0, tick)
	else
		queue, head = {}, 1
		settled()
	end
end
local function ask(key, id, link)
	if queued[key] or known[key] ~= nil then return end
	queued[key] = { id = id, link = link }
	queue[#queue + 1] = key
	if not ticking then ticking = true; C_Timer.After(0, tick) end
end

-- The answers for a record: { prof, quest, upgrade, vendor, tags }, or nil while there are none (ItemTree isn't
-- there, isn't ready, is turned off, hasn't been asked yet, or doesn't know). Global Inventory's rows are never asked:
-- the answers are about the character you're playing.
function IT:Facts(rec)
	if type(rec) ~= "table" or not rec.itemID or rec.global or rec.empty then return nil end
	if not self:Ready() then return nil end
	local key = rec.link or rec.itemID
	local e = known[key]
	if e ~= nil then return e or nil end
	ask(key, rec.itemID, rec.link)
	return nil
end

-- (1.10.0-beta7) Does ItemTree say to keep this item? For the Loot Helper and the Disenchant Helper, which act on the
-- answer: asked on the spot if it isn't known (a handful of items, the ones a Helper would otherwise offer), and with
-- fresh, asked again whatever is known (the Loot Helper's check at the click). True only on a clear yes: no ItemTree,
-- the setting off, not ready, or no answer all mean the Helpers go on as they always have. It only ever adds a reason
-- to hold an item back; it never takes one away.
-- (1.10.0-beta8, Shweep: "This doesn't make sense to hold it back for DE helper, right?") forDisenchant: the Disenchant
-- Helper's question. A piece ItemTree keeps for its dust is kept in order to be disenchanted, so there it isn't held.
-- (1.10.0-beta9) Each Helper has its own switch (Settings > Other Addons), and neither depends on the rules' switch.
function IT:Holds(rec, fresh, forDisenchant)
	if not (ns.db and ns.db[forDisenchant and "deHoldItemTree" or "makeRoomHoldItemTree"] ~= false) then return false end
	if type(rec) ~= "table" or not rec.itemID or rec.global or rec.empty then return false end
	if not ready() then return false end
	local key = rec.link or rec.itemID
	local e = known[key]
	if e == nil or fresh then
		local A = api()
		local ok, f = pcall(A.GetItemFacts, rec.itemID, rec.link)
		local now = ok and IT.Read(f) or false
		-- (a rule may be reading the same answer, or waiting for it: the views hear of it on the next frame)
		if queued[key] ~= nil or (e ~= nil and not same(e, now)) or (was[key] ~= nil and not same(was[key], now)) then changed = true end
		known[key], idOf[key], was[key], queued[key] = now, rec.itemID, nil, nil
		e = now
		if changed and not ticking then ticking = true; C_Timer.After(0, tick) end
	end
	if not (e and e.kept == true) then return false end
	if forDisenchant and e.forDust then return false end
	return true
end

-- Forgets answers so they're asked again: one key, or everything. What was known is kept aside to compare with, so
-- nothing is redrawn when the new answers say the same. Asked again at once only while a rule wants them.
local function forget(key)
	if known[key] == nil then return end
	local id = idOf[key]
	if id and (not live or live[key]) and IT:Ready() and IT:Wanted() then
		if was[key] == nil then was[key] = known[key] end
		known[key] = nil
		ask(key, id, type(key) == "string" and key or nil)
	else
		-- (no rule wants it any more: let it go; it's asked afresh if one ever does)
		known[key], idOf[key], was[key] = nil, nil, nil
	end
end
function IT:Forget()
	local keys = {}
	for key in pairs(known) do keys[#keys + 1] = key end
	for _, key in ipairs(keys) do forget(key) end
end
-- A moment after something that can change ItemTree's answers with no word from it: once, however many times asked.
function IT:ForgetSoon()
	if forgetting or not next(known) then return end
	forgetting = true
	C_Timer.After(1, function() forgetting = false; IT:Forget() end)
end

-- ItemTree's own word that its answers changed, or that its data is ready. Registered once it's there.
function IT:Hook()
	local A = api()
	if hooked or not A then return end
	hooked = true
	if type(A.RegisterChangeCallback) == "function" then pcall(A.RegisterChangeCallback, function() IT:Forget() end) end
	if type(A.RegisterReadyCallback) == "function" then
		pcall(A.RegisterReadyCallback, function()
			-- (rules asked while it wasn't ready got no answer: look again)
			if IT:Wanted() and ns.Sections and ns.Sections.Reapply then ns.Sections:Reapply() end
		end)
	end
end

-- (for the tests) how many answers are held, and how many are waiting to be asked
function IT:Count()
	local n = 0
	for _ in pairs(known) do n = n + 1 end
	return n, #queue - head + 1
end

ns:OnSignal("ADDON_READY", function()
	IT:Hook()
	-- The bags changed: an item whose count changed is asked again (ItemTree's change notice is for changes with no
	-- bag change), and one that's gone is let go.
	ns:OnSignal("ITEMS_CHANGED", function()
		-- (1.10.0-beta7) the counts are kept whether or not anything is known yet: a Helper's question can come between
		-- two looks at the bags, and a stack that changed right after it must still be noticed
		local now = {}
		live = {}
		for _, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
			for _, r in ipairs(list) do
				if r.itemID then
					now[r.itemID] = (now[r.itemID] or 0) + (r.count or 1)
					live[r.link or r.itemID] = true
				end
			end
		end
		if not next(known) and not ticking then counts = now; return end
		local stale, gone, total = {}, {}, 0
		for key, id in pairs(idOf) do
			total = total + 1
			if not live[key] then
				gone[#gone + 1] = key   -- (the item left, its link changed with your level, or it's in a saved bank)
			elseif counts[id] ~= nil and now[id] ~= counts[id] then
				stale[#stale + 1] = key
			end
		end
		if total > MAX_KNOWN then
			for _, key in ipairs(gone) do known[key], idOf[key], was[key] = nil, nil, nil end
		end
		counts = now
		for _, key in ipairs(stale) do forget(key) end
	end)
	-- The setting, or another profile: start over, and redraw at once (off means those rules fit nothing).
	ns:OnSignal("SETTINGS_CHANGED", function(key)
		if key ~= "useItemTree" and key ~= nil then return end
		known, was, idOf, queue, queued, head, changed = {}, {}, {}, {}, {}, 1, false   -- (the bags' counts stay: they're the bags', not ItemTree's)
		if key == "useItemTree" then
			ns:Fire("ITEMTREE_FACTS")
			if ns.Sections and ns.Sections.Reapply then ns.Sections:Reapply() end
		end
	end)
	for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "SKILL_LINES_CHANGED" }) do
		ns:On(event, function() IT:ForgetSoon() end)
	end
end)
