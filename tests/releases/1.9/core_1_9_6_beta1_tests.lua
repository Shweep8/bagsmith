-- ======== 1.9.6-beta1 (Shweep, 20 Nov) ========
-- Since client build 71037 the game gives no realm: GetRealmName() and GetNormalizedRealmName() answer "" (Jeor's check
-- in game: `build 71037 realm [] norm [] Player-6925-04D3CC4C`; his character on another ruleset:
-- `Player-6935-044751E2`). Under 1.9.5 that filed the character under "Name - ", so its alts left the tooltips, Global
-- Inventory and the gold totals, it was no longer saved, its saved bank wasn't found and its profile fell to Default.
-- ns:Realm() (Core/Init.lua) now answers in the game's place: the character's own record, its server number, the
-- saved character of its name, or a label made from the server number; nil rather than a guess.

local GUID, GUID2 = "Player-6925-04D3CC4C", "Player-6935-044751E2"
local function char(name, realm, more)
	local e = { name = name, realm = realm, class = "WARRIOR", level = 20, gold = 111, updated = 1,
		items = { { bag = 0, slot = 1, itemID = 90001, count = 7, name = "Linen Cloth", quality = 1, classID = 7 } },
		bank = { { bag = -1, slot = 1, itemID = 97001, count = 3, name = "Banked", quality = 1, classID = 7 } } }
	for k, v in pairs(more or {}) do e[k] = v end
	return e
end
local function usual()
	return { ["Aldren - Forever"] = char("Aldren Thorne", "Forever"), ["Alt1 - Forever"] = char("Alt1", "Forever", { gold = 222 }),
		["Faraway - Elsewhere"] = char("Faraway", "Elsewhere", { gold = 333 }) }
end
local function worn(...) local t = {}; for i, id in ipairs({ ... }) do t[#t + 1] = { slot = i, itemID = id, count = 1 } end; return t end
-- o: realm (the game's answer; "" by default, false for nil), guid (false: the client has no UnitGUID), name, class, level, worn (slot -> item ID), cache, chars, profiles, servers, cdb
local function boot(o)
	o = o or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.charName = o.name or "Aldren Thorne"
	local realm = o.realm
	if realm == nil then realm = "" end
	if realm == false then realm = nil end
	M.realm = realm
	_G.GetRealmName = function() return M.realm end
	_G.GetNormalizedRealmName = function() return M.realm end
	M.guid = o.guid ~= false and (o.guid or GUID) or nil
	if o.guid == false then _G.UnitGUID = nil else _G.UnitGUID = function() return M.guid end end
	M.asked = 0
	_G.UnitClass = function() M.asked = M.asked + 1; return "X", o.class or "WARRIOR" end
	_G.UnitLevel = function() return o.level or 23 end
	_G.GetInventoryItemID = function(_, slot) return (o.worn or {})[slot] end
	M.sizes[1] = 16
	M.put(0, 1, { id = 90001, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5 })
	_G.BagSmithCharDB = o.cdb or { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = o.chars or {}, cache = o.cache or usual(), servers = o.servers,
		profiles = o.profiles or { Default = { view = "list" }, Mine = { view = "icon" }, Other = { view = "list" } } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.9.6-beta1"
	M.fire("ADDON_LOADED", "BagSmith")
	local atLoad = { key = n:CharKey(), profile = (n.Profiles:Active()) }
	M.fire("PLAYER_LOGIN"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	return n, M, atLoad
end
local function count(t) local c = 0; for _ in pairs(t or {}) do c = c + 1 end; return c end
local function keys(t) local k = {}; for key in pairs(t or {}) do k[#k + 1] = tostring(key) end; table.sort(k); return table.concat(k, ", ") end

;(function()
	-- The game answers: everything as before, and what it says is noted for the day it doesn't
	local n, M, atLoad = boot({ realm = "Forever", chars = { ["Aldren - Forever"] = "Mine" } })
	local Inv = n.Inventory
	check(n:CharKey() == "Aldren - Forever" and atLoad.key == "Aldren - Forever" and atLoad.profile == "Mine", "the game answers: the key and the profile as before")
	check(n:Realm() == "Forever" and select(2, n:RealmSource()) == "the game", "the realm is the game's")
	check(#Inv:Characters(false) == 2 and #Inv:Characters(true) == 3, "characters: 2 on this ruleset, 3 with every ruleset")
	local others = Inv:Others()
	n:SaveCache()
	local e = BagSmithDB.cache["Aldren - Forever"]
	check(e.updated ~= 1 and e.realm == "Forever" and e.guid == GUID, "a save: under its key, its realm, stamped with its GUID")
	check(count(BagSmithDB.cache) == 3, "no other entry appears (" .. keys(BagSmithDB.cache) .. ")")
	check(Inv:Others() == others, "a save doesn't throw away the other characters' counts (as before)")
	check(BagSmithDB.servers["6925"] == "Forever" and count(BagSmithDB.servers) == 1, "the server number is learned: 6925 is Forever")
	check(BagSmithCharDB.realm == "Forever" and BagSmithCharDB.realmFor == GUID, "and the character records its realm for itself, with its GUID")
	check((n.errors or 0) == 0, "no errors")
end)()

for _, case in ipairs({ { "", "an empty realm" }, { false, "no realm at all (nil)" } }) do
	-- The outage, fixed: an existing character, its saved data as 1.9.5 left it (no stamp, nothing learned)
	local n, M, atLoad = boot({ realm = case[1], chars = { ["Aldren - Forever"] = "Mine" } })
	local Inv, what = n.Inventory, case[2] .. ": "
	check(atLoad.key == "Aldren - Forever" and n:CharKey() == "Aldren - Forever", what .. "the character is filed where it always was (" .. tostring(atLoad.key) .. ")")
	check(atLoad.profile == "Mine", what .. "its profile is back, from the moment BagSmith loads (" .. tostring(atLoad.profile) .. ")")
	check(#Inv:Characters(false) == 2 and #Inv:Characters(true) == 3, what .. "its alt is back, and nobody is counted twice")
	local g1 = Inv:Gold(false); local g2 = Inv:Gold(true)
	check(#g1 == 2 and #g2 == 3, what .. "gold: 2 rows on this ruleset, 3 for the account")
	check(count(Inv:Others()[90001]) == 1, what .. "the tooltip counts the alt's Linen Cloth")
	check(n:SavedBank() ~= nil and n:IsOwnKey("Aldren - Forever") and not n:IsOwnKey("Alt1 - Forever"), what .. "the saved bank is found; its own entry is its own, the alt's isn't")
	local others = Inv:Others()
	n:SaveCache()
	local e = BagSmithDB.cache["Aldren - Forever"]
	check(e.updated ~= 1 and e.realm == "Forever" and e.guid == GUID, what .. "it is saved again, stamped with its GUID")
	check(count(BagSmithDB.cache) == 3 and BagSmithDB.cache["Aldren - "] == nil, what .. "nothing is filed under \"Aldren - \" (" .. keys(BagSmithDB.cache) .. ")")
	check(Inv:Others() == others, what .. "a save doesn't throw away the other characters' counts")
	n:SaveCache(true)
	check(BagSmithDB.cache["Aldren - Forever"].realm == "Forever" and count(BagSmithDB.cache) == 3, what .. "the logout save too")
	check(BagSmithDB.servers["6925"] == "Forever" and BagSmithCharDB.realm == "Forever", what .. "6925 is learned as Forever, and the character records it")
	local realm, from = n:RealmSource()
	check(realm == "Forever" and from == "its saved character", what .. "/bs check's source: its saved character")
	SlashCmdList.BAGSMITH("check")
	local said
	for i = #M.log, math.max(1, #M.log - 12), -1 do if M.log[i]:find("Realm: Forever %(from its saved character%)") then said = true end end
	check(said and M.log[#M.log]:find("Events this client"), what .. "/bs check says so (and still ends as it did)")
	local before = M.asked
	for _ = 1, 50 do n:CharKey() end
	check(M.asked == before, what .. "worked out once, not on every ask")
	check((n.errors or 0) == 0, what .. "no errors")
end

;(function()
	-- The game's functions missing altogether: the same
	local n = boot({ chars = { ["Aldren - Forever"] = "Mine" } })
	_G.GetRealmName = nil
	check(n:CharKey() == "Aldren - Forever" and n:Realm() == "Forever", "no GetRealmName at all: still Forever")
	n:SaveCache()
	check(BagSmithDB.cache["Aldren - Forever"].updated ~= 1 and (n.errors or 0) == 0, "and a save works")
end)()

;(function()
	-- The next sessions: the character's own record answers, whatever else is saved
	local cache = usual()
	cache["Aldren - Elsewhere"] = char("Aldren Thorne", "Elsewhere")
	local n, M, atLoad = boot({ cache = cache, cdb = { version = 1, firstSeen = {}, realm = "Elsewhere" }, chars = { ["Aldren - Elsewhere"] = "Other" } })
	check(atLoad.key == "Aldren - Elsewhere" and atLoad.profile == "Other", "its own record decides between two saved characters of its name")
	check(select(2, n:RealmSource()) == "its own record" and BagSmithDB.servers["6925"] == "Elsewhere", "(from its own record; and its server number learns from it)")
	-- a record that can't be a realm is no record
	for _, bad in ipairs({ 7, "Unknown", ("x"):rep(65), {} }) do
		local n2 = boot({ cdb = { version = 1, firstSeen = {}, realm = bad } })
		check(n2:CharKey() == "Aldren - Forever" and BagSmithCharDB.realm == "Forever", "a damaged record (" .. type(bad) .. ") is passed over and written again")
	end
	-- a record made by another character (a settings folder copied across) isn't this one's: passed over, rewritten
	local n5 = boot({ cdb = { version = 1, firstSeen = {}, realm = "Elsewhere", realmFor = GUID2 } })
	check(n5:CharKey() == "Aldren - Forever" and BagSmithCharDB.realm == "Forever" and BagSmithCharDB.realmFor == GUID, "another character's record (a copied settings folder) is passed over, and made this one's")
	local n6 = boot({ cache = cache, cdb = { version = 1, firstSeen = {}, realm = "Elsewhere", realmFor = GUID } })
	check(n6:CharKey() == "Aldren - Elsewhere", "its own, stamped as its own: used")
	-- its own record wins over a server number learned otherwise, and doesn't rewrite it
	local n3 = boot({ cdb = { version = 1, firstSeen = {}, realm = "Forever" }, servers = { ["6925"] = "Elsewhere" } })
	check(n3:CharKey() == "Aldren - Forever" and BagSmithDB.servers["6925"] == "Elsewhere", "its own record before the server number; what's learned isn't replaced by what's worked out")
end)()

;(function()
	-- A character with nothing saved, on a server whose realm is known: it joins that ruleset
	local n, M, atLoad = boot({ name = "Newbie", servers = { ["6925"] = "Forever" } })
	local Inv = n.Inventory
	check(atLoad.key == "Newbie - Forever" and select(2, n:RealmSource()) == "its server number", "a new character on a known server: \"Newbie - Forever\"")
	check(#Inv:Characters(false) == 3 and #Inv:Characters(true) == 4, "it sees this ruleset's two characters at once")
	n:SaveCache()
	local e = BagSmithDB.cache["Newbie - Forever"]
	check(e and e.realm == "Forever" and e.guid == GUID and count(BagSmithDB.cache) == 4, "and is saved beside them")
	check(BagSmithCharDB.realm == "Forever", "its own record")
end)()

;(function()
	-- A character with nothing saved, nothing learned: a label from its server number, which the real name replaces
	local n, M, atLoad = boot({ name = "Newbie" })
	local Inv = n.Inventory
	check(atLoad.key == "Newbie - Realm 6925" and n:Realm() == "Realm 6925", "a new character, nothing learned: filed under its server number (" .. tostring(atLoad.key) .. ")")
	check(select(2, n:RealmSource()) == "its server number, as a new character", "(source)")
	check(#Inv:Characters(false) == 1 and #Inv:Characters(true) == 4, "alone on its ruleset for now; everyone with every ruleset")
	n.Profiles:Use("Other")
	n:SaveCache()
	local db = BagSmithDB
	check(db.cache["Newbie - Realm 6925"] and db.cache["Newbie - Realm 6925"].realm == "Realm 6925" and db.chars["Newbie - Realm 6925"] == "Other", "saved, and its profile kept, under that label")
	check(db.servers["6925"] == nil and BagSmithCharDB.realm == "Realm 6925", "a label is never learned as a realm; the character records it")
	local newbieCDB = BagSmithCharDB
	-- a second new character on the same server groups with it
	db.cache["Second - Realm 6925"] = char("Second", "Realm 6925", { guid = "Player-6925-0000AAAA" })
	n.Inventory:Invalidate(true)
	check(#n.Inventory:Characters(false) == 2, "a second new character on that server is on its ruleset")

	-- then an older character of that server logs in: the label becomes the real name everywhere
	local saved = { cache = db.cache, chars = db.chars }
	saved.cache["Newbie - Realm 6925"].updated = 50
	local n2 = boot({ cache = saved.cache, chars = saved.chars })
	local db2 = BagSmithDB
	check(n2:CharKey() == "Aldren - Forever" and db2.servers["6925"] == "Forever", "an older character logs in: 6925 is Forever")
	check(db2.cache["Newbie - Realm 6925"] == nil and db2.cache["Newbie - Forever"] and db2.cache["Newbie - Forever"].realm == "Forever" and db2.cache["Newbie - Forever"].updated == 50, "the new character's saved data moves to \"Newbie - Forever\"")
	check(db2.cache["Second - Forever"] and db2.cache["Second - Realm 6925"] == nil, "the second one's too")
	check(db2.chars["Newbie - Forever"] == "Other" and db2.chars["Newbie - Realm 6925"] == nil, "and its profile link")
	check(#n2.Inventory:Characters(false) == 4, "all four are one ruleset now")

	-- and the new character's next login: its own record still says the label; the name it stands for is used
	local n3, M3, atLoad3 = boot({ name = "Newbie", cache = db2.cache, chars = db2.chars, servers = db2.servers, cdb = newbieCDB })
	check(atLoad3.key == "Newbie - Forever" and atLoad3.profile == "Other", "the new character next time: \"Newbie - Forever\", on its profile")
	check(BagSmithCharDB.realm == "Forever", "its record is brought up to date")
	check((n3.errors or 0) == 0, "no errors")
end)()

;(function()
	-- The label gives way where the real key is already taken: the newer save stays
	local function both(labelTime, realTime)
		local cache = usual()
		cache["Newbie - Realm 6925"] = char("Newbie", "Realm 6925", { updated = labelTime, gold = 5 })
		cache["Newbie - Forever"] = char("Newbie", "Forever", { updated = realTime, gold = 9 })
		boot({ cache = cache, chars = { ["Newbie - Realm 6925"] = "Other", ["Newbie - Forever"] = "Mine" } })
		return BagSmithDB
	end
	local db = both(80, 20)
	check(db.cache["Newbie - Realm 6925"] == nil and db.cache["Newbie - Forever"].gold == 5, "both keys saved: the newer (the labelled one) stays")
	check(db.chars["Newbie - Forever"] == "Mine" and db.chars["Newbie - Realm 6925"] == nil, "a profile link already on the real key stays")
	db = both(20, 80)
	check(db.cache["Newbie - Realm 6925"] == nil and db.cache["Newbie - Forever"].gold == 9, "both keys saved: the newer (the real one) stays")
end)()

;(function()
	-- The same name on two rulesets
	local function two(a, b) local c = usual(); c["Aldren - Forever"] = char("Aldren Thorne", "Forever", a); c["Aldren - Elsewhere"] = char("Aldren Thorne", "Elsewhere", b); return c end
	local n = boot({ cache = two({}, { class = "MAGE" }) })
	check(n:CharKey() == "Aldren - Forever", "two of its name, another class: the one of its class")
	n = boot({ cache = two({}, { level = 40 }) })
	check(n:CharKey() == "Aldren - Forever", "two of its name and class, one a higher level than it is: the other")
	local wearing = { 501, 502, 503, 504, 505 }
	n = boot({ cache = two({ equipped = worn(501, 502, 503, 504, 999) }, { equipped = worn(501, 777, 778) }), worn = wearing })
	check(n:CharKey() == "Aldren - Forever", "two of its name, class and level: the one wearing what it wears (4 of 5 against 1)")
	n = boot({ cache = two({ equipped = worn(777) }, { equipped = worn(501, 502, 503) }), worn = wearing })
	check(n:CharKey() == "Aldren - Elsewhere", "(the other way round)")

	-- no clear winner: nothing is guessed, and BagSmith is as it was under 1.9.5
	for _, case in ipairs({
		{ { equipped = worn(501, 502, 503) }, { equipped = worn(501, 502) }, "3 against 2" },
		{ { equipped = worn(501, 502) }, {}, "2 against none" },
		{ {}, {}, "nothing worn was saved" },
	}) do
		local n2, M2, atLoad2 = boot({ cache = two(case[1], case[2]), worn = wearing, chars = { ["Aldren - Forever"] = "Mine" } })
		local what = "no clear winner (" .. case[3] .. "): "
		check(n2:Realm() == nil and n2:CharKey() == "Aldren - " and atLoad2.profile == "Default", what .. "no realm, the 1.9.5 key")
		local before = M2.asked
		for _ = 1, 50 do n2:CharKey() end
		check(M2.asked == before, what .. "not worked out again on every ask")
		n2:SaveCache()
		check(BagSmithDB.cache["Aldren - Forever"].updated == 1 and BagSmithDB.cache["Aldren - Elsewhere"].updated == 1 and count(BagSmithDB.cache) == 4, what .. "neither is saved over, nothing new is filed")
		check(count(BagSmithDB.servers) == 0 and BagSmithCharDB.realm == "", what .. "nothing learned, nothing recorded")
		check(#n2.Inventory:Characters(false) == 1 and select(1, n2:RealmSource()) == nil and (n2.errors or 0) == 0, what .. "alone, as before; no errors")
	end

	-- the server number settles it once it's known
	n = boot({ cache = two({}, {}), servers = { ["6925"] = "Elsewhere" } })
	check(n:CharKey() == "Aldren - Elsewhere", "two alike, but its server number is known: exact")
	n = boot({ cache = two({}, {}), servers = { ["6935"] = "Elsewhere" } })
	check(n:CharKey() == "Aldren - Forever" and BagSmithDB.servers["6925"] == "Forever", "two alike, the other's realm belongs to another server: this one")
	-- and a stamp
	n = boot({ cache = two({}, { guid = GUID2 }) })
	check(n:CharKey() == "Aldren - Forever", "two alike, one stamped as another character: the other")
	n = boot({ cache = two({ class = "MAGE", level = 60 }, { guid = GUID }) })
	check(n:CharKey() == "Aldren - Elsewhere", "its own stamp: no doubt, whatever else is saved")
end)()

;(function()
	-- Another character's saved data is never taken by name
	local cache = usual()
	cache["Aldren - Forever"].guid = GUID2
	local n = boot({ cache = cache })
	check(n:CharKey() == "Aldren - Realm 6925", "the only one of its name is stamped as another character: this one is new")
	n:SaveCache()
	check(BagSmithDB.cache["Aldren - Forever"].updated == 1 and BagSmithDB.cache["Aldren - Forever"].guid == GUID2 and BagSmithDB.cache["Aldren - Realm 6925"], "the other's data is untouched; this one has its own")
	check(BagSmithDB.servers["6925"] == nil, "and nothing is learned from it")
end)()

;(function()
	-- The GUID arrives after loading (some clients): the name serves at load, and it's settled once the GUID is there
	-- (as boot, but stopping between loading and logging in)
	local o = { chars = { ["Aldren - Forever"] = "Mine" } }
	package.loaded.mock = nil
	local M = require("mock")
	M.charName, M.realm, M.guid, M.asked = "Aldren Thorne", "", nil, 0
	_G.GetRealmName = function() return M.realm end
	_G.GetNormalizedRealmName = _G.GetRealmName
	_G.UnitGUID = function() return M.guid end
	_G.UnitClass = function() M.asked = M.asked + 1; return "X", "WARRIOR" end
	_G.UnitLevel = function() return 23 end
	_G.GetInventoryItemID = function() return nil end
	M.sizes[1] = 16
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = o.chars, cache = usual(), profiles = { Default = {}, Mine = {} } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.9.6-beta1"
	M.fire("ADDON_LOADED", "BagSmith")
	check(n:CharKey() == "Aldren - Forever" and (n.Profiles:Active()) == "Mine", "no GUID yet at load: the name serves, the profile is right")
	check(BagSmithCharDB.realm == "" and count(BagSmithDB.servers) == 0, "not recorded or learned until the GUID is there")
	M.guid = GUID
	M.fire("PLAYER_LOGIN"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	check(n:CharKey() == "Aldren - Forever" and BagSmithCharDB.realm == "Forever" and BagSmithCharDB.realmFor == GUID and BagSmithDB.servers["6925"] == "Forever", "the GUID is there: settled, recorded, learned")
	check((n.errors or 0) == 0, "no errors")

	-- a record that turns out to be another character's is dropped once the GUID can tell
	package.loaded.mock = nil
	M = require("mock")
	M.charName, M.realm, M.guid = "Aldren Thorne", "", nil
	_G.GetRealmName = function() return M.realm end
	_G.UnitGUID = function() return M.guid end
	_G.UnitClass = function() return "X", "WARRIOR" end
	_G.UnitLevel = function() return 23 end
	_G.BagSmithCharDB = { version = 1, firstSeen = {}, realm = "Elsewhere", realmFor = GUID2 }
	_G.BagSmithDB = { version = 2, chars = {}, cache = usual(), profiles = { Default = {} } }
	n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith")
	check(n:CharKey() == "Aldren - Elsewhere" and BagSmithCharDB.realmFor == GUID2, "(at load, no GUID: the record serves for now, untouched)")
	M.guid = GUID
	M.fire("PLAYER_LOGIN"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	check(n:CharKey() == "Aldren - Forever" and BagSmithCharDB.realm == "Forever" and BagSmithCharDB.realmFor == GUID, "the GUID says the record is another character's: Forever, by its saved character")

	-- with the GUID, the server number can correct what the name said at load
	package.loaded.mock = nil
	M = require("mock")
	M.charName, M.realm, M.guid, M.asked = "Aldren Thorne", "", nil, 0
	_G.GetRealmName = function() return M.realm end
	_G.UnitGUID = function() return M.guid end
	_G.UnitClass = function() return "X", "WARRIOR" end
	_G.UnitLevel = function() return 23 end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local cache = usual()
	cache["Aldren - Forever"], cache["Aldren - Elsewhere"] = nil, char("Aldren Thorne", "Elsewhere")
	_G.BagSmithDB = { version = 2, chars = {}, cache = cache, servers = { ["6925"] = "Forever" }, profiles = { Default = {} } }
	n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith")
	check(n:CharKey() == "Aldren - Elsewhere", "(at load, by name: Elsewhere's)")
	M.guid = GUID
	M.fire("PLAYER_LOGIN"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n:SaveCache()
	check(n:CharKey() == "Aldren - Forever" and BagSmithDB.cache["Aldren - Elsewhere"].updated == 1 and BagSmithDB.cache["Aldren - Forever"] ~= nil, "its server is Forever's: filed there, Elsewhere's character left alone")
	check(BagSmithCharDB.realm == "Forever", "and that is what it records")
end)()

;(function()
	-- A client with no UnitGUID: the name still works, and is final; a new character waits, as before
	local n = boot({ guid = false, chars = { ["Aldren - Forever"] = "Mine" } })
	check(n:CharKey() == "Aldren - Forever" and (n.Profiles:Active()) == "Mine" and BagSmithCharDB.realm == "Forever", "no UnitGUID: by name, and recorded")
	n:SaveCache()
	check(BagSmithDB.cache["Aldren - Forever"].updated ~= 1 and BagSmithDB.cache["Aldren - Forever"].guid == nil and count(BagSmithDB.servers or {}) == 0, "saved, with no stamp and nothing learned")
	n = boot({ guid = false, name = "Newbie" })
	n:SaveCache()
	check(n:Realm() == nil and n:CharKey() == "Newbie - " and count(BagSmithDB.cache) == 3, "no UnitGUID, nothing saved: no realm, nothing filed (as under 1.9.5)")
end)()

;(function()
	-- A profile picked while the game had no realm was filed under "Name - ": it follows the character
	local n, M, atLoad = boot({ chars = { ["Aldren - "] = "Other", ["Aldren - Forever"] = "Mine" } })
	check(atLoad.profile == "Other" and BagSmithDB.chars["Aldren - "] == nil and BagSmithDB.chars["Aldren - Forever"] == "Other", "the profile picked during the outage is the one in use, on the real key")
	n = boot({ chars = { ["Aldren - "] = "Other", ["Alt1 - "] = "Mine" } })
	check((n.Profiles:Active()) == "Other" and BagSmithDB.chars["Aldren - Forever"] == "Other" and BagSmithDB.chars["Alt1 - "] == "Mine", "(with no earlier link too; another character's waits for it)")
	n = boot({ realm = "Forever", chars = { ["Aldren - "] = "Other" } })
	check((n.Profiles:Active()) == "Other" and BagSmithDB.chars["Aldren - "] == nil, "and the same if the game answers again")
	n.Profiles:Use("Mine")
	check(BagSmithDB.chars["Aldren - Forever"] == "Mine" and BagSmithDB.chars["Aldren - "] == nil, "a profile picked now goes on the real key")
end)()

;(function()
	-- An older copy of the current character under another key is still dropped; nobody else's is
	local cache = usual()
	cache["Aldren Thorne - Forever"] = char("Aldren Thorne", "Forever")
	local n = boot({ cache = cache })
	n:CachedCharacters()
	check(BagSmithDB.cache["Aldren Thorne - Forever"] == nil and count(BagSmithDB.cache) == 3, "an older copy of this character is dropped, as before (" .. keys(BagSmithDB.cache) .. ")")
end)()

;(function()
	-- The game answers again one day: labels become the real name, and what the game says replaces what was worked out
	local cache = usual()
	cache["Newbie - Realm 6925"] = char("Newbie", "Realm 6925", { guid = GUID })
	local n, M, atLoad = boot({ realm = "Forever", name = "Newbie", cache = cache, cdb = { version = 1, firstSeen = {}, realm = "Realm 6925" },
		chars = { ["Newbie - Realm 6925"] = "Other" }, servers = { ["6935"] = "Forever" } })
	check(atLoad.key == "Newbie - Forever" and atLoad.profile == "Other", "the game answers: the real key, the profile with it")
	check(BagSmithDB.cache["Newbie - Forever"] and BagSmithDB.cache["Newbie - Realm 6925"] == nil and BagSmithCharDB.realm == "Forever", "the labelled data and the record follow")
	check(BagSmithDB.servers["6925"] == "Forever" and BagSmithDB.servers["6935"] == nil, "one realm, one server: the game's word replaces the older pairing")
	-- mid-session too (an answer that arrives late)
	local n2, M2 = boot({ name = "Newbie" })
	n2:SaveCache()
	check(BagSmithDB.cache["Newbie - Realm 6925"] ~= nil, "(a session that started with no answer)")
	M2.realm = "Forever"
	n2:SaveCache()
	check(n2:CharKey() == "Newbie - Forever" and BagSmithDB.cache["Newbie - Forever"] and BagSmithDB.cache["Newbie - Realm 6925"] == nil and #n2.Inventory:Characters(false) == 3, "the answer arrives mid-session: one entry, on the real key, among its ruleset")
	check((n2.errors or 0) == 0, "no errors")
end)()

;(function()
	-- Saved data is never trusted as it comes
	local cache = usual()
	cache["Alt1 - Forever"].guid = 12345
	cache["Faraway - Elsewhere"].guid = "Player-" .. ("9"):rep(80)
	cache["Aldren - Forever"].guid = "Creature-0-1-2"
	local n, M = boot({ realm = "Forever", guid = "Player-1-0000BEEF", cache = cache,
		servers = { ["6925"] = "Forever", abc = "X", [7] = "Y", ["6935"] = "", ["1"] = "Unknown", ["2"] = "Realm 2", ["3"] = "Dup", ["4"] = "Dup", ["5"] = ("y"):rep(65), ["6"] = 12 } })
	check(BagSmithDB.servers["6925"] == nil and BagSmithDB.servers["1"] == "Forever" and count(BagSmithDB.servers) == 1, "the server list: only sound pairs are kept, a realm listed twice is forgotten (" .. keys(BagSmithDB.servers) .. "); then the game's word")
	check(BagSmithDB.cache["Alt1 - Forever"].guid == nil and BagSmithDB.cache["Faraway - Elsewhere"].guid == nil, "a stamp that isn't a GUID is dropped")
	local n2 = boot({ servers = "nonsense", cdb = "nonsense" })
	check(n2:CharKey() == "Aldren - Forever" and (n2.errors or 0) == 0, "a damaged list or record: as if there were none")
	-- and what's kept survives a reload
	local n3 = boot({})
	n3:SaveCache()
	local db, cdb = BagSmithDB, BagSmithCharDB
	local n4 = boot({ cache = db.cache, chars = db.chars, servers = db.servers, cdb = cdb })
	check(BagSmithDB.servers["6925"] == "Forever" and BagSmithDB.cache["Aldren - Forever"].guid == GUID and BagSmithCharDB.realm == "Forever", "the list, the stamp and the record survive a reload")
	check(select(2, n4:RealmSource()) == "its own record", "(and the next session reads its own record)")
end)()

;(function()
	-- What's New: an update under 1.9 (no pop-up), worded as drafted
	local n = boot({ realm = "Forever" })
	BagSmithDB.whatsNewSeen, BagSmithDB.whatsNewPatchSeen, BagSmithDB.whatsNewButtonSeen = "1.9.5", { ["1.9.5"] = true, ["1.9.4"] = true, ["1.9.3"] = true, ["1.9.2"] = true, ["1.9.1"] = true }, "1.9.5"
	local WN = n.WhatsNew
	local e = WN.ENTRIES[1]
	check(e.v == "1.9.6" and e.heading == "BagSmith 1.9.6" and #e.items == 2, "the 1.9.6 entry leads, two bullets")
	check(e.items[1] == "|cfffac775Your Characters Are Back:|r a recent game update hid your other characters from tooltips, Global Inventory and your gold totals. That's fixed, and nothing was lost.", "Your Characters Are Back, word for word")
	check(e.items[2] == "|cfffac775Catching Up:|r each character shows what it had the last time you played it before the update. Log in to it once and it's up to date again.", "Catching Up, word for word")
	local text = table.concat(e.items, " ")
	check(not text:find("\226\128\148") and not text:find("\226\128\147"), "no em or en dashes")
	local tabs = WN:Tabs()
	check(tabs[1].v == "1.9.0" and #tabs[1].patches == 6 and tabs[1].patches[1].v == "1.9.6" and tabs[1].patches[2].v == "1.9.5", "the 1.9 tab: 1.9.6 first of six updates")
	check(not WN:Pending(), "from 1.9.5: no pop-up (an update, as Shweep set it in 1.9.2)")
	check(WN:PatchNew(tabs[1].patches[1]) and not WN:PatchNew(tabs[1].patches[2]) and WN:ButtonNew(), "1.9.6 says NEW, and so does Settings' What's New button")
	n.version = "1.9.5"
	check(#WN:Tabs()[1].patches == 5, "(running 1.9.5: no 1.9.6 entry yet)")
	-- the changelog's section
	local f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	local section = log:match("^(## 1%.9%.6\n.-)\n## 1%.9%.5\n") or ""
	check(section:find("Your other characters are back") and section:find("71037") and not section:find("\226\128\148"), "the changelog's 1.9.6 section says what happened, with no em dash")
	check((n.errors or 0) == 0, "no errors")
end)()
