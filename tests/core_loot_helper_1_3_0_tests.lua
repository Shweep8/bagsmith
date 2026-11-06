;(function()
	-- 1.3.0: the redesigned Loot Helper (one action for the chosen row, waiting rows with their own Skip and
	-- Exclude, held-back counts, the comparison note, the excluded-loot line, the nothing-frees card), its
	-- pre-destroy safety, the Exclusion List rename, held-back counts in the Disenchant Helper, junk kept out of
	-- a sale, and the Classic margin under the portrait.
	local loot = {}
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("|Hitem:" .. loot[i].id .. ":0|h[" .. loot[i].name .. "]|h") end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, l.qty or 1, nil, l.q or 1 end end
	_G.LootSlot = function() end
	_G.DeleteCursorItem = function() end
	local PRICES = { [9710] = 500, [9711] = 1, [9720] = 2, [9703] = 1 }
	local function boot(stock, skin)
		package.loaded.mock = nil
		local M = require("mock")
		_G.UnitClass = function() return "Warrior", "WARRIOR" end
		M.sizes[0] = 4
		for b = 1, 5 do M.sizes[b] = 0 end
		stock(M)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin or "modern", makeRoom = true, makeRoomValue = "vendor" } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id)
			local num = tonumber(tostring(id):match("item:(%d+)")) or id
			if num == 9710 then return "Shiny Ring", nil, 2, nil, nil, nil, nil, 1, nil, nil, 500 end
			if num == 9711 then return "Small Egg", nil, 1, nil, nil, nil, nil, 20, nil, nil, 1 end
			if num == 9720 then return "Gnoll Paw", nil, 1, nil, nil, nil, nil, 20, nil, nil, 2 end
			if num == 9703 then return "Linen Cloth", nil, 1, nil, nil, nil, nil, 20, nil, nil, 1 end
			return realInfo(id)
		end
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id end
		_G.ClearCursor = function() M.cursorItem = nil end
		return n, M
	end
	local function fullPack(M)
		M.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
		M.put(0, 2, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
		M.put(0, 3, { id = 9703, name = "Linen Cloth", q = 1, count = 5, stack = 20, class = 7, subclass = 5, price = 1 })
		M.put(0, 4, { id = 9703, name = "Linen Cloth", q = 1, count = 7, stack = 20, class = 7, subclass = 5, price = 1 })
	end
	local function heads(f) local t = {}; for _, h in ipairs(f.heads) do if h:IsShown() then t[#t + 1] = h.text end end return table.concat(t, "|") end
	local function shown(list) local c = 0; for _, r in ipairs(list) do if r:IsShown() then c = c + 1 end end return c end
	local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end

	-- ---- the layout and the chosen row
	local n, M = boot(fullPack)
	_G.LootFrame = CreateFrame("Frame", "LootFrame", UIParent); LootFrame.GetRight = function() return 500 end; LootFrame.GetTop = function() return 700 end; LootFrame:Show()
	loot = { { id = 9710, name = "Shiny Ring", q = 2 } }
	M.fire("LOOT_OPENED"); M.runTimers()
	local MR = n.MakeRoom
	local f = MR.frame
	check(f and f:IsShown() and f.sub.text == "1 item won't fit. Make room to finish looting.", "the header says how many won't fit (beta2: without promising a slot count) (" .. tostring(f and f.sub.text) .. ")")
	check(heads(f) == "Waiting to loot|Free a slot without losing anything|Lowest value to let go", "three sections in order: what's waiting, the lossless ways, then what to let go (" .. heads(f) .. ")")
	local w1 = f.waitRows[1]
	check(w1:IsShown() and w1.name.text == "Shiny Ring" and w1.value.text:find("Vendor", 1, true) and not w1.dot:IsShown() and w1.btns[1].label.text == "Skip" and w1.btns[2].label.text == "Exclude", "a waiting row: the name, the value in words, no selection dot, and its own Skip and Exclude")
	check(w1.btns[1].tip == "Leave it in the loot window this time" and w1.btns[2].tip == "Add it to your Loot Exclusion List", "Skip and Exclude say what they do to that item")
	local c1 = f.combineRows[1]
	check(c1:IsShown() and c1.choosable and c1.dot:IsShown() and #c1.btns == 0 and c1.name.text == "Linen Cloth", "a combine row is a row you choose, with no button of its own")
	check(c1.dotFill:IsShown() and c1.hl:IsShown() and f.act:IsShown() and f.act.label.text == "Combine Linen Cloth" and f.act.active == true, "the lossless way is chosen first, and the one button does it with the accent")
	local belt
	for _, r in ipairs(f.destroyRows) do if r:IsShown() and r.name.text == "Linen Belt" then belt = r end end
	check(belt and #belt.btns == 0 and belt.value.text:find("Vendor", 1, true), "a destroy row shows its name and value, and no button of its own")
	belt:GetScript("OnClick")(belt)
	check(belt.dotFill:IsShown() and not c1.dotFill:IsShown() and f.act.label.text == "Destroy Linen Belt" and f.act.active == false, "choosing an item to let go: the button names it, without the accent")
	f.act:GetScript("OnClick")(f.act)
	local c = n.Popups.confirm
	check(c and c:IsShown() and (c.text and c.text.text or c.msg and c.msg.text or ""):find("Destroy Linen Belt", 1, true) ~= nil or (c and c:IsShown()), "destroying something that isn't junk still asks first")
	if c and c:IsShown() then c:Hide() end
	check(f.foot:IsShown() and f.foot.text == "Ranked by vendor price", "the footer says what the ranking follows")
	check(f.strata == "DIALOG" and f.toplevel == true and f.closeX:IsShown(), "it sits above the bags window, comes forward when clicked, and has a corner X in Modern")
	check(f.points[1][2] == UIParent and f.points[1][1] == "TOPLEFT" and f.points[1][4] == 508 and f.points[1][5] == 700, "it opens beside the loot window, anchored to the screen")

	-- ---- the comparison note, and loot the Exclusion List leaves behind
	f:Hide()
	loot = { { id = 9710, name = "Shiny Ring", q = 2 }, { id = 9711, name = "Small Egg", q = 1 }, { id = 9720, name = "Gnoll Paw", q = 1 } }
	MR:Never()[9720] = true
	M.fire("LOOT_OPENED"); M.runTimers()
	check(f.note:IsShown() and f.note.text == "Small Egg is worth less than anything you'd let go.", "an incoming item worth less than every offer gets a quiet note (" .. tostring(f.note.text) .. ")")
	check(f.excl:IsShown() and f.excl.text == "1 excluded item stays in the loot window" and f.exclInfo:IsShown() and (f.exclInfo.lines[1] or ""):find("On your Loot Exclusion List (1):", 1, true) and f.exclInfo.lines[1]:find("Gnoll Paw", 1, true), "loot on the Loot Exclusion List is named in a quiet line with an info tooltip")
	f:Hide(); MR:Never()[9720] = nil

	-- ---- held back: protected items that would otherwise have been offered
	n.Marks:ToggleFavorite(recOf(n, 9702))
	loot = { { id = 9710, name = "Shiny Ring", q = 2 } }
	M.fire("LOOT_OPENED"); M.runTimers()
	check(f.held:IsShown() and f.held.text == "1 protected item isn't offered" and f.heldInfo:IsShown() and (f.heldInfo.lines[1] or ""):find("Favorites (1):", 1, true) and f.heldInfo.lines[1]:find("Linen Belt", 1, true), "a favorite cheaper than the loot is counted as held back, with its reason and name")
	local beltOffered = false; for _, r in ipairs(f.destroyRows) do if r:IsShown() and r.name.text == "Linen Belt" then beltOffered = true end end
	check(not beltOffered, "and it isn't offered")
	f:Hide()

	-- ---- nothing frees a slot: the card says why
	n, M = boot(function(MM)
		for s = 1, 4 do MM.put(0, s, { id = 9800 + s, name = "Keepsake " .. s, q = 1, class = 15, subclass = 0, price = 5 }) end
	end)
	for s = 1, 4 do n.Marks:ToggleFavorite(recOf(n, 9800 + s)) end
	loot = { { id = 9710, name = "Shiny Ring", q = 2 } }
	M.fire("LOOT_OPENED"); M.runTimers()
	MR = n.MakeRoom; f = MR.frame
	check(f:IsShown() and f.card:IsShown() and f.card.head.text == "Nothing here frees a slot." and f.card.text.text:find("^Everything left is protected: 4 favorites%.") and f.card.text.text:find("Take what fits from the loot window", 1, true) and not f.act:IsShown(), "when nothing can free a slot the card says so, with the reasons counted (" .. tostring(f.card.text.text) .. ")")
	check(f.card.mark.texture and f.card.mark.texture:find("mark128", 1, true), "with BagSmith's one-color mark")
	f:Hide()

	-- ---- the pre-destroy check: an offer that can't be told from another copy, or gear sets that can't be read
	n, M = boot(fullPack)
	MR = n.MakeRoom
	loot = { { id = 9710, name = "Shiny Ring", q = 2 } }
	M.fire("LOOT_OPENED"); M.runTimers()
	local o = MR:Offer(recOf(n, 9702), false)
	check(MR:StillOk(o) == true, "(control) the belt can be destroyed")
	local oNo = MR:Offer(recOf(n, 9702), false); oNo.guid = nil
	check(select(2, MR:StillOk(oNo)) == "changed", "an offer recorded without an item instance, where the client gives instances, is refused")
	local GS = n.GearSets
	local realAvail, realSetsAt = GS.Available, GS.SetsAt
	GS.Available = function() return true end; GS.SetsAt = function() return nil, true end
	local ok2, why2 = MR:StillOk(o)
	check(ok2 == false and why2 == "unknown", "gear sets that can't be read refuse the destroy")
	GS.Available, GS.SetsAt = realAvail, realSetsAt
	GS:Rebuild()   -- the next read of the game's sets clears the failed read
	check(GS.readFailed == false, "a later successful read clears the failed-read state")
	MR.frame:Hide()

	-- ---- the Exclusion List rename
	MR:ManageNever()
	check(MR.neverFrame.title.text == "Loot Exclusion List", "the Loot Helper's list is the Loot Exclusion List")
	MR.neverFrame:Hide()
	local SP = n.SettingsPanel; SP:Show(); SP:ShowPage("loothelper")
	local texts = {}; for _, w in ipairs(SP.pools.text) do if w:IsShown() then texts[#texts + 1] = w.text.text end end
	local all = table.concat(texts, "|")
	check(all:find("Your Loot Exclusion List is empty. Use Exclude in the Loot Helper to add items.", 1, true) and all:find("Favorites are never destroyed by the Loot Helper", 1, true) and all:find("never suggested for destroying", 1, true), "the Loot Helper page names the list and what's protected")
	SP:ShowPage("automation")
	texts = {}; for _, w in ipairs(SP.pools.text) do if w:IsShown() then texts[#texts + 1] = w.text.text end end
	check(table.concat(texts, "|"):find("The enchant box from a profession window is always left for you.", 1, true), "the Prompts help says which box is always left for you")
	SP:Hide()

	-- ---- junk kept out of a sale is said
	n.Junk:Toggle(recOf(n, 9702))
	GS.Available = function() return true end; GS.SetsAt = function(_, bag, slot) if bag == 0 and slot == 2 then return { "Tank" } end end
	local ready, waiting, skipped, kept = n.Junk:Sellables("marked")
	check(kept and kept.total == 1 and n.Why:Phrase(kept) == "1 item in a gear set", "a marked item in a gear set is kept out of the sale, and counted for the chat line")
	GS.Available, GS.SetsAt = realAvail, realSetsAt

	-- ---- the shared words
	local W = n.Why
	local h = W:New(); W:Add(h, "favorite", "A"); W:Add(h, "favorite", "B"); W:Add(h, "gearset", "C"); W:Add(h, "quest", "D")
	check(W:Phrase(h) == "2 favorites, 1 item in a gear set and 1 quest item", "the phrase for a card (" .. W:Phrase(h) .. ")")
	for i = 1, 3 do W:Add(h, "favorite", "F" .. i) end
	check(W:Lines(h)[1] == "|cffe6b450Favorites (5):|r A, B, F1, and 2 more", "a tooltip line names up to three, then counts the rest (" .. tostring(W:Lines(h)[1]) .. ")")

	-- ---- Classic: from the search row down, the rows start under the portrait
	n, M = boot(fullPack, "classic")
	local V = n.Window.main
	check(V.belowShift == -48 and V.search.points[1][2] == V.title and V.search.points[1][4] == 4 - 48, "in Classic the search row and below start at the window's inner margin (48 px left of the title)")
	n:Set("skin", "modern"); M.runTimers()
	check(V.belowShift == 0 and V.search.points[1][4] == 4, "in Modern they start under the title as before")
end)()

;(function()
	-- 1.3.0: the Disenchant Helper counts what it holds back, in the shared words, and the rename
	package.loaded.mock = nil
	local M = require("mock")
	local DEID = 13262
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
	M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
	M.put(0, 3, { id = 7003, name = "Lucky Charm", q = 2, count = 1, class = 4, subclass = 1, price = 300, ilvl = 24, equip = "INVTYPE_FINGER" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
	_G.IsSpellKnown = function(id) return id == DEID end
	_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
	_G.RegisterStateDriver = function() end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE = n.Disenchant
	local function recOf(id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
	n.Marks:ToggleFavorite(recOf(7003))
	DE:Never()[7002] = true
	DE:Show(); DE:Refresh()
	local f = DE.frame
	check(#DE.entries == 1 and f.heldLine:IsShown() and f.heldLine.text == "2 held back" and f.heldInfo:IsShown(), "the header counts what the list holds back (" .. tostring(f.heldLine.text) .. ")")
	local lines = table.concat(f.heldInfo.lines, " / "):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	check(lines:find("Favorites (1): Lucky Charm", 1, true) and lines:find("On your DE Exclusion List (1): Worn Dagger", 1, true), "and the info tooltip says why, by reason and name (" .. lines .. ")")
	check(f.never.label.text == "Exclude" and f.never.tip == "Add it to your DE Exclusion List", "the button is Exclude")
	DE:ManageNever()
	check(DE.neverFrame.title.text == "DE Exclusion List", "the helper's list is the DE Exclusion List")
	DE.neverFrame:Hide()
	-- the empty card carries the count too
	DE:Skip()
	check(f.empty:IsShown() and f.empty.held:IsShown() and f.empty.held.text == "2 held back" and f.empty.heldInfo:IsShown(), "the empty card carries the held-back count with its info icon")
	f:Hide()
end)()
