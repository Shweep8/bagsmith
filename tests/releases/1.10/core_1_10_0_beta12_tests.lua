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
	local e = WN.ENTRIES[2]   -- (by design since 1.10.1: one more place down, after 1.10.1's entry)
	-- (by design since 1.10.0-beta16, Shweep, 23 Nov: "our what's new card is not player friendly, it's more technical
	-- than sells the new features"; on the rewrite: "rest looks better tho, ty". Seven bullets that lead with what the
	-- player gets, where there were nine that read like a list of features. The checks below follow the new text.)
	check(e.v == "1.10.0" and e.heading == "BagSmith 1.10" and #e.items == 7 and not e.opens and not e.note, S0 .. "the 1.10 card leads, with seven bullets")
	local heads = {}
	for _, it in ipairs(e.items) do heads[#heads + 1] = it:match("^|cfffac775(.-):|r ") end
	check(table.concat(heads, "|") == "Sections That Sort Themselves|Start in One Click|Simpler Filters|Tabs Your Way|All Items, Where You Want It|Friends With Your Other Addons|A Cleaner Classic Look",
		S0 .. "its bullets, as Shweep approved them: " .. table.concat(heads, "|"))
	local text = table.concat(e.items, " ")
	check(not text:find("\226\128\148") and not text:find("\226\128\147"), S0 .. "no em or en dashes")
	check(select(2, text:gsub("Thanks to Jeor!", "")) == 1 and not text:find("Ohnoto", 1, true), S0 .. "Jeor thanked for the Classic icons; no credit on the All Items bullet, as Shweep chose")
	check(e.items[5] == "|cfffac775All Items, Where You Want It:|r using Sections: All? Drag the All Items title to put your pinned sections and Favorites above or below it. Pin to Top is now called Pin Section.",
		S0 .. "the All Items bullet, word for word")
	check(e.items[1] == "|cfffac775Sections That Sort Themselves:|r done dragging every new item to the right spot? Tell a section what belongs in it, like cloth, or gear that binds when equipped, and your loot files itself from then on. Click the pencil beside a section in Settings > Custom Sections. You'll see what lands there before you save.",
		S0 .. "the first bullet leads with what the player gets, word for word")
	check(e.items[6]:find("All of it is optional.", 1, true) and e.items[6]:find("Auction Price Source moved there too.", 1, true)
		and e.items[6]:find("won't offer what it says to keep, apart from your junk and gear it keeps for its dust.", 1, true)
		and e.items[7] == "|cfffac775A Cleaner Classic Look:|r sharper item icons and borders in the Classic skin. Thanks to Jeor!", S0 .. "the addons bullet: optional, where Auction Price Source went, the Helpers with their two exceptions; and the Classic bullet")
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
	check(table.concat(pages, ",") == "custom,custom,addons", S0 .. "three links into Settings: Custom Sections twice, Addon Sources (" .. table.concat(pages, ",") .. ")")
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
	-- (by design since 1.10.1-beta2: 1.10.1 adds one setting, Auto-Close Bags I Opened; 1.10.0's own list is as it was)
	local added = 0
	for _ in pairs(P.NEW.added) do added = added + 1 end
	check(P.NEW.release == "1.10" and added == 1 and P.NEW.added["1.10.1"] and P.NEW.added["1.10.1"].keys.autoCloseOwnBags == "general", "the list is 1.10's, with 1.10.1's one addition")
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
	check(toc:find("## Version: %d+%.%d+%.%d+") and not toc:find("X-BagSmith-Dev", 1, true), "the TOC has a version (by design since 1.11.0: later releases too; the exact one is pinned in tests/run.lua) and carries no development marker")
	f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	-- (by design since 1.10.1: its patch's section comes first)
	check(log:find("\n## 1.10.0\n", 1, true) and log:find("\n## 1.9.8\n", 1, true) and log:find("\n## 1.10.0\n", 1, true) < log:find("\n## 1.9.8\n", 1, true), "the changelog has 1.10.0, then 1.9.8")
end)()
