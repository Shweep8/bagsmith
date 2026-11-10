;(function()
	-- 1.6.0-beta7: the 1.6.0-beta6 audit's findings, past what its own probes check (they're in the suite too:
	-- core_audit_1_6_0_beta6_*_tests.lua).
	--  R1  the Loot Helper's automatic choice always follows the cheapest as ranked now; a row the player picked stays until
	--      what the ranking follows (Rank Suggestions By, the price source in use) changes, by any route
	--  R2  the Disenchant Helper's skin waits for combat's end (it resizes the protected window), and the latest wins
	--  R3  (Shweep) the window stops narrowing where the kept columns stop fitting; the Narrow Windows card says so
	--  advisory (Shweep's wording): a quest check that errors at the final destroy check means nothing is destroyed

	local function lootBoot(skin, prof, other)
		package.loaded.mock = nil
		local M = require("mock")
		for b = 0, 5 do M.sizes[b] = 0 end; M.sizes[0] = 2
		M.maxStack = { [7001] = 1, [7002] = 1, [9001] = 1 }
		M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
		M.put(0, 2, { id = 7002, name = "Common Trinket", q = 1, count = 1, class = 15, subclass = 0, price = 5 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = skin, deEnabled = true, makeRoom = true, priceSource = "auctionator", makeRoomValue = "ah" }
		for k, v in pairs(prof or {}) do p[k] = v end
		local profiles = { Default = p }
		if other then local o = {}; for k, v in pairs(p) do o[k] = v end; for k, v in pairs(other) do o[k] = v end; profiles.Other = o end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = profiles }
		_G.IsSpellKnown = function(id) return id == 13262 end
		_G.GetNumSkillLines = function() return 1 end
		_G.GetSkillLineInfo = function() return "Enchanting", false, nil, 150 end
		_G.RegisterStateDriver = function() end; _G.UnregisterStateDriver = function() end
		local function idOf(v) return type(v) == "number" and v or tonumber(tostring(v):match("item:(%d+)")) end
		local prices = { [7001] = 600, [7002] = 1000, [9001] = 1000000 }
		M.prices = prices
		_G.Auctionator = { API = { v1 = {
			GetAuctionPriceByItemLink = function(c, l) return prices[idOf(l)] or 10000 end,
			GetAuctionPriceByItemID = function(c, id) return prices[idOf(id)] or 10000 end,
		} } }
		_G.BlackthornesTS_API = nil
		local real = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(v) if idOf(v) == 9001 then return "Waiting Loot", "item:9001", 1, 1, 0, "Misc", "Misc", 1, "", 1, 1000000, 15, 0 end; return real(v) end
		_G.GetNumLootItems = function() return 1 end
		_G.GetLootSlotType = function() return 1 end
		_G.GetLootSlotLink = function() return "|Hitem:9001:0|h[Waiting Loot]|h" end
		_G.GetLootSlotInfo = function() return "icon", "Waiting Loot", 1, nil, 1 end
		_G.LootSlot = function() M.lootRequested = true end
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id; M.cursorFrom = { bag, slot } end
		_G.ClearCursor = function() M.cursorItem = nil; M.cursorFrom = nil end
		_G.DeleteCursorItem = function() if M.cursorFrom then M.bags[M.cursorFrom[1]][M.cursorFrom[2]] = nil end; M.cursorItem = nil; M.deleted = (M.deleted or 0) + 1 end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		M.fire("LOOT_OPENED"); M.runTimers(); M.runTimers()
		return n, M
	end
	local function act(n) return n.MakeRoom.frame.act.label.text end
	local function rowFor(n, name) for _, r in ipairs(n.MakeRoom.frame.destroyRows or {}) do if r:IsShown() and r.name.text == name then return r end end end

	for _, skin in ipairs({ "modern", "classic" }) do
		-- R1: the other direction, Vendor to AH through a profile, same price source
		local n, M = lootBoot(skin, { makeRoomValue = "vendor" }, { makeRoomValue = "ah" })
		check(act(n) == "Destroy Common Trinket", skin .. ": ranked by vendor price, the Trinket (5) is the default (" .. tostring(act(n)) .. ")")
		n.Profiles:Use("Other"); M.runTimers(); M.runTimers()
		check(act(n) == "Destroy Sturdy Boots", skin .. ": a profile ranked by AH price: the default follows to the Boots (600) (" .. tostring(act(n)) .. ")")
		n.MakeRoom.frame.act:GetScript("OnClick")(n.MakeRoom.frame.act)
		check(M.bags[0][1] == nil and M.bags[0][2] ~= nil, skin .. ": and the click destroys the Boots, the item it names")

		-- R1: the automatic default follows a fresh scan that changes the order (nothing picked)
		n, M = lootBoot(skin)
		check(act(n) == "Destroy Sturdy Boots", skin .. ": by AH price, the Boots first")
		M.prices[7001] = 5000
		n.MakeRoom:Refresh()
		check(act(n) == "Destroy Common Trinket", skin .. ": a fresh scan makes the Trinket cheaper: the default follows (" .. tostring(act(n)) .. ")")

		-- R1: a row the player picked stays through a repaint, until the ranking basis changes
		n, M = lootBoot(skin)
		local r = rowFor(n, "Common Trinket")
		r.onPick()
		check(act(n) == "Destroy Common Trinket", skin .. ": picking the Trinket chooses it")
		M.prices[7002] = 2000; n.MakeRoom:Refresh()
		check(act(n) == "Destroy Common Trinket", skin .. ": a repaint (a fresh scan) keeps the player's pick")
		n:Set("makeRoomValue", "vendor"); M.runTimers()
		n:Set("makeRoomValue", "ah"); M.runTimers()
		check(act(n) == "Destroy Sturdy Boots", skin .. ": what the ranking follows changed: back to the cheapest (" .. tostring(act(n)) .. ")")

		-- advisory: a quest check that errors refuses, with Shweep's message; a client without the check is unaffected
		n, M = lootBoot(skin)
		local prints = {}
		local realPrint = n.Print
		n.Print = function(self, fmt, ...) prints[#prints + 1] = select("#", ...) > 0 and fmt:format(...) or fmt; return realPrint(self, fmt, ...) end
		local realQ = C_Container.GetContainerItemQuestInfo
		C_Container.GetContainerItemQuestInfo = function() error("quest status unavailable") end
		n.MakeRoom.frame.act:GetScript("OnClick")(n.MakeRoom.frame.act)
		check(M.bags[0][1] ~= nil and not M.deleted, skin .. ": the quest check errors: nothing destroyed")
		check(table.concat(prints, " | "):find("BagSmith couldn't check whether that's a quest item just now, so nothing was destroyed. Try again in a moment.", 1, true) ~= nil, skin .. ": and the player is told why, in Shweep's words")
		C_Container.GetContainerItemQuestInfo = nil
		n.MakeRoom:Refresh()
		n.MakeRoom.frame.act:GetScript("OnClick")(n.MakeRoom.frame.act)
		check(M.bags[0][1] == nil, skin .. ": a client without the check destroys as before")
		C_Container.GetContainerItemQuestInfo = realQ
	end

	-- ---- R2: the Disenchant Helper's skin waits for combat's end; the latest change wins
	local DEID = 13262
	local function deBoot(prof)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = "modern", deEnabled = true, combatFade = false }
		for k, v in pairs(prof or {}) do p[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
		_G.IsSpellKnown = function(id) return id == DEID end
		_G.GetNumSkillLines = function() return 2 end
		_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, 150 end
		_G.RegisterStateDriver = function() end; _G.UnregisterStateDriver = function() end
		_G.Auctionator = nil; _G.BlackthornesTS_API = nil
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local DE = n.Disenchant
		DE:Show(); M.runTimers()
		local f = DE.frame
		local blocked = {}
		for fr, label in pairs({ [f] = "DE.frame", [f.cur] = "DE.frame.cur", [DE:Button()] = "the button" }) do
			fr.protected = true; fr.IsProtected = function(self) return self.protected end
			for _, m in ipairs({ "Show", "Hide", "SetPoint", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight", "SetParent", "StartMoving", "StartSizing", "StopMovingOrSizing" }) do
				local orig = fr[m]
				if orig then fr[m] = function(self, ...) if M.combat then blocked[#blocked + 1] = m .. " " .. label end; return orig(self, ...) end end
			end
		end
		n.blockedLog = blocked
		return n, M, DE, f
	end
	local function combat(M, DE, on)
		local b = DE:Button()
		local was = M.combat; M.combat = false
		local fn = assert(loadstring(b:GetAttribute("_onstate-bscombat")))
		setfenv(fn, { self = b, newstate = on and "lock" or "open" }); fn()
		M.combat = on; M.fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED"); M.runTimers()
	end
	for _, start in ipairs({ "modern", "classic" }) do
		local n, M, DE, f = deBoot({ skin = start })
		local other = start == "modern" and "classic" or "modern"
		combat(M, DE, true)
		n:Set("skin", other); n:Set("skin", start); n:Set("skin", other); M.runTimers()
		check(#n.blockedLog == 0 and DE.skinPending, start .. ": three skin changes in combat: the helper untouched, its skin waiting (" .. table.concat(n.blockedLog, ", ") .. ")")
		local dressedBefore = f.classicState and f.classicState.on or false
		combat(M, DE, false)
		local on = f.classicState and f.classicState.on or false
		check(not DE.skinPending and on == (other == "classic"), start .. ": when combat ends it takes the last one: " .. other .. " (was " .. tostring(dressedBefore) .. ")")
		check(f:IsShown() and DE:Button():GetAttribute("type") == "spell", start .. ": still open and armed")
		-- out of combat, at once, as before
		n:Set("skin", start); M.runTimers()
		check((f.classicState and f.classicState.on or false) == (start == "classic") and not DE.skinPending, start .. ": out of combat a skin change applies at once")
	end

	-- ---- R3: the narrowest width follows the kept columns
	local function colBoot(prof, ah)
		package.loaded.mock = nil
		local M = require("mock")
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = "modern", view = "list", grp = "type" }
		for k, v in pairs(prof or {}) do p[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
		_G.Auctionator = ah and { API = { v1 = { GetAuctionPriceByItemID = function() return 1 end, GetAuctionPriceByItemLink = function() return 1 end } } } or nil
		_G.BlackthornesTS_API = nil
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); M.runTimers(); M.runTimers()
		return n, M, n.Window.main
	end
	local n, M, V = colBoot()
	check(n.View.MinWidthFor(false) == 440 and n.View.MinWidthFor(true) == 500 and V.frame.resizeBounds[1] == 440, "the defaults: 440 and 500, as in beta4")
	local all = {}
	for _, k in ipairs(n.db.colOrder) do if k ~= "n" then all[#all + 1] = k end end
	n:Set("cols", all); n:Set("colAside", {}); M.runTimers()
	check(n.View.MinWidthFor(false) == 46 + 90 + 12 * 30, "every column kept, no AH source: 12 columns (" .. n.View.MinWidthFor(false) .. ")")
	check(V.frame.resizeBounds[1] == 496, "the grip stops there (" .. tostring(V.frame.resizeBounds[1]) .. ")")
	n, M, V = colBoot({ fixW = 440 }, true)
	n:Set("cols", all); n:Set("colAside", {}); M.runTimers()
	check(n.View.MinWidthFor(false) == 526 and V.frame.resizeBounds[1] == 526 and V.frame:GetWidth() == 526, "with AH Price as well: 526, and a 440 window widens to it")
	check(n.db.fixW == 440, "the saved width is left as it was")
	n:Set("colAside", { "t", "age", "v", "ah" }); M.runTimers()
	check(V.frame.resizeBounds[1] == 440, "ticking four back: 440 again")
	-- each window its own
	n:Set("bankCols", all); n:Set("bankColAside", { "jk" }); M.runTimers()
	check(n.View.MinWidthFor(true) == 500 and n.View.MinWidthFor(false) == 440, "the bank window's own columns: 12 kept need 496, under its 500 (" .. n.View.MinWidthFor(true) .. ")")
	n:Set("bankColAside", {}); M.runTimers()
	check(n.View.MinWidthFor(true) == 526 and n.View.MinWidthFor(false) == 440 and n.Window.bank.frame.resizeBounds[1] == 526, "all 13 kept: 526 for the bank alone (" .. n.View.MinWidthFor(true) .. ")")
	n:Set("bankColAside", { "jk" }); M.runTimers()
	-- the Settings card says so, only when it applies
	n:Set("colAside", {}); M.runTimers()
	local P = n.SettingsPanel
	P:Show(); M.runTimers()
	local function texts(page)
		P:ShowPage(page); M.runTimers()
		local t = {}
		for _, w in ipairs(P.pools.text or {}) do if w:IsShown() then t[#t + 1] = w.text.text end end
		return table.concat(t, " | ")
	end
	check(texts("bagcols"):find("With these columns kept, the bags window can't be narrower than 526 pixels.", 1, true) ~= nil, "Bag Columns: \"With these columns kept, the bags window can't be narrower than 526 pixels.\"")
	check(texts("bankcols"):find("With these columns kept, the bank window can't be narrower than 496 pixels.", 1, true) == nil, "Bank Columns: no line while the bank's 500 still applies")
	n:Set("bankColAside", {}); M.runTimers()
	check(texts("bankcols"):find("With these columns kept, the bank window can't be narrower than 526 pixels.", 1, true) ~= nil, "and the bank's line when its columns need more")
	n:Set("colAside", { "t", "age", "v", "ah" }); M.runTimers()
	check(texts("bagcols"):find("can't be narrower than", 1, true) == nil, "back to the defaults: no line")
	P:Hide()
	-- and at that narrowest width every kept column fits, both windows, both skins
	for _, skin in ipairs({ "modern", "classic" }) do
		n, M, V = colBoot({ skin = skin }, true)
		n:Set("cols", all); n:Set("bankCols", n.Copy(all)); n:Set("colAside", {}); n:Set("bankColAside", {}); M.runTimers()
		for _, W in ipairs({ n.Window.main, n.Window.bank }) do
			W.scroll.w = W.minWidth - 46; W.trustedRowWidth = nil
			local plan, width = W:ColumnPlan()
			local last = plan[#plan]
			check(#plan.dropped == 0 and last.colX + last.colW <= width, ("%s %s: at its narrowest, all %d columns fit (%d in %d)"):format(skin, W.isBank and "bank" or "bags", #plan, last.colX + last.colW, width))
		end
	end
end)()
