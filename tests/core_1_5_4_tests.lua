;(function()
	-- 1.5.4 (Shweep): seven windows didn't close with Escape; and the Settings side menu was nearly full, with no way to
	-- reach entries that didn't fit. Escape now runs each window's own close action (what its close button does); the
	-- side menu tightens its spacing, then scrolls, if its entries ever don't fit above About & Support.
	local DEID = 13262
	local function boot(skin)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin or "modern", deEnabled = true } } }
		_G.IsSpellKnown = function(id) return id == DEID end
		_G.GetNumSkillLines = function() return 2 end
		_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, 150 end
		_G.RegisterStateDriver = function() end
		_G.UnregisterStateDriver = function() end
		local combat = false
		_G.InCombatLockdown = function() return combat end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M, function(on) combat = on end
	end
	-- The game's Escape: hide every shown frame named in UISpecialFrames (CloseSpecialWindows).
	local function escape()
		local any = false
		for _, name in ipairs(UISpecialFrames) do
			local fr = _G[name]
			if fr and fr:IsShown() then fr:Hide(); any = true end
		end
		return any
	end

	local n, M, setCombat = boot()
	-- the plain windows: Escape does what their close button does (hides them)
	local plain = {
		{ "Loot Exclusion List", function() return n.MakeRoom:NeverWindow() end },
		{ "DE Exclusion List", function() return n.Disenchant:NeverWindow() end },
		{ "moved-items list", function() return n.Sections:MovedWindow() end },
		{ "Loot Helper", function() return n.MakeRoom:Frame() end },
	}
	for _, w in ipairs(plain) do
		local ok, f = pcall(w[2])
		if ok and f then
			f:Show()
			local consumed = escape()
			check(consumed and not f:IsShown(), w[1] .. ": Escape closes it")
		else
			check(false, w[1] .. ": its window could be built for the test (" .. tostring(f) .. ")")
		end
	end
	-- the Disenchant Helper: closes on Escape, and in combat waits until combat ends (it holds a secure button)
	local DE = n.Disenchant
	DE:Show(); M.runTimers()
	local df = DE.frame
	check(df and df:IsShown(), "(setup) the Disenchant Helper is open")
	escape()
	check(not df:IsShown(), "Disenchant Helper: Escape closes it")
	DE:Show(); M.runTimers()
	-- (1.5.6, by design) the game counts the helper as protected (it holds the secure Disenchant button) and won't let it be
	-- hidden in combat: Escape closes it as far as the player can tell, at once, and it really closes when combat ends
	df.protected = true; df.IsProtected = function(self) return self.protected end
	setCombat(true)
	escape()
	check(df:IsShown() and df:GetAlpha() == 0 and df.bsSoftClosed, "Disenchant Helper in combat: Escape makes it vanish at once (fully see-through; the game won't let it hide yet)")
	setCombat(false); M.fire("PLAYER_REGEN_ENABLED"); M.runTimers()
	check(not df:IsShown(), "Disenchant Helper: it closes once combat ends")
	-- the Disenchant offer: Escape means Ask Later, never "don't offer again"
	local of = DE:OfferFrame()
	of:Show()
	escape()
	check(not of:IsShown() and DE.lastOfferAnswer == "later" and not (n.cdb and n.cdb.deOfferDeclined), "Disenchant offer: Escape is Ask Later (" .. tostring(DE.lastOfferAnswer) .. ")")
	-- What's New: Escape closes it and marks it seen, as its close button does
	local WN = n.WhatsNew
	local marked = 0
	local realMark = WN.MarkSeen
	WN.MarkSeen = function(self, ...) marked = marked + 1; return realMark(self, ...) end
	WN:ShowLatest(); M.runTimers()
	local card = _G.BagSmithWhatsNew
	check(card and card:IsShown(), "(setup) What's New is open")
	local before = marked
	escape()
	check(not card:IsShown() and marked > before, "What's New: Escape closes it and marks it seen, as its close button does")
	-- nothing open: Escape isn't taken by BagSmith (the game's menu can open)
	check(not escape(), "with nothing open, Escape isn't taken by a hidden window")

	-- ---- the Settings side menu
	for _, skin in ipairs({ "modern", "classic" }) do
		n, M = boot(skin)
		local P = n.SettingsPanel
		P:Show(); M.runTimers()
		local f = P.frame
		local aboutTop = 560 - (14 + 22 + 6 + 22)
		local function lastBottom()
			local _, rel, _, _, y = P.nav:GetPoint(1)
			local top = (rel == f) and -y or (10 + 28 - y)
			local bottom, shown = 0, 0
			for _, b in ipairs(P.navButtons) do
				if b:IsShown() then
					shown = shown + 1
					local pt = b.points[1]
					local by = type(pt[2]) == "number" and pt[3] or pt[5]
					bottom = math.max(bottom, top - by + b:GetHeight())
				end
			end
			return bottom, shown
		end
		for _, page in ipairs({ "general", "sections", "columns", "sheets", "automation", "dehelper" }) do
			P:ShowPage(page)
			local bottom = lastBottom()
			check(bottom <= aboutTop, ("%s, %s open: the menu ends above About & Support (%d <= %d)"):format(skin, page, bottom, aboutTop))
		end
		-- squeezed: the spacing tightens so every entry still fits
		P:ShowPage("sections")
		local all = select(2, lastBottom())
		f:SetHeight(500); P:SyncNav()
		local bottom, shown = lastBottom()
		check(shown == all and bottom <= 500 - (14 + 22 + 6 + 22), skin .. ": a shorter window tightens the spacing, every entry still showing above About & Support")
		-- squeezed further: it scrolls, the open page stays in view, and the wheel reaches the rest
		f:SetHeight(360); P:SyncNav()
		bottom, shown = lastBottom()
		local cur
		for _, b in ipairs(P.navButtons) do if b.page == "sections" then cur = b end end
		check(shown < all and bottom <= 360 - (14 + 22 + 6 + 22) and cur:IsShown(), skin .. ": when even tight spacing can't fit them, it scrolls, keeping the open page in view")
		local wheel = P.nav:GetScript("OnMouseWheel")
		check(wheel ~= nil, skin .. ": the menu scrolls with the mouse wheel")
		if wheel then
			for _ = 1, 20 do wheel(P.nav, -1) end
			local last = P.navButtons[#P.navButtons]
			check(last:IsShown(), skin .. ": scrolled down, the last entry comes into view")
		end
		f:SetHeight(560); P:SyncNav()
		check(select(2, lastBottom()) == all, skin .. ": back at full height, all entries show again")
	end
end)()
