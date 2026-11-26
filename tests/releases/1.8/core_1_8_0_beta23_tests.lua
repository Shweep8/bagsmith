;(function()
	-- ======== 1.8.0-beta23 (Shweep: "we def should open it when guild bank opens") ========
	-- Forever doesn't open the bags with the guild bank. BagSmith follows its window, loaded on demand, as it follows a
	-- vendor: open with it, close with it, unless the bags were open already.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {} } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	check(not n.Hooks.guildBankFollowed, "(setup) the guild bank's window isn't loaded yet")
	-- the game loads Blizzard_GuildBankUI when you first open the guild bank
	local gb = CreateFrame("Frame", "GuildBankFrame", UIParent)
	gb:Hide()
	M.fire("ADDON_LOADED", "Blizzard_GuildBankUI")
	check(n.Hooks.guildBankFollowed, "once it loads, BagSmith follows the guild bank's window")
	if n.Window:IsShown() then n.Window:Hide() end
	gb:Show(); M.runTimers()
	check(n.Window:IsShown(), "the guild bank opens: so do the bags")
	gb:Hide(); M.runTimers()
	check(not n.Window:IsShown(), "it closes: so do the bags")
	-- (by design since 1.11.0-beta3, Shweep's "1": Always Close closes the bags at every place, whether they opened for it or were open already). Bags you had open already stayed open here; Close If Auto-Opened is the choice that leaves them now.
	n.Window:Show()
	gb:Show(); M.runTimers(); gb:Hide(); M.runTimers()
	check(not n.Window:IsShown(), "bags you had open already close with it too (When I Leave: Always Close)")
	n:Set("closeOnLeave", "auto"); n.Window:Show()
	gb:Show(); M.runTimers(); gb:Hide(); M.runTimers()
	check(n.Window:IsShown(), "and stay open with Close If Auto-Opened")
	n:Set("closeOnLeave", "always")
	n.Window:Hide()
	n.Hooks.FollowGuildBank()
	gb:Show(); M.runTimers(); gb:Hide(); M.runTimers()
	check(not n.Window:IsShown(), "followed once only (no double hooks)")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- Auto Travel Mode: Leave Travel Mode at the Guild Bank (on by default), back on when it closes
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { travelMode = true } } }
	local n = M.loadAddon("BagSmith")
	local gb = CreateFrame("Frame", "GuildBankFrame", UIParent); gb:Hide()
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	M.fire("ADDON_LOADED", "Blizzard_GuildBankUI")
	check(n.db.travelLeaveGuildBank == true, "on by default")
	gb:Show(); M.runTimers()
	check(n.ui.travelHold.guildbank == true and n:TravelHeld(), "at the guild bank: Travel Mode is off")
	check(n:TravelTip():find("at the guild bank", 1, true), "the signpost says why: " .. n:TravelTip())
	gb:Hide(); M.runTimers()
	check(not n.ui.travelHold.guildbank and not n:TravelHeld(), "closed: back on")
	n:Set("travelLeaveGuildBank", false)
	gb:Show(); M.runTimers()
	check(not n.ui.travelHold.guildbank, "turned off: Travel Mode stays on at the guild bank")
	gb:Hide(); M.runTimers()
	n:Set("travelLeaveGuildBank", true)
	gb:Show(); M.runTimers()
	n:Set("travelLeaveGuildBank", false)
	check(not n.ui.travelHold.guildbank, "turning it off while there lets go")
	gb:Hide(); M.runTimers()
	-- the setting is on the page
	n.SettingsPanel:Show(); n.SettingsPanel:ShowPage("automation")
	local row
	for _, w in ipairs(n.SettingsPanel.pools.check) do if w:IsShown() and w.key == "travelLeaveGuildBank" then row = w end end
	check(row and row.text.text == "Leave Travel Mode at the Guild Bank", "Settings > Automations lists it")
	check((n.errors or 0) == 0, "no errors")
end)()
