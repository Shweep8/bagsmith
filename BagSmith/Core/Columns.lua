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
	if not ns.COL_LABEL[key] then return false end   -- (1.12.0-beta3) a saved key nobody answers for: an addon's column, the addon not loaded
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
		self:Failed(d, text)
		return ""
	end
	if text == nil then return nil end
	if text == false then return "" end
	return tostring(text)
end
-- (1.12.0-beta5, the beta4 audit's advisory) A failure here counts toward MAX_FAILS like one in Columns:Value: the
-- docs say five failures switch a column off, and a column that only ever failed while sorting was never counted.
function Columns:Failed(d, err)
	d.fails = d.fails + 1
	if d.fails >= self.MAX_FAILS and not d.off then
		d.off = true
		ns:Debug("Columns: %s failed %d times and is off until a reload (%s)", d.key, d.fails, tostring(err))
	end
end
function Columns:SortValue(key, rec)
	local d = self.defs[key]
	if not d or d.off or not d.sort or not rec then return 0 end
	local ok, v = pcall(d.sort, rec)
	if not ok then self:Failed(d, v) end
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

-- (1.12.0-beta5, the beta4 audit's B4-3) A column became able or unable to show (Pawn's advisor switched, Pawn
-- loading late): it leaves or joins the row, which is a layout change whatever the window is sorted by. The windows
-- are laid out again on the next frame (once, however often this is called in a frame), their narrowest width
-- follows (the column counts toward it only while it can show), and an open Bag Columns page is drawn again so its
-- row greys or comes back. Nothing saved changes.
function Columns:AvailabilityChanged(key)
	if not self.defs[key] or self.layoutQueued then return end
	self.layoutQueued = true
	local function go()
		Columns.layoutQueued = false
		if not ns.ready then return end
		for _, v in pairs(ns.views or {}) do if v.big and v.ApplyMinWidth then v:ApplyMinWidth() end end
		if ns.RefreshViews then ns:RefreshViews(true) end
		local P = ns.SettingsPanel
		if P and P.frame and P.frame:IsShown() and P.Refresh then P:Refresh() end
	end
	if C_Timer and C_Timer.After then C_Timer.After(0, go) else go() end
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

------------------------------------------------------------------------
-- (1.12.0-beta3) Columns from other addons: BagSmith.API 1.2
------------------------------------------------------------------------
-- No plugin registration is needed, as for an icon corner mark: an addon that already draws one can add a column in
-- a few lines.
--   RegisterColumn(label, id, onUpdate, options) -> true, or false if refused (said once in chat)
--     label     the heading's text, and the column's name in Settings (plain text, 40 characters at most)
--     id        letters, digits, _ - . (40 at most). The player's column lists save it as "x:<id>".
--     onUpdate(details) -> text, sortValue
--               details: the table a corner widget's onUpdate gets (Core/Corners.lua, C:DetailsFor): itemLink,
--               itemID, quality, itemLevel, isBound, itemCount, icon, isJunk, classID, subClassID, itemName, and,
--               for the player's own items, bagID, slotID and itemLocation.
--               text: a string; "" or false for an empty cell; nil for "not ready yet" (the cell keeps what it
--               showed for the same item and nothing is remembered: call RefreshColumn when you can answer).
--               sortValue: a number to sort by when the player clicks the heading (0 without one).
--     options   width (pixels, 30 to 400; 60 without one), align ("LEFT", the default, or "RIGHT"), tooltip (a
--               sentence for the heading's tooltip and the Settings row's), otherCharacters (true: also asked about
--               another character's saved items; without it those cells are empty and onUpdate isn't called)
--   RefreshColumn(id) -> true, or false for an id that isn't registered. Your answers changed: BagSmith forgets
--     what it kept for the column and asks again for the rows on screen. Any number of calls in one frame make one
--     redraw.
--   IsColumnShown(id) -> whether the player has it ticked, in the bags or the bank.
-- An answer is kept per item (its place, link and count) until RefreshColumn, so onUpdate runs once per item, not
-- once per redraw or per comparison in a sort. Each function accepts a dot or a colon call.
-- The column is listed in Settings > Bag Columns and Bank Columns, unticked, at the end; the player ticks, moves,
-- resizes and sorts by it like any other. It is never shown in Global Inventory.
Columns.MAX_ADDON = 8        -- columns from other addons, in all
Columns.CACHE_MAX = 4000     -- answers kept for one column before they are all forgotten and asked again
Columns.TEXT_MAX = 200       -- bytes of a cell's text kept (room for a color code or a small picture's markup)
Columns.ADDON_TIP = "Added by another addon."
local addonCount = 0
local refusedSaid = {}
local function refuse(id, why)
	local key = tostring(id) .. "|" .. why
	if ns.Debug then ns:Debug("RegisterColumn refused: %s", why) end
	if not refusedSaid[key] and ns.Print then
		refusedSaid[key] = true
		ns:Print("An addon's column (%s) couldn't be added to Bag Columns: %s.", type(id) == "string" and id ~= "" and id or "no id", why)
	end
	return false
end
local function cacheKey(rec)
	return (rec.cached and "o" or "") .. tostring(rec.bag) .. ":" .. tostring(rec.slot) .. ":" .. tostring(rec.link or rec.itemID) .. ":" .. tostring(rec.count or 1)
end
-- The addon's answer for one item, asked once and then kept: the text (nil for "not ready yet") and the sort value.
-- An error in onUpdate is the caller's pcall's (Columns:Value counts it; Columns:SortValue sorts the item as 0).
local function answer(d, rec)
	if rec.cached and not d.others then return "", 0 end
	local ck = cacheKey(rec)
	local hit = d.cache[ck]
	if hit then return hit[1], hit[2] end
	local details = (ns.Corners and ns.Corners.DetailsFor) and ns.Corners:DetailsFor(rec) or { itemLink = rec.link, itemID = rec.itemID }
	local text, sort = d.onUpdate(details)
	if text == nil then return nil, 0 end
	if text == false then text = "" end
	text = (tostring(text):gsub("%c", " "))
	if #text > Columns.TEXT_MAX then
		-- (1.12.0-beta5, the beta4 audit's advisory) cut between characters, never inside one: step back while the
		-- next byte is the middle of a UTF-8 character. (Markup cut in half shows as text: the docs ask for short markup.)
		local n = Columns.TEXT_MAX
		while n > 0 do
			local b = text:byte(n + 1)
			if b and b >= 128 and b < 192 then n = n - 1 else break end
		end
		text = text:sub(1, n)
	end
	sort = tonumber(sort)
	if not sort or sort ~= sort then sort = 0 end
	if d.cached >= Columns.CACHE_MAX then d.cache, d.cached = {}, 0 end
	d.cache[ck] = { text, sort }
	d.cached = d.cached + 1
	return text, sort
end

function Columns:RegisterAddon(label, id, onUpdate, options)
	if type(label) ~= "string" or label:match("^%s*$") or type(id) ~= "string" or id == "" or #id > 40 or not id:match("^[%w_%-%.]+$")
		or type(onUpdate) ~= "function" then
		return refuse(id, "it needs a label, an id (letters, digits, _ - .) and onUpdate")
	end
	local key = "x:" .. id
	if self.defs[key] then return refuse(id, ("%q is already registered"):format(id)) end
	if addonCount >= self.MAX_ADDON then return refuse(id, ("BagSmith takes %d columns from other addons, and already has them"):format(self.MAX_ADDON)) end
	options = type(options) == "table" and options or {}
	label = (label:gsub("[%c|]", " ")):sub(1, 40)
	local tip = type(options.tooltip) == "string" and options.tooltip ~= "" and (options.tooltip:gsub("%c", " ")):sub(1, 200) or self.ADDON_TIP
	local d
	if not self:Register(key, {
		label = label, owner = label, width = options.width, numeric = options.align == "RIGHT", tip = tip,
		text = function(rec) return (answer(d, rec)) end,
		sort = function(rec) local _, v = answer(d, rec); return v end,
	}) then return refuse(id, "BagSmith couldn't add it") end
	d = self.defs[key]
	d.addon, d.id, d.onUpdate, d.others, d.cache, d.cached = true, id, onUpdate, options.otherCharacters == true, {}, 0
	addonCount = addonCount + 1
	self:PlaceAddonColumns()
	if ns.db and ns.Fire then ns:Fire("SETTINGS_CHANGED", "colOrder") end   -- (an open Settings page and the windows follow)
	return true
end
-- A registered column that isn't in the profile's column orders yet joins them at the end, unticked. Nothing else
-- of the player's lists is touched: it isn't ticked, and it isn't added to Narrow Windows (a saved list there is the
-- player's). Run when one registers, when settings are ready and on every profile switch.
function Columns:PlaceAddonColumns()
	local db = ns.db
	if not db then return end
	for _, key in ipairs(self.keys) do
		if self.defs[key].addon then
			for _, name in ipairs({ "colOrder", "bankColOrder" }) do
				local list = db[name]
				if type(list) == "table" and not ns.IndexOf(list, key) then list[#list + 1] = key end
			end
		end
	end
end
function Columns:RefreshAddon(id)
	local d = type(id) == "string" and self.defs["x:" .. id] or nil
	if not (d and d.addon) then return false end
	d.cache, d.cached = {}, 0
	if d.refreshQueued then return true end
	d.refreshQueued = true
	local function go() d.refreshQueued = false; Columns:Changed(d.key) end
	if C_Timer and C_Timer.After then C_Timer.After(0, go) else go() end
	return true
end
function Columns:AddonShown(id)
	local key = type(id) == "string" and ("x:" .. id) or nil
	local db = ns.db
	if not (key and self.defs[key] and db) then return false end
	return (ns.IndexOf(db.cols or {}, key) or ns.IndexOf(db.bankCols or {}, key)) and true or false
end

local API = _G.BagSmith and _G.BagSmith.API
local function args(first, ...) if first == API then return ... end return first, ... end
if API then
	API.RegisterColumn = function(...) return Columns:RegisterAddon(args(...)) end
	API.RefreshColumn = function(...) return Columns:RefreshAddon((args(...))) end
	API.IsColumnShown = function(...) return Columns:AddonShown((args(...))) end
end
if ns.OnSignal then
	ns:OnSignal("ADDON_READY", function() Columns:PlaceAddonColumns() end)
	ns:OnSignal("PROFILE_ACTIVATED", function() Columns:PlaceAddonColumns() end)
end
