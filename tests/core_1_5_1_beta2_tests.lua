;(function()
	-- 1.5.1-beta2: Ask Before Destroying (off by default) with Always Ask for Rare or Better (on by default, nested,
	-- greyed while the first is on); junk always one click; Soul Shards follow the first; the cheapest destroy row
	-- chosen first when nothing lossless is offered. And the canvas repair on every window open (Shweep: after a
	-- reload the bags window opened blank, in both styles, until List and Icons were swapped).
	local ITEMS = {
		[9701] = { "Broken Fang", 3, 1 }, [9702] = { "Linen Belt", 22, 1 }, [9871] = { "Blue Blade", 40, 1 },
		[9872] = { "Prize Ring", 500, 1 }, [9873] = { "Linen Cloth", 1, 20 }, [6265] = { "Soul Shard", 0, 1 },
	}
	local loot = {}
	local function boot(stock, size, profile, class)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return class or "Warrior", (class or "Warrior"):upper() end
		for b = 0, 5 do M.sizes[b] = 0 end
		M.sizes[0] = size
		M.maxStack = {}
		for id, it in pairs(ITEMS) do M.maxStack[id] = it[3] end
		stock(M)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = "modern", makeRoom = true, makeRoomValue = "vendor" }
		for k, v in pairs(profile or {}) do p[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id)
			local num = tonumber(tostring(id):match("item:(%d+)")) or id
			local it = ITEMS[num]
			if it then return it[1], nil, 1, nil, nil, nil, nil, it[3], nil, nil, it[2] end
			return realInfo(id)
		end
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id; M.cursorFrom = { bag, slot } end
		_G.ClearCursor = function() M.cursorItem = nil end
		M.deleted = 0
		_G.DeleteCursorItem = function() if M.cursorFrom then M.bags[M.cursorFrom[1]][M.cursorFrom[2]] = nil end; M.cursorItem = nil; M.deleted = M.deleted + 1 end
		_G.GetNumLootItems = function() local c = 0; for i = 1, 6 do if loot[i] then c = i end end; return c end
		_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
		_G.GetLootSlotLink = function(i) local l = loot[i]; return l and ("|Hitem:" .. l.id .. ":0|h[" .. ITEMS[l.id][1] .. "]|h") end
		_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", ITEMS[l.id][1], 1, nil, 2 end end
		_G.LootSlot = function() end
		return n, M
	end
	local function item(id, extra)
		local it = ITEMS[id]
		local t = { id = id, name = it[1], q = 1, class = 15, subclass = 0, price = it[2] }
		for k, v in pairs(extra or {}) do t[k] = v end
		return t
	end
	local function act(n) local f = n.MakeRoom.frame; f.act:GetScript("OnClick")(f.act); return n.Popups.confirm end
	local function asking(n) local c = n.Popups.confirm; return c and c:IsShown() or false end
	local function open(M) loot = { { id = 9872 } }; M.fire("LOOT_OPENED"); M.runTimers() end

	-- ---- the defaults
	local n, M = boot(function(B) B.put(0, 1, item(9702)); B.put(0, 2, item(9871, { q = 3 })) end, 2)
	check(n.db.makeRoomAsk == false and n.db.makeRoomAskRare == true, "defaults: Ask Before Destroying off, Always Ask for Rare or Better on")
	open(M)
	local f = n.MakeRoom.frame
	check(f:IsShown() and f.act.label.text == "Destroy Linen Belt", "the cheapest destroy row is chosen first when nothing lossless is offered (" .. tostring(f.act.label.text) .. ")")
	check(f.act.tip == "Destroyed at once", "its button says it acts at once (" .. tostring(f.act.tip) .. ")")
	act(n)
	check(not asking(n) and M.deleted == 1 and M.bags[0][1] == nil, "a common item is destroyed at once, with no question")

	-- a rare item still asks, like the game
	n, M = boot(function(B) B.put(0, 1, item(9871, { q = 3 })); B.put(0, 2, item(9871, { q = 3 })) end, 2)
	open(M); f = n.MakeRoom.frame
	check(f.act.tip == "Asks before destroying", "a blue item's button says it asks (" .. tostring(f.act.tip) .. ")")
	local c = act(n)
	check(asking(n) and M.deleted == 0, "a blue item still asks first with the defaults")
	c.yes:GetScript("OnClick")(c.yes)
	check(M.deleted == 1, "and Yes destroys it")

	-- unticking Always Ask for Rare or Better lets rare items go at once too
	n, M = boot(function(B) B.put(0, 1, item(9871, { q = 3 })); B.put(0, 2, item(9871, { q = 3 })) end, 2, { makeRoomAskRare = false })
	open(M); act(n)
	check(not asking(n) and M.deleted == 1, "with Always Ask for Rare or Better off, a blue item goes at once")

	-- Ask Before Destroying on: everything but junk asks
	n, M = boot(function(B) B.put(0, 1, item(9702)); B.put(0, 2, item(9871)) end, 2, { makeRoomAsk = true })
	open(M); act(n)
	check(asking(n) and M.deleted == 0, "Ask Before Destroying on: a common item asks first")
	n, M = boot(function(B) B.put(0, 1, item(9701, { q = 0 })); B.put(0, 2, item(9871)) end, 2, { makeRoomAsk = true })
	open(M); f = n.MakeRoom.frame
	check(f.act.label.text == "Destroy Broken Fang" and f.act.tip == "Junk: destroyed in one click", "junk is chosen first and says one click")
	act(n)
	check(not asking(n) and M.deleted == 1, "junk always goes in one click, even with Ask Before Destroying on")

	-- a lossless way still comes first when there is one
	n, M = boot(function(B) B.put(0, 1, item(9873, { count = 5 })); B.put(0, 2, item(9873, { count = 7 })) end, 2)
	open(M); f = n.MakeRoom.frame
	check(f.act.label.text == "Combine Linen Cloth", "with a lossless way offered, it's chosen first (" .. tostring(f.act.label.text) .. ")")

	-- ---- Soul Shards follow Ask Before Destroying
	local function shards(profile)
		local nn, MM = boot(function(B) for s = 1, 3 do B.put(0, s, item(6265, { q = 1 })) end end, 3, profile, "Warlock")
		nn.MakeRoom:ShowShards()
		local ff = nn.MakeRoom.frame
		ff.shard.go:GetScript("OnClick")(ff.shard.go)
		return nn, MM, ff
	end
	n, M, f = shards()
	check(not asking(n) and M.deleted == 1, "Soul Shards, Ask Before Destroying off: the first click destroys the first shard, no question")
	n, M, f = shards({ makeRoomAsk = true })
	check(asking(n) and M.deleted == 0, "Soul Shards, Ask Before Destroying on: it asks how many first")

	-- ---- the settings rows
	n, M = boot(function() end, 4)
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("loothelper")
	local function row(key) for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == key then return w end end end
	local ask, rare = row("makeRoomAsk"), row("makeRoomAskRare")
	check(ask and ask.text.text == "Ask Before Destroying" and not ask.box:GetChecked(), "Settings > Loot Helper: Ask Before Destroying, off")
	check(ask and (ask.help.text or ""):find("at once", 1, true) and (ask.help.text or ""):find("Junk always goes in one click", 1, true), "its help says what off means and that junk is always one click (" .. tostring(ask and ask.help.text) .. ")")
	check(rare and rare.text.text == "Always Ask for Rare or Better" and rare.box:GetChecked() and rare.box:IsEnabled(), "Always Ask for Rare or Better, on and usable")
	check(rare and ask and rare.points[1][4] > ask.points[1][4], "it's nested under Ask Before Destroying (" .. tostring(rare and rare.points[1][4]) .. " vs " .. tostring(ask and ask.points[1][4]) .. ")")
	n:Set("makeRoomAsk", true)
	rare = row("makeRoomAskRare")
	check(rare and rare.box:GetChecked() and not rare.box:IsEnabled(), "while Ask Before Destroying is on, it shows ticked and greyed out")
	n:Set("makeRoomAsk", false)
	rare = row("makeRoomAskRare")
	check(rare and rare.box:IsEnabled(), "and usable again when it's off")
	for _, word in ipairs({ "destroy", "confirm", "ask" }) do
		P:SetQuery(word)
		check(row("makeRoomAsk") and row("makeRoomAskRare"), ("searching \"%s\" finds both settings"):format(word))
	end
	P:SetQuery("")

	-- ---- the canvas repair runs whenever a window opens
	n, M = boot(function(B) B.put(0, 1, item(9702)) end, 16)
	local m = n.Window.main
	local whys = {}
	local real = m.RefreshCanvas
	m.RefreshCanvas = function(self, why) whys[#whys + 1] = why; return real(self, why) end
	local reattached = 0
	local realSet = m.scroll.SetScrollChild
	m.scroll.SetScrollChild = function(sf, child) reattached = reattached + 1; return realSet(sf, child) end
	n.Window:Show(); M.runTimers(); M.runTimers()
	local shown = false
	for _, w in ipairs(whys) do if w == "show" then shown = true end end
	check(shown and reattached >= 1, "opening the bags window re-attaches its list canvas on the next frame (" .. table.concat(whys, ",") .. "; " .. reattached .. " re-attach)")
	n.Window:Hide(); whys = {}; reattached = 0
	n.Window:Show(); M.runTimers(); M.runTimers()
	shown = false
	for _, w in ipairs(whys) do if w == "show" then shown = true end end
	check(shown and reattached >= 1, "and again on every later open")
end)()
