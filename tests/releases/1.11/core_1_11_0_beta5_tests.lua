-- ======== 1.11.0-beta5 (Shweep, 26 Nov: "build", on the plan for the beta4 audit) ========
-- The answer to the independent audit of 1.11.0-beta4 (26 Nov: "Hold promotion to stable"). Its four findings, each
-- reproduced on beta4 with the auditor's own cases before anything was changed, and each of those cases kept here:
--   B4-1 (P2) "Sections can be saved to a renamed or deleted sheet". The Sections on a Sheet window only heard of a
--        sheet's rename or deletion when some section's own list changed; open on a sheet no section was set to, it
--        kept the old name and the next tick saved it. It is told every time now, follows a rename where the old
--        name is gone and the new one is there, moves off a deleted sheet and says so, and looks before it writes.
--        A section being edited follows the same way.
--   B4-2 (P2) "Disenchant Results reports a definitive net on incomplete data". The sale side counted every cast and
--        the material side only the loot that was seen; and an item with no auction price was compared by its vendor
--        price as if that were its best sale. The comparison is a matched set now (an item's sale values join with
--        its first counted material), says how many it counts, and names no winner while a counted item that could
--        have been auctioned had no price.
--   B4-3 (P3) "New Gear Set disappears if the current search matches nothing". The count and the button stay.
--   B4-4 (P3) "Saved Results validation misses upper bounds in nested fields". One bound for every number, a cap on
--        how much of a damaged table is read, values capped where they are multiplied and shown, and a name with a
--        | code or a control character is not shown.

local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function click(b) b:GetScript("OnClick")(b) end
local function pump(M) for _ = 1, 20 do M.runTimers() end end
local function copy(t) if type(t) ~= "table" then return t end local o = {}; for k, v in pairs(t) do o[k] = copy(v) end return o end

------------------------------------------------------------------------
-- B4-1. Sections on a Sheet and a sheet renamed or deleted while it is open
------------------------------------------------------------------------
local function boot(opt)
	opt = opt or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 13 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = opt.profile or {} }, whatsNewSeen = "1.10.0" }
	_G.BagSmithWhatsNew = nil
	_G.GuildBankFrame, _G.MailFrame = nil, nil
	local n = M.loadAddon("BagSmith"); n.version = "1.11.0-beta5"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); for _ = 1, 12 do M.runTimers() end
	return M, n, n.Sections
end
local function names(S, id) local l = S:Sheets(id); return l and table.concat(l, ",") or "every sheet" end
local function rowFor(f, id) for _, r in ipairs(f.rows) do if r:IsShown() and r.id == id then return r end end end
local GONE = "That sheet isn't there any more, so nothing was changed."

do
	-- the auditor's first case: a sheet no section is set to, deleted elsewhere with the window open
	local M, n, S = boot()
	local id = S:Create("Audit Cloth")
	check(n:SaveSheet("Audit Scratch"), "(set up: a sheet of your own)")
	local f = S:OpenSheetSections("Audit Scratch")
	check(f:IsShown() and f.sheet == "Audit Scratch" and f.pick.label.text == "Audit Scratch" and S:Sheets(id) == nil, "(Sections on a Sheet is open on it, and no section is set to it)")
	n:DeleteSheet("Audit Scratch")
	check(f.sheet ~= "Audit Scratch" and f.sheet == "All" and f.pick.label.text == "All", "the sheet is deleted elsewhere: the window moves off it at once (it stayed, in beta4): " .. tostring(f.sheet))
	check(f.err.text == "The sheet \"Audit Scratch\" is gone. Now on \"All\".", "and says so: " .. tostring(f.err.text))
	S:TickSheetSection(id)
	check(names(S, id) == "All", "a tick now is for the sheet the window shows, never the deleted one: " .. names(S, id))
	check(f.err.text == "", "(the note clears with the next tick)")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- the auditor's second case: renamed elsewhere with the window open
	local M, n, S = boot()
	local id = S:Create("Audit Cloth")
	check(n:SaveSheet("Audit Old"), "(set up: a sheet of your own)")
	local f = S:OpenSheetSections("Audit Old")
	check(n:UpdateSheet("Audit Old", "Audit New"), "(the sheet is renamed elsewhere)")
	check(f.sheet == "Audit New" and f.pick.label.text == "Audit New" and f.err.text == "", "the window follows the rename (it kept the old name, in beta4): " .. tostring(f.sheet))
	S:TickSheetSection(id)
	check(names(S, id) == "Audit New", "a tick saves the new name, not the old: " .. names(S, id))
	check(rowFor(f, id).check:GetChecked() and plain(rowFor(f, id).note.text) == "only here", "and the row shows it")
	-- renamed again, now that a section is set to it: the section follows as it always has, and the window with it
	check(n:UpdateSheet("Audit New", "Audit Newer"), "(renamed once more)")
	check(names(S, id) == "Audit Newer" and f.sheet == "Audit Newer" and f.pick.label.text == "Audit Newer" and rowFor(f, id).check:GetChecked(),
		"a sheet a section is set to, renamed: the section follows and the window stays with the sheet (it jumped to the first tab, in beta4): " .. tostring(f.sheet))
	S:TickSheetSection(id)
	check(names(S, id) == "every sheet", "unticking takes the new name off")
	-- the same name saved again (only the filters): nothing to follow
	check(n:UpdateSheet("Audit Newer", "Audit Newer") and f.sheet == "Audit Newer" and f.err.text == "", "saving a sheet under its own name changes nothing here")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- a sheet a section is set to, deleted with the window open
	local M, n, S = boot()
	local a, b = S:Create("Cloth"), S:Create("Herbs")
	check(n:SaveSheet("Raid Night"), "(set up: a sheet)")
	local f = S:OpenSheetSections("Raid Night")
	S:TickSheetSection(a)
	check(names(S, a) == "Raid Night" and names(S, b) == "every sheet", "(Cloth is set to show on it)")
	local from = #M.log + 1
	n:DeleteSheet("Raid Night")
	local said
	for i = from, #M.log do if plain(M.log[i]):find("The section \"Cloth\" was only shown on the sheet Raid Night; it now shows on every sheet.", 1, true) then said = true end end
	check(names(S, a) == "every sheet" and said, "its sheet deleted: the section shows on every sheet again and chat says so, as before")
	check(f.sheet == "All" and f.err.text == "The sheet \"Raid Night\" is gone. Now on \"All\"." and not rowFor(f, a).check:GetChecked(), "and the window has moved off it, saying so")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- your bags and your bank can each have a sheet of the same name
	local M, n, S = boot()
	M.fire("BANKFRAME_OPENED"); M.runTimers(); M.runTimers()
	local bank = n.Window.bank
	check(bank and bank.isBank, "(set up: the bank is open)")
	local id, other = S:Create("Cloth"), S:Create("Herbs")
	check(n:SaveSheet("Twin") and n:SaveSheet("Twin", bank) and #n.db.sheets == 1 and #n.db.bankSheets == 1, "(a sheet named Twin in the bags, and one in the bank)")
	local f = S:OpenSheetSections("Twin")
	S:TickSheetSection(id)
	check(names(S, id) == "Twin", "(Cloth is set to Twin)")
	check(n:UpdateSheet("Twin", "Twin Two"), "(the bags' Twin is renamed)")
	check(f.sheet == "Twin" and f.pick.label.text == "Twin" and f.err.text == "", "the bank still has a Twin: the window stays on it")
	check(names(S, id) == "Twin,Twin Two", "and the section shows on both, as before")
	S:TickSheetSection(other)
	check(names(S, other) == "Twin", "a tick for Twin is still good: it is a sheet")
	n:DeleteSheet("Twin", bank)
	check(f.sheet == "All" and f.err.text == "The sheet \"Twin\" is gone. Now on \"All\".", "the bank's Twin deleted too: now it is gone, and the window moves")
	check(names(S, id) == "Twin Two" and names(S, other) == "every sheet", "the sections let go of it")
	-- deleted in one while the other keeps it
	check(n:SaveSheet("Pair") and n:SaveSheet("Pair", bank), "(another pair)")
	f = S:OpenSheetSections("Pair")
	n:DeleteSheet("Pair")
	check(f.sheet == "Pair" and f.err.text == "", "one of a pair deleted: the name is still a sheet, and the window stays")
	S:TickSheetSection(other)
	check(names(S, other) == "Pair", "and takes a tick")
	M.fire("BANKFRAME_CLOSED"); M.runTimers()
	check((n.errors or 0) == 0, "no errors")
end
do
	-- looked at before anything is written: a sheet that went some way the window wasn't told of
	local M, n, S = boot()
	local id = S:Create("Cloth")
	check(n:SaveSheet("Quiet"), "(set up: a sheet)")
	local f = S:OpenSheetSections("Quiet")
	table.remove(n.db.sheets, 1)   -- gone without a word (another addon, a hand-edited file)
	check(f.sheet == "Quiet", "(the window hasn't heard)")
	S:TickSheetSection(id)
	check(names(S, id) == "every sheet", "a tick for a sheet that isn't there saves nothing: " .. names(S, id))
	check(f.err.text == GONE and f.sheet == "All" and f.pick.label.text == "All" and not rowFor(f, id).check:GetChecked(), "it says so and moves to a sheet there is: " .. tostring(f.err.text))
	S:TickSheetSection(id)
	check(names(S, id) == "All" and f.err.text == "", "the next tick is an ordinary one")
	-- a section already set to the sheet that went: a tick there writes nothing either (not even the untick)
	local other = S:Create("Herbs")
	check(n:SaveSheet("Quiet Two"), "(another sheet)")
	f = S:OpenSheetSections("Quiet Two")
	S:TickSheetSection(other)
	check(names(S, other) == "Quiet Two" and rowFor(f, other).check:GetChecked(), "(Herbs is set to it)")
	table.remove(n.db.sheets, 1)
	S:TickSheetSection(other)
	check(names(S, other) == "Quiet Two" and f.err.text == GONE and f.sheet == "All", "a tick on a row of a sheet that went is refused before anything is written: " .. names(S, other))
	-- the rule itself, under the window
	local ok, why = S:SetOnSheet(id, "No Such Sheet", true)
	check(ok == false and why == GONE and names(S, id) == "All", "S:SetOnSheet won't put a section on a sheet that isn't one")
	check(S:SetOnSheet(id, "Gear", true) == true and names(S, id) == "All,Gear", "(one of BagSmith's tabs is)")
	S:SetSheets(id, { "All", "Left Over" })
	check(S:SetOnSheet(id, "Left Over", false) == true and names(S, id) == "All", "taking a name that is no longer a sheet off a list is always allowed")
	check(S:IsTabChoice("All") and S:IsTabChoice("Bank") and not S:IsTabChoice("GearSets") and not S:IsTabChoice("Left Over") and not S:IsTabChoice(nil), "(S:IsTabChoice: the tabs and sheets a section can be set to)")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- the sheet menu left open while its sheet goes
	local M, n, S = boot()
	local id = S:Create("Cloth")
	check(n:SaveSheet("First") and n:SaveSheet("Second"), "(set up: two sheets)")
	local f = S:OpenSheetSections("First")
	S:PickSheetMenu(f.pick)
	local second, gear
	for _, it in ipairs(n.menuFrame.items or {}) do if it.text == "Second" then second = it elseif it.text == "Gear" then gear = it end end
	check(second and gear, "(the menu lists Second and Gear)")
	n:DeleteSheet("Second")
	check(f.sheet == "First" and f.err.text == "", "(another sheet deleted: the window stays where it is)")
	second.onClick()
	check(f.sheet == "First" and f.pick.label.text == "First" and f.err.text == GONE, "picking a sheet that went while the menu was open picks nothing, and says so: " .. tostring(f.sheet))
	gear.onClick()
	check(f.sheet == "Gear" and f.err.text == "", "a sheet that is there is picked as ever")
	S:TickSheetSection(id)
	check(names(S, id) == "Gear", "and ticked")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- a section being edited when one of its sheets is renamed or deleted
	local M, n, S = boot()
	local E = n.SectionEditor
	local id = S:Create("Cloth")
	check(n:SaveSheet("Old Name") and n:SaveSheet("Other"), "(set up: two sheets)")
	S:SetSheets(id, { "Old Name", "Gear" })
	E:Open(id)
	check(E.frame:IsShown() and table.concat(E.draft.sheets, ",") == "Old Name,Gear", "(the editor is open on a section set to Old Name and Gear)")
	check(n:UpdateSheet("Old Name", "New Name"), "(Old Name is renamed elsewhere)")
	check(table.concat(E.draft.sheets, ",") == "New Name,Gear", "the editor's ticks follow the rename: " .. table.concat(E.draft.sheets, ","))
	local chips = {}
	for _, c in ipairs(E.frame.sheetChips) do if c:IsShown() then chips[c.sheet] = c.active and "on" or "off" end end
	check(chips["New Name"] == "on" and chips["Old Name"] == nil and chips["Gear"] == "on" and chips["Other"] == "off", "and its row of sheets is drawn again: New Name ticked, Old Name gone")
	E:Save()
	check(names(S, id) == "New Name,Gear", "so saving doesn't put the old name back (it did, before): " .. names(S, id))
	-- deleted while editing
	E:Open(id)
	n:DeleteSheet("New Name")
	check(table.concat(E.draft.sheets, ",") == "Gear", "a sheet deleted while editing: the tick goes with it")
	E:Save()
	check(names(S, id) == "Gear", "and saving keeps the rest")
	-- ticks not saved yet follow too
	E:Open(id)
	E:ToggleSheet("Other")
	check(table.concat(E.draft.sheets, ",") == "Gear,Other", "(Other is ticked in the editor, not saved)")
	check(n:UpdateSheet("Other", "Another"), "(and renamed)")
	check(table.concat(E.draft.sheets, ",") == "Gear,Another", "a tick not saved yet follows the rename")
	chips = {}
	for _, c in ipairs(E.frame.sheetChips) do if c:IsShown() then chips[c.sheet] = c.active and "on" or "off" end end
	check(chips["Another"] == "on" and chips["Other"] == nil, "and the editor draws it (no saved section changed, so nothing else would have)")
	n:DeleteSheet("Another")
	check(table.concat(E.draft.sheets, ",") == "Gear", "and goes with a deletion")
	E:Save()
	check(names(S, id) == "Gear", "saved: Gear alone")
	-- the last one going leaves nothing ticked, which the editor already handles
	S:SetSheets(id, nil)
	check(n:SaveSheet("Solo"), "(one more sheet)")
	S:SetSheets(id, { "Solo" })
	E:Open(id)
	local from = #M.log + 1
	n:DeleteSheet("Solo")
	check(#E.draft.sheets == 0 and E:Sheets() == nil and names(S, id) == "every sheet", "its only sheet deleted while editing: nothing is ticked, and the saved section shows on every sheet")
	E:Save()
	check(names(S, id) == "every sheet", "saving leaves it on every sheet")
	-- with the editor closed, nothing is touched
	E.frame:Hide()
	check(n:SaveSheet("Later") and n:UpdateSheet("Later", "Latest"), "a sheet renamed with the editor closed: no errors")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- nothing open at all, and the window closed: a sheet comes and goes without a word
	local M, n, S = boot()
	check(n:SaveSheet("A") and n:UpdateSheet("A", "B"), "(a sheet made and renamed with no window ever opened)")
	n:DeleteSheet("B")
	check(S.sheetFrame == nil and (n.errors or 0) == 0, "no window is made for it, and no errors")
	check(n:SaveSheet("C"), "(a sheet)")
	local f = S:OpenSheetSections("C")
	f:Hide()
	n:DeleteSheet("C")
	check(not f:IsShown() and (n.errors or 0) == 0, "closed, it is left alone")
	f = S:OpenSheetSections("C")
	check(f.sheet == "All" and f.err.text == "", "and opens on a sheet there is, with nothing to say")
end

------------------------------------------------------------------------
-- B4-2. Disenchant Results: the comparison is a matched set, and says what it counts
------------------------------------------------------------------------
local DEID = 13262
local MATNAMES = { [10940] = "Strange Dust", [11083] = "Soul Dust", [10938] = "Lesser Magic Essence", [10939] = "Greater Magic Essence", [10998] = "Lesser Astral Essence", [11082] = "Greater Astral Essence", [10978] = "Small Glimmering Shard", [11084] = "Large Glimmering Shard", [11138] = "Small Glowing Shard" }
local PRICES = { [7001] = 1500, [7002] = 600, [10940] = 120, [10938] = 300, [10939] = 500, [10998] = 400, [11083] = 150, [11082] = 900, [10978] = 800, [11084] = 2000, [11138] = 1200 }
local function without(...) local p = copy(PRICES); for _, id in ipairs({ ... }) do p[id] = nil end return p end
local function deBoot(opt)
	opt = opt or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 452, ilvl = 23, equip = "INVTYPE_FEET" })
	M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
	M.put(0, 3, { id = 7003, name = "Ring of the Deep", q = 3, count = 1, class = 4, subclass = 0, price = 2500, ilvl = 24, equip = "INVTYPE_FINGER", bound = true })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = opt.skin or "modern", deEnabled = true } }, whatsNewSeen = "1.10.0", deShared = opt.deShared }
	_G.BagSmithWhatsNew = nil
	_G.GuildBankFrame, _G.MailFrame = nil, nil
	_G.IsSpellKnown = function(id) return id == DEID end
	_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
	_G.RegisterStateDriver = function() end
	_G.GetMoneyString = function(c) return ("%dg %ds %dc"):format(math.floor(c / 10000), math.floor(c / 100) % 100, c % 100) end
	_G.LOOT_ITEM_SELF = "You receive loot: %s."; _G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
	_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."; _G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(link) local id = tonumber(tostring(link):match("item:(%d+)")) or link; if MATNAMES[id] then return MATNAMES[id], nil, id == 10978 and 3 or 1 end return realInfo(link) end
	local prices = opt.prices or PRICES
	if opt.noAH then _G.Auctionator = nil else
		_G.Auctionator = { API = { v1 = {
			GetAuctionPriceByItemLink = function(_, link) local id = tonumber(link:match("item:(%d+)")); return id and prices[id] end,
			GetAuctionPriceByItemID = function(_, id) return prices[id] end,
			GetAuctionAgeByItemLink = function() return nil end,
		} } }
	end
	local n = M.loadAddon("BagSmith"); n.version = "1.11.0-beta5"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	for _ = 1, 10 do M.runTimers() end
	local DE = n.Disenchant
	DE:Show(); M.runTimers()
	return M, n, DE, prices
end
local function entryOf(DE, id) for _, e in ipairs(DE.entries or {}) do if e.itemID == id then return e end end end
local function lootLine(M, id, count)
	M.fire("CHAT_MSG_LOOT", ("You receive loot: |cffffffff|Hitem:%d:0:0:0:0:0:0:0|h[mat]|h|r%s."):format(id, count > 1 and ("x" .. count) or ""))
end
-- A cast, up to the moment it succeeds; then its loot; then the item leaving its slot.
local function cast(M, DE, id)
	local e = entryOf(DE, id)
	DE:Select(e)
	local b = DE:Button()
	b:GetScript("PreClick")(b)
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", DEID)
	return e
end
local function finish(M, e) M.bags[e.bag][e.slot] = nil; M.fire("BAG_UPDATE_DELAYED"); M.fire("LOOT_CLOSED"); M.runTimers(); M.runTimers(); M.runTimers() end
local function disenchant(M, DE, id, loot)
	local e = cast(M, DE, id)
	for _, l in ipairs(loot) do lootLine(M, l[1], l[2]) end
	finish(M, e)
	return e
end
-- The view's lines as { left, right, kind }, and one of them by its left text.
local function lines(DE, which)
	local out = {}
	for _, l in ipairs((DE:ResultLines(which or "session"))) do out[#out + 1] = { plain(l.left), plain(l.right), l.kind, l.id } end
	return out
end
local function line(DE, left, which) for _, l in ipairs(lines(DE, which)) do if l[1] == left then return l end end end
local function matOf(DE, id, i) return DE:Expectation(entryOf(DE, id).rec)[i or 1][1] end

-- (By design since 1.11.0-beta6, the beta5 re-audit's B5-2, throughout this section: every auction house amount in
-- the comparison is after the 5% cut. The boots' 15s quote leaves 14s25c; 24s of dust leaves 22s80c, so the boots'
-- disenchant is ahead by 8s55c where it was 9s; the materials row is "Their Materials, Sold at the AH Now"; and the
-- saved record's version is 3. The scenarios and what they show are unchanged.)
do
	-- the auditor's first case: a second cast that succeeds and gives no loot BagSmith sees
	local M, n, DE = deBoot()
	disenchant(M, DE, 7001, { { 10940, 20 } })
	local t = DE:Results("session").tracked
	check(t.n == 1 and t.cn == 1 and t.matsValue == 2400 and t.alt == 1425 and t.ahead == 855, "(one disenchant: 24s of dust against boots worth 15s at the auction house; after the cut, ahead by 8s55c)")
	check(line(DE, "Counted: 1 of 1 disenchants. The other gave no materials BagSmith saw.") == nil and line(DE, "Disenchanting Came Out Ahead By")[2] == DE.Money(855),
		"with every disenchant counted, no note about what is counted, and the winner as before")
	disenchant(M, DE, 7002, {})
	local r = DE:Results("session")
	t = r.tracked
	check(r.n == 2 and t.n == 2 and t.matsValue == 2400, "(a second disenchant succeeds and no materials are seen: two on record, the materials unchanged)")
	check(t.cn == 1 and t.vendor == 452 and t.ah == 1425 and t.ahN == 1 and t.alt == 1425, "its sale values stay out of the comparison (beta4 added the dagger's 8s to the sale side alone): " .. tostring(t.alt))
	check(t.ahead == 855, "so the comparison is still the boots against the boots' dust (+8s55c after the cut), not beta4's result across two: " .. tostring(t.ahead))
	local note = line(DE, "Counted: 1 of 2 disenchants. The other gave no materials BagSmith saw.")
	check(note and note[3] == "note", "and the view says which disenchants it counts")
	local L = lines(DE)
	local at = {}
	for i, l in ipairs(L) do at[l[1]] = i end
	check(at["If You Had Sold Them Instead"] and at["Counted: 1 of 2 disenchants. The other gave no materials BagSmith saw."] == at["If You Had Sold Them Instead"] + 1, "right under the heading, before the numbers")
	check(line(DE, "Items Disenchanted")[2] == "2" and line(DE, "To a Vendor")[2] == DE.Money(452) and line(DE, "Best of the Two")[2] == DE.Money(1425), "Items Disenchanted still counts both; the sold-instead lines are the counted one's")
	check(r.best and r.best.id == 7001, "(the most valuable item is the boots either way)")
	-- a third with no loot
	disenchant(M, DE, 7003, {})
	check(line(DE, "Counted: 1 of 3 disenchants. The other 2 gave no materials BagSmith saw."), "two unseen: \"The other 2\"")
	check(DE:Results("session").best.id == 7003, "(a disenchant whose loot wasn't seen is still the most valuable item if it was)")
	-- the same in All Time, and in what is saved
	check(line(DE, "Counted: 1 of 3 disenchants. The other 2 gave no materials BagSmith saw.", "all") and DE:Results("all").tracked.ahead == 855, "All Time says the same")
	local st = BagSmithDB.deShared.stats
	check(st.v == 3 and st.n == 3 and st.cn == 1 and st.vendor == 452 and st.ah == 1425 and st.ahN == 1 and st.ahU == 0 and st.alt == 1425, "the saved record keeps the counted ones apart from the rest")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- when an item joins: with its first material, once
	local M, n, DE = deBoot()
	local m1 = matOf(DE, 7001, 1)
	local second = DE:Expectation(entryOf(DE, 7001).rec)[2]
	local m2 = second and second[1]
	local e = cast(M, DE, 7001)
	local t = DE:Results("session").tracked
	check(t and t.n == 1 and t.cn == 0 and t.ahead == nil and t.vendor == 0 and t.alt == 0, "the cast succeeded and its loot hasn't come: on record, not yet in the comparison")
	check(line(DE, "If You Had Sold Them Instead") == nil and line(DE, "Items Disenchanted")[2] == "1", "(nothing to compare is shown until there is)")
	lootLine(M, m1, 2)
	t = DE:Results("session").tracked
	check(t.cn == 1 and t.vendor == 452 and t.alt == 1425, "its first material counted: now it is in")
	if m2 then lootLine(M, m2, 1) end
	lootLine(M, m1, 1)
	t = DE:Results("session").tracked
	check(t.cn == 1 and t.vendor == 452 and t.alt == 1425 and t.ahN == 1, "a second material, or more of the first, doesn't count the item twice")
	finish(M, e)
	check(DE:Results("session").tracked.cn == 1 and line(DE, "If You Had Sold Them Instead"), "and the comparison shows")
	-- a call with no cast behind it (nothing in the game makes one) notes the item and compares nothing
	DE:NoteDisenchanted({ quality = 2, vendor = 500, itemID = 7001, name = "Loose" })
	t = DE:Results("session").tracked
	check(t.n == 2 and t.cn == 1 and t.vendor == 452, "an item noted with no cast to match stays out")
	DE:NoteMatched(nil); DE:NoteMatched({}); DE:NoteMatched({ matched = true, sale = { vendor = 9, worth = 9 } })
	check(DE:Results("session").tracked.cn == 1 and (n.errors or 0) == 0, "and a cast with nothing noted, or already matched, adds nothing")
end
do
	-- the auditor's second case: an item that could have gone to the auction house and had no price there
	local M, n, DE = deBoot({ prices = without(7002) })
	local dagger = entryOf(DE, 7002)
	check(dagger and dagger.vendor == 800 and dagger.ah == nil and not dagger.bound, "(set up: a dagger worth 8s to a vendor, with no auction price)")
	local mat = matOf(DE, 7002)
	disenchant(M, DE, 7002, { { mat, 3 } })
	local t = DE:Results("session").tracked
	check(t.cn == 1 and t.ahU == 1 and t.ahN == 0 and t.vendor == 800 and t.matsValue == PRICES[mat] * 3 and t.matsKnown, "(its materials are counted and priced)")
	check(t.ahead == nil, "no winner: its best sale isn't known (beta4 compared the materials with the vendor price alone)")
	check(line(DE, "Disenchanting Came Out Ahead By") == nil and line(DE, "Selling Would Have Paid More By") == nil and line(DE, "Disenchanting and Selling Came Out Even") == nil, "no winner line")
	check(line(DE, "Best of the Two") == nil, "and no Best of the Two, which would be the vendor price under another name")
	local why = line(DE, "No winner named: 1 of these had no auction price when you disenchanted it.")
	check(why and why[3] == "note", "it says why")
	check(line(DE, "To a Vendor")[2] == DE.Money(800) and line(DE, "Their Materials, Sold at the AH Now")[2] == DE.Money(DE.AfterCut(PRICES[mat] * 3)), "the two things that are known stay: the vendor total and the materials' value")
	-- one with a price beside it
	disenchant(M, DE, 7001, { { matOf(DE, 7001), 2 } })
	t = DE:Results("session").tracked
	check(t.cn == 2 and t.ahN == 1 and t.ahU == 1 and t.ahead == nil, "(a second, with an auction price)")
	check(line(DE, "At the Auction House (1 of 2 had a price)")[2] == DE.Money(1425) and line(DE, "Best of the Two") == nil and line(DE, "No winner named: 1 of these had no auction price when you disenchanted it."), "the auction house line says one of two had a price; still no winner")
	check(BagSmithDB.deShared.stats.ahU == 1, "(saved with the record)")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- two of them
	local M, n, DE = deBoot({ prices = without(7001, 7002) })
	disenchant(M, DE, 7001, { { matOf(DE, 7001), 2 } })
	disenchant(M, DE, 7002, { { matOf(DE, 7002), 3 } })
	check(DE:Results("session").tracked.ahU == 2 and line(DE, "No winner named: 2 of these had no auction price when you disenchanted them."), "two with no auction price: \"2 of these ... them\"")
	check(line(DE, "At the Auction House") == nil, "(and no auction house line with nothing to total)")
end
do
	-- a soulbound item never had an auction price to miss: its vendor price is its best sale
	local M, n, DE = deBoot()
	local ring = entryOf(DE, 7003)
	check(ring and ring.bound and ring.ah == nil and ring.vendor == 2500, "(set up: a soulbound ring worth 25s to a vendor)")
	local mat = matOf(DE, 7003)
	disenchant(M, DE, 7003, { { mat, 1 } })
	local t = DE:Results("session").tracked
	check(t.cn == 1 and t.ahU == 0 and t.ahN == 0 and t.alt == 2500 and t.ahead == DE.AfterCut(PRICES[mat]) - 2500, "it is compared by its vendor price, and a winner is named: " .. tostring(t.ahead))
	check(line(DE, t.ahead > 0 and "Disenchanting Came Out Ahead By" or "Selling Would Have Paid More By") and not line(DE, "No winner named: 1 of these had no auction price when you disenchanted it."), "the winner line shows, with no note")
end
do
	-- with no auction prices at all, the line about AH values is the whole story
	local M, n, DE = deBoot({ noAH = true })
	disenchant(M, DE, 7002, { { matOf(DE, 7002), 3 } })
	local t = DE:Results("session").tracked
	check(t.cn == 1 and t.ahU == 1 and t.ahead == nil and not t.matsKnown, "(no auction addon: nothing priced)")
	check(line(DE, "AH values need Auctionator or Blackthornes Tradeskills.") and line(DE, "To a Vendor")[2] == DE.Money(800), "the view says AH values need an addon, and shows the vendor total")
	check(line(DE, "No winner named: 1 of these had no auction price when you disenchanted it.") == nil and line(DE, "Their Materials, Sold at the AH Now") == nil and line(DE, "Best of the Two") == nil,
		"and doesn't add a second note about a winner nobody could have named")
end
do
	-- All Time: older disenchants in the log, then one counted and one not
	local log = { version = 3, results = { ["2:3:a"] = { n = 4, mats = { [10940] = 9, [10938] = 2 }, seen = { [10940] = 4, [10938] = 2 } } }, materials = {} }
	local M, n, DE = deBoot({ deShared = copy(log) })
	disenchant(M, DE, 7001, { { matOf(DE, 7001), 2 } })
	check(line(DE, "Counted since 1.11: 1 of your 5 disenchants.", "all") and line(DE, "1 more since then gave no materials BagSmith saw.", "all") == nil, "(All Time, one counted of five on record)")
	disenchant(M, DE, 7002, {})
	local r = DE:Results("all")
	check(r.n == 6 and r.partial and r.tracked.n == 2 and r.tracked.cn == 1, "(a second since, with no materials seen)")
	local a, b = line(DE, "Counted since 1.11: 1 of your 6 disenchants.", "all"), line(DE, "1 more since then gave no materials BagSmith saw.", "all")
	check(a and b and a[3] == "note" and b[3] == "note", "All Time says how many it counts, and that one more gave nothing it saw")
	disenchant(M, DE, 7003, {})
	check(line(DE, "2 more since then gave no materials BagSmith saw.", "all"), "\"2 more since then\"")
	check(line(DE, "Counted: 1 of 3 disenchants. The other 2 gave no materials BagSmith saw.", "session"), "(This Session words it its own way)")
end
do
	-- a record written by beta3 or beta4 has no version: it starts over, and the log's counts and materials stay
	local old = { version = 3, results = { ["2:3:a"] = { n = 3, mats = { [10940] = 6 }, seen = { [10940] = 3 } } }, materials = {},
		stats = { n = 3, vendor = 3752, ah = 2100, ahN = 2, alt = 4800, q = { [2] = 2, [3] = 1 }, mats = { [10940] = 6 }, best = { id = 7001, q = 2, vendor = 452, ah = 1500, worth = 1500, name = "Sturdy Boots" } } }
	local M, n, DE = deBoot({ deShared = copy(old) })
	local st = DE:Stats()
	check(st.v == 3 and st.n == 0 and st.cn == 0 and st.alt == 0 and next(st.mats) == nil and st.best == nil, "a beta3 or beta4 record (no version) isn't read: its totals were not a matched set")
	local r = DE:Results("all")
	check(r.n == 3 and r.matsValue == 6 * 120 and r.tracked == nil and r.best == nil, "All Time still has the three disenchants and their materials, from the log")
	check(line(DE, "If You Had Sold Them Instead", "all") == nil and line(DE, "Items Disenchanted", "all")[2] == "3", "with no sold-instead lines until a disenchant is counted")
	-- one that reaches memory some other way is no better
	BagSmithDB.deShared.stats = { n = 9, alt = 5, vendor = 5, q = {}, mats = { [10940] = 3 } }
	st = DE:Stats()
	check(st.v == 3 and st.n == 0 and st.alt == 0 and next(st.mats) == nil and BagSmithDB.deShared.stats == st, "a record without the version found in memory is replaced too")
	disenchant(M, DE, 7001, { { matOf(DE, 7001), 2 } })
	check(line(DE, "Counted since 1.11: 1 of your 4 disenchants.", "all") and DE:Results("all").tracked.cn == 1, "the next one starts the count")
	-- a record of this version comes back as it was saved
	local saved = copy(BagSmithDB.deShared)
	M, n, DE = deBoot({ deShared = saved })
	st = DE:Stats()
	check(st.v == 3 and st.n == 1 and st.cn == 1 and st.vendor == 452 and st.ah == 1425 and st.ahN == 1 and st.ahU == 0 and st.alt == 1425 and st.best and st.best.name == "Sturdy Boots", "this version's record loads as it was saved")
	check(DE:Results("all").tracked.ahead == DE.AfterCut(PRICES[matOf(DE, 7001)] * 2) - 1425, "and compares as it did")
	check((n.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- B4-3. The Gear Sets sheet when a search matches none of your sets' items
------------------------------------------------------------------------
local function gearBoot(sets)
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 10, ilvl = 10 })
	M.put(0, 5, { id = 9001, name = "Silk Robe", q = 2, count = 1, class = 4, subclass = 1, type = "Armor", sub = "Cloth", equip = "INVTYPE_ROBE", bind = 2, price = 300, ilvl = 20 })
	_G.INVTYPE_ROBE = "Chest"
	_G.ItemTreeAPI = nil
	M.removeEquipmentSets()
	if sets then
		M.installEquipmentSets()
		for i = 1, sets do M.addSet(("Set %02d"):format(i), { [5] = 0x00300000 + 5 }) end   -- its chest piece: the Silk Robe, bag 0 slot 5
	end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { view = "list", grp = "type", favSection = true, recentSection = false } }, whatsNewSeen = "1.10.0" }
	_G.BagSmithWhatsNew = nil
	_G.GuildBankFrame, _G.MailFrame = nil, nil
	local n = M.loadAddon("BagSmith"); n.version = "1.11.0-beta5"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); pump(M)
	return n, M, n.Window.main
end
local LIMIT = "You have the most sets the game allows (10). Delete one to make another."
do
	-- the auditor's case: two sets, and a search that matches nothing
	local n, M, main = gearBoot(2)
	main:SetSheet("GearSets"); pump(M)
	local note = main.gsNote
	check(note:IsShown() and note.btn:IsShown() and note.text.text == "2 of 10 gear sets" and not note.count:IsShown(), "(the Gear Sets sheet: the count and New Gear Set under the sets)")
	main.st.filters.text = "AUDIT NO MATCH"; n:RefreshViews(true); pump(M)
	note = main.gsNote
	check(note:IsShown() and note.text.text == "No gear set items match.", "a search that matches none of them says so, as before: " .. tostring(note.text.text))
	check(note.btn:IsShown() and note.btn.label.text == "New Gear Set" and note.btn:IsEnabled() and not note.btn.offReason, "and New Gear Set stays (it went, in beta4)")
	check(note.count:IsShown() and note.count.text == "2 of 10 gear sets", "with the count on a line of its own: " .. tostring(note.count.text))
	check(note.count.points[1][2] == note.text and note.btn.points[1][2] == note.count, "the note, then the count, then the button")
	click(note.btn)
	local p = n.promptFrame
	check(p and p:IsShown(), "a click asks for the new set's name")
	p.edit:SetText("Healing"); click(p.ok); pump(M)
	check(#n.GearSets:Sets() == 3 and n.GearSets:Find("Healing") ~= nil and main.gsNote.count.text == "3 of 10 gear sets", "the set is made with the search still on, and the count follows")
	-- the search cleared: back under the sets
	main.st.filters.text = ""; n:RefreshViews(true); pump(M)
	note = main.gsNote
	check(note:IsShown() and note.text.text == "3 of 10 gear sets" and not note.count:IsShown() and note.btn:IsShown() and note.btn.label.text == "New Gear Set" and note.btn.points[1][2] == note.text,
		"the search cleared: the count and the button under the sets, as they were")
	-- another character's bags: nothing to make
	main.st.filters.text = "AUDIT NO MATCH"; n:RefreshViews(true); pump(M)
	n.ui.owner = "Someone - Realm"; main:Refresh(true); pump(M)
	note = main.gsNote
	check(not (note:IsShown() and note.btn:IsShown()) and not (note:IsShown() and note.count:IsShown()), "looking at another character's bags: no button and no count, search or not")
	n.ui.owner = nil
	check((n.errors or 0) == 0, "no errors")
end
do
	-- at the game's limit, the button is greyed there too
	local n, M, main = gearBoot(10)
	main:SetSheet("GearSets"); pump(M)
	main.st.filters.text = "AUDIT NO MATCH"; n:RefreshViews(true); pump(M)
	local note = main.gsNote
	check(note.text.text == "No gear set items match." and note.count.text == "10 of 10 gear sets" and note.btn:IsShown(), "(ten sets, and a search that matches nothing)")
	check(not note.btn:IsEnabled() and note.btn.offReason == LIMIT, "at the limit the button is greyed and says why, here as under the sets")
	n.GearSets:Delete("Set 10"); pump(M)
	check(main.gsNote.count.text == "9 of 10 gear sets" and main.gsNote.btn:IsEnabled() and not main.gsNote.btn.offReason, "one set fewer: usable again")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- no sets at all: the first-time note, unchanged, search or not
	local n, M, main = gearBoot(0)
	main:SetSheet("GearSets"); pump(M)
	main.st.filters.text = "AUDIT NO MATCH"; n:RefreshViews(true); pump(M)
	local note = main.gsNote
	check(note:IsShown() and note.text.text == "No gear sets yet." and note.btn:IsShown() and note.btn.label.text == "Create Gear Set" and not note.count:IsShown() and note.btn.points[1][2] == note.text,
		"with no sets yet: \"No gear sets yet.\" and Create Gear Set, and no count")
end

------------------------------------------------------------------------
-- B4-4. The saved record: every number bounded, a damaged table read only so far, nothing shown past what formats
------------------------------------------------------------------------
do
	-- the auditor's record (given this version's stamp, so it is read at all)
	local M, n, DE = deBoot({ deShared = { version = 3, results = {}, materials = {}, stats = { v = 3, n = 1, alt = 100, ah = math.huge, vendor = -500,
		q = { [2] = 1e30, [3] = 0 / 0, [9] = 3 }, mats = { [10940] = 1e30, [10938] = 0 / 0, [11083] = math.huge, [-1] = 2, [10939.2] = 1, [10998] = 1.7 },
		best = { id = 7001, q = 2, worth = 1e30, ah = 1e30, name = "Test" } } } })
	local st = DE:Stats()
	check(st.ah == 0 and st.vendor == 0 and st.q[3] == nil and st.q[9] == nil and st.mats[10938] == nil and st.mats[11083] == nil and st.mats[-1] == nil and st.mats[10998] == 1,
		"(as before: values that aren't finite or are negative, qualities and IDs out of range are refused, and fractions made whole)")
	check(st.q[2] == nil and st.mats[10940] == nil and st.best == nil, "a quality count, a material count and a most valuable item of 1e30 are refused too (they were kept, in beta4)")
	DE:ShowResults(true); DE:SetResultsTab("all")
	check((n.errors or 0) == 0, "and the view draws")
end
do
	-- where the bounds are: a count below a billion, an amount of copper below 1e13
	local M, n, DE = deBoot({ deShared = { version = 3, results = {}, materials = {}, stats = { v = 3, n = 1e9 - 1, cn = 1e9, ahN = 5, ahU = 1e9 + 5, vendor = 1e13 - 1, ah = 1e13, alt = 2e13,
		q = { [2] = 1e9 - 1, [3] = 1e9, [4] = 12 }, mats = { [10940] = 1e9 - 1, [10938] = 1e9, [10939] = 7 },
		best = { id = 7001, q = 2, worth = 1e13 - 1, ah = 1e13, vendor = 1e13, name = "Sturdy Boots" } } } })
	local st = DE:Stats()
	check(st.n == 1e9 - 1 and st.cn == 0 and st.ahN == 5 and st.ahU == 0, "counts: just under a billion is kept, a billion and over reads as none")
	check(st.vendor == 1e13 - 1 and st.ah == 0 and st.alt == 0, "amounts: just under 1e13 copper is kept, 1e13 and over reads as none")
	check(st.q[2] == 1e9 - 1 and st.q[3] == nil and st.q[4] == 12 and st.mats[10940] == 1e9 - 1 and st.mats[10938] == nil and st.mats[10939] == 7, "the same bound inside the quality counts and the materials")
	check(st.best and st.best.worth == 1e13 - 1 and st.best.ah == nil and st.best.vendor == 0 and st.best.name == "Sturdy Boots", "and inside the most valuable item: each piece on its own")
	-- a most valuable item worth too much is no record of one
	M, n, DE = deBoot({ deShared = { version = 3, results = {}, materials = {}, stats = { v = 3, n = 1, best = { id = 7001, q = 2, worth = 1e13, name = "Sturdy Boots" } } } })
	check(DE:Stats().best == nil, "a most valuable item worth 1e13 or more is dropped whole")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- the name is shown in a line of text: one with a | code or a control character isn't kept
	for _, bad in ipairs({ "|cffff0000Red|r", "|TInterface\\Icons\\x:64|t", "|Hitem:1|h[x]|h", "two\nlines", "tab\there", "" }) do
		local M, n, DE = deBoot({ deShared = { version = 3, results = { ["2:3:a"] = { n = 1, mats = {} } }, materials = {}, stats = { v = 3, n = 1, best = { id = 7001, q = 2, worth = 500, vendor = 500, name = bad } } } })
		local b = DE:Stats().best
		check(b and b.id == 7001 and b.name == nil, ("a saved name like %q is dropped, the item kept"):format(bad))
		local row
		for _, l in ipairs((DE:ResultLines("all"))) do if l.id == 7001 then row = l end end
		check(row and plain(row.left) == "Sturdy Boots", "and the view shows the item's own name: " .. tostring(row and row.left))
	end
	local M, n, DE = deBoot({ deShared = { version = 3, results = {}, materials = {}, stats = { v = 3, n = 1, best = { id = 7001, q = 2, worth = 500, vendor = 500, name = "Boots of the Whale" } } } })
	check(DE:Stats().best.name == "Boots of the Whale", "a plain name is kept")
	check(DE.PlainName("Fine") == "Fine" and DE.PlainName("a|b") == nil and DE.PlainName(("x"):rep(121)) == nil and DE.PlainName(7) == nil and DE.PlainName("") == nil, "(DE.PlainName: plain, not over-long, or nothing)")
	-- written that way as well: an item whose name isn't plain is recorded without it
	disenchant(M, DE, 7002, { { matOf(DE, 7002), 1 } })
	DE:NoteDisenchanted({ quality = 2, vendor = 999999, itemID = 7001, name = "|cffff0000Tricky|r" }, {})
	check(DE:Stats().best.id == 7001 and DE:Stats().best.name == nil, "a name with a | code isn't written either")
	-- and shown that way, should one be in memory all the same
	DE:Stats().best.name = "|cffff0000Tricky|r"
	local row
	for _, l in ipairs((DE:ResultLines("all"))) do if l.id == 7001 then row = l end end
	check(row and plain(row.left) == "Sturdy Boots" and not row.left:find("Tricky", 1, true), "nor shown")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- a damaged materials table is read only so far. (Lua walks a table built 1, 2, 3... in that order, so the first
	-- 2,000 here are the ones read: all refused, and the good ones after them are never reached.)
	local many = {}
	for i = 1, 2000 do many[i] = 0 end
	for i = 2001, 3000 do many[i] = 5 end
	local M, n, DE = deBoot({ deShared = { version = 3, results = {}, materials = {}, stats = { v = 3, n = 1, mats = many } } })
	local count = 0
	for _ in pairs(DE:Stats().mats) do count = count + 1 end
	check(count == 0, "reading stops after 2,000 entries, kept or not (beta4 read the whole table): " .. count)
	-- within that, the first 200 good ones are kept, as before
	many = {}
	for i = 1, 1500 do many[i] = 5 end
	M, n, DE = deBoot({ deShared = { version = 3, results = {}, materials = {}, stats = { v = 3, n = 1, mats = many } } })
	count = 0
	for _ in pairs(DE:Stats().mats) do count = count + 1 end
	check(count == 200, "and no more than 200 kinds are kept: " .. count)
	check((n.errors or 0) == 0, "no errors")
end
do
	-- nothing shown runs past what the game can format, whatever is in memory or whatever a price addon answers
	local M, n, DE = deBoot()
	local MAX = DE.MONEY_MAX
	check(MAX == 1e13 and DE.COUNT_MAX == 1e9 and DE.STATS_VERSION == 3, "(the bounds: 1e13 copper, a billion, record version 3)")   -- (by design since 1.11.0-beta6, B5-2: version 3)
	check(n.DE_STATS.VERSION == DE.STATS_VERSION and n.DE_STATS.MONEY_MAX == MAX and n.DE_STATS.COUNT_MAX == DE.COUNT_MAX and n.DE_STATS.MATS_KEPT == 200 and n.DE_STATS.MATS_READ == 2000,
		"(the check on load and the Helper read them from one place)")
	local list, total, unpriced = DE.Valued({ [10940] = 1e30, [10938] = 2 })
	check(total < MAX and total >= 0 and unpriced == 0, "a count far too large is valued at the cap, not past it: " .. tostring(total))
	for _, m in ipairs(list) do check(m.value and m.value < MAX and m.value >= 0, "each material's value is under the cap") end
	-- a price addon answering nonsense is no price
	local real = n.AH.Price
	for _, p in ipairs({ 0 / 0, math.huge, -5, 1e30, "lots" }) do
		n.AH.Price = function() return p end
		local _, t, u = DE.Valued({ [10940] = 3 })
		check(t == 0 and u == 1, ("a price of %s from an auction addon counts as no price"):format(tostring(p)))
	end
	n.AH.Price = real
	-- an item priced absurdly when it is disenchanted is capped as it is noted
	local e = entryOf(DE, 7001)
	e.ah = 1e30
	disenchant(M, DE, 7001, { { matOf(DE, 7001), 2 } })
	local st = DE:Stats()
	check(st.ah < MAX and st.alt < MAX and st.best.worth < MAX and st.best.ah < MAX, "an absurd auction price on the item is capped where it is noted")
	-- the auditor's row: an oversized value in memory doesn't come out as negative gold
	st.best = { id = 7001, q = 2, worth = 1e30, ah = 1e30 }
	local row
	for _, l in ipairs((DE:ResultLines("all"))) do if l.id == 7001 then row = l end end
	check(row and not plain(row.right):find("%-%d") and plain(row.right) == "AH, after its cut, " .. DE.Money(MAX - 1), "an oversized value in memory is shown at the cap, never as a negative: " .. tostring(row and row.right))
	st.vendor, st.alt, st.ah = 1e30, 1e30, 1e30
	local ok = true
	for _, l in ipairs(lines(DE, "all")) do if l[2]:find("%-%d") then ok = false end end
	check(ok, "and no line of the view shows a negative amount")
	DE:ShowResults(true); DE:SetResultsTab("all")
	check((n.errors or 0) == 0, "no errors")
end
