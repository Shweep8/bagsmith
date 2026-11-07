--[[
	BagSmith - Frames/View.lua
	A bag view: the window itself (title bar, search, toolbar, tabs, footer,
	size and position). The bags window, the bank window and the small bag
	windows are all views with different options:
	  opts.kind   "main" | "bank" | "bag"
	  opts.bags   list of bag IDs (bag windows); main and bank decide their own
	  opts.bank   true for the bank's small bag windows
	  opts.title  window title
	The bags window's state lives in ns.ui, the bank window's in ns.uiBank.

	Split across three files:
	  View.lua      the window and its controls (this file)
	  ViewList.lua  what the list shows and how rows, cells and sections lay out
	  Scroll.lua    everything about scrolling the list
--]]

local ADDON, ns = ...
local Skins, Buttons = ns.Skins, ns.Buttons

local View = {}
View.__index = View
ns.View = View
ns.views = {}

ns.ui = { sheet = "All", filters = ns.EmptyFilters(), owner = nil, search = "" }
-- The bag-windows and reagent-window settings are starting states: applied
-- when BagSmith opens. During a session the footer icons and the windows'
-- own close buttons decide, remembered until BagSmith is closed.
function ns.SessionWindows()
	if ns.ui.bagWindows == nil then ns.ui.bagWindows = ns.db.bagWindows end
	if ns.ui.reagentWindow == nil then ns.ui.reagentWindow = ns.db.reagentWindow end
	return ns.ui.bagWindows, ns.ui.reagentWindow
end
-- The bank window keeps its own sheet, filters and column sort.
ns.uiBank = { sheet = "All", filters = ns.EmptyFilters() }

-- Grouping, sort, view and stack merging are separate settings for the bank window.
local BANK_PREF = { grp = "bankGrp", sort = "bankSort", view = "bankView", mergeStacks = "bankMerge",
	cols = "bankCols", colOrder = "bankColOrder", colWidths = "bankColWidths" }
-- Sheets remember their own view (optional, the sheetViews setting): each
-- sheet tab keeps its own Sections, Sort, View, Merge Stacks and collapsed
-- sections. The All tab, and every tab with the setting off, use the
-- window's own settings. Sheets only store what was changed on them; the
-- rest follows the window.
local SHEET_KEYS = { grp = true, sort = true, view = true, mergeStacks = true }
function View:SheetPrefs(create)
	if not (ns.db.sheetViews and self.big and self.st and self.st.sheet and self.st.sheet ~= "All") then return nil end
	if ns.ui.owner and not self.isBank then return nil end   -- browsing another character
	local all = ns.db.sheetPrefs
	local win = self.isBank and "bank" or "bags"
	all[win] = all[win] or (create and {} or nil)
	if not all[win] then return nil end
	local p = all[win][self.st.sheet]
	if not p and create then p = { collapsed = {} }; all[win][self.st.sheet] = p end
	return p
end
function View:Pref(key)
	if SHEET_KEYS[key] then
		local p = self:SheetPrefs(false)
		if p and p[key] ~= nil then return p[key] end
	end
	if self.isBank and BANK_PREF[key] then return ns.db[BANK_PREF[key]] end
	return ns.db[key]
end
-- (1.4.1) A change of sort, view or grouping is a fresh layout: slots moved to the end of All Items this session go
-- back to their real place.
local FRESH_KEYS = { sort = true, view = true, grp = true }
function View:FreshLayout() self.freedSlots, self.lastOmitted, self.freedSeq = nil, nil, nil end
function View:SetPref(key, value)
	if FRESH_KEYS[key] then self:FreshLayout() end
	if SHEET_KEYS[key] then
		local p = self:SheetPrefs(true)
		if p then
			p[key] = value   -- silent like the window setting; callers refresh
			return true
		end
	end
	return ns:Set((self.isBank and BANK_PREF[key]) or key, value, true)
end

local PAD, TITLE_H, TOOL_H, HEADER_H, TAB_H, FOOTER_H, LANE_H, GAP = 12, 26, 26, 20, 22, 26, 26, 6
local MONEY_X = 10   -- the gold's distance from the footer's left edge
local COLW = { c = 0.07, il = 0.07, rq = 0.06, t = 0.16, sl = 0.11, bd = 0.07, v = 0.12, w = 0.14, age = 0.08, ah = 0.12, jk = 0.05, fv = 0.05, cc = 0.05 }
local COLPAD = 10   -- gap kept clear at the right edge of every column
local BAR_ROOM = 22 -- the scrollbar's lane at the right of a list; given back to the list when nothing scrolls
local NUMERIC = { c = true, il = true, rq = true, v = true, age = true, ah = true }
local COLKEY = { c = "colQty", il = "colLevel", rq = "colReq", t = "colType", sl = "colSlot", bd = "colBind", v = "colValue", w = "colWhere", age = "colAge", ah = "colAH", jk = "colJunk", fv = "colFav", cc = "colCurr" }
-- Shared with ViewList.lua and Scroll.lua.
View.C = { TITLE_H = TITLE_H, FOOTER_H = FOOTER_H, PAD = PAD, HEADER_H = HEADER_H, LANE_H = LANE_H, GAP = GAP, COLW = COLW, COLPAD = COLPAD, NUMERIC = NUMERIC, COLKEY = COLKEY, TAB_H = TAB_H }

------------------------------------------------------------------------
-- Small widget helpers
------------------------------------------------------------------------
local function fontString(parent, template, justify)
	local s = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
	s:SetJustifyH(justify or "LEFT")
	s:SetWordWrap(false)
	return s
end

------------------------------------------------------------------------
-- Modern hover: one style for every button. Classic leaves hover to
-- Blizzard's art and keeps today's look on its Modern-looking pieces, so
-- none of this paints while Classic is on. Leaving, hiding the button or a
-- skin change always puts the resting look back.
------------------------------------------------------------------------
local HOVER_WASH = 0.10   -- total white wash on hover for icon buttons and list rows
local function modernSkin() return not (ns.Classic and ns.Classic.IsOn and ns.Classic.IsOn()) end
View.ModernSkin = modernSkin
-- paint(button) draws the button for its current state; button.hover says
-- whether the pointer is on it.
local function hover(b, paint)
	b:HookScript("OnEnter", function(x) x.hover = true; paint(x) end)
	b:HookScript("OnLeave", function(x) x.hover = false; paint(x) end)
	b:HookScript("OnHide", function(x) if x.hover then x.hover = false; paint(x) end end)
end
ns.Hover = hover
-- A wash shown while hovered in Modern, on top of any highlight the button
-- already has (existing = that highlight's alpha), so the total is HOVER_WASH.
-- target: the frame that gets the wash (defaults to b).
local function hoverWash(b, existing, target)
	target = target or b
	if not target.hoverWash then
		target.hoverWash = target:CreateTexture(nil, "ARTWORK", nil, 7)
		target.hoverWash:SetTexture("Interface\\Buttons\\WHITE8X8")
		target.hoverWash:SetAllPoints(target)
		target.hoverWash:SetVertexColor(1, 1, 1, math.max(0, HOVER_WASH - (existing or 0)))
		target.hoverWash:Hide()
	end
	hover(b, function(x) target.hoverWash:SetShown(x.hover and modernSkin() and not target.classicOn) end)
end
ns.HoverWash = hoverWash

local function textButton(parent, text, width, onClick, template, name)
	-- 1.2.0: a template lets a secure action button wear the same look (its click is the game's, not ours)
	local b = CreateFrame("Button", name, parent, template and (template .. ", BackdropTemplate") or "BackdropTemplate")
	b:SetSize(width or 60, 20)
	b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	b.label = fontString(b, "GameFontHighlightSmall", "CENTER")
	b.label:SetPoint("CENTER")
	b.label:SetText(text)
	if onClick then b:SetScript("OnClick", onClick) end
	b:SetScript("OnEnter", function(self) if self.tip and ns.TooltipsOK() then GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(self.tip); GameTooltip:Show() end end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	hover(b, function(x) if modernSkin() and not x.classicOn then x:SetActive(x.active) end end)
	function b:SetActive(on)
		self.active = on
		local s = Skins:Current()
		if self.classicOn and self.classic then
			if self.classic.isTab then
				-- Blizzard tabs: their own selected and unselected art.
				local fn = on and PanelTemplates_SelectTab or PanelTemplates_DeselectTab
				if fn then pcall(fn, self.classic) end
				if on then self.label:SetTextColor(1, 1, 1) else self.label:SetTextColor(1, 0.82, 0) end
			else
				-- Blizzard button: pressed while active, gold text when active.
				self.classic:SetButtonState(on and "PUSHED" or "NORMAL", on and true or false)
				if on then self.label:SetTextColor(1, 0.82, 0) else self.label:SetTextColor(0.95, 0.9, 0.8) end
			end
			return
		end
		-- Hover lifts the button a step; a selected one keeps its accent border
		-- and only brightens, so hover never looks like selection.
		local hov = self.hover and modernSkin()
		if on then
			local ar, ag, ab = Skins:Accent()
			if hov then self:SetBackdropColor(0.29, 0.28, 0.24, 1) else self:SetBackdropColor(0.23, 0.22, 0.19, 1) end
			self:SetBackdropBorderColor(ar, ag, ab, hov and 1 or 0.9)
			self.label:SetTextColor(s.heading[1], s.heading[2], s.heading[3])
		elseif hov then
			self:SetBackdropColor(s.chip[1] + 0.06, s.chip[2] + 0.06, s.chip[3] + 0.06, 1)
			self:SetBackdropBorderColor(s.line[1] + 0.14, s.line[2] + 0.14, s.line[3] + 0.14, 1)
			self.label:SetTextColor(s.text[1], s.text[2], s.text[3])
		else
			self:SetBackdropColor(s.chip[1], s.chip[2], s.chip[3], 1); self:SetBackdropBorderColor(s.line[1], s.line[2], s.line[3], 1)
			self.label:SetTextColor(s.muted[1], s.muted[2], s.muted[3])
		end
	end
	-- Classic: Blizzard's own button art (or tab art) under the label. The
	-- art is created once, on the first switch, and only shown or hidden after.
	function b:SetClassic(on, template)
		if on and not self.classic then
			local ok, art = pcall(CreateFrame, "Button", nil, self, template or "UIPanelButtonTemplate")
			if not ok or not art then return end
			art:SetAllPoints(self)
			art:EnableMouse(false)
			if art.SetText then art:SetText("") end
			art.isTab = template ~= nil and template ~= "UIPanelButtonTemplate"
			self.classic = art
			self:HookScript("OnMouseDown", function(s) if s.classicOn and not s.active then s.classic:SetButtonState("PUSHED") end end)
			self:HookScript("OnMouseUp", function(s) if s.classicOn and not s.active then s.classic:SetButtonState("NORMAL") end end)
			self:HookScript("OnEnter", function(s) if s.classicOn then s.classic:LockHighlight(); if ns.Classic and ns.Classic.TabArtReport then ns.Classic.TabArtReport(s) end end end)
			-- (1.5.0-beta6) the tab art follows the tab's height
			self:HookScript("OnSizeChanged", function(s) if s.classicOn and ns.Classic and ns.Classic.FitTabArt then ns.Classic.FitTabArt(s) end end)
			self:HookScript("OnLeave", function(s) if s.classicOn then s.classic:UnlockHighlight() end end)
		end
		self.classicOn = on and self.classic ~= nil
		if self.classic then
			self.classic:SetShown(self.classicOn)
			-- The label (and any icon riding with it) must draw above the art,
			-- so it moves onto the art frame.
			self.label:SetParent(self.classicOn and self.classic or self)
			for _, r in ipairs(self.riders or {}) do r:SetParent(self.classicOn and self.classic or self) end
			if self.classicOn then
				self:SetBackdropColor(0, 0, 0, 0); self:SetBackdropBorderColor(0, 0, 0, 0)
				if ns.Classic and ns.Classic.FitTabArt then ns.Classic.FitTabArt(self) end
			end
		end
		self:SetActive(self.active)
	end
	b:SetActive(false)
	-- Made inside a window that's already dressed in Classic (a pop-up's
	-- buttons, rows added later): Classic from the start, so no button ever
	-- shows the Modern look in Classic.
	local p, depth = parent, 0
	while p and depth < 8 do
		local st = p.classicState
		if st then
			if st.on then b:SetClassic(true) end
			break
		end
		p = p.GetParent and p:GetParent(); depth = depth + 1
	end
	return b
end
ns.TextButton = textButton

-- A footer button holding an icon and a count (the bag windows, the reagent
-- window, the bank's bag windows): the whole thing is one button in the
-- skin's own style, so the count is clickable too and reads as a control.
-- 20 px tall inside the 26 px footer, so the footer keeps its height.
local function countButton(parent, icon, tip, onClick)
	local b = textButton(parent, "", 40, onClick)
	b.tip = tip
	b.isCount = true
	b.icon = b:CreateTexture(nil, "OVERLAY")
	b.icon:SetSize(14, 14)
	b.icon:SetTexture(icon)
	b.icon:SetPoint("LEFT", b, "LEFT", 8, 0)
	b.label:ClearAllPoints()
	b.label:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
	b.riders = { b.icon }
	-- The icon takes the label's color, so it follows rest, hover and open.
	local setActive = b.SetActive
	function b:SetActive(on)
		setActive(self, on)
		local r, g, bl = self.label:GetTextColor()
		if r then self.icon:SetVertexColor(r, g, bl) end
	end
	function b:Fit() self:SetWidth(8 + 14 + 4 + math.ceil(self.label:GetStringWidth()) + 8) end
	b:SetActive(false)
	return b
end

local MUTED = { 0.62, 0.6, 0.55 }
local function iconButton(parent, texture, tip, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(24, 24)
	b.tex = b:CreateTexture(nil, "ARTWORK")
	b.tex:SetPoint("CENTER")
	b.tex:SetSize(16, 16)
	if texture:find("\\") then b.tex:SetTexture(texture) else b.tex:SetAtlas(texture) end
	b.tip = tip
	b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
	b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function(self)
		self.tex:SetVertexColor(0.93, 0.91, 0.88)
		if ns.TooltipsOK() then
			GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(self.tip)
			-- An optional second line (a function, so it can describe the moment).
			local sub = type(self.tipSub) == "function" and self.tipSub(self) or self.tipSub
			if sub then GameTooltip:AddLine(sub, nil, nil, nil, true) end
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self) self:SetActive(self.active); GameTooltip:Hide() end)
	hoverWash(b, 0.06)
	hover(b, function(x) if x.hover and modernSkin() and not x.active then x.tex:SetVertexColor(1, 1, 1) end end)
	function b:SetActive(on)
		self.active = on
		if on then self.tex:SetVertexColor(Skins:Accent()) else self.tex:SetVertexColor(unpack(self.restColor or MUTED)) end
	end
	b:SetActive(false)
	return b
end
ns.IconButton = iconButton

------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------
function View.New(name, opts)
	local self = setmetatable({ name = name, opts = opts, kind = opts.kind }, View)
	self.isMain = opts.kind == "main"
	self.isBank = opts.kind == "bank"
	self.big = self.isMain or self.isBank   -- windows with search, tools, header, footer
	self.st = (self.isBank or opts.bank) and ns.uiBank or ns.ui
	ns.views[name] = self
	self:Build()
	-- (1.4.1) closing the window ends the session: the next open lays everything out in its true bag order (hooked
	-- after Build, which sets the frame's own OnHide)
	if self.frame and self.frame.HookScript then self.frame:HookScript("OnHide", function() self:FreshLayout() end) end
	return self
end

function View:Build()
	local f = CreateFrame("Frame", self.name, UIParent, "BackdropTemplate")
	self.frame = f
	f.view = self
	f:Hide()
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:SetResizable(true)
	if f.SetResizeBounds then f:SetResizeBounds(620, 300, 1400, 1200) end   -- up to 1400 wide, 1200 tall

	-- Title bar
	-- The whole top band drags the window, from the very top edge down to the
	-- title row. Buttons in the band sit above it and still take clicks.
	local drag = CreateFrame("Frame", nil, f)
	drag:SetPoint("TOPLEFT", 0, 0)
	drag:SetPoint("TOPRIGHT", 0, 0)
	drag:SetHeight(PAD + TITLE_H + 6)
	drag:EnableMouse(true)
	drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart", function() f:StartMoving() end)
	drag:SetScript("OnDragStop", function() f:StopMovingOrSizing(); self:SavePosition(); ns:RepositionPanels() end)
	self.dragArea = drag

	local title = CreateFrame("Frame", nil, f)
	title:SetPoint("TOPLEFT", PAD, -PAD)
	title:SetPoint("TOPRIGHT", -PAD, -PAD)
	title:SetHeight(TITLE_H)
	title:SetFrameLevel(drag:GetFrameLevel() + 2)
	self.title = title
	-- What sits below the title row (search, toolbar, list) starts this far left of the title's left edge: 0 in
	-- Modern; in Classic, where the title moves beside the portrait, the difference back to the inner margin (1.3.0).
	self.belowShift = 0

	-- One band behind the whole toolbar area (title, search, tools). Its
	-- bottom edge is anchored once the tools row exists, below.
	title.band = f:CreateTexture(nil, "BACKGROUND")
	title.band:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
	title.band:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	title.band:SetTexture("Interface\\Buttons\\WHITE8X8")
	title.band:SetVertexColor(1, 1, 1, 0.045)
	title.band:SetPoint("BOTTOM", title, "BOTTOM", 0, -4)

	local mark = title:CreateTexture(nil, "ARTWORK")
	mark:SetSize(16, 16)
	mark:SetPoint("LEFT", 0, 0)
	mark:SetTexture("Interface\\AddOns\\BagSmith\\Media\\mark.tga")
	self.mark = mark
	self.titleText = fontString(title, "GameFontNormal")
	self.titleText:SetPoint("LEFT", mark, "RIGHT", 6, 0)
	self.subText = fontString(title, "GameFontHighlightSmall")
	self.subText:SetPoint("LEFT", self.titleText, "RIGHT", 8, 0)

	local MEDIA = "Interface\\AddOns\\BagSmith\\Media\\"
	local close = iconButton(title, MEDIA .. "ui-close.tga", "Close", function()
		if self.kind == "bag" then
			-- Close just this window. The footer icon still opens or closes the
			-- whole set; once every window in a set is closed the set is off.
			ns:CloseBagWindow(self.opts.bags[1], self.opts.bank)
			ns:RefreshViews(true)
		else
			self:Hide()
		end
	end)
	close:SetPoint("RIGHT", 2, 0)
	self.closeBtn = close
	if not self.big then
		-- Small windows keep their slot count in the title bar, left of the close button.
		self.titleCount = fontString(title, "GameFontHighlightSmall", "RIGHT")
		self.titleCount:SetPoint("RIGHT", close, "LEFT", -8, 0)
		self.titleText:SetPoint("RIGHT", self.titleCount, "LEFT", -10, 0)
		self.titleText:SetWordWrap(false)
		self.subText:Hide()
	end

	local anchorLeft = title
	if self.isMain then
		-- Travel Mode: beside the close button, same style.
		self.btnTravel = iconButton(title, MEDIA .. "ui-signpost.tga", "Travel Mode", function() ns:ToggleTravel() end)
		self.btnTravel.tipSub = function() return ns:TravelTip() end
		self.btnTravel:SetPoint("RIGHT", close, "LEFT", 0, 0)
		-- A thin divider: the tool icons on one side, the window's own
		-- controls (Travel Mode, close) on the other.
		self.titleDivider = title:CreateTexture(nil, "ARTWORK")
		self.titleDivider:SetSize(1, 16)
		self.titleDivider:SetPoint("RIGHT", self.btnTravel, "LEFT", -4, 0)
		self.btnSettings = iconButton(title, MEDIA .. "ui-cog.tga", "Settings", function() ns.SettingsPanel:Toggle() end)
		self.btnSettings:SetPoint("RIGHT", self.titleDivider, "LEFT", -4, 0)
		self.btnCurrency = iconButton(title, MEDIA .. "ui-wallet.tga", "Currencies", function() ns.Drawer:Toggle() end)
		self.btnCurrency:SetPoint("RIGHT", self.btnSettings, "LEFT", 0, 0)
		self.btnBank = iconButton(title, MEDIA .. "ui-bank.tga", "Bank", function() self:SetSheet(self.st.sheet == "Bank" and "All" or "Bank") end)
		self.btnBank:SetPoint("RIGHT", self.btnCurrency, "LEFT", 0, 0)
		-- The Gear Sets tab, the same way (shown when the client has equipment sets).
		self.btnGearSets = iconButton(title, MEDIA .. "ui-sword-shield.tga", "Gear Sets", function() self:SetSheet(self.st.sheet == "GearSets" and "All" or "GearSets") end)
		self.btnGearSets:SetPoint("RIGHT", self.btnBank, "LEFT", 0, 0)
		self.btnGearSets:Hide()
		-- The Disenchant Helper (1.2.0), shown while the helper is on in settings.
		self.btnDisenchant = iconButton(title, MEDIA .. "ui-disenchant.tga", "Disenchant Helper", function() if ns.Disenchant then ns.Disenchant:Toggle() end end)
		self.btnDisenchant:SetPoint("RIGHT", self.btnBank, "LEFT", 0, 0)
		self.btnDisenchant:Hide()
		self.btnClean = iconButton(title, MEDIA .. "ui-broom.tga", "Clean Up Bags", function() self:CleanUp() end)
		self.btnClean:SetPoint("RIGHT", self.btnBank, "LEFT", 0, 0)

		-- Character picker
		self.charBtn = textButton(title, "", 170, function() ns.Popups:ToggleCharacters(self) end)
		self.charBtn:SetHeight(22)
		self.charBtn:SetPoint("LEFT", self.subText, "RIGHT", 10, 0)
		self.charIcon = self.charBtn:CreateTexture(nil, "ARTWORK")
		self.charIcon:SetSize(14, 14)
		self.charIcon:SetPoint("LEFT", 6, 0)
		self.charBtn.label:ClearAllPoints()
		self.charBtn.label:SetPoint("LEFT", self.charIcon, "RIGHT", 5, 0)
		self.charBtn.label:SetPoint("RIGHT", -18, 0)
		self.charBtn.label:SetJustifyH("LEFT")
		self.charArrow = self.charBtn:CreateTexture(nil, "OVERLAY")
		self.charArrow:SetSize(11, 11)
		self.charArrow:SetPoint("RIGHT", -6, 0)
		self.charArrow:SetTexture("Interface\\AddOns\\BagSmith\\Media\\ui-chev-down.tga")
		self.charArrow:SetVertexColor(0.62, 0.6, 0.55)
		self.charReset = iconButton(title, MEDIA .. "ui-close.tga", "Back to Your Own Bags", function() self:SetOwner(nil) end)
		self.charReset.tex:SetSize(11, 11)
		self.charReset:SetPoint("LEFT", self.charBtn, "RIGHT", 2, 0)
		self.charReset:Hide()
	end
	if self.big then
		-- Search + filter
		local search = CreateFrame("EditBox", self.name .. "Search", f, "SearchBoxTemplate")
		search:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 4, -2)
		search:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", -70, -2)
		search:SetHeight(TOOL_H)
		search:SetAutoFocus(false)
		-- Above the drag band: in Travel Mode the search sits in the title row.
		search:SetFrameLevel(drag:GetFrameLevel() + 3)
		search:HookScript("OnTextChanged", function(box)
			local t = box:GetText() or ""
			if t ~= self.st.filters.text then
				self.st.filters.text = t
				local P = ns.Popups
				if P.filter and P.filter:IsShown() and P.view == self and not P.syncing then P.syncing = true; P.filter.search:SetText(t); P.syncing = false end
				ns:RefreshViews()
			end
		end)
		search:SetScript("OnEscapePressed", function(box) box:SetText(""); box:ClearFocus() end)
		self.search = search
		self.btnFilter = textButton(f, "Filter", 64, function() ns.Popups:ToggleFilters(self) end)
		self.btnFilter:SetHeight(TOOL_H - 4)
		self.btnFilter:SetPoint("LEFT", search, "RIGHT", 6, 0)

		-- Tools row. Spans the window (not the search row): the search row
		-- follows the toolbar's end (see LayoutTools), so the toolbar must not
		-- take its width from the search row, or the two would chase each other.
		local tools = CreateFrame("Frame", nil, f)
		tools:SetPoint("TOPLEFT", search, "BOTTOMLEFT", -4, -4)
		tools:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -(2 + TOOL_H + 4))
		tools:SetHeight(TOOL_H)
		self.tools = tools
		self.toolItems = {}
		-- An exclusive group: a small muted label, then joined segments with no
		-- gap between them, so it reads as one control. Standalone actions get
		-- their own separate buttons with clear space around them.
		local function seg(label, items, get, set)
			local btns = {}
			local lbl = fontString(tools, "GameFontHighlightSmall")
			lbl:SetText(label); lbl:SetTextColor(0.56, 0.55, 0.51)
			self.toolItems[#self.toolItems + 1] = { frame = lbl, width = lbl:GetStringWidth(), gap = 6, isLabel = true }
			-- One bordered container holds the segments; thin dividers separate
			-- them; the active one gets a fill plus its own full outline on top.
			local total = 0
			for _, it in ipairs(items) do total = total + (it[3] or 54) end
			local box = CreateFrame("Frame", nil, tools, "BackdropTemplate")
			box:SetSize(total + 2, 20)
			self.segBoxes = self.segBoxes or {}
			self.segBoxes[#self.segBoxes + 1] = box
			box.btns = btns
			self.toolItems[#self.toolItems + 1] = { frame = box, width = total + 2, gap = 14 }
			box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
			local sx = 1
			for i, it in ipairs(items) do
				local w = it[3] or 54
				local b = CreateFrame("Button", nil, box, "BackdropTemplate")
				b:SetSize(w, 18)
				b:SetPoint("LEFT", box, "LEFT", sx, 0)
				b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
				b.label = fontString(b, "GameFontHighlightSmall", "CENTER"); b.label:SetPoint("CENTER"); b.label:SetText(it[2])
				b.value = it[1]
				b:SetScript("OnClick", function() set(it[1]); for _, o in ipairs(btns) do o:SetActive(get() == o.value) end; ns:RefreshViews(true) end)
				if i < #items then
					b.divider = box:CreateTexture(nil, "ARTWORK")
					b.divider:SetTexture("Interface\\Buttons\\WHITE8X8"); b.divider:SetWidth(1)
					b.divider:SetPoint("TOP", box, "TOPLEFT", sx + w, -1); b.divider:SetPoint("BOTTOM", box, "BOTTOMLEFT", sx + w, 1)
				end
				function b:SetActive(on)
					self.active = on
					local s = Skins:Current()
					local hov = self.hover and modernSkin()
					if on then
						local ar, ag, ab = Skins:Accent()
						if hov then self:SetBackdropColor(0.29, 0.28, 0.24, 1) else self:SetBackdropColor(0.23, 0.22, 0.19, 1) end
						self:SetBackdropBorderColor(ar, ag, ab, hov and 1 or 0.9)
						self:SetFrameLevel(box:GetFrameLevel() + 3)
						self.label:SetTextColor(s.heading[1], s.heading[2], s.heading[3])
					else
						-- Hovered: a light fill and a full-color label, no border, so
						-- the group still reads as one outlined control.
						if hov then self:SetBackdropColor(1, 1, 1, 0.07) else self:SetBackdropColor(0, 0, 0, 0) end
						self:SetBackdropBorderColor(0, 0, 0, 0)
						self:SetFrameLevel(box:GetFrameLevel() + 1)
						if hov then self.label:SetTextColor(s.text[1], s.text[2], s.text[3]) else self.label:SetTextColor(s.muted[1], s.muted[2], s.muted[3]) end
					end
				end
				hover(b, function(x) if modernSkin() and not x.classicOn then x:SetActive(x.active) end end)
				btns[#btns + 1] = b
				self.segButtons = self.segButtons or {}
				self.segButtons[#self.segButtons + 1] = b
				sx = sx + w
			end
			local function skin()
				local s = Skins:Current()
				if self.classicApplied then
					-- Classic draws these as separate Blizzard buttons; no group outline.
					box:SetBackdropColor(0, 0, 0, 0); box:SetBackdropBorderColor(0, 0, 0, 0)
					return
				end
				box:SetBackdropColor(s.chip[1], s.chip[2], s.chip[3], 1); box:SetBackdropBorderColor(s.line[1], s.line[2], s.line[3], 1)
				for _, b in ipairs(btns) do if b.divider then b.divider:SetVertexColor(s.line[1], s.line[2], s.line[3], 1) end end
			end
			Skins:Register(box, skin)
			local function sync() for _, o in ipairs(btns) do o:SetActive(get() == o.value) end end
			sync()
			return sync
		end
		self.syncGrp = seg("Sections", { { "none", "All", 38 }, { "type", "By Section", 64 }, { "bag", "By Bag", 54 } }, function() return self:Pref("grp") end, function(v) self:SetPref("grp", v) end)
		self.btnLanes = iconButton(tools, MEDIA .. "ui-collapse.tga", "Collapse or Expand All Sections", function() self:ToggleAllLanes() end)
		self.toolItems[#self.toolItems + 1] = { frame = self.btnLanes, width = 24, gap = 10, offset = -10 }
		self.btnSort = textButton(tools, "Sort: quality", 96, function()
			local modes, cur = { "quality", "name", "ilvl", "newest", "oldest", "off" }, self:Pref("sort")
			local i = ns.IndexOf(modes, cur) or 1
			self.st.colSort = nil
			self:SetPref("sort", modes[i % #modes + 1])
			self:SyncTools(); ns:RefreshViews(true)
		end)
		self.toolItems[#self.toolItems + 1] = { frame = self.btnSort, width = 96, gap = 8 }
		self.btnMerge = textButton(tools, "Merge Stacks", 92, function() self:SetPref("mergeStacks", not self:Pref("mergeStacks")); self:SyncTools(); ns:RefreshViews(true) end)
		self.btnMerge.tip = "Combine stacks of the same item into one, with the total count: one row in List view, one icon in Icons"
		self.toolItems[#self.toolItems + 1] = { frame = self.btnMerge, width = 92, gap = 12, compactText = "Merge", fullText = "Merge Stacks", compactWidth = 56 }
		self.syncView = seg("View", { { "list", "List", 46 }, { "icons", "Icons", 50 } }, function() return self:Pref("view") end, function(v) self:SetPref("view", v) end)
		title.band:ClearAllPoints()
		title.band:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
		title.band:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
		title.band:SetPoint("BOTTOM", tools, "BOTTOM", 0, -6)
		self:LayoutTools()
		tools:SetScript("OnSizeChanged", function() self:LayoutTools() end)
		anchorLeft = tools
	end
	if self.kind == "main" then
		-- The bag strip (backpack, bag slots, reagent bag slot): the same band
		-- as the bank window's, shown with the footer's bag-slots button.
		local bagBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
		bagBar:SetPoint("TOPLEFT", anchorLeft, "BOTTOMLEFT", 0, -10)
		bagBar:SetPoint("TOPRIGHT", anchorLeft, "BOTTOMRIGHT", 0, -10)
		bagBar:SetHeight(1)
		bagBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
		bagBar:SetBackdropColor(1, 1, 1, 0.04)
		bagBar:SetBackdropBorderColor(1, 1, 1, 0.08)
		bagBar:Hide()
		self.bagBar = bagBar
		self.bagBarAnchor = anchorLeft
	end
	if self.isBank then
		-- Bank bag slot bar: a clearly separated band of its own.
		local bankBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
		-- A little more room under the toolbar so the strip doesn't crowd it.
		bankBar:SetPoint("TOPLEFT", anchorLeft, "BOTTOMLEFT", 0, -10)
		bankBar:SetPoint("TOPRIGHT", anchorLeft, "BOTTOMRIGHT", 0, -10)
		bankBar:SetHeight(1)
		bankBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
		bankBar:SetBackdropColor(1, 1, 1, 0.04)
		bankBar:SetBackdropBorderColor(1, 1, 1, 0.08)
		self.bankBar = bankBar
		anchorLeft = bankBar
	end

	-- Column header
	local header = CreateFrame("Frame", nil, f)
	header:SetPoint("TOPLEFT", anchorLeft, "BOTTOMLEFT", 0, -4)
	header:SetPoint("TOPRIGHT", anchorLeft, "BOTTOMRIGHT", 0, -4)
	self.headerAnchor = anchorLeft
	header:SetHeight(HEADER_H)
	header.line = header:CreateTexture(nil, "ARTWORK")
	header.line:SetPoint("BOTTOMLEFT"); header.line:SetPoint("BOTTOMRIGHT"); header.line:SetHeight(1)
	self.header = header
	self.headerLabels = {}
	local function headerLabel(key, text)
		local b = CreateFrame("Button", nil, header)
		b:SetHeight(HEADER_H)
		b.text = fontString(b, "GameFontHighlightSmall")
		b.text:SetAllPoints()
		b.text:SetText(text)
		b.key = key
		b:SetScript("OnClick", function()
			ns:SortByColumn(self.st, key)
			if self.SyncTools then self:SyncTools() end
			ns:RefreshViews(true)
		end)
		b:SetScript("OnEnter", function(btn)
			if not ns.TooltipsOK() then return end
			GameTooltip:SetOwner(btn, "ANCHOR_TOP")
			GameTooltip:SetText("Click to sort by " .. text)
			if key == "age" then GameTooltip:AddLine("Time since BagSmith first saw the item in your bags", 0.6, 0.6, 0.6) end
			GameTooltip:AddLine("Drag the gold line on either side to resize", 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		hover(b, function(x)
			if not modernSkin() then return end
			local sk = Skins:Current()
			x.text:SetTextColor(unpack(x.hover and sk.text or sk.muted))
		end)
		self.headerLabels[key] = b
		return b
	end
	headerLabel("n", "Item")
	for _, c in ipairs(ns.COLS) do headerLabel(c[1], c[2]) end

	-- Sheet tabs (main and bank)
	if self.big then
		local tabs = CreateFrame("Frame", nil, f)
		tabs:SetPoint("BOTTOMLEFT", PAD, PAD + FOOTER_H + 2)
		tabs:SetPoint("BOTTOMRIGHT", -PAD, PAD + FOOTER_H + 2)
		tabs:SetHeight(TAB_H)
		self.tabs = tabs
		self.tabButtons = {}
	end

	-- Footer
	local footer = CreateFrame("Frame", nil, f)
	footer:SetPoint("BOTTOMLEFT", PAD, PAD)
	footer:SetPoint("BOTTOMRIGHT", -PAD, PAD)
	footer:SetHeight(FOOTER_H)
	footer.line = footer:CreateTexture(nil, "ARTWORK")
	footer.line:SetPoint("TOPLEFT"); footer.line:SetPoint("TOPRIGHT"); footer.line:SetHeight(1)
	self.footer = footer
	self.moneyText = fontString(footer, "GameFontHighlightSmall")
	-- The gold sits 10 px in from the left, closer to the room the count
	-- buttons keep on the right.
	self.moneyText:SetPoint("LEFT", MONEY_X, 0)
	-- Leave room for the resize grip in the corner of the main window.
	local rightEdge = self.big and -18 or -2
	if self.isBank then
		self.btnBags = countButton(footer, "Interface\\AddOns\\BagSmith\\Media\\mark.tga", "Show each bank bag in its own small window", function()
			ns.ui.bankBagWindows = not ns.ui.bankBagWindows; ns.ui.closedBankBags = {}; self:SyncTools(); ns:RefreshViews(true)
		end)
	elseif self.kind == "main" then
		self.btnBags = countButton(footer, "Interface\\AddOns\\BagSmith\\Media\\mark.tga", "Show the backpack and each bag in its own small window", function()
			local b = ns.SessionWindows(); ns.ui.bagWindows = not b; ns.ui.closedBags = {}; self:SyncTools(); ns:RefreshViews(true)
		end)
		-- Side by side: [reagent button] 6px [bags button]
		self.btnReagent = countButton(footer, "Interface\\AddOns\\BagSmith\\Media\\ui-leaf.tga", "Show the reagent bag in its own small window", function()
			local _, r = ns.SessionWindows(); ns.ui.reagentWindow = not r
			self:SyncTools(); ns:RefreshViews(true)
		end)
		self.btnReagent:SetPoint("RIGHT", self.btnBags, "LEFT", -6, 0)
		self.reagentText = self.btnReagent.label
		-- The bag strip's toggle: a wide button that looks like a row of bag slots.
		self.btnBagBar = ns.TextButton(footer, "", 62, function()
			ns:Set("bagBar", not ns.db.bagBar)
		end)
		self.btnBagBar:SetHeight(20)
		self.btnBagBar.inFooter = true   -- keeps 20 px in Classic, like the count buttons beside it
		self.btnBagBar.tip = "Show or hide your bags: equip or swap bags, and open a bag's own window"
		-- A narrow slot and six square slots: a mini bag bar, BagSmith's "open your bags" mark.
		local bi = self.btnBagBar:CreateTexture(nil, "OVERLAY")
		bi:SetSize(56, 14); bi:SetPoint("CENTER", 0, 0)
		bi:SetTexture("Interface\\AddOns\\BagSmith\\Media\\ui-bagbar.tga")
		self.btnBagBar.icon = bi
		self.btnBagBar.riders = { bi }
		self.btnBagBar:HookScript("OnEnter", function(b) b.iconHover = true; self:ColorBagBarButton() end)
		self.btnBagBar:HookScript("OnLeave", function(b) b.iconHover = false; self:ColorBagBarButton() end)
	end
	if self.btnBags then
		self.btnBags:SetPoint("RIGHT", footer, "RIGHT", rightEdge, 0)
		self.freeText = self.btnBags.label   -- the count lives inside the button
	else
		self.freeText = fontString(footer, "GameFontHighlightSmall", "RIGHT")
		self.freeText:SetPoint("RIGHT", rightEdge, 0)
	end
	self.statusText = fontString(footer, "GameFontHighlightSmall", "CENTER")
	self.statusText:SetPoint("CENTER")
	self.favChips = {}

	-- Scroll region
	local scroll = CreateFrame("ScrollFrame", self.name .. "Scroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
	if self.big then
		scroll:SetPoint("BOTTOMRIGHT", self.tabs or footer, "TOPRIGHT", -BAR_ROOM, 4)
	else
		-- Small windows have no column header: the grid starts under the title,
		-- 8 px clear of the header band (the band ends 4 px below the title),
		-- the same room the grid has at its sides.
		footer:Hide()
		header:Hide()
		scroll:ClearAllPoints()
		scroll:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
		scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD - BAR_ROOM, PAD)
	end
	-- A size change (resizing, the window opening) re-checks whether the scrollbar is needed.
	scroll:HookScript("OnSizeChanged", function() self:UpdateBarSpace() end)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	self:SetupScroll(scroll, child)
	-- Slim scrollbar: no arrow buttons, just a track and thumb. The mouse
	-- wheel keeps working through the template.
	local sb = scroll.ScrollBar
	if sb then
		sb:ClearAllPoints()
		sb:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, -2)
		sb:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 2)
		for _, key in ipairs({ "Back", "Forward", "ScrollUpButton", "ScrollDownButton" }) do
			local btn = sb[key] or _G[(sb:GetName() or "") .. key]
			if btn then btn:SetAlpha(0); btn:EnableMouse(false) end
		end
		if sb.Track and sb.Track.Thumb then
			sb.Track.Thumb:SetAlpha(0.6)
		end
	end

	-- Resize grip (bottom-right)
	local grip = CreateFrame("Button", nil, f)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -4, 4)
	grip.tex = grip:CreateTexture(nil, "ARTWORK")
	grip.tex:SetAllPoints()
	grip.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetScript("OnMouseDown", function() self.sizing = true; f:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function()
		f:StopMovingOrSizing()
		self.sizing = false
		-- Dragging never changes the size mode: in Fit to Items it sets the
		-- largest size; in Scalable it sets the size. Values are rounded.
		local w, h = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
		if self.isBank then
			ns:Set("bankW", w, true); ns:Set("bankH", h, true)
		elseif ns.db.sizeMode == "auto" then
			ns:Set("maxW", w, true); ns:Set("maxH", h, true)
		else
			ns:Set("fixW", w, true); ns:Set("fixH", h, true)
		end
		-- Keep the window exactly where the resize left it (the saved spot
		-- was from before, so re-applying it made the window jump).
		self:SaveSizedPosition()
		self.refreshWanted = nil
		self:ApplySize(); self:Refresh(true)
		-- Once more on the next frame: the client can settle the new size a
		-- frame after the drag ends, and the layout should use the final one.
		ns:NextFrame("settle:" .. self.name, function() if f:IsShown() and not self.sizing then self:Refresh(true) end end)
	end)
	self.grip = grip
	f:HookScript("OnHide", function() self.sizing = false; self.refreshWanted = nil end)   -- a drag cut short never leaves it waiting

	if self.kind == "main" then
		f:SetScript("OnSizeChanged", function() ns:NextFrame("panels", function() ns:RepositionPanels() end) end)
	end
	table.insert(UISpecialFrames, self.name)
	f:SetScript("OnShow", function()
		if ns.ready then PlaySound(SOUNDKIT.IG_BACKPACK_OPEN) end
		if InCombatLockdown() then ns:ApplyCombatFade(true) end
		-- The main window brings its companions (bag windows)
		-- back with it; the others just refresh themselves.
		if self.kind == "main" then ns:RefreshViews(true) else self:Refresh(true) end
		-- (1.5.1-beta2) and its list canvas laid out again once the client has drawn a frame: after a reload the window
		-- is built while closed, and the client could keep a stale picture of the canvas and draw nothing (Shweep: a
		-- blank window, in both styles, until List and Icons were swapped). See View:RefreshCanvas.
		ns:NextFrame("canvas:show:" .. self.name, function() self:RefreshCanvas("show") end)
	end)
	f:SetScript("OnHide", function()
		if ns.ready then PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE) end
		if self.isBank and ns.Bank then ns.Bank:OnWindowHidden() end
		if self.isMain then ns:OnMainHidden() end
	end)

	Skins:Register(f, function() self:ApplySkin() end)
	self:ApplySize()
end

------------------------------------------------------------------------
-- Skin, size, position
------------------------------------------------------------------------
-- Places the toolbar items left to right. If the full form does not fit the window, it narrows in two steps
-- (1.4.1): first the group labels ("Sections", "View") are hidden; only if it still doesn't fit does "Merge Stacks"
-- become "Merge".
function View:ToolsTotal(level)
	local w = 0
	for _, it in ipairs(self.toolItems or {}) do
		if not (level >= 1 and it.isLabel) then
			w = w + ((level >= 2 and it.compactWidth) or it.width) + it.gap + (it.offset or 0)
		end
	end
	return w
end
function View:LayoutTools()
	if not self.toolItems then return end
	local avail = self.tools:GetWidth()
	local level = 0
	if self:ToolsTotal(0) > avail then level = (self:ToolsTotal(1) > avail) and 2 or 1 end
	self.toolsLevel = level
	self.toolsCompact = level >= 1
	local compact = level >= 1
	local x = 0
	for _, it in ipairs(self.toolItems) do
		local f = it.frame
		if compact and it.isLabel then
			f:Hide()
		else
			f:Show()
			local short = level >= 2 and it.compactWidth ~= nil
			local w = short and it.compactWidth or it.width
			if it.compactText then
				f.label:SetText(short and it.compactText or it.fullText); f:SetWidth(w)
			end
			x = x + (it.offset or 0)
			f:ClearAllPoints(); f:SetPoint("LEFT", self.tools, "LEFT", x, 0)
			x = x + w + it.gap
		end
	end
	self.toolsWidth = x
	-- The search row ends where the toolbar ends: Filter's right edge lines up
	-- with the last button (Icons), whatever the window's width or skin. If
	-- the toolbar ever reaches the window's edge, Filter stays at the edge.
	local last
	for _, it in ipairs(self.toolItems) do if not (compact and it.isLabel) then last = it end end
	local toolsEnd = x - (last and last.gap or 0)
	local cap = (avail and avail > 50) and avail or math.huge   -- before the first layout pass, width can read 0
	if toolsEnd > cap then toolsEnd = cap end
	self.toolsEnd = toolsEnd
	self:PlaceSearch()
end

-- The search box: its own row under the title (ending with the toolbar), or
-- in Travel Mode, in the title row between the character picker and the icons.
-- shift: how far left of the title's left edge the rows below it start (0 in Modern; Classic moves the title
-- beside the portrait and passes the difference back). Re-places what hangs from the title.
function View:PlaceBelow(shift)
	shift = shift or 0
	if self.belowShift == shift then return end
	self.belowShift = shift
	if self.PlaceSearch then self:PlaceSearch() end
	if self.header then self:PlaceHeader() end
	if self.scroll then self:PlaceScroll() end
end
function View:PlaceSearch()
	if not (self.search and self.btnFilter and self.title) then return end
	self.search:ClearAllPoints()
	if self:TravelOn() then
		-- The character picker is hidden in Travel Mode: search starts after the title.
		self.search:SetPoint("LEFT", self.subText, "RIGHT", 12, 0)
		self.search:SetPoint("RIGHT", self.btnClean, "LEFT", -8, 0)
		self.search:SetHeight(22)
	else
		local shift = self.belowShift or 0
		self.search:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 4 + shift, -2)
		self.search:SetPoint("TOPRIGHT", self.title, "BOTTOMLEFT", (self.toolsEnd or 400) - self.btnFilter:GetWidth() - 6 + shift, -2)
		self.search:SetHeight(TOOL_H)
	end
end

------------------------------------------------------------------------
-- Travel Mode (bags window only): the Filter button and the toolbar row
-- are hidden, search moves into the title row, the title says so, and the
-- items fill the space. The sheet tabs and footer stay. Turned off,
-- everything is back exactly. Auto Travel Mode can switch it off while the
-- bank, the auction house or a vendor is open, and back on after.
------------------------------------------------------------------------
function View:TravelOn()
	return self.isMain and ns.db and ns.db.travelMode and not ns:TravelHeld() and true or false
end
function View:ApplyTravel()
	if not (self.isMain and self.tools and self.header) then return end
	-- Moving the items area moves protected item buttons: never in combat.
	ns:Safely("travel" .. self.name, function()
		local on = self:TravelOn()
		-- Travel Mode always shows your own bags (there's no picker to leave
		-- another character's), and closes the picker's list and the Filter
		-- panel so a stale list can't switch characters behind it.
		if on and ns.ui.owner then self:SetOwner(nil) end
		if on and ns.Popups then ns.Popups:HideAll() end
		self.tools:SetShown(not on)
		self.btnFilter:SetShown(not on)
		if self.charBtn then self.charBtn:SetShown(not on) end
		if self.charReset then self.charReset:SetShown(not on and ns.ui.owner ~= nil) end
		if ns.Classic and ns.Classic.SyncDropdown then ns.Classic.SyncDropdown(self) end
		if self.btnBagBar then self.btnBagBar:SetShown(self.st.sheet ~= "Bank" and not ns.ui.owner) end   -- stays in Travel Mode
		self:PlaceSearch()
		local above = on and self.title or self.tools
		self:PlaceHeader(on)
		local band = self.title.band
		if band then
			band:ClearAllPoints()
			band:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 4, -4)
			band:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -4, -4)
			band:SetPoint("BOTTOM", above, "BOTTOM", 0, -6)
		end
		if self.btnTravel then self.btnTravel:SetActive(on) end
		self.travelShown = on
		self:UpdateTitle()
	end)
end

-- The drag band across the top of the bags and bank windows ends exactly
-- where the search row begins, in either skin, so it never sits over the
-- search box or Filter (Classic's bank collapses its title row, which put
-- the search row under a fixed-height band). Small windows keep a fixed band.
function View:FitDragBand()
	local drag = self.dragArea
	if not drag then return end
	local h = PAD + TITLE_H + 6
	if self.big and self.title then
		local p = { self.title:GetPoint(1) }
		local point, rel, y = p[1], p[2], p[5]
		if type(p[2]) == "number" then rel, y = self.frame, p[3] end   -- ("TOPLEFT", x, y): relative to the parent
		if point == "TOPLEFT" and (rel == self.frame or rel == nil) and type(y) == "number" then
			h = -y + (self.title:GetHeight() or TITLE_H) + 2
		end
	end
	drag:SetHeight(h)
end

function View:ApplySkin()
	local s = Skins:Current()
	Skins:ApplyBackdrop(self.frame)
	self.mark:SetVertexColor(unpack(s.heading))
	if self.titleDivider then self.titleDivider:SetColorTexture(unpack(s.line)) end
	self.titleText:SetTextColor(unpack(s.heading))
	self.subText:SetTextColor(unpack(s.muted))
	self.header.line:SetColorTexture(unpack(s.line))
	self.footer.line:SetColorTexture(unpack(s.line))
	self.moneyText:SetTextColor(unpack(s.text))
	self.statusText:SetTextColor(Skins:Accent())
	for _, b in pairs(self.headerLabels) do b.text:SetTextColor(unpack(s.muted)) end
	if self.charBtn then self.charBtn:SetActive(ns.ui.owner ~= nil) end
	-- Classic code never touches a Modern window unless Classic has been on
	-- for it this session (then it restores what it recorded).
	if ns.Classic then
		if self.big then
			local on = ns.db.skin == "classic"
			if on or self.classicEverApplied then ns.Classic:Apply(self, on) end
	self:FitDragBand()
	if self.isMain then self:ApplyTravel() end
		else
			ns.Classic:DressSmall(self, ns.db.skin == "classic")   -- does nothing in Modern unless dressed before
		end
	end
end


function View:ApplySize()
	-- Never while the corner is being dragged: re-applying the saved size and
	-- spot mid-drag made the window jump back (the drag's end saves both).
	if self.sizing then return end
	local f, db = self.frame, ns.db
	f:SetScale(db.scale)
	if self.isMain then
		if db.sizeMode == "fixed" then f:SetSize(db.fixW, db.fixH) else f:SetSize(db.maxW, math.min(db.maxH, self.autoHeight or db.maxH)) end
		f:ClearAllPoints()
		local p = db.point
		f:SetPoint(p[1], UIParent, p[3], p[4], p[5])
	elseif self.isBank then
		f:SetSize(db.bankW, db.bankH)
		f:ClearAllPoints()
		local p = db.bankPoint
		f:SetPoint(p[1], UIParent, p[3], p[4], p[5])
	else
		-- Small windows: width from icons-per-row, height capped (then they
		-- scroll). They follow the main Scale, with Bag Window Scale on top.
		local w = PAD * 2 + 22 + db.bagCols * (db.iconSize + GAP) - GAP
		f:SetScale(db.scale * db.bagScale)
		local h = math.min(db.bagMaxH, self.autoHeight or 120)
		-- Classic: never shorter than Blizzard's frame art needs (see Classic.BagMinHeight).
		local minH = ns.Classic and ns.Classic.BagMinHeight and ns.Classic.BagMinHeight(self)
		if minH and h < minH then h = minH end
		f:SetSize(w, h)
		if not self.positioned then
			f:ClearAllPoints()
			local saved = self.kind == "bag" and db.bagPoints[tostring(self.opts.bags[1])]
			if saved then
				f:SetPoint(saved[1], UIParent, saved[3], saved[4], saved[5])
			else
				local anchor = self.opts.anchor and self.opts.anchor()
				if anchor then f:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", -6, 0) else f:SetPoint("CENTER") end
			end
			self.positioned = true
		end
	end
	self.grip:SetShown(self.big)
end

function View:SavePosition()
	local point, _, rel, x, y = self.frame:GetPoint(1)
	if not point then return end
	local p = { point, "UIParent", rel, math.floor(x + 0.5), math.floor(y + 0.5) }
	if self.isMain then ns:Set("point", p, true)
	elseif self.isBank then ns:Set("bankPoint", p, true)
	elseif self.kind == "bag" then ns.db.bagPoints[tostring(self.opts.bags[1])] = p end
end


------------------------------------------------------------------------
-- Chrome: title, tools, tabs, footer
------------------------------------------------------------------------
function View:UpdateTitle()
	local title = self.opts.title
	if self.isMain then
		title = self.st.sheet == "Bank" and "Bank (Saved)" or "Your Bags"
		if self:TravelOn() then title = title .. " (Travel Mode)" end
	end
	if self.isBank then title = "Bank" end
	self.titleText:SetText(title)
	if self.classicApplied and self.classicTitle then self.classicTitle:SetText(title); self.titleText:SetText("") end
	if self.isMain then self:PlaceSearch() end
end

function View:UpdateChrome(shown, total, bagInfo, cached)
	local s = Skins:Current()
	self:UpdateTitle()
	local title = self.opts.title
	if not self.big and ns.Classic then ns.Classic:Retitle(self.frame, title, ns.Classic.BagIcon(self)) end
	local sub = ""
	if ns.ui.owner then
		local data = BagSmithDB.cache[ns.ui.owner]
		sub = (data and data.name or "?") .. ", read only"
		if self.st.sheet == "Bank" then sub = sub .. ", saved bank" end
	elseif self.st.sheet == "Bank" and self.isMain then
		sub = "saved view"
	elseif self.isBank then
		sub = ns.atBank and "" or "saved view"
	end
	if #shown ~= total then sub = (sub ~= "" and sub .. ", " or "") .. ("%d of %d shown"):format(#shown, total) end
	self.subText:SetText(sub)
	if self.charBtn then
		local data = ns.ui.owner and BagSmithDB.cache[ns.ui.owner] or BagSmithDB.cache[ns:CharKey()]
		local name, class, level = data and data.name or ns:DisplayName("player"), data and data.class, data and data.level or UnitLevel("player")
		if not class then local _, c = UnitClass("player"); class = c end
		self.charBtn.label:SetText(("%s  |cff8f8c83%d|r"):format(name or "?", level or 0))
		self.charBtn.label:SetTextColor(ns.ClassColor(class))
		if CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class] then
			self.charIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
			self.charIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]))
		end
		self.charBtn:SetActive(ns.ui.owner ~= nil)
		self.charReset:SetShown(ns.ui.owner ~= nil and not self:TravelOn())
		self.btnBank:SetActive(self.st.sheet == "Bank")
		if self.btnGearSets then
			local gs = ns.GearSets and ns.GearSets:Available() and true or false
			self.btnGearSets:SetShown(gs)
			self.btnGearSets:SetActive(self.st.sheet == "GearSets")
			self:RefreshToolbar()
		end
		self.btnFilter:SetActive(ns.FilterCount(self.st.filters) > 0)
		self.btnFilter.label:SetText(ns.FilterCount(self.st.filters) > 0 and ("Filter (%d)"):format(ns.FilterCount(self.st.filters)) or "Filter")
	end
end

-- The Disenchant Helper's toolbar button: shown while the helper is on, lit while its window is open (1.2.0).
function View:RefreshToolbar()
	if not (self.btnDisenchant and self.btnBank) then return end
	local gs = ns.GearSets and ns.GearSets:Available() and true or false
	local de = self.kind == "main" and ns.db and ns.db.deEnabled == true
	self.btnDisenchant:SetShown(de)
	self.btnDisenchant:SetActive(de and ns.Disenchant and ns.Disenchant.frame and ns.Disenchant.frame:IsShown() or false)
	local beside = gs and self.btnGearSets or self.btnBank
	if self.deBeside ~= beside then self.btnDisenchant:ClearAllPoints(); self.btnDisenchant:SetPoint("RIGHT", beside, "LEFT", 0, 0); self.deBeside = beside end
	local cleanAnchor = de and self.btnDisenchant or (gs and self.btnGearSets or self.btnBank)
	if self.cleanBeside ~= cleanAnchor then self.btnClean:ClearAllPoints(); self.btnClean:SetPoint("RIGHT", cleanAnchor, "LEFT", 0, 0); self.cleanBeside = cleanAnchor end
end
function View:SyncTools()
	if not self.tools then return end
	self.syncGrp(); self.syncView()
	local sb, sr = ns.SessionWindows()
	if self.btnBags then self.btnBags:SetActive(self.isBank and (ns.ui.bankBagWindows or false) or sb) end
	-- Browsing another character: bag windows show your own bags, so the
	-- bags and reagent buttons are greyed out and explain why.
	local browsing = ns.ui.owner and not self.isBank
	for _, b in ipairs({ self.btnBags, self.btnReagent }) do
		if b and b.isCount then
			b.baseTip = b.baseTip or b.tip
			if browsing then
				b:Disable(); b:SetAlpha(0.45)
				b.tip = "Bag windows show your own bags. Switch back to your character to open them."
			else
				b:Enable(); b:SetAlpha(1)
				b.tip = b.baseTip
			end
		end
	end
	if self.btnMerge then self.btnMerge:SetActive(self:Pref("mergeStacks")); self.btnMerge.label:SetText((self.toolsLevel or 0) >= 2 and "Merge" or "Merge Stacks") end
	if self.btnReagent then self.btnReagent:SetActive(sr and true or false) end
	local SORT_NAME = { quality = "Quality", name = "Name", ilvl = "iLvl", newest = "Newest", oldest = "Oldest", off = "Off" }
	self.btnSort.label:SetText(self.st.colSort and ("Sort: " .. (ns.COL_LABEL[self.st.colSort.key] or "Item")) or ("Sort: " .. (SORT_NAME[self:Pref("sort")] or self:Pref("sort"))))
	self.btnSort:SetActive(self.st.colSort ~= nil)
	local ids, collapsedSet = self.laneIds or {}, {}
	for _, id in ipairs(self:CollapsedList()) do collapsedSet[id] = true end
	local all = #ids > 0
	for _, id in ipairs(ids) do if not collapsedSet[id] then all = false end end
	self.btnLanes.tex:SetTexture("Interface\\AddOns\\BagSmith\\Media\\" .. (all and "ui-expand.tga" or "ui-collapse.tga"))
	self.btnLanes.tip = all and "Expand All Sections" or "Collapse All Sections"
	self.btnLanes:SetShown(#ids > 0)
end

function View:UpdateTabs()
	-- Row height: Blizzard's tabs are taller in Classic. Everything is still
	-- created at its Modern size; only this pass's layout uses rowH.
	local rowH = self.classicApplied and 30 or TAB_H
	local db, x = ns.db, 0
	local hidden = {}
	for _, t in ipairs(self.isBank and db.bankHiddenTabs or db.hiddenTabs) do hidden[t] = true end
	-- No equipment sets on this client: no Gear Sets tab.
	if not (ns.GearSets and ns.GearSets:Available()) then hidden.GearSets = true end
	local i, row = 0, 0
	local order = self.isBank and db.bankTabOrder or db.tabOrder
	for _, id in ipairs(order) do
		if not hidden[id] then
			i = i + 1
			local b = self.tabButtons[i]
			if not b then
				b = textButton(self.tabs, "", 60, function(btn) self:SetSheet(btn.sheet) end)
				b:SetHeight(TAB_H - 2)
				if self.classicApplied then b:SetClassic(true, ns.Classic.TabTemplate()) end
				b:RegisterForDrag("LeftButton")
				b:SetScript("OnDragStart", function(btn) ns.dragTab = btn.sheet; btn:SetAlpha(0.5) end)
				b:SetScript("OnDragStop", function(btn)
					btn:SetAlpha(1)
					local target = ns.FrameUnderCursor("sheet")
					if ns.dragTab and target and target ~= ns.dragTab then ns:ReorderTab(ns.dragTab, target, self) end
					ns.dragTab = nil
				end)
				self.tabButtons[i] = b
			end
			b:SetHeight(rowH - 2)
			if b.classicOn and ns.Classic and ns.Classic.FitTabArt then ns.Classic.FitTabArt(b) end   -- (1.5.0-beta6)
			local label = ns.TAB_LABEL[id] or id
			b.sheet = id
			b.label:SetText(label)
			b.label:ClearAllPoints(); b.label:SetPoint("CENTER"); b.label:SetWordWrap(false)
			local w = math.min(160, math.max(40, b.label:GetStringWidth() + 16))
			b.label:SetWidth(w - 12)
			b:SetWidth(w)
			if x + w > self.tabs:GetWidth() and x > 0 then x = 0; row = row + 1 end
			b:ClearAllPoints(); b:SetPoint("TOPLEFT", self.tabs, "TOPLEFT", x, -row * rowH)
			b:SetActive(self.st.sheet == id)
			b:Show()
			x = x + w + 2
		end
	end
	for j = i + 1, #self.tabButtons do self.tabButtons[j]:Hide() end
	local rows = row + 1
	if self.tabs:GetHeight() ~= rows * rowH then self.tabs:SetHeight(rows * rowH) end

	-- Plus: new sheet from the Filter panel. Pencil: edit the selected custom
	-- sheet. Modern uses small icon buttons (sized on every pass, so a size
	-- from Classic can never stick); Classic uses tab-style ones.
	if not self.tabAdd then
		self.tabAdd = iconButton(self.tabs, "Interface\\AddOns\\BagSmith\\Media\\ui-plus.tga", "New sheet: save a search and filters as a tab", function() ns.Popups:OpenFilters(self, "new") end)
		self.tabAdd.tex:SetSize(12, 12)
		self.tabEdit = iconButton(self.tabs, "Interface\\AddOns\\BagSmith\\Media\\ui-pencil.tga", "Edit this sheet: rename, change its filters, or delete it", function() ns.Popups:OpenFilters(self, "edit", self.st.sheet) end)
		self.tabEdit.tex:SetSize(13, 13)
	end
	local addBtn, editBtn = self.tabAdd, self.tabEdit
	if self.classicApplied then
		if not self.tabAddTab then
			self.tabAddTab = textButton(self.tabs, "+", 34, function() ns.Popups:OpenFilters(self, "new") end)
			self.tabAddTab.tip = self.tabAdd.tip
			self.tabAddTab:SetClassic(true, ns.Classic.TabTemplate())
			self.tabEditTab = textButton(self.tabs, "", 34, function() ns.Popups:OpenFilters(self, "edit", self.st.sheet) end)
			self.tabEditTab.tip = self.tabEdit.tip
			self.tabEditTab:SetClassic(true, ns.Classic.TabTemplate())
			local holder = self.tabEditTab.classic or self.tabEditTab
			local pen = holder:CreateTexture(nil, "OVERLAY")
			pen:SetTexture("Interface\\AddOns\\BagSmith\\Media\\ui-pencil.tga"); pen:SetSize(13, 13); pen:SetPoint("CENTER", 0, -1)
			pen:SetVertexColor(1, 0.82, 0)
		end
		self.tabAdd:Hide(); self.tabEdit:Hide()
		addBtn, editBtn = self.tabAddTab, self.tabEditTab
		addBtn:SetHeight(rowH - 2); editBtn:SetHeight(rowH - 2)
	else
		if self.tabAddTab then self.tabAddTab:Hide(); self.tabEditTab:Hide() end
		self.tabAdd:SetSize(TAB_H - 2, TAB_H - 2); self.tabEdit:SetSize(TAB_H - 2, TAB_H - 2)
	end
	local aw, ew = addBtn:GetWidth(), editBtn:GetWidth()
	local isCustom = not ns.TAB_LABEL[self.st.sheet]
	local extras = (aw + 2) + (isCustom and (ew + 2) or 0)
	if x + extras > self.tabs:GetWidth() then x = 0; row = row + 1; self.tabs:SetHeight((row + 1) * rowH) end
	addBtn:ClearAllPoints(); addBtn:SetPoint("TOPLEFT", self.tabs, "TOPLEFT", x + 2, -row * rowH); addBtn:Show()
	x = x + aw + 4
	editBtn:SetShown(isCustom)
	if isCustom then editBtn:ClearAllPoints(); editBtn:SetPoint("TOPLEFT", self.tabs, "TOPLEFT", x, -row * rowH) end
end

function View:UpdateFooter(bagInfo)
	-- Footer-only updates (money, currency) pass no bag details: reuse the last
	-- full refresh's, so saved free-slot counts don't drop to 0/0.
	if bagInfo then self.footerBagInfo = bagInfo else bagInfo = self.footerBagInfo end
	local s = Skins:Current()
	local owner = ns.ui.owner
	local gold = owner and (BagSmithDB.cache[owner] and BagSmithDB.cache[owner].gold or 0) or GetMoney()
	self.moneyText:SetText(GetMoneyString(gold or 0, true))

	-- Free slots
	local free, total, rfree, rtotal
	if owner then
		free, total, rfree, rtotal = 0, 0, 0, 0
		for bag, info in pairs(bagInfo or {}) do
			if info.reagent then rfree, rtotal = rfree + (info.free or 0), rtotal + (info.size or 0)
			elseif bag ~= ns.KEYRING then free, total = free + (info.free or 0), total + (info.size or 0) end
		end
	elseif (self.isMain and self.st.sheet == "Bank") or (self.isBank and not ns.atBank) then
		free, total, rfree, rtotal = 0, 0, 0, 0
		for _, info in pairs(bagInfo or {}) do free, total = free + (info.free or 0), total + (info.size or 0) end
	else
		free, total, rfree, rtotal = ns:FreeSlots(self.kind == "main" and self.st.sheet ~= "Bank" and ns.BAGS or self:Bags())
	end
	if (self.isMain and self.st.sheet == "Bank") or self.isBank then rtotal = 0 end
	-- A window showing only the reagent bag reports the reagent slots.
	if total == 0 and rtotal > 0 then free, total = rfree, rtotal end
	local txt = ("%d / %d"):format(free, total)
	if free <= 0 then txt = "|cfff09595" .. txt .. "|r" elseif free <= 4 then txt = "|cfffac775" .. txt .. "|r" end
	if self.titleCount then
		self.titleCount:SetText(txt)
		self.titleCount:SetTextColor(Skins:Color("muted"))
		return
	end
	self.freeText:SetText(txt)
	if self.reagentText then
		local showR = rtotal > 0 and self.st.sheet ~= "Bank" and not owner
		local r = ("%d / %d"):format(rfree, rtotal)
		if rfree <= 0 then r = "|cfff09595" .. r .. "|r" elseif rfree <= 1 then r = "|cfffac775" .. r .. "|r" end
		self.reagentText:SetText(r)
		self.btnReagent:SetShown(showR)
		self.btnReagent:Fit()
	end
	if self.btnBags then self.btnBags:Fit() end
	-- The bag strip's button sits just left of the counts (not in Travel Mode,
	-- on the Bank sheet, or while browsing another character).
	if self.btnBagBar then
		local b = self.btnBagBar
		b:ClearAllPoints()
		local left = (self.btnReagent and self.btnReagent:IsShown()) and self.btnReagent or self.btnBags
		b:SetPoint("RIGHT", left, "LEFT", -6, 0)
		b:SetShown(self.st.sheet ~= "Bank" and not owner)
		b:SetActive(ns.db.bagBar and true or false)
		self:ColorBagBarButton()
	end
	-- Favorite currencies, as many as fit between money and free text.
	if not self.isMain then return end
	local favs = ns.Currency:Favorites(owner)
	-- Favorites may run up to 12 px short of the count buttons on the right
	-- (the resize grip's room, the bags button, the reagent button).
	local right = (self.big and 18 or 2) + (self.btnBags and self.btnBags:GetWidth() or self.freeText:GetStringWidth())
		+ ((self.btnReagent and self.btnReagent:IsShown()) and (self.btnReagent:GetWidth() + 6) or 0)
		+ ((self.btnBagBar and self.btnBagBar:IsShown()) and (self.btnBagBar:GetWidth() + 6) or 0)
	local avail = self.footer:GetWidth() - right - 12
	-- Favorites start a clear step after the gold, then each icon+count pair keeps 12px from the next.
	local x = MONEY_X + self.moneyText:GetStringWidth() + 20
	local full = false   -- once one doesn't fit, the rest go into "+N" too, so favorites stay in order
	local shownCount = 0
	for i, e in ipairs(favs) do
		local chip = self.favChips[i]
		if not chip then
			chip = CreateFrame("Button", nil, self.footer)
			chip:SetHeight(18)
			chip.icon = chip:CreateTexture(nil, "ARTWORK"); chip.icon:SetSize(14, 14); chip.icon:SetPoint("LEFT")
			chip.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			chip.text = fontString(chip, "GameFontHighlightSmall"); chip.text:SetPoint("LEFT", chip.icon, "RIGHT", 4, 0)
			chip:SetScript("OnClick", function() ns.Drawer:Toggle() end)
			chip:SetScript("OnEnter", function(c) if ns.TooltipsOK() then GameTooltip:SetOwner(c, "ANCHOR_TOP"); GameTooltip:SetText(c.name); GameTooltip:Show() end end)
			chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
			hoverWash(chip, 0)
			self.favChips[i] = chip
		end
		chip.icon:SetTexture(e.icon)
		chip.text:SetText(BreakUpLargeNumbers and BreakUpLargeNumbers(e.count) or e.count)
		chip.name, chip.key = e.name, e.key
		local w = 18 + chip.text:GetStringWidth()
		if full or x + w > avail then chip:Hide(); full = true else
			chip:SetWidth(w); chip:ClearAllPoints(); chip:SetPoint("LEFT", self.footer, "LEFT", x, 0); chip:Show()
			x = x + w + 12; shownCount = shownCount + 1
		end
	end
	for j = #favs + 1, #self.favChips do self.favChips[j]:Hide() end
	if #favs > shownCount then
		-- The "+N" chip needs room too; drop the last visible currency if it does not fit.
		if not self.favMore then
			self.favMore = textButton(self.footer, "", 34, function() ns.Drawer:Toggle() end)
			self.favMore:SetHeight(18)
			self.favMore.tip = "More pinned currencies: open the currency drawer"
		end
		while shownCount > 0 and x + 34 > avail do
			local last = self.favChips[shownCount]
			x = x - (last:GetWidth() + 12)
			last:Hide()
			shownCount = shownCount - 1
		end
		self.favMore.label:SetText("+" .. (#favs - shownCount))
		if x + 34 <= avail or shownCount == 0 then
			self.favMore:ClearAllPoints(); self.favMore:SetPoint("LEFT", self.footer, "LEFT", x, 0); self.favMore:Show()
		else self.favMore:Hide() end
	elseif self.favMore then self.favMore:Hide() end
	self.favShown = shownCount
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------
function View:SetSheet(id)
	local wasCustom = not ns.TAB_LABEL[self.st.sheet]
	self.st.sheet = id
	local custom
	for _, s in ipairs(self.isBank and ns.db.bankSheets or ns.db.sheets) do if s.n == id then custom = s end end
	if custom then
		self.st.filters = ns.CleanFilters(custom.f)
		if self.search then self.search:SetText(self.st.filters.text) end
	elseif wasCustom then
		self.st.filters = ns.EmptyFilters()
		if self.search then self.search:SetText("") end
	end
	ns:RefreshViews(true)
end

function View:SetOwner(key)
	-- Picking yourself always means your live, usable bags.
	if key and ns:IsOwnKey(key) then key = nil end
	-- Travel Mode shows only your own bags: another character can't be picked.
	if key and self.TravelOn and self:TravelOn() then return end
	ns.ui.owner = key
	if key and not BagSmithDB.cache[key] then ns.ui.owner = nil end
	ns:RefreshViews(true)
	if ns.ui.owner then ns:Print("Viewing %s, read only.", BagSmithDB.cache[ns.ui.owner].name) end
	if ns.ui.owner then ns:DebugOwner(ns.ui.owner) end
end
-- (1.5.0-beta3) /bs debug: which saved character is shown, its saved gold and when it was saved, and whether the
-- same character is saved more than once (an older copy could be the one picked).
function ns:DebugOwner(key)
	if not (ns.db and ns.db.debug and ns.Debug) then return end
	local e = BagSmithDB.cache[key] or {}
	local others = {}
	for k, v in pairs(BagSmithDB.cache) do
		if k ~= key and type(v) == "table" and v.name == e.name and (v.realm == e.realm or v.realm == nil or e.realm == nil) then
			others[#others + 1] = ("%q (gold %s)"):format(k, tostring(v.gold))
		end
	end
	local age = e.updated and (time() - e.updated)
	local when = not age and "never" or age < 120 and ("%d seconds ago"):format(age) or age < 7200 and ("%d minutes ago"):format(math.floor(age / 60)) or ("%d hours ago"):format(math.floor(age / 3600))
	ns:Debug("Viewing %q: saved gold %s, saved %s, %d currencies saved.%s", key, tostring(e.gold), when,
		(function() local n = 0; for _ in pairs(e.currencies or {}) do n = n + 1 end return n end)(),
		#others > 0 and (" Also saved as " .. table.concat(others, ", ") .. ".") or "")
end

-- Collapsed lanes live in the profile when "remember" is on, otherwise only for this session.
ns.ui.collapsed = {}
ns.uiBank.collapsed = {}
-- Each window keeps its own collapsed sections (the bank used to share the
-- bags window's list, so collapsing in one collapsed matching sections in both).
function ns.CollapsedList(view)
	if view and view.isBank then return ns.db.remember and ns.db.bankCollapsed or ns.uiBank.collapsed end
	return ns.db.remember and ns.db.collapsed or ns.ui.collapsed
end
function View:CollapsedList()
	local p = self:SheetPrefs(true)
	if p then p.collapsed = p.collapsed or {}; return p.collapsed end
	return ns.CollapsedList(self)
end

function View:ToggleLane(id)
	local list = self:CollapsedList()
	local i = ns.IndexOf(list, id)
	if i then table.remove(list, i) else table.insert(list, id) end
	ns:RefreshViews(true)
end

function View:ToggleAllLanes()
	local list = self:CollapsedList()
	local ids, set = self.laneIds or {}, {}
	for _, id in ipairs(list) do set[id] = true end
	local all = #ids > 0
	for _, id in ipairs(ids) do if not set[id] then all = false end end
	if all then
		for _, id in ipairs(ids) do local i = ns.IndexOf(list, id); if i then table.remove(list, i) end end
	else
		for _, id in ipairs(ids) do if not set[id] then table.insert(list, id) end end
	end
	ns:RefreshViews(true)
end

-- A Clean Up rearranges the bags on purpose, for some seconds: the windows don't hold their layout under the pointer
-- meanwhile, and lay out once more when it's done (1.4.1).
ns.CLEANUP_SECONDS = 6
function ns:NoteCleanup()
	ns.cleanupUntil = GetTime() + ns.CLEANUP_SECONDS
	for _, v in pairs(ns.views or {}) do v.held = false; if v.FreshLayout then v:FreshLayout() end end
	ns.cleanupToken = (ns.cleanupToken or 0) + 1
	local token = ns.cleanupToken
	C_Timer.After(ns.CLEANUP_SECONDS, function()
		if token ~= ns.cleanupToken then return end   -- a newer Clean Up owns the window
		ns.cleanupUntil = nil
		ns:RefreshViews(true)
	end)
end
function View:CleanUp()
	if ns.ui.owner then ns:Print("You can only clean up your own bags."); return end
	if InCombatLockdown() or UnitIsDead("player") then ns:Print("Can't clean up right now."); return end
	ns:NoteCleanup()
	-- The bank window (whatever sheet it shows) or the Bags window's Bank sheet.
	if (self.isBank or self.st.sheet == "Bank") and ns.atBank then
		if C_Container.SortBankBags then C_Container.SortBankBags() end
	elseif C_Container.SortBags then
		PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
		C_Container.SortBags()
	end
end

function View:Show() if not self.frame:IsShown() then self.frame:Show() end end
function View:Hide() if self.frame:IsShown() then self.frame:Hide() end end
function View:Toggle() if self.frame:IsShown() then self:Hide() else self:Show() end end
function View:IsShown() return self.frame:IsShown() end

-- The list's place in its window. The scrollbar's lane on the right is
-- given back to the list when nothing scrolls, so the margins match.
function View:PlaceScroll(classic)
	local sc = self.scroll
	if not sc then return end
	if classic == nil then
		if self.big then classic = self.classicApplied
		else classic = self.frame.classicState and self.frame.classicState.on end
	end
	local room = self.barHidden and 0 or -BAR_ROOM   -- the right inset
	sc:ClearAllPoints()
	if self.big then
		sc:SetPoint("TOPLEFT", self.header, "BOTTOMLEFT", 0, -2)
		if classic and self.tabs then sc:SetPoint("BOTTOMRIGHT", self.footer, "TOPRIGHT", room, 6)
		else sc:SetPoint("BOTTOMRIGHT", self.tabs or self.footer, "TOPRIGHT", room, 4) end
	else
		sc:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", self.belowShift or 0, classic and -4 or -12)
		sc:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -PAD + room, PAD)
	end
end

-- Show the scrollbar only when the list overflows; without it the list
-- takes the lane back. A change is laid out again once (the width changes
-- how many icons fit a row). It can't flip back and forth: hiding happens
-- only when the list fits at the narrower width (so it fits wider too), and
-- showing only when it overflows at the wider width (so it overflows
-- narrower too). In combat it waits, since moving item buttons is restricted.
function View:UpdateBarSpace(height, visible)
	local bar = self.scroll and self.scroll.ScrollBar
	-- Not during a corner drag: the size changes constantly then, and the
	-- full refresh when the drag ends decides once, at the final size.
	if not bar or self.inBarUpdate or self.sizing then return end
	height = height or self.contentHeight
	if not height then return end
	if not visible then
		local chrome = self.lastChrome or 0
		visible = self.scroll:GetHeight()
		if self.isMain and ns.db.sizeMode == "auto" and self.autoHeight then visible = math.min(ns.db.maxH, self.autoHeight) - chrome - 4
		elseif self.kind == "bag" and self.autoHeight then visible = math.min(ns.db.bagMaxH, self.autoHeight) - chrome - 4 end
	end
	if height <= 0 then visible = math.max(visible or 0, 1)   -- an empty list fits (not "not laid out yet")
	elseif not visible or visible <= 0 then return end   -- not laid out yet: decide once it is
	local need = height > visible + 1
	if (not need) ~= (self.barHidden and true or false) then
		-- The bar itself shows or hides at once. Rows hold still under the
		-- pointer, so the width change waits: holding asks for a tidy-up when
		-- the pointer leaves, and that full layout comes back here.
		-- Hiding waits for the pointer (a hidden bar can't float anywhere);
		-- showing never does, or the bar would sit outside the narrower list.
		if not need and (self.held or (self.frame.IsMouseOver and self.frame:IsMouseOver())) then
			bar:SetShown(false)
			if not self.held and ns.WatchHeld then self.held = true; ns.WatchHeld() end
			return
		end
		if InCombatLockdown() then ns:Safely("barSpace" .. self.name, function() self:UpdateBarSpace() end); return end
		self.inBarUpdate = true
		self.barHidden = not need
		bar:SetShown(need)
		self:PlaceScroll()
		self.inBarUpdate = false
		ns:NextFrame("barSpace" .. self.name, function() if self.frame:IsShown() then self:Refresh(true) end end)
		return
	end
	bar:SetShown(not self.barHidden)
	-- Keep the list's place in step (a skin switch can restore an older one).
	if not InCombatLockdown() and not self.held then
		self.inBarUpdate = true; self:PlaceScroll(); self.inBarUpdate = false
	end
end

-- After resizing: save where the window now is, measured from the same
-- corner its saved spot uses (bottom-right by default), so it stays put.
function View:SaveSizedPosition()
	local f = self.frame
	if not (self.isMain or self.isBank) then return end
	local key = self.isMain and "point" or "bankPoint"
	local saved = ns.db[key]
	local point = type(saved) == "table" and saved[1] or "BOTTOMRIGHT"
	local L, R, T, B = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
	if not (L and R and T and B) then return end
	local s, us = f:GetEffectiveScale(), UIParent:GetEffectiveScale()
	local UW, UH = UIParent:GetWidth() * us / s, UIParent:GetHeight() * us / s
	local x, y
	if point:find("LEFT") then x = L elseif point:find("RIGHT") then x = R - UW else x = (L + R) / 2 - UW / 2 end
	if point:find("TOP") then y = T - UH elseif point:find("BOTTOM") then y = B else y = (T + B) / 2 - UH / 2 end
	ns:Set(key, { point, "UIParent", point, math.floor(x + 0.5), math.floor(y + 0.5) }, true)
end

-- Where the bag strip and the column header sit, for every state: Travel
-- Mode on (under the title row) or off (under the toolbar), the strip open
-- (the header under it) or closed. Travel Mode and the strip both come here,
-- so they can't disagree.
function View:PlaceHeader(travel)
	if not self.header then return end
	if travel == nil then travel = self.travelShown and true or false end
	local base = (travel and self.title) or self.headerAnchor or self.tools
	local shift = self.belowShift or 0
	local above, gap = base, travel and -8 or -4
	if self.bagBar and self.bagBarOpen then
		self.bagBar:ClearAllPoints()
		self.bagBar:SetPoint("TOPLEFT", base, "BOTTOMLEFT", (base == self.title) and shift or 0, travel and -8 or -10)
		self.bagBar:SetPoint("TOPRIGHT", base, "BOTTOMRIGHT", 0, travel and -8 or -10)
		above, gap = self.bagBar, -4
	end
	self.header:ClearAllPoints()
	self.header:SetPoint("TOPLEFT", above, "BOTTOMLEFT", (above == self.title) and shift or 0, gap)
	self.header:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, gap)
end

-- The bag-strip button's icon. Modern: the toolbar icons' colors (resting
-- grey, brighter on hover, the accent while the strip is open). Classic: the
-- same as the count buttons beside it, whose icons take their label's color
-- (warm off-white at rest, gold while on).
function View:ColorBagBarButton()
	local b = self.btnBagBar
	if not (b and b.icon) then return end
	local on = ns.db.bagBar and true or false
	if b.classicOn then
		local r, g, bl = b.label:GetTextColor()
		if r then b.icon:SetVertexColor(r, g, bl) end
	elseif on then b.icon:SetVertexColor(ns.Skins:Accent())
	elseif b.iconHover then b.icon:SetVertexColor(0.93, 0.91, 0.88)
	else b.icon:SetVertexColor(MUTED[1], MUTED[2], MUTED[3]) end
end
