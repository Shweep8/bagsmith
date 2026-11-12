;(function()
	-- 1.7.0-beta1 (Shweep: a Quest Starter in Recent wore a smaller "!" than the same item in any other section). The mark
	-- was sized once, when made, from the icon's width at that moment, and placing it only ever shrank it (the cap at half
	-- the icon). Now it's sized at every placement from the icon it sits on, as the Icon Corners preview sizes it.
	local function boot(prof)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 3000, name = "Torn Note", q = 1, count = 1, class = 12, subclass = 0, price = 0 })
		M.put(0, 2, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local pr = { skin = "modern", view = "icons" }
		for k, v in pairs(prof or {}) do pr[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = pr } }
		local n = M.loadAddon("BagSmith")
		C_Container.GetContainerItemQuestInfo = function(bag, slot) if bag == 0 and slot == 1 then return { questID = 101, isActive = false } end return { isQuestItem = false } end
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M
	end
	local function expected(n, b)
		local px = n.Buttons:IconPx(b)
		local s = math.max(10, math.floor(px * 0.45 + 0.5))
		return math.min(s, math.floor(px / 2)), px
	end
	for _, skin in ipairs({ "modern", "classic" }) do
		local n, M = boot({ skin = skin })
		local now = time()
		n.cdb.recentSince = now - 100
		n.cdb.firstSeen[M.bags[0][1].guid] = now - 10
		n:Scan(); n:Set("recentSection", true); n.Window:Show(); M.runTimers(); M.runTimers()
		local function find()
			local main, copy
			for _, b in ipairs(n.Window.main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 3000 then main = b end end
			for _, b in ipairs(n.Buttons.recent or {}) do if b:IsShown() and b.rec and b.rec.itemID == 3000 then copy = b end end
			return main, copy
		end
		local main, copy = find()
		check(main and copy and main.questMark and copy.questMark and main.questMark:IsShown() and copy.questMark:IsShown(),
			skin .. ": (setup) the starter shows its mark in its section and in Recent")
		for _, size in ipairs({ 37, 24, 48, 37 }) do
			n:Set("iconSize", size); n:RefreshViews(true); M.runTimers(); M.runTimers()
			main, copy = find()
			for _, pair in ipairs({ { main, "its section" }, { copy, "Recent" } }) do
				local b, where = pair[1], pair[2]
				local want, px = expected(n, b)
				local got = b and b.questMark and b.questMark:GetWidth()
				check(got == want, ("%s: Icon Size %d, %s: the mark is %s px for a %s px icon (%s)"):format(skin, size, where, tostring(want), tostring(px), tostring(got)))
			end
			check(main.questMark:GetWidth() == copy.questMark:GetWidth(), ("%s: Icon Size %d: the same size in Recent as in its section"):format(skin, size))
		end
		-- List view, then back to Icons: the row's small mark doesn't stay
		n:Set("view", "list"); n:RefreshViews(true); M.runTimers(); M.runTimers()
		main = find()
		local want = expected(n, main)
		check(main and main.questMark:GetWidth() == want, skin .. ": in List view the mark fits the row's icon (" .. tostring(main and main.questMark:GetWidth()) .. " vs " .. want .. ")")
		n:Set("view", "icons"); n:RefreshViews(true); M.runTimers(); M.runTimers()
		main, copy = find()
		want = expected(n, main)
		check(main and main.questMark:GetWidth() == want and copy.questMark:GetWidth() == want, skin .. ": back in Icons view, full size again (" .. tostring(main and main.questMark:GetWidth()) .. ")")
		-- the shadow follows (anchored to the mark by two corners)
		check(select(2, main.questShade:GetPoint(1)) == main.questMark, skin .. ": the shadow is still anchored to the mark")
		-- the preview and a live button agree
		n:Set("iconSize", 37); n:RefreshViews(true); M.runTimers(); M.runTimers()
		main = find()
		check(main.questMark:GetWidth() == math.max(10, math.floor(n.Buttons:IconPx(main) * 0.45 + 0.5)), skin .. ": at the default size it matches the preview's size")
	end

	-- ======== the Loot Helper: Protect (1.7.0-beta1, Shweep; its Show More was removed in beta3, by design) ========
	local loot = {}
	local lootPrice = 30
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("|Hitem:" .. loot[i].id .. ":0|h[" .. loot[i].name .. "]|h") end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, l.qty or 1, nil, l.q or 1 end end
	_G.LootSlot = function() end
	local deleted = 0
	_G.DeleteCursorItem = function() deleted = deleted + 1 end
	local INFO = { [9740] = { "Rough Gem", 1, 1 }, [9701] = { "Broken Fang", 0, 1, 3 }, [9702] = { "Linen Belt", 1, 1, 22 }, [9720] = { "Gnoll Paw", 1, 20, 2 },
		[9730] = { "Heavy Stone", 1, 20, 50 }, [9731] = { "Fine Ring", 1, 1, 80 } }
	local function lootBoot(stock, skin, cdb)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return "Warrior", "WARRIOR" end
		M.sizes[0] = 5
		for b = 1, 5 do M.sizes[b] = 0 end
		stock(M)
		_G.BagSmithCharDB = cdb or { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin or "modern", makeRoom = true, makeRoomValue = "vendor", makeRoomAsk = false } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id)
			local num = tonumber(tostring(id):match("item:(%d+)")) or id
			local e = INFO[num]
			if e then return e[1], nil, e[2], nil, nil, nil, nil, e[3], nil, nil, num == 9740 and lootPrice or e[4] end
			return realInfo(id)
		end
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id end
		_G.ClearCursor = function() M.cursorItem = nil end
		return n, M
	end
	local function pack(M)
		M.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
		M.put(0, 2, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
		M.put(0, 3, { id = 9720, name = "Gnoll Paw", q = 1, count = 5, stack = 20, class = 15, subclass = 0, price = 2 })   -- 10c
		M.put(0, 4, { id = 9730, name = "Heavy Stone", q = 1, count = 1, stack = 20, class = 7, subclass = 7, price = 50 })   -- 50c
		M.put(0, 5, { id = 9731, name = "Fine Ring", q = 1, class = 4, subclass = 0, price = 80, equip = "INVTYPE_FINGER" })
	end
	local function offered(f)
		local t = {}
		for _, r in ipairs(f.destroyRows) do if r:IsShown() then t[#t + 1] = r.name.text end end
		return table.concat(t, ",")
	end
	local function rowNamed(f, name) for _, r in ipairs(f.destroyRows) do if r:IsShown() and r.name.text == name then return r end end end
	local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
	local function openLoot(M) M.fire("LOOT_CLOSED"); M.runTimers(); M.fire("LOOT_OPENED"); M.runTimers() end

	for _, skin in ipairs({ "modern", "classic" }) do
		lootPrice = 30
		local n, M = lootBoot(pack, skin)
		_G.LootFrame = CreateFrame("Frame", "LootFrame", UIParent); LootFrame.GetRight = function() return 500 end; LootFrame.GetTop = function() return 700 end; LootFrame:Show()
		loot = { { id = 9740, name = "Rough Gem", q = 1 } }
		M.fire("LOOT_OPENED"); M.runTimers()
		local MR, f = n.MakeRoom, n.MakeRoom.frame
		local S = skin .. ": "
		check(f and f:IsShown() and offered(f) == "Broken Fang,Gnoll Paw,Linen Belt", S .. "(setup) junk, then the items worth less than the 30c loot (" .. offered(f) .. ")")

		-- ---- Protect
		-- (1.7.0-beta10, by design: Shweep) Protect is a secondary choice beside the Destroy button, for the chosen row
		local belt = rowNamed(f, "Linen Belt")
		check(belt and #belt.btns == 0 and f.protect.label.text == "Protect" and f.protect:IsShown(), S .. "Protect sits beside Destroy, not on the rows")
		check(f.protect.tip == "Don't suggest again" and (f.protect.tipSub or ""):find("Settings > Loot Helper", 1, true), S .. "its tooltip: \"Don't suggest again\", and where to undo it")
		local beltOffer = MR:Offer(recOf(n, 9702), false, "priced", 22)
		check(MR:StillOk(beltOffer) == true, S .. "(control) the belt can be destroyed before it's protected")
		belt:GetScript("OnClick")(belt)   -- chosen
		check(f.act.label.text == "Destroy Linen Belt", S .. "(setup) the belt is the chosen row")
		f.protect:GetScript("OnClick")(f.protect); M.runTimers()   -- (1.7.0-beta10) Protect, for the chosen belt
		check(n.cdb.makeRoomProtect[9702] == true and MR:IsProtected(9702), S .. "Protect puts it on this character's Protected Items")
		check(offered(f) == "Broken Fang,Gnoll Paw", S .. "and it isn't offered any more (" .. offered(f) .. ")")
		check(f.act.label.text == "Destroy Broken Fang", S .. "the choice goes back to the first row (" .. tostring(f.act.label.text) .. ")")
		check(f.held:IsShown() and f.held.text == "1 protected item isn't offered" and (f.heldInfo.lines[1] or ""):find("Protected by you (1):", 1, true) and f.heldInfo.lines[1]:find("Linen Belt", 1, true),
			S .. "it counts with the other protected items, under its own reason (" .. tostring(f.held.text) .. " / " .. tostring(f.heldInfo.lines[1]) .. ")")
		local ok, why = MR:StillOk(beltOffer)
		check(ok == false and why == "protected", S .. "an offer made before it was protected is refused at the click (" .. tostring(why) .. ")")
		local before = deleted
		MR:Destroy(beltOffer, true)
		check(deleted == before, S .. "even after a Yes, nothing is destroyed")
		-- a protected junk item: not offered either
		local fang = rowNamed(f, "Broken Fang"); fang:GetScript("OnClick")(fang); f.protect:GetScript("OnClick")(f.protect); M.runTimers()
		check(offered(f) == "Gnoll Paw" and f.held.text == "2 protected items aren't offered", S .. "junk can be protected too (" .. offered(f) .. ")")
		-- the phrase on the empty card
		local h = n.Why:New(); n.Why:Add(h, "favorite", "A"); n.Why:Add(h, "protected", "B")
		check(n.Why:Phrase(h) == "1 favorite and 1 item you protected", S .. "the card's words: " .. n.Why:Phrase(h))

		-- ---- the Protected Items window
		MR:ManageProtected()
		local pw = MR.protectFrame
		check(pw and pw:IsShown() and pw.title.text == "Protected Items" and pw.sub.text == "2 items the Loot Helper won't suggest destroying.", S .. "Protected Items: its own window (" .. tostring(pw and pw.sub.text) .. ")")
		check(pw ~= MR.neverFrame and pw:GetName() == "BagSmithProtected", S .. "not the Loot Exclusion List's window")
		local names = {}
		for _, r in ipairs(pw.rows) do if r:IsShown() then names[#names + 1] = r.name.text end end
		check(table.concat(names, ",") == "Broken Fang,Linen Belt", S .. "listed A to Z (" .. table.concat(names, ",") .. ")")
		check(pw.rows[2].remove.tip == "Stop protecting it: the Loot Helper can suggest it again", S .. "each row's X says what it does (" .. tostring(pw.rows[2].remove.tip) .. ")")
		pw.search:SetText("belt"); pw.search:GetScript("OnTextChanged")(pw.search)
		local vis = 0; for _, r in ipairs(pw.rows) do if r:IsShown() then vis = vis + 1 end end
		check(vis == 1, S .. "the search narrows it")
		pw.search:SetText(""); pw.search:GetScript("OnTextChanged")(pw.search)
		pw.rows[2].remove:GetScript("OnClick")(pw.rows[2].remove); M.runTimers()
		check(not MR:IsProtected(9702) and MR:IsProtected(9701) and pw.sub.text == "1 item the Loot Helper won't suggest destroying.", S .. "removing one there lets the Loot Helper suggest it again")
		check(offered(f) == "Gnoll Paw,Linen Belt", S .. "and the open Loot Helper offers it at once (" .. offered(f) .. ")")
		MR:ClearProtected(); M.runTimers()
		check(not MR:IsProtected(9701) and pw.empty:IsShown() and pw.empty.text == "Nothing is protected yet. Use Protect in the Loot Helper to add items.", S .. "Clear All empties it, with a line that says how to add items")
		check(offered(f) == "Broken Fang,Gnoll Paw,Linen Belt", S .. "everything is offered again")
		pw:Hide()
		MR:ManageNever()
		check(MR.neverFrame and MR.neverFrame:IsShown() and MR.neverFrame.title.text == "Loot Exclusion List" and MR.neverFrame:GetName() == "BagSmithNeverAsk"
			and MR.neverFrame.empty.text == "Your Loot Exclusion List is empty. Use Exclude in the Loot Helper to add items.", S .. "the Loot Exclusion List's window is unchanged")
		MR.neverFrame:Hide()

		-- ---- the settings page
		MR:Protect(9702); M.runTimers()
		local P = n.SettingsPanel; P:Show(); P:ShowPage("loothelper"); M.runTimers()
		local all = {}
		for _, pool in pairs(P.pools or {}) do for _, w in ipairs(pool) do if w:IsShown() then
			for _, k in ipairs({ "text", "label" }) do local t = w[k]; if type(t) == "table" and t.text then all[#all + 1] = t.text elseif type(t) == "string" then all[#all + 1] = t end end
		end end end
		local txt = table.concat(all, "\n")
		check(txt:find("Protected Items: 1 item", 1, true) and txt:find("This list only affects the Loot Helper", 1, true), S .. "Settings > Loot Helper shows Protected Items and its count")
		P:Hide()

		-- (1.7.0-beta3, by design) Show More was removed: the "let go" list scrolls and lists every candidate instead
		f = MR.frame
		f:Hide()
	end

	-- ---- Protected Items: per character, kept across a reload, malformed entries dropped
	do
		local n, M = lootBoot(pack, "modern", { version = 1, firstSeen = {}, makeRoomProtect = { [9702] = true, [9731] = true, x = true, [5] = "yes" } })
		local p = n.cdb.makeRoomProtect
		check(p[9702] == true and p[9731] == true and p.x == nil and p[5] == nil, "saved Protected Items are kept at load; malformed entries are dropped")
		local n2 = lootBoot(pack, "modern", { version = 1, firstSeen = {}, makeRoomProtect = "bad" })
		check(type(n2.cdb.makeRoomProtect) == "table" and next(n2.cdb.makeRoomProtect) == nil, "a malformed list starts empty")
		local n3 = lootBoot(pack, "modern", nil)
		check(type(n3.cdb.makeRoomProtect) == "table" and next(n3.cdb.makeRoomProtect) == nil, "a character without one starts with an empty list")
	end
end)()
