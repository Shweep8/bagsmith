;(function()
	-- ======== 1.7.0-beta3: the Loot Helper (Shweep) ========
	-- The "let go" list scrolls and lists every candidate (no stop at six; Show More removed); it's ranked by how much
	-- you'd miss an item, not by price alone: a material your professions use counts three times over, a spare stack at
	-- half, junk ranks by value with everything else, and anything a quest still asks for is never offered. The weights
	-- only order the list; what may be offered, and the check at the click, go by plain value as before.
	local loot = {}
	local lootPrice = 30
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("|Hitem:" .. loot[i].id .. ":0|h[" .. loot[i].name .. "]|h") end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, l.qty or 1, nil, l.q or 1 end end
	_G.LootSlot = function() end
	local deleted = 0
	_G.DeleteCursorItem = function() deleted = deleted + 1 end
	local quests = {}   -- { title, header, questID, objectives = { { text, kind } } }
	local function questApi(mode)
		_G.GetNumQuestLogEntries = function() return #quests end
		_G.GetQuestLogTitle = function(i) local q = quests[i]; if not q then return nil end; if q.throws then error("quest read failed") end; return q.title, 10, 0, q.header, false, false, 0, q.questID end
		if mode == "objectives" then
			_G.GetNumQuestLeaderBoards, _G.GetQuestLogLeaderBoard = nil, nil
			_G.C_QuestLog = { GetQuestObjectives = function(id) for _, q in ipairs(quests) do if q.questID == id then local out = {}; for _, o in ipairs(q.objectives or {}) do out[#out + 1] = { text = o[1], type = o[2] } end return out end end return {} end }
		else
			_G.C_QuestLog = nil
			_G.GetNumQuestLeaderBoards = function(i) return #((quests[i] or {}).objectives or {}) end
			_G.GetQuestLogLeaderBoard = function(j, i) local o = ((quests[i] or {}).objectives or {})[j]; if o then return o[1], o[2], false end end
		end
	end
	local function boot(stock, skin, extra)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return "Warrior", "WARRIOR" end
		for b = 1, 5 do M.sizes[b] = 0 end
		M.sizes[0] = 12
		local info = stock(M)
		_G.BagSmithCharDB = (extra and extra.cdb) or { version = 1, firstSeen = {} }
		local pr = { skin = skin or "modern", makeRoom = true, makeRoomValue = "vendor", makeRoomAsk = false }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = pr } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id)
			local num = tonumber(tostring(id):match("item:(%d+)")) or id
			if num == 9740 then return "Rough Gem", nil, 1, nil, nil, nil, nil, 1, nil, nil, lootPrice end
			local e = info and info[num]
			if e then return e[1], nil, e[2], nil, nil, nil, nil, e[3], nil, nil, e[4] end
			return realInfo(id)
		end
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id end
		_G.ClearCursor = function() M.cursorItem = nil end
		return n, M
	end
	local function offered(f)
		local t = {}
		for _, r in ipairs(f.destroyRows) do if r:IsShown() then t[#t + 1] = { y = -(r.points[1][5] or 0), name = r.name.text } end end
		table.sort(t, function(a, b) return a.y < b.y end)
		local names = {}
		for _, e in ipairs(t) do names[#names + 1] = e.name end
		return table.concat(names, ",")
	end
	local function rowNamed(f, name) for _, r in ipairs(f.destroyRows) do if r:IsShown() and r.name.text == name then return r end end end
	local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
	local function open(M) M.fire("LOOT_CLOSED"); M.runTimers(); M.fire("LOOT_OPENED"); M.runTimers() end
	questApi("leaderboard")

	-- ---- the scrolling list, both skins
	local function many(M)
		M.sizes[0] = 10   -- full: the loot won't fit
		local info = {}
		for s = 1, 10 do
			M.put(0, s, { id = 9800 + s, name = "Trinket " .. string.char(64 + s), q = 1, class = 15, subclass = 0, price = s })
			info[9800 + s] = { "Trinket " .. string.char(64 + s), 1, 1, s }
		end
		return info
	end
	for _, skin in ipairs({ "modern", "classic" }) do
		local S = skin .. ": "
		lootPrice = 30
		local n, M = boot(many, skin)
		loot = { { id = 9740, name = "Rough Gem", q = 1 } }
		M.fire("LOOT_OPENED"); M.runTimers()
		local MR, f = n.MakeRoom, n.MakeRoom.frame
		local ROW = f.destroyRows[1]:GetHeight()
		check(f.more == nil and MR.ShowingMore == nil and MR.ToggleMore == nil, S .. "Show More is gone")
		check(offered(f) == "Trinket A,Trinket B,Trinket C,Trinket D,Trinket E,Trinket F,Trinket G,Trinket H,Trinket I,Trinket J", S .. "every candidate is listed, least missed first (" .. offered(f) .. ")")
		check(f.letGo:IsShown() and math.abs(f.letGo:GetHeight() - 6 * ROW) < 0.5 and math.abs(f.letGo.child:GetHeight() - 10 * ROW) < 0.5, S .. "six rows show; the other four scroll")
		check(f.letGo.ScrollBar:IsShown() and math.abs(f.destroyRows[1]:GetWidth() - (f:GetWidth() - 12 - 26)) < 0.5, S .. "with its scrollbar, and rows narrowed to make room for it")
		local r1 = f.destroyRows[1]
		check(r1.name.width == r1:GetWidth() - 62 - r1.btnUsed - 8, S .. "names still get the room left of the cost column")   -- (1.7.0-beta10, by design: the cost column, not Protect)
		local heads = {}
		for _, h in ipairs(f.heads) do if h:IsShown() then heads[#heads + 1] = h.text end end
		-- (1.7.0-beta10, by design: Shweep's layout) one list, headed by the loot it's making room for
		check(table.concat(heads, "|"):find("To make room for Rough Gem", 1, true), S .. "the heading names the loot it's making room for (" .. table.concat(heads, "|") .. ")")
		-- the action stays below the list
		local function topOf(fr) local p = fr.points[1]; return -(p[5] or p[3] or 0) end
		check(topOf(f.act) >= topOf(f.letGo) + 6 * ROW, S .. "the Destroy button sits below the list, always in view")
		-- the scroll position is kept as it repaints, and clamped when the list gets shorter
		f.letGo:SetVerticalScroll(3 * ROW); MR:Refresh()
		check(math.abs(f.letGo:GetVerticalScroll() - 3 * ROW) < 0.5, S .. "a repaint keeps the scroll position")
		for _, id in ipairs({ 9808, 9809, 9810 }) do MR:Protect(id) end; M.runTimers()
		check(math.abs(f.letGo:GetVerticalScroll() - 1 * ROW) < 0.5, S .. "a shorter list clamps it (seven rows: one row of scroll left) (" .. f.letGo:GetVerticalScroll() .. ")")
		MR:ClearProtected(); M.runTimers()
		-- a row below the first six can be chosen and acted on
		f.letGo:SetVerticalScroll(4 * ROW); MR:Refresh()
		local j = rowNamed(f, "Trinket J")
		j:GetScript("OnClick")(j)
		check(f.act.label.text == "Destroy Trinket J", S .. "a row further down can be chosen")
		local before = deleted
		f.act:GetScript("OnClick")(f.act)
		check(deleted == before + 1, S .. "and destroyed (it doesn't ask: a common item, Ask Before Destroying off)")
		-- six or fewer: no scrollbar, rows full width
		for _, id in ipairs({ 9801, 9802, 9803, 9804 }) do MR:Protect(id) end; M.runTimers()
		local k = 0; for _, r in ipairs(f.destroyRows) do if r:IsShown() then k = k + 1 end end
		check(k == 6 and not f.letGo.ScrollBar:IsShown() and math.abs(f.destroyRows[1]:GetWidth() - (f:GetWidth() - 12)) < 0.5 and math.abs(f.letGo:GetHeight() - k * ROW) < 0.5,
			S .. "six or fewer: no scrollbar, rows at full width, the list just as tall as its rows (" .. k .. ")")
		check(f.letGo:GetVerticalScroll() == 0, S .. "and nothing left to scroll")
		-- the footer and its (i)
		-- (1.7.0-beta4, by design: Shweep's wording)
		-- (1.7.0-beta10, by design: Shweep's layout) the (i) sits by the list's heading; the footer says what happens next
		check(f.foot.text == "Then Rough Gem goes in your bags." and f.footInfo:IsShown() and f.footInfo.title == "How it decides"
			and (f.footInfo.lines[2] or ""):find("Junk always shows up", 1, true) and f.footInfo.lines[4] == "Prices come from the vendor.", S .. "the footer says what happens next; the (i) says how it decides")
		f:Hide()
	end

	-- ---- the ranking: junk by value, spare stacks at half, profession materials at three times
	local function mixed(M)
		M.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 25 })                                -- junk, 25c
		M.put(0, 2, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 12, equip = "INVTYPE_WAIST" })          -- 12c
		M.put(0, 3, { id = 2589, name = "Linen Cloth", q = 1, count = 5, stack = 20, class = 7, subclass = 5, price = 1 })            -- 5c (a material?)
		M.put(0, 4, { id = 2592, name = "Wool Cloth", q = 1, count = 20, stack = 20, class = 7, subclass = 5, price = 1 })            -- 20c, the main stack
		M.put(0, 5, { id = 2592, name = "Wool Cloth", q = 1, count = 18, stack = 20, class = 7, subclass = 5, price = 1 })            -- 18c, spare: 9
		M.put(0, 6, { id = 9720, name = "Gnoll Paw", q = 1, count = 4, stack = 20, class = 15, subclass = 0, price = 2 })             -- 8c
		M.put(0, 7, { id = 9750, name = "Strange Dust", q = 1, count = 2, stack = 20, class = 7, subclass = 12, price = 7 })          -- 14c
		for s = 8, 12 do M.put(0, s, { id = 9760 + s, name = "Keepsake " .. s, q = 1, class = 15, subclass = 0, price = 99 }) end   -- worth more than the loot
		return { [9701] = { "Broken Fang", 0, 1, 25 }, [9702] = { "Linen Belt", 1, 1, 12 }, [2589] = { "Linen Cloth", 1, 20, 1 }, [2592] = { "Wool Cloth", 1, 20, 1 },
			[9720] = { "Gnoll Paw", 1, 20, 2 }, [9750] = { "Strange Dust", 1, 20, 7 } }
	end
	for _, skin in ipairs({ "modern", "classic" }) do
		local S = skin .. ": "
		lootPrice = 30
		quests = {}
		local n, M = boot(mixed, skin)
		loot = { { id = 9740, name = "Rough Gem", q = 1 } }
		M.fire("LOOT_OPENED"); M.runTimers()
		local MR, f = n.MakeRoom, n.MakeRoom.frame
		-- before any profession window: by value, a spare stack at half, junk with everything else
		check(offered(f) == "Linen Cloth,Gnoll Paw,Wool Cloth,Linen Belt,Strange Dust,Wool Cloth,Broken Fang",
			S .. "least missed first: Linen 5, Paw 8, spare Wool 18 at half (9), Belt 12, Dust 14, Wool 20, then the 25c junk (" .. offered(f) .. ")")
		check(not offered(f):find("Keepsake", 1, true), S .. "items worth more than the loot still aren't offered")
		local fang = rowNamed(f, "Broken Fang")
		check(fang and fang.cost.text:find("^Junk"), S .. "junk worth more than the loot is still offered, marked Junk, but no longer first")   -- (1.7.0-beta10, by design: in the cost column)
		-- the profession windows teach the materials
		_G.GetTradeSkillLine = function() return "Tailoring", 50, 75 end
		_G.GetNumTradeSkills = function() return 2 end
		_G.GetTradeSkillInfo = function(i) if i == 1 then return "Cloth", "header" end return "Bolt of Linen Cloth", "easy" end
		_G.GetTradeSkillNumReagents = function(i) return i == 2 and 1 or 0 end
		_G.GetTradeSkillReagentItemLink = function(i, j) return "|Hitem:2589:0|h[Linen Cloth]|h" end
		M.fire("TRADE_SKILL_SHOW"); M.runTimers()
		check(n.cdb.professionMats and n.cdb.professionMats.Tailoring and n.cdb.professionMats.Tailoring[2589] == true, S .. "opening Tailoring learns its recipes' materials")
		_G.GetCraftDisplaySkillLine = function() return "Enchanting" end
		_G.GetNumCrafts = function() return 1 end
		_G.GetCraftInfo = function(i) return "Enchant Bracer - Minor Health", nil, "optimal" end
		_G.GetCraftNumReagents = function() return 1 end
		_G.GetCraftReagentItemLink = function() return "|Hitem:9750:0|h[Strange Dust]|h" end
		M.fire("CRAFT_SHOW"); M.runTimers()
		check(n.cdb.professionMats.Enchanting and n.cdb.professionMats.Enchanting[9750] == true, S .. "and Enchanting's craft window too")
		-- a narrowed list only adds
		_G.GetNumTradeSkills = function() return 0 end
		M.fire("TRADE_SKILL_UPDATE"); M.runTimers()
		check(n.cdb.professionMats.Tailoring[2589] == true, S .. "a recipe list narrowed by a filter forgets nothing")
		MR:Refresh()
		check(offered(f) == "Gnoll Paw,Wool Cloth,Linen Belt,Linen Cloth,Wool Cloth,Broken Fang,Strange Dust",
			S .. "materials count three times over: Linen 15, Dust 42 (" .. offered(f) .. ")")
		-- the weights don't let anything through the value rule: a spare stack worth more than the loot stays out
		lootPrice = 15; open(M); f = MR.frame
		check(not offered(f):find("Wool Cloth", 1, true) and offered(f):find("Broken Fang", 1, true), S .. "a spare stack worth more than the loot isn't offered, at half or not (" .. offered(f) .. ")")
		lootPrice = 30; open(M); f = MR.frame
		-- quests: what an objective asks for is never offered, finished or not
		quests = { { title = "Cloth", header = true }, { title = "Paws for Thought", questID = 501, objectives = { { "Gnoll Paw: 3/10", "item" }, { "Gnoll Mystic slain: 0/5", "monster" } } } }
		local pawOffer = MR:Offer(recOf(n, 9720), false, "priced", 8)
		MR:Refresh()
		check(not offered(f):find("Gnoll Paw", 1, true), S .. "an item a quest asks for isn't offered (" .. offered(f) .. ")")
		check(f.held:IsShown() and (table.concat(f.heldInfo.lines or {}, "\n")):find("Needed for a quest (1):", 1, true), S .. "it's counted as held back: Needed for a quest")
		local ok, why = MR:StillOk(pawOffer)
		check(ok == false and why == "questneed", S .. "an offer made before the quest is refused at the click (" .. tostring(why) .. ")")
		quests[2].objectives[1][1] = "Gnoll Paw: 10/10"
		MR:Refresh()
		check(not offered(f):find("Gnoll Paw", 1, true), S .. "still kept once the objective is complete (it's handed in)")
		quests = {}; MR:Refresh()
		check(offered(f):find("Gnoll Paw", 1, true), S .. "the quest gone, it's offered again")
		-- names: exactly, by the objective's name; some other wording counts if it contains the name
		check(not MR:NeededForQuest("Linen Cloth", { "Bolt of Linen Cloth: 0/5" }), S .. "\"Bolt of Linen Cloth: 0/5\" doesn't keep Linen Cloth")
		check(MR:NeededForQuest("Linen Cloth", { "0/5 Linen Cloth (collect)" }), S .. "an objective worded another way keeps it if it names it")
		-- the other reader, and a read that errors
		questApi("objectives")
		quests = { { title = "Paws for Thought", questID = 501, objectives = { { "Gnoll Paw: 2/5", "item" } } } }
		MR:Refresh()
		check(not offered(f):find("Gnoll Paw", 1, true), S .. "C_QuestLog's objectives are read where the quest log's lines aren't")
		quests = { { title = "Broken", questID = 9, throws = true } }
		local okR = pcall(MR.Refresh, MR)
		-- (1.7.0-beta5, by design: the beta4 audit's F2) a quest read that errors fails closed: nothing is offered
		check(okR and offered(f) == "", S .. "a quest read that errors holds everything back, nothing breaks")
		questApi("leaderboard"); quests = {}
		f:Hide()
		-- kept per character, across a load; malformed parts dropped
		local saved = n.cdb.professionMats
		local copy = {}
		for prof, set in pairs(saved) do copy[prof] = {}; for id in pairs(set) do copy[prof][id] = true end end
		copy.Bad = "x"; copy.Tailoring.foo = true; copy[5] = { [1] = true }
		local n2 = boot(mixed, skin, { cdb = { version = 1, firstSeen = {}, professionMats = copy } })
		local p = n2.cdb.professionMats
		check(p.Tailoring[2589] == true and p.Enchanting[9750] == true and p.Bad == nil and p.Tailoring.foo == nil and p[5] == nil, S .. "learned materials are kept across a load; malformed parts are dropped")
		for _, k in ipairs({ "GetTradeSkillLine", "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillNumReagents", "GetTradeSkillReagentItemLink",
			"GetCraftDisplaySkillLine", "GetNumCrafts", "GetCraftInfo", "GetCraftNumReagents", "GetCraftReagentItemLink" }) do _G[k] = nil end
	end
	_G.GetNumQuestLogEntries, _G.GetQuestLogTitle, _G.GetNumQuestLeaderBoards, _G.GetQuestLogLeaderBoard, _G.C_QuestLog = nil, nil, nil, nil, nil
end)()
