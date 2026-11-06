;(function()
	-- 1.0.2: the item level on icons, Icons view only, gear only, off by default, under every overlay
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 5, ilvl = 23, equip = "INVTYPE_FEET" })
	M.put(0, 2, { id = 7002, name = "Minor Healing Potion", q = 1, count = 5, class = 0, subclass = 1, price = 1, ilvl = 5, equip = "INVTYPE_NON_EQUIP" })
	M.put(0, 4, { id = 7004, name = "Linen Cloth", q = 1, count = 15, class = 7, subclass = 5, price = 1, ilvl = 5, equip = "INVTYPE_NON_EQUIP" })
	M.put(0, 5, { id = 7005, name = "Worn Dagger", q = 1, count = 1, class = 2, subclass = 15, price = 3, ilvl = 7, equip = "INVTYPE_WEAPON" })
	M.put(0, 3, { id = 7003, name = "Odd Trinket", q = 2, count = 1, class = 4, subclass = 0, price = 5, ilvl = 1, equip = "INVTYPE_TRINKET" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", view = "icons" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local function btn(slot) return n.Buttons.byBag[0][slot] end
	local function shown(slot) local t = btn(slot).ilvlText; return t ~= nil and t:IsShown() and t.text or nil end
	check(n.db.iconItemLevel == false and shown(1) == nil, "off by default: no level on the boots")
	n:Set("iconItemLevel", true); M.runTimers(); M.runTimers()
	n.Window.main:Refresh(true, "test"); M.runTimers()
	local boots = btn(1)
	check(boots.mode == "cell" and shown(1) == "23", "in Icons view with the setting on, gear shows its level")
	local t = boots.ilvlText
	local layer, sub = t:GetDrawLayer()
	check(layer == "ARTWORK" and sub == 1 and t.points[1][1] == "TOPRIGHT" and t.points[1][2] == boots.icon and t.points[1][4] == 0 and t.points[1][5] == 0, "the level is drawn on ARTWORK just above the icon, flush in the top-right corner (1.5.0-beta6)")
	local coinPoints = boots.junkCoin.points
	check(coinPoints == nil or coinPoints[1] == nil or coinPoints[1][1] == "TOPLEFT", "the junk coin keeps the top-left corner: the two never meet")
	check(shown(2) == nil and shown(3) == nil and shown(4) == nil, "a potion, cloth and a level-1 trinket show nothing, whatever equip slot the client reports")
	check(shown(5) == "7", "a weapon shows its level")
	local cr, cg, cb = boots.ilvlText.textColor and boots.ilvlText.textColor[1], boots.ilvlText.textColor and boots.ilvlText.textColor[2], boots.ilvlText.textColor and boots.ilvlText.textColor[3]
	check(n.db.iconItemLevelColor == "3598db" and cr and math.abs(cr - 0x35 / 255) < 0.01 and math.abs(cg - 0x98 / 255) < 0.01 and math.abs(cb - 0xdb / 255) < 0.01, "the level is drawn in its own color, #3598db by default, apart from the count")
	n:Set("iconItemLevelColor", "ff0000"); M.runTimers()
	check(math.abs(boots.ilvlText.textColor[1] - 1) < 0.01 and boots.ilvlText.textColor[2] < 0.01, "changing the color setting recolors the placed levels at once")
	check(n:Set("iconItemLevelColor", "nope") == false and n.db.iconItemLevelColor == "ff0000", "a non-hex value is refused")
	n:Set("iconItemLevelColor", "#3598DB")
	check(n.db.iconItemLevelColor == "3598db", "a hash and upper case are accepted and normalized")
	-- the color row sits indented under its checkbox, as a sub-setting
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("icons")   -- (1.5.0: Item Level moved to Item Icons)
	local chk, col
	for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == "iconItemLevel" then chk = w end end
	for _, w in ipairs(P.pools.color) do if w:IsShown() and w.key == "iconItemLevelColor" then col = w end end
	check(chk and col and col.points[1][4] > chk.points[1][4], "Item Level Color is indented under Show Item Level on Icons")
	P:Hide()
	-- List view: the column, never the overlay
	n:Set("view", "list"); M.runTimers(); n.Window.main:Refresh(true, "test"); M.runTimers()
	check(btn(1).mode == "row" and (btn(1).ilvlText == nil or not btn(1).ilvlText:IsShown()) and btn(1).colLevel and tostring(btn(1).colLevel.text) == "23", "in List view the level stays in its column and the icon overlay is hidden")
	-- the column follows the same rule as the icon: a level only for weapons and armor with a real one, "-" otherwise
	check(tostring(btn(5).colLevel.text) == "7" and btn(2).colLevel.text == "-" and btn(4).colLevel.text == "-" and btn(3).colLevel.text == "-", "the iLvl column shows the dagger's level and a dash for the potion, the cloth and the level-1 trinket")
	check(n.COL_LABEL.rq == "Req lvl" and n.COL_LABEL.il == "iLvl", "the required-level column is headed Req lvl")
	n:Set("view", "icons"); M.runTimers(); n.Window.main:Refresh(true, "test"); M.runTimers()
	check(shown(1) == "23", "back in Icons view it returns")
	n:Set("iconItemLevel", false); M.runTimers(); n.Window.main:Refresh(true, "test"); M.runTimers()
	check(shown(1) == nil, "turning the setting off hides it")
	-- an emptied slot clears it
	n:Set("iconItemLevel", true); M.runTimers(); n.Window.main:Refresh(true, "test"); M.runTimers()
	M.bags[0][1] = nil; M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	check(shown(1) == nil or not btn(1):IsShown(), "an emptied slot shows no level (its button is hidden with it, and a refill resets the text)")
end)()

