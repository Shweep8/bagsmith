--[[
	BagSmith - Core/Currency.lua
	Wallet currencies (C_CurrencyInfo) plus token items counted from bags and
	bank, with a favorites list stored in the profile.
	Keys: "c:<currencyID>" for wallet entries, "i:<itemID>" for token items.
--]]

local ADDON, ns = ...
local Currency = {}
ns.Currency = Currency

-- (1.5.0-beta11) Currencies BagSmith knows of: seen in the list this session, your favorites, and this character's
-- last save.
Currency.known, Currency.lastSeen = {}, {}
function Currency:KnownIDs()
	local ids = {}
	for id in pairs(self.known) do ids[id] = true end
	for _, key in ipairs((ns.db and ns.db.fav) or {}) do local id = tonumber(tostring(key):match("^c:(%d+)$")); if id then ids[id] = true end end
	local cache = _G.BagSmithDB and BagSmithDB.cache
	local entry = cache and ns.CharKey and cache[ns:CharKey()]
	for key in pairs((entry and entry.currencies) or {}) do local id = tonumber(tostring(key):match("^c:(%d+)$")); if id then ids[id] = true end end
	-- (1.5.0, rebuild audit G7) and every currency in the last good capture, so a currency the game isn't answering
	-- for yet keeps being asked about (a save can't make BagSmith forget it)
	for key in pairs(ns.liveWallet or {}) do local id = tonumber(tostring(key):match("^c:(%d+)$")); if id then ids[id] = true end end
	return ids
end
local function walletList()
	local out = {}
	if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize) then return out end
	-- Only the currencies visible in the wallet list are read. Expanding
	-- collapsed headers from an addon fires CURRENCY_DISPLAY_UPDATE, which
	-- would trigger another read: an easy way to spin forever.
	local n = C_CurrencyInfo.GetCurrencyListSize()
	local listed, anyCollapsed, rows = {}, false, 0
	local unavailable = {}   -- (1.5.0 production, audit G5) known currencies the game gave no answer for this time
	for idx = 1, n do
		local info = C_CurrencyInfo.GetCurrencyListInfo(idx)
		-- (a header that isn't known to be expanded may be hiding currencies)
		if info and info.isHeader and info.isHeaderExpanded ~= true then anyCollapsed = true end
		if info and not info.isHeader and info.name then
			local id
			if C_CurrencyInfo.GetCurrencyListLink and C_CurrencyInfo.GetCurrencyIDFromLink then
				local link = C_CurrencyInfo.GetCurrencyListLink(idx)
				id = link and C_CurrencyInfo.GetCurrencyIDFromLink(link)
			end
			id = id or info.currencyID
			if id then
				out[#out + 1] = { key = "c:" .. id, id = id, name = info.name, icon = info.iconFileID,
					count = info.quantity or 0, quality = info.quality or 1, source = "Wallet" }
				rows = rows + 1
				listed[id] = true
				Currency.known[id] = true
				Currency.lastSeen[id] = out[#out]
			end
		end
	end
	-- (1.5.0-beta11, audit F4) A collapsed header hides its currencies from the list, though you still have them.
	-- Every currency BagSmith knows of (seen this session, a favorite, or in this character's last save) that the
	-- list doesn't show is asked for by its ID, which doesn't depend on headers (and fires no events). Only while the
	-- list is readable: an empty list (the logout teardown) stays "unavailable", so the logout rule keeps the last
	-- good capture instead of zeros.
	-- A currency the game no longer has is dropped: the lookup says it isn't discovered, or every header is open and
	-- the lookup finds nothing (1.5.1-beta1, G8: under a collapsed header no answer only means unavailable).
	-- Where a client can't look a currency up by its ID, a missing currency keeps the balance last seen this session
	-- only while some header is collapsed (or doesn't say), since that's what can hide it; with every header open, a
	-- missing currency really is gone. (Its balance may be out of date until its header is opened again.)
	if n > 0 then
		local lookup = C_CurrencyInfo.GetCurrencyInfo
		for id in pairs(Currency:KnownIDs()) do
			if not listed[id] then
				local info = lookup and lookup(id)
				if lookup then
					if info and info.discovered == false then
						-- the game says it isn't discovered: gone (even if it was the last one)
					elseif info and info.name and info.name ~= "" then
						out[#out + 1] = { key = "c:" .. id, id = id, name = info.name, icon = info.iconFileID,
							count = info.quantity or 0, quality = info.quality or 1, source = "Wallet", byId = true }
						listed[id] = true
						-- (1.5.0-beta13, audit G2) remembered for the session like a currency seen in the list, so it
						-- stays in Wallet when the pin that led to it goes away (unpinning, or another profile)
						Currency.known[id] = true
						Currency.lastSeen[id] = out[#out]
					elseif rows == 0 or anyCollapsed then
						-- (1.5.1-beta1, third-build audit G8) no answer (nil, or a blank name) is unavailable, not gone,
						-- when the list shows no currency rows or some header is collapsed (or doesn't say): another
						-- visible row doesn't prove this one is gone, since a collapsed header may be hiding it. Its
						-- last value carries over and it keeps being asked about. With every header open, it's gone.
						unavailable[id] = true
					end
				elseif anyCollapsed and Currency.lastSeen[id] then
					local e = Currency.lastSeen[id]
					out[#out + 1] = { key = e.key, id = e.id, name = e.name, icon = e.icon, count = e.count, quality = e.quality, source = "Wallet" }
					listed[id] = true
				elseif rows == 0 then
					unavailable[id] = true
				end
			end
		end
	end
	-- (1.5.0-beta14, audit G3) A readable wallet (the list has rows), including currencies found by ID, also becomes
	-- the last good capture the logout save falls back on, so a balance that's only been displayed (an import) isn't
	-- lost if the list empties before logout. Replaced as a whole, never merged with older captures, so a removed
	-- currency doesn't come back; an empty list (n == 0) never replaces it; a real 0 stays 0.
	-- (During logout nothing replaces the capture: the game's data is being torn down.)
	-- (1.5.0 production, audit G5) The capture is replaced on every readable build, even when it comes out empty, so
	-- a currency that's really gone stays gone (the last one included). "Gone" means the game said so (not
	-- discovered), or the list shows currency rows under headers that are all open and it isn't among them or found
	-- by ID. A known currency the game gave no answer for while the list shows no currency rows, or while some
	-- header is collapsed (1.5.1-beta1, G8), is unavailable, not gone: its previous captured value carries over.
	-- (1.5.0, release audit G6) Before this session's first capture, the previous value of a currency the game gives
	-- no answer for comes from this character's last save (only for those currencies: not a merge of saved history,
	-- and never for one the game reports gone), so an unanswered first read can't erase a saved balance at logout.
	if n > 0 and not ns.loggingOut then
		local capture, old = {}, ns.liveWallet or Currency:SavedWallet()
		for _, e in ipairs(out) do capture[e.key] = e end
		for id in pairs(unavailable) do local k = "c:" .. id; if old[k] and not capture[k] then capture[k] = old[k] end end
		ns.liveWallet = capture
	end
	return out
end

local function tokenItems(items, bankItems)
	local byId, out = {}, {}
	local function add(rec, src)
		-- Its own category (older saved banks worked out the same way as saved
		-- views), never the section it was moved to.
		local own = rec.ownCat or (ns.Sections and ns.Sections:OwnCategory(rec)) or rec.cat
		if own ~= "Tokens" then return end
		local e = byId[rec.itemID]
		if not e then
			e = { key = "i:" .. rec.itemID, id = rec.itemID, name = rec.name, icon = rec.icon, count = 0, quality = rec.quality, source = src }
			byId[rec.itemID] = e
			out[#out + 1] = e
		end
		e.count = e.count + (rec.count or 1)
		if src ~= e.source then e.source = "Bags and bank" end
	end
	for _, rec in ipairs(items or {}) do add(rec, "Bags") end
	for _, rec in ipairs(bankItems or {}) do add(rec, "Bank") end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

-- Items tracked as currencies (Track as Currency, in the profile): counted in
-- your bags and bank, and listed even at 0, so nothing custom is forgotten.
function Currency:Tracked(bank, have)
	local out = {}
	for _, id in ipairs((ns.db and ns.db.customCurrencies) or {}) do
		local key = "i:" .. id
		if not (have and have[key]) then
			local e = { key = key, id = id, count = 0, custom = true, source = "Bags and bank" }
			for _, l in ipairs({ ns.items or {}, bank or {} }) do
				for _, r in ipairs(l) do
					if r.itemID == id then e.count = e.count + (r.count or 1); e.name = e.name or r.name; e.icon = e.icon or r.icon; e.quality = e.quality or r.quality end
				end
			end
			if not e.name and C_Item and C_Item.GetItemInfo then
				local name, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
				e.name, e.quality, e.icon = name, e.quality or quality, e.icon or icon
				if not name and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
			end
			if not e.icon and C_Item and C_Item.GetItemIconByID then e.icon = C_Item.GetItemIconByID(id) end
			e.name = e.name or ("Item " .. id)
			e.quality = e.quality or 1
			out[#out + 1] = e
		end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

-- The wallet list is cached until a currency or bag event invalidates it.
local listCache
function Currency:Invalidate() listCache = nil end

-- Full list for the drawer: live character or a cached one.
function Currency:List(owner)
	if owner then
		local data = BagSmithDB.cache[owner]
		local out = {}
		for key, e in pairs(data and data.currencies or {}) do
			out[#out + 1] = { key = key, id = e.id, name = e.name, icon = e.icon, count = e.count, quality = e.quality, source = e.source }
		end
		table.sort(out, function(a, b) return a.name < b.name end)
		return out
	end
	if listCache then return listCache end
	local out = walletList()
	-- Bank tokens: this session's bank scan, or the saved bank until then.
	local bank = ns.bankScanned and ns.bankItems or ns:SavedBank() or {}
	local have = {}
	for _, e in ipairs(tokenItems(ns.items, bank)) do out[#out + 1] = e; have[e.key] = true end
	-- Items tracked as currencies: always listed, even when you have none.
	for _, e in ipairs(self:Tracked(bank, have)) do out[#out + 1] = e end
	listCache = out
	return out
end

-- This character's wallet currencies as last saved (keys "c:<id>"), for G6's carry-over.
function Currency:SavedWallet()
	local cache = _G.BagSmithDB and BagSmithDB.cache
	local entry = cache and ns.CharKey and cache[ns:CharKey()]
	local out = {}
	for k, e in pairs((entry and entry.currencies) or {}) do
		if type(k) == "string" and k:match("^c:%d+$") and type(e) == "table" then out[k] = e end
	end
	return out
end
-- The saved shape of an entry (no working marks such as byId).
function Currency:SavedEntry(e)
	return { id = e.id, name = e.name, icon = e.icon, count = e.count, quality = e.quality, source = e.source }
end
function Currency:Snapshot()
	local snap = {}
	for _, e in ipairs(self:List()) do snap[e.key] = self:SavedEntry(e) end
	return snap
end

function Currency:Favorites(owner)
	local all, byKey, out = self:List(owner), {}, {}
	for _, e in ipairs(all) do byKey[e.key] = e end
	for _, key in ipairs(ns.db.fav) do
		local e = byKey[key]
		if e then out[#out + 1] = e end
	end
	return out, all
end

function Currency:IsFavorite(key) return ns.IndexOf(ns.db.fav, key) ~= nil end
function Currency:ToggleFavorite(key)
	local i = ns.IndexOf(ns.db.fav, key)
	if i then table.remove(ns.db.fav, i) else table.insert(ns.db.fav, key) end
	-- (1.5.0-beta12, audit G1) favorites tell the list which hidden currencies to look up by ID, so the cached list
	-- is cleared before anyone is told (a listener that redraws first must not read the old list)
	self:Invalidate()
	ns:Fire("SETTINGS_CHANGED", "fav")
end
function Currency:MoveFavorite(key, delta)
	local i = ns.IndexOf(ns.db.fav, key)
	if i and ns.Move(ns.db.fav, i, i + delta) then ns:Fire("SETTINGS_CHANGED", "fav") end
end

-- Import Blizzard's "show on backpack" picks.
function Currency:ImportBlizzard()
	local added = 0
	if C_CurrencyInfo and C_CurrencyInfo.GetBackpackCurrencyInfo then
		for i = 1, 20 do
			local info = C_CurrencyInfo.GetBackpackCurrencyInfo(i)
			if not info or not info.currencyTypesID then break end
			local key = "c:" .. info.currencyTypesID
			if not self:IsFavorite(key) then table.insert(ns.db.fav, key); added = added + 1 end
		end
	end
	if added > 0 then
		self:Invalidate()   -- (1.5.0-beta12, audit G1) before the notice, so the drawer's redraw shows the imports
		ns:Fire("SETTINGS_CHANGED", "fav")
	end
	return added
end

ns:OnSignal("ADDON_READY", function()
	-- (1.5.0-beta5, audit F4) capture the wallet now, while the game's data is valid; saving stays on its delay
	ns:On("CURRENCY_DISPLAY_UPDATE", function()
		if ns.NoteLiveWallet then ns:NoteLiveWallet() else Currency:Invalidate() end
		ns:NextFrame("currency", function() ns:ScheduleCacheSave(); ns:Fire("CURRENCY_CHANGED") end)
	end)
	ns:OnSignal("ITEMS_CHANGED", function() Currency:Invalidate() end)
	-- A profile change (or its tracked items changing): the list is rebuilt from that profile.
	ns:OnSignal("SETTINGS_CHANGED", function(key)
		if key == nil or key == "customCurrencies" or key == "marks" or key == "fav" then Currency:Invalidate() end
	end)
	-- A tracked item's name arriving from the game (it may never have been in your bags).
	ns:On("GET_ITEM_INFO_RECEIVED", function()
		if ns.db and #(ns.db.customCurrencies or {}) > 0 then
			Currency:Invalidate()
			if ns.Drawer and ns.Drawer.Refresh then ns.Drawer:Refresh() end
		end
	end)
end)
