;(function()
	-- 1.4.2: three fixes from live use of 1.4.1.

	-- ---- 1. Bindings.xml declares the BAGSMITH header once (a player saw "Binding header BAGSMITH was attempted to be
	-- loaded more than once" 322 times: every binding carried the header)
	local xml = io.open("BagSmith/Bindings.xml"):read("*a")
	local headers, bindings, withCategory = 0, 0, 0
	for _ in xml:gmatch('header="BAGSMITH"') do headers = headers + 1 end
	for line in xml:gmatch("<Binding [^\n]*") do
		bindings = bindings + 1
		if line:find('category="BINDING_CATEGORY_BAGSMITH"', 1, true) then withCategory = withCategory + 1 end
	end
	local first = xml:match("<Binding [^\n]*")
	check(headers == 1 and first and first:find('header="BAGSMITH"', 1, true), "the header is declared once, on the first binding (" .. headers .. " found)")
	check(bindings == 8 and withCategory == 8, "all eight bindings are still there, each in BagSmith's category")

	-- ---- 2. cooldown swipes on BagSmith's item buttons
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 118, name = "Minor Healing Potion", q = 1, count = 3, class = 0, subclass = 1, price = 5 })
	M.put(0, 2, { id = 6948, name = "Hearthstone", q = 1, count = 1, class = 15, subclass = 0, price = 0 })
	M.put(0, 3, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
	M.put(1, 1, { id = 118, name = "Minor Healing Potion", q = 1, count = 2, class = 0, subclass = 1, price = 5 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", emptySlots = true } } }
	local onCooldown = { [118] = { 100, 60 } }
	C_Container.GetContainerItemCooldown = function(bag, slot)
		local it = M.bags[bag] and M.bags[bag][slot]
		local cd = it and onCooldown[it.id]
		if cd then return cd[1], cd[2], 1 end
		return 0, 0, 1
	end
	local set = {}
	_G.CooldownFrame_Set = function(frame, start, duration, enable) set[frame] = { start = start, duration = duration, enable = enable } end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V = n.Window.main
	V:SetPref("grp", "none"); V:SetPref("view", "icons"); V:SetPref("mergeStacks", false); n:RefreshViews(true); M.runTimers()
	local function buttonFor(bag, slot) for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.bag == bag and b.rec.slot == slot then return b end end end
	local potion, hearth, linen = buttonFor(0, 1), buttonFor(0, 2), buttonFor(0, 3)
	check(potion and set[potion.Cooldown] and set[potion.Cooldown].start == 100 and set[potion.Cooldown].duration == 60, "a potion on cooldown shows its swipe when the bags draw")
	check(hearth and set[hearth.Cooldown] and set[hearth.Cooldown].duration == 0 and linen and set[linen.Cooldown].duration == 0, "items not on cooldown show none")
	-- the Hearthstone goes on cooldown: the game says cooldowns changed
	onCooldown[6948] = { 200, 1800 }
	M.fire("BAG_UPDATE_COOLDOWN"); M.runTimers()
	check(set[hearth.Cooldown] and set[hearth.Cooldown].start == 200 and set[hearth.Cooldown].duration == 1800, "when cooldowns change, the Hearthstone's swipe starts")
	-- the potion's cooldown ends
	onCooldown[118] = nil
	M.fire("BAG_UPDATE_COOLDOWN"); M.runTimers()
	check(set[potion.Cooldown].duration == 0, "and a cooldown that ended clears")
	-- an empty slot shows none
	local empty; for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.empty then empty = b; break end end
	check(empty and set[empty.Cooldown] and set[empty.Cooldown].duration == 0, "an empty slot shows no cooldown")
	-- individual bag windows: their own buttons get a swipe too
	onCooldown[118] = { 300, 60 }
	local host = CreateFrame("Frame", nil, UIParent)
	local m = n.Buttons:GetMirror(host, 1); m:SetID(1); m.bag = 1
	local rec; for _, r in ipairs(n.items) do if r.bag == 1 and r.slot == 1 then rec = r end end
	n.Buttons:Fill(m, rec); m:Show()
	check(m.Cooldown and set[m.Cooldown] and set[m.Cooldown].start == 300, "a bag window's slot has a cooldown swipe and shows the potion's cooldown")
	onCooldown[118] = nil
	M.fire("BAG_UPDATE_COOLDOWN"); M.runTimers()
	check(set[m.Cooldown].duration == 0, "and it updates when cooldowns change")
	-- another character's items (cached): none
	local cached = n.Buttons:GetMirror(host, 2); cached:SetID(2); cached.bag = 0
	onCooldown[118] = { 400, 60 }
	n.Buttons:Fill(cached, { itemID = 118, name = "Minor Healing Potion", icon = 1, count = 1, quality = 1, bag = 0, slot = 1, cached = true })
	check(set[cached.Cooldown] and set[cached.Cooldown].duration == 0, "another character's items show no cooldown")

	-- ---- 3. Classic: the top-right square buttons light up inside their art, not with a box behind them
	local hl = {}
	local function watch(b)
		local tex = { points = {} }
		tex.ClearAllPoints = function(t) t.points = {} end
		tex.SetPoint = function(t, ...) t.points[#t.points + 1] = { ... } end
		tex.SetAllPoints = function(t) t.points = { "all" } end
		tex.SetVertexColor = function(t, r, g, bb, a) t.alpha = a end
		b.SetHighlightTexture = function(_, file, mode) tex.file, tex.mode = file, mode end
		b.GetHighlightTexture = function() return tex end
		hl[b] = tex
	end
	for _, b in ipairs({ V.btnSettings, V.btnBank, V.btnCurrency, V.btnClean }) do if b then watch(b) end end
	n:Set("skin", "classic"); M.runTimers(); M.runTimers()
	local ok, inset = true, true
	for b, t in pairs(hl) do
		if t.file ~= "Interface\\Buttons\\UI-Common-MouseHilight" or t.mode ~= "ADD" then ok = false end
		local p1 = t.points[1]
		if not (p1 and p1[1] == "TOPLEFT" and p1[2] == 3 and p1[3] == -3) then inset = false end
	end
	check(next(hl) and ok, "Classic: the square buttons hover with the game's soft square-button glow")
	check(inset, "inset to the art, so it lights the button instead of a box behind it")
	n:Set("skin", "modern"); M.runTimers(); M.runTimers()
	local modern = true
	for _, t in pairs(hl) do if not (t.file == "Interface\\Buttons\\WHITE8X8" and t.points[1] == "all" and t.alpha == 0.06) then modern = false end end
	check(modern, "Modern: the flat faint hover over the whole button, as before")
end)()
