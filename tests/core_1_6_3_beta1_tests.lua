;(function()
	-- 1.6.3-beta1 (Shweep: an item moved from Other to Food went back after every /reload, however it was moved). The
	-- saved-settings check at load didn't know Split Consumables' sections (ConsFood...), so it dropped moves to them,
	-- their place in Section Order and their vendor/AH hiding; profile sharing runs the same check. Shweep's choice for
	-- a move to a split section that isn't in use (the split off, or that type unticked): the item shows in Consumables
	-- meanwhile and goes back when the section is in use again; the move is kept.
	local function copy(t) if type(t) ~= "table" then return t end local o = {} for k, v in pairs(t) do o[copy(k)] = copy(v) end return o end
	local function session(db, cdb)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 4540, name = "Tough Hunk of Bread", q = 1, count = 5, class = 0, subclass = 5, type = "Consumable", sub = "Food & Drink", price = 1 })
		M.put(0, 2, { id = 5571, name = "Small Black Pouch", q = 1, count = 1, class = 15, subclass = 0, type = "Miscellaneous", sub = "Junk", price = 3 })
		M.put(0, 3, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
		M.put(0, 4, { id = 6948, name = "Hearthstone", q = 1, count = 1, class = 15, subclass = 0, price = 0 })
		M.put(0, 5, { id = 118, name = "Minor Healing Potion", q = 1, count = 3, class = 0, subclass = 1, type = "Consumable", sub = "Potion", price = 5 })
		C_Item.GetItemSpell = function(id) if id == 4540 then return "Food", 433 end end
		_G.GetSpellInfo = function(id) return ({ [433] = "Food", [430] = "Drink" })[id] end
		_G.BagSmithCharDB = cdb or { version = 1, firstSeen = {} }
		_G.BagSmithDB = db or { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M
	end
	local function reload(n) return session(copy(_G.BagSmithDB), copy(_G.BagSmithCharDB)) end
	local function cat(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r.cat end end end
	local function indexOf(t, v) for i, x in ipairs(t or {}) do if x == v then return i end end end

	-- ---- 1. moves to split sections, their order and hiding, across a reload
	local n, M = session()
	n:Set("splitCons", true); M.runTimers()
	local mine = n.Sections:Create("Mine")
	check(cat(n, 5571) == "Other" and cat(n, 4540) == "ConsFood" and mine, "(setup) the pouch in Other, the bread in Food, a custom section")
	n.Sections:Move(5571, "ConsFood")
	n.Sections:Move(118, "ConsDrink")
	n.Sections:Move(2589, "Gear")
	n.Sections:Move(6948, mine)
	local order = n.db.laneOrder
	table.remove(order, indexOf(order, "ConsFood")); table.insert(order, 1, "ConsFood")
	n.db.sectionHide = n.db.sectionHide or {}; n.db.sectionHide.ConsFood = { vendor = true }
	check(cat(n, 5571) == "ConsFood" and cat(n, 118) == "ConsDrink", "(setup) moved to Food and Drink")
	n, M = reload(n)
	check(cat(n, 5571) == "ConsFood", "after a reload, the pouch moved from Other to Food stays in Food (" .. tostring(cat(n, 5571)) .. ")")
	check(cat(n, 118) == "ConsDrink" and n.db.sectionMoves[118] == "ConsDrink", "a potion moved to Drink stays there too")
	check(cat(n, 2589) == "Gear" and cat(n, 6948) == mine, "moves to Gear and to a custom section stay, as before")
	check(n.db.laneOrder[1] == "ConsFood" and indexOf(n.db.laneOrder, "ConsFood") == 1, "Food keeps its place in Section Order (" .. tostring(n.db.laneOrder[1]) .. ")")
	local others = 0; for _, id in ipairs(n.db.laneOrder) do if id == "ConsFood" then others = others + 1 end end
	check(others == 1, "and appears there once")
	check(n.db.sectionHide.ConsFood and n.db.sectionHide.ConsFood.vendor == true, "and keeps its vendor hiding")

	-- ---- 2. the split off, or Food unticked: in Consumables meanwhile; back in Food when it's in use
	n:Set("splitCons", false); M.runTimers()
	check(cat(n, 5571) == "Consumables" and n.db.sectionMoves[5571] == "ConsFood", "split off: the pouch shows in Consumables, the move kept (" .. tostring(cat(n, 5571)) .. ")")
	local lone = false
	for _, r in ipairs(n.items) do if r.cat and n.PARENT_CAT[r.cat] then lone = true end end
	check(not lone, "no item sits in a split section while the split is off")
	n, M = reload(n)
	check(cat(n, 5571) == "Consumables" and n.db.sectionMoves[5571] == "ConsFood", "and after a reload with the split off, still Consumables, the move kept")
	n:Set("splitCons", true); M.runTimers()
	check(cat(n, 5571) == "ConsFood", "the split back on: the pouch is in Food again")
	n:Set("splitConsTypes", { Food = false }); M.runTimers()
	check(cat(n, 5571) == "Consumables" and cat(n, 118) == "ConsDrink", "Food unticked: the pouch in Consumables, the potion still in Drink")
	n:Set("splitConsTypes", {}); M.runTimers()
	check(cat(n, 5571) == "ConsFood", "Food ticked again: back in Food")

	-- ---- 3. profile sharing keeps them
	local code = n.Share:Export()
	local name = code and n.Share:Import(code, "Shared")
	local prof = name and BagSmithDB.profiles[name]
	check(prof and prof.sectionMoves and prof.sectionMoves[5571] == "ConsFood" and prof.sectionMoves[118] == "ConsDrink",
		"a shared profile keeps moves to split sections (" .. tostring(name) .. ")")
	check(prof and prof.laneOrder and prof.laneOrder[1] == "ConsFood" and prof.sectionHide and prof.sectionHide.ConsFood, "and their order and hiding")

	-- ---- 4. the check still drops what it should
	local db = copy(_G.BagSmithDB)
	local moves = db.profiles.Default.sectionMoves
	moves[1001], moves[1002], moves[1003], moves[1004], moves[1005] = "~recent", "Junk", "Bogus", "ConsBogus", "c99"
	n, M = session(db, copy(_G.BagSmithCharDB))
	local m = n.db.sectionMoves
	check(m[1001] == nil and m[1002] == nil and m[1003] == nil and m[1004] == nil, "moves to special sections, Junk or unknown sections are still dropped at load")
	check(m[1005] == "c99" and m[5571] == "ConsFood", "custom section ids and split sections are kept")
end)()
