;(function()
	-- 1.5.0: icon corners. BagSmith's marks and other addons' widgets share each icon corner through a priority list
	-- (Style > Items > Icon Corners); other addons register through BagSmith.API 1.1.
	local function boot(prefs)
		package.loaded.mock = nil
		local M = require("mock")
		M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
		M.put(0, 1, { id = 3300, name = "Rabbit's Foot", q = 0, count = 1, class = 15, subclass = 0, price = 5 })                       -- junk (grey)
		M.put(0, 2, { id = 9001, name = "Azure Ring", q = 2, count = 1, class = 4, subclass = 0, ilvl = 24, price = 50, equip = "INVTYPE_FINGER" })
		M.put(0, 3, { id = 2589, name = "Linen Cloth", q = 1, count = 12, class = 7, subclass = 5, price = 1 })
		M.put(0, 4, { id = 6948, name = "Hearthstone", q = 1, count = 1, class = 15, subclass = 0, price = 0 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local profile = { skin = "modern", iconItemLevel = true }
		for k, v in pairs(prefs or {}) do profile[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = profile } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); M.runTimers(); M.runTimers()
		local V = n.Window.main
		V:SetPref("grp", "none"); V:SetPref("view", "icons"); V:SetPref("mergeStacks", false); n:RefreshViews(true); M.runTimers()
		return n, M, V
	end
	local function btn(V, id) for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id and b.mode == "cell" then return b end end end
	local function at(region) local p = region and region.points and region.points[1]; return p and (p[1] .. "," .. tostring(p[4]) .. "," .. tostring(p[5])) end
	local function said(M, pat) for _, l in ipairs(M.log) do if l:find(pat, 1, true) then return true end end end

	-- ---- defaults reproduce today's Icons look
	local n, M, V = boot()
	local C = n.Corners
	local junk, ring, linen = btn(V, 3300), btn(V, 9001), btn(V, 2589)
	check(junk.junkCoin:IsShown() and at(junk.junkCoin) == "TOPLEFT,0,0", "default: the junk coin top-left, flush in its corner (1.5.0-beta6) (" .. tostring(at(junk.junkCoin)) .. ")")
	-- (1.5.0-beta6) flush in its corner, like the stack count
	check(ring.ilvlText and ring.ilvlText:IsShown() and at(ring.ilvlText) == "TOPRIGHT,0,0", "default: the item level top-right, flush in its corner (" .. tostring(at(ring.ilvlText)) .. ")")
	local flush = true
	for _, corner in ipairs({ "top_left", "bottom_left", "bottom_right", "top_right" }) do
		C:Place("item_level", corner)
		if corner == "bottom_right" then C:Move("item_level", -1) end   -- (it can't pass the stack count; with a single ring the count isn't shown anyway)
		n:RefreshViews(true); M.runTimers()
		local r = btn(V, 9001)
		local p = r.ilvlText and r.ilvlText.points and r.ilvlText.points[1]
		if not (p and p[1] == ({ top_left = "TOPLEFT", top_right = "TOPRIGHT", bottom_left = "BOTTOMLEFT", bottom_right = "BOTTOMRIGHT" })[corner] and p[4] == 0 and p[5] == 0) then flush = false end
	end
	check(flush, "the item level sits flush in whichever corner it's in")
	C:Reset(); n:RefreshViews(true); M.runTimers()
	ring = btn(V, 9001)
	check(linen.Count:IsShown() and at(linen.Count) == "BOTTOMRIGHT,0,0", "default: the stack count bottom-right, where it was (" .. tostring(at(linen.Count)) .. ")")
	check(not C:CornerOf("quantity") or C:CornerOf("quantity") == "bottom_right", "quantity is a bottom-right widget")

	-- ---- Pawn arrow and gear-set shield: one per corner, the player's order decides
	n.Pawn.IsUpgrade = function(_, rec) return rec and rec.itemID == 9001, false end
	n:RefreshViews(true); M.runTimers()
	ring = btn(V, 9001)
	ring.linkOn = true; C:Apply(ring)   -- (as if the ring were in two gear sets)
	check(ring.pawnArrow and ring.pawnArrow:IsShown() and at(ring.pawnArrow) == "BOTTOMLEFT,0,0" and not (ring.linkMark and ring.linkMark:IsShown()), "both apply: the Pawn arrow shows (first by default), the shield waits")
	C:Move("equipment_set", -1)
	local _ = ring.linkMark or n.Buttons:LinkMark(ring, ring.rec)
	ring.linkOn = true; C:Apply(ring)
	check(ring.linkMark == nil or (ring.linkMark:IsShown() and not ring.pawnArrow:IsShown()), "the player puts the shield first: the shield shows, the arrow waits")
	check(n.db.iconCornersTouched.bottom_left == true, "and that corner counts as arranged")
	C:Move("equipment_set", 1)

	-- ---- the API: registration rules, both call styles
	local API = BagSmith.API
	check(select(2, API:GetVersion()) == 1, "the API is 1.1")
	local inits, updates = 0, 0
	local answer = true
	local function onInit(b) inits = inits + 1; local t = b:CreateTexture(nil, "OVERLAY"); t.padding = 1; return t end
	local function onUpdate(w, d) updates = updates + 1; w.lastDetails = d; return answer end
	check(API.RegisterCornerWidget("Tree Mark", "itemtree_mark", onUpdate, onInit, { corner = "top_right", priority = 1 }) == true, "dot style registers")
	check(API:RegisterCornerWidget("Other", "other_mark", function() return true end, function(b) return b:CreateTexture() end) == true, "colon style registers")
	check(API.RegisterCornerWidget("Dup", "itemtree_mark", onUpdate, onInit) == false, "a duplicate id is refused (false, no error)")
	check(API.RegisterCornerWidget("Bad", "has space", onUpdate, onInit) == false and API.RegisterCornerWidget(nil, "x", onUpdate, onInit) == false and API.RegisterCornerWidget("NoInit", "noinit", onUpdate) == false, "bad arguments are refused")
	check(API.RegisterCornerWidget("Mine", "junk", onUpdate, onInit) == false, "a built-in id is taken")
	-- auto-insert: priority 1 in an untouched corner goes first
	check(n.db.iconCorners.top_right[1] == "itemtree_mark" and n.db.iconCorners.top_right[2] == "item_level", "a new widget goes where it asks in a corner the player hasn't arranged")
	check(API.IsCornerWidgetActive("itemtree_mark") and API:GetCurrentCornerForWidget("itemtree_mark") == "top_right" and not API.IsCornerWidgetActive("other_mark"), "active and corner answers; one with no default position isn't placed")
	-- a corner the player arranged: arrivals go to the end
	API.RegisterCornerWidget("Late", "late_mark", function() return true end, function(b) return b:CreateTexture() end, { corner = "bottom_left", priority = 1 })
	check(n.db.iconCorners.bottom_left[#n.db.iconCorners.bottom_left] == "late_mark", "in a corner the player arranged, a new widget goes at the end")
	M.runTimers()

	-- ---- drawing a third-party widget: once per button, placed in its corner, scaled with the icon
	ring = btn(V, 9001)
	local w = ring.cornerWidgets and ring.cornerWidgets.itemtree_mark
	check(w and w:IsShown() and at(w) and at(w):find("^TOPRIGHT,") and not ring.ilvlText:IsShown(), "the widget shows top-right (first there) and the item level waits")
	local d = w and w.lastDetails
	check(d and d.itemID == 9001 and d.itemLink and d.quality == 2 and d.itemLevel == 24 and d.bagID == 0 and d.slotID == 2 and d.isJunk == false, "its details: item ID, link, quality, item level, bag and slot, junk")
	local before = inits
	n:RefreshViews(true); M.runTimers()
	check(inits == before, "init runs once per button, not on every refresh")
	-- false: the next one in the corner shows
	answer = false; n:RefreshViews(true); M.runTimers()
	ring = btn(V, 9001)
	check(not ring.cornerWidgets.itemtree_mark:IsShown() and ring.ilvlText:IsShown(), "answering false hands the corner to the next (the item level)")
	-- nil: asked again later
	answer = nil; n:RefreshViews(true); M.runTimers()
	ring = btn(V, 9001)
	check(next(C.retries) ~= nil and not ring.cornerWidgets.itemtree_mark:IsShown(), "answering nil (not ready) queues the item to be asked again")
	answer = true; C:RunRetries()
	check(ring.cornerWidgets.itemtree_mark:IsShown() and next(C.retries) == nil, "and when it's ready, it shows")
	-- the frame budget: a slow widget waits for the next frame, a fast one doesn't
	C.BUDGET_MS = -1
	n:RefreshViews(true); M.runTimers()
	ring = btn(V, 9001)
	check(not ring.cornerWidgets.itemtree_mark:IsShown() and next(C.retries) ~= nil, "over the frame's budget, a widget not marked fast waits")
	C.BUDGET_MS = 4; C:RunRetries()
	check(ring.cornerWidgets.itemtree_mark:IsShown(), "and shows on a later frame")

	-- ---- quantity: a stack shows its count; a single item lets the next bottom-right widget show
	API.RegisterCornerWidget("Corner BR", "br_mark", function() return true end, function(b) return b:CreateTexture() end, { corner = "bottom_right", priority = 5 })
	n:RefreshViews(true); M.runTimers()
	linen, ring = btn(V, 2589), btn(V, 9001)
	check(linen.Count:IsShown() and not linen.cornerWidgets.br_mark:IsShown(), "on a stack the count shows")
	check(ring.cornerWidgets.br_mark:IsShown(), "on a single item the next bottom-right widget shows (no overlap with a count)")

	-- ---- errors are contained
	API.RegisterCornerWidget("Broken", "broken_mark", function() error("boom") end, function(b) return b:CreateTexture() end, { corner = "top_left", priority = 1 })
	for _ = 1, 3 do n:RefreshViews(true); M.runTimers() end
	check(C.widgets.broken_mark.broken and said(M, "kept failing, so it's off until you reload"), "a widget that keeps failing is switched off with one chat line")
	junk = btn(V, 3300)
	check(junk.junkCoin:IsShown(), "and the corner falls back to the junk coin")

	-- ---- List rows are unchanged
	V:SetPref("view", "list"); n:RefreshViews(true); M.runTimers()
	local row; for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 9001 and b.mode == "row" then row = b end end
	-- (1.5.0-beta4) other addons' marks show on List rows only if their addon opts in (listRows); this one didn't
	check(row and not (row.cornerWidgetsRow and row.cornerWidgetsRow.itemtree_mark) and not (row.cornerWidgets and row.cornerWidgets.itemtree_mark and row.cornerWidgets.itemtree_mark:IsShown()), "a mark whose addon didn't opt in to List rows doesn't show on rows (beta4)")
	V:SetPref("view", "icons"); n:RefreshViews(true); M.runTimers()

	-- ---- settings: remove stays removed; Move; Not Shown; reset; validators
	C:Remove("itemtree_mark")
	C:InsertAll()
	check(not C:CornerOf("itemtree_mark"), "a widget the player removed stays removed")
	C:Place("itemtree_mark", "top_right")
	C:NextCorner("itemtree_mark")
	check(C:CornerOf("itemtree_mark") == "bottom_right", "Move sends it to the next corner clockwise")
	C:Reset()
	check(n.db.iconCorners.top_left[1] == "broken_mark" and n.db.iconCorners.top_right[1] == "itemtree_mark" and n.db.iconCorners.bottom_left[1] == "late_mark" and n.db.iconCorners.bottom_left[2] == "pawn", "Reset puts BagSmith's marks back and other addons' widgets where they asked")
	check(n:Set("iconCorners", { top_left = { "junk", "junk", "bad id", 7 }, top_right = "x" }) and #n.db.iconCorners.top_left == 1 and #n.db.iconCorners.top_right == 0 and n.db.iconCorners.bottom_left, "bad saved corners are repaired (duplicates, bad ids, missing corners)")
	n:Set("iconCorners", { top_left = { "junk" }, top_right = { "item_level", "ghost_mark" }, bottom_left = { "pawn", "equipment_set" }, bottom_right = { "quantity" } })

	-- ---- the settings page (1.5.0-beta10): Icon Corners as dropdowns on Item Icons
	n:Set("iconItemLevel", false)
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("icons")
	local w = P.pools.cornerCards[1]
	check(w and w:IsShown() and w.groups and w.unused, "Icon Corners is on the Item Icons page, a group per corner")
	local function rows(k) local t = {}; for _, r in ipairs(P.pools.cornerCards[1].groups[k].rows) do if r:IsShown() then t[#t + 1] = r end end return t end
	local tr = rows("top_right")
	local ghost, ilvl
	for _, r in ipairs(tr) do if r.id == "ghost_mark" then ghost = r end; if r.id == "item_level" then ilvl = r end end
	check(tr[1] and tr[1].id == "item_level" and not tr[1].thenLabel:IsShown() and tr[2] and tr[2].thenLabel:IsShown(), "the first dropdown is the mark that shows; the next ones say then")
	check(ghost and ghost.drop.label.text == "ghost_mark (not loaded)" and ghost.drop.tip:find("isn't loaded", 1, true), "a mark whose addon isn't loaded keeps its place, marked not loaded")
	check(ilvl and ilvl.drop.tip:find("turn on Item Level (ilvl)", 1, true), "Item Level with its setting off says how to turn it on")
	-- choosing a mark used in another corner moves it here, replacing what was there
	local menu
	local realMenu = n.ShowMenu
	n.ShowMenu = function(items) menu = items end
	local tl = rows("top_left")[1]
	tl.drop:GetScript("OnClick")(tl.drop)
	local shield
	for _, it in ipairs(menu or {}) do if it.text == "Gear Set Shield (in Bottom Left)" then shield = it end end
	check(menu and menu[1].text == "None" and shield and menu[#menu].text == "Cancel", "a dropdown lists None, every mark (saying where it is now), and Cancel")
	shield.onClick()
	check(n.db.iconCorners.top_left[1] == "equipment_set" and not n.Corners:CornerOf("junk") and n.Corners:CornerOf("equipment_set") == "top_left", "choosing it moves it here, and the mark it replaced is no longer shown")
	-- None empties a corner
	tl = rows("top_left")[1]
	tl.drop:GetScript("OnClick")(tl.drop); menu[1].onClick()
	check(#n.db.iconCorners.top_left == 0 and rows("top_left")[1].drop.label.text == "None", "None empties the corner")
	-- + adds a backup, x removes it
	local bl = rows("bottom_left")
	bl[#bl].add:GetScript("OnClick")(bl[#bl].add)
	local junkItem
	for _, it in ipairs(menu) do if it.text == "Junk Coin" then junkItem = it end end
	junkItem.onClick()
	local list = n.db.iconCorners.bottom_left
	check(list[#list] == "junk", "+ adds a backup at the end of the corner")
	bl = rows("bottom_left")
	bl[#bl].remove:GetScript("OnClick")(bl[#bl].remove)
	check(not n.Corners:CornerOf("junk"), "x removes it (it's then not shown)")
	check(P.pools.cornerCards[1].unused.text:find("Junk Coin", 1, true), "marks in no corner are listed as not shown")
	n.ShowMenu = realMenu
	n.Corners:Reset(); P:Refresh()
	P:Hide()
end)()

;(function()
	-- combat: a widget's first creation waits for combat to end
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 4; for b = 1, 5 do M.sizes[b] = 0 end
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 3, class = 7, subclass = 5, price = 1 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V = n.Window.main
	V:SetPref("view", "icons"); n:RefreshViews(true); M.runTimers()
	local made = 0
	-- registered before BagSmith's settings were ready? (here after): still placed once
	_G.InCombatLockdown = function() return true end
	BagSmith.API.RegisterCornerWidget("Combat Mark", "combat_mark", function() return true end, function(b) made = made + 1; return b:CreateTexture() end, { corner = "top_right", priority = 1 })
	n.Corners:Apply((function() for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 2589 then return b end end end)(), true)
	check(made == 0 and n.Corners.pendingInit, "in combat a widget isn't created on our buttons; it waits")
	_G.InCombatLockdown = function() return false end
	M.fire("PLAYER_REGEN_ENABLED"); M.runTimers(); M.runTimers()
	check(made > 0, "when combat ends, it's created and drawn")
end)()
