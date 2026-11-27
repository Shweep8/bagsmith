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
	cols = "bankCols", colOrder = "bankColOrder", colWidths = "bankColWidths", colAside = "bankColAside" }
-- Sheets remember their own view (optional, the sheetViews setting): each
-- sheet tab keeps its own Sections, Sort, View, Merge Stacks and collapsed
-- sections. The All tab, and every tab with the setting off, use the
-- window's own settings. Sheets only store what was changed on them; the
-- rest follows the window.
local SHEET_KEYS = { grp = true, sort = true, view = true, mergeStacks = true }
function View:SheetPrefs(create)
	if not (ns.db.sheetViews and self.big and self.st and self.st.sheet and self.st.sheet ~= "All") then return nil end
	if ns.ui.owner and not self.isBank then return nil end   -- browsing another character
	if self.isMain and ns.ui.global then return nil end   -- (1.9.0-beta4) Global Inventory has its own settings
	local all = ns.db.sheetPrefs
	local win = self.isBank and "bank" or "bags"
	all[win] = all[win] or (create and {} or nil)
	if not all[win] then return nil end
	local p = all[win][self.st.sheet]
	if not p and create then p = { collapsed = {} }; all[win][self.st.sheet] = p end
	return p
end
-- (1.9.0-beta2) Global Inventory reads as a list of every item, unmerged, by section (never by bag): the window's own
-- choices are overridden while it shows, not changed, so they're as they were when it's left.
local GLOBAL_PREF = { view = "list", mergeStacks = false }
function View:Pref(key)
	if self.isMain and ns.ui.global then
		if GLOBAL_PREF[key] ~= nil then return GLOBAL_PREF[key] end
		-- (1.9.0-beta4) its own settings, for the account: sort, sections, column widths
		local G = ns.Inventory and ns.Inventory:Settings()
		if G then
			if key == "sort" and G.sort then return G.sort end
			if key == "grp" then local g = G.grp or ns.db.grp; return (g == "bag") and "type" or g end
			if key == "colWidths" then return G.colWidths end
			if key == "cols" or key == "colOrder" then return G[key] end   -- (1.9.0-beta6) Global Columns
		end
	end
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
	-- (1.9.0-beta4) In Global Inventory: its own sort and sections; List and Merge are fixed there (beta5: Merge greyed)
	if self.isMain and ns.ui.global and ns.Inventory then
		local G = ns.Inventory:Settings()
		if key == "sort" then G.sort = value; return true end
		if key == "grp" then G.grp = (value == "bag") and "type" or value; return true end
		if key == "view" or key == "mergeStacks" then return true end
	end
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
-- (1.9.0-beta8, Shweep: "in modern style the footer almost rides high") Modern: the footer's contents sit this much
-- lower, centered between its line and the window's bottom edge (the line and the tabs stay where they were)
local FOOTER_DROP = 6
local function footerFont() return ns.Fonts and ns.Fonts:FooterName("GameFontHighlightSmall") or "GameFontHighlightSmall" end
local COLW = { who = 0.14, c = 0.07, il = 0.07, rq = 0.06, t = 0.16, sl = 0.11, bd = 0.07, v = 0.12, w = 0.14, age = 0.08, ah = 0.12, jk = 0.05, fv = 0.05, cc = 0.05 }
local COLPAD = 10   -- gap kept clear at the right edge of every column
local BAR_ROOM = 22 -- the scrollbar's lane at the right of a list; given back to the list when nothing scrolls
local NUMERIC = { c = true, il = true, rq = true, v = true, age = true, ah = true }
local COLKEY = { who = "colWho", c = "colQty", il = "colLevel", rq = "colReq", t = "colType", sl = "colSlot", bd = "colBind", v = "colValue", w = "colWhere", age = "colAge", ah = "colAH", jk = "colJunk", fv = "colFav", cc = "colCurr" }
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
-- (1.9.0-beta19, Shweep: "can we get font working in header buttons (both styles) and the alt dropdown") the chosen
-- Font at the game's own size (Fonts:FaceName): the toolbar's buttons and labels, the sheet tabs, the character picker
local function faceFont(template)
	template = template or "GameFontHighlightSmall"
	return ns.Fonts and ns.Fonts.FaceName and ns.Fonts:FaceName(template) or template
end
View.FaceFont = faceFont

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

-- (1.7.0-beta11) a secondary button's Classic art, grayed: every texture of Blizzard's button desaturated (or put back)
local SECONDARY_ART = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }
local function grayArt(art, on)
	on = on and true or false
	if (art.bsGrayed or false) == on then return end
	art.bsGrayed = on
	local function d(t)
		if t and t.SetDesaturated and (not t.GetObjectType or t:GetObjectType() == "Texture") then pcall(t.SetDesaturated, t, on) end
	end
	if art.GetRegions then for _, r in ipairs({ art:GetRegions() }) do d(r) end end
	for _, get in ipairs(SECONDARY_ART) do if art[get] then local ok, t = pcall(art[get], art); if ok then d(t) end end end
end
-- (1.9.0-beta5, Shweep: "disabled buttons, tabs etc, need tooltips explaining not available in global inventory") a
-- control Global Inventory can't use: greyed and disabled, its tooltip naming it, saying so and why. Information, not
-- help, so shown with Show Help Tooltips off. The game runs no hover scripts on a disabled button unless asked to
-- (beta4's greyed buttons had their reasons, unseen), hence SetMotionScriptsWhileDisabled.
View.GLOBAL_OFF = "Not available in Global Inventory"
local function offTip(b)
	if not (b.offReason and ns.TooltipsOK()) then return false end
	GameTooltip:SetOwner(b, "ANCHOR_TOP")
	ns.TipText(GameTooltip, b.offName or "")
	-- (1.11.0-beta6) the line under the name is Global Inventory's unless the caller gave its own, or none (false):
	-- a control greyed for another reason said "Not available in Global Inventory" over it (New Gear Set at the
	-- game's limit, since 1.11.0-beta1)
	local head = b.offHead
	if head == nil then head = View.GLOBAL_OFF end
	if head then ns.TipLine(GameTooltip, head, 1, 0.82, 0) end
	ns.TipLine(GameTooltip, b.offReason, 0.8, 0.8, 0.8, true)
	GameTooltip:Show()
	return true
end
View.OffTip = offTip
-- each greyed control's reason, one line
View.GLOBAL_WHY = {
	merge = "Global Inventory already shows each item once, with every character's count together.",
	icons = "Global Inventory is a list, so it can show who has each item and where.",
	gearSets = "Gear sets belong to the character you're playing.",
	bagWindows = "Bag windows show the bags of the character you're playing.",
	bagBar = "The bag bar shows the bags of the character you're playing.",
	byBag = "Global Inventory brings all your characters' bags together, so it groups items by section.",   -- (beta17)
}
function View.GlobalOff(b, off, name, reason, head)
	if not b then return end
	if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
	if off then
		b:Disable(); b:SetAlpha(0.45); b.offName, b.offReason, b.offHead = name, reason, head
	else
		if b.offReason then b:Enable(); b:SetAlpha(1) end
		b.offName, b.offReason, b.offHead = nil, nil, nil
	end
end
local function textButton(parent, text, width, onClick, template, name)
	-- 1.2.0: a template lets a secure action button wear the same look (its click is the game's, not ours)
	local b = CreateFrame("Button", name, parent, template and (template .. ", BackdropTemplate") or "BackdropTemplate")
	b:SetSize(width or 60, 20)
	b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	b.label = fontString(b, "GameFontHighlightSmall", "CENTER")
	b.label:SetPoint("CENTER")
	b.label:SetText(text)
	if onClick then b:SetScript("OnClick", onClick) end
	b:SetScript("OnEnter", function(self)
		if offTip(self) then return end   -- (1.9.0-beta5)
		local help = self.tip and ns.HelpTipsOK()
		-- (1.8.0-beta5) information, not help: shown even with Show Help Tips off (the free-slot breakdown)
		local info = self.tipInfo and ns.TooltipsOK() and self.tipInfo(self)
		if help or info then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			if help then
				ns.TipText(GameTooltip, self.tip)
				-- (1.5.8) an optional second line, as icon buttons have (a function, so it can describe the moment)
				local sub = type(self.tipSub) == "function" and self.tipSub(self) or self.tipSub
				if sub then ns.TipLine(GameTooltip, sub, 0.8, 0.8, 0.8, true) end
			end
			if info then info(GameTooltip, help) end
			GameTooltip:Show()
		end
	end)
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
				-- (1.7.0-beta11) a secondary button: the same art, grayed, with light gray text
				grayArt(self.classic, self.secondary)
				if self.secondary then self.label:SetTextColor(0.85, 0.85, 0.85)
				elseif on then self.label:SetTextColor(1, 0.82, 0) else self.label:SetTextColor(0.95, 0.9, 0.8) end
			end
			return
		end
		-- Hover lifts the button a step; a selected one keeps its accent border
		-- and only brightens, so hover never looks like selection.
		local hov = self.hover and modernSkin()
		if self.secondary then
			-- (1.7.0-beta11) a secondary choice beside the main one: plain gray, a step lighter on hover, never accented
			if hov then
				self:SetBackdropColor(0.30, 0.30, 0.30, 1); self:SetBackdropBorderColor(0.50, 0.50, 0.50, 1)
				self.label:SetTextColor(0.92, 0.92, 0.92)
			else
				self:SetBackdropColor(0.24, 0.24, 0.24, 1); self:SetBackdropBorderColor(0.40, 0.40, 0.40, 1)
				self.label:SetTextColor(0.80, 0.80, 0.80)
			end
		elseif on then
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
	-- (1.7.0-beta11) a secondary button (Protect beside the Loot Helper's Destroy): gray in both skins
	function b:SetSecondary(on)
		self.secondary = on and true or nil
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
		if offTip(self) then return end   -- (1.9.0-beta5)
		if ns.HelpTipsOK() then
			GameTooltip:SetOwner(self, "ANCHOR_TOP"); ns.TipText(GameTooltip, self.tip)
			-- An optional second line (a function, so it can describe the moment).
			local sub = type(self.tipSub) == "function" and self.tipSub(self) or self.tipSub
			if sub then ns.TipLine(GameTooltip, sub, nil, nil, nil, true) end
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
View.MIN_W = { main = 440, bank = 500 }   -- (1.6.0; 620 for both before)
-- (1.6.0-beta7, the beta6 audit's R3; Shweep) The columns a narrow window may not set aside (shown, unticked under Narrow
-- Windows) must still fit at their narrowest (30 px each, Item 90) beside the list's margins and scrollbar lane, so the
-- window can't be dragged narrower than that: the bags window's 440 (the bank's 500), or more when many columns are kept.
-- Returns the narrowest width and the plain minimum.
function View.MinWidthFor(bank)
	local base = bank and View.MIN_W.bank or View.MIN_W.main
	local db = ns.db
	if not db then return base, base end
	local cols, aside = db[bank and "bankCols" or "cols"], db[bank and "bankColAside" or "colAside"]
	local kept = 0
	for _, key in ipairs(type(cols) == "table" and cols or {}) do
		local canGo = key ~= "c" and type(aside) == "table" and ns.IndexOf(aside, key) ~= nil   -- (Qty never goes)
		if not canGo and ns.Columns:Usable(key) then kept = kept + 1 end   -- (1.12.0-beta1: AH Price, and a registered column, only while it can show)
	end
	local need = PAD * 2 + BAR_ROOM + (View.ITEM_MIN or 90) + kept * (View.COL_MIN or 30)
	return math.max(base, need), base
end
-- Applies that narrowest width to the bags or bank window: the resize grip stops there, and a window narrower than it
-- widens to it (the saved size isn't changed). Out of combat only (the window holds protected item buttons).
-- (1.9.0-beta8) The width the footer needs at its text size: a large amount of gold on the left, the count buttons on
-- the right (and the resize grip's room), so bigger footer text can't run the two together.
function View:FooterNeed()
	if not (self.footer and self.moneyText) then return 0 end
	local m = self.footerMeasure
	if not m then m = self.footer:CreateFontString(nil, "OVERLAY", footerFont()); m:Hide(); self.footerMeasure = m end
	m:SetFontObject(footerFont())
	m:SetText(GetMoneyString and GetMoneyString(99999999, true) or "9999g 99s 99c")
	if self.btnBags and self.btnBags.Fit then self.btnBags:Fit() end
	if self.btnReagent and self.btnReagent.Fit then self.btnReagent:Fit() end
	local right = 18 + (self.btnBags and self.btnBags:GetWidth() or 0)
		+ ((self.btnReagent and self.btnReagent:IsShown()) and (self.btnReagent:GetWidth() + 6) or 0)
		+ ((self.btnBagBar and self.btnBagBar:IsShown()) and (self.btnBagBar:GetWidth() + 6) or 0)
	local mw = (m.GetUnboundedStringWidth and m:GetUnboundedStringWidth()) or m:GetStringWidth() or 0   -- (textWidth is below)
	return math.ceil(PAD * 2 + MONEY_X + mw + 20 + right + 12)
end
function View:ApplyMinWidth()
	if not self.big then return end
	ns:Safely("minwidth:" .. self.name, function()
		local f = self.frame
		local minW = math.max(View.MinWidthFor(self.isBank), self:FooterNeed())   -- (beta8) and the footer's text
		self.minWidth = minW
		if f.SetResizeBounds then f:SetResizeBounds(minW, 300, 1400, 1200) end
		if (f:GetWidth() or 0) < minW then f:SetWidth(minW) end
	end)
end

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
	-- (1.6.0) as narrow as 440 px (the bags window) or 500 (the bank, whose bag strip needs the room); up to 1400 wide,
	-- 1200 tall. Small bag windows size themselves.
	if f.SetResizeBounds then f:SetResizeBounds((View.MinWidthFor(self.isBank)), 300, 1400, 1200) end

	-- Title bar
	-- The whole top band drags the window, from the very top edge down to the
	-- title row. Buttons in the band sit above it and still take clicks.
	local drag = CreateFrame("Frame", nil, f)
	drag:SetPoint("TOPLEFT", 0, 0)
	drag:SetPoint("TOPRIGHT", 0, 0)
	drag:SetHeight(PAD + TITLE_H + 6)
	drag:EnableMouse(true)
	drag:RegisterForDrag("LeftButton")
	-- (1.7.0-beta2) Lock Windows: no moving (nor resizing, the grip below) while it's on
	drag:SetScript("OnDragStart", function() if ns:WindowsLocked() then return end; self.dragMoving = true; f:StartMoving(); ns.Buttons:WakeModernBorders() end)
	drag:SetScript("OnDragStop", function()
		if ns:WindowsLocked() and not self.dragMoving then return end   -- (locked: it never started, so no spot to save)
		self.dragMoving = nil
		f:StopMovingOrSizing(); self:SavePosition(); ns:RepositionPanels()
		ns.Buttons:WakeModernBorders()   -- (1.7.3) the borders settle where the window landed
	end)
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
		-- (1.9.0-beta2, Shweep) Global Inventory: left of Travel Mode, the divider moving to its left
		self.btnGlobal = iconButton(title, MEDIA .. "ui-globe.tga", "Global Inventory", function() self:SetGlobal(not ns.ui.global) end)
		self.btnGlobal.tipSub = function() return ns.ui.global and "Click to go back to your bags." or "Every item on your characters on this realm, in one list." end
		self.btnGlobal:SetPoint("RIGHT", self.btnTravel, "LEFT", 0, 0)
		self.titleDivider:SetPoint("RIGHT", self.btnGlobal, "LEFT", -4, 0)
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
		-- (1.5.5) Travel Mode hides the toolbar and its Collapse All Sections button: a twin sits at the right end of
		-- Travel Mode's search box, just before the broom (Shweep's choice), showing only there and only with sections.
		self.btnLanesTravel = iconButton(title, MEDIA .. "ui-collapse.tga", "Collapse or Expand All Sections", function() self:ToggleAllLanes() end)
		self.btnLanesTravel:SetPoint("RIGHT", self.btnClean, "LEFT", -2, 0)
		self.btnLanesTravel:Hide()

		-- Character picker
		self.charBtn = textButton(title, "", 170, function() ns.Popups:ToggleCharacters(self) end)
		self.charBtn:SetHeight(22)
		self.charBtn:SetPoint("LEFT", self.subText, "RIGHT", 10, 0)
		self.charIcon = self.charBtn:CreateTexture(nil, "ARTWORK")
		self.charIcon:SetSize(14, 14)
		self.charIcon:SetPoint("LEFT", 6, 0)
		-- (1.6.0-beta11, Shweep: "feel free to ellipse names") the level stands on its own at the right, before the arrow, and
		-- the name takes what's left, cut short with "..." in a narrow picker; the level is never cut
		self.charBtn.label:SetFontObject(faceFont())   -- (1.9.0-beta19)
		self.charLevel = fontString(self.charBtn, faceFont(), "RIGHT")
		self.charLevel:SetPoint("RIGHT", self.charBtn, "RIGHT", -View.PICKER_ARROW, 0)
		self.charLevel:SetTextColor(0.56, 0.55, 0.51)
		self.charBtn.label:ClearAllPoints()
		self.charBtn.label:SetPoint("LEFT", self.charIcon, "RIGHT", 5, 0)
		self.charBtn.label:SetPoint("RIGHT", self.charLevel, "LEFT", -5, 0)
		self.charBtn.label:SetJustifyH("LEFT")
		if self.charBtn.label.SetWordWrap then self.charBtn.label:SetWordWrap(false) end
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
		-- (1.9.0-beta4, Shweep) Travel Mode, too narrow for the search box in the title row: a search icon in its place;
		-- clicked, search opens as its own full-width row under the title, and folds back once cleared and left
		if self.isMain then
			self.btnSearchFold = iconButton(self.title, "Interface\\AddOns\\BagSmith\\Media\\ui-search.tga", "Search", function() self:OpenTravelSearch(not self.searchOpen) end)
			self.btnSearchFold:Hide()
			search:HookScript("OnEditFocusLost", function(box)
				if self.searchOpen and (box:GetText() or "") == "" then self:OpenTravelSearch(false) end
			end)
		end
		self.btnFilter = textButton(f, "Filter", 64, function() ns.Popups:ToggleFilters(self) end)
		self.btnFilter.label:SetFontObject(faceFont())   -- (1.9.0-beta19)
		self.btnFilter:SetHeight(TOOL_H - 4)
		self.btnFilter:SetPoint("LEFT", search, "RIGHT", 6, 0)

		-- Tools row. Spans the window (not the search row): the search row
		-- follows the toolbar's end (see LayoutTools), so the toolbar must not
		-- take its width from the search row, or the two would chase each other.
		-- (1.5.2) Its left edge hangs from the title too, at the rows' inner margin (PlaceSearch re-places it with the
		-- Classic shift), not from the search box: in the Classic bank the search box alone moves clear of the portrait,
		-- and the toolbar and everything below it must stay put.
		local tools = CreateFrame("Frame", nil, f)
		tools:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -(2 + TOOL_H + 4))
		tools:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -(2 + TOOL_H + 4))
		tools:SetHeight(TOOL_H)
		self.tools = tools
		self.toolItems = {}
		-- An exclusive group: a small muted label, then joined segments with no
		-- gap between them, so it reads as one control. Standalone actions get
		-- their own separate buttons with clear space around them.
		local function seg(label, items, get, set)
			local btns = {}
			local lbl = fontString(tools, faceFont())   -- (1.9.0-beta19: the chosen Font, as the buttons)
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
				b.label = fontString(b, faceFont(), "CENTER"); b.label:SetPoint("CENTER"); b.label:SetText(it[2])
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
				b:HookScript("OnEnter", offTip); b:HookScript("OnLeave", function(x) if x.offReason then GameTooltip:Hide() end end)   -- (1.9.0-beta5)
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
		self.grpSegBtns = self.segBoxes[#self.segBoxes].btns   -- (1.9.0-beta17) By Bag, greyed in Global Inventory
		self.toolItems[#self.toolItems].hideAt = 3
		-- (1.6.0) For narrow windows: Sections as one button with a menu (from the fourth step), then, at the fifth,
		-- Sort drops "Sort:", and Merge Stacks and List / Icons become icons.
		self.btnGrpMenu = textButton(tools, "", 88, function(b)
			local cur, items = self:Pref("grp"), {}
			for _, it in ipairs(View.GRP_CHOICES) do
				-- (1.9.0-beta17, Shweep: "By Bag needs to be disabled / greyed out and needs tooltip") not in Global Inventory
				local off = it[1] == "bag" and self.isMain and ns.ui.global
				items[#items + 1] = { text = it[2], checked = cur == it[1], disabled = off or nil,
					tipNote = off and View.GLOBAL_OFF or nil, tip = off and View.GLOBAL_WHY.byBag or nil,
					onClick = function()
						self:SetPref("grp", it[1]); self.syncGrp(); self:SyncTools(); ns:RefreshViews(true)
					end }
			end
			ns.ShowMenu(items, b)
		end)
		self.btnGrpMenu.tip = "Sections"
		self.btnGrpMenu.label:SetFontObject(faceFont())   -- (1.9.0-beta19)
		self.btnGrpMenu.tipSub = "Show all your items together, by section, or by bag"
		self.btnGrpMenu.label:ClearAllPoints()
		self.btnGrpMenu.label:SetPoint("LEFT", 8, 0); self.btnGrpMenu.label:SetPoint("RIGHT", -18, 0)
		self.btnGrpMenu.chev = self.btnGrpMenu:CreateTexture(nil, "OVERLAY")
		self.btnGrpMenu.chev:SetSize(10, 10); self.btnGrpMenu.chev:SetPoint("RIGHT", -6, 0)
		self.btnGrpMenu.chev:SetTexture(MEDIA .. "ui-chev-down.tga")
		self.btnGrpMenu.chev:SetVertexColor(MUTED[1], MUTED[2], MUTED[3])
		self.btnGrpMenu.riders = { self.btnGrpMenu.chev }
		self.toolItems[#self.toolItems + 1] = { frame = self.btnGrpMenu, width = 88, gap = 14, onlyAt = 3 }
		self.btnLanes = iconButton(tools, MEDIA .. "ui-collapse.tga", "Collapse or Expand All Sections", function() self:ToggleAllLanes() end)
		self.toolItems[#self.toolItems + 1] = { frame = self.btnLanes, width = 24, gap = 10, offset = -10 }
		self.btnSort = textButton(tools, "Sort: quality", 96, function()
			local modes, cur = { "quality", "name", "ilvl", "newest", "oldest", "off" }, self:Pref("sort")
			local i = ns.IndexOf(modes, cur) or 1
			self.st.colSort = nil
			self:SetPref("sort", modes[i % #modes + 1])
			self:SyncTools(); ns:RefreshViews(true)
		end)
		self.btnSort.label:SetFontObject(faceFont())   -- (1.9.0-beta19)
		self.toolItems[#self.toolItems + 1] = { frame = self.btnSort, width = 96, gap = 8, w4 = 72 }
		local function toggleMerge()
			-- (1.9.0-beta5, Shweep) greyed in Global Inventory, which already shows each item once (beta4's All Rows is gone)
			if self.isMain and ns.ui.global then return end
			self:SetPref("mergeStacks", not self:Pref("mergeStacks")); self:SyncTools(); ns:RefreshViews(true)
		end
		self.btnMerge = textButton(tools, "Merge Stacks", 92, toggleMerge)
		self.btnMerge.label:SetFontObject(faceFont())   -- (1.9.0-beta19)
		self.btnMerge.tip = "Combine stacks of the same item into one, with the total count: one row in List view, one icon in Icons"
		self.toolItems[#self.toolItems + 1] = { frame = self.btnMerge, width = 92, gap = 12, compactText = "Merge", fullText = "Merge Stacks", compactWidth = 56, hideAt = 4 }
		self.btnMergeIcon = iconButton(tools, MEDIA .. "ui-merge.tga", "Merge Stacks", toggleMerge)
		self.btnMergeIcon.tipSub = function() return self:Pref("mergeStacks") and "On: each item shows once, with its total count" or "Off: click to show each item once, with its total count" end
		self.toolItems[#self.toolItems + 1] = { frame = self.btnMergeIcon, width = 24, gap = 4, onlyAt = 4, live = true }
		self.syncView = seg("View", { { "list", "List", 46 }, { "icons", "Icons", 50 } }, function() return self:Pref("view") end, function(v) self:SetPref("view", v) end)
		self.viewSegBtns = self.segBoxes[#self.segBoxes].btns   -- (1.9.0-beta5) Icons, greyed in Global Inventory
		self.toolItems[#self.toolItems].hideAt = 4
		self.btnViewIcon = iconButton(tools, MEDIA .. "ui-list.tga", "List View", function()
			self:SetPref("view", self:Pref("view") == "list" and "icons" or "list"); self.syncView(); self:SyncTools(); ns:RefreshViews(true)
		end)
		self.btnViewIcon.tipSub = function() return self:Pref("view") == "list" and "Click to switch to Icons" or "Click to switch to List" end
		self.toolItems[#self.toolItems + 1] = { frame = self.btnViewIcon, width = 24, gap = 0, onlyAt = 4, live = true }
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
		b.text = fontString(b, ns.Fonts and ns.Fonts:Name("GameFontHighlightSmall") or "GameFontHighlightSmall")   -- (1.9.0-beta8) Text Size
		b.text:SetAllPoints()
		b.text:SetText(text)
		b.key = key
		b:SetScript("OnClick", function()
			ns:SortByColumn(self.st, key)
			if self.SyncTools then self:SyncTools() end
			ns:RefreshViews(true)
		end)
		b:SetScript("OnEnter", function(btn)
			if not ns.HelpTipsOK() then return end
			GameTooltip:SetOwner(btn, "ANCHOR_TOP")
			ns.TipText(GameTooltip, "Click to sort by " .. text)
			if key == "age" then ns.TipLine(GameTooltip, "Time since BagSmith first saw the item in your bags", 0.6, 0.6, 0.6) end
			-- (1.12.0-beta1) a registered column says what it shows (Pawn's: how much of an upgrade)
			local reg = ns.Columns:Get(key)
			if reg and reg.tip then ns.TipLine(GameTooltip, reg.tip, 0.6, 0.6, 0.6) end
			ns.TipLine(GameTooltip, "Drag the gold line on either side to resize", 0.6, 0.6, 0.6)
			-- (1.6.0-beta6) what a narrow window has set aside, and where to choose
			local aside = self:AsideText()
			if aside then ns.TipLine(GameTooltip, aside, 0.98, 0.78, 0.46) end
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
	headerLabel("who", "Who")   -- (1.9.0-beta2) Global Inventory's own column
	-- (1.12.0-beta1) the registered columns there are now (Pawn's); one registered later gets its heading when it is
	-- first laid out (View:LayoutHeader)
	for _, key in ipairs(ns.Columns.keys) do headerLabel(key, ns.COL_LABEL[key] or key) end
	self.MakeHeaderLabel = headerLabel

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
	self.footerKey = FOOTER_H .. ":0"   -- (beta8) as built; LayoutFooter places it for the skin and Footer Text Size
	self.moneyText = fontString(footer, footerFont())
	-- The gold sits 10 px in from the left, closer to the room the count
	-- buttons keep on the right.
	self.moneyText:SetPoint("LEFT", MONEY_X, 0)
	-- (1.8.0-beta12, Shweep) Click your gold to open or close the currency drawer (the main window's; it opens beside it).
	-- (1.9.1-beta1, Shweep: "In bank window mousing over the gold in corner should display same tool tip as main bag")
	-- the bank's gold has the same tooltip; only the bags' opens the drawer
	if self.kind == "main" or self.kind == "bank" then
		local main = self.kind == "main"
		local mb = CreateFrame("Button", nil, footer)
		mb:SetPoint("TOPLEFT", self.moneyText, "TOPLEFT", -4, 4)
		mb:SetPoint("BOTTOMRIGHT", self.moneyText, "BOTTOMRIGHT", 4, -4)
		if main then mb:SetScript("OnClick", function() if ns.Drawer then ns.Drawer:Toggle() end end) end
		-- (1.9.0-beta1, Shweep) the tooltip lists your gold: each character's on this realm, Shift for the account
		function mb:ShowGoldTip(again)
			-- (beta2, Shweep: holding Shift reshaped it) shown again from scratch, as a fresh hover
			if again then GameTooltip:Hide() end
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			if GameTooltip.ClearLines then GameTooltip:ClearLines() end
			if ns.Inventory then ns.Inventory:AddGoldLines(GameTooltip) end
			if main and ns.HelpTipsOK() then
				GameTooltip:AddLine(" ")
				ns.TipLine(GameTooltip, "Click to open or close the currency drawer.", 0.8, 0.8, 0.8, true)
			end
			GameTooltip:Show()
		end
		mb:SetScript("OnEnter", function(b) if ns.Inventory then ns.Inventory.goldOwner = b end; b:ShowGoldTip() end)
		mb:SetScript("OnLeave", function() if ns.Inventory then ns.Inventory.goldOwner = nil end; GameTooltip:Hide() end)
		self.moneyButton = mb
	end
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
		self.btnBags.tipInfo = function() return self:FreeTip() end   -- (1.8.0-beta5) the free slots by kind of bag
		-- (1.8.0-beta12, Shweep) the footer's other count button shows the same breakdown
		if self.btnReagent then self.btnReagent.tipInfo = function() return self:FreeTip() end end
	else
		self.freeText = fontString(footer, footerFont(), "RIGHT")
		self.freeText:SetPoint("RIGHT", rightEdge, 0)
	end
	self.statusText = fontString(footer, footerFont(), "CENTER")
	-- (beta8) the count buttons' text in the footer's font too
	for _, b in ipairs({ self.btnBags or false, self.btnReagent or false }) do if b and b.label then b.label:SetFontObject(footerFont()) end end
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
	-- (1.7.3-beta2, Shweep's choice) Resizing drags an outline, not the window: the window keeps its size and contents
	-- until the button is let go, then takes the outline's size and lays out once. Resizing the window itself
	-- re-laid the contents while the size passed through (1.7.3-beta1 did it 20 times a second: it flickered, worst in
	-- Classic), or left them stale or blank (1.7.2).
	grip:SetScript("OnMouseDown", function()
		if ns:WindowsLocked() then self.lockedPress = true; return end   -- (1.7.0-beta2) Lock Windows
		self.sizing = true
		self:StartOutlineResize()
	end)
	grip:SetScript("OnMouseUp", function()
		if self.lockedPress then self.lockedPress = nil; return end
		self:EndOutlineResize()
		self.sizing = false
		-- Dragging never changes the size mode: in Fit to Items it sets the
		-- largest size; in Scalable it sets the size. Values are rounded.
		local w, h = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
		if self.isBank then
			ns:Set("bankW", w, true); ns:Set("bankH", h, true)
		elseif self:GlobalSize() then
			-- (1.9.0-beta13) resized in Global Inventory: its own size, never the bags'
			local G = ns.Inventory:Settings(); G.w, G.h = w, h
			local P = ns.SettingsPanel   -- (beta14) an open Settings shows it in Width and Height
			if P and P.ShowStepValue and P.frame and P.frame:IsShown() then P:ShowStepValue("__globalW", w); P:ShowStepValue("__globalH", h) end
		elseif ns.db.sizeMode == "auto" then
			ns:Set("maxW", w, true); ns:Set("maxH", h, true)
		else
			ns:Set("fixW", w, true); ns:Set("fixH", h, true)
		end
		-- Keep the window exactly where the resize left it (the saved spot
		-- was from before, so re-applying it made the window jump).
		self:SaveSizedPosition()
		if not self:GlobalSize() then self:ShowSizeInSettings() end   -- (1.7.3-beta6) an open Settings panel shows the size just saved
		self.refreshWanted = nil
		self:ApplySize(); self:Refresh(true)
		-- Once more on the next frame: the client can settle the new size a
		-- frame after the drag ends, and the layout should use the final one.
		ns:NextFrame("settle:" .. self.name, function() self:FinishResizeLayout() end)
		ns.Buttons:WakeModernBorders()
	end)
	self.grip = grip

	if self.kind == "main" then
		f:SetScript("OnSizeChanged", function() ns:NextFrame("panels", function() ns:RepositionPanels() end) end)
	end
	table.insert(UISpecialFrames, self.name)
	f:SetScript("OnShow", function()
		if ns.ready then PlaySound(SOUNDKIT.IG_BACKPACK_OPEN) end
		if InCombatLockdown() then ns:ApplyCombatFade(true) end
		-- (1.7.0-beta14, Shweep) the game's Show on Backpack picks, pinned before the window draws, so they're in the
		-- footer on the first frame
		if self.kind == "main" and ns.Currency and ns.Currency.SyncBlizzardPicks then ns:Guard("Currency picks", ns.Currency.SyncBlizzardPicks, ns.Currency) end
		-- The main window brings its companions (bag windows)
		-- back with it; the others just refresh themselves.
		if self.kind == "main" then ns:RefreshViews(true) else self:Refresh(true) end
		-- (1.5.1-beta2) and its list canvas laid out again once the client has drawn a frame: after a reload the window
		-- is built while closed, and the client could keep a stale picture of the canvas and draw nothing (Shweep: a
		-- blank window, in both styles, until List and Icons were swapped). See View:RefreshCanvas.
		ns:NextFrame("canvas:show:" .. self.name, function() self:RefreshCanvas("show") end)
		-- (1.5.5) and its header laid out again for its real width: in a fresh session the window is built closed, and on
		-- this client its size event may not fire when it opens, so the header kept a width it read as 0 (Shweep: it
		-- didn't fill the window until resized)
		if self.LayoutTools then ns:NextFrame("tools:show:" .. self.name, function() self:LayoutTools() end) end
		-- (1.6.0) and its Background Opacity (a window built or re-dressed since it was last applied)
		if ns.ApplyBgOpacity then ns:NextFrame("bgOpacity:show", function() ns:ApplyBgOpacity(); ns:ApplyCombatFade(InCombatLockdown()) end) end
		-- (The full layout above fills every button, and with it each one's cooldown, so a cooldown that started while the
		-- window was closed shows on opening: 1.6.2-beta1's extra refresh here was redundant and was removed in beta4.)
		-- (1.6.2-beta4) and its list area placed, once the window has drawn (View:EnsureListPlaced)
		if self.ScheduleListPlaced then self:ScheduleListPlaced() end
	end)
	f:SetScript("OnHide", function()
		-- A drag cut short never leaves it waiting, nor its outline on screen. (1.7.3-beta2: this was a HookScript on
		-- the grip's side, added before this SetScript, which replaced it, so it never ran.)
		self.sizing = false; self.refreshWanted = nil; self:CancelOutlineResize()
		if ns.ready then PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE) end
		if self.isBank and ns.Bank then ns.Bank:OnWindowHidden() end
		-- (1.9.0-beta2, Shweep) closing BagSmith leaves Global Inventory: the bags come back as they were
		if self.isMain and ns.ui.global then self:SetGlobal(false) end
		if self.isMain then ns:OnMainHidden() end
	end)

	Skins:Register(f, function() self:ApplySkin() end)
	self:ApplySize()
end

------------------------------------------------------------------------
-- Skin, size, position
------------------------------------------------------------------------
-- Places the toolbar items left to right. If the full form does not fit the window, it narrows in steps (1.4.1):
-- first the group labels ("Sections", "View") are hidden; then "Merge Stacks" becomes "Merge"; (1.6.0-beta5) then
-- Sections becomes one button with a menu (the widest piece goes first); last, for the narrowest windows, Sort drops
-- "Sort:", and Merge Stacks and List / Icons become icons. (beta5, Shweep) The last control (List / Icons) sits at the
-- row's right end, so the toolbar and the search row above it both end at the window's edge, at every width.
View.GRP_CHOICES = { { "none", "All" }, { "type", "By Section" }, { "bag", "By Bag" } }
View.TOOL_LEVELS = 4
local function toolShown(it, level)
	if it.isLabel and level >= 1 then return false end
	if it.onlyAt and level < it.onlyAt then return false end
	if it.hideAt and level >= it.hideAt then return false end
	return true
end
local function toolWidth(it, level)
	if it.live and it.frame.GetWidth then return it.frame:GetWidth() end
	if level >= 4 and it.w4 then return it.w4 end
	return (level >= 2 and it.compactWidth) or it.width
end
function View:ToolsTotal(level)
	local w = 0
	for _, it in ipairs(self.toolItems or {}) do
		if toolShown(it, level) then w = w + toolWidth(it, level) + it.gap + (it.offset or 0) end
	end
	return w
end
function View:LayoutTools()
	if not self.toolItems then return end
	-- (1.9.0-beta19) the group labels in the chosen Font: measured again (a font change lays the header out anew)
	for _, it in ipairs(self.toolItems) do if it.isLabel and it.frame.GetStringWidth then it.width = it.frame:GetStringWidth() end end
	local avail = self.tools:GetWidth()
	local level = 0
	-- (1.5.5) A width that reads 0 (or nearly) isn't known yet (a window built while closed): it isn't "too narrow",
	-- so the full header is laid out, and the window's next open lays it out again for its real width.
	if avail and avail > 50 then
		while level < View.TOOL_LEVELS and self:ToolsTotal(level) > avail do level = level + 1 end
	end
	self.toolsLevel = level
	self.toolsCompact = level >= 1
	local x, last, lastX, lastW = 0, nil, 0, 0
	local prev, lastLabel = nil, nil   -- (1.6.0) a shown group label right before the last control ("View")
	for _, it in ipairs(self.toolItems) do
		local f = it.frame
		if not toolShown(it, level) then
			f:Hide()
		else
			-- (1.5.5) Collapse All Sections shows only when there are sections (as SyncTools decides): laying the toolbar
			-- out again on every open mustn't bring it back with nothing to collapse
			if f == self.btnLanes and #(self.laneIds or {}) == 0 then f:Hide() else f:Show() end
			local w = toolWidth(it, level)
			if it.compactText then
				f.label:SetText((level >= 2 and it.compactWidth) and it.compactText or it.fullText); f:SetWidth(w)
			elseif it.w4 then
				f:SetWidth(w)
			end
			x = x + (it.offset or 0)
			f:ClearAllPoints(); f:SetPoint("LEFT", self.tools, "LEFT", x, 0)
			lastLabel = (prev and prev.isLabel) and prev or nil
			last, lastX, lastW = it, x, w
			x = x + w + it.gap
			prev = it
		end
	end
	self.toolsWidth = x
	-- (1.6.0-beta5) the last control moves to the row's right end (never back over the one before it). (1.6.0, Shweep's
	-- screenshot) its group label moves with it, keeping its gap: "View" stayed behind after Merge Stacks.
	if last and avail and avail > 50 and avail - lastW > lastX then
		lastX = avail - lastW
		last.frame:ClearAllPoints(); last.frame:SetPoint("LEFT", self.tools, "LEFT", lastX, 0)
		if lastLabel then
			lastLabel.frame:ClearAllPoints(); lastLabel.frame:SetPoint("LEFT", self.tools, "LEFT", lastX - lastLabel.gap - toolWidth(lastLabel, level), 0)
		end
	end
	if self.btnSort then self:SyncSortLabel() end
	if self.btnGrpMenu then self:SyncGrpMenu() end
	-- The search row ends where the toolbar ends: Filter's right edge lines up with the last button (List / Icons), which
	-- now sits at the row's end, so both rows reach the window's edge. Before the first layout pass (width unknown) it's
	-- where the toolbar's controls end. If the toolbar ever runs past the window's edge, Filter stays at the edge.
	local toolsEnd = last and (lastX + lastW) or 0
	local cap = (avail and avail > 50) and avail or math.huge   -- before the first layout pass, width can read 0
	if toolsEnd > cap then toolsEnd = cap end
	self.toolsEnd = toolsEnd
	self:PlaceSearch()
	if self.LayoutTitleRow then self:LayoutTitleRow() end
end

-- (1.6.0) The toolbar's narrowest step: the Sort button without "Sort:", the Sections button naming the choice.
local SORT_NAME = { quality = "Quality", name = "Name", ilvl = "iLvl", newest = "Newest", oldest = "Oldest", off = "Off" }
function View:SyncSortLabel()
	local name = self.st.colSort and (ns.COL_LABEL[self.st.colSort.key] or "Item") or (SORT_NAME[self:Pref("sort")] or self:Pref("sort"))
	self.btnSort.label:SetText(((self.toolsLevel or 0) >= 4) and name or ("Sort: " .. name))
end
function View:SyncGrpMenu()
	local cur = self:Pref("grp")
	for _, it in ipairs(View.GRP_CHOICES) do if it[1] == cur then self.btnGrpMenu.label:SetText(it[2]) end end
	if self.btnMergeIcon then self.btnMergeIcon:SetActive(self:Pref("mergeStacks") and true or false) end
	if self.btnViewIcon then
		local list = self:Pref("view") == "list"
		self.btnViewIcon.tex:SetTexture("Interface\\AddOns\\BagSmith\\Media\\" .. (list and "ui-list.tga" or "ui-grid.tga"))
		self.btnViewIcon.tip = list and "List View" or "Icons View"
	end
end

-- (1.6.0-beta6) The header tooltip's line about columns a narrow window has set aside, or nil when none are.
function View:AsideText()
	local plan = self.columnPlan
	local d = plan and plan.dropped
	if not (d and #d > 0) then return nil end
	local names = {}
	for _, key in ipairs(d) do names[#names + 1] = ns.COL_LABEL[key] or key end
	return ("Set aside to fit: %s. Widen the window, or choose in Settings > %s."):format(table.concat(names, ", "), self.isBank and "Bank Columns" or "Bag Columns")
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
	local fold = self.btnSearchFold
	if fold and not (self:TravelOn() and self.searchFolded) then fold:Hide(); self.searchOpen = nil end
	if self:TravelOn() and self.searchFolded and fold then
		-- (1.9.0-beta4) folded: the icon where the search box would start; open, the box is its own row under the title
		fold:ClearAllPoints()
		if self.subText:IsShown() then fold:SetPoint("LEFT", self.subText, "RIGHT", 8, 0)
		else fold:SetPoint("LEFT", self.subText, "LEFT", 0, 0) end
		fold:Show(); if fold.SetActive then fold:SetActive(self.searchOpen and true or false) end
		if self.searchOpen then
			self.search:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 4 + (self.belowShift or 0), -2)
			self.search:SetPoint("TOPRIGHT", self.title, "BOTTOMRIGHT", 0, -2)
			self.search:SetHeight(22)
			self.search:Show()
		else
			self.search:Hide()
		end
	elseif self:TravelOn() then
		self.search:Show()
		-- The character picker is hidden in Travel Mode: search starts after the title. (1.5.5) It ends at Travel Mode's
		-- Collapse All Sections button when that shows, else at the broom.
		local T = self.btnLanesTravel
		-- (1.6.0-beta11) after the note while it shows, else where it would start (12 past the title either way)
		if self.subText:IsShown() then self.search:SetPoint("LEFT", self.subText, "RIGHT", 12, 0)
		else self.search:SetPoint("LEFT", self.subText, "LEFT", 4, 0) end
		if T and T:IsShown() then self.search:SetPoint("RIGHT", T, "LEFT", -6, 0)
		else self.search:SetPoint("RIGHT", self.btnClean, "LEFT", -8, 0) end
		self.search:SetHeight(22)
	else
		self.search:Show()
		local shift = self.belowShift or 0
		-- (1.5.2) The bank's title row is empty in Classic and collapsed, so its search row sits level with the portrait:
		-- there it starts at the title's left edge, clear of the portrait. Its right end stays with the Filter button.
		local left = (self.isBank and shift ~= 0) and 0 or shift
		self.search:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 4 + left, -2)
		self.search:SetPoint("TOPRIGHT", self.title, "BOTTOMLEFT", (self.toolsEnd or 400) - self.btnFilter:GetWidth() - 6 + shift, -2)
		self.search:SetHeight(TOOL_H)
	end
	-- (1.5.2) The toolbar row starts at the inner margin whatever the search box does (it used to hang from the search
	-- box's left edge, so moving the bank's search box moved every row below it).
	if self.tools then
		self.tools:ClearAllPoints()
		self.tools:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", self.belowShift or 0, -(2 + TOOL_H + 4))
		self.tools:SetPoint("TOPRIGHT", self.title, "BOTTOMRIGHT", 0, -(2 + TOOL_H + 4))
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
		-- (1.9.0-beta3, Shweep) no picker in Global Inventory: it already shows every character
		if self.charBtn then self.charBtn:SetShown(not on and not ns.ui.global) end
		if self.charReset then self.charReset:SetShown(not on and not ns.ui.global and ns.ui.owner ~= nil) end
		-- (1.9.0-beta2) The globe steps aside in Travel Mode, the divider closing the gap: Travel Mode's search keeps its
		-- room in the title row at 440 px. (Global Inventory turns Travel Mode off anyway; the folding search icon to come
		-- brings it back.)
		-- (1.9.0-beta4) the globe shows in Travel Mode again: the search folds into an icon when the row is too narrow
		if self.btnGlobal then
			self.btnGlobal:Show()
			self.titleDivider:ClearAllPoints()
			self.titleDivider:SetPoint("RIGHT", self.btnGlobal, "LEFT", -4, 0)
		end
		if ns.Classic and ns.Classic.SyncDropdown then ns.Classic.SyncDropdown(self) end
		if self.btnBagBar then self.btnBagBar:SetShown(self.st.sheet ~= "Bank" and not ns.ui.owner) end   -- stays in Travel Mode
		if self.btnLanesTravel then self.btnLanesTravel:SetShown(on and #(self.laneIds or {}) > 0) end   -- (1.5.5)
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
		local changed = self.travelShown ~= on
		self.travelShown = on
		self:UpdateTitle()
		-- (1.9.0-beta16) the header the list hangs from moved: checked as on opening
		if changed and self.frame:IsShown() and self.ScheduleListPlaced then self:ScheduleListPlaced() end
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


-- Fit to Items grows upwards: the sheet tabs/footer must not move when a
-- filter changes the height. Keep the horizontal anchor and relative point;
-- moving only our anchor down needs an offset in the frame's own coordinates
-- (the same units as GetHeight), even when UIParent has a different scale.
local function bottomAnchor(point)
	return point:find("LEFT") and "BOTTOMLEFT" or point:find("RIGHT") and "BOTTOMRIGHT" or "BOTTOM"
end
local function bottomPosition(p, height)
	if p[1]:find("BOTTOM") then return p end
	local shift = p[1]:find("TOP") and height or height / 2
	return { bottomAnchor(p[1]), "UIParent", p[3], p[4], p[5] - shift }
end

-- (1.7.3) Resizing drags the shared outline (Frames/Outline.lua); the window takes its size on release.
function View:StartOutlineResize()
	local minW = self.minWidth or View.MinWidthFor(self.isBank)
	-- (1.7.3-beta6, Shweep) the bags window's size is in Settings: an open panel shows the outline's size as it's dragged
	local onSize = self.isMain and function(w, h) self:ShowSizeInSettings(w, h) end or nil
	if not ns.Outline:Start(self.frame, minW, 300, 1400, 1200, onSize) then self.sizing = false; return end
	self.outline = ns.Outline.frame
end

-- The window takes the outline's size, its top-left corner staying where it was (as the client's own sizing from
-- the bottom-right corner did). The caller saves the size and place, then lays out once.
function View:EndOutlineResize()
	local f = self.frame
	local w, h, L, T = ns.Outline:Finish(f)
	if not w then return end
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", L, T)
	f:SetSize(w, h)
end

function View:CancelOutlineResize()
	if not ns.Outline:Active(self.frame) then return end
	ns.Outline:Cancel(self.frame)
	self:ShowSizeInSettings()   -- back to the saved size
end

-- (1.7.3-beta6) The Settings panel's Width and Height (Max Width and Max Height in Fit to Items) for the bags window:
-- with a size, show it (the drag in progress; nothing is saved); without, show the saved values again.
function View:ShowSizeInSettings(w, h)
	local P = ns.SettingsPanel
	if not (self.isMain and P and P.frame and P.frame:IsShown()) then return end
	if not w then P:Refresh(); return end
	local auto = ns.db.sizeMode == "auto"
	if P.ShowStepValue then
		P:ShowStepValue(auto and "maxW" or "fixW", math.floor(w + 0.5))
		P:ShowStepValue(auto and "maxH" or "fixH", math.floor(h + 0.5))
	end
end

function View:ApplySize()
	-- Native dragging owns size and position until the gesture is saved.
	if self.sizing or self.dragMoving then return end
	local f, db = self.frame, ns.db
	local w0, h0 = f.GetWidth and f:GetWidth(), f.GetHeight and f:GetHeight()
	f:SetScale(db.scale)
	if self.isMain then
		local mw, mh = self:SizeLimits()
		if db.sizeMode == "fixed" then f:SetSize(mw, mh) else
			local height = math.min(mh, self.autoHeight or mh)
			-- Convert old saved top/center anchors before changing height. On
			-- first use of a profile, use its full height like a fresh login:
			-- neither the frame nor autoHeight belongs to that profile yet.
			local oldHeight = self.sizeProfile == db and f:GetHeight() or 0
			local p = bottomPosition(db.point, oldHeight and oldHeight > 0 and oldHeight or mh)
			if p ~= db.point then ns:Set("point", p, true) end
			f:SetSize(mw, height)
		end
		f:ClearAllPoints()
		local p = db.point
		f:SetPoint(p[1], UIParent, p[3], p[4], p[5])
		self.sizeProfile = db
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
	self.grip:SetShown(self.big and not ns:WindowsLocked())   -- (1.7.0-beta2) no grip while Lock Windows is on
	self:ApplyMinWidth()   -- (1.6.0-beta7, R3) never narrower than the kept columns need
	-- (1.9.0-beta16) the main or bank window resized while open (Settings, Fit to Items, Global Inventory, a profile):
	-- the list area is checked as on opening (View:EnsureListPlaced)
	if self.big and w0 and h0 and f.IsShown and f:IsShown() and self.ScheduleListPlaced
		and (math.abs((f:GetWidth() or 0) - w0) > 0.5 or math.abs((f:GetHeight() or 0) - h0) > 0.5) then
		self:ScheduleListPlaced()
	end
end

-- (1.9.0-beta13, Shweep: "when you click Global can we pre-expand the window size ... and then leaving it bring it
-- back", "approx as tall as settings is, maybe a tad more", "you can go 750 for width") Global Inventory's own size
-- while it shows, when Resize for Global Inventory is on: the size you last gave it there (saved for the account),
-- else 750 wide and 620 tall. In Fit to Items it's the largest size, as maxW/maxH. (beta14) Settings > Windows shows
-- and sets the two (Width, Height), so they always decide: no more "a wider window keeps its width".
View.GLOBAL_W, View.GLOBAL_H = 750, 620
function View:GlobalSize()
	if not (self.isMain and ns.ui and ns.ui.global and ns.db and ns.db.globalResize and ns.Inventory) then return nil end
	local G = ns.Inventory:Settings()
	return G.w or View.GLOBAL_W, G.h or View.GLOBAL_H
end
-- The main window's width and height (its largest, in Fit to Items) as they stand: Global Inventory's, or the bags'.
function View:SizeLimits()
	local gw, gh = self:GlobalSize()
	if gw then return gw, gh end
	local db = ns.db
	if db.sizeMode == "fixed" then return db.fixW, db.fixH end
	return db.maxW, db.maxH
end

function View:SavePosition()
	local point, _, rel, x, y = self.frame:GetPoint(1)
	if not point then return end
	local p = { point, "UIParent", rel, math.floor(x + 0.5), math.floor(y + 0.5) }
	if self.isMain and ns.db.sizeMode == "auto" then
		p = bottomPosition(p, self.frame:GetHeight())
		self.frame:ClearAllPoints()
		self.frame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
	end
	if self.isMain then ns:Set("point", p, true)
	elseif self.isBank then ns:Set("bankPoint", p, true)
	elseif self.kind == "bag" then ns.db.bagPoints[tostring(self.opts.bags[1])] = p end
end


------------------------------------------------------------------------
-- Chrome: title, tools, tabs, footer
------------------------------------------------------------------------
-- The title in its longest form first, then shorter ones for a narrow window (1.6.0): Travel Mode's "(Travel Mode)" goes
-- first (the lit signpost still says so), then "Bank (Saved)" becomes "Bank". (The bags' own title is "Bags" since 1.9.0-beta2.)
function View:TitleForms()
	if self.isBank then return { "Bank" } end
	if not self.isMain then return { self.opts.title or "" } end
	if ns.ui.global then return { "Global Inventory", "Global Inv" } end   -- (1.9.0-beta2, Shweep's names)
	local saved = self.st.sheet == "Bank"
	-- (1.9.0-beta2, Shweep) "Bags", no longer "Your Bags": room in the title row for the globe
	local base, short = saved and "Bank (Saved)" or "Bags", saved and "Bank" or "Bags"
	if self:TravelOn() then return base == short and { base .. " (Travel Mode)", base } or { base .. " (Travel Mode)", base, short } end
	return base == short and { base } or { base, short }
end
function View:UpdateTitle()
	local title = self:TitleForms()[1]
	self.titleText:SetText(title)
	if self.classicApplied and self.classicTitle then self.classicTitle:SetText(title); self.titleText:SetText("") end
	if self.isMain then self:PlaceSearch(); self:LayoutTitleRow() end
end

-- (1.6.0) The title row of the bags window, fitted to a narrow window. The icons at its right end never move; what's left
-- of them gives way in this order: the character picker narrows (170 px down to 110), the title shortens (TitleForms),
-- and the note after the title ("12 of 80 shown") is cut short, or hidden when there's no room for it at all. In Travel
-- Mode the search box sits in this row and keeps at least SEARCH_MIN.
local PICKER_W, PICKER_MIN, SEARCH_MIN = 170, 110, 120
View.TITLE_FIT = { PICKER_W = PICKER_W, PICKER_MIN = PICKER_MIN, SEARCH_MIN = SEARCH_MIN }
-- (1.6.0-beta11) how far the picker's level sits from its right edge: clear of Modern's small chevron, and of Classic's
-- larger dropdown arrow (Shweep's screenshot: the level ran under it); Classic sets its own (Frames/Classic.lua)
View.PICKER_ARROW, View.PICKER_ARROW_CLASSIC = 18, 28
-- How far the left edge of f sits from the title row's right edge, following its RIGHT-to-LEFT anchors back to the row.
local function fromRight(f, title, depth)
	depth = depth or 0
	if not f or depth > 16 then return nil end
	local p, rel, rp, x = f:GetPoint(1)
	if type(rel) ~= "table" then rel, rp, x = (f.GetParent and f:GetParent()) or title, p, rel end   -- ("RIGHT", x, y)
	if p ~= "RIGHT" then return nil end
	local base
	if rel == title and rp == "RIGHT" then base = 0
	elseif rp == "LEFT" then base = fromRight(rel, title, depth + 1) end
	if not base then return nil end
	return base - (tonumber(x) or 0) + (f:GetWidth() or 0)
end
View.FromRight = fromRight
local function textWidth(fs)
	if fs.GetUnboundedStringWidth then return fs:GetUnboundedStringWidth() or 0 end
	return fs:GetStringWidth() or 0
end
-- (1.6.0-beta11, Shweep's screenshots) What comes after the note (the picker; in Travel Mode the search box) follows it
-- only while it shows. A hidden note keeps its width, so at the narrowest width the picker and its X slid over the icons
-- when viewing another character, and Travel Mode's search box shrank while searching ("1 of 13 shown").
function View:FollowNote()
	local shown = self.subText and self.subText:IsShown()
	if self.charBtn then
		self.charBtn:ClearAllPoints()
		if shown then self.charBtn:SetPoint("LEFT", self.subText, "RIGHT", 10, 0)
		else self.charBtn:SetPoint("LEFT", self.subText, "LEFT", 2, 0) end   -- (the note starts 8 past the title: 10 in all)
	end
	if self:TravelOn() then self:PlaceSearch() end
end
-- (1.9.0-beta3, Shweep: "shortened last names regardless of width") The picker's name in full when it fits beside the
-- class icon and the level; otherwise the surname as its initial ("Shweepy T."), cut short with "..." if even that
-- doesn't fit.
-- (1.9.0-beta4) Travel Mode's folded search: open (its own row under the title, focused) or closed.
function View:OpenTravelSearch(on)
	if not (self.search and self.searchFolded) then return end
	if not on and (self.search:GetText() or "") ~= "" then on = true end   -- a search in use stays open
	self.searchOpen = on and true or nil
	self:PlaceSearch(); self:PlaceHeader()
	if on and self.search.SetFocus then self.search:SetFocus() end
	ns:RefreshViews(true)
end
function View:FitPickerName()
	local b = self.charBtn
	if not (b and b.label and b.fullName) then return end
	local full = b.fullName
	local inset = (self.classicApplied and self.classicDropdown) and View.PICKER_ARROW_CLASSIC or View.PICKER_ARROW
	local levelW = self.charLevel and textWidth(self.charLevel) or 0
	local room = (b:GetWidth() or 0) - 6 - 14 - 5 - levelW - inset - 5
	b.label:SetText(full)
	if room > 0 and textWidth(b.label) > room then b.label:SetText(ns.ShortName(full) or full) end
end
function View:LayoutTitleRow()
	if not (self.isMain and self.title and self.titleText) then return end
	local avail = self.title:GetWidth() or 0
	local forms = self:TitleForms()
	local classic = self.classicApplied and self.classicTitle and true or false
	local travel = self:TravelOn()
	local T = self.btnLanesTravel
	local edge = (travel and T and T:IsShown()) and T or self.btnClean
	local right = edge and fromRight(edge, self.title)
	self.titleFit = nil
	if avail <= 50 or not right then
		-- Not laid out yet (a window built while closed): the full forms, as before.
		if not classic then self.titleText:SetText(forms[1]) end
		if self.charBtn then self.charBtn:SetWidth(PICKER_W) end
		self.subText:SetWidth(0); self.subText:Show()
		return
	end
	local lead = classic and 2 or (16 + 6)   -- the mark and its gap (Modern); Classic's note starts at the row's edge
	local subW = textWidth(self.subText)
	local picker = (not travel) and self.charBtn and self.charBtn:IsShown()
	local reset = (picker and self.charReset and self.charReset:IsShown()) and (2 + self.charReset:GetWidth()) or 0
	-- What the row must keep after the note: the picker at its narrowest, or Travel Mode's search box.
	local tail = travel and (12 + SEARCH_MIN + 8) or (picker and (10 + PICKER_MIN + reset) or 0)
	local room = avail - right - 8
	-- (1.9.0-beta4, Shweep) Travel Mode: if even the shortest title leaves no room for the search box, it folds into an icon
	local folded = false
	if travel then
		local shortest = classic and 0 or (function() self.titleText:SetText(forms[#forms]); return textWidth(self.titleText) + 8 end)()
		if lead + shortest + tail > room then folded = true; tail = 8 + 24 + 8 end
	end
	if folded ~= (self.searchFolded == true) then
		self.searchFolded = folded or nil
		if not folded then self.searchOpen = nil end
		self:PlaceSearch(); self:PlaceHeader()
	end
	local function titleW(form)
		if classic then return 0 end
		self.titleText:SetText(form)
		return textWidth(self.titleText) + 8
	end
	local chosen, tw = #forms, 0
	for i, form in ipairs(forms) do
		tw = titleW(form)
		if lead + tw + subW + tail <= room then chosen = i; break end
	end
	if chosen == #forms then tw = titleW(forms[#forms]) end
	local subRoom = room - lead - tw - tail
	if subW <= subRoom then
		self.subText:SetWidth(0); self.subText:Show()
	elseif subRoom >= 24 then
		self.subText:SetWidth(subRoom); self.subText:SetWordWrap(false); self.subText:Show()
		subW = subRoom
	else
		self.subText:Hide(); subW = 0
	end
	local pw
	if picker then
		pw = math.max(PICKER_MIN, math.min(PICKER_W, math.floor(room - lead - tw - subW - 10 - reset)))
		self.charBtn:SetWidth(pw)
	elseif self.charBtn then
		self.charBtn:SetWidth(PICKER_W)
	end
	self:FollowNote()
	self:FitPickerName()
	if not classic then self.titleText:SetText(forms[chosen]) end
	self.titleFit = { form = chosen, picker = pw, sub = self.subText:IsShown() and subW or nil, room = room, right = right }
end

function View:UpdateChrome(shown, total, bagInfo, cached)
	local s = Skins:Current()
	self:UpdateTitle()
	local title = self.opts.title
	if not self.big and ns.Classic then ns.Classic:Retitle(self.frame, title, ns.Classic.BagIcon(self)) end
	local sub = ""
	if ns.ui.owner then
		local data = BagSmithDB.cache[ns.ui.owner]
		sub = "read only"   -- (1.6.0-beta11, Shweep) the picker already says whose bags these are
		if self.st.sheet == "Bank" then sub = sub .. ", saved bank" end
	elseif self.st.sheet == "Bank" and self.isMain then
		sub = "saved view"
	elseif self.isBank then
		sub = ns.atBank and "" or "saved view"
	end
	-- (1.9.0-beta8, Shweep: the value note "is getting lost ... hard to understand") Global Inventory's worth is its Total
	-- row now (UpdateTotalRow), under the Vendor and AH Price columns; the title keeps only "N of M shown"
	local shownNote = #shown ~= total and ("%d of %d shown"):format(#shown, total) or nil
	-- (1.10.0-beta4) the Filters window says the same under its rules
	if ns.Popups and ns.Popups.UpdateCount then ns.Popups:UpdateCount(self, #shown, total) end
	if shownNote then sub = (sub ~= "" and sub .. ", " or "") .. shownNote end
	self.subText:SetText(sub)
	if self.charBtn then
		local data = ns.ui.owner and BagSmithDB.cache[ns.ui.owner] or BagSmithDB.cache[ns:CharKey()]
		local name, class, level = data and data.name or ns:DisplayName("player"), data and data.class, data and data.level or UnitLevel("player")
		if not class then local _, c = UnitClass("player"); class = c end
		-- (1.9.0-beta2, Shweep) a surname as its initial ("Shweepy T.") when the full name doesn't fit (beta3: only then)
		self.charBtn.fullName = name or "?"
		self:FitPickerName()
		self.charBtn.label:SetTextColor(ns.ClassColor(class))
		if self.charLevel then self.charLevel:SetText(tostring(level or 0)) end
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
			-- (1.9.0-beta4, Shweep) greyed out in Global Inventory: your character's sets
			local gbl = self.isMain and ns.ui.global
			self.btnGearSets.baseTip = self.btnGearSets.baseTip or self.btnGearSets.tip
			View.GlobalOff(self.btnGearSets, gbl, "Gear Sets", View.GLOBAL_WHY.gearSets)
			self:RefreshToolbar()
		end
		self.btnFilter:SetActive(ns.FilterCount(self.st.filters) > 0)
		self.btnFilter.label:SetText(ns.FilterCount(self.st.filters) > 0 and ("Filter (%d)"):format(ns.FilterCount(self.st.filters)) or "Filter")
	end
	if self.isMain then self:LayoutTitleRow() end   -- (1.6.0) the note and picker just changed
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
	-- (1.9.0-beta3, Shweep) and in Global Inventory
	local browsing = (ns.ui.owner or (self.isMain and ns.ui.global)) and not self.isBank
	local gbl = self.isMain and ns.ui.global and true or false
	for _, b in ipairs({ self.btnBags, self.btnReagent }) do
		if b and b.isCount then
			b.baseTip = b.baseTip or b.tip
			View.GlobalOff(b, gbl, b == self.btnReagent and "Reagent Bag Window" or "Bag Windows", View.GLOBAL_WHY.bagWindows)
			if gbl then
				b.tip = b.baseTip   -- (beta5) its reason is GlobalOff's
			elseif browsing then
				b:Disable(); b:SetAlpha(0.45)
				b.tip = "Bag windows show your own bags. Switch back to your character to open them."
			else
				b:Enable(); b:SetAlpha(1)
				b.tip = b.baseTip
			end
		end
	end
	-- (1.9.0-beta4, Shweep) the bag bar's button in Global Inventory: there, greyed out, saying why (its strip stays hidden)
	local bb = self.btnBagBar
	if bb then
		View.GlobalOff(bb, gbl, "Bag Bar", View.GLOBAL_WHY.bagBar)
	end
	-- (1.9.0-beta5, Shweep) Merge Stacks and Icons greyed in Global Inventory, saying why
	if self.btnMerge then
		self.btnMerge:SetActive(not gbl and self:Pref("mergeStacks")); self.btnMerge.label:SetText((self.toolsLevel or 0) >= 2 and "Merge" or "Merge Stacks")
		View.GlobalOff(self.btnMerge, gbl, "Merge Stacks", View.GLOBAL_WHY.merge)
	end
	View.GlobalOff(self.btnMergeIcon, gbl, "Merge Stacks", View.GLOBAL_WHY.merge)
	for _, b in ipairs(self.viewSegBtns or {}) do
		View.GlobalOff(b, gbl and b.value == "icons", "Icons View", View.GLOBAL_WHY.icons)
	end
	-- (1.9.0-beta17) and By Bag (Global Inventory shows By Bag as By Section)
	for _, b in ipairs(self.grpSegBtns or {}) do
		View.GlobalOff(b, gbl and b.value == "bag", "By Bag", View.GLOBAL_WHY.byBag)
	end
	View.GlobalOff(self.btnViewIcon, gbl, "Icons View", View.GLOBAL_WHY.icons)
	if self.btnReagent then self.btnReagent:SetActive(sr and true or false) end
	self:SyncSortLabel()
	if self.btnGrpMenu then self:SyncGrpMenu() end
	self.btnSort:SetActive(self.st.colSort ~= nil)
	local ids, collapsedSet = self.laneIds or {}, {}
	for _, id in ipairs(self:CollapsedList()) do collapsedSet[id] = true end
	local all = #ids > 0
	for _, id in ipairs(ids) do if not collapsedSet[id] then all = false end end
	self.btnLanes.tex:SetTexture("Interface\\AddOns\\BagSmith\\Media\\" .. (all and "ui-expand.tga" or "ui-collapse.tga"))
	self.btnLanes.tip = all and "Expand All Sections" or "Collapse All Sections"
	self.btnLanes:SetShown(#ids > 0)
	local T = self.btnLanesTravel
	if T then
		T.tex:SetTexture("Interface\\AddOns\\BagSmith\\Media\\" .. (all and "ui-expand.tga" or "ui-collapse.tga"))
		T.tip = self.btnLanes.tip
		local show = self:TravelOn() and #ids > 0
		if T:IsShown() ~= show then T:SetShown(show); self:PlaceSearch() end
	end
end

-- (1.6.0-beta5, Shweep) The sheet tabs keep to one row in both skins (Classic's hang below the window, where a second
-- row looked broken). They fit first: Classic's tabs trim their padding and overlap a little, like Blizzard's. Tabs that
-- still don't fit fold into a "»" tab whose menu lists them, with New Sheet... at the bottom (the "+" steps aside while
-- anything is folded). The tab you're on always stays in view: if it would fold, it takes the last place that fits.
View.TAB_MORE_W = 30
-- (1.8.0-beta13, Shweep; learned from Guildy) Classic tabs overlap like the game's (14 px, was 2): each tab's frame is
-- this much wider, half on each side, so labels, the row's length and folding stay exactly as they were; the shaded
-- ends of the game's tab art tuck under their neighbors. The row's outer ends are trimmed (Classic.TrimTabEnds).
-- (1.8.0-beta14, Shweep: "the tabs look terrible, regardless of width") Off again: the copied art overlapping its
-- neighbor crowded the labels. Kept at 0 (beta12's layout) while the shading is examined (Classic.TabArtReport).
View.CLASSIC_TAB_EXTRA = 0
function View:TabPlan(widths, avail, current, endRoom, pencilRoom)
	-- widths: { id, w } in order; endRoom: what the + and the pencil need after the tabs; pencilRoom: the pencil alone
	-- (it stays while folding, for the current custom sheet). Returns the ids shown and the ids folded, each in order.
	-- step: the distance between one tab's right edge and the next one's left (Classic's overlap a little).
	local step = self.classicApplied and -2 or 2
	local total = 0
	for _, t in ipairs(widths) do total = total + t.w + step end
	if total + endRoom <= avail then
		local all = {}; for _, t in ipairs(widths) do all[#all + 1] = t.id end
		return all, {}
	end
	-- Folding: the "»" tab and the pencil (for the current custom sheet) stay; the + goes into the menu.
	local room = avail - (View.TAB_MORE_W + step) - (pencilRoom or 0)
	local shown, folded, x = {}, {}, 0
	for _, t in ipairs(widths) do
		if #folded == 0 and x + t.w + step <= room then shown[#shown + 1] = t; x = x + t.w + step
		else folded[#folded + 1] = t end
	end
	-- the current tab must be in view: it replaces shown tabs from the end until it fits
	local curFolded
	for i, t in ipairs(folded) do if t.id == current then curFolded = i end end
	if curFolded then
		local cur = table.remove(folded, curFolded)
		while #shown > 0 and x + cur.w + step > room do
			local t = table.remove(shown)
			x = x - t.w - step
			table.insert(folded, 1, t)
		end
		shown[#shown + 1] = cur
		-- folded tabs keep their own order
		local order = {}; for i, t in ipairs(widths) do order[t.id] = i end
		table.sort(folded, function(p, q) return order[p.id] < order[q.id] end)
	end
	local s, f = {}, {}
	for _, t in ipairs(shown) do s[#s + 1] = t.id end
	for _, t in ipairs(folded) do f[#f + 1] = t.id end
	return s, f
end
function View:UpdateTabs()
	-- Row height: Blizzard's tabs are taller in Classic. Everything is still
	-- created at its Modern size; only this pass's layout uses rowH.
	local rowH = self.classicApplied and 30 or TAB_H
	local db = ns.db
	local hidden = {}
	-- (1.9.0-beta6, Shweep: Global Sheets) Global Inventory's own tabs: the built-in ones, its own choice and order
	local G = self.isMain and ns.ui.global and ns.Inventory and ns.Inventory:Settings()
	for _, t in ipairs(G and G.hiddenTabs or (self.isBank and db.bankHiddenTabs or db.hiddenTabs)) do hidden[t] = true end
	-- No equipment sets on this client: no Gear Sets tab.
	if not (ns.GearSets and ns.GearSets:Available()) then hidden.GearSets = true end
	-- (1.9.0-beta5, Shweep: "Can we show Gear Sets tab just disabled?") in Global Inventory: shown, greyed (beta4 hid it)
	local gbl = self.isMain and ns.ui.global and true or false
	local order = G and G.tabOrder or (self.isBank and db.bankTabOrder or db.tabOrder)
	-- Each tab's width: its label plus padding (Classic's art needs less than it had: 12 px, not 16).
	self.tabMeasure = self.tabMeasure or self.tabs:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	local pad = self.classicApplied and 12 or 16
	local widths, labels = {}, {}
	for _, id in ipairs(order) do
		if not hidden[id] then
			local label = ns.TAB_LABEL[id] or id
			labels[id] = label
			self.tabMeasure:SetText(label)
			widths[#widths + 1] = { id = id, w = math.min(160, math.max(40, (self.tabMeasure:GetStringWidth() or 0) + pad)) }
		end
	end
	self.tabMeasure:SetText("")

	-- Plus: new sheet from the Filter panel. Pencil: edit the selected custom
	-- sheet. Modern uses small icon buttons (sized on every pass, so a size
	-- from Classic can never stick); Classic uses tab-style ones.
	if not self.tabAdd then
		self.tabAdd = iconButton(self.tabs, "Interface\\AddOns\\BagSmith\\Media\\ui-plus.tga", "New sheet: save a search and filters as a tab", function() ns.Popups:OpenFilters(self, "new") end)
		self.tabAdd.tex:SetSize(12, 12)
		self.tabEdit = iconButton(self.tabs, "Interface\\AddOns\\BagSmith\\Media\\ui-pencil.tga", "Edit this sheet: rename, change its filters, or delete it", function() ns.Popups:OpenFilters(self, "edit", self.st.sheet) end)
		self.tabEdit.tex:SetSize(13, 13)
	end
	-- (1.6.0-beta5) the "»" tab: the tabs that don't fit, and New Sheet...
	if not self.tabMore then
		self.tabMore = textButton(self.tabs, "\194\187", View.TAB_MORE_W, function(b)
			local items = {}
			for _, id in ipairs(self.tabFolded or {}) do
				items[#items + 1] = { text = ns.TAB_LABEL[id] or id, checked = self.st.sheet == id, onClick = function() self:SetSheet(id) end }
			end
			if not (self.isMain and ns.ui.global) then items[#items + 1] = { text = "New Sheet...", gap = true, onClick = function() ns.Popups:OpenFilters(self, "new") end } end
			ns.ShowMenu(items, b)
		end)
		self.tabMore.tip = "More Sheets"
		self.tabMore.label:SetFontObject(faceFont())   -- (1.9.0-beta19)
		self.tabMore.tipSub = "The tabs that don't fit, and New Sheet..."
	end
	local addBtn, editBtn = self.tabAdd, self.tabEdit
	if self.classicApplied then
		if not self.tabAddTab then
			self.tabAddTab = textButton(self.tabs, "+", 34, function() ns.Popups:OpenFilters(self, "new") end)
			self.tabAddTab.tip = self.tabAdd.tip
			self.tabAddTab.label:SetFontObject(faceFont())   -- (1.9.0-beta19)
			self.tabAddTab:SetClassic(true, ns.Classic.TabTemplate())
			self.tabEditTab = textButton(self.tabs, "", 34, function() ns.Popups:OpenFilters(self, "edit", self.st.sheet) end)
			self.tabEditTab.tip = self.tabEdit.tip
			self.tabEditTab.label:SetFontObject(faceFont())   -- (1.9.0-beta19)
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
	local more = self.tabMore
	if self.classicApplied and not more.classicOn then more:SetClassic(true, ns.Classic.TabTemplate()) end
	if not self.classicApplied and more.classicOn then more:SetClassic(false) end
	more:SetHeight(rowH - 2)
	if more.classicOn and ns.Classic and ns.Classic.FitTabArt then ns.Classic.FitTabArt(more) end

	local aw, ew = addBtn:GetWidth(), editBtn:GetWidth()
	if self.classicApplied then aw, ew = 34, 34 end   -- (1.8.0-beta13) their own width, not the wider overlapping frame
	local isCustom = not ns.TAB_LABEL[self.st.sheet]
	local avail = self.tabs:GetWidth()
	local pencil = isCustom and (ew + 2) or 0
	local shown, folded
	if avail and avail > 50 then
		shown, folded = self:TabPlan(widths, avail, self.st.sheet, (aw + 4) + pencil, pencil)
	else
		shown, folded = {}, {}
		for _, t in ipairs(widths) do shown[#shown + 1] = t.id end
	end
	self.tabFolded = folded
	local wOf = {}; for _, t in ipairs(widths) do wOf[t.id] = t.w end
	local step = self.classicApplied and -2 or 2
	local extra = self.classicApplied and View.CLASSIC_TAB_EXTRA or 0   -- (1.8.0-beta13)
	local half = extra / 2
	local base = (self.tabs.GetFrameLevel and self.tabs:GetFrameLevel() or 0) + 1
	local laid = {}   -- the Classic tab-art buttons in this row, left to right
	local x, i, row = 0, 0, 0   -- one row (row stays 0: the offsets are written as before, so layouts compare unchanged)
	for _, id in ipairs(shown) do
		i = i + 1
		local b = self.tabButtons[i]
		if not b then
			b = textButton(self.tabs, "", 60, function(btn) self:SetSheet(btn.sheet) end)
			b.label:SetFontObject(faceFont())   -- (1.9.0-beta19)
			b:SetHeight(TAB_H - 2)
			if self.classicApplied then b:SetClassic(true, ns.Classic.TabTemplate()) end
			b:RegisterForDrag("LeftButton")
			-- (1.9.0-beta6) not in Global Inventory: its tab order is set in Settings > Sheets > Global Sheets
			b:SetScript("OnDragStart", function(btn) if self.isMain and ns.ui.global then return end ns.dragTab = btn.sheet; btn:SetAlpha(0.5) end)
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
		local w = wOf[id]
		b.sheet = id
		b.label:SetText(labels[id])
		b.label:ClearAllPoints(); b.label:SetPoint("CENTER"); b.label:SetWordWrap(false)
		b.label:SetWidth(w - 12)
		b:SetWidth(w + extra)
		if b.classicOn and ns.Classic and ns.Classic.FitTabEnds then ns.Classic.FitTabEnds(b) end   -- (1.8.0-beta15)
		b:ClearAllPoints(); b:SetPoint("TOPLEFT", self.tabs, "TOPLEFT", x - half, -row * rowH)
		b:SetActive(self.st.sheet == id)
		View.GlobalOff(b, gbl and id == "GearSets", "Gear Sets", View.GLOBAL_WHY.gearSets)
		-- (1.8.0-beta13) overlapping: the selected tab draws above its neighbors, as the game's does
		if extra > 0 and b.SetFrameLevel then b:SetFrameLevel(self.st.sheet == id and base + 2 or base) end
		b:Show()
		if b.classicOn then laid[#laid + 1] = b end
		x = x + w + step
	end
	for j = i + 1, #self.tabButtons do self.tabButtons[j]:Hide() end
	if self.tabs:GetHeight() ~= rowH then self.tabs:SetHeight(rowH) end   -- one row, always (1.6.0-beta5)

	-- (1.8.0-beta13) in Classic the », + and pencil tabs overlap the same way: wider by `extra`, half on each side
	local function place(btn, at, w)
		if btn.classicOn and ns.Classic and ns.Classic.FitTabEnds then ns.Classic.FitTabEnds(btn) end   -- (1.8.0-beta15)
		if extra > 0 and btn.classicOn then
			btn:SetWidth(w + extra)
			btn:ClearAllPoints(); btn:SetPoint("TOPLEFT", self.tabs, "TOPLEFT", at - half, -row * rowH)
			if btn.SetFrameLevel then btn:SetFrameLevel(base) end
			laid[#laid + 1] = btn
		else
			btn:ClearAllPoints(); btn:SetPoint("TOPLEFT", self.tabs, "TOPLEFT", at, -row * rowH)
		end
	end
	local moreW, addW, editW = View.TAB_MORE_W, self.classicApplied and 34 or aw, self.classicApplied and 34 or ew
	if #folded > 0 then
		place(more, x, moreW)
		more:SetActive(false); more:Show()
		x = x + moreW + step
		addBtn:Hide()
	else
		more:Hide()
		-- (1.9.0-beta6) Global Inventory shows the built-in tabs only: no New Sheet there
		if G then addBtn:Hide() else
			place(addBtn, x + 2, addW); addBtn:Show()
			x = x + addW + 4
		end
	end
	editBtn:SetShown(isCustom)
	if isCustom then place(editBtn, x, editW) end
	-- (1.8.0-beta13) the row's outer ends have no neighbor to tuck under: their shaded ends are trimmed; every other
	-- end gets its art back (a tab can move from the end to the middle)
	if extra > 0 and ns.Classic and ns.Classic.TrimTabEnds then
		for k, btn in ipairs(laid) do
			ns.Classic.TrimTabEnds(btn, k == 1 and half + 1 or 0, k == #laid and half + 1 or 0)
		end
	end
end

-- (1.8.0-beta5) The Bags button's tooltip: free slots in ordinary bags, then each kind of special bag (its name in its
-- indicator color).
-- (beta10 feedback, Shweep: "not seeing that") Always shown, not only with special bags: the general slots, the
-- reagent bag's when there is one, then each special bag's.
function View:FreeTip()
	-- (1.9.0-beta4) Global Inventory: each character's free slots, then the total
	if self.isMain and ns.ui.global and ns.Inventory then
		local free, total, list = ns.Inventory:FreeSlots(ns.Inventory:Settings().allRealms)
		return function(tt, help)
			if help then tt:AddLine(" ") end
			if help then tt:AddLine("Free slots", 1, 0.82, 0) else ns.TipText(tt, "Free slots", 1, 0.82, 0) end
			for _, c in ipairs(list) do
				local r, g, b = ns.ClassColor(c.class)
				tt:AddDoubleLine(ns.Inventory.ClassIcon(c.class) .. (c.name or "?"), ("%d / %d"):format(c.free, c.total), r, g, b, 1, 1, 1)
			end
			tt:AddDoubleLine("Total", ("%d / %d"):format(free, total), 1, 0.82, 0, 1, 1, 1)
		end
	end
	local special = self.freeSpecial or {}
	local g = self.freeGeneral
	if not g then return nil end
	local reagent = self.freeReagent
	return function(tt, help)
		if help then tt:AddLine(" ") end
		if help then tt:AddLine("Free slots", 1, 0.82, 0) else ns.TipText(tt, "Free slots", 1, 0.82, 0) end
		tt:AddDoubleLine("Bags (anything fits)", ("%d / %d"):format(g[1], g[2]), 1, 1, 1, 1, 1, 1)
		if reagent then
			local r, gg, b = ns:BagKindColor("reagent")
			tt:AddDoubleLine(ns:BagKindName("reagent"), ("%d / %d"):format(reagent[1], reagent[2]), r, gg, b, 1, 1, 1)
		end
		for _, k in ipairs(ns:BagKindsSorted()) do   -- (beta7 feedback) alphabetical, as in Settings
			local v = special[k.key]
			if v then
				local r, gg, b = ns:BagKindColor(k.key)
				tt:AddDoubleLine(ns:BagKindName(k.key), ("%d / %d"):format(v.free, v.total), r, gg, b, 1, 1, 1)
			end
		end
	end
end

-- (1.9.0-beta8) The footer's frame for the skin and Footer Text Size: taller as its text grows (the tabs above move up
-- with it), and in Modern its contents 6 px lower, the line and tabs where they were. Classic keeps it as built (its
-- gold bar hangs from the footer; its tabs from the window).
function View:LayoutFooter()
	local footer = self.footer
	if not footer then return end
	local h = ns.Fonts and ns.Fonts:FooterGrow(FOOTER_H) or FOOTER_H
	local drop = self.classicApplied and 0 or FOOTER_DROP
	local key = h .. ":" .. drop
	if self.footerKey ~= key then
		self.footerKey = key
		footer:ClearAllPoints()
		footer:SetPoint("BOTTOMLEFT", PAD, PAD - drop); footer:SetPoint("BOTTOMRIGHT", -PAD, PAD - drop)   -- (as built: to its parent)
		footer:SetHeight(h)
		footer.line:ClearAllPoints()
		footer.line:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, drop); footer.line:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, drop)
		if self.tabs and not self.classicApplied then
			self.tabs:ClearAllPoints()
			self.tabs:SetPoint("BOTTOMLEFT", PAD, PAD + h + 2); self.tabs:SetPoint("BOTTOMRIGHT", -PAD, PAD + h + 2)
		end
	end
	local bh = ns.Fonts and ns.Fonts:FooterGrow(20) or 20
	for _, b in ipairs({ self.btnBags or false, self.btnReagent or false, self.btnBagBar or false }) do
		if b and b:GetHeight() ~= bh then b:SetHeight(bh) end
	end
end

function View:UpdateFooter(bagInfo)
	self:LayoutFooter()
	-- Footer-only updates (money, currency) pass no bag details: reuse the last
	-- full refresh's, so saved free-slot counts don't drop to 0/0.
	if bagInfo then self.footerBagInfo = bagInfo else bagInfo = self.footerBagInfo end
	local s = Skins:Current()
	local owner = ns.ui.owner
	local gold = owner and (BagSmithDB.cache[owner] and BagSmithDB.cache[owner].gold or 0) or GetMoney()
	-- (1.9.0-beta4) Global Inventory: this ruleset's gold (every ruleset's with Other Rulesets)
	local global = self.isMain and ns.ui.global and ns.Inventory
	if global then gold = select(2, ns.Inventory:Gold(ns.Inventory:Settings().allRealms)) end
	self.moneyText:SetText(GetMoneyString(gold or 0, true))

	-- Free slots. (1.8.0-beta5) Special bags (a quiver, a herb bag, ...) count apart: the number is the slots anything
	-- fits in, and the Bags button's tooltip lists the rest by kind. Saved data (another character, the bank away from
	-- it) carries each bag's kind from 1.8.0 on; older saves count every bag as general until that character logs in.
	local free, total, rfree, rtotal, special = 0, 0, 0, 0, nil
	local function addSpecial(kind, f, t)
		special = special or {}
		local k = special[kind] or { free = 0, total = 0 }
		k.free, k.total = k.free + (f or 0), k.total + (t or 0)
		special[kind] = k
	end
	if owner then
		for bag, info in pairs(bagInfo or {}) do
			if info.reagent then rfree, rtotal = rfree + (info.free or 0), rtotal + (info.size or 0)
			elseif bag ~= ns.KEYRING and info.kind and ns.BAG_KIND[info.kind] then addSpecial(info.kind, info.free, info.size)
			elseif bag ~= ns.KEYRING then free, total = free + (info.free or 0), total + (info.size or 0) end
		end
	elseif (self.isMain and self.st.sheet == "Bank") or (self.isBank and not ns.atBank) then
		for _, info in pairs(bagInfo or {}) do
			if info.kind and ns.BAG_KIND[info.kind] then addSpecial(info.kind, info.free, info.size)
			else free, total = free + (info.free or 0), total + (info.size or 0) end
		end
	else
		free, total, rfree, rtotal, special = ns:FreeSlots(self.kind == "main" and self.st.sheet ~= "Bank" and ns.BAGS or self:Bags())
	end
	if (self.isMain and self.st.sheet == "Bank") or self.isBank then rtotal = 0 end
	-- (1.9.0-beta4) Global Inventory: your characters' free slots together (as Bag Slot Count counts them)
	if global then
		free, total = ns.Inventory:FreeSlots(ns.Inventory:Settings().allRealms)
		rfree, rtotal, special = 0, 0, nil
	end
	self.freeSpecial = special
	self.freeReagent = rtotal > 0 and { rfree, rtotal } or nil   -- (beta11) for the tooltip
	-- A window showing only the reagent bag reports the reagent slots; one showing only special bags, theirs.
	if total == 0 and rtotal > 0 then free, total = rfree, rtotal
	elseif total == 0 and special then
		for _, k in pairs(special) do free, total = free + k.free, total + k.total end
		special, self.freeSpecial = nil, nil
	end
	-- (1.9.0-beta1, Shweep) Bag Slot Count: All Free Slots counts the special bags' room in the number too (the tooltip
	-- still lists it by kind, and there's no "+")
	local plus = special ~= nil
	if special and ns.db and ns.db.bagSlotCount == "all" then
		for _, k in pairs(special) do free, total = free + k.free, total + k.total end
		plus = false
	end
	self.freeGeneral = { free, total }
	local txt = ("%d / %d"):format(free, total)
	if free <= 0 then txt = "|cfff09595" .. txt .. "|r" elseif free <= 4 then txt = "|cfffac775" .. txt .. "|r" end
	-- a quiet "+": there's more room in special bags (the tooltip says where)
	if plus and not self.titleCount then txt = txt .. " |cff9d9d9d+|r" end
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
			chip.text = fontString(chip, footerFont()); chip.text:SetPoint("LEFT", chip.icon, "RIGHT", 4, 0)
			chip:SetScript("OnClick", function() ns.Drawer:Toggle() end)
			-- (1.9.0-beta18, Shweep: "when pinned the tool tip doesn't give any info on per player counts") in Global
			-- Inventory each character's count and the total, as the drawer's tooltip; in your bags, your count
			chip:SetScript("OnEnter", function(c)
				if not ns.TooltipsOK() then return end
				GameTooltip:SetOwner(c, "ANCHOR_TOP")
				-- (1.9.1-beta1, Shweep) in your own bags too: who has how many on this ruleset, when anyone else has it
				local per, total = c.per, c.total
				if not (per and #per > 0) and ns.Currency and ns.Currency.Breakdown then per, total = ns.Currency:Breakdown(c.key) end
				if per and #per > 0 then
					GameTooltip:AddDoubleLine(c.name or "", "Total: " .. tostring(total or 0), 1, 0.82, 0, 0.55, 0.78, 1)
					for _, p in ipairs(per) do
						local cr, cg, cb = ns.ClassColor(p.class)
						GameTooltip:AddDoubleLine((ns.Inventory and ns.Inventory.ClassIcon(p.class) or "") .. (p.name or "?"), tostring(p.count), cr, cg, cb, 1, 1, 1)
					end
				else
					GameTooltip:AddDoubleLine(c.name or "", tostring(c.total or 0), 1, 0.82, 0, 1, 1, 1)
				end
				GameTooltip:Show()
			end)
			chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
			hoverWash(chip, 0)
			self.favChips[i] = chip
		end
		chip.icon:SetTexture(e.icon)
		chip:SetHeight(ns.Fonts and ns.Fonts:FooterGrow(18) or 18)   -- (beta8) Footer Text Size
		chip.text:SetText(BreakUpLargeNumbers and BreakUpLargeNumbers(e.count) or e.count)
		chip.name, chip.key = e.name, e.key
		chip.per, chip.total = e.per, e.count   -- (beta18) for its tooltip
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
			self.favMore.label:SetFontObject(footerFont())   -- (beta8)
			self.favMore.tip = "More pinned currencies: open the currency drawer"
		end
		while shownCount > 0 and x + 34 > avail do
			local last = self.favChips[shownCount]
			x = x - (last:GetWidth() + 12)
			last:Hide()
			shownCount = shownCount - 1
		end
		self.favMore:SetHeight(ns.Fonts and ns.Fonts:FooterGrow(18) or 18)
		self.favMore.label:SetText("+" .. (#favs - shownCount))
		-- (1.6.0) only where it fits: in a narrow window it never covers the buttons on the right (the wallet in the
		-- title row still opens every currency)
		if x + 34 <= avail then
			self.favMore:ClearAllPoints(); self.favMore:SetPoint("LEFT", self.footer, "LEFT", x, 0); self.favMore:Show()
		else self.favMore:Hide() end
	elseif self.favMore then self.favMore:Hide() end
	self.favShown = shownCount
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------
-- (1.9.0-beta2) Global Inventory on or off. On: another character's view and Travel Mode step aside, a saved-bank or
-- Gear Sets tab goes to All, and the search starts empty and focused. Off (the globe again, or closing the window):
-- the tab, the search and the scroll come back as they were.
function View:SetGlobal(on)
	if not self.isMain then return end
	on = on and true or false
	if on == (ns.ui.global == true) then return end
	if on then
		self.globalSaved = { sheet = self.st.sheet, text = self.st.filters and self.st.filters.text or "",
			scroll = self.scroll and self.scroll:GetVerticalScroll() or 0 }
		if ns.ui.owner then self:SetOwner(nil) end
		ns.ui.global = true
		ns.ui.travelHold.global = true
		-- (1.9.0-beta6) a custom sheet, or a tab hidden in Global Inventory, goes to All too; a custom sheet's filters are
		-- set aside with it and come back on leaving
		local G = ns.Inventory and ns.Inventory:Settings()
		if not ns.TAB_LABEL[self.st.sheet] then self.globalSaved.filters = self.st.filters; self.st.filters = ns.EmptyFilters() end
		if self.st.sheet == "Bank" or self.st.sheet == "GearSets" or not ns.TAB_LABEL[self.st.sheet]
			or (G and ns.IndexOf(G.hiddenTabs, self.st.sheet)) then self.st.sheet = "All" end
		if self.st.filters then self.st.filters.text = "" end
		if self.search then self.search:SetText("") end
		self:FreshLayout()
		ns:Safely("globalsize:" .. self.name, function() self:ApplySize() end)   -- (beta13) its own size (after combat, in it)
		if self.ScheduleListPlaced then self:ScheduleListPlaced() end   -- (beta16) see View:EnsureListPlaced
		ns:ApplyTravel(); ns:RefreshViews(true)
		if self.search and self.search.SetFocus and self.frame:IsShown() then self.search:SetFocus() end
	else
		ns.ui.global = nil
		ns.ui.globalOpen = nil   -- (beta3) the accordion starts closed next time
		ns.ui.travelHold.global = nil
		local s = self.globalSaved or {}
		self.globalSaved = nil
		if s.sheet then self.st.sheet = s.sheet end
		if s.filters then self.st.filters = s.filters end
		if self.st.filters then self.st.filters.text = s.text or "" end
		if self.search then self.search:SetText(s.text or ""); if self.search.ClearFocus then self.search:ClearFocus() end end
		self:FreshLayout()
		ns:Safely("globalsize:" .. self.name, function() self:ApplySize() end)   -- (beta13) back to your size
		-- (1.9.0-beta16, Shweep: "Closing Global Inventory has the same problem now ... only impact classic") the size
		-- and the view change with the window open, where the opening's checks don't run: run them now
		if self.ScheduleListPlaced then self:ScheduleListPlaced() end
		ns:ApplyTravel(); ns:RefreshViews(true)
		if self.scroll and s.scroll then self.scroll:SetVerticalScroll(s.scroll) end
	end
	if self.btnGlobal and self.btnGlobal.SetActive then self.btnGlobal:SetActive(ns.ui.global == true) end
	self:UpdateTitle()
end

function View:SetSheet(id)
	if self.isMain and ns.ui.global and id == "GearSets" then return end   -- (1.9.0-beta4) your character's sets
	if self.isMain and ns.ui.global and not ns.TAB_LABEL[id] then return end   -- (1.9.0-beta6) built-in tabs only there
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
	if self.isMain and ns.ui.global and ns.Inventory then return ns.Inventory:Settings().collapsed end   -- (1.9.0-beta4)
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

-- (1.7.0-beta2) Lock Windows (Settings > Window): the bags, bank and bag windows and both helpers can't be moved or
-- resized. Their drag and resize handlers check it; the resize grips hide while it's on.
function ns:WindowsLocked() return (ns.db and ns.db.lockWindows) and true or false end
function ns:ApplyWindowLock()
	local locked = ns:WindowsLocked()
	for _, v in pairs(ns.views or {}) do if v.grip then v.grip:SetShown((v.big and not locked) and true or false) end end
	-- the Disenchant Helper is a protected window (its secure button): its grip changes outside combat
	local de = ns.Disenchant and ns.Disenchant.frame
	if de and de.grip then ns:Safely("lockWindows:de", function() de.grip:SetShown(not ns:WindowsLocked()) end) end
end
ns:OnSignal("SETTINGS_CHANGED", function(key) if key == nil or key == "lockWindows" then ns:ApplyWindowLock() end end)
ns:OnSignal("SETTINGS_CHANGED", function(key) if key == "bagSlotCount" then ns:RefreshViews(true) end end)   -- (1.9.0-beta1) the footer's count
-- (1.9.0-beta19) a font change: each window's header laid out again, its group labels measured in the new face
ns:OnSignal("FONTS_CHANGED", function()
	for _, v in pairs(ns.views or {}) do if v.toolItems and v.tools then v:LayoutTools() end end
end)

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
	if ns.ui.owner or ns.ui.global then ns:Print("You can only clean up your own bags."); return end
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

-- (1.9.0-beta8, Shweep: Global Inventory's value "is getting lost ... hard to understand"; "I like" a total row pinned at
-- the bottom) A spreadsheet's Total row: "Total (N items shown)" under Item, the sums under Vendor and AH Price, as the
-- columns stand; it follows the search, tab and filters. Hover: what the numbers mean.
function View:UpdateTotalRow(shown, plan)
	local on = self.isMain and ns.ui.global and plan ~= nil and true or false
	local r = self.totalRow
	if not on and not r then return end
	if not r then
		r = CreateFrame("Frame", nil, self.frame)
		r.line = r:CreateTexture(nil, "ARTWORK"); r.line:SetPoint("TOPLEFT"); r.line:SetPoint("TOPRIGHT"); r.line:SetHeight(1)
		r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
		-- (beta9, Shweep: "too transparent in classic theme") a solid backing in the window's own color, the light tint
		-- over it
		r.tint = r:CreateTexture(nil, "BACKGROUND", nil, 1); r.tint:SetAllPoints(); r.tint:SetTexture("Interface\\Buttons\\WHITE8X8")
		local font = ns.Fonts and ns.Fonts:Name("GameFontHighlightSmall") or "GameFontHighlightSmall"
		r.label = fontString(r, ns.Fonts and ns.Fonts:Name("GameFontNormal") or "GameFontNormal")
		r.count = fontString(r, font)
		r.cells = {}
		for _, key in ipairs({ "v", "ah" }) do r.cells[key] = fontString(r, font, "RIGHT") end
		r:EnableMouse(true)
		r:SetScript("OnEnter", function(row)
			if not ns.TooltipsOK() then return end
			GameTooltip:SetOwner(row, "ANCHOR_TOP")
			ns.TipText(GameTooltip, "Total")
			ns.TipLine(GameTooltip, "Everything shown above, on all your characters: it follows your search, tab and filters.", 0.8, 0.8, 0.8, true)
			-- (beta9) the exact sums, whatever the row had room for
			ns.TipLine(GameTooltip, "Vendor: what a vendor would pay for all of it.", 1, 1, 1, true)
			if row.sums and row.sums.v and row.sums.v > 0 then ns.TipLine(GameTooltip, "   " .. ns.Money(row.sums.v), 1, 1, 1) end
			if row.cells.ah:IsShown() then
				ns.TipLine(GameTooltip, "AH Price: at your price source's prices. Items it hasn't priced count as nothing.", 1, 1, 1, true)
				if row.sums and row.sums.ah and row.sums.ah > 0 then ns.TipLine(GameTooltip, "   " .. ns.Money(row.sums.ah), 1, 1, 1) end
			end
			GameTooltip:Show()
		end)
		r:SetScript("OnLeave", function() GameTooltip:Hide() end)
		self.totalRow = r
	end
	local was = r.on
	r.on = on
	r:SetShown(on)
	if on then
		local sk = Skins:Current()
		r.line:SetColorTexture(unpack(sk.line))
		r.bg:SetVertexColor(sk.bg[1], sk.bg[2], sk.bg[3], 1)
		r.tint:SetVertexColor(1, 1, 1, 0.05)
		r.label:SetTextColor(unpack(sk.heading))
		r.count:SetTextColor(unpack(sk.muted))
		r:SetHeight(ns.Fonts and ns.Fonts:RowNeed() or 20)
		local v, a, priced = 0, 0, ns.AH and ns.AH:Available()
		for _, rec in ipairs(shown or {}) do
			if not rec.hasNoValue and rec.sellPrice then v = v + rec.sellPrice * (rec.count or 1) end
			if priced then a = a + (ns.AH:StackValue(rec) or 0) end
		end
		local n = #(shown or {})
		r.sums = { v = v, ah = a }
		r.label:SetText("Total")
		local at = {}
		for _, col in ipairs(plan) do at[col.key] = col end
		local item = at.n
		r.label:ClearAllPoints(); r.label:SetPoint("LEFT", r, "LEFT", (item and item.colX or 0) + 4, 0)
		r.count:ClearAllPoints(); r.count:SetPoint("LEFT", r.label, "RIGHT", 6, 0)
		-- (beta9, Shweep: "can the new pinned total fit somehow at smaller widths?") each sum ends at its column's right
		-- edge but may take the empty cells to its left (Who, Where, Type), as a spreadsheet lets text run on; still too
		-- tight, the count shortens to "(N)", then the sums drop their copper, then their silver. Never cut short.
		-- (beta10, Shweep) "V:" and "AH:" before them, as the section headers write theirs
		local LABEL = { v = "V: ", ah = "AH: " }
		local function money(c, drop, key)
			if c <= 0 then return LABEL[key] .. "-" end
			if drop == 1 and c >= 100 then c = c - c % 100 elseif drop == 2 and c >= 10000 then c = c - c % 10000 end
			return LABEL[key] .. ns.Money(c)
		end
		local function width(fs, text) fs:SetText(text); return (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()) or fs:GetStringWidth() or 0 end
		local labelEnd = (item and item.colX or 0) + 4 + width(r.label, "Total") + 6
		local sums = {}
		for _, col in ipairs(plan) do if (col.key == "v" or col.key == "ah") and r.cells[col.key] then sums[#sums + 1] = col end end
		local tries = { { 0, "full" }, { 0, "short" }, { 1, "short" }, { 2, "short" }, { 2, "none" } }
		local pick
		for _, t in ipairs(tries) do
			local countText = t[2] == "full" and (n == 1 and "(1 item shown)" or ("(%d items shown)"):format(n)) or (t[2] == "short" and ("(%d)"):format(n) or "")
			local left = labelEnd + (countText ~= "" and (width(r.count, countText) + 8) or 0)
			local fits, place = true, {}
			for _, col in ipairs(sums) do
				local right = col.x + col.width
				local text = money(col.key == "v" and v or a, t[1], col.key)
				local w = width(r.cells[col.key], text)
				if right - w < left then fits = false; break end
				place[col.key] = { left = left, right = right, text = text }
				left = right + 8
			end
			pick = { count = countText, place = place }
			if fits then break end
		end
		r.count:SetText(pick.count)
		for key, cell in pairs(r.cells) do
			local p = pick.place[key]
			if p then
				cell:ClearAllPoints(); cell:SetPoint("LEFT", r, "LEFT", p.left, 0); cell:SetWidth(p.right - p.left)
				cell:SetText(p.text)
				cell:SetTextColor(unpack(sk.text))
				cell:Show()
			elseif at[key] then
				-- (no room even rounded: the last try's text, cut at its own column, rather than nothing)
				local col = at[key]
				cell:ClearAllPoints(); cell:SetPoint("LEFT", r, "LEFT", col.x, 0); cell:SetWidth(col.width)
				cell:SetText(money(key == "v" and v or a, 2, key)); cell:SetTextColor(unpack(sk.text)); cell:Show()
			else
				cell:Hide()
			end
		end
	end
	if was ~= on then self:PlaceScroll() end
end

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
		-- (1.5.5) Icons view has no column headers: the list starts where they would, not below their hidden row
		if self:Pref("view") == "list" and self.kind ~= "bag" then sc:SetPoint("TOPLEFT", self.header, "BOTTOMLEFT", 0, -2)
		else sc:SetPoint("TOPLEFT", self.header, "TOPLEFT", 0, 0) end
		-- (1.9.0-beta8) Global Inventory's Total row takes the list's last line, pinned above the tabs
		local below = (self.totalRow and self.totalRow.on) and (self.totalRow:GetHeight() + 2) or 0
		local base, y = self.tabs or self.footer, 4
		if classic and self.tabs then base, y = self.footer, 6 end
		sc:SetPoint("BOTTOMRIGHT", base, "TOPRIGHT", room, y + below + (self.placeNudge or 0))   -- (beta15) see EnsureListPlaced
		if self.totalRow then
			self.totalRow:ClearAllPoints()
			self.totalRow:SetPoint("BOTTOMLEFT", base, "TOPLEFT", 0, y)
			self.totalRow:SetPoint("BOTTOMRIGHT", base, "TOPRIGHT", room, y)
		end
	else
		sc:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", self.belowShift or 0, classic and -4 or -12)
		sc:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -PAD + room, PAD + (self.placeNudge or 0))
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
		if self.isMain and ns.db.sizeMode == "auto" and self.autoHeight then visible = math.min(select(2, self:SizeLimits()), self.autoHeight) - chrome - 4
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
	if self.isMain and ns.db.sizeMode == "auto" then point = bottomAnchor(point) end
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
	if travel and self.searchFolded and self.searchOpen and self.search then base = self.search end   -- (1.9.0-beta4) under the open search row
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
