-- ======== 1.10.1-beta2 (Shweep, 23 Nov: "1, build") ========
-- After beta1, from Shweep:
--   * Forever's own bag keys (his screenshot): Toggle Backpack on B and F12, Toggle Reagent Bag unbound, Toggle Bag 1
--     to 4 on F8 to F11, Open All Bags on Shift-B. Beta1's name led with Open All Bags and counted every key:
--     "(Shift-B, B and 5 more)". The name gives one key now, the main one.
--   * "keep it as it is but add a setting default (true) for that so players can turn it off in future": bags the
--     player opened himself close when a vendor closes, as they always have, behind Auto-Close Bags I Opened (his
--     pick of the name). Off, leaving only closes bags that opened for that window.
-- And from reading FlareUI 7.0.6 at his request: the game's Use Combined Bags setting decides who could get beta1's
-- fault (separate bags, where the game's OpenBackpack goes through ToggleBackpack), and Forever's bank opens the bags
-- through the game's own calls too. Both bag settings and the bank are run here.
--
-- The game's bag functions below model both settings: what each call opens and closes, which other calls it makes,
-- and the window the game remembers as the one that opened the bags. BagSmith hooks them when it loads.

local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local VENDOR = { GetName = function() return "MerchantFrame" end }
local MAIL = { GetName = function() return "MailFrame" end }
local BANK = { GetName = function() return "BankFrame" end }

local function boot(opt)
	opt = opt or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 13 })
	local G = { shown = {}, opener = nil, size = { [0] = 16, 6, 6, 6, 6, opt.reagent and 6 or 0 }, last = 5, combined = opt.combined, one = false }
	local function held(id) return G.combined and id <= 4 end   -- the bags the combined window holds
	local function isOpen(id) if held(id) then return G.one end return G.shown[id] and true or false end
	function G.anyOpen() for i = 0, G.last do if isOpen(i) then return true end end return false end
	local function closeBag(id) if held(id) then G.one = false else G.shown[id] = nil end end
	_G.CloseAllBags = function(frame)
		if frame and frame:GetName() ~= G.opener then return false end   -- that window didn't open them: nothing closes
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
		if G.combined then return OpenBag(0) end          -- the one window, opened directly
		if not G.shown[0] then ToggleBackpack() end        -- separate bags: through the toggle
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
	for k, v in pairs(opt.db or {}) do _G.BagSmithDB[k] = v end
	_G.BagSmithWhatsNew = nil
	local n = M.loadAddon("BagSmith"); n.version = "1.10.1-beta2"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	for _ = 1, 20 do M.runTimers() end
	return M, n, G
end
local function frame(M) for _ = 1, 3 do M.runTimers() end end   -- a new frame
local ORDERS = { "BagSmith first", "the game first" }
local KEYS = { { "ToggleBackpack", "Toggle Backpack" }, { "ToggleAllBags", "Open All Bags" } }
local BAGS = { { true, "combined bags" }, { false, "separate bags" } }
local function opens(M, order, show, win, late)
	frame(M)
	if order == "BagSmith first" then M.fire(show); if late then frame(M) end; OpenAllBags(win) else OpenAllBags(win); if late then frame(M) end; M.fire(show) end
end
local function closes(M, order, hide, win)
	frame(M)
	if order == "BagSmith first" then M.fire(hide); CloseAllBags(win) else CloseAllBags(win); M.fire(hide) end
	frame(M)
end

------------------------------------------------------------------------
-- 1. Both bag settings: a vendor, the mail and the bank, in either order, with either key
------------------------------------------------------------------------
for _, bags in ipairs(BAGS) do
	for _, reagent in ipairs({ false, true }) do
		for _, order in ipairs(ORDERS) do
			for _, key in ipairs(KEYS) do
				local M, n, G = boot({ combined = bags[1], reagent = reagent })
				local S = ("%s%s, %s, the key on %s: "):format(bags[2], reagent and " and a reagent bag" or "", order, key[2])
				local function press() frame(M); _G[key[1]]() end
				for visit = 1, 2 do
					opens(M, order, "MERCHANT_SHOW", VENDOR)
					check(n.Window:IsShown(), S .. "vendor, visit " .. visit .. ": the bags open")
					closes(M, order, "MERCHANT_CLOSED", VENDOR)
					check(not n.Window:IsShown() and not G.anyOpen(), S .. "and close on leaving, the game's too")
					press(); local opened = n.Window:IsShown(); press()
					check(opened and not n.Window:IsShown(), S .. "the key opens and closes them in between")
				end
				opens(M, order, "MAIL_SHOW", MAIL)
				check(n.Window:IsShown(), S .. "the mailbox: open")
				closes(M, order, "MAIL_CLOSED", MAIL)
				check(not n.Window:IsShown(), S .. "the mailbox: shut on leaving")
				-- the bank: BagSmith opens its bags on the bank's event, and Forever's bank window asks the game for them too
				opens(M, order, "BANKFRAME_OPENED", BANK)
				check(n.Window:IsShown() and n.Hooks.AutoOpened(), S .. "the bank: the bags open, for the bank")
				closes(M, order, "BANKFRAME_CLOSED", BANK)
				check(not n.Window:IsShown(), S .. "the bank: shut on leaving")
				check((n.errors or 0) == 0, S .. "no errors")
			end
		end
	end
end
do
	-- a client whose bank doesn't ask the game for the bags: they stay open after it, as before, and are the player's
	local M, n, G = boot({ combined = false })
	frame(M); M.fire("BANKFRAME_OPENED")
	check(n.Window:IsShown() and n.Hooks.AutoOpened(), "a bank that doesn't ask the game for the bags: BagSmith still opens them")
	frame(M); M.fire("BANKFRAME_CLOSED")
	check(n.Window:IsShown(), "and they stay open when it closes, as before")
	frame(M)
	check(not n.Hooks.AutoOpened(), "from the next frame they count as bags the player has open")
end

------------------------------------------------------------------------
-- 2. Auto-Close Bags I Opened: on, as it has always worked
------------------------------------------------------------------------
do
	local M, n = boot()
	check(n.db.autoCloseOwnBags == true, "Auto-Close Bags I Opened is on by default")
	check(BagSmithDB.profiles.Default.autoCloseOwnBags == true, "and a profile from before it gets it on")
end
for _, bags in ipairs(BAGS) do
	for _, order in ipairs(ORDERS) do
		for _, key in ipairs(KEYS) do
			local S = ("on, %s, %s, the key on %s: "):format(bags[2], order, key[2])
			local M, n, G = boot({ combined = bags[1] })
			frame(M); _G[key[1]]()
			check(n.Window:IsShown() and not n.Hooks.AutoOpened(), S .. "(set up: the player opens the bags with the key)")
			opens(M, order, "MERCHANT_SHOW", VENDOR)
			check(n.Window:IsShown() and not n.Hooks.AutoOpened(), S .. "at a vendor they stay open, and are still the player's")
			closes(M, order, "MERCHANT_CLOSED", VENDOR)
			check(not n.Window:IsShown(), S .. "leaving closes them, as it always has")
		end
	end
end

------------------------------------------------------------------------
-- 3. Auto-Close Bags I Opened: off
------------------------------------------------------------------------
for _, bags in ipairs(BAGS) do
	for _, order in ipairs(ORDERS) do
		for _, key in ipairs(KEYS) do
			local S = ("off, %s, %s, the key on %s: "):format(bags[2], order, key[2])
			local function press(M) frame(M); _G[key[1]]() end
			-- bags the player opened stay open
			local M, n, G = boot({ combined = bags[1], profile = { autoCloseOwnBags = false } })
			n.db.debug = true
			press(M)
			opens(M, order, "MERCHANT_SHOW", VENDOR)
			check(n.Window:IsShown() and not n.Hooks.AutoOpened(), S .. "(set up: the player's own bags, open at a vendor)")
			local from = #M.log + 1
			closes(M, order, "MERCHANT_CLOSED", VENDOR)
			check(n.Window:IsShown(), S .. "leaving the vendor leaves bags the player opened open")
			local said
			for i = from, #M.log do if plain(M.log[i]):find("Bag key: CloseAllBags left open (bags you opened yourself); window open -> open", 1, true) then said = true end end
			check(said, S .. "and /bs debug says why")
			press(M)
			check(not n.Window:IsShown(), S .. "the key closes them, in one press")
			-- bags that opened for the vendor still close with it
			opens(M, order, "MERCHANT_SHOW", VENDOR)
			check(n.Window:IsShown() and n.Hooks.AutoOpened(), S .. "bags shut: a vendor opens them, for the vendor")
			closes(M, order, "MERCHANT_CLOSED", VENDOR)
			check(not n.Window:IsShown(), S .. "and leaving closes those")
			-- closed and opened again by the player at the vendor: his now
			opens(M, order, "MERCHANT_SHOW", VENDOR)
			press(M); check(not n.Window:IsShown() and not n.Hooks.AutoOpened(), S .. "at the vendor the key closes them")
			press(M); check(n.Window:IsShown() and not n.Hooks.AutoOpened(), S .. "and opening them again makes them the player's")
			closes(M, order, "MERCHANT_CLOSED", VENDOR)
			check(n.Window:IsShown(), S .. "so they stay open on leaving")
			-- Escape and the X close them whatever the setting
			frame(M); CloseAllBags()
			check(not n.Window:IsShown(), S .. "Escape (the game's CloseAllBags with no window) closes them")
			press(M); n.Window:Hide()
			check(not n.Window:IsShown() and not n.Hooks.AutoOpened(), S .. "and so does the X")
			-- the bank
			frame(M); press(M); if not n.Window:IsShown() then press(M) end
			opens(M, order, "BANKFRAME_OPENED", BANK)
			closes(M, order, "BANKFRAME_CLOSED", BANK)
			check(n.Window:IsShown(), S .. "bags the player had open stay open after the bank")
			press(M); if n.Window:IsShown() then press(M) end
			opens(M, order, "BANKFRAME_OPENED", BANK)
			check(n.Window:IsShown() and n.Hooks.AutoOpened(), S .. "bags shut: the bank opens them")
			closes(M, order, "BANKFRAME_CLOSED", BANK)
			check(not n.Window:IsShown(), S .. "and leaving the bank closes those")
			check((n.errors or 0) == 0, S .. "no errors")
		end
	end
end
for _, order in ipairs(ORDERS) do
	-- bags opened from BagSmith's own button, so the game counts its own as shut (separate bags): the vendor window's
	-- OpenAllBags runs its toggle. They are the player's before, during and after.
	local S = "off, separate bags, " .. order .. ": "
	local M, n, G = boot({ combined = false, profile = { autoCloseOwnBags = false } })
	frame(M); n.Window:Show()
	check(n.Window:IsShown() and not G.anyOpen(), S .. "(set up: opened from BagSmith's own button, the game's bags shut)")
	opens(M, order, "MERCHANT_SHOW", VENDOR)
	check(n.Window:IsShown() and not n.Hooks.AutoOpened(), S .. "at a vendor they stay open and stay the player's, whatever the game's toggle did in that call")
	closes(M, order, "MERCHANT_CLOSED", VENDOR)
	check(n.Window:IsShown(), S .. "and stay open on leaving")
	-- the vendor's window a frame after its event: opened for the vendor, shut by the toggle, opened again in the call
	M, n, G = boot({ combined = false, profile = { autoCloseOwnBags = false } })
	opens(M, order, "MERCHANT_SHOW", VENDOR, true)
	check(n.Window:IsShown() and n.Hooks.AutoOpened(), S .. "the game's window a frame apart: open, and for the vendor")
	closes(M, order, "MERCHANT_CLOSED", VENDOR)
	check(not n.Window:IsShown(), S .. "so leaving closes them")
end

------------------------------------------------------------------------
-- 4. The switch in Settings > General
------------------------------------------------------------------------
do
	local M, n = boot({ db = { newSeen = { ["1.10"] = { general = "1.10.0" } } } })
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("general"); M.runTimers()
	local function row(key) for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.key == key then return w end end end
	local function top(w) return select(5, w:GetPoint(1)) or select(3, w:GetPoint(1)) end
	local r, bagRow, mini = row("autoCloseOwnBags"), row("replaceBlizzardBags"), row("minimap")
	check(r and r.text.text == "Auto-Close Bags I Opened", "the switch is named Auto-Close Bags I Opened")
	-- (by design since 1.10.1: Shweep had the help reworded, "a tad confusing as written", and picked this one)
	check(r and r.help.text == "When you leave a vendor, the mailbox, a trade or the auction house, your bags close, even if you already had them open. Turn off, and bags you already had open stay open.",
		"its help, word for word: " .. tostring(r and r.help.text))
	check(r and not r.help.text:find("\226\128\148"), "no dashes")
	check(r and bagRow and mini and top(bagRow) > top(r) and top(r) > top(mini), "it sits under Open with the Bag Keybind, above Show Minimap Button")
	check(r.box:GetChecked() == true, "ticked by default")
	check(P:IsNew("keys", "autoCloseOwnBags") and r.newTag and r.newTag:IsShown(), "NEW beside it for someone who saw the General page in 1.10.0")
	check(not (bagRow.newTag and bagRow.newTag:IsShown()), "and not beside the settings that were there")
	r.box:SetChecked(false); r.box:GetScript("OnClick")(r.box)
	check(n.db.autoCloseOwnBags == false and BagSmithDB.profiles.Default.autoCloseOwnBags == false, "unticking it turns it off, in the profile")
	r.box:SetChecked(true); r.box:GetScript("OnClick")(row("autoCloseOwnBags").box)
	check(n.db.autoCloseOwnBags == true, "and ticking it turns it back on")
	-- with Blizzard's bags on the key BagSmith opens and closes nothing for a window: the switch is greyed, its value kept
	n:Set("autoCloseOwnBags", false); n:Set("replaceBlizzardBags", false); M.runTimers()
	r = row("autoCloseOwnBags")
	check(r and not r.box:IsEnabled() and r.box:GetChecked() == false, "with Open with the Bag Keybind off it is greyed, showing what it is set to")
	n:Set("replaceBlizzardBags", true); M.runTimers()
	check(row("autoCloseOwnBags").box:IsEnabled(), "and usable again with it on")
	check((n.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- 5. The bag key in the setting's name: one key, the main one
------------------------------------------------------------------------
do
	local binds
	local function bind(t) binds = t end
	local HELP = " You can still open BagSmith from the minimap button or /bs."
	local M, n = boot()
	local KB, P = n.KeyBinds, n.SettingsPanel
	_G.KEY_TAB = "Tab"
	_G.GetBindingKey = function(action) return unpack(binds[action] or {}) end
	local function row() for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.key == "replaceBlizzardBags" then return w end end end
	bind({}); P:Show(); P:ShowPage("general"); M.runTimers()
	local function reads(name, help, what)
		P:Refresh()
		check(row().text.text == "Open with the Bag Keybind (" .. name .. ")", what .. ": (" .. name .. "), got " .. row().text.text)
		check(row().help.text == help .. HELP, what .. ": the help: " .. row().help.text)
	end
	-- Forever's own keys, from Shweep's screenshot
	bind({ TOGGLEBACKPACK = { "B", "F12" }, OPENALLBAGS = { "SHIFT-B" }, TOGGLEBAG1 = { "F8" }, TOGGLEBAG2 = { "F9" }, TOGGLEBAG3 = { "F10" }, TOGGLEBAG4 = { "F11" } })
	reads("B", "Turn off to keep Blizzard's bags on B and your other bag keys.", "Forever's own keys (beta1 read Shift-B, B and 5 more)")
	check(table.concat(KB:BagKeys(), " ") == "B F12 Shift-B F8 F9 F10 F11", "(all seven keys are known, Toggle Backpack's first)")
	-- the player's keys: Tab on Toggle Backpack, then moved to Open All Bags with F12 left on Toggle Backpack
	bind({ TOGGLEBACKPACK = { "TAB", "F12" }, OPENALLBAGS = { "SHIFT-B" } })
	reads("Tab", "Turn off to keep Blizzard's bags on Tab and your other bag keys.", "Tab on Toggle Backpack")
	bind({ TOGGLEBACKPACK = { "F12" }, OPENALLBAGS = { "TAB" } })
	reads("Tab", "Turn off to keep Blizzard's bags on Tab and your other bag keys.", "Tab moved to Open All Bags, F12 left on Toggle Backpack: Tab, not F12")
	-- one key only
	bind({ TOGGLEBACKPACK = { "B" } })
	reads("B", "Turn off to keep Blizzard's bags on B.", "one key in all")
	bind({ OPENALLBAGS = { "CTRL-SHIFT-I" } })
	reads("Ctrl-Shift-I", "Turn off to keep Blizzard's bags on Ctrl-Shift-I.", "only Open All Bags, with modifiers")
	-- function keys: passed over while there is another, used when there is nothing else, and fine with a modifier
	bind({ TOGGLEBACKPACK = { "F12" }, TOGGLEBAG1 = { "F8" } })
	reads("F12", "Turn off to keep Blizzard's bags on F12 and your other bag keys.", "nothing but function keys: the first")
	bind({ TOGGLEBACKPACK = { "F12", "SHIFT-F5" } })
	reads("Shift-F5", "Turn off to keep Blizzard's bags on Shift-F5 and your other bag keys.", "a function key with a modifier is a key someone chose")
	bind({ TOGGLEBACKPACK = { "F12" }, TOGGLEREAGENTBAG1 = { "R" } })
	reads("R", "Turn off to keep Blizzard's bags on R and your other bag keys.", "the reagent bag's key before a bare function key")
	-- none, and where the game can't be asked
	bind({})
	reads("Not Set", "No key opens your bags right now. Set one in the game's Key Bindings, under Toggle Backpack or Open All Bags.", "no bag key at all")
	_G.GetBindingKey = nil
	reads("B", "Turn off to keep Blizzard's bags on B.", "where the game can't be asked")
	check(KB:MainBagKey({ "F12", "Tab" }) == "Tab" and KB:MainBagKey({ "F9" }) == "F9", "(MainBagKey: the first that isn't a bare function key, else the first)")
	check((n.errors or 0) == 0, "no errors")
	_G.GetBindingKey, _G.KEY_TAB = nil, nil
end

------------------------------------------------------------------------
-- 6. What's New, the changelog and the version
------------------------------------------------------------------------
do
	local M, n = boot()
	local WN = n.WhatsNew
	local e = WN.ENTRIES[1]
	check(e.v == "1.10.1" and #e.items == 3 and not e.opens, "What's New: 1.10.1's update has three bullets and doesn't open the card")
	check(plain(e.items[1]) == "Bags at Vendors: with the game's Use Combined Bags turned off, your bags could stay shut at vendors, the mailbox, trades and the auction house, though the bag key opened them fine. They open there now.",
		"Bags at Vendors, word for word: " .. plain(e.items[1]))
	check(plain(e.items[2]) == "Auto-Close Bags I Opened: a new switch in Settings > General. Turn it off and bags you opened yourself stay open when you leave a vendor or the mailbox.",
		"Auto-Close Bags I Opened, word for word: " .. plain(e.items[2]))
	check(plain(e.items[3]) == "Your Bag Key in Settings: Settings > General names the key your bags are on, such as Tab, instead of always saying B.",
		"Your Bag Key in Settings, word for word: " .. plain(e.items[3]))
	check(not table.concat(e.items, " "):find("\226\128\148"), "no dashes")
	check(#WN:UnseenReleases() == 0 and not WN:Pending(), "coming from 1.10.0 the card still doesn't open by itself")
	local function slurp(p) local f = assert(io.open(p, "r")); local s = f:read("*a"); f:close(); return s end
	local top = slurp("BagSmith/CHANGELOG.md"):match("^## 1%.10%.1\n(.-)\n## 1%.10%.0\n")
	check(top and top:find("New:\n%- Auto%-Close Bags I Opened %(Settings > General%), on as it has always worked%.") and top:find("\nFixed:\n%- Bags that stayed shut at vendors") and top:find("With the game's Use Combined Bags\n  turned off", 1, true) and top:find("\nChanged:\n%- Settings > General: Open with the Bag Keybind names the key"),
		"the changelog's 1.10.1: the new switch, the fix and who had it, and the Settings line")
	check(top and not top:find("\226\128\148"), "no dashes")
	check(slurp("BagSmith/BagSmith.toc"):find("## Version: 1%.10%.1"), "the TOC version is 1.10.1's (the exact one is pinned in tests/run.lua)")
end
