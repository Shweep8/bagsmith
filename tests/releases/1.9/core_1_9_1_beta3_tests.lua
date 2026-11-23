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
-- ======== 1.9.1-beta3 (Shweep, 18 Nov) ========
-- "I do think point releases getting new tags would be good going forward as well": a point release's additions are
-- NEW even on a page opened in an earlier version of the release. Panel.NEW.added["1.9.1"] holds 1.9.1's (Full-Width
-- Pinned); a page remembers the version it was opened at (an older save's true reads as 1.9.0).

local function boot(newSeen, version)
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {} }, whatsNewSeen = "1.9.0", newSeen = newSeen }
	local n = M.loadAddon("BagSmith"); n.SettingsPanel.NEW = NEW19()
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.version = version or "1.9.1-beta3"
	return n, M, n.SettingsPanel
end
local function navTag(P, page) for _, b in ipairs(P.navButtons) do if b.page == page then return b.newTag and b.newTag:IsShown() or false end end end
local function rowTag(P, key)
	for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.key == key then return w.newTag and w.newTag:IsShown() or false end end
	for _, w in ipairs(P.pools.seg or {}) do if w:IsShown() and w.key == key then return w.newTag and w.newTag:IsShown() or false end end
	for _, w in ipairs(P.pools.step or {}) do if w:IsShown() and w.key == key then return w.newTag and w.newTag:IsShown() or false end end
end
local ALL19 = { general = true, window = true, icons = true, look = true, sections = true, columns = true, sheets = true,
	globalsections = true, globalcols = true, globalsheets = true }

;(function()
	-- updated from 1.9.0, every 1.9 page opened then (an older save's true)
	local seen = {}
	for k in pairs(ALL19) do seen[k] = true end
	local n, M, P = boot({ ["1.9"] = seen })
	P:Show(); P:ShowPage("look"); M.runTimers()
	check(navTag(P, "look"), "Style: NEW again (Full-Width Pinned came in 1.9.1)")
	check(not navTag(P, "general") and not navTag(P, "window") and not navTag(P, "icons"), "the pages with nothing new since: no tag")
	check(rowTag(P, "splitViewPinnedWide") == true, "Full-Width Pinned: NEW")
	check(rowTag(P, "iconLayout") == false and rowTag(P, "footerTextScale") == false, "Icon Layout and Footer Text Size (1.9.0, seen): no tag")
	check(P:InRelease("keys", "splitViewPinnedWide") and P:InRelease("keys", "iconLayout"), "searching \"new\" finds both (the whole release)")
	-- seen now: from the next time Settings opens, gone
	P:Hide(); P:Show(); P:ShowPage("look"); M.runTimers()
	check(BagSmithDB.newSeen["1.9"].look == "1.9.1", "Style remembers 1.9.1, the version it was opened at")
	check(not navTag(P, "look") and rowTag(P, "splitViewPinnedWide") == false, "opened again: no tags on Style")
	check(BagSmithDB.newSeen["1.9"].sheets == true, "pages not opened since keep what they had (Sheets)")
	P:Hide()
	-- saved and loaded back: the version kept, junk dropped
	BagSmithDB.newSeen["1.9"].bad = "nope"; BagSmithDB.newSeen["1.9"].odd = "1.9.1.5"
	local saved = BagSmithDB
	n, M, P = (function()
		package.loaded.mock = nil
		local M2 = require("mock")
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = saved
		local n2 = M2.loadAddon("BagSmith"); n2.SettingsPanel.NEW = NEW19()
		M2.fire("ADDON_LOADED", "BagSmith"); M2.fire("PLAYER_ENTERING_WORLD"); M2.runTimers()
		n2.version = "1.9.1-beta3"
		return n2, M2, n2.SettingsPanel
	end)()
	local s19 = BagSmithDB.newSeen["1.9"]
	check(s19.look == "1.9.1" and s19.sheets == true and s19.bad == nil and s19.odd == nil, "after a reload: \"1.9.1\" and true kept, anything else dropped")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- straight from 1.8: nothing of 1.9 seen, all of it NEW
	local n, M, P = boot({ ["1.8"] = { look = true } })
	P:Show(); P:ShowPage("look"); M.runTimers()
	check(navTag(P, "look") and navTag(P, "general"), "every 1.9 page NEW")
	check(rowTag(P, "splitViewPinnedWide") == true and rowTag(P, "iconLayout") == true, "1.9.0's settings and 1.9.1's both NEW")
	P:Hide()
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- running 1.9.0: 1.9.1's entries don't count yet
	local seen = {}
	for k in pairs(ALL19) do seen[k] = true end
	local n, M, P = boot({ ["1.9"] = seen }, "1.9.0")
	P:Show(); P:ShowPage("look"); M.runTimers()
	check(not navTag(P, "look") and not P:InRelease("keys", "splitViewPinnedWide"), "in 1.9.0, Full-Width Pinned isn't on the list")
	P:Hide()
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- a first install: nothing NEW, 1.9.1's included; /bs new reset brings them all back
	local n, M, P = boot(nil)
	P:MarkAllNewSeen()
	P:Show(); P:ShowPage("look"); M.runTimers()
	check(not navTag(P, "look") and rowTag(P, "splitViewPinnedWide") == false and not navTag(P, "general"), "a first install: nothing NEW")
	check(BagSmithDB.newSeen["1.9"].look == "1.9.1", "(every page marked at 1.9.1)")
	P:ResetNewForTesting()
	check(navTag(P, "look") and rowTag(P, "splitViewPinnedWide") == true and rowTag(P, "iconLayout") == true, "/bs new reset: all of 1.9's NEW again")
	P:Hide()
	check((n.errors or 0) == 0, "no errors")
end)()
