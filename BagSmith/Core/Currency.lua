--[[
	BagSmith - Core/Currency.lua
	Wallet currencies (C_CurrencyInfo) plus token items counted from bags and
	bank, with a favorites list stored in the profile.
	Keys: "c:<currencyID>" for wallet entries, "i:<itemID>" for token items.
--]]

local ADDON, ns = ...
local Currency = {}
ns.Currency = Currency

local function walletList()
	local out = {}
	if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize) then return out end
	-- Only the currencies visible in the wallet list are read. Expanding
	-- collapsed headers from an addon fires CURRENCY_DISPLAY_UPDATE, which
	-- would trigger another read: an easy way to spin forever.
	local n = C_CurrencyInfo.GetCurrencyListSize()
	for idx = 1, n do
		local info = C_CurrencyInfo.GetCurrencyListInfo(idx)
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
			end
		end
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

function Currency:Snapshot()
	local snap = {}
	for _, e in ipairs(self:List()) do
		snap[e.key] = { id = e.id, name = e.name, icon = e.icon, count = e.count, quality = e.quality, source = e.source }
	end
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
	if added > 0 then ns:Fire("SETTINGS_CHANGED", "fav") end
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
		if key == nil or key == "customCurrencies" or key == "marks" then Currency:Invalidate() end
	end)
	-- A tracked item's name arriving from the game (it may never have been in your bags).
	ns:On("GET_ITEM_INFO_RECEIVED", function()
		if ns.db and #(ns.db.customCurrencies or {}) > 0 then
			Currency:Invalidate()
			if ns.Drawer and ns.Drawer.Refresh then ns.Drawer:Refresh() end
		end
	end)
end)
