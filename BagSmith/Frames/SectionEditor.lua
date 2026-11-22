--[[
	Frames/SectionEditor.lua (1.10.0-beta3)

	The rule editor: a custom section's name and its rules on the left, and on the right what those rules would do
	right now, over your bags and bank. Nothing is changed until Save.

	The window works on a draft of the section's rules. The rows themselves, "+ Add a Rule" and the second window where
	a Type or Slot is ticked are Frames/RuleList.lua's (1.10.0-beta4: shared with the Filters window): this file is a
	rule list (E has ns.RuleList's methods) with a window around it. Save turns the draft back into rules
	(Core/Rules.lua) and hands them to Core/Sections.lua, which cleans them like any saved data.
--]]
local ADDON, ns = ...
local S = ns.Sections
local Skins = ns.Skins
local E = setmetatable({}, ns.RuleList)
ns.SectionEditor = E

local PAD, LW, RW, GAP, H = 14, 372, 250, 16, 470
local W = PAD + LW + GAP + RW + PAD
local TOP, BOTTOM = 136, 54                 -- above and below the two lists
local RULES_W, SHOWN_W = LW - 22, RW - 22   -- each list, beside its scroll bar
local PREVIEW_MAX = 40

local function qualityColor(q)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------
function E:Window()
	local f = self.frame
	if f then return f end
	f = CreateFrame("Frame", "BagSmithSectionEditor", UIParent, "BackdropTemplate")
	f:SetSize(W, H); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true)
	f:SetToplevel(true)   -- (it opens from Settings, which is in the same layer: a click brings either one forward)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	f:SetMovable(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	local function text(parent, template, width)
		local t = (parent or f):CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
		t:SetJustifyH("LEFT"); t:SetJustifyV("TOP")
		if width then t:SetWidth(width) end
		return t
	end
	f.title = text(f, "GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", 12, -12); f.title:SetText("Edit Section")
	-- the left side: the name, all or any, then the rules
	f.nameLabel = text(f); f.nameLabel:SetPoint("TOPLEFT", PAD, -40); f.nameLabel:SetText("Section name")
	f.edit = CreateFrame("EditBox", "BagSmithSectionEditorName", f, "InputBoxTemplate")
	f.edit:SetHeight(22); f.edit:SetPoint("TOPLEFT", PAD + 6, -56); f.edit:SetWidth(LW - 10)
	f.edit:SetAutoFocus(false); f.edit:SetMaxLetters(40)
	f.edit:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
	f.edit:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
	f.edit:SetScript("OnTextChanged", function(box, user) if user then f.err:SetText("") end end)
	f.ask = text(f); f.ask:SetPoint("TOPLEFT", PAD, -90); f.ask:SetText("Put an item in this section when it fits")
	f.all = ns.TextButton(f, "all of these", 92, function() E:SetMode("all") end); f.all:SetHeight(20); f.all:SetPoint("TOPLEFT", PAD, -108)
	f.any = ns.TextButton(f, "any one of these", 118, function() E:SetMode("any") end); f.any:SetHeight(20); f.any:SetPoint("LEFT", f.all, "RIGHT", 6, 0)
	f.all.tip = "An item must fit every rule below."
	f.any.tip = "An item only has to fit one of the rules below."
	f.rules = CreateFrame("ScrollFrame", "BagSmithSectionEditorRules", f, "UIPanelScrollFrameTemplate")
	f.rules:SetPoint("TOPLEFT", PAD, -TOP); f.rules:SetSize(RULES_W, H - TOP - BOTTOM)
	f.rulesChild = CreateFrame("Frame", nil, f.rules); f.rulesChild:SetSize(RULES_W, 1); f.rules:SetScrollChild(f.rulesChild)
	ns.WheelStep(f.rules, 40)
	f.rows = {}
	-- the rule list's own parts (Frames/RuleList.lua): where its rows go, and the window its second one belongs to
	self.rows, self.parent, self.width, self.host, self.pickerName = f.rows, f.rulesChild, RULES_W, f, "BagSmithSectionPicker"
	f.add = ns.TextButton(f.rulesChild, "+ Add a Rule", 104, function(b) E:AddMenu(b) end); f.add:SetHeight(22)
	f.hint = text(f.rulesChild, nil, RULES_W - 4); f.hint:SetText("Pick two or more on one line and either one counts.")
	f.order = text(f.rulesChild, nil, RULES_W - 4)
	-- (1.10.0-beta5) Show this section on [every sheet] [only some sheets], then the tabs to tick
	f.scopeLabel = text(f.rulesChild); f.scopeLabel:SetText("Show this section on")
	f.scopeAll = ns.TextButton(f.rulesChild, "every sheet", 84, function() E:SetScoped(false) end); f.scopeAll:SetHeight(20)
	f.scopeSome = ns.TextButton(f.rulesChild, "only some sheets", 116, function() E:SetScoped(true) end); f.scopeSome:SetHeight(20)
	f.scopeAll.tip = "This section is on every tab."
	f.scopeSome.tip = "This section is only on the tabs you tick. Everywhere else, its items stay in their usual section."
	f.sheetChips = {}
	f.scopeNote = text(f.rulesChild, nil, RULES_W - 4)
	-- the line between the two sides
	f.divider = f:CreateTexture(nil, "ARTWORK"); f.divider:SetSize(1, H - 40 - BOTTOM)
	f.divider:SetPoint("TOPLEFT", PAD + LW + GAP / 2, -40)
	-- the right side: what the rules do
	local rx = PAD + LW + GAP
	f.shownTitle = text(f, "GameFontNormal"); f.shownTitle:SetPoint("TOPLEFT", rx, -40); f.shownTitle:SetText("What this does")
	f.shownSub = text(f); f.shownSub:SetPoint("TOPLEFT", rx, -58); f.shownSub:SetText("Looking at your bags and bank")
	f.shown = CreateFrame("ScrollFrame", "BagSmithSectionEditorShown", f, "UIPanelScrollFrameTemplate")
	f.shown:SetPoint("TOPLEFT", rx, -80); f.shown:SetSize(SHOWN_W, H - 80 - BOTTOM)
	f.shownChild = CreateFrame("Frame", nil, f.shown); f.shownChild:SetSize(SHOWN_W, 1); f.shown:SetScrollChild(f.shownChild)
	ns.WheelStep(f.shown, 40)
	f.lines = {}
	-- the outline around "Fits, but stays somewhere else"
	f.box = CreateFrame("Frame", nil, f.shownChild, "BackdropTemplate")
	f.box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	-- the foot
	f.foot = text(f, nil, LW); f.foot:SetPoint("BOTTOMLEFT", PAD, 12); f.foot:SetText("Nothing changes in your bags until you save.")
	-- (two lines' room: what Save as Section... left behind can be a sentence)
	f.err = text(f, nil, LW); f.err:SetPoint("BOTTOMLEFT", PAD, 27); f.err:SetTextColor(1, 0.4, 0.4)
	f.save = ns.TextButton(f, "Save Section", 116, function() E:Save() end); f.save:SetHeight(24); f.save:SetPoint("BOTTOMRIGHT", -12, 12)
	f.cancel = ns.TextButton(f, "Cancel", 70, function() f:Hide() end); f.cancel:SetHeight(24); f.cancel:SetPoint("RIGHT", f.save, "LEFT", -6, 0)
	self:Shade()   -- while the second window is up, this one waits behind it
	f:SetScript("OnHide", function() f.edit:ClearFocus(); E:ClosePicker() end)
	f.classicSpec = ns.Classic.DialogSpec(f, { restore = function() Skins:ApplyBackdrop(f); local s = Skins:Current(); f:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1) end })
	Skins:Register(f, function(fr)
		Skins:ApplyBackdrop(fr); local s = Skins:Current(); fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)
		fr.title:SetTextColor(unpack(s.heading)); fr.shownTitle:SetTextColor(unpack(s.heading))
		for _, t in ipairs({ fr.nameLabel, fr.shownSub, fr.hint, fr.order, fr.foot }) do t:SetTextColor(unpack(s.muted)) end
		fr.ask:SetTextColor(unpack(s.text)); fr.scopeLabel:SetTextColor(unpack(s.text))
		fr.divider:SetColorTexture(s.line[1], s.line[2], s.line[3], 1)
		fr.box:SetBackdropColor(0, 0, 0, 0); fr.box:SetBackdropBorderColor(s.line[1], s.line[2], s.line[3], 1)
		ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
		if ns.Classic.DressScrollBar then
			ns.Classic:DressScrollBar(fr.rules, ns.Classic.IsOn()); ns.Classic:DressScrollBar(fr.shown, ns.Classic.IsOn())
		end
		if fr:IsShown() then E:Refresh() end
	end)
	f:Hide()
	-- Escape closes the second window first, if it's up, and this one the next time.
	ns:CloseOnEscape(f, function()
		if E.picker and E.picker:IsShown() then
			E:ClosePicker()
			local proxy = f.bsEscape   -- (the game hid this window's Escape stand-in: the window stays, so it goes back)
			if proxy then proxy.syncing = true; proxy:Show(); proxy.syncing = nil end
			return
		end
		f:Hide()
	end)
	ns:CombatWindow(f)
	self.frame = f
	return f
end

-- (1.10.0-beta5) every sheet, or only some; and a tab ticked or unticked
function E:SetScoped(on)
	local d = self.draft
	if not d then return end
	d.scoped = on and true or false
	self:Changed()
end
function E:ToggleSheet(id)
	local d = self.draft
	if not (d and id) then return end
	d.sheets = d.sheets or {}
	local at
	for i, name in ipairs(d.sheets) do if name == id then at = i end end
	if at then table.remove(d.sheets, at) else d.sheets[#d.sheets + 1] = id end
	self:Changed()
end
-- The tabs the draft is set to show on, or nil for every sheet.
function E:Sheets()
	local d = self.draft
	return d and d.scoped and S.CleanSheets(d.sheets) or nil
end
function E:SetMode(mode)
	if not self.draft then return end
	self.draft.mode = mode == "any" and "any" or "all"
	self:Refresh()
end
function E:Error(text)
	local f = self.frame
	if f then f.err:SetText(text or ""); f.err:SetTextColor(1, 0.4, 0.4) end
end
-- A word that isn't a mistake (what Save as Section... left behind), in the same place.
function E:Info(text)
	local f = self.frame
	if f then f.err:SetText(text or ""); f.err:SetTextColor(0.95, 0.78, 0.5) end
end

-- After anything in the draft changed, and after a rule was added (Frames/RuleList.lua calls these).
function E:Changed()
	self:Error("")
	self:Refresh()
end
function E:Added()
	local f = self.frame
	if f and f.rules then f.rules:SetVerticalScroll(math.max(0, (f.rulesHeight or 0) - (H - TOP - BOTTOM))) end
end

------------------------------------------------------------------------
-- What the rules do: the list on the right
------------------------------------------------------------------------
local function shownLine(f, i)
	local l = f.lines[i]
	if l then return l end
	l = CreateFrame("Frame", nil, f.shownChild); l:SetSize(SHOWN_W, 20); l:EnableMouse(true)
	l.icon = l:CreateTexture(nil, "ARTWORK"); l.icon:SetSize(18, 18); l.icon:SetPoint("TOPLEFT", 4, -1)
	l.name = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); l.name:SetJustifyH("LEFT"); l.name:SetJustifyV("TOP")
	l.why = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); l.why:SetJustifyH("LEFT"); l.why:SetJustifyV("TOP")
	l.count = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); l.count:SetPoint("TOPRIGHT", -6, -3)
	l:SetScript("OnEnter", function(self)
		if not (self.id and ns.TooltipsOK()) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.link or ("item:" .. self.id)); GameTooltip:Show()
	end)
	l:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.lines[i] = l
	return l
end
local function byName(a, b) return (a.name or "") < (b.name or "") end
function E:RefreshShown(s)
	local f, d = self.frame, self.draft
	local R = ns.Rules
	local rules = R.Clean(self:Rules())
	local sheets = self:Sheets()
	local here, elsewhere = S:PreviewRules(rules, d.id, sheets)
	f.shownSub:SetText(sheets and ("Looking at your bags and bank, on %s"):format(S:SheetsText(sheets)) or "Looking at your bags and bank")
	table.sort(here, byName)
	table.sort(elsewhere, function(a, b) return byName(a.rec, b.rec) end)
	self.shown = { here = here, elsewhere = elsewhere, rules = rules }
	local n, y = 0, 0
	local function line(kind, textValue, extra)
		n = n + 1
		local l = shownLine(f, n)
		l.kind, l.id, l.link = kind, nil, nil
		l.icon:Hide(); l.why:Hide(); l.count:Hide()
		l.name:ClearAllPoints(); l.name:SetWordWrap(kind == "note"); l.name:SetText(textValue)
		local h = 20
		if kind == "head" then
			l.name:SetPoint("TOPLEFT", 4, -3); l.name:SetWidth(SHOWN_W - 44); l.name:SetTextColor(unpack(s.heading))
			l.count:SetText(tostring(extra)); l.count:SetTextColor(unpack(s.text)); l.count:Show()
		elseif kind == "note" then
			l.name:SetPoint("TOPLEFT", 6, -2); l.name:SetWidth(SHOWN_W - 12); l.name:SetTextColor(unpack(s.muted))
			h = 6 + math.max(13, math.ceil(l.name:GetStringHeight() or 13))
		else
			local rec = extra.rec
			l.id, l.link = rec.itemID, rec.link
			l.icon:SetTexture(rec.icon); l.icon:Show()
			l.name:SetPoint("TOPLEFT", 28, -3); l.name:SetWidth(SHOWN_W - 34); l.name:SetTextColor(qualityColor(rec.quality))
			if extra.why then
				l.why:ClearAllPoints(); l.why:SetPoint("TOPLEFT", 28, -16); l.why:SetWidth(SHOWN_W - 34); l.why:SetWordWrap(false)
				l.why:SetText(extra.why); l.why:SetTextColor(unpack(s.muted)); l.why:Show()
				h = 32
			end
		end
		l:SetHeight(h); l:ClearAllPoints(); l:SetPoint("TOPLEFT", f.shownChild, "TOPLEFT", 0, -y); l:Show()
		y = y + h
		return l
	end
	-- goes in this section
	line("head", "Goes in this section", #here)
	if #here == 0 then
		local usable = 0
		for _, r in ipairs(d.rows) do if self:RowUsable(r) then usable = usable + 1 end end
		local words
		if not rules then words = #d.rows == 0 and "Nothing goes here yet. Add a rule to fill it by itself." or "Nothing goes here yet. Pick something on a rule."
		elseif d.mode ~= "any" and usable > 1 then words = "Nothing goes here yet. Pick something else on a rule, or switch to any one of these."
		else words = "Nothing in your bags or bank goes here right now." end
		line("note", words)
	end
	for i = 1, math.min(#here, PREVIEW_MAX) do
		local rec = here[i]
		line("item", rec.name or ("Item " .. tostring(rec.itemID)), { rec = rec })
	end
	if #here > PREVIEW_MAX then line("note", ("and %d more"):format(#here - PREVIEW_MAX)) end
	-- fits, but stays somewhere else: in its own outline
	y = y + 10
	local top = y
	y = y + 4
	line("head", "Fits, but stays somewhere else", #elsewhere)
	if #elsewhere == 0 then line("note", rules and "Nothing. Everything that fits goes here." or "Nothing yet.") end
	for i = 1, math.min(#elsewhere, PREVIEW_MAX) do
		local e = elsewhere[i]
		line("item", e.rec.name or ("Item " .. tostring(e.rec.itemID)), { rec = e.rec, why = e.why })
	end
	if #elsewhere > PREVIEW_MAX then line("note", ("and %d more"):format(#elsewhere - PREVIEW_MAX)) end
	y = y + 4
	f.box:ClearAllPoints(); f.box:SetPoint("TOPLEFT", f.shownChild, "TOPLEFT", 0, -top); f.box:SetSize(SHOWN_W, y - top)
	f.box:SetBackdropColor(0, 0, 0, 0); f.box:SetBackdropBorderColor(s.line[1], s.line[2], s.line[3], 1)
	for i = n + 1, #f.lines do f.lines[i]:Hide() end
	f.shownChild:SetHeight(math.max(1, y))
	local view = H - 80 - BOTTOM
	if f.shown.ScrollBar then f.shown.ScrollBar:SetShown(y > view) end
	if (f.shown:GetVerticalScroll() or 0) > math.max(0, y - view) then f.shown:SetVerticalScroll(math.max(0, y - view)) end
end

-- "If an item fits two of your sections, the one higher on your list gets it. Enchanting Mats is above this one."
local function orderNote(d)
	local customs = S:Customs()
	local at = d.id and S:Priority(d.id) or (#customs + 1)
	local above, others = {}, 0
	for i, c in ipairs(customs) do
		if c.id ~= d.id and c.rules then
			others = others + 1
			if i < at then above[#above + 1] = c.name end
		end
	end
	if others == 0 then return "" end
	local words = "If an item fits two of your sections, the one higher on your list gets it."
	if #above == 1 then return words .. (" %s is above this one."):format(above[1]) end
	if #above > 1 then return words .. (" %d of your sections are above this one."):format(#above) end
	return words .. " This one is first."
end

function E:Refresh()
	local f, d = self.frame, self.draft
	if not (f and d and f:IsShown()) then return end
	-- only for the profile and the section it was opened for
	if ns.db ~= self.db or (d.id and not S:Custom(d.id)) then f:Hide() return end
	local s = Skins:Current()
	f.all:SetActive(d.mode ~= "any"); f.any:SetActive(d.mode == "any")
	local y, lists = self:Layout(s)
	f.add:ClearAllPoints(); f.add:SetPoint("TOPLEFT", f.rulesChild, "TOPLEFT", 0, -y)
	f.add:SetAlpha(#d.rows >= ns.Rules.MAX_ROWS and 0.5 or 1)
	y = y + 30
	f.hint:SetShown(lists > 0)
	if lists > 0 then f.hint:ClearAllPoints(); f.hint:SetPoint("TOPLEFT", f.rulesChild, "TOPLEFT", 0, -y); y = y + 16 end
	-- (1.10.0-beta5) where the section shows
	y = y + 8
	f.scopeLabel:ClearAllPoints(); f.scopeLabel:SetPoint("TOPLEFT", f.rulesChild, "TOPLEFT", 0, -(y + 4))
	f.scopeAll:ClearAllPoints(); f.scopeAll:SetPoint("TOPLEFT", f.rulesChild, "TOPLEFT", 124, -y)
	f.scopeSome:ClearAllPoints(); f.scopeSome:SetPoint("LEFT", f.scopeAll, "RIGHT", 6, 0)
	f.scopeAll:SetActive(not d.scoped); f.scopeSome:SetActive(d.scoped and true or false)
	y = y + 26
	local used = 0
	if d.scoped then
		local choices, covered = S:TabChoices(), {}
		for _, t in ipairs(choices) do covered[t.id] = true end
		-- (a sheet it names that isn't one of your tabs any more can still be unticked)
		for _, id in ipairs(d.sheets or {}) do if not covered[id] then choices[#choices + 1] = { id = id, label = S:TabLabel(id) } end end
		local x = 0
		for i, t in ipairs(choices) do
			local c = f.sheetChips[i]
			if not c then
				c = ns.TextButton(f.rulesChild, "", 40, function(b) E:ToggleSheet(b.sheet) end); c:SetHeight(20)
				f.sheetChips[i] = c
			end
			local on = false
			for _, name in ipairs(d.sheets or {}) do if name == t.id then on = true end end
			c.sheet = t.id
			c.label:SetText(t.label)
			c:SetActive(on)
			local w = math.min(RULES_W - 4, math.max(30, math.ceil(c.label:GetStringWidth() or 0) + 16))
			c:SetWidth(w)
			if x > 0 and x + w > RULES_W - 4 then x = 0; y = y + 24 end
			c:ClearAllPoints(); c:SetPoint("TOPLEFT", f.rulesChild, "TOPLEFT", x, -y); c:Show()
			x = x + w + 4
			used = i
		end
		y = y + 26
		local sheets = self:Sheets()
		f.scopeNote:SetText(sheets and "On your other sheets, these items stay in their usual section." or "Tick at least one, or this section shows on every sheet.")
		if sheets then f.scopeNote:SetTextColor(unpack(s.muted)) else f.scopeNote:SetTextColor(0.95, 0.6, 0.45) end
		f.scopeNote:ClearAllPoints(); f.scopeNote:SetPoint("TOPLEFT", f.rulesChild, "TOPLEFT", 0, -y)
		y = y + 4 + math.max(13, math.ceil(f.scopeNote:GetStringHeight() or 13))
	end
	f.scopeNote:SetShown(d.scoped and true or false)
	for i = used + 1, #f.sheetChips do f.sheetChips[i]:Hide() end
	local note = orderNote(d)
	f.order:SetShown(note ~= "")
	if note ~= "" then
		f.order:SetText(note); f.order:ClearAllPoints(); f.order:SetPoint("TOPLEFT", f.rulesChild, "TOPLEFT", 0, -(y + 4))
		y = y + 4 + math.max(13, math.ceil(f.order:GetStringHeight() or 13))
	end
	f.rulesHeight = y
	f.rulesChild:SetHeight(math.max(1, y))
	local view = H - TOP - BOTTOM
	if f.rules.ScrollBar then f.rules.ScrollBar:SetShown(y > view) end
	if (f.rules:GetVerticalScroll() or 0) > math.max(0, y - view) then f.rules:SetVerticalScroll(math.max(0, y - view)) end
	self:RefreshShown(s)
end

------------------------------------------------------------------------
-- Opening and saving
------------------------------------------------------------------------
-- id: the section to edit; nil for a new one. start (1.10.0-beta4, for a new one): { name, rules, note }, what the
-- Filters window's Save as Section... hands over.
function E:Open(id, start)
	if not ns.Rules then return end
	local c = id and S:Custom(id) or nil
	if id and not c then return end
	local f = self:Window()
	self:ClosePicker()
	self.db = ns.db
	if c then start = nil end
	local d = self:DraftFrom(c and c.rules or (start and start.rules))
	d.id = c and c.id or nil
	-- (1.10.0-beta5) the sheets it's set to show on
	d.sheets, d.scoped = {}, false
	if c and c.sheets then
		for i, name in ipairs(c.sheets) do d.sheets[i] = name end
		d.scoped = true
	end
	self.draft = d
	self:ClearBoxes()
	f.title:SetText(c and "Edit Section" or "New Section")
	f.save.label:SetText(c and "Save Section" or "Create Section")
	f.edit:SetText(c and c.name or (start and start.name) or "")
	f.err:SetText("")
	if start and start.note then self:Info(start.note) end
	f.rules:SetVerticalScroll(0); f.shown:SetVerticalScroll(0)
	if ns.Classic then ns.Classic:RefreshTitle(f) end
	f:Show()
	if f.Raise then f:Raise() end   -- in front of Settings, where it was opened from
	if not c then f.edit:SetFocus() end
	self:Refresh()
	return f
end
function E:Save()
	local f, d = self.frame, self.draft
	if not (f and d) then return end
	if ns.db ~= self.db or (d.id and not S:Custom(d.id)) then f:Hide() return end   -- the profile changed, or the section is gone
	local rules = ns.Rules.Clean(self:Rules())
	local id = d.id
	if id then
		local ok, why = S:Rename(id, f.edit:GetText())
		if not ok then return self:Error(why) end
	else
		local why
		id, why = S:Create(f.edit:GetText())
		if not id then return self:Error(why) end
	end
	if rules or S:Rules(id) then S:SetRules(id, rules) end
	-- (1.10.0-beta5) where it shows: only written when it changes
	local sheets = self:Sheets()
	local now = S:Sheets(id)
	if table.concat(sheets or {}, "\1") ~= table.concat(now or {}, "\1") then S:SetSheets(id, sheets) end
	f:Hide()
	return id
end
function S:EditSection(id) return E:Open(id) end

ns:OnSignal("ADDON_READY", function()
	-- the list on the right follows your bags, and your other sections, while the window is up
	local function follow() if E.frame and E.frame:IsShown() then E:Refresh() end end
	ns:OnSignal("ITEMS_CHANGED", follow)
	ns:OnSignal("SETTINGS_CHANGED", function(key) if key == "customSections" then follow() end end)
	ns:OnSignal("PROFILE_ACTIVATED", function() if E.frame and E.frame:IsShown() then E.frame:Hide() end end)
end)
