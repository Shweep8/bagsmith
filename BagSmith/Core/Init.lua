--[[
	BagSmith - Core/Init.lua
	Namespace, client detection, shared constants, event dispatcher, combat queue.
--]]

local ADDON, ns = ...
_G.BagSmith = ns   -- (BagSmith's namespace, for its own tests and tooling; not a public contract: other addons use BagSmith.API)

ns.name = ADDON
ns.version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"

------------------------------------------------------------------------
-- Client detection. Forever reports WOW_PROJECT_MAINLINE, so use the
-- interface number and the [Game] TOC variable ("Camelot").
------------------------------------------------------------------------
local _, build, _, interface = GetBuildInfo()
ns.startup = {}
ns.build = build
ns.interface = tonumber(interface) or 0
ns.gameToken = C_AddOns.GetAddOnMetadata(ADDON, "X-Game")
ns.isForever = (ns.gameToken == "Camelot") or (ns.interface >= 16000 and ns.interface < 20000)

------------------------------------------------------------------------
-- Bag constants
------------------------------------------------------------------------
ns.BACKPACK = Enum.BagIndex and Enum.BagIndex.Backpack or 0
ns.NUM_BAGS = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
ns.REAGENT_BAG = (Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
ns.HAS_REAGENT_SLOT = ns.NUM_BAGS >= ns.REAGENT_BAG
ns.BANK = BANK_CONTAINER or (Enum.BagIndex and Enum.BagIndex.Bank) or -1

-- Bank bag slots: the constant is missing on some clients, so fall back to
-- the modern constants table and finally to the classic count of 6.
ns.NUM_BANK_BAGS = NUM_BANKBAGSLOTS
	or (Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBankBagSlots)
	or (Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumCharacterBankSlots)
	or 6

-- Keyring. Only trust it when the client gives us a real bag ID.
-- (1.7.5-beta1, Shweep's probe on Forever: container -1 has 32 slots and holds the keys; the bank's own slots are
-- container 6, a placeholder tab bag, and its bags follow.) On Forever, Enum.BagIndex.Keyring reads -1, the old
-- bank number, and until 1.7.5 that collision made BagSmith drop the keyring and read the keys as bank items (their
-- 32 slots counted as bank space). When the bank is Forever's tabs (C_Bank), -1 is the keyring, not the bank:
-- ns.BANK is then nil, so the bank is only its tabs (ns.BANK_BAGS) and nothing treats -1 as the bank.
-- ns.KEYRING_WAS_BANK marks this, so data saved before 1.7.5 can drop the keys it filed under the bank.
ns.KEYRING = nil
do
	local candidate = KEYRING_CONTAINER or (Enum.BagIndex and Enum.BagIndex.Keyring)
	local bankTabs = type(C_Bank) == "table" and type(C_Bank.FetchNumPurchasedBankTabs) == "function"
		and type(C_Bank.PurchaseBankTab) == "function"
	local answers = function(bag)
		-- Final proof: the container API must answer for it.
		local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
		return ok and type(slots) == "number"
	end
	if candidate and candidate ~= ns.BACKPACK then
		if candidate ~= ns.BANK then
			if (type(GetKeyRingSize) == "function" or type(HasKey) == "function") and answers(candidate) then ns.KEYRING = candidate end
		elseif bankTabs and answers(candidate) then
			ns.KEYRING = candidate
			ns.KEYRING_WAS_BANK = candidate
			ns.BANK = nil
		end
	end
	ns.startup.keyringCandidate = candidate
end

ns.BAGS = {}
for bag = ns.BACKPACK, ns.NUM_BAGS do ns.BAGS[#ns.BAGS + 1] = bag end
if ns.KEYRING then ns.BAGS[#ns.BAGS + 1] = ns.KEYRING end

ns.BANK_BAGS = {}
if ns.BANK then ns.BANK_BAGS[1] = ns.BANK end
for i = 1, ns.NUM_BANK_BAGS do ns.BANK_BAGS[#ns.BANK_BAGS + 1] = ns.NUM_BAGS + i end

ns.ALL_BAGS = {}
for _, b in ipairs(ns.BAGS) do ns.ALL_BAGS[#ns.ALL_BAGS + 1] = b end
for _, b in ipairs(ns.BANK_BAGS) do ns.ALL_BAGS[#ns.ALL_BAGS + 1] = b end

ns.MAX_SLOTS_FLOOR = 18

function ns:IsReagentBag(bag) return ns.HAS_REAGENT_SLOT and bag == ns.REAGENT_BAG end
function ns:IsBankBag(bag)
	if bag == ns.BANK then return true end
	return bag > ns.NUM_BAGS and bag <= ns.NUM_BAGS + ns.NUM_BANK_BAGS
end

function ns:BagName(bag)
	if bag == ns.BACKPACK then return BACKPACK_TOOLTIP or "Backpack" end
	if bag == ns.KEYRING then return KEYRING or "Keyring" end
	-- The bank's own slots: the window already says "Bank".
	if bag == ns.BANK then return "Default" end
	local ok, invID = pcall(C_Container.ContainerIDToInventoryID, bag)
	if not ok then invID = nil end
	-- Forever's C_Bank tabs: the bag in each tab lives in its own inventory slot.
	if not invID and ns:IsBankBag(bag) and ns.Bank and ns.Bank.InvSlot then invID = ns.Bank:InvSlot(bag - ns.NUM_BAGS) end
	local link = invID and GetInventoryItemLink("player", invID)
	if link then
		local name = link:match("%[(.-)%]")
		-- Forever's bank tabs hold a hidden placeholder "bag" marked (DNT);
		-- those are the bank's own slots, not a bag the player placed.
		if name and ns:IsBankBag(bag) and (name:find("%(DNT%)") or name:find("Bank Tab Bag")) then return "Default" end
		if name and name ~= "" then return name end
	end
	if ns:IsReagentBag(bag) then return "Reagent bag" end
	if ns:IsBankBag(bag) then return ("Bank bag %d"):format(bag - ns.NUM_BAGS) end
	return ("Bag %d"):format(bag)
end

-- (1.8.0-beta5, a player's request via Shweep) Special bags: which kind of bag each one is, for the free-slot breakdown
-- and the optional inner glow. A bag's kind comes from its item's class and subclass, the types Forever defines
-- (Shweep's probe, 15 Nov: C_Item.GetItemSubClassInfo; a Herb Pouch hovered at a vendor read family 32, class 1,
-- subclass 2). The family the container reports can't tell them apart: the reagent bag reports 0, as an ordinary bag
-- does. Ordinary bags (1, 0) have no kind. Each kind's name is the game's own (translated), else the English one;
-- color is its default glow color (Settings > Item Icons > Special Bags; every glow is off until turned on).
ns.BAG_KINDS = {
	{ key = "quiver", class = 11, sub = 2, name = "Quiver", color = "d9b26f" },
	{ key = "ammo", class = 11, sub = 3, name = "Ammo Pouch", color = "c08552" },
	{ key = "soul", class = 1, sub = 1, name = "Soul Bag", color = "a77be0" },
	{ key = "herb", class = 1, sub = 2, name = "Herb Bag", color = "6cc44f" },
	{ key = "enchanting", class = 1, sub = 3, name = "Enchanting Bag", color = "6d9cf2" },
	{ key = "engineering", class = 1, sub = 4, name = "Engineering Bag", color = "e8913f" },
	{ key = "mining", class = 1, sub = 6, name = "Mining Bag", color = "aab0b8" },
	{ key = "leatherworking", class = 1, sub = 7, name = "Leatherworking Bag", color = "b07d52" },
	{ key = "fishing", class = 1, sub = 9, name = "Tackle Box", color = "4fc0d6" },
	{ key = "cooking", class = 1, sub = 10, name = "Cooking Bag", color = "e6c75a" },
	{ key = "trinket", class = 1, sub = 12, name = "Trinket Bag", color = "e06aa8" },
	{ key = "reagent", class = 1, sub = 11, name = "Reagent Bag", color = "46c7a8" },
}
ns.BAG_KIND = {}
do
	local byType = {}
	for _, k in ipairs(ns.BAG_KINDS) do ns.BAG_KIND[k.key] = k; byType[k.class * 100 + k.sub] = k.key end
	ns.BAG_KIND_BY_TYPE = byType
end
-- The kind's name in the game's language.
function ns:BagKindName(key)
	local k = ns.BAG_KIND[key]
	if not k then return nil end
	if k.localName == nil then
		local f = (C_Item and C_Item.GetItemSubClassInfo) or GetItemSubClassInfo
		local ok, name = false, nil
		if type(f) == "function" then ok, name = pcall(f, k.class, k.sub) end
		k.localName = (ok and type(name) == "string" and name ~= "" and not name:find("OBSOLETE")) and name or false
	end
	return k.localName or k.name
end
-- The kind of bag in a container slot, or nil for an ordinary bag, the backpack, the keyring and the bank's own slots.
function ns:BagKind(bag)
	if type(bag) ~= "number" or bag == ns.BACKPACK or bag == ns.KEYRING or bag == ns.BANK then return nil end
	if ns:IsReagentBag(bag) then return "reagent" end
	local okC, inv = pcall(C_Container.ContainerIDToInventoryID, bag)
	if not okC then inv = nil end
	if not inv and ns:IsBankBag(bag) and ns.Bank and ns.Bank.InvSlot then inv = ns.Bank:InvSlot(bag - ns.NUM_BAGS) end
	local link = inv and GetInventoryItemLink("player", inv)
	if not link then return nil end
	local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
	if type(info) ~= "function" then return nil end
	local ok, _, _, _, _, _, class, sub = pcall(info, link)
	if not ok or type(class) ~= "number" or type(sub) ~= "number" then return nil end
	return ns.BAG_KIND_BY_TYPE[class * 100 + sub]
end
-- (beta7 feedback, Shweep) The kinds in alphabetical order of the names the game shows (Settings and the free-slot
-- tooltip list them this way, in any language).
function ns:BagKindsSorted()
	local list = {}
	for _, k in ipairs(ns.BAG_KINDS) do list[#list + 1] = k end
	table.sort(list, function(a, b) return ns:BagKindName(a.key):lower() < ns:BagKindName(b.key):lower() end)
	return list
end
-- A kind's glow color as r, g, b (the profile's choice, else the default).
function ns:BagKindColor(key)
	local hex = ns.db and ns.db["glowColor_" .. key] or (ns.BAG_KIND[key] and ns.BAG_KIND[key].color) or "ffffff"
	local r, g, b = hex:match("^(%x%x)(%x%x)(%x%x)$")
	if not r then return 1, 1, 1 end
	return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

-- (1.7.5-beta1, Shweep's report: the wheel skipped past too much content) One mouse wheel notch moves every
-- BagSmith list a set distance: two rows of a list, one row of icons. The game's scroll frames move half the visible
-- height a notch, which in a tall window skipped past whole sections. step is pixels, or a function that returns
-- them (for a list whose rows change height); range, when given, returns how far the list may scroll.
ns.WHEEL_ROWS = 2
function ns.WheelStep(sf, step, range)
	if not (sf and sf.SetScript) then return end
	if sf.EnableMouseWheel then sf:EnableMouseWheel(true) end
	sf.bsWheelStep = step
	sf:SetScript("OnMouseWheel", function(s, delta)
		local px = type(step) == "function" and step(s) or step
		px = math.max(1, tonumber(px) or 20)
		local limit = range and range(s)
		if limit == nil and s.GetVerticalScrollRange then limit = s:GetVerticalScrollRange() end
		if limit == nil then
			local child = s.GetScrollChild and s:GetScrollChild()
			limit = child and child.GetHeight and s.GetHeight and ((child:GetHeight() or 0) - (s:GetHeight() or 0)) or 0
		end
		local now = s:GetVerticalScroll() or 0
		local new = math.max(0, math.min(math.max(0, limit), now - (delta or 0) * px))
		-- The template's scrollbar moves the list when its value changes; set both so they agree either way.
		local bar = s.ScrollBar
		if bar and bar.SetValue then bar:SetValue(new) end
		if math.abs((s:GetVerticalScroll() or 0) - new) > 0.5 then s:SetVerticalScroll(new) end
	end)
end

-- Forever characters have a first and a last name. The plain UnitName API
-- returns only the first word, so try the richer APIs and accept a result
-- that looks like "First Last" (two words, both capitalised, no title
-- punctuation). Falls back to the first name.
function ns:DisplayName(unit)
	unit = unit or "player"
	local first = UnitName(unit) or "Unknown"
	local candidates = {}
	if C_PlayerInfo then
		for _, fn in ipairs({ "GetPlayerFullName", "GetFullName", "GetPlayerName" }) do
			if type(C_PlayerInfo[fn]) == "function" then
				local ok, v = pcall(C_PlayerInfo[fn], unit)
				if ok and type(v) == "string" then candidates[#candidates + 1] = v end
			end
		end
	end
	if type(UnitFullName) == "function" then
		local ok, v = pcall(UnitFullName, unit)
		if ok and type(v) == "string" then candidates[#candidates + 1] = v end
	end
	if type(GetUnitName) == "function" then
		local ok, v = pcall(GetUnitName, unit, false)
		if ok and type(v) == "string" then candidates[#candidates + 1] = v end
	end
	if type(UnitPVPName) == "function" then
		local ok, v = pcall(UnitPVPName, unit)
		if ok and type(v) == "string" then candidates[#candidates + 1] = v end
	end
	for _, v in ipairs(candidates) do
		local a, b = v:match("^(%S+) (%S+)$")
		if a and b and a == first and not b:find("[,%.]") and b:sub(1, 1) ~= b:sub(1, 1):lower() then
			return v
		end
	end
	return first
end

-- What a character's saved data and profile are filed under: "Name - Realm". (1.9.6) The realm is ns:Realm()'s
-- answer (below, after the events); while it has none, the game's own, as before, even an empty one.
function ns:CharKey(name, realm)
	if realm == nil then
		realm = ns:Realm()
		if realm == nil then
			realm = GetRealmName and GetRealmName()
			if type(realm) ~= "string" then realm = "Unknown" end
		end
	end
	return (name or UnitName("player") or "Unknown") .. " - " .. realm
end

------------------------------------------------------------------------
-- Output
------------------------------------------------------------------------
local PREFIX = "|cfffac775BagSmith|r "
function ns:Print(fmt, ...)
	local msg = select("#", ...) > 0 and fmt:format(...) or tostring(fmt)
	local cf = DEFAULT_CHAT_FRAME or ChatFrame1
	cf:AddMessage(PREFIX .. msg)
end
function ns:Debug(fmt, ...)
	if ns.db and ns.db.debug then
		ns:Print("|cff8f8c83" .. (select("#", ...) > 0 and fmt:format(...) or tostring(fmt)) .. "|r")
	end
end

-- Money strings are formatted once per distinct value (bounded cache).
local moneyCache, moneyCount = {}, 0
function ns.Money(copper)
	if not copper or copper <= 0 then return "" end
	local s = moneyCache[copper]
	if not s then
		s = GetMoneyString(copper, true)
		if moneyCount > 400 then moneyCache, moneyCount = {}, 0 end
		moneyCache[copper] = s; moneyCount = moneyCount + 1
	end
	return s
end

------------------------------------------------------------------------
-- Events and signals
------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local handlers, signals = {}, {}
-- Handlers are wrapped: one failing handler must never stop the others, and
-- the first error of each kind is reported so a silent failure is impossible.
local reported = {}
function ns:Guard(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		ns.errorLog = ns.errorLog or {}
		if #ns.errorLog < 20 then ns.errorLog[#ns.errorLog + 1] = label .. ": " .. tostring(err) end
		if not reported[label] then
			reported[label] = true
			ns.errors = (ns.errors or 0) + 1
			ns:Print("|cffff6060Error in %s:|r %s", label, tostring(err))
			ns:Print("Type /bs errors to list them, and please report them.")
		end
	end
	return ok
end

frame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do ns:Guard(event, list[i], ...) end
end)
-- Events differ between clients; an unknown one must not stop the rest of
-- a handler from registering. Skipped names are listed by /bs check.
ns.skippedEvents = {}
function ns:On(event, fn)
	if not handlers[event] then
		local ok = pcall(frame.RegisterEvent, frame, event)
		if not ok then
			ns.skippedEvents[#ns.skippedEvents + 1] = event
			return false
		end
		handlers[event] = {}
	end
	table.insert(handlers[event], fn)
	return true
end
function ns:OnSignal(name, fn)
	signals[name] = signals[name] or {}
	table.insert(signals[name], fn)
end
function ns:Fire(name, ...)
	local list = signals[name]
	if not list then return end
	for i = 1, #list do ns:Guard(name, list[i], ...) end
end

------------------------------------------------------------------------
-- The realm (1.9.6)
------------------------------------------------------------------------
-- Which ruleset the character you're playing is on: what its saved data is filed under ("Name - Realm") and what
-- decides which of your characters count as "this ruleset". The game's own answer whenever it gives one. Since client
-- build 71037 GetRealmName() (and GetNormalizedRealmName()) answer "" (Jeor's check in game, 20 Nov), which hid every
-- alt, stopped the saves and dropped profiles to Default. So, without the game's answer, in this order:
--   1. what this character recorded for itself (BagSmithCharDB.realm: the game's own per-character file), unless the
--      record was made by another character (realmFor, its GUID: a settings folder copied from one to another);
--   2. the realm learned for its server number, the middle of its GUID ("Player-6925-04D3CC4C" is server 6925; the
--      number differs by ruleset, Jeor's two characters: 6925 and 6935), kept for the account in BagSmithDB.servers;
--   3. the realm a saved character of its name is filed under, when only one of them can be this character: the same
--      class, not a higher level, not stamped with another character's GUID, not on a realm that belongs to another
--      server number. With several left, the one whose saved gear is clearly what's worn now, or none;
--   4. for a character with nothing saved (a new one, a new install), a label made from the server number: characters
--      on one server still group together, and the label gives way to the real name the moment that's learned.
-- nil when none of these answers (yet): nothing is ever filed under a guess, and BagSmith behaves as it did before.
-- The realm is only compared, never shown.
local realmKnown     -- this session's answer once worked out without the game (the game itself is asked every time)
local realmStuck     -- no answer was found: not worked out again until RealmRetry (login, entering the world, a save)
local realmTaught    -- the game's answer that was last recorded (once a session is enough)
local realmSettled   -- the answer the rest of BagSmith was last told about
local realmUnsure    -- worked out before the GUID was to be had (some clients have it only after loading): the answer
                     -- serves for now, isn't recorded, and is worked out again once the GUID is there
local function soundRealm(r) return type(r) == "string" and r ~= "" and #r <= 64 and r ~= "Unknown" end
local function serverLabel(server) return "Realm " .. server end
local function labelServer(realm) return type(realm) == "string" and realm:match("^Realm (%d+)$") or nil end
ns.RealmLabelServer = labelServer
-- The player's GUID and the server number inside it (nil when the client has none to give).
local function playerGUID()
	if type(UnitGUID) ~= "function" then return nil end
	local ok, g = pcall(UnitGUID, "player")
	if not ok or type(g) ~= "string" or #g > 64 then return nil end
	return g, g:match("^Player%-(%d+)%-")
end
ns.PlayerGUID = playerGUID
local function serverMap()
	local db = rawget(_G, "BagSmithDB")
	if type(db) ~= "table" then return nil end
	if type(db.servers) ~= "table" then db.servers = {} end
	return db.servers
end
local function serverOf(map, realm)
	local s = labelServer(realm)
	if s then return s end
	for server, r in pairs(map or {}) do if r == realm then return server end end
end
-- A label made from a server number becomes that server's real name: saved characters and profile links are filed
-- under the new key. Where the real key is already taken (the same character, saved both ways), the newer one stays.
local function relabel(from, to)
	local db = rawget(_G, "BagSmithDB")
	if type(db) ~= "table" then return end
	local suffix = " - " .. from
	local function renamed(key)
		if type(key) == "string" and #key > #suffix and key:sub(-#suffix) == suffix then return key:sub(1, #key - #from) .. to end
	end
	local moves = {}
	for key, data in pairs(type(db.cache) == "table" and db.cache or {}) do
		if type(data) == "table" and data.realm == from and renamed(key) then moves[#moves + 1] = key end
	end
	for _, key in ipairs(moves) do
		local data, new = db.cache[key], renamed(key)
		local there = db.cache[new]
		db.cache[key] = nil
		if type(there) ~= "table" or (tonumber(data.updated) or 0) >= (tonumber(there.updated) or 0) then
			data.realm = to
			db.cache[new] = data
		end
	end
	moves = {}
	for key in pairs(type(db.chars) == "table" and db.chars or {}) do if renamed(key) then moves[#moves + 1] = key end end
	for _, key in ipairs(moves) do
		local new = renamed(key)
		if db.chars[new] == nil then db.chars[new] = db.chars[key] end
		db.chars[key] = nil
	end
end
-- This server number stands for this realm. One realm, one server: what the game itself said (sure) replaces an
-- older pairing; anything worked out from saved data never does.
local function learnServer(server, realm, sure)
	local map = serverMap()
	if not (map and server and soundRealm(realm)) or labelServer(realm) or map[server] == realm then return end
	if map[server] and not sure then return end
	for s, r in pairs(map) do
		if r == realm and s ~= server then
			if not sure then return end
			map[s] = nil
		end
	end
	map[server] = realm
	relabel(serverLabel(server), realm)
end
-- The answer is in: this character records it for itself, and a profile it was given while the game had no realm
-- (filed under "Name - ") moves to its real key. The counts kept under the old key are dropped.
local function settleRealm(realm, unsure)
	if ns.cdb and not unsure then
		if ns.cdb.realm ~= realm then ns.cdb.realm = realm end
		local guid = playerGUID()
		if guid and ns.cdb.realmFor ~= guid then ns.cdb.realmFor = guid end
	end
	if realmSettled == realm then return end
	realmSettled = realm
	local db, name = rawget(_G, "BagSmithDB"), UnitName and UnitName("player")
	if type(db) == "table" and type(db.chars) == "table" and type(name) == "string" and name ~= "" then
		local blank, real = name .. " - ", name .. " - " .. realm
		if db.chars[blank] ~= nil then
			db.chars[real] = db.chars[blank]
			db.chars[blank] = nil
		end
	end
	if ns.Inventory and ns.Inventory.Invalidate then ns.Inventory:Invalidate(true) end
end
-- Step 3: the realm of the one saved character that can be this one, or nil.
local function savedRealm(name, guid, server)
	local db = rawget(_G, "BagSmithDB")
	if type(db) ~= "table" or type(db.cache) ~= "table" then return nil end
	local map = serverMap()
	local class, level
	if UnitClass then class = select(2, UnitClass("player")) end
	if UnitLevel then level = UnitLevel("player") end
	if type(level) ~= "number" or level < 1 then level = nil end
	local found = {}
	for key, data in pairs(db.cache) do
		if type(data) == "table" and soundRealm(data.realm) and key == name .. " - " .. data.realm then
			if guid and data.guid == guid then return data.realm end   -- its own stamp: no doubt
			local ok = true
			if type(class) == "string" and type(data.class) == "string" and data.class ~= class then ok = false end
			if ok and level and type(data.level) == "number" and data.level > level then ok = false end
			-- (another character's stamp; or this character's GUID isn't to be had yet, so it can't be told: later)
			if ok and type(data.guid) == "string" then ok = false end
			if ok and server then
				local theirs = serverOf(map, data.realm)
				if theirs and theirs ~= server then ok = false end
			end
			if ok then found[#found + 1] = data end
		end
	end
	if #found == 1 then return found[1].realm end
	if #found < 2 then return nil, #found end
	-- several: the one wearing what this character wears (three items or more, and twice any other's), or none
	local worn = {}
	if type(GetInventoryItemID) == "function" then
		for slot = 1, 19 do local id = GetInventoryItemID("player", slot); if id then worn[id] = true end end
	end
	local best, most, second = nil, 0, 0
	for _, data in ipairs(found) do
		local n, seen = 0, {}
		for _, r in ipairs(type(data.equipped) == "table" and data.equipped or {}) do
			if type(r) == "table" and r.itemID and worn[r.itemID] and not seen[r.itemID] then seen[r.itemID] = true; n = n + 1 end
		end
		if n > most then best, most, second = data, n, most elseif n > second then second = n end
	end
	if best and most >= 3 and most >= 2 * second then return best.realm end
	return nil, #found
end
function ns:Realm()
	local r = GetRealmName and GetRealmName()
	if soundRealm(r) then
		if realmTaught ~= r and ns.cdb then
			realmTaught = r
			local _, server = playerGUID()
			learnServer(server, r, true)
			settleRealm(r)
		end
		return r
	end
	if realmKnown then return realmKnown end
	if realmStuck or not ns.cdb then return nil end   -- (saved data isn't loaded yet: asked again once it is)
	local name = UnitName and UnitName("player")
	if type(name) ~= "string" or name == "" then return nil end
	local guid, server = playerGUID()
	local map = serverMap()
	local realm, from = nil, nil
	realmUnsure = (not guid and type(UnitGUID) == "function") or nil
	-- 1. its own record, if it is its own (a label from a server number gives way to that server's name once learned)
	local own, ownFor = ns.cdb.realm, ns.cdb.realmFor
	if soundRealm(own) and not (guid and type(ownFor) == "string" and ownFor ~= "" and ownFor ~= guid) then
		local s = labelServer(own)
		realm, from = (s and map and map[s]) or own, "its own record"
		if not s then learnServer(server, own) end
	end
	-- 2. its server number
	if not realm and server and map and map[server] then realm, from = map[server], "its server number" end
	-- 3. a saved character of its name
	local several
	if not realm then
		realm, several = savedRealm(name, guid, server)
		if realm then
			from = "its saved character"
			if not labelServer(realm) then learnServer(server, realm) end
		end
	end
	-- 4. nothing saved: a label from the server number
	if not realm and server and (several or 0) == 0 then realm, from = serverLabel(server), "its server number, as a new character" end
	if not realm then
		realmStuck = true
		return nil
	end
	realmKnown, ns.realmFrom = realm, from
	settleRealm(realm, realmUnsure)
	return realm
end
-- Worth asking again: the player's name, level, gear and GUID arrive as the game loads, and a save has to be right.
function ns:RealmRetry()
	realmStuck, realmTaught = nil, nil
	if realmKnown and realmUnsure and playerGUID() then realmKnown, realmUnsure = nil, nil end
end
-- For /bs check: the realm in use and where it came from.
function ns:RealmSource()
	local r = GetRealmName and GetRealmName()
	if soundRealm(r) then return r, "the game" end
	local realm = ns:Realm()
	return realm, realm and ns.realmFrom or nil
end
ns:On("PLAYER_LOGIN", function() ns:RealmRetry() end)
ns:On("PLAYER_ENTERING_WORLD", function() ns:RealmRetry() end)

------------------------------------------------------------------------
-- Combat-safe queue and next-frame coalescing
------------------------------------------------------------------------
local queue, order = {}, {}
-- (1.5.8) Longer tooltip lines wrap (Shweep: they took up too much of the screen). The game does the wrapping, since only
-- it knows the tooltip's font and size (beta1 broke lines by counting characters, and lines the game also wrapped came
-- out ragged): a line longer than TIP_SHORT visible characters is added with wrapping on, and the tooltip gets a minimum
-- width of TIP_WIDTH so wrapped lines sit at a natural width instead of squeezing to a short title. The width is reset
-- when the tooltip hides, so the game's own tooltips and other addons' are untouched. Short lines pass through as given.
-- Every BagSmith tooltip line goes through TipLine or TipText.
ns.TIP_SHORT, ns.TIP_WIDTH = 40, 280
local function visibleLen(s)
	return #(s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "WW"):gsub("|A.-|a", "WW"):gsub("|H.-|h", ""):gsub("|h", ""))
end
function ns.TipIsLong(text) return type(text) == "string" and visibleLen(text) > ns.TIP_SHORT end
function ns.TipWidth(tt)
	if not (tt and tt.SetMinimumWidth) or tt.bsMinWidth then return end
	tt:SetMinimumWidth(ns.TIP_WIDTH); tt.bsMinWidth = true
	if not tt.bsWidthHook and tt.HookScript then
		tt.bsWidthHook = true
		tt:HookScript("OnHide", function(self) if self.bsMinWidth then self.bsMinWidth = nil; self:SetMinimumWidth(0) end end)
	end
end
function ns.TipLine(tt, text, r, g, b, wrap, ...)
	if ns.TipIsLong(text) then ns.TipWidth(tt); return tt:AddLine(text, r, g, b, true, ...) end
	return tt:AddLine(text, r, g, b, wrap, ...)
end
function ns.TipText(tt, text, r, g, b, a, wrap, ...)
	if ns.TipIsLong(text) then ns.TipWidth(tt); return tt:SetText(text, r or 1, g or 1, b or 1, a or 1, true, ...) end
	return tt:SetText(text, r, g, b, a, wrap, ...)
end

-- (1.5.4) Escape closes a BagSmith window by running that window's own close action, what its close button does. A
-- small invisible stand-in goes on the game's Escape list (UISpecialFrames): it's shown while the window is, and when
-- Escape hides it, the close action runs. The game never hides the window itself, so a window holding a secure button
-- can wait out combat (its close action uses ns:Safely), and a window whose close does more than hide (What's New marks
-- itself seen; the Disenchant offer answers Ask Later) does that too. Hiding the whole interface (Alt+Z) isn't Escape.
function ns:CloseOnEscape(frame, close)
	if not (frame and UISpecialFrames and close) or frame.bsEscape then return end
	local name = (frame:GetName() or "BagSmithWindow") .. "Escape"
	local proxy = CreateFrame("Frame", name, UIParent)
	proxy:Hide()
	proxy:SetScript("OnHide", function(p)
		if p.syncing or p:IsShown() then return end   -- following the window, or hidden with the whole interface
		if frame:IsShown() then close() end
	end)
	frame:HookScript("OnShow", function() proxy.syncing = true; proxy:Show(); proxy.syncing = nil end)
	frame:HookScript("OnHide", function()
		if frame:IsShown() then return end              -- hidden with the whole interface, not closed
		proxy.syncing = true; proxy:Hide(); proxy.syncing = nil
	end)
	if frame:IsShown() then proxy.syncing = true; proxy:Show(); proxy.syncing = nil end
	table.insert(UISpecialFrames, name)
	frame.bsEscape = proxy
end
function ns:Safely(key, fn)
	if InCombatLockdown() then
		if not queue[key] then order[#order + 1] = key end
		queue[key] = fn
		return false
	end
	fn()
	return true
end
ns:On("PLAYER_REGEN_ENABLED", function()
	local pending, keys = queue, order
	queue, order = {}, {}
	for _, key in ipairs(keys) do
		local fn = pending[key]
		if fn then fn() end
	end
	ns:Fire("COMBAT_ENDED")
end)
ns:On("PLAYER_REGEN_DISABLED", function() ns:Fire("COMBAT_STARTED") end)

local nextFrame = {}
function ns:NextFrame(key, fn)
	if nextFrame[key] then return end
	nextFrame[key] = true
	C_Timer.After(0, function() nextFrame[key] = nil; fn() end)
end

------------------------------------------------------------------------
-- Tooltips are suppressed while BagSmith is faded for combat.
------------------------------------------------------------------------
function ns.TooltipsOK()
	return not (InCombatLockdown() and ns.db and ns.db.combatFade)
end
-- (1.6.0) Tooltips that explain BagSmith's own controls (buttons, the toolbar, column headers, the star, wallet and pouch
-- cells, the item menu's dots, section headers' numbers): off with Show Help Tips. Item, bag and currency tooltips, the
-- (i) icons and the Settings window's help always show (they use TooltipsOK).
function ns.HelpTipsOK()
	return ns.TooltipsOK() and not (ns.db and ns.db.helpTips == false)
end

------------------------------------------------------------------------
-- Small utilities
------------------------------------------------------------------------
function ns.Copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and ns.Copy(v) or v end
	return out
end
function ns.IndexOf(list, value)
	for i, v in ipairs(list) do if v == value then return i end end
	return nil
end
function ns.Move(list, from, to)
	if from == to or not list[from] or not list[to] then return false end
	local v = table.remove(list, from)
	table.insert(list, to, v)
	return true
end
-- Returns the value of `field` on whichever frame is under the cursor, if any.
function ns.FrameUnderCursor(field)
	local frames
	if GetMouseFoci then frames = GetMouseFoci() elseif GetMouseFocus then frames = { GetMouseFocus() } end
	for _, f in ipairs(frames or {}) do
		local cur = f
		while cur do
			if cur[field] ~= nil then return cur[field] end
			cur = cur.GetParent and cur:GetParent()
		end
	end
	return nil
end

-- (1.9.0-beta2, Shweep) "First Last" as "First L." (Forever's surnames), for the narrow character picker
function ns.ShortName(name)
	if type(name) ~= "string" then return name end
	local first, last = name:match("^(%S+)%s+(%S)")
	return first and (first .. " " .. last .. ".") or name
end
function ns.ClassColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 0.8, 0.8, 0.8
end
