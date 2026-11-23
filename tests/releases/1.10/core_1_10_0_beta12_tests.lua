-- ======== 1.10.0-beta12 (Shweep, 22 Nov: "ready for audit version and please inlcude what's new in it") ========
-- The candidate sent for audit. Nothing in how the addon behaves changes from beta11; it gains what a release carries:
-- (1) the 1.10 What's New card, as Shweep reviewed it ("no need for bullet 5 crediting Ohnoto", "length is fine");
-- (2) 1.10's NEW tags in Settings (each release's list replaces the last one's);
-- (3) the READMEs' lines about rules, All Items' place and Addon Sources.

local function boot(opts)
	opts = opts or {}
	package.loaded.mock = nil
	local M = require("mock")
	M.removeEquipmentSets()
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Trade Goods", sub = "Cloth", price = 13 })
	_G.ItemTreeAPI = opts.itemtree and {
		version = 1, IsReady = function() return true end, RequestData = function() end,
		RegisterReadyCallback = function() end, RegisterChangeCallback = function() end, GetItemFacts = function() return nil end,
	} or nil
	_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = opts.skin or "modern", view = "list" } }, whatsNewSeen = opts.seen }
	if opts.fresh then _G.BagSmithDB = nil end
	local n = M.loadAddon("BagSmith")
	n.version = "1.10.0-beta12"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	return n, M
end

for _, skin in ipairs({ "modern", "classic" }) do
	-- the 1.10 card
	local S0 = skin .. ": "
	local n, M = boot({ skin = skin, seen = "1.9.8" })
	local WN = n.WhatsNew
	local e = WN.ENTRIES[1]
	check(e.v == "1.10.0" and e.heading == "BagSmith 1.10" and #e.items == 9 and not e.opens and not e.note, S0 .. "the 1.10 card leads, with nine bullets")
	local heads = {}
	for _, it in ipairs(e.items) do heads[#heads + 1] = it:match("^|cfffac775(.-):|r ") end
	check(table.concat(heads, "|") == "Sections That Fill Themselves|Start From an Item or an Example|A New Filters Window|Sections Only Where You Want Them|All Items, Where You Want It|Works With ItemTree|Addon Sources|Cleaner Classic Icons|Disenchant Helper and Junk",
		S0 .. "its bullets, as Shweep reviewed them: " .. table.concat(heads, "|"))
	local text = table.concat(e.items, " ")
	check(not text:find("\226\128\148") and not text:find("\226\128\147"), S0 .. "no em or en dashes")
	check(select(2, text:gsub("Thanks to Jeor!", "")) == 1 and not text:find("Ohnoto", 1, true), S0 .. "Jeor thanked for the Classic icons; no credit on the All Items bullet, as Shweep chose")
	check(e.items[5] == "|cfffac775All Items, Where You Want It:|r with Sections set to All, your pinned sections, Favorites and the rest can sit above or below All Items. Drag its title, or move it in Settings > Sections. Pin to Top is now called Pin Section.",
		S0 .. "the All Items bullet, word for word")
	check(e.items[1]:find("Give one a few rules, like Type is Cloth or Binding is Binds when equipped, and every item that fits goes there on its own.", 1, true)
		and e.items[1]:find("and whether it's food or drink, a quest item, a crafting material or something your character can use.", 1, true), S0 .. "the first bullet says what a rule is and what it can look at")
	check(e.items[6]:find("It's optional, and BagSmith works the same without it.", 1, true) and e.items[7]:find("Auction Price Source moved there from General.", 1, true)
		and e.items[9] == "|cfffac775Disenchant Helper and Junk:|r an item you've marked as junk no longer shows in the Disenchant Helper.", S0 .. "ItemTree is optional; where Auction Price Source went; the Disenchant Helper's change")
	-- every "Settings > ..." opens a real page
	local P = n.SettingsPanel
	local pages = {}
	for _, it in ipairs(e.items) do
		for key, heading in WN.Linkify(it):gmatch("|Hbagsmith:settings:([%w]+):([^|]*)|h") do
			pages[#pages + 1] = key
			P:Show(); P:ShowPage(key); M.runTimers()
			check(heading == "" and P.page == key, S0 .. "the link to " .. key .. " opens that page")
		end
	end
	P:Hide()
	check(table.concat(pages, ",") == "custom,custom,sections,addons", S0 .. "four links into Settings: Custom Sections twice, Sections, Addon Sources (" .. table.concat(pages, ",") .. ")")
	-- every setting and page the card names is really called that
	P:Show(); P:ShowPage("addons"); M.runTimers()
	local names = {}
	for _, b in ipairs(P.navButtons) do names[b.text.text] = true end
	check(names["Custom Sections"] and names["Sections"] and names["Addon Sources"], S0 .. "the pages it names exist under those names")
	P:Hide()
	-- an update from 1.9.8 shows it once, on the 1.10 tab
	WN:ShowLatest(); M.runTimers()
	local c = WN.Card()
	check(c and c:IsShown() and c.sel == 1 and c.entries[1].v == "1.10.0", S0 .. "it opens on 1.10")
	local tabs = {}
	for i, en in ipairs(c.entries) do tabs[i] = en.v end
	check(tabs[1] == "1.10.0" and #tabs <= 5, S0 .. "1.10 is the first of its tabs (" .. table.concat(tabs, ", ") .. ")")
	c:Hide()
	check((n.errors or 0) == 0, S0 .. "no errors")
end

;(function()
	-- the card by itself: after an update, once; never on a first install
	local n, M = boot({ seen = "1.9.8" })
	local WN = n.WhatsNew
	n.Window:Show(); M.runTimers(); M.runTimers()
	local c = WN.Card and WN.Card()
	check(c and c:IsShown() and c.entries[c.sel].v == "1.10.0", "coming from 1.9.8: the first time the bags open, the 1.10 card shows")
	if c then c:Hide() end
	n, M = boot({ fresh = true })
	WN = n.WhatsNew
	n.Window:Show(); M.runTimers(); M.runTimers()
	c = WN.Card and WN.Card()
	check(not (c and c:IsShown()), "a first install: no card")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- 1.10's NEW list (replacing 1.9's, as each release does)
	local n, M = boot({ seen = "1.9.8", itemtree = true })
	local P = n.SettingsPanel
	check(P.NEW.release == "1.10" and next(P.NEW.added) == nil, "the list is 1.10's, with no point release's additions yet")
	for _, key in ipairs({ "useItemTree", "makeRoomHoldItemTree", "deHoldItemTree", "makeRoomHoldPawn", "deHoldPawn" }) do
		check(P:IsNew("keys", key), key .. " is NEW")
	end
	check(P:IsNew("heads", "How an Item Finds Its Section") and P:IsNew("pages", "addons") and P:IsNew("pages", "custom") and P:IsNew("pages", "sections"), "so are Addon Sources, Custom Sections and its last card, and Sections")
	check(not P:IsNew("keys", "tipInventory") and not P:IsNew("keys", "borderWeight") and not P:IsNew("keys", "sectionValues") and not P:IsNew("pages", "general"), "1.9's aren't any more")
	check(not P:IsNew("keys", "priceSource"), "Auction Price Source only moved: it isn't NEW")
	P.page = "about"; P:Show()
	local function shownTags()
		local t = {}
		for _, b in ipairs(P.navButtons) do if b:IsShown() and b.newTag and b.newTag:IsShown() then t[#t + 1] = b.page end end
		table.sort(t)
		return t
	end
	local tags = shownTags()
	check(table.concat(tags, ",") == "addons,sections", "NEW beside Addon Sources and Sections in the list (" .. table.concat(tags, ",") .. ")")
	-- Addon Sources' name leaves room for its tag
	local b
	for _, nb in ipairs(P.navButtons) do if nb.page == "addons" then b = nb end end
	local tagX = select(4, b.newTag:GetPoint(1))
	if b.newTag.scaled then tagX = tagX * 0.65 end
	check(8 + 14 + 4 + b.text:GetStringWidth() + 6 <= tagX, "the tag sits clear of the name Addon Sources (" .. (8 + 14 + 4 + b.text:GetStringWidth()) .. " before " .. tostring(tagX) .. ")")
	-- on the page: ItemTree's three switches wear the tag (Pawn isn't installed here, so its rows aren't shown)
	P:ShowPage("addons"); M.runTimers()
	local tagged = {}
	for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.newTag and w.newTag:IsShown() then tagged[#tagged + 1] = w.key end end
	table.sort(tagged)
	check(table.concat(tagged, ",") == "deHoldItemTree,makeRoomHoldItemTree,useItemTree", "on the page, each ItemTree switch is tagged (" .. table.concat(tagged, ",") .. ")")
	-- Sections opens to show Custom Sections' tag under it, and that page's last card is tagged
	P:ShowPage("sections"); M.runTimers()
	check(table.concat(shownTags(), ","):find("custom", 1, true), "with Sections open, Custom Sections under it wears the tag too (" .. table.concat(shownTags(), ",") .. ")")
	P:ShowPage("custom"); M.runTimers()
	local headTag
	for _, h in ipairs(P.pools.head or {}) do if h:IsShown() and h.text.text == "How an Item Finds Its Section" then headTag = h.newTag and h.newTag:IsShown() end end
	check(headTag, "How an Item Finds Its Section wears the tag")
	-- seen once, the tags go the next time Settings opens
	P:Hide(); P.page = "about"; P:Show()
	tags = shownTags()
	check(#tags == 0, "the pages opened once: no tags the next time (" .. table.concat(tags, ",") .. ")")
	P:Hide()
	-- a first install: nothing is new to this player
	n, M = boot({ fresh = true, itemtree = true })
	P = n.SettingsPanel
	P.page = "about"; P:Show()
	tags = shownTags()
	check(#tags == 0, "a first install: no NEW tags")
	P:Hide()
	check((n.errors or 0) == 0, "no errors")
	_G.ItemTreeAPI = nil
end)()

;(function()
	-- the READMEs, the changelog, the version
	local f = io.open("BagSmith/README.md"); local readme = f:read("*a"); f:close()
	check(readme:find("binding, item level, vendor value, name, kind of consumable, quest item, crafting material, usable by you)", 1, true)
		and readme:find("All Items has its own place in Section Order", 1, true) and readme:find("- Addon Sources (Settings): what BagSmith does with other addons, each optional.", 1, true),
		"the addon's README: the rules, All Items' place, Addon Sources")
	f = io.open("README.md"); local top = f:read("*a"); f:close()
	check(top:find("sections of your own that you fill by hand or\n  with rules", 1, true) and top:find("**Works with other addons, none required:**", 1, true), "the repository's README: sections with rules, and the addons BagSmith works with")
	check(not readme:find("\226\128\148") and not top:find("\226\128\148"), "with no dashes")
	f = io.open("BagSmith/BagSmith.toc"); local toc = f:read("*a"); f:close()
	check(toc:find("## Version: 1.10.0", 1, true) and not toc:find("X-BagSmith-Dev", 1, true), "the TOC says 1.10.0 (the exact version is pinned in tests/run.lua) and carries no development marker")
	f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	check(log:find("^## 1%.10%.0\n") and log:find("\n## 1.9.8\n", 1, true), "the changelog leads with 1.10.0, then 1.9.8")
end)()
