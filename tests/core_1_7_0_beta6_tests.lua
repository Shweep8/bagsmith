;(function()
	-- ======== 1.7.0-beta6: Split Gear by Binding (Shweep) ========
	-- Like Split Consumables: one setting, off by default, a tick for each. Gear bound to you (bind on pickup, or a bind on
	-- equip piece once it's bound) goes to Gear: Soulbound; bind on equip not yet bound to Gear: BoE; binds when used, or
	-- doesn't bind, stays in Gear. Its sections are known to the load check from the start (the 1.6.3 lesson).
	local function copy(t) if type(t) ~= "table" then return t end local o = {} for k, v in pairs(t) do o[copy(k)] = copy(v) end return o end
	local function session(db, cdb, skin)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 5001, name = "Bound Helm", q = 2, class = 4, subclass = 4, price = 50, equip = "INVTYPE_HEAD", bind = 1, bound = true })
		M.put(0, 2, { id = 5002, name = "Tradeable Boots", q = 2, class = 4, subclass = 2, price = 40, equip = "INVTYPE_FEET", bind = 2 })
		M.put(0, 3, { id = 5003, name = "Equipped Once Gloves", q = 2, class = 4, subclass = 2, price = 30, equip = "INVTYPE_HAND", bind = 2, bound = true })
		M.put(0, 4, { id = 5004, name = "Use Bound Trinket", q = 2, class = 4, subclass = 0, price = 20, equip = "INVTYPE_TRINKET", bind = 3 })
		M.put(0, 5, { id = 5005, name = "Plain Shirt", q = 1, class = 4, subclass = 0, price = 5, equip = "INVTYPE_BODY", bind = 0 })
		M.put(0, 6, { id = 5006, name = "Worn Sword", q = 0, class = 2, subclass = 7, price = 3, equip = "INVTYPE_WEAPON", bind = 2 })
		M.put(0, 7, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
		_G.BagSmithCharDB = cdb or { version = 1, firstSeen = {} }
		_G.BagSmithDB = db or { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin or "modern", grp = "type", view = "list" } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M
	end
	local function reload() return session(copy(_G.BagSmithDB), copy(_G.BagSmithCharDB)) end
	local function cat(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r.cat end end end
	local function indexOf(t, v) for i, x in ipairs(t or {}) do if x == v then return i end end end
	for _, skin in ipairs({ "modern", "classic" }) do
		local S = skin .. ": "
		local n, M = session(nil, nil, skin)
		check(n.db.splitGear == false and cat(n, 5001) == "Gear" and cat(n, 5002) == "Gear", S .. "off by default: all gear in Gear")
		check(n.CAT_LABEL.GearSoulbound == "Gear: Soulbound" and n.CAT_LABEL.GearBoE == "Gear: BoE" and n.PARENT_CAT.GearSoulbound == "Gear" and n.PARENT_CAT.GearBoE == "Gear", S .. "the two sections, part of Gear")
		n:Set("splitGear", true); M.runTimers()
		check(cat(n, 5001) == "GearSoulbound", S .. "bind on pickup: Gear: Soulbound")
		check(cat(n, 5002) == "GearBoE", S .. "bind on equip, not yet bound: Gear: BoE")
		check(cat(n, 5003) == "GearSoulbound", S .. "bind on equip, bound since: Gear: Soulbound")
		check(cat(n, 5004) == "Gear" and cat(n, 5005) == "Gear", S .. "binds when used, or doesn't bind: stays in Gear")
		check(cat(n, 5006) == "Junk" and cat(n, 2589) == "TradeGoods", S .. "grey gear is still Junk; nothing else moves")
		local order = n.db.laneOrder
		local g = indexOf(order, "Gear")
		check(g and order[g + 1] == "GearSoulbound" and order[g + 2] == "GearBoE", S .. "they join Section Order right after Gear")
		-- the window
		n.Window:Show(); n:RefreshViews(true); M.runTimers()
		local V = n.Window.main
		local lanes = table.concat(V.laneIds or {}, ",")
		check(lanes:find("GearSoulbound", 1, true) and lanes:find("GearBoE", 1, true), S .. "By Section shows both sections (" .. lanes .. ")")
		local labels = {}
		for _, h in pairs(n.Buttons.lanes[V.child] or {}) do if h:IsShown() and h.laneId then labels[h.laneId] = h.text.text end end
		check(labels.GearSoulbound == "Gear: Soulbound" and labels.GearBoE == "Gear: BoE", S .. "titled Gear: Soulbound and Gear: BoE")
		-- the Gear tab still shows them
		local shownOnGear = 0
		V.st.sheet = "Gear"; n:RefreshViews(true); M.runTimers()
		local shown = V:Filtered()
		for _, r in ipairs(shown) do if r.itemID == 5001 or r.itemID == 5002 then shownOnGear = shownOnGear + 1 end end
		check(shownOnGear == 2, S .. "the Gear tab still has the split gear (" .. shownOnGear .. ")")
		V.st.sheet = "All"; n:RefreshViews(true); M.runTimers()
		-- binding moves it: the boots get equipped and come back bound
		M.bags[0][2].bound = true; n:Scan(); M.runTimers()
		check(cat(n, 5002) == "GearSoulbound", S .. "the BoE boots, once bound: Gear: Soulbound on the next scan")
		M.bags[0][2].bound = nil; n:Scan(); M.runTimers()
		-- a tick off keeps that kind in Gear
		n:Set("splitGearTypes", { BoE = false }); M.runTimers()
		check(cat(n, 5002) == "Gear" and cat(n, 5001) == "GearSoulbound", S .. "Gear: BoE unticked: BoE gear in Gear, Soulbound still split")
		n:Set("splitGearTypes", {}); M.runTimers()
		-- custom moves win; a move to a split section waits in Gear while it's off
		n.Sections:Move(5001, "Other")
		check(cat(n, 5001) == "Other", S .. "a piece you moved stays where you moved it")
		n.Sections:Move(5005, "GearBoE")
		check(cat(n, 5005) == "GearBoE", S .. "a move into Gear: BoE")
		n:Set("splitGear", false); M.runTimers()
		check(cat(n, 5005) == "Gear" and n.db.sectionMoves[5005] == "GearBoE" and cat(n, 5002) == "Gear", S .. "split off: everything back in Gear, the move kept")
		n:Set("splitGear", true); M.runTimers()
		check(cat(n, 5005) == "GearBoE", S .. "on again: back in Gear: BoE")
		-- the 1.6.3 lesson: moves, order and hiding survive a reload
		table.remove(order, indexOf(order, "GearBoE")); table.insert(order, 1, "GearBoE")
		n.db.sectionHide = n.db.sectionHide or {}; n.db.sectionHide.GearBoE = { vendor = true }
		n.db.pinnedSections.GearSoulbound = true
		n, M = reload()
		check(n.db.splitGear == true and cat(n, 5005) == "GearBoE" and n.db.sectionMoves[5005] == "GearBoE", S .. "after a reload: still split, the move kept")
		check(n.db.laneOrder[1] == "GearBoE" and n.db.sectionHide.GearBoE and n.db.sectionHide.GearBoE.vendor == true and n.db.pinnedSections.GearSoulbound == true,
			S .. "and Gear: BoE's place in the order, its vendor hiding and Gear: Soulbound's pin")
		-- saved settings are checked
		local db = copy(_G.BagSmithDB); db.profiles.Default.splitGearTypes = { BoE = false, Bogus = false, Soulbound = "no" }
		n, M = session(db, copy(_G.BagSmithCharDB), skin)
		check(n.db.splitGearTypes.BoE == false and n.db.splitGearTypes.Bogus == nil and n.db.splitGearTypes.Soulbound == nil, S .. "saved ticks are checked at load")
		n:Set("splitGearTypes", {}); M.runTimers()
		-- profile sharing
		local code = n.Share:Export()
		local name = code and n.Share:Import(code, "Shared Gear")
		local prof = name and BagSmithDB.profiles[name]
		check(prof and prof.splitGear == true and prof.sectionMoves[5005] == "GearBoE", S .. "a shared profile keeps the split and its moves")
		-- Settings > Sections
		local P = n.SettingsPanel; P:Show(); P:ShowPage("sections"); M.runTimers()
		local heads = {}
		for _, w in ipairs(P.pools.head) do if w:IsShown() then heads[#heads + 1] = w.text.text end end
		check(table.concat(heads, "|") == "Sections|Which Section an Item Goes To|Keys & Reagent Bag|Consumables|Gear|Move, Pin and Hide Sections", S .. "a Gear card after Consumables: " .. table.concat(heads, "|"))
		local function box(key) for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == key then return w end end end
		check(box("splitGear") and box("splitGear").text.text == "Split Gear by Binding" and box("splitGear_Soulbound") and box("splitGear_Soulbound").text.text == "Gear: Soulbound" and box("splitGear_BoE"), S .. "Split Gear by Binding, with a tick for each")
		local t = box("splitGear_BoE"); t.box:SetChecked(false); t.box:GetScript("OnClick")(t.box); M.runTimers()
		check(n.db.splitGearTypes.BoE == false and cat(n, 5002) == "Gear", S .. "unticking Gear: BoE in Settings keeps it in Gear")
		local rows = {}
		for _, l in ipairs(P.pools.list) do if l:IsShown() then for _, r in ipairs(l.rows) do if r:IsShown() then rows[r.id] = r end end end end
		check(rows.GearSoulbound and not rows.GearBoE, S .. "the table lists only the split sections in use")
		P:SetQuery("soulbound"); M.runTimers()
		check(box("splitGear"), S .. "searching \"soulbound\" finds it")
		P:SetQuery(""); P:Hide()
		_G.BagSmithDB = nil
	end
end)()
;(function()
	-- ======== 1.7.0-beta6: the What's New 1.7 card (a draft for Shweep's review) ========
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {} } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers()
	local WN = n.WhatsNew
	local e = WN.ENTRIES[1]
	local text = table.concat(e.items, " ")
	-- (1.7.0-beta12, by design: Shweep's review) nine bullets: Mail and Trade, Section Values at Any Width and Smoother
	-- Clean Up added (the body scrolls when a release is taller than the card)
	check(e.v == "1.7.0" and e.heading == "BagSmith 1.7" and #e.items == 9, "What's New: the 1.7 card leads, with nine bullets")
	check(WN.ENTRIES[2].v == "1.6.0" and WN.ENTRIES[3].v == "1.5.1", "and 1.6's card follows, then 1.5.1's")
	local heads = {}
	for _, it in ipairs(e.items) do heads[#heads + 1] = it:match("^|cfffac775(.-):|r") end
	check(table.concat(heads, "|") == "A Smarter Loot Helper|Protect|Mail and Trade|Split Gear by Binding|Lock Windows|Pinned Sections Stand Out|Simpler Section Settings|Section Values at Any Width|Smoother Clean Up", "its bullets: " .. table.concat(heads, "|"))
	check(text:find("Settings > Loot Helper", 1, true) and text:find("Settings > Sections", 1, true) and text:find("Settings > Windows", 1, true) and text:find("Settings > Style", 1, true), "each names where its setting is")
	check(text:find("Gear: Soulbound and Gear: BoE", 1, true) and text:find("Full-Width Recent", 1, true) and text:find("Highlight Pinned Sections", 1, true), "with the settings' own names")
	check(not text:find("\226\128\148") and not text:find("Show More", 1, true) and not text:find("Text Size", 1, true) and not text:find("Font", 1, true), "no em dashes; nothing that isn't in 1.7 (Show More, Text Size, Font)")
	n.version = "1.7.0-beta6"   -- (the mock reports 0.1.0 for every build; a beta counts as its release)
	local tabs = WN:Tabs()
	check(#tabs == 5 and tabs[1].v == "1.7.0" and tabs[5].v == "1.4.0", "five tabs, 1.7 first; 1.3 drops off the row")
	WN:ShowLatest(); M.runTimers()
	local f = _G.BagSmithWhatsNew
	check(f and f:IsShown() and f.sel == 1 and f.entries[1].v == "1.7.0", "the card opens on 1.7")
	WN:Close()
	_G.BagSmithDB = nil
end)()
;(function()
	-- ======== 1.7.0-beta6: Gear Sets still come first with Split Gear by Binding on ========
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 5001, name = "Bound Helm", q = 2, class = 4, subclass = 4, price = 50, equip = "INVTYPE_HEAD", bind = 1, bound = true })
	M.put(0, 2, { id = 5002, name = "Tradeable Boots", q = 2, class = 4, subclass = 2, price = 40, equip = "INVTYPE_FEET", bind = 2 })
	M.put(0, 3, { id = 5007, name = "Spare Bracers", q = 2, class = 4, subclass = 2, price = 35, equip = "INVTYPE_WRIST", bind = 2 })
	M.installEquipmentSets()
	M.addSet("Tank", { [1] = M.bagLoc(0, 1), [8] = M.bagLoc(0, 2) })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list", splitGear = true, recentSection = false } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); n:RefreshViews(true); M.runTimers()
	local V = n.Window.main
	local lanes = "," .. table.concat(V.laneIds or {}, ",") .. ","
	check(lanes:find(",~gs:Tank,", 1, true) and lanes:find(",GearBoE,", 1, true) and not lanes:find(",GearSoulbound,", 1, true),
		"gear sets: the set's helm and boots show under Tank, the spare bracers under Gear: BoE, and Gear: Soulbound has nothing left (" .. lanes .. ")")
	M.removeEquipmentSets()
	_G.BagSmithDB = nil
end)()
;(function()
	-- ======== 1.7.0-beta6: the Type column keeps the slot for a ring or trinket in a split Gear section ========
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 5011, name = "Band of Trading", q = 2, type = "Armor", sub = "Miscellaneous", class = 4, subclass = 0, price = 60, equip = "INVTYPE_FINGER", bind = 2 })
	M.put(0, 2, { id = 5012, name = "Bound Charm", q = 2, type = "Armor", sub = "Miscellaneous", class = 4, subclass = 0, price = 60, equip = "INVTYPE_TRINKET", bind = 1, bound = true })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { splitGear = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local function rec(id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
	local ring, charm = rec(5011), rec(5012)
	check(ring.cat == "GearBoE" and charm.cat == "GearSoulbound", "the ring in Gear: BoE, the trinket in Gear: Soulbound")
	check(ring.itemSubType == "Miscellaneous" and n:TypeText(ring) == "Finger" and n:TypeText(charm) == "Trinket" and n:TypeText(ring) == n:SlotText(ring) and n:SlotText(ring) ~= "" and n:TypeText(charm) == n:SlotText(charm),
		"their Type is their slot (" .. tostring(n:TypeText(ring)) .. ", " .. tostring(n:TypeText(charm)) .. "), as in Gear, not \"Miscellaneous\"")
	_G.BagSmithDB = nil
end)()
