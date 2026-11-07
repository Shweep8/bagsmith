;(function()
	-- 1.5.2: the 1.5.1-beta3 audit's two conditional P3s, deferred from 1.5.1, and Shweep's bank report.
	-- L6: a loot slot skipped only for the 1 s retry cooldown got no recheck, so after a fast hand-loot of another stack
	-- of the same item, automatic looting stalled until the next bag event. L7: a grey item whose quality only the cache
	-- reports was offered as junk, then refused by the final junk check (it read only the bag's quality). And in Classic,
	-- the bank's search box started under the portrait (its title row is empty there, so the search row sits level with
	-- the portrait).
	local ITEMS = {
		-- id = { name, vendor price, max stack, quality }
		[9701] = { "Broken Fang", 3, 1, 0 }, [9702] = { "Linen Belt", 22, 1, 1 }, [9882] = { "Prize Ring", 500, 1, 2 },
		[9883] = { "Rough Stone", 1, 20, 1 },
	}
	local loot, requested, bagQuality = {}, {}, {}
	local clock, due = 9500, {}
	local function advance(dt)
		local target = clock + (dt or 0)
		while true do
			table.sort(due, function(a, b) return a.at < b.at end)
			local t = due[1]
			if not t or t.at > target then break end
			table.remove(due, 1)
			if t.at > clock then clock = t.at end
			t.fn()
		end
		clock = target
	end
	local function boot(stock, size, profile, skin)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return "Warrior", "WARRIOR" end
		for b = 0, 5 do M.sizes[b] = 0 end
		M.sizes[0] = size
		M.maxStack = {}
		for id, it in pairs(ITEMS) do M.maxStack[id] = it[3] end
		bagQuality = {}
		stock(M)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = skin or "modern", makeRoom = true, makeRoomValue = "vendor" }
		for k, v in pairs(profile or {}) do p[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
		local realCI = C_Container.GetContainerItemInfo
		C_Container.GetContainerItemInfo = function(bag, slot)
			local info = realCI(bag, slot)
			if info and bagQuality[info.itemID] ~= nil then info.quality = bagQuality[info.itemID] or nil end
			return info
		end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id)
			local num = tonumber(tostring(id):match("item:(%d+)")) or id
			local it = ITEMS[num]
			if it then return it[1], nil, it[4], nil, nil, nil, nil, it[3], nil, nil, it[2] end
			return realInfo(id)
		end
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id; M.cursorFrom = { bag, slot } end
		_G.ClearCursor = function() M.cursorItem = nil end
		M.deleted = 0
		_G.DeleteCursorItem = function() if M.cursorFrom then M.bags[M.cursorFrom[1]][M.cursorFrom[2]] = nil end; M.cursorItem = nil; M.deleted = M.deleted + 1 end
		_G.GetNumLootItems = function() local c = 0; for i = 1, 6 do if loot[i] then c = i end end; return c end
		_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
		_G.GetLootSlotLink = function(i) local l = loot[i]; return l and ("|Hitem:" .. l.id .. ":0|h[" .. ITEMS[l.id][1] .. "]|h") end
		_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", ITEMS[l.id][1], l.qty or 1, nil, 2 end end
		requested = {}
		_G.LootSlot = function(i) requested[#requested + 1] = i end
		clock, due = 9500, {}
		_G.GetTime = function() return clock end
		C_Timer.After = function(d, fn) due[#due + 1] = { at = clock + (d or 0), fn = fn } end
		return n, M
	end
	local function item(id, extra)
		local it = ITEMS[id]
		local t = { id = id, name = it[1], q = it[4], class = 15, subclass = 0, price = it[2] }
		for k, v in pairs(extra or {}) do t[k] = v end
		return t
	end
	local function asked() return table.concat(requested, ",") end
	local function count(slot) local c = 0; for _, s in ipairs(requested) do if s == slot then c = c + 1 end end; return c end

	-- ---- L6: a slot skipped only for the retry cooldown is rechecked when the cooldown ends
	local n, M = boot(function(B) for s = 1, 3 do B.put(0, s, item(9701)) end end, 3)
	loot = { { id = 9883, qty = 20 }, { id = 9883, qty = 20 } }
	M.fire("LOOT_OPENED"); advance(0.2)
	M.bags[0][1] = nil; M.bags[0][2] = nil; n:Scan(); advance(0)
	check(asked() == "1", "L6: two slots free, BagSmith asks for slot 1 (asked: " .. asked() .. ")")
	advance(0.1); M.put(0, 1, item(9883, { count = 20 })); n:Scan(); advance(0)   -- slot 2, looted by hand, lands first
	advance(0.1); loot[2] = nil; M.fire("LOOT_SLOT_CLEARED", 2); advance(0)      -- and clears within the cooldown
	local before = count(1)
	advance(2)                                                                     -- no bag event at all
	check(count(1) > before, "L6: slot 1, still waiting and still fitting, is asked for again when the cooldown ends, without another bag event (asked: " .. asked() .. ")")
	-- control: nothing is asked for again and again (the request is now out, the guard holds)
	local now = #requested
	advance(0.5)
	check(#requested == now, "L6: one recheck, not a stream of them (asked: " .. asked() .. ")")

	-- ---- L7: a grey item whose quality only the cache reports can be destroyed by its junk action
	n, M = boot(function(B) B.put(0, 1, item(9701)); B.put(0, 2, item(9702)); bagQuality[9701] = false end, 2)
	loot = { { id = 9882 } }
	M.fire("LOOT_OPENED"); advance(0.2)
	local f = n.MakeRoom.frame
	check(f and f:IsShown() and f.act.label.text == "Destroy Broken Fang" and f.act.tip == "Junk: destroyed in one click", "L7: the grey fang, known grey only from the cache, is offered as junk (" .. tostring(f and f.act.label.text) .. ", " .. tostring(f and f.act.tip) .. ")")
	f.act:GetScript("OnClick")(f.act)
	check(M.deleted == 1 and M.bags[0][1] == nil, "L7: and one click destroys it, instead of refusing it as changed")
	-- control: a quality nobody reports isn't taken as junk at the final check
	n, M = boot(function(B) B.put(0, 1, item(9701)); B.put(0, 2, item(9702)) end, 2)
	loot = { { id = 9882 } }
	M.fire("LOOT_OPENED"); advance(0.2)
	f = n.MakeRoom.frame
	bagQuality[9701] = false
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(id) local num = tonumber(tostring(id):match("item:(%d+)")) or id; if num == 9701 then return "Broken Fang", nil, nil, nil, nil, nil, nil, 1, nil, nil, 3 end return realInfo(id) end
	f.act:GetScript("OnClick")(f.act)
	check(M.deleted == 0, "L7 (control): an offered junk item whose quality no source reports any more is kept")

	-- ---- Classic: the bank's search box starts clear of the portrait
	n, M = boot(function(B) B.put(0, 1, item(9702)) end, 4, nil, "classic")
	M.runTimers()
	M.fire("BANKFRAME_OPENED"); M.runTimers()
	local bk = n.Window.bank
	local p = bk.search.points[1]
	check(bk.belowShift == -48 and p and p[2] == bk.title and p[4] >= 0, "Classic bank: the search box starts at or right of the title's left edge, clear of the portrait (x " .. tostring(p and p[4]) .. ")")
	local q = bk.search.points[2]
	check(q and q[4] == (bk.toolsEnd or 400) - bk.btnFilter:GetWidth() - 6 + bk.belowShift, "Classic bank: its right end stays where it was, beside the Filter button")
	local V = n.Window.main
	check(V.search.points[1][4] == 4 - 48, "Classic bags window: unchanged, the search row starts at the inner margin")
	-- Where rows really are: follow each frame's left anchors back to the title (the search box's own anchor isn't
	-- enough; in 1.5.2-beta1 the toolbar hung from it, so every row below moved with it).
	local function leftOf(fr, title)
		local x, guard = 0, 0
		while fr and fr ~= title and guard < 10 do
			local pt = fr.points and fr.points[1]
			if not pt then return nil end
			x = x + (pt[4] or 0); fr = pt[2]; guard = guard + 1
		end
		return fr == title and x or nil
	end
	check(leftOf(bk.tools, bk.title) == -48, "Classic bank: the toolbar row stays at the inner margin, under the portrait (x " .. tostring(leftOf(bk.tools, bk.title)) .. ")")
	check(leftOf(bk.search, bk.title) >= 0, "Classic bank: only the search box moves clear of the portrait")
	check(leftOf(V.tools, V.title) == -48 and leftOf(V.search, V.title) == -44, "Classic bags window: the toolbar and search box are where they were")
	n:Set("skin", "modern"); M.runTimers()
	check(bk.search.points[1][4] == 4 and V.search.points[1][4] == 4, "Modern: both unchanged")
	check(leftOf(bk.tools, bk.title) == 0 and leftOf(V.tools, V.title) == 0, "Modern: both toolbars where they were")
end)()
