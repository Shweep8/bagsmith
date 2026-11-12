;(function()
	-- ======== 1.7.0-beta8: the answer to the 1.7.0-beta7 audit ========
	-- F1: quests with no quest ID that share a title kept only one reading; a failed read borrowed another's.
	-- A1: answers that came back empty without an error counted as readings. F2: the 1.7 card's quest promise.
	local deleted = 0
	local function boot()
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return "Warrior", "WARRIOR" end
		for b = 1, 5 do M.sizes[b] = 0 end
		M.sizes[0] = 3
		M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, stack = 20, class = 7, subclass = 5, price = 1 })
		M.put(0, 2, { id = 9720, name = "Gnoll Paw", q = 1, count = 2, stack = 20, class = 15, subclass = 0, price = 2 })
		M.put(0, 3, { id = 4865, name = "Ruined Pelt", q = 1, count = 1, stack = 20, class = 15, subclass = 0, price = 3 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { makeRoom = true, makeRoomValue = "vendor", makeRoomAsk = false } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		C_Container.PickupContainerItem = function(b, s) local i = M.bags[b][s]; M.cursorItem = i and i.id; M.cursorSlot = { b, s } end
		_G.ClearCursor = function() M.cursorItem = nil end
		_G.DeleteCursorItem = function() deleted = deleted + 1; local p = M.cursorSlot; M.bags[p[1]][p[2]] = nil; M.cursorItem = nil end
		local MR = n.MakeRoom
		MR.Waiting = function() return { { id = 9999, values = { vendor = 100 } } } end
		return n, M, MR
	end
	-- log: { { title, id, objs = { text... } | nil, header, collapsed, err, nilText, nilKind, nilCount } }
	local log
	local function quests(t, api)
		log = t
		_G.GetNumQuestLogEntries = function() return #log, #log end
		_G.GetQuestLogTitle = function(i) local q = log[i]; return q.title, 10, 0, q.header or false, q.collapsed or false, false, 0, q.id end
		_G.GetNumQuestLeaderBoards = function(i) local q = log[i]; if q.nilCount then return nil end; return #(q.objs or {}) end
		_G.GetQuestLogLeaderBoard = function(j, i)
			local q = log[i]
			if q.err then error("objective unavailable") end
			if q.nilText then return nil, "item", false end
			if q.nilKind then return q.objs[j], nil, false end
			return q.objs[j], q.kinds and q.kinds[j] or "item", false
		end
		_G.C_QuestLog = api
	end
	local function needs(MR, name) local list, complete = MR:QuestObjectives(); return MR:NeededForQuest(name, list), complete, list end
	local function offer(n, MR, id) for _, r in ipairs(n.items) do if r.itemID == id then return MR:Offer(r, false, "priced", r.count or 1) end end end

	-- ---- F1: same title, no quest ID
	do
		local n, M, MR = boot()
		MR.questMemo = {}
		quests({ { title = "Shared", objs = { "Linen Cloth: 5/20" } }, { title = "Shared", objs = { "Gnoll Paw: 2/8" } } })
		local cloth, complete = needs(MR, "Linen Cloth")
		check(cloth and needs(MR, "Gnoll Paw") and complete, "two quests, one title, no IDs: both protect their items, the reading complete")
		MR.questMemo = {}
		quests({ { title = "Shared", objs = { "Gnoll Paw: 2/8" } }, { title = "Shared", objs = { "Linen Cloth: 5/20" } } })
		check(needs(MR, "Linen Cloth") and needs(MR, "Gnoll Paw"), "the other order too")
		MR.questMemo = {}
		quests({ { title = "Shared", id = 1001, objs = { "Linen Cloth: 5/20" } }, { title = "Shared", id = 1002, objs = { "Gnoll Paw: 2/8" } } })
		check(needs(MR, "Linen Cloth") and needs(MR, "Gnoll Paw"), "control: distinct IDs keep both, as before")
		MR.questMemo = {}
		quests({ { title = "Shared", id = 0, objs = { "Linen Cloth: 5/20" } }, { title = "Shared", id = 0, objs = { "Gnoll Paw: 2/8" } } })
		check(needs(MR, "Linen Cloth") and needs(MR, "Gnoll Paw"), "a quest ID of 0 counts as no ID: both kept")
		-- the second can't be read: never borrows the first's reading
		MR.questMemo = {}
		quests({ { title = "Shared", objs = { "Gnoll Paw: 2/8" } }, { title = "Shared", objs = { "Linen Cloth: 5/20" } } })
		needs(MR, "Linen Cloth")
		log[2].err = true
		local _, complete2 = needs(MR, "Linen Cloth")
		check(complete2 == false, "the second same-titled quest can't be read (an error): the reading is incomplete")
		log[2].err = nil; log[2].nilText = true
		check(select(2, needs(MR, "Linen Cloth")) == false, "nor when it answers nothing")
		-- an offer made before the clash is refused at the click
		MR.questMemo = {}
		quests({})
		local o = offer(n, MR, 2589)
		check(o and MR:StillOk(o), "(setup) Linen Cloth offered with no quests")
		quests({ { title = "Shared", objs = { "Linen Cloth: 5/20" } }, { title = "Shared", objs = { "Gnoll Paw: 2/8" } } })
		check(select(2, MR:StillOk(o)) == "questneed", "two same-titled quests appear: the old offer is refused (questneed)")
		deleted = 0
		local res = MR:Destroy(o, true)
		check(not res and deleted == 0 and M.bags[0][1] ~= nil, "and a confirmed Destroy deletes nothing")
		-- one's heading collapsed: the other's reading doesn't replace it
		MR.questMemo = {}
		quests({ { title = "Zone A", header = true }, { title = "Shared", objs = { "Linen Cloth: 5/20" } },
			{ title = "Zone B", header = true }, { title = "Shared", objs = { "Gnoll Paw: 2/8" } } })
		needs(MR, "Linen Cloth")
		quests({ { title = "Zone A", header = true, collapsed = true }, { title = "Zone B", header = true }, { title = "Shared", objs = { "Gnoll Paw: 2/8" } } })
		local kept, complete3 = needs(MR, "Linen Cloth")
		check(kept and needs(MR, "Gnoll Paw") and complete3, "Zone A collapsed: its quest's Linen Cloth stays protected beside the visible one's")
		-- progress: the newer text replaces the older for the same objective, no duplicates
		quests({ { title = "Zone A", header = true, collapsed = true }, { title = "Zone B", header = true }, { title = "Shared", objs = { "Gnoll Paw: 5/8" } } })
		local _, _, list = needs(MR, "Gnoll Paw")
		local paws = 0
		for _, t in ipairs(list) do if t:find("Gnoll Paw", 1, true) then paws = paws + 1 end end
		check(paws == 1 and table.concat(list, "|"):find("Gnoll Paw: 5/8", 1, true), "progress replaces the old text (" .. table.concat(list, " | ") .. ")")
		-- the whole log in view and read, the collapsed quest gone: forgotten
		quests({ { title = "Zone B", header = true }, { title = "Shared", objs = { "Gnoll Paw: 5/8" } } })
		check(not needs(MR, "Linen Cloth") and needs(MR, "Gnoll Paw"), "a full read without it: its Linen Cloth is no longer kept")
		quests({})
		check(not needs(MR, "Gnoll Paw") and select(2, needs(MR, "Gnoll Paw")), "an empty log, fully read: nothing kept")
	end

	-- ---- A1: answers that come back empty
	do
		local n, M, MR = boot()
		local o
		local function known()
			MR.questMemo = {}
			quests({ { title = "Donation", id = 1001, objs = { "Linen Cloth: 5/20" } } })
			check(needs(MR, "Linen Cloth"), "(setup) the quest is read once")
			quests({})
			o = offer(n, MR, 2589)
			quests({ { title = "Donation", id = 1001, objs = { "Linen Cloth: 5/20" } } })
		end
		known(); _G.GetNumQuestLogEntries = function() return nil end
		local kept, complete = needs(MR, "Linen Cloth")
		check(complete == false and kept, "the log count missing: incomplete, the remembered need kept")
		check(select(2, MR:StillOk(o)) == "questlog", "and an old offer is refused (questlog)")
		known(); _G.GetNumQuestLogEntries = function() return "lots" end
		check(select(2, needs(MR, "Linen Cloth")) == false, "a count that isn't a number: incomplete")
		known(); log[1].nilCount = true
		kept, complete = needs(MR, "Linen Cloth")
		check(kept and complete, "the objective count missing, the quest remembered: its reading kept")
		check(select(2, MR:StillOk(o)) == "questneed", "and the offer is refused (questneed)")
		known(); log[1].nilText = true
		kept = needs(MR, "Linen Cloth")
		check(kept, "a declared objective with no text: the remembered reading kept")
		deleted = 0
		check(not MR:Destroy(o, true) and deleted == 0, "a confirmed Destroy deletes nothing")
		known(); log[1].nilKind = true
		check(needs(MR, "Linen Cloth"), "an objective with no kind: a failed read, the remembered reading kept")
		-- a new quest whose objectives come back empty: incomplete
		MR.questMemo = {}
		quests({ { title = "New", id = 2002, objs = { "Linen Cloth: 1/5" }, nilText = true } })
		check(select(2, needs(MR, "Linen Cloth")) == false, "a new quest read with no text, nothing remembered: incomplete")
		-- the fallback is tried when the log's lines come back empty
		local calls = 0
		MR.questMemo = {}
		quests({ { title = "Donation", id = 1001, objs = { "Linen Cloth: 5/20" }, nilText = true } },
			{ GetQuestObjectives = function(id) calls = calls + 1; return { { type = "item", text = "Linen Cloth: 5/20" } } end })
		kept, complete = needs(MR, "Linen Cloth")
		check(calls > 0 and kept and complete, "the log's line empty: C_QuestLog's objectives are read instead")
		-- C_QuestLog's answers are checked too
		for label, bad in pairs({ ["not a table"] = "x", ["an entry not a table"] = { 1 }, ["an entry with no type"] = { { text = "Linen Cloth: 5/20" } },
				["an item with no text"] = { { type = "item" } } }) do
			MR.questMemo = {}
			quests({ { title = "Donation", id = 1001, objs = { "Linen Cloth: 5/20" }, err = true } }, { GetQuestObjectives = function() return bad end })
			check(select(2, needs(MR, "Linen Cloth")) == false, "C_QuestLog answers " .. label .. ": a failed read (incomplete)")
		end
		-- real answers of nothing stay answers
		MR.questMemo = {}
		quests({ { title = "Explore", id = 3003, objs = {} } })
		kept, complete = needs(MR, "Linen Cloth")
		check(not kept and complete, "a quest with no objectives (a real 0): complete, nothing kept")
		MR.questMemo = {}
		quests({ { title = "Explore", id = 3003, objs = {}, err = true } }, { GetQuestObjectives = function() return {} end })
		check(select(2, needs(MR, "Linen Cloth")) == true, "C_QuestLog's empty list: an answer (complete)")
		MR.questMemo = {}
		quests({ { title = "Hunt", id = 4004, objs = { "", "Linen Cloth: 1/5" }, kinds = { "monster", "item" } } })
		kept, complete = needs(MR, "Linen Cloth")
		check(kept and complete, "an empty-text monster objective beside an item one: read, the item kept")
		-- a client without the objective functions has nothing to read (complete, no needs), as before
		MR.questMemo = {}
		quests({ { title = "Donation", id = 1001, objs = { "Linen Cloth: 5/20" } } })
		_G.GetQuestLogLeaderBoard = nil; _G.GetNumQuestLeaderBoards = nil
		kept, complete = needs(MR, "Linen Cloth")
		check(not kept and complete, "no objective functions at all: complete, nothing kept (unchanged)")
	end

	-- ---- /bs questlog: what the client reports
	do
		local n, M, MR = boot()
		MR.questMemo = {}
		quests({ { title = "Zone", header = true }, { title = "Shared", objs = { "Linen Cloth: 5/20" } }, { title = "Donation", id = 1001, objs = { "Gnoll Paw: 2/8" } } })
		local said = {}
		local print_ = n.Print
		n.Print = function(self, msg, ...) said[#said + 1] = select("#", ...) > 0 and msg:format(...) or tostring(msg); return print_(self, msg, ...) end
		SlashCmdList.BAGSMITH("questlog")
		n.Print = print_
		local text = table.concat(said, "\n")
		check(text:find("Shared (no quest ID): read from the quest log; Linen Cloth: 5/20", 1, true), "/bs questlog: a quest with no ID, how it was read, its item")
		check(text:find("Donation (quest 1001): read from the quest log; Gnoll Paw: 2/8", 1, true), "a quest with its ID")
		check(text:find("Reading complete. Items kept for quests: 2.", 1, true) and text:find("no heading collapsed", 1, true), "whether the reading was complete")
		log[3].err = true
		said = {}
		n.Print = function(self, msg, ...) said[#said + 1] = select("#", ...) > 0 and msg:format(...) or tostring(msg); return print_(self, msg, ...) end
		MR.questMemo = {}
		SlashCmdList.BAGSMITH("questlog")
		n.Print = print_
		text = table.concat(said, "\n")
		check(text:find("Donation (quest 1001): couldn't be read", 1, true) and text:find("Reading incomplete", 1, true), "a quest it couldn't read, and the incomplete reading")
		check(not text:find("\226\128\148"), "no em dashes")
	end

	-- ---- F2: the 1.7 card says what it can't see
	do
		local n = boot()
		local first = n.WhatsNew.ENTRIES[1].items[1]
		check(first:find("never offers what you still need for a quest, unless its heading is collapsed in your quest log.", 1, true), "the 1.7 card's first bullet names the collapsed-heading limit")
		check(n.MakeRoom:HowItDecides()[3] == "Anything you still need for a quest is never on the list, unless its heading is collapsed in your quest log.", "as the (i) does (unchanged)")
	end
	_G.BagSmithDB = nil
end)()
