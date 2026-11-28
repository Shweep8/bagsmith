-- ======== 1.11.0-beta7 (Shweep, 26 Nov: "build", on the plan for the beta6 re-audit) ========
-- Three things in one build.
--
-- 1. The answer to the independent re-audit of 1.11.0-beta6 ("Keep beta6 in beta"), each case reproduced on beta6
--    first with the auditor's own probe:
--      B6-1 (P2) an Offer Anyway question outlived the Helper being closed and reopened, or Results being opened,
--           and its Yes still set the reason aside.
--      B6-2 (P2, safety hardening) an offer was honoured at the click without proof that the slot held the same
--           instance, when the game's identity call was missing at that moment.
--      B6-3 (P3) a cast was closed a second after its item left the bags, so a later loot line inside its five
--           seconds was dropped and Results named a winner early.
--      B6-4 (P3, hardening) a saved record missing a total it needs was read as zero without being marked.
-- 2. The held-back list as Shweep asked after seeing beta6 in game: "not sure dimming the held back is a good call,
--    can be hard to read. also the button in header is hard to find, end of the reg list would possibly be
--    better.. also, can we better differentiate reg list from held back items?" Then, on the plan: "sounds good as
--    scoped".
-- 3. A bag he right-clicked was remembered by the swap hint as dragged ("wart fix you mentioned makes sense").
--
-- The fixtures down to the first block are the beta6 set's.

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
	local n = M.loadAddon("BagSmith"); n.version = "1.11.0-beta7"
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


local function favBoot()
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS); put(M, 3, DAGGER) end)
	n.Marks:ToggleFavorite(recOf(n, 7001)); pump(M); DE:Refresh()
	click(bandOf(f)); click(rowFor(f, 7001))
	return n, M, DE, f, b
end
local QUESTION = "Sturdy Boots is a favorite.\nDisenchant this one anyway? Nothing is disenchanted until you click Disenchant."

------------------------------------------------------------------------
-- B6-1. A question belongs to the moment it was asked
------------------------------------------------------------------------
do
	-- the auditor's first case: the question up, the Helper closed and opened again
	local n, M, DE, f, b = favBoot()
	check(DE.viewing and DE.viewing.held == "favorite" and not armed(b), "(set up: a favorite, held back, its row in the panel)")
	click(f.offer)
	local pop = n.Popups.confirm
	check(pop and pop:IsShown() and pop.text.text == QUESTION, "Offer Anyway asks, in BagSmith's own question box")
	local oldYes = pop.onYes
	check(type(oldYes) == "function" and DE.askFn == oldYes, "(the box holds the Helper's question)")
	DE:Close()
	check(not pop:IsShown() and DE.askFn == nil, "closing the Helper takes its question down (it stayed up, in beta6)")
	DE:Show(); pump(M)
	check(DE.viewing == nil and heldOf(DE, 7001) and not pop:IsShown(), "opened again: the boots are held back, and no question is waiting")
	oldYes()
	check(DE.offered == nil and heldOf(DE, 7001) ~= nil and entryOf(DE, 7001) == nil, "a Yes from the old question, were its box still up, sets nothing aside")
	check(armed(b) and DE.current.itemID == 7002, "(the dagger is armed, as on any opening)")
	-- and the same question asked again, in its own moment, still works
	click(rowFor(f, 7001)); click(f.offer)
	check(pop:IsShown() and pop.onYes ~= oldYes, "(asked again: a new question)")
	click(pop.yes)
	check(entryOf(DE, 7001) and DE.current.itemID == 7001 and DE.current.offered == "Favorite" and armed(b), "answered where it was asked, Yes offers the piece")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- the auditor's second case: Results opened over the question
	local n, M, DE, f, b = favBoot()
	click(f.offer)
	local pop = n.Popups.confirm
	local oldYes = pop.onYes
	DE:ShowResults(true)
	check(not pop:IsShown() and DE.askFn == nil, "opening Results takes the question down")
	oldYes()
	check(DE.offered == nil and not armed(b), "and its Yes does nothing behind Results")
	DE:ShowResults(false)
	check(heldOf(DE, 7001) ~= nil and entryOf(DE, 7001) == nil, "back on the list the boots are held back (beta6 offered them here)")
	-- nor can anything be offered while Results is up, or with the Helper closed
	DE:ShowResults(true)
	check(DE:OfferAnyway(DE.heldEntries[1], true) == false and DE.offered == nil, "DE:OfferAnyway refuses while Results is up")
	DE:ShowResults(false); DE:Close()
	check(DE:OfferAnyway(DE.heldEntries[1], true) == false and DE.offered == nil, "and with the Helper closed")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- everything else that changes what the Helper is showing drops the question too
	local drops = {
		{ "the held-back rows hidden", function(n, M, DE, f) click(bandOf(f)) end },
		{ "another row picked", function(n, M, DE, f) click(rowFor(f, 7002)) end },
		{ "the same row picked again", function(n, M, DE, f) click(rowFor(f, 7001)) end },
		{ "Skip", function(n, M, DE, f) click(f.skip) end },
		{ "combat starting", function(n, M, DE, f) M.combat = true; M.fire("PLAYER_REGEN_DISABLED") end },
		{ "the Helper turned off", function(n, M, DE, f) n:Set("deEnabled", false) end },
		{ "the favorite mark taken off and the list drawn again", function(n, M, DE, f) n.Marks:ToggleFavorite(recOf(n, 7001)); pump(M); DE:Refresh() end },
		{ "the piece leaving the bags", function(n, M, DE, f) M.bags[0][1] = nil; M.fire("BAG_UPDATE_DELAYED"); pump(M) end },
	}
	for _, d in ipairs(drops) do
		local n, M, DE, f, b = favBoot()
		click(f.offer)
		local pop = n.Popups.confirm
		local oldYes = pop.onYes
		check(pop:IsShown() and DE.askFn == oldYes, "(a question is up)")
		d[2](n, M, DE, f)
		check(not pop:IsShown() and DE.askFn == nil, d[1] .. ": the question is taken down")
		M.combat = false
		oldYes()
		check(DE.offered == nil or next(DE.offered) == nil, d[1] .. ": and its Yes sets nothing aside")
	end
	-- a second question replaces the first
	local n, M, DE, f, b = favBoot()
	n.Marks:ToggleFavorite(recOf(n, 7002)); pump(M); DE:Refresh()
	click(rowFor(f, 7001)); click(f.offer)
	local pop = n.Popups.confirm
	local first = pop.onYes
	DE.viewing = heldOf(DE, 7002); DE:OfferAnyway()
	check(pop:IsShown() and pop.onYes ~= first and pop.text.text:find("Worn Dagger is a favorite", 1, true), "(a second question, about the dagger)")
	first()
	check(DE.offered == nil, "the first question's Yes is dead once a second is asked")
	-- the box is shared: a question of someone else's is left alone
	local otherAnswered = false
	n.Confirm(nil, "Something else entirely?", function() otherAnswered = true end)
	check(pop:IsShown() and pop.text.text == "Something else entirely?" and DE.askFn ~= nil, "(another of BagSmith's questions takes the box)")
	DE:Close()
	check(pop:IsShown() and pop.text.text == "Something else entirely?", "closing the Helper leaves a question that isn't its own on screen")
	click(pop.yes)
	check(otherAnswered and DE.offered == nil, "and that question is answered as ever")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- the answer looks for itself too: the panel must still be on the row it was asked about
	local n, M, DE, f, b = favBoot()
	n.Marks:ToggleFavorite(recOf(n, 7002)); pump(M); DE:Refresh()
	click(rowFor(f, 7001)); click(f.offer)
	local pop = n.Popups.confirm
	local yes = pop.onYes
	DE.viewing = heldOf(DE, 7002)   -- (the panel moved by some way that told nobody)
	yes()
	check(DE.offered == nil, "a Yes with the panel on another row sets nothing aside, even if nothing dropped the question")
	-- and an opening that follows no closing still starts without a question: one held-back piece, nothing to offer,
	-- so the panel would be on the same row again
	local it = { facts = { [5387] = keepFacts(5387) } }
	n, M, DE, f, b = hBoot(function(M) put(M, 2, CLOAK) end, { it = it })
	n.Marks:ToggleFavorite(recOf(n, 5387)); pump(M); DE:Refresh()
	click(f.empty.heldShow)
	check(DE.viewing and DE.viewing.held == "favorite", "(set up: one held-back piece, a favorite, in the panel)")
	click(f.offer)
	pop = n.Popups.confirm
	yes = pop.onYes
	check(pop:IsShown() and DE.askFn == yes, "(its question is up)")
	DE.frame:Hide()   -- (hidden without the Helper's own close)
	-- (by design since 1.11.0-beta8, the beta7 re-audit's B7-3: the window hiding, by whatever means, takes its question down)
	check(not pop:IsShown(), "(the box goes down with the window)")
	DE:Show(); pump(M)
	check(DE.viewing and DE.viewing.itemID == 5387, "(opened again: the panel is on that row once more)")
	check(not pop:IsShown() and DE.askFn == nil, "opening the Helper drops a question left from before")
	yes()
	check(DE.offered == nil, "and its Yes sets nothing aside")
end
do
	-- closed in combat (as far as the player can tell): the question goes then too
	local n, M, DE, f, b = favBoot()
	click(f.offer)
	local pop = n.Popups.confirm
	local oldYes = pop.onYes
	DE.frame.IsProtected = function() return true end
	M.combat = true
	DE:Close()
	check(DE.frame.bsSoftClosed and not pop:IsShown() and DE.askFn == nil, "a close in combat takes the question down as well")
	M.combat = false; M.fire("PLAYER_REGEN_ENABLED"); pump(M)
	oldYes()
	check(DE.offered == nil, "and its Yes does nothing after combat")
end

------------------------------------------------------------------------
-- B6-2. An offer is honoured only for the piece proven to be in the slot
------------------------------------------------------------------------
do
	local n, M, DE, f, b = favBoot()
	click(f.offer); click(n.Popups.confirm.yes)
	local e = DE.current
	check(armed(b) and e and e.itemID == 7001 and DE:OfferedWhy(e.rec).favorite and DE:LiveCheck(e) == true, "(set up: the boots offered over their favorite mark, armed, passing the click's check)")
	-- the auditor's case: another copy in the slot, then the game's identity call gone
	put(M, 1, BOOTS)
	local info = C_Container.GetContainerItemInfo(0, 1)
	check(info.itemID == e.itemID and info.hyperlink == e.link and M.bags[0][1].guid ~= e.rec.guid, "(another copy of the boots in the slot: same item, same link, another instance)")
	local ok, why = DE:LiveCheck(e)
	check(ok == false and why == "that slot holds another copy of the item now", "with the identity call there, the other copy is refused as ever")
	local original = C_Item.GetItemGUID
	C_Item.GetItemGUID = nil
	ok, why = DE:LiveCheck(e)
	check(ok == false and why == "that item couldn't be confirmed as the piece you offered", "with the identity call gone, an offered piece that can't be proven is refused (beta6 let it pass): " .. tostring(why))
	b:GetScript("PreClick")(b)
	check(not armed(b) and DE.castingEntry == nil and DE.current == nil and DE.lastDisarm == why, "and the click is disarmed")
	-- the very piece that was offered, unproven, is refused too: proof is what is asked for
	C_Item.GetItemGUID = original
	local n2, M2, DE2, f2, b2 = favBoot()
	click(f2.offer); click(n2.Popups.confirm.yes)
	local e2 = DE2.current
	local orig2 = C_Item.GetItemGUID
	C_Item.GetItemGUID = nil
	ok, why = DE2:LiveCheck(e2)
	check(ok == false and why == "that item couldn't be confirmed as the piece you offered", "the offered piece itself, with no way to prove it is still the one, is refused too")
	-- a piece nobody offered keeps the path it always had on a client with no instances
	local dagger = entryOf(DE2, 7002)
	check(dagger and next(DE2:OfferedWhy(dagger.rec)) == nil and DE2:LiveCheck(dagger) == true, "a piece nobody offered passes without the identity call, as before")
	C_Item.GetItemGUID = orig2
	check(DE2:LiveCheck(e2) == true, "(the call back: the offered piece passes again)")
	check((n.errors or 0) == 0 and (n2.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- B6-3. A cast stays open for its loot until the loot closes or its five seconds pass
------------------------------------------------------------------------
do
	-- the auditor's case, on a clock: cast at 100, ten dust at once, the item gone, five more dust at 102
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS) end)
	local stamp = 100
	_G.GetTime = function() return stamp end
	DE:Select(entryOf(DE, 7001)); b:GetScript("PreClick")(b)
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", DEID)
	lootLine(M, 10940, 10)
	DE.pendingLook = true   -- (the view's own later look is kept out of this: the mock runs every timer at once)
	DE:ShowResults(true)
	check(DE:Results("session").pending and painted(DE, "Selling Would Have Paid More By") == nil, "(the first line in, the view waiting)")
	local oneSecond = 0
	local realAfter = C_Timer.After
	C_Timer.After = function(delay, fn) if delay == 1 then oneSecond = oneSecond + 1 end return realAfter(delay, fn) end
	M.bags[0][1] = nil; M.fire("BAG_UPDATE_DELAYED"); pump(M)
	C_Timer.After = realAfter
	check(oneSecond == 0, "the item leaving its slot starts no one-second close any more")
	stamp = 101.2
	pump(M)
	check(DE.castOpen ~= nil and DE:Results("session").pending and DE:Results("session").tracked.ahead == nil, "past the old second the cast is still open and no winner is named (beta6 closed it and said selling was ahead by 2s85c)")
	stamp = 102
	lootLine(M, 10940, 5)
	check(DE:Results("session").tracked.matsValue == 1800, "a second line inside the five seconds is counted (beta6 dropped it)")
	M.fire("LOOT_CLOSED")
	local done = DE:Results("session").tracked
	check(DE.castOpen == nil and done.cn == 1 and done.matsValue == 1800 and done.ahead == 285, "the loot closes: the item counted once, both lines, disenchanting ahead by 2s85c")
	check(painted(DE, "Disenchanting Came Out Ahead By") == DE.Money(285), "and the open view says so")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- its five seconds are still the limit, and what may be counted is unchanged
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS) end)
	local stamp = 100
	_G.GetTime = function() return stamp end
	DE:Select(entryOf(DE, 7001)); b:GetScript("PreClick")(b)
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", DEID)
	lootLine(M, 10940, 10)
	DE.pendingLook = true
	DE:ShowResults(true)
	M.bags[0][1] = nil; M.fire("BAG_UPDATE_DELAYED"); pump(M)
	stamp = 103
	lootLine(M, 2589, 4)   -- linen cloth, picked up from somewhere: nothing a disenchant gives
	check(DE:Results("session").tracked.matsValue == 1200 and DE.castOpen ~= nil, "something that isn't a disenchanting material is not counted for the cast, inside its time or not")
	check(painted(DE, "No winner yet: a disenchant is still collecting its loot.") ~= nil, "(the view is still waiting)")
	stamp = 105.5
	check(DE:Results("session").pending == nil, "five seconds after the cast it no longer holds the winner back")
	lootLine(M, 10940, 5)
	check(DE.castOpen == nil and DE:Results("session").tracked.matsValue == 1200, "a line after its five seconds is not counted, and closes the cast")
	check(painted(DE, "Selling Would Have Paid More By") == DE.Money(285), "and the open view is drawn again with what was counted in time")
	check((n.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- B6-4. A saved comparison must have every total it is made of
------------------------------------------------------------------------
do
	local function loaded(stats)
		local n, M, DE = hBoot(function(M) put(M, 1, BOOTS) end, { deShared = { version = 3, results = { ["2:a"] = { n = 1, mats = { [10940] = 5 } } }, stats = stats } })
		return DE:Stats(), DE:Results("all").tracked, DE
	end
	-- the auditor's record: one disenchant compared, 10s to a vendor, 6s of materials, and no best-sale total at all
	local st, t, DE = loaded({ v = 3, n = 1, cn = 1, vendor = 1000, ah = 0, ahN = 0, ahU = 0, mats = { [10940] = 5 } })
	check(t and t.matsKnown and t.matsNet == 570, "(its materials are whole: 5s70c after the cut)")
	check(st.gap == true and t.gap == true and t.ahead == nil, "a record with no best-sale total is marked, and names no winner (beta6 read the total as nothing and said disenchanting was ahead by 5s70c)")
	check(line(DE, "No winner named: part of the saved record couldn't be read.", "all") ~= nil, "the view says why")
	-- a whole record, for comparison
	local whole = { v = 3, n = 2, cn = 2, vendor = 900, ah = 1400, ahN = 1, ahU = 0, alt = 1900, mats = { [10940] = 20 } }
	st, t = loaded(deep(whole))
	check(st.gap == nil and t.ahead == DE.AfterCut(2400) - 1900, "a record with everything in it, and counts that agree, names its winner")
	-- each total it is made of, missing
	for _, k in ipairs({ "n", "cn", "vendor", "ah", "ahN", "ahU", "alt", "mats" }) do
		local r = deep(whole); r[k] = nil
		st, t = loaded(r)
		if k == "cn" then
			check(st.cn == 0 and (t == nil or t.ahead == nil), "without cn nothing is compared at all")
		else
			check(st.gap == true and (t == nil or t.ahead == nil), "missing " .. k .. ": marked, no winner")
		end
	end
	-- counts and totals that can't all be true
	for label, change in pairs({
		["more compared than disenchanted"] = { cn = 3 },
		["more priced and unpriced than compared"] = { ahN = 2, ahU = 1 },
		["a best-sale total below the vendor total"] = { alt = 800 },
		["a best-sale total below the auction total"] = { vendor = 100, ah = 1400, alt = 1300 },
		["a best-sale total above the two together"] = { alt = 2400 },
	}) do
		local r = deep(whole)
		for k, v in pairs(change) do r[k] = v end
		st, t = loaded(r)
		check(st.gap == true and t.ahead == nil, label .. ": marked, no winner")
	end
	-- a record with nothing compared yet needs none of it
	st, t = loaded({ v = 3, n = 2, mats = {} })
	check(st.gap == nil and st.cn == 0, "a record with nothing compared is not marked for what it doesn't have")
	-- and a real one, saved by this build and read back
	local n, M, DE2, f, b = hBoot(function(M) put(M, 1, BOOTS); put(M, 3, DAGGER) end)
	DE2:Select(entryOf(DE2, 7001)); castArmed(M, DE2, b, { { 10940, 20 } })
	DE2:Select(entryOf(DE2, 7002)); castArmed(M, DE2, b, {})
	local saved = deep(BagSmithDB.deShared)
	local n3, M3, DE3 = hBoot(function(M) put(M, 1, BOOTS) end, { deShared = saved })
	check(DE3:Stats().gap == nil and DE3:Stats().n == 2 and DE3:Stats().cn == 1 and DE3:Results("all").tracked.ahead == 855, "what this build saves reads back whole, one of its two disenchants unmatched included")
end

------------------------------------------------------------------------
-- The held-back list, as asked for after beta6 was seen in game
------------------------------------------------------------------------
local CHEV_RIGHT, CHEV_DOWN = "Interface\\AddOns\\BagSmith\\Media\\ui-chev-right.tga", "Interface\\AddOns\\BagSmith\\Media\\ui-chev-down.tga"
do
	local it = { facts = { [5387] = keepFacts(5387) } }
	local n, M, DE, f, b = hBoot(function(M) put(M, 1, BOOTS); put(M, 2, CLOAK); put(M, 3, DAGGER); put(M, 4, EPIC) end, { it = it })
	local rows = rowsOf(f)
	local band = rows[3]
	-- the switch is at the end of the offered rows, and the header has no button
	check(#rows == 3 and band.heading and band.entry == nil, "after the two offered rows comes the Held Back band, before anything is shown")
	check(plain(band.cells[2].text) == "Held Back (2)" and band.cells[6].text == "Show" and band.cells[1].text == "" and band.cells[3].text == "", "it reads Held Back (2), with Show at its right end")
	check(band.band:IsShown() and band.rule:IsShown() and band.chev:IsShown() and band.chev.texture == CHEV_RIGHT and not band.lock:IsShown() and not band.dot:IsShown(), "a tinted row with a rule above it and a chevron pointing right")
	check(f.heldShow == nil and f.heldLine:IsShown() and f.heldLine.text == "2 held back" and f.heldInfo:IsShown(), "the header keeps \"2 held back\" and its (i), and has no button")
	check(not rows[1].band:IsShown() and not rows[1].rule:IsShown() and not rows[1].chev:IsShown() and rows[1].dot:IsShown() and not rows[1].lock:IsShown(), "(an offered row has none of that: its ring, as ever)")
	check(armed(b) and DE.current.itemID == rows[1].entry.itemID, "(and the first offered piece is armed)")
	-- its tooltip
	GameTooltip:SetOwner(UIParent, "ANCHOR_TOP")
	band:GetScript("OnEnter")(band)
	check(table.concat(GameTooltip.lines or {}, " | "):find("Click to show or hide them.", 1, true), "hovering the band says what a click does")
	-- a click shows them
	click(band)
	rows = rowsOf(f)
	check(DE.showHeld == true and #rows == 5 and rows[3].heading and rows[3].cells[6].text == "Hide" and rows[3].chev.texture == CHEV_DOWN, "a click on the band shows the held-back rows; it reads Hide, its chevron down")
	local cloakRow, epicRow = rows[4], rows[5]
	check(cloakRow.entry.held == "itemtree" and epicRow.entry.held == "epic", "(the cloak and the epic)")
	-- not dimmed; told apart by a lock and an amber reason
	check(cloakRow:GetAlpha() == 1 and epicRow:GetAlpha() == 1, "held-back rows are at full strength (they were dimmed, in beta6)")
	check(cloakRow.lock:IsShown() and not cloakRow.dot:IsShown() and not cloakRow.dotFill:IsShown() and epicRow.lock:IsShown(), "each wears a lock where an offered row has its ring")
	local c6, o6 = cloakRow.cells[6].textColor, rows[1].cells[6].textColor
	check(c6 and c6[1] == 1 and c6[2] == 0.6 and c6[3] == 0.25, "its reason is in amber")
	check(o6 and o6[1] == 1 and o6[2] == 1 and o6[3] == 1, "an offered row's recommendation is white, as before")
	check(not cloakRow.band:IsShown() and not cloakRow.rule:IsShown() and not cloakRow.chev:IsShown(), "(a held-back row is not a band)")
	-- looked at: the highlight, and still the lock
	click(cloakRow)
	check(DE.viewing.itemID == 5387 and cloakRow.hl:IsShown() and cloakRow.lock:IsShown() and not cloakRow.dotFill:IsShown() and not armed(b), "looked at: highlighted, still locked, nothing armed")
	-- offered: an ordinary row again, and a row reused for it loses its lock and amber
	click(f.offer)
	rows = rowsOf(f)
	local offeredRow = rowFor(f, 5387)
	check(offeredRow and not offeredRow.lock:IsShown() and offeredRow.dot:IsShown() and offeredRow.cells[6].textColor[2] == 1, "offered, its row has a ring and a white recommendation")
	check(plain(bandOf(f).cells[2].text) == "Held Back (1)" and rowFor(f, 7010).lock:IsShown(), "the band counts one, and the epic keeps its lock")
	-- a click hides them
	click(bandOf(f))
	rows = rowsOf(f)
	check(DE.showHeld == false and #rows == 4 and rows[4].heading and rows[4].cells[6].text == "Show" and rows[4].chev.texture == CHEV_RIGHT and DE.viewing == nil, "a click on the band hides them again: three offered rows and the band")
	check(not rows[3].lock:IsShown() and rows[3].cells[6].textColor[2] == 1 and rows[3]:GetAlpha() == 1, "(the row that held a held-back piece a moment ago shows an offered one cleanly)")
	-- everything offered: nothing held back, no band
	click(bandOf(f)); DE:OfferAnyway(heldOf(DE, 7010), true)
	check(DE.held.total == 0 and bandOf(f) == nil and #rowsOf(f) == 4 and not f.heldLine:IsShown(), "with nothing held back there is no band and no count")
	check((n.errors or 0) == 0, "no errors")
end
do
	-- nothing to offer: the card, with a button of its own under the count
	local it = { facts = { [5387] = keepFacts(5387) } }
	local n, M, DE, f, b = hBoot(function(M) put(M, 2, CLOAK) end, { it = it })
	check(f.empty:IsShown() and f.empty.held.text == "1 held back" and f.empty.heldShow:IsShown() and f.empty.heldShow.label.text == "Show Held Back", "the empty card has Show Held Back")
	check(f.empty.heldShow.points[1][1] == "TOP" and f.empty.heldShow.points[1][2] == f.empty.held and f.empty.heldShow.points[1][3] == "BOTTOM", "centred under \"1 held back\"")
	check(f.empty.heldShow.tip == "Held-back items" and bandOf(f) == nil, "(with its tip; no band while the card is up)")
	click(f.empty.heldShow)
	local rows = rowsOf(f)
	check(not f.empty:IsShown() and #rows == 2 and rows[1].heading and rows[1].cells[6].text == "Hide" and rows[2].lock:IsShown(), "it shows the list: the band, reading Hide, and the held-back row")
	click(rows[1])
	check(f.empty:IsShown() and DE.showHeld == false, "the band's Hide brings the card back")
	-- no held-back pieces at all: no button, no band
	local n2, M2, DE2, f2 = hBoot(function(M) put(M, 1, BOOTS) end)
	check(bandOf(f2) == nil and #rowsOf(f2) == 1 and not f2.heldLine:IsShown(), "with nothing held back the list is just the offered rows")
	check((n.errors or 0) == 0 and (n2.errors or 0) == 0, "no errors")
end
do
	-- the What's New bullet says where the switch is now
	local n = hBoot(function(M) put(M, 1, BOOTS) end)
	local items = n.WhatsNew.ENTRIES[2].items   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
	check(#items == 8 and items[8]:find("click the Held Back line at the end of its list", 1, true) and not items[8]:find("Show beside", 1, true), "the card's eighth bullet points at the Held Back line: " .. plain(items[8]))
end

------------------------------------------------------------------------
-- The swap hint and a bag that was only clicked
------------------------------------------------------------------------
do
	package.loaded.mock = nil
	local M = require("mock")
	local MAGE = 4241
	M.put(0, 1, { id = 2770, name = "Copper Ore", q = 1, count = 5, class = 7, subclass = 7, price = 1 })
	M.put(1, 2, { id = MAGE, name = "Mageweave Bag", q = 1, class = 1, subclass = 0, equip = "INVTYPE_BAG", price = 10 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", debug = true } }, whatsNewSeen = "1.10.0" }
	_G.BagSmithWhatsNew = nil
	_G.GetInventoryItemID = function(_, inv) return ({ [20] = 4238 })[inv] end
	local n = M.loadAddon("BagSmith"); n.version = "1.11.0-beta7"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local bagSlot = CreateFrame("Button", "CharacterBag0Slot", UIParent)
	local itemButton = CreateFrame("Button", "BagSmithTestItem1_2", UIParent)
	local over = itemButton
	_G.GetMouseFoci = function() return { over } end
	local shown = 0
	local realShow = n.SwapHint.Show
	n.SwapHint.Show = function(...) shown = shown + 1 end
	local function said(from, what) for i = from, #M.log do if plain(M.log[i]):find(what, 1, true) then return true end end return false end
	-- his trace: a right-click on a bag in bag 1. The game locks it, lets it go, and refuses for lack of a free slot.
	local from = #M.log + 1
	M.cursorItem = nil
	M.bags[1][2].locked = true; M.fire("ITEM_LOCK_CHANGED", 1, 2)
	check(said(from, "Swap hint: remembered the bag from bag 1 slot 2"), "(the bag locks: remembered, as any bag picked up is)")
	M.bags[1][2].locked = nil; M.fire("ITEM_LOCK_CHANGED", 1, 2)
	check(said(from, "Swap hint: the bag was released back into bag 1 slot 2; cursor empty; pointer over BagSmithTestItem1_2"), "(it is let go, the cursor empty, the pointer on the item)")
	check(said(from, "Swap hint: forgot the bag (back in its slot, nothing on the cursor)"), "back in its slot with nothing on the cursor: it is forgotten at once")
	local mark = #M.log + 1
	M.fire("UI_ERROR_MESSAGE", 21, "No equipment slot is available for that item.")
	check(not said(mark, "Swap hint: game error") and not said(mark, "Swap hint: dragged bag from bag 1 (remembered)"), "the game's refusal a moment later is no longer read as a drag's (it was: his trace)")
	-- and for the ten seconds after, an error with the pointer on that bag's own slot explains nothing
	over = bagSlot
	M.fire("UI_ERROR_MESSAGE", 50, "Some other red message.")
	for _ = 1, 5 do M.runTimers() end
	check(shown == 0, "an unrelated error with the pointer on that bag's slot shows no swap explanation (it would have, for ten seconds)")
	-- a real drag let go of over its own bag's slot is still noticed, as before
	from = #M.log + 1
	M.bags[1][2].locked = true; M.cursorItem = MAGE; M.fire("ITEM_LOCK_CHANGED", 1, 2)
	M.cursorItem = nil; M.bags[1][2].locked = nil; M.fire("ITEM_LOCK_CHANGED", 1, 2)
	for _ = 1, 5 do M.runTimers() end
	check(said(from, "pointer over CharacterBag0Slot") and not said(from, "forgot the bag (back in its slot") and shown == 1, "a bag dragged and let go of over its own bag's slot is still explained")
	n.SwapHint.Show = realShow
	_G.GetMouseFoci = nil; _G.CharacterBag0Slot = nil
	check((n.errors or 0) == 0, "no errors")
end
