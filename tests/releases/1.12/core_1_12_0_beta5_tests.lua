-- ======== 1.12.0-beta5 (Shweep, 28 Nov: "build") ========
-- The answer to the independent audit of 1.12.0-beta4 ("Keep in beta"; four findings, all Medium, each reproduced on
-- beta4 first with the auditor's own two probes: 9 pass, 8 fail there, 17 pass here, unmodified).
--   B4-1 the bag menu's pick acted after its opening conditions had stopped being true.
--   B4-2 the game's error could be paired with an earlier bag than the one it was for.
--   B4-3 Pawn's advisor switched with the list open left the column as it was until a full redraw.
--   B4-4 sorted by Pawn, a new item answered at once showed its number but stayed sorted as not an upgrade.
-- And the report's advisories: a column's failures while sorting count toward its cutoff; a cell's text is cut between
-- characters.
-- The fixtures are the beta1 set's (Pawn) and the beta3 set's (the game's bag moves), as they stand.

local ARROW = "|TInterface\\AddOns\\Pawn\\Textures\\UpgradeArrow:0|t"
local function arrowed(pct) return pct and (ARROW .. " " .. pct) or ARROW end
local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function slurp(p) local f = assert(io.open(p, "r")); local s = f:read("*a"); f:close(); return s end
local function idOf(link) return tonumber(tostring(link):match("item:(%d+)")) end

-- answers[id]: true (an upgrade), false or nil (not one), "wait" (Pawn can't say yet: nil)
local function fakePawn()
	local P = { answers = {}, pct = {}, asks = 0, amountCalls = 0, rescans = 0 }
	_G.PawnShouldItemLinkHaveUpgradeArrow = function(link)
		P.asks = P.asks + 1
		local a = P.answers[idOf(link)]
		if a == "wait" then return nil end
		return a and true or false
	end
	_G.PawnGetItemData = function(link) return { Link = link, ID = idOf(link) } end
	_G.PawnIsItemAnUpgrade = function(item, doNotRescan)
		P.amountCalls = P.amountCalls + 1
		if doNotRescan ~= true then P.rescans = P.rescans + 1 end
		if P.fail then error("Pawn is busy") end
		return P.pct[item.ID]
	end
	_G.PawnBigUpgradeThreshold = 100
	_G.PawnCommon = { ShowBagUpgradeAdvisor = true }
	-- 9802: an upgrade for two scales, 15.4% and 31%; 9804: nothing in the slot (Pawn's huge number); 9805: a higher
	-- item level only (no list at all); 9806: under half a percent
	P.answers[9802], P.answers[9804], P.answers[9805], P.answers[9806] = true, true, true, true
	P.pct[9802] = { { ScaleName = "a", LocalizedScaleName = "A", PercentUpgrade = 0.154 }, { ScaleName = "b", LocalizedScaleName = "B", PercentUpgrade = 0.31 } }
	P.pct[9804] = { { ScaleName = "a", PercentUpgrade = 100 } }
	P.pct[9806] = { { ScaleName = "a", PercentUpgrade = 0.004 } }
	return P
end
local function noPawn()
	_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnGetItemData, _G.PawnIsItemAnUpgrade, _G.PawnBigUpgradeThreshold, _G.PawnCommon = nil, nil, nil, nil, nil
end

local function boot(o)
	o = o or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 9801, name = "Old Belt", q = 1, class = 4, subclass = 1, price = 5, equip = "INVTYPE_WAIST" })
	M.put(0, 2, { id = 9802, name = "Better Belt", q = 2, class = 4, subclass = 1, price = 50, equip = "INVTYPE_WAIST" })
	M.put(0, 3, { id = 9804, name = "First Ring", q = 2, class = 4, subclass = 0, price = 50, equip = "INVTYPE_FINGER" })
	M.put(0, 4, { id = 9805, name = "Level Only", q = 2, class = 4, subclass = 1, price = 50, equip = "INVTYPE_LEGS" })
	M.put(0, 5, { id = 9806, name = "Slight Gloves", q = 2, class = 4, subclass = 1, price = 50, equip = "INVTYPE_HAND" })
	M.put(0, 6, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 13 })
	if o.bag1 then M.put(1, 1, { id = 9807, name = "Spare Boots", q = 1, class = 4, subclass = 1, price = 5, equip = "INVTYPE_FEET" }) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = o.db and { version = 2, chars = {}, cache = {}, profiles = { Default = o.db } } or nil
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local main
	if not o.closed then
		ToggleAllBags(); M.runTimers()
		main = n.Window.main
		main.RowWidth = function() return o.width or 900 end   -- wide enough for every column, unless a case says otherwise
		n:RefreshViews(true); M.runTimers()
	end
	return n, M, main
end
local function row(v, id) for _, b in ipairs(v.used or {}) do if b:IsShown() and b.rec and b.hasItem and b.rec.itemID == id then return b end end end
local function cell(v, id, field) local b = row(v, id); local fs = b and b[field or "colX_pawn"]; return fs and fs.text or nil, fs end
local function keys(v) local t = {}; for _, c in ipairs((v:ColumnPlan())) do t[#t + 1] = c.key end; return table.concat(t, ",") end
local function col(v, key) for _, c in ipairs((v:ColumnPlan())) do if c.key == key then return c end end end
local function names(v) local t = {}; for _, b in ipairs(v.used or {}) do if b:IsShown() and b.rec and b.hasItem then t[#t + 1] = b.rec.name end end; return table.concat(t, " | ") end
local function tick(n, M, key, on, list)
	list = list or n.db.cols
	local i = n.IndexOf(list, key)
	if on and not i then table.insert(list, key) elseif not on and i then table.remove(list, i) end
	n:Fire("SETTINGS_CHANGED", "cols"); n:RefreshViews(true); M.runTimers()
end


local LINEN, WOOL, SILK, MAGE, RUNE, TINY, HERB = 4238, 4240, 4245, 4241, 14046, 4999, 22250
local SIZE = { [LINEN] = 4, [WOOL] = 6, [SILK] = 8, [MAGE] = 10, [RUNE] = 14, [TINY] = 2, [HERB] = 12 }
local NAMES = { [LINEN] = "Linen Bag", [WOOL] = "Wool Bag", [SILK] = "Silk Bag", [MAGE] = "Mageweave Bag", [RUNE] = "Runecloth Bag", [TINY] = "Tiny Pouch", [HERB] = "Herb Pouch" }
local function bagItem(id) return { id = id, name = NAMES[id], q = 1, class = 1, subclass = 0, equip = "INVTYPE_BAG", price = 10 } end
local function ore(n) return { id = 2770, name = "Copper Ore", q = 1, count = n or 5, class = 7, subclass = 7, price = 1 } end
-- worn: bag 1 Silk (8), bag 2 Linen (4), bag 3 Mageweave (10), bag 4 Wool (6). The new bag is at (o.at or backpack 1).
local function bagBoot(o)
	o = o or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0], M.sizes[1], M.sizes[2], M.sizes[3], M.sizes[4], M.sizes[5] = 4, 8, 4, 10, 6, 0
	local newID = o.new or RUNE
	local at = o.at or { 0, 1 }
	M.put(at[1], at[2], bagItem(newID))
	M.put(1, 1, ore()); M.put(1, 2, ore()); M.put(1, 3, ore())      -- the Silk Bag: 3 used
	M.put(2, 1, ore())                                              -- the Linen Bag: 1 used (2 with the new bag inside)
	M.put(4, 1, ore()); M.put(4, 2, ore())                          -- the Wool Bag: 2 used
	if o.fill then o.fill(M) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", debug = true } } }
	local equipped = o.equipped or { [20] = SILK, [21] = LINEN, [22] = MAGE, [23] = WOOL }
	_G.GetInventoryItemID = function(_, inv) return equipped[inv] end
	local clock = 100
	_G.GetTime = function() return clock end
	local st = { cur = nil, puts = {}, places = 0 }
	local function unlockSoon(it) C_Timer.After(0, function() it.locked = nil end) end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(id) local num = tonumber(tostring(id):match("item:(%d+)")) or id; if NAMES[num] then return NAMES[num] end return realInfo(id) end
	C_Container.PickupContainerItem = function(bag, slot)
		local it = M.bags[bag] and M.bags[bag][slot]
		if not st.cur then
			if it then st.cur = { id = it.id, bag = bag, slot = slot }; it.locked = true; M.cursorItem = it.id end
			return
		end
		if it then return end
		st.places = st.places + 1
		local moved = M.bags[st.cur.bag][st.cur.slot]
		M.bags[bag] = M.bags[bag] or {}
		M.bags[bag][slot] = moved; M.bags[st.cur.bag][st.cur.slot] = nil
		moved.locked = true; unlockSoon(moved)
		st.cur = nil; M.cursorItem = nil
	end
	_G.ClearCursor = function()
		if st.cur then local it = M.bags[st.cur.bag][st.cur.slot]; if it then it.locked = nil end end
		st.cur = nil; M.cursorItem = nil
	end
	_G.PutItemInBag = function(inv)
		st.puts[#st.puts + 1] = inv
		if not st.cur then return end
		local new = M.bags[st.cur.bag][st.cur.slot]
		local x = inv - 19
		if st.cur.bag == x then return end                       -- a bag stored in the bag it would replace: refused
		local used = 0
		for _, it in pairs(M.bags[x] or {}) do if it ~= new then used = used + 1 end end
		if used > (SIZE[new.id] or 0) then return end            -- too small for what the old bag holds: refused
		local old = equipped[inv]
		equipped[inv] = new.id
		M.sizes[x] = SIZE[new.id]
		local yb, ys = st.cur.bag, st.cur.slot
		M.bags[yb][ys] = nil
		st.cur = nil; M.cursorItem = nil
		local ob = bagItem(old); ob.locked = true; M.put(yb, ys, ob); unlockSoon(ob)
	end
	local r = { n = n, M = M, st = st, equipped = equipped, H = n.SwapHint, at = at, newID = newID }
	function r.tick(dt) clock = clock + dt end
	function r.run() for _ = 1, 40 do M.runTimers() end end
	-- the game's side of a right-click on the bag: its slot locks and unlocks with nothing on the cursor, then the red line
	function r.lock() M.bags[at[1]][at[2]].locked = true; M.fire("ITEM_LOCK_CHANGED", at[1], at[2]) end
	function r.unlock() M.bags[at[1]][at[2]].locked = nil; M.fire("ITEM_LOCK_CHANGED", at[1], at[2]) end
	function r.red() M.fire("UI_ERROR_MESSAGE", 21, "No equipment slot is available for that item.") end
	function r.rightClick() r.lock(); r.unlock(); r.red(); M.runTimers() end
	function r.menu()
		local m = n.menuFrame
		if not (m and m:IsShown()) then return nil end
		local rows = {}
		for _, x in ipairs(m.rows) do if x:IsShown() then rows[#rows + 1] = x end end
		return rows
	end
	function r.texts() local t = {}; for _, x in ipairs(r.menu() or {}) do t[#t + 1] = plain(x.text.text) end; return table.concat(t, " | ") end
	function r.pick(text) for _, x in ipairs(r.menu() or {}) do if plain(x.text.text):find(text, 1, true) then return x end end end
	function r.where(id) for bag = 0, 4 do for s, it in pairs(M.bags[bag] or {}) do if it.id == id then return bag, s end end end end
	return r
end


local function said(M, from, what) for i = from, #M.log do if plain(M.log[i]):find(what, 1, true) then return true end end return false end

------------------------------------------------------------------------
-- B4-1: the menu is retired when what it rests on changes, and a pick looks at everything again
------------------------------------------------------------------------
for _, place in ipairs({ { "a vendor", "MERCHANT_SHOW", "MerchantFrame" }, { "the mailbox", "MAIL_SHOW", "MailFrame" }, { "a trade", "TRADE_SHOW", "TradeFrame" }, { "the auction house", "AUCTION_HOUSE_SHOW", "AuctionHouseFrame" } }) do
	local r = bagBoot()
	r.rightClick()
	local pick = r.pick("Linen Bag").fn
	check(r.menu() ~= nil and r.H.offered ~= nil and pick ~= nil, "(" .. place[1] .. ": the menu is open)")
	_G[place[3]] = { IsShown = function() return true end }
	local from = #r.M.log + 1
	r.M.fire(place[2]); r.run()
	check(r.menu() == nil and r.H.offered == nil, place[1] .. " opening closes the menu")
	check(said(r.M, from, "Swap menu: withdrawn (a vendor, mailbox, trade or auction house opened)"), place[1] .. ": /bs debug says why")
	pick(); r.run()
	check(#r.st.puts == 0 and r.equipped[21] == LINEN and said(r.M, from, "Your bags changed while the menu was open, so nothing was swapped."), place[1] .. ": the row picked from before does nothing, and says so")
	_G[place[3]] = nil
end
do
	-- the bank, combat, and a place that sends no event BagSmith hears (the guild bank): refused at the pick
	local r = bagBoot()
	r.rightClick()
	r.n.atBank = true; r.n:Fire("BANK_OPENED"); r.run()
	check(r.menu() == nil and r.H.offered == nil, "the bank opening closes the menu")
	r.n.atBank = false
	r = bagBoot()
	r.rightClick()
	r.M.combat = true; r.M.fire("PLAYER_REGEN_DISABLED"); r.run()
	check(r.menu() == nil and r.H.offered == nil, "combat starting closes the menu")
	r = bagBoot()
	r.rightClick()
	local pick = r.pick("Linen Bag").fn
	_G.GuildBankFrame = { IsShown = function() return true end }
	pick(); r.run()
	check(#r.st.puts == 0 and r.equipped[21] == LINEN, "the guild bank open at the pick: nothing is swapped")
	_G.GuildBankFrame = nil
end
do
	-- the worn bags changing under the menu
	local r = bagBoot()
	r.rightClick()
	local pick = r.pick("Linen Bag").fn
	r.equipped[22] = nil                                      -- a different bag slot emptied; no event yet
	local from = #r.M.log + 1
	pick(); r.run()
	check(#r.st.puts == 0 and r.equipped[21] == LINEN and said(r.M, from, "Your bags changed while the menu was open"), "a bag slot emptied since the menu opened (the report's case): the pick swaps nothing")
	r = bagBoot()
	r.rightClick()
	r.equipped[22] = nil
	r.M.fire("BAG_UPDATE", 3); r.run()
	check(r.menu() == nil and r.H.offered == nil, "and when the game says a bag changed, the menu closes by itself")
	-- a bag update that changes nothing the offer rests on leaves the menu alone
	r = bagBoot()
	r.rightClick()
	r.M.fire("BAG_UPDATE", 1); r.n:Fire("ITEMS_CHANGED"); r.run()
	check(r.menu() ~= nil and r.H.offered ~= nil, "a bag update with nothing changed leaves the menu open")
	-- the picked row has become one that would be greyed
	r = bagBoot()
	r.rightClick()
	pick = r.pick("Linen Bag").fn
	r.equipped[21] = RUNE                                     -- the worn bag is now the same kind as the new one
	pick(); r.run()
	check(#r.st.puts == 0, "the picked bag changed to one that would be greyed: nothing is swapped")
	-- the picked row is the same bag still, but would now be greyed: a special bag, and the worn bag gained something
	-- that can't go in it (the model of the game here would swap it, so only this check stands in the way)
	r = bagBoot({ new = HERB })
	local fam = { [HERB] = 32, [765] = 32 }
	C_Item.GetItemFamily = function(id) return fam[id] or 0 end
	r.rightClick()
	pick = r.pick("Mageweave Bag").fn
	check(pick ~= nil, "(a special bag: the empty Mageweave Bag can be picked)")
	r.M.put(3, 1, ore())                                      -- ore lands in it while the menu is open; no event
	from = #r.M.log + 1
	pick(); r.run()
	check(#r.st.puts == 0 and r.equipped[22] == MAGE and said(r.M, from, "Your bags changed while the menu was open"), "the picked bag is the same but would now be greyed: nothing is swapped")
	-- a second offer retires the first: its rows are dead
	r = bagBoot()
	r.rightClick()
	local first = r.pick("Linen Bag").fn
	r.rightClick()
	check(r.menu() ~= nil, "(a second right-click: a fresh menu)")
	first(); r.run()
	check(#r.st.puts == 0 and r.equipped[21] == LINEN, "a row of the menu it replaced does nothing")
	-- the controls the report asks for: a normal pick still swaps; a refused one leaves the bags as they were
	r = bagBoot()
	r.rightClick()
	r.pick("Linen Bag").fn(); r.run()
	check(r.equipped[21] == RUNE and #r.st.puts == 1 and r.M.cursorItem == nil and not r.H.swapping and r.H.offered == nil, "control: a normal pick still swaps, once, and the offer is spent")
	local ob, os = r.where(LINEN)
	check(ob == 0 and os == 1, "control: the old bag is where the new one was")
	r = bagBoot({ new = TINY })
	r.rightClick()
	r.pick("Silk Bag").fn(); r.run()
	local nb, nsl = r.where(TINY)
	check(r.equipped[20] == SILK and nb == 0 and nsl == 1 and r.M.cursorItem == nil and not r.H.swapping and r.M.bags[1][1] and r.M.bags[1][2] and r.M.bags[1][3], "control: a pick the game refuses leaves both bags and the worn bag's contents where they were")
	check((r.n.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- B4-2: one error, one bag
------------------------------------------------------------------------
do
	-- the report's sequence: A released with no error; B locks, the error comes while B is locked, B is released
	local r = bagBoot()
	r.M.put(0, 2, bagItem(TINY))
	local function lockB() r.M.bags[0][2].locked = true; r.M.fire("ITEM_LOCK_CHANGED", 0, 2) end
	local function unlockB() r.M.bags[0][2].locked = nil; r.M.fire("ITEM_LOCK_CHANGED", 0, 2) end
	r.lock(); r.unlock(); r.tick(0.1)
	lockB(); r.red(); unlockB(); r.run()
	check(r.H.offered and r.H.offered.id == TINY and r.texts():find("^Swap in Tiny Pouch for:") ~= nil, "the error belongs to the bag that was locked when it came: the menu is for B: " .. r.texts())
	check(#r.st.puts == 0, "(nothing moved)")
	-- A released with no error; B clicked and released; then the error: B's, as the newer click
	r = bagBoot()
	r.M.put(0, 2, bagItem(TINY))
	r.lock(); r.unlock(); r.tick(0.1)
	r.M.bags[0][2].locked = true; r.M.fire("ITEM_LOCK_CHANGED", 0, 2); r.M.bags[0][2].locked = nil; r.M.fire("ITEM_LOCK_CHANGED", 0, 2)
	r.red(); r.run()
	check(r.H.offered and r.H.offered.id == TINY, "two clicks, then the error: it is the newer bag's")
	-- an error while B is locked is not claimed by A's release, nor by a late release of B
	r = bagBoot()
	r.M.put(0, 2, bagItem(TINY))
	r.M.bags[0][2].locked = true; r.M.fire("ITEM_LOCK_CHANGED", 0, 2)
	r.red()
	r.tick(0.6)
	r.M.bags[0][2].locked = nil; r.M.fire("ITEM_LOCK_CHANGED", 0, 2); r.run()
	check(r.menu() == nil, "the error first, the release more than half a second later: no menu")
	r = bagBoot()
	r.M.put(0, 2, bagItem(TINY))
	r.M.bags[0][2].locked = true; r.M.fire("ITEM_LOCK_CHANGED", 0, 2)
	r.red()
	r.lock()                                                  -- another bag locks: a new attempt; B's error is the past
	r.M.bags[0][2].locked = nil; r.M.fire("ITEM_LOCK_CHANGED", 0, 2)
	r.unlock(); r.run()
	check(r.menu() == nil, "an error for one bag, then another bag clicked with no error of its own: no menu for either")
	-- A clicked and released with no error; then B is dragged off to another slot; then an error: nobody's menu.
	-- (A new bag locking forgets the older click: without that, the error would be taken for A's.)
	r = bagBoot()
	r.M.put(0, 2, bagItem(TINY))
	r.lock(); r.unlock(); r.tick(0.1)
	r.M.cursorItem = TINY; r.M.bags[0][2].locked = true; r.M.fire("ITEM_LOCK_CHANGED", 0, 2)
	r.M.bags[0][3] = r.M.bags[0][2]; r.M.bags[0][2] = nil; r.M.bags[0][3].locked = nil; r.M.cursorItem = nil
	r.M.fire("ITEM_LOCK_CHANGED", 0, 2); r.M.fire("ITEM_LOCK_CHANGED", 0, 3)
	r.red(); r.run()
	check(r.menu() == nil and r.H.offered == nil, "a click with no error, then another bag dragged to a new slot, then an error: no menu for the first bag")
	-- a new bag being picked up withdraws a menu that is open for another
	r = bagBoot()
	r.M.put(0, 2, bagItem(TINY))
	r.rightClick()
	check(r.menu() ~= nil, "(a menu open for A)")
	r.M.bags[0][2].locked = true; r.M.fire("ITEM_LOCK_CHANGED", 0, 2); r.run()
	check(r.menu() == nil and r.H.offered == nil, "another bag picked up: the menu for the first is withdrawn")
	-- controls: both plain orders still work
	r = bagBoot()
	r.rightClick()
	check(r.H.offered and r.H.offered.id == RUNE, "control: click, release, error: the menu")
	r = bagBoot()
	r.lock(); r.red(); r.unlock(); r.M.runTimers()
	check(r.H.offered and r.H.offered.id == RUNE, "control: click, error, release: the menu")
	check((r.n.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- B4-3: Pawn's column follows its advisor's switch with the list open
------------------------------------------------------------------------
for _, sorted in ipairs({ false, true }) do
	local label = sorted and "sorted by Pawn: " or "not sorted by it: "
	fakePawn()
	local n, M, V = boot()
	n:Set("grp", "none")
	tick(n, M, "pawn", true)
	if sorted then V.headerLabels.pawn:GetScript("OnClick")(V.headerLabels.pawn); M.runTimers() end
	n.Pawn:Pass(); M.runTimers()
	check(cell(V, 9802) == arrowed("+31%") and V.headerLabels.pawn:IsShown() and col(V, "pawn") ~= nil, label .. "(the column is showing)")
	local layouts, realRefresh = 0, n.RefreshViews
	n.RefreshViews = function(self, ...) layouts = layouts + 1; return realRefresh(self, ...) end
	_G.PawnCommon.ShowBagUpgradeAdvisor = false
	n.Pawn:OnPawnRefresh("advisor off")
	M.runTimers(); M.runTimers(); M.runTimers()
	local b = row(V, 9802)
	check(not b.pawnArrow:IsShown(), label .. "the advisor off: the arrow goes (as before)")
	check(not col(V, "pawn") and not V.headerLabels.pawn:IsShown() and not b.colX_pawn:IsShown() and b.colX_pawn.text == "", label .. "and so does the column, its heading and what its cells held, with no redraw asked for")
	check(n.IndexOf(n.db.cols, "pawn") ~= nil, label .. "the saved tick is untouched")
	check(layouts >= 1 and layouts <= 3, label .. "one layout for the change, not a stream of them (" .. layouts .. ")")
	layouts = 0
	M.runTimers(); M.runTimers(); M.runTimers(); M.runTimers()
	check(layouts == 0, label .. "and nothing keeps redrawing afterwards (" .. layouts .. ")")
	_G.PawnCommon.ShowBagUpgradeAdvisor = true
	n.Pawn:OnPawnRefresh("advisor on")
	M.runTimers(); M.runTimers(); M.runTimers()
	check(col(V, "pawn") ~= nil and V.headerLabels.pawn:IsShown() and row(V, 9802).pawnArrow:IsShown() and cell(V, 9802) == arrowed("+31%"), label .. "the advisor on again: the column is back, filled")
	n.RefreshViews = realRefresh
	check((n.errors or 0) == 0, label .. "no errors")
	noPawn()
end
do
	-- the window's narrowest width and an open Bag Columns page follow too; Pawn arriving late
	fakePawn()
	local n, M, V = boot()
	local all = { "c", "t", "bd", "v", "w", "age", "fv", "cc", "jk", "il", "rq", "sl", "pawn" }
	n.db.cols = all; n.db.colAside = {}; n:Fire("SETTINGS_CHANGED", "cols"); n:RefreshViews(true); M.runTimers()
	local with = V.minWidth
	local Pn = n.SettingsPanel
	Pn:Show(); M.runTimers(); Pn:ShowPage("bagcols"); M.runTimers()
	local function pawnRow() for _, l in ipairs(Pn.pools.list or {}) do if l:IsShown() then for _, x in ipairs(l.rows) do if x:IsShown() and x.id == "pawn" then return x end end end end end
	check(pawnRow().box:IsEnabled(), "(Bag Columns open: Pawn's row is live)")
	_G.PawnCommon.ShowBagUpgradeAdvisor = false
	n.Pawn:OnPawnRefresh("advisor off"); M.runTimers(); M.runTimers()
	check(V.minWidth == with - 30, "the advisor off: the window's narrowest width no longer counts the column (" .. tostring(with) .. " to " .. tostring(V.minWidth) .. ")")
	check(not pawnRow().box:IsEnabled() and pawnRow().box:GetChecked(), "and the open Bag Columns page greys its row, still ticked")
	_G.PawnCommon.ShowBagUpgradeAdvisor = true
	n.Pawn:OnPawnRefresh("advisor on"); M.runTimers(); M.runTimers()
	check(V.minWidth == with and pawnRow().box:IsEnabled(), "on again: both are as they were")
	Pn:Hide()
	-- with the bags closed, the window's narrowest width still follows (it is applied when the change comes, not
	-- when the window is next drawn)
	n.Window.main:Hide(); M.runTimers()
	_G.PawnCommon.ShowBagUpgradeAdvisor = false
	n.Pawn:OnPawnRefresh("advisor off"); M.runTimers(); M.runTimers()
	check(V.frame.resizeBounds[1] == with - 30, "the bags closed: the window's narrowest width follows all the same (" .. tostring(V.frame.resizeBounds[1]) .. ")")
	_G.PawnCommon.ShowBagUpgradeAdvisor = true
	n.Pawn:OnPawnRefresh("advisor on"); M.runTimers(); M.runTimers()
	check(V.frame.resizeBounds[1] == with, "and back")
	n.Window.main:Show(); M.runTimers()
	-- any number of changes in one frame make one layout
	local layouts, realRefresh = 0, n.RefreshViews
	n.RefreshViews = function(self, ...) layouts = layouts + 1; return realRefresh(self, ...) end
	n.Columns:AvailabilityChanged("pawn"); n.Columns:AvailabilityChanged("pawn"); n.Columns:AvailabilityChanged("pawn")
	check(layouts == 0, "(the layout waits for the next frame)")
	M.runTimers()
	local once = layouts
	n.Columns:AvailabilityChanged("nope"); M.runTimers()
	check(once >= 1 and layouts == once, "three changes in one frame: the windows are laid out as for one (" .. once .. "); an unknown column: not at all")
	n.Columns:AvailabilityChanged("pawn"); M.runTimers()
	local one = layouts - once
	check(one == once, "(the same count as a single change makes: " .. one .. ")")
	n.RefreshViews = realRefresh
	check((n.errors or 0) == 0, "no errors")
	noPawn()
	-- Pawn loading after BagSmith
	n, M, V = boot({ db = { cols = { "c", "t", "pawn" }, fvccCols = true, jkCol = true } })
	check(not col(V, "pawn"), "(no Pawn yet: the ticked column isn't in the row)")
	local P = fakePawn()
	M.fire("ADDON_LOADED", "Pawn"); M.runTimers(); M.runTimers(); M.runTimers()
	check(col(V, "pawn") ~= nil and V.headerLabels.pawn:IsShown(), "Pawn loading late: the ticked column joins the row by itself")
	check((n.errors or 0) == 0, "no errors")
	noPawn()
end

------------------------------------------------------------------------
-- B4-4: sorted by Pawn, a new item sorts where its answer puts it
------------------------------------------------------------------------
for _, dir in ipairs({ "desc", "asc" }) do
	for _, late in ipairs({ false, true }) do
		local label = (dir == "desc" and "largest first, " or "smallest first, ") .. (late and "Pawn answering a moment later: " or "Pawn answering at once: ")
		local P = fakePawn()
		local n, M, V = boot()
		n:Set("grp", "none")
		tick(n, M, "pawn", true)
		local h = V.headerLabels.pawn
		h:GetScript("OnClick")(h); M.runTimers()
		if dir == "asc" then h:GetScript("OnClick")(h); M.runTimers() end
		M.runTimers(); M.runTimers()
		P.answers[9810] = late and "wait" or true
		P.pct[9810] = { { PercentUpgrade = 0.75 } }
		local changes, realChanged = 0, n.Columns.Changed
		n.Columns.Changed = function(self, key) changes = changes + 1; return realChanged(self, key) end
		M.put(0, 7, { id = 9810, name = "Newest Helm", q = 2, class = 4, subclass = 1, price = 50, equip = "INVTYPE_HEAD" })
		M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED")
		for _ = 1, 4 do M.runTimers() end
		if late then
			check(cell(V, 9810) == "", label .. "(not answered yet: its cell is empty)")
			P.answers[9810] = true
			for _ = 1, 6 do M.runTimers() end
		end
		check(cell(V, 9810) == arrowed("+75%"), label .. "the new item shows +75%")
		local order = names(V)
		if dir == "desc" then check(order:find("^Newest Helm | Better Belt") ~= nil, label .. "and is first, above +31%: " .. order)
		else check(order:find("Better Belt | Newest Helm$") ~= nil, label .. "and is last, after +31%: " .. order) end
		-- no loop: once it has settled, nothing more is told to the column and nothing more is redrawn
		local settled = changes
		local layouts, realRefresh = 0, n.RefreshViews
		n.RefreshViews = function(self, ...) layouts = layouts + 1; return realRefresh(self, ...) end
		for _ = 1, 8 do M.runTimers() end
		check(changes == settled and layouts == 0, label .. "then it is quiet: no further notice or redraw (" .. changes .. " in all)")
		check(changes >= 1 and changes <= 3, label .. "one or two notices, not one per row")
		n.RefreshViews, n.Columns.Changed = realRefresh, realChanged
		check((n.errors or 0) == 0, label .. "no errors")
		noPawn()
	end
end
do
	-- not sorted by Pawn: the same arrival redraws nothing extra (the cell is filled by the row's own fill)
	local P = fakePawn()
	local n, M, V = boot()
	tick(n, M, "pawn", true)
	M.runTimers(); M.runTimers()
	local layouts, realRefresh = 0, n.RefreshViews
	P.answers[9810] = true; P.pct[9810] = { { PercentUpgrade = 0.75 } }
	M.put(0, 7, { id = 9810, name = "Newest Helm", q = 2, class = 4, subclass = 1, price = 50, equip = "INVTYPE_HEAD" })
	M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
	n.RefreshViews = function(self, ...) layouts = layouts + 1; return realRefresh(self, ...) end
	for _ = 1, 6 do M.runTimers() end
	check(cell(V, 9810) == arrowed("+75%") and layouts == 0, "not sorted by Pawn: the new item's cell is filled and no extra redraw follows (" .. layouts .. ")")
	n.RefreshViews = realRefresh
	noPawn()
end

------------------------------------------------------------------------
-- The advisories
------------------------------------------------------------------------
do
	noPawn()
	local n, M, V = boot()
	local api = BagSmith.API
	-- a column that fails only while sorting is counted, and switched off
	local sorts = 0
	check(n.Columns:Register("zs", { label = "Zs", text = function() return "ok" end, sort = function() sorts = sorts + 1; error("sort broke") end }) == true, "(a column whose sort fails)")
	for i = 1, 4 do n.Columns:SortValue("zs", { itemID = i }) end
	check(n.Columns:Get("zs").off ~= true and n.Columns:Get("zs").fails == 4, "four failures while sorting are counted")
	check(n.Columns:SortValue("zs", { itemID = 5 }) == 0 and n.Columns:Get("zs").off == true, "the fifth switches the column off, as five failures while drawing do")
	local s0 = sorts
	check(n.Columns:SortValue("zs", { itemID = 6 }) == 0 and sorts == s0 and (n.errors or 0) == 0, "after that its function isn't called, and none of it is an error of BagSmith's")
	-- an addon's onUpdate failing during a sort (the first time an item is asked about) counts too
	local calls = 0
	api.RegisterColumn("Flaky", "flaky", function() calls = calls + 1; error("no") end)
	for i = 1, 5 do n.Columns:SortValue("x:flaky", { itemID = i, bag = 0, slot = i, link = "l" .. i }) end
	check(n.Columns:Get("x:flaky").off == true and calls == 5, "an addon's column failing five times while sorting is switched off")
	-- a long text is cut between characters
	local euro = "\226\130\172"   -- one character, three bytes
	local text
	api.RegisterColumn("Long", "long", function() return text end)
	text = ("a"):rep(199) .. euro .. "zzz"
	local got = n.Columns:Value("x:long", { itemID = 1, bag = 0, slot = 1, link = "a" })
	check(#got == 199 and got == ("a"):rep(199), "a character that would straddle the 200th byte is left out whole (" .. #got .. " bytes kept)")
	text = ("a"):rep(197) .. euro .. "zzz"
	got = n.Columns:Value("x:long", { itemID = 2, bag = 0, slot = 2, link = "b" })
	check(#got == 200 and got:sub(198, 200) == euro, "one that ends on the 200th byte is kept")
	text = ("a"):rep(250)
	check(#n.Columns:Value("x:long", { itemID = 3, bag = 0, slot = 3, link = "c" }) == 200, "plain text is cut at 200 as before")
	local doc = slurp("docs/API.md")
	check(doc:find("text over 200 bytes is cut, between characters", 1, true) and doc:find("After five failures, while drawing or while sorting, the column is switched", 1, true) and doc:find("until you call it, the old answers stay on screen", 1, true),
		"docs/API.md says all three: the cut, what counts as a failure, and whose job a refresh is")
	check((n.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- The version
------------------------------------------------------------------------
do
	check(slurp("BagSmith/BagSmith.toc"):find("\n## Version: 1%.12%.0"), "the TOC version is 1.12.0's (the exact one is pinned in tests/run.lua)")
	local top = slurp("BagSmith/CHANGELOG.md"):match("^## 1%.12%.0\n(.-)\n## 1%.11%.0\n") or ""
	local entries = 0
	for _ in ("\n" .. top):gmatch("\n%- ") do entries = entries + 1 end
	check(entries == 5, "the changelog's 1.12.0 section is unchanged: these are fixes to things 1.12 itself adds")
end
