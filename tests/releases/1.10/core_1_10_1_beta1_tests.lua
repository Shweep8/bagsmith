-- ======== 1.10.1-beta1 (Shweep, 23 Nov: "okay build") ========
-- A player's report after 1.10.0: no BagSmith window at a vendor, though the bag key opened it. His /bs debug read
--     Bag key: ToggleBag acted; window open -> closed (called from: ToggleBag < ToggleBackpack_Individual < ... < ToggleBackpack)
--     Bag key: ToggleBackpack ignored (this press is already handled) ... (called from: ToggleBackpack < ... < OpenBackpack ...)
--     Bag key: OpenAllBags ignored (this press is already handled) ... (called from: OpenAllBags < ... MerchantFrame.lua:147 < Show ...)
-- BagSmith had opened its window on the vendor event; the game's vendor window then opened the game's own bags, which
-- toggles the backpack, and BagSmith took that toggle for a press of the bag key and shut the window again, all
-- before the screen was drawn.
--   1. The game's bag calls in the frame BagSmith opens for a vendor, the mail, a trade or the auction house are not
--      presses of the bag key.
--   2. When one of the game's windows asks for the bags (OpenAllBags with that window), they end open, whatever a
--      toggle inside the same call did a moment before.
-- Shweep, on the same build: "will our settings update to show what their keybind is? so if not B": Settings >
-- General names the player's own bag key.
--
-- The game's bag functions below are a model of how the game's own (separate, not combined) bags behave: what each
-- call opens and closes, which other calls it makes, and the window the game remembers as the one that opened the
-- bags. BagSmith hooks them when it loads, as in game, so each hook fires in the game's order.

local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local VENDOR = { GetName = function() return "MerchantFrame" end }
local MAIL = { GetName = function() return "MailFrame" end }

local function boot(profile, extra)
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 13 })
	-- the game's side: which of its own bags it has open, and the window that opened them
	local G = { shown = {}, opener = nil, size = { [0] = 16, 6, 6, 6, 6, 0 }, last = 5 }
	function G.anyOpen() for i = 0, G.last do if G.shown[i] then return true end end return false end
	_G.CloseAllBags = function(frame)
		if frame and frame:GetName() ~= G.opener then return false end   -- that window didn't open them: nothing closes
		G.opener = nil
		local closed = false
		for i = 0, G.last do if G.shown[i] then G.shown[i] = nil; closed = true end end
		return closed
	end
	_G.ToggleBag = function(id)
		if (G.size[id] or 0) <= 0 then return end
		if G.shown[id] then
			if id == 0 then CloseAllBags() else G.shown[id] = nil end
		else
			G.shown[id] = true
		end
	end
	_G.ToggleBackpack = function() if G.shown[0] then CloseAllBags() else ToggleBag(0) end end
	_G.OpenBackpack = function() if not G.shown[0] then ToggleBackpack() end end
	_G.OpenBag = function(id) if (G.size[id] or 0) > 0 then G.shown[id] = true end end
	local function openAll() OpenBackpack(); for i = 1, G.last do OpenBag(i) end end
	_G.OpenAllBags = function(frame)
		if G.anyOpen() then return end
		if frame and not G.opener then G.opener = frame:GetName() end
		openAll()
	end
	_G.ToggleAllBags = function()
		local open, total = 0, 1
		if G.shown[0] then open = open + 1; G.shown[0] = nil end
		for i = 1, G.last do
			if (G.size[i] or 0) > 0 then total = total + 1 end
			if G.shown[i] then G.shown[i] = nil; open = open + 1 end
		end
		if open < total then openAll() end
	end
	_G.ToggleBackpack_Combined = nil
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	-- someone who has seen 1.10's card, unless a block says otherwise; and no card left over from the block before
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = profile or {} }, whatsNewSeen = "1.10.0" }
	for k, v in pairs(extra or {}) do _G.BagSmithDB[k] = v end
	_G.BagSmithWhatsNew = nil
	local n = M.loadAddon("BagSmith"); n.version = "1.10.1-beta1"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	for _ = 1, 20 do M.runTimers() end
	return M, n, G
end
-- A new frame: whatever the last press or window did is over.
local function frame(M) for _ = 1, 3 do M.runTimers() end end
local function bagLines(M, from)
	local out = {}
	for i = from, #M.log do local l = plain(M.log[i]); local at = l:find("Bag key:", 1, true); if at then out[#out + 1] = l:sub(at):gsub(" %(called from.*", "") end end
	return out
end

local ORDERS = { "BagSmith first", "the game first" }
local KEYS = { { "ToggleBackpack", "Toggle Backpack" }, { "ToggleAllBags", "Open All Bags" } }
-- A window of the game's opening: the event BagSmith hears, and the game's own OpenAllBags for that window.
local function opens(M, order, event, win, late)
	frame(M)
	if order == "BagSmith first" then
		M.fire(event .. "_SHOW"); if late then frame(M) end; OpenAllBags(win)
	else
		OpenAllBags(win); if late then frame(M) end; M.fire(event .. "_SHOW")
	end
end
local function closes(M, order, event, win)
	frame(M)
	if order == "BagSmith first" then M.fire(event .. "_CLOSED"); CloseAllBags(win) else CloseAllBags(win); M.fire(event .. "_CLOSED") end
end

------------------------------------------------------------------------
-- 1. At a vendor, with either key and in either order
------------------------------------------------------------------------
for _, order in ipairs(ORDERS) do
	for _, key in ipairs(KEYS) do
		local M, n, G = boot()
		local S = ("%s, the key on %s: "):format(order, key[2])
		local function press() frame(M); _G[key[1]]() end
		check(n.db.replaceBlizzardBags == true and not n.Window:IsShown() and not G.anyOpen(), S .. "(set up: bags shut, the game's own too)")
		opens(M, order, "MERCHANT", VENDOR)
		check(n.Window:IsShown(), S .. "the bags open at a vendor")
		check(G.anyOpen() and G.opener == "MerchantFrame", S .. "(the game opened its own bags for the vendor, as it does)")
		closes(M, order, "MERCHANT", VENDOR)
		check(not n.Window:IsShown() and not G.anyOpen(), S .. "and close when the vendor closes")
		-- the key between visits, then a second and a third visit
		press(); check(n.Window:IsShown(), S .. "the key opens the bags")
		press(); check(not n.Window:IsShown(), S .. "and closes them")
		for visit = 2, 3 do
			opens(M, order, "MERCHANT", VENDOR)
			check(n.Window:IsShown(), S .. "visit " .. visit .. ": open")
			if visit == 3 then
				-- at the vendor the key still does its job
				press(); check(not n.Window:IsShown(), S .. "at the vendor, the key closes the bags")
				press(); check(n.Window:IsShown(), S .. "and opens them again")
			end
			closes(M, order, "MERCHANT", VENDOR)
			check(not n.Window:IsShown(), S .. "visit " .. visit .. ": shut on leaving")
		end
		check((n.errors or 0) == 0, S .. "no errors")
	end
end

------------------------------------------------------------------------
-- 2. The player's sequence, line by line
------------------------------------------------------------------------
do
	local M, n, G = boot()
	n.db.debug = true
	frame(M)
	local from = #M.log + 1
	M.fire("MERCHANT_SHOW")
	check(n.Window:IsShown(), "BagSmith opens on the vendor event")
	OpenAllBags(VENDOR)
	local lines = bagLines(M, from)
	check(lines[1] == "Bag key: ToggleBag ignored (this press is already handled); window open -> open", "the game's ToggleBag for the vendor is no longer a press (was: acted; window open -> closed): " .. tostring(lines[1]))
	check(lines[2] == "Bag key: ToggleBackpack ignored (this press is already handled); window open -> open", "nor its ToggleBackpack: " .. tostring(lines[2]))
	check(lines[3] == "Bag key: OpenAllBags ignored (this press is already handled); window open -> open" and #lines == 3, "and OpenAllBags finds the bags open: " .. tostring(lines[3]))
	check(n.Window:IsShown(), "the bags are open at the vendor")
	-- the next frame is a new press
	frame(M); ToggleBackpack()
	check(not n.Window:IsShown(), "a frame later the bag key is a press again")
end

------------------------------------------------------------------------
-- 3. The game's window a frame after the event
------------------------------------------------------------------------
for _, order in ipairs(ORDERS) do
	local M, n, G = boot()
	local S = order .. ", a frame apart: "
	n.db.debug = true
	local from = #M.log + 1
	opens(M, order, "MERCHANT", VENDOR, true)
	check(n.Window:IsShown(), S .. "the bags are open at the vendor")
	if order == "BagSmith first" then
		local lines = bagLines(M, from)
		check(lines[1] == "Bag key: ToggleBag acted; window open -> closed", S .. "(the game's toggle, a frame later, does shut the window: " .. tostring(lines[1]) .. ")")
		check(lines[#lines] == "Bag key: OpenAllBags opened for the game's window; window closed -> open", S .. "and the vendor window's OpenAllBags opens it again in the same call: " .. tostring(lines[#lines]))
	end
	closes(M, order, "MERCHANT", VENDOR)
	check(not n.Window:IsShown(), S .. "shut on leaving")
end

------------------------------------------------------------------------
-- 4. Out of step with the game (BagSmith opened or closed by something that isn't the bag key)
------------------------------------------------------------------------
for _, order in ipairs(ORDERS) do
	for _, key in ipairs(KEYS) do
		local S = ("%s, the key on %s: "):format(order, key[2])
		-- closed with BagSmith's own X: the game still counts its bags as open
		local M, n, G = boot()
		frame(M); _G[key[1]](); n.Window:Hide()
		check(not n.Window:IsShown() and G.anyOpen(), S .. "(set up: BagSmith shut by its X, the game's bags still open)")
		opens(M, order, "MERCHANT", VENDOR)
		check(n.Window:IsShown(), S .. "shut by its X before: the bags open at a vendor")
		closes(M, order, "MERCHANT", VENDOR)
		check(not n.Window:IsShown(), S .. "and close on leaving")
		-- opened from BagSmith's own button: the game counts its bags as shut
		M, n, G = boot()
		frame(M); n.Window:Show()
		check(n.Window:IsShown() and not G.anyOpen(), S .. "(set up: BagSmith opened from its own button, the game's bags shut)")
		opens(M, order, "MERCHANT", VENDOR)
		check(n.Window:IsShown(), S .. "bags you had open stay open when you visit a vendor (" .. (order == "BagSmith first" and "was: the game's toggle shut them" or "as before") .. ")")
	end
end

------------------------------------------------------------------------
-- 5. The mail, a trade, the auction house, the guild bank
------------------------------------------------------------------------
for _, order in ipairs(ORDERS) do
	local M, n, G = boot()
	for _, ev in ipairs({ "MAIL", "TRADE", "AUCTION_HOUSE" }) do
		opens(M, order, ev, MAIL)
		check(n.Window:IsShown(), order .. ": the bags open at " .. ev)
		closes(M, order, ev, MAIL)
		check(not n.Window:IsShown(), order .. ": and close when " .. ev .. " closes")
	end
end
do
	-- the guild bank's window, followed by its OnShow: the same opening, so the same care
	local M, n, G = boot()
	local gb = CreateFrame("Frame", "GuildBankFrame", UIParent); gb:Hide()
	M.fire("ADDON_LOADED", "Blizzard_GuildBankUI")
	check(n.Hooks.guildBankFollowed, "(set up: the guild bank's window is followed)")
	frame(M); gb:Show()
	check(n.Window:IsShown(), "the guild bank opens the bags")
	OpenAllBags(gb)   -- should a client's guild bank ask for the bags too
	check(n.Window:IsShown(), "and a bag call from the game in that frame doesn't shut them")
	frame(M); gb:Hide(); frame(M)
	check(not n.Window:IsShown(), "they close with it")
	_G.GuildBankFrame = nil
end

------------------------------------------------------------------------
-- 6. What must not change
------------------------------------------------------------------------
for _, key in ipairs(KEYS) do
	-- after the game menu, BagSmith open while the game counts its bags as shut: one press closes BagSmith. With
	-- Open All Bags that press runs the game's OpenAllBags inside it, which names no window and so opens nothing.
	local M, n, G = boot()
	local S = "the key on " .. key[2] .. ": "
	frame(M); n.Window:Show()
	check(n.Window:IsShown() and not G.anyOpen(), S .. "(set up: BagSmith open, the game's bags shut)")
	frame(M); _G[key[1]]()
	check(not n.Window:IsShown(), S .. "one press closes BagSmith")
	frame(M); _G[key[1]]()
	check(n.Window:IsShown(), S .. "the next opens it")
end
do
	-- the game's OpenAllBags with no window (a cinematic ending, a vehicle) still opens, once
	local M, n, G = boot()
	frame(M); OpenAllBags()
	check(n.Window:IsShown(), "OpenAllBags with no window opens the bags, as before")
	-- and the first press after it is a press
	frame(M); ToggleAllBags()
	check(not n.Window:IsShown(), "and the key closes them")
end
for _, order in ipairs(ORDERS) do
	-- Open with the Bag Keybind off: Blizzard's bags are in use, BagSmith stays out of it
	local M, n, G = boot({ replaceBlizzardBags = false })
	opens(M, order, "MERCHANT", VENDOR)
	check(not n.Window:IsShown() and G.anyOpen(), order .. ": with Open with the Bag Keybind off, a vendor opens the game's bags and not BagSmith")
	closes(M, order, "MERCHANT", VENDOR)
	frame(M); ToggleAllBags()
	check(not n.Window:IsShown(), order .. ": and the key is Blizzard's")
end

------------------------------------------------------------------------
-- 7. Settings > General names the player's own bag key
------------------------------------------------------------------------
do
	local binds
	local function bind(t) binds = t end
	local function useBindings() _G.GetBindingKey = function(action) return unpack(binds[action] or {}) end end
	local HELP = " You can still open BagSmith from the minimap button or /bs."
	local M, n = boot()
	local KB, P = n.KeyBinds, n.SettingsPanel
	_G.KEY_TAB = "Tab"
	local function row() for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.key == "replaceBlizzardBags" then return w end end end
	P:Show(); P:ShowPage("general"); M.runTimers()

	-- where the game can't be asked, it reads as it always did
	_G.GetBindingKey = nil
	P:Refresh()
	check(KB:BagKeys() == nil, "(no GetBindingKey: the keys are unknown)")
	check(row() and row().text.text == "Open with the Bag Keybind (B)" and row().help.text == "Turn off to keep Blizzard's bags on B." .. HELP,
		"where the game can't be asked the setting says B, as before: " .. tostring(row() and row().text.text))

	useBindings()
	bind({ OPENALLBAGS = { "B" } }); P:Refresh()
	check(row().text.text == "Open with the Bag Keybind (B)", "Open All Bags on B: (B)")

	-- the player's case: Tab on Toggle Backpack, nothing on Open All Bags
	bind({ TOGGLEBACKPACK = { "TAB" } }); P:Refresh()
	check(row().text.text == "Open with the Bag Keybind (Tab)", "Toggle Backpack on Tab and nothing on Open All Bags: (Tab), was (B): " .. row().text.text)
	check(row().help.text == "Turn off to keep Blizzard's bags on Tab." .. HELP, "and its help says Tab: " .. row().help.text)
	-- and after his change
	bind({ OPENALLBAGS = { "TAB" } }); P:Refresh()
	check(row().text.text == "Open with the Bag Keybind (Tab)", "Open All Bags on Tab: (Tab)")

	-- (by design since 1.10.1-beta2: the name gives one key, the main one, and the help says when there are more; the
	-- forms with two keys and with a count, checked here in beta1, are gone. The beta2 set has the full list.)
	bind({ OPENALLBAGS = { "B" }, TOGGLEBACKPACK = { "F12" } }); P:Refresh()
	check(row().text.text == "Open with the Bag Keybind (B)" and row().help.text == "Turn off to keep Blizzard's bags on B and your other bag keys." .. HELP,
		"a key on each: one key in the name, and the help says there are others: " .. row().text.text)
	bind({ OPENALLBAGS = { "B", "SHIFT-B" }, TOGGLEBACKPACK = { "F12", "CTRL-ALT-F12" } }); P:Refresh()
	check(#KB:BagKeys() == 4, "four keys are known")

	-- (Shweep: "a secondary keybind ... and there is a keybind for opening bags and reagent bag") a bag's own key and
	-- the reagent bag's open BagSmith too, so they count
	bind({ TOGGLEREAGENTBAG1 = { "SHIFT-R" } }); P:Refresh()
	check(row().text.text == "Open with the Bag Keybind (Shift-R)", "only the reagent bag's key set: it is the bag key (not Not Set): " .. row().text.text)
	-- each of those keys does open BagSmith: the same bags its ToggleBag hook acts for
	for _, a in ipairs(KB.BAG_ACTIONS) do
		if a[2] then
			n.Window:Hide(); frame(M); ToggleBag(a[2])
			check(n.Hooks.Covers(a[2]) and n.Window:IsShown(), "the key for " .. a[1] .. " (bag " .. a[2] .. ") opens BagSmith")
		end
	end
	n.Window:Hide(); frame(M)
	-- a bag BagSmith leaves to Blizzard doesn't count: its key doesn't open BagSmith
	local realCovers = n.Hooks.Covers
	n.Hooks.Covers = function(bag) return bag ~= 5 and realCovers(bag) end
	bind({ TOGGLEREAGENTBAG1 = { "SHIFT-R" }, TOGGLEBAG1 = { "F8" } }); P:Refresh()
	check(row().text.text == "Open with the Bag Keybind (F8)", "a key for a bag BagSmith doesn't stand in for isn't named: " .. row().text.text)
	n.Hooks.Covers = realCovers
	check(realCovers(n.BANK) == false or n.BANK == nil, "(the bank's own window is never one of them)")

	-- no key on either
	bind({}); P:Refresh()
	check(#KB:BagKeys() == 0 and row().text.text == "Open with the Bag Keybind (Not Set)", "no key on either: (Not Set): " .. row().text.text)
	check(row().help.text == "No key opens your bags right now. Set one in the game's Key Bindings, under Toggle Backpack or Open All Bags." .. HELP,   -- (by design since beta2: Toggle Backpack first)
		"and its help says where to set one: " .. row().help.text)
	_G.BINDING_NAME_OPENALLBAGS, _G.BINDING_NAME_TOGGLEBACKPACK = "Alle Taschen", "Rucksack"
	P:Refresh()
	check(row().help.text:find("under Rucksack or Alle Taschen.", 1, true), "in the game's own names for the two where it has them: " .. row().help.text)   -- (by design since beta2: Toggle Backpack first)
	_G.BINDING_NAME_OPENALLBAGS, _G.BINDING_NAME_TOGGLEBACKPACK = nil, nil

	-- a key changed while the page is open shows at once; on another page nothing is drawn again for it
	bind({ OPENALLBAGS = { "B" } }); P:Refresh()
	bind({ OPENALLBAGS = { "TAB" } }); M.fire("UPDATE_BINDINGS")
	check(row().text.text == "Open with the Bag Keybind (Tab)", "a key changed with the General page open shows at once")
	P:ShowPage("about"); M.runTimers()
	local refreshed = 0
	local real = P.Refresh; P.Refresh = function(...) refreshed = refreshed + 1; return real(...) end
	M.fire("UPDATE_BINDINGS")
	check(refreshed == 0, "on another page a key change redraws nothing")
	P:Hide(); M.fire("UPDATE_BINDINGS")
	check(refreshed == 0, "nor with Settings closed")
	P.Refresh = real
	-- the setting itself is the same one
	check(n.db.replaceBlizzardBags == true, "(the setting is untouched)")
	local words = { KB:BagKeyWords() }
	check(not (words[1] .. words[2]):find("\226\128\148"), "no dashes in the words")
	check((n.errors or 0) == 0, "no errors")
	_G.GetBindingKey, _G.KEY_TAB = nil, nil
end

------------------------------------------------------------------------
-- 8. What's New, the changelog and the version
------------------------------------------------------------------------
do
	local M, n = boot()
	local WN = n.WhatsNew
	check(BagSmithDB.whatsNewSeen == "1.10.0", "(set up: this player has seen the 1.10 card)")
	local e = WN.ENTRIES[3]   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
	-- (by design since 1.10.1-beta2: three bullets, the new setting's between the two)
	check(e.v == "1.10.1" and e.heading == "BagSmith 1.10.1" and #e.items == 3 and not e.opens and WN.ENTRIES[4].v == "1.10.0", "What's New: 1.10.1's entry is first, three bullets, and is an ordinary update")   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
	check(plain(e.items[1]):find("^Bags at Vendors: ") and plain(e.items[3]):find("^Your Bag Key in Settings: "), "its bullets: Bags at Vendors first, Your Bag Key in Settings last")
	check(not table.concat(e.items, " "):find("\226\128\148"), "no dashes in them")
	check(#WN:UnseenReleases() == 0 and not WN:UnseenOpener() and not WN:Pending(), "coming from 1.10.0: the card does not open by itself for this update")
	frame(M); ToggleAllBags(); M.runTimers(); M.runTimers()
	check(n.Window:IsShown() and not (BagSmithWhatsNew and BagSmithWhatsNew:IsShown()), "opening the bags: no card")
	check(BagSmithDB.whatsNewSeen == "1.10.0", "and nothing is marked on their behalf")
end
do
	local M, n = boot(nil, { whatsNewSeen = "1.9.0", whatsNewPatchSeen = { ["1.9.8"] = true, ["1.9.7"] = true, ["1.9.6"] = true, ["1.9.5"] = true, ["1.9.4"] = true, ["1.9.3"] = true, ["1.9.2"] = true, ["1.9.1"] = true } })
	local WN = n.WhatsNew
	local unseen = WN:UnseenReleases()
	check(#unseen == 1 and unseen[1].v == "1.10.0" and WN:Pending(), "coming from 1.9.8: the 1.10 card is still what opens")
	frame(M); ToggleAllBags(); M.runTimers(); M.runTimers()
	local f = BagSmithWhatsNew
	check(f and f:IsShown() and f.entries[f.sel].v == "1.10.0", "the first time the bags open: the card, on the 1.10 tab")
end
do
	local function slurp(p) local f = assert(io.open(p, "r")); local s = f:read("*a"); f:close(); return s end
	local log = slurp("BagSmith/CHANGELOG.md")
	-- (by design since 1.11.0-beta1: 1.11.0's section comes first; 1.10.1's is still above 1.10.0's)
	local top = log:match("\n## 1%.10%.1\n(.-)\n## 1%.10%.0\n")
	check(top ~= nil, "the changelog has 1.10.1, above 1.10.0")
	check(top and top:find("Fixed:\n%- Bags that stayed shut at vendors, the mailbox, trades and the auction house%.") and top:find("Changed:\n%- Settings > General: Open with the Bag Keybind names the key your bags are really on"),
		"with the fix and the Settings line")
	check(top and not top:find("\226\128\148"), "and no dashes")
	check(slurp("BagSmith/BagSmith.toc"):find("## Version: %d+%.%d+%.%d+"), "the TOC has a version (by design since 1.11.0: the exact one is pinned in tests/run.lua)")
end
