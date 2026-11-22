--[[
	BagSmith - Frames/Popups.lua
	The Filters window (search, quality, quick picks, rules, save as a sheet or a section) and the character picker.
--]]

local ADDON, ns = ...
local Skins = ns.Skins
local Popups = {}
ns.Popups = Popups

local function fs(parent, template, justify)
	local s = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
	s:SetJustifyH(justify or "LEFT"); s:SetWordWrap(false)
	return s
end

local function popupFrame(name, parent, width)
	local f = CreateFrame("Frame", name, parent, "BackdropTemplate")
	f:SetFrameStrata("DIALOG")
	f:SetWidth(width)
	f:EnableMouse(true)
	f:Hide()
	Skins:Register(f, function(fr)
		Skins:ApplyBackdrop(fr)
		fr:SetBackdropColor(0.075, 0.07, 0.06, 1)
	end)
	return f
end

------------------------------------------------------------------------
-- Confirmation dialog: BagSmith's own small frame (never a Blizzard
-- StaticPopup), anchored to the control that asked.
------------------------------------------------------------------------
-- A web address to copy: addons can't open web pages, so the address is shown
-- selected, ready for Ctrl+C. Edits are undone; Ctrl+C closes it a moment later.
function ns.ShowLink(title, url)
	local f = Popups.link
	if not f then
		f = CreateFrame("Frame", "BagSmithLink", UIParent, "BackdropTemplate")
		f:SetSize(420, 132)
		f:SetFrameStrata("FULLSCREEN_DIALOG")
		f:SetClampedToScreen(true)
		f:EnableMouse(true)
		f:SetMovable(true); f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
		f.classicSpec = ns.Classic.DialogSpec(f, { restore = function() Skins:ApplyBackdrop(f); local s = Skins:Current(); f:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1) end })
		f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		f.title:SetPoint("TOPLEFT", 16, -14)
		f.help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		f.help:SetPoint("TOPLEFT", 16, -38); f.help:SetPoint("TOPRIGHT", -16, -38); f.help:SetJustifyH("LEFT")
		f.help:SetText("Press Ctrl+C to copy, then paste it into your browser.")
		f.edit = CreateFrame("EditBox", "BagSmithLinkBox", f, "InputBoxTemplate")
		f.edit:SetHeight(22); f.edit:SetPoint("TOPLEFT", 22, -60); f.edit:SetPoint("TOPRIGHT", -18, -60)
		f.edit:SetAutoFocus(false)
		f.edit:SetScript("OnTextChanged", function(e, user) if user and e:GetText() ~= f.url then e:SetText(f.url); e:HighlightText() end end)
		f.edit:SetScript("OnEditFocusGained", function(e) e:HighlightText() end)
		f.edit:SetScript("OnMouseUp", function(e) e:HighlightText() end)
		f.edit:SetScript("OnEscapePressed", function() f:Hide() end)
		f.edit:SetScript("OnEnterPressed", function() f:Hide() end)
		f.edit:SetScript("OnKeyDown", function(e, key)
			if key == "C" and IsControlKeyDown() then
				local shown = f.showToken
				C_Timer.After(0.2, function() if f.showToken == shown then f:Hide() end end)
			end
		end)
		f.close = ns.TextButton(f, "Close", 80, function() f:Hide() end)
		f.close:SetHeight(24); f.close:SetPoint("BOTTOMRIGHT", -14, 12)
		f:SetScript("OnHide", function() f.edit:ClearFocus() end)
		Skins:Register(f, function(fr)
			Skins:ApplyBackdrop(fr); local s = Skins:Current(); fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)
			fr.title:SetTextColor(unpack(s.heading)); fr.help:SetTextColor(unpack(s.muted))
			ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
		end)
		f:Hide()
		Popups.link = f
	end
	f.url = url
	f.showToken = (f.showToken or 0) + 1   -- a copy timer from an earlier show won't close this one
	f.title:SetText(title)
	if ns.Classic then ns.Classic:RefreshTitle(f) end
	f.edit:SetText(url)
	f:Show()
	f.edit:SetFocus(); f.edit:HighlightText()
	return f
end

-- Profile Sharing window: "share" shows this profile's code, selected and
-- ready to copy; "import" takes a pasted code and a name for the new profile.
function ns.ShareWindow(mode, mode2)
	local f = Popups.share
	if not f then
		f = CreateFrame("Frame", "BagSmithShare", UIParent, "BackdropTemplate")
		f:SetSize(440, 270)
		f:SetFrameStrata("DIALOG")
		f:SetClampedToScreen(true)
		f:EnableMouse(true)
		f:SetMovable(true); f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
		f.classicSpec = ns.Classic.DialogSpec(f, { restore = function() Skins:ApplyBackdrop(f); local s = Skins:Current(); f:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1) end })
		f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		f.title:SetPoint("TOPLEFT", 16, -14)
		f.help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		f.help:SetPoint("TOPLEFT", 16, -38); f.help:SetPoint("TOPRIGHT", -16, -38)
		f.help:SetJustifyH("LEFT"); f.help:SetWordWrap(true)
		-- The code box: a scrolling, multi-line text box.
		f.box = CreateFrame("Frame", nil, f, "BackdropTemplate")
		f.box:SetPoint("TOPLEFT", 16, -72); f.box:SetPoint("TOPRIGHT", -16, -72); f.box:SetHeight(110)
		f.scroll = CreateFrame("ScrollFrame", nil, f.box)
		f.scroll:SetPoint("TOPLEFT", 6, -6); f.scroll:SetPoint("BOTTOMRIGHT", -6, 6)
		f.edit = CreateFrame("EditBox", nil, f.scroll)
		f.edit:SetMultiLine(true); f.edit:SetAutoFocus(false); f.edit:SetFontObject(ChatFontNormal)
		f.edit:SetWidth(440 - 32 - 12)
		f.scroll:SetScrollChild(f.edit)
		f.scroll:EnableMouseWheel(true)
		f.scroll:SetScript("OnMouseWheel", function(sf, d) sf:SetVerticalScroll(math.max(0, (sf:GetVerticalScroll() or 0) - d * 20)) end)
		f.box:EnableMouse(true); f.box:SetScript("OnMouseDown", function() f.edit:SetFocus() end)
		f.edit:SetScript("OnEscapePressed", function() f:Hide() end)
		-- Share: the code stays as it is, selected; Ctrl+C (Cmd+C) says Copied!
		f.edit:SetScript("OnTextChanged", function(e, user)
			if f.locked and user and e:GetText() ~= f.locked then e:SetText(f.locked); e:HighlightText() end
		end)
		f.edit:SetScript("OnEditFocusGained", function(e) if f.locked then e:HighlightText() end end)
		f.edit:SetScript("OnKeyDown", function(e, key)
			if f.locked and key == "C" and ((IsControlKeyDown and IsControlKeyDown()) or (IsMetaKeyDown and IsMetaKeyDown())) then
				f.hint:SetText("Copied!")
			end
		end)
		f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		f.hint:SetPoint("TOPLEFT", f.box, "BOTTOMLEFT", 2, -4); f.hint:SetPoint("TOPRIGHT", f.box, "BOTTOMRIGHT", -2, -4)
		f.hint:SetJustifyH("LEFT")
		-- Import: the new profile's name.
		f.nameLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		f.nameLabel:SetPoint("BOTTOMLEFT", 16, 48); f.nameLabel:SetText("Name")
		f.name = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
		f.name:SetSize(200, 20); f.name:SetAutoFocus(false); f.name:SetMaxLetters(32)
		f.name:SetPoint("LEFT", f.nameLabel, "RIGHT", 12, 0)
		f.name:SetScript("OnEscapePressed", function() f:Hide() end)
		f.ok = ns.TextButton(f, "Import", 80, function()
			local result, err = ns.Share:Import(f.edit:GetText(), f.name:GetText())
			if not result then f.hint:SetText("|cffff6060" .. err .. "|r"); return end
			f:Hide()
			ns:Print("Imported the profile \"%s\". Assign it in Settings > Profile to use it.", result)
			if ns.SettingsPanel and ns.SettingsPanel.Refresh then ns.SettingsPanel:Refresh() end
		end)
		f.ok:SetHeight(24); f.ok:SetPoint("BOTTOMRIGHT", -14, 12)
		f.close = ns.TextButton(f, "Close", 80, function() f:Hide() end)
		f.close:SetHeight(24); f.close:SetPoint("RIGHT", f.ok, "LEFT", -6, 0)
		f:SetScript("OnKeyDown", function(s, key) if key == "ESCAPE" then s:Hide() end end)
		-- Skinned last: the skin callback colors the pieces made above.
		Skins:Register(f, function(fr)
			Skins:ApplyBackdrop(fr); local s = Skins:Current(); fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)
			fr.title:SetTextColor(unpack(s.heading)); fr.help:SetTextColor(unpack(s.muted)); fr.hint:SetTextColor(unpack(s.muted))
			if fr.box.SetBackdrop then
				fr.box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
				fr.box:SetBackdropColor(0, 0, 0, 0.35); fr.box:SetBackdropBorderColor(unpack(s.line))
			end
			ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
		end)
		Popups.share = f
	end
	f.mode = mode
	f.hint:SetText("")
	if mode == "text" then
		-- Read-only text for copying (the controller diagnostics); opts = { title, help, text }.
		local opts = type(mode2) == "table" and mode2 or {}
		f.title:SetText(opts.title or ""); if ns.Classic then ns.Classic:RefreshTitle(f) end
		f.help:SetText(opts.help or "")
		f.locked = opts.text or ""
		f.edit:SetText(f.locked)
		f.hint:SetText((IsMacClient and IsMacClient()) and "Press Cmd+C to copy" or "Press Ctrl+C to copy")
		f.nameLabel:Hide(); f.name:Hide(); f.ok:Hide()
		f.close.label:SetText("Close")
		f.close:ClearAllPoints(); f.close:SetPoint("BOTTOMRIGHT", -14, 12)
	elseif mode == "share" then
		local code, err = ns.Share:Export()
		f.title:SetText("Share Profile: " .. ns.profileName); if ns.Classic then ns.Classic:RefreshTitle(f) end
		f.help:SetText("This code holds the profile's settings and saved sheets. Copy it to keep it, or give it to someone; they import it in Settings > Profile.")
		f.locked = code or ""
		f.edit:SetText(code or "")
		f.hint:SetText(code and ((IsMacClient and IsMacClient()) and "Press Cmd+C to copy" or "Press Ctrl+C to copy") or ("|cffff6060" .. tostring(err) .. "|r"))
		f.nameLabel:Hide(); f.name:Hide(); f.ok:Hide()
		f.close.label:SetText("Close")
		f.close:ClearAllPoints(); f.close:SetPoint("BOTTOMRIGHT", -14, 12)
	else
		f.title:SetText("Import Profile"); if ns.Classic then ns.Classic:RefreshTitle(f) end
		f.help:SetText("Paste a BagSmith profile code. It's added as a new profile; nothing you have now is changed.")
		f.locked = nil
		f.edit:SetText("")
		f.name:SetText("")
		f.nameLabel:Show(); f.name:Show(); f.ok:Show()
		f.close.label:SetText("Cancel")
		f.close:ClearAllPoints(); f.close:SetPoint("RIGHT", f.ok, "LEFT", -6, 0)
	end
	f:ClearAllPoints(); f:SetPoint("CENTER")
	f:Show()
	f.edit:SetFocus()
	if mode == "share" or mode == "text" then f.edit:HighlightText() end
end

function ns.Confirm(anchor, text, onYes, onNo)
	local f = Popups.confirm
	if not f then
		f = CreateFrame("Frame", "BagSmithConfirm", UIParent, "BackdropTemplate")
		f:SetSize(340, 96)
		f:SetFrameStrata("TOOLTIP")
		f:SetClampedToScreen(true)
		-- movable like every other dialog (1.1.0): it opens beside what you clicked and can be pulled aside
		f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
		f:EnableMouse(true)
		-- Classic: Blizzard's dialog border, like its own pop-up questions.
		f.classicSpec = ns.Classic.DialogSpec(f, { title = function() return "Confirm" end, restore = function() Skins:ApplyBackdrop(f); local s = Skins:Current(); f:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1) end })
		Skins:Register(f, function(fr)
			Skins:ApplyBackdrop(fr); local s = Skins:Current(); fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)
			ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
		end)
		f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		f.text:SetPoint("TOPLEFT", 16, -14); f.text:SetPoint("TOPRIGHT", -16, -14)
		-- the text starts at the top edge: under the Classic title bar it moves down to clear it (restored in Modern)
		table.insert(f.classicSpec.moves, { f.text, function() f.text:ClearAllPoints(); f.text:SetPoint("TOPLEFT", 16, -30); f.text:SetPoint("TOPRIGHT", -16, -30) end })
		ns.Classic:Dress(f, f.classicSpec, ns.Classic.IsOn())   -- (the text exists now: the move joins the dressing)
		f.text:SetJustifyH("LEFT"); f.text:SetJustifyV("TOP"); f.text:SetWordWrap(true); f.text:SetNonSpaceWrap(true)
		f.text:SetHeight(60)   -- room for several lines; the frame sizes to the text below
		f.yes = ns.TextButton(f, "Yes", 70, function() local fn = f.onYes; f.onNo = nil; f:Hide(); if fn then fn() end end)
		f.yes:SetHeight(24); f.yes:SetPoint("BOTTOMRIGHT", -14, 12)
		f.no = ns.TextButton(f, "Cancel", 70, function() f:Hide() end)
		f.no:SetHeight(24); f.no:SetPoint("RIGHT", f.yes, "LEFT", -6, 0)
		f:SetScript("OnHide", function(s)
			local no = s.onNo
			s.onYes, s.onNo = nil, nil
			if no then no() end   -- closed without Yes
		end)
		f:SetScript("OnKeyDown", function(s, key) if key == "ESCAPE" then s:Hide() end end)
		Popups.confirm = f
	end
	if f:IsShown() then f:Hide() end   -- an earlier question closes first (its Cancel runs)
	f.text:SetText(text)
	f.onYes, f.onNo = onYes, onNo
	f.sections = nil
	f.lootHelper = nil; f.lootHelperKey = nil   -- the Loot Helper marks its own confirmations after opening them
	local lines = math.max(1, math.ceil((f.text:GetStringWidth() or 0) / (340 - 32)))
	local textH = math.max(f.text:GetStringHeight() or 14, lines * 15)
	f.text:SetHeight(textH + 4)
	f:SetHeight(textH + 66)
	f.yes:SetActive(true)
	f:ClearAllPoints()
	if anchor and anchor.GetCenter then f:SetPoint("TOP", anchor, "BOTTOM", 0, -6) else f:SetPoint("CENTER") end
	f:Show()
end

function Popups:HideAll()
	for _, panel in pairs(self.filters or {}) do panel:Hide() end
	if self.chars then self.chars:Hide() end
end

------------------------------------------------------------------------
-- The Filters window (rebuilt in 1.10.0-beta4 on the rules a custom section has)
--
-- Search, Quality and Quick picks always apply. Under "Only show items that fit" are rules, the same rows as the
-- section editor's (Frames/RuleList.lua), with three kinds that are only a filter's: Section, Bag and Time in Bags.
-- What used to be the "Type / Sections", "Bind", "Where" and "Age" boxes are rules now: a sheet saved by an older
-- version shows them as rules (ns.FoldFilters), and filters the same.
--
-- The window edits its view's filters in place (view.st.filters), so the list behind it follows every click. Its
-- rule list keeps a draft of the rules (a rule with nothing picked yet lives only there) and writes the sound ones
-- back on every change.
------------------------------------------------------------------------
local QUALITY = { { 0, "Poor" }, { 1, "Common" }, { 2, "Uncommon" }, { 3, "Rare" }, { 4, "Epic" }, { 5, "Legendary" } }

local FW, FPAD = 480, 14
local RULES_W, RULES_MAX = FW - FPAD * 2 - 22, 190   -- the rules, beside their scroll bar; they scroll past this height
local function qualityHex(q)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	if not c then return nil end
	return ("|cff%02x%02x%02x"):format(math.floor((c.r or 1) * 255 + 0.5), math.floor((c.g or 1) * 255 + 0.5), math.floor((c.b or 1) * 255 + 0.5))
end
-- A chip: a small button that stays lit while it's on. (It answers SetChecked and GetChecked like the check boxes
-- these used to be.)
local function chip(parent, label, onChange)
	local c
	c = ns.TextButton(parent, label, 40, function()
		c.on = not c.on
		c:Paint()
		onChange(c.on, c)
	end)
	c:SetHeight(20)
	c.text = label
	function c:Paint()
		local hex = self.on and self.quality and qualityHex(self.quality)
		self.label:SetText(hex and (hex .. self.text .. "|r") or self.text)
		self:SetActive(self.on and true or false)
	end
	function c:SetChecked(on) self.on = on and true or false; self:Paint() end
	function c:GetChecked() return self.on == true end
	c:SetWidth(math.max(30, math.ceil(c.label:GetStringWidth() or 0) + 16))
	return c
end

-- The bags the window is actually showing: its own or the Bank sheet's,
-- live or another character's saved ones (with their saved names).
local function whereBags(view)
	local list = view.Bags and view:Bags() or ns.BAGS
	local saved
	if view.Records then local _; _, saved = view:Records() end
	local out = {}
	for _, bag in ipairs(list) do
		-- Another character's (or the unvisited bank's) saved names only: never
		-- the current character's live names standing in for missing ones.
		local info
		if view.IsCached and view:IsCached() then info = saved and saved[bag] else info = (saved and saved[bag]) or ns.bagInfo[bag] end
		if info and (info.size or 0) > 0 then out[#out + 1] = info.name or ("Bag " .. bag) end
	end
	return out
end

function Popups:BuildFilters(view)
	local f = popupFrame(nil, view.frame, FW)
	f:SetMovable(true); f:SetClampedToScreen(true)
	f.view = view
	self.filters = self.filters or {}
	self.filters[view] = f
	-- Every color painted here is remembered and painted again on a skin
	-- change, so the panel never keeps the colors of the skin it was built in.
	f.tints = {}
	local function tint(region, role, texture)
		f.tints[#f.tints + 1] = { region, role, texture }
		if texture then region:SetColorTexture(Skins:Color(role)) else region:SetTextColor(Skins:Color(role)) end
	end
	self.filter = f
	f.checks = {}

	-- Drag bar with title and close; the panel can be moved aside to watch the list change.
	local drag = CreateFrame("Frame", nil, f)
	drag:SetPoint("TOPLEFT", 0, 0); drag:SetPoint("TOPRIGHT", 0, 0); drag:SetHeight(34)
	drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart", function() f:StartMoving() end)
	-- Each window's panel remembers on its own that the player moved it.
	-- (One shared flag left the bank's panel, built later, with no position.)
	drag:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f.moved = true end)
	f.title = fs(f, "GameFontNormal"); f.title:SetPoint("TOPLEFT", FPAD, -11)
	tint(f.title, "heading")
	local close = ns.IconButton(f, "Interface\\AddOns\\BagSmith\\Media\\ui-close.tga", "Close", function() f:Hide() end)
	close:SetPoint("TOPRIGHT", -8, -6)
	-- Classic: Blizzard's window frame (no portrait), title in the strip.
	f.classicSpec = {
		title = function() return f.title:GetText() end,
		close = function() f:Hide() end,
		hide = { f.title, close },
		restore = function() Skins:ApplyBackdrop(f); f:SetBackdropColor(0.075, 0.07, 0.06, 1) end,
	}
	Skins:Register(f, function(fr)
		Skins:ApplyBackdrop(fr); fr:SetBackdropColor(0.075, 0.07, 0.06, 1)
		for _, t in ipairs(fr.tints or {}) do
			if t[3] then t[1]:SetColorTexture(Skins:Color(t[2])) else t[1]:SetTextColor(Skins:Color(t[2])) end
		end
		ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
		if ns.Classic.DressScrollBar and fr.rules then ns.Classic:DressScrollBar(fr.rules, ns.Classic.IsOn()) end
		if fr:IsShown() and fr.list then Popups:LayoutFilters(fr) end
	end)
	-- The drag bar covers the top of the panel; the close button must sit above it or the bar takes its clicks.
	close:SetFrameLevel(drag:GetFrameLevel() + 2)
	f.closeBtn, f.dragBar = close, drag
	-- which window and tab these filters are for: "Bags, on the All tab"
	f.where = fs(f); f.where:SetPoint("TOPLEFT", FPAD, -34); tint(f.where, "muted")
	local y = -52

	-- Search, shared with the window's own search box.
	local search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
	search:SetPoint("TOPLEFT", FPAD + 4, y); search:SetPoint("TOPRIGHT", -FPAD, y); search:SetHeight(24)
	search:SetAutoFocus(false)
	search:HookScript("OnTextChanged", function(box)
		local v = Popups.view
		if not v or Popups.syncing then return end
		local txt = box:GetText() or ""
		if txt ~= v.st.filters.text then
			v.st.filters.text = txt
			if v.search then Popups.syncing = true; v.search:SetText(txt); Popups.syncing = false end
			ns:RefreshViews()
		end
	end)
	search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
	f.search = search
	local shint = fs(f); shint:SetPoint("TOPLEFT", FPAD, y - 28); tint(shint, "muted")
	shint:SetText("Words match names and types. Shortcuts: boe, bop, new, q:rare, t:herb, il>20. A saved sheet keeps its search.")
	shint:SetWidth(FW - FPAD * 2); shint:SetWordWrap(true)
	y = y - 28 - 32

	local function heading(text)
		local s = fs(f, "GameFontNormal"); s:SetPoint("TOPLEFT", FPAD, y); s:SetText(text); tint(s, "accent")
		y = y - 20
		return s
	end
	local function row(chips)
		local x = FPAD
		for _, c in ipairs(chips) do
			c:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
			x = x + c:GetWidth() + 4
			f.checks[#f.checks + 1] = c
		end
		y = y - 28
	end
	local function filters() return f.view.st.filters end
	-- Quality: any of the ones lit
	heading("Quality")
	local chips = {}
	for _, q in ipairs(QUALITY) do
		local c = chip(f, q[2], function(on) filters().q[q[1]] = on or nil; ns:RefreshViews(true) end)
		c.groupKey, c.key, c.quality = "q", q[1], q[1]
		chips[#chips + 1] = c
	end
	row(chips)
	-- Quick picks
	heading("Quick picks")
	local newC = chip(f, "New", function(on) filters().new = on; ns:RefreshViews(true) end)
	newC.groupKey, newC.tip = "new", "Only items that are new in your bags."
	local usableC = chip(f, "Usable by Me", function(on) filters().usable = on or nil; ns:RefreshViews(true) end)
	usableC.groupKey, usableC.tip = "usable", "Hides what your character can't use: a level, class or skill it doesn't have."
	-- (1.9.0-beta4, Shweep) Global Inventory only: your characters on other rulesets too (hidden by default)
	local realmsC = chip(f, "Include Other Rulesets", function(on)
		if ns.Inventory then ns.Inventory:Settings().allRealms = on end
		ns:RefreshViews(true)
	end)
	realmsC.groupKey = "allRealms"
	f.realmsCheck = realmsC
	row({ newC, usableC, realmsC })
	y = y - 4

	-- Only show items that fit [all of these] [any one of these], then the rules
	f.ask = fs(f); f.ask:SetPoint("TOPLEFT", FPAD, y - 4); f.ask:SetText("Only show items that fit"); tint(f.ask, "text")
	f.all = ns.TextButton(f, "all of these", 92, function() Popups:SetFilterMode(f, "all") end); f.all:SetHeight(20)
	f.all:SetPoint("LEFT", f.ask, "RIGHT", 8, 0)
	f.any = ns.TextButton(f, "any one of these", 118, function() Popups:SetFilterMode(f, "any") end); f.any:SetHeight(20)
	f.any:SetPoint("LEFT", f.all, "RIGHT", 6, 0)
	f.all.tip = "An item must fit every rule below."
	f.any.tip = "An item only has to fit one of the rules below."
	y = y - 28
	f.rulesTop = y
	-- (named, as the game's scroll frame template names its own parts after it)
	local suffix = view.isBank and "Bank" or "Bags"
	f.rules = CreateFrame("ScrollFrame", "BagSmithFilterRules" .. suffix, f, "UIPanelScrollFrameTemplate")
	f.rules:SetPoint("TOPLEFT", FPAD, y); f.rules:SetSize(RULES_W, 30)
	f.rulesChild = CreateFrame("Frame", nil, f.rules); f.rulesChild:SetSize(RULES_W, 1); f.rules:SetScrollChild(f.rulesChild)
	ns.WheelStep(f.rules, 40)
	-- the rule list (Frames/RuleList.lua): a filter's, so Section, Bag and Time in Bags are offered too
	local L = setmetatable({ filter = true, rows = {}, parent = f.rulesChild, width = RULES_W, host = f, pickerName = "BagSmithFilterPicker" .. suffix }, ns.RuleList)
	f.list = L
	L.draft = L:DraftFrom(nil)
	function L:Changed()
		local now = filters()
		now.rules = ns.Rules.Clean(self:Rules())
		self.bound, self.wrote = now, now.rules
		Popups:LayoutFilters(f)
		ns:RefreshViews(true)
	end
	function L:Added()
		f.rules:SetVerticalScroll(math.max(0, (f.rulesHeight or 0) - RULES_MAX))
	end
	-- the choices only this window knows: your sections, and the bags it shows
	function L:Options(k)
		if k == "sec" then
			local out = {}
			for _, id in ipairs(ns.CATS) do out[#out + 1] = { label = ns.CAT_LABEL[id] or id, v = { id } } end
			for _, c in ipairs(ns.Sections and ns.Sections:Customs() or {}) do out[#out + 1] = { label = c.name, v = { c.id } } end
			return out
		elseif k == "bag" then
			local out = {}
			for _, name in ipairs(whereBags(f.view)) do out[#out + 1] = { label = name, v = { name } } end
			return out
		end
		return ns.Rules:Options(k)
	end
	f.add = ns.TextButton(f.rulesChild, "+ Add a Rule", 104, function(b) L:AddMenu(b) end); f.add:SetHeight(22)
	f.hint = fs(f.rulesChild); f.hint:SetText("Pick two or more on one line and either one counts."); tint(f.hint, "muted")

	-- Everything under the rules rides one frame, moved to sit below however many rules there are.
	local tail = CreateFrame("Frame", nil, f); tail:SetSize(FW, 150)
	f.tail = tail
	local ty = 0
	local line = tail:CreateTexture(nil, "ARTWORK"); line:SetPoint("TOPLEFT", FPAD, ty); line:SetPoint("TOPRIGHT", -FPAD, ty); line:SetHeight(1); tint(line, "line", true)
	ty = ty - 8
	-- how much of the tab the filters leave: "14 of 57 items shown"
	f.count = fs(tail); f.count:SetPoint("TOPLEFT", FPAD, ty - 5); tint(f.count, "text")
	local clear = ns.TextButton(tail, "Clear All", 80, function()
		local v = f.view
		v.st.filters = ns.EmptyFilters(); if v.search then v.search:SetText("") end
		Popups:SyncFilters(); ns:RefreshViews(true)
	end)
	clear:SetHeight(22); clear:SetPoint("TOPRIGHT", -FPAD, ty)
	f.clearBtn = clear
	ty = ty - 32
	-- Keep these filters: as a sheet (a tab), or as a section. Rename, save or delete when a sheet is being edited.
	f.sheetLabel = fs(tail, "GameFontNormal"); f.sheetLabel:SetPoint("TOPLEFT", FPAD, ty); tint(f.sheetLabel, "accent")
	ty = ty - 22
	local box = CreateFrame("EditBox", nil, tail, "InputBoxTemplate")
	box:SetSize(FW - FPAD * 2 - 6 - 116 - 8 - 132 - 8, 24); box:SetAutoFocus(false); box:SetMaxLetters(40)
	box:SetPoint("TOPLEFT", FPAD + 6, ty)
	box:SetScript("OnEnterPressed", function() Popups:CommitSheet() end)
	box:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
	f.sheetBox = box
	local save = ns.TextButton(tail, "Save as Sheet", 116, function() Popups:CommitSheet() end)
	save:SetHeight(24); save:SetPoint("LEFT", box, "RIGHT", 8, 0)
	f.saveBtn = save
	local section = ns.TextButton(tail, "Save as Section...", 132, function() Popups:SaveAsSection(f) end)
	section:SetHeight(24); section:SetPoint("LEFT", save, "RIGHT", 8, 0)
	section.tip = "Opens the section editor with these rules, to look over before it's made."
	f.sectionBtn = section
	local hint = fs(tail); hint:SetPoint("TOPLEFT", FPAD, ty - 30); tint(hint, "muted")
	hint:SetWidth(FW - FPAD * 2); hint:SetWordWrap(true)
	f.saveHint = hint
	ty = ty - 30 - 34
	f.deleteBtn = ns.TextButton(tail, "Delete Sheet", 100, function(btn)
		local v, name = Popups.view, Popups.editing
		if not name then return end
		ns.Confirm(btn, ("Delete the sheet \"%s\"?"):format(name), function()
			ns:DeleteSheet(name, v); f:Hide()
		end)
	end)
	f.deleteBtn:SetHeight(24); f.deleteBtn:SetPoint("TOPLEFT", FPAD, ty)
	local done = ns.TextButton(tail, "Done", 70, function() f:Hide() end)
	done:SetHeight(24); done:SetPoint("TOPRIGHT", -FPAD, ty)
	f.doneBtn = done
	f.tailHeight = -ty + 24 + FPAD
	tail:SetHeight(f.tailHeight)
	f:SetScript("OnHide", function() L:ClosePicker() end)
	ns.Classic:DressButtons(f)
end

function Popups:SetFilterMode(f, mode)
	local L = f.list
	L.draft.mode = mode == "any" and "any" or "all"
	L:Changed()
end

-- Lays out the rules and what rides below them, and sizes the window to fit.
function Popups:LayoutFilters(f)
	local L = f.list
	if not L then return end
	local s = Skins:Current()
	f.all:SetActive(L.draft.mode ~= "any"); f.any:SetActive(L.draft.mode == "any")
	local h, lists = L:Layout(s)
	f.add:ClearAllPoints(); f.add:SetPoint("TOPLEFT", f.rulesChild, "TOPLEFT", 0, -h)
	f.add:SetAlpha(#L.draft.rows >= ns.Rules.MAX_ROWS and 0.5 or 1)
	h = h + 28
	f.hint:SetShown(lists > 0)
	if lists > 0 then f.hint:ClearAllPoints(); f.hint:SetPoint("TOPLEFT", f.rulesChild, "TOPLEFT", 0, -h); h = h + 16 end
	f.rulesHeight = h
	f.rulesChild:SetHeight(math.max(1, h))
	local view = math.min(h, RULES_MAX)
	f.rules:SetHeight(view)
	if f.rules.ScrollBar then f.rules.ScrollBar:SetShown(h > RULES_MAX) end
	if (f.rules:GetVerticalScroll() or 0) > math.max(0, h - view) then f.rules:SetVerticalScroll(math.max(0, h - view)) end
	local top = f.rulesTop - view - 8
	f.tail:ClearAllPoints(); f.tail:SetPoint("TOPLEFT", f, "TOPLEFT", 0, top)
	f:SetHeight(-top + f.tailHeight)
end

-- The count under the rules, and anything else that follows the list behind the window. View:UpdateChrome calls this
-- on every redraw of its list.
function Popups:UpdateCount(view, shown, total)
	local f = self.filters and self.filters[view]
	if not (f and f.count) then return end
	if shown and total then f.shownCount, f.totalCount = shown, total end
	if not f:IsShown() then return end
	-- the window's filters were replaced (another tab, another profile): show those
	if self.view == view and f.list and f.list.bound ~= view.st.filters then
		-- a sheet was being edited and another tab was picked: the edit is over, so Save Changes can't put that
		-- tab's filters into the sheet
		if self.editing and view.st.sheet ~= self.editTab then self.editing, self.editingDB = nil, nil end
		self:SyncFilters()
	end
	local n, of = f.shownCount or 0, f.totalCount or 0
	if of == 0 then f.count:SetText("Nothing on this tab")
	elseif n == of then f.count:SetText(of == 1 and "The 1 item here is shown" or ("All %d items shown"):format(of))
	else f.count:SetText(("%d of %d items shown"):format(n, of)) end
end

-- Saves a new sheet, or applies name + filters to the sheet being edited.
function Popups:CommitSheet()
	local f, v = self.filter, self.view
	if not (f and f:IsShown()) then return end   -- a panel closed by a profile change can't save anything
	local name = f.sheetBox:GetText()
	if self.editing then
		local ok, err = ns:UpdateSheet(self.editing, name, v)
		if ok then f:Hide() else ns:Print(err) end
	else
		local ok, err = ns:SaveSheet(name, v)
		if ok then f.sheetBox:SetText(""); f:Hide() else ns:Print(err) end
	end
end

-- Save as Section...: the rules a section can use, handed to the section editor to look over. A section's rules are
-- about the item itself, so the search, the quick picks and the rules about where an item is right now stay behind,
-- and the editor says which.
local function joinWords(list)
	if #list <= 2 then return table.concat(list, " and ") end
	return table.concat(list, ", ", 1, #list - 1) .. " and " .. list[#list]
end
function Popups:SectionRules(filters)
	local R = ns.Rules
	local f = ns.FoldFilters(ns.CleanFilters(filters))
	local rules = f.rules or { mode = "all", rows = {} }
	local rows, left, seen = {}, {}, {}
	local function leave(word) if not seen[word] then seen[word] = true; left[#left + 1] = word end end
	if (f.text or "") ~= "" then leave("the search") end
	for _, row in ipairs(rules.rows) do
		local def = R.KEYS[row.k]
		if def and def.filterOnly then leave(def.label) else rows[#rows + 1] = row end
	end
	-- the Quality chips are one more rule, where "all of these" (or nothing else) makes that mean the same
	if next(f.q) then
		if rules.mode ~= "any" or #rows == 0 then
			local v = {}
			for q in pairs(f.q) do v[#v + 1] = q end
			table.sort(v)
			table.insert(rows, 1, { k = "quality", v = v })
			if #rows == 1 then rules.mode = "all" end
		else
			leave("Quality")
		end
	end
	if f.new then leave("New") end
	if f.usable then leave("Usable by Me") end
	local out = R.Clean({ mode = rules.mode, rows = rows })
	local note = #left > 0 and ("Left out, since a section's rules are about the item itself: %s."):format(joinWords(left)) or nil
	return out, note
end
function Popups:SaveAsSection(f)
	local v = f.view
	if not (ns.SectionEditor and v) then return end
	local rules, note = self:SectionRules(v.st.filters)
	local name = f.sheetBox:GetText() or ""
	ns.SectionEditor:Open(nil, { name = name, rules = rules, note = note })
end

function Popups:SyncFilters()
	local f = self.filter
	if not f then return end
	local v = self.view or ns.Window.main
	-- what an older version kept as boxes shows as rules (the filters mean the same either way)
	local filters = ns.FoldFilters(v.st.filters)
	-- the rule list's draft follows the window's filters: made again only when they were replaced by something else
	-- (another sheet, Clear All, a section deleted), never over a rule that is still being filled in
	local L = f.list
	if L.bound ~= filters or filters.rules ~= L.wrote then
		L:ClosePicker()
		L.draft = L:DraftFrom(filters.rules)
		L.bound, L.wrote = filters, filters.rules
		L:ClearBoxes()
		f.rules:SetVerticalScroll(0)
	end
	for _, c in ipairs(f.checks) do
		if c.groupKey == "new" then c:SetChecked(filters.new)
		elseif c.groupKey == "usable" then c:SetChecked(filters.usable)
		elseif c.groupKey == "allRealms" then
			c:SetChecked(ns.Inventory and ns.Inventory:Settings().allRealms or false)
			c:SetShown((v.isMain and ns.ui.global) and true or false)
		else c:SetChecked(filters[c.groupKey][c.key] and true or false) end
	end
	self.syncing = true
	f.search:SetText(filters.text or "")
	self.syncing = false
	-- "Bags, on the All tab"
	local sheet = v.st.sheet or "All"
	local tab = ns.TAB_LABEL[sheet] or sheet
	local what = v.isBank and "Bank" or ((v.isMain and ns.ui.global) and "Global Inventory" or "Bags")
	f.where:SetText(("%s, on the %s tab"):format(what, tab))
	if self.editing then
		f.title:SetText((v.isBank and "Bank Sheet: " or "Sheet: ") .. self.editing)
		f.sheetLabel:SetText("Edit Sheet")
		f.saveBtn.label:SetText("Save Changes")
		f.saveHint:SetText("Change the name or the filters above, then save. Delete removes the tab.")
		f.deleteBtn:Show()
	else
		f.title:SetText(v.isBank and "Bank Filters" or "Filters")
		f.sheetLabel:SetText("Keep these filters:")
		f.saveBtn.label:SetText("Save as Sheet")
		f.saveHint:SetText("A sheet is a tab that shows only these items. A section groups them together wherever they show.")
		f.deleteBtn:Hide()
	end
	ns.Classic:Retitle(f, f.title:GetText())
	self:LayoutFilters(f)
	self:UpdateCount(v)
end

-- mode: nil/"browse" (Filter button), "new" (plus next to the tabs), "edit" (pencil on a custom tab)
function Popups:OpenFilters(view, mode, sheetName)
	-- One panel per window, built once.
	self.filters = self.filters or {}
	for other, panel in pairs(self.filters) do if other ~= view then panel:Hide() end end
	if not self.filters[view] then self:BuildFilters(view) end
	self.filter = self.filters[view]
	if self.chars then self.chars:Hide() end
	local f = self.filter
	self.view = view
	self.editing = (mode == "edit") and sheetName or nil
	self.editingDB = self.editing and ns.db or nil   -- the profile this edit belongs to
	self.editTab = self.editing and view.st.sheet or nil   -- (1.10.0-beta4) and the tab it was started on
	-- Under its window's search box unless the player moved it. A panel with
	-- no position would never draw, so one without any is always placed.
	if not f.moved or f:GetNumPoints() == 0 then
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", view.search, "BOTTOMLEFT", -4, -2)
	end
	if mode == "edit" then
		-- Load the sheet's saved filters so they can be adjusted.
		local list = view.isBank and ns.db.bankSheets or ns.db.sheets
		for _, s in ipairs(list) do if s.n == sheetName then view.st.filters = ns.CleanFilters(s.f); if view.search then view.search:SetText(view.st.filters.text) end end end
		f.sheetBox:SetText(sheetName)
	elseif mode == "new" then
		f.sheetBox:SetText("")
	end
	self:SyncFilters()
	f:Show()
	if mode == "new" then f.sheetBox:SetFocus() end
	ns:RefreshViews(true)
end

function Popups:ToggleFilters(view)
	if self.filter and self.filter:IsShown() and self.view == view and not self.editing then self.filter:Hide(); return end
	self:OpenFilters(view, "browse")
end

------------------------------------------------------------------------
-- Character picker: searchable, six rows visible, then scrolls.
------------------------------------------------------------------------
local ROW_H, VISIBLE = 26, 6

function Popups:BuildCharacters(view)
	local f = popupFrame("BagSmithCharPopup", view.frame, 280)
	self.chars = f
	local box = CreateFrame("EditBox", "BagSmithCharSearch", f, "SearchBoxTemplate")
	box:SetPoint("TOPLEFT", 10, -10); box:SetPoint("TOPRIGHT", -10, -10); box:SetHeight(22)
	box:SetAutoFocus(false)
	box:HookScript("OnTextChanged", function() Popups:FillCharacters() end)
	box:SetScript("OnEscapePressed", function() f:Hide() end)
	f.search = box
	local scroll = CreateFrame("ScrollFrame", "BagSmithCharScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -6)
	scroll:SetSize(240, ROW_H * VISIBLE)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(240, 1)
	scroll:SetScrollChild(child)
	ns.WheelStep(scroll, ROW_H * ns.WHEEL_ROWS)   -- (1.7.5-beta1) the wheel: two rows a notch (Init.lua, ns.WheelStep)
	f.child, f.rows = child, {}
	f:SetHeight(10 + 22 + 6 + ROW_H * VISIBLE + 10)
end

function Popups:FillCharacters()
	local f = self.chars
	local q = (f.search:GetText() or ""):lower()
	local list = ns:CachedCharacters()
	local i = 0
	for _, c in ipairs(list) do
		local hay = ((c.name or "") .. " " .. (c.class or "")):lower()
		if q == "" or hay:find(q, 1, true) then
			i = i + 1
			local r = f.rows[i]
			if not r then
				r = CreateFrame("Button", nil, f.child)
				r:SetSize(236, ROW_H)
				r:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
				r:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
				ns.HoverWash(r, 0.06)   -- Modern: a clearer hover
				r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(16, 16); r.icon:SetPoint("LEFT", 6, 0)
				-- (1.9.0-beta19, Shweep: "the alt dropdown") the chosen Font at the game's size, as the picker's button
				local face = ns.View and ns.View.FaceFont and ns.View.FaceFont() or nil
				r.name = fs(r, face); r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0); r.name:SetPoint("RIGHT", -60, 0)
				r.lvl = fs(r, face, "RIGHT"); r.lvl:SetPoint("RIGHT", -6, 0); r.lvl:SetWidth(54)
				r:SetScript("OnClick", function(btn) ns.Window.main:SetOwner(btn.isMe and nil or btn.key); f:Hide() end)
				f.rows[i] = r
			end
			r.key, r.isMe = c.key, c.isMe
			r.name:SetText(c.name or "?")
			r.name:SetTextColor(ns.ClassColor(c.class))
			r.lvl:SetText(("Lv %d%s"):format(c.level or 0, c.isMe and ", you" or ""))
			r.lvl:SetTextColor(Skins:Color("muted"))
			if CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[c.class] then
				r.icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
				r.icon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[c.class]))
			else r.icon:SetTexture(nil) end
			r:ClearAllPoints(); r:SetPoint("TOPLEFT", f.child, "TOPLEFT", 0, -(i - 1) * ROW_H)
			r:Show()
		end
	end
	for j = i + 1, #f.rows do f.rows[j]:Hide() end
	f.child:SetHeight(math.max(1, i * ROW_H))
end

function Popups:ToggleCharacters(view)
	if not self.chars then self:BuildCharacters(view) end
	if self.filter then self.filter:Hide() end
	local f = self.chars
	if f:IsShown() then f:Hide(); return end
	f:ClearAllPoints()
	f:SetPoint("TOP", view.charBtn, "BOTTOM", 0, -4)
	f.search:SetText("")
	self:FillCharacters()
	f:Show()
end

ns:OnSignal("ADDON_READY", function()
	ns:OnSignal("SETTINGS_CHANGED", function(key)
		if key ~= "customSections" and key ~= nil then return end
		-- A sheet being edited belongs to its profile: the edit ends only when
		-- that profile was switched, replaced or reset (not when the active
		-- profile is re-selected or another profile is deleted).
		if key == nil and Popups.editing and ns.db ~= Popups.editingDB then
			Popups.editing, Popups.editingDB = nil, nil
			for _, f in pairs(Popups.filters or {}) do if f:IsShown() then f:Hide() end end
		end
		-- (your sections' names, and the Section rule's choices, are read fresh)
		for _, f in pairs(Popups.filters or {}) do
			if f:IsShown() and f == Popups.filter then Popups:SyncFilters() end
		end
	end)
end)
