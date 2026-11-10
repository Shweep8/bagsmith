;(function()
	-- 1.6.0-beta11: Shweep's feedback on beta10 and the 1.6.0-beta10 audit's precision notes.
	--  * the title row at the narrowest width: what follows the note (the picker, Travel Mode's search box) follows it only
	--    while it shows; the note says "read only" (no name); the picker's name is cut short before its level, which
	--    clears the arrow (Classic's larger one too)
	--  * soulbound items have no AH value anywhere: the bags' AH Price column and totals, item tooltips, the Disenchant
	--    Helper ("Soulbound", only Disenchant or Vendor), the Loot Helper (vendor price, "AH Soulbound"; loot that binds when
	--    picked up likewise)
	--  * B10 A1 and A2: prices and margins round a decimal half up, from the number as written
	-- ---- a horizontal layout resolver: a region's left and right edges in the window's coordinates, from its anchors
	local function natural(r)
		if r.GetStringWidth then
			local sw = r:GetStringWidth() or 0
			if r.width and r.width > 0 then return math.min(r.width, sw) end
			return sw
		end
		return r.w
	end
	local function parentOf(r) return r.parentFrame or r.parent end
	local span
	local function anchorX(rel, rp, root, depth)
		local l, rr = span(rel, root, depth + 1)
		if not l then return nil end
		if rp:find("LEFT") then return l elseif rp:find("RIGHT") then return rr end
		return (l + rr) / 2
	end
	span = function(r, root, depth)
		depth = depth or 0
		if r == root then return 0, root.w or root:GetWidth() end
		if depth > 40 or not r then return nil end
		local L, R, C
		for _, p in ipairs(r.points or {}) do
			local point, rel, rp, x = p[1], p[2], p[3], p[4]
			if type(rel) ~= "table" then rel, rp, x = parentOf(r), point, rel end
			local ax = anchorX(rel, rp or point, root, depth)
			if not ax then return nil end
			ax = ax + (tonumber(x) or 0)
			if point:find("LEFT") then L = ax elseif point:find("RIGHT") then R = ax else C = ax end
		end
		local w = natural(r)
		if L and R then return L, R end
		if not w then return nil end
		if L then return L, L + w end
		if R then return R - w, R end
		if C then return C - w / 2, C + w / 2 end
		return nil
	end
	local function sized(V, W)
		V.frame.w = W
		for _, r in ipairs({ V.title, V.tools, V.footer }) do
			local l, rr = span(r, V.frame)
			if l then r.w = rr - l end
		end
		V:LayoutTools(); V:UpdateFooter(); V:LayoutTitleRow()
		for _, r in ipairs({ V.title, V.tools, V.footer }) do
			local l, rr = span(r, V.frame)
			if l then r.w = rr - l end
		end
		V:LayoutTools(); V:UpdateFooter(); V:LayoutTitleRow()
	end
	local function overlaps(list)
		table.sort(list, function(a, b) return a.l < b.l end)
		for i = 2, #list do if list[i].l < list[i - 1].r - 0.01 then return list[i - 1].name .. " / " .. list[i].name end end
	end

	local function fmt(x) return x and ("%.0f"):format(x) or "?" end
	local function sized(V, W)
		V.frame.w = W
		for _ = 1, 2 do
			for _, r in ipairs({ V.title, V.tools, V.footer }) do local l, rr = span(r, V.frame); if l then r.w = rr - l end end
			V:LayoutTools(); V:UpdateFooter(); V:LayoutTitleRow()
		end
	end
	-- game-like text widths (the mock counts characters): the title in its larger font, the note in the small one
	local function gameWidths(V)
		local function w(fs, per) fs.GetUnboundedStringWidth = function(self) return #(self.text or "") * per end; fs.GetStringWidth = fs.GetUnboundedStringWidth end
		w(V.titleText, 10); w(V.subText, 6)
	end
	local function firstIcon(V)
		local best, name = math.huge, "?"
		for _, k in ipairs({ "btnLanesTravel", "btnClean", "btnDisenchant", "btnGearSets", "btnBank", "btnCurrency", "btnSettings" }) do
			local b = V[k]
			if b and b:IsShown() then local l = span(b, V.frame); if l and l < best then best, name = l, k end end
		end
		return best, name
	end

	-- ---- the picker when viewing another character, at 440
	for _, skin in ipairs({ "modern", "classic" }) do
		for _, de in ipairs({ false, true }) do
			package.loaded.mock = nil
			local M = require("mock")
			local realFs = M.fs   -- (the mock's SetWordWrap does nothing: record it)
			M.fs = function(...) local s = realFs(...); s.SetWordWrap = function(self, on) self.wordWrap = on end; return s end
			_G.BagSmithCharDB = { version = 1, firstSeen = {} }
			_G.BagSmithDB = { version = 2, chars = {}, profiles = { Default = { skin = skin, view = "icons", deEnabled = de } }, cache = {
				["Bree Baggs - Forever"] = { name = "Bree Baggs", realm = "Forever", class = "MAGE", level = 1, gold = 0, updated = time() - 30, bags = {}, items = {}, currencies = {} },
				["Bartholomew Longname - Forever"] = { name = "Bartholomew Longname", realm = "Forever", class = "MAGE", level = 60, gold = 0, updated = time() - 30, bags = {}, items = {}, currencies = {} } } }
			local n = M.loadAddon("BagSmith")
			M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
			n.Window:Show(); M.runTimers(); M.runTimers()
			local V = n.Window.main
			gameWidths(V)
			local tag = skin .. (de and " with the Disenchant button" or "")
			for _, key in ipairs({ "Bree Baggs - Forever", "Bartholomew Longname - Forever" }) do
				V:SetOwner(key); M.runTimers(); M.runTimers()
				sized(V, 440)
				local who = tag .. ", viewing " .. key:match("^(.-) %-")
				check(V.subText.text == "read only", who .. ": the note says \"read only\", not the name (" .. tostring(V.subText.text) .. ")")
				local icon, iconName = firstIcon(V)
				local _, pr = span(V.charBtn, V.frame)
				local _, xr = span(V.charReset, V.frame)
				check(V.charReset:IsShown() and xr and xr <= icon + 0.01 and pr <= icon, who .. " at 440: the picker and its X end before the first icon (" .. fmt(xr) .. " / " .. iconName .. " " .. fmt(icon) .. ")")
				check(V.charBtn:GetWidth() >= 110, who .. ": the picker keeps at least 110 px (" .. fmt(V.charBtn:GetWidth()) .. ")")
				if not V.subText.shown then
					local p = { V.charBtn:GetPoint(1) }
					check(p[2] == V.subText and p[3] == "LEFT", who .. ": with the note hidden, the picker starts where the note would")
				end
				-- the level on its own, the name before it, cut short with "..." (no wrapping)
				local lp = { V.charLevel:GetPoint(1) }
				local inset = (V.classicApplied and V.classicDropdown) and n.View.PICKER_ARROW_CLASSIC or n.View.PICKER_ARROW
				check(V.charLevel.text == (key:find("Bree") and "1" or "60") and lp[1] == "RIGHT" and lp[4] == -inset, who .. ": the level is its own text, " .. inset .. " px from the right (clear of the arrow)")
				local np = {}
				for i = 1, V.charBtn.label:GetNumPoints() do local pt = { V.charBtn.label:GetPoint(i) }; np[pt[1]] = pt end
				check(V.charBtn.label.text == key:match("^(.-) %-") and np.RIGHT and np.RIGHT[2] == V.charLevel and np.RIGHT[3] == "LEFT" and V.charBtn.label.wordWrap == false,
					who .. ": the name ends before the level and doesn't wrap, so a long one is cut short")
			end
			V:SetOwner(nil); M.runTimers(); M.runTimers()
			check(V.subText.text == "" and not V.charReset:IsShown(), tag .. ": back to your own bags, no note")
		end
	end

	-- ---- Travel Mode's search box at 440, searching
	for _, skin in ipairs({ "modern", "classic" }) do
		for _, de in ipairs({ false, true }) do
			package.loaded.mock = nil
			local M = require("mock")
			for i = 1, 12 do M.put(0, i, { id = 4000 + i, name = "Item " .. i, q = 1, count = 1, class = 7, subclass = 5, price = 1 }) end
			M.put(1, 1, { id = 5000, name = "Linen Cloth", q = 1, count = 1, class = 7, subclass = 5, price = 1 })
			_G.BagSmithCharDB = { version = 1, firstSeen = {} }
			_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, view = "icons", deEnabled = de, travelMode = true } } }
			local n = M.loadAddon("BagSmith")
			M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
			n.Window:Show(); M.runTimers(); M.runTimers()
			local V = n.Window.main
			gameWidths(V)
			for _, q in ipairs({ "", "linen" }) do
				n.ui.filters.text = q; n:RefreshViews(true); M.runTimers(); M.runTimers()
				sized(V, 440)
				local who = ("%s%s, Travel Mode, %s"):format(skin, de and " with the Disenchant button" or "", q == "" and "no search" or "searching (" .. tostring(V.subText.text) .. ")")
				local sl, sr = span(V.search, V.frame)
				local icon = firstIcon(V)
				check(sl and sr and sr - sl >= 120 and sr <= icon + 0.01, who .. " at 440: the search box keeps at least 120 px and ends before the icons (" .. fmt(sr and sl and sr - sl) .. " px)")
			end
			n.ui.filters.text = ""
		end
	end
end)()

;(function()
	-- ---- soulbound items: the bags, tooltips and the Loot Helper
	local bound = {}
	local function boot(skin, lootBop)
		package.loaded.mock = nil
		local M = require("mock")
		for b = 0, 5 do M.sizes[b] = 0 end; M.sizes[0] = 2
		M.maxStack = { [7001] = 1, [7002] = 1, [9001] = 1 }
		M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
		M.put(0, 2, { id = 7002, name = "Common Trinket", q = 1, count = 1, class = 15, subclass = 0, price = 5 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, view = "list", grp = "type", makeRoom = true, makeRoomValue = "ah", cols = { "c", "v", "ah" } } } }
		local function idOf(v) return type(v) == "number" and v or tonumber(tostring(v):match("item:(%d+)")) end
		local function ap(v) local id = idOf(v); if id == 7001 then return 600 elseif id == 7002 then return 1000 elseif id == 9001 then return 1000000 end end
		_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function(c, l) return ap(l) end, GetAuctionPriceByItemID = function(c, id) return ap(id) end } } }
		_G.BlackthornesTS_API = nil
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(v) if idOf(v) == 9001 then return "Waiting Loot", "item:9001", 2, 20, 0, "Armor", "Cloth", 1, "INVTYPE_CHEST", 1, lootBop and 300 or 1000000, 4, 1, lootBop and 1 or 2 end; return realInfo(v) end
		local realContainer = C_Container.GetContainerItemInfo
		C_Container.GetContainerItemInfo = function(bag, slot) local i = realContainer(bag, slot); if i and bound[i.itemID] then i.isBound = true end; return i end
		_G.GetNumLootItems = function() return 1 end
		_G.GetLootSlotType = function() return 1 end
		_G.GetLootSlotLink = function() return "|Hitem:9001:0|h[Waiting Loot]|h" end
		_G.GetLootSlotInfo = function() return "icon", "Waiting Loot", 1, nil, 2 end
		_G.LootSlot = function() M.lootRequested = true end
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id; M.cursorFrom = { bag, slot } end
		_G.ClearCursor = function() M.cursorItem = nil; M.cursorFrom = nil end
		_G.DeleteCursorItem = function() if M.cursorFrom then M.bags[M.cursorFrom[1]][M.cursorFrom[2]] = nil end; M.cursorItem = nil end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M
	end
	local function rows(f) local out = {}; for _, r in ipairs(f.destroyRows or {}) do if r:IsShown() then out[#out + 1] = { name = r.name.text, value = r.value.text } end end; return out end
	for _, skin in ipairs({ "modern", "classic" }) do
		-- control: nothing bound, ranked by AH price: the Boots (600) before the Trinket (1000)
		bound = {}
		local n, M = boot(skin)
		n.Window:Show(); M.runTimers(); M.runTimers()
		local trinket = n.Buttons:Get(0, 2)
		check(trinket.colAH.text == n.Money(1000) and n.AH:StackValue(trinket.rec) == 1000, skin .. ": (control) the Trinket's AH Price shows 10s")
		M.fire("LOOT_OPENED"); M.runTimers(); M.runTimers()
		local f = n.MakeRoom.frame
		local r = rows(f)
		check(r[1] and r[1].name == "Sturdy Boots" and r[2] and r[2].name == "Common Trinket", skin .. ": (control) ranked by AH price, the Boots come first")
		-- the Trinket soulbound
		bound = { [7002] = true }
		n, M = boot(skin)
		n.Window:Show(); M.runTimers(); M.runTimers()
		trinket = n.Buttons:Get(0, 2)
		local boots = n.Buttons:Get(0, 1)
		check(trinket.rec.isBound and trinket.colAH.text == "" and boots.colAH.text == n.Money(600), skin .. ": a soulbound item's AH Price cell is empty; the Boots' still shows")
		check(n.AH:StackValue(trinket.rec) == nil and n.AH:Sellable(trinket.rec) == false, skin .. ": it has no AH value (the section totals and sorting use the same)")
		local tipLines = 0
		local tip = { AddDoubleLine = function() tipLines = tipLines + 1 end, AddLine = function() tipLines = tipLines + 1 end }
		n.AH:AddTooltipLines(tip, trinket.rec)
		check(tipLines == 0, skin .. ": its tooltip gets no AH Price line (the game's own says Soulbound)")
		M.fire("LOOT_OPENED"); M.runTimers(); M.runTimers()
		f = n.MakeRoom.frame
		r = rows(f)
		check(r[1] and r[1].name == "Common Trinket" and r[1].value:find("AH Soulbound", 1, true) and r[1].value:find(n.Money(5), 1, true) ~= nil,
			skin .. ": the Loot Helper counts it at its vendor price (5c), so it comes first, marked AH Soulbound (" .. tostring(r[1] and r[1].value) .. ")")
		check(r[2] and r[2].name == "Sturdy Boots", skin .. ": and the Boots after it, by their AH price")
		f.act:GetScript("OnClick")(f.act); M.runTimers()
		check(M.bags[0][2] == nil and M.bags[0][1] ~= nil, skin .. ": the click destroys the Trinket it names (the final check reads the same value), the Boots stay")
		-- loot that binds when picked up counts at its vendor price: 3s here, so neither item (6s, 10s on the AH) is worth less
		bound = {}
		n, M = boot(skin, true)
		M.fire("LOOT_OPENED"); M.runTimers(); M.runTimers()
		local w = n.MakeRoom:Waiting()[1]
		check(w and w.values and w.values.bound == "bop" and w.values.ah == nil and n.MakeRoom:Rank(w.values) == 300, skin .. ": loot that binds when picked up has no AH value and ranks at its vendor price")
		check(n.MakeRoom:ValueText(w.values):find("AH Binds when picked up", 1, true) ~= nil, skin .. ": its value line says so")
		local _, ds = n.MakeRoom:Suggestions(n.MakeRoom:Waiting())
		check(#ds == 0, skin .. ": nothing in the bags is worth less than its 3s, so nothing is offered (" .. #ds .. ")")
	end
end)()

;(function()
	-- ---- soulbound items: the Disenchant Helper
	package.loaded.mock = nil
	local M = require("mock")
	local DEID = 13262
	M.put(0, 1, { id = 7003, name = "Rare Chest", q = 3, count = 1, class = 4, subclass = 2, price = 2000, ilvl = 45, equip = "INVTYPE_CHEST" })
	M.put(0, 2, { id = 7013, name = "Bound Chest", q = 3, count = 1, class = 4, subclass = 2, price = 2000, ilvl = 45, equip = "INVTYPE_CHEST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true, deLeveling = "never" } } }
	_G.IsSpellKnown = function(id) return id == DEID end
	_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
	_G.GetNumSkillLines = function() return 1 end
	_G.GetSkillLineInfo = function() return "Enchanting", false, nil, 300, 0, 0, 300 end
	_G.RegisterStateDriver = function() end; _G.UnregisterStateDriver = function() end
	_G.InCombatLockdown = function() return false end
	_G.GetCVar = function(k) if k == "autoLootDefault" then return "1" end end
	local prices = { [7003] = 9000, [7013] = 9000, [11177] = 1000 }
	_G.Auctionator = { API = { v1 = {
		GetAuctionPriceByItemLink = function(_, link) local id = tonumber(link:match("item:(%d+)")); return id and prices[id] end,
		GetAuctionPriceByItemID = function(_, id) return prices[id] end,
		GetAuctionAgeByItemLink = function() return nil end,
	} } }
	local realContainer = C_Container.GetContainerItemInfo
	C_Container.GetContainerItemInfo = function(bag, slot) local i = realContainer(bag, slot); if i and i.itemID == 7013 then i.isBound = true end; return i end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE = n.Disenchant
	DE:Show(); M.runTimers()
	local byId = {}; for _, e in ipairs(DE.entries) do byId[e.itemID] = e end
	local free, b = byId[7003], byId[7013]
	check(free and free.ah == 9000 and free.verdict == "ah", "(control) the tradeable chest: 90s on the AH, Sell at AH")
	check(b and b.bound and b.ah == nil and b.verdict ~= "ah", "the soulbound chest: no AH price, never Sell at AH (" .. tostring(b and b.verdict) .. ")")
	check(b and (b.verdict == "vendor" or b.verdict == "de") and b.mats == free.mats, "it's Vendor or Disenchant on the same materials (which can be sold)")
	check(DE:ValueText(b.ah, "ah", b) == "Soulbound" and DE:ValueText(free.ah, "ah", free) == n.Money(9000), "its AH value reads Soulbound")
	check(DE:Verdict({ vendor = 0, ah = 9000, mats = 1, bound = true }) == "de" and DE:Verdict({ vendor = 0, ah = 9000, mats = 1 }) == "ah", "a soulbound entry's AH price is never counted, even if one is given")
	DE.current = b; DE:Paint()
	check(DE.frame.cur.values.text:find("AH Soulbound", 1, true) ~= nil, "the value line: AH Soulbound (" .. tostring(DE.frame.cur.values.text) .. ")")
	GameTooltip.ClearLines = GameTooltip.ClearLines or function() end   -- (the shared mock's tooltip lacks these)
	GameTooltip.SetHyperlink = GameTooltip.SetHyperlink or function() end
	local said = {}
	local realTip = n.TipLine
	n.TipLine = function(tip, text, ...) said[#said + 1] = tostring(text); return realTip(tip, text, ...) end
	local row
	for _, r in ipairs(DE.frame.rows) do if r:IsShown() and r.entry == b then row = r end end
	if row then DE:RowTip(row) end
	n.TipLine = realTip
	local hint = false
	for _, l in ipairs(said) do if l:find("scan", 1, true) then hint = true end end
	check(row and not hint, "its row's tooltip has no scan hint for it")
	DE:Close()
end)()

;(function()
	-- ---- B10 A1 and A2: a decimal half rounds up, from the number as written
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true, deLeveling = "never" } } }
	_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function() return 1 end, GetAuctionPriceByItemID = function() return 1 end } } }
	_G.BlackthornesTS_API = nil
	_G.GetNumSkillLines = function() return 1 end
	_G.GetSkillLineInfo = function() return "Enchanting", false, nil, 120, 0, 0, 150 end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE = n.Disenchant
	local H = DE.DecimalHundredths
	check(H(8200.005) == 820001 and H(8200.0049) == 820000 and H(8200.0051) == 820001, "8200.005c is 8200.01c (a decimal half up); 8200.0049c is 8200.00c")
	check(H(1.005) == 101 and H(0.145) == 15 and H(0.144999999995) == 14 and H(0.155) == 16, "1.005 is 1.01; 0.145 is 15; 0.144999999995 is 14 (not up); 0.155 is 16")
	check(H(2147483647) == 214748364700 and H(2147483646.995) == 214748364700, "at the gold cap: whole, and a half of a hundredth just under it")
	check(H(0) == 0 and H(12) == 1200 and H(1e20) == math.floor(1e20 * 100 + 0.5), "whole numbers; a number written with an exponent rounds the plain way")
	local function v(vendor, ah, mats) return DE:Verdict({ vendor = vendor, ah = ah, mats = mats }) end
	n:Set("deMargin", 0.10)
	check(v(0, 8200.005, 9020) == "ah" and v(0, 8200.0049, 9020) == "de", "the audit's case: 8200.005c on the AH (8200.01c) against 9020c of materials is Sell at AH; 8200.0049c is Disenchant")
	n.db.deMargin = 0.144999999995
	check(v(95, 0, 114) == "de", "a margin of 14.4999999995% counts as 14%: 95c against 1s 14c is a tie, Disenchant")
	n.db.deMargin = 0.145
	check(v(95, 0, 114) == "vendor", "14.5% still counts as 15%")
	n.db.deMargin = 0.10
	n.db.deAhMargin = 0.144999999995
	check(v(95, 114, 0) == "ah", "an AH margin of 14.4999999995% counts as 14%: a tie, Sell at AH")
	n.db.deAhMargin = 0.20
end)()
