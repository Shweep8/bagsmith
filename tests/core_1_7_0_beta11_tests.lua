;(function()
	-- ======== 1.7.0-beta11: the Loot Helper's headings and its Protect button (Shweep) ========
	-- In game the heading "To make room for <loot>" was centered in its box, so the (i) placed after the text's width
	-- sat over the text. Every Loot Helper heading is left-justified now; and Protect is a gray button in both skins,
	-- a second choice beside the main one.
	local loot = {}
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("|Hitem:" .. loot[i].id .. ":0|h[" .. loot[i].name .. "]|h") end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, l.qty or 1, nil, l.q or 1 end end
	_G.LootSlot = function() end
	local LONG = "Crude Battle Axe of the Unyielding Northern Wastes"
	local INFO = { [9740] = { "Rough Gem", 1, 1, 30 }, [9741] = { "Shiny Ring", 2, 1, 500 }, [9743] = { "Crude Battle Axe", 1, 1, 400 },
		[9744] = { LONG, 1, 1, 400 },
		[9701] = { "Broken Fang", 0, 1, 3 }, [9702] = { "Linen Belt", 1, 1, 22 }, [9720] = { "Gnoll Paw", 1, 20, 2 },
		[9703] = { "Linen Cloth", 1, 20, 1 }, [9731] = { "Fine Ring", 1, 1, 80 }, [6265] = { "Soul Shard", 1, 1, 0 } }
	local function boot(stock, skin, prof, class)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return class or "Warrior", (class or "Warrior"):upper() end
		M.sizes[0] = 6
		for b = 1, 5 do M.sizes[b] = 0 end
		stock(M)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local pr = { skin = skin or "modern", makeRoom = true, makeRoomValue = "vendor", makeRoomAsk = false }
		for k, v in pairs(prof or {}) do pr[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = pr } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id)
			local num = tonumber(tostring(id):match("item:(%d+)")) or id
			local e = INFO[num]
			if e then return e[1], nil, e[2], nil, nil, nil, nil, e[3], nil, nil, e[4] end
			return realInfo(id)
		end
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id; M.cursorSlot = { bag, slot } end
		_G.ClearCursor = function() M.cursorItem = nil end
		_G.DeleteCursorItem = function() local p = M.cursorSlot; if p then M.bags[p[1]][p[2]] = nil end; M.cursorItem = nil end
		_G.GetNumQuestLogEntries = function() return 0, 0 end
		return n, M
	end
	local function pack(M)
		M.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
		M.put(0, 2, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
		M.put(0, 3, { id = 9720, name = "Gnoll Paw", q = 1, count = 5, stack = 20, class = 15, subclass = 0, price = 2 })
		M.put(0, 4, { id = 9731, name = "Fine Ring", q = 1, class = 4, subclass = 0, price = 80, equip = "INVTYPE_FINGER" })
		M.put(0, 5, { id = 9703, name = "Linen Cloth", q = 1, count = 5, stack = 20, class = 7, subclass = 5, price = 1 })
		M.put(0, 6, { id = 9703, name = "Linen Cloth", q = 1, count = 7, stack = 20, class = 7, subclass = 5, price = 1 })
	end
	local function shownHeads(f) local t = {}; for _, h in ipairs(f.heads) do if h:IsShown() then t[#t + 1] = h end end return t end
	local function allLeft(f) for _, h in ipairs(shownHeads(f)) do if h:GetJustifyH() ~= "LEFT" then return false, h.text end end return true end
	local function headNamed(f, prefix) for _, h in ipairs(shownHeads(f)) do if (h.text or ""):find(prefix, 1, true) == 1 then return h end end end
	local function rowNamed(f, name) for _, r in ipairs(f.destroyRows) do if r:IsShown() and r.name.text == name then return r end end end
	local function openLoot(M) M.fire("LOOT_CLOSED"); M.runTimers(); M.fire("LOOT_OPENED"); M.runTimers() end
	-- where the (i) sits: its offset from the heading's left edge
	local function infoX(f, h) local p = f.footInfo.points[1]; return p and p[2] == h and p[3] == "LEFT" and p[4] or nil end
	local function gray(c, lo, hi) return c and math.abs(c[1] - c[2]) < 0.001 and math.abs(c[2] - c[3]) < 0.001 and c[1] >= lo and c[1] <= hi end

	for _, skin in ipairs({ "modern", "classic" }) do
		local S = skin .. ": "
		local n, M = boot(pack, skin)
		_G.LootFrame = CreateFrame("Frame", "LootFrame", UIParent); LootFrame.GetRight = function() return 500 end; LootFrame.GetTop = function() return 700 end; LootFrame:Show()
		-- ---- the heading and its (i): a short name (Shweep's screenshot)
		loot = { { id = 9743, name = "Crude Battle Axe", q = 1 } }
		openLoot(M)
		local MR, f = n.MakeRoom, n.MakeRoom.frame
		check(f and f:IsShown(), S .. "(setup) the Loot Helper is open")
		local h = headNamed(f, "To make room for ")
		check(h and h.text == "To make room for Crude Battle Axe", S .. "(setup) the heading names the loot (" .. tostring(h and h.text) .. ")")
		local ok, bad = allLeft(f)
		check(ok, S .. "every Loot Helper heading is left-justified" .. (bad and (" (not: " .. bad .. ")") or ""))
		local x, sw = infoX(f, h), h:GetStringWidth()
		check(x and h.width and sw < h.width and math.abs(x - (sw + 4)) < 0.5,
			S .. "a short name: the text starts at the heading's left edge, so the (i) sits just after it (" .. tostring(x) .. " vs text " .. sw .. ", box " .. tostring(h.width) .. ")")
		-- ---- a name too long for the box: it truncates, and the (i) stays at the box's end, after the text
		loot = { { id = 9744, name = LONG, q = 1 } }
		openLoot(M)
		h = headNamed(f, "To make room for ")
		x, sw = infoX(f, h), h:GetStringWidth()
		check(h:GetJustifyH() == "LEFT" and sw > h.width and x and math.abs(x - (h.width + 4)) < 0.5,
			S .. "a long name: left-justified and truncated in its box, the (i) just past the box (" .. tostring(x) .. ", box " .. tostring(h.width) .. ")")
		-- ---- two waiting: both headings left-justified, and the second one still places its (i) after its own text
		loot = { { id = 9740, name = "Rough Gem", q = 1 }, { id = 9741, name = "Shiny Ring", q = 2 } }
		openLoot(M)
		ok, bad = allLeft(f)
		check(ok and #shownHeads(f) == 2 and shownHeads(f)[1].text == "Waiting to loot", S .. "with items waiting, both headings are left-justified" .. (bad and (" (not: " .. bad .. ")") or ""))
		h = headNamed(f, "To make room for ")
		x, sw = infoX(f, h), h:GetStringWidth()
		check(h and math.abs((x or -99) - (sw + 4)) < 0.5, S .. "the (i) follows \"" .. tostring(h and h.text) .. "\"")
		-- ---- Protect: gray, beside the main button
		local belt = rowNamed(f, "Linen Belt")
		belt:GetScript("OnClick")(belt)
		check(f.act.label.text == "Destroy Linen Belt" and f.protect:IsShown() and f.protect.secondary == true, S .. "an item to let go chosen: Protect shows, marked secondary")
		if skin == "modern" then
			check(gray(f.protect.bgColor, 0.15, 0.35) and gray(f.protect.borderColor, 0.3, 0.6) and gray(f.protect.label.textColor, 0.7, 0.9),
				S .. "Protect is plain gray: background, border and text")
			local ar, ag, ab = n.Skins:Accent()
			local bc = f.protect.borderColor
			check(not (math.abs(bc[1] - ar) < 0.01 and math.abs(bc[2] - ag) < 0.01 and math.abs(bc[3] - ab) < 0.01), S .. "Protect never takes the accent color")
			local restBg = f.protect.bgColor[1]
			f.protect.scripts.OnEnter(f.protect)
			check(gray(f.protect.bgColor, 0.15, 0.45) and f.protect.bgColor[1] > restBg, S .. "hovered, Protect lifts a step and stays gray")
			f.protect.scripts.OnLeave(f.protect)
			check(math.abs(f.protect.bgColor[1] - restBg) < 0.001, S .. "left, it rests gray again")
			check(not gray(f.act.label.textColor, 0, 1) or f.act.secondary ~= true, S .. "the main button isn't secondary")
		else
			check(f.protect.classicOn and f.protect.classic and f.protect.classic.bsGrayed == true and gray(f.protect.label.textColor, 0.7, 0.95),
				S .. "Protect wears Blizzard's button art, grayed, with gray text")
			check(f.act.classicOn and f.act.classic and f.act.classic.bsGrayed ~= true and f.act.secondary ~= true, S .. "the main button keeps its own colors")
			-- every texture of the art: desaturated while secondary, put back when not
			local art = f.protect.classic
			local t1, t2, tN = M.tex(), M.tex(), M.tex()
			local label = M.fs()
			art.GetRegions = function() return t1, t2, label end
			art.GetNormalTexture = function() return tN end
			art.bsGrayed = nil
			f.protect:SetActive(false)
			check(t1.desaturated == true and t2.desaturated == true and tN.desaturated == true, S .. "the art's textures are desaturated")
			f.protect:SetSecondary(false)
			check(t1.desaturated == false and tN.desaturated == false and not gray(f.protect.label.textColor, 0, 1), S .. "SetSecondary(false) puts the art and the text back")
			f.protect:SetSecondary(true)
		end
		f:Hide()
	end

	-- ---- the pooled heading reused below (Soul Shards) is left-justified too
	do
		local n, M = boot(function(M)
			pack(M)
			M.sizes[0] = 7
			M.put(0, 7, { id = 6265, name = "Soul Shard", q = 1, count = 1, stack = 1, class = 15, subclass = 0, price = 0 })
		end, "modern", { shardKeep = 0 }, "Warlock")
		loot = { { id = 9741, name = "Shiny Ring", q = 2 } }
		openLoot(M)
		local f = n.MakeRoom.frame
		local sh = headNamed(f, "Soul Shards")
		local ok, bad = allLeft(f)
		check(sh and ok, "a warlock's Soul Shards heading is left-justified too" .. (bad and (" (not: " .. bad .. ")") or ""))
		f:Hide()
	end
	_G.BagSmithDB = nil
end)()

;(function()
	-- ======== 1.7.0-beta11: a merged stack right-clicked at the mailbox attaches all its stacks (Player Index, Shweep) ========
	-- On this client an attached stack stays in its bag slot, locked, until the mail is sent, as a traded one does. The
	-- follow-up waited for it to leave its slot, so it said "Moved 0 of 4 stacks of Linen Cloth; nothing moved (the
	-- stack stayed locked)." with the clicked stack attached and the rest left behind. Now the mail is read as the trade
	-- is: a stack counts as attached when it's locked in its slot and the mail holds one more of that item than before.
	package.loaded.mock = nil
	local M = require("mock")
	local function stock() for s = 1, 4 do M.put(0, s, { id = 2589, name = "Linen Cloth", q = 1, count = s == 4 and 3 or 20, stack = 20, class = 7, subclass = 5, price = 1 }) end end
	stock()
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	_G.MailFrame = CreateFrame("Frame", "MailFrame", UIParent); _G.SendMailFrame = CreateFrame("Frame", "SendMailFrame", MailFrame); MailFrame:Hide(); SendMailFrame:Hide()
	_G.TradeFrame = CreateFrame("Frame", "TradeFrame", UIParent); TradeFrame:Hide()
	_G.ATTACHMENTS_MAX_SEND = 12; _G.MAX_TRADE_ITEMS = 7
	-- the mail's attachments: { name, id }; the game gives the name and the item ID, and a link
	local mail, trade = {}, {}
	_G.GetSendMailItem = function(i) local a = mail[i]; if a then return a.name, a.id end end
	_G.GetSendMailItemLink = function(i) local a = mail[i]; if a and a.id then return "|Hitem:" .. a.id .. ":0|h[" .. a.name .. "]|h" end end
	_G.GetTradePlayerItemInfo = function(i) return trade[i] end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local D = n.Drop
	n:Set("mergeStacks", true); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local function linenButton()
		n:Scan(); M.runTimers(); n.Window.main:Refresh(true, "test"); M.runTimers()
		for _, b in ipairs(n.Buttons.all) do if b:IsShown() and b.rec and b.rec.itemID == 2589 and b.rec.merged then return b end end
	end
	local function said() return M.log[#M.log] or "" end
	local function clearLog() for i = #M.log, 1, -1 do M.log[i] = nil end end
	local function attach(bag, slot) local it = M.bags[bag][slot]; mail[#mail + 1] = { name = it.name, id = it.id }; it.locked = true end
	local used = {}
	local realUse = C_Container.UseContainerItem
	-- the game: a right-clicked stack at the mailbox is attached and stays where it is, locked
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; attach(bag, slot) end
	-- the player's right-click, as the game runs it: mouse-down, the game attaches the clicked stack, then the click's hooks
	local function rightClick(b)
		b.scripts.OnMouseDown(b, "RightButton")
		attach(b.rec.bag, b.rec.slot)
		b.scripts.OnClick(b, "RightButton")
	end
	local function run() for _ = 1, 30 do M.runTimers() end end
	local function attached() local c = 0; for _, a in ipairs(mail) do if a.id == 2589 then c = c + 1 end end return c end

	MailFrame:Show(); SendMailFrame:Show(); M.fire("MAIL_SHOW")
	local H = D.HOLDS or {}
	check(D:Where() == "mail" and H.mail and H.trade and not H.bank, "at the send form; the mail and the trade hold stacks, the bank doesn't")
	-- ---- the reported case: 20 + 20 + 20 + 3, one merged row
	local b = linenButton()
	check(b and b.rec.stacks == 4, "(setup) one merged row of four Linen Cloth stacks")
	clearLog()
	rightClick(b)
	run()
	table.sort(used)
	check(#used == 3 and attached() == 4, "all four stacks are attached: the clicked one by the game, three by BagSmith (" .. table.concat(used, ", ") .. "; " .. attached() .. " attached)")
	check(not said():find("Moved", 1, true) and not said():find("nothing moved", 1, true), "everything attached: no message in chat (" .. said() .. ")")
	check(D.active == nil, "the job is done")
	-- ---- the mail's slots: what fits goes, and chat says how many didn't
	M.fire("MAIL_SEND_SUCCESS"); stock(); mail = {}; used = {}
	for i = 1, 10 do mail[i] = { name = "Rough Stone", id = 2835 } end   -- ten of twelve used
	b = linenButton(); clearLog()
	rightClick(b)
	run()
	check(#used == 1 and attached() == 2 and said():find("Moved 2 stacks of Linen Cloth; 2 more would not fit in the mail.", 1, true),
		"with two slots left, the clicked stack and one more go, and chat says two didn't fit (" .. said() .. ")")
	-- ---- a stack already attached is skipped, not counted as a failure
	M.fire("MAIL_SEND_SUCCESS"); stock(); mail = {}; used = {}
	attach(0, 4)   -- the 3 is already on the mail
	b = linenButton(); clearLog()
	check(b and b.rec.bag == 0 and b.rec.slot ~= 4, "(setup) the row's button stands on an unattached stack")
	rightClick(b)
	run()
	check(#used == 2 and attached() == 4 and not said():find("Moved", 1, true), "the stack already attached is skipped; the others follow, no message (" .. #used .. " used, " .. said() .. ")")
	-- ---- a lock alone isn't proof: a stack that locks but the mail didn't take stops the job, said
	M.fire("MAIL_SEND_SUCCESS"); stock(); mail = {}; used = {}
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; M.bags[bag][slot].locked = true end
	b = linenButton(); clearLog()
	rightClick(b)
	run()
	check(#used == 1 and said():find("Moved 1 of 4 stacks of Linen Cloth; the rest stayed (a stack stayed locked).", 1, true),
		"a follower that locks without the mail growing isn't counted, and the job stops (" .. said() .. ")")
	-- a follower the game won't attach (nothing happens): stops, said
	M.fire("MAIL_SEND_SUCCESS"); stock(); mail = {}; used = {}
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot end
	b = linenButton(); clearLog()
	rightClick(b)
	run()
	check(#used == 1 and said():find("Moved 1 of 4 stacks of Linen Cloth; the rest stayed (the mail may be full, or the game wants a click for each).", 1, true),
		"a follower the mail didn't take stops the job (" .. said() .. ")")
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; attach(bag, slot) end
	-- ---- the clicked stack: locked but not on the mail moves nothing
	M.fire("MAIL_SEND_SUCCESS"); stock(); mail = {}; used = {}
	b = linenButton(); clearLog()
	b.scripts.OnMouseDown(b, "RightButton")
	M.bags[b.rec.bag][b.rec.slot].locked = true   -- locked, the mail unchanged
	b.scripts.OnClick(b, "RightButton")
	run()
	check(#used == 0 and said():find("Moved 0 of 4 stacks of Linen Cloth; nothing moved (the stack stayed locked).", 1, true), "a locked clicked stack the mail doesn't hold moves nothing (" .. said() .. ")")
	-- ---- no mouse-down count (or one taken in a trade): nothing can be told, nothing follows
	M.fire("MAIL_SEND_SUCCESS"); stock(); mail = {}; used = {}
	b = linenButton(); clearLog()
	local members = {}; for _, m in ipairs(b.rec.members) do members[#members + 1] = { bag = m.bag, slot = m.slot } end
	D.tradeBaseline = nil
	attach(b.rec.bag, b.rec.slot)
	D:MoveRest({ itemID = 2589, members = members, name = "Linen Cloth", where = "mail", first = { bag = b.rec.bag, slot = b.rec.slot } })
	run()
	check(#used == 0 and said():find("could not be confirmed", 1, true), "without the mouse-down count nothing follows (" .. said() .. ")")
	M.fire("MAIL_SEND_SUCCESS"); stock(); mail = {}; used = {}; clearLog()
	D.tradeBaseline = { itemID = 2589, where = "trade", count = 0, at = GetTime() }
	attach(b.rec.bag, b.rec.slot)
	D:MoveRest({ itemID = 2589, members = members, name = "Linen Cloth", where = "mail", first = { bag = b.rec.bag, slot = b.rec.slot } })
	run()
	check(#used == 0 and said():find("could not be confirmed", 1, true), "a count taken in a trade never serves the mail (" .. said() .. ")")
	-- ---- the mail's count: by link, by the item ID the game gives, or by name
	mail = { { name = "Linen Cloth", id = 2589 }, { name = "Wool Cloth", id = 2592 } }
	check(D.InMail, "the mail's count is read (Drop:InMail)")
	if D.InMail then
	check(D:InMail(2589, "Linen Cloth") == 1 and D:InMail(2592, "Wool Cloth") == 1 and D:InMail(2770, "Copper Ore") == 0, "the mail's count of an item, by link")
	local realLink = GetSendMailItemLink
	_G.GetSendMailItemLink = nil
	check(D:InMail(2589, "Linen Cloth") == 1 and D:InMail(2592, "Linen Cloth") == 1, "without links: by the item ID the game gives")
	local realGet = GetSendMailItem
	_G.GetSendMailItem = function(i) local a = mail[i]; if a then return a.name end end
	check(D:InMail(2589, "Linen Cloth") == 1 and D:InMail(1, "Wool Cloth") == 1 and D:InMail(2589, "Copper Ore") == 0, "with the name alone: by name")
	_G.GetSendMailItem, _G.GetSendMailItemLink = realGet, realLink
	end
	mail = {}
	-- ---- the mail closing stops it, as before
	MailFrame:Hide(); SendMailFrame:Hide(); M.fire("MAIL_CLOSED")
	check(D:Where() == nil, "the send form closed: no destination")

	-- ---- the trade is unchanged
	stock(); used = {}
	TradeFrame:Show(); M.fire("TRADE_SHOW")
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; trade[#trade + 1] = "Linen Cloth"; M.bags[bag][slot].locked = true end
	b = linenButton(); clearLog()
	b.scripts.OnMouseDown(b, "RightButton")
	check(D.tradeBaseline and D.tradeBaseline.where == "trade" and D.tradeBaseline.count == 0, "mouse-down in a trade notes the trade's count, marked as the trade's")
	trade[#trade + 1] = "Linen Cloth"; M.bags[b.rec.bag][b.rec.slot].locked = true
	b.scripts.OnClick(b, "RightButton")
	run()
	check(#used == 3 and #trade == 4 and not said():find("Moved", 1, true), "in a trade the other three stacks follow, as before (" .. #used .. " used)")
	TradeFrame:Hide(); M.fire("TRADE_CLOSED")
	-- mouse-down anywhere else notes nothing
	b.scripts.OnMouseDown(b, "RightButton")
	check(D.tradeBaseline == nil, "mouse-down away from the mail and the trade notes nothing")

	-- ---- the bank is unchanged: a stack that leaves its slot went
	stock(); used = {}
	n.atBank = true
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; M.bags[bag][slot] = nil end
	members = {}; for s = 1, 4 do members[#members + 1] = { bag = 0, slot = s } end
	M.bags[0][1] = nil; clearLog()
	D:MoveRest({ itemID = 2589, members = members, name = "Linen Cloth", first = { bag = 0, slot = 1 } })
	run()
	check(#used == 3 and not said():find("Moved", 1, true), "at the bank the rest follow as before (" .. #used .. " used)")
	n.atBank = false
	C_Container.UseContainerItem = realUse
	_G.BagSmithDB = nil
end)()
