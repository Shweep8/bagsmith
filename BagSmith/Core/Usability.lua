-- Unmet character requirements, separate from cooldowns and other temporary restrictions.
local ADDON, ns = ...
local U = {}
ns.Usability = U
local cache, count, patterns = {}, 0, {}
-- (1.9.2-beta1, after Shweep's review) items read before the game had their data, with no answer yet: only these are
-- read again when item data or tooltip data arrives
local unknown = {}
local function plain(s)
	return type(s) == "string" and s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$") or ""
end
local function matches(text, fmt)
	if type(fmt) ~= "string" or fmt == "" then return false end
	local p = patterns[fmt]
	if not p then
		local s = plain(fmt):gsub("%%[%d]+%$[sd]", "\001"):gsub("%%[sd]", "\001")
		p = "^" .. s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"):gsub("\001", ".+") .. "$"
		patterns[fmt] = p
	end
	return text:match(p) ~= nil
end
local REQUIREMENTS = { "ITEM_MIN_LEVEL", "ITEM_LEVEL_RANGE_CURRENT", "ITEM_CLASSES_ALLOWED", "ITEM_RACES_ALLOWED",
	"RACE_CLASS_ONLY", "ITEM_MIN_SKILL", "ITEM_REQ_REPUTATION" }
local RESTRICTED = { "RestrictedRaceClass", "RestrictedFaction", "RestrictedSkill", "RestrictedPvPMedal", "RestrictedReputation", "RestrictedLevel" }
local function red(r, g, b)
	return type(r) == "number" and type(g) == "number" and type(b) == "number" and r > 0.7 and g < 0.3 and b < 0.3
end
local function redText(text, color)
	if color then
		local r, g, b = color.r, color.g, color.b
		if color.GetRGB then r, g, b = color:GetRGB() end
		if red(r, g, b) then return true end
	end
	for r, g, b in (text or ""):gmatch("|c%x%x(%x%x)(%x%x)(%x%x)") do
		if red(tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255) then return true end
	end
	return false
end
local function unmet(text, color, rec)
	if type(text) ~= "string" or not redText(text, color) then return false end
	local s = plain(text)
	for _, key in ipairs(REQUIREMENTS) do if matches(s, _G[key]) then return true end end
	return (rec.classID == 2 or rec.classID == 4) and rec.itemSubType ~= nil and s == rec.itemSubType
end
-- (1.9.3-beta1, Shweep: "it thinks I can use a gun and sword as a priest - the leather pants tho are correctly red")
-- A weapon's or armor's type sits on the right of its slot line ("Ranged ... Gun", "One-Hand ... Sword"), red when your
-- character can't use it. The item's type name is often not what the tooltip says ("Guns", "One-Handed Swords",
-- "Staves", "Shields"), so only cloth, leather, mail and plate matched above: the slot line decides. Its left side is
-- the game's own name for the item's slot (INVTYPE_*), so this holds in any language. Read in game on Forever: a
-- priest's gun shows "Ranged | Gun" in (1, 0.13, 0.13); INVTYPE_RANGEDRIGHT is "Ranged".
local function slotLine(line, rec)
	if rec.classID ~= 2 and rec.classID ~= 4 then return false end
	local slot = type(rec.equipLoc) == "string" and rec.equipLoc ~= "" and _G[rec.equipLoc]
	if type(slot) ~= "string" or slot == "" or plain(line.leftText) ~= plain(slot) then return false end
	return type(line.rightText) == "string" and plain(line.rightText) ~= "" and redText(line.rightText, line.rightColor)
end
local function unmetLine(line, rec)
	local types = Enum and Enum.TooltipDataLineType or {}
	for _, name in ipairs(RESTRICTED) do
		if types[name] ~= nil and line.type == types[name] then
			return redText(line.leftText, line.leftColor) or redText(line.rightText, line.rightColor)
		end
	end
	if slotLine(line, rec) then return true end
	-- ITEM_REQ_SKILL is just "Requires %s": without a typed line that is ambiguous.
	return unmet(line.leftText, line.leftColor, rec) or unmet(line.rightText, line.rightColor, rec)
end
local scanTip
local function tooltip(rec)
	-- Hyperlinks describe the logged-in character even when viewing saved inventory.
	local link = rec.link or (rec.itemID and ("item:" .. rec.itemID))
	if not link then return nil end
	if C_TooltipInfo and C_TooltipInfo.GetHyperlink then return C_TooltipInfo.GetHyperlink(link) end
	if not scanTip then scanTip = CreateFrame("GameTooltip", "BagSmithUsabilityTooltip", UIParent, "GameTooltipTemplate") end
	if not (scanTip.SetHyperlink and scanTip.NumLines and scanTip.ClearLines) then return nil end
	scanTip:SetOwner(UIParent, "ANCHOR_NONE"); scanTip:ClearLines(); scanTip:SetHyperlink(link)
	local lines = {}
	for i = 1, scanTip:NumLines() do
		local line = {}
		for _, side in ipairs({ "Left", "Right" }) do
			local rgn = _G["BagSmithUsabilityTooltipText" .. side .. i]
			if rgn then
				local r, g, b = rgn:GetTextColor()
				line[side:lower() .. "Text"] = rgn:GetText()
				line[side:lower() .. "Color"] = { r = r, g = g, b = b }
			end
		end
		lines[#lines + 1] = line
	end
	scanTip:Hide()
	return { lines = lines }
end
function U:IsUnusable(rec)
	if not rec or rec.empty or rec.globalChild then return false end
	local c = rec.classID
	if c ~= 2 and c ~= 4 and c ~= 9 and c ~= 0 then
		-- Some edible reagents (raw fish on Forever) are Trade Goods. A real use
		-- spell makes them eligible; a category label alone does not tell us that.
		local ok, name, spellID = pcall(ns.ItemUseSpell, ns, rec.itemID)
		if not ok or not ((type(name) == "string" and name ~= "") or (type(spellID) == "number" and spellID > 0)) then return false end
	end
	local level = UnitLevel and UnitLevel("player")
	if type(level) == "number" and level > 0 and type(rec.minLevel) == "number" and rec.minLevel > level then return true end
	local key = rec.link or rec.itemID
	if not key then return false end
	if cache[key] ~= nil then return cache[key] end
	local ok, info = pcall(tooltip, rec)
	if scanTip then scanTip:Hide() end
	local id = tonumber(rec.itemID)
	if not ok or type(info) ~= "table" or type(info.lines) ~= "table" or #info.lines == 0 then
		if id then unknown[id] = true end
		return false
	end
	local result, readable = false, 0
	local readOK = pcall(function()
		for _, line in ipairs(info.lines) do
			if plain(line.leftText) ~= "" or plain(line.rightText) ~= "" then readable = readable + 1 end
			if unmetLine(line, rec) then result = true; break end
		end
	end)
	if not readOK then if id then unknown[id] = true end return false end
	-- Empty/header-only tooltips are loading states, not evidence of met requirements.
	if not result and readable < 2 then if id then unknown[id] = true end return false end
	if id then unknown[id] = nil end
	if count >= 2000 then cache, count = {}, 0 end
	cache[key], count = result, count + 1
	return result
end
-- (1.10.0-beta11) For a rule (Usable by Me): true, false, or nil while the game hasn't shown the item's tooltip yet
-- (U:IsUnusable says "not unusable" then, which is right for an overlay and wrong for filing an item).
function U:Usable(rec)
	if type(rec) ~= "table" or rec.empty or not rec.itemID then return nil end
	if self:IsUnusable(rec) then return false end
	local id = tonumber(rec.itemID)
	if id and unknown[id] then return nil end
	return true
end
-- Does a section's rules, or a window's filter, ask whether an item is usable?
local function ruleWanted()
	local function uses(rules)
		if type(rules) ~= "table" or type(rules.rows) ~= "table" then return false end
		for _, row in ipairs(rules.rows) do if type(row) == "table" and row.k == "usable" then return true end end
		return false
	end
	for _, c in ipairs(ns.Sections and ns.Sections:Customs() or {}) do if uses(c.rules) then return true end end
	for _, v in pairs(ns.views or {}) do if v.st and v.st.filters and uses(v.st.filters.rules) then return true end end
	return false
end
-- The answers may have changed (you leveled, learned a skill, or the game sent an item's tooltip): while a rule asks,
-- the sections are looked at again a moment later, once, and only if an answer about something you carry really is
-- different (the game sends tooltip news constantly, and an item whose tooltip never loads must not keep the bags
-- redrawing).
local function answers()
	local parts = {}
	for _, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
		for _, r in ipairs(list) do
			if r.itemID then
				local u = U:Usable(r)
				if u ~= true then parts[#parts + 1] = tostring(r.itemID) .. (u == false and "n" or "?") end
			end
		end
	end
	return table.concat(parts, ",")
end
-- (1.10.0-beta13, the beta12 audit's F2) force: a level gained. An item that was out of reach by its level alone
-- has no tooltip answer to compare (the level check answers before the tooltip is read), so the comparison is
-- skipped that once and the sections are looked at whatever it says.
local reapplying, lastAnswers, forced = false, nil, false
local function reapplySoon(force)
	if not ruleWanted() then return end
	if force then forced = true end
	if reapplying then return end
	reapplying = true
	C_Timer.After(0.5, function()
		reapplying = false
		local must = forced
		forced = false
		if not (ruleWanted() and ns.Sections and ns.Sections.Reapply) then return end
		local now = answers()
		if now == lastAnswers and not must then return end
		lastAnswers = now
		ns.Sections:Reapply()
	end)
end
U.RuleWanted = ruleWanted   -- (for the tests)
function U:Decorate(b, rec)
	local show = ns.db and ns.db.unusableOverlay and self:IsUnusable(rec) or false
	if show and not b.unusableOverlay then
		-- Above the artwork, below OVERLAY borders, counts and corner marks.
		b.unusableOverlay = b:CreateTexture(nil, "ARTWORK", nil, 7)
		b.unusableOverlay:SetAllPoints(b.icon)
	end
	if b.unusableOverlay then
		b.unusableOverlay:SetColorTexture(1, 0, 0, ns.db.unusableOverlayOpacity or 0.35)
		b.unusableOverlay:SetShown(show)
	end
end
function U:Invalidate() cache, count, unknown = {}, 0, {} end
-- (1.9.2-beta1) a requirement can become met, never unmet: progression drops only the answers that said "can't use"
function U:ForgetUnusable()
	for k, v in pairs(cache) do if v then cache[k] = nil; count = count - 1 end end
end
U.Unknown = function() return unknown end   -- (for the tests)
function U:Refresh()
	local B = ns.Buttons
	if not B then return end
	local function each(b) self:Decorate(b, b.hasItem and b.rec or nil) end
	B:EachLive(each)
	for _, pool in pairs(B.cached) do for _, b in pairs(pool) do each(b) end end
end
local queued = false
local function refreshSoon()
	if queued then return end
	queued = true
	C_Timer.After(0, function() queued = false; U:Refresh() end)
end
-- (1.9.2-beta1, after Shweep's review: each of these events used to clear every answer and read every item's tooltip
-- again; in the mock, 30 item-data loads for items not in the bags cost 840 reads)
local function itemData(itemID)   -- an item's data arrived: read it again only if it had no answer yet
	itemID = tonumber(itemID)
	if itemID and unknown[itemID] then unknown[itemID] = nil; refreshSoon(); reapplySoon() end
end
local function tooltipData()   -- no item named: only while some item still has no answer
	if next(unknown) then refreshSoon(); reapplySoon() end
end
local function progressed(level)   -- level, skills, spells, reputation: the red ones may now be usable
	-- (1.10.0-beta13, F2) every one of these asks for another look at the sections while a rule uses Usable by Me
	-- (beta11 asked only when a tooltip had been red, which missed an item held back by its level alone); what
	-- keeps that from being costly is the comparison in reapplySoon. A level gained skips the comparison.
	U:ForgetUnusable(); refreshSoon()
	reapplySoon(level == true)
end
local function entered()   -- logging in, a reload, another character: everything afresh
	U:Invalidate(); refreshSoon(); reapplySoon()
end
ns:OnSignal("SETTINGS_CHANGED", function(key)
	if key == nil or key == "unusableOverlay" then U:Invalidate(); U:Refresh()
	elseif key == "unusableOverlayOpacity" then U:Refresh() end
end)
ns:OnSignal("ADDON_READY", function()
	ns:On("PLAYER_LEVEL_UP", function() progressed(true) end)
	for _, event in ipairs({ "SKILL_LINES_CHANGED", "SPELLS_CHANGED", "UPDATE_FACTION" }) do ns:On(event, function() progressed(false) end) end
	ns:On("GET_ITEM_INFO_RECEIVED", itemData)
	ns:On("TOOLTIP_DATA_UPDATE", tooltipData)
	ns:On("PLAYER_ENTERING_WORLD", entered)
end)
