;(function()
	-- ======== 1.7.0-beta14: the 1.7.0-beta13 audit's R1 and R2 ========
	-- R1: the tidy clears the cursor only while it holds it (from its own pick-up to the place), so a stack the player
	-- picks up meanwhile, even of the same item, is never touched; each confirmation checks the job's guard before it
	-- reads the bags. R2: the whole move job is protected: an error anywhere (the stack size read, the step after the
	-- tidy, a follow-up, the setup) ends the job cleanly, said and kept for /bs errors, and the next move isn't refused.
	local function boot(mode)
		package.loaded.mock = nil
		local M = require("mock")
		for b = 1, 5 do M.sizes[b] = 0 end
		M.sizes[0] = 4
		for s, c in ipairs({ 20, 19, 11, 2 }) do M.put(0, s, { id = 2589, name = "Linen Cloth", q = 1, count = c, class = 7, subclass = 5, price = 1 }) end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {} } }
		_G.MailFrame = CreateFrame("Frame", "MailFrame", UIParent); _G.SendMailFrame = CreateFrame("Frame", "SendMailFrame", MailFrame)
		_G.TradeFrame = CreateFrame("Frame", "TradeFrame", UIParent); TradeFrame:Hide()
		local mail = {}
		_G.GetSendMailItem = function(i) local a = mail[i]; if a then return "Linen Cloth", 2589, nil, a end end
		_G.GetSendMailItemLink = function(i) if mail[i] then return "item:2589:0" end end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local D = n.Drop
		local st = { held = nil, attached = 0, clears = 0, moves = 0, reads = 0 }
		_G.ClearCursor = function()
			st.clears = st.clears + 1
			if st.held and st.held.slot then local src = M.bags[0][st.held.slot]; if src then src.count = src.count + st.held.n; src.locked = nil end end
			st.held = nil; M.cursorItem = nil
		end
		local function take(b, s, amount)
			local src = M.bags[b][s]
			st.held = { slot = s, n = amount }
			src.count = src.count - amount; src.locked = true
			if src.count <= 0 then M.bags[b][s] = nil end
			M.cursorItem = 2589
		end
		C_Container.SplitContainerItem = function(b, s, amount)
			take(b, s, amount)
			if mode == "split_holds_then_throws" then error("the split put the item on the cursor, then failed") end
		end
		C_Container.PickupContainerItem = function(b, s)
			if not st.held then return take(b, s, M.bags[b][s].count) end
			local h = st.held; local dst = M.bags[b][s]
			dst.count = dst.count + h.n; st.held = nil; M.cursorItem = nil; st.moves = st.moves + 1
			local src = M.bags[0][h.slot]; if src then src.locked = nil end
			-- the player's own gesture during the confirmation's wait
			if mode == "user_same_id" or mode == "user_same_id_throw" then st.userDrag = true end
			if mode == "cancel_then_throw" then st.cancelSoon = true end
		end
		C_Container.UseContainerItem = function(b, s) st.attached = st.attached + 1; mail[#mail + 1] = M.bags[b][s].count; M.bags[b][s].locked = true end
		local realInfo = C_Container.GetContainerItemInfo
		local realFree = D.FreeSlots
		local frees = 0
		D.FreeSlots = function(self, ...)
			frees = frees + 1
			if mode == "setup_throw" and frees == 1 then error("reading the mail's room failed") end
			if mode == "continuation_throw" and frees == 2 then error("reading the mail's room failed") end
			return realFree(self, ...)
		end
		if mode == "maxstack_throw" then
			C_Item.GetItemMaxStackSizeByID = nil
			C_Item.GetItemInfo = function() error("the stack size read failed") end
		end
		local timers = {}
		-- one timer round: the player's drag and the cancel happen between the place and its confirmation
		local function round()
			local ts = M.timers or {}; M.timers = {}
			if st.userDrag then st.userDrag = false; M.cursorItem = 2589; st.userHolding = true end
			if st.cancelSoon then st.cancelSoon = false; MailFrame:Hide(); SendMailFrame:Hide() end
			for _, fn in ipairs(ts) do fn() end
		end
		C_Container.GetContainerItemInfo = function(b, s)
			st.reads = st.reads + 1
			if (mode == "user_same_id_throw" and st.userHolding) or (mode == "cancel_then_throw" and not MailFrame:IsShown()) then error("reading the bag failed") end
			return realInfo(b, s)
		end
		D:NoteTradeBaseline({ itemID = 2589, name = "Linen Cloth" })
		mail[1] = 20; M.bags[0][1].locked = true
		local members = { { bag = 0, slot = 1 }, { bag = 0, slot = 2 }, { bag = 0, slot = 3 }, { bag = 0, slot = 4 } }
		local okSetup, errSetup = pcall(D.MoveRest, D, { itemID = 2589, name = "Linen Cloth", where = "mail", first = { bag = 0, slot = 1 }, members = members })
		local ok, err = pcall(function() for _ = 1, 40 do round() end end)
		C_Container.GetContainerItemInfo = realInfo
		return { ok = ok and okSetup, err = err or errSetup, D = D, M = M, n = n, st = st, log = table.concat(M.log, "|"), restore = function() MailFrame:Show(); SendMailFrame:Show() end }
	end
	local function nextMoveWorks(r)
		r.restore(); r.M.cursorItem = nil
		r.D:MoveRest({ itemID = 2589, name = "Linen Cloth", where = "mail", first = { bag = 0, slot = 2 }, members = { { bag = 0, slot = 2 }, { bag = 0, slot = 3 } } })
		return not table.concat(r.M.log, "|"):find("Still moving", 1, true)
	end

	-- R1: the player's own stack of the same item, picked up while a move waits for its confirmation
	local r = boot("user_same_id")
	check(r.ok and r.st.moves == 1 and r.st.clears == 0 and r.M.cursorItem == 2589, "R1: a same-item stack the player picks up during the wait stays on the cursor")
	check(r.D.active == nil and r.st.attached == 0 and r.log:find("something is on your cursor", 1, true), "R1: the job stops there, saying why")
	r = boot("user_same_id_throw")
	check(r.ok and r.st.clears == 0 and r.M.cursorItem == 2589 and r.D.active == nil, "R1: and when the bag read would fail too, the player's stack is still left alone")
	check(not r.log:find("Error in", 1, true), "R1: the guard comes first, so the failing read isn't reached")
	-- the job's guard before the read: the mail closes during the wait, the read would fail
	r = boot("cancel_then_throw")
	check(r.ok and r.D.active == nil and r.st.moves == 1 and r.st.attached == 0 and r.log:find("the mail closed", 1, true) and not r.log:find("Error in", 1, true),
		"R1: the mail closing during the wait ends the tidy without reading the bags")
	-- control: while the tidy holds the cursor, its own item is put back on an error
	r = boot("split_holds_then_throws")
	check(r.ok and r.D.active == nil and r.st.clears == 1 and r.M.cursorItem == nil and r.st.attached == 0 and r.log:find("something went wrong while topping up the stacks", 1, true),
		"(control) an error while the tidy holds its own item: the item goes back, the job ends")
	local total = 0; for s = 1, 4 do local it = r.M.bags[0][s]; if it then total = total + it.count end end
	check(total == 52, "(control) every unit still in the bags (" .. total .. ")")
	-- R2: errors outside the tidy's own steps
	for _, case in ipairs({
		{ "maxstack_throw", "something went wrong while topping up the stacks" },
		{ "continuation_throw", "something went wrong while moving the stacks" },
		{ "setup_throw", nil },
	}) do
		local mode, words = case[1], case[2]
		r = boot(mode)
		check(r.ok, mode .. ": the error doesn't escape (" .. tostring(r.err) .. ")")
		check(r.D.active == nil and r.st.attached == 0 and r.M.cursorItem == nil, mode .. ": no job left running, nothing more attached, nothing on the cursor")
		check(r.log:find("Error in", 1, true) and #(r.n.errorLog or {}) > 0, mode .. ": said once, kept for /bs errors")
		if words then check(r.log:find(words, 1, true), mode .. ": chat says the rest stayed (" .. words .. ")") end
		check(nextMoveWorks(r), mode .. ": the next move isn't refused as still moving")
	end
	_G.BagSmithDB = nil
end)()

;(function()
	-- R2: a follow-up's own steps (the bank's), protected too: a bag read that fails mid-job ends the job
	package.loaded.mock = nil
	local M = require("mock")
	for s, c in ipairs({ 20, 20, 20 }) do M.put(0, s, { id = 2589, name = "Linen Cloth", q = 1, count = c, class = 7, subclass = 5, price = 1 }) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {} } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local D = n.Drop
	n.atBank = true
	local used = 0
	C_Container.UseContainerItem = function(b, s) used = used + 1; M.bags[b][s] = nil end
	local realInfo = C_Container.GetContainerItemInfo
	local reads = 0
	C_Container.GetContainerItemInfo = function(b, s) reads = reads + 1; if used >= 1 then error("reading the bag failed") end return realInfo(b, s) end
	M.bags[0][1] = nil
	D:MoveRest({ itemID = 2589, name = "Linen Cloth", first = { bag = 0, slot = 1 }, members = { { bag = 0, slot = 1 }, { bag = 0, slot = 2 }, { bag = 0, slot = 3 } } })
	local ok, err = pcall(function() for _ = 1, 30 do M.runTimers() end end)
	C_Container.GetContainerItemInfo = realInfo
	local log = table.concat(M.log, "|")
	check(ok and D.active == nil and used == 1 and log:find("something went wrong while moving the stacks", 1, true), "R2: a bank follow-up whose bag read fails ends the job, said (" .. tostring(err) .. ")")
	n.atBank = false
	_G.BagSmithDB = nil
end)()

;(function()
	-- ======== 1.7.0-beta14: the game's Show on Backpack picks, pinned without the button (Shweep) ========
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", fav = {} } } }
	local names = { [1901] = "Honor", [1902] = "Arena Points", [1903] = "Marks" }
	local realGet = C_CurrencyInfo.GetCurrencyInfo
	_G.C_CurrencyInfo.GetCurrencyInfo = function(id) if names[id] then return { name = names[id], quantity = 9, iconFileID = 8, quality = 1 } end return realGet and realGet(id) end
	M.backpackPicks = {}   -- the game hasn't answered yet
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local W = n.Window
	local function fav(id) return n.Currency:IsFavorite("c:" .. id) end
	local function seen() local t = {}; for id in pairs(BagSmithCharDB.blizzPicksSeen or {}) do t[#t + 1] = id end; table.sort(t); return table.concat(t, ",") end
	-- no answer yet: nothing pinned, nothing marked
	W:Show()
	check(#n.db.fav == 0 and seen() == "", "no picks from the game yet: nothing pinned, nothing marked as seen")
	-- the game's answer arrives (its currency update): pinned now, and the footer redraws
	M.backpackPicks = { 1901 }
	M.fire("CURRENCY_DISPLAY_UPDATE"); M.runTimers(); M.runTimers()
	check(fav(1901) and seen() == "1901", "the answer arrives: Honor pinned, without the button")
	n:RefreshViews(true); M.runTimers()
	check((W.main.favShown or 0) == 1, "and in the footer")
	W:Hide()
	-- the first open on a character whose picks are there at once: pinned before the window draws
	package.loaded.mock = nil
	M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", fav = {} } } }
	_G.C_CurrencyInfo.GetCurrencyInfo = function(id) if names[id] then return { name = names[id], quantity = 9, iconFileID = 8, quality = 1 } end end
	M.backpackPicks = { 1901, 1902 }
	n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD")
	W = n.Window
	-- (no timers run between the open and the check: the pins are there on the window's first draw)
	W:Show()
	check(fav(1901) and fav(1902) and (W.main.favShown or 0) == 2, "the first open: both picks pinned and in the footer as the window draws (" .. tostring(W.main.favShown) .. ")")
	-- unpinned in BagSmith: stays unpinned on the next open and the next currency update
	n.Currency:ToggleFavorite("c:1902")
	W:Hide(); W:Show(); M.fire("CURRENCY_DISPLAY_UPDATE"); M.runTimers(); M.runTimers()
	check(fav(1901) and not fav(1902), "a pick unpinned in BagSmith stays unpinned")
	-- a pick made later: pinned on the next open; nothing is unpinned when a pick is taken away in the game
	M.backpackPicks = { 1901, 1903 }
	W:Hide(); W:Show()
	check(fav(1903) and fav(1901) and not fav(1902), "a new pick is pinned on the next open")
	M.backpackPicks = { 1903 }
	W:Hide(); W:Show()
	check(fav(1901), "a pick taken away in the game is never unpinned by BagSmith")
	-- the button brings back the ones unpinned
	M.backpackPicks = { 1901, 1902, 1903 }
	n.Drawer:Show()
	local f = n.Drawer.frame
	check(f.import.tip == "Pin your Blizzard picks again" and f.import.tipSub:find("pinned for you when the bags open", 1, true), "the button's tooltip says it's automatic now")
	f.import:GetScript("OnClick")(f.import)
	check(fav(1902), "the button pins an unpinned pick again")
	-- the seen list is saved per character and checked on load
	check(type(BagSmithCharDB.blizzPicksSeen) == "table" and BagSmithCharDB.blizzPicksSeen[1901] and BagSmithCharDB.blizzPicksSeen[1902] and BagSmithCharDB.blizzPicksSeen[1903], "the picks already seen are saved for this character")
	package.loaded.mock = nil
	M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {}, blizzPicksSeen = { [1901] = true, bad = true, [5] = "yes" } }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", fav = {} } } }
	M.backpackPicks = { 1901 }
	n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers()
	check(BagSmithCharDB.blizzPicksSeen[1901] == true and BagSmithCharDB.blizzPicksSeen.bad == nil and BagSmithCharDB.blizzPicksSeen[5] == nil, "the saved list keeps only currency IDs")
	n.Window:Show()
	check(not fav(1901), "a pick this character had before isn't pinned again after a reload")
	n.Window:Hide()
	_G.C_CurrencyInfo.GetCurrencyInfo = realGet
	_G.BagSmithDB = nil
end)()
