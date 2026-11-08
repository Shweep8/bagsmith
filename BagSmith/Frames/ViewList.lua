--[[
	BagSmith - Frames/ViewList.lua
	What a view shows and how it is laid out: which records, filtering and
	merged stacks, the column plan and header, rows, icon cells and sections,
	in-place refreshes, and rows holding still under the pointer.
--]]

local ADDON, ns = ...
local Skins, Buttons = ns.Skins, ns.Buttons
local View = ns.View
local C = View.C
local PAD, HEADER_H, LANE_H, GAP, COLW, COLPAD, NUMERIC, COLKEY = C.PAD, C.HEADER_H, C.LANE_H, C.GAP, C.COLW, C.COLPAD, C.NUMERIC, C.COLKEY

------------------------------------------------------------------------
-- What this view shows
------------------------------------------------------------------------
function View:IsCached()
	if ns.ui.owner then return true end
	if self.isMain and self.st.sheet == "Bank" then return true end   -- main's Bank sheet is always the saved view
	if self.isBank and not ns.atBank then return true end
	return false
end

function View:Bags()
	if self.isBank then return ns.BANK_BAGS, true end
	if self.kind == "main" then
		if self.st.sheet == "Bank" then return ns.BANK_BAGS, true end
		return ns.BAGS, false
	end
	return self.opts.bags, self.opts.bank and true or false
end

function View:Records()
	-- Your own Gear Sets sheet: every set's slots, worn and banked included.
	if self.kind == "main" and self.st.sheet == "GearSets" and not ns.ui.owner and ns.GearSets and ns.GearSets:Available() then
		return ns.GearSets:SheetRecords(), nil, false
	end
	local bags, bank = self:Bags()
	local want = {}
	for _, b in ipairs(bags) do want[b] = true end
	local src, bagInfo
	if ns.ui.owner then
		src, bagInfo = ns:CachedRecords(ns.ui.owner, bank)
	elseif bank and (not ns.atBank or self.isMain) then
		-- The dedicated bank window owns the live bank buttons; the main
		-- window's Bank sheet always reads the saved copy.
		src, bagInfo = ns:CachedRecords(ns:CharKey(), true)
	else
		src = bank and ns.bankItems or ns.items
	end
	local out = {}
	for _, rec in ipairs(src) do if want[rec.bag] then out[#out + 1] = rec end end
	return out, bagInfo, bank
end

local function sheetPred(sheet)
	if sheet == "All" then return function(r) return not (ns.db.hideJunk and r.cat == "Junk") end end
	if sheet == "Bank" then return function() return true end end
	-- Gear Sets: items in a set (another character's saved bags say which).
	if sheet == "GearSets" then return function(r) return ns.GearSets and ns.GearSets:SetsOf(r) ~= nil end end
	for _, s in ipairs(ns.db.sheets) do if s.n == sheet then return function() return true end end end
	for _, s in ipairs(ns.db.bankSheets) do if s.n == sheet then return function() return true end end end
	-- (1.5.0-beta9) the Consumables tab includes Split Consumables' sections
	return function(r) return r.cat == sheet or ns.PARENT_CAT[r.cat] == sheet end
end

-- Collapse stacks of the same item into one record. The representative
-- keeps its real bag and slot (so its secure button still works); the
-- count is the total and "where" lists how many stacks there are.
local function mergeStacks(list)
	local byId, out = {}, {}
	for _, r in ipairs(list) do
		local key = not r.display and ns.MergeKey(r)
		local m = key and byId[key]
		if not key then
			out[#out + 1] = r   -- display-only rows (the Gear Sets sheet) are never merged
		elseif not m then
			m = {}
			for k, v in pairs(r) do m[k] = v end
			m.stacks, m.merged = 1, true
			m.members = { { bag = r.bag, slot = r.slot, itemID = r.itemID, count = r.count or 1 } }
			byId[key] = m
			out[#out + 1] = m
		else
			m.count = m.count + (r.count or 1)
			m.stacks = m.stacks + 1
			m.members[#m.members + 1] = { bag = r.bag, slot = r.slot, itemID = r.itemID, count = r.count or 1 }
			if (r.firstSeen or 0) > (m.firstSeen or 0) then m.firstSeen = r.firstSeen end
			m.isNew = m.isNew or r.isNew
		end
	end
	for _, m in ipairs(out) do
		if (m.stacks or 1) > 1 then m.where = ("%s +%d"):format(m.where or "", m.stacks - 1) end
	end
	return out
end

function View:Filtered()
	local records, bagInfo, bank = self:Records()
	local pred, fp = sheetPred(self.st.sheet), ns:FilterPredicate(self.st.filters)
	local shown, total = {}, 0
	-- Sections hidden at vendors or the auction house, while one is open.
	-- hiddenNow counts their items (shown or not, for the note at the end of
	-- the list); hiddenSecs names those sections.
	local anyHide = not self:IsCached() and ns.Sections and ns.Sections:HidingAny()
	local hiding = anyHide and not ns.ui.showHidden
	local hidden, secs, secSeen = 0, {}, {}
	for _, r in ipairs(records) do
		if pred(r) then
			local would = anyHide and ns.Sections:WouldHide(r)
			if would then
				hidden = hidden + 1
				local label = ns.Sections:Label(ns.Sections:EffectiveSection(r))
				if not secSeen[label] then secSeen[label] = true; secs[#secs + 1] = label end
			end
			if not (would and hiding) then
				total = total + 1
				if fp(r) then shown[#shown + 1] = r end
			end
		end
	end
	self.hiddenNow, self.hiddenSecs = hidden, secs
	-- (the Gear Sets tab never merges: each row is one set's slot, and one
	-- item in two sets is two rows, not a stack of two)
	if self:Pref("mergeStacks") and self.kind ~= "bag" and self.st.sheet ~= "GearSets" then
		-- Merge once; the total counts distinct items, not stacks.
		local all = {}
		for _, r in ipairs(records) do if pred(r) then all[#all + 1] = r end end
		shown = mergeStacks(shown)
		local seen, n = {}, 0
		for _, r in ipairs(all) do
			-- (items hidden at this vendor or auction house aren't counted, as unmerged)
			if not (hiding and ns.Sections:HiddenNow(r)) then
				local k = r.display and r or ns.MergeKey(r); if not seen[k] then seen[k] = true; n = n + 1 end
			end
		end
		total = n
	end
	return shown, total, records, bagInfo, bank
end

------------------------------------------------------------------------
-- Column plan
------------------------------------------------------------------------
-- The list's width, for laying out columns. Right after a window opens or
-- changes size the game may not have laid it out yet, and then reports 0 (or
-- says its rect isn't valid). Columns must never be planned from that: it
-- squeezed every column into 200 px and their header names vanished. So a
-- bad read uses the last width trusted for this window (adjusted for the
-- window's current size), and the list is planned again on the next frame,
-- once the real width is there.
local ROW_RETRIES = 10
function View:RowWidth()
	local s = self.scroll
	local w = s:GetWidth() or 0
	local valid = w >= 100 and not (s.IsRectValid and not s:IsRectValid())
	local fw = self.frame:GetWidth() or 0
	if valid then
		w = math.floor(w)
		self.trustedRowWidth = w
		if fw > w then self.rowChrome = fw - w end
		self.rowRetries = 0
		return math.max(200, w)
	end
	local est
	if self.rowChrome and fw - self.rowChrome >= 100 then est = fw - self.rowChrome
	elseif self.trustedRowWidth then est = self.trustedRowWidth
	elseif fw >= 100 + PAD * 2 + 22 then est = fw - PAD * 2 - 22
	else est = 200 end
	self.rowRetries = (self.rowRetries or 0) + 1
	if self.rowRetries <= ROW_RETRIES then
		ns:NextFrame("rowwidth:" .. self.name, function() if self.frame:IsShown() then self:Refresh(true) end end)
	end
	return math.max(200, math.floor(est))
end

-- Called once per view: whenever the list's width really changes (the grip,
-- the Size settings, a skin switch), plan the columns again on the next
-- frame. While the grip is being dragged it waits for the release.
function View:WatchRowWidth()
	if self.rowWatch or not self.scroll then return end
	self.rowWatch = true
	self.scroll:HookScript("OnSizeChanged", function(_, w)
		-- Compared with the raw width the plan was made from (not the plan's
		-- 200 px floor), so a narrow list can't keep asking for rebuilds.
		local made = self.trustedRowWidth
		if self.sizing or not made or not w or w < 100 then return end
		if math.abs(math.floor(w) - made) > 1 then
			ns:NextFrame("rowwidth:" .. self.name, function() if self.frame:IsShown() then self:Refresh(true) end end)
		end
	end)
end

local COL_MIN, COL_MAX, ITEM_MIN = 30, 400, 90

-- When the fixed columns don't fit beside Item's minimum, they shrink in
-- proportion (none below COL_MIN) just for display: the saved widths are
-- untouched, so a wider window brings them back exactly.
local function squeeze(order, widths, room)
	local free, total = {}, 0
	for _, key in ipairs(order) do if key ~= "n" then free[key] = true; total = total + widths[key] end end
	if total <= room then return false end
	for _ = 1, #order do
		local freeSum, pinned = 0, 0
		for _, key in ipairs(order) do
			if key ~= "n" then if free[key] then freeSum = freeSum + widths[key] else pinned = pinned + widths[key] end end
		end
		local left = room - pinned
		if freeSum <= 0 or left <= 0 then
			for key in pairs(free) do widths[key] = COL_MIN end
			break
		end
		local f = left / freeSum
		local floored = false
		for key in pairs(free) do
			if widths[key] * f < COL_MIN then widths[key] = COL_MIN; free[key] = nil; floored = true end
		end
		if not floored then
			for key in pairs(free) do widths[key] = math.floor(widths[key] * f) end
			break
		end
	end
	return true
end

-- Column plan, left to right. Item ("n") can sit anywhere in the order and
-- takes whatever width the fixed columns leave; every other column uses its
-- saved pixel width or a default fraction of the row, squeezed to fit when
-- the window is too narrow for them.
function View:ColumnPlan()
	local width = self:RowWidth()
	local narrow = not self.big and width < 360
	local order = {}
	if narrow then order = { "n", "c" } else
		local cols = self:Pref("cols")
		for _, key in ipairs(self:Pref("colOrder")) do
			-- AH Price only while Auctionator is installed (the tick is kept).
			if key == "n" or (ns.IndexOf(cols, key) and (key ~= "ah" or ns.AH:Available())) then order[#order + 1] = key end
		end
		if not ns.IndexOf(order, "n") then table.insert(order, 1, "n") end
	end
	local widths, fixed = {}, 0
	for _, key in ipairs(order) do
		if key ~= "n" then
			local w = self:Pref("colWidths")[key] or ((key == "jk" or key == "fv" or key == "cc") and 30) or math.floor(width * (narrow and 0.18 or COLW[key]))
			widths[key] = w
			fixed = fixed + w
		end
	end
	local squeezed = false
	if not narrow then
		squeezed = squeeze(order, widths, width - ITEM_MIN)
		if squeezed then fixed = 0; for _, key in ipairs(order) do if key ~= "n" then fixed = fixed + widths[key] end end end
	end
	widths.n = math.max(ITEM_MIN, width - fixed)
	local plan, x = {}, 0
	-- The item menu button (three dots) sits at the left of the Item column.
	local K = (ns.db.itemMenuButton and 12) or 0
	plan.kebab = K > 0
	for _, key in ipairs(order) do
		local w = widths[key]
		if key == "n" then
			plan[#plan + 1] = { key = "n", fs = "colName", x = x + 26 + K, width = w - 26 - K - COLPAD, iconX = x + 2 + K, kebabX = x, colX = x, colW = w }
		else
			plan[#plan + 1] = { key = key, fs = COLKEY[key], x = x + 4, width = w - 4 - COLPAD, colX = x, colW = w }
		end
		x = x + w
	end
	plan.squeezed = squeezed
	return plan, width
end

function View:LayoutHeader(plan)
	local visible = {}
	self.headerSeps = self.headerSeps or {}
	self.headerGrips = self.headerGrips or {}
	local si = 0
	local narrowHeader = not self.big
	for i, col in ipairs(plan) do
		local b = self.headerLabels[col.key]
		if b then
			b:ClearAllPoints()
			b:SetPoint("LEFT", self.header, "LEFT", col.key == "n" and col.colX + 4 or col.x, 0)
			b:SetWidth(col.width)
			b.text:SetJustifyH(NUMERIC[col.key] and "RIGHT" or "LEFT")
			local cs = self.st.colSort
			local iconCol = col.key == "jk" or col.key == "fv" or col.key == "cc"
			b.text:SetText(iconCol and "" or ns.COL_LABEL[col.key] or "Item")
			if iconCol then
				-- Icon headers: the Sell All Junk pouch, the star, the wallet.
				if not b.junkIcon then
					b.junkIcon = b:CreateTexture(nil, "OVERLAY"); b.junkIcon:SetSize(16, 16)
					if col.key == "jk" then ns.Junk:SetColumnIcon(b.junkIcon) else ns.Marks.KINDS[col.key].art(b.junkIcon) end
				end
				-- One family: all three in the header text's color.
				local hr, hg, hb = b.text:GetTextColor()
				b.junkIcon:SetVertexColor(hr or 0.56, hg or 0.55, hb or 0.51)
				-- Centered on the column itself (where its row cells are), not on
				-- the label, which is laid out for text and sits left of center.
				b.junkIcon:ClearAllPoints(); b.junkIcon:SetPoint("CENTER", self.header, "LEFT", col.colX + col.colW / 2, 0); b.junkIcon:Show()
			elseif b.junkIcon then b.junkIcon:Hide() end
			if not b.sortIcon then
				b.sortIcon = b:CreateTexture(nil, "OVERLAY"); b.sortIcon:SetSize(9, 9)
			end
			if cs and cs.key == col.key then
				b.sortIcon:SetTexture("Interface\\AddOns\\BagSmith\\Media\\" .. (cs.dir == "asc" and "ui-sort-up.tga" or "ui-sort-down.tga"))
				b.sortIcon:SetVertexColor(Skins:Accent())
				b.sortIcon:ClearAllPoints()
				if iconCol then b.sortIcon:SetPoint("LEFT", b.junkIcon, "RIGHT", 1, 0)   -- beside the icon, not over it
				elseif NUMERIC[col.key] then b.sortIcon:SetPoint("LEFT", b, "LEFT", 0, 0)
				else b.sortIcon:SetPoint("LEFT", b, "LEFT", b.text:GetStringWidth() + 4, 0) end
				b.sortIcon:Show()
			else
				b.sortIcon:Hide()
			end
			b:Show()
			visible[col.key] = true
			if i > 1 then
				si = si + 1
				local sep = self.headerSeps[si]
				if not sep then
					sep = self.header:CreateTexture(nil, "ARTWORK")
					sep:SetTexture("Interface\\Buttons\\WHITE8X8"); sep:SetVertexColor(1, 1, 1, 0.08); sep:SetWidth(1)
					self.headerSeps[si] = sep
				end
				sep:ClearAllPoints(); sep:SetPoint("TOP", self.header, "TOPLEFT", col.colX, 0); sep:SetPoint("BOTTOM", self.header, "BOTTOMLEFT", col.colX, 0); sep:Show()
			end
		end
	end
	for j = si + 1, #self.headerSeps do self.headerSeps[j]:Hide() end
	self:LayoutColumnGrips(plan, narrowHeader)
	for key, b in pairs(self.headerLabels) do if not visible[key] then b:Hide() end end
	local head = self:Pref("view") == "list" and self.kind ~= "bag"
	if self.header:IsShown() ~= head then
		self.header:SetShown(head)
		if self.PlaceScroll then self:PlaceScroll() end   -- (1.5.5) Icons view reclaims the headers' room; List view gives it back
	end
end

-- Column width grips: one on every line between two columns (none at the
-- row's outer edges). Dragging a line moves it with the pointer and changes
-- only the two columns touching it, one wider and the other narrower by the
-- same amount; every other column stays put. Item is still the only column
-- that grows and shrinks with the window, so the row always fills. Limits:
-- 30 to 400 px for a fixed column, 90 px at least for Item. Double-click a
-- line to reset both columns.
local function limits(key) if key == "n" then return ITEM_MIN, math.huge end return COL_MIN, COL_MAX end
local function colName(key) return ns.COL_LABEL[key] or "Item" end

local function onGripDown(g)
	g.dragging = true
	local startX = GetCursorPosition() / UIParent:GetEffectiveScale()
	local widths = g.view:Pref("colWidths")
	-- Squeezed (window too narrow for the saved widths): keep what is on
	-- screen for every column first, so the line can follow the pointer.
	local plan = g.view.columnPlan
	if plan and plan.squeezed then
		for _, c in ipairs(plan) do if c.key ~= "n" then widths[c.key] = c.colW end end
	end
	local a, b = g.left, g.right   -- { key, w } from the plan at the moment of the click
	local minA, maxA = limits(a.key)
	local minB, maxB = limits(b.key)
	local dMin = math.max(minA - a.w, b.w - maxB)
	local dMax = math.min(maxA - a.w, b.w - minB)
	g:SetScript("OnUpdate", function(u)
		local x = GetCursorPosition() / UIParent:GetEffectiveScale()
		local d = math.floor((x - startX) / (u:GetEffectiveScale() / UIParent:GetEffectiveScale()) + 0.5)
		if d < dMin then d = dMin elseif d > dMax then d = dMax end
		local changed = false
		-- Item's width is never saved: it is whatever the fixed columns leave.
		if a.key ~= "n" and widths[a.key] ~= a.w + d then widths[a.key] = a.w + d; changed = true end
		if b.key ~= "n" and widths[b.key] ~= b.w - d then widths[b.key] = b.w - d; changed = true end
		if changed then ns:NextFrame("colresize", function() ns:RefreshViews(true) end) end
	end)
end

function View:LayoutColumnGrips(plan, narrowHeader)
	self.columnPlan = plan
	-- Nothing in the header ever draws past the row's edge.
	if self.header.SetClipsChildren and not self.headerClips then self.header:SetClipsChildren(true); self.headerClips = true end
	local grips = self.headerGrips
	local n = 0
	if not narrowHeader then
		for i = 1, #plan - 1 do
			local left, right = plan[i], plan[i + 1]
			n = i
			local g = grips[i]
			if not g then
				g = CreateFrame("Button", nil, self.header)
				g:SetSize(10, HEADER_H)
				g:SetFrameLevel(self.header:GetFrameLevel() + 5)
				g.tex = g:CreateTexture(nil, "OVERLAY"); g.tex:SetTexture("Interface\\Buttons\\WHITE8X8"); g.tex:SetWidth(2)
				g.tex:SetPoint("TOP", 0, -3); g.tex:SetPoint("BOTTOM", 0, 3)
				local ar, ag, ab = Skins:Accent(); g.tex:SetVertexColor(ar, ag, ab, 0.25)
				g:SetScript("OnEnter", function(s)
					local r1, g1, b1 = Skins:Accent(); s.tex:SetVertexColor(r1, g1, b1, 0.9)
					if ns.TooltipsOK() then
						GameTooltip:SetOwner(s, "ANCHOR_TOP")
						GameTooltip:SetText(("Drag to resize %s and %s"):format(colName(s.left.key), colName(s.right.key)))
						GameTooltip:AddLine("Double-click to reset both", 0.6, 0.6, 0.6)
						GameTooltip:Show()
					end
				end)
				g:SetScript("OnLeave", function(s) if not s.dragging then local r1, g1, b1 = Skins:Accent(); s.tex:SetVertexColor(r1, g1, b1, 0.25) end GameTooltip:Hide() end)
				g:SetScript("OnMouseDown", onGripDown)
				g:SetScript("OnMouseUp", function(s) s.dragging = false; s:SetScript("OnUpdate", nil); local r1, g1, b1 = Skins:Accent(); s.tex:SetVertexColor(r1, g1, b1, 0.25) end)
				g:SetScript("OnDoubleClick", function(s)
					local widths = s.view:Pref("colWidths")
					widths[s.left.key] = nil; widths[s.right.key] = nil
					ns:RefreshViews(true)
				end)
				grips[i] = g
			end
			g.view = self
			g.left = { key = left.key, w = left.colW }
			g.right = { key = right.key, w = right.colW }
			g.colKey = right.key   -- the column to the right of the line
			g:ClearAllPoints(); g:SetPoint("LEFT", self.header, "LEFT", right.colX - 5, 0)
			g:SetHeight(HEADER_H)
			g:Show()
		end
	end
	for j = n + 1, #grips do grips[j]:Hide() end
end

-- Section header values, in one format for the whole window. The item count
-- sits beside the section's name ("Trade Goods (11)"); the right side holds
-- only values: "V:" for the vendor value and "AH:" for the Auctionator total
-- (while that window's AH Price column is on), exact amounts, "-" for a
-- missing value. One line when every header has room; otherwise every header
-- stacks them as a small table:
--     V:  6s 27c
--     AH: 19s 70c
-- amounts right-aligned at the edge, labels right-aligned beside them (the
-- colons line up), the amount column as wide as the widest amount in the
-- window so the columns line up from header to header. Only if even that won't
-- fit does the AH total go, then the vendor value. Recent keeps its own words.
local LABEL_GAP, EDGE = 4, 4
local function writeHeaderValues(infos)
	local anyAH = false
	for _, i in ipairs(infos) do if i.ah then anyAH = true end end
	-- Room the name and its count take on the left.
	-- (a gear set's Equip button sits right after the count, so it counts too)
	local function titleW(h) return (h.textX or 20) - 20 + h.text:GetStringWidth() + 6 + h.count:GetStringWidth() + ((h.equipSet and h.equipSet:IsShown()) and (8 + h.equipSet:GetWidth()) or 0)
		+ ((h.wornTag and h.wornTag:IsShown()) and (10 + h.wornTag:GetStringWidth()) or 0) end
	local function hideTable(h) h.vLabel:Hide(); h.vAmt:Hide(); h.aLabel:Hide(); h.aAmt:Hide() end
	local function single(i, text)
		local h = i.h
		hideTable(h)
		h.sub:ClearAllPoints(); h.sub:SetPoint("RIGHT", -EDGE, 0)
		h.sub:SetText(text)
		h.sub:SetShown(text ~= "")
		return titleW(h) + h.sub:GetStringWidth() + 60 <= i.colW
	end
	local amtW, labelW = 0, 0
	if anyAH then
		for _, i in ipairs(infos) do
			if not i.recent then
				local h = i.h
				h.vAmt:SetText(i.v); amtW = math.max(amtW, h.vAmt:GetStringWidth())
				if i.ah then h.aAmt:SetText(i.ah); amtW = math.max(amtW, h.aAmt:GetStringWidth()) end
				h.vLabel:SetText("V:"); h.aLabel:SetText("AH:")
				labelW = math.max(labelW, h.vLabel:GetStringWidth(), h.aLabel:GetStringWidth())
			end
		end
	end
	local function stacked(i)
		local h = i.h
		h.sub:Hide()
		h.vAmt:ClearAllPoints(); h.vAmt:SetPoint("TOPRIGHT", -EDGE, -3); h.vAmt:SetText(i.v); h.vAmt:Show()
		h.vLabel:ClearAllPoints(); h.vLabel:SetPoint("TOPRIGHT", -(EDGE + amtW + LABEL_GAP), -3); h.vLabel:SetText("V:"); h.vLabel:Show()
		if i.ah then
			h.aAmt:ClearAllPoints(); h.aAmt:SetPoint("BOTTOMRIGHT", -EDGE, 3); h.aAmt:SetText(i.ah); h.aAmt:Show()
			h.aLabel:ClearAllPoints(); h.aLabel:SetPoint("BOTTOMRIGHT", -(EDGE + amtW + LABEL_GAP), 3); h.aLabel:SetText("AH:"); h.aLabel:Show()
		else
			h.aAmt:Hide(); h.aLabel:Hide()
		end
		return titleW(h) + labelW + LABEL_GAP + amtW + 60 <= i.colW
	end
	local formats = { function(i) return single(i, "V: " .. i.v .. (i.ah and (", AH: " .. i.ah) or "")) end }
	if anyAH then formats[#formats + 1] = stacked end
	formats[#formats + 1] = function(i) return single(i, "V: " .. i.v) end
	formats[#formats + 1] = function(i) return single(i, "") end
	-- Recent: "Recent (23) [Clear Recent]   also in their sections". Everything
	-- counts toward the fit; when it's short of room the words on the right go
	-- first (the header's tooltip still explains the copies), then the button
	-- shortens to "Clear". The name, count and a working button always stay.
	local function recentFits(i, words, short)
		local h, btn = i.h, i.h.clearRecent
		if btn then
			btn.label:SetText(short and "Clear" or "Clear Recent")
			btn:SetWidth(short and math.max(44, math.ceil(btn.label:GetStringWidth()) + 16) or 86)
		end
		single(i, words and "also in their sections" or "")
		local need = titleW(h) + (btn and (8 + btn:GetWidth()) or 0) + 60
		if words then need = need + 12 + h.sub:GetStringWidth() end
		return need <= i.colW
	end
	for _, i in ipairs(infos) do
		if i.recent and not recentFits(i, true, false) and not recentFits(i, false, false) then recentFits(i, false, true) end
		-- An empty custom section: no values; in icon view, a muted hint.
		if i.emptyCustom then single(i, i.emptyHint and "Empty. Drag an item onto this title." or "") end
		-- A gear set with nothing in your bags: where its items are instead.
		if i.emptySet then single(i, i.setNote or "") end
	end
	local chosen = formats[#formats]
	for _, f in ipairs(formats) do
		local all = true
		for _, i in ipairs(infos) do
			if not i.recent and not i.emptyCustom and not i.emptySet and not f(i) then all = false; break end
		end
		if all then chosen = f; break end
	end
	for _, i in ipairs(infos) do if not i.recent and not i.emptyCustom and not i.emptySet then chosen(i) end end
end

-- Refill the rows already on screen without moving anything. With
-- blankGone, a row whose item has left becomes an empty gap.
function View:RefreshInPlace(bank, blankGone)
	local fp = ns:FilterPredicate(self.st.filters)
	local live = bank and ns.bankItems or ns.items
	-- Hidden at this vendor or auction house (the same rule as a full layout).
	local hiding = ns.Sections and ns.Sections:HidingAny() and not ns.ui.showHidden
	local function hidden(r) return hiding and ns.Sections:HiddenNow(r) end
	-- Merged totals count exactly what a full refresh would show: this
	-- window's bags, its sheet, and the active filters.
	local pool
	local function mergePool()
		if pool then return pool end
		pool = {}
		local recs = self:Records()
		local pred = sheetPred(self.st.sheet)
		for _, o in ipairs(recs) do if pred(o) and fp(o) and not hidden(o) then pool[#pool + 1] = o end end
		return pool
	end
	local bySlot = {}
	for _, r in ipairs(live) do bySlot[r.bag * 1000 + r.slot] = r end
	for _, b in ipairs(self.used or {}) do
		local old = b.rec
		if old and not old.cached and old.bag and old.slot then
			local r = bySlot[old.bag * 1000 + old.slot]
			-- A blank row (or empty slot cell) whose slot gains an item shows it
			-- at once: its button already uses that slot.
			if old.empty and not r then r = false end
			-- A row's button is bound to its own bag slot, so the row only ever
			-- shows what is in that slot: a merged row whose stack is gone shows
			-- whatever took its place, or blanks, never another stack of the item
			-- (a click would use the slot, not the stack on show). The merged
			-- total returns with the next full layout.
			if old.merged and not r then
				Buttons:Blank(b, { bag = old.bag, slot = old.slot, empty = true })
				if not b:IsShown() and not InCombatLockdown() then b:Show() end
			elseif r then
				local rec = r
				if old.merged and r.itemID == old.itemID and r.quality == old.quality then
					-- Keep the merged total while the layout is frozen.
					rec = {}
					for k, v in pairs(r) do rec[k] = v end
					rec.count, rec.merged, rec.where, rec.stacks, rec.members = 0, true, old.where, 0, {}
					local mk = ns.MergeKey(r)
					for _, o in ipairs(mergePool()) do
						if ns.MergeKey(o) == mk then
							rec.count = rec.count + (o.count or 1); rec.stacks = rec.stacks + 1
							rec.members[#rec.members + 1] = { bag = o.bag, slot = o.slot, itemID = o.itemID, count = o.count or 1 }
						end
					end
				end
				if hidden(r) then
					-- A hidden item never shows as an active row: its button is
					-- hidden (in combat that's blocked, so it's dimmed instead).
					if InCombatLockdown() then Buttons:Fill(b, rec, { dim = true }) else b:Hide() end
				else
					Buttons:Fill(b, rec, { dim = not fp(r) })
					-- Hidden earlier for a hidden item: show it again now its slot
					-- holds something visible.
					if not b:IsShown() and not InCombatLockdown() then b:Show() end
				end
			elseif r == nil and (blankGone or InCombatLockdown()) then
				-- (In combat the row can't be removed, but it mustn't keep showing the old item.)
				Buttons:Blank(b, { bag = old.bag, slot = old.slot, empty = true })
				if not b:IsShown() and not InCombatLockdown() then b:Show() end
			elseif r == false and not b:IsShown() and not InCombatLockdown() then
				-- An empty cell hidden while a hidden item sat in it: the slot is
				-- empty again, so the empty cell shows again.
				Buttons:Blank(b, { bag = old.bag, slot = old.slot, empty = true })
				b:Show()
			end
		end
	end
end

-- Does the filtered list hold an item that has no row on screen yet?
-- Extra stacks of an item already shown as a merged row don't count.
function View:HasArrivals(shown)
	local onScreen, mergedShown = {}, {}
	for _, b in ipairs(self.used or {}) do
		local r = b.rec
		-- (a row hidden for a hidden item isn't on screen)
		if r and not r.empty and r.bag and r.slot and b:IsShown() then
			onScreen[r.bag * 1000 + r.slot] = true
			if r.merged then mergedShown[ns.MergeKey(r)] = true end
		end
	end
	for _, r in ipairs(shown or {}) do
		if r.merged then
			if not mergedShown[ns.MergeKey(r)] then return true end
		elseif r.bag and r.slot and not onScreen[r.bag * 1000 + r.slot] then
			return true
		end
	end
	return false
end

-- Rows hold still while the pointer is over the list: items that leave
-- leave a gap, new items wait, and the list tidies up once the pointer
-- leaves the window. Only item changes are held; searching, settings and
-- clicks on the toolbar still update straight away.
local holdWatcher, holdActive   -- one frame for the life of the session; WoW never frees frames
local function holdTick(f)
	local any = false
	for _, v in pairs(ns.views) do
		if v.held and v.sizing then
			any = true   -- mid-drag: the tidy-up waits for the drag to end
		elseif v.held then
			if not v.frame:IsShown() or not v.frame:IsMouseOver() then v.held = false; v.refreshTag = "tidy-up"; v:Refresh(); v.refreshTag = nil
			else any = true end
		end
	end
	if not any then f:SetScript("OnUpdate", nil); holdActive = false end
end
local function watchHeld()
	if holdActive then return end
	holdWatcher = holdWatcher or CreateFrame("Frame")
	holdActive = true
	holdWatcher:SetScript("OnUpdate", holdTick)
end
ns.WatchHeld = watchHeld

function View:Refresh(force, reason)
	if not self.frame:IsShown() or not Buttons.created then return end
	-- No layout while the corner is being dragged (the size is passing
	-- through); the drag's end lays out once, then again when sizes settle.
	if self.sizing then self.refreshWanted = true; return end
	local shown, total, all, bagInfo, bank = self:Filtered()
	local cached = self:IsCached()

	-- A change in the bag set itself (a bag equipped, removed or swapped)
	-- never holds: new slots appear or go, so everything refreshes at once.
	local bagSet = self:BagSetKey(bagInfo)
	local bagsChanged = self.lastBagSet ~= nil and bagSet ~= self.lastBagSet
	self.lastBagSet = bagSet
	-- (1.4.1) ...except while a Clean Up you asked for is rearranging the bags: then everything lays out at once,
	-- so no item shows in its new slot and its old place together until the pointer leaves.
	local cleaning = ns.cleanupUntil and GetTime() < ns.cleanupUntil
	if reason == "items" and not force and not bagsChanged and self.big and not cached and not InCombatLockdown()
		and not cleaning and self.frame:IsMouseOver() and self.used and #self.used > 0 then
		self:RefreshInPlace(bank, true)
		self:UpdateFooter(bagInfo)
		if self.bagBar and ns.BagBar then ns.BagBar:UpdateStatus(self.bagBar) end
		self.held = true
		watchHeld()
		-- Something new arrived (dropped in, looted): show it shortly, even if
		-- the pointer stays put, so it never looks lost. Items leaving still
		-- just leave gaps until the pointer moves away.
		if self:HasArrivals(shown) then
			self.arrivalToken = (self.arrivalToken or 0) + 1
			local token = self.arrivalToken
			C_Timer.After(0.25, function()
				if token ~= self.arrivalToken or not self.held then return end
				self.held = false
				self.refreshTag = "arrival"
				ns:RefreshViews()   -- waits on its own if a mouse button is down
				self.refreshTag = nil
			end)
		end
		return
	end

	if InCombatLockdown() then
		-- Visual-only refresh: refill frames already on screen, dim non-matches.
		self:RefreshInPlace(bank, false)
		local waiting = false
		for _, bg in ipairs(self:Bags()) do if ns.bagInfo[bg] and ns.bagInfo[bg].pendingGrow then waiting = true end end
		self.statusText:SetText(waiting and "Locked in combat; new bag slots appear after" or "Layout locked in combat")
		ns:Safely("layout:" .. self.name, function() self:Refresh(true) end)
		self:UpdateFooter(bagInfo)
		return
	end
	self.held = false   -- a full rebuild lays everything out fresh
	local waiting = false
	for _, b in ipairs(self:Bags()) do if ns.bagInfo[b] and ns.bagInfo[b].pendingGrow then waiting = true end end
	self.statusText:SetText(waiting and "New bag slots appear after combat" or "")

	if self.bankBar then
		local h = ns.Bank and ns.Bank:FillBar(self.bankBar) or 0
		self.bankBar:SetHeight(math.max(1, h))
		self.bankBar:SetShown(h > 0)
	end
	if self.bagBar then
		-- The bag strip: the column header sits under it while it's shown.
		local h = ns.BagBar and ns.BagBar:FillBar(self.bagBar) or 0
		self.bagBar:SetHeight(math.max(1, h))
		self.bagBar:SetShown(h > 0)
		if (h > 0) ~= (self.bagBarOpen and true or false) then
			self.bagBarOpen = h > 0
			self:PlaceHeader()
		end
	end
	local plan, width = self:ColumnPlan()
	self.planWidth = width
	self:WatchRowWidth()
	self:LayoutHeader(plan)
	local height = self:Layout(shown, all, plan, width, bagInfo, bank, cached)
	-- The list ends at the bottom of its last row: no padding below it, so
	-- there is nothing to scroll past.
	self.contentHeight = height
	local oldHeight = self.child and self.child.GetHeight and self.child:GetHeight() or 0
	local savedScroll = self.trustedScroll or (self.scroll.GetVerticalScroll and self.scroll:GetVerticalScroll()) or 0
	ns:Debug("%s rebuilt (%s): list height %d -> %d, width %d, scroll %d", self.name, self.refreshTag or reason or (force and "forced") or "update", oldHeight, height, width or 0, math.floor(savedScroll or 0))
	self.child:SetSize(width, math.max(height, 1))
	self:UpdateChrome(shown, total, bagInfo, cached)
	self:UpdateFooter(bagInfo)
	if self.big then self:UpdateTabs(); self:SyncTools() end
	-- Auto size: content height plus chrome, capped by maxH.
	local chrome = self.frame:GetHeight() - self.scroll:GetHeight()
	self.lastChrome = chrome
	self.autoHeight = height + chrome + 4
	self:ApplySize()
	-- Only now is the final scroll height known; show the bar only if the
	-- content still overflows it.
	if self.scroll.ScrollBar then
		local visible = self.scroll:GetHeight()
		if self.isMain and ns.db.sizeMode == "auto" then visible = math.min(ns.db.maxH, self.autoHeight) - chrome - 4
		elseif self.kind == "bag" then visible = math.min(ns.db.bagMaxH, self.autoHeight) - chrome - 4 end
		self:UpdateBarSpace(height, visible)
		self:SyncScrollBar()
		self:RestoreScroll(savedScroll, height, visible)
	end
	ns:Fire("VIEW_LAYOUT", self)   -- geometry is valid from here (the plugin API coalesces this into VIEW_UPDATED)
end

-- Which bags exist and their sizes: a change here is a change in the bag set.
function View:BagSetKey(bagInfo)
	local parts = {}
	-- Live views read the live bag sizes (their refresh has no saved bag
	-- info); a saved character's view keeps its saved info.
	local live = not self:IsCached()
	for _, bag in ipairs(self:Bags() or {}) do
		local info = (live and ns.bagInfo[bag]) or (bagInfo and bagInfo[bag])
		parts[#parts + 1] = tostring(bag) .. ":" .. tostring(info and info.size or 0)
	end
	return table.concat(parts, ",")
end

-- Locked cells (bag windows, items hidden at a vendor or the auction house):
-- plain frames, made once and reused, that show the item greyed with a padlock.
function View:LockCell(host, i, rec, x, y, cell)
	self.lockCells = self.lockCells or {}
	local c = self.lockCells[i]
	if not c then
		c = CreateFrame("Frame", nil, host)
		c.icon = c:CreateTexture(nil, "ARTWORK"); c.icon:SetAllPoints(); c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		c.shade = c:CreateTexture(nil, "ARTWORK", nil, 1); c.shade:SetAllPoints(); c.shade:SetColorTexture(0, 0, 0, 0.45)
		c.lock = c:CreateTexture(nil, "OVERLAY"); c.lock:SetPoint("CENTER")
		c.lock:SetTexture("Interface\\AddOns\\BagSmith\\Media\\ui-lock.tga")
		c:EnableMouse(true)
		c:SetScript("OnEnter", function(cf)
			if not (cf.rec and ns.TooltipsOK()) then return end
			local where = ns.Sections:Where() == "ah" and "the auction house" or "vendors"
			GameTooltip:SetOwner(cf, "ANCHOR_RIGHT")
			GameTooltip:SetText(cf.rec.name or "Hidden item", 1, 1, 1)
			GameTooltip:AddLine(("Hidden at %s (%s). Use Show Them at the end of the bags list to show it."):format(where, ns.Sections:Label(ns.Sections:EffectiveSection(cf.rec))), 0.8, 0.8, 0.8, true)
			GameTooltip:Show()
		end)
		c:SetScript("OnLeave", function() GameTooltip:Hide() end)
		self.lockCells[i] = c
	end
	c:SetParent(host)
	c.rec = rec
	c:ClearAllPoints(); c:SetSize(cell, cell); c:SetPoint("TOPLEFT", host, "TOPLEFT", x, y)
	c.icon:SetTexture(rec.icon); c.icon:SetDesaturated(true)
	c.lock:SetSize(math.floor(cell * 0.6), math.floor(cell * 0.6))
	if ns.Classic and ns.Classic.IsOn and ns.Classic.IsOn() then c.lock:SetVertexColor(1, 0.82, 0) else c.lock:SetVertexColor(0.92, 0.9, 0.86) end
	c:Show()
end
function View:HideLockCells(from)
	for i = (from or 0) + 1, #(self.lockCells or {}) do self.lockCells[i]:Hide() end
end

-- The note at the end of the list while a vendor or the auction house hides
-- some sections: "4 items hidden at this vendor (Gear, Favorites)" with Show
-- Them, then "Showing 4 items..." with Hide Again. Made once per view.
function View:PlaceHiddenNotice(host, y, width)
	local n = self.hiddenNow or 0
	local where = ns.Sections and ns.Sections:Where()
	local note = self.hiddenNote
	if n == 0 or not where then
		if note then note:Hide() end
		return y
	end
	if not note then
		note = CreateFrame("Frame", nil, host)
		note:SetHeight(50)
		note.text = note:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		note.text:SetPoint("TOP", note, "TOP", 0, -6); note.text:SetJustifyH("CENTER")
		note.btn = ns.TextButton(note, "", 100, function()
			ns.ui.showHidden = not ns.ui.showHidden
			ns:RefreshViews(true)
		end)
		note.btn:SetHeight(22); note.btn:SetPoint("TOP", note.text, "BOTTOM", 0, -6)
		self.hiddenNote = note
	end
	note:SetParent(host)
	note:ClearAllPoints(); note:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -(y + 8)); note:SetWidth(width)
	local place = where == "ah" and "at the auction house" or "at this vendor"
	local items = n == 1 and "1 item" or ("%d items"):format(n)
	if ns.ui.showHidden then
		note.text:SetText(("Showing %s from sections hidden %s"):format(items, place))
		note.btn.label:SetText("Hide Again")
	else
		note.text:SetText(("%s hidden %s (%s)"):format(items, place, table.concat(self.hiddenSecs or {}, ", ")))
		note.btn.label:SetText("Show Them")
	end
	note.text:SetWidth(math.max(80, width - 24)); note.text:SetTextColor(Skins:Color("muted"))
	note.btn:SetWidth(math.ceil(note.btn.label:GetStringWidth()) + 28)
	if note.btn.SetClassic then note.btn:SetClassic(ns.Classic and ns.Classic.IsOn and ns.Classic.IsOn() or false) end
	note.btn:SetActive(false)
	-- Sized from the text as it wraps at this width, plus the button.
	local textH = math.max(12, math.ceil(note.text:GetStringHeight() or 12))
	local h = 6 + textH + 6 + 22 + 6
	note:SetHeight(h)
	note:Show()
	return y + 8 + h + 8
end

-- Lays out lanes/items. Returns content height.
function View:Layout(shown, all, plan, width, bagInfo, bank, cached)
	local db = ns.db
	local host = self.child
	local used, usedSet = {}, {}
	local iconMode = self:Pref("view") == "icons" or self.kind == "bag"
	local rowH, cell = db.dense and 22 or db.rowHeight, db.iconSize
	local y = 0

	-- Live bags: attach proxies to this host so the buttons draw and clip here.
	-- Bag windows mirror the slots with plain cells instead, so the secure
	-- buttons stay in the main window.
	local bags = self:Bags()
	local mirror = self.kind == "bag" and not cached
	if not cached and not mirror then for _, b in ipairs(bags) do Buttons:AttachBag(b, host) end end

	local grp = self:Pref("grp")
	-- The reagent bag is a place, not a type: its own section applies only when
	-- Sections is All. By Type sorts its items by type (and your moves); By
	-- Bag shows every bag as a section anyway.
	local reagentLane = db.reagent == "lane" and grp == "none" and self.kind == "main" and self.st.sheet ~= "Bank"
	local reagentName = ns.bagInfo[ns.REAGENT_BAG] and ns.bagInfo[ns.REAGENT_BAG].name

	-- Slot grid: single-bag icon view with no lanes shows every slot, empties included.
	-- Bag windows are always a plain slot grid (keys included).
	local slotGrid = self.kind == "bag" or (iconMode and not self.big and grp == "none" and db.emptySlots and #bags == 1
		and not (db.keys and (function() for _, r in ipairs(all) do if r.cat == "Keys" then return true end end end)()))
	if slotGrid then
		local bag = bags[1]
		local size = cached and (bagInfo and bagInfo[bag] and bagInfo[bag].size or 0) or (ns.bagInfo[bag] and ns.bagInfo[bag].size or 0)
		local perRow = math.max(1, math.floor((width + GAP) / (cell + GAP)))
		if self.kind == "bag" then perRow = math.max(1, math.min(perRow, db.bagCols)) end
		local shownSet = {}
		for _, r in ipairs(shown) do shownSet[r.slot] = r end
		local allSet = {}
		for _, r in ipairs(all) do allSet[r.slot] = r end
		local ci, locks = 0, 0
		for slot = 1, size do
			local b
			if mirror then b = Buttons:GetMirror(host, slot); b:SetID(slot); b.bag = bag
			elseif cached then b = Buttons:GetCached(host, slot) else b = Buttons:Get(bag, slot) end
			if b then
				ci = ci + 1
				local col, row = (ci - 1) % perRow, math.floor((ci - 1) / perRow)
				local x, yy = col * (cell + GAP), -(row * (cell + GAP))
				local r = allSet[slot]
				-- Hidden at this vendor or auction house: a locked cell instead of the
				-- item's button (greyed icon, padlock, no clicks, no drops), so it
				-- can't be sold or used and doesn't look like room. In combat the
				-- button can't be hidden, so it's only dimmed there.
				local locked = r and not cached and ns.Sections and ns.Sections:HiddenNow(r)
				if locked and not InCombatLockdown() then
					b:Hide()
					locks = locks + 1
					self:LockCell(host, locks, r, x, yy, cell)
				else
					Buttons:SetMode(b, "cell")
					b:ClearAllPoints()
					b:SetSize(cell, cell)
					b:SetPoint("TOPLEFT", host, "TOPLEFT", x, yy)
					if r then Buttons:Fill(b, r, { dim = locked or not shownSet[slot] }) else Buttons:Blank(b) end
					b:Show()
					used[#used + 1] = b; usedSet[b] = true
				end
			end
		end
		self:HideLockCells(locks)
		y = math.ceil(ci / perRow) * (cell + GAP)
		self:HideUnused(usedSet, host)
		if self.hiddenNote then self.hiddenNote:Hide() end   -- bag windows lock their hidden items instead
		self.used = used
		return y
	end

	-- Favorites: favorited items move into their own section (like pinned
	-- mail), so they're taken out before the usual sections are built.
	-- Recent still lists a newly looted favorite (Recent shows copies).
	local shownAll = shown
	-- Gear sets: items in one of the game's equipment sets go to that set's
	-- section (the first by name when it's in more than one), ahead of
	-- Favorites. Saved bags carry the set names they were saved with.
	-- On the Gear Sets sheet every record already says its set (sheetSet)
	-- and slot, and each set lists every slot, whatever the setting.
	local setLanes
	local GS = ns.GearSets
	local onSheet = self.kind == "main" and self.st.sheet == "GearSets"
	local ownSheet = onSheet and not cached and GS and GS:Available()
	if GS and (GS:Showing() or onSheet) and (self.kind == "main" or self.isBank) then
		local bySet, setOrder, rest = {}, {}, {}
		local function add(name, r)
			if not bySet[name] then bySet[name] = {}; setOrder[#setOrder + 1] = name end
			table.insert(bySet[name], r)
		end
		for _, r in ipairs(shown) do
			-- An item in several sets shows in each. The first is the item's own
			-- button; the others are copies that work the same (like Recent's),
			-- marked so they don't look like more items (Buttons:LinkMark).
			-- Your own sheet's records already say their one set.
			local names = (onSheet and r.sheetSet and { r.sheetSet }) or GS:SetsOf(r)
			if names then
				for i, name in ipairs(names) do
					local rr = r
					if i > 1 then rr = {}; for k, v in pairs(r) do rr[k] = v end; rr.setCopy = true end
					add(name, rr)
				end
			else
				rest[#rest + 1] = r
			end
		end
		local sorter = ns:CurrentSorter(self.st, self:Pref("sort"))
		local function bySlot(a, b)
			if (a.setSlot or 99) ~= (b.setSlot or 99) then return (a.setSlot or 99) < (b.setSlot or 99) end
			return (a.name or "") < (b.name or "")
		end
		local function nameOrder(a, b) local la, lb = a.label:lower(), b.label:lower(); if la ~= lb then return la < lb end return a.label < b.label end
		local f = self.st.filters or {}
		local narrowing = ns.FilterCount(f) > 0 or (f.text or "") ~= ""
		local where = ns.Sections and ns.Sections:Where()
		-- (every set shares one Show at Vendor / AH choice: "~gs")
		local function hiddenHere() return where and not ns.ui.showHidden and not ns.Sections:Shown("~gs", where) end
		if ownSheet then
			-- Your own sheet: every set, slot by slot; the title says where
			-- its items are, with Equip when some are in your bags.
			setLanes = {}
			for _, set in ipairs(GS:Sets()) do
				local items = bySet[set.name] or {}
				if (#items > 0 or not narrowing) and (#items > 0 or not hiddenHere()) then
					table.sort(items, bySlot)
					local t = GS:Tally(set)
					local note, worn = GS:EmptyNote(set)
					if t.total > 0 and not worn then note = GS:Places(set) end
					setLanes[#setLanes + 1] = { id = GS.LaneId(set.name), orderId = "~gs", label = set.name, items = items, gearSet = set.name,
						noteOnly = true, setNote = note, allWorn = worn, canEquip = t.bags > 0 }
				end
			end
			if #setLanes == 0 then setLanes = nil end
			shown = rest
		elseif #setOrder > 0 then
			setLanes = {}
			for _, name in ipairs(setOrder) do
				table.sort(bySet[name], onSheet and bySlot or sorter)
				setLanes[#setLanes + 1] = { id = GS.LaneId(name), orderId = "~gs", label = name, items = bySet[name], gearSet = name, canEquip = not cached }
			end
			table.sort(setLanes, nameOrder)
			shown = rest
		end
		-- A set with nothing in your bags (worn, in the bank or missing) still
		-- shows its title in your own bags window, as empty custom sections
		-- do: not while a search or filters narrow the window, not on a
		-- built-in category tab, not By Bag, and not while it's hidden at
		-- this vendor or auction house.
		if not onSheet and not cached and self.kind == "main" and self.st.sheet ~= "Bank" and grp ~= "bag" and GS:Available() then
			local sheet = self.st.sheet
			local savedSheet = false
			for _, s in ipairs(ns.db.sheets or {}) do if s.n == sheet then savedSheet = true end end
			local categorySheet = sheet and sheet ~= "All" and not savedSheet
			if not narrowing and not categorySheet then
				local have = {}
				for _, name in ipairs(setOrder) do have[name] = true end
				for _, set in ipairs(GS:Sets()) do
					local id = GS.LaneId(set.name)
					if not have[set.name] and not hiddenHere() then
						local note, worn = GS:EmptyNote(set)
						setLanes = setLanes or {}
						setLanes[#setLanes + 1] = { id = id, orderId = "~gs", label = set.name, items = {}, gearSet = set.name, noteOnly = true, setNote = note, allWorn = worn }
					end
				end
				if setLanes then table.sort(setLanes, nameOrder) end
			end
		end
	end
	local favLane
	if not cached and db.favSection and ns.Marks and (self.kind == "main" or self.isBank) then
		local favs, rest = {}, {}
		for _, r in ipairs(shown) do
			if not r.empty and r.itemID and r.cat ~= "Junk" and ns.Marks:IsFavorite(r.itemID) then favs[#favs + 1] = r else rest[#rest + 1] = r end
		end
		if #favs > 0 then
			table.sort(favs, ns:CurrentSorter(self.st, self:Pref("sort")))
			favLane = { id = "~fav", label = "Favorites", items = favs, favorites = true }
			shown = rest
		end
	end
	-- Pinned sections (1.4.0): in All view, their items leave the main list for their own sections near the top
	-- (not repeated below). By Section moves the pinned sections up as they are; By Bag ignores pins.
	local pins = (ns.Sections and not cached and grp ~= "bag") and ns.Sections:PinnedSet() or {}
	local pinLanes
	if grp == "none" and next(pins) then
		local byPin, rest = {}, {}
		for _, r in ipairs(shown) do
			local id = r.cat
			if not r.empty and id and pins[id] then byPin[id] = byPin[id] or {}; table.insert(byPin[id], r) else rest[#rest + 1] = r end
		end
		if next(byPin) then
			pinLanes = {}
			local sorter = ns:CurrentSorter(self.st, self:Pref("sort"))
			for id, items in pairs(byPin) do
				table.sort(items, sorter)
				pinLanes[#pinLanes + 1] = { id = id, label = ns.Sections:Label(id) or id, items = items, pinnedSection = true }
			end
			shown = rest
		end
	end
	local lanes = ns:BuildLanes(shown, grp, { reagentLane = reagentLane, reagentName = reagentName, sorter = ns:CurrentSorter(self.st, self:Pref("sort")) })
	local function insertByOrder(lane)
		local order = {}
		for i, id in ipairs(db.laneOrder) do order[id] = i end
		-- (every gear set shares the one "~gs" place: orderId)
		local mine = order[lane.orderId or lane.id] or 1
		local at = #lanes + 1
		local placed = false
		if mine == 1 then at = 1; placed = true else
			for i, l in ipairs(lanes) do
				local o = order[l.orderId or l.id]
				if o then
					placed = true
					if o > mine then at = i; break else at = i + 1 end
				end
			end
		end
		-- Sections not in Section Order (no sections, or By Bag): above them if
		-- it comes before the first item section in the order, else below.
		if not placed then
			local firstCat
			for i, id in ipairs(db.laneOrder) do if id:sub(1, 1) ~= "~" then firstCat = i; break end end
			at = (firstCat and mine < firstCat) and 1 or (#lanes + 1)
		end
		table.insert(lanes, at, lane)
		-- Beside a special section, an unlabeled list gets an "All Items" header.
		for _, l in ipairs(lanes) do if l.id == "" then l.id, l.label = "~all", "All Items" end end
		return at
	end
	if favLane then insertByOrder(favLane) end
	-- The sets together at Gear Sets' place, in name order.
	if setLanes then
		local at = insertByOrder(setLanes[1])
		for i = 2, #setLanes do at = at + 1; table.insert(lanes, at, setLanes[i]) end
	end
	-- Empty custom sections (Show When Empty), so a new one is visible and
	-- takes drops right away. Not while a search or filters narrow the window,
	-- unless the filter picks that very section (a sheet for it).
	-- (1.4.0-beta3: a pinned custom section always shows, empty or not, in By Section and in All view, whatever its
	-- Show When Empty; only a search or filter that narrows the window, a category sheet, or its own vendor and
	-- auction-house hiding put it aside, as for any section)
	if (grp == "type" or (grp == "none" and next(pins))) and not cached and ns.Sections then
		local f = self.st.filters or {}
		local narrowing = ns.FilterCount(f) > 0 or (f.text or "") ~= ""
		-- A built-in category sheet (Gear, Consumables...) shows only its own
		-- category, so it never gains unrelated custom headings.
		local sheet = self.st.sheet
		local savedSheet = false
		for _, s in ipairs(ns.db.sheets or {}) do if s.n == sheet then savedSheet = true end end
		for _, s in ipairs(ns.db.bankSheets or {}) do if s.n == sheet then savedSheet = true end end
		local categorySheet = sheet and sheet ~= "All" and sheet ~= "Bank" and not savedSheet
		local where = ns.Sections:Where()
		local have = {}
		for _, l in ipairs(lanes) do have[l.id] = true end
		-- (1.4.0-beta5: All view's pinned sections with items join the lanes later; they count as present here, or
		-- a pinned custom section with items would also get an empty copy)
		for _, l in ipairs(pinLanes or {}) do have[l.id] = true end
		for _, c in ipairs(ns.Sections:Customs()) do
			local pinnedHere = pins[c.id] == true
			local eligible = not have[c.id] and (pinnedHere or (grp == "type" and db.showEmptySections and ns.Sections:ShowsEmpty(c.id)))
				-- hidden here (vendor or auction house), unless Show Hidden
				and not (where and not ns.ui.showHidden and not ns.Sections:Shown(c.id, where))
				and (not categorySheet or sheet == c.id)
				-- searching or filtering hides them, unless the filter is for this section
				and (not narrowing or ((f.text or "") == "" and f.cat and f.cat[c.id]))
			if eligible then insertByOrder({ id = c.id, label = c.name, items = {}, emptyCustom = true, pinnedSection = pinnedHere or nil }) end
		end
	end
	-- Empty slots in icon view (no sections, or sections by bag): live views
	-- only, since an empty slot needs its secure button. They follow the items.
	-- whether this view shows empty slots: the drop overlay offers a free slot when it doesn't (1.4.0-beta2)
	self.emptyShown = (iconMode and db.emptySlots and not cached and not onSheet and grp ~= "type" and ns.FilterCount(self.st.filters) == 0 and (self.st.filters.text or "") == "") and true or false
	if iconMode and db.emptySlots and not cached and not onSheet and grp ~= "type" and ns.FilterCount(self.st.filters) == 0 and (self.st.filters.text or "") == "" then
		local used = {}
		for _, r in ipairs(all) do used[r.bag * 1000 + r.slot] = true end
		local byLane = {}
		for _, lane in ipairs(lanes) do byLane[lane.id] = lane end
		-- Sort: Off (1.4.0-beta4): the grid follows the bags as they are, so empty slots go where they really are
		-- (into the main list even when it carries its "All Items" title), instead of after the items.
		local offOrder = self:Pref("sort") == "off" and not self.st.colSort
		local touched = {}
		for index, bag in ipairs(bags) do
			local size = ns.bagInfo[bag] and ns.bagInfo[bag].size or 0
			if not (db.keys and bag == ns.KEYRING) then
				for slot = 1, size do
					if not used[bag * 1000 + slot] then
						local rec = { bag = bag, slot = slot, empty = true, bagIndex = index, name = "", quality = 1, count = 0, where = ns.bagInfo[bag].name }
						local id, label = ns:LaneOf(rec, grp, { reagentLane = reagentLane, reagentName = reagentName })
						local lane = byLane[id] or (offOrder and id == "" and byLane["~all"]) or nil
						if not lane then
							lane = { id = id, label = label, pinned = id == "~rb", items = {}, bagIndex = index }
							byLane[id] = lane; lanes[#lanes + 1] = lane
						end
						lane.items[#lane.items + 1] = rec
						touched[lane] = true
					end
				end
			end
		end
		if offOrder then
			local pos = {}
			for i, b in ipairs(bags) do pos[b] = i end
			local function asInBags(a, b)
				local x, y = pos[a.bag] or 99, pos[b.bag] or 99
				if x ~= y then return x < y end
				local s1, s2 = a.slot or 0, b.slot or 0
				if s1 ~= s2 then return s1 < s2 end
				return (a.name or "") < (b.name or "")
			end
			for lane in pairs(touched) do table.sort(lane.items, asInBags) end
			-- (1.4.1) All view, within a session: a slot that joins All Items because its item left a section shown
			-- elsewhere (unpinned, unfavorited, swapped out by a drop) goes to the end of All Items instead of its real
			-- place, so nothing already shown moves. A slot leaving All Items (an item going into a pinned section)
			-- just closes up. A fresh layout (opening the bags, a Clean Up, a change of sort, view or grouping) puts
			-- everything back in its true order.
			local mainLane = grp == "none" and (byLane["~all"] or byLane[""]) or nil
			if mainLane then
				local inMain = {}
				for _, r in ipairs(mainLane.items) do if r.bag and r.slot then inMain[r.bag * 1000 + r.slot] = true end end
				local omitted = {}
				for _, r in ipairs(all) do
					if r.bag and r.slot and not r.empty then
						local k = r.bag * 1000 + r.slot
						if not inMain[k] then omitted[k] = true end
					end
				end
				self.freedSlots = self.freedSlots or {}
				self.freedSeq = self.freedSeq or 0
				if self.lastOmitted then
					-- (numbered as they join, so a later one goes after an earlier one and nothing already shown moves)
					local joined = {}
					for k in pairs(self.lastOmitted) do if inMain[k] and not self.freedSlots[k] then joined[#joined + 1] = k end end
					table.sort(joined)
					for _, k in ipairs(joined) do self.freedSeq = self.freedSeq + 1; self.freedSlots[k] = self.freedSeq end
				end
				for k in pairs(self.freedSlots) do if not inMain[k] then self.freedSlots[k] = nil end end
				self.lastOmitted = omitted
				if next(self.freedSlots) then
					local keep, tail = {}, {}
					for _, r in ipairs(mainLane.items) do
						local k = r.bag and r.slot and (r.bag * 1000 + r.slot)
						if k and self.freedSlots[k] then tail[#tail + 1] = r else keep[#keep + 1] = r end
					end
					table.sort(tail, function(a, b) return self.freedSlots[a.bag * 1000 + a.slot] < self.freedSlots[b.bag * 1000 + b.slot] end)
					for _, r in ipairs(tail) do keep[#keep + 1] = r end
					mainLane.items = keep
				end
			end
		end
	end
	-- Pinned sections first, in Section Order (Recent, placed below, still takes the very top) (1.4.0).
	if next(pins) then
		if pinLanes then for _, l in ipairs(pinLanes) do lanes[#lanes + 1] = l end end
		local order = {}
		for i, id in ipairs(db.laneOrder) do order[id] = i end
		local front, rest = {}, {}
		for _, l in ipairs(lanes) do
			if l.pinnedSection or (grp == "type" and pins[l.id]) then l.pinnedSection = true; front[#front + 1] = l else rest[#rest + 1] = l end
		end
		if #front > 0 then
			table.sort(front, function(a, b) return (order[a.id] or 999) < (order[b.id] or 999) end)
			for _, l in ipairs(rest) do front[#front + 1] = l end
			for i = 1, #front do lanes[i] = front[i] end
			-- beside a pinned section, the unlabeled main list gets its "All Items" header
			local hasAll = false
			for _, l in ipairs(lanes) do if l.id == "~all" then hasAll = true end end
			if not hasAll then for _, l in ipairs(lanes) do if l.id == "" then l.id, l.label = "~all", "All Items"; break end end end
		end
	end
	local laneIdx, cachedIdx, linkIdx = 0, 0, 0
	local collapsedSet = {}
	for _, id in ipairs(self:CollapsedList()) do collapsedSet[id] = true end
	self.laneIds = {}

	-- Recent section (bags window only, optional): items first seen since the
	-- session began (or the last Clear Recent), newest first, pinned at the
	-- top. They also stay in their usual section; the copies use their own
	-- secure buttons, so they work exactly like the originals.
	-- It takes its place from Section Order (top by default); sections not in
	-- that order (bags, when grouping By Bag) keep theirs, with Recent at the
	-- top if it's first in the order, otherwise at the bottom.
	if self.kind == "main" and not cached and db.recentSection and self.st.sheet ~= "Bank" and self.st.sheet ~= "GearSets" then
		local recent = ns:RecentRecords(shownAll)
		if #recent > 0 then
			local lane = { id = "~recent", label = "Recent", items = recent, recent = true }
			local order = {}
			for i, id in ipairs(db.laneOrder) do order[id] = i end
			local mine = order["~recent"] or 1
			local at = #lanes + 1
			if mine == 1 then
				at = 1   -- first in Section Order: always the very top
			else
				for i, l in ipairs(lanes) do
					if order[l.id] then
						if order[l.id] > mine then at = i; break else at = i + 1 end
					end
				end
			end
			table.insert(lanes, at, lane)
			-- Sections: All has one unlabeled list; with Recent beside it, that
			-- list gets an "All Items" header so the two don't run together.
			-- Not in Section Order and not draggable; collapsible like any section.
			for _, l in ipairs(lanes) do
				if l.id == "" then l.id, l.label = "~all", "All Items" end
			end
		end
	end

	-- Icon Split View (optional, icon view): two columns of sections that fill
	-- left to right, top to bottom; each pair is top-aligned and the row is as
	-- tall as its taller section. Falls back to one column when a half can't
	-- fit MIN_HALF_ICONS icons. Recent pairs like any other section.
	local COL_GAP, MIN_HALF_ICONS = 16, 4
	local halfW = math.floor((width - COL_GAP) / 2)
	local twoCol = iconMode and self.big and grp ~= "none" and db.splitView
		and math.floor((halfW + GAP) / (cell + GAP)) >= MIN_HALF_ICONS
	self.twoColumn = twoCol and true or false
	local recentIdx = 0

	local headerInfos = {}
	local function placeLane(lane, x0, colW, y0)
		local y = y0
		local open = true
		if lane.id ~= "" then
			laneIdx = laneIdx + 1
			self.laneIds[#self.laneIds + 1] = lane.id
			open = not collapsedSet[lane.id]
			local h = Buttons:GetLane(host, laneIdx)
			local value = 0
			for _, r in ipairs(lane.items) do if r.sellPrice and not r.hasNoValue then value = value + r.sellPrice * r.count end end
			h.laneId = lane.id
			-- A gear set's title: its icon (your own sets) and a muted
			-- "Gear Set:" before the name, so it never looks like a regular section.
			local setIcon = lane.gearSet and not cached and ns.GearSets and ns.GearSets:Find(lane.gearSet)
			setIcon = setIcon and (setIcon.icon or 134400) or nil
			if setIcon then
				if not h.setIcon then
					h.setIcon = h:CreateTexture(nil, "OVERLAY")
					h.setIcon:SetSize(16, 16); h.setIcon:SetPoint("LEFT", 22, 0); h.setIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
				end
				h.setIcon:SetTexture(setIcon); h.setIcon:Show()
			elseif h.setIcon then
				h.setIcon:Hide()
			end
			local shift = setIcon and 42 or 20
			if (h.textX or 20) ~= shift then h.text:ClearAllPoints(); h.text:SetPoint("LEFT", shift, 0); h.textX = shift end
			if lane.gearSet then
				local m = Skins:Current().muted
				h.text:SetText(("|cff%02x%02x%02xGear Set:|r %s"):format(math.floor(m[1] * 255 + 0.5), math.floor(m[2] * 255 + 0.5), math.floor(m[3] * 255 + 0.5), lane.label))
			else
				h.text:SetText(lane.label)
			end
			local n = 0
			for _, r in ipairs(lane.items) do if not r.empty then n = n + 1 end end
			-- a pinned section says so beside its count, with the pin (1.4.0)
			h.count:SetText(lane.pinnedSection and ("(%d)   |TInterface\\AddOns\\BagSmith\\Media\\ui-pin.tga:12:12|t Pinned"):format(n) or ("(%d)"):format(n))
			h.showAH = nil
			-- The values are written after every header is placed, in one
			-- format for the whole window (see writeHeaderValues above).
			local info = { h = h, colW = colW, recent = lane.recent, emptyCustom = lane.emptyCustom, emptyHint = lane.emptyCustom and iconMode, emptySet = lane.noteOnly, setNote = lane.setNote }
			if not lane.recent then
				info.v = value > 0 and ns.Money(value) or "-"
				if ns.AH:Available() and ns.IndexOf(self:Pref("cols"), "ah") then
					h.showAH = true
					local total = 0
					for _, r in ipairs(lane.items) do if not r.empty then total = total + (ns.AH:StackValue(r) or 0) end end
					info.ah = total > 0 and ns.Money(total) or "-"
				end
			end
			headerInfos[#headerInfos + 1] = info
			h.arrow:SetTexture("Interface\\AddOns\\BagSmith\\Media\\" .. (open and "ui-chev-down.tga" or "ui-chev-right.tga"))
			local s = Skins:Current()
			local ar, ag, ab = Skins:Accent()
			h.text:SetTextColor(ar, ag, ab); h.accent:SetVertexColor(ar, ag, ab, 0.9); h.sub:SetTextColor(unpack(s.muted)); h.count:SetTextColor(unpack(s.muted)); for _, k in ipairs({ "vLabel", "vAmt", "aLabel", "aAmt" }) do h[k]:SetTextColor(unpack(s.muted)) end; h.arrow:SetVertexColor(unpack(s.muted)); h.line:SetColorTexture(unpack(s.line))
			h.view = self
			if not h.scriptsSet then
				-- Set once per header; they read h.laneId and h.view at click time.
				h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
				h:SetScript("OnClick", function(btn, mouse)
					-- Holding an item: drop it on this section (it goes back to its slot).
					if ns.Sections and ns.Sections:CursorItem() then
						if ns.Sections:DropOnSection(btn.laneId) then return end
					end
					if mouse == "RightButton" then if ns.Sections then ns.Sections:SectionMenu(btn.laneId, btn) end return end
					btn.view:ToggleLane(btn.laneId)
				end)
				h:SetScript("OnReceiveDrag", function(btn) if ns.Sections then ns.Sections:DropOnSection(btn.laneId) end end)
				-- "All Items" (Sections: All beside Recent) isn't in Section Order, so it doesn't drag.
				h:SetScript("OnDragStart", function(btn) if btn.laneId == "~all" then return end ns.dragLane = btn.laneId; btn:SetAlpha(0.5) end)
				h:SetScript("OnDragStop", function(btn)
					btn:SetAlpha(1)
					local target = ns.FrameUnderCursor("laneId")
					if ns.dragLane and target and target ~= ns.dragLane and target ~= "~all" then ns:ReorderLane(ns.dragLane, target) end
					ns.dragLane = nil
				end)
				-- Headers explain their numbers on hover (Recent, its copies).
				h:SetScript("OnEnter", function(btn)
					-- Holding an item over a section that takes it: say what dropping does.
					local hint = ns.Sections and ns.Sections:DropHint(btn.laneId)
					if hint then
						GameTooltip:SetOwner(btn, "ANCHOR_TOP"); GameTooltip:SetText(hint, 1, 1, 1); GameTooltip:Show()
						btn.dropLit = true; btn.accent:SetVertexColor(1, 1, 1, 1)
						return
					end
					if not ns.TooltipsOK() then return end
					GameTooltip:SetOwner(btn, "ANCHOR_TOP")
					if btn.laneId == "~recent" then
						GameTooltip:SetText("Recent Items", 1, 1, 1)
						GameTooltip:AddLine("Items you picked up since you logged in. They're also in their usual sections; Clear Recent empties this list without moving or removing anything.", nil, nil, nil, true)
					else
						GameTooltip:SetText(btn.text:GetText() or "", 1, 1, 1)
						if ns.GearSets and ns.GearSets.IsLane(btn.laneId) then
							GameTooltip:AddLine("A gear set from the game's Equipment Manager: its items that are in your bags. Right-click for more.", nil, nil, nil, true)
						end
						GameTooltip:AddLine("Vendor (V): what a merchant pays for everything in this section.", nil, nil, nil, true)
						if btn.showAH then GameTooltip:AddLine("AH: the total from Auctionator's last scan. Items it hasn't scanned are left out.", nil, nil, nil, true) end
					end
					GameTooltip:Show()
				end)
				h:SetScript("OnLeave", function(btn)
					GameTooltip:Hide()
					if btn.dropLit then btn.dropLit = nil; btn.accent:SetVertexColor(Skins:Accent()) end
				end)
				h.scriptsSet = true
			end
			-- Recent's own Clear Recent button, beside its title.
			if lane.recent then
				if not h.clearRecent then
					h.clearRecent = ns.TextButton(h, "Clear Recent", 86, function() ns:ClearRecent() end)
					h.clearRecent:SetHeight(18)
					h.clearRecent:SetScript("OnEnter", nil)
				end
				-- Right after the count: "Recent (23) [Clear Recent]".
				h.clearRecent.tip = (db.newdot and db.newdotClearRecent) and "Empties the Recent list and clears the green dots." or "Empties the Recent list."
				h.clearRecent:ClearAllPoints()
				h.clearRecent:SetPoint("LEFT", h.count, "RIGHT", 8, 0)
				h.clearRecent:Show()
			elseif h.clearRecent then
				h.clearRecent:Hide()
			end
			-- Warlocks: Clear Shards on the section holding Soul Shards in ordinary bags.
			local shardHere = false
			if not lane.recent and not cached and ns.MakeRoom and ns.MakeRoom:IsWarlock() then
				for _, r in ipairs(lane.items) do
					if r.itemID == 6265 and r.bag and ns.MakeRoom:BagFamily(r.bag) == 0 then shardHere = true; break end
				end
				if shardHere then local _, can = ns.MakeRoom:Shards(); shardHere = can > 0 end
			end
			if shardHere then
				if not h.clearShards then
					h.clearShards = ns.TextButton(h, "Clear Shards", 86, function() ns.MakeRoom:ShowShards() end)
					h.clearShards:SetHeight(18)
					h.clearShards.tip = "Destroy Soul Shards kept in your ordinary bags (never ones in a soul bag)."
				end
				h.clearShards:ClearAllPoints()
				h.clearShards:SetPoint("LEFT", h.count, "RIGHT", 8, 0)
				h.clearShards:Show()
			elseif h.clearShards then
				h.clearShards:Hide()
			end
			-- A gear set: Equip beside its count (the bags window, your own
			-- live bags; nothing can be equipped from the bank or an alt).
			local GSm = ns.GearSets
			if lane.gearSet and lane.canEquip and GSm and not cached and self.kind == "main" and self.st.sheet ~= "Bank" then
				if not h.equipSet then
					h.equipSet = ns.TextButton(h, "Equip", 54, function(b) ns.GearSets:Equip(b.setName) end)
					h.equipSet:SetHeight(18)
				end
				h.equipSet.setName = lane.gearSet
				GSm.buttons[h.equipSet] = true
				h.equipSet:ClearAllPoints()
				h.equipSet:SetPoint("LEFT", h.count, "RIGHT", 8, 0)
				h.equipSet:Show()
				GSm:PaintButton(h.equipSet)
			elseif h.equipSet then
				h.equipSet:Hide()
			end
			-- A set you're wearing: "Worn" where Equip would be.
			if lane.allWorn then
				if not h.wornTag then
					h.wornTag = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
					h.wornTag:SetText("Worn")
				end
				h.wornTag:ClearAllPoints(); h.wornTag:SetPoint("LEFT", h.count, "RIGHT", 10, 0)
				h.wornTag:SetTextColor(unpack(Skins:Current().muted))
				h.wornTag:Show()
			elseif h.wornTag then
				h.wornTag:Hide()
			end
			h:ClearAllPoints()
			h:SetSize(colW, LANE_H)
			h:SetPoint("TOPLEFT", host, "TOPLEFT", x0, -y)
			if h.lastY and h.lastY ~= y and h.host == host and self.animate then
				h.slide:SetOffset(0, y - h.lastY)
				h.anim:Stop(); h.anim:Play()
			end
			h.lastY, h.host = y, host
			h:Show()
			used[#used + 1] = h; usedSet[h] = true
			y = y + LANE_H + (iconMode and 4 or 0)   -- icon rows get a little air under the header
		end
		if open then
			local function buttonFor(r)
				if lane.recent then recentIdx = recentIdx + 1; return Buttons:GetRecent(recentIdx, r.bag, r.slot, self.name) end
				if cached or r.display then cachedIdx = cachedIdx + 1; return Buttons:GetCached(host, cachedIdx) end
				-- A shared gear set item's second (third...) showing: a copy button.
				if r.setCopy then recentIdx = recentIdx + 1; return Buttons:GetRecent(recentIdx, r.bag, r.slot, self.name) end
				return Buttons:Get(r.bag, r.slot)
			end
			if iconMode then
				local perRow = math.max(1, math.floor((colW + GAP) / (cell + GAP)))
				for i, r in ipairs(lane.items) do
					local b = buttonFor(r)
					if b then
						b.inLane, b.inView = lane.id, self   -- (1.4.0-beta5: where a drop on it lands)
						Buttons:SetMode(b, "cell")
						b:ClearAllPoints(); b:SetSize(cell, cell)
						local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
						b:SetPoint("TOPLEFT", host, "TOPLEFT", x0 + col * (cell + GAP), -(y + row * (cell + GAP)))
						if r.empty then Buttons:Blank(b, r) else Buttons:Fill(b, r, r.display and { dim = true } or nil) end
						b:Show()
						used[#used + 1] = b; usedSet[b] = true
					end
				end
				y = y + math.ceil(#lane.items / perRow) * (cell + GAP) + 2
			else
				for _, r in ipairs(lane.items) do
					local b = buttonFor(r)
					if b then
						b.inLane, b.inView = lane.id, self
						Buttons:SetMode(b, "row")
						b:ClearAllPoints(); b:SetSize(colW, rowH)
						b:SetPoint("TOPLEFT", host, "TOPLEFT", x0, -y)
						Buttons:ApplyColumns(b, plan, rowH)
						Buttons:Fill(b, r)
						Buttons:SetStripe(b, (#used % 2) == 1)
						b:Show()
						used[#used + 1] = b; usedSet[b] = true
						y = y + rowH
					end
				end
			end
		end
		return y
	end

	local inRow, rowTop, rowBottom = false, y, y
	for _, lane in ipairs(lanes) do
		if not twoCol then
			if inRow then y = rowBottom; inRow = false end
			y = placeLane(lane, 0, width, y)
		elseif not inRow then
			rowTop = y
			rowBottom = placeLane(lane, 0, halfW, rowTop)
			inRow = true
		else
			rowBottom = math.max(rowBottom, placeLane(lane, halfW + COL_GAP, halfW, rowTop))
			y = rowBottom
			inRow = false
		end
	end
	if inRow then y = rowBottom end
	writeHeaderValues(headerInfos)
	self.animate = false
	self:HideUnused(usedSet, host)
	self.used = used
	y = self:PlaceGearSetsNote(host, y, width, onSheet and #lanes == 0)
	return self:PlaceHiddenNotice(host, y, width)
end

-- The Gear Sets sheet with nothing on it: no sets yet (with a Create Gear
-- Set button), or another character's bags with no set items saved.
function View:PlaceGearSetsNote(host, y, width, show)
	local note = self.gsNote
	if not show then
		if note then note:Hide() end
		return y
	end
	if not note then
		note = CreateFrame("Frame", nil, host)
		note.text = note:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		note.text:SetPoint("TOP", note, "TOP", 0, -10); note.text:SetJustifyH("CENTER")
		note.btn = ns.TextButton(note, "Create Gear Set", 130, function() if ns.GearSets then ns.GearSets:PromptNew() end end)
		note.btn:SetHeight(22); note.btn:SetPoint("TOP", note.text, "BOTTOM", 0, -10)
		note.btn.tip = "Saves what you're wearing now as a gear set (shirt and tabard left out)."
		self.gsNote = note
	end
	note:SetParent(host)
	note:ClearAllPoints(); note:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -(y + 8)); note:SetWidth(width)
	local mine = not ns.ui.owner and ns.GearSets and ns.GearSets:Available()
	local f = self.st.filters or {}
	local narrowing = ns.FilterCount(f) > 0 or (f.text or "") ~= ""
	local text
	if not mine then text = "No gear set items saved for this character. Log in as them to see their sets."
	elseif #ns.GearSets:Sets() == 0 then text = "No gear sets yet."
	else text = narrowing and "No gear set items match." or "No gear sets yet." end
	note.text:SetText(text); note.text:SetWidth(math.max(80, width - 24)); note.text:SetTextColor(Skins:Color("muted"))
	local withButton = mine and #ns.GearSets:Sets() == 0
	note.btn:SetShown(withButton and true or false)
	if withButton then
		if note.btn.SetClassic then note.btn:SetClassic(ns.Classic and ns.Classic.IsOn and ns.Classic.IsOn() or false) end
		note.btn:SetActive(false)
	end
	local h = 10 + math.max(14, math.ceil(note.text:GetStringHeight() or 14)) + (withButton and (10 + 22) or 0) + 10
	note:SetHeight(h)
	note:Show()
	return y + 8 + h + 8
end

function View:HideUnused(usedSet, host)
	for _, b in ipairs(Buttons.all) do
		if not usedSet[b] and b:IsShown() and b:GetParent():GetParent() == host then b:Hide(); b.rec, b.hasItem = nil, nil end
	end
	for _, b in pairs(Buttons.cached[host] or {}) do if not usedSet[b] then b:Hide() end end
	for _, b in pairs(Buttons.mirrors[host] or {}) do if not usedSet[b] then b:Hide() end end
	-- This window's own copies only (each window has its own pool).
	for _, b in ipairs(Buttons.copyPools[self.name] or {}) do
		if not usedSet[b] and b:IsShown() then b:Hide(); b.rec, b.hasItem = nil, nil end
	end
	for _, h in pairs(Buttons.lanes[host] or {}) do if not usedSet[h] then h:Hide(); h.lastY = nil end end
end
