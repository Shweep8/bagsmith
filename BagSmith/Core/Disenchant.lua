local ADDON, ns = ...
--[[
	Disenchant Helper (1.2.0).

	A window that lists the gear in your bags worth considering, with three
	values per item (vendor, AH, and what its disenchant materials should be
	worth) and a verdict, then walks you through it one item at a time: the
	item at the top is armed on a secure button, you click it (or press the
	keybinding), the cast happens, the loot window shows the materials, and
	the next item comes up. Skip passes on an item for the session; Never
	keeps an item out for good.

	What it knows and where from:
	- Results (which materials, how likely, how many) come from a table shipped
	  here, per quality, item-level bracket and armor-or-weapon, the game's own
	  tables. Every cast's actual loot is recorded locally per bracket, and once
	  a bracket has enough of your own results (CALIBRATE_AT), those take over
	  for that bracket; the window says which it is using.
	- Prices come from the Auctionator data BagSmith already keeps (Core/AH.lua):
	  the item's own AH price on the "sell it" side, the materials' prices on the
	  "disenchant it" side. No Auctionator: dashes and the install note, and no
	  recommendation (vendor against vendor is rarely interesting). A material
	  with no price yet: "no price yet", naming it, with the scan hint.
	- Eligibility: bags only; weapons and armor; uncommon and rare, epics only by
	  setting; never favorites, gear-set pieces or items on the never list;
	  refundable and still-tradeable items skipped by setting; only what your
	  Enchanting skill can disenchant.

	Nothing is cast by this file: the cast is a secure action the player
	triggers. Attributes are set out of combat only, and a state driver blanks
	the button in combat.
]]
local DE = {}
ns.Disenchant = DE

DE.SPELL_ID = 13262            -- Disenchant
DE.CALIBRATE_AT = 20           -- your own results take over for a bracket from this many casts
DE.MIN_QUALITY = 2             -- uncommon
DE.W = 640
DE.MIN_W, DE.MIN_H = 620, 320   -- the six columns at their widths need 612 inside the window

-- Materials by item ID (the names come from the game when an item is known).
local M = {
	strangeDust = 10940, soulDust = 11083, visionDust = 11137, dreamDust = 11176, illusionDust = 16204,
	lesserMagic = 10938, greaterMagic = 10939, lesserAstral = 10998, greaterAstral = 11082,
	lesserMystic = 11134, greaterMystic = 11135, lesserNether = 11174, greaterNether = 11175,
	lesserEternal = 16202, greaterEternal = 16203,
	smallGlimmering = 10978, largeGlimmering = 11084, smallGlowing = 11138, largeGlowing = 11139,
	smallRadiant = 11177, largeRadiant = 11178, smallBrilliant = 14343, largeBrilliant = 14344,
	nexusCrystal = 20725,
}
DE.MATS = M

-- Uncommon brackets: dust (min, max), essence (min, max), shard. Armor favors dust, weapons favor essence.
-- Chances: the favored one 75%, the other 20%, the shard 5%.
DE.UNCOMMON = {
	{ 5, 15, M.strangeDust, 1, 2, M.lesserMagic, 1, 2, M.smallGlimmering },
	{ 16, 20, M.strangeDust, 2, 3, M.greaterMagic, 1, 2, M.smallGlimmering },
	{ 21, 25, M.strangeDust, 4, 6, M.greaterMagic, 2, 3, M.smallGlimmering },
	{ 26, 30, M.soulDust, 1, 2, M.lesserAstral, 1, 2, M.largeGlimmering },
	{ 31, 35, M.soulDust, 2, 5, M.greaterAstral, 1, 2, M.smallGlowing },
	{ 36, 40, M.visionDust, 1, 2, M.lesserMystic, 1, 2, M.largeGlowing },
	{ 41, 45, M.visionDust, 2, 5, M.greaterMystic, 1, 2, M.smallRadiant },
	{ 46, 50, M.dreamDust, 1, 2, M.lesserNether, 1, 2, M.largeRadiant },
	{ 51, 55, M.dreamDust, 2, 5, M.greaterNether, 1, 2, M.smallBrilliant },
	{ 56, 60, M.illusionDust, 1, 2, M.lesserEternal, 1, 2, M.largeBrilliant },
	{ 61, 99, M.illusionDust, 2, 5, M.greaterEternal, 1, 2, M.largeBrilliant },
}
-- Rare: one shard. Epic: the bracket's shard below 56, a Nexus Crystal from 56.
DE.SHARD = {
	{ 5, 25, M.smallGlimmering }, { 26, 30, M.largeGlimmering }, { 31, 35, M.smallGlowing }, { 36, 40, M.largeGlowing },
	{ 41, 45, M.smallRadiant }, { 46, 50, M.largeRadiant }, { 51, 55, M.smallBrilliant }, { 56, 99, M.largeBrilliant },
}
DE.EPIC_CRYSTAL_FROM = 56
-- Enchanting skill needed to disenchant, by item level.
DE.SKILL = { { 20, 1 }, { 25, 25 }, { 30, 50 }, { 35, 75 }, { 40, 100 }, { 45, 125 }, { 50, 150 }, { 55, 175 }, { 60, 200 }, { 99, 225 } }

local function bracket(list, ilvl)
	for i, b in ipairs(list) do if ilvl >= b[1] and ilvl <= b[2] then return i, b end end
end
function DE.SkillFor(ilvl) for _, s in ipairs(DE.SKILL) do if ilvl <= s[1] then return s[2] end end return 225 end
function DE.IsWeapon(rec) return rec.classID == 2 end
function DE.IsGear(rec) return rec.classID == 2 or rec.classID == 4 end

-- The shipped expectation: a list of { id, chance, min, max }, and the bracket key for the log.
function DE:Expectation(rec)
	if type(rec) ~= "table" then return nil end
	local q, ilvl = rec.quality or 0, rec.ilvl or 0
	if ilvl < 5 then ilvl = 5 end
	if q == 2 then
		local i, b = bracket(self.UNCOMMON, ilvl)
		if not b then return nil end
		local weapon = self.IsWeapon(rec)
		local out = {
			{ b[3], weapon and 0.20 or 0.75, b[4], b[5] },   -- dust
			{ b[6], weapon and 0.75 or 0.20, b[7], b[8] },   -- essence
			{ b[9], 0.05, 1, 1 },                             -- shard
		}
		return out, ("2:%d:%s"):format(i, weapon and "w" or "a")
	elseif q == 3 then
		local i, b = bracket(self.SHARD, ilvl)
		if not b then return nil end
		return { { b[3], 1, 1, 1 } }, ("3:%d"):format(i)
	elseif q == 4 then
		if ilvl >= self.EPIC_CRYSTAL_FROM then return { { M.nexusCrystal, 1, 1, 1 } }, "4:crystal" end
		local i, b = bracket(self.SHARD, ilvl)
		if not b then return nil end
		return { { b[3], 1, 1, 1 } }, ("4:%d"):format(i)
	end
	return nil
end

------------------------------------------------------------------------
-- Your own results
------------------------------------------------------------------------
DE.LOG_VERSION = 3   -- records written before the provenance rules (betas 5 to 10) or by beta12's double-counting window read are dropped once
function DE:Log()
	if not ns.cdb then return {} end
	if type(ns.cdb.deResults) ~= "table" then ns.cdb.deResults = {} end
	if (tonumber(ns.cdb.deResultsVersion) or 0) ~= self.LOG_VERSION then
		if next(ns.cdb.deResults) then ns:Print("Disenchant Helper: the learned results from the beta builds were cleared (they could include loot that was not the helper's); estimates start from the typical results again.") end
		ns.cdb.deResults = {}
		ns.cdb.deResultsVersion = self.LOG_VERSION
	end
	return ns.cdb.deResults
end
-- Record one cast's loot (a list of { id, count }) against its bracket key.
function DE:Record(key, loot)
	if not key then return end
	local log = self:Log()
	local e = log[key]
	if type(e) ~= "table" then e = { n = 0, mats = {} }; log[key] = e end
	e.n = (e.n or 0) + 1
	e.seen = e.seen or {}
	for _, l in ipairs(loot or {}) do
		if l.id and (l.count or 0) > 0 then e.mats[l.id] = (e.mats[l.id] or 0) + l.count; e.seen[l.id] = (e.seen[l.id] or 0) + 1 end
	end
	ns:Debug("Disenchant Helper: recorded cast %d for bracket %s (%d material%s)", e.n, key, #(loot or {}), #(loot or {}) == 1 and "" or "s")
end
-- One material arriving for the cast already counted under its key (the loot chat reports them one line at a time).
function DE:RecordMaterial(key, id, count)
	if not (key and id) then return end
	local e = self:Log()[key]
	if type(e) ~= "table" then return end
	e.seen = e.seen or {}
	e.mats[id] = (e.mats[id] or 0) + (count or 1)
	e.seen[id] = (e.seen[id] or 0) + 1
	ns:Debug("Disenchant Helper: %s x%d from the cast under bracket %s", self.MatName(id), count or 1, key)
end
DE.LOOT_WINDOW = 5   -- seconds after a cast during which loot lines belong to it (closed sooner by the loot window closing or the item leaving)
-- Only disenchant materials are ever attributed to a cast: a pickup that happens to land in the window is not.
local MATERIAL = {}
for _, id in pairs(M) do MATERIAL[id] = true end
DE.MATERIAL = MATERIAL
-- One tally per cast, whichever source reports first: a second report of the same material adds only what
-- exceeds the first (the loot chat and the loot window describe the same materials).
function DE:Tally(c, id, count, source)
	if not (c and id and MATERIAL[id]) then return false end
	if c.allowed and not c.allowed[id] then return false end   -- not a material this cast can produce
	count = tonumber(count) or 1
	-- the chat reports receipts, which add up (two lines of 1 and 2 are 3); the loot window reports a snapshot of
	-- what it holds, and the game may show the same window more than once (LOOT_READY, then LOOT_OPENED), so a
	-- window read replaces: the largest snapshot seen stands. The recorded amount is the larger source's total,
	-- since the two describe the same loot.
	c.bySource = c.bySource or { chat = {}, window = {} }
	if source == "window" then c.bySource.window[id] = math.max(c.bySource.window[id] or 0, count)
	else c.bySource.chat[id] = (c.bySource.chat[id] or 0) + count end
	count = math.max(c.bySource.chat[id] or 0, c.bySource.window[id] or 0)
	c.tally = c.tally or {}
	local prev = c.tally[id] or 0
	if count <= prev then return false end
	local delta = count - prev
	local e = self:Log()[c.key]
	if type(e) == "table" then
		e.seen = e.seen or {}
		e.mats[id] = (e.mats[id] or 0) + delta
		if prev == 0 then e.seen[id] = (e.seen[id] or 0) + 1 end
	end
	self.session = self.session or { done = 0, mats = {} }
	self.session.mats[id] = (self.session.mats[id] or 0) + delta
	c.tally[id] = count
	ns:Debug("Disenchant Helper: %s x%d from the cast under bracket %s", self.MatName(id), delta, c.key)
	return true
end
function DE:CloseCast(why) if self.castOpen then ns:Debug("Disenchant Helper: attribution closed (%s)", why or "done"); self.castOpen = nil end end
-- The loot chat's own patterns, built from the game's strings ("You receive loot: %s." and "...%sx%d.").
local lootPatterns
local function buildLootPatterns()
	lootPatterns = {}
	local function pat(fmt, multi)
		if type(fmt) ~= "string" then return end
		local p = fmt:gsub("%%", "%%%%"):gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
		p = p:gsub("%.$", "%%.?")
		lootPatterns[#lootPatterns + 1] = { "^" .. p, multi }
	end
	pat(LOOT_ITEM_SELF_MULTIPLE, true); pat(LOOT_ITEM_PUSHED_SELF_MULTIPLE, true)
	pat(LOOT_ITEM_SELF, false); pat(LOOT_ITEM_PUSHED_SELF, false)
end
function DE.ParseLootLine(msg)
	if not lootPatterns then buildLootPatterns() end
	for _, p in ipairs(lootPatterns) do
		local link, count = msg:match(p[1])
		if link then
			local id = tonumber(link:match("item:(%d+)"))
			if id then return id, p[2] and tonumber(count) or 1 end
		end
	end
end
function DE:OnLootChat(msg)
	local c = self.castOpen
	if not (c and msg) then return end
	if (GetTime() - c.at) > self.LOOT_WINDOW then self:CloseCast("window passed"); return end
	local id, count = self.ParseLootLine(msg)
	if not id then return end
	if not MATERIAL[id] then return end   -- somebody else's loot, or a pickup: not the cast's
	if self:Tally(c, id, count, "chat") and self.frame and self.frame:IsShown() then self:Paint() end
end
-- Expected quantity of each material per cast: the shipped chances, or your own averages once a bracket
-- has enough casts. Returns a list of { id, perCast } and "estimate" or "yours" with the count.
function DE:Expected(rec)
	local shipped, key = self:Expectation(rec)
	if not shipped then return nil end
	local e = key and self:Log()[key]
	if type(e) == "table" and (e.n or 0) >= self.CALIBRATE_AT then
		local out = {}
		for id, total in pairs(e.mats or {}) do out[#out + 1] = { id, total / e.n, seen = (e.seen and e.seen[id]) or 0 } end
		table.sort(out, function(a, b) return a[2] > b[2] end)
		return out, "yours", e.n, key
	end
	local out = {}
	for _, m in ipairs(shipped) do out[#out + 1] = { m[1], m[2] * (m[3] + m[4]) / 2, chance = m[2], min = m[3], max = m[4] } end
	return out, "estimate", type(e) == "table" and e.n or 0, key
end

------------------------------------------------------------------------
-- Prices and verdicts
------------------------------------------------------------------------
local function itemInfo(id) if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(id) end return GetItemInfo and GetItemInfo(id) end
function DE.MatName(id) local name = itemInfo(id); return name or ("item " .. tostring(id)) end
function DE.Money(v) if ns.Money then local s = ns.Money(v); if s ~= "" then return s end end return (GetCoinTextureString and GetCoinTextureString(v)) or tostring(v) end

-- Per material: the AH price, or nil. The materials' value is nil when any price is missing (and which).
function DE:MatsValue(rec)
	local list, basis, n, key = self:Expected(rec)
	if not list then return nil, "no-table" end
	if not (ns.AH and ns.AH:Available()) then return nil, "no-auctionator" end
	local total, missing = 0, nil
	for _, m in ipairs(list) do
		local p = ns.AH:Price({ itemID = m[1], link = "item:" .. m[1] })
		if not p then missing = missing or m[1]
		else total = total + p * m[2] end
	end
	if missing then return nil, "no-price", missing, basis, n end
	return math.floor(total + 0.5), nil, nil, basis, n
end

-- The recommendation for an entry: "de", "ah" (the AH is the better sale), "vendor", "unknown" (a material's
-- price is missing), "call" (no Auctionator: nothing to compare against).
function DE:Verdict(entry)
	local margin = (ns.db and tonumber(ns.db.deMargin)) or 0.10
	if not (ns.AH and ns.AH:Available()) then return "call" end
	if entry.mats == nil then return "unknown" end
	local vendor, ah = entry.vendor or 0, entry.ah or 0
	local best = math.max(vendor, ah)
	if entry.mats >= best * (1 + margin) and entry.mats > 0 then return "de" end
	if ah > vendor then return "ah" end
	return "vendor"
end
DE.VERDICT_TEXT = { de = "Disenchant", ah = "Sell at AH", vendor = "Vendor", sell = "Sell", unknown = "No price yet", call = "Your call" }
-- One line per material: a range and rough odds from the shipped table, or your own averages and how often
-- the material showed up. The heading says which it is.
function DE:LikelyLines(rec)
	local list, basis, n = self:Expected(rec)
	if not list then return nil end
	local lines = {}
	for _, m in ipairs(list) do
		if basis == "yours" then
			lines[#lines + 1] = ("%s: %.1f per cast, in %d of %d"):format(self.MatName(m[1]), m[2], m.seen or 0, n)
		else
			local qty = m.min == m.max and tostring(m.min) or ("%d to %d"):format(m.min, m.max)
			lines[#lines + 1] = ("%s: %s, about %d%%"):format(self.MatName(m[1]), qty, math.floor(m.chance * 100 + 0.5))
		end
	end
	local head = basis == "yours" and ("from %d of your results"):format(n) or ("DE estimate, %d of %d of your disenchants"):format(n or 0, self.CALIBRATE_AT)
	return lines, head, basis, n
end

------------------------------------------------------------------------
-- Eligibility
------------------------------------------------------------------------
function DE:Never()
	if not ns.cdb then return {} end
	if type(ns.cdb.deNever) ~= "table" then ns.cdb.deNever = {} end
	return ns.cdb.deNever
end
function DE:NeverList()
	local out = {}
	for id in pairs(self:Never()) do out[#out + 1] = { id = id, name = (itemInfo(id)) or ("Item " .. id) } end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end
function DE:Unnever(id)
	self:Never()[id] = nil
	if self.frame and self.frame:IsShown() then self:Refresh() end
	self:RefreshNeverWindow()
	if ns.SettingsPanel and ns.SettingsPanel.frame and ns.SettingsPanel.frame:IsShown() then ns.SettingsPanel:Refresh() end
end
local NW, NROW = 300, 24
function DE:NeverWindow()
	local f = self.neverFrame
	if f then return f end
	f = CreateFrame("Frame", "BagSmithDisenchantNever", UIParent, "BackdropTemplate")
	f:SetSize(NW, 360); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true)
	if f.SetToplevel then f:SetToplevel(true) end
	f.closeX = ns.IconButton(f, "Interface\\AddOns\\BagSmith\\Media\\ui-close.tga", "Close", function() f:Hide() end)
	f.closeX:SetSize(18, 18); f.closeX:SetPoint("TOPRIGHT", -10, -10)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	f:SetMovable(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", 12, -12); f.title:SetText("DE Exclusion List")
	f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
	f.sub:SetWidth(NW - 24); f.sub:SetJustifyH("LEFT")
	f.search = CreateFrame("EditBox", "BagSmithDisenchantNeverSearch", f, "SearchBoxTemplate")
	f.search:SetSize(NW - 32, 22); f.search:SetAutoFocus(false); f.search:SetPoint("TOPLEFT", 18, -58)
	f.search:SetScript("OnTextChanged", function(box) if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(box) end; DE:RefreshNeverWindow() end)
	f.search:SetScript("OnEscapePressed", function(box) box:SetText(""); box:ClearFocus() end)
	f.scroll = CreateFrame("ScrollFrame", "BagSmithDisenchantNeverScroll", f, "UIPanelScrollFrameTemplate")
	f.scroll:SetPoint("TOPLEFT", 10, -88); f.scroll:SetPoint("BOTTOMRIGHT", -30, 44)
	f.child = CreateFrame("Frame", nil, f.scroll); f.child:SetSize(NW - 44, 1); f.scroll:SetScrollChild(f.child)
	f.rows = {}
	f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.empty:SetPoint("TOPLEFT", 16, -96)
	f.empty:SetWidth(NW - 32); f.empty:SetJustifyH("LEFT")
	f.close = ns.TextButton(f, "Close", 70, function() f:Hide() end); f.close:SetHeight(22); f.close:SetPoint("BOTTOMRIGHT", -12, 12)
	f.classicSpec = ns.Classic.DialogSpec(f, { hide = { f.closeX }, restore = function() ns.Skins:ApplyBackdrop(f); local s = ns.Skins:Current(); f:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1) end })
	ns.Skins:Register(f, function(fr)
		ns.Skins:ApplyBackdrop(fr); local s = ns.Skins:Current(); fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)
		fr.title:SetTextColor(unpack(s.heading)); fr.sub:SetTextColor(unpack(s.muted)); fr.empty:SetTextColor(unpack(s.muted))
		ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
	end)
	f:Hide()
	ns:CloseOnEscape(f, function() f:Hide() end)   -- (1.5.4) Escape closes it like its Close button
	ns:CombatWindow(f)   -- (1.5.6) fades in combat like the bags window
	self.neverFrame = f
	return f
end
local function neverRow(f, i)
	local r = f.rows[i]
	if r then return r end
	r = CreateFrame("Frame", nil, f.child); r:SetSize(NW - 44, NROW - 2)
	r:EnableMouse(true)
	r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT", 2, 0)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.name:SetPoint("RIGHT", -28, 0); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
	r.remove = ns.IconButton(r, "Interface\\AddOns\\BagSmith\\Media\\ui-close.tga", "Remove from your DE Exclusion List", function(b) DE:Unnever(b:GetParent().id) end)
	r.remove:SetSize(16, 16); r.remove:SetPoint("RIGHT", -4, 0)
	r:SetScript("OnEnter", function(self) if self.id and ns.TooltipsOK() then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. self.id); GameTooltip:Show() end end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.rows[i] = r
	return r
end
function DE:RefreshNeverWindow()
	local f = self.neverFrame
	if not (f and f:IsShown()) then return end
	local all = self:NeverList()
	local text = (f.search:GetText() or ""):lower()
	local list = {}
	for _, e in ipairs(all) do if text == "" or e.name:lower():find(text, 1, true) then list[#list + 1] = e end end
	f.sub:SetText(#all == 1 and "1 item on your DE Exclusion List." or ("%d items on your DE Exclusion List."):format(#all))
	for i, e in ipairs(list) do
		local r = neverRow(f, i)
		r.id = e.id
		local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id)) or (C_Item and C_Item.GetItemInfoInstant and select(5, C_Item.GetItemInfoInstant(e.id)))
		r.icon:SetTexture(icon)
		r.name:SetText(e.name); r.name:SetTextColor(unpack(ns.Skins:Current().text))
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", f.child, "TOPLEFT", 0, -(i - 1) * NROW); r:Show()
	end
	for i = #list + 1, #f.rows do f.rows[i]:Hide() end
	f.child:SetHeight(math.max(1, #list * NROW))
	f.empty:SetShown(#list == 0)
	f.empty:SetText(#all == 0 and "Your DE Exclusion List is empty. Use Exclude in the helper to add items." or "No items match.")
end
function DE:ManageNever()
	local f = self:NeverWindow()
	f.search:SetText("")
	f:Show()
	self:RefreshNeverWindow()
end
function DE:ClearNever() local t = self:Never(); for id in pairs(t) do t[id] = nil end; if self.frame and self.frame:IsShown() then self:Refresh() end; self:RefreshNeverWindow() end

function DE:Known()
	if type(IsSpellKnown) == "function" then local ok, v = pcall(IsSpellKnown, self.SPELL_ID); if ok then return v == true end end
	if type(IsPlayerSpell) == "function" then local ok, v = pcall(IsPlayerSpell, self.SPELL_ID); if ok then return v == true end end
	return false
end
-- (1.5.3) The skill line's name as the game spells it in the player's language: the Enchanting profession spell's
-- name (Apprentice, Journeyman, Expert, Artisan), from C_Spell or GetSpellInfo; English as the last resort. It was
-- only the English name, so on a game in another language the skill was never found.
DE.PROFESSION_SPELL_IDS = { 7411, 7412, 7413, 13920 }
local function professionNames()
	local names = {}
	for _, id in ipairs(DE.PROFESSION_SPELL_IDS) do
		local n
		if C_Spell and type(C_Spell.GetSpellName) == "function" then local ok, v = pcall(C_Spell.GetSpellName, id); if ok then n = v end end
		if not n and type(GetSpellInfo) == "function" then local ok, v = pcall(GetSpellInfo, id); if ok then n = v end end
		if type(n) == "string" and n ~= "" then names[n] = true end
	end
	names["Enchanting"] = true
	return names
end
-- The character's Enchanting skill, or nil when the client cannot say (then no item is held back for skill).
function DE:Skill()
	if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then return nil end
	local ok, n = pcall(GetNumSkillLines)
	if not ok then return nil end
	local names = professionNames()
	for i = 1, (n or 0) do
		local ok2, name, header, _, rank = pcall(GetSkillLineInfo, i)
		if ok2 and not header and name and names[name] then return tonumber(rank) end
	end
	return nil
end
-- Returns whether the item can still be returned to a vendor, and a second value that is true when the
-- client could not say (a thrown call); a client without the API answers "no, known".
local function refundable(rec)
	local C = C_Container
	if not (C and type(C.GetContainerItemPurchaseInfo) == "function") then return false, false end
	local ok, money, itemCount, refundSec = pcall(C.GetContainerItemPurchaseInfo, rec.bag, rec.slot, false)
	if not ok then return false, true end
	return (tonumber(refundSec) or 0) > 0, false
end
local scanTip
local function tradeable(rec)
	if not (BIND_TRADE_TIME_REMAINING and CreateFrame and GameTooltip) then return false end
	if not scanTip then
		scanTip = CreateFrame("GameTooltip", "BagSmithDEScanTooltip", UIParent, "GameTooltipTemplate")
		scanTip:SetOwner(UIParent, "ANCHOR_NONE")
	end
	if type(scanTip.SetBagItem) ~= "function" then return false end
	scanTip:ClearLines()
	local ok = pcall(scanTip.SetBagItem, scanTip, rec.bag, rec.slot)
	if not ok then return false, true end   -- the tooltip could not be read: unknown
	local pattern = BIND_TRADE_TIME_REMAINING:gsub("%%s", ".+")
	for i = 1, scanTip:NumLines() do
		local line = _G["BagSmithDEScanTooltipTextLeft" .. i]
		local text = line and line:GetText()
		if text and text:find(pattern) then return true end
	end
	return false
end
DE.Refundable, DE.Tradeable = refundable, tradeable

-- The armed entry against the live bag and the character's marks right now: the same item in the same slot,
-- not a favorite, not in a gear set, not on the never list, still the kind the helper handles. Returns true,
-- or false and why. Anything the client cannot answer is a no.
function DE:LiveCheck(entry)
	if not entry then return false, "nothing is armed" end
	local C = C_Container
	if not (C and type(C.GetContainerItemInfo) == "function") then return false, "the bag could not be read" end
	local ok, info = pcall(C.GetContainerItemInfo, entry.bag, entry.slot)
	if not ok or type(info) ~= "table" then return false, "the slot could not be read" end
	if info.itemID ~= entry.itemID then return false, "that slot holds a different item now" end
	-- the same item ID is not the same item: where the client gives instances, the armed one must match the one in
	-- the slot now; a record without an instance, or a slot whose instance cannot be read, cannot be identified
	if C_Item and C_Item.GetItemGUID and ItemLocation then
		local okG, guid = pcall(function() local loc = ItemLocation:CreateFromBagAndSlot(entry.bag, entry.slot); if loc and C_Item.DoesItemExist(loc) then return C_Item.GetItemGUID(loc) end end)
		if not okG or guid == nil then return false, "that item could not be identified" end
		if not (entry.rec and entry.rec.guid) then return false, "that item could not be identified" end
		if guid ~= entry.rec.guid then return false, "that slot holds another copy of the item now" end
	end
	if info.isLocked then return false, "that item is locked right now" end
	if self:Never()[entry.itemID] then return false, "that item is on your DE Exclusion List" end
	if ns.Marks and ns.Marks:IsFavorite(entry.itemID) then return false, "that item is a favorite now" end
	if ns.GearSets and ns.GearSets:Available() then
		local okS, setsAt, unreadable = pcall(function() return ns.GearSets:SetsAt(entry.bag, entry.slot) end)
		if not okS or unreadable then return false, "gear sets could not be checked" end
		if setsAt and #setsAt > 0 then return false, "that item is in a gear set now" end
	end
	if entry.rec and not self.IsGear(entry.rec) then return false, "that item is not weapon or armor" end
	-- the same gates the list applies, against the live slot; a read that fails is unknown, and unknown is a no
	if ns.db and ns.db.deSkipRefundable ~= false then
		local live = { bag = entry.bag, slot = entry.slot }
		local isRefundable, unknownR = refundable(live)
		if unknownR then return false, "whether that item is refundable could not be checked" end
		if isRefundable then return false, "that item is refundable now" end
		local isTradeable, unknownT = tradeable(live)
		if unknownT then return false, "whether that item is tradeable could not be checked" end
		if isTradeable then return false, "that item is still tradeable" end
	end
	return true
end
-- Why an item is in or out. Returns true, or false and a short reason.
function DE:Eligible(rec, skill)
	if not rec or rec.empty or rec.cached then return false, "not here" end
	if type(rec.bag) ~= "number" or rec.bag < 0 or rec.bag > 4 then return false, "not in your bags" end
	if not self.IsGear(rec) then return false, "not weapon or armor" end
	local q = rec.quality or 0
	if q < self.MIN_QUALITY then return false, "common" end
	if q >= 4 and not (ns.db and ns.db.deIncludeEpics) then return false, "epic" end
	if q > 4 then return false, "legendary" end
	if (rec.ilvl or 0) < 5 then return false, "no item level" end
	if self:Never()[rec.itemID] then return false, "never" end
	if ns.Marks and rec.itemID and ns.Marks:IsFavorite(rec.itemID) then return false, "favorite" end
	if rec.gearSets then return false, "gear set" end
	if skill and self.SkillFor(rec.ilvl) > skill then return false, "skill" end
	if ns.db and ns.db.deSkipRefundable ~= false then
		if refundable(rec) then return false, "refundable" end
		if tradeable(rec) then return false, "tradeable" end
	end
	return true
end

-- Every eligible item in the bags, with its values and verdict, best disenchant first.
-- Eligible's reasons that mean "held back" (an item that would otherwise be considered), in the shared words.
DE.HELD = { never = "deExcluded", favorite = "favorite", ["gear set"] = "gearset", skill = "skill", refundable = "refundable", tradeable = "tradeable", epic = "epic" }
function DE:Entries()
	local out = {}
	local skill = self:Skill()
	local items = ns.items or {}
	self.held = ns.Why:New()
	for _, rec in ipairs(items) do
		if not (self.skipped and self.skipped[rec.guid or (rec.bag .. ":" .. rec.slot)]) then
			local ok, why = self:Eligible(rec, skill)
			if not ok and self.HELD[why] then ns.Why:Add(self.held, self.HELD[why], rec.name) end
			if ok then
				local e = { rec = rec, bag = rec.bag, slot = rec.slot, itemID = rec.itemID, name = rec.name, link = rec.link, quality = rec.quality, ilvl = rec.ilvl }
				e.vendor = (rec.sellPrice or 0) * (rec.count or 1)
				if ns.AH and ns.AH:Available() then e.ah = ns.AH:Price(rec) end
				local mats, why, missing, basis, n = self:MatsValue(rec)
				e.mats, e.matsWhy, e.missing, e.basis, e.n = mats, why, missing, basis, n
				e.verdict = self:Verdict(e)
				out[#out + 1] = e
			end
		end
	end
	local order = { de = 1, unknown = 2, call = 3, ah = 4, vendor = 5 }
	table.sort(out, function(a, b)
		if order[a.verdict] ~= order[b.verdict] then return order[a.verdict] < order[b.verdict] end
		return (a.mats or 0) > (b.mats or 0)
	end)
	return out
end

------------------------------------------------------------------------
-- The secure button and the cast
------------------------------------------------------------------------
-- Built once, inside the window's item panel (so the skins dress it with its neighbors); the keybinding's
-- CLICK target exists from the first time the helper is opened.
function DE:Button(parent)
	if self.button then return self.button end
	local b = ns.TextButton(parent or self:Frame().cur, "Disenchant", 140, nil, "SecureActionButtonTemplate, SecureHandlerStateTemplate", "BagSmithDisenchantButton")
	b:SetHeight(24)
	b.tip = "Disenchant this item"
	if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
	-- (1.5.3) By the spell's ID, which the game understands in every language. It was the name, from GetSpellInfo
	-- or else the English "Disenchant"; this client has no GetSpellInfo, so a game in any other language was asked
	-- for a spell it doesn't know by that name, and the button silently did nothing (a player's report).
	b:SetAttribute("spell", self.SPELL_ID)
	-- In combat the button does nothing, by the game's own state driver. (1.4.0-beta6, the beta5 audit's P1: the
	-- states were "1" and "0", which the game's driver hands over as numbers, so the old check for the text "1" never
	-- matched and combat armed the button.) The states are words now, and the snippet only ever disarms: anything but
	-- "open" clears the action and its target. Re-arming happens only from the helper's own refresh once combat ends,
	-- so no stale target comes back. If the driver can't be registered, the button never arms (DE:Arm checks).
	DE.combatGuard = false
	if b.SetAttribute and RegisterStateDriver then
		-- (1.5.6) and it hides the button in combat (a secure snippet may; addon code may not), so a helper closed in combat
		-- as far as the player can tell leaves nothing clickable behind; after combat it shows again if it was shown
		b:SetAttribute("_onstate-bscombat", [[ if newstate ~= "open" then self:SetAttribute("type", nil); self:SetAttribute("target-bag", nil); self:SetAttribute("target-slot", nil); self:SetAttribute("target-item", nil); if not self:GetAttribute("bs-locked") then self:SetAttribute("bs-locked", true); self:SetAttribute("bs-wasShown", self:IsShown() and true or false) end; self:Hide() elseif self:GetAttribute("bs-locked") then self:SetAttribute("bs-locked", nil); if self:GetAttribute("bs-wasShown") then self:Show() end end ]])
		DE.combatGuard = pcall(RegisterStateDriver, b, "bscombat", "[combat] lock; open") and true or false
	end
	-- Before the click commits: the slot must still hold the armed item, and it must still be eligible by what the
	-- game and the character's marks say right now. If not, the click is disarmed (attributes may change out of
	-- combat) and the list refreshed. Fail closed: a check that cannot be made disarms too.
	b:SetScript("PreClick", function()
		if InCombatLockdown and InCombatLockdown() then return end   -- attributes are frozen; the state driver blanked the button
		local okNow, why = DE:LiveCheck(DE.current)
		if not okNow then
			-- disarm this click; the list is re-judged on the next frame, never inside the click (re-arming here would
			-- hand this very click to another item)
			b:SetAttribute("type", nil)
			DE.current = nil
			DE.lastDisarm = why
			ns:Print("Disenchant Helper: %s; the list was refreshed.", why or "that item changed")
			DE.castingEntry = nil
			local f = C_Timer and C_Timer.After or function(_, fn) fn() end
			f(0, function() if DE.frame and DE.frame:IsShown() then DE:Refresh() end end)
			return
		end
		if ns.MarkAction then ns.MarkAction("disenchant") end
		DE.castingEntry = DE.current
	end)
	b:SetScript("PostClick", function() if DE.lastDisarm then DE.lastDisarm = nil end end)
	self.button = b
	return b
end
-- Arm the button for an entry (out of combat only); nil disarms it.
function DE:Arm(entry)
	local b = self:Button()
	if InCombatLockdown and InCombatLockdown() then self.armPending = entry; return false end
	self.armPending = nil
	-- no combat guard, no arming: without it a click in combat would skip the checks (fail closed, 1.4.0-beta6)
	if entry and not self.combatGuard then
		if not self.warnedGuard then
			self.warnedGuard = true
			ns:Print("Disenchant Helper: this game client wouldn't let BagSmith guard the Disenchant button in combat, so it stays off.")
		end
		entry = nil
	end
	if entry then
		b:SetAttribute("type", "spell")
		b:SetAttribute("target-bag", entry.bag)
		b:SetAttribute("target-slot", entry.slot)
		b:SetAttribute("target-item", ("%d %d"):format(entry.bag, entry.slot))
		b:Enable(); b:Show(); if b.SetActive then b:SetActive(false) end
	else
		b:SetAttribute("type", nil)
		b:SetAttribute("target-bag", nil); b:SetAttribute("target-slot", nil); b:SetAttribute("target-item", nil)
		b:Disable(); if b.SetActive then b:SetActive(false) end
	end
	self.current = entry
	return true
end

-- Events around a cast: success records the loot, the loot window closing refreshes the list.
-- A cast succeeded: count it under its bracket now; the materials follow by loot chat (or the loot window)
-- within the next few seconds. Nothing waits on them: the item leaving its slot moves the list on.
function DE:OnSpellSucceeded(unit, spellID)
	if unit ~= "player" or tonumber(spellID) ~= self.SPELL_ID then return end
	local e = self.castingEntry
	if not e then return end
	local key = select(4, self:Expected(e.rec))
	self:Record(key, {})
	-- the materials this bracket can produce: anything else arriving in the window is not the cast's
	local allowed = {}
	local shipped = self:Expectation(e.rec)
	for _, m in ipairs(shipped or {}) do allowed[m[1]] = true end
	self.castOpen = { key = key, entry = e, at = GetTime(), allowed = next(allowed) and allowed or nil }
	self.castingEntry = nil
	self.done = (self.done or 0) + 1
	self.session = self.session or { done = 0, mats = {} }
	self.session.done = self.session.done + 1
end
-- The loot window, for players with auto-loot off: its slots are the same materials, tallied once per cast.
function DE:OnLootOpened()
	local c = self.castOpen
	if not c or (GetTime() - c.at) > self.LOOT_WINDOW then return end
	local n = (GetNumLootItems and GetNumLootItems()) or 0
	local sums = {}   -- a material in two slots is one count
	for i = 1, n do
		local link = GetLootSlotLink and GetLootSlotLink(i)
		local id = link and tonumber(link:match("item:(%d+)"))
		local qty
		if GetLootSlotInfo then local _, _, q = GetLootSlotInfo(i); qty = q end
		if id and MATERIAL[id] then sums[id] = (sums[id] or 0) + (tonumber(qty) or 1) end
	end
	for id, total in pairs(sums) do self:Tally(c, id, total, "window") end
end
-- The loot window closing ends the cast's attribution: nothing after it is the cast's.
function DE:OnLootClosed()
	self:CloseCast("loot closed")
	if self.frame and self.frame:IsShown() then self:Refresh() end
end
function DE:OnCastFailed(unit, spellID)
	if unit ~= "player" or tonumber(spellID) ~= self.SPELL_ID then return end
	self.castingEntry = nil
	if self.frame and self.frame:IsShown() then self:Refresh() end
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------
local W, ROW = DE.W, 22
-- Re-anchors a frame to the screen at the spot it occupies now (its corner, in screen coordinates).
function DE.ToScreen(f)
	if not (f and f.GetLeft and f.GetTop) then return end
	local left, top = f:GetLeft(), f:GetTop()
	if not (left and top) then return end
	local w, h = f:GetWidth(), f:GetHeight()
	-- the frame's edges are in its own scale; the anchor to UIParent is in UIParent's (equal unless the frame is scaled)
	local fs, us = f.GetEffectiveScale and f:GetEffectiveScale() or 1, UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
	if fs ~= us and us > 0 then local k = fs / us; left, top = left * k, top * k end
	f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top); f:SetSize(w, h)
end
-- Column layout from the window's width: the item name takes what the money columns leave.
local COLS = { { "", 0, 14 }, { "Item", 18, nil }, { "Vendor", nil, 104 }, { "AH", nil, 104 }, { "Mats (DE est.)", nil, 110 }, { "Rec. Action", nil, 86 } }
function DE:Columns(width)
	local inner = width - 44
	local fixed = 14 + 104 + 104 + 110 + 86 + (#COLS - 1) * 6   -- the fixed columns and the gaps between all six
	local nameW = math.max(120, inner - fixed)
	local out, x = {}, 0
	for i, c in ipairs(COLS) do
		local w = c[3] or nameW
		out[i] = { c[1], x, w }
		x = x + w + 6
	end
	return out
end
function DE:Frame()
	local f = self.frame
	if f then return f end
	f = CreateFrame("Frame", "BagSmithDisenchant", UIParent, "BackdropTemplate")
	f:SetSize(W, 440); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
	-- (1.5.6) The secure Disenchant button inside makes this window protected (Shweep, in game: IsProtected), and in combat
	-- the game won't let an addon hide a protected window or change its mouse. So the window takes no clicks itself: its
	-- catcher, BagSmith's own frame under every button, takes its empty space and dragging, and can be switched off in
	-- combat when the window is closed as far as the player can tell (DE:Close).
	f:EnableMouse(false)
	f.bsCatcher = CreateFrame("Frame", nil, f)
	f.bsCatcher:SetAllPoints(f); f.bsCatcher:SetFrameLevel(f:GetFrameLevel()); f.bsCatcher:EnableMouse(true)
	f.bsCatcher:RegisterForDrag("LeftButton")
	f.bsCatcher:SetScript("OnDragStart", function() local own = f:GetScript("OnDragStart"); if own then own(f) end end)
	f.bsCatcher:SetScript("OnDragStop", function() local own = f:GetScript("OnDragStop"); if own then own(f) end end)
	if f.SetToplevel then f:SetToplevel(true) end   -- above the bags window, and forward when clicked, like Settings
	-- the corner X (Modern; the Classic chrome brings its own)
	f.closeX = ns.IconButton(f, "Interface\\AddOns\\BagSmith\\Media\\ui-close.tga", "Close", function() DE:Close() end)
	f.closeX:SetSize(18, 18); f.closeX:SetPoint("TOPRIGHT", -10, -10)
	f:SetMovable(true); f:RegisterForDrag("LeftButton")
	-- a frame anchored to another frame leaps when moved or sized: it is put on the screen first, at its own spot
	f:SetScript("OnDragStart", function(self) DE.ToScreen(self); self:StartMoving() end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, rel, x, yy = self:GetPoint(1)
		if point then ns.db.dePos = { point, "UIParent", rel or point, math.floor(x + 0.5), math.floor(yy + 0.5) } end
	end)
	-- resizable, the size remembered
	if f.SetResizable then f:SetResizable(true) end
	if f.SetResizeBounds then f:SetResizeBounds(self.MIN_W, self.MIN_H) elseif f.SetMinResize then f:SetMinResize(self.MIN_W, self.MIN_H) end
	f.grip = CreateFrame("Button", nil, f); f.grip:SetSize(16, 16); f.grip:SetPoint("BOTTOMRIGHT", -4, 4)
	f.grip.tex = f.grip:CreateTexture(nil, "OVERLAY"); f.grip.tex:SetAllPoints(); f.grip.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	f.grip:SetScript("OnMouseDown", function() DE.ToScreen(f); if f.StartSizing then f:StartSizing("BOTTOMRIGHT") end end)
	f.grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); ns.db.deSize = { math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5) }; DE:Layout(); DE:Paint() end)
	f:SetScript("OnSizeChanged", function() if f:IsShown() then DE:Layout() end end)
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", 12, -12); f.title:SetText("Disenchant Helper")
	f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
	f.sub:SetJustifyH("LEFT"); f.sub:SetWordWrap(true)
	-- beside the count: how many items the list holds back, and why on hover (1.3.0)
	f.heldLine = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.heldLine:Hide()
	f.heldInfo = ns.Why.InfoButton(f); f.heldInfo:Hide()
	-- the current item: icon, name, values, the recommendation; one row of buttons beneath
	f.cur = CreateFrame("Frame", nil, f); f.cur:SetHeight(84); f.cur:SetPoint("TOPLEFT", 12, -56); f.cur:SetPoint("TOPRIGHT", -12, -56)
	f.cur.icon = f.cur:CreateTexture(nil, "ARTWORK"); f.cur.icon:SetSize(40, 40); f.cur.icon:SetPoint("TOPLEFT", 0, -2)
	f.cur.name = f.cur:CreateFontString(nil, "OVERLAY", "GameFontNormal"); f.cur.name:SetPoint("TOPLEFT", f.cur.icon, "TOPRIGHT", 8, 0); f.cur.name:SetPoint("RIGHT", f.cur, "RIGHT", 0, 0); f.cur.name:SetJustifyH("LEFT")
	f.cur.values = f.cur:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.cur.values:SetPoint("TOPLEFT", f.cur.name, "BOTTOMLEFT", 0, -3); f.cur.values:SetPoint("RIGHT", f.cur, "RIGHT", 0, 0); f.cur.values:SetJustifyH("LEFT")
	f.cur.verdict = f.cur:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.cur.verdict:SetPoint("TOPLEFT", f.cur.values, "BOTTOMLEFT", 0, -3); f.cur.verdict:SetPoint("RIGHT", f.cur, "RIGHT", 0, 0); f.cur.verdict:SetJustifyH("LEFT")
	-- the right half: the likely results, a thin rule between the halves
	f.cur.rule = f.cur:CreateTexture(nil, "ARTWORK"); f.cur.rule:SetWidth(1); f.cur.rule:SetPoint("TOP", f.cur, "TOP", 0, 0); f.cur.rule:SetPoint("BOTTOM", f.cur, "BOTTOM", 0, 0); f.cur.rule:SetColorTexture(1, 1, 1, 0.15)
	f.cur.likelyHead = f.cur:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); f.cur.likelyHead:SetPoint("TOPLEFT", f.cur.rule, "TOPRIGHT", 10, -2); f.cur.likelyHead:SetPoint("RIGHT", f.cur, "RIGHT", 0, 0); f.cur.likelyHead:SetJustifyH("LEFT")
	f.cur.likely = f.cur:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.cur.likely:SetPoint("TOPLEFT", f.cur.likelyHead, "BOTTOMLEFT", 0, -2); f.cur.likely:SetPoint("RIGHT", f.cur, "RIGHT", 0, 0); f.cur.likely:SetJustifyH("LEFT"); f.cur.likely:SetJustifyV("TOP"); f.cur.likely:SetWordWrap(true)
	if f.cur.likely.SetFont and f.cur.likely.GetFont then local font, _, flags = f.cur.likely:GetFont(); if font then f.cur.likely:SetFont(font, 10, flags) end end
	-- the basis on its own short line at the bottom of the box, never wrapping
	f.cur.basis = f.cur:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.cur.basis:SetPoint("BOTTOMLEFT", f.cur.rule, "BOTTOMRIGHT", 10, 2); f.cur.basis:SetPoint("RIGHT", f.cur, "RIGHT", 0, 0); f.cur.basis:SetJustifyH("LEFT"); f.cur.basis:SetWordWrap(false)
	if f.cur.basis.SetFont and f.cur.basis.GetFont then local font, _, flags = f.cur.basis:GetFont(); if font then f.cur.basis:SetFont(font, 10, flags) end end
	local b = self:Button(f.cur)
	b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", f.cur, "BOTTOMLEFT", 0, 0)
	f.skip = ns.TextButton(f.cur, "Skip", 66, function() DE:Skip() end); f.skip:SetHeight(24); f.skip:SetPoint("LEFT", b, "RIGHT", 6, 0)
	f.skip.tip = "Pass on it for now"
	f.never = ns.TextButton(f.cur, "Exclude", 70, function() DE:NeverCurrent() end); f.never:SetHeight(24); f.never:SetPoint("LEFT", f.skip, "RIGHT", 6, 0)
	f.never.tip = "Add it to your DE Exclusion List"
	f.junk = ns.TextButton(f.cur, "Mark as Junk", 110, function() DE:JunkCurrent() end); f.junk:SetHeight(24); f.junk:SetPoint("LEFT", f.never, "RIGHT", 6, 0)
	f.junk.tip = "Mark it as junk"
	-- the list: a selection dot, the item, three values, the recommendation
	f.heads = {}
	for i = 1, #COLS do
		local h = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); h:SetJustifyH("LEFT")
		f.heads[i] = h
	end
	f.rows = {}
	f.scroll = CreateFrame("ScrollFrame", "BagSmithDisenchantScroll", f, "UIPanelScrollFrameTemplate")
	f.child = CreateFrame("Frame", nil, f.scroll); f.child:SetSize(W - 44, 10); f.scroll:SetScrollChild(f.child)
	f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.status:SetPoint("BOTTOMLEFT", 12, 36); f.status:SetWidth(W - 24); f.status:SetJustifyH("LEFT"); f.status:SetWordWrap(true)
	f.close = ns.TextButton(f, "Close", 70, function() DE:Close() end); f.close:SetHeight(22); f.close:SetPoint("BOTTOMRIGHT", -12, 10)
	-- consider skipped items again: a small undo arrow at the top right, only while something is skipped
	f.refresh = ns.IconButton(f, "Interface\\AddOns\\BagSmith\\Media\\ui-undo.tga", "Consider skipped items again", function() DE:ClearSkipped() end)
	f.refresh:SetSize(18, 18); f.refresh:SetPoint("RIGHT", f.closeX, "LEFT", -6, 0); f.refresh:Hide()
	-- the empty state: the icon, a headline and one line, in the middle of the list area
	f.empty = CreateFrame("Frame", nil, f); f.empty:SetPoint("TOPLEFT", 12, -56); f.empty:SetPoint("BOTTOMRIGHT", -12, 44); f.empty:Hide()
	f.empty.icon = f.empty:CreateTexture(nil, "ARTWORK"); f.empty.icon:SetSize(64, 64); f.empty.icon:SetPoint("CENTER", f.empty, "CENTER", 0, 60); f.empty.icon:SetTexture("Interface\\AddOns\\BagSmith\\Media\\ui-disenchant-large.tga"); f.empty.icon:SetAlpha(0.6)
	f.empty.head = f.empty:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.empty.head:SetPoint("TOP", f.empty.icon, "BOTTOM", 0, -10)
	-- the body in pieces: the count, the haul one material per line, the value in gold, then what was set aside
	f.empty.count = f.empty:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); f.empty.count:SetPoint("TOP", f.empty.head, "BOTTOM", 0, -8); f.empty.count:SetWidth(400); f.empty.count:SetJustifyH("CENTER"); f.empty.count:SetWordWrap(true)
	f.empty.haul = f.empty:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.empty.haul:SetPoint("TOP", f.empty.count, "BOTTOM", 0, -6); f.empty.haul:SetWidth(400); f.empty.haul:SetJustifyH("CENTER"); f.empty.haul:SetWordWrap(true)
	f.empty.value = f.empty:CreateFontString(nil, "OVERLAY", "GameFontNormal"); f.empty.value:SetPoint("TOP", f.empty.haul, "BOTTOM", 0, -8); f.empty.value:SetWidth(400); f.empty.value:SetJustifyH("CENTER")
	f.empty.line = f.empty:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.empty.line:SetPoint("TOP", f.empty.value, "BOTTOM", 0, -16); f.empty.line:SetWidth(360); f.empty.line:SetJustifyH("CENTER"); f.empty.line:SetWordWrap(true)
	f.empty.skipped = ns.TextButton(f.empty, "Consider skipped again", 160, function() DE:ClearSkipped() end); f.empty.skipped:SetHeight(22); f.empty.skipped:SetPoint("TOP", f.empty.line, "BOTTOM", 0, -10); f.empty.skipped:Hide()
	f.empty.held = f.empty:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.empty.held:Hide()
	f.empty.heldInfo = ns.Why.InfoButton(f.empty); f.empty.heldInfo:Hide()
	f.empty.never = ns.TextButton(f.empty, "DE Exclusion List...", 140, function() DE:ManageNever() end); f.empty.never:SetHeight(22); f.empty.never:Hide()
	-- the footer: what the mats values are, centered beside Close
	-- centered on the window itself, like the title and the card (the line is short enough to clear Close)
	f.footer = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.footer:SetPoint("BOTTOMLEFT", 12, 13); f.footer:SetPoint("BOTTOMRIGHT", -12, 13); f.footer:SetJustifyH("CENTER")
	f.footer:SetText("Mats are DE estimates that improve as you disenchant."); f.footer:SetWordWrap(false)
	f.classicSpec = ns.Classic.DialogSpec(f, { hide = { f.closeX }, close = function() DE:Close() end, restore = function() ns.Skins:ApplyBackdrop(f); local s = ns.Skins:Current(); f:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1) end })
	ns.Skins:Register(f, function(fr)
		ns.Skins:ApplyBackdrop(fr); local s = ns.Skins:Current(); fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)
		fr.title:SetTextColor(unpack(s.heading)); fr.sub:SetTextColor(unpack(s.muted)); fr.status:SetTextColor(unpack(s.muted)); fr.footer:SetTextColor(unpack(s.muted))
		fr.empty.head:SetTextColor(unpack(s.heading)); fr.empty.line:SetTextColor(unpack(s.muted))
		do local ar, ag, ab = ns.Skins:Accent(); fr.empty.icon:SetVertexColor(ar, ag, ab) end   -- the art, tinted with the accent
		fr.empty.count:SetTextColor(unpack(s.text)); fr.empty.haul:SetTextColor(unpack(s.muted)); fr.empty.value:SetTextColor(unpack(s.heading))
		fr.cur.likelyHead:SetTextColor(unpack(s.heading)); fr.cur.likely:SetTextColor(unpack(s.muted)); fr.cur.basis:SetTextColor(unpack(s.muted))
		for _, h in ipairs(fr.heads) do h:SetTextColor(unpack(s.heading)) end
		ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
		if ns.Classic.DressScrollBar then ns.Classic:DressScrollBar(fr.scroll, ns.Classic.IsOn()) end
	end)
	f:SetScript("OnHide", function()
		DE:Arm(nil)
		if DE.session and (DE.session.done or 0) > 0 then
			local skipped = DE:SkippedCount()
			ns:Print("Disenchant Helper: %s%s", DE:SessionSummary(), skipped > 0 and (" %d skipped."):format(skipped) or "")
			DE.sessionClosed = true
		end
		if ns.Window and ns.Window.main and ns.Window.main.RefreshToolbar then ns.Window.main:RefreshToolbar() end
	end)
	f:SetScript("OnShow", function()
		-- a new sitting after one that disenchanted something starts its counts over
		if DE.sessionClosed then DE.session = nil; DE.done = nil; DE.sessionClosed = nil end
		if f.Raise then f:Raise() end
		DE:Layout(); DE:Refresh()
		if ns.Window and ns.Window.main and ns.Window.main.RefreshToolbar then ns.Window.main:RefreshToolbar() end
	end)
	f:Hide()
	-- (1.5.4) Escape closes it like its Close button. (1.5.6) In combat too, as far as the player can tell (DE:Close), and
	-- it fades in combat like the bags window.
	ns:CloseOnEscape(f, function() DE:Close() end)
	ns:CombatWindow(f)
	f:HookScript("OnHide", function() DE:AfterClose() end)
	self.frame = f
	self:Layout()
	return f
end
-- Places the headers under the button row and sizes the columns to the window.
function DE:Layout()
	local f = self.frame
	if not f then return end
	local width = f:GetWidth() or W
	f.sub:SetWidth(width - 24)
	-- the rule splits the item panel: the left half holds the item and its buttons (at least 330 px), the right the likely results
	local leftW = math.max(330, math.floor((width - 24) * 0.55))
	f.cur.rule:ClearAllPoints(); f.cur.rule:SetPoint("TOP", f.cur, "TOPLEFT", leftW, 0); f.cur.rule:SetPoint("BOTTOM", f.cur, "BOTTOMLEFT", leftW, 0)
	f.cur.name:SetWidth(leftW - 48 - 8); f.cur.values:SetWidth(leftW - 48 - 8); f.cur.verdict:SetWidth(leftW - 48 - 8)
	f.status:SetWidth(width - 24)
	local cols = self:Columns(width)
	f.cols = cols
	local headY = -(56 + 84 + 10)
	for i, c in ipairs(cols) do
		local h = f.heads[i]
		h:ClearAllPoints(); h:SetPoint("TOPLEFT", 12 + c[2], headY); h:SetText(c[1]); h:SetWidth(c[3])
	end
	f.scroll:ClearAllPoints(); f.scroll:SetPoint("TOPLEFT", 12, headY - 16); f.scroll:SetPoint("BOTTOMRIGHT", -30, 56)
	f.child:SetWidth(width - 44)
	for _, r in ipairs(f.rows) do
		r:SetWidth(width - 44)
		for c, t in ipairs(r.cells) do t:ClearAllPoints(); t:SetPoint("LEFT", cols[c][2], 0); t:SetWidth(cols[c][3]) end
	end
end

local function row(f, i)
	local r = f.rows[i]
	if r then return r end
	r = CreateFrame("Button", nil, f.child); r:SetSize((f:GetWidth() or W) - 44, ROW)
	r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
	r.cells = {}
	for c = 1, #f.cols do
		local t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); t:SetPoint("LEFT", f.cols[c][2], 0); t:SetWidth(f.cols[c][3]); t:SetJustifyH("LEFT")
		t:SetWordWrap(false)   -- a value too long for its column is cut, never wrapped onto a second line
		r.cells[c] = t
	end
	-- the selection dot in the first column: a radio-style ring, filled on the selected row
	r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetSize(12, 12); r.dot:SetPoint("LEFT", 1, 0)
	r.dot:SetTexture("Interface\\Buttons\\UI-RadioButton"); r.dot:SetTexCoord(0, 0.25, 0, 1)
	r.dotFill = r:CreateTexture(nil, "OVERLAY"); r.dotFill:SetSize(12, 12); r.dotFill:SetPoint("LEFT", 1, 0)
	r.dotFill:SetTexture("Interface\\Buttons\\UI-RadioButton"); r.dotFill:SetTexCoord(0.25, 0.5, 0, 1); r.dotFill:Hide()
	r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 1, 1, 0.08); r.hl:Hide()
	r:SetScript("OnClick", function(self) if self.entry then DE:Select(self.entry) end end)
	r:SetScript("OnEnter", function(self) DE:RowTip(self) end)
	r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	f.rows[i] = r
	return r
end

local function qcolor(q)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end
-- The wording for a missing price: one message everywhere.
DE.NO_AUCTIONATOR = "Install Auctionator to enable this column. It shows prices from Auctionator's last auction house scan."
function DE.NoPriceTip(what)
	return ("Auctionator has no price for %s yet. Open the Auction House and run an Auctionator scan, or search for it there, and BagSmith will pick the price up."):format(what or "this item")
end
function DE:RowTip(r)
	local e = r.entry
	if not (e and GameTooltip) then return end
	GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	if e.link then GameTooltip:SetHyperlink(e.link) else GameTooltip:AddLine(e.name or "") end
	GameTooltip:AddLine(" ")
	if not (ns.AH and ns.AH:Available()) then GameTooltip:AddLine(self.NO_AUCTIONATOR, 0.8, 0.8, 0.8, true)
	elseif e.matsWhy == "no-price" then GameTooltip:AddLine(self.NoPriceTip(self.MatName(e.missing)), 0.8, 0.8, 0.8, true)
	elseif e.ah == nil then GameTooltip:AddLine(self.NoPriceTip(e.name), 0.8, 0.8, 0.8, true) end
	local lines, head = self:LikelyLines(e.rec)
	if lines then
		GameTooltip:AddLine(("Likely results (%s):"):format(head), 1, 0.82, 0)
		for _, l in ipairs(lines) do GameTooltip:AddLine(l, 0.9, 0.9, 0.9) end
	end
	GameTooltip:Show()
end

function DE:Select(entry)
	self:Arm(entry)
	self:Paint()
end
function DE:Skip()
	if not self.current then return end
	self.skipped = self.skipped or {}
	self.skipped[self.current.rec.guid or (self.current.bag .. ":" .. self.current.slot)] = true
	self:Refresh()
end
function DE:NeverCurrent()
	if not self.current then return end
	self:Never()[self.current.itemID] = true
	self:Refresh()
end
function DE:JunkCurrent()
	if not (self.current and ns.Junk) then return end
	if not ns.Junk:Marked(self.current.itemID) then ns.Junk:Toggle(self.current.rec) end
	self:Refresh()
end

function DE:ValueText(v, kind, e)
	if kind == "ah" then
		if not (ns.AH and ns.AH:Available()) then return "-" end
		return v and self.Money(v) or "no price yet"
	elseif kind == "mats" then
		if not (ns.AH and ns.AH:Available()) then return "-" end
		if v == nil then return e and e.matsWhy == "no-price" and "no price yet" or "-" end
		return self.Money(v)
	end
	return (v or 0) > 0 and self.Money(v) or "-"
end

-- How many items are skipped this session, and how many the never list holds.
function DE:SkippedCount() local n = 0; for _ in pairs(self.skipped or {}) do n = n + 1 end return n end
function DE:NeverCount() local n = 0; for _ in pairs(self:Never()) do n = n + 1 end return n end
function DE:ClearSkipped() self.skipped = {}; if self.frame and self.frame:IsShown() then self:Refresh() end end
-- The sitting's haul in pieces for the card: the count line, the materials one per line, the value line.
function DE:SessionPieces()
	local s = self.session or { done = self.done or 0, mats = {} }
	local list = {}
	for id, count in pairs(s.mats or {}) do list[#list + 1] = { id = id, count = count } end
	table.sort(list, function(a, b) return a.count > b.count end)
	local names, value, priced = {}, 0, true
	for _, m in ipairs(list) do
		names[#names + 1] = ("%s x%d"):format(self.MatName(m.id), m.count)
		local p = ns.AH and ns.AH:Available() and ns.AH:Price({ itemID = m.id, link = "item:" .. m.id })
		if p then value = value + p * m.count else priced = false end
	end
	return {
		count = ("%d %s disenchanted"):format(s.done or 0, (s.done or 0) == 1 and "item" or "items"),
		haul = table.concat(names, "\n"),
		value = (#names > 0 and priced and value > 0) and ("Worth about %s at current AH prices"):format(self.Money(value)) or "",
	}
end
-- What this sitting produced in one line: items, each material with its count, and their AH value when known.
function DE:SessionSummary()
	local s = self.session or { done = self.done or 0, mats = {} }
	local parts = { ("%d %s disenchanted"):format(s.done or 0, (s.done or 0) == 1 and "item" or "items") }
	local list = {}
	for id, count in pairs(s.mats or {}) do list[#list + 1] = { id = id, count = count } end
	table.sort(list, function(a, b) return a.count > b.count end)
	local names, value, priced = {}, 0, true
	for _, m in ipairs(list) do
		names[#names + 1] = ("%s x%d"):format(self.MatName(m.id), m.count)
		local p = ns.AH and ns.AH:Available() and ns.AH:Price({ itemID = m.id, link = "item:" .. m.id })
		if p then value = value + p * m.count else priced = false end
	end
	if #names > 0 then parts[#parts + 1] = table.concat(names, ", ") end
	if #names > 0 and priced and value > 0 then parts[#parts + 1] = ("worth about %s at current AH prices"):format(self.Money(value)) end
	return table.concat(parts, ". ") .. "."
end
-- The empty state's words: why there is nothing, and what can bring something back.
function DE:EmptyWords()
	local known, skill = self:Known(), self:Skill()
	if not known then return "This character can't disenchant.", "Disenchant comes with the Enchanting profession." end
	local skipped, never = self:SkippedCount(), self:NeverCount()
	local parts = {}
	if skipped > 0 then parts[#parts + 1] = ("%d skipped this session"):format(skipped) end
	if never > 0 then parts[#parts + 1] = ("%d on your DE Exclusion List"):format(never) end
	local rest = #parts > 0 and (table.concat(parts, ", ") .. ".") or nil
	if (self.done or 0) > 0 then
		-- the haul leads whenever anything was disenchanted; what was set aside follows, apart from it
		return rest and "Done for now." or "All done.", rest or "", self:SessionPieces()
	end
	if rest then return "Nothing left to consider.", rest end
	-- items held back by skill, if any
	local heldBack, need = 0, nil
	for _, rec in ipairs(ns.items or {}) do
		if self.IsGear(rec) and (rec.quality or 0) >= self.MIN_QUALITY and skill and self.SkillFor(rec.ilvl or 0) > skill then heldBack = heldBack + 1; need = math.max(need or 0, self.SkillFor(rec.ilvl or 0)) end
	end
	if heldBack > 0 then return "Nothing you can disenchant yet.", ("%d %s need%s more Enchanting skill than %d."):format(heldBack, heldBack == 1 and "item" or "items", heldBack == 1 and "s" or "", skill) end
	return "Nothing to disenchant.", "Your bags hold no weapons or armor worth considering right now."
end
function DE:Paint()
	local f = self:Frame()
	local entries = self.entries or {}
	local cur = self.current
	local ahOn = ns.AH and ns.AH:Available()
	-- nothing to consider: the empty card instead of the panel, headers and list
	local empty = #entries == 0
	f.empty:SetShown(empty)
	for _, h in ipairs(f.heads) do h:SetShown(not empty) end
	f.scroll:SetShown(not empty)
	if empty then
		f.cur:Hide()
		for _, r in ipairs(f.rows) do r:Hide() end
		local head, line, pieces = self:EmptyWords()
		f.empty.head:SetText(head); f.empty.line:SetText(line or "")
		f.empty.count:SetText(pieces and pieces.count or ""); f.empty.haul:SetText(pieces and pieces.haul or ""); f.empty.value:SetText(pieces and pieces.value or "")
		-- without a haul the set-aside line sits right under the headline
		f.empty.line:ClearAllPoints()
		if pieces then f.empty.line:SetPoint("TOP", (pieces.value ~= "" and f.empty.value) or (pieces.haul ~= "" and f.empty.haul) or f.empty.count, "BOTTOM", 0, -16)
		else f.empty.line:SetPoint("TOP", f.empty.head, "BOTTOM", 0, -6) end
		f.sub:Hide()
		local heldN = self.held and self.held.total or 0
		f.empty.held:SetShown(heldN > 0); f.empty.heldInfo:SetShown(heldN > 0)
		local below = f.empty.line
		if heldN > 0 then
			f.empty.held:ClearAllPoints(); f.empty.held:SetPoint("TOP", f.empty.line, "BOTTOM", 0, -8)
			f.empty.held:SetText(("%d held back"):format(heldN))
			f.empty.heldInfo:ClearAllPoints(); f.empty.heldInfo:SetPoint("LEFT", f.empty.held, "RIGHT", 4, 0)
			below = f.empty.held
		end
		local skipped, never = self:SkippedCount(), self:NeverCount()
		f.empty.skipped:SetShown(skipped > 0)
		f.empty.never:SetShown(never > 0)
		f.empty.never:ClearAllPoints()
		if skipped > 0 then f.empty.never:SetPoint("LEFT", f.empty.skipped, "RIGHT", 6, 0) else f.empty.never:SetPoint("TOP", below, "BOTTOM", 0, -10) end
		if skipped > 0 and never > 0 then f.empty.skipped:ClearAllPoints(); f.empty.skipped:SetPoint("TOP", below, "BOTTOM", -58, -10) elseif skipped > 0 then f.empty.skipped:ClearAllPoints(); f.empty.skipped:SetPoint("TOP", below, "BOTTOM", 0, -10) end
	end
	local skippedNow = self:SkippedCount()
	f.refresh:SetShown(skippedNow > 0)
	f.refresh.tip = ("Consider skipped items again (%d skipped this session)"):format(skippedNow)
	-- the current item
	if cur then
		f.cur:Show()
		f.cur.icon:SetTexture(cur.rec.icon)
		f.cur.name:SetText(cur.name or ""); f.cur.name:SetTextColor(qcolor(cur.quality))
		f.cur.values:SetText(("Vendor %s   AH %s   Mats %s"):format(self:ValueText(cur.vendor, "vendor"), self:ValueText(cur.ah, "ah", cur), self:ValueText(cur.mats, "mats", cur)))
		local vt = self.VERDICT_TEXT[cur.verdict] or ""
		if cur.basis then vt = vt .. (cur.basis == "yours" and ("  (from %d of your results)"):format(cur.n or 0) or "  (DE estimate)") end
		if cur.verdict == "unknown" and cur.missing then vt = ("No price yet for %s"):format(self.MatName(cur.missing)) end
		f.cur.verdict:SetText(vt)
		local lines, head = self:LikelyLines(cur.rec)
		f.cur.likelyHead:SetText("Likely results")
		f.cur.likely:SetText(lines and table.concat(lines, "\n") or "No table for this item.")
		f.cur.basis:SetText(head and (head:sub(1, 1):upper() .. head:sub(2)) or "")
		f.cur.rule:Show(); f.cur.likelyHead:Show(); f.cur.likely:Show(); f.cur.basis:Show()
		f.junk:SetShown(cur.verdict == "vendor" and ns.Junk ~= nil and not ns.Junk:Marked(cur.itemID))   -- never a nudge toward junking something the AH pays for
	else
		f.cur:Hide()
	end
	-- the list
	for i, e in ipairs(entries) do
		local r = row(f, i)
		r.entry = e
		r.cells[1]:SetText("")
		r.cells[2]:SetText(e.name or ""); r.cells[2]:SetTextColor(qcolor(e.quality))
		r.cells[3]:SetText(self:ValueText(e.vendor, "vendor"))
		r.cells[4]:SetText(self:ValueText(e.ah, "ah", e))
		r.cells[5]:SetText(self:ValueText(e.mats, "mats", e))
		r.cells[6]:SetText(self.VERDICT_TEXT[e.verdict] or "")
		r.hl:SetShown(e == cur); r.dotFill:SetShown(e == cur)
		r:Show()
	end
	for i = #entries + 1, #f.rows do f.rows[i]:Hide() end
	f.child:SetHeight(math.max(10, #entries * ROW))
	-- the words at the top and bottom
	local known, skill = self:Known(), self:Skill()
	f.sub:SetShown(not empty)
	if not known then
		f.sub:SetText("This character cannot disenchant (the Disenchant ability comes with Enchanting).")
	else
		f.sub:SetText(("%d %s to consider.%s"):format(#entries, #entries == 1 and "item" or "items", skill and ("  Enchanting skill %d."):format(skill) or ""))
	end
	local heldN = self.held and self.held.total or 0
	f.heldLine:SetShown(heldN > 0 and not empty); f.heldInfo:SetShown(heldN > 0 and not empty)
	if heldN > 0 then
		f.heldLine:ClearAllPoints(); f.heldLine:SetPoint("LEFT", f.sub, "LEFT", (f.sub:GetStringWidth() or 120) + 10, 0)
		f.heldLine:SetText(("%d held back"):format(heldN))
		f.heldInfo:ClearAllPoints(); f.heldInfo:SetPoint("LEFT", f.heldLine, "LEFT", (f.heldLine:GetStringWidth() or 60) + 4, 0)
		f.heldInfo.title = "Not offered"; f.heldInfo.lines = ns.Why:Lines(self.held)
		f.empty.heldInfo.title = "Not offered"; f.empty.heldInfo.lines = f.heldInfo.lines
	end
	local notes = {}
	if empty then f.status:SetText(""); f.status:Hide(); return end
	if not ahOn then notes[#notes + 1] = "AH prices need Auctionator; without it the helper compares against vendor prices only and makes no recommendation." end
	if GetCVar and (GetCVar("autoLootDefault") == "0" or GetCVar("autoLootDefault") == nil) then notes[#notes + 1] = "Auto Loot is off: after each cast, take the materials from the loot window before the next item is ready." end
	if self.done and self.done > 0 then notes[#notes + 1] = ("%d disenchanted this session."):format(self.done) end
	f.status:SetText(table.concat(notes, "  "))
	f.status:SetShown(#notes > 0)
end

function DE:Refresh()
	local f = self:Frame()
	self.entries = self:Entries()
	-- the current item: keep it if it is still there, else the first
	local keep
	if self.current then
		for _, e in ipairs(self.entries) do if e.bag == self.current.bag and e.slot == self.current.slot and e.itemID == self.current.itemID then keep = e end end
	end
	self:Arm(keep or self.entries[1])
	self:Paint()
end

function DE:Show()
	if not (ns.db and ns.db.deEnabled) then ns:Print("Turn on the Disenchant Helper in Settings > Automations & Actions first."); return end
	-- (1.5.6) closed in combat as far as the player can tell, and wanted again: it comes back as it was
	if self.frame and self.frame.bsSoftClosed then self:Restore(); return end
	-- in combat the game won't let a protected window be shown or moved: it doesn't open (or move) until combat ends
	if InCombatLockdown() then
		if not (self.frame and self.frame:IsShown()) then ns:Print("The Disenchant Helper can't open during combat.") end
		return
	end
	local f = self:Frame()
	f:ClearAllPoints()
	local size = ns.db.deSize
	if type(size) == "table" and tonumber(size[1]) and tonumber(size[2]) then f:SetSize(math.max(self.MIN_W, size[1]), math.max(self.MIN_H, size[2])) end
	local pos = ns.db.dePos
	if type(pos) == "table" and pos[1] then f:SetPoint(pos[1], UIParent, pos[3] or pos[1], pos[4] or 0, pos[5] or 0)
	else
		-- beside the bags window when it is open: to its left with a gap, or its right when there is no room
		-- beside the bags window, in screen coordinates (never anchored to the bags window itself: a frame anchored to
		-- another frame leaps when it is dragged or sized)
		local main = ns.Window and ns.Window.main and ns.Window.main.frame
		local mLeft, mTop, mRight = main and main:IsShown() and main.GetLeft and main:GetLeft(), main and main.GetTop and main:GetTop(), main and main.GetRight and main:GetRight()
		-- GetLeft and friends answer in the bags window's own scale; the helper hangs on UIParent at its scale
		if mLeft and mTop and mRight then
			local ms = main.GetEffectiveScale and main:GetEffectiveScale() or 1
			local hs = f.GetEffectiveScale and f:GetEffectiveScale() or 1
			if ms ~= hs and hs > 0 then local k = ms / hs; mLeft, mTop, mRight = mLeft * k, mTop * k, mRight * k end
		end
		if mLeft and mTop and mRight then
			local gap, w = 12, f:GetWidth()
			if mLeft - gap - w >= 0 then f:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", mLeft - gap, mTop)
			else f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", mRight + gap, mTop) end
		else f:SetPoint("CENTER", UIParent, "CENTER", 0, 60) end
	end
	self.skipped = self.skipped or {}
	f:Show()
	self:Refresh()
end
function DE:Toggle() if self.frame and self.frame:IsShown() and not self.frame.bsSoftClosed then self:Close() else self:Show() end end

-- (1.5.6) Closing the helper. Its secure Disenchant button makes the window protected, and in combat the game won't let an
-- addon hide it (Shweep: it couldn't be closed in combat). So in combat it closes as far as the player can tell: fully
-- see-through, its click shield off, everything clickable that BagSmith owns switched off (the window takes no clicks
-- itself, see DE:Frame), the Disenchant button already hidden by its combat guard; it finishes closing when combat ends.
-- A helper the game doesn't count as protected just closes.
local function eachChild(f, fn) for _, c in ipairs({ f:GetChildren() }) do fn(c); eachChild(c, fn) end end
local function setMouse(f, on)
	eachChild(f, function(c)
		if c.IsProtected and c:IsProtected() then return end   -- (the secure button: its guard hides it in combat)
		if not on then
			if not c.bsMouseOff and c.EnableMouse then
				c.bsMouseWas = not c.IsMouseEnabled or c:IsMouseEnabled()
				c.bsMouseOff = true; c:EnableMouse(false)
			end
		elseif c.bsMouseOff then
			c.bsMouseOff = nil; c:EnableMouse(c.bsMouseWas ~= false)
		end
	end)
end
local function syncEscape(f, shown)
	local p = f.bsEscape
	if p then p.syncing = true; p:SetShown(shown); p.syncing = nil end
end
function DE:Close()
	local f = self.frame
	if not (f and f:IsShown()) or f.bsSoftClosed then return end
	if InCombatLockdown() and f.IsProtected and f:IsProtected() then
		f.bsSoftClosed = true
		f:SetAlpha(0)
		if f.bsShield then f.bsShield:Hide() end
		setMouse(f, false)
		syncEscape(f, false)
		ns:Safely("de:close", function() DE:FinishClose() end)
		return
	end
	f:Hide()
end
-- after combat: really hide it (then AfterClose makes it whole again for next time)
function DE:FinishClose() local f = self.frame; if f and f.bsSoftClosed and f:IsShown() then f:Hide() end end
function DE:AfterClose()
	local f = self.frame
	if f and f.bsSoftClosed and not f:IsShown() then
		f.bsSoftClosed = nil
		f:SetAlpha(1)
		setMouse(f, true)
	end
end
-- wanted again before combat ended: as it was, faded like the other windows, Escape working again
function DE:Restore()
	local f = self.frame
	if not (f and f.bsSoftClosed) then return end
	f.bsSoftClosed = nil
	ns:Safely("de:close", function() end)   -- the close waiting for combat's end is called off
	setMouse(f, true)
	ns:ApplyCombatFade(InCombatLockdown())
	syncEscape(f, true)
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
ns:OnSignal("ADDON_READY", function()
	ns:On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID) DE:OnSpellSucceeded(unit, spellID) end)
	ns:On("UNIT_SPELLCAST_FAILED", function(unit, _, spellID) DE:OnCastFailed(unit, spellID) end)
	ns:On("UNIT_SPELLCAST_INTERRUPTED", function(unit, _, spellID) DE:OnCastFailed(unit, spellID) end)
	ns:On("LOOT_OPENED", function() DE:OnLootOpened() end)
	ns:On("LOOT_READY", function() DE:OnLootOpened() end)
	ns:On("LOOT_CLOSED", function() DE:OnLootClosed() end)
	ns:On("CHAT_MSG_LOOT", function(msg) DE:OnLootChat(msg) end)
	ns:On("SKILL_LINES_CHANGED", function() if DE.frame and DE.frame:IsShown() then DE:Refresh() end end)
	-- a favorite or a gear set changing re-judges the list at once (the armed item included)
	ns:On("EQUIPMENT_SETS_CHANGED", function() if DE.frame and DE.frame:IsShown() then ns:NextFrame("de:sets", function() DE:Refresh() end) end end)
	-- the list follows the scanner's own word that the bags changed (the raw bag event precedes the rescan); it never waits on loot
	ns:OnSignal("ITEMS_CHANGED", function()
		local c = DE.castOpen
		if c and c.entry then
			local C = C_Container
			local info = C and C.GetContainerItemInfo and C.GetContainerItemInfo(c.entry.bag, c.entry.slot)
			if not (type(info) == "table" and info.itemID == c.entry.itemID) then
				-- the item is gone: give its loot lines one more second, then close
				local f = C_Timer and C_Timer.After or function(_, fn) fn() end
				f(1, function() if DE.castOpen == c then DE:CloseCast("item gone") end end)
			end
		end
		if DE.frame and DE.frame:IsShown() then DE:Refresh() end
	end)
	-- combat over: re-arm from a fresh look (the state driver only disarms) (1.4.0-beta6: also when something was armed)
	ns:On("PLAYER_REGEN_ENABLED", function() if DE.armPending ~= nil or DE.current ~= nil or (DE.frame and DE.frame:IsShown()) then DE:Refresh() end end)
end)
ns:OnSignal("SETTINGS_CHANGED", function(key)
	if (key == nil or key == "deMargin" or key == "deIncludeEpics" or key == "deSkipRefundable" or key == "marks") and DE.frame and DE.frame:IsShown() then DE:Refresh() end
	if key == "deEnabled" and ns.db and not ns.db.deEnabled and DE.frame and DE.frame:IsShown() then DE.frame:Hide() end
	if (key == nil or key == "deEnabled") and ns.Window and ns.Window.main and ns.Window.main.RefreshToolbar then ns.Window.main:RefreshToolbar() end
end)

------------------------------------------------------------------------
-- The offer: a character with Enchanting is asked once whether to add the helper
------------------------------------------------------------------------
-- Add Now turns the helper on (the toolbar button appears); Ask Later asks again next session; Don't Ask
-- Again is remembered for the character and can be undone on the settings page.
function DE:OfferDue()
	if not (ns.db and ns.cdb) then return false end
	if ns.db.deEnabled then return false end
	if ns.cdb.deOfferDeclined then return false end
	if self.offeredThisSession then return false end
	if InCombatLockdown and InCombatLockdown() then return false end
	if ns.atBank or (ns.ui and (ns.ui.atVendor or ns.ui.owner)) then return false end
	return self:Known()
end
function DE:OfferFrame()
	local f = self.offer
	if f then return f end
	f = CreateFrame("Frame", "BagSmithDisenchantOffer", UIParent, "BackdropTemplate")
	f:SetSize(440, 148); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true)
	if f.SetToplevel then f:SetToplevel(true) end
	f:SetMovable(true); f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f.closeX = ns.IconButton(f, "Interface\\AddOns\\BagSmith\\Media\\ui-close.tga", "Ask Later", function() DE:OfferAnswer("later") end)
	f.closeX:SetSize(18, 18); f.closeX:SetPoint("TOPRIGHT", -10, -10)
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", 16, -14); f.title:SetText("Disenchant Helper")
	-- the icon at the left with a rule beside it, the text to the right
	f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetSize(40, 40); f.icon:SetPoint("TOPLEFT", 20, -44); f.icon:SetTexture("Interface\\AddOns\\BagSmith\\Media\\ui-disenchant-large.tga")
	f.rule = f:CreateTexture(nil, "ARTWORK"); f.rule:SetWidth(1); f.rule:SetPoint("TOPLEFT", 74, -42); f.rule:SetPoint("BOTTOMLEFT", 74, 44); f.rule:SetColorTexture(1, 1, 1, 0.15)
	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); f.text:SetPoint("TOPLEFT", 86, -42); f.text:SetPoint("TOPRIGHT", -16, -42); f.text:SetJustifyH("LEFT"); f.text:SetWordWrap(true)
	f.text:SetText("This character can disenchant. Add the Disenchant Helper button to your bag window? It lists the gear worth considering, walks you through it one click at a time, and learns from your results.")
	f.add = ns.TextButton(f, "Add Now", 100, function() DE:OfferAnswer("add") end); f.add:SetHeight(22); f.add:SetPoint("BOTTOMRIGHT", -16, 12)
	f.add.primary = true   -- the one we hope for: drawn in the active (accent) state, in both skins
	-- the quiet choices: plain muted text at the left of the same row, no button chrome
	local function link(text, onClick)
		local b = CreateFrame("Button", nil, f); b:SetHeight(22)
		b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.label:SetPoint("LEFT"); b.label:SetText(text)
		b:SetWidth(b.label:GetStringWidth() + 4)
		b:SetScript("OnClick", onClick)
		b:SetScript("OnEnter", function(self) self.label:SetTextColor(1, 1, 1) end)
		b:SetScript("OnLeave", function(self) local s = ns.Skins:Current(); self.label:SetTextColor(unpack(s.muted)) end)
		b.isLink = true
		return b
	end
	f.later = link("Ask Later", function() DE:OfferAnswer("later") end); f.later:SetPoint("BOTTOMLEFT", 86, 12)
	f.never = link("Don't Ask Again", function() DE:OfferAnswer("never") end); f.never:SetPoint("LEFT", f.later, "RIGHT", 14, 0)
	f.classicSpec = ns.Classic.DialogSpec(f, { hide = { f.closeX }, close = function() DE:OfferAnswer("later") end, restore = function() ns.Skins:ApplyBackdrop(f); local s = ns.Skins:Current(); f:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1) end })
	ns.Skins:Register(f, function(fr)
		ns.Skins:ApplyBackdrop(fr); local s = ns.Skins:Current(); fr:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 1)
		fr.title:SetTextColor(unpack(s.heading))
		do local ar, ag, ab = ns.Skins:Accent(); fr.icon:SetVertexColor(ar, ag, ab) end   -- the art, tinted with the accent
		fr.later.label:SetTextColor(unpack(s.muted)); fr.never.label:SetTextColor(unpack(s.muted))
		if fr.add.SetActive then fr.add:SetActive(true) end
		ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
	end)
	f:Hide()
	ns:CloseOnEscape(f, function() DE:OfferAnswer("later") end)   -- (1.5.4) Escape is Ask Later, as its close is
	ns:CombatWindow(f)   -- (1.5.6) fades in combat like the bags window
	self.offer = f
	return f
end
function DE:Offer()
	if not self:OfferDue() then return false end
	self.offeredThisSession = true
	local f = self:OfferFrame()
	f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	f:Show()
	return true
end
function DE:OfferAnswer(what)
	if self.offer then self.offer:Hide() end
	if what == "add" then ns:Set("deEnabled", true); ns:Print("The Disenchant Helper is on: its button is beside the Gear Sets shield, and /bs de opens it too.")
	elseif what == "never" then if ns.cdb then ns.cdb.deOfferDeclined = true end end
	self.lastOfferAnswer = what
end
function DE:AskAgain() if ns.cdb then ns.cdb.deOfferDeclined = nil end end
-- Forget what this character's disenchants taught the helper: the estimates go back to the typical results.
function DE:ResetLearned()
	if ns.cdb then ns.cdb.deResults = {} end
	if self.frame and self.frame:IsShown() then self:Refresh() end
end
function DE:LearnedCount() local n = 0; for _, e in pairs(self:Log()) do n = n + (type(e) == "table" and (e.n or 0) or 0) end return n end
ns:OnSignal("ADDON_READY", function()
	-- the learned-results schema is checked at login, after the saved data has been validated, so a legacy record is
	-- cleared (and said) at startup rather than on first use
	DE:Log()
	-- the offer, a moment after the bags open (the character's spells are known by then); the windows are
	-- built by a later ADDON_READY handler, so the hook waits a frame for them
	local function hook()
		if ns.Window and ns.Window.main and ns.Window.main.frame and not DE.offerHooked then
			DE.offerHooked = true
			ns.Window.main.frame:HookScript("OnShow", function() local f = C_Timer and C_Timer.After or function(_, fn) fn() end; f(0.2, function() if ns.Window.main.frame:IsShown() then DE:Offer() end end) end)
		end
	end
	if ns.NextFrame then ns:NextFrame("de:offer-hook", hook) else hook() end
end)

-- The keybinding clicks the secure button directly (a CLICK binding); its name for the Keybindings page.
_G["BINDING_NAME_CLICK BagSmithDisenchantButton:LeftButton"] = "Disenchant Next Item"
