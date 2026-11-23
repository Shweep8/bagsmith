-- ======== 1.10.0-beta6 (Shweep, 22 Nov: "okay build beta per above") ========
-- (1) What ItemTree knows, as rules: Used by My Professions, Needed for a Quest, An Upgrade for Me and Sold by Vendors
-- for sections and filters, ItemTree's Advice for filters only; "Use ItemTree" in Settings > General. ItemTree is
-- optional. Its answers are asked once per item, a few a frame, and only while a rule wants them (Core/ItemTree.lua).
-- (2) The second window (the Type list) and its shade get layers of their own above the window they open over
-- (Shweep's screenshots: "the Edit Section and Change a Rule window glitch each other out").
--
-- The facts below are ItemTree v1.2.8's real answers on Shweep's priest, as his /run printed them (22 Nov).

local FIVE = { "Cooking", "Enchanting", "First Aid", "Fishing", "Tailoring" }
local function uses(skills, current, stale, reagent, quest)
	return { reagentSkills = skills, current = current, stale = stale, professions = FIVE, kinds = { reagent = reagent, lock = 0, spell = 0, quest = quest or 0, tool = 0, teaches = 0 } }
end
local function noQuests() return { stale = false, needs = {}, titles = {}, predicted = {}, starts = {}, counts = {}, staleAfter = {} } end
local FACTS = {
	[3173] = { itemId = 3173, known = true,   -- Bear Meat
		price = { worthTrip = false, copper = 30, source = "auctionator" },
		keep = { lines = { "Keep (61)", "Cooking (skill 50 to 100)", "2 x Cooking", "Thelsamar Blood Sausages" }, always = false, marked = true, line = "Keep (61)", noAuctionData = false, valuable = false,
			stock = { every = true, uses = { { usefulName = "Blood Sausage", useful = 3220, item = 3220, profession = "Cooking", skill = 185, name = "Blood Sausage" } } },
			tags = { "keep" }, never = false, need = 61, state = "keep", off = false, byUse = true, legendary = false },
		route = { needed = true, need = 58, profession = "Cooking" },
		vendors = { buyPrice = 60, everywhere = false, count = 0 },
		uses = uses({}, 1, 2, 0, 1),
		quests = { stale = false, needs = { 418 }, titles = { [418] = "Thelsamar Blood Sausages" }, predicted = {}, starts = {}, counts = { [418] = 3 }, staleAfter = {} } },
	[2996] = { itemId = 2996, known = true,   -- Bolt of Linen Cloth
		price = { worthTrip = false, copper = 44, source = "auctionator" },
		keep = { lines = { "Keep", "Useful from level 8 to 11" }, always = false, marked = true, line = "Keep", noAuctionData = false, valuable = false, tags = { "keep" }, never = false, state = "keep", off = false, byUse = true,
			why = { profession = "Tailoring", kind = "trade", skill = 197 }, legendary = false },
		route = { needed = true, need = 201, profession = "Tailoring" },
		vendors = { buyPrice = 160, everywhere = false, count = 0 },
		uses = uses({ 197 }, 19, 27, 19), quests = noQuests() },
	[279898] = { itemId = 279898, known = true,   -- Dwarven Tome (no price at all)
		keep = { lines = { "Equip (Any spec)", "Upgrade for your Off Hand (slot empty)" }, always = false, marked = true, line = "Equip (Any spec)",
			gear = { basis = "empty", specs = { "discipline", "holy", "shadow" }, upgrade = true, labels = { "Discipline", "Holy", "Shadow" } },
			valuable = false, noAuctionData = false, tags = { "equip" }, never = false, state = "keep", off = false, byUse = true, legendary = false },
		vendors = { buyPrice = 1919, everywhere = false, count = 0 },
		route = { needed = false },
		uses = uses({}, 0, 0, 0), quests = noQuests() },
	[3372] = { itemId = 3372, known = true,   -- Leaded Vial
		price = { worthTrip = false, copper = 45, source = "auctionator" },
		keep = { lines = { "Vendor", "Sold by vendors everywhere", "3 x Enchanting", "2 x First Aid", "51 x Alchemy", "7 x Poisons" }, always = false, marked = false, line = "Vendor", valuable = false, noAuctionData = false,
			tags = { "vendor" }, never = false, state = "vendor", off = false, byUse = false, legendary = false },
		route = { needed = false, need = 0 },
		vendors = { buyPrice = 200, everywhere = true, count = 92 },
		uses = uses({ 333, 129 }, 63, 0, 63), quests = noQuests() },
	[2321] = { itemId = 2321, known = true,   -- Fine Thread
		price = { worthTrip = false, copper = 99, source = "auctionator" },
		keep = { lines = { "Keep (18)", "Tailoring (skill 85 to 95)" }, always = false, marked = true, noAuctionData = false, line = "Keep (18)", valuable = false, tags = { "keep" }, never = false, need = 18, state = "keep", off = false,
			byUse = true, why = { profession = "Tailoring", kind = "trade", skill = 197 }, legendary = false },
		route = { needed = true, need = 18, profession = "Tailoring" },
		vendors = { buyPrice = 100, everywhere = true, count = 94 },
		uses = uses({ 197, 129 }, 195, 1, 195), quests = noQuests() },
	[3371] = { itemId = 3371, known = true,   -- Empty Vial
		price = { worthTrip = false, copper = 7, source = "auctionator" },
		keep = { lines = { "Keep (32)", "First Aid (skill 1 to 40)" }, always = false, marked = true, noAuctionData = false, line = "Keep (32)", valuable = false, tags = { "keep" }, never = false, need = 32, state = "keep", off = false,
			byUse = true, why = { profession = "Fishing", kind = "trade", skill = 356 }, legendary = false },
		route = { needed = true, need = 32, profession = "First Aid" },
		vendors = { buyPrice = 20, everywhere = true, count = 105 },
		uses = uses({ 356 }, 21, 22, 21), quests = noQuests() },
	[6530] = { itemId = 6530, known = true,   -- Nightcrawlers
		price = { worthTrip = false, copper = 26, source = "auctionator" },
		keep = { lines = { "Vendor", "Sold by vendors everywhere" }, always = false, marked = false, line = "Vendor", valuable = false, noAuctionData = false, tags = { "vendor" }, never = false, state = "vendor", off = false, byUse = false,
			consumable = { notFood = true, keep = false, judged = false, xpFood = false, buffFood = false }, legendary = false },
		route = { needed = false },
		vendors = { buyPrice = 100, everywhere = true, count = 68 },
		uses = uses({}, 1, 0, 1), quests = noQuests() },
	[1708] = { itemId = 1708, known = true,   -- Sweet Nectar
		price = { worthTrip = false, copper = 189, source = "auctionator" },
		keep = { lines = { "Keep", "Best drink in your bags", "Sold by vendors everywhere", "2 x Cooking" }, always = false, marked = true, line = "Keep", valuable = false, noAuctionData = false, tags = { "keep" }, never = false,
			state = "keep", off = false, byUse = false,
			consumable = { words = "Best drink in your bags", judged = true, xpFood = false, outranked = false, buffFood = false, notFood = false, keep = true, efficient = true, kind = "drink", restore = 1344 }, legendary = false },
		route = { needed = false, need = 0 },
		vendors = { buyPrice = 1000, everywhere = true, count = 147 },
		uses = uses({ 185 }, 2, 0, 2), quests = noQuests() },
}
local function deep(t) if type(t) ~= "table" then return t end local c = {}; for k, v in pairs(t) do c[k] = deep(v) end; return c end

-- ItemTree, as BagSmith meets it: a global table of plain functions. Every call returns a new table, as in the game.
local function fakeItemTree(state)
	state.calls, state.asked, state.requested = 0, {}, 0
	return {
		version = 1,
		IsReady = function() return state.ready ~= false end,
		RequestData = function() state.requested = state.requested + 1 end,
		RegisterReadyCallback = function(fn) state.onReady = fn end,
		RegisterChangeCallback = function(fn) state.onChange = fn end,
		GetItemFacts = function(id, link)
			state.calls = state.calls + 1
			state.asked[id] = (state.asked[id] or 0) + 1
			if state.raise and state.raise[id] then error("ItemTree broke") end
			if state.ready == false then return nil end
			return deep((state.facts or FACTS)[id])
		end,
	}
end
-- it: "none" (not installed), or a state table for the fake (ready unless it says ready = false)
local function boot(opts)
	opts = opts or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 16
	local function tg(slot, id, name, sub, subName, extra)
		local it = { id = id, name = name, q = 1, count = 5, class = 7, subclass = sub, type = "Trade Goods", sub = subName, price = 10, ilvl = 10 }
		for k, v in pairs(extra or {}) do it[k] = v end
		M.put(0, slot, it)
	end
	tg(1, 3173, "Bear Meat", 8, "Cooking")
	tg(2, 2996, "Bolt of Linen Cloth", 5, "Cloth")
	tg(3, 3372, "Leaded Vial", 11, "Other")
	tg(4, 2321, "Fine Thread", 11, "Other")
	tg(5, 3371, "Empty Vial", 11, "Other")
	M.put(0, 6, { id = 279898, name = "Dwarven Tome", q = 2, count = 1, class = 4, subclass = 0, type = "Armor", sub = "Miscellaneous", equip = "INVTYPE_HOLDABLE", bind = 2, price = 480, ilvl = 24 })
	M.put(0, 7, { id = 6530, name = "Nightcrawlers", q = 1, count = 4, class = 0, subclass = 8, type = "Consumable", sub = "Other", price = 25, ilvl = 10 })
	M.put(0, 8, { id = 1708, name = "Sweet Nectar", q = 1, count = 10, class = 0, subclass = 5, type = "Consumable", sub = "Food & Drink", price = 50, ilvl = 25 })
	-- something ItemTree has no answer for
	tg(9, 99001, "Mystery Dust", 12, "Enchanting")
	_G.INVTYPE_HOLDABLE = "Held In Off-hand"
	_G.ITEM_QUALITY_COLORS = { [0] = { r = 0.62, g = 0.62, b = 0.62 }, { r = 1, g = 1, b = 1 }, { r = 0.12, g = 1, b = 0 }, { r = 0, g = 0.44, b = 0.87 }, { r = 0.64, g = 0.21, b = 0.93 }, { r = 1, g = 0.5, b = 0 } }
	local state = opts.it ~= "none" and (opts.it or {}) or nil
	_G.ItemTreeAPI = (state and not opts.late) and fakeItemTree(state) or nil
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local prof = { view = "list", grp = "type", favSection = true, recentSection = false }
	for k, v in pairs(opts.prof or {}) do prof[k] = v end
	_G.BagSmithDB = opts.saved or { version = 2, chars = {}, cache = {}, profiles = { Default = prof } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta6"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	return n, M, n.Window.main, n.Sections, n.Rules, n.ItemTree, state
end
local function pump(M) for _ = 1, 40 do M.runTimers() end end
local function recOf(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
local function click(b) b:GetScript("OnClick")(b) end
local function yes(k, n) return { mode = "all", rows = { { k = k, v = { "yes" }, n = n } } } end
local function inSection(n, id)
	local t = {}
	for _, r in ipairs(n.items) do if r.itemID and r.cat == id then t[#t + 1] = r.name end end
	table.sort(t)
	return table.concat(t, ", ")
end
local function shown(main)
	local t = {}
	for i, r in ipairs((main:Filtered())) do t[i] = r.name end
	table.sort(t)
	return table.concat(t, ", ")
end
local MATS = "Bear Meat, Bolt of Linen Cloth, Empty Vial, Fine Thread, Leaded Vial, Sweet Nectar"
-- (by design since 1.10.0-beta7, Shweep: "the description is somewhat confusing": the row's description is one
-- sentence, the state is on a line of its own under it, and the addon's name is in its own color)
local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
-- (by design since 1.10.0-beta9, Shweep: "this needs more consistency and a scalable plan": ItemTree has a card of its
-- own on Settings > Other Addons; its state is beside the card's heading, and the switch is Section and Filter Rules)
local function stateLine(P)
	for _, w in ipairs(P.pools.head or {}) do
		if w:IsShown() and w.text and w.text.text == "ItemTree" then return w.state and w.state:IsShown() and w.state.text or nil end
	end
end

;(function()
	-- ItemTree's real answers, as the few a rule reads
	local n, M, main, S, R, IT = boot({ it = "none" })
	local function read(id) local e = IT.Read(deep(FACTS[id])); return ("%s %s %s %s %s"):format(tostring(e.prof), tostring(e.quest), tostring(e.upgrade), tostring(e.vendor), table.concat(e.tags, "+")) end
	check(read(3173) == "true true false false keep", "Bear Meat: a profession keeps it (Cooking's route), a quest needs it, no vendor sells it; advice Keep (" .. read(3173) .. ")")
	check(read(2996) == "true false false false keep", "Bolt of Linen Cloth: Tailoring uses it now")
	check(read(279898) == "false false true false equip", "Dwarven Tome: an upgrade, no profession, advice Equip; and it has no price at all")
	check(read(3372) == "true false false true vendor", "Leaded Vial: two of his professions use it though ItemTree doesn't keep it; sold by vendors; advice Vendor")
	check(read(2321) == "true false false true keep" and read(3371) == "true false false true keep", "Fine Thread and Empty Vial: used, and sold by vendors")
	check(read(6530) == "false false false true vendor", "Nightcrawlers: a lure is no recipe's ingredient for him: not used by his professions; sold by vendors")
	check(read(1708) == "true false false true keep", "Sweet Nectar: two Cooking recipes use it")
	-- the trap the real output showed: uses.kinds are COUNTS for every profession's recipes, and 0 is true in Lua
	local trap = IT.Read({ uses = { kinds = { reagent = 63 }, reagentSkills = {} }, route = { needed = false } })
	check(trap.prof == false, "sixty-three recipes of other people's professions don't make it used by yours")
	local zero = IT.Read({ uses = { kinds = { reagent = 0 } }, vendors = { count = 0, buyPrice = 60 }, keep = { gear = { upgrade = false } }, quests = { needs = {} } })
	check(zero.prof == false and zero.vendor == false and zero.upgrade == false and zero.quest == false and #zero.tags == 0, "zeroes, an empty list and a vendor price with no vendor all read as no")
	check(IT.Read(nil) == nil and IT.Read("x") == nil, "no table from ItemTree: no answer")
	local odd = IT.Read({ keep = { tags = { "keep", 7, "Not A Tag", "vendor", {} } }, uses = "x", route = 5, vendors = { count = "many" } })
	check(odd.prof == false and odd.vendor == false and table.concat(odd.tags, "+") == "keep+vendor", "anything unexpected in its table is left out, never an error")
	-- the rules' words
	check(R:RowText({ k = "it_prof", v = { "yes" } }) == "Used by My Professions is Yes" and R:RowText({ k = "it_vendor", v = { "yes" }, n = true }) == "Sold by Vendors is not Yes", "yes or no rules read \"is Yes\" and \"is not Yes\"")
	check(R:RowText({ k = "it_advice", v = { "vendor", "worthless" } }) == "ItemTree's Advice is Vendor or Worthless" and R:RowText({ k = "it_quest", v = { "yes" } }) == "Needed for a Quest is Yes" and R:RowText({ k = "it_upgrade", v = { "yes" } }) == "An Upgrade for Me is Yes", "and the others")
	local c = R.Clean({ rows = { { k = "it_prof", v = { "yes", "no", true } }, { k = "it_advice", v = { "vendor", "Vendor", "keep me", "pet" } } } })
	check(c and #c.rows == 2 and #c.rows[1].v == 1 and #c.rows[2].v == 2 and c.rows[2].v[2] == "pet", "kept like any rule: yes alone; ItemTree's own lowercase words, one it may add later included")
	check(R.KEYS.it_advice.filterOnly and not R.KEYS.it_prof.filterOnly and #R.KEY_ORDER == 6, "its advice is a filter's rule only; New Section From This Item is as it was")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- no ItemTree: BagSmith is as it was, and a rule that needs it waits
	local n, M, main, S, R, IT = boot({ it = "none" })
	check(not IT:Installed() and not IT:Enabled() and not IT:Ready() and IT:Facts(recOf(n, 3173)) == nil, "not installed: no answers")
	local id = S:CreateWithRules("Mats", yes("it_prof")); pump(M)
	check(id and S:Rules(id).rows[1].k == "it_prof" and inSection(n, id) == "", "a section whose rule needs ItemTree is kept, and takes nothing")
	S:SetRules(id, yes("it_prof", true)); pump(M)
	check(inSection(n, id) == "", "\"is not\" takes nothing either: no answer is not a no")
	local menu
	n.ShowMenu = function(items) menu = items end
	local f = S:EditSection(id); M.runTimers()
	check(f.rows[1].label.text == "Used by My Professions" and f.rows[1].note:IsShown() and f.rows[1].note.text == "ItemTree isn't installed, so this rule fits nothing for now." and f.rows[1].verb:IsShown(), "the editor shows the rule and says why it's waiting")
	click(f.add)
	check(menu[#menu].text == "Optional: the ItemTree addon adds more rules here." and menu[#menu].disabled and #menu == 8, "+ Add a Rule: one quiet line about ItemTree, no rules of its own")
	click(f.cancel)
	-- Settings > Other Addons (by design since 1.10.0-beta9: an addon you don't have shows its card with no rows)
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("addons"); M.runTimers()
	local row
	for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.key == "useItemTree" then row = w end end
	check(row == nil and stateLine(P) == "Not installed", "ItemTree's card is listed, with no switch to tick: Not installed")
	local said
	for _, w in ipairs(P.pools.text or {}) do if w:IsShown() and w.text.text == "BagSmith works with these addons when you have them. None is needed." then said = true end end
	check(said, "and the page says none of them is needed")
	P:Hide()
	check(n.db.useItemTree == true, "(the setting itself is on, for the day ItemTree is installed)")
	check((n.errors or 0) == 0, "no errors")
end)()

for _, skin in ipairs({ "modern", "classic" }) do
	-- with ItemTree: asked once an item, a few at a time, only while a rule wants it
	local S0 = skin .. ": "
	local it = {}
	local n, M, main, S, R, IT = boot({ it = it, prof = { skin = skin } })
	check(IT:Installed() and IT:Enabled() and IT:Ready(), S0 .. "installed, on by default, ready")
	pump(M); M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); pump(M)
	check(it.calls == 0 and it.onChange ~= nil and it.onReady ~= nil, S0 .. "no rule needs it: ItemTree is asked nothing (BagSmith only listens for its changes)")
	local reapplied = 0
	local realReapply = S.Reapply
	S.Reapply = function(self, ...) reapplied = reapplied + 1; return realReapply(self, ...) end
	local mats = S:CreateWithRules("Profession Mats", yes("it_prof"))
	check(inSection(n, mats) == "" and it.calls == 0 and select(2, IT:Count()) == 9, S0 .. "a section that asks: at first the items wait where they were, and nine questions wait their turn")
	M.runTimers()
	check(it.calls > 0 and it.calls <= 4 and inSection(n, mats) == "", S0 .. "a few are asked on the next frame, not all at once (" .. it.calls .. ")")
	pump(M)
	check(it.calls == 9 and inSection(n, mats) == MATS, S0 .. "a few frames on: each item asked once, and the six his professions use are in the section (" .. inSection(n, mats) .. ")")
	check(recOf(n, 279898).cat == "Gear" and recOf(n, 6530).cat == "Consumables" and recOf(n, 99001).cat == "TradeGoods", S0 .. "the tome, the lure and the item ItemTree doesn't know stay where they were")
	local asked = it.calls
	M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); pump(M)
	n:RefreshViews(true); pump(M)
	check(it.calls == asked and inSection(n, mats) == MATS, S0 .. "another look at the bags, another redraw: nothing asked again")
	-- one more Bear Meat: that item alone is asked again, and nothing is redrawn for the same answer
	reapplied = 0
	M.bags[0][1].count = 6
	M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); pump(M)
	check(it.calls == asked + 1 and it.asked[3173] == 2 and it.asked[2996] == 1, S0 .. "one more Bear Meat looted: Bear Meat is asked again, nothing else")
	check(reapplied == 0, S0 .. "its answer is the same, so nothing is sorted again for it")
	-- a new item
	M.put(0, 10, { id = 2589, name = "Linen Cloth", q = 1, count = 3, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 10, ilvl = 5 })
	it.facts = deep(FACTS); it.facts[2589] = { itemId = 2589, known = true, uses = { reagentSkills = { 197, 129 } }, route = { needed = true }, vendors = { count = 0 }, keep = { tags = { "keep" } }, quests = { needs = {} } }
	M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); pump(M)
	check(it.asked[2589] == 1 and recOf(n, 2589).cat == mats, S0 .. "a new item is asked about, and joins the section")
	-- ItemTree says its answers changed
	asked = it.calls
	it.facts[3372].uses.reagentSkills = {}   -- (say he dropped Enchanting and First Aid)
	it.onChange("setting"); pump(M)
	check(it.calls == asked + 10 and recOf(n, 3372).cat == "TradeGoods" and recOf(n, 2996).cat == mats, S0 .. "ItemTree's change notice: everything is asked afresh, and the Leaded Vial leaves the section")
	-- something that can change its answers with no word from it
	asked = it.calls
	it.facts[279898].keep.gear.upgrade = false
	M.fire("PLAYER_EQUIPMENT_CHANGED", 17); M.fire("PLAYER_EQUIPMENT_CHANGED", 16); pump(M)
	check(it.calls == asked + 10, S0 .. "gear changed (twice in a moment): asked afresh once")
	-- the other yes or no rules, and "is not"
	S:SetRules(mats, yes("it_quest")); pump(M)
	check(inSection(n, mats) == "Bear Meat", S0 .. "Needed for a Quest: Bear Meat")
	S:SetRules(mats, yes("it_vendor")); pump(M)
	check(inSection(n, mats) == "Empty Vial, Fine Thread, Leaded Vial, Nightcrawlers, Sweet Nectar", S0 .. "Sold by Vendors: the five a vendor sells")
	S:SetRules(mats, yes("it_vendor", true)); pump(M)
	check(inSection(n, mats) == "Bear Meat, Bolt of Linen Cloth, Dwarven Tome, Linen Cloth", S0 .. "is not Yes: the ones ItemTree says no vendor sells, and not the item it doesn't know")
	it.facts[279898].keep.gear.upgrade = true
	it.onChange("setting"); pump(M)
	S:SetRules(mats, yes("it_upgrade")); pump(M)
	check(inSection(n, mats) == "Dwarven Tome", S0 .. "An Upgrade for Me: the tome")
	check(it.requested == 0, S0 .. "BagSmith never asks ItemTree to load its data")
	check((n.errors or 0) == 0, S0 .. "no errors")
end

;(function()
	-- not ready yet; turned off; an error inside ItemTree; ItemTree loaded after BagSmith
	local it = { ready = false }
	local n, M, main, S, R, IT = boot({ it = it })
	local mats = S:CreateWithRules("Profession Mats", yes("it_prof")); pump(M)
	check(IT:Installed() and not IT:Ready() and it.calls == 0 and inSection(n, mats) == "", "installed but not ready: nothing asked, the section waits")
	it.ready = true
	it.onReady(); pump(M)
	check(it.calls == 9 and inSection(n, mats) == MATS, "ItemTree says it's ready: asked, and the section fills")
	-- Use ItemTree off
	local asked = it.calls
	n:Set("useItemTree", false); pump(M)
	check(not IT:Enabled() and inSection(n, mats) == "" and recOf(n, 3173).cat == "TradeGoods" and it.calls == asked, "Use ItemTree off: its rules fit nothing at once, and it's asked nothing")
	local menu
	n.ShowMenu = function(items) menu = items end
	local f = S:EditSection(mats); M.runTimers()
	check(f.rows[1].note:IsShown() and f.rows[1].note.text == "ItemTree is turned off in Settings, so this rule fits nothing for now.", "the editor says the rule is waiting for the setting")
	click(f.add)
	check(menu[#menu].text == "ItemTree is turned off. Turn it on in Settings to add its rules." and menu[#menu].disabled, "+ Add a Rule: one line that says where to turn it on")
	click(f.cancel)
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("addons"); M.runTimers()
	local row
	for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.key == "useItemTree" then row = w end end
	check(row and row.text.text == "Section and Filter Rules" and row.box:IsEnabled() and not row.box:GetChecked() and stateLine(P) == "Installed", "Settings: installed and off, ready to tick")
	row.box:SetChecked(true); click(row.box); pump(M)
	row = nil
	for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.key == "useItemTree" then row = w end end
	check(n.db.useItemTree == true and row and row.box:GetChecked() and stateLine(P) == "Installed", "ticked: on")
	check(inSection(n, mats) == MATS and it.calls == asked + 9, "and the section fills again, each item asked afresh")
	local heads = {}
	for _, w in ipairs(P.pools.head or {}) do if w:IsShown() then heads[#heads + 1] = tostring(w.text and w.text.text or w.text) end end
	-- (by design since 1.10.0-beta8: the Auction Prices card joined Other Addons; since beta9: a page of its own)
	table.sort(heads)
	check(table.concat(heads, " | ") == "Auction Prices | ItemTree | Pawn", "it has its own card on the Other Addons page (" .. table.concat(heads, " | ") .. ")")
	P:Hide()
	-- ItemTree raising an error is no answer, not an error of BagSmith's
	it.raise = { [3173] = true }
	it.onChange("setting"); pump(M)
	check(recOf(n, 3173).cat == "TradeGoods" and recOf(n, 2996).cat == mats and (n.errors or 0) == 0, "an error inside ItemTree for one item: that item waits, the rest are sorted, nothing breaks")
	-- Global Inventory's rows are about every character: never asked
	asked = it.calls
	check(IT:Facts({ itemID = 2996, global = true }) == nil and IT:Facts({ empty = true }) == nil and IT:Facts(nil) == nil and it.calls == asked, "a Global Inventory row, an empty slot: no question")
	-- loaded after BagSmith
	local late = {}
	n, M, main, S, R, IT = boot({ it = late, late = true })
	mats = S:CreateWithRules("Profession Mats", yes("it_prof")); pump(M)
	check(not IT:Installed() and inSection(n, mats) == "", "(ItemTree not there yet)")
	_G.ItemTreeAPI = fakeItemTree(late)
	S:Reapply(); pump(M)
	check(IT:Ready() and late.onChange ~= nil and inSection(n, mats) == MATS, "ItemTree appearing later in the session is found, listened to and asked")
	check((n.errors or 0) == 0, "no errors")
end)()

for _, skin in ipairs({ "modern", "classic" }) do
	-- + Add a Rule with ItemTree; its advice in the Filters window; the second window's own layer
	local S0 = skin .. ": "
	local it = {}
	local n, M, main, S, R, IT = boot({ it = it, prof = { skin = skin } })
	local E = n.SectionEditor
	local menu
	n.ShowMenu = function(items) menu = items end
	local f = S:EditSection(); M.runTimers()
	click(f.add)
	local texts = {}
	for i, item in ipairs(menu) do texts[i] = item.text end
	check(table.concat(texts, " | ") == "What should the rule look at? | Type | Slot | Quality | Binding | Item Level | Vendor Value | What ItemTree knows | Used by My Professions | Needed for a Quest | An Upgrade for Me | Sold by Vendors"
		and menu[8].title and menu[9].tip:find("professions", 1, true), S0 .. "the section editor's + Add a Rule: What ItemTree knows, four rules (its advice isn't a section's)")
	menu[9].onClick(); M.runTimers()
	local r1 = f.rows[1]
	check(#E.draft.rows == 1 and r1.label.text == "Used by My Professions" and r1.verb.label.text == "is" and r1.chips[1]:IsShown() and r1.chips[1].label.text == "Yes" and r1.chips[1].active and not r1.note:IsShown() and not r1.choose:IsShown(),
		S0 .. "Used by My Professions: a row that says is Yes")
	pump(M)
	local names = {}
	for i, r in ipairs(E.shown.here) do names[i] = r.name end
	check(table.concat(names, ", ") == MATS and it.calls == 9, S0 .. "the list on the right fills as ItemTree answers (" .. table.concat(names, ", ") .. ")")
	click(r1.verb); pump(M)
	names = {}
	for i, r in ipairs(E.shown.here) do names[i] = r.name end
	check(r1.verb.label.text == "is not" and table.concat(names, ", ") == "Dwarven Tome, Nightcrawlers", S0 .. "is not Yes: the tome and the lure")
	click(r1.verb)
	f.edit:SetText("Profession Mats"); click(f.save); pump(M)
	local made = S:Customs()[1]
	check(made and made.rules.rows[1].k == "it_prof" and inSection(n, made.id) == MATS, S0 .. "Create Section: the section, filled")
	-- Settings says the rule in words
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("custom"); M.runTimers()
	local row
	for _, w in ipairs(P.pools.csec or {}) do if w:IsShown() and w.id == made.id then row = w end end
	check(row and row.sub.text == "Used by My Professions is Yes" and row.text.text:find("(6 items)", 1, true), S0 .. "Settings > Custom Sections: Used by My Professions is Yes, 6 items")
	P:Hide()
	-- the second window's own layer (the Type list over the editor)
	f = S:EditSection(made.id); M.runTimers()
	E:AddRow("type"); M.runTimers()
	local p = E.picker
	check(p:IsShown() and f:GetFrameStrata() == "DIALOG" and f.shade:IsShown() and f.shade:GetFrameStrata() == "FULLSCREEN" and p:GetFrameStrata() == "FULLSCREEN_DIALOG",
		S0 .. "the Type list is in a layer above the editor's, with the shade in a layer between (" .. tostring(p:GetFrameStrata()) .. ")")
	check(p:GetHeight() <= f:GetHeight() and p.parent == f, S0 .. "it's no taller than the editor, and still closes with it")
	f:Hide()
	check(not p:IsShown() and not f.shade:IsShown(), S0 .. "(the editor closed: the list and the shade go)")
	-- the Filters window: ItemTree's Advice too
	local Po = n.Popups
	Po:OpenFilters(main, "browse"); M.runTimers()
	local ff = Po.filter
	local L = ff.list
	click(ff.add)
	texts = {}
	for i, item in ipairs(menu) do texts[i] = item.text end
	check(table.concat(texts, " | "):find("Time in Bags | What ItemTree knows | Used by My Professions | Needed for a Quest | An Upgrade for Me | Sold by Vendors | ItemTree's Advice$"), S0 .. "the Filters window's + Add a Rule: the same four, and ItemTree's Advice")
	menu[#menu].onClick(); pump(M)
	local chips = {}
	for _, c in ipairs(L.rows[1].chips) do if c:IsShown() then chips[#chips + 1] = c.label.text end end
	check(L.rows[1].label.text == "ItemTree's Advice" and table.concat(chips, ", ") == "Keep, Equip, Use, Open, Auction, Vendor, Disenchant, Worthless", S0 .. "ItemTree's Advice: its words on the row (" .. table.concat(chips, ", ") .. ")")
	click(L.rows[1].chips[6]); pump(M)
	check(shown(main) == "Leaded Vial, Nightcrawlers" and ff.count.text == "2 of 9 items shown", S0 .. "Vendor: the two ItemTree would vendor")
	click(L.rows[1].chips[2]); pump(M)
	check(shown(main) == "Dwarven Tome, Leaded Vial, Nightcrawlers", S0 .. "and Equip: the tome too")
	-- a Section rule's list opens in its own layer over the Filters window too
	L:AddRow("sec"); M.runTimers()
	check(L.picker:IsShown() and L.picker:GetFrameStrata() == "FULLSCREEN_DIALOG" and ff.shade:GetFrameStrata() == "FULLSCREEN" and L.picker:GetHeight() <= ff:GetHeight(), S0 .. "the Filters window's list has its own layer too, and is no taller than the window")
	L:ClosePicker()
	click(ff.clearBtn); ff:Hide(); pump(M)
	-- its advice among a section's rules fits nothing, and the editor says so
	n.db.customSections[1].rules = R.Clean({ mode = "all", rows = { { k = "it_advice", v = { "keep" } } } })
	S:Reapply(); pump(M)
	check(inSection(n, made.id) == "", S0 .. "ItemTree's Advice among a section's rules takes nothing")
	f = S:EditSection(made.id); M.runTimers()
	check(f.rows[1].label.text == "ItemTree's Advice" and f.rows[1].note.text == "Only a filter can use this rule. Here it fits nothing.", S0 .. "and the editor says only a filter can use it")
	click(f.cancel)
	check(it.requested == 0 and (n.errors or 0) == 0, S0 .. "no errors, and ItemTree was never asked to load anything")
end

;(function()
	-- the TOC and the changelog
	local f = io.open("BagSmith/BagSmith.toc"); local toc = f:read("*a"); f:close()
	check(toc:find("Core\\Rules.lua\nCore\\ItemTree.lua\nCore\\Sections.lua\n", 1, true), "the TOC loads the ItemTree bridge with the rules")
	check(toc:find("## OptionalDeps: Pawn, Auctionator, Blackthornes_TS, ItemTree\n", 1, true), "and names ItemTree as optional, so it loads first when it's there")
	f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	local section = ("\n" .. log):match("\n(## 1%.10%.0\n.-)\n## 1%.9%.8\n") or ""
	check(section:find("With the ItemTree addon installed", 1, true) and section:find("Used by My Professions", 1, true) and section:find("ItemTree is optional, and BagSmith works the same without it.", 1, true), "the changelog's 1.10.0 section: ItemTree's rules, and that it's optional")
	check(not section:find("\226\128\148") and not section:find("\226\128\147"), "with no dashes")
end)()
