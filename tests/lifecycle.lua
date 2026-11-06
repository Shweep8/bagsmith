--[[
	tests/lifecycle.lua

	A play session, step by step, with every rule in tests/invariants.lua
	checked after each step. The steps are the awkward real-life sequences
	that feature tests tend to skip: timing windows, logins and reloads,
	bank visits, combat, settings changed mid-session, renames and deletes.
	Returns a function(check) that runs it all.
--]]
local I = dofile("tests/invariants.lua")

return function(check)
	local M, ns
	local function stock(MM)
		MM.put(0, 1, { id = 20558, name = "Warsong Gulch Mark", q = 2, count = 5, class = 12, subclass = 0, price = 0 })
		MM.put(0, 2, { id = 7001, name = "Healing Potion", q = 1, count = 5, class = 0, subclass = 1, price = 10 })
		MM.put(0, 4, { id = 7001, name = "Healing Potion", q = 1, count = 3, class = 0, subclass = 1, price = 10 })
		MM.put(0, 5, { id = 7002, name = "Linen Cloth", q = 1, count = 10, class = 7, subclass = 5, price = 1 })
		MM.put(0, 6, { id = 7003, name = "Old Sword", q = 2, class = 2, subclass = 7, price = 300, equip = "INVTYPE_WEAPON" })
	end
	local function boot(savedDB, savedChar, restock)
		package.loaded.mock = nil
		M = require("mock")
		restock(M)
		_G.BagSmithDB, _G.BagSmithCharDB = savedDB, savedChar
		ns = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD", savedDB == nil, savedDB ~= nil); M.runTimers(); M.runTimers()
	end
	local function settle() M.runTimers(); M.runTimers(); M.elapse(); M.runTimers() end
	local function bagsChanged() M.fire("BAG_UPDATE_DELAYED"); settle() end
	local steps, failures = 0, 0
	local function step(label)
		steps = steps + 1
		local bad = I.check(ns, M)
		if #bad > 0 then failures = failures + 1 end
		check(#bad == 0, ("lifecycle step %d, %s: every rule holds%s"):format(steps, label, #bad > 0 and (": " .. table.concat(bad, "; ")) or ""))
	end

	-- A first login with some items.
	boot(nil, nil, stock)
	ns.db.fav = { "i:20558" }   -- the token as a footer favorite
	step("first login")
	ToggleAllBags(); settle()
	step("bags opened")
	M.put(0, 7, { id = 7004, name = "Copper Ore", q = 1, count = 4, class = 7, subclass = 0, price = 2 }); bagsChanged()
	step("an item looted")
	ns:Set("mergeStacks", true); ns:RefreshViews(true)
	step("Merge Stacks turned on")

	-- Rows held still under the pointer while things change.
	local main = ns.Window.main
	main.frame.IsMouseOver = function() return true end
	M.bags[0][2] = nil; bagsChanged()
	step("pointer over the bags, one merged potion stack used up")
	M.put(0, 2, { id = 7005, name = "Shiny Ring", q = 2, class = 4, subclass = 0, price = 50, equip = "INVTYPE_FINGER" }); bagsChanged()
	step("something looted into the freed slot while rows hold still")
	M.bags[0][5], M.bags[0][8] = nil, M.bags[0][5]; bagsChanged()
	step("an item moved to another slot while rows hold still")
	main.frame.IsMouseOver = function() return false end
	ns:RefreshViews(); settle()
	step("pointer leaves the bags")

	-- Tokens change.
	M.bags[0][1].count = 9; bagsChanged()
	step("token count changed")

	-- Bank: move something in, close right away.
	M.put(-1, 1, { id = 7006, name = "Bank Gem", q = 2, class = 7, subclass = 0, price = 5 })
	M.put(-1, 2, { id = 20558, name = "Warsong Gulch Mark", q = 2, count = 4, class = 12, subclass = 0, price = 0 })
	M.fire("BANKFRAME_OPENED"); settle()
	step("bank opened")
	-- Moved and closed within the 1.5 s save delay (no time passes between).
	M.put(-1, 3, M.bags[0][6]); M.bags[0][6] = nil
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	M.fire("BANKFRAME_CLOSED"); settle()
	step("an item moved into the bank and the bank closed right away")
	M.fire("PLAYER_MONEY"); settle()
	step("money changed")

	-- Combat.
	M.combat = true; M.fire("PLAYER_REGEN_DISABLED"); settle()
	M.bags[0][4].count = 2; bagsChanged()
	step("a potion drunk in combat")
	M.combat = false; M.fire("PLAYER_REGEN_ENABLED"); settle()
	step("combat ended")

	-- Settings changed mid-session.
	for _, change in ipairs({ { "grp", "type" }, { "view", "icons" }, { "splitView", true }, { "grp", "bag" }, { "recentSection", false },
		{ "recentSection", true }, { "view", "list" }, { "mergeStacks", false }, { "grp", "none" }, { "skin", "classic" }, { "skin", "modern" } }) do
		ns:Set(change[1], change[2]); settle()
		step(("setting %s changed to %s"):format(change[1], tostring(change[2])))
	end

	-- Sheets with remembered views: save, change, rename, delete.
	ns:Set("sheetViews", true)
	main.st.filters = ns.EmptyFilters(); main.st.filters.text = "potion"
	ns:SaveSheet("Potions", main); main.st.sheet = "Potions"; main:SetPref("view", "icons"); settle()
	step("a sheet saved with its own view")
	ns:UpdateSheet("Potions", "Drinks", main); settle()
	step("the sheet renamed")
	ns:DeleteSheet("Drinks", main); settle()
	step("the sheet deleted")

	-- Recent with merged stacks: a new stack arrives, then is used up.
	ns:Set("mergeStacks", true); ns:Set("recentSection", true)
	M.put(0, 9, { id = 7001, name = "Healing Potion", q = 1, count = 2, class = 0, subclass = 1, price = 10 }); M.now = M.now + 5; bagsChanged()
	M.bags[0][9] = nil; M.now = M.now + 5; bagsChanged()
	local stillRecent = false
	for _, b in ipairs(ns.Buttons.recent) do if b:IsShown() and b.rec and b.rec.itemID == 7001 then stillRecent = true end end
	check(stillRecent, "lifecycle: merged potions stay in Recent after the newly looted stack is used up")
	step("a new potion stack looted and used up, with Merge Stacks on")

	-- Travel Mode through a vendor, the bank, combat and a skin change.
	ns:ToggleTravel(); settle()
	step("Travel Mode turned on")
	M.put(0, 10, { id = 7007, name = "Silk Cloth", q = 1, count = 2, class = 7, subclass = 5, price = 3 }); bagsChanged()
	step("an item looted in Travel Mode")
	M.fire("MERCHANT_SHOW"); settle()
	step("a vendor opened in Travel Mode (Auto Travel Mode turns it off)")
	M.bags[0][10] = nil; bagsChanged()
	step("an item sold at the vendor")
	M.fire("MERCHANT_CLOSED"); settle()
	step("the vendor closed (Travel Mode back on)")
	M.fire("BANKFRAME_OPENED"); settle()
	step("the bank opened in Travel Mode")
	M.fire("BANKFRAME_CLOSED"); settle()
	step("the bank closed (Travel Mode back on)")
	local flying = false
	_G.UnitOnTaxi = function() return flying end
	flying = true; M.fire("PLAYER_CONTROL_LOST"); settle()
	step("took a flight path in Travel Mode (Auto Travel Mode turns it off)")
	flying = false; M.fire("PLAYER_CONTROL_GAINED"); settle()
	step("landed (Travel Mode back on)")
	_G.UnitOnTaxi = nil
	M.combat = true; ns:ToggleTravel()
	M.combat = false; M.fire("PLAYER_REGEN_ENABLED"); settle()
	step("Travel Mode switched off during combat, caught up after")
	ns:ToggleTravel(); ns:Set("skin", "classic"); settle()
	step("Travel Mode on in Classic")
	ns:Set("skin", "modern"); ns:ToggleTravel(); settle()
	step("back to Modern, Travel Mode off")

	-- Profiles: a sheet selected in one profile, then a switch; a reset asked and then a switch.
	ns:Set("sheetViews", false)
	main.st.filters = ns.EmptyFilters(); main.st.filters.text = "cloth"
	ns:SaveSheet("Cloth", main); main.st.sheet = "Cloth"; settle()
	step("a sheet saved and selected")
	ns.Profiles:Use("Second"); settle()
	step("switched to a new profile (copies the sheet)")
	ns.Profiles:Reset("Second"); settle()
	step("the new profile reset to defaults (no sheets now)")
	ns.Confirm(main.frame, "Reset?", function() end)
	ns.Profiles:Use("Default"); settle()
	check(not ns.Popups.confirm:IsShown(), "lifecycle: a profile switch closes an open confirmation")
	step("back to the Default profile with a confirmation open")
	-- Travel Mode with the character picker open.
	ns.Popups:ToggleCharacters(main)
	ns:ToggleTravel(); settle()
	step("Travel Mode turned on with the character picker open")
	ns:ToggleTravel(); settle()

	-- Junk: mark, dim, sell at a vendor, unmark.
	ns:Set("view", "list")
	local cloth
	for _, r in ipairs(ns.items) do if r.itemID == 7002 then cloth = r end end
	if cloth then
		ns.Junk:Toggle(cloth); settle()
		step("Linen Cloth marked as junk")
		ns:Set("dimJunk", true); settle()
		step("Dim Junk Items turned on")
		_G.C_MerchantFrame = _G.C_MerchantFrame or { SellAllJunkItems = function() end }
		ns.Junk:Toggle(cloth); settle()
		step("Linen Cloth unmarked")
		ns:Set("dimJunk", false); settle()
		step("Dim Junk Items turned off")
	end

	-- Make Room: loot that won't fit, the panel, then the loot window closing.
	do
		local loot = { { id = 7090, name = "Big Prize" } }
		_G.GetNumLootItems = function() return #loot end
		_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
		_G.GetLootSlotLink = function(i) return loot[i] and ("item:" .. loot[i].id) end
		_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, 1, nil, 2 end end
		local realFree = C_Container.GetContainerNumFreeSlots
		C_Container.GetContainerNumFreeSlots = function() return 0, 0 end   -- every bag full
		M.fire("LOOT_OPENED"); settle()
		check(ns.MakeRoom.frame and ns.MakeRoom.frame:IsShown(), "lifecycle: loot that won't fit opens Make Room")
		step("looting with full bags (Make Room open)")
		loot = {}
		M.fire("LOOT_CLOSED"); settle()
		step("the loot window closed")
		ns.MakeRoom.frame:Hide()
		C_Container.GetContainerNumFreeSlots = realFree
		_G.GetNumLootItems, _G.GetLootSlotType, _G.GetLootSlotLink, _G.GetLootSlotInfo = nil, nil, nil, nil
	end

	-- Favorites and Track as Currency.
	do
		local potion
		for _, r in ipairs(ns.items) do if r.itemID == 7001 then potion = r end end
		if potion then
			ns.Marks:ToggleFavorite(potion); ns:RefreshViews(true); settle()
			local shown = 0
			for _, b in ipairs(ns.Window.main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 7001 then shown = shown + 1 end end
			local ids = table.concat(ns.Window.main.laneIds or {}, ",")
			-- Once in Favorites (plus a copy in Recent if it's new), above the rest.
			check(shown <= 2 and ids:find("~fav") and ids:find("~fav") < (ids:find("~all") or 999), "lifecycle: a favorite moves to Favorites, which sits above the other items: " .. ids)
			step("an item favorited")
			ns.Marks:Track(7004); settle()
			step("an item tracked as a currency")
			ns.Marks:ToggleFavorite(potion); ns.Marks:Untrack(7004); ns:RefreshViews(true); settle()
			step("unfavorited and untracked")
		end
	end

	-- Browsing another character's saved bags, with money changing.
	local otherKey = "Someone - Elsewhere"
	BagSmithDB.cache[otherKey] = { name = "Someone", realm = "Elsewhere", gold = 5, items = {}, bags = { ["0"] = { size = 16, free = 10 } } }
	ns.ui.owner = otherKey; ns:RefreshViews(true); settle()
	local before = main.freeText.text
	M.fire("PLAYER_MONEY"); settle()
	check(main.freeText.text == before, "lifecycle: browsing another character, a money change keeps their free-slot count")
	ns.ui.owner = nil; ns:RefreshViews(true); settle()
	step("back to your own bags")

	-- Log out and back in: the same bags, saved variables carried over.
	local bankAges = {}
	for _, r in ipairs(ns.bankItems or {}) do if r.guid then bankAges[r.guid] = ns.cdb.firstSeen[r.guid] end end
	M.fire("PLAYER_LOGOUT")
	local savedDB, savedChar = BagSmithDB, BagSmithCharDB
	local bags = {}
	for bag, list in pairs(M.bags) do bags[bag] = {}; for slot, it in pairs(list) do bags[bag][slot] = it end end
	boot(savedDB, savedChar, function(MM) for bag, list in pairs(bags) do for slot, it in pairs(list) do MM.put(bag, slot, it) end end end)
	-- Away from the bank: the live bank list is empty, the saved bank vouches.
	M.bags[-1] = {}
	step("logged back in, away from the bank")
	M.now = M.now + 30; bagsChanged()
	step("a bag change 30 seconds after login, away from the bank")
	for slot, it in pairs(bags[-1] or {}) do M.put(-1, slot, it) end
	M.fire("BANKFRAME_OPENED"); settle()
	step("the bank visited after logging back in")
	local kept = next(bankAges) ~= nil
	for guid, t in pairs(bankAges) do if ns.cdb.firstSeen[guid] ~= t then kept = false end end
	check(kept, "lifecycle: bank items keep their ages across a logout, a bag change away from the bank, and the next bank visit")
	M.fire("BANKFRAME_CLOSED"); settle()

	check(failures == 0, ("lifecycle: %d steps, every rule held after each"):format(steps))
end
