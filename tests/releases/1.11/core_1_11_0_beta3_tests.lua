-- ======== 1.11.0-beta3 (Shweep, 26 Nov: "1, and yes to the Special Bag plan, build beta3") ========
-- 1.11's third beta:
--   1. When I Leave at the mailbox. His in-game check of beta2: "Never close doesn't seem to work at a mailbox, worked
--      at vendor though." The vendor, the bank and the auction house close the bags naming themselves; the game's mail
--      window closes them naming no window (the call Escape makes), which BagSmith took for Escape. A close with no
--      window that comes as the mail window goes is the mailbox's now. The same hole was in 1.10.1 (Auto-Close Bags I
--      Opened unticked).
--   2. Always Close at every place (his "1"): after a trade and the guild bank, which BagSmith follows by itself, bags
--      the player already had open stayed open under Always Close. Leaving follows When I Leave there too.
--   3. Special Bag Slot Indicators (Settings > Item Icons): "where you select which Special Bag to edit first (dropdown
--      maybe?) and then the settings show up for it".
--   4. Disenchant Results, in the Disenchant Helper (a player's ask; his "In the DE helper", gold lines skipped):
--      This Session and All Time.
--
-- The game's bag functions are modelled as in the 1.10.1 and 1.11.0-beta2 sets, and the mail window as the game has it:
-- it shows, asks for the bags by name, and on leaving hides and then closes the bags with no name.

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
	if not opt.lateMail then G.mail = CreateFrame("Frame", "MailFrame", UIParent); G.mail:Hide() end
	local n = M.loadAddon("BagSmith"); n.version = "1.11.0-beta3"
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
-- The mail window as the game runs it. Arriving: the window shows and asks for the bags by name; the event is heard
-- before or after. Leaving: the window hides, then the bags are closed with no window named; the event is heard
-- before all of it, after all of it, or between the two (the window shut from its own X, then the game's close).
local MAIL_ORDERS = { "the event first", "the game first", "the event between" }
local function mailOpens(M, G, order)
	frame(M)
	if order == "the event first" then M.fire("MAIL_SHOW"); G.mail:Show(); OpenAllBags(G.mail)
	else G.mail:Show(); OpenAllBags(G.mail); M.fire("MAIL_SHOW") end
end
local function mailCloses(M, G, order)
	frame(M)
	if order == "the event first" then M.fire("MAIL_CLOSED"); G.mail:Hide(); CloseAllBags()
	elseif order == "the game first" then G.mail:Hide(); CloseAllBags(); M.fire("MAIL_CLOSED")
	else G.mail:Hide(); M.fire("MAIL_CLOSED"); CloseAllBags() end
end

------------------------------------------------------------------------
-- 1. When I Leave at the mailbox
------------------------------------------------------------------------
for _, bags in ipairs(BAGS) do
	for _, order in ipairs(MAIL_ORDERS) do
		local S = ("%s, %s: "):format(bags[2], order)
		-- Never Close (his report)
		local M, n, G = boot({ combined = bags[1], profile = { closeOnLeave = "never" } })
		check(n.Hooks.mailFollowed == true, S .. "(the game's mail window is followed)")
		n.db.debug = true
		mailOpens(M, G, order)
		check(n.Window:IsShown() and n.Hooks.AutoOpened(), S .. "(set up: the mailbox opened the bags)")
		local from = #M.log + 1
		mailCloses(M, G, order)
		check(n.Window:IsShown(), S .. "Never Close: leaving the mailbox leaves the bags open")
		check(debugSaid(M, from, "CloseAllBags (the mail window's) left open (When I Leave is Never Close)"), S .. "Never Close: /bs debug says whose close it was, and why nothing closed")
		check(not n.Hooks.AutoOpened(), S .. "Never Close: they are the player's from then on")
		frame(M)
		check(not n.Hooks.MailLeaving(), S .. "a moment later the mailbox is no longer leaving")
		CloseAllBags()
		check(not n.Window:IsShown(), S .. "Never Close: so Escape (the same call, with no mailbox going) closes them")
		-- while the mailbox is open, Escape and the bag key are themselves
		mailOpens(M, G, order)
		frame(M); CloseAllBags()
		check(not n.Window:IsShown(), S .. "Never Close: Escape at the open mailbox closes the bags")
		frame(M); ToggleAllBags()
		check(n.Window:IsShown(), S .. "Never Close: the bag key opens them there")
		frame(M); ToggleAllBags()
		check(not n.Window:IsShown(), S .. "Never Close: and closes them")
		mailCloses(M, G, order); frame(M)
		check((n.errors or 0) == 0, S .. "Never Close: no errors")
		-- Close If Auto-Opened (1.10.1's switch, unticked: the hole was there too)
		M, n, G = boot({ combined = bags[1], profile = { autoCloseOwnBags = false } })
		check(n.db.closeOnLeave == "auto", S .. "(a 1.10.1 profile with Auto-Close Bags I Opened unticked)")
		frame(M); ToggleAllBags()
		mailOpens(M, G, order)
		check(n.Window:IsShown() and not n.Hooks.AutoOpened(), S .. "(set up: the player's own bags, open at the mailbox)")
		mailCloses(M, G, order)
		check(n.Window:IsShown(), S .. "Close If Auto-Opened: bags the player had open stay open on leaving the mailbox")
		frame(M); ToggleAllBags()
		check(not n.Window:IsShown(), S .. "(the bag key closes them)")
		mailOpens(M, G, order)
		check(n.Window:IsShown() and n.Hooks.AutoOpened(), S .. "(set up: bags the mailbox opened)")
		mailCloses(M, G, order)
		check(not n.Window:IsShown(), S .. "Close If Auto-Opened: bags the mailbox opened close with it")
		-- Always Close
		M, n, G = boot({ combined = bags[1] })
		frame(M); ToggleAllBags()
		mailOpens(M, G, order)
		mailCloses(M, G, order)
		check(not n.Window:IsShown(), S .. "Always Close: bags the player had open close on leaving the mailbox, as ever")
		mailOpens(M, G, order)
		mailCloses(M, G, order)
		check(not n.Window:IsShown(), S .. "Always Close: and bags the mailbox opened")
		-- Auto-Open off at the mailbox still holds, with the real window
		M, n, G = boot({ combined = bags[1], profile = { autoOpenMail = false } })
		mailOpens(M, G, order)
		check(not n.Window:IsShown(), S .. "Auto-Open at the Mailbox off: the bags stay shut")
		mailCloses(M, G, order); frame(M)
		check(not n.Window:IsShown() and (n.errors or 0) == 0, S .. "and nothing is left open")
	end
end
do
	-- a mail window that loads after BagSmith is followed from the first visit
	local M, n, G = boot({ lateMail = true, profile = { closeOnLeave = "never" } })
	check(not n.Hooks.mailFollowed, "(a mail window that isn't there at login isn't followed yet)")
	mailOpens(M, G, "the game first")
	check(n.Hooks.mailFollowed == true, "it is followed from the first visit")
	mailCloses(M, G, "the game first")
	check(n.Window:IsShown(), "Never Close holds on that first visit")
	-- a new visit ends the leaving at once
	frame(M); n.Window:Hide()
	mailOpens(M, G, "the event first")
	M.fire("MAIL_CLOSED"); check(n.Hooks.MailLeaving(), "(MAIL_CLOSED: the mailbox is leaving)")
	M.fire("MAIL_SHOW"); check(not n.Hooks.MailLeaving(), "a new visit ends it")
	-- Blizzard's bags on the bag key: BagSmith follows none of it
	M, n, G = boot({ profile = { closeOnLeave = "never", replaceBlizzardBags = false } })
	n.Window:Show()
	mailOpens(M, G, "the event first"); mailCloses(M, G, "the event first")
	check(n.Window:IsShown() and not n.Hooks.MailLeaving(), "with Open with the Bag Keybind off, BagSmith's window is left alone and nothing is marked")
end

------------------------------------------------------------------------
-- 2. Always Close at every place: trades, the guild bank, and a bank that asks the game for nothing
------------------------------------------------------------------------
for _, bags in ipairs(BAGS) do
	local S = bags[2] .. ": "
	local function trade(M) frame(M); M.fire("TRADE_SHOW"); frame(M); M.fire("TRADE_CLOSED"); frame(M) end
	-- a trade (the game's trade window asks for no bags: BagSmith follows the events)
	local M, n, G = boot({ combined = bags[1] })
	frame(M); ToggleAllBags()
	check(n.Window:IsShown(), S .. "(set up: the player opens the bags)")
	trade(M)
	check(not n.Window:IsShown(), S .. "Always Close: bags the player had open close when a trade ends")
	trade(M)
	check(not n.Window:IsShown(), S .. "Always Close: bags the trade opened close with it")
	-- the game sends TRADE_CLOSED twice, and sometimes with no trade window before it
	frame(M); ToggleAllBags()
	M.fire("TRADE_CLOSED"); frame(M)
	check(n.Window:IsShown(), S .. "a TRADE_CLOSED with no trade before it closes nothing")
	M.fire("TRADE_SHOW"); frame(M); M.fire("TRADE_CLOSED"); frame(M)
	ToggleAllBags(); frame(M)
	check(n.Window:IsShown(), S .. "(set up: opened again after the trade)")
	M.fire("TRADE_CLOSED"); frame(M)
	check(n.Window:IsShown(), S .. "the second TRADE_CLOSED for the same trade closes nothing")
	ToggleAllBags(); frame(M)
	-- Close If Auto-Opened and Never Close at a trade
	M, n, G = boot({ combined = bags[1], profile = { closeOnLeave = "auto" } })
	frame(M); ToggleAllBags(); trade(M)
	check(n.Window:IsShown(), S .. "Close If Auto-Opened: bags the player had open stay open after a trade")
	frame(M); ToggleAllBags(); trade(M)
	check(not n.Window:IsShown(), S .. "Close If Auto-Opened: bags the trade opened close")
	M, n, G = boot({ combined = bags[1], profile = { closeOnLeave = "never" } })
	trade(M)
	check(n.Window:IsShown() and not n.Hooks.AutoOpened(), S .. "Never Close: bags the trade opened stay open, and are the player's")
	-- Auto-Open off for trades, Always Close: the player's own bags still close at the end of one
	M, n, G = boot({ combined = bags[1], profile = { autoOpenTrade = false } })
	trade(M)
	check(not n.Window:IsShown(), S .. "Auto-Open When Trading off: a trade opens nothing")
	frame(M); ToggleAllBags(); trade(M)
	check(not n.Window:IsShown(), S .. "and Always Close still closes bags the player had open")
	-- the guild bank
	M, n, G = boot({ combined = bags[1] })
	local gb = CreateFrame("Frame", "GuildBankFrame", UIParent); gb:Hide()
	M.fire("ADDON_LOADED", "Blizzard_GuildBankUI")
	frame(M); ToggleAllBags()
	frame(M); gb:Show(); frame(M); gb:Hide(); frame(M)
	check(not n.Window:IsShown(), S .. "Always Close: bags the player had open close with the guild bank")
	n:Set("closeOnLeave", "auto")
	frame(M); ToggleAllBags()
	frame(M); gb:Show(); frame(M); gb:Hide(); frame(M)
	check(n.Window:IsShown(), S .. "Close If Auto-Opened: they stay open after the guild bank")
	_G.GuildBankFrame = nil
	-- a bank that asks the game for nothing
	M, n, G = boot({ combined = bags[1] })
	frame(M); ToggleAllBags()
	frame(M); M.fire("BANKFRAME_OPENED"); frame(M); M.fire("BANKFRAME_CLOSED"); frame(M)
	check(not n.Window:IsShown(), S .. "Always Close: bags the player had open close with the bank, whether or not the game's bank window closes them")
	M, n, G = boot({ combined = bags[1], profile = { closeOnLeave = "never" } })
	frame(M); M.fire("BANKFRAME_OPENED"); frame(M); M.fire("BANKFRAME_CLOSED"); frame(M)
	check(n.Window:IsShown() and not n.Hooks.AutoOpened(), S .. "Never Close: bags the bank opened stay open")
	-- a vendor: the game's own window still does it, in either order, and a second MERCHANT_CLOSED does nothing
	M, n, G = boot({ combined = bags[1] })
	frame(M); ToggleAllBags()
	frame(M); M.fire("MERCHANT_SHOW"); OpenAllBags(VENDOR); frame(M); M.fire("MERCHANT_CLOSED"); CloseAllBags(VENDOR); frame(M)
	check(not n.Window:IsShown(), S .. "Always Close at a vendor, the event first: closed")
	ToggleAllBags(); frame(M)
	M.fire("MERCHANT_CLOSED"); frame(M)
	check(n.Window:IsShown(), S .. "a second MERCHANT_CLOSED closes nothing")
	-- Blizzard's bags on the bag key
	M, n, G = boot({ combined = bags[1], profile = { replaceBlizzardBags = false } })
	n.Window:Show(); trade(M)
	check(n.Window:IsShown(), S .. "with Open with the Bag Keybind off, a trade leaves BagSmith's window alone")
	check((n.errors or 0) == 0, S .. "no errors")
end

------------------------------------------------------------------------
-- 3. Special Bag Slot Indicators: pick a kind, then its settings
------------------------------------------------------------------------
do
	local function open(opt)
		local M, n = boot(opt)
		-- what the character wears in its bag slots (the mock's own answer is a reagent bag)
		local worn = opt and opt.worn or {}
		n.BagKind = function(_, bag) return worn[bag] end
		local P = n.SettingsPanel
		P:Show(); P:ShowPage("icons"); M.runTimers()
		local function checks() local t = {}; for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and tostring(w.key):find("^glow_") then t[#t + 1] = w end end return t end
		local function drop() for _, w in ipairs(P.pools.dropdown or {}) do if w:IsShown() and w.key == "bagKindPick" then return w end end end
		local function kindRows() local t = {}; for _, pool in ipairs({ "seg", "step", "color" }) do for _, w in ipairs(P.pools[pool] or {}) do if w:IsShown() and tostring(w.key):find("^glow") then t[#t + 1] = w.key end end end table.sort(t); return table.concat(t, " ") end
		return M, n, P, checks, drop, kindRows
	end
	local M, n, P, checks, drop, kindRows = open()
	local d = drop()
	check(d and d.text.text == "Special Bag" and d.help.text == "Choose a kind of bag, then set up its indicator below.", "Item Icons has a Special Bag list under Special Bag Slot Indicators")
	local labels = {}
	for _, c in ipairs(d.choices) do labels[#labels + 1] = c.label end
	check(#labels == 12 and table.concat(labels, "|") == "Ammo Pouch|Cooking Bag|Enchanting Bag|Engineering Bag|Herb Bag|Leatherworking Bag|Mining Bag|Quiver|Reagent Bag|Soul Bag|Tackle Box|Trinket Bag",
		"it lists the twelve kinds, alphabetically: " .. table.concat(labels, "|"))
	check(d.btn.label.text == "Ammo Pouch" and n.SettingsPanel.bagKind == "ammo", "with nothing turned on and no special bag worn, it starts on the first")
	local c = checks()
	check(#c == 1 and c[1].key == "glow_ammo" and c[1].text.text == "Ammo Pouch Indicator" and c[1].box:GetChecked() == false and kindRows() == "", "under it, that kind's one switch, off, and nothing else of the twelve")
	-- turn it on: its four settings, and the list marks it
	c[1].box:SetChecked(true); c[1].box:GetScript("OnClick")(c[1].box); M.runTimers()
	check(n.db.glow_ammo == true and kindRows() == "glowAlpha_ammo glowColor_ammo glowEmpty_ammo glowFilled_ammo", "turned on: its four settings show: " .. kindRows())
	check(drop().btn.label.text == "Ammo Pouch (On)" and drop().choices[1].label == "Ammo Pouch (On)" and drop().choices[2].label == "Cooking Bag", "and the list marks it (On)")
	-- pick another from the list
	local btn = drop().btn
	btn:GetScript("OnClick")(btn)
	local m = n.menuFrame
	local texts, tickedOne = {}, nil
	for _, it in ipairs(m.items) do texts[#texts + 1] = it.text; if it.checked then tickedOne = it.text end end
	check(m:IsShown() and #m.items == 12 and tickedOne == "Ammo Pouch (On)", "the list opens with the twelve, the one in view marked: " .. tostring(tickedOne))
	for _, it in ipairs(m.items) do if it.text == "Herb Bag" then it.onClick() end end
	m:Hide(); M.runTimers()
	c = checks()
	check(drop().btn.label.text == "Herb Bag" and #c == 1 and c[1].key == "glow_herb" and c[1].box:GetChecked() == false and kindRows() == "", "picking Herb Bag shows Herb Bag's switch alone")
	check(n.db.glow_ammo == true, "(the Ammo Pouch indicator stays on: only the view moved)")
	c[1].box:SetChecked(true); c[1].box:GetScript("OnClick")(c[1].box); M.runTimers()
	check(kindRows() == "glowAlpha_herb glowColor_herb glowEmpty_herb glowFilled_herb", "Herb Bag on: its four settings")
	-- turning the one in view off keeps the view on it
	c = checks(); c[1].box:SetChecked(false); c[1].box:GetScript("OnClick")(c[1].box); M.runTimers()
	c = checks()
	check(n.db.glow_herb == false and drop().btn.label.text == "Herb Bag" and #c == 1 and c[1].key == "glow_herb", "turned off again: the page stays on Herb Bag, it doesn't jump to the one that's on")
	check(BagSmithDB.profiles.Default.bagKindPick == nil and n.db.bagKindPick == nil, "the pick is the page's own: nothing is saved for it")
	-- leaving the page and coming back keeps it
	P:ShowPage("general"); P:ShowPage("icons"); M.runTimers()
	check(drop().btn.label.text == "Herb Bag", "it is remembered while you play")
	-- search still finds every kind by name
	P:SetQuery("quiver"); M.runTimers()
	c = checks()
	check(#c == 1 and c[1].key == "glow_quiver" and drop() == nil, "searching \"quiver\" finds the Quiver Indicator itself, with no list in the way")
	P:SetQuery("indicator"); M.runTimers()
	check(#checks() == 12, "searching \"indicator\" finds all twelve")
	P:SetQuery(""); M.runTimers()
	check((n.errors or 0) == 0, "no errors")
	-- where it starts: the first kind that's on
	M, n, P, checks, drop = open({ profile = { glow_quiver = true, glow_herb = true } })
	check(drop().btn.label.text == "Herb Bag (On)" and checks()[1].key == "glow_herb", "with Herb Bag and Quiver on, it starts on Herb Bag (the first of them in the list)")
	-- else a kind the character has in a bag slot
	M, n, P, checks, drop = open({ worn = { [2] = "soul", [3] = "herb" } })
	check(drop().btn.label.text == "Herb Bag" and checks()[1].key == "glow_herb", "with none on, it starts on a kind the character wears (the first of them in the list): " .. tostring(drop().btn.label.text))
	-- both looks
	M, n, P, checks, drop = open({ profile = { skin = "classic", glow_mining = true } })
	check(drop().btn.label.text == "Mining Bag (On)" and (n.errors or 0) == 0, "the same in the Classic look")
end

------------------------------------------------------------------------
-- 4. Disenchant Results
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
	local n = M.loadAddon("BagSmith"); n.version = "1.11.0-beta3"
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
do
	local M, n, DE, prices = deBoot()
	local f = DE.frame
	local b = DE:Button()
	-- the button, and the view before anything is disenchanted
	check(f.resultsBtn and f.resultsBtn.label.text == "Results" and f.resultsBtn.points[1][1] == "BOTTOMLEFT" and f.close.points[1][1] == "BOTTOMRIGHT", "the Helper has a Results button, across from Close")
	check(f.resultsBtn.tip == "What your disenchants gave you" and f.resultsBtn.tipSub == "This session and all time. Click again for the list.", "its tip says what it is")
	check(not f.results:IsShown() and f.cur:IsShown() and f.scroll:IsShown() and b:GetAttribute("type") == "spell" and f.resultsBtn.active ~= true, "(the Helper opens on its list, the Disenchant button armed)")
	f.resultsBtn:GetScript("OnClick")(f.resultsBtn)
	check(f.results:IsShown() and not f.cur:IsShown() and not f.scroll:IsShown() and not f.sub:IsShown() and not f.status:IsShown() and not f.footer:IsShown() and f.resultsBtn.active == true, "Results swaps the list for the results")
	check(not f.heads[2]:IsShown() and not f.empty:IsShown(), "(the list's headings and the empty card are put away too)")
	check(b:GetAttribute("type") == nil and DE.current == nil, "and nothing is armed behind it")
	check(f.results.tabSession.label.text == "This Session" and f.results.tabAll.label.text == "All Time" and f.results.back.label.text == "Back to List" and f.results.tabSession.active == true and f.results.tabAll.active ~= true, "its two tabs, This Session first, and Back to List")
	local L = linesOf(DE)
	check(#L == 1 and L[1][1] == "Nothing disenchanted this session yet." and L[1][3] == "note", "with nothing disenchanted it says so")
	f.results.tabAll:GetScript("OnClick")(f.results.tabAll)
	L = linesOf(DE)
	check(f.results.tabAll.active == true and #L == 1 and L[1][1] == "No disenchants on record yet.", "and so does All Time")
	f.results.back:GetScript("OnClick")(f.results.back)
	check(not f.results:IsShown() and f.cur:IsShown() and f.scroll:IsShown() and f.footer:IsShown() and b:GetAttribute("type") == "spell" and DE.current ~= nil, "Back to List: the list is back and the button armed")
	-- three disenchants: two uncommon, one rare (soulbound: no AH price)
	local boots, dagger, ring = entryOf(DE, 7001), entryOf(DE, 7002), entryOf(DE, 7003)
	check(boots and dagger and ring and boots.vendor == 452 and boots.ah == 1500 and dagger.vendor == 800 and dagger.ah == 600 and ring.vendor == 2500 and ring.ah == nil and ring.bound, "(set up: boots 4s52c or 15s at the AH, a dagger 8s or 6s, a soulbound ring 25s)")
	local bootsMat, daggerMat, ringMat = DE:Expectation(boots.rec)[1][1], DE:Expectation(dagger.rec)[1][1], DE:Expectation(ring.rec)[1][1]
	disenchant(M, DE, 7001, { { bootsMat, 2 } })
	local r = DE:Results("session")
	check(r.n == 1 and #r.byQuality == 1 and r.byQuality[1].q == 2 and r.byQuality[1].n == 1, "one disenchant: counted, as uncommon")
	check(#r.mats == 1 and r.mats[1].id == bootsMat and r.mats[1].count == 2 and r.mats[1].value == prices[bootsMat] * 2 and r.matsValue == prices[bootsMat] * 2 and r.matsUnpriced == 0, "its materials, at the AH's price now")
	check(r.tracked.n == 1 and r.tracked.vendor == 452 and r.tracked.ah == 1500 and r.tracked.ahN == 1 and r.tracked.alt == 1500 and r.tracked.ahead == prices[bootsMat] * 2 - 1500, "what the boots would have sold for, and how the materials compare")
	check(r.best and r.best.id == 7001 and r.best.name == "Sturdy Boots" and r.best.worth == 1500 and not r.partial, "the most valuable so far: the boots")
	disenchant(M, DE, 7002, { { daggerMat, 3 } })
	disenchant(M, DE, 7003, { { ringMat, 1 } })
	r = DE:Results("session")
	check(r.n == 3 and #r.byQuality == 2 and r.byQuality[1].q == 2 and r.byQuality[1].n == 2 and r.byQuality[2].q == 3 and r.byQuality[2].n == 1, "three: two uncommon, one rare")
	local want = {}
	for _, p in ipairs({ { bootsMat, 2 }, { daggerMat, 3 }, { ringMat, 1 } }) do want[p[1]] = (want[p[1]] or 0) + p[2] end
	local matsTotal, okMats = 0, true
	for id, count in pairs(want) do matsTotal = matsTotal + prices[id] * count end
	for _, m in ipairs(r.mats) do if want[m.id] ~= m.count then okMats = false end end
	check(okMats and r.matsValue == matsTotal, "every material counted once, their total at AH prices: " .. tostring(r.matsValue))
	for i = 2, #r.mats do if (r.mats[i - 1].value or -1) < (r.mats[i].value or -1) then okMats = false end end
	check(okMats, "the dearest material first")
	check(r.tracked.vendor == 452 + 800 + 2500 and r.tracked.ah == 1500 + 600 and r.tracked.ahN == 2 and r.tracked.alt == 1500 + 800 + 2500, "vendor total, AH total (two of the three had a price), and the better of the two for each")
	check(r.tracked.ahead == matsTotal - (1500 + 800 + 2500), "ahead: the materials less the best sale")
	check(r.best.id == 7003 and r.best.worth == 2500 and r.best.ah == nil and r.best.q == 3, "the most valuable: the ring, by its vendor price")
	-- the same in the saved record your characters share, and nothing else added to the save
	local st = BagSmithDB.deShared.stats
	check(st and st.n == 3 and st.q[2] == 2 and st.q[3] == 1 and st.vendor == 3752 and st.ah == 2100 and st.ahN == 2 and st.alt == 4800 and st.best.id == 7003, "the shared record holds the same")
	local okSaved = true
	for id, count in pairs(want) do if st.mats[id] ~= count then okSaved = false end end
	check(okSaved, "with the same materials")
	local keys = {}
	for k in pairs(st) do keys[#keys + 1] = k end
	table.sort(keys)
	check(table.concat(keys, " ") == "ah ahN alt best mats n q vendor", "the record's fields: " .. table.concat(keys, " "))
	-- the view
	DE:ShowResults(true)
	L = linesOf(DE)
	check(L[1][1] == "Items Disenchanted" and L[1][2] == "3" and L[1][3] == "head" and L[2][1] == "Uncommon 2,  Rare 1", "This Session: Items Disenchanted 3, Uncommon 2, Rare 1: " .. tostring(L[2] and L[2][1]))
	check(L[3][1] == "Materials Received" and L[3][2] == "AH Value Now" and L[3][3] == "head", "Materials Received, with AH Value Now over the values")
	local first = r.mats[1]
	check(L[4][1] == ("%s x%d"):format(MATNAMES[first.id], first.count) and L[4][2] == DE.Money(first.value) and L[4][4] == first.id, "each material: its name and count, its value, and its tooltip on hover: " .. L[4][1] .. " / " .. L[4][2])
	check(lineFor(DE, "Total") and lineFor(DE, "Total")[2] == DE.Money(matsTotal), "Total")
	check(lineFor(DE, "If You Had Sold Them Instead") and lineFor(DE, "To a Vendor")[2] == DE.Money(3752), "If You Had Sold Them Instead: To a Vendor")
	check(lineFor(DE, "At the Auction House (2 of 3 had a price)") and lineFor(DE, "At the Auction House (2 of 3 had a price)")[2] == DE.Money(2100), "At the Auction House, saying how many had a price")
	check(lineFor(DE, "Best of the Two")[2] == DE.Money(4800) and lineFor(DE, "Their Materials, at AH Value Now")[2] == DE.Money(matsTotal), "Best of the Two, and Their Materials")
	local diff = matsTotal - 4800
	local verdict = diff > 0 and lineFor(DE, "Disenchanting Came Out Ahead By") or lineFor(DE, "Selling Would Have Paid More By")
	check(diff ~= 0 and verdict and verdict[2] == DE.Money(math.abs(diff)), "and which came out ahead, by how much: " .. tostring(verdict and (verdict[1] .. " " .. verdict[2])))
	check(lineFor(DE, "Most Valuable Item Disenchanted") and lineFor(DE, "Ring of the Deep") and lineFor(DE, "Ring of the Deep")[2] == "Vendor " .. DE.Money(2500) and lineFor(DE, "Ring of the Deep")[4] == 7003, "Most Valuable Item Disenchanted: the ring, Vendor 25s")
	check(lineFor(DE, "Counted since 1.11: 3 of your 3 disenchants.") == nil, "(This Session has no \"since 1.11\" note)")
	local all = table.concat((function() local t = {}; for _, l in ipairs(L) do t[#t + 1] = l[1] .. " " .. l[2] end return t end)(), " ")
	check(not all:find("\226\128\148") and not all:lower():find("gold"), "no dashes, and no gold lines (Shweep: \"Yes skip\")")
	-- a material row's tooltip
	local shownTip
	local realOwner, realLink = GameTooltip.SetOwner, GameTooltip.SetHyperlink
	GameTooltip.SetHyperlink = function(_, link) shownTip = link end
	for _, row in ipairs(f.results.rows) do if row:IsShown() and row.id == first.id then row:GetScript("OnEnter")(row) end end
	GameTooltip.SetHyperlink = realLink
	check(shownTip == "item:" .. first.id, "hovering a material shows its tooltip")
	-- All Time agrees, with every disenchant from 1.11
	DE:SetResultsTab("all")
	L = linesOf(DE)
	check(L[1][2] == "3" and L[2][1] == "Uncommon 2,  Rare 1" and lineFor(DE, "To a Vendor")[2] == DE.Money(3752) and not lineFor(DE, "Counted since 1.11: 3 of your 3 disenchants."), "All Time: the same three, nothing older")
	-- closing and opening the Helper: it opens on the list, and This Session still has them
	DE:Close(); M.runTimers()
	DE:Show(); M.runTimers()
	check(not f.results:IsShown() and DE.view == nil, "closed and opened again, the Helper is on its list")
	check(DE:Results("session").n == 3 and DE.resultsTab == "all", "This Session still has the three (it counts since you logged in), and the tab you were on is kept")
	-- in combat the Helper doesn't change
	M.combat = true
	check(DE:ToggleResults() == false and DE.view == nil and not f.results:IsShown(), "in combat Results does nothing")
	M.combat = false
	DE:ShowResults(true)
	M.combat = true
	check(DE:ShowResults(false) == false and DE.view == "results", "nor does Back to List")
	M.combat = false; M.fire("PLAYER_REGEN_ENABLED"); M.runTimers()
	check(f.results:IsShown() and b:GetAttribute("type") == nil, "after combat it is as it was, nothing armed")
	-- the bags changing while the results are up arms nothing
	M.put(0, 5, { id = 7005, name = "Plain Vest", q = 2, count = 1, class = 4, subclass = 1, price = 300, ilvl = 22, equip = "INVTYPE_CHEST" })
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	check(f.results:IsShown() and b:GetAttribute("type") == nil and DE.current == nil, "new gear arriving while the results are up arms nothing")
	DE:ShowResults(false)
	check(DE.current and DE.current.itemID == 7005 and b:GetAttribute("type") == "spell", "back on the list it is offered and armed")
	-- Forget Learned Results takes the record with it
	DE:ResetLearned()
	check(DE:Results("all").n == 0 and DE:Stats().n == 0 and next(DE:Stats().mats) == nil and DE:Stats().best == nil, "Forget Learned Results clears All Time, its record included")
	check(DE:Results("session").n == 3, "(This Session is what you did since logging in, and stays)")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- disenchants from before 1.11 are in the log: All Time has their counts and materials, the sold-instead lines say since when
	local M, n, DE, prices = deBoot({ deShared = { version = 3, results = { ["2:3:a"] = { n = 4, mats = { [10940] = 9, [10938] = 2 }, seen = { [10940] = 4, [10938] = 2 } }, ["f:4:101"] = { n = 1, mats = { [11138] = 1 }, seen = { [11138] = 1 } } }, materials = {} } })
	local r = DE:Results("all")
	check(r.n == 5 and r.byQuality[1].q == 2 and r.byQuality[1].n == 4 and r.byQuality[2].q == 4 and r.byQuality[2].n == 1 and r.tracked == nil and r.best == nil, "five older disenchants: counted by quality from the log (a learned bracket's too), no worth noted")
	check(r.matsValue == 9 * 120 + 2 * 300 + 1200 and #r.mats == 3, "their materials valued now")
	DE:ShowResults(true); DE:SetResultsTab("all")
	check(lineFor(DE, "Items Disenchanted")[2] == "5" and lineFor(DE, "Uncommon 4,  Epic 1") and not lineFor(DE, "If You Had Sold Them Instead") and not lineFor(DE, "Most Valuable Item Disenchanted"), "All Time shows them, with no sold-instead lines yet")
	DE:ShowResults(false)
	local boots = entryOf(DE, 7001)
	local mat = DE:Expectation(boots.rec)[1][1]
	disenchant(M, DE, 7001, { { mat, 2 } })
	r = DE:Results("all")
	check(r.n == 6 and r.partial and r.tracked.n == 1 and r.tracked.vendor == 452, "one more, in 1.11: six in all, one with its worth noted")
	check(r.tracked.matsValue == prices[mat] * 2 and r.tracked.ahead == prices[mat] * 2 - 1500, "compared with its own materials only, not the older ones'")
	DE:ShowResults(true)
	check(lineFor(DE, "Counted since 1.11: 1 of your 6 disenchants.") and lineFor(DE, "Counted since 1.11: 1 of your 6 disenchants.")[3] == "note", "the sold-instead lines say which disenchants they count")
	DE:SetResultsTab("session")
	check(lineFor(DE, "Items Disenchanted")[2] == "1" and not lineFor(DE, "Counted since 1.11: 1 of your 6 disenchants."), "This Session has the one")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- a material with no price yet: said so, no total passed off as whole, no verdict
	local M, n, DE = deBoot({ prices = { [7001] = 1500, [10940] = 120 } })
	local boots = entryOf(DE, 7001)
	local list = DE:Expectation(boots.rec)
	local a, b2 = list[1][1], list[2][1]
	local priced, unpriced = (a == 10940) and a or b2, (a == 10940) and b2 or a
	disenchant(M, DE, 7001, { { a, 2 }, { b2, 1 } })
	local r = DE:Results("session")
	check(r.matsUnpriced == 1 and r.tracked.ahead == nil, "(set up: one of two materials has no price)")
	DE:ShowResults(true)
	check(lineFor(DE, MATNAMES[unpriced] .. " x" .. (unpriced == a and 2 or 1))[2] == "no price yet", "a material with no price says \"no price yet\"")
	check(lineFor(DE, "Total (1 with no price yet)") ~= nil, "the total says one is missing")
	check(not lineFor(DE, "Disenchanting Came Out Ahead By") and not lineFor(DE, "Selling Would Have Paid More By") and not lineFor(DE, "Their Materials, at AH Value Now"), "and no verdict is given on part of the materials")
	check(lineFor(DE, "To a Vendor")[2] == DE.Money(452) and lineFor(DE, "At the Auction House")[2] == DE.Money(1500), "the items' own lines stand (one item, priced: no \"N of M\")")
	check((n.errors or 0) == 0, "no errors")
	-- no price addon: dashes, a note, the vendor line only
	M, n, DE = deBoot({ noAH = true })
	boots = entryOf(DE, 7001)
	disenchant(M, DE, 7001, { { DE:Expectation(boots.rec)[1][1], 2 } })
	DE:ShowResults(true)
	local L = linesOf(DE)
	check(lineFor(DE, "Materials Received")[2] == "" and L[4][2] == "-" and lineFor(DE, "AH values need Auctionator or Blackthornes Tradeskills.") and not lineFor(DE, "Total"), "with no price addon: dashes for values, and a note saying what they need")
	check(lineFor(DE, "To a Vendor")[2] == DE.Money(452) and not lineFor(DE, "At the Auction House") and not lineFor(DE, "Best of the Two") and not lineFor(DE, "Disenchanting Came Out Ahead By"), "the vendor line alone")
	check(lineFor(DE, "Sturdy Boots") and lineFor(DE, "Sturdy Boots")[2] == "Vendor " .. DE.Money(452), "the most valuable item by its vendor price")
	check((n.errors or 0) == 0, "no errors")
	-- the Classic look
	M, n, DE = deBoot({ skin = "classic" })
	DE:ShowResults(true); DE:SetResultsTab("all")
	check(DE.frame.results:IsShown() and #linesOf(DE) == 1 and (n.errors or 0) == 0, "the view opens in the Classic look")
end
do
	-- the saved record is checked piece by piece when it loads
	local huge = 1 / 0
	local bad = { n = -3, vendor = "lots", ah = huge, ahN = 2.9, alt = 0 / 0, q = { [2] = 4.7, [3] = -1, [9] = 5, x = 1 }, mats = { [10940] = 12.9, [-5] = 3, [10938] = "many", [0.5] = 2, [11083] = 0, bad = 1 },
		best = { id = 7001, name = ("x"):rep(500), q = 99, vendor = -1, ah = "no", worth = 1500.6 } }
	local M, n, DE = deBoot({ deShared = { version = 3, results = {}, materials = {}, stats = bad } })
	local st = DE:Stats()
	check(st.n == 0 and st.vendor == 0 and st.ah == 0 and st.ahN == 2 and st.alt == 0, "amounts that aren't whole numbers from zero up read as none, or are made whole")
	check(st.q[2] == 4 and st.q[3] == nil and st.q[9] == nil and st.q.x == nil, "quality counts: whole, positive, for a real quality")
	local kept = {}
	for id in pairs(st.mats) do kept[#kept + 1] = tostring(id) end
	check(#kept == 1 and st.mats[10940] == 12, "materials: whole positive item IDs with a count of one or more: " .. table.concat(kept, " "))
	check(st.best and st.best.id == 7001 and st.best.name == nil and st.best.q == 1 and st.best.vendor == 0 and st.best.ah == nil and st.best.worth == 1500, "the most valuable item: each piece checked")
	DE:ShowResults(true); DE:SetResultsTab("all")
	check((n.errors or 0) == 0, "and the view draws from it without error")
	local many = {}
	for i = 1, 400 do many[20000 + i] = 1 end
	M, n, DE = deBoot({ deShared = { version = 3, results = {}, materials = {}, stats = { n = 1, mats = many, best = { id = "x", worth = 5 } } } })
	local count = 0
	for _ in pairs(DE:Stats().mats) do count = count + 1 end
	check(count == 200 and DE:Stats().best == nil, "no more than 200 kinds of material are kept, and a most valuable item with no ID is dropped")
	M, n, DE = deBoot({ deShared = { version = 3, results = {}, materials = {}, stats = "nonsense" } })
	check(DE:Stats().n == 0 and next(DE:Stats().mats) == nil and (n.errors or 0) == 0, "a record that isn't one starts empty")
	-- a log from before the provenance rules is dropped, and its record with it
	M, n, DE = deBoot({ deShared = { version = 2, results = { ["2:3:a"] = { n = 4, mats = {} } }, materials = {}, stats = { n = 4, vendor = 100, mats = {} } } })
	check(DE:Results("all").n == 0 and DE:Stats().n == 0, "an out-of-date log is cleared, and the record goes with it")
end

------------------------------------------------------------------------
-- 5. The changelog and the version
------------------------------------------------------------------------
do
	local function slurp(p) local f = assert(io.open(p, "r")); local s = f:read("*a"); f:close(); return s end
	local top = slurp("BagSmith/CHANGELOG.md"):match("^## 1%.11%.0\n(.-)\n## 1%.10%.1\n")
	check(top and top:find("\n%- Disenchant Results: the Disenchant Helper has a Results button%."), "the changelog's 1.11.0 has Disenchant Results")
	check(top and top:find("\n%- Always Close now also closes bags you already had open when you finish a trade or leave the guild bank") and top:find("\n%- Special Bag Slot Indicators %(Settings > Item Icons%): pick a kind of bag from a list"), "under Changed: Always Close at trades and the guild bank, and the Special Bag list")
	check(top and top:find("\nFixed:\n%- Leaving the mailbox closed bags you had opened yourself even with Auto%-Close Bags I Opened turned off %(1%.10%.1%)%."), "under Fixed: the mailbox")
	check(top and not top:find("\226\128\148"), "no dashes")
	check(slurp("BagSmith/BagSmith.toc"):find("## Version: 1%.11%.0"), "the TOC version is 1.11.0's (the exact one is pinned in tests/run.lua)")
end
