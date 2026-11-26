;(function()
	-- ======== 1.8.0-beta7: what characters using a profile share (Shweep) ========
	-- Settings > Profile > Shared Between Characters: each part (Favorites, Custom Sections, Pinned
	-- Sections, Section Order and Hidden Sections, Custom Currencies, Pinned Currencies, Custom Sheets) is shared
	-- unless unchecked; then each character keeps its own copy, and the profile's own values are never written over.
	local function deep(t) if type(t) ~= "table" then return t end local o = {} for k, v in pairs(t) do o[k] = deep(v) end return o end
	local function boot(charName, db, cdb)
		package.loaded.mock = nil
		local M = require("mock")
		M.charName = charName
		_G.BagSmithCharDB = cdb or { version = 1, firstSeen = {} }
		_G.BagSmithDB = db
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M
	end
	-- the game writes the saved data after PLAYER_LOGOUT: a deep copy stands in for that
	local function logout(M) M.fire("PLAYER_LOGOUT"); return deep(_G.BagSmithDB), deep(_G.BagSmithCharDB) end

	-- (beta8, by design) Favorites, Pinned Sections, Custom Currencies and Pinned Currencies are per character by default;
	-- this profile shares currencies and favorites on purpose, to follow one part from shared to unshared
	-- (1.8.0-beta16, by design, audit F1) a character's copies are kept under the profile's id, not its name
	local function ownOf(cdb, db) return cdb.own[db.profiles.Default.profileId] end
	local saved = { version = 2, chars = {}, cache = {}, profiles = { Default = { customCurrencies = { 20558 }, favItems = { 6948 }, shareCurrencies = true, shareFavorites = true } } }
	local n, M = boot("Aldren Thorne", saved)
	check(#n.PROFILE_PARTS == 7 and n.db.shareCurrencies == true and n.db.shareFavorites == true, "seven parts; this profile shares currencies and favorites")
	check(n.db.customCurrencies[1] == 20558, "(setup) the profile tracks Warsong Gulch Marks")

	-- Aldren keeps his own currencies
	n:Set("shareCurrencies", false); M.runTimers()
	check(n.db.customCurrencies[1] == 20558 and ownOf(n.cdb, BagSmithDB).customCurrencies[1] == 20558, "unshared: his own copy starts as the profile's")
	table.insert(n.db.customCurrencies, 6948)
	n.db.favItems[#n.db.favItems + 1] = 1004   -- favorites are still shared
	local db, cdbA = logout(M)
	check(#db.profiles.Default.customCurrencies == 1 and db.profiles.Default.customCurrencies[1] == 20558, "saved: the profile's currencies untouched")
	check(#ownOf(cdbA, db).customCurrencies == 2 and ownOf(cdbA, db).customCurrencies[2] == 6948, "saved: his own copy has the new one")
	check(#db.profiles.Default.favItems == 2, "a shared part saves into the profile as before")
	check(db.profiles.Default.shareCurrencies == false, "the choice belongs to the profile")

	-- another character on the same profile
	local n2, M2 = boot("Brannoc Vale", deep(db))
	check(#n2.db.customCurrencies == 1 and n2.db.customCurrencies[1] == 20558, "Brannoc starts from the profile's currencies, not Aldren's")
	n2.db.customCurrencies[#n2.db.customCurrencies + 1] = 4306
	local db2, cdbB = logout(M2)
	check(#db2.profiles.Default.customCurrencies == 1 and ownOf(cdbB, db2).customCurrencies[2] == 4306, "his change stays his own too")
	check(#n2.db.favItems == 2, "and both see the shared favorites")

	-- Aldren again: his copy is back
	n, M = boot("Aldren Thorne", deep(db2), deep(cdbA))
	check(#n.db.customCurrencies == 2 and n.db.customCurrencies[2] == 6948, "Aldren logs in to his own currencies")
	-- shared again: the profile's; his copy kept for later
	n:Set("shareCurrencies", true); M.runTimers()
	check(#n.db.customCurrencies == 1 and #ownOf(n.cdb, BagSmithDB).customCurrencies == 2, "shared again: the profile's currencies; his copy kept")
	n:Set("shareCurrencies", false); M.runTimers()
	check(#n.db.customCurrencies == 2, "unshared again: his own copy comes back")

	-- switching profiles puts the old profile's own values back first
	local defaultTable = BagSmithDB.profiles.Default
	n.Profiles:Use("Alts"); M.runTimers()
	check(#defaultTable.customCurrencies == 1 and n.profileName == "Alts", "using another profile: Default has its own values back")
	check(BagSmithDB.profiles.Alts.shareCurrencies == false and #n.db.customCurrencies == 2, "a new profile copies what he saw, choice included")
	n.Profiles:Use("Default"); M.runTimers()
	check(#n.db.customCurrencies == 2, "back on Default: his own copy again")

	-- sheets travel with their tabs
	n:Set("shareSheets", false); M.runTimers()
	check(n.db.sheets == ownOf(n.cdb, BagSmithDB).sheets and n.db.tabOrder == ownOf(n.cdb, BagSmithDB).tabOrder, "Custom Sheets: the sheets and the tab order are his together")
	check((n.errors or 0) == 0, "no errors")

	-- damaged saved copies are dropped; copies for a profile that's gone too
	local bad = deep(cdbA)
	ownOf(bad, db2).customCurrencies = "lots"
	ownOf(bad, db2).notAPart = { 1 }
	bad.own.Gone = { favItems = { 1 } }
	n, M = boot("Aldren Thorne", deep(db2), bad)
	check(ownOf(n.cdb, BagSmithDB).notAPart == nil and n.cdb.own.Gone == nil, "an unknown key and a deleted profile's copies are dropped")
	check(#n.db.customCurrencies == 1 and #ownOf(n.cdb, BagSmithDB).customCurrencies == 1, "a damaged copy is dropped: he starts again from the profile's")

	-- the Settings page
	n.SettingsPanel:Show(); n.SettingsPanel:ShowPage("profile"); M.runTimers()
	local seen, labels = 0, {}
	for _, w in ipairs(n.SettingsPanel.pools.check or {}) do if w:IsShown() and w.key and w.key:find("^share") then seen = seen + 1; labels[#labels + 1] = w.text.text end end
	check(seen == 7, "Settings > Profile lists the seven parts: " .. table.concat(labels, ", "))
	n.SettingsPanel:Hide()
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- (beta6 feedback) the special-bag glow sits inside the icon, with its own opacity
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[3] = 6; M.bagNames[3] = "Herb Pouch"
	local realInstant = C_Item.GetItemInfoInstant
	C_Item.GetItemInfoInstant = function(item)
		if type(item) == "string" and item:find("%[Herb Pouch%]") then return 1, "Container", "", "INVTYPE_BAG", 1, 1, 2 end
		return realInstant(item)
	end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", glow_herb = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); n.ui.bagWindows = true; n:RefreshViews(true); M.runTimers(); M.runTimers()
	local cell = n.Buttons.mirrors[n.Window.bagViews[3].child][1]
	local g = cell and cell.bagGlow
	check(g and g:IsShown(), "(setup) an empty herb bag slot glows")
	local p1 = g and g.points and g.points[1]
	check(p1 and p1[2] == cell.icon and p1[1] == "TOPLEFT" and p1[4] > 0 and p1[5] < 0, "the glow sits on the icon's square, a pixel inside, not over the slot's frame")
	check(g.color and g.color[4] == 1 and n.db.glowAlpha_herb == 1, "at full opacity by default")
	n:Set("glowAlpha_herb", 0.4); M.runTimers()
	check(math.abs(g.color[4] - 0.4) < 1e-9, "its own opacity: 40%")
	check(n:Set("glowAlpha_herb", 5) and n.db.glowAlpha_herb == 1 and n:Set("glowAlpha_herb", 0) and n.db.glowAlpha_herb == 0.1, "kept between 10% and 100%")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- (beta7 feedback, Shweep) Special Bag Slot Indicators, in alphabetical order
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local names = {}
	for _, k in ipairs(n:BagKindsSorted()) do names[#names + 1] = n:BagKindName(k.key) end
	check(table.concat(names, ", ") == "Ammo Pouch, Cooking Bag, Enchanting Bag, Engineering Bag, Herb Bag, Leatherworking Bag, Mining Bag, Quiver, Reagent Bag, Soul Bag, Tackle Box, Trinket Bag",
		"alphabetical: " .. table.concat(names, ", "))
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("icons"); M.runTimers()
	local rows, head = {}, false
	for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.key and w.key:find("^glow_") then rows[#rows + 1] = { y = w.points[1] and w.points[1][5] or 0, t = w.text.text } end end
	for _, h in ipairs(P.pools.head or {}) do if h:IsShown() and h.text and h.text.text == "Special Bag Slot Indicators" then head = true end end
	table.sort(rows, function(a, b) return a.y > b.y end)
	local shown = {}
	for _, r in ipairs(rows) do shown[#shown + 1] = r.t end
	check(head, "the heading reads Special Bag Slot Indicators")
	-- (beta9, by design) "indicator" wording
	-- (by design since 1.11.0-beta3: the kinds are a Special Bag list now, in the same order, with the picked kind's
	-- switch under it)
	local listed = {}
	for _, w in ipairs(P.pools.dropdown or {}) do if w:IsShown() and w.key == "bagKindPick" then for _, c in ipairs(w.choices) do listed[#listed + 1] = (c.label:gsub(" %(On%)$", "")) end end end
	check(listed[1] == "Ammo Pouch" and listed[12] == "Trinket Bag" and #shown == 1 and shown[1]:find(" Indicator$"), "Settings lists them in that order: " .. table.concat(listed, " | "))
	P:Hide()
end)()

;(function()
	-- (1.8.0-beta8, Shweep) Settings > Profile: the profile list near the top; "Profile Codes" (was "Share")
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {} } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("profile"); M.runTimers()
	local heads = {}
	for _, h in ipairs(P.pools.head or {}) do if h:IsShown() and h.text then heads[#heads + 1] = { y = h.points[1] and h.points[1][5] or 0, t = h.text.text } end end
	table.sort(heads, function(a, b) return a.y > b.y end)
	local t = {}
	for _, h in ipairs(heads) do t[#t + 1] = h.t end
	check(table.concat(t, " > ") == "Profile: Default > All Profiles > Shared Between Characters > Profile Codes", "the Profile page's order: " .. table.concat(t, " > "))
	P:Hide()
end)()

;(function()
	-- (1.8.0-beta8, Shweep) the defaults: Favorites, Pinned Sections, Custom Currencies and Pinned Currencies are each
	-- character's own; a profile saved before 1.8 takes them, and nothing is lost: each character starts from the profile's
	local function deep(t) if type(t) ~= "table" then return t end local o = {} for k, v in pairs(t) do o[k] = deep(v) end return o end
	local function boot(charName, db, cdb)
		package.loaded.mock = nil
		local M = require("mock")
		M.charName = charName
		_G.BagSmithCharDB = cdb or { version = 1, firstSeen = {} }
		_G.BagSmithDB = db
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M
	end
	local old = { version = 2, chars = {}, cache = {}, profiles = { Default = { favItems = { 6948 }, customCurrencies = { 20558 }, fav = { "i:20558" }, pinnedSections = { Gear = true }, customSections = { { id = "c1", name = "Professions" } } } } }
	local n, M = boot("Aldren Thorne", old)
	check(n.db.shareFavorites == false and n.db.sharePinnedSections == false and n.db.shareCurrencies == false and n.db.sharePinnedCurrencies == false,
		"per character by default: Favorites, Pinned Sections, Custom Currencies, Pinned Currencies")
	check(n.db.shareSections == true and n.db.shareSectionOrder == true and n.db.shareSheets == true, "shared by default: Custom Sections, Section Order, Custom Sheets")
	check(n.db.favItems[1] == 6948 and n.db.customCurrencies[1] == 20558 and n.db.fav[1] == "i:20558" and n.db.pinnedSections.Gear, "his favorites, currencies and pins carried over")
	n.db.favItems[#n.db.favItems + 1] = 1004
	M.fire("PLAYER_LOGOUT")
	local db = deep(BagSmithDB)
	check(#db.profiles.Default.favItems == 1, "a new favorite stays his: the profile's untouched")
	local n2 = boot("Brannoc Vale", deep(db))
	check(#n2.db.favItems == 1 and n2.db.favItems[1] == 6948 and n2.db.customCurrencies[1] == 20558, "another character starts from the profile's, not his")
	-- What's New says so, in soft red
	local card
	for _, e in ipairs(n2.WhatsNew.ENTRIES) do if e.v == "1.8.0" then card = e end end
	local important
	for _, line in ipairs(card and card.items or {}) do if line:find("^|cfff09595Important:|r") then important = line end end
	check(important and important:find("favorites, pinned sections, custom currencies and pinned currencies", 1, true) and important:find("nothing is lost", 1, true),
		"the 1.8 card's Important bullet, in soft red")
	check((n2.errors or 0) == 0, "no errors")
end)()

;(function()
	-- (1.8.0-beta8) Reset and Copy on the profile a character uses replace what it sees, its own copies included
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { favItems = { 6948 } }, Other = { favItems = { 1004, 2589 } } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	check(n.db.shareFavorites == false and n.db.favItems[1] == 6948, "(setup) favorites are his own, from Default's")
	n.db.favItems[#n.db.favItems + 1] = 765
	n.Profiles:CopyFrom("Other"); M.runTimers()
	check(#n.db.favItems == 2 and n.db.favItems[1] == 1004, "Copy: he sees Other's favorites, not his old ones")
	n.Profiles:Reset(); M.runTimers()
	check(#n.db.favItems == 0 and n.db.shareFavorites == false, "Reset: he sees a fresh profile's (none)")
	M.fire("PLAYER_LOGOUT")
	check(#BagSmithDB.profiles.Default.favItems == 0 and #BagSmithDB.profiles.Other.favItems == 2, "saved: Default reset, Other untouched")
	check((n.errors or 0) == 0, "no errors")
end)()
