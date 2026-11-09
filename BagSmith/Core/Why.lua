local _, ns = ...
--[[ Why an item was left out (1.3.0).

	One vocabulary for every place BagSmith quietly keeps items out of something: the Disenchant Helper's
	list, the Loot Helper's suggestions, junk marking and selling. A place collects the items it held back
	under reason codes; this file turns them into the same words everywhere: a count line, the info
	tooltip's grouped lines, and the phrase on an empty card.
]]
local Why = {}
ns.Why = Why

Why.LABEL = {
	favorite = "Favorites",
	gearset = "In a gear set",
	quest = "Quest items",
	pawn = "Pawn upgrades",
	novalue = "No vendor price",
	refundable = "Refundable",
	tradeable = "Still tradeable",
	epic = "Epics (off in settings)",
	skill = "Needs more Enchanting skill",
	deExcluded = "On your DE Exclusion List",
	lootExcluded = "On your Loot Exclusion List",
	unknown = "Couldn't be checked right now",
}
-- singular and plural for the empty card's sentence
Why.NOUN = {
	favorite = { "favorite", "favorites" },
	gearset = { "item in a gear set", "items in a gear set" },
	quest = { "quest item", "quest items" },
	pawn = { "Pawn upgrade", "Pawn upgrades" },
	novalue = { "item with no vendor price", "items with no vendor price" },
	refundable = { "refundable item", "refundable items" },
	tradeable = { "still-tradeable item", "still-tradeable items" },
	epic = { "epic", "epics" },
	skill = { "item above your Enchanting skill", "items above your Enchanting skill" },
	deExcluded = { "item on your DE Exclusion List", "items on your DE Exclusion List" },
	lootExcluded = { "item on your Loot Exclusion List", "items on your Loot Exclusion List" },
	unknown = { "item that couldn't be checked", "items that couldn't be checked" },
}
Why.ORDER = { "favorite", "gearset", "quest", "pawn", "deExcluded", "lootExcluded", "refundable", "tradeable", "epic", "skill", "novalue", "unknown" }
Why.SHOWN_NAMES = 3

function Why:New() return { total = 0, by = {} } end
function Why:Add(h, code, name)
	if not (h and code) then return end
	h.by[code] = h.by[code] or {}
	table.insert(h.by[code], name or "?")
	h.total = h.total + 1
end
-- One tooltip line per reason, in a fixed order: "Favorites (2): Tear of Grief, Heavy Linen Gloves".
function Why:Lines(h)
	local out = {}
	if not h then return out end
	for _, code in ipairs(self.ORDER) do
		local names = h.by[code]
		if names and #names > 0 then
			local shown = {}
			for i = 1, math.min(#names, self.SHOWN_NAMES) do shown[i] = names[i] end
			local more = #names - #shown
			out[#out + 1] = ("|cffe6b450%s (%d):|r %s%s"):format(self.LABEL[code] or code, #names, table.concat(shown, ", "), more > 0 and (", and %d more"):format(more) or "")
		end
	end
	return out
end
function Why:Line(code, names)
	local h = self:New()
	for _, n in ipairs(names or {}) do self:Add(h, code, n) end
	return self:Lines(h)[1]
end
-- "2 favorites, 1 item in a gear set and 1 quest item"
function Why:Phrase(h)
	local parts = {}
	if not h then return "" end
	for _, code in ipairs(self.ORDER) do
		local names = h.by[code]
		if names and #names > 0 then
			local noun = self.NOUN[code] or { code, code }
			parts[#parts + 1] = ("%d %s"):format(#names, #names == 1 and noun[1] or noun[2])
		end
	end
	if #parts <= 1 then return parts[1] or "" end
	return table.concat(parts, ", ", 1, #parts - 1) .. " and " .. parts[#parts]
end

-- The small info icon: hover for the grouped reasons (button.title and button.lines).
function Why.InfoButton(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(14, 14)
	b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(); b.tex:SetTexture("Interface\\AddOns\\BagSmith\\Media\\ui-info.tga")
	b:SetScript("OnEnter", function(self)
		if not (self.lines and ns.TooltipsOK and ns.TooltipsOK()) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		ns.TipText(GameTooltip, self.title or "", 1, 1, 1)
		for _, l in ipairs(self.lines) do ns.TipLine(GameTooltip, l, 0.9, 0.9, 0.9, true) end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end
