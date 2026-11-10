--[[
	BagSmith - Core/AH.lua

	Auction house prices, for the optional "AH Price" column and the Loot and
	Disenchant Helpers, from Auctionator or (1.6.0) Blackthornes Tradeskills,
	each through its own public interface (see SOURCES below). Prices are per
	item, in copper; nil when the source has none. Neither offers a public
	"scan finished" notice, so the column refreshes when the auction house
	closes and on BagSmith's own refreshes.
--]]
local ADDON, ns = ...
local AH = {}
ns.AH = AH

local CALLER = "BagSmith"

-- (1.6.0) Price sources. Each is read only through its own public, supported interface, at the moment of use, so load
-- order never matters and a missing or misbehaving source just means "no price":
--   auctionator   Auctionator.API.v1 (Auctionator 340's own files); every call takes a caller ID and raises on bad
--                 arguments, so each is wrapped. Age is in days.
--   blackthornes  BlackthornesTS_API (Blackthornes Tradeskills' Logic/PublicAPI.lua, version 1, which its author made
--                 for other addons): GetPrice(item) in copper, GetPriceAge(item) in seconds since your own scan saw it;
--                 neither raises, but each call is wrapped all the same. Its price is its market value (your scans, then
--                 guild prices, then other price addons filling gaps); a price from those has no age.
-- Price Source (ns.db.priceSource): "auto" uses the first installed in ORDER (Auctionator first, so nobody's numbers
-- change on update); a chosen source that isn't installed falls back to the other rather than giving no prices.
local function auctionatorApi()
	local a = type(Auctionator) == "table" and type(Auctionator.API) == "table" and Auctionator.API.v1
	return type(a) == "table" and a or nil
end
local function aCall(name, ...)
	local a = auctionatorApi()
	local fn = a and a[name]
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, CALLER, ...)
	if ok then return v end
	return nil
end
local function btsApi()
	local a = type(BlackthornesTS_API) == "table" and BlackthornesTS_API or nil
	if a and (tonumber(a.version) or 0) >= 1 and type(a.GetPrice) == "function" then return a end
	return nil
end
local function bCall(name, item)
	local a = btsApi()
	local fn = a and a[name]
	if type(fn) ~= "function" or item == nil then return nil end
	local ok, v = pcall(fn, item)
	if ok and type(v) == "number" and v == v then return v end
	return nil
end
-- (1.6.0-beta6, the beta5 audit's advisory) a usable price is a real, finite amount above zero: not a string, not zero or
-- below, not NaN, not infinity. Both sources go through it.
local function positive(v) return type(v) == "number" and v == v and v > 0 and v < math.huge and v or nil end
local MAX_AGE_DAYS = 21

local SOURCES = {
	auctionator = {
		name = "Auctionator",
		available = function() local a = auctionatorApi(); return a ~= nil and type(a.GetAuctionPriceByItemLink) == "function" end,
		price = function(rec)
			local v
			if rec.link then v = aCall("GetAuctionPriceByItemLink", rec.link) end
			if v == nil and rec.itemID then v = aCall("GetAuctionPriceByItemID", rec.itemID) end
			return positive(v)
		end,
		-- days, or nil and why: "unknown" (no date for this price)
		age = function(rec)
			local v
			if rec.link then v = aCall("GetAuctionAgeByItemLink", rec.link) end
			if v == nil and rec.itemID then v = aCall("GetAuctionAgeByItemID", rec.itemID) end
			if type(v) == "number" and v == v and v >= 0 and v < math.huge then return v end
			return nil, "unknown"
		end,
		noPrice = "Auctionator has no price for %s yet. Open the Auction House and run an Auctionator scan, or search for it there, and BagSmith will pick the price up.",
		column = "Prices from Auctionator's last auction house scan.",
	},
	blackthornes = {
		name = "Blackthornes Tradeskills",
		available = function() return btsApi() ~= nil end,
		price = function(rec)
			local v = positive(bCall("GetPrice", rec.link))
			if v == nil and rec.itemID then v = positive(bCall("GetPrice", rec.itemID)) end
			return v
		end,
		age = function(rec)
			local s = bCall("GetPriceAge", rec.link)
			if s == nil and rec.itemID then s = bCall("GetPriceAge", rec.itemID) end
			-- (1.6.0-beta6, the beta5 audit's F5) no age of your own (guild data, another addon) is "unknown", not old
			if type(s) ~= "number" or s < 0 or s ~= s or s == math.huge then return nil, "unknown" end
			local days = math.floor(s / 86400)
			if days > MAX_AGE_DAYS then return nil, "old" end
			return days
		end,
		noPrice = "Blackthornes Tradeskills has no price for %s yet. Open the Auction House and scan (/bts scan), and BagSmith will pick the price up.",
		column = "Prices from Blackthornes Tradeskills' auction house scans.",
	},
}
AH.ORDER = { "auctionator", "blackthornes" }
AH.SOURCES = SOURCES
AH.INSTALL_HINT = "Install Auctionator or Blackthornes Tradeskills to enable this column. It shows prices from your auction house scans."

-- The source in use ("auctionator" or "blackthornes"), or nil when neither is installed.
function AH:Source()
	local want = ns.db and ns.db.priceSource or "auto"
	if want ~= "auto" and SOURCES[want] and SOURCES[want].available() then return want end
	for _, key in ipairs(self.ORDER) do if SOURCES[key].available() then return key end end
	return nil
end
function AH:SourceName() local k = self:Source(); return k and SOURCES[k].name or nil end
function AH:Installed(key) return SOURCES[key] ~= nil and SOURCES[key].available() end
-- "Prices from ...", for the AH column's tips, or the install hint.
function AH:ColumnText() local k = self:Source(); return k and SOURCES[k].column or self.INSTALL_HINT end
-- The source's own "no price yet" hint, naming the item.
function AH:NoPriceText(what)
	local k = self:Source()
	if not k then return self.INSTALL_HINT end
	return SOURCES[k].noPrice:format(what or "this item")
end

-- True when a price source is installed and offers its price lookup.
function AH:Available() return self:Source() ~= nil end

-- Price per item from the source in use, or nil.
function AH:Price(rec)
	local k = rec and self:Source()
	if not k then return nil end
	return SOURCES[k].price(rec)
end

-- (1.6.0-beta11, Shweep: "handle everywhere") A soulbound item can't be sold at the auction house, so it has no AH
-- value anywhere: not in the AH Price column, the section totals, sorting by AH price, item tooltips, the Loot Helper
-- or the Disenchant Helper. Every bind-on-pickup item in your bags is soulbound, and so is anything bound once used.
-- AH:Price stays the item's market price (the Disenchant Helper's materials, which can be sold, use it).
function AH:Sellable(rec) return not (rec and rec.isBound) end

-- The stack's value (price x count), or nil. Nil for a soulbound item (1.6.0-beta11).
function AH:StackValue(rec)
	if not self:Sellable(rec) then return nil end
	local p = self:Price(rec)
	return p and p * (rec.count or 1) or nil
end

-- Days since the source last saw the item, or nil (over 21 days, or never, or a price with no scan of your own).
function AH:Age(rec)
	local k = rec and self:Source()
	if not k then return nil end
	return (SOURCES[k].age(rec))
end
-- (1.6.0-beta6, F5) The same, telling the two nils apart: days, or "old" (older than the cutoff), or "unknown" (no date
-- for this price: guild data, another addon, or a source that gave none).
function AH:AgeInfo(rec)
	local k = rec and self:Source()
	if not k then return "unknown" end
	local days, why = SOURCES[k].age(rec)
	if days then return days end
	return why == "old" and "old" or "unknown"
end

-- The column is shown in at least one window.
function AH:ColumnOn()
	if not self:Available() then return false end
	return ns.IndexOf(ns.db.cols, "ah") ~= nil or ns.IndexOf(ns.db.bankCols, "ah") ~= nil
end

-- Lines added to an item's tooltip while the column is on.
function AH:AddTooltipLines(tip, rec)
	if not (tip and rec and self:ColumnOn()) then return end
	if not self:Sellable(rec) then return end   -- (1.6.0-beta11) the game's tooltip already says Soulbound
	local p = self:Price(rec)
	if not p then
		ns.TipLine(tip, "AH Price: not scanned", 0.6, 0.6, 0.6)
		return
	end
	tip:AddDoubleLine("AH Price (each)", ns.Money(p), 0.98, 0.78, 0.46, 1, 1, 1)
	local age = self:AgeInfo(rec)
	local when
	if age == "unknown" then when = "Scan date unknown"   -- (1.6.0-beta6, F5; Shweep's wording)
	elseif age == "old" then when = "Over 3 weeks old"
	elseif age < 1 then when = "Seen today"
	elseif age < 2 then when = "Seen yesterday"
	else when = ("Seen %d days ago"):format(age) end
	ns.TipLine(tip, when, 0.6, 0.6, 0.6)
end

ns:On("AUCTION_HOUSE_CLOSED", function() if AH:ColumnOn() then ns:RefreshViews(true) end end)
-- A price addon may load after BagSmith: offer the column as soon as it does.
ns:On("ADDON_LOADED", function(name)
	if (name == "Auctionator" or name == "Blackthornes_TS") and ns.ready then ns:Fire("SETTINGS_CHANGED", "cols") end
end)
-- (1.6.0) a different source repaints everything that shows prices. (1.6.0-beta6, the beta5 audit's F1) Whenever the
-- source in use changes (Price Source, a profile switch, a price addon loading late), PRICE_SOURCE_CHANGED tells the
-- Loot and Disenchant Helpers, which repaint their values, order and recommendations from it.
function AH:CheckSource()
	local now = self:Source()
	if now == self.lastSource then return false end
	local was = self.lastSource
	self.lastSource = now
	if ns.ready then ns:Fire("PRICE_SOURCE_CHANGED", now, was) end
	return true
end
ns:OnSignal("ADDON_READY", function() AH.lastSource = AH:Source() end)
ns:OnSignal("SETTINGS_CHANGED", function(key)
	if key == "priceSource" and ns.ready then ns:RefreshViews(true) end
	if key == nil or key == "priceSource" or key == "cols" then AH:CheckSource() end
end)
