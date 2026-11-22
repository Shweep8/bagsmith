--[[
	Frames/RuleList.lua (1.10.0-beta4; its rows were the section editor's in beta3)

	A list of rules to edit: the rows, "+ Add a Rule", and the second window where a long list (Type, Slot, Section)
	is ticked. The section editor and the Filters window each have one, so a rule looks and works the same in both.

	ns.RuleList is a prototype: an owner makes a table with it as its __index and gives it
		draft    { mode = "all" | "any", rows = { ... } }, the rules as the list holds them while they're edited
		parent   the frame the rows are made in (they're laid out from its top left)
		width    the room a row has
		host     the window: the second window is its child, and it waits behind a shade while that one is up
		filter   true for a filter's rules: the keys that are only a filter's are offered too
		rows     {} (the rows made so far)
	and may replace
		Changed()      called after anything in the draft changed (lay out again, apply, redraw)
		Added()        called after a rule was added (bring it into view)
		Options(k)     the choices for a key (the owner knows which bags or sections are in play)

	A list row in the draft is { k, n, v = { ... } }; a number row { k, op = "ge" | "le" | "in", a, b }, where a and b
	are nil while their boxes are empty; a row this list can't edit (a key this version doesn't know, or a filter's key
	among a section's rules) is kept exactly as it came, with kept = true. L:Rules() turns the draft back into rules.
--]]
local ADDON, ns = ...
local Skins = ns.Skins
local RL = {}
RL.__index = RL
ns.RuleList = RL

local LABEL_W, CHIP_H, CHIP_GAP = 88, 20, 4
local PAD, PW, PH, PROW = 14, 330, 480, 22
local OPS = { "ge", "le", "in" }
local OP_TEXT = { ge = "at least", le = "at most", ["in"] = "between" }
local INLINE = { quality = true, bind = true, bag = true }   -- few enough choices to show them all on the row
local PICKED = { type = true, slot = true, sec = true }      -- long lists: picked in the second window
local KINDS = {
	{ k = "type", hint = "What kind of item it is: Cloth, Herbs, Plate, Potions..." },
	{ k = "slot", hint = "Where it's worn: Head, Trinket, Two-Hand..." },
	{ k = "quality", hint = "Common, Uncommon, Rare, Epic..." },
	{ k = "bind", hint = "Soulbound, Binds when equipped, No binding..." },
	{ k = "ilvl", hint = "At least, at most, or between two numbers." },
	{ k = "price", hint = "What a vendor pays for one: at least, at most, or between." },
}
-- (for filters only: about where an item is right now, so never a section's)
local FILTER_KINDS = {
	{ k = "sec", hint = "The section it's in: Gear, Trade Goods, one of yours..." },
	{ k = "bag", hint = "Which of your bags it sits in." },
	{ k = "age", hint = "How long it has been in your bags, in hours." },
}
local PICK_ASK = { type = "Tick every kind you want:", slot = "Tick every slot you want:", sec = "Tick every section you want:" }
local PICK_NONE = { type = "Tick at least one kind.", slot = "Tick at least one slot.", sec = "Tick at least one section." }
local PICK_HINT = { type = "What kind of item it is", slot = "Where it's worn", sec = "Where it's filed in your bags" }
RL.OP_TEXT = OP_TEXT

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

------------------------------------------------------------------------
-- The draft
------------------------------------------------------------------------
-- The key's definition, if this list can edit it: a filter's own keys only in a filter's list.
function RL:Def(k)
	local def = ns.Rules.KEYS[k]
	if def and def.filterOnly and not self.filter then return nil end
	return def
end
function RL:DraftRow(row)
	local def = self:Def(row.k)
	if not def then return { k = row.k, v = copy(row.v), n = row.n, kept = true } end
	if def.number then
		local lo, hi = row.v[1], row.v[2]
		if type(lo) ~= "number" or type(hi) ~= "number" then return { k = row.k, op = "ge" } end
		if hi >= def.top then return { k = row.k, op = "ge", a = lo } end
		if lo == hi then return { k = row.k, op = "in", a = lo, b = hi } end
		if lo <= 0 then return { k = row.k, op = "le", a = hi } end
		return { k = row.k, op = "in", a = lo, b = hi }
	end
	return { k = row.k, n = row.n and true or nil, v = copy(row.v) }
end
-- A draft from saved rules (nil: none).
function RL:DraftFrom(rules)
	local d = { mode = "all", rows = {} }
	if type(rules) == "table" then
		d.mode = rules.mode == "any" and "any" or "all"
		for _, row in ipairs(rules.rows or {}) do
			if type(row) == "table" and type(row.k) == "string" and type(row.v) == "table" then d.rows[#d.rows + 1] = self:DraftRow(row) end
		end
	end
	return d
end
-- The draft as rules. A row with nothing picked, or a number box left empty, has no values: such a row is ignored
-- (Rules:Fits skips it, and it isn't saved).
function RL:Rules()
	local d, rows = self.draft, {}
	for _, r in ipairs(d and d.rows or {}) do
		local def = self:Def(r.k)
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
function RL:RowUsable(r)
	local def = self:Def(r.k)
	if r.kept or not def then return true end
	if def.number then return r.a ~= nil and (r.op ~= "in" or r.b ~= nil) end
	return #r.v > 0
end
-- The choices for a key. An owner replaces this where it knows more (which bags, which sections).
function RL:Options(k) return ns.Rules:Options(k) end
-- What a list row shows as chips: every choice for a short list (Quality, Binding, Bag); for a long one (Type, Slot,
-- Section) the ones picked. A value no choice covers (a quality past Legendary, a slot this client doesn't name, a bag
-- that isn't equipped now) gets a chip of its own, so it can always be taken off.
function RL:RowOptions(row)
	local R = ns.Rules
	local out, covered = {}, {}
	if row.k == "type" then
		for _, v in ipairs(row.v) do out[#out + 1] = { label = R:TypeLabel(v), v = { v } } end
		return out
	end
	for _, o in ipairs(self:Options(row.k)) do
		local some = false
		for _, v in ipairs(o.v) do if has(row.v, v) then some = true; covered[v] = true end end
		if INLINE[row.k] or some then out[#out + 1] = o end
	end
	for _, v in ipairs(row.v) do
		if not covered[v] then out[#out + 1] = { label = R:ValueLabel(row.k, v), v = { v }, quality = row.k == "quality" and v or nil } end
	end
	return out
end
-- An owner replaces these.
function RL:Changed() end
function RL:Added() end

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
-- Number boxes start empty when a list is opened for something else, so each shows its number the usual way, not as it
-- was last typed.
function RL:ClearBoxes()
	for _, r in ipairs(self.rows or {}) do
		for _, num in ipairs(r.num) do for _, box in ipairs(num.boxes) do box:SetText("") end end
	end
end

------------------------------------------------------------------------
-- A rule's row
------------------------------------------------------------------------
function RL:Row(i)
	local L = self
	local r = L.rows[i]
	if r then return r end
	r = CreateFrame("Frame", nil, L.parent); r:SetSize(L.width, 24)
	r.index = i
	r.label = r:CreateFontString(nil, "OVERLAY", "GameFontNormal"); r.label:SetPoint("TOPLEFT", 0, -4)
	r.label:SetJustifyH("LEFT"); r.label:SetWidth(LABEL_W); r.label:SetWordWrap(false)
	r.verb = ns.TextButton(r, "is", 52, function(b) L:VerbClick(i, b) end); r.verb:SetHeight(20); r.verb:SetPoint("TOPLEFT", LABEL_W, -1)
	r.remove = ns.IconButton(r, "Interface\\AddOns\\BagSmith\\Media\\ui-close.tga", "Remove this rule", function() L:RemoveRow(i) end)
	r.remove:SetSize(18, 18); r.remove:SetPoint("TOPRIGHT", -2, -2)
	r.note = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.note:SetJustifyH("LEFT"); r.note:SetWidth(L.width - 4)
	r.chips = {}
	r.choose = ns.TextButton(r, "Choose...", 70, function() L:OpenPicker(i) end); r.choose:SetHeight(CHIP_H)
	r.choose.tip = "Opens the whole list to pick from."
	r.andText = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.andText:SetText("and")
	r.unitText = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.num = {}
	for j = 1, 2 do
		r.num[j] = numInput(r, function(n)
			local row = L.draft and L.draft.rows[i]
			if not row then return end
			if j == 1 then row.a = n:Get() else row.b = n:Get() end
			L:Changed()
		end)
	end
	r.line = r:CreateTexture(nil, "BACKGROUND"); r.line:SetHeight(1)
	r.line:SetPoint("BOTTOMLEFT", 0, 0); r.line:SetPoint("BOTTOMRIGHT", 0, 0)
	L.rows[i] = r
	return r
end
local function rowChip(L, r, j)
	local c = r.chips[j]
	if c then return c end
	c = ns.TextButton(r, "", 40, function(b) L:ChipClick(r.index, b.option) end); c:SetHeight(CHIP_H)
	r.chips[j] = c
	return c
end
-- Lays one rule out and returns its height.
function RL:LayoutRow(r, row, s)
	local R = ns.Rules
	local def = self:Def(row.k)
	local width = self.width
	r.label:SetWidth((row.kept or not def) and (width - 30) or LABEL_W)   -- ("Another addon's rule" has the line to itself)
	r.label:SetText(def and def.label or R:KeyLabel(row.k)); r.label:SetTextColor(unpack(s.heading))
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
		local c = rowChip(self, r, j)
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
		if x > 0 and x + w > width - 4 then x = 0; y = y + CHIP_H + CHIP_GAP end
		widget:ClearAllPoints(); widget:SetPoint("TOPLEFT", r, "TOPLEFT", x, -y); widget:Show()
		x = x + w + CHIP_GAP
	end
	for j = 1, used do
		local c = r.chips[j]
		local w = math.max(30, math.ceil(c.label:GetStringWidth() or 0) + 16)
		w = math.min(w, width - 4)
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
	r.andText:Hide(); r.unitText:Hide()
	for j = 1, 2 do r.num[j]:Hide() end
	if number then
		local nx, ny = LABEL_W + 80, 1
		local last = r.num[1]
		r.num[1]:Set(row.a, def.money)
		r.num[1]:ClearAllPoints(); r.num[1]:SetPoint("TOPLEFT", r, "TOPLEFT", nx, -ny); r.num[1]:Show()
		if row.op == "in" then
			-- a plain number's second box shares the line; money's (three boxes) takes the next one
			if def.money then ny = ny + 24 else nx = nx + NUM_W + 4 end
			r.andText:SetTextColor(unpack(s.text))
			r.andText:ClearAllPoints(); r.andText:SetPoint("TOPLEFT", r, "TOPLEFT", nx, -(ny + 4)); r.andText:Show()
			r.num[2]:Set(row.b, def.money)
			r.num[2]:ClearAllPoints(); r.num[2]:SetPoint("TOPLEFT", r, "TOPLEFT", nx + 26, -ny); r.num[2]:Show()
			last = r.num[2]
		end
		-- its unit after the last box ("hours")
		if def.unit then
			r.unitText:SetText(def.unit[2]); r.unitText:SetTextColor(unpack(s.text))
			r.unitText:ClearAllPoints(); r.unitText:SetPoint("LEFT", last, "RIGHT", 4, 0); r.unitText:Show()
		end
		y = ny + 26
	end
	-- a word when the row doesn't count yet, or can't be changed here
	local note
	local known = R.KEYS[row.k]
	if known and known.filterOnly and not self.filter then note = "Only a filter can use this rule. Here it fits nothing."
	elseif row.kept or not def then note = "From another addon or a newer BagSmith. It's kept as it is."
	elseif number and not self:RowUsable(row) then note = "Type a number, or this rule is ignored."
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
-- Lays every rule out from the parent's top (y down from there) and returns the height used, and how many of the
-- rules are lists (the hint about picking two on a line is for those).
function RL:Layout(s, top)
	local d = self.draft
	local y, lists = top or 0, 0
	for i, row in ipairs(d and d.rows or {}) do
		local r = self:Row(i)
		local h = self:LayoutRow(r, row, s)
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.left or 0, -y); r:Show()
		y = y + h + 6
		local def = self:Def(row.k)
		if def and not def.number and not row.kept then lists = lists + 1 end
	end
	for i = #(d and d.rows or {}) + 1, #self.rows do self.rows[i]:Hide() end
	return y, lists
end

function RL:VerbClick(i, button)
	local L = self
	local row = self.draft and self.draft.rows[i]
	local def = row and self:Def(row.k)
	if not def or row.kept then return end
	if def.number then
		local items = {}
		for _, op in ipairs(OPS) do
			items[#items + 1] = { text = OP_TEXT[op], checked = (row.op or "ge") == op, onClick = function()
				local now = L.draft and L.draft.rows[i]
				if now ~= row then return end
				-- "between" keeps the number already typed as its first; leaving it drops the second
				row.op = op
				if op ~= "in" then row.b = nil end
				L:Changed()
			end }
		end
		return ns.ShowMenu(items, button)
	end
	row.n = (not row.n) or nil
	self:Changed()
end
function RL:ChipClick(i, option)
	local row = self.draft and self.draft.rows[i]
	if not (row and option and row.v) then return end
	toggle(row.v, option)
	self:Changed()
end
function RL:RemoveRow(i)
	local d = self.draft
	if not (d and d.rows[i]) then return end
	table.remove(d.rows, i)
	self:Changed()
end
-- The kinds of rule this list offers.
function RL:Kinds()
	if not self.filter then return KINDS end
	local out = {}
	for _, kind in ipairs(KINDS) do out[#out + 1] = kind end
	for _, kind in ipairs(FILTER_KINDS) do out[#out + 1] = kind end
	return out
end
-- + Add a Rule: what should the rule look at?
function RL:AddMenu(button)
	local L, d = self, self.draft
	if not d then return end
	local R = ns.Rules
	if #d.rows >= R.MAX_ROWS then
		local words = self.filter and "A filter can have %d rules, and this one has them all." or "A section can have %d rules, and this one has them all."
		return ns.ShowMenu({ { text = words:format(R.MAX_ROWS), disabled = true } }, button)
	end
	local items = { { text = "What should the rule look at?", title = true } }
	for _, kind in ipairs(self:Kinds()) do
		items[#items + 1] = { text = R.KEYS[kind.k].label, tip = kind.hint, gap = kind.k == "price" and self.filter or nil, onClick = function() L:AddRow(kind.k) end }
	end
	return ns.ShowMenu(items, button)
end
function RL:AddRow(k)
	local d = self.draft
	local R = ns.Rules
	local def = self:Def(k)
	if not (d and def) or #d.rows >= R.MAX_ROWS then return end
	if PICKED[k] then return self:OpenPicker(nil, k) end   -- a long list: picked first, added by Add Rule
	if def.number then d.rows[#d.rows + 1] = { k = k, op = "ge" } else d.rows[#d.rows + 1] = { k = k, v = {} } end
	self:Changed()
	self:Added()
end

------------------------------------------------------------------------
-- The second window: the whole list for a Type, Slot or Section rule
------------------------------------------------------------------------
-- While it's up, the host waits behind a shade.
function RL:Shade()
	local host = self.host
	if host.shade then return host.shade end
	local shade = CreateFrame("Frame", nil, host); shade:SetAllPoints(host); shade:EnableMouse(true)
	shade:SetFrameLevel(host:GetFrameLevel() + 30)
	shade.tex = shade:CreateTexture(nil, "BACKGROUND"); shade.tex:SetAllPoints(); shade.tex:SetColorTexture(0, 0, 0, 0.5)
	shade:Hide()
	host.shade = shade
	return shade
end
function RL:Picker()
	local L = self
	local p = self.picker
	if p then return p end
	local host = self.host
	self:Shade()
	p = CreateFrame("Frame", self.pickerName, host, "BackdropTemplate")
	p:SetFrameLevel(host:GetFrameLevel() + 40)
	p:SetSize(PW, PH); p:SetClampedToScreen(true); p:EnableMouse(true)
	p:SetPoint("CENTER", host, "CENTER", 0, 0)
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
	p.scroll = CreateFrame("ScrollFrame", self.pickerName and (self.pickerName .. "Scroll") or nil, p, "UIPanelScrollFrameTemplate")
	p.scroll:SetPoint("TOPLEFT", PAD, -80); p.scroll:SetSize(PW - PAD * 2 - 22, PH - 80 - 130)
	p.child = CreateFrame("Frame", nil, p.scroll); p.child:SetSize(PW - PAD * 2 - 22, 1); p.scroll:SetScrollChild(p.child)
	ns.WheelStep(p.scroll, PROW * ns.WHEEL_ROWS)
	p.rows = {}
	p.note = text(nil, PW - PAD * 2); p.note:SetPoint("BOTTOMLEFT", PAD, 92)
	p.note:SetText("This list comes from the game itself, so a new kind of item shows up here on its own.")
	p.sayLabel = text(); p.sayLabel:SetPoint("BOTTOMLEFT", PAD, 74); p.sayLabel:SetText("Your rule will say")
	p.say = text(nil, PW - PAD * 2); p.say:SetPoint("TOPLEFT", p, "BOTTOMLEFT", PAD, 70); p.say:SetHeight(28)
	p.ok = ns.TextButton(p, "Add Rule", 90, function() L:PickerDone() end); p.ok:SetHeight(24); p.ok:SetPoint("BOTTOMRIGHT", -12, 12)
	p.cancel = ns.TextButton(p, "Cancel", 70, function() L:ClosePicker() end); p.cancel:SetHeight(24); p.cancel:SetPoint("RIGHT", p.ok, "LEFT", -6, 0)
	p:SetScript("OnHide", function() host.shade:Hide(); L.pick = nil end)
	p.classicSpec = ns.Classic.DialogSpec(p, { restore = function() Skins:ApplyBackdrop(p); local s = Skins:Current(); p:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1) end, close = function() L:ClosePicker() end })
	Skins:Register(p, function(fr)
		Skins:ApplyBackdrop(fr); local s = Skins:Current(); fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)
		fr.title:SetTextColor(unpack(s.heading)); fr.head:SetTextColor(unpack(s.heading))
		for _, t in ipairs({ fr.hint, fr.note, fr.sayLabel }) do t:SetTextColor(unpack(s.muted)) end
		fr.ask:SetTextColor(unpack(s.text)); fr.say:SetTextColor(unpack(s.text))
		ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
		if ns.Classic.DressScrollBar then ns.Classic:DressScrollBar(fr.scroll, ns.Classic.IsOn()) end
		if fr:IsShown() then L:RefreshPicker() end
	end)
	p:Hide()
	self.picker = p
	return p
end
function RL:ClosePicker()
	local p = self.picker
	if p and p:IsShown() then p:Hide() end
	if self.host and self.host.shade then self.host.shade:Hide() end
	self.pick = nil
end
-- index: the rule whose values to change; nil with k: a new rule of that kind.
function RL:OpenPicker(index, k)
	local d = self.draft
	if not d then return end
	local row = index and d.rows[index]
	if index and not (row and row.v and PICKED[row.k]) then return end
	k = row and row.k or k
	if not (PICKED[k] and self:Def(k)) then return end
	local p = self:Picker()
	local pick = { index = index, row = row, k = k, n = row and row.n or nil, v = copy(row and row.v), open = {} }
	-- a type with something ticked starts open
	if k == "type" then
		for _, v in ipairs(pick.v) do local class = tonumber(tostring(v):match("^(%d+):")); if class then pick.open[class] = true end end
	end
	self.pick = pick
	p.title:SetText(index and "Change a Rule" or "Add a Rule")
	p.ok.label:SetText(index and "Done" or "Add Rule")
	p.head:SetText(ns.Rules.KEYS[k].label); p.hint:SetText(PICK_HINT[k] or "")
	p.ask:SetText(PICK_ASK[k] or "")
	p.note:SetShown(k == "type")
	p.scroll:SetVerticalScroll(0)
	if ns.Classic then ns.Classic:RefreshTitle(p) end
	self.host.shade:Show()
	p:ClearAllPoints(); p:SetPoint("CENTER", self.host, "CENTER", 0, 0)
	p:Show()
	self:RefreshPicker()
	return p
end
-- The rows to show: for Type, a title for each kind of item (click to open it), then "Any kind of ..." and its kinds;
-- a type with one kind or none is a single line. For Slot and Section, one line each.
function RL:PickerList()
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
		for _, o in ipairs(self:Options(pick.k)) do
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
local function pickerRow(L, p, i)
	local r = p.rows[i]
	if r then return r end
	r = CreateFrame("Button", nil, p.child); r:SetSize(PW - PAD * 2 - 22, PROW)
	r.arrow = r:CreateTexture(nil, "ARTWORK"); r.arrow:SetSize(12, 12); r.arrow:SetPoint("LEFT", 4, 0)
	r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate"); r.check:SetSize(22, 22)
	r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.label:SetJustifyH("LEFT"); r.label:SetWordWrap(false)
	r.count = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.count:SetPoint("RIGHT", -6, 0)
	r:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
	local hl = r:GetHighlightTexture(); if hl and hl.SetVertexColor then hl:SetVertexColor(1, 1, 1, 0.06) end
	r:SetScript("OnClick", function(self) L:PickerClick(self.entry) end)
	r.check:SetScript("OnClick", function(self) L:PickerClick(self:GetParent().entry) end)
	p.rows[i] = r
	return r
end
function RL:PickerClick(entry)
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
function RL:RefreshPicker()
	local p, pick = self.picker, self.pick
	if not (p and pick and p:IsShown()) then return end
	local s, R = Skins:Current(), ns.Rules
	local list = self:PickerList()
	p.list = list
	for i, entry in ipairs(list) do
		local r = pickerRow(self, p, i)
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
function RL:PickerDone()
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
	self:Changed()
	if not pick.index then self:Added() end
end
