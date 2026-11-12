--[[
	BagSmith - Frames/Popups.lua
	Filter panel (checkboxes + save as sheet) and the character picker.
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

local function checkbox(parent, label, onChange)
	local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	c:SetSize(22, 22)
	c.label = fs(c)
	c.label:SetPoint("LEFT", c, "RIGHT", 2, 0)
	c.label:SetText(label)
	c:SetScript("OnClick", function(self) onChange(self:GetChecked() and true or false) end)
	return c
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
-- Filter panel
------------------------------------------------------------------------
local QUALITY = { { 0, "Poor" }, { 1, "Common" }, { 2, "Uncommon" }, { 3, "Rare" }, { 4, "Epic" }, { 5, "Legendary" } }
local BIND = { "BoE", "BoP", "None" }

local FW, FPAD, ROWH = 480, 14, 26
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
	f.wherePool = {}

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
	end)
	-- The drag bar covers the top of the panel; the close button must sit above it or the bar takes its clicks.
	close:SetFrameLevel(drag:GetFrameLevel() + 2)
	f.closeBtn, f.dragBar = close, drag
	local y = -38

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

	local host = f
	local function section(text)
		y = y - 6
		local s = fs(host, "GameFontNormal"); s:SetPoint("TOPLEFT", FPAD, y); s:SetText(text); tint(s, "accent"); y = y - 22
	end
	local function row(items, groupKey, valueOf, labelOf)
		local x, usable = FPAD, FW - FPAD * 2
		for _, it in ipairs(items) do
			local key, label = valueOf(it), labelOf(it)
			local c = checkbox(host, label, function(on)
				local set = Popups.view.st.filters[groupKey]
				if on then set[key] = true else set[key] = nil end
				ns:RefreshViews(true)
			end)
			local w = 26 + c.label:GetStringWidth() + 14
			if x + w > FPAD + usable then x = FPAD; y = y - ROWH end
			c:SetPoint("TOPLEFT", x, y + 2)
			c.groupKey, c.key = groupKey, key
			f.checks[#f.checks + 1] = c
			x = x + w
		end
		y = y - ROWH
	end
	section("Rarity")
	row(QUALITY, "q", function(it) return it[1] end, function(it) return it[2] end)
	section("Type / Sections")
	-- The Category row is refilled in place (FillCategory) whenever custom
	-- sections or the profile change, reusing its checkboxes. Everything
	-- below it rides a sub-frame moved to fit the number of category rows.
	f.catY, f.catPool, f.catRows = y, {}, 1
	local catAfter = CreateFrame("Frame", nil, f)
	catAfter:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y - ROWH)
	catAfter:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, y - ROWH)
	f.catAfter, f.catAfterTop = catAfter, y - ROWH
	host = catAfter
	y = 0
	section("Bind")
	row(BIND, "bd", function(it) return it end, function(it) return it end)
	section("Where")
	-- The Where row is rebuilt in place when the bag set changes, reusing
	-- its checkboxes, so the panel itself is never recreated.
	f.whereY = y
	-- Everything below Where sits on a frame that FillWhere moves up or down
	-- to match the number of bag rows, so no space is reserved.
	local after = CreateFrame("Frame", nil, catAfter)
	after:SetPoint("TOPLEFT", catAfter, "TOPLEFT", 0, y - ROWH)
	after:SetPoint("TOPRIGHT", catAfter, "TOPRIGHT", 0, y - ROWH)
	f.after = after
	f.afterTop = y - ROWH
	host = after   -- following widgets are parented to the sub-frame
	y = 0
	section("Other")
	local newC = checkbox(host, "New Items Only", function(on) Popups.view.st.filters.new = on; ns:RefreshViews(true) end)
	newC:SetPoint("TOPLEFT", FPAD, y + 2); newC.groupKey = "new"
	f.checks[#f.checks + 1] = newC
	y = y - ROWH - 4

	-- Age window: two single-digit fields, whole hours 0 to 9.
	section("Age")
	local ageLabel = fs(host); ageLabel:SetPoint("TOPLEFT", FPAD, y - 4); ageLabel:SetText("Time in your bags between")
	tint(ageLabel, "text")
	local function ageBox(anchor, key)
		local b = CreateFrame("EditBox", nil, host, "InputBoxTemplate")
		b:SetSize(26, 22); b:SetAutoFocus(false); b:SetMaxLetters(1)
		if b.SetNumeric then b:SetNumeric(true) end
		b:SetJustifyH("CENTER")
		b:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
		b:SetScript("OnTextChanged", function(box)
			if Popups.syncing or not Popups.view then return end
			local v = tonumber(box:GetText())
			if v and (v < 0 or v > 9 or v ~= math.floor(v)) then v = nil end
			Popups.view.st.filters[key] = v
			ns:RefreshViews(true)
		end)
		b:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
		b:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
		return b
	end
	f.ageMin = ageBox(ageLabel, "ageMin")
	local andLabel = fs(host); andLabel:SetPoint("LEFT", f.ageMin, "RIGHT", 8, 0); andLabel:SetText("and")
	tint(andLabel, "text")
	f.ageMax = ageBox(andLabel, "ageMax")
	local hrs = fs(host); hrs:SetPoint("LEFT", f.ageMax, "RIGHT", 8, 0); hrs:SetText("hours")
	tint(hrs, "text")
	local ageHint = fs(host); ageHint:SetPoint("TOPLEFT", FPAD, y - 30); tint(ageHint, "muted")
	ageHint:SetText("Whole hours from 0 (just now) to 9. Leave both empty for any age.")
	y = y - 56

	-- Sheet section: "Save as sheet" when browsing or creating, rename/save/delete when editing.
	local line = host:CreateTexture(nil, "ARTWORK"); line:SetPoint("TOPLEFT", FPAD, y + 6); line:SetPoint("TOPRIGHT", -FPAD, y + 6); line:SetHeight(1); tint(line, "line", true)
	y = y - 8
	f.sheetLabel = fs(host, "GameFontNormal"); f.sheetLabel:SetPoint("TOPLEFT", FPAD, y); tint(f.sheetLabel, "accent")
	y = y - 24
	local box = CreateFrame("EditBox", nil, host, "InputBoxTemplate")
	box:SetSize(FW - FPAD * 2 - 130, 24); box:SetAutoFocus(false)
	box:SetPoint("TOPLEFT", FPAD + 6, y)
	box:SetScript("OnEnterPressed", function() Popups:CommitSheet() end)
	box:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
	f.sheetBox = box
	local save = ns.TextButton(host, "Save as Sheet", 116, function() Popups:CommitSheet() end)
	save:SetHeight(24); save:SetPoint("LEFT", box, "RIGHT", 8, 0)
	f.saveBtn = save
	local hint = fs(host); hint:SetPoint("TOPLEFT", FPAD, y - 28); tint(hint, "muted")
	hint:SetWidth(FW - FPAD * 2); hint:SetWordWrap(true)
	f.saveHint = hint
	y = y - 56
	local clear = ns.TextButton(f, "Clear All", 80, function()
		local v = Popups.view
		v.st.filters = ns.EmptyFilters(); if v.search then v.search:SetText("") end
		Popups:SyncFilters(); ns:RefreshViews(true)
	end)
	clear:SetHeight(24); clear:SetPoint("BOTTOMLEFT", FPAD, FPAD)
	f.deleteBtn = ns.TextButton(f, "Delete Sheet", 100, function(btn)
		local v, name = Popups.view, Popups.editing
		if not name then return end
		ns.Confirm(btn, ("Delete the sheet \"%s\"?"):format(name), function()
			ns:DeleteSheet(name, v); f:Hide()
		end)
	end)
	f.deleteBtn:SetHeight(24); f.deleteBtn:SetPoint("LEFT", clear, "RIGHT", 8, 0)
	local done = ns.TextButton(f, "Done", 70, function() f:Hide() end)
	done:SetHeight(24); done:SetPoint("BOTTOMRIGHT", -FPAD, FPAD)
	after:SetHeight(-y)
	f.afterHeight = -y
	f.bottomPad = FPAD + 24 + 8
	Popups.filterFrameHeight = function(panel, rows)
		return -panel.catAfterTop + ((panel.catRows or 1) - 1) * ROWH - panel.afterTop + ((rows or panel.whereRows or 1) - 1) * ROWH + panel.afterHeight + panel.bottomPad
	end
	ns.Classic:DressButtons(f)
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
local function bagSignatureFor(view)
	return tostring(ns.ui.owner) .. "|" .. tostring(view.st and view.st.sheet) .. "|" .. table.concat(whereBags(view), "|")
end

function Popups:FillWhere(f)
	local view = f.view
	local sig = bagSignatureFor(view)
	if f.whereSig == sig then return end
	f.whereSig = sig
	local bags = whereBags(view)
	-- drop old Where checks from the sync list
	local kept = {}
	for _, c in ipairs(f.checks) do if c.groupKey ~= "w" then kept[#kept + 1] = c end end
	f.checks = kept
	local x, y, usable = FPAD, f.whereY, FW - FPAD * 2
	for i, name in ipairs(bags) do
		local c = f.wherePool[i]
		if not c then
			c = checkbox(f.catAfter, name, function(on)
				local set = Popups.view.st.filters.w
				if on then set[c.key] = true else set[c.key] = nil end
				ns:RefreshViews(true)
			end)
			c.groupKey = "w"
			f.wherePool[i] = c
		end
		c.key = name
		c.label:SetText(name)
		local w = 26 + c.label:GetStringWidth() + 14
		if x + w > FPAD + usable then x = FPAD; y = y - ROWH end
		c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, y + 2); c:Show()
		f.checks[#f.checks + 1] = c
		x = x + w
	end
	for j = #bags + 1, #f.wherePool do f.wherePool[j]:Hide() end
	local rows = 1 + math.floor((f.whereY - y) / ROWH + 0.5)
	f.whereRows = rows
	Popups.SizeCatAfter(f)
	f.after:ClearAllPoints()
	f.after:SetPoint("TOPLEFT", f.catAfter, "TOPLEFT", 0, f.afterTop - (rows - 1) * ROWH)
	f.after:SetPoint("TOPRIGHT", f.catAfter, "TOPRIGHT", 0, f.afterTop - (rows - 1) * ROWH)
	f:SetHeight(Popups.filterFrameHeight(f, rows))
end

-- The Category row: the built-in categories plus the custom sections of the
-- active profile, with their current names. Refilled in place when they
-- change; a checkbox for a section that no longer exists does nothing.
-- (length-prefixed fields: no name can imitate another list)
local function categorySignature()
	local name = ns.profileName or ""
	local parts = { #name .. ":" .. name }
	for _, c in ipairs(ns.Sections and ns.Sections:Customs() or {}) do
		parts[#parts + 1] = #c.id .. ":" .. c.id .. #c.name .. ":" .. c.name
	end
	return table.concat(parts)
end
local function validCategory(key) return ns.CAT_LABEL[key] ~= nil or (ns.Sections and ns.Sections:IsCustom(key)) end
function Popups:FillCategory(f)
	local sig = categorySignature()
	if f.catSig == sig then return end
	f.catSig = sig
	local cats = {}
	for _, c in ipairs(ns.CATS) do cats[#cats + 1] = c end
	for _, c in ipairs(ns.Sections and ns.Sections:Customs() or {}) do cats[#cats + 1] = c.id end
	local kept = {}
	for _, c in ipairs(f.checks) do if c.groupKey ~= "cat" then kept[#kept + 1] = c end end
	f.checks = kept
	local x, y, usable = FPAD, f.catY, FW - FPAD * 2
	for i, key in ipairs(cats) do
		local c = f.catPool[i]
		if not c then
			c = checkbox(f, "", function(on)
				if not validCategory(c.key) then c:SetChecked(false) return end   -- a section that's gone
				local set = Popups.view.st.filters.cat
				if on then set[c.key] = true else set[c.key] = nil end
				ns:RefreshViews(true)
			end)
			c.groupKey = "cat"
			f.catPool[i] = c
		end
		c.key = key
		-- (1.7.0-beta10) a built-in category by its own name: Gear here covers all gear, split or not (not "Gear: Other")
		c.label:SetText(ns.CAT_LABEL[key] or (ns.Sections and ns.Sections:Label(key)) or key)
		local w = 26 + c.label:GetStringWidth() + 14
		if x + w > FPAD + usable then x = FPAD; y = y - ROWH end
		c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, y + 2); c:Show()
		f.checks[#f.checks + 1] = c
		x = x + w
	end
	for j = #cats + 1, #f.catPool do f.catPool[j]:Hide() end
	local rows = 1 + math.floor((f.catY - y) / ROWH + 0.5)
	f.catRows = rows
	f.catAfter:ClearAllPoints()
	f.catAfter:SetPoint("TOPLEFT", f, "TOPLEFT", 0, f.catAfterTop - (rows - 1) * ROWH)
	f.catAfter:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, f.catAfterTop - (rows - 1) * ROWH)
	Popups.SizeCatAfter(f)
	f:SetHeight(Popups.filterFrameHeight(f, f.whereRows or 1))
end
-- The sub-frame below Category must have a height: the client draws nothing
-- on a frame with no size, children included.
function Popups.SizeCatAfter(f)
	local h = -f.afterTop + ((f.whereRows or 1) - 1) * ROWH + (f.afterHeight or 0) + 8
	f.catAfter:SetHeight(math.max(8, h))
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

function Popups:SyncFilters()
	local f = self.filter
	if not f then return end
	local v = self.view or ns.Window.main
	local filters = v.st.filters
	for _, c in ipairs(f.checks) do
		if c.groupKey == "new" then c:SetChecked(filters.new)
		else c:SetChecked(filters[c.groupKey][c.key] and true or false) end
	end
	self.syncing = true
	f.search:SetText(filters.text or "")
	f.ageMin:SetText(filters.ageMin and tostring(filters.ageMin) or "")
	f.ageMax:SetText(filters.ageMax and tostring(filters.ageMax) or "")
	self.syncing = false
	if self.editing then
		f.title:SetText((v.isBank and "Bank Sheet: " or "Sheet: ") .. self.editing)
		f.sheetLabel:SetText("Edit Sheet")
		f.saveBtn.label:SetText("Save Changes")
		f.saveHint:SetText("Change the name or the filters above, then save. Delete removes the tab.")
		f.deleteBtn:Show()
	else
		f.title:SetText(v.isBank and "Bank Filters" or "Filters")
		f.sheetLabel:SetText("Save as a Sheet")
		f.saveBtn.label:SetText("Save as Sheet")
		f.saveHint:SetText("Name the current search and filters to keep them as a tab.")
		f.deleteBtn:Hide()
	end
	ns.Classic:Retitle(f, f.title:GetText())
end

-- mode: nil/"browse" (Filter button), "new" (plus next to the tabs), "edit" (pencil on a custom tab)
function Popups:OpenFilters(view, mode, sheetName)
	-- One panel per window, built once; only its Where row changes with the bags.
	self.filters = self.filters or {}
	for other, panel in pairs(self.filters) do if other ~= view then panel:Hide() end end
	if not self.filters[view] then self:BuildFilters(view) end
	self.filter = self.filters[view]
	if self.chars then self.chars:Hide() end
	local f = self.filter
	self.view = view
	self:FillCategory(f)
	self:FillWhere(f)
	self.editing = (mode == "edit") and sheetName or nil
	self.editingDB = self.editing and ns.db or nil   -- the profile this edit belongs to
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
				r.name = fs(r); r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0); r.name:SetPoint("RIGHT", -60, 0)
				r.lvl = fs(r, nil, "RIGHT"); r.lvl:SetPoint("RIGHT", -6, 0); r.lvl:SetWidth(54)
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
		for _, f in pairs(Popups.filters or {}) do
			if f:IsShown() then Popups:FillCategory(f); Popups:SyncFilters() end
		end
	end)
end)
