;(function()
	-- ======== 1.7.5-beta1 ========
	-- (1) Forever's keyring. Shweep's probe on Forever: container -1 has 32 slots and holds the keys; the bank's own
	-- slots are container 6 (a placeholder tab bag named "(DNT)", 48 slots) and its bags follow. Enum.BagIndex.Keyring
	-- reads -1, the old bank number. Before 1.7.5 that collision dropped the keyring and read the keys as bank items, and
	-- their 32 slots counted as bank space. With the bank in tabs (C_Bank), -1 is now the keyring: in the bags, not the
	-- bank, and data saved before 1.7.5 drops the keys it filed under the bank. (2) The mouse wheel: two rows of a list,
	-- one row of icons a notch, in every BagSmith list (the game's half a page skipped whole sections).

	local function forever(cache)
		package.loaded.mock = nil
		local M = require("mock")
		_G.Enum.BagIndex.Keyring = -1     -- Forever's enum: the keyring is -1
		M.sizes[-1] = 32                  -- and -1 is a 32-slot keyring
		M.put(-1, 1, { id = 5396, name = "Key to Searing Gorge", q = 1, class = 13, subclass = 0, type = "Key", sub = "Key", bind = 1 })
		M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = cache or {}, profiles = { Default = { skin = "modern" } } }
		local n = M.loadAddon("BagSmith")
		return n, M
	end

	-- another character's data, saved by 1.7.4 at the bank: its key filed under the bank (-1), and the bank's real slots (6)
	local alt = "Brannoc - Forever"
	local function altEntry()
		return { name = "Brannoc Vale", realm = "Forever", class = "WARRIOR", level = 20, gold = 100, items = {},
			bags = { ["0"] = { size = 16, free = 16, name = "Backpack" } },
			bank = {
				{ bag = -1, slot = 1, itemID = 5396, name = "Key to Searing Gorge", quality = 1, count = 1, cat = "Keys" },
				{ bag = 6, slot = 1, itemID = 2589, name = "Linen Cloth", quality = 1, count = 20, cat = "Trade Goods" },
			},
			bankBags = { ["-1"] = { size = 32, free = 31, name = "Default" }, ["6"] = { size = 48, free = 47, name = "Default" } } }
	end

	local n, M = forever({ [alt] = altEntry() })
	check(n.KEYRING == -1 and n.BANK == nil and n.KEYRING_WAS_BANK == -1, "Forever: -1 is the keyring, and there's no old bank container")
	local inBags, inBank = false, false
	for _, b in ipairs(n.BAGS) do if b == -1 then inBags = true end end
	for _, b in ipairs(n.BANK_BAGS) do if b == -1 then inBank = true end end
	check(inBags and not inBank and n.BANK_BAGS[1] == 6 and #n.BANK_BAGS == n.NUM_BANK_BAGS, "the keyring is with the bags; the bank is its tabs, 6 onward")
	check(not n:IsBankBag(-1) and n:IsBankBag(6), "-1 isn't a bank bag")
	check(n:BagName(-1) == "Keyring", "it's called the Keyring: " .. tostring(n:BagName(-1)))

	M.fire("ADDON_LOADED", "BagSmith")
	check(n.loaded and (n.errors or 0) == 0, "loads without error")
	local saved = BagSmithDB.cache[alt]
	check(saved and #saved.bank == 1 and saved.bank[1].bag == 6, "the saved bank drops the key 1.7.4 filed under it, and keeps the rest")
	check(saved and saved.bankBags["-1"] == nil and saved.bankBags["6"] and saved.bankBags["6"].size == 48, "and the keyring's 32 slots leave the saved bank's space")
	local recs, info = n:CachedRecords(alt, true)
	local slots = 0
	for _, v in pairs(info) do slots = slots + v.size end
	check(#recs == 1 and slots == 48, "that character's bank, viewed from here: the cloth, 48 slots")

	M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	check(n.ready, "ready")
	local key
	for _, r in ipairs(n.items) do if r.itemID == 5396 then key = r end end
	check(key and key.bag == -1 and key.cat == "Keys", "the key is in your bags, in Keys: " .. tostring(key and key.cat))
	check(n.bagInfo[-1] and n.bagInfo[-1].size == 32, "the keyring reads its 32 slots")
	local sum = 0
	for _, b in ipairs(n.BAGS) do if b ~= -1 and not n:IsReagentBag(b) then sum = sum + (n.bagInfo[b] and n.bagInfo[b].size or 0) end end
	local _, total = n:FreeSlots()
	check(total == sum, "the keyring's slots aren't bag space: " .. tostring(total) .. " of " .. sum)
	check(n.Buttons.byBag[-1] and #n.Buttons.byBag[-1] >= 32, "the keyring has its item buttons")

	-- at the bank: the key isn't a bank item, and the bank's space is its own slots
	M.sizes[6] = 48; M.bagNames[6] = "Character Bank Tab Bag (DNT)"
	M.put(6, 1, { id = 6200, name = "Peacebloom", q = 1, count = 2, class = 7, subclass = 9, type = "Tradeskill", sub = "Herb" })
	M.fire("BANKFRAME_OPENED"); M.runTimers(); M.runTimers()
	local keyAtBank = false
	for _, r in ipairs(n.bankItems) do if r.bag == -1 or r.itemID == 5396 then keyAtBank = true end end
	check(#n.bankItems == 1 and not keyAtBank, "the bank holds the Peacebloom, not the key: " .. #n.bankItems)
	local bw = n.Window.bank
	check(bw and bw.freeText.text and bw.freeText.text:find("/ 48") ~= nil, "the bank's free count is its 48 slots: " .. tostring(bw and bw.freeText.text))
	n:SaveCache()
	local mine = BagSmithDB.cache[n:CharKey()]
	local keySaved = false
	for _, r in ipairs(mine.items) do if r.bag == -1 and r.itemID == 5396 then keySaved = true end end
	check(keySaved and mine.bankBags["-1"] == nil and #mine.bank == 1, "saved: the key with your bags, the bank without it")
	M.fire("BANKFRAME_CLOSED"); M.runTimers()
	check((n.errors or 0) == 0, "no errors at the bank")

	-- /bs check's bank line with no old bank container
	local printed = {}
	local oldPrint = n.Print
	n.Print = function(_, fmt, ...) printed[#printed + 1] = fmt:format(...) end
	local ok, err = pcall(SlashCmdList.BAGSMITH, "check")
	n.Print = oldPrint
	check(ok, "/bs check runs: " .. tostring(err))
	local line
	for _, l in ipairs(printed) do if l:find("^Bank bag") then line = l end end
	check(line and line:find("tabs only") and line:find("keyring %-1"), "/bs check: \"" .. tostring(line) .. "\"")

	-- a saved key in this character's own bank (1.7.4) is dropped too, and a later load without the collision keeps -1 records
	local own = altEntry(); own.name = "Aldren Thorne"
	n, M = forever({ ["Aldren - Forever"] = own })
	M.fire("ADDON_LOADED", "BagSmith")
	check(#BagSmithDB.cache["Aldren - Forever"].bank == 1, "this character's own saved bank drops the key as well")

	-- the harness's older layout (no keyring enum): the bank's own slots stay at -1, nothing is dropped
	package.loaded.mock = nil
	M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = { [alt] = altEntry() }, profiles = { Default = { skin = "modern" } } }
	n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith")
	check(n.KEYRING == nil and n.BANK == -1 and n.BANK_BAGS[1] == -1 and n.KEYRING_WAS_BANK == nil, "no keyring enum: the bank keeps -1")
	check(#BagSmithDB.cache[alt].bank == 2 and BagSmithDB.cache[alt].bankBags["-1"], "and saved bank items at -1 are kept")

	-- a client with its own keyring number (-2) keeps both: the bank at -1, the keyring at -2
	package.loaded.mock = nil
	M = require("mock")
	_G.KEYRING_CONTAINER = -2; _G.GetKeyRingSize = function() return 12 end
	M.sizes[-2] = 12; M.bags[-2] = {}
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {} } }
	n = M.loadAddon("BagSmith")
	check(n.KEYRING == -2 and n.BANK == -1 and n.BANK_BAGS[1] == -1 and n.KEYRING_WAS_BANK == nil, "a separate keyring number: keyring -2, bank -1")
	_G.KEYRING_CONTAINER = nil; _G.GetKeyRingSize = nil
end)()

;(function()
	-- (2) the mouse wheel
	package.loaded.mock = nil
	local M = require("mock")
	for s = 1, 16 do M.put(0, s, { id = 7000 + s, name = "Item" .. s, q = 1, count = 1, class = 0, subclass = 5, price = 1 }) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local view = n.Window.main
	local V = view
	V:SetPref("view", "list"); n:RefreshViews(true); M.runTimers()
	local rowH = n.db.rowHeight
	check(view.wheelStep == rowH * 2, "list view: a notch is two rows (" .. tostring(view.wheelStep) .. ", rows " .. rowH .. ")")
	n.db.rowHeight = 30; n:RefreshViews(true); M.runTimers()
	check(view.wheelStep == 60, "it follows the row height: " .. tostring(view.wheelStep))
	n.db.rowHeight = rowH
	V:SetPref("view", "icons"); n:RefreshViews(true); M.runTimers()
	check(view.wheelStep == n.db.iconSize + n.View.C.GAP, "icons: a notch is one row of icons (" .. tostring(view.wheelStep) .. ")")

	-- the wheel moves by that step, and never past the end of the list
	V:SetPref("view", "list"); n:RefreshViews(true); M.runTimers()
	local sf = view.scroll
	view.contentHeight = 600; sf.h = 300   -- range 300
	view.frame.IsMouseOver = function() return true end
	sf:SetVerticalScroll(0); view.trustedScroll = 0
	local wheel = sf:GetScript("OnMouseWheel")
	wheel(sf, -1); M.runTimers()
	check(sf:GetVerticalScroll() == rowH * 2, "one notch down: two rows, " .. sf:GetVerticalScroll() .. " (half the list area would be 150)")
	wheel(sf, -1); wheel(sf, -1); M.runTimers()
	check(sf:GetVerticalScroll() == rowH * 6, "three notches: six rows: " .. sf:GetVerticalScroll())
	for _ = 1, 20 do wheel(sf, -1) end; M.runTimers()
	check(sf:GetVerticalScroll() == 300, "never past the end: " .. sf:GetVerticalScroll())
	wheel(sf, 1); M.runTimers()
	check(sf:GetVerticalScroll() == 300 - rowH * 2, "and back up two rows: " .. sf:GetVerticalScroll())
	for _ = 1, 20 do wheel(sf, 1) end; M.runTimers()
	check(sf:GetVerticalScroll() == 0, "never above the top")

	-- the shared helper on a plain list
	local plain = CreateFrame("ScrollFrame", nil, UIParent, "UIPanelScrollFrameTemplate")
	local child = CreateFrame("Frame", nil, plain); child:SetSize(100, 500); plain:SetSize(100, 100)
	plain.GetScrollChild = function() return child end
	n.WheelStep(plain, 48)
	plain:GetScript("OnMouseWheel")(plain, -1)
	check(plain:GetVerticalScroll() == 48 and plain.bsWheelStep == 48, "a list with the helper: 48 px a notch")
	for _ = 1, 20 do plain:GetScript("OnMouseWheel")(plain, -1) end
	check(plain:GetVerticalScroll() == 400, "and it stops at the end: " .. plain:GetVerticalScroll())

	-- every scroll list in BagSmith sets its own step: the shared helper, the view's setup, or a handler of its own
	local files = {}
	for line in io.lines("BagSmith/BagSmith.toc") do
		if line:match("%.lua%s*$") and not line:match("^#") and not line:match("^Libs") then files[#files + 1] = "BagSmith/" .. line:gsub("\\", "/"):gsub("%s+$", "") end
	end
	local missing, found = {}, 0
	for _, path in ipairs(files) do
		local lines = {}
		for l in io.lines(path) do lines[#lines + 1] = l end
		for i, l in ipairs(lines) do
			if l:find('CreateFrame%("ScrollFrame"') then
				found = found + 1
				local ok = false
				for j = i, math.min(#lines, i + 20) do
					if lines[j]:find("WheelStep%(") or lines[j]:find("SetupScroll%(") or lines[j]:find('"OnMouseWheel"') then ok = true end
				end
				if not ok then missing[#missing + 1] = path .. ":" .. i end
			end
		end
	end
	check(found >= 11 and #missing == 0, "every scroll list sets its wheel step (" .. found .. " found; missing: " .. table.concat(missing, ", ") .. ")")
end)()

;(function()
	-- (3) Forever's keyring button still opens Blizzard's keyring window: BagSmith doesn't take that window over
	package.loaded.mock = nil
	local M = require("mock")
	_G.Enum.BagIndex.Keyring = -1; M.sizes[-1] = 32
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", replaceBlizzardBags = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	check(n.KEYRING == -1 and n.db.replaceBlizzardBags, "(setup) Forever's keyring, BagSmith replacing Blizzard's bags")
	local before = n.Window:IsShown()
	n.Hooks.Request("ToggleBag", "toggle", -1)
	check(n.Window:IsShown() == before, "toggling the keyring leaves BagSmith's window as it was")
	n.Hooks.Request("ToggleBag", "toggle", 1)
	check(n.Window:IsShown() ~= before, "while toggling a bag still toggles BagSmith's window")
end)()
