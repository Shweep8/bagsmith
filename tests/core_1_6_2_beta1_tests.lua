;(function()
	-- 1.6.2-beta1 (Shweep: "handle all you mentioned"): the performance review's changes. Cooldowns update only on
	-- buttons that can be seen (and on the Recent copies too); the single-bag windows are built the first time they open;
	-- List rows place their columns again only when the columns change; the junk cell's "can't be marked" reason is made
	-- on hover; the legacy BagSmithProbeReport is no longer declared.
	local function boot(profile, setup)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 118, name = "Minor Healing Potion", q = 1, count = 3, class = 0, subclass = 1, price = 5 })
		M.put(0, 2, { id = 6948, name = "Hearthstone", q = 1, count = 1, class = 15, subclass = 0, price = 0 })
		M.put(0, 3, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
		M.put(0, 4, { id = 2592, name = "Wool Cloth", q = 1, count = 4, class = 7, subclass = 5, price = 2 })
		M.put(1, 1, { id = 2318, name = "Light Leather", q = 1, count = 2, class = 7, subclass = 6, price = 2 })
		M.put(1, 2, { id = 5571, name = "Small Black Pouch", q = 1, count = 1, class = 1, subclass = 0, price = 0 })
		if setup then setup(M) end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = profile } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M
	end

	-- ---- 1. Cooldowns: only buttons that can be seen; the Recent copies too; current again when the bags open
	for _, skin in ipairs({ "modern", "classic" }) do
		local onCooldown = { [118] = { 100, 60 } }
		local set = {}
		local n, M = boot({ skin = skin, view = "icons" }, function(M)
			C_Container.GetContainerItemCooldown = function(bag, slot)
				local it = M.bags[bag] and M.bags[bag][slot]
				local cd = it and onCooldown[it.id]
				if cd then return cd[1], cd[2], 1 end
				return 0, 0, 1
			end
			_G.CooldownFrame_Set = function(frame, start, duration, enable) set[frame] = { start = start, duration = duration } end
		end)
		n.Window:Show(); M.runTimers(); M.runTimers()
		local V = n.Window.main
		V.frame.IsMouseOver = function() return false end
		local calls = 0
		local orig = n.Buttons.Cooldown
		n.Buttons.Cooldown = function(...) calls = calls + 1; return orig(...) end
		local function buttonFor(bag, slot) return n.Buttons:Get(bag, slot) end
		local hearth = buttonFor(0, 2)
		M.fire("BAG_UPDATE_COOLDOWN"); M.runTimers()
		local open = calls
		check(open >= 6 and hearth:IsVisible(), skin .. ": with the bags open, a cooldown change updates the item buttons (" .. open .. ")")
		n.Window:Hide(); M.runTimers(); M.runTimers()
		check(not V.frame:IsShown() and hearth:IsShown() and not hearth:IsVisible(), skin .. ": (setup) the bags closed, the buttons keep their own shown flag")
		calls = 0
		M.fire("BAG_UPDATE_COOLDOWN"); M.runTimers()
		check(calls == 0, skin .. ": with the bags closed, a cooldown change touches no button (" .. calls .. ")")
		-- the Hearthstone goes on cooldown while the bags are closed: opening them shows it
		onCooldown[6948] = { 200, 1800 }
		M.fire("BAG_UPDATE_COOLDOWN"); M.runTimers()
		n.Window:Show(); M.runTimers(); M.runTimers()
		check(set[hearth.Cooldown] and set[hearth.Cooldown].start == 200 and set[hearth.Cooldown].duration == 1800,
			skin .. ": opening the bags shows the cooldown that started while they were closed")
		-- even when the opening redraw is held (the pointer already over the window)
		n.Window:Hide(); M.runTimers(); M.runTimers()
		onCooldown[6948] = { 300, 1800 }
		M.fire("BAG_UPDATE_COOLDOWN"); M.runTimers()
		V.frame.IsMouseOver = function() return true end
		n.Window:Show(); M.runTimers(); M.runTimers()
		check(set[hearth.Cooldown] and set[hearth.Cooldown].start == 300, skin .. ": and with the pointer over the window as it opens")
		V.frame.IsMouseOver = function() return false end
		-- the Recent copies follow cooldown changes too
		local now = time()
		n.cdb.recentSince = now - 100
		n.cdb.firstSeen[M.bags[0][2].guid] = now - 10
		n:Scan(); n:Set("recentSection", true); n:RefreshViews(true); M.runTimers()
		local copy
		for _, b in ipairs(n.Buttons.recent) do if b:IsShown() and b.rec and b.rec.itemID == 6948 then copy = b end end
		check(copy and copy:IsVisible(), skin .. ": (setup) the Hearthstone has a Recent copy")
		onCooldown[6948] = { 400, 1800 }
		M.fire("BAG_UPDATE_COOLDOWN"); M.runTimers()
		check(copy and set[copy.Cooldown] and set[copy.Cooldown].start == 400, skin .. ": a cooldown change updates the Recent copy too")
		-- a bag window's own buttons (plain cells) follow it while open, not while closed
		n:Set("__openWindows", "all"); n.Window:Hide(); n:OnMainHidden(); ToggleAllBags(); M.runTimers(); M.runTimers()
		local bw = rawget(n.Window.bagViews, 0)
		local cell
		for _, b in pairs(bw and n.Buttons.mirrors[bw.child] or {}) do if b:IsShown() and b.rec and b.rec.itemID == 6948 then cell = b end end
		check(bw and bw:IsShown() and cell and cell:IsVisible(), skin .. ": (setup) the backpack's own window shows the Hearthstone")
		onCooldown[6948] = { 500, 1800 }
		M.fire("BAG_UPDATE_COOLDOWN"); M.runTimers()
		check(cell and set[cell.Cooldown] and set[cell.Cooldown].start == 500, skin .. ": the bag window's cell follows a cooldown change")
		n.Buttons.Cooldown = orig
	end

	-- ---- 2. The single-bag windows are built the first time they open
	for _, skin in ipairs({ "modern", "classic" }) do
		local n, M = boot({ skin = skin, bagBar = true, bgOpacity = 0.6 })
		local W = n.Window
		local built = {}
		for name in pairs(n.views) do built[#built + 1] = name end
		table.sort(built)
		check(#built == 2 and n.views.BagSmithFrame and n.views.BagSmithBankFrame, skin .. ": at login only the bags and bank windows are built (" .. table.concat(built, ", ") .. ")")
		local none = true
		for _, bag in ipairs(n.BAGS) do if rawget(W.bagViews, bag) then none = false end end
		for _, bag in ipairs(n.BANK_BAGS) do if rawget(W.bankBagViews, bag) then none = false end end
		check(none, skin .. ": no bag or bank bag window is built at login")
		-- the bags window, its bag strip and the debug listing build none
		n.Window:Show(); M.runTimers(); M.runTimers()
		local main = n.Window.main
		check(main.bagBar and main.bagBar:IsShown(), skin .. ": (setup) the bag strip shows")
		n.BagBar:FillBar(main.bagBar)
		local okCheck = pcall(SlashCmdList.BAGSMITH, "check")
		check(okCheck, skin .. ": /bs check runs")
		none = true
		for _, bag in ipairs(n.BAGS) do if rawget(W.bagViews, bag) then none = false end end
		check(none and n.Window.main:IsShown(), skin .. ": opening the bags window, painting its bag strip and listing windows build none either")
		-- Auto-Open All Bags: the windows for bags with slots are built and shown, dressed and see-through like the rest
		n:Set("__openWindows", "all"); n.Window:Hide(); n:OnMainHidden(); ToggleAllBags(); M.runTimers(); M.runTimers()
		local shown, wrong = 0, {}
		for _, bag in ipairs(n.BAGS) do
			local v = rawget(W.bagViews, bag)
			local size = n.bagInfo[bag] and n.bagInfo[bag].size or 0
			if size > 0 and bag ~= n.KEYRING then
				if v and v:IsShown() and v.positioned then shown = shown + 1 else wrong[#wrong + 1] = tostring(bag) end
			elseif v then wrong[#wrong + 1] = tostring(bag) .. " (no slots, built)" end
		end
		check(shown >= 4 and #wrong == 0, skin .. ": each bag with slots gets its window when it opens, placed beside the bags window; none for an empty socket (" .. table.concat(wrong, ", ") .. ")")
		local v1 = rawget(W.bagViews, 1)
		check(v1 and n.views[v1.name] == v1 and v1.frame:GetName() == "BagSmithBag1", skin .. ": a built bag window joins the windows BagSmith keeps")
		local inEscape = false
		for _, name in ipairs(UISpecialFrames) do if name == "BagSmithBag1" then inEscape = true end end
		check(inEscape, skin .. ": Escape closes it")
		if skin == "classic" then
			check(v1 and v1.frame.classicState, "classic: a bag window built late wears the Classic frame")
			n:ApplyBgOpacity()
		else
			check(v1 and v1.frame.bgColor and math.abs(v1.frame.bgColor[4] - (n.Skins:Current().bg[4] or 1) * 0.6) < 0.001,
				"modern: a bag window built late takes Background Opacity (" .. tostring(v1 and v1.frame.bgColor and v1.frame.bgColor[4]) .. ")")
		end
		-- built once: closing and reopening reuses it
		n.Window:Hide(); n:OnMainHidden(); M.runTimers()
		check(v1 and not v1:IsShown(), skin .. ": closing the bags closes it")
		ToggleAllBags(); M.runTimers(); M.runTimers()
		check(rawget(W.bagViews, 1) == v1 and v1:IsShown(), skin .. ": reopening shows the same window again")
		-- bank bag windows: built at the bank, the first time they're turned on
		M.sizes[6] = 20; M.bagNames[6] = "Linen Bag"
		M.fire("BANKFRAME_OPENED"); M.runTimers(); M.runTimers()
		local bankBuilt = false
		for _, bag in ipairs(n.BANK_BAGS) do if rawget(W.bankBagViews, bag) then bankBuilt = true end end
		check(not bankBuilt and n.Window.bank:IsShown(), skin .. ": opening the bank builds no bank bag window yet")
		local bw = n.Window.bank
		bw.btnBags.scripts.OnClick(bw.btnBags); M.runTimers(); M.runTimers()
		local b6 = rawget(W.bankBagViews, 6)
		check(b6 and b6:IsShown() and b6.titleText.text == "Bank: Linen Bag", skin .. ": turning them on builds and shows the bank bag's window (" .. tostring(b6 and b6.titleText.text) .. ")")
		M.fire("BANKFRAME_CLOSED"); M.runTimers()
		check(b6 and not b6:IsShown(), skin .. ": leaving the bank closes it")
	end
	-- a bag window first opened during combat: built, shown, and faded like the others
	for _, skin in ipairs({ "modern", "classic" }) do
		local n2, M2 = boot({ skin = skin, combatFade = true, combatAlpha = 0.4 })
		n2.Window:Show(); M2.runTimers(); M2.runTimers()
		M2.combat = true; M2.fire("PLAYER_REGEN_DISABLED"); M2.runTimers()
		local ok, err = pcall(function() n2.BagBar:ToggleWindow(1); M2.runTimers(); M2.runTimers() end)
		local c1 = rawget(n2.Window.bagViews, 1)
		check(ok and c1 and c1:IsShown() and math.abs((c1.frame:GetAlpha() or 1) - 0.4) < 0.001,
			skin .. ": first opened in combat, a bag window appears faded like the others (" .. tostring(err or (c1 and c1.frame:GetAlpha())) .. ")")
		M2.combat = false; M2.fire("PLAYER_REGEN_ENABLED"); M2.runTimers()
		check(c1 and math.abs((c1.frame:GetAlpha() or 1) - 1) < 0.001, skin .. ": and comes back to full when combat ends")
	end

	-- ---- 3. List rows: columns placed again only when they change
	for _, skin in ipairs({ "modern", "classic" }) do
		local n, M = boot({ skin = skin, view = "list" })
		n.Window:Show(); M.runTimers(); M.runTimers()
		local V = n.Window.main
		V.frame.IsMouseOver = function() return false end
		local row
		for _, b in ipairs(V.used or {}) do if b.mode == "row" and b.rec and b.rec.itemID == 2589 then row = b end end
		check(row and row.colQty and row.colType, skin .. ": (setup) Linen Cloth's row")
		local placed = 0
		local function spy(r)
			for _, key in ipairs(n.Buttons.COL_KEYS) do
				local fs = r[key]
				if fs and not fs.bsSpied then
					local o = fs.SetPoint
					fs.SetPoint = function(...) placed = placed + 1; return o(...) end
					fs.bsSpied = true
				end
			end
		end
		for _, b in ipairs(V.used or {}) do if b.mode == "row" then spy(b) end end
		-- an item change with nothing about the columns changed
		M.bags[0][4].count = 9
		M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
		local wool
		for _, b in ipairs(V.used or {}) do if b.mode == "row" and b.rec and b.rec.itemID == 2592 then wool = b end end
		check(placed == 0 and wool and tostring(wool.colQty.text) == "9" and wool.colQty:IsShown(), skin .. ": an item change redraws the rows without placing their columns again (" .. placed .. ")")
		-- a column taken away: placed again, the column hidden
		local cols = n.db.cols
		local had = {}; for i, c in ipairs(cols) do had[i] = c end
		for i = #cols, 1, -1 do if cols[i] == "t" then table.remove(cols, i) end end
		n:RefreshViews(true); M.runTimers()
		check(placed > 0 and not row.colType:IsShown(), skin .. ": taking away a column places the rest again and hides it (" .. placed .. ")")
		-- Icons view and back: every column the plan doesn't have stays hidden, the icon its row size
		n:Set("view", "icons"); n:RefreshViews(true); M.runTimers()
		check(row.mode == "cell", skin .. ": (setup) Icons view")
		n:Set("view", "list"); n:RefreshViews(true); M.runTimers()
		check(row.mode == "row" and not row.colType:IsShown() and row.colQty:IsShown() and row.colName:IsShown(), skin .. ": back in List view the hidden column stays hidden and the rest show")
		check(row.iconPx and row.icon:GetWidth() == row.iconPx, skin .. ": and the icon is the row's size again (" .. tostring(row.icon:GetWidth()) .. " / " .. tostring(row.iconPx) .. ")")
		-- the column back
		n.db.cols = had; n:RefreshViews(true); M.runTimers()
		check(row.colType:IsShown(), skin .. ": the column put back shows again")
		-- a slot emptied and filled again keeps its columns
		M.bags[0][3] = nil
		M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
		M.put(0, 3, { id = 2589, name = "Linen Cloth", q = 1, count = 6, class = 7, subclass = 5, price = 1 })
		M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
		local linen, seen = nil, {}
		for _, b in ipairs(V.used or {}) do if b.mode == "row" and b.rec and b.rec.itemID == 2589 then linen = b; seen[#seen + 1] = tostring(b.colQty.text) .. "/" .. tostring(b.colQty:IsShown()) .. "/" .. tostring(b.colName:IsShown()) end end
		check(linen and linen.colQty:IsShown() and tostring(linen.colQty.text) == "6" and linen.colName:IsShown(), skin .. ": an item gone and back shows its columns (" .. table.concat(seen, ", ") .. ")")
	end

	-- ---- 4. The junk cell's reason, made when you point at it
	do
		local n, M = boot({ skin = "modern", view = "list" })
		n.Window:Show(); M.runTimers(); M.runTimers()
		local V = n.Window.main
		local pouch
		for _, b in ipairs(V.used or {}) do if b.mode == "row" and b.rec and b.rec.itemID == 5571 then pouch = b end end
		check(pouch and pouch.colJunk and pouch.colJunk.state == "blocked", "(setup) the pouch, with no vendor price, can't be marked")
		check(pouch and pouch.colJunk.reason == nil, "no reason text is made while the rows draw")
		local lines = {}
		local oLine = n.TipLine
		n.TipLine = function(tip, text, ...) lines[#lines + 1] = text; return oLine(tip, text, ...) end
		n.Junk:CellEnter(pouch.colJunk)
		n.TipLine = oLine
		check(table.concat(lines, " | "):find("can't be sold to a vendor", 1, true), "pointing at the cell says why: " .. table.concat(lines, " | "))
	end

	-- ---- 5. The legacy saved variable is retired; the namespace global is labeled
	local toc = io.open("BagSmith/BagSmith.toc"):read("*a")
	check(toc:find("\n## SavedVariables: BagSmithDB\n", 1, true) and not toc:find("BagSmithProbeReport", 1, true), "the TOC no longer declares BagSmithProbeReport")
	local init = io.open("BagSmith/Core/Init.lua"):read("*a")
	check(init:find("_G.BagSmith = ns   -- ", 1, true) and init:find("not a public contract", 1, true), "the BagSmith global says it isn't a public contract (BagSmith.API is)")
end)()
