--[[
	BagSmith - Frames/Drawer.lua
	Currency drawer: a side panel attached to the main window. Favorites at
	the top (star to unpin, arrows to reorder), then wallet currencies, then
	token items counted from bags and bank.
--]]

local ADDON, ns = ...
local Skins = ns.Skins
local Drawer = {}
ns.Drawer = Drawer

local WIDTH, ROW_H = 280, 26

local function fs(parent, template, justify)
	local s = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
	s:SetJustifyH(justify or "LEFT"); s:SetWordWrap(false)
	return s
end

function Drawer:Create()
	if self.frame then return end
	local main = ns.Window.main.frame
	local f = CreateFrame("Frame", "BagSmithDrawer", main, "BackdropTemplate")
	-- The Currencies button follows the drawer itself, however it closes.
	local function syncButton() local m = ns.Window.main; if m and m.btnCurrency then m.btnCurrency:SetActive(f:IsVisible() and true or false) end end
	f:HookScript("OnShow", syncButton); f:HookScript("OnHide", syncButton)
	f:SetWidth(WIDTH)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(true)
	f:Hide()
	self.frame = f
	-- (skin callback set below, once the title and close button exist)

	f.title = fs(f, "GameFontNormal"); f.title:SetPoint("TOPLEFT", 12, -12); f.title:SetText("Currencies")
	local close = ns.IconButton(f, "Interface\\AddOns\\BagSmith\\Media\\ui-close.tga", "Close", nil)
	close:SetPoint("TOPRIGHT", -8, -8)
	close:SetScript("OnClick", function() Drawer:Hide() end)
	-- Classic: Blizzard's window frame (no portrait), title in the strip.
	f.hint = fs(f); f.hint:SetPoint("TOPLEFT", 12, -34); f.hint:SetPoint("TOPRIGHT", -12, -34)

	local scroll = CreateFrame("ScrollFrame", "BagSmithDrawerScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 8, -50)
	scroll:SetPoint("BOTTOMRIGHT", -26, 72)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(WIDTH - 40, 1)
	scroll:SetScrollChild(child)
	f.scroll, f.child, f.rows, f.heads = scroll, child, {}, {}

	f.import = ns.TextButton(f, "Import Blizzard Picks", 150, function()
		local n = ns.Currency:ImportBlizzard()
		ns:Print("Imported %d currencies from the Blizzard backpack.", n)
		Drawer:Refresh()
	end)
	f.import:SetHeight(22); f.import:SetPoint("BOTTOMLEFT", 12, 10)

	-- Add Item: track any item as a currency. Type to search items you have
	-- (bags, bank, other characters' saved bags, ones tracked before), or
	-- paste an item link (shift-click an item) or an item ID, then Enter.
	local add = CreateFrame("EditBox", "BagSmithDrawerAdd", f, "SearchBoxTemplate")
	add:SetSize(WIDTH - 24, 22); add:SetAutoFocus(false)
	add:SetPoint("BOTTOMLEFT", 16, 40)
	if add.Instructions then add.Instructions:SetText("Add an item as a currency") end
	add:SetScript("OnTextChanged", function(box, user) if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(box) end; Drawer:Suggest() end)
	add:SetScript("OnEnterPressed", function(box) Drawer:AddFromBox() end)
	add:SetScript("OnEscapePressed", function(box) box:SetText(""); box:ClearFocus(); Drawer:Suggest() end)
	f.add = add
	f.addHint = fs(f); f.addHint:SetPoint("BOTTOMLEFT", add, "TOPLEFT", -4, 2); f.addHint:SetPoint("BOTTOMRIGHT", add, "TOPRIGHT", 0, 2)
	f.suggest = {}
	-- Shift-clicking an item while the box has focus puts its link in the box.
	if not Drawer.linkHook and type(ChatEdit_InsertLink) == "function" then
		Drawer.linkHook = true
		hooksecurefunc("ChatEdit_InsertLink", function(link) local b = Drawer.frame and Drawer.frame.add; if b and b:HasFocus() and link then b:SetText(link); Drawer:AddFromBox() end end)
	end

	-- Classic: Blizzard's window frame (no portrait), title in the strip.
	-- Its border is thicker than Modern's, so the list, its scrollbar and the
	-- Import button move in to clear it (Modern's spots are put back after).
	f.classicSpec = {
		title = function() return "Currencies" end,
		close = function() Drawer:Hide() end,
		hide = { f.title, close },
		moves = {
			{ scroll, function()
				scroll:ClearAllPoints()
				scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -50)
				scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 78)
			end },
			{ add, function() add:ClearAllPoints(); add:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 44) end },
			{ f.import, function() f.import:ClearAllPoints(); f.import:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 14) end },
		},
		restore = function() Skins:ApplyBackdrop(f) end,
	}
	Skins:Register(f, function(fr)
		Skins:ApplyBackdrop(fr)
		ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
		Drawer:Refresh()   -- rows follow the list's width in either skin
	end)
end

-- Row width: Modern's list is 240 wide; Classic's is 10 narrower to clear
-- its border, so the rows shrink with it and the reorder arrows stay inside.
local function rowWidth(f)
	local st = f.classicState
	return (st and st.on) and (WIDTH - 50) or (WIDTH - 40)
end

local function head(f, i, text, sub)
	local h = f.heads[i]
	if not h then
		h = CreateFrame("Frame", nil, f.child); h:SetSize(WIDTH - 40, 22)
		h.text = fs(h, "GameFontNormalSmall"); h.text:SetPoint("LEFT", 2, -2)
		h.sub = fs(h, nil, "RIGHT"); h.sub:SetPoint("RIGHT", -2, -2)
		h.line = h:CreateTexture(nil, "ARTWORK"); h.line:SetPoint("BOTTOMLEFT"); h.line:SetPoint("BOTTOMRIGHT"); h.line:SetHeight(1)
		f.heads[i] = h
	end
	h:SetWidth(rowWidth(f))
	h.text:SetText(text); h.sub:SetText(sub or "")
	h.text:SetTextColor(Skins:Color("heading")); h.sub:SetTextColor(Skins:Color("muted")); h.line:SetColorTexture(Skins:Color("line"))
	return h
end

local function row(f, i)
	local r = f.rows[i]
	if r then return r end
	r = CreateFrame("Frame", nil, f.child); r:SetSize(WIDTH - 40, ROW_H)
	r.star = CreateFrame("Button", nil, r); r.star:SetSize(18, 18); r.star:SetPoint("LEFT", 0, 0)
	-- The pin: currencies pinned to the bag footer (item Favorites are the star).
	r.star.tex = r.star:CreateTexture(nil, "ARTWORK"); r.star.tex:SetAllPoints(); r.star.tex:SetTexture("Interface\\AddOns\\BagSmith\\Media\\ui-pin.tga")
	r.star:SetScript("OnEnter", function(b)
		if not ns.TooltipsOK() then return end
		GameTooltip:SetOwner(b, "ANCHOR_TOP")
		GameTooltip:SetText(ns.Currency:IsFavorite(b:GetParent().key) and "Unpin" or "Pin to Footer")
		GameTooltip:Show()
	end)
	r.star:SetScript("OnLeave", function() GameTooltip:Hide() end)
	r.star:SetScript("OnClick", function(b) ns.Currency:ToggleFavorite(b:GetParent().key); Drawer:Refresh() end)
	ns.HoverWash(r.star, 0)
	r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(16, 16); r.icon:SetPoint("LEFT", r.star, "RIGHT", 4, 0)
	r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	r.name = fs(r); r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0); r.name:SetPoint("RIGHT", -100, 4)
	r.src = fs(r); r.src:SetPoint("LEFT", r.icon, "RIGHT", 6, -9); r.src:SetPoint("RIGHT", -100, -9)
	r.count = fs(r, nil, "RIGHT"); r.count:SetPoint("RIGHT", -46, 0); r.count:SetWidth(52)
	r.up = ns.IconButton(r, "Interface\\AddOns\\BagSmith\\Media\\ui-chev-up.tga", "Move Up", function(b) ns.Currency:MoveFavorite(b:GetParent().key, -1); Drawer:Refresh() end)
	r.up:SetSize(20, 20); r.up:SetPoint("RIGHT", -20, 0)
	r.down = ns.IconButton(r, "Interface\\AddOns\\BagSmith\\Media\\ui-chev-down.tga", "Move Down", function(b) ns.Currency:MoveFavorite(b:GetParent().key, 1); Drawer:Refresh() end)
	r.down:SetSize(20, 20); r.down:SetPoint("RIGHT", 0, 0)
	r.remove = ns.IconButton(r, "Interface\\AddOns\\BagSmith\\Media\\ui-close.tga", "Stop Tracking", function(b) ns.Marks:Untrack(b:GetParent().id); Drawer:Refresh() end)
	r.remove:SetSize(16, 16); r.remove:SetPoint("RIGHT", -2, 0)
	f.rows[i] = r
	return r
end

function Drawer:Refresh()
	local f = self.frame
	if not f or not f:IsShown() then return end
	local owner = ns.ui.owner
	local favs, all = ns.Currency:Favorites(owner)
	local favSet = {}
	for _, e in ipairs(favs) do favSet[e.key] = true end
	local main = ns.Window.main
	f.hint:SetText(#favs > 0 and ("%d of %d pinned fit in the footer"):format(main.favShown or 0, #favs) or "Pin a currency to show it in the bag footer.")
	f.hint:SetTextColor(Skins:Color("muted"))

	local y, ri, hi = 0, 0, 0
	local function addRow(e, isFav)
		ri = ri + 1
		local r = row(f, ri)
		r.key, r.id = e.key, e.id
		r:SetWidth(rowWidth(f))
		r.icon:SetTexture(e.icon)
		local none = e.custom and (e.count or 0) == 0   -- a tracked item you have none of: dimmed
		r.name:SetText(e.name); r.name:SetTextColor(Skins:Color(none and "muted" or "text"))
		r.src:SetText(e.source or ""); r.src:SetTextColor(Skins:Color("muted"))
		r.count:SetText(BreakUpLargeNumbers and BreakUpLargeNumbers(e.count) or e.count)
		r.count:SetTextColor(Skins:Color(none and "muted" or "text"))
		r.icon:SetDesaturated(none and true or false)
		r.remove:SetShown(e.custom and not isFav and not owner and true or false)
		r.star.tex:SetVertexColor(isFav and 0.98 or 0.4, isFav and 0.78 or 0.4, isFav and 0.46 or 0.4)
		r.up:SetShown(isFav and not owner); r.down:SetShown(isFav and not owner)
		r.star:SetShown(not owner)
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", f.child, "TOPLEFT", 0, -y); r:Show()
		y = y + ROW_H
	end
	local function addHead(text, sub)
		hi = hi + 1
		local h = head(f, hi, text, sub)
		h:ClearAllPoints(); h:SetPoint("TOPLEFT", f.child, "TOPLEFT", 0, -y); h:Show()
		y = y + 24
	end
	addHead("Pinned", "")
	for _, e in ipairs(favs) do addRow(e, true) end
	local wallet, tokens, tracked = {}, {}, {}
	for _, e in ipairs(all) do
		if not favSet[e.key] then
			if e.key:sub(1, 2) == "c:" then wallet[#wallet + 1] = e
			elseif e.custom then tracked[#tracked + 1] = e
			else tokens[#tokens + 1] = e end
		end
	end
	if #wallet > 0 then addHead("Wallet"); for _, e in ipairs(wallet) do addRow(e, false) end end
	if #tokens > 0 then addHead("Carried Tokens", "bags and bank"); for _, e in ipairs(tokens) do addRow(e, false) end end
	if #tracked > 0 then addHead("Tracked Items", "bags and bank"); for _, e in ipairs(tracked) do addRow(e, false) end end
	for j = ri + 1, #f.rows do f.rows[j]:Hide() end
	for j = hi + 1, #f.heads do f.heads[j]:Hide() end
	f.child:SetSize(rowWidth(f), math.max(1, y))
	f.import:SetShown(not owner)
	f.add:SetShown(not owner); f.addHint:SetShown(not owner)
	if owner then for _, s in ipairs(f.suggest) do s:Hide() end end
	if ns.Classic and self.frame then ns.Classic:DressButtons(self.frame) end
end

-- Add Item: candidates matching the typed name (items BagSmith has seen),
-- shown just above the box; Enter or a click adds one.
local MAX_SUGGEST = 6
local function candidates(text)
	text = text:lower()
	local out, seen = {}, {}
	local function consider(id, name, icon)
		if not id or seen[id] or not name then return end
		seen[id] = true
		if ns.Marks:IsTracked(id) or (ns.TOKEN_IDS and ns.TOKEN_IDS[id]) then return end
		if name:lower():find(text, 1, true) then out[#out + 1] = { id = id, name = name, icon = icon } end
	end
	for _, r in ipairs(ns.items or {}) do consider(r.itemID, r.name, r.icon) end
	for _, r in ipairs((ns.bankScanned and ns.bankItems) or ns:SavedBank() or {}) do consider(r.itemID, r.name, r.icon) end
	for _, data in pairs(BagSmithDB and BagSmithDB.cache or {}) do
		for _, l in ipairs({ data.items or {}, data.bank or {} }) do for _, r in ipairs(l) do consider(r.itemID, r.name, r.icon) end end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end
Drawer.Candidates = candidates
function Drawer:Suggest()
	local f = self.frame
	if not f then return end
	local text = f.add:GetText() or ""
	local list = {}
	if #text >= 2 and not text:find("item:%d+") and not text:match("^%s*%d+%s*$") then list = candidates(text) end
	for i = 1, math.min(#list, MAX_SUGGEST) do
		local s = f.suggest[i]
		if not s then
			s = CreateFrame("Button", nil, f, "BackdropTemplate")
			s:SetSize(WIDTH - 24, 20)
			s:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
			s.icon = s:CreateTexture(nil, "ARTWORK"); s.icon:SetSize(16, 16); s.icon:SetPoint("LEFT", 4, 0)
			s.text = fs(s); s.text:SetPoint("LEFT", s.icon, "RIGHT", 6, 0); s.text:SetPoint("RIGHT", -4, 0)
			s:SetScript("OnClick", function(b) Drawer:AddItem(b.id) end)
			s:SetFrameLevel(f:GetFrameLevel() + 20)
			f.suggest[i] = s
		end
		local sk = Skins:Current()
		s:SetBackdropColor(sk.bg[1], sk.bg[2], sk.bg[3], 0.97)
		s.id = list[i].id
		s.icon:SetTexture(list[i].icon); s.text:SetText(list[i].name); s.text:SetTextColor(Skins:Color("text"))
		s:ClearAllPoints(); s:SetPoint("BOTTOMLEFT", f.add, "TOPLEFT", -4, 2 + (i - 1) * 21)
		s:Show()
	end
	for i = math.min(#list, MAX_SUGGEST) + 1, #f.suggest do f.suggest[i]:Hide() end
	f.addHint:SetText((#text >= 2 and #list == 0 and not text:find("item:%d+") and not text:match("^%s*%d+%s*$"))
		and "No items match. Paste an item link (shift-click an item) or an item ID to add any item." or "")
	f.addHint:SetTextColor(Skins:Color("muted"))
end
function Drawer:AddItem(id)
	local f = self.frame
	if ns.Marks:Track(id) then
		local name = (C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(id)) or ("item " .. id)
		ns:Print("Tracking %s as a currency.", name)
	end
	if f then f.add:SetText(""); f.add:ClearFocus(); self:Suggest() end
	self:Refresh()
end
function Drawer:AddFromBox()
	local f = self.frame
	local text = f.add:GetText() or ""
	local id = tonumber(text:match("item:(%d+)")) or tonumber(text:match("^%s*(%d+)%s*$"))
	if not id then
		local list = #text >= 2 and candidates(text) or {}
		if #list == 1 then id = list[1].id end
	end
	if id then self:AddItem(id) end
end

function Drawer:Position()
	local f, main = self.frame, ns.Window.main.frame
	f:ClearAllPoints()
	f:SetHeight(main:GetHeight())
	-- Flip to the other side if the preferred side would leave the screen.
	local side = ns.db.side
	local left = main:GetLeft() or 0
	local right = main:GetRight() or 0
	local screenW = UIParent:GetWidth() / ns.db.scale
	if side == "left" and left - WIDTH < 0 then side = "right" end
	if side == "right" and right + WIDTH > screenW then side = "left" end
	if side == "left" then f:SetPoint("TOPRIGHT", main, "TOPLEFT", -4, 0) else f:SetPoint("TOPLEFT", main, "TOPRIGHT", 4, 0) end
end

function Drawer:Show()
	self:Create()
	self:Position()
	self.frame:Show()
	self:Refresh()
	ns.Window.main.btnCurrency:SetActive(true)
end
function Drawer:Hide()
	if self.frame then self.frame:Hide() end
	if ns.Window.main then ns.Window.main.btnCurrency:SetActive(false) end
end
function Drawer:Toggle() if self.frame and self.frame:IsShown() then self:Hide() else self:Show() end end
