--[[
	Frames/SectionEditor.lua (1.10.0-beta3)

	The rule editor: a custom section's name and its rules on the left, and on the right what those rules would do
	right now, over your bags and bank. Nothing is changed until Save.

	The window works on a draft of the section: { id (nil for a new section), mode, rows }. A list row (Type, Slot,
	Quality, Binding) is { k, n, v = { ... } }; a number row (Item Level, Vendor Value) is { k, op = "ge" | "le" |
	"in", a, b }, where a and b are nil while their boxes are empty; a row this version doesn't know (a newer
	version's, another addon's) is kept exactly as it came. Save turns the draft back into rules (Core/Rules.lua) and
	hands them to Core/Sections.lua, which cleans them like any saved data.

	Type and Slot have long lists, so their values are picked in a second window (E:Picker), on a copy that is only
	written back by its Add Rule or Done button. Quality and Binding show every choice on the row.
--]]
local ADDON, ns = ...
local S = ns.Sections
local Skins = ns.Skins
local E = {}
ns.SectionEditor = E

local PAD, LW, RW, GAP, H = 14, 372, 250, 16, 470
local W = PAD + LW + GAP + RW + PAD
local TOP, BOTTOM = 136, 54                 -- above and below the two lists
local RULES_W, SHOWN_W = LW - 22, RW - 22   -- each list, beside its scroll bar
local LABEL_W, CHIP_H, CHIP_GAP = 88, 20, 4
local PREVIEW_MAX = 40
local PW, PH, PROW = 330, 480, 22
local OPS = { "ge", "le", "in" }
local OP_TEXT = { ge = "at least", le = "at most", ["in"] = "between" }
local INLINE = { quality = true, bind = true }   -- few enough choices to show them all on the row
local PICKED = { type = true, slot = true }      -- long lists: picked in the second window
local KINDS = {
	{ k = "type", hint = "What kind of item it is: Cloth, Herbs, Plate, Potions..." },
	{ k = "slot", hint = "Where it's worn: Head, Trinket, Two-Hand..." },
	{ k = "quality", hint = "Common, Uncommon, Rare, Epic..." },
	{ k = "bind", hint = "Soulbound, Binds when equipped, No binding..." },
	{ k = "ilvl", hint = "At least, at most, or between two numbers." },
	{ k = "price", hint = "What a vendor pays for one: at least, at most, or between." },
}
local PICK_ASK = { type = "Tick every kind you want:", slot = "Tick every slot you want:" }
local PICK_NONE = { type = "Tick at least one kind.", slot = "Tick at least one slot." }
local PICK_HINT = { type = "What kind of item it is", slot = "Where it's worn" }

local function has(list, v) for i, x in ipairs(list) do if x == v then return i end end end
local function copy(list) local t = {}; for i, v in ipairs(list or {}) do t[i] = v end; return t end
local function anyOf(values, o) for _, v in ipairs(o.v) do if has(values, v) then return true end end return false end
-- Ticking a choice adds its values (o.add when only some of them are worth storing); unticking takes them all off.
local function toggle(values, o)
	if anyOf(values, o) then
		for _, v in ipairs(o.v) do local i = has(values, v); if i then table.remove(values, i) end end
		return false
	end
	for _, v in ipairs(o.add or o.v) do
		if #values < ns.Rules.MAX_VALUES and not has(values, v) then values[#values + 1] = v end
	end
	return true
end
local function qualityHex(q)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	if not c then return nil end
	return ("|cff%02x%02x%02x"):format(math.floor((c.r or 1) * 255 + 0.5), math.floor((c.g or 1) * 255 + 0.5), math.floor((c.b or 1) * 255 + 0.5))
end
local function qualityColor(q)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

------------------------------------------------------------------------
-- The draft
------------------------------------------------------------------------
local function draftRow(row)
	local def = ns.Rules.KEYS[row.k]
	if not def then return { k = row.k, v = copy(row.v), n = row.n, kept = true } end
	if def.number then
		local lo, hi = row.v[1], row.v[2]
		if type(lo) ~= "number" or type(hi) ~= "number" then return { k = row.k, op = "ge" } end
		if lo == hi then return { k = row.k, op = "in", a = lo, b = hi } end
		if hi >= def.top then return { k = row.k, op = "ge", a = lo } end
		if lo <= 0 then return { k = row.k, op = "le", a = hi } end
		return { k = row.k, op = "in", a = lo, b = hi }
	end
	return { k = row.k, n = row.n and true or nil, v = copy(row.v) }
end
-- The draft as rules. A row with nothing picked, or a number box left empty, has no values: such a row is ignored
-- (Rules:Fits skips it, and it isn't saved).
function E:Rules()
	local d, rows = self.draft, {}
	for _, r in ipairs(d and d.rows or {}) do
		local def = ns.Rules.KEYS[r.k]
		if r.kept or not def then
			rows[#rows + 1] = { k = r.k, v = r.v, n = r.n }
		elseif def.number then
			local v = {}
			if r.op == "le" then if r.a then v = { 0, r.a } end
			elseif r.op == "in" then if r.a and r.b then v = { math.min(r.a, r.b), math.max(r.a, r.b) } end
			elseif r.a then v = { r.a, def.top } end
			rows[#rows + 1] = { k = r.k, v = v }
		else
			rows[#rows + 1] = { k = r.k, v = r.v, n = r.n }
		end
	end
	return { mode = d and d.mode == "any" and "any" or "all", rows = rows }
end
-- Does this draft row count yet?
local function rowUsable(r)
	local def = ns.Rules.KEYS[r.k]
	if r.kept or not def then return true end
	if def.number then return r.a ~= nil and (r.op ~= "in" or r.b ~= nil) end
	return #r.v > 0
end

-- What a list row shows as chips: every choice for a short list (Quality, Binding); for a long one (Type, Slot) the
-- ones picked. A value no choice covers (a quality past Legendary, a slot this client doesn't name) gets a chip of its
-- own, so it can always be taken off.
function E:RowOptions(row)
	local R = ns.Rules
	local out, covered = {}, {}
	if row.k == "type" then
		for _, v in ipairs(row.v) do out[#out + 1] = { label = R:TypeLabel(v), v = { v } } end
		return out
	end
	for _, o in ipairs(R:Options(row.k)) do
		local some = false
		for _, v in ipairs(o.v) do if has(row.v, v) then some = true; covered[v] = true end end
		if INLINE[row.k] or some then out[#out + 1] = o end
	end
	for _, v in ipairs(row.v) do
		if not covered[v] then out[#out + 1] = { label = R:ValueLabel(row.k, v), v = { v }, quality = row.k == "quality" and v or nil } end
	end
	return out
end

------------------------------------------------------------------------
-- A number box: one box for a plain number, or gold, silver and copper
------------------------------------------------------------------------
local BOX_W, NUM_W = { 38, 22, 22 }, 52
local function numInput(parent, onChange)
	local n = CreateFrame("Frame", nil, parent); n:SetSize(NUM_W, 20)
	n.boxes, n.tags = {}, {}
	for i, tag in ipairs({ "g", "s", "c" }) do
		local b = CreateFrame("EditBox", nil, n, "InputBoxTemplate")
		b:SetAutoFocus(false); b:SetNumeric(true); b:SetHeight(20); b:SetMaxLetters(i == 1 and 4 or 2)
		b:SetScript("OnTextChanged", function(box, user) if user then onChange(n) end end)
		b:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
		b:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
		b:SetScript("OnTabPressed", function(box)
			local nxt = n.boxes[i + 1]
			if nxt and nxt:IsShown() then nxt:SetFocus() else box:ClearFocus() end
		end)
		n.boxes[i] = b
		local t = n:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); t:SetText(tag); n.tags[i] = t
	end
	-- A plain number, or nil while the box is empty; money as copper, nil while all three are empty.
	function n:Get()
		if not self.money then return tonumber(self.boxes[1]:GetText()) end
		local g, s, c = tonumber(self.boxes[1]:GetText()), tonumber(self.boxes[2]:GetText()), tonumber(self.boxes[3]:GetText())
		if not (g or s or c) then return nil end
		return (g or 0) * 10000 + (s or 0) * 100 + (c or 0)
	end
	-- Lays the boxes out for a plain number or for money, and shows a value. The text is only written when it says
	-- something else than the boxes already do, so typing is never interrupted.
	function n:Set(value, money)
		money = money and true or false
		if self.money ~= money then
			self.money = money
			local x = 6
			for i, b in ipairs(self.boxes) do
				local show = money or i == 1
				b:SetShown(show); self.tags[i]:SetShown(money)
				if show then
					local w = money and BOX_W[i] or 44
					b:SetWidth(w); b:ClearAllPoints(); b:SetPoint("LEFT", self, "LEFT", x, 0)
					self.tags[i]:ClearAllPoints(); self.tags[i]:SetPoint("LEFT", b, "RIGHT", 2, 0)
					x = x + w + (money and 20 or 2)
				end
			end
			self.boxes[1]:SetMaxLetters(4)
			self:SetWidth(money and (x - 10) or NUM_W)
			for _, b in ipairs(self.boxes) do b:SetText("") end
		end
		if self:Get() == value then return end
		if value == nil then
			for _, b in ipairs(self.boxes) do b:SetText("") end
		elseif money then
			self.boxes[1]:SetText(("%d"):format(math.floor(value / 10000)))
			self.boxes[2]:SetText(("%d"):format(math.floor(value / 100) % 100))
			self.boxes[3]:SetText(("%d"):format(value % 100))
		else
			self.boxes[1]:SetText(("%d"):format(value))
		end
	end
	return n
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
	f.add = ns.TextButton(f.rulesChild, "+ Add a Rule", 104, function(b) E:AddMenu(b) end); f.add:SetHeight(22)
	f.hint = text(f.rulesChild, nil, RULES_W - 4); f.hint:SetText("Pick two or more on one line and either one counts.")
	f.order = text(f.rulesChild, nil, RULES_W - 4)
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
	f.foot = text(f, nil, LW); f.foot:SetPoint("BOTTOMLEFT", PAD, 14); f.foot:SetText("Nothing changes in your bags until you save.")
	f.err = text(f, nil, LW); f.err:SetPoint("BOTTOMLEFT", PAD, 30); f.err:SetTextColor(1, 0.4, 0.4); f.err:SetWordWrap(false)
	f.save = ns.TextButton(f, "Save Section", 116, function() E:Save() end); f.save:SetHeight(24); f.save:SetPoint("BOTTOMRIGHT", -12, 12)
	f.cancel = ns.TextButton(f, "Cancel", 70, function() f:Hide() end); f.cancel:SetHeight(24); f.cancel:SetPoint("RIGHT", f.save, "LEFT", -6, 0)
	-- while the second window is up, this one waits behind a shade
	f.shade = CreateFrame("Frame", nil, f); f.shade:SetAllPoints(f); f.shade:EnableMouse(true)
	f.shade:SetFrameLevel(f:GetFrameLevel() + 30)
	f.shade.tex = f.shade:CreateTexture(nil, "BACKGROUND"); f.shade.tex:SetAllPoints(); f.shade.tex:SetColorTexture(0, 0, 0, 0.5)
	f.shade:Hide()
	f:SetScript("OnHide", function() f.edit:ClearFocus(); E:ClosePicker() end)
	f.classicSpec = ns.Classic.DialogSpec(f, { restore = function() Skins:ApplyBackdrop(f); local s = Skins:Current(); f:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1) end })
	Skins:Register(f, function(fr)
		Skins:ApplyBackdrop(fr); local s = Skins:Current(); fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)
		fr.title:SetTextColor(unpack(s.heading)); fr.shownTitle:SetTextColor(unpack(s.heading))
		for _, t in ipairs({ fr.nameLabel, fr.shownSub, fr.hint, fr.order, fr.foot }) do t:SetTextColor(unpack(s.muted)) end
		fr.ask:SetTextColor(unpack(s.text))
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

function E:SetMode(mode)
	if not self.draft then return end
	self.draft.mode = mode == "any" and "any" or "all"
	self:Refresh()
end
function E:Error(text)
	local f = self.frame
	if f then f.err:SetText(text or "") end
end

------------------------------------------------------------------------
-- A rule's row
------------------------------------------------------------------------
local function ruleRow(f, i)
	local r = f.rows[i]
	if r then return r end
	r = CreateFrame("Frame", nil, f.rulesChild); r:SetSize(RULES_W, 24)
	r.index = i
	r.label = r:CreateFontString(nil, "OVERLAY", "GameFontNormal"); r.label:SetPoint("TOPLEFT", 0, -4)
	r.label:SetJustifyH("LEFT"); r.label:SetWidth(LABEL_W); r.label:SetWordWrap(false)
	r.verb = ns.TextButton(r, "is", 52, function(b) E:VerbClick(i, b) end); r.verb:SetHeight(20); r.verb:SetPoint("TOPLEFT", LABEL_W, -1)
	r.remove = ns.IconButton(r, "Interface\\AddOns\\BagSmith\\Media\\ui-close.tga", "Remove this rule", function() E:RemoveRow(i) end)
	r.remove:SetSize(18, 18); r.remove:SetPoint("TOPRIGHT", -2, -2)
	r.note = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.note:SetJustifyH("LEFT"); r.note:SetWidth(RULES_W - 4)
	r.chips = {}
	r.choose = ns.TextButton(r, "Choose...", 70, function() E:OpenPicker(i) end); r.choose:SetHeight(CHIP_H)
	r.choose.tip = "Opens the whole list to pick from."
	r.andText = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.andText:SetText("and")
	r.num = {}
	for j = 1, 2 do
		r.num[j] = numInput(r, function(n)
			local row = E.draft and E.draft.rows[i]
			if not row then return end
			if j == 1 then row.a = n:Get() else row.b = n:Get() end
			E:Error("")
			E:Refresh()
		end)
	end
	r.line = r:CreateTexture(nil, "BACKGROUND"); r.line:SetHeight(1)
	r.line:SetPoint("BOTTOMLEFT", 0, 0); r.line:SetPoint("BOTTOMRIGHT", 0, 0)
	f.rows[i] = r
	return r
end
local function rowChip(r, j)
	local c = r.chips[j]
	if c then return c end
	c = ns.TextButton(r, "", 40, function(b) E:ChipClick(r.index, b.option) end); c:SetHeight(CHIP_H)
	r.chips[j] = c
	return c
end
-- Lays one rule out and returns its height.
function E:LayoutRow(r, row, s)
	local R = ns.Rules
	local def = R.KEYS[row.k]
	r.label:SetWidth((row.kept or not def) and (RULES_W - 30) or LABEL_W)   -- ("Another addon's rule" has the line to itself)
	r.label:SetText(R:KeyLabel(row.k)); r.label:SetTextColor(unpack(s.heading))
	r.line:SetColorTexture(s.line[1], s.line[2], s.line[3], 0.6)
	local number, list = def and def.number, def and not def.number and not row.kept
	local used = 0
	-- is / is not, or at least / at most / between
	r.verb:SetShown(def ~= nil and not row.kept)
	if number then
		r.verb:SetWidth(74); r.verb.label:SetText(OP_TEXT[row.op] or OP_TEXT.ge); r.verb:SetActive(false)
		r.verb.tip = "At least, at most, or between two numbers."
	elseif list then
		r.verb:SetWidth(52); r.verb.label:SetText(row.n and "is not" or "is"); r.verb:SetActive(row.n and true or false)
		r.verb.tip = "Switch between is and is not."
	end
	local y = 26
	-- the choices
	for j, o in ipairs(list and self:RowOptions(row) or {}) do
		local c = rowChip(r, j)
		local on = anyOf(row.v, o)
		local label = o.label
		if on and o.quality then label = (qualityHex(o.quality) or "") .. label .. (qualityHex(o.quality) and "|r" or "") end
		c.option = o
		c.label:SetText(label)
		c.tip = not INLINE[row.k] and "Click to take this off the rule." or nil
		c:SetActive(on)
		used = j
	end
	local x = 0
	local function place(widget, w)
		if x > 0 and x + w > RULES_W - 4 then x = 0; y = y + CHIP_H + CHIP_GAP end
		widget:ClearAllPoints(); widget:SetPoint("TOPLEFT", r, "TOPLEFT", x, -y); widget:Show()
		x = x + w + CHIP_GAP
	end
	for j = 1, used do
		local c = r.chips[j]
		local w = math.max(30, math.ceil(c.label:GetStringWidth() or 0) + 16)
		w = math.min(w, RULES_W - 4)
		c:SetWidth(w)
		place(c, w)
	end
	for j = used + 1, #r.chips do r.chips[j]:Hide() end
	r.choose:SetShown(list and PICKED[row.k] and true or false)
	if list and PICKED[row.k] then
		r.choose:SetActive(false)
		place(r.choose, 70)
	end
	if list and (used > 0 or PICKED[row.k]) then y = y + CHIP_H + 4 end
	-- the numbers, beside the choice of at least, at most or between
	r.andText:Hide()
	for j = 1, 2 do r.num[j]:Hide() end
	if number then
		local nx, ny = LABEL_W + 80, 1
		r.num[1]:Set(row.a, def.money)
		r.num[1]:ClearAllPoints(); r.num[1]:SetPoint("TOPLEFT", r, "TOPLEFT", nx, -ny); r.num[1]:Show()
		if row.op == "in" then
			-- a plain number's second box shares the line; money's (three boxes) takes the next one
			if def.money then ny = ny + 24 else nx = nx + NUM_W + 4 end
			r.andText:SetTextColor(unpack(s.text))
			r.andText:ClearAllPoints(); r.andText:SetPoint("TOPLEFT", r, "TOPLEFT", nx, -(ny + 4)); r.andText:Show()
			r.num[2]:Set(row.b, def.money)
			r.num[2]:ClearAllPoints(); r.num[2]:SetPoint("TOPLEFT", r, "TOPLEFT", nx + 26, -ny); r.num[2]:Show()
		end
		y = ny + 26
	end
	-- a word when the row doesn't count yet, or can't be changed here
	local note
	if row.kept or not def then note = "From another addon or a newer BagSmith. It's kept as it is."
	elseif number and not rowUsable(row) then note = "Type a number, or this rule is ignored."
	elseif list and #row.v == 0 then note = "Pick at least one, or this rule is ignored." end
	r.note:SetShown(note ~= nil)
	if note then
		r.note:SetText(note)
		if row.kept or not def then r.note:SetTextColor(unpack(s.muted)) else r.note:SetTextColor(0.95, 0.6, 0.45) end
		r.note:ClearAllPoints(); r.note:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -y)
		y = y + 16
	end
	y = y + 6
	r:SetHeight(y)
	return y
end

function E:VerbClick(i, button)
	local row = self.draft and self.draft.rows[i]
	local def = row and ns.Rules.KEYS[row.k]
	if not def or row.kept then return end
	if def.number then
		local items = {}
		for _, op in ipairs(OPS) do
			items[#items + 1] = { text = OP_TEXT[op], checked = (row.op or "ge") == op, onClick = function()
				local now = E.draft and E.draft.rows[i]
				if now ~= row then return end
				-- "between" keeps the number already typed as its first; leaving it drops the second
				row.op = op
				if op ~= "in" then row.b = nil end
				E:Refresh()
			end }
		end
		return ns.ShowMenu(items, button)
	end
	row.n = (not row.n) or nil
	self:Refresh()
end
function E:ChipClick(i, option)
	local row = self.draft and self.draft.rows[i]
	if not (row and option and row.v) then return end
	toggle(row.v, option)
	self:Error("")
	self:Refresh()
end
function E:RemoveRow(i)
	local d = self.draft
	if not (d and d.rows[i]) then return end
	table.remove(d.rows, i)
	self:Error("")
	self:Refresh()
end
-- + Add a Rule: what should the rule look at?
function E:AddMenu(button)
	local d = self.draft
	if not d then return end
	local R = ns.Rules
	if #d.rows >= R.MAX_ROWS then
		return ns.ShowMenu({ { text = ("A section can have %d rules, and this one has them all."):format(R.MAX_ROWS), disabled = true } }, button)
	end
	local items = { { text = "What should the rule look at?", title = true } }
	for _, kind in ipairs(KINDS) do
		items[#items + 1] = { text = R:KeyLabel(kind.k), tip = kind.hint, onClick = function() E:AddRow(kind.k) end }
	end
	return ns.ShowMenu(items, button)
end
function E:AddRow(k)
	local d = self.draft
	local R = ns.Rules
	local def = R.KEYS[k]
	if not (d and def) or #d.rows >= R.MAX_ROWS then return end
	if PICKED[k] then return self:OpenPicker(nil, k) end   -- a long list: picked first, added by Add Rule
	if def.number then d.rows[#d.rows + 1] = { k = k, op = "ge" } else d.rows[#d.rows + 1] = { k = k, v = {} } end
	self:Refresh()
	-- the new rule in view
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
	local here, elsewhere = S:PreviewRules(rules, d.id)
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
		for _, r in ipairs(d.rows) do if rowUsable(r) then usable = usable + 1 end end
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
	local y, lists = 0, 0
	for i, row in ipairs(d.rows) do
		local r = ruleRow(f, i)
		local h = self:LayoutRow(r, row, s)
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", f.rulesChild, "TOPLEFT", 0, -y); r:Show()
		y = y + h + 6
		local def = ns.Rules.KEYS[row.k]
		if def and not def.number and not row.kept then lists = lists + 1 end
	end
	for i = #d.rows + 1, #f.rows do f.rows[i]:Hide() end
	f.add:ClearAllPoints(); f.add:SetPoint("TOPLEFT", f.rulesChild, "TOPLEFT", 0, -y)
	f.add:SetAlpha(#d.rows >= ns.Rules.MAX_ROWS and 0.5 or 1)
	y = y + 30
	f.hint:SetShown(lists > 0)
	if lists > 0 then f.hint:ClearAllPoints(); f.hint:SetPoint("TOPLEFT", f.rulesChild, "TOPLEFT", 0, -y); y = y + 16 end
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
-- id: the section to edit; nil for a new one.
function E:Open(id)
	if not ns.Rules then return end
	local c = id and S:Custom(id) or nil
	if id and not c then return end
	local f = self:Window()
	self:ClosePicker()
	self.db = ns.db
	local d = { id = c and c.id or nil, mode = "all", rows = {} }
	if c and type(c.rules) == "table" then
		d.mode = c.rules.mode == "any" and "any" or "all"
		for _, row in ipairs(c.rules.rows or {}) do
			if type(row) == "table" and type(row.k) == "string" and type(row.v) == "table" then d.rows[#d.rows + 1] = draftRow(row) end
		end
	end
	self.draft = d
	-- (number boxes start empty, so each shows its number the usual way, not as it was last typed)
	for _, r in ipairs(f.rows) do
		for _, num in ipairs(r.num) do for _, box in ipairs(num.boxes) do box:SetText("") end end
	end
	f.title:SetText(c and "Edit Section" or "New Section")
	f.save.label:SetText(c and "Save Section" or "Create Section")
	f.edit:SetText(c and c.name or "")
	f.err:SetText("")
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
	f:Hide()
	return id
end
function S:EditSection(id) return E:Open(id) end

------------------------------------------------------------------------
-- The second window: the whole list for a Type or Slot rule
------------------------------------------------------------------------
function E:Picker()
	local p = self.picker
	if p then return p end
	local f = self:Window()
	p = CreateFrame("Frame", "BagSmithSectionPicker", f, "BackdropTemplate")
	p:SetFrameLevel(f:GetFrameLevel() + 40)
	p:SetSize(PW, PH); p:SetClampedToScreen(true); p:EnableMouse(true)
	p:SetPoint("CENTER", f, "CENTER", 0, 0)
	p:SetMovable(true); p:RegisterForDrag("LeftButton")
	p:SetScript("OnDragStart", p.StartMoving); p:SetScript("OnDragStop", p.StopMovingOrSizing)
	local function text(template, width)
		local t = p:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
		t:SetJustifyH("LEFT"); t:SetJustifyV("TOP")
		if width then t:SetWidth(width) end
		return t
	end
	p.title = text("GameFontNormalLarge"); p.title:SetPoint("TOPLEFT", 12, -12); p.title:SetText("Add a Rule")
	p.head = text("GameFontNormal"); p.head:SetPoint("TOPLEFT", PAD, -40)
	p.hint = text(); p.hint:SetPoint("LEFT", p.head, "RIGHT", 8, 0)
	p.ask = text(nil, PW - PAD * 2); p.ask:SetPoint("TOPLEFT", PAD, -60)
	p.scroll = CreateFrame("ScrollFrame", "BagSmithSectionPickerScroll", p, "UIPanelScrollFrameTemplate")
	p.scroll:SetPoint("TOPLEFT", PAD, -80); p.scroll:SetSize(PW - PAD * 2 - 22, PH - 80 - 130)
	p.child = CreateFrame("Frame", nil, p.scroll); p.child:SetSize(PW - PAD * 2 - 22, 1); p.scroll:SetScrollChild(p.child)
	ns.WheelStep(p.scroll, PROW * ns.WHEEL_ROWS)
	p.rows = {}
	p.note = text(nil, PW - PAD * 2); p.note:SetPoint("BOTTOMLEFT", PAD, 92)
	p.note:SetText("This list comes from the game itself, so a new kind of item shows up here on its own.")
	p.sayLabel = text(); p.sayLabel:SetPoint("BOTTOMLEFT", PAD, 74); p.sayLabel:SetText("Your rule will say")
	p.say = text(nil, PW - PAD * 2); p.say:SetPoint("TOPLEFT", p, "BOTTOMLEFT", PAD, 70); p.say:SetHeight(28)
	p.ok = ns.TextButton(p, "Add Rule", 90, function() E:PickerDone() end); p.ok:SetHeight(24); p.ok:SetPoint("BOTTOMRIGHT", -12, 12)
	p.cancel = ns.TextButton(p, "Cancel", 70, function() E:ClosePicker() end); p.cancel:SetHeight(24); p.cancel:SetPoint("RIGHT", p.ok, "LEFT", -6, 0)
	p:SetScript("OnHide", function() f.shade:Hide(); E.pick = nil end)
	p.classicSpec = ns.Classic.DialogSpec(p, { restore = function() Skins:ApplyBackdrop(p); local s = Skins:Current(); p:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1) end, close = function() E:ClosePicker() end })
	Skins:Register(p, function(fr)
		Skins:ApplyBackdrop(fr); local s = Skins:Current(); fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)
		fr.title:SetTextColor(unpack(s.heading)); fr.head:SetTextColor(unpack(s.heading))
		for _, t in ipairs({ fr.hint, fr.note, fr.sayLabel }) do t:SetTextColor(unpack(s.muted)) end
		fr.ask:SetTextColor(unpack(s.text)); fr.say:SetTextColor(unpack(s.text))
		ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
		if ns.Classic.DressScrollBar then ns.Classic:DressScrollBar(fr.scroll, ns.Classic.IsOn()) end
		if fr:IsShown() then E:RefreshPicker() end
	end)
	p:Hide()
	self.picker = p
	return p
end
function E:ClosePicker()
	local p = self.picker
	if p and p:IsShown() then p:Hide() end
	if self.frame then self.frame.shade:Hide() end
	self.pick = nil
end
-- index: the rule whose values to change; nil with k: a new rule of that kind.
function E:OpenPicker(index, k)
	local d = self.draft
	if not d then return end
	local row = index and d.rows[index]
	if index and not (row and row.v and PICKED[row.k]) then return end
	k = row and row.k or k
	if not PICKED[k] then return end
	local p = self:Picker()
	local pick = { index = index, row = row, k = k, n = row and row.n or nil, v = copy(row and row.v), open = {} }
	-- a type with something ticked starts open
	if k == "type" then
		for _, v in ipairs(pick.v) do local class = tonumber(tostring(v):match("^(%d+):")); if class then pick.open[class] = true end end
	end
	self.pick = pick
	p.title:SetText(index and "Change a Rule" or "Add a Rule")
	p.ok.label:SetText(index and "Done" or "Add Rule")
	p.head:SetText(ns.Rules:KeyLabel(k)); p.hint:SetText(PICK_HINT[k] or "")
	p.ask:SetText(PICK_ASK[k] or "")
	p.note:SetShown(k == "type")
	p.scroll:SetVerticalScroll(0)
	if ns.Classic then ns.Classic:RefreshTitle(p) end
	self.frame.shade:Show()
	p:ClearAllPoints(); p:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
	p:Show()
	self:RefreshPicker()
	return p
end
-- The rows to show: for Type, a title for each kind of item (click to open it), then "Any kind of ..." and its kinds;
-- a type with one kind or none is a single line. For Slot, one line each.
function E:PickerList()
	local pick, R = self.pick, ns.Rules
	local list, covered = {}, {}
	if not pick then return list end
	if pick.k == "type" then
		for _, g in ipairs(R:TypeGroups()) do
			covered[g.any] = true
			for _, kind in ipairs(g.kinds) do covered[kind.v] = true end
			if #g.kinds <= 1 then
				local o = { v = { g.any, g.kinds[1] and g.kinds[1].v }, add = { g.any } }
				list[#list + 1] = { label = g.label, option = o, on = anyOf(pick.v, o) }
			else
				local any, ticked = has(pick.v, g.any) ~= nil, 0
				for _, kind in ipairs(g.kinds) do if has(pick.v, kind.v) then ticked = ticked + 1 end end
				local count = any and "every kind" or (ticked > 0 and ("%d of %d ticked"):format(ticked, #g.kinds) or ("%d kinds"):format(#g.kinds))
				list[#list + 1] = { head = true, class = g.class, label = g.label, count = count, open = pick.open[g.class] and true or false }
				if pick.open[g.class] then
					list[#list + 1] = { label = "Any kind of " .. g.label, option = { v = { g.any } }, on = any, indent = true, group = g }
					for _, kind in ipairs(g.kinds) do
						list[#list + 1] = { label = kind.label, option = { v = { kind.v } }, on = any or has(pick.v, kind.v) ~= nil, locked = any, indent = true }
					end
				end
			end
		end
	else
		for _, o in ipairs(R:Options(pick.k)) do
			for _, v in ipairs(o.v) do covered[v] = true end
			list[#list + 1] = { label = o.label, option = o, on = anyOf(pick.v, o) }
		end
	end
	-- anything ticked that the lists don't name can still be unticked
	for _, v in ipairs(pick.v) do
		if not covered[v] then list[#list + 1] = { label = R:ValueLabel(pick.k, v), option = { v = { v } }, on = true } end
	end
	return list
end
local function pickerRow(p, i)
	local r = p.rows[i]
	if r then return r end
	r = CreateFrame("Button", nil, p.child); r:SetSize(PW - PAD * 2 - 22, PROW)
	r.arrow = r:CreateTexture(nil, "ARTWORK"); r.arrow:SetSize(12, 12); r.arrow:SetPoint("LEFT", 4, 0)
	r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate"); r.check:SetSize(22, 22)
	r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.label:SetJustifyH("LEFT"); r.label:SetWordWrap(false)
	r.count = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.count:SetPoint("RIGHT", -6, 0)
	r:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
	local hl = r:GetHighlightTexture(); if hl and hl.SetVertexColor then hl:SetVertexColor(1, 1, 1, 0.06) end
	r:SetScript("OnClick", function(self) E:PickerClick(self.entry) end)
	r.check:SetScript("OnClick", function(self) E:PickerClick(self:GetParent().entry) end)
	p.rows[i] = r
	return r
end
function E:PickerClick(entry)
	local pick = self.pick
	if not (pick and entry) then return end
	if entry.head then
		pick.open[entry.class] = (not pick.open[entry.class]) or nil
	elseif not entry.locked then
		local on = toggle(pick.v, entry.option)
		-- "Any kind of Armor" stands for each kind of it: those come off the list
		if on and entry.group then
			for _, kind in ipairs(entry.group.kinds) do local i = has(pick.v, kind.v); if i then table.remove(pick.v, i) end end
		end
	end
	self:RefreshPicker()
end
function E:RefreshPicker()
	local p, pick = self.picker, self.pick
	if not (p and pick and p:IsShown()) then return end
	local s, R = Skins:Current(), ns.Rules
	local list = self:PickerList()
	p.list = list
	for i, entry in ipairs(list) do
		local r = pickerRow(p, i)
		r.entry = entry
		r.arrow:SetShown(entry.head and true or false); r.check:SetShown(not entry.head); r.count:SetShown(entry.head and true or false)
		r.label:ClearAllPoints()
		if entry.head then
			r.arrow:SetTexture(entry.open and "Interface\\AddOns\\BagSmith\\Media\\ui-chev-down.tga" or "Interface\\AddOns\\BagSmith\\Media\\ui-chev-right.tga")
			r.arrow:SetVertexColor(unpack(s.muted))
			r.label:SetPoint("LEFT", 22, 0); r.label:SetTextColor(unpack(s.heading))
			r.count:SetText(entry.count); r.count:SetTextColor(unpack(s.muted))
		else
			local x = entry.indent and 20 or 0
			r.check:ClearAllPoints(); r.check:SetPoint("LEFT", x, 0)
			r.check:SetChecked(entry.on and true or false)
			r.check:SetAlpha(entry.locked and 0.45 or 1)
			r.label:SetPoint("LEFT", x + 24, 0)
			if entry.locked then r.label:SetTextColor(unpack(s.muted)) else r.label:SetTextColor(unpack(s.text)) end
		end
		r.label:SetText(entry.label)
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", p.child, "TOPLEFT", 0, -(i - 1) * PROW); r:Show()
	end
	for i = #list + 1, #p.rows do p.rows[i]:Hide() end
	local h, view = #list * PROW, PH - 80 - 130
	p.child:SetHeight(math.max(1, h))
	if p.scroll.ScrollBar then p.scroll.ScrollBar:SetShown(h > view) end
	if (p.scroll:GetVerticalScroll() or 0) > math.max(0, h - view) then p.scroll:SetVerticalScroll(math.max(0, h - view)) end
	local ready = #pick.v > 0
	p.say:SetText(ready and R:RowText({ k = pick.k, v = pick.v, n = pick.n }) or (PICK_NONE[pick.k] or ""))
	p.ok:SetAlpha(ready and 1 or 0.5)
end
-- Add Rule, or Done: the ticks go onto the rule (a new one needs at least one).
function E:PickerDone()
	local pick, d = self.pick, self.draft
	if not (pick and d) then return self:ClosePicker() end
	if pick.index then
		-- only if the rule it was opened for is still there
		if d.rows[pick.index] == pick.row then pick.row.v = copy(pick.v) end
	else
		if #pick.v == 0 then return end
		if #d.rows < ns.Rules.MAX_ROWS then d.rows[#d.rows + 1] = { k = pick.k, v = copy(pick.v) } end
	end
	self:ClosePicker()
	self:Error("")
	self:Refresh()
	if not pick.index and self.frame then self.frame.rules:SetVerticalScroll(math.max(0, (self.frame.rulesHeight or 0) - (H - TOP - BOTTOM))) end
end

ns:OnSignal("ADDON_READY", function()
	-- the list on the right follows your bags, and your other sections, while the window is up
	local function follow() if E.frame and E.frame:IsShown() then E:Refresh() end end
	ns:OnSignal("ITEMS_CHANGED", follow)
	ns:OnSignal("SETTINGS_CHANGED", function(key) if key == "customSections" then follow() end end)
	ns:OnSignal("PROFILE_ACTIVATED", function() if E.frame and E.frame:IsShown() then E.frame:Hide() end end)
end)
