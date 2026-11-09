--[[
	BagSmith - Frames/SettingsPanel.lua
	A scrolling side panel with every setting. Controls write through ns:Set
	so validation and refresh happen in one place.
--]]

local ADDON, ns = ...
local WHEEL_STEP = 40   -- px per mouse wheel notch in Settings (about two rows)
local Skins = ns.Skins
local Panel = {}
ns.SettingsPanel = Panel

local LINE = 30

local function fs(parent, template, justify)
	local s = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
	s:SetJustifyH(justify or "LEFT"); s:SetWordWrap(false)
	return s
end

------------------------------------------------------------------------
-- Layout cursor helpers. Everything is rebuilt on Refresh so the panel is
-- always in sync with the profile; widgets are pooled by type.
------------------------------------------------------------------------
local NAV_W, WIN_W, WIN_H = 170, 680, 560
local SEARCH_W = 200   -- NAV_W fits the longest page name, "Automations & Actions"
-- A third field names the page an entry sits under: it's listed (indented)
-- only while that page or one of its sub-pages is open.
local PAGES = {
	{ "general", "General" }, { "look", "Style" }, { "icons", "Item Icons" }, { "window", "Windows" },
	{ "sections", "Sections" }, { "dynamic", "Dynamic Sections", "sections" }, { "custom", "Custom Sections", "sections" },
	{ "columns", "Columns" }, { "bagcols", "Bag Columns", "columns" }, { "bankcols", "Bank Columns", "columns" },
	{ "sheets", "Sheets" }, { "bagsheets", "Bag Sheets", "sheets" }, { "banksheets", "Bank Sheets", "sheets" },
	{ "sorting", "Sorting & Filters" }, { "automation", "Automations & Actions" }, { "loothelper", "Loot Helper", "automation" }, { "dehelper", "Disenchant Helper", "automation" },
	{ "keys", "Keybindings" }, { "plugins", "Plugins" }, { "profile", "Profile" }, { "advanced", "Advanced" },
}
local PARENT, HAS_SUBS = {}, {}
for _, p in ipairs(PAGES) do if p[3] then PARENT[p[1]] = p[3]; HAS_SUBS[p[3]] = true end end
local NAV_STEP = 28
-- (1.5.4) The side menu's room runs from its top to just above About & Support (those two buttons, their margins and a
-- gap). If its entries ever don't fit there (pages added later), the spacing tightens, down to NAV_MIN_STEP, and past
-- that the list scrolls with the mouse wheel, small arrows showing there's more. Today everything fits at full spacing.
local NAV_BTN_H, NAV_MIN_STEP, NAV_RESERVE = 26, 22, 70

function Panel:Create()
	if self.frame then return end
	local f = CreateFrame("Frame", "BagSmithSettings", UIParent, "BackdropTemplate")
	f:SetSize(WIN_W, WIN_H)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:Hide()
	self.frame = f

	-- Title bar
	local drag = CreateFrame("Frame", nil, f)
	drag:SetPoint("TOPLEFT", 0, 0); drag:SetPoint("TOPRIGHT", 0, 0); drag:SetHeight(46)
	drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
	local title = CreateFrame("Frame", nil, f)
	title:SetPoint("TOPLEFT", 12, -10); title:SetPoint("TOPRIGHT", -12, -10); title:SetHeight(28)
	title:SetFrameLevel(drag:GetFrameLevel() + 2)
	drag:SetScript("OnDragStart", function() f:StartMoving() end)
	drag:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		local point, _, rel, x, y = f:GetPoint(1)
		if point then ns:Set("settingsPoint", { point, "UIParent", rel, math.floor(x + 0.5), math.floor(y + 0.5) }, true) end
	end)
	title.band = f:CreateTexture(nil, "BACKGROUND")
	title.band:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4); title.band:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	title.band:SetPoint("BOTTOM", title, "BOTTOM", 0, -8)
	title.band:SetTexture("Interface\\Buttons\\WHITE8X8"); title.band:SetVertexColor(1, 1, 1, 0.045)
	local mark = title:CreateTexture(nil, "ARTWORK"); mark:SetSize(16, 16); mark:SetPoint("LEFT", 2, 0)
	mark:SetTexture("Interface\\AddOns\\BagSmith\\Media\\mark.tga"); self.mark = mark
	f.title = fs(title, "GameFontNormal"); f.title:SetPoint("LEFT", mark, "RIGHT", 8, 0); f.title:SetText("BagSmith Settings")
	f.sub = fs(title); f.sub:SetPoint("LEFT", f.title, "RIGHT", 10, 0)
	local close = ns.IconButton(title, "Interface\\AddOns\\BagSmith\\Media\\ui-close.tga", "Close", function() Panel:Hide() end)
	close:SetPoint("RIGHT", 4, 0)
	-- Search every page, to the right of the profile line (both skins).
	local search = CreateFrame("EditBox", "BagSmithSettingsSearch", title, "SearchBoxTemplate")
	search:SetSize(SEARCH_W, 20); search:SetPoint("RIGHT", title, "RIGHT", -30, 0); search:SetAutoFocus(false)
	search:SetScript("OnTextChanged", function(box)
		if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(box) end
		Panel:SetQuery(box:GetText())
	end)
	search:SetScript("OnEscapePressed", function(box) box:SetText(""); box:ClearFocus() end)
	f.search = search
	f.sub:SetPoint("RIGHT", search, "LEFT", -12, 0)   -- a long profile name shortens instead of running under it

	-- Category list on the left
	local nav = CreateFrame("Frame", nil, f)
	nav:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
	nav:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 14)
	nav:SetWidth(NAV_W)
	nav.line = nav:CreateTexture(nil, "ARTWORK"); nav.line:SetPoint("TOPRIGHT", 0, 0); nav.line:SetPoint("BOTTOMRIGHT", 0, 0); nav.line:SetWidth(1)
	-- (1.5.4) scrolling, for when the entries don't fit (see NAV_RESERVE); the arrows show only then
	nav:EnableMouseWheel(true)
	nav:SetScript("OnMouseWheel", function(_, delta)
		Panel.navOffset = (Panel.navOffset or 0) - delta
		Panel.navFollowPage = Panel.page   -- the reader is scrolling: don't snap back to the open page
		Panel:SyncNav()
	end)
	nav.moreUp = nav:CreateTexture(nil, "OVERLAY"); nav.moreUp:SetSize(10, 10)
	nav.moreUp:SetTexture("Interface\\AddOns\\BagSmith\\Media\\ui-chev-down.tga"); nav.moreUp:SetTexCoord(0, 1, 1, 0); nav.moreUp:Hide()
	nav.moreDown = nav:CreateTexture(nil, "OVERLAY"); nav.moreDown:SetSize(10, 10)
	nav.moreDown:SetTexture("Interface\\AddOns\\BagSmith\\Media\\ui-chev-down.tga"); nav.moreDown:Hide()
	self.nav, self.navButtons = nav, {}
	for i, page in ipairs(PAGES) do
		local b = CreateFrame("Button", nil, nav)
		b:SetHeight(26)   -- (placed by SyncNav: sub-pages show only under the open page)
		b.text = fs(b); b.text:SetPoint("LEFT", page[3] and 24 or 10, 0); b.text:SetText(page[2])
		b.parent = page[3]
		if HAS_SUBS[page[1]] then
			-- A page with sub-pages: a small arrow, right when folded, down when open.
			b.arrow = b:CreateTexture(nil, "ARTWORK"); b.arrow:SetSize(10, 10); b.arrow:SetPoint("RIGHT", -6, 0)
		end
		b.bar = b:CreateTexture(nil, "ARTWORK"); b.bar:SetPoint("TOPLEFT", 0, -4); b.bar:SetPoint("BOTTOMLEFT", 0, 4); b.bar:SetWidth(3)
		b.bar:SetTexture("Interface\\Buttons\\WHITE8X8")
		b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8"); b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.05)
		ns.HoverWash(b, 0.05)   -- Modern: a clearer hover
		b.page = page[1]
		b:SetScript("OnClick", function(btn) Panel:ShowPage(btn.page) end)
		self.navButtons[i] = b
	end

	-- What's New, at the bottom left under the categories.
	f.whatsNew = ns.TextButton(f, "What's New", NAV_W - 10, function() ns.WhatsNew:ShowLatest() end)
	f.whatsNew:SetHeight(22)
	f.whatsNew:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 14)
	f.whatsNew.tip = "What's new in this version of BagSmith"
	-- About, just above it.
	f.about = ns.TextButton(f, "About & Support", NAV_W - 10, function() Panel:ShowPage("about") end)
	f.about:SetHeight(22)
	f.about:SetPoint("BOTTOMLEFT", f.whatsNew, "TOPLEFT", 0, 6)
	f.about.tip = "Version, Discord and support links"

	-- Page content on the right, scrolling if needed
	local scroll = CreateFrame("ScrollFrame", "BagSmithSettingsScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", nav, "TOPRIGHT", 16, 0)
	scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 14)
	local sb = scroll.ScrollBar
	if sb then
		for _, key in ipairs({ "Back", "Forward", "ScrollUpButton", "ScrollDownButton" }) do
			local btn = sb[key] or _G[(sb:GetName() or "") .. key]
			if btn then btn:SetAlpha(0); btn:EnableMouse(false) end
		end
	end
	-- The mouse wheel moves a couple of rows at a time (the template moves
	-- half a page, which skipped whole sections).
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(s, delta)
		local range = s.GetVerticalScrollRange and s:GetVerticalScrollRange() or 0
		local new = math.max(0, math.min(range, (s:GetVerticalScroll() or 0) - delta * WHEEL_STEP))
		if s.ScrollBar and s.ScrollBar.SetValue then s.ScrollBar:SetValue(new) end
		s:SetVerticalScroll(new)
	end)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	f.child, self.scroll = child, scroll
	self.pools = { cornerCards = {}, head = {}, check = {}, seg = {}, step = {}, list = {}, text = {}, edit = {}, btn = {}, color = {}, profiles = {}, cmd = {}, bind = {}, about = {}, csec = {}, csechead = {}, moved = {}, gset = {}, ptitle = {}, vis = {}, vishead = {}, pin = {}, card = {}, sep = {}, plug = {}, pnotice = {}, feat = {} }
	self.page = self.page or "general"
	table.insert(UISpecialFrames, "BagSmithSettings")
	ns:CombatWindow(f)   -- (1.5.6) fades in combat like the bags window
	-- The Settings icon follows the window itself, however it opens or closes
	-- (Esc closes it directly, without going through Panel:Hide).
	local function syncIcon() local m = ns.Window.main; if m and m.btnSettings then m.btnSettings:SetActive(f:IsVisible() and true or false) end end
	f:HookScript("OnShow", syncIcon); f:HookScript("OnHide", syncIcon)
	-- Closing Settings stops a waiting "Press a key..." (nothing is bound).
	f:HookScript("OnHide", function() if ns.KeyBinds then ns.KeyBinds:CancelCapture() end end)
	local function modernLook(fr)
		Skins:ApplyBackdrop(fr)
		local s = Skins:Current()
		fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)   -- fully opaque: nothing should show through Settings
	end
	-- Classic: Blizzard's window frame with the BagSmith portrait; the title
	-- moves into the strip, the profile line sits below it, the category
	-- list starts under the portrait.
	self.classicSpec = {
		portrait = function() return "Interface\\AddOns\\BagSmith\\Media\\icon.tga" end,
		title = function() return "BagSmith Settings" end,
		close = function() Panel:Hide() end,
		hide = { mark, f.title, close, title.band },
		moves = {
			{ title, function() title:ClearAllPoints(); title:SetPoint("TOPLEFT", f, "TOPLEFT", 66, -26); title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -26) end },
			{ f.sub, function() f.sub:ClearAllPoints(); f.sub:SetPoint("LEFT", title, "LEFT", 0, 0); f.sub:SetPoint("RIGHT", f.search, "LEFT", -12, 0) end },
			{ nav, function() nav:ClearAllPoints(); nav:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -66); nav:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 14) end },
		},
		restore = function() modernLook(f) end,
	}
	Skins:Register(f, function(fr)
		modernLook(fr)
		Panel:ApplySkin()
		if ns.Classic then ns.Classic:Dress(fr, Panel.classicSpec, ns.Classic.IsOn()); ns.Classic:DressScrollBar(Panel.scroll, ns.Classic.IsOn()) end
	end)
	self:ApplyPosition()
end

function Panel:ApplySkin()
	local s = Skins:Current()
	self.mark:SetVertexColor(unpack(s.heading))
	self.frame.title:SetTextColor(unpack(s.heading))
	self.frame.sub:SetTextColor(unpack(s.muted))
	self.nav.line:SetColorTexture(unpack(s.line))
	self:SyncNav()
end

-- (1.5.4) The height the side menu's entries can use: from its top down to just above About & Support.
function Panel:NavRoom()
	local f, nav = self.frame, self.nav
	local _, rel, _, _, y = nav:GetPoint(1)
	local top = (rel == f) and -(y or 0) or (10 + 28 - (y or 0))   -- Classic anchors it to the window, Modern under the title
	return (f:GetHeight() or WIN_H) - top - NAV_RESERVE
end

function Panel:SyncNav()
	local s = Skins:Current()
	-- Sub-pages show under their page while it or one of them is open (not while searching).
	local open = not self.query and (PARENT[self.page] or (HAS_SUBS[self.page] and self.page)) or nil
	local list, cur = {}, nil
	for _, b in ipairs(self.navButtons) do
		if not b.parent or b.parent == open then
			list[#list + 1] = b
			if b.page == self.page then cur = #list end
		else
			b:Hide()
		end
		if b.arrow then
			b.arrow:SetTexture("Interface\\AddOns\\BagSmith\\Media\\" .. (b.page == open and "ui-chev-down.tga" or "ui-chev-right.tga"))
			b.arrow:SetVertexColor(unpack(s.muted))
		end
		local on = b.page == self.page and not self.query   -- (no page is current while searching)
		b.text:SetTextColor(unpack(on and s.heading or s.muted))
		if on then b.bar:SetVertexColor(Skins:Accent()); b.bar:Show() else b.bar:Hide() end
	end
	-- (1.5.4) Place them: full spacing when they fit above About & Support, tighter when not, and when even the tight
	-- spacing can't fit them all, a window of them that scrolls, keeping the open page in view when the page changes.
	local count, room = #list, self:NavRoom()
	local step, h, fit = NAV_STEP, NAV_BTN_H, count
	if count > 1 and (count - 1) * step + h > room then
		step = math.max(NAV_MIN_STEP, math.floor((room - h) / (count - 1)))
		h = math.min(NAV_BTN_H, step)
		fit = math.max(1, math.min(count, math.floor((room - h) / step) + 1))
	end
	local maxOff = count - fit
	local off = math.min(math.max(self.navOffset or 0, 0), maxOff)
	if cur and (self.navFollowPage ~= self.page or self.navLastFit ~= fit) then
		if cur - 1 < off then off = cur - 1 elseif cur > off + fit then off = cur - fit end
	end
	self.navOffset, self.navFollowPage, self.navLastFit = off, self.page, fit
	for idx, b in ipairs(list) do
		local k = idx - 1 - off
		if k >= 0 and k < fit then
			b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -k * step); b:SetPoint("TOPRIGHT", -10, -k * step)
			b:SetHeight(h); b:Show()
		else
			b:Hide()
		end
	end
	local nav = self.nav
	if nav and nav.moreUp then
		nav.moreUp:ClearAllPoints(); nav.moreUp:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -14, 8)
		nav.moreDown:ClearAllPoints(); nav.moreDown:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -14, -(fit * step) + 2)
		nav.moreUp:SetVertexColor(unpack(s.muted)); nav.moreDown:SetVertexColor(unpack(s.muted))
		nav.moreUp:SetShown(off > 0); nav.moreDown:SetShown(off < maxOff)
	end
	if self.frame and self.frame.about then self.frame.about:SetActive(self.page == "about" and not self.query) end
end

function Panel:ApplyPosition()
	local f, p = self.frame, ns.db.settingsPoint
	f:ClearAllPoints(); f:SetPoint(p[1], UIParent, p[3], p[4], p[5])
	f:SetScale(ns.db.scale)
end

function Panel:ShowPage(page)
	if page ~= self.page and ns.KeyBinds then ns.KeyBinds:CancelCapture() end   -- leaving a waiting "Press a key..."
	-- Opening a page ends a search.
	if self.query then self.query = nil; if self.frame and self.frame.search then self.frame.search:SetText("") end end
	self.page = page
	self.scroll:SetVerticalScroll(0)
	self:SyncNav()
	self:Refresh()
end

local ROW_W = WIN_W - 12 - NAV_W - 16 - 34 - 12   -- content width inside the page
-- Rows that belong to the setting above them (Recent Items' options) sit
-- slightly indented; rowW is the width the current row may use.
local INDENT = 18
local LIST_STRIPE, LIST_HOVER = 0.035, 0.07   -- reorder list rows: every other row, and the hovered row
local rowW, rowX = ROW_W, 0
-- Every sub-section (each heading) sits on a card: the rows under a heading
-- are inset by CARD_PAD on a faint panel with a 1 px border, closed at the
-- next heading or the end of the page, with a small gap (CARD_GAP) before
-- the next heading. Inside a card, a hairline between one row and the next.
local CARD_PAD, CARD_GAP = 10, 8

local function hairline(self)
	local pool = self.pools.sep
	self.counts.sep = (self.counts.sep or 0) + 1
	local t = pool[self.counts.sep]
	if not t then t = self.frame.child:CreateTexture(nil, "BACKGROUND", nil, 2); t:SetHeight(1); t:SetTexture("Interface\\Buttons\\WHITE8X8"); pool[self.counts.sep] = t end
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", self.frame.child, "TOPLEFT", rowX + 4, -(self.y - 1))
	t:SetWidth(rowW - 8)
	local r, g, b = Skins:Color("line")
	t:SetVertexColor(r, g, b, 0.45)
	t:Show()
end

local function acquire(self, kind, make)
	local pool = self.pools[kind]
	self.counts[kind] = (self.counts[kind] or 0) + 1
	local i = self.counts[kind]
	local w = pool[i]
	if not w then w = make(self.frame.child); pool[i] = w end
	-- Inside a card: a hairline above every row but the first.
	if self.card and kind ~= "head" then
		if self.card.rows > 0 then hairline(self) end
		self.card.rows = self.card.rows + 1
	end
	w:ClearAllPoints()
	w:SetPoint("TOPLEFT", self.frame.child, "TOPLEFT", rowX, -self.y)
	if kind ~= "list" and kind ~= "profiles" then w:SetWidth(rowW) end
	w:Show()
	return w
end

-- The card behind the rows of the sub-section that just ended.
function Panel:CloseCard()
	local c = self.card
	if not c then return end
	self.card = nil
	rowX, rowW = 0, ROW_W
	if c.rows == 0 then return end
	local pool = self.pools.card
	self.counts.card = (self.counts.card or 0) + 1
	local f = pool[self.counts.card]
	if not f then
		f = CreateFrame("Frame", nil, self.frame.child, "BackdropTemplate")
		f:SetFrameLevel(self.frame.child:GetFrameLevel())   -- under the rows
		f.fill = f:CreateTexture(nil, "BACKGROUND"); f.fill:SetAllPoints(); f.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
		f.edge = {}
		for i = 1, 4 do local e = f:CreateTexture(nil, "BORDER"); e:SetTexture("Interface\\Buttons\\WHITE8X8"); f.edge[i] = e end
		f.edge[1]:SetPoint("TOPLEFT"); f.edge[1]:SetPoint("TOPRIGHT"); f.edge[1]:SetHeight(1)
		f.edge[2]:SetPoint("BOTTOMLEFT"); f.edge[2]:SetPoint("BOTTOMRIGHT"); f.edge[2]:SetHeight(1)
		f.edge[3]:SetPoint("TOPLEFT"); f.edge[3]:SetPoint("BOTTOMLEFT"); f.edge[3]:SetWidth(1)
		f.edge[4]:SetPoint("TOPRIGHT"); f.edge[4]:SetPoint("BOTTOMRIGHT"); f.edge[4]:SetWidth(1)
		pool[self.counts.card] = f
	end
	local top, bottom = c.top, self.y + CARD_PAD - 4
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", self.frame.child, "TOPLEFT", 0, -top)
	f:SetSize(ROW_W, bottom - top)
	local classic = ns.Classic and ns.Classic.IsOn and ns.Classic.IsOn()
	if classic then f.fill:SetVertexColor(0, 0, 0, 0.18) else f.fill:SetVertexColor(1, 1, 1, 0.025) end
	local r, g, b = Skins:Color("line")
	for i = 1, 4 do f.edge[i]:SetVertexColor(r, g, b, 0.7) end
	f:Show()
	self.y = bottom + CARD_GAP
end

-- Rows added inside fn are indented under the setting they belong to.
function Panel:Indented(fn)
	local x0, w0 = rowX, rowW
	-- Searching: the setting these belong to, if it didn't match itself.
	local f = self.filter
	if f then f.indentParent, f.indentX0, f.indentW0, f.lastSkipped = f.lastSkipped, x0, w0, nil end
	rowX, rowW = x0 + INDENT, w0 - INDENT
	local ok, err = pcall(fn)
	rowX, rowW = x0, w0
	if f then f.indentParent = nil end
	if not ok then error(err, 0) end
end
local FONT_H = 14

local function wrapText(fs, width)
	fs:SetWidth(width)
	fs:SetWordWrap(true)
	fs:SetNonSpaceWrap(false)
	return math.max(FONT_H, fs:GetStringHeight() or FONT_H)
end

-- info (1.5.0-beta3): an optional { title, lines, keywords } for an info icon beside the heading; its words are
-- searchable.
function Panel:Head(text, info)
	self:CloseCard()
	local h = acquire(self, "head", function(p)
		local w = CreateFrame("Frame", nil, p); w:SetSize(ROW_W, 30)
		w.text = fs(w, "GameFontNormal"); w.text:SetPoint("BOTTOMLEFT", 2, 6)
		w.line = w:CreateTexture(nil, "ARTWORK"); w.line:SetPoint("BOTTOMLEFT"); w.line:SetPoint("BOTTOMRIGHT"); w.line:SetHeight(1)
		return w
	end)
	h.text:SetText(text); h.text:SetTextColor(Skins:Color("heading")); h.line:SetColorTexture(Skins:Color("line"))
	if info and not info.noIcon then
		if not h.info then h.info = ns.Why.InfoButton(h) end
		h.info.title, h.info.lines = info.title, info.lines
		h.info:ClearAllPoints(); h.info:SetPoint("LEFT", h.text, "LEFT", (h.text:GetStringWidth() or 0) + 6, 0)
		h.info:Show()
	elseif h.info then
		h.info:Hide()
	end
	self.y = self.y + 40
	-- The card for this sub-section starts just under the heading's line.
	self.card = { top = self.y - 6, rows = 0 }
	rowX, rowW = CARD_PAD, ROW_W - CARD_PAD * 2
	self.y = self.y + 2
end

function Panel:Text(text)
	local w = acquire(self, "text", function(p) local w = CreateFrame("Frame", nil, p); w:SetSize(ROW_W, 20); w.text = fs(w); w.text:SetPoint("TOPLEFT", 2, -2); return w end)
	if w.info then w.info:Hide(); w.othersLine = nil end   -- (1.5.0-beta6) a reused row loses the Icon Corners line's info icon
	w.text:SetText(text); w.text:SetTextColor(Skins:Color("muted"))
	local h = wrapText(w.text, rowW - 4)
	w:SetHeight(h + 8)
	self.y = self.y + h + 10
end

-- A command list: each command in a fixed-width gold column, its description
-- beside it in the help color. A long description wraps in its own column;
-- a command never breaks across lines.
local CMD_W = 96
function Panel:Command(cmd, desc)
	local w = acquire(self, "cmd", function(p)
		local r = CreateFrame("Frame", nil, p); r:SetSize(ROW_W, 20)
		r.cmd = fs(r); r.cmd:SetPoint("TOPLEFT", 2, -2); r.cmd:SetWordWrap(false)
		r.desc = fs(r); r.desc:SetPoint("TOPLEFT", 2 + CMD_W, -2)
		return r
	end)
	w.cmd:SetText(cmd); w.cmd:SetWidth(CMD_W - 8); w.cmd:SetTextColor(Skins:Color("heading"))
	w.desc:SetText(desc); w.desc:SetTextColor(Skins:Color("muted"))
	local h = wrapText(w.desc, rowW - CMD_W - 4)
	w:SetHeight(h + 6)
	self.y = self.y + h + 8
end

-- Shared row layout: label at top-left, an optional help line under it
-- (word-wrapped), and a control that sits on the label line when it fits
-- or drops to its own line under the help when it does not.
local function layoutRow(w, label, help, controlW, controlH)
	w.text:ClearAllPoints(); w.text:SetPoint("TOPLEFT", 2, -6)
	w.text:SetText(label); w.text:SetTextColor(Skins:Color("text"))
	w.text:SetWordWrap(false); w.text:SetWidth(0)
	local labelW = w.text:GetStringWidth()
	local fits = labelW + 16 + controlW <= rowW
	local y = 6 + FONT_H
	if not fits then w.text:SetWidth(rowW - 4) end
	local helpH = 0
	w.help:ClearAllPoints(); w.help:SetPoint("TOPLEFT", 2, -(y + 2))
	if help and help ~= "" then
		w.help:SetText(help); w.help:SetTextColor(Skins:Color("muted"))
		-- Keep the help clear of a control sitting on the label line.
		helpH = wrapText(w.help, fits and (rowW - controlW - 16) or (rowW - 4)) + 2
		w.help:Show()
	else
		w.help:SetText(""); w.help:Hide()
	end
	y = y + helpH
	local controlY
	if fits then controlY = -4 else controlY = -(y + 4); y = y + controlH + 4 end
	w:SetHeight(y + 8)
	return controlY, fits
end

-- opts (1.5.1-beta2, optional): { disabled = true, checked = bool } shows the box greyed out and fixed, for a setting
-- that its parent overrides.
function Panel:Check(key, label, help, opts)
	local c = acquire(self, "check", function(p)
		local w = CreateFrame("Frame", nil, p); w:SetSize(ROW_W, LINE)
		w.text = fs(w); w.help = fs(w)
		w.box = CreateFrame("CheckButton", nil, w, "UICheckButtonTemplate"); w.box:SetSize(24, 24)
		w.box:SetScript("OnClick", function(b) if w.onSet then w.onSet(b:GetChecked() and true or false) else ns:Set(w.key, b:GetChecked() and true or false) end end)
		return w
	end)
	c.key = key; c.onSet = nil
	c.box:Enable()   -- a pooled row: whatever its last use set (a plugin getter failure disables the box), a core setting is usable
	local cy = layoutRow(c, label, help, 24, 24)
	c.box:ClearAllPoints(); c.box:SetPoint("TOPRIGHT", 0, cy)
	c.box:SetChecked(ns.db[key] and true or false)
	c.box:SetAlpha(1)
	if opts and opts.disabled then
		c.box:SetChecked(opts.checked and true or false); c.box:Disable(); c.box:SetAlpha(0.5)
		c.text:SetTextColor(Skins:Color("muted"))
	end
	self.y = self.y + c:GetHeight()
end

-- below: the options go on their own line under the label and help, left
-- to right, wrapping only if they don't fit (for long option labels).
-- extra (optional): { label = ..., onClick = fn }, a small button under the
-- choices on the right, beside the help line (the Skin row's Reload Interface).
function Panel:Seg(key, label, options, help, below, extra)
	local s = acquire(self, "seg", function(p)
		local w = CreateFrame("Frame", nil, p); w:SetSize(ROW_W, LINE)
		w.text = fs(w); w.help = fs(w); w.btns = {}
		return w
	end)
	s.key = key
	-- Size buttons first so the row knows how wide the control is.
	local total = 0
	for i, opt in ipairs(options) do
		local b = s.btns[i]
		if not b then
			b = ns.TextButton(s, "", 60, function(btn) ns:Set(btn.parentKey, btn.value) end)
			b:SetHeight(22)
			s.btns[i] = b
		end
		b.parentKey, b.value = key, opt[1]
		b.label:SetText(opt[2])
		b.w = math.max(44, b.label:GetStringWidth() + 16)
		b:SetWidth(b.w)
		local current
		if key == "__openWindows" then current = ns.db.bagWindows and "all" or (ns.db.reagentWindow and "reagent" or "main")
		else current = ns.db[key] end
		b:SetActive(current == opt[1])
		b:Show()
		total = total + b.w + 2
	end
	for j = #options + 1, #s.btns do s.btns[j]:Hide() end
	local cy, fits = layoutRow(s, label, help, below and rowW + 1 or total, 22)
	if fits then
		local x = 0
		for i = #options, 1, -1 do
			local b = s.btns[i]
			b:ClearAllPoints(); b:SetPoint("TOPRIGHT", s, "TOPRIGHT", -x, cy)
			x = x + b.w + 2
		end
	else
		-- Own line(s), flowing left to right and wrapping if needed.
		local x, line = 0, 0
		for i = 1, #options do
			local b = s.btns[i]
			if x + b.w > rowW then x = 0; line = line + 1 end
			b:ClearAllPoints(); b:SetPoint("TOPLEFT", s, "TOPLEFT", x, cy - line * 24)
			x = x + b.w + 2
		end
		if line > 0 then s:SetHeight(s:GetHeight() + line * 24) end
	end
	if extra then
		if not s.extraBtn then
			s.extraBtn = ns.TextButton(s, "", 60, function(btn) if btn.onExtra then btn.onExtra(btn) end end)
			s.extraBtn:SetHeight(22)
		end
		local e = s.extraBtn
		e.onExtra = extra.onClick
		e.label:SetText(extra.label)
		e:SetWidth(math.max(44, e.label:GetStringWidth() + 16))
		e:ClearAllPoints()
		if fits then
			-- Under the choices, on the right, beside the help line.
			e:SetPoint("TOPRIGHT", s, "TOPRIGHT", 0, cy - 26)
			s:SetHeight(math.max(s:GetHeight(), -cy + 26 + 22 + 8))
		else
			e:SetPoint("TOPLEFT", s, "TOPLEFT", 0, -(s:GetHeight() - 4))
			s:SetHeight(s:GetHeight() + 26)
		end
		e:Show()
	elseif s.extraBtn then
		s.extraBtn:Hide()
	end
	self.y = self.y + s:GetHeight()
end

-- Number rows: minus, a box you can type into, plus. Whole numbers only;
-- percentages are typed as whole percents (85 for 85%). Out-of-range
-- values snap to the nearest limit.
local function stepShow(w)
	local v = ns.db[w.key] or 0
	w.value:SetText(tostring(w.percent and math.floor(v * 100 + 0.5) or math.floor(v + 0.5)))
end
local function stepCommit(box)
	local w = box:GetParent()
	local txt = box:GetText() or ""
	local n = txt:match("^%d+$") and tonumber(txt) or nil
	if n then ns:Set(w.key, w.percent and n / 100 or n) end
	stepShow(w)
	box:ClearFocus()
end
-- info (1.4.2): an optional { title, lines, keywords } for a small info icon beside the label, with its own tooltip
-- (the same icon BagSmith uses for its held-back explanations); its words are searchable too.
function Panel:Step(key, label, step, fmt, help, info)
	local s = acquire(self, "step", function(p)
		local w = CreateFrame("Frame", nil, p); w:SetSize(ROW_W, LINE)
		w.text = fs(w); w.help = fs(w)
		w.value = CreateFrame("EditBox", nil, w, "InputBoxTemplate")
		w.value:SetSize(48, 22); w.value:SetAutoFocus(false); w.value:SetMaxLetters(4)
		if w.value.SetNumeric then w.value:SetNumeric(true) end   -- digits only: no decimals, no minus sign
		w.value:SetJustifyH("CENTER")
		w.value:SetScript("OnEnterPressed", stepCommit)
		w.value:SetScript("OnEscapePressed", function(box) stepShow(box:GetParent()); box:ClearFocus() end)
		w.value:SetScript("OnEditFocusLost", function(box) stepShow(box:GetParent()) end)
		-- A fixed "%" inside the box for percentages; part of the frame, not the text.
		w.unit = w.value:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		w.unit:SetPoint("RIGHT", w.value, "RIGHT", -6, 0)
		w.unit:SetText("%")
		w.minus = ns.IconButton(w, "Interface\\AddOns\\BagSmith\\Media\\ui-minus.tga", "Decrease", function(b) local pr = b:GetParent(); ns:Set(pr.key, ns.db[pr.key] - pr.step) end); w.minus:SetSize(22, 22)
		w.plus = ns.IconButton(w, "Interface\\AddOns\\BagSmith\\Media\\ui-plus.tga", "Increase", function(b) local pr = b:GetParent(); ns:Set(pr.key, ns.db[pr.key] + pr.step) end); w.plus:SetSize(22, 22)
		return w
	end)
	s.key, s.step = key, step
	s.percent = fmt:find("%%%%") ~= nil
	local cy = layoutRow(s, label, help, 24 + 56 + 24 + 12, 22)
	s.plus:ClearAllPoints(); s.plus:SetPoint("TOPRIGHT", s, "TOPRIGHT", 0, cy)
	s.value:SetSize(56, 22)
	s.value:ClearAllPoints(); s.value:SetPoint("RIGHT", s.plus, "LEFT", -6, 0)
	s.minus:ClearAllPoints(); s.minus:SetPoint("RIGHT", s.value, "LEFT", -6, 0)
	s.unit:SetShown(s.percent); s.unit:SetTextColor(Skins:Color("muted"))
	-- Every box reserves the same space on both sides, so numbers sit in the
	-- same spot whether or not the % is shown in the right-hand space.
	if s.value.SetTextInsets then s.value:SetTextInsets(12, 12, 0, 0) end
	stepShow(s)
	if info then
		if not s.info then s.info = ns.Why.InfoButton(s) end
		s.info.title, s.info.lines = info.title, info.lines
		s.info:ClearAllPoints(); s.info:SetPoint("LEFT", s.text, "LEFT", (s.text:GetStringWidth() or 0) + 6, 0)
		s.info:Show()
	elseif s.info then
		s.info:Hide()
	end
	self.y = self.y + s:GetHeight()
end

-- A color setting: swatch opens the game's color picker; hex box for exact values. Any six-hex-digit
-- setting (the accent, the item-level color) uses the same row.
local function applyColor(key, hex)
	if ns:Set(key, hex) then return true end
	ns:Print("Enter a color as six hex digits, for example fac775.")
	return false
end
local function applyAccent(hex) return applyColor("accent", hex) end
local function openPicker(key, current)
	if not ColorPickerFrame then return end
	local r, g, b = Skins.hexToRGB(current)
	-- The picker stays open on its own; it only changes the profile it was
	-- opened for (a profile switch in the meantime makes it do nothing).
	local owner = ns.db
	local function commit()
		if ns.db ~= owner then return end
		local nr, ng, nb
		if ColorPickerFrame.GetColorRGB then nr, ng, nb = ColorPickerFrame:GetColorRGB() else nr, ng, nb = r, g, b end
		applyColor(key, ("%02x%02x%02x"):format(math.floor(nr * 255 + 0.5), math.floor(ng * 255 + 0.5), math.floor(nb * 255 + 0.5)))
	end
	local function cancel() if ns.db == owner then applyColor(key, current) end end
	if ColorPickerFrame.SetupColorPickerAndShow then
		ColorPickerFrame:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false, swatchFunc = commit, cancelFunc = cancel })
	else
		ColorPickerFrame.hasOpacity = false
		ColorPickerFrame.func, ColorPickerFrame.cancelFunc = commit, cancel
		ColorPickerFrame:SetColorRGB(r, g, b)
		ColorPickerFrame:Show()
	end
end
function Panel:Color(key, label, help)
	local c = acquire(self, "color", function(p)
		local w = CreateFrame("Frame", nil, p); w:SetSize(ROW_W, LINE)
		w.text = fs(w); w.help = fs(w)
		w.swatch = CreateFrame("Button", nil, w, "BackdropTemplate"); w.swatch:SetSize(26, 22)
		w.swatch:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
		w.swatch:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
		w.swatch:SetScript("OnClick", function(b) local row = b:GetParent(); openPicker(row.key, ns.db[row.key]) end)
		w.swatch:SetScript("OnEnter", function(b) GameTooltip:SetOwner(b, "ANCHOR_TOP"); ns.TipText(GameTooltip, "Pick a color"); GameTooltip:Show() end)
		w.swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)
		ns.HoverWash(w.swatch, 0)
		w.box = CreateFrame("EditBox", nil, w, "InputBoxTemplate"); w.box:SetSize(72, 22); w.box:SetAutoFocus(false); w.box:SetMaxLetters(7)
		w.box:SetScript("OnEnterPressed", function(box) if applyColor(box:GetParent().key, box:GetText()) then box:ClearFocus() end end)
		w.box:SetScript("OnEscapePressed", function(box) box:SetText(ns.db[box:GetParent().key]); box:ClearFocus() end)
		w.reset = ns.TextButton(w, "Reset", 52, function(b) local row = b:GetParent(); applyColor(row.key, ns.DEFAULTS and ns.DEFAULTS[row.key] or Skins.DEFAULT_ACCENT) end); w.reset:SetHeight(22)
		return w
	end)
	c.key = key
	local cy = layoutRow(c, label, help, 26 + 4 + 72 + 4 + 52 + 8, 22)
	c.reset:ClearAllPoints(); c.reset:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, cy)
	c.box:ClearAllPoints(); c.box:SetPoint("RIGHT", c.reset, "LEFT", -6, 0)
	c.swatch:ClearAllPoints(); c.swatch:SetPoint("RIGHT", c.box, "LEFT", -8, 0)
	c.swatch:SetBackdropColor(Skins.hexToRGB(ns.db[key]))
	c.box:SetText(ns.db[key])
	self.y = self.y + c:GetHeight()
end

-- Profile rows: name, Use, Copy into current, Delete (Default cannot be deleted).
function Panel:Profiles()
	local names = ns.Profiles:List()
	local l = acquire(self, "profiles", function(p) local w = CreateFrame("Frame", nil, p); w:SetSize(ROW_W, 1); w.rows = {}; return w end)
	l:SetWidth(rowW)
	for i, name in ipairs(names) do
		local r = l.rows[i]
		if not r or not r.isProfile then
			r = CreateFrame("Frame", nil, l); r:SetSize(rowW, 30); r.isProfile = true
			r.text = fs(r); r.text:SetPoint("LEFT", 4, 0); r.text:SetPoint("RIGHT", -190, 0); r.text:SetWordWrap(false)
			r.use = ns.TextButton(r, "Assign", 60, function(b) local row = b:GetParent(); local ok, err = ns.Profiles:Use(row.name); if not ok then ns:Print(err) end end)
			r.use:SetHeight(22); r.use:SetPoint("RIGHT", -110, 0)
			r.use.tip = "Assign this profile to this character"
			r.copy = ns.TextButton(r, "Copy", 52, function(b) local row = b:GetParent(); local ok, err = ns.Profiles:CopyFrom(row.name); ns:Print(ok and ("Copied %s into %s."):format(row.name, ns.profileName) or err) end)
			r.copy:SetHeight(22); r.copy:SetPoint("RIGHT", -54, 0)
			r.copy.tip = "Copy this profile's settings into the profile you are using"
			r.del = ns.IconButton(r, "Interface\\AddOns\\BagSmith\\Media\\ui-close.tga", "Delete this profile", function(b)
				-- The name is captured now: the row can be reused before Yes is clicked.
				local target = b:GetParent().name
				ns.Confirm(b, ("Delete the profile \"%s\"?\nCharacters using it go back to Default."):format(target), function()
					local ok, err = ns.Profiles:Delete(target)
					if not ok then ns:Print(err) end
				end)
			end)
			r.del:SetSize(22, 22); r.del:SetPoint("RIGHT", -20, 0)
			l.rows[i] = r
		end
		r.name = name
		local active = name == ns.profileName
		r.text:SetText(name .. (active and "  (this character)" or "")); r.text:SetTextColor(Skins:Color(active and "heading" or "text"))
		r.use:SetActive(active); r.use:SetShown(not active)
		r.copy:SetShown(not active)
		r.del:SetShown(name ~= "Default")
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", l, "TOPLEFT", 0, -(i - 1) * 30); r:SetWidth(rowW); r:Show()
	end
	for j = #names + 1, #l.rows do l.rows[j]:Hide() end
	l:SetHeight(math.max(1, #names * 30))
	self.y = self.y + #names * 30 + 10
end

-- Ordered list with optional checkbox per row and up/down arrows.
-- items: { { id=, label=, checked=bool|nil } }; onCheck(id, on); onMove(id, delta)
function Panel:List(items, onCheck, onMove)
	local l = acquire(self, "list", function(p) local w = CreateFrame("Frame", nil, p); w:SetSize(ROW_W, 1); w.rows = {}; return w end)
	l:SetWidth(rowW)
	for i, it in ipairs(items) do
		local r = l.rows[i]
		if not r then
			r = CreateFrame("Frame", nil, l); r:SetSize(rowW, 26)
			r.box = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate"); r.box:SetSize(20, 20); r.box:SetPoint("LEFT", 0, 0)
			r.text = fs(r); r.text:SetPoint("LEFT", 24, 0); r.text:SetPoint("RIGHT", -54, 0); r.text:SetWordWrap(false)
			r.up = ns.IconButton(r, "Interface\\AddOns\\BagSmith\\Media\\ui-chev-up.tga", "Move Up", function(b) local row = b:GetParent(); row.onMove(row.id, -1) end); r.up:SetSize(22, 22); r.up:SetPoint("RIGHT", -24, 0)
			r.down = ns.IconButton(r, "Interface\\AddOns\\BagSmith\\Media\\ui-chev-down.tga", "Move Down", function(b) local row = b:GetParent(); row.onMove(row.id, 1) end); r.down:SetSize(22, 22); r.down:SetPoint("RIGHT", 0, 0)
			r.box:SetScript("OnClick", function(b) local row = b:GetParent(); row.onCheck(row.id, b:GetChecked() and true or false) end)
			-- A row can explain itself (for example why it can't be ticked).
			local function tipOn(f)
				local row = f.tipRow or f
				if row.tip and ns.TooltipsOK() then GameTooltip:SetOwner(f, "ANCHOR_RIGHT"); ns.TipText(GameTooltip, row.tip, 1, 1, 1, 1, true); GameTooltip:Show() end
			end
			r.box.tipRow = r
			r.box:SetScript("OnEnter", tipOn); r.box:SetScript("OnLeave", function() GameTooltip:Hide() end)
			r:SetScript("OnEnter", tipOn); r:SetScript("OnLeave", function() GameTooltip:Hide() end)
			-- Zebra stripes, and a highlight on the row under the pointer (its
			-- checkbox, label and arrows count as the row), so each row's
			-- arrows clearly belong to it.
			r.stripe = r:CreateTexture(nil, "BACKGROUND")
			r.stripe:SetAllPoints(); r.stripe:SetColorTexture(1, 1, 1, LIST_STRIPE)
			r.hover = r:CreateTexture(nil, "BACKGROUND", nil, 1)
			r.hover:SetAllPoints(); r.hover:SetColorTexture(1, 1, 1, LIST_HOVER); r.hover:Hide()
			local function sync(part) local row = part.rowOf or part; row.hover:SetShown(row:IsMouseOver() and true or false) end
			r:EnableMouse(true)
			r:HookScript("OnEnter", sync); r:HookScript("OnLeave", sync)
			for _, part in ipairs({ r.box, r.up, r.down }) do
				part.rowOf = r
				part:HookScript("OnEnter", sync); part:HookScript("OnLeave", sync)
			end
			r:HookScript("OnHide", function(row) row.hover:Hide() end)
			l.rows[i] = r
		end
		r.id, r.onCheck, r.onMove = it.id, onCheck, onMove
		r.tip = it.tip
		r.stripe:SetShown(i % 2 == 0)   -- the first row of every list is plain
		r.text:SetText(it.label); r.text:SetTextColor(Skins:Color((it.disabled or it.dim) and "muted" or "text"))
		r.box:SetShown(it.checked ~= nil)
		r.box:SetChecked(it.checked and true or false)
		-- Greyed out: shown, can't be ticked.
		if it.disabled then r.box:Disable(); r.box:SetAlpha(0.5) else r.box:Enable(); r.box:SetAlpha(1) end
		r.text:ClearAllPoints(); r.text:SetPoint("LEFT", it.checked ~= nil and 24 or 4, 0); r.text:SetPoint("RIGHT", -54, 0)
		r.up:SetShown(i > 1); r.down:SetShown(i < #items)
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", l, "TOPLEFT", 0, -(i - 1) * 26); r:SetWidth(rowW); r:Show()
	end
	for j = #items + 1, #l.rows do l.rows[j]:Hide() end
	l:SetHeight(math.max(1, #items * 26))
	self.y = self.y + #items * 26 + 10
end

-- Icon Corners (1.5.0-beta10): dropdowns. At the top, two small previews side by side (your real icon at your Icon
-- Size, and a List view row's icon, each magnified as a whole so text marks keep their proportions). Below, a group
-- per corner: a dropdown for the mark that shows, then optional "then" backups (+ adds one, x removes it) for items
-- the first doesn't apply to. A mark used in another corner is listed "(in Top Right)" and moves here when chosen;
-- None empties a corner. The stack count is locked first in its corner. Marks in no corner are listed as not shown,
-- other addons' new ones flagged. (Beta2 to beta9 tried cards, lists and a drag-and-drop editor.)
local MEDIA = "Interface\\AddOns\\BagSmith\\Media\\"
local SAMPLE_PX, ROW_SAMPLE_SCALE, PREVIEW_H = 56, 1.25, 84
local GROUP_HEAD, DROP_H, DROP_GAP, GROUP_GAP, THEN_W = 18, 24, 4, 5, 34
local function makeDrop(parent)
	local d = CreateFrame("Button", nil, parent, "BackdropTemplate")
	d:SetHeight(DROP_H)
	if d.SetBackdrop then d:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }) end
	d.label = fs(d); d.label:SetPoint("LEFT", d, "LEFT", 8, 0); d.label:SetPoint("RIGHT", d, "RIGHT", -22, 0)
	if d.label.SetJustifyH then d.label:SetJustifyH("LEFT") end
	if d.label.SetWordWrap then d.label:SetWordWrap(false) end
	d.chev = d:CreateTexture(nil, "ARTWORK"); d.chev:SetSize(10, 10); d.chev:SetPoint("RIGHT", d, "RIGHT", -8, 0); d.chev:SetTexture(MEDIA .. "ui-chev-down.tga")
	d:RegisterForClicks("LeftButtonUp")
	d:SetScript("OnClick", function(self) if self.onPick then self.onPick(self) end end)
	d:SetScript("OnEnter", function(self)
		if self.tip and ns.TooltipsOK() then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); ns.TipText(GameTooltip, self.full or "", 1, 1, 1); ns.TipLine(GameTooltip, self.tip, nil, nil, nil, true); GameTooltip:Show() end
	end)
	d:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return d
end
local function styleDrop(d, locked)
	if not d.SetBackdropColor then return end
	local r, g, bb = Skins:Color("text"); d:SetBackdropColor(r, g, bb, locked and 0.03 or 0.07)
	local lr, lg, lb = Skins:Color("line"); d:SetBackdropBorderColor(lr, lg, lb, 1)
end
local function makeGroupRow(group)
	local r = CreateFrame("Frame", nil, group); r:SetHeight(DROP_H)
	r.thenLabel = fs(r); r.thenLabel:SetPoint("RIGHT", r, "LEFT", THEN_W - 6, 0); r.thenLabel:SetText("then")
	r.drop = makeDrop(r)
	r.remove = ns.IconButton(r, MEDIA .. "ui-close.tga", "Remove This Backup", function(b) local row = b:GetParent(); if row.onRemove then row.onRemove() end end); r.remove:SetSize(16, 16)
	r.add = ns.IconButton(r, MEDIA .. "ui-plus.tga", "Add a Backup", function(b) local row = b:GetParent(); if row.onAdd then row.onAdd(b) end end); r.add:SetSize(16, 16)
	r.lock = r:CreateTexture(nil, "ARTWORK"); r.lock:SetSize(12, 12); r.lock:SetTexture(MEDIA .. "ui-lock.tga")
	r.add:SetPoint("RIGHT", r, "RIGHT", -4, 0)
	r.remove:SetPoint("RIGHT", r, "RIGHT", -26, 0)
	r.lock:SetPoint("CENTER", r.remove, "CENTER", 0, 0)
	r.drop:SetPoint("LEFT", r, "LEFT", THEN_W, 0); r.drop:SetPoint("RIGHT", r, "RIGHT", -48, 0)
	return r
end
function Panel:CornerCards()
	local C = ns.Corners
	local w = acquire(self, "cornerCards", function(p)
		local f = CreateFrame("Frame", nil, p); f:SetSize(ROW_W, 10)
		f.preview = ns.Buttons:GetCached(f, 1)
		f.previewList = ns.Buttons:GetCached(f, 2)
		for _, b in ipairs({ f.preview, f.previewList }) do
			b.bsPreview, b.bsDisplayOnly = true, true
			if b.EnableMouse then b:EnableMouse(false) end
		end
		f.iconsLabel = fs(f); f.iconsLabel:SetText("Icons view")
		f.listLabel = fs(f); f.listLabel:SetText("List view")
		f.listQty = fs(f); if f.listQty.SetJustifyH then f.listQty:SetJustifyH("RIGHT") end
		f.listName = fs(f); f.listName:SetText("Sample")
		-- a corner of the sample lights up while its group is hovered
		f.hi = {}
		for _, corner in ipairs({ "top_left", "top_right", "bottom_left", "bottom_right" }) do
			local h = CreateFrame("Frame", nil, f.preview, "BackdropTemplate")
			if h.SetBackdrop then h:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }) end
			h:Hide(); f.hi[corner] = h
		end
		f.groups = {}
		for _, corner in ipairs({ "top_left", "top_right", "bottom_left", "bottom_right" }) do
			local g = CreateFrame("Frame", nil, f, "BackdropTemplate"); g.corner = corner
			if g.SetBackdrop then g:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }) end
			g.glyph = CreateFrame("Frame", nil, g, "BackdropTemplate"); g.glyph:SetSize(9, 9); g.glyph:SetPoint("TOPLEFT", g, "TOPLEFT", 8, -5)
			if g.glyph.SetBackdrop then g.glyph:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }) end
			g.dot = g.glyph:CreateTexture(nil, "ARTWORK"); g.dot:SetSize(3, 3)
			g.dot:SetPoint(corner:upper():gsub("_", ""), g.glyph, corner:upper():gsub("_", ""), corner:find("left") and 1 or -1, corner:find("top") and -1 or 1)
			g.title = fs(g); g.title:SetPoint("LEFT", g.glyph, "RIGHT", 6, 0)
			g.rows = {}
			g:EnableMouse(true)
			g:SetScript("OnEnter", function(self) f.hi[self.corner]:Show() end)
			g:SetScript("OnLeave", function(self) if not self:IsMouseOver() then f.hi[self.corner]:Hide() end end)
			f.groups[corner] = g
		end
		f.unused = fs(f); if f.unused.SetJustifyH then f.unused:SetJustifyH("LEFT") end
		return f
	end)
	Panel.cornerEditor = w
	w:SetWidth(rowW)
	local refresh = function() Panel:Refresh() end

	-- the previews: real size, magnified
	local half = math.floor(rowW / 2)
	local cell = math.max(16, ns.db.iconSize or 37)
	local scale = SAMPLE_PX / cell
	local b = w.preview
	ns.Buttons:SetMode(b, "cell"); b:ClearAllPoints(); b:SetSize(cell, cell)
	if b.SetScale then b:SetScale(scale) end
	b:SetPoint("TOP", w, "TOPLEFT", (half / 2) / scale, -2 / scale)   -- (a scaled frame's offsets are in its own units)
	ns.Buttons:Fill(b, C.SAMPLE); C:DrawPreview(b, "cell", cell - 4); b:Show()
	for corner, h in pairs(w.hi) do
		h:ClearAllPoints(); h:SetSize(math.floor(cell * 0.45 + 0.5), math.floor(cell * 0.45 + 0.5))
		h:SetPoint(corner:upper():gsub("_", ""), b, corner:upper():gsub("_", ""), 0, 0)
		if h.SetBackdropBorderColor then local r, g, bb = Skins:Color("accent"); h:SetBackdropBorderColor(r, g, bb, 1) end
	end
	w.iconsLabel:ClearAllPoints(); w.iconsLabel:SetPoint("TOP", w, "TOPLEFT", half / 2, -(2 + SAMPLE_PX + 4)); w.iconsLabel:SetTextColor(Skins:Color("muted"))
	local lb = w.previewList
	ns.Buttons:SetMode(lb, "cell"); lb:ClearAllPoints(); lb:SetSize(24, 24)
	if lb.SetScale then lb:SetScale(ROW_SAMPLE_SCALE) end
	lb:SetPoint("CENTER", w, "TOPLEFT", (half + half / 2) / ROW_SAMPLE_SCALE, -(2 + SAMPLE_PX / 2) / ROW_SAMPLE_SCALE)
	ns.Buttons:Fill(lb, C.SAMPLE); C:DrawPreview(lb, "row", 20); lb:Show()
	w.listQty:ClearAllPoints(); w.listQty:SetPoint("RIGHT", w, "TOPLEFT", half + half / 2 - 24 * ROW_SAMPLE_SCALE / 2 - 6, -(2 + SAMPLE_PX / 2))
	w.listQty:SetText(C:RowCountOnIcon() and "" or tostring(C.SAMPLE.count)); w.listQty:SetTextColor(Skins:Color("text"))
	w.listName:ClearAllPoints(); w.listName:SetPoint("LEFT", w, "TOPLEFT", half + half / 2 + 24 * ROW_SAMPLE_SCALE / 2 + 6, -(2 + SAMPLE_PX / 2)); w.listName:SetTextColor(Skins:Color("text"))
	w.listLabel:ClearAllPoints(); w.listLabel:SetPoint("TOP", w, "TOPLEFT", half + half / 2, -(2 + SAMPLE_PX + 4)); w.listLabel:SetTextColor(Skins:Color("muted"))

	-- what a dropdown lists
	local function label(id) local wd = C.widgets[id]; return wd and wd.label or (id .. " (not loaded)") end
	local function noteFor(id)
		local wd = C.widgets[id]
		if not wd then return "This mark's addon isn't loaded. Its place is kept for when it is." end
		if id == C.PROTECTED then return "The stack count always shows when an item has a stack, first in its corner. Choose it in another corner's first dropdown to move it there." end
		local t = (wd.builtin and C:BuiltinNote(id)) or "The first mark in a corner that applies to an item is the one shown."
		if C.COLUMN_NOTE[id] then t = t .. " " .. C.COLUMN_NOTE[id] end
		if not wd.builtin and not wd.rows then t = t .. " Icons view only: its addon hasn't added List view support." end
		return t
	end
	local function choices(corner, index, cur, forAdd)
		local items, here = {}, ns.db.iconCorners[corner] or {}
		if not forAdd and index == 1 and cur ~= C.PROTECTED then
			-- (1.5.0-beta11, audit F2) None empties the whole corner, backups included
			items[#items + 1] = { text = "None", onClick = function() C:ClearCorner(corner); refresh() end }
		end
		for _, id in ipairs(C.order) do
			local inHere = ns.IndexOf(here, id) ~= nil
			local ok = not inHere and not (id == C.PROTECTED and (forAdd or index > 1))
			if ok then
				local from = C:CornerOf(id)
				local text = label(id) .. (from and (" (in " .. C.LABEL[from] .. ")") or "") .. ((not from and C:IsNew(id)) and " (new)" or "")
				items[#items + 1] = { text = text, onClick = function()
					if forAdd then C:PlaceAt(id, corner) else C:SetSlot(corner, index, id) end
					refresh()
				end }
			end
		end
		if #items == 0 then items[1] = { text = "No other marks", color = { Skins:Color("muted") }, onClick = function() end } end
		items[#items].gap = true
		items[#items + 1] = { text = "Cancel", color = { Skins:Color("muted") }, onClick = function() end }
		return items
	end
	Panel.CornerChoices = choices

	-- the groups
	local y = PREVIEW_H
	for _, corner in ipairs(C.CORNERS) do
		local g = w.groups[corner]
		g.title:SetText(C.LABEL[corner]); g.title:SetTextColor(Skins:Color("muted"))
		if g.glyph.SetBackdropBorderColor then local r, gg, bb = Skins:Color("text"); g.glyph:SetBackdropBorderColor(r, gg, bb, 0.6) end
		g.dot:SetColorTexture(Skins:Color("accent"))
		local ids = ns.db.iconCorners[corner] or {}
		local n = math.max(1, #ids)
		for i = 1, n do
			local r = g.rows[i]
			if not r then r = makeGroupRow(g); g.rows[i] = r end
			local id = ids[i]
			local locked = id == C.PROTECTED
			r.id, r.index = id, i
			r.thenLabel:SetShown(i > 1); r.thenLabel:SetTextColor(Skins:Color("muted"))
			local d = r.drop
			d.full = id and label(id) or "None"
			d.label:SetText(id and label(id) or "None")
			d.label:SetTextColor(Skins:Color((id and not (C.widgets[id] and C.widgets[id].builtin and C:BuiltinNote(id))) and C.widgets[id] and "text" or "muted"))
			d.tip = id and noteFor(id) or "Nothing shows in this corner. Choose a mark."
			d.chev:SetShown(not locked)
			d.locked = locked
			d.onPick = (not locked) and function(anchor) ns.ShowMenu(choices(corner, i, id, false), anchor) end or nil
			styleDrop(d, locked)
			r.lock:SetShown(locked)
			r.remove:SetShown(i > 1 and not locked)
			r.onRemove = function() C:SetSlot(corner, i, nil); refresh() end
			r.add:SetShown(i == n and #ids > 0)
			r.onAdd = function(anchor) ns.ShowMenu(choices(corner, #ids + 1, nil, true), anchor) end
			r:ClearAllPoints(); r:SetPoint("TOPLEFT", g, "TOPLEFT", 0, -(GROUP_HEAD + (i - 1) * (DROP_H + DROP_GAP))); r:SetPoint("RIGHT", g, "RIGHT", -4, 0); r:Show()
		end
		for j = n + 1, #g.rows do g.rows[j]:Hide() end
		local h = GROUP_HEAD + n * (DROP_H + DROP_GAP) + 3
		g:ClearAllPoints(); g:SetPoint("TOPLEFT", w, "TOPLEFT", 0, -y); g:SetSize(rowW, h); g:Show()
		if g.SetBackdropColor then local r, gg, bb = Skins:Color("text"); g:SetBackdropColor(r, gg, bb, 0.03); local lr, lg, lb2 = Skins:Color("line"); g:SetBackdropBorderColor(lr, lg, lb2, 1) end
		y = y + h + GROUP_GAP
	end
	-- what isn't shown anywhere
	local unused = {}
	for _, id in ipairs(C.order) do
		if not C:CornerOf(id) then unused[#unused + 1] = label(id) .. (C:IsNew(id) and " (new)" or "") end
	end
	w.unused:ClearAllPoints(); w.unused:SetPoint("TOPLEFT", w, "TOPLEFT", 2, -(y + 2)); w.unused:SetWidth(rowW - 4)
	w.unused:SetText(#unused > 0 and ("Not shown: " .. table.concat(unused, ", ")) or "Every mark is in a corner.")
	w.unused:SetTextColor(Skins:Color("muted"))
	local uh = (w.unused.GetStringHeight and w.unused:GetStringHeight() or 14)
	local total = y + 4 + uh
	w:SetHeight(total)
	self.y = self.y + total + 10
end
function Panel:IconCorners()
	local C = ns.Corners
	if not C then return end
	-- (1.5.0-beta6) the info about other addons' marks sits at the end of the line about them, below the cards;
	-- the heading stays plain (its search words still find the section)
	local othersInfo = {
		title = "Marks from other addons",
		lines = {
			"When an addon that marks items supports BagSmith, its marks appear here on their own, in the corner the addon suggests. You can move, reorder or hide them like BagSmith's.",
			"If an addon's marks don't show up here, that addon doesn't support BagSmith yet.",
			"|cff999999Addon authors: see BagSmith's API notes.|r",
		},
		keywords = "addon addons marks mark other",
	}
	local names = {}
	for _, id in ipairs(C.order) do local wd = C.widgets[id]; if wd then names[#names + 1] = wd.label end end
	self:Head("Icon Corners", { noIcon = true, lines = othersInfo.lines, keywords = othersInfo.keywords .. " " .. table.concat(names, " ") })
	self:Text("Pick the mark each corner shows. Add a backup for items the first one doesn't apply to. In List view, Item Level and Stack Count show in their columns instead.")
	self:CornerCards()
	local others = false
	for _, id in ipairs(C.order) do local wd = C.widgets[id]; if wd and not wd.builtin then others = true end end
	self:Text(others and "Marks from other addons are listed in the cards above." or "Other addons' marks appear here when they support BagSmith.")
	local line = self.pools.text[self.counts.text]
	if line and not self.filter then
		if not line.info then line.info = ns.Why.InfoButton(line) end
		line.info.title, line.info.lines = othersInfo.title, othersInfo.lines
		line.info:ClearAllPoints(); line.info:SetPoint("LEFT", line.text, "LEFT", (line.text:GetStringWidth() or 0) + 6, 0)
		line.info:Show()
		line.othersLine = true
	end
	self:Button("Reset Icon Corners", function() C:Reset(); Panel:Refresh() end)
end

-- A key binding row: name, current key, Set Key and Clear.
function Panel:Binding(action, label)
	local w = acquire(self, "bind", function(p)
		local r = CreateFrame("Frame", nil, p); r:SetSize(ROW_W, LINE + 6)
		r.text = fs(r); r.text:SetPoint("LEFT", 0, 0)
		r.key = fs(r); r.key:SetPoint("LEFT", 190, 0)
		r.clear = ns.TextButton(r, "Clear", 64, function(b)
			local row = b:GetParent()
			local msg = ns.KeyBinds:Clear(row.action)
			if msg then ns:Print(msg) end
			Panel:Refresh()
		end)
		r.clear:SetHeight(22); r.clear:SetPoint("RIGHT", 0, 0)
		r.set = ns.TextButton(r, "Set Key", 80, function(b)
			local row = b:GetParent()
			row.key:SetText("Press a key...")
			ns.KeyBinds:Capture(row.action, function(msg)
				if type(msg) == "string" then ns:Print(msg) end
				Panel:Refresh()
			end)
		end)
		r.set:SetHeight(22); r.set:SetPoint("RIGHT", r.clear, "LEFT", -6, 0)
		return r
	end)
	local s = Skins:Current()
	w.action = action
	w.text:SetText(label); w.text:SetTextColor(unpack(s.text))
	local key = ns.KeyBinds:Key(action)
	w.key:SetText(key or "Not Set"); w.key:SetTextColor(unpack(key and s.heading or s.muted))
	w.set:SetActive(false); w.clear:SetActive(false)
	if w.clear.SetEnabled then w.clear:SetEnabled(key ~= nil) end
	w.clear:SetAlpha(key and 1 or 0.45)
	self.y = self.y + LINE + 10
end

-- A custom section: its name and item count, with Rename and Delete.
-- The heading over the custom sections' Show When Empty checkboxes.
function Panel:CustomSectionHeader()
	local w = acquire(self, "csechead", function(p)
		local w = CreateFrame("Frame", nil, p); w:SetHeight(18)
		w.text = fs(w); w.text:SetPoint("RIGHT", -62, 0); w.text:SetJustifyH("RIGHT"); w.text:SetText("Show When Empty")
		return w
	end)
	w.text:SetTextColor(Skins:Color("muted"))
	self.y = self.y + 20
end
-- A custom section: its name and item count, Show When Empty (a checkbox),
-- then a pencil (Rename) and an x (Delete).
function Panel:CustomSectionRow(c)
	local w = acquire(self, "csec", function(p)
		local w = CreateFrame("Frame", nil, p); w:SetHeight(26)
		w.text = fs(w); w.text:SetPoint("LEFT", 6, 0)
		w.del = ns.IconButton(w, "Interface\\AddOns\\BagSmith\\Media\\ui-close.tga", "Delete this section", function(b) ns.Sections:ConfirmDelete(b:GetParent().id, b) end)
		w.del:SetSize(18, 18); w.del:SetPoint("RIGHT", -4, 0)
		w.ren = ns.IconButton(w, "Interface\\AddOns\\BagSmith\\Media\\ui-pencil.tga", "Rename this section", function(b) ns.Sections:PromptRename(b:GetParent().id) end)
		w.ren:SetSize(18, 18); w.ren:SetPoint("RIGHT", w.del, "LEFT", -8, 0)
		w.empty = CreateFrame("CheckButton", nil, w, "UICheckButtonTemplate"); w.empty:SetSize(24, 24)
		w.empty:SetPoint("RIGHT", -62, 0)
		w.empty:SetScript("OnClick", function(b) ns.Sections:SetShowEmpty(w.id, b:GetChecked() and true or false); Panel:Refresh() end)
		return w
	end)
	w.id = c.id
	local n = ns.Sections:ItemCount(c.id)
	w.text:SetText(("%s  |cff9a9a9a(%d %s)|r"):format(c.name, n, n == 1 and "item" or "items"))
	w.text:SetTextColor(Skins:Color("text"))
	w.empty:SetChecked(c.showEmpty ~= false)
	w.empty:SetAlpha(ns.db.showEmptySections and 1 or 0.5)
	self.y = self.y + 28
end
-- A gear set: its icon (click or drag it to put the set on an action bar),
-- its name and how many items it holds, then a pencil (Rename) and an x (Delete).
function Panel:GearSetRow(set)
	local w = acquire(self, "gset", function(p)
		local w = CreateFrame("Frame", nil, p); w:SetHeight(28)
		w.pick = CreateFrame("Button", nil, w); w.pick:SetSize(22, 22); w.pick:SetPoint("LEFT", 6, 0)
		w.pick.icon = w.pick:CreateTexture(nil, "ARTWORK"); w.pick.icon:SetAllPoints(); w.pick.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		w.pick:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		w.pick:RegisterForDrag("LeftButton")
		local function pick(b) ns.GearSets:PickUp(b:GetParent().name) end
		w.pick:SetScript("OnClick", pick); w.pick:SetScript("OnDragStart", pick)
		w.pick:SetScript("OnEnter", function(b)
			if not ns.TooltipsOK() then return end
			GameTooltip:SetOwner(b, "ANCHOR_TOP"); ns.TipText(GameTooltip, "Put on Action Bar")
			ns.TipLine(GameTooltip, "Click or drag it, then click an action bar slot to place the set there.", nil, nil, nil, true)
			GameTooltip:Show()
		end)
		w.pick:SetScript("OnLeave", function() GameTooltip:Hide() end)
		w.text = fs(w); w.text:SetPoint("LEFT", w.pick, "RIGHT", 8, 0)
		w.del = ns.IconButton(w, "Interface\\AddOns\\BagSmith\\Media\\ui-close.tga", "Delete this gear set", function(b) ns.GearSets:ConfirmDelete(b:GetParent().name, b) end)
		w.del:SetSize(18, 18); w.del:SetPoint("RIGHT", -4, 0)
		w.ren = ns.IconButton(w, "Interface\\AddOns\\BagSmith\\Media\\ui-pencil.tga", "Rename this gear set", function(b) ns.GearSets:PromptRename(b:GetParent().name) end)
		w.ren:SetSize(18, 18); w.ren:SetPoint("RIGHT", w.del, "LEFT", -8, 0)
		return w
	end)
	w.name = set.name
	w.pick.icon:SetTexture(set.icon or 134400)
	w.text:SetText(("%s  |cff9a9a9a(%s)|r"):format(set.name, ns.GearSets:Summary(set)))
	w.text:SetTextColor(Skins:Color("text"))
	self.y = self.y + 30
end
-- The moved items: the count, with Manage... and Reset All on the same line.
function Panel:MovedRow()
	local w = acquire(self, "moved", function(p)
		local w = CreateFrame("Frame", nil, p); w:SetHeight(26)
		w.text = fs(w); w.text:SetPoint("LEFT", 6, 0); w.text:SetPoint("RIGHT", -180, 0); w.text:SetJustifyH("LEFT")
		w.reset = ns.TextButton(w, "Reset All", 80, function(b)
			local moved = ns.Sections:MoveCount()
			ns.Confirm(b, ("Send all %d moved items back to their own sections?"):format(moved), function() ns.Sections:ClearAll(); Panel:Refresh() end)
		end)
		w.reset:SetHeight(22); w.reset:SetPoint("RIGHT", 0, 0)
		w.manage = ns.TextButton(w, "Manage...", 84, function() ns.Sections:ManageMoves() end)
		w.manage:SetHeight(22); w.manage:SetPoint("RIGHT", w.reset, "LEFT", -6, 0)
		return w
	end)
	local moved = ns.Sections:MoveCount()
	if moved > 0 then
		w.text:SetText(("You've moved %d %s to other sections."):format(moved, moved == 1 and "item" or "items"))
		w.text:SetTextColor(Skins:Color("text"))
		w.manage:Show(); w.reset:Show()
	else
		w.text:SetText("No items moved yet. Drag an item onto a section title, or Alt+Left-click it.")
		w.text:SetTextColor(Skins:Color("muted"))
		w.manage:Hide(); w.reset:Hide()
	end
	w.manage:SetActive(false); w.reset:SetActive(false)
	self.y = self.y + 28
end
-- A section's Show at Vendor and Show at Auction House toggles.
-- The headings over the Show at Vendor / Show at AH checkboxes.
function Panel:VisibilityHeader()
	local w = acquire(self, "vishead", function(p)
		local w = CreateFrame("Frame", nil, p); w:SetHeight(18)
		w.vendor = fs(w); w.vendor:SetPoint("RIGHT", -80, 0); w.vendor:SetJustifyH("RIGHT"); w.vendor:SetText("Show at Vendor")
		w.ah = fs(w); w.ah:SetPoint("RIGHT", 0, 0); w.ah:SetJustifyH("RIGHT"); w.ah:SetText("Show at AH")
		return w
	end)
	w.vendor:SetTextColor(Skins:Color("muted")); w.ah:SetTextColor(Skins:Color("muted"))
	self.y = self.y + 20
end
-- A section's Show at Vendor and Show at AH checkboxes (checked: shown), with
-- a note after its name when it's hidden somewhere.
function Panel:VisibilityRow(id)
	local w = acquire(self, "vis", function(p)
		local w = CreateFrame("Frame", nil, p); w:SetHeight(24)
		w.text = fs(w); w.text:SetPoint("LEFT", 6, 0)
		w.note = fs(w); w.note:SetPoint("LEFT", w.text, "RIGHT", 8, 0)
		local function box(where, x)
			local b = CreateFrame("CheckButton", nil, w, "UICheckButtonTemplate"); b:SetSize(24, 24)
			b:SetPoint("RIGHT", x, 0)
			b:SetScript("OnClick", function(btn) ns.Sections:SetShown(w.id, where, btn:GetChecked() and true or false); Panel:Refresh() end)
			return b
		end
		w.vendor = box("vendor", -80)
		w.ah = box("ah", 0)
		return w
	end)
	w.id = id
	local atVendor, atAH = ns.Sections:Shown(id, "vendor"), ns.Sections:Shown(id, "ah")
	w.text:SetText(ns.Sections:Label(id)); w.text:SetTextColor(Skins:Color("text"))
	local note = (not atVendor and not atAH) and "hidden at both" or (not atVendor) and "hidden at vendors" or (not atAH) and "hidden at the AH" or ""
	w.note:SetText(note); w.note:SetTextColor(Skins:Color("muted"))
	w.vendor:SetChecked(atVendor); w.ah:SetChecked(atAH)
	self.y = self.y + 26
end

-- A section and its pin (1.4.0).
function Panel:PinRow(id)
	local w = acquire(self, "pin", function(p)
		local w = CreateFrame("Frame", nil, p); w:SetHeight(24)
		w.text = fs(w); w.text:SetPoint("LEFT", 6, 0)
		w.box = CreateFrame("CheckButton", nil, w, "UICheckButtonTemplate"); w.box:SetSize(24, 24); w.box:SetPoint("RIGHT", 0, 0)
		w.box:SetScript("OnClick", function(btn) ns.Sections:SetPinned(w.id, btn:GetChecked() and true or false); Panel:Refresh() end)
		return w
	end)
	w.id = id
	w.text:SetText(ns.Sections:Label(id) or id); w.text:SetTextColor(Skins:Color("text"))
	w.box:SetChecked(ns.Sections:Pinned(id))
	self.y = self.y + 26
end
function Panel:Button(label, onClick, width)
	local b = acquire(self, "btn", function(p) local w = ns.TextButton(p, "", 100, function(btn) btn.onClick(btn) end); w:SetHeight(22); return w end)
	b.label:SetText(label); b.onClick = onClick
	b:SetWidth(width or math.max(80, b.label:GetStringWidth() + 20))
	b:SetActive(false)
	self.y = self.y + 26
end
-- Several buttons on one row (1.2.0): { { label, onClick }, ... }, laid out left to right.
function Panel:Buttons(list)
	local x, rowY = 0, self.y
	for _, spec in ipairs(list) do
		local b = acquire(self, "btn", function(p) local w = ns.TextButton(p, "", 100, function(btn) btn.onClick(btn) end); w:SetHeight(22); return w end)
		b.label:SetText(spec[1]); b.onClick = spec[2]
		b:SetWidth(spec[3] or math.max(80, b.label:GetStringWidth() + 20))
		b:SetActive(false)
		b:ClearAllPoints(); b:SetPoint("TOPLEFT", self.frame.child, "TOPLEFT", rowX + x, -rowY)
		x = x + b:GetWidth() + 6
	end
	self.y = rowY + 26
end

function Panel:Edit(placeholder, onEnter)
	local e = acquire(self, "edit", function(p)
		local w = CreateFrame("Frame", nil, p); w:SetSize(ROW_W, LINE + 4)
		w.box = CreateFrame("EditBox", nil, w, "InputBoxTemplate"); w.box:SetPoint("LEFT", 6, 0); w.box:SetSize(150, 22); w.box:SetAutoFocus(false)
		w.go = ns.TextButton(w, "", 90, function(b) local p = b:GetParent(); p.onEnter(p.box:GetText()); p.box:SetText("") end); w.go:SetHeight(22); w.go:SetPoint("LEFT", w.box, "RIGHT", 6, 0)
		w.box:SetScript("OnEnterPressed", function(box) local p = box:GetParent(); p.onEnter(box:GetText()); box:SetText(""); box:ClearFocus() end)
		return w
	end)
	e.onEnter = onEnter
	e.go.label:SetText(placeholder)
	self.y = self.y + LINE + 6
end

------------------------------------------------------------------------
-- Content
------------------------------------------------------------------------
local function orderedList(orderKey, allowedKey, labelOf, hideIds)
	local items = {}
	for _, id in ipairs(ns.db[orderKey]) do
		if not hideIds or not hideIds[id] then
			local checked
			if allowedKey then checked = ns.IndexOf(ns.db[allowedKey], id) ~= nil end
			items[#items + 1] = { id = id, label = labelOf(id), checked = checked }
		end
	end
	return items
end

local pages = {}

pages.profile = function(self, db)
	self:Head("Profile: " .. ns.profileName)
	self:Text("A profile is a saved set of settings. Every character uses Default unless you pick another.")
	self:Text("This character uses: " .. ns.profileName)
	self:Edit("Create Profile", function(name) local ok, err = ns.Profiles:Use(name); if not ok then ns:Print(err) end end)
	self:Head("Share")
	self:Text("A profile code holds all of a profile's settings, including saved sheets. Share yours, or import one to add it as a new profile.")
	self:Button("Share This Profile", function() ns.ShareWindow("share") end, 160)
	self:Button("Import Profile", function() ns.ShareWindow("import") end, 160)
	self:Head("All Profiles")
	self:Text("Assign gives this character that profile's settings. Copy brings another profile's settings into the one this character uses. Deleting a profile moves anyone using it back to Default.")
	self:Profiles()
end

-- General: how BagSmith opens, which of Blizzard's windows it stands in for, and its notices.
pages.general = function(self, db)
	self:Head("Opening BagSmith")
	self:Check("replaceBlizzardBags", "Open with the Bag Keybind (B)", "Turn off to use Blizzard's bags on B and open BagSmith from the minimap icon or /bs instead")
	self:Check("minimap", "Show Minimap Button", "You can still open BagSmith from the addon list with this disabled")
	self:Check("minimapFade", "Fade Minimap Button", "Shows the button only while the pointer is over the minimap")
	self:Head("Blizzard's Interface")
	if ns.Bank and ns.Bank.supported then
		self:Check("replaceBank", "Replace the Bank Window", "Shows your bank in a BagSmith window when you visit a banker")
	else
		self:Text("Bank window replacement is unavailable on this client; the bank opens in Blizzard's window alongside BagSmith's Bank sheet.")
	end
	self:Check("hideBlizzBagBar", "Hide Blizzard's Bag Bar", "Hides the game's own row of bag buttons. The bag strip in BagSmith (the button left of the counts in the footer) does the same job.")
	self:Head("Notices")
	self:Check("quiet", "Hide the Login Message")
	self:Check("whatsNew", "Show What's New After Updates", "After a notable update, a short card shows what's new the first time you open your bags. The What's New button in this window shows it any time.")
end

pages.look = function(self, db)
	self:Head("Skin")
	-- Switching skins is live (no reload needed); Reload Interface is only a safety valve.
	self:Seg("skin", "Skin", { { "modern", "Modern" }, { "classic", "Classic" } },
		"If anything looks off after switching skins, reload the interface.", nil, { label = "Reload Interface", onClick = function()
			if InCombatLockdown() then ns:Print("You can reload the interface once combat ends.") return end
			ReloadUI()
		end })
	self:Head("Colors")
	self:Color("accent", "Accent Color", "Highlights, selected buttons and section titles")
	self:Check("rtext", "Color Item Names by Rarity")
	self:Head("Size")
	self:Step("scale", "Scale", 0.05, "%d%%")
	self:Step("rowHeight", "Row Height (List View)", 2, "%d")
	self:Check("dense", "Compact Rows", "Shorter rows in List view")
	self:Head("Layout")
	self:Check("splitView", "Split View (Icons View)", "In Icons view, sections sit side by side in two columns, filling left to right, top to bottom. Needs Sections By Section or By Bag; a narrow window shows one column.")
	self:Check("emptySlots", "Show Empty Slots", "Your free bag spaces as blank squares in Icons view. Hidden in By Section, where a free space belongs to no section.")
end

-- Item Icons (1.5.0): everything about an item's picture, in either view, and what's drawn on it (marks).
pages.icons = function(self, db)
	self:Head("Appearance")
	self:Seg("border", "Rarity Borders", { { "all", "All" }, { "unc", "Green and Up" }, { "off", "Off" } })
	self:Step("iconSize", "Icon Size (Icons View)", 2, "%d", nil, {
		title = "Smaller icons",
		lines = {
			"Cooldown times show on an item icon only when they fit inside it. At smaller sizes the darkening sweep still shows the cooldown. List rows work the same way.",
			"|cff999999Cooldown times follow the game's own option for cooldown numbers.|r",
		},
		keywords = "cooldown cooldowns timer timers countdown",
	})
	self:Check("dimJunk", "Dim Junk", "Grey items and items you mark as junk are greyed out")
	self:Head("Marks")
	self:Check("newdot", "Green Dot on New Items", "The dot clears when you hover over the item")
	if db.newdot then
		self:Indented(function()
			self:Check("newdotClearRecent", "Clear Recent Also Clears Green Dots")
		end)
	end
	self:Check("iconItemLevel", "Item Level (ilvl)", "Icons view only: the item level on weapon and armor, in its own color so it reads apart from the stack count. Its corner is set under Icon Corners.")
	self:Indented(function() self:Color("iconItemLevelColor", "Item Level Color", "The color of the item level") end)
	self:IconCorners()
end

pages.automation = function(self, db)
	self:Head("Auto Travel Mode")
	self:Text("Travel Mode is a compact, on-the-go view: the signpost beside the close button hides the toolbar and filters so you can focus on adventuring, and you can switch back to your full inventory tools anytime. These settings switch it off for you when it's time to manage your bags, and back on afterwards.")
	self:Check("travelLeaveBank", "Leave Travel Mode at the Bank", "Turns it back on when you close the bank.")
	self:Check("travelLeaveAH", "Leave Travel Mode at the Auction House", "Turns it back on when you close the auction house.")
	self:Check("travelLeaveVendor", "Leave Travel Mode at Vendors", "Turns it back on when you close the vendor.")
	self:Check("travelLeaveTaxi", "Leave Travel Mode During Flight Paths", "Turns it back on when you land.")
	self:Check("travelLeaveTrade", "Leave Travel Mode When Trading", "Turns it back on when the trade is finished or canceled.")
	self:Head("Bag Cleanup")
	self:Check("cleanOnOpen", "Clean Up Bags When Opened", "Runs Blizzard's Clean Up Bags each time you open your bags (not in combat or at the bank)")
	self:Head("Vendors")
	self:Check("autoSellJunk", "Sell Junk Automatically at Vendors", "Sells grey and junk-marked items when you open a vendor, one at a time (the last 12 can be bought back). If the game wants a click for this, BagSmith says so. Blizzard's Sell All Junk button always sells every grey item, favorites and hidden sections included; BagSmith can't change that. BagSmith's own junk selling follows the same rule, and also sells junk-marked items.")
	self:Head("Prompts")
	self:Text("Some actions bring up a yes/no box (equipping bind-on-equip gear, using an item that binds, replacing an enchant). BagSmith can click Yes for you on the kinds you choose. Hold Shift to keep a box open. The enchant box from a profession window is always left for you.")
	self:Check("autoConfirm", "Auto-Confirm Prompts From BagSmith Actions", "Only a box that follows one of these BagSmith actions, within a few seconds. Every confirmation is announced in chat.")
	self:Indented(function()
		for _, src in ipairs(ns.Prompts and ns.Prompts.SOURCES or {}) do self:Check(src.key, src.label) end
		local keys = {}
		for _, k in ipairs(ns.Prompts and ns.Prompts.KEYS or {}) do
			if k[1] == "custom" then
				local bound = ns.Prompts:CustomKey()
				keys[#keys + 1] = { "custom", "Custom: " .. (bound and ns.KeyBinds:Pretty(bound) or "no key set") }
			else keys[#keys + 1] = { k[1], k[2] } end
		end
		self:Seg("autoConfirmKey", "Confirm", keys, "Always: the box is confirmed on its own (hold Shift to keep one open). Shift or Ctrl: only while that key is held when the box appears. Custom: only while the key you bind here is held; with no key set, nothing is confirmed.")
		if db.autoConfirmKey == "custom" then self:Indented(function() self:Binding("BAGSMITH_CONFIRMKEY", "Custom Confirm Key") end) end
		self:Check("autoConfirmEverywhere", "Also Outside BagSmith", "The same kinds of box wherever they come from, with the same key rule")
		self:Indented(function()
			for _, g in ipairs(ns.Prompts and ns.Prompts.GROUPS or {}) do self:Check(g.key, g.label) end
		end)
	end)
	self:Head("Clear Soul Shards")
	self:Step("shardKeep", "Soul Shards to Keep", 1, "%d", "|cff8788eeWarlock|r only. Clear Soul Shards always leaves you at least this many. Shards in a soul bag count toward it and are never destroyed.")
end

pages.loothelper = function(self, db)
	self:Head("Loot Helper")
	self:Text("When loot won't fit, the Loot Helper appears beside the loot window with ways to free space, then finishes the looting.")
	self:Check("makeRoom", "Show Loot Helper When Loot Won't Fit")
	self:Seg("makeRoomValue", "Rank Suggestions By", { { "ah", "AH Price" }, { "vendor", "Vendor Price" } },
		"AH Price uses Auctionator's prices when it has them, and the vendor price otherwise. Both are shown either way.")
	-- (1.5.1-beta2) whether destroying asks first
	self:Check("makeRoomAsk", "Ask Before Destroying", "When off, Destroy removes the chosen item at once, with no confirmation. Junk always goes in one click.")
	self:Indented(function()
		self:Check("makeRoomAskRare", "Always Ask for Rare or Better", "Like the game, blue and epic items still ask for confirmation before they're destroyed.",
			db.makeRoomAsk and { disabled = true, checked = true } or nil)
	end)
	-- The Loot Exclusion List: one line here, the list in its own window.
	self:Text("Favorites, gear-set items, quest items and Pawn upgrades are never suggested for destroying.")
	self:Head("Loot Exclusion List")
	self:Text("Loot the Loot Helper won't ask you to make room for. This list only affects the Loot Helper.")
	self:Text("Favorites are never destroyed by the Loot Helper or offered by the Disenchant Helper; junk selling still includes them.")
	local never = ns.MakeRoom and ns.MakeRoom:NeverList() or {}
	if #never > 0 then
		self:Text(("Loot Exclusion List: %d %s"):format(#never, #never == 1 and "item" or "items"))
		self:Buttons({
			{ "Manage...", function() ns.MakeRoom:ManageNever() end },
			{ "Clear All", function(btn) ns.Confirm(btn, ("Ask about all %d items again?"):format(#never), function() ns.MakeRoom:ClearNever(); self:Refresh() end) end },
		})
	else
		self:Text("Your Loot Exclusion List is empty. Use Exclude in the Loot Helper to add items.")
	end
end

pages.dehelper = function(self, db)
	self:Head("Disenchant Helper")
	self:Text("A window that lists the gear in your bags worth considering, with vendor, AH and materials values and a recommendation, then walks you through it one click per item. It never disenchants on its own.")
	self:Text("Estimates start from the game's typical disenchant results. BagSmith records what each of your disenchants actually produces, and once a kind of item (its quality and level bracket, armor or weapon) has twenty of your disenchants behind it, that kind's estimates come from your results instead, so the helper gets more accurate the more you use it. Results are kept per character and per kind, so a new enchanter starts from the typical results again.")
	self:Check("deEnabled", "Disenchant Helper", "Adds its button beside the Gear Sets shield; /bs de and the Disenchant Next Item keybinding work too")
	self:Indented(function()
		self:Step("deMargin", "Disenchant Must Beat Selling By", 0.05, "%d%%", "Materials have to be worth this much more than the best of vendor and AH price before Disenchant is recommended")
		self:Check("deIncludeEpics", "Include Epics", "Off keeps epics out of the helper entirely")
		self:Check("deSkipRefundable", "Skip Refundable and Tradeable Items", "Items you could still return to a vendor, or hand to a group member from a recent roll, stay out")
		self:Button("Open Disenchant Helper", function() if ns.Disenchant then ns.Disenchant:Show() end end)
		self:Text("Favorites and gear-set items are always left out. The DE Exclusion List only affects this helper.")
		local never = ns.Disenchant and ns.Disenchant:NeverList() or {}
		if #never > 0 then
			self:Text(("DE Exclusion List: %d %s"):format(#never, #never == 1 and "item" or "items"))
			self:Buttons({
				{ "Manage...", function() ns.Disenchant:ManageNever() end },
				{ "Clear All", function(btn) ns.Confirm(btn, ("Consider all %d items again?"):format(#never), function() ns.Disenchant:ClearNever(); self:Refresh() end) end },
			})
		else
			self:Text("Your DE Exclusion List is empty. Use Exclude in the helper to add items.")
		end
	end)
	local learned = ns.Disenchant and ns.Disenchant:LearnedCount() or 0
	if learned > 0 then
		self:Text(("This character's disenchants on record: %d."):format(learned))
		self:Button("Forget Learned Results", function(btn)
			ns.Confirm(btn, ("Forget all %d recorded disenchants? Estimates go back to the typical results."):format(learned), function() ns.Disenchant:ResetLearned(); self:Refresh() end)
		end)
	end
	self:Head("Opt-in")
	self:Text("When a character with Enchanting opens the bags, BagSmith offers the helper once: Add Now, Ask Later, or Don't Ask Again.")
	if db.deEnabled then
		self:Text("This character has already opted in.")
	elseif ns.cdb and ns.cdb.deOfferDeclined then
		self:Text("This character opted out (Don't Ask Again).")
		self:Button("Ask Again", function() if ns.Disenchant then ns.Disenchant:AskAgain() end; self:Refresh() end)
	else
		self:Text("This character hasn't been asked yet, or chose Ask Later.")
	end
end

pages.keys = function(self, db)
	self:Head("Keybindings")
	self:Text("Click Set Key, then press the key you want (with Shift, Ctrl or Alt if you like). Esc cancels. These are the same bindings as in the game's Keybindings, under BagSmith.")
	for _, b in ipairs(ns.KeyBinds and ns.KeyBinds.LIST or {}) do self:Binding(b[1], b[2]) end
	self:Head("Item Menu")
	self:Text("Alt+Left-click an item opens BagSmith's item menu (Move to Section, Favorite, Mark as Junk, Track as Currency).")
	-- The game's own item modifiers: if one is on Alt, it happens too.
	local MODS = { { "CHATLINK", "Link to Chat" }, { "DRESSUP", "Dress Up" }, { "SPLITSTACK", "Split Stack" }, { "EXPANDITEM", "Expand Item" }, { "SOCKETITEM", "Socket Item" } }
	for _, m in ipairs(MODS) do
		local mod = GetModifiedClick and GetModifiedClick(m[1])
		if mod == "ALT" then
			self:Text(("Your %s modifier is also Alt, so Alt+Left-click will do that too."):format(m[2]))
		end
	end
end

pages.window = function(self, db)
	self:Head("Bag Window")
	self:Seg("view", "Start In", { { "list", "List" }, { "icons", "Icons" } })
	self:Seg("sizeMode", "Window Size", { { "auto", "Fit to Items" }, { "fixed", "Scalable" } },
		db.sizeMode == "auto" and "Shrinks to fit your items, up to the max size below. Dragging the corner sets the max size." or "Stays the size you set. Drag the corner to resize it.")
	if db.sizeMode == "auto" then
		self:Step("maxW", "Max Width", 20, "%d"); self:Step("maxH", "Max Height", 20, "%d")
	else
		self:Step("fixW", "Width", 20, "%d"); self:Step("fixH", "Height", 20, "%d")
	end
	self:Head("Combat")
	self:Check("combatFade", "Fade Windows During Combat", "Windows turn see-through while you fight")
	self:Step("combatAlpha", "Opacity in Combat", 0.05, "%d%%")
	self:Check("combatLock", "Ignore Clicks While Faded", "Clicks pass through faded windows, so you can't click something by accident mid-fight")
	self:Head("Bag Windows")
	self:Seg("__openWindows", "When the Main Window Opens",
		{ { "main", "Open Main Window Only" }, { "all", "Auto-Open All Bags" }, { "reagent", "Auto-Open Reagent Bag" } },
		"The footer buttons open or close bag windows anytime.", true)
	self:Step("bagCols", "Icons per Row in Bag Windows", 1, "%d")
	self:Step("bagScale", "Bag Window Scale", 0.05, "%d%%", "On top of Scale in Style. 100% matches the main window.")
	self:Step("bagMaxH", "Bag Window Max Height", 20, "%d", "Taller bags scroll.")
	self:Head("Currency Drawer")
	self:Seg("side", "Opens to the", { { "left", "Left" }, { "right", "Right" } }, "Switches sides on its own if there isn't room")
end

pages.sections = function(self, db)
	self:Head("Sections")
	self:Text("Group your items into sections. Click a header to collapse it, and drag headers to reorder them.")
	self:Seg("grp", "Open with Sections", { { "none", "None" }, { "type", "By Section" }, { "bag", "By Bag" } })
	self:Check("remember", "Remember Which Sections Are Collapsed")
	self:Head("Which Section an Item Goes To")
	self:Text("An item in one of your gear sets goes to that set's section (while Show Gear Sets as Sections is on). Otherwise an item marked as junk always goes to Junk. Otherwise a favorite goes to Favorites (while that section is on). Otherwise it goes to the section you moved it to, or else its usual section by type.")
	self:Head("Keys & Reagent Bag")
	self:Check("keys", "Keys in Their Own Section (All and By Bag)", "By Section always gives keys their own section.")
	self:Seg("reagent", "Reagent Bag (Sections: All)", { { "inline", "Mixed In" }, { "lane", "Own Section" } },
		"By Section sorts reagent-bag items by type; By Bag shows each bag as a section.")
	-- (1.5.0-beta9) Split Consumables
	self:Head("Consumables")
	self:Check("splitCons", "Split Consumables by Type", "Consumables becomes sections of their own: Food, Drink, Potions and more. Untick a type to keep it in Consumables.")
	if db.splitCons then
		self:Indented(function()
			for _, k in ipairs(ns.CONS_KINDS) do
				self:Check("splitCons_" .. k, ns.CONS_LABEL[k], k == "Food" and "Includes items that are both food and drink." or nil)
				local c = self.pools.check[self.counts.check]
				if c and c.key == "splitCons_" .. k then
					c.box:SetChecked((db.splitConsTypes or {})[k] ~= false)
					c.onSet = function(on)
						local t = {}
						for kk, v in pairs(db.splitConsTypes or {}) do t[kk] = v end
						if on then t[k] = nil else t[k] = false end   -- (missing means split)
						ns:Set("splitConsTypes", t)
					end
				end
			end
		end)
	end
	self:Head("Section Order")
	self:Text("Every section follows this order, dynamic and custom ones included.")
	-- Recent Items, Keys and Reagent Bag stay listed (so their place can be set
	-- in advance) but are dimmed with "(off)" when inactive, and say how to turn
	-- them on.
	-- (1.5.0-beta9) Split Consumables' sections are listed only while in use
	local hideSplit = {}
	for _, k in ipairs(ns.CONS_KINDS) do local id = ns.CONS_ID[k]; if not (ns.Sections and ns.Sections:ConsSplitActive(id)) then hideSplit[id] = true end end
	local orderItems = orderedList("laneOrder", nil, function(id) return id == "~recent" and "Recent Items" or (ns.Sections and ns.Sections:Label(id)) or ns.CAT_LABEL[id] or id end, hideSplit)
	for _, it in ipairs(orderItems) do
		local off
		if it.id == "~recent" and not db.recentSection then
			off = "Recent Items is off. Tick Recent Items in Settings > Dynamic Sections to turn it on."
		elseif it.id == "~fav" and not db.favSection then
			off = "Favorites is off. Tick Favorites in Settings > Dynamic Sections to turn it on."
		elseif it.id == "~gs" and not (ns.GearSets and ns.GearSets:Available()) then
			off = "This game client doesn't have equipment sets."
		elseif it.id == "~gs" and not db.gearSetSections then
			off = "Gear Sets is off. Tick Show Gear Sets as Sections in Settings > Dynamic Sections to turn it on."
		elseif it.id == "~rb" and db.reagent ~= "lane" then
			off = "Your reagent bag's items are mixed in with your other items. Set Reagent Bag to Own Section, under Keys & Reagent Bag, above."
		end
		if off then it.label, it.dim, it.tip = it.label .. " (off)", true, off end
	end
	self:List(orderItems,
		nil, function(id, delta) local i = ns.IndexOf(db.laneOrder, id); if ns.Move(db.laneOrder, i, i + delta) then ns:Fire("SETTINGS_CHANGED", "laneOrder") end end)
	-- Pinned sections (1.4.0): one row per item section, with its pin.
	self:Head("Pinned Sections")
	self:Text("A pinned section shows at the top, after Recent. In All view its items get their own section there instead of the main list. By Bag ignores pins. You can also right-click a section's title.")
	for _, id in ipairs(db.laneOrder) do
		if ns.Sections:Pinnable(id) and (not id:match("^c%d+$") or ns.Sections:IsCustom(id)) then self:PinRow(id) end
	end
	if not ns.IndexOf(db.laneOrder, "Junk") then self:PinRow("Junk") end
	local GS = ns.GearSets
	-- Show at Vendor / Show at AH, for every section.
	self:Head("Vendors & Auction House")
	self:Text("Every section shows at vendors and the auction house unless you hide it here (or right-click its title). Hidden items come back as soon as you close the vendor or auction house, and a note at the end of the list offers to show them during the visit. Hiding a section only hides it from view: Blizzard's Sell All Junk button always sells every grey item, favorites and hidden sections included; BagSmith can't change that. BagSmith's own junk selling follows the same rule, and also sells junk-marked items.")
	self:VisibilityHeader()
	for _, id in ipairs(db.laneOrder) do
		if id == "~gs" then
			-- One row for every gear set, as in Section Order.
			if GS and GS:Available() and GS:Showing() then self:VisibilityRow("~gs") end
		elseif id ~= "~recent" and id ~= "~ky" and id ~= "~rb" and (not id:match("^c%d+$") or ns.Sections:IsCustom(id)) then self:VisibilityRow(id) end
	end
	if not ns.IndexOf(db.laneOrder, "Junk") then self:VisibilityRow("Junk") end
end


-- Sections that fill themselves: Recent Items, Favorites and your gear sets.
pages.dynamic = function(self, db)
	self:Head("Dynamic Sections")
	self:Text("Sections that fill themselves: what you just picked up, what you starred, and your gear sets.")
	self:Check("recentSection", "Recent Items", "What you picked up since logging in, newest first. Shown at the top by default; move it in Section Order (Sections). The items also stay in their usual section. Clear Recent in its header empties the list.")
	if db.recentSection then
		self:Indented(function()
			self:Seg("recentWindow", "Recent Items From", { { "session", "Since Login" }, { "1h", "Last Hour" }, { "15m", "Last 15 Min" } },
				"Since Login: everything you've picked up since you logged in on this character. A /reload doesn't reset it. Use Clear Recent in the section's header to start it over.")
			self:Seg("recentMax", "Recent Items Shown", { { 0, "All" }, { 8, "8" }, { 16, "16" }, { 32, "32" } })
		end)
	end
	self:Check("favSection", "Favorites", "Items you star (the Favorite column, or its keybinding) move to this section at the top, like pinned mail. Move it in Section Order (Sections). Off: they stay in their usual sections. Favorites aren't protected from junk selling: Blizzard's Sell All Junk button always sells every grey item, favorites and hidden sections included; BagSmith can't change that. BagSmith's own junk selling follows the same rule, and also sells junk-marked items.")
	-- The game's own equipment sets, shown as sections.
	self:Head("Gear Sets")
	local GS = ns.GearSets
	if not (GS and GS:Available()) then
		self:Text("This game client doesn't have equipment sets.")
	else
		self:Text("Your gear sets are the game's own equipment sets, the same ones as the Equipment Manager in your character window. Each has its own section in your bags, holding the set's items that are in your bags, with an Equip button. A set you're wearing shows its title marked Worn. Items in a set can't be marked as junk, are never sold by BagSmith and are never offered by the Loot Helper.")
		self:Check("gearSetSections", "Show Gear Sets as Sections", "Off: set items stay in their usual sections (still protected).")
		self:Button("New Gear Set...", function() GS:PromptNew() end)
		local sets = GS:Rebuild()
		if #sets == 0 then
			self:Text("No gear sets yet. New Gear Set... saves what you're wearing now (shirt and tabard left out).")
		else
			for _, set in ipairs(sets) do self:GearSetRow(set) end
			self:Text("Gear Sets are managed in Blizzard's Equipment Manager.")
		end
	end
end

-- Your own sections, and moving items between sections.
pages.custom = function(self, db)
	self:Head("Custom Sections")
	self:Text("Make your own sections. Drag an item onto a section's title (with Sections set to By Section), Alt+Left-click it, or use the Move to Section keybinding. Moves apply to every copy of the item and belong to this profile.")
	self:Button("New Section...", function() ns.Sections:PromptNew() end)
	self:Check("showEmptySections", "Show Empty Custom Sections", "Your sections show even when empty, ready to drag items onto. Each can opt out below. Empty ones hide while you search or filter.")
	local customs = ns.Sections:Customs()
	if #customs == 0 then
		self:Text("No sections yet. New Section... makes one.")
	else
		self:CustomSectionHeader()
		for _, c in ipairs(customs) do self:CustomSectionRow(c) end
	end
	self:MovedRow()
end

pages.columns = function(self, db)
	self:Head("Columns")
	self:Check("itemMenuButton", "Item Menu Button", "Three dots at the left of each list row open the item menu (the same as Alt+Left-click): Move to Section, Favorite, Mark as Junk, Track as Currency. List view only.")
	self:Text("Choose and order each window's columns in Bag Columns and Bank Columns.")
end
-- Each window's columns: one list, ticked to show, arrows to reorder.
local function columnsPage(self, db, bank)
	self:Head(bank and "Bank Columns" or "Bag Columns")
	self:Text((bank and "Your bank window's columns." or "Your bags window's columns (its Bank tab uses them too).")
		.. " Tick a column to show it. Item is always shown, but you can move it. To resize columns, drag the line between two headers: the two columns beside it trade width, and Item fills the rest of the row. Double-click a line to reset both.")
	local colsKey, orderKey, widthsKey = bank and "bankCols" or "cols", bank and "bankColOrder" or "colOrder", bank and "bankColWidths" or "colWidths"
	local cols, order = db[colsKey], db[orderKey]
	local colItems = {}
	for _, id in ipairs(order) do
		if id == "n" then colItems[#colItems + 1] = { id = "n", label = "Item", checked = true, disabled = true, tip = "Item is always shown. You can still move it, like the other columns." }
		elseif id == "ah" then
			-- AH Price: always listed, greyed out until Auctionator is installed.
			local ok = ns.AH:Available()
			colItems[#colItems + 1] = { id = id, label = ns.COL_LABEL[id], checked = ns.IndexOf(cols, id) ~= nil, disabled = not ok,
				tip = ok and "Prices from Auctionator's last auction house scan. Shows the stack's value, or \"-\" when an item hasn't been scanned." or "Install Auctionator to enable this column. It shows prices from Auctionator's last auction house scan." }
		else colItems[#colItems + 1] = { id = id, label = ns.COL_LABEL[id], checked = ns.IndexOf(cols, id) ~= nil } end
	end
	self:List(colItems,
		function(id, on)
			local i = ns.IndexOf(cols, id)
			if on and not i then table.insert(cols, id) elseif not on and i then table.remove(cols, i) end
			ns:Fire("SETTINGS_CHANGED", colsKey)
		end,
		function(id, delta) local i = ns.IndexOf(order, id); if ns.Move(order, i, i + delta) then ns:Fire("SETTINGS_CHANGED", orderKey) end end)
	self:Button(bank and "Reset Bank Column Widths" or "Reset Bags Column Widths", function() db[widthsKey] = {}; ns:Fire("SETTINGS_CHANGED", widthsKey) end)
end
pages.bagcols = function(self, db) columnsPage(self, db, false) end
pages.bankcols = function(self, db) columnsPage(self, db, true) end


pages.sheets = function(self, db)
	self:Head("Sheets")
	self:Check("sheetViews", "Sheets Remember Their View", "Each sheet tab keeps its own Sections, Sort, View, Merge Stacks and collapsed sections. The All tab uses the window's settings.")
	self:Text("Choose and order each window's tabs in Bag Sheets and Bank Sheets.")
end
-- Each window's tabs and saved sheets: one list, like Columns.
local function sheetsPage(self, db, bank)
	self:Head(bank and "Bank Sheets" or "Bag Sheets")
	self:Text((bank and "Your bank window's tabs." or "Your bags window's tabs.") .. " Tick a sheet to show its tab. All is always shown, but you can move it. Save your own sheets from the Filter panel.")
	local orderKey, hiddenKey = bank and "bankTabOrder" or "tabOrder", bank and "bankHiddenTabs" or "hiddenTabs"
	local order, hiddenList = db[orderKey], db[hiddenKey]
	local ui = bank and ns.uiBank or ns.ui
	local hidden = {}
	for _, t in ipairs(hiddenList) do hidden[t] = true end
	local items = {}
	for _, id in ipairs(order) do
		local checked
		if id ~= "All" then checked = not hidden[id] end
		items[#items + 1] = { id = id, label = ns.TAB_LABEL[id] or id, checked = checked }
	end
	self:List(items,
		function(id, on)
			if id == "All" then return end
			local list = db[hiddenKey]   -- read now, in case the profile's table was replaced
			local i = ns.IndexOf(list, id)
			if on and i then table.remove(list, i) elseif not on and not i then table.insert(list, id) end
			if not on and ui and ui.sheet == id then ui.sheet = "All" end
			ns:Fire("SETTINGS_CHANGED", hiddenKey)
		end,
		function(id, delta) local o = db[orderKey]; local i = ns.IndexOf(o, id); if ns.Move(o, i, i + delta) then ns:Fire("SETTINGS_CHANGED", orderKey) end end)
end
pages.bagsheets = function(self, db) sheetsPage(self, db, false) end
pages.banksheets = function(self, db) sheetsPage(self, db, true) end

pages.sorting = function(self, db)
	self:Head("Sorting")
	self:Seg("sort", "Open Sorted By", { { "quality", "Rarity" }, { "name", "A-Z" }, { "ilvl", "iLvl" }, { "newest", "New" }, { "oldest", "Old" }, { "off", "Off" } },
		"Off keeps items in bag order, where they sit in your bags.")
	self:Text("Click any column header to sort by it; click again to flip the direction.")
	self:Head("Filters")
	self:Check("mergeStacks", "Merge Stacks", "Shows each item once, with its total count")
	self:Check("hideJunk", "Hide Junk on the All Sheet", "Junk stays on its own sheet")
	self:Text("Search shortcuts: boe, bop, new, q:rare, t:herb, il>20.")
end

pages.advanced = function(self, db)
	self:Head("Advanced")
	self:Check("debug", "Debug Messages in Chat")
	-- (Hide the Login Message and Show What's New After Updates are on the General page.)
	self:Head("Troubleshooting Commands")
	self:Command("/bs check", "Shows what loaded and what didn't")
	self:Command("/bs errors", "Lists errors from this session")
	self:Command("/bs dump", "Lists every item with its category")
	self:Head("Reset")
	self:Text("Puts every setting in this profile back the way BagSmith came, including columns, sheets, and colors.")
	self:Button("Reset to Defaults", function(btn)
		-- Reset exactly the profile named in the question, whatever is active by then.
		local target = ns.profileName
		ns.Confirm(btn, ("Reset the \"%s\" profile to defaults?\nThis cannot be undone."):format(target), function()
			local ok, err = ns.Profiles:Reset(target)
			if ok == false then ns:Print(err) end
		end)
	end)
end

------------------------------------------------------------------------
-- About: the icon, the version and release date (read from the TOC), the
-- author's note, and links (shown ready to copy; addons can't open pages).
------------------------------------------------------------------------
local ABOUT_ICON = "Interface\\AddOns\\BagSmith\\Media\\about-icon.tga"
local LINKS = {
	curseforge = { label = "CurseForge", url = "https://www.curseforge.com/wow/addons/bagsmith", icon = "ui-curseforge.tga", tint = { 0.945, 0.392, 0.212 } },
	coffee = { label = "Buy Me a Coffee", url = "https://buymeacoffee.com/shweepy", icon = "ui-coffee.tga", tint = { 1, 0.867, 0 } },
	discord = { label = "Discord", url = "https://discord.gg/uYfcHPkcar", icon = "ui-discord.tga" },
	gamepad = { label = "CurseForge", url = "https://www.curseforge.com/wow/addons/bagsmith-gamepad-support", icon = "ui-curseforge.tga", tint = { 0.945, 0.392, 0.212 } },
}
Panel.LINKS = LINKS
Panel.ABOUT_ME = {
	"I'm Shweep. I've been playing WoW on and off since December 2005, so Azeroth has been part of my life for a pretty ridiculous amount of time at this point. I know plenty of you can say the same.",
	"I spend my days building software and my evenings tinkering with side projects, playing board games, and getting lost in the occasional RPG.",
	"I started building BagSmith because not many bag addons make it easy to look past the icons. I figured if it solved a problem for me, it might help someone else too.",
	"If it saves you some frustration and you feel like buying me a coffee, it helps fuel more updates and fixes. If you can't, no worries at all. Bug reports, feature ideas, and kind words are just as appreciated.",
}
local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }
-- "Version 0.13.2, released October 14, 2026" (the date is set in the TOC at each release).
function Panel:VersionLine()
	local line = "Version " .. tostring(ns.version or "?")
	local raw = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "X-Date")
	local y, m, d = tostring(raw or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	if y and MONTHS[tonumber(m)] then line = line .. (", released %s %d, %s"):format(MONTHS[tonumber(m)], tonumber(d), y) end
	return line
end
local function linkButton(parent, key)
	local L = LINKS[key]
	local b = ns.TextButton(parent, L.label, 120, function() ns.ShowLink(L.label, L.url) end)
	b:SetHeight(24)
	b.icon = b:CreateTexture(nil, "OVERLAY")
	b.icon:SetSize(16, 16); b.icon:SetPoint("LEFT", b, "LEFT", 8, 0)
	b.icon:SetTexture("Interface\\AddOns\\BagSmith\\Media\\" .. L.icon)
	if L.tint then b.icon:SetVertexColor(L.tint[1], L.tint[2], L.tint[3]) end
	b.label:ClearAllPoints(); b.label:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
	b:SetWidth(8 + 16 + 6 + math.ceil(b.label:GetStringWidth()) + 12)
	b.riders = { b.icon }
	b.tip = L.url
	b.linkKey = key
	return b
end
function Panel:About()
	local w = acquire(self, "about", function(p)
		local w = CreateFrame("Frame", nil, p)
		-- The icon, framed like the bags. The texture is the backpack lifted
		-- from the art onto an even dark background (no trace of the art's own
		-- silver border), evenly padded. Modern: the bags' shaded frame.
		-- Classic: the frame of Blizzard's bag slots (the same art as the Bag
		-- Bar), which is drawn for slots this size; the item frame drawn for
		-- small icons looked uneven when enlarged.
		w.icon = w:CreateTexture(nil, "ARTWORK"); w.icon:SetSize(52, 52); w.icon:SetPoint("TOPRIGHT", -6, -6)
		w.icon:SetTexture(ABOUT_ICON); w.icon:SetTexCoord(0, 1, 0, 1)
		w.iconEdge = w:CreateTexture(nil, "BACKGROUND", nil, -1); w.iconEdge:SetTexture("Interface\\Buttons\\WHITE8X8")
		w.iconEdge:SetPoint("TOPLEFT", w.icon, "TOPLEFT", -2, 2); w.iconEdge:SetPoint("BOTTOMRIGHT", w.icon, "BOTTOMRIGHT", 2, -2)
		w.iconBG = w:CreateTexture(nil, "BACKGROUND", nil, 0); w.iconBG:SetTexture("Interface\\Buttons\\WHITE8X8")
		w.iconBG:SetPoint("TOPLEFT", w.icon, "TOPLEFT", -1, 1); w.iconBG:SetPoint("BOTTOMRIGHT", w.icon, "BOTTOMRIGHT", 1, -1)
		w.iconFrame = w:CreateTexture(nil, "OVERLAY", nil, 2)
		w.iconFrame:SetPoint("CENTER", w.icon, "CENTER")
		w.title = w:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); w.title:SetPoint("TOPLEFT", 2, -6)
		w.version = fs(w)
		w.curseforge = linkButton(w, "curseforge")
		w.meHead = fs(w); w.supportHead = fs(w)
		w.paras = {}
		for i = 1, #Panel.ABOUT_ME do w.paras[i] = fs(w); w.paras[i]:SetJustifyH("LEFT") end
		w.supportText = fs(w); w.supportText:SetJustifyH("LEFT")
		w.coffee = linkButton(w, "coffee")
		w.discord = linkButton(w, "discord")
		return w
	end)
	local s = Skins:Current()
	local classic = ns.Classic and ns.Classic.IsOn and ns.Classic.IsOn()
	if classic and not w.iconFrameSet and ns.BagBar then
		local art = ns.BagBar:SlotFrameArt()
		if art.atlas then w.iconFrame:SetAtlas(art.atlas) else w.iconFrame:SetTexture(art.file) end
		w.iconFrameSet = true
	end
	-- Classic: the icon sits inside the bag-slot frame's opening (the frame's
	-- cut corners and gold rim drawn over its edges), like an item in a bag
	-- slot; Modern: the icon at full size in the shaded frame.
	if classic then
		w.iconFrame:SetSize(58, 58)
		w.icon:SetSize(48, 48); w.icon:ClearAllPoints(); w.icon:SetPoint("TOPRIGHT", -7, -7)
	else
		w.icon:SetSize(52, 52); w.icon:ClearAllPoints(); w.icon:SetPoint("TOPRIGHT", -6, -6)
	end
	w.iconFrame:SetShown(classic and true or false)
	w.iconEdge:SetShown(not classic); w.iconBG:SetShown(not classic)
	w.iconEdge:SetVertexColor(1, 1, 1, 0.14); w.iconBG:SetVertexColor(0, 0, 0, 0.6)
	w.title:SetText("About BagSmith"); w.title:SetTextColor(unpack(s.heading))
	w.version:ClearAllPoints(); w.version:SetPoint("TOPLEFT", w.title, "BOTTOMLEFT", 0, -6)
	w.version:SetText(self:VersionLine()); w.version:SetTextColor(Skins:Color("muted"))
	w.curseforge:ClearAllPoints(); w.curseforge:SetPoint("TOPLEFT", w.version, "BOTTOMLEFT", -2, -8)
	local y = 6 + 22 + 6 + FONT_H + 8 + 24 + 22
	y = math.max(y, 2 + 56 + 12)
	local textW = rowW - 4
	-- About Me
	w.meHead:ClearAllPoints(); w.meHead:SetPoint("TOPLEFT", 2, -y)
	w.meHead:SetText("About Me"); w.meHead:SetTextColor(Skins:Accent())
	y = y + FONT_H + 8
	for i, para in ipairs(w.paras) do
		para:ClearAllPoints(); para:SetPoint("TOPLEFT", 2, -y)
		para:SetText(Panel.ABOUT_ME[i]); para:SetTextColor(Skins:Color("text"))
		y = y + wrapText(para, textW) + 10
	end
	-- Support & Community
	y = y + 10
	w.supportHead:ClearAllPoints(); w.supportHead:SetPoint("TOPLEFT", 2, -y)
	w.supportHead:SetText("Support & Community"); w.supportHead:SetTextColor(Skins:Accent())
	y = y + FONT_H + 8
	w.supportText:ClearAllPoints(); w.supportText:SetPoint("TOPLEFT", 2, -y)
	w.supportText:SetText("Join the Discord to talk about BagSmith, share feedback, report bugs and suggest features.")
	w.supportText:SetTextColor(Skins:Color("muted"))
	y = y + wrapText(w.supportText, textW) + 10
	w.coffee:ClearAllPoints(); w.coffee:SetPoint("TOPLEFT", 0, -y)
	w.discord:ClearAllPoints(); w.discord:SetPoint("LEFT", w.coffee, "RIGHT", 8, 0)
	y = y + 24 + 10
	w:SetHeight(y)
	self.y = self.y + y
end
------------------------------------------------------------------------
-- Plugins: separate optional addons that use BagSmith.API. Discovery and
-- status come from the API's cached model (refreshed when Settings opens
-- and after a toggle here), never from rendering. Enable/disable is the
-- game's addon state for this character and takes effect after a reload
-- the user asks for; nothing is hot-unloaded and nothing reloads by itself.
------------------------------------------------------------------------
local function pluginAPI() return ns.API end
-- One compact row per discovered plugin: name, version, author (with the curated Official badge), description,
-- status in plain words, an enable/disable box, and Options only when an active plugin registered one.
function Panel:PluginRow(item)
	local e, st = item.entry, item.status
	local w = acquire(self, "plug", function(p)
		local r = CreateFrame("Frame", nil, p); r:SetSize(ROW_W, LINE)
		r.text = fs(r); r.text:SetPoint("TOPLEFT", 2, -6)
		r.meta = fs(r); r.meta:SetPoint("TOPLEFT", 2, -(6 + FONT_H + 2))
		r.help = fs(r)
		r.status = fs(r)
		r.box = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate"); r.box:SetSize(24, 24)
		r.box:SetScript("OnClick", function(b)
			local row = b:GetParent()
			local ok, codeOrState, msg = pluginAPI():SetPluginEnabled(row.addon, b:GetChecked() and true or false)   -- by the addon folder: the row's canonical identity
			if not ok then ns:Print("Plugins: %s", tostring(msg)); pluginAPI():RefreshPlugins() end
			Panel:Refresh()
		end)
		r.options = ns.TextButton(r, "Options", 80, function(b) local row = b:GetParent(); Panel:ShowPluginOptions(row.pluginId, row.addon) end)
		r.options:SetHeight(22)
		return r
	end)
	local skin = Skins:Current()
	-- recycled rows start clean
	w.pluginId, w.addon = e.id, e.addon
	w.text:SetWordWrap(false); w.meta:SetWordWrap(false)
	-- the title and meta lines stop short of every control shown on the right (checkbox and, when offered, Options)
	local controlsW = 40 + (st.options and 90 or 0)
	w.text:SetText(e.title ~= "" and e.title or e.addon); w.text:SetTextColor(Skins:Color("text")); w.text:SetWidth(rowW - controlsW)
	local meta = {}
	if e.version ~= "" then meta[#meta + 1] = "v" .. e.version end
	if e.author ~= "" then meta[#meta + 1] = "by " .. e.author end
	if e.official then meta[#meta + 1] = "Official" end
	w.meta:SetText(table.concat(meta, "  |  ")); w.meta:SetTextColor(unpack(e.official and skin.heading or skin.muted)); w.meta:SetWidth(rowW - controlsW)
	local y = math.max(6 + FONT_H + 2 + FONT_H + 4, 4 + 24 + 8)   -- below the title and meta lines, and below the controls
	w.help:ClearAllPoints(); w.help:SetPoint("TOPLEFT", 2, -y)
	if e.notes ~= "" then w.help:SetText(e.notes); w.help:SetTextColor(Skins:Color("muted")); y = y + wrapText(w.help, rowW - 4) + 2; w.help:Show() else w.help:SetText(""); w.help:Hide() end
	w.status:ClearAllPoints(); w.status:SetPoint("TOPLEFT", 2, -y)
	local label = "Status: " .. tostring(st.text)
	if st.pending then label = label .. "  (reload required)" end
	w.status:SetText(label)
	w.status:SetTextColor(unpack((st.state == "failed" or st.problem) and (skin.warning or skin.heading) or skin.text))
	y = y + wrapText(w.status, rowW - 4) + 4
	w.box:ClearAllPoints(); w.box:SetPoint("TOPRIGHT", 0, -4)
	w.box:SetChecked(st.enabled == "enabled")
	local canToggle = (st.enabled == "enabled" and st.canDisable) or (st.enabled ~= "enabled" and st.canEnable)
	if canToggle then w.box:Enable(); w.box:Show() else w.box:Disable(); if st.manageElsewhere or st.enabled == nil then w.box:Hide() else w.box:Show() end end
	w.options:ClearAllPoints(); w.options:SetPoint("TOPRIGHT", -30, -4)
	if st.options then w.options:Show(); w.options:SetActive(false) else w.options:Hide() end
	w:SetHeight(y + 4)
	self.y = self.y + w:GetHeight()
end
-- The one pending notice and its reload control.
function Panel:PluginNotice(count)
	local w = acquire(self, "pnotice", function(p)
		local r = CreateFrame("Frame", nil, p); r:SetSize(ROW_W, LINE)
		r.text = fs(r); r.text:SetPoint("TOPLEFT", 2, -6)
		r.btn = ns.TextButton(r, "Reload UI", 100, function()
			local ok, _, msg = pluginAPI():RequestReload()
			if not ok then ns:Print("Plugins: %s", tostring(msg)) end
		end)
		r.btn:SetHeight(22); r.btn:SetPoint("TOPRIGHT", 0, -4)
		return r
	end)
	local char = (ns.API and ns.API:CharacterName()) or "this character"
	w.text:SetText(("%d change%s to plugin addons for %s take%s effect after you reload the interface. Nothing has stopped or started yet."):format(count, count == 1 and "" or "s", char, count == 1 and "s" or ""))
	w.text:SetTextColor(Skins:Color("text"))
	local h = wrapText(w.text, rowW - 120)
	w.btn:SetActive(false)
	w:SetHeight(math.max(h + 12, 30))
	self.y = self.y + w:GetHeight()
end
-- A curated featured entry (a display convention: known IDs from core, not self-declared metadata).
-- The project link sits top right in the About page's style; the Discord link (the same button About uses)
-- bottom right; the description runs between them, never under either.
function Panel:FeaturedCard(info)
	local w = acquire(self, "feat", function(p)
		local r = CreateFrame("Frame", nil, p); r:SetSize(ROW_W, LINE)
		r.text = fs(r); r.text:SetPoint("TOPLEFT", 2, -6)
		r.help = fs(r)
		r.link = linkButton(r, "gamepad"); r.link:SetPoint("TOPRIGHT", 0, -4)
		r.discord = linkButton(r, "discord"); r.discord:SetPoint("BOTTOMRIGHT", 0, 6)
		return r
	end)
	local linkW = w.link:GetWidth()
	w.text:SetWordWrap(false); w.text:SetText(info.title); w.text:SetTextColor(Skins:Color("text")); w.text:SetWidth(rowW - linkW - 12)
	local top = math.max(6 + FONT_H + 4, 4 + 24 + 6)
	w.help:ClearAllPoints(); w.help:SetPoint("TOPLEFT", 2, -top)
	w.help:SetText(info.text); w.help:SetTextColor(Skins:Color("muted"))
	local h = wrapText(w.help, rowW - 4)
	w.helpTop = top
	w.link:SetActive(false); w.discord:SetActive(false)
	w:SetHeight(top + h + 8 + 24 + 6)   -- room for the Discord button under the description
	self.y = self.y + w:GetHeight()
end
pages.plugins = function(self, db)
	local api = pluginAPI()
	local list = api and api:PluginList() or {}
	local char = (api and api:CharacterName()) or "this character"
	self:Head("Installed plugins")
	local pending = 0
	for _, item in ipairs(list) do if item.status.pending then pending = pending + 1 end end
	if #list == 0 then
		self:Text("No plugins installed yet. Plugins are optional add-ons that build on BagSmith; see Featured plugins below.")
	else
		if api and not api:CanToggle() then self:Text("This client offers no addon enable controls here: use the game's AddOns screen to enable or disable plugins. Their status is shown below.")
		else self:Text(("Enabling or disabling a plugin here applies to %s only and takes effect after you reload the interface."):format(char)) end
		if pending > 0 then self:PluginNotice(pending) end
		for _, item in ipairs(list) do self:PluginRow(item) end
	end
	-- Featured: the official companion, only while it is not installed (an installed one has its row above)
	local gpItem = api and api:PluginItemByAddon("BagSmith_Gamepad")   -- the curated addon, not whichever addon claims the ID
	if not gpItem then
		self:Head("Featured plugins")
		self:FeaturedCard({ title = "BagSmith Gamepad: coming soon", text = "Browse your bags from a gamepad or controller: friendly and easy to use, just like with a keyboard and mouse. It's in alpha testing now; when it reaches beta we'll be looking for testers. Interested? Join the Discord." })
	end
	self:Head("Build a plugin")
	self:Text("Want to build on BagSmith? The developer documentation and a starter example ship with the source, in the docs/plugins folder. Plugins work through a small public API (reading the open bags, showing item tooltips, lifecycle events and their own settings), never by using, moving or selling items, and like any addon they run alongside BagSmith rather than in a sandbox. We'd love to see what you come up with.")
end
-- A plugin's options page, drawn by the plugin's registered render function through a small bridge of core
-- rows. Never rendered by search (it is not a sidebar page), so options callbacks never run from enumeration.
function Panel:ShowPluginOptions(id, addon)
	self.pluginPage, self.pluginPageAddon = id, addon
	self:ShowPage("pluginoptions")
end
pages.pluginoptions = function(self, db)
	local api = pluginAPI()
	local p = api and api:Plugin(self.pluginPage or "")
	if p and self.pluginPageAddon and p.addon ~= self.pluginPageAddon then p = nil end   -- the registration must be this row's addon
	self:Button("Back to Plugins", function() Panel:ShowPage("plugins") end)
	if not (p and p.state == "active" and p.options) then self:Head("Plugin options"); self:Text("This plugin has no options, or is not active."); return end
	self:Head(p.options.title)
	local panel = self
	local id = p.id
	-- Every plugin callback a widget holds runs through the API's guarded dispatch: the plugin must still be
	-- active at the click (not merely when the page was drawn), and an error fails the plugin through its one
	-- terminal path, after which the page is redrawn and these widgets are gone.
	local function guarded(what, fn, ...)
		local ok, code, err = api:Invoke(id, "options " .. what, fn, ...)
		if not ok then ns:NextFrame("settings:plugin-failed", function() Panel:Refresh() end) end
		return ok, code, err
	end
	local ui = {}
	function ui:Head(text) panel:Head(tostring(text)) end
	function ui:Text(text) panel:Text(tostring(text)) end
	function ui:Check(label, help, get, set)
		local c = acquire(panel, "check", function(pp)
			local w = CreateFrame("Frame", nil, pp); w:SetSize(ROW_W, LINE)
			w.text = fs(w); w.help = fs(w)
			w.box = CreateFrame("CheckButton", nil, w, "UICheckButtonTemplate"); w.box:SetSize(24, 24)
			w.box:SetScript("OnClick", function(b) local row = b:GetParent(); if row.onSet then row.onSet(b:GetChecked() and true or false) else ns:Set(row.key, b:GetChecked() and true or false) end end)
			return w
		end)
		c.key = nil
		c.onSet = function(v) local ok = guarded("setter", set, v); if ok then Panel:Refresh() end end
		local cy = layoutRow(c, tostring(label), help and tostring(help) or nil, 24, 24)
		c.box:ClearAllPoints(); c.box:SetPoint("TOPRIGHT", 0, cy)
		local okG, v = guarded("getter", get)   -- Invoke returns (true, value) on success and (false, code, message) on failure
		if okG then c.box:SetChecked(v and true or false); c.box:Enable()
		else c.box:SetChecked(false); c.box:Disable(); c.help:SetText("This option could not be read; the plugin has been stopped."); c.help:Show() end
		panel.y = panel.y + c:GetHeight()
	end
	function ui:Button(label, onClick) panel:Button(tostring(label), function() guarded("button", onClick) end) end
	local okR = guarded("render", p.options.render, ui)
	if not okR then self:Text("This plugin's options failed to draw; the plugin has been stopped.") end
end
-- A plugin failing while its options page is open: the page is redrawn so its widgets no longer carry plugin code.
ns:OnSignal("PLUGIN_STATE_CHANGED", function(id)
	if Panel.frame and Panel.frame:IsShown() then Panel:Refresh() end
end)
-- Core check rows made by ns:Set keep that path; a plugin check row has onSet instead (the shared pool).
pages.about = function(self) self:About() end

function Panel:Refresh()
	if not self.frame or not self.frame:IsShown() then return end
	self.counts, self.y = {}, 4
	self.card, rowX, rowW = nil, 0, ROW_W
	for _, pool in pairs(self.pools) do for _, w in ipairs(pool) do w:Hide() end end
	self.frame.sub:SetText("Profile: " .. ns.profileName)
	local fn = pages[self.page] or pages.profile
	if self.query then self:RefreshSearch(ns.db) else fn(self, ns.db) end
	self:CloseCard()
	self.frame.child:SetHeight(self.y + 10)
	self.frame.child:SetWidth(ROW_W)
	-- The scrollbar only when the page is taller than the window.
	local sb, h = self.scroll and self.scroll.ScrollBar, self.scroll and self.scroll:GetHeight()
	if sb and h and h > 0 then
		local need = self.y + 10 > h + 1
		sb:SetShown(need)
		if not need then self.scroll:SetVerticalScroll(0) end
	end
	if ns.Classic then ns.Classic:DressButtons(self.frame) end   -- new rows match the current skin
end

-- The profile segment writes a fake key; intercept it.
local origSet = ns.Set
function ns:Set(key, value, silent)
	if key == "__profile" then local ok, err = ns.Profiles:Use(value); if not ok then ns:Print(err) end return ok end
	-- When the Main Window Opens: two stored switches behind one choice.
	if key == "__openWindows" then
		origSet(self, "bagWindows", value == "all", true)
		return origSet(self, "reagentWindow", value == "all" or value == "reagent", silent)
	end
	return origSet(self, key, value, silent)
end

function Panel:Show()
	if ns.API then ns.API:RefreshPlugins() end
	self:Create()
	self:ApplyPosition()
	self.frame:Show()
	self:SyncNav()
	self:Refresh()
	if ns.Window.main and ns.Window.main.btnSettings then ns.Window.main.btnSettings:SetActive(true) end
end
function Panel:Hide()
	if self.frame then self.frame:Hide() end
	if ns.Window.main and ns.Window.main.btnSettings then ns.Window.main.btnSettings:SetActive(false) end
end
function Panel:Toggle() if self.frame and self.frame:IsShown() then self:Hide() else self:Show() end end

ns:OnSignal("SETTINGS_CHANGED", function(key)
	if Panel.frame and Panel.frame:IsShown() then
		if key == nil or key == "scale" then Panel:ApplyPosition() end
		Panel:Refresh()
	end
end)

------------------------------------------------------------------------
-- Search: every page at once, like the game's own Options search. The
-- results list each page that has a match under its name, then only the
-- cards and rows that match, as the real controls. A card whose heading
-- matches shows whole. Every word typed must match a row's label, help or
-- option names. Opening a page or clearing the box ends the search.
------------------------------------------------------------------------
local SEARCH_MIN = 2   -- letters before a search starts
local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")):lower() end
local function matches(words, ...)
	local parts = {}
	for i = 1, select("#", ...) do local v = select(i, ...); if v ~= nil then parts[#parts + 1] = plain(v) end end
	local hay = table.concat(parts, " ")
	for _, w in ipairs(words) do if not hay:find(w, 1, true) then return false end end
	return true
end
function Panel:SetQuery(text)
	text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local q = (#text >= SEARCH_MIN) and text or nil
	if q == self.query then return end
	if q and ns.KeyBinds then ns.KeyBinds:CancelCapture() end
	self.query = q
	if self.scroll then self.scroll:SetVerticalScroll(0) end
	self:SyncNav()
	self:Refresh()
end
function Panel:Searching() return self.query ~= nil end
-- A page's name as a big title (the results list).
function Panel:PageTitle(text)
	local w = acquire(self, "ptitle", function(p)
		local w = CreateFrame("Frame", nil, p); w:SetSize(ROW_W, 30)
		w.text = fs(w, "GameFontNormalLarge"); w.text:SetPoint("BOTTOMLEFT", 2, 4)
		return w
	end)
	w.text:SetText(text); w.text:SetTextColor(Skins:Color("heading"))
	self.y = self.y + 34
end
-- What each kind of row is searched by.
local SEARCHED = {
	Text = function() return nil end,   -- explanations show only with their whole card
	CornerCards = function() return nil end,
	Command = function(cmd, desc) return cmd, desc end,
	Check = function(_, label, help) return label, help end,
	Seg = function(_, label, options, help)
		local t = {}
		for _, o in ipairs(type(options) == "table" and options or {}) do t[#t + 1] = o[2] end
		return label, help, table.concat(t, " ")
	end,
	Step = function(_, label, _, _, help, info)
		local extra = help or ""
		if info then extra = extra .. " " .. table.concat(info.lines or {}, " ") .. " " .. (info.keywords or "") end
		return label, extra
	end,
	Color = function(_, label, help) return label, help end,
	Profiles = function() return "profile profiles new copy rename delete reset share import export " .. tostring(ns.profileName or "") end,
	List = function(items)
		local t = {}
		for _, it in ipairs(type(items) == "table" and items or {}) do t[#t + 1] = it.label end
		return table.concat(t, " ")
	end,
	Binding = function(_, label) return label, "keybinding key bind" end,
	CustomSectionRow = function(c) return c and c.name, "custom section" end,
	GearSetRow = function(set) return set and set.name, "gear set" end,
	MovedRow = function() return "moved items manage reset all" end,
	VisibilityRow = function(id) return ns.Sections and ns.Sections:Label(id), "show at vendor auction house ah" end,
	PinRow = function(id) return ns.Sections and ns.Sections:Label(id), "pin pinned top" end,   -- (1.4.0)
	Button = function(label) return label end,
	Edit = function(placeholder) return placeholder end,
	About = function() return "about support version discord curseforge buy me a coffee bagsmith" end,
	PluginRow = function(item) local e, st = item.entry, item.status; return (e.title or "") .. " " .. (e.author or "") .. " " .. (e.notes or "") .. " " .. tostring(st.text), "plugin plugins addon controller gamepad" end,
	PluginNotice = function() return "plugins reload required pending change" end,
	FeaturedCard = function(info) return (info.title or "") .. " " .. (info.text or ""), "plugin plugins featured official controller gamepad curseforge discord" end,
}
-- (1.5.6) Ranking (Shweep: searching "Recent" put its own setting near the bottom). A measuring pass grades each page by
-- its best match, without drawing: 1, a setting's or card's own name starts with what was typed; 2, a name contains it
-- further in, a row only names it (section lists, visibility, pins, custom sections, gear sets, plugins), or the page's
-- name matches; 3, only a help line, an option or a keyword mentions it. Pages are then drawn best tier first, in menu
-- order within a tier, each with its rows in their usual order.
local NAMED = { Check = true, Seg = true, Step = true, Color = true, Binding = true, Button = true, Command = true, Edit = true }
local NAMES = { List = true, VisibilityRow = true, PinRow = true, CustomSectionRow = true, GearSetRow = true, PluginRow = true, FeaturedCard = true }
local function searchTier(kind, f, ...)
	if not matches(f.words, ...) then return nil end
	local name = (...)
	name = name ~= nil and plain(name) or ""
	if NAMED[kind] and name:sub(1, #f.phrase) == f.phrase then return 1 end
	if (NAMED[kind] or NAMES[kind]) and matches(f.words, name) then return 2 end
	return 3
end
-- The page name, then the card's heading (and a pending sub-heading), are
-- drawn just before the first row that passes.
function Panel:EmitPending()
	local f = self.filter
	if not f.pageShown then
		f.pageShown = true
		self:CloseCard()
		self:PageTitle(f.pageLabel)
	end
	if f.pendingHead then
		local text = f.pendingHead
		f.pendingHead = nil
		f.origHead(self, text, f.pendingHeadInfo)
	end
	if f.pendingSub then local fn = f.pendingSub; f.pendingSub = nil; fn() end
	-- An indented setting brings the setting it belongs to (drawn unindented).
	local p = f.indentParent
	if p then
		f.indentParent = nil
		local x, w = rowX, rowW
		rowX, rowW = f.indentX0, f.indentW0
		p.orig(self, unpack(p.args, 1, p.n))
		rowX, rowW = x, w
	end
end
for name, textOf in pairs(SEARCHED) do
	local orig = Panel[name]
	Panel[name] = function(self, ...)
		local f = self.filter
		if f then
			if f.measure then   -- (1.5.6) grading only: nothing is drawn
				local tier = searchTier(name, f, textOf(...))
				if tier and tier < f.best then f.best = tier end
				return
			end
			if not (f.cardAll or matches(f.words, textOf(...))) then
				-- Remembered, in case a setting indented under it matches.
				f.lastSkipped = { orig = orig, args = { ... }, n = select("#", ...) }
				return
			end
			f.lastSkipped = nil
			self:EmitPending()
		end
		return orig(self, ...)
	end
end
-- (an assignment, not a second "function Panel:Head": the original stays the one definition)
local origHead = Panel.Head
Panel.Head = function(self, text, info)
	local f = self.filter
	if not f then return origHead(self, text, info) end
	if f.measure then   -- (1.5.6) grading only
		local plainText = plain(text)
		local tier
		if plainText:sub(1, #f.phrase) == f.phrase then tier = 1
		elseif matches(f.words, text) then tier = 2
		elseif info and matches(f.words, table.concat(info.lines or {}, " "), info.keywords) then tier = 3 end
		if tier and tier < f.best then f.best = tier end
		return
	end
	self:CloseCard()
	f.pendingHead, f.pendingSub, f.lastSkipped = text, nil, nil
	f.pendingHeadInfo = info
	local words = text
	if info then words = words .. " " .. table.concat(info.lines or {}, " ") .. " " .. (info.keywords or "") end
	f.cardAll = f.pageAll or matches(f.words, words)
	if f.cardAll then self:EmitPending() end
end
-- Column headings over a set of rows show only with a row under them.
for _, name in ipairs({ "VisibilityHeader", "CustomSectionHeader" }) do
	local orig = Panel[name]
	Panel[name] = function(self, ...)
		local f = self.filter
		if not f or f.cardAll then return orig(self, ...) end
		local args = { ... }
		f.pendingSub = function() orig(self, unpack(args)) end
	end
end
local origText = Panel.Text
function Panel:RefreshSearch(db)
	local words = {}
	for w in self.query:lower():gmatch("%S+") do words[#words + 1] = w end
	local phrase = table.concat(words, " ")
	-- (1.5.6) The measuring pass: each page's best tier, nothing drawn. Anything a page draws outside the searched rows
	-- is wiped by the same reset Refresh does, before the results are drawn.
	local y0 = self.y
	local graded = {}
	for i, p in ipairs(PAGES) do   -- (About & Support has its own button: never searched)
		self.filter = { words = words, phrase = phrase, measure = true, best = math.huge }
		local ok = pcall(pages[p[1]], self, db)
		local best = self.filter.best
		self.filter = nil
		if matches(words, p[2]) and best > 2 then best = 2 end   -- the page's own name
		if ok and best < math.huge then graded[#graded + 1] = { page = p, best = best, order = i } end
	end
	self.card, rowX, rowW = nil, 0, ROW_W
	self.counts, self.y = {}, y0
	for _, pool in pairs(self.pools) do for _, w in ipairs(pool) do w:Hide() end end
	table.sort(graded, function(a, b) if a.best ~= b.best then return a.best < b.best end return a.order < b.order end)
	self:PageTitle("Results:")
	local list = {}
	for _, g in ipairs(graded) do list[#list + 1] = g.page end
	local any = false
	for _, p in ipairs(list) do
		self.filter = { words = words, pageLabel = p[2], origHead = origHead, pageAll = matches(words, p[2]) }
		local ok, err = pcall(pages[p[1]], self, db)
		self:CloseCard()
		local shown = self.filter.pageShown
		self.filter = nil
		if not ok then error(err, 0) end
		if shown then any = true; self.y = self.y + 6 end
	end
	if not any then origText(self, "No results found. Try different words.") end
end
