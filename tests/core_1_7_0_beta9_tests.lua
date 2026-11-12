;(function()
	-- ======== 1.7.0-beta9: the answer to the 1.7.0-beta8 audit ========
	-- A1: a delete the game refuses (silently or with an error) is checked for: the item goes back, nothing counts it as
	-- gone, and a Soul Shard batch ends. A2: blank item text and C_QuestLog lists with holes are failed reads.
	-- F1: /bs questlog counts quest IDs by the reader's rule.
	local BLOCKED = "The game wouldn't let BagSmith destroy that, so it's back in your bags. You can still drag it out of your bags to destroy it yourself."
	local SHARD_BLOCKED = "The game wouldn't let BagSmith destroy that Soul Shard, so it's back in your bags. You can still drag it out of your bags to destroy it yourself."
	local function boot(prof)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return "Warlock", "WARLOCK" end
		for b = 1, 5 do M.sizes[b] = 0 end
		M.sizes[0] = 4
		M.put(0, 1, { id = 6265, name = "Soul Shard", q = 1, count = 1, stack = 1, class = 15, subclass = 0, price = 0 })
		M.put(0, 2, { id = 6265, name = "Soul Shard", q = 1, count = 1, stack = 1, class = 15, subclass = 0, price = 0 })
		M.put(0, 3, { id = 2589, name = "Linen Cloth", q = 1, count = 1, stack = 20, class = 7, subclass = 5, price = 1 })
		M.put(0, 4, { id = 4865, name = "Ruined Pelt", q = 1, count = 1, stack = 20, class = 15, subclass = 0, price = 2 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local pr = { makeRoom = true, makeRoomValue = "vendor", makeRoomAsk = false, shardKeep = 0 }
		for k, v in pairs(prof or {}) do pr[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = pr } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		C_Container.PickupContainerItem = function(b, s) local i = M.bags[b][s]; M.cursorItem = i and i.id; M.cursorSlot = { b, s } end
		_G.ClearCursor = function() M.cursorItem = nil end
		_G.GetNumQuestLogEntries = function() return 0, 0 end
		_G.GetQuestLogLeaderBoard = nil; _G.C_QuestLog = nil
		local MR = n.MakeRoom
		MR.Waiting = function() return { { id = 9999, values = { vendor = 100 } } } end
		local said = {}
		local print_ = n.Print
		n.Print = function(self, msg, ...) said[#said + 1] = select("#", ...) > 0 and msg:format(...) or tostring(msg); return print_(self, msg, ...) end
		return n, M, MR, said
	end
	local function works(M) return function() local p = M.cursorSlot; M.bags[p[1]][p[2]] = nil; M.cursorItem = nil end end
	local function offerFor(n, MR, id, value) for _, r in ipairs(n.items) do if r.itemID == id then return MR:Offer(r, false, "priced", value or 1) end end end   -- value: what it was ranked by (vendor price x count)

	-- ---- A1: the Loot Helper's Destroy
	for _, mode in ipairs({ "silent", "error" }) do
		local n, M, MR, said = boot()
		local o = offerFor(n, MR, 2589)
		_G.DeleteCursorItem = mode == "silent" and function() end or function() error("ADDON_ACTION_BLOCKED") end
		local ok, res = pcall(MR.Destroy, MR, o, true)
		check(ok and res == false, mode .. ": Destroy reports that nothing was destroyed (no error escapes)")
		check(M.cursorItem == nil and M.bags[0][3] and M.bags[0][3].id == 2589, mode .. ": the item is back in its slot, nothing on the cursor")
		check(said[#said] == BLOCKED, mode .. ": and it says so (" .. tostring(said[#said]) .. ")")
		-- the row's own click, asking off: the same
		for k in pairs(said) do said[k] = nil end
		local r2 = MR:TryDestroy(o, nil, "Linen Cloth", 1, "k", false)
		check(r2 == false and M.bags[0][3] ~= nil and said[#said] == BLOCKED, mode .. ": the row's click likewise")
		-- once the game allows it: destroyed, as before
		_G.DeleteCursorItem = works(M)
		check(MR:Destroy(o, true) == true and M.bags[0][3] == nil and M.cursorItem == nil, mode .. ": allowed again: destroyed (control)")
	end
	-- a confirmation's Yes, refused
	do
		local n, M, MR, said = boot({ makeRoomAsk = true })
		local o = offerFor(n, MR, 4865, 2)
		_G.DeleteCursorItem = function() end
		local yes
		local confirm_ = n.Confirm
		n.Confirm = function(btn, text, fn) yes = fn end
		MR:TryDestroy(o, nil, "Ruined Pelt", 2, "k", true)
		check(yes ~= nil and M.bags[0][4] ~= nil, "(setup) asking: a question first, nothing destroyed yet")
		yes()
		check(M.bags[0][4] ~= nil and M.cursorItem == nil and said[#said] == BLOCKED, "its Yes, refused by the game: the item is back, and it says so (" .. tostring(said[#said]) .. ")")
		n.Confirm = confirm_
	end

	-- ---- A1: Clear Soul Shards
	do
		local n, M, MR, said = boot()
		_G.DeleteCursorItem = function() end
		MR:ShowShards(); MR.shardQty = 2
		MR:DestroyNextShard(MR.frame.shard.go)
		check(MR.shardBatch == nil and M.cursorItem == nil and M.bags[0][1] ~= nil and M.bags[0][2] ~= nil, "a refused shard delete: both shards kept, the batch ended")
		check(said[#said] == SHARD_BLOCKED, "and it says so (" .. tostring(said[#said]) .. ")")
		_G.DeleteCursorItem = function() error("ADDON_ACTION_BLOCKED") end
		local ok = pcall(MR.DestroyNextShard, MR, MR.frame.shard.go)
		check(ok and MR.shardBatch == nil and M.bags[0][1] ~= nil, "an error: caught, the shard kept, the batch ended")
		_G.DeleteCursorItem = works(M)
		MR:DestroyNextShard(MR.frame.shard.go)
		check(M.bags[0][1] == nil and MR.shardBatch == 1, "allowed: the next click starts a new batch and destroys one (one left to go)")
		n:Scan(); M.runTimers()
		_G.DeleteCursorItem = function() end
		MR:DestroyNextShard(MR.frame.shard.go)
		check(M.bags[0][2] ~= nil and MR.shardBatch == nil, "refused mid-batch: the shard kept, the batch ended (not counted down)")
	end
	-- asked first: a Yes, then refused
	do
		local n, M, MR, said = boot({ makeRoomAsk = true })
		local yes
		local confirm_ = n.Confirm
		n.Confirm = function(btn, text, fn) yes = fn end
		_G.DeleteCursorItem = function() end
		MR:ShowShards(); MR.shardQty = 2
		MR:DestroyNextShard(MR.frame.shard.go)
		yes()
		check(MR.shardBatch == nil and M.bags[0][1] ~= nil and said[#said] == SHARD_BLOCKED, "asked first, Yes, refused: kept, the batch ended, it says so")
		n.Confirm = confirm_
	end

	-- ---- A2: blank item text, lists with holes
	do
		local n, M, MR = boot()
		local log
		local function quests(t, api)
			log = t
			_G.GetNumQuestLogEntries = function() return #log, #log end
			_G.GetQuestLogTitle = function(i) local q = log[i]; return q.title, 10, 0, false, false, false, 0, q.id end
			_G.GetNumQuestLeaderBoards = function(i) return #(log[i].objs or {}) end
			_G.GetQuestLogLeaderBoard = function(j, i) local q = log[i]; return q.objs[j], q.kinds and q.kinds[j] or "item", false end
			_G.C_QuestLog = api
		end
		local function needs(name) local list, complete = MR:QuestObjectives(); return MR:NeededForQuest(name, list), complete end
		for _, blank in ipairs({ "", "   " }) do
			MR.questMemo = {}
			quests({ { title = "Donation", id = 1001, objs = { "Linen Cloth: 5/20" } } })
			needs("Linen Cloth")
			log[1].objs = { blank }
			local kept, complete = needs("Linen Cloth")
			check(kept and complete, "an item objective with blank text (" .. #blank .. " characters): the remembered reading kept")
			MR.questMemo = {}
			quests({ { title = "New", id = 2002, objs = { blank } } })
			check(select(2, needs("Linen Cloth")) == false, "a new quest whose item objective is blank: incomplete")
		end
		MR.questMemo = {}
		quests({ { title = "Hunt", id = 3003, objs = { "   " }, kinds = { "monster" } } })
		check(select(2, needs("Linen Cloth")) == true, "a blank monster objective is still an answer")
		local A = { type = "item", text = "Linen Cloth: 5/20" }
		for label, list in pairs({ ["a hole at 1"] = { [2] = A }, ["a hole in the middle"] = { { type = "monster", text = "x" }, [3] = A },
				["a key that isn't a number"] = { A, extra = A }, ["a blank item"] = { { type = "item", text = " " } } }) do
			MR.questMemo = {}
			quests({ { title = "Donation", id = 1001, objs = { "Linen Cloth: 5/20" } } }, { GetQuestObjectives = function() return list end })
			_G.GetNumQuestLeaderBoards = nil
			check(select(2, needs("Linen Cloth")) == false, "C_QuestLog's list with " .. label .. ": a failed read (incomplete)")
		end
		MR.questMemo = {}
		quests({ { title = "Explore", id = 4004 } }, { GetQuestObjectives = function() return { { type = "monster", text = "" }, A } end })
		_G.GetNumQuestLeaderBoards = nil
		local kept, complete = needs("Linen Cloth")
		check(kept and complete, "a whole list (a blank monster objective, then the item): read, the item kept")
		-- ForgetQuest takes the event's ID as a number or text
		MR.questMemo = { [1001] = { "Linen Cloth: 5/20" } }
		MR:ForgetQuest("1001")
		check(MR.questMemo[1001] == nil, "a quest's ID as text still forgets it")
	end

	-- ---- F1: /bs questlog counts IDs by the reader's rule
	do
		local n, M, MR, said = boot()
		local ids = { 0, -1, "12", 1001 }
		_G.C_QuestLog = { GetNumQuestLogEntries = function() return #ids end, GetInfo = function(i) return { title = "Q" .. i, isHeader = false, questID = ids[i] } end }
		said = {}
		local print_ = n.Print
		n.Print = function(self, msg, ...) said[#said + 1] = select("#", ...) > 0 and msg:format(...) or tostring(msg) end
		SlashCmdList.BAGSMITH("questlog")
		n.Print = print_
		check(table.concat(said, "\n"):find("C_QuestLog lists 4 quests, 2 with an ID.", 1, true), "/bs questlog: IDs 0 and -1 aren't IDs; \"12\" and 1001 are")
		check(n.MakeRoom.QuestID(0) == nil and n.MakeRoom.QuestID(-1) == nil and n.MakeRoom.QuestID("12") == 12 and n.MakeRoom.QuestID("x") == nil, "the one rule, MR.QuestID")
	end
	check(not BLOCKED:find("\226\128\148") and not SHARD_BLOCKED:find("\226\128\148"), "the messages have no em dashes")
	_G.BagSmithDB = nil
end)()
