;(function()
	-- ======== 1.7.0-beta7: a split's sections show in Move, Pin and Hide Sections as soon as it's turned on (Shweep) ========
	-- Settings redraws on a change before the sections join Section Order, so the first time a split was turned on with
	-- Settings open, its sections only showed in the table after the next redraw (Split Consumables since 1.5.0-beta9;
	-- Split Gear by Binding in beta6). Ticked with Settings open here, the way a player does it.
	for _, skin in ipairs({ "modern", "classic" }) do
		local S = skin .. ": "
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 5001, name = "Bound Helm", q = 2, class = 4, subclass = 4, price = 50, equip = "INVTYPE_HEAD", bind = 1, bound = true })
		M.put(0, 2, { id = 5002, name = "Tradeable Boots", q = 2, class = 4, subclass = 2, price = 40, equip = "INVTYPE_FEET", bind = 2 })
		M.put(0, 3, { id = 118, name = "Minor Healing Potion", q = 1, count = 3, class = 0, subclass = 1, price = 5 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local P = n.SettingsPanel; P:Show(); P:ShowPage("sections"); M.runTimers()
		local function rows()
			local out = {}
			for _, l in ipairs(P.pools.list) do if l:IsShown() then for _, r in ipairs(l.rows) do if r:IsShown() then out[#out + 1] = r.id end end end end
			return "," .. table.concat(out, ",") .. ","
		end
		local function box(key) for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == key then return w end end end
		local function tick(key, on) local b = box(key); b.box:SetChecked(on); b.box:GetScript("OnClick")(b.box) end
		check(rows():find(",Gear,Consumables,", 1, true) and not rows():find("GearSoulbound", 1, true) and not rows():find(n.CONS_ID[n.CONS_KINDS[1]], 1, true), S .. "before: no split sections in the table (" .. rows() .. ")")
		-- Split Gear by Binding: ticked, no other redraw
		tick("splitGear", true)
		check(n.db.splitGear == true and rows():find(",Gear,GearSoulbound,GearBoE,Consumables,", 1, true), S .. "Split Gear by Binding: Gear: Soulbound and Gear: BoE in the table at once, right after Gear (" .. rows() .. ")")
		check(box("splitGear_Soulbound") and box("splitGear_BoE"), S .. "with the two ticks")
		-- Split Consumables by Type: the same (fixed for it too)
		tick("splitCons", true)
		local r = rows()
		local first = n.CONS_ID[n.CONS_KINDS[1]]
		local all = true
		for _, k in ipairs(n.CONS_KINDS) do if not r:find("," .. n.CONS_ID[k] .. ",", 1, true) then all = false end end
		check(n.db.splitCons == true and all and r:find(",Consumables," .. first .. ",", 1, true), S .. "Split Consumables: its sections in the table at once, right after Consumables (" .. r .. ")")
		check(r:find(",Gear,GearSoulbound,GearBoE,", 1, true), S .. "and the gear ones stay")
		-- off: gone from the table, as before; on again: back in their places
		tick("splitGear", false)
		check(not rows():find("GearSoulbound", 1, true) and not rows():find("GearBoE", 1, true), S .. "off: the gear sections leave the table")
		local order = n.db.laneOrder
		local g = n.IndexOf(order, "GearBoE"); table.remove(order, g); table.insert(order, 1, "GearBoE")
		tick("splitGear", true)
		check(rows():find(",GearBoE,", 1, true) and n.IndexOf(n.db.laneOrder, "GearBoE") == 1 and rows():find(",Gear,GearSoulbound,", 1, true), S .. "on again: they come back where you left them")
		-- an unticked kind stays out of the table
		tick("splitGear_BoE", false)
		check(rows():find(",GearSoulbound,", 1, true) and not rows():find(",GearBoE,", 1, true), S .. "untick Gear: BoE: only Gear: Soulbound listed")
		-- in a search too
		P:SetQuery("order"); M.runTimers()
		check(rows():find(",GearSoulbound,", 1, true), S .. "a search for \"order\" lists them")
		P:SetQuery(""); P:Hide()
		-- the bags follow, as before
		local function cat(id) for _, rec in ipairs(n.items) do if rec.itemID == id then return rec.cat end end end
		check(cat(5001) == "GearSoulbound" and cat(5002) == "Gear", S .. "the bags follow (Gear: BoE unticked, the boots in Gear)")
		_G.BagSmithDB = nil
	end
end)()
;(function()
	-- ======== 1.7.0-beta7: only a change that adds sections redraws Settings a second time ========
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {} } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local P = n.SettingsPanel; P:Show(); P:ShowPage("sections"); M.runTimers()
	local real, count = P.Refresh, 0
	P.Refresh = function(self, ...) count = count + 1; return real(self, ...) end
	n:Set("splitGear", true); M.runTimers()
	check(count == 2, "turning a split on the first time: Settings draws twice (" .. count .. ")")
	count = 0; n:Set("splitGear", false); M.runTimers(); n:Set("splitGear", true); M.runTimers()
	check(count == 2, "off and on again (nothing new to add): once each (" .. count .. ")")
	P:Hide(); count = 0
	n:Set("splitCons", true); M.runTimers()
	check(count == 0 and n.IndexOf(n.db.laneOrder, n.CONS_ID[n.CONS_KINDS[1]]) ~= nil, "with Settings closed: nothing drawn, the sections still join the order")
	P.Refresh = real
	_G.BagSmithDB = nil
end)()
