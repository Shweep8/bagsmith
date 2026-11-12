;(function()
	-- ======== 1.7.0-beta12: full stacks into the mail and the trade (Shweep) ========
	-- While the mailbox's send form or a trade window is open, a merged row stands on its fullest stack, so the game's own
	-- attach is a full one; then, before the rest follow, BagSmith tops up the partial stacks still in the bags (the
	-- fullest partial takes what fits from the smallest, one move at a time, each checked), and sends full stacks first,
	-- the leftover last. Shweep's 70 Linen Cloth (20, 20, 19, 11) went as 20, 20, 19, 11; now as 20, 20, 20, 10.
	package.loaded.mock = nil
	local M = require("mock")
	local ID = 2589
	local function linen(slot, count) M.put(0, slot, { id = ID, name = "Linen Cloth", q = 1, count = count, class = 7, subclass = 5, price = 1 }) end
	local function stock(counts) for s = 1, 8 do M.bags[0][s] = nil end; for s, c in ipairs(counts) do linen(s, c) end end
	stock({ 11, 20, 19, 20 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	_G.MailFrame = CreateFrame("Frame", "MailFrame", UIParent); _G.SendMailFrame = CreateFrame("Frame", "SendMailFrame", MailFrame); MailFrame:Hide(); SendMailFrame:Hide()
	_G.TradeFrame = CreateFrame("Frame", "TradeFrame", UIParent); TradeFrame:Hide()
	_G.ATTACHMENTS_MAX_SEND = 12; _G.MAX_TRADE_ITEMS = 7
	local mail, trade = {}, {}
	_G.GetSendMailItem = function(i) local a = mail[i]; if a then return a.name, a.id, 1, a.count end end
	_G.GetSendMailItemLink = function(i) local a = mail[i]; if a and a.id then return "|Hitem:" .. a.id .. ":0|h[" .. a.name .. "]|h" end end
	_G.GetTradePlayerItemInfo = function(i) local a = trade[i]; if a then return a.name end end
	_G.GetTradePlayerItemLink = function(i) local a = trade[i]; if a then return "|Hitem:" .. a.id .. ":0|h[" .. a.name .. "]|h" end end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local D = n.Drop
	n:Set("mergeStacks", true); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local function row()
		n:Scan(); M.runTimers(); n.Window.main:Refresh(true, "test"); M.runTimers()
		for _, b in ipairs(n.Buttons.all) do if b:IsShown() and b.rec and b.rec.itemID == ID and b.rec.merged then return b end end
	end
	local function at(b) return b and (b.rec.bag .. ":" .. b.rec.slot) or "none" end
	local function said() return M.log[#M.log] or "" end
	local function clearLog() for i = #M.log, 1, -1 do M.log[i] = nil end end
	local function run() for _ = 1, 60 do M.runTimers() end end

	-- ---- the merged row stands on its fullest stack while the send form or a trade is open, elsewhere on the first
	local b = row()
	check(b and b.rec.stacks == 4 and at(b) == "0:1" and b.rec.count == 70, "(setup) nowhere special: the row stands on its first stack, 70 in four (" .. at(b) .. ")")
	MailFrame:Show(); SendMailFrame:Show(); M.fire("MAIL_SHOW"); M.runTimers(); M.runTimers()
	b = row()
	check(at(b) == "0:2" and b.rec.count == 70 and #b.rec.members == 4, "at the send form: on the fullest stack (the first of the 20s), still 70 in four (" .. at(b) .. ")")
	M.bags[0][2].locked = true
	b = row()
	check(at(b) == "0:4", "a locked stack (on the mail already) is passed over for the next fullest (" .. at(b) .. ")")
	M.bags[0][2].locked = nil
	-- the inbox tab: the send form hides, back to the first stack
	SendMailFrame:Hide(); if SendMailFrame.scripts.OnHide then SendMailFrame.scripts.OnHide(SendMailFrame) end; M.runTimers(); M.runTimers()
	check((D.StandsOnFullest and D:StandsOnFullest()) == false and D.fullestOn == false, "the inbox tab: not the send form, not the fullest")
	b = row()
	check(at(b) == "0:1", "the inbox: back on the first stack (" .. at(b) .. ")")
	MailFrame:Hide(); M.fire("MAIL_CLOSED"); M.runTimers()
	TradeFrame:Show(); M.fire("TRADE_SHOW"); M.runTimers(); M.runTimers()
	b = row()
	check((D.StandsOnFullest and D:StandsOnFullest()) and at(b) == "0:2", "in a trade: the fullest stack (" .. at(b) .. ")")
	TradeFrame:Hide(); M.fire("TRADE_CLOSED"); M.runTimers(); M.runTimers()
	n.atBank = true
	b = row()
	check(not (D.StandsOnFullest and D:StandsOnFullest()) and at(b) == "0:1", "at the bank: the first stack, as before (" .. at(b) .. ")")
	n.atBank = false

	-- ---- the game, modeled: a pick-up or a split puts the item on the cursor (its slot locked), a place merges it into
	-- a stack of the same item; the game confirms a move a moment later (both slots unlock)
	local cursor
	local moves = {}
	local function unlockSoon(...) local slots = { ... }; C_Timer.After(0, function() for _, s in ipairs(slots) do local it = M.bags[0][s]; if it then it.locked = nil end end end) end
	local refuseSplit, refusePlace, revert = false, false, false
	C_Container.SplitContainerItem = function(bag, slot, amount)
		if refuseSplit then return end
		local it = M.bags[bag][slot]
		cursor = { from = slot, id = it.id, n = amount }; M.cursorItem = it.id; it.locked = true
	end
	C_Container.PickupContainerItem = function(bag, slot)
		local it = M.bags[bag][slot]
		if not cursor then cursor = { from = slot, id = it.id, n = it.count }; M.cursorItem = it.id; it.locked = true; return end
		if refusePlace then return end   -- the game won't take it: it stays on the cursor
		local src = M.bags[0][cursor.from]
		moves[#moves + 1] = cursor.n .. ":" .. cursor.from .. ">" .. slot
		if not revert then
			it.count = it.count + cursor.n
			src.count = src.count - cursor.n
			if src.count <= 0 then M.bags[0][cursor.from] = nil end
		end
		it.locked = true
		cursor = nil; M.cursorItem = nil
		unlockSoon(slot, moves[#moves]:match(":(%d+)>") + 0)
	end
	_G.ClearCursor = function() if cursor then local src = M.bags[0][cursor.from]; if src then src.locked = nil end end; cursor = nil; M.cursorItem = nil end
	local function attach(slot) local it = M.bags[0][slot]; mail[#mail + 1] = { name = it.name, id = it.id, count = it.count }; it.locked = true end
	local used = {}
	local realUse = C_Container.UseContainerItem
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = slot; attach(slot) end
	local function rightClick(bt)
		bt.scripts.OnMouseDown(bt, "RightButton")
		attach(bt.rec.slot)
		bt.scripts.OnClick(bt, "RightButton")
	end
	local function counts(list) local t = {}; for _, a in ipairs(list) do if a.id == ID then t[#t + 1] = a.count end end; table.sort(t, function(x, y) return x > y end); return table.concat(t, ",") end
	local function fresh(c) M.fire("MAIL_SEND_SUCCESS"); stock(c); mail = {}; used = {}; moves = {}; cursor = nil; M.cursorItem = nil; clearLog() end

	-- ---- Shweep's 70: 20, 20, 19, 11 go as 20, 20, 20, 10
	MailFrame:Show(); SendMailFrame:Show(); if SendMailFrame.scripts.OnShow then SendMailFrame.scripts.OnShow(SendMailFrame) end; M.fire("MAIL_SHOW"); M.runTimers(); M.runTimers()
	fresh({ 20, 20, 19, 11 })
	b = row()
	check(at(b) == "0:1", "(setup) the row stands on a full stack")
	rightClick(b)
	run()
	check(counts(mail) == "20,20,20,10" and #mail == 4, "the mail gets 20, 20, 20 and 10 (" .. counts(mail) .. ")")
	check(#moves == 1 and moves[1] == "1:4>3", "one move: 1 from the 11 tops up the 19 (" .. table.concat(moves, " ") .. ")")
	check(used[1] == 2 and used[2] == 3 and used[3] == 4, "full stacks go first, the leftover last (" .. table.concat(used, ",") .. ")")
	check(said() == "" and D.active == nil and cursor == nil, "nothing to say, the job done, nothing on the cursor (" .. said() .. ")")
	-- ---- a slot saved: 20, 11, 11, 11 (53) go as 20, 20, 13
	fresh({ 20, 11, 11, 11 })
	rightClick(row())
	run()
	check(counts(mail) == "20,20,13" and #mail == 3, "three partial stacks tidy into two: 20, 20, 13, one attachment fewer (" .. counts(mail) .. ")")
	check(#moves == 2 and moves[1] == "9:4>2" and moves[2] == "2:4>3", "the fullest partial takes from the smallest, until one partial is left (" .. table.concat(moves, " ") .. ")")
	-- ---- the mail's room is counted after the tidy
	fresh({ 20, 11, 11, 11 })
	for i = 1, 10 do mail[i] = { name = "Rough Stone", id = 2835, count = 1 } end   -- ten of twelve used
	rightClick(row())
	run()
	check(counts(mail) == "20,20" and said():find("Moved 2 stacks of Linen Cloth; 1 more would not fit in the mail.", 1, true),
		"with one slot left after the clicked stack, the tidied 20 goes and only the 13 stays (" .. counts(mail) .. "; " .. said() .. ")")
	-- ---- the trade too
	M.fire("MAIL_CLOSED"); MailFrame:Hide(); SendMailFrame:Hide(); M.runTimers()
	TradeFrame:Show(); M.fire("TRADE_SHOW"); M.runTimers(); M.runTimers()
	stock({ 15, 20, 8 }); trade = {}; used = {}; moves = {}; clearLog()
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = slot; local it = M.bags[0][slot]; trade[#trade + 1] = { name = it.name, id = it.id, count = it.count }; it.locked = true end
	b = row()
	check(at(b) == "0:2", "(setup) in the trade the row stands on the 20")
	b.scripts.OnMouseDown(b, "RightButton")
	trade[#trade + 1] = { name = "Linen Cloth", id = ID, count = 20 }; M.bags[0][2].locked = true
	b.scripts.OnClick(b, "RightButton")
	run()
	check(counts(trade) == "20,20,3" and #moves == 1 and moves[1] == "5:3>1", "in a trade 20, 15, 8 go as 20, 20, 3 (" .. counts(trade) .. "; " .. table.concat(moves, " ") .. ")")
	TradeFrame:Hide(); M.fire("TRADE_CLOSED"); M.runTimers()
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = slot; attach(slot) end

	-- ---- a move the game refuses ends the tidy, said; the stacks go as they are
	MailFrame:Show(); SendMailFrame:Show(); M.fire("MAIL_SHOW"); M.runTimers(); M.runTimers()
	fresh({ 20, 11, 11, 11 })
	refuseSplit = true
	rightClick(row())
	run()
	refuseSplit = false
	local lines = table.concat(M.log, "\n")
	check(lines:find("Couldn't top up the stacks of Linen Cloth; the rest go as they are.", 1, true) and counts(mail) == "20,11,11,11" and cursor == nil,
		"a split the game refuses: said once, the stacks attach as they are (" .. counts(mail) .. ")")
	fresh({ 20, 11, 11, 11 })
	refusePlace = true
	rightClick(row())
	run()
	refusePlace = false
	check(table.concat(M.log, "\n"):find("Couldn't top up", 1, true) and cursor == nil and M.bags[0][4] and M.bags[0][4].count == 11 and counts(mail) == "20,11,11,11",
		"a place the game refuses: the item goes back from the cursor, said, and the stacks attach as they are")
	fresh({ 20, 11, 11, 11 })
	revert = true
	rightClick(row())
	run()
	revert = false
	check(table.concat(M.log, "\n"):find("Couldn't top up", 1, true) and #moves == 1 and counts(mail) == "20,11,11,11",
		"a move that doesn't come out as expected ends the tidy after it (" .. #moves .. " move)")
	-- ---- combat mid-tidy: it stops, and nothing more follows
	fresh({ 20, 11, 11, 11 })
	local realCombat = InCombatLockdown
	local polls = 0
	local realPick = C_Container.PickupContainerItem
	C_Container.PickupContainerItem = function(...) realPick(...); if not cursor then _G.InCombatLockdown = function() return true end end end
	rightClick(row())
	run()
	_G.InCombatLockdown = realCombat
	C_Container.PickupContainerItem = realPick
	check(#moves == 1 and #used == 0 and said():find("combat started", 1, true) and cursor == nil, "combat during the tidy: no more moves, nothing more attached, said (" .. said() .. ")")
	-- ---- the mail closing mid-tidy: it stops
	fresh({ 20, 11, 11, 11 })
	C_Container.PickupContainerItem = function(...) realPick(...); if not cursor then MailFrame:Hide(); SendMailFrame:Hide() end end
	rightClick(row())
	run()
	C_Container.PickupContainerItem = realPick
	check(#moves == 1 and #used == 0 and said():find("the mail closed", 1, true), "the mail closing during the tidy: it stops, said (" .. said() .. ")")
	MailFrame:Show(); SendMailFrame:Show(); M.runTimers()
	-- ---- nothing to tidy: full stacks and one partial go as before, without a move
	fresh({ 20, 20, 20, 3 })
	rightClick(row())
	run()
	check(#moves == 0 and counts(mail) == "20,20,20,3" and said() == "", "full stacks and one partial: no moves, all attached")
	MailFrame:Hide(); SendMailFrame:Hide(); M.fire("MAIL_CLOSED"); M.runTimers()

	-- ---- the bank is unchanged: no tidy, the stacks move as they are
	stock({ 20, 11, 11 }); used = {}; moves = {}; clearLog()
	n.atBank = true
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = slot; M.bags[bag][slot] = nil end
	M.bags[0][1] = nil
	D:MoveRest({ itemID = ID, members = { { bag = 0, slot = 1 }, { bag = 0, slot = 2 }, { bag = 0, slot = 3 } }, name = "Linen Cloth", first = { bag = 0, slot = 1 } })
	run()
	check(#moves == 0 and #used == 2, "at the bank no stacks are tidied; the rest follow as before")
	n.atBank = false
	C_Container.UseContainerItem = realUse
	_G.BagSmithDB = nil
end)()

;(function()
	-- ======== 1.7.0-beta12: a quest item has no price, and the Loot Helper says so (Shweep) ========
	local loot = {}
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("|Hitem:" .. loot[i].id .. ":0|h[" .. loot[i].name .. "]|h") end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, 1, nil, 1, false, l.quest or false end end
	_G.LootSlot = function() end
	local INFO = { [9801] = { "Gnoll Paw", 0 }, [9802] = { "Strange Rock", 0 }, [9803] = { "Mysterious Note", 0 }, [9701] = { "Broken Fang", 3 }, [9702] = { "Linen Belt", 22 } }
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 2; for b2 = 1, 5 do M.sizes[b2] = 0 end
	M.put(0, 1, { id = 9701, name = "Broken Fang", q = 1, class = 15, subclass = 0, price = 3 })
	M.put(0, 2, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", makeRoom = true, makeRoomValue = "vendor" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local realInfo, realInstant = C_Item.GetItemInfo, C_Item.GetItemInfoInstant
	C_Item.GetItemInfo = function(id)
		local num = tonumber(tostring(id):match("item:(%d+)")) or id
		local e = INFO[num]
		if e then return e[1], nil, 1, nil, nil, nil, nil, 1, nil, nil, e[2], num == 9803 and 12 or 15 end
		return realInfo(id)
	end
	C_Item.GetItemInfoInstant = function(id) if INFO[id] then return id, nil, nil, nil, 1, id == 9803 and 12 or 15 end return realInstant(id) end
	_G.GetNumQuestLogEntries = function() return 0, 0 end
	_G.LootFrame = CreateFrame("Frame", "LootFrame", UIParent); LootFrame.GetRight = function() return 500 end; LootFrame.GetTop = function() return 700 end; LootFrame:Show()
	local function openLoot() M.fire("LOOT_CLOSED"); M.runTimers(); M.fire("LOOT_OPENED"); M.runTimers() end
	local MR = n.MakeRoom
	-- the loot window marks it a quest item
	loot = { { id = 9801, name = "Gnoll Paw", quest = true } }
	openLoot()
	local f = MR.frame
	check(f and f:IsShown() and f.note:IsShown() and f.note.text == "Gnoll Paw is a quest item, so it has no price. These are simply your cheapest items.", "a quest item from the loot window: the note says so (" .. tostring(f and f.note.text) .. ")")
	-- its item class is Quest
	loot = { { id = 9803, name = "Mysterious Note" } }
	openLoot()
	check(f.note.text == "Mysterious Note is a quest item, so it has no price. These are simply your cheapest items.", "an item of the Quest class: the same (" .. tostring(f.note.text) .. ")")
	check(MR:IsQuestItem({ id = 9803 }) and MR:IsQuestItem({ id = 9801, questItem = true }) and not MR:IsQuestItem({ id = 9802 }) and not MR:IsQuestItem({}), "MR:IsQuestItem: the loot window's flag or the item class")
	-- other loot with no price: "yet", as before
	loot = { { id = 9802, name = "Strange Rock" } }
	openLoot()
	check(f.note.text == "Strange Rock has no price yet, so these are simply your cheapest items.", "other loot with no price: no price yet, as before (" .. tostring(f.note.text) .. ")")
	f:Hide()
	C_Item.GetItemInfo, C_Item.GetItemInfoInstant = realInfo, realInstant
	_G.BagSmithDB = nil
end)()

;(function()
	-- ======== 1.7.0-beta12: the 1.7 card, Shweep's text, and a body that scrolls (Shweep) ========
	for _, skin in ipairs({ "modern", "classic" }) do
		local S = skin .. ": "
		package.loaded.mock = nil
		local M = require("mock")
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local WN = n.WhatsNew
		local e = WN.ENTRIES[1]
		local heads = {}
		for _, it in ipairs(e.items) do heads[#heads + 1] = it:match("^|cfffac775(.-):|r") end
		if skin == "modern" then
			check(e.v == "1.7.0" and #e.items == 9 and table.concat(heads, "|") == "A Smarter Loot Helper|Protect|Mail and Trade|Split Gear by Binding|Lock Windows|Pinned Sections Stand Out|Simpler Section Settings|Section Values at Any Width|Smoother Clean Up",
				"the 1.7 card: nine bullets in Shweep's order (" .. table.concat(heads, "|") .. ")")
			local text = table.concat(e.items, " ")
			check(e.items[1]:find("Click another waiting item to make room for it instead.", 1, true) and e.items[1]:find("Hover the (i) beside the list's heading", 1, true)
				and e.items[1]:find("never offers what you still need for a quest, unless its heading is collapsed in your quest log.", 1, true),
				"the first: the switch, the list's heading, and the quest promise word for word")
			check(e.items[3]:find("all of its stacks now attach", 1, true) and e.items[3]:find("tops up partial stacks", 1, true), "Mail and Trade: all stacks attach, partial ones topped up")
			check(e.items[4]:find("with the rest in Gear: Other.", 1, true) and e.items[4]:find("Consumables: Other", 1, true), "Split Gear by Binding: Gear: Other and Consumables: Other")
			check(e.items[8]:find("small coin", 1, true) and e.items[9]:find("Clean Up Bags When Opened", 1, true), "the coin, and Clean Up with its setting's name")
			check(not text:find("\226\128\148") and not text:find("Text Size", 1, true), "no em dashes; nothing that isn't in 1.7")
		end
		n.version = "1.7.0-beta12"
		WN:ShowLatest(); M.runTimers()
		local c = WN.Card()
		local bar = c.body.ScrollBar
		check(c:IsShown() and c.sel == 1, S .. "(setup) the card opens on 1.7")
		check(c.bodyH <= WN.MAX_BODY and c.contentH > c.bodyH and c.scrolls, S .. "1.7 is taller than the body (at most " .. WN.MAX_BODY .. "): it scrolls (" .. c.contentH .. " in " .. c.bodyH .. ")")
		check(bar and bar:IsShown(), S .. "with its scrollbar shown")
		local b1 = c.lines[2]
		check(b1 and math.abs((b1.width or 0) - (440 - 32 - 32 - 10)) < 0.5 and math.abs(c.body:GetWidth() - (440 - 32)) < 0.5, S .. "the text narrows to make room for the bar (" .. tostring(b1 and b1.width) .. ")")
		local last = c.lines[10]
		check(last and last:IsShown() and last.text:find("Smoother Clean Up", 1, true), S .. "the ninth bullet is laid out")
		local wheel = c.body:GetScript("OnMouseWheel")
		wheel(c.body, -1)
		check(c.body:GetVerticalScroll() > 0 and c.body:GetVerticalScroll() <= 40, S .. "a notch of the wheel scrolls a line or two (" .. c.body:GetVerticalScroll() .. ")")
		wheel(c.body, -100000)
		check(c.body:GetVerticalScroll() == c.contentH - c.bodyH, S .. "the wheel stops at the end")
		wheel(c.body, 100000)
		check(c.body:GetVerticalScroll() == 0, S .. "and at the top")
		local h = c:GetHeight()
		wheel(c.body, -3)
		-- a shorter release: full width, no bar, the same size, back at the top
		local short
		for i, en in ipairs(c.entries) do if en.v == "1.5.1" then short = i end end
		WN:Select(short)
		check(c:GetHeight() == h and not c.scrolls and not bar:IsShown() and c.body:GetVerticalScroll() == 0 and math.abs(c.lines[2].width - (440 - 32 - 10)) < 0.5,
			S .. "1.5.1 fits: the same card size, no bar, full width, at the top")
		WN:Select(1)
		check(c.scrolls and bar:IsShown() and c.body:GetVerticalScroll() == 0 and c:GetHeight() == h, S .. "back on 1.7: the bar again, at the top, the same size")
		if skin == "classic" then
			check(bar.classicSnap ~= nil, S .. "the scrollbar is dressed for Classic")
		end
		WN:Close()
		-- a short screen: the screen's rule wins over MAX_BODY
		UIParent:SetHeight(420)
		WN:ShowLatest(); M.runTimers()
		check(c.bodyH < WN.MAX_BODY and c:GetHeight() <= 420 and c.scrolls and bar:IsShown(), S .. "on a short screen the body is shorter still, and scrolls (" .. c.bodyH .. ")")
		WN:Close()
		UIParent:SetHeight(768)
		_G.BagSmithDB = nil
	end
end)()
