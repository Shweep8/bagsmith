;(function()
	-- ======== 1.7.0-beta13: the 1.7.0-beta12 audit's F1: every header shows exactly one format, after any change ========
	-- A pooled header that had shown the coin kept it under stacked values (Shweep saw it in Split View, both skins).
	-- Every switch between the three formats (one line, stacked, the coin), each header checked.
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
		local realW
		-- (mock text is 6 px a letter: one title's width stands in for a column with less room)
		local function setTitle(w)
			local h = lane("GearSoulbound")
			realW = realW or h.text.GetStringWidth
			h.text.GetStringWidth = w and function() return w end or realW
			n:RefreshViews(true); M.runTimers()
		end
		-- what a header shows: "one", "stacked", "coin", or "mixed"/"none"
		local function shows(h)
			local one = h.sub:IsShown() and (h.sub.text or ""):find("^V: ") ~= nil
			local st = h.vAmt:IsShown() or h.vLabel:IsShown() or h.aAmt:IsShown() or h.aLabel:IsShown()
			local coin = h.valCoin ~= nil and h.valCoin:IsShown()
			local k = (one and 1 or 0) + (st and 1 or 0) + (coin and 1 or 0)
			if k > 1 then return "mixed" elseif one then return "one" elseif st then return "stacked" elseif coin then return "coin" end
			return "none"
		end
		local function all(kind)
			local hs, got = headers(), {}
			for _, h in ipairs(hs) do local s = shows(h); if s ~= kind then got[#got + 1] = h.laneId .. "=" .. s end end
			return #hs >= 4 and #got == 0, table.concat(got, ", ")
		end
		-- the widths for each format, found rather than assumed
		local widths = { one = false, stacked = nil, coin = 260 }
		for w = 100, 250, 5 do
			setTitle(w)
			if not widths.stacked and all("stacked") then widths.stacked = w end
		end
		check(widths.stacked ~= nil, S .. "(setup) a width where every header stacks its values (" .. tostring(widths.stacked) .. ")")
		local function go(kind) setTitle(widths[kind] or nil) end
		local kinds = { "one", "stacked", "coin" }
		for _, from in ipairs(kinds) do
			for _, to in ipairs(kinds) do
				go(from); go(to)
				local ok, bad = all(to)
				check(ok, S .. from .. " then " .. to .. ": every header shows " .. to .. " only" .. (bad ~= "" and (" (" .. bad .. ")") or ""))
			end
		end
		-- through all three and back, twice
		for _, k in ipairs({ "coin", "stacked", "one", "coin", "one", "stacked", "coin", "stacked" }) do go(k) end
		local ok, bad = all("stacked")
		check(ok, S .. "after a long run of changes, stacked only" .. (bad ~= "" and (" (" .. bad .. ")") or ""))
		go("one")
		_G.Auctionator = nil
	end
	_G.BagSmithDB = nil
end)()

;(function()
	-- ======== 1.7.0-beta13: the 1.7.0-beta12 audit's A1: an error while topping up stacks ends the job cleanly ========
	-- Each split, pick-up and place runs protected: an error is said and kept for /bs errors, this move's item comes off
	-- the cursor (back where it was), anything else on the cursor is left alone, nothing else moves, and the next move
	-- isn't refused as "still moving".
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
		-- the game's cursor: a pick-up or split takes the units out of the slot (locked); ClearCursor puts them back
		local st = { held = nil, attached = 0, clears = 0 }
		_G.ClearCursor = function()
			st.clears = st.clears + 1
			if st.held and st.held.id == 2589 then local src = M.bags[0][st.held.slot]; if src then src.count = src.count + st.held.n; src.locked = nil else M.put(0, st.held.slot, { id = 2589, name = "Linen Cloth", q = 1, count = st.held.n, class = 7, subclass = 5, price = 1 }) end end
			st.held = nil; M.cursorItem = nil
		end
		local function take(b, s, amount)
			local src = M.bags[b][s]
			st.held = { id = 2589, slot = s, n = amount }
			src.count = src.count - amount; src.locked = true
			if src.count <= 0 then M.bags[b][s] = nil end
			M.cursorItem = 2589
		end
		C_Container.SplitContainerItem = function(b, s, amount)
			if mode == "split_throw" then error("ADDON_ACTION_BLOCKED SplitContainerItem") end
			take(b, s, amount)
		end
		C_Container.PickupContainerItem = function(b, s)
			if not st.held then
				if mode == "pickup_throw" then error("ADDON_ACTION_BLOCKED PickupContainerItem") end
				return take(b, s, M.bags[b][s].count)
			end
			if mode == "place_throw" then error("ADDON_ACTION_BLOCKED PickupContainerItem") end
			if mode == "place_throw_other" then st.held = { id = 2835, slot = 0, n = 1 }; M.cursorItem = 2835; error("something else on the cursor") end
			local h = st.held; local dst = M.bags[b][s]
			dst.count = dst.count + h.n; st.held = nil; M.cursorItem = nil
			local src = M.bags[0][h.slot]; if src then src.locked = nil end
		end
		C_Container.UseContainerItem = function(b, s) st.attached = st.attached + 1; mail[#mail + 1] = M.bags[b][s].count; M.bags[b][s].locked = true end
		if mode == "check_throw" then
			local realInfo = C_Container.GetContainerItemInfo
			local placed = false
			local realPick = C_Container.PickupContainerItem
			C_Container.PickupContainerItem = function(b, s) local had = st.held; realPick(b, s); if had then placed = true end end
			C_Container.GetContainerItemInfo = function(b, s) if placed then error("reading the bag failed") end return realInfo(b, s) end
			st.restore = function() C_Container.GetContainerItemInfo = realInfo end
		end
		D:NoteTradeBaseline({ itemID = 2589, name = "Linen Cloth" })
		mail[1] = 20; M.bags[0][1].locked = true
		local members = { { bag = 0, slot = 1 }, { bag = 0, slot = 2 }, { bag = 0, slot = 3 }, { bag = 0, slot = 4 } }
		D:MoveRest({ itemID = 2589, name = "Linen Cloth", where = "mail", first = { bag = 0, slot = 1 }, members = members })
		local ok, err = pcall(function() for _ = 1, 40 do M.runTimers() end end)
		if st.restore then st.restore() end
		local log = table.concat(M.log, "|")
		local total = 0
		for s = 1, 4 do local it = M.bags[0][s]; if it then total = total + it.count end end
		return { ok = ok, err = err, D = D, M = M, n = n, st = st, log = log, total = total, mail = mail }
	end
	-- the control: 20 clicked, 19, 11 and 2 tidy to 20, 12, then attach
	local r = boot("success")
	check(r.ok and r.D.active == nil and r.st.attached == 2 and r.mail[2] == 20 and r.mail[3] == 12 and r.M.cursorItem == nil, "(control) 19, 11 and 2 go as 20 and 12 (" .. tostring(r.mail[2]) .. ", " .. tostring(r.mail[3]) .. ")")
	for _, mode in ipairs({ "split_throw", "pickup_throw", "place_throw", "check_throw" }) do
		r = boot(mode)
		check(r.ok, mode .. ": the error doesn't escape (" .. tostring(r.err) .. ")")
		check(r.D.active == nil and r.st.attached == 0, mode .. ": the job ends; nothing more is attached")
		check(r.log:find("something went wrong while topping up the stacks; see /bs errors", 1, true) and r.log:find("Error in Mail and trade: topping up stacks", 1, true),
			mode .. ": chat says so, once, and points to /bs errors")
		check(#(r.n.errorLog or {}) > 0 and r.n.errorLog[1]:find("Mail and trade: topping up stacks", 1, true), mode .. ": kept for /bs errors")
		-- (an attached stack stays in its bag slot, locked: the bags still hold all 52)
		check(r.M.cursorItem == nil and r.st.held == nil and r.total == 52, mode .. ": nothing on the cursor; all 52 still in the bags (" .. r.total .. ")")
		-- the next move isn't refused
		r.D:MoveRest({ itemID = 2589, name = "Linen Cloth", where = "mail", first = { bag = 0, slot = 2 }, members = { { bag = 0, slot = 2 }, { bag = 0, slot = 3 } } })
		check(not table.concat(r.M.log, "|"):find("Still moving", 1, true), mode .. ": the next move isn't refused as still moving")
	end
	-- something else on the cursor when the error comes: left alone
	r = boot("place_throw_other")
	check(r.ok and r.D.active == nil and r.st.attached == 0 and r.M.cursorItem == 2835, "an error with another item on the cursor: the job ends, that item is left alone")
	_G.BagSmithDB = nil
end)()

;(function()
	-- ======== 1.7.0-beta13: the 1.7.0-beta12 audit's A2: a send form that exists only later is hooked once ========
	package.loaded.mock = nil
	local M = require("mock")
	local ID = 2589
	for s, c in ipairs({ 11, 20, 19 }) do M.put(0, s, { id = ID, name = "Linen Cloth", q = 1, count = c, class = 7, subclass = 5, price = 1 }) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	_G.MailFrame = nil; _G.SendMailFrame = nil
	_G.TradeFrame = CreateFrame("Frame", "TradeFrame", UIParent); TradeFrame:Hide()
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local D = n.Drop
	n:Set("mergeStacks", true); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local function row()
		for _, b in ipairs(n.Buttons.all) do if b:IsShown() and b.rec and b.rec.itemID == ID and b.rec.merged then return b end end
	end
	check(not D.sendFormHooked and row() and row().rec.slot == 1, "(setup) no send form yet: nothing hooked; the row on its first stack")
	-- the mailbox opens on its Inbox; the send form exists from now on
	_G.MailFrame = CreateFrame("Frame", "MailFrame", UIParent); _G.SendMailFrame = CreateFrame("Frame", "SendMailFrame", MailFrame)
	local hooks = 0
	local realHook = SendMailFrame.HookScript
	SendMailFrame.HookScript = function(self, k, fn) hooks = hooks + 1; return realHook(self, k, fn) end
	MailFrame:Show(); SendMailFrame:Hide(); M.fire("MAIL_SHOW"); M.runTimers(); M.runTimers()
	check(D.sendFormHooked == SendMailFrame and hooks == 2, "the first MAIL_SHOW that finds the send form hooks its OnShow and OnHide (" .. hooks .. ")")
	check(row().rec.slot == 1, "on the Inbox the row stays on its first stack")
	SendMailFrame:Show(); SendMailFrame.scripts.OnShow(SendMailFrame); M.runTimers(); M.runTimers()
	check(D:StandsOnFullest() and row().rec.slot == 2, "switching to Send Mail moves the row to its fullest stack (" .. row().rec.slot .. ")")
	SendMailFrame:Hide(); SendMailFrame.scripts.OnHide(SendMailFrame); M.runTimers(); M.runTimers()
	check(row().rec.slot == 1, "back to the Inbox: the first stack again")
	MailFrame:Hide(); M.fire("MAIL_CLOSED"); M.runTimers()
	MailFrame:Show(); M.fire("MAIL_SHOW"); M.runTimers()
	check(hooks == 2, "a second visit doesn't hook again")
	MailFrame:Hide(); M.fire("MAIL_CLOSED"); M.runTimers()
	_G.BagSmithDB = nil
end)()
