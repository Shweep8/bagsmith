-- ======== 1.11.0-beta2 (Shweep, 25 Nov: "ready for beta 2 now") ========
-- 1.11's second beta, as scoped with him on 24 Nov:
--   1. Auto-Open and Auto-Close (Settings > Automations). His idea after 1.10.1: "wouldn't it make more sense for the
--      setting to be something more like auto open with, and then list out all the places that BagSmith auto opens
--      when you go to and default them all to true"; then "The lighter version is good": a switch for each place
--      (vendors, the mailbox, trades, the auction house, the bank, the guild bank), all on, and one choice for what
--      leaving does (Always Close, Close If Auto-Opened, Never Close), which takes over from 1.10.1's Auto-Close Bags
--      I Opened. "Yeah automations is fine for that."
--   2. Sections on a Sheet: several of your sections set to a sheet at once, from the sheet's side.
--
-- The game's bag functions are modelled as in the 1.10.1 sets (both bag settings): what each call opens and closes,
-- which calls it makes, and the window the game remembers as the one that opened the bags.

local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function win(name) return { GetName = function() return name end } end
local VENDOR, MAIL, TRADE, AH, AHOLD, BANK, OTHER = win("MerchantFrame"), win("MailFrame"), win("TradeFrame"), win("AuctionHouseFrame"), win("AuctionFrame"), win("BankFrame"), win("SomeOtherFrame")

local function boot(opt)
	opt = opt or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 13 })
	M.put(0, 2, { id = 2447, name = "Peacebloom", q = 1, count = 5, class = 7, subclass = 9, type = "Trade Goods", sub = "Herb", price = 10 })
	M.put(0, 3, { id = 2318, name = "Light Leather", q = 1, count = 5, class = 7, subclass = 6, type = "Trade Goods", sub = "Leather", price = 10 })
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
	_G.GuildBankFrame = nil
	local n = M.loadAddon("BagSmith"); n.version = "1.11.0-beta2"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	for _ = 1, 20 do M.runTimers() end
	return M, n, G
end
local function frame(M) for _ = 1, 3 do M.runTimers() end end
local ORDERS = { "BagSmith first", "the game first" }
local BAGS = { { true, "combined bags" }, { false, "separate bags" } }
local function opens(M, order, show, w)
	frame(M)
	if order == "BagSmith first" then M.fire(show); OpenAllBags(w) else OpenAllBags(w); M.fire(show) end
end
local function closes(M, order, hide, w)
	frame(M)
	if order == "BagSmith first" then M.fire(hide); CloseAllBags(w) else CloseAllBags(w); M.fire(hide) end
	frame(M)
end
local function debugSaid(M, from, what)
	for i = from, #M.log do if plain(M.log[i]):find(what, 1, true) then return true end end
	return false
end
local EVENT_PLACES = {
	{ "autoOpenVendor", "MERCHANT_SHOW", "MERCHANT_CLOSED", VENDOR, "a vendor" },
	{ "autoOpenMail", "MAIL_SHOW", "MAIL_CLOSED", MAIL, "the mailbox" },
	{ "autoOpenTrade", "TRADE_SHOW", "TRADE_CLOSED", TRADE, "a trade" },
	{ "autoOpenAH", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", AH, "the auction house" },
}

------------------------------------------------------------------------
-- 1. The settings, and what a profile from 1.10.1 becomes
------------------------------------------------------------------------
do
	local M, n = boot()
	for _, k in ipairs({ "autoOpenVendor", "autoOpenMail", "autoOpenTrade", "autoOpenAH", "autoOpenBank", "autoOpenGuildBank" }) do
		check(n.db[k] == true, k .. " is on by default")
	end
	check(n.db.closeOnLeave == "always", "When I Leave is Always Close by default, as BagSmith has always worked")
	check(n.db.autoCloseOwnBags == nil and BagSmithDB.profiles.Default.autoCloseOwnBags == nil, "1.10.1's switch is no longer a setting of its own")
	check(n:Set("closeOnLeave", "never") and n.db.closeOnLeave == "never" and not n:Set("closeOnLeave", "sometimes") and n.db.closeOnLeave == "never", "the choice takes always, auto or never, and nothing else")
	local H = n.Hooks
	check(H.PlaceOf(VENDOR) == "vendor" and H.PlaceOf(MAIL) == "mail" and H.PlaceOf(TRADE) == "trade" and H.PlaceOf(AH) == "ah" and H.PlaceOf(AHOLD) == "ah"
		and H.PlaceOf(BANK) == "bank" and H.PlaceOf(win("GuildBankFrame")) == "guildbank", "the game's windows are known by name")
	check(H.PlaceOf(OTHER) == nil and H.PlaceOf(nil) == nil and H.PlaceOf({}) == nil and H.OpensAt(nil) == true, "any other window is none of them, and is followed as before")
end
do
	local M, n = boot({ profile = { autoCloseOwnBags = false } })
	check(n.db.closeOnLeave == "auto" and BagSmithDB.profiles.Default.autoCloseOwnBags == nil, "a profile with Auto-Close Bags I Opened unticked (1.10.1): Close If Auto-Opened")
	M, n = boot({ profile = { autoCloseOwnBags = true } })
	check(n.db.closeOnLeave == "always" and BagSmithDB.profiles.Default.autoCloseOwnBags == nil, "ticked: Always Close")
	M, n = boot({ profile = { autoCloseOwnBags = false, closeOnLeave = "never" } })
	check(n.db.closeOnLeave == "never", "a choice already made stands")
	M, n = boot({ profile = { closeOnLeave = "whenever", autoOpenVendor = "yes" } })
	check(n.db.closeOnLeave == "always" and n.db.autoOpenVendor == true, "nonsense in the saved data falls back to the defaults")
end

------------------------------------------------------------------------
-- 2. Auto-Open off for a place: the bags stay shut there, and open everywhere else
------------------------------------------------------------------------
for _, bags in ipairs(BAGS) do
	for _, order in ipairs(ORDERS) do
		for _, p in ipairs(EVENT_PLACES) do
			local S = ("%s, %s, Auto-Open off at %s: "):format(bags[2], order, p[5])
			local M, n, G = boot({ combined = bags[1], profile = { [p[1]] = false } })
			n.db.debug = true
			local from = #M.log + 1
			opens(M, order, p[2], p[4])
			check(not n.Window:IsShown(), S .. "the bags stay shut")
			check(G.anyOpen(), S .. "(the game opened its own, as it does)")
			check(debugSaid(M, from, "(Auto-Open is off for this window)"), S .. "/bs debug says why")
			closes(M, order, p[3], p[4])
			check(not n.Window:IsShown() and not G.anyOpen(), S .. "and nothing is left open on leaving")
			-- the bag key is as it was
			frame(M); ToggleAllBags(); check(n.Window:IsShown(), S .. "the bag key opens them")
			frame(M); ToggleAllBags(); check(not n.Window:IsShown(), S .. "and closes them")
			-- every other place still opens
			for _, q in ipairs(EVENT_PLACES) do
				if q[1] ~= p[1] then
					opens(M, order, q[2], q[4])
					check(n.Window:IsShown(), S .. "the bags still open at " .. q[5])
					closes(M, order, q[3], q[4])
					check(not n.Window:IsShown(), S .. "and close on leaving " .. q[5])
				end
			end
			check((n.errors or 0) == 0, S .. "no errors")
		end
	end
end
for _, bags in ipairs(BAGS) do
	for _, order in ipairs(ORDERS) do
		local S = ("%s, %s, Auto-Open off at vendors: "):format(bags[2], order)
		-- bags the player has open are left alone
		local M, n, G = boot({ combined = bags[1], profile = { autoOpenVendor = false } })
		frame(M); ToggleAllBags()
		check(n.Window:IsShown(), S .. "(set up: the player opens the bags with the key)")
		opens(M, order, "MERCHANT_SHOW", VENDOR)
		check(n.Window:IsShown() and not n.Hooks.AutoOpened(), S .. "bags already open stay open at the vendor, and are the player's")
		closes(M, order, "MERCHANT_CLOSED", VENDOR)
		check(not n.Window:IsShown(), S .. "and leaving closes them (When I Leave: Always Close)")
		-- opened from BagSmith's own button, so the game counts its own bags as shut
		M, n, G = boot({ combined = bags[1], profile = { autoOpenVendor = false } })
		frame(M); n.Window:Show()
		opens(M, order, "MERCHANT_SHOW", VENDOR)
		check(n.Window:IsShown() and not n.Hooks.AutoOpened(), S .. "bags opened from BagSmith's own button stay open too, whatever the game's toggle did")
		-- the old auction house window's name counts as the auction house
		M, n, G = boot({ combined = bags[1], profile = { autoOpenAH = false } })
		opens(M, order, "AUCTION_HOUSE_SHOW", AHOLD)
		check(not n.Window:IsShown(), S:gsub("vendors", "the auction house") .. "the older auction house window is the auction house too")
	end
end
for _, bags in ipairs(BAGS) do
	for _, order in ipairs(ORDERS) do
		local S = ("%s, %s: "):format(bags[2], order)
		-- the bank
		local M, n, G = boot({ combined = bags[1], profile = { autoOpenBank = false } })
		opens(M, order, "BANKFRAME_OPENED", BANK)
		check(not n.Window:IsShown(), S .. "Auto-Open off at the bank: the bags stay shut")
		check(not n.Bank.supported or n.Window.bank:IsShown(), S .. "and the bank's own window still opens")
		closes(M, order, "BANKFRAME_CLOSED", BANK)
		check(not n.Window:IsShown(), S .. "nothing is left open after the bank")
		frame(M); ToggleAllBags()
		opens(M, order, "BANKFRAME_OPENED", BANK)
		check(n.Window:IsShown() and not n.Hooks.AutoOpened(), S .. "bags the player has open stay open at the bank")
		-- on, as before
		M, n, G = boot({ combined = bags[1] })
		opens(M, order, "BANKFRAME_OPENED", BANK)
		check(n.Window:IsShown() and n.Hooks.AutoOpened(), S .. "Auto-Open on at the bank: the bags open, as before")
		-- a window that isn't one of the listed places is followed as it always was
		M, n, G = boot({ combined = bags[1], profile = { autoOpenVendor = false, autoOpenMail = false, autoOpenTrade = false, autoOpenAH = false, autoOpenBank = false, autoOpenGuildBank = false } })
		frame(M); OpenAllBags(OTHER)
		check(n.Window:IsShown(), S .. "with every switch off, another of the game's windows asking for the bags still gets them")
		frame(M); CloseAllBags(OTHER); frame(M)
		check(not n.Window:IsShown(), S .. "and they close with it")
	end
end
do
	-- the guild bank
	local M, n, G = boot({ profile = { autoOpenGuildBank = false } })
	local gb = CreateFrame("Frame", "GuildBankFrame", UIParent); gb:Hide()
	M.fire("ADDON_LOADED", "Blizzard_GuildBankUI")
	frame(M); gb:Show(); frame(M)
	check(not n.Window:IsShown(), "Auto-Open off at the guild bank: the bags stay shut")
	gb:Hide(); frame(M)
	n:Set("autoOpenGuildBank", true)
	frame(M); gb:Show(); frame(M)
	check(n.Window:IsShown(), "on again: they open, with no reload")
	gb:Hide(); frame(M)
	check(not n.Window:IsShown(), "and close with it")
	_G.GuildBankFrame = nil
end

------------------------------------------------------------------------
-- 3. When I Leave
------------------------------------------------------------------------
for _, bags in ipairs(BAGS) do
	for _, order in ipairs(ORDERS) do
		local S = ("%s, %s, "):format(bags[2], order)
		-- Never Close
		local M, n, G = boot({ combined = bags[1], profile = { closeOnLeave = "never" } })
		n.db.debug = true
		opens(M, order, "MERCHANT_SHOW", VENDOR)
		check(n.Window:IsShown() and n.Hooks.AutoOpened(), S .. "Never Close: (set up: a vendor opened the bags)")
		local from = #M.log + 1
		closes(M, order, "MERCHANT_CLOSED", VENDOR)
		check(n.Window:IsShown(), S .. "Never Close: leaving the vendor leaves them open")
		check(not n.Hooks.AutoOpened(), S .. "Never Close: and from then on they are the player's")
		check(debugSaid(M, from, "left open (When I Leave is Never Close)"), S .. "Never Close: /bs debug says why")
		frame(M); ToggleAllBags()
		check(not n.Window:IsShown(), S .. "Never Close: the bag key still closes them")
		opens(M, order, "MAIL_SHOW", MAIL); frame(M); CloseAllBags()
		check(not n.Window:IsShown(), S .. "Never Close: so does Escape")
		closes(M, order, "MAIL_CLOSED", MAIL)
		opens(M, order, "BANKFRAME_OPENED", BANK)
		closes(M, order, "BANKFRAME_CLOSED", BANK)
		check(n.Window:IsShown(), S .. "Never Close: they stay open after the bank too")
		n.Window:Hide()
		-- Close If Auto-Opened (1.10.1's switch, unticked)
		M, n, G = boot({ combined = bags[1], profile = { closeOnLeave = "auto" } })
		opens(M, order, "MERCHANT_SHOW", VENDOR)
		closes(M, order, "MERCHANT_CLOSED", VENDOR)
		check(not n.Window:IsShown(), S .. "Close If Auto-Opened: bags the vendor opened close on leaving")
		frame(M); ToggleAllBags()
		opens(M, order, "MERCHANT_SHOW", VENDOR)
		closes(M, order, "MERCHANT_CLOSED", VENDOR)
		check(n.Window:IsShown(), S .. "Close If Auto-Opened: bags the player had open stay open")
		-- Always Close
		M, n, G = boot({ combined = bags[1] })
		frame(M); ToggleAllBags()
		opens(M, order, "MERCHANT_SHOW", VENDOR)
		closes(M, order, "MERCHANT_CLOSED", VENDOR)
		check(not n.Window:IsShown(), S .. "Always Close: bags the player had open close on leaving, as ever")
		check((n.errors or 0) == 0, S .. "no errors")
	end
end
do
	-- the guild bank follows the choice
	local M, n, G = boot({ profile = { closeOnLeave = "never" } })
	local gb = CreateFrame("Frame", "GuildBankFrame", UIParent); gb:Hide()
	M.fire("ADDON_LOADED", "Blizzard_GuildBankUI")
	frame(M); gb:Show(); frame(M); gb:Hide(); frame(M)
	check(n.Window:IsShown(), "Never Close: the bags stay open after the guild bank")
	_G.GuildBankFrame = nil
end

------------------------------------------------------------------------
-- 4. The card on Settings > Automations
------------------------------------------------------------------------
do
	local M, n = boot()
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("automation"); M.runTimers()
	local function row(key) for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.key == key then return w end end end
	local function seg(key) for _, w in ipairs(P.pools.seg or {}) do if w:IsShown() and w.key == key then return w end end end
	local function top(w) return select(5, w:GetPoint(1)) or select(3, w:GetPoint(1)) end
	local heads = {}
	for _, w in ipairs(P.pools.head or {}) do if w:IsShown() then heads[#heads + 1] = { plain(w.text and w.text.text or (w.label and w.label.text) or ""), top(w) } end end
	table.sort(heads, function(a, b) return a[2] > b[2] end)
	local order = {}
	for i, h in ipairs(heads) do order[i] = h[1] end
	local joined = table.concat(order, " | ")
	check(joined:find("Auto-Open and Auto-Close | Auto Travel Mode", 1, true), "the page has Auto-Open and Auto-Close, just above Auto Travel Mode: " .. joined)
	local WANT = { { "autoOpenVendor", "Auto-Open at Vendors" }, { "autoOpenMail", "Auto-Open at the Mailbox" }, { "autoOpenTrade", "Auto-Open When Trading" },
		{ "autoOpenAH", "Auto-Open at the Auction House" }, { "autoOpenBank", "Auto-Open at the Bank" }, { "autoOpenGuildBank", "Auto-Open at the Guild Bank" } }
	local last
	for _, w in ipairs(WANT) do
		local r = row(w[1])
		check(r and r.text.text == w[2] and r.box:GetChecked() == true and r.box:IsEnabled(), w[2] .. ": there, ticked, usable")
		check(r and (not last or top(last) > top(r)), w[2] .. ": in order")
		last = r
	end
	local s = seg("closeOnLeave")
	check(s and s.text.text == "When I Leave" and top(last) > top(s), "under them, When I Leave")
	local labels, active = {}, nil
	for _, b in ipairs(s.btns) do if b:IsShown() then labels[#labels + 1] = b.label.text; if b.active then active = b.label.text end end end
	check(table.concat(labels, " | ") == "Always Close | Close If Auto-Opened | Never Close", "its three choices: " .. table.concat(labels, " | "))
	check(s.help.text == "Always Close closes your bags when you leave, even if you already had them open. Close If Auto-Opened leaves bags you already had open. Never Close leaves them all open.",
		"its help, word for word: " .. tostring(s.help.text))
	check(not (s.help.text .. table.concat(labels)):find("\226\128\148"), "no dashes")
	check(n.db.closeOnLeave == "always", "(Always Close is the one in use)")
	for _, b in ipairs(s.btns) do if b.label.text == "Never Close" then b:GetScript("OnClick")(b) end end
	check(n.db.closeOnLeave == "never" and BagSmithDB.profiles.Default.closeOnLeave == "never", "clicking Never Close sets it, in the profile")
	local r = row("autoOpenMail")
	r.box:SetChecked(false); r.box:GetScript("OnClick")(r.box)
	check(n.db.autoOpenMail == false and n.db.autoOpenVendor == true, "unticking the mailbox turns that one off and no other")
	-- with Blizzard's bags on the bag key, BagSmith opens for none of them but the bank
	n:Set("replaceBlizzardBags", false); M.runTimers()
	for _, w in ipairs(WANT) do
		local rr = row(w[1])
		if w[1] == "autoOpenBank" then check(rr.box:IsEnabled(), "with Open with the Bag Keybind off, the bank's switch stays usable (the bank opens BagSmith's bags either way)")
		else check(not rr.box:IsEnabled() and rr.box:GetChecked() == (n.db[w[1]] and true or false), w[2] .. ": greyed then, showing what it is set to") end
	end
	n:Set("replaceBlizzardBags", true); M.runTimers()
	check(row("autoOpenVendor").box:IsEnabled(), "and usable again with it on")
	-- General no longer has 1.10.1's switch
	P:ShowPage("general"); M.runTimers()
	check(row("autoCloseOwnBags") == nil and row("replaceBlizzardBags") ~= nil, "General no longer has Auto-Close Bags I Opened")
	check((n.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- 5. Sections on a Sheet
------------------------------------------------------------------------
do
	local M, n = boot()
	local S, R = n.Sections, n.Rules
	local function recOf(id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
	local cloth = S:CreateWithRules("Cloth", { mode = "all", rows = { { k = "type", v = { "7:5" } } } })
	local herbs = S:CreateWithRules("Herbs", { mode = "all", rows = { { k = "type", v = { "7:9" } } } })
	local leather = S:CreateWithRules("Leather", { mode = "all", rows = { { k = "type", v = { "7:6" } } } })
	check(cloth and herbs and leather, "(set up: three sections of the player's own, by rule)")
	-- the setting, from the sheet's side
	check(S:SheetNote(cloth, "TradeGoods") == "every sheet" and not S:SetToSheet(cloth, "TradeGoods"), "a section with no sheets set shows on every sheet")
	check(S:SetOnSheet(cloth, "TradeGoods", true) and S:SetToSheet(cloth, "TradeGoods") and S:SheetNote(cloth, "TradeGoods") == "only here", "set to a sheet: it shows there only")
	check(S:SheetNote(cloth, "Gear") == "only on Trade Goods", "from another sheet: \"only on Trade Goods\"")
	check(S:SetOnSheet(cloth, "Gear", true) and S:SheetNote(cloth, "TradeGoods") == "here and Gear" and S:SheetNote(cloth, "Bank") == "only on Trade Goods and Gear", "a second sheet: \"here and Gear\"")
	check(S:SetOnSheet(cloth, "Gear", false) and S:SheetNote(cloth, "TradeGoods") == "only here", "taken off one: only the other")
	check(S:SetOnSheet(cloth, "TradeGoods", false) and S:Sheets(cloth) == nil and S:SheetNote(cloth, "TradeGoods") == "every sheet", "taken off its last sheet: every sheet again")
	check(S:SetOnSheet(cloth, "TradeGoods", false) and S:Sheets(cloth) == nil, "taking off what isn't on changes nothing")
	local many = {}
	for i = 1, 24 do many[i] = "Sheet " .. i end
	S:SetSheets(herbs, many)
	-- (by design since 1.11.0-beta5, the beta4 audit's B4-1: a section is only put on a sheet there is, so the 25th
	-- here is one of BagSmith's own tabs; it was "One More", a name that is no sheet)
	local ok, why = S:SetOnSheet(herbs, "Gear", true)
	check(ok == false and why == "A section can be set to 24 sheets at most." and #S:Sheets(herbs) == 24, "a 25th sheet is refused, with why: " .. tostring(why))
	S:SetSheets(herbs, nil)
	check(S:SetOnSheet("nope", "TradeGoods", true) == false and S:SetOnSheet(cloth, "", true) == false, "no such section, or no sheet: refused")

	-- the window, from the tab the bags are on
	n.Window:Show(); for _ = 1, 10 do M.runTimers() end
	n.Window.main:SetSheet("TradeGoods"); for _ = 1, 5 do M.runTimers() end
	local f = S:OpenSheetSections()
	check(f:IsShown() and f.sheet == "TradeGoods" and f.pick.label.text == "Trade Goods", "Sections on a Sheet opens on the tab the bags are on: " .. tostring(f.pick.label.text))
	check(f.title.text == "Sections on a Sheet" and f.intro.text == "Tick the sections that should show on this sheet only. A section you leave unticked keeps showing where it does now.", "its title and its one line of help")
	local function rows() local t = {}; for _, r in ipairs(f.rows) do if r:IsShown() then t[#t + 1] = r end end return t end
	local function rowOf(name) for _, r in ipairs(rows()) do if r.name.text == name then return r end end end
	check(#rows() == 3 and rowOf("Cloth") and rowOf("Herbs") and rowOf("Leather"), "it lists the player's three sections")
	check(rowOf("Cloth").check:GetChecked() == false and rowOf("Cloth").note.text == "every sheet", "each unticked, \"every sheet\"")
	check(not f.empty:IsShown() and not f.scroll.ScrollBar:IsShown(), "(no empty note, no scroll bar for three)")
	-- tick three, one after the other, without closing: that is the point
	for _, name in ipairs({ "Cloth", "Herbs", "Leather" }) do local r = rowOf(name); r:GetScript("OnClick")(r) end
	check(S:SetToSheet(cloth, "TradeGoods") and S:SetToSheet(herbs, "TradeGoods") and S:SetToSheet(leather, "TradeGoods"), "three clicks set three sections to the sheet")
	check(rowOf("Cloth").check:GetChecked() == true and rowOf("Herbs").note.text == "only here" and f:IsShown(), "each row follows, and the window stays up")
	for _ = 1, 5 do M.runTimers() end
	check(S:CatOn(recOf(2589), "TradeGoods") == cloth and S:CatOn(recOf(2589), "All") == "TradeGoods", "the bags follow: cloth is in Cloth on Trade Goods, and in Trade Goods on All: " .. tostring(S:CatOn(recOf(2589), "TradeGoods")) .. ", " .. tostring(S:CatOn(recOf(2589), "All")))
	check(S:CatOn(recOf(2447), "TradeGoods") == herbs and S:CatOn(recOf(2318), "TradeGoods") == leather, "and so the herbs and the leather")
	-- the tick box itself works as the row does
	local c = rowOf("Leather").check
	c:GetScript("OnClick")(c)
	check(not S:SetToSheet(leather, "TradeGoods") and rowOf("Leather").note.text == "every sheet", "unticking takes it off the sheet: every sheet again")
	-- another sheet
	S:PickSheetMenu(f.pick)
	local m = n.menuFrame
	local labels, tickedOne = {}, nil
	for _, it in ipairs(m.items) do labels[#labels + 1] = it.text; if it.checked then tickedOne = it.text end end
	check(m:IsShown() and tickedOne == "Trade Goods" and table.concat(labels, "|"):find("All", 1, true) and table.concat(labels, "|"):find("Bank", 1, true) and not table.concat(labels, "|"):find("Gear Sets", 1, true),
		"the sheet's list: BagSmith's tabs (not Gear Sets), the one in use marked: " .. table.concat(labels, "|"))
	for _, it in ipairs(m.items) do if it.text == "Gear" then it.onClick() end end
	m:Hide()
	check(f.sheet == "Gear" and f.pick.label.text == "Gear" and rowOf("Cloth").check:GetChecked() == false and rowOf("Cloth").note.text == "only on Trade Goods", "picking Gear shows the same sections from Gear's side")
	local r = rowOf("Cloth"); r:GetScript("OnClick")(r)
	check(rowOf("Cloth").note.text == "here and Trade Goods" and #S:Sheets(cloth) == 2, "ticking Cloth there adds Gear to its sheets")
	-- it follows what happens elsewhere
	S:Delete(herbs); for _ = 1, 5 do M.runTimers() end
	check(#rows() == 2 and not rowOf("Herbs"), "a section deleted elsewhere leaves the list")
	local made = S:Create("Gems"); for _ = 1, 5 do M.runTimers() end
	check(#rows() == 3 and rowOf("Gems") and rowOf("Gems").note.text == "every sheet", "and a new one joins it")
	f.done:GetScript("OnClick")(f.done)
	check(not f:IsShown(), "Done closes it")
	-- asked for a sheet by name; a sheet that isn't one falls back to the first
	f = S:OpenSheetSections("Bank")
	check(f.sheet == "Bank", "it can be opened for a named sheet")
	n.Window.main:SetSheet("GearSets"); for _ = 1, 5 do M.runTimers() end
	f:Hide(); f = S:OpenSheetSections()
	check(f.sheet ~= "GearSets" and f.pick.label.text ~= "", "from the Gear Sets tab (which lists sets, not sections) it opens on a sheet that takes sections: " .. tostring(f.pick.label.text))
	f:Hide()
	check((n.errors or 0) == 0, "no errors")
end
do
	-- the two ways in, a long list, and nothing to list
	local M, n = boot()
	local S = n.Sections
	n.Window:Show(); for _ = 1, 10 do M.runTimers() end
	local f = S:OpenSheetSections()
	check(f.empty:IsShown() and f.empty.text == "You have no sections of your own yet. Make one in Settings > Custom Sections.", "with no sections of your own it says so, and where to make one")
	f:Hide()
	local first
	for i = 1, 14 do local id = S:Create(("Section %02d"):format(i)); first = first or id end
	f = S:OpenSheetSections("All")
	local shown = 0
	for _, r in ipairs(f.rows) do if r:IsShown() then shown = shown + 1 end end
	check(shown == 14 and f.scroll.ScrollBar:IsShown() and f.child:GetHeight() == 14 * 22 and f:GetHeight() <= 768 - 60, "fourteen sections: the list scrolls and the window keeps its size")
	f:Hide()
	-- from a section's menu in the bags
	S:SectionMenu(first, n.Window.main.frame)
	local entry
	for _, it in ipairs(n.menuFrame.items) do if it.text == "Sections on This Sheet..." then entry = it end end
	check(entry and entry.tip == "Choose which of your sections show on this sheet only, several at once.", "a section's menu in the bags has Sections on This Sheet...")
	n.menuFrame:Hide(); entry.onClick()
	check(S.sheetFrame:IsShown() and S.sheetFrame.sheet == "All", "it opens the window for the tab the bags are on")
	S.sheetFrame:Hide()
	-- from Settings > Custom Sections
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("custom"); M.runTimers()
	local btn
	for _, b in ipairs(P.pools.btn or {}) do if b:IsShown() and b.label.text == "Sections on a Sheet..." then btn = b end end
	check(btn ~= nil, "Settings > Custom Sections has Sections on a Sheet...")
	btn:GetScript("OnClick")(btn)
	check(S.sheetFrame:IsShown(), "and it opens the window")
	check((n.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- 6. The changelog and the version
------------------------------------------------------------------------
do
	local function slurp(p) local f = assert(io.open(p, "r")); local s = f:read("*a"); f:close(); return s end
	local top = ("\n" .. slurp("BagSmith/CHANGELOG.md")):match("\n## 1%.11%.0\n(.-)\n## 1%.10%.1\n")   -- (by design since 1.12.0-beta1: 1.12.0's section now leads the file, so 1.11.0's is found wherever it stands)
	check(top and top:find("\n%- Auto%-Open and Auto%-Close %(Settings > Automations%)") and top:find("\n%- Sections on a Sheet %(Settings > Custom Sections, or a section's menu in your bags%)"),
		"the changelog's 1.11.0 has Auto-Open and Auto-Close, and Sections on a Sheet")
	check(top and top:find("\nChanged:\n%- Auto%-Close Bags I Opened, from 1%.10%.1, is now the When I Leave choice on Automations%."), "and says where 1.10.1's switch went")
	check(top and not top:find("\226\128\148"), "no dashes")
	check(slurp("BagSmith/BagSmith.toc"):find("## Version: 1%.1[1-9]%.%d"), "the TOC version is 1.11.0's or later (by design since 1.12.0-beta1; the exact one is pinned in tests/run.lua)")
end
