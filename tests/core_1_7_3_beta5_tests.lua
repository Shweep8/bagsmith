;(function()
	-- ======== 1.7.3-beta5: the Disenchant Helper's likely results link to their items (Shweep) ========
	-- Each material's name, in its rarity color and softly underlined, shows the item's tooltip on hover, by item ID.
	package.loaded.mock = nil
	local M = require("mock")
	local DEID = 13262
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 452, ilvl = 23, equip = "INVTYPE_FEET" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
	_G.IsSpellKnown = function(id) return id == DEID end
	_G.RegisterStateDriver = function() end
	_G.UnregisterStateDriver = function() end
	_G.ITEM_QUALITY_COLORS = { [1] = { r = 1, g = 1, b = 1 }, [2] = { r = 0.12, g = 1, b = 0 }, [3] = { r = 0, g = 0.44, b = 0.87 }, [4] = { r = 0.64, g = 0.21, b = 0.93 } }
	-- the game knows Strange Dust (with its quality); the essence and shard aren't loaded yet (names and qualities unknown)
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(link)
		local id = tonumber(tostring(link):match("item:(%d+)")) or link
		if id == 10940 then return "Strange Dust", "item:10940", 1 end
		if id == 10939 or id == 10978 then return nil end
		return realInfo(link)
	end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE = n.Disenchant
	DE:Show(); M.runTimers()
	local f = DE.frame
	local rows = {}
	for _, r in ipairs(f.cur.likelyRows or {}) do if r:IsShown() then rows[r.id] = r end end
	local dust, ess, shard = rows[10940], rows[10939], rows[10978]
	check(dust and ess and shard, "one row per likely material (Strange Dust, Greater Magic Essence, Small Glimmering Shard)")
	check(dust and dust.name.text == "Strange Dust" and dust.rest.text:find("^: ") and dust.rest.text:find("about 75%%"), "the name, then the amount and odds")
	check(dust and dust.c[1] == 1 and dust.c[2] == 1 and dust.c[3] == 1, "Strange Dust in its quality's color (common, from the game)")
	check(ess and math.abs(ess.c[1] - 0.12) < 1e-9 and ess.c[2] == 1, "an essence the game hasn't loaded: uncommon green, from BagSmith's own table")
	check(shard and shard.c[3] == 0.87, "a shard: rare blue")
	check(ess and ess.name.text == "item 10939", "(its name waits for the game, as before)")
	check(n.Disenchant.MAT_QUALITY[n.Disenchant.MATS.nexusCrystal] == 4 and n.Disenchant.MAT_QUALITY[n.Disenchant.MATS.greaterEternal] == 2
		and n.Disenchant.MAT_QUALITY[n.Disenchant.MATS.illusionDust] == 1 and n.Disenchant.MAT_QUALITY[n.Disenchant.MATS.largeBrilliant] == 3,
		"every material has a quality: dust common, essences uncommon, shards rare, the Nexus Crystal epic")
	-- the soft underline: the name's color, faint, brighter on hover; the tooltip by ID
	local lc = dust.line.color
	check(lc and lc[4] == 0.4 and dust.line.points and dust.line.points[1][2] == dust.name, "a soft underline under the name, in its color")
	dust:GetScript("OnEnter")(dust)
	check(GameTooltip.shown and GameTooltip.owner == dust and GameTooltip.item and GameTooltip.item.link == "item:10940", "hovering a name shows that item's tooltip (by ID)")
	check(dust.line.color[4] == 0.9, "and brightens its underline")
	dust:GetScript("OnLeave")(dust)
	check(not GameTooltip.shown and dust.line.color[4] == 0.4, "leaving hides it and softens the underline again")
	check(f.cur.likely.text == "", "the plain text line stays empty while rows show")
	-- an item with no table: the plain line says so, no rows
	local parts = select(5, DE:LikelyLines({ quality = 5, ilvl = 60, class = 4 }))
	DE:PaintLikely(parts)
	local shown = 0
	for _, r in ipairs(f.cur.likelyRows) do if r:IsShown() then shown = shown + 1 end end
	check(shown == 0, "no table: no rows")
end)()
