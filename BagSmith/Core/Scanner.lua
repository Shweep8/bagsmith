--[[
	BagSmith - Core/Scanner.lua
	Reads bags (always) and bank (while open) through C_Container into flat
	record lists, and writes a per-character cache into BagSmithDB.cache so
	other characters can be browsed read-only.
--]]

local ADDON, ns = ...

ns.items = {}       -- live bag records
ns.bankItems = {}   -- live bank records (last seen while bank was open)
ns.bagInfo = {}     -- bag -> { size, free, family, name }
ns.atBank = false
ns.pendingInfo = false

local function bagSize(bag)
	if bag == ns.KEYRING and type(GetKeyRingSize) == "function" then
		return (HasKey and not HasKey()) and 0 or (GetKeyRingSize() or 0)
	end
	return C_Container.GetContainerNumSlots(bag) or 0
end

local function itemLevel(link)
	if C_Item.GetDetailedItemLevelInfo then
		local ok, lvl = pcall(C_Item.GetDetailedItemLevelInfo, link)
		if ok and type(lvl) == "number" then return lvl end
	end
end

local function guidFor(bag, slot)
	if C_Item.GetItemGUID and ItemLocation then
		local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
		if loc and C_Item.DoesItemExist(loc) then
			local ok, guid = pcall(C_Item.GetItemGUID, loc)
			if ok then return guid end
		end
	end
end

-- "New" is BagSmith's own state, so it survives reloads and clears only
-- when the player has really looked at the item:
--   * the client's new-item flag, or a stack that grew since the last scan,
--     marks an item new
--   * hovering it for a moment dismisses it (DismissNew), remembering the
--     stack count, so it stays dismissed until the stack grows again.
ns.lastCounts = ns.lastCounts or {}   -- guid -> count at the previous scan
ns.newFlags = ns.newFlags or {}       -- guid -> true while flagged this session
local function clientNew(bag, slot)
	return C_NewItems and C_NewItems.IsNewItem and C_NewItems.IsNewItem(bag, slot) or false
end
-- Without item GUIDs (some clients give none) the key is the slot plus the
-- item and its stack count, which is stable until the slot changes.
local function slotKey(bag, slot) return bag .. ":" .. slot end
local function slotValue(itemID, count) return itemID .. ":" .. count end

-- grew: the stack grew AND you now hold more of the item (decided in ns:Scan
-- once every stack is read; combining stacks isn't new).
local function isNew(bag, slot, guid, count, itemID, grew)
	local key = guid or slotKey(bag, slot)
	if grew then ns.newFlags[key] = true end
	if clientNew(bag, slot) then ns.newFlags[key] = true end
	if ns.cdb then
		-- A dismissed stack that shrinks lowers its remembered size, so growing
		-- again from there counts as new (10 dismissed, used to 2, looted to 3).
		-- Both memories are lowered before either is checked.
		local sk = slotKey(bag, slot)
		local seenCount = guid and ns.cdb.seen[guid]
		if seenCount and count < seenCount then ns.cdb.seen[guid] = count; seenCount = count end
		local sv = ns.cdb.seenSlots[sk]
		local sid, scount
		if sv then
			sid, scount = sv:match("^(%d+):(%d+)$")
			if sid and tonumber(sid) == itemID then
				scount = tonumber(scount)
				if count < scount then ns.cdb.seenSlots[sk] = sid .. ":" .. count; scount = count end
			else
				sid = nil
			end
		end
		if seenCount and count <= seenCount then return false end
		-- Slot memory is for clients without item GUIDs; with GUIDs it would
		-- mistake another stack moved into this slot for the dismissed one.
		if not guid and sid and count <= scount then return false end
	end
	return ns.newFlags[key] and true or false
end

function ns:DismissNew(rec)
	if not rec or rec.cached then return end
	local key = rec.guid or (rec.bag and rec.slot and slotKey(rec.bag, rec.slot))
	if key then ns.newFlags[key] = nil end
	-- A merged row's count is the total of all its stacks: remember this
	-- slot's own stack size, not the total.
	local count = rec.count or 1
	if rec.merged and rec.bag and rec.slot then
		for _, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
			for _, r in ipairs(list) do if r.bag == rec.bag and r.slot == rec.slot then count = r.count or 1 end end
		end
	end
	if ns.cdb then
		if rec.guid then ns.cdb.seen[rec.guid] = count end
		if rec.bag and rec.slot and rec.itemID then ns.cdb.seenSlots[slotKey(rec.bag, rec.slot)] = slotValue(rec.itemID, count) end
	end
	if C_NewItems and C_NewItems.RemoveNewItem and rec.bag and rec.slot then pcall(C_NewItems.RemoveNewItem, rec.bag, rec.slot) end
	rec.isNew = false
	-- The row may hold a merged copy; clear the live records it was built from
	-- (every stack of the same item when merging), otherwise the next redraw
	-- rebuilds the row from records that still say "new".
	local function clearLive(list)
		for _, r in ipairs(list) do
			-- The stacks this row stands for: the same merge identity (never a
			-- different piece of gear that only shares the item ID).
			local same = (r.bag == rec.bag and r.slot == rec.slot) or (rec.merged and ns.MergeKey(r) == ns.MergeKey(rec))
			if same and r.isNew then
				r.isNew = false
				local k = r.guid or slotKey(r.bag, r.slot)
				ns.newFlags[k] = nil
				if ns.cdb then
					if r.guid then ns.cdb.seen[r.guid] = r.count or 1 end
					ns.cdb.seenSlots[slotKey(r.bag, r.slot)] = slotValue(r.itemID, r.count or 1)
				end
				if C_NewItems and C_NewItems.RemoveNewItem then pcall(C_NewItems.RemoveNewItem, r.bag, r.slot) end
			end
		end
	end
	clearLive(ns.items); clearLive(ns.bankItems)
end

-- firstStamp: the first-seen time for an item not seen before (the bank's use
-- the session's start: anything first seen there was already yours).
local function readSlot(bag, slot, now, bagIndex, firstStamp)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	if not info or not info.itemID then return nil end
	local link = info.hyperlink
	local rec = {
		bag = bag, slot = slot, bagIndex = bagIndex, itemID = info.itemID, link = link,
		icon = info.iconFileID, quality = info.quality, count = info.stackCount or 1,   -- (1.5.1-beta3) a missing quality stays unknown for now
		isLocked = info.isLocked or false, isBound = info.isBound or false, hasNoValue = info.hasNoValue or false,
		isReadable = info.isReadable or false,
		name = link and link:match("%[(.-)%]") or ("Item " .. info.itemID),
		where = ns.bagInfo[bag] and ns.bagInfo[bag].name or "",
	}
	-- The instant lookup never waits on the item cache, so class and subclass
	-- are known on the first draw even for items the client has not loaded.
	if C_Item.GetItemInfoInstant then
		local ok, _, iType, iSub, iEquip, iIcon, iClass, iSubclass = pcall(C_Item.GetItemInfoInstant, info.itemID)
		if ok and iClass then
			rec.itemType, rec.itemSubType, rec.equipLoc = iType, iSub, iEquip
			rec.icon = rec.icon or iIcon
			rec.classID, rec.subclassID = iClass, iSubclass
		end
	end
	local name, _, quality, ilvl, minLevel, itemType, itemSubType, maxStack, equipLoc, icon, sellPrice, classID, subclassID, bindType, _, _, isCraftingReagent =
		C_Item.GetItemInfo(link or info.itemID)
	if name then
		rec.name, rec.quality = name, rec.quality or quality
		rec.ilvl, rec.minLevel = itemLevel(link) or ilvl, minLevel
		rec.itemType, rec.itemSubType, rec.equipLoc = itemType, itemSubType, equipLoc
		rec.maxStack = maxStack
		rec.icon, rec.sellPrice = rec.icon or icon, sellPrice
		rec.classID, rec.subclassID, rec.bindType = classID, subclassID, bindType
		rec.isCraftingReagent = isCraftingReagent and true or false
	else
		ns.pendingInfo = true
		if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(info.itemID) end
	end
	-- (1.5.1-beta3, the beta2 audit's L4) The bag's own quality first, then the item's cached quality; only then
	-- common, marked as unknown so nothing destructive treats it as known to be common. (Before, a quality the bag
	-- didn't report became common at once and the cached quality could never replace it.)
	if rec.quality == nil then rec.quality, rec.qualityUnknown = 1, true end
	-- Quest items and quest starters, whatever their class.
	if C_Container.GetContainerItemQuestInfo then
		local ok, q = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
		if ok and type(q) == "table" and (q.isQuestItem or q.questID) then rec.isQuest = true end
	end
	rec.ownCat = ns:Categorize(rec)
	-- Moved to another section (per profile), unless marked as junk below.
	rec.cat = ns.Sections and ns.Sections:Apply(rec, rec.ownCat) or rec.ownCat
	-- Marked as junk (this character): sorted into Junk, sold with Sell All Junk.
	if ns.Junk and ns.Junk:Marked(rec.itemID) then rec.cat = "Junk" end
	-- In one of your gear sets (the game's equipment sets): their names.
	if ns.GearSets then ns.GearSets:Tag(rec) end
	local guid = guidFor(bag, slot)
	rec.guid = guid
	ns.hasGuids = ns.hasGuids or (guid ~= nil)
	-- A stack that grew: whether that's new is decided after the scan, once
	-- it's known whether you hold more of the item than before.
	local prev = ns.lastCounts[guid or slotKey(bag, slot)]
	if prev and rec.count > prev then rec.grewFrom = prev end
	if guid and ns.cdb then
		local seen = ns.cdb.firstSeen
		if not seen[guid] then
			seen[guid] = firstStamp or now
			rec.freshStamp = true      -- candidate for inheriting a split stack's age
		end
		rec.firstSeen = seen[guid]
	end
	rec.isNew = isNew(bag, slot, guid, rec.count, rec.itemID, false)
	return rec
end

-- The unique IDs of what you're wearing (empty when the client can't say).
function ns.WornGuids()
	local out = {}
	if not (ItemLocation and type(ItemLocation.CreateFromEquipmentSlot) == "function" and C_Item and type(C_Item.GetItemGUID) == "function"
		and type(GetInventoryItemID) == "function") then return out end
	for slot = 1, 19 do
		if GetInventoryItemID("player", slot) then
			local ok, loc = pcall(ItemLocation.CreateFromEquipmentSlot, ItemLocation, slot)
			if ok and loc then
				local okG, guid = pcall(C_Item.GetItemGUID, loc)
				if okG and guid then out[#out + 1] = guid end
			end
		end
	end
	return out
end

-- "Linen Bag" twice is ambiguous; the second becomes "Linen Bag (3)" using
-- the bag slot number, which matches what the player sees on the bag bar.
local function disambiguate(list)
	local count = {}
	for _, bag in ipairs(list) do
		local info = ns.bagInfo[bag]
		if info and info.size > 0 then count[info.name] = (count[info.name] or 0) + 1 end
	end
	for _, bag in ipairs(list) do
		local info = ns.bagInfo[bag]
		-- "Default" is the bank's own slots wherever they live; it is one place, not a duplicate.
		if info and (count[info.name] or 0) > 1 and bag ~= ns.BACKPACK and bag ~= ns.BANK and info.name ~= "Default" then
			local slotNo = ns:IsBankBag(bag) and (bag - ns.NUM_BAGS) or bag
			info.name = ("%s (%d)"):format(info.name, slotNo)
		end
	end
end

local function scanBags(list, now, into, seenGuids, firstStamp)
	for _, bag in ipairs(list) do
		local size = bagSize(bag)
		local free, family = 0, 0
		if size > 0 then
			free, family = C_Container.GetContainerNumFreeSlots(bag)
			free, family = free or 0, family or 0
			if family == 0 and ns:IsReagentBag(bag) then family = 0x80000 end
		end
		ns.bagInfo[bag] = { size = size, free = free, family = family, name = ns:BagName(bag) }
	end
	disambiguate(list)
	-- Forever keeps the bank's real slots in a placeholder tab (named Default
	-- above) and also exposes an older, empty bank container. When both exist
	-- and the old one is empty, ignore it: no window, no Where entry, and not
	-- counted in free slots.
	local legacy = ns.bagInfo[ns.BANK]
	if legacy and legacy.size > 0 and legacy.free >= legacy.size then
		for _, bag in ipairs(list) do
			local info = ns.bagInfo[bag]
			if bag ~= ns.BANK and info and info.size > 0 and info.name == "Default" then
				legacy.size, legacy.free, legacy.hiddenLegacy = 0, 0, true
				break
			end
		end
	end
	for index, bag in ipairs(list) do
		local size = ns.bagInfo[bag].size
		if ns.Buttons and ns.Buttons.created then
			ns.bagInfo[bag].pendingGrow = not ns.Buttons:EnsureCapacity(bag, size) or nil
		end
		for slot = 1, size do
			local rec = readSlot(bag, slot, now, index, firstStamp)
			if rec then
				into[#into + 1] = rec
				if rec.guid then seenGuids[rec.guid] = true end
			end
		end
	end
end

function ns:Scan()
	ns.rescanPending = nil
	-- The last scan's stacks (for the bank's settle windows, below).
	local prevBags, prevBank, prevAtBank = ns.items or {}, ns.bankItems or {}, ns.lastScanAtBank
	-- Which slots hold gear set items, read fresh before the records are made.
	if ns.GearSets then ns.GearSets:Rebuild(); ns.GearSets.dirty = false end
	local now, seen = time(), {}
	ns.pendingInfo = false
	-- Recent lists what came from outside (loot, vendors, mail, trades, quests,
	-- crafting). Anything first seen in the bank or on your character was
	-- already yours, so its first-seen time is the session's start, which
	-- Recent never includes.
	local since = ns.cdb and ns.cdb.recentSince
	local owned = (since and since > 0) and math.min(now, since) or now
	local items = {}
	scanBags(ns.BAGS, now, items, seen)
	local bankNow
	if ns.atBank then bankNow = {}; scanBags(ns.BANK_BAGS, now, bankNow, seen, owned) end
	-- A stack that just appeared while another stack of the same item shrank by
	-- the same amount is a split, not new loot: it keeps the source's age
	-- (bags or bank).
	if ns.cdb then
		local pool = {}
		for _, r in ipairs(items) do pool[#pool + 1] = r end
		for _, r in ipairs(bankNow or {}) do pool[#pool + 1] = r end
		for _, rec in ipairs(pool) do
			if rec.freshStamp and rec.guid then
				for _, other in ipairs(pool) do
					local prev = other.guid and ns.lastCounts[other.guid]
					if other ~= rec and other.itemID == rec.itemID and prev and prev - other.count == rec.count and other.firstSeen then
						ns.cdb.firstSeen[rec.guid] = other.firstSeen
						rec.firstSeen = other.firstSeen
						break
					end
				end
				-- (first seen just now, no source found yet: see the bank's settle windows below)
				if rec.firstSeen == now then rec.stampedNow = true end
			end
			rec.freshStamp = nil
		end
	end
	ns.items = items
	-- Bank items count as still owned while away from the bank: this
	-- session's bank scan if there was one, else the saved bank (an old saved
	-- bank without item IDs can't vouch for them, so nothing is tidied away
	-- until the bank is visited; otherwise every bank item's age would reset).
	local bankUnknown = false
	if ns.atBank then
		ns.bankItems = bankNow
		ns.bankScanned = true
	elseif ns.bankScanned then
		for _, rec in ipairs(ns.bankItems) do if rec.guid then seen[rec.guid] = true end end
	else
		local saved = ns:SavedBank()
		local vouched = false
		for _, rec in ipairs(saved or {}) do if rec.guid then seen[rec.guid] = true; vouched = true end end
		if saved and #saved > 0 and not vouched then bankUnknown = true end
	end
	-- What you're wearing: its items keep their first-seen times while worn
	-- (taking one off isn't new), and a piece first seen on you was yours already.
	if ns.cdb then
		for _, guid in ipairs(ns.WornGuids()) do
			seen[guid] = true
			if not ns.cdb.firstSeen[guid] then ns.cdb.firstSeen[guid] = owned end
		end
	end
	-- A stack that grew is newly gained (a fresh age, and the green dot) only
	-- when you now hold more of that item than at the last scan: combining
	-- stacks, or moving some from the bank onto a stack in your bags, isn't.
	local totals = {}
	for _, list in ipairs({ items, ns.bankItems or {} }) do
		for _, r in ipairs(list) do if r.itemID then totals[r.itemID] = (totals[r.itemID] or 0) + (r.count or 1) end end
	end
	local before = ns.lastTotals
	-- At the bank, your bags and the bank update a frame apart, so a move can
	-- look like more (or less) of an item for a moment. There, the first change
	-- to an item you already held opens a settle window for that item, which
	-- remembers every stack's count (bags and bank) from just before. Each
	-- further change keeps it open; after a quiet second it closes and each
	-- stack's change is judged: losses are matched to gains (exact amounts
	-- first), a covered gain is a move (a new stack takes its source's age),
	-- and only a bag stack's uncovered gain is new (loot never lands in the
	-- bank). Away from the bank, decided at once as before.
	local clock = GetTime()
	local SETTLE = ns.SETTLE or 1
	ns.settleWins = ns.settleWins or {}
	local wins = ns.settleWins
	local bankList = bankNow or ns.bankItems or {}
	local function keyOf(r) return r.guid or slotKey(r.bag, r.slot) end
	local function snapshot(bagList, bankStacks, id)
		local out = {}
		for i, list in ipairs({ bagList, bankStacks }) do
			for _, r in ipairs(list) do
				if r.itemID == id then out[keyOf(r)] = { count = r.count or 1, firstSeen = r.firstSeen, bank = (i == 2) } end
			end
		end
		return out
	end
	local function oldestIn(snap)
		local o
		for _, v in pairs(snap) do if v.firstSeen and v.firstSeen < now and (not o or v.firstSeen < o) then o = v.firstSeen end end
		return o
	end
	local function queueSettle()
		C_Timer.After(SETTLE + 0.1, function() ns.rescanPending = true; ns:NextFrame("scan", function() ns:Scan() end) end)
	end
	-- Which held items changed since the last scan (at the bank, seen both times).
	if ns.atBank and prevAtBank and before then
		local nowC, prevC = {}, {}
		for _, list in ipairs({ items, bankList }) do for _, r in ipairs(list) do if r.itemID then nowC[keyOf(r)] = { id = r.itemID, c = r.count or 1 } end end end
		for _, list in ipairs({ prevBags, prevBank }) do for _, r in ipairs(list) do if r.itemID then prevC[keyOf(r)] = { id = r.itemID, c = r.count or 1 } end end end
		local changed = {}
		for k, v in pairs(nowC) do
			local p = prevC[k]
			if not p or p.id ~= v.id or p.c ~= v.c then changed[v.id] = true; if p and p.id ~= v.id then changed[p.id] = true end end
		end
		for k, p in pairs(prevC) do if not nowC[k] then changed[p.id] = true end end
		for id in pairs(changed) do
			if (before[id] or 0) > 0 then
				if not wins[id] then wins[id] = { s0 = snapshot(prevBags, prevBank, id), gainAt = {} } end
				wins[id].last = clock
				queueSettle()
			end
		end
	end
	-- Stacks of an item with an open window: nothing is new yet.
	for _, list in ipairs({ items, bankNow or {} }) do
		for _, rec in ipairs(list) do
			local w = rec.itemID and wins[rec.itemID]
			if w then
				local key = keyOf(rec)
				if rec.grewFrom or (rec.stampedNow and not w.s0[key]) then w.gainAt[key] = w.gainAt[key] or now end
				rec.grewFrom = nil
				if rec.stampedNow and rec.guid and ns.cdb then
					local older = oldestIn(w.s0) or owned   -- your other stacks' age, for now
					ns.cdb.firstSeen[rec.guid] = older; rec.firstSeen = older
				end
			elseif rec.grewFrom then
				rec.grewFrom = nil
				if not before or (totals[rec.itemID] or 0) > (before[rec.itemID] or 0) then
					if rec.guid and ns.cdb then ns.cdb.firstSeen[rec.guid] = now; rec.firstSeen = now end
					rec.isNew = isNew(rec.bag, rec.slot, rec.guid, rec.count, rec.itemID, true)
				end
			end
			rec.stampedNow = nil
		end
	end
	-- Windows whose quiet second is up: judge each stack.
	for id, w in pairs(wins) do
		if clock - (w.last or 0) >= SETTLE then
			wins[id] = nil
			local s1 = snapshot(items, bankList, id)
			local recs = {}
			for _, list in ipairs({ items, bankList }) do for _, r in ipairs(list) do if r.itemID == id then recs[keyOf(r)] = r end end end
			local gains, losses = {}, {}
			for k, v in pairs(s1) do
				local d = v.count - ((w.s0[k] and w.s0[k].count) or 0)
				if d > 0 then gains[#gains + 1] = { key = k, amt = d, left = d, bank = v.bank, newStack = not w.s0[k], at = w.gainAt[k] or now } end
			end
			for k, v in pairs(w.s0) do
				local d = ((s1[k] and s1[k].count) or 0) - v.count
				if d < 0 then losses[#losses + 1] = { key = k, amt = -d, left = -d, firstSeen = v.firstSeen } end
			end
			table.sort(gains, function(x, y)
				if x.bank ~= y.bank then return x.bank end     -- bank gains are covered first
				if x.at ~= y.at then return x.at < y.at end
				return x.key < y.key
			end)
			table.sort(losses, function(x, y) return x.key < y.key end)
			-- Exact amounts first (bank -7, bag +7), then the rest.
			for _, g in ipairs(gains) do
				for _, l in ipairs(losses) do
					if l.left == l.amt and l.amt == g.amt then l.left, g.left, g.from = 0, 0, l.firstSeen; break end
				end
			end
			for _, g in ipairs(gains) do
				for _, l in ipairs(losses) do
					if g.left <= 0 then break end
					if l.left > 0 then
						local take = math.min(g.left, l.left)
						g.left, l.left = g.left - take, l.left - take
						g.from = g.from or l.firstSeen
					end
				end
			end
			local fallback = oldestIn(w.s0) or owned
			for _, g in ipairs(gains) do
				local r = recs[g.key]
				if r then
					if g.left > 0 and not g.bank then
						-- (some of) this stack's gain came from outside: new
						if r.guid and ns.cdb then ns.cdb.firstSeen[r.guid] = g.at; r.firstSeen = g.at end
						r.isNew = isNew(r.bag, r.slot, r.guid, r.count, r.itemID, true)
					elseif g.newStack and r.guid and ns.cdb then
						local age = g.from or fallback   -- moved or split: its source's age
						ns.cdb.firstSeen[r.guid] = age; r.firstSeen = age
					end
				end
			end
		end
	end
	ns.lastTotals = totals
	ns.lastScanAtBank = ns.atBank and true or false
	-- Prune timestamps for items that are gone, but never right after login
	-- (the client may not have handed over bag contents yet) and never from
	-- a scan that saw nothing at all; otherwise every age resets each session.
	ns.loginTime = ns.loginTime or now
	local settled = (now - ns.loginTime) > 15 and #items > 0 and not bankUnknown
	if ns.cdb and settled then
		for guid in pairs(ns.cdb.firstSeen) do if not seen[guid] then ns.cdb.firstSeen[guid] = nil end end
		for guid in pairs(ns.cdb.seen) do if not seen[guid] then ns.cdb.seen[guid] = nil end end
	end
	local live = {}
	for _, rec in ipairs(items) do live[rec.guid or slotKey(rec.bag, rec.slot)] = rec end
	for _, rec in ipairs(ns.bankItems) do live[rec.guid or slotKey(rec.bag, rec.slot)] = rec end
	for key in pairs(ns.lastCounts) do if not live[key] then ns.lastCounts[key] = nil; ns.newFlags[key] = nil end end
	for key, rec in pairs(live) do ns.lastCounts[key] = rec.count end
	if ns.cdb then
		-- Forget slot memory once the slot holds a different item (or nothing).
		local bySlot = {}
		for _, rec in ipairs(items) do bySlot[slotKey(rec.bag, rec.slot)] = rec.itemID end
		for _, rec in ipairs(ns.bankItems) do bySlot[slotKey(rec.bag, rec.slot)] = rec.itemID end
		for k, v in pairs(ns.cdb.seenSlots) do
			local sid = v:match("^(%d+):")
			if not bySlot[k] or tonumber(sid) ~= bySlot[k] then ns.cdb.seenSlots[k] = nil end
		end
	end
	ns:ScheduleCacheSave()
	-- Recount token items before the windows redraw (they read the totals).
	if ns.Currency then ns.Currency:Invalidate() end
	ns:Fire("ITEMS_CHANGED")
	return items
end

-- This character's bank as last saved (for use before the bank is visited
-- this session), or nil.
function ns:SavedBank()
	local entry = BagSmithDB and BagSmithDB.cache and BagSmithDB.cache[ns:CharKey()]
	return entry and entry.bank or nil
end

-- Serialising every item on every bag event is wasted work during looting
-- or sorting; write the cache once things settle.
function ns:ScheduleCacheSave()
	if ns.cacheTimer then return end
	ns.cacheTimer = C_Timer.NewTimer(1.5, function() ns.cacheTimer = nil; ns:SaveCache() end)
end

function ns:FreeSlots(bags)
	local general, generalTotal, reagent, reagentTotal = 0, 0, 0, 0
	for _, bag in ipairs(bags or ns.BAGS) do
		local info = ns.bagInfo[bag]
		if info and bag ~= ns.KEYRING then
			if ns:IsReagentBag(bag) then reagent, reagentTotal = reagent + info.free, reagentTotal + info.size
			else general, generalTotal = general + info.free, generalTotal + info.size end
		end
	end
	return general, generalTotal, reagent, reagentTotal
end

------------------------------------------------------------------------
-- Character cache (for the alt viewer)
------------------------------------------------------------------------
local KEEP = { "bag", "slot", "bagIndex", "itemID", "link", "icon", "quality", "count", "name", "where", "ilvl", "minLevel",
	"itemType", "itemSubType", "equipLoc", "sellPrice", "classID", "subclassID", "bindType", "isBound", "hasNoValue", "cat", "firstSeen", "guid", "maxStack", "ownCat", "isQuest", "isCraftingReagent", "gearSets" }
local function serialize(list)
	local out = {}
	for i, rec in ipairs(list) do
		local s = {}
		for _, k in ipairs(KEEP) do s[k] = rec[k] end
		out[i] = s
	end
	return out
end

-- Is this cache entry the character we are playing? By key, or by name and
-- realm for entries saved under an older key.
function ns:IsOwnKey(key)
	if not key then return false end
	if key == ns:CharKey() then return true end
	local data = BagSmithDB and BagSmithDB.cache and BagSmithDB.cache[key]
	if not data then return false end
	local realm = GetRealmName()
	local myName = ns:DisplayName("player")
	return data.name == myName and (data.realm == realm or data.realm == "Unknown" or data.realm == nil)
end

-- (1.5.0-beta4) Gold and currencies as seen during play. On this client the game reports 0 gold and no currencies
-- while you log out, so the logout save uses what was seen during play instead, and never replaces a known amount
-- with 0 or an empty list. Gold spent down to 0 during play is recorded then (PLAYER_MONEY), so it's still saved.
function ns:NoteLiveMoney() local g = GetMoney and GetMoney(); if type(g) == "number" then ns.liveGold = g end end
-- (1.5.0-beta5, audit F3/F4) The wallet (the game's currency list) is tracked apart from token and tracked items,
-- which come from BagSmith's own scan and are always available. It's captured the moment it changes, while the
-- game's data is valid; a currency still listed at 0 is a real 0. A wallet with nothing listed at all is treated
-- as unavailable (the logout teardown) and never replaces the last good capture.
function ns:WalletPart(snap)
	local w = {}
	for k, e in pairs(snap or {}) do if e.source == "Wallet" then w[k] = e end end
	return w
end
function ns:NoteLiveWallet()
	if not ns.Currency then return end
	ns.Currency:Invalidate()
	ns.Currency:List()   -- (the rebuild replaces the capture when the list is readable; see walletList)
end
function ns:SaveCache(atLogout)
	if not BagSmithDB or not BagSmithDB.cache then return end
	-- Right after login the realm can still be missing; saving then would
	-- create a second, stale entry for this character under "Unknown".
	local realm, name = GetRealmName(), UnitName("player")
	if not realm or realm == "" or not name or name == "" then return end
	local key = ns:CharKey()
	local entry = BagSmithDB.cache[key] or {}
	local _, class = UnitClass("player")
	entry.name = ns:DisplayName("player")
	entry.realm = GetRealmName() or "Unknown"
	entry.class = class
	entry.level = UnitLevel("player") or 0
	local nowGold = GetMoney and GetMoney() or 0
	if atLogout then
		-- trust a real amount; a 0 at logout keeps what play last saw (or the last save)
		if nowGold > 0 then entry.gold = nowGold else entry.gold = ns.liveGold or entry.gold or 0 end
	else
		entry.gold = nowGold
		ns.liveGold = nowGold
	end
	entry.updated = time()
	entry.bags = {}
	for _, bag in ipairs(ns.BAGS) do
		local info = ns.bagInfo[bag]
		if info then entry.bags[tostring(bag)] = { size = info.size, free = info.free, name = info.name, reagent = ns:IsReagentBag(bag) or nil } end
	end
	entry.items = serialize(ns.items)
	if ns.atBank then
		entry.bankBags = {}
		for _, bag in ipairs(ns.BANK_BAGS) do
			local info = ns.bagInfo[bag]
			if info then entry.bankBags[tostring(bag)] = { size = info.size, free = info.free, name = info.name } end
		end
		entry.bank = serialize(ns.bankItems)
	end
	if ns.Currency then
		-- (1.5.0 production, audit G4/G5/P3; rebuild audit G7) Every save, during play and at logout, takes the wallet
		-- from the last good capture (when there is one) rather than from the displayed list: the capture carries over
		-- a currency the game isn't answering for yet, which the list leaves out, so a routine save can't forget it;
		-- at logout it also means teardown zeros can't be saved and a currency that's really gone doesn't come back.
		-- Item-based entries (tokens, tracked items) come from BagSmith's own scan. With no capture this session, the
		-- current wallet is used, or the last save's when the current one is empty (unavailable). Every entry is put
		-- in its saved shape after all of that.
		local snap = ns.Currency:Snapshot()   -- (this may also refresh the capture, so it comes first)
		local out = {}
		for k, e in pairs(snap) do if e.source ~= "Wallet" then out[k] = e end end
		local wallet = ns.liveWallet
		if wallet == nil then
			wallet = ns:WalletPart(snap)
			if not next(wallet) then wallet = ns:WalletPart(entry.currencies) end
		end
		for k, e in pairs(wallet) do out[k] = e end
		if atLogout and not next(out) and ns.liveWallet == nil then out = ns.liveCurrencies or entry.currencies or out end
		snap = {}
		for k, e in pairs(out) do snap[k] = ns.Currency:SavedEntry(e) end
		if not atLogout then ns.liveCurrencies = snap end
		entry.currencies = snap
	end
	BagSmithDB.cache[key] = entry
end

-- Returns a list of cached characters, own character first.
function ns:CachedCharacters()
	local me, list = ns:CharKey(), {}
	-- Drop stale copies of the current character saved under another key.
	for key in pairs(BagSmithDB.cache or {}) do
		if key ~= me and ns:IsOwnKey(key) then BagSmithDB.cache[key] = nil end
	end
	for key, data in pairs(BagSmithDB.cache or {}) do
		list[#list + 1] = { key = key, name = data.name, realm = data.realm, class = data.class, level = data.level, isMe = key == me }
	end
	table.sort(list, function(a, b)
		if a.isMe ~= b.isMe then return a.isMe end
		return (a.name or "") < (b.name or "")
	end)
	return list
end

-- Deserialise a cached character into records with the same shape as live ones.
function ns:CachedRecords(key, bank)
	local data = BagSmithDB.cache and BagSmithDB.cache[key]
	if not data then return {}, {} end
	local src
	if bank then src = data.bank or {} else src = data.items end
	local out = {}
	for i, s in ipairs(src or {}) do
		local rec = {}
		for k, v in pairs(s) do rec[k] = v end
		rec.count = rec.count or 1
		rec.quality = rec.quality or 1
		rec.name = rec.name or "?"
		-- The section comes from the current profile on every read: the item's own
		-- category (saved, or worked out again for older saves), then this
		-- profile's moves. A saved "Junk" (that character's marks) stays.
		local savedJunk = rec.cat == "Junk"
		rec.ownCat = (ns.Sections and ns.Sections:OwnCategory(rec)) or rec.ownCat or ns:Categorize(rec)
		if savedJunk then rec.cat = "Junk"
		elseif ns.Sections then rec.cat = ns.Sections:Apply(rec, rec.ownCat)
		else rec.cat = rec.ownCat end
		-- Gear sets as saved (a list of names), nothing else.
		if rec.gearSets ~= nil then
			local names = {}
			if type(rec.gearSets) == "table" then for _, n in ipairs(rec.gearSets) do if type(n) == "string" and n ~= "" then names[#names + 1] = n end end end
			rec.gearSets = #names > 0 and names or nil
		end
		rec.cached = true
		out[i] = rec
	end
	-- Explicitly the bank's or the bags' details: a bank never visited has
	-- none (it used to fall back to the bags' and show their slot count).
	local bagsInfo = {}
	local info
	if bank then info = data.bankBags else info = data.bags end
	for k, v in pairs(info or {}) do bagsInfo[tonumber(k)] = v end
	return out, bagsInfo, data
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local function rescan() ns.rescanPending = true; ns:NextFrame("scan", function() ns:Scan() end) end

function ns:UpdateLock(bag, slot)
	if not bag or not slot then return end
	local info = C_Container.GetContainerItemInfo(bag, slot)
	local locked = info and info.isLocked or false
	for _, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
		for _, r in ipairs(list) do if r.bag == bag and r.slot == slot then r.isLocked = locked end end
	end
	local b = ns.Buttons and ns.Buttons:Get(bag, slot)
	if b and b:IsShown() then
		if b.secure then SetItemButtonDesaturated(b, locked) elseif b.icon then b.icon:SetDesaturated(locked) end
	end
	-- The Recent section's copy of the same slot dims with it.
	for _, c in ipairs(ns.Buttons and ns.Buttons.recent or {}) do
		if c:IsShown() and c.smithBag == bag and c:GetID() == slot then SetItemButtonDesaturated(c, locked) end
	end
	for _, pool in pairs(ns.Buttons and ns.Buttons.mirrors or {}) do
		for _, c in pairs(pool) do if c:IsShown() and c.bag == bag and c:GetID() == slot and c.icon then c.icon:SetDesaturated(locked) end end
	end
end

-- Recent items: first seen after the session began (or after Clear Recent),
-- newest first. "Session" starts at login and survives a /reload; see Window.
-- Items stamped by the first scan of a session (everything BagSmith hadn't
-- seen yet) are not recent: the boundary is set just after that scan.
local RECENT_WINDOW = { session = nil, ["1h"] = 3600, ["15m"] = 900 }
function ns:RecentRecords(records)
	local since = ns.cdb and ns.cdb.recentSince
	if not since or since == 0 then return {} end
	local span = RECENT_WINDOW[ns.db.recentWindow]
	local limit = since
	if span then limit = math.max(since, time() - span) end
	-- Merged rows are sticky: once an item is in Recent this session, its
	-- merged row stays while you still have any of it, even after the new
	-- stack is used up (it remembers when it was last recent). It leaves when
	-- the item is gone entirely, its time falls outside the window, or on
	-- Clear Recent. Separate stacks (Merge Stacks off) aren't sticky.
	local sticky = ns.cdb.recentSticky
	if type(sticky) ~= "table" then sticky = {}; ns.cdb.recentSticky = sticky end
	local function key(r) return tostring(r.itemID) .. ":" .. tostring(r.quality or 0) end
	local held = {}
	for _, r in ipairs(ns.items or {}) do if r.itemID then held[key(r)] = true end end
	for k in pairs(sticky) do if not held[k] then sticky[k] = nil end end   -- gone entirely
	local when = {}
	local out = {}
	for _, r in ipairs(records or {}) do
		if not r.empty and r.firstSeen then
			local t = r.firstSeen
			if r.merged and r.itemID then
				local k = key(r)
				if t > limit then sticky[k] = math.max(sticky[k] or 0, t) end
				t = math.max(t, sticky[k] or 0)
			end
			if t > limit then out[#out + 1] = r; when[r] = t end
		end
	end
	table.sort(out, function(a, b)
		if when[a] ~= when[b] then return when[a] > when[b] end
		return (a.name or "") < (b.name or "")
	end)
	local cap = ns.db.recentMax or 0
	if cap > 0 then for i = #out, cap + 1, -1 do out[i] = nil end end
	return out
end
function ns:StartRecentSession(isInitialLogin)
	if not ns.cdb then return end
	if isInitialLogin or not ns.cdb.recentSince or ns.cdb.recentSince == 0 then ns.cdb.recentSince = time(); ns.cdb.recentSticky = {} end
end
function ns:ClearRecent()
	if ns.cdb then ns.cdb.recentSince = time(); ns.cdb.recentSticky = {} end
	-- When this clear also clears the green dots, a bank settle window
	-- measures from now on: anything gained before the clear never becomes
	-- new; anything after still does. (Without that option, Clear Recent
	-- leaves dots alone, so a pending gain still gets its dot, as it would
	-- away from the bank; it's out of Recent either way.)
	local clearsDots = ns.db and ns.db.newdot and ns.db.newdotClearRecent
	for id, w in pairs(clearsDots and ns.settleWins or {}) do
		local snap = {}
		for i, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
			for _, r in ipairs(list) do
				if r.itemID == id then snap[r.guid or slotKey(r.bag, r.slot)] = { count = r.count or 1, firstSeen = r.firstSeen, bank = (i == 2) } end
			end
		end
		w.s0, w.gainAt = snap, {}
	end
	-- With the green dots on, Clear Recent can clear them too (as hovering would).
	if ns.db and ns.db.newdot and ns.db.newdotClearRecent then
		for _, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
			for _, rec in ipairs(list) do if rec.isNew then ns:DismissNew(rec) end end
		end
	end
	ns:RefreshViews(true)
end

ns:OnSignal("ADDON_READY", function()
	ns:On("BAG_UPDATE_DELAYED", rescan)
	ns:On("BAG_CONTAINER_UPDATE", rescan)
	ns:On("PLAYER_EQUIPMENT_CHANGED", rescan)
	-- A lock only changes how an item looks (dimmed while it moves). Update
	-- that in place; rebuilding the list here moved rows under the pointer
	-- mid-click and dropped the click.
	ns:On("ITEM_LOCK_CHANGED", function(bag, slot) ns:UpdateLock(bag, slot) end)
	ns:On("BAG_NEW_ITEMS_UPDATED", rescan)
	ns:On("PLAYER_ENTERING_WORLD", rescan)
	ns:On("PLAYER_LOGOUT", function()
		if ns.cacheTimer then ns.cacheTimer:Cancel(); ns.cacheTimer = nil end
		ns.loggingOut = true   -- (1.5.0-beta14) the wallet's last good capture isn't replaced from here on
		ns:SaveCache(true)
	end)
	ns:On("PLAYER_MONEY", function() ns:NoteLiveMoney(); ns:ScheduleCacheSave(); ns:Fire("MONEY_CHANGED") end)
	ns:On("GET_ITEM_INFO_RECEIVED", function() if ns.pendingInfo then rescan() end end)
	ns:On("BANKFRAME_OPENED", function() ns.atBank = true; ns:Scan(); ns:Fire("BANK_OPENED") end)
	-- Saving waits 1.5 s to batch changes, and only includes the bank while
	-- it's open: save now, before leaving, so a last-second change is kept.
	ns:On("BANKFRAME_CLOSED", function()
		if ns.atBank then
			-- A rescan still waiting would leave the save a step behind: scan now.
			if ns.rescanPending then pcall(ns.Scan, ns) end
			if ns.cacheTimer then ns.cacheTimer:Cancel(); ns.cacheTimer = nil end
			ns:SaveCache()
		end
		ns.atBank = false; ns:Fire("BANK_CLOSED")
	end)
	ns:On("PLAYERBANKSLOTS_CHANGED", rescan)
	ns:On("PLAYERBANKBAGSLOTS_CHANGED", rescan)
	if ns.KEYRING then ns:On("KEYRING_UPDATE", rescan) end
end)
