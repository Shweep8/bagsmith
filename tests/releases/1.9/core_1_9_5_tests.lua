-- (by design since 1.10.0-beta12: the 1.10 card leads What's New, so every older entry is one place further down)
-- ======== 1.9.5 (Shweep, 19 Nov) ========
-- "I do think a What's New would be nice, it's technically relevant": a 1.9.5 entry, an update under the 1.9 tab
-- (no pop-up; NEW on its button and on Settings' What's New button until opened), worded as drafted. And ("should we
-- just also back add 1.9.3?", "go") 1.9.3's fix, added afterwards.

local function boot(db)
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {} } }
	for k, v in pairs(db or {}) do BagSmithDB[k] = v end
	local n = M.loadAddon("BagSmith")
	n.version = "1.9.5"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	return n, M
end

;(function()
	local n = boot({ whatsNewSeen = "1.9.4", whatsNewPatchSeen = { ["1.9.4"] = true, ["1.9.2"] = true, ["1.9.1"] = true }, whatsNewButtonSeen = "1.9.4" })
	local WN = n.WhatsNew
	local e = WN.ENTRIES[8]   -- (by design since 1.9.8: three places down, after 1.9.8's, 1.9.7's and 1.9.6's entries)   -- (by design since 1.10.1: one more place down, after 1.10.1's entry)   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
	check(e.v == "1.9.5" and e.heading == "BagSmith 1.9.5" and #e.items == 1, "the 1.9.5 entry, one bullet")
	check(e.items[1] == "|cfffac775Faster and Lighter:|r Global Inventory searches and redraws faster, and BagSmith takes up about a third less space.", "Faster and Lighter, word for word as drafted")
	check(not e.items[1]:find("\226\128\148") and not e.items[1]:find("\226\128\147"), "no em or en dashes")
	local tabs = WN:Tabs()
	check(tabs[1].v == "1.9.0" and #tabs[1].patches == 5 and tabs[1].patches[1].v == "1.9.5" and tabs[1].patches[2].v == "1.9.4" and tabs[1].patches[3].v == "1.9.3" and tabs[1].patches[4].v == "1.9.2", "the 1.9 tab: 1.9.5, 1.9.4, 1.9.3, 1.9.2, 1.9.1")
	local e3 = WN.ENTRIES[10]   -- (by design since 1.9.8: three places down, after 1.9.8's, 1.9.7's and 1.9.6's entries)   -- (by design since 1.10.1: one more place down, after 1.10.1's entry)   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
	check(e3.v == "1.9.3" and e3.heading == "BagSmith 1.9.3" and #e3.items == 1 and e3.items[1] == "|cfffac775Unusable Weapons Too:|r the red tint now also marks weapons, shields and librams, idols or totems your class can't use, like guns and swords on a priest.", "1.9.3's entry, word for word as drafted")
	check(not e3.items[1]:find("\226\128\148") and not e3.items[1]:find("\226\128\147"), "(no dashes in it)")
	check(not WN:Pending(), "from 1.9.4: no pop-up (an update)")
	check(WN:PatchNew(tabs[1].patches[1]) and not WN:PatchNew(tabs[1].patches[2]), "1.9.5 says NEW; 1.9.4, already opened, doesn't")
	check(WN:PatchNew(tabs[1].patches[3]), "1.9.3 says NEW too (never opened: it had no entry)")
	check(WN:ButtonNew(), "Settings' What's New button: NEW")
	n.version = "1.9.4"
	check(#WN:Tabs()[1].patches == 4, "(running 1.9.4: no 1.9.5 entry yet)")
	check((n.errors or 0) == 0, "no errors")
end)()
