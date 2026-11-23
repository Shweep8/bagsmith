-- ======== 1.10.0-beta10 (Shweep, 22 Nov: "Build w/ Beta 10") ========
-- (1) All Items in Section Order (a player's request, relayed 20 Nov: "I have 4 pinned sections. I want 3 above and 1
-- below All Items"; Shweep: "okay i'm good w/ what you suggest"). With Sections: All, each section beside All Items
-- shows above it or below it by its place in Section Order; on each side pinned sections still go first; Recent, when
-- it is first in the order, still takes the very top ("okay i'll follow ur reccomendation"). All Items' title drags.
-- (2) Pin to Top is Pin Section, Unpin is Unpin Section, and the lines that said "at the top" are reworded.
-- (3) Settings: Other Addons is Addon Sources ("can we call it Addon Sources"), its first line ends "None are
-- required.", and Plugins sits just above Advanced ("let's move plugins above advanced").

local DEFAULT_ORDER = "~recent,~fav,Gear,Consumables,Reagents,TradeGoods,Recipes,Quest,Tokens,Other,Junk,~all,~ky,~rb,~gs"
local OLD_ORDER = { "~recent", "~fav", "Gear", "Consumables", "Reagents", "TradeGoods", "Recipes", "Quest", "Tokens", "Other", "Junk", "~ky", "~rb", "~gs" }
local function copy(t) local c = {}; for i, v in ipairs(t) do c[i] = v end; return c end

-- opts: prof (profile fields), key (a key in the bags), sets (a gear set), skin
local function boot(opts)
	opts = opts or {}
	package.loaded.mock = nil
	local M = require("mock")
	if opts.sets then M.installEquipmentSets() else M.removeEquipmentSets() end
	M.sizes[0] = 16
	M.put(0, 1, { id = 101, guid = "g1", name = "Sword", q = 2, class = 2, subclass = 7, price = 100, equip = "INVTYPE_WEAPON", ilvl = 10 })
	M.put(0, 2, { id = 102, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 10 })
	M.put(0, 3, { id = 103, name = "Bread", q = 1, count = 5, class = 0, subclass = 5, type = "Consumable", sub = "Food & Drink", price = 5 })
	M.put(0, 4, { id = 104, guid = "g4", name = "Ring", q = 2, class = 4, subclass = 0, price = 50, equip = "INVTYPE_FINGER" })
	M.put(0, 5, { id = 106, name = "Grey Rag", q = 0, class = 15, subclass = 0, price = 1 })
	if opts.key then M.put(0, 6, { id = 105, name = "Old Key", q = 1, class = 13, subclass = 0, type = "Key", price = 0 }) end
	if opts.sets then M.addSet("Tank", { [11] = M.bagLoc(0, 4) }) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local p = { view = opts.view or "list", grp = "none", favSection = true, recentSection = false, skin = opts.skin or "modern", gearSetSections = opts.sets and true or nil,
		emptySlots = opts.empties and true or false }
	for k, v in pairs(opts.prof or {}) do p[k] = v end
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta10"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	return n, M, n.Window.main
end
local function lanes(n, M, main)
	n:RefreshViews(true); M.runTimers(); M.runTimers()
	local t = {}
	for i, id in ipairs(main.laneIds or {}) do t[i] = id == "" and "(list)" or id end
	return table.concat(t, " | ")
end
local function rec(n, id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
local function order(n) return table.concat(n.db.laneOrder, ",") end
local function move(n, id, before)   -- put id right before another id in Section Order
	local o = n.db.laneOrder
	table.remove(o, n.IndexOf(o, id))
	table.insert(o, before and n.IndexOf(o, before) or (#o + 1), id)
	n:Fire("SETTINGS_CHANGED", "laneOrder")
end
local function headers(n, v)
	local list = {}
	for _, h in pairs(n.Buttons.lanes[v.child] or {}) do if h:IsShown() and h.laneId then list[#list + 1] = h end end
	table.sort(list, function(a, b) local ya, yb = -a.points[1][5], -b.points[1][5]; if ya ~= yb then return ya < yb end return a.points[1][4] < b.points[1][4] end)
	return list
end
local function header(n, v, id) for _, h in ipairs(headers(n, v)) do if h.laneId == id then return h end end end

;(function()
	-- Section Order has All Items: a fresh profile, and where it joins an older one
	local n = boot()
	check(order(n) == DEFAULT_ORDER, "a fresh profile: All Items sits after your item sections, before Keys, Reagent Bag and Gear Sets (" .. order(n) .. ")")
	local S = n.Sections
	check(S:Label("~all") == "All Items" and not S:Pinnable("~all") and not S:CanTake("~all"), "it reads All Items, and it can't be pinned or take items")
	local targets = table.concat(S:Targets(), ",")
	check(not targets:find("~all", 1, true), "it isn't offered as a section to move items to")
	-- 1.9.8's usual order
	n = boot({ prof = { laneOrder = copy(OLD_ORDER) } })
	check(order(n) == DEFAULT_ORDER, "an older profile in the usual order: All Items joins right before Keys (" .. order(n) .. ")")
	-- again on the next login: it's there once
	local saved = copy(n.db.laneOrder)
	n = boot({ prof = { laneOrder = saved } })
	check(order(n) == DEFAULT_ORDER, "and it joins once")
	-- a dynamic section between the item sections: All Items goes right before it, so it still shows below
	n = boot({ prof = { laneOrder = { "~recent", "Gear", "~fav", "Consumables", "TradeGoods", "Junk", "~ky", "~gs" } } })
	check(order(n):find("^~recent,Gear,~all,~fav,Consumables,TradeGoods,Junk,~ky,~gs"), "Favorites moved down among the item sections: All Items joins right before it, so it stays below (" .. order(n) .. ")")
	-- ... unless a pinned section is further down: pinned sections were always above
	n = boot({ prof = { laneOrder = { "~recent", "Gear", "~fav", "Consumables", "TradeGoods", "Junk", "~ky", "~gs" }, pinnedSections = { TradeGoods = true } } })
	check(order(n):find("^~recent,Gear,~fav,Consumables,TradeGoods,~all,Junk,~ky,~gs"), "with a pinned section further down, All Items joins after it: pinned sections stay above (" .. order(n) .. ")")
	n = boot({ prof = { laneOrder = copy(OLD_ORDER), pinnedSections = { Junk = true, Gear = true } } })
	check(order(n) == DEFAULT_ORDER, "pinned sections among the item sections, the usual order: nothing else moves")
	-- no dynamic section after the items: at the end
	n = boot({ prof = { laneOrder = { "~recent", "~fav", "~ky", "~rb", "~gs", "Gear", "Consumables", "TradeGoods", "Junk" } } })
	check(order(n):find("^~recent,~fav,~ky,~rb,~gs,Gear,Consumables,TradeGoods,Junk,~all"), "every dynamic section ahead of the items: All Items joins after them all (" .. order(n) .. ")")
	-- an order that isn't a list at all is replaced by the usual one
	n = boot({ prof = { laneOrder = "bad" } })
	check(order(n) == DEFAULT_ORDER, "a broken order becomes the usual one, All Items included")
	-- a new section joins before Other; with no Other in the order, before All Items
	n = boot()
	local id = n.Sections:Create("Cloth")
	local o = n.db.laneOrder
	check(o[n.IndexOf(o, id) + 1] == "Other", "a new section joins Section Order just before Other")
	table.remove(o, n.IndexOf(o, "Other"))
	local id2 = n.Sections:Create("Herbs")
	check(o[n.IndexOf(o, id2) + 1] == "~all", "with no Other there, just before All Items, so pinning it puts it above")
	check((n.errors or 0) == 0, "no errors")
end)()

for _, view in ipairs({ "list", "icons" }) do
	-- Sections: All, section by section
	local V0 = view .. ": "
	local n, M, main = boot({ view = view, key = true, sets = true })
	local S = n.Sections
	check(lanes(n, M, main) == "~all | ~ky | ~gs:Tank", V0 .. "as it comes: All Items, then Keys and the gear set (" .. lanes(n, M, main) .. ")")
	n.Marks:ToggleFavorite(rec(n, 103))
	-- (by design: before, Favorites dropped below All Items whenever a Keys section showed, and Gear Sets jumped above it
	-- whenever there was a favorite)
	check(lanes(n, M, main) == "~fav | ~all | ~ky | ~gs:Tank", V0 .. "a favorite: Favorites above All Items, Keys and Gear Sets below, each by its place in Section Order (" .. lanes(n, M, main) .. ")")
	S:SetPinned("TradeGoods", true)
	check(lanes(n, M, main) == "TradeGoods | ~fav | ~all | ~ky | ~gs:Tank", V0 .. "a pinned section: above, ahead of Favorites (" .. lanes(n, M, main) .. ")")
	S:SetPinned("Gear", true)
	check(lanes(n, M, main) == "Gear | TradeGoods | ~fav | ~all | ~ky | ~gs:Tank", V0 .. "two pinned: in Section Order among themselves")
	-- one pinned section moved below All Items: what the player asked for
	move(n, "TradeGoods", "~ky")
	check(lanes(n, M, main) == "Gear | ~fav | ~all | TradeGoods | ~ky | ~gs:Tank", V0 .. "Trade Goods moved after All Items in Section Order: it shows below (" .. lanes(n, M, main) .. ")")
	-- on the lower side too, pinned sections go first
	move(n, "TradeGoods", nil)
	check(order(n):find("~gs,TradeGoods$") and lanes(n, M, main) == "Gear | ~fav | ~all | TradeGoods | ~ky | ~gs:Tank", V0 .. "even last in Section Order, a pinned section is first of those below All Items")
	-- its items are in its own section, not in All Items
	local inAll, inPin = 0, 0
	for _, r in ipairs((main:Filtered())) do if r.itemID == 102 then inAll = inAll + 1 end end
	check(inAll == 1, V0 .. "(the cloth is shown once)")
	-- Favorites below, Keys above
	move(n, "~fav", "~ky")
	check(lanes(n, M, main) == "Gear | ~all | TradeGoods | ~fav | ~ky | ~gs:Tank", V0 .. "Favorites moved after All Items: below it (" .. lanes(n, M, main) .. ")")
	move(n, "~ky", "~all")
	check(lanes(n, M, main) == "Gear | ~ky | ~all | TradeGoods | ~fav | ~gs:Tank", V0 .. "Keys moved before All Items: above it (" .. lanes(n, M, main) .. ")")
	move(n, "~gs", "~all")
	check(lanes(n, M, main) == "Gear | ~ky | ~gs:Tank | ~all | TradeGoods | ~fav", V0 .. "Gear Sets moved before All Items: above it (" .. lanes(n, M, main) .. ")")
	-- nothing pinned, only Keys above: the list still gets its title, or the two would run together
	S:SetPinned("TradeGoods", false); S:SetPinned("Gear", false)
	n.Marks:ToggleFavorite(rec(n, 103))
	move(n, "~gs", nil)
	check(lanes(n, M, main) == "~ky | ~all | ~gs:Tank", V0 .. "only Keys above: the list is titled All Items (" .. lanes(n, M, main) .. ")")
	local h = header(n, main, "~all")
	check(h and h.text and (h.text.text or ""):find("All Items", 1, true), V0 .. "with that title on its header")
	-- By Section and By Bag pass over All Items
	n:Set("grp", "type")
	local bySection = lanes(n, M, main)
	check(not bySection:find("~all", 1, true) and not bySection:find("(list)", 1, true) and bySection:find("Gear", 1, true), V0 .. "By Section: no All Items, the sections in their order (" .. bySection .. ")")
	S:SetPinned("Junk", true)
	check(lanes(n, M, main):find("^Junk | "), V0 .. "By Section: a pinned section still goes first, wherever All Items is in the order")
	S:SetPinned("Junk", false)
	n:Set("grp", "bag")
	check(not lanes(n, M, main):find("~all", 1, true), V0 .. "By Bag: no All Items either")
	n:Set("grp", "none")
	check((n.errors or 0) == 0, V0 .. "no errors")
end

;(function()
	-- Icons view with empty slots showing: once All Items has its title, the empty slots have a list of their own after
	-- the items. It stays last, and it isn't a second All Items.
	local n, M, main = boot({ view = "icons", empties = true, key = true })
	n.Sections:SetPinned("TradeGoods", true)
	n.Marks:ToggleFavorite(rec(n, 103))
	local got = lanes(n, M, main)
	local function titles() local c = 0; for _, h in ipairs(headers(n, main)) do if (h.text.text or ""):find("All Items", 1, true) then c = c + 1 end end; return c end
	local _, alls = got:gsub("~all", "")
	check(got:find("^TradeGoods | ~fav | ~all | ~ky") and alls == 1 and titles() == 1, "Icons with empty slots: one All Items, with one title (" .. got .. ")")
	move(n, "TradeGoods", "~ky")
	got = lanes(n, M, main)
	_, alls = got:gsub("~all", "")
	check(got:find("^~fav | ~all | TradeGoods | ~ky") and alls == 1 and titles() == 1, "with a pinned section below All Items too (" .. got .. ")")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- Recent: first in Section Order, the very top, as before; anywhere else, by its place
	local n, M, main = boot({ prof = { recentSection = true } })
	local now = time()
	n.cdb.recentSince = now - 100; n.cdb.firstSeen[M.bags[0][1].guid] = now - 10; n:Scan()
	local S = n.Sections
	S:SetPinned("TradeGoods", true)
	n.Marks:ToggleFavorite(rec(n, 103))
	local got = lanes(n, M, main)
	if got:find("~recent", 1, true) then
		check(got == "~recent | TradeGoods | ~fav | ~all", "Recent first in Section Order: the very top, above a pinned section (" .. got .. ")")
		move(n, "~recent", "Gear")
		check(lanes(n, M, main) == "TradeGoods | ~fav | ~recent | ~all", "Recent second: above All Items, after the pinned section, in its place after Favorites (" .. lanes(n, M, main) .. ")")
		move(n, "~recent", "~ky")
		check(lanes(n, M, main) == "TradeGoods | ~fav | ~all | ~recent", "Recent after All Items: below it (" .. lanes(n, M, main) .. ")")
	else
		check(false, "(setup) Recent should be showing: " .. got)
	end
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- an empty pinned section of your own shows on its side too; one that isn't in Section Order stays above
	local n, M, main = boot()
	local S = n.Sections
	local id = S:Create("Herbs")
	S:SetPinned(id, true)
	check(lanes(n, M, main) == id .. " | ~all", "an empty pinned section of your own: above All Items")
	move(n, id, "~ky")
	check(lanes(n, M, main) == "~all | " .. id, "moved after All Items: below it")
	S:SetPinned(id, false)
	-- Junk left out of Section Order by an old profile, and pinned
	local o = n.db.laneOrder
	table.remove(o, n.IndexOf(o, "Junk"))
	S:SetPinned("Junk", true)
	check(lanes(n, M, main) == "Junk | ~all", "a pinned section with no place in Section Order: above All Items, as pinned sections always were (" .. lanes(n, M, main) .. ")")
	check((n.errors or 0) == 0, "no errors")
end)()

for _, skin in ipairs({ "modern", "classic" }) do
	-- All Items' title drags, and a section can be dropped on it
	local S0 = skin .. ": "
	local n, M, main = boot({ skin = skin })
	local S = n.Sections
	S:SetPinned("TradeGoods", true); S:SetPinned("Gear", true)
	n.Marks:ToggleFavorite(rec(n, 103))
	check(lanes(n, M, main) == "Gear | TradeGoods | ~fav | ~all", S0 .. "(two pinned sections and Favorites, above All Items)")
	local realUnder = n.FrameUnderCursor
	local function drag(from, to)
		local h = header(n, main, from)
		n.FrameUnderCursor = function() return to end
		h:GetScript("OnDragStart")(h)
		local started = n.dragLane
		h:GetScript("OnDragStop")(h)
		n.FrameUnderCursor = realUnder
		M.runTimers()
		return started
	end
	check(drag("TradeGoods", "~all") == "TradeGoods" and lanes(n, M, main) == "Gear | ~fav | ~all | TradeGoods", S0 .. "a pinned section's title dropped on All Items: it moves to the other side (" .. lanes(n, M, main) .. ")")
	check(drag("TradeGoods", "~all") == "TradeGoods" and lanes(n, M, main) == "Gear | TradeGoods | ~fav | ~all", S0 .. "and back again")
	check(drag("~all", "~fav") == "~all" and lanes(n, M, main) == "Gear | TradeGoods | ~all | ~fav", S0 .. "All Items' own title drags: dropped on Favorites, it goes above it, and the pinned sections stay where they were (" .. lanes(n, M, main) .. ")")
	check(n.IndexOf(n.db.laneOrder, "Gear") < n.IndexOf(n.db.laneOrder, "~all") and n.IndexOf(n.db.laneOrder, "Consumables") < n.IndexOf(n.db.laneOrder, "~all"),
		S0 .. "in Section Order only Favorites changed sides: the sections not on screen didn't move")
	check(drag("~all", "~fav") == "~all" and lanes(n, M, main) == "Gear | TradeGoods | ~fav | ~all", S0 .. "and back")
	check(drag("~all", "Gear") == "~all" and lanes(n, M, main) == "~all | Gear | TradeGoods | ~fav", S0 .. "dropped on the top section: everything it passed is below it now, pinned first (" .. lanes(n, M, main) .. ")")
	check(drag("~all", "TradeGoods") == "~all" and lanes(n, M, main) == "Gear | TradeGoods | ~all | ~fav", S0 .. "dropped on the second one down: the two it passed are above again (" .. lanes(n, M, main) .. ")")
	check(drag("~all", "~fav") == "~all" and lanes(n, M, main) == "Gear | TradeGoods | ~fav | ~all", S0 .. "(and Favorites above again)")
	-- All Items has no menu of its own, as before
	local menu
	local realMenu = n.ShowMenu
	n.ShowMenu = function(items) menu = items end
	S:SectionMenu("~all", header(n, main, "~all"))
	check(menu == nil, S0 .. "All Items' title has no menu, as before")
	-- Pin Section / Unpin Section
	S:SectionMenu("Consumables", header(n, main, "~all"))
	local pin
	for _, item in ipairs(menu or {}) do if item.text == "Pin Section" then pin = item end end
	check(pin and pin.tip == "Shown ahead of your other sections, after Recent. In All view its items get their own section, above or below All Items by its place in Section Order.", S0 .. "a section's menu: Pin Section, with what it does (" .. tostring(pin and pin.tip) .. ")")
	menu = nil
	S:SectionMenu("TradeGoods", header(n, main, "TradeGoods"))
	local unpin
	for _, item in ipairs(menu or {}) do if item.text == "Unpin Section" then unpin = item end end
	check(unpin and unpin.tip == "Back to its usual place.", S0 .. "a pinned section's menu: Unpin Section")
	local old = false
	for _, item in ipairs(menu or {}) do if item.text == "Pin to Top" or item.text == "Unpin" then old = true end end
	check(not old, S0 .. "Pin to Top and Unpin are gone")
	unpin.onClick(); M.runTimers()
	check(not S:Pinned("TradeGoods") and lanes(n, M, main) == "Gear | ~fav | ~all", S0 .. "Unpin Section: its items are back in All Items")
	n.ShowMenu = realMenu

	-- Settings > Sections: All Items in the list, and the words about pins
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("sections"); M.runTimers()
	local txt = {}
	for _, w in ipairs(P.pools.text or {}) do if w:IsShown() then txt[#txt + 1] = w.text.text end end
	local all = table.concat(txt, "\n")
	check(all:find("Pin shows a section ahead of your other sections, just under Recent. You can also pin one by right-clicking its title. By Bag ignores pins.", 1, true)
		and all:find("All Items is the list you see with Sections: All. There, a pinned or dynamic section shows above it or below it by its place in this list.", 1, true)
		and not all:find("at the top", 1, true), S0 .. "Settings > Sections says what Pin does, and what All Items' place is for")
	local row, before, after
	for _, l in ipairs(P.pools.list or {}) do
		if l:IsShown() then
			local shown = {}
			for _, r in ipairs(l.rows) do if r:IsShown() then shown[#shown + 1] = r end end
			for i, r in ipairs(shown) do if r.id == "~all" then row, before, after = r, shown[i - 1], shown[i + 1] end end
		end
	end
	-- (the drags above left Favorites right before All Items in Section Order)
	local o = n.db.laneOrder
	local at = n.IndexOf(o, "~all")
	check(row and row.text.text == "All Items" and before and before.id == o[at - 1] and after and after.id == o[at + 1], S0 .. "the list has All Items, in its place in Section Order (after " .. tostring(before and before.id) .. ")")
	check(row and row.tip == "With Sections: All, the sections above this one in the list show above All Items, and the ones below it show below. By Section and By Bag pass over it.", S0 .. "and pointing at it says what its place does")
	local boxes = 0
	for _, c in ipairs(row and row.cols or {}) do if c:IsShown() then boxes = boxes + 1 end end
	check(row and boxes == 0, S0 .. "it has no Pin, Vendor or AH box: there's nothing to pin or hide")
	P:Hide()

	-- the page list: Addon Sources, and Plugins just above Advanced
	local names = {}
	for i, b in ipairs(P.navButtons) do if not b.parent then names[#names + 1] = b.text.text end end
	check(table.concat(names, "|") == "General|Style|Item Icons|Windows|Sections|Columns|Sheets|Sorting & Filters|Automations|Keybindings|Addon Sources|Profile|Plugins|Advanced",
		S0 .. "Settings' pages: Addon Sources after Keybindings, Plugins just above Advanced (" .. table.concat(names, "|") .. ")")
	P:Show(); P:ShowPage("addons"); M.runTimers()
	txt = {}
	for _, w in ipairs(P.pools.text or {}) do if w:IsShown() then txt[#txt + 1] = w.text.text end end
	check(txt[1] == "BagSmith works with these addons when you have them. None are required." or table.concat(txt, "\n"):find("BagSmith works with these addons when you have them. None are required.", 1, true), S0 .. "the page's first line: None are required.")
	check(not table.concat(txt, "\n"):find("None is needed", 1, true), S0 .. "not: None is needed")
	-- its name beside a NEW tag: room to spare
	local b
	for _, nb in ipairs(P.navButtons) do if nb.page == "addons" then b = nb end end
	P.NewTag(b, true, b, 0)
	local tagW = P.NewTagWidth(b.newTag)
	local textEnd = 8 + 14 + 4 + b.text:GetStringWidth()
	check(b.text.text == "Addon Sources" and textEnd + 6 <= (170 - 10) - tagW, S0 .. "Addon Sources leaves room for a NEW tag (" .. textEnd .. " + 6 against " .. ((170 - 10) - tagW) .. ")")
	P.NewTag(b, false)
	P:ShowPage("loothelper"); M.runTimers()
	txt = {}
	for _, w in ipairs(P.pools.text or {}) do if w:IsShown() then txt[#txt + 1] = w.text.text end end
	check(table.concat(txt, "\n"):find("Settings > Addon Sources sets what Pawn and ItemTree hold back.", 1, true), S0 .. "Settings > Loot Helper points at Addon Sources")
	P:Hide()
	check((n.errors or 0) == 0, S0 .. "no errors")
end

;(function()
	-- the words in the files, and the changelog
	local f = io.open("BagSmith/Frames/SectionsUI.lua"); local src = f:read("*a"); f:close()
	check(not src:find("\"Pin to Top\"", 1, true) and not src:find("stays at the top", 1, true) and select(2, src:gsub("stays in a pinned section: its own section, %%s, is pinned too%.", "")) == 2,
		"the two chat lines say a pinned section, not the top")
	f = io.open("BagSmith/Frames/WhatsNew.lua"); local wn = f:read("*a"); f:close()
	check(wn:find("choose Pin to Top. It stays at the top, just under Recent", 1, true), "What's New's 1.4 entry is left as it was written")
	check(wn:find("pick one in Settings > Addon Sources > Auction Prices.", 1, true) and wn:find("|cfffac775Marks from Other Addons:|r", 1, true), "its line about price addons points at Addon Sources; the older entry about marks from other addons is untouched")
	f = io.open("BagSmith/Frames/SettingsPanel.lua"); src = f:read("*a"); f:close()
	local _, tips = src:gsub("Auction Price Source is in Settings > Addon Sources%.", "")
	check(tips == 2 and not src:find("Settings > Other Addons", 1, true), "the AH Price column's tips point at Addon Sources")
	f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	local section = ("\n" .. log):match("\n(## 1%.10%.0\n.-)\n## 1%.9%.8\n") or ""
	check(section:find("All Items is part of Section Order.", 1, true) and section:find("Pin to Top is now Pin Section, and Unpin is Unpin Section.", 1, true), "the changelog's 1.10.0 section: All Items in Section Order, Pin Section")
	check(section:find("Favorites no longer drops below All Items when a Keys section is showing", 1, true) and section:find("Settings: Plugins moved down the list, just above Advanced.", 1, true), "what changed for Favorites and Gear Sets in All view, and Plugins' new place")
	check(section:find("A new Settings page, Addon Sources,", 1, true) and not section:find("Other Addons", 1, true), "and the page by its new name")
	check(not section:find("\226\128\148") and not section:find("\226\128\147"), "with no dashes")
end)()
