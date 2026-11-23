--[[
	Core/ItemTree.lua (1.10.0-beta6; the Helpers' question, IT:Holds, 1.10.0-beta7 and beta8)

	ItemTree is another addon, and optional. It knows what an item is for on the character you're playing: whether a
	profession of yours uses it, whether a quest needs it, whether it's an upgrade, whether vendors sell it, and what it
	would do with it. With Section and Filter Rules on (Settings > Addon Sources; the setting is useItemTree), section
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
-- (1.10.0-beta14, the beta13 re-audit's R5) keys whose last fresh read failed while an answer was held. The answer
-- stays for the rules; a Helper's list no longer leans on it, and asks again, until ItemTree answers.
local doubt = {}
local announcing = false
local BUDGET_MS, PER_TICK = 3, 4   -- a few a frame: by the clock where the game has one, else by count

local function api()
	local A = rawget(_G, "ItemTreeAPI")
	if type(A) == "table" and type(A.GetItemFacts) == "function" then return A end
end
function IT:Installed() return api() ~= nil end
-- Installed, and its rules on (Settings > Addon Sources > Section and Filter Rules; on unless you turned it off).
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
		-- (1.10.0-beta14, the re-audit's R1) not for an item that was yours when it was asked about and has left since
		-- (the bag change cancels those; this is the same rule where the answer would be stored)
		if q and known[key] == nil and not (q.held and live and not live[key]) then
			local ok, f = pcall(A.GetItemFacts, q.id, q.link)
			local e = ok and IT.Read(f) or false
			known[key], idOf[key] = e, q.id
			if e then doubt[key] = nil end
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
	-- held: the key was among your items at the last look (a row read from saved data, such as the bank away from the
	-- bank, never is; it is answered all the same)
	queued[key] = { id = id, link = link, held = (live ~= nil and live[key] == true) or nil }
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
-- (1.10.0-beta9) Each Helper has its own switch (Settings > Addon Sources), and neither depends on the rules' switch.
-- (1.10.0-beta13, the beta12 audit's F1) Three answers, not two. ItemTree's own contract: GetItemFacts returns nil
-- "when not ready" (and when its own inner call fails); an item it has no data for still gets a table. So nil, or an
-- error, is "couldn't say", and an unreadable safety answer is a no:
--   "hold"     ItemTree marks it Keep (and, for the Disenchant Helper, not for its dust)
--   "clear"    ItemTree answered, and doesn't keep it
--   "unknown"  ItemTree is installed and this Helper's switch is on, but it gave no answer: not ready, an error
--              inside it, or nothing back. The Helpers hold the item and refuse at the click.
--   nil        no opinion: ItemTree isn't installed, this Helper's switch is off, or the row isn't a real item of yours
-- A refresh that fails never replaces an answer already held.
function IT:Verdict(rec, fresh, forDisenchant)
	if not (ns.db and ns.db[forDisenchant and "deHoldItemTree" or "makeRoomHoldItemTree"] ~= false) then return nil end
	local A = api()
	if not A then return nil end
	if type(rec) ~= "table" or not rec.itemID or rec.global or rec.empty then return nil end
	local key = rec.link or rec.itemID
	local e = known[key]
	-- (false is what the rules' queue keeps when ItemTree gave it nothing: for a Helper that is no answer, so ask)
	-- (1.10.0-beta14, R5) and an answer in doubt is asked for again, so a list can't offer on the strength of a "clear"
	-- that the last click could not confirm
	if not e or fresh or doubt[key] then
		local now
		if ready() then
			local ok, f = pcall(A.GetItemFacts, rec.itemID, rec.link)
			if ok and type(f) == "table" then now = IT.Read(f) end
		end
		if not now then
			if e then doubt[key] = true end
			return "unknown"
		end
		doubt[key] = nil
		-- (a rule may be reading the same answer, or waiting for it: the views hear of it on the next frame)
		if queued[key] ~= nil or (e ~= nil and not same(e, now)) or (was[key] ~= nil and not same(was[key], now)) then changed = true end
		known[key], idOf[key], was[key], queued[key] = now, rec.itemID, nil, nil
		e = now
		if changed and not ticking then ticking = true; C_Timer.After(0, tick) end
	end
	if e.kept == true and not (forDisenchant and e.forDust) then return "hold" end
	return "clear"
end
-- Must a Helper hold this item back on ItemTree's account? Yes for its Keep, and (1.10.0-beta13) yes too when it is on
-- and couldn't answer: before, no answer read as "no", which let a failed refresh undo a Keep. The second value is the
-- verdict, for the words. (The Helpers ask IT:Verdict themselves.)
function IT:Holds(rec, fresh, forDisenchant)
	local verdict = self:Verdict(rec, fresh, forDisenchant)
	return verdict == "hold" or verdict == "unknown", verdict
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
		known[key], idOf[key], was[key], doubt[key] = nil, nil, nil, nil
	end
end
function IT:Forget()
	local keys = {}
	for key in pairs(known) do keys[#keys + 1] = key end
	for _, key in ipairs(keys) do forget(key) end
end
-- (1.10.0-beta14, the re-audit's R5) ItemTree's answers may have changed: said once to whoever is showing them (an
-- open Helper draws its list again), however many notices arrive together.
local function announce()
	if announcing then return end
	announcing = true
	C_Timer.After(0.2, function() announcing = false; ns:Fire("ITEMTREE_CHANGED") end)
end
-- A moment after something that can change ItemTree's answers with no word from it: once, however many times asked.
function IT:ForgetSoon()
	if forgetting or not next(known) then return end
	forgetting = true
	C_Timer.After(1, function() forgetting = false; IT:Forget(); announce() end)
end
-- (1.10.0-beta14, R5) While a Helper is open with items waiting for ItemTree, it looks again by itself: fn runs once,
-- IT.RETRY seconds from now, however many times this is asked meanwhile (who names the asker). A failure that passes
-- with no word from ItemTree is noticed this way.
IT.RETRY = 3
local retrying = {}
function IT:RetrySoon(who, fn)
	if retrying[who] or type(fn) ~= "function" then return end
	retrying[who] = true
	C_Timer.After(IT.RETRY, function() retrying[who] = nil; fn() end)
end

-- ItemTree's own word that its answers changed, or that its data is ready. Registered once it's there.
function IT:Hook()
	local A = api()
	if hooked or not A then return end
	hooked = true
	-- (1.10.0-beta14) and an open Helper hears of it: what it held as waiting is asked about again
	if type(A.RegisterChangeCallback) == "function" then pcall(A.RegisterChangeCallback, function() IT:Forget(); announce() end) end
	if type(A.RegisterReadyCallback) == "function" then
		pcall(A.RegisterReadyCallback, function()
			-- (rules asked while it wasn't ready got no answer: look again)
			if IT:Wanted() and ns.Sections and ns.Sections.Reapply then ns.Sections:Reapply() end
			-- (1.10.0-beta13) and so did the Helpers, which held everything back meanwhile: they hear of it too
			ns:Fire("ITEMTREE_READY")
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
		-- (1.10.0-beta14, the beta13 re-audit's R1) A lookup still waiting in the queue for an item that was yours and
		-- has left is cancelled, with the old answer kept aside for it. Before, the queue answered for the absent item
		-- a moment later, and when a copy came back that answer was found and nothing asked again.
		for key, q in pairs(queued) do
			if live[key] then q.held = true
			elseif q.held then queued[key], was[key] = nil, nil end
		end
		if not next(known) and not ticking then counts = now; return end
		local stale, gone = {}, {}
		for key, id in pairs(idOf) do
			if not live[key] then
				gone[#gone + 1] = key   -- (the item left, or its link changed with your level)
			elseif counts[id] ~= nil and now[id] ~= counts[id] then
				stale[#stale + 1] = key
			end
		end
		-- (1.10.0-beta13, the beta12 audit's F4) An item you no longer hold is let go at once. Its answer used to be
		-- kept until there were a great many, so when your last copy left and came back, the old answer was still
		-- there and nothing asked again: its count had no "before" to differ from.
		for _, key in ipairs(gone) do known[key], idOf[key], was[key], doubt[key] = nil, nil, nil, nil end
		counts = now
		for _, key in ipairs(stale) do forget(key) end
	end)
	-- The setting, or another profile: start over, and redraw at once (off means those rules fit nothing).
	ns:OnSignal("SETTINGS_CHANGED", function(key)
		if key ~= "useItemTree" and key ~= nil then return end
		known, was, idOf, queue, queued, head, changed, doubt = {}, {}, {}, {}, {}, 1, false, {}   -- (the bags' counts stay: they're the bags', not ItemTree's)
		if key == "useItemTree" then
			ns:Fire("ITEMTREE_FACTS")
			if ns.Sections and ns.Sections.Reapply then ns.Sections:Reapply() end
		end
	end)
	for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "SKILL_LINES_CHANGED" }) do
		ns:On(event, function() IT:ForgetSoon() end)
	end
end)
