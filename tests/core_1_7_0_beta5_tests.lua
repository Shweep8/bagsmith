;(function()
	-- ======== 1.7.0-beta5: the answer to the 1.7.0-beta4 audit, and the card's new name ========
	-- ---- F1: Destroy Shards never goes below Soul Shards to Keep: the shards are counted live right before each delete
	local deleted = 0
	local function shardBoot(prof, setup)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return "Warlock", "WARLOCK" end
		for b = 1, 5 do M.sizes[b] = 0 end
		M.sizes[0] = 4
		M.put(0, 1, { id = 6265, name = "Soul Shard", q = 1, count = 1, stack = 1, class = 15, subclass = 0, price = 0 })
		M.put(0, 2, { id = 6265, name = "Soul Shard", q = 1, count = 1, stack = 1, class = 15, subclass = 0, price = 0 })
		M.put(0, 3, { id = 6265, name = "Soul Shard", q = 1, count = 1, stack = 1, class = 15, subclass = 0, price = 0 })
		if setup then setup(M) end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local pr = { makeRoom = true, makeRoomValue = "vendor", makeRoomAsk = false, shardKeep = 1 }
		for k, v in pairs(prof or {}) do pr[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = pr } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		C_Container.PickupContainerItem = function(b, s) local i = M.bags[b][s]; M.cursorItem = i and i.id; M.cursorSlot = { b, s } end
		_G.ClearCursor = function() M.cursorItem = nil end
		_G.DeleteCursorItem = function() deleted = deleted + 1; local p = M.cursorSlot; M.bags[p[1]][p[2]] = nil; M.cursorItem = nil end
		local said = {}
		local print_ = n.Print
		n.Print = function(self, msg, ...) said[#said + 1] = tostring(msg); return print_(self, msg, ...) end
		return n, M, said
	end
	-- removal while a scan is pending (a Clean Up holds it), then the last one above the keep
	do
		deleted = 0
		local n, M, said = shardBoot()
		local MR = n.MakeRoom
		MR:ShowShards()
		check(select(2, MR:Shards()) == 2, "(setup) three shards, keep one: two may go")
		n:NoteCleanup(); M.bags[0][2], M.bags[0][3] = nil, nil; M.fire("BAG_UPDATE_DELAYED")
		check(n.cleanupScanQueued and select(2, MR:Shards()) == 2, "(setup) two used up, the scan held: the old count still says two may go")
		MR:DestroyNextShard(MR.frame.shard.go)
		check(deleted == 0 and M.bags[0][1] ~= nil, "one shard left, keep one: nothing is destroyed")
		check(said[#said] == "That would leave you with fewer than 1 Soul Shard, so nothing was destroyed.", "and it says why (" .. tostring(said[#said]) .. ")")
		check(MR.shardBatch == nil, "the batch ends")
		n:Scan(); M.runTimers()
	end
	-- moved to another bag: still counted
	do
		deleted = 0
		local n, M, said = shardBoot(nil, function(M) M.sizes[1] = 2 end)
		local MR = n.MakeRoom
		MR:ShowShards()
		n:NoteCleanup(); M.bags[1][1] = M.bags[0][3]; M.bags[0][3] = nil; M.fire("BAG_UPDATE_DELAYED")
		MR:DestroyNextShard(MR.frame.shard.go)
		check(deleted == 1, "a shard moved to another bag still counts: three live, one goes (" .. deleted .. ")")
	end
	-- a soul bag's shards count toward the keep (and are never destroyed)
	do
		deleted = 0
		local n, M = shardBoot(nil, function(M)
			M.sizes[1] = 2
			M.put(1, 1, { id = 6265, name = "Soul Shard", q = 1, count = 1, stack = 1, class = 15, subclass = 0, price = 0 })
			M.bags[0][2], M.bags[0][3] = nil, nil
		end)
		local free = C_Container.GetContainerNumFreeSlots
		C_Container.GetContainerNumFreeSlots = function(bag) local f, fam = free(bag); if bag == 1 then return f, 4 end return f, fam end
		local MR = n.MakeRoom
		n:Scan(); M.runTimers()
		MR:ShowShards()
		MR:DestroyNextShard(MR.frame.shard.go)
		check(deleted == 1 and M.bags[1][1] ~= nil and M.bags[0][1] == nil, "one in the backpack and one in a soul bag, keep one: the backpack's goes, the soul bag's stays")
		C_Container.GetContainerNumFreeSlots = free
	end
	-- the keep raised mid-batch
	do
		deleted = 0
		local n, M, said = shardBoot()
		local MR = n.MakeRoom
		MR:ShowShards(); MR.shardQty = 2
		MR:DestroyNextShard(MR.frame.shard.go)
		check(deleted == 1 and MR.shardBatch == 1, "(setup) a batch of two: one gone, one to go")
		n.db.shardKeep = 2
		MR:DestroyNextShard(MR.frame.shard.go)
		check(deleted == 1, "Soul Shards to Keep raised to two mid-batch: the next click destroys nothing")
	end
	-- the question's Yes, with a scan pending
	do
		deleted = 0
		local n, M, said = shardBoot({ makeRoomAsk = true })
		local MR = n.MakeRoom
		MR:ShowShards(); MR.shardQty = 2
		MR:DestroyNextShard(MR.frame.shard.go)
		local c = n.Popups.confirm
		check(c and c:IsShown() and deleted == 0, "(setup) asked first")
		n:NoteCleanup(); M.bags[0][2], M.bags[0][3] = nil, nil; M.fire("BAG_UPDATE_DELAYED")
		c.yes:GetScript("OnClick")(c.yes)
		check(deleted == 0 and M.bags[0][1] ~= nil, "Yes, after two were used with the scan held: nothing destroyed")
	end
	-- a bag that can't be read: nothing destroyed
	do
		deleted = 0
		local n, M, said = shardBoot()
		local MR = n.MakeRoom
		MR:ShowShards()
		local info = C_Container.GetContainerItemInfo
		C_Container.GetContainerItemInfo = function(bag, slot) if bag == 0 and slot == 4 then error("not ready") end return info(bag, slot) end
		MR:DestroyNextShard(MR.frame.shard.go)
		check(deleted == 0 and said[#said] == "BagSmith couldn't count your Soul Shards just now, so nothing was destroyed. Try again in a moment.", "a bag that can't be read: nothing destroyed, and it says so")
		C_Container.GetContainerItemInfo = info
		MR:DestroyNextShard(MR.frame.shard.go)
		check(deleted == 1, "(control) readable again: one goes")
	end

	-- ---- F2: a quest log that can't be read fails closed; readings are remembered for the session
	local loot = { { id = 9740, name = "Rough Gem" } }
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("|Hitem:" .. loot[i].id .. ":0|h[" .. loot[i].name .. "]|h") end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, 1, nil, 1 end end
	_G.LootSlot = function() end
	local log = {}   -- { title, header, collapsed, questID, objs = { { text, kind } }, failTitle, failCount, failObj = j }
	local fail = {}
	local function api(objectivesToo)
		_G.GetNumQuestLogEntries = function() if fail.count then error("count") end return #log end
		_G.GetQuestLogTitle = function(i) local q = log[i]; if not q then return nil end; if q.failTitle then error("title") end; return q.title, 10, 0, q.header, q.collapsed, false, 0, q.questID end
		_G.GetNumQuestLeaderBoards = function(i) local q = log[i]; if q.failCount then error("leaderboards") end return #(q.objs or {}) end
		_G.GetQuestLogLeaderBoard = function(j, i) local q = log[i]; if q.failObj == j then error("objective") end; local o = (q.objs or {})[j]; if o then return o[1], o[2], false end end
		_G.C_QuestLog = objectivesToo and { GetQuestObjectives = function(id) for _, q in ipairs(log) do if q.questID == id then local out = {}; for _, o in ipairs(q.objs or {}) do out[#out + 1] = { text = o[1], type = o[2] } end return out end end return {} end } or nil
	end
	local function lootBoot(skin)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return "Warrior", "WARRIOR" end
		for b = 1, 5 do M.sizes[b] = 0 end
		M.sizes[0] = 3
		M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, stack = 20, class = 7, subclass = 5, price = 1 })
		M.put(0, 2, { id = 9720, name = "Gnoll Paw", q = 1, count = 2, stack = 20, class = 15, subclass = 0, price = 2 })
		M.put(0, 3, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 9, equip = "INVTYPE_WAIST" })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, makeRoom = true, makeRoomValue = "vendor", makeRoomAsk = false } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id) local num = tonumber(tostring(id):match("item:(%d+)")) or id; if num == 9740 then return "Rough Gem", nil, 1, nil, nil, nil, nil, 1, nil, nil, 50 end return realInfo(id) end
		C_Container.PickupContainerItem = function(b, s) local i = M.bags[b][s]; M.cursorItem = i and i.id; M.cursorSlot = { b, s } end
		_G.ClearCursor = function() M.cursorItem = nil end
		_G.DeleteCursorItem = function() deleted = deleted + 1; local p = M.cursorSlot; M.bags[p[1]][p[2]] = nil; M.cursorItem = nil end
		local said = {}
		local print_ = n.Print
		n.Print = function(self, msg, ...) said[#said + 1] = tostring(msg); return print_(self, msg, ...) end
		return n, M, said
	end
	local function offered(f) local t = {}; for _, r in ipairs(f.destroyRows) do if r:IsShown() then t[#t + 1] = r.name.text end end; table.sort(t); return table.concat(t, ",") end
	local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
	for _, skin in ipairs({ "modern", "classic" }) do
		local S = skin .. ": "
		deleted = 0
		log, fail = {}, {}
		api(false)
		local n, M, said = lootBoot(skin)
		local MR = n.MakeRoom
		M.fire("LOOT_OPENED"); M.runTimers()
		local f = MR.frame
		check(f and f:IsShown() and offered(f) == "Gnoll Paw,Linen Belt,Linen Cloth", S .. "(setup) nothing needed: all three offered (" .. (f and offered(f) or "") .. ")")
		local cloth = MR:Offer(recOf(n, 2589), false, "priced", 5)
		-- the count can't be read, nothing remembered: nothing offered, nothing destroyed
		fail.count = true; MR:Refresh()
		check(offered(f) == "" and f.card:IsShown() and (f.card.text.text or ""):find("3 items that couldn't be checked", 1, true), S .. "the quest log can't be read: nothing is offered; the card counts all three as couldn't be checked")
		local ok, why = MR:StillOk(cloth)
		check(ok == false and why == "questlog", S .. "an earlier offer is refused at the click (" .. tostring(why) .. ")")
		check(not MR:Destroy(cloth, true) and deleted == 0 and said[#said] == "BagSmith couldn't check your quests just now, so nothing was destroyed. Try again in a moment.", S .. "even after a Yes, with that message")
		fail.count = nil
		-- a quest's title can't be read
		log = { { title = "Wool Donation", questID = 77, objs = { { "Linen Cloth: 2/20", "item" } }, failTitle = true } }
		MR:Refresh()
		check(offered(f) == "" and select(2, MR:StillOk(cloth)) == "questlog", S .. "a title that can't be read: the same")
		-- read once, then its objectives fail: the last good reading stands
		log[1].failTitle = nil; MR:Refresh()
		check(offered(f) == "Gnoll Paw,Linen Belt" and select(2, MR:StillOk(cloth)) == "questneed", S .. "read: Linen Cloth kept for the quest, the rest offered")
		log[1].failCount = true; MR:Refresh()
		check(offered(f) == "Gnoll Paw,Linen Belt" and select(2, MR:StillOk(cloth)) == "questneed", S .. "its objective count fails: the last reading still keeps the Cloth, the rest still offered")
		log[1].failCount = nil; log[1].failObj = 1; MR:Refresh()
		check(select(2, MR:StillOk(cloth)) == "questneed", S .. "one objective fails: the same")
		-- a new quest whose objectives fail, nothing remembered: closed
		log[2] = { title = "Paw Hunt", questID = 78, objs = { { "Gnoll Paw: 1/8", "item" }, { "Wolf Pelt: 0/4", "item" } }, failObj = 2 }
		MR:Refresh()
		local paw = MR:Offer(recOf(n, 9702), false, "priced", 9)
		check(offered(f) == "" and select(2, MR:StillOk(paw)) == "questlog", S .. "a new quest read only in part (one objective fails), nothing remembered: closed")
		-- the other reader saves it
		api(true); MR:Refresh()
		check(offered(f) == "Linen Belt" and select(2, MR:StillOk(paw)) == nil and MR:StillOk(paw) == true, S .. "C_QuestLog's objectives read it: the Paw kept, the Belt offered again")
		api(false); log[1].failObj, log[2].failObj = nil, nil
		-- collapsed: the quest under it is remembered
		log = { { title = "Elwynn", header = true, collapsed = true } }
		MR:Refresh()
		check(offered(f) == "Linen Belt", S .. "both quests' heading collapsed: still kept (remembered this session) (" .. offered(f) .. ")")
		-- turned in while collapsed: forgotten
		M.fire("QUEST_TURNED_IN", 77, 0, 0); MR:Refresh()
		check(offered(f) == "Linen Belt,Linen Cloth", S .. "the Cloth's quest turned in: the Cloth is offered again (" .. offered(f) .. ")")
		M.fire("QUEST_REMOVED", 78); MR:Refresh()
		check(offered(f) == "Gnoll Paw,Linen Belt,Linen Cloth", S .. "the Paw's quest abandoned: the Paw too")
		-- the whole log in view without a quest: it's forgotten even without the events
		log = { { title = "Wool Donation", questID = 77, objs = { { "Linen Cloth: 2/20", "item" } } } }; MR:Refresh()
		check(offered(f) == "Gnoll Paw,Linen Belt", S .. "(setup) the quest back")
		log = {}; MR:Refresh()
		check(offered(f) == "Gnoll Paw,Linen Belt,Linen Cloth", S .. "the whole log in view, the quest gone from it: forgotten")
		-- no quest log functions on the client: nothing to read, nothing held
		_G.GetNumQuestLogEntries = nil; MR:Refresh()
		check(offered(f) == "Gnoll Paw,Linen Belt,Linen Cloth" and MR:StillOk(cloth) == true, S .. "a client without the quest log functions: nothing held back")
		api(false)
		-- the question's Yes after the log stops reading
		n.db.makeRoomAsk = true
		log = {}; MR:Refresh()
		local row; for _, r in ipairs(f.destroyRows) do if r:IsShown() and r.name.text == "Linen Belt" then row = r end end
		row:GetScript("OnClick")(row); f.act:GetScript("OnClick")(f.act)
		local c = n.Popups.confirm
		check(c and c:IsShown(), S .. "(setup) asked first")
		local before = deleted
		fail.count = true
		c.yes:GetScript("OnClick")(c.yes)
		check(deleted == before and M.bags[0][3] ~= nil, S .. "Yes after the quest log stopped reading: nothing destroyed")
		fail.count = nil; n.db.makeRoomAsk = false
		-- the wording
		local L = f.footInfo.lines
		check(L[3] == "Anything you still need for a quest is never on the list, unless its heading is collapsed in your quest log.", S .. "the (i): the quest line says what it can't see")
		f:Hide()
		local P = n.SettingsPanel; P:Show(); P:ShowPage("loothelper"); M.runTimers()
		local all = {}
		for _, w in ipairs(P.pools.text) do if w:IsShown() then all[#all + 1] = w.text.text end end
		check(table.concat(all, "\n"):find("Anything you still need for a quest is never on the list, unless its heading is collapsed in your quest log.", 1, true), S .. "Settings > Loot Helper says the same")
		P:Hide()
	end
	_G.GetNumQuestLogEntries, _G.GetQuestLogTitle, _G.GetNumQuestLeaderBoards, _G.GetQuestLogLeaderBoard, _G.C_QuestLog = nil, nil, nil, nil, nil
	_G.GetNumLootItems, _G.GetLootSlotType, _G.GetLootSlotLink, _G.GetLootSlotInfo = nil, nil, nil, nil

	-- ---- F3: a column heading shows only with its own rows; and the card's new name
	for _, skin in ipairs({ "modern", "classic" }) do
		local S = skin .. ": "
		package.loaded.mock = nil
		local M = require("mock")
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, pinnedHighlight = true } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Sections:Create("Professions")
		local P = n.SettingsPanel; P:Show(); P:ShowPage("sections"); M.runTimers()
		local heads = {}
		for _, w in ipairs(P.pools.head) do if w:IsShown() then heads[#heads + 1] = w.text.text end end
		check(heads[#heads] == "Move, Pin and Hide Sections", S .. "the card's name: Move, Pin and Hide Sections (" .. tostring(heads[#heads]) .. ")")
		local first
		for _, w in ipairs(P.pools.text) do if w:IsShown() and w.text.text:find("^Your sections show in this order") then first = w end end
		check(first and first.text.text == "Your sections show in this order, dynamic and custom ones included. Use the arrows to move one.", S .. "its first line")
		local function count(pool) local c = 0; for _, w in ipairs(P.pools[pool]) do if w:IsShown() then c = c + 1 end end return c end
		for _, q in ipairs({ { "vendor", true }, { "highlight", false }, { "opacity", false }, { "highlight opacity", false }, { "order", true }, { "arrange", true } }) do
			P:SetQuery(q[1]); M.runTimers()
			local h, l = count("listhead"), count("list")
			if q[2] then check(h == 1 and l >= 1, S .. "\"" .. q[1] .. "\": the table, with its headings (" .. h .. ", " .. l .. ")")
			else check(h == 0, S .. "\"" .. q[1] .. "\": no headings without their table (" .. h .. ", " .. l .. ")") end
		end
		-- the same for the custom sections' headings
		P:SetQuery("moved"); M.runTimers()
		check(count("moved") >= 1 and count("csechead") == 0, S .. "\"moved\": the moved-items row, without the custom sections' headings")
		P:SetQuery("professions"); M.runTimers()
		check(count("csec") == 1 and count("csechead") == 1, S .. "\"professions\": the custom section's row, with its headings")
		P:SetQuery(""); M.runTimers()
		P:Hide()
	end
end)()
