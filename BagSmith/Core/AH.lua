--[[
	BagSmith - Core/AH.lua

	Auction house prices from Auctionator, for the optional "AH Price"
	column. Only Auctionator's public, supported interface is used
	(Auctionator.API.v1, read from Auctionator 340's own files): every call
	takes a caller ID first ("BagSmith") and raises a Lua error on bad
	arguments, so each call is wrapped and can never break BagSmith.
	Prices are per item, in copper, from Auctionator's last scan; nil when it
	has none. Auctionator has no public "scan finished" notice, so the column
	refreshes when the auction house closes and on BagSmith's own refreshes.
--]]
local ADDON, ns = ...
local AH = {}
ns.AH = AH

local CALLER = "BagSmith"

local function api()
	local a = type(Auctionator) == "table" and type(Auctionator.API) == "table" and Auctionator.API.v1
	return type(a) == "table" and a or nil
end

-- True when Auctionator is installed and offers its price lookup.
function AH:Available()
	local a = api()
	return a ~= nil and type(a.GetAuctionPriceByItemLink) == "function"
end

local function call(name, ...)
	local a = api()
	local fn = a and a[name]
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, CALLER, ...)
	if ok then return v end
	return nil
end

-- Price per item from the last scan, or nil.
function AH:Price(rec)
	if not (rec and self:Available()) then return nil end
	local v
	if rec.link then v = call("GetAuctionPriceByItemLink", rec.link) end
	if v == nil and rec.itemID then v = call("GetAuctionPriceByItemID", rec.itemID) end
	return type(v) == "number" and v or nil
end

-- The stack's value (price x count), or nil.
function AH:StackValue(rec)
	local p = self:Price(rec)
	return p and p * (rec.count or 1) or nil
end

-- Days since Auctionator last saw the item, or nil (over 21 days, or never).
function AH:Age(rec)
	if not (rec and self:Available()) then return nil end
	local v
	if rec.link then v = call("GetAuctionAgeByItemLink", rec.link) end
	if v == nil and rec.itemID then v = call("GetAuctionAgeByItemID", rec.itemID) end
	return type(v) == "number" and v or nil
end

-- The column is shown in at least one window.
function AH:ColumnOn()
	if not self:Available() then return false end
	return ns.IndexOf(ns.db.cols, "ah") ~= nil or ns.IndexOf(ns.db.bankCols, "ah") ~= nil
end

-- Lines added to an item's tooltip while the column is on.
function AH:AddTooltipLines(tip, rec)
	if not (tip and rec and self:ColumnOn()) then return end
	local p = self:Price(rec)
	if not p then
		ns.TipLine(tip, "AH Price: not scanned", 0.6, 0.6, 0.6)
		return
	end
	tip:AddDoubleLine("AH Price (each)", ns.Money(p), 0.98, 0.78, 0.46, 1, 1, 1)
	local age = self:Age(rec)
	local when
	if age == nil then when = "Over 3 weeks old"
	elseif age < 1 then when = "Seen today"
	elseif age < 2 then when = "Seen yesterday"
	else when = ("Seen %d days ago"):format(age) end
	ns.TipLine(tip, when, 0.6, 0.6, 0.6)
end

ns:On("AUCTION_HOUSE_CLOSED", function() if AH:ColumnOn() then ns:RefreshViews(true) end end)
-- Auctionator may load after BagSmith: offer the column as soon as it does.
ns:On("ADDON_LOADED", function(name)
	if name == "Auctionator" and ns.ready then ns:Fire("SETTINGS_CHANGED", "cols") end
end)
