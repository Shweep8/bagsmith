local _, ns = ...

-- Icon corners (1.5.0). Each corner of an item icon (Icons view, bag windows, the bank, copies, other characters'
-- bags) has a priority list of widgets, BagSmith's own and other addons'. Per item, the first widget in the list
-- that has something to show is drawn there; the rest wait. Players order the lists under Item Icons > Icon Corners.
--
-- Other addons register through BagSmith.API (1.1). The contract follows the shape many Forever addons already
-- use for Baganator's corner widgets, so supporting BagSmith is a few lines; it's BagSmith's own implementation.
--   RegisterCornerWidget(label, id, onUpdate, onInit, defaultPosition, isFast) -> true, or false if refused
--     onInit(itemButton) -> frame or region: called once per item button, outside combat; BagSmith places it.
--       Optional fields on it: padding (a multiplier for the 2 px inset), sizeFont (accepted; widgets scale with
--       the icon either way).
--     onUpdate(widget, details) -> true (show), false (nothing here, try the next), nil (not ready, ask again)
--     defaultPosition: { corner = "top_left" | "top_right" | "bottom_left" | "bottom_right", priority = n }
--     isFast: true skips the per-frame time budget.
--   IsCornerWidgetActive(id), GetCurrentCornerForWidget(id), RequestItemButtonsRefresh()
-- Each accepts a dot or a colon call.

local C = {}
ns.Corners = C

C.CORNERS = { "top_left", "top_right", "bottom_left", "bottom_right" }
C.LABEL = { top_left = "Top Left", top_right = "Top Right", bottom_left = "Bottom Left", bottom_right = "Bottom Right" }
local POINT = { top_left = "TOPLEFT", top_right = "TOPRIGHT", bottom_left = "BOTTOMLEFT", bottom_right = "BOTTOMRIGHT" }
local SIGN = { top_left = { 1, -1 }, top_right = { -1, -1 }, bottom_left = { 1, 1 }, bottom_right = { -1, 1 } }
C.DEFAULTS = { top_left = { "quest_start", "junk" }, top_right = { "item_level" }, bottom_left = { "pawn", "equipment_set" }, bottom_right = { "quantity" } }
C.MAX_ERRORS = 5          -- a widget that keeps failing is switched off until reload
C.BUDGET_MS = 4           -- per frame, for widgets that aren't marked fast
C.RETRY_LIMIT = 600       -- frames a "not ready yet" item keeps being asked again
C.SCALE_MIN, C.SCALE_MAX = 0.7, 1.3

C.widgets, C.order = {}, {}

------------------------------------------------------------------------
-- BagSmith's own marks, as built-in widgets. Their art and size are drawn by their own code (Junk, Pawn, the
-- gear-set shield, the item level, the count), exactly as before; the corner decides where and whether.
------------------------------------------------------------------------
-- (1.5.0-beta3) List rows follow the corners too. A mark that has its own List column steps aside on a row's icon
-- (the next mark in the corner takes its place): Item Level always; Stack Count while the Qty column shows (BagSmith
-- already puts the count on the row icon when it doesn't).
local function builtin(id, label, region, test, inset, extra, insetRow)
	C.widgets[id] = { label = label, builtin = true, region = region, test = test, inset = inset, extra = extra, insetRow = insetRow }
	C.order[#C.order + 1] = id
end
-- (1.5.0-beta6) BagSmith's marks sit flush in their corner (they were 1 px in, plus the art's own empty margin,
-- which read as pushed toward the middle); other addons' marks keep the usual 2 px.
builtin("junk", "Junk Coin", function(b) return b.junkCoin end,
	function(b, rec) return ns.Junk and ns.Junk:IsJunk(rec) and true or false end, { 0, 0 })
-- (1.5.0-beta6) the item level sits flush in its corner, like the stack count: a number's own text box already
-- leaves a small gap around the digits (it was 2 px in and 1 px down, which read as pushed toward the middle)
builtin("item_level", "Item Level", function(b) return b.ilvlText end,
	function(b, rec) return ns.Buttons:ItemLevelShows(b, rec) end, { 0, 0 })
builtin("pawn", "Pawn Upgrade Arrow", function(b) return b.pawnArrow end,
	function(b) return b.pawnUp and true or false end, { 0, 0 })
builtin("equipment_set", "Gear Set Shield", function(b) return b.linkMark end,
	function(b) return b.linkOn and true or false end, { 0, 0 }, function(b) return b.linkCount end)
builtin("quantity", "Stack Count", function(b) return b.Count end,
	function(b, rec) return (rec.count or 0) > 1 and (b.mode ~= "row" or b.countOnIcon) and true or false end, { 0, 0 }, nil, { -2, -1 })
-- (1.6.0) Quest Starter (a player's request): the game's yellow "available quest" mark on an item that begins a quest you
-- haven't accepted (Scanner: rec.questStart). BagSmith hides the item template's own quest overlay (Buttons.lua), so
-- this is its replacement. Locked like the stack count; top left by default, ahead of the junk coin (quest items can't be
-- marked as junk, so the two never compete).
local QUEST_ART = "Interface\\GossipFrame\\AvailableQuestIcon"
-- (1.6.0-beta9, Shweep: "very little but some contrast") a slight drop shadow, like the item level's text shadow: the
-- same art in black, 1 px down and right, just under the mark. It's anchored to the mark by two corners, so it follows
-- the mark's size and corner; it shows and hides with it as the mark's extra region (Apply, the preview, hide).
C.QUEST_SHADE = { alpha = 0.8, x = 1, y = -1 }
local function questMark(b)
	if not b.questMark and b.CreateTexture then
		local t = b:CreateTexture(nil, "OVERLAY", nil, 6)
		t:SetTexture(QUEST_ART); t:Hide()
		local w = (b.icon and b.icon.GetWidth and b.icon:GetWidth()) or 0
		if w <= 0 then w = 32 end
		local px = math.max(8, math.floor(w * 0.45)); t:SetSize(px, px)
		b.questMark = t
		local sh = b:CreateTexture(nil, "OVERLAY", nil, 5)
		sh:SetTexture(QUEST_ART); sh:Hide()
		local q = C.QUEST_SHADE
		if sh.SetVertexColor then sh:SetVertexColor(0, 0, 0, q.alpha) end
		sh:SetPoint("TOPLEFT", t, "TOPLEFT", q.x, q.y)
		sh:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", q.x, q.y)
		b.questShade = sh
	end
	return b.questMark
end
local function questShade(b) questMark(b); return b.questShade end
C.QUEST_ART = QUEST_ART
builtin("quest_start", "Quest Starter", questMark, function(b, rec) return rec and rec.questStart and true or false end, { 0, 0 }, questShade)
C.COLUMN_NOTE = { item_level = "In List view the item level shows in its column, so the next mark in this corner takes its place.",
	quantity = "In List view the stack count shows in the Qty column, so the next mark in this corner takes its place (if you hide that column, it shows here instead)." }

-- Why a built-in shows nothing, for the Corners settings (nil when it can show).
function C:BuiltinNote(id)
	local db = ns.db or {}
	if id == "item_level" and not db.iconItemLevel then return "Off: turn on Item Level (ilvl) under Marks above" end
	if id == "pawn" and not (ns.Pawn and ns.Pawn.Present and ns.Pawn:Present()) then return "Shows when Pawn is installed" end
	if id == "equipment_set" and db.gearSetSections == false then return "Off: turn on Show Gear Sets as Sections" end
	return nil
end

------------------------------------------------------------------------
-- Settings: per profile, { corner = { id, ... } }; which corners the player has arranged; which widgets were
-- already placed once (a widget the player removes stays removed).
------------------------------------------------------------------------
local function lists() return ns.db and ns.db.iconCorners end
function C:CornerOf(id)
	local l = lists()
	if not l then return nil end
	for _, corner in ipairs(C.CORNERS) do
		for i, v in ipairs(l[corner] or {}) do if v == id then return corner, i end end
	end
	return nil
end
function C:Touch(corner) if ns.db and C.LABEL[corner] then ns.db.iconCornersTouched[corner] = true end end
-- (1.5.0-beta4) The stack count is protected: when an item has a stack its count always shows, first in its corner
-- (nothing ranks above it), and it can be moved but not hidden. (1.6.0) The Quest Starter mark is locked the same way.
-- Locked marks are always in some corner (back in their home corner if a save lacks one), ahead of every other mark
-- there, in this order if they share one. C.PROTECTED stays the stack count, for anything that reads it.
C.PROTECTED = "quantity"
C.LOCKED = { "quest_start", "quantity" }
local LOCKED_SET, LOCKED_HOME = { quest_start = true, quantity = true }, { quest_start = "top_left", quantity = "bottom_right" }
function C:IsLocked(id) return id ~= nil and LOCKED_SET[id] == true end
function C:Normalize()
	local l = lists()
	if not l then return end
	for _, id in ipairs(C.LOCKED) do
		if not C:CornerOf(id) then local home = LOCKED_HOME[id]; l[home] = l[home] or {}; table.insert(l[home], 1, id) end
	end
	for _, corner in ipairs(C.CORNERS) do
		local list = l[corner]
		if list and #list > 1 then
			local front, rest = {}, {}
			for _, id in ipairs(C.LOCKED) do if ns.IndexOf(list, id) then front[#front + 1] = id end end
			for _, v in ipairs(list) do if not LOCKED_SET[v] then rest[#rest + 1] = v end end
			local i = 0
			for _, v in ipairs(front) do i = i + 1; list[i] = v end
			for _, v in ipairs(rest) do i = i + 1; list[i] = v end
		end
	end
end

-- A newly registered widget's first placement: at the position it asks for, unless the player has arranged
-- that corner, in which case at its end; once per widget per profile.
function C:AutoInsert(id)
	local w, db = C.widgets[id], ns.db
	if not (w and not w.builtin and db) then return end
	if db.iconCornersInserted[id] then return end
	local dp = w.defaultPosition
	if not dp then return end
	db.iconCornersInserted[id] = true
	if C:CornerOf(id) then return end
	local list = db.iconCorners[dp.corner]
	if db.iconCornersTouched[dp.corner] or dp.priority > #list then
		list[#list + 1] = id
	else
		table.insert(list, math.max(1, dp.priority), id)
	end
	C:Normalize()
end
function C:InsertAll() for _, id in ipairs(C.order) do C:AutoInsert(id) end end

-- Settings actions (the Corners page): each marks the corner as arranged.
function C:Move(id, delta)
	local corner, i = C:CornerOf(id)
	if not corner then return end
	local list = ns.db.iconCorners[corner]
	local j = i + delta
	if j < 1 or j > #list then return end
	if C:IsLocked(id) or C:IsLocked(list[j]) then return end   -- nothing moves past a locked mark
	C:Seen(id)
	list[i], list[j] = list[j], list[i]
	C:Touch(corner); C:Changed()
end
function C:Remove(id)
	if C:IsLocked(id) then return end   -- a locked mark can be moved, not hidden
	local corner, i = C:CornerOf(id)
	if not corner then return end
	C:Seen(id)
	table.remove(ns.db.iconCorners[corner], i)
	C:Touch(corner); C:Changed()
end
-- Put a widget at the end of a corner (from Not Shown, or from another corner).
function C:Place(id, corner)
	if not (C.widgets[id] or ns.db) or not C.LABEL[corner] then return end
	local from, i = C:CornerOf(id)
	if from then table.remove(ns.db.iconCorners[from], i); C:Touch(from) end
	local list = ns.db.iconCorners[corner]
	list[#list + 1] = id
	C:Normalize()
	C:Touch(corner); C:Changed()
end
-- (1.5.0-beta8) For the drag-and-drop editor: put a mark in a corner just before another mark (or at the end).
function C:PlaceAt(id, corner, beforeId)
	if not ns.db or not C.LABEL[corner] or id == beforeId then return end
	local from, i = C:CornerOf(id)
	if from then table.remove(ns.db.iconCorners[from], i); C:Touch(from) end
	local list = ns.db.iconCorners[corner]
	local at = #list + 1
	if beforeId then for k, v in ipairs(list) do if v == beforeId then at = k; break end end end
	table.insert(list, at, id)
	C:Normalize()
	C:Seen(id); C:Touch(corner); C:Changed()
end
-- (1.5.0-beta10) For the dropdowns: put a mark in a corner's slot (1 = the one that shows, 2 on = backups). It
-- replaces what was there (which is then not shown), and leaves wherever it was before. The stack count goes in
-- ahead of whatever is in the slot instead of replacing it (it's always first, and the mark it would displace
-- becomes the first backup). nil empties the slot (the stack count can't be removed).
function C:SetSlot(corner, index, id)
	if not ns.db or not C.LABEL[corner] then return end
	local list = ns.db.iconCorners[corner]
	local cur = list[index]
	if id == cur then return end
	-- (1.5.0-beta11, audit F2) nothing in a corner's first slot means the corner shows nothing, backups included
	if id == nil and index == 1 then return C:ClearCorner(corner) end
	if id == nil then
		if cur and not C:IsLocked(cur) then table.remove(list, index); C:Seen(cur) end
	else
		local from, j = C:CornerOf(id)
		if from then table.remove(ns.db.iconCorners[from], j); C:Touch(from) end
		list = ns.db.iconCorners[corner]
		cur = list[index]
		if C:IsLocked(id) or cur == nil or C:IsLocked(cur) then
			table.insert(list, math.min(index + (C:IsLocked(cur) and 1 or 0), #list + 1), id)
		else
			list[index] = id; C:Seen(cur)
		end
		C:Seen(id)
	end
	C:Normalize()
	C:Touch(corner); C:Changed()
end
-- (1.5.0-beta11, audit F2) None on a corner's first dropdown: the corner shows nothing, backups included. The stack
-- count is protected, so a corner holding it keeps it (its dropdown is locked and offers no None).
function C:ClearCorner(corner)
	if not ns.db or not C.LABEL[corner] then return end
	local list = ns.db.iconCorners[corner]
	local keep = {}
	for _, id in ipairs(list) do
		if C:IsLocked(id) then keep[#keep + 1] = id else C:Seen(id) end
	end
	ns.db.iconCorners[corner] = keep
	C:Normalize()
	C:Touch(corner); C:Changed()
end
-- A mark from another addon is "new" until the player does something with it in Icon Corners (per profile).
function C:Seen(id) if ns.db and ns.db.iconCornersSeen then ns.db.iconCornersSeen[id] = true end end
function C:IsNew(id)
	local w = C.widgets[id]
	return w and not w.builtin and ns.db and ns.db.iconCornersSeen and not ns.db.iconCornersSeen[id] or false
end
-- The next corner clockwise: Top Left, Top Right, Bottom Right, Bottom Left.
local CLOCKWISE = { top_left = "top_right", top_right = "bottom_right", bottom_right = "bottom_left", bottom_left = "top_left" }
function C:NextCorner(id)
	local corner = C:CornerOf(id)
	C:Place(id, corner and CLOCKWISE[corner] or C:HomeCorner(id))
end
function C:HomeCorner(id)
	local w = C.widgets[id]
	if w and w.defaultPosition then return w.defaultPosition.corner end
	for corner, ids in pairs(C.DEFAULTS) do for _, v in ipairs(ids) do if v == id then return corner end end end
	return "top_right"
end
function C:Reset()
	if not ns.db then return end
	ns.db.iconCorners = ns.Copy(C.DEFAULTS)
	ns.db.iconCornersTouched = {}
	-- widgets from other addons go back to where they asked to be
	ns.db.iconCornersInserted = {}
	C:InsertAll()
	C:Normalize()
	C:Changed()
end
function C:Changed()
	if ns.Fire then ns:Fire("SETTINGS_CHANGED", "iconCorners") end
	C:RequestRefresh()
end

------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------
local refreshQueued = false
function C:RequestRefresh()
	if refreshQueued then return end
	refreshQueued = true
	local function run() refreshQueued = false; if ns.RefreshViews and ns.db then ns:RefreshViews(true) end end
	if C_Timer and C_Timer.After then C_Timer.After(0, run) else run() end
end

local clock = debugprofilestop
local spent, resetQueued = 0, false
local function charge(ms)
	spent = spent + ms
	if not resetQueued and C_Timer and C_Timer.After then
		resetQueued = true
		C_Timer.After(0, function() spent, resetQueued = 0, false end)
	end
end

-- The details a widget reads, from BagSmith's own record of the item (the field names widgets already use).
function C:Details(b, rec)
	if b.cornerDetails and b.cornerDetailsFor == b.cornerFill then return b.cornerDetails end
	local d = {
		itemLink = rec.link, itemID = rec.itemID, quality = rec.quality, itemLevel = rec.ilvl,
		isBound = rec.isBound and true or false, itemCount = rec.count or 1, icon = rec.icon,
		isJunk = (ns.Junk and ns.Junk:IsJunk(rec)) and true or false,
		-- (1.5.0-beta11, audit F1) BagSmith's records spell it subclassID; the public field is subClassID
		classID = rec.classID, subClassID = rec.subclassID or rec.subClassID, itemName = rec.name,
	}
	if not rec.cached and rec.bag and rec.slot then
		d.bagID, d.slotID = rec.bag, rec.slot
		if ItemLocation and ItemLocation.CreateFromBagAndSlot then
			local ok, loc = pcall(ItemLocation.CreateFromBagAndSlot, ItemLocation, rec.bag, rec.slot)
			if ok then d.itemLocation = loc end
		end
	end
	d.tooltipGetter = function()
		if not C_TooltipInfo then return nil end
		if d.bagID and C_TooltipInfo.GetBagItem then return C_TooltipInfo.GetBagItem(d.bagID, d.slotID) end
		if rec.link and C_TooltipInfo.GetHyperlink then return C_TooltipInfo.GetHyperlink(rec.link) end
	end
	-- tooltip data is built only if a widget reads it
	setmetatable(d, { __index = function(t, k)
		if k == "tooltipInfo" then
			local ok, info = pcall(t.tooltipGetter)
			info = ok and info or nil
			-- (1.5.0-beta11, audit F3) only real data is kept: while the game's tooltip data isn't ready, the next ask
			-- (a retry, or after the item's data arrives) tries again instead of remembering "unavailable"
			if ok and info then rawset(t, "tooltipInfo", info) end
			return info
		end
	end })
	b.cornerDetails, b.cornerDetailsFor = d, b.cornerFill
	return d
end

local function iconPx(b)
	if ns.Buttons and ns.Buttons.IconPx then return ns.Buttons:IconPx(b) end
	return (b.GetWidth and b:GetWidth() or 37) - 4
end
C.SCALE_MIN_ROW = 0.4
function C:Scale(b, mode, px)
	local ref = ((ns.DEFAULTS and ns.DEFAULTS.iconSize) or 37) - 4
	local s = (px or iconPx(b)) / math.max(1, ref)
	return math.max((mode or b.mode) == "row" and C.SCALE_MIN_ROW or C.SCALE_MIN, math.min(C.SCALE_MAX, s))
end

-- The widget a button shows for an id: a built-in's own region, or another addon's, made the first time
-- (outside combat; a widget that would be made in combat waits for combat to end).
-- (1.5.0-beta4) In List view a BagSmith item button is the whole row, so an addon that sizes its mark from the slot
-- or rings the slot would span the row. Other addons' marks show on List rows only if the addon opts in
-- (RegisterCornerWidget's options.listRows); they then get an icon-sized slot of their own: a frame over the row's
-- icon, with .itemButton (the row) and GetBagID / GetID forwarded to it.
function C:RowSlot(b)
	local f = b.cornerRowSlot
	if not f then
		f = CreateFrame("Frame", nil, b)
		if f.EnableMouse then f:EnableMouse(false) end
		f.itemButton, f.bagsmithRowSlot = b, true
		f.GetBagID = function() return (b.GetBagID and b:GetBagID()) or b.bag end
		f.GetID = function() return b:GetID() end
		b.cornerRowSlot = f
	end
	local px = iconPx(b)
	f:ClearAllPoints(); f:SetPoint("CENTER", b.icon or b, "CENTER", 0, 0); f:SetSize(px, px)
	return f
end
function C:WidgetOn(b, id, w, mode)
	if w.builtin then return w.region(b) end
	local row = mode == "row"
	if row and not w.rows then return nil end
	local key = row and "cornerWidgetsRow" or "cornerWidgets"
	b[key] = b[key] or {}
	local got = b[key][id]
	if got == nil then
		if InCombatLockdown and InCombatLockdown() then C.pendingInit = true; return nil end
		if not b.cornerHolder then
			b.cornerHolder = CreateFrame("Frame", nil, b)
			b.cornerHolder:SetAllPoints(b)
			if b.cornerHolder.SetFrameLevel and b.GetFrameLevel then b.cornerHolder:SetFrameLevel((b:GetFrameLevel() or 0) + 4) end
		end
		local ok, made = pcall(w.onInit, row and C:RowSlot(b) or b)
		if not ok or type(made) ~= "table" then
			if not ok then C:Failed(id, w, made) end
			b[key][id] = false
			return nil
		end
		if made.SetParent then made:SetParent(b.cornerHolder) end
		if made.Hide then made:Hide() end
		-- (audit F1) the size it was made at, for an opted-in texture's resizing
		if made.GetWidth and not made.bsBaseW then made.bsBaseW, made.bsBaseH = made:GetWidth(), made.GetHeight and made:GetHeight() or made:GetWidth() end
		b[key][id] = made
		got = made
	end
	return got or nil
end

function C:Failed(id, w, err)
	w.errors = (w.errors or 0) + 1
	if ns.Debug then ns:Debug("Icon corner %s failed: %s", id, tostring(err)) end
	if w.errors >= C.MAX_ERRORS and not w.broken then
		w.broken = true
		ns:Print("The icon corner \"%s\" from another addon kept failing, so it's off until you reload.", w.label)
	end
end

-- Ask one widget. true / false / nil (not ready, or no time left this frame).
-- (1.5.0-beta5, audit F2) Another addon's answer is kept for the button's current fill (a fresh fill, a refresh
-- request or a settings change starts over), so a retry asks only the widgets still pending: a slow widget that
-- answered can't use up every frame's budget again and keep later corners from ever being asked.
function C:Ask(b, rec, id, w, widget)
	if w.builtin then return w.test(b, rec) and true or false end
	local answers = b.cornerAnswers
	if answers and answers.fill == b.cornerFill and answers[id] ~= nil then return answers[id] end
	if not w.isFast and spent >= C.BUDGET_MS then return nil end
	local t0 = clock and clock()
	local ok, res = pcall(w.onUpdate, widget, C:Details(b, rec))
	if t0 and not w.isFast then charge(clock() - t0) end
	if not ok then C:Failed(id, w, res); return false end
	if res == nil then return nil end
	res = res and true or false
	if not answers or answers.fill ~= b.cornerFill then answers = { fill = b.cornerFill }; b.cornerAnswers = answers end
	answers[id] = res
	return res
end

-- BagSmith's picture marks never grow past their quarter of the icon (1.5.0-beta4).
local CAPPED = { junk = true, pawn = true, equipment_set = true, quest_start = true }
local function place(b, id, w, widget, corner, mode, px)
	mode = mode or b.mode
	local sx, sy = SIGN[corner][1], SIGN[corner][2]
	widget:ClearAllPoints()
	if w.builtin and CAPPED[id] and widget.SetSize and widget.GetWidth then
		local icon = px or iconPx(b)
		-- (1.7.0-beta1, Shweep: smaller in Recent than anywhere else) the Quest Starter mark is sized here, at every
		-- placement, from the icon it sits on, as the preview sizes it. It used to keep the size it was made at (the icon's
		-- width at that moment) and the cap below only ever shrank it, so a copy made while its icon was small stayed small.
		if id == "quest_start" then local s = math.max(10, math.floor(icon * 0.45 + 0.5)); widget:SetSize(s, s) end
		local cap = math.floor(icon / 2)   -- half the icon: inside its quarter
		if cap > 0 and (widget:GetWidth() or 0) > cap then widget:SetSize(cap, cap) end
	end
	if w.builtin then
		local inset = (mode == "row" and w.insetRow) or w.inset
		widget:SetPoint(POINT[corner], b.icon or b, POINT[corner], inset[1] == 0 and 0 or sx * inset[1], inset[2] == 0 and 0 or sy * inset[2])
	else
		-- (1.5.0-beta4) another addon's widget keeps its own size, as in other bag addons: many size themselves from
		-- the slot and their own settings. It's scaled with the icon only if it asks (sizeFont or bagsmithScale).
		-- (1.5.0-beta5, audit F1) an opted-in widget always gets its scale set, 1 included, so a reused widget
		-- never keeps a previous size; a texture is resized from the size it was made at (recorded at creation,
		-- before BagSmith ever resized it). A widget that didn't opt in is never touched.
		local s = 1
		if widget.sizeFont or widget.bagsmithScale then
			s = C:Scale(b, mode, px)
			if widget.SetScale then
				widget:SetScale(s)
			elseif widget.SetSize and widget.bsBaseW and widget.bsBaseW > 0 then
				widget:SetSize(widget.bsBaseW * s, widget.bsBaseH * s)
				s = 1   -- (the inset below is then in plain pixels)
			else
				s = 1
			end
		end
		local pad = tonumber(widget.padding) or 1
		widget:SetPoint(POINT[corner], b.icon or b, POINT[corner], sx * 2 * pad / s, sy * 2 * pad / s)
	end
end

local function hide(b, w, widget)
	if widget and widget.Hide then widget:Hide() end
	if w.extra then local x = w.extra(b); if x and x.Hide then x:Hide() end end
end

-- Decide and draw every corner of one button. fresh: a new fill (a new item or a refresh).
function C:Apply(b, fresh)
	if fresh then b.cornerFill = (b.cornerFill or 0) + 1 end
	local rec = b.rec
	if b.bsPreview then return end   -- the settings preview draws itself (C:DrawPreview)
	local live = (b.mode == "cell" or b.mode == "row") and rec and not rec.empty and b.hasItem and ns.db and ns.db.iconCorners
	if b.cornerHolder then b.cornerHolder:SetShown(live and true or false) end
	if not live then
		-- (1.6.0-beta10, the beta9 audit's B9 R1) nothing in the slot (an empty slot shown, or a slot blanked in combat): the
		-- Quest Starter mark and its shadow go too. BagSmith's other marks are hidden by their own code (Buttons:Blank); this
		-- one only has the corners'. Only what exists is hidden: nothing is made here.
		if b.questMark then b.questMark:Hide() end
		if b.questShade then b.questShade:Hide() end
		return
	end
	-- the other view's instances of other addons' widgets stay hidden
	for _, wd in pairs((b.mode == "row" and b.cornerWidgets or b.cornerWidgetsRow) or {}) do if wd and wd.Hide then wd:Hide() end end
	if b.mode == "row" and b.cornerRowSlot then C:RowSlot(b) end
	local placed, retry = {}, false
	for _, corner in ipairs(C.CORNERS) do
		local winner
		for _, id in ipairs(ns.db.iconCorners[corner] or {}) do
			local w = C.widgets[id]
			placed[id] = true
			if w and not w.broken then
				local widget = C:WidgetOn(b, id, w, b.mode)
				if widget then
					local show = false
					if not winner then
						show = C:Ask(b, rec, id, w, widget)
						if show == nil then retry = true; show = false end
					end
					if show then
						winner = id
						place(b, id, w, widget, corner)
						widget:Show()
						if w.extra then local x = w.extra(b); if x then x:Show() end end
					else
						hide(b, w, widget)
					end
				end
			elseif w and w.broken then
				hide(b, w, C:WidgetOn(b, id, w, b.mode))
			end
		end
	end
	-- anything in no corner (removed by the player, or not loaded) shows nothing
	for id, w in pairs(C.widgets) do
		if not placed[id] then
			if w.builtin then hide(b, w, w.region(b))
			else
				for _, key in ipairs({ "cornerWidgets", "cornerWidgetsRow" }) do if b[key] and b[key][id] then hide(b, w, b[key][id]) end end
			end
		end
	end
	b.cornerWaiting = retry
	if retry and not C.inRetry then C:Queue(b) end
end

-- "Not ready yet": the button is asked again on later frames while it still shows the same fill.
C.retries = {}
local driver
function C:Queue(b)
	local entry = C.retries[b]
	if entry and entry.fill == b.cornerFill then return end
	C.retries[b] = { fill = b.cornerFill, tries = 0 }
	if not driver and CreateFrame then
		driver = CreateFrame("Frame")
	end
	if driver and not driver.running then
		driver.running = true
		driver:SetScript("OnUpdate", function() C:RunRetries() end)
	end
end
function C:RunRetries()
	local list = C.retries
	C.retries = {}
	C.inRetry = true
	for b, entry in pairs(list) do
		if b.cornerFill == entry.fill and b:IsShown() and entry.tries < C.RETRY_LIMIT then
			C:Apply(b)
			if b.cornerWaiting then entry.tries = entry.tries + 1; C.retries[b] = entry end
		end
	end
	C.inRetry = false
	if not next(C.retries) and driver then driver:SetScript("OnUpdate", nil); driver.running = false end
end

------------------------------------------------------------------------
-- The settings' live preview (1.5.0-beta3): a display-only item button showing, in each corner, the first mark
-- that can show for this player, as if every mark applied to the sample item. BagSmith's marks are drawn with their
-- own art at their own sizes; another addon's mark shows as a small neutral tag (its code isn't run on a pretend
-- item). mode: "cell" (Icons view) or "row" (List view: Item Level steps aside, Stack Count unless the Qty column
-- is hidden).
------------------------------------------------------------------------
C.SAMPLE = { itemID = 0, name = "Sample Item", icon = "Interface\\Icons\\INV_Chest_Cloth_17", quality = 2, count = 20, ilvl = 24,
	classID = 4, subclassID = 1, cached = true, display = true }
function C:RowCountOnIcon()
	local cols = ns.db and ns.db.cols
	return not (type(cols) == "table" and ns.IndexOf(cols, "c"))
end
function C:PreviewWinner(corner, mode)
	local ids = ns.db and ns.db.iconCorners and ns.db.iconCorners[corner] or {}
	for _, id in ipairs(ids) do
		local w = C.widgets[id]
		if w and not w.broken then
			if not w.builtin then
				if mode ~= "row" or w.rows then return id end
			else
			local can = C:BuiltinNote(id) == nil
			if mode == "row" and (id == "item_level" or (id == "quantity" and not C:RowCountOnIcon())) then can = false end
			if can then return id end
			end
		end
	end
	return nil
end
local function markSize(px, factor) return math.max(10, math.floor(px * factor + 0.5)) end
C.PREVIEW_ENSURE = {
	junk = function(b, mode, px) local t = b.junkCoin; if t then t:SetSize(markSize(px, 0.45), markSize(px, 0.45)) end; return t end,
	quest_start = function(b, mode, px) local t = questMark(b); if t then t:SetSize(markSize(px, 0.45), markSize(px, 0.45)) end; return t end,
	item_level = function(b, mode, px)
		local was = b.mode; b.mode = "cell"
		local db = ns.db; local on = db.iconItemLevel; db.iconItemLevel = true
		ns.Buttons:ItemLevel(b, C.SAMPLE)
		db.iconItemLevel = on; b.mode = was
		return b.ilvlText
	end,
	pawn = function(b, mode, px)
		if not b.pawnArrow then
			b.pawnArrow = b:CreateTexture(nil, "OVERLAY", nil, 6)
			if ns.Pawn and ns.Pawn.SetArt then ns.Pawn:SetArt(b.pawnArrow) end
		end
		b.pawnArrow:SetSize(markSize(px, 0.45), markSize(px, 0.45))
		return b.pawnArrow
	end,
	equipment_set = function(b, mode, px)
		if not b.linkMark then
			b.linkMark = b:CreateTexture(nil, "OVERLAY", nil, 3)
			b.linkMark:SetTexture(ns.Buttons.MARK_ART)
			b.linkCount = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
			if b.linkCount.SetJustifyH then b.linkCount:SetJustifyH("LEFT") end
		end
		ns.Buttons:StyleShield(b, 2, px)
		return b.linkMark
	end,
	quantity = function(b) if b.Count then b.Count:SetText("20") end; return b.Count end,
}
-- The neutral tag for another addon's mark: a small square in the accent color.
local function previewTag(b)
	local t = b:CreateTexture(nil, "OVERLAY", nil, 7)
	t:SetSize(8, 8)
	t:SetColorTexture(0.98, 0.78, 0.46, 0.95)
	return t
end
function C:DrawPreview(b, mode, px)
	b.bsPreview = true
	px = px or iconPx(b)
	b.previewTags = b.previewTags or {}
	for _, w in pairs(C.widgets) do if w.builtin then hide(b, w, w.region(b)) end end
	for _, t in pairs(b.previewTags) do t:Hide() end
	if b.newDot then b.newDot:Hide() end
	b.previewShown = {}
	for _, corner in ipairs(C.CORNERS) do
		local id = C:PreviewWinner(corner, mode)
		b.previewShown[corner] = id
		if id then
			local w = C.widgets[id]
			if w.builtin then
				local region = C.PREVIEW_ENSURE[id](b, mode, px)
				if region then
					place(b, id, w, region, corner, mode, px)
					region:Show()
					if w.extra then local x = w.extra(b); if x then x:Show() end end
				end
			else
				local tag = b.previewTags[corner]
				if not tag then tag = previewTag(b); b.previewTags[corner] = tag end
				place(b, id, w, tag, corner, mode, px)
				tag:Show()
			end
		end
	end
end

-- /bs corners (1.5.0-beta4): every mark BagSmith knows, where it is, and anything wrong with it; for players and authors.
function C:Report()
	ns:Print("Icon corners:")
	for _, id in ipairs(C.order) do
		local w = C.widgets[id]
		local corner, i = C:CornerOf(id)
		local where = corner and ("%s, %d of %d"):format(C.LABEL[corner], i, #ns.db.iconCorners[corner]) or "hidden"
		local bits = {}
		if not w.builtin then
			bits[#bits + 1] = w.rows and "List rows too" or "Icons view only"
			if w.isFast then bits[#bits + 1] = "fast" end
			if w.broken then bits[#bits + 1] = "switched off after errors" elseif (w.errors or 0) > 0 then bits[#bits + 1] = ("%d errors"):format(w.errors) end
		end
		ns:Print("  %s (%s): %s%s", w.label, id, where, #bits > 0 and (" [" .. table.concat(bits, ", ") .. "]") or "")
	end
	for _, corner in ipairs(C.CORNERS) do
		for _, id in ipairs(ns.db.iconCorners[corner] or {}) do
			if not C.widgets[id] then ns:Print("  %s: %s, not loaded", id, C.LABEL[corner]) end
		end
	end
end

------------------------------------------------------------------------
-- The public API (BagSmith.API 1.1)
------------------------------------------------------------------------
local API = _G.BagSmith and _G.BagSmith.API
local function args(first, ...) if first == API then return ... end return first, ... end

-- (1.6.0) A refused registration says why in chat, once per mark per session (it was only in debug), so an addon's
-- author doesn't have to guess.
local refusedSaid = {}
local function refuse(id, why)
	local key = tostring(id) .. "|" .. why
	if ns.Debug then ns:Debug("RegisterCornerWidget refused: %s", why) end
	if not refusedSaid[key] and ns.Print then
		refusedSaid[key] = true
		ns:Print("An addon's icon mark (%s) couldn't be added to Icon Corners: %s.", type(id) == "string" and id ~= "" and id or "no id", why)
	end
	return false
end
function C:Register(label, id, onUpdate, onInit, defaultPosition, isFast, options)
	if type(label) ~= "string" or label == "" or type(id) ~= "string" or id == "" or #id > 64 or not id:match("^[%w_%-%.:]+$")
		or type(onUpdate) ~= "function" or type(onInit) ~= "function" then
		return refuse(id, "it needs a label, an id (letters, digits, _ - . :), onUpdate and onInit")
	end
	if C.widgets[id] then
		return refuse(id, ("%q is already registered"):format(id))
	end
	local dp
	if type(defaultPosition) == "table" and C.LABEL[defaultPosition.corner] then
		dp = { corner = defaultPosition.corner, priority = math.max(1, math.floor(tonumber(defaultPosition.priority) or 1)) }
	end
	C.widgets[id] = { label = label, onUpdate = onUpdate, onInit = onInit, isFast = isFast and true or false, defaultPosition = dp,
		rows = type(options) == "table" and options.listRows == true }
	C.order[#C.order + 1] = id
	if ns.db and ns.db.iconCorners then C:AutoInsert(id); C:RequestRefresh() end
	return true
end

if API then
	API.RegisterCornerWidget = function(...) return C:Register(args(...)) end
	API.IsCornerWidgetActive = function(...) local id = args(...); return C:CornerOf(id) ~= nil end
	API.GetCurrentCornerForWidget = function(...) local id = args(...); return (C:CornerOf(id)) end
	API.RequestItemButtonsRefresh = function() C:RequestRefresh() end
end

-- Settings ready (and on every profile switch): place newly registered widgets once.
if ns.OnSignal then
	ns:OnSignal("ADDON_READY", function()
		C:InsertAll()
		C:Normalize()
		ns:On("PLAYER_REGEN_ENABLED", function() if C.pendingInit then C.pendingInit = false; C:RequestRefresh() end end)
		ns:On("GET_ITEM_INFO_RECEIVED", function() if next(C.retries) then C:RunRetries() end end)
	end)
	ns:OnSignal("PROFILE_ACTIVATED", function() C:InsertAll(); C:Normalize(); C:RequestRefresh() end)
end
