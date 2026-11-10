;(function()
	-- 1.6.0-beta8: the 1.6.0-beta7 audit's A1, and Shweep's changes after it.
	--  A1  a Loot Helper pick ends when nothing is offered (as when its own row goes), and with a new loot window
	--  Narrow Windows: Qty, like Item, is never set aside; every other column is ticked by default; the card says so
	--  Disenchant Helper: AH prices count after the AH's 5% cut; Selling at the AH Must Beat the Vendor By (20%);
	--      Leveling Enchanting (Automatic below the rank's cap, Always, Never): materials at full value, margin zero

	-- ---- A1 (the audit's fixture: Boots 600 and Trinket 1,000 by AH price, loot worth 1,000,000 waiting)
	local function lootBoot(skin)
		package.loaded.mock = nil
		local M = require("mock")
		for b = 0, 5 do M.sizes[b] = 0 end; M.sizes[0] = 3
		M.maxStack = { [7001] = 1, [7002] = 1, [7004] = 1, [9001] = 1 }
		M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
		M.put(0, 2, { id = 7002, name = "Common Trinket", q = 1, count = 1, class = 15, subclass = 0, price = 5 })
		M.put(0, 3, { id = 7004, name = "Old Bracers", q = 1, count = 1, class = 4, subclass = 1, price = 50, ilvl = 10, equip = "INVTYPE_WRIST" })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, makeRoom = true, priceSource = "auctionator", makeRoomValue = "ah" } } }
		local function idOf(v) return type(v) == "number" and v or tonumber(tostring(v):match("item:(%d+)")) end
		local prices = { [7001] = 600, [7002] = 1000, [7004] = 2000, [9001] = 1000000 }
		_G.Auctionator = { API = { v1 = {
			GetAuctionPriceByItemLink = function(c, l) return prices[idOf(l)] or 10000 end,
			GetAuctionPriceByItemID = function(c, id) return prices[idOf(id)] or 10000 end,
		} } }
		_G.BlackthornesTS_API = nil
		local real = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(v) if idOf(v) == 9001 then return "Waiting Loot", "item:9001", 1, 1, 0, "Misc", "Misc", 1, "", 1, 1000000, 15, 0 end; return real(v) end
		_G.GetNumLootItems = function() return 1 end
		_G.GetLootSlotType = function() return 1 end
		_G.GetLootSlotLink = function() return "|Hitem:9001:0|h[Waiting Loot]|h" end
		_G.GetLootSlotInfo = function() return "icon", "Waiting Loot", 1, nil, 1 end
		_G.LootSlot = function() M.lootRequested = true end
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id; M.cursorFrom = { bag, slot } end
		_G.ClearCursor = function() M.cursorItem = nil; M.cursorFrom = nil end
		_G.DeleteCursorItem = function() if M.cursorFrom then M.bags[M.cursorFrom[1]][M.cursorFrom[2]] = nil end; M.cursorItem = nil end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		M.fire("LOOT_OPENED"); M.runTimers(); M.runTimers()
		return n, M
	end
	local function act(n) return n.MakeRoom.frame.act:IsShown() and n.MakeRoom.frame.act.label.text or nil end
	local function rowFor(n, name) for _, r in ipairs(n.MakeRoom.frame.destroyRows or {}) do if r:IsShown() and r.name.text == name then return r end end end
	local function fav(n, ids) for _, r in ipairs(n.items) do if ids[r.itemID] then n.Marks:ToggleFavorite(r) end end; n:Fire("ITEMS_CHANGED") end
	for _, skin in ipairs({ "modern", "classic" }) do
		local n, M = lootBoot(skin)
		local R = n.MakeRoom
		check(act(n) == "Destroy Sturdy Boots", skin .. ": the Boots (600) first by AH price")
		rowFor(n, "Common Trinket").onPick()
		check(act(n) == "Destroy Common Trinket" and R.selPicked, skin .. ": the player picks the Trinket")
		-- partial: only the picked row goes; the pick ends, the default is the cheapest left
		fav(n, { [7002] = true })
		check(act(n) == "Destroy Sturdy Boots" and not R.selPicked, skin .. ": the picked row is protected: the pick ends, back to the cheapest")
		fav(n, { [7002] = true })
		check(act(n) == "Destroy Sturdy Boots", skin .. ": and it doesn't come back with the row")
		-- complete: every row goes, then they come back
		rowFor(n, "Common Trinket").onPick()
		fav(n, { [7001] = true, [7002] = true, [7004] = true })
		check(act(n) == nil and not R.selPicked and R.sel == nil, skin .. ": nothing offered: no action, and the pick ends (A1)")
		fav(n, { [7001] = true, [7002] = true, [7004] = true })
		check(act(n) == "Destroy Sturdy Boots", skin .. ": items offered again: the cheapest, not the old pick (" .. tostring(act(n)) .. ")")
		-- a new loot window starts from the cheapest
		rowFor(n, "Common Trinket").onPick()
		M.fire("LOOT_CLOSED"); M.runTimers(); M.fire("LOOT_OPENED"); M.runTimers(); M.runTimers()
		check(act(n) == "Destroy Sturdy Boots" and not R.selPicked, skin .. ": a new loot window starts from the cheapest (" .. tostring(act(n)) .. ")")
	end

	-- ---- Narrow Windows: Qty never set aside; every other column ticked by default
	local function colBoot(prof)
		package.loaded.mock = nil
		local M = require("mock")
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = "modern", view = "list", grp = "type" }
		for k, v in pairs(prof or {}) do p[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
		_G.Auctionator = nil; _G.BlackthornesTS_API = nil
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); M.runTimers(); M.runTimers()
		return n, M, n.Window.main
	end
	local ALL = "t,age,v,ah,w,sl,rq,il,bd,fv,cc,jk"
	local n, M, V = colBoot()
	check(table.concat(n.db.colAside, ",") == ALL and table.concat(n.db.bankColAside, ",") == ALL, "every column but Item and Qty ticked by default, both windows: " .. table.concat(n.db.colAside, ","))
	check(not n.IndexOf(n.db.colAside, "c") and not n.IndexOf(n.db.colAside, "n"), "neither Qty nor Item is in the list")
	V.scroll.w = 394; V.trustedRowWidth = nil
	local plan = V:ColumnPlan()
	check(table.concat(plan.dropped, ",") == "t", "at 440 with the default columns, only Type is set aside, as before (" .. table.concat(plan.dropped, ",") .. ")")
	V.scroll.w = 160; V.trustedRowWidth = nil
	plan = V:ColumnPlan()
	local keys = {}; for _, c in ipairs(plan) do keys[#keys + 1] = c.key end
	check(n.IndexOf(keys, "c") and n.IndexOf(keys, "n"), "however narrow, Qty and Item stay (" .. table.concat(keys, ",") .. ")")
	check(n.View.MinWidthFor(false) == 440 and n.View.MinWidthFor(true) == 500, "everything ticked: the windows' narrowest widths are the plain 440 and 500")
	-- a saved list with Qty in it (from beta6 or beta7): Qty is dropped on load; and never set aside at run time
	n, M, V = colBoot({ colAside = { "c", "t" }, bankColAside = { "jk", "c" } })
	check(table.concat(n.db.colAside, ",") == "t" and table.concat(n.db.bankColAside, ",") == "jk", "Qty is taken out of a saved list on load")
	n.db.colAside = { "c", "t", "age" }
	check(table.concat(V:AsideOrder(), ",") == "t,age", "and skipped if it gets in at run time")
	n.db.cols = { "c", "t" }; n.db.colAside = { "c" }
	check(n.View.MinWidthFor(false) == 440, "Qty always counts as kept toward the narrowest width")
	-- the card
	n, M, V = colBoot()
	local P = n.SettingsPanel
	P:Show(); M.runTimers(); P:ShowPage("bagcols"); M.runTimers()
	local txt = {}
	for _, w in ipairs(P.pools.text or {}) do if w:IsShown() then txt[#txt + 1] = w.text.text end end
	check(table.concat(txt, " | "):find("Item and Qty are always shown.", 1, true) ~= nil, "the card says Item and Qty are always shown")
	local list
	for _, l in ipairs(P.pools.list or {}) do if l:IsShown() and l.rows[1] and l.rows[1]:IsShown() and l.rows[1].id == "t" then list = l end end
	local rows = {}
	for _, r in ipairs(list and list.rows or {}) do if r:IsShown() then rows[#rows + 1] = r.id .. (r.box:GetChecked() and "+" or "-") end end
	check(table.concat(rows, " ") == "t+ age+ v+ w+ bd+ fv+ cc+ jk+", "the default card: every shown column ticked, in the default order, no Qty: " .. table.concat(rows, " "))
	P:Hide()

	-- ---- the Disenchant Helper's recommendation
	package.loaded.mock = nil
	M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
	_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function() return 1 end, GetAuctionPriceByItemID = function() return 1 end } } }
	local skill = { rank = 150, max = nil }
	_G.GetNumSkillLines = function() return 1 end
	_G.GetSkillLineInfo = function() return "Enchanting", false, nil, skill.rank, 0, 0, skill.max end
	n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE = n.Disenchant
	local function v(vendor, ah, mats) return DE:Verdict({ vendor = vendor, ah = ah, mats = mats }) end
	check(n.db.deAhMargin == 0.20 and n.db.deLeveling == "auto", "defaults: AH must beat the vendor by 20%; leveling Automatic")
	-- Shweep's screenshot (Enchanting 150 of 150: not leveling)
	check(v(495, 500, 161) == "vendor", "the sword: 5s on the AH is 4s 75c after the cut, less than the vendor's 4s 95c: Vendor")
	check(v(60, 200, 145) == "ah", "the linen pants: 1s 90c after the cut against 60c: Sell at AH")
	check(v(226, 300, 145) == "ah", "the britches: 2s 85c after the cut is 26% over 2s 26c: Sell at AH")
	n:Set("deAhMargin", 0.30)
	check(v(226, 300, 145) == "vendor", "at 30% the britches go to the vendor")
	n:Set("deAhMargin", 0.20)
	check(v(0, 100, 10) == "ah", "no vendor price: any AH price wins")
	-- materials go through the AH too
	check(v(100, 0, 112) == "vendor", "mats 1s 12c (1s 06c after the cut) against a 1s vendor price: not 10% better, so Vendor")
	check(v(100, 0, 120) == "de", "mats 1s 20c (1s 14c after the cut): 14% better: Disenchant")
	-- leveling
	skill.rank, skill.max = 120, 150
	local lv, rk, cap = DE:Leveling()
	check(lv and rk == 120 and cap == 150, "Enchanting 120 of 150: leveling, automatically")
	-- (1.6.0-beta10, by design: Shweep) leveling allows up to 10% less than selling (it was a tie at least)
	check(v(100, 0, 90) == "de" and v(100, 0, 89) == "vendor", "leveling: mats at full value, up to 10% less than selling is enough")
	skill.rank, skill.max = 150, 150
	check(not DE:Leveling() and v(100, 0, 100) == "vendor", "at the cap: not leveling")
	skill.rank, skill.max = 120, nil
	lv, rk, cap = DE:Leveling()
	check(lv and cap == 150, "no maximum from the game: the next cap above the skill (150)")
	skill.rank = 225
	check(not DE:Leveling(), "exactly at a cap with no maximum given: counted as at the cap")
	skill.rank = 300
	check(not DE:Leveling(), "300: done")
	n:Set("deLeveling", "always")
	check(DE:Leveling() and v(100, 0, 100) == "de", "Always: leveling whatever the skill")
	skill.rank, skill.max = 120, 150
	n:Set("deLeveling", "never")
	check(not DE:Leveling() and v(100, 0, 100) == "vendor", "Never: never")
	n:Set("deLeveling", "auto")
	-- the Settings page
	local P2 = n.SettingsPanel
	P2:Show(); M.runTimers(); P2:ShowPage("dehelper"); M.runTimers()
	local labels, helps = {}, {}
	for _, kind in ipairs({ "step", "seg" }) do
		for _, w in ipairs(P2.pools[kind] or {}) do if w:IsShown() and w.key then labels[w.key] = w.text.text; helps[w.key] = w.help and w.help.text end end
	end
	check(labels.deAhMargin == "Selling at the AH Must Beat the Vendor By" and helps.deAhMargin == "Selling at the AH is only recommended when, after the auction house's 5% cut, it pays this much more than the vendor.", "Settings > Disenchant Helper: Selling at the AH Must Beat the Vendor By, with its help")
	check(labels.deLeveling == "Leveling Enchanting" and helps.deLeveling and helps.deLeveling:find("Automatic does this until your Enchanting reaches its current cap.", 1, true), "and Leveling Enchanting (Automatic, Always, Never)")
	P2:Hide()
	n:Set("deAhMargin", 5); check(n.db.deAhMargin == 2, "the margin is kept within 0 to 200%")
	n:Set("deLeveling", "sometimes"); check(n.db.deLeveling == "auto", "an unknown leveling choice is Automatic")
end)()

;(function()
	-- 1.6.0-beta8: what the Disenchant Helper shows while leveling: "(for leveling)" after Disenchant, and the skill note
	package.loaded.mock = nil
	local M = require("mock")
	local DEID = 13262
	M.put(0, 1, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
	local skill = { rank = 120, max = 150 }
	_G.IsSpellKnown = function(id) return id == DEID end
	_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
	_G.GetNumSkillLines = function() return 2 end
	_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, skill.rank, 0, 0, skill.max end
	_G.RegisterStateDriver = function() end
	_G.UnregisterStateDriver = function() end
	_G.InCombatLockdown = function() return false end
	_G.GetCVar = function(k) if k == "autoLootDefault" then return "1" end end
	-- the dagger: 11s on the AH (10s 45c after the cut, over 20% more than the vendor's 8s); its materials come to a
	-- little more at full value, short of 10% more after the cut
	local prices = { [7002] = 1100, [10940] = 120, [10938] = 300, [10939] = 500, [10978] = 800, [11083] = 150, [11082] = 800, [11138] = 1200 }
	_G.Auctionator = { API = { v1 = {
		GetAuctionPriceByItemLink = function(_, link) local id = tonumber(link:match("item:(%d+)")); return id and prices[id] end,
		GetAuctionPriceByItemID = function(_, id) return prices[id] end,
		GetAuctionAgeByItemLink = function() return nil end,
	} } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE = n.Disenchant
	DE:Show(); M.runTimers()
	local f = DE.frame
	local e = DE.current
	local function starts(t, p) return type(t) == "string" and t:sub(1, #p) == p end   -- (then "(DE estimate)" or your results)
	check(e and e.itemID == 7002 and e.mats and e.mats >= e.ah * 0.95 and e.mats * 0.95 < e.ah * 0.95 * 1.10, ("the dagger: mats %s against 11s on the AH"):format(tostring(e and e.mats)))
	check(e.verdict == "de" and starts(f.cur.verdict.text, "Disenchant (for leveling)"), "Enchanting 120 of 150: Disenchant (for leveling) (" .. tostring(f.cur.verdict.text) .. ")")
	-- (1.6.0-beta10, by design: Shweep's new note)
	check(f.status.text:find("Leveling Enchanting (120 of 150): disenchanting is favored.", 1, true) ~= nil, "the note gives the skill: " .. tostring(f.status.text))
	n:Set("deLeveling", "never"); M.runTimers()
	e = DE.current
	check(e.verdict == "ah" and starts(f.cur.verdict.text, "Sell at AH") and not f.status.text:find("Leveling", 1, true), "Never: Sell at AH, and no leveling note (" .. tostring(f.cur.verdict.text) .. ")")
	skill.rank = 150
	n:Set("deLeveling", "auto"); M.runTimers()
	check(DE.current.verdict == "ah" and not f.status.text:find("Leveling", 1, true), "Automatic at the cap (150 of 150): as Never")
	skill.max = nil
	n:Set("deLeveling", "always"); M.runTimers()
	check(DE.current.verdict == "de" and starts(f.cur.verdict.text, "Disenchant (for leveling)") and f.status.text:find("Leveling Enchanting: disenchanting is favored.", 1, true) ~= nil, "(1.6.0-beta10, by design: the new note) Always at 150 with no maximum given: for leveling, and the note without numbers: " .. tostring(f.status.text))
	DE:Close()
end)()
