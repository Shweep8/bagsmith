-- (by design since 1.10.0-beta12) this set tests the NEW tags with 1.9's list, which the panel's own list (each
-- release's) replaced: 1.9's, as it stood at 1.9.8, is put back after the addon loads
local function NEW19()
	return { release = "1.9",
		pages = { general = true, window = true, icons = true, look = true, sections = true, columns = true, sheets = true,
			globalsections = true, globalcols = true, globalsheets = true },
		heads = {},
		keys = { tipInventory = "general", tipAHPrice = "general", bagSlotCount = "window", borderWeight = "icons", iconLayout = "look", footerTextScale = "look", globalResize = "window" },
		added = {
			["1.9.1"] = { keys = { splitViewPinnedWide = "look" } },
			["1.9.2"] = { keys = { unusableOverlay = "icons" } },
			["1.9.4"] = { keys = { sectionValues = "sections" } },
		} }
end
-- ======== 1.9.2-beta1 (Shweep, 18 Nov) ========
-- Jeor's Unusable Item Overlay (Shweep8/bagsmith#15), with Shweep's follow-ups: the tooltip re-reads (each item-data,
-- tooltip-data, level, skill, spell or reputation event cleared every answer and read every item again), "Unusable Item
-- Opacity", a NEW tag. What's New: a release's updates under its tab ("a second set of button under a primary release"),
-- the card popping up only for a main release and opening on its own notes, NEW on updates not opened and on Settings'
-- What's New button until it's clicked.

local function boot(opts)
	opts = opts or {}
	package.loaded.mock = nil
	local M = require("mock")
	for i = 1, (opts.armor or 0) do
		M.put(i <= 16 and 0 or 1, ((i - 1) % 16) + 1, { id = 10000 + i, name = "Armor " .. i, q = 2, count = 1, class = 4, subclass = 1, type = "Armor", sub = "Cloth", price = 10 })
	end
	M.put(4, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local db = { version = 2, chars = {}, cache = {}, profiles = { Default = { view = "icons" } } }
	for k, v in pairs(opts.db or {}) do db[k] = v end
	_G.BagSmithDB = db
	if opts.tip then _G.C_TooltipInfo = { GetHyperlink = opts.tip } else _G.C_TooltipInfo = nil end
	-- (1.9.2-beta2) the game's "Requires Level %d" (the mock has none, so beta1's red pieces never turned red)
	_G.ITEM_MIN_LEVEL = "Requires Level %d"
	local n = M.loadAddon("BagSmith"); n.SettingsPanel.NEW = NEW19()
	n.version = opts.version or "1.9.2-beta1"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	return n, M
end

;(function()
	-- the tooltip re-reads
	local reads, red, loading = 0, {}, { [10003] = true }
	local function tip(link)
		reads = reads + 1
		local id = tonumber(tostring(link):match("item:(%d+)"))
		if loading[id] then return { lines = {} } end   -- the game doesn't have its data yet
		local lines = { { leftText = "Armor " .. tostring(id) }, { leftText = "Cloth" } }
		if red[id] then lines[#lines + 1] = { leftText = ITEM_MIN_LEVEL:format(60), leftColor = { r = 1, g = 0.1, b = 0.1 } } end
		return { lines = lines }
	end
	red[10001], red[10002] = true, true
	local n, M = boot({ armor = 20, tip = tip })
	n.Window:Show(); M.runTimers(); M.runTimers()
	check(reads > 0, "(setup) the bags open: each armor piece read once (" .. reads .. ")")
	check(n.Usability.Unknown()[10003], "(setup) one piece read before its data was there: no answer yet")
	-- (1.9.2-beta2) the two red pieces really tinted, the others not
	local function btn(id) local f; n.Buttons:EachLive(function(b) if b.hasItem and b.rec and b.rec.itemID == id then f = b end end); return f end
	local function tinted(id) local b = btn(id); return b and b.unusableOverlay and b.unusableOverlay:IsShown() or false end
	check(tinted(10001) and tinted(10002) and not tinted(10004), "(setup) the two pieces above your level tinted red, the rest not")
	local r0 = reads
	for i = 1, 30 do M.fire("GET_ITEM_INFO_RECEIVED", 50000 + i, true); M.runTimers() end
	check(reads == r0, "item data for 30 items not in the bags: nothing read again (" .. (reads - r0) .. ")")
	for i = 1, 10 do M.fire("TOOLTIP_DATA_UPDATE", i); M.runTimers() end
	local afterTips = reads - r0
	check(afterTips > 0 and afterTips <= 10 * 2, "tooltip data while one piece still has no answer: only that piece read again (" .. afterTips .. ")")
	loading[10003] = nil
	r0 = reads
	M.fire("GET_ITEM_INFO_RECEIVED", 10003, true); M.runTimers()
	check(reads - r0 >= 1 and reads - r0 <= 2 and not n.Usability.Unknown()[10003], "its data arriving: read again, now answered (" .. (reads - r0) .. ")")
	r0 = reads
	for i = 1, 10 do M.fire("TOOLTIP_DATA_UPDATE", i); M.runTimers() end
	check(reads == r0, "nothing unanswered: tooltip data reads nothing")
	r0 = reads
	for i = 1, 10 do M.fire("UPDATE_FACTION"); M.runTimers() end
	check(reads - r0 >= 10 * 2 and reads - r0 <= 10 * 2 * 2, "10 reputation gains: only the two red pieces read again each time (" .. (reads - r0) .. ")")
	red[10001] = nil
	M.fire("PLAYER_LEVEL_UP", 60); M.runTimers()
	local b1 = btn(10001)
	check(b1 and b1.unusableOverlay and not b1.unusableOverlay:IsShown(), "a level up: the piece now usable loses its tint")
	check(tinted(10002), "the one still above your level keeps it")
	r0 = reads
	M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	check(reads - r0 >= 19, "a reload or login: everything read afresh (" .. (reads - r0) .. ")")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- the setting: on by default, "Unusable Item Opacity", NEW in 1.9.2
	local n, M = boot()
	check(n.db.unusableOverlay == true and n.db.unusableOverlayOpacity == 0.35, "Unusable Item Overlay: on by default, at 35%")   -- (by design since 1.9.2-beta2: 35%, was 50%)
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("icons"); M.runTimers()
	local c, s
	for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == "unusableOverlay" then c = w end end
	for _, w in ipairs(P.pools.step) do if w:IsShown() and w.key == "unusableOverlayOpacity" then s = w end end
	check(c and c.text.text == "Unusable Item Overlay" and c.help.text == "Marks equipment, recipes and consumables whose requirements your current character does not meet with a translucent red overlay.", "the switch, with Jeor's description")
	check(s and s.text.text == "Unusable Item Opacity", "its opacity: \"Unusable Item Opacity\"")
	check(P:InRelease("keys", "unusableOverlay"), "on the NEW list for 1.9.2")
	P:Hide()
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- What's New: the tabs
	local n, M = boot({ db = { whatsNewSeen = "1.9.1" } })
	local WN = n.WhatsNew
	local tabs = WN:Tabs()
	check(tabs[1].v == "1.9.0" and #tabs[1].patches == 2 and tabs[1].patches[1].v == "1.9.2" and tabs[1].patches[2].v == "1.9.1", "the 1.9 tab: its own notes, with 1.9.2 and 1.9.1 under it")
	local t15
	for _, g in ipairs(tabs) do if g.v == "1.5.0" then t15 = g end end
	check(t15 and #t15.patches == 1 and t15.patches[1].v == "1.5.1", "the 1.5 tab: 1.5.1 under it")
	check(#tabs == 5 and tabs[2].v == "1.8.0" and #tabs[2].patches == 0, "five tabs; 1.8 with no updates")
	-- updated from 1.9.1: no pop-up; NEW on the updates and on Settings' button
	check(not WN:Pending(), "1.9.1 to 1.9.2: the card doesn't pop up (an update)")
	check(WN:PatchNew(tabs[1].patches[1]) and WN:PatchNew(tabs[1].patches[2]), "1.9.2 and 1.9.1 say NEW (never opened)")
	check(not WN:PatchNew(t15.patches[1]), "1.5.1 doesn't (an old release's update)")
	local P = n.SettingsPanel
	P:Show(); M.runTimers()
	local btn = P.frame.whatsNew
	check(WN:ButtonNew() and btn.newTag and btn.newTag:IsShown(), "Settings' What's New button: NEW")
	btn:GetScript("OnClick")(btn); M.runTimers()
	local c = WN.Card()
	check(not (btn.newTag and btn.newTag:IsShown()) and not WN:ButtonNew(), "clicked: the button's NEW is gone")
	check(c:IsShown() and c.sel == 1 and c.sub == nil and c.lines[1].text == "BagSmith 1.9", "it opens on 1.9's own notes")
	local subs = {}
	for _, b in ipairs(c.subTabs or {}) do if b:IsShown() then subs[#subs + 1] = b end end
	check(#subs == 2 and subs[1].label.text == "1.9.2" and subs[2].label.text == "1.9.1", "a second row: 1.9.2, 1.9.1")
	check(subs[1].newTag and subs[1].newTag:IsShown() and subs[2].newTag and subs[2].newTag:IsShown(), "both with NEW")
	local h = c:GetHeight()
	subs[1]:GetScript("OnClick")(subs[1]); M.runTimers()
	check(c.sub == 1 and c.lines[1].text == "BagSmith 1.9.2" and c.lines[2].text:find("Unusable Items in Red", 1, true), "1.9.2 clicked: its notes")
	check(not WN:PatchNew(tabs[1].patches[1]) and not (subs[1].newTag and subs[1].newTag:IsShown()) and subs[2].newTag:IsShown(), "1.9.2's NEW gone; 1.9.1's stays until opened")
	check(c.tabs[1].active, "the 1.9 tab still highlighted")
	WN:Select(2); M.runTimers()
	check(c:GetHeight() == h, "the 1.8 tab: the same card size (the second row's room kept)")
	local shown = 0
	for _, b in ipairs(c.subTabs) do if b:IsShown() then shown = shown + 1 end end
	check(shown == 0, "and no second row under 1.8")
	WN:Close()
	-- kept for the account
	local saved = BagSmithDB
	saved.whatsNewPatchSeen.junk = true; saved.whatsNewPatchSeen["1.9"] = true
	n, M = boot({ db = saved })
	check(BagSmithDB.whatsNewPatchSeen["1.9.2"] == true and BagSmithDB.whatsNewPatchSeen.junk == nil and BagSmithDB.whatsNewPatchSeen["1.9"] == nil, "after a reload: 1.9.2 still opened; junk dropped")
	check(BagSmithDB.whatsNewButtonSeen == "1.9.2", "and the button's click remembered")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- from 1.8 straight to 1.9.2: the card pops up on 1.9's own notes
	local n, M = boot({ db = { whatsNewSeen = "1.8.0" } })
	local WN = n.WhatsNew
	check(WN:Pending(), "1.8 to 1.9.2: the card pops up (a new release)")
	WN:Check(); M.runTimers()
	local c = WN.Card()
	check(c:IsShown() and c.sel == 1 and c.sub == nil and c.lines[1].text == "BagSmith 1.9", "on 1.9's own notes")
	local subs = 0
	for _, b in ipairs(c.subTabs or {}) do if b:IsShown() and b.newTag and b.newTag:IsShown() then subs = subs + 1 end end
	check(subs == 2, "1.9.2 and 1.9.1 under it, both NEW")
	WN:Close()
	check(not WN:Pending(), "closed: seen")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- a first install: nothing to pop up, nothing NEW
	local n, M = boot({ db = {} })
	local WN = n.WhatsNew
	BagSmithDB.whatsNewSeen = nil; BagSmithDB.whatsNewPatchSeen = nil; BagSmithDB.whatsNewButtonSeen = nil
	n:Fire("ADDON_READY")
	check(not WN:Pending() and not WN:ButtonNew(), "a first install: no pop-up, no NEW on the button")
	check(not WN:PatchNew(WN:Tabs()[1].patches[1]), "nor on the updates")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- /bs new reset (for testing): the card pops up again on 1.9's own notes, the updates NEW again
	local n, M = boot({ db = { whatsNewSeen = "1.9.2", whatsNewPatchSeen = { ["1.9.2"] = true, ["1.9.1"] = true }, whatsNewButtonSeen = "1.9.2" } })
	local WN = n.WhatsNew
	check(not WN:Pending() and not WN:ButtonNew(), "(setup) everything seen")
	SlashCmdList.BAGSMITH("new reset")
	check(WN:Pending(), "/bs new reset: the card will pop up (seen set before 1.9, not 1.9.1)")
	check(WN:ButtonNew() and WN:PatchNew(WN:Tabs()[1].patches[1]), "and the updates and the button NEW again")
	WN:Check(); M.runTimers()
	local c = WN.Card()
	check(c:IsShown() and c.sel == 1 and c.sub == nil, "it pops up on 1.9's own notes")
	WN:Close()
	SlashCmdList.BAGSMITH("new reset skipped")
	check(#WN:UnseenReleases() >= 2, "/bs new reset skipped: several releases unseen (" .. #WN:UnseenReleases() .. ")")
	check((n.errors or 0) == 0, "no errors")
end)()
