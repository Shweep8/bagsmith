--[[
	BagSmith - Core/Columns.lua

	(1.12.0-beta1) List view columns whose values come from somewhere other
	than the item itself: another addon's answer about it. Pawn's is the
	first (Core/Pawn.lua registers it). A registered column behaves as
	BagSmith's own do: it is listed in Settings > Bag Columns and Bank
	Columns, unticked until the player ticks it, and can then be moved,
	resized, set aside by a narrow window and sorted by its header.

	What a column gives when it registers (Columns:Register(key, def)):
	  label      the header's text, and its name in Settings
	  owner      the addon whose answers it shows
	  width      its width in pixels until the player drags it
	  numeric    true for a right-aligned column, as BagSmith's numbers are
	  text       function(rec): the cell's text. nil means "not ready yet":
	             the cell keeps what it showed for the same item. "" or
	             false is an empty cell.
	  sort       function(rec): a number to sort by, from what is already
	             known (it is called many times in one sort, so it asks
	             nobody). Without it the column sorts as 0 for every item.
	  color      the cell's text color, { r, g, b }
	  available  function(): true, or false and a sentence saying why not
	             (the greyed column's tooltip in Settings)
	  tip        a sentence for the header's tooltip and the Settings row's

	Every function a column gives runs through pcall. One whose text fails
	Columns.MAX_FAILS times is switched off until the next reload rather
	than failing on every row.

	A registered column is never shown in Global Inventory (ns.GLOBAL_COLS
	lists what shows there). What it says about another character's saved
	items is its own business; Pawn's says nothing.

	Its key is saved in the same lists as BagSmith's own column keys (cols,
	colOrder, colAside, colWidths and the bank's), so Core/Settings.lua's
	load check has to know it: ns.EXTRA_COLS there.
--]]
local ADDON, ns = ...
local Columns = {}
ns.Columns = Columns

Columns.defs = {}        -- key -> the column
Columns.keys = {}        -- keys, in the order registered
Columns.MAX_FAILS = 5
Columns.DEFAULT_WIDTH = 60
local FIELD = "colX_"    -- a row's font string for a registered column: b["colX_" .. key]

function Columns:Register(key, def)
	if type(key) ~= "string" or key == "" or key == "n" or type(def) ~= "table" or type(def.text) ~= "function" then return false end
	if self.defs[key] or ns.COL_LABEL[key] then return false end   -- taken, by a registered column or one of BagSmith's own
	local label = (type(def.label) == "string" and def.label ~= "") and def.label or key
	local width = tonumber(def.width)
	if not width or width ~= width then width = self.DEFAULT_WIDTH end
	local color = def.color
	if not (type(color) == "table" and tonumber(color[1]) and tonumber(color[2]) and tonumber(color[3])) then color = nil end
	self.defs[key] = {
		key = key, label = label, owner = type(def.owner) == "string" and def.owner or nil,
		width = math.max(30, math.min(400, math.floor(width))), numeric = def.numeric and true or false,
		text = def.text, sort = type(def.sort) == "function" and def.sort or nil, color = color,
		available = type(def.available) == "function" and def.available or nil,
		tip = type(def.tip) == "string" and def.tip or nil, fails = 0,
	}
	self.keys[#self.keys + 1] = key
	ns.COL_LABEL[key] = label   -- the header, Settings and the Sort button's name read it there, as for BagSmith's own
	return true
end
function Columns:Get(key) return key and self.defs[key] or nil end
function Columns:Field(key) return FIELD .. key end
function Columns:Numeric(key) local d = self.defs[key]; return d and d.numeric or false end
function Columns:Width(key) local d = self.defs[key]; return d and d.width or nil end

-- Can the column show anything right now? Its own word, and why not.
function Columns:Available(key)
	local d = self.defs[key]
	if not d then return true end
	if d.off then return false, "This column ran into errors, so it is off until you reload." end
	if not d.available then return true end
	local ok, yes, why = pcall(d.available)
	if not ok then return false end
	return yes and true or false, (not yes and type(why) == "string") and why or nil
end
-- A ticked column that can show now: AH Price needs a price addon, a registered column has its own say, the rest
-- always can. (The tick itself is kept either way.)
function Columns:Usable(key)
	if key == "ah" then return ns.AH and ns.AH:Available() or false end
	if self.defs[key] then return (self:Available(key)) end
	return true
end

-- The cell's text for one item: a string, or nil for "not ready yet".
function Columns:Value(key, rec)
	local d = self.defs[key]
	if not d or d.off or not rec then return "" end
	local ok, text = pcall(d.text, rec)
	if not ok then
		d.fails = d.fails + 1
		if d.fails >= self.MAX_FAILS then
			d.off = true
			ns:Debug("Columns: %s failed %d times and is off until a reload (%s)", key, d.fails, tostring(text))
		end
		return ""
	end
	if text == nil then return nil end
	if text == false then return "" end
	return tostring(text)
end
function Columns:SortValue(key, rec)
	local d = self.defs[key]
	if not d or d.off or not d.sort or not rec then return 0 end
	local ok, v = pcall(d.sort, rec)
	v = ok and tonumber(v) or nil
	if not v or v ~= v then return 0 end
	return v
end

-- A row's registered cells, from its record. b.xcols is the row's own list of them, made when its columns are
-- placed (Buttons:ApplyColumns): { key, fs } and what the cell last showed, for whom.
function Columns:Fill(b, rec)
	local cells = b.xcols
	if not cells then return end
	for _, c in ipairs(cells) do
		local fs = b[c.fs]
		if fs then
			local text = self:Value(c.key, rec)
			local link = rec and rec.link or nil
			-- not ready yet: the same item keeps what it showed, a different one starts empty
			if text == nil then text = (link ~= nil and c.link == link and c.text) or "" end
			c.link, c.text = link, text
			fs:SetText(text)
		end
	end
end
function Columns:Clear(b)
	for _, c in ipairs(b.xcols or {}) do
		c.link, c.text = nil, nil
		if b[c.fs] then b[c.fs]:SetText("") end
	end
end

-- A column's answers changed after the rows were drawn (Pawn answering late): the rows on screen show the new ones,
-- and a window sorted by that column sorts again.
function Columns:Changed(key)
	if not self.defs[key] then return end
	if ns.Buttons and ns.Buttons.EachLive then
		ns.Buttons:EachLive(function(b)
			if b.mode == "row" and b.xcols and b.hasItem and b.rec and (not b.IsShown or b:IsShown()) then Columns:Fill(b, b.rec) end
		end)
	end
	local sorted = false
	for _, v in pairs(ns.views or {}) do
		local cs = v.st and v.st.colSort
		if cs and cs.key == key and (not v.IsShown or v:IsShown()) then sorted = true end
	end
	if sorted and ns.RefreshViews then ns:RefreshViews(true) end
end
