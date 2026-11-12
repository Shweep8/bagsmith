;(function()
	-- 1.2.0: a merged row right-clicked at the mailbox or in the trade window: the rest of its stacks follow, within the window's slots
	package.loaded.mock = nil
	local M = require("mock")
	for s = 1, 5 do M.put(0, s, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 3 }) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	-- the mailbox and the trade window, as frames the game would show
	_G.MailFrame = CreateFrame("Frame", "MailFrame", UIParent); _G.SendMailFrame = CreateFrame("Frame", "SendMailFrame", MailFrame); MailFrame:Hide(); SendMailFrame:Hide()
	_G.TradeFrame = CreateFrame("Frame", "TradeFrame", UIParent); TradeFrame:Hide()
	_G.ATTACHMENTS_MAX_SEND = 12; _G.MAX_TRADE_ITEMS = 7
	local mailSlots, tradeSlots = {}, {}
	_G.GetSendMailItem = function(i) return mailSlots[i] end
	_G.GetTradePlayerItemInfo = function(i) return tradeSlots[i] end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local D = n.Drop
	n:Set("mergeStacks", true); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	-- merged rows are built by the view: the merged record sits on the button that shows it
	local function wool() n.Window.main:Refresh(true, "test"); M.runTimers(); for _, b in ipairs(n.Buttons.all) do if b:IsShown() and b.rec and b.rec.itemID == 2592 and b.rec.merged then return b.rec end end end
	local function said() return M.log[#M.log] or "" end
	check(D:Where() == nil, "nowhere special: no follow-up")
	-- the mailbox: the right-clicked stack attached by the game, the rest attach one by one
	-- (1.7.0-beta11, by design: an attached stack stays in its bag slot, locked, until the mail is sent, as a traded
	-- one does; the 1.2.0 model took it out of the bag, which the game doesn't, so the follow-up never ran in game)
	MailFrame:Show(); SendMailFrame:Show()
	check(D:Where() == "mail" and D:FreeSlots("mail") == 12, "with the send form open the destination is the mail, twelve slots free")
	local used = {}
	local realUse = C_Container.UseContainerItem
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; mailSlots[#mailSlots + 1] = "Wool Cloth"; M.bags[bag][slot].locked = true end
	local rec = wool()
	check(rec and rec.merged and rec.stacks == 5, "(setup) one merged row of five stacks")
	-- the click: the game attaches the clicked stack; BagSmith's hook sends the rest
	D:NoteTradeBaseline(rec)   -- (1.7.0-beta11) mouse-down: the mail holds none yet
	mailSlots[1] = "Wool Cloth"; M.bags[0][1].locked = true
	local b = n.Buttons.byBag[0][1]
	local members = {}; for _, m in ipairs(rec.members) do members[#members + 1] = { bag = m.bag, slot = m.slot, itemID = m.itemID, count = m.count } end
	D:MoveRest({ itemID = 2592, members = members, name = "Wool Cloth", where = "mail", first = { bag = 0, slot = 1 } })
	for _ = 1, 14 do M.runTimers() end
	table.sort(used)
	check(#used == 4 and used[1] == "0:2" and used[4] == "0:5", "at the mailbox the other four stacks attach (" .. table.concat(used, ", ") .. ")")
	-- the mail's slots fill: only what fits goes, and chat says how many did not
	for s = 1, 5 do M.put(0, s, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 3 }) end
	n:Scan(); M.runTimers(); rec = wool()
	mailSlots = {}; for i = 1, 10 do mailSlots[i] = "x" end   -- ten of twelve used
	used = {}
	D:NoteTradeBaseline(rec)   -- (1.7.0-beta11) mouse-down
	mailSlots[11] = "Wool Cloth"; M.bags[0][1].locked = true   -- the clicked stack took the eleventh (and stays, locked)
	members = {}; for _, m in ipairs(rec.members) do members[#members + 1] = { bag = m.bag, slot = m.slot, itemID = m.itemID, count = m.count } end
	D:MoveRest({ itemID = 2592, members = members, name = "Wool Cloth", where = "mail", first = { bag = 0, slot = 1 } })
	for _ = 1, 14 do M.runTimers() end
	check(#used == 1 and said():find("3 more would not fit in the mail", 1, true), "with one slot left, one stack follows and chat says three did not fit (" .. said() .. ")")
	-- the mail closing mid-way stops it
	MailFrame:Hide(); SendMailFrame:Hide()
	check(D:Where() == nil, "the send form closed: no destination")
	-- the trade window: stacks stay in the bag but become locked when the window takes them
	for s = 1, 5 do M.put(0, s, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 3 }) end
	n:Scan(); M.runTimers(); rec = wool()
	TradeFrame:Show()
	check(D:Where() == "trade" and D:FreeSlots("trade") == 6, "with the trade window open the destination is the trade, six slots free")
	used = {}
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; tradeSlots[#tradeSlots + 1] = "Wool Cloth"; M.bags[bag][slot].locked = true end
	D:NoteTradeBaseline({ itemID = 2592, name = "Wool Cloth" })   -- mouse-down: the trade holds none yet
	tradeSlots[1] = "Wool Cloth"; M.bags[0][1].locked = true   -- the clicked stack, placed by the game
	members = {}; for _, m in ipairs(rec.members) do members[#members + 1] = { bag = m.bag, slot = m.slot, itemID = m.itemID, count = m.count } end
	D:MoveRest({ itemID = 2592, members = members, name = "Wool Cloth", where = "trade", first = { bag = 0, slot = 1 } })
	for _ = 1, 14 do M.runTimers() end
	table.sort(used)
	check(#used == 4 and used[1] == "0:2" and used[4] == "0:5" and #tradeSlots == 5, "in the trade window the other four stacks follow, each left in the bag locked (" .. table.concat(used, ", ") .. ")")
	check(not said():find("Moved %d of"), "all placed: no shortfall message")
	-- a locked stack is already in the trade: it is skipped, not counted as a failure
	for s = 1, 5 do M.bags[0][s].locked = nil end
	tradeSlots = { "x", "x", "x", "x", "x" }   -- five of six used
	used = {}
	D:NoteTradeBaseline({ itemID = 2592, name = "Wool Cloth" })
	tradeSlots[6] = "Wool Cloth"; M.bags[0][1].locked = true
	n:Scan(); M.runTimers(); rec = wool()
	members = {}; for _, m in ipairs(rec.members) do members[#members + 1] = { bag = m.bag, slot = m.slot, itemID = m.itemID, count = m.count } end
	D:MoveRest({ itemID = 2592, members = members, name = "Wool Cloth", where = "trade", first = { bag = 0, slot = 1 } })
	for _ = 1, 6 do M.runTimers() end
	check(#used == 0 and said():find("no free slots for the rest of Wool Cloth", 1, true), "with the trade window full nothing follows and chat says so (" .. said() .. ")")
	TradeFrame:Hide()
	C_Container.UseContainerItem = realUse
	-- the bank path is unchanged: gated on being at the bank
	check(D:Where() == nil, "with everything closed there is no destination")
	n.atBank = true
	check(D:Where() == "bank" and D:FreeSlots("bank") == nil, "at the bank the destination is the bank, with no slot count")
	n.atBank = false
end)()

