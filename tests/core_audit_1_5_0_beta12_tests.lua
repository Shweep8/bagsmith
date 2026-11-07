;(function()
	-- 1.5.0-beta13: the 1.5.0-beta12 audit's G2. A hidden currency found only by its ID, because an imported pin led to
	-- it, must stay in Wallet when unpinned (with its balance, and in the next save), be pinnable again through its
	-- own row, and survive a switch to a profile without the pin; all with no save in between, through the real
	-- drawer controls. (The auditor's script, which asserts the defect, is kept in docs/plugins/audit-1.5.0-beta12/.)
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", fav = {} }, Other = { skin = "modern", fav = {} } } }
	_G.C_CurrencyInfo.GetCurrencyListSize = function() return 1 end
	_G.C_CurrencyInfo.GetCurrencyListInfo = function(i) if i == 1 then return { name = "Player vs. Player", isHeader = true, isHeaderExpanded = false } end end
	_G.C_CurrencyInfo.GetCurrencyInfo = function(id) if id == 1901 then return { name = "Honor", quantity = 150, iconFileID = 8, quality = 1 } end end
	_G.C_CurrencyInfo.GetBackpackCurrencyInfo = function(i) return i == 1 and { currencyTypesID = 1901 } or nil end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	n.Drawer:Show()
	local f = n.Drawer.frame
	local function rowFor(name) for _, r in ipairs(f.rows or {}) do if r:IsShown() and r.name.text == name then return r end end end
	f.import:GetScript("OnClick")(f.import)
	local r = rowFor("Honor")
	check(r and n.Currency:IsFavorite("c:1901"), "(control) Import Blizzard Picks: Honor, found by its ID, is pinned")
	-- unpin with the row's own control, no save in between
	r.star:GetScript("OnClick")(r.star)
	M.runTimers()
	r = rowFor("Honor")
	check(not n.Currency:IsFavorite("c:1901") and r and tostring(r.count.text) == "150", "G2: unpinned, Honor stays in the drawer's Wallet with its balance (150)")
	check(n.Currency:Snapshot()["c:1901"] and n.Currency:Snapshot()["c:1901"].count == 150, "G2: and in the snapshot")
	n:SaveCache()
	check(BagSmithDB.cache[n:CharKey()].currencies["c:1901"] and BagSmithDB.cache[n:CharKey()].currencies["c:1901"].count == 150, "G2: and the next save records it")
	-- pin it again with that row's control
	r.star:GetScript("OnClick")(r.star)
	check(n.Currency:IsFavorite("c:1901") and #n.Currency:Favorites() == 1, "G2: its row's pin button pins it again")
	-- a switch to a profile without the pin, before any save of a fresh session
	package.loaded.mock = nil
	M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", fav = {} }, Other = { skin = "modern", fav = {} } } }
	_G.C_CurrencyInfo.GetCurrencyListSize = function() return 1 end
	_G.C_CurrencyInfo.GetCurrencyListInfo = function(i) if i == 1 then return { name = "Player vs. Player", isHeader = true, isHeaderExpanded = false } end end
	_G.C_CurrencyInfo.GetCurrencyInfo = function(id) if id == 1901 then return { name = "Honor", quantity = 150, iconFileID = 8, quality = 1 } end end
	_G.C_CurrencyInfo.GetBackpackCurrencyInfo = function(i) return i == 1 and { currencyTypesID = 1901 } or nil end
	n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	n.Drawer:Show()
	f = n.Drawer.frame
	f.import:GetScript("OnClick")(f.import)
	n.Profiles:Use("Other"); M.runTimers()
	check(not n.Currency:IsFavorite("c:1901") and n.Currency:Snapshot()["c:1901"] and n.Currency:Snapshot()["c:1901"].count == 150, "G2: after switching to a profile without the pin, Honor is still listed with its balance")
end)()
