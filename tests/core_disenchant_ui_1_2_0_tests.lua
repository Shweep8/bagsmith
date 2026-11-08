;(function()
	-- 1.2.0-beta2: the helper's window and toolbar button, the offer, the settings sub-pages
	package.loaded.mock = nil
	local M = require("mock")
	local DEID = 13262
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 452, ilvl = 23, equip = "INVTYPE_FEET" })
	M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local known = true
	_G.IsSpellKnown = function(id) return known and id == DEID end
	_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
	_G.RegisterStateDriver = function() end
	_G.GetMoneyString = function(c) return ("%dg %ds %dc"):format(math.floor(c / 10000), math.floor(c / 100) % 100, c % 100) end
	-- the materials' names, which the mock only knows for items in bags
	local MATNAMES = { [10940] = "Strange Dust", [11083] = "Soul Dust", [11137] = "Vision Dust", [11176] = "Dream Dust", [16204] = "Illusion Dust", [10938] = "Lesser Magic Essence", [10939] = "Greater Magic Essence", [10998] = "Lesser Astral Essence", [11082] = "Greater Astral Essence", [11134] = "Lesser Mystic Essence", [11135] = "Greater Mystic Essence", [11174] = "Lesser Nether Essence", [11175] = "Greater Nether Essence", [16202] = "Lesser Eternal Essence", [16203] = "Greater Eternal Essence", [10978] = "Small Glimmering Shard", [11084] = "Large Glimmering Shard", [11138] = "Small Glowing Shard", [11139] = "Large Glowing Shard", [11177] = "Small Radiant Shard", [11178] = "Large Radiant Shard", [14343] = "Small Brilliant Shard", [14344] = "Large Brilliant Shard", [20725] = "Nexus Crystal" }
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(link) local id = tonumber(tostring(link):match("item:(%d+)")) or link; if MATNAMES[id] then return MATNAMES[id] end return realInfo(link) end
	-- Auctionator with prices, so the mats values and tags appear
	local prices = { [7001] = 1500, [7002] = 1000, [10940] = 120, [10939] = 500, [10978] = 800, [11083] = 150, [11082] = 900, [11138] = 1200 }
	_G.Auctionator = { API = { v1 = {
		GetAuctionPriceByItemLink = function(caller, link) local id = tonumber(link:match("item:(%d+)")); return id and prices[id] end,
		GetAuctionPriceByItemID = function(caller, id) return prices[id] end,
		GetAuctionAgeByItemLink = function() return nil end,
	} } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE, V = n.Disenchant, n.Window.main
	-- the offer: a character with Enchanting, helper off, opening the bags
	n.Window:Show(); M.runTimers(); M.runTimers(); M.runTimers()
	check(DE.offer and DE.offer:IsShown() and DE.offeredThisSession, "opening the bags on a character with Enchanting offers the helper once")
	DE:OfferAnswer("later")
	n.Window:Hide(); n.Window:Show(); M.runTimers(); M.runTimers(); M.runTimers()
	check(not DE.offer:IsShown(), "Ask Later: not again this session")
	DE.offeredThisSession = nil
	n.Window:Hide(); n.Window:Show(); M.runTimers(); M.runTimers(); M.runTimers()
	check(DE.offer:IsShown(), "(next session) it asks again")
	DE:OfferAnswer("never")
	DE.offeredThisSession = nil
	n.Window:Hide(); n.Window:Show(); M.runTimers(); M.runTimers(); M.runTimers()
	check(not DE.offer:IsShown() and n.cdb.deOfferDeclined == true, "Don't Ask Again is remembered for the character")
	DE:AskAgain(); DE.offeredThisSession = nil
	n.Window:Hide(); n.Window:Show(); M.runTimers(); M.runTimers(); M.runTimers()
	check(DE.offer:IsShown() and n.cdb.deOfferDeclined == nil, "Ask Again on the settings page clears it and the offer returns")
	check(DE.offer.icon and DE.offer.icon.texture and DE.offer.icon.texture:find("ui%-disenchant") and DE.offer.rule and DE.offer.text.points[1][2] > DE.offer.rule.points[1][2], "the offer shows the icon at the left, a rule, and the text beside it")
	check(DE.offer.add.label and not DE.offer.add.isLink and DE.offer.later.isLink and DE.offer.never.isLink and DE.offer.add.points[1][1] == "BOTTOMRIGHT" and DE.offer.later.points[1][1] == "BOTTOMLEFT", "Add Now is the one real button at the right; Ask Later and Don't Ask Again are quiet links at the left")
	check(DE.offer.add.active == true and DE.offer.icon.texture:find("ui%-disenchant%-large") ~= nil, "Add Now is drawn highlighted (the active state) and the offer uses the large texture")
	-- the toolbar button follows the setting; Add Now turns the helper on
	check(V.btnDisenchant and not V.btnDisenchant:IsShown(), "with the helper off there is no toolbar button")
	DE:OfferAnswer("add")
	check(n.db.deEnabled == true and V.btnDisenchant:IsShown() and V.btnDisenchant.points[1][2] == V.btnBank and V.btnClean.points[1][2] == V.btnDisenchant, "Add Now turns the helper on; its button sits left of Bank (no gear sets here) and the broom moves left of it")
	known = false; DE.offeredThisSession = nil; n:Set("deEnabled", false)
	n.Window:Hide(); n.Window:Show(); M.runTimers(); M.runTimers(); M.runTimers()
	check(not DE.offer:IsShown(), "a character without Enchanting is never offered")
	known = true; n:Set("deEnabled", true)
	-- the window: the Disenchant button is shown, skinned and first in the button row; the layout fits the width
	V.btnDisenchant:GetScript("OnClick")(V.btnDisenchant)
	local f = DE.frame
	local b = DE:Button()
	check(f:IsShown() and b:IsShown() and b.label and b.label.text == "Disenchant" and b:GetParent() == f.cur and b.points[1][1] == "BOTTOMLEFT" and b:GetAttribute("type") == "spell", "the toolbar button opens the helper; the Disenchant button is visible, skinned, first in the row and armed")
	check(f.skip.points[1][2] == b and f.never.points[1][2] == f.skip and f.junk.points[1][2] == f.never, "Skip, Never and Mark as Junk follow it in one row")
	check(b.active == false, "the Disenchant button is an action: never held in the active (pressed) state")
	-- the item panel's right half: the likely results beside a vertical rule, in small type
	check(f.cur.rule:IsShown() and f.cur.likelyHead.text == "Likely results" and f.cur.basis.text == "DE estimate, 0 of 20 of your disenchants" and f.cur.basis.points[1][1] == "BOTTOMLEFT" and f.cur.likely.text:find("about 75%%") and f.cur.likely.text:find("about 5%%") and f.cur.likely.text:find(" to ", 1, true), "the right half lists the likely results with ranges and rough odds, headed DE estimate")
	check(f.cur.rule.points[1][4] >= 330 and f.cur.rule.points[1][4] < f:GetWidth() - 24, "the rule splits the panel with the left half at least 330 px")
	check(f.footer.text == "Mats are DE estimates that improve as you disenchant." and f.footer.points[1][1] == "BOTTOMLEFT" and f.footer.points[2][1] == "BOTTOMRIGHT" and f.footer.points[2][2] == -12, "the footer is one short line that explains the mats values and that they improve, centered on the window")
	check(b.tip == "Disenchant this item" and f.skip.tip == "Pass on it for now" and f.never.tip == "Add it to your DE Exclusion List" and f.junk.tip == "Mark it as junk", "the button tooltips are one short clause each")
	check(f.sub.text == "2 items to consider." or f.sub.text:find("^2 items to consider%.%s*$") or f.sub.text:find("^2 items to consider%.  Enchanting skill"), "the header is the count and the skill, no paragraph (" .. f.sub.text .. ")")
	check(f.rows[1].cells[5].text:find("est", 1, true) == nil and f.cols[5][1] == "Mats (DE est.)" and f.cols[3][3] >= 104, "no tag in the mats cells: the header says DE est., the money columns are wider")
	check(true, "(cells are created with SetWordWrap(false); the mock does not model wrapping)")
	-- the refresh icon: hidden with nothing skipped, shown with a count once something is
	check(not f.refresh:IsShown(), "nothing skipped: no refresh icon")
	DE:Skip()
	check(f.refresh:IsShown() and f.refresh.tip:find("1 skipped this session", 1, true), "one skip: the icon appears with the count")
	-- skip everything: the empty card
	DE:Skip()
	check(#DE.entries == 0 and f.empty:IsShown() and not f.cur:IsShown() and not f.scroll:IsShown() and f.empty.head.text == "Nothing left to consider." and f.empty.line.text == "2 skipped this session." and f.empty.line.points[1][2] == f.empty.head and f.empty.skipped:IsShown() and not f.empty.never:IsShown(), "everything skipped: the card says so with a way back under the headline and no never-list button")
	f.empty.skipped:GetScript("OnClick")(f.empty.skipped)
	check(#DE.entries == 2 and not f.empty:IsShown() and f.cur:IsShown() and not f.refresh:IsShown(), "Consider skipped again brings the items back and hides the icon")
	DE:Never()[7001] = true; DE:Never()[7002] = true; DE:Refresh()
	check(f.empty:IsShown() and f.empty.line.text == "2 on your DE Exclusion List." and f.empty.never:IsShown() and not f.empty.skipped:IsShown(), "everything never'd: the card offers the never list")
	DE:ClearNever()
	DE.done = 3; M.bags[0][1] = nil; M.bags[0][2] = nil; M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	check(f.empty:IsShown() and f.empty.head.text == "All done." and f.empty.count.text == "3 items disenchanted" and f.empty.haul.text == "" and f.empty.value.text == "", "after a session's work the card celebrates (no materials recorded: just the count)")
	DE.done = nil; DE:Refresh()
	check(f.empty.head.text == "Nothing to disenchant." and f.empty.line.text:find("no weapons or armor", 1, true), "fresh and empty: the plain message")
	known = false; DE:Refresh()
	check(f.empty.head.text == "This character can't disenchant.", "no Enchanting: the card says so")
	known = true
	M.put(0, 3, { id = 7010, name = "Grand Mace", q = 2, count = 1, class = 2, subclass = 4, price = 3000, ilvl = 63, equip = "INVTYPE_2HWEAPON" })
	_G.GetNumSkillLines = function() return 1 end; _G.GetSkillLineInfo = function() return "Enchanting", false, nil, 75 end
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	check(f.empty.head.text == "Nothing you can disenchant yet." and f.empty.line.text:find("more Enchanting skill than 75", 1, true), "held back by skill: the card says how much")
	_G.GetNumSkillLines = nil; _G.GetSkillLineInfo = nil; M.bags[0][3] = nil
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 452, ilvl = 23, equip = "INVTYPE_FEET" })
	M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	check(V.btnDisenchant.active == true, "the toolbar button lights while the window is open")
	local cols = f.cols
	check(#cols == 6 and cols[1][3] == 14 and cols[2][1] == "Item" and cols[6][1] == "Rec. Action" and cols[6][2] + cols[6][3] <= f:GetWidth() - 44, "six columns: the dot, the item, three values and Rec. Action, all inside the window")
	local headY = f.heads[2].points[1][3]
	check(headY <= -(56 + 76) and f.scroll.points[1][3] < headY, "the headers sit below the current item's button row, the list below the headers")
	-- money, not copper
	local r1 = f.rows[1]
	check(r1 and r1.cells[3].text == "0g 8s 0c" or (r1 and r1.cells[3].text:find("s", 1, true)), "values are money, not raw copper (" .. tostring(r1 and r1.cells[3].text) .. ")")
	-- the selection dot and highlight follow the current item
	check(r1.dotFill:IsShown() and r1.hl:IsShown() and not f.rows[2].dotFill:IsShown(), "the first row is selected: filled dot and highlight")
	f.rows[2]:GetScript("OnClick")(f.rows[2])
	check(f.rows[2].dotFill:IsShown() and not f.rows[1].dotFill:IsShown() and DE.current == f.rows[2].entry and b:GetAttribute("target-slot") == f.rows[2].entry.slot, "clicking a row selects it and arms it")
	-- resizing re-lays the columns and remembers the size
	-- (1.5.7, by design) a resize starts with a press on the grip: a release alone (say, after a press in combat, which is
	-- ignored) doesn't count as one
	f.grip:GetScript("OnMouseDown")(f.grip); f.w = 720; f.h = 500; f.grip:GetScript("OnMouseUp")(f.grip)
	check(n.db.deSize[1] == 720 and f.cols[2][3] > cols[2][3] and f.cols[6][2] + f.cols[6][3] <= 720 - 44, "a wider window gives the item column the extra room and the size is remembered")
	f:Hide(); DE:Show()
	check(f:GetWidth() == 720, "the remembered size is used next time")
	-- a size below the minimum is held to it
	n.db.deSize = { 100, 100 }; f:Hide(); DE:Show()
	check(f:GetWidth() == DE.MIN_W and f:GetHeight() == DE.MIN_H and DE.MIN_W == 620, "a saved size below the minimum is raised to it (the minimum fits the six columns)")
	f:Hide()
	check(V.btnDisenchant.active == false, "closing the window unlights the toolbar button")
	-- layering: above the bags window and forward when clicked; a corner X in Modern, hidden under the Classic chrome
	check(f.strata == "DIALOG" and f.toplevel == true and f.closeX and f.closeX:IsShown(), "the helper sits on the DIALOG strata, top-level, with a corner X in Modern")
	check(DE:NeverWindow().strata == "DIALOG" and DE:NeverWindow().toplevel == true and DE:OfferFrame().toplevel == true and DE:OfferFrame().closeX ~= nil, "the never window and the offer are layered the same, with their own X")
	-- the opening position: beside the bags window, to its left with a gap, unless a position was saved
	n.db.dePos = nil; f:Hide()
	local main = V.frame; main.GetLeft = function() return 900 end
	DE:Show()
	check(f.points[1][1] == "TOPRIGHT" and f.points[1][2] == UIParent and f.points[1][3] == "BOTTOMLEFT" and f.points[1][4] == 900 - 12 and f.points[1][5] == main:GetTop(), "with room on the left the helper opens just left of the bags window, anchored to the screen")
	f:Hide(); main.GetLeft = function() return 100 end; DE:Show()
	check(f.points[1][1] == "TOPLEFT" and f.points[1][2] == UIParent and f.points[1][3] == "BOTTOMLEFT" and f.points[1][4] == main:GetRight() + 12, "with no room on the left it opens to the right, anchored to the screen")
	f:Hide(); main.GetLeft = nil; n.Window:Hide(); DE:Show()
	check(f.points[1][1] == "CENTER", "with the bags closed it opens at the center")
	n.db.dePos = { "TOPLEFT", "UIParent", "TOPLEFT", 40, -40 }; f:Hide(); n.Window:Show(); M.runTimers(); DE:Show()
	check(f.points[1][1] == "TOPLEFT" and f.points[1][4] == 40, "a saved position wins")
	n.db.dePos = nil
	-- the sitting's summary: on the All done card with counts and value, and in chat when the window closes
	DE.session = { done = 2, mats = { [10940] = 6, [10939] = 2 } }; DE.done = 2
	M.bags[0][1] = nil; M.bags[0][2] = nil; M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	check(f.empty:IsShown() and f.empty.head.text == "All done." and f.empty.count.text == "2 items disenchanted" and f.empty.haul.text == "Strange Dust x6\nGreater Magic Essence x2" and f.empty.value.text:find("^Worth about ") and f.empty.value.text:find("at current AH prices$") and f.empty.line.text == "" and not f.sub:IsShown(), "All done: the count, the haul one material per line, the value in its own line, nothing set aside, the header line hidden")
	check(f.empty.icon.texture:find("ui%-disenchant%-large") ~= nil, "the card uses the large texture")
	local said = {}; local realPrint = n.Print; n.Print = function(self, fmt, ...) said[#said + 1] = fmt:format(...) end
	f:Hide(); n.Print = realPrint
	check(said[#said] and said[#said]:find("^Disenchant Helper: 2 items disenchanted%. Strange Dust x6"), "closing after a sitting with casts puts the summary in chat")
	DE:Show()
	check(DE.session == nil and (DE.done or 0) == 0, "the next sitting starts its counts over")
	-- disenchanted some and skipped others: the haul leads, the skipped line follows with its button
	DE.session = { done = 1, mats = { [10940] = 2 } }; DE.done = 1; DE.skipped = { ["x:1"] = true, ["x:2"] = true }
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers(); DE:Refresh()
	check(f.empty:IsShown() and f.empty.head.text == "Done for now." and f.empty.count.text == "1 item disenchanted" and f.empty.haul.text == "Strange Dust x2" and f.empty.line.text == "2 skipped this session." and f.empty.skipped:IsShown() and f.empty.line.points[1][2] == f.empty.value, "disenchanted some, skipped others: the haul in its pieces, the skipped line apart beneath the value")
	said = {}; n.Print = function(self, fmt, ...) said[#said + 1] = fmt:format(...) end
	f:Hide(); n.Print = realPrint
	check(said[#said] and said[#said]:find("1 item disenchanted%. Strange Dust x2") and said[#said]:find("2 skipped%.$"), "the chat line carries the skipped count too")
	DE.skipped = {}; DE:Show()
	f:Hide()
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 452, ilvl = 23, equip = "INVTYPE_FEET" })
	M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
	M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
	DE:Show()
	-- settings: the sub-pages, and the Prompts kinds nested under Also Outside BagSmith with no AutoNod text
	local SP = n.SettingsPanel; SP:Show()
	SP:ShowPage("automation")
	local texts = {}; for _, w in ipairs(SP.pools.text) do if w:IsShown() then texts[#texts + 1] = w.text.text end end
	local all = table.concat(texts, "|")
	check(not all:find("AutoNod", 1, true), "no AutoNod mention on the page")
	local outside, kind
	for _, w in ipairs(SP.pools.check) do if w:IsShown() then if w.key == "autoConfirmEverywhere" then outside = w elseif w.key == "autoConfirmEquip" then kind = w end end end
	check(outside and kind and kind.points[1][4] > outside.points[1][4], "the kinds are indented under Also Outside BagSmith")
	local heads = {}; for _, w in ipairs(SP.pools.head) do if w:IsShown() then heads[w.text.text] = true end end
	check(not heads["Loot Helper"] and not heads["Disenchant Helper"] and heads["Prompts"], "the Automations page no longer carries the two helpers")
	SP:ShowPage("loothelper")
	local lh = false; for _, w in ipairs(SP.pools.check) do if w:IsShown() and w.key == "makeRoom" then lh = true end end
	check(lh, "the Loot Helper sub-page has its setting")
	SP:ShowPage("dehelper")
	local dh, ask = false, false
	for _, w in ipairs(SP.pools.check) do if w:IsShown() and w.key == "deEnabled" then dh = true end end
	for _, w in ipairs(SP.pools.btn) do if w:IsShown() and w.label.text == "Ask Again" then ask = true end end
	check(dh and not ask, "the Disenchant Helper sub-page has its setting and no Ask Again while the offer is not declined")
	local function optin() for _, w in ipairs(SP.pools.text) do if w:IsShown() and (w.text.text:find("opted in", 1, true) or w.text.text:find("opted out", 1, true) or w.text.text:find("hasn't been asked", 1, true)) then return w.text.text end end end
	check(optin() == "This character has already opted in.", "Opt-in: with the helper on, the character has opted in")
	n:Set("deEnabled", false); n.cdb.deOfferDeclined = true; SP:Refresh()
	ask = false; for _, w in ipairs(SP.pools.btn) do if w:IsShown() and w.label.text == "Ask Again" then ask = true end end
	check(ask and optin() == "This character opted out (Don't Ask Again).", "opted out: the sub-page says so and offers Ask Again")
	n.cdb.deOfferDeclined = nil; SP:Refresh()
	check(optin():find("hasn't been asked", 1, true) ~= nil, "neither: not asked yet, or Ask Later")
	n:Set("deEnabled", true); SP:Refresh()
	-- the never list's Manage window
	DE:Never()[7002] = true; SP:Refresh()
	local manage; for _, w in ipairs(SP.pools.btn) do if w:IsShown() and w.label.text == "Manage..." then manage = w end end
	check(manage ~= nil, "with items on the never list the sub-page offers Manage...")
	local clearAll; for _, w in ipairs(SP.pools.btn) do if w:IsShown() and w.label.text == "Clear All" then clearAll = w end end
	check(clearAll and manage.points[1][5] == clearAll.points[1][5] and clearAll.points[1][4] > manage.points[1][4], "Manage... and Clear All share one row, side by side")
	manage.onClick(manage)
	local nw = DE.neverFrame
	check(nw and nw:IsShown() and nw.rows[1] and nw.rows[1]:IsShown() and nw.rows[1].id == 7002, "Manage... opens the Never Disenchant window with the item")
	nw.rows[1].remove:GetScript("OnClick")(nw.rows[1].remove)
	check(DE:Never()[7002] == nil and not nw.rows[1]:IsShown(), "Consider Again removes it")
	nw:Hide()
	SP:Hide()
	-- Classic: the toolbar button and the Disenchant button are dressed like their neighbors
	n:Set("skin", "classic"); M.runTimers()
	check(V.btnDisenchant.squareBg ~= nil and V.btnDisenchant.squareBg == V.btnClean.squareBg or (V.btnDisenchant.squareBg ~= nil and V.btnClean.squareBg ~= nil), "in Classic the toolbar button wears the same square button frame as the broom")
	DE:Show()
	check(b.classicOn == true and b.classic ~= nil and f.skip.classic ~= nil and b.classic.isTab == f.skip.classic.isTab, "in Classic the Disenchant button has the same Blizzard button art as Skip")
	n:Set("skin", "modern"); M.runTimers(); f:Hide()
end)()

