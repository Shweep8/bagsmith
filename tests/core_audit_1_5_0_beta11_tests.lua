;(function()
	-- 1.5.0-beta12: the 1.5.0-beta11 audit's G1. Import Blizzard Picks with a currency hidden under a collapsed header,
	-- never seen this session or saved, and the currency list already cached: the import must show the currency in
	-- the drawer and the footer in that same click, with no other refresh. (The auditor's script, which asserts the
	-- defect, is kept in docs/plugins/audit-1.5.0-beta11/.)
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", fav = {} } } }
	local lookups = 0
	-- one collapsed header; Honor (1901) is pinned in the game's backpack and found only by its ID
	_G.C_CurrencyInfo.GetCurrencyListSize = function() return 1 end
	_G.C_CurrencyInfo.GetCurrencyListInfo = function(i) if i == 1 then return { name = "Player vs. Player", isHeader = true, isHeaderExpanded = false } end end
	_G.C_CurrencyInfo.GetCurrencyInfo = function(id) lookups = lookups + 1; if id == 1901 then return { name = "Honor", quantity = 150, iconFileID = 8, quality = 1 } end end
	_G.C_CurrencyInfo.GetBackpackCurrencyInfo = function(i) return i == 1 and { currencyTypesID = 1901 } or nil end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	n.Drawer:Show()
	local f = n.Drawer.frame
	local function drawerHas(name) for _, r in ipairs(f.rows or {}) do if r:IsShown() and r.name.text == name then return r end end end
	check(#n.Currency:List() == 0 and not drawerHas("Honor") and #n.db.fav == 0, "(control) before the import: the list is cached and empty, Honor isn't shown")
	lookups = 0
	f.import:GetScript("OnClick")(f.import)
	-- no timers, no other events
	local row = drawerHas("Honor")
	local favs = n.Currency:Favorites()
	check(n.IndexOf(n.db.fav, "c:1901") ~= nil and #favs == 1 and favs[1].count == 150, "G1: the import pins Honor, and BagSmith's favorites show it with its balance (150) at once")
	check(row and row.count.text ~= nil and tostring(row.count.text) == "150", "G1: the drawer shows it in the same click")
	check((n.Window.main.favShown or 0) == 1, "G1: and the bag footer shows it, in the same click")
	check(lookups >= 1, "it was found by its ID (the header stays collapsed)")
	-- pinning and unpinning by hand clear the list the same way
	n.Currency:ToggleFavorite("c:1901")
	check(#n.Currency:Favorites() == 0, "unpinning takes it away at once")
	n.Currency:ToggleFavorite("c:1901")
	check(#n.Currency:Favorites() == 1, "pinning it again brings it back at once")
end)()
