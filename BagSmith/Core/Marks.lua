--[[
	Core/Marks.lua

	Two item marks with their own list-view columns (beside Junk, which is
	Core/Junk.lua):
	  Favorite (star): favorited items move into the Favorites section at the
	    top of the window, like pinned mail.
	  Currency (wallet): items tracked as currencies show in the currency
	    drawer with their count, and stay listed even when you have none.
	Both lists live in the profile (so Profile Sharing carries them), by
	item ID. Each column's cell works like the Junk cell: faint on row hover,
	full when on, a tooltip, click to toggle; items that can't take the mark
	explain why. Each has a key binding for the item under the pointer.
--]]
local ADDON, ns = ...
local M = {}
ns.Marks = M

local WALLET = "Interface\\AddOns\\BagSmith\\Media\\ui-wallet.tga"
local FAINT, HOVER, BLOCKED = 0.35, 0.8, 0.3
local GOLD = { 0.98, 0.78, 0.46 }

------------------------------------------------------------------------
-- The lists
------------------------------------------------------------------------
local function list(key)
	if not ns.db then return {} end
	if type(ns.db[key]) ~= "table" then ns.db[key] = {} end
	return ns.db[key]
end
function M:IsFavorite(id) return id and ns.IndexOf(list("favItems"), id) ~= nil or false end
function M:IsTracked(id) return id and ns.IndexOf(list("customCurrencies"), id) ~= nil or false end
-- Items that are currencies already (the built-in token list, or sorted into Tokens).
function M:IsBuiltInCurrency(rec) return rec and ((ns.TOKEN_IDS and ns.TOKEN_IDS[rec.itemID]) or (rec.ownCat or rec.cat) == "Tokens") and true or false end

local function refresh()
	if ns.Currency then ns.Currency:Invalidate() end
	ns:Fire("SETTINGS_CHANGED", "marks")
	if ns.Drawer and ns.Drawer.Refresh then ns.Drawer:Refresh() end
end
function M:ToggleFavorite(rec)
	if not (rec and rec.itemID and not rec.empty and not rec.cached) then return end
	local l = list("favItems")
	local i = ns.IndexOf(l, rec.itemID)
	if i then table.remove(l, i) else l[#l + 1] = rec.itemID end
	M:RedecorateItem(rec.itemID)
	refresh()
end
function M:Track(id)
	if not id or M:IsTracked(id) then return false end
	local l = list("customCurrencies")
	l[#l + 1] = id
	if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
	refresh()
	return true
end
function M:Untrack(id)
	local l = list("customCurrencies")
	local i = ns.IndexOf(l, id)
	if not i then return false end
	table.remove(l, i)
	refresh()
	return true
end
function M:ToggleCurrency(rec)
	if not (rec and rec.itemID and not rec.empty and not rec.cached) or M:IsBuiltInCurrency(rec) then return end
	if M:IsTracked(rec.itemID) then M:Untrack(rec.itemID) else M:Track(rec.itemID) end
	M:RedecorateItem(rec.itemID)
end

------------------------------------------------------------------------
-- Cells (Favorite and Currency columns)
------------------------------------------------------------------------
local KINDS = {
	fv = {
		field = "colFav", column = "favColumn",
		art = function(tex) tex:SetTexture("Interface\\AddOns\\BagSmith\\Media\\ui-star.tga") end,
		state = function(rec)
			if not rec or rec.empty then return "none" end
			if rec.cached then return "blocked", "Favorites are your own items: switch to that character to favorite theirs." end
			return M:IsFavorite(rec.itemID) and "on" or "eligible"
		end,
		toggle = function(rec) M:ToggleFavorite(rec) end,
		tip = function(state, reason, key)
			if state == "blocked" then return "Can't Be a Favorite", reason end
			if state == "on" then return "Favorite", "In the Favorites section at the top. Click to unfavorite.", key end
			return "Favorite", "Click to pin it in the Favorites section at the top.", key
		end,
		binding = "BAGSMITH_FAVORITE",
	},
	cc = {
		field = "colCurr", column = "currColumn",
		art = function(tex) tex:SetTexture(WALLET) end,
		state = function(rec)
			if not rec or rec.empty then return "none" end
			if rec.cached then return "blocked", "Tracking is set from your own items: switch to that character, or add it from the currency drawer." end
			if M:IsBuiltInCurrency(rec) then return "fixed", "Already a currency: it's always in the currency drawer." end
			return M:IsTracked(rec.itemID) and "on" or "eligible"
		end,
		toggle = function(rec) M:ToggleCurrency(rec) end,
		tip = function(state, reason, key)
			if state == "blocked" then return "Can't Track This Here", reason end
			if state == "fixed" then return "Currency", reason end
			if state == "on" then return "Tracked as a Currency", "Shown in the currency drawer, even when you have none. Click to stop tracking.", key end
			return "Track as Currency", "Click to show it in the currency drawer with its count.", key
		end,
		binding = "BAGSMITH_CURRENCYITEM",
	},
}
M.KINDS = KINDS

-- Made the first time a row lays out the column (Buttons.EnsureCell).
function M:MakeCell(b, kind)
	local k = KINDS[kind]
	if b[k.field] then return b[k.field] end
	do
		local c = CreateFrame("Button", nil, b)
		c:SetSize(16, 16)
		c.tex = c:CreateTexture(nil, "OVERLAY"); c.tex:SetAllPoints(c)
		k.art(c.tex)
		c.kind = kind
		c:SetScript("OnClick", function(self) local row = self:GetParent(); if row.rec and self.state ~= "blocked" and self.state ~= "fixed" then KINDS[self.kind].toggle(row.rec) end end)
		c:SetScript("OnEnter", function(self) M:CellEnter(self) end)
		c:SetScript("OnLeave", function(self) M:CellLeave(self) end)
		c:Hide()
		b[k.field] = c
		-- Painted for the record already on the button.
		local state, reason = k.state(b.rec)
		c.state, c.reason = state, reason
		return c
	end
end

function M:Paint(b, kind)
	local k = KINDS[kind]
	local c = b[k.field]
	if not c then return end
	local state = c.state or "none"
	local show = b[k.column] and b.mode == "row" and b.hasItem and state ~= "none"
	c:SetShown(show and true or false)
	local over = c.hover or b.rowHover or (b.IsMouseOver and b:IsMouseOver())
	if state == "eligible" then
		c.tex:SetAlpha(c.hover and HOVER or (over and FAINT or 0)); c.tex:SetDesaturated(false); c.tex:SetVertexColor(1, 1, 1)
	elseif state == "blocked" then
		c.tex:SetAlpha(c.hover and BLOCKED or 0); c.tex:SetDesaturated(true); c.tex:SetVertexColor(1, 1, 1)
	else   -- on, fixed: gold, like every column icon that's on
		c.tex:SetAlpha(1); c.tex:SetDesaturated(false)
		c.tex:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
	end
end
function M:Decorate(b, rec)
	for kind, k in pairs(KINDS) do
		local c = b[k.field]
		if c then
			local state, reason = k.state(rec)
			c.state, c.reason = state, reason
			M:Paint(b, kind)
		end
	end
end
function M:RowHover(b, on)
	b.rowHover = on and true or false
	for kind in pairs(KINDS) do M:Paint(b, kind) end
end
function M:CellEnter(c)
	c.hover = true
	local b = c:GetParent()
	M:Paint(b, c.kind)
	if not ns.TooltipsOK() then return end
	local k = KINDS[c.kind]
	local key = ns.KeyBinds and ns.KeyBinds:Key(k.binding)
	local title, line, showKey = k.tip(c.state, c.reason, key)
	GameTooltip:SetOwner(c, "ANCHOR_TOP")
	ns.TipText(GameTooltip, title)
	if line then ns.TipLine(GameTooltip, line, 0.6, 0.6, 0.6, true) end
	if showKey then ns.TipLine(GameTooltip, ("Or press %s with the pointer on the item."):format(showKey), 0.6, 0.6, 0.6, true) end
	GameTooltip:Show()
end
function M:CellLeave(c)
	c.hover = false
	local b = c:GetParent()
	b.rowHover = b.IsMouseOver and b:IsMouseOver() or false
	M:Paint(b, c.kind)
	GameTooltip:Hide()
end
-- Every visible button for an item, at once (rows can be holding still).
function M:RedecorateItem(id)
	for _, l in ipairs({ ns.Buttons.all, ns.Buttons.recent }) do
		for _, b in ipairs(l or {}) do
			if b.rec and b.rec.itemID == id and not b.rec.empty then M:Decorate(b, b.rec) end
		end
	end
end

-- Tooltip lines on item tooltips (with the key hints once keys are set).
function M:AddTooltipLines(tip, rec)
	if not (tip and rec and not rec.empty and not rec.cached) then return end
	if M:IsFavorite(rec.itemID) then ns.TipLine(tip, "Favorite", GOLD[1], GOLD[2], GOLD[3]) end
	if M:IsTracked(rec.itemID) then ns.TipLine(tip, "Tracked as a currency", GOLD[1], GOLD[2], GOLD[3]) end
	local kf = ns.KeyBinds and ns.KeyBinds:Key("BAGSMITH_FAVORITE")
	if kf then ns.TipLine(tip, ("Press %s to %s"):format(kf, M:IsFavorite(rec.itemID) and "unfavorite" or "favorite"), 0.6, 0.6, 0.6) end
	local kc = ns.KeyBinds and ns.KeyBinds:Key("BAGSMITH_CURRENCYITEM")
	if kc and not M:IsBuiltInCurrency(rec) then ns.TipLine(tip, ("Press %s to %s"):format(kc, M:IsTracked(rec.itemID) and "stop tracking as a currency" or "track as a currency"), 0.6, 0.6, 0.6) end
end

------------------------------------------------------------------------
-- Key bindings: the item under the pointer.
------------------------------------------------------------------------
local function hovered()
	local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
	for _, f in ipairs(foci or {}) do
		local x = f
		for _ = 1, 3 do
			if not x then break end
			if x.rec and x.hasItem then return x.rec end
			x = x.GetParent and x:GetParent()
		end
	end
end
function BagSmith_ToggleFavorite() local rec = hovered(); if rec then M:ToggleFavorite(rec) end end
function BagSmith_ToggleCurrencyItem() local rec = hovered(); if rec then M:ToggleCurrency(rec) end end
