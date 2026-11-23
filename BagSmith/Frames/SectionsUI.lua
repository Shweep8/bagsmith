--[[
	Frames/SectionsUI.lua

	The UI around custom sections (Core/Sections.lua):
	- a small menu (ns.ShowMenu) and a name prompt (ns.Prompt);
	- the item menu: Alt+Left-click an item, or the Move to Section
	  keybinding (Move to Section, Reset to Its Original Section, Favorite, Mark as
	  Junk, Track as Currency);
	- section titles (Sections By Section): drop a dragged item on one to move it
	  there (the item goes straight back to its slot); right-click one for Show
	  at Vendor / Show at AH, and Rename / Delete for your own sections;
	- the moved-items window (Settings > Custom Sections > Manage...).
--]]
local ADDON, ns = ...
local S = ns.Sections
local Skins = ns.Skins

------------------------------------------------------------------------
-- A small menu. items: { text, onClick, checked, disabled, title, gap }
------------------------------------------------------------------------
local MENU_W, ROW_H, MENU_MAX = 220, 20, 300
-- (1.8.0) it.font: the row's text in that font file, at the row's size. Without one, the text goes back to its font
-- object's own face: a face set directly stays until set again (the font object alone doesn't undo it, beta2's bug:
-- Default Font kept the last font picked), and rows are reused.
-- (1.9.0-beta19, after FlareUI 6.10.1) A font the game hasn't drawn yet loads only when a drawn text asks for it: until
-- then SetFont answers false and the text keeps its old face. Such a text asks again every half second, up to 30
-- seconds, until the game has the file (a row reused for another face drops its old wish).
local pendingFaces = setmetatable({}, { __mode = "k" })
local faceTicks
local function retryFaces()
	faceTicks = (faceTicks or 0) + 1
	for fs, want in pairs(pendingFaces) do
		local ok, res = pcall(fs.SetFont, fs, want[1], want[2], want[3])
		if ok and res ~= false then pendingFaces[fs] = nil end
	end
	if next(pendingFaces) and faceTicks < 60 then
		C_Timer.After(0.5, retryFaces)
	else
		for fs in pairs(pendingFaces) do pendingFaces[fs] = nil end
		faceTicks = nil
	end
end
ns.MENU_FACES_PENDING = pendingFaces   -- (for the tests)
function ns.MenuFace(fs, path, object)
	if not (fs.SetFont and fs.GetFont) then return end
	pendingFaces[fs] = nil
	local obj = object and _G[object]
	local objPath, objSize, objFlags
	if obj and obj.GetFont then objPath, objSize, objFlags = obj:GetFont() end
	local _, size, flags = fs:GetFont()
	size, flags = objSize or size, objFlags or flags
	path = path or objPath
	if not (path and size) then return end
	local ok, res = pcall(fs.SetFont, fs, path, size, flags or "")
	if ok and res == false then
		pendingFaces[fs] = { path, size, flags or "" }
		if faceTicks then faceTicks = 0   -- (already asking: a fresh 30 seconds)
		elseif C_Timer and C_Timer.After then faceTicks = 0; C_Timer.After(0.5, retryFaces) end
	end
end
function ns.ShowMenu(items, anchor, keepPlace)
	local m = ns.menuFrame
	if not m then
		m = CreateFrame("Frame", "BagSmithMenu", UIParent, "BackdropTemplate")
		m:SetFrameStrata("FULLSCREEN_DIALOG"); m:SetClampedToScreen(true); m:EnableMouse(true)
		m.rows = {}
		-- A click anywhere else closes it.
		m.catcher = CreateFrame("Button", nil, UIParent)
		-- (1.5.0-beta3) just under the menu, above dialogs like Settings: a click anywhere else always lands here
		m.catcher:SetAllPoints(UIParent); m.catcher:SetFrameStrata("FULLSCREEN")
		m.catcher:RegisterForClicks("AnyUp")
		m.catcher:SetScript("OnClick", function() m:Hide() end)
		m.catcher:Hide()
		m:EnableKeyboard(true)
		m:SetScript("OnKeyDown", function(self, key)
			if key == "ESCAPE" then self:SetPropagateKeyboardInput(false); self:Hide()
			else self:SetPropagateKeyboardInput(true) end
		end)
		m:SetScript("OnHide", function(self) self.catcher:Hide(); self.owner = nil end)
		-- Opened from an item, its dots or a section title: when that's no
		-- longer on screen (the window closed), the menu goes too.
		m:SetScript("OnUpdate", function(self)
			if self.owner and not (self.owner.IsVisible and self.owner:IsVisible()) then self:Hide() end
		end)
		m.classicSpec = { template = "DialogBorderTemplate",
			restore = function() Skins:ApplyBackdrop(m); local s = Skins:Current(); m:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1) end }
		Skins:Register(m, function(fr)
			Skins:ApplyBackdrop(fr); local s = Skins:Current(); fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)
			ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
		end)
		m:Hide()
		ns.menuFrame = m
	end
	local classic = ns.Classic and ns.Classic.IsOn and ns.Classic.IsOn()
	local pad = classic and 14 or 6
	if m.items ~= items then m.listOffset, m.offset = nil, 0 end
	m.items, m.pad = items, pad
	if not keepPlace then m.owner = anchor end
	-- Width: wide enough for the longest row, up to MENU_MAX; a row still
	-- too long wraps to two lines.
	m.measure = m.measure or m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	local widest = 0
	for _, it in ipairs(items) do
		if it.text then
			m.measure:SetFontObject(it.big and "GameFontNormal" or "GameFontHighlightSmall")
			ns.MenuFace(m.measure, it.font, it.big and "GameFontNormal" or "GameFontHighlightSmall")
			m.measure:SetText(it.text)
			widest = math.max(widest, m.measure:GetStringWidth() + (it.icon and 28 or 22) + 10)
		end
	end
	m.measure:SetText("")
	local innerW = math.max(MENU_W - 12, math.min(MENU_MAX, math.ceil(widest)))
	local textRoom = innerW - 32
	for _, it in ipairs(items) do
		local need = 0
		if it.text then
			m.measure:SetFontObject(it.big and "GameFontNormal" or "GameFontHighlightSmall")
			ns.MenuFace(m.measure, it.font, it.big and "GameFontNormal" or "GameFontHighlightSmall")
			m.measure:SetText(it.text); need = m.measure:GetStringWidth()
		end
		it.wrap = need > textRoom
	end
	m.measure:SetText("")
	-- Rows marked group = true (a run of them, like the list of sections)
	-- scroll inside the menu, LIST_MAX at a time, with up/down arrows;
	-- everything before and after them stays put (the item's name, the
	-- actions). The checked one starts in view.
	local first, last
	for i, it in ipairs(items) do if it.group then first = first or i; last = i end end
	local display = {}
	local screenH = (UIParent:GetHeight() or 768) - 40
	-- How many section rows fit: the screen, less every fixed row (title,
	-- gaps), both arrows and the padding. At most 12; if not even 3 fit, the
	-- whole menu scrolls instead (below), so every action stays reachable.
	-- (1.8.0-beta22, after FlareUI) a menu may ask for a taller list (items.listRows: the Font list, 20)
	local LIST_MAX = items.listRows or 12
	if first then
		local fixedH = pad * 2 + 32
		for i, it in ipairs(items) do
			if not it.group then fixedH = fixedH + (it.big and ROW_H + 4 or ROW_H) + (it.wrap and 12 or 0) end
			if it.gap then fixedH = fixedH + 6 end
		end
		-- The tallest section row (a wrapped one is taller) sets how many fit.
		local tallest = ROW_H
		for i = first, last do if items[i].wrap then tallest = ROW_H + 12 end end
		local room = math.floor((screenH - fixedH) / tallest)
		if room < 3 then first = nil else LIST_MAX = math.min(items.listRows or 12, room) end
	end
	if first and (last - first + 1) > LIST_MAX then
		local count = last - first + 1
		local maxOff = count - LIST_MAX
		if not m.listOffset then
			local checked
			for i = first, last do if items[i].checked then checked = i - first + 1 end end
			m.listOffset = checked and math.max(0, math.min(maxOff, checked - math.floor(LIST_MAX / 2))) or 0
		end
		m.listOffset = math.max(0, math.min(maxOff, m.listOffset))
		m.listMax = maxOff
		for i = 1, first - 1 do display[#display + 1] = items[i] end
		display[#display + 1] = { arrow = -1, enabled = m.listOffset > 0 }
		for i = first + m.listOffset, first + m.listOffset + LIST_MAX - 1 do display[#display + 1] = items[i] end
		display[#display + 1] = { arrow = 1, enabled = m.listOffset < maxOff }
		for i = last + 1, #items do display[#display + 1] = items[i] end
	else
		m.listMax = nil
		for i = 1, #items do display[#display + 1] = items[i] end
	end
	-- Anything else too long for the screen (or a screen too short for the
	-- fixed rows) scrolls as a whole. With a section list, it fits as sized.
	local tallestRow = ROW_H
	for _, it in ipairs(display) do
		local h = (it.big and ROW_H + 4 or ROW_H) + (it.wrap and 12 or 0) + (it.gap and 6 or 0)
		if h > tallestRow then tallestRow = h end
	end
	local maxRows = m.listMax and #display or math.max(4, math.floor((screenH - pad * 2) / tallestRow))
	local visible = math.min(#display, maxRows)
	m.maxOffset = m.listMax and 0 or math.max(0, #display - visible)
	m.offset = math.max(0, math.min(m.offset or 0, m.maxOffset))
	local y = pad
	for i = 1, visible do
		local it = display[i + m.offset]
		local r = m.rows[i]
		if not r then
			r = CreateFrame("Button", nil, m)
			r:SetHeight(ROW_H)
			r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 1, 1, 0.08)
			r.check = r:CreateTexture(nil, "OVERLAY"); r.check:SetSize(12, 12); r.check:SetPoint("LEFT", 6, 0)
			r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
			r.arrow = r:CreateTexture(nil, "OVERLAY"); r.arrow:SetSize(16, 16); r.arrow:SetPoint("CENTER")
			r.icon = r:CreateTexture(nil, "OVERLAY"); r.icon:SetSize(14, 14); r.icon:SetPoint("LEFT", 6, 0)
			r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.text:SetPoint("LEFT", 22, 0); r.text:SetPoint("RIGHT", -6, 0)
			r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false)
			r:SetScript("OnClick", function(self)
				if self.arrowDir then
					m.listOffset = (m.listOffset or 0) + self.arrowDir * 3
					ns.ShowMenu(m.items, nil, true)
					return
				end
				if not self.fn and self.tipText then return end   -- (1.9.0-beta17) a greyed entry with a tip: nothing to do
				local fn = self.fn; m:Hide(); if fn then fn() end
			end)
			-- (1.9.0-beta17) an entry's tip on hover (it.tip, with it.tipNote above it), greyed entries included
			r:SetScript("OnEnter", function(self)
				if not (self.tipText and ns.TooltipsOK()) then return end
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				ns.TipText(GameTooltip, self.tipTitle or "")
				if self.tipNote then ns.TipLine(GameTooltip, self.tipNote, 1, 0.82, 0) end
				ns.TipLine(GameTooltip, self.tipText, 0.8, 0.8, 0.8, true)
				GameTooltip:Show()
			end)
			r:SetScript("OnLeave", function(self) if self.tipText then GameTooltip:Hide() end end)
			m.rows[i] = r
		end
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", pad, -y); r:SetPoint("TOPRIGHT", -pad, -y)
		local s = Skins:Current()
		if it.arrow then
			-- A scroll arrow for the list: lit when there's more that way.
			r.arrowDir = it.enabled and it.arrow or nil
			r.arrow:SetTexture(it.arrow < 0 and "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up" or "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
			r.arrow:SetAlpha(it.enabled and 1 or 0.25); r.arrow:Show()
			r.text:SetText(""); r.check:Hide(); r.icon:Hide()
			r.fn = nil
			r:SetHeight(16)
			r:EnableMouse(it.enabled and true or false)
			r.hl:SetShown(it.enabled and true or false)
			r:Show()
			y = y + 16
		else
			r.arrowDir = nil
			r.arrow:Hide()
			-- An icon on the left (undo, star, pouch, wallet), where a check would go.
			if it.icon then
				r.icon:SetTexture(it.icon)
				if it.iconTint then r.icon:SetVertexColor(it.iconTint[1], it.iconTint[2], it.iconTint[3]) else r.icon:SetVertexColor(0.9, 0.88, 0.82) end
				r.icon:Show()
			else
				r.icon:Hide()
			end
			r.text:ClearAllPoints(); r.text:SetPoint("LEFT", it.icon and 26 or 22, 0); r.text:SetPoint("RIGHT", -6, 0)
			-- The item's name: one size larger, in its quality color.
			r.text:SetFontObject(it.big and "GameFontNormal" or "GameFontHighlightSmall")
			ns.MenuFace(r.text, it.font, it.big and "GameFontNormal" or "GameFontHighlightSmall")   -- (1.8.0) a row in its own face (the Font setting)
			r.text:SetWordWrap(it.wrap and true or false)
			r:SetHeight((it.big and ROW_H + 4 or ROW_H) + (it.wrap and 12 or 0))
			r.text:SetText(it.text or "")
			-- (1.8.0-beta22, after FlareUI) a pick-one list (it.radio) shows round marks, the chosen one filled; a toggle a tick
			if it.radio then
				r.check:SetTexture("Interface\\Buttons\\UI-RadioButton")
				if it.checked then r.check:SetTexCoord(0.25, 0.5, 0, 1) else r.check:SetTexCoord(0, 0.25, 0, 1) end
				r.check:SetSize(14, 14); r.check:Show()
			else
				r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check"); r.check:SetTexCoord(0, 1, 0, 1)
				r.check:SetSize(12, 12); r.check:SetShown(it.checked and true or false)
			end
			r.radio = it.radio and true or nil
			r.fn = (not it.disabled and not it.title) and it.onClick or nil
			r.tipTitle, r.tipNote, r.tipText = it.text, it.tipNote, it.tip
			r:EnableMouse(r.fn ~= nil or it.tip ~= nil)
			if it.color then r.text:SetTextColor(it.color[1], it.color[2], it.color[3])
			elseif it.title then r.text:SetTextColor(Skins:Accent())
			elseif it.disabled then r.text:SetTextColor(unpack(s.muted))
			else r.text:SetTextColor(unpack(s.text)) end
			r.hl:SetShown(r.fn ~= nil)
			r:Show()
			y = y + (it.big and ROW_H + 4 or ROW_H) + (it.wrap and 12 or 0) + (it.gap and 6 or 0)
		end
	end
	for j = visible + 1, #m.rows do m.rows[j]:Hide() end
	if not m.wheelSet then
		m:EnableMouseWheel(true)
		m:SetScript("OnMouseWheel", function(self, delta)
			if self.listMax then
				self.listOffset = math.max(0, math.min(self.listMax, (self.listOffset or 0) - delta * 3))
			elseif (self.maxOffset or 0) > 0 then
				self.offset = math.max(0, math.min(self.maxOffset, (self.offset or 0) - delta * 3))
			else
				return
			end
			ns.ShowMenu(self.items, nil, true)
		end)
		m.wheelSet = true
	end
	m:SetSize(innerW + pad * 2, y + pad)
	if not keepPlace then
		m:ClearAllPoints()
		local x, cy = GetCursorPosition()
		local sc = UIParent:GetEffectiveScale()
		m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / sc + 4, cy / sc - 4)
	end
	m.catcher:Show(); m:Show()
	return m
end

------------------------------------------------------------------------
-- A name prompt.
------------------------------------------------------------------------
-- maxLetters (optional, default 40) and note (an optional muted line under the box).
function ns.Prompt(title, default, onOK, maxLetters, note)
	local f = ns.promptFrame
	if not f then
		f = CreateFrame("Frame", "BagSmithPrompt", UIParent, "BackdropTemplate")
		f:SetSize(320, 124); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true)
		f:SetMovable(true); f:RegisterForDrag("LeftButton")   -- movable like every other dialog (1.1.0)
		f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
		f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", 16, -14)
		f.edit = CreateFrame("EditBox", "BagSmithPromptBox", f, "InputBoxTemplate")
		f.edit:SetHeight(22); f.edit:SetPoint("TOPLEFT", 22, -44); f.edit:SetPoint("TOPRIGHT", -18, -44)
		f.edit:SetAutoFocus(false); f.edit:SetMaxLetters(40)
		f.err = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.err:SetPoint("TOPLEFT", 18, -72); f.err:SetPoint("TOPRIGHT", -18, -72)
		f.err:SetJustifyH("LEFT"); f.err:SetTextColor(1, 0.4, 0.4)
		local function ok()
			local fn = f.onOK
			local done, why = true, nil
			if fn then done, why = fn(f.edit:GetText()) end
			if done then f:Hide() else f.err:SetTextColor(1, 0.4, 0.4); f.err:SetText(why or "") end
		end
		f.ok = ns.TextButton(f, "Save", 70, ok); f.ok:SetHeight(24); f.ok:SetPoint("BOTTOMRIGHT", -14, 12)
		f.cancel = ns.TextButton(f, "Cancel", 70, function() f:Hide() end); f.cancel:SetHeight(24)
		f.cancel:SetPoint("RIGHT", f.ok, "LEFT", -6, 0)
		f.edit:SetScript("OnEnterPressed", ok)
		f.edit:SetScript("OnEscapePressed", function() f:Hide() end)
		f:SetScript("OnHide", function() f.edit:ClearFocus() end)
		f.classicSpec = ns.Classic.DialogSpec(f, { restore = function() Skins:ApplyBackdrop(f); local s = Skins:Current(); f:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1) end })
		Skins:Register(f, function(fr)
			Skins:ApplyBackdrop(fr); local s = Skins:Current(); fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)
			fr.title:SetTextColor(unpack(s.heading))
			ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
		end)
		f:Hide()
		ns.promptFrame = f
	end
	f.title:SetText(title)
	if ns.Classic then ns.Classic:RefreshTitle(f) end
	if note then local s = Skins:Current(); f.err:SetTextColor(s.muted[1], s.muted[2], s.muted[3]); f.err:SetText(note)
	else f.err:SetText("") end
	f.edit:SetMaxLetters(maxLetters or 40)
	f.onOK = onOK
	f.edit:SetText(default or "")
	f:Show(); f.edit:SetFocus(); f.edit:HighlightText()
	return f
end

------------------------------------------------------------------------
-- New / rename / delete a custom section
------------------------------------------------------------------------
function S:PromptNew(thenMove)
	local db = ns.db
	return ns.Prompt("New Section", "", function(text)
		if ns.db ~= db then return true end   -- the profile changed: this was for the old one
		local id, why = S:Create(text)
		if not id then return false, why end
		if thenMove then S:Move(thenMove, id) end
		return true
	end)
end
function S:PromptRename(id)
	local db = ns.db
	return ns.Prompt("Rename Section", S:Label(id), function(text) if ns.db ~= db then return true end return S:Rename(id, text) end)
end
function S:ConfirmDelete(id, anchor)
	local n = S:ItemCount(id)
	local what = n == 1 and "Its 1 item goes back to its own section." or n > 1 and ("Its %d items go back to their own sections."):format(n) or "It has no items."
	local db = ns.db
	ns.Confirm(anchor or UIParent, ("Delete the section \"%s\"? %s"):format(S:Label(id), what), function() if ns.db == db then S:Delete(id) end end)
	if ns.Popups.confirm then ns.Popups.confirm.sections = true end
end

------------------------------------------------------------------------
-- The item menu (Alt+Left-click, or the Move to Section keybinding)
------------------------------------------------------------------------
local UNDO = "Interface\\AddOns\\BagSmith\\Media\\ui-undo.tga"
local STAR = "Interface\\AddOns\\BagSmith\\Media\\ui-star.tga"
local POUCH = "Interface\\AddOns\\BagSmith\\Media\\ui-pouch.tga"
local WALLET = "Interface\\AddOns\\BagSmith\\Media\\ui-wallet.tga"
function S:ItemMenu(rec, owner)
	if not (rec and rec.itemID) then return end
	local id = rec.itemID
	local db = ns.db
	local function guard(fn) return function() if ns.db == db then fn() end end end
	local moved = S:MovedTo(id)
	local own = rec.ownCat or ns:Categorize(rec)
	-- (1.10.0-beta5) the section it's in on the tab the menu was opened from (a section can show on some tabs only)
	local sheet
	do
		local x, depth = owner, 0
		while x and depth < 10 do
			if type(x.view) == "table" and x.view.st then sheet = x.view.st.sheet; break end
			x = x.GetParent and x:GetParent(); depth = depth + 1
		end
	end
	local current = S:Apply(rec, own, sheet)   -- (1.10.0-beta1) where you put it, or the section whose rules it fits
	local q = rec.quality or 1
	local qc = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]) or nil
	local items = { { text = rec.name or ("Item " .. id), title = true, big = true, gap = not moved, color = qc and { qc.r, qc.g, qc.b } or nil } }
	-- In a gear set: it shows in the set's section whatever its section is,
	-- so say so right under the name.
	local sets = ns.GearSets and ns.GearSets:SetsOf(rec)
	if sets then
		items[1].gap = false
		local names = #sets == 1 and sets[1] or (table.concat(sets, ", ", 1, #sets - 1) .. " and " .. sets[#sets])
		items[#items + 1] = { text = (#sets == 1 and "In gear set %s" or "In gear sets %s"):format(names), disabled = true, gap = not moved }
	end
	-- Moved: the way back comes first, right under the name.
	if moved then
		items[#items + 1] = { text = ("Reset to Its Original Section (%s)"):format(S:Label(own)), icon = UNDO, onClick = guard(function() S:Clear(id) end), gap = true }
	end
	items[#items + 1] = { text = "Move to Section:", title = true }
	for _, sec in ipairs(S:Targets()) do
		-- The item's default section is marked; picking it moves the item back.
		local label = S:Label(sec) .. (sec == own and " (default)" or "")
		-- (1.10.0-beta5) a section that isn't shown on this tab says where it is
		local sc = S:Custom(sec)
		if sc and sc.sheets and not S:OnSheet(sc, sheet) then label = ("%s (on %s)"):format(label, S:SheetsText(sc.sheets)) end
		items[#items + 1] = { text = "   " .. label, checked = sec == current, group = true, onClick = guard(function() S:Move(id, sec) end) }
	end
	items[#items + 1] = { text = "   New Section...", onClick = guard(function() S:PromptNew(id) end) }
	-- (1.10.0-beta1) a section that fills itself with items like this one
	items[#items + 1] = { text = "   New Section From This Item...", onClick = guard(function() S:PromptFromItem(rec) end), gap = true }
	if ns.Marks then
		local fav = ns.Marks:IsFavorite(id)
		items[#items + 1] = { text = fav and "Remove from Favorites" or "Favorite", icon = STAR, iconTint = fav and { 1, 0.82, 0 } or nil, onClick = guard(function() ns.Marks:ToggleFavorite(rec) end) }
	end
	if ns.Junk then
		local marked = ns.Junk:Marked(id)
		local can = marked or (ns.Junk.Markable and ns.Junk:Markable(rec))
		items[#items + 1] = { text = marked and "Unmark as Junk" or "Mark as Junk", icon = POUCH, disabled = not can, onClick = guard(function() ns.Junk:Toggle(rec) end) }
	end
	if ns.Marks then
		local tracked = ns.Marks:IsTracked(id)
		items[#items + 1] = { text = tracked and "Stop Tracking as Currency" or "Track as Currency", icon = WALLET, onClick = guard(function() ns.Marks:ToggleCurrency(rec) end) }
	end
	return ns.ShowMenu(items, owner)
end

-- The hovered item, for the keybinding.
local function hovered()
	local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
	for _, f in ipairs(foci or {}) do
		local x = f
		for _ = 1, 3 do
			if not x then break end
			if x.rec and x.hasItem then return x.rec, x end
			x = x.GetParent and x:GetParent()
		end
	end
end
S.Hovered = hovered
function BagSmith_MoveToSection() if ns.ready then local rec, btn = hovered(); if rec then S:ItemMenu(rec, btn) end end end

------------------------------------------------------------------------
-- Section titles: drops and the right-click menu
------------------------------------------------------------------------
-- What dropping an item on this section does: "move", "favorite", "junk" or nil.
-- (By Bag titles are "bag:N" and Sections: None has no titles, so neither takes drops.)
function S:DropKind(laneId)
	if laneId == "~fav" then return "favorite" end
	if laneId == "~all" then return "home" end   -- (1.4.0-beta3) All Items: back out of a pinned section
	if laneId == "Junk" then return "junk" end
	if S:CanTake(laneId) then return "move" end
end
local function cursorItem()
	local kind, id, link = GetCursorInfo()
	if kind == "item" and id then return id, link end
end
S.CursorItem = cursorItem
function S:DropHint(laneId)
	local id, link = cursorItem()
	local kind = id and self:DropKind(laneId)
	if not kind then return end
	local name = (link and link:match("%[(.-)%]")) or (C_Item.GetItemInfo and C_Item.GetItemInfo(id)) or "this item"
	if kind == "home" then return ("Drop to move %s back to All Items"):format(name) end
	if kind == "favorite" then return ("Drop to favorite %s"):format(name)
	elseif kind == "junk" then return ("Drop to mark %s as junk"):format(name) end
	return ("Drop to move %s to %s"):format(name, self:Label(laneId))
end
-- Returns true if it took the item (which goes straight back to its slot).
function S:DropOnSection(laneId)
	local id = cursorItem()
	local kind = id and self:DropKind(laneId)
	if not kind then return false end
	local rec
	if kind == "home" then
		-- All Items is everything that isn't pinned. An item moved into a pinned custom section goes back to its own
		-- section (moving an item to its own section undoes the move), unless that section is pinned too. An item
		-- that isn't in a pinned section is already in All Items: nothing to do.
		local own, cur
		for _, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
			for _, r in ipairs(list) do if r.itemID == id then rec = r; break end end
			if rec then break end
		end
		if not rec then return false end
		own = self:OwnCategory(rec)
		cur = self:MovedTo(id) or own
		if not self:Pinned(cur) then return false end
		local name = rec.name or "That item"
		if self:Pinned(own) then
			if cur ~= own then
				ns:Print("%s stays in a pinned section: its own section, %s, is pinned too. Unpin %s, or move it to another section.", name, self:Label(own), self:Label(own))
			else
				ns:Print("%s belongs in %s, which is pinned. Unpin %s, or move it to another section.", name, self:Label(own), self:Label(own))
			end
			return false
		end
		ClearCursor()   -- the item goes back where it came from: nothing moves in your bags
		S:Move(id, own)
		return true
	end
	if kind == "junk" then
		-- Bags or bank; only take the drop if it can be marked.
		for _, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
			for _, r in ipairs(list) do if r.itemID == id then rec = r; break end end
			if rec then break end
		end
		if not (ns.Junk and rec) or ns.Junk:Marked(id) or (ns.Junk.Markable and not ns.Junk:Markable(rec)) then return false end
	end
	ClearCursor()   -- the item goes back where it came from: nothing moves in your bags
	if kind == "favorite" then
		if ns.Marks and not ns.Marks:IsFavorite(id) then ns.Marks:ToggleFavorite({ itemID = id }) end
	elseif kind == "junk" then
		ns.Junk:Toggle(rec)
	else
		S:Move(id, laneId)
	end
	return true
end
-- Every click or drag on a bag slot is a new gesture (1.4.0-beta7); a pending drop check from an older gesture
-- ends when it sees a newer one.
function S:NoteGesture() self.dropGen = (self.dropGen or 0) + 1; return self.dropGen end
-- A drop or click onto a slot among All Items in All view (1.4.0-beta6, bound to its gesture in beta7): the game acts
-- first, then the slot is read. The check expects one item (the one this gesture carried) and acts only when that
-- item, and only that item, lands in the slot. It belongs to its gesture, its profile, its view and the item's
-- pinned section at the time: if a newer gesture starts, the profile changes, the view leaves All, or the item's
-- section changes, it stops. The slot may settle a moment later, so a few short looks follow, then it gives up.
function S:WatchAllItemsDrop(btn, expected, gen)
	if not (btn and expected) then return end
	gen = gen or self.dropGen
	if btn.inLane ~= "~all" and btn.inLane ~= "" then return end
	local view = btn.inView
	if not (view and view.Pref and view:Pref("grp") == "none") then return end
	local to = self:MovedTo(expected)
	if not (to and self:IsCustom(to) and self:Pinned(to)) then return end   -- only an item in a pinned custom section
	local rec = btn.rec
	local bag = (rec and rec.bag) or btn.bag
	local slot = (rec and rec.slot) or (btn.GetID and btn:GetID())
	if not (bag and slot) then return end
	local before = (rec and not rec.empty) and rec.itemID or nil
	if before == expected then return end   -- a merge onto the same item: nothing to judge
	local db0 = ns.db
	local function current()
		return gen == self.dropGen and ns.db == db0 and view:Pref("grp") == "none" and self:MovedTo(expected) == to
	end
	local function look()
		if not current() then return true end   -- superseded: stop looking
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if info and info.itemID == expected then S:IntoAllItems(expected); return true end
		return false
	end
	if look() then return end
	local tries = 0
	local function again()
		tries = tries + 1
		if look() or tries >= 3 then return end
		C_Timer.After(0.2, again)
	end
	if C_Timer and C_Timer.After then C_Timer.After(0.2, again) end
end
-- An item that landed among All Items: if it sits in a pinned custom section by a move, it goes back to its own
-- section (the move is undone) so it stays in All Items; if that section is pinned too, chat says so. Items not in
-- a pinned custom section are left alone.
function S:IntoAllItems(itemID)
	if not itemID then return false end
	local to = self:MovedTo(itemID)
	if not (to and self:IsCustom(to) and self:Pinned(to)) then return false end
	local rec
	for _, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
		for _, r in ipairs(list) do if r.itemID == itemID then rec = r; break end end
		if rec then break end
	end
	if not rec then return false end
	local own = self:OwnCategory(rec)
	if self:Pinned(own) then
		ns:Print("%s stays in a pinned section: its own section, %s, is pinned too. Unpin %s, or move it to another section.", rec.name or "That item", self:Label(own), self:Label(own))
		return false
	end
	S:Move(itemID, own)
	return true
end
function S:SectionMenu(laneId, owner)
	if not laneId or laneId == "" or laneId == "~all" or laneId:match("^bag:") then return end
	local items = { { text = S:Label(laneId), title = true, gap = true } }
	local db = ns.db
	local function same() return ns.db == db end
	-- A gear set: Equip (from your own bags window), Update, Put on Action
	-- Bar, then Show at Vendor / AH. Sets belong to the character you're
	-- playing, so browsing another character's bags offers only the toggles.
	local GS = ns.GearSets
	if GS and GS.IsLane(laneId) then
		local name = GS.NameOf(laneId)
		local v = owner and owner.view
		local mine = not ns.ui.owner and GS:Find(name) ~= nil
		if mine then
			if v and v.kind == "main" and v.st and v.st.sheet ~= "Bank" then
				local blocked = GS:EquipBlocked()
				items[#items + 1] = { text = "Equip", disabled = blocked ~= nil, tip = blocked, onClick = function() GS:Equip(name) end }
			end
			items[#items + 1] = { text = "Update from What I'm Wearing...", onClick = function() GS:ConfirmUpdate(name, owner) end }
			items[#items + 1] = { text = "Put on Action Bar", onClick = function() GS:PickUp(name) end, gap = true }
		end
		-- (one choice for every set, like their one place in Section Order)
		items[#items + 1] = { text = "Show Gear Sets at Vendor", checked = S:Shown("~gs", "vendor"), onClick = function() if same() then S:SetShown("~gs", "vendor", not S:Shown("~gs", "vendor")) end end }
		items[#items + 1] = { text = "Show Gear Sets at Auction House", checked = S:Shown("~gs", "ah"), onClick = function() if same() then S:SetShown("~gs", "ah", not S:Shown("~gs", "ah")) end end }
		return ns.ShowMenu(items, owner)
	end
	-- Pin to Top (1.4.0): item sections only (not Recent, Favorites, Keys, Reagent Bag, gear sets or All Items).
	-- (1.10.0-beta10, Shweep) Pin Section / Unpin Section: a pinned section can sit below All Items now, so "to Top"
	-- no longer says it
	if S:Pinnable(laneId) then
		local pinned = S:Pinned(laneId)
		items[#items + 1] = { text = pinned and "Unpin Section" or "Pin Section", onClick = function() if same() then S:SetPinned(laneId, not S:Pinned(laneId)) end end,
			tip = pinned and "Back to its usual place." or "Shown ahead of your other sections, after Recent. In All view its items get their own section, above or below All Items by its place in Section Order.", gap = true }
	end
	-- (Recent, Keys and Reagent Bag are views of other sections, so they have no toggles.)
	if laneId ~= "~recent" and laneId ~= "~ky" and laneId ~= "~rb" then
		items[#items + 1] = { text = "Show at Vendor", checked = S:Shown(laneId, "vendor"), onClick = function() if same() then S:SetShown(laneId, "vendor", not S:Shown(laneId, "vendor")) end end }
		items[#items + 1] = { text = "Show at Auction House", checked = S:Shown(laneId, "ah"), onClick = function() if same() then S:SetShown(laneId, "ah", not S:Shown(laneId, "ah")) end end, gap = S:IsCustom(laneId) }
	end
	if S:IsCustom(laneId) then
		local c = S:Custom(laneId)
		items[#items + 1] = { text = "Show When Empty", checked = c and c.showEmpty ~= false, disabled = not ns.db.showEmptySections,
			onClick = function() if same() then local cc = S:Custom(laneId); if cc then S:SetShowEmpty(laneId, cc.showEmpty == false) end end end, gap = true }
		-- (1.10.0-beta3) its name and its rules, in the editor
		items[#items + 1] = { text = "Edit Section...", onClick = function() if same() then S:EditSection(laneId) end end,
			tip = "Change its name, and the rules that fill it by itself." }
		items[#items + 1] = { text = "Rename...", onClick = function() if same() then S:PromptRename(laneId) end end }
		items[#items + 1] = { text = "Delete...", onClick = function() if same() then S:ConfirmDelete(laneId) end end }
	end
	items[#items + 1] = { text = "New Section...", onClick = function() if same() then S:PromptNew() end end }
	return ns.ShowMenu(items, owner)
end

------------------------------------------------------------------------
-- The moved-items window (Settings > Custom Sections > Manage...)
------------------------------------------------------------------------
local NW, NROW = 340, 24
function S:MovedWindow()
	local f = self.movedFrame
	if f then return f end
	f = CreateFrame("Frame", "BagSmithMovedItems", UIParent, "BackdropTemplate")
	f:SetSize(NW, 380); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	f:SetMovable(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", 12, -12); f.title:SetText("Moved Items")
	f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
	f.sub:SetWidth(NW - 24); f.sub:SetJustifyH("LEFT")
	f.search = CreateFrame("EditBox", "BagSmithMovedSearch", f, "SearchBoxTemplate")
	f.search:SetSize(NW - 32, 22); f.search:SetAutoFocus(false); f.search:SetPoint("TOPLEFT", 18, -58)
	f.search:SetScript("OnTextChanged", function(box) if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(box) end; S:RefreshMovedWindow() end)
	f.search:SetScript("OnEscapePressed", function(box) box:SetText(""); box:ClearFocus() end)
	f.scroll = CreateFrame("ScrollFrame", "BagSmithMovedScroll", f, "UIPanelScrollFrameTemplate")
	f.scroll:SetPoint("TOPLEFT", 10, -88); f.scroll:SetPoint("BOTTOMRIGHT", -30, 44)
	f.child = CreateFrame("Frame", nil, f.scroll); f.child:SetSize(NW - 44, 1); f.scroll:SetScrollChild(f.child)
	ns.WheelStep(f.scroll, NROW * ns.WHEEL_ROWS)   -- (1.7.5-beta1) the wheel: two rows a notch (Init.lua, ns.WheelStep)
	f.rows = {}
	f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.empty:SetPoint("TOPLEFT", 16, -96)
	f.empty:SetWidth(NW - 32); f.empty:SetJustifyH("LEFT")
	f.close = ns.TextButton(f, "Close", 70, function() f:Hide() end); f.close:SetHeight(22); f.close:SetPoint("BOTTOMRIGHT", -12, 12)
	f.classicSpec = ns.Classic.DialogSpec(f, { restore = function() Skins:ApplyBackdrop(f); local s = Skins:Current(); f:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1) end })
	Skins:Register(f, function(fr)
		Skins:ApplyBackdrop(fr); local s = Skins:Current(); fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)
		fr.title:SetTextColor(unpack(s.heading)); fr.sub:SetTextColor(unpack(s.muted)); fr.empty:SetTextColor(unpack(s.muted))
		ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
	end)
	f:Hide()
	ns:CloseOnEscape(f, function() f:Hide() end)   -- (1.5.4) Escape closes it like its Close button
	ns:CombatWindow(f)   -- (1.5.6) fades in combat like the bags window
	self.movedFrame = f
	return f
end
local function itemName(id)
	local name = C_Item.GetItemInfo and C_Item.GetItemInfo(id)
	return name or ("Item " .. id)
end
local function ownOf(id)
	for _, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
		for _, r in ipairs(list) do if r.itemID == id then return r.ownCat or ns:Categorize(r) end end
	end
end
-- Every moved item: { id, name, to, own }, A to Z.
function S:MovedList()
	local out = {}
	for id, to in pairs(self:Moves()) do
		if self:CanTake(to) then out[#out + 1] = { id = id, name = itemName(id), to = to, own = ownOf(id) } end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end
local function movedRow(f, i)
	local r = f.rows[i]
	if r then return r end
	r = CreateFrame("Frame", nil, f.child); r:SetSize(NW - 44, NROW - 2)
	r:EnableMouse(true)
	r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT", 2, 0)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.name:SetPoint("RIGHT", -28, 0); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
	r.remove = ns.IconButton(r, "Interface\\AddOns\\BagSmith\\Media\\ui-undo.tga", "Reset to Its Original Section", function(b)
		-- Only for the profile this window was opened for.
		if ns.db ~= S.movedDB then f:Hide() return end
		S:Clear(b:GetParent().id)
	end)
	r.remove:SetSize(16, 16); r.remove:SetPoint("RIGHT", -4, 0)
	r:SetScript("OnEnter", function(self)
		if not (self.id and ns.TooltipsOK()) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. self.id); GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.rows[i] = r
	return r
end
function S:RefreshMovedWindow()
	local f = self.movedFrame
	if not (f and f:IsShown()) then return end
	local all = self:MovedList()
	local text = (f.search:GetText() or ""):lower()
	local list = {}
	for _, e in ipairs(all) do
		local hay = (e.name .. " " .. S:Label(e.to)):lower()
		if text == "" or hay:find(text, 1, true) then list[#list + 1] = e end
	end
	f.sub:SetText(#all == 1 and "1 item moved to another section." or ("%d items moved to other sections."):format(#all))
	local s = Skins:Current()
	for i, e in ipairs(list) do
		local r = movedRow(f, i)
		r.id = e.id
		local icon = (C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id)) or (C_Item.GetItemInfoInstant and select(5, C_Item.GetItemInfoInstant(e.id)))
		r.icon:SetTexture(icon)
		local where = e.own and e.own ~= e.to and ("in %s (was %s)"):format(S:Label(e.to), S:Label(e.own)) or ("in %s"):format(S:Label(e.to))
		r.name:SetText(("%s  |cff9a9a9a%s|r"):format(e.name, where)); r.name:SetTextColor(unpack(s.text))
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", f.child, "TOPLEFT", 0, -(i - 1) * NROW); r:Show()
	end
	for i = #list + 1, #f.rows do f.rows[i]:Hide() end
	f.child:SetHeight(math.max(1, #list * NROW))
	f.empty:SetShown(#list == 0)
	f.empty:SetText(#all == 0 and "No items moved yet. Drag an item onto a section title, or Alt+Left-click it." or "No items match.")
end
function S:ManageMoves()
	local f = self:MovedWindow()
	self.movedDB = ns.db
	f.search:SetText("")
	f:Show()
	self:RefreshMovedWindow()
end

------------------------------------------------------------------------
-- New Section From This Item (1.10.0-beta1): a section that fills itself. Tick what the items should have in common
-- with the one you picked; the list below shows what would go in it right now, from your bags and bank.
------------------------------------------------------------------------
local FW, FPAD, FROW, FMAX = 380, 14, 22, 8
function S:FromItemWindow()
	local f = self.fromFrame
	if f then return f end
	f = CreateFrame("Frame", "BagSmithSectionFromItem", UIParent, "BackdropTemplate")
	f:SetSize(FW, 320); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	f:SetMovable(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	local function text(template, width)
		local t = f:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
		t:SetJustifyH("LEFT"); t:SetWidth(width or (FW - FPAD * 2)); t:SetWordWrap(false)
		return t
	end
	f.title = text("GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", 12, -12); f.title:SetText("New Section From This Item")
	f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetSize(26, 26); f.icon:SetPoint("TOPLEFT", FPAD, -40)
	f.item = text("GameFontNormal", FW - FPAD * 2 - 34); f.item:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
	f.nameLabel = text(); f.nameLabel:SetPoint("TOPLEFT", FPAD, -76); f.nameLabel:SetText("Section name")
	f.edit = CreateFrame("EditBox", "BagSmithSectionFromItemName", f, "InputBoxTemplate")
	f.edit:SetHeight(22); f.edit:SetPoint("TOPLEFT", FPAD + 6, -92); f.edit:SetPoint("TOPRIGHT", -FPAD, -92)
	f.edit:SetAutoFocus(false); f.edit:SetMaxLetters(40)
	f.ask = text(); f.ask:SetPoint("TOPLEFT", FPAD, -124); f.ask:SetText("Put items in it that have the same:")
	f.checks, f.rows = {}, {}
	f.head = text(); f.sub = text(); f.more = text(); f.also = text(); f.err = text()
	f.also:SetWordWrap(true); f.err:SetWordWrap(true); f.err:SetTextColor(1, 0.4, 0.4)
	local function create()
		if ns.db ~= S.fromDB then f:Hide() return end   -- the profile changed: this was for the old one
		local id, why = S:CreateWithRules(f.edit:GetText(), S:FromItemRules())
		if not id then f.err:SetText(why or ""); S:RefreshFromItem(); return end
		f:Hide()
	end
	f.create = ns.TextButton(f, "Create Section", 116, create); f.create:SetHeight(24); f.create:SetPoint("BOTTOMRIGHT", -12, 12)
	f.cancel = ns.TextButton(f, "Cancel", 70, function() f:Hide() end); f.cancel:SetHeight(24); f.cancel:SetPoint("RIGHT", f.create, "LEFT", -6, 0)
	f.edit:SetScript("OnEnterPressed", create)
	f.edit:SetScript("OnEscapePressed", function() f:Hide() end)
	f:SetScript("OnHide", function() f.edit:ClearFocus() end)
	f.classicSpec = ns.Classic.DialogSpec(f, { restore = function() Skins:ApplyBackdrop(f); local s = Skins:Current(); f:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1) end })
	Skins:Register(f, function(fr)
		Skins:ApplyBackdrop(fr); local s = Skins:Current(); fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)
		fr.title:SetTextColor(unpack(s.heading))
		for _, t in ipairs({ fr.nameLabel, fr.sub, fr.more, fr.also }) do t:SetTextColor(unpack(s.muted)) end
		fr.ask:SetTextColor(unpack(s.text)); fr.head:SetTextColor(unpack(s.heading))
		ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
	end)
	f:Hide()
	ns:CloseOnEscape(f, function() f:Hide() end)
	ns:CombatWindow(f)
	self.fromFrame = f
	return f
end
-- The rules the ticked boxes make: every ticked detail must be the same ("all").
function S:FromItemRules()
	local f = self.fromFrame
	local rows = {}
	for _, fact in ipairs(f and f.facts or {}) do
		if f.on[fact.k] then rows[#rows + 1] = { k = fact.k, v = { fact.v } } end
	end
	return { mode = "all", rows = rows }
end
local function fromCheck(f, i)
	local c = f.checks[i]
	if c then return c end
	c = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate"); c:SetSize(22, 22)
	c.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	c.label:SetJustifyH("LEFT"); c.label:SetWordWrap(false); c.label:SetWidth(FW - FPAD * 2 - 30)
	c.label:SetPoint("LEFT", c, "RIGHT", 2, 0)
	c:SetScript("OnClick", function(b)
		f.on[b.key] = b:GetChecked() and true or nil
		f.err:SetText("")
		S:RefreshFromItem()
	end)
	f.checks[i] = c
	return c
end
local function fromRow(f, i)
	local r = f.rows[i]
	if r then return r end
	r = CreateFrame("Frame", nil, f); r:SetSize(FW - FPAD * 2, FROW - 2); r:EnableMouse(true)
	r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT", 2, 0)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.name:SetPoint("RIGHT", -4, 0); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
	r:SetScript("OnEnter", function(self)
		if not (self.id and ns.TooltipsOK()) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.link or ("item:" .. self.id)); GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.rows[i] = r
	return r
end
local function qualityColor(q)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end
function S:RefreshFromItem()
	local f = self.fromFrame
	if not (f and f:IsShown()) then return end
	local s = Skins:Current()
	-- the details to tick
	local y = -142
	for i, fact in ipairs(f.facts) do
		local c = fromCheck(f, i)
		c.key = fact.k
		c:ClearAllPoints(); c:SetPoint("TOPLEFT", FPAD, y)
		c:SetChecked(f.on[fact.k] and true or false)
		c.label:SetText(("%s: %s"):format(fact.label, fact.text)); c.label:SetTextColor(unpack(s.text))
		c:Show(); c.label:Show()
		y = y - FROW
	end
	for i = #f.facts + 1, #f.checks do f.checks[i]:Hide(); f.checks[i].label:Hide() end
	-- what it would do
	local here, elsewhere = self:PreviewRules(self:FromItemRules(), nil)
	f.preview = { here = here, elsewhere = elsewhere }
	y = y - 10
	f.head:ClearAllPoints(); f.head:SetPoint("TOPLEFT", FPAD, y)
	f.head:SetText(#here == 1 and "Would go in this section: 1 item" or ("Would go in this section: %d items"):format(#here))
	y = y - 15
	f.sub:ClearAllPoints(); f.sub:SetPoint("TOPLEFT", FPAD, y)
	local ticked = next(f.on) ~= nil
	f.sub:SetText(not ticked and "Tick at least one to see what goes in." or (#here == 0 and "Nothing in your bags or bank would go here right now." or "Looking at your bags and bank."))
	y = y - 18
	local shown = math.min(#here, FMAX)
	for i = 1, shown do
		local rec, r = here[i], fromRow(f, i)
		r.id, r.link = rec.itemID, rec.link
		r.icon:SetTexture(rec.icon)
		r.name:SetText(rec.name or ("Item " .. tostring(rec.itemID))); r.name:SetTextColor(qualityColor(rec.quality))
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", FPAD, y); r:Show()
		y = y - FROW
	end
	for i = shown + 1, #f.rows do f.rows[i]:Hide() end
	f.more:ClearAllPoints(); f.more:SetPoint("TOPLEFT", FPAD + 26, y)
	f.more:SetShown(#here > shown)
	if #here > shown then f.more:SetText(("and %d more"):format(#here - shown)); y = y - 16 end
	-- the ones that fit but are decided first, with why
	f.also:ClearAllPoints(); f.also:SetPoint("TOPLEFT", FPAD, y - 4)
	f.also:SetShown(#elsewhere > 0)
	if #elsewhere > 0 then
		local parts = {}
		for i = 1, math.min(#elsewhere, 4) do
			local e = elsewhere[i]
			parts[#parts + 1] = ("%s (%s)"):format(e.rec.name or "?", e.why)
		end
		if #elsewhere > 4 then parts[#parts + 1] = ("%d more"):format(#elsewhere - 4) end
		f.also:SetText("Fits, but stays somewhere else: " .. table.concat(parts, "; ") .. ".")
		local lines = math.max(1, math.ceil((f.also:GetStringWidth() or 0) / (FW - FPAD * 2)))
		y = y - 4 - lines * 13
	end
	f.err:ClearAllPoints(); f.err:SetPoint("TOPLEFT", FPAD, y - 6)
	if (f.err:GetText() or "") ~= "" then y = y - 20 end
	f:SetHeight(-y + 50)
end
function S:PromptFromItem(rec)
	if not (rec and rec.itemID and ns.Rules) then return end
	local f = self:FromItemWindow()
	self.fromDB = ns.db
	f.rec = rec
	f.facts = ns.Rules:FactsOf(rec)
	-- its type is ticked to start with; the rest are yours to add
	f.on = {}
	if f.facts[1] then f.on[f.facts[1].k] = true end
	f.icon:SetTexture(rec.icon)
	f.item:SetText(rec.name or ("Item " .. tostring(rec.itemID))); f.item:SetTextColor(qualityColor(rec.quality))
	-- a name to start from: the kind of item ("Cloth"), yours to change
	local start = (type(rec.itemSubType) == "string" and rec.itemSubType ~= "" and rec.itemSubType) or (type(rec.itemType) == "string" and rec.itemType) or ""
	f.err:SetText("")
	f.edit:SetText(start)
	if ns.Classic then ns.Classic:RefreshTitle(f) end
	f:Show(); f.edit:SetFocus(); f.edit:HighlightText()
	self:RefreshFromItem()
	return f
end

ns:OnSignal("ADDON_READY", function()
	ns:On("GET_ITEM_INFO_RECEIVED", function() if S.movedFrame and S.movedFrame:IsShown() then S:RefreshMovedWindow() end end)
	-- (1.10.0-beta1) the preview follows your bags while the window is up
	ns:OnSignal("ITEMS_CHANGED", function() if S.fromFrame and S.fromFrame:IsShown() then S:RefreshFromItem() end end)
end)
