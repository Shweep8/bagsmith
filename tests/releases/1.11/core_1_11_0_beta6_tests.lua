-- ======== 1.11.0-beta6 (Shweep, 26 Nov: "let's add in beta 6"; and the re-audit of beta5 the same evening) ========
-- Two things in one build.
--
-- 1. Held back, shown. His ask, with a piece ItemTree kept for a spec he doesn't play: "we need a way to see what is
--    being held back somehow to make our own decisions if we so wish to. When we can see them we should see the
--    reason still beside each... somehow using the same width we already have to work with so we can DE skip, etc
--    if we want to w/ vendor and AH data etc." Show, beside "N held back", lists the held-back pieces under the
--    offered ones in the same columns, the reason where Rec. Action is. A held-back row is looked at, never armed.
--    Offer Anyway sets its reason aside for that one piece (asked first for a protection of the player's own), and
--    the piece is then judged again like any other, with every other check and the fresh check at the click intact.
--
-- 2. The answer to the independent re-audit of 1.11.0-beta5 ("Keep beta5 in beta"), each case reproduced on beta5
--    first with the auditor's own probe:
--      B5-1 (P2) a section's editor, open while one of two same-named sheets is renamed, put the section back on the
--           old name alone when saved.
--      B5-2 (P3) Results named a winner from auction house prices before the cut, which the cut can reverse.
--      B5-3 (P3) Results named a winner while a disenchant was still collecting its loot.
--      B5-4 (P3) a saved record that lost materials when it was read still named a winner from what was left.

local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function deep(t) if type(t) ~= "table" then return t end local c = {}; for k, v in pairs(t) do c[k] = deep(v) end; return c end
local function click(b) b:GetScript("OnClick")(b) end
local function pump(M) for _ = 1, 20 do M.runTimers() end end
local DEID = 13262
local MATNAMES = { [10940] = "Strange Dust", [11083] = "Soul Dust", [10938] = "Lesser Magic Essence", [10939] = "Greater Magic Essence", [10998] = "Lesser Astral Essence", [11082] = "Greater Astral Essence", [10978] = "Small Glimmering Shard", [11084] = "Large Glimmering Shard", [11138] = "Small Glowing Shard" }
local PRICES = { [7001] = 1500, [7002] = 600, [10940] = 120, [10938] = 300, [10939] = 500, [10998] = 400, [11083] = 150, [11082] = 900, [10978] = 800, [11084] = 2000, [11138] = 1200 }

-- ItemTree's real answer for a piece it keeps (a quest piece, as in the 1.10.0-beta8 set), and the fake that gives it.
local function keepFacts(id)
	return { itemId = id, known = true, noDisenchant = true,
		keep = { lines = { "Keep (1)", "A Lost Master (II)", "Not an upgrade" }, always = false, marked = true, line = "Keep (1)",
			gear = { basis = "stats", specs = {}, upgrade = false, labels = {} }, valuable = false, noAuctionData = false, tags = { "keep" }, never = false, state = "keep", off = false, byUse = true, legendary = false },
		vendors = { everywhere = false, count = 0 }, route = { needed = false },
		uses = { reagentSkills = {}, current = 1, stale = 0, professions = {}, kinds = { reagent = 0, lock = 0, spell = 0, quest = 1, tool = 0, teaches = 0 } },
		quests = { stale = false, needs = { 993 }, titles = { [993] = "A Lost Master" }, predicted = {}, starts = {}, keepUpTo = 1, counts = { [993] = 1 }, staleAfter = {} } }
end
local function fakeItemTree(state)
	state.calls, state.asked = 0, {}
	return {
		version = 1,
		IsReady = function() return state.ready ~= false end,
		RequestData = function() end,
		RegisterReadyCallback = function(fn) state.onReady = fn end,
		RegisterChangeCallback = function(fn) state.onChange = fn end,
		GetItemFacts = function(id)
			state.calls = state.calls + 1
			state.asked[id] = (state.asked[id] or 0) + 1
			return deep(state.facts[id]) or { itemId = id, known = false }
		end,
	}
end
local function fakePawn(state)
	state.asked = {}
	_G.PawnShouldItemLinkHaveUpgradeArrow = function(link)
		local id = tonumber(tostring(link):match("item:(%d+)"))
		state.asked[id] = (state.asked[id] or 0) + 1
		if state.pending and state.pending[id] then return nil end
		return state.upgrades[id] or false
	end
	_G.PawnCommon = { ShowBagUpgradeAdvisor = true }
end
local BOOTS = { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 452, ilvl = 23, equip = "INVTYPE_FEET" }
local CLOAK = { id = 5387, name = "Enchanted Moonstalker Cloak", q = 2, count = 1, class = 4, subclass = 1, price = 150, ilvl = 20, equip = "INVTYPE_CLOAK" }
local DAGGER = { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" }
local EPIC = { id = 7010, name = "Blade of Ages", q = 4, count = 1, class = 2, subclass = 7, price = 50000, ilvl = 40, equip = "INVTYPE_WEAPON" }
local function put(M, slot, item) M.put(0, slot, deep(item)) end

-- An enchanter with `stock` in the bags. opts: it (ItemTree's state), pawn (Pawn's), prof (profile keys), rank
-- (Enchanting skill), sets (a function that adds gear sets), trade (a table driving the tradeable tooltip read),
-- deShared, prices, vendor (the boots' vendor price).
local function hBoot(stock, opts)
	opts = opts or {}
	package.loaded.mock = nil
	local M = require("mock")
	stock(M)
	_G.ItemTreeAPI = opts.it and fakeItemTree(opts.it) or nil
	if opts.pawn then fakePawn(opts.pawn) else _G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil end
	M.removeEquipmentSets()
	if opts.sets then M.installEquipmentSets(); opts.sets(M) end
	_G.BIND_TRADE_TIME_REMAINING = nil
	if opts.trade then
		-- the game's tooltip, which the Helper reads for "still tradeable"; the mock's frames have no SetBagItem
		_G.BIND_TRADE_TIME_REMAINING = "You may trade this item with players that were also eligible to loot this item for the next %s."
		local T = opts.trade
		local realCreate = CreateFrame
		_G.CreateFrame = function(kind, name, ...)
			if name ~= "BagSmithDEScanTooltip" then return realCreate(kind, name, ...) end
			local tip = { SetOwner = function() end, ClearLines = function() end, at = nil }
			function tip:SetBagItem(bag, slot) if T.unreadable then error("no tooltip") end self.at = bag .. ":" .. slot end
			function tip:NumLines() return (T.slots and T.slots[self.at]) and 1 or 0 end
			_G[name .. "TextLeft1"] = { GetText = function() return "You may trade this item with players that were also eligible to loot this item for the next 1 hour." end }
			_G[name] = tip
			return tip
		end
	end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local prof = { skin = "modern", deEnabled = true }
	for k, v in pairs(opts.prof or {}) do prof[k] = v end
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = prof }, whatsNewSeen = "1.10.0", deShared = opts.deShared }
	_G.BagSmithWhatsNew = nil
	_G.GuildBankFrame, _G.MailFrame = nil, nil
	_G.IsSpellKnown = function(id) return id == DEID end
	_G.GetNumSkillLines = function() return 2 end
	_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, opts.rank or 300 end
	_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
	_G.RegisterStateDriver = function() end
	_G.UnregisterStateDriver = function() end
	_G.GetMoneyString = function(c) return ("%dg %ds %dc"):format(math.floor(c / 10000), math.floor(c / 100) % 100, c % 100) end
	_G.LOOT_ITEM_SELF = "You receive loot: %s."; _G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
	_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."; _G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
	C_Container.GetContainerItemPurchaseInfo = nil
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(link) local id = tonumber(tostring(link):match("item:(%d+)")) or link; if MATNAMES[id] then return MATNAMES[id], nil, id == 10978 and 3 or 1 end return realInfo(link) end
	local prices = opts.prices or PRICES
	if opts.noAH then _G.Auctionator = nil else
		_G.Auctionator = { API = { v1 = {
			GetAuctionPriceByItemLink = function(_, link) local id = tonumber(link:match("item:(%d+)")); return id and prices[id] end,
			GetAuctionPriceByItemID = function(_, id) return prices[id] end,
			GetAuctionAgeByItemLink = function() return nil end,
		} } }
	end
	local n = M.loadAddon("BagSmith"); n.version = "1.11.0-beta6"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	for _ = 1, 10 do M.runTimers() end
	local DE = n.Disenchant
	-- (by design since 1.11.0-beta8: Offer Anyway became Disenchant Anyway, lying over the Disenchant button, which then
	-- stays dead for half a second. These scenarios are about what is set aside and checked, not that pause, so it is
	-- switched off here; the beta8 set has the pause. The button's words and the question's are the new ones below.)
	DE.ARM_HOLD = 0
	DE:Show(); M.runTimers()
	return n, M, DE, DE.frame, DE:Button()
end
local function recOf(n, id, slot) for _, r in ipairs(n.items) do if r.itemID == id and (not slot or r.slot == slot) then return r end end end
local function offered(DE) local t = {}; for _, e in ipairs(DE.entries or {}) do t[#t + 1] = e.name end; table.sort(t); return table.concat(t, ", ") end
local function heldList(DE) local t = {}; for _, e in ipairs(DE.heldEntries or {}) do t[#t + 1] = e.name .. " [" .. e.held .. "]" end; return table.concat(t, ", ") end
local function entryOf(DE, id, slot) for _, e in ipairs(DE.entries or {}) do if e.itemID == id and (not slot or e.slot == slot) then return e end end end
local function heldOf(DE, id, slot) for _, e in ipairs(DE.heldEntries or {}) do if e.itemID == id and (not slot or e.slot == slot) then return e end end end
local function rowsOf(f) local t = {}; for _, r in ipairs(f.rows) do if r:IsShown() then t[#t + 1] = r end end return t end
local function rowFor(f, id, slot) for _, r in ipairs(rowsOf(f)) do if r.entry and r.entry.itemID == id and (not slot or r.entry.slot == slot) then return r end end end
local function armed(b) return b:GetAttribute("type") == "spell" end
-- (By design since 1.11.0-beta7, Shweep's look at beta6 in game: "not sure dimming the held back is a good call ... the
-- button in header is hard to find, end of the reg list would possibly be better". The switch is the Held Back band at
-- the end of the offered rows, there whenever anything is held back; the header's Show button is gone; held-back rows
-- are at full strength with a lock in place of the ring. The checks below that named the old button or the dimming
-- name the band and the lock instead, each marked.)
local function bandOf(f) for _, r in ipairs(rowsOf(f)) do if r.heading then return r end end end
local function lootLine(M, id, count)
	M.fire("CHAT_MSG_LOOT", ("You receive loot: |cffffffff|Hitem:%d:0:0:0:0:0:0:0|h[mat]|h|r%s."):format(id, count > 1 and ("x" .. count) or ""))
end
-- The armed piece disenchanted as the game runs it.
local function castArmed(M, DE, b, loot)
	local e = DE.current
	b:GetScript("PreClick")(b)
	if DE.castingEntry ~= e then return false end
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", DEID)
	for _, l in ipairs(loot or {}) do lootLine(M, l[1], l[2]) end
	M.bags[e.bag][e.slot] = nil; M.fire("BAG_UPDATE_DELAYED"); M.fire("LOOT_CLOSED"); pump(M)
	return true
end
local function lines(DE, which)
	local out = {}
	for _, l in ipairs((DE:ResultLines(which or "session"))) do out[#out + 1] = { plain(l.left), plain(l.right), l.kind, l.id } end
	return out
end
local function line(DE, left, which) for _, l in ipairs(lines(DE, which)) do if l[1] == left then return l end end end
local function painted(DE, left) for _, r in ipairs(DE.frame.results.rows) do if r:IsShown() and plain(r.left.text) == left then return plain(r.right.text) end end end

------------------------------------------------------------------------
-- 1. Held back, shown
------------------------------------------------------------------------
do
	-- ItemTree keeps the cloak; the epic waits behind Include Epics. Until Show is clicked, nothing has changed.
	local it = { facts = { [5387] = keepFacts(5387) } }
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS); put(M, 2, CLOAK); put(M, 3, DAGGER); put(M, 4, EPIC) end, { it = it })
	check(offered(DE) == "Sturdy Boots, Worn Dagger" and DE.held.total == 2, "(set up: boots and a dagger offered; a cloak ItemTree keeps and an epic held back)")
	-- (by design since 1.11.0-beta7: the band is a row of the list, so three rows, not two)
	check(not DE.showHeld and #DE.heldEntries == 0 and #rowsOf(f) == 3 and DE.viewing == nil, "the list is the offered pieces, as before, and the Held Back band after them")
	check(f.heldLine:IsShown() and f.heldLine.text == "2 held back" and f.heldInfo:IsShown() and f.heldShow == nil, "\"2 held back\" and its (i) in the header, with no button there")
	check(bandOf(f) == rowsOf(f)[3] and plain(bandOf(f).cells[2].text) == "Held Back (2)" and bandOf(f).cells[6].text == "Show", "the band comes after the offered rows and reads Held Back (2), Show")
	check(armed(b) and DE.current and DE.current.itemID == rowsOf(f)[1].entry.itemID, "(the first offered piece is armed)")
	local first = DE.current
	click(bandOf(f))
	local rows = rowsOf(f)
	check(DE.showHeld == true and #rows == 5 and rows[3].cells[6].text == "Hide", "Show: the held-back pieces join the list, and the band reads Hide")
	check(rows[3].heading and rows[3].entry == nil and plain(rows[3].cells[2].text) == "Held Back (2)" and not rows[3].dot:IsShown(), "under a heading, Held Back (2)")
	check(heldList(DE) == "Enchanted Moonstalker Cloak [itemtree], Blade of Ages [epic]", "an addon's advice first, then the player's own protections: " .. heldList(DE))
	local cloakRow, epicRow = rows[4], rows[5]
	check(cloakRow.entry.itemID == 5387 and plain(cloakRow.cells[2].text) == "Enchanted Moonstalker Cloak" and cloakRow.cells[6].text == "ItemTree: keep", "the cloak's row: its reason where Rec. Action is")
	check(cloakRow.cells[3].text == DE.Money(150) and cloakRow.cells[4].text == "no price yet" and cloakRow.cells[5].text ~= "", "with its vendor, AH and materials values in the same columns: " .. tostring(cloakRow.cells[5].text))
	check(epicRow.entry.itemID == 7010 and epicRow.cells[6].text == "Epic" and epicRow.cells[3].text == DE.Money(50000), "the epic's row")
	-- (by design since 1.11.0-beta7: not dimmed; a lock where the ring is)
	check(cloakRow:GetAlpha() == 1 and epicRow:GetAlpha() == 1 and cloakRow.lock:IsShown() and not cloakRow.dot:IsShown() and rows[1].dot:IsShown() and not rows[1].lock:IsShown(), "held-back rows are at full strength, with a lock where the others have their ring")
	check(DE.current and DE.current.itemID == first.itemID and armed(b) and b:GetAttribute("target-slot") == first.slot and DE.viewing == nil, "showing them changes nothing about what is armed")
	check(f.sub.text:find("2 items to consider", 1, true), "(the count line still counts the offered ones)")

	-- a held-back row is looked at, never armed
	click(cloakRow)
	check(DE.viewing and DE.viewing.itemID == 5387 and DE.current == nil, "a click on a held-back row looks at it")
	check(not armed(b) and b:GetAttribute("target-slot") == nil and b:GetAttribute("target-item") == nil and not b:IsEnabled(), "and the Disenchant button is disarmed and greyed")
	check(f.cur:IsShown() and plain(f.cur.name.text) == "Enchanted Moonstalker Cloak" and f.cur.values.text:find("Vendor " .. DE.Money(150), 1, true), "the panel shows the piece and its values")
	check(f.cur.verdict.text == "Held back: ItemTree says to keep", "and why it is held back, in place of the recommendation: " .. tostring(f.cur.verdict.text))
	check(f.offer:IsShown() and f.offer:IsEnabled() and f.offer.label.text == "Disenchant Anyway" and not f.never:IsShown() and not f.unoffer:IsShown() and not f.junk:IsShown(), "its buttons: Offer Anyway, no Exclude or Junk")
	check(f.offer.points[1][2] == b and f.skip.points[1][2] == f.offer and f.skip:IsShown(), "Offer Anyway beside the greyed Disenchant button, Skip after it")
	check(cloakRow.hl:IsShown() and cloakRow.lock:IsShown() and not cloakRow.dotFill:IsShown() and not rows[1].dotFill:IsShown() and not rows[1].hl:IsShown(), "its row is the highlighted one (by design since 1.11.0-beta7: it keeps its lock, no dot)")
	local held = DE.viewing
	DE:Arm(held)
	check(DE.current == nil and not armed(b), "DE:Arm refuses a held-back row")
	local ok, why = DE:LiveCheck(held)
	check(ok == false and why == "that item is held back", "so does the check at the click: " .. tostring(why))
	b:GetScript("PreClick")(b)
	check(DE.castingEntry == nil and not armed(b), "and a click on the button with a held-back row in the panel casts nothing")
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", DEID)
	check((DE.done or 0) == 0, "(no disenchant is counted)")
	DE:Refresh()
	check(DE.viewing and DE.viewing.itemID == 5387 and DE.current == nil and not armed(b), "a refresh keeps looking at it, still unarmed")

	-- Offer Anyway: advice from an addon is one click
	local asked = it.asked[5387]
	local confirms = 0
	local realConfirm = n.Confirm
	n.Confirm = function() confirms = confirms + 1 end
	click(f.offer)
	n.Confirm = realConfirm
	check(confirms == 0, "ItemTree's advice is set aside with one click, no question")
	check(offered(DE) == "Enchanted Moonstalker Cloak, Sturdy Boots, Worn Dagger" and DE.held.total == 1, "the cloak is in the list now, and one piece is still held back")
	check(DE.current and DE.current.itemID == 5387 and DE.viewing == nil and armed(b) and b:GetAttribute("target-slot") == 2, "and it is the armed piece")
	check(DE.current.offered == "ItemTree: keep" and f.cur.verdict.text:find("(offered by you: ItemTree: keep)", 1, true), "the panel says the player offered it, and what was set aside: " .. tostring(f.cur.verdict.text))
	check(f.unoffer:IsShown() and f.unoffer.label.text == "Hold Back" and not f.never:IsShown() and not f.offer:IsShown() and f.skip.points[1][2] == b, "its buttons: Disenchant, Skip, and Hold Back where Exclude sits")
	check(rowFor(f, 5387):GetAlpha() == 1 and rowFor(f, 5387).cells[6].text ~= "ItemTree: keep" and plain(rowsOf(f)[4].cells[2].text) == "Held Back (1)", "its row is an ordinary one, above Held Back (1)")
	local rec = DE.current.rec
	check(DE.offered[rec.guid] and DE.offered[rec.guid].itemID == 5387 and DE.offered[rec.guid].why.itemtree == true and next(DE.offered[rec.guid].why, "itemtree") == nil, "the offer is kept by the piece's own instance, for that one reason")
	-- at the click: ItemTree is not asked about this piece, and every other check is made
	local before = it.asked[5387]
	check(DE:LiveCheck(DE.current) == true and it.asked[5387] == before, "at the click ItemTree isn't asked about it again")
	DE:Never()[5387] = true
	ok, why = DE:LiveCheck(DE.current)
	check(ok == false and why == "that item is on your DE Exclusion List", "put on the Exclusion List after it was offered: the click is refused, ItemTree's word being all that was set aside")
	DE:Never()[5387] = nil
	n.Marks:ToggleFavorite(rec); pump(M)
	ok, why = DE:LiveCheck(entryOf(DE, 5387) or { bag = 0, slot = 2, itemID = 5387, rec = rec })
	check(ok == false and why == "that item is a favorite now", "a reason that was not set aside still refuses the click: " .. tostring(why))
	DE:Refresh()
	check(offered(DE) == "Sturdy Boots, Worn Dagger" and heldOf(DE, 5387).held == "favorite", "and the list, drawn again, holds it back as a favorite now")
	n.Marks:ToggleFavorite(rec); pump(M); DE:Refresh()
	check(entryOf(DE, 5387) ~= nil, "(the favorite mark off: offered again, the offer still standing)")
	-- and it disenchants like any other piece
	DE:Select(entryOf(DE, 5387))
	local mat = DE:Expectation(rec)[1][1]
	check(castArmed(M, DE, b, { { mat, 2 } }) and DE.done == 1, "Disenchant on the offered piece casts, and the disenchant is counted")
	check(next(DE.offered) == nil, "its offer goes with it")
	check(entryOf(DE, 5387) == nil and heldOf(DE, 5387) == nil and DE.held.total == 1, "(the cloak is gone from the list)")
	-- a piece nobody offered is still asked about at the click, and refused on ItemTree's word
	local bootsEntry = entryOf(DE, 7001)
	local askedBoots = it.asked[7001] or 0
	it.facts[7001] = keepFacts(7001)   -- (say ItemTree now keeps the boots)
	local okB, whyB = DE:LiveCheck(bootsEntry)
	check(okB == false and whyB == "ItemTree says to keep that item" and it.asked[7001] == askedBoots + 1, "any other piece is still asked about, and refused on ItemTree's word: " .. tostring(whyB))
	it.facts[7001] = nil
	check((n.errors or 0) == 0, "no errors")
end
do
	-- Hold Back takes an offer back; a new look at the Helper starts with none
	local it = { facts = { [5387] = keepFacts(5387) } }
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS); put(M, 2, CLOAK) end, { it = it })
	click(bandOf(f)); click(rowFor(f, 5387)); click(f.offer)
	check(DE.current.itemID == 5387 and armed(b), "(set up: the cloak offered and armed)")
	click(f.unoffer)
	check(next(DE.offered) == nil and offered(DE) == "Sturdy Boots" and heldOf(DE, 5387) and heldOf(DE, 5387).held == "itemtree", "Hold Back: the offer is taken back and the cloak is held back again")
	check(DE.viewing and DE.viewing.itemID == 5387 and DE.current == nil and not armed(b), "the panel still looks at it, with nothing armed")
	check(DE:TakeBack(entryOf(DE, 7001)) == false, "(a piece nobody offered has nothing to take back)")
	-- offered, then the Helper closed and opened
	click(f.offer)
	check(entryOf(DE, 5387) ~= nil, "(offered again)")
	DE:Close(); DE:Show(); pump(M)
	check(DE.offered == nil and entryOf(DE, 5387) == nil and DE.held.total == 1, "an offer lasts while the Helper stays open: opened again, the cloak is held back")
	check(DE.showHeld == true and heldOf(DE, 5387) ~= nil and DE.current and DE.current.itemID == 7001 and armed(b), "(the rows are still shown, and the boots are armed as on any opening)")
	-- the piece leaves the bags with its offer standing
	click(rowFor(f, 5387)); click(f.offer)
	local guid = DE.current.rec.guid
	check(DE.offered[guid] ~= nil, "(offered once more)")
	M.bags[0][2] = nil; M.fire("BAG_UPDATE_DELAYED"); pump(M)
	check(DE.offered[guid] == nil, "sold or moved out of the bags: the offer is forgotten")
	put(M, 2, CLOAK); M.fire("BAG_UPDATE_DELAYED"); pump(M)
	check(entryOf(DE, 5387) == nil and heldOf(DE, 5387) ~= nil, "another copy in the same slot is held back like any other: nothing inherits an offer")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- a protection of the player's own is asked about first
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS); put(M, 3, DAGGER) end)
	n.Marks:ToggleFavorite(recOf(n, 7002)); pump(M); DE:Refresh()   -- (drawn again, so the band is there to click)
	click(bandOf(f))
	check(heldList(DE) == "Worn Dagger [favorite]" and rowFor(f, 7002).cells[6].text == "Favorite", "(set up: the dagger is a favorite, held back and shown)")
	click(rowFor(f, 7002))
	check(f.cur.verdict.text == "Held back: a favorite" and f.offer:IsEnabled(), "its panel says so, and it can be offered")
	local askedText, yes, no
	local realConfirm = n.Confirm
	n.Confirm = function(anchor, text, onYes, onNo) askedText, yes, no = text, onYes, onNo end
	click(f.offer)
	check(askedText == "Worn Dagger is a favorite.\nDisenchant this one anyway? Nothing is disenchanted until you click Disenchant.", "Offer Anyway asks first: " .. tostring(askedText))
	check(DE.offered == nil and entryOf(DE, 7002) == nil and not armed(b), "and nothing is offered until the answer is yes")
	yes()
	check(entryOf(DE, 7002) ~= nil and DE.current.itemID == 7002 and DE.current.offered == "Favorite" and armed(b), "yes: the dagger is offered and armed")
	check(DE:LiveCheck(DE.current) == true and n.Marks:IsFavorite(7002), "the click's check passes for it, and it is still a favorite everywhere else")
	-- asked, and the reason gone before the answer: a yes records nothing for a row that is no longer there
	click(f.unoffer); click(f.offer)
	n.Marks:ToggleFavorite(recOf(n, 7002)); pump(M); DE:Refresh()
	check(entryOf(DE, 7002) ~= nil and not n.Marks:IsFavorite(7002), "(asked again; the favorite mark taken off meanwhile, so the dagger is offered in the ordinary way)")
	yes()
	check(DE.offered == nil or next(DE.offered) == nil, "a yes for a question whose reason is gone sets nothing aside")
	n.Marks:ToggleFavorite(recOf(n, 7002)); pump(M); DE:Refresh()
	check(heldOf(DE, 7002) and heldOf(DE, 7002).held == "favorite", "(a favorite again: held back again, as nothing was set aside)")
	-- asked, and the piece gone before the answer
	click(rowFor(f, 7002)); click(f.offer)
	M.bags[0][3] = nil; M.fire("BAG_UPDATE_DELAYED"); pump(M)
	yes()
	check(DE.offered == nil or next(DE.offered) == nil, "a yes that comes after the piece has gone offers nothing")
	n.Confirm = realConfirm
	check((n.errors or 0) == 0, "no errors")
end
do
	-- each reason, how it may be set aside, and that it lifts only itself
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS); put(M, 3, DAGGER); put(M, 4, EPIC) end,
		{ sets = function(M) M.addSet("Tank", { [16] = 0x00300000 + 1 }) end })   -- the boots, bag 0 slot 1, are in a gear set
	local I = DE.HELD_INFO
	check(I.itemtree.offer == "free" and I.pawn.offer == "free" and I.junk.offer == "free", "an addon's advice and a junk mark: one click")
	check(I.favorite.offer == "ask" and I["gear set"].offer == "ask" and I.never.offer == "ask" and I.refundable.offer == "ask" and I.tradeable.offer == "ask" and I.epic.offer == "ask", "a favorite, a gear set, the Exclusion List, refundable, tradeable, an epic: asked first")
	check(I.skill.offer == nil and I.itemtreewait.offer == nil and I.skill.cant and I.itemtreewait.cant, "not enough skill, and a piece still waiting on ItemTree: can't be offered")
	for why in pairs(DE.HELD) do check(I[why] ~= nil and I[why].short and I[why].text, "every reason the Helper holds a piece back for has its words: " .. why) end
	click(bandOf(f))
	check(recOf(n, 7001).gearSets ~= nil and heldOf(DE, 7001) and heldOf(DE, 7001).held == "gear set" and heldOf(DE, 7010).held == "epic", "(set up: the boots in a gear set, the epic)")
	-- a gear set
	local boots = heldOf(DE, 7001)
	check(DE:CanOffer(boots) == "ask" and rowFor(f, 7001).cells[6].text == "Gear set", "a piece in a gear set can be offered, asked first")
	check(DE:OfferAnyway(boots, true) and entryOf(DE, 7001) and entryOf(DE, 7001).offered == "Gear set", "offered")
	check(DE:LiveCheck(entryOf(DE, 7001)) == true, "the click's check passes while it is still in the set")
	local okD, whyD = DE:LiveCheck({ bag = 0, slot = 3, itemID = 7002, rec = recOf(n, 7002) })
	check(okD == true, "(the dagger, in no set, passes as ever)")
	-- an epic
	local epic = heldOf(DE, 7010)
	check(DE:CanOffer(epic) == "ask" and DE:OfferAnyway(epic, true) and entryOf(DE, 7010) and entryOf(DE, 7010).offered == "Epic" and n.db.deIncludeEpics == false, "an epic is offered for itself; Include Epics stays off")
	-- the Exclusion List
	DE:Never()[7002] = true; DE:Refresh()
	local dagger = heldOf(DE, 7002)
	check(dagger and dagger.held == "never" and rowFor(f, 7002).cells[6].text == "Excluded" and DE:CanOffer(dagger) == "ask", "a piece on the DE Exclusion List: held back as Excluded")
	local ok, why = DE:LiveCheck({ bag = 0, slot = 3, itemID = 7002, rec = dagger.rec })
	check(ok == false and why == "that item is on your DE Exclusion List", "(the click's check refuses it)")
	check(DE:OfferAnyway(dagger, true) and DE:LiveCheck(entryOf(DE, 7002)) == true and DE:Never()[7002] == true, "offered: the check passes for this piece, and the list still has the item")
	-- two reasons on one piece: each is set aside by itself
	n.Marks:ToggleFavorite(recOf(n, 7002)); pump(M)
	dagger = heldOf(DE, 7002)
	check(dagger and dagger.held == "favorite" and entryOf(DE, 7002) == nil, "the same dagger made a favorite too: the offer for the Exclusion List doesn't cover that")
	ok, why = DE:LiveCheck({ bag = 0, slot = 3, itemID = 7002, rec = dagger.rec })
	check(ok == false and why == "that item is a favorite now", "at the click either: " .. tostring(why))
	DE:Select(dagger)
	check(DE:OfferAnyway(dagger, true) and entryOf(DE, 7002) and entryOf(DE, 7002).offered == "Favorite, Excluded", "offered for that as well: both are named")
	check(DE:LiveCheck(entryOf(DE, 7002)) == true, "and now the click's check passes")
	check(DE:TakeBack(entryOf(DE, 7002)) and heldOf(DE, 7002).held == "never" and DE.offered[dagger.rec.guid] == nil, "Hold Back takes back the whole offer")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- refundable and tradeable: each read is skipped only for the reason that was set aside
	local trade = { slots = {} }
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS); put(M, 3, DAGGER) end, { trade = trade })
	C_Container.GetContainerItemPurchaseInfo = function(bag, slot) if bag == 0 and slot == 3 then return 500, 1, 3600 end return 0, 0, 0 end
	DE:Refresh()   -- (drawn again, so the band is there to click)
	click(bandOf(f))
	local dagger = heldOf(DE, 7002)
	check(dagger and dagger.held == "refundable" and rowFor(f, 7002).cells[6].text == "Refundable" and DE:CanOffer(dagger) == "ask", "(set up: the dagger can still be refunded)")
	check(DE:OfferAnyway(dagger, true) and entryOf(DE, 7002).offered == "Refundable" and DE:LiveCheck(entryOf(DE, 7002)) == true, "offered: the click's check doesn't read whether it is refundable")
	trade.unreadable = true
	local ok, why = DE:LiveCheck(entryOf(DE, 7002))
	check(ok == false and why == "whether that item is tradeable could not be checked", "but it still reads whether it is tradeable, and a read that fails still refuses: " .. tostring(why))
	trade.unreadable = nil
	trade.slots["0:3"] = true; DE:Refresh()
	dagger = heldOf(DE, 7002)
	check(dagger and dagger.held == "tradeable" and rowFor(f, 7002).cells[6].text == "Tradeable", "still tradeable as well: held back for that, the first offer notwithstanding")
	check(DE:OfferAnyway(dagger, true) and entryOf(DE, 7002).offered == "Refundable, Tradeable" and DE:LiveCheck(entryOf(DE, 7002)) == true, "offered for both: the check passes")
	-- a piece offered for tradeable alone is still stopped by a refund window
	trade.slots["0:1"] = true; DE:Refresh()
	local boots = heldOf(DE, 7001)
	check(boots and boots.held == "tradeable" and DE:OfferAnyway(boots, true) and DE:LiveCheck(entryOf(DE, 7001)) == true, "(the boots, tradeable, offered)")
	C_Container.GetContainerItemPurchaseInfo = function(bag, slot) return 500, 1, 3600 end
	ok, why = DE:LiveCheck(entryOf(DE, 7001))
	check(ok == false and why == "that item is refundable now", "refundable now: the click is refused, tradeable having been the only thing set aside")
	C_Container.GetContainerItemPurchaseInfo = nil
	check((n.errors or 0) == 0, "no errors")
end
do
	-- Pawn's word, set aside for one piece
	local pawn = { upgrades = { [7002] = true } }
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS); put(M, 3, DAGGER) end, { pawn = pawn, prof = { deHoldPawn = true } })
	click(bandOf(f))
	local dagger = heldOf(DE, 7002)
	check(dagger and dagger.held == "pawn" and rowFor(f, 7002).cells[6].text == "Pawn upgrade" and DE:CanOffer(dagger) == "free", "(set up: Pawn says the dagger is an upgrade)")
	click(rowFor(f, 7002))
	check(f.cur.verdict.text == "Held back: Pawn says it's an upgrade", "the panel says so")
	click(f.offer)
	check(DE.current and DE.current.itemID == 7002 and DE.current.offered == "Pawn upgrade" and armed(b), "one click offers it")
	local before = pawn.asked[7002]
	pawn.pending = { [7002] = true }
	check(DE:LiveCheck(DE.current) == true and pawn.asked[7002] == before, "at the click Pawn isn't asked about it, answer or no answer")
	pawn.pending = { [7001] = true }
	local ok, why = DE:LiveCheck(entryOf(DE, 7001))
	check(ok == false and why == "Pawn hasn't decided yet whether that item is an upgrade", "any other piece still waits on Pawn")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- what can't be offered
	local it = { facts = {}, ready = false }
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS); put(M, 3, { id = 7020, name = "Deep Plate", q = 2, count = 1, class = 4, subclass = 4, price = 900, ilvl = 60, equip = "INVTYPE_CHEST" }) end, { it = it, rank = 30 })
	click(f.empty.heldShow)   -- (nothing is offered here, so it is the empty card's button)
	check(heldList(DE) == "Deep Plate [skill], Sturdy Boots [itemtreewait]", "(set up: one piece above the character's skill, one waiting on ItemTree): " .. heldList(DE))
	local plate, boots = heldOf(DE, 7020), heldOf(DE, 7001)
	local can, cant = DE:CanOffer(plate)
	check(can == false and cant == "Your Enchanting skill is too low to disenchant it." and rowFor(f, 7020).cells[6].text == "Needs skill", "not enough skill: it can't be offered, and says why")
	click(rowFor(f, 7020))
	check(f.offer:IsShown() and not f.offer:IsEnabled() and f.offer.offReason == cant and f.offer.offName == "Disenchant Anyway" and f.offer.offHead == false, "Offer Anyway is greyed, its tooltip giving the reason")
	check(DE:OfferAnyway(plate) == false and DE:OfferAnyway(plate, true) == false and DE.offered == nil, "and DE:OfferAnyway does nothing for it")
	can, cant = DE:CanOffer(boots)
	check(can == false and cant == "ItemTree hasn't answered about it yet. This clears by itself in a moment." and rowFor(f, 7001).cells[6].text == "ItemTree: wait", "waiting on ItemTree: not yet")
	check(DE:OfferAnyway(boots, true) == false and DE.offered == nil, "nor is it offered")
	-- a control greyed here gets its own tooltip, not Global Inventory's
	GameTooltip:SetOwner(UIParent, "ANCHOR_TOP")
	n.View.OffTip(f.offer)
	local tip = table.concat(GameTooltip.lines or {}, " | ")
	check(tip:find("Your Enchanting skill is too low", 1, true) and not tip:find("Global Inventory", 1, true), "its tooltip doesn't say \"Not available in Global Inventory\": " .. tip)
	-- a legendary, counted under epics while Include Epics is off, is never offered
	can, cant = DE:CanOffer({ held = "epic", quality = 5, rec = { guid = "x" } })
	check(can == false and cant == "A legendary item is never offered.", "a legendary is never offered")
	-- nor any piece on a client that can't tell one copy from another
	can, cant = DE:CanOffer({ held = "itemtree", quality = 2, rec = {} })
	check(can == false and cant:find("can't tell one copy of an item from another", 1, true), "with no instance to keep an offer by, no piece is offered")
	check(next(DE:OfferedWhy({ itemID = 7001 })) == nil and next(DE:OfferedWhy(nil)) == nil, "(and a record without an instance never has an offer)")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- an offer is one piece's: another copy of the same item is not offered with it
	local it = { facts = { [5387] = keepFacts(5387) } }
	local n, M, DE, f, b = hBoot(function(M) put(M, 2, CLOAK); put(M, 5, CLOAK) end, { it = it })
	check(f.empty:IsShown() and f.empty.held:IsShown() and f.empty.held.text == "2 held back" and f.empty.heldInfo:IsShown(), "(set up: two copies of a cloak ItemTree keeps, nothing to offer: the empty card, \"2 held back\")")
	check(f.empty.heldShow:IsShown() and f.empty.heldShow.label.text == "Show Held Back" and f.empty.heldShow.points[1][2] == f.empty.held, "the card has a button of its own, centred under the count (by design since 1.11.0-beta7: Show Held Back)")
	click(f.empty.heldShow)
	local rows = rowsOf(f)
	check(not f.empty:IsShown() and f.scroll:IsShown() and #rows == 3 and rows[1].heading and plain(rows[1].cells[2].text) == "Held Back (2)", "Show: the list takes the card's place, with the two held-back rows")
	check(DE.viewing and DE.viewing.slot == 2 and DE.current == nil and not armed(b) and f.cur:IsShown(), "the panel looks at the first of them; nothing is armed")
	check(bandOf(f) and bandOf(f).cells[6].text == "Hide", "(the band reads Hide now)")
	click(f.offer)
	check(#DE.entries == 1 and DE.entries[1].slot == 2 and DE.current.slot == 2 and armed(b) and b:GetAttribute("target-slot") == 2, "Offer Anyway on one copy: that copy is offered and armed")
	check(#DE.heldEntries == 1 and DE.heldEntries[1].slot == 5 and DE.held.total == 1, "the other copy is still held back")
	local ok, why = DE:LiveCheck({ bag = 0, slot = 5, itemID = 5387, rec = DE.heldEntries[1].rec })
	check(ok == false and why == "ItemTree says to keep that item", "and the click's check still refuses it: " .. tostring(why))
	-- disenchant the offered one: the panel moves to a held-back row, armed with nothing
	local mat = DE:Expectation(DE.current.rec)[1][1]
	check(castArmed(M, DE, b, { { mat, 1 } }), "(the offered copy is disenchanted)")
	check(#DE.entries == 0 and DE.current == nil and not armed(b) and DE.viewing and DE.viewing.slot == 5, "with nothing left to offer, the panel looks at the held-back copy and nothing is armed")
	b:GetScript("PreClick")(b)
	check(DE.castingEntry == nil, "a click on the button now casts nothing")
	-- Skip passes on a held-back row; Hide brings the card back
	click(f.skip)
	check(#DE.heldEntries == 0 and DE.held.total == 0 and DE.viewing == nil and f.empty:IsShown(), "Skip on a held-back row sets it aside like any other, and the card is back")
	DE:ClearSkipped()
	check(#DE.heldEntries == 1 and not f.empty:IsShown(), "(considered again: shown again)")
	click(bandOf(f))
	check(DE.showHeld == false and f.empty:IsShown() and #DE.heldEntries == 0 and DE.viewing == nil and f.empty.held.text == "1 held back", "Hide: the card again, \"1 held back\"")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- in combat nothing here changes anything
	local it = { facts = { [5387] = keepFacts(5387) } }
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS); put(M, 2, CLOAK); put(M, 4, EPIC) end, { it = it })
	click(bandOf(f))
	local held = heldOf(DE, 5387)
	M.combat = true
	check(DE:ShowHeld(false) == false and DE.showHeld == true, "in combat: Show and Hide do nothing")
	DE:Select(held)
	check(DE.viewing == nil, "a row click does nothing")
	check(DE:OfferAnyway(held) == false and DE.offered == nil, "Offer Anyway does nothing")
	M.combat = false
	DE:Select(held); click(f.offer)
	M.combat = true
	check(DE:TakeBack(entryOf(DE, 5387)) == false and next(DE.offered) ~= nil, "nor does Hold Back")
	M.combat = false
	-- the Results view puts the Show button away with the rest
	DE:ShowResults(true)
	check(f.results:IsShown() and not f.heldLine:IsShown() and not armed(b), "Results: the held line is put away, nothing armed")
	DE:ShowResults(false)
	check(f.heldLine:IsShown() and bandOf(f) ~= nil and entryOf(DE, 5387) ~= nil, "back to the list: as it was, the offer still standing")
	check((n.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- 2. The re-audit of beta5
------------------------------------------------------------------------
local function sBoot()
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 13 })
	_G.ItemTreeAPI = nil; _G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil
	M.removeEquipmentSets()
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {} }, whatsNewSeen = "1.10.0" }
	_G.BagSmithWhatsNew = nil
	_G.GuildBankFrame, _G.MailFrame = nil, nil
	local n = M.loadAddon("BagSmith"); n.version = "1.11.0-beta6"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); for _ = 1, 12 do M.runTimers() end
	M.fire("BANKFRAME_OPENED"); M.runTimers(); M.runTimers()
	return M, n, n.Sections, n.SectionEditor, n.Window.bank
end
local function names(S, id) local l = S:Sheets(id); return l and table.concat(l, ",") or "every sheet" end
do
	-- B5-1, the auditor's case: bags and bank each have a Twin; the section is set to Twin; the editor is open
	local M, n, S, E, bank = sBoot()
	check(bank and n:SaveSheet("Twin") and n:SaveSheet("Twin", bank), "(set up: a sheet named Twin in the bags and one in the bank)")
	local id = S:Create("Cloth")
	S:SetSheets(id, { "Twin" })
	E:Open(id)
	check(n:UpdateSheet("Twin", "Bag Twin"), "(the bags' Twin is renamed with the editor open)")
	check(names(S, id) == "Twin,Bag Twin", "(the saved section shows on both, as it always has)")
	check(table.concat(E.draft.sheets, ",") == "Twin,Bag Twin", "the editor's ticks follow the same way (beta5 left them on Twin alone): " .. table.concat(E.draft.sheets, ","))
	local chips = {}
	for _, c in ipairs(E.frame.sheetChips) do if c:IsShown() then chips[c.sheet] = c.active and "on" or "off" end end
	check(chips["Twin"] == "on" and chips["Bag Twin"] == "on", "and its row of sheets shows both ticked")
	E:Save()
	check(names(S, id) == "Twin,Bag Twin", "saving the editor unchanged leaves the section on both (beta5 put it back on Twin alone): " .. names(S, id))
	-- what the player unticked stays unticked
	E:Open(id)
	E:ToggleSheet("Twin")
	check(table.concat(E.draft.sheets, ",") == "Bag Twin", "(Twin is unticked in the editor, not saved)")
	check(n:UpdateSheet("Twin", "Bank Twin", bank), "(the bank's Twin is renamed too)")
	check(table.concat(E.draft.sheets, ",") == "Bag Twin", "a name the player unticked gains nothing")
	E:Save()
	check(names(S, id) == "Bag Twin", "and Save keeps the player's choice")
	-- one of a pair deleted: the name is still a sheet, and nothing changes
	check(n:SaveSheet("Pair") and n:SaveSheet("Pair", bank), "(another pair)")
	S:SetSheets(id, { "Pair" })
	E:Open(id)
	n:DeleteSheet("Pair")
	check(table.concat(E.draft.sheets, ",") == "Pair" and names(S, id) == "Pair", "one of a pair deleted: the tick stays, the name is still a sheet")
	n:DeleteSheet("Pair", bank)
	check(#E.draft.sheets == 0, "the other deleted too: now the tick goes")
	E.frame:Hide()
	-- already ticked both: no double; and the cap holds
	check(n:SaveSheet("Dup") and n:SaveSheet("Dup", bank) and n:SaveSheet("Dup Two"), "(a pair, and a sheet with the name one of them is about to take)")
	S:SetSheets(id, { "Dup", "Gear" })
	E:Open(id)
	E:ToggleSheet("Dup Two")
	n:DeleteSheet("Dup Two")
	check(table.concat(E.draft.sheets, ",") == "Dup,Gear", "(set up)")
	check(n:UpdateSheet("Dup", "Dup Two"), "(the bags' Dup becomes Dup Two)")
	check(table.concat(E.draft.sheets, ",") == "Dup,Dup Two,Gear", "the new name goes in beside the old, once: " .. table.concat(E.draft.sheets, ","))
	local many = {}
	for i = 1, 23 do many[i] = "Sheet " .. i end
	many[24] = "Full"
	check(n:SaveSheet("Full") and n:SaveSheet("Full", bank), "(a pair named Full)")
	E.draft.sheets = many
	check(n:UpdateSheet("Full", "Fuller"), "(renamed with 24 sheets ticked)")
	check(#E.draft.sheets == 24, "the cap of 24 holds: " .. #E.draft.sheets)
	M.fire("BANKFRAME_CLOSED"); M.runTimers()
	check((n.errors or 0) == 0, "no errors")
end
do
	-- B5-2: both sides of the comparison after the auction house's cut
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS) end)
	check(DE.AfterCut(1010) == 960 and DE.AfterCut(980) == 931 and DE.AfterCut(100) == 95 and DE.AfterCut(1) == 1 and DE.AfterCut(0) == 0, "(DE.AfterCut: 5% off, in whole copper)")
	check(DE.AfterCut(nil) == 0 and DE.AfterCut(-5) == 0 and DE.AfterCut(0 / 0) == 0 and DE.AfterCut(1e30) < DE.MONEY_MAX, "(and nothing strange for a strange amount)")
	-- the auditor's control: an item and materials quoted alike come out even
	n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS) end, { prices = { [7001] = 1010, [10940] = 101 } })
	DE:Select(entryOf(DE, 7001)); castArmed(M, DE, b, { { 10940, 10 } })
	local t = DE:Results("session").tracked
	check(t.cn == 1 and t.ahU == 0 and t.matsValue == 1010 and t.matsNet == 960 and t.alt == 960 and t.ahead == 0, "equal quotes for the item and its materials come out even after the cut")
	check(line(DE, "Disenchanting and Selling Came Out Even"), "and the view says so")
	-- the auditor's crossover: a vendor price between the materials' quote and what the auction house would leave
	local boots = deep(BOOTS); boots.price = 1000
	n, M, DE, f, b = hBoot(function(M) M.put(0, 1, boots) end, { prices = { [7001] = 980, [10940] = 101 } })
	DE:Select(entryOf(DE, 7001)); castArmed(M, DE, b, { { 10940, 10 } })
	t = DE:Results("session").tracked
	check(t.vendor == 1000 and t.ah == 931 and t.alt == 1000 and t.matsValue == 1010 and t.matsNet == 960, "(a 10s vendor price, a 9s80c quote that leaves 9s31c, materials quoted at 10s10c that leave 9s60c)")
	check(t.ahead == -40, "selling wins by 40c (beta5 said disenchanting won by 10c): " .. tostring(t.ahead))
	check(line(DE, "Disenchanting Came Out Ahead By") == nil and line(DE, "Selling Would Have Paid More By")[2] == DE.Money(40), "the winner line says so")
	local note = line(DE, "Auction house amounts here are after its 5% cut.")
	check(note and note[3] == "note", "and the block says its auction house amounts are after the cut")
	check(line(DE, "At the Auction House")[2] == DE.Money(931) and line(DE, "Best of the Two")[2] == DE.Money(1000) and line(DE, "Their Materials, Sold at the AH Now")[2] == DE.Money(960), "each of its rows is what the sale would leave")
	check(line(DE, "Their Materials, at AH Value Now") == nil, "(the materials row has its new name)")
	local dust
	for _, l in ipairs(lines(DE)) do if l[1] == "Strange Dust x10" then dust = l end end
	check(dust and dust[2] == DE.Money(1010), "Materials Received still shows the market value, uncut: " .. tostring(dust and dust[2]))
	local best
	for _, l in ipairs(lines(DE)) do if l[4] == 7001 and l[1] == "Sturdy Boots" then best = l end end
	check(best and best[2] == "Vendor " .. DE.Money(1000), "the most valuable item is judged the same way: the vendor's 10s beats the auction's 9s31c")
	local st = BagSmithDB.deShared.stats
	check(st.v == 3 and st.ah == 931 and st.alt == 1000 and st.vendor == 1000, "the saved record is version 3, its auction amounts after the cut")
	-- an item the auction house pays more for, after the cut
	n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS) end)
	DE:Select(entryOf(DE, 7001)); castArmed(M, DE, b, { { 10940, 20 } })
	t = DE:Results("session").tracked
	check(t.ah == 1425 and t.alt == 1425 and t.matsNet == 2280 and t.ahead == 855, "boots quoted at 15s leave 14s25c; 24s of dust leaves 22s80c; ahead by 8s55c")
	for _, l in ipairs(lines(DE)) do if l[4] == 7001 and l[1] == "Sturdy Boots" then best = l end end
	check(best[2] == "AH, after its cut, " .. DE.Money(1425), "the most valuable item's line says its amount is after the cut: " .. tostring(best[2]))
	-- with no auction prices there is nothing cut, and no note about it
	n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS) end, { noAH = true })
	DE:Select(entryOf(DE, 7001)); castArmed(M, DE, b, { { 10940, 2 } })
	check(line(DE, "To a Vendor") and line(DE, "Auction house amounts here are after its 5% cut.") == nil, "no auction addon: no note about a cut")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- B5-3: no winner while a disenchant is still collecting its loot
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS); put(M, 3, DAGGER) end)
	DE:Select(entryOf(DE, 7001))
	local e = DE.current
	b:GetScript("PreClick")(b)
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", DEID)
	lootLine(M, 10940, 10)
	DE:ShowResults(true)
	local r = DE:Results("session")
	check(DE.castOpen ~= nil and r.pending == true and r.tracked.cn == 1 and r.tracked.matsNet == 1140, "(the cast succeeded, one loot line in, the cast still open)")
	check(r.tracked.ahead == nil, "no winner yet (beta5 said selling was ahead by 3s)")
	check(painted(DE, "Selling Would Have Paid More By") == nil and painted(DE, "Disenchanting Came Out Ahead By") == nil, "the view shows no winner line")
	local wait = line(DE, "No winner yet: a disenchant is still collecting its loot.")
	check(wait and wait[3] == "note" and painted(DE, "Their Materials, Sold at the AH Now") == DE.Money(1140), "it says why, and shows what has come so far")
	check(line(DE, "No winner yet: a disenchant is still collecting its loot.", "all"), "All Time waits the same way")
	lootLine(M, 10940, 5)
	M.fire("LOOT_CLOSED")
	r = DE:Results("session")
	check(DE.castOpen == nil and r.pending == nil and r.tracked.cn == 1 and r.tracked.matsNet == 1710 and r.tracked.ahead == 285, "the second line and the loot closing: both lines counted, the item once, ahead by 2s85c")
	check(painted(DE, "Disenchanting Came Out Ahead By") == DE.Money(285), "and the open view is drawn again with the winner, without being asked")
	-- a cast whose loot never closes stops holding the winner back once its time is up
	DE:ShowResults(false)
	DE:Select(entryOf(DE, 7002))
	b:GetScript("PreClick")(b)
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", DEID)
	DE:ShowResults(true)
	check(DE:Results("session").pending == true and DE.pendingLook == true, "(a second cast, open, nothing arriving: the view waits and has asked to look again)")
	for _ = 1, 80 do GetTime() end   -- the mock's clock: more than the five seconds a cast collects for
	check(DE:Results("session").pending == nil and DE:Results("session").tracked.ahead == 285, "past its time, the cast no longer holds the winner back (its item was never matched, so the comparison is the boots')")
	M.runTimers()
	check(DE.pendingLook == nil and painted(DE, "Disenchanting Came Out Ahead By") == DE.Money(285), "and the view looked again by itself")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- B5-3: a cast closed by its item leaving the bags (no loot window to close): the open view is drawn again then too
	local n2, M2, DE2, f2, b2 = hBoot(function(M) put(M, 1, BOOTS) end)
	DE2:Select(entryOf(DE2, 7001))
	local e2 = DE2.current
	b2:GetScript("PreClick")(b2)
	M2.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", DEID)
	lootLine(M2, 10940, 20)
	DE2.pendingLook = true   -- (the view's own second look, five seconds on, is kept out of this: the mock runs every timer at once)
	DE2:ShowResults(true)
	check(DE2.castOpen ~= nil and painted(DE2, "No winner yet: a disenchant is still collecting its loot.") ~= nil and painted(DE2, "Disenchanting Came Out Ahead By") == nil, "(a cast open, the view waiting)")
	M2.bags[e2.bag][e2.slot] = nil; M2.fire("BAG_UPDATE_DELAYED"); pump(M2)
	-- (by design since 1.11.0-beta7, the beta6 re-audit's B6-3: the item leaving no longer closes the cast a second
	-- later; it stays open for its loot until the loot window closes or its five seconds pass)
	check(DE2.castOpen ~= nil and painted(DE2, "Disenchanting Came Out Ahead By") == nil, "the item leaves: the cast is still open and the view still waits")
	M2.fire("LOOT_CLOSED"); pump(M2)
	check(DE2.castOpen == nil and painted(DE2, "Disenchanting Came Out Ahead By") == DE2.Money(855), "the loot closes, the cast closes, and the view names the winner without being asked")
	check((n2.errors or 0) == 0, "no errors")
end
do
	-- B5-4, the auditor's record (at this version): 201 kinds of material, of which 200 are kept
	local ms = {}
	for id = 10001, 10201 do ms[id] = 1 end
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS) end, { deShared = { version = 3, results = { ["2:a"] = { n = 201, mats = deep(ms) } }, stats = { v = 3, n = 201, cn = 201, alt = 20050, ahN = 201, mats = deep(ms) } } })
	n.AH.Available = function() return true end
	n.AH.Price = function() return 100 end
	local r = DE:Results("all")
	local t = r.tracked
	check(#r.mats == 201 and t.matsValue == 20000 and t.cn == 201, "(the log still has 201 kinds; the saved comparison kept 200 of them, and all 201 disenchants)")
	check(DE:Stats().gap == true and t.gap == true, "the record knows it lost part of itself when it was read")
	check(t.ahead == nil, "so no winner is named from it (beta5 said selling was ahead by 50c)")
	local why = line(DE, "No winner named: part of the saved record couldn't be read.", "all")
	check(why and why[3] == "note" and line(DE, "Selling Would Have Paid More By", "all") == nil and line(DE, "Disenchanting Came Out Ahead By", "all") == nil, "and the view says why")
	check(line(DE, "To a Vendor", "all") and line(DE, "Best of the Two", "all")[2] == DE.Money(20050), "(its totals are still shown)")
	-- This Session has its own record, which was never read from a file
	DE:Select(entryOf(DE, 7001)); castArmed(M, DE, b, { { 10940, 2 } })
	check(DE:Results("session").tracked.gap == nil and DE:Results("session").tracked.ahead ~= nil, "This Session is not held back by it")
	check(DE:Results("all").tracked.ahead == nil and BagSmithDB.deShared.stats.gap == true, "All Time stays without a winner, and the record is saved saying so")
	-- each kind of loss marks it; a clean record is not marked
	local function loaded(stats)
		stats.v = 3
		local n2, M2, DE2 = hBoot(function(M) put(M, 1, BOOTS) end, { deShared = { version = 3, results = {}, stats = stats } })
		return DE2:Stats(), DE2:Results("all").tracked
	end
	local st, tr = loaded({ n = 2, cn = 2, vendor = 900, ah = 1400, ahN = 1, ahU = 0, alt = 1900, mats = { [10940] = 20 }, q = { [2] = 2 } })
	check(st.gap == nil and tr.gap == nil and tr.ahead == DE.AfterCut(2400) - 1900, "a record read whole names its winner as ever")
	for label, bad in pairs({
		["a total below zero"] = { n = 2, cn = 2, vendor = 900, alt = -5, mats = { [10940] = 20 } },
		["a total that isn't a number"] = { n = 2, cn = 2, vendor = "lots", alt = 1900, mats = { [10940] = 20 } },
		["a total past the bound"] = { n = 2, cn = 2, vendor = 900, alt = 1e13, mats = { [10940] = 20 } },
		["a count that isn't whole"] = { n = 2, cn = 1.5, vendor = 900, alt = 1900, mats = { [10940] = 20 } },
		["a material with a bad count"] = { n = 2, cn = 2, vendor = 900, alt = 1900, mats = { [10940] = 20, [10938] = -1 } },
		["a material with a bad ID"] = { n = 2, cn = 2, vendor = 900, alt = 1900, mats = { [10940] = 20, x = 3 } },
		["materials that aren't a table"] = { n = 2, cn = 2, vendor = 900, alt = 1900, mats = "none" },
		["a mark from an earlier read"] = { n = 2, cn = 2, vendor = 900, alt = 1900, mats = { [10940] = 20 }, gap = true },
	}) do
		st, tr = loaded(bad)
		check(st.gap == true and tr.ahead == nil, "no winner from a record with " .. label)
	end
	st, tr = loaded({ n = 2, cn = 2, vendor = 900, ah = 1400, ahN = 1, ahU = 0, alt = 1900, mats = { [10940] = 20 }, q = { [2] = 2, [9] = 4 }, best = { id = 7001, q = 2, worth = 1425, vendor = -3, name = "a|b" } })
	check(st.gap == nil and tr.ahead ~= nil, "what isn't part of the comparison (a quality count, the most valuable item) doesn't mark it")   -- (by design since 1.11.0-beta7, B6-4: the fixture names every total, ahU too)
	-- beta5's record, version 2, is not read: its auction amounts were before the cut
	local n3, M3, DE3 = hBoot(function(M) put(M, 1, BOOTS) end, { deShared = { version = 3, results = { ["2:3:a"] = { n = 2, mats = { [10940] = 4 } } }, stats = { v = 2, n = 2, cn = 2, vendor = 900, ah = 1500, ahN = 1, alt = 1900, mats = { [10940] = 4 } } } })
	check(DE3:Stats().v == 3 and DE3:Stats().n == 0 and DE3:Results("all").n == 2 and DE3:Results("all").tracked == nil, "a beta5 record starts over; All Time's counts and materials stay, from the log")
	check((n.errors or 0) == 0, "no errors")
end
