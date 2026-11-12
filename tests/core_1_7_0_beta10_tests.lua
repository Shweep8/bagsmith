;(function()
	-- ======== 1.7.0-beta10: the Loot Helper's layout (Shweep) ========
	-- What's waiting, the one it's making room for highlighted (click another to switch); one list of the ways to make
	-- room for it under "To make room for <loot>" (free ways first, then items to let go, a cost on the right); one
	-- button, with Protect beside it for an item to let go; a line saying what happens next. Offers are judged against
	-- that loot alone, and a slot you free goes to it first.
	local loot = {}
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("|Hitem:" .. loot[i].id .. ":0|h[" .. loot[i].name .. "]|h") end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, l.qty or 1, nil, l.q or 1 end end
	local looted = {}
	_G.LootSlot = function(i) looted[#looted + 1] = i end
	local deleted = 0
	-- Rough Gem 30c and Shiny Ring 5s wait; Small Egg 1c
	local INFO = { [9740] = { "Rough Gem", 1, 1, 30 }, [9741] = { "Shiny Ring", 2, 1, 500 }, [9742] = { "Small Egg", 1, 20, 1 },
		[9701] = { "Broken Fang", 0, 1, 3 }, [9702] = { "Linen Belt", 1, 1, 22 }, [9720] = { "Gnoll Paw", 1, 20, 2 },
		[9703] = { "Linen Cloth", 1, 20, 1 }, [9731] = { "Fine Ring", 1, 1, 80 }, [6265] = { "Soul Shard", 1, 1, 0 } }
	local function boot(stock, skin, prof, class)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return class or "Warrior", (class or "Warrior"):upper() end
		M.sizes[0] = 6
		for b = 1, 5 do M.sizes[b] = 0 end
		stock(M)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local pr = { skin = skin or "modern", makeRoom = true, makeRoomValue = "vendor", makeRoomAsk = false }
		for k, v in pairs(prof or {}) do pr[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = pr } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id)
			local num = tonumber(tostring(id):match("item:(%d+)")) or id
			local e = INFO[num]
			if e then return e[1], nil, e[2], nil, nil, nil, nil, e[3], nil, nil, e[4] end
			return realInfo(id)
		end
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id; M.cursorSlot = { bag, slot } end
		_G.ClearCursor = function() M.cursorItem = nil end
		_G.DeleteCursorItem = function() deleted = deleted + 1; local p = M.cursorSlot; if p then M.bags[p[1]][p[2]] = nil end; M.cursorItem = nil end
		_G.GetNumQuestLogEntries = function() return 0, 0 end
		return n, M
	end
	local function pack(M)
		M.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
		M.put(0, 2, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
		M.put(0, 3, { id = 9720, name = "Gnoll Paw", q = 1, count = 5, stack = 20, class = 15, subclass = 0, price = 2 })   -- 10c
		M.put(0, 4, { id = 9731, name = "Fine Ring", q = 1, class = 4, subclass = 0, price = 80, equip = "INVTYPE_FINGER" })
		M.put(0, 5, { id = 9703, name = "Linen Cloth", q = 1, count = 5, stack = 20, class = 7, subclass = 5, price = 1 })
		M.put(0, 6, { id = 9703, name = "Linen Cloth", q = 1, count = 7, stack = 20, class = 7, subclass = 5, price = 1 })
	end
	local function heads(f) local t = {}; for _, h in ipairs(f.heads) do if h:IsShown() then t[#t + 1] = h.text end end return table.concat(t, "|") end
	local function offered(f) local t = {}; for _, r in ipairs(f.destroyRows) do if r:IsShown() then t[#t + 1] = r.name.text end end return table.concat(t, ",") end
	local function rowNamed(f, name) for _, r in ipairs(f.destroyRows) do if r:IsShown() and r.name.text == name then return r end end end
	local function waitRow(f, name) for _, r in ipairs(f.waitRows) do if r:IsShown() and r.name.text == name then return r end end end
	local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
	local function topOf(fr) local p = fr.points[1]; return -(p[5] or p[3] or 0) end
	local function openLoot(M) M.fire("LOOT_CLOSED"); M.runTimers(); M.fire("LOOT_OPENED"); M.runTimers() end

	for _, skin in ipairs({ "modern", "classic" }) do
		local S = skin .. ": "
		local n, M = boot(pack, skin)
		_G.LootFrame = CreateFrame("Frame", "LootFrame", UIParent); LootFrame.GetRight = function() return 500 end; LootFrame.GetTop = function() return 700 end; LootFrame:Show()
		loot = { { id = 9740, name = "Rough Gem", q = 1 }, { id = 9741, name = "Shiny Ring", q = 2 } }
		openLoot(M)
		local MR, f = n.MakeRoom, n.MakeRoom.frame
		check(f and f:IsShown(), S .. "(setup) the Loot Helper is open")
		-- what's waiting: the most valuable is the one it makes room for, highlighted
		local gem, ring = waitRow(f, "Rough Gem"), waitRow(f, "Shiny Ring")
		check(gem and ring and f.waitRows[1] == gem and f.waitRows[2] == ring, S .. "the waiting rows keep the loot window's order")
		check(ring.isTarget and ring.bar:IsShown() and ring.hl:IsShown() and not gem.isTarget and not gem.bar:IsShown() and not ring.dot:IsShown(),
			S .. "the most valuable (the ring) is highlighted, with a bar in the accent color; no selection dots on waiting rows")
		check(heads(f) == "Waiting to loot|To make room for Shiny Ring", S .. "two headings: what's waiting, then the ways to make room for it (" .. heads(f) .. ")")
		-- one list: the free way first, then items to let go, with costs on the right
		local c1 = f.combineRows[1]
		check(c1:IsShown() and c1.cost.text == "Free" and c1:GetParent() == f.letGo.child, S .. "combining stacks is in the same list, its cost Free")
		check(topOf(c1) < topOf(rowNamed(f, "Broken Fang")) or c1.points[1][5] > rowNamed(f, "Broken Fang").points[1][5], S .. "free ways come first")
		check(offered(f) == "Linen Cloth,Broken Fang,Linen Cloth,Gnoll Paw,Linen Belt,Fine Ring", S .. "everything worth less than the ring, least missed first (" .. offered(f) .. ")")
		check(rowNamed(f, "Broken Fang").cost.text:find("^Junk") and rowNamed(f, "Linen Belt").cost.text ~= "" and #rowNamed(f, "Linen Belt").btns == 0,
			S .. "each item's cost on the right (junk marked Junk); no buttons on the rows")
		check(f.footInfo:IsShown() and f.footInfo.title == "How it decides" and #f.footInfo.lines == 5, S .. "the (i) by the list's heading says how it decides")
		-- the one button, and Protect beside it only for an item to let go
		check(f.act.label.text == "Combine Linen Cloth" and not f.protect:IsShown() and math.abs(f.act:GetWidth() - (f:GetWidth() - 24)) < 0.5,
			S .. "a free way chosen: the button does it, full width, no Protect")
		check(f.foot:IsShown() and f.foot.text == "Then Shiny Ring goes in your bags.", S .. "the line under it says what happens next (" .. tostring(f.foot.text) .. ")")
		local belt = rowNamed(f, "Linen Belt")
		belt:GetScript("OnClick")(belt)
		check(f.act.label.text == "Destroy Linen Belt" and f.protect:IsShown() and f.protect.label.text == "Protect" and f.act:GetWidth() < f:GetWidth() - 24 - 70,
			S .. "an item to let go chosen: Destroy names it, Protect sits beside it")
		check(topOf(f.protect) == topOf(f.act) and f.protect.active ~= true, S .. "Protect on the same line, quiet (no accent)")
		f.protect:GetScript("OnClick")(f.protect); M.runTimers()
		check(MR:IsProtected(9702) and not rowNamed(f, "Linen Belt") and f.held:IsShown() and f.held.text == "1 protected item isn't offered", S .. "Protect protects the chosen item; it leaves the list, counted below it")
		check(topOf(f.held) > topOf(f.letGo), S .. "the protected line sits under the list")
		MR:ClearProtected(); M.runTimers()
		-- click the gem: it's the one it makes room for now; the list is judged against it
		gem = waitRow(f, "Rough Gem")
		gem.tipFn(GameTooltip)
		check(table.concat(GameTooltip.lines or {}, " "):find("Click to make room for this instead.", 1, true), S .. "another waiting row's tooltip says a click switches to it")
		GameTooltip:Hide()
		gem:GetScript("OnClick")(gem)
		gem, ring = waitRow(f, "Rough Gem"), waitRow(f, "Shiny Ring")
		check(gem.isTarget and gem.bar:IsShown() and not ring.isTarget, S .. "clicking the gem highlights it")
		check(heads(f) == "Waiting to loot|To make room for Rough Gem" and f.foot.text == "Then Rough Gem goes in your bags.", S .. "the heading and the line follow it")
		check(offered(f) == "Linen Cloth,Broken Fang,Linen Cloth,Gnoll Paw,Linen Belt", S .. "only what's worth less than the 30c gem is offered now (no Fine Ring) (" .. offered(f) .. ")")
		-- an offer made for the ring is refused once the gem is what it makes room for
		local ringOffer = MR:Offer(recOf(n, 9731), false, "priced", 80)
		local ok, why = MR:StillOk(ringOffer)
		check(ok == false and why == "worth", S .. "an offer worth letting go only for the ring is refused at the click (" .. tostring(why) .. ")")
		-- a new loot window starts over at the most valuable
		openLoot(M)
		check(waitRow(f, "Shiny Ring").isTarget and heads(f):find("Shiny Ring", 1, true), S .. "a new loot window makes room for the most valuable again")
		-- one waiting item: highlighted, nothing to switch
		loot = { { id = 9740, name = "Rough Gem", q = 1 } }
		openLoot(M)
		gem = waitRow(f, "Rough Gem")
		check(gem.isTarget and gem.bar:IsShown() and gem.onTarget == nil, S .. "one waiting item: it's highlighted; clicking it changes nothing")
		gem.tipFn(GameTooltip)
		check(not table.concat(GameTooltip.lines or {}, " "):find("Click to make room", 1, true), S .. "and its tooltip doesn't offer a switch")
		GameTooltip:Hide()
		f:Hide()
	end

	-- ---- a freed slot goes to the one it makes room for
	do
		local n, M = boot(function(M)
			for s = 1, 6 do M.put(0, s, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 }) end
		end)
		loot = { { id = 9742, name = "Small Egg", q = 1 }, { id = 9741, name = "Shiny Ring", q = 2 } }
		local MR = n.MakeRoom
		openLoot(M)
		local w = MR:Waiting()
		check(#w == 2, "(setup) both wait: the bags are full")
		M.bags[0][1] = nil; n:Scan(); M.runTimers()
		w = MR:Waiting()
		check(#w == 1 and w[1].name == "Small Egg", "one slot freed: the ring (making room for it) takes it; the egg still waits")
		-- the player picks the egg: the egg gets the next free slot
		M.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 }); n:Scan(); M.runTimers()
		local f = MR.frame
		local egg = waitRow(f, "Small Egg")
		egg:GetScript("OnClick")(egg)
		M.bags[0][1] = nil; n:Scan(); M.runTimers()
		w = MR:Waiting()
		check(#w == 1 and w[1].name == "Shiny Ring", "making room for the egg: the egg takes the freed slot; the ring waits")
		f:Hide()
	end

	-- ---- nothing for the one it makes room for: the card says another may have a way
	do
		local n, M = boot(function(M)
			for s = 1, 6 do M.put(0, s, { id = 9700 + s, name = "Keepsake " .. s, q = 1, class = 15, subclass = 0, price = 5 }) end
		end)
		for s = 1, 6 do n.Marks:ToggleFavorite(recOf(n, 9700 + s)) end
		loot = { { id = 9742, name = "Small Egg", q = 1 }, { id = 9741, name = "Shiny Ring", q = 2 } }
		openLoot(M)
		local f = n.MakeRoom.frame
		check(f.card:IsShown() and f.card.text.text:find("Or click another waiting item to make room for it instead.", 1, true), "nothing frees a slot for the ring: the card says another waiting item may have a way")
		loot = { { id = 9741, name = "Shiny Ring", q = 2 } }
		openLoot(M)
		check(f.card:IsShown() and not f.card.text.text:find("Or click another", 1, true), "with only one waiting, it doesn't")
		f:Hide()
	end

	-- ---- quest rewards: the line says there's room
	do
		local n, M = boot(pack)
		local MR = n.MakeRoom
		MR.Waiting = function() return { { id = 9741, name = "Shiny Ring", qty = 1, quality = 2, values = { vendor = 500 } } } end
		MR.quest = { kind = "complete", title = "A Quest" }
		MR:Show("quest"); M.runTimers()
		local f = MR.frame
		check(f.foot:IsShown() and f.foot.text == "Then there's room for Shiny Ring.", "quest rewards: \"Then there's room for Shiny Ring.\" (" .. tostring(f.foot.text) .. ")")
		f:Hide()
	end

	-- ---- Soul Shards: below the list and its button
	do
		local n, M = boot(function(M)
			pack(M)
			M.sizes[0] = 7
			M.put(0, 7, { id = 6265, name = "Soul Shard", q = 1, count = 1, stack = 1, class = 15, subclass = 0, price = 0 })
		end, "modern", { shardKeep = 0 }, "Warlock")
		loot = { { id = 9741, name = "Shiny Ring", q = 2 } }
		openLoot(M)
		local f = n.MakeRoom.frame
		check(f.shard:IsShown() and heads(f):find("Soul Shards$") and topOf(f.shard) > topOf(f.act), "a warlock's Soul Shards sit below the list and its button (" .. heads(f) .. ")")
		f:Hide()
	end
	_G.BagSmithDB = nil
end)()

;(function()
	-- ======== 1.7.0-beta10: section header values: one format for every header, the coin last (Shweep) ========
	for _, skin in ipairs({ "modern", "classic" }) do
		local S = skin .. ": "
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 9401, name = "Sword", q = 2, class = 2, subclass = 7, price = 500, equip = "INVTYPE_WEAPON", bind = 1, bound = true })
		M.put(0, 2, { id = 9402, name = "Axe", q = 2, class = 2, subclass = 0, price = 300, equip = "INVTYPE_WEAPON", bind = 2 })
		M.put(0, 3, { id = 9403, name = "Bread", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
		M.put(0, 4, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, view = "icons", grp = "type", splitView = true, splitGear = true, sizeMode = "fixed", fixW = 440, recentSection = false } } }
		_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function() return nil end,
			GetAuctionPriceByItemID = function(_, id) return ({ [9401] = 10000, [9402] = 5000, [2589] = 20 })[id] end } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		table.insert(n.db.cols, "ah"); table.insert(n.db.iconCols or {}, "ah")
		n.Window:Show(); n:RefreshViews(true); M.runTimers(); M.runTimers()
		local V = n.Window.main
		local function headers() local l = {}; for _, h in pairs(n.Buttons.lanes[V.child] or {}) do if h:IsShown() and h.laneId and h.laneId ~= "~recent" then l[#l + 1] = h end end; return l end
		local function lane(id) for _, h in ipairs(headers()) do if h.laneId == id then return h end end end
		check(V.twoColumn and lane("GearSoulbound") and lane("GearBoE"), S .. "(setup) Split View, narrow, with the gear split")
		-- (mock text is 6 px a letter: one long title stands in for a column too narrow, as in Split View at 440)
		local realW
		local function setTitle(id, w)
			local h = lane(id)
			realW = realW or h.text.GetStringWidth
			h.text.GetStringWidth = w and function() return w end or realW
		end
		local all = headers()
		check(#all >= 4 and lane("GearBoE").sub:IsShown() and lane("GearBoE").sub.text == "V: " .. n.Money(300) .. ", AH: " .. n.Money(5000), S .. "(control) with room: one line")
		setTitle("GearSoulbound", 260); n:RefreshViews(true); M.runTimers()
		all = headers()
		local coins = 0
		for _, h in ipairs(all) do if h.valCoin and h.valCoin:IsShown() and not h.sub:IsShown() and not h.vAmt:IsShown() then coins = coins + 1 end end
		check(coins == #all, S .. "one header too narrow for its values: every header shows the coin (" .. coins .. " of " .. #all .. ")")
		local boe = lane("GearBoE")
		check(boe.valCoin.v == n.Money(300) and boe.valCoin.ah == n.Money(5000), S .. "the coin holds that section's V and AH")
		boe.valCoin:GetScript("OnEnter")(boe.valCoin)
		local tip = table.concat(GameTooltip.lines or {}, " ")
		check(tip:find("V: " .. n.Money(300), 1, true) and tip:find("AH: " .. n.Money(5000), 1, true), S .. "hovering it shows them (" .. tip .. ")")
		boe.valCoin:GetScript("OnLeave")(boe.valCoin)
		local collapsedBefore = n.db.collapsed and n.db.collapsed.GearBoE
		GameTooltip:Hide()
		boe.valCoin:GetScript("OnClick")(boe.valCoin, "LeftButton")
		tip = table.concat(GameTooltip.lines or {}, " ")
		check(tip:find("V: " .. n.Money(300), 1, true) and (n.db.collapsed and n.db.collapsed.GearBoE) == collapsedBefore, S .. "clicking it shows the same, and doesn't collapse the section")
		GameTooltip:Hide()
		local sw = lane("GearSoulbound")
		check(sw.valCoin.ah == "-", S .. "soulbound gear has no AH value: its coin says AH: -")
		setTitle("GearSoulbound", nil); n:RefreshViews(true); M.runTimers()
		-- room enough: one line in every header, no coin
		local one = 0
		all = headers()
		for _, h in ipairs(all) do if h.sub:IsShown() and h.sub.text:find("^V: ") and not (h.valCoin and h.valCoin:IsShown()) then one = one + 1 end end
		check(#all > 0 and one == #all, S .. "with room: every header shows its values on one line, no coin (" .. one .. " of " .. #all .. ")")
		_G.Auctionator = nil
	end
	_G.BagSmithDB = nil
end)()

;(function()
	-- ======== 1.7.0-beta10: Gear: Other and Consumables: Other (Shweep) ========
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 5001, name = "Bound Helm", q = 2, class = 4, subclass = 4, price = 50, equip = "INVTYPE_HEAD", bind = 1, bound = true })
	M.put(0, 2, { id = 5004, name = "Use Bound Trinket", q = 2, class = 4, subclass = 0, price = 20, equip = "INVTYPE_TRINKET", bind = 3 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); n:RefreshViews(true); M.runTimers()
	local V = n.Window.main
	local function laneText(id) for _, h in pairs(n.Buttons.lanes[V.child] or {}) do if h:IsShown() and h.laneId == id then return h.text.text end end end
	check(n.Sections:Label("Gear") == "Gear" and laneText("Gear") == "Gear", "split off: Gear is Gear")
	n:Set("splitGear", true); M.runTimers(); n:RefreshViews(true); M.runTimers()
	check(n.Sections:Label("Gear") == "Gear: Other" and laneText("Gear") == "Gear: Other" and laneText("GearSoulbound") == "Gear: Soulbound",
		"split on: what's left in Gear reads Gear: Other, beside Gear: Soulbound (" .. tostring(laneText("Gear")) .. ")")
	check(n.CAT_LABEL.Gear == "Gear" and n.TAB_LABEL.Gear == "Gear", "the Gear tab and the category filter keep Gear (they cover all gear)")
	local P = n.SettingsPanel; P:Show(); P:ShowPage("sections"); M.runTimers()
	local label
	for _, l in ipairs(P.pools.list) do if l:IsShown() then for _, r in ipairs(l.rows) do if r:IsShown() and r.id == "Gear" then label = r.label and r.label.text or r.text and r.text.text end end end end
	check(label == "Gear: Other", "Settings > Sections lists it as Gear: Other (" .. tostring(label) .. ")")
	P:Hide()
	check(n.Sections:NameTaken("gear: other") and not n.Sections:NameTaken("Other Gear"), "a section of your own can't take the name Gear: Other while it's in use")
	n:Set("splitGearTypes", { Soulbound = false, BoE = false }); M.runTimers()
	check(n.Sections:Label("Gear") == "Gear", "both kinds unticked: nothing split out, so it's plain Gear again")
	n:Set("splitGear", false); M.runTimers()
	check(n.Sections:Label("Gear") == "Gear" and not n.Sections:NameTaken("Gear: Other"), "split off: Gear, and the name is free")
	check(n.CAT_LABEL.ConsOther == "Consumables: Other" and n.CONS_LABEL.Other == "Consumables: Other", "Other Consumables is now Consumables: Other")
	_G.BagSmithDB = nil
end)()
