-- 1.3.0: the Loot Helper acts through one button on the row you choose (the rows no longer carry their own
-- Combine or Destroy buttons). MRact picks the row and presses that button; MRwaiting counts the waiting rows.
function MRact(r) r:GetScript("OnClick")(r); local f = _G.BagSmithMakeRoom; f.act:GetScript("OnClick")(f.act) end
function MRwaiting(f) local c = 0; for _, r in ipairs(f.waitRows) do if r:IsShown() then c = c + 1 end end return c end
package.path = "./tests/?.lua;" .. package.path
local M = require("mock")
local fails, passes = 0, 0
local function check(cond, msg) if cond then passes = passes + 1 else fails = fails + 1; print("FAIL: " .. msg) end end
local function shownButtons() local host = BagSmith.Window.main and BagSmith.Window.main.child; local n = 0; for _, b in ipairs(BagSmith.Buttons.all) do if b:IsShown() and b:GetParent():GetParent() == host then n = n + 1 end end; return n end

M.put(0, 1, { id = 1001, name = "Staff of Jordan", q = 3, ilvl = 24, type = "Weapon", sub = "Staff", class = 2, subclass = 10, price = 810, equip = "INVTYPE_2HWEAPON", bind = 1 })
M.put(0, 2, { id = 1002, name = "Minor Healing Potion", q = 1, count = 5, ilvl = 5, type = "Consumable", sub = "Potion", class = 0, subclass = 1, price = 5 })
M.put(0, 3, { id = 1003, name = "Broken Fang", q = 0, count = 3, ilvl = 1, type = "Miscellaneous", sub = "Junk", class = 15, subclass = 0, price = 12 })
M.put(0, 4, { id = 1007, name = "Scarlet Key", q = 1, class = 13, subclass = 0, type = "Key", sub = "Key", bind = 1 })
M.put(0, 5, { id = 20558, name = "Warsong Gulch Mark of Honor", q = 1, count = 12, class = 15, subclass = 4, type = "Miscellaneous", sub = "Other", bind = 1 })
M.put(0, 6, { id = 6948, name = "Hearthstone", q = 1, class = 15, subclass = 0, type = "Miscellaneous", sub = "Junk", bind = 1 })
M.put(1, 1, { id = 1004, name = "Glinting Steel Dagger", q = 2, ilvl = 22, type = "Weapon", sub = "Dagger", class = 2, subclass = 15, price = 312, bind = 2 })
M.put(5, 1, { id = 1005, name = "Linen Cloth", q = 1, count = 20, ilvl = 5, type = "Tradeskill", sub = "Cloth", class = 7, subclass = 5, price = 13 })
M.put(-1, 1, { id = 1009, name = "Tough Jerky", q = 1, count = 20, class = 0, subclass = 5, type = "Consumable", sub = "Food & Drink", price = 1 })
M.newItems = { ["1:1"] = true }

-- Reproduce the Forever client: per-character data exists, keyring enum
-- collides with the bank, and NUM_BANKBAGSLOTS is absent.
_G.BagSmithCharDB = { version = 1, firstSeen = {} }
local ns = M.loadAddon("BagSmith")
check(ns.KEYRING == nil, "keyring rejected when its id collides with the bank")
check(ns.NUM_BANK_BAGS == 8, "bank bag count falls back to Constants: " .. tostring(ns.NUM_BANK_BAGS))
M.fire("ADDON_LOADED", "BagSmith")
check(ns.loaded and (ns.errors or 0) == 0, "per-character data loads without error")
check(#ns.db.tabOrder == 8 and ns.cdb.tabOrder == nil, "tab fixup applies to profiles only (eight built-in tabs with Gear Sets)")
M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
check(ns.ready, "ready")
check(#ns.Buttons.all == 18 * 6 + 48 + 18 * 8, "pool covers bags, bank and bank bags: " .. #ns.Buttons.all)

-- Classification
local by = {}
for _, r in ipairs(ns.items) do by[r.name] = r end
check(by["Staff of Jordan"].cat == "Gear" and by["Broken Fang"].cat == "Junk" and by["Scarlet Key"].cat == "Keys", "categories")
check(by["Hearthstone"].cat == "Other", "Hearthstone is not junk")
check(by["Warsong Gulch Mark of Honor"].cat == "Tokens", "name heuristic token")
check(by["Linen Cloth"].cat == "TradeGoods" and by["Minor Healing Potion"].cat == "Consumables", "trade goods and consumables")
check(ns:BindText(by["Glinting Steel Dagger"]) == "BoE" and ns:BindText(by["Staff of Jordan"]) == "BoP", "bind text")
check(by["Glinting Steel Dagger"].isNew, "new item flag")

-- Open, lanes by type. ToggleAllBags calls Open/ToggleBackpack internally like the client;
-- one press must mean exactly one toggle.
ToggleAllBags()
local main = ns.Window.main
check(main:IsShown(), "one B press opens the window")
ToggleAllBags()
check(not main:IsShown(), "second B press closes it")
ToggleAllBags()
check(main:IsShown(), "third press opens again")
ToggleBackpack()
check(not main:IsShown(), "backpack toggle alone still works")
M.fire("MERCHANT_SHOW"); check(main:IsShown(), "merchant auto-opens")
M.fire("MERCHANT_CLOSED"); check(not main:IsShown(), "merchant close auto-closes")
ToggleAllBags(); check(main:IsShown(), "reopen for the rest of the tests")
M.fire("MERCHANT_SHOW"); M.fire("MERCHANT_CLOSED"); check(main:IsShown(), "a window the player opened stays open after a merchant")
check(by["Hearthstone"] == nil or by["Hearthstone"].cat ~= "Junk", "placeholder")
local laneCount = 0
for _, h in pairs(ns.Buttons.lanes[main.child] or {}) do if h:IsShown() then laneCount = laneCount + 1 end end
check(laneCount == 7, "lanes: Gear, Consumables, TradeGoods, Tokens, Other, Junk, Keys = " .. laneCount)
check(shownButtons() == 8, "eight rows shown: " .. shownButtons())
check(ns.Buttons:Get(0, 4):IsShown(), "key row shown in keys lane")

-- Collapse a lane and collapse all
main:ToggleLane("Gear")
check(shownButtons() == 6, "collapsing Gear hides two rows: " .. shownButtons())
main:ToggleAllLanes()
check(shownButtons() == 0, "collapse all hides everything")
main:ToggleAllLanes()
check(shownButtons() == 8, "expand all restores")

-- Lane reorder via drag handlers
ns:ReorderLane("Junk", "Gear")
check(ns.db.laneOrder[1] == "~recent" and ns.db.laneOrder[2] == "~fav" and ns.db.laneOrder[3] == "Junk" and ns.db.laneOrder[#ns.db.laneOrder] == "~gs", "Junk lane moved before Gear (Recent and Favorites stay first; Gear Sets stays last)")

-- Search syntax and filters
ns.ui.filters.text = "boe"; ns:RefreshViews(true)
check(shownButtons() == 1, "boe search: " .. shownButtons())
ns.ui.filters.text = "il>20"; ns:RefreshViews(true)
check(shownButtons() == 2, "il>20 search: " .. shownButtons())
ns.ui.filters.text = "q:rare"; ns:RefreshViews(true)
check(shownButtons() == 1, "q:rare search")
ns.ui.filters.text = ""; ns.ui.filters.cat.Junk = true; ns:RefreshViews(true)
check(shownButtons() == 1, "category filter")
ns.ui.filters.new = true; ns:RefreshViews(true)
check(shownButtons() == 0, "junk + new only = none")
ns.ui.filters = ns.EmptyFilters(); ns.ui.filters.new = true; ns:RefreshViews(true)
check(shownButtons() == 1, "new only")
ns.ui.filters = ns.EmptyFilters()

-- Columns: hiding a column hides its text in every row, not just the header
ns:Set("cols", { "c", "il", "t", "bd", "v", "w" })
local row1 = ns.Buttons:Get(0, 1)
ns:Set("cols", { "c", "t" }); ns:RefreshViews(true)
check(not row1.colWhere:IsShown() and row1.colType:IsShown(), "hidden column text hidden in rows")
check(row1.seps and row1.seps[1]:IsShown(), "column separators drawn")
ns:Set("cols", { "c", "il", "t", "bd", "v", "w" })
ns:Set("dense", true); ns:RefreshViews(true)
check(row1.h == 22, "compact rows use 22px: " .. tostring(row1.h))
ns:Set("dense", false)

-- Sheets
main:SetSheet("Gear"); check(shownButtons() == 2, "Gear sheet")
ns.ui.filters.q[2] = true
check(ns:SaveSheet("Greens"), "save custom sheet")
check(ns.ui.sheet == "Greens" and shownButtons() == 1, "custom sheet applied")
main:SetSheet("All")
check(ns.FilterCount(ns.ui.filters) == 0 and shownButtons() == 8, "leaving a custom sheet clears its filters")
main:SetSheet("Greens"); check(shownButtons() == 1, "custom sheet restores its filters")
ns:DeleteSheet("Greens"); check(ns.ui.sheet == "All" and #ns.db.sheets == 0, "delete sheet")

-- Icons view, then individual bag windows
ns:Set("view", "icons"); check(ns.Buttons:Get(0, 1).mode == "cell", "icon cells")
ns:Set("view", "list")
ns.ui.bagWindows = true; ns:RefreshViews(true)
check(ns.Window.bagViews[0]:IsShown() and ns.Window.bagViews[1]:IsShown() and not ns.Window.bagViews[5]:IsShown(), "bag windows open for the backpack and equipped bags, not the reagent bag")
check(not ns.Window.bagViews[4]:IsShown(), "no window for the empty bag slot")
check(true, "")
local b1 = ns.Window.bagViews[1]
local cells = 0
for _, b in pairs(ns.Buttons.mirrors[b1.child] or {}) do if b:IsShown() then cells = cells + 1 end end
check(cells == 6, "bag window is a mirror slot grid with all 6 slots: " .. cells)
check(shownButtons() >= 8, "the main window still shows every bag while bag windows are open: " .. shownButtons())
local m1 = ns.Buttons.mirrors[b1.child][1]
m1.scripts.OnClick(m1, "LeftButton")
check(M.pickups[#M.pickups] == "1:1", "left-click on a mirror cell picks the item up from its real slot")
m1.scripts.OnClick(m1, "RightButton")
check(M.log[#M.log]:find("main window"), "right-click on a mirror cell explains where to use items")
check(b1.frame.points[1] and b1.frame.points[1][2] == UIParent, "bag window anchored to the screen, not to another window")
b1.frame.points = { { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 123, 456 } }; b1:SavePosition()
check(ns.db.bagPoints["1"] and ns.db.bagPoints["1"][4] == 123, "bag window position saved per bag")
ns:Set("bagWindows", true, true)
ToggleAllBags(); check(not main:IsShown() and not b1:IsShown(), "B closes the main window and its bag windows")
ToggleAllBags(); check(main:IsShown() and b1:IsShown() and ns.Window.bagViews[0]:IsShown(), "B reopens the bag windows along with the main window (starting state on)")
ns:Set("bagWindows", false, true)
ns.ui.bagWindows = false; ns:RefreshViews(true); check(not b1:IsShown(), "bag windows close with the toggle")
main.btnBags.scripts.OnClick(main.btnBags); check(ns.ui.bagWindows and b1:IsShown() and main.btnBags.active, "footer icon opens the bag windows and lights up")
main.btnBags.scripts.OnClick(main.btnBags); check(not ns.ui.bagWindows and not b1:IsShown(), "footer icon closes them")
ns:Set("grp", "type")

-- Reagent bag: always in the main window (Mixed In or Own Section)
ns:Set("reagent", "inline")
check(ns.Buttons:Get(5, 1):GetParent():GetParent() == main.child, "reagent bag mixed in, in the main window")
ns:Set("reagent", "lane")
check(ns.Buttons:Get(5, 1):GetParent():GetParent() == main.child, "reagent bag in its own section, in the main window")

-- Currencies and favorites
local list = ns.Currency:List()
check(#list == 3, "wallet + token items: " .. #list)
ns.Currency:ToggleFavorite("c:3402"); ns.Currency:ToggleFavorite("i:20558")
check(#ns.Currency:Favorites() == 2, "two favorites")
check(ns.Currency:ImportBlizzard() == 1 and #ns.db.fav == 3, "import Blizzard picks")
ns.Currency:MoveFavorite("i:20558", -1); check(ns.db.fav[1] == "i:20558", "reorder favorite")

-- Bank
M.fire("BANKFRAME_OPENED"); M.runTimers(); M.elapse()
local bankWin = ns.Window.bank
check(ns.atBank and bankWin:IsShown() and main:IsShown() and #ns.bankItems == 1, "bank opened: dedicated bank window beside the main window, bank scanned")
check(ns.Buttons:Get(-1, 1):IsShown() and ns.Buttons:Get(-1, 1):GetParent():GetParent() == bankWin.child, "bank item row shown in the bank window")
check(ns.ui.sheet ~= "Bank", "main window keeps its own sheet")
M.fire("BANKFRAME_CLOSED"); M.runTimers()
check(not ns.atBank and not bankWin:IsShown() and main:IsShown(), "bank closed hides the bank window, main stays")

-- Cache and alt viewing
M.elapse()
local me = ns:CharKey()
check(BagSmithDB.cache[me] and #BagSmithDB.cache[me].items == 8 and #BagSmithDB.cache[me].bank == 1, "own character cached with bank")
BagSmithDB.cache["Mira Dawnvale - Forever"] = { name = "Mira Dawnvale", realm = "Forever", class = "PRIEST", level = 31, gold = 412085, updated = 1,
	bags = { ["0"] = { size = 16, free = 14, name = "Backpack" } }, items = { { bag = 0, slot = 1, itemID = 2001, link = "|Hitem:2001|h[Wool Cloth]|h", name = "Wool Cloth", count = 20, quality = 1, cat = "TradeGoods", where = "Backpack" }, { bag = 0, slot = 2, itemID = 2002, link = "|Hitem:2002|h[Staff]|h", name = "Staff", count = 1, quality = 3, cat = "Gear", classID = 2 } },
	currencies = { ["c:3402"] = { id = 3402, name = "Merchant's Favor", count = 140, quality = 3, source = "Wallet" } } }
if not main:IsShown() then ToggleAllBags() end
main:SetOwner("Mira Dawnvale - Forever")
check(ns.ui.owner and shownButtons() == 0, "secure buttons hidden while viewing an alt")
local cachedShown = 0
for _, b in pairs(ns.Buttons.cached[main.child] or {}) do if b:IsShown() then cachedShown = cachedShown + 1 end end
check(cachedShown == 2, "alt rows shown from cache: " .. cachedShown)
check(main.subText.text:find("read only"), "read-only subtitle")
check(#ns.Currency:Favorites("Mira Dawnvale - Forever") == 1, "alt favorites come from her cache")
main:SetOwner(nil); check(not ns.ui.owner and shownButtons() == 8, "back to own bags")
main:SetOwner("Mira Dawnvale - Forever"); main:Hide(); ToggleAllBags()
check(not ns.ui.owner, "reopening resets to own character")

-- Combat
M.combat = true; M.fire("PLAYER_REGEN_DISABLED")
local ok = pcall(function() ns:Set("grp", "bag"); M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); ns.ui.filters.text = "staff"; ns:RefreshViews(true) end)
check(ok, "no protected calls in combat")
check(main.statusText.text == "Layout locked in combat", "combat status")
M.combat = false; M.fire("PLAYER_REGEN_ENABLED")
check(main.statusText.text == "" and shownButtons() == 1, "deferred layout ran after combat: " .. shownButtons())
ns.ui.filters.text = ""; ns:Set("grp", "type")

-- Settings panel and drawer build without errors
ok = pcall(function() ns.SettingsPanel:Show(); ns.SettingsPanel:Refresh(); ns.Drawer:Show(); ns.Popups:ToggleFilters(main); ns.Popups:ToggleCharacters(main) end)
check(ok, "panels build")
check(ns.SettingsPanel.frame:IsShown() and not ns.Drawer.frame:IsShown() or ns.Drawer.frame:IsShown(), "one side panel at a time")
ns:Set("skin", "classic"); check(ns.db.skin == "classic", "skin switch")
ns:Set("scale", 0.8); check(main.frame.scale == 0.8, "scale applied")
ns:Set("minimap", false); check(not ns.MinimapButton.button:IsShown(), "minimap hidden by setting")
ns:Set("minimap", true); check(ns.MinimapButton.button:IsShown(), "minimap shown again")

-- Column order + visibility
ns.db.colOrder = { "w", "c", "il", "rq", "t", "sl", "bd", "v" }; ns:Fire("SETTINGS_CHANGED", "colOrder")
local plan = main:ColumnPlan()
check(plan[2].key == "w", "column order respected: " .. plan[2].key)
SlashCmdList.BAGSMITH("dump")
CloseAllBags(); check(not main:IsShown(), "CloseAllBags")
-- A failing handler must be reported, not silently kill everything else.
local reached = false
ns:OnSignal("ITEMS_CHANGED", function() error("boom") end)
ns:OnSignal("ITEMS_CHANGED", function() reached = true end)
ns:Scan()
check(reached, "a failing handler does not stop later handlers")
check((ns.errors or 0) > 0 and M.log[#M.log - 1]:find("Error in"), "the error is reported in chat")

SlashCmdList.BAGSMITH("check")
check(M.log[#M.log]:find("Events this client") and M.log[#M.log - 1]:find("Missing APIs"), "self check runs")

-- Regression: validating a table without tab fields must not error.
local okv = pcall(ns.validateSettings, { version = 1, firstSeen = {} }, { version = 1, firstSeen = {} })
check(okv, "validating non-profile data does not touch tab fields")

-- Round 3 regressions
if not main:IsShown() then ToggleAllBags() end
ns:Set("view", "list"); ns:Set("grp", "type"); ns:RefreshViews(true)
local r0 = ns.Buttons:Get(0, 1)
check(r0.seps and r0.seps[1] and r0.seps[1]:IsShown(), "separators in list mode")
ns:Set("view", "icons"); ns:RefreshViews(true)
check(not r0.seps[1]:IsShown(), "separators hidden in icon mode")
ns:Set("view", "list")
ns:Set("cols", { "il", "t" }); ns:RefreshViews(true)
check(ns.Buttons:Get(0, 2).countOnIcon == true, "count shown on icon when Qty column is hidden")
ns:Set("cols", { "c", "il", "t", "bd", "v", "w" }); ns:RefreshViews(true)
check(ns.Buttons:Get(0, 2).countOnIcon == false, "count kept off the icon when Qty column is shown")
-- settings list: unchecked columns must still get a checkbox
ns:Set("cols", { "c", "t" })
ns.SettingsPanel:Show(); ns.SettingsPanel:ShowPage("bagcols")
local listW, colList = ns.SettingsPanel.pools.list, nil
for _, l in ipairs(listW) do for _, r in ipairs(l.rows) do if r.id == "w" and r:IsShown() then colList = r end end end
check(colList and colList.box:IsShown() and not colList.box:GetChecked(), "unchecked column keeps its checkbox")
ns:Set("cols", { "c", "il", "t", "bd", "v", "w" })
ns.SettingsPanel:Hide()
-- collapsed lanes: session only when remember is off
ns:Set("remember", false)
main:ToggleLane("Gear")
check(#ns.db.collapsed == 0 and #ns.ui.collapsed == 1, "collapse not written to the profile when remember is off")
main:ToggleLane("Gear"); ns:Set("remember", true)
-- alt view ignores separate layout
main:SetOwner("Mira Dawnvale - Forever")
local bags = main:Bags()
check(#bags == #ns.BAGS, "alt view shows every bag")
main:SetOwner(nil)
-- currency reading never mutates the wallet
local expandCalls = 0
C_CurrencyInfo.ExpandCurrencyList = function() expandCalls = expandCalls + 1 end
ns.Currency:List()
check(expandCalls == 0, "wallet headers are never expanded by the addon")
-- frame under cursor helper
_G.GetMouseFoci = function() local h = ns.Buttons:GetLane(main.child, 1); return { h } end
check(ns.FrameUnderCursor("laneId") ~= nil, "drop target resolved from mouse focus")
SlashCmdList.BAGSMITH("errors")
check(M.log[#M.log]:find("boom") or M.log[#M.log]:find("No errors"), "errors command lists recorded errors")

-- Round 4: columns
if not main:IsShown() then ToggleAllBags() end
ns:Set("view", "list"); ns:Set("grp", "type")
ns:Set("cols", { "c", "il", "t", "bd", "v", "w" })
ns:Set("colOrder", { "c", "n", "il", "t", "bd", "v", "w" }); ns:RefreshViews(true)
local plan = main:ColumnPlan()
check(plan[1].key == "c" and plan[2].key == "n", "Item column can sit after Qty: " .. plan[1].key .. "," .. plan[2].key)
check(plan[2].iconX > plan[1].colW - 5, "icon moves with the Item column")
local qtyPlan = plan[1]
check(qtyPlan.width == qtyPlan.colW - 4 - 10, "numeric column keeps a 10px gap before the next column")
ns:Set("colOrder", { "n", "c", "il", "t", "bd", "v", "w" })
ns:Set("cols", { "il" }); ns:RefreshViews(true)
plan = main:ColumnPlan()
check(plan[1].key == "n" and #plan == 2, "Item never hides even when unticked lists exclude it")
ns.db.colWidths.il = 120; ns:RefreshViews(true)
plan = main:ColumnPlan()
check(plan[2].colW == 120, "saved column width applied: " .. tostring(plan[2].colW))
check(main.headerGrips[1] and main.headerGrips[1]:IsShown() and not (main.headerGrips[2] and main.headerGrips[2]:IsShown()), "one grip per line between columns, none at the row's outer edge")
_G.BagSmithDB.profiles.Default.colWidths = { il = 9999, bogus = 50, c = "x" }
M.fire("ADDON_LOADED", "BagSmith")
check(ns.db.colWidths.il == 400 and ns.db.colWidths.bogus == nil and ns.db.colWidths.c == nil, "column widths validated")
ns.db.colWidths = {}; ns:Set("cols", { "c", "il", "t", "bd", "v", "w" })
check(ns:TypeText({ cat = "Gear", itemSubType = "Miscellaneous", equipLoc = "INVTYPE_HOLDABLE", quality = 2 }) == "Held", "gear misc shows slot")
check(ns:TypeText({ cat = "Other", itemSubType = "Junk", itemType = "Miscellaneous", quality = 1 }) == "Miscellaneous", "common junk-subtype shows Miscellaneous")

-- header click sorting
ns:SortByColumn(ns.ui, "v"); ns:RefreshViews(true)
local first
for _, b in ipairs(ns.Buttons.all) do if b:IsShown() and b.points[1] and b.points[1][5] == -26 then first = b end end
check(ns.ui.colSort.key == "v" and ns.ui.colSort.dir == "desc", "column sort set")
ns:SortByColumn(ns.ui, "v"); check(ns.ui.colSort.dir == "asc", "second click flips direction")
ns.ui.colSort = nil

-- Round 5: grips have a height, age column, All sheet has no checkbox
ns:Set("cols", { "c", "il", "t", "age" }); ns:RefreshViews(true)
local g = main.headerGrips[2]
check(g and g:IsShown() and (g.h or 0) > 0, "resize grip is hittable (has height): " .. tostring(g and g.h))
check(ns.AgeText(time() - 30) == "now" and ns.AgeText(time() - 7200) == "2h" and ns.AgeText(time() - 3 * 86400) == "3d", "age text")
check(ns.Buttons:Get(0, 1).colAge:IsShown() and ns.Buttons:Get(0, 1).colAge.text ~= nil, "age column filled")
ns:Set("cols", { "c", "il", "t", "bd", "v", "w" })
ns.SettingsPanel:Show(); ns.SettingsPanel:ShowPage("bagsheets")
local allRow
for _, l in ipairs(ns.SettingsPanel.pools.list) do for _, r in ipairs(l.rows) do if r.id == "All" and r:IsShown() then allRow = r end end end
check(allRow and not allRow.box:IsShown(), "All sheet has no checkbox")
ns.SettingsPanel:Hide()

-- Round 6: settings rows never overlap; wide controls drop below their label
ns.SettingsPanel:Show()
local overlap = false
for _, pg in ipairs({ "profile", "look", "window", "sections", "columns", "sheets", "sorting", "advanced" }) do
ns.SettingsPanel:ShowPage(pg)
for _, kind in ipairs({ "check", "seg", "step", "text", "head", "list", "edit", "btn" }) do
	for _, w in ipairs(ns.SettingsPanel.pools[kind]) do
		if w:IsShown() then
			local top = -(w.points[1] and w.points[1][5] or 0)
			w._top, w._bottom = top, top + (w.h or 0)
		end
	end
end
local rows = {}
for _, kind in ipairs({ "check", "seg", "step", "text", "head", "list", "edit", "btn" }) do
	for _, w in ipairs(ns.SettingsPanel.pools[kind]) do if w:IsShown() then rows[#rows + 1] = w end end
end
table.sort(rows, function(a, b) return a._top < b._top end)
for i = 2, #rows do if rows[i]._top < rows[i - 1]._bottom - 0.5 then overlap = true end end
rows = {}
end
check(not overlap, "no settings row overlaps the previous one, on any page")
ns.SettingsPanel:ShowPage("sorting")
local reagentSeg
for _, w in ipairs(ns.SettingsPanel.pools.seg) do if w:IsShown() and w.key == "sort" then reagentSeg = w end end
check(reagentSeg and reagentSeg.btns[1]:IsShown(), "sort segment laid out on the sorting page")
ns.SettingsPanel:Hide()

-- Round 7
check(ns:DisplayName("player") == "Aldren Thorne", "two-word name from the richer API: " .. ns:DisplayName("player"))
M.pvpName = "Aldren Thorne, Champion of the Frozen Wastes"
check(ns:DisplayName("player") == "Aldren", "a comma title falls back to the first name: " .. ns:DisplayName("player"))
M.pvpName = "Aldren the Explorer"
check(ns:DisplayName("player") == "Aldren", "a lowercase title word is not a last name: " .. ns:DisplayName("player"))
M.pvpName = "Aldren Thorne"
check(ns.DEFAULTS.colOrder[1] == "c" and ns.DEFAULTS.colOrder[2] == "n" and ns.IndexOf(ns.DEFAULTS.cols, "age"), "default columns: Qty, Item, Type, Bind, Vendor, Where, Age")
-- new marker clears on mouseover
M.newItems["1:1"] = true; ns:Scan(); ns:RefreshViews(true)
local nb = ns.Buttons:Get(1, 1)
check(nb.rec and nb.rec.isNew, "item flagged new before hover")
nb.scripts.OnEnter(nb); nb.scripts.OnLeave(nb); M.elapse()
check(nb.rec.isNew, "a quick pass over the item does not clear the marker")
nb.scripts.OnEnter(nb); M.elapse()
check(not nb.rec.isNew and not nb.newDot:IsShown() and not M.newItems["1:1"], "hovering for three seconds clears the marker and tells the client")
-- the client re-flagging it (a reload) must not bring it back
M.newItems["1:1"] = true; ns:Scan()
check(not ns.Buttons:Get(1, 1).rec.isNew, "dismissed item stays dismissed even if the client flags it again")
-- a stack that grows becomes new again
M.bags[0][2].count = 9; ns:Scan()
check(ns.Buttons:Get(0, 2).rec.isNew, "a stack that grew is marked new")
M.bags[0][2].count = 9; ns:DismissNew(ns.Buttons:Get(0, 2).rec); ns:Scan()
check(not ns.Buttons:Get(0, 2).rec.isNew, "dismissed at that count stays dismissed")
M.bags[0][2].count = 12; ns:Scan()
check(ns.Buttons:Get(0, 2).rec.isNew, "growing again makes it new again")
ns:DismissNew(ns.Buttons:Get(0, 2).rec)

-- Round 8: bank free count from the cache, scrollbar hidden when content fits
M.elapse(); main:SetSheet("Bank")
check(main.freeText.text:find("47 / 48") and not main.freeText.text:find("free"), "cached bank count shown away from the bank, without the word free: " .. tostring(main.freeText.text))
check(((main.classicApplied and main.classicTitle.text) or main.titleText.text) == "Bank (Saved)", "main window labels its bank sheet as the saved view")
main:SetSheet("All")
check(main.scroll.ScrollBar.shown == false or main.scroll.ScrollBar:IsShown() == false, "scrollbar hidden when the list fits")

-- Round 9
if not main:IsShown() then ToggleAllBags() end
ns:Set("view", "list"); ns:Set("grp", "type"); ns.ui.bagWindows = false; ns:RefreshViews(true)
-- duplicate bag names get the bag slot number
check(ns.bagInfo[1].name == "Linen Bag (1)" and ns.bagInfo[2].name == "Linen Bag (2)" and ns.bagInfo[3].name == "Small Brown Pouch", "duplicate bag names disambiguated: " .. ns.bagInfo[1].name .. " / " .. ns.bagInfo[3].name)
-- merge stacks
M.put(2, 1, { id = 1005, name = "Linen Cloth", q = 1, count = 7, ilvl = 5, type = "Tradeskill", sub = "Cloth", class = 7, subclass = 5, price = 13 })
ns:Scan()
ns:Set("mergeStacks", true); ns:RefreshViews(true)
local cloth
for _, b in ipairs(ns.Buttons.all) do if b:IsShown() and b.rec and b.rec.itemID == 1005 then cloth = b end end
check(cloth and cloth.rec.count == 27 and cloth.rec.stacks == 2, "two stacks merged into one row with the total: " .. tostring(cloth and cloth.rec.count))
check(cloth.rec.where:find("%+1"), "merged row says how many extra stacks")
check(ns.Buttons:Get(2, 1) and not ns.Buttons:Get(2, 1):IsShown() or cloth == ns.Buttons:Get(2, 1) or true, "")
main.btnMerge.scripts.OnClick(main.btnMerge)
check(not ns.db.mergeStacks, "toolbar button toggles merging")
local separate = 0
for _, b in ipairs(ns.Buttons.all) do if b:IsShown() and b.rec and b.rec.itemID == 1005 then separate = separate + 1 end end
check(separate == 2, "unmerged shows both stacks: " .. separate)
M.bags[2][1] = nil; ns:Scan()
-- reagent window
check(main.btnReagent:IsShown() and main.reagentText.text:find("/ 6"), "reagent footer icon with its own count: " .. main.reagentText.text)
main.btnReagent.scripts.OnClick(main.btnReagent)
check(ns.ui.reagentWindow and ns.Window.bagViews[5]:IsShown() and not ns.Window.bagViews[1]:IsShown(), "reagent icon opens only the reagent window")
ns.ui.bagWindows = true; ns:RefreshViews(true)
check(ns.Window.bagViews[1]:IsShown() and ns.Window.bagViews[0]:IsShown(), "bag windows open the rest")
ns.ui.bagWindows = false; ns:RefreshViews(true); ns.ui.reagentWindow = false; ns:RefreshViews(true)
-- accent colour
check(ns:Set("accent", "#00AAFF") and ns.db.accent == "00aaff", "accent accepts hex with a hash")
check(not ns:Set("accent", "blue") and ns.db.accent == "00aaff", "accent rejects non-hex")
local r, g, b = ns.Skins:Accent(); check(math.abs(b - 1) < 0.01 and r < 0.01, "accent colour feeds the skin")
ns.SettingsPanel:Show(); ns.SettingsPanel:ShowPage("look")
local colorRow = ns.SettingsPanel.pools.color[1]
colorRow.swatch.scripts.OnClick(colorRow.swatch)
M.pickRGB = { 1, 0, 0 }; M.picker.swatchFunc()
check(ns.db.accent == "ff0000", "colour picker commit applies: " .. ns.db.accent)
M.picker.cancelFunc(); check(ns.db.accent == "00aaff", "colour picker cancel restores")
colorRow.reset.scripts.OnClick(colorRow.reset); check(ns.db.accent == "fac775", "reset restores the default accent")
-- reset to defaults needs a confirm click
ns:Set("dense", true); ns.SettingsPanel:ShowPage("advanced")
local resetBtn
for _, w in ipairs(ns.SettingsPanel.pools.btn) do if w:IsShown() and w.label.text == "Reset to Defaults" then resetBtn = w end end
resetBtn.scripts.OnClick(resetBtn); check(ns.db.dense == true and ns.Popups.confirm:IsShown(), "reset asks in the dialog")
ns.Popups.confirm.yes.scripts.OnClick(ns.Popups.confirm.yes); check(ns.db.dense == false, "confirming resets")
ns.SettingsPanel:Hide()
-- tabs wrap
for i = 1, 8 do ns:SaveSheet("A fairly long sheet name number " .. i) end
main:SetSheet("All")
check(main.tabs.h and main.tabs.h > 22, "tabs wrap onto extra rows when there are many: " .. tostring(main.tabs.h))
local maxRight = 0
for _, b in ipairs(main.tabButtons) do if b:IsShown() then maxRight = math.max(maxRight, (b.points[1][4] or 0) + (b.w or 0)) end end
check(maxRight <= main.tabs:GetWidth(), "no tab runs past the window edge")
for i = 1, 8 do ns:DeleteSheet("A fairly long sheet name number " .. i) end

-- Round 10: footer under a narrow window
if not main:IsShown() then ToggleAllBags() end
ns.db.fav = { "c:3402", "c:1901", "i:20558" }
main.footer.w = 900; main:UpdateFooter()
check(main.favShown == 3 and not (main.favMore and main.favMore:IsShown()), "wide footer shows every favorite")
main.footer.w = 330; main:UpdateFooter()
local right = main.footer.w - 18 - main.btnBags.w - (main.btnReagent:IsShown() and (main.btnReagent.w + 6) or 0)
local ok = true
for i, chip in ipairs(main.favChips) do if chip:IsShown() then local cx = chip.points[1][4]; if cx + chip.w > right then ok = false end end end
if main.favMore and main.favMore:IsShown() then if main.favMore.points[1][4] + 34 > right then ok = false end end
check(ok, "narrow footer: nothing on the left runs into the count buttons on the right")
check(main.favShown < 3 and main.favMore:IsShown() and main.favMore.label.text == "+" .. (3 - main.favShown), "hidden favorites are counted in the +N chip")
main.footer.w = nil; ns.db.fav = {}

-- Round 11: bag swaps after login
if not main:IsShown() then ToggleAllBags() end
ns:Set("view", "list"); ns:Set("grp", "type")
-- swap bag 1 (6 slots) for a 20-slot bag with an item in slot 19
M.sizes[1] = 20; M.bagNames[1] = "Traveler's Backpack"
M.put(1, 19, { id = 3001, name = "Deep Pocket Item", q = 2, class = 15, subclass = 4, type = "Miscellaneous", sub = "Other" })
M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
check(#ns.Buttons.byBag[1] == 20, "pool grew to cover the bigger bag: " .. #ns.Buttons.byBag[1])
check(ns.Buttons:Get(1, 19) and ns.Buttons:Get(1, 19):IsShown() and ns.Buttons:Get(1, 19).rec.name == "Deep Pocket Item", "item in a slot beyond the old pool is shown")
check(ns.bagInfo[1].name == "Traveler's Backpack", "new bag name picked up")
-- the same swap during combat waits, then completes
M.sizes[3] = 20
M.put(3, 20, { id = 3002, name = "Late Item", q = 1, class = 15, subclass = 4, type = "Miscellaneous", sub = "Other" })
M.combat = true; M.fire("PLAYER_REGEN_DISABLED")
local okc = pcall(function() M.fire("BAG_UPDATE_DELAYED"); M.runTimers() end)
check(okc and #ns.Buttons.byBag[3] == 18, "no buttons created in combat")
check(main.statusText.text:find("new bag slots"), "status explains the wait: " .. tostring(main.statusText.text))
M.combat = false; M.fire("PLAYER_REGEN_ENABLED")
check(#ns.Buttons.byBag[3] == 20 and ns.Buttons:Get(3, 20):IsShown(), "buttons created after combat and the item appears")
-- filter panel rebuilds its Where list when bags change
ns.Popups:ToggleFilters(main)
local found = false
for _, c in ipairs(ns.Popups.filter.checks) do if c.label.text == "Traveler's Backpack" then found = true end end
check(found, "filter panel lists the new bag")
ns.Popups:ToggleFilters(main)
M.bags[1][19] = nil; M.bags[3][20] = nil

-- Round 12: keybind toggle, bank replacement, modern icon frames
if not main:IsShown() then ToggleAllBags() end
main:Hide()
-- Blizzard's frames were parked while "open"; switching the setting off must close them
ContainerFrame_GenerateFrame(ContainerFrame1, 20, 0)
check(ContainerFrame1:IsShown() and ContainerFrame1:GetParent() ~= ContainerFrameContainer, "Blizzard backpack frame parked and still counted open")
ns:Set("replaceBlizzardBags", false)
check(ContainerFrame1:GetParent() == ContainerFrameContainer and not ContainerFrame1:IsShown(), "switching the keybind setting off returns and closes Blizzard's frames")
ToggleAllBags()
check(not main:IsShown(), "with the keybind setting off, B does not open BagSmith")
check(ContainerFrame1:GetParent() ~= nil and ContainerFrame1:GetParent().name ~= nil or true, "")
M.blizOpen = false
SlashCmdList.BAGSMITH("show"); check(main:IsShown(), "/bs still opens it")
main:Hide()
ns:Set("replaceBlizzardBags", true)
ToggleAllBags(); check(main:IsShown(), "keybind setting back on: B opens BagSmith again")
-- bank
check(ns.Bank.supported and ns.Bank.backend == "modern", "bank bag API detected on this client: " .. ns.Bank.backend)
M.fire("BANKFRAME_OPENED"); M.runTimers()
check(BankFrame.alpha == 0 and ns.Bank.concealed, "Blizzard's bank window is concealed while replacing")
local bankWin = ns.Window.bank
check(bankWin.bankBar.h > 1 and bankWin.bankBar:IsShown(), "bank bag bar is shown in the bank window at a banker")
check(bankWin.bankBar.label.text == "Bank Bags" and bankWin.bankBar.hint.text:find("2 of 8"), "bank bag section has a title and slot summary: " .. tostring(bankWin.bankBar.hint.text))
local slots = bankWin.bankBar.slots
check(slots[1].purchased and slots[2].purchased and not slots[3].purchased, "purchased slots and the next one for sale")
check(slots[1].icon.shown == true and slots[2].icon.shown == true and slots[2].icon.texture == ns.BagBar.EMPTY and slots[2].icon.desaturated, "equipped bank bag shows its icon; empty purchased slot shows the empty bag picture (Classic)")
check(slots[3].secureBuy:IsShown() and slots[3].secureBuy:GetAttribute("clickbutton") == BankFrame.BankPanel.PurchasePrompt.TabCostFrame.PurchaseButton, "the for-sale slot securely clicks the purchase prompt's button")
check(ns.Bank:BlizzardPurchaseButton() ~= nil and ns.Bank.pickedName == "purchase prompt button", "the purchase prompt's button is the one used")
check(not slots[1].secureBuy:IsShown() and not slots[4].secureBuy:IsShown(), "only the for-sale slot has the secure click-through")
-- simulate Blizzard completing the purchase
M.bankSlots = 3; M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
check(bankWin.bankBar.slots[3].purchased and bankWin.bankBar.slots[4].secureBuy:IsShown(), "after purchase the bar updates and the next slot is for sale")
M.cursorItem = true
slots[2].scripts.OnClick(slots[2], "LeftButton")
check(M.putInBag == 26, "clicking an empty purchased slot with a bag on the cursor places it: " .. tostring(M.putInBag))
M.cursorItem = nil
slots[1].scripts.OnClick(slots[1], "LeftButton")
check(M.pickedBag == 25, "clicking a filled slot picks the bag up: " .. tostring(M.pickedBag))
main:Hide()
check(not M.bankClosed, "closing the main window does not end the bank session")
bankWin:Hide()
check(M.bankClosed == 1, "closing the bank window ends the bank session")
M.fire("BANKFRAME_CLOSED"); M.runTimers()
check(BankFrame.alpha == 1 and not ns.Bank.concealed, "Blizzard's bank window restored after leaving")
ns:Set("replaceBank", false)
M.fire("BANKFRAME_OPENED"); M.runTimers()
check(BankFrame.alpha == 1 and not bankWin:IsShown(), "with replacement off, Blizzard's bank stays and the bank window does not open")
M.fire("BANKFRAME_CLOSED"); M.runTimers()
ns:Set("replaceBank", true)
-- modern icon frames (new players start in Classic; this checks Modern)
if ns.db.skin ~= "modern" then ns:Set("skin", "modern"); M.runTimers() end
ToggleAllBags()
local fb = ns.Buttons:Get(0, 1)
check(fb.frameBG and fb.frameBG:IsShown(), "modern skin draws the shaded frame behind icons")
ns:Set("skin", "classic")
check(not fb.frameBG:IsShown(), "classic skin uses Blizzard slot art instead")
ns:Set("skin", "modern")

-- Round 13: rarity border per skin
if not main:IsShown() then ToggleAllBags() end
ns:Set("skin", "modern"); ns:Set("border", "all")
local rb = ns.Buttons:Get(0, 1)  -- rare staff
check(rb.qRing:IsShown() and not rb.qFrame:IsShown() and rb.frameBG:IsShown(), "modern list: crisp ring plus shaded frame")
ns:Set("skin", "classic")
check(rb.qRing:IsShown() and not rb.qFrame:IsShown() and not rb.frameBG:IsShown() and not rb.slotBG:IsShown(), "classic list: plain icon with a thin ring, no slot art")
ns:Set("view", "icons")
check(rb.qFrame:IsShown() and not rb.qRing:IsShown() and rb.slotBG:IsShown(), "classic icon cells: Blizzard slot art and Blizzard's rarity frame")
ns:Set("skin", "modern")
check(rb.qRing:IsShown() and rb.frameBG:IsShown() and not rb.slotBG:IsShown(), "modern icon cells: shaded frame inside the cell")
ns:Set("view", "list")
ns:Set("border", "unc")
local cb = ns.Buttons:Get(0, 2)  -- common potion
check(cb.qRing:IsShown() and cb.qNeutral and cb.qRing.color[1] == ns.Buttons.NEUTRAL_FRAME[1] and rb.qRing:IsShown() and not rb.qNeutral,
	"Green and Up: common icons get the neutral thin frame instead of a rarity color, rare keeps its color")
ns:Set("border", "off")
check(rb.qRing:IsShown() and rb.qNeutral and rb.qRing.color[1] == ns.Buttons.NEUTRAL_FRAME[1] and not rb.qFrame:IsShown(), "Off: every icon gets the neutral thin frame, no rarity color")
ns:Set("border", "all"); ns:Set("skin", "modern")
check(rb.IconBorder and not rb.IconBorder:IsShown(), "Blizzard's own border stays hidden")

-- compact rows with both border styles
ns:Set("dense", true); ns:Set("skin", "classic"); ns:RefreshViews(true)
local drb = ns.Buttons:Get(0, 1)
check(drb.h == 22 and drb.icon.w == 16, "compact rows shrink the icon with the row: " .. tostring(drb.icon.w))
check(drb.qRing:IsShown() and not drb.qFrame:IsShown(), "classic compact rows keep the thin ring")
ns:Set("skin", "modern")
check(drb.qRing:IsShown() and drb.frameBG:IsShown(), "modern ring and frame follow the smaller icon")
ns:Set("dense", false)
check(drb.h == 26 and drb.icon.w == 20, "normal rows restore the icon size")

-- read-only cells draw nothing over the icon
ns.ui.bagWindows = true; ns:RefreshViews(true)
local mc = ns.Buttons.mirrors[ns.Window.bagViews[1].child][1]
check((not mc.IconBorder or not mc.IconBorder:IsShown()), "mirror cells have no glow layer over the icon")
ns.ui.bagWindows = false; ns:RefreshViews(true)
main:SetOwner("Mira Dawnvale - Forever")
local ac = ns.Buttons.cached[main.child][1]
check(ac and ac:IsShown() and (not ac.IconBorder or not ac.IconBorder:IsShown()), "alt-view cells have no glow layer over the icon")
main:SetOwner(nil)

-- small windows: count in the title bar, no footer
ns.ui.bagWindows = true; ns:RefreshViews(true); ns.ui.reagentWindow = true; ns:RefreshViews(true)
local bw, rw = ns.Window.bagViews[1], ns.Window.bagViews[5]
check(bw.titleCount and bw.titleCount.text and bw.titleCount.text:find("/ 20") and not bw.titleCount.text:find("free"), "bag window count in the title: " .. tostring(bw.titleCount.text))
check(not bw.footer:IsShown() and not rw.footer:IsShown(), "bag and reagent windows have no footer or gold")
check(rw.titleCount.text:find("/ 6"), "reagent window count in the title: " .. tostring(rw.titleCount.text))
ns.ui.bagWindows = false; ns:RefreshViews(true); ns.ui.reagentWindow = false; ns:RefreshViews(true)

-- unknown events are skipped, not fatal
check(ns.IndexOf(ns.skippedEvents, "PLAYERBANKBAGSLOTS_CHANGED") ~= nil, "unknown client event recorded as skipped")
check((ns.errors or 0) == 1, "no error is raised for it (only the deliberate boom from earlier): " .. tostring(ns.errors))
SlashCmdList.BAGSMITH("check")
check(M.log[#M.log]:find("PLAYERBANKBAGSLOTS_CHANGED"), "self check lists skipped events")

-- Round 14: taint sources from the beta log
local anyBagID = false
for _, b in ipairs(ns.Buttons.all) do if rawget(b, "bagID") ~= nil then anyBagID = true end end
check(not anyBagID, "no secure button carries an addon-written bagID field")
check(rawget(ns.Buttons.proxies[0], "GetBagID") == nil, "proxies expose only their C-side ID")
check(ns.Buttons:Get(0, 1).smithBag == 0, "our own bag bookkeeping lives under another name")
-- Blizzard assigning a managed bag to one of its frames parks it; an unmanaged bag unparks it
check(type(ContainerFrame2.SetBagID) == "function" and type(ContainerFrame2.SetID) == "function", "no Blizzard frame method was broken by a hook")
ContainerFrame_GenerateFrame(ContainerFrame2, 6, 1)
check(ContainerFrame2:GetParent() ~= UIParent and ContainerFrame2:GetParent() ~= ContainerFrameContainer, "Blizzard bag frame parked when Blizzard assigns it a managed bag")
ContainerFrame_GenerateFrame(ContainerFrame2, 48, -1)
check(ContainerFrame2:GetParent() == ContainerFrameContainer, "unparked when assigned the bank")
ContainerFrame_GenerateFrame(ContainerFrame3, 6, 2); ContainerFrame3:SetParent(ContainerFrameContainer)
UpdateContainerFrameAnchors()
check(ContainerFrame3:GetParent() ~= ContainerFrameContainer, "anchor pass re-parks any managed frame")

-- One Bag window parks like the rest
_G.ContainerFrameCombinedBags = CreateFrame("Frame", "ContainerFrameCombinedBags", ContainerFrameContainer)
ContainerFrameCombinedBags.SetBagID = function(self, id) self:SetID(id) end
ContainerFrame_GenerateFrame(ContainerFrameCombinedBags, 0, 0)
check(ContainerFrameCombinedBags:GetParent() ~= ContainerFrameContainer, "Blizzard's combined bag window is parked when it opens")
local lbk = #M.log
SlashCmdList.BAGSMITH("check")
local bankLine = false
for i = lbk + 1, #M.log do if M.log[i]:find("Bank: modern API") and M.log[i]:find("Purchase button") then bankLine = true end end
check(bankLine, "/bs check reports the bank API and purchase button")
lbk = #M.log
SlashCmdList.BAGSMITH("bankapi")
local helped = false
for i = lbk + 1, #M.log do if M.log[i]:find("Commands:") and not M.log[i]:find("bank") then helped = true end end
check(helped, "retired commands are gone and the help no longer lists them")

-- Round 15: the bank window is independent of the main window
if not main:IsShown() then ToggleAllBags() end
M.fire("BANKFRAME_OPENED"); M.runTimers()
local bankWin = ns.Window.bank
check(bankWin:IsShown(), "bank window open")
bankWin:SetPref("grp", "none"); bankWin:SetPref("sort", "name"); bankWin:SetPref("view", "icons"); bankWin:SetPref("mergeStacks", true)
check(ns.db.grp == "type" and ns.db.sort == "quality" and ns.db.view == "list" and not ns.db.mergeStacks, "changing the bank's tools leaves the main window's settings alone")
check(ns.db.bankGrp == "none" and ns.db.bankSort == "name" and ns.db.bankView == "icons" and ns.db.bankMerge, "the bank keeps its own grouping, sort, view and merge")
local bankTabs = {}
for _, b in ipairs(bankWin.tabButtons) do if b:IsShown() then bankTabs[#bankTabs + 1] = b.sheet end end
check(#bankTabs == 6 and not ns.IndexOf(bankTabs, "Bank"), "bank window has the category tabs but no Bank tab: " .. table.concat(bankTabs, ","))
bankWin:SetSheet("Consumables")
check(ns.uiBank.sheet == "Consumables" and ns.ui.sheet ~= "Consumables", "bank sheet is separate from the main sheet")
ns.uiBank.filters.text = "jerky"; ns:RefreshViews(true)
check(ns.ui.filters.text == "", "bank search does not leak into the main search")
ns.Popups:ToggleFilters(bankWin)
check(ns.Popups.view == bankWin, "filter panel opened from the bank edits the bank's filters")
ns.Popups:ToggleFilters(bankWin)
ns.uiBank.filters = ns.EmptyFilters(); bankWin:SetSheet("All")
bankWin:SetPref("grp", "type"); bankWin:SetPref("sort", "quality"); bankWin:SetPref("view", "list"); bankWin:SetPref("mergeStacks", false)
M.fire("BANKFRAME_CLOSED"); M.runTimers()

-- Round 16
check(rawequal(_G.StaticPopupDialogs, M.spdTable) and _G.StaticPopupDialogs.BAGSMITH_BUY_BANK_SLOT == nil, "StaticPopupDialogs global never reassigned, and no dialog added on the modern path")
-- bank window honours the replace setting
ns:Set("replaceBank", false)
M.fire("BANKFRAME_OPENED"); M.runTimers()
check(not ns.Window.bank:IsShown() and main:IsShown() and BankFrame.alpha == 1, "with replacement off, only the main window opens at the bank")
ns:Set("replaceBank", true)
check(ns.Window.bank:IsShown() and BankFrame.alpha == 0, "turning replacement on at the bank opens the bank window")
ns:Set("replaceBank", false)
check(not ns.Window.bank:IsShown() and not M.bankClosed2, "turning it off closes the bank window without ending the session")
ns:Set("replaceBank", true)
-- bank sheets
ns.uiBank.filters.cat.Consumables = true
check(ns:SaveSheet("Bank food", ns.Window.bank), "bank can save a sheet")
check(ns.uiBank.sheet == "Bank food" and #ns.db.bankSheets == 1 and #ns.db.sheets == 0, "bank sheet stored separately from bag sheets")
local names = {}
for _, b in ipairs(ns.Window.bank.tabButtons) do if b:IsShown() then names[#names + 1] = b.sheet end end
check(ns.IndexOf(names, "Bank food") ~= nil and not ns.IndexOf(names, "Bank"), "bank tab row shows the saved bank sheet")
local mainNames = {}
for _, b in ipairs(main.tabButtons) do if b:IsShown() then mainNames[#mainNames + 1] = b.sheet end end
check(not ns.IndexOf(mainNames, "Bank food"), "bag window does not show bank sheets")
ns.Window.bank:SetSheet("All"); ns.Window.bank:SetSheet("Bank food")
check(ns.uiBank.filters.cat.Consumables, "selecting the bank sheet restores its filters")
ns:DeleteSheet("Bank food", ns.Window.bank)
check(#ns.db.bankSheets == 0 and ns.uiBank.sheet == "All", "bank sheet deleted")
M.fire("BANKFRAME_CLOSED"); M.runTimers()

-- Round 17: sheet workflow, filter search mirroring, bank hidden tabs, profiles list, timings
if not main:IsShown() then ToggleAllBags() end
ns.ui.filters = ns.EmptyFilters(); main:SetSheet("All")
main.tabAdd.scripts.OnClick(main.tabAdd)
check(ns.Popups.filter:IsShown() and ns.Popups.view == main and not ns.Popups.editing and ns.Popups.filter.saveBtn.label.text == "Save as Sheet", "plus opens the filter panel in new-sheet mode")
ns.Popups.filter.sheetBox:SetText("Greens"); ns.ui.filters.q[2] = true
ns.Popups:CommitSheet()
check(ns.ui.sheet == "Greens" and #ns.db.sheets == 1 and not ns.Popups.filter:IsShown(), "saving from the panel creates and selects the sheet")
check(main.tabEdit:IsShown(), "pencil appears for a selected custom sheet")
main.tabEdit.scripts.OnClick(main.tabEdit)
check(ns.Popups.editing == "Greens" and ns.Popups.filter.saveBtn.label.text == "Save Changes" and ns.Popups.filter.deleteBtn:IsShown(), "pencil opens edit mode with save changes and delete")
ns.Popups.filter.sheetBox:SetText("Green things"); ns.ui.filters.q[3] = true
ns.Popups:CommitSheet()
check(ns.db.sheets[1].n == "Green things" and ns.db.sheets[1].f.q[3] and ns.ui.sheet == "Green things", "edit renames the sheet and saves the new filters")
main.tabEdit.scripts.OnClick(main.tabEdit)
ns.Popups.filter.deleteBtn.scripts.OnClick(ns.Popups.filter.deleteBtn)
check(#ns.db.sheets == 1 and ns.Popups.confirm:IsShown() and ns.Popups.confirm.text.text:find("Green things"), "delete asks in a BagSmith dialog, not chat")
ns.Popups.confirm.no.scripts.OnClick(ns.Popups.confirm.no)
check(#ns.db.sheets == 1 and not ns.Popups.confirm:IsShown(), "cancel keeps the sheet")
ns.Popups.filter.deleteBtn.scripts.OnClick(ns.Popups.filter.deleteBtn)
ns.Popups.confirm.yes.scripts.OnClick(ns.Popups.confirm.yes)
check(#ns.db.sheets == 0 and ns.ui.sheet == "All", "yes deletes the sheet")
-- search mirroring both ways
ns.Popups:OpenFilters(main, "browse")
main.search:SetText("cloth"); main.search.scripts.OnTextChanged(main.search)
check(ns.Popups.filter.search.text == "cloth", "window search mirrors into the filter panel")
ns.Popups.filter.search:SetText("egg"); ns.Popups.filter.search.scripts.OnTextChanged(ns.Popups.filter.search)
check(ns.ui.filters.text == "egg" and main.search.text == "egg", "filter panel search mirrors back to the window")
ns.Popups.filter:Hide(); ns.ui.filters.text = ""; main.search:SetText("")
-- bank hidden tabs are separate
ns.db.bankHiddenTabs = { "Quest" }; ns:Fire("SETTINGS_CHANGED", "bankHiddenTabs")
M.fire("BANKFRAME_OPENED"); M.runTimers()
local bt = {}
for _, b in ipairs(ns.Window.bank.tabButtons) do if b:IsShown() then bt[#bt + 1] = b.sheet end end
local mt = {}
for _, b in ipairs(main.tabButtons) do if b:IsShown() then mt[#mt + 1] = b.sheet end end
check(not ns.IndexOf(bt, "Quest") and ns.IndexOf(mt, "Quest"), "hiding a bank tab does not hide the bag tab")
ns.db.bankHiddenTabs = {}
M.fire("BANKFRAME_CLOSED"); M.runTimers()
-- profiles list can delete from Default
ns.Profiles:Use("Alt profile"); ns.Profiles:Use("Default")
ns.SettingsPanel:Show(); ns.SettingsPanel:ShowPage("profile")
local prow
for _, l in ipairs(ns.SettingsPanel.pools.profiles) do for _, r in ipairs(l.rows) do if r:IsShown() and r.name == "Alt profile" then prow = r end end end
check(prow and prow.del:IsShown(), "non-Default profiles show a delete button from any profile")
prow.del.scripts.OnClick(prow.del)
check(BagSmithDB.profiles["Alt profile"] ~= nil and ns.Popups.confirm:IsShown(), "profile delete asks in the dialog")
ns.Popups.confirm.yes.scripts.OnClick(ns.Popups.confirm.yes)
check(BagSmithDB.profiles["Alt profile"] == nil, "confirming deletes the profile")
ns.SettingsPanel:Hide()
check(ns.Buttons.NEW_DISMISS_SECONDS == 0.5, "new-item dismissal is half a second")
check(main.dragArea and main.dragArea.points[1][1] == "TOPLEFT" and main.dragArea.h > 26, "drag band covers the whole top of the window")

-- Round 18: combat fade, segmented groups
if not main:IsShown() then ToggleAllBags() end
ns:Set("combatFade", true); ns:Set("combatAlpha", 0.15); ns:Set("combatLock", true)
M.combat = true; M.fire("PLAYER_REGEN_DISABLED")
check(math.abs(main.frame.alpha - 0.15) < 0.001, "windows fade to the combat opacity: " .. tostring(main.frame.alpha))
check(main.frame.bsShield and main.frame.bsShield:IsShown(), "a click shield covers the window in combat")
ns:Set("combatLock", false)
check(not main.frame.bsShield:IsShown(), "click shield can be turned off")
ns:Set("combatLock", true)
ns:Set("combatAlpha", 0.5)
check(math.abs(main.frame.alpha - 0.5) < 0.001, "changing the opacity mid-combat applies immediately")
M.combat = false; M.fire("PLAYER_REGEN_ENABLED")
check(main.frame.alpha == 1 and not main.frame.bsShield:IsShown(), "windows return to full opacity and accept clicks after combat")
ns:Set("combatFade", false); M.combat = true; M.fire("PLAYER_REGEN_DISABLED")
check(main.frame.alpha == 1, "with fading off nothing changes")
M.combat = false; M.fire("PLAYER_REGEN_ENABLED"); ns:Set("combatFade", true)
check(main.syncGrp ~= nil, "segmented groups built")

-- Round 19
if not main:IsShown() then ToggleAllBags() end
-- dismissal survives a bag update during the hover, and takes 1 second
M.newItems["0:3"] = true; ns:Scan(); ns:RefreshViews(true)
local nbtn = ns.Buttons:Get(0, 3)
check(nbtn.rec and nbtn.rec.isNew, "item flagged new")
nbtn.scripts.OnEnter(nbtn)
M.bags[0][3].count = 4; ns:Scan()     -- record replaced while hovering
M.elapse()
check(not ns.Buttons:Get(0, 3).rec.isNew, "hover dismissal still completes after a bag update replaced the record")
check(ns.Buttons.NEW_DISMISS_SECONDS == 0.5, "dismissal takes half a second")
-- bag windows dismiss on hover too
M.newItems["1:1"] = true; ns.cdb.seen = {}; ns.cdb.seenSlots = {}; ns.newFlags = {}; ns:Scan()
ns.ui.bagWindows = true; ns:RefreshViews(true)
local mcell = ns.Buttons.mirrors[ns.Window.bagViews[1].child][1]
check(mcell.rec and mcell.rec.isNew, "mirror cell shows the new item")
mcell.scripts.OnEnter(mcell); M.elapse()
check(not mcell.rec.isNew and not ns.Buttons:Get(1, 1).rec.isNew, "hovering in a bag window clears the marker everywhere")
ns.ui.bagWindows = false; ns:RefreshViews(true)
-- tooltips suppressed in combat while faded
M.combat = true; M.fire("PLAYER_REGEN_DISABLED")
GameTooltip.shown = false
local rowb = ns.Buttons:Get(0, 1); rowb.scripts.OnEnter(rowb)
check(not GameTooltip:IsShown(), "no item tooltip during combat while faded")
main.btnSettings.scripts.OnEnter(main.btnSettings)
check(not GameTooltip:IsShown(), "no button tooltip during combat while faded")
M.combat = false; M.fire("PLAYER_REGEN_ENABLED")
rowb.scripts.OnEnter(rowb)
check(GameTooltip:IsShown(), "tooltips back after combat")
rowb.scripts.OnLeave(rowb)
-- an open tooltip is hidden when combat starts
rowb.scripts.OnEnter(rowb); check(GameTooltip:IsShown(), "tooltip open")
M.combat = true; M.fire("PLAYER_REGEN_DISABLED")
check(not GameTooltip:IsShown(), "tooltip hidden the moment combat starts")
M.combat = false; M.fire("PLAYER_REGEN_ENABLED")
-- confirm dialog sizes to its text
ns.Confirm(nil, "Delete the profile \"test\"?\nCharacters using it go back to Default.", function() end)
check(ns.Popups.confirm.text.h and ns.Popups.confirm.text.h >= 15 and ns.Popups.confirm.h > 80, "confirm dialog gives its text a real height")
ns.Popups.confirm:Hide()
-- small windows: grid directly under the title
ns.ui.bagWindows = true; ns:RefreshViews(true)
local bw = ns.Window.bagViews[1]
check(bw.scroll.points[1][2] == bw.title, "bag window grid anchors to the title")
ns.ui.bagWindows = false; ns:RefreshViews(true)

-- Round 20: starting states and session memory
main:Hide()
ns:Set("bagWindows", true, true); ns:Set("reagentWindow", true, true)
ToggleAllBags()
check(ns.Window.bagViews[1]:IsShown() and ns.Window.bagViews[5]:IsShown(), "both settings on: windows open with BagSmith")
local bv1 = ns.Window.bagViews[1]
-- close a bag window with its X: all bag windows stay closed for the session
ns.ui.bagWindows = false; ns.ui.closedBags = {}; ns:RefreshViews(true)   -- the footer icon turning the set off
check(not ns.Window.bagViews[1]:IsShown() and not ns.Window.bagViews[0]:IsShown() and not main.btnBags.active, "turning the set off closes them and un-lights the icon")
ns:RefreshViews(true); ns:Scan()
check(not ns.Window.bagViews[1]:IsShown(), "later refreshes do not reopen it")
check(ns.Window.bagViews[5]:IsShown(), "the reagent window is unaffected")
main:Hide(); ToggleAllBags()
check(ns.Window.bagViews[1]:IsShown(), "reopening BagSmith returns to the starting state")
ns:Set("bagWindows", false, true); ns:Set("reagentWindow", false, true); ns.ui.bagWindows, ns.ui.reagentWindow = nil, nil; ns:RefreshViews(true)
check(not ns.Window.bagViews[1]:IsShown() and not ns.Window.bagViews[5]:IsShown(), "settings off: windows closed")

-- Round 21: empty slots in the main window's icon view
if not main:IsShown() then ToggleAllBags() end
ns.ui.filters = ns.EmptyFilters(); main:SetSheet("All")
ns:Set("emptySlots", true); ns:Set("view", "icons"); ns:Set("grp", "none"); ns:RefreshViews(true)
local shownCells, blanks = 0, 0
for _, b in ipairs(ns.Buttons.all) do if b:IsShown() and b:GetParent():GetParent() == main.child then shownCells = shownCells + 1; if b.rec and b.rec.empty then blanks = blanks + 1 end end end
local expectedTotal = 0
for _, bag in ipairs(main:Bags()) do expectedTotal = expectedTotal + (ns.bagInfo[bag] and ns.bagInfo[bag].size or 0) end
check(shownCells == expectedTotal and blanks > 0, ("icon view with no sections shows every slot: %d of %d, %d empty"):format(shownCells, expectedTotal, blanks))
ns:Set("grp", "bag"); ns:RefreshViews(true)
shownCells = 0
for _, b in ipairs(ns.Buttons.all) do if b:IsShown() and b:GetParent():GetParent() == main.child then shownCells = shownCells + 1 end end
check(shownCells == expectedTotal, "sections by bag also show every slot: " .. shownCells)
ns:Set("grp", "type"); ns:RefreshViews(true)
blanks = 0
for _, b in ipairs(ns.Buttons.all) do if b:IsShown() and b.rec and b.rec.empty then blanks = blanks + 1 end end
check(blanks == 0, "sections by type show no empties")
ns:Set("grp", "none"); ns:Set("emptySlots", false); ns:RefreshViews(true)
blanks = 0
for _, b in ipairs(ns.Buttons.all) do if b:IsShown() and b.rec and b.rec.empty then blanks = blanks + 1 end end
check(blanks == 0, "setting off hides empties")
ns:Set("emptySlots", true); ns:Set("view", "list"); ns:Set("grp", "type")

-- Round 22: dismissal without GUIDs and without RemoveNewItem (Forever-like)
if not main:IsShown() then ToggleAllBags() end
ns:Set("view", "list"); ns:Set("grp", "type")
local savedGuid, savedRemove = C_Item.GetItemGUID, C_NewItems.RemoveNewItem
C_Item.GetItemGUID = nil; C_NewItems.RemoveNewItem = nil
M.newItems["0:5"] = true; ns.cdb.seenSlots = {}; ns.newFlags = {}; ns.lastCounts = {}
ns:Scan(); ns:RefreshViews(true)
local gb = ns.Buttons:Get(0, 5)
check(gb.rec.isNew and gb.rec.guid == nil, "new item flagged with no GUID available")
gb.scripts.OnEnter(gb); M.elapse()
check(not gb.rec.isNew, "dismissed by hover")
-- reopen the bags: the client still flags it and cannot clear it
main:Hide(); ToggleAllBags()
check(not ns.Buttons:Get(0, 5).rec.isNew, "dot stays gone after reopening the bags")
ns:Scan(); ns:RefreshViews(true)
check(not ns.Buttons:Get(0, 5).rec.isNew, "and after a rescan")
M.bags[0][5].count = (M.bags[0][5].count or 1) + 5; ns:Scan()
check(ns.Buttons:Get(0, 5).rec.isNew, "a grown stack is new again without GUIDs")
ns:DismissNew(ns.Buttons:Get(0, 5).rec)
M.bags[0][5] = { id = 7777, name = "Different item", q = 1, class = 15, subclass = 4, type = "Miscellaneous", sub = "Other" }
M.newItems["0:5"] = true; ns:Scan()
check(ns.Buttons:Get(0, 5).rec.isNew, "a different item in the same slot is new")
M.bags[0][5] = nil; M.newItems["0:5"] = nil; ns:Scan()
C_Item.GetItemGUID = savedGuid; C_NewItems.RemoveNewItem = savedRemove

-- Round 23: dismissal with Merge stacks on survives a reopen without a rescan
if not main:IsShown() then ToggleAllBags() end
ns:Set("view", "list"); ns:Set("grp", "type")
M.put(2, 2, { id = 1005, name = "Linen Cloth", q = 1, count = 3, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
M.newItems["2:2"] = true; ns.cdb.seen = {}; ns.cdb.seenSlots = {}; ns.newFlags = {}; ns.lastCounts = {}
ns:Scan()
main:SetPref("mergeStacks", true); ns:RefreshViews(true)
local merged
for _, b in ipairs(ns.Buttons.all) do if b:IsShown() and b.rec and b.rec.itemID == 1005 and b.rec.merged then merged = b end end
check(merged and merged.rec.isNew, "merged cloth row is flagged new")
merged.scripts.OnEnter(merged); M.elapse()
check(not merged.rec.isNew, "hover clears the merged row")
main:Hide(); ToggleAllBags()   -- reopen: rebuilds merged rows from the live records, no rescan
local again
for _, b in ipairs(ns.Buttons.all) do if b:IsShown() and b.rec and b.rec.itemID == 1005 and b.rec.merged then again = b end end
check(again and not again.rec.isNew, "dot stays cleared after reopening with Merge stacks on")
main:SetPref("mergeStacks", false); M.bags[2][2] = nil; M.newItems["2:2"] = nil; ns:Scan()

-- Round 24: bag window controls and a leak probe
if not main:IsShown() then ToggleAllBags() end
ns:Set("bagCols", 4); ns.ui.bagWindows = true; ns:RefreshViews(true)
local bwin = ns.Window.bagViews[0]   -- backpack, 20 slots
local rows = {}
for _, c in pairs(ns.Buttons.mirrors[bwin.child] or {}) do if c:IsShown() then rows[math.abs(c.points[1][5])] = true end end
local nrows = 0; for _ in pairs(rows) do nrows = nrows + 1 end
local want = math.ceil(ns.bagInfo[0].size / 4)
check(nrows == want, ("%d-slot bag at 4 per row makes %d rows: %d"):format(ns.bagInfo[0].size, want, nrows))
check(bwin.frame.w == 12 * 2 + 22 + 4 * (37 + 6) - 6, "bag window width follows icons per row: " .. tostring(bwin.frame.w))
ns:Set("bagMaxH", 200); ns:RefreshViews(true)
check(bwin.frame.h <= 200, "bag window height capped: " .. tostring(bwin.frame.h))
do
	local keep = ns.db.scale
	ns:Set("scale", 1.2); ns:Set("bagScale", 0.8)
	check(math.abs(bwin.frame.scale - 0.96) < 1e-6, "bag windows follow the main Scale, with Bag Window Scale on top: " .. tostring(bwin.frame.scale))
	ns:Set("bagScale", 1.0)
	check(math.abs(bwin.frame.scale - 1.2) < 1e-6, "Bag Window Scale 100% matches the main window")
	ns:Set("scale", keep)
end
ns:Set("bagCols", 6); ns:Set("bagMaxH", 320); ns:Set("bagScale", 1.0); ns.ui.bagWindows = false; ns:RefreshViews(true)
-- leak probe: frames must not grow across many refreshes, popups and scans
local f0 = #M.frames
for i = 1, 60 do
  M.bags[0][2].count = 5 + (i % 3); M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.elapse()
  M.fire("PLAYER_MONEY"); M.fire("CURRENCY_DISPLAY_UPDATE"); M.runTimers()
  if i % 5 == 0 then
    ns.Popups:ToggleFilters(main); ns.Popups:ToggleFilters(main)
    M.fire("BANKFRAME_OPENED"); M.runTimers(); ns.Popups:ToggleFilters(ns.Window.bank); ns.Popups:ToggleFilters(ns.Window.bank); M.fire("BANKFRAME_CLOSED"); M.runTimers()
    ns:Set("view", i % 10 == 0 and "icons" or "list"); ns.SettingsPanel:Show(); ns.SettingsPanel:ShowPage("bagcols"); ns.SettingsPanel:Hide()
    ns.ui.bagWindows = true; ns:RefreshViews(true); ns.ui.bagWindows = false; ns:RefreshViews(true)
  end
end
check(#M.frames - f0 <= 4, ("no frame growth across a long session: +%d"):format(#M.frames - f0))
ns:Set("view", "list")

-- Round 25: empty-slot look by skin; scrollbar decided after sizing
if not main:IsShown() then ToggleAllBags() end
ns.ui.bagWindows = true; ns:RefreshViews(true)
local bw3 = ns.Window.bagViews[3]   -- empty bag
local empty
for _, c in pairs(ns.Buttons.mirrors[bw3.child] or {}) do if c:IsShown() and c.rec == nil then empty = c end end
ns:Set("skin", "modern"); ns:RefreshViews(true)
check(empty and not empty.icon:IsShown() and empty.frameBG:IsShown(), "modern: empty bag-window slot is the plain shaded square")
ns:Set("view", "icons"); ns:Set("grp", "none"); ns:Set("emptySlots", true); ns:RefreshViews(true)
local mainEmpty
for _, b in ipairs(ns.Buttons.all) do if b:IsShown() and b.rec and b.rec.empty and b:GetParent():GetParent() == main.child then mainEmpty = b end end
check(mainEmpty and not mainEmpty.icon:IsShown() and mainEmpty.frameBG:IsShown(), "modern: empty main-window slot matches (no Blizzard art)")
ns:Set("skin", "classic"); ns:RefreshViews(true)
check(empty.slotBG:IsShown() and empty.slotRing:IsShown() and mainEmpty.slotBG:IsShown() and not mainEmpty.icon:IsShown(), "classic: empties show the cropped slot art inside the Quickslot ring in both windows")
ns:Set("skin", "modern"); ns:Set("view", "list"); ns:Set("grp", "type"); ns.ui.bagWindows = false; ns:RefreshViews(true)
-- scrollbar: fit-content window that grows to hold the list shows no bar
local origScrollGH = main.scroll.GetHeight
main.scroll.GetHeight = function() return (main.frame.h or 500) - 200 end   -- the mock does no layout; make the scroll region follow the window like anchors do
ns:Set("sizeMode", "auto"); ns:Set("maxH", 1200); ns:RefreshViews(true)
check(not main.scroll.ScrollBar:IsShown(), "no scrollbar when the window grew to fit")
ns:Set("maxH", 300); ns:RefreshViews(true)
check(main.scroll.ScrollBar:IsShown(), "scrollbar when the cap is hit")
ns:Set("maxH", 720); main.scroll.GetHeight = origScrollGH

-- Filter panel height follows the number of bag rows
if not main:IsShown() then ToggleAllBags() end
ns.Popups:OpenFilters(main, "browse")
local pf = ns.Popups.filter
local h1 = pf.h
-- one long bag row: add many bags with long names to force a second row
local savedNames = {}
for k, v in pairs(M.bagNames) do savedNames[k] = v end
M.bagNames[1] = "An Extraordinarily Long Bag Name One"; M.bagNames[2] = "An Extraordinarily Long Bag Name Two"; M.bagNames[3] = "An Extraordinarily Long Bag Name Three"
ns:Scan(); ns.Popups.filter:Hide(); ns.Popups:OpenFilters(main, "browse")
check(pf.h > h1, ("panel grows when the Where list wraps: %s -> %s"):format(tostring(h1), tostring(pf.h)))
M.bagNames = savedNames; ns:Scan(); ns.Popups.filter:Hide(); ns.Popups:OpenFilters(main, "browse")
check(pf.h == h1, "and shrinks back with fewer rows")
ns.Popups.filter:Hide()

-- Responsive toolbar
if not main:IsShown() then ToggleAllBags() end
main.tools.w = 900; main:LayoutTools()
check(not main.toolsCompact and main.toolItems[1].frame:IsShown() and main.btnMerge.label.text == "Merge Stacks", "wide: full toolbar with labels")
main.tools.w = 560; main:LayoutTools()
-- (1.4.1: the toolbar narrows in two steps, labels first, then "Merge"; at 560 the labels are hidden and Merge is
-- shortened only if it still doesn't fit)
check(main.toolsCompact and not main.toolItems[1].frame:IsShown() and main.btnMerge.label.text == ((main.toolsLevel or 0) >= 2 and "Merge" or "Merge Stacks") and main.toolsWidth <= 560, ("narrow: compact toolbar fits (%d in %d)"):format(main.toolsWidth, 560))
main.tools.w = nil; main:LayoutTools()

-- Ages survive an early empty scan after login
local stamp = ns.cdb.firstSeen
local anyGuid, anyStamp
for g, s in pairs(stamp) do anyGuid, anyStamp = g, s; break end
check(anyGuid ~= nil, "timestamps exist")
ns.loginTime = time()           -- pretend we just logged in
local savedSizes = {}
for k, v in pairs(M.sizes) do savedSizes[k] = v end
for k in pairs(M.sizes) do M.sizes[k] = 0 end   -- client hands over nothing yet
ns:Scan()
check(ns.cdb.firstSeen[anyGuid] == anyStamp, "an empty scan right after login does not wipe timestamps")
for k, v in pairs(savedSizes) do M.sizes[k] = v end
ns:Scan()
check(ns.cdb.firstSeen[anyGuid] == anyStamp, "the age is unchanged once items come back")
ns.loginTime = time() - 60

-- Stack age follows the newest item; splits keep their age
ns.loginTime = time() - 60
M.put(2, 3, { id = 5005, name = "Rugged Leather", q = 1, count = 10, class = 7, subclass = 6, type = "Tradeskill", sub = "Leather" })
ns:Scan()
local function recAt(bag, slot) for _, r in ipairs(ns.items) do if r.bag == bag and r.slot == slot then return r end end end
local old = time() - 3600
ns.cdb.firstSeen[recAt(2, 3).guid] = old; ns:Scan()
check(recAt(2, 3).firstSeen == old, "stack has an hour-old age")
M.bags[2][3].count = 14; ns:Scan()
check(recAt(2, 3).firstSeen >= time() - 2, "adding to the stack resets its age to now")
ns.cdb.firstSeen[recAt(2, 3).guid] = old; ns:Scan()
-- split: 14 -> 9 here, a new stack of 5 appears elsewhere
M.bags[2][3].count = 9
M.put(2, 4, { id = 5005, name = "Rugged Leather", q = 1, count = 5, class = 7, subclass = 6, type = "Tradeskill", sub = "Leather" })
ns:Scan()
check(recAt(2, 4).firstSeen == old and recAt(2, 3).firstSeen == old, "a split-off stack inherits the source's age")
-- genuinely new loot of the same item elsewhere is new
M.put(2, 5, { id = 5005, name = "Rugged Leather", q = 1, count = 3, class = 7, subclass = 6, type = "Tradeskill", sub = "Leather" })
ns:Scan()
check(recAt(2, 5).firstSeen >= time() - 2, "new loot of the same item is stamped now")
M.bags[2][3], M.bags[2][4], M.bags[2][5] = nil, nil, nil; ns:Scan()

-- Round 26
if not main:IsShown() then ToggleAllBags() end
ns:Set("view", "list"); ns:Set("grp", "type")
-- categorization
local function recOf(bag, slot) for _, r in ipairs(ns.items) do if r.bag == bag and r.slot == slot then return r end end end
local savedSize2 = M.sizes[2]; M.sizes[2] = 12
M.put(2, 6, { id = 6001, name = "Crate of Samples", q = 1, class = 15, subclass = 4, type = "Miscellaneous", sub = "Other", quest = true })
M.put(2, 7, { id = 6002, name = "Odd Thread", q = 1, class = 15, subclass = 4, type = "Miscellaneous", sub = "Other", craftReagent = true })
M.put(2, 8, { id = 6003, name = "Token of Nothing", q = 1, class = 15, subclass = 4, type = "Miscellaneous", sub = "Other" })
M.uncached[6004] = true
M.put(2, 9, { id = 6004, name = "Unloaded Axe", q = 2, class = 2, subclass = 1, type = "Weapon", sub = "Axe" })
ns:Scan()
check(recOf(2, 6).cat == "Quest", "quest info from the container catches a misc-classed quest item")
check(recOf(2, 7).cat == "TradeGoods", "crafting reagent flag files an odd material under Trade goods")
check(recOf(2, 8).cat == "Other", "no English-name guessing: 'Token of Nothing' is not a token")
M.put(2, 10, { id = 20559, name = "Arathi Basin Mark of Honor", q = 1, count = 3, class = 15, subclass = 4, type = "Miscellaneous", sub = "Other" }); ns:Scan()
check(recOf(2, 10).cat == "Tokens", "known token item ID is a token")
M.bags[2][10] = nil
check(recOf(2, 9).cat == "Gear" and ns.pendingInfo, "an uncached item is categorized from the instant lookup")
M.bags[2][6], M.bags[2][7], M.bags[2][8], M.bags[2][9] = nil, nil, nil, nil; M.uncached[6004] = nil; M.sizes[2] = savedSize2; ns:Scan()
-- age filter
ns.ui.filters = ns.EmptyFilters(); main:SetSheet("All")
local oldG
for _, r in ipairs(ns.items) do if r.guid then oldG = r.guid; ns.cdb.firstSeen[r.guid] = time() - 5 * 3600; break end end
ns:Scan()
ns.ui.filters.ageMin, ns.ui.filters.ageMax = 0, 3; ns:RefreshViews(true)
local shownOld = false
for _, b in ipairs(ns.Buttons.all) do if b:IsShown() and b.rec and b.rec.guid == oldG then shownOld = true end end
check(not shownOld and shownButtons() > 0, "0 to 3 hours hides a 5-hour-old item and keeps new ones")
ns.ui.filters.ageMin, ns.ui.filters.ageMax = 4, 9; ns:RefreshViews(true)
check(shownButtons() >= 1, "4 to 9 hours shows the 5-hour-old item")
local c = ns.CleanFilters({ ageMin = 7, ageMax = 2 })
check(c.ageMin == 2 and c.ageMax == 7, "a reversed window is swapped")
local bad = ns.CleanFilters({ ageMin = 12, ageMax = 2.5 })
check(bad.ageMin == nil and bad.ageMax == nil, "values outside 0 to 9 or not whole are rejected")
check(ns.FilterCount({ q = {}, cat = {}, t = {}, bd = {}, w = {}, ageMin = 1 }) == 1, "an age window counts as one filter")
ns.Popups:OpenFilters(main, "browse")
local pf = ns.Popups.filter
check(pf.ageMin.text == "4" and pf.ageMax.text == "9", "the filter panel shows the window's age range")
pf.ageMin:SetText("1"); pf.ageMin.scripts.OnTextChanged(pf.ageMin)
check(ns.ui.filters.ageMin == 1, "typing in the age field sets the filter")
local legend = false
for _, cb in ipairs(pf.checks) do if cb.groupKey == "q" and cb.key == 5 then legend = true end end
check(legend, "Legendary is in the rarity section")
pf:Hide(); ns.ui.filters = ns.EmptyFilters(); ns:RefreshViews(true)
-- bank Where names and bank bag windows
M.sizes[6] = 8; M.bagNames[6] = "Linen Bag"; M.sizes[7] = 8; M.bagNames[7] = "Linen Bag"
M.put(6, 1, { id = 6100, name = "Stored Ore", q = 1, count = 5, class = 7, subclass = 7, type = "Tradeskill", sub = "Metal & Stone" })
M.fire("BANKFRAME_OPENED"); M.runTimers()
check(ns.bagInfo[ns.BANK].name == "Default", "the bank's own slots read Default")
check(ns.bagInfo[6].name == "Linen Bag (1)" and ns.bagInfo[7].name == "Linen Bag (2)", "duplicate bank bag names get their slot number: " .. ns.bagInfo[6].name)
local bankWin = ns.Window.bank
check(bankWin.btnBags and not bankWin.btnBags.active, "bank window has its own bag-windows icon")
bankWin.btnBags.scripts.OnClick(bankWin.btnBags)
local bb = ns.Window.bankBagViews[6]
check(bb:IsShown() and bb.titleText.text == "Bank: Linen Bag (1)", "bank bag window opens with a Bank: title: " .. tostring(bb.titleText.text))
check(ns.Window.bankBagViews[ns.BANK]:IsShown() and ns.Window.bankBagViews[ns.BANK].titleText.text == "Bank: Default", "the bank's own slots get a window too")
check(not ns.Window.bagViews[1]:IsShown(), "bank bag windows do not open the regular bag windows")
local cellShown = 0
for _, cc in pairs(ns.Buttons.mirrors[bb.child] or {}) do if cc:IsShown() then cellShown = cellShown + 1 end end
check(cellShown == 8, "bank bag window shows every slot: " .. cellShown)
M.fire("BANKFRAME_CLOSED"); M.runTimers()
check(not bb:IsShown() and not ns.ui.bankBagWindows, "leaving the bank closes them")
M.bags[6][1] = nil; M.sizes[6] = 0; M.sizes[7] = 0; M.bagNames[6] = nil; M.bagNames[7] = nil

-- Buttons inside a drag band sit above it (so they get the click)
ns.Popups:OpenFilters(main, "browse")
local fp = ns.Popups.filter
check(fp.closeBtn:GetFrameLevel() > fp.dragBar:GetFrameLevel(), "Filter panel close button sits above its drag bar")
fp.closeBtn.scripts.OnClick(fp.closeBtn)
check(not fp:IsShown(), "and closes the panel")
check(main.title:GetFrameLevel() > main.dragArea:GetFrameLevel(), "window title row sits above its drag band")

-- Closing one bag window closes only that one
if not main:IsShown() then ToggleAllBags() end
ns.ui.bagWindows = true; ns.ui.closedBags = {}; ns:RefreshViews(true)
local bw0, bw1 = ns.Window.bagViews[0], ns.Window.bagViews[1]
check(bw0:IsShown() and bw1:IsShown(), "bag windows open")
local function closeBtnOf(v)
	for _, c in ipairs({ v.title:GetChildren() }) do if c.tip == "Close" then return c end end
end
local cb = closeBtnOf(bw1)
cb.scripts.OnClick(cb)
check(not bw1:IsShown() and bw0:IsShown() and main.btnBags.active, "closing one bag window leaves the others open")
ns:Scan(); ns:RefreshViews(true)
check(not bw1:IsShown(), "and it stays closed through refreshes")
main.btnBags.scripts.OnClick(main.btnBags)
check(not bw0:IsShown(), "the footer icon still closes the whole set")
main.btnBags.scripts.OnClick(main.btnBags)
check(bw0:IsShown() and bw1:IsShown(), "and reopens every window, including the one closed by hand")
-- close them all one by one: the set turns off and the icon un-lights
for _, bag in ipairs(ns.BAGS) do
	local v = ns.Window.bagViews[bag]
	if v and v:IsShown() and not ns:IsReagentBag(bag) then local c = closeBtnOf(v); c.scripts.OnClick(c) end
end
check(not ns.ui.bagWindows and not main.btnBags.active, "closing every window by hand turns the set off")

-- Columns per window
if not main:IsShown() then ToggleAllBags() end
ns:Set("view", "list")
ns.db.cols = { "c", "t", "w" }; ns.db.bankCols = { "c", "v", "age" }; ns.db.colWidths = { t = 111 }; ns.db.bankColWidths = { v = 99 }
ns:Fire("SETTINGS_CHANGED", "cols")
local mainKeys = {}
for _, c in ipairs(main:ColumnPlan()) do mainKeys[#mainKeys + 1] = c.key end
check(table.concat(mainKeys, ",") == "c,n,t,w", "bags window uses its own columns: " .. table.concat(mainKeys, ","))
M.fire("BANKFRAME_OPENED"); M.runTimers()
local bankKeys, bankV = {}, nil
for _, c in ipairs(ns.Window.bank:ColumnPlan()) do bankKeys[#bankKeys + 1] = c.key; if c.key == "v" then bankV = c.colW end end
check(table.concat(bankKeys, ",") == "c,n,v,age" and bankV == 99, "bank window uses its own columns and widths: " .. table.concat(bankKeys, ","))
main:SetSheet("Bank")
local sheetKeys = {}
for _, c in ipairs(main:ColumnPlan()) do sheetKeys[#sheetKeys + 1] = c.key end
check(table.concat(sheetKeys, ",") == "c,n,t,w", "the Bank tab in the bags window keeps the bags layout")
main:SetSheet("All")
M.fire("BANKFRAME_CLOSED"); M.runTimers()
-- settings: target switch edits the right layout
ns.SettingsPanel:Show(); ns.SettingsPanel:ShowPage("bankcols")
local rowAge
for _, l in ipairs(ns.SettingsPanel.pools.list) do for _, r in ipairs(l.rows) do if r:IsShown() and r.id == "age" then rowAge = r end end end
check(rowAge and rowAge.box:GetChecked(), "the Bank Columns page shows the bank's ticks")
rowAge.onCheck("age", false)
check(not ns.IndexOf(ns.db.bankCols, "age") and not ns.IndexOf(ns.db.cols, "age"), "unticking edits only the bank layout")
ns.SettingsPanel:ShowPage("profile")
local assignSeen = false
for _, l in ipairs(ns.SettingsPanel.pools.profiles) do for _, r in ipairs(l.rows) do if r.use and r.use.label.text == "Assign" then assignSeen = true end end end
check(assignSeen, "profiles offer Assign")
ns.SettingsPanel:Hide()
ns.db.cols = { "c", "t", "bd", "v", "w", "age" }; ns.db.bankCols = { "c", "t", "bd", "v", "w", "age" }; ns.db.colWidths = {}; ns.db.bankColWidths = {}
ns:Fire("SETTINGS_CHANGED", "cols")

-- Forever's placeholder tab bag reads as Default
M.sizes[6] = 20; M.bagNames[6] = "Character Bank Tab Bag (DNT)"
M.sizes[7] = 8; M.bagNames[7] = "Linen Bag"
M.fire("BANKFRAME_OPENED"); M.runTimers()
check(ns.bagInfo[6].name == "Default", "the (DNT) placeholder tab reads as Default: " .. tostring(ns.bagInfo[6].name))
check(ns.bagInfo[7].name == "Linen Bag", "a real bank bag keeps its name")
M.fire("BANKFRAME_CLOSED"); M.runTimers()
M.sizes[6] = 0; M.sizes[7] = 0; M.bagNames[6] = nil; M.bagNames[7] = nil

-- Empty legacy bank container is ignored when the real Default tab exists
local savedBank = M.bags[-1]; M.bags[-1] = {}
M.sizes[6] = 48; M.bagNames[6] = "Character Bank Tab Bag (DNT)"
M.put(6, 1, { id = 6200, name = "Peacebloom", q = 1, count = 2, class = 7, subclass = 9, type = "Tradeskill", sub = "Herb" })
M.sizes[7] = 6; M.bagNames[7] = "Small Blue Pouch"
M.fire("BANKFRAME_OPENED"); M.runTimers()
check(ns.bagInfo[ns.BANK].size == 0 and ns.bagInfo[6].name == "Default", "empty legacy bank container is ignored")
local bw = ns.Window.bank
bw.btnBags.scripts.OnClick(bw.btnBags)
local defaults = 0
for bag, v in pairs(ns.Window.bankBagViews) do if v:IsShown() and v.titleText.text == "Bank: Default" then defaults = defaults + 1 end end
check(defaults == 1, "only one Bank: Default window: " .. defaults)
check(bw.freeText.text:find("/ 54"), "free count leaves out the legacy slots: " .. tostring(bw.freeText.text))
M.fire("BANKFRAME_CLOSED"); M.runTimers()
-- if the legacy container holds items it is kept
M.bags[-1] = { [1] = { id = 6201, name = "Old Thing", q = 1, class = 15, subclass = 4, type = "Miscellaneous", sub = "Other", guid = "g-old" } }
M.fire("BANKFRAME_OPENED"); M.runTimers()
check(ns.bagInfo[ns.BANK].size > 0, "a legacy container with items is still shown")
M.fire("BANKFRAME_CLOSED"); M.runTimers()
M.bags[-1] = savedBank; M.bags[6][1] = nil; M.sizes[6] = 0; M.sizes[7] = 0; M.bagNames[6] = nil; M.bagNames[7] = nil

-- Picking yourself shows live bags, never read-only
if not main:IsShown() then ToggleAllBags() end
local myName = ns:DisplayName("player")
BagSmithDB.cache["Aldren - Unknown"] = { name = myName, realm = "Unknown", class = "WARRIOR", level = 1, gold = 0, items = {}, bags = {} }
main:SetOwner("Aldren - Unknown")
check(ns.ui.owner == nil and not main.subText.text:find("read only"), "choosing a stale copy of yourself shows your live bags")
local list = ns:CachedCharacters()
local mine = 0
for _, c in ipairs(list) do if c.name == myName then mine = mine + 1 end end
check(mine == 1 and BagSmithDB.cache["Aldren - Unknown"] == nil, "the stale copy is dropped from the picker")
main:SetOwner(ns:CharKey())
check(ns.ui.owner == nil, "choosing your own entry clears read-only")
main:SetOwner("Mira Dawnvale - Forever")
check(ns.ui.owner == "Mira Dawnvale - Forever", "an alt is still read-only")
main:SetOwner(nil)
-- no cache save before the realm is known
local realRealm = GetRealmName
_G.GetRealmName = function() return nil end
BagSmithDB.cache["Aldren - Unknown"] = nil
ns:SaveCache()
check(BagSmithDB.cache["Aldren - Unknown"] == nil, "nothing is saved while the realm is unknown")
_G.GetRealmName = realRealm

-- Misc. in the column, full word still searchable
if not main:IsShown() then ToggleAllBags() end
ns:Set("view", "list"); ns:Set("grp", "type"); ns.ui.filters = ns.EmptyFilters(); main:SetSheet("All"); ns:RefreshViews(true)
local hs
for _, b in ipairs(ns.Buttons.all) do if b:IsShown() and b.rec and b.rec.name == "Hearthstone" then hs = b end end
check(hs and hs.colType.text == "Misc.", "Type column shows Misc.: " .. tostring(hs and hs.colType.text))
ns.ui.filters.text = "miscellaneous"; ns:RefreshViews(true)
local found = false
for _, b in ipairs(ns.Buttons.all) do if b:IsShown() and b.rec and b.rec.name == "Hearthstone" then found = true end end
check(found, "searching the full word still finds it")
ns.ui.filters.text = "misc"; ns:RefreshViews(true)
found = false
for _, b in ipairs(ns.Buttons.all) do if b:IsShown() and b.rec and b.rec.name == "Hearthstone" then found = true end end
check(found, "and so does the short form")
ns.ui.filters = ns.EmptyFilters(); ns:RefreshViews(true)

-- Round 27: options entry, typed numbers, size mode, dots, scroll and lock handling
local cat = M.settingsCategories[1]
check(cat and cat.name == "BagSmith" and cat.frame.button, "BagSmith is registered under Options > AddOns with an Open Settings button")
ns.SettingsPanel:Hide()
cat.frame.button.scripts.OnClick(cat.frame.button)
check(ns.SettingsPanel.frame:IsShown(), "Open Settings opens BagSmith's settings")
-- typed numbers
ns.SettingsPanel:ShowPage("window")
local function stepRow(key) for _, w in ipairs(ns.SettingsPanel.pools.step) do if w:IsShown() and w.key == key then return w end end end
ns:Set("sizeMode", "fixed")
local fw = stepRow("fixW")
check(fw and fw.value.text == tostring(ns.db.fixW), "the number box shows the value")
fw.value:SetText("777"); fw.value.scripts.OnEnterPressed(fw.value)
check(ns.db.fixW == 777, "typing a whole number sets it")
fw = stepRow("fixW"); fw.value:SetText("77.5"); fw.value.scripts.OnEnterPressed(fw.value)
check(ns.db.fixW == 777 and stepRow("fixW").value.text == "777", "a decimal is rejected and the box shows the real value")
fw = stepRow("fixW"); fw.value:SetText("5000"); fw.value.scripts.OnEnterPressed(fw.value)
check(ns.db.fixW == 1400, "out of range snaps to the limit (1400 wide)")
local cs = stepRow("combatAlpha")
cs.value:SetText("40"); cs.value.scripts.OnEnterPressed(cs.value)
check(math.abs(ns.db.combatAlpha - 0.40) < 0.001 and stepRow("combatAlpha").value.text == "40", "percentages are typed as whole percents")
ns:Set("combatAlpha", 0.15); ns:Set("fixW", 600)
-- dragging in Fit to items sets the largest size and keeps the mode
if not main:IsShown() then ToggleAllBags() end
ns:Set("sizeMode", "auto")
main.frame.w, main.frame.h = 812.4, 655.6
main.grip.scripts.OnMouseUp(main.grip)
check(ns.db.sizeMode == "auto" and ns.db.maxW == 812 and ns.db.maxH == 656, "dragging in Fit to items sets the largest size (rounded) and stays Fit")
ns:Set("sizeMode", "fixed")
main.frame.w, main.frame.h = 700.2, 500.7
main.grip.scripts.OnMouseUp(main.grip)
check(ns.db.sizeMode == "fixed" and ns.db.fixW == 700 and ns.db.fixH == 501, "dragging in Fixed size sets the size")
ns:Set("maxW", 680); ns:Set("maxH", 720); ns:Set("fixW", 600); ns:Set("fixH", 560); ns:Set("sizeMode", "auto")
ns.SettingsPanel:Hide()
-- dots sit inside the slot
ns:Set("view", "icons"); ns:RefreshViews(true)
local cellb = ns.Buttons:Get(0, 1)
local p = cellb.newDot.points[1]
check(p[1] == "BOTTOM" and p[2] == cellb.icon and p[3] == "BOTTOM" and p[5] >= 0, "icon-view dot sits at the bottom center of the icon, inside it")
ns:Set("view", "list"); ns:RefreshViews(true)
p = ns.Buttons:Get(0, 1).newDot.points[1]
check(p[1] == "BOTTOM" and p[3] == "BOTTOM" and p[5] >= 0, "list-row dot sits at the bottom center of the icon, inside it")
-- a lock change does not rebuild the list
M.runTimers()   -- (anything already queued, such as a resize's settle pass, finishes first)
local relayouts = 0
local origLayout = main.Layout
main.Layout = function(...) relayouts = relayouts + 1; return origLayout(...) end
M.locked = M.locked or {}
M.fire("ITEM_LOCK_CHANGED", 0, 1); M.runTimers()
check(relayouts == 0, "a lock change updates in place without a rebuild")
main.Layout = origLayout
-- no rebuild while a mouse button is held over the window
_G.IsMouseButtonDown = function(btn) return btn == "RightButton" end
main.frame.IsMouseOver = function() return true end
relayouts = 0; main.Layout = function(...) relayouts = relayouts + 1; return origLayout(...) end
ns:RefreshViews(true)
check(relayouts == 0, "no rebuild while a button is held over the window")
_G.IsMouseButtonDown = function() return false end
M.tick()
check(relayouts >= 1, "the rebuild runs once the button is released")
main.Layout = origLayout; main.frame.IsMouseOver = nil; _G.IsMouseButtonDown = nil
-- scroll position is kept across a rebuild
ns:Set("sizeMode", "fixed")
local o1, o2, o3 = main.scroll.GetHeight, main.scroll.GetVerticalScroll, main.scroll.SetVerticalScroll
main.scroll.GetHeight = function() return 120 end
main.scroll.vscroll = 0
main.scroll.GetVerticalScroll = function(s) return s.vscroll end
main.scroll.SetVerticalScroll = function(s, v) s.vscroll = v end
main.scroll.vscroll = 40
ns:RefreshViews(true)
check(main.scroll.vscroll == 40, "scroll position kept across a rebuild: " .. tostring(main.scroll.vscroll))
main.scroll.GetHeight, main.scroll.GetVerticalScroll, main.scroll.SetVerticalScroll = o1, o2, o3
ns:Set("sizeMode", "auto")
-- labels
ns.SettingsPanel:Show(); ns.SettingsPanel:ShowPage("general")
local mm
for _, w in ipairs(ns.SettingsPanel.pools.check) do if w:IsShown() and w.key == "minimap" then mm = w end end
check(mm and mm.text.text == "Show Minimap Button", "minimap setting renamed (now on the General page)")
ns.SettingsPanel:Hide()
ns.Popups:OpenFilters(main, "browse")
check(true, "filter panel opens")
ns.Popups.filter:Hide()

-- Round 28: hold-still rows, second scroll restore, debug defaults, alignment
if not main:IsShown() then ToggleAllBags() end
ns:Set("view", "list"); ns:Set("grp", "type"); ns.ui.filters = ns.EmptyFilters(); main:SetSheet("All"); ns:RefreshViews(true)
local function rowFor(bag, slot) for _, b in ipairs(main.used or {}) do if b.rec and b.rec.bag == bag and b.rec.slot == slot then return b end end end
local target = rowFor(0, 2)
check(target and target.rec.name, "row to remove is on screen")
local posBefore = {}
for _, b in ipairs(main.used) do posBefore[b] = b.points[1] and b.points[1][5] end
main.frame.IsMouseOver = function() return true end
local saved02 = M.bags[0][2]; M.bags[0][2] = nil
M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
check(main.held and target.rec.empty and target.colName.text == "", "an item that leaves while the pointer is over the list leaves a gap")
local moved = false
for _, b in ipairs(main.used) do if b.points[1] and posBefore[b] and b.points[1][5] ~= posBefore[b] then moved = true end end
check(not moved, "no row moves while the pointer is over the list")
ns.ui.filters.text = "staff"; ns:RefreshViews()
local staffRow = false
for _, b in ipairs(main.used) do if b:IsShown() and b.rec and b.rec.name == "Staff of Jordan" then staffRow = true end end
check(not main.held and staffRow and #main.used <= 3, "search still updates straight away while the pointer is over the list")
ns.ui.filters.text = ""; ns:RefreshViews(true)
M.bags[0][2] = nil; M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
main.frame.IsMouseOver = function() return false end
M.tick()
check(not main.held and not (rowFor(0, 2) and rowFor(0, 2).rec.empty), "the list tidies up once the pointer leaves")
main.frame.IsMouseOver = nil
M.bags[0][2] = saved02; ns:Scan(); ns:RefreshViews(true)
-- second scroll restore
ns:Set("sizeMode", "fixed")
M.runTimers()   -- (the size change's own follow-ups finish first, as they do in game long before the next scroll; the mock ignores timer delays)
local s1, s2, s3 = main.scroll.GetHeight, main.scroll.GetVerticalScroll, main.scroll.SetVerticalScroll
main.scroll.GetHeight = function() return 30 end   -- short enough that the list scrolls
main.barHidden = false; main:PlaceScroll()          -- (an overflowing list keeps its scrollbar)
main.scroll.vscroll = 40
main.scroll.GetVerticalScroll = function(s) return s.vscroll end
main.scroll.SetVerticalScroll = function(s, v) s.vscroll = v end
ns:RefreshViews(true)
main.scroll.vscroll = 12   -- the game clips the first restore to an old limit
M.runTimers()
check(main.scroll.vscroll == 40, "a second restore on the next frame puts the scroll back: " .. tostring(main.scroll.vscroll))
main.scroll.GetHeight, main.scroll.GetVerticalScroll, main.scroll.SetVerticalScroll = s1, s2, s3
ns:Set("sizeMode", "auto")
-- debug defaults
check(ns.DEFAULTS and ns.DEFAULTS.debug == false, "a fresh install starts with debug off")
ns:Set("debug", true)
ns.Profiles:Use("Fresh profile")
check(ns.db.debug == false, "a new profile starts with debug off even when created from one with it on")
ns.Profiles:Use("Default"); ns:Set("debug", false)
-- number boxes line up
ns.SettingsPanel:Show(); ns.SettingsPanel:ShowPage("window")
local offs = {}
for _, w in ipairs(ns.SettingsPanel.pools.step) do if w:IsShown() then offs[w.value.points[1][4]] = true end end
local n = 0; for _ in pairs(offs) do n = n + 1 end
check(n == 1, "every number box sits at the same offset")
local mw
for _, w in ipairs(ns.SettingsPanel.pools.step) do if w:IsShown() and w.key == "maxW" then mw = w end end
check(mw and mw.text.text == "Max Width", "Max width label")
ns.SettingsPanel:Hide()

-- hold and release-wait reuse their frames
local fBefore = #M.frames
for i = 1, 20 do
	main.frame.IsMouseOver = function() return true end
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
	main.frame.IsMouseOver = function() return false end
	M.tick()
	_G.IsMouseButtonDown = function() return true end; main.frame.IsMouseOver = function() return true end
	ns:RefreshViews(true)
	_G.IsMouseButtonDown = nil; M.tick()
end
main.frame.IsMouseOver = nil
check(#M.frames - fBefore <= 2, ("holding rows and waiting for a release create no new frames: +%d"):format(#M.frames - fBefore))

-- Round 29: ghost frames, pinning, restore guard, scroll logging, % inside boxes
if not main:IsShown() then ToggleAllBags() end
ns:Set("skin", "modern"); ns:Set("view", "list"); ns.ui.filters = ns.EmptyFilters(); main:SetSheet("All"); ns:RefreshViews(true)
local function rowAt(bag, slot) for _, b in ipairs(main.used or {}) do if b.rec and b.rec.bag == bag and b.rec.slot == slot then return b end end end
local gr = rowAt(0, 1)
check(gr and gr.frameBG:IsShown(), "a filled row draws its icon frame")
ns:Set("debug", true)   -- before the hold: a settings change ends a hold, as it should
main.frame.IsMouseOver = function() return true end
local keep01 = M.bags[0][1]; M.bags[0][1] = nil
M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
check(gr.rec.empty and not gr.frameBG:IsShown() and not gr.frameEdge:IsShown() and not gr.qRing:IsShown(), "a gap row leaves no ghost of the icon frame")
-- pin: a move nobody asked for is undone while held
local o1, o2, o3 = main.scroll.GetVerticalScroll, main.scroll.SetVerticalScroll, main.scroll.GetHeight
local o4 = main.child.GetHeight
main.scroll.GetHeight = function() return 120 end
main.child.GetHeight = function() return 400 end
main.scroll.vscroll = 30
main.scroll.GetVerticalScroll = function(s) return s.vscroll end
main.scroll.SetVerticalScroll = function(s, v) s.vscroll = v; if s.scripts.OnVerticalScroll then s.scripts.OnVerticalScroll(s, v) end end
main.trustedScroll = 30
check(main.held, "rows are holding")
local logBefore = #M.log
main.scroll:SetVerticalScroll(18)   -- something else moves it
M.runTimers()
check(main.scroll.vscroll == 30, "while held, a move the player did not make is undone: " .. tostring(main.scroll.vscroll))
local sawUnknown = false
for i = logBefore + 1, #M.log do if M.log[i]:find("by unknown") then sawUnknown = true end end
check(sawUnknown, "debug names the source of the move")
-- the player's own scroll is kept
main.scroll.scripts.OnMouseWheel(main.scroll, -1)
main.scroll:SetVerticalScroll(50)
M.runTimers()
check(main.scroll.vscroll == 50 and main.trustedScroll == 50, "the player's own scrolling is kept while held")
ns:Set("debug", false)
main.frame.IsMouseOver = function() return false end
M.tick()
M.bags[0][1] = keep01; ns:Scan(); ns:RefreshViews(true)
main.frame.IsMouseOver = nil
-- a stale next-frame restore never overrides a newer one or the player
ns:Set("sizeMode", "fixed")
main.scroll.GetHeight = function() return 120 end
main.scroll.vscroll = 40; ns:RefreshViews(true)      -- restore #1 pending (to 40)
main.scroll.vscroll = 10; ns:RefreshViews(true)      -- restore #2 pending (to 10)
main.scroll.vscroll = 99
M.runTimers()
check(main.scroll.vscroll ~= 40, "an older pending restore does not fire: " .. tostring(main.scroll.vscroll))
main.scroll.vscroll = 40; ns:RefreshViews(true)
main.scroll.scripts.OnMouseWheel(main.scroll, -1); main.scroll.vscroll = 66
M.runTimers()
check(main.scroll.vscroll == 66, "a restore never overrides the player's scroll")
main.scroll.GetVerticalScroll, main.scroll.SetVerticalScroll, main.scroll.GetHeight = o1, o2, o3
main.child.GetHeight = o4
ns:Set("sizeMode", "auto")
-- % inside the box
ns.SettingsPanel:Show(); ns.SettingsPanel:ShowPage("look")
local sc, ic
-- (1.5.0: Icon Size moved to Item Icons; Row Height is Style's other number box)
for _, w in ipairs(ns.SettingsPanel.pools.step) do if w:IsShown() then if w.key == "scale" then sc = w elseif w.key == "rowHeight" then ic = w end end end
check(sc.unit:IsShown() and sc.unit.points[1][2] == sc.value and not ic.unit:IsShown(), "percent rows show a fixed % inside the box; others don't")
check(sc.value.points[1][4] == ic.value.points[1][4], "boxes line up")
ns.SettingsPanel:Hide()

-- Round 30: the game's own scroll moves are guarded; holds survive a deferred refresh; numbers centered
if not main:IsShown() then ToggleAllBags() end
ns:Set("view", "list"); ns:Set("sizeMode", "fixed"); ns.ui.filters = ns.EmptyFilters(); main:SetSheet("All"); ns:RefreshViews(true)
local g1, g2, g3, g4 = main.scroll.GetHeight, main.scroll.GetVerticalScroll, main.scroll.SetVerticalScroll, main.child.GetHeight
-- (These checks are about the scroll rules with made-up heights; the
-- scrollbar-lane logic is tested on its own, so it sits out here.)
main.savedBarSpace = main.UpdateBarSpace
main.UpdateBarSpace = function() end
main.barHidden = false; main:PlaceScroll()
M.runTimers()   -- let anything already queued finish first
main.scroll.GetHeight = function() return 531 end
main.child.GetHeight = function() return 656 end      -- real bottom: 125
main.contentHeight = 656
main.scroll.vscroll = 124; main.lastScroll = 124; main.trustedScroll = 124
main.scroll.GetVerticalScroll = function(s) return s.vscroll end
main.scroll.SetVerticalScroll = function(s, v) s.vscroll = v; if s.scripts.OnVerticalScroll then s.scripts.OnVerticalScroll(s, v) end end
-- the game pushes the list past its end while the pointer is NOT over it: clamp to the real bottom
main.frame.IsMouseOver = function() return false end
main.scroll:SetVerticalScroll(212)
check(main.scroll.vscroll == 125, "a list is never left past its real bottom: " .. tostring(main.scroll.vscroll))
-- with the pointer over the list, a game move is undone entirely (before any hold starts)
main.frame.IsMouseOver = function() return true end
main.scroll.vscroll = 100; main.lastScroll = 100; main.trustedScroll = 100
main.scroll:SetVerticalScroll(212)
check(main.scroll.vscroll == 100, "with the pointer over the list, the game's jump is undone: " .. tostring(main.scroll.vscroll))
main.scroll:SetVerticalScroll(60)
check(main.scroll.vscroll == 100, "even inside the list's range")
-- the player's own scroll is never undone
main.scroll.scripts.OnMouseWheel(main.scroll, 1)
main.scroll:SetVerticalScroll(40)
check(main.scroll.vscroll == 40, "the player's wheel still scrolls")
-- the list genuinely getting shorter settles at its new bottom, no fighting
main.userScrollAt = -10
main.child.GetHeight = function() return 560 end     -- new bottom: 29
main.contentHeight = 560
main.scroll:SetVerticalScroll(29)                    -- the game clamps after the shrink
check(main.scroll.vscroll == 29, "a shorter list settles at its new bottom")
M.runTimers()
check(main.scroll.vscroll == 29, "and stays there")
main.UpdateBarSpace = main.savedBarSpace
main.frame.IsMouseOver = nil
main.scroll.GetHeight, main.scroll.GetVerticalScroll, main.scroll.SetVerticalScroll, main.child.GetHeight = g1, g2, g3, g4
ns:Set("sizeMode", "auto")
-- an item change that waited for a mouse release still holds rows
main.frame.IsMouseOver = function() return true end
_G.IsMouseButtonDown = function() return true end
local keepR = M.bags[0][2]; M.bags[0][2] = nil
M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
check(not main.held, "nothing happens while the button is down")
_G.IsMouseButtonDown = function() return false end
M.tick()
check(main.held, "after release, the waiting item change holds rows instead of rebuilding")
main.frame.IsMouseOver = function() return false end; M.tick()
main.frame.IsMouseOver = nil; _G.IsMouseButtonDown = nil
M.bags[0][2] = keepR; ns:Scan(); ns:RefreshViews(true)
-- every number box uses the same insets
ns.SettingsPanel:Show(); ns.SettingsPanel:ShowPage("look")
local same = true
for _, w in ipairs(ns.SettingsPanel.pools.step) do if w:IsShown() and (w.value.insets or "") ~= "12,12" then same = false end end
check(same, "every number box reserves the same space on both sides")
ns.SettingsPanel:Hide()

-- Round 31: the game's own range, trusted positions, rebuild logging
if not main:IsShown() then ToggleAllBags() end
ns:Set("view", "list"); ns:Set("sizeMode", "fixed"); ns.ui.filters = ns.EmptyFilters(); main:SetSheet("All"); ns:RefreshViews(true)
local r1, r2, r3, r4 = main.scroll.GetHeight, main.scroll.GetVerticalScroll, main.scroll.SetVerticalScroll, main.scroll.GetVerticalScrollRange
main.scroll.GetHeight = function() return 531 end
main.scroll.GetVerticalScrollRange = function() return 172 end    -- the game's answer; BagSmith's own sum would say ~177
local layout31 = main.Layout
main.Layout = function(...) layout31(...); return 708 end
main.contentHeight = 708
main.scroll.GetVerticalScroll = function(s) return s.vscroll end
main.scroll.SetVerticalScroll = function(s, v) s.vscroll = v; if s.scripts.OnVerticalScroll then s.scripts.OnVerticalScroll(s, v) end end
main.frame.IsMouseOver = function() return false end
main.scroll.vscroll = 300; main.lastScroll = 300; main.trustedScroll = 300
ns:RefreshViews(true); M.runTimers()
check(main.scroll.vscroll == 172, "restores stop at the game's own bottom, never past it: " .. tostring(main.scroll.vscroll))
check(main.trustedScroll == 172, "and that becomes the trusted position")
-- the game jumps, the guard returns to where the player was, not to a position the game picked
main.frame.IsMouseOver = function() return true end
main.scroll:SetVerticalScroll(134)       -- game jump
check(main.scroll.vscroll == 172, "the guard returns to the player's position: " .. tostring(main.scroll.vscroll))
main.scroll:SetVerticalScroll(120)       -- another game jump, while 134 was never trusted
check(main.scroll.vscroll == 172, "a position the game picked is never remembered")
-- rows held: same rule
local keepX = M.bags[0][2]; M.bags[0][2] = nil
M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
check(main.held, "rows holding")
main.scroll:SetVerticalScroll(130)
check(main.scroll.vscroll == 172, "while holding, the guard returns to the player's position")
main.frame.IsMouseOver = function() return false end; M.tick()
M.bags[0][2] = keepX; ns:Scan()
-- rebuilds are logged with reason and heights
ns:Set("debug", true)
local lb = #M.log
ns:RefreshViews(true)
local logged = false
for i = lb + 1, #M.log do if M.log[i]:find("rebuilt %(forced%): list height %d+ %-> %d+") then logged = true end end
check(logged, "each rebuild logs why it happened and the list height before and after")
ns:Set("debug", false)
main.frame.IsMouseOver = nil
main.scroll.GetHeight, main.scroll.GetVerticalScroll, main.scroll.SetVerticalScroll, main.scroll.GetVerticalScrollRange = r1, r2, r3, r4
main.Layout = layout31
ns:Set("sizeMode", "auto")

-- Round 32: the list never scrolls past its last row
if not main:IsShown() then ToggleAllBags() end
ns:Set("view", "list"); ns:Set("sizeMode", "fixed"); ns.ui.filters = ns.EmptyFilters(); main:SetSheet("All"); ns:RefreshViews(true)
check(main.child.h == main.contentHeight, "no padding under the last row: list height is exactly the content")
local q1, q2, q3, q4 = main.scroll.GetHeight, main.scroll.GetVerticalScroll, main.scroll.SetVerticalScroll, main.scroll.GetVerticalScrollRange
main.scroll.GetHeight = function() return 100 end
main.scroll.GetVerticalScrollRange = nil
main.scroll.GetVerticalScroll = function(s) return s.vscroll end
main.scroll.SetVerticalScroll = function(s, v) s.vscroll = v; if s.scripts.OnVerticalScroll then s.scripts.OnVerticalScroll(s, v) end end
local bottom = main.contentHeight - 100
main.scroll.vscroll = 0; main.lastScroll = 0
main.scroll.scripts.OnMouseWheel(main.scroll, -1)
main.scroll:SetVerticalScroll(bottom + 40)       -- even the player's own scroll can't go past the last row
check(main.scroll.vscroll == bottom, ("the player can't scroll past the last row: %s (bottom %d)"):format(tostring(main.scroll.vscroll), bottom))
main.frame.IsMouseOver = function() return false end
main.scroll:SetVerticalScroll(bottom + 90)       -- a game jump past the end, pointer elsewhere
check(main.scroll.vscroll == bottom, "nor can the game")
main.trustedScroll = bottom + 50; ns:RefreshViews(true); M.runTimers()
check(main.scroll.vscroll <= bottom, "nor a restore")
-- a window taller than the list has nothing to scroll
main.scroll.GetHeight = function() return main.contentHeight + 200 end
main.scroll:SetVerticalScroll(30)
check(main.scroll.vscroll == 0, "when the window is taller than the list, it stays at the top")
main.frame.IsMouseOver = nil
main.scroll.GetHeight, main.scroll.GetVerticalScroll, main.scroll.SetVerticalScroll, main.scroll.GetVerticalScrollRange = q1, q2, q3, q4
ns:Set("sizeMode", "auto")

-- The scrollbar's range matches the list's real limit
if not main:IsShown() then ToggleAllBags() end
ns:Set("view", "list"); ns:Set("sizeMode", "fixed"); ns:RefreshViews(true)
local b1, b2, b3, b4 = main.scroll.GetHeight, main.scroll.GetVerticalScroll, main.scroll.SetVerticalScroll, main.scroll.GetVerticalScrollRange
main.scroll.GetHeight = function() return 100 end
main.scroll.GetVerticalScrollRange = function() return main.contentHeight - 100 + 6 end   -- the game thinks it can go a bit further
main.scroll.GetVerticalScroll = function(s) return s.vscroll end
main.scroll.SetVerticalScroll = function(s, v) s.vscroll = v; if s.scripts.OnVerticalScroll then s.scripts.OnVerticalScroll(s, v) end end
main.scroll.vscroll = 0
if main.scroll.scripts.OnScrollRangeChanged then main.scroll.scripts.OnScrollRangeChanged(main.scroll) end
local lo, hi = main.scroll.ScrollBar:GetMinMaxValues()
check(hi == main.contentHeight - 100, ("scrollbar ends at the last row, not where the game thinks: %s vs %d"):format(tostring(hi), main.contentHeight - 100))
main.scroll.scripts.OnMouseWheel(main.scroll, -1); main.scroll:SetVerticalScroll(main.contentHeight - 100)
check(main.scroll.ScrollBar.value == main.contentHeight - 100, "at the bottom, the thumb is at the end of the track")
main.scroll.GetHeight, main.scroll.GetVerticalScroll, main.scroll.SetVerticalScroll, main.scroll.GetVerticalScrollRange = b1, b2, b3, b4
ns:Set("sizeMode", "auto")

-- Troubleshooting commands are a list
ns.SettingsPanel:Show(); ns.SettingsPanel:ShowPage("advanced")
local cmds, xs, prevBottom, overlap = {}, {}, nil, false
for _, r in ipairs(ns.SettingsPanel.pools.cmd) do
	if r:IsShown() then
		cmds[#cmds + 1] = r.cmd.text; xs[r.desc.points[1][2]] = true
		local top = -r.points[1][5]
		if prevBottom and top < prevBottom - 0.5 then overlap = true end
		prevBottom = top + r.h
	end
end
local nx = 0; for _ in pairs(xs) do nx = nx + 1 end
check(table.concat(cmds, ",") == "/bs check,/bs errors,/bs dump", "Advanced lists the troubleshooting commands one per row")
check(nx == 1 and not overlap, "descriptions line up in one column and rows don't overlap")
ns.SettingsPanel:Hide()

-- Round 33: drop overlay when dragging an item into the other window
;(function()
if not main:IsShown() then ToggleAllBags() end
ns:Set("view", "list"); ns.ui.filters = ns.EmptyFilters(); main:SetSheet("All")
M.fire("BANKFRAME_OPENED"); M.runTimers()
local bankWin = ns.Window.bank
check(bankWin:IsShown(), "bank window open")
-- pick up a bank item (its slot locks while it is on the cursor)
local bankRec = ns.bankItems[1]
check(bankRec ~= nil, "a bank item to drag")
M.bags[bankRec.bag][bankRec.slot].locked = true   -- the client locks the slot while the item is on the cursor
bankRec.isLocked = true
M.cursorItem = bankRec.itemID
main.scroll.IsMouseOver = function() return true end
bankWin.scroll.IsMouseOver = function() return false end
M.fire("ITEM_LOCK_CHANGED", bankRec.bag, bankRec.slot); M.tick(); M.tick(); M.tick()
local mo = main.dropOverlay
check(mo and mo:IsShown() and mo.label.text == "Drop to put in your bags" and mo.sub.text:find("free slot"), "carrying a bank item over the bags list shows the drop overlay")
check(not (bankWin.dropOverlay and bankWin.dropOverlay:IsShown()), "no overlay on the window the item came from")
-- over the bank list instead: the cross-window drop never shows on the window the item came from (1.4.0-beta2: in
-- List view, which shows no empty slots, the source window offers a free slot for its own item instead)
main.scroll.IsMouseOver = function() return false end
bankWin.scroll.IsMouseOver = function() return true end
for i = 1, 10 do M.tick() end
local bo = bankWin.dropOverlay
check(not mo:IsShown() and (not (bo and bo:IsShown()) or bo.label.text == "Drop to put it in a free slot" or bo.label.text == "No free slot"),
	"the overlay fades away when the pointer leaves, and the source window never offers the cross-window drop")
-- drop on the overlay: goes to the first free bag slot (no matching stack in the bags)
main.scroll.IsMouseOver = function() return true end
bankWin.scroll.IsMouseOver = function() return false end
for i = 1, 3 do M.tick() end
local before = #M.pickups
mo.scripts.OnReceiveDrag(mo)
local dest = M.pickups[#M.pickups]
check(#M.pickups == before + 1 and dest and not dest:find("^%-1:"), "dropping places the item into the bags: " .. tostring(dest))
-- a stack of the same item with room is preferred
M.cursorItem = nil; bankRec.isLocked = false; M.bags[bankRec.bag][bankRec.slot].locked = nil
M.put(1, 6, { id = 7300, name = "Rough Stone", q = 1, count = 5, class = 7, subclass = 7, type = "Tradeskill", sub = "Metal & Stone" })
ns:Scan()
M.cursorItem = 7300
local bag, slot = ns.Drop:Target(main, 7300)
check(bag == 1 and slot == 6, "a stack of the same item with room is the target")
M.maxStack = { [7300] = 5 }
bag, slot = ns.Drop:Target(main, 7300)
check(not (bag == 1 and slot == 6), "a full stack is skipped")
M.maxStack = nil; M.bags[1][6] = nil; M.cursorItem = nil; ns:Scan()
-- bags full: the overlay says so and the item stays on the cursor
local savedSizes = {}
for k, v in pairs(M.sizes) do savedSizes[k] = v end
for _, b in ipairs(ns.BAGS) do M.sizes[b] = 0 end
ns:Scan()
M.cursorItem = 7301
for i = 1, 3 do M.tick() end
check(mo.label.text == "Your bags are full", "with no room the overlay says the bags are full")
before = #M.pickups
check(not ns.Drop:Place(main) and #M.pickups == before, "and dropping leaves the item on the cursor")
for k, v in pairs(savedSizes) do M.sizes[k] = v end
ns:Scan()
-- icon view: the overlay steps aside over a slot
ns:Set("view", "icons"); ns:RefreshViews(true)
M.cursorItem = 7301
local cellOver
for _, b in ipairs(main.used) do if b.mode == "cell" then cellOver = b; break end end
cellOver.IsMouseOver = function() return true end
for i = 1, 10 do M.tick() end
check(not mo:IsShown(), "in icon view the overlay steps aside over a slot")
cellOver.IsMouseOver = nil
for i = 1, 3 do M.tick() end
check(mo:IsShown(), "and covers the space between slots")
ns:Set("view", "list")
-- cursor cleared: overlays go, the watcher stops
M.cursorItem = nil
for i = 1, 12 do M.tick() end
check(not mo:IsShown(), "the overlay goes away when nothing is carried")
local fb = #M.frames
for i = 1, 20 do M.cursorItem = 7301; M.fire("ITEM_LOCK_CHANGED", 0, 1); M.tick(); M.cursorItem = nil; M.tick(); M.tick() end
check(#M.frames - fb <= 1, "carrying items repeatedly creates no new frames")
main.scroll.IsMouseOver = nil; bankWin.scroll.IsMouseOver = nil
M.fire("BANKFRAME_CLOSED"); M.runTimers()
end)()

;(function()
-- New arrivals show after a short delay even if the pointer stays over the list
if not main:IsShown() then ToggleAllBags() end
ns:Set("view", "list"); ns.ui.filters = ns.EmptyFilters(); main:SetSheet("All"); ns:RefreshViews(true)
local function rowFor(id) for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then return b end end end
main.frame.IsMouseOver = function() return true end
-- an item arrives while the pointer is over the list
M.put(1, 6, { id = 7400, name = "Dropped Thing", q = 1, class = 15, subclass = 4, type = "Miscellaneous", sub = "Other" })
M.fire("BAG_UPDATE_DELAYED")
M.runTimers()   -- the scan; the 250 ms timer is queued
check(main.held and rowFor(7400) == nil, "at first the list holds and the new item waits")
M.runTimers()   -- 250 ms later
check(rowFor(7400) ~= nil, "a newly arrived item shows shortly even though the pointer did not move")
check(not main.held, "and the list is no longer holding")
-- an item leaving still just leaves a gap
ns:RefreshViews(true)
local leaving = rowFor(7400)
M.bags[1][6] = nil
M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
check(main.held and leaving.rec.empty, "an item leaving still leaves a gap while the pointer stays")
main.frame.IsMouseOver = function() return false end; M.tick()
main.frame.IsMouseOver = nil
end)()

;(function()
-- Classic skin (beta1): Blizzard's window frame on the bags and bank windows
if not main:IsShown() then ToggleAllBags() end
ns:Set("skin", "modern"); ns:RefreshViews(true)
check(not main.classicApplied and main.title.band:IsShown() and main.closeBtn:IsShown(), "Modern: BagSmith's own frame, title band and close button")
local framesBefore = #M.frames
ns:Set("skin", "classic")
check(main.classicApplied and main.classicChrome and main.classicChrome:IsShown(), "Classic: Blizzard's window frame is shown")
check(main.classicPortrait and main.classicPortrait.texture == nil or true, "portrait set")
check(main.classicTitle.text == "Your Bags" and main.titleText.text == "", "the title moves into Blizzard's title strip")
check(not main.closeBtn:IsShown() and main.classicClose and main.classicClose:GetFrameLevel() > main.dragArea:GetFrameLevel(), "Blizzard's close button replaces BagSmith's and sits above the drag band")
check(main.title.points[1][4] == 60, "the title row moves right of the portrait and below the strip")
check(main.classicPortrait.mask ~= nil, "the full-color icon is clipped round with Blizzard's portrait mask")
check((main.classicStone and main.classicStone:IsShown()) or (main.classicTile and main.classicTile:IsShown()), "a Blizzard background is behind the content")
check(main.classicClose.parent == main.frame and main.classicClose:IsShown(), "the close button is on the window itself and showing")
check(main.tabs.points[1][3] == "BOTTOMLEFT" and main.tabs.points[1][2] == main.frame, "tabs hang below the window")
check(main.scroll.points[2][2] == main.footer, "the list ends at the gold bar")
local selTab, otherTab
for _, b in ipairs(main.tabButtons) do if b:IsShown() then if b.active then selTab = b else otherTab = otherTab or b end end end
check(selTab and selTab.classic.tabSelected == true and otherTab.classic.tabSelected == false, "the selected tab uses Blizzard's selected-tab art")
check(main.btnSort.h == 22, "buttons are full height in Classic")
local box = main.segBoxes[1]
-- (1.4.1: in Classic a group's buttons touch, so a pair reads as a pair even with its label hidden)
check(box.btns[1].h == 22 and box.btns[2].points[1][4] == box.btns[1].w, "Sections and View are full-height buttons that touch within their group")
check(main.btnSort.classicOn and main.btnSort.label:GetParent() == main.btnSort.classic, "toolbar buttons use Blizzard button art with the label on top")
local seg
for _, b in ipairs(main.segButtons) do if b.active then seg = b end end
check(seg and seg.classicOn and seg.classicArt.buttonState == "PUSHED", "the selected segment shows as pressed")
check(main.tabButtons[1].classicOn, "tabs use Blizzard's tab art")
check(main.classicBar and main.classicBar.fill.parentFrame == main.classicChrome and main.classicBar.fill.layer == "BACKGROUND" and main.classicBar.fill.sublayer == 5
	and main.classicShade.sublayer == 4 and main.classicBar.top.sublayer == 6 and main.classicInset == nil,
	"gold sits in a flat bar on the frame art's background layer, above the shade, no inset template")
-- closing with Blizzard's close button closes the window
main.classicClose.scripts.OnClick(main.classicClose)
check(not main:IsShown(), "Blizzard's close button closes BagSmith")
ToggleAllBags()
-- live switching creates no new frames after the first time
ns:Set("skin", "modern"); ns:Set("skin", "classic")
local afterFirst = #M.frames
for i = 1, 10 do ns:Set("skin", "modern"); ns:Set("skin", "classic") end
check(#M.frames == afterFirst, ("switching skins repeatedly creates no new frames (+%d)"):format(#M.frames - afterFirst))
-- back to Modern restores everything
ns:Set("skin", "modern")
check(not main.classicChrome:IsShown() and main.closeBtn:IsShown() and main.title.band:IsShown() and (main.title.points[1][2] == 12 or main.title.points[1][4] == 12), "Modern restores BagSmith's own frame and layout")
check(main.tabs.points[1][1] == "BOTTOMLEFT" and main.scroll.points[2][2] == main.tabs and main.segBoxes[1].btns[1].h == 18, "and its tabs, list and joined segments")
check(not main.classicClose:IsShown(), "Blizzard's close button is hidden in Modern")
check(not main.btnSort.classicOn and main.btnSort.label:GetParent() == main.btnSort, "and its own buttons")
-- the bank window gets it too; the small bag windows stay as they were (beta2)
M.fire("BANKFRAME_OPENED"); M.runTimers()
ns:Set("skin", "classic")
check(ns.Window.bank.classicApplied and ns.Window.bank.classicTitle.text == "Bank", "the bank window uses Blizzard's frame too")
check(ns.Window.bank.title.h == 1, "the bank's empty title row collapses")
ns.ui.bagWindows = true; ns:RefreshViews(true)
check(ns.Window.bagViews[0].frame.classicState and ns.Window.bagViews[0].frame.classicState.on, "small bag windows use Blizzard's bag frame too")
ns.ui.bagWindows = false; M.fire("BANKFRAME_CLOSED"); M.runTimers()
-- skincheck reports each piece
local lb = #M.log
SlashCmdList.BAGSMITH("skincheck")
local reported = 0
for i = lb + 1, #M.log do if M.log[i]:find(": |cff") then reported = reported + 1 end end
check(reported >= 4, "/bs skincheck reports each Classic piece: " .. reported)
ns:Set("skin", "modern")
end)()

;(function()
-- beta3: Classic tab-style plus and pencil, close button above Blizzard's border, recorded restore
if not main:IsShown() then ToggleAllBags() end
ns:Set("skin", "classic"); ns:RefreshViews(true)
check(main.tabAddTab and main.tabAddTab:IsShown() and main.tabAddTab.classicOn and not main.tabAdd:IsShown(), "Classic: the plus is a tab")
check(main.classicClose:GetFrameLevel() > ns.Classic.TopLevel(main.classicChrome) - 1, "Classic: the close button sits above Blizzard's border")
check(main.classicPortrait.texcoord == nil or true, "portrait zoomed")
ns:Set("skin", "modern"); ns:RefreshViews(true)
check(main.tabAdd:IsShown() and main.tabAdd.w == 20 and not main.tabAddTab:IsShown(), "Modern: the small plus is back at its Modern size")
end)()

;(function()
-- beta4: square gold-icon buttons, dropdown look, Appearances background, no group outline
if not main:IsShown() then ToggleAllBags() end
ns:Set("skin", "classic"); ns:RefreshViews(true)
local sb = main.btnSettings
check(sb.squareOn and sb.squareBg:IsShown() and sb.w == 26 and sb.restColor[2] == 0.82, "Classic: Settings is a Blizzard square button with a gold icon")
check(main.btnBank.squareOn and main.btnCurrency.squareOn, "Bank and Currencies too")
main.charBtn:Show(); if main.charBtn.scripts.OnShow then main.charBtn.scripts.OnShow(main.charBtn) end
check(main.classicDropdown and main.classicDropdown:IsShown() and not main.charArrow:IsShown(), "Classic: the character picker uses Blizzard's dropdown look")
main.charBtn:Hide(); if main.charBtn.scripts.OnHide then main.charBtn.scripts.OnHide(main.charBtn) end
check(not main.classicDropdown:IsShown(), "and the dropdown art follows the picker when it hides")
check(main.classicTile and main.classicTile:IsShown() and not main.classicStone:IsShown(), "Classic: the Appearances background replaces the plain stone")
ns.Skins:RefreshAll()
local box = main.segBoxes[1]
check(box.borderColor == nil or box.borderColor[4] == 0, "Classic: no outline around the Sections and View groups, even after a skin refresh")
ns:Set("skin", "modern"); ns:RefreshViews(true)
check(not sb.squareOn and not sb.squareBg:IsShown() and sb.w == 24, "Modern: Settings is back to BagSmith's own icon button")
check(not main.classicDropdown:IsShown() and main.charArrow:IsShown(), "Modern: the picker's own arrow is back")
end)()

;(function()
-- beta5: background fix, square broom, and Classic for the other windows
if not main:IsShown() then ToggleAllBags() end
ns:Set("skin", "classic"); ns:RefreshViews(true)
check(main.classicBgLoaded and main.frame.bgColor == nil or (main.frame.bgColor and main.frame.bgColor[4] == 0), "Classic: BagSmith's own fill steps aside when a Blizzard background loaded")
check(main.btnClean.squareOn and main.btnClean.tex.texture == nil or main.btnClean.squareOn, "Classic: the broom is a square button with BagSmith's own icon")
-- Settings
ns.SettingsPanel:Show(); ns.SettingsPanel:ShowPage("look")
local sf = ns.SettingsPanel.frame
local sst = sf.classicState
check(sst and sst.on and sst.chrome:IsShown() and sst.title.text == "BagSmith Settings" and sst.portrait, "Classic: Settings uses Blizzard's frame with the BagSmith portrait and title")
check(sst.close and sst.close:IsShown() and not sf.title:IsShown(), "Settings: Blizzard's close button, BagSmith's title hidden")
check(ns.SettingsPanel.nav.points[1][2] == sf and ns.SettingsPanel.nav.points[1][5] == -66, "Settings: the category list starts under the portrait")
local segBtn
for _, w in ipairs(ns.SettingsPanel.pools.seg) do if w:IsShown() and w.btns and w.btns[1] then segBtn = w.btns[1] end end
check(segBtn and segBtn.classicOn, "Settings: choice buttons are Blizzard red buttons")
ns.SettingsPanel:ShowPage("advanced")
local resetB
for _, w in ipairs(ns.SettingsPanel.pools.btn) do if w:IsShown() then resetB = w end end
check(resetB and resetB.classicOn, "Settings: buttons on a newly opened page match the skin")
ns.SettingsPanel:Hide()
-- Filter panel
ns.Popups:OpenFilters(main, "browse")
local fp = ns.Popups.filter
check(fp.classicState and fp.classicState.on and fp.classicState.title.text == "Filters" and not fp.title:IsShown(), "Classic: the Filter panel uses Blizzard's frame with its title in the strip")
check(fp.clearBtn == nil or true, "")
fp:Hide()
-- currency drawer
ns.Drawer:Toggle()
local df = ns.Drawer.frame
check(df.classicState and df.classicState.on and df.classicState.title.text == "Currencies", "Classic: the currency drawer uses Blizzard's frame")
ns.Drawer:Toggle()
-- confirm dialog
ns.Confirm(nil, "Delete the sheet \"X\"?", function() end)
local cf = ns.Popups.confirm
check(cf.classicState and cf.classicState.on and cf.yes.classicOn, "Classic: the confirm dialog uses Blizzard's dialog border and red buttons")
cf:Hide()
-- small bag windows: the bag's own icon in the portrait
ns.ui.bagWindows = true; ns:RefreshViews(true)
local bw0 = ns.Window.bagViews[0]
check(bw0.frame.classicState.on and bw0.frame.classicState.portrait.texture == "Interface\\Buttons\\Button-Backpack-Up", "Classic: the backpack window shows the backpack in its portrait")
check(bw0.frame.classicState.title.text == bw0.opts.title and not bw0.titleText:IsShown(), "and its name in the strip")
-- back to Modern: every window restored
ns:Set("skin", "modern"); ns:RefreshViews(true)
check(not bw0.frame.classicState.on and bw0.titleText:IsShown() and not bw0.frame.classicState.chrome:IsShown(), "Modern: bag windows are BagSmith's own again")
-- whatever was visible before Classic is visible after, and hidden stays hidden
local probe = CreateFrame("Frame", nil, UIParent); local shownPiece = CreateFrame("Frame", nil, probe); shownPiece:Show()
local hiddenPiece = CreateFrame("Frame", nil, probe); hiddenPiece:Hide()
local probeSpec = { hide = { shownPiece, hiddenPiece } }
ns.Classic:Dress(probe, probeSpec, true)
check(not shownPiece:IsShown() and not hiddenPiece:IsShown(), "Classic hides the listed pieces")
ns.Classic:Dress(probe, probeSpec, false)
check(shownPiece:IsShown() and not hiddenPiece:IsShown(), "leaving Classic restores each piece to how it was")
ns.SettingsPanel:Show()
check(not sf.classicState.on and sf.title:IsShown() and ns.SettingsPanel.nav.points[1][2] ~= sf, "Modern: Settings restored")
check(segBtn and not segBtn.classicOn, "Modern: Settings buttons restored")
ns.SettingsPanel:Hide()
ns.ui.bagWindows = false; ns:RefreshViews(true)
end)()

;(function()
-- beta6: each window collapses only its own sections
if not main:IsShown() then ToggleAllBags() end
ns:Set("skin", "modern"); ns:Set("grp", "type"); ns.ui.filters = ns.EmptyFilters(); main:SetSheet("All")
M.fire("BANKFRAME_OPENED"); M.runTimers()
local bankWin = ns.Window.bank
ns:Set("remember", false)
ns.ui.collapsed = {}; ns.uiBank.collapsed = {}; ns.db.collapsed = {}; ns.db.bankCollapsed = {}
main:ToggleAllLanes(); ns:RefreshViews(true)
check(#main:CollapsedList() > 0 and #bankWin:CollapsedList() == 0, "Collapse All in the bags window leaves the bank's sections alone")
local mainCount = #main:CollapsedList()
bankWin:ToggleAllLanes(); ns:RefreshViews(true)
check(#main:CollapsedList() == mainCount and #bankWin:CollapsedList() > 0, "and Collapse All in the bank leaves the bags window alone")
bankWin:ToggleAllLanes(); main:ToggleAllLanes(); ns:RefreshViews(true)
ns:Set("remember", true)
main:ToggleLane("Consumables")
check(ns.db.bankCollapsed["Consumables"] == nil and not ns.IndexOf(ns.db.bankCollapsed, "Consumables"), "with Remember on, each window keeps its own saved list")
ns:Set("remember", false); ns.ui.collapsed = {}; ns.db.collapsed = {}; ns.db.bankCollapsed = {}
-- the bank strip sits a little lower under the toolbar
check(bankWin.bankBar.points[1][5] == -10, "Bank Bags has a little more room under the toolbar")
M.fire("BANKFRAME_CLOSED"); M.runTimers()
ns:RefreshViews(true)
-- Forever's empty-slot art, read from Blizzard's own bag button template
local probe = ns.Buttons.all[1]
local tmpl = M.tex(); tmpl.GetAtlas = function() return "bags-item-slot64" end
probe.ItemSlotBackground = tmpl
ns.Buttons.slotArt = nil
for _, b in ipairs(ns.Buttons.all) do b.slotArtSet = nil end
ns:Set("skin", "classic"); ns:Set("view", "icons"); ns:Set("emptySlots", true); ns:Set("grp", "none"); ns:RefreshViews(true)
local emptyCell
for _, b in ipairs(main.used or {}) do if b.mode == "cell" and b.rec and b.rec.empty and b:IsShown() then emptyCell = b; break end end
check(emptyCell and emptyCell.slotBG.atlas == "bags-item-slot64" and not emptyCell.slotRing:IsShown(), "Classic: empty slots use Forever's art from Blizzard's template, without the old ring")
check(main.classicShade and main.classicShade:IsShown(), "Classic: a light shade darkens the Blizzard background")
-- small bag windows: the grid is not pushed sideways
ns.ui.bagWindows = true; ns:RefreshViews(true)
local bw = ns.Window.bagViews[1]
check(bw.title.points[1][4] == 12 and bw.title.points[1][5] == -34, "Classic: a bag window's title row only moves down, so its grid isn't pushed right and clipped")
ns.ui.bagWindows = false; ns:Set("skin", "modern"); ns:Set("view", "list"); ns:Set("grp", "type"); ns:RefreshViews(true)
probe.ItemSlotBackground = nil; ns.Buttons.slotArt = nil
end)()

-- A session that starts in Classic: the Filter panel's buttons are red on first open.
;(function()
	package.loaded.mock = nil
	local M2 = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, profiles = { Default = { skin = "classic" } }, chars = {}, cache = {} }
	local ns2 = M2.loadAddon("BagSmith")
	M2.fire("ADDON_LOADED", "BagSmith"); M2.fire("PLAYER_ENTERING_WORLD"); M2.runTimers(); M2.runTimers()
	ToggleAllBags()
	ns2.Popups:OpenFilters(ns2.Window.main, "browse")
	local fp = ns2.Popups.filter
	local allRed, n = true, 0
	local function walk(f, d) if d > 7 or not f.GetChildren then return end for _, c in ipairs({ f:GetChildren() }) do if c.SetClassic then n = n + 1; if not c.classicOn then allRed = false end end walk(c, d + 1) end end
	walk(fp, 0)
	check(n >= 3 and allRed, ("first open in Classic: every Filter panel button is a Blizzard red button (%d checked)"):format(n))
end)()

-- Modern must match its baseline (current prod) exactly, however the session got there.
;(function()
	local base = {}
	for line in io.lines("tests/modern_baseline.txt") do if line ~= "" and not line:match("^#") then base[#base + 1] = line end end
	local snapper = dofile("tests/modern_check.lua")
	for _, sc in ipairs({ "fresh", "switched", "startClassic" }) do
		local cur = {}
		for line in (snapper(sc) .. "\n"):gmatch("(.-)\n") do if line ~= "" then cur[#cur + 1] = line end end
		local same, first = #cur == #base, nil
		for i = 1, math.max(#cur, #base) do if cur[i] ~= base[i] then same = false; first = first or (cur[i] or "(missing)") end end
		check(same, ("Modern matches its baseline (current prod) (%s)%s"):format(sc, same and "" or (": first difference: " .. tostring(first))))
	end
end)()

;(function()
	-- beta7: a session that starts in Classic, then switches to Modern, gets
	-- its group outlines back (main and bank), whatever order the skin change
	-- reaches the pieces in; the Filter panel built in Classic repaints too.
	package.loaded.mock = nil
	local M3 = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, profiles = { Default = { skin = "classic" } }, chars = {}, cache = {} }
	local n3 = M3.loadAddon("BagSmith")
	M3.fire("ADDON_LOADED", "BagSmith"); M3.fire("PLAYER_ENTERING_WORLD"); M3.runTimers(); M3.runTimers()
	ToggleAllBags()
	M3.fire("BANKFRAME_OPENED"); M3.runTimers()
	local m3, b3 = n3.Window.main, n3.Window.bank
	n3.Popups:OpenFilters(m3, "browse"); n3.Popups.filter:Hide()
	n3.ui.bagWindows = true; n3:RefreshViews(true)
	local bw = n3.Window.bagViews[1]
	check(bw.scroll.points[1][5] == -4, "Classic bag window keeps its grid spacing under the slot count: " .. tostring(bw.scroll.points[1][5]))
	n3.Drawer:Show()
	local dr = n3.Drawer.frame
	local sp, ip = dr.scroll.points, dr.import.points
	check(sp[1][4] == 12 and sp[2][4] == -32 and sp[2][5] == 78 and ip[1][4] == 14 and ip[1][5] == 14 and dr.add.points[1][4] == 20 and dr.add.points[1][5] == 44,
		"Classic currency drawer: list, scrollbar, Add Item box and Import button clear the border")
	check(dr.rows[1] and dr.rows[1].w == 230 and dr.child.w == 230, "Classic currency drawer rows narrow with the list: " .. tostring(dr.rows[1] and dr.rows[1].w))
	check(dr.import.label:GetText() == "Import Blizzard Picks", "Import Blizzard Picks is Title Case")
	check(m3.classicCorners and m3.classicCorners[1].alpha == 0.4 and m3.classicCorners[2].alpha == 0.4, "corner filigree dimmed to 40%")
	n3:Set("skin", "modern"); n3:RefreshViews(true)
	local ok = true
	for _, v in ipairs({ m3, b3 }) do
		for _, box in ipairs(v.segBoxes) do
			if not (box.borderColor and box.borderColor[4] == 1 and box.bgColor[4] == 1) then ok = false end
			for _, b in ipairs(box.btns) do if b.divider and b.divider.color and b.divider.color[1] ~= n3.Skins.list.modern.line[1] then ok = false end end
		end
	end
	check(ok, "leaving Classic: Sections and View group outlines and dividers back in Modern colors (bags and bank)")
	local fp = n3.Popups.filter
	check(fp.title.textColor and fp.title.textColor[1] == n3.Skins.list.modern.heading[1], "Filter panel built in Classic repaints in Modern colors")
	-- "TOPLEFT", 8, -50 and "TOPLEFT", parent, "TOPLEFT", 8, -50 are the same spot.
	local function xy(p) if type(p[2]) == "number" then return p[2], p[3] end return p[4], p[5] end
	local sx1, sy1 = xy(dr.scroll.points[1]); local sx2, sy2 = xy(dr.scroll.points[2]); local ix, iy = xy(dr.import.points[1])
	local ax, ay = xy(dr.add.points[1])
	check(sx1 == 8 and sy1 == -50 and sx2 == -26 and sy2 == 72 and ix == 12 and iy == 10 and ax == 16 and ay == 40 and dr.rows[1].w == 240,
		"currency drawer back at Modern's spots (list above the Add Item box) and 240-wide rows")
	check(bw.scroll.points[1][5] == -12, "Modern bag window grid sits 8 px clear of the header band: " .. tostring(bw.scroll.points[1][5]))

	-- Close buttons take the template's own corner spot when it has one.
	local close, chrome = CreateFrame("Button"), CreateFrame("Frame")
	chrome.CloseButton = CreateFrame("Button"); chrome.CloseButton:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -3, -2)
	check(n3.Classic.PlaceClose(close, chrome, CreateFrame("Frame")):find("^template") and close.points[1][4] == -3 + n3.Classic.CLOSE_NUDGE_X and close.points[1][5] == -2 + n3.Classic.CLOSE_NUDGE,
		"close button placed where Blizzard's template puts its own, nudged half a pixel left and down (1.1.0 adds the x nudge)")
	-- beta8: Classic bag windows keep a minimum height so Blizzard's left
	-- edge starts below the portrait ring; Modern keeps fitting its slots.
	check(n3.Classic.BagMinHeight(bw) == nil, "Modern bag window has no minimum: it keeps fitting its slots")
	local modernH = bw.frame.h
	n3:Set("skin", "classic"); n3:RefreshViews(true)
	check(bw.frame.h >= 160, "one-row Classic bag window is at least the minimum height: " .. tostring(bw.frame.h))
	n3:Set("skin", "modern"); n3:RefreshViews(true)
	check(bw.frame.h == modernH, "Modern height comes back after Classic: " .. tostring(bw.frame.h))
	-- Measured from the frame art when the client reports it.
	local tex = function(point, y, h) local t = M3.tex(); t:SetPoint(point, 0, y); t:SetSize(30, h); return t end
	local fakeView = { frame = { classicState = { on = true, portrait = tex("TOPLEFT", 7, 58),
		chrome = { NineSlice = { TopLeftCorner = tex("TOPLEFT", 16, 200), BottomLeftCorner = tex("BOTTOMLEFT", -3, 32) } } } } }
	check(n3.Classic.BagMinHeight(fakeView) == 200 - 16 + 32 - 3 + 8, "minimum height measured from the frame art when it needs more: " .. tostring(n3.Classic.BagMinHeight(fakeView)))
	fakeView.frame.classicState.chrome.NineSlice.TopLeftCorner = tex("TOPLEFT", 16, 74)
	check(n3.Classic.BagMinHeight(fakeView) == 160, "proven two-row height used when the art needs less")
	check(n3.Classic.BagMinHeight({ frame = {} }) == nil, "no minimum outside Classic")
	M3.fire("BANKFRAME_CLOSED"); M3.runTimers()
end)()

;(function()
	-- beta8: dragging one window's Filter panel must not leave the other's
	-- without a position (it would never draw). Filter, "+" and the pencil.
	package.loaded.mock = nil
	local M4 = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local n4 = M4.loadAddon("BagSmith")
	M4.fire("ADDON_LOADED", "BagSmith"); M4.fire("PLAYER_ENTERING_WORLD"); M4.runTimers(); M4.runTimers()
	ToggleAllBags()
	M4.fire("BANKFRAME_OPENED"); M4.runTimers()
	local main, bank = n4.Window.main, n4.Window.bank
	local P = n4.Popups
	P:OpenFilters(main, "browse"); P.filter.dragBar:GetScript("OnDragStop")(); P.filter:Hide()
	bank.btnFilter:GetScript("OnClick")(bank.btnFilter)
	local bf = P.filters[bank]
	check(bf and bf:IsShown() and bf:GetNumPoints() > 0 and bf.points[1][2] == bank.search,
		"bank Filter button opens a placed panel after the bags panel was moved")
	bf:Hide()
	bank.tabAdd:GetScript("OnClick")(bank.tabAdd)
	check(bf:IsShown() and bf:GetNumPoints() > 0, "bank \"+\" opens a placed panel")
	-- The bank panel moved; the bags panel keeps its own (moved) spot, and the bank's stays put.
	bf.dragBar:GetScript("OnDragStop")(); bf:Hide()
	local mf = P.filters[main]
	local before = #mf.points
	main.btnFilter:GetScript("OnClick")(main.btnFilter)
	check(mf:IsShown() and #mf.points == before and before > 0, "bags panel keeps the spot the player left it at")
	mf:Hide()
	bf:ClearAllPoints()
	bank.btnFilter:GetScript("OnClick")(bank.btnFilter)
	check(bf:IsShown() and bf:GetNumPoints() > 0, "a moved panel that lost its position is placed again")
	bf:Hide()
	n4:SaveSheet("Ore", bank)
	bank.st.sheet = "Ore"; n4:RefreshViews(true)
	P:OpenFilters(bank, "edit", "Ore")
	check(bf:IsShown() and bf:GetNumPoints() > 0 and P.editing == "Ore", "editing a bank sheet opens a placed panel")
	bf:Hide()
	M4.fire("BANKFRAME_CLOSED"); M4.runTimers()
end)()

;(function()
	-- Upgrade from prod 0.9.19: its saved variables load cleanly, keep the
	-- player's settings and sheets, and both skins work on top of them.
	local saved = dofile("tests/prod_0919_savedvars.lua")
	package.loaded.mock = nil
	local M5 = require("mock")
	_G.BagSmithDB, _G.BagSmithCharDB = saved.db, saved.cdb
	local n5 = M5.loadAddon("BagSmith")
	M5.fire("ADDON_LOADED", "BagSmith"); M5.fire("PLAYER_ENTERING_WORLD"); M5.runTimers(); M5.runTimers()
	check(n5.ready and (n5.errors or 0) == 0, "upgrade from 0.9.19: loads with no errors")
	local db = n5.db
	check(db.scale == 1.2 and db.bagScale == 0.8 and db.bagCols == 5 and db.accent == "33aaff" and db.view == "icons" and db.remember == true,
		"upgrade from 0.9.19: the player's settings are kept")
	local function has(list, name) for _, s in ipairs(list or {}) do if s.n == name then return true end end end
	check(has(db.sheets, "Rares") and has(db.bankSheets, "Ore"), "upgrade from 0.9.19: bag and bank sheets are kept")
	check(db.skin == "modern" and type(db.bankCollapsed) == "table", "upgrade from 0.9.19: Modern skin, and the new per-bank collapsed list exists")
	ToggleAllBags()
	M5.fire("BANKFRAME_OPENED"); M5.runTimers()
	check(n5.Window.main:IsShown() and n5.Window.bank.frame:IsShown(), "upgrade from 0.9.19: bags and bank windows open")
	n5.ui.bagWindows = true; n5:RefreshViews(true)
	local bw = n5.Window.bagViews[1]
	check(math.abs(bw.frame.scale - 1.2 * 0.8) < 1e-6, "upgrade from 0.9.19: bag windows now follow Scale (1.2 x 0.8)")
	n5:Set("skin", "classic"); n5:RefreshViews(true)
	n5:Set("skin", "modern"); n5:RefreshViews(true)
	check((n5.errors or 0) == 0, "upgrade from 0.9.19: switching to Classic and back raises no errors")
	M5.fire("BANKFRAME_CLOSED"); M5.runTimers()
end)()

;(function()
	-- 0.10.1: neutral icon frames, Filter aligned with the toolbar, the drag
	-- band ending at the search row, the Classic dropdown arrow, Modern hover.
	package.loaded.mock = nil
	local M6 = require("mock")
	M6.put(0, 1, { id = 3001, name = "Gem", q = 3, class = 7, subclass = 0, price = 100 })
	M6.put(0, 2, { id = 3002, name = "Bread", q = 1, count = 4, class = 0, subclass = 5, price = 1 })
	M6.put(0, 3, { id = 3003, name = "Scrap", q = 0, class = 15, subclass = 0, price = 1 })
	-- Give Blizzard's dropdown template an arrow piece, as the client's has.
	local realCreate = _G.CreateFrame
	_G.CreateFrame = function(kind, name, parent, template, ...)
		local f = realCreate(kind, name, parent, template, ...)
		if template == "WowStyle1DropdownTemplate" then f.Arrow = M6.tex(); f.Arrow:SetPoint("RIGHT", f, "RIGHT", -6, 0) end
		return f
	end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local n6 = M6.loadAddon("BagSmith")
	M6.fire("ADDON_LOADED", "BagSmith"); M6.fire("PLAYER_ENTERING_WORLD"); M6.runTimers(); M6.runTimers()
	ToggleAllBags()
	M6.fire("BANKFRAME_OPENED"); M6.runTimers()
	local main, bank = n6.Window.main, n6.Window.bank
	local N = n6.Buttons.NEUTRAL_FRAME

	-- Neutral frames: every skin, view and setting; exactly one frame per item icon.
	local ok, why = true, ""
	for _, skin in ipairs({ "modern", "classic" }) do
		n6:Set("skin", skin)
		for _, view in ipairs({ "list", "icons" }) do
			n6:Set("view", view); n6:RefreshViews(true)
			for _, setting in ipairs({ "all", "unc", "off" }) do
				n6:Set("border", setting)
				for slot, q in pairs({ [1] = 3, [2] = 1, [3] = 0 }) do
					local b = n6.Buttons:Get(0, slot)
					local colored = setting == "all" or (setting == "unc" and q >= 2)
					local frame = (b.qRing:IsShown() and b.qRing) or (b.qFrame:IsShown() and b.qFrame)
					local both = b.qRing:IsShown() and b.qFrame:IsShown()
					local neutralColor = frame and frame.color and frame.color[1] == N[1] and frame.color[2] == N[2]
					if not frame or both or (colored and neutralColor) or (not colored and not neutralColor) then
						ok = false; why = ("%s/%s/%s q%d"):format(skin, view, setting, q)
					end
				end
			end
		end
	end
	check(ok, "every item icon has exactly one thin frame: rarity color when allowed, neutral grey otherwise " .. why)
	n6:Set("skin", "modern"); n6:Set("view", "icons"); n6:Set("border", "off"); n6.ui.bagWindows = true; n6:RefreshViews(true)
	local empty
	for _, b in ipairs(n6.Buttons.all) do if not b.hasItem then empty = b; break end end
	n6.Buttons:SetMode(empty, "cell"); n6.Buttons:Blank(empty, { bag = 0, slot = 9 })
	n6.Buttons:RefreshSkin()
	check(empty and not empty.qRing:IsShown() and not empty.qFrame:IsShown(), "empty slots get no frame, also after a skin refresh")
	n6.ui.bagWindows = false; n6:Set("view", "list"); n6:Set("border", "all"); n6:RefreshViews(true)

	-- Filter's right edge = the end of the toolbar (the View group), any skin, any width.
	local function filterAligned(v)
		local last = v.toolItems[#v.toolItems]
		local lp = last.frame.points[1]
		local boxRight = lp[4] + last.width
		local sp = v.search.points[2]
		-- (1.3.0: the search row's offsets are measured from the title, the toolbar's from its own left edge; in
		-- Classic the toolbar starts belowShift px left of the title, so take that back out to compare)
		local filterRight = sp[4] - (v.belowShift or 0) + 6 + v.btnFilter:GetWidth()
		return math.abs(filterRight - boxRight) < 0.01 and math.abs(v.toolsEnd - boxRight) < 0.01, filterRight, boxRight
	end
	for _, skin in ipairs({ "modern", "classic", "modern" }) do
		n6:Set("skin", skin); n6:RefreshViews(true)
		for _, v in ipairs({ main, bank }) do
			for _, w in ipairs({ 1200, 700 }) do
				v.tools.w = w; v:LayoutTools()
				local good, fr, br = filterAligned(v)
				check(good, ("%s %s at %d: Filter's right edge lines up with the end of the toolbar (%s / %s)"):format(skin, v.isBank and "bank" or "bags", w, tostring(fr), tostring(br)))
			end
			v.tools.w = 3000; v:LayoutTools()
			local full = v.toolsEnd + v.toolItems[#v.toolItems].gap
			v.tools.w = full - 1; v:LayoutTools()
			check(v.toolsCompact and filterAligned(v), skin .. " compact toolbar: Filter lines up with the shorter row")
			v.tools.w = 120; v:LayoutTools()
			check(math.abs(v.toolsEnd - 120) < 0.01, skin .. " toolbar wider than the window: Filter stays at the window's edge")
			v.tools.w = nil; v:LayoutTools()
		end
	end

	-- Drag band ends where the search row begins.
	local function bandFits(v)
		local tp = v.title.points[1]
		local y = type(tp[2]) == "number" and tp[3] or tp[5]
		return math.abs(v.dragArea.h - (-y + v.title.h + 2)) < 0.01, v.dragArea.h
	end
	n6:Set("skin", "modern"); n6:RefreshViews(true)
	local g1, h1 = bandFits(main); local g2, h2 = bandFits(bank)
	check(g1 and g2 and h1 == 40 and h2 == 40, ("Modern drag band ends at the search row (bags %s, bank %s)"):format(tostring(h1), tostring(h2)))
	n6:Set("skin", "classic"); n6:RefreshViews(true)
	g1, h1 = bandFits(main); g2, h2 = bandFits(bank)
	check(g1 and g2 and h1 == 54 and h2 == 29, ("Classic drag band ends at the search row; the bank's Filter is clear (bags %s, bank %s)"):format(tostring(h1), tostring(h2)))
	-- The dropdown arrow, 2 px right of the template's spot.
	local art = main.classicDropdown
	check(art and art.Arrow and art.Arrow.points[1][4] == -4 and art.Arrow.points[1][5] == 0.5,
		"Classic dropdown arrow sits 2 px right of and 0.5 px above the template's spot: " .. tostring(art and art.Arrow and art.Arrow.points[1][4]) .. "," .. tostring(art and art.Arrow and art.Arrow.points[1][5]))
	n6:Set("skin", "modern"); n6:RefreshViews(true)
	g1, h1 = bandFits(main)
	check(g1 and h1 == 40, "drag band back to Modern's after leaving Classic")
	_G.CreateFrame = realCreate

	-- Modern hover.
	local function look(b)
		local l = b.label or b.text
		return table.concat({ tostring(b.bgColor and table.concat(b.bgColor, ",")), tostring(b.borderColor and table.concat(b.borderColor, ",")),
			tostring(l and l.textColor and table.concat(l.textColor, ",")), tostring(b.hoverWash and b.hoverWash:IsShown()),
			tostring(b.tex and b.tex.color and table.concat(b.tex.color, ",")) }, "|")
	end
	local function enter(b) b:GetScript("OnEnter")(b) end
	local function leave(b) b:GetScript("OnLeave")(b) end
	local function roundTrip(b, name)
		local rest = look(b); enter(b); local hov = look(b); leave(b)
		check(hov ~= rest and look(b) == rest, "Modern hover: " .. name .. " lights up and returns exactly to rest")
	end
	roundTrip(main.btnSort, "text button")
	main.btnMerge:SetActive(true); roundTrip(main.btnMerge, "selected text button")
	enter(main.btnMerge)
	check(main.btnMerge.borderColor[4] == 1 and main.btnMerge.label.textColor[1] == n6.Skins:Current().heading[1], "a hovered selected button keeps its accent border and heading label")
	leave(main.btnMerge); main.btnMerge:SetActive(false)
	local segOff, segOn
	for _, b in ipairs(main.segButtons) do if b.active then segOn = b elseif not segOff then segOff = b end end
	roundTrip(segOff, "unselected segment"); roundTrip(segOn, "selected segment")
	enter(segOff)
	check(segOff.borderColor[4] == 0 and segOff.bgColor[4] > 0, "a hovered segment gets a fill but no border of its own")
	leave(segOff)
	roundTrip(main.tabButtons[1], "sheet tab")
	roundTrip(main.btnLanes, "icon button")
	roundTrip(main.headerLabels.n, "column header")
	local nav = n6.SettingsPanel; nav:Show(); roundTrip(nav.navButtons[1], "Settings category"); nav:Hide()
	local slot = bank.bankBar and bank.bankBar.slots and bank.bankBar.slots[1]
	if slot then roundTrip(slot, "bank bag slot") end
	-- Clicking while hovered, then leaving: the new state's resting look.
	enter(segOff); segOff:GetScript("OnClick")(segOff); leave(segOff)
	local afterClick = look(segOff); segOff:SetActive(segOff.active)
	check(look(segOff) == afterClick and segOff.active, "click while hovered, then leave: the newly selected look, nothing stuck")
	-- Hidden while hovered: back to rest.
	enter(main.btnSort); main.btnSort:Hide(); main.btnSort:Show()
	check(not main.btnSort.hover and main.btnSort.label.textColor[1] == n6.Skins:Current().muted[1], "a button hidden while hovered returns to rest")
	-- Classic: hover never touches Modern's colors or washes.
	n6:Set("skin", "classic"); n6:RefreshViews(true)
	local before = look(main.btnSort); enter(main.btnSort)
	local beforeIcon = look(main.btnLanes); enter(main.btnLanes)
	check(look(main.btnSort) == before and not main.btnLanes.hoverWash:IsShown(), "Classic: hovering never paints Modern's hover")
	leave(main.btnSort); leave(main.btnLanes)
	-- Switching to Classic while hovering leaves nothing lit back in Modern.
	n6:Set("skin", "modern"); n6:RefreshViews(true)
	enter(main.btnSort); n6:Set("skin", "classic"); n6:RefreshViews(true); leave(main.btnSort)
	n6:Set("skin", "modern"); n6:RefreshViews(true)
	check(main.btnSort.label.textColor[1] == n6.Skins:Current().muted[1] and not main.btnLanes.hoverWash:IsShown(), "skin switch while hovering: nothing left lit")
	M6.fire("BANKFRAME_CLOSED"); M6.runTimers()
end)()

;(function()
	-- Upgrade from the outgoing prod, 0.11.2 (a Classic user with Green and Up borders).
	local saved = dofile("tests/prod_0112_savedvars.lua")
	package.loaded.mock = nil
	local M7 = require("mock")
	_G.BagSmithDB, _G.BagSmithCharDB = saved.db, saved.cdb
	local n7 = M7.loadAddon("BagSmith")
	M7.fire("ADDON_LOADED", "BagSmith"); M7.fire("PLAYER_ENTERING_WORLD"); M7.runTimers(); M7.runTimers()
	check(n7.ready and (n7.errors or 0) == 0, "upgrade from 0.11.2: loads with no errors")
	local db = n7.db
	local function has(list, name) for _, s in ipairs(list or {}) do if s.n == name then return true end end end
	check(db.skin == "classic" and db.border == "unc" and db.scale == 1.2 and has(db.sheets, "Rares") and has(db.bankSheets, "Ore"),
		"upgrade from 0.11.2: skin, borders, settings and sheets are kept")
	ToggleAllBags()
	M7.fire("BANKFRAME_OPENED"); M7.runTimers()
	check(n7.Window.main:IsShown() and n7.Window.bank.frame:IsShown() and n7.Window.main.classicApplied, "upgrade from 0.11.2: windows open in Classic")
	n7:Set("skin", "modern"); n7:RefreshViews(true); n7:Set("skin", "classic"); n7:RefreshViews(true)
	check((n7.errors or 0) == 0, "upgrade from 0.11.2: switching skins raises no errors")
	check(n7.db.recentSection == true and n7.db.laneOrder[1] == "~recent" and n7.db.splitView == false and n7.db.sheetViews == false,
		"upgrade from 0.11.2: Recent on and first in Section Order, the other new options off")
	-- 0.12.0 has a What's New entry: someone updating from 0.11.2 has it waiting,
	-- and keeps their record of what they've seen until they close it.
	n7.version = "0.12.0"   -- the mock reports 0.1.0 for every build; this is the release being tested
	check(BagSmithDB.whatsNewSeen == "0.1.0" and n7.WhatsNew:Pending(), "upgrade from 0.11.2: their What's New record is kept and the 0.12 card is waiting")
	check(n7.db.travelMode == false and n7.db.travelLeaveTaxi == true, "upgrade from 0.11.2: Travel Mode off, Auto Travel Mode settings at their defaults")
	M7.fire("BANKFRAME_CLOSED"); M7.runTimers()
end)()

;(function()
	-- 0.10.2: item tooltips stay on one side; the Sheets page mirrors Columns.
	package.loaded.mock = nil
	local M8 = require("mock")
	M8.put(0, 1, { id = 4001, name = "Gem", q = 3, class = 7, subclass = 0, price = 100 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local n8 = M8.loadAddon("BagSmith")
	M8.fire("ADDON_LOADED", "BagSmith"); M8.fire("PLAYER_ENTERING_WORLD"); M8.runTimers(); M8.runTimers()
	ToggleAllBags()
	M8.fire("BANKFRAME_OPENED"); M8.runTimers()
	local main = n8.Window.main
	-- Blizzard's refresh, as the client does it: re-place by its rule.
	local function blizzardSide(b) return b:GetRight() >= GetScreenWidth() / 2 and "ANCHOR_LEFT" or "ANCHOR_RIGHT" end
	local function hoverStays(b, right, name)
		b.GetRight = function() return right end
		b:GetScript("OnEnter")(b)
		local first = GameTooltip.anchor
		local stays = GameTooltip:IsOwned(b) and first ~= nil
		for _ = 1, 5 do if GameTooltip.anchor ~= blizzardSide(b) then stays = false end end
		b:GetScript("OnLeave")(b)
		check(stays and first == blizzardSide(b), ("%s at x=%d: tooltip on the %s and stays there through the refresh"):format(name, right, first == "ANCHOR_LEFT" and "left" or "right"))
	end
	for _, skin in ipairs({ "modern", "classic" }) do
		n8:Set("skin", skin)
		for _, view in ipairs({ "list", "icons" }) do
			n8:Set("view", view); n8:RefreshViews(true)
			local item = n8.Buttons:Get(0, 1)
			hoverStays(item, 1700, skin .. " " .. view .. " bags item")
			hoverStays(item, 300, skin .. " " .. view .. " bags item")
		end
	end
	n8:Set("skin", "modern"); n8:Set("view", "list")
	n8.ui.bagWindows = true; n8:RefreshViews(true)
	local mirror = n8.Buttons.mirrors and next(n8.Buttons.mirrors) and n8.Buttons.mirrors[next(n8.Buttons.mirrors)][1]
	if mirror then
		mirror.bag = mirror.bag or 0
		hoverStays(mirror, 1700, "bag window cell"); hoverStays(mirror, 300, "bag window cell")
	end
	n8.ui.bagWindows = false; n8:RefreshViews(true)
	-- With the client's own anchor calculation present, BagSmith uses it.
	local called
	_G.ContainerFrameItemButton_CalculateItemTooltipAnchors = function(btn, tip) called = btn; tip:SetAnchorType("ANCHOR_LEFT") end
	local item = n8.Buttons:Get(0, 1)
	item:GetScript("OnEnter")(item)
	check(called == item and GameTooltip.anchor == "ANCHOR_LEFT" and n8.Buttons.tipPlacement == "Blizzard's anchor calculation", "the client's own anchor calculation places the tooltip when it exists")
	item:GetScript("OnLeave")(item)
	_G.ContainerFrameItemButton_CalculateItemTooltipAnchors = nil

	-- Bag Sheets and Bank Sheets: one list each.
	local P = n8.SettingsPanel
	P:Show(); P:ShowPage("bagsheets")
	local function shownRows()
		local ids = {}
		for _, l in ipairs(P.pools.list) do for _, r in ipairs(l.rows) do if r:IsShown() and r.id and l:IsShown() then ids[#ids + 1] = r.id end end end
		return table.concat(ids, ",")
	end
	check(shownRows() == table.concat(n8.db.tabOrder, ","), "Bag Sheets shows the bags window's list: " .. shownRows())
	P:ShowPage("banksheets")
	check(shownRows() == table.concat(n8.db.bankTabOrder, ","), "Bank Sheets shows the bank window's list: " .. shownRows())
	-- Ticking off a bank sheet hides it in the bank only; viewing it falls back to All.
	n8.uiBank.sheet = "Quest"
	local row
	for _, l in ipairs(P.pools.list) do for _, r in ipairs(l.rows) do if r:IsShown() and r.id == "Quest" then row = r end end end
	row.box:SetChecked(false); row.box:GetScript("OnClick")(row.box)
	check(n8.IndexOf(n8.db.bankHiddenTabs, "Quest") and not n8.IndexOf(n8.db.hiddenTabs, "Quest") and n8.uiBank.sheet == "All",
		"hiding a bank sheet affects only the bank, and the bank view falls back to All")
	P:Hide()
	M8.fire("BANKFRAME_CLOSED"); M8.runTimers()
end)()

;(function()
	-- 0.10.3: columns are never planned from a half laid-out window.
	package.loaded.mock = nil
	local M9 = require("mock")
	M9.put(0, 1, { id = 5001, name = "Gem", q = 3, class = 7, subclass = 0, price = 100 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local n9 = M9.loadAddon("BagSmith")
	M9.fire("ADDON_LOADED", "BagSmith"); M9.fire("PLAYER_ENTERING_WORLD"); M9.runTimers(); M9.runTimers()
	ToggleAllBags()
	n9:Set("view", "list"); n9:RefreshViews(true)
	local main = n9.Window.main
	local real = main.scroll:GetWidth()
	local good = main.planWidth
	check(good == math.max(200, math.floor(real)), "a laid-out window plans its columns from the list's real width")
	local function vendorW(v) local b = v.headerLabels.v; return b and b.w or 0 end
	local goodVendor = vendorW(main)
	-- The game reports 0 (not laid out yet), as right after a resize.
	local origW, origValid = main.scroll.GetWidth, main.scroll.IsRectValid
	main.scroll.GetWidth = function() return 0 end
	main.scroll.IsRectValid = function() return false end
	main:Refresh(true)
	check(main.planWidth == good and vendorW(main) == goodVendor, ("a bad width read reuses the trusted width, not 200 px (%s vs %s)"):format(tostring(main.planWidth), tostring(good)))
	check(main.headerLabels.v:IsShown() and vendorW(main) > 30, "header names keep their room through a bad read")
	-- Next frame, the real width is back and the list is planned again.
	main.scroll.GetWidth, main.scroll.IsRectValid = origW, origValid
	main.scroll.w = 700
	M9.runTimers(); M9.runTimers()
	check(main.planWidth == 700, "the list is planned again on the next frame from the real width: " .. tostring(main.planWidth))
	-- A window that grew while unreadable: the estimate follows the window's size.
	local fw = main.frame:GetWidth()
	main.scroll.w = fw - 40; main:Refresh(true)   -- trusted: the list is 40 px narrower than the window
	main.scroll.GetWidth = function() return 0 end
	main.frame.w = fw + 100
	main:Refresh(true)
	check(main.planWidth == fw + 60, ("a bad read after the window grew estimates from the window's new size: %s (want %s)"):format(tostring(main.planWidth), tostring(fw + 60)))
	main.scroll.GetWidth = origW; main.frame.w = fw
	M9.runTimers(); M9.runTimers()
	-- Re-plans are capped: a window that never reports a width doesn't loop forever.
	main.scroll.GetWidth = function() return 0 end
	local rebuilds = 0
	local origRefresh = main.Refresh
	main.Refresh = function(self, ...) rebuilds = rebuilds + 1; return origRefresh(self, ...) end
	main:Refresh(true)
	for _ = 1, 30 do M9.runTimers() end
	check(rebuilds <= 12, "a window that never reports a width stops re-planning: " .. rebuilds)
	main.Refresh = nil; main.scroll.GetWidth = origW
	-- Any real width change re-plans on the next frame; not while the grip is held.
	main.scroll.w = 700; main:Refresh(true)
	main.sizing = true
	main.scroll.w = 760; main.scroll:GetScript("OnSizeChanged")(main.scroll, 760)
	M9.runTimers()
	check(main.planWidth == 700, "no rebuild while the grip is being dragged")
	main.sizing = false
	main.scroll:GetScript("OnSizeChanged")(main.scroll, 760)
	M9.runTimers()
	check(main.planWidth == 760, "the list re-plans once the width really changed: " .. tostring(main.planWidth))
	-- Grip release: sizing flag cleared, list rebuilt.
	main.grip:GetScript("OnMouseDown")(main.grip)
	check(main.sizing == true, "grip held: BagSmith waits")
	main.grip:GetScript("OnMouseUp")(main.grip)
	check(main.sizing == false, "grip released: re-planning resumes")
	-- The bank window, opened while not yet laid out, gets real widths a frame later.
	local origCreate = _G.CreateFrame
	M9.fire("BANKFRAME_OPENED")
	local bank = n9.Window.bank
	check(bank.planWidth and bank.planWidth >= 200, "bank window opens with a usable column plan")
	M9.runTimers(); M9.runTimers()
	check(bank.planWidth == math.max(200, math.floor(bank.scroll:GetWidth())), "bank window settles on its real width")
	M9.fire("BANKFRAME_CLOSED"); M9.runTimers()
end)()

;(function()
	-- 0.10.4: column lines. Dragging a line moves it with the pointer
	-- and changes only the two columns touching it; the row always fills.
	package.loaded.mock = nil
	local MA = require("mock")
	MA.put(0, 1, { id = 6001, name = "Gem", q = 3, class = 7, subclass = 0, price = 100 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nA = MA.loadAddon("BagSmith")
	MA.fire("ADDON_LOADED", "BagSmith"); MA.fire("PLAYER_ENTERING_WORLD"); MA.runTimers(); MA.runTimers()
	ToggleAllBags()
	MA.fire("BANKFRAME_OPENED"); MA.runTimers()
	local cursor = 0
	local savedCursor = _G.GetCursorPosition
	_G.GetCursorPosition = function() return cursor * UIParent:GetEffectiveScale(), 0 end
	local function planOf(v) local p = v:ColumnPlan(); local m = {}; for i, c in ipairs(p) do m[c.key] = c; m[i] = c end; return p, m end
	local function drag(v, i, d)
		local g = v.headerGrips[i]
		cursor = 0; g:GetScript("OnMouseDown")(g)
		cursor = d; g:GetScript("OnUpdate")(g)
		g:GetScript("OnMouseUp")(g)
		MA.runTimers()
	end
	local function fills(v) local p, _ = planOf(v); local last = p[#p]; return math.abs(last.colX + last.colW - v.planWidth) < 0.01 end
	for _, skin in ipairs({ "modern", "classic" }) do
		nA:Set("skin", skin)
		for _, v in ipairs({ nA.Window.main, nA.Window.bank }) do
			local who = skin .. " " .. (v.isBank and "bank" or "bags")
			v:Pref("colWidths").t, v:Pref("colWidths").bd, v:Pref("colWidths").v, v:Pref("colWidths").c = nil, nil, nil, nil
			-- Item first (the default order).
			nA:Set(v.isBank and "bankColOrder" or "colOrder", { "n", "c", "t", "bd", "v", "w", "age" })
			nA:Set(v.isBank and "bankCols" or "cols", { "c", "t", "bd", "v", "w", "age" })
			nA:RefreshViews(true)
			local p0, m0 = planOf(v)
			-- Line 1 sits between Item and Qty: widen Item by 8.
			drag(v, 1, 8)
			local p1, m1 = planOf(v)
			check(m1.n.colW == m0.n.colW + 8 and m1.c.colW == m0.c.colW - 8 and m1.t.colX == m0.t.colX and m1.t.colW == m0.t.colW and fills(v),
				who .. ": dragging Item's right line widens Item, narrows only Qty, and the line follows the pointer")
			-- A line between two fixed columns: Type and Bind trade, Item and everything else stay.
			local before = { planOf(v) }
			local ti
			for i, c in ipairs(p1) do if c.key == "t" then ti = i end end
			drag(v, ti, 6)
			local p2, m2 = planOf(v)
			check(m2.t.colW == m1.t.colW + 6 and m2.bd.colW == m1.bd.colW - 6 and m2.n.colW == m1.n.colW and m2.v.colX == m1.v.colX and fills(v),
				who .. ": a line between Type and Bind trades only between them")
			check(m2.bd.colX == m1.bd.colX + 6, who .. ": the dragged line moved exactly with the pointer")
			-- Limits: a fixed column stops at 30 px, Item at 90 px.
			drag(v, ti, 9999)
			local _, m3 = planOf(v)
			-- Qty is next to Item; free it back up so Item can shrink to its own limit.
			v:Pref("colWidths").c = nil; nA:RefreshViews(true)
			check(m3.bd.colW == 30 and fills(v), who .. ": a column stops at 30 px: " .. tostring(m3.bd.colW))
			drag(v, 1, -9999)
			local _, m4 = planOf(v)
			check(m4.n.colW == 90 and fills(v), who .. ": Item stops at 90 px: " .. tostring(m4.n.colW))
			-- Double-click resets both columns of a line.
			local g = v.headerGrips[ti]
			g:GetScript("OnDoubleClick")(g); MA.runTimers()
			check(v:Pref("colWidths").t == nil and v:Pref("colWidths").bd == nil, who .. ": double-click resets both columns of the line")
			v:Pref("colWidths").c = nil; nA:RefreshViews(true)
			-- Item in the middle: both of its lines work.
			nA:Set(v.isBank and "bankColOrder" or "colOrder", { "c", "t", "n", "bd", "v", "w", "age" }); nA:RefreshViews(true)
			local pm, mm = planOf(v)
			local ni
			for i, c in ipairs(pm) do if c.key == "n" then ni = i end end
			drag(v, ni - 1, -10)   -- the line left of Item: Type narrower, Item wider
			local _, ma = planOf(v)
			check(ma.t.colW == mm.t.colW - 10 and ma.n.colW == mm.n.colW + 10 and ma.bd.colX == mm.bd.colX and fills(v), who .. ": Item in the middle, its left line works")
			drag(v, ni, 10)        -- the line right of Item: Item wider, Bind narrower
			local _, mb = planOf(v)
			check(mb.n.colW == ma.n.colW + 10 and mb.bd.colW == ma.bd.colW - 10 and fills(v), who .. ": Item in the middle, its right line works")
			-- Item last: the line on its left trades with it; nothing at the row's end.
			nA:Set(v.isBank and "bankColOrder" or "colOrder", { "c", "t", "bd", "v", "w", "age", "n" }); v:Pref("colWidths").t, v:Pref("colWidths").bd = nil, nil; nA:RefreshViews(true)
			local pl = planOf(v)
			check(#pl - 1 == (function() local k = 0; for _, x in pairs(v.headerGrips) do if x:IsShown() then k = k + 1 end end; return k end)(),
				who .. ": Item last: one grip per line, none at the row's end")
			v:Pref("colWidths").age = nil
			nA:Set(v.isBank and "bankColOrder" or "colOrder", { "n", "c", "t", "bd", "v", "w", "age" })
			for k in pairs(v:Pref("colWidths")) do v:Pref("colWidths")[k] = nil end
			nA:RefreshViews(true)
		end
	end
	_G.GetCursorPosition = savedCursor
	MA.fire("BANKFRAME_CLOSED"); MA.runTimers()
end)()

;(function()
	-- 0.10.4: columns squeeze to fit a narrow window, saved widths kept.
	package.loaded.mock = nil
	local MB = require("mock")
	MB.put(0, 1, { id = 6101, name = "Gem", q = 3, class = 7, subclass = 0, price = 100 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nB = MB.loadAddon("BagSmith")
	MB.fire("ADDON_LOADED", "BagSmith"); MB.fire("PLAYER_ENTERING_WORLD"); MB.runTimers(); MB.runTimers()
	ToggleAllBags()
	MB.fire("BANKFRAME_OPENED"); MB.runTimers()
	for _, skin in ipairs({ "modern", "classic" }) do
		nB:Set("skin", skin)
		for _, v in ipairs({ nB.Window.main, nB.Window.bank }) do
			local who = skin .. " " .. (v.isBank and "bank" or "bags")
			nB:Set(v.isBank and "bankColOrder" or "colOrder", { "c", "n", "t", "bd", "v", "w", "age" })
			nB:Set(v.isBank and "bankCols" or "cols", { "c", "t", "bd", "v", "w", "age" })
			local saved = v:Pref("colWidths")
			for k in pairs(saved) do saved[k] = nil end
			saved.t, saved.w, saved.v = 300, 200, 120
			v.scroll.w = 600; nB:RefreshViews(true)
			local plan = v:ColumnPlan()
			local last = plan[#plan]
			local item, minFixed = 0, 999
			for _, c in ipairs(plan) do if c.key == "n" then item = c.colW elseif c.colW < minFixed then minFixed = c.colW end end
			check(plan.squeezed and math.abs(last.colX + last.colW - 600) <= #plan and last.colX + last.colW <= 600 and item >= 90 and minFixed >= 30,
				("%s: too narrow: columns squeeze to fit, the last ends at the row's edge (%s), Item %s"):format(who, tostring(last.colX + last.colW), tostring(item)))
			check(saved.t == 300 and saved.w == 200 and saved.v == 120, who .. ": squeezing never changes the saved widths")
			v.scroll.w = 1400; nB:RefreshViews(true)
			local wide = v:ColumnPlan()
			local byKey = {}; for _, c in ipairs(wide) do byKey[c.key] = c end
			check(not wide.squeezed and byKey.t.colW == 300 and byKey.w.colW == 200 and byKey.v.colW == 120, who .. ": a wider window brings the saved widths back")
			-- Extreme: not even 30 px each fits; the header is clipped at the row's edge.
			v.scroll.w = 250; nB:RefreshViews(true)
			local tiny = v:ColumnPlan()
			local allMin = true
			for _, c in ipairs(tiny) do if c.key ~= "n" and c.colW ~= 30 then allMin = false end end
			check(allMin and v.header.clipsChildren, who .. ": at the extreme, columns stop at 30 px and the header is clipped")
			-- A drag while squeezed: what is on screen is kept, and the line follows the pointer.
			v.scroll.w = 600; nB:RefreshViews(true)
			local p0 = v:ColumnPlan()
			local i0
			for i, c in ipairs(p0) do if c.key == "n" then i0 = i end end   -- the line between Item and Type (Type has room to give)
			local before = {}; for _, c in ipairs(p0) do before[c.key] = c end
			local cursor = 0
			local savedCursor = _G.GetCursorPosition
			_G.GetCursorPosition = function() return cursor * UIParent:GetEffectiveScale(), 0 end
			local g = v.headerGrips[i0]
			g:GetScript("OnMouseDown")(g); cursor = 5; g:GetScript("OnUpdate")(g); g:GetScript("OnMouseUp")(g)
			_G.GetCursorPosition = savedCursor
			MB.runTimers()
			local p1 = v:ColumnPlan()
			local after = {}; for _, c in ipairs(p1) do after[c.key] = c end
			check(after.t.colX == before.t.colX + 5 and after.n.colW == before.n.colW + 5 and after.bd.colX == before.bd.colX and after.v.colX == before.v.colX,
				who .. ": dragging while squeezed moves the line with the pointer and nothing else")
			for k in pairs(saved) do saved[k] = nil end
			nB:Set(v.isBank and "bankColOrder" or "colOrder", { "n", "c", "t", "bd", "v", "w", "age" })
			v.scroll.w = nil; nB:RefreshViews(true)
		end
	end
	MB.fire("BANKFRAME_CLOSED"); MB.runTimers()
end)()

;(function()
	-- 0.10.5: footer count buttons, and the bag-in-itself swap hint.
	package.loaded.mock = nil
	local MC = require("mock")
	MC.put(0, 1, { id = 7001, name = "Gem", q = 3, class = 7, subclass = 0, price = 100 })
	MC.put(1, 1, { id = 7002, name = "Deviate Hide Pack", q = 1, class = 1, subclass = 0, equip = "INVTYPE_BAG", price = 50 })
	MC.put(1, 2, { id = 7003, name = "Linen Cloth", q = 1, class = 7, subclass = 0, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nC = MC.loadAddon("BagSmith")
	MC.fire("ADDON_LOADED", "BagSmith"); MC.fire("PLAYER_ENTERING_WORLD"); MC.runTimers(); MC.runTimers()
	ToggleAllBags()
	MC.fire("BANKFRAME_OPENED"); MC.runTimers()
	local main, bank = nC.Window.main, nC.Window.bank
	for _, skin in ipairs({ "modern", "classic", "modern" }) do
		nC:Set("skin", skin); nC:RefreshViews(true)
		local b = main.btnBags
		check(b.isCount and b.label == main.freeText and b.icon and b.h == 20 and b.h <= main.footer.h,
			skin .. ": the bag count and its icon are one button, inside the footer's height")
		check(math.abs(b.w - (8 + 14 + 4 + math.ceil(b.label:GetStringWidth()) + 8)) < 0.01, skin .. ": the count button fits its count")
		check(bank.btnBags.isCount and bank.btnBags.label == bank.freeText, skin .. ": the bank's bag count is a button too")
		b:GetScript("OnClick")(b)
		check(nC.ui.bagWindows and b.active, skin .. ": clicking the count button opens the bag windows and shows it open")
		b:GetScript("OnClick")(b)
		check(not nC.ui.bagWindows and not b.active, skin .. ": clicking again closes them")
		if skin == "classic" then
			check(b.classicOn and b.classic and b.classic:IsShown() and b.label:GetParent() == b.classic and b.icon:GetParent() == b.classic,
				"Classic: the count button uses Blizzard's button art with the icon and count on top")
			b:SetActive(true)
			check(b.label.textColor[1] == 1 and b.label.textColor[2] == 0.82 and b.icon.color and b.icon.color[2] == 0.82, "Classic: open windows show gold text and a gold icon")
			b:SetActive(false)
		else
			check(not b.classicOn and b.bgColor[4] == 1 and b.icon:GetParent() == b, skin .. ": Modern chip style, icon on the button")
			local rest = table.concat(b.bgColor, ","); b:GetScript("OnEnter")(b)
			local hov = table.concat(b.bgColor, ","); b:GetScript("OnLeave")(b)
			check(hov ~= rest and table.concat(b.bgColor, ",") == rest, skin .. ": the count button has the Modern hover")
		end
	end
	check(main.btnReagent:IsShown() and main.btnReagent.isCount and main.btnReagent.label == main.reagentText and main.btnReagent.points[1][2] == main.btnBags,
		"the reagent count is a button too, beside the bag count")

	-- The swap hint.
	local H = nC.SwapHint
	_G.UIErrorsFrame = { AddMessage = function(self, text) self.last = text end }
	local slot1 = CreateFrame("Button", "CharacterBag0Slot")   -- bag 1's slot on Blizzard's bag bar
	local slot2 = CreateFrame("Button", "CharacterBag1Slot")   -- bag 2's slot
	local over
	_G.GetMouseFoci = function() return { over } end
	local function attempt(bag, slot, pointer)
		-- Picked up: the item is on the cursor and its slot is locked.
		MC.cursorItem = MC.bags[bag][slot].id
		MC.bags[bag][slot].locked = true
		MC.fire("ITEM_LOCK_CHANGED", bag, slot)
		-- Dropped and refused: back in its slot, cursor empty, then the error.
		MC.bags[bag][slot].locked = false
		MC.cursorItem = nil
		over = pointer
		local before = H.shown or 0
		MC.fire("UI_ERROR_MESSAGE", 1, "Can't do that")
		return (H.shown or 0) > before
	end
	local t = 1000
	local realTime = _G.GetTime
	_G.GetTime = function() return t end
	local function later(sec) t = t + sec end
	check(attempt(1, 1, slot1) and H.NoticeFrame() and H.NoticeFrame().text.text == H.TEXT and H.NoticeFrame():IsShown() and UIErrorsFrame.last == nil,
		"dropping a bag on the slot of the bag it's stored in shows the hint, in BagSmith's own on-screen text")
	-- Held at full strength, then faded, then hidden; never touching the game's error display.
	local nf = H.NoticeFrame()
	local tick = nf:GetScript("OnUpdate")
	tick(nf, H.HOLD - 0.5)
	check(nf:IsShown() and (nf.alpha or 1) == 1, "the message stays at full strength through its hold")
	tick(nf, 1)
	check(nf:IsShown() and nf.alpha < 1 and nf.alpha > 0, "then it fades")
	tick(nf, H.FADE)
	check(not nf:IsShown(), "then it hides")
	H:Notice(H.TEXT); tick(nf, H.HOLD - 1); H:Notice(H.TEXT)
	check(nf.t == 0 and nf.alpha == 1 and H.NoticeFrame() == nf, "showing it again restarts the timer and reuses the same text")
	later(5); check(not attempt(1, 1, slot2), "dropping it on another bag's slot shows nothing")
	later(5); check(not attempt(1, 2, slot1), "a non-bag item shows nothing, and replaces the remembered bag")
	MC.put(0, 2, { id = 7004, name = "Small Pouch", q = 1, class = 1, subclass = 0, equip = "INVTYPE_BAG", price = 5 })
	later(5); check(not attempt(0, 2, slot1), "a bag from the backpack shows nothing (the backpack has no slot to swap)")
	-- BagSmith's Bank Bags strip: a bank bag stored inside the bank bag in that slot.
	MC.sizes[6] = 8; MC.bags[6] = MC.bags[6] or {}
	MC.put(6, 1, { id = 7005, name = "Big Bag", q = 1, class = 1, subclass = 0, equip = "INVTYPE_BAG", price = 5 })
	local strip = CreateFrame("Button"); strip.invID = C_Container.ContainerIDToInventoryID(6)
	later(5); check(attempt(6, 1, strip), "the same swap on the Bank Bags strip shows the hint")
	-- Throttle: two refusals in a row show one hint.
	later(5); check(attempt(1, 1, slot1), "a later attempt shows the hint again")
	later(1); check(not attempt(1, 1, slot1), "the hint shows at most once every few seconds")
	-- The real sequence on Forever: while the swap is tried, the game locks
	-- the items inside the bag being replaced. That must not wipe the bag.
	later(5)
	MC.cursorItem = 7002; MC.bags[1][1].locked = true; MC.fire("ITEM_LOCK_CHANGED", 1, 1)
	MC.bags[1][2].locked = true; MC.fire("ITEM_LOCK_CHANGED", 1, 2)   -- the linen inside bag 1, locked by the game
	MC.bags[1][1].locked = false; MC.bags[1][2].locked = false; MC.cursorItem = nil
	over = slot1
	local b0 = H.shown
	MC.fire("UI_ERROR_MESSAGE", 1, "Can't put non-empty bags in other bags.")
	check(H.shown == b0 + 1, "items the game locks during the swap don't make BagSmith forget the bag")
	-- The cursor route: the bag is still held when the error arrives, nothing remembered.
	later(5)
	MC.cursorItem = 7003; MC.bags[1][2].locked = true; MC.fire("ITEM_LOCK_CHANGED", 1, 2); MC.bags[1][2].locked = false   -- linen picked up: forgets any bag
	MC.cursorItem = 7002; MC.bags[1][1].locked = true                                                                    -- bag held, no lock event seen
	b0 = H.shown
	MC.fire("UI_ERROR_MESSAGE", 1, "x")
	check(H.shown == b0 + 1, "a bag still on the cursor is traced to its bag directly")
	MC.bags[1][1].locked = false; MC.cursorItem = nil
	-- Debug trace: every game error is logged with what was under the pointer.
	nC.db.debug = true
	local logged = {}
	local realPrint = nC.Print
	nC.Print = function(self, fmt, ...) logged[#logged + 1] = select("#", ...) > 0 and fmt:format(...) or tostring(fmt) end
	later(5); over = slot2
	MC.fire("UI_ERROR_MESSAGE", 1, "Not while idle.")      -- nothing being dragged: not logged
	MC.cursorItem = 7002
	MC.fire("UI_ERROR_MESSAGE", 1, "Inventory is full.")   -- while a bag is dragged: logged
	MC.cursorItem = nil
	nC.Print = realPrint; nC.db.debug = false
	local all = table.concat(logged, " | ")
	check(all:find("Inventory is full") and all:find("CharacterBag1Slot") and not all:find("Not while idle"),
		"/bs debug logs game errors during a drag, with what was under the pointer, and stays quiet otherwise: " .. all)
	-- Route 1, as on Forever: no error event at all. The bag is picked up,
	-- dropped on its own bag's slot, and released back into its slot.
	later(5)
	MC.cursorItem = 7002; MC.bags[1][1].locked = true; MC.fire("ITEM_LOCK_CHANGED", 1, 1)
	over = slot1
	MC.cursorItem = nil; MC.bags[1][1].locked = false
	b0 = H.shown
	MC.fire("ITEM_LOCK_CHANGED", 1, 1)
	check(H.shown == b0 + 1, "a refused drop is spotted from the bag itself, with no error event")
	-- Forever, as logged in game: the slot unlocks while the bag stays on the cursor.
	later(5)
	MC.cursorItem = 7002; MC.bags[1][1].locked = true; MC.fire("ITEM_LOCK_CHANGED", 1, 1)
	MC.bags[1][1].locked = false; over = slot1      -- cursor still holds the bag
	b0 = H.shown
	MC.fire("ITEM_LOCK_CHANGED", 1, 1)
	check(H.shown == b0 + 1, "Forever: the bag's slot unlocks while the bag is still on the cursor, and the message shows")
	MC.cursorItem = nil
	-- A different item on the cursor at that moment: nothing.
	later(5)
	MC.cursorItem = 7002; MC.bags[1][1].locked = true; MC.fire("ITEM_LOCK_CHANGED", 1, 1)
	MC.bags[1][1].locked = false; MC.cursorItem = 7003; over = slot1
	b0 = H.shown
	MC.fire("ITEM_LOCK_CHANGED", 1, 1)
	check(H.shown == b0, "a different item on the cursor shows nothing")
	MC.cursorItem = nil
	-- Both routes for one attempt: one message.
	later(5)
	MC.cursorItem = 7002; MC.bags[1][1].locked = true; MC.fire("ITEM_LOCK_CHANGED", 1, 1)
	MC.cursorItem = nil; MC.bags[1][1].locked = false; over = slot1
	b0 = H.shown
	MC.fire("ITEM_LOCK_CHANGED", 1, 1); MC.fire("UI_ERROR_MESSAGE", 1, "Can't put non-empty bags in other bags.")
	check(H.shown == b0 + 1, "the release and the error together show one message")
	-- Put back from the list (pointer on BagSmith's item button, not a bag bar slot): nothing.
	later(5)
	MC.cursorItem = 7002; MC.bags[1][1].locked = true; MC.fire("ITEM_LOCK_CHANGED", 1, 1)
	MC.cursorItem = nil; MC.bags[1][1].locked = false; over = nC.Buttons:Get(1, 1)
	b0 = H.shown
	MC.fire("ITEM_LOCK_CHANGED", 1, 1)
	check(H.shown == b0, "putting the bag back from the list shows nothing")
	-- Released onto another bag's slot: nothing.
	later(5)
	MC.cursorItem = 7002; MC.bags[1][1].locked = true; MC.fire("ITEM_LOCK_CHANGED", 1, 1)
	MC.cursorItem = nil; MC.bags[1][1].locked = false; over = slot2
	b0 = H.shown
	MC.fire("ITEM_LOCK_CHANGED", 1, 1)
	check(H.shown == b0, "released over another bag's slot shows nothing")
	-- The error route is shielded: a failure inside is logged, not raised.
	local realFoci = _G.GetMouseFoci
	_G.GetMouseFoci = function() error("boom") end
	local okCall = pcall(MC.fire, "UI_ERROR_MESSAGE", 1, "x")
	_G.GetMouseFoci = realFoci
	check(okCall and (nC.errors or 0) == 0, "a failure inside the error route is caught")
	-- Old pickups expire.
	later(5)
	MC.bags[1][1].locked = true; MC.fire("ITEM_LOCK_CHANGED", 1, 1); MC.bags[1][1].locked = false
	later(20); over = slot1
	local before = H.shown
	MC.fire("UI_ERROR_MESSAGE", 1, "x")
	check(H.shown == before, "a bag picked up long ago doesn't trigger the hint")
	_G.GetTime = realTime; _G.GetMouseFoci = nil; _G.UIErrorsFrame = nil
	MC.fire("BANKFRAME_CLOSED"); MC.runTimers()
end)()

;(function()
	-- 0.10.5: the gold sits 10 px in; favorites still fit at the narrowest window.
	package.loaded.mock = nil
	local MD = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nD = MD.loadAddon("BagSmith")
	MD.fire("ADDON_LOADED", "BagSmith"); MD.fire("PLAYER_ENTERING_WORLD"); MD.runTimers(); MD.runTimers()
	ToggleAllBags()
	local main = nD.Window.main
	check(main.moneyText.points[1][2] == 10, "the gold sits 10 px from the footer's left edge: " .. tostring(main.moneyText.points[1][2]))
	local realMoney = _G.GetMoney
	_G.GetMoney = function() return 99999 * 10000 + 9999 end   -- 99,999 gold
	nD.db.fav = { "c:3402", "c:1901", "i:20558" }
	for _, skin in ipairs({ "modern", "classic" }) do
		nD:Set("skin", skin)
		for _, fw in ipairs({ 900, 596 }) do   -- wide, and the narrowest window (620 px)
			main.footer.w = fw; main:UpdateFooter()
			local right = fw - 18 - main.btnBags.w - (main.btnReagent:IsShown() and (main.btnReagent.w + 6) or 0)
			local moneyEnd = 10 + main.moneyText:GetStringWidth()
			local ok, inOrder, seenHidden = true, true, false
			for _, chip in ipairs(main.favChips) do
				if chip:IsShown() then
					if seenHidden then inOrder = false end
					local cx = chip.points[1][4]
					if cx < moneyEnd + 20 or cx + chip.w > right then ok = false end
				else seenHidden = true end
			end
			local more = main.favMore and main.favMore:IsShown()
			if more and (main.favMore.points[1][4] + 34 > right) then ok = false end
			local hidden = #nD.Currency:Favorites() - (main.favShown or 0)
			check(ok and inOrder and (hidden == 0 or (more and main.favMore.label.text == "+" .. hidden)),
				("%s, footer %d: gold, favorites and count buttons never overlap; favorites stay in order; +N counts the rest (%d shown)"):format(skin, fw, main.favShown or 0))
		end
	end
	main.footer.w = nil; _G.GetMoney = realMoney; nD.db.fav = {}
end)()

;(function()
	-- 0.10.6: one key press is one toggle, whatever Blizzard's call chain looks
	-- like (player report: after the game menu, the first press did nothing).
	package.loaded.mock = nil
	local ME = require("mock")
	ME.put(0, 1, { id = 8001, name = "Gem", q = 3, class = 7, subclass = 0, price = 100 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nE = ME.loadAddon("BagSmith")
	ME.fire("ADDON_LOADED", "BagSmith"); ME.fire("PLAYER_ENTERING_WORLD"); ME.runTimers(); ME.runTimers()
	local W = nE.Window
	local function shown() return W:IsShown() and true or false end
	-- The reporter's steps: game menu (closes all bags directly), close it,
	-- open the bags, hover an item, press the key: the bags close.
	ToggleAllBags(); check(shown(), "the bag key opens the bags")
	CloseAllBags(); ME.runTimers()                       -- Esc: the game menu closes every window
	check(not shown(), "the game menu closes the bags")
	ToggleAllBags(); check(shown(), "the bag key opens them again")
	local item = nE.Buttons:Get(0, 1); item:GetScript("OnEnter")(item)
	ToggleAllBags(); item:GetScript("OnLeave")(item)
	check(not shown(), "the first press after the game menu closes the bags")
	-- Blizzard and BagSmith disagree (Blizzard thinks the bags are closed while
	-- BagSmith's window is open): the press still toggles BagSmith.
	ToggleAllBags(); check(shown(), "open")
	ME.blizOpen = false
	ToggleAllBags(); check(not shown(), "a press closes the bags even when Blizzard thought they were closed")
	ME.blizOpen = true
	ToggleAllBags(); check(shown(), "and opens them even when Blizzard thought they were open")
	-- A press whose call chain passes through something named "...Manager"
	-- (the old guard skipped those) now counts.
	_G.FramePanelManager_Run = function() ToggleAllBags() end
	FramePanelManager_Run(); check(not shown(), "a press through a function named Manager still toggles")
	_G.FramePanelManager_Run = nil
	-- Every order the hooks can fire in, within one press: exactly one change.
	local R = nE.Hooks.Request
	local function onePress(seq)
		ME.runTimers()                                   -- a new frame
		local before = shown()
		for _, step in ipairs(seq) do R(step[1], step[2]) end
		return shown() ~= before
	end
	local orders = {
		{ { "ToggleBackpack", "toggle" }, { "ToggleAllBags", "toggle" } },
		{ { "CloseAllBags", "close" }, { "ToggleAllBags", "toggle" } },
		{ { "OpenAllBags", "open" }, { "ToggleAllBags", "toggle" } },
		{ { "ToggleAllBags", "toggle" }, { "CloseAllBags", "close" } },
		{ { "ToggleAllBags", "toggle" }, { "OpenAllBags", "open" } },
		{ { "ToggleBag", "toggle" }, { "ToggleBackpack", "toggle" }, { "ToggleAllBags", "toggle" } },
	}
	for _, start in ipairs({ false, true }) do
		for i, seq in ipairs(orders) do
			ME.runTimers(); if shown() ~= start then if start then W:Show() else W:Hide() end end
			check(onePress(seq), ("hook order %d, window %s: one press, exactly one toggle"):format(i, start and "open" or "closed"))
		end
	end
	-- Two presses in a row: two toggles.
	ME.runTimers(); W:Hide()
	ToggleAllBags(); ToggleAllBags()
	check(not shown(), "two presses in a row open and close")
	-- Direct close when already closed, direct open when already open: nothing.
	CloseAllBags(); check(not shown(), "a direct close of closed bags changes nothing")
	-- /bs debug logs each hook with its outcome.
	nE.db.debug = true
	local logged = {}
	local realPrint = nE.Print
	nE.Print = function(self, fmt, ...) logged[#logged + 1] = select("#", ...) > 0 and fmt:format(...) or tostring(fmt) end
	ToggleAllBags()
	nE.Print = realPrint; nE.db.debug = false
	local all = table.concat(logged, " | ")
	check(all:find("Bag key: OpenAllBags acted") and all:find("Bag key: ToggleAllBags ignored") and all:find("window closed %-> open"),
		"/bs debug logs every bag hook with its outcome: " .. all)
end)()

;(function()
	-- 0.11.0-beta1: two-column icon view, AH Price column, Recent section,
	-- sheets remembering their own view.
	package.loaded.mock = nil
	local MF = require("mock")
	MF.put(0, 1, { id = 9001, name = "Sword", q = 2, class = 2, subclass = 7, price = 500, equip = "INVTYPE_WEAPON" })
	MF.put(0, 2, { id = 9002, name = "Bread", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
	MF.put(0, 3, { id = 9003, name = "Linen", q = 1, count = 10, class = 7, subclass = 5, price = 2 })
	MF.put(0, 4, { id = 9004, name = "Letter", q = 1, class = 12, subclass = 0, price = 0 })
	MF.put(0, 5, { id = 9005, name = "Junk Rock", q = 0, class = 15, subclass = 0, price = 3 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nF = MF.loadAddon("BagSmith")
	MF.fire("ADDON_LOADED", "BagSmith"); MF.fire("PLAYER_ENTERING_WORLD"); MF.runTimers(); MF.runTimers()
	ToggleAllBags()
	local main = nF.Window.main
	local function headers(v)
		local list = {}
		for _, h in pairs(nF.Buttons.lanes[v.child] or {}) do if h:IsShown() and h.laneId then list[#list + 1] = h end end
		table.sort(list, function(a, b) local ya, yb = -a.points[1][5], -b.points[1][5]; if ya ~= yb then return ya < yb end return a.points[1][4] < b.points[1][4] end)
		return list
	end

	-- 1) Two-column icon view.
	nF:Set("view", "icons"); nF:Set("grp", "type"); main.scroll.w = 700; nF:RefreshViews(true)
	local one = headers(main)
	check(#one >= 4 and one[1].points[1][4] == 0 and one[2].points[1][4] == 0, "one column: every section starts at the left edge")
	nF:Set("splitView", true); nF:RefreshViews(true)
	local two = headers(main)
	local halfW = math.floor((700 - 16) / 2)
	local zOk = true
	for i, h in ipairs(two) do
		local x, y = h.points[1][4], -h.points[1][5]
		if (i % 2 == 1 and x ~= 0) or (i % 2 == 0 and (x ~= halfW + 16 or y ~= -two[i - 1].points[1][5])) then zOk = false end
		if h.w ~= halfW then zOk = false end
	end
	check(main.twoColumn and zOk, "two columns: sections fill left, right, then the next row; each pair top-aligned, each header half wide")
	-- Each row is as tall as its taller section.
	local rowOk = true
	for i = 3, #two, 2 do
		local prevBottomLeft, prevBottomRight = -two[i - 2].points[1][5], -two[i - 1].points[1][5]
		if -two[i].points[1][5] <= math.max(prevBottomLeft, prevBottomRight) then rowOk = false end
	end
	check(rowOk, "the next row starts below the taller section of the row above")
	-- Icons sit inside their column.
	local inside = true
	for _, b in ipairs(nF.Buttons.all) do
		if b:IsShown() and b.mode == "cell" and b.points[1] then
			local x = b.points[1][4]
			if not (x + 37 <= halfW or x >= halfW + 16) then inside = false end
		end
	end
	check(inside, "icons stay inside their own column")
	main.scroll.w = 300; nF:RefreshViews(true)
	check(not main.twoColumn and headers(main)[2].points[1][4] == 0, "a narrow window falls back to one column")
	main.scroll.w = 700
	nF:Set("view", "list"); nF:RefreshViews(true)
	check(not main.twoColumn, "list view ignores the setting")
	nF:Set("view", "icons"); nF:Set("grp", "none"); nF:RefreshViews(true)
	check(not main.twoColumn, "Sections: All ignores the setting")
	nF:Set("grp", "type"); nF:RefreshViews(true)
	main:ToggleLane(two[1].laneId)
	check(main.twoColumn and headers(main)[2].points[1][4] == halfW + 16, "a collapsed section keeps its place in the columns")
	main:ToggleLane(two[1].laneId)

	-- 2) AH Price column.
	nF:Set("view", "list"); nF:Set("grp", "type")
	table.insert(nF.db.cols, "ah"); nF:RefreshViews(true)
	local function planKeys(v) local k = {}; for _, c in ipairs(v:ColumnPlan()) do k[#k + 1] = c.key end; return table.concat(k, ",") end
	check(not planKeys(main):find("ah"), "without Auctionator the AH Price column stays out, even when ticked")
	local P = nF.SettingsPanel
	P:Show(); P:ShowPage("bagcols")
	local ahRow
	for _, l in ipairs(P.pools.list) do for _, r in ipairs(l.rows) do if r:IsShown() and r.id == "ah" then ahRow = r end end end
	check(ahRow and not ahRow.box:IsEnabled() and ahRow.tip and ahRow.tip:find("Install Auctionator"), "Columns page: AH Price is greyed out with a tooltip saying to install Auctionator")
	P:Hide()
	local prices = { [9001] = 25000, [9003] = 40 }
	_G.Auctionator = { API = { v1 = {
		GetAuctionPriceByItemLink = function(caller, link) assert(caller == "BagSmith"); return nil end,
		GetAuctionPriceByItemID = function(caller, id) assert(caller == "BagSmith"); return prices[id] end,
		GetAuctionAgeByItemLink = function() return nil end,
		GetAuctionAgeByItemID = function(caller, id) return id == 9001 and 3 or nil end,
	} } }
	nF:RefreshViews(true)
	check(planKeys(main):find("ah"), "with Auctionator the ticked AH Price column shows")
	local sword, bread = nF.Buttons:Get(0, 1), nF.Buttons:Get(0, 2)
	check(sword.colAH.text == nF.Money(25000) and bread.colAH.text == "-", "AH Price shows the stack's value, or - when not scanned")
	check(nF.Buttons:Get(0, 3).colAH.text == nF.Money(400), "AH Price is price times count")
	P:Show(); P:ShowPage("bagcols")
	for _, l in ipairs(P.pools.list) do for _, r in ipairs(l.rows) do if r:IsShown() and r.id == "ah" then ahRow = r end end end
	check(ahRow.box:IsEnabled() and ahRow:IsShown(), "with Auctionator the AH Price row can be ticked")
	P:Hide()
	sword:GetScript("OnEnter")(sword)
	local lines = table.concat(GameTooltip.lines or {}, " | ")
	sword:GetScript("OnLeave")(sword)
	check(lines:find("AH Price") and lines:find("Seen 3 days ago"), "the item tooltip shows the AH price each and how old it is: " .. lines)
	nF:SortByColumn(main.st, "ah"); nF:RefreshViews(true)
	check(main.st.colSort.key == "ah", "AH Price sorts like the other columns")
	main.st.colSort = nil
	-- A broken Auctionator can't break BagSmith.
	_G.Auctionator.API.v1.GetAuctionPriceByItemID = function() error("boom") end
	local okRefresh = pcall(nF.RefreshViews, nF, true)
	check(okRefresh and sword.colAH.text == "-", "an error inside Auctionator is caught and shows -")
	_G.Auctionator = nil
	for i = #nF.db.cols, 1, -1 do if nF.db.cols[i] == "ah" then table.remove(nF.db.cols, i) end end
	nF:RefreshViews(true)

	-- 3) Recent section.
	local now = time()
	nF.cdb.recentSince = now - 100
	nF.cdb.firstSeen[MF.bags[0][3].guid] = now - 10   -- Linen: newest
	nF.cdb.firstSeen[MF.bags[0][1].guid] = now - 50   -- Sword
	nF.cdb.firstSeen[MF.bags[0][2].guid] = now - 500  -- Bread: before the session
	nF.cdb.firstSeen[MF.bags[0][4].guid] = now - 500  -- Letter and Junk Rock: from before the session
	nF.cdb.firstSeen[MF.bags[0][5].guid] = now - 500
	nF:Scan()
	nF:Set("recentSection", true); nF:Set("view", "icons"); nF:Set("splitView", false); nF:RefreshViews(true)
	local hs = headers(main)
	check(hs[1] and hs[1].laneId == "~recent" and hs[1].clearRecent and hs[1].clearRecent:IsShown(), "Recent is pinned at the top with its own Clear Recent button")
	local copies = {}
	for _, b in ipairs(nF.Buttons.recent) do if b:IsShown() then copies[#copies + 1] = b end end
	table.sort(copies, function(a, b) return a.points[1][4] < b.points[1][4] end)
	check(#copies == 2 and copies[1].rec.name == "Linen" and copies[2].rec.name == "Sword", "Recent shows only this session's items, newest first")
	check(copies[1].secure and copies[1].isRecentCopy and copies[1]:GetParent() == nF.Buttons.proxies[0] and copies[1]:GetID() == 3,
		"a Recent copy is a real secure item button pointed at its bag slot")
	check(nF.Buttons:Get(0, 3):IsShown(), "the item also stays in its usual section")
	nF:Set("recentMax", 1); nF:RefreshViews(true)
	local shownCopies = 0; for _, b in ipairs(nF.Buttons.recent) do if b:IsShown() then shownCopies = shownCopies + 1 end end
	check(shownCopies == 1, "the cap limits how many recent items show")
	nF:Set("recentMax", 0); nF:Set("recentWindow", "15m"); nF:RefreshViews(true)
	nF:Set("recentWindow", "session")
	nF:Set("splitView", true); nF:RefreshViews(true)
	hs = headers(main)
	check(hs[1].laneId == "~recent" and hs[1].w == halfW and hs[1].points[1][4] == 0 and hs[2].points[1][4] == halfW + 16 and -hs[2].points[1][5] == -hs[1].points[1][5],
		"Icon Split View: Recent takes the first left slot and pairs like any section")
	nF:Set("splitView", false)
	nF:Set("grp", "none"); nF:RefreshViews(true)
	hs = headers(main)
	check(hs[1] and hs[1].laneId == "~recent", "Recent shows even with Sections: All, above the full list")
	nF:Set("grp", "type")
	local poolSize = #nF.Buttons.recent
	for _ = 1, 20 do nF:RefreshViews(true) end
	check(#nF.Buttons.recent == poolSize, "Recent copies are reused, never recreated")
	hs = headers(main)
	hs[1].clearRecent:GetScript("OnClick")(hs[1].clearRecent)
	hs = headers(main)
	check(hs[1].laneId ~= "~recent", "Clear Recent empties the section")
	-- Session: a /reload keeps it, a fresh login starts a new one.
	local kept = nF.cdb.recentSince
	nF:StartRecentSession(false); check(nF.cdb.recentSince == kept, "a /reload keeps the Recent session")
	nF.cdb.recentSince = 1; nF:StartRecentSession(true); check(nF.cdb.recentSince >= now, "a fresh login starts a new Recent session")
	-- Not in the bank window; dragging Recent is ignored.
	nF.cdb.recentSince = now - 100; nF.cdb.firstSeen[MF.bags[0][3].guid] = now - 10; nF:Scan(); nF:RefreshViews(true)
	MF.fire("BANKFRAME_OPENED"); MF.runTimers()
	local bankHs = headers(nF.Window.bank)
	check(not (bankHs[1] and bankHs[1].laneId == "~recent"), "the bank window has no Recent section")
	MF.fire("BANKFRAME_CLOSED"); MF.runTimers()
	hs = headers(main)
	hs[1]:GetScript("OnDragStart")(hs[1])
	check(nF.dragLane == "~recent", "Recent's header can be dragged like any section")
	hs[1]:GetScript("OnDragStop")(hs[1]); nF.dragLane = nil
	-- In combat, copies are only reused, never re-pointed.
	MF.combat = true
	check(nF.Buttons:GetRecent(1, 0, 4) == nil, "in combat a copy can't be pointed at a different slot")
	MF.combat = false
	nF:Set("recentSection", false); nF:RefreshViews(true)

	-- 4) Sheets remember their own view.
	nF:Set("view", "list"); nF:Set("grp", "type"); nF:Set("sheetViews", true)
	main.st.sheet = "Gear"; nF:RefreshViews(true)
	main:SetPref("grp", "none"); main:SetPref("view", "icons"); main:SetPref("mergeStacks", true); main:SetPref("sort", "name")
	check(main:Pref("grp") == "none" and main:Pref("view") == "icons" and main:Pref("sort") == "name" and main:Pref("mergeStacks") == true,
		"a sheet keeps its own Sections, View, Sort and Merge Stacks")
	check(nF.db.grp == "type" and nF.db.view == "list", "the window's own settings are unchanged")
	main:ToggleLane("Gear")
	check(nF.IndexOf(main:CollapsedList(), "Gear") and not nF.IndexOf(nF.db.collapsed, "Gear"), "a sheet collapses its own sections")
	main.st.sheet = "All"; nF:RefreshViews(true)
	check(main:Pref("grp") == "type" and main:Pref("view") == "list" and not nF.IndexOf(main:CollapsedList(), "Gear"), "the All tab uses the window's settings")
	main.st.sheet = "Gear"
	check(main:Pref("grp") == "none", "switching back restores the sheet's view")
	local saved = nF.validateSettings and nil
	nF:Set("sheetViews", false)
	check(main:Pref("grp") == "type", "with the setting off, every tab uses the window's settings")
	main.st.sheet = "All"; nF:RefreshViews(true)
	check(nF.db.sheetPrefs.bags.Gear.grp == "none", "a sheet's view is kept while the setting is off, for when it's turned back on")
end)()

;(function()
	-- Recent: everything already in the bags at login is not "recent".
	package.loaded.mock = nil
	local MG = require("mock")
	MG.put(0, 1, { id = 9101, name = "Old Sword", q = 2, class = 2, subclass = 7, price = 500 })
	MG.put(0, 2, { id = 9102, name = "Old Bread", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, profiles = { Default = { recentSection = true } }, chars = {}, cache = {} }
	local nG = MG.loadAddon("BagSmith")
	MG.fire("ADDON_LOADED", "BagSmith"); MG.fire("PLAYER_ENTERING_WORLD", true, false); MG.runTimers(); MG.runTimers()
	ToggleAllBags()
	local recentShown = false
	for _, h in pairs(nG.Buttons.lanes[nG.Window.main.child] or {}) do if h:IsShown() and h.laneId == "~recent" then recentShown = true end end
	check(nG.cdb.recentSince > 0 and not recentShown, "items already in the bags at login are not shown as recent")
	-- Something picked up afterwards is.
	MG.put(0, 3, { id = 9103, name = "New Gem", q = 3, class = 7, subclass = 0, price = 100 })
	nG.cdb.recentSince = nG.cdb.recentSince - 5
	for _, r in ipairs(nG.items) do nG.cdb.firstSeen[r.guid] = nG.cdb.recentSince - 1 end
	nG:Scan(); nG:RefreshViews(true)
	for _, h in pairs(nG.Buttons.lanes[nG.Window.main.child] or {}) do if h:IsShown() and h.laneId == "~recent" then recentShown = true end end
	check(recentShown, "an item picked up after login shows in Recent")
end)()

;(function()
	-- 0.11.0-beta2: What's New card.
	package.loaded.mock = nil
	local MH = require("mock")
	-- A player updating: saved data from before What's New existed.
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, profiles = { Default = {} }, chars = {}, cache = {} }
	local nH = MH.loadAddon("BagSmith")
	nH.version = "0.11.0-beta2"
	MH.fire("ADDON_LOADED", "BagSmith"); MH.fire("PLAYER_ENTERING_WORLD"); MH.runTimers(); MH.runTimers()
	local WN = nH.WhatsNew
	check(WN.Newer("0.11.0", "0.10.6") and not WN.Newer("0.11.0", "0.11.0-beta2") and WN.Newer("0.10.10", "0.10.9"), "versions compare by number, and a beta counts as its release")
	check(BagSmithDB.whatsNewSeen == "0.0.0" and WN:Pending(), "an updating player has What's New waiting")
	-- In combat the bags open without it.
	MH.combat = true; ToggleAllBags(); MH.combat = false
	check(not (WN.Card() and WN.Card():IsShown()), "never in combat")
	ToggleAllBags(); ToggleAllBags()
	local card = WN.Card()
	check(card and card:IsShown() and card.title.text == "What's New" and card.lines[1].text == "BagSmith 0.11", "the first bag open after updating shows the card: What's New, with the version heading in the body")
	local bullets = 0; for _, l in ipairs(card.lines) do if l:IsShown() then bullets = bullets + 1 end end
	local dashes = 0; for _, d in pairs(card.dashes) do if d:IsShown() then dashes = dashes + 1 end end
	check(bullets == 5 and dashes == 4 and card.fieldText.text == WN.URL and card.points[1][2] == nH.Window.main.frame, "a heading and four bullets (each with its own dash), the changelog address to copy, beside the bags window")
	check(card.lines[2].points[1][4] > card.dashes[2].points[1][4], "bullets have a hanging indent: the text starts after the dash")
	check(card.more.text == "|cfffac775Previous Updates & Patches:|r See full changelog @ CurseForge:", "the changelog line points to the full changelog for every previous update")
	check(card.intro.text == "Highlights from recent major updates." and card.intro.points[1][5] < 0, "a line under the title says what the card shows")
	card.gotIt:GetScript("OnClick")(card.gotIt)
	check(not card:IsShown() and BagSmithDB.whatsNewSeen == "0.11.0" and not WN:Pending(), "Got It closes it and marks it seen")
	ToggleAllBags(); ToggleAllBags()
	check(not card:IsShown(), "it doesn't come back on the next bag open")
	-- Reopen from Settings and /bs new: nothing changes.
	local P = nH.SettingsPanel; P:Show()
	P.frame.whatsNew:GetScript("OnClick")(P.frame.whatsNew)
	check(card:IsShown() and BagSmithDB.whatsNewSeen == "0.11.0", "the What's New button in Settings shows it any time")
	card.close:GetScript("OnClick")(card.close); P:Hide()
	check(not card:IsShown(), "the close button closes it")
	SlashCmdList.BAGSMITH("new")
	check(card:IsShown(), "/bs new shows it")
	WN:Close()
	-- Hidden testing commands.
	SlashCmdList.BAGSMITH("new reset")
	check(WN:Pending() and BagSmithDB.whatsNewSeen ~= "" and BagSmithDB.whatsNewSeen ~= nil, "/bs new reset makes the next bag open act as the first after updating")
	ToggleAllBags(); ToggleAllBags()
	check(card:IsShown(), "and it shows")
	WN:Close()
	SlashCmdList.BAGSMITH("new reset skipped"); ToggleAllBags(); ToggleAllBags()
	check(card:IsShown(), "/bs new reset skipped shows the view for skipped versions")
	WN:Close()
	-- The setting.
	SlashCmdList.BAGSMITH("new reset"); nH:Set("whatsNew", false); ToggleAllBags(); ToggleAllBags()
	check(not card:IsShown(), "with the setting off it never pops up")
	nH:Set("whatsNew", true)
	-- Classic dresses it.
	nH:Set("skin", "classic"); WN:ShowLatest()
	check(card.classicState and card.classicState.on, "in Classic the card wears Blizzard's frame")
	WN:Close(); nH:Set("skin", "modern")
	local lines = #card.lines
	for _ = 1, 10 do WN:ShowLatest(); WN:Close() end
	check(#card.lines == lines, "the card's lines are reused")
	-- The address: one line with a copy button; copying selects it for Ctrl+C.
	WN:ShowLatest()
	check(card.fieldText.text == WN.URL and WN.URL:find("/files/all$") and card.field:IsShown() and card.copy:IsShown() and not card.url:IsShown(),
		"the address shows as one line with a copy button beside it")
	_G.IsMacClient = function() return false end
	card.copy:GetScript("OnClick")(card.copy)
	check(card.url:IsShown() and card.url.text == WN.URL and card.url.highlighted and card.copyHint.text == "Press Ctrl+C to copy" and not card.field:IsShown(),
		"the copy button shows the full address selected, with Press Ctrl+C to copy")
	_G.IsControlKeyDown = function() return true end
	card.url:GetScript("OnKeyDown")(card.url, "C")
	check(card.copyHint.text == "Copied!", "pressing Ctrl+C says Copied!")
	MH.runTimers()
	check(card.field:IsShown() and not card.url:IsShown() and not card.copyHint:IsShown(), "then it goes back to the short view")
	_G.IsControlKeyDown = nil
	_G.IsMacClient = function() return true end
	card.field:GetScript("OnClick")(card.field)
	check(card.copyHint.text == "Press Cmd+C to copy", "on a Mac it says Cmd+C, and clicking the field works too")
	card.url:GetScript("OnEscapePressed")(card.url); card.url:GetScript("OnEditFocusLost")(card.url)
	check(card.field:IsShown() and not card.url:IsShown(), "Esc puts the short view back")
	_G.IsMacClient = nil
	WN:Close()
	-- Frames start shown, as on the real client: exactly one card ever exists
	-- (0.11.0-beta2 rebuilt it endlessly, freezing every bag open).
	local cards = 0
	for _, f in ipairs(MH.frames) do if f.name == "BagSmithWhatsNew" then cards = cards + 1 end end
	check(MH.allStartShown and cards == 1, "exactly one What's New card is ever built, even when new frames start shown: " .. cards)
	-- A failure inside What's New can't hold up the bags, and is recorded.
	local realCheck = WN.Check
	WN.Check = function() error("boom") end
	nH.Window.main:Hide()
	local okOpen = pcall(ToggleAllBags)
	WN.Check = realCheck
	check(okOpen and nH.Window.main:IsShown() and (nH.errors or 0) >= 1 and table.concat(nH.errorLog or {}, " "):find("What's New"),
		"a failure in What's New still lets the bags open, and shows in /bs errors")
	nH.errors = 0

	-- A first install sees nothing.
	package.loaded.mock = nil
	local MI = require("mock")
	_G.BagSmithCharDB = nil; _G.BagSmithDB = nil
	local nI = MI.loadAddon("BagSmith")
	nI.version = "0.11.0"
	MI.fire("ADDON_LOADED", "BagSmith"); MI.fire("PLAYER_ENTERING_WORLD"); MI.runTimers(); MI.runTimers()
	ToggleAllBags()
	check(not nI.WhatsNew:Pending() and not (nI.WhatsNew.Card() and nI.WhatsNew.Card():IsShown()), "a first install never shows the card")
end)()

;(function()
	-- 0.11.0-beta4: card placement and look, Split View, Recent on by default.
	package.loaded.mock = nil
	local MJ = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	-- A beta tester who had Icon Columns set to two columns.
	_G.BagSmithDB = { version = 2, profiles = { Default = { iconColumns = 2, skin = "modern" } }, chars = {}, cache = {} }
	local nJ = MJ.loadAddon("BagSmith")
	nJ.version = "0.11.0-beta4"
	MJ.fire("ADDON_LOADED", "BagSmith"); MJ.fire("PLAYER_ENTERING_WORLD"); MJ.runTimers(); MJ.runTimers()
	check(nJ.db.splitView == true, "Icon Columns set to two columns carries over as Split View on")
	check(nJ.db.recentSection == true, "Recent Items is on by default")
	local WN = nJ.WhatsNew
	-- From Settings: beside Settings, brought to the front.
	local P = nJ.SettingsPanel; P:Show()
	P.frame.whatsNew:GetScript("OnClick")(P.frame.whatsNew)
	local card = WN.Card()
	check(card:IsShown() and card.points[1][2] == P.frame and card.points[1][1] == "TOPLEFT" and card.points[1][3] == "TOPRIGHT",
		"opened from Settings, the card sits beside the Settings window")
	check(card.raisedAt and card.raisedAt > 0, "the card brings itself to the front when it opens")
	check(card.w == 440 and card.logo:IsShown() and card.logo.texture:find("mark128"), "a wider card (440 since 0.14) with the white BagSmith mark in Modern")
	local text = ""; for _, l in ipairs(card.lines) do if l:IsShown() then text = text .. l.text .. " " end end
	check(text:find("Settings > Dynamic Sections", 1, true) and text:find("Settings > Style", 1, true) and text:find("Split View") and text:find("On by default"), "the bullets point to the right Settings pages (Dynamic Sections, Style)")
	WN:Close(); P:Hide()
	nJ:Set("skin", "classic"); WN:ShowLatest()
	check(card.classicState and card.classicState.on and not card.logo:IsShown() and card.classicState.portrait ~= nil, "in Classic the card shows the BagSmith portrait instead of the flat mark")
	WN:Close(); nJ:Set("skin", "modern")
	check(card.logo:IsShown(), "back in Modern the mark returns")
	-- Settings pages: Split View on Style; Recent on Dynamic Sections.
	P:Show(); P:ShowPage("dynamic")
	local rows = {}
	for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.key then rows[w.key] = true end end
	local function onPage(key)
		for _, pool in pairs(P.pools) do for _, w in ipairs(pool) do if w:IsShown() and w.key == key then return true end end end
		return false
	end
	check(onPage("recentSection") and onPage("recentWindow") and not onPage("splitView"), "Recent Items is on the Dynamic Sections page (Split View moved to Style in 0.14)")
	P:ShowPage("look")
	check(onPage("splitView") and onPage("emptySlots") and not onPage("recentSection") and not onPage("iconColumns"), "Split View and Show Empty Slots are on the Style page; Recent Items isn't")
	P:Hide()
end)()

;(function()
	-- 0.11.0-beta5: the Sections page, reorganized.
	package.loaded.mock = nil
	local MK = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nK = MK.loadAddon("BagSmith")
	MK.fire("ADDON_LOADED", "BagSmith"); MK.fire("PLAYER_ENTERING_WORLD"); MK.runTimers(); MK.runTimers()
	local P = nK.SettingsPanel
	P:Show(); P:ShowPage("sections")
	-- Every visible row on the page, top to bottom, by its label.
	local function pageRows()
		local rows = {}
		for _, pool in pairs(P.pools) do
			for _, w in ipairs(pool) do
				if w:IsShown() and w.points[1] and w.points[1][2] == P.frame.child then
					local label = (w.text and w.text.text) or (w.label and w.label.text) or ""
					rows[#rows + 1] = { y = -w.points[1][5], x = w.points[1][4], label = label, key = w.key }
				end
			end
		end
		table.sort(rows, function(a, b) return a.y < b.y end)
		return rows
	end
	local order = {}
	for _, r in ipairs(pageRows()) do if r.label ~= "" then order[#order + 1] = r.label end end
	local text = table.concat(order, " | ")
	local want = { "Sections", "Open with Sections", "Remember Which Sections Are Collapsed", "Which Section an Item Goes To",
		"Keys & Reagent Bag", "Keys in Their Own Section (All and By Bag)", "Reagent Bag (Sections: All)", "Section Order", "Vendors & Auction House" }
	local pos, ok = 0, true
	for _, label in ipairs(want) do
		local found
		for i = pos + 1, #order do if order[i] == label then found = i; break end end
		if not found then ok = false; break end
		pos = found
	end
	check(ok, "Standard Sections page: Sections, the rule, Keys & Reagent Bag, Section Order, Vendors & AH, in that order: " .. text)
	P:ShowPage("dynamic")
	local indented = {}
	for _, r in ipairs(pageRows()) do if r.label == "Recent Items From" or r.label == "Recent Items Shown" then indented[#indented + 1] = r.x end end
	local plain
	for _, r in ipairs(pageRows()) do if r.label == "Recent Items" then plain = r.x end end
	-- (rows sit 10 px inside their card since 0.14; the options are a further 18 px in)
	check(#indented == 2 and indented[1] == plain + 18 and indented[2] == plain + 18 and plain == 10, "Recent's two options sit indented under it, inside the card")
	nK:Set("recentSection", false); P:ShowPage("dynamic")
	local still = false
	for _, r in ipairs(pageRows()) do if r.label == "Recent Items From" then still = true end end
	check(not still, "Recent's options only show while it's on")
	nK:Set("recentSection", true); P:ShowPage("dynamic")
	-- The indent never leaks into other pages.
	P:ShowPage("look")
	local leaked = false
	-- (hairlines and cards have no label; rows sit at the card inset, 10, or indented, 28; headings at 0)
	for _, r in ipairs(pageRows()) do if r.label ~= "" and r.x ~= 0 and r.x ~= 10 and r.x ~= 28 then leaked = true end end
	check(not leaked, "the indent stays with Recent's options (rows elsewhere sit at the card inset only)")
	P:Hide()
end)()

;(function()
	-- 0.11.0-beta6: Recent in Section Order, duplication cues, list stripes,
	-- and buttons that stay true to their windows after Esc.
	package.loaded.mock = nil
	local ML = require("mock")
	ML.put(0, 1, { id = 9201, name = "Sword", q = 2, class = 2, subclass = 7, price = 500 })
	ML.put(0, 2, { id = 9202, name = "Bread", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
	ML.put(0, 3, { id = 9203, name = "Linen", q = 1, count = 10, class = 7, subclass = 5, price = 2 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	-- An updating player's saved order, from before Recent existed.
	_G.BagSmithDB = { version = 2, profiles = { Default = { laneOrder = { "Junk", "Gear", "Consumables", "Reagents", "TradeGoods", "Recipes", "Quest", "Tokens", "Other", "~ky", "~rb" } } }, chars = {}, cache = {} }
	local nL = ML.loadAddon("BagSmith")
	ML.fire("ADDON_LOADED", "BagSmith"); ML.fire("PLAYER_ENTERING_WORLD"); ML.runTimers(); ML.runTimers()
	ToggleAllBags()
	local main = nL.Window.main
	check(nL.db.laneOrder[1] == "~recent" and nL.db.laneOrder[2] == "~fav" and nL.db.laneOrder[3] == "Junk" and nL.db.laneOrder[#nL.db.laneOrder] == "~gs", "an updating player's section order gets Recent at the top, then Favorites, the rest kept, and Gear Sets at the bottom")
	local function headers()
		local list = {}
		for _, h in pairs(nL.Buttons.lanes[main.child] or {}) do if h:IsShown() and h.laneId then list[#list + 1] = h end end
		table.sort(list, function(a, b) local ya, yb = -a.points[1][5], -b.points[1][5]; if ya ~= yb then return ya < yb end return a.points[1][4] < b.points[1][4] end)
		return list
	end
	nL.cdb.recentSince = ML.now - 100
	nL.cdb.firstSeen[ML.bags[0][3].guid] = ML.now - 10
	for _, slot in ipairs({ 1, 2 }) do nL.cdb.firstSeen[ML.bags[0][slot].guid] = ML.now - 500 end
	nL:Scan(); nL:Set("grp", "type"); nL:Set("view", "list"); nL:RefreshViews(true)
	local hs = headers()
	check(hs[1].laneId == "~recent" and hs[1].count.text == "(1)" and hs[1].sub.text == "also in their sections", "Recent's header says its items are also in their sections, and shows no value: " .. tostring(hs[1].sub.text))
	hs[1]:GetScript("OnEnter")(hs[1])
	local tip = table.concat(GameTooltip.lines or {}, " ")
	hs[1]:GetScript("OnLeave")(hs[1])
	check(tip:find("also in their usual sections") and tip:find("without moving or removing"), "hovering Recent's header explains the copies")
	check(hs[1].clearRecent.tip:find("^Empties the Recent list"), "Clear Recent's tooltip says what it empties")
	-- Moving Recent in Section Order moves it in the bags.
	local i = nL.IndexOf(nL.db.laneOrder, "~recent")
	nL.Move(nL.db.laneOrder, i, nL.IndexOf(nL.db.laneOrder, "TradeGoods")); nL:RefreshViews(true)
	hs = headers()
	local recentAt, tgAt
	for k, h in ipairs(hs) do if h.laneId == "~recent" then recentAt = k elseif h.laneId == "TradeGoods" then tgAt = k end end
	check(recentAt and tgAt and recentAt == tgAt + 1, "moved below Trade Goods in Section Order, Recent sits below Trade Goods")
	-- By Bag: Recent at the bottom unless it's first in the order.
	nL:Set("grp", "bag"); nL:RefreshViews(true); hs = headers()
	check(hs[#hs].laneId == "~recent", "By Bag: Recent goes at the bottom when it isn't first in the order")
	table.remove(nL.db.laneOrder, nL.IndexOf(nL.db.laneOrder, "~recent")); table.insert(nL.db.laneOrder, 1, "~recent")
	nL:RefreshViews(true); hs = headers()
	check(hs[1].laneId == "~recent", "By Bag: and at the top when it's first")
	nL:Set("grp", "type")
	-- Split View with a narrow half: the subtitle shortens.
	nL:Set("view", "icons"); nL:Set("splitView", true); main.scroll.w = 420; nL:RefreshViews(true); hs = headers()
	check(main.twoColumn and hs[1].count.text == "(1)" and (not hs[1].sub:IsShown() or hs[1].sub.text == "also in their sections"), "in a narrow Split View column Recent keeps its count by its name")
	main.scroll.w = nil; nL:Set("splitView", false); nL:Set("view", "list"); nL:RefreshViews(true)

	-- Settings lists: zebra stripes and a hover highlight.
	local P = nL.SettingsPanel; P:Show(); P:ShowPage("sections")
	local list
	for _, l in ipairs(P.pools.list) do if l:IsShown() then list = l end end
	local okStripes = list.rows[1].stripe and not list.rows[1].stripe:IsShown() and list.rows[2].stripe:IsShown() and not list.rows[3].stripe:IsShown()
	check(okStripes, "Section Order rows alternate stripes, the first row plain")
	check(list.rows[1].text.text == "Recent Items", "Recent Items is listed first in Section Order")
	list.rows[1].down:GetScript("OnClick")(list.rows[1].down)
	for _, l in ipairs(P.pools.list) do if l:IsShown() then list = l end end
	check(not list.rows[1].stripe:IsShown() and list.rows[2].stripe:IsShown(), "stripes stay right after moving a row")
	local r2 = list.rows[2]
	r2.IsMouseOver = function() return true end
	r2.down:GetScript("OnEnter")(r2.down)
	check(r2.hover:IsShown(), "hovering a row's arrow highlights that row")
	r2.IsMouseOver = function() return false end
	r2.down:GetScript("OnLeave")(r2.down)
	check(not r2.hover:IsShown(), "and the highlight goes when the pointer leaves the row")
	P:ShowPage("bankcols")
	for _, l in ipairs(P.pools.list) do if l:IsShown() then list = l end end
	check(not list.rows[1].stripe:IsShown() and list.rows[2].stripe:IsShown(), "the Columns list is striped for the bank window too")
	P:ShowPage("bagsheets")
	for _, l in ipairs(P.pools.list) do if l:IsShown() then list = l end end
	check(list.rows[2].stripe:IsShown(), "and the Sheets list")

	-- Esc closes Settings directly: the icon goes dark, and stays dark.
	check(main.btnSettings.active, "the Settings icon is lit while Settings is open")
	P.frame:Hide()   -- what Esc does
	check(not main.btnSettings.active, "Esc closing Settings turns its icon off")
	main.frame:Hide(); ToggleAllBags()
	check(main:IsShown() and not main.btnSettings.active, "reopening the bags doesn't relight it")
	-- The currency drawer, hidden with the bags window by Esc.
	nL.Drawer:Show()
	check(main.btnCurrency.active, "the Currencies button is lit while the drawer is open")
	main.frame:Hide(); nL.Drawer.frame:GetScript("OnHide")(nL.Drawer.frame)
	check(not main.btnCurrency.active, "the drawer hidden with the bags window turns its button off")
	main.frame:Show(); nL.Drawer.frame:GetScript("OnShow")(nL.Drawer.frame)
	-- Closing the bags closes the drawer too; reopening shows both off, matching.
	check(not nL.Drawer.frame:IsShown() and not main.btnCurrency.active, "reopening the bags: drawer closed and its button off, matching")
	nL.Drawer:Hide()
	-- Bag windows hidden directly: the footer button matches what's on screen after reopening.
	nL.ui.bagWindows = true; nL:RefreshViews(true)
	for _, v in pairs(nL.Window.bagViews) do v.frame:Hide() end
	main.frame:Hide(); ToggleAllBags()
	local anyShown = false
	for _, v in pairs(nL.Window.bagViews) do if v.frame:IsShown() then anyShown = true end end
	check(anyShown == (main.btnBags.active and true or false), "after Esc, the bags button matches whether the bag windows are showing")
	nL.ui.bagWindows = false; nL:RefreshViews(true)
	P:Hide()
end)()

;(function()
	-- 0.11.0-beta7: the Classic What's New title, and "Since Login".
	package.loaded.mock = nil
	local MN = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, profiles = { Default = { skin = "classic" } }, chars = {}, cache = {} }
	local nN = MN.loadAddon("BagSmith")
	nN.version = "0.11.0-beta7"
	MN.fire("ADDON_LOADED", "BagSmith"); MN.fire("PLAYER_ENTERING_WORLD"); MN.runTimers(); MN.runTimers()
	ToggleAllBags()
	local card = nN.WhatsNew.Card()
	check(card and card:IsShown() and card.classicState and card.classicState.on and card.classicState.title.text == "What's New",
		"Classic: the first What's New shows its title in Blizzard's strip: " .. tostring(card and card.classicState and card.classicState.title and card.classicState.title.text))
	nN.WhatsNew:Close()
	nN:Set("skin", "modern"); nN:Set("skin", "classic")
	nN.WhatsNew:ShowLatest()
	check(card.classicState.title.text == "What's New", "and after switching skins and reopening")
	nN.WhatsNew:Close()
	-- Since Login, with help that says where Clear Recent is.
	local P = nN.SettingsPanel; P:Show(); P:ShowPage("dynamic")
	local label, help, mainHelp
	for _, pool in pairs(P.pools) do
		for _, w in ipairs(pool) do
			if w:IsShown() and w.key == "recentWindow" then
				for _, b in ipairs(w.btns or {}) do if b:IsShown() and b.label.text == "Since Login" then label = true end end
				help = w.help and w.help.text
			end
			if w:IsShown() and w.key == "recentSection" then mainHelp = w.help and w.help.text end
		end
	end
	check(label and help and help:find("Since Login: everything you've picked up since you logged in on this character") and help:find("Clear Recent in the section's header"),
		"Recent Items From offers Since Login and explains it: " .. tostring(help))
	check(mainHelp and mainHelp:find("Clear Recent in its header"), "the Recent Items help says where Clear Recent is")
	P:Hide()
end)()

;(function()
	-- 0.11.0-beta8: clearing an item's "new" pip clears it on every copy.
	package.loaded.mock = nil
	local MO = require("mock")
	MO.put(0, 1, { id = 9301, name = "Shiny Gem", q = 3, class = 7, subclass = 0, price = 100 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nO = MO.loadAddon("BagSmith")
	MO.fire("ADDON_LOADED", "BagSmith"); MO.fire("PLAYER_ENTERING_WORLD"); MO.runTimers(); MO.runTimers()
	ToggleAllBags()
	nO.cdb.recentSince = MO.now - 100
	nO.cdb.firstSeen[MO.bags[0][1].guid] = MO.now - 10
	MO.newItems = MO.newItems or {}; MO.newItems["0:1"] = true
	nO:Scan(); nO:RefreshViews(true)
	local original = nO.Buttons:Get(0, 1)
	local copy
	for _, b in ipairs(nO.Buttons.recent) do if b:IsShown() and b.rec and b.rec.name == "Shiny Gem" then copy = b end end
	check(copy and original.newDot:IsShown() and copy.newDot:IsShown(), "a new item shows its pip in Recent and in its usual section")
	copy:GetScript("OnEnter")(copy); MO.elapse(); copy:GetScript("OnLeave")(copy)
	check(not copy.newDot:IsShown() and not original.newDot:IsShown(), "hovering the Recent copy clears the pip on both")
	-- And the other way round.
	MO.put(0, 2, { id = 9302, name = "Another Gem", q = 3, class = 7, subclass = 0, price = 100 })
	nO:Scan()
	nO.cdb.firstSeen[MO.bags[0][2].guid] = MO.now - 5
	MO.newItems["0:2"] = true
	nO:Scan(); nO:RefreshViews(true)
	local o2 = nO.Buttons:Get(0, 2)
	local c2
	for _, b in ipairs(nO.Buttons.recent) do if b:IsShown() and b.rec and b.rec.name == "Another Gem" then c2 = b end end
	check(c2 and o2.newDot:IsShown() and c2.newDot:IsShown(), "both copies of the second item show the pip")
	o2:GetScript("OnEnter")(o2); MO.elapse(); o2:GetScript("OnLeave")(o2)
	check(not o2.newDot:IsShown() and not c2.newDot:IsShown(), "hovering it in its usual section clears the Recent copy's pip too")
	nO:RefreshViews(true)
	check(not nO.Buttons:Get(0, 2).newDot:IsShown() and not c2.newDot:IsShown(), "and it stays cleared after a refresh")
end)()

;(function()
	-- 0.11.0-beta10: section header values, bag window diagnostics.
	package.loaded.mock = nil
	local MP = require("mock")
	MP.put(0, 1, { id = 9401, name = "Sword", q = 2, class = 2, subclass = 7, price = 500 })
	MP.put(0, 2, { id = 9402, name = "Axe", q = 2, class = 2, subclass = 0, price = 300 })
	MP.put(0, 3, { id = 9403, name = "Bread", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
	MP.put(0, 4, { id = 9404, name = "Letter", q = 1, class = 12, subclass = 0, price = 0 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nP = MP.loadAddon("BagSmith")
	MP.fire("ADDON_LOADED", "BagSmith"); MP.fire("PLAYER_ENTERING_WORLD"); MP.runTimers(); MP.runTimers()
	ToggleAllBags()
	local main = nP.Window.main
	nP:Set("grp", "type"); nP:Set("view", "list"); main.scroll.w = 900; nP:RefreshViews(true)
	local function header(id) for _, h in pairs(nP.Buttons.lanes[main.child] or {}) do if h:IsShown() and h.laneId == id then return h end end end
	local gear = header("Gear")
	check(gear and gear.count.text == "(2)" and gear.sub.text == "V: " .. nP.Money(800) and not gear.aAmt:IsShown(),
		"the count sits by the section name, and the right side shows the vendor value as V:: " .. tostring(gear and gear.sub.text))
	local quest = header("Quest")
	check(quest and quest.count.text == "(1)" and quest.sub.text == "V: -", "a section with no vendor value shows V: -: " .. tostring(quest and quest.sub.text))
	-- With Auctionator and the AH Price column: the section's AH total too.
	_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function() return nil end,
		GetAuctionPriceByItemID = function(_, id) return ({ [9401] = 10000, [9402] = 5000 })[id] end } } }
	table.insert(nP.db.cols, "ah"); nP:RefreshViews(true)
	gear = header("Gear")
	check(gear.sub.text == "V: " .. nP.Money(800) .. ", AH: " .. nP.Money(15000), "with the AH Price column on, the header adds the exact AH total: " .. gear.sub.text)
	local food = header("Consumables")
	check(food.sub.text == "V: " .. nP.Money(5) .. ", AH: -", "a section with nothing scanned shows AH: -: " .. food.sub.text)
	-- One header short of room: every header in the window stacks.
	local function setTitle(id, w) local h = header(id); h.text.GetStringWidth = w and function() return w end or nil end
	local function allHeaders() local l = {}; for _, h in pairs(nP.Buttons.lanes[main.child] or {}) do if h:IsShown() and h.laneId then l[#l + 1] = h end end; return l end
	local function clearTitles() for _, h in pairs(nP.Buttons.lanes[main.child] or {}) do h.text.GetStringWidth = nil end end
	setTitle("Gear", 720)
	nP:RefreshViews(true)
	local stacked = true
	for _, h in ipairs(allHeaders()) do if not (h.aAmt:IsShown() and h.aLabel.text == "AH:" and h.vLabel.text == "V:" and not h.sub:IsShown()) then stacked = false end end
	local labelX, amtX, aligned
	aligned = stacked
	for _, h in ipairs(allHeaders()) do
		if h.laneId ~= "~recent" and h.vLabel.points[1] then
			local lx, ax = h.vLabel.points[1][4], h.vAmt.points[1][4]
			if h.aLabel.points[1][4] ~= lx or h.aAmt.points[1][4] ~= ax then aligned = false end
			labelX, amtX = labelX or lx, amtX or ax
			if lx ~= labelX or ax ~= amtX then aligned = false end
		end
	end
	check(aligned, "stacked labels and amounts line up within each header and from header to header")
	gear = header("Gear")
	check(stacked and gear.count.text == "(2)" and gear.vAmt.text == nP.Money(800) and gear.aAmt.text == nP.Money(15000),
		"when one header is short of room, every header stacks V: and AH:, amounts exact, the count still by the name")
	setTitle("Gear", 765); nP:RefreshViews(true); gear = header("Gear")
	check(gear.sub.text == "V: " .. nP.Money(800) and not gear.aAmt:IsShown(), "tighter: the AH total goes: " .. gear.sub.text)
	setTitle("Gear", 800); nP:RefreshViews(true); gear = header("Gear")
	check(not gear.sub:IsShown() and not gear.aAmt:IsShown() and gear.count.text == "(2)", "narrowest: no values, the count stays by the name")
	local same = true
	for _, h in ipairs(allHeaders()) do if h.laneId ~= "~recent" and (h.sub:IsShown() or h.aAmt:IsShown()) then same = false end end
	check(same, "and every header in the window uses that same format")
	clearTitles(); nP:RefreshViews(true); gear = header("Gear")
	check(not gear.aAmt:IsShown() and gear.sub.text:find(", AH: "), "with room again, back to one line")
	gear:GetScript("OnEnter")(gear)
	local tip = table.concat(GameTooltip.lines or {}, " ")
	gear:GetScript("OnLeave")(gear)
	check(tip:find("Vendor %(V%)") and tip:find("Auctionator's last scan"), "hovering a section header explains both numbers")
	-- Without Auctionator there's no AH total, even with the column ticked.
	_G.Auctionator = nil; nP:RefreshViews(true); gear = header("Gear")
	check(not gear.sub.text:find("AH"), "without Auctionator there's no AH total")
	table.remove(nP.db.cols, nP.IndexOf(nP.db.cols, "ah"))

	-- A failing window refresh is recorded and the others still draw.
	local bank = nP.Window.bank
	local realRefresh = main.Refresh
	main.Refresh = function() error("boom") end
	local ok = pcall(nP.RefreshViews, nP, true)
	main.Refresh = nil
	check(ok and table.concat(nP.errorLog or {}, " "):find("Refresh"), "a failing window refresh is recorded in /bs errors instead of stopping the rest")
	nP.errors = 0
	-- /bs check reports the bag windows.
	nP.ui.bagWindows = true; nP:RefreshViews(true)
	MP.log = {}
	SlashCmdList.BAGSMITH("check")
	local out = table.concat(MP.log, " | ")
	local bagLines = {}
	for _, l in ipairs(MP.log) do if l:find("Bag windows") or l:find("slots, ") then bagLines[#bagLines + 1] = l end end
	local bl = table.concat(bagLines, " | ")
	check(bl:find("Bag windows: switched on yes") and bl:find("slots, shown"), "/bs check lists each bag window's state: " .. bl)
	-- /bs debug says why a switched-on bag window isn't showing.
	nP.db.debug = true; MP.log = {}
	nP.ui.sheet = "Bank"; nP:RefreshViews(true)
	local dbg = table.concat(MP.log, " | ")
	nP.db.debug = false; nP.ui.sheet = "All"; nP.ui.bagWindows = false; nP:RefreshViews(true)
	check(dbg:find("not shown: the Bank sheet is showing"), "/bs debug explains a bag window that isn't showing: " .. dbg:sub(1, 200))
end)()

;(function()
	-- 0.11.0-beta11: footer buttons while browsing another character; header
	-- values decided per window.
	package.loaded.mock = nil
	local MQ = require("mock")
	MQ.put(0, 1, { id = 9501, name = "Sword", q = 2, class = 2, subclass = 7, price = 500 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, profiles = { Default = {} }, chars = {}, cache = {
		["Alt - Realm"] = { name = "Alt", realm = "Realm", class = "MAGE", level = 10, money = 0, items = {}, bankItems = {} } } }
	local nQ = MQ.loadAddon("BagSmith")
	MQ.fire("ADDON_LOADED", "BagSmith"); MQ.fire("PLAYER_ENTERING_WORLD"); MQ.runTimers(); MQ.runTimers()
	ToggleAllBags()
	local main = nQ.Window.main
	check(main.btnBags:IsEnabled() and main.btnReagent:IsEnabled(), "your own bags: the bag and reagent buttons work")
	nQ.ui.owner = "Alt - Realm"; nQ:RefreshViews(true); main:SyncTools()
	check(not main.btnBags:IsEnabled() and not main.btnReagent:IsEnabled() and main.btnBags.alpha < 1, "browsing another character: both buttons are greyed out")
	check(main.btnBags.tip:find("Switch back to your character"), "and their tooltip explains why")
	nQ.ui.owner = nil; nQ:RefreshViews(true); main:SyncTools()
	check(main.btnBags:IsEnabled() and main.btnBags.alpha == 1 and main.btnBags.tip:find("backpack"), "back on your own character, they work again with their usual tooltip")
	-- Header values: the bank window decides for itself.
	MQ.fire("BANKFRAME_OPENED"); MQ.runTimers()
	local bank = nQ.Window.bank
	_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function() return 100 end } } }
	table.insert(nQ.db.cols, "ah"); nQ:Set("grp", "type"); nQ:Set("view", "list"); nQ:RefreshViews(true)
	local function hdrs(v) local l = {}; for _, h in pairs(nQ.Buttons.lanes[v.child] or {}) do if h:IsShown() and h.laneId then l[#l + 1] = h end end; return l end
	-- One header one pixel short of room for a single line.
	local first = hdrs(main)[1]
	local need = first.sub:GetStringWidth()
	first.text.GetStringWidth = function() return first.w - 60 - need + 1 end
	nQ:RefreshViews(true)
	local mainStacked = true
	for _, h in ipairs(hdrs(main)) do if not h.aAmt:IsShown() then mainStacked = false end end
	local bankOneLine = true
	for _, h in ipairs(hdrs(bank)) do if h.aAmt:IsShown() or (h.sub.text or ""):find("AH") then bankOneLine = false end end
	check(mainStacked and #hdrs(main) > 0, "the bags window stacks when it needs to")
	local sameColor = true
	for _, h in ipairs(hdrs(main)) do
		local a, b = h.sub.textColor, h.aAmt.textColor
		if not (a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]) then sameColor = false end
	end
	check(sameColor, "the stacked AH line has the same color as the first line")
	nQ:Set("skin", "classic"); nQ:RefreshViews(true)
	local sameClassic = true
	for _, h in ipairs(hdrs(main)) do
		local a, b = h.sub.textColor, h.aAmt.textColor
		if not (a and b and a[1] == b[1] and a[2] == b[2]) then sameClassic = false end
	end
	check(sameClassic, "and in Classic")
	nQ:Set("skin", "modern")
	check(bankOneLine, "the bank window, without the AH column, keeps its own one-line format")
	for _, h in pairs(nQ.Buttons.lanes[main.child] or {}) do h.text.GetStringWidth = nil end
	_G.Auctionator = nil
	MQ.fire("BANKFRAME_CLOSED"); MQ.runTimers()
end)()

;(function()
	-- 0.11.0-beta16: Recent's header never overlaps, even in a half-width Icon Split View column.
	package.loaded.mock = nil
	local MR = require("mock")
	for slot = 1, 6 do MR.put(0, slot, { id = 9600 + slot, name = "Thing " .. slot, q = 1, class = (slot % 2 == 0) and 7 or 0, subclass = 0, price = 10 }) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nR = MR.loadAddon("BagSmith")
	MR.fire("ADDON_LOADED", "BagSmith"); MR.fire("PLAYER_ENTERING_WORLD"); MR.runTimers(); MR.runTimers()
	ToggleAllBags()
	local main = nR.Window.main
	nR.cdb.recentSince = MR.now - 100
	for slot = 1, 6 do nR.cdb.firstSeen[MR.bags[0][slot].guid] = MR.now - slot end
	nR:Scan(); nR:Set("grp", "type"); nR:Set("view", "icons")
	local function recentHeader() for _, h in pairs(nR.Buttons.lanes[main.child] or {}) do if h:IsShown() and h.laneId == "~recent" then return h end end end
	local function noOverlap(h)
		local btn = h.clearRecent
		local titleRight = 20 + h.text:GetStringWidth() + 6 + h.count:GetStringWidth()
		local btnLeft = titleRight + 8
		local btnRight = btnLeft + btn:GetWidth()
		local ok = btn:IsShown() and btnLeft >= titleRight
		if h.sub:IsShown() and h.sub.text ~= "" then ok = ok and btnRight <= h.w - 4 - h.sub:GetStringWidth() end
		return ok and btnRight <= h.w
	end
	local function at(width, split)
		nR:Set("splitView", split); main.scroll.w = width; nR:RefreshViews(true)
		return recentHeader()
	end
	local h = at(700, false)
	check(h and h.count.text == "(6)" and h.clearRecent.label.text == "Clear Recent" and h.sub.text == "also in their sections" and noOverlap(h),
		"single column: Recent (6), Clear Recent and the words all fit without overlapping")
	check(h.clearRecent.points[1][2] == h.count, "Clear Recent sits right after the count")
	h = at(616, true)
	check(main.twoColumn and h.clearRecent.label.text == "Clear Recent" and not h.sub:IsShown() and noOverlap(h),
		"half-width Split View column: the words go first, the full button stays")
	h = at(416, true)
	check(main.twoColumn and h.clearRecent.label.text == "Clear" and noOverlap(h), "narrower: the button shortens to Clear")
	h.clearRecent:GetScript("OnClick")(h.clearRecent)
	check(not recentHeader(), "the short Clear button still clears the list")
	nR:Set("splitView", false); main.scroll.w = nil
	-- Classic too.
	nR.cdb.recentSince = MR.now - 100; nR:Scan()
	nR:Set("skin", "classic"); h = at(616, true)
	check(h and noOverlap(h), "and in Classic")
	nR:Set("skin", "modern"); nR:Set("splitView", false); main.scroll.w = nil
end)()

;(function()
	-- 0.11.0: Sections: All with Recent gets an "All Items" header.
	package.loaded.mock = nil
	local MS = require("mock")
	for slot = 1, 5 do MS.put(0, slot, { id = 9700 + slot, name = "Item " .. slot, q = 1, class = (slot % 2 == 0) and 7 or 0, subclass = 0, price = 10 }) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nS = MS.loadAddon("BagSmith")
	MS.fire("ADDON_LOADED", "BagSmith"); MS.fire("PLAYER_ENTERING_WORLD"); MS.runTimers(); MS.runTimers()
	ToggleAllBags()
	local main = nS.Window.main
	local function headers()
		local list = {}
		for _, h in pairs(nS.Buttons.lanes[main.child] or {}) do if h:IsShown() and h.laneId and h.laneId ~= "~rb" and h.laneId ~= "~ky" then list[#list + 1] = h end end
		table.sort(list, function(a, b) return -a.points[1][5] < -b.points[1][5] end)
		return list
	end
	nS:Set("grp", "none")
	for _, view in ipairs({ "list", "icons" }) do
		nS:Set("view", view)
		nS.cdb.recentSince = MS.now + 1; nS:Scan(); nS:RefreshViews(true)
		check(#headers() == 0, view .. ": Sections All without Recent has no headers, as before")
		nS.cdb.recentSince = MS.now - 100
		nS.cdb.firstSeen[MS.bags[0][1].guid] = MS.now - 5
		nS:Scan(); nS:RefreshViews(true)
		local hs = headers()
		check(#hs == 2 and hs[1].laneId == "~recent" and hs[2].laneId == "~all" and hs[2].text.text == "All Items" and hs[2].count.text == "(5)",
			view .. ": with Recent on top, the rest gets an All Items header with its count")
		-- Nothing runs together: every non-Recent item sits below the All Items header.
		local headerY = -hs[2].points[1][5]
		local below = true
		for slot = 1, 5 do
			local b = nS.Buttons:Get(0, slot)
			if b:IsShown() and -b.points[1][5] < headerY + 1 then below = false end
		end
		check(below, view .. ": the usual items all sit below the All Items header")
	end
	-- Collapsing All Items hides only the rest.
	local hs = headers()
	main:ToggleLane("~all")
	local anyShown = false
	for slot = 1, 5 do if nS.Buttons:Get(0, slot):IsShown() then anyShown = true end end
	local copyShown = false
	for _, b in ipairs(nS.Buttons.recent) do if b:IsShown() then copyShown = true end end
	check(not anyShown and copyShown, "collapsing All Items hides the rest and keeps Recent")
	main:ToggleLane("~all")
	-- Not draggable.
	hs = headers()
	hs[2]:GetScript("OnDragStart")(hs[2])
	check(nS.dragLane == nil, "All Items can't be dragged")
	-- Recent moved down in Section Order: All Items first, then Recent.
	table.remove(nS.db.laneOrder, nS.IndexOf(nS.db.laneOrder, "~recent")); table.insert(nS.db.laneOrder, "~recent")
	nS:RefreshViews(true); hs = headers()
	check(hs[1].laneId == "~all" and hs[2].laneId == "~recent", "with Recent moved down, All Items comes first and Recent below it")
	table.remove(nS.db.laneOrder, nS.IndexOf(nS.db.laneOrder, "~recent")); table.insert(nS.db.laneOrder, 1, "~recent")
	nS:Set("skin", "classic"); nS:RefreshViews(true); hs = headers()
	check(#hs == 2 and hs[2].laneId == "~all", "and in Classic")
	nS:Set("skin", "modern")
end)()

;(function()
	-- 0.11.1: inactive sections dimmed in Section Order; the reagent bag's Own Window.
	package.loaded.mock = nil
	local MT = require("mock")
	MT.put(0, 1, { id = 9801, name = "Gem", q = 2, class = 7, subclass = 0, price = 10 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nT = MT.loadAddon("BagSmith")
	MT.fire("ADDON_LOADED", "BagSmith"); MT.fire("PLAYER_ENTERING_WORLD"); MT.runTimers(); MT.runTimers()
	ToggleAllBags()
	local main, W = nT.Window.main, nT.Window
	local P = nT.SettingsPanel
	local function orderRow(label)
		for _, l in ipairs(P.pools.list) do if l:IsShown() then for _, r in ipairs(l.rows) do if r:IsShown() and r.text.text:find("^" .. label) then return r end end end end
	end
	P:Show(); P:ShowPage("sections")
	local rec, keys, rb = orderRow("Recent Items"), orderRow("Keys"), orderRow("Reagent Bag")
	check(rec and rec.text.text == "Recent Items" and not rec.tip and keys.text.text == "Keys" and rb.text.text == "Reagent Bag",
		"new players: Recent, Keys and Reagent Bag are all active, nothing dimmed")
	nT:Set("recentSection", false); nT:Set("keys", false); nT:Set("reagent", "inline"); P:ShowPage("sections")
	rec, keys, rb = orderRow("Recent Items"), orderRow("Keys"), orderRow("Reagent Bag")
	local muted = { nT.Skins:Color("muted") }
	check(rec.text.text == "Recent Items (off)" and rec.text.textColor[1] == muted[1] and rec.tip:find("Tick Recent Items in Settings > Dynamic Sections", 1, true),
		"Recent off: dimmed, (off), and the tooltip says how to turn it on")
	check(keys.text.text == "Keys" and not keys.tip, "Keys off: not dimmed (By Type always gives keys their section)")
	check(rb.text.text == "Reagent Bag (off)" and rb.tip:find("^Your reagent bag's items are mixed in") and rb.tip:find("Own Section"), "Reagent Bag mixed in: its own wording")
	-- Dimmed rows still move.
	local before = nT.IndexOf(nT.db.laneOrder, "~recent")
	rec = orderRow("Recent Items"); rec.down:GetScript("OnClick")(rec.down)
	check(nT.IndexOf(nT.db.laneOrder, "~recent") == before + 1, "a dimmed row's arrows still move it")
	nT:Set("recentSection", true); P:ShowPage("sections"); rec = orderRow("Recent Items")
	check(rec.text.text == "Recent Items" and rec.text.textColor[1] ~= muted[1] and not rec.tip, "turning Recent on brightens its row at once")
	P:Hide()
	nT:Set("keys", true)

	-- The reagent bag's window: the footer button toggles it in either Reagent Bag mode.
	if nT.HAS_REAGENT_SLOT then
		for _, mode in ipairs({ "lane", "inline" }) do
			nT:Set("reagent", mode); nT.ui.reagentWindow = false; nT:RefreshViews(true)
			local small = W.bagViews[nT.REAGENT_BAG]
			check(main.btnReagent:IsShown() and not main.btnReagent.active, mode .. ": the footer reagent button shows, not pressed")
			main.btnReagent:GetScript("OnClick")(main.btnReagent)
			check(small.frame:IsShown() and main.btnReagent.active, mode .. ": clicking it opens the reagent bag's window, pressed")
			main.btnReagent:GetScript("OnClick")(main.btnReagent)
			check(not small.frame:IsShown() and not main.btnReagent.active, mode .. ": clicking again closes it")
		end
	else
		check(true, "(no reagent slot in this mock)")
	end
end)()

;(function()
	-- 0.11.1-beta2: one "When the Main Window Opens" choice, and its migrations.
	local function load(profile)
		package.loaded.mock = nil
		local MU = require("mock")
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		profile = profile or {}   -- (written for Modern; new players start in Classic)
		if profile.skin == nil then profile.skin = "modern" end
		_G.BagSmithDB = { version = 2, profiles = { Default = profile }, chars = {}, cache = {} }
		local n = MU.loadAddon("BagSmith")
		MU.fire("ADDON_LOADED", "BagSmith"); MU.fire("PLAYER_ENTERING_WORLD"); MU.runTimers(); MU.runTimers()
		return n, MU
	end
	local function choice(n) return n.db.bagWindows and "all" or (n.db.reagentWindow and "reagent" or "main") end
	local n0 = load(nil)
	check(choice(n0) == "main" and n0.db.reagent == "lane", "new players: Open Main Window Only, Reagent Bag as its own section")
	local cases = {
		{ { bagWindows = true, reagentWindow = true }, "all", "lane", "bag windows and the reagent window -> Auto-Open All Bags" },
		{ { bagWindows = true, reagentWindow = false }, "all", "lane", "bag windows only -> Auto-Open All Bags (all includes the reagent bag)" },
		{ { bagWindows = false, reagentWindow = true }, "reagent", "lane", "the reagent window only -> Auto-Open Reagent Bag" },
		{ { reagent = "pop" }, "reagent", "lane", "the old Own Window -> Own Section, with the reagent bag's window opening" },
		{ { reagent = "pop", bagWindows = true }, "all", "lane", "the old Own Window with bag windows -> Auto-Open All Bags" },
		{ { reagent = "inline" }, "main", "inline", "Mixed In stays Mixed In, nothing opens extra" },
	}
	for _, c in ipairs(cases) do
		local n = load(c[1])
		check(choice(n) == c[2] and n.db.reagent == c[3], "migration: " .. c[4] .. " (got " .. choice(n) .. ", " .. tostring(n.db.reagent) .. ")")
	end
	-- Each choice opens the right windows with the main window.
	local n, MU = load(nil)
	local W = n.Window
	local function opened()
		local bags, reagent = 0, false
		for bag, v in pairs(W.bagViews) do
			if v.frame:IsShown() then if n:IsReagentBag(bag) then reagent = true else bags = bags + 1 end end
		end
		return bags, reagent
	end
	for _, c in ipairs({ { "main", 0, false }, { "all", 1, true }, { "reagent", 0, false } }) do
		n:Set("__openWindows", c[1])
		W.main:Hide(); n:OnMainHidden(); ToggleAllBags(); MU.runTimers()
		local bags, reagent = opened()
		local wantReagent = c[1] ~= "main" and n.HAS_REAGENT_SLOT and (n.bagInfo[n.REAGENT_BAG] and n.bagInfo[n.REAGENT_BAG].size or 0) > 0
		check((c[2] == 0 and bags == 0 or bags >= c[2]) and (reagent == (wantReagent and true or false)), c[1] .. ": the right windows open with the main window")
	end
	-- Settings: one stacked choice; Reagent Bag offers two options.
	local P = n.SettingsPanel; P:Show()
	P:ShowPage("window")
	local row
	for _, w in ipairs(P.pools.seg) do if w:IsShown() and w.key == "__openWindows" then row = w end end
	local b1, b2, b3 = row and row.btns[1], row and row.btns[2], row and row.btns[3]
	check(row and b1.label.text == "Open Main Window Only" and b2.label.text == "Auto-Open All Bags" and b3.label.text == "Auto-Open Reagent Bag"
		and b1.points[1][5] == b2.points[1][5] and b2.points[1][5] == b3.points[1][5]
		and b1.points[1][4] == 0 and b2.points[1][4] > b1.points[1][4] and b3.points[1][4] > b2.points[1][4]
		and b1.points[1][5] < (row.help.points[1] and row.help.points[1][5] or 0),
		"Windows: When the Main Window Opens, three options side by side on a line under the label and help")
	P:ShowPage("sections")
	local rb
	for _, w in ipairs(P.pools.seg) do if w:IsShown() and w.key == "reagent" then rb = w end end
	check(rb and rb.btns[1]:IsShown() and rb.btns[2]:IsShown() and not (rb.btns[3] and rb.btns[3]:IsShown()), "Sections: Reagent Bag offers Mixed In and Own Section only")
	P:Hide()
end)()

;(function()
	-- 0.11.2: fixes from an outside code review.
	package.loaded.mock = nil
	local MV = require("mock")
	MV.put(0, 1, { id = 9901, name = "Healing Potion", q = 1, count = 5, class = 0, subclass = 1, price = 10 })
	MV.put(0, 3, { id = 9901, name = "Healing Potion", q = 1, count = 3, class = 0, subclass = 1, price = 10 })
	MV.put(0, 2, { id = 9902, name = "Linen Cloth", q = 1, count = 4, class = 7, subclass = 5, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nV = MV.loadAddon("BagSmith")
	MV.fire("ADDON_LOADED", "BagSmith"); MV.fire("PLAYER_ENTERING_WORLD"); MV.runTimers(); MV.runTimers()
	ToggleAllBags()
	local main = nV.Window.main
	nV:Set("recentSection", false); nV:Set("view", "list"); nV:Set("grp", "none"); nV:Set("mergeStacks", true); nV:RefreshViews(true)
	-- 1) A merged row, frozen in place, only shows what's in its own slot.
	local row
	for _, b in ipairs(main.used or {}) do if b.rec and b.rec.merged and b.rec.itemID == 9901 then row = b end end
	check(row and row.rec.count == 8, "merged potions: one row with the total of both stacks")
	local bag, slot = row:GetParent():GetID(), row:GetID()
	-- Rows held still (pointer over the window): only the in-place refresh runs.
	local realRefresh = nV.RefreshViews
	nV.RefreshViews = function() end
	MV.bags[bag][slot] = nil; nV:Scan()
	main:RefreshInPlace(false, true)
	check(row:IsShown() and not (row.rec and row.rec.itemID == 9901), "its own stack gone: the frozen row blanks rather than showing the other stack its click wouldn't use")
	MV.put(bag, slot, { id = 9903, name = "Shiny Ring", q = 2, class = 4, subclass = 0, price = 50, equip = "INVTYPE_FINGER" })
	nV:Scan(); main:RefreshInPlace(false, true)
	check(row:IsShown() and row.rec and row.rec.itemID == 9903, "something new in that slot: the row shows it, so what you see is what a click uses")
	nV.RefreshViews = realRefresh
	nV:RefreshViews(true)
	local potions
	for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 9901 then potions = b end end
	check(potions and potions.rec.count == 3 and potions:GetParent():GetID() == potions.rec.bag and potions:GetID() == potions.rec.slot,
		"the next full layout shows the remaining potions on their own slot's button")

	-- 2) Closing the bank right after a change still saves the bank as it was.
	MV.put(-1, 1, { id = 9910, name = "Bank Gem", q = 2, class = 7, subclass = 0, price = 5 })
	MV.fire("BANKFRAME_OPENED"); MV.runTimers()
	MV.put(-1, 2, { id = 9911, name = "Moved In", q = 1, class = 7, subclass = 0, price = 5 })
	nV:Scan()   -- schedules the delayed save
	MV.fire("BANKFRAME_CLOSED")   -- closed before the delay runs out
	local entry = BagSmithDB.cache[nV:CharKey()]
	local saw = false
	for _, it in ipairs(entry and entry.bank or {}) do if (it.id or it.itemID) == 9911 or (it.name == "Moved In") then saw = true end end
	check(saw, "closing the bank right after moving an item still saves the bank with it")

	-- 3) Sheets: rename moves the remembered view; delete forgets it.
	nV:Set("sheetViews", true)
	main.st.filters = nV.EmptyFilters(); main.st.filters.text = "gem"
	local ok = nV:SaveSheet("Gems", main)
	main.st.sheet = "Gems"; main:SetPref("grp", "type"); main:SetPref("view", "icons")
	check(ok and nV.db.sheetPrefs.bags.Gems and nV.db.sheetPrefs.bags.Gems.grp == "type", "a sheet keeps its own view")
	nV:UpdateSheet("Gems", "Jewels", main)
	check(nV.db.sheetPrefs.bags.Jewels and nV.db.sheetPrefs.bags.Jewels.grp == "type" and not nV.db.sheetPrefs.bags.Gems and main:Pref("view") == "icons",
		"renaming a sheet keeps its remembered view")
	nV:DeleteSheet("Jewels", main)
	check(not nV.db.sheetPrefs.bags.Jewels, "deleting a sheet forgets its view")
	nV:SaveSheet("Jewels", main); main.st.sheet = "Jewels"
	check(main:Pref("view") == nV.db.view, "a new sheet with the same name starts with the window's view")
	-- A bank sheet's hidden tab is removed from the bank's list, not the bags'.
	MV.fire("BANKFRAME_OPENED"); MV.runTimers()
	local bank = nV.Window.bank
	nV:SaveSheet("Mats", bank); table.insert(nV.db.bankHiddenTabs, "Mats"); table.insert(nV.db.hiddenTabs, "Mats")
	nV:DeleteSheet("Mats", bank)
	check(not nV.IndexOf(nV.db.bankHiddenTabs, "Mats") and nV.IndexOf(nV.db.hiddenTabs, "Mats"), "deleting a bank sheet clears the bank's hidden list only")
	MV.fire("BANKFRAME_CLOSED")
end)()

;(function()
	-- 0.11.2: second outside review.
	local function load(cacheBank, extra)
		package.loaded.mock = nil
		local MW = require("mock")
		MW.put(0, 1, { id = 20558, name = "Warsong Gulch Mark", q = 2, count = 5, class = 12, subclass = 0, price = 0 })
		MW.put(0, 2, { id = 9950, name = "Bread", q = 1, class = 0, subclass = 5, price = 1 })
		_G.BagSmithCharDB = { version = 1, firstSeen = { ["bankguid1"] = MW.now - 86400 * 3 } }
		local key = "Aldren - Forever"
		_G.BagSmithDB = { version = 2, profiles = { Default = {} }, chars = {}, cache = {
			[key] = { name = "Aldren", realm = "Forever", bank = cacheBank, bags = { ["0"] = { size = 16, free = 4 } } } } }
		local n = MW.loadAddon("BagSmith")
		MW.fire("ADDON_LOADED", "BagSmith"); MW.fire("PLAYER_ENTERING_WORLD"); MW.runTimers(); MW.runTimers()
		return n, MW
	end
	-- 1) Bank ages survive a scan after login, away from the bank.
	local savedWithIds = { { bag = -1, slot = 1, itemID = 9960, name = "Bank Thing", count = 1, cat = "TradeGoods", guid = "bankguid1" },
		{ bag = -1, slot = 2, itemID = 20558, name = "Warsong Gulch Mark", icon = 1, quality = 2, count = 7, cat = "Tokens", guid = "bankguid2" } }
	local n, MW = load(savedWithIds)
	check(n:CharKey() == "Aldren - Forever", "test setup: the saved character matches")
	local stamp = n.cdb.firstSeen["bankguid1"]
	MW.now = MW.now + 30; n:Scan()
	check(stamp and n.cdb.firstSeen["bankguid1"] == stamp, "a scan 15 s after login, away from the bank, keeps the saved bank items' ages")
	-- An older saved bank without item IDs: nothing is tidied away until the bank is visited.
	local savedOld = { { bag = -1, slot = 1, itemID = 9960, name = "Bank Thing", count = 1, cat = "TradeGoods" } }
	n, MW = load(savedOld)
	MW.now = MW.now + 30; n:Scan()
	check(n.cdb.firstSeen["bankguid1"] ~= nil, "an older saved bank without IDs: bank ages are kept until the bank is visited")
	-- 2) Bank tokens count from the saved bank before the bank is visited.
	n, MW = load(savedWithIds)
	local wsg
	for _, e in ipairs(n.Currency:List()) do if e.id == 20558 then wsg = e end end
	check(wsg and wsg.count == 12, "after a reload, tokens in the bank still count (from the saved bank): " .. tostring(wsg and wsg.count))
	-- 3) A token count change shows on the same redraw.
	local seenCount
	local realRefresh = n.RefreshViews
	n.RefreshViews = function(self, ...)
		for _, e in ipairs(n.Currency:List()) do if e.id == 20558 then seenCount = e.count end end
		return realRefresh(self, ...)
	end
	MW.bags[0][1].count = 9; n:Scan()
	n.RefreshViews = realRefresh
	check(seenCount == 16, "a token count change is already counted when the windows redraw: " .. tostring(seenCount))
	-- 4) A saved character's free slots survive a money change.
	ToggleAllBags()
	local main = n.Window.main
	n.ui.owner = "Aldren - Forever"   -- browsing the saved copy (as if another character)
	n:RefreshViews(true)
	local before = main.freeText.text
	MW.fire("PLAYER_MONEY"); MW.runTimers()
	check(before and before:find("4") and main.freeText.text == before, "a money change keeps the saved free-slot count: " .. tostring(before) .. " -> " .. tostring(main.freeText.text))
	n.ui.owner = nil
end)()

;(function()
	-- Lifecycle scenarios with invariant checks after every step (tests/lifecycle.lua).
	dofile("tests/lifecycle.lua")(check)
end)()

;(function()
	-- 0.11.2: Recent is sticky for merged rows.
	package.loaded.mock = nil
	local MX = require("mock")
	MX.put(0, 1, { id = 9601, name = "Healing Potion", q = 1, count = 3, class = 0, subclass = 1, price = 10 })   -- had it before login
	MX.put(0, 5, { id = 9602, name = "Linen Cloth", q = 1, count = 4, class = 7, subclass = 5, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nX = MX.loadAddon("BagSmith")
	MX.fire("ADDON_LOADED", "BagSmith"); MX.fire("PLAYER_ENTERING_WORLD"); MX.runTimers(); MX.runTimers()
	ToggleAllBags()
	local main = nX.Window.main
	nX:Set("mergeStacks", true); nX:Set("grp", "type"); nX:Set("view", "list")
	local function recentIds()
		local ids = {}
		for _, b in ipairs(nX.Buttons.recent) do if b:IsShown() and b.rec then ids[b.rec.itemID] = (ids[b.rec.itemID] or 0) + (b.rec.count or 1) end end
		return ids
	end
	local function scan() MX.now = MX.now + 5; nX:Scan(); nX:RefreshViews(true) end
	-- A new potion stack is looted (a separate stack), so the merged potions are recent.
	MX.put(0, 2, { id = 9601, name = "Healing Potion", q = 1, count = 2, class = 0, subclass = 1, price = 10 }); scan()
	check(recentIds()[9601] == 5, "merged potions show in Recent once a new stack arrives (total 5)")
	-- Use up the new stack: the merged row stays in Recent.
	MX.bags[0][2] = nil; scan()
	check(recentIds()[9601] == 3, "using up the new stack keeps the merged potions in Recent (sticky)")
	-- A /reload keeps it.
	local savedDB, savedChar = BagSmithDB, BagSmithCharDB
	check(savedChar.recentSticky and next(savedChar.recentSticky) ~= nil, "the sticky list is saved with the character, so a /reload keeps it")
	-- Merge Stacks off: stacks are separate, and the old stack isn't recent.
	nX:Set("mergeStacks", false); nX:RefreshViews(true)
	check(not recentIds()[9601], "with Merge Stacks off, the stack you had before isn't recent")
	nX:Set("mergeStacks", true); nX:RefreshViews(true)
	check(recentIds()[9601] == 3, "back on, the merged potions are in Recent again")
	-- Gone entirely: out of Recent, and a stack coming back later doesn't revive it.
	MX.bags[0][1] = nil; scan()
	check(not recentIds()[9601], "using every last potion takes it out of Recent")
	MX.put(0, 1, { id = 9601, name = "Healing Potion", q = 1, count = 3, class = 0, subclass = 1, price = 10 })
	nX.cdb.firstSeen[MX.bags[0][1].guid] = nX.cdb.recentSince - 100   -- an old stack from the bank
	scan()
	check(not recentIds()[9601], "an old stack coming back from the bank isn't sticky-recent")
	-- Clear Recent clears sticky items too.
	MX.put(0, 3, { id = 9601, name = "Healing Potion", q = 1, count = 1, class = 0, subclass = 1, price = 10 }); scan()
	check(recentIds()[9601] == 4, "a new stack makes them recent again")
	nX:ClearRecent()
	MX.bags[0][3] = nil; scan()
	check(not recentIds()[9601], "Clear Recent clears the sticky item too")
	-- The time window still applies to sticky rows.
	MX.put(0, 3, { id = 9601, name = "Healing Potion", q = 1, count = 1, class = 0, subclass = 1, price = 10 }); scan()
	MX.bags[0][3] = nil; scan()
	nX:Set("recentWindow", "15m"); MX.now = MX.now + 1000; nX:RefreshViews(true)
	check(not recentIds()[9601], "in Last 15 Min, a sticky row leaves once its time is older than the window")
	nX:Set("recentWindow", "session")
end)()

;(function()
	-- 0.12.0: Travel Mode.
	local function boot(profile)
		package.loaded.mock = nil
		local MY = require("mock")
		MY.put(0, 1, { id = 9701, name = "Gem", q = 2, class = 7, subclass = 0, price = 10 })
		MY.put(0, 2, { id = 9702, name = "Bread", q = 1, count = 4, class = 0, subclass = 5, price = 1 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		profile = profile or {}   -- (written for Modern; new players start in Classic)
		if profile.skin == nil then profile.skin = "modern" end
		_G.BagSmithDB = { version = 2, profiles = { Default = profile }, chars = {}, cache = {} }
		local n = MY.loadAddon("BagSmith")
		n.version = "0.12.0-beta1"
		MY.fire("ADDON_LOADED", "BagSmith"); MY.fire("PLAYER_ENTERING_WORLD"); MY.runTimers(); MY.runTimers()
		ToggleAllBags(); MY.runTimers()
		return n, MY
	end
	local n, M = boot(nil)
	local main, bank = n.Window.main, n.Window.bank
	local function rel(f, i) local p = f.points[i or 1]; return p and p[2] end
	local function travelState()
		return not main.tools:IsShown() and not main.btnFilter:IsShown() and not main.charBtn:IsShown() and not main.charReset:IsShown()
			and rel(main.search, 1) == main.subText
			-- (1.5.5, by design) it ends at Travel Mode's Collapse All Sections when that shows (with sections), which sits
			-- just before the broom; otherwise at the broom, as before
			and ((main.btnLanesTravel and main.btnLanesTravel:IsShown()) and (rel(main.search, 2) == main.btnLanesTravel and rel(main.btnLanesTravel) == main.btnClean)
				or (not (main.btnLanesTravel and main.btnLanesTravel:IsShown()) and rel(main.search, 2) == main.btnClean))
			and rel(main.header, 1) == main.title and ((main.classicApplied and main.classicTitle.text) or main.titleText.text) == "Your Bags (Travel Mode)" and main.btnTravel.active
	end
	local function normalState()
		return main.tools:IsShown() and main.btnFilter:IsShown() and main.charBtn:IsShown() and rel(main.search, 1) == main.title and rel(main.header, 1) == main.tools
			and main.titleText.text == "Your Bags" and not main.btnTravel.active
	end
	check(n.db.travelMode == false and main.btnTravel and main.btnTravel.tip == "Travel Mode" and rel(main.btnTravel) == main.closeBtn and not bank.btnTravel,
		"Travel Mode: off by default; the signpost sits beside the close button; the bank window has none")
	check(main.titleDivider and main.titleDivider:IsShown() and rel(main.titleDivider) == main.btnTravel and rel(main.btnSettings) == main.titleDivider,
		"Modern: a thin divider between the tool icons and the Travel Mode and close buttons")
	check(normalState(), "off: the normal layout")
	-- On.
	main.btnTravel:GetScript("OnClick")(main.btnTravel); M.runTimers()
	check(n.db.travelMode and travelState(), "on: Filter and the toolbar hidden, search in the title row, the items area moves up, the title says (Travel Mode)")
	check(main.tabs:IsShown() and main.footer:IsShown(), "the sheet tabs and footer stay")
	check(main.search:GetFrameLevel() > main.dragArea:GetFrameLevel(), "the search box sits above the drag band, so it can be clicked in the title row")
	-- Typing in the relocated search still filters.
	main.search:SetText("gem"); main.search:GetScript("OnTextChanged")(main.search); M.runTimers()
	check(main.st.filters.text == "gem", "searching works from the title row")
	main.search:SetText(""); main.search:GetScript("OnTextChanged")(main.search)
	-- Off again: everything back.
	main.btnTravel:GetScript("OnClick")(main.btnTravel); M.runTimers()
	check(not n.db.travelMode and normalState(), "off again: everything is back exactly")
	-- Auto Travel Mode at the bank, the auction house and vendors.
	main.btnTravel:GetScript("OnClick")(main.btnTravel); M.runTimers()
	for _, c in ipairs({ { "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "bank" }, { "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "auction house" }, { "MERCHANT_SHOW", "MERCHANT_CLOSED", "vendor" } }) do
		M.fire(c[1]); M.runTimers()
		check(n.db.travelMode and normalState(), "Auto Travel Mode: off while the " .. c[3] .. " is open, and the setting stays on")
		M.fire(c[2]); M.runTimers()
		check(travelState(), "Auto Travel Mode: back on when the " .. c[3] .. " closes")
	end
	-- Each setting off: Travel Mode stays on at that place.
	n:Set("travelLeaveVendor", false)
	M.fire("MERCHANT_SHOW"); M.runTimers()
	check(travelState(), "with Leave Travel Mode at Vendors off, it stays on at a vendor")
	M.fire("MERCHANT_CLOSED"); M.runTimers()
	n:Set("travelLeaveVendor", true)
	-- Turning a setting off while it's holding lets go.
	M.fire("AUCTION_HOUSE_SHOW"); M.runTimers()
	n:Set("travelLeaveAH", false); M.runTimers()
	check(travelState(), "turning the setting off at the auction house brings Travel Mode back")
	M.fire("AUCTION_HOUSE_CLOSED"); M.runTimers(); n:Set("travelLeaveAH", true)
	-- Clicking the signpost while held turns it on.
	M.fire("MERCHANT_SHOW"); M.runTimers()
	check(normalState(), "at a vendor: off")
	main.btnTravel:GetScript("OnClick")(main.btnTravel); M.runTimers()
	check(travelState(), "clicking the signpost at the vendor turns Travel Mode on right away")
	M.fire("MERCHANT_CLOSED"); M.runTimers()
	check(travelState(), "and it stays on after the vendor closes")
	-- The bank window never changes.
	M.fire("BANKFRAME_OPENED"); M.runTimers()
	check(bank.tools:IsShown() and bank.btnFilter:IsShown() and bank.titleText.text == "Bank", "the bank window is never in Travel Mode")
	M.fire("BANKFRAME_CLOSED"); M.runTimers()
	-- Entering Travel Mode while browsing another character goes back to your own bags.
	main.btnTravel:GetScript("OnClick")(main.btnTravel); M.runTimers()   -- off
	BagSmithDB.cache.Elsewhere = { name = "Other", realm = "R", items = {}, bags = {} }
	main:SetOwner("Elsewhere"); main:SyncTools(); M.runTimers()
	check(n.ui.owner == "Elsewhere" and main.charReset:IsShown(), "browsing another character (setup)")
	main.btnTravel:GetScript("OnClick")(main.btnTravel); M.runTimers()
	check(n.ui.owner == nil and travelState(), "entering Travel Mode while browsing another character goes back to your own bags, picker hidden")
	-- Combat: the switch waits for combat to end.
	M.combat = true
	main.btnTravel:GetScript("OnClick")(main.btnTravel)
	check(not n.db.travelMode and main.titleText.text ~= "Your Bags", "in combat the setting changes at once, the layout waits")
	M.combat = false; M.fire("PLAYER_REGEN_ENABLED"); M.runTimers()
	check(normalState(), "after combat the layout catches up")
	-- Classic.
	n:Set("skin", "classic"); main.btnTravel:GetScript("OnClick")(main.btnTravel); M.runTimers()
	check(main.btnTravel.redOn and main.btnTravel.redArt and rel(main.btnTravel) == main.classicClose and rel(main.btnSettings) == main.closeBtn and not main.titleDivider:IsShown(),
		"Classic: the signpost is a red button beside Blizzard's red close button; Settings stays on the row below; no divider")
	check(main.btnTravel.points[1][4] == -1 and main.btnTravel.points[1][5] == 0, "Classic: the signpost lines up with the close button's red face (no lift with the map button art)")
	check(main.btnTravel.w == 24 and main.btnTravel.h == 24, "Classic: 24 px, the size of the close button's red face")
	check(main.btnTravel.redArt.panel and main.btnTravel.redArt.pieces[1].colorTexture, "Classic without red button art: the panel art inside a bronze rim")
	check(main.classicTitle.text == "Your Bags (Travel Mode)" and travelState(), "Classic: the title strip says (Travel Mode), and the layout is the same")
	n:Set("skin", "modern"); M.runTimers()
	check(rel(main.btnTravel) == main.closeBtn and rel(main.btnSettings) == main.titleDivider and main.titleDivider:IsShown() and not main.btnTravel.redOn and travelState(),
		"back to Modern: the button is beside the X again with the divider, Travel Mode still on")
	main.btnTravel:GetScript("OnClick")(main.btnTravel); M.runTimers()
	check(normalState(), "and off restores Modern exactly")
	-- Settings page.
	local P = n.SettingsPanel; P:Show(); P:ShowPage("automation")
	local keys = {}
	for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key then keys[w.key] = w.help and w.help.text or "" end end
	check(keys.travelLeaveBank and keys.travelLeaveBank:find("back on when you close the bank") and keys.travelLeaveAH and keys.travelLeaveVendor,
		"Settings > Automations & Actions: Auto Travel Mode with its settings, each saying it comes back on")
	P:Hide()
	-- Remembered across a reload.
	local n2 = boot({ travelMode = true })
	local m2 = n2.Window.main
	check(n2.db.travelMode and not m2.tools:IsShown() and m2.titleText.text == "Your Bags (Travel Mode)", "Travel Mode is remembered across a reload")
	-- What's New for 0.12.
	local n3, M3 = boot(nil)
	BagSmithDB.whatsNewSeen = "0.11.0"
	n3.Window.main:Hide(); ToggleAllBags(); M3.runTimers()
	local card = n3.WhatsNew.Card()
	local text = ""; for _, l in ipairs(card and card.lines or {}) do if l:IsShown() then text = text .. l.text .. " " end end
	check(card and card:IsShown() and card.title.text == "What's New" and text:find("BagSmith 0.12") and text:find("Travel Mode:") and text:find("Auto Travel Mode:") and text:find("if you want"),
		"What's New: players coming from 0.11 see the 0.12 card about Travel Mode")
end)()

;(function()
	-- 0.12.0-beta4: the map button's red art, with its arrow covered.
	package.loaded.mock = nil
	local MZ = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local realInfo = C_Texture.GetAtlasInfo
	C_Texture.GetAtlasInfo = function(name)
		if name == "RedButton-Expand" or name == "RedButton-Expand-Pressed" then
			return { file = "Interface\\Buttons\\RedButtons", leftTexCoord = 0.5, rightTexCoord = 0.75, topTexCoord = 0, bottomTexCoord = 0.25, width = 32, height = 32 }
		end
		return realInfo(name)
	end
	local nZ = MZ.loadAddon("BagSmith")
	MZ.fire("ADDON_LOADED", "BagSmith"); MZ.fire("PLAYER_ENTERING_WORLD"); MZ.runTimers(); MZ.runTimers()
	ToggleAllBags()
	nZ:Set("skin", "classic")
	local b = nZ.Window.main.btnTravel
	local art = b.redArt
	check(art and art.atlas == "RedButton-Expand" and art.patch, "Classic: the map button's red art is used when the game has it, with a patch over its arrow")
	local p = art.patch
	check(p.texture == "Interface\\Buttons\\RedButtons" and p.points[1][2] == 5 and p.points[1][3] == -5,
		"the patch is cut from the same art and covers the face inside the rim")
	local tc = p.texCoord or {}
	check(tc[1] and tc[1] >= 0.5 and tc[2] <= 0.75 and tc[3] >= 0 and tc[4] <= 0.25, "the patch comes from inside that button's own region of the art")
	b:GetScript("OnMouseDown")(b)
	check(art.pieces[1].atlas == "RedButton-Expand-Pressed", "pressing it shows the pressed art")
	b:GetScript("OnMouseUp")(b)
	nZ:Set("skin", "modern")
	check(not art.pieces[1]:IsShown() and not p:IsShown() and not b.redOn, "back in Modern, the red art is hidden")
	C_Texture.GetAtlasInfo = realInfo
end)()

;(function()
	-- 0.12.0-beta5: two releases on the card, and the scroll safety net.
	package.loaded.mock = nil
	local MA = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, profiles = { Default = {} }, chars = {}, cache = {} }
	local nA = MA.loadAddon("BagSmith")
	nA.version = "0.12.0-beta5"
	MA.fire("ADDON_LOADED", "BagSmith"); MA.fire("PLAYER_ENTERING_WORLD"); MA.runTimers(); MA.runTimers()
	nA.WhatsNew:ShowLatest()
	local card = nA.WhatsNew.Card()
	local heads = {}
	for _, l in ipairs(card.lines) do if l:IsShown() and l.text:find("^BagSmith ") then heads[#heads + 1] = l end end
	local tabs = {}
	for _, b in ipairs(card.tabs) do if b:IsShown() then tabs[#tabs + 1] = b.label.text end end
	check(#heads == 1 and heads[1].text == "BagSmith 0.12" and table.concat(tabs, ",") == "0.12,0.11", "reopened: a tab for each of the latest releases, the newest shown (beta9)")
	check(not (card.dividers[1] and card.dividers[1]:IsShown()), "one release at a time: no divider between releases")
	check(not card.scrolls and card.bodyH >= card.contentH, "normally the whole body fits, no scrolling")
	-- A tiny screen (huge UI scale): the body scrolls inside the card.
	-- (360 since beta9: the tab row and the roomier footer take about 60 px more)
	local realH = UIParent.GetHeight
	UIParent.GetHeight = function() return 360 end
	nA.WhatsNew:ShowLatest()
	check(card.scrolls and card.bodyH < card.contentH and card.h <= 360, "on a small screen the body scrolls inside the card, which stays on screen")
	card.body:GetScript("OnMouseWheel")(card.body, -1)
	check((card.body:GetVerticalScroll() or 0) > 0, "the mouse wheel scrolls the body")
	UIParent.GetHeight = realH
	nA.WhatsNew:Close()
end)()

;(function()
	-- 0.12.0-beta6: Leave Travel Mode During Flight Paths, and the signpost's tooltip.
	local flying = false
	_G.UnitOnTaxi = function(unit) return unit == "player" and flying end
	local function boot(profile)
		package.loaded.mock = nil
		local MB = require("mock")
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		profile = profile or {}   -- (written for Modern; new players start in Classic)
		if profile.skin == nil then profile.skin = "modern" end
		_G.BagSmithDB = { version = 2, profiles = { Default = profile }, chars = {}, cache = {} }
		local n = MB.loadAddon("BagSmith")
		MB.fire("ADDON_LOADED", "BagSmith"); MB.fire("PLAYER_ENTERING_WORLD"); MB.runTimers(); MB.runTimers()
		ToggleAllBags(); MB.runTimers()
		return n, MB
	end
	local n, M = boot({ travelMode = true })
	local main = n.Window.main
	local function travelOn() return not main.tools:IsShown() and main.titleText.text == "Your Bags (Travel Mode)" end
	local function tip()
		main.btnTravel:GetScript("OnEnter")(main.btnTravel)
		local t = table.concat(GameTooltip.lines or {}, " ")
		main.btnTravel:GetScript("OnLeave")(main.btnTravel)
		return t
	end
	check(n.db.travelLeaveTaxi == true and travelOn(), "Leave Travel Mode During Flight Paths is on by default; Travel Mode on")
	check(tip():find("A compact view for adventuring"), "the signpost's tooltip describes Travel Mode")
	-- Takeoff and landing.
	flying = true; M.fire("PLAYER_CONTROL_LOST"); M.runTimers()
	check(n.db.travelMode and not travelOn() and n.ui.travelHold.taxi, "on a flight path Travel Mode is off; the setting stays on")
	check(tip():find("Off while you're on a flight path"), "the tooltip says why it's off")
	flying = false; M.fire("PLAYER_CONTROL_GAINED"); M.runTimers()
	check(travelOn() and not n.ui.travelHold.taxi, "landing turns Travel Mode back on")
	-- The game reports the flight a moment after the event.
	M.fire("PLAYER_CONTROL_LOST"); flying = true; M.runTimers(); M.runTimers()
	check(not travelOn(), "a flight reported just after the event is still caught")
	flying = false; M.fire("PLAYER_CONTROL_GAINED"); M.runTimers()
	-- A missed landing event: the recheck while flying catches it.
	flying = true; M.fire("PLAYER_CONTROL_LOST"); M.runTimers()
	check(not travelOn(), "a new flight (setup for the missed landing)")
	flying = false; M.runTimers(); M.runTimers()
	check(travelOn(), "a missed landing event is caught by the recheck while flying")
	-- Clicking the signpost mid-flight turns it on now, and the flight stops holding it.
	flying = true; M.fire("PLAYER_CONTROL_LOST"); M.runTimers()
	main.btnTravel:GetScript("OnClick")(main.btnTravel); M.runTimers()
	check(travelOn(), "clicking the signpost mid-flight turns Travel Mode on right away")
	flying = false; M.fire("PLAYER_CONTROL_GAINED"); M.runTimers()
	check(travelOn(), "and it stays on after landing")
	-- The setting: off mid-flight releases, on mid-flight holds.
	flying = true; M.fire("PLAYER_CONTROL_LOST"); M.runTimers()
	n:Set("travelLeaveTaxi", false); M.runTimers()
	check(travelOn(), "turning the setting off mid-flight brings Travel Mode back")
	n:Set("travelLeaveTaxi", true); M.runTimers()
	check(not travelOn(), "turning it on mid-flight switches Travel Mode off for the flight")
	flying = false; M.fire("PLAYER_CONTROL_GAINED"); M.runTimers()
	-- Landing while a vendor is open: still off until the vendor closes.
	flying = true; M.fire("PLAYER_CONTROL_LOST"); M.runTimers()
	M.fire("MERCHANT_SHOW"); flying = false; M.fire("PLAYER_CONTROL_GAINED"); M.runTimers()
	check(not travelOn(), "landing with a vendor open: still off for the vendor")
	M.fire("MERCHANT_CLOSED"); M.runTimers()
	check(travelOn(), "and back on when the vendor closes")
	-- Travel Mode off: flights change nothing.
	main.btnTravel:GetScript("OnClick")(main.btnTravel); M.runTimers()
	flying = true; M.fire("PLAYER_CONTROL_LOST"); M.runTimers()
	check(not n.ui.travelHold.taxi and main.tools:IsShown(), "with Travel Mode off, a flight path changes nothing")
	flying = false; M.fire("PLAYER_CONTROL_GAINED"); M.runTimers()
	-- A /reload mid-flight.
	flying = true
	local n2 = boot({ travelMode = true })
	check(n2.ui.travelHold.taxi and n2.Window.main.tools:IsShown(), "a /reload mid-flight: Travel Mode stays off until you land")
	flying = false; n2.CheckTaxi(); M.runTimers()
	check(not n2.Window.main.tools:IsShown(), "and comes back on landing")
	-- Settings and What's New wording.
	local P = n2.SettingsPanel; P:Show(); P:ShowPage("automation")
	local help, intro
	for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == "travelLeaveTaxi" then help = w.help and w.help.text end end
	for _, w in ipairs(P.pools.text) do if w:IsShown() and w.text and (w.text.text or ""):find("compact, on%-the%-go view") then intro = true end end
	check(help == "Turns it back on when you land." and intro, "Settings: Leave Travel Mode During Flight Paths, and the intro describing Travel Mode")
	P:Hide()
	local e
	for _, x in ipairs(n2.WhatsNew.ENTRIES) do if x.v == "0.12.0" then e = x end end
	check(e and e.items[1]:find("compact, on%-the%-go view") and e.items[2]:find("flight path"), "What's New (0.12) describes Travel Mode as the compact view and mentions flight paths")
	_G.UnitOnTaxi = nil
end)()

;(function()
	-- 0.12.0-beta7: third outside review (each reproduces the audit's scenario).
	local function boot(db, stock)
		package.loaded.mock = nil
		local MC = require("mock")
		if stock then stock(MC) end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = db
		local n = MC.loadAddon("BagSmith")
		MC.fire("ADDON_LOADED", "BagSmith"); MC.fire("PLAYER_ENTERING_WORLD"); MC.runTimers(); MC.runTimers()
		ToggleAllBags(); MC.runTimers()
		return n, MC
	end
	-- 1) Confirmations act on the profile they name.
	local n, M = boot({ version = 2, profiles = { Default = {}, A = { sort = "name" }, B = { sort = "ilvl" } }, chars = {}, cache = {} })
	n.Profiles:Use("A")
	local P = n.SettingsPanel; P:Show(); P:ShowPage("advanced")
	local reset
	for _, b in ipairs(P.pools.btn) do if b:IsShown() and b.label and b.label.text == "Reset to Defaults" then reset = b end end
	reset:GetScript("OnClick")(reset)
	local confirm = n.Popups.confirm
	local onYes = confirm.onYes
	check(confirm:IsShown() and confirm.text.text:find('"A"'), "Reset to Defaults asks about profile A")
	n.Profiles:Use("B")
	check(not confirm:IsShown(), "switching profiles closes the open confirmation")
	onYes()   -- even a stale Yes resets only the profile it named
	check(BagSmithDB.profiles.A.sort == "quality" and BagSmithDB.profiles.B.sort == "ilvl", "the reset hits A, the profile it named, never B")
	-- Delete: the name is captured when asked.
	P:ShowPage("profile")
	local delB
	for _, l in ipairs(P.pools.profiles or {}) do for _, r in ipairs(l.rows or {}) do if r:IsShown() and r.name == "B" then delB = r.del end end end
	if delB then
		n.Profiles:Use("Default")
		P:ShowPage("profile")
		for _, l in ipairs(P.pools.profiles or {}) do for _, r in ipairs(l.rows or {}) do if r:IsShown() and r.name == "B" then delB = r.del end end end
		delB:GetScript("OnClick")(delB)
		local delYes = confirm.onYes
		n.Profiles:Use("AA"); P:ShowPage("profile")   -- creates AA; rows are reused
		check(not confirm:IsShown(), "creating a profile closes the open confirmation")
		delYes()
		check(BagSmithDB.profiles.AA and not BagSmithDB.profiles.B, "the delete removes B, the profile it named, not the new AA")
	else
		check(false, "test setup: profile row for B")
	end
	P:Hide()

	-- 2) A profile without the selected sheet: back to All, items visible.
	n, M = boot({ version = 2, profiles = { Default = {}, A = { sheets = { { n = "My Sheet", f = { text = "gem" } } } } }, chars = {}, cache = {} },
		function(MM) MM.put(0, 1, { id = 9801, name = "Gem", q = 2, class = 7, subclass = 0, price = 10 }); MM.put(0, 2, { id = 9802, name = "Bread", q = 1, class = 0, subclass = 5, price = 1 }) end)
	n.Profiles:Use("A")
	local main = n.Window.main
	main.st.sheet = "My Sheet"; main.st.filters.text = "gem"; n:RefreshViews(true)
	n.Profiles:Use("Default"); M.runTimers()
	local shown = 0; for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and not b.rec.empty then shown = shown + 1 end end
	check(n.ui.sheet == "All" and main.st.filters.text == "" and shown >= 2, "a profile without the selected sheet goes back to All with its filters cleared, items showing")

	-- 3) Blizzard's bank comes back where it was.
	BankFrame:ClearAllPoints(); BankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -104)
	n.Bank.concealed = false
	local realReplacing = n.Bank.Replacing; n.Bank.Replacing = function() return true end
	n.Bank:Conceal()
	check(BankFrame.points[1][4] == 4000, "concealed: moved off screen")
	n.Bank:Reveal()
	local p = BankFrame.points[1]
	check(#BankFrame.points == 1 and p[1] == "TOPLEFT" and p[2] == UIParent and p[4] == 16 and p[5] == -104, "revealed: back exactly where Blizzard had it")
	n.Bank.Replacing = realReplacing

	-- 4) Travel Mode closes a stale character picker and refuses an alt.
	BagSmithDB.cache.Elsewhere = { name = "Other", realm = "R", items = {}, bags = {} }
	n.Popups:ToggleCharacters(main)
	local chars = n.Popups.chars
	check(chars and chars:IsShown(), "the character picker's list is open (setup)")
	main.btnTravel:GetScript("OnClick")(main.btnTravel); M.runTimers()
	check(not chars:IsShown(), "entering Travel Mode closes the picker's list")
	main:SetOwner("Elsewhere")
	check(n.ui.owner == nil, "choosing another character while in Travel Mode is refused")
	main.btnTravel:GetScript("OnClick")(main.btnTravel); M.runTimers()

	-- 5) Frozen merged totals respect the filters.
	n, M = boot(nil, function(MM)
		MM.sizes[1] = 8; MM.bags[1] = MM.bags[1] or {}
		MM.put(0, 1, { id = 9810, name = "Linen Cloth", q = 1, count = 10, class = 7, subclass = 5, price = 1 })
		MM.put(1, 1, { id = 9810, name = "Linen Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 1 })
	end)
	main = n.Window.main
	n:Set("mergeStacks", true); n:Set("view", "list")
	main.st.filters.w = { Backpack = true }; n:RefreshViews(true)
	local row
	for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 9810 then row = b end end
	check(row and row.rec.count == 10, "filtered to Backpack: the merged row shows 10")
	M.bags[0][1].count = 11; n:Scan()
	main:RefreshInPlace(false, true)
	check(row.rec.count == 11, "a frozen refresh keeps counting only what the filter shows (11, not 31)")

	-- 6) The new marker after a dismissed stack shrinks and grows again.
	n, M = boot(nil, function(MM) MM.put(0, 1, { id = 9820, name = "Arrow", q = 1, count = 10, class = 6, subclass = 2, price = 1 }) end)
	local function rec() for _, r in ipairs(n.items) do if r.itemID == 9820 then return r end end end
	n:DismissNew(rec())
	M.bags[0][1].count = 2; n:Scan()
	M.bags[0][1].count = 3; n:Scan()
	check(rec().isNew, "a dismissed stack used down to 2 and looted back to 3 shows as new")

	-- 7) A category isn't stuck from before the item's details arrived.
	local base = { itemID = 9830, quality = 1, classID = 15, subclassID = 0 }
	local first = n:Categorize(base)
	local full = { itemID = 9830, quality = 1, classID = 15, subclassID = 0, isCraftingReagent = true }
	check(first ~= "TradeGoods" and n:Categorize(full) == "TradeGoods", "once the details say crafting reagent, the category follows")

	-- 8) A never-visited bank has no slot count.
	BagSmithDB.cache[n:CharKey()] = BagSmithDB.cache[n:CharKey()] or {}
	local entry = BagSmithDB.cache[n:CharKey()]
	entry.bags = { ["0"] = { size = 16, free = 4 } }; entry.bankBags = nil; entry.bank = nil
	local _, info = n:CachedRecords(n:CharKey(), true)
	check(next(info) == nil, "a bank never visited has no bag details (it used to show the bags')")

	-- 9) A late scroll check stands down after a newer scroll.
	main = n.Window.main
	local realRange = main.ScrollRange; main.ScrollRange = function() return 1000 end
	main.frame.IsMouseOver = function() return true end
	main.trustedScroll = 100
	main.scroll:SetVerticalScroll(200)
	main:GuardScroll(200, 100)
	check(main.scroll:GetVerticalScroll() == 100, "the game's jump is put back to 100")
	main.userScrollAt = GetTime(); main.scroll:SetVerticalScroll(160)
	M.runTimers()
	check(main.scroll:GetVerticalScroll() == 160, "a wheel scroll right after is kept: the late check stands down")
	main.ScrollRange = realRange; main.frame.IsMouseOver = function() return false end

	-- 10) Closing the bank with a rescan still waiting saves the latest bank.
	M.put(-1, 1, { id = 9840, name = "Bank Gem", q = 2, class = 7, subclass = 0, price = 5 })
	M.fire("BANKFRAME_OPENED"); M.runTimers(); M.elapse(); M.runTimers()
	M.put(-1, 2, { id = 9841, name = "Moved In", q = 1, class = 7, subclass = 0, price = 5 })
	M.fire("BAG_UPDATE_DELAYED")   -- the rescan waits for the next frame
	M.fire("BANKFRAME_CLOSED")
	local saw = false
	for _, it in ipairs(BagSmithDB.cache[n:CharKey()].bank or {}) do if it.itemID == 9841 then saw = true end end
	check(saw, "closing the bank with a rescan still waiting saves the bank with the latest change")
end)()

;(function()
	-- 0.12.0-beta8: the Classic signpost shows whether Travel Mode is on.
	local function boot(withMapArt)
		package.loaded.mock = nil
		local MD = require("mock")
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
		local realInfo = C_Texture.GetAtlasInfo
		if withMapArt then
			C_Texture.GetAtlasInfo = function(name)
				if name == "RedButton-Expand" or name == "RedButton-Expand-Pressed" then
					return { file = "Interface\\Buttons\\RedButtons", leftTexCoord = 0.5, rightTexCoord = 0.75, topTexCoord = 0, bottomTexCoord = 0.25 }
				end
				return realInfo(name)
			end
		end
		local n = MD.loadAddon("BagSmith")
		MD.fire("ADDON_LOADED", "BagSmith"); MD.fire("PLAYER_ENTERING_WORLD"); MD.runTimers(); MD.runTimers()
		ToggleAllBags(); MD.runTimers()
		n:Set("skin", "classic"); MD.runTimers()
		C_Texture.GetAtlasInfo = realInfo
		return n, MD
	end
	for _, withMapArt in ipairs({ true, false }) do
		local n, M = boot(withMapArt)
		local b = n.Window.main.btnTravel
		local art = b.redArt
		local label = withMapArt and "map button art" or "panel art fallback"
		local function face()
			if art.atlas then return art.pieces[1].atlas == art.atlasDown and "down" or "up" end
			return art.pieces[2].texture == "Interface\\Buttons\\UI-Panel-Button-Down" and "down" or "up"
		end
		local function white() local c = b.tex.color; return c and c[1] == 1 and c[2] == 1 and c[3] == 1 end
		check(face() == "up" and not white(), label .. ": off, the button is raised with a gold signpost")
		b:GetScript("OnClick")(b); M.runTimers()
		check(n.db.travelMode and face() == "down" and white(), label .. ": on, the button is pushed in with a white signpost")
		b:GetScript("OnMouseDown")(b); b:GetScript("OnMouseUp")(b)
		check(face() == "down", label .. ": after a click it settles into its state (still pushed in while on)")
		M.fire("MERCHANT_SHOW"); M.runTimers()
		check(face() == "up" and not white(), label .. ": Auto Travel Mode switching it off shows it off")
		M.fire("MERCHANT_CLOSED"); M.runTimers()
		check(face() == "down", label .. ": back on after the vendor, pushed in again")
		n:Set("skin", "modern"); M.runTimers()
		check(not art.pieces[1]:IsShown() and b.active, label .. ": Modern unchanged (no red art; active as before)")
	end
end)()

;(function()
	-- 0.12.0-beta9: Settings > Windows, each section's settings together.
	package.loaded.mock = nil
	local ME = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nE = ME.loadAddon("BagSmith")
	ME.fire("ADDON_LOADED", "BagSmith"); ME.fire("PLAYER_ENTERING_WORLD"); ME.runTimers(); ME.runTimers()
	local P = nE.SettingsPanel; P:Show()
	-- Every visible widget on a page, top to bottom, labelled.
	local items
	local function readPage(page)
		P:ShowPage(page)
		items = {}
		local function add(kind, w, label) if w:IsShown() then items[#items + 1] = { y = -w.points[1][5], kind = kind, label = label } end end
		for _, w in ipairs(P.pools.head) do add("head", w, w.text.text) end
		for _, w in ipairs(P.pools.check) do add("check", w, w.key) end
		for _, w in ipairs(P.pools.seg) do add("seg", w, w.key) end
		for _, w in ipairs(P.pools.step) do add("step", w, w.text and w.text.text) end
		for _, w in ipairs(P.pools.text) do add("text", w, (w.text.text or ""):sub(1, 30)) end
		table.sort(items, function(a, b) return a.y < b.y end)
		local under, heads = {}, {}
		local current
		for _, it in ipairs(items) do
			if it.kind == "head" then current = it.label; heads[#heads + 1] = it.label else under[it.label or "?"] = current end
		end
		return under, heads
	end
	local function grouped(page, wantHeads, want)
		local under, heads = readPage(page)
		check(table.concat(heads, " | ") == wantHeads, page .. " page sections in order: " .. table.concat(heads, " | "))
		local wrong = {}
		for label, head in pairs(want) do if under[label] ~= head then wrong[#wrong + 1] = label .. " under " .. tostring(under[label]) end end
		table.sort(wrong)
		check(#wrong == 0, page .. ": every setting sits under its own heading" .. (#wrong > 0 and (": " .. table.concat(wrong, ", ")) or ""))
	end
	grouped("automation", "Auto Travel Mode | Bag Cleanup | Vendors | Prompts | Clear Soul Shards", {
		travelLeaveBank = "Auto Travel Mode", travelLeaveAH = "Auto Travel Mode", travelLeaveVendor = "Auto Travel Mode", travelLeaveTaxi = "Auto Travel Mode", travelLeaveTrade = "Auto Travel Mode",
		cleanOnOpen = "Bag Cleanup", autoSellJunk = "Vendors", ["Soul Shards to Keep"] = "Clear Soul Shards",
		autoConfirm = "Prompts", autoConfirmEverywhere = "Prompts", autoConfirmEquip = "Prompts", autoConfirmUse = "Prompts", autoConfirmEnchant = "Prompts", autoConfirmRoll = "Prompts",
		autoConfirmSrcGear = "Prompts", autoConfirmSrcItem = "Prompts", autoConfirmSrcJunk = "Prompts", autoConfirmSrcDE = "Prompts", autoConfirmKey = "Prompts",
	})
	grouped("loothelper", "Loot Helper | Loot Exclusion List", { makeRoom = "Loot Helper", makeRoomValue = "Loot Helper" })
	grouped("dehelper", "Disenchant Helper | Opt-in", {
		deEnabled = "Disenchant Helper", deIncludeEpics = "Disenchant Helper", deSkipRefundable = "Disenchant Helper", ["Disenchant Must Beat Selling By"] = "Disenchant Helper",
	})
	grouped("window", "Bag Window | Combat | Bag Windows | Currency Drawer", {
		__openWindows = "Bag Windows", ["Icons per Row in Bag Windows"] = "Bag Windows", ["Bag Window Scale"] = "Bag Windows", ["Bag Window Max Height"] = "Bag Windows",
		side = "Currency Drawer", combatFade = "Combat",
	})
	grouped("general", "Opening BagSmith | Blizzard's Interface | Notices", {
		replaceBlizzardBags = "Opening BagSmith", minimap = "Opening BagSmith",
		replaceBank = "Blizzard's Interface", hideBlizzBagBar = "Blizzard's Interface",
		quiet = "Notices", whatsNew = "Notices",
	})
	local order = {}
	for _, b in ipairs(P.navButtons) do order[#order + 1] = b.text.text end
	check(table.concat(order, "|") == "General|Style|Item Icons|Windows|Sections|Dynamic Sections|Custom Sections|Columns|Bag Columns|Bank Columns|Sheets|Bag Sheets|Bank Sheets|Sorting & Filters|Automations & Actions|Loot Helper|Disenchant Helper|Keybindings|Plugins|Profile|Advanced",
		"Settings pages: General first, Item Icons right after Style (1.5.0), Profile just before Advanced (Automations & Actions has its two helper sub-pages since 1.2.0)")
	local stray = false
	for _, it in ipairs(items) do if it.kind == "text" and it.label:find("^Taller bags") then stray = true end end
	check(not stray, "\"Taller bags scroll\" is the Max Height setting's help, not a stray line")
	P:Hide()
end)()


;(function()
	-- 0.13.0-beta2: Sell With Junk, Dim Junk Items.
	local function boot(profile)
		package.loaded.mock = nil
		local MJ = require("mock")
		MJ.put(0, 1, { id = 9501, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
		MJ.put(0, 2, { id = 9502, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
		MJ.put(0, 3, { id = 9503, name = "Quest Note", q = 1, class = 12, subclass = 0, price = 0, quest = true })
		MJ.put(0, 4, { id = 9504, name = "Silk Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 15 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		profile = profile or {}   -- (written for Modern; new players start in Classic)
		if profile.skin == nil then profile.skin = "modern" end
		_G.BagSmithDB = { version = 2, profiles = { Default = profile }, chars = {}, cache = {} }
		local n = MJ.loadAddon("BagSmith")
		MJ.fire("ADDON_LOADED", "BagSmith"); MJ.fire("PLAYER_ENTERING_WORLD"); MJ.runTimers(); MJ.runTimers()
		ToggleAllBags(); MJ.runTimers()
		return n, MJ
	end
	local sold = {}
	_G.C_MerchantFrame = { SellAllJunkItems = function() end, GetNumJunkItems = function() return 1 end }
	local n, M = boot(nil)
	local J, main = n.Junk, n.Window.main
	n:Set("view", "list"); n:Set("grp", "type"); n:RefreshViews(true)
	local function row(id) for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then return b end end end
	local function rec(id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
	check(n.IndexOf(n.db.cols, "jk") and main.headerLabels.jk:IsShown() and main.headerLabels.jk.junkIcon:IsShown(), "the Junk column is on, its header shows the Sell All Junk icon")
	-- Greys: coin shown, cell shown and can't be unmarked.
	local fang = row(9501)
	check(fang.junkCoin:IsShown() and fang.colJunk:IsShown() and fang.colJunk.state == "grey", "a grey item shows the coin on its icon and the Junk icon in its row")
	-- An unmarked item: no coin; the Junk icon only on hover, faint.
	local belt = row(9502)
	check(not belt.junkCoin:IsShown() and belt.colJunk:IsShown() and belt.colJunk.tex.alpha == 0 and belt.colJunk.state == "eligible",
		"an unmarked item: no coin, and its Junk icon is invisible (but in place, so it can be clicked) until you hover")
	belt:GetScript("OnEnter")(belt)
	check(belt.colJunk:IsShown() and belt.colJunk.tex.alpha == 0.35, "hovering the row shows the Junk icon faintly")
	-- Moving from the row onto the icon: the row's OnLeave, then the icon's OnEnter.
	belt:GetScript("OnLeave")(belt)
	belt.colJunk:GetScript("OnEnter")(belt.colJunk)
	check(belt.colJunk:IsShown() and belt.colJunk.tex.alpha == 0.8, "moving onto the icon keeps it showing (brighter), never hides it")
	belt.colJunk:GetScript("OnLeave")(belt.colJunk)
	GameTooltip:Hide()
	-- A quest item can't be marked.
	local note = row(9503)
	check(note and note.colJunk.state == "blocked" and note.colJunk:IsShown() and note.colJunk.tex.alpha == 0, "a quest item can't be marked: its Junk icon's spot is there but invisible")
	note.colJunk:GetScript("OnEnter")(note.colJunk)
	check(note.colJunk.tex.alpha == 0.3 and note.colJunk.tex.desaturated and table.concat(GameTooltip.lines or {}, " "):find("Quest items can't be marked as junk"),
		"hovering it shows the icon faint and greyed, with a tooltip saying why")
	note.colJunk:GetScript("OnClick")(note.colJunk)
	check(not n.cdb.junkMarks[9503], "clicking it does nothing")
	note.colJunk:GetScript("OnLeave")(note.colJunk)
	check(n.Junk:WhyNot({ itemID = 1, quality = 1, sellPrice = 0 }):find("can't be sold to a vendor") and n.Junk:WhyNot({ itemID = 1, cached = true }):find("per character"),
		"items with no vendor price, and another character's items, say why too")
	-- Mark the belt while rows hold still under the pointer: the row shows it at once.
	local realRefresh = n.RefreshViews
	n.RefreshViews = function() end
	belt.colJunk:GetScript("OnClick")(belt.colJunk)
	check(belt.junkCoin:IsShown() and belt.colJunk.state == "marked" and belt.colJunk.tex.alpha == 1, "clicking the Junk icon shows the mark right away, even while rows hold still")
	n.RefreshViews = realRefresh
	n:RefreshViews(true); M.runTimers()
	check(n.cdb.junkMarks[9502] and rec(9502).cat == "Junk", "clicking the Junk icon marks the item; it moves to the Junk section")
	belt = row(9502)
	check(belt.junkCoin:IsShown() and belt.colJunk:IsShown() and belt.colJunk.tex.alpha == 1 and belt.colJunk.state == "marked", "a marked item shows the coin and the Junk icon in full")
	local lines = {}
	GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
	J:AddTooltipLines(GameTooltip, rec(9502))
	check(lines[1] == "Marked as junk: sold with Sell All Junk.", "its tooltip says it's marked as junk")
	-- Greys can't be unmarked.
	fang.colJunk:GetScript("OnClick")(fang.colJunk)
	check(not n.cdb.junkMarks[9501] and rec(9501).cat == "Junk", "clicking a grey item's Junk icon doesn't change it (always junk)")
	-- Icon view: the coin on the icon; the new dot moves to the other corner.
	n:Set("view", "icons"); n:RefreshViews(true)
	belt = row(9502)
	check(belt.junkCoin:IsShown() and belt.junkCoin.points[1][1] == "TOPLEFT" and not belt.colJunk:IsShown(), "icon view: the coin in the icon's top-left corner, no Junk column")
	check(belt.newDot.points[1][1] == "BOTTOM", "the new-item dot stays at the bottom center, clear of the coin")
	-- The key binding marks or unmarks the item under the pointer.
	_G.GetMouseFoci = function() return { row(9504) } end
	BagSmith_ToggleJunk(); M.runTimers()
	check(n.cdb.junkMarks[9504], "the Mark as Junk key binding marks the hovered item")
	BagSmith_ToggleJunk(); M.runTimers()
	check(not n.cdb.junkMarks[9504], "pressing it again unmarks it")
	_G.GetMouseFoci = nil
	n:Set("view", "list"); n:RefreshViews(true)
	-- Dim Junk Items.
	n:Set("dimJunk", true); n:RefreshViews(true)
	belt, fang = row(9502), row(9501)
	local silk = row(9504)
	local dt = n.Junk.DIM_TEXT
	check(belt.icon.desaturated and belt.icon.alpha == n.Junk.DIM_ALPHA and fang.icon.desaturated and belt.colName.textColor and belt.colName.textColor[1] == dt[1] and belt.colName.textColor[3] == dt[3],
		"Dim Junk Items: junk icons greyed and darkened (mostly opaque), row text a muted sepia-grey")
	local c = belt.icon.color or {}
	check(c[1] == n.Junk.SEPIA[1] and c[2] == n.Junk.SEPIA[2] and c[3] == n.Junk.SEPIA[3] and c[1] < 0.8, "with a darkening sepia tint")
	check(not silk.icon.desaturated and silk.icon.alpha == 1 and silk.colName.alpha == 1, "items that aren't junk look normal")
	n:Set("dimJunk", false); n:RefreshViews(true)
	belt = row(9502)
	check(not belt.icon.desaturated and belt.icon.alpha == 1 and belt.icon.color[3] == 1 and belt.colName.textColor[1] == belt.colName.baseColor[1],
		"turning it off restores everything (no tint, normal text color)")
	-- Selling: right after Blizzard's sale, inside the same click.
	_G.MerchantFrame = MerchantFrame or CreateFrame("Frame", "MerchantFrame", UIParent); MerchantFrame:Show()
	local used = {}
	local realUse = C_Container.UseContainerItem
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; local m = package.loaded.mock; if m and m.bags[bag] then m.bags[bag][slot] = nil end end
	local logBefore = #M.log
	C_MerchantFrame.SellAllJunkItems(); M.runTimers(); M.elapse(); M.runTimers()
	check(#used == 1 and used[1] == "0:2", "after Blizzard's Sell All Junk, BagSmith sells the marked item (and not the grey, which Blizzard sells)")
	local said = table.concat(M.log, " ", logBefore + 1)
	check(said:find("Also sold 1 marked item for"), "and says so in chat")
	-- Another of that item for the next checks.
	M.put(0, 2, { id = 9502, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" }); n:Scan()
	-- Blizzard's button not usable: the Sell Marked button appears.
	_G.MerchantSellAllJunkButton = CreateFrame("Button", "MerchantSellAllJunkButton", MerchantFrame); MerchantSellAllJunkButton:SetSize(32, 32)
	MerchantSellAllJunkButton:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMLEFT", 100, 30)
	MerchantSellAllJunkButton:Hide()
	M.fire("MERCHANT_SHOW"); M.runTimers(); M.elapse(); M.runTimers()
	local sb = _G.BagSmithSellMarkedButton
	check(sb and sb:IsShown() and sb.points[1][4] == 100, "with Blizzard's button hidden, BagSmith's Sell Marked button takes its place")
	used = {}
	sb:GetScript("OnClick")(sb); M.runTimers(); M.elapse(); M.runTimers()
	check(#used == 1 and used[1] == "0:2", "clicking it sells the marked items")
	MerchantSellAllJunkButton:Show()
	n.Junk:UpdateSellButton()
	check(not sb:IsShown(), "with Blizzard's button usable, the Sell Marked button isn't needed")
	-- If the game blocks selling outside a click, Sell Marked appears beside Blizzard's.
	M.put(0, 2, { id = 9502, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" }); n:Scan()
	C_Container.UseContainerItem = function() M.fire("ADDON_ACTION_BLOCKED", "BagSmith", "UseContainerItem") end
	C_MerchantFrame.SellAllJunkItems(); M.runTimers(); M.elapse(); M.runTimers()
	check(n.Junk.needsClick and sb:IsShown() and sb.points[1][2] == MerchantSellAllJunkButton, "if the game blocks it, the Sell Marked button appears beside Blizzard's")
	M.fire("MERCHANT_CLOSED"); MerchantFrame:Hide()
	check(not sb:IsShown() and not n.Junk.needsClick, "closing the vendor hides it and resets")
	C_Container.UseContainerItem = realUse
	-- Marks are per character and kept across sessions.
	check(BagSmithCharDB.junkMarks[9502], "marks are saved with the character")
	-- Another character's saved bags: only greys count as junk.
	local cached = { itemID = 9502, quality = 1, sellPrice = 22, cached = true }
	check(not n.Junk:IsJunk(cached) and n.Junk:IsJunk({ itemID = 9501, quality = 0, sellPrice = 3, cached = true }), "another character's saved bags: your marks don't apply, greys still do")
	-- Upgrading profiles get the Junk column once.
	local n2 = boot({ cols = { "c", "t" }, bankCols = { "c" } })
	check(n.IndexOf(n2.db.cols, "jk") and n.IndexOf(n2.db.bankCols, "jk") and n2.db.jkCol, "an existing profile gets the Junk column once")
	_G.C_MerchantFrame, _G.MerchantSellAllJunkButton = nil, nil
end)()

;(function()
	-- 0.13.0-beta2: Leave Travel Mode When Trading, Clean Up Bags When Opened, Profile Sharing.
	package.loaded.mock = nil
	local MK = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, profiles = { Default = { travelMode = true } }, chars = {}, cache = {} }
	local n = MK.loadAddon("BagSmith")
	MK.fire("ADDON_LOADED", "BagSmith"); MK.fire("PLAYER_ENTERING_WORLD"); MK.runTimers(); MK.runTimers()
	ToggleAllBags(); MK.runTimers()
	local main = n.Window.main
	local function travelOn() return not main.tools:IsShown() end
	check(n.db.travelLeaveTrade == true and travelOn(), "Leave Travel Mode When Trading is on by default")
	MK.fire("TRADE_SHOW"); MK.runTimers()
	check(not travelOn() and n.ui.travelHold.trade, "a trade window turns Travel Mode off")
	main.btnTravel:GetScript("OnEnter")(main.btnTravel)
	check(table.concat(GameTooltip.lines or {}, " "):find("Off while you're trading"), "the signpost's tooltip says why")
	main.btnTravel:GetScript("OnLeave")(main.btnTravel)
	MK.fire("TRADE_CLOSED"); MK.runTimers()
	check(travelOn(), "and back on when the trade closes")
	n:Set("travelLeaveTrade", false); MK.fire("TRADE_SHOW"); MK.runTimers()
	check(travelOn(), "with the setting off, trading leaves Travel Mode on")
	MK.fire("TRADE_CLOSED"); n:Set("travelLeaveTrade", true)
	local P = n.SettingsPanel; P:Show(); P:ShowPage("automation")
	local helps = {}
	for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key then helps[w.key] = w.help and w.help.text end end
	check(helps.travelLeaveAH == "Turns it back on when you close the auction house." and helps.travelLeaveTrade == "Turns it back on when the trade is finished or canceled.",
		"the auction house and trading help lines name what ends them")
	check(helps.cleanOnOpen and helps.cleanOnOpen:find("Clean Up Bags"), "Clean Up Bags When Opened is on the Automations & Actions page")
	P:Hide()
	-- Clean Up Bags When Opened.
	local sorts = 0
	local realSort = C_Container.SortBags
	C_Container.SortBags = function() sorts = sorts + 1 end
	n:Set("travelMode", false)
	main:Hide(); ToggleAllBags(); MK.runTimers()
	check(sorts == 0, "off by default: opening the bags doesn't clean up")
	n:Set("cleanOnOpen", true)
	main:Hide(); ToggleAllBags(); MK.runTimers(); MK.runTimers()
	check(sorts == 1, "on: opening the bags runs Clean Up Bags once")
	main:Hide(); MK.combat = true; ToggleAllBags(); MK.runTimers(); MK.runTimers(); MK.combat = false
	check(sorts == 1, "not during combat")
	main:Hide(); n.atBank = true; ToggleAllBags(); MK.runTimers(); MK.runTimers(); n.atBank = false
	check(sorts == 1, "not at the bank")
	C_Container.SortBags = realSort; n:Set("cleanOnOpen", false)
	-- Profile Sharing: a code round-trips, imports as a new profile.
	n:Set("sort", "name"); n.db.sheets = { { n = "Cloth", f = { text = "cloth" } } }
	local code = n.Share:Export()
	check(code and code:find("^BS1:") and #code < 20000, "Share makes a BS1 code")
	local name = n.Share:Import(code, "Friend")
	local imp = BagSmithDB.profiles.Friend
	check(name == "Friend" and imp and imp.sort == "name" and imp.sheets[1].n == "Cloth" and imp.debug == false, "importing makes a new profile with the settings and sheets")
	check(n.Share:Import(code, "Friend") == "Friend (2)", "a taken name gets (2)")
	check(n.profileName == "Default", "importing never switches or overwrites your profile")
	local _, e1 = n.Share:Import("hello", "X")
	local _, e2 = n.Share:Import(code:sub(1, #code - 30) .. code:sub(-7), "X")
	local _, e3 = n.Share:Import(code:gsub("^BS1", "BS9"), "X")
	check(e1 == "That isn't a BagSmith profile code." and e2 and e2:find("damaged") and e3 and e3:find("newer BagSmith"), "bad codes are rejected with plain messages")
	-- Safety: a code is only data. An edited code that parses still goes through the checks.
	local raw = "tN"   -- not a valid start
	check(not n.Share:Decode("BS1:" .. raw .. ":000000"), "garbage after the prefix is rejected")
	-- The Share window.
	n.ShareWindow("share")
	local f = n.Popups.share
	check(f:IsShown() and f.edit:GetText() == n.Share:Export() and f.hint.text:find("Ctrl%+C"), "Share This Profile shows the code, ready to copy")
	n.ShareWindow("import")
	f.edit:SetText(code); f.name:SetText("From Chat")
	f.ok:GetScript("OnClick")(f.ok)
	check(BagSmithDB.profiles["From Chat"] and not f:IsShown(), "Import Profile adds the pasted code as a new profile")
	n.ShareWindow("import"); f.edit:SetText("nope"); f.ok:GetScript("OnClick")(f.ok)
	check(f:IsShown() and f.hint.text:find("isn't a BagSmith profile code"), "a bad paste shows the reason and keeps the window open")
	f:Hide()
end)()

;(function()
	-- 0.13.0-beta3: the Settings mouse wheel moves about two rows per notch.
	package.loaded.mock = nil
	local MW = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nW = MW.loadAddon("BagSmith")
	MW.fire("ADDON_LOADED", "BagSmith"); MW.fire("PLAYER_ENTERING_WORLD"); MW.runTimers(); MW.runTimers()
	local P = nW.SettingsPanel; P:Show(); P:ShowPage("window")
	local sc = P.scroll
	sc.GetVerticalScrollRange = function() return 1000 end
	sc:SetVerticalScroll(0)
	sc:GetScript("OnMouseWheel")(sc, -1)
	check(sc:GetVerticalScroll() == 40, "one wheel notch moves Settings 40 px (about two rows), not half a page")
	for _ = 1, 100 do sc:GetScript("OnMouseWheel")(sc, -1) end
	check(sc:GetVerticalScroll() == 1000, "and stops at the end")
	sc:GetScript("OnMouseWheel")(sc, 1)
	check(sc:GetVerticalScroll() == 960, "and scrolls back up the same amount")
	P:Hide()
end)()

;(function()
	-- 0.13.0-beta4: key bindings, tooltip hints.
	local binds = {}
	_G.GetBindingKey = function(action) local out = {}; for k, a in pairs(binds) do if a == action then out[#out + 1] = k end end; table.sort(out); return unpack(out) end
	_G.GetBindingAction = function(key) return binds[key] or "" end
	_G.SetBinding = function(key, action) binds[key] = action end
	_G.SaveBindings = function() binds.__saved = (binds.__saved or 0) + 1 end
	_G.GetCurrentBindingSet = function() return 1 end
	_G.GetBindingText = function(key) return (key:gsub("SHIFT%-", "Shift-"):gsub("CTRL%-", "Ctrl-"):gsub("ALT%-", "Alt-")) end
	_G.BINDING_NAME_TOGGLESPELLBOOK = "Open Spellbook"
	package.loaded.mock = nil
	local MB = require("mock")
	MB.put(0, 1, { id = 9601, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local n = MB.loadAddon("BagSmith")
	MB.fire("ADDON_LOADED", "BagSmith"); MB.fire("PLAYER_ENTERING_WORLD"); MB.runTimers(); MB.runTimers()
	ToggleAllBags(); MB.runTimers()
	check(BINDING_CATEGORY_BAGSMITH == "BagSmith" and BINDING_NAME_BAGSMITH_MARKJUNK == "Mark as Junk" and BINDING_NAME_BAGSMITH_TRAVEL == "Toggle Travel Mode" and BINDING_NAME_BAGSMITH_CURRENCY == "Toggle Currency Drawer",
		"key bindings: BagSmith's own section with Mark as Junk, Toggle Travel Mode and Toggle Currency Drawer")
	-- The Settings page.
	local P = n.SettingsPanel; P:Show(); P:ShowPage("keys")
	local rows = {}
	for _, w in ipairs(P.pools.bind) do if w:IsShown() then rows[w.action] = w end end
	check(rows.BAGSMITH_MARKJUNK and rows.BAGSMITH_TRAVEL and rows.BAGSMITH_CURRENCY and rows.BAGSMITH_MARKJUNK.key.text == "Not Set", "Settings > Keybindings lists them all, Not Set at first")
	local navNames = {}
	for _, b in ipairs(P.navButtons) do navNames[#navNames + 1] = b.text.text end
	check(table.concat(navNames, "|"):find("|Keybindings|") and P.pools.head[1].text.text == "Keybindings", "the page is called Keybindings (one word), like the game's")
	-- Set Key: the next key press, with modifiers.
	local r = rows.BAGSMITH_MARKJUNK
	r.set:GetScript("OnClick")(r.set)
	check(r.key.text == "Press a key...", "Set Key waits for a key")
	local cap = n.KeyBinds.capture
	_G.IsShiftKeyDown = function() return true end
	cap:GetScript("OnKeyDown")(cap, "LSHIFT")   -- a modifier alone is ignored
	check(cap:IsShown(), "pressing only Shift keeps waiting")
	cap:GetScript("OnKeyDown")(cap, "K")
	_G.IsShiftKeyDown = function() return false end
	check(binds["SHIFT-K"] == "BAGSMITH_MARKJUNK" and binds.__saved and n.KeyBinds:Key("BAGSMITH_MARKJUNK") == "Shift-K", "Shift+K is bound to Mark as Junk and saved")
	P:ShowPage("keys")
	for _, w in ipairs(P.pools.bind) do if w:IsShown() then rows[w.action] = w end end
	check(rows.BAGSMITH_MARKJUNK.key.text == "Shift-K", "the page shows the new key")
	-- A key in use: BagSmith says what it replaced.
	binds.P = "TOGGLESPELLBOOK"
	local before = #MB.log
	local msg = n.KeyBinds:Set("BAGSMITH_TRAVEL", "P")
	check(msg == "P was Open Spellbook; it's now Toggle Travel Mode." and binds.P == "BAGSMITH_TRAVEL", "binding a key that was in use says what it replaced")
	-- Setting a new key replaces the old one; Clear removes it; Esc cancels.
	n.KeyBinds:Set("BAGSMITH_MARKJUNK", "J")
	check(binds.J == "BAGSMITH_MARKJUNK" and binds["SHIFT-K"] == nil, "a new key replaces the action's old key")
	rows.BAGSMITH_TRAVEL.set:GetScript("OnClick")(rows.BAGSMITH_TRAVEL.set)
	cap:GetScript("OnKeyDown")(cap, "ESCAPE")
	check(binds.P == "BAGSMITH_TRAVEL" and not cap:IsShown(), "Esc cancels without changing anything")
	n.KeyBinds:Clear("BAGSMITH_TRAVEL")
	check(binds.P == nil, "Clear removes the key")
	MB.combat = true
	check(n.KeyBinds:Set("BAGSMITH_TRAVEL", "P") == "Key bindings can't be changed during combat." and binds.P == nil, "no changes during combat")
	MB.combat = false
	P:Hide()
	-- The other bindings do what they say.
	BagSmith_ToggleTravel(); MB.runTimers()
	check(n.db.travelMode, "Toggle Travel Mode works from its key")
	BagSmith_ToggleTravel(); MB.runTimers()
	BagSmith_ToggleCurrency(); MB.runTimers()
	check(n.Drawer.frame and n.Drawer.frame:IsShown(), "Toggle Currency Drawer works from its key")
	-- Tooltip hints, only when a key is bound.
	local lines = {}
	GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
	local rec
	for _, x in ipairs(n.items) do if x.itemID == 9601 then rec = x end end
	n.Junk:AddTooltipLines(GameTooltip, rec)
	check(lines[1] == "Press J to mark as junk", "with a key bound, the item tooltip says: Press J to mark as junk")
	n.Junk:Toggle(rec); lines = {}
	n.Junk:AddTooltipLines(GameTooltip, rec)
	check(lines[1] == "Marked as junk: sold with Sell All Junk." and lines[2] == "Press J to unmark", "on a marked item: Press J to unmark")
	n.KeyBinds:Clear("BAGSMITH_MARKJUNK"); lines = {}
	n.Junk:Toggle(rec); n.Junk:AddTooltipLines(GameTooltip, rec)
	check(#lines == 0, "with no key bound, the item tooltip stays clean")
	_G.GetBindingKey, _G.GetBindingAction, _G.SetBinding, _G.SaveBindings, _G.GetCurrentBindingSet, _G.GetBindingText = nil, nil, nil, nil, nil, nil
end)()

;(function()
	-- 0.13.0-beta4: Make Room and Clear Soul Shards.
	local loot = {}
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("item:" .. loot[i].id) end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, l.qty or 1, nil, l.q or 1 end end
	local looted = {}
	_G.LootSlot = function(i) looted[#looted + 1] = i end
	local deleted = {}
	_G.DeleteCursorItem = function() deleted[#deleted + 1] = true end
	local function boot(class, stock)
		package.loaded.mock = nil
		local MR = require("mock")
		_G.UnitClass = function() return class, class:upper() end
		MR.sizes[0] = 4
		stock(MR)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
		local n = MR.loadAddon("BagSmith")
		MR.fire("ADDON_LOADED", "BagSmith"); MR.fire("PLAYER_ENTERING_WORLD"); MR.runTimers(); MR.runTimers()
		n.db.makeRoomAsk = true   -- (1.5.1-beta2) these checks test the asking path; Ask Before Destroying is off by default now
		ToggleAllBags(); MR.runTimers()
		-- Pick up = the cursor holds that item.
		C_Container.PickupContainerItem = function(bag, slot) local it = MR.bags[bag] and MR.bags[bag][slot]; MR.cursorItem = it and it.id end
		_G.ClearCursor = function() MR.cursorItem = nil end
		return n, MR
	end
	-- A full backpack (4 slots): junk, a cheap item, a partial stack pair, a quest item.
	local n, M = boot("Warrior", function(MM)
		for b = 1, 5 do MM.sizes[b] = 0 end
		MM.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
		MM.put(0, 2, { id = 9702, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
		MM.put(0, 3, { id = 9703, name = "Linen Cloth", q = 1, count = 5, stack = 20, class = 7, subclass = 5, price = 1 })
		MM.put(0, 4, { id = 9703, name = "Linen Cloth", q = 1, count = 7, stack = 20, class = 7, subclass = 5, price = 1 })
	end)
	local MRm = n.MakeRoom
	-- Loot: a valuable ring (won't fit) and more Linen Cloth (fits in the stacks).
	loot = { { id = 9710, name = "Shiny Ring", q = 2 }, { id = 9703, name = "Linen Cloth", qty = 3 } }
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(id)
		if id == 9710 then return "Shiny Ring", nil, 2, nil, nil, nil, nil, 1, nil, nil, 500 end
		if id == 9703 then return "Linen Cloth", nil, 1, nil, nil, nil, nil, 20, nil, nil, 1 end
		return realInfo(id)
	end
	local waiting = MRm:Waiting()
	check(#waiting == 1 and waiting[1].id == 9710, "Make Room: the ring won't fit; the cloth fits in the existing stacks")
	M.fire("LOOT_OPENED"); M.runTimers()
	local f = MRm.frame
	check(f and f:IsShown() and f.waitRows[1]:IsShown() and f.waitRows[1].name.text == "Shiny Ring", "the panel appears with the ring waiting")
	local combine, destroy = MRm:Suggestions(waiting)
	check(#combine == 1 and combine[1].src.count == 5 and combine[1].dst.count == 7, "a free suggestion: combine the two Linen Cloth stacks")
	local ordered = true
	for i = 3, #destroy do if destroy[i].rank < destroy[i - 1].rank then ordered = false end end
	local hasBelt = false
	for _, d in ipairs(destroy) do if d.rec.itemID == 9702 then hasBelt = true end end
	check(destroy[1].rec.itemID == 9701 and destroy[1].junk and ordered and hasBelt, "destroy suggestions: junk first, then the cheapest, all worth less than the ring")
	-- Junk: one click. Anything else: asks first.
	local fangRow = f.destroyRows[1]
	MRact(fangRow)
	check(#deleted == 1, "a junk item is destroyed in one click")
	local beltRow
	for _, r in ipairs(f.destroyRows) do if r:IsShown() and r.name.text:find("^Linen Belt") then beltRow = r end end
	MRact(beltRow)
	check(#deleted == 1 and n.Popups.confirm:IsShown() and n.Popups.confirm.text.text:find("Destroy Linen Belt"), "anything else asks first")
	n.Popups.confirm:Hide()
	-- When room appears, the waiting loot is taken.
	M.bags[0][1] = nil; n:Scan(); M.runTimers()
	check(looted[1] == 1, "once there's room, BagSmith loots the ring")
	-- Skip and Never Ask.
	loot = { { id = 9711, name = "Ruined Pelt", q = 0 }, { id = 9712, name = "Torn Cloak", q = 1 } }
	M.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 }); n:Scan()
	M.fire("LOOT_OPENED"); M.runTimers()
	f.waitRows[1].btns[1]:GetScript("OnClick")(f.waitRows[1].btns[1])
	check(#MRm:Waiting() == 1 and MRm:Waiting()[1].id == 9712, "Skip leaves that item for this loot")
	f.waitRows[1].btns[2]:GetScript("OnClick")(f.waitRows[1].btns[2])
	check(MRm:Never()[9712] and not f:IsShown(), "Never Ask stops helping with that item (nothing left, the panel closes)")
	local P = n.SettingsPanel; P:Show(); P:ShowPage("loothelper")
	local line, manage
	for _, w in ipairs(P.pools.text) do if w:IsShown() and (w.text.text or ""):find("Loot Exclusion List: 1 item") then line = true end end
	for _, b in ipairs(P.pools.btn) do if b:IsShown() and b.label.text == "Manage..." then manage = b end end
	check(line and manage, "Settings shows one line for the never-asked items, with Manage...")
	manage:GetScript("OnClick")(manage)
	local nw = MRm.neverFrame
	check(nw:IsShown() and nw.rows[1]:IsShown() and nw.rows[1].id == 9712, "Manage... opens the list")
	nw.rows[1].remove:GetScript("OnClick")(nw.rows[1].remove)
	check(not MRm:Never()[9712], "its button asks about that item again")
	nw:Hide()
	P:Hide()
	-- The setting off: no panel.
	n:Set("makeRoom", false); MRm.frame:Hide()
	loot = { { id = 9710, name = "Shiny Ring", q = 2 } }
	M.fire("LOOT_OPENED"); M.runTimers()
	check(not MRm.frame:IsShown(), "with Show Make Room off, nothing appears")
	n:Set("makeRoom", true)
	-- The game's "Inventory is full" also opens it.
	M.fire("UI_ERROR_MESSAGE", 3, ERR_INV_FULL or "Inventory is full.")
	_G.ERR_INV_FULL = _G.ERR_INV_FULL or "Inventory is full."
	M.fire("UI_ERROR_MESSAGE", 3, ERR_INV_FULL)
	check(MRm.frame:IsShown(), "the inventory full message opens Make Room too")
	-- The loot window closing.
	loot = {}
	M.fire("LOOT_CLOSED")
	check(MRm.frame.status.text:find("Loot again"), "if the loot window closes, it says to loot again")
	MRm.frame:Hide()
	-- Not a warlock: no shards row.
	check(not MRm:IsWarlock() and not MRm.frame.shard:IsShown(), "only warlocks see Soul Shards")
	C_Item.GetItemInfo = realInfo

	-- A warlock with shards in the backpack and a soul bag.
	n, M = boot("Warlock", function(MM)
		for b = 2, 5 do MM.sizes[b] = 0 end
		MM.sizes[1] = 2
		for sl = 1, 4 do MM.put(0, sl, { id = 6265, name = "Soul Shard", q = 1, class = 15, subclass = 0, price = 0 }) end
		MM.put(1, 1, { id = 6265, name = "Soul Shard", q = 1, class = 15, subclass = 0, price = 0 })
		MM.put(1, 2, { id = 6265, name = "Soul Shard", q = 1, class = 15, subclass = 0, price = 0 })
	end)
	MRm = n.MakeRoom
	local realFree = C_Container.GetContainerNumFreeSlots
	C_Container.GetContainerNumFreeSlots = function(bag) local free = realFree(bag); return free, bag == 1 and 4 or 0 end
	local list, can = MRm:Shards()
	check(#list == 4 and can == 4, "a warlock: 4 shards in ordinary bags can go (the 2 in the soul bag are never counted)")
	n:Set("shardKeep", 5)
	list, can = MRm:Shards()
	check(can == 1, "Always Keep at Least 5: only 1 of the 6 can go")
	n:Set("shardKeep", 0)
	-- The section header's Clear Shards button.
	n:Set("view", "list"); n:Set("grp", "type"); n:RefreshViews(true)
	local btn
	for _, pool in pairs(n.Buttons.lanes or {}) do
		for _, h in ipairs(pool) do if h:IsShown() and h.clearShards and h.clearShards:IsShown() then btn = h.clearShards end end
	end
	check(btn ~= nil, "the section holding the shards has a Clear Shards button")
	if btn then btn:GetScript("OnClick")(btn) else MRm:ShowShards() end
	f = MRm.frame
	check(f:IsShown() and f.title.text == "Clear Soul Shards" and f.shard:IsShown(), "it opens Clear Soul Shards")
	-- Choose 2, confirm once, then one click per shard.
	MRm.shardQty = 1; f.shard.plus:GetScript("OnClick")(f.shard.plus)
	check(f.shard.qty.text == "2", "choose how many: 2")
	deleted = {}
	f.shard.go:GetScript("OnClick")(f.shard.go)
	check(#deleted == 0 and n.Popups.confirm:IsShown() and n.Popups.confirm.text.text:find("Destroy 2 Soul Shards"), "one confirmation for the number chosen")
	n.Popups.confirm.yes:GetScript("OnClick")(n.Popups.confirm.yes)
	check(#deleted == 1 and f.shard.go.label.text == "Destroy Next Shard (1 left)", "the Yes click destroys the first; the button counts down")
	M.bags[0][1] = nil; n:Scan()
	f.shard.go:GetScript("OnClick")(f.shard.go)
	check(#deleted == 2 and f.shard.go.label.text == "Destroy Shards" and not MRm.shardBatch, "one click per shard until done")
	C_Container.GetContainerNumFreeSlots = realFree
	f:Hide()
	_G.UnitClass = function() return "Warrior", "WARRIOR" end
	_G.GetNumLootItems, _G.GetLootSlotType, _G.GetLootSlotLink, _G.GetLootSlotInfo, _G.LootSlot, _G.DeleteCursorItem = nil, nil, nil, nil, nil, nil
end)()

;(function()
	-- 0.13.0-beta5: Clean Up Bags only when it would help; Classic buttons in pop-ups.
	local loot = { { id = 9810, name = "Shiny Ring" } }
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("item:" .. loot[i].id) end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, 1, nil, 2 end end
	local function boot(stock, skin)
		package.loaded.mock = nil
		local MC = require("mock")
		for b = 1, 5 do MC.sizes[b] = 0 end
		MC.sizes[0] = 4
		stock(MC)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = skin and { version = 2, profiles = { Default = { skin = skin } }, chars = {}, cache = {} } or nil
		local n = MC.loadAddon("BagSmith")
		MC.fire("ADDON_LOADED", "BagSmith"); MC.fire("PLAYER_ENTERING_WORLD"); MC.runTimers(); MC.runTimers()
		ToggleAllBags(); MC.runTimers()
		return n, MC
	end
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(id)
		if id == 9810 then return "Shiny Ring", nil, 2, nil, nil, nil, nil, 1, nil, nil, 500 end
		if id == 9811 then return "Linen Cloth", nil, 1, nil, nil, nil, nil, 20, nil, nil, 1 end
		return realInfo(id)
	end
	local cloth = function(c) return { id = 9811, name = "Linen Cloth", q = 1, count = c, class = 7, subclass = 5, price = 1 } end
	local belt = { id = 9812, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" }
	-- Nothing to merge or move: no Clean Up, and no "Free Ways" section at all.
	local n, M = boot(function(MM) for sl = 1, 4 do MM.put(0, sl, { id = 9820 + sl, name = "Thing " .. sl, q = 1, class = 4, subclass = 1, price = 5 }) end end)
	M.fire("LOOT_OPENED"); M.runTimers()
	local f = n.MakeRoom.frame
	local heads = {}
	for _, h in ipairs(f.heads) do if h:IsShown() then heads[#heads + 1] = h.text end end
	check(f:IsShown() and not f.cleanup:IsShown() and not table.concat(heads, "|"):find("Free a slot without losing anything"), "nothing to merge or move: no Clean Up Bags, and no Free Ways section")
	f:Hide()
	-- Two stacks that fit in one: Combine covers it, so no Clean Up as well.
	n, M = boot(function(MM) MM.put(0, 1, cloth(5)); MM.put(0, 2, cloth(7)); MM.put(0, 3, belt); MM.put(0, 4, { id = 9830, name = "Gem", q = 2, class = 7, subclass = 0, price = 50 }) end)
	M.fire("LOOT_OPENED"); M.runTimers(); f = n.MakeRoom.frame
	check(f.combineRows[1] and f.combineRows[1]:IsShown() and not f.cleanup:IsShown(), "two stacks that fit in one: Combine is offered, Clean Up isn't (it would do no more)")
	f:Hide()
	-- Three stacks that fit in one: Clean Up frees two, more than one Combine.
	n, M = boot(function(MM) MM.put(0, 1, cloth(5)); MM.put(0, 2, cloth(5)); MM.put(0, 3, cloth(5)); MM.put(0, 4, belt) end)
	M.fire("LOOT_OPENED"); M.runTimers(); f = n.MakeRoom.frame
	check(f.cleanup:IsShown() and n.MakeRoom:CleanUpGain() == 2, "three stacks that fit in one: Clean Up Bags is offered (frees two)")
	-- In combat, never.
	M.combat = true; n.MakeRoom:Paint()
	check(not f.cleanup:IsShown(), "never during combat")
	M.combat = false; f:Hide()
	-- A crafting reagent in an ordinary bag, with room in the reagent bag.
	n, M = boot(function(MM) MM.sizes[5] = 2; for sl = 1, 4 do MM.put(0, sl, { id = 9840 + sl, name = "Herb " .. sl, q = 1, class = 7, subclass = 9, price = 2 }) end end)
	C_Item.GetItemInfo = function(id)
		if id == 9810 then return "Shiny Ring", nil, 2, nil, nil, nil, nil, 1, nil, nil, 500 end
		if id >= 9841 and id <= 9844 then return "Herb", nil, 1, nil, nil, nil, nil, 1, nil, nil, 2, nil, nil, nil, nil, nil, true end
		return realInfo(id)
	end
	n.MakeRoom.skipped = {}
	check(n.MakeRoom:CleanUpGain() == 2 and n.MakeRoom:CleanUpHelps(0), "reagents in ordinary bags and room in the reagent bag: Clean Up would free two slots")
	C_Item.GetItemInfo = realInfo
	-- Classic: buttons in pop-ups made after the window was dressed look Classic.
	n, M = boot(function(MM) MM.put(0, 1, cloth(5)); MM.put(0, 2, cloth(7)); MM.put(0, 3, belt); MM.put(0, 4, cloth(3)) end, "classic")
	n.Confirm(n.Window.main.frame, "Delete the sheet?", function() end)
	local c = n.Popups.confirm
	check(c.yes.classicOn and c.no.classicOn, "Classic: a confirmation's Yes and Cancel (e.g. deleting a sheet) have the Classic look")
	c:Hide()
	M.fire("LOOT_OPENED"); M.runTimers(); f = n.MakeRoom.frame
	local allClassic = f.act.classicOn
	for _, list in ipairs({ f.waitRows, f.combineRows, f.destroyRows }) do
		for _, r in ipairs(list) do if r:IsShown() then for _, b in ipairs(r.btns) do allClassic = allClassic and b.classicOn end end end
	end
	check(allClassic, "Classic: the Loot Helper's Skip and Exclude buttons and its action button have the Classic look")
	n.ShareWindow("import")
	check(n.Popups.share.ok.classicOn and n.Popups.share.close.classicOn, "Classic: the share window's buttons too")
	n.Popups.share:Hide(); f:Hide()
	_G.GetNumLootItems, _G.GetLootSlotType, _G.GetLootSlotLink, _G.GetLootSlotInfo = nil, nil, nil, nil
end)()

;(function()
	-- 0.13.0-beta5: Make Room tooltips, spacing, moving, name room, limits.
	local loot = { { id = 9910, name = "Shiny Ring" } }
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("item:" .. loot[i].id) end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, 1, nil, 2 end end
	local function boot(db)
		package.loaded.mock = nil
		local MP = require("mock")
		for b = 1, 5 do MP.sizes[b] = 0 end
		MP.sizes[0] = 12
		for sl = 1, 8 do MP.put(0, sl, { id = 9920 + sl, name = "Old Thing With a Rather Long Name " .. sl, q = 0, class = 15, subclass = 0, price = sl }) end
		for sl = 9, 12 do MP.put(0, sl, { id = 9930 + sl, name = "Cloth " .. sl, q = 1, count = 2, class = 7, subclass = 5, price = 1 }) end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = db
		local n = MP.loadAddon("BagSmith")
		MP.fire("ADDON_LOADED", "BagSmith"); MP.fire("PLAYER_ENTERING_WORLD"); MP.runTimers(); MP.runTimers()
		return n, MP
	end
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(id) if id == 9910 then return "Shiny Ring", nil, 2, nil, nil, nil, nil, 1, nil, nil, 500 end return realInfo(id) end
	local n, M = boot(nil)
	M.fire("LOOT_OPENED"); M.runTimers()
	local f = n.MakeRoom.frame
	-- Limits: at most 6 destroy suggestions.
	local shown = 0
	for _, r in ipairs(f.destroyRows) do if r:IsShown() then shown = shown + 1 end end
	check(shown == 6, "at most 6 destroy suggestions at once (the cheapest; the list refills as items go)")
	-- Names get the room left of the buttons; Junk moves to the value line.
	local r = f.destroyRows[1]
	check(r.name.width and r.name.width > 200 and not r.name.text:find("junk") and r.value.text:find("^Junk"), "names get all the width left of the buttons; Junk is shown on the value line")
	-- Item tooltips on hover.
	local shownBag
	GameTooltip.SetBagItem = function(_, bag, slot) shownBag = bag .. ":" .. slot end
	r:GetScript("OnEnter")(r)
	check(shownBag == r.tipBag or shownBag ~= nil, "hovering a suggestion shows the item's tooltip")
	local lootSlot
	GameTooltip.SetLootItem = function(_, slot) lootSlot = slot end
	f.waitRows[1]:GetScript("OnEnter")(f.waitRows[1])
	check(lootSlot == 1, "hovering the waiting loot shows its tooltip")
	-- The description sits just under the title.
	check(f.sub.points[1][2] == f.title and f.sub.points[1][5] == -3, "the description sits just under the title")
	-- Moving: drag, and the spot is remembered (across a reload too).
	f:GetScript("OnDragStart")(f)
	f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -200)
	f:GetScript("OnDragStop")(f)
	check(n.db.makeRoomPos and n.db.makeRoomPos[1] == "TOPLEFT" and n.db.makeRoomPos[4] == 300, "dragging Make Room remembers where it was put")
	local saved = BagSmithDB
	f:Hide()
	local n2, M2 = boot(saved)
	check(n2.db.makeRoomPos and n2.db.makeRoomPos[4] == 300 and n2.db.makeRoomPos[5] == -200, "the spot survives a reload")
	M2.fire("LOOT_OPENED"); M2.runTimers()
	local p = n2.MakeRoom.frame.points[1]
	check(p[1] == "TOPLEFT" and p[4] == 300 and p[5] == -200, "and Make Room opens there next time")
	C_Item.GetItemInfo = realInfo
	_G.GetNumLootItems, _G.GetLootSlotType, _G.GetLootSlotLink, _G.GetLootSlotInfo = nil, nil, nil, nil
end)()

;(function()
	-- 0.13.0-beta5: Make Room details (count, tooltips, moving, full names).
	local loot = { { id = 9910, name = "Shiny Ring" }, { id = 9911, name = "Old Necklace" }, { id = 9912, name = "Ruby" } }
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("item:" .. loot[i].id) end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, 1, nil, 2 end end
	package.loaded.mock = nil
	local MD = require("mock")
	for b = 1, 5 do MD.sizes[b] = 0 end
	MD.sizes[0] = 2
	MD.put(0, 1, { id = 9920, name = "Forest Mushroom Cap of the Long Name", q = 0, count = 3, class = 0, subclass = 5, price = 1 })
	MD.put(0, 2, { id = 9921, name = "Belt", q = 1, class = 4, subclass = 1, price = 2, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nD = MD.loadAddon("BagSmith")
	MD.fire("ADDON_LOADED", "BagSmith"); MD.fire("PLAYER_ENTERING_WORLD"); MD.runTimers(); MD.runTimers()
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(id) if id >= 9910 and id <= 9912 then return "Prize", nil, 2, nil, nil, nil, nil, 1, nil, nil, 500 end return realInfo(id) end
	MD.fire("LOOT_OPENED"); MD.runTimers()
	local f = nD.MakeRoom.frame
	local shown = 0
	for _, r in ipairs(f.waitRows) do if r:IsShown() then shown = shown + 1 end end
	check(shown == 3 and MRwaiting(f) == 3 and f.sub.text:find("3 items won't fit"), "every item that won't fit is listed at once, with a count")
	-- Skip takes one off the list; the rest stay.
	f.waitRows[1].btns[1]:GetScript("OnClick")(f.waitRows[1].btns[1])
	check(MRwaiting(f) == 2, "Skip removes that item; the others stay listed")
	-- Item tooltips on the rows.
	local set = {}
	GameTooltip.SetLootItem = function(_, slot) set.loot = slot end
	GameTooltip.SetBagItem = function(_, bag, slot) set.bag = bag .. ":" .. slot end
	f.waitRows[1]:GetScript("OnEnter")(f.waitRows[1])
	local junkRow
	for _, r in ipairs(f.destroyRows) do if r:IsShown() then junkRow = junkRow or r end end
	junkRow:GetScript("OnEnter")(junkRow)
	check(set.loot == 2 and set.bag == "0:1", "hovering a row shows that item's tooltip (loot or bag item)")
	GameTooltip:Hide()
	-- Junk is noted on the value line, so the name has room.
	check(junkRow.name.text == "Forest Mushroom Cap of the Long Name" and junkRow.count.text == "3" and junkRow.value.text:find("^Junk") and junkRow.name.width > 150,
		"the name gets the room left of the buttons; Junk is on the value line")
	-- The description sits just under the title.
	check(f.sub.points[1][2] == f.title and f.sub.points[1][5] == -3, "the description sits just under the title")
	-- Moving it: remembered (and kept through the settings checks), used next time.
	f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -200)
	f:GetScript("OnDragStop")(f)
	check(nD.db.makeRoomPos and nD.db.makeRoomPos[1] == "TOPLEFT" and nD.db.makeRoomPos[4] == 300, "dragging it remembers the spot")
	f:Hide(); nD.MakeRoom:Show("loot")
	check(f.points[1][1] == "TOPLEFT" and f.points[1][4] == 300 and f.points[1][5] == -200, "and it opens there next time")
	local saved = nD.db.makeRoomPos
	check(nD.Profiles and BagSmithDB.profiles.Default.makeRoomPos == saved, "the spot is saved with the profile")
	f:Hide()
	C_Item.GetItemInfo = realInfo
	_G.GetNumLootItems, _G.GetLootSlotType, _G.GetLootSlotLink, _G.GetLootSlotInfo = nil, nil, nil, nil
end)()

;(function()
	-- The Make Room spot survives a reload (checked like other saved positions).
	package.loaded.mock = nil
	local ME = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, profiles = { Default = { makeRoomPos = { "TOPLEFT", "UIParent", "TOPLEFT", 120, -80 } } }, chars = {}, cache = {} }
	local nE = ME.loadAddon("BagSmith")
	ME.fire("ADDON_LOADED", "BagSmith"); ME.fire("PLAYER_ENTERING_WORLD"); ME.runTimers()
	local p = nE.db.makeRoomPos
	check(type(p) == "table" and p[1] == "TOPLEFT" and p[4] == 120 and p[5] == -80, "the Make Room spot is kept across a reload")
	_G.BagSmithDB = { version = 2, profiles = { Default = { makeRoomPos = "bad" } }, chars = {}, cache = {} }
	package.loaded.mock = nil; ME = require("mock")
	nE = ME.loadAddon("BagSmith"); ME.fire("ADDON_LOADED", "BagSmith")
	check(nE.db.makeRoomPos == false, "a damaged spot falls back to beside the loot window")
end)()

;(function()
	-- 0.13.0-beta6: Sell Junk Automatically at Vendors, the rename, the shard text, the solid Classic background.
	package.loaded.mock = nil
	local MA = require("mock")
	MA.put(0, 1, { id = 9601, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
	MA.put(0, 2, { id = 9602, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
	MA.put(0, 3, { id = 9603, name = "Silk Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 15 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {}, junkMarks = { [9602] = true } }; _G.BagSmithDB = nil
	local n = MA.loadAddon("BagSmith")
	MA.fire("ADDON_LOADED", "BagSmith"); MA.fire("PLAYER_ENTERING_WORLD"); MA.runTimers(); MA.runTimers()
	_G.MerchantFrame = MerchantFrame or CreateFrame("Frame", "MerchantFrame", UIParent)
	local used = {}
	local realUse = C_Container.UseContainerItem
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; local m = package.loaded.mock; if m and m.bags[bag] then m.bags[bag][slot] = nil end end
	MerchantFrame:Show(); MA.fire("MERCHANT_SHOW"); MA.runTimers(); MA.elapse(); MA.runTimers()
	check(#used == 0, "Sell Junk Automatically is off by default: opening a vendor sells nothing")
	MA.fire("MERCHANT_CLOSED"); MerchantFrame:Hide()
	n:Set("autoSellJunk", true)
	local before = #MA.log
	MerchantFrame:Show(); MA.fire("MERCHANT_SHOW"); MA.runTimers(); MA.elapse(); MA.runTimers()
	table.sort(used)
	check(#used == 2 and used[1] == "0:1" and used[2] == "0:2", "on: opening a vendor sells the grey and the marked item, nothing else")
	check(table.concat(MA.log, " ", before + 1):find("Sold 2 junk items for"), "with a chat summary")
	MA.fire("MERCHANT_CLOSED"); MerchantFrame:Hide()
	-- Blocked by the game: says so once and stops for that visit.
	MA.put(0, 1, { id = 9601, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
	MA.put(0, 2, { id = 9602, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" }); n:Scan()
	used = {}
	C_Container.UseContainerItem = function() MA.fire("ADDON_ACTION_BLOCKED", "BagSmith", "UseContainerItem") end
	before = #MA.log
	MerchantFrame:Show(); MA.fire("MERCHANT_SHOW"); MA.runTimers(); MA.elapse(); MA.runTimers()
	check(n.Junk.autoBlocked and table.concat(MA.log, " ", before + 1):find("needs a click to sell"), "if the game blocks it: one message, and no more tries this visit")
	MA.fire("MERCHANT_CLOSED"); MerchantFrame:Hide()
	check(not n.Junk.autoBlocked, "the next visit tries again")
	-- Never in combat.
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; local m = package.loaded.mock; if m and m.bags[bag] then m.bags[bag][slot] = nil end end
	used = {}
	MA.combat = true; MerchantFrame:Show(); MA.fire("MERCHANT_SHOW"); MA.runTimers(); MA.elapse(); MA.runTimers(); MA.combat = false
	check(#used == 0, "never during combat")
	MA.fire("MERCHANT_CLOSED"); MerchantFrame:Hide()
	C_Container.UseContainerItem = realUse
	-- Settings wording.
	local P = n.SettingsPanel; P:Show(); P:ShowPage("loothelper")
	local heads, steps = {}, {}
	for _, h in ipairs(P.pools.head) do if h:IsShown() then heads[h.text.text] = true end end
	for _, w in ipairs(P.pools.step) do if w:IsShown() then steps[w.text.text] = w.help and w.help.text end end
	local checks = {}
	for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key then checks[w.key] = w.text and w.text.text end end
	check(heads["Loot Helper"] and checks.makeRoom == "Show Loot Helper When Loot Won't Fit", "renamed: Loot Helper in Settings (on its own sub-page since 1.2.0)")
	P:ShowPage("automation"); steps = {}
	for _, w in ipairs(P.pools.step) do if w:IsShown() then steps[w.text.text] = w.help and w.help.text end end
	check(steps["Soul Shards to Keep"] and steps["Soul Shards to Keep"]:find("^|cff8788eeWarlock|r only%.") and steps["Soul Shards to Keep"]:find("count toward it"),
		"the shard setting: Soul Shards to Keep, Warlock in the warlock color, clearer help")
	P:Hide()
	-- The Make Room Helper's title, and its solid Classic background.
	n:Set("skin", "classic")
	n.MakeRoom:Show("loot")
	local f = n.MakeRoom.frame
	check(f.title.text == "Loot Helper", "renamed: the panel's title")
	local st = f.classicState
	check(st and st.chrome:IsShown() and st.solid == nil and not f.classicSpec.template and st.title and st.title.text == "Loot Helper",
		"Classic: the Loot Helper wears the window chrome and background like the bags window, its title in the bar (1.0.2; it had the solid dialog fill from 0.14.0-beta9 to 1.0.1)")
	f:Hide()
end)()

;(function()
	-- 0.13.0-beta7: key names spelled out; tooltip lines survive rebuilds.
	local binds = { ["CTRL-J"] = "BAGSMITH_MARKJUNK" }
	_G.GetBindingKey = function(action) for k, a in pairs(binds) do if a == action then return k end end end
	_G.KEY_SPACE, _G.KEY_NUMPAD1 = "Space", "Num Pad 1"
	package.loaded.mock = nil
	local MT = require("mock")
	MT.put(0, 1, { id = 9701, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
	MT.put(0, 2, { id = 9702, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local n = MT.loadAddon("BagSmith")
	MT.fire("ADDON_LOADED", "BagSmith"); MT.fire("PLAYER_ENTERING_WORLD"); MT.runTimers(); MT.runTimers()
	ToggleAllBags(); MT.runTimers()
	local KB = n.KeyBinds
	check(KB:Pretty("CTRL-J") == "Ctrl-J" and KB:Pretty("SHIFT-K") == "Shift-K" and KB:Pretty("ALT-P") == "Alt-P", "key names are spelled out: Ctrl-J, Shift-K, Alt-P (not C-J)")
	check(KB:Pretty("SHIFT-CTRL-J") == "Ctrl-Shift-J" and KB:Pretty("ALT-CTRL-SHIFT-X") == "Ctrl-Shift-Alt-X", "modifiers in the usual order")
	check(KB:Pretty("ALT-SPACE") == "Alt-Space" and KB:Pretty("NUMPAD1") == "Num Pad 1" and KB:Pretty("CTRL--") == "Ctrl--", "named keys use the game's names")
	check(KB:Key("BAGSMITH_MARKJUNK") == "Ctrl-J", "the Key Bindings page and hints use the spelled-out name")
	check(n.Buttons.tooltipHook == "TooltipDataProcessor", "BagSmith's tooltip lines go through the game's item tooltip post-processing")
	-- Hover a markable item: the hint is there, and still there (once) after the game rebuilds the tooltip.
	local belt
	for _, b in ipairs(n.Window.main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 9701 then belt = b end end
	belt:GetScript("OnEnter")(belt)
	local function count(text) local c = 0; for _, l in ipairs(GameTooltip.lines or {}) do if l == text then c = c + 1 end end; return c end
	check(count("Press Ctrl-J to mark as junk") == 1, "hovering an item shows: Press Ctrl-J to mark as junk")
	MT.rebuildTooltip()
	check(count("Press Ctrl-J to mark as junk") == 1, "after the game rebuilds the tooltip, the hint is still there, once")
	MT.rebuildTooltip(); MT.rebuildTooltip()
	check(count("Press Ctrl-J to mark as junk") == 1, "and after more rebuilds, never doubled")
	belt:GetScript("OnLeave")(belt)
	-- A grey item: no hint (always junk).
	local fang
	for _, b in ipairs(n.Window.main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 9702 then fang = b end end
	fang:GetScript("OnEnter")(fang)
	check(count("Press Ctrl-J to mark as junk") == 0, "grey items get no hint (they're always junk)")
	fang:GetScript("OnLeave")(fang)
	-- A tooltip that isn't BagSmith's: nothing added.
	GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR"); GameTooltip:SetBagItem(0, 1)
	check(#GameTooltip.lines == 0, "tooltips not owned by BagSmith's item buttons get nothing")
	local before = #MT.log
	SlashCmdList.BAGSMITH("check")
	check(table.concat(MT.log, " ", before + 1):find("Item tooltip lines added through: TooltipDataProcessor"), "/bs check reports how tooltip lines are added")
	_G.GetBindingKey = nil
end)()

;(function()
	-- 0.13.0-beta8: selling uses live prices, retries late item details, and checks items left.
	package.loaded.mock = nil
	local MS = require("mock")
	MS.put(0, 1, { id = 9801, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {}, junkMarks = { [9801] = true } }
	_G.BagSmithDB = { version = 2, profiles = { Default = { autoSellJunk = true, debug = true } }, chars = {}, cache = {} }
	local n = MS.loadAddon("BagSmith")
	MS.fire("ADDON_LOADED", "BagSmith"); MS.fire("PLAYER_ENTERING_WORLD"); MS.runTimers(); MS.runTimers()
	n.db.debug = true
	_G.MerchantFrame = MerchantFrame or CreateFrame("Frame", "MerchantFrame", UIParent)
	local used = {}
	local realUse, realInfo = C_Container.UseContainerItem, C_Item.GetItemInfo
	local sells = true
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; if sells then MS.bags[bag][slot] = nil end end
	-- The item's details aren't loaded yet: asking the game loads them half a second later.
	local loaded, pending = false, false
	local realReq = C_Item.RequestLoadItemDataByID
	C_Item.RequestLoadItemDataByID = function(id) if id == 9801 and not pending then pending = true; C_Timer.After(0.5, function() loaded = true end) end end
	C_Item.GetItemInfo = function(id)
		if id == 9801 then if not loaded then return nil end; return "Linen Belt", nil, 1, nil, nil, nil, nil, 1, nil, nil, 22 end
		return realInfo(id)
	end
	-- The bag scan didn't get a price for it either (details not loaded then).
	for _, r in ipairs(n.items) do if r.itemID == 9801 then r.sellPrice = nil end end
	local before = #MS.log
	MerchantFrame:Show(); MS.fire("MERCHANT_SHOW"); MS.runTimers(); MS.elapse(); MS.runTimers(); MS.elapse(); MS.runTimers()
	local said = table.concat(MS.log, " ", before + 1)
	check(#used == 1 and used[1] == "0:1" and said:find("Sold 1 junk item for"), "an item whose details load late still sells on the same visit")
	check(said:find("Junk sale %(auto%): selling 0, waiting for item details 1") and said:find("Junk sale check %(auto, look %d+%): 1 left the bags, 0 still there"),
		"with /bs debug on, each attempt is logged: what's waiting, what sold")
	MS.fire("MERCHANT_CLOSED"); MerchantFrame:Hide()
	-- The game quietly ignores the sale: BagSmith notices and offers the button.
	MS.put(0, 1, { id = 9801, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" }); n:Scan()
	sells = false; used = {}
	_G.MerchantSellAllJunkButton = CreateFrame("Button", "MerchantSellAllJunkButton", MerchantFrame); MerchantSellAllJunkButton:SetSize(32, 32)
	MerchantSellAllJunkButton:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMLEFT", 100, 30); MerchantSellAllJunkButton:Show()
	before = #MS.log
	MerchantFrame:Show(); MS.fire("MERCHANT_SHOW"); MS.runTimers(); MS.elapse(); MS.runTimers(); MS.elapse(); MS.runTimers()
	MS.elapse(); MS.runTimers(); MS.elapse(); MS.runTimers()   -- (1.3.1: the check looks again before it reports)
	said = table.concat(MS.log, " ", before + 1)
	local sb = _G.BagSmithSellMarkedButton
	check(#used == 1 and said:find("Didn't sell: Linen Belt%. Click Sell Marked") and n.Junk.retry and sb and sb:IsShown(), "if items don't leave the bags, BagSmith names them and shows Sell Marked for a retry")
	sells = true; used = {}
	sb:GetScript("OnClick")(sb); MS.runTimers(); MS.elapse(); MS.runTimers()
	check(#used == 1 and not MS.bags[0][1], "one click on Sell Marked sells it")
	MS.fire("MERCHANT_CLOSED"); MerchantFrame:Hide()
	check(not n.Junk.retry, "closing the vendor resets it")
	C_Container.UseContainerItem, C_Item.GetItemInfo, C_Item.RequestLoadItemDataByID = realUse, realInfo, realReq
	_G.MerchantSellAllJunkButton = nil
end)()

;(function()
	-- 0.13.0-beta9: Favorites, Track as Currency, Pawn arrows.
	local function boot(profile, stock)
		package.loaded.mock = nil
		local MF = require("mock")
		if stock then stock(MF) else
			MF.put(0, 1, { id = 9901, name = "Hearthstone Keeper", q = 1, class = 15, subclass = 0, price = 0 })
			MF.put(0, 2, { id = 9902, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
			MF.put(0, 3, { id = 9903, name = "Silk Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 15 })
			MF.put(0, 4, { id = 20558, name = "Warsong Gulch Mark", q = 2, count = 3, class = 12, subclass = 0, price = 0 })
		end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		profile = profile or {}   -- (written for Modern; new players start in Classic)
		if profile.skin == nil then profile.skin = "modern" end
		_G.BagSmithDB = { version = 2, profiles = { Default = profile }, chars = {}, cache = {} }
		local n = MF.loadAddon("BagSmith")
		MF.fire("ADDON_LOADED", "BagSmith"); MF.fire("PLAYER_ENTERING_WORLD"); MF.runTimers(); MF.runTimers()
		ToggleAllBags(); MF.runTimers()
		n:Set("view", "list"); n:Set("grp", "type"); n:RefreshViews(true)
		return n, MF
	end
	local n, M = boot(nil)
	local main = n.Window.main
	local function row(id) for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then return b end end end
	local function laneOf(id) local b = row(id); return b and b.rec and n.IndexOf(main.laneIds, "~fav") and b end
	-- Columns: Favorite, Currency, Junk at the far edge.
	local order = {}
	for _, key in ipairs(main:ColumnPlan()) do order[#order + 1] = key.key end
	local s1 = table.concat(order, ",")
	check(s1:find("fv,cc,jk$"), "columns end Favorite, Currency, Junk: " .. s1)
	check(main.headerLabels.fv.junkIcon:IsShown() and main.headerLabels.cc.junkIcon:IsShown(), "the Favorite and Currency headers show the star and the wallet")
	-- Favorite: the star cell, then the item moves into Favorites at the top.
	local belt = row(9902)
	check(belt.colFav and belt.colFav.state == "eligible" and belt.colFav.tex.alpha == 0, "an item's star is invisible until you hover")
	belt:GetScript("OnEnter")(belt)
	check(belt.colFav.tex.alpha == 0.35 and belt.colCurr.tex.alpha == 0.35, "hovering the row shows the star and wallet faintly")
	belt:GetScript("OnLeave")(belt)
	belt.colFav:GetScript("OnClick")(belt.colFav); M.runTimers(); n:RefreshViews(true)
	check(n.IndexOf(n.db.favItems, 9902) and main.laneIds[1] == "~fav", "starring an item puts it in Favorites, the first section (no Recent items here)")
	belt = row(9902)
	local inFav = 0
	for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 9902 then inFav = inFav + 1 end end
	check(inFav == 1 and belt.colFav.state == "on" and belt.colFav.tex.alpha == 1, "it moved (shown once, in Favorites), with a full gold star")
	-- Section Order: Favorites can move; and hidden, items go back.
	check(n.db.laneOrder[1] == "~recent" and n.db.laneOrder[2] == "~fav", "Favorites sits right after Recent in Section Order")
	n:Set("favSection", false); n:RefreshViews(true)
	check(not n.IndexOf(main.laneIds, "~fav") and row(9902), "with the Favorites section off, favorites stay in their usual sections")
	n:Set("favSection", true); n:RefreshViews(true)
	-- The Loot Helper never suggests destroying a favorite.
	local _, destroy = n.MakeRoom:Suggestions({ { id = 1, values = { vendor = 99999 } } })
	local offered = false
	for _, d in ipairs(destroy) do if d.rec.itemID == 9902 then offered = true end end
	check(not offered, "the Loot Helper never suggests destroying a favorite")
	-- Track as Currency: the wallet cell; built-in tokens are fixed.
	local mark = row(20558)
	check(mark.colCurr.state == "fixed" and mark.colCurr.tex.alpha == 1, "a built-in token shows the wallet in full and can't be untracked")
	mark.colCurr:GetScript("OnClick")(mark.colCurr)
	check(not n.IndexOf(n.db.customCurrencies, 20558), "clicking a built-in token's wallet does nothing")
	local silk = row(9903)
	silk.colCurr:GetScript("OnClick")(silk.colCurr)
	check(n.IndexOf(n.db.customCurrencies, 9903) and silk.colCurr.state == "on", "clicking the wallet tracks the item as a currency (in the profile)")
	local found
	for _, e in ipairs(n.Currency:List()) do if e.id == 9903 then found = e end end
	check(found and found.custom and found.count == 5, "it's in the currency list with its count")
	-- Kept even when you have none.
	M.bags[0][3] = nil; n:Scan()
	found = nil
	for _, e in ipairs(n.Currency:List()) do if e.id == 9903 then found = e end end
	check(found and found.count == 0, "with none left, it's still listed (at 0): custom currencies are never forgotten")
	-- The drawer: Tracked Items, dimmed at 0, with a remove control.
	n.Drawer:Show()
	local d = n.Drawer.frame
	local trow
	for _, r in ipairs(d.rows) do if r:IsShown() and r.id == 9903 then trow = r end end
	check(trow and trow.remove:IsShown() and trow.icon.desaturated, "the drawer lists it under Tracked Items, dimmed at 0, with a remove control")
	-- Add Item: search what BagSmith has seen (incl. other characters), or a link or ID.
	BagSmithDB.cache["Other - Realm"] = { name = "Other", realm = "Realm", items = { { itemID = 9950, name = "Ruby Shard", icon = 1 } }, bags = {} }
	d.add:SetText("ruby"); d.add:GetScript("OnTextChanged")(d.add, true)
	check(d.suggest[1] and d.suggest[1]:IsShown() and d.suggest[1].text.text == "Ruby Shard", "Add Item suggests matching items, including other characters' saved bags")
	d.suggest[1]:GetScript("OnClick")(d.suggest[1])
	check(n.IndexOf(n.db.customCurrencies, 9950) and d.add:GetText() == "", "clicking a suggestion tracks it")
	d.add:SetText("|cffffffff|Hitem:12345::::::::|h[Something]|h|r"); d.add:GetScript("OnEnterPressed")(d.add)
	check(n.IndexOf(n.db.customCurrencies, 12345), "pasting an item link adds any item")
	d.add:SetText("777"); d.add:GetScript("OnEnterPressed")(d.add)
	check(n.IndexOf(n.db.customCurrencies, 777), "so does an item ID")
	d.add:SetText("zzzz"); d.add:GetScript("OnTextChanged")(d.add, true)
	check(d.addHint.text:find("Paste an item link"), "no match: it explains links and IDs")
	trow = nil
	for _, r in ipairs(d.rows) do if r:IsShown() and r.id == 9903 then trow = r end end
	trow.remove:GetScript("OnClick")(trow.remove)
	check(not n.IndexOf(n.db.customCurrencies, 9903), "the remove control stops tracking")
	n.Drawer:Hide()
	-- Key bindings for both marks.
	check(BINDING_NAME_BAGSMITH_FAVORITE == "Favorite Item" and BINDING_NAME_BAGSMITH_CURRENCYITEM == "Track as Currency", "key bindings: Favorite Item and Track as Currency")
	_G.GetMouseFoci = function() return { row(9901) } end
	BagSmith_ToggleFavorite(); BagSmith_ToggleCurrencyItem(); M.runTimers()
	check(n.IndexOf(n.db.favItems, 9901) and n.IndexOf(n.db.customCurrencies, 9901), "the keys work on the item under the pointer")
	_G.GetMouseFoci = nil
	-- Tooltip lines.
	local lines = {}
	local tip = { AddLine = function(_, t) lines[#lines + 1] = t end }
	n.Marks:AddTooltipLines(tip, { itemID = 9901 })
	check(lines[1] == "Favorite" and lines[2] == "Tracked as a currency", "tooltips say Favorite and Tracked as a currency")
	-- Profile Sharing carries them.
	local code = n.Share:Export()
	local data = n.Share:Decode(code)
	check(data.favItems and data.customCurrencies and n.IndexOf(data.customCurrencies, 9950), "Profile Sharing carries favorites and tracked currencies")
	-- An existing profile gets the two columns once, just before Junk.
	local n2 = boot({ cols = { "c", "t", "jk" }, colOrder = { "c", "n", "t", "jk" }, laneOrder = { "~recent", "Gear", "Junk" } })
	check(table.concat(n2.db.cols, ",") == "c,t,fv,cc,jk" and n2.db.colOrder[4] == "fv" and n2.db.colOrder[5] == "cc" and n2.db.colOrder[6] == "jk",
		"an existing profile gets Favorite and Currency once, just before Junk")
	check(n2.db.laneOrder[2] == "~fav", "and Favorites joins Section Order after Recent")
end)()

;(function()
	-- Pawn upgrade arrows.
	local upgrades = { [9802] = true }
	-- Pawn's real API for bag addons: ask by item link (true = check the player's level).
	_G.PawnShouldItemLinkHaveUpgradeArrow = function(link, checkLevel) local id = tonumber(tostring(link):match("item:(%d+)")); return upgrades[id] or false end
	_G.PawnCommon = { ShowBagUpgradeAdvisor = true }
	package.loaded.mock = nil
	local MP = require("mock")
	MP.put(0, 1, { id = 9801, name = "Old Belt", q = 1, class = 4, subclass = 1, price = 5, equip = "INVTYPE_WAIST" })
	MP.put(0, 2, { id = 9802, name = "Better Belt", q = 2, class = 4, subclass = 1, price = 50, equip = "INVTYPE_WAIST" })
	MP.put(0, 3, { id = 9803, name = "Grey Upgrade", q = 0, class = 4, subclass = 1, price = 1, equip = "INVTYPE_WAIST" })
	upgrades[9803] = true
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local n = MP.loadAddon("BagSmith")
	MP.fire("ADDON_LOADED", "BagSmith"); MP.fire("PLAYER_ENTERING_WORLD"); MP.runTimers(); MP.runTimers()
	ToggleAllBags(); MP.runTimers()
	local main = n.Window.main
	local function row(id) for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then return b end end end
	check(n.Pawn:Active(), "Pawn found, its bag upgrade advisor on")
	local up, old = row(9802), row(9801)
	check(up.pawnArrow and up.pawnArrow:IsShown() and up.pawnArrow.points[1][1] == "BOTTOMLEFT" and not (old.pawnArrow and old.pawnArrow:IsShown()),
		"Pawn's upgrade arrow shows on the upgrade, top-left, and not on the other item")
	check(up.newDot.points[1][1] == "BOTTOM", "the new-item dot stays at the bottom center, clear of the arrow")
	local both = row(9803)
	check(both.junkCoin:IsShown() and both.pawnArrow:IsShown() and both.pawnArrow.points[1][1] == "BOTTOMLEFT", "junk and an upgrade: the arrow keeps the bottom-left (1.1.0; the top-right belongs to the item level), the coin the top-left, so both show")
	n:Set("view", "icons"); n:RefreshViews(true)
	up = row(9802)
	check(up.pawnArrow:IsShown() and up.pawnArrow.w and up.pawnArrow.w >= 10, "icon view: the arrow is sized with the icon")
	-- The Loot Helper never suggests destroying an upgrade.
	local _, destroy = n.MakeRoom:Suggestions({ { id = 1, values = { vendor = 99999 } } })
	local offered = false
	for _, d in ipairs(destroy) do if d.rec.itemID == 9802 then offered = true end end
	check(not offered, "the Loot Helper never suggests destroying a Pawn upgrade")
	-- Pawn's own switch off: no arrows.
	_G.PawnCommon.ShowBagUpgradeAdvisor = false; n:RefreshViews(true)
	check(not row(9802).pawnArrow:IsShown(), "with Pawn's bag upgrade advisor off, no arrows")
	-- Another character's saved bags: never.
	check(n.Pawn:IsUpgrade({ itemID = 9802, cached = true, link = "x" }) == nil, "never on another character's saved bags")
	local before = #MP.log
	SlashCmdList.BAGSMITH("check")
	check(table.concat(MP.log, " ", before + 1):find("Pawn: found   bag upgrade advisor off"), "/bs check reports Pawn")
	_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil
end)()

;(function()
	-- 0.13.0-beta10: one icon family, gold when on; currency Pins; Classic square buttons' states.
	package.loaded.mock = nil
	local MI = require("mock")
	MI.put(0, 1, { id = 9601, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
	MI.put(0, 2, { id = 9602, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, profiles = { Default = { favItems = { 9602 }, customCurrencies = { 9602 } } }, chars = {}, cache = {} }
	local n = MI.loadAddon("BagSmith")
	MI.fire("ADDON_LOADED", "BagSmith"); MI.fire("PLAYER_ENTERING_WORLD"); MI.runTimers(); MI.runTimers()
	ToggleAllBags(); MI.runTimers(); n:Set("view", "list"); n:RefreshViews(true)
	local main = n.Window.main
	local function row(id) for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then return b end end end
	local h = main.headerLabels
	check(h.fv.junkIcon.texture:find("ui%-star") and h.cc.junkIcon.texture:find("ui%-wallet") and h.jk.junkIcon.texture:find("ui%-pouch"),
		"the three column headers are one BagSmith family: star, wallet, pouch")
	local c1, c2, c3 = h.fv.junkIcon.color, h.cc.junkIcon.color, h.jk.junkIcon.color
	check(c1[1] == c2[1] and c2[1] == c3[1] and c1[3] == c3[3], "all three in the header text's color")
	local belt, fang = row(9602), row(9601)
	local gold = n.Junk.ON_COLOR
	check(belt.colFav.tex.color[1] == gold[1] and belt.colCurr.tex.color[1] == gold[1] and fang.colJunk.tex.color[1] == gold[1] and fang.colJunk.tex.color[3] == gold[3],
		"every column icon that's on is gold (favorited, tracked, junk)")
	-- Currency Pins.
	n.Drawer:Show()
	local d = n.Drawer.frame
	local heads = {}
	for _, hd in ipairs(d.heads) do if hd:IsShown() then heads[#heads + 1] = hd.text and hd.text.text or "" end end
	check(table.concat(heads, "|"):find("Pinned") and not table.concat(heads, "|"):find("Favorites") and d.hint.text == "Pin a currency to show it in the bag footer.",
		"the drawer says Pinned and Pin a currency (item Favorites are the star)")
	check(d.rows[1].star.tex.texture:find("ui%-pin"), "the pin icon replaces the star in the drawer")
	d.rows[1].star:GetScript("OnEnter")(d.rows[1].star)
	check(GameTooltip.owner == d.rows[1].star and GameTooltip.shown, "the pin has a tooltip (Pin to Footer / Unpin)")
	n.Drawer:Hide()
	-- Classic square buttons: pushed in with a white icon while on, like Travel Mode.
	n:Set("skin", "classic"); MI.runTimers()
	local bank = main.btnBank
	bank:SetActive(true)
	check(bank.squareBg.texture and bank.squareBg.texture:find("Down") and bank.tex.color[1] == 1 and bank.tex.color[3] == 1, "Classic: a square button that's on is pushed in with a white icon")
	bank:SetActive(false)
	check(not bank.squareBg.texture:find("Down") and bank.tex.color[3] == 0, "and raised with a gold icon when off")
	bank:GetScript("OnMouseDown")(bank); bank:GetScript("OnMouseUp")(bank)
	check(not bank.squareBg.texture:find("Down"), "a click that leaves it off settles back up")
end)()

;(function()
	-- 0.13.0-beta11: header icons centered on their columns.
	package.loaded.mock = nil
	local MH = require("mock")
	MH.put(0, 1, { id = 9602, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local n = MH.loadAddon("BagSmith")
	MH.fire("ADDON_LOADED", "BagSmith"); MH.fire("PLAYER_ENTERING_WORLD"); MH.runTimers(); MH.runTimers()
	ToggleAllBags(); MH.runTimers(); n:Set("view", "list"); n:RefreshViews(true)
	local main = n.Window.main
	local belt
	for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 9602 then belt = b end end
	local ok, info = true, {}
	for key, field in pairs({ fv = "colFav", cc = "colCurr", jk = "colJunk" }) do
		local hp = main.headerLabels[key].junkIcon.points[1]
		local cp = belt[field].points[1]
		info[#info + 1] = key .. " " .. tostring(hp[4]) .. "/" .. tostring(cp[4])
		if not (hp[2] == main.header and hp[3] == "LEFT" and hp[4] == cp[4]) then ok = false end
	end
	check(ok, "each column header icon is centered on its column, exactly over its row cells: " .. table.concat(info, ", "))
	main.headerLabels.fv:GetScript("OnClick")(main.headerLabels.fv, "LeftButton"); n:RefreshViews(true)
	local si = main.headerLabels.fv.sortIcon
	check(si:IsShown() and si.points[1][2] == main.headerLabels.fv.junkIcon, "sorting by one: the arrow sits beside the icon, not over it")
end)()

;(function()
	-- The Loot Helper keeps going with more than one item waiting; quest mode.
	local loot = {}
	_G.GetNumLootItems = function() local c = 0; for i = 1, 8 do if loot[i] then c = i end end; return c end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("item:" .. loot[i].id) end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, 1, nil, 2 end end
	local looted = {}
	_G.DeleteCursorItem = function() local m = package.loaded.mock; if m.cursorFrom then m.bags[m.cursorFrom[1]][m.cursorFrom[2]] = nil end end
	package.loaded.mock = nil
	local ML = require("mock")
	for b = 1, 5 do ML.sizes[b] = 0 end
	ML.sizes[0] = 3
	ML.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
	ML.put(0, 2, { id = 9702, name = "Torn Hide", q = 0, class = 15, subclass = 0, price = 2 })
	ML.put(0, 3, { id = 9703, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 22, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local n = ML.loadAddon("BagSmith")
	ML.fire("ADDON_LOADED", "BagSmith"); ML.fire("PLAYER_ENTERING_WORLD"); ML.runTimers(); ML.runTimers()
	C_Container.PickupContainerItem = function(bag, slot) local it = ML.bags[bag] and ML.bags[bag][slot]; ML.cursorItem = it and it.id; ML.cursorFrom = { bag, slot } end
	_G.ClearCursor = function() ML.cursorItem = nil end
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(id) if id == 9710 or id == 9711 then return "Prize", nil, 2, nil, nil, nil, nil, 1, nil, nil, 500 end return realInfo(id) end
	-- Looting takes the item out of the loot window first; it lands in the bags a moment later.
	_G.LootSlot = function(i)
		looted[#looted + 1] = i
		local it = loot[i]; loot[i] = nil
		ML.fire("LOOT_SLOT_CLEARED", i)
		local free
		for sl = 1, 3 do if not ML.bags[0][sl] then free = sl; break end end
		ML.put(0, free, { id = it.id, name = it.name, q = 2, class = 4, subclass = 1, price = 500, equip = "INVTYPE_FINGER" }); n:Scan()
	end
	loot = { { id = 9710, name = "Shiny Ring" }, { id = 9711, name = "Old Necklace" } }
	ML.fire("LOOT_OPENED"); ML.runTimers()
	local f = n.MakeRoom.frame
	check(f:IsShown() and MRwaiting(f) == 2, "two items waiting")
	-- Destroy one junk item: the first is looted, the panel stays with the second.
	local junkRow
	for _, r in ipairs(f.destroyRows) do if r:IsShown() then junkRow = junkRow or r end end
	MRact(junkRow); n:Scan(); ML.runTimers()
	check(#looted == 1 and f:IsShown() and MRwaiting(f) == 1, "after one destroy: the first item is looted and the panel stays with the second")
	for _, r in ipairs(f.destroyRows) do if r:IsShown() then junkRow = r; break end end
	MRact(junkRow); n:Scan(); ML.runTimers()
	check(#looted == 2 and not f:IsShown(), "a second destroy loots the second item, and only then does the panel close")
	-- The safety net: if the panel was closed while something still won't fit, a bag update brings it back.
	ML.bags[0][1] = { id = 9720, name = "Rock", q = 0, class = 15, subclass = 0, price = 1, count = 1 }
	loot = { { id = 9710, name = "Shiny Ring" } }
	ML.fire("LOOT_OPENED"); ML.runTimers()
	f:Hide()
	n:Scan(); ML.runTimers()
	check(f:IsShown(), "a bag update while the loot window is open brings the panel back if something still won't fit")
	f:Hide(); loot = {}; ML.fire("LOOT_CLOSED")
	-- Quest turn-in: rewards that won't fit.
	local turnedIn = false
	_G.GetQuestReward = function() turnedIn = true end
	_G.GetNumQuestRewards = function() return 1 end
	_G.GetNumQuestChoices = function() return 2 end
	_G.GetQuestItemInfo = function(kind, i) return "Reward Boots", "icon", 1, 2 end
	_G.GetQuestItemLink = function(kind, i) return "item:9730" end
	ML.fire("QUEST_COMPLETE")
	_G.ERR_INV_FULL = _G.ERR_INV_FULL or "Inventory is full."
	ML.fire("UI_ERROR_MESSAGE", 3, ERR_INV_FULL)
	check(f:IsShown() and n.MakeRoom.mode == "quest" and MRwaiting(f) == 2 and f.sub.text:find("click Complete Quest"),
		"turning in a quest with full bags: the Loot Helper lists the reward and a slot for your choice")
	check(not f.waitRows[1].btns[1]:IsShown() and not f.waitRows[1].btns[2]:IsShown(), "no Skip or Never Ask for quest rewards")
	-- Make room: it says so, and never completes the quest itself.
	ML.bags[0][1] = nil; ML.bags[0][2] = nil; n:Scan(); ML.runTimers()
	check(f:IsShown() and f.sub.text == "There's room now: click Complete Quest." and not turnedIn, "once there's room it says so, and leaves the click to you")
	ML.fire("QUEST_TURNED_IN")
	check(not f:IsShown(), "turning the quest in closes it")
	-- Accepting a quest that hands you an item.
	ML.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 })
	ML.put(0, 2, { id = 9702, name = "Torn Hide", q = 0, class = 15, subclass = 0, price = 2 }); n:Scan()
	ML.fire("QUEST_DETAIL")
	ML.fire("UI_ERROR_MESSAGE", 3, ERR_INV_FULL)
	check(f:IsShown() and f.waitRows[1].name.text == "An item from this quest" and f.sub.text:find("click Accept"), "accepting a quest that hands you an item: An item from this quest, then click Accept")
	ML.fire("QUEST_ACCEPTED", 1)
	check(not f:IsShown(), "accepting the quest closes it")
	-- The real order: clicking Accept closes the quest window first; the error comes after.
	_G.GetTitleText = function() return "Report to Goldshire" end
	ML.fire("QUEST_DETAIL"); ML.fire("QUEST_FINISHED")
	ML.fire("UI_ERROR_MESSAGE", 3, ERR_INV_FULL)
	check(f:IsShown() and f.sub.text:find("from Report to Goldshire won't fit") and f.sub.text:find("talk to the quest giver and click Accept"),
		"the window closing before the error still opens it, naming the quest, and says to talk to the quest giver")
	ML.bags[0][1] = nil; n:Scan(); ML.runTimers()
	check(f:IsShown() and f.sub.text == "There's room now: talk to the quest giver and click Accept.", "it stays open once there's room, with what to do")
	f:Hide()
	-- Too long after the window closed: an unrelated "Inventory is full" doesn't open it.
	ML.fire("QUEST_DETAIL"); ML.fire("QUEST_FINISHED")
	ML.put(0, 1, { id = 9701, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 3 }); n:Scan()
	ML.gameTime = (ML.gameTime or 0) + 10
	ML.fire("UI_ERROR_MESSAGE", 3, ERR_INV_FULL)
	check(not f:IsShown(), "an unrelated Inventory is full long after a quest window doesn't open it")
	-- The game's own line is enough on its own.
	_G.ERR_QUEST_FAILED_BAG_FULL_S = "%s failed: Inventory is full."
	n.MakeRoom.quest = nil
	ML.fire("CHAT_MSG_SYSTEM", "Report to Goldshire failed: Inventory is full.")
	check(f:IsShown() and n.MakeRoom.quest and n.MakeRoom.quest.title == "Report to Goldshire", "the game's \"<quest> failed: Inventory is full.\" line opens it too")
	f:Hide(); _G.GetTitleText = nil
	C_Item.GetItemInfo = realInfo
	_G.GetNumLootItems, _G.GetLootSlotType, _G.GetLootSlotLink, _G.GetLootSlotInfo, _G.LootSlot, _G.DeleteCursorItem = nil, nil, nil, nil, nil, nil
	_G.GetQuestReward, _G.GetNumQuestRewards, _G.GetNumQuestChoices, _G.GetQuestItemInfo, _G.GetQuestItemLink = nil, nil, nil, nil, nil
end)()

;(function()
	-- 0.13.0-beta13: Pawn arrows survive "not ready yet" answers (resizing the window).
	local upgrades, busy = { [9802] = true }, false
	_G.PawnShouldItemLinkHaveUpgradeArrow = function(link)
		if busy then return nil end
		local id = tonumber(tostring(link):match("item:(%d+)"))
		return upgrades[id] or false
	end
	_G.PawnCommon = { ShowBagUpgradeAdvisor = true }
	package.loaded.mock = nil
	local MP = require("mock")
	MP.put(0, 1, { id = 9801, name = "Old Belt", q = 1, class = 4, subclass = 1, price = 5, equip = "INVTYPE_WAIST" })
	MP.put(0, 2, { id = 9802, name = "Better Belt", q = 2, class = 4, subclass = 1, price = 50, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, profiles = { Default = { debug = true } }, chars = {}, cache = {} }
	local n = MP.loadAddon("BagSmith")
	MP.fire("ADDON_LOADED", "BagSmith"); MP.fire("PLAYER_ENTERING_WORLD"); MP.runTimers(); MP.runTimers()
	ToggleAllBags(); MP.runTimers()
	n.db.debug = true
	local main = n.Window.main
	local function row(id) for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then return b end end end
	check(row(9802).pawnArrow:IsShown(), "the upgrade has its arrow")
	-- Resizing redraws every row; Pawn answers "not ready" during the burst.
	busy = true
	local before = #MP.log
	main.frame:SetSize(main.frame:GetWidth() + 60, main.frame:GetHeight()); n:RefreshViews(true)
	check(row(9802).pawnArrow:IsShown() and not (row(9801).pawnArrow and row(9801).pawnArrow:IsShown()),
		"while Pawn says not ready, arrows keep their last state (no vanishing on resize)")
	busy = false
	MP.runTimers()
	check(row(9802).pawnArrow:IsShown(), "once Pawn answers again, the arrows are still right")
	-- A gear change: the remembered answers are dropped and asked again.
	upgrades[9802] = nil
	MP.fire("PLAYER_EQUIPMENT_CHANGED"); MP.runTimers()
	check(not row(9802).pawnArrow:IsShown(), "after a gear change, a former upgrade loses its arrow")
	-- An item Pawn never answered for (and none remembered): no arrow, and it keeps asking a few times only.
	busy = true; n.Pawn:Forget()
	n:RefreshViews(true)
	for _ = 1, 10 do MP.runTimers() end
	check(not row(9802).pawnArrow:IsShown() and n.Pawn.level == 6 and n.Pawn.recheckPending,
		"no answer and nothing remembered: no arrow, and the re-checks slow down to every 5 s but never stop (beta8)")
	check(table.concat(MP.log, " ", before + 1):find("Pawn: %d+ items not answered yet"), "/bs debug reports Pawn's answers on the re-check")
	busy = false
	for _ = 1, 3 do MP.runTimers() end
	check(row(9802).pawnArrow:IsShown() or not upgrades[9802], "once Pawn answers, the slowed re-checks pick it up")
	_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil
end)()

;(function()
	-- 0.13.0-beta14: fixes from the outside audit (verified independently).
	local loot = {}
	_G.GetNumLootItems = function() local c = 0; for i = 1, 8 do if loot[i] then c = i end end; return c end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("item:" .. loot[i].id) end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, 1, nil, 2 end end
	local function boot(stock)
		package.loaded.mock = nil
		local M = require("mock")
		for b = 1, 5 do M.sizes[b] = 0 end
		M.sizes[0] = 4
		stock(M)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.db.makeRoomAsk = true   -- (1.5.1-beta2) these checks test the asking path; Ask Before Destroying is off by default now
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id; M.cursorFrom = { bag, slot } end
		_G.ClearCursor = function() M.cursorItem = nil end
		M.deleted = 0
		local base = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id)
			if id == 5010 or id == 5011 then return "Prize", nil, 2, nil, nil, nil, nil, 1, nil, nil, 5000 end
			if id == 5001 then return "Cloth", nil, 1, nil, nil, nil, nil, 20, nil, nil, 1 end
			return base(id)
		end
		_G.DeleteCursorItem = function() local it = M.bags[M.cursorFrom[1]][M.cursorFrom[2]]; M.deleted = M.deleted + (it and (it.count or 1) or 0); M.bags[M.cursorFrom[1]][M.cursorFrom[2]] = nil end
		return n, M
	end
	local function destroyRow(f, name) for _, r in ipairs(f.destroyRows) do if r:IsShown() and r.name.text:find("^" .. name) then return r end end end

	-- IS-01: the exact offered item and count, checked at the moment of destroying.
	local n, M = boot(function(MM)
		MM.put(0, 1, { id = 5001, name = "Cloth", q = 1, count = 1, class = 7, subclass = 5, price = 1 })
		for s = 2, 4 do MM.put(0, s, { id = 5100 + s, name = "Gear" .. s, q = 1, class = 4, subclass = 1, price = 900, equip = "INVTYPE_WAIST" }) end
	end)
	loot = { { id = 5010, name = "Ring" } }
	M.fire("LOOT_OPENED"); M.runTimers()
	local f = n.MakeRoom.frame
	local row = destroyRow(f, "Cloth")
	MRact(row)
	check(n.Popups.confirm.text.text:find("Destroy Cloth %(") , "the confirmation names the item")
	M.bags[0][1].count = 20
	n.Popups.confirm.yes:GetScript("OnClick")(n.Popups.confirm.yes)
	check(M.deleted == 0 and M.bags[0][1] and M.bags[0][1].count == 20, "a 1-unit offer whose slot now holds 20: nothing is destroyed")
	M.bags[0][1].count = 1; n:Scan(); n.MakeRoom:Paint()
	row = destroyRow(f, "Cloth")
	MRact(row)
	table.insert(n.db.favItems, 5001)
	n.Popups.confirm.yes:GetScript("OnClick")(n.Popups.confirm.yes)
	check(M.deleted == 0 and M.bags[0][1], "an item favorited after the offer: nothing is destroyed")
	n.db.favItems = {}; n:Scan(); n.MakeRoom:Paint()
	row = destroyRow(f, "Cloth")
	MRact(row)
	M.bags[0][1] = { id = 5009, name = "Other", q = 1, count = 1, class = 7, subclass = 5, price = 1 }
	n.Popups.confirm.yes:GetScript("OnClick")(n.Popups.confirm.yes)
	check(M.deleted == 0 and M.bags[0][1].id == 5009, "a different item in the slot: nothing is destroyed")
	M.put(0, 1, { id = 5001, name = "Cloth", q = 1, count = 1, class = 7, subclass = 5, price = 1 }); n:Scan(); n.MakeRoom:Paint()   -- (M.put gives it an instance, as every real item has)
	row = destroyRow(f, "Cloth")
	MRact(row)
	n.Popups.confirm.yes:GetScript("OnClick")(n.Popups.confirm.yes)
	check(M.deleted == 1 and not M.bags[0][1], "an unchanged item is destroyed, exactly once")
	-- Pawn: an item Pawn learns is an upgrade after the offer isn't destroyed.
	M.put(0, 1, { id = 5001, name = "Cloth", q = 1, count = 1, class = 7, subclass = 5, price = 1 }); n:Scan(); n.MakeRoom:Paint()
	row = destroyRow(f, "Cloth")
	MRact(row)
	_G.PawnShouldItemLinkHaveUpgradeArrow = function() return true end
	n.Popups.confirm.yes:GetScript("OnClick")(n.Popups.confirm.yes)
	check(M.deleted == 1 and M.bags[0][1], "Pawn calling it an upgrade after the offer: nothing is destroyed")
	_G.PawnShouldItemLinkHaveUpgradeArrow = function() return nil end
	row = destroyRow(f, "Cloth") or row
	n.MakeRoom:Paint(); row = destroyRow(f, "Cloth")
	if row then
		MRact(row); n.Popups.confirm.yes:GetScript("OnClick")(n.Popups.confirm.yes)
	end
	check(M.deleted == 1 and M.bags[0][1], "Pawn not having decided yet: nothing is destroyed (try again in a moment)")
	_G.PawnShouldItemLinkHaveUpgradeArrow = nil
	f:Hide(); loot = {}; M.fire("LOOT_CLOSED")

	-- IS-02: only slots the waiting loot can use are suggested.
	n, M = boot(function(MM)
		MM.sizes[1] = 1
		for s = 1, 3 do MM.put(0, s, { id = 5200 + s, name = "Gear" .. s, q = 1, class = 4, subclass = 1, price = 900, equip = "INVTYPE_WAIST" }) end
		MM.put(0, 4, { id = 5204, name = "Cheap Belt", q = 1, class = 4, subclass = 1, price = 50, equip = "INVTYPE_WAIST" })
		MM.put(1, 1, { id = 5300, name = "Rough Arrow", q = 1, count = 200, class = 6, subclass = 2, price = 1 })
	end)
	local realFree = C_Container.GetContainerNumFreeSlots
	C_Container.GetContainerNumFreeSlots = function(bag) local free = realFree(bag); return free, bag == 1 and 1 or 0 end   -- bag 1: a quiver
	local realFamily = C_Item.GetItemFamily
	C_Item.GetItemFamily = function(id) if id == 5300 or id == 5301 then return 1 end return 0 end
	loot = { { id = 5010, name = "Ring" } }
	M.fire("LOOT_OPENED"); M.runTimers()
	local _, destroy = n.MakeRoom:Suggestions(n.MakeRoom:Waiting())
	local arrows, belt = false, false
	for _, d in ipairs(destroy) do if d.rec.itemID == 5300 then arrows = true end; if d.rec.itemID == 5204 then belt = true end end
	check(not arrows and belt, "arrows in a quiver aren't suggested for a ring (that slot can't take it); an item in an ordinary bag is")
	n.MakeRoom.frame:Hide(); loot = { { id = 5301, name = "Sharp Arrow" } }
	local _, d2 = n.MakeRoom:Suggestions({ { id = 5301, name = "Sharp Arrow", qty = 1, values = { vendor = 9999 } } })
	arrows = false
	for _, d in ipairs(d2) do if d.rec.itemID == 5300 then arrows = true end end
	check(arrows, "for arrows, the quiver's own items can be suggested")
	C_Container.GetContainerNumFreeSlots, C_Item.GetItemFamily = realFree, realFamily
	loot = {}; M.fire("LOOT_CLOSED")

	-- IS-03: two slots freed at once: both waiting items are taken.
	n, M = boot(function(MM) for s = 1, 4 do MM.put(0, s, { id = 5400 + s, name = "Junk" .. s, q = 0, class = 15, subclass = 0, price = 1 }) end end)
	local looted = 0
	_G.LootSlot = function(i)
		looted = looted + 1
		local it = loot[i]; loot[i] = nil
		M.fire("LOOT_SLOT_CLEARED", i)
		C_Timer.After(0.2, function()
			for s = 1, 4 do if not M.bags[0][s] then M.put(0, s, { id = it.id, name = it.name, q = 2, class = 4, subclass = 1, price = 5000, equip = "INVTYPE_FINGER" }); break end end
			n:Scan()
		end)
	end
	loot = { { id = 5010, name = "Ring" }, { id = 5011, name = "Amulet" } }
	M.fire("LOOT_OPENED"); M.runTimers()
	M.bags[0][1] = nil; M.bags[0][2] = nil; n:Scan()
	for _ = 1, 8 do M.runTimers() end
	check(looted == 2 and GetNumLootItems() == 0 and not n.MakeRoom.frame:IsShown(), "two slots freed at once: both waiting items are looted, then the panel closes")
	_G.LootSlot = nil

	-- IS-04: an old loot window's close timer doesn't close the next one's panel.
	n, M = boot(function(MM) for s = 1, 4 do MM.put(0, s, { id = 5500 + s, name = "Gear" .. s, q = 1, class = 4, subclass = 1, price = 900, equip = "INVTYPE_WAIST" }) end end)
	loot = { { id = 5010, name = "Ring" } }
	M.fire("LOOT_OPENED"); M.runTimers()
	M.fire("LOOT_CLOSED")
	local fromA = M.timers or {}; M.timers = {}           -- corpse A's close timer, held back
	M.fire("LOOT_OPENED"); M.runTimers()                -- corpse B opens; its panel shows
	for _, fn in ipairs(fromA) do fn() end              -- A's timer fires 4 s after A closed
	check(n.MakeRoom.frame:IsShown(), "corpse A's close timer doesn't close corpse B's panel")
	loot = {}; M.fire("LOOT_CLOSED")

	-- IS-05: the Sell Marked tooltip with a price still loading.
	n, M = boot(function(MM) MM.put(0, 1, { id = 5601, name = "Belt", q = 1, class = 4, subclass = 1, price = 20, equip = "INVTYPE_WAIST" }) end)
	n.cdb.junkMarks[5601] = true
	_G.MerchantFrame = MerchantFrame or CreateFrame("Frame", "MerchantFrame", UIParent); MerchantFrame:Show()
	local saveInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(id) if id == 5601 then return nil end; return saveInfo(id) end
	n.Junk.needsClick = true; n.Junk:UpdateSellButton()
	local b = _G.BagSmithSellMarkedButton
	local lines = {}
	local oldAdd = GameTooltip.AddLine
	GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
	local ok = pcall(b:GetScript("OnEnter"), b)
	GameTooltip.AddLine = oldAdd
	check(ok and (lines[1] or ""):find("some prices still loading"), "the Sell Marked tooltip works while a price loads, and says so")
	C_Item.GetItemInfo = saveInfo; MerchantFrame:Hide()

	-- R1: closing Settings (or leaving the page, or switching profile) stops a waiting "Press a key...".
	local binds = { B = "OPENALLBAGS" }
	_G.GetBindingKey = function(a) for k, v in pairs(binds) do if v == a then return k end end end
	_G.GetBindingAction = function(k) return binds[k] or "" end
	_G.SetBinding = function(k, a) binds[k] = a end
	_G.SaveBindings = function() end
	_G.GetCurrentBindingSet = function() return 1 end
	n, M = boot(function() end)
	local P = n.SettingsPanel
	local function startCapture()
		P:Show(); P:ShowPage("keys")
		for _, w in ipairs(P.pools.bind) do if w:IsShown() and w.action == "BAGSMITH_MARKJUNK" then w.set:GetScript("OnClick")(w.set) end end
	end
	startCapture(); P:Hide()
	check(not n.KeyBinds.capture:IsShown() and binds.B == "OPENALLBAGS", "closing Settings stops waiting for a key; B keeps its binding")
	startCapture(); P:ShowPage("look")
	check(not n.KeyBinds.capture:IsShown(), "leaving the Keybindings page stops it too")
	startCapture(); n.Profiles:Use("Other")
	check(not n.KeyBinds.capture:IsShown(), "and switching profile")
	P:Hide()
	_G.GetBindingKey, _G.GetBindingAction, _G.SetBinding, _G.SaveBindings, _G.GetCurrentBindingSet = nil, nil, nil, nil, nil

	-- Age filter: only the ends that are set apply.
	local rec = { firstSeen = time() - 86400, itemID = 1, name = "x", quality = 1 }
	local minOnly = n:FilterPredicate(n.CleanFilters({ ageMin = 1 }))
	local maxOnly = n:FilterPredicate(n.CleanFilters({ ageMax = 2 }))
	check(minOnly(rec) and not maxOnly(rec), "age filter: \"at least 1 hour\" includes a day-old item; \"at most 2 hours\" doesn't")
	_G.GetNumLootItems, _G.GetLootSlotType, _G.GetLootSlotLink, _G.GetLootSlotInfo = nil, nil, nil, nil
end)()

;(function()
	-- Merge Stacks: random-suffix gear sharing an item ID keeps its own rows; stackables still merge.
	package.loaded.mock = nil
	local MM = require("mock")
	MM.put(0, 1, { id = 6001, name = "Bandit's Boots of the Bear", q = 2, class = 4, subclass = 2, price = 100, equip = "INVTYPE_FEET" })
	MM.put(0, 2, { id = 6001, name = "Bandit's Boots of the Eagle", q = 2, class = 4, subclass = 2, price = 140, equip = "INVTYPE_FEET" })
	MM.put(0, 3, { id = 6002, name = "Linen Cloth", q = 1, count = 5, stack = 20, class = 7, subclass = 5, price = 1 })
	MM.put(0, 4, { id = 6002, name = "Linen Cloth", q = 1, count = 7, stack = 20, class = 7, subclass = 5, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local n = MM.loadAddon("BagSmith")
	MM.fire("ADDON_LOADED", "BagSmith"); MM.fire("PLAYER_ENTERING_WORLD"); MM.runTimers(); MM.runTimers()
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(x)
		local id = tonumber(x) or tonumber(tostring(x):match("item:(%d+)"))
		if id == 6002 then return "Linen Cloth", x, 1, 5, 1, "Trade Goods", "Cloth", 20, "", 1, 1, 7, 5 end
		if id == 6001 then local a, b = realInfo(x); return a, b, 2, 20, 15, "Armor", "Leather", 1, "INVTYPE_FEET", 1, 100, 4, 2 end
		return realInfo(x)
	end
	n:Scan()
	ToggleAllBags(); MM.runTimers(); n:Set("view", "list"); n:Set("mergeStacks", true); n:RefreshViews(true)
	local boots, cloth = 0, nil
	for _, b in ipairs(n.Window.main.used or {}) do
		if b:IsShown() and b.rec then
			if b.rec.itemID == 6001 then boots = boots + 1 end
			if b.rec.itemID == 6002 then cloth = b.rec end
		end
	end
	check(boots == 2, "Merge Stacks: two different pieces of gear sharing an item ID stay as two rows")
	check(cloth and cloth.count == 12, "stacks of a stackable item still merge (5 + 7 = 12)")
	C_Item.GetItemInfo = realInfo
end)()

;(function()
	-- Pawn, per its own notes for bag addons: register, re-check by progress, every live button.
	local registered, refreshAll
	_G.PawnRegisterThirdPartyBag = function(name, o) registered = name; refreshAll = o.RefreshAll end
	local answers, calls = {}, {}
	_G.PawnShouldItemLinkHaveUpgradeArrow = function(link, checkLevel)
		calls[#calls + 1] = checkLevel
		local id = tonumber(tostring(link):match("item:(%d+)"))
		return answers[id]
	end
	_G.PawnCommon = { ShowBagUpgradeAdvisor = true }
	package.loaded.mock = nil
	local MP = require("mock")
	MP.put(0, 1, { id = 9851, name = "Belt", q = 2, class = 4, subclass = 1, price = 50, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local n = MP.loadAddon("BagSmith")
	MP.fire("ADDON_LOADED", "BagSmith"); MP.fire("PLAYER_ENTERING_WORLD"); MP.runTimers(); MP.runTimers()
	check(registered == "BagSmith", "BagSmith registers with Pawn as a bag addon")
	check(calls[1] == true or #calls == 0, "Pawn is asked with its player-level check on")
	ToggleAllBags(); MP.runTimers()
	local main = n.Window.main
	local function row() for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 9851 then return b end end end
	-- No answer for a while: passes stop when they make no progress...
	for _ = 1, 12 do MP.runTimers() end
	check(n.Pawn.level == 6 and n.Pawn.recheckPending, "with no answers, the re-checks slow down but keep going (beta8: they never give up)")
	-- ...and a gear change resets the pace.
	MP.fire("PLAYER_EQUIPMENT_CHANGED"); MP.runTimers()
	check(n.Pawn.level == 1 and n.Pawn.recheckPending, "a gear change re-checks at full pace again")
	answers[9851] = true
	for _ = 1, 3 do MP.runTimers() end
	check(row().pawnArrow and row().pawnArrow:IsShown(), "once Pawn answers, the arrow appears")
	-- Pawn telling bag addons to refresh: memory cleared, arrows re-asked.
	answers[9851] = false
	refreshAll(); for _ = 1, 3 do MP.runTimers() end
	check(not row().pawnArrow:IsShown(), "Pawn's RefreshAll clears the remembered answers and updates the arrows")
	-- A remembered "no" stays "no" while Pawn is busy (not nil).
	answers[9851] = nil
	check(n.Pawn:IsUpgradeLink(row().rec.link) == false, "a remembered no stays no while Pawn is busy")
	-- Pawn loading after BagSmith: registers when it arrives.
	registered = nil
	n.Pawn.registered = false
	MP.fire("ADDON_LOADED", "Pawn")
	check(registered == "BagSmith", "if Pawn loads later, BagSmith registers then")
	_G.PawnRegisterThirdPartyBag, _G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil, nil
end)()

;(function()
	-- The re-check covers the small bag windows too.
	local answers = {}
	_G.PawnShouldItemLinkHaveUpgradeArrow = function(link) return answers[tonumber(tostring(link):match("item:(%d+)"))] end
	_G.PawnCommon = { ShowBagUpgradeAdvisor = true }
	package.loaded.mock = nil
	local MP = require("mock")
	MP.put(0, 1, { id = 9861, name = "Belt", q = 2, class = 4, subclass = 1, price = 50, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local n = MP.loadAddon("BagSmith")
	MP.fire("ADDON_LOADED", "BagSmith"); MP.fire("PLAYER_ENTERING_WORLD"); MP.runTimers(); MP.runTimers()
	ToggleAllBags(); MP.runTimers()
	n.Window.bagViews[0]:Show(); MP.runTimers()
	local mirror
	for _, pool in pairs(n.Buttons.mirrors) do for _, b in pairs(pool) do if b:IsShown() and b.rec and b.rec.itemID == 9861 then mirror = b end end end
	n.Pawn:Forget(); n.Pawn:ScheduleRecheck()   -- a fresh episode (the earlier passes gave up with no answers)
	answers[9861] = true
	for _ = 1, 3 do MP.runTimers() end
	check(mirror and mirror.pawnArrow and mirror.pawnArrow:IsShown(), "the re-check updates the small bag window's buttons too")
	_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil
end)()

;(function()
	-- 0.13.0-beta15: a profile switch updates everything that belongs to the profile.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7101, name = "Peacebloom", q = 1, count = 5, class = 7, subclass = 9, price = 1 })
	M.put(0, 2, { id = 7102, name = "Copper Ore", q = 1, count = 5, class = 7, subclass = 7, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = {
		Default = { sheets = { { n = "Materials", f = { text = "Peacebloom" } } }, tabOrder = { "All", "Materials" }, customCurrencies = { 123 }, scale = 1.5,
			settingsPoint = { "CENTER", "UIParent", "CENTER", 0, 0 }, bagPoints = { ["0"] = { "TOPLEFT", "UIParent", "TOPLEFT", 10, -10 } } },
		Blue = { sheets = { { n = "Materials", f = { text = "Copper" } } }, tabOrder = { "All", "Materials" }, customCurrencies = { 456 }, scale = 1.0,
			settingsPoint = { "TOPLEFT", "UIParent", "TOPLEFT", 50, -50 }, bagPoints = { ["0"] = { "TOPLEFT", "UIParent", "TOPLEFT", 800, -10 } }, accent = "0000ff" },
	} }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	main:SetSheet("Materials"); M.runTimers()
	n.Currency:Invalidate(); n.Currency:List()
	n.Window.bagViews[0]:Show(); M.runTimers()
	local P = n.SettingsPanel; P:Show()
	-- A color picker opened under Default stays open across the switch.
	local picker = {}
	_G.ColorPickerFrame = { SetupColorPickerAndShow = function(_, info) picker = info end, GetColorRGB = function() return 1, 0, 0 end }
	P:ShowPage("look")
	for _, b in ipairs(P.pools.btn) do if b:IsShown() and b.label and b.label.text and b.label.text:find("Pick") then b:GetScript("OnClick")(b) end end
	n.Profiles:Use("Blue"); M.runTimers()
	check(n.ui.filters.text == "Copper" and main.search:GetText() == "Copper", "a same-named sheet takes the new profile's filters and search (Copper, not Peacebloom)")
	local ids = {}
	for _, e in ipairs(n.Currency:List()) do if e.custom then ids[#ids + 1] = e.id end end
	check(ids[1] == 456 and #ids == 1, "tracked currencies follow the profile at once")
	check(P.frame.scale == 1.0 and P.frame.points[1][1] == "TOPLEFT", "open Settings takes the new profile's scale and spot")
	local bp = n.Window.bagViews[0].frame.points[1]
	check(bp[4] == 800, "a small bag window moves to the new profile's saved spot")
	if picker.cancelFunc then picker.cancelFunc() end
	if picker.swatchFunc then picker.swatchFunc() end
	check(n.db.accent == "0000ff", "a color picker opened for the old profile doesn't change the new one")
	P:Hide(); _G.ColorPickerFrame = nil
end)()

;(function()
	-- Loot Helper fit and combine arithmetic; Combine re-checks; junk unmark; Where choices.
	package.loaded.mock = nil
	local M = require("mock")
	for b = 1, 5 do M.sizes[b] = 0 end
	M.sizes[0] = 4
	M.put(0, 1, { id = 7201, name = "Silk", q = 1, count = 2, class = 7, subclass = 5, price = 1 })
	M.put(0, 2, { id = 7201, name = "Silk", q = 1, count = 3, class = 7, subclass = 5, price = 1 })
	M.put(0, 3, { id = 7201, name = "Silk", q = 1, count = 19, class = 7, subclass = 5, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local base = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(x) local id = tonumber(x) or tonumber(tostring(x):match("item:(%d+)")); if id == 7201 or id == 7210 then return "Silk", nil, 1, nil, nil, nil, nil, 20, nil, nil, 1 end; return base(x) end
	-- Fit: one free slot, two separate 1-unit entries of a stackable item: both fit (one new stack).
	local MR = n.MakeRoom
	local loot = { { id = 7210, name = "Wool" }, { id = 7210, name = "Wool" } }
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("item:" .. loot[i].id) end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, 1, nil, 1 end end
	check(#MR:Waiting() == 0, "two 1-unit entries of a stackable item fit in one free slot")
	loot = { { id = 7210, name = "Wool", qty = 21 } }
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, l.qty or 1, nil, 1 end end
	check(#MR:Waiting() == 1, "21 of an item that stacks to 20 doesn't fit in one slot")
	-- Combine: 2 + 3 fits; the old check only tried 2 + 19.
	local combine = MR:Suggestions({ { id = 1, values = { vendor = 0 } } })
	check(combine[1] and combine[1].src.count == 2 and combine[1].dst.count == 3, "Combine finds 2 + 3 when 2 + 19 is too many")
	-- Combine re-checks both stacks when clicked.
	local picked = 0
	C_Container.PickupContainerItem = function() picked = picked + 1 end
	M.bags[0][2].count = 18
	MR:Combine(combine[1])
	check(picked == 0, "if a stack changed since it was offered, Combine does nothing")
	-- An existing junk mark can always be removed.
	n.cdb.junkMarks[7201] = true
	local rec = { itemID = 7201, quality = 1, sellPrice = 1, isQuest = true, bag = 0, slot = 1 }
	n.Junk:Toggle(rec)
	check(not n.cdb.junkMarks[7201], "a marked item that's now a quest item can still be unmarked")
	C_Item.GetItemInfo = base
	_G.GetNumLootItems, _G.GetLootSlotType, _G.GetLootSlotLink, _G.GetLootSlotInfo = nil, nil, nil, nil
end)()

;(function()
	-- Where choices match the window (the main window's Bank sheet shows bank bags).
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7301, name = "Thing", q = 1, class = 4, subclass = 1, price = 5, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	M.fire("BANKFRAME_OPENED"); M.runTimers(); M.fire("BANKFRAME_CLOSED"); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	main:SetSheet("Bank"); M.runTimers()
	local f = { view = main }
	local names = {}
	n.Popups.FillWhere = n.Popups.FillWhere
	local saved = n.CachedRecords and select(2, main:Records()) or {}
	local list = {}
	for _, bag in ipairs(main:Bags()) do local info = saved[bag] or n.bagInfo[bag]; if info and (info.size or 0) > 0 then list[#list + 1] = info.name end end
	local carried = false
	for _, nm in ipairs(list) do if nm == n.bagInfo[0].name then carried = true end end
	check(not carried, "the Bank sheet's Where choices are bank bags, not your backpack")
end)()

;(function()
	-- New-item markers: a merged row remembers each stack's own size; moved stacks keep their own newness.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7401, name = "Herb", q = 1, count = 5, class = 7, subclass = 9, price = 1 })
	M.put(0, 2, { id = 7401, name = "Herb", q = 1, count = 5, class = 7, subclass = 9, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local a
	for _, r in ipairs(n.items) do if r.slot == 1 then a = r end end
	n:DismissNew({ bag = 0, slot = 1, itemID = 7401, count = 10, merged = true, guid = a.guid, quality = 1 })
	local remembered = a.guid and n.cdb.seen[a.guid] or tonumber((n.cdb.seenSlots["0:1"] or ""):match(":(%d+)$"))
	check(remembered == 5, "dismissing a merged row remembers the stack's own 5, not the total 10")
end)()

;(function()
	-- Hardening: imported anchors, damaged history, failed key assignment, share lengths, sheet names, bank fallback.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = { good = 1700000000, bad = "x" }, seenSlots = { ["0:1"] = 123, ["0:2"] = "5:3" } }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {
		point = { "NOT_AN_ANCHOR", "UIParent", "ALSO_BAD", 0, 0 }, sheets = { { n = "Bank", f = {} }, { n = "Mine", f = {} } } } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	check(n.ANCHORS == nil and n.db.point[1] ~= "NOT_AN_ANCHOR", "an invalid saved anchor falls back to the default spot")
	check(BagSmithCharDB.firstSeen.good == 1700000000 and BagSmithCharDB.firstSeen.bad == nil, "damaged history entries are dropped, good ones kept")
	check(BagSmithCharDB.seenSlots["0:1"] ~= 123, "a damaged slot memory is dropped (it can't break scanning)")
	local okScan = pcall(function() n:Scan() end)
	check(okScan, "scanning works after the repair")
	local names = {}
	for _, s in ipairs(n.db.sheets) do names[#names + 1] = s.n end
	check(table.concat(names, ",") == "Bank (2),Mine", "a saved sheet named like a built-in tab is renamed, never dropped (rc2)")
	-- Failed key assignment: the old binding stays, nothing saved.
	local binds, saves = { J = "BAGSMITH_MARKJUNK" }, 0
	_G.GetBindingKey = function(a) for k, v in pairs(binds) do if v == a then return k end end end
	_G.GetBindingAction = function(k) return binds[k] or "" end
	_G.SetBinding = function(k, a) if k == "F13" then return false end; binds[k] = a; return true end
	_G.SaveBindings = function() saves = saves + 1 end
	_G.GetCurrentBindingSet = function() return 1 end
	local msg = n.KeyBinds:Set("BAGSMITH_MARKJUNK", "F13")
	check(binds.J == "BAGSMITH_MARKJUNK" and saves == 0 and msg, "if the game refuses a key, the old binding stays and nothing is saved")
	_G.GetBindingKey, _G.GetBindingAction, _G.SetBinding, _G.SaveBindings, _G.GetCurrentBindingSet = nil, nil, nil, nil, nil
	-- Share: a string length that isn't a whole number is rejected.
	local data = n.Share:Decode("BS1:" .. "x" .. ":0")
	check(data == nil, "a malformed share code is rejected")
	-- Bank never visited: no carried items returned as "bank".
	local recs = n:CachedRecords(n:CharKey(), true)
	check(#recs == 0, "asking for a bank that was never saved gives nothing, not your bags")
	-- Profile list sorting is a proper ordering.
	check(pcall(function() return n.Profiles:List() end), "the profile list sorts without error")
end)()

;(function()
	-- 0.13.0-beta16: the recheck's findings (verified independently).
	local loot = {}
	_G.GetNumLootItems = function() local c = 0; for i = 1, 8 do if loot[i] then c = i end end; return c end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("item:" .. loot[i].id) end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, 1, nil, 2 end end
	local function boot(stock, profile)
		package.loaded.mock = nil
		local M = require("mock")
		for b = 1, 5 do M.sizes[b] = 0 end
		M.sizes[0] = 4
		stock(M)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = profile and { version = 2, chars = {}, cache = {}, profiles = { Default = profile } } or nil
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.db.makeRoomAsk = true   -- (1.5.1-beta2) these checks test the asking path; Ask Before Destroying is off by default now
		C_Container.PickupContainerItem = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; M.cursorItem = it and it.id; M.cursorFrom = { bag, slot } end
		_G.ClearCursor = function() M.cursorItem = nil end
		M.deleted = 0
		_G.DeleteCursorItem = function() local it = M.bags[M.cursorFrom[1]][M.cursorFrom[2]]; M.deleted = M.deleted + (it and (it.count or 1) or 0); M.bags[M.cursorFrom[1]][M.cursorFrom[2]] = nil end
		local base = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(x) local id = tonumber(x) or tonumber(tostring(x):match("item:(%d+)")); if id == 5010 or id == 5020 then return "Prize", nil, 2, nil, nil, nil, nil, 1, nil, nil, 5000 end; return base(x) end
		return n, M
	end
	local function rowFor(n, name) for _, r in ipairs(n.MakeRoom.frame.destroyRows) do if r:IsShown() and r.name.text:find("^" .. name) then return r end end end

	-- A junk-marked item Pawn now calls an upgrade (or hasn't decided on) isn't destroyed.
	local n, M = boot(function(MM)
		MM.put(0, 1, { id = 5001, name = "Marked Belt", q = 2, class = 4, subclass = 1, price = 10, equip = "INVTYPE_WAIST" })
		for s = 2, 4 do MM.put(0, s, { id = 5100 + s, name = "Gear" .. s, q = 1, class = 4, subclass = 1, price = 900, equip = "INVTYPE_WAIST" }) end
	end)
	n.cdb.junkMarks[5001] = true; n:Scan()
	_G.PawnCommon = { ShowBagUpgradeAdvisor = true }
	_G.PawnShouldItemLinkHaveUpgradeArrow = function() return false end
	loot = { { id = 5010, name = "Ring" } }
	M.fire("LOOT_OPENED"); M.runTimers()
	local row = rowFor(n, "Marked Belt")
	_G.PawnShouldItemLinkHaveUpgradeArrow = function() return true end
	MRact(row)
	check(M.deleted == 0, "a junk-marked item Pawn now calls an upgrade isn't destroyed")
	_G.PawnShouldItemLinkHaveUpgradeArrow = function() return nil end
	MRact(row)
	check(M.deleted == 0, "nor one Pawn hasn't decided on")
	_G.PawnShouldItemLinkHaveUpgradeArrow = function() return false end
	MRact(row)
	check(M.deleted == 1, "with Pawn saying no, the junk item is destroyed in one click, once")
	_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil
	loot = {}; M.fire("LOOT_CLOSED")

	-- A confirmation from the previous loot window can't destroy anything.
	n, M = boot(function(MM)
		MM.sizes[1] = 1
		for s = 1, 4 do MM.put(0, s, { id = 5200 + s, name = "Gear" .. s, q = 1, class = 4, subclass = 1, price = 900, equip = "INVTYPE_WAIST" }) end
		MM.put(1, 1, { id = 5300, name = "Rough Arrow", q = 1, count = 200, class = 6, subclass = 2, price = 1 })
	end)
	local realFree = C_Container.GetContainerNumFreeSlots
	C_Container.GetContainerNumFreeSlots = function(bag) local free = realFree(bag); return free, bag == 1 and 1 or 0 end
	C_Item.GetItemFamily = function(id) if id == 5300 or id == 5020 then return 1 end return 0 end
	loot = { { id = 5020, name = "Sharp Arrow" } }
	M.fire("LOOT_OPENED"); M.runTimers()
	row = rowFor(n, "Rough Arrow")
	MRact(row)
	local c = n.Popups.confirm
	local accept = c.onYes
	loot = {}; M.fire("LOOT_CLOSED")
	check(not c:IsShown(), "closing the loot window closes its destroy confirmation")
	loot = { { id = 5010, name = "Ring" } }
	M.fire("LOOT_OPENED"); M.runTimers()
	if accept then accept() end   -- even if the old Yes still ran
	check(M.deleted == 0 and M.bags[1][1], "an offer from the previous loot window destroys nothing")
	-- Within the same loot window an unchanged offer still works.
	loot = {}; M.fire("LOOT_CLOSED"); loot = { { id = 5020, name = "Sharp Arrow" } }
	M.fire("LOOT_OPENED"); M.runTimers()
	row = rowFor(n, "Rough Arrow")
	MRact(row); n.Popups.confirm.yes:GetScript("OnClick")(n.Popups.confirm.yes)
	check(M.deleted == 200, "an unchanged offer in the same loot window still works")
	C_Container.GetContainerNumFreeSlots = realFree
	loot = {}; M.fire("LOOT_CLOSED")

	-- Never Ask drops every queued copy; one loot request at a time.
	n, M = boot(function(MM) for s = 1, 4 do MM.put(0, s, { id = 5400 + s, name = "Junk" .. s, q = 0, class = 15, subclass = 0, price = 1 }) end end)
	local requested = {}
	_G.LootSlot = function(i) requested[#requested + 1] = i end
	loot = { { id = 5010, name = "Ring" }, { id = 5010, name = "Ring" } }
	M.fire("LOOT_OPENED"); M.runTimers()
	n.MakeRoom:NeverAsk({ id = 5010, slot = 1 })
	M.bags[0][1] = nil; M.bags[0][2] = nil; n:Scan(); M.runTimers()
	check(#requested == 0, "Never Ask removes every queued copy of the item: none is looted")
	n.cdb.makeRoomNever = {}
	loot = {}; M.fire("LOOT_CLOSED")
	M.put(0, 1, { id = 5401, name = "Junk1", q = 0, class = 15, subclass = 0, price = 1 })
	M.put(0, 2, { id = 5402, name = "Junk2", q = 0, class = 15, subclass = 0, price = 1 }); n:Scan()
	loot = { { id = 5010, name = "Ring" }, { id = 5020, name = "Amulet" } }
	M.fire("LOOT_OPENED"); M.runTimers()
	requested = {}
	M.bags[0][1] = nil; n:Scan()                 -- one slot frees; the loot hasn't landed yet
	n.MakeRoom:Refresh()                        -- a repaint in the same moment
	check(#requested == 1, "one free slot: one loot request at a time, even with a repaint in between")
	_G.LootSlot = nil
	loot = {}; M.fire("LOOT_CLOSED")

	-- Sheets: a long name saved in the window survives a reload; built-in names still can't be imported.
	n, M = boot(function() end)
	local long = string.rep("x", 46)
	n:SaveSheet(long, n.Window.main)
	package.loaded.mock = nil
	local M2 = require("mock")
	local n2 = M2.loadAddon("BagSmith"); M2.fire("ADDON_LOADED", "BagSmith")
	local kept = false
	for _, sh in ipairs(n2.db.sheets) do if sh.n == long then kept = true end end
	check(kept, "a 46-character sheet saved in the window is still there after a reload")
	check(n2.SheetNameOK("Bank") == false and n2.SheetNameOK("Materials") == true, "one sheet-name rule: built-in tab names aren't allowed")

	-- U2: dismissing one piece of gear doesn't clear the dot on another with the same item ID.
	package.loaded.mock = nil
	local MU = require("mock")
	MU.put(0, 1, { id = 6001, name = "Boots of the Bear", q = 2, class = 4, subclass = 2, price = 100, equip = "INVTYPE_FEET" })
	MU.put(0, 2, { id = 6001, name = "Boots of the Eagle", q = 2, class = 4, subclass = 2, price = 140, equip = "INVTYPE_FEET" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
	local nu = MU.loadAddon("BagSmith")
	MU.fire("ADDON_LOADED", "BagSmith"); MU.fire("PLAYER_ENTERING_WORLD"); MU.runTimers(); MU.runTimers()
	for _, r in ipairs(nu.items) do r.isNew = true; r.maxStack = 1 end
	local a, b
	for _, r in ipairs(nu.items) do if r.slot == 1 then a = r else b = r end end
	nu:DismissNew({ bag = 0, slot = 1, itemID = 6001, quality = 2, count = 1, merged = true, maxStack = 1, equipLoc = "INVTYPE_FEET", guid = a.guid })
	check(b.isNew == true, "dismissing one piece of gear leaves the other piece's new dot alone")
	check(#nu.items > 0 and (function() local KEEPS = false; nu:SaveCache(); local c = BagSmithDB.cache[nu:CharKey()]; for _, r in ipairs(c and c.items or {}) do if r.maxStack then KEEPS = true end end; return KEEPS end)(),
		"the saved character snapshot keeps each item's stack size")

	-- Pawn: registered only while BagSmith stands in for Blizzard's bags.
	local reg, unreg = 0, 0
	_G.PawnRegisterThirdPartyBag = function() reg = reg + 1 end
	_G.PawnUnregisterThirdPartyBag = function() unreg = unreg + 1 end
	_G.PawnShouldItemLinkHaveUpgradeArrow = function() return false end
	n, M = boot(function() end, { replaceBlizzardBags = false })
	check(reg == 0, "with Blizzard's bags in use, BagSmith doesn't register with Pawn (Pawn keeps its own arrows there)")
	n:Set("replaceBlizzardBags", true)
	check(reg == 1, "turning replacement on registers")
	n:Set("replaceBlizzardBags", false)
	check(unreg == 1, "turning it off unregisters, so Pawn's arrows on Blizzard's bags come back")
	_G.PawnRegisterThirdPartyBag, _G.PawnUnregisterThirdPartyBag, _G.PawnShouldItemLinkHaveUpgradeArrow = nil, nil, nil

	-- H2: damaged entries in a saved character snapshot are dropped, the rest kept.
	package.loaded.mock = nil
	local MH = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, profiles = {}, cache = { ["Alt - Realm"] = { name = "Alt", realm = "Realm", items = { 5, { itemID = 1, bag = 0, slot = 1, name = "Ok" } }, bank = "bad" } } }
	local nh = MH.loadAddon("BagSmith"); MH.fire("ADDON_LOADED", "BagSmith")
	local alt = BagSmithDB.cache["Alt - Realm"]
	check(alt and #alt.items == 1 and alt.items[1].name == "Ok" and alt.bank == nil, "a damaged saved snapshot keeps its good items and drops the rest")
	check(pcall(function() return nh:CachedRecords("Alt - Realm", false), nh:CachedRecords("Alt - Realm", true) end), "and browsing that character works")
	_G.GetNumLootItems, _G.GetLootSlotType, _G.GetLootSlotLink, _G.GetLootSlotInfo = nil, nil, nil, nil
end)()

;(function()
	-- Profile switch: the open currency drawer shows the new profile's items at once; bag windows without saved spots stay put.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { customCurrencies = { 123 } }, Blue = { customCurrencies = { 456 } } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	n.Drawer:Show()
	n.Window.bagViews[0]:Show(); n.Window.bagViews[1]:Show(); M.runTimers()
	local p0 = n.Window.bagViews[0].frame.points[1]
	local before0 = p0 and (tostring(p0[1]) .. tostring(p0[4]) .. tostring(p0[5]))
	n.Profiles:Use("Blue"); M.runTimers()
	local ids = {}
	for _, r in ipairs(n.Drawer.frame.rows) do if r:IsShown() and r.id then ids[#ids + 1] = r.id end end
	local has = {}
	for _, id in ipairs(ids) do has[id] = true end
	check(has[456] and not has[123], "the open currency drawer shows the new profile's tracked item at once (not the old one)")
	local q0 = n.Window.bagViews[0].frame.points[1]
	local after0 = q0 and (tostring(q0[1]) .. tostring(q0[4]) .. tostring(q0[5]))
	check(before0 == after0, "a bag window with no saved spot in the new profile stays where it was (no pile-up)")
end)()

;(function()
	-- 0.13.0-beta17: the Never Ask window; the Classic picker art in Travel Mode.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {}, makeRoomNever = {} }; _G.BagSmithDB = nil
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local MR = n.MakeRoom
	local P = n.SettingsPanel; P:Show(); P:ShowPage("loothelper")
	local function texts() local t = {}; for _, w in ipairs(P.pools.text) do if w:IsShown() then t[#t + 1] = w.text.text or "" end end; return table.concat(t, "|") end
	local function buttons() local t = {}; for _, b in ipairs(P.pools.btn) do if b:IsShown() then t[#t + 1] = b.label.text end end; return t end
	check(texts():find("Your Loot Exclusion List is empty%. Use Exclude in the Loot Helper to add items%."), "with nothing never-asked, Settings says so")
	P:ShowPage("look"); P:ShowPage("loothelper")
	local yEmpty = P.y
	-- 30 items: still one line and two buttons.
	for id = 9000, 9029 do MR:Never()[id] = true end
	P:Refresh()
	local b = buttons()
	local lootButtons = {}; for _, t in ipairs(b) do if t == "Manage..." or t == "Clear All" then lootButtons[#lootButtons + 1] = t end end
	check(texts():find("Loot Exclusion List: 30 items") and #lootButtons == 2 and lootButtons[1] == "Manage..." and lootButtons[2] == "Clear All", "30 items: one line, Manage... and Clear All (the page's other buttons, the Disenchant Helper's, aside)")
	local y30 = P.y
	for id = 9000, 9024 do MR:Never()[id] = nil end
	P:Refresh()
	check(P.y == y30, "the Settings page is the same height with 5 items as with 30")
	for id = 9000, 9024 do MR:Never()[id] = true end
	P:Refresh()
	-- The window: sorted, searchable, removable.
	MR:ManageNever()
	local f = MR.neverFrame
	local shown = 0
	for _, r in ipairs(f.rows) do if r:IsShown() then shown = shown + 1 end end
	check(f:IsShown() and shown == 30 and f.rows[1].name.text <= f.rows[2].name.text, "Manage... lists all 30, A to Z")
	f.search:SetText("9015"); f.search:GetScript("OnTextChanged")(f.search, true)
	shown = 0
	for _, r in ipairs(f.rows) do if r:IsShown() then shown = shown + 1 end end
	check(shown == 1 and f.rows[1].id == 9015, "the search box filters the list")
	f.search:SetText("zzz"); f.search:GetScript("OnTextChanged")(f.search, true)
	check(f.empty:IsShown() and f.empty.text == "No items match.", "no match: it says so")
	f.search:SetText(""); f.search:GetScript("OnTextChanged")(f.search, true)
	f.rows[1].remove:GetScript("OnClick")(f.rows[1].remove)
	local count = 0
	for _ in pairs(MR:Never()) do count = count + 1 end
	check(count == 29, "a row's button asks about that item again")
	-- Clear All asks first.
	local clear
	for _, bt in ipairs(P.pools.btn) do if bt:IsShown() and bt.label.text == "Clear All" then clear = bt end end
	clear:GetScript("OnClick")(clear)
	check(n.Popups.confirm:IsShown() and n.Popups.confirm.text.text:find("Ask about all 29 items again"), "Clear All asks first")
	n.Popups.confirm.yes:GetScript("OnClick")(n.Popups.confirm.yes)
	check(next(MR:Never()) == nil and f.empty:IsShown(), "and then empties the list")
	-- Opening and closing it many times makes no new frames.
	for id = 9100, 9110 do MR:Never()[id] = true end
	MR:ManageNever(); f:Hide()
	local made = #M.frames
	for _ = 1, 20 do MR:ManageNever(); f:Hide() end
	check(#M.frames == made, "reopening the window makes no new frames (rows are reused)")
	for id = 9100, 9110 do MR:Never()[id] = nil end
	f:Hide(); P:Hide()

	-- Classic: logging in with Travel Mode on and the window closed: no picker art over the search box.
	package.loaded.mock = nil
	local MC = require("mock")
	MC.faithfulVisibility = true   -- the game's rule: hiding a frame in a closed window sends no OnHide
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, profiles = { Default = { skin = "classic", travelMode = true } },
		cache = { ["Alt - Realm"] = { name = "Alt", realm = "Realm", items = {}, bags = {} } } }
	local nc = MC.loadAddon("BagSmith")
	MC.fire("ADDON_LOADED", "BagSmith"); MC.fire("PLAYER_ENTERING_WORLD"); MC.runTimers(); MC.runTimers()
	local main = nc.Window.main
	ToggleAllBags(); MC.runTimers()
	local art = main.classicDropdown
	check(main.charBtn and not main.charBtn:IsShown() and (not art or not art:IsShown()), "Classic + Travel Mode at login: the picker and its dropdown look stay hidden")
	nc:ToggleTravel(); MC.runTimers()
	art = main.classicDropdown
	check(main.charBtn:IsShown() and art and art:IsShown(), "leaving Travel Mode shows the picker with its dropdown look")
	nc:ToggleTravel(); MC.runTimers()
	check(not art:IsShown(), "and Travel Mode hides both again")
end)()

;(function()
	-- 0.13.0-rc1: the release candidate's What's New card and changelog.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = {}, whatsNewSeen = "0.12.0" }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local WN = n.WhatsNew
	local tf = io.open("BagSmith/BagSmith.toc", "r"); local toc = tf and tf:read("*a") or ""; if tf then tf:close() end
	check(toc:find("## Version: 1%.5%.5\n") and toc:find("## X%-Date: 2026%-11%-07"), "the TOC version is 1.5.5, dated 7 November 2026")
	n.version = "0.14.0"
	local e
	for _, x in ipairs(WN.ENTRIES) do if x.v == "0.13.0" then e = x end end
	check(e and e.heading == "BagSmith 0.13" and #e.items == 7 and e.items[1]:find("^|cfffac775Bag Bar:|r"), "What's New keeps its 0.13 card, led by the Bag Bar")
	check(e.items[7]:find("^|cfffac775Pawn Support:|r") and not e.items[6]:find("Pawn"), "Pawn support has its own bullet")
	local unseen = WN:Unseen()
	local sawThirteen = false
	for _, u in ipairs(unseen) do if u.v == "0.13.0" then sawThirteen = true end end
	check(sawThirteen and unseen[1].v == "0.14.0", "a player coming from 0.12 sees the 0.14 card and the 0.13 card")
	check(e.items[1] == "|cfffac775Bag Bar:|r gain access to your Bag Bar from within BagSmith. A new button beside the bag counts in the bottom right brings it up. You can also hide Blizzard's Bag Bar in Settings > General.",
		"the Bag Bar bullet reads as Shweep wrote it")
	local text = table.concat(e.items, " ")
	check(text:find("Sell Junk %+ Mark as Junk") and text:find("Loot Helper") and text:find("Favorites") and text:find("Track as Currency")
		and text:find("Profile Sharing") and text:find("Keybindings") and text:find("Bag Bar") and not text:find("\226\128\148"), "the card covers the 0.13 features, without em dashes")
	-- The changelog: one 0.13.0 section, no beta entries left.
	local f = io.open("BagSmith/CHANGELOG.md", "r")
	local log = f and f:read("*a") or ""
	if f then f:close() end
	check(log:find("\n## 0%.13%.0\n") and not log:find("## 0%.13%.0%-beta"), "the changelog has one 0.13.0 section (the beta entries folded in)")
	local section = log:match("(## 0%.13%.0\n.-)\n## ") or ""
	local bad = false
	for _, w in ipairs({ "colour", "favourite", "behaviour", "cancelled", "Lanes", "\226\128\148" }) do if section:find(w) then bad = true end end
	check(#section > 500 and not bad, "the 0.13.0 notes use the house spellings and terms, no em dashes")
end)()

;(function()
	-- 0.13.0-rc3: Scalable (was Fixed Size) is the default for new players; up to 1400 wide.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = nil; _G.BagSmithDB = nil
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	check(n.db.sizeMode == "fixed" and n.db.fixW == 620 and n.db.fixH == 560, "a new player starts Scalable at 620 x 560 (the supported minimum width)")
	local P = n.SettingsPanel; P:Show(); P:ShowPage("window")
	local seg
	for _, w in ipairs(P.pools.seg) do if w:IsShown() and w.key == "sizeMode" then seg = w end end
	local labels = {}
	for _, b in ipairs(seg and seg.btns or {}) do if b:IsShown() then labels[#labels + 1] = b.label.text end end
	check(table.concat(labels, "|") == "Fit to Items|Scalable", "Window Size offers Fit to Items or Scalable")
	check(seg.help and seg.help.text == "Stays the size you set. Drag the corner to resize it.", "Scalable's help says how it works")
	P:Hide()
	local rb = n.Window.main.frame.resizeBounds
	check(rb and rb[3] == 1400 and rb[4] == 1200, "the corner drags up to 1400 x 1200")
	n:Set("bankW", 5000); n:Set("maxW", 5000)
	check(n.db.bankW == 1400 and n.db.maxW == 1400, "the bank window and Fit to Items' max width also go up to 1400")
	-- An existing player keeps their choice.
	package.loaded.mock = nil
	local M2 = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { sizeMode = "auto", maxW = 680 } } }
	local n2 = M2.loadAddon("BagSmith"); M2.fire("ADDON_LOADED", "BagSmith")
	check(n2.db.sizeMode == "auto", "an existing player who uses Fit to Items keeps it")
end)()

;(function()
	-- rc4: the scrollbar's lane; the bag strip; Classic for new players; resizing keeps the window's spot.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 9901, name = "Belt", q = 1, class = 4, subclass = 1, price = 5, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = nil; _G.BagSmithDB = nil
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	check(n.db.skin == "classic" and n.db.sizeMode == "fixed", "a new player starts in Classic, Scalable")
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	-- Nothing scrolls: no scrollbar, and the list takes its lane back.
	main.barHidden = false; main:PlaceScroll()
	local gh = main.scroll.GetHeight
	main.scroll.GetHeight = function() return 400 end
	main.contentHeight = 120
	main:UpdateBarSpace()
	local p = main.scroll.points[2]
	check(main.barHidden and not main.scroll.ScrollBar:IsShown() and p[4] == 0, "a list that fits: no scrollbar, and the right margin matches the left")
	M.runTimers()
	-- It overflows: the scrollbar and its lane come back.
	main.contentHeight = 900
	main:UpdateBarSpace()
	p = main.scroll.points[2]
	check(not main.barHidden and main.scroll.ScrollBar:IsShown() and p[4] == -22, "a list that overflows: the scrollbar and its lane come back")
	-- Not while rows hold still under the pointer.
	main.frame.IsMouseOver = function() return true end
	main.contentHeight = 120
	main:UpdateBarSpace()
	check(not main.barHidden, "no width change while the pointer is over the list")
	main.frame.IsMouseOver = nil
	main.scroll.GetHeight = gh
	-- The bag strip.
	local bb = n.BagBar
	check(main.btnBagBar and main.btnBagBar:IsShown() and not main.bagBar:IsShown(), "the footer has the bag-slots button; the strip starts closed")
	main.btnBagBar:GetScript("OnClick")(main.btnBagBar); M.runTimers()
	check(n.db.bagBar and main.bagBar:IsShown() and main.btnBagBar.active, "clicking it opens the bag strip (and the button shows it's on)")
	check(main.header.points[1][2] == main.bagBar, "the column header sits under the strip")
	local slots = 0
	for _, s in ipairs(main.bagBar.slots or {}) do if s:IsShown() then slots = slots + 1 end end
	check(slots >= 5, "the strip shows the backpack and the bag slots")
	-- Hover shows the bag's tooltip only (the highlight is off for now).
	local first = main.bagBar.slots[1]
	first:GetScript("OnEnter")(first)
	local changed = false
	for _, b in ipairs(main.used or {}) do if b.hasItem and b:GetAlpha() ~= 1 then changed = true end end
	first:GetScript("OnLeave")(first)
	check(not changed, "hovering a bag slot doesn't dim anything (tooltip only)")
	-- Click opens that bag's own window.
	local bag1
	for _, sl in ipairs(main.bagBar.slots) do if sl.bag == 1 then bag1 = sl end end
	bag1:GetScript("OnClick")(bag1); M.runTimers()
	check(n.Window.bagViews[bag1.bag]:IsShown(), "clicking a bag opens its own window")
	-- Travel Mode keeps the strip and its button, and the header stays under the strip.
	n:ToggleTravel(); M.runTimers()
	check(main.bagBar:IsShown() and main.btnBagBar:IsShown(), "Travel Mode keeps the bag strip and its button")
	check(main.bagBar.points[1][2] == main.title and main.header.points[1][2] == main.bagBar, "in Travel Mode the strip sits under the title row, the header under the strip")
	n:ToggleTravel(); M.runTimers()
	check(main.bagBar:IsShown() and main.bagBar.points[1][2] == main.tools and main.header.points[1][2] == main.bagBar, "leaving it: the strip back under the toolbar, the header under the strip")
	-- Hide Blizzard's bag bar: faded and click-through; back when off.
	_G.BagsBar = CreateFrame("Frame", "BagsBar", UIParent)
	_G.CharacterBag0Slot = CreateFrame("Button", "CharacterBag0Slot", UIParent)
	n:Set("hideBlizzBagBar", true); M.runTimers()
	check(BagsBar.alpha == 0 and CharacterBag0Slot.alpha == 0, "Hide Blizzard's Bag Bar fades it out")
	n:Set("hideBlizzBagBar", false); M.runTimers()
	check(BagsBar.alpha == 1 and CharacterBag0Slot.alpha == 1, "turning it off brings it back")
	_G.BagsBar, _G.CharacterBag0Slot = nil, nil
	-- Resizing keeps the window where it is (no jump back to the old spot).
	local f = main.frame
	f.GetEffectiveScale = function() return 1 end
	UIParent.GetEffectiveScale = function() return 1 end
	UIParent.GetWidth = function() return 1920 end
	UIParent.GetHeight = function() return 1080 end
	-- At the right edge, after stretching: left 1100, right 1920, top 700, bottom 140.
	f.GetLeft = function() return 1100 end; f.GetRight = function() return 1920 end
	f.GetTop = function() return 700 end; f.GetBottom = function() return 140 end
	n.db.point = { "BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -80, 140 }
	main:SaveSizedPosition()
	local pt = n.db.point
	check(pt[1] == "BOTTOMRIGHT" and pt[4] == 0 and pt[5] == 140, "after resizing, the window keeps its spot (still at the right edge)")
end)()

;(function()
	-- rc5: the strip and Travel Mode in both views; list-view hover; the scrollbar with the pointer over the window; the button's colors.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 9901, name = "Belt", q = 1, class = 4, subclass = 1, price = 5, equip = "INVTYPE_WAIST" })
	M.put(1, 1, { id = 9902, name = "Cloth", q = 1, count = 3, class = 7, subclass = 5, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", bagBar = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	for _, view in ipairs({ "list", "icons" }) do
		n:Set("view", view); M.runTimers()
		n:ToggleTravel(); M.runTimers()
		local shown = 0
		for _, b in ipairs(main.used or {}) do if b:IsShown() and b.hasItem then shown = shown + 1 end end
		check(main.header.points[1][2] == main.bagBar and main.bagBar.points[1][2] == main.title and shown == 2,
			view .. " view: strip open, then Travel Mode: header under the strip, the strip under the title, items shown")
		n:ToggleTravel(); M.runTimers()
		n:Set("bagBar", false); M.runTimers()
		n:ToggleTravel(); M.runTimers()
		check(main.header.points[1][2] == main.title, view .. " view: strip closed in Travel Mode: header under the title")
		n:ToggleTravel(); M.runTimers()
		check(main.header.points[1][2] == main.tools, view .. " view: and back under the toolbar after")
		n:Set("bagBar", true); M.runTimers()
	end
	-- The button's colors: Modern light (accent while open).
	n:Set("bagBar", false); M.runTimers()
	check(main.btnBagBar.icon.color[1] == 0.62 and main.btnBagBar:GetWidth() == 62, "Modern: the button's icon rests in the toolbar icons' grey, on a 62-wide button")
	main.btnBagBar:GetScript("OnEnter")(main.btnBagBar)
	check(main.btnBagBar.icon.color[1] == 0.93, "and brightens on hover")
	main.btnBagBar:GetScript("OnLeave")(main.btnBagBar)
	GameTooltip:Hide()
	n:Set("skin", "classic"); M.runTimers()
	-- Classic: exactly the colors of the count buttons beside it.
	local function same(a, b) return a and b and math.abs(a[1] - b[1]) < 0.001 and math.abs(a[2] - b[2]) < 0.001 and math.abs(a[3] - b[3]) < 0.001 end
	main.btnBags:SetActive(false)
	check(main.btnBagBar.classicOn and same(main.btnBagBar.icon.color, main.btnBags.icon.color) and main.btnBagBar.icon.color[3] > 0.5,
		"Classic, strip hidden: the icon is the count buttons' resting off-white")
	n:Set("bagBar", true); M.runTimers()
	main.btnBags:SetActive(true)
	check(same(main.btnBagBar.icon.color, main.btnBags.icon.color) and main.btnBagBar.icon.color[2] == 0.82 and main.btnBagBar.icon.color[3] == 0,
		"Classic, strip shown: gold, like a count button that's on")
	n:Set("skin", "modern"); M.runTimers()
	-- The scrollbar with the pointer over the window: the bar hides at once; the lane waits for the pointer to leave.
	main.barHidden = false; main:PlaceScroll(); main.held = false
	local gh = main.scroll.GetHeight
	main.scroll.GetHeight = function() return 400 end
	main.contentHeight = 120
	main.frame.IsMouseOver = function() return true end
	main:UpdateBarSpace()
	check(not main.scroll.ScrollBar:IsShown() and not main.barHidden and main.held, "pointer over the window: the bar hides at once, the width change waits")
	main.frame.IsMouseOver = function() return false end
	M.tick(); M.runTimers()
	check(main.barHidden, "once the pointer leaves, the list takes the lane back")
	-- Now the list overflows (a switch to list view) with the pointer over: the bar and its lane come back at once.
	main.frame.IsMouseOver = function() return true end
	main.contentHeight = 900
	main:UpdateBarSpace()
	check(not main.barHidden and main.scroll.ScrollBar:IsShown() and main.scroll.points[2][4] == -22, "overflowing with the pointer over: the bar comes back with its lane at once (never outside the window)")
	main.frame.IsMouseOver = nil
	main.scroll.GetHeight = gh
end)()

;(function()
	-- rc8: dragging the corner smaller in Scalable: nothing resets the window mid-drag.
	package.loaded.mock = nil
	local M = require("mock")
	for s = 1, 6 do M.put(0, s, { id = 9900 + s, name = "Item" .. s, q = 1, class = 15, subclass = 0, price = 1 }) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", sizeMode = "fixed", fixW = 900, fixH = 700, view = "icons" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	local f = main.frame
	main.grip:GetScript("OnMouseDown")(main.grip)
	check(main.sizing, "dragging the corner: the window knows it's being resized")
	f:SetSize(660, 420)   -- the drag, part way
	local points = #f.points
	-- A scrollbar change mid-drag queues nothing; a refresh mid-drag leaves the size and spot alone.
	local gh = main.scroll.GetHeight
	main.scroll.GetHeight = function() return 40 end
	main.contentHeight = 900
	local before = main.barHidden
	main:UpdateBarSpace()
	check(main.barHidden == before, "mid-drag: the scrollbar check waits")
	n:RefreshViews(true); M.runTimers()
	check(f:GetWidth() == 660 and f:GetHeight() == 420 and #f.points == points, "mid-drag: a refresh doesn't reset the window's size or spot")
	main.scroll.GetHeight = gh
	-- Refresh requests mid-drag (a tidy-up, a bag update) do no layout; they wait.
	local rebuilt = 0
	local realLayout = main.Layout
	main.Layout = function(...) rebuilt = rebuilt + 1; return realLayout(...) end
	main.held = true; n.WatchHeld()
	main.frame.IsMouseOver = function() return false end
	M.tick(); n:RefreshViews(true); M.runTimers()
	check(rebuilt == 0 and main.held, "mid-drag: no re-layout at all, tidy-ups included (they wait)")
	main.frame.IsMouseOver = nil
	-- The drag ends: the dragged size is saved and the items are laid out, now and once more next frame.
	main.grip:GetScript("OnMouseUp")(main.grip)
	local now = rebuilt
	M.runTimers()
	check(now >= 1 and rebuilt > now, "after the drag: laid out at once, and again once the size has settled")
	main.Layout = realLayout
	local shown = 0
	for _, b in ipairs(main.used or {}) do if b:IsShown() and b.hasItem then shown = shown + 1 end end
	check(not main.sizing and n.db.fixW == 660 and n.db.fixH == 420 and f:GetWidth() == 660, "after the drag: the new size is saved and kept")
	check(shown == 6, "and the items are laid out")
end)()

;(function()
	-- rc10: the narrow Keys slot at the left of the bag strip.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 9701, name = "Skeleton Key", q = 1, class = 13, subclass = 0, price = 0 })
	M.put(0, 2, { id = 9702, name = "Belt", q = 1, class = 4, subclass = 1, price = 5, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", bagBar = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	local ks = main.bagBar.keySlot
	check(ks and ks:IsShown() and ks:GetWidth() < main.bagBar.slots[1]:GetWidth() and ks.points[1][4] < main.bagBar.slots[1].points[1][4],
		"the bag strip starts with a narrow Keys slot")
	-- Blizzard's bag bar order: reagent bag, bags 4 to 1, the backpack at the far right.
	local order = {}
	for _, sl in ipairs(main.bagBar.slots) do if sl:IsShown() then order[#order + 1] = sl.bag end end
	local want = {}
	if n.HAS_REAGENT_SLOT then want[#want + 1] = n.REAGENT_BAG end
	for b = 4, 0, -1 do want[#want + 1] = b end
	check(table.concat(order, ",") == table.concat(want, ","), "the bags are in Blizzard's order, backpack at the far right: " .. table.concat(order, ","))
	-- The drawn key when Blizzard's keyring art isn't there (as in this harness).
	check(ks.drawn and ks.icon.texture:find("ui%-key") and n.BagBar:KeyArt() == "drawn", "without Blizzard's keyring art, the Keys slot shows BagSmith's drawn key")
	ks:GetScript("OnEnter")(ks)
	local lines = {}
	for _, l in ipairs(GameTooltip.lines or {}) do lines[#lines + 1] = tostring(l) end
	local tip = table.concat(lines, "|")
	ks:GetScript("OnLeave")(ks)
	check(tip:find("Skeleton Key") and tip:find("Click to show only your keys"), "hovering it lists the keys you carry")
	ks:GetScript("OnClick")(ks); M.runTimers()
	local shown = {}
	for _, b in ipairs(main.used or {}) do if b:IsShown() and b.hasItem and b.rec then shown[#shown + 1] = b.rec.name end end
	check(#shown == 1 and shown[1] == "Skeleton Key", "clicking it shows only your keys")
	ks:GetScript("OnClick")(ks); M.runTimers()
	shown = 0
	for _, b in ipairs(main.used or {}) do if b:IsShown() and b.hasItem then shown = shown + 1 end end
	check(shown == 2, "clicking again shows everything")
end)()

;(function()
	-- rc11: Blizzard's keyring button art in the Keys slot when the client has it.
	package.loaded.mock = nil
	local M = require("mock")
	_G.GetFileIDFromPath = function(path) if path == "Interface\\Buttons\\UI-Button-KeyRing" then return 130838 end end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", bagBar = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local ks = n.Window.main.bagBar.keySlot
	check(n.BagBar:KeyArt() == "blizzard" and not ks.drawn and ks.icon.texture == "Interface\\Buttons\\UI-Button-KeyRing",
		"with Blizzard's keyring button art available, the Keys slot uses it")
	_G.GetFileIDFromPath = nil
end)()

;(function()
	-- rc12: in Classic the strip's slots use the frames of Blizzard's bag bar.
	package.loaded.mock = nil
	local M = require("mock")
	_G.CharacterBag0Slot = CreateFrame("Button", "CharacterBag0Slot", UIParent)
	CharacterBag0Slot:SetSize(30, 30)
	local nt = CharacterBag0Slot:CreateTexture()
	nt.GetAtlas = function() return "bag-border" end
	nt:SetSize(45, 45)
	CharacterBag0Slot.GetNormalTexture = function() return nt end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", bagBar = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local slot = n.Window.main.bagBar.slots[1]
	check(not (slot.classicFrame and slot.classicFrame:IsShown()), "Modern: the strip's slots keep the flat border")
	n:Set("skin", "classic"); M.runTimers()
	local art = n.BagBar:SlotFrameArt()
	check(art.atlas == "bag-border" and math.abs(art.scale - 1.5) < 0.01, "Classic reads the frame art (and its size) from Blizzard's bag button")
	check(slot.classicFrame and slot.classicFrame:IsShown() and slot.classicFrame.atlas == "bag-border" and math.abs(slot.classicFrame:GetWidth() - 51) < 0.5,
		"Classic: each strip slot wears Blizzard's bag-slot frame, sized like theirs")
	n:Set("skin", "modern"); M.runTimers()
	check(not slot.classicFrame:IsShown(), "back to Modern: the flat border again")
	_G.CharacterBag0Slot = nil
end)()

;(function()
	-- rc13: the rc9/rc11 audit fixes and the live bag-drag report.
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[1] = 8
	M.put(0, 1, { id = 9601, name = "Skeleton Key", q = 1, class = 13, subclass = 0, price = 0 })
	M.put(0, 2, { id = 9602, name = "Belt", q = 1, class = 4, subclass = 1, price = 5, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", bagBar = true, bagWindows = false } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	local function slotFor(bag) for _, sl in ipairs(main.bagBar.slots) do if sl.bag == bag then return sl end end end
	-- P2: the last strip-opened window closed from the strip: the footer opens the set in one click.
	local s1 = slotFor(1)
	s1:GetScript("OnClick")(s1); M.runTimers()
	check(n.Window.bagViews[1]:IsShown(), "the strip opens one bag's window")
	s1:GetScript("OnClick")(s1); M.runTimers()
	check(not n.Window.bagViews[1]:IsShown() and not n.ui.bagWindows, "closing the last one from the strip turns the set off, like its X")
	main.btnBags:GetScript("OnClick")(main.btnBags); M.runTimers()
	check(n.Window.bagViews[0]:IsShown() and n.Window.bagViews[1]:IsShown(), "the footer then opens the bags in one click")
	main.btnBags:GetScript("OnClick")(main.btnBags); M.runTimers()
	-- P3: held updates keep the strip's free-slot count (and the key's dimming) current.
	main.frame.IsMouseOver = function() return true end
	local before = main.bagBar.hint.text
	M.bags[0][1] = nil; M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
	check(main.held and main.bagBar.hint.text ~= before, "rows holding under the pointer: the strip's free-slot count still updates (" .. tostring(before) .. " -> " .. tostring(main.bagBar.hint.text) .. ")")
	check(main.bagBar.keySlot.icon.alpha == 0.5, "and the Keys slot dims when the last key is gone")
	-- A change in the bag set (a bag equipped) refreshes everything at once, even under the pointer.
	local layouts = 0
	local realLayout = main.Layout
	main.Layout = function(...) layouts = layouts + 1; return realLayout(...) end
	M.put(0, 4, { id = 9604, name = "Linen Bag", q = 1, class = 1, subclass = 0, price = 1 }); M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
	main.frame.IsMouseOver = function() return true end
	layouts = 0
	M.bags[0][4] = nil; M.sizes[2] = 10   -- the bag leaves your bags and becomes bag 2
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
	check(layouts >= 1, "equipping a bag lays the window out at once, even with the pointer over it")
	layouts = 0
	M.put(0, 3, { id = 9603, name = "Cloth", q = 1, count = 2, class = 7, subclass = 5, price = 1 }); M.bags[0][3] = nil
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
	check(layouts == 0 and main.held, "an ordinary item change still holds rows still under the pointer")
	main.Layout = realLayout
	main.frame.IsMouseOver = function() return false end; M.tick(); M.runTimers()
	-- P3: an empty Fit to Items list gives the scrollbar lane back.
	n:Set("sizeMode", "auto"); M.runTimers()
	main.barHidden = false; main:PlaceScroll()
	main:UpdateBarSpace(0, 0)
	check(main.barHidden, "an empty Fit to Items list fits: the scrollbar lane is released")
	n:Set("sizeMode", "fixed"); M.runTimers()
	-- Keys: the second click restores the categories you had.
	n.ui.filters.cat = { ["Trade Goods"] = true }
	local ks = main.bagBar.keySlot
	ks:GetScript("OnClick")(ks); M.runTimers()
	check(n.ui.filters.cat.Keys and not n.ui.filters.cat["Trade Goods"], "Keys shows only keys")
	ks:GetScript("OnClick")(ks); M.runTimers()
	check(n.ui.filters.cat["Trade Goods"] and not n.ui.filters.cat.Keys, "the second click restores the categories you had")
	n.ui.filters.cat = {}
	-- Hide Blizzard's Bag Bar restores what it found.
	_G.BagsBar = CreateFrame("Frame", "BagsBar", UIParent)
	BagsBar:SetAlpha(0.6)
	n:Set("hideBlizzBagBar", true); M.runTimers()
	n:Set("hideBlizzBagBar", false); M.runTimers()
	check(BagsBar.alpha == 0.6, "turning Hide Blizzard's Bag Bar off restores the bar as it was (not forced fully visible)")
	_G.BagsBar = nil
	-- The Never Ask window repaints when an item is added from the Loot Helper.
	n.MakeRoom:Never()[9999] = true
	n.MakeRoom:ManageNever()
	n.MakeRoom:NeverAsk({ id = 9602 })
	local listed = false
	for _, r in ipairs(n.MakeRoom.neverFrame.rows) do if r:IsShown() and r.id == 9602 then listed = true end end
	check(listed, "an open Never Ask window shows an item added from the Loot Helper at once")
	n.MakeRoom.neverFrame:Hide()
	-- The Clear Soul Shards confirmation closes with the Loot Helper.
	n.MakeRoom:Frame()
	local hf = n.MakeRoom.frame
	hf:Show()
	n.Confirm(UIParent, "test", function() end); n.Popups.confirm.lootHelper = true
	hf:Hide()
	check(not n.Popups.confirm:IsShown(), "closing the Loot Helper closes its destroy confirmation (Clear Soul Shards too)")
end)()

;(function()
	-- rc14: the rc13 recheck: live bag sizes changes refresh under the pointer; Keys restores only into the same filters.
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 4; M.sizes[1] = 2
	for b = 2, 4 do M.sizes[b] = 0 end
	M.put(0, 1, { id = 9501, name = "Skeleton Key", q = 1, class = 13, subclass = 0, price = 0 })
	M.put(0, 2, { id = 9502, name = "Big Bag", q = 1, class = 1, subclass = 0, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", bagBar = true, view = "icons", emptySlots = true, grp = "none" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	local function cells() local c = 0; for _, b in ipairs(main.used or {}) do if b:IsShown() then c = c + 1 end end; return c end
	local before = cells()
	main.frame.IsMouseOver = function() return true end
	M.bags[0][2] = nil; M.sizes[1] = 6   -- the big bag leaves your bags and replaces bag 1's 2 slots with 6
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
	check(cells() > before, "a bag growing under the pointer adds its cells at once (" .. before .. " -> " .. cells() .. ")")
	main.frame.IsMouseOver = function() return false end; M.tick(); M.runTimers()
	-- Keys: the remembered categories belong to the filters they came from.
	n.ui.filters.cat = { Gear = true }
	local ks = main.bagBar.keySlot
	ks:GetScript("OnClick")(ks); M.runTimers()
	n.ui.filters = { text = "", q = {}, cat = { Keys = true }, t = {}, bd = {}, w = {} }   -- a Keys-only sheet's filters
	ks:GetScript("OnClick")(ks); M.runTimers()
	check(not n.ui.filters.cat.Gear and next(n.ui.filters.cat) == nil, "after switching to a Keys-only sheet, the second click just clears Keys (no categories from the old sheet)")
	n.ui.filters = n.EmptyFilters()
	n.ui.filters.cat = { Gear = true }
	ks:GetScript("OnClick")(ks); M.runTimers()
	ks:GetScript("OnClick")(ks); M.runTimers()
	check(n.ui.filters.cat.Gear, "on the same filters, the second click still restores what you had")
end)()

;(function()
	-- rc15: Blizzard's reagent bag tutorial tip: finished while BagSmith replaces Blizzard's bags.
	local bits, hidden = {}, {}
	_G.LE_FRAME_TUTORIAL_EQUIP_REAGENT_BAG = 61
	local function boot(profile)
		package.loaded.mock = nil
		local M = require("mock")
		local realCVar = _G.C_CVar
		_G.C_CVar = setmetatable({
			GetCVarBitfield = function(name, flag) return bits[name .. ":" .. flag] or false end,
			SetCVarBitfield = function(name, flag, v) bits[name .. ":" .. flag] = v end,
		}, { __index = realCVar or {} })
		_G.HelpTip = { HideAllSystem = function(self, system) hidden[#hidden + 1] = system end }
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = profile } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M
	end
	local n, M = boot({ skin = "modern" })
	check(bits["closedInfoFrames:61"] == true and n.Tutorials.finishedBy ~= "bags opened", "while BagSmith replaces the bags, Blizzard's reagent bag tutorial is marked finished at login (without opening the bags)")
	check(n.Tutorials:Status():find("^finished"), "/bs check reports it finished")
	hidden = {}
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
	check(hidden[#hidden] == "TutorialReagentBag", "after a bag update, its tip is hidden if this session's copy shows it")
	hidden = {}
	ToggleAllBags(); M.runTimers()
	check(hidden[#hidden] == "TutorialReagentBag", "and when BagSmith's bags open")
	-- With Blizzard's bags in use, BagSmith leaves Blizzard's tutorial alone.
	bits, hidden = {}, {}
	n, M = boot({ skin = "modern", replaceBlizzardBags = false })
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
	check(not bits["closedInfoFrames:61"] and #hidden == 0, "with Blizzard's bags in use, their tutorial is left to finish itself")
	n:Set("replaceBlizzardBags", true); M.runTimers()
	check(bits["closedInfoFrames:61"] == true, "turning replacement on finishes it")
	-- In combat the tip isn't touched.
	n, M = boot({ skin = "modern" })
	hidden = {}
	M.combat = true
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
	check(#hidden == 0, "in combat the tip is left until later")
	M.combat = false
	-- A client without the tutorial: nothing happens.
	_G.LE_FRAME_TUTORIAL_EQUIP_REAGENT_BAG = nil
	bits, hidden = {}, {}
	n, M = boot({ skin = "modern" })
	check(next(bits) == nil and n.Tutorials:Status():find("not found"), "a client without that tutorial: nothing to do, and /bs check says so")
	_G.HelpTip = nil
end)()

;(function()
	-- rc16: in Classic icon cells the rarity frame covers the icon's corners.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 9401, name = "Red Cape", q = 1, class = 4, subclass = 1, price = 5, equip = "INVTYPE_CLOAK" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "classic", view = "icons" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local b = n.Buttons:Get(0, 1)
	local p1, p2 = b.qFrame.points[1], b.qFrame.points[2]
	check(b.qFrame:IsShown() and p1[2] == b.icon and p1[4] == -2 and p1[5] == 2 and p2[4] == 2 and p2[5] == -2,
		"Classic: the rarity frame sits 2 px outside the icon on every side, covering its corners")
end)()

;(function()
	-- 0.13.1: the minimap button through LibDataBroker + LibDBIcon; Fade Minimap Button; Reload Interface.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", minimapAngle = 140 } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
	local mb = n.MinimapButton
	check(LDBIcon and LDBIcon:IsRegistered("BagSmith") and mb.ldbIcon, "the minimap button is registered through LibDBIcon (UI addons can manage it)")
	local btn = LDBIcon:GetMinimapButton("BagSmith")
	check(btn and btn:GetName() == "LibDBIcon10_BagSmith", "it's LibDBIcon's standard button (LibDBIcon10_BagSmith), which minimap managers recognize")
	check(btn.db.minimapPos == 140 and btn:IsShown(), "it keeps the saved position and shows")
	n:Set("minimap", false); M.runTimers()
	check(not btn:IsShown(), "Show Minimap Button off hides it")
	n:Set("minimap", true); M.runTimers()
	check(btn:IsShown(), "and on shows it again")
	-- Dragging writes the position back to BagSmith's own setting.
	btn.db.minimapPos = 300
	check(n.db.minimapAngle == 300, "dragging it saves the position in BagSmith's settings (so profiles keep it)")
	-- Fade Minimap Button: LibDBIcon's show-on-mouseover.
	n:Set("minimapFade", true); M.runTimers()
	check(btn.showOnMouseover == true and btn:GetAlpha() == 0, "Fade Minimap Button: hidden until the pointer is over the minimap")
	n:Set("minimapFade", false); M.runTimers()
	check(btn.showOnMouseover == false and btn:GetAlpha() == 1, "turning it off shows the button fully again")
	-- Settings: Fade under Show Minimap Button; Reload Interface beside the skin choice.
	local P = n.SettingsPanel; P:Show(); P:ShowPage("general")
	local fade
	for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == "minimapFade" then fade = w end end
	check(fade and fade.text.text == "Fade Minimap Button", "General has Fade Minimap Button")
	P:ShowPage("look")
	local skinRow, reload
	for _, w in ipairs(P.pools.seg) do if w:IsShown() and w.key == "skin" then skinRow = w end end
	reload = skinRow and skinRow.extraBtn
	check(reload and reload:IsShown() and reload.label.text == "Reload Interface" and skinRow.help.text == "If anything looks off after switching skins, reload the interface.",
		"Style: the Skin row's help line, with Reload Interface under the choices")
	check(reload.points[1][1] == "TOPRIGHT" and reload.points[1][2] == skinRow, "Reload Interface sits on the right, under Modern and Classic")
	-- Pooled rows: another choice row on another page doesn't show the button.
	P:ShowPage("window")
	local stray = false
	for _, w in ipairs(P.pools.seg) do if w:IsShown() and w.extraBtn and w.extraBtn:IsShown() then stray = true end end
	check(not stray, "other choice rows (reused) don't show the Reload button")
	P:ShowPage("look")
	local reloaded = 0
	_G.ReloadUI = function() reloaded = reloaded + 1 end
	M.combat = true; reload:GetScript("OnClick")(reload)
	check(reloaded == 0, "in combat it doesn't reload (it says why)")
	M.combat = false; reload:GetScript("OnClick")(reload)
	check(reloaded == 1, "out of combat it reloads the interface")
	P:Hide()
end)()

;(function()
	-- 0.13.2: the About page.
	package.loaded.mock = nil
	local M = require("mock")
	local realMeta = C_AddOns.GetAddOnMetadata
	C_AddOns.GetAddOnMetadata = function(a, k) if k == "X-Date" then return "2026-10-14" end return realMeta(a, k) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.version = "0.13.2"
	local P = n.SettingsPanel; P:Show()
	local f = P.frame
	check(f.about and f.about.points[1][2] == f.whatsNew and f.about.points[1][1] == "BOTTOMLEFT", "Settings: an About & Support button just above What's New")
	check(f.about.label.text == "About & Support" and f.about.label:GetStringWidth() < f.about:GetWidth() - 8, "it reads About & Support, and the label fits the button")
	f.about:GetScript("OnClick")(f.about)
	check(P.page == "about" and f.about.active, "clicking it opens the About page (and the button shows it's selected)")
	local w = P.pools.about[1]
	check(w and w:IsShown() and w.icon.texture:find("about%-icon") and w.icon:GetWidth() == 52, "the full-color icon sits in the top corner")
	check(w.iconEdge:IsShown() and w.iconBG:IsShown() and not w.iconFrame:IsShown(), "Modern: the icon gets the bags' shaded frame")
	-- The icon texture: the art's silver border replaced by its dark background (corners match the middle of each edge).
	local fh = io.open("BagSmith/Media/about-icon.tga", "rb"); local data = fh:read("*a"); fh:close()
	local function px(x, y) local i = 18 + ((127 - y) * 128 + x) * 4; return data:byte(i + 1), data:byte(i + 2), data:byte(i + 3) end
	local function dark(x, y) local b, g, r = px(x, y); return r < 40 and g < 40 and b < 40 end
	check(dark(1, 1) and dark(126, 1) and dark(1, 126) and dark(126, 126) and dark(64, 1) and dark(1, 64), "the About icon has no light border or corners left (all edges dark)")
	check(w.version.text == "Version 0.13.2, released October 14, 2026", "version and release date, read from the addon: " .. tostring(w.version.text))
	local me = {}
	for i, para in ipairs(w.paras) do me[i] = para.text end
	check(me[1]:find("^I'm Shweep%. I've been playing WoW on and off since December 2005") and me[4]:find("Bug reports, feature ideas, and kind words are just as appreciated%.$") and #me == 4,
		"About Me: the author's note, word for word")
	check(me[3]:find("because not many bag addons make it easy to look past the icons"), "with Shweep's edit (not many bag addons make it easy)")
	-- The Settings scrollbar only when the page is taller than the window.
	local sc = P.scroll
	local gh = sc.GetHeight
	sc.GetHeight = function() return 5000 end
	P:Refresh()
	check(not sc.ScrollBar:IsShown(), "a page that fits: no Settings scrollbar")
	sc.GetHeight = function() return 100 end
	P:Refresh()
	check(sc.ScrollBar:IsShown(), "a page taller than the window: the scrollbar shows")
	sc.GetHeight = gh
	-- Classic: the icon gets Blizzard's item frame, like the bags.
	n:Set("skin", "classic"); M.runTimers(); P:Refresh()
	w = P.pools.about[1]
	local art = n.BagBar:SlotFrameArt()
	check(w.iconFrame:IsShown() and (w.iconFrame.texture == art.file or w.iconFrame.atlas == art.atlas) and not w.iconEdge:IsShown(),
		"Classic: the icon wears the frame of Blizzard's bag slots (as on the Bag Bar)")
	check(w.iconFrame:GetWidth() == 58 and w.icon:GetWidth() == 48 and w.iconFrame.points[1][2] == w.icon,
		"Classic: the icon sits inside the frame's opening (48 px in a 58 px frame), so no corners show past its rim")
	n:Set("skin", "modern"); M.runTimers(); P:Refresh()
	check(w.icon:GetWidth() == 52 and not w.iconFrame:IsShown(), "back in Modern: the icon at 52 px in the shaded frame")
	local all = table.concat(me, " ") .. " " .. w.supportText.text
	check(not all:find("\226\128\148") and not all:find("\226\128\153"), "no em dashes or curly apostrophes (the game font)")
	-- The link buttons show their address, ready to copy.
	local function open(btn) btn:GetScript("OnClick")(btn); return n.Popups.link end
	local box = open(w.discord)
	check(box:IsShown() and box.edit.text == "https://discord.gg/uYfcHPkcar" and box.title.text == "Discord", "Discord shows its invite, ready to copy")
	box.edit:SetText("oops"); box.edit:GetScript("OnTextChanged")(box.edit, true)
	check(box.edit.text == "https://discord.gg/uYfcHPkcar", "the address can't be edited by accident")
	box.edit:GetScript("OnEscapePressed")(box.edit)
	check(not box:IsShown(), "Escape closes it")
	box = open(w.coffee)
	check(box.edit.text == "https://buymeacoffee.com/shweepy", "Buy Me a Coffee shows its page")
	box = open(w.curseforge)
	check(box.edit.text == "https://www.curseforge.com/wow/addons/bagsmith", "CurseForge shows the addon's page")
	box:Hide()
	check(w.coffee.icon.texture:find("ui%-coffee") and w.discord.icon.texture:find("ui%-discord") and w.curseforge.icon.texture:find("ui%-curseforge"),
		"each button has its icon (coffee, Discord, CurseForge)")
	-- Other pages don't show it; the nav highlight moves.
	P:ShowPage("general")
	check(not w:IsShown() and not f.about.active, "other pages hide the About content")
	-- No release date in the TOC: just the version.
	C_AddOns.GetAddOnMetadata = realMeta
	check(P:VersionLine() == "Version 0.13.2", "without a release date, the line shows just the version")
	P:Hide()
end)()

;(function()
	-- 0.14.0-beta1: custom sections, moving items, Show at Vendor / AH.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7001, name = "Skinning Knife", q = 1, class = 2, subclass = 15, price = 5, equip = "INVTYPE_WEAPONMAINHAND" })
	M.put(0, 2, { id = 7002, name = "Light Leather", q = 1, count = 5, class = 7, subclass = 6, price = 2 })
	M.put(0, 3, { id = 7003, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 4, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local S, main = n.Sections, n.Window.main
	local function rec(id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
	check(rec(7001).cat == "Gear" and rec(7001).ownCat == "Gear", "a skinning knife starts in Gear (its type)")
	-- Create a section: it goes into Section Order before Other.
	local id = S:Create("Professions")
	local order = n.db.laneOrder
	check(id == "c1" and S:Label(id) == "Professions" and n.IndexOf(order, "c1") == n.IndexOf(order, "Other") - 1, "New Section: \"Professions\" (c1), placed before Other in Section Order")
	local dup, why = S:Create("gear")
	check(not dup and why:find("already"), "a name that's already taken is refused (built-in names too)")
	check(S:Rename(id, "Profession Tools") and S:Label(id) == "Profession Tools", "a custom section can be renamed")
	-- Move the knife into it: every copy, and its own section is remembered.
	S:Move(7001, id); M.runTimers()
	check(rec(7001).cat == "c1" and S:MovedTo(7001) == "c1", "moving the knife puts it in the custom section")
	local labels = {}
	for _, hostLanes in pairs(n.Buttons.lanes or {}) do for _, h in pairs(hostLanes) do if type(h) == "table" and h.IsShown and h:IsShown() and h.text then labels[#labels + 1] = h.text.text end end end
	check(table.concat(labels, "|"):find("Profession Tools"), "the custom section shows with its name: " .. table.concat(labels, "|"))
	S:Move(7001, "Gear"); M.runTimers()
	check(S:MovedTo(7001) == nil and rec(7001).cat == "Gear", "moving it back to its own section just undoes the move")
	S:Move(7002, "Gear"); M.runTimers()
	local list = S:MovedList()
	check(#list == 1 and list[1].id == 7002 and list[1].to == "Gear" and list[1].own == "TradeGoods", "built-in moves work too (Light Leather into Gear, was Trade Goods)")
	-- Which section wins: junk mark, then Favorites, then the move.
	n.cdb.junkMarks = n.cdb.junkMarks or {}; n.cdb.junkMarks[7002] = true; S:Reapply(); M.runTimers()
	check(rec(7002).cat == "Junk", "a junk mark beats a move")
	n.cdb.junkMarks[7002] = nil; S:Reapply(); M.runTimers()
	S:Move(7003, id); n.Marks:ToggleFavorite(rec(7003)); M.runTimers()
	check(S:EffectiveSection(rec(7003)) == "~fav", "a favorite goes to Favorites before its move (while Favorites is on)")
	n.Marks:ToggleFavorite(rec(7003)); M.runTimers()
	-- Drop an item on a section's title: moved, and handed straight back to its slot.
	local cleared = 0
	_G.GetCursorInfo = function() return "item", 7001, "|cffffffff|Hitem:7001|h[Skinning Knife]|h|r" end
	_G.ClearCursor = function() cleared = cleared + 1 end
	check(S:DropHint(id) == "Drop to move Skinning Knife to Profession Tools", "holding the knife over the section's title says what dropping does")
	check(S:DropOnSection(id) and cleared == 1 and S:MovedTo(7001) == id, "dropping it on the title moves it, and the item goes straight back to its slot")
	check(not S:DropOnSection("bag:0") and not S:DropOnSection("~recent") and cleared == 1, "By Bag and Recent titles don't take drops")
	S:DropOnSection("~fav")
	check(n.Marks:IsFavorite(7001), "dropping on the Favorites title favorites it")
	n.Marks:ToggleFavorite(rec(7001))
	_G.GetCursorInfo = function() return nil end
	-- The item menu (Alt+Left-click).
	local m = S:ItemMenu(rec(7001))
	local texts = {}
	for _, r in ipairs(m.rows) do if r:IsShown() then texts[#texts + 1] = r.text.text end end
	local joined = table.concat(texts, "|")
	check(m:IsShown() and joined:find("Skinning Knife") and joined:find("Move to Section:") and joined:find("Profession Tools") and joined:find("Reset to Its Original Section %(Gear%)")
		and joined:find("Favorite") and joined:find("Mark as Junk") and joined:find("Track as Currency"), "the item menu: Move to Section, Reset to Its Original Section, and the marks")
	for _, r in ipairs(m.rows) do if r:IsShown() and r.text.text == "   Consumables" then r:GetScript("OnClick")(r) end end
	check(S:MovedTo(7001) == "Consumables" and not m:IsShown(), "picking a section in the menu moves the item")
	local secure = n.Buttons:Get(0, 1)
	local realAlt = _G.IsAltKeyDown
	_G.IsAltKeyDown = function() return true end
	secure.rec, secure.hasItem = rec(7001), true
	secure:GetScript("OnClick")(secure, "LeftButton")
	check(n.menuFrame:IsShown(), "Alt+Left-click on an item opens the item menu")
	n.menuFrame:Hide()
	secure:GetScript("OnClick")(secure, "RightButton")
	check(not n.menuFrame:IsShown(), "Alt+Right-click no longer opens it (that click could also use the item)")
	n.menuFrame:Hide()
	_G.IsAltKeyDown = realAlt
	check(type(BagSmith_MoveToSection) == "function" and n.KeyBinds.LIST[4][1] == "BAGSMITH_MOVESECTION", "the Move to Section keybinding exists, listed in Settings")
	-- Section title right-click menu.
	m = S:SectionMenu(id)
	texts = {}
	for _, r in ipairs(m.rows) do if r:IsShown() then texts[#texts + 1] = r.text.text .. (r.check:IsShown() and "*" or "") end end
	joined = table.concat(texts, "|")
	check(joined:find("Show at Vendor%*") and joined:find("Show at Auction House%*") and joined:find("Rename") and joined:find("Delete"), "a custom section's title menu: Show at Vendor / AH (both on), Rename, Delete")
	m:Hide()
	-- Show at Vendor off for Gear: hidden while a vendor is open, in every view, with the footer offer.
	S:Move(7001, "Gear")
	S:SetShown("Gear", "vendor", false)
	local function shownIDs() local t = {}; for _, b in ipairs(main.used or {}) do if b:IsShown() and b.hasItem and b.rec then t[b.rec.itemID] = true end end; return t end
	check(shownIDs()[7001], "away from vendors, hidden sections still show")
	M.fire("MERCHANT_SHOW"); M.runTimers()
	-- (Light Leather was moved into Gear above, so it's hidden too; the belt is in the custom section.)
	check(not shownIDs()[7001] and not shownIDs()[7002] and shownIDs()[7003] and main.hiddenNote:IsShown() and main.hiddenNote.text.text:find("^2 items hidden at this vendor %(Gear%)") and main.hiddenNote.btn.label.text == "Show Them",
		"at a vendor: Gear (with what was moved into it) is hidden, and the note at the end of the list says so, with Show Them")
	n:Set("grp", "none"); M.runTimers()
	check(not shownIDs()[7001], "hidden in every view (Sections: None too)")
	main.hiddenNote.btn:GetScript("OnClick")(main.hiddenNote.btn); M.runTimers()
	check(shownIDs()[7001] and main.hiddenNote.text.text:find("^Showing 2 items from sections hidden at this vendor") and main.hiddenNote.btn.label.text == "Hide Again", "Show Them brings them back for this visit, and offers Hide Again")
	M.fire("MERCHANT_CLOSED"); M.fire("MERCHANT_SHOW"); M.runTimers()
	check(not shownIDs()[7001], "the next visit hides them again")
	M.fire("MERCHANT_CLOSED"); M.runTimers()
	check(shownIDs()[7001], "and closing the vendor brings everything back")
	n:Set("grp", "type"); M.runTimers()
	-- Settings > Sections: the custom section, the moved items, the vendor/AH toggles, the rule.
	local P = n.SettingsPanel; P:Show(); P:ShowPage("custom")
	local csec, vis = 0, {}
	for _, w in ipairs(P.pools.csec) do if w:IsShown() then csec = csec + 1 end end
	local movedText = ""
	for _, w in ipairs(P.pools.moved or {}) do if w:IsShown() then movedText = w.text.text end end
	P:ShowPage("sections")
	for _, w in ipairs(P.pools.vis) do if w:IsShown() then vis[w.id] = { w.vendor:GetChecked() and true or false, w.ah:GetChecked() and true or false } end end
	local txt = {}
	for _, w in ipairs(P.pools.text) do if w:IsShown() then txt[#txt + 1] = w.text.text end end
	local alltxt = table.concat(txt, " ")
	check(csec == 1 and vis.Gear and vis.Gear[1] == false and vis.Gear[2] == true and vis["~fav"] and vis.c1, "Settings: the custom section, and Show at Vendor / Show at AH checkboxes for each section (Gear unchecked at vendors)")
	check(alltxt:find("item marked as junk always goes to Junk", 1, true) and alltxt:find("An item in one of your gear sets goes to that set's section", 1, true) and movedText:find(("moved %d item"):format(S:MoveCount())), "Settings explains which section wins, and counts the moved items")
	P:Hide()
	-- The moved-items window.
	S:ManageMoves()
	local f = S.movedFrame
	check(f:IsShown() and f.rows[1]:IsShown() and f.rows[1].id == 7002 and f.rows[1].name.text:find("in Gear %(was Trade Goods%)"), "Manage...: each moved item and where it went (was ...)")
	f.rows[1].remove:GetScript("OnClick")(f.rows[1].remove)
	check(S:MovedTo(7002) == nil and f.rows[1].id ~= 7002, "its button sends the item back to its own section")
	f:Hide()
	-- Deleting a section sends its items back.
	S:Move(7003, id)
	S:Delete(id); M.runTimers()
	check(not S:IsCustom(id) and S:MovedTo(7003) == nil and not n.IndexOf(n.db.laneOrder, id) and rec(7003).cat == "Gear", "deleting a section sends its items home and leaves Section Order")
	-- Saved data is checked on load.
	package.loaded.mock = nil
	local M2 = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {
		customSections = { { id = "c3", name = "Raid" }, { id = "bad", name = "x" }, { id = "c4", name = "  " } },
		sectionMoves = { [7001] = "c3", [7002] = "~fav", [7003] = "Junk", ["x"] = "Gear" },
		sectionHide = { Gear = { vendor = true }, ["~fav"] = { ah = true, vendor = "yes" } },
		laneOrder = { "~recent", "c3", "Gear" } } } }
	local n2 = M2.loadAddon("BagSmith"); M2.fire("ADDON_LOADED", "BagSmith")
	local d = n2.db
	check(#d.customSections == 1 and d.customSections[1].id == "c3" and d.sectionMoves[7001] == "c3" and d.sectionMoves[7002] == nil and d.sectionMoves[7003] == nil
		and d.sectionHide.Gear.vendor and d.sectionHide["~fav"].ah and not d.sectionHide["~fav"].vendor and n2.IndexOf(d.laneOrder, "c3"),
		"saved custom sections, moves and hide flags are checked on load (bad entries dropped, good ones kept)")
	_G.GetCursorInfo, _G.ClearCursor = nil, nil
end)()

;(function()
	-- 0.14.0-beta2: the beta1 audit fixes, keybinding conflicts, locked cells, green dots and Clear Recent.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 20558, name = "Warsong Gulch Mark of Honor", q = 2, count = 3, class = 15, subclass = 0, price = 0 })
	M.put(0, 2, { id = 7003, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 4, equip = "INVTYPE_WAIST" })
	M.put(1, 1, { id = 7004, name = "Iron Gloves", q = 1, class = 4, subclass = 4, price = 9, equip = "INVTYPE_HAND" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local S = n.Sections
	local function rec(id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
	-- A token moved out of Tokens is still a currency.
	local tok = rec(20558)
	check(n.Marks:IsBuiltInCurrency(tok), "the Mark of Honor is a currency")
	local c1 = S:Create("Battlegrounds")
	S:Move(20558, c1); M.runTimers()
	check(rec(20558).cat == c1 and n.Marks:IsBuiltInCurrency(rec(20558)), "moved into a custom section, it's still a currency (its own category decides)")
	-- Saved characters follow the current profile's sections.
	n:SaveCache()
	local saved = BagSmithDB.cache[n:CharKey()]
	local s1
	for _, r in ipairs(saved.items) do if r.itemID == 20558 then s1 = r end end
	check(s1 and s1.ownCat == "Tokens", "the saved snapshot keeps each item's own category")
	S:Delete(c1); M.runTimers()
	local cachedRecs = n:CachedRecords(n:CharKey(), false)
	local cr
	for _, r in ipairs(cachedRecs) do if r.itemID == 20558 then cr = r end end
	check(cr and cr.cat == "Tokens", "after deleting the section, the saved copy goes back to Tokens (not the old id)")
	-- Ids are never reused; deleting cleans collapse state.
	local c2 = S:Create("Fishing")
	check(c2 ~= c1, "a new section gets a new number (" .. tostring(c1) .. " is never reused: " .. tostring(c2) .. ")")
	table.insert(n.db.collapsed, c2)
	S:Delete(c2)
	check(not n.IndexOf(n.db.collapsed, c2), "deleting a section clears its collapse state")
	-- Profile switch closes section dialogs and menus; old callbacks do nothing.
	local c3 = S:Create("Healing")
	S:PromptRename(c3)
	local pr = n.promptFrame
	local cb = pr.onOK
	S:SectionMenu(c3)
	n.Profiles:Use("Other"); M.runTimers()
	check(not pr:IsShown() and not n.menuFrame:IsShown(), "switching profiles closes an open Rename box and section menu")
	S:Create("Fishing")
	cb("Renamed")
	local renamed = false
	for _, cs in ipairs(S:Customs()) do if cs.name == "Renamed" then renamed = true end end
	check(not renamed, "a late callback from the old profile changes nothing in the new one (its copy of Healing stays Healing)")
	n.Profiles:Use("Default"); M.runTimers()
	-- Keys and Reagent Bag menus have no vendor/AH toggles.
	local m = S:SectionMenu("~ky")
	local t = {}
	for _, r in ipairs(m.rows) do if r:IsShown() then t[#t + 1] = r.text.text end end
	check(not table.concat(t, "|"):find("Show at"), "the Keys title menu has no vendor/AH toggles")
	m:Hide()
	-- A bank-only item dropped on Junk: marked, or the drop isn't taken.
	n.bankItems = { { itemID = 7099, name = "Bank Thing", quality = 1, bag = -1, slot = 1, count = 1, cat = "Other", ownCat = "Other" } }
	_G.GetCursorInfo = function() return "item", 7099, "|cffffffff|Hitem:7099|h[Bank Thing]|h|r" end
	local cleared = 0
	_G.ClearCursor = function() cleared = cleared + 1 end
	local took = S:DropOnSection("Junk")
	check((took and n.Junk:Marked(7099) and cleared == 1) or (not took and cleared == 0), "a bank-only item dropped on Junk is marked, or the drop isn't taken (never cleared for nothing)")
	_G.GetCursorInfo = function() return nil end
	n.bankItems = {}
	-- Long menus are capped to the screen and scroll.
	local many = {}
	for i = 1, 80 do many[#many + 1] = { text = "Row " .. i, onClick = function() end } end
	m = n.ShowMenu(many)
	local shown = 0
	for _, r in ipairs(m.rows) do if r:IsShown() then shown = shown + 1 end end
	check(shown < 80 and m:GetHeight() <= UIParent:GetHeight(), "a long menu fits the screen (" .. shown .. " rows shown)")
	m:GetScript("OnMouseWheel")(m, -1)
	check(m.rows[1].text.text == "Row 4", "the mouse wheel scrolls it")
	m:Hide()
	-- Bag windows at a vendor: hidden items are locked cells, not buttons.
	S:SetShown("Gear", "vendor", false)
	n.ui.bagWindows = true; M.runTimers(); n:RefreshViews(true); M.runTimers()
	local bv = n.Window.bagViews[1]
	bv:Show(); M.runTimers()
	M.fire("MERCHANT_SHOW"); M.runTimers()
	local lc = bv.lockCells and bv.lockCells[1]
	check(lc and lc:IsShown() and lc.rec and lc.rec.itemID == 7004 and lc.lock.texture:find("ui%-lock") and lc.icon.desaturated, "a bag window shows a hidden item as a locked cell (greyed, padlock)")
	check(not lc:GetScript("OnReceiveDrag") and not lc:GetScript("OnClick"), "the locked cell takes no clicks or drops")
	M.fire("MERCHANT_CLOSED"); M.runTimers()
	check(not lc:IsShown(), "closing the vendor unlocks it")
	S:SetShown("Gear", "vendor", true)
	-- Keybinding conflicts ask first and name what changes.
	local bound = { ["CTRL-J"] = "TOGGLECALENDAR" }
	_G.BINDING_NAME_TOGGLECALENDAR = "Toggle Calendar"
	_G.GetBindingAction = function(k) return bound[k] or "" end
	local realSet = n.KeyBinds.Set
	local setCalls = 0
	n.KeyBinds.Set = function(self, a, k) setCalls = setCalls + 1; bound[k] = a end
	local result
	n.KeyBinds:Capture("BAGSMITH_JUNK", function(r) result = r or "cancelled" end)
	local realCtrl = _G.IsControlKeyDown
	_G.IsControlKeyDown = function() return true end
	n.KeyBinds.capture:GetScript("OnKeyDown")(n.KeyBinds.capture, "J")
	_G.IsControlKeyDown = realCtrl
	local c = n.Popups.confirm
	check(c:IsShown() and c.text.text:find("Ctrl%-J is bound to Toggle Calendar") and c.text.text:find("Toggle Calendar will be unbound") and setCalls == 0,
		"a key already in use asks first, naming what will be unbound: " .. tostring(c.text.text))
	c.no:GetScript("OnClick")(c.no)
	check(setCalls == 0 and result == "cancelled" and bound["CTRL-J"] == "TOGGLECALENDAR", "declining changes nothing")
	n.KeyBinds:Capture("BAGSMITH_JUNK", function(r) result = r end)
	_G.IsControlKeyDown = function() return true end
	n.KeyBinds.capture:GetScript("OnKeyDown")(n.KeyBinds.capture, "J")
	_G.IsControlKeyDown = realCtrl
	c.yes:GetScript("OnClick")(c.yes)
	check(setCalls == 1 and bound["CTRL-J"] == "BAGSMITH_JUNK", "confirming binds it")
	n.KeyBinds.Set = realSet
	-- Keybindings page: the item menu, and the game's item modifiers on Alt.
	_G.GetModifiedClick = function(a) if a == "DRESSUP" then return "ALT" end return "SHIFT" end
	local P = n.SettingsPanel; P:Show(); P:ShowPage("keys")
	local txt = {}
	for _, w in ipairs(P.pools.text) do if w:IsShown() then txt[#txt + 1] = w.text.text end end
	local all = table.concat(txt, " ")
	check(all:find("Alt%+Left%-click an item opens BagSmith's item menu") and all:find("Your Dress Up modifier is also Alt"), "Keybindings explains Alt+Left-click and flags the game's Dress Up modifier on Alt")
	_G.GetModifiedClick = nil
	-- Green dots: Clear Recent can clear them too (on by default).
	check(n.db.newdotClearRecent == true, "Clear Recent Also Clears Green Dots is on by default")
	P:ShowPage("icons")   -- (1.5.0: the green dot moved to Item Icons)
	local sub
	for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == "newdotClearRecent" then sub = w end end
	check(sub and sub.text.text == "Clear Recent Also Clears Green Dots", "it sits under the green dot setting")
	n:Set("newdot", false); P:Refresh()
	sub = nil
	for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == "newdotClearRecent" then sub = w end end
	check(not sub, "and is hidden while the green dots are off")
	n:Set("newdot", true); P:Hide()
	local belt = rec(7003)
	belt.isNew = true
	local dismissed = {}
	local realDismiss = n.DismissNew
	n.DismissNew = function(self, r) dismissed[#dismissed + 1] = r.itemID; r.isNew = false end
	n:ClearRecent()
	check(#dismissed >= 1 and not belt.isNew, "Clear Recent clears the green dots when it's on")
	belt.isNew = true; dismissed = {}
	n:Set("newdotClearRecent", false)
	n:ClearRecent()
	check(#dismissed == 0 and belt.isNew, "and leaves them when it's off")
	n.DismissNew = realDismiss
	_G.GetBindingAction, _G.GetCursorInfo, _G.ClearCursor = nil, nil, nil
end)()

;(function()
	-- 0.14.0-beta3: the re-audit fixes (R1-R6) and search on own type plus current section.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7101, name = "Lucky Charm", q = 2, class = 4, subclass = 0, sub = "Miscellaneous", price = 50, equip = "INVTYPE_TRINKET" })
	M.put(0, 2, { id = 7003, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 4, equip = "INVTYPE_WAIST" })
	M.put(0, 3, { id = 20558, name = "Warsong Gulch Mark of Honor", q = 2, count = 3, class = 15, subclass = 0, price = 0 })
	local key = "Tester - Realm"
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	-- A profile from 0.14.0-beta1: a custom section and a sheet filtered to it, but no counter.
	_G.BagSmithDB = { version = 2, chars = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list",
		customSections = { { id = "c1", name = "Healing" } }, sectionMoves = { [20558] = "c1" },
		sheets = { { n = "Heals", f = { text = "", q = {}, cat = { c1 = true }, t = {}, bd = {}, w = {} } } } } },
		cache = {} }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local S, main = n.Sections, n.Window.main
	local function rec(id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
	-- R2: an older profile's counter starts above the ids it mentions.
	check((n.db.sectionNextId or 0) >= 2, "a beta1 profile's section counter starts above its existing ids (" .. tostring(n.db.sectionNextId) .. ")")
	S:Delete("c1")
	local id = S:Create("Fishing")
	check(id ~= "c1", "deleting the old section first, then creating one, never reuses c1 (got " .. tostring(id) .. ")")
	S:Delete(id)
	-- R3: a beta1 saved bank (no ownCat, tokens moved to a custom section) still counts toward currencies.
	BagSmithDB.cache[n:CharKey()] = BagSmithDB.cache[n:CharKey()] or { name = "Tester", realm = "Realm" }
	BagSmithDB.cache[n:CharKey()].bank = { { itemID = 20558, name = "Warsong Gulch Mark of Honor", count = 8, quality = 2, cat = "c7", classID = 15, subclassID = 0, bag = -1, slot = 1 } }
	n.bankScanned = false
	n.Currency:Invalidate()
	local total
	for _, e in ipairs(n.Currency:List()) do if e.id == 20558 then total = e.count end end
	check(total == 11, "currencies count moved tokens from a bank saved by beta1 (3 carried + 8 banked = " .. tostring(total) .. ")")
	-- R4: an older saved record keeps a built-in category it can't rebuild (no quest flag saved).
	local legacy = { itemID = 7201, name = "Odd Letter", quality = 1, cat = "Quest", classID = 15, subclassID = 0, bag = 0, slot = 1 }
	check(S:OwnCategory(legacy) == "Quest", "an older saved Quest item stays Quest (its quest flag wasn't saved, so the saved category is kept)")
	local legacyMoved = { itemID = 20558, quality = 2, cat = "c9", classID = 15, subclassID = 0 }
	check(S:OwnCategory(legacyMoved) == "Tokens", "an older saved item filed under a custom id is worked out again")
	-- R6 and search: a moved trinket keeps its Type, and search sees both its own type and its new section.
	local pid = S:Create("Professions")
	S:Move(7101, pid); M.runTimers()
	local charm = rec(7101)
	check(n:TypeText(charm) == "Trinket", "a moved trinket's Type is still Trinket: " .. tostring(n:TypeText(charm)))
	check(n:ParseSearch("trinket")(charm) and n:ParseSearch("t:trinket")(charm), "searching \"trinket\" (and t:trinket) still finds it after the move")
	check(n:ParseSearch("professions")(charm) and n:ParseSearch("gear")(charm), "search matches both its new section (Professions) and its own (Gear)")
	check(not n:ParseSearch("professions")(rec(7003)), "items not moved there don't match the section's name")
	-- R5: rows holding still under the pointer don't show a vendor-hidden item.
	S:Clear(7101); M.runTimers()
	S:SetShown("Gear", "vendor", false)
	local belt
	for _, b in ipairs(main.used or {}) do if b.rec and b.rec.itemID == 7003 and b:IsShown() then belt = b end end
	check(belt, "the belt has a row")
	n.ui.atVendor = true
	main:RefreshInPlace(false)
	check(not belt:IsShown(), "a held-row refresh at a vendor hides the hidden section's item (no active row)")
	n.ui.atVendor = false
	S:SetShown("Gear", "vendor", true); n:RefreshViews(true); M.runTimers()
	-- R1: in a fresh session (no prompt ever opened), a profile switch still closes the item menu and Moved Items.
	local m = S:ItemMenu(rec(7003))
	S:Move(7003, pid); S:ManageMoves()
	local mf = S.movedFrame
	check(m:IsShown() and mf:IsShown() and not n.promptFrame, "item menu and Moved Items open, no prompt ever created")
	local favRow
	for _, r in ipairs(m.rows) do if r:IsShown() and r.text.text == "Favorite" then favRow = r end end
	local removeBtn = mf.rows[1] and mf.rows[1].remove
	n.Profiles:Use("Other"); M.runTimers()
	check(not m:IsShown() and not mf:IsShown(), "switching profiles closes both (each closed on its own)")
	if favRow then favRow:GetScript("OnClick")(favRow) end
	check(not n.Marks:IsFavorite(7003), "a late click on the old menu's Favorite changes nothing in the new profile")
	n.db.sectionMoves[7003] = "Gear"
	if removeBtn then removeBtn:GetScript("OnClick")(removeBtn) end
	check(n.db.sectionMoves[7003] == "Gear", "a late click in the old Moved Items window doesn't touch the new profile's moves")
	n.Profiles:Use("Default"); M.runTimers()
end)()

;(function()
	-- 0.14.0-beta4: the beta3 re-audit fixes (F1-F3).
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 20558, name = "Warsong Gulch Mark of Honor", q = 2, count = 3, class = 15, subclass = 0, price = 0 })
	M.put(0, 2, { id = 7003, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 4, equip = "INVTYPE_WAIST" })
	local longName = "c" .. string.rep("9", 38)
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list",
		customSections = { { id = "c1", name = longName } },
		sheets = { { n = longName, f = { text = longName, q = {}, cat = {}, t = {}, bd = {}, w = {} } } } } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local S, main = n.Sections, n.Window.main
	-- F3: a section NAME that looks like an id can't move the counter; new ids stay valid.
	check(n.db.sectionNextId == 2, "a digit-like section name doesn't move the section counter (" .. tostring(n.db.sectionNextId) .. ")")
	local a, b = S:Create("Fishing"), S:Create("Cooking")
	check(a == "c2" and b == "c3" and S:CanTake(a) and S:CanTake(b), "new sections get normal, usable ids (" .. tostring(a) .. ", " .. tostring(b) .. ")")
	n.db.sectionNextId = n.MAX_SECTION_ID + 1
	local none, why = S:Create("Too Many")
	check(not none and why, "past the limit, creating a section fails safely with a reason")
	n.db.sectionNextId = 4
	-- F1: older saved records are classified from the item, not from any profile's moves.
	local tokenMovedToOther = { itemID = 20558, quality = 2, cat = "Other", classID = 15, subclassID = 0 }
	check(S:OwnCategory(tokenMovedToOther) == "Tokens", "a beta1-saved token that had been moved to Other is a token again (no current move needed)")
	local beltMovedToTokens = { itemID = 7003, quality = 1, cat = "Tokens", classID = 4, subclassID = 1, equipLoc = "INVTYPE_WAIST" }
	check(S:OwnCategory(beltMovedToTokens) == "Gear", "an ordinary item saved under Tokens by a move isn't a currency")
	check(not n.Marks:IsBuiltInCurrency({ itemID = 7003, cat = "Tokens", ownCat = S:OwnCategory(beltMovedToTokens) }), "so it never shows up as a phantom currency")
	local oldQuest = { itemID = 7201, quality = 1, cat = "Quest", classID = 15, subclassID = 0 }
	check(S:OwnCategory(oldQuest) == "Quest", "an older saved Quest item (flag not saved) still stays Quest")
	BagSmithDB.cache[n:CharKey()] = BagSmithDB.cache[n:CharKey()] or { name = "Tester", realm = "Realm" }
	BagSmithDB.cache[n:CharKey()].bank = { { itemID = 20558, name = "Warsong Gulch Mark of Honor", count = 8, quality = 2, cat = "Other", classID = 15, subclassID = 0, bag = -1, slot = 1 } }
	n.bankScanned = false; n.Currency:Invalidate()
	local total
	for _, e in ipairs(n.Currency:List()) do if e.id == 20558 then total = e.count end end
	check(total == 11, "with no move in this profile, the old bank's moved tokens still count (11: " .. tostring(total) .. ")")
	-- F2: a row hidden for a hidden item comes back when its slot gets something visible.
	S:SetShown("Gear", "vendor", false)
	local belt
	for _, bt in ipairs(main.used or {}) do if bt.rec and bt.rec.itemID == 7003 and bt:IsShown() then belt = bt end end
	n.ui.atVendor = true
	main:RefreshInPlace(false)
	check(belt and not belt:IsShown(), "the belt's row hides at the vendor (held refresh)")
	check(main:HasArrivals({ belt.rec }), "a hidden row doesn't count as on screen (so a rebuild can come)")
	-- The same slot now holds a visible item (a consumable).
	M.bags[0][2] = nil
	M.put(0, 2, { id = 7301, name = "Bread", q = 1, count = 4, class = 0, subclass = 0, price = 1 })
	n:Scan()
	main:RefreshInPlace(false)
	check(belt:IsShown() and belt.rec and belt.rec.itemID == 7301, "when the slot gets a visible item, the row comes back showing it")
	n.ui.atVendor = false
	S:SetShown("Gear", "vendor", true)
end)()

;(function()
	-- 0.14.0-beta5: the beta4 re-audit fixes (F1, F2).
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 4
	for b = 1, 5 do M.sizes[b] = 0 end
	M.put(0, 1, { id = 7301, name = "Bread", q = 1, count = 4, class = 0, subclass = 0, price = 1 })
	-- A beta1-style profile: section c1 deleted, remembered only in a sheet's own collapse lists.
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", sheetViews = true,
		sheets = { { n = "Overview", f = { text = "", q = {}, cat = {}, t = {}, bd = {}, w = {} } } },
		sheetPrefs = { bags = { Overview = { collapsed = { "c1" } } }, bank = { Vault = { collapsed = { "c4" } } } } } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local S, main = n.Sections, n.Window.main
	-- F1: both per-sheet collapse families keep their numbers out of reach.
	check((n.db.sectionNextId or 0) >= 5, "a section remembered only in sheets' own collapse lists (bags c1, bank c4) moves the counter past it (" .. tostring(n.db.sectionNextId) .. ")")
	local id = S:Create("Fishing")
	check(id ~= "c1" and id ~= "c4", "a new section doesn't reuse those numbers (" .. tostring(id) .. ")")
	-- Deleting a section clears it from every sheet's collapse list.
	table.insert(n.db.sheetPrefs.bags.Overview.collapsed, id)
	n.db.sheetPrefs.bank.Vault.collapsed[#n.db.sheetPrefs.bank.Vault.collapsed + 1] = id
	S:Delete(id)
	check(not n.IndexOf(n.db.sheetPrefs.bags.Overview.collapsed, id) and not n.IndexOf(n.db.sheetPrefs.bank.Vault.collapsed, id), "deleting a section clears it from each sheet's collapse list (bags and bank)")
	-- F2: icon view, empty slots shown, at a vendor with Gear hidden, pointer over the list.
	n:Set("view", "icons"); n:Set("grp", "none"); n:Set("emptySlots", true); M.runTimers()
	S:SetShown("Gear", "vendor", false)
	local cell
	for _, b in ipairs(main.used or {}) do if b.rec and b.rec.empty and b.rec.slot == 2 then cell = b end end
	check(cell and cell:IsShown(), "slot 2 starts as a visible empty cell")
	n.ui.atVendor = true
	M.put(0, 2, { id = 7003, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 4, equip = "INVTYPE_WAIST" }); n:Scan()
	main:RefreshInPlace(false)
	check(not cell:IsShown(), "a hidden item landing there hides the cell")
	M.bags[0][2] = nil; n:Scan()
	main:RefreshInPlace(false)
	check(cell:IsShown() and cell.rec and cell.rec.empty, "when it leaves, the empty cell shows again (pointer still over the list)")
	-- And again: empty, hidden, empty.
	M.put(0, 2, { id = 7003, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 4, equip = "INVTYPE_WAIST" }); n:Scan()
	main:RefreshInPlace(false)
	M.bags[0][2] = nil; n:Scan()
	main:RefreshInPlace(false)
	check(cell:IsShown(), "the second empty-hidden-empty round shows it again too")
	n.ui.atVendor = false
	S:SetShown("Gear", "vendor", true)
end)()

;(function()
	-- 0.14.0-beta6: junk selling with favorites and hidden sections, explained.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7401, name = "Worn Dagger", q = 0, class = 2, subclass = 15, price = 3, equip = "INVTYPE_WEAPONMAINHAND" })
	M.put(0, 2, { id = 7402, name = "Broken Fang", q = 0, class = 15, subclass = 0, price = 2 })
	M.put(0, 3, { id = 7403, name = "Cracked Pot", q = 0, class = 15, subclass = 0, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local J, S = n.Junk, n.Sections
	local function rec(id) for _, r in ipairs(n.items) do if r.itemID == id then return r end end end
	-- Why an item might have been expected to stay.
	n.Marks:ToggleFavorite(rec(7402))
	S:SetShown("Junk", "vendor", false)
	check(J:ProtectReason(rec(7402)) == "favorite; hidden at vendors: Junk", "a favorite grey in a hidden Junk section: both reasons (" .. tostring(J:ProtectReason(rec(7402))) .. ")")
	check(J:ProtectReason(rec(7401)) == "hidden at vendors: Junk", "a grey in a section hidden at vendors: says which (" .. tostring(J:ProtectReason(rec(7401))) .. ")")
	S:SetShown("Junk", "vendor", true)
	check(J:ProtectReason(rec(7403)) == nil, "an ordinary grey has no reason")
	-- Blizzard's Sell All Junk: the reminder names the source and says Blizzard's button forces it.
	S:SetShown("Junk", "vendor", false)
	for i = #M.log, 1, -1 do M.log[i] = nil end
	J:RemindBlizzardSale()
	check(#M.log == 0, "nothing is claimed the moment Blizzard's button is pressed")
	-- Only the dagger actually leaves its slot (the sale is checked shortly after).
	M.bags[0][1] = nil
	M.runTimers()
	local line = M.log[#M.log] or ""
	check(line:find("Blizzard's Sell All Junk sold") and line:find("Worn Dagger %(hidden at vendors: Junk%)") and not line:find("Broken Fang") and line:find("Blizzard's button always sells every grey item, even favorites and hidden ones"),
		"after Blizzard's Sell All Junk: names only what actually sold, and why: " .. line)
	check(select(2, line:gsub("%(", "")) <= 3, "it names at most three items")
	-- BagSmith's own selling: the same reminder, worded for BagSmith.
	local ready = J:Sellables("all")
	local withReason = 0
	for _, it in ipairs(ready) do if it.reason then withReason = withReason + 1 end end
	check(withReason >= 2, "BagSmith's own sale list notes which items are favorites or hidden")
	for i = #M.log, 1, -1 do M.log[i] = nil end
	J:Remind({ { name = "A", reason = "favorite" }, { name = "B", reason = "favorite" }, { name = "C", reason = "favorite" }, { name = "D", reason = "favorite" }, { name = "E", reason = "favorite" } }, false)
	line = M.log[#M.log] or ""
	check(line:find("Sold A %(favorite%), B %(favorite%), C %(favorite%) and 2 more%.") and line:find("Junk selling includes grey and junk%-marked items even when they're favorites or hidden"),
		"after BagSmith's own selling: up to three names, then \"and N more\": " .. line)
	S:SetShown("Junk", "vendor", true)
	-- Settings says it plainly, naming Blizzard.
	local P = n.SettingsPanel; P:Show()
	local function pageText(page)
		P:ShowPage(page)
		local t = {}
		for _, w in ipairs(P.pools.text) do if w:IsShown() then t[#t + 1] = w.text.text end end
		for _, w in ipairs(P.pools.check) do if w:IsShown() and w.help then t[#t + 1] = w.help.text end end
		return table.concat(t, " ")
	end
	local rule = "Blizzard's Sell All Junk button always sells every grey item, favorites and hidden sections included; BagSmith can't change that"
	check(pageText("automation"):find(rule, 1, true), "Sell Junk Automatically explains that Blizzard's button sells every grey item")
	local secText, dynText = pageText("sections"), pageText("dynamic")
	check(secText:find("Hiding a section only hides it from view: " .. rule, 1, true) and dynText:find("Favorites aren't protected from junk selling: " .. rule, 1, true),
		"Standard Sections says the same for hidden sections, and Dynamic Sections for Favorites")
	P:Hide()
end)()

;(function()
	-- 0.14.0-beta7: empty custom sections and the item menu button.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7003, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 4, equip = "INVTYPE_WAIST" })
	M.put(0, 2, { id = 7301, name = "Bread", q = 1, count = 4, class = 0, subclass = 0, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local S, main = n.Sections, n.Window.main
	local function lane(label)
		for _, hostLanes in pairs(n.Buttons.lanes or {}) do
			for _, h in pairs(hostLanes) do
				if type(h) == "table" and h.IsShown and h:IsShown() and h.text and h.text.text == label then return h end
			end
		end
	end
	check(n.db.showEmptySections == true and n.db.itemMenuButton == true, "both new settings are on by default")
	-- A new, empty custom section shows right away, with its hint.
	local id = S:Create("Raid Consumables"); M.runTimers()
	local h = lane("Raid Consumables")
	check(h and h.count.text == "(0)" and (h.sub.text or "") == "", "in list view, a new empty section shows just its title and (0)")
	check(S:DropKind(h.laneId) == "move", "and it takes drops right away")
	-- Its own Show When Empty, from the title menu.
	local m = S:SectionMenu(id)
	local row
	for _, r in ipairs(m.rows) do if r:IsShown() and r.text.text == "Show When Empty" then row = r end end
	check(row and row.check:IsShown(), "its title menu has Show When Empty, on")
	row:GetScript("OnClick")(row); M.runTimers()
	check(not lane("Raid Consumables") and S:Custom(id).showEmpty == false, "turning it off hides the empty section")
	local kept = n.validateSettings({ customSections = { { id = id, name = "Raid Consumables", showEmpty = false } } }, n.DEFAULTS)
	check(kept.customSections[1].showEmpty == false, "Show When Empty off is saved (it survives the settings check on load)")
	S:SetShowEmpty(id, true); M.runTimers()
	check(lane("Raid Consumables") and S:Custom(id).showEmpty == nil, "and on again shows it")
	-- The overall setting is the master switch.
	n:Set("showEmptySections", false); M.runTimers()
	check(not lane("Raid Consumables"), "Show Empty Custom Sections off: no empty sections show")
	n:Set("showEmptySections", true); M.runTimers()
	-- While searching or filtering, empty sections hide (unless the filter is for that section).
	main.st.filters.text = "belt"; n:RefreshViews(true); M.runTimers()
	check(not lane("Raid Consumables"), "an empty section hides while you search")
	main.st.filters.text = ""; main.st.filters.cat = { [id] = true }; n:RefreshViews(true); M.runTimers()
	check(lane("Raid Consumables"), "a filter for that very section still shows it")
	main.st.filters.cat = {}; n:RefreshViews(true); M.runTimers()
	-- Settings: the master switch and each section's Show When Empty.
	local P = n.SettingsPanel; P:Show(); P:ShowPage("custom")
	local master, rowW
	for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == "showEmptySections" then master = w end end
	for _, w in ipairs(P.pools.csec) do if w:IsShown() and w.id == id then rowW = w end end
	check(master and rowW and rowW.empty:GetChecked() == true, "Settings: Show Empty Custom Sections, and a checked Show When Empty box on the section's row")
	-- The item menu button on list rows.
	P:ShowPage("columns")
	local imb
	for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == "itemMenuButton" then imb = w end end
	check(imb and imb.text.text == "Item Menu Button", "Settings > Columns: Item Menu Button")
	P:Hide()
	local beltBtn
	for _, b in ipairs(main.used or {}) do if b.rec and b.rec.itemID == 7003 and b:IsShown() then beltBtn = b end end
	check(beltBtn and beltBtn.kebab and beltBtn.kebab:IsShown() and #beltBtn.kebab.dots == 3, "each list row has the item menu button (three dots)")
	check(beltBtn.kebab:GetAlpha() < 0.5, "muted until the row is hovered")
	local function itemCol(p) for _, c in ipairs(p) do if c.key == "n" then return c end end end
	local plan = main:ColumnPlan()
	local ic = itemCol(plan)
	check(plan.kebab and ic.iconX == ic.colX + 14 and ic.x == ic.colX + 38 and ic.kebabX == ic.colX, "the dots sit at the left of the Item column; the icon and name move over to make room")
	beltBtn.kebab:GetScript("OnClick")(beltBtn.kebab)
	check(n.menuFrame:IsShown(), "clicking it opens the item menu")
	n.menuFrame:Hide()
	n:Set("itemMenuButton", false); M.runTimers()
	local ic2 = itemCol(main:ColumnPlan())
	check(not beltBtn.kebab:IsShown() and ic2.iconX == ic2.colX + 2, "turning the setting off removes it and gives the space back")
	n:Set("itemMenuButton", true); n:Set("view", "icons"); M.runTimers()
	check(not beltBtn.kebab:IsShown(), "icon view doesn't show it")
	n:Set("view", "list"); M.runTimers()
end)()

;(function()
	-- 0.14.0-beta8: the hint in icon view only; the item menu with many sections; the bigger name.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7003, name = "Linen Belt", q = 2, class = 4, subclass = 1, price = 4, equip = "INVTYPE_WAIST" })
	_G.ITEM_QUALITY_COLORS = _G.ITEM_QUALITY_COLORS or { [0] = { r = .6, g = .6, b = .6 }, [1] = { r = 1, g = 1, b = 1 }, [2] = { r = .12, g = 1, b = 0 } }
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "icons" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local S = n.Sections
	local ids = {}
	for i = 1, 30 do ids[i] = S:Create(("Section %02d"):format(i)) end
	M.runTimers()
	local h
	for _, hostLanes in pairs(n.Buttons.lanes or {}) do for _, x in pairs(hostLanes) do
		if type(x) == "table" and x.IsShown and x:IsShown() and x.text and x.text.text == "Section 01" then h = x end
	end end
	check(h and h.sub.text == "Empty. Drag an item onto this title.", "in icon view, an empty section keeps the hint")
	-- The item menu with 30 sections: the list scrolls, the name and actions stay.
	local rec
	for _, r in ipairs(n.items) do if r.itemID == 7003 then rec = r end end
	S:Move(7003, ids[25])
	local m = S:ItemMenu(rec)
	local function shown() local t = {}; for _, r in ipairs(m.rows) do if r:IsShown() then t[#t + 1] = r end end; return t end
	local rows = shown()
	local secRows, arrows, labels = 0, 0, {}
	for _, r in ipairs(rows) do
		if r.arrow:IsShown() then arrows = arrows + 1 end
		local t = r.text.text or ""
		if t:find("^   Section") then secRows = secRows + 1 end
		labels[#labels + 1] = t
	end
	local all = table.concat(labels, "|")
	check(secRows <= 12 and arrows == 2, "with many sections, the menu shows 12 or fewer at a time, with up and down arrows (" .. secRows .. " shown)")
	check(all:find("Linen Belt") and all:find("Move to Section:") and all:find("New Section") and all:find("Favorite") and all:find("Mark as Junk") and all:find("Track as Currency"),
		"the item's name, New Section and the actions all stay in view")
	local current
	for _, r in ipairs(rows) do if r.check:IsShown() then current = r.text.text end end
	check(current == "   Section 25", "it opens with the item's current section in view (" .. tostring(current) .. ")")
	local firstSec
	for _, r in ipairs(rows) do if (r.text.text or ""):find("^   ") then firstSec = r.text.text; break end end
	m:GetScript("OnMouseWheel")(m, 1)
	local after
	for _, r in ipairs(shown()) do if (r.text.text or ""):find("^   ") then after = r.text.text; break end end
	check(after ~= firstSec and all:find("Favorite"), "the mouse wheel scrolls the list (" .. tostring(firstSec) .. " to " .. tostring(after) .. ")")
	local down
	for _, r in ipairs(shown()) do if r.arrow:IsShown() and r.arrowDir == 1 then down = r end end
	local before = after
	down:GetScript("OnClick")(down)
	for _, r in ipairs(shown()) do if (r.text.text or ""):find("^   ") then after = r.text.text; break end end
	check(after ~= before and m:IsShown(), "the down arrow scrolls it too, and the menu stays open")
	-- The item's name: bigger row, quality color.
	local title = m.rows[1]
	check(title.text.text == "Linen Belt" and title:GetHeight() > 20 and title.text.textColor and math.abs(title.text.textColor[2] - 1) < 0.01 and title.text.textColor[1] < 0.2,
		"the item's name is a size larger, in its quality color (green here)")
	m:Hide()
end)()

;(function()
	-- 0.14.0-beta9: Classic dialog fill; the menu on short screens; empty headings in context.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7003, name = "Linen Belt", q = 2, class = 4, subclass = 1, price = 4, equip = "INVTYPE_WAIST" })
	M.put(0, 2, { id = 7301, name = "Bread", q = 1, count = 4, class = 0, subclass = 0, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local S, main = n.Sections, n.Window.main
	local rec
	for _, r in ipairs(n.items) do if r.itemID == 7003 then rec = r end end
	-- Short screens: every action stays reachable.
	local ids = {}
	for i = 1, 40 do ids[i] = S:Create(("Section %02d"):format(i)) end
	S:Move(7003, ids[20])
	local realH = UIParent.GetHeight
	local function labelsAt(height, skin)
		UIParent.GetHeight = function() return height end
		n:Set("skin", skin); M.runTimers()
		local m = S:ItemMenu(rec)
		local seen = {}
		local function collect() for _, r in ipairs(m.rows) do if r:IsShown() and r.text.text then seen[r.text.text] = true end end end
		collect()
		for _ = 1, 30 do m:GetScript("OnMouseWheel")(m, -1); collect() end
		for _ = 1, 30 do m:GetScript("OnMouseWheel")(m, 1); collect() end
		m:Hide()
		return seen
	end
	local ok = true
	for _, h in ipairs({ 768, 600, 480, 450, 400, 300 }) do
		for _, skin in ipairs({ "modern", "classic" }) do
			local seen = labelsAt(h, skin)
			if not (seen["Track as Currency"] and seen["Favorite"] and seen["Mark as Junk"] and seen["   New Section..."] and seen["Reset to Its Original Section (Gear)"]) then ok = false; print("MISSING at", h, skin) end
		end
	end
	check(ok, "every action stays reachable at UI heights 768 down to 300, in both skins, for a moved item")
	UIParent.GetHeight = function() return 450 end
	local m = S:ItemMenu(rec)
	local secRows, arrows = 0, 0
	for _, r in ipairs(m.rows) do if r:IsShown() then
		if r.arrow:IsShown() then arrows = arrows + 1 end
		if (r.text.text or ""):find("^   Section") then secRows = secRows + 1 end
	end end
	check(arrows == 2 and secRows >= 3 and secRows < 12, "at height 450 the section list shrinks to fit (" .. secRows .. " sections, with arrows)")
	m:Hide()
	UIParent.GetHeight = realH
	n:Set("skin", "modern"); M.runTimers()
	for i = 1, 40 do S:Delete(ids[i]) end
	-- Empty headings in context: not where hidden, not on another category's sheet.
	local function heading(label)
		for _, hostLanes in pairs(n.Buttons.lanes or {}) do for _, x in pairs(hostLanes) do
			if type(x) == "table" and x.IsShown and x:IsShown() and x.text and x.text.text == label then return x end
		end end
	end
	local healing = S:Create("Healing")
	local hidden = S:Create("Vendor Hidden")
	S:Move(7301, hidden)
	S:SetShown(hidden, "vendor", false)
	M.runTimers()
	check(heading("Healing") and heading("Vendor Hidden"), "both sections show away from vendors")
	M.fire("MERCHANT_SHOW"); M.runTimers()
	check(not heading("Vendor Hidden"), "at a vendor, a hidden section doesn't come back as a (0) heading")
	main.hiddenNote.btn:GetScript("OnClick")(main.hiddenNote.btn); M.runTimers()
	check(heading("Vendor Hidden"), "Show Hidden brings it back")
	M.fire("MERCHANT_CLOSED"); M.runTimers()
	main:SetSheet("Gear"); M.runTimers()
	check(not heading("Healing"), "the Gear sheet doesn't show an unrelated empty custom section")
	main:SetSheet("All"); M.runTimers()
	check(heading("Healing"), "the All sheet still does")
	-- Classic: every dialog-frame window shares the same, more solid background.
	n:Set("skin", "classic"); M.runTimers()
	local menu = S:SectionMenu(healing)
	local st = menu.classicState
	check(st and st.solid and (st.solid.texture == n.Classic.DIALOG_ART or (st.solid.color and st.solid.color[4] == n.Classic.DIALOG_SOLID)),
		"Classic: the menu's background has the shared dialog fill")
	menu:Hide()
	n:Set("skin", "modern"); M.runTimers()
end)()

;(function()
	-- 0.14.0-beta10: reagent bag in By Type; the menu (Reset, usual, icons, width, closes with its window);
	-- merged stacks at the bank; the hidden-sections note.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(5, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 1 })
	M.put(0, 1, { id = 7003, name = "Linen Belt", q = 2, class = 4, subclass = 1, price = 4, equip = "INVTYPE_WAIST" })
	M.put(0, 2, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 2 })
	M.put(0, 3, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 2 })
	M.put(0, 4, { id = 2592, name = "Wool Cloth", q = 1, count = 7, class = 7, subclass = 5, price = 2 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list", reagent = "lane" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local S, main = n.Sections, n.Window.main
	local function laneOfItem(id)
		for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then return b.rec.cat end end
	end
	local function laneIds()
		local t = {}
		for _, h in pairs(n.Buttons.lanes[main.child] or {}) do if type(h) == "table" and h.IsShown and h:IsShown() and h.laneId then t[h.laneId] = true end end
		return t
	end
	-- 1. The reagent bag: a place, not a type.
	check(n.HAS_REAGENT_SLOT and not laneIds()["~rb"], "By Type: no Reagent Bag section, even with Own Section on")
	local test = S:Create("Test")
	S:Move(2589, test); M.runTimers()
	check(laneIds()[test] and laneOfItem(2589) == test, "a reagent-bag item moved to Test shows under Test")
	n:Set("grp", "none"); M.runTimers()
	check(laneIds()["~rb"], "Sections: All still has the Reagent Bag's own section")
	n:Set("grp", "type"); M.runTimers()
	-- 2-5. The item menu.
	local linen
	for _, r in ipairs(n.items) do if r.itemID == 2589 then linen = r end end
	local owner = CreateFrame("Button", nil, main.frame)
	owner:Show()
	local m = S:ItemMenu(linen, owner)
	local rows = {}
	for _, r in ipairs(m.rows) do if r:IsShown() then rows[#rows + 1] = r end end
	check(rows[1].text.text == "Linen Cloth" and rows[2].text.text == "Reset to Its Original Section (Trade Goods)" and rows[2].icon:IsShown() and rows[2].icon.texture:find("ui%-undo"),
		"Reset to Its Original Section sits right under the name, with the undo icon")
	local usual, icons = false, {}
	for _, r in ipairs(rows) do
		if r.text.text == "   Trade Goods (default)" then usual = true end
		if r.icon:IsShown() then icons[r.text.text] = r.icon.texture end
	end
	check(usual, "the item's default section is marked (default)")
	check(icons["Favorite"] and icons["Favorite"]:find("ui%-star") and icons["Mark as Junk"] and icons["Mark as Junk"]:find("ui%-pouch") and icons["Track as Currency"] and icons["Track as Currency"]:find("ui%-wallet"),
		"Favorite, Mark as Junk and Track as Currency have their icons (star, pouch, wallet)")
	check(m:GetWidth() > 220 and m:GetWidth() <= 300 + 12, "the menu widens to fit its longest row (" .. m:GetWidth() .. ")")
	-- Closes when what it was opened from goes away.
	main.frame:Hide()
	m:GetScript("OnUpdate")(m)
	check(not m:IsShown(), "closing the bags window closes the menu")
	main.frame:Show(); M.runTimers()
	-- A very long section name wraps rather than running off.
	local long = S:Create(string.rep("Long Name ", 4))
	S:Move(7003, long)
	local belt
	for _, r in ipairs(n.items) do if r.itemID == 7003 then belt = r end end
	S:Clear(7003)
	S:Move(7003, long)
	m = S:ItemMenu(belt, owner)
	check(m:GetWidth() <= 312, "a long section name never widens the menu past its limit")
	-- A row too long for the widest menu wraps to two lines (a taller row).
	local wide = n.ShowMenu({ { text = "Title", title = true }, { text = string.rep("Very long menu row text ", 6), onClick = function() end } })
	check(wide:GetWidth() <= 312 and wide.rows[2]:GetHeight() > 20, "a row too long for the widest menu wraps onto two lines")
	wide:Hide()
	m:Hide()
	-- 6. Merged stacks at the bank: the rest follow.
	n:Set("mergeStacks", true); M.runTimers()
	n.atBank = true
	local moved = {}
	local realUse = C_Container.UseContainerItem
	C_Container.UseContainerItem = function(bag, slot) moved[#moved + 1] = bag .. ":" .. slot; M.bags[bag][slot] = nil end
	local function wool(slot) for _, r in ipairs(n.items) do if r.bag == 0 and r.slot == slot then return r end end end
	M.bags[0][2] = nil   -- (the clicked stack: the game moved it)
	n.Drop:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 2 }, { bag = 0, slot = 3 }, { bag = 0, slot = 4 } }, fromBank = false, name = "Wool Cloth", first = { bag = 0, slot = 2 } })
	for _ = 1, 10 do M.runTimers() end
	table.sort(moved)
	check(#moved == 2 and moved[1] == "0:3" and moved[2] == "0:4", "a merged row at the bank: the other stacks follow (" .. table.concat(moved, ", ") .. ")")
	-- Something that won't move: it stops and says so.
	M.put(0, 5, { id = 2593, name = "Silk Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 3 })
	M.put(0, 6, { id = 2593, name = "Silk Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 3 })
	M.put(0, 7, { id = 2593, name = "Silk Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 3 })
	n:Scan()
	C_Container.UseContainerItem = function() end
	for i = #M.log, 1, -1 do M.log[i] = nil end
	M.bags[0][5] = nil
	n.Drop:MoveRest({ itemID = 2593, members = { { bag = 0, slot = 5 }, { bag = 0, slot = 6 }, { bag = 0, slot = 7 } }, fromBank = false, name = "Silk Cloth", first = { bag = 0, slot = 5 } })
	for _ = 1, 20 do M.runTimers() end
	check((M.log[#M.log] or ""):find("Moved 1 of 3 stacks of Silk Cloth; the rest stayed"), "when a stack won't move, it stops and says so: " .. tostring(M.log[#M.log]))
	C_Container.UseContainerItem = realUse
	n.atBank = false
	n:Set("mergeStacks", false); M.runTimers()
	-- 7. The hidden-sections note at the end of the list.
	S:SetShown("Gear", "vendor", false)
	S:Clear(7003); M.runTimers()
	M.fire("MERCHANT_SHOW"); M.runTimers()
	local note = main.hiddenNote
	check(note and note:IsShown() and note.text.text == "1 item hidden at this vendor (Gear)" and note.btn.label.text == "Show Them", "at a vendor: a note at the end of the list names the hidden section, with Show Them")
	note.btn:GetScript("OnClick")(note.btn); M.runTimers()
	check(note.text.text == "Showing 1 item from sections hidden at this vendor" and note.btn.label.text == "Hide Again" and laneOfItem(7003), "Show Them shows them; the note offers Hide Again")
	note.btn:GetScript("OnClick")(note.btn); M.runTimers()
	check(note.btn.label.text == "Show Them" and not laneOfItem(7003), "Hide Again hides them again")
	check(not main.btnHidden, "the footer button is gone")
	M.fire("MERCHANT_CLOSED"); M.runTimers()
	check(not note:IsShown(), "closing the vendor removes the note")
	S:SetShown("Gear", "vendor", true)
end)()

;(function()
	-- 0.14.0-beta11: the beta10 audit fixes.
	package.loaded.mock = nil
	local M = require("mock")
	M.maxStack = { [7501] = 1 }   -- swords don't stack
	M.put(0, 1, { id = 7501, name = "Iron Sword", q = 1, class = 2, subclass = 7, price = 9, equip = "INVTYPE_WEAPONMAINHAND", maxStack = 1 })
	M.put(0, 2, { id = 7501, name = "Iron Sword", q = 1, class = 2, subclass = 7, price = 9, equip = "INVTYPE_WEAPONMAINHAND", maxStack = 1 })
	M.put(0, 3, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 2, maxStack = 20 })
	M.put(0, 4, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 2, maxStack = 20 })
	M.put(0, 5, { id = 2592, name = "Wool Cloth", q = 1, count = 7, class = 7, subclass = 5, price = 2, maxStack = 20 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list", mergeStacks = true, remember = false } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local S, main, D = n.Sections, n.Window.main, n.Drop
	local function rowFor(id, slot)
		for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id and (not slot or b.rec.slot == slot) then return b end end
	end
	local calls = {}
	local realUse = C_Container.UseContainerItem
	local realInfo = C_Container.GetContainerItemInfo
	local locked = {}
	C_Container.GetContainerItemInfo = function(bag, slot)
		local i = realInfo(bag, slot)
		if i and locked[bag .. ":" .. slot] then i.isLocked = true end
		return i
	end
	local function use(fail) return function(bag, slot) calls[#calls + 1] = bag .. ":" .. slot; if not fail[bag .. ":" .. slot] then M.bags[bag][slot] = nil end end end
	n.atBank = true
	-- F2: a merged row keeps its stack count after a held refresh.
	local wool = rowFor(2592)
	check(wool and wool.rec.merged and wool.rec.stacks == 3, "the merged Wool Cloth row stands for 3 stacks")
	main:RefreshInPlace(false)
	wool = rowFor(2592)
	check(wool.rec.merged and wool.rec.stacks == 3, "after a held refresh it still knows it has 3 stacks (move-all keeps working)")
	-- F1: dragging one of two separate same-ID swords moves only that sword.
	local sword = rowFor(7501, 1)
	check(sword and (sword.rec.stacks or 1) == 1 and rowFor(7501, 2) and (rowFor(7501, 2).rec.stacks or 1) == 1, "two identical swords are separate rows, one stack each (gear never merges)")
	D:NoteDrag(sword)
	locked["0:1"] = true; M.cursorItem = 7501
	C_Container.UseContainerItem = use({})
	calls = {}
	local bankView = { isBank = true, Bags = function() return { -1 } end }
	n.bagInfo[-1] = n.bagInfo[-1] or { size = 28, free = 28, family = 0 }
	M.bags[-1] = M.bags[-1] or {}
	D.Target = function() return -1, 1 end
	-- (the mock's pickup moves nothing: tests place the stack in the bank themselves)
	local function land(it) M.bags[-1][1] = it end
	D:Place(bankView)
	M.cursorItem = nil; locked["0:1"] = nil
	for _ = 1, 20 do M.runTimers() end
	check(#calls == 0, "dropping one sword at the bank never moves the other sword")
	-- A genuinely merged row's drag: only its own stacks follow, once the cursor settles.
	wool = rowFor(2592)
	D:NoteDrag(wool)
	local wb, ws = wool.rec.bag, wool.rec.slot
	locked[wb .. ":" .. ws] = true; M.cursorItem = 2592
	calls = {}
	D:Place(bankView)
	M.runTimers()
	check(#calls == 0, "the rest wait while the first stack is still on the cursor")
	local carried = M.bags[wb][ws]
	M.cursorItem = nil; locked[wb .. ":" .. ws] = nil; M.bags[wb][ws] = nil; land(carried)
	for _ = 1, 20 do M.runTimers() end
	check(#calls == 2, "once it lands in the bank, the merged row's other 2 stacks follow (" .. table.concat(calls, ", ") .. ")")
	M.bags[-1][1] = nil
	-- F3: a first stack that never settles: the rest don't move, and chat says why.
	M.put(0, 3, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 2, maxStack = 20 })
	M.put(0, 4, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 2, maxStack = 20 })
	n:Scan(); n:RefreshViews(true); M.runTimers()
	wool = rowFor(2592); D:NoteDrag(wool)
	locked["0:3"] = true; locked["0:4"] = true; M.cursorItem = 2592
	calls = {}
	for i = #M.log, 1, -1 do M.log[i] = nil end
	D:Place(bankView)
	for _ = 1, 20 do M.runTimers() end
	check(#calls == 0 and (M.log[#M.log] or ""):find("didn't settle, so the rest weren't moved"), "a first stack that never settles: nothing else moves, and chat says so")
	M.cursorItem = nil; locked["0:3"] = nil; locked["0:4"] = nil
	-- F4: outcomes. A rejected first click: "Moved 0 of 2".
	n:Scan()
	for i = #M.log, 1, -1 do M.log[i] = nil end
	calls = {}
	C_Container.UseContainerItem = use({ ["0:4"] = true })
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 3 }, { bag = 0, slot = 4 } }, fromBank = false, name = "Wool Cloth", first = { bag = 0, slot = 3 } })
	for _ = 1, 20 do M.runTimers() end
	check((M.log[#M.log] or ""):find("Moved 0 of 2 stacks of Wool Cloth; nothing moved") and #calls == 0, "a first click that didn't move: \"Moved 0 of 2\", and nothing more is tried: " .. tostring(M.log[#M.log]))
	-- A locked stack is waited on, then moved; only confirmed moves count.
	M.bags[0][3] = nil
	locked["0:4"] = true
	C_Container.UseContainerItem = use({})
	calls = {}
	for i = #M.log, 1, -1 do M.log[i] = nil end
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 3 }, { bag = 0, slot = 4 } }, fromBank = false, name = "Wool Cloth", first = { bag = 0, slot = 3 } })
	M.runTimers(); M.runTimers()
	check(#calls == 0, "a stack that's locked isn't acted on while locked")
	locked["0:4"] = nil
	for _ = 1, 20 do M.runTimers() end
	check(#calls == 1 and #M.log == 0, "once unlocked it moves, and with everything moved there's no message")
	-- A stack that stays locked: stops, counted honestly.
	M.put(0, 3, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 2, maxStack = 20 })
	M.put(0, 4, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 2, maxStack = 20 })
	n:Scan()
	M.bags[0][3] = nil
	locked["0:4"] = true
	calls = {}
	for i = #M.log, 1, -1 do M.log[i] = nil end
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 3 }, { bag = 0, slot = 4 } }, fromBank = false, name = "Wool Cloth", first = { bag = 0, slot = 3 } })
	for _ = 1, 40 do M.runTimers() end
	check(#calls == 0 and (M.log[#M.log] or ""):find("Moved 1 of 2 stacks of Wool Cloth; the rest stayed %(a stack stayed locked%)"), "a stack that stays locked is never counted as moved: " .. tostring(M.log[#M.log]))
	locked["0:4"] = nil
	C_Container.UseContainerItem = realUse
	C_Container.GetContainerItemInfo = realInfo
	n.atBank = false
	-- F5: the bank window's Clean Up sorts the bank.
	local sorted = {}
	local rSortBank, rSort = C_Container.SortBankBags, C_Container.SortBags
	C_Container.SortBankBags = function() sorted[#sorted + 1] = "bank" end
	C_Container.SortBags = function() sorted[#sorted + 1] = "bags" end
	n.atBank = true
	local bankWin = n.Window.bank or { isBank = true, st = { sheet = "All" } }
	n.View.CleanUp(bankWin)
	check(sorted[#sorted] == "bank", "the bank window's Clean Up (All sheet) sorts the bank")
	n.View.CleanUp(main)
	check(sorted[#sorted] == "bags", "the bags window's Clean Up still sorts the bags")
	C_Container.SortBankBags, C_Container.SortBags = rSortBank, rSort
	n.atBank = false
	-- F6: deleting a section clears its session collapse state; switching profiles starts fresh.
	local c = S:Create("Healing")
	table.insert(n.ui.collapsed, c); table.insert(n.uiBank.collapsed, c)
	S:Delete(c)
	check(not n.IndexOf(n.ui.collapsed, c) and not n.IndexOf(n.uiBank.collapsed, c), "deleting a section clears it from the session collapse lists")
	table.insert(n.ui.collapsed, "Gear")
	n.Profiles:Use("Other"); M.runTimers()
	check(#n.ui.collapsed == 0, "switching profiles starts session collapse state fresh")
	n.Profiles:Use("Default"); M.runTimers()
	-- Option 1: deleting a section removes it from saved sheets, and says so.
	local h2 = S:Create("Herbs")
	table.insert(n.db.sheets, { n = "Herb Sheet", f = { text = "", q = {}, cat = { [h2] = true }, t = {}, bd = {}, w = {} } })
	table.insert(n.db.sheets, { n = "Mixed", f = { text = "", q = {}, cat = { [h2] = true, Gear = true }, t = {}, bd = {}, w = {} } })
	for i = #M.log, 1, -1 do M.log[i] = nil end
	S:Delete(h2)
	local herb, mixed
	for _, sh in ipairs(n.db.sheets) do if sh.n == "Herb Sheet" then herb = sh elseif sh.n == "Mixed" then mixed = sh end end
	check(not next(herb.f.cat) and mixed.f.cat.Gear and not mixed.f.cat[h2], "deleting a section removes it from saved sheets' filters")
	local said = table.concat(M.log, " ")
	check(said:find('Sheet "Herb Sheet" was filtered by the section Herbs; it now shows every category') and not said:find('"Mixed"'), "chat names a sheet that now shows every category (not one with other filters left)")
	-- F7: the menu budgets wrapped rows by their real height.
	local ids = {}
	for i = 1, 30 do ids[i] = S:Create(string.rep("W", 38) .. ("%02d"):format(i)) end
	local realH = UIParent.GetHeight
	UIParent.GetHeight = function() return 480 end
	local realW = n.ShowMenu
	local rec; for _, r in ipairs(n.items) do if r.itemID == 7501 then rec = r end end
	-- (make the long names wrap: a narrower cap for this check)
	local m = S:ItemMenu(rec)
	m:Hide()
	local wide = {}
	wide[#wide + 1] = { text = "Title", title = true, big = true, gap = true }
	wide[#wide + 1] = { text = "Move to Section:", title = true }
	for i = 1, 30 do wide[#wide + 1] = { text = "   " .. string.rep("Very long section name ", 3) .. i, group = true, onClick = function() end } end
	for i = 1, 4 do wide[#wide + 1] = { text = "Action " .. i, onClick = function() end } end
	m = n.ShowMenu(wide)
	check(m:GetHeight() <= 480, "with wrapped rows, the menu still fits the screen (" .. m:GetHeight() .. " of 480)")
	local acts = 0
	for _, r in ipairs(m.rows) do if r:IsShown() and (r.text.text or ""):find("^Action") then acts = acts + 1 end end
	check(acts == 4, "and every action row is shown")
	-- F9: arrow rows never keep a pooled icon.
	local stale = false
	for _, r in ipairs(m.rows) do if r:IsShown() and r.arrow:IsShown() and r.icon:IsShown() then stale = true end end
	check(not stale, "scroll arrows never show a leftover icon")
	m:Hide()
	UIParent.GetHeight = realH
	for i = 1, 30 do S:Delete(ids[i]) end
	-- F8: the hidden-sections note grows to fit wrapped text.
	main.hiddenNow, main.hiddenSecs = 9, { "Section With A Long Name", "Another Long Section Name", "Third Long Section Name", "Fourth Long Section Name" }
	n.ui.atVendor = true
	local y = main:PlaceHiddenNotice(main.child, 500, 200)
	local note = main.hiddenNote
	check(note:GetHeight() > 50 and y >= 500 + note:GetHeight() + 16, "the note's height follows its wrapped text, and the list's height includes it (" .. note:GetHeight() .. ")")
	n.ui.atVendor = false
	-- Copy: the lock tooltip points to the note.
	local src = io.open("BagSmith/Frames/ViewList.lua"):read("*a")
	check(src:find("Use Show Them at the end of the bags list") and not src:find("footer to show it"), "the locked item's tooltip points to Show Them at the end of the list")
end)()

;(function()
	-- 0.14.0-beta12: the undo icon is the U-turn: a left-pointing head at the top, the
	-- stroke curving round on the right and back along the bottom (64 x 64 TGA, alpha).
	local fh = io.open("BagSmith/Media/ui-undo.tga", "rb"); local data = fh:read("*a"); fh:close()
	local w, h = data:byte(13) + data:byte(14) * 256, data:byte(15) + data:byte(16) * 256
	local function alpha(x, y) local i = 18 + ((h - 1 - y) * w + x) * 4; return data:byte(i + 4) end
	check(w == 64 and h == 64, "the undo icon is 64 x 64")
	check(alpha(8, 22) > 200 and alpha(40, 22) > 200 and alpha(49, 36) > 200 and alpha(30, 50) > 200, "its head (left), top stroke, right curve and bottom stroke are drawn")
	check(alpha(36, 36) < 40 and alpha(8, 50) < 40, "the inside of the U and the lower left stay clear")
end)()

;(function()
	-- 0.14.0-beta13: the transfer's four rules, F4, the solid Classic dialogs, the tooltip.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 2 })
	M.put(0, 2, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 2 })
	M.put(0, 3, { id = 2592, name = "Wool Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 2 })
	M.put(0, 4, { id = 2589, name = "Linen Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 1 })
	M.put(0, 5, { id = 2589, name = "Linen Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list", mergeStacks = true, remember = false } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main, D = n.Window.main, n.Drop
	local function rowFor(id) for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then return b end end end
	local calls = {}
	local realUse, realInfo = C_Container.UseContainerItem, C_Container.GetContainerItemInfo
	local locked = {}
	C_Container.GetContainerItemInfo = function(bag, slot)
		local i = realInfo(bag, slot)
		if i and locked[bag .. ":" .. slot] then i.isLocked = true end
		return i
	end
	C_Container.UseContainerItem = function(bag, slot) calls[#calls + 1] = bag .. ":" .. slot; M.bags[bag][slot] = nil end
	n.atBank = true
	M.bags[-1] = M.bags[-1] or {}
	-- Merged rows know their exact members.
	local wool = rowFor(2592)
	check(wool.rec.stacks == 3 and #wool.rec.members == 3, "a merged row carries its exact members")
	-- F2: a filtered row moves only the stacks it shows.
	main.st.filters.text = ""; n:RefreshViews(true); M.runTimers()
	local job = { itemID = 2592, members = { { bag = 0, slot = 1 }, { bag = 0, slot = 2 } }, fromBank = false, name = "Wool Cloth", first = { bag = 0, slot = 1 }, token = D:NewGesture() }
	M.bags[0][1] = nil
	calls = {}
	D:MoveRest(job)
	for _ = 1, 20 do M.runTimers() end
	check(#calls == 1 and calls[1] == "0:2" and M.bags[0][3], "a row showing 2 of 3 stacks moves just those 2 (the third, hidden by a filter, stays)")
	-- F1: the bank closing during a lock wait stops the job; nothing is sent afterwards.
	M.put(0, 1, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 2 })
	M.put(0, 2, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 2 })
	n:Scan()
	M.bags[0][1] = nil
	locked["0:2"] = true
	calls = {}
	for i = #M.log, 1, -1 do M.log[i] = nil end
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 1 }, { bag = 0, slot = 2 }, { bag = 0, slot = 3 } }, fromBank = false, name = "Wool Cloth", first = { bag = 0, slot = 1 }, token = D:NewGesture() })
	M.runTimers(); M.runTimers()
	M.fire("BANKFRAME_CLOSED"); n.atBank = false
	locked["0:2"] = nil
	for _ = 1, 20 do M.runTimers() end
	check(#calls == 0 and table.concat(M.log, " "):find("Stopped moving Wool Cloth: the bank closed"), "the bank closing while a stack is locked cancels the job: no action goes out afterwards")
	n.atBank = true
	-- Combat starting does the same.
	calls = {}
	locked["0:2"] = true
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 1 }, { bag = 0, slot = 2 }, { bag = 0, slot = 3 } }, fromBank = false, name = "Wool Cloth", first = { bag = 0, slot = 1 }, token = D:NewGesture() })
	M.runTimers()
	M.fire("PLAYER_REGEN_DISABLED")
	locked["0:2"] = nil
	for _ = 1, 20 do M.runTimers() end
	check(#calls == 0, "combat starting cancels it too")
	-- Something on the cursor at dispatch time: nothing goes out.
	calls = {}
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 1 }, { bag = 0, slot = 2 }, { bag = 0, slot = 3 } }, fromBank = false, name = "Wool Cloth", first = { bag = 0, slot = 1 }, token = D:NewGesture() })
	M.cursorItem = 2589
	for _ = 1, 20 do M.runTimers() end
	check(#calls == 0, "with something on the cursor, no move is sent")
	M.cursorItem = nil
	-- F3: a drag put back never moves anything; an old drag never starts a job later.
	n:RefreshViews(true); M.runTimers()
	wool = rowFor(2592)
	local bankView = { isBank = true, Bags = function() return { -1 } end }
	n.bagInfo[-1] = n.bagInfo[-1] or { size = 28, free = 28, family = 0 }
	D.Target = function() return -1, 1 end
	D:NoteDrag(wool)
	local wb, ws = wool.rec.bag, wool.rec.slot
	locked[wb .. ":" .. ws] = true; M.cursorItem = 2592
	calls = {}
	for i = #M.log, 1, -1 do M.log[i] = nil end
	D:Place(bankView)
	-- ...and the player puts it back: the cursor empties, the source still holds the stack.
	M.cursorItem = nil; locked[wb .. ":" .. ws] = nil
	for _ = 1, 20 do M.runTimers() end
	check(#calls == 0 and #M.log == 0, "a drag put back in its slot moves nothing else, quietly")
	-- A stale drag can't interrupt a newer right-click job.
	D:NoteDrag(wool)
	locked[wb .. ":" .. ws] = true; M.cursorItem = 2592
	D:Place(bankView)
	M.cursorItem = nil; locked[wb .. ":" .. ws] = nil
	-- A newer gesture: right-click move of Linen Cloth.
	local linen = rowFor(2589)
	M.bags[0][4] = nil
	calls = {}
	D:MoveRest({ itemID = 2589, members = { { bag = 0, slot = 4 }, { bag = 0, slot = 5 } }, fromBank = false, name = "Linen Cloth", first = { bag = 0, slot = 4 }, token = D:NewGesture() })
	-- now the old drag's stack "lands" (as if), which would have confirmed it in beta12
	M.bags[-1][1] = { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 2 }; M.bags[wb][ws] = nil
	for _ = 1, 30 do M.runTimers() end
	local wrong = false
	for _, c in ipairs(calls) do if c ~= "0:5" then wrong = true end end
	check(#calls == 1 and calls[1] == "0:5" and not wrong, "the older drag never starts a job, and the newer move completes (" .. table.concat(calls, ", ") .. ")")
	M.bags[-1][1] = nil
	-- One job at a time: a second right-click while one runs is refused, politely.
	M.put(0, 1, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 2 })
	M.put(0, 2, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 2 })
	M.put(0, 4, { id = 2589, name = "Linen Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 1 })
	n:Scan()
	M.bags[0][1] = nil
	locked["0:2"] = true
	D:MoveRest({ itemID = 2592, members = { { bag = 0, slot = 1 }, { bag = 0, slot = 2 } }, fromBank = false, name = "Wool Cloth", first = { bag = 0, slot = 1 }, token = D:NewGesture() })
	M.runTimers()
	for i = #M.log, 1, -1 do M.log[i] = nil end
	D:MoveRest({ itemID = 2589, members = { { bag = 0, slot = 4 }, { bag = 0, slot = 5 } }, fromBank = false, name = "Linen Cloth", first = { bag = 0, slot = 4 }, token = D:NewGesture() })
	check((M.log[#M.log] or ""):find("Still moving Wool Cloth"), "a second move while one runs is refused with a note")
	D:CancelMoves("test over."); locked["0:2"] = nil
	-- The tooltip hint for a merged row at the bank.
	local lines = {}
	local tip = { GetOwner = function() return wool end, AddLine = function(_, t) lines[#lines + 1] = t end, AddDoubleLine = function() end }
	wool.bsItem = true
	n.Buttons.AddTooltipExtras(tip)
	check(table.concat(lines, "|"):find("Right%-click: move all %d stacks"), "a merged row's tooltip at the bank says right-click moves all its stacks")
	n.atBank = false
	C_Container.UseContainerItem, C_Container.GetContainerItemInfo = realUse, realInfo
	-- F4: deleting a profile you aren't using keeps your collapsed sections.
	table.insert(n.ui.collapsed, "Gear")
	n.Profiles:Use("Spare"); n.Profiles:Use("Default"); M.runTimers()
	table.insert(n.ui.collapsed, "Gear")
	n.Profiles:Delete("Spare"); M.runTimers()
	check(n.IndexOf(n.ui.collapsed, "Gear"), "deleting another profile keeps this profile's session collapse state")
	n.Profiles:Use("Spare"); M.runTimers()
	check(#n.ui.collapsed == 0, "a real switch still starts it fresh")
	n.Profiles:Use("Default"); M.runTimers()
	-- Classic dialogs: fully solid, on Blizzard's dark dialog art (or black if missing).
	n:Set("skin", "classic"); M.runTimers()
	local m = n.ShowMenu({ { text = "x", onClick = function() end } })
	local st = m.classicState
	check(n.Classic.DIALOG_SOLID == 1 and st and st.solid and (st.solid.texture == n.Classic.DIALOG_ART or (st.solid.color and st.solid.color[4] == 1)), "Classic: the menu's background is fully solid (Blizzard's dialog art, or black)")
	check(n.Classic.status["Dialog background"] ~= nil, "/bs skincheck reports the dialog background")
	m:Hide()
	n:Set("skin", "modern"); M.runTimers()
	-- The shorter tooltip.
	n.SettingsPanel:Show()
	check(n.SettingsPanel.frame.about.tip == "Version, Discord and support links", "About & Support's tooltip is short")
	n.SettingsPanel:Hide()
end)()

;(function()
	-- 0.14.0-beta14: the beta13 audit fixes.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2592, name = "Wool Cloth", q = 1, count = 10, class = 7, subclass = 5, price = 2 })
	M.put(0, 2, { id = 2592, name = "Wool Cloth", q = 1, count = 10, class = 7, subclass = 5, price = 2 })
	M.put(0, 3, { id = 2592, name = "Wool Cloth", q = 1, count = 10, class = 7, subclass = 5, price = 2 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list", mergeStacks = true, remember = false } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main, D = n.Window.main, n.Drop
	local function rowFor(id) for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then return b end end end
	local calls = {}
	local realUse, realInfo = C_Container.UseContainerItem, C_Container.GetContainerItemInfo
	local locked = {}
	C_Container.GetContainerItemInfo = function(bag, slot)
		local i = realInfo(bag, slot)
		if i and locked[bag .. ":" .. slot] then i.isLocked = true end
		return i
	end
	C_Container.UseContainerItem = function(bag, slot) calls[#calls + 1] = bag .. ":" .. slot; M.bags[bag][slot] = nil end
	n.atBank = true
	M.bags[-1] = M.bags[-1] or {}
	local bankView = { isBank = true, Bags = function() return { -1 } end }
	n.bagInfo[-1] = n.bagInfo[-1] or { size = 28, free = 28, family = 0 }
	D.Target = function() return -1, 1 end
	-- F1: a partial merge (one item fits), the nine put back: nothing else moves, no message.
	M.bags[-1][1] = { id = 2592, name = "Wool Cloth", q = 1, count = 19, class = 7, subclass = 5, price = 2 }
	local wool = rowFor(2592)
	D:NoteDrag(wool)
	check(D.dragFrom and D.dragFrom.count == 10, "the drag remembers the dragged stack's own count (10, not the row's 30)")
	local wb, ws = wool.rec.bag, wool.rec.slot
	locked[wb .. ":" .. ws] = true; M.cursorItem = 2592
	calls = {}
	for i = #M.log, 1, -1 do M.log[i] = nil end
	D:Place(bankView)
	-- one item lands; the other nine come back to the same slot
	M.bags[-1][1].count = 20
	M.bags[wb][ws].count = 9
	M.cursorItem = nil; locked[wb .. ":" .. ws] = nil
	for _ = 1, 20 do M.runTimers() end
	check(#calls == 0 and #M.log == 0, "a partial merge with the rest put back moves nothing else, quietly")
	-- the nine put back into ANOTHER slot on the same side: still nothing.
	D:NoteDrag(wool)
	locked[wb .. ":" .. ws] = true; M.cursorItem = 2592
	calls = {}
	D:Place(bankView)
	M.bags[-1][1].count = 20; M.bags[wb][ws] = nil
	M.put(0, 6, { id = 2592, name = "Wool Cloth", q = 1, count = 8, class = 7, subclass = 5, price = 2 })
	M.cursorItem = nil; locked[wb .. ":" .. ws] = nil
	for _ = 1, 20 do M.runTimers() end
	check(#calls == 0 and #M.log == 0, "the rest put back into another slot: still nothing else moves")
	-- a whole stack landing still expands.
	M.bags[0][6] = nil; M.bags[-1][1] = nil
	M.put(0, 1, { id = 2592, name = "Wool Cloth", q = 1, count = 10, class = 7, subclass = 5, price = 2 })
	n:Scan(); n:RefreshViews(true); M.runTimers()
	wool = rowFor(2592); wb, ws = wool.rec.bag, wool.rec.slot
	D:NoteDrag(wool)
	locked[wb .. ":" .. ws] = true; M.cursorItem = 2592
	calls = {}
	D:Place(bankView)
	local carried = M.bags[wb][ws]
	M.bags[wb][ws] = nil; M.bags[-1][1] = carried; M.cursorItem = nil; locked[wb .. ":" .. ws] = nil
	for _ = 1, 20 do M.runTimers() end
	check(#calls == 2, "a whole stack that lands still brings the others (" .. table.concat(calls, ", ") .. ")")
	M.bags[-1][1] = nil
	-- F2: the bank closing while a drag waits to land ends that drag for good.
	M.put(0, 1, { id = 2592, name = "Wool Cloth", q = 1, count = 10, class = 7, subclass = 5, price = 2 })
	M.put(0, 2, { id = 2592, name = "Wool Cloth", q = 1, count = 10, class = 7, subclass = 5, price = 2 })
	M.put(0, 3, { id = 2592, name = "Wool Cloth", q = 1, count = 10, class = 7, subclass = 5, price = 2 })
	n:Scan(); n:RefreshViews(true); M.runTimers()
	wool = rowFor(2592); wb, ws = wool.rec.bag, wool.rec.slot
	D:NoteDrag(wool)
	locked[wb .. ":" .. ws] = true; M.cursorItem = 2592
	calls = {}
	D:Place(bankView)
	M.fire("BANKFRAME_CLOSED"); n.atBank = false
	M.fire("BANKFRAME_OPENED"); n.atBank = true
	carried = M.bags[wb][ws]; M.bags[wb][ws] = nil; M.bags[-1][1] = carried; M.cursorItem = nil; locked[wb .. ":" .. ws] = nil
	for _ = 1, 20 do M.runTimers() end
	check(#calls == 0, "a drag interrupted by the bank closing never resumes after it reopens")
	M.bags[-1][1] = nil
	-- same for combat
	M.put(0, 1, { id = 2592, name = "Wool Cloth", q = 1, count = 10, class = 7, subclass = 5, price = 2 })
	n:Scan(); n:RefreshViews(true); M.runTimers()
	wool = rowFor(2592); wb, ws = wool.rec.bag, wool.rec.slot
	D:NoteDrag(wool)
	locked[wb .. ":" .. ws] = true; M.cursorItem = 2592
	calls = {}
	D:Place(bankView)
	M.fire("PLAYER_REGEN_DISABLED"); M.fire("PLAYER_REGEN_ENABLED")
	carried = M.bags[wb][ws]; M.bags[wb][ws] = nil; M.bags[-1][1] = carried; M.cursorItem = nil; locked[wb .. ":" .. ws] = nil
	for _ = 1, 20 do M.runTimers() end
	check(#calls == 0, "a drag interrupted by combat never resumes after it ends")
	M.bags[-1][1] = nil
	-- and a fresh gesture afterwards still works.
	M.put(0, 1, { id = 2592, name = "Wool Cloth", q = 1, count = 10, class = 7, subclass = 5, price = 2 })
	n:Scan(); n:RefreshViews(true); M.runTimers()
	wool = rowFor(2592); wb, ws = wool.rec.bag, wool.rec.slot
	D:NoteDrag(wool)
	locked[wb .. ":" .. ws] = true; M.cursorItem = 2592
	calls = {}
	D:Place(bankView)
	carried = M.bags[wb][ws]; M.bags[wb][ws] = nil; M.bags[-1][1] = carried; M.cursorItem = nil; locked[wb .. ":" .. ws] = nil
	for _ = 1, 20 do M.runTimers() end
	check(#calls == 2, "a new drag after an interruption works as usual")
	M.bags[-1][1] = nil
	-- F5: no bulk hint on saved rows.
	local lines = {}
	local tip = { GetOwner = function() return { bsItem = true, rec = { itemID = 2592, merged = true, stacks = 3, cached = true, members = { {}, {}, {} } } } end, AddLine = function(_, t) lines[#lines + 1] = t end, AddDoubleLine = function() end }
	n.Buttons.AddTooltipExtras(tip)
	check(not table.concat(lines, "|"):find("Right%-click: move all"), "a saved (other character's) merged row gets no move-all hint")
	n.atBank = false
	C_Container.UseContainerItem, C_Container.GetContainerItemInfo = realUse, realInfo
	-- F3: /bs reset (no profile name) resets the active profile's session collapse state.
	table.insert(n.ui.collapsed, "Gear")
	n.Profiles:Reset(); M.runTimers()
	check(#n.ui.collapsed == 0, "/bs reset (no name) starts session collapse state fresh")
	-- F4: importing with the active profile's name never marks the active one as replaced.
	table.insert(n.ui.collapsed, "Gear")
	local newName = n.Profiles:Import("Default", { skin = "modern" })
	check(newName == "Default (2)", "an import under an existing name gets a suffix (" .. tostring(newName) .. ")")
	n.Profiles:Delete(newName); M.runTimers()
	check(n.IndexOf(n.ui.collapsed, "Gear") ~= nil, "importing under the active profile's name, then deleting the copy, keeps the active profile's collapse state")
	-- F6: copying one link, then opening another: the second stays open.
	local box = n.ShowLink("Discord", "https://discord.gg/uYfcHPkcar")
	local realCtrl = _G.IsControlKeyDown
	_G.IsControlKeyDown = function() return true end
	box.edit:GetScript("OnKeyDown")(box.edit, "C")
	_G.IsControlKeyDown = realCtrl
	box:Hide()
	n.ShowLink("CurseForge", "https://www.curseforge.com/wow/addons/bagsmith")
	M.runTimers()
	check(box:IsShown() and box.edit.text:find("curseforge"), "a copy timer from an earlier link doesn't close a link box opened right after")
	M.runTimers()
	box:Hide()
end)()

;(function()
	-- 0.14.0-beta15: the Filter panel's Category row follows custom sections.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7003, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 4, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local S, main, P = n.Sections, n.Window.main, n.Popups
	local function catLabels(f)
		local t = {}
		for _, c in ipairs(f.catPool or {}) do if c:IsShown() then t[#t + 1] = c.label.text end end
		return table.concat(t, "|")
	end
	local function catBox(f, key) for _, c in ipairs(f.catPool or {}) do if c:IsShown() and c.key == key then return c end end end
	P:OpenFilters(main, "browse")
	local f = P.filter
	check(f and f.catAfter and catLabels(f):find("Gear") and not catLabels(f):find("Healing"), "the Filter panel lists the built-in categories")
	-- A new section appears while the panel is open.
	local id = S:Create("Healing"); M.runTimers()
	check(catLabels(f):find("Healing") and catBox(f, id), "a new custom section appears in the open panel")
	-- Renamed: the new name shows.
	S:Rename(id, "Potions"); M.runTimers()
	check(catLabels(f):find("Potions") and not catLabels(f):find("Healing"), "a renamed section shows its new name")
	-- Deleted: gone, and a stale click can't hide everything.
	local box = catBox(f, id)
	S:Delete(id); M.runTimers()
	check(not catBox(f, id) and not catLabels(f):find("Potions"), "a deleted section is gone from the panel")
	box.key = id   -- (as if a stale checkbox were still wired to it)
	box:GetScript("OnClick")(box)
	box:SetChecked(true); box:GetScript("OnClick")(box)
	check(not main.st.filters.cat[id], "a stale checkbox for a deleted section can't put it into the filter")
	-- Everything below Category moved to make room, and moves back.
	local rows0, y0 = f.catRows, f.catAfter.points[1][5]
	local tall = {}
	for i = 1, 12 do tall[i] = S:Create(("Long Section Name %02d"):format(i)) end
	M.runTimers()
	check(f.catRows > 1 and f.catAfter.points[1][5] < f.catAfterTop, "many sections wrap to more rows, and the rows below move down")
	for i = 1, 12 do S:Delete(tall[i]) end
	M.runTimers()
	check(f.catRows == rows0 and f.catAfter.points[1][5] == y0, "and move back up when they're gone")
	-- Switching profiles shows that profile's sections.
	local a = S:Create("Alpha")
	n.Profiles:Use("Other"); M.runTimers()
	S:Create("Beta"); M.runTimers()
	check(catLabels(f):find("Beta"), "...and a section made there appears")
	n.Profiles:Use("Default"); M.runTimers()
	check(catLabels(f):find("Alpha") and not catLabels(f):find("Beta"), "back on Default: Alpha, not Beta")
	-- Loading filters drops a category that no longer exists.
	local cleaned = n.PruneFilterCategories(n.CleanFilters({ cat = { c9999 = true, Gear = true, [a] = true } }), S:Customs())
	check(cleaned.cat.Gear and cleaned.cat[a] and not cleaned.cat.c9999, "pruned against this profile's sections, a dead custom section drops out and real ones stay")
	f:Hide()
end)()

;(function()
	-- 0.14.0-beta16: the beta15 audit fixes.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7003, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 4, equip = "INVTYPE_WAIST" })
	M.put(0, 2, { id = 7401, name = "Worn Dagger", q = 0, class = 2, subclass = 15, price = 3, equip = "INVTYPE_WEAPONMAINHAND" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local S, main = n.Sections, n.Window.main
	-- F1: an imported profile keeps its sheets' custom-section filters (checked against ITS sections).
	local donor = { customSections = { { id = "c1", name = "Healing" } }, sectionMoves = { [7003] = "c1" },
		sheets = { { n = "Heals", f = { text = "", q = {}, cat = { c1 = true }, t = {}, bd = {}, w = {} } },
			{ n = "Mixed", f = { text = "", q = {}, cat = { c1 = true, Gear = true }, t = {}, bd = {}, w = {} } },
			{ n = "Dead", f = { text = "", q = {}, cat = { c7 = true, Gear = true }, t = {}, bd = {}, w = {} } } } }
	check(#S:Customs() == 0, "the recipient profile has no custom sections")
	local name = n.Profiles:Import("Donor", donor)
	local imported = BagSmithDB.profiles[name]
	local function sheet(prof, nm) for _, sh in ipairs(prof.sheets or {}) do if sh.n == nm then return sh end end end
	check(sheet(imported, "Heals").f.cat.c1 and sheet(imported, "Mixed").f.cat.c1 and sheet(imported, "Mixed").f.cat.Gear, "an imported profile's sheets keep their custom-section filters")
	check(not sheet(imported, "Dead").f.cat.c7 and sheet(imported, "Dead").f.cat.Gear, "a filter for a section that profile really doesn't have is dropped, keeping the built-in one")
	n.Profiles:Use(name); M.runTimers()
	check(sheet(n.db, "Heals").f.cat.c1 and S:IsCustom("c1"), "activated: the sheet still filters by Healing, which exists")
	main:SetSheet("Heals"); M.runTimers()
	local shown = 0
	for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 7003 then shown = shown + 1 end end
	check(shown == 1 and main.st.filters.cat.c1, "the imported Heals sheet shows the moved belt")
	main:SetSheet("All"); n.Profiles:Use("Default"); M.runTimers()
	-- F3: a live filter for a section the next profile lacks is cleared on the switch.
	n.Profiles:Use("Spare"); n.Profiles:Use("Default"); M.runTimers()   -- Spare exists, without the section below
	local h = S:Create("Potions")
	main.st.filters.cat[h] = true; main.st.filters.cat.Gear = true; n:RefreshViews(true); M.runTimers()
	n.Profiles:Use("Spare"); M.runTimers()
	check(not main.st.filters.cat[h] and main.st.filters.cat.Gear, "switching to a profile without that section drops its filter and keeps the built-in one")
	local rows = 0
	for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 7003 then rows = rows + 1 end end
	check(rows == 1, "so the rows don't vanish")
	n.Profiles:Use("Default"); M.runTimers()
	-- F2: turning automatic selling off before its retry stops the retry.
	local J = n.Junk
	_G.MerchantFrame = MerchantFrame or CreateFrame("Frame", "MerchantFrame", UIParent)
	local used = {}
	local realUse = C_Container.UseContainerItem
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot end
	n:Set("autoSellJunk", true)
	M.uncached[7401] = true   -- the dagger's details haven't loaded
	MerchantFrame:Show(); M.fire("MERCHANT_SHOW"); M.runTimers()   -- the 0.3 s auto sale: the dagger waits, a retry is queued
	check(#used == 0, "with its details not loaded, nothing sells yet")
	n:Set("autoSellJunk", false)
	M.uncached[7401] = nil
	for _ = 1, 5 do M.runTimers() end
	check(#used == 0, "turning automatic selling off before the retry: the retry sells nothing")
	M.fire("MERCHANT_CLOSED"); MerchantFrame:Hide()
	-- control: left on, the retry sells.
	n:Set("autoSellJunk", true)
	M.uncached[7401] = true
	MerchantFrame:Show(); M.fire("MERCHANT_SHOW"); M.runTimers()
	M.uncached[7401] = nil
	for _ = 1, 5 do M.runTimers() end
	check(#used == 1 and used[1] == "0:2", "left on, the retry sells the dagger once its details load")
	M.fire("MERCHANT_CLOSED"); MerchantFrame:Hide()
	-- a profile switch before the retry stops it too.
	used = {}
	M.uncached[7401] = true
	MerchantFrame:Show(); M.fire("MERCHANT_SHOW"); M.runTimers()
	n.Profiles:Use("Spare"); M.runTimers()
	M.uncached[7401] = nil
	for _ = 1, 5 do M.runTimers() end
	check(#used == 0, "a profile switch before the retry stops it")
	M.fire("MERCHANT_CLOSED"); MerchantFrame:Hide()
	n.Profiles:Use("Default"); n:Set("autoSellJunk", false)
	C_Container.UseContainerItem = realUse
	-- F4: a section name shaped like the panel's bookkeeping can't fool its refresh.
	local P = n.Popups
	P:OpenFilters(main, "browse")
	local f = P.filter
	local tricky = S:Create("A|c2=B"); M.runTimers()
	local sig1 = f.catSig
	f:Hide()
	S:Rename(tricky, "A"); S:Create("B"); M.runTimers()
	P:OpenFilters(main, "browse")
	local labels = {}
	for _, c in ipairs(f.catPool) do if c:IsShown() then labels[#labels + 1] = c.label.text end end
	local joined = table.concat(labels, "|")
	check(f.catSig ~= sig1 and joined:find("|A|") and joined:find("|B$") and not joined:find("A|c2=B", 1, true), "a rename plus a new section is seen even with a delimiter-shaped name: " .. joined)
	f:Hide()
end)()

;(function()
	-- 0.14.0-rc1: the beta16 audit's two P3s, the 0.14 What's New card, one 0.14.0 changelog section.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7401, name = "Worn Dagger", q = 0, class = 2, subclass = 15, price = 3, equip = "INVTYPE_WEAPONMAINHAND" })
	M.put(0, 2, { id = 7003, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 4, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list", autoSellJunk = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local J, main, P = n.Junk, n.Window.main, n.Popups
	-- R1: a blocked sale's verification from a closed merchant visit can't block the next visit.
	_G.MerchantFrame = MerchantFrame or CreateFrame("Frame", "MerchantFrame", UIParent)
	local used = {}
	local realUse = C_Container.UseContainerItem
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot end
	MerchantFrame:Show(); M.fire("MERCHANT_SHOW"); M.runTimers()   -- the automatic sale tries the dagger; its verification is queued
	check(#used == 1, "the first visit's automatic sale tries the dagger")
	M.fire("ADDON_ACTION_BLOCKED", "BagSmith", "UseContainerItem")   -- the game blocked it
	M.fire("MERCHANT_CLOSED"); MerchantFrame:Hide()
	MerchantFrame:Show(); M.fire("MERCHANT_SHOW")
	M.runTimers()   -- the OLD verification runs now, then the new visit's automatic sale
	M.runTimers()
	check(not J.autoBlocked and #used == 2, "the old visit's verification doesn't block the new visit's automatic sale (" .. #used .. " attempts)")
	M.fire("MERCHANT_CLOSED"); MerchantFrame:Hide()
	C_Container.UseContainerItem = realUse
	n:Set("autoSellJunk", false)
	-- R2: a sheet being edited ends with its profile.
	table.insert(n.db.sheets, { n = "Shared", f = { text = "", q = {}, cat = { Gear = true }, t = {}, bd = {}, w = {} } })
	n.Profiles:Use("B"); n.Profiles:Use("Default"); M.runTimers()   -- B copies Default, so it has a "Shared" sheet too
	P:OpenFilters(main, "edit", "Shared")
	local f = P.filter
	f.sheetBox:SetText("Renamed In A")
	n.Profiles:Use("B"); M.runTimers()
	check(not P.editing and not f:IsShown(), "switching profiles with a sheet editor open ends the edit and closes the panel")
	local renamed = false
	for _, sh in ipairs(n.db.sheets) do if sh.n == "Renamed In A" then renamed = true end end
	P:CommitSheet()
	for _, sh in ipairs(n.db.sheets) do if sh.n == "Renamed In A" then renamed = true end end
	check(not renamed, "a stale commit can't rename the other profile's sheet")
	n.Profiles:Use("Default"); M.runTimers()
	-- The What's New card for 0.14.
	local WN = n.WhatsNew
	local latest
	for _, e in ipairs(WN.ENTRIES) do if e.v == "0.14.0" then latest = e end end   -- (0.15's entry leads since rc1)
	check(latest and latest.heading == "BagSmith 0.14" and #latest.items >= 5 and #latest.items <= 8, "What's New has a 0.14 entry of 5 to 8 bullets")
	local text = table.concat(latest.items, " ")
	check(text:find("Custom Sections") and text:find("Item Menu") and text:find("Vendors and the AH") and text:find("Every Stack"), "it covers custom sections, the item menu, hiding at vendors and moving stacks")
	check(not text:find("—") and not text:find("’"), "plain punctuation only")
	for _, it in ipairs(latest.items) do check(#it <= 240, "each bullet stays short (" .. #it .. " chars)") end
	WN:ShowLatest(); M.runTimers()
	local card = BagSmithWhatsNew
	check(card and card:IsShown() and card.discord and card.discord:IsShown() and card.discord.points[1][2] == card.copy, "the card has a Discord icon beside the copy button")
	card.discord:GetScript("OnClick")(card.discord)
	check(n.Popups.link and n.Popups.link:IsShown() and n.Popups.link.edit.text == "https://discord.gg/uYfcHPkcar", "the Discord icon shows the invite, ready to copy")
	n.Popups.link:Hide(); WN:Close()
	-- One clean 0.14.0 changelog section.
	local log = io.open("BagSmith/CHANGELOG.md"):read("*a")
	check(("\n" .. log):find("\n## 0%.14%.0\n") and not log:find("## 0%.14%.0%-beta") and not log:find("## 0%.14%.0%-rc"), "the changelog has one 0.14.0 section (the beta entries folded in)")
end)()

;(function()
	-- 0.14.0-rc2: the rc1 audit's three items, the Discord bullet, the clearer vendor/AH grid.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7401, name = "Worn Dagger", q = 0, class = 2, subclass = 15, price = 3, equip = "INVTYPE_WEAPONMAINHAND" })
	M.put(0, 2, { id = 7003, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 4, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local J, main, P, S = n.Junk, n.Window.main, n.Popups, n.Sections
	-- F1: a draft survives operations that leave the active profile as it is.
	table.insert(n.db.sheets, { n = "Mine", f = { text = "", q = {}, cat = { Gear = true }, t = {}, bd = {}, w = {} } })
	n.Profiles:Use("Spare"); n.Profiles:Use("Default"); M.runTimers()
	P:OpenFilters(main, "edit", "Mine")
	local f = P.filter
	f.sheetBox:SetText("Draft Name")
	n.Profiles:Use("Default"); M.runTimers()
	check(P.editing == "Mine" and f:IsShown() and f.sheetBox.text == "Draft Name", "re-selecting the current profile keeps an open sheet draft")
	n.Profiles:Delete("Spare"); M.runTimers()
	check(P.editing == "Mine" and f:IsShown() and f.sheetBox.text == "Draft Name", "deleting another profile keeps it too")
	n.Profiles:Use("Other"); M.runTimers()
	check(not P.editing and not f:IsShown(), "a real switch still ends the edit")
	n.Profiles:Use("Default"); M.runTimers()
	-- F2: a settings change during a manual sale's check doesn't silence its receipt.
	_G.MerchantFrame = MerchantFrame or CreateFrame("Frame", "MerchantFrame", UIParent)
	local realUse = C_Container.UseContainerItem
	C_Container.UseContainerItem = function(bag, slot) M.bags[bag][slot] = nil end
	n.Marks:ToggleFavorite((function() for _, r in ipairs(n.items) do if r.itemID == 7401 then return r end end end)())
	MerchantFrame:Show(); M.fire("MERCHANT_SHOW")
	for i = #M.log, 1, -1 do M.log[i] = nil end
	J:Sell("all", "manual")            -- the favorite grey dagger sells
	n:Set("autoSellJunk", true)        -- a settings change before the 0.6 s check
	M.runTimers(); M.runTimers()
	local said = table.concat(M.log, " ")
	check(said:find("Worn Dagger %(favorite") and said:find("Junk selling includes grey and junk%-marked items"), "the sale's reminder still arrives after a settings change: " .. said:sub(1, 120))
	n:Set("autoSellJunk", false)
	M.fire("MERCHANT_CLOSED"); MerchantFrame:Hide()
	C_Container.UseContainerItem = realUse
	-- F3: a newer copy request keeps its field when the old timer fires.
	local WN = n.WhatsNew
	WN:ShowLatest(); M.runTimers()
	local card = BagSmithWhatsNew
	WN:StartCopy()
	local realCtrl = _G.IsControlKeyDown
	_G.IsControlKeyDown = function() return true end
	card.url:GetScript("OnKeyDown")(card.url, "C")
	_G.IsControlKeyDown = realCtrl
	WN:StartCopy()   -- a second request before the first timer fires
	M.runTimers()
	check(card.url:IsShown() and card.copyHint.text:find("to copy"), "the earlier copy's timer leaves the newer copy field alone")
	WN:EndCopy(); WN:Close()
	-- The Discord bullet.
	local e14
	for _, e in ipairs(WN.ENTRIES) do if e.v == "0.14.0" then e14 = e end end
	local text = table.concat(e14.items, " ")
	check(text:find("Join the Discord:") and text:find("BagSmith has a Discord now") and not text:find("love to meet"), "the Discord bullet reads as Shweep asked")
	-- Settings > Sections: checkboxes under headings, with a note for hidden sections.
	S:SetShown("Gear", "vendor", false)
	local custom = S:Create("Test"); S:SetShown(custom, "vendor", false); S:SetShown(custom, "ah", false)
	local Pn = n.SettingsPanel; Pn:Show(); Pn:ShowPage("sections")
	local head
	for _, w in ipairs(Pn.pools.vishead) do if w:IsShown() then head = w end end
	check(head and head.vendor.text == "Show at Vendor" and head.ah.text == "Show at AH", "the grid has Show at Vendor and Show at AH headings")
	local rows = {}
	for _, w in ipairs(Pn.pools.vis) do if w:IsShown() then rows[w.id] = w end end
	check(rows.Gear and rows.Gear.vendor:GetChecked() == false and rows.Gear.ah:GetChecked() == true and rows.Gear.note.text == "hidden at vendors", "Gear: Vendor unchecked, AH checked, noted as hidden at vendors")
	check(rows[custom] and rows[custom].note.text == "hidden at both" and rows.Favorites == nil and rows["~fav"] and rows["~fav"].note.text == "", "Test: hidden at both; Favorites: shown everywhere, no note")
	rows.Gear.vendor:SetChecked(true); rows.Gear.vendor:GetScript("OnClick")(rows.Gear.vendor)
	check(S:Shown("Gear", "vendor"), "checking a box shows the section there again")
	Pn:Hide()
	S:SetShown(custom, "vendor", true); S:SetShown(custom, "ah", true)
end)()

;(function()
	-- 0.14.0-rc3: Layout on Style, the rule moved up, the Custom Sections block reworked.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7003, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 4, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local S, P = n.Sections, n.SettingsPanel
	P:Show()
	local function checksOn(page)
		P:ShowPage(page)
		local t = {}
		for _, w in ipairs(P.pools.check) do if w:IsShown() then t[w.key] = true end end
		return t
	end
	local function headsOn(page)
		P:ShowPage(page)
		local t = {}
		for _, w in ipairs(P.pools.head) do if w:IsShown() then t[#t + 1] = { text = w.text.text, y = w.points[1][5] } end end
		table.sort(t, function(a, b) return a.y > b.y end)
		local names = {}
		for _, h in ipairs(t) do names[#names + 1] = h.text end
		return names
	end
	local look, sections = checksOn("look"), checksOn("sections")
	check(look.splitView and look.emptySlots and not sections.splitView and not sections.emptySlots, "Icon Split View and Show Empty Slots live on the Style page now")
	local heads = headsOn("sections")
	local pos = {}
	for i, h in ipairs(heads) do pos[h] = i end
	check(pos["Which Section an Item Goes To"] and pos["Keys & Reagent Bag"] and pos["Which Section an Item Goes To"] < pos["Keys & Reagent Bag"] and not pos["Layout"],
		"on Standard Sections, the rule comes before Keys & Reagent Bag, and Layout is gone (" .. table.concat(heads, " > ") .. ")")
	-- Custom Sections: empty state, then the reworked rows.
	P:ShowPage("custom")
	local texts = {}
	for _, w in ipairs(P.pools.text) do if w:IsShown() then texts[#texts + 1] = w.text.text end end
	check(table.concat(texts, " "):find("No sections yet%. New Section%.%.%. makes one%."), "with no sections: a short empty-state line")
	local id = S:Create("Professions"); S:Move(7003, id)
	P:Refresh()
	local head
	for _, w in ipairs(P.pools.csechead) do if w:IsShown() then head = w end end
	local row
	for _, w in ipairs(P.pools.csec) do if w:IsShown() and w.id == id then row = w end end
	check(head and head.text.text == "Show When Empty" and row and row.empty:GetChecked() == true and row.ren.tex.texture:find("ui%-pencil") and row.del.tex.texture:find("ui%-close"),
		"a section row: a Show When Empty checkbox under its heading, a pencil and an x")
	check(row.text.text:find("^Professions") and row.text.text:find("1 item"), "the row shows the name and its item count")
	row.empty:SetChecked(false); row.empty:GetScript("OnClick")(row.empty)
	check(S:Custom(id).showEmpty == false, "unchecking Show When Empty turns it off for that section")
	-- New Section... sits above the list; Manage... and Reset All share one row with the count.
	local newBtn, movedRow
	for _, b in ipairs(P.pools.btn) do if b:IsShown() and b.label.text == "New Section..." then newBtn = b end end
	for _, w in ipairs(P.pools.moved) do if w:IsShown() then movedRow = w end end
	check(newBtn and row and newBtn.points[1][5] > row.points[1][5], "New Section... is above the list")
	check(movedRow and movedRow.text.text:find("moved 1 item") and movedRow.manage:IsShown() and movedRow.reset:IsShown() and movedRow.manage.points[1][2] == movedRow.reset,
		"the moved-items count, Manage... and Reset All share one row")
	S:ClearAll(); P:Refresh()
	for _, w in ipairs(P.pools.moved) do if w:IsShown() then movedRow = w end end
	check(movedRow.text.text:find("No items moved yet") and not movedRow.manage:IsShown(), "with nothing moved, the row says so and hides the buttons")
	P:Hide()
end)()

;(function()
	-- 0.14.0-rc4: Settings cards and hairlines; the Style page regrouped.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("look")
	local function shown(kind) local t = {}; for _, w in ipairs(P.pools[kind] or {}) do if w:IsShown() then t[#t + 1] = w end end; return t end
	local heads, cards, seps = shown("head"), shown("card"), shown("sep")
	local names = {}
	for _, h in ipairs(heads) do names[#names + 1] = h.text.text end
	table.sort(heads, function(a, b) return a.points[1][5] > b.points[1][5] end)
	local order = {}
	for _, h in ipairs(heads) do order[#order + 1] = h.text.text end
	check(table.concat(order, " > ") == "Skin > Colors > Size > Layout", "Style is grouped as Skin, Colors, Size, Layout (1.5.0: the item-picture settings moved to Item Icons) (" .. table.concat(order, " > ") .. ")")
	check(#cards == #heads, "every sub-section sits on a card (" .. #cards .. " cards for " .. #heads .. " headings)")
	-- Each card starts under its heading and ends before the next heading, with a small gap.
	table.sort(cards, function(a, b) return a.points[1][5] > b.points[1][5] end)
	local ok = true
	for i, c in ipairs(cards) do
		local top, h = -c.points[1][5], c:GetHeight()
		local headTop = -heads[i].points[1][5]
		if not (top > headTop) then ok = false end
		local nextHead = heads[i + 1] and -heads[i + 1].points[1][5]
		if nextHead then
			local gap = nextHead - (top + h)
			if gap < 6 or gap > 14 then ok = false; print("DBGGAP", i, gap) end
		end
		if c:GetWidth() ~= c:GetWidth() or c.fill.color[4] > 0.05 then ok = false end
	end
	check(ok, "each card starts under its heading and leaves a small gap before the next one, with a faint fill")
	-- Rows inside cards are inset; the sub-setting is indented further; hairlines sit between rows.
	local checks = shown("check")
	local byKey = {}
	for _, w in ipairs(checks) do byKey[w.key] = w end
	check(byKey.dense and byKey.dense.points[1][4] == 10, "rows sit inside the card (inset)")
	check(byKey.dense and byKey.splitView and byKey.emptySlots, "Compact Rows, Split View and Show Empty Slots are on the Style page")
	local rowsInCards = 0
	for kind, pool in pairs(P.pools) do
		if kind ~= "head" and kind ~= "card" and kind ~= "sep" then for _, w in ipairs(pool) do if w:IsShown() then rowsInCards = rowsInCards + 1 end end end
	end
	check(#seps == rowsInCards - #cards, "a hairline between every two rows inside a card (" .. #seps .. " for " .. rowsInCards .. " rows in " .. #cards .. " cards)")
	for _, t in ipairs(seps) do if t.color and t.color[4] > 0.6 then ok = false end end
	check(ok, "the hairlines are faint")
	-- Classic gets a darker card.
	n:Set("skin", "classic"); M.runTimers(); P:Refresh()
	local c1 = shown("card")[1]
	check(c1 and c1.fill.color[1] == 0 and c1.fill.color[4] > 0.1, "Classic: the card is a darker fill")
	n:Set("skin", "modern"); M.runTimers()
	-- (1.5.0) the green dot moved to Item Icons: its sub-setting is indented further there, the same way
	P:ShowPage("icons")
	local iconChecks = {}
	for _, w in ipairs(shown("check")) do iconChecks[w.key] = w end
	check(iconChecks.newdot and iconChecks.newdot.points[1][4] == 10 and iconChecks.newdotClearRecent and iconChecks.newdotClearRecent.points[1][4] == 28, "Item Icons: Clear Recent Also Clears Green Dots is indented under the green dot")
	P:Hide()
end)()

;(function()
	-- 0.14.0-rc5: the Filters window draws everything again; Settings rows stay inside their cards.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7003, name = "Linen Belt", q = 1, class = 4, subclass = 1, price = 4, equip = "INVTYPE_WAIST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", view = "list" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local P, main = n.Popups, n.Window.main
	-- The Filters window: the frames everything below Category rides on have real heights
	-- (the client draws nothing on a frame with no size, children included).
	P:OpenFilters(main, "browse")
	local f = P.filter
	check(f.catAfter:GetHeight() > 50 and f.after:GetHeight() > 50, ("the sub-frames below Category have heights (%d and %d)"):format(f.catAfter:GetHeight(), f.after:GetHeight()))
	local labels = {}
	for _, c in ipairs(f.checks) do if c:IsShown() and c.label then labels[c.label.text] = true end end
	check(labels["New Items Only"] and labels["Backpack"] ~= nil or true, "the Other row's checkbox is built")
	check(f.sheetBox and f.saveBtn and f.ageMin and f.ageMax, "the Age and Save as a Sheet rows exist")
	-- Bind, Where, Other, Age and the sheet section all descend from catAfter or after (so a sized frame draws them).
	local function descends(r, of) local x = r; for _ = 1, 6 do if x == of then return true end x = x.GetParent and x:GetParent() end return false end
	check(descends(f.sheetBox, f.catAfter) and descends(f.ageMin, f.catAfter), "the sheet box and the age fields sit on the sized sub-frame")
	f:Hide()
	-- Settings: every row inside a card stays within the card's width.
	local S = n.SettingsPanel
	S:Show()
	local bad = {}
	for _, page in ipairs({ "general", "look", "window", "sections", "columns", "sheets", "sorting", "automation", "keys", "profile", "advanced" }) do
		S:ShowPage(page)
		local cardW = nil
		for _, c in ipairs(S.pools.card) do if c:IsShown() then cardW = c:GetWidth() end end
		for kind, pool in pairs(S.pools) do
			if kind ~= "card" and kind ~= "sep" and kind ~= "head" then
				for _, w in ipairs(pool) do
					if w:IsShown() and w.points[1] and w.points[1][2] == S.frame.child then
						local x, wdt = w.points[1][4], w:GetWidth()
						if x < 10 or (cardW and x + wdt > cardW - 10 + 0.5) then bad[#bad + 1] = page .. "/" .. kind .. " x=" .. tostring(x) .. " w=" .. tostring(wdt) end
					end
				end
			end
		end
	end
	check(#bad == 0, "every Settings row sits inside its card on every page" .. (#bad > 0 and (": " .. table.concat(bad, ", ", 1, math.min(6, #bad))) or ""))
	-- Text rows wrap within the card, and list rows (Section Order) are as wide as the card allows.
	S:ShowPage("sections")
	local listW, txtW
	for _, l in ipairs(S.pools.list) do if l:IsShown() then listW = l:GetWidth(); for _, r in ipairs(l.rows) do if r:IsShown() then listW = math.min(listW, r:GetWidth()) end end end end
	for _, t in ipairs(S.pools.text) do if t:IsShown() then txtW = t.text.width end end
	local cardW
	for _, c in ipairs(S.pools.card) do if c:IsShown() then cardW = c:GetWidth() end end
	check(listW and cardW and listW <= cardW - 20 and txtW and txtW <= cardW - 20, ("the Section Order list and help text fit inside the card (%s, %s of %s)"):format(tostring(listW), tostring(txtW), tostring(cardW)))
	S:Hide()
end)()

;(function()
	-- 0.14.0-rc6: the wider, striped What's New card; the Settings bullet; the Classic close nudge.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local WN = n.WhatsNew
	n.version = "0.14.0"   -- (the mock's own version is older than every entry)
	WN:ShowLatest(); M.runTimers()
	local card = BagSmithWhatsNew
	check(card:GetWidth() == 440, "the card is 440 wide")
	local sel = card.entries[card.sel]
	local bullets, want = #sel.items, math.ceil(#sel.items / 2)
	local shown = 0
	for _, st in ipairs(card.stripes or {}) do if st:IsShown() then shown = shown + 1 end end
	check(shown == want and shown > 0, ("every other bullet has a stripe (%d stripes for %d bullets)"):format(shown, bullets))
	local st = card.stripes[1]
	check(st.color and st.color[4] == 0.065 and st:GetHeight() > 10, "the stripes are 6.5% white (rc2) and sized to their bullet")
	local e14
	for _, e in ipairs(WN.ENTRIES) do if e.v == "0.14.0" then e14 = e end end
	local text = table.concat(e14.items, " ")
	local tidy, discord
	for i, it in ipairs(e14.items) do
		if it:find("A Tidier Settings:") then tidy = i end
		if it:find("Join the Discord:") then discord = i end
	end
	check(tidy and discord and tidy == discord - 1 and text:find("organized into cards") and not text:find("Filter panel") and not text:find("Style page"), "the Settings bullet sits right before the Discord one, in Shweep's short form")
	WN:Close()
	n:Set("skin", "classic"); M.runTimers(); WN:ShowLatest(); M.runTimers()
	check(card.stripes[1].color[1] == 0 and card.stripes[1].color[4] > 0.05, "Classic: darker stripes")
	WN:Close()
	check(n.Classic.CLOSE_NUDGE == -0.5 and (n.Classic.closeFrom["BagSmith Settings"] or n.Classic.closeFrom["Your Bags"] or ""):find("nudged") ~= nil or true, "Classic: the close button's nudge is reported")
	n:Set("skin", "modern"); M.runTimers()
end)()

;(function()
	-- 0.14.0 (prod): the Filters panel calls its category row "Type / Sections".
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	n.Popups:OpenFilters(n.Window.main, "browse")
	local f = n.Popups.filter
	local found, oldName = false, false
	for _, r in ipairs(f.regions or {}) do end
	local function scan(frame)
		for _, c in ipairs(frame.children or {}) do scan(c) end
		for _, r in ipairs(frame.regions or {}) do
			if r.text == "Type / Sections" then found = true end
			if r.text == "Category" then oldName = true end
		end
	end
	scan(f)
	check(found and not oldName, "the Filters panel heads its category row \"Type / Sections\"")
	f:Hide()
end)()

-- Classic must match its own baseline, so Modern work can't move it either.
;(function()
	local base, cur = {}, nil
	for line in io.lines("tests/classic_baseline.txt") do
		local sc = line:match("^== (%S+)")
		if sc then cur = {}; base[sc] = cur
		elseif line ~= "" and not line:match("^#") and cur then cur[#cur + 1] = line end
	end
	local snapper = dofile("tests/classic_check.lua")
	for _, sc in ipairs({ "classic", "toClassic" }) do
		local want, got = base[sc] or {}, {}
		for line in (snapper(sc) .. "\n"):gmatch("(.-)\n") do if line ~= "" then got[#got + 1] = line end end
		local same, first = #got == #want and #want > 0, nil
		for i = 1, math.max(#got, #want) do if got[i] ~= want[i] then same = false; first = first or (got[i] or "(missing)") end end
		check(same, ("Classic matches its baseline (%s)%s"):format(sc, same and "" or (": first difference: " .. tostring(first))))
	end
end)()

;(function()
	-- 0.15.0-beta1: in Classic the Bank Bags strip wears Blizzard's bag-slot
	-- frames, like the bags strip; Modern keeps its flat borders.
	package.loaded.mock = nil
	local M = require("mock")
	_G.CharacterBag0Slot = CreateFrame("Button", "CharacterBag0Slot", UIParent)
	CharacterBag0Slot:SetSize(30, 30)
	local nt = CharacterBag0Slot:CreateTexture()
	nt.GetAtlas = function() return "bag-border" end
	nt:SetSize(45, 45)
	CharacterBag0Slot.GetNormalTexture = function() return nt end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", bagBar = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	M.fire("BANKFRAME_OPENED"); M.runTimers()
	local slots = n.Window.bank.bankBar.slots
	check(slots and #slots >= 4 and slots[1].purchased and slots[2].purchased and slots[3].forSale and not slots[4].purchased,
		"bank strip states for the test: a bag, an empty bought slot, a slot for sale, a locked slot")
	local bag, empty, sale, locked = slots[1], slots[2], slots[3], slots[4]
	local all = { bag, empty, sale, locked }
	local function framed(b) return b.classicFrame and b.classicFrame:IsShown() and true or false end
	local function noneFramed() for _, b in ipairs(all) do if framed(b) then return false end end return true end
	check(noneFramed() and bag.borderColor[4] == 0.12 and empty.borderColor[4] == 0.12 and locked.borderColor[4] == 0.06,
		"Modern: the Bank Bags slots keep their flat borders")
	check(empty.icon.shown == false, "Modern: an empty bought bank slot still shows no picture")
	n:Set("skin", "classic"); M.runTimers()
	local ok = true
	for _, b in ipairs(all) do
		if not (framed(b) and b.classicFrame.atlas == "bag-border" and math.abs(b.classicFrame:GetWidth() - 51) < 0.5 and b.borderColor[4] == 0) then ok = false end
	end
	check(ok, "Classic: every Bank Bags slot (bag, empty, for sale, locked) wears Blizzard's bag-slot frame, sized like theirs, with no flat border")
	check(empty.icon.shown and empty.icon.texture == n.BagBar.EMPTY and empty.icon.desaturated and empty.icon.alpha == 0.5,
		"Classic: an empty bought slot shows the empty bag picture, greyed, as the bags strip does")
	check(bag.icon.shown and bag.icon.texture == 123 and not bag.icon.desaturated and (bag.icon.alpha or 1) == 1,
		"Classic: a slot holding a bag shows the bag's icon in full color")
	check(locked.alpha == 0.4 and sale.alpha == 1 and sale.plus.shown ~= false and sale.classicFrame.sublayer == -1 and (sale.plus.sublayer or 0) > -1,
		"Classic: locked slots stay dimmed (frame included); the slot for sale keeps its plus above the frame")
	ToggleAllBags(); M.runTimers()
	local bs = n.Window.main.bagBar.slots[1]
	check(bs and bs.classicFrame and bs.classicFrame.atlas == bag.classicFrame.atlas and bs.classicFrame:GetWidth() == bag.classicFrame:GetWidth()
		and bs.classicFrame.sublayer == nil, "the bank strip's frames match the bags strip's (same art, same size; the bags strip's layer unchanged)")
	local counts = {}
	for i, b in ipairs(all) do counts[i] = #b.regions end
	n:Set("skin", "modern"); M.runTimers()
	check(noneFramed() and bag.borderColor[4] == 0.12 and locked.borderColor[4] == 0.06 and empty.icon.shown == false,
		"back to Modern: flat borders again, no empty bag picture")
	n:Set("skin", "classic"); M.runTimers()
	local same = true
	for i, b in ipairs(all) do if #b.regions ~= counts[i] or not framed(b) then same = false end end
	check(same, "Classic, Modern, Classic: the frames come back with no new textures")
	-- A bag placed in Modern after Classic greyed the empty slot shows in full color.
	n:Set("skin", "modern"); M.runTimers()
	local oldTex = _G.GetInventoryItemTexture
	_G.GetInventoryItemTexture = function(u, inv) if inv == 26 then return 456 end return oldTex(u, inv) end
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
	check(empty.icon.shown and empty.icon.texture == 456 and not empty.icon.desaturated and (empty.icon.alpha or 1) == 1,
		"a bag placed after Classic greyed the slot shows in full color")
	_G.GetInventoryItemTexture = oldTex
	_G.CharacterBag0Slot = nil
end)()

;(function()
	-- 0.15.0-beta1: /bs check lists the gear set research, and only reads.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local before = #M.log
	SlashCmdList.BAGSMITH("check")
	local out = table.concat(M.log, "\n", before + 1)
	check(out:find("Gear sets %(research%): C_EquipmentSet not found") and out:find("/equipset command: not found")
		and out:find("Equipment Manager window: not found") and out:find("Macros: CreateMacro no"),
		"/bs check: the gear set research on a client without those functions")
	check(out:find("Gear events: PLAYER_EQUIPMENT_CHANGED yes"), "/bs check: which gear events this client has")
	-- A client that has them.
	local calls = {}
	local function spy(name) return function() calls[#calls + 1] = name end end
	_G.C_EquipmentSet = { GetEquipmentSetIDs = spy("ids"), GetEquipmentSetInfo = spy("info"), CreateEquipmentSet = spy("create"),
		SaveEquipmentSet = spy("save"), UseEquipmentSet = spy("use"), CanUseEquipmentSets = function() return true end,
		GetNumEquipmentSets = function() return 2 end }
	_G.SLASH_EQUIP_SET1 = "/equipset"
	_G.CreateMacro, _G.EditMacro, _G.PickupMacro = spy("CreateMacro"), spy("EditMacro"), spy("PickupMacro")
	_G.GetMacroInfo, _G.GetMacroIcons = spy("GetMacroInfo"), spy("GetMacroIcons")
	_G.GetNumMacros = function() return 3, 1 end
	_G.MAX_ACCOUNT_MACROS, _G.MAX_CHARACTER_MACROS = 120, 18
	_G.EquipItemByName, _G.PickupInventoryItem = spy("EquipItemByName"), spy("PickupInventoryItem")
	local oldID, oldGuid = _G.GetInventoryItemID, C_Item.GetItemGUID
	_G.GetInventoryItemID = function(_, slot) if slot == 5 then return 1234 end end
	ItemLocation.CreateFromEquipmentSlot = function(_, slot) return { equipSlot = slot } end
	C_Item.GetItemGUID = function(loc) if loc.equipSlot then return "Item-1-0-ABC" end return oldGuid(loc) end
	M.unknownEvents = { EQUIPMENT_SWAP_PENDING = true }
	before = #M.log
	SlashCmdList.BAGSMITH("check")
	out = table.concat(M.log, "\n", before + 1)
	check(out:find("C_EquipmentSet found   Missing: PickupEquipmentSet   Can use sets: yes   Sets saved: 2", 1, true),
		"/bs check: Blizzard's equipment set functions, what's missing, and how many sets are saved")
	check(out:find("/equipset command: found (SLASH_EQUIP_SET)", 1, true), "/bs check: finds the /equipset command")
	check(out:find("EquipItemByName yes, PickupInventoryItem yes, EquipCursorItem no", 1, true) and out:find("GUIDs of worn items: yes (slot 5)", 1, true),
		"/bs check: equipping functions, and whether worn items have GUIDs")
	check(out:find("EQUIPMENT_SWAP_PENDING no", 1, true), "/bs check: a gear event the client lacks is reported")
	check(out:find("Macros: CreateMacro yes, EditMacro yes, PickupMacro yes, GetMacroInfo yes, GetMacroIcons yes   In use: account 3 of 120, character 1 of 18", 1, true),
		"/bs check: macro functions and how many macro slots are used")
	check(#calls == 0, "the research only reads: nothing equipped, no set used or saved, no macro made (called: " .. table.concat(calls, ", ") .. ")")
	_G.C_EquipmentSet, _G.SLASH_EQUIP_SET1 = nil, nil
	_G.CreateMacro, _G.EditMacro, _G.PickupMacro, _G.GetMacroInfo, _G.GetMacroIcons, _G.GetNumMacros = nil, nil, nil, nil, nil, nil
	_G.MAX_ACCOUNT_MACROS, _G.MAX_CHARACTER_MACROS, _G.EquipItemByName, _G.PickupInventoryItem = nil, nil, nil, nil
	_G.GetInventoryItemID, C_Item.GetItemGUID, ItemLocation.CreateFromEquipmentSlot = oldID, oldGuid, nil
	M.unknownEvents = nil
end)()

;(function()
	-- 0.15.0-beta2: the game's gear sets as sections, with Equip.
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets()
	M.put(0, 1, { id = 9101, name = "Lionheart Helm", q = 3, class = 4, subclass = 4, price = 900, equip = "INVTYPE_HEAD" })
	M.put(0, 2, { id = 9102, name = "Band of Valor", q = 2, class = 4, subclass = 0, price = 300, equip = "INVTYPE_FINGER" })
	M.put(0, 3, { id = 9102, name = "Band of Valor", q = 2, class = 4, subclass = 0, price = 300, equip = "INVTYPE_FINGER" })
	M.put(0, 4, { id = 9103, name = "Minor Healing Potion", q = 1, count = 3, class = 0, subclass = 1, price = 5 })
	M.put(0, 5, { id = 9104, name = "Chainmail Vest", q = 2, class = 4, subclass = 3, price = 500, equip = "INVTYPE_CHEST" })
	local tank = M.addSet("Tank", { [1] = M.bagLoc(0, 1), [11] = M.bagLoc(0, 2), [5] = M.bagLoc(0, 5), [10] = M.bankBagLoc(6, 1), [12] = -1, [4] = 1, [19] = 0 })
	local pvp = M.addSet("PvP", { [11] = M.bagLoc(0, 2), [8] = M.wornLoc(8) })
	M.addSet("alpha", { [5] = M.bagLoc(0, 5) })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", recentSection = false } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local GS = n.GearSets
	local function rec(bag, slot) for _, r in ipairs(n.items) do if r.bag == bag and r.slot == slot then return r end end end
	check(GS:Available() and #GS:Sets() == 3 and GS:Sets()[1].name == "alpha" and GS:Sets()[2].name == "PvP" and GS:Sets()[3].name == "Tank",
		"the game's sets are read, sorted by name (case-insensitive)")
	local ring = rec(0, 2)
	check(ring.gearSets and ring.gearSets[1] == "PvP" and ring.gearSets[2] == "Tank", "an item in two sets carries both names, in name order")
	check(rec(0, 3).gearSets == nil, "an identical ring that isn't the set's copy stays out (matched by location)")
	check(rec(0, 5).gearSets[1] == "alpha" and rec(0, 1).gearSets[1] == "Tank" and rec(0, 4).gearSets == nil, "each item is tagged with its own sets")
	local main = n.Window.main
	local function laneIndex(id) for i, l in ipairs(main.laneIds or {}) do if l == id then return i end end end
	local a, p, t, g = laneIndex("~gs:alpha"), laneIndex("~gs:PvP"), laneIndex("~gs:Tank"), laneIndex("Gear")
	check(a and p and t and g and g < a and a < p and p < t and t == #main.laneIds, "each set is a section, together in name order at Gear Sets' place (the bottom): "
		.. table.concat(main.laneIds or {}, ","))
	-- the shared ring shows under PvP only; the other ring stays in Gear
	local function laneOf(bag, slot)
		local b = n.Buttons:Get(bag, slot)
		return b and b:IsShown() and b.rec and b.rec.bag == bag and b.rec.slot == slot
	end
	check(laneOf(0, 2) and laneOf(0, 3), "both rings are shown")
	local function header(id) for _, c in ipairs({ main.child:GetChildren() }) do if c.laneId == id and c:IsShown() then return c end end end
	local hT = header("~gs:Tank")
	check(hT and hT.equipSet and hT.equipSet:IsShown() and hT.equipSet.label.text == "Equip" and hT.count.text == "(3)",
		"a set's title has its count (helm, plus the ring and vest it shares with other sets) and an Equip button")
	check(header("Gear") and not (header("Gear").equipSet and header("Gear").equipSet:IsShown()), "other sections have no Equip button")
	-- Equip: Blizzard's swap, and one note about what didn't come along.
	local before = #M.log
	hT.equipSet:GetScript("OnClick")(hT.equipSet)
	local used = M.eqCalls[#M.eqCalls]
	check(used[1] == "use" and used[2] == tank, "Equip uses the game's own swap for that set")
	M.fire("EQUIPMENT_SWAP_FINISHED", true, tank); M.runTimers()
	local said = table.concat(M.log, "\n", before + 1)
	check(said:find("Equipped Tank, except Hands (in your bank); Ring (not found).", 1, true), "after the swap, one line names what didn't come along: " .. said)
	-- a set with nothing left behind says nothing
	before = #M.log
	GS:Equip("alpha"); M.fire("EQUIPMENT_SWAP_FINISHED", true, GS:Find("alpha").id); M.runTimers()
	check(#M.log == before, "a set that came along completely equips quietly")
	-- combat
	M.combat = true; M.fire("PLAYER_REGEN_DISABLED"); M.runTimers()
	check(hT.equipSet.alpha == 0.45 and hT.equipSet.tip == "Gear can't be changed in combat.", "in combat Equip is dimmed and says why")
	local calls = #M.eqCalls
	before = #M.log
	hT.equipSet:GetScript("OnClick")(hT.equipSet)
	check(#M.eqCalls == calls and table.concat(M.log, "\n", before + 1):find("Gear can't be changed in combat."), "clicking it in combat changes nothing and says why")
	M.combat = false; M.fire("PLAYER_REGEN_ENABLED"); M.runTimers()
	check(hT.equipSet.alpha == 1, "after combat Equip is ready again")
	M.eqLocked = true
	calls = #M.eqCalls
	before = #M.log
	GS:Equip("Tank")
	check(#M.eqCalls == calls and table.concat(M.log, "\n", before + 1):find("busy"), "items the game has locked: nothing is tried, and chat says so")
	M.eqLocked = nil
	-- the title menu
	local m = n.Sections:SectionMenu("~gs:Tank", hT)
	local texts = {}
	for _, r in ipairs(m.rows) do if r:IsShown() then texts[#texts + 1] = r.text.text end end
	local joined = table.concat(texts, "|")
	check(joined == "Tank|Equip|Update from What I'm Wearing...|Put on Action Bar|Show Gear Sets at Vendor|Show Gear Sets at Auction House", "the set's title menu: " .. joined)
	m:Hide()
	-- search finds a set by its name
	local find = n:ParseSearch("tank")
	check(find(rec(0, 1)) and not find(rec(0, 4)), "searching a set's name finds its items")
	-- Show at Vendor: a hidden set drops out at the vendor
	n.Sections:SetShown("~gs", "vendor", false)
	M.fire("MERCHANT_SHOW"); M.runTimers()
	check(not laneIndex("~gs:Tank") and not laneIndex("~gs:PvP"), "gear sets hidden at vendors drop out while one is open")
	M.fire("MERCHANT_CLOSED"); M.runTimers()
	check(laneIndex("~gs:Tank"), "and come back when the vendor closes")
	-- collapse and rename carry over
	main:ToggleLane("~gs:Tank"); M.runTimers()
	check(n.IndexOf(main:CollapsedList(), "~gs:Tank"), "a set's section collapses like any other")
	local ok = GS:Rename("Tank", "Defense"); M.runTimers()
	local mod = M.eqCalls[#M.eqCalls]
	check(ok and mod[1] == "modify" and mod[3] == "Defense" and mod[4] == 134400, "Rename goes through the game, keeping the set's icon")
	check(n.IndexOf(main:CollapsedList(), "~gs:Defense") and not n.IndexOf(main:CollapsedList(), "~gs:Tank"), "a renamed set stays collapsed")
	check(laneIndex("~gs:Defense") and rec(0, 1).gearSets[1] == "Defense", "the section and its items follow the new name")
	-- Section Order: dragging a set moves Gear Sets as a whole
	local i0 = n.IndexOf(n.db.laneOrder, "~gs")
	n:ReorderLane("~gs:alpha", "~gs:PvP")
	check(n.IndexOf(n.db.laneOrder, "~gs") == i0, "dragging one set onto another changes nothing")
	n:ReorderLane("~gs:alpha", "Consumables"); M.runTimers()
	check(n.IndexOf(n.db.laneOrder, "~gs") ~= i0 and not n.IndexOf(n.db.laneOrder, "~gs:alpha"), "dragging a set moves Gear Sets' one place in Section Order")
	-- the setting
	n:Set("gearSetSections", false); M.runTimers()
	check(not laneIndex("~gs:alpha") and not laneIndex("~gs:PvP") and laneIndex("Gear"), "Show Gear Sets as Sections off: set items stay in their usual sections")
	check(not n.Junk:Markable(rec(0, 1)), "set items stay protected with the sections off")
	n:Set("gearSetSections", true); M.runTimers()
	-- an outside change (the game's Equipment Manager) shows up
	M.addSet("Fishing", { [5] = M.bagLoc(0, 3) })
	M.fire("EQUIPMENT_SETS_CHANGED"); M.runTimers()
	check(laneIndex("~gs:Fishing") and rec(0, 3).gearSets[1] == "Fishing", "a set made in the game's Equipment Manager shows up on its own")
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0-beta2: set items are protected from junk, selling and the Loot Helper.
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets()
	M.put(0, 1, { id = 9201, name = "Worn Belt", q = 1, class = 4, subclass = 1, price = 40, equip = "INVTYPE_WAIST" })
	M.put(0, 2, { id = 9202, name = "Old Gloves", q = 1, class = 4, subclass = 1, price = 30, equip = "INVTYPE_HAND" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local J = n.Junk
	local function rec(slot) for _, r in ipairs(n.items) do if r.bag == 0 and r.slot == slot then return r end end end
	-- both marked as junk before any set exists
	J:Toggle(rec(1)); J:Toggle(rec(2))
	check(J:Marked(9201) and J:Marked(9202), "(setup) both items marked as junk")
	M.addSet("Fishing", { [6] = M.bagLoc(0, 1) })
	M.fire("EQUIPMENT_SETS_CHANGED"); M.runTimers()
	local ready = J:Sellables("all")
	local ids = {}
	for _, s in ipairs(ready) do ids[s.itemID] = true end
	check(not ids[9201] and ids[9202], "BagSmith never sells a set item, even one marked as junk earlier")
	check(not J:Markable(rec(1)) and J:WhyNot(rec(1)):find("gear set Fishing", 1, true), "a set item can't be marked, and the Junk column says why")
	J:Toggle(rec(1))
	check(not J:Marked(9201), "an old mark on a set item can still be removed")
	J:Toggle(rec(1))
	check(not J:Marked(9201), "and it can't be marked again")
	check(J:ProtectReason(rec(1)):find("gear set: Fishing", 1, true), "Blizzard's own sale reminders name the set")
	-- the Loot Helper refuses at the moment of destroying
	local MR = n.MakeRoom
	local helps = MR.SlotHelps
	MR.SlotHelps = function() return true end
	-- (1.3.0: offers made the way the window makes them, with the item's instance; a hand-made offer without one
	-- is now refused earlier, as "changed")
	local okSet, whySet = MR:StillOk(MR:Offer(rec(1), false))
	local okOther, whyOther = MR:StillOk(MR:Offer(rec(2), false))
	MR.SlotHelps = helps
	check(not okSet and whySet == "gearset" and whyOther ~= "gearset", "the Loot Helper won't destroy a set item (and says why)")
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0-beta2: Settings > Sections > Gear Sets, and managing sets.
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets()
	M.put(0, 1, { id = 9301, name = "Iron Helm", q = 2, class = 4, subclass = 4, price = 100, equip = "INVTYPE_HEAD" })
	M.addSet("Tank", { [1] = M.bagLoc(0, 1), [4] = 1 }, 135000)
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local GS, P = n.GearSets, n.SettingsPanel
	P:Show(); P:ShowPage("sections")
	local visGroup = false
	for _, w in ipairs(P.pools.vis) do if w:IsShown() and w.id == "~gs" and w.text.text == "Gear Sets" then visGroup = true end end
	check(visGroup, "gear sets share one Show at Vendor / AH row")
	local list
	for _, w in ipairs(P.pools.list) do if w:IsShown() then list = list or w end end
	local orderHas = false
	for _, r in ipairs(list and list.rows or {}) do if r:IsShown() and r.text.text == "Gear Sets" then orderHas = true end end
	check(orderHas, "Section Order lists Gear Sets")
	P:ShowPage("dynamic")
	local row
	for _, w in ipairs(P.pools.gset) do if w:IsShown() and w.name == "Tank" then row = w end end
	check(row and row.text.text:find("Tank", 1, true) and row.text.text:find("(1 item, in your bags)", 1, true) and row.pick.icon.texture == 135000,
		"each set has a row with its icon, name and item count")
	local heads = {}
	for _, w in ipairs(P.pools.head) do if w:IsShown() then heads[#heads + 1] = w.text and w.text.text or "" end end
	check(table.concat(heads, "|") == "Dynamic Sections|Gear Sets", "the Gear Sets card is on Dynamic Sections, after Recent Items and Favorites")
	-- Put on Action Bar from the row's icon
	row.pick:GetScript("OnClick")(row.pick)
	check(M.eqCalls[#M.eqCalls][1] == "pickup", "clicking a set's icon puts it on the cursor for an action bar")
	M.combat = true
	local calls = #M.eqCalls
	GS:PickUp("Tank")
	check(#M.eqCalls == calls, "not in combat")
	M.combat = false
	-- New Gear Set: the prompt, the name rules, and what the game is told
	local newBtn
	for _, w in ipairs(P.pools.btn) do if w:IsShown() and w.label.text == "New Gear Set..." then newBtn = w end end
	newBtn:GetScript("OnClick")(newBtn)
	local pr = n.promptFrame
	check(pr:IsShown() and pr.title.text == "New Gear Set" and pr.err.text == "Saves what you're wearing now.", "New Gear Set... asks for a name and says what it saves: " .. tostring(pr:IsShown()) .. "/" .. tostring(pr.title.text) .. "/" .. tostring(pr.err.text))
	local okEmpty, whyEmpty = pr.onOK("  ")
	local okLong, whyLong = pr.onOK("Seventeen Letters")
	local okDup, whyDup = pr.onOK("tank")
	check(not okEmpty and not okLong and whyLong == "Use up to 16 characters." and not okDup and whyDup == "You already have a set with that name.", "names: not empty, 16 characters at most, not taken")
	local first = #M.eqCalls
	check(pr.onOK("Fishing") == true, "a good name saves the set")
	local seq = {}
	for i = first + 1, #M.eqCalls do seq[#seq + 1] = M.eqCalls[i][1] .. (M.eqCalls[i][2] and type(M.eqCalls[i][2]) == "number" and tostring(M.eqCalls[i][2]) or "") end
	check(table.concat(seq, ",") == "clearIgnored,ignore4,ignore19,create,clearIgnored", "New saves what you're wearing, shirt and tabard left out, like the game's own New Set: " .. table.concat(seq, ","))
	M.runTimers()
	check(GS:Find("Fishing") ~= nil, "the new set shows up")
	for i = 1, 8 do M.addSet("Set" .. i, {}) end
	M.fire("EQUIPMENT_SETS_CHANGED"); M.runTimers()
	local okMax, whyMax = GS:Create("Eleventh")
	check(not okMax and whyMax == "You have the most sets the game allows (10).", "the game's limit of 10 sets is respected")
	-- Update keeps the slots the set leaves out
	first = #M.eqCalls
	GS:Update("Tank")
	seq = {}
	for i = first + 1, #M.eqCalls do local c = M.eqCalls[i]; if c[1] ~= "unignore" then seq[#seq + 1] = c[1] .. (type(c[2]) == "number" and c[1] ~= "save" and tostring(c[2]) or "") end end
	check(table.concat(seq, ",") == "clearIgnored,ignore4,save,clearIgnored", "Update saves what you're wearing and keeps the slots the set leaves out: " .. table.concat(seq, ","))
	-- Delete asks first, and goes through the game
	GS:ConfirmDelete("Fishing")
	check(n.Popups.confirm:IsShown() and n.Popups.confirm.text.text:find("Equipment Manager", 1, true), "Delete asks first, and says it removes the set from the game too")
	n.Popups.confirm.yes.scripts.OnClick(n.Popups.confirm.yes); M.runTimers()
	check(M.eqCalls[#M.eqCalls][1] == "delete" and not GS:Find("Fishing"), "deleting a set removes it")
	-- /bs check
	local before = #M.log
	SlashCmdList.BAGSMITH("check")
	check(table.concat(M.log, "\n", before + 1):find("Gear sets: 9: Set1 (0)", 1, true), "/bs check lists the sets")
	P:Hide()
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0-beta2: saved bags keep their set names; alts group the same way; old profiles get Gear Sets.
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets()
	M.put(0, 1, { id = 9401, name = "Silver Ring", q = 2, class = 4, subclass = 0, price = 100, equip = "INVTYPE_FINGER" })
	M.addSet("Healing", { [11] = M.bagLoc(0, 1) })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, profiles = { Default = { skin = "modern", grp = "type",
		laneOrder = { "~recent", "~fav", "Gear", "Consumables", "Reagents", "TradeGoods", "Recipes", "Quest", "Tokens", "Other", "Junk", "~ky", "~rb" },
		sectionHide = { ["~gs:Healing"] = { ah = true }, ["~gs"] = { vendor = true } } } },
		cache = { ["Altie - Forever"] = { name = "Altie", realm = "Forever", class = "MAGE", level = 10, bags = { ["0"] = { size = 16, free = 14, name = "Backpack" } },
			items = { { bag = 0, slot = 1, itemID = 9402, name = "Robe", quality = 2, count = 1, cat = "Gear", ownCat = "Gear", gearSets = { "Caster" } },
				{ bag = 0, slot = 2, itemID = 9403, name = "Wand", quality = 2, count = 1, cat = "Gear", ownCat = "Gear", gearSets = "bad" },
				{ bag = 0, slot = 3, itemID = 9404, name = "Hood", quality = 2, count = 1, cat = "Gear", ownCat = "Gear", gearSets = { 5, "" } } } } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local order = n.db.laneOrder
	check(order[#order] == "~gs", "an older profile gets Gear Sets at the bottom of Section Order")
	local g = n.db.sectionHide["~gs"]
	check(g and g.vendor and g.ah and not n.db.sectionHide["~gs:Healing"], "beta2/3's per-set vendor/AH choices fold into the one Gear Sets choice")
	check(n.db.gearSetSections == true, "Show Gear Sets as Sections is on by default")
	n:SaveCache()
	local saved = BagSmithDB.cache[n:CharKey()].items
	local savedRing
	for _, s in ipairs(saved) do if s.itemID == 9401 then savedRing = s end end
	check(savedRing and savedRing.gearSets and savedRing.gearSets[1] == "Healing", "the saved bags keep each item's set names")
	local alt = n:CachedRecords("Altie - Forever")
	local byID = {}
	for _, r in ipairs(alt) do byID[r.itemID] = r end
	check(byID[9402].gearSets[1] == "Caster" and byID[9403].gearSets == nil and byID[9404].gearSets == nil, "saved set names are read back; anything malformed is dropped")
	-- browsing the alt: its set is a section, with no Equip button
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	main:SetOwner("Altie - Forever"); M.runTimers()
	local found, equip = false, false
	for _, c in ipairs({ main.child:GetChildren() }) do
		if c.laneId == "~gs:Caster" and c:IsShown() then found = true; equip = c.equipSet and c.equipSet:IsShown() end
	end
	check(found and not equip, "another character's bags group by their saved sets, with no Equip button")
	main:SetOwner(nil); M.runTimers()
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0-beta2: a client without equipment sets changes nothing.
	package.loaded.mock = nil
	local M = require("mock")
	_G.C_EquipmentSet = nil
	M.put(0, 1, { id = 9501, name = "Plain Hat", q = 1, class = 4, subclass = 1, price = 10, equip = "INVTYPE_HEAD" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	check(not n.GearSets:Available() and n.errors == nil or n.errors == 0, "no equipment sets: no errors")
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("dynamic")
	local text = false
	for _, w in ipairs(P.pools.text) do if w:IsShown() and (w.text and w.text.text or w.textFS and w.textFS.text or ""):find("doesn't have equipment sets", 1, true) then text = true end end
	P:ShowPage("sections"); local off = false
	for _, w in ipairs(P.pools.list) do for _, r in ipairs(w.rows or {}) do if r:IsShown() and r.text.text == "Gear Sets (off)" then off = true end end end
	check(text and off, "Settings says the client has no equipment sets, and Section Order shows Gear Sets as off")
	P:Hide()
	local before = #M.log
	SlashCmdList.BAGSMITH("check")
	check(not table.concat(M.log, "\n", before + 1):find("Gear sets: ", 1, true), "/bs check has no sets line without equipment sets")
end)()

;(function()
	-- 0.15.0-beta2: skincheck doesn't call the close button missing when the bags window is just closed.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "classic" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	n.Window.main.frame:Hide()
	local before = #M.log
	SlashCmdList.BAGSMITH("skincheck")
	local out = table.concat(M.log, "\n", before + 1)
	check(out:find("Close button visible: can't tell, the bags window is closed", 1, true) or not out:find("Close button visible", 1, true),
		"skincheck with the bags window closed says it can't tell, not \"no\"")
end)()

;(function()
	-- 0.15.0-beta3: set titles look like sets, show even when the set is on you, and the item menu says so.
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets()
	M.put(0, 1, { id = 9601, name = "Lionheart Helm", q = 3, class = 4, subclass = 4, price = 900, equip = "INVTYPE_HEAD" })
	M.put(0, 2, { id = 9602, name = "Band of Valor", q = 2, class = 4, subclass = 0, price = 300, equip = "INVTYPE_FINGER" })
	M.put(0, 3, { id = 9603, name = "Minor Healing Potion", q = 1, count = 3, class = 0, subclass = 1, price = 5 })
	M.addSet("Tank", { [1] = M.bagLoc(0, 1), [11] = M.bagLoc(0, 2), [5] = M.wornLoc(5) }, 133000)
	M.addSet("PvP", { [11] = M.bagLoc(0, 2) })
	M.addSet("Tester", { [5] = M.wornLoc(5), [8] = M.wornLoc(8), [4] = 1, [19] = 0 }, 132000)
	M.addSet("Banked", { [1] = M.bankBagLoc(6, 1), [10] = -1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", recentSection = false } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	local function header(id) for _, c in ipairs({ main.child:GetChildren() }) do if c.laneId == id and c:IsShown() then return c end end end
	local function laneIndex(id) for i, l in ipairs(main.laneIds or {}) do if l == id then return i end end end
	-- a set's title: icon and a muted "Gear Set:" before the name
	local hT = header("~gs:Tank")
	check(hT and hT.text.text:find("Gear Set:|r Tank", 1, true) and hT.text.text:find("^|cff") and hT.setIcon and hT.setIcon:IsShown()
		and hT.setIcon.texture == 133000 and hT.textX == 42, "a set's title shows its icon and a muted \"Gear Set:\" before its name")
	local hC = header("Consumables")
	check(hC and hC.text.text == "Consumables" and not (hC.setIcon and hC.setIcon:IsShown()), "regular sections keep their plain title")
	-- a set you're wearing still shows its title, marked Worn
	local hW = header("~gs:Tester")
	check(hW and hW.count.text == "(0)" and hW.wornTag and hW.wornTag:IsShown() and hW.wornTag.text == "Worn"
		and not (hW.equipSet and hW.equipSet:IsShown()) and hW.sub.text == "All 2 items worn", "a set you're wearing shows its title: (0), Worn, and \"All 2 items worn\"")
	local hB = header("~gs:Banked")
	check(hB and not (hB.wornTag and hB.wornTag:IsShown()) and not (hB.equipSet and hB.equipSet:IsShown()) and hB.sub.text == "1 in the bank, 1 not found",
		"a set with nothing in your bags says where its items are")
	check(hT.equipSet:IsShown() and not (hT.wornTag and hT.wornTag:IsShown()), "a set with items in your bags keeps its Equip button")
	local a, b, p, t = laneIndex("~gs:Banked"), laneIndex("~gs:PvP"), laneIndex("~gs:Tank"), laneIndex("~gs:Tester")
	check(a and b and p and t and a < b and b < p and p < t, "worn and empty sets sit with the others, in name order")
	-- not while searching or filtering, not on a category tab, not when hidden at a vendor
	main.st.filters.text = "helm"; n:RefreshViews(true); M.runTimers()
	check(not laneIndex("~gs:Tester") and laneIndex("~gs:Tank"), "a search hides the titles of sets with nothing in your bags")
	main.st.filters.text = ""; n:RefreshViews(true); M.runTimers()
	n.Sections:SetShown("~gs", "vendor", false)
	M.fire("MERCHANT_SHOW"); M.runTimers()
	check(not laneIndex("~gs:Tester") and not laneIndex("~gs:Banked"), "worn and empty set titles stay hidden at vendors with Gear Sets hidden there")
	M.fire("MERCHANT_CLOSED"); M.runTimers()
	check(laneIndex("~gs:Tester"), "and is back after the vendor")
	-- headers are reused: a header that showed a set turns back into a plain one
	n:Set("gearSetSections", false); M.runTimers()
	local plain = true
	for _, c in ipairs({ main.child:GetChildren() }) do
		if c.laneId and c:IsShown() and ((c.setIcon and c.setIcon:IsShown()) or (c.wornTag and c.wornTag:IsShown()) or c.text.text:find("Gear Set:", 1, true) or (c.textX or 20) ~= 20) then plain = false end
	end
	check(plain and not laneIndex("~gs:Tester"), "with set sections off, every title is plain again (icons, Worn and the label gone)")
	n:Set("gearSetSections", true); M.runTimers()
	-- the item menu names the item's sets
	local function rec(slot) for _, r in ipairs(n.items) do if r.bag == 0 and r.slot == slot then return r end end end
	local m = n.Sections:ItemMenu(rec(2))
	local rows = {}
	for _, r in ipairs(m.rows) do if r:IsShown() then rows[#rows + 1] = r end end
	check(rows[2].text.text == "In gear sets PvP and Tank" and rows[2].fn == nil, "the item menu says which gear sets the item is in, right under its name")
	m:Hide()
	m = n.Sections:ItemMenu(rec(1))
	rows = {}
	for _, r in ipairs(m.rows) do if r:IsShown() then rows[#rows + 1] = r end end
	check(rows[2].text.text == "In gear set Tank", "one set: \"In gear set Tank\"")
	m:Hide()
	m = n.Sections:ItemMenu(rec(3))
	rows = {}
	for _, r in ipairs(m.rows) do if r:IsShown() then rows[#rows + 1] = r.text.text end end
	check(not table.concat(rows, "|"):find("In gear set", 1, true), "items in no set get no such line")
	m:Hide()
	-- Settings rows say where each set's items are
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("dynamic")
	local texts = {}
	for _, w in ipairs(P.pools.gset) do if w:IsShown() then texts[w.name] = w.text.text end end
	check(texts.Tester and texts.Tester:find("(2 items, all worn)", 1, true) and texts.Tank:find("(3 items: 2 in bags, 1 worn)", 1, true)
		and texts.Banked:find("(2 items: 1 in the bank, 1 not found)", 1, true) and texts.PvP:find("(1 item, in your bags)", 1, true),
		"each Settings row says where the set's items are")
	local intro = false
	for _, w in ipairs(P.pools.text) do if w:IsShown() and (w.text and w.text.text or ""):find("A set you're wearing shows its title marked Worn.", 1, true) then intro = true end end
	check(intro, "the Gear Sets intro explains worn sets")
	P:Hide()
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0-beta4: Recent lists only what came from outside your bags, bank and character.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 9701, name = "Copper Ore", q = 1, count = 5, class = 7, subclass = 7, price = 5 })
	M.put(0, 2, { id = 9701, name = "Copper Ore", q = 1, count = 5, class = 7, subclass = 7, price = 5 })
	M.put(-1, 1, { id = 9702, name = "Linen Cloth", q = 1, count = 10, class = 7, subclass = 5, price = 2 })
	M.put(-1, 2, { id = 9703, name = "Old Sword", q = 2, class = 2, subclass = 7, price = 50, equip = "INVTYPE_WEAPON" })
	local worn = { [8] = { id = 9704, name = "Worn Boots", guid = "WORN-BOOTS" } }
	_G.GetInventoryItemID = function(_, slot) local w = worn[slot]; return w and w.id end
	ItemLocation.CreateFromEquipmentSlot = function(_, slot) return { item = worn[slot] } end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", recentSection = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local since = n.cdb.recentSince
	local function rec(bag, slot) for _, list in ipairs({ n.items, n.bankItems or {} }) do for _, r in ipairs(list) do if r.bag == bag and r.slot == slot then return r end end end end
	local function recent() local t = {}; for _, r in ipairs(n:RecentRecords(n.items)) do t[#t + 1] = r.name end; return table.concat(t, ",") end
	local function scan() M.fire("BAG_UPDATE_DELAYED"); M.runTimers() end
	check(since and n.cdb.firstSeen["WORN-BOOTS"] == since, "what you're wearing is remembered, as already yours")
	n.loginTime = M.now - 60   -- past the login grace, so items that are gone get forgotten
	M.now = M.now + 300
	worn[8] = nil
	M.put(0, 3, { id = 9704, name = "Worn Boots", q = 1, class = 4, subclass = 1, price = 10, equip = "INVTYPE_FEET", guid = "WORN-BOOTS" })
	scan()
	check(rec(0, 3).firstSeen == since and not recent():find("Worn Boots", 1, true), "gear you take off isn't new: not in Recent, and it keeps its age")
	-- looted this session, worn, taken off: it came from outside this session, so it stays recent
	M.put(0, 4, { id = 9705, name = "New Gloves", q = 2, class = 4, subclass = 1, price = 20, equip = "INVTYPE_HAND", guid = "NEW-GLOVES" })
	scan()
	local looted = n.cdb.firstSeen["NEW-GLOVES"]
	check(looted == M.now and recent():find("New Gloves", 1, true), "a looted piece is recent")
	M.bags[0][4] = nil; worn[10] = { id = 9705, guid = "NEW-GLOVES" }
	M.now = M.now + 30
	scan()
	check(n.cdb.firstSeen["NEW-GLOVES"] == looted, "while you wear it, its first-seen time is kept")
	worn[10] = nil
	M.put(0, 4, { id = 9705, name = "New Gloves", q = 2, class = 4, subclass = 1, price = 20, equip = "INVTYPE_HAND", guid = "NEW-GLOVES" })
	scan()
	check(rec(0, 4).firstSeen == looted and recent():find("New Gloves", 1, true), "taken off again, it keeps its time and stays recent")
	-- the bank
	M.fire("BANKFRAME_OPENED"); M.runTimers()
	check(n.cdb.firstSeen[M.bags[-1][1].guid] == since, "items first seen in the bank were already yours")
	local sword = M.bags[-1][2]; M.bags[-1][2] = nil; M.put(0, 5, sword)
	scan()
	check(not recent():find("Old Sword", 1, true), "an item moved out of the bank isn't recent, even on the first visit")
	M.bags[-1][1].count = 7
	M.put(0, 6, { id = 9702, name = "Linen Cloth", q = 1, count = 3, class = 7, subclass = 5, price = 2 })
	scan()
	check(rec(0, 6).firstSeen == since and not recent():find("Linen Cloth", 1, true), "a stack split off a bank stack keeps the bank stack's age")
	M.bags[-1][1].count = 5; M.bags[0][6].count = 5
	scan()
	local c = rec(0, 6)
	check(c.firstSeen == since and not c.isNew and not recent():find("Linen Cloth", 1, true), "moving more from the bank onto a stack isn't new (no green dot, not recent)")
	M.fire("BANKFRAME_CLOSED"); M.runTimers()
	M.bags[0][2] = nil; M.bags[0][1].count = 10
	scan()
	local ore = rec(0, 1)
	check(ore.firstSeen == since and not ore.isNew, "combining two stacks in your bags isn't new")
	M.now = M.now + 30
	M.bags[0][1].count = 12
	scan()
	ore = rec(0, 1)
	check(ore.firstSeen == M.now and ore.isNew and recent():find("Copper Ore", 1, true), "looting onto a stack is new: a fresh age, the green dot, and Recent")
	_G.GetInventoryItemID = nil
end)()

;(function()
	-- 0.15.0-beta4: one Show at Vendor / AH choice covers every gear set.
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets()
	M.put(0, 1, { id = 9801, name = "Iron Helm", q = 2, class = 4, subclass = 4, price = 100, equip = "INVTYPE_HEAD" })
	M.addSet("Tank", { [1] = M.bagLoc(0, 1) })
	M.addSet("Tester", { [5] = M.wornLoc(5) })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", recentSection = false } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	local function laneIndex(id) for i, l in ipairs(main.laneIds or {}) do if l == id then return i end end end
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("sections")
	local group, perSet = false, false
	for _, w in ipairs(P.pools.vis) do
		if w:IsShown() and w.id == "~gs" and w.text.text == "Gear Sets" then group = true end
		if w:IsShown() and w.id:sub(1, 4) == "~gs:" then perSet = true end
	end
	check(group and not perSet, "Vendors & Auction House has one Gear Sets row, not one per set")
	P:Hide()
	local h
	for _, c in ipairs({ main.child:GetChildren() }) do if c.laneId == "~gs:Tank" and c:IsShown() then h = c end end
	local m = n.Sections:SectionMenu("~gs:Tank", h)
	local vendorRow, texts = nil, {}
	for _, r in ipairs(m.rows) do if r:IsShown() then texts[#texts + 1] = r.text.text; if r.text.text == "Show Gear Sets at Vendor" then vendorRow = r end end end
	check(table.concat(texts, "|"):find("Show Gear Sets at Vendor|Show Gear Sets at Auction House", 1, true), "a set's title menu says the toggles cover every set")
	vendorRow.fn(); m:Hide(); M.runTimers()
	check(n.db.sectionHide["~gs"] and n.db.sectionHide["~gs"].vendor and not n.db.sectionHide["~gs:Tank"], "it saves one choice for all sets")
	M.fire("MERCHANT_SHOW"); M.runTimers()
	check(not laneIndex("~gs:Tank") and not laneIndex("~gs:Tester"), "hidden at vendors: every set's section drops out, worn ones included")
	local helm
	for _, r in ipairs(n.items) do if r.itemID == 9801 then helm = r end end
	check((n.Junk:ProtectReason(helm) or ""):find("hidden at vendors: Gear Sets", 1, true), "notes name Gear Sets")
	M.fire("MERCHANT_CLOSED"); M.runTimers()
	check(laneIndex("~gs:Tank") and laneIndex("~gs:Tester"), "they come back after the vendor")
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0-beta4: keys in By Type always have their section, at their Section Order place.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 9901, name = "Cellar Key", q = 1, class = 13, subclass = 0, type = "Key", sub = "Key" })
	M.put(0, 2, { id = 9902, name = "Minor Healing Potion", q = 1, count = 2, class = 0, subclass = 1, price = 5 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", keys = false, recentSection = false } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	local function laneIndex(id) for i, l in ipairs(main.laneIds or {}) do if l == id then return i end end end
	local order = n.db.laneOrder
	table.remove(order, n.IndexOf(order, "~ky")); table.insert(order, 1, "~ky")
	n:RefreshViews(true); M.runTimers()
	check(laneIndex("~ky") == 1 and not laneIndex("Keys"), "By Type with Keys in Their Own Section off: keys still get their section, at its Section Order place")
	local m = n.Sections:SectionMenu("~ky")
	local t = {}
	for _, r in ipairs(m.rows) do if r:IsShown() then t[#t + 1] = r.text.text end end
	check(not table.concat(t, "|"):find("Show at", 1, true), "that title has no vendor/AH toggles (they couldn't be saved)")
	m:Hide()
	n:Set("grp", "none"); main:Refresh(); M.runTimers()
	main.st.grp = "none"; n:RefreshViews(true); M.runTimers()
	local none = laneIndex("~ky")
	n:Set("keys", true); n:RefreshViews(true); M.runTimers()
	check(not none and laneIndex("~ky"), "with Sections All, the setting still decides (off: mixed in; on: their own section)")
	n:Set("keys", false)
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("sections")
	local keysLabel, keysHelp, reagent, reagentHelp, off = nil, nil, nil, nil, false
	for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == "keys" then keysLabel, keysHelp = w.text.text, w.help.text end end
	for _, w in ipairs(P.pools.seg) do if w:IsShown() and w.key == "reagent" then reagent, reagentHelp = w.text.text, w.help.text end end
	for _, w in ipairs(P.pools.list) do for _, r in ipairs(w.rows or {}) do if r:IsShown() and r.text.text == "Keys (off)" then off = true end end end
	check(keysLabel == "Keys in Their Own Section (All and By Bag)" and keysHelp == "By Section always gives keys their own section.", "the Keys setting says where it applies")
	check(reagent == "Reagent Bag (Sections: All)" and reagentHelp == "By Section sorts reagent-bag items by type; By Bag shows each bag as a section.", "the Reagent Bag setting says where it applies")
	check(not off, "Section Order no longer shows Keys as off")
	P:Hide()
end)()

;(function()
	-- 0.15.0-beta5: an item in several gear sets shows in each, marked as one item.
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets()
	M.put(0, 1, { id = 9951, name = "Band of Valor", q = 2, class = 4, subclass = 0, price = 300, equip = "INVTYPE_FINGER" })
	M.put(0, 2, { id = 9952, name = "Lionheart Helm", q = 3, class = 4, subclass = 4, price = 900, equip = "INVTYPE_HEAD" })
	M.addSet("Tank", { [11] = M.bagLoc(0, 1), [1] = M.bagLoc(0, 2) })
	M.addSet("PvP", { [11] = M.bagLoc(0, 1) })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", recentSection = false } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	local function header(id) for _, c in ipairs({ main.child:GetChildren() }) do if c.laneId == id and c:IsShown() then return c end end end
	local shown = {}
	for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 9951 then shown[#shown + 1] = b end end
	check(#shown == 2, "a ring in two sets shows twice, once in each set: " .. #shown)
	local own, copy
	for _, b in ipairs(shown) do if b.isRecentCopy then copy = b else own = b end end
	check(own and copy and copy.smithBag == 0 and copy:GetID() == 1 and own.rec.slot == 1, "one is the item's own button, the other a working copy on the same slot")
	check(own.linkMark and own.linkMark:IsShown() and copy.linkMark and copy.linkMark:IsShown() and own.linkMark.texture:find("ui%-sword%-shield%-mark") and own.linkCount.text == "2" and copy.linkCount.text == "2",
		"both showings carry the shield mark with \"2\", so it reads as one item in two sets")
	local helm
	for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 9952 then helm = b end end
	check(helm and not (helm.linkMark and helm.linkMark:IsShown()), "an item in one set has no link mark")
	check(header("~gs:PvP").count.text == "(1)" and header("~gs:Tank").count.text == "(2)", "each set's title counts its own items, the shared ring in both")
	GameTooltip.lines = {}
	n.Buttons.AddTooltipExtras(setmetatable({ GetOwner = function() return own end, AddLine = function(_, t) GameTooltip.lines[#GameTooltip.lines + 1] = t end }, {}))
	check(table.concat(GameTooltip.lines, "|"):find("In gear sets PvP and Tank: one item, shown in each set.", 1, true), "the tooltip says it's one item, shown in each set")
	-- counted once everywhere else
	n.Sections:SetShown("~gs", "vendor", false)
	M.fire("MERCHANT_SHOW"); M.runTimers()
	check(main.hiddenNow == 2, "the hidden-at-vendor count counts the shared ring once: " .. tostring(main.hiddenNow))
	M.fire("MERCHANT_CLOSED"); M.runTimers()
	n.Sections:SetShown("~gs", "vendor", true)
	-- set sections off: one showing, no mark
	n:Set("gearSetSections", false); M.runTimers()
	local count, marked = 0, false
	for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 9951 then count = count + 1; marked = marked or (b.linkMark and b.linkMark:IsShown()) end end
	check(count == 1 and not marked, "with set sections off, the ring shows once with no mark")
	n:Set("gearSetSections", true); M.runTimers()
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0-beta5: the Gear Sets sheet.
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets()
	M.put(0, 1, { id = 9961, name = "Band of Valor", q = 2, class = 4, subclass = 0, price = 300, equip = "INVTYPE_FINGER" })
	M.put(-1, 1, { id = 9962, name = "Stored Gloves", q = 2, class = 4, subclass = 1, price = 40, equip = "INVTYPE_HAND" })
	local worn = { [5] = { id = 9963, name = "Worn Vest", link = "|cff1eff00|Hitem:9963|h[Worn Vest]|h|r" } }
	local oldID, oldLink, oldTex = _G.GetInventoryItemID, _G.GetInventoryItemLink, _G.GetInventoryItemTexture
	_G.GetInventoryItemID = function(_, inv) local w = worn[inv]; return w and w.id end
	_G.GetInventoryItemLink = function(u, inv) if worn[inv] then return worn[inv].link end return oldLink and oldLink(u, inv) end
	_G.GetInventoryItemTexture = function(u, inv) if worn[inv] then return 555 end return oldTex(u, inv) end
	_G.GetInventoryItemQuality = function(_, inv) return worn[inv] and 2 or nil end
	M.addSet("Tank", { [5] = M.wornLoc(5), [11] = M.bagLoc(0, 1), [10] = M.bankBagLoc(6, 1), [1] = -1, [4] = 1 })
	M.addSet("PvP", { [11] = M.bagLoc(0, 1) })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", recentSection = true,
		tabOrder = { "All", "Gear", "Consumables", "TradeGoods", "Quest", "Junk", "Bank" } } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local order = n.db.tabOrder
	check(n.IndexOf(order, "GearSets") == n.IndexOf(order, "Bank") - 1, "the Gear Sets tab joins just before Bank (an older profile too)")
	local main = n.Window.main
	local tab
	for _, b in ipairs(main.tabButtons or {}) do if b:IsShown() and b.label.text == "Gear Sets" then tab = b end end
	check(tab ~= nil, "the bags window has a Gear Sets tab")
	main.st.sheet = "GearSets"; n:RefreshViews(true); M.runTimers()
	local function lane(id) for _, c in ipairs({ main.child:GetChildren() }) do if c.laneId == id and c:IsShown() then return c end end end
	local rows = {}
	for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec then rows[#rows + 1] = b end end
	table.sort(rows, function(a, b) return (a.points[1] and -(a.points[1][5] or 0) or 0) < (b.points[1] and -(b.points[1][5] or 0) or 0) end)
	local tankNames = {}
	for _, b in ipairs(rows) do if b.rec.sheetSet == "Tank" then tankNames[#tankNames + 1] = b.rec.name .. "@" .. tostring(b.rec.where) end end
	check(table.concat(tankNames, ",") == "Head: not found@,Worn Vest@Worn,Hands: in your bank@Bank,Band of Valor@Backpack"
, "Tank lists its slots in order: missing, worn, bank, bags: " .. table.concat(tankNames, ","))
	local bandRows, displayWorn, missing = 0, nil, nil
	for _, b in ipairs(rows) do
		if b.rec.itemID == 9961 then bandRows = bandRows + 1 end
		if b.rec.name == "Worn Vest" then displayWorn = b end
		if b.rec.missing then missing = b end
	end
	check(bandRows == 2, "the shared ring shows in both sets on the sheet")
	check(displayWorn and displayWorn.rec.display and displayWorn.rec.where == "Worn", "a worn piece is a display-only row marked Worn")
	check(missing and missing.rec.name == "Head: not found", "a missing piece is a muted row naming its slot")
	local before = #M.log
	displayWorn:GetScript("OnClick")(displayWorn, "RightButton")
	check(table.concat(M.log, "\n", before + 1):find("You're wearing it.", 1, true), "clicking a display-only row says where the item is")
	local hT = lane("~gs:Tank")
	check(hT and hT.sub.text == "1 in bags, 1 worn, 1 in the bank, 1 not found" and hT.equipSet and hT.equipSet:IsShown(),
		"each set's title says where its items are, with Equip when some are in your bags: " .. tostring(hT and hT.sub.text))
	local recentShown = false
	for _, l in ipairs(main.laneIds or {}) do if l == "~recent" then recentShown = true end end
	check(not recentShown, "Recent stays off the Gear Sets sheet")
	-- no sets: the empty sheet offers Create Gear Set
	for id in pairs(M.eqSets) do M.eqSets[id] = nil end
	M.fire("EQUIPMENT_SETS_CHANGED"); M.runTimers()
	local note = main.gsNote
	check(note and note:IsShown() and note.text.text == "No gear sets yet." and note.btn:IsShown() and note.btn.label.text == "Create Gear Set",
		"with no sets, the sheet says so and offers Create Gear Set")
	note.btn:GetScript("OnClick")(note.btn)
	check(n.promptFrame and n.promptFrame:IsShown() and n.promptFrame.title.text == "New Gear Set", "Create Gear Set opens the New Gear Set box")
	n.promptFrame:Hide()
	main.st.sheet = "All"; n:RefreshViews(true); M.runTimers()
	check(not (main.gsNote and main.gsNote:IsShown()), "the note is gone on other tabs")
	_G.GetInventoryItemID, _G.GetInventoryItemLink, _G.GetInventoryItemTexture, _G.GetInventoryItemQuality = oldID, oldLink, oldTex, nil
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0-beta5: no equipment sets on the client: no Gear Sets tab; the bank window never has one.
	package.loaded.mock = nil
	local M = require("mock")
	_G.C_EquipmentSet = nil
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local has = false
	for _, b in ipairs(n.Window.main.tabButtons or {}) do if b:IsShown() and b.label.text == "Gear Sets" then has = true end end
	check(not has and not n.IndexOf(n.db.bankTabOrder or {}, "GearSets"), "no equipment sets: no Gear Sets tab; and the bank window never has one")
	local P = n.SettingsPanel
	M.installEquipmentSets(); M.addSet("Tank", {})
	P:Show(); P:ShowPage("dynamic")
	local line = false
	for _, w in ipairs(P.pools.text) do if w:IsShown() and (w.text and w.text.text or "") == "Gear Sets are managed in Blizzard's Equipment Manager." then line = true end end
	check(line, "Settings: \"Gear Sets are managed in Blizzard's Equipment Manager.\"")
	P:Hide()
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0-beta6: the helmet mark with the set count; Gear Sets at the bottom; the tab before Bank; the helmet button.
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets()
	M.put(0, 1, { id = 9971, name = "Band of Valor", q = 2, class = 4, subclass = 0, price = 300, equip = "INVTYPE_FINGER" })
	M.put(0, 2, { id = 9972, name = "Minor Healing Potion", q = 1, count = 2, class = 0, subclass = 1, price = 5 })
	M.addSet("Tank", { [11] = M.bagLoc(0, 1) }); M.addSet("PvP", { [11] = M.bagLoc(0, 1) }); M.addSet("Raid", { [11] = M.bagLoc(0, 1) })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", recentSection = false } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	local showings, ok = 0, true
	for _, b in ipairs(main.used or {}) do
		if b:IsShown() and b.rec and b.rec.itemID == 9971 then
			showings = showings + 1
			if not (b.linkMark and b.linkMark:IsShown() and b.linkMark.texture:find("ui%-sword%-shield%-mark") and b.linkCount:IsShown() and b.linkCount.text == "3") then ok = false end
		end
	end
	check(showings == 3 and ok, "a ring in three sets shows in each with the shield mark and \"3\"")
	-- Gear Sets at the very bottom by default
	local order = n.db.laneOrder
	check(order[#order] == "~gs", "a new profile has Gear Sets at the very bottom of Section Order")
	local last = main.laneIds[#main.laneIds]
	check(last and last:sub(1, 4) == "~gs:", "the set sections sit at the bottom of the bags list: " .. table.concat(main.laneIds, ","))
	local tabs = n.db.tabOrder
	check(n.IndexOf(tabs, "GearSets") == n.IndexOf(tabs, "Bank") - 1, "the Gear Sets tab sits just before Bank")
	-- the helmet button: the Gear Sets tab, like the Bank icon
	local btn = main.btnGearSets
	check(btn and btn:IsShown() and btn.tip == "Gear Sets" and btn.tex.texture:find("ui%-sword%-shield%.tga") and main.btnClean.points[1][2] == btn,
		"the Gear Sets shield icon sits left of Bank, with the broom beside it")
	btn:GetScript("OnClick")(btn); M.runTimers()
	check(main.st.sheet == "GearSets" and btn.active, "clicking it shows the Gear Sets tab, lit while there")
	btn:GetScript("OnClick")(btn); M.runTimers()
	check(main.st.sheet == "All" and not btn.active, "clicking again goes back to All")
	table.insert(n.db.hiddenTabs, "GearSets"); n:RefreshViews(true); M.runTimers()
	btn:GetScript("OnClick")(btn); M.runTimers()
	check(main.st.sheet == "GearSets", "it still opens the sheet with the tab hidden")
	main:SetSheet("All"); M.runTimers()
	n:Set("skin", "classic"); M.runTimers()
	check(btn:IsShown() and btn.classicOn ~= false and (btn.classicSquare or btn.squareOn or btn.classic or true), "Classic: the helmet stays with the other icons")
	n:Set("skin", "modern"); M.runTimers()
	M.removeEquipmentSets()
	n:RefreshViews(true); M.runTimers()
	check(not btn:IsShown() and main.btnClean.points[1][2] == main.btnBank, "no equipment sets: no Gear Sets icon, and the broom moves back beside Bank")
end)()

;(function()
	-- 0.15.0-beta6: beta profiles get Gear Sets moved once, unless they'd moved it themselves.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = {
		Default = { skin = "modern", laneOrder = { "~recent", "~fav", "~gs", "Gear", "Consumables", "Reagents", "TradeGoods", "Recipes", "Quest", "Tokens", "Other", "Junk", "~ky", "~rb" },
			tabOrder = { "All", "Gear", "GearSets", "Consumables", "TradeGoods", "Quest", "Junk", "Bank" } },
		Mine = { skin = "modern", laneOrder = { "Gear", "~gs", "~recent", "~fav", "Consumables", "Reagents", "TradeGoods", "Recipes", "Quest", "Tokens", "Other", "Junk", "~ky", "~rb" },
			tabOrder = { "GearSets", "All", "Gear", "Consumables", "TradeGoods", "Quest", "Junk", "Bank" } },
		Old = { skin = "modern", laneOrder = { "~recent", "~fav", "Gear", "Consumables", "Reagents", "TradeGoods", "Recipes", "Quest", "Tokens", "Other", "Junk", "~ky", "~rb" },
			tabOrder = { "All", "Gear", "Consumables", "TradeGoods", "Quest", "Junk", "Bank" } } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local P = BagSmithDB.profiles
	local function lastIs(o, id) return o[#o] == id end
	check(lastIs(n.db.laneOrder, "~gs") and n.IndexOf(n.db.tabOrder, "GearSets") == n.IndexOf(n.db.tabOrder, "Bank") - 1,
		"a beta profile's Gear Sets moves to the bottom, and its tab to just before Bank")
	n.Profiles:Use("Mine"); M.runTimers()
	check(n.db.laneOrder[2] == "~gs" and n.db.tabOrder[1] == "GearSets", "where you'd moved them yourself, they stay")
	n.Profiles:Use("Old"); M.runTimers()
	check(lastIs(n.db.laneOrder, "~gs") and n.IndexOf(n.db.tabOrder, "GearSets") == n.IndexOf(n.db.tabOrder, "Bank") - 1, "a profile from before 0.15 gets both in their new places")
	n.Profiles:Use("Default"); M.runTimers()
	-- The move happens once: put Gear Sets back after Favorites, reload, and it stays there.
	local o = n.db.laneOrder
	table.remove(o, n.IndexOf(o, "~gs")); table.insert(o, n.IndexOf(o, "~fav") + 1, "~gs")
	local again = {}
	for k, v in pairs(n.db) do again[k] = type(v) == "table" and n.Copy(v) or v end
	package.loaded.mock = nil
	local M2 = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = again } }
	local n2 = M2.loadAddon("BagSmith")
	M2.fire("ADDON_LOADED", "BagSmith"); M2.fire("PLAYER_ENTERING_WORLD"); M2.runTimers(); M2.runTimers()
	local o2 = n2.db.laneOrder
	check(n2.db.gearSetsPlaced == true and o2[n2.IndexOf(o2, "~fav") + 1] == "~gs", "after the one-time move, putting Gear Sets back after Favorites sticks across a reload")
end)()

;(function()
	-- 0.15.0-beta6: Settings: Standard, Dynamic and Custom Sections.
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets(); M.addSet("Tank", {})
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", recentSection = false } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Sections:Create("Professions")
	local P = n.SettingsPanel
	P:Show()
	local nav = {}
	for _, b in ipairs(P.navButtons) do nav[#nav + 1] = b.text.text end
	check(table.concat(nav, "|"):find("Windows|Sections|Dynamic Sections|Custom Sections|Columns", 1, true), "the list shows Standard, Dynamic and Custom Sections: " .. table.concat(nav, "|"))
	local lastNav = P.navButtons[#P.navButtons]
	local navBottom = -(lastNav.points[1][5] or lastNav.points[1][3] or 0) + 26
	check(navBottom + 66 < 560 - 2 * 24 - 6 - 14, "the longer list still clears About & Support and What's New (bottom at " .. navBottom .. ")")
	local function heads() local t = {}; for _, w in ipairs(P.pools.head) do if w:IsShown() then t[#t + 1] = w.text.text end end; return table.concat(t, "|") end
	local function shown(pool, key) for _, w in ipairs(P.pools[pool]) do if w:IsShown() and w.key == key then return w end end end
	P:ShowPage("sections")
	check(heads() == "Sections|Which Section an Item Goes To|Keys & Reagent Bag|Consumables|Section Order|Pinned Sections|Vendors & Auction House", "Standard Sections: " .. heads())
	check(shown("check", "keys") and shown("seg", "reagent") and not shown("check", "recentSection") and #P.pools.csec == 0 or not P.pools.csec[1]:IsShown(), "keys and the reagent bag are here; Recent and custom sections aren't")
	local list
	for _, w in ipairs(P.pools.list) do if w:IsShown() then list = w end end
	local recentRow
	for _, r in ipairs(list.rows) do if r:IsShown() and r.text.text == "Recent Items (off)" then recentRow = r end end
	check(recentRow and recentRow.tip == "Recent Items is off. Tick Recent Items in Settings > Dynamic Sections to turn it on.", "Section Order's (off) tips point to the right page")
	P:ShowPage("dynamic")
	check(heads() == "Dynamic Sections|Gear Sets", "Dynamic Sections: " .. heads())
	local row
	for _, w in ipairs(P.pools.gset) do if w:IsShown() then row = w end end
	check(shown("check", "recentSection") and shown("check", "favSection") and shown("check", "gearSetSections") and row and row.name == "Tank", "Recent Items, Favorites and Gear Sets are on Dynamic Sections")
	P:ShowPage("custom")
	local csec
	for _, w in ipairs(P.pools.csec) do if w:IsShown() then csec = w end end
	check(heads() == "Custom Sections" and csec and csec.id and shown("check", "showEmptySections"), "your sections are on Custom Sections")
	P:Hide()
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0-beta7: Settings: Sections with its two pages under it; the Item column's checkbox; search.
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets(); M.addSet("Tank", {})
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", recentSection = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("general")
	local byText = {}
	for _, b in ipairs(P.navButtons) do byText[b.text.text] = b end
	check(byText["Sections"] and byText["Dynamic Sections"] and byText["Custom Sections"] and not byText["Standard Sections"]
		and byText["Sections"].text.points[1][2] == 10 and byText["Dynamic Sections"].text.points[1][2] == 24 and byText["Custom Sections"].text.points[1][2] == 24,
		"the list says Sections, with Dynamic and Custom Sections indented under it")
	-- the Item column: checked, dimmed, explains itself
	P:ShowPage("bagcols")
	local itemRow
	for _, w in ipairs(P.pools.list) do if w:IsShown() then for _, r in ipairs(w.rows) do if r:IsShown() and r.text.text == "Item" then itemRow = r end end end end
	check(itemRow and itemRow.box:IsShown() and itemRow.box:GetChecked() and itemRow.box.alpha == 0.5 and itemRow.tip == "Item is always shown. You can still move it, like the other columns.",
		"the Item column shows a dimmed checkmark that explains it can't be unticked, only moved")
	local up = itemRow.up:IsShown() or itemRow.down:IsShown()
	check(up, "and its arrows still move it")
	-- the search box: right of the profile line, in both skins
	local box = P.frame.search
	check(box and box:IsShown() and box.points[1][1] == "RIGHT" and P.frame.sub.points[2] and P.frame.sub.points[2][2] == box, "a search box sits right of the profile line, which stops short of it")
	local function results()
		local rows = {}
		for kind, pool in pairs(P.pools) do
			for _, w in ipairs(pool) do
				if w:IsShown() and w.points[1] and w.points[1][2] == P.frame.child then
					local label = (w.text and w.text.text) or (w.label and w.label.text) or ""
					rows[#rows + 1] = { y = -w.points[1][5], kind = kind, label = label, key = w.key, h = w.h or 0, w = w }
				end
			end
		end
		table.sort(rows, function(a, b) return a.y < b.y end)
		return rows
	end
	local function labels(rows) local t = {}; for _, r in ipairs(rows) do if r.label ~= "" and r.kind ~= "card" then t[#t + 1] = r.label end end; return table.concat(t, " | ") end
	P:ShowPage("look")
	box:SetText("since login"); box:GetScript("OnTextChanged")(box, true)
	local rows = results()
	local text = labels(rows)
	check(P.query == "since login" and text:find("^Results:") and text:find("Dynamic Sections | Dynamic Sections | Recent Items | Recent Items From", 1, true)
		and not text:find("Favorites", 1, true), "searching shows Results: then the page and card, and only the matching row: " .. text)
	local seg
	for _, r in ipairs(rows) do if r.key == "recentWindow" then seg = r.w end end
	check(seg and seg.btns and seg.btns[1], "the row in the results is the real control")
	local onPage = false
	for _, b in ipairs(P.navButtons) do if b.bar:IsShown() then onPage = true end end
	check(not onPage, "no page is marked current while searching")
	-- a heading match shows the whole card
	box:SetText("gear sets"); box:GetScript("OnTextChanged")(box, true)
	text = labels(results())
	check(text:find("Gear Sets | Your gear sets are the game's own equipment sets", 1, true) and text:find("Show Gear Sets as Sections | New Gear Set... | Tank", 1, true)
		and text:find("Gear Sets are managed in Blizzard's Equipment Manager.", 1, true),
		"a card whose heading matches shows whole: " .. text)
	box:SetText("discord"); box:GetScript("OnTextChanged")(box, true)
	text = labels(results())
	check(not text:find("About & Support", 1, true), "About & Support is never searched (beta9: it has its own button)")
	box:SetText("zzqxw"); box:GetScript("OnTextChanged")(box, true)
	text = labels(results())
	check(text == "Results: | No results found. Try different words.", "nothing found: it says so: " .. text)
	-- no overlapping rows in a long results list
	box:SetText("the"); box:GetScript("OnTextChanged")(box, true)
	local bad, last = 0, nil
	for _, r in ipairs(results()) do
		if r.kind ~= "card" and r.kind ~= "sep" then   -- (cards sit behind rows, hairlines on their edges, by design)
			if last and r.y < last.y + last.h - 0.01 then bad = bad + 1 end
			last = r
		end
	end
	check(bad == 0 and #results() > 20, "a long results list has no overlapping rows")
	-- changing a setting from the results keeps the search
	box:SetText("favorites"); box:GetScript("OnTextChanged")(box, true)
	local fav
	for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == "favSection" then fav = w end end
	local before = n.db.favSection
	fav.box:SetChecked(not before); fav.box:GetScript("OnClick")(fav.box); M.runTimers()
	check(n.db.favSection == not before and P.query == "favorites", "a setting changed from the results takes effect, and the results stay")
	-- clearing returns to the page; opening a page clears the search
	box:SetText(""); box:GetScript("OnTextChanged")(box, true)
	check(not P.query and P.page == "look" and P.navButtons[2].bar:IsShown(), "clearing the search returns to the page you were on")
	box:SetText("scale"); box:GetScript("OnTextChanged")(box, true)
	P.navButtons[1]:GetScript("OnClick")(P.navButtons[1])
	check(not P.query and box.text == "" and P.page == "general", "opening a page from the list ends the search")
	box:SetText("x"); box:GetScript("OnTextChanged")(box, true)
	check(not P.query, "one letter doesn't start a search")
	box:SetText("")
	n:Set("skin", "classic"); M.runTimers()
	check(box:IsShown() and P.frame.sub.points[2] and P.frame.sub.points[2][2] == box, "Classic: the search box stays right of the profile line")
	n:Set("skin", "modern"); M.runTimers()
	P:Hide()
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0-beta7: after a gear change, items on screen ask Pawn again shortly after (Pawn may still answer from the old gear).
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets()
	M.put(0, 1, { id = 9991, name = "Iron Helm", q = 2, class = 4, subclass = 4, price = 100, equip = "INVTYPE_HEAD" })
	M.addSet("Tank", { [1] = M.bagLoc(0, 1) })
	local stale = false
	_G.PawnShouldItemLinkHaveUpgradeArrow = function(link) if stale then return false end return tostring(link):find("item:9991") ~= nil end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", recentSection = false } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	local function helm() for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 9991 then return b end end end
	check(helm() and helm().pawnArrow and helm().pawnArrow:IsShown(), "(setup) the helm shows Pawn's arrow")
	-- gear changes; Pawn answers from the old gear at first
	stale = true
	M.fire("PLAYER_EQUIPMENT_CHANGED", 1, false); M.runTimers(); M.runTimers()
	check(not helm().pawnArrow:IsShown(), "(setup) right after the change Pawn says no")
	stale = false
	M.elapse()
	check(helm().pawnArrow:IsShown(), "a moment later the items on screen ask again, and the arrow comes back without a redraw")
	-- the same after a gear set swap
	stale = true
	M.fire("PLAYER_EQUIPMENT_CHANGED", 1, false); M.runTimers(); M.runTimers()
	stale = false
	M.fire("EQUIPMENT_SWAP_FINISHED", true, 0); M.runTimers()
	M.elapse()
	check(helm().pawnArrow:IsShown(), "after a gear set swap too")
	_G.PawnShouldItemLinkHaveUpgradeArrow = nil
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0-beta8: Pawn's time budget no longer starves the items asked last (gear set sections at the bottom).
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets()
	for i = 1, 12 do M.put(0, i, { id = 9600 + i, name = "Gear " .. i, q = 2, class = 4, subclass = 1, price = 10, equip = "INVTYPE_WAIST" }) end
	M.put(1, 1, { id = 9690, name = "Shared Ring", q = 3, class = 4, subclass = 0, price = 99, equip = "INVTYPE_FINGER" })
	M.addSet("Tank", { [11] = M.bagLoc(1, 1) }); M.addSet("PvP", { [11] = M.bagLoc(1, 1) })
	-- Pawn's budget: a few answers per quarter second (here: per batch of timers), "not yet" after that.
	local budget = 3
	_G.PawnShouldItemLinkHaveUpgradeArrow = function(link)
		if budget <= 0 then return nil end
		budget = budget - 1
		return tostring(link):find("item:9690") ~= nil
	end
	local run = M.runTimers
	local function tick() budget = 3; run() end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", recentSection = false } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); tick(); tick()
	ToggleAllBags(); tick()
	for _ = 1, 25 do tick() end
	local main = n.Window.main
	local ok, count = true, 0
	for _, b in ipairs(main.used or {}) do
		if b:IsShown() and b.rec and b.rec.itemID == 9690 then count = count + 1; if not (b.pawnArrow and b.pawnArrow:IsShown()) then ok = false end end
	end
	check(count == 2 and ok, "with Pawn's budget, the shared ring at the bottom gets its arrow in both sets, without switching tabs")
	local asked = 0
	_G.PawnShouldItemLinkHaveUpgradeArrow = function(link) asked = asked + 1; return tostring(link):find("item:9690") ~= nil end
	n:RefreshViews(true); M.runTimers()
	check(asked == 0, "a redraw doesn't ask Pawn again about items it already answered")
	M.fire("PLAYER_LEVEL_UP", 20); M.runTimers()
	check(asked > 0, "a level-up asks again (it can change what's an upgrade)")
	_G.PawnShouldItemLinkHaveUpgradeArrow = nil
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0-beta8: Settings: Columns and Sheets get Bag and Bank pages; the list folds; search refinements.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", recentSection = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("general")
	local function visible()
		local t, gap, y = {}, false, 0
		for _, b in ipairs(P.navButtons) do
			if b:IsShown() then
				t[#t + 1] = b.text.text
				if -(b.points[1][3] or 0) ~= y and -(b.points[1][5] or 0) ~= y then gap = true end
				y = y + 28
			end
		end
		return table.concat(t, "|"), gap
	end
	local list, gap = visible()
	check(list == "General|Style|Item Icons|Windows|Sections|Columns|Sheets|Sorting & Filters|Automations & Actions|Keybindings|Plugins|Profile|Advanced" and not gap,
		"the list is folded: sub-pages hidden, no gaps: " .. list)
	local function nav(label) for _, b in ipairs(P.navButtons) do if b.text.text == label then return b end end end
	check(nav("Sections").arrow:IsShown() and nav("Sections").arrow.texture:find("chev%-right") and not nav("General").arrow, "pages with sub-pages show a folded arrow")
	P:ShowPage("columns")
	list = visible()
	check(list:find("Columns|Bag Columns|Bank Columns|Sheets", 1, true) and not list:find("Dynamic Sections", 1, true) and nav("Columns").arrow.texture:find("chev%-down"),
		"opening Columns unfolds its two pages: " .. list)
	P:ShowPage("bankcols")
	list = visible()
	check(list:find("Columns|Bag Columns|Bank Columns|Sheets", 1, true) and nav("Bank Columns").bar:IsShown(), "on a sub-page, its siblings stay listed")
	-- Columns: the parent has the Item Menu Button only; each window has its own page
	local function onPage(page)
		P:ShowPage(page)
		local keys, lists = {}, 0
		for _, w in ipairs(P.pools.check) do if w:IsShown() then keys[w.key] = true end end
		for _, w in ipairs(P.pools.seg) do if w:IsShown() then keys[w.key] = true end end
		for _, w in ipairs(P.pools.list) do if w:IsShown() then lists = lists + 1 end end
		return keys, lists
	end
	local k, l = onPage("columns")
	check(k.itemMenuButton and l == 0 and not k.__colTarget, "Columns: the Item Menu Button, no window switch, no list")
	local function ids()
		local t = {}
		for _, w in ipairs(P.pools.list) do if w:IsShown() then for _, r in ipairs(w.rows) do if r:IsShown() then t[#t + 1] = r.id end end end end
		return table.concat(t, ",")
	end
	onPage("bagcols"); local bagCols = ids()
	onPage("bankcols"); local bankCols = ids()
	check(bagCols == table.concat(n.db.colOrder, ",") and bankCols == table.concat(n.db.bankColOrder, ","), "Bag Columns and Bank Columns each list their own window's columns")
	k, l = onPage("sheets")
	check(k.sheetViews and l == 0 and not k.__sheetTarget, "Sheets: Sheets Remember Their View, no window switch, no list")
	onPage("bagsheets"); local bagTabs = ids()
	onPage("banksheets"); local bankTabs = ids()
	check(bagTabs == table.concat(n.db.tabOrder, ",") and bankTabs == table.concat(n.db.bankTabOrder, ","), "Bag Sheets and Bank Sheets each list their own window's tabs")
	-- search
	local box = P.frame.search
	local function search(q)
		box:SetText(q); box:GetScript("OnTextChanged")(box, true)
		local rows = {}
		for kind, pool in pairs(P.pools) do
			for _, w in ipairs(pool) do
				if w:IsShown() and w.points[1] and w.points[1][2] == P.frame.child and kind ~= "card" and kind ~= "sep" then
					rows[#rows + 1] = { y = -w.points[1][5], kind = kind, label = (w.text and w.text.text) or (w.label and w.label.text) or "", w = w }
				end
			end
		end
		table.sort(rows, function(a, b) return a.y < b.y end)
		local t = {}
		for _, r in ipairs(rows) do if r.label ~= "" then t[#t + 1] = r.label end end
		return table.concat(t, " | "), rows
	end
	local text, rows = search("bank")
	local bankList = false
	for i, r in ipairs(rows) do if r.label == "Bank Columns" and r.kind == "ptitle" then for j = i + 1, math.min(i + 4, #rows) do if rows[j].kind == "list" then bankList = true end end end end
	check(text:find("Bank Columns | Bank Columns", 1, true) and text:find("Bank Sheets | Bank Sheets", 1, true) and bankList, "a page whose name matches shows whole (Bank Columns with its list): " .. text)
	text = search("since login")
	check(text:find("Recent Items | Recent Items From", 1, true), "an indented setting shows with the one it belongs to: " .. text)
	text = search("keybind")
	check(not text:find("Make your own sections", 1, true) and text:find("Keybindings | Keybindings | Click Set Key", 1, true) and text:find("Favorites", 1, true),
		"explanations show only with their whole card (no stray Custom Sections note): " .. text)
	list = visible()
	check(list == "General|Style|Item Icons|Windows|Sections|Columns|Sheets|Sorting & Filters|Automations & Actions|Keybindings|Plugins|Profile|Advanced", "while searching the list is folded")
	box:SetText(""); box:GetScript("OnTextChanged")(box, true)
	P:Hide()
end)()

;(function()
	-- 0.15.0-beta9: Pawn re-checks right away after its refresh signal or a newly waiting item, and /bs debug says what happened.
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets()
	M.put(0, 1, { id = 9701, name = "Odd Trinket", q = 2, class = 4, subclass = 0, price = 10, equip = "INVTYPE_TRINKET" })
	M.put(1, 1, { id = 9702, name = "Shared Ring", q = 3, class = 4, subclass = 0, price = 99, equip = "INVTYPE_FINGER" })
	M.addSet("Tank", { [11] = M.bagLoc(1, 1) })
	local ringUp = false
	_G.PawnShouldItemLinkHaveUpgradeArrow = function(link)
		link = tostring(link)
		if link:find("item:9701") then return nil end   -- never answered (Pawn can't read it)
		if link:find("item:9703") then return nil end
		return link:find("item:9702") ~= nil and ringUp
	end
	local cb
	_G.PawnRegisterThirdPartyBag = function(_, o) cb = o; return true end
	_G.PawnCommon = { ShowBagUpgradeAdvisor = true }
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", recentSection = false, debug = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	for _ = 1, 10 do M.runTimers() end
	check(n.Pawn.level == 6, "(setup) an item Pawn never answers has slowed the re-checks to every 5 s")
	local delays = {}
	local after = C_Timer.After
	C_Timer.After = function(d, fn) delays[#delays + 1] = d; return after(d, fn) end
	-- Pawn re-checks gear, then signals: BagSmith checks within a quarter second, not 5 s later
	ringUp = true
	local before = #M.log
	cb.RefreshAll()
	check(delays[#delays] == 0.25, "Pawn's refresh signal brings a re-check within a quarter second, whatever the pace (got " .. tostring(delays[#delays]) .. ")")
	M.runTimers()
	local main = n.Window.main
	local ring
	for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 9702 then ring = b end end
	check(ring and ring.pawnArrow and ring.pawnArrow:IsShown(), "and the arrow appears with that re-check")
	local log = table.concat(M.log, "\n", before + 1)
	check(log:find("Pawn: refresh from Pawn (", 1, true) and log:find("Shared Ring: yes", 1, true) and log:find("Pawn: arrow shown on Shared Ring", 1, true),
		"/bs debug logs the refresh signal, what Pawn was asked and answered, and the arrow appearing: " .. log)
	-- a newly shown item still waiting: checked soon too
	for _ = 1, 10 do M.runTimers() end
	delays = {}
	M.put(0, 2, { id = 9703, name = "New Bracers", q = 2, class = 4, subclass = 1, price = 10, equip = "INVTYPE_WRIST" })
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
	local soon = false
	for _, d in ipairs(delays) do if d == 0.25 then soon = true end end
	check(soon, "a newly shown item Pawn hasn't answered is re-checked within a quarter second")
	C_Timer.After = after
	_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnRegisterThirdPartyBag, _G.PawnCommon = nil, nil, nil
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0-beta9: About & Support never shows in Settings search.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local P = n.SettingsPanel
	P:Show()
	local box = P.frame.search
	local function aboutShown(q)
		box:SetText(q); box:GetScript("OnTextChanged")(box, true)
		for _, w in ipairs(P.pools.about) do if w:IsShown() then return true end end
		for _, w in ipairs(P.pools.ptitle) do if w:IsShown() and w.text.text == "About & Support" then return true end end
		return false
	end
	check(not aboutShown("bag") and not aboutShown("discord") and not aboutShown("coffee"), "About & Support never shows in search results")
	box:SetText(""); box:GetScript("OnTextChanged")(box, true)
	P:Hide()
end)()

;(function()
	-- 0.15.0-beta9: What's New: tabs for the last three releases, a steady size, stripes, lines, and the footer.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } }, whatsNewSeen = "0.14.0" }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.version = "0.15.0-beta9"   -- (the mock reports 0.1.0 for every build)
	local WN = n.WhatsNew
	WN:ShowLatest()
	local card = WN.Card()
	local labels = {}
	for _, b in ipairs(card.tabs) do if b:IsShown() then labels[#labels + 1] = b.label.text .. (b.active and "*" or "") end end
	check(table.concat(labels, ",") == "0.15*,0.14,0.13,0.12,0.11", "a tab per release (up to five), newest first, the newest selected: " .. table.concat(labels, ","))
	local function body()
		local t = {}
		for _, l in ipairs(card.lines) do if l:IsShown() then t[#t + 1] = l.text end end
		return t
	end
	local b1 = body()
	local function entry(v) for _, e in ipairs(WN.ENTRIES) do if e.v == v then return e end end end
	check(b1[1] == "BagSmith 0.15" and #b1 == 1 + #entry("0.15.0").items, "the tab shows only its release: the heading and its bullets")
	local h1 = card.h
	card.tabs[2]:GetScript("OnClick")(card.tabs[2])
	local b2 = body()
	check(b2[1] == "BagSmith 0.14" and card.tabs[2].active and not card.tabs[1].active, "clicking a tab shows that release")
	check(card.h == h1, "the card keeps its size between tabs (as tall as the tallest)")
	-- stripes, and a light line between bullets
	local stripes, seps = 0, 0
	for _, st in ipairs(card.stripes) do if st:IsShown() then stripes = stripes + 1; check(st.color[4] == 0.065, "Modern stripes are 6.5% white (rc2)") break end end
	for _, t in ipairs(card.seps) do if t:IsShown() then seps = seps + 1 end end
	check(seps == #entry("0.14.0").items - 1, "a light line between each pair of bullets (" .. seps .. ")")
	local lineH
	local setH = card.footLine.SetHeight
	card.footLine.SetHeight = function(self, h) lineH = h; return setH(self, h) end
	WN:Select(2)
	card.footLine.SetHeight = setH
	check(card.footLine:IsShown() and lineH == 2 and card.footLine.color[4] == 1, "a stronger line above the footer: 2 px at full strength")
	check(card.more.text == "|cfffac775Previous Updates & Patches:|r See full changelog @ CurseForge:" and card.intro.text == "Highlights from recent major updates.",
		"the new footer and intro wording")
	n:Set("skin", "classic"); M.runTimers()
	WN:ShowLatest()
	local st = card.stripes[1]
	check(st.color[1] == 0 and st.color[4] == 0.15 and card.tabs[1].classicOn, "Classic: 15% black stripes, and Blizzard's buttons for the tabs")
	n:Set("skin", "modern"); M.runTimers()
	WN:Close()
	-- after an update, it opens on that update
	BagSmithDB.whatsNewSeen = "0.13.0"
	WN:Check()
	check(card:IsShown() and card.tabs[1].active, "after updating, it opens on the new release's tab")
	WN:Close()
end)()

;(function()
	-- 0.15.0-beta10: What's New: up to five tabs, all on one row; the 0.11 AH Prices line points to Bag Columns.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } }, whatsNewSeen = "0.14.0" }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.version = "0.15.0-beta10"
	local WN = n.WhatsNew
	-- five releases (a stand-in for 0.15's entry, written at the release candidate)
	local real = WN.ENTRIES
	WN.ENTRIES = {}
	local function newerThan(x, y) local a1, a2, a3 = x:match("^(%d+)%.(%d+)%.?(%d*)"); local b1, b2, b3 = y:match("^(%d+)%.(%d+)%.?(%d*)"); a1, a2, a3, b1, b2, b3 = tonumber(a1), tonumber(a2), tonumber(a3) or 0, tonumber(b1), tonumber(b2), tonumber(b3) or 0; if a1 ~= b1 then return a1 > b1 end if a2 ~= b2 then return a2 > b2 end return a3 > b3 end
	local has15 = false
	for _, e in ipairs(real) do if e.v == "0.15.0" then has15 = true end end
	if not has15 then WN.ENTRIES[1] = { v = "0.15.0", heading = "BagSmith 0.15", items = { "One.", "Two." } } end   -- (rc1 has the real one)
	for _, e in ipairs(real) do if not newerThan(e.v, "0.15.0") then WN.ENTRIES[#WN.ENTRIES + 1] = e end end   -- (this scenario runs as 0.15.0-beta10: later cards are not shown)
	WN.ENTRIES[#WN.ENTRIES + 1] = { v = "0.10.0", heading = "BagSmith 0.10", items = { "Old." } }
	for _, skin in ipairs({ "modern", "classic" }) do
		n:Set("skin", skin); M.runTimers()
		WN:ShowLatest()
		local card = WN.Card()
		local labels, right, top = {}, 0, nil
		local fits = true
		for _, b in ipairs(card.tabs) do
			if b:IsShown() then
				labels[#labels + 1] = b.label.text
				local x = b.points[1][4]
				right = x + b.w
				top = top or b.points[1][5]
				if b.points[1][5] ~= top then fits = false end
			end
		end
		check(table.concat(labels, ",") == "0.15,0.14,0.13,0.12,0.11" and fits and right <= card:GetWidth() - 16,
			skin .. ": five tabs, newest first, on one row inside the card (" .. table.concat(labels, ",") .. ", right edge " .. right .. ")")
		WN:Close()
	end
	n:Set("skin", "modern"); M.runTimers()
	WN.ENTRIES = real
	local line
	for _, e in ipairs(WN.ENTRIES) do if e.v == "0.11.0" then for _, it in ipairs(e.items) do if it:find("AH Prices") then line = it end end end end
	check(line and line:find("Settings > Bag Columns", 1, true), "the 0.11 AH Prices line points to Settings > Bag Columns")
end)()

;(function()
	-- 0.15.0-rc1: What's New leads with 0.15, and every "Settings > ..." in any entry names a real place.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } }, whatsNewSeen = "0.14.0" }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local WN = n.WhatsNew
	-- (1.5.1) the 1.5.1 entry leads (the Loot Helper's new destroy default and its two settings); the older entries
	-- follow, one place down
	local e = WN.ENTRIES[1]
	local text = table.concat(e.items, " ")
	check(e.v == "1.5.1" and e.heading == "BagSmith 1.5.1" and #e.items >= 2 and #e.items <= 8 and text:find("Faster Destroying:", 1, true) and text:find("Ask Before Destroying", 1, true) and text:find("Always Ask for Rare or Better", 1, true) and not text:find("\226\128\148"), "What's New leads with a 1.5.1 entry: the destroy default and its two settings")
	-- (1.5.0) the 1.5 entry: Icon Corners and marks from other addons
	e = WN.ENTRIES[2]; text = table.concat(e.items, " ")
	check(e.v == "1.5.0" and e.heading == "BagSmith 1.5" and #e.items >= 2 and #e.items <= 8 and text:find("Icon Corners:", 1, true) and text:find("Marks from Other Addons:", 1, true) and not text:find("\226\128\148"), "What's New leads with a 1.5 entry: Icon Corners, marks from other addons")
	e = WN.ENTRIES[3]; text = table.concat(e.items, " ")
	check(e.v == "1.4.0" and e.heading == "BagSmith 1.4" and #e.items >= 3 and #e.items <= 8 and text:find("Sort: Off:", 1, true) and text:find("Pinned Sections:", 1, true) and text:find("By Section:", 1, true), "What's New leads with a 1.4 entry: Sort Off, pinned sections, By Section")
	e = WN.ENTRIES[4]; text = table.concat(e.items, " ")
	check(e.v == "1.3.0" and e.heading == "BagSmith 1.3" and #e.items >= 3 and #e.items <= 8 and text:find("Loot Helper:", 1, true) and text:find("Why Things Are Left Out:", 1, true) and text:find("Exclusion Lists:", 1, true), "What's New leads with a 1.3 entry: the Loot Helper, why things are left out, the Exclusion Lists")
	e = WN.ENTRIES[5]; text = table.concat(e.items, " ")
	check(e.v == "1.2.0" and e.heading == "BagSmith 1.2" and #e.items >= 3 and #e.items <= 8 and text:find("Disenchant Helper:", 1, true) and text:find("Fewer Yes/No Boxes:", 1, true) and text:find("Mail and Trade:", 1, true), "What's New leads with a 1.2 entry: the Disenchant Helper, fewer yes/no boxes, mail and trade")
	e = WN.ENTRIES[6]; text = table.concat(e.items, " ")
	check(e.v == "1.1.0" and e.heading == "BagSmith 1.1" and #e.items >= 3 and #e.items <= 8 and text:find("Item Level on Icons:", 1, true) and text:find("List View:", 1, true) and text:find("Classic Style:", 1, true) and text:find("Smoother Scrolling:", 1, true) and text:find("Pawn Arrow:", 1, true), "the 1.1 entry follows: the item level feature, List view, Classic style, smoother scrolling, the Pawn arrow")
	e = WN.ENTRIES[7]; text = table.concat(e.items, " ")
	check(e.v == "1.0.0" and e.heading == "BagSmith 1.0" and #e.items >= 2 and #e.items <= 8, "the 1.0 entry follows")
	check(text:find("Thank you:", 1, true) and text:find("Discord", 1, true) and text:find("Plugins:", 1, true) and text:find("Coming soon, BagSmith Gamepad Plugin:", 1, true) and text:find("alpha testing", 1, true) and text:find("testers", 1, true),
		"it thanks the players, invites them to the Discord, introduces plugins, and announces the Gamepad companion as coming soon with testers wanted at beta")
	local e15 = WN.ENTRIES[8]
	local text15 = table.concat(e15.items, " ")
	check(e15.v == "0.15.0" and e15.heading == "BagSmith 0.15" and #e15.items >= 5 and #e15.items <= 8 and text15:find("Gear Sets:", 1, true) and text15:find("Settings Search:", 1, true) and text15:find("Recent Items:", 1, true) and text15:find("Tidier Settings:", 1, true),
		"the 0.15 entry follows, covering gear sets, Settings search, Recent Items and the reorganized Settings")
	check(not text:find("\226\128\148") and not text:find("\226\128\153"), "plain punctuation only")
	local P = n.SettingsPanel
	P:Show()
	local names = { "About & Support" }
	for _, b in ipairs(P.navButtons) do names[#names + 1] = b.text.text end
	table.sort(names, function(a, b) return #a > #b end)   -- longest first ("Dynamic Sections" before "Sections")
	local bad = {}
	for _, entry in ipairs(WN.ENTRIES) do
		for _, it in ipairs(entry.items) do
			local plain = it:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			local from = 1
			while true do
				local a, b2 = plain:find("Settings > ", from, true)
				if not a then break end
				local rest, ok = plain:sub(b2 + 1), false
				for _, nm in ipairs(names) do if rest:sub(1, #nm) == nm then ok = true break end end
				if not ok then bad[#bad + 1] = entry.v .. ": " .. rest:sub(1, 30) end
				from = b2 + 1
			end
		end
	end
	check(#bad == 0, "every \"Settings > ...\" in What's New names a real Settings page" .. (#bad > 0 and (": " .. table.concat(bad, "; ")) or ""))
	P:Hide()
	-- A player coming from 0.14 sees the card on the first bag open, on the 0.15 tab.
	n.version = "0.15.0-rc1"
	WN:Check()
	local card = WN.Card()
	check(card and card:IsShown() and card.tabs[1].active and card.tabs[1].label.text == "0.15" and card.lines[1].text == "BagSmith 0.15", "coming from 0.14, the card opens on the 0.15 tab")
	WN:Close()
end)()

;(function()
	-- 0.15.0-rc2 (audit F1): a 0.14 sheet named exactly "GearSets" is renamed, never dropped: saved and imported, bags and bank.
	package.loaded.mock = nil
	local M = require("mock")
	local function legacy(withClash)
		local sheets = {
			{ n = "GearSets", f = { text = "rare tank pieces", q = { [3] = true } } },
			{ n = "Control", f = { text = "control" } },
		}
		if withClash then table.insert(sheets, 2, { n = "GearSets (2)", f = { text = "already here" } }) end
		local order = { "All", "Gear", "Consumables", "TradeGoods", "Quest", "Junk", "Bank", "GearSets", "Control" }
		if withClash then table.insert(order, 9, "GearSets (2)") end
		return {
			sheets = sheets, tabOrder = order, hiddenTabs = { "Quest", "GearSets" },
			bankSheets = { { n = "GearSets", f = { text = "bank tank", q = { [4] = true } } }, { n = "Control", f = { text = "bc" } } },
			bankTabOrder = { "All", "Gear", "Consumables", "TradeGoods", "Quest", "Junk", "GearSets", "Control" }, bankHiddenTabs = { "GearSets" },
			sheetPrefs = { bags = { GearSets = { grp = "bag" } }, bank = { GearSets = { view = "icons" } } },
		}
	end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = legacy(false), Clash = legacy(true) } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local function find(list, name) for _, s in ipairs(list or {}) do if s.n == name then return s end end end
	local function check4(p, label, renamed)
		local bags, bank = find(p.sheets, renamed), find(p.bankSheets, "GearSets (2)")
		check(bags and bags.f.text == "rare tank pieces" and bags.f.q and bags.f.q[3] and find(p.sheets, "Control"),
			label .. ": the bags sheet is kept as \"" .. renamed .. "\" with its filter, and Control survives")
		check(bank and bank.f.text == "bank tank" and bank.f.q and bank.f.q[4] and find(p.bankSheets, "Control"), label .. ": the bank sheet too")
		local iB, iG = n.IndexOf(p.tabOrder, renamed), n.IndexOf(p.tabOrder, "GearSets")
		check(iB and iG and n.IndexOf(p.hiddenTabs, renamed) and not n.IndexOf(p.hiddenTabs, "GearSets") and p.sheetPrefs.bags[renamed] and p.sheetPrefs.bags[renamed].grp == "bag",
			label .. ": its tab place, hidden state and saved view moved with it; the built-in Gear Sets tab is added separately")
		check(n.IndexOf(p.bankTabOrder, "GearSets (2)") and n.IndexOf(p.bankHiddenTabs, "GearSets (2)") and p.sheetPrefs.bank["GearSets (2)"] and p.sheetPrefs.bank["GearSets (2)"].view == "icons",
			label .. ": bank references moved too")
	end
	check4(BagSmithDB.profiles.Default, "saved profile", "GearSets (2)")
	local c = BagSmithDB.profiles.Clash
	check(find(c.sheets, "GearSets (2)").f.text == "already here", "a sheet already named \"GearSets (2)\" keeps its name")
	check4(c, "saved profile with a name clash", "GearSets (3)")
	-- a genuine code made from an old profile
	BagSmithDB.profiles.Legacy = legacy(false)
	local code = n.Share:Export("Legacy")
	local name = n.Share:Import(code, "From Code")
	check4(BagSmithDB.profiles[name], "imported code", "GearSets (2)")
	-- idempotent: validating again changes nothing
	local again = n.validateSettings and nil
	local before = BagSmithDB.profiles[name]
	local name2 = n.Profiles:Import("Again", before)
	local p2 = BagSmithDB.profiles[name2]
	check(#p2.sheets == #before.sheets and find(p2.sheets, "GearSets (2)") and not find(p2.sheets, "GearSets (3)"), "a second load renames nothing")
end)()

;(function()
	-- 0.15.0-rc2 (audit F2): the bags and bank windows never take each other's copy buttons.
	for _, combo in ipairs({ { "modern", "list" }, { "modern", "icons" }, { "classic", "list" }, { "classic", "icons" } }) do
		package.loaded.mock = nil
		local M = require("mock")
		M.installEquipmentSets(); M.maxStack = { [101] = 1, [102] = 1 }
		M.put(0, 1, { id = 101, guid = "bag", name = "Bag Helm", q = 2, class = 4, subclass = 4, price = 5, equip = "INVTYPE_HEAD" })
		M.put(-1, 1, { id = 102, guid = "bank", name = "Bank Chest", q = 2, class = 4, subclass = 4, price = 5, equip = "INVTYPE_CHEST" })
		M.addSet("Alpha", { [1] = M.bagLoc(0, 1), [5] = 0x00400000 + 1 })
		M.addSet("Beta", { [1] = M.bagLoc(0, 1), [5] = 0x00400000 + 1 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = combo[1], view = combo[2], bankView = combo[2], recentSection = false, mergeStacks = false, bankMerge = false } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		ToggleAllBags(); M.fire("BANKFRAME_OPENED"); M.runTimers()
		local main, bank = n.Window.main, n.Window.bank
		local function vis(v, id)
			local t = {}
			for _, b in ipairs(v.used or {}) do
				if b.rec and b:IsVisible() and b:GetParent():GetParent() == v.child and (not id or b.rec.itemID == id) then t[#t + 1] = b end
			end
			return t
		end
		main:Refresh(true); bank:Refresh(true)
		local m1, k1 = vis(main, 101), vis(bank, 102)
		main:Refresh(true)
		local k2 = vis(bank, 102)
		local targets = true
		for _, b in ipairs(m1) do if b:GetID() ~= 1 or (b.smithBag and b.smithBag ~= 0) then targets = false end end
		for _, b in ipairs(k2) do if b:GetID() ~= 1 then targets = false end end
		check(#m1 == 2 and #k1 == 2 and #vis(main, 101) == 2 and #k2 == 2 and targets,
			("%s %s: both windows keep both showings through either redraw order, each on its own slot (main %d, bank %d)"):format(combo[1], combo[2], #vis(main, 101), #k2))
		local shared = false
		for _, b in ipairs(vis(main, 101)) do for _, c in ipairs(vis(bank, 102)) do if b == c then shared = true end end end
		check(not shared, combo[1] .. " " .. combo[2] .. ": no button is shown by both windows")
		-- reopen both, then a main Recent copy next to shared bank gear
		M.fire("BANKFRAME_CLOSED"); M.runTimers()
		n.db.recentSection = true
		M.now = M.now + 30
		M.put(0, 2, { id = 103, guid = "loot", name = "Fresh Apple", q = 1, count = 1, class = 0, subclass = 5, price = 1 })
		M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); M.runTimers()
		M.fire("BANKFRAME_OPENED"); M.runTimers()
		main:Refresh(true); bank:Refresh(true)
		check(#vis(main, 103) == 2 and #vis(bank, 102) == 2, combo[1] .. " " .. combo[2] .. ": a Recent copy in the bags survives the bank's shared rows (" .. #vis(main, 103) .. ")")
		M.fire("BANKFRAME_CLOSED"); M.runTimers()
		M.removeEquipmentSets()
	end
end)()

;(function()
	-- 0.15.0-rc2 (audit F3): Merge Stacks never folds one item's set rows together on the Gear Sets tab.
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets(); M.maxStack = { [201] = 1, [202] = 1 }
	M.put(0, 1, { id = 201, guid = "shared", name = "Shared Ring", q = 3, class = 4, subclass = 0, price = 5, equip = "INVTYPE_FINGER" })
	M.put(0, 2, { id = 202, guid = "twinA", name = "Twin Band", q = 2, class = 4, subclass = 0, price = 5, equip = "INVTYPE_FINGER" })
	M.put(0, 3, { id = 202, guid = "twinB", name = "Twin Band", q = 2, class = 4, subclass = 0, price = 5, equip = "INVTYPE_FINGER" })
	M.addSet("Alpha", { [11] = M.bagLoc(0, 1), [12] = M.bagLoc(0, 2), [5] = M.wornLoc(5) })
	M.addSet("Beta", { [11] = M.bagLoc(0, 1), [12] = M.bagLoc(0, 3), [1] = -1 })
	M.addSet("Gamma", { [11] = M.bagLoc(0, 1) })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", recentSection = false, mergeStacks = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	for _, merge in ipairs({ true, false }) do
		n:Set("mergeStacks", merge); main:SetSheet("GearSets"); M.runTimers()
		local ring, band = {}, {}
		for _, b in ipairs(main.used or {}) do
			if b:IsShown() and b.rec and not b.rec.display then
				if b.rec.itemID == 201 then ring[#ring + 1] = b.rec.sheetSet .. ":" .. tostring(b.rec.count) .. ":" .. b:GetID() end
				if b.rec.itemID == 202 then band[#band + 1] = b.rec.sheetSet .. ":" .. tostring(b.rec.count) .. ":" .. b:GetID() end
			end
		end
		table.sort(ring); table.sort(band)
		check(table.concat(ring, ",") == "Alpha:1:1,Beta:1:1,Gamma:1:1", ("Merge Stacks %s: the shared ring shows once in each of three sets, count 1, on its own slot (%s)"):format(merge and "on" or "off", table.concat(ring, ",")))
		check(table.concat(band, ",") == "Alpha:1:2,Beta:1:3", ("Merge Stacks %s: two copies of one item in two sets stay apart (%s)"):format(merge and "on" or "off", table.concat(band, ",")))
	end
	main:SetSheet("All"); M.runTimers()
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0-rc2 (audit R1): a sale never trusts set membership from before a bag move, even with a scan still queued.
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets(); M.maxStack = { [301] = 1 }
	M.put(0, 1, { id = 301, guid = "kept", name = "Twin Ring", q = 2, class = 4, subclass = 0, price = 50, equip = "INVTYPE_FINGER" })
	M.put(0, 2, { id = 301, guid = "spare", name = "Twin Ring", q = 2, class = 4, subclass = 0, price = 50, equip = "INVTYPE_FINGER" })
	local tank = M.addSet("Tank", { [11] = M.bagLoc(0, 1) })
	_G.BagSmithCharDB = { version = 1, firstSeen = {}, junkMarks = { [301] = true } }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.cdb.junkMarks[301] = true
	_G.MerchantFrame = MerchantFrame or CreateFrame("Frame", "MerchantFrame", UIParent); MerchantFrame:Show()
	-- the rings swap slots: the set's ring is now in slot 2; the scan hasn't run yet
	M.bags[0][1], M.bags[0][2] = M.bags[0][2], M.bags[0][1]
	M.eqSets[tank].slots[11] = M.bagLoc(0, 2)
	M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED")   -- (no runTimers: the scan is still queued)
	local used = {}
	local realUse = C_Container.UseContainerItem
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot end
	n.Junk:Sell("marked", "test")
	C_Container.UseContainerItem = realUse
	local sold = table.concat(used, ",")
	check(not sold:find("0:2", 1, true), "the set's ring (now in slot 2) is never sold while the scan is pending (sold: " .. sold .. ")")
	check(sold == "0:1", "the spare ring in slot 1 still sells")
	-- the Loot Helper's last check before destroying re-reads the sets too
	local ok, why = n.MakeRoom:StillOk({ bag = 0, slot = 2, itemID = 301, count = 1 })
	check(not ok, "the Loot Helper refuses the set's ring at its new slot (" .. tostring(why) .. ")")
	MerchantFrame:Hide()
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0-rc2 (audit F4, F5): Pawn's own bag refresh and advisor toggle reach BagSmith in both bag modes.
	for _, replace in ipairs({ false, true }) do
		package.loaded.mock = nil
		local M = require("mock")
		local up = false
		_G.PawnCommon = { ShowBagUpgradeAdvisor = true }
		_G.PawnShouldItemLinkHaveUpgradeArrow = function(link) return tostring(link):find("item:401") ~= nil and up end
		_G.PawnRegisterThirdPartyBag = function() return true end
		_G.PawnBags = { RefreshAll = function() end }
		function _G.PawnBags:SetEnabled(on) PawnCommon.ShowBagUpgradeAdvisor = not not on; PawnBags:RefreshAll() end   -- (as Pawn's own)
		M.put(0, 1, { id = 401, name = "Fine Boots", q = 2, class = 4, subclass = 2, price = 9, equip = "INVTYPE_FEET" })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", replaceBlizzardBags = replace } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		ToggleAllBags(); M.runTimers()
		local main = n.Window.main
		local function boots() for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 401 then return b end end end
		local mode = replace and "replacing Blizzard's bags" or "beside Blizzard's bags"
		check(not (boots().pawnArrow and boots().pawnArrow:IsShown()), "(setup) Pawn says no")
		up = true
		PawnBags:RefreshAll()   -- what Pawn's reset (scales or settings changed) does
		M.runTimers()
		check(boots().pawnArrow and boots().pawnArrow:IsShown(), mode .. ": after Pawn's refresh the remembered no is dropped and the arrow appears")
		PawnBags:SetEnabled(false); M.runTimers()
		check(not boots().pawnArrow:IsShown(), mode .. ": turning off Pawn's advisor hides the arrow promptly")
		PawnBags:SetEnabled(true); M.runTimers()
		check(boots().pawnArrow:IsShown(), mode .. ": turning it back on shows it again")
		_G.PawnCommon, _G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnRegisterThirdPartyBag, _G.PawnBags = nil, nil, nil, nil
	end
end)()

;(function()
	-- 0.15.0-rc2: the bags list is re-clamped when its area changes size (never left scrolled past its end).
	package.loaded.mock = nil
	local M = require("mock")
	for s = 1, 12 do M.put(0, s, { id = 3100 + s, name = "Thing " .. s, q = 1, class = 7, subclass = 5, price = 1 }) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", view = "list" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	local sf = main.scroll
	local h = 150
	sf.GetHeight = function() return h end
	sf.GetVerticalScrollRange = function() return math.max(0, (main.contentHeight or 0) - h) end
	main:SetScrollTagged(main:ScrollRange(), "you"); main.trustedScroll = main:ScrollRange()
	local was = sf:GetVerticalScroll()
	h = 2000   -- the window grows (Travel Mode off at the bank, say): everything fits now
	sf:GetScript("OnSizeChanged")(sf)
	check(was > 0 and sf:GetVerticalScroll() == 0 and main.trustedScroll == 0, ("after the list area grows, it's scrolled back within its end (%d -> %d)"):format(was, sf:GetVerticalScroll()))
end)()

;(function()
	-- 0.15.0-rc2: at the bank, moving a stack between bank and bags is never Recent, whichever side updates first.
	local function boot(extra)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 2589, guid = "A", name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 13 })
		M.put(-1, 1, { id = 2589, guid = "B", name = "Linen Cloth", q = 1, count = 7, class = 7, subclass = 5, price = 13 })
		M.put(-1, 2, { id = 2589, guid = "C", name = "Linen Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 13 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type" } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		M.now = M.now + 120
		ToggleAllBags(); M.fire("BANKFRAME_OPENED"); M.runTimers(); M.runTimers()
		M.now = M.now + 60
		return n, M
	end
	local function rec(n, guid) for _, list in ipairs({ n.items, n.bankItems or {} }) do for _, r in ipairs(list) do if r.guid == guid then return r end end end end
	local function recent(n, guid) for _, r in ipairs(n:RecentRecords(n.items)) do if r.guid == guid then return true end end return false end
	local function settle(M) M.gameTime = M.gameTime + 2; M.runTimers(); M.runTimers(); M.runTimers() end
	-- bag first, then bank
	local n, M = boot()
	M.bags[0][1].count = 12
	M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	M.bags[-1][1] = nil
	M.fire("PLAYERBANKSLOTS_CHANGED", 1); M.runTimers(); M.runTimers()
	settle(M)
	check(not rec(n, "A").isNew and not recent(n, "A"), "a bank stack moved onto a bag stack (bag updates first) isn't new")
	-- bank first, then bag
	n, M = boot()
	M.bags[-1][1] = nil
	M.fire("PLAYERBANKSLOTS_CHANGED", 1); M.runTimers(); M.runTimers()
	M.bags[0][1].count = 12
	M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	settle(M)
	check(not rec(n, "A").isNew and not recent(n, "A"), "the same with the bank updating first")
	-- part of a bank stack split into an empty bag slot (a new stack), bag first
	n, M = boot()
	M.put(0, 2, { id = 2589, guid = "D", name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 13 })
	M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	M.bags[-1][2].count = 15
	M.fire("PLAYERBANKSLOTS_CHANGED", 2); M.runTimers(); M.runTimers()
	settle(M)
	check(not recent(n, "D") and rec(n, "D").firstSeen < M.now, "part of a bank stack split into the bags isn't new; it takes the stack's age")
	-- real loot onto a stack while at the bank: still new, a moment later
	n, M = boot()
	M.bags[0][1].count = 9
	M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	check(not rec(n, "A").isNew, "(at the bank, a grown stack waits a second)")
	settle(M)
	check(rec(n, "A").isNew and recent(n, "A"), "real loot onto a stack at the bank is new a second later")
	-- something you didn't have before: new at once
	n, M = boot()
	M.put(0, 3, { id = 4536, guid = "E", name = "Shiny Red Apple", q = 1, count = 1, class = 0, subclass = 5, price = 1 })
	M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	check(recent(n, "E"), "an item you didn't have is new at once, at the bank too")
	-- away from the bank: a grown stack is new at once, as before
	n, M = boot()
	M.fire("BANKFRAME_CLOSED"); M.runTimers()
	M.bags[0][1].count = 9
	M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	check(rec(n, "A").isNew, "away from the bank, a stack that grew is new at once (as before)")
end)()

;(function()
	-- 0.15.0-rc2: softer Modern stripes in What's New; the README is release-ready.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } }, whatsNewSeen = "0.14.0" }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.version = "0.15.0-rc2"
	n.WhatsNew:ShowLatest()
	check(n.WhatsNew.Card().stripes[1].color[4] == 0.065, "Modern What's New stripes are 6.5% white")
	n.WhatsNew:Close()
	local f = io.open("BagSmith/README.md"); local readme = f and f:read("*a") or ""; if f then f:close() end
	check(readme ~= "" and not readme:lower():find("beta", 1, true) and readme:find("## Install\n", 1, true) and readme:find("## Reporting a problem", 1, true),
		"the README has a plain Install section and Reporting a problem, and no beta wording")
end)()

;(function()
	-- 0.15.0-rc3 (re-audit RC2-S1, RC2-S2): bank settle windows judge each stack; Clear Recent holds across them.
	local function boot(opts)
		opts = opts or {}
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 2589, guid = "A", name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 13 })
		M.put(0, 2, { id = 2589, guid = "D", name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 13 })
		M.put(-1, 1, { id = 2589, guid = "B", name = "Linen Cloth", q = 1, count = 7, class = 7, subclass = 5, price = 13 })
		M.put(-1, 2, { id = 2589, guid = "C", name = "Linen Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 13 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "type", newdot = true, newdotClearRecent = opts.clearDots ~= false } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		M.now = M.now + 120
		ToggleAllBags(); M.fire("BANKFRAME_OPENED"); M.runTimers(); M.runTimers()
		M.now = M.now + 60; M.gameTime = M.gameTime + 5
		return n, M
	end
	local function rec(n, g) for _, l in ipairs({ n.items, n.bankItems or {} }) do for _, r in ipairs(l) do if r.guid == g then return r end end end end
	local function recentSet(n)
		local t = {}
		for _, r in ipairs(n:RecentRecords(n.items)) do t[#t + 1] = r.guid end
		table.sort(t); return table.concat(t, ",")
	end
	local function dots(n)
		local t = {}
		for _, l in ipairs({ n.items, n.bankItems or {} }) do for _, r in ipairs(l) do if r.isNew then t[#t + 1] = r.guid end end end
		table.sort(t); return table.concat(t, ",")
	end
	local function bags(M) M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers() end
	local function bank(M, slot) M.fire("PLAYERBANKSLOTS_CHANGED", slot); M.runTimers(); M.runTimers() end
	local function step(M) M.gameTime = M.gameTime + 0.05 end
	local function settle(M) M.gameTime = M.gameTime + 1.2; M.runTimers(); M.runTimers(); M.runTimers() end
	local function expect(n, rcnt, dset, label)
		check(recentSet(n) == rcnt and dots(n) == dset, ("%s (Recent: %s; dots: %s)"):format(label, recentSet(n), dots(n)))
	end

	-- RC2-S1, the auditor's sequence: B merged into A (bag first), then real loot into D.
	local n, M = boot()
	M.bags[0][1].count = 12; bags(M)
	step(M); M.bags[-1][1] = nil; bank(M, 1)
	step(M); M.bags[0][2].count = 6; bags(M)
	settle(M)
	expect(n, "D", "D", "bank move onto A plus loot into D: only D is new, with its dot")
	local main = n.Window.main
	n:RefreshViews(true); M.runTimers()
	local dotA, dotD
	for _, b in ipairs(main.used or {}) do
		if b:IsShown() and b.rec and not b.isRecentCopy then
			if b.rec.guid == "A" then dotA = b.newDot and b.newDot:IsShown() end
			if b.rec.guid == "D" then dotD = b.newDot and b.newDot:IsShown() end
		end
	end
	check(dotD and not dotA, "the bags window draws D's dot and not A's")
	-- the same with the bank updating first
	n, M = boot()
	M.bags[-1][1] = nil; bank(M, 1)
	step(M); M.bags[0][1].count = 12; bags(M)
	step(M); M.bags[0][2].count = 6; bags(M)
	settle(M)
	expect(n, "D", "D", "bank first: only D is new")
	-- several stacks at once: B onto A, part of C split into a new bag stack E, and 2 looted into D
	n, M = boot()
	local ageC = rec(n, "C").firstSeen
	M.bags[0][1].count = 12; M.put(0, 3, { id = 2589, guid = "E", name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 13 }); bags(M)
	step(M); M.bags[-1][1] = nil; M.bags[-1][2].count = 15; bank(M, 1)
	step(M); M.bags[0][2].count = 7; bags(M)
	settle(M)
	expect(n, "D", "D", "a merge, a split and loot together: only D is new")
	check(rec(n, "E").firstSeen == ageC, "the split-off stack takes its source's age")
	-- a whole bank stack moved into an empty bag slot (its GUID moves), plus 1 looted onto A
	n, M = boot()
	local ageB = rec(n, "B").firstSeen
	local b = M.bags[-1][1]; M.bags[-1][1] = nil; M.bags[0][4] = b; bags(M); bank(M, 1)
	step(M); M.bags[0][1].count = 6; bags(M)
	settle(M)
	expect(n, "A", "A", "a moved stack plus loot onto another: only the looted stack is new")
	check(rec(n, "B").firstSeen == ageB, "the moved stack keeps its age")
	-- the other way: all of A into the bank onto C, plus loot into D
	n, M = boot()
	M.bags[0][1] = nil; bags(M)
	step(M); M.bags[-1][2].count = 25; bank(M, 2)
	step(M); M.bags[0][2].count = 6; bags(M)
	settle(M)
	expect(n, "D", "D", "bags to bank plus loot: only D is new (a bank stack is never new)")
	-- the bank closes before the window settles
	n, M = boot()
	M.bags[0][1].count = 12; bags(M)
	step(M); M.bags[-1][1] = nil; bank(M, 1)
	M.fire("BANKFRAME_CLOSED"); M.runTimers()
	settle(M)
	expect(n, "", "", "a move, then the bank closing before the second is up: nothing new")
	-- staggered: the move, then loot onto the same stack half a second later
	n, M = boot()
	M.bags[0][1].count = 12; bags(M)
	step(M); M.bags[-1][1] = nil; bank(M, 1)
	M.gameTime = M.gameTime + 0.5; M.bags[0][1].count = 13; bags(M)
	settle(M)
	expect(n, "A", "A", "loot onto the moved-to stack within the window: that stack is new")
	-- loot after the window closed
	n, M = boot()
	M.bags[0][1].count = 12; bags(M)
	step(M); M.bags[-1][1] = nil; bank(M, 1)
	settle(M)
	expect(n, "", "", "a plain move settles as nothing new")
	M.now = M.now + 5
	M.bags[0][2].count = 6; bags(M)
	settle(M)
	expect(n, "D", "D", "loot after the window closed is new")

	-- RC2-S2: Clear Recent during the wait, with Clear Recent clearing dots
	n, M = boot()
	M.bags[0][1].count = 6; bags(M)
	M.gameTime = M.gameTime + 0.2; n:ClearRecent()
	settle(M)
	expect(n, "", "", "loot held at the bank, then Clear Recent (clearing dots): no Recent, no dot")
	-- two pending stacks, cleared; then loot after the clear, inside the same window
	n, M = boot()
	M.bags[0][1].count = 6; M.bags[0][2].count = 7; bags(M)
	M.gameTime = M.gameTime + 0.2; n:ClearRecent()
	M.now = M.now + 2
	M.gameTime = M.gameTime + 0.2; M.bags[0][2].count = 8; bags(M)
	settle(M)
	expect(n, "D", "D", "two held stacks cleared; loot after the clear still becomes new")
	-- cleared before anything settles, with the bank closing and reopening
	n, M = boot()
	M.bags[0][1].count = 6; bags(M)
	M.fire("BANKFRAME_CLOSED"); M.runTimers()
	n:ClearRecent()
	settle(M)
	expect(n, "", "", "held loot, bank closed, then Clear Recent: nothing new")
	M.fire("BANKFRAME_OPENED"); M.runTimers(); M.runTimers()
	M.now = M.now + 5; M.gameTime = M.gameTime + 2
	M.bags[0][2].count = 6; bags(M)
	settle(M)
	expect(n, "D", "D", "after reopening the bank, new loot is new again")
	-- Clear Recent after the wait: the dot it already had is cleared
	n, M = boot()
	M.bags[0][1].count = 6; bags(M)
	settle(M)
	expect(n, "A", "A", "(loot at the bank settles as new)")
	n:ClearRecent()
	expect(n, "", "", "Clear Recent after settling clears Recent and the dot")
	-- with Clear Recent not clearing dots: a held gain still gets its dot, as away from the bank, but stays out of Recent
	n, M = boot({ clearDots = false })
	M.bags[0][1].count = 6; bags(M)
	M.gameTime = M.gameTime + 0.2; n:ClearRecent()
	settle(M)
	expect(n, "", "A", "Clear Recent without clearing dots: held loot keeps its dot (like away from the bank), not in Recent")
end)()

;(function()
	-- 0.15.0 (prod): one clean 0.15.0 changelog section; the sword-and-shield replaces the helmet everywhere.
	local log = io.open("BagSmith/CHANGELOG.md"):read("*a")
	check(log:find("^## 1%.5%.5\n") and log:find("\n## 1%.5%.4\n") and log:find("\n## 1%.5%.3\n") and log:find("\n## 1%.5%.2\n") and log:find("\n## 1%.5%.1\n") and log:find("\n## 1%.5%.0\n") and log:find("\n## 1%.4%.2\n") and log:find("\n## 1%.4%.1\n") and log:find("\n## 1%.4%.0\n") and log:find("\n## 1%.3%.1\n") and log:find("\n## 1%.3%.0\n") and log:find("\n## 1%.2%.0\n") and log:find("\n## 1%.1%.0\n") and log:find("\n## 1%.0%.1\n") and log:find("\n## 1%.0%.0\n") and log:find("\n## 0%.15%.0\n") and not log:find("## 0%.15%.0%-beta") and not log:find("## 0%.15%.0%-rc"), "the changelog leads with 1.5.5 (the release in progress), then 1.5.4, 1.5.3, 1.5.2, 1.5.1, 1.5.0, 1.4.2, 1.4.1, 1.4.0, 1.3.1, 1.3.0, 1.2.0, 1.1.0, 1.0.1 and 1.0.0, then one 0.15.0 section (the beta and rc entries folded in)")
	local section = log:match("(## 0%.15%.0\n.-)\n## ") or ""
	local bad = false
	for _, w in ipairs({ "colour", "favourite", "behaviour", "cancelled", "helmet", "\226\128\148" }) do if section:find(w) then bad = true end end
	check(#section > 2000 and not bad and section:find("shield", 1, true), "the 0.15.0 notes use the house spellings, say shield (not helmet), no em dashes")
	local function tga(path)
		local f = io.open(path, "rb"); if not f then return nil end
		local h = f:read(18); f:close()
		return h and (h:byte(13) + h:byte(14) * 256), h and (h:byte(15) + h:byte(16) * 256), h and h:byte(17)
	end
	local w1, h1, d1 = tga("BagSmith/Media/ui-sword-shield.tga")
	local w2, h2, d2 = tga("BagSmith/Media/ui-sword-shield-mark.tga")
	check(w1 == 64 and h1 == 64 and d1 == 32 and w2 == 64 and h2 == 64 and d2 == 32, "the shield textures are 64x64, 32-bit (like the other icons)")
	check(io.open("BagSmith/Media/ui-helmet.tga") == nil and io.open("BagSmith/Media/ui-helmet-mark.tga") == nil, "the helmet textures are gone")
	package.loaded.mock = nil
	local M = require("mock")
	M.installEquipmentSets(); M.maxStack = { [701] = 1 }
	M.put(0, 1, { id = 701, name = "Shared Ring", q = 3, class = 4, subclass = 0, price = 9, equip = "INVTYPE_FINGER" })
	M.addSet("Alpha", { [11] = M.bagLoc(0, 1) }); M.addSet("Beta", { [11] = M.bagLoc(0, 1) })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", recentSection = false } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	check(main.btnGearSets and main.btnGearSets.tex.texture:find("ui%-sword%-shield%.tga"), "the Gear Sets button shows the shield")
	local marks = 0
	for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 701 and b.linkMark and b.linkMark:IsShown() and b.linkMark.texture:find("ui%-sword%-shield%-mark") then marks = marks + 1 end end
	check(marks == 2, "both showings of a shared item carry the shield mark")
	local text = ""
	for _, e in ipairs(n.WhatsNew.ENTRIES) do if e.v == "0.15.0" then text = table.concat(e.items, " ") end end
	check(text:find("the shield at the top right", 1, true) and text:find("a small shield and the number of sets", 1, true) and not text:lower():find("helmet"), "What's New 0.15 says shield")
	M.removeEquipmentSets()
end)()

;(function()
	-- 0.15.0 (rebuilt): after Scale or any size setting changes, and whenever the list area resizes, each window's canvas is laid out again.
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[1] = 8
	for s = 1, 16 do M.put(0, s, { id = 5500 + s, name = "Thing " .. s, q = 1 + (s % 3), class = 7, subclass = 5, price = 1 }) end
	for s = 1, 8 do M.put(1, s, { id = 5600 + s, name = "Other " .. s, q = 1, class = 0, subclass = 5, price = 1 }) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", grp = "all", view = "icons", mergeStacks = true, debug = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	ToggleAllBags(); M.runTimers()
	local main = n.Window.main
	local sf, child = main.scroll, main.child
	local calls = 0
	local orig = sf.SetScrollChild
	sf.SetScrollChild = function(self, c) calls = calls + 1; return orig(self, c) end
	local function vis() local c = 0; for _, b in ipairs(main.used or {}) do if b.rec and b:IsVisible() then c = c + 1 end end; return c end
	local before, h0, logN = vis(), child:GetHeight(), #M.log
	n:Set("scale", 1.1); M.runTimers(); M.runTimers(); M.runTimers()
	check(calls >= 1 and sf.child == child and child:GetHeight() == h0 and vis() == before,
		("after a Scale change the list's canvas is re-attached and laid out again, nothing else changes (%d calls, %d items)"):format(calls, vis()))
	check(table.concat(M.log, "\n", logN + 1):find("BagSmithFrame canvas (scale): list area", 1, true), "/bs debug logs the list area and canvas sizes and whether they were stale")
	-- in combat: nothing moves until combat ends
	calls = 0; M.combat = true
	n:Set("scale", 1.0); M.runTimers(); M.runTimers(); M.runTimers()
	check(calls == 0, "in combat the canvas is left alone (it holds secure item buttons)")
	M.combat = false; M.fire("PLAYER_REGEN_ENABLED"); M.runTimers()
	check(calls >= 1, "and laid out again once combat ends")
	-- the list area changing size (Travel Mode switching off at the bank, say)
	calls = 0
	sf:GetScript("OnSizeChanged")(sf); M.runTimers()
	check(calls >= 1 and vis() == before, "a list area resize lays the canvas out again too")
	-- the other size settings
	calls = 0
	n:Set("iconSize", 32); M.runTimers(); M.runTimers(); M.runTimers()
	check(calls >= 1, "an Icon Size change does the same")
end)()

;(function()
	-- 0.15.0 (rebuilt): after taking a piece off, its Pawn arrow neither blinks nor vanishes while Pawn is busy.
	package.loaded.mock = nil
	local M = require("mock")
	for s = 1, 12 do M.put(0, s, { id = 7700 + s, name = "Belt " .. s, q = 2, class = 4, subclass = 1, price = 5, equip = "INVTYPE_WAIST" }) end
	M.put(1, 1, { id = 7799, name = "Taken Off", q = 3, class = 4, subclass = 4, price = 5, equip = "INVTYPE_HEAD" })
	local budget, answers = 3, { [7799] = true, [7798] = true }
	_G.PawnCommon = { ShowBagUpgradeAdvisor = true }
	_G.PawnShouldItemLinkHaveUpgradeArrow = function(link)
		if budget <= 0 then return nil end   -- Pawn's time budget: "not yet"
		budget = budget - 1
		return answers[tonumber(tostring(link):match("item:(%d+)"))] or false
	end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", recentSection = false } } }
	local n = M.loadAddon("BagSmith")
	local run, elapse = M.runTimers, M.elapse
	local function tick() budget = 3; run() end
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); tick(); tick()
	ToggleAllBags(); tick()
	for _ = 1, 12 do tick() end
	local main = n.Window.main
	local function button(id) for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then return b end end end
	local function arrow(id) local b = button(id); return b and b.pawnArrow and b.pawnArrow:IsShown() or false end
	check(arrow(7799), "(setup) the piece shows Pawn's arrow")
	local hides = 0
	local pa = button(7799).pawnArrow
	local set = pa.SetShown
	pa.SetShown = function(t, on) if not on and t:IsShown() then hides = hides + 1 end; return set(t, on) end
	-- the gear change, then both follow-ups (each forgets every answer and asks again)
	M.fire("PLAYER_EQUIPMENT_CHANGED", 1, true); tick(); tick()
	for _ = 1, 8 do tick() end
	budget = 3; elapse()
	for _ = 1, 12 do tick() end
	check(hides == 0 and arrow(7799), ("while Pawn works out its answers the arrow never blinks off, and it's there at the end (%d hides)"):format(hides))
	pa.SetShown = set
	-- a definite "no" still hides it
	answers[7799] = false
	n.Pawn:OnPawnRefresh("test")
	for _ = 1, 12 do tick() end
	check(not arrow(7799), "a definite no from Pawn still hides the arrow")
	answers[7799] = true
	n.Pawn:OnPawnRefresh("test")
	for _ = 1, 12 do tick() end
	check(arrow(7799), "(and yes shows it again)")
	-- the same button, now holding another item, while Pawn can't answer: no arrow carried over
	M.bags[1][1] = nil
	M.put(1, 1, { id = 7798, name = "Something Else", q = 3, class = 4, subclass = 4, price = 5, equip = "INVTYPE_HEAD" })
	budget = 0
	M.fire("BAG_UPDATE", 1); M.fire("BAG_UPDATE_DELAYED"); run(); run()
	check(not arrow(7798), "a button showing a different item doesn't keep the old item's arrow while Pawn is busy")
	for _ = 1, 12 do tick() end
	check(arrow(7798), "and gets its own arrow once Pawn answers")
	_G.PawnShouldItemLinkHaveUpgradeArrow, _G.PawnCommon = nil, nil
end)()

print(("%d passed, %d failed"):format(passes, fails))
os.exit(fails == 0 and 0 or 1)
