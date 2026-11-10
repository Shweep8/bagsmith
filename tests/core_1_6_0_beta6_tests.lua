;(function()
	-- 1.6.0-beta6: the 1.6.0-beta5 audit's findings, past what its own probes check (they're in the suite too:
	-- core_audit_1_6_0_beta5_*_tests.lua), and Shweep's Narrow Windows choice.
	--  F1  a different price source, or a different price to rank by, redoes both open helpers; a Loot Helper offer is only
	--      good at the value it was offered at (Shweep: "That item's price changed since it was offered, ...")
	--  F2  the Disenchant Helper never repaints in combat, from any caller; a row click in combat does nothing (Shweep)
	--  F3  the Disenchant button is armed only while the helper is really open, through every close route
	--  F4  a move or resize crossing into combat finishes outside combat
	--  F5  a price with no scan date says "Scan date unknown" (Shweep's wording); an old one, "Over 3 weeks old"
	--  F6  locked marks don't count toward a corner's 16
	--  advisory: no infinite, zero, negative or NaN price from either source
	--  Narrow Windows (Shweep): which columns a narrow List view sets aside, and in what order, per window

	-- ---- the Loot Helper and prices (the audit's fixture: Boots and a Trinket, loot worth 1,000,000 waiting)
	local function lootBoot(skin, prof)
		package.loaded.mock = nil
		local M = require("mock")
		for b = 0, 5 do M.sizes[b] = 0 end; M.sizes[0] = 2
		M.maxStack = { [7001] = 1, [7002] = 1, [9001] = 1 }
		M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
		M.put(0, 2, { id = 7002, name = "Common Trinket", q = 1, count = 1, class = 15, subclass = 0, price = 5 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = skin, deEnabled = true, makeRoom = true, priceSource = "auctionator", makeRoomValue = "ah" }
		for k, v in pairs(prof or {}) do p[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
		_G.IsSpellKnown = function(id) return id == 13262 end
		_G.GetNumSkillLines = function() return 1 end
		_G.GetSkillLineInfo = function() return "Enchanting", false, nil, 150 end
		_G.RegisterStateDriver = function() end; _G.UnregisterStateDriver = function() end
		local function idOf(v) return type(v) == "number" and v or tonumber(tostring(v):match("item:(%d+)")) end
		local prices = { a = { [7001] = 600, [7002] = 1000, [9001] = 1000000 }, b = { [7001] = 100000, [7002] = 1, [9001] = 1000000 } }
		M.prices = prices
		_G.Auctionator = { API = { v1 = {
			GetAuctionPriceByItemLink = function(c, l) return prices.a[idOf(l)] or 10000 end,
			GetAuctionPriceByItemID = function(c, id) return prices.a[idOf(id)] or 10000 end,
			GetAuctionAgeByItemLink = function() return M.aAge end, GetAuctionAgeByItemID = function() return M.aAge end,
		} } }
		_G.BlackthornesTS_API = { version = 1, GetPrice = function(v) return prices.b[idOf(v)] or 10 end, GetPriceAge = function() return M.bAge end }
		local real = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(v) if idOf(v) == 9001 then return "Waiting Loot", "item:9001", 1, 1, 0, "Misc", "Misc", 1, "", 1, 1000000, 15, 0 end; return real(v) end
		_G.GetNumLootItems = function() return 1 end
		_G.GetLootSlotType = function() return 1 end
		_G.GetLootSlotLink = function() return "|Hitem:9001:0|h[Waiting Loot]|h" end
		_G.GetLootSlotInfo = function() return "icon", "Waiting Loot", 1, nil, 1 end
		_G.LootSlot = function() M.lootRequested = true end
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id; M.cursorFrom = { bag, slot } end
		_G.ClearCursor = function() M.cursorItem = nil; M.cursorFrom = nil end
		_G.DeleteCursorItem = function() if M.cursorFrom then M.bags[M.cursorFrom[1]][M.cursorFrom[2]] = nil end; M.cursorItem = nil; M.deleted = (M.deleted or 0) + 1 end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Disenchant:Show(); M.runTimers()
		M.fire("LOOT_OPENED"); M.runTimers(); M.runTimers()
		return n, M
	end
	local function firstShown(rows) for _, r in ipairs(rows or {}) do if r:IsShown() then return r.name.text, r.value.text end end end
	local function capturePrints(n) local out = {}; local real = n.Print; n.Print = function(self, fmt, ...) out[#out + 1] = select("#", ...) > 0 and fmt:format(...) or fmt; return real(self, fmt, ...) end; return out end

	for _, skin in ipairs({ "modern", "classic" }) do
		-- F1: Rank Suggestions By changing while the panel is open: the same refresh
		local n, M = lootBoot(skin)
		local R = n.MakeRoom
		check(firstShown(R.frame.destroyRows) == "Sturdy Boots", skin .. ": ranked by AH price, the Boots (600) first")
		n:Set("makeRoomValue", "vendor"); M.runTimers(); M.runTimers()
		local _, ds = R:Suggestions(R:Waiting())
		check(firstShown(R.frame.destroyRows) == ds[1].rec.name and ds[1].rec.name == "Common Trinket", skin .. ": switched to Vendor Price, the panel re-ranks at once (" .. tostring(firstShown(R.frame.destroyRows)) .. ")")

		-- F1: the offer remembers its value; a fresh scan changing the price refuses the click
		n, M = lootBoot(skin)
		R = n.MakeRoom
		local prints = capturePrints(n)
		M.prices.a[7001] = 650   -- a fresh Auctionator scan while the panel stays open, no refresh between
		R.frame.act:GetScript("OnClick")(R.frame.act)
		check(M.bags[0][1] ~= nil and not M.deleted, skin .. ": the price changed after the offer was shown: nothing is destroyed")
		local said = table.concat(prints, " | ")
		check(said:find("That item's price changed since it was offered, so nothing was destroyed. The Loot Helper has updated.", 1, true) ~= nil, skin .. ": and the player is told why, in Shweep's words (" .. said .. ")")
		local v = firstShown(R.frame.destroyRows)
		R.frame.act:GetScript("OnClick")(R.frame.act)
		check(M.bags[0][1] == nil and M.deleted == 1, skin .. ": the panel has updated; the offer at the new price goes ahead (" .. tostring(v) .. ")")

		-- F1: an open question about an offer closes when the source changes
		n, M = lootBoot(skin, { makeRoomAsk = true })
		R = n.MakeRoom
		R.frame.act:GetScript("OnClick")(R.frame.act)
		local c = n.Popups.confirm
		check(c and c:IsShown() and c.lootHelperKey, skin .. ": Ask Before Destroying on: the click asks")
		n:Set("priceSource", "blackthornes"); M.runTimers(); M.runTimers()
		check(not c:IsShown() and M.bags[0][1] ~= nil, skin .. ": a different price source closes the question; nothing destroyed")

		-- F1: a price addon loading late, with nothing chosen: the helpers follow the new source
		n, M = lootBoot(skin, { priceSource = "blackthornes" })
		local fired = 0
		n:OnSignal("PRICE_SOURCE_CHANGED", function() fired = fired + 1 end)
		local saved = _G.BlackthornesTS_API
		_G.BlackthornesTS_API = nil
		n.AH:CheckSource(); fired = 0   -- Blackthornes gone: Auctionator in use
		_G.BlackthornesTS_API = saved
		M.fire("ADDON_LOADED", "Blackthornes_TS"); M.runTimers(); M.runTimers()
		check(fired == 1 and n.AH:Source() == "blackthornes", skin .. ": Blackthornes Tradeskills loading late changes the source, and the helpers are told (" .. fired .. ")")
		check(n.Disenchant.current and n.Disenchant.current.ah == n.Disenchant:Entries()[1].ah, skin .. ": the Disenchant Helper shows its prices")
		n:Set("dense", true); M.runTimers()
		check(fired == 1, skin .. ": an unrelated setting doesn't")
	end

	-- ---- F5 and the advisory: ages and prices at the source boundary
	local n, M = lootBoot("modern")
	local AH = n.AH
	local rec = { itemID = 7001, link = "item:7001", count = 1 }
	n.db.cols = { "ah" }
	local function tipLines()
		local lines = {}
		local tip = { AddDoubleLine = function() end, AddLine = function(self, s) lines[#lines + 1] = s end }
		AH:AddTooltipLines(tip, rec)
		return table.concat(lines, " | ")
	end
	n:Set("priceSource", "blackthornes"); M.runTimers()
	M.bAge = nil
	check(AH:AgeInfo(rec) == "unknown" and tipLines():find("Scan date unknown", 1, true) and not tipLines():find("Over 3 weeks", 1, true), "Blackthornes, no scan date of your own: \"Scan date unknown\"")
	M.bAge = 30 * 86400
	check(AH:AgeInfo(rec) == "old" and AH:Age(rec) == nil and tipLines():find("Over 3 weeks old", 1, true), "an old scan: \"Over 3 weeks old\"; Age stays nil as before")
	M.bAge = 2 * 86400 + 5
	check(AH:AgeInfo(rec) == 2 and tipLines():find("Seen 2 days ago", 1, true), "a recent scan: its age")
	for _, bad in ipairs({ 0 / 0, math.huge, -5 }) do M.bAge = bad; check(AH:AgeInfo(rec) == "unknown", "a nonsense age is unknown: " .. tostring(bad)) end
	n:Set("priceSource", "auctionator"); M.runTimers()
	M.aAge = nil
	check(AH:AgeInfo(rec) == "unknown" and tipLines():find("Scan date unknown", 1, true), "Auctionator with no age for a price: \"Scan date unknown\" too")
	M.aAge = 3
	check(AH:AgeInfo(rec) == 3 and tipLines():find("Seen 3 days ago", 1, true), "Auctionator's age in days, as before")
	for _, bad in ipairs({ math.huge, 0, -1, 0 / 0 }) do
		M.prices.a[7001] = bad
		check(AH:Price(rec) == nil, "Auctionator: an unusable price is no price: " .. tostring(bad))
	end
	M.prices.a[7001] = 600
	n:Set("priceSource", "blackthornes"); M.runTimers()
	M.prices.b[7001] = math.huge
	check(AH:Price(rec) == nil and AH:StackValue(rec) == nil, "Blackthornes: infinity is no price")

	-- ---- the Disenchant Helper around combat: the strict model (every change to the helper, its item panel or the button in
	-- combat is recorded), combat entered as the game does it (the state driver locks, then the events)
	local DEID = 13262
	local function deBoot(prof, profiles)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
		M.put(0, 2, { id = 7003, name = "Fine Gloves", q = 2, count = 1, class = 4, subclass = 1, price = 400, ilvl = 22, equip = "INVTYPE_HAND" })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = "modern", deEnabled = true, combatFade = false }
		for k, v in pairs(prof or {}) do p[k] = v end
		local all = { Default = p }
		for k, v in pairs(profiles or {}) do all[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = all }
		_G.IsSpellKnown = function(id) return id == DEID end
		_G.GetNumSkillLines = function() return 2 end
		_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, 150 end
		_G.RegisterStateDriver = function() end
		_G.UnregisterStateDriver = function() end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local DE = n.Disenchant
		DE:Show(); M.runTimers()
		local f = DE.frame
		local blocked = {}
		for fr, label in pairs({ [f] = "DE.frame", [f.cur] = "DE.frame.cur", [DE:Button()] = "the button" }) do
			fr.protected = true; fr.IsProtected = function(self) return self.protected end
			for _, m in ipairs({ "Show", "Hide", "SetPoint", "ClearAllPoints", "SetSize", "SetParent", "StartMoving", "StartSizing", "StopMovingOrSizing" }) do
				local orig = fr[m]
				if orig then fr[m] = function(self, ...) if M.combat then blocked[#blocked + 1] = m .. " " .. label end; return orig(self, ...) end end
			end
		end
		n.blockedLog = blocked
		return n, M, DE, f
	end
	local function driver(M, DE, state)
		local b = DE:Button()
		local was = M.combat; M.combat = false
		local fn = assert(loadstring(b:GetAttribute("_onstate-bscombat")))
		setfenv(fn, { self = b, newstate = state }); fn()
		M.combat = was
	end
	local function combat(M, DE, on)
		if not on then M.combat = false end
		driver(M, DE, on and "lock" or "open")
		M.combat = on; M.fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED"); M.runTimers()
	end
	local function armed(DE) local b = DE:Button(); return b:GetAttribute("type") == "spell" and b:GetAttribute("target-slot") ~= nil end
	local function clean(n) return #n.blockedLog == 0, table.concat(n.blockedLog, ", ") end

	for _, skin in ipairs({ "modern", "classic" }) do
		-- F2: a row click in combat does nothing (Shweep); after combat the helper is as it was, armed, and clicks work again
		local n, M, DE, f = deBoot({ skin = skin })
		local first = DE.current
		combat(M, DE, true)
		local r2 = f.rows[2]
		r2:GetScript("OnClick")(r2)
		local ok, log = clean(n)
		check(ok and DE.current == first, skin .. ": a row click in combat changes nothing and touches nothing protected (" .. log .. ")")
		DE:Paint()
		check(clean(n) and DE.refreshPending, skin .. ": a repaint asked for in combat waits for its end")
		combat(M, DE, false)
		check(not DE.refreshPending and armed(DE) and DE.current and DE.current.itemID == first.itemID, skin .. ": after combat: repainted, armed on the same item")
		r2:GetScript("OnClick")(r2)
		check(DE.current and DE.current.itemID == r2.entry.itemID and armed(DE), skin .. ": and a row click selects again")

		-- F3: every close route leaves it disarmed, with or without a refresh waiting; opening again arms it
		local routes = {
			{ "the close button out of combat", function(n, M, DE, f) DE:Close() end, false },
			{ "Escape out of combat", function(n, M, DE, f) f.bsEscape:Hide() end, false },
			{ "the close button in combat, a refresh waiting", function(n, M, DE, f) combat(M, DE, true); DE:Close(); n:Fire("ITEMS_CHANGED"); combat(M, DE, false) end, true },
			{ "Escape in combat, a refresh waiting", function(n, M, DE, f) combat(M, DE, true); f.bsEscape:Hide(); n:Fire("ITEMS_CHANGED"); combat(M, DE, false) end, true },
			{ "the toolbar's toggle in combat, the bags changing", function(n, M, DE, f) combat(M, DE, true); DE:Toggle(); M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); combat(M, DE, false) end, true },
		}
		for _, route in ipairs(routes) do
			n, M, DE, f = deBoot({ skin = skin })
			check(armed(DE), skin .. ", " .. route[1] .. ": armed while open")
			route[2](n, M, DE, f)
			M.runTimers()
			ok, log = clean(n)
			check(not f:IsShown() and not armed(DE) and ok, skin .. ", " .. route[1] .. ": closed and disarmed (" .. log .. ")")
			DE:Refresh()
			check(not armed(DE), skin .. ", " .. route[1] .. ": a late refresh doesn't arm a closed helper")
			DE:Show(); M.runTimers()
			check(f:IsShown() and armed(DE), skin .. ", " .. route[1] .. ": opened again, armed")
		end
		-- closed in combat and opened again before combat ends: it comes back and is armed when combat ends
		n, M, DE, f = deBoot({ skin = skin })
		combat(M, DE, true); DE:Close(); n:Fire("ITEMS_CHANGED"); DE:Show()
		check(not f.bsSoftClosed, skin .. ": wanted again in combat: it's back")
		combat(M, DE, false)
		check(f:IsShown() and armed(DE), skin .. ": and armed when combat ends")

		-- F4: combat starting mid-move, where the game still allows the stop (the event comes before the lock): finished at
		-- once, the spot saved; where it doesn't: finished when combat ends, nothing protected touched in combat
		n, M, DE, f = deBoot({ skin = skin })
		f:GetScript("OnDragStart")(f)
		M.fire("PLAYER_REGEN_DISABLED"); M.runTimers()
		check(not f.bsMoving and type(n.db.dePos) == "table", skin .. ": combat starting mid-move, before the lock: the move ends and its spot is saved")
		n, M, DE, f = deBoot({ skin = skin })
		f.grip:GetScript("OnMouseDown")(f.grip)
		f.w, f.h = 700, 420
		combat(M, DE, true)
		f.grip:GetScript("OnMouseUp")(f.grip)
		ok, log = clean(n)
		check(ok and f.bsSizing, skin .. ": a resize released in combat waits, touching nothing protected (" .. log .. ")")
		combat(M, DE, false)
		check(not f.bsSizing and type(n.db.deSize) == "table" and n.db.deSize[1] == 700 and n.db.deSize[2] == 420, skin .. ": after combat the resize ends and its size is saved")
	end

	-- ---- F6: locked marks don't count toward a corner's 16
	n, M = lootBoot("modern")
	local raw = { iconCorners = { top_left = { "quest_start", "quantity" }, top_right = {}, bottom_left = {}, bottom_right = {} }, iconCornersInserted = {} }
	for i = 1, 16 do raw.iconCorners.top_left[#raw.iconCorners.top_left + 1] = "audit.tail" .. i end
	local name = n.Profiles:Import("Full", raw); n.Profiles:Use(name); M.runTimers()
	local tl = n.db.iconCorners.top_left
	check(#tl == 18 and tl[1] == "quest_start" and tl[2] == "quantity" and tl[18] == "audit.tail16", "both locked marks and 16 others: all kept (" .. #tl .. ")")
	local round = n.Profiles:Import("Round", n.Copy(n.db)); n.Profiles:Use(round); M.runTimers()
	check(#n.db.iconCorners.top_left == 18 and n.Corners:CornerOf("audit.tail16") == "top_left", "and through sharing and loading again")
	raw.iconCorners.top_left[#raw.iconCorners.top_left + 1] = "audit.tail17"
	name = n.Profiles:Import("TooMany", raw); n.Profiles:Use(name); M.runTimers()
	check(#n.db.iconCorners.top_left == 18 and n.Corners:CornerOf("audit.tail17") == nil, "a 17th other mark is still more than a corner keeps")
	check(n.Corners.LOCKED[1] == "quest_start" and n.Corners.LOCKED[2] == "quantity" and #n.Corners.LOCKED == 2, "the locked marks the limit leaves out are the Corners module's own")

	-- ---- Narrow Windows (Shweep): the player chooses which columns a narrow List view sets aside, first to go first
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
	local function planAt(V, rowW)
		V.scroll.w = rowW; V.trustedRowWidth = nil
		local plan = V:ColumnPlan()
		local keys = {}
		for _, c in ipairs(plan) do keys[#keys + 1] = c.key end
		return plan, table.concat(keys, ","), table.concat(plan.dropped or {}, ",")
	end
	local n, M, V = colBoot()
	-- (1.6.0-beta8, by design: Shweep) every column but Item and Qty ticked by default, wide text columns first
	check(table.concat(n.db.colAside, ",") == "t,age,v,ah,w,sl,rq,il,bd,fv,cc,jk" and table.concat(n.db.bankColAside, ",") == "t,age,v,ah,w,sl,rq,il,bd,fv,cc,jk", "by default: every column but Item and Qty, Type, Age, Vendor and AH Price first, in both windows")
	local plan, keys, dropped = planAt(V, 394)
	check(dropped == "t", "at 440 with the defaults: Type, as in beta4 (" .. dropped .. ")")
	-- a player's own order
	n.db.colAside = { "jk", "cc", "t" }
	plan, keys, dropped = planAt(V, 394)
	check(dropped == "jk,cc" and keys:find("t,", 1, true), "Junk, then Currency, ticked first: they go first, Type stays (" .. dropped .. ")")
	plan, keys, dropped = planAt(V, 900)
	check(dropped == "" and keys:find("jk", 1, true), "wide: every column back")
	-- nothing ticked: shrink to fit, as in 1.5.8
	n.db.colAside = {}
	plan, keys, dropped = planAt(V, 394)
	check(dropped == "" and plan.squeezed and keys == "c,n,t,bd,v,w,age,fv,cc,jk", "nothing ticked: every column stays and shrinks to fit, as before 1.6.0")
	-- a ticked column that's turned off isn't set aside (it isn't there)
	n.db.colAside = { "sl", "t" }
	plan, keys, dropped = planAt(V, 394)
	check(dropped == "t", "a ticked column that isn't shown is skipped (" .. dropped .. ")")
	-- each window its own
	n.db.colAside = { "t", "age", "v", "ah" }; n.db.bankColAside = { "jk" }
	n.Window.bank = n.Window.bank or (function() for _, v in pairs(n.views) do if v.isBank then return v end end end)()
	local B = n.Window.bank
	check(B:AsideOrder()[1] == "jk" and V:AsideOrder()[1] == "t", "the bank window keeps its own list")
	-- the header says what's set aside, and where to choose
	plan = planAt(V, 394)
	V.columnPlan = plan
	check(V:AsideText() == "Set aside to fit: Type. Widen the window, or choose in Settings > Bag Columns.", "the header's line: " .. tostring(V:AsideText()))
	local lines = {}
	local realTip = n.TipLine
	n.TipLine = function(tip, text, ...) lines[#lines + 1] = text; return realTip(tip, text, ...) end
	V:LayoutHeader(plan)
	V.headerLabels.age:GetScript("OnEnter")(V.headerLabels.age)
	n.TipLine = realTip
	check(table.concat(lines, "|"):find("Set aside to fit: Type.", 1, true) ~= nil, "pointing at a column header shows it")
	planAt(V, 900); V.columnPlan = V:ColumnPlan()
	check(V:AsideText() == nil, "and nothing when nothing is set aside")
	-- saved values cleaned on load
	n, M, V = colBoot({ colAside = { "jk", "n", "nope", "jk", 7, "t" } })
	check(table.concat(n.db.colAside, ",") == "jk,t", "a saved list keeps known columns once each, never Item (" .. table.concat(n.db.colAside, ",") .. ")")
	n, M, V = colBoot({ colAside = "junk" })
	check(table.concat(n.db.colAside, ",") == "t,age,v,ah,w,sl,rq,il,bd,fv,cc,jk", "an unreadable list is the default again")

	-- the Settings card: Settings > Bag Columns > Narrow Windows ((1.6.0-beta8) from beta6's default list, so the steps
	-- below keep their meaning; the new default's rows are checked in core_1_6_0_beta8_tests.lua)
	n, M, V = colBoot({ colAside = { "t", "age", "v", "ah" } })
	local P = n.SettingsPanel
	P:Show(); M.runTimers(); P:ShowPage("bagcols"); M.runTimers()
	local function narrowList()
		for _, l in ipairs(P.pools.list or {}) do
			if l:IsShown() and l.rows[1] and l.rows[1]:IsShown() and l.rows[1].id == "t" and l.rows[1].box:GetChecked() then return l end
		end
	end
	local l = narrowList()
	local heads = {}
	for _, w in ipairs(P.pools.head or {}) do if w:IsShown() then heads[#heads + 1] = w.text and w.text.text or w.label end end
	check(table.concat(heads, "|"):find("Narrow Windows", 1, true) ~= nil and l ~= nil, "Settings > Bag Columns has a Narrow Windows card with its list")
	local function rowsOf(list)
		local out = {}
		for _, r in ipairs(list.rows) do if r:IsShown() then out[#out + 1] = r.id .. (r.box:GetChecked() and "+" or "-") .. (r.up:IsShown() and "^" or "") .. (r.down:IsShown() and "v" or "") end end
		return table.concat(out, " ")
	end
	-- (1.6.0-beta8, by design) Qty isn't listed any more
	check(rowsOf(l) == "t+v age+^v v+^ bd- w- fv- cc- jk-", "the ticked ones first, in order, with arrows among themselves; the rest unticked, in column order: " .. rowsOf(l))
	local function row(list, id) for _, r in ipairs(list.rows) do if r:IsShown() and r.id == id then return r end end end
	local jk = row(l, "jk"); jk.box:SetChecked(true); jk.box:GetScript("OnClick")(jk.box); M.runTimers()
	check(table.concat(n.db.colAside, ",") == "t,age,v,ah,jk", "ticking Junk adds it last")
	l = narrowList()
	local up = row(l, "jk"); up.up:GetScript("OnClick")(up.up); M.runTimers()
	check(table.concat(n.db.colAside, ",") == "t,age,jk,ah,v" or table.concat(n.db.colAside, ",") == "t,age,jk,v,ah", "its up arrow moves it past the shown ticked column above it (" .. table.concat(n.db.colAside, ",") .. ")")
	l = narrowList()
	local t = row(l, "t"); t.box:SetChecked(false); t.box:GetScript("OnClick")(t.box); M.runTimers()
	check(not n.IndexOf(n.db.colAside, "t"), "unticking Type: never set aside")
	P:ShowPage("bankcols"); M.runTimers()
	heads = {}
	for _, w in ipairs(P.pools.head or {}) do if w:IsShown() then heads[#heads + 1] = w.text and w.text.text or w.label end end
	check(table.concat(heads, "|"):find("Narrow Windows", 1, true) ~= nil and table.concat(n.db.bankColAside, ",") == "t,age,v,ah,w,sl,rq,il,bd,fv,cc,jk", "Bank Columns has its own card, its own list untouched")
	P:Hide()
end)()
