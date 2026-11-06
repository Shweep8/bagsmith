;(function()
	-- 1.5.0-beta3 (Shweep's feedback on beta2): a way out of the corner menus; a live preview on a real, display-only
	-- item button (Icons / List); List rows follow the corners (marks with their own column step aside); the
	-- settings explain List view and other addons' marks; a /bs debug line when switching characters.
	local function boot(prefs, cache)
		package.loaded.mock = nil
		local M = require("mock")
		M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
		M.put(0, 1, { id = 3300, name = "Rabbit's Foot", q = 0, count = 1, class = 15, subclass = 0, price = 5 })
		M.put(0, 2, { id = 2589, name = "Linen Cloth", q = 1, count = 12, class = 7, subclass = 5, price = 1 })
		M.put(0, 3, { id = 9001, name = "Azure Ring", q = 2, count = 1, class = 4, subclass = 0, ilvl = 24, price = 50, equip = "INVTYPE_FINGER" })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local profile = { skin = "modern" }
		for k, v in pairs(prefs or {}) do profile[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = cache or {}, profiles = { Default = profile } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M
	end
	local function said(M, pat) for _, l in ipairs(M.log) do if l:find(pat, 1, true) then return true end end end

	-- ---- 1. the menu: a click elsewhere, Escape, or Cancel closes it, changing nothing
	local n, M = boot()
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("icons")
	-- (1.5.0-beta10: a corner's dropdown opens the menu)
	local function cards() return P.pools.cornerCards[1].groups end
	local junkRow = P.pools.cornerCards[1].groups.top_left.rows[1]
	junkRow.name = junkRow.drop
	junkRow.name:GetScript("OnClick")(junkRow.name)
	local m = n.menuFrame
	check(m and m:IsShown() and m.catcher:IsShown() and m.catcher.strata == "FULLSCREEN", "the menu's click-catcher sits above dialogs like Settings (" .. tostring(m and m.catcher.strata) .. ")")
	m.catcher:GetScript("OnClick")(m.catcher)
	check(not m:IsShown() and n.Corners:CornerOf("junk") == "top_left", "a click anywhere else closes it; nothing moved")
	junkRow.name:GetScript("OnClick")(junkRow.name)
	m:GetScript("OnKeyDown")(m, "ESCAPE")
	check(not m:IsShown() and P.frame:IsShown(), "Escape closes the menu and leaves Settings open")
	junkRow.name:GetScript("OnClick")(junkRow.name)
	local cancel = m.items[#m.items]
	check(cancel.text == "Cancel" and m.items[#m.items - 1].gap, "the menu ends with Cancel, set apart")
	cancel.onClick(); m:Hide()
	check(n.Corners:CornerOf("junk") == "top_left", "Cancel changes nothing")

	-- ---- 2. the live preview
	local w = P.pools.cornerCards[1]
	local b = w.preview
	check(b and b:IsShown() and b.bsPreview and b.rec and b.rec.name == "Sample Item", "the preview is a real BagSmith item button with a sample item")
	check(b.bsDisplayOnly == true, "it's display-only: no clicks, drags or item actions")
	check(b.previewShown.top_left == "junk" and b.junkCoin:IsShown(), "top left shows the junk coin")
	check(b.previewShown.top_right == nil and not (b.ilvlText and b.ilvlText:IsShown()), "item level is off, so the top right shows nothing")
	check(b.previewShown.bottom_left == "equipment_set" and b.linkMark:IsShown(), "without Pawn installed, the bottom left shows the next mark, the gear-set shield")
	check(b.previewShown.bottom_right == "quantity" and b.Count:IsShown() and b.Count.text == "20", "bottom right shows the stack count")
	n:Set("iconItemLevel", true); P:Refresh(); b = P.pools.cornerCards[1].preview
	check(b.previewShown.top_right == "item_level" and b.ilvlText:IsShown(), "turn on Item Level and it shows top right")
	-- (1.5.0-beta4: the stack count is protected and can't be hidden)
	n.Corners:Remove("quantity"); P:Refresh(); b = P.pools.cornerCards[1].preview
	check(b.previewShown.bottom_right == "quantity" and b.Count:IsShown(), "the stack count can't be hidden: it stays on the preview")
	n:Set("iconItemLevel", false)
	n.Corners:Place("junk", "top_right"); P:Refresh(); b = P.pools.cornerCards[1].preview
	check(b.previewShown.top_right == "junk" and b.previewShown.top_left == nil, "move the junk coin and it moves on the preview")
	n.Corners:Reset(); P:Refresh(); b = P.pools.cornerCards[1].preview
	check(b.previewShown.top_left == "junk" and b.previewShown.bottom_right == "quantity", "Reset puts the preview back")
	-- another addon's mark: a neutral tag; its code isn't run on the pretend item
	local initOnPreview = 0
	BagSmith.API.RegisterCornerWidget("Tree Mark", "tree_mark", function() return true end, function(btn) if btn.bsPreview then initOnPreview = initOnPreview + 1 end; return btn:CreateTexture() end, { corner = "top_left", priority = 1 })
	P:Refresh(); b = P.pools.cornerCards[1].preview
	check(b.previewShown.top_left == "tree_mark" and b.previewTags.top_left and b.previewTags.top_left:IsShown() and not b.junkCoin:IsShown(), "another addon's mark shows as a small tag in its corner")
	check(initOnPreview == 0, "and its own code never runs on the preview")
	-- the frame and the rarity border follow your settings; the size follows Icon Size
	n:Set("border", "off"); P:Refresh(); b = P.pools.cornerCards[1].preview
	local offNeutral = b.qNeutral == true
	n:Set("border", "all"); P:Refresh(); b = P.pools.cornerCards[1].preview
	check(offNeutral and b.qNeutral == false and b.qRing:IsShown(), "the rarity border follows Rarity Borders (a plain frame when off, green when on)")
	-- (1.5.0-beta10) the Icons view preview is your icon at your Icon Size, magnified as a whole to about 56 px, so
	-- text marks keep their real proportions
	n:Set("iconSize", 24); P:Refresh(); b = P.pools.cornerCards[1].preview
	local w24, s24 = b:GetWidth(), b.scale
	n:Set("iconSize", 48); P:Refresh(); b = P.pools.cornerCards[1].preview
	check(w24 == 24 and b:GetWidth() == 48 and math.abs(s24 * 24 - 56) < 0.01 and math.abs(b.scale * 48 - 56) < 0.01, "the Icons view preview is your icon at your Icon Size, magnified to the same size on screen")
	-- List: a row-sized icon; Item Level steps aside; Stack Count unless the Qty column is hidden
	-- (1.5.0-beta7) the List preview shows beside the Icons one, always: a row with its Qty column, icon and name
	local w7 = P.pools.cornerCards[1]
	b = w7.previewList
	check(b:GetWidth() == 24 and b.previewShown.top_right == nil and b.previewShown.bottom_right == nil and w7.listQty.text == "20", "List preview: a row icon; item level steps aside, and the count shows in the Qty column")
	local cols = {}; for _, c in ipairs(n.db.cols) do if c ~= "c" then cols[#cols + 1] = c end end
	n:Set("cols", cols); P:Refresh(); w7 = P.pools.cornerCards[1]; b = w7.previewList
	check(b.previewShown.bottom_right == "quantity" and w7.listQty.text == "", "hide the Qty column and the count moves onto the row icon")

	-- ---- 3. the settings explain List view and other addons' marks
	local text = {}
	for _, t in ipairs(P.pools.text) do if t:IsShown() and t.text and t.text.text then text[#text + 1] = t.text.text end end
	local all = table.concat(text, " || ")
	check(all:find("In List view, Item Level and Stack Count show in their columns instead", 1, true), "the intro explains List view")
	-- (1.5.0-beta6) the line under the cards stays, with words for when other addons' marks are there, and carries
	-- the info icon; the heading is plain
	local otherLine
	for _, t in ipairs(P.pools.text) do if t:IsShown() and t.othersLine then otherLine = t end end
	check(otherLine and otherLine.text.text == "Marks from other addons are listed in the cards above." and otherLine.info:IsShown() and otherLine.info.title == "Marks from other addons" and otherLine.info.lines[2]:find("doesn't support BagSmith yet", 1, true), "with another addon's marks there, the line says so and its info icon explains other addons' marks")
	local head
	for _, h in ipairs(P.pools.head) do if h:IsShown() and h.text.text == "Icon Corners" then head = h end end
	check(head and not (head.info and head.info:IsShown()), "the Icon Corners heading is plain")
	local ilvlTip
	for _, r in ipairs(cards().top_right.rows) do if r:IsShown() and r.id == "item_level" then ilvlTip = r.drop.tip end end
	check(ilvlTip and ilvlTip:find("In List view the item level shows in its column", 1, true), "hovering Item Level explains its List column")
	local box = P.frame.search
	box:SetText("addon"); box:GetScript("OnTextChanged")(box, true)
	local found = false
	for _, h in ipairs(P.pools.head) do if h:IsShown() and h.text.text == "Icon Corners" then found = true end end
	check(found, "searching \"addon\" finds Icon Corners")
	box:SetText(""); box:GetScript("OnTextChanged")(box, true)
	P:Hide()
end)()

;(function()
	-- the hint line, with no other addon's mark registered
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "classic" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("icons")
	local found
	for _, t in ipairs(P.pools.text) do if t:IsShown() and t.othersLine and t.text.text == "Other addons' marks appear here when they support BagSmith." then found = t end end
	check(found and found.info and found.info:IsShown(), "Classic, no other addon's marks yet: the line says where they'll appear, with its info icon")
	check(P.pools.cornerCards[1].preview:IsShown(), "Classic: the preview shows too")
	P:Hide()
end)()

;(function()
	-- List rows follow the corners
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
	M.put(0, 1, { id = 3300, name = "Rabbit's Foot", q = 0, count = 1, class = 15, subclass = 0, price = 5 })
	M.put(0, 2, { id = 2589, name = "Linen Cloth", q = 1, count = 12, class = 7, subclass = 5, price = 1 })
	M.put(0, 3, { id = 9001, name = "Azure Ring", q = 2, count = 1, class = 4, subclass = 0, ilvl = 24, price = 50, equip = "INVTYPE_FINGER" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", iconItemLevel = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V = n.Window.main
	V:SetPref("grp", "none"); V:SetPref("view", "list"); V:SetPref("mergeStacks", false); n:RefreshViews(true); M.runTimers()
	local function row(id) for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id and b.mode == "row" then return b end end end
	check(row(3300).junkCoin:IsShown(), "(control) the junk coin shows on its row")
	n.Corners:Remove("junk"); n:RefreshViews(true); M.runTimers()
	check(not row(3300).junkCoin:IsShown(), "hide the junk coin in Icon Corners and it's gone from List rows too")
	n.Corners:Reset(); n:RefreshViews(true); M.runTimers()
	check(not (row(9001).ilvlText and row(9001).ilvlText:IsShown()), "item level never shows on a row icon (it has its column)")
	check(row(2589).Count.text == "" or not row(2589).Count:IsShown(), "the count stays in the Qty column while it shows")
	local cols = {}; for _, c in ipairs(n.db.cols) do if c ~= "c" then cols[#cols + 1] = c end end
	n:Set("cols", cols); n:RefreshViews(true); M.runTimers()
	local r = row(2589)
	local p = r.Count.points and r.Count.points[1]
	check(r.Count:IsShown() and r.Count.text ~= "" and p and p[1] == "BOTTOMRIGHT" and p[4] == 2 and p[5] == -1, "with the Qty column hidden, the count shows bottom right on the row icon, where it was")
	-- Pawn and the shield take turns on rows too
	n.Pawn.IsUpgrade = function(_, rec) return rec and rec.itemID == 9001, false end
	n:RefreshViews(true); M.runTimers()
	r = row(9001); r.linkOn = true; n.Corners:Apply(r)
	check(r.pawnArrow and r.pawnArrow:IsShown() and not (r.linkMark and r.linkMark:IsShown()), "rows: one mark per corner, the Pawn arrow first by default")
	-- (1.5.0-beta4) another addon's mark on rows only if it opts in; then it gets an icon-sized slot of its own
	local slots = {}
	BagSmith.API.RegisterCornerWidget("Row Mark", "row_mark", function() return true end, function(btn) if btn.bagsmithRowSlot then slots[btn.itemButton] = btn end; local t = btn:CreateTexture(); t:SetSize(btn:GetWidth() * 0.4, btn:GetWidth() * 0.4); return t end, { corner = "top_right", priority = 1 }, false, { listRows = true })
	BagSmith.API.RegisterCornerWidget("Cell Mark", "cell_mark", function() return true end, function(btn) return btn:CreateTexture() end, { corner = "top_left", priority = 1 })
	n:RefreshViews(true); M.runTimers()
	r = row(2589)
	local wd = r.cornerWidgetsRow and r.cornerWidgetsRow.row_mark
	local slotSeen = slots[r]
	check(wd and wd:IsShown() and slotSeen and slotSeen:GetWidth() == n.Buttons:IconPx(r), "an addon that opts in shows on List rows, sized from an icon-sized slot it's given (" .. tostring(slotSeen and slotSeen:GetWidth()) .. " px)")
	check(slotSeen and slotSeen:GetID() == r:GetID(), "that slot answers the row's slot number")
	check(not (r.cornerWidgetsRow and r.cornerWidgetsRow.cell_mark), "one that doesn't opt in stays off List rows")
end)()

;(function()
	-- switching the bags window to another character: its saved gold and currencies; /bs debug says what was read
	package.loaded.mock = nil
	local M = require("mock")
	_G.GetMoney = function() return 234 end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, profiles = { Default = { skin = "modern", fav = { "c:1792" }, debug = true } }, cache = {
		["Bree Baggs - Forever"] = { name = "Bree Baggs", realm = "Forever", class = "MAGE", level = 1, gold = 999, updated = time() - 30, bags = {}, items = {}, currencies = { ["c:1792"] = { id = 1792, name = "Honor", icon = 1, count = 77, quality = 1 } } },
		["Bree Baggs-Forever"] = { name = "Bree Baggs", realm = "Forever", class = "MAGE", level = 1, gold = 5, updated = time() - 90000, bags = {}, items = {}, currencies = {} },
	} }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V = n.Window.main
	check(V.moneyText.text == "234c", "(control) your own gold")
	V:SetOwner("Bree Baggs - Forever"); M.runTimers(); M.runTimers()
	check(V.moneyText.text == "999c" and V.favChips[1] and V.favChips[1]:IsShown() and V.favChips[1].text.text == "77", "switching characters shows that character's saved gold and pinned currencies")
	n.Drawer:Toggle(); M.runTimers()
	check(n.Drawer.frame and n.Drawer.frame:IsShown(), "the currency drawer opens for them")
	local line
	for _, l in ipairs(M.log) do if l:find("Viewing \"Bree Baggs - Forever\": saved gold 999, saved 30 seconds ago, 1 currencies saved.", 1, true) then line = l end end
	check(line and line:find("Also saved as \"Bree Baggs-Forever\" (gold 5)", 1, true), "/bs debug names the save that was read, and flags another save of the same character")
	V:SetOwner(nil); M.runTimers(); M.runTimers()
	check(V.moneyText.text == "234c", "and back to your own")
end)()
