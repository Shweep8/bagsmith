-- ======== 1.9.8-beta1 (Shweep, 21 Nov) ========
-- "need another hotfix, some items are not showing up in global / tooltips": his Shweepy Thyme showed Shweepy
-- Dreamshade's bank as its own ("those Writ's are only on Shweepy Dreamshade"), and neither listed the other ("I can't
-- see Shweepy Dreamshade's hearthstone"). Forever's characters have a first and a last name, UnitName gives the first
-- alone, and both were filed under "Shweepy - Realm": one saved record, each login writing over the other. So since
-- saved characters began (the same on 1.9.5), not since 1.9.6. A character now takes the usual key only when that
-- record isn't another character's (ns:OwnKey, Core/Init.lua). Also: a saved level above the level read at load no
-- longer rules a saved character out (it could file the character for good under a server-number label), a character
-- so labelled finds its saved self again, and 1.9.7's What's New entry, owed.

local R = "CAMWOW US2 Realm 1 PvE"
local T, D = "Player-6925-0000AAAA", "Player-6925-0000BBBB"
local function rec(name, realm, more)
	local e = { name = name, realm = realm, class = "WARRIOR", level = 20, gold = 111, updated = 1,
		items = { { bag = 0, slot = 1, itemID = 6948, count = 1, name = "Hearthstone", quality = 1, classID = 15 } } }
	for k, v in pairs(more or {}) do e[k] = v end
	return e
end
local WRIT = { bag = -1, slot = 1, itemID = 90030, count = 1, name = "Craftsman's Writ", quality = 1, classID = 12 }
-- o: name, guid (false: the client has no UnitGUID), realm (the game's answer; R by default, "" for none), class,
-- level, cache, chars, profiles, cdb, servers, pvp (what the richer name functions give), late (no GUID while loading)
local function start(o)
	o = o or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.charName = o.name or "Shweepy Thyme"
	M.pvpName = o.pvp
	local realm = o.realm; if realm == nil then realm = R end
	M.realm = realm
	_G.GetRealmName = function() return M.realm end
	M.guid = (o.guid ~= false and not o.late) and (o.guid or T) or nil   -- (late: the function is there, the GUID not yet)
	if o.guid == false then _G.UnitGUID = nil else _G.UnitGUID = function() return M.guid end end
	M.level = o.level or 23
	_G.UnitClass = function() return "X", o.class or "WARRIOR" end
	_G.UnitLevel = function() return M.level end
	_G.GetInventoryItemID = function() return nil end
	M.sizes[1] = 16
	M.put(0, 1, { id = 6948, name = "Hearthstone", q = 1, count = 1, class = 15, subclass = 0 })
	_G.BagSmithCharDB = o.cdb or { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = o.chars or {}, cache = o.cache or {}, servers = o.servers,
		profiles = o.profiles or { Default = { view = "list" }, Mine = { view = "icon" } } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.9.8-beta1"
	M.fire("ADDON_LOADED", "BagSmith")
	return n, M
end
local function boot(o)
	local n, M = start(o)
	local atLoad = { key = n:CharKey(), profile = (n.Profiles:Active()) }
	M.fire("PLAYER_LOGIN"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	return n, M, atLoad
end
local function count(t) local c = 0; for _ in pairs(t or {}) do c = c + 1 end; return c end
local function keys(t) local k = {}; for key in pairs(t or {}) do k[#k + 1] = tostring(key) end; table.sort(k); return table.concat(k, " | ") end
local function names(list) local t = {}; for _, c in ipairs(list) do t[#t + 1] = c.name end; return table.concat(t, ", ") end

;(function()
	-- Two characters who share a first name, from nothing: each gets a record of its own
	local n = boot({ name = "Shweepy Thyme", guid = T })
	n:SaveCache()
	check(n:CharKey() == "Shweepy - " .. R and BagSmithDB.cache["Shweepy - " .. R].guid == T, "the first of them is filed as before, under its first name")
	local db = BagSmithDB
	local n2, M2, atLoad2 = boot({ name = "Shweepy Dreamshade", guid = D, cache = db.cache, chars = db.chars })
	check(atLoad2.key == "Shweepy Dreamshade - " .. R and n2:CharKey() == atLoad2.key, "the second gets a key of its own, from the moment BagSmith loads (" .. tostring(atLoad2.key) .. ")")
	check(not n2:IsOwnKey("Shweepy - " .. R) and n2:SavedBank() == nil, "the first one's record isn't its own; it has no saved bank yet")
	n2:SaveCache(); n2:CachedCharacters()
	local a, b = BagSmithDB.cache["Shweepy - " .. R], BagSmithDB.cache["Shweepy Dreamshade - " .. R]
	check(a and a.name == "Shweepy Thyme" and a.guid == T and a.updated ~= nil, "the first one's record is untouched by the second's save")
	check(b and b.name == "Shweepy Dreamshade" and b.guid == D and count(BagSmithDB.cache) == 2, "the second is saved beside it (" .. keys(BagSmithDB.cache) .. ")")
	local chars = n2.Inventory:Characters(false)
	check(#chars == 2 and names(chars) == "Shweepy Dreamshade, Shweepy Thyme", "each lists the other: " .. names(chars))
	check(count(n2.Inventory:Others()[6948]) == 1, "and counts the other's Hearthstone in tooltips")
	-- each finds its own record again, whichever logs in
	db = BagSmithDB
	local n3 = boot({ name = "Shweepy Thyme", guid = T, cache = db.cache, chars = db.chars })
	check(n3:CharKey() == "Shweepy - " .. R and #n3.Inventory:Characters(false) == 2, "the first, next time: its own key, and it lists the second")
	local n4 = boot({ name = "Shweepy Dreamshade", guid = D, cache = db.cache, chars = db.chars })
	check(n4:CharKey() == "Shweepy Dreamshade - " .. R, "the second, next time: its own key")
	check((n.errors or 0) + (n2.errors or 0) + (n3.errors or 0) + (n4.errors or 0) == 0, "no errors")
end)()

;(function()
	-- An account as 1.9.7 left it: one record, last written by Dreamshade, holding Dreamshade's bank
	local function shared() return { ["Shweepy - " .. R] = rec("Shweepy Dreamshade", R, { guid = D, bank = { WRIT } }), ["Bree - " .. R] = rec("Bree Baggs", R) } end
	local n, M, atLoad = boot({ name = "Shweepy Thyme", guid = T, cache = shared(), chars = { ["Shweepy - " .. R] = "Mine" } })
	check(atLoad.key == "Shweepy Thyme - " .. R, "Thyme no longer takes Dreamshade's record (" .. tostring(atLoad.key) .. ")")
	check(n:SavedBank() == nil, "and no longer shows Dreamshade's bank as its own")
	check(atLoad.profile == "Mine" and BagSmithDB.chars["Shweepy Thyme - " .. R] == "Mine" and BagSmithDB.chars["Shweepy - " .. R] == "Mine", "its profile comes along (the two shared the link)")
	local chars = n.Inventory:Characters(false)
	check(#chars == 3 and names(chars) == "Shweepy Thyme, Bree Baggs, Shweepy Dreamshade", "it lists Dreamshade again, and Bree: " .. names(chars))
	n:SaveCache(); n:CachedCharacters()
	local d = BagSmithDB.cache["Shweepy - " .. R]
	check(d and d.guid == D and d.name == "Shweepy Dreamshade" and d.updated == 1 and d.bank and d.bank[1].itemID == 90030, "Dreamshade's record and bank are left alone")
	check(BagSmithDB.cache["Shweepy Thyme - " .. R] and BagSmithDB.cache["Shweepy Thyme - " .. R].guid == T and count(BagSmithDB.cache) == 3, "Thyme has its own record now")
	-- Dreamshade keeps the record that is its own
	local n2, M2, atLoad2 = boot({ name = "Shweepy Dreamshade", guid = D, cache = shared() })
	check(atLoad2.key == "Shweepy - " .. R and n2:SavedBank() and n2:SavedBank()[1].itemID == 90030, "Dreamshade keeps its record, bank and all")
	check((n.errors or 0) + (n2.errors or 0) == 0, "no errors")
end)()

;(function()
	-- A shared record with no stamp (1.9.5's data): the full names tell them apart
	local function old() return { ["Shweepy - " .. R] = rec("Shweepy Thyme", R, { bank = { WRIT } }) } end
	local n = boot({ name = "Shweepy Dreamshade", guid = D, cache = old() })
	check(n:CharKey() == "Shweepy Dreamshade - " .. R and n:SavedBank() == nil, "no stamp, another full name: a key of its own")
	n:SaveCache()
	check(BagSmithDB.cache["Shweepy - " .. R].name == "Shweepy Thyme" and BagSmithDB.cache["Shweepy - " .. R].updated == 1, "the other's record untouched")
	local n2 = boot({ name = "Shweepy Thyme", guid = T, cache = old() })
	check(n2:CharKey() == "Shweepy - " .. R, "no stamp, its own full name: its record, as before")
	n2:SaveCache()
	check(BagSmithDB.cache["Shweepy - " .. R].guid == T and count(BagSmithDB.cache) == 1, "and its save stamps it")
	-- the GUID not to hand yet (or a client with none): the full names decide, and nothing is written over
	local n3 = boot({ name = "Shweepy Thyme", guid = false, cache = { ["Shweepy - " .. R] = rec("Shweepy Dreamshade", R, { guid = D }) } })
	check(n3:CharKey() == "Shweepy Thyme - " .. R, "no GUID to hold against a stamp: the full names still tell them apart")
	n3:SaveCache()
	check(BagSmithDB.cache["Shweepy - " .. R].guid == D and BagSmithDB.cache["Shweepy - " .. R].updated == 1, "(and the stamped record isn't written over)")
end)()

;(function()
	-- The GUID arrives after loading: the key is settled once it is there
	local n, M = start({ name = "Shweepy", pvp = "Shweepy", late = true, cache = { ["Shweepy - " .. R] = rec("Shweepy", R, { guid = D }) } })
	local early = n:CharKey()
	check(early == "Shweepy - " .. R, "no surname and no GUID yet: the usual key, for now")
	M.guid = T
	M.fire("PLAYER_LOGIN"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	check(n:CharKey() == "Shweepy 0000AAAA - " .. R, "the GUID says the record is another's: a key of its own, by the end of its GUID (" .. n:CharKey() .. ")")
	n:SaveCache()
	check(BagSmithDB.cache["Shweepy - " .. R].guid == D and BagSmithDB.cache["Shweepy - " .. R].updated == 1 and BagSmithDB.cache["Shweepy 0000AAAA - " .. R], "saved under it; the other's record untouched")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- The last check: a save never goes over another character's record, whatever the key
	local n = boot({ name = "Shweepy Thyme", guid = T, cache = { ["Shweepy - " .. R] = rec("Shweepy Dreamshade", R, { guid = D }) } })
	n.OwnKey = function() return "Shweepy - " .. R end
	n:SaveCache()
	check(BagSmithDB.cache["Shweepy - " .. R].guid == D and BagSmithDB.cache["Shweepy - " .. R].updated == 1, "a key that is another character's: nothing saved")
end)()

;(function()
	-- One character, nothing shared: exactly as before
	local n = boot({ name = "Aldren Thorne", guid = T, cache = { ["Aldren - " .. R] = rec("Aldren Thorne", R), ["Alt1 - " .. R] = rec("Alt1", R) } })
	check(n:CharKey() == "Aldren - " .. R and n:IsOwnKey("Aldren - " .. R) and not n:IsOwnKey("Alt1 - " .. R), "an ordinary character keeps its key")
	n:SaveCache(); n:CachedCharacters()
	check(count(BagSmithDB.cache) == 2 and BagSmithDB.cache["Aldren - " .. R].guid == T, "and its record (" .. keys(BagSmithDB.cache) .. ")")
	-- a stale copy of this character under another key is still dropped: by its stamp now
	local cache = { ["Aldren - " .. R] = rec("Aldren Thorne", R, { guid = T }), ["Aldren Thorne - " .. R] = rec("Aldren Thorne", R, { guid = T }), ["Alt1 - " .. R] = rec("Alt1", R, { guid = D }) }
	local n2 = boot({ name = "Aldren Thorne", guid = T, cache = cache })
	n2:CachedCharacters()
	check(n2:CharKey() == "Aldren - " .. R and BagSmithDB.cache["Aldren Thorne - " .. R] == nil and count(BagSmithDB.cache) == 2, "two records with its stamp: the usual key is its own, the copy is dropped")
	-- a surname changed since its record was stamped: still its record
	local n3 = boot({ name = "Aldren Stone", guid = T, cache = { ["Aldren - " .. R] = rec("Aldren Thorne", R, { guid = T }) } })
	check(n3:CharKey() == "Aldren - " .. R, "its stamp outweighs a changed surname")
end)()

;(function()
	-- With no realm from the game (client build 71037): the same, by the server number or the saved character
	local n = boot({ name = "Shweepy Dreamshade", guid = D, realm = "", servers = { ["6925"] = R },
		cache = { ["Shweepy - " .. R] = rec("Shweepy Thyme", R, { guid = T }), ["Bree - " .. R] = rec("Bree Baggs", R) } })
	check(n:CharKey() == "Shweepy Dreamshade - " .. R and #n.Inventory:Characters(false) == 3, "no realm from the game: a key of its own on its ruleset, and it lists the others")
	-- its own stamp is found under its own key
	local n2 = boot({ name = "Shweepy Dreamshade", guid = D, realm = "",
		cache = { ["Shweepy - " .. R] = rec("Shweepy Thyme", R, { guid = T }), ["Shweepy Dreamshade - " .. R] = rec("Shweepy Dreamshade", R, { guid = D }) } })
	check(n2:Realm() == R and n2:CharKey() == "Shweepy Dreamshade - " .. R, "and finds its realm by its own stamp, under its own key")
	-- a saved character with another full name isn't taken for this one
	local n3 = boot({ name = "Shweepy Dreamshade", guid = D, realm = "", cache = { ["Shweepy - " .. R] = rec("Shweepy Thyme", R) } })
	check(n3:Realm() == "Realm 6925" and BagSmithDB.servers["6925"] == nil, "another full name under its first name: not its saved self (a new character, nothing learned)")
	local n4 = boot({ name = "Shweepy Thyme", guid = T, realm = "", cache = { ["Shweepy - " .. R] = rec("Shweepy Thyme", R) } })
	check(n4:Realm() == R and n4:CharKey() == "Shweepy - " .. R, "its own full name: its saved self, as in 1.9.6")
end)()

;(function()
	-- The level read while loading no longer decides
	local n, M = start({ name = "Aldren Thorne", guid = T, realm = "", level = 1,
		cache = { ["Aldren - Forever"] = rec("Aldren Thorne", "Forever"), ["Alt1 - Forever"] = rec("Alt1", "Forever") } })
	check(n:CharKey() == "Aldren - Forever", "the level reads 1 while loading, its saved self is level 20: still its saved self")
	M.level = 23
	M.fire("PLAYER_LOGIN"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n:SaveCache()
	check(n:CharKey() == "Aldren - Forever" and count(BagSmithDB.cache) == 2 and BagSmithCharDB.realm == "Forever" and #n.Inventory:Characters(false) == 2, "and after login: one record, its alt listed")

	-- A character 1.9.6 or 1.9.7 filed under a label finds its saved self again, and everything comes back together
	local cache = {
		["Aldren - Forever"] = rec("Aldren Thorne", "Forever", { updated = 10 }),
		["Aldren - Realm 6925"] = rec("Aldren Thorne", "Realm 6925", { guid = T, updated = 50, gold = 999 }),
		["Second - Realm 6925"] = rec("Second One", "Realm 6925", { guid = D, updated = 40 }),
		["Alt1 - Forever"] = rec("Alt1", "Forever"),
	}
	local n2, M2, atLoad = boot({ name = "Aldren Thorne", guid = T, realm = "", cache = cache, chars = { ["Aldren - Realm 6925"] = "Mine" },
		cdb = { version = 1, firstSeen = {}, realm = "Realm 6925", realmFor = T } })
	check(atLoad.key == "Aldren - Forever" and n2:Realm() == "Forever", "filed under a label by 1.9.7: it finds its saved self on the real realm")
	check(BagSmithDB.servers["6925"] == "Forever" and BagSmithCharDB.realm == "Forever", "the server number is learned, its own record put right")
	local a = BagSmithDB.cache["Aldren - Forever"]
	check(a and a.gold == 999 and a.guid == T and BagSmithDB.cache["Aldren - Realm 6925"] == nil, "its newer save, made under the label, is the one kept")
	check(BagSmithDB.cache["Second - Forever"] and BagSmithDB.cache["Second - Realm 6925"] == nil, "another character filed under the label comes over too")
	check(atLoad.profile == "Mine" and BagSmithDB.chars["Aldren - Forever"] == "Mine", "and its profile")
	check(#n2.Inventory:Characters(false) == 3, "all three are one ruleset again")
	check((n.errors or 0) + (n2.errors or 0) == 0, "no errors")
end)()

;(function()
	-- What's New: 1.9.8's entry, and 1.9.7's, owed; updates under 1.9, no pop-up
	local n = boot({ name = "Aldren Thorne" })
	BagSmithDB.whatsNewSeen, BagSmithDB.whatsNewPatchSeen, BagSmithDB.whatsNewButtonSeen = "1.9.6", { ["1.9.6"] = true, ["1.9.5"] = true, ["1.9.4"] = true, ["1.9.3"] = true, ["1.9.2"] = true, ["1.9.1"] = true }, "1.9.6"
	local WN = n.WhatsNew
	local e, e7 = WN.ENTRIES[1], WN.ENTRIES[2]
	check(e.v == "1.9.8" and e.heading == "BagSmith 1.9.8" and #e.items == 2, "the 1.9.8 entry leads, two bullets")
	check(e.items[1] == "|cfffac775Shared First Names:|r two characters with the same first name, like Mara Swift and Mara Stone, no longer write over each other's saved bags, bank and gold. Each shows on its own in Global Inventory and tooltips.", "Shared First Names, word for word")
	-- (by design since 1.9.8-beta2: Shweep's "Important", in soft red, saying more; the beta2 set has its words)
	check(e.items[2]:find("^|cfff09595Important:|r ") ~= nil, "the second bullet is Important, in soft red")
	check(e7.v == "1.9.7" and e7.heading == "BagSmith 1.9.7" and #e7.items == 2, "then 1.9.7's entry, two bullets")
	check(e7.items[1] == "|cfffac775No Clean Up at Vendors:|r Clean Up Bags When Opened no longer runs when your bags open at a vendor, so your items stay put while you sell. The Clean Up button still works there.", "No Clean Up at Vendors, word for word")
	check(e7.items[2] == "|cfffac775Junk Stays Dimmed:|r with Dim Junk on, junk keeps its greyed look while your bags are being cleaned up.", "Junk Stays Dimmed, word for word")
	local text = table.concat(e.items, " ") .. table.concat(e7.items, " ")
	check(not text:find("\226\128\148") and not text:find("\226\128\147"), "no em or en dashes")
	local tabs = WN:Tabs()
	check(tabs[1].v == "1.9.0" and #tabs[1].patches == 8 and tabs[1].patches[1].v == "1.9.8" and tabs[1].patches[2].v == "1.9.7" and tabs[1].patches[3].v == "1.9.6", "the 1.9 tab: 1.9.8 and 1.9.7 first of eight updates")
	-- (by design since 1.9.8-beta2: this one update opens the card by itself, at Shweep's word; the beta2 set has it)
	check(WN:Pending() and WN:UnseenOpener() == e, "from 1.9.6: 1.9.8's update opens the card by itself; 1.9.7's doesn't")
	check(WN:PatchNew(tabs[1].patches[1]) and WN:PatchNew(tabs[1].patches[2]) and not WN:PatchNew(tabs[1].patches[3]) and WN:ButtonNew(), "both say NEW, and so does Settings' What's New button")
	local f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	local section = ("\n" .. log):match("\n(## 1%.9%.8\n.-)\n## 1%.9%.7\n") or ""
	check(section:find("share a first name") and section:find("visit the bank once") and not section:find("\226\128\148") and not section:find("\226\128\147"), "the changelog's 1.9.8 section says what happened and what to do, with no dashes")
	check((n.errors or 0) == 0, "no errors")
end)()
