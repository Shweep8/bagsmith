-- ======== 1.11.0-beta4 (Shweep, 27 Nov: "build") ========
-- 1.11's fourth beta: his beta3 check, and the wrap-up before the audit candidate.
--   1. The mailbox, again. beta3 in game: "at mailbox and leaving bags closing still, maybe not doable?" His /bs debug
--      lines and a call stack showed the game's hide function for the mailbox running twice, one inside the other:
--      hiding the mail window ends the visit from the window's own OnHide, which runs the hide function again, and
--      that inner run closes the bags (naming no window) before anything hooked onto the window's hide has been
--      told. The visit itself is the mark now: a close that names no window is the mailbox's when it comes during
--      the visit with the mail window no longer showing, or just after it.
--   2. Disenchant Results: "needs zebra lines or something". A faint band on every other line.
--   3. "Just now" and "this session" in the Disenchant Helper ("can we somehow explain both, especially for haul on
--      the all done"): its count line, its All done card and its chat line.
--   4. The version number in the Settings header ("Header is fine for 1.11, footer in 2.0").
--   5. 1.11's What's New card and NEW tags. 1.10.1's entry stays as history; the new card says where its switch went.

local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function win(name) return { GetName = function() return name end } end
local VENDOR, TRADE, AH, BANK = win("MerchantFrame"), win("TradeFrame"), win("AuctionHouseFrame"), win("BankFrame")

local function boot(opt)
	opt = opt or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 13 })
	local G = { shown = {}, opener = nil, size = { [0] = 16, 6, 6, 6, 6, 0 }, last = 5, combined = opt.combined, one = false }
	local function held(id) return G.combined and id <= 4 end
	local function isOpen(id) if held(id) then return G.one end return G.shown[id] and true or false end
	function G.anyOpen() for i = 0, G.last do if isOpen(i) then return true end end return false end
	local function closeBag(id) if held(id) then G.one = false else G.shown[id] = nil end end
	_G.CloseAllBags = function(frame)
		if frame and frame:GetName() ~= G.opener then return false end
		G.opener = nil
		for i = 0, G.last do closeBag(i) end
	end
	_G.OpenBag = function(id) if held(id) then G.one = true elseif (G.size[id] or 0) > 0 then G.shown[id] = true end end
	_G.ToggleBackpack_Combined = function() if G.one then G.one = false else OpenBackpack() end end
	_G.ToggleBag = function(id)
		if held(id) then return ToggleBackpack_Combined() end
		if (G.size[id] or 0) <= 0 then return end
		if G.shown[id] then if id == 0 then CloseAllBags() else G.shown[id] = nil end else G.shown[id] = true end
	end
	_G.ToggleBackpack = function()
		if G.combined then return ToggleBackpack_Combined() end
		if G.shown[0] then CloseAllBags() else ToggleBag(0) end
	end
	_G.OpenBackpack = function()
		if G.combined then return OpenBag(0) end
		if not G.shown[0] then ToggleBackpack() end
	end
	local function openAll() OpenBackpack(); for i = (G.combined and 5 or 1), G.last do OpenBag(i) end end
	_G.OpenAllBags = function(frame)
		if G.anyOpen() then return end
		if frame and not G.opener then G.opener = frame:GetName() end
		openAll()
	end
	_G.ToggleAllBags = function()
		local open, total = 0, 1
		if isOpen(0) then open = open + 1; closeBag(0) end
		for i = 1, G.last do
			if not held(i) then
				if (G.size[i] or 0) > 0 then total = total + 1 end
				if isOpen(i) then closeBag(i); open = open + 1 end
			end
		end
		if open < total then openAll() end
	end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = opt.profile or {} }, whatsNewSeen = "1.10.0" }
	_G.BagSmithWhatsNew = nil
	_G.GuildBankFrame, _G.MailFrame = nil, nil
	-- the game's mail window, there from the start unless the test says it loads later
	-- The mail window's own OnHide, set before BagSmith hooks the window: hiding it ends the visit, and the game's hide
	-- function runs again inside that and closes the bags naming no window (Shweep's /bs debug and call stack on
	-- Forever, 27 Nov). A hook added with HookScript only runs after this.
	if not opt.lateMail then
		G.mail = CreateFrame("Frame", "MailFrame", UIParent); G.mail:Hide()
		G.mail:SetScript("OnHide", function()
			if G.eventInside then M.fire("MAIL_CLOSED") end
			CloseAllBags()
		end)
	end
	local n = M.loadAddon("BagSmith"); n.version = "1.11.0-beta4"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	for _ = 1, 20 do M.runTimers() end
	if opt.lateMail then G.mail = CreateFrame("Frame", "MailFrame", UIParent); G.mail:Hide() end
	return M, n, G
end
local function frame(M) for _ = 1, 3 do M.runTimers() end end
local BAGS = { { true, "combined bags" }, { false, "separate bags" } }
local function debugSaid(M, from, what)
	for i = from, #M.log do if plain(M.log[i]):find(what, 1, true) then return true end end
	return false
end

local function arrive(M, G) frame(M); M.fire("MAIL_SHOW"); G.mail:Show(); OpenAllBags(G.mail) end
-- Leaving the mailbox as Forever does it. Walking away: the hide function hides the window (whose own OnHide closes
-- the bags inside that call), then closes the bags itself; MAIL_CLOSED is heard inside the hide or after it all.
local function walkAway(M, G, inside)
	frame(M)
	G.eventInside = inside
	G.mail:Hide(); CloseAllBags()
	if not inside then M.fire("MAIL_CLOSED") end
	frame(M)
end

------------------------------------------------------------------------
-- 1. When I Leave at the mailbox, with the hide function running inside itself
------------------------------------------------------------------------
for _, bags in ipairs(BAGS) do
	for _, inside in ipairs({ true, false }) do
		local S = ("%s, MAIL_CLOSED %s: "):format(bags[2], inside and "inside the hide" or "after it")
		-- Never Close (his report, twice now)
		local M, n, G = boot({ combined = bags[1], profile = { closeOnLeave = "never" } })
		n.db.debug = true
		frame(M); ToggleAllBags()
		arrive(M, G)
		check(n.Window:IsShown() and n.Hooks.MailOpen(), S .. "(set up: bags open, at the mailbox, the visit marked)")
		local from = #M.log + 1
		walkAway(M, G, inside)
		check(n.Window:IsShown(), S .. "Never Close: walking away from the mailbox leaves the bags open")
		check(debugSaid(M, from, "CloseAllBags (the mail window's) left open (When I Leave is Never Close)"), S .. "Never Close: /bs debug says it was the mailbox's close, left open")
		check(not debugSaid(M, from, "CloseAllBags acted"), S .. "Never Close: and no close was taken for Escape (his log's first line)")
		check(not n.Hooks.MailOpen() and not n.Hooks.MailLeaving(), S .. "the visit is over a moment later")
		CloseAllBags()
		check(not n.Window:IsShown(), S .. "Never Close: Escape closes them afterwards")
		-- at the open mailbox, Escape and the bag key are themselves: the mail window is still showing
		frame(M); ToggleAllBags(); arrive(M, G)
		frame(M); CloseAllBags()
		check(not n.Window:IsShown(), S .. "Never Close: Escape at the open mailbox closes the bags")
		frame(M); ToggleAllBags()
		check(n.Window:IsShown(), S .. "Never Close: the bag key opens them there")
		frame(M); ToggleAllBags()
		check(not n.Window:IsShown(), S .. "Never Close: and closes them")
		walkAway(M, G, inside)
		-- bags the mailbox opened, Never Close
		arrive(M, G)
		check(n.Window:IsShown() and n.Hooks.AutoOpened(), S .. "(set up: the mailbox opened the bags)")
		walkAway(M, G, inside)
		check(n.Window:IsShown() and not n.Hooks.AutoOpened(), S .. "Never Close: bags the mailbox opened stay open too, and are the player's from then")
		check((n.errors or 0) == 0, S .. "Never Close: no errors")
		-- Close If Auto-Opened
		M, n, G = boot({ combined = bags[1], profile = { closeOnLeave = "auto" } })
		frame(M); ToggleAllBags(); arrive(M, G); walkAway(M, G, inside)
		check(n.Window:IsShown(), S .. "Close If Auto-Opened: bags the player had open stay open")
		frame(M); ToggleAllBags(); arrive(M, G); walkAway(M, G, inside)
		check(not n.Window:IsShown(), S .. "Close If Auto-Opened: bags the mailbox opened close")
		-- Always Close
		M, n, G = boot({ combined = bags[1] })
		frame(M); ToggleAllBags(); arrive(M, G); walkAway(M, G, inside)
		check(not n.Window:IsShown(), S .. "Always Close: bags the player had open close")
		arrive(M, G); walkAway(M, G, inside)
		check(not n.Window:IsShown(), S .. "Always Close: bags the mailbox opened close")
		-- the mail window shut from its own X: it hides (and closes the bags inside), the rest follows a moment later
		M, n, G = boot({ combined = bags[1], profile = { closeOnLeave = "never" } })
		frame(M); ToggleAllBags(); arrive(M, G)
		frame(M); G.eventInside = false; G.mail:Hide()
		check(n.Window:IsShown(), S .. "Never Close: the mail window shut from its X leaves the bags open")
		M.fire("MAIL_CLOSED"); CloseAllBags(); frame(M)
		check(n.Window:IsShown(), S .. "and so does what follows it")
		check((n.errors or 0) == 0, S .. "no errors")
	end
end
do
	-- Blizzard's bags on the bag key: BagSmith marks nothing and follows none of it
	local M, n, G = boot({ profile = { closeOnLeave = "never", replaceBlizzardBags = false } })
	n.Window:Show(); arrive(M, G)
	check(not n.Hooks.MailOpen(), "with Open with the Bag Keybind off, a mailbox visit isn't marked")
	walkAway(M, G, true)
	check(n.Window:IsShown(), "and BagSmith's window is left alone")
end

------------------------------------------------------------------------
-- 2. Disenchant Results: a band on every other line. 3. "Just now" and "this session"
------------------------------------------------------------------------
local DEID = 13262
local MATNAMES = { [10940] = "Strange Dust", [11083] = "Soul Dust", [10938] = "Lesser Magic Essence", [10939] = "Greater Magic Essence", [10998] = "Lesser Astral Essence", [11082] = "Greater Astral Essence", [10978] = "Small Glimmering Shard", [11084] = "Large Glimmering Shard", [11138] = "Small Glowing Shard" }
local function deBoot(opt)
	opt = opt or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 452, ilvl = 23, equip = "INVTYPE_FEET" })
	M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
	M.put(0, 3, { id = 7003, name = "Ring of the Deep", q = 3, count = 1, class = 4, subclass = 0, price = 2500, ilvl = 24, equip = "INVTYPE_FINGER", bound = true })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = opt.skin or "modern", deEnabled = true } }, whatsNewSeen = "1.10.0", deShared = opt.deShared }
	_G.BagSmithWhatsNew = nil
	_G.GuildBankFrame, _G.MailFrame = nil, nil
	_G.IsSpellKnown = function(id) return id == DEID end
	_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
	_G.RegisterStateDriver = function() end
	_G.GetMoneyString = function(c) return ("%dg %ds %dc"):format(math.floor(c / 10000), math.floor(c / 100) % 100, c % 100) end
	-- the game's own loot lines
	_G.LOOT_ITEM_SELF = "You receive loot: %s."; _G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
	_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."; _G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(link) local id = tonumber(tostring(link):match("item:(%d+)")) or link; if MATNAMES[id] then return MATNAMES[id], nil, id == 10978 and 3 or 1 end return realInfo(link) end
	local prices = opt.prices or { [7001] = 1500, [7002] = 600, [10940] = 120, [10938] = 300, [10939] = 500, [10998] = 400, [11083] = 150, [11082] = 900, [10978] = 800, [11084] = 2000, [11138] = 1200 }
	if opt.noAH then _G.Auctionator = nil else
		_G.Auctionator = { API = { v1 = {
			GetAuctionPriceByItemLink = function(_, link) local id = tonumber(link:match("item:(%d+)")); return id and prices[id] end,
			GetAuctionPriceByItemID = function(_, id) return prices[id] end,
			GetAuctionAgeByItemLink = function() return nil end,
		} } }
	end
	local n = M.loadAddon("BagSmith"); n.version = "1.11.0-beta4"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	for _ = 1, 10 do M.runTimers() end
	local DE = n.Disenchant
	DE:Show(); M.runTimers()
	return M, n, DE, prices
end
local function entryOf(DE, id) for _, e in ipairs(DE.entries or {}) do if e.itemID == id then return e end end end
-- One disenchant as the game runs it: the click, the cast succeeding, the loot lines, the item leaving its slot.
local function disenchant(M, DE, id, loot)
	local e = entryOf(DE, id)
	DE:Select(e)
	local b = DE:Button()
	b:GetScript("PreClick")(b)
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", DEID)
	for _, l in ipairs(loot) do
		M.fire("CHAT_MSG_LOOT", ("You receive loot: |cffffffff|Hitem:%d:0:0:0:0:0:0:0|h[mat]|h|r%s."):format(l[1], l[2] > 1 and ("x" .. l[2]) or ""))
	end
	M.bags[e.bag][e.slot] = nil; M.fire("BAG_UPDATE_DELAYED"); M.fire("LOOT_CLOSED"); M.runTimers(); M.runTimers(); M.runTimers()
	return e
end
local function linesOf(DE)
	local t = {}
	for _, r in ipairs(DE.frame.results.rows) do if r:IsShown() then t[#t + 1] = { plain(r.left.text), plain(r.right.text), r.kind, r.id } end end
	return t
end
local function lineFor(DE, left) for _, l in ipairs(linesOf(DE)) do if l[1] == left then return l end end end

local function linesOf(DE)
	local t = {}
	for _, r in ipairs(DE.frame.results.rows) do if r:IsShown() then t[#t + 1] = { plain(r.left.text), plain(r.right.text), r.kind, r.stripe:IsShown() } end end
	return t
end
local function lastChat(M, what) for i = #M.log, 1, -1 do if plain(M.log[i]):find(what, 1, true) then return plain(M.log[i]) end end end
do
	local M, n, DE, prices = deBoot()
	local f = DE.frame
	local boots, dagger, ring = entryOf(DE, 7001), entryOf(DE, 7002), entryOf(DE, 7003)
	local bootsMat, daggerMat, ringMat = DE:Expectation(boots.rec)[1][1], DE:Expectation(dagger.rec)[1][1], DE:Expectation(ring.rec)[1][1]
	-- the first sitting of the session: one count, said once
	disenchant(M, DE, 7001, { { bootsMat, 2 } })
	check(f.status:IsShown() and f.status.text:find("1 disenchanted this session.", 1, true) and not f.status.text:find("just now", 1, true), "the first sitting: \"1 disenchanted this session.\": " .. tostring(f.status.text))
	local just, sess = DE:JustNow()
	check(just == 1 and sess == 1, "(just now 1, this session 1)")
	disenchant(M, DE, 7002, { { daggerMat, 3 } })
	disenchant(M, DE, 7003, { { ringMat, 1 } })
	check(f.empty:IsShown() and f.empty.count.text == "3 items disenchanted" and not f.empty.session:IsShown() and not f.empty.results:IsShown(), "its All done card: \"3 items disenchanted\", as before, with no second line")
	DE:Close(); M.runTimers()
	local said = lastChat(M, "Disenchant Helper:")
	check(said and said:find("3 items disenchanted: ", 1, true) and not said:find("just now", 1, true) and not said:find("This session", 1, true), "its chat line on closing, as before: " .. tostring(said))
	-- the bands, on what was just disenchanted
	DE:Show(); M.runTimers()
	DE:ShowResults(true)
	local L = linesOf(DE)
	local okBands, seenHead, lastBand = true, false, nil
	local banded, plainRows = 0, 0
	for _, l in ipairs(L) do
		if l[3] == "head" then
			if l[4] then okBands = false end
			seenHead, lastBand = true, nil
		elseif l[3] == "row" then
			if lastBand == nil then if l[4] then okBands = false end      -- the first line under a heading is plain
			elseif l[4] == lastBand then okBands = false end             -- then every other one is banded
			lastBand = l[4]
			if l[4] then banded = banded + 1 else plainRows = plainRows + 1 end
		else
			if l[4] then okBands = false end
			lastBand = nil
		end
	end
	check(okBands and seenHead and banded >= 3 and plainRows >= 4, ("Results: every other line under a heading is banded, starting plain; headings and notes never (%d banded, %d plain)"):format(banded, plainRows))
	local stripe = f.results.rows[1].stripe
	check(stripe and select(4, stripe:GetVertexColor()) == 0.035, "the band is faint, the strength the Settings lists use")
	DE:SetResultsTab("all")
	L = linesOf(DE)
	local any = false
	for _, l in ipairs(L) do if l[4] then any = true end end
	check(any, "All Time is banded the same")
	DE:SetResultsTab("session"); DE:ShowResults(false)
	-- a second sitting: nothing done yet, the session's count stands
	M.put(0, 5, { id = 7005, name = "Plain Vest", q = 2, count = 1, class = 4, subclass = 1, price = 300, ilvl = 22, equip = "INVTYPE_CHEST" })
	M.put(0, 6, { id = 7006, name = "Plain Belt", q = 2, count = 1, class = 4, subclass = 1, price = 200, ilvl = 22, equip = "INVTYPE_WAIST" })
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers(); DE:Refresh()
	just, sess = DE:JustNow()
	check(just == 0 and sess == 3 and f.status.text:find("3 disenchanted this session.", 1, true) and not f.status.text:find("just now", 1, true), "opened again, nothing done yet: \"3 disenchanted this session.\": " .. tostring(f.status.text))
	local vest, belt = entryOf(DE, 7005), entryOf(DE, 7006)
	check(vest and belt, "(set up: two more pieces to disenchant)")
	local vestMat, beltMat = DE:Expectation(vest.rec)[1][1], DE:Expectation(belt.rec)[1][1]
	disenchant(M, DE, 7005, { { vestMat, 2 } })
	check(f.status.text:find("1 disenchanted just now, 4 this session.", 1, true), "one more: \"1 disenchanted just now, 4 this session.\": " .. tostring(f.status.text))
	disenchant(M, DE, 7006, { { beltMat, 1 } })
	-- the All done card explains both
	local total = prices[bootsMat] * 2 + prices[daggerMat] * 3 + prices[ringMat] + prices[vestMat] * 2 + prices[beltMat]
	check(f.empty:IsShown() and f.empty.count.text == "Just now: 2 items disenchanted", "the All done card: \"Just now: 2 items disenchanted\": " .. tostring(f.empty.count.text))
	check(f.empty.haul.text ~= "" and f.empty.value.text == ("Worth about %s at current AH prices"):format(DE.Money(prices[vestMat] * 2 + prices[beltMat])), "with the haul of just now and its worth, as before")
	check(f.empty.session:IsShown() and f.empty.session.text == ("This session: 5 items disenchanted, worth about %s."):format(DE.Money(total)), "and under it what the session comes to: " .. tostring(f.empty.session.text))
	check(f.empty.results:IsShown() and f.empty.results.label.text == "See Results" and f.empty.session.points[1][2] == f.empty.value and f.empty.results.points[1][2] == f.empty.session and f.empty.line.points[1][2] == f.empty.results,
		"with See Results under that, and what was set aside below them")
	f.empty.results:GetScript("OnClick")(f.empty.results)
	check(f.results:IsShown() and DE:Results("session").n == 5, "See Results opens Results, whose This Session has the five")
	DE:ShowResults(false)
	DE:Close(); M.runTimers()
	said = lastChat(M, "Disenchant Helper:")
	check(said and said:find("2 items disenchanted just now: ", 1, true) and said:find(" This session: 5 items.", 1, true), "the chat line on closing says both: " .. tostring(said))
	check(not (f.empty.session.text .. said):find("\226\128\148"), "no dashes")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- a material with no price: the session's line gives the count and no worth
	local M, n, DE = deBoot({ prices = { [7001] = 1500, [10940] = 120 } })
	local f = DE.frame
	local list = DE:Expectation(entryOf(DE, 7001).rec)
	disenchant(M, DE, 7001, { { list[1][1], 2 }, { list[2][1], 1 } })
	DE:Close(); M.runTimers(); DE:Show(); M.runTimers()
	local id = entryOf(DE, 7002).itemID
	disenchant(M, DE, 7002, { { DE:Expectation(entryOf(DE, 7002).rec)[1][1], 1 } })
	disenchant(M, DE, 7003, { { DE:Expectation(entryOf(DE, 7003).rec)[1][1], 1 } })
	check(f.empty:IsShown() and f.empty.session:IsShown() and f.empty.session.text == "This session: 3 items disenchanted.", "with a price missing the session's line says how many, and no worth: " .. tostring(f.empty.session.text))
	check((n.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- 4. The version number in the Settings header. 5. 1.11's NEW tags and What's New card
------------------------------------------------------------------------
for _, skin in ipairs({ "modern", "classic" }) do
	local M, n = boot({ profile = { skin = skin } })
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("general"); M.runTimers()
	check(P.frame.sub:IsShown() and P.frame.sub.text == "1.11.0-beta4   Profile: Default", skin .. ": the header's muted line reads the version as the TOC has it, then the profile: " .. tostring(P.frame.sub.text))
	n.version = "1.11.0"; P:Refresh()
	check(P.frame.sub.text == "1.11.0   Profile: Default", skin .. ": a release shows its plain number")
	n.version = "1.11.0-beta4"
	check(P.frame.title.text == "BagSmith Settings" and (n.errors or 0) == 0, skin .. ": the title is as it was")
end
do
	local M, n = boot({ profile = {} })
	local P = n.SettingsPanel
	check(P.NEW.release == "1.11" and next(P.NEW.pages) == nil and next(P.NEW.added) == nil, "the NEW list is 1.11's: no new page, no point release yet")
	P:Show(); P:ShowPage("automation"); M.runTimers()
	check(P:IsNew("heads", "Auto-Open and Auto-Close") and P:IsNew("keys", "closeOnLeave") and P:NewPage("automation"), "someone coming from 1.10: Auto-Open and Auto-Close and When I Leave are NEW, and so is Automations in the list")
	local seg
	for _, w in ipairs(P.pools.seg or {}) do if w:IsShown() and w.key == "closeOnLeave" then seg = w end end
	check(seg and seg.newTag and seg.newTag:IsShown(), "When I Leave wears the tag")
	check(not P:IsNew("keys", "autoOpenVendor") and not P:IsNew("keys", "cleanOnOpen"), "the card's own switches and the page's older settings wear none")
	check(P:IsNew("keys", "bagKindPick") and P:NewPage("icons") and P:IsNew("buttons", "Sections on a Sheet...") and P:NewPage("custom"), "the Special Bag list and Sections on a Sheet... are NEW")
	check(not P:IsNew("keys", "useItemTree") and not P:NewPage("addons") and not P:IsNew("buttons", "New Section...") and not P:IsNew("keys", "autoCloseOwnBags"), "nothing of 1.10's list is")
	P:ShowPage("icons"); M.runTimers()
	local drop
	for _, w in ipairs(P.pools.dropdown or {}) do if w:IsShown() and w.key == "bagKindPick" then drop = w end end
	check(drop and drop.newTag and drop.newTag:IsShown(), "the Special Bag list wears the tag")
	P:ShowPage("custom"); M.runTimers()
	local btn
	for _, b in ipairs(P.pools.btn or {}) do if b:IsShown() and b.label.text == "Sections on a Sheet..." then btn = b end end
	check(btn and btn.newTag and btn.newTag:IsShown(), "and so does Sections on a Sheet...")
	-- opened once, they go from the next time Settings opens
	P:Hide(); P:Show(); P:ShowPage("automation"); M.runTimers()
	check(not P:IsNew("heads", "Auto-Open and Auto-Close") and not P:NewPage("automation"), "a page opened once shows none the next time Settings opens")
	-- a first install sees none
	M, n = boot({ profile = {} })
	P = n.SettingsPanel
	P:MarkAllNewSeen(); P:Show(); P:ShowPage("automation"); M.runTimers()
	check(not P:IsNew("heads", "Auto-Open and Auto-Close") and not P:IsNew("keys", "bagKindPick") and not P:IsNew("buttons", "Sections on a Sheet..."), "a first install sees no NEW tags")
	check((n.errors or 0) == 0, "no errors")
end
do
	local M, n = boot({ profile = {} })
	local WN = n.WhatsNew
	local e = WN.ENTRIES[1]
	check(e.v == "1.11.0" and e.heading == "BagSmith 1.11" and #e.items == 7 and not e.opens and not e.remind, "What's New opens with 1.11's card: seven bullets")
	local WANT = {
		"See What Your Disenchants Gave You: the Disenchant Helper has a new Results button. This Session and All Time show how many items you broke down, the materials you got and what they're worth at the auction house now, and whether selling the items would have paid more.",
		"Auto-Open Where You Want It: choose where your bags open by themselves (vendors, the mailbox, trades, the auction house, the bank and the guild bank) and what happens when you leave: Always Close, Close If Auto-Opened or Never Close. Find it in Settings > Automations.",
		"Auto-Close Bags I Opened Has Moved: that switch from 1.10.1 is now the When I Leave choice in Settings > Automations, and what you had carries over. Always Close now covers trades and the guild bank too.",
		"Gear Sets From Your Bags: make a new gear set any time from the Gear Sets tab, and rename or delete one from its menu, without a trip to Settings.",
		"Sections on a Sheet: pick a tab and tick the sections of yours that should show there, several at once. It's in Settings > Custom Sections and in each section's menu.",
		"More Ways to Start a Section: New Section From This Item now offers the kind of consumable, quest items, crafting materials and whether you can use it.",
		"Shorter Special Bag Settings: Special Bag Slot Indicators in Settings > Item Icons is one short list now. Pick a kind of bag, then set it up.",
	}
	for i, want in ipairs(WANT) do check(plain(e.items[i]) == want, ("bullet %d, word for word: %s"):format(i, plain(e.items[i] or ""))) end
	check(not table.concat(e.items, " "):find("\226\128\148"), "no dashes")
	-- 1.10.1's entry stays as it was written (Shweep: "Leave as history")
	local old = WN.ENTRIES[2]
	check(old.v == "1.10.1" and plain(old.items[2]) == "Auto-Close Bags I Opened: a new switch in Settings > General. Turn it off and bags you opened yourself stay open when you leave a vendor or the mailbox.", "1.10.1's entry is left as history, under it")
	-- coming from 1.10.1 (the seed's whatsNewSeen is 1.10.0, with 1.10.1 an update under it), 1.11 is a release to show
	check(WN:Pending() and #WN:UnseenReleases() >= 1 and WN:UnseenReleases()[1].v == "1.11.0", "someone updating has 1.11's card waiting")
	check((n.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- 6. The changelog, the README and the version
------------------------------------------------------------------------
do
	local function slurp(p) local f = assert(io.open(p, "r")); local s = f:read("*a"); f:close(); return s end
	local top = slurp("BagSmith/CHANGELOG.md"):match("^## 1%.11%.0\n(.-)\n## 1%.10%.1\n")
	check(top and top:find("The Helper's own count now says how many you disenchanted just now and how many this session%.") and top:find("\n%- Settings shows BagSmith's version number beside its title%."), "the changelog's 1.11.0 has the Helper's two counts and the version in Settings")
	check(top and top:find("\nFixed:\n%- Leaving the mailbox closed bags you had opened yourself") and not top:find("\226\128\148"), "its mailbox fix stands, and no dashes")
	check(slurp("README.md"):find("a Disenchant Helper for enchanters with Results for what your disenchants\n  gave you", 1, true), "the README's Helpers line names Results")
	check(slurp("BagSmith/BagSmith.toc"):find("## Version: 1%.11%.0"), "the TOC version is 1.11.0's (the exact one is pinned in tests/run.lua)")
end
