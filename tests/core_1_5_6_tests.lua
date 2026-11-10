;(function()
	-- 1.5.6 (Shweep): the Disenchant Helper didn't fade in combat and couldn't be closed in combat; every window should fade
	-- like the bags window and close with Escape in combat. The helper is protected (Shweep, in game: IsProtected true,
	-- the bags window false): its secure Disenchant button makes it so, and the game won't let an addon hide it in combat.
	-- So in combat it closes as far as the player can tell, and finishes closing when combat ends. The mock models the
	-- game's rule: a frame marked protected errors on Show, Hide, SetPoint or SetSize in combat.
	local DEID = 13262
	local function boot(prof)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local p = { skin = "modern", deEnabled = true }
		for k, v in pairs(prof or {}) do p[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
		_G.IsSpellKnown = function(id) return id == DEID end
		_G.GetNumSkillLines = function() return 2 end
		_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, 150 end
		_G.RegisterStateDriver = function() end
		_G.UnregisterStateDriver = function() end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M
	end
	local function combat(M, on)
		M.combat = on
		M.fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED"); M.runTimers()
	end
	local function escape()
		local any = false
		for _, name in ipairs(UISpecialFrames) do
			local fr = _G[name]
			if fr and fr:IsShown() then fr:Hide(); any = true end
		end
		return any
	end
	local function protect(f) f.protected = true; f.IsProtected = function(self) return self.protected end end

	-- ---- every BagSmith window fades in combat, like the bags window
	local n, M = boot()
	local DE = n.Disenchant
	DE:Show(); M.runTimers()
	local windows = {
		{ "Disenchant Helper", DE.frame },
		{ "Loot Helper", n.MakeRoom:Frame() },
		{ "Loot Exclusion List", n.MakeRoom:NeverWindow() },
		{ "DE Exclusion List", DE:NeverWindow() },
		{ "moved-items list", n.Sections:MovedWindow() },
		{ "Disenchant offer", DE:OfferFrame() },
	}
	n.WhatsNew:ShowLatest(); M.runTimers()
	windows[#windows + 1] = { "What's New", _G.BagSmithWhatsNew }
	n.SettingsPanel:Show(); M.runTimers()
	windows[#windows + 1] = { "Settings", n.SettingsPanel.frame }
	for _, w in ipairs(windows) do w[2]:Show() end
	combat(M, true)
	local alpha = n.db.combatAlpha
	for _, w in ipairs(windows) do
		local f = w[2]
		check(f:GetAlpha() == alpha and f.bsShield and f.bsShield:IsShown(), w[1] .. ": fades in combat and ignores clicks, like the bags window (alpha " .. tostring(f:GetAlpha()) .. ")")
	end
	combat(M, false)
	for _, w in ipairs(windows) do
		local f = w[2]
		check(f:GetAlpha() == 1 and not (f.bsShield and f.bsShield:IsShown()), w[1] .. ": back to normal after combat")
	end
	-- a window opened in combat fades at once
	local lf = n.MakeRoom:NeverWindow(); lf:Hide()
	combat(M, true)
	lf:Show()
	check(lf:GetAlpha() == alpha, "a window opened during combat fades at once")
	combat(M, false); lf:Hide()

	-- ---- the Disenchant Helper's own clicks are caught by a part BagSmith controls, not the protected window
	local f = DE.frame
	check(f.bsCatcher and f.bsCatcher:GetScript("OnDragStart") and f.bsCatcher:GetFrameLevel() <= f.closeX:GetFrameLevel(), "the helper's empty space and dragging belong to its catcher, under its buttons")

	-- ---- in combat, a protected Disenchant Helper closes as far as you can tell, and finishes after combat
	n, M = boot()
	DE = n.Disenchant
	DE:Show(); M.runTimers()
	f = DE.frame
	protect(f)
	combat(M, true)
	local ok, err = pcall(escape)
	check(ok, "Escape in combat doesn't try anything the game blocks (" .. tostring(err) .. ")")
	check(f:GetAlpha() == 0 and f:IsShown() and f.bsSoftClosed, "Escape in combat: it turns fully see-through at once (the game won't let it hide yet)")
	check(not f.bsShield:IsShown(), "nothing invisible is left catching clicks: its combat shield is off")
	check(f.closeX.bsMouseOff and f.bsCatcher.bsMouseOff, "its close button and catcher stop taking clicks")
	ok, err = pcall(combat, M, false)
	check(ok and not f:IsShown() and f:GetAlpha() == 1 and not f.bsSoftClosed and not f.closeX.bsMouseOff, "when combat ends it closes for real, and is ready to open normally (" .. tostring(err) .. ")")
	-- its close button in combat does the same
	DE:Show(); M.runTimers()
	combat(M, true)
	ok, err = pcall(f.closeX:GetScript("OnClick"), f.closeX)
	check(ok and f:GetAlpha() == 0 and f.bsSoftClosed, "its close button in combat does the same (" .. tostring(err) .. ")")
	-- changed your mind mid-fight: opening it brings it back, faded like the other windows, Escape working again
	ok, err = pcall(DE.Show, DE); M.runTimers()
	check(ok and not f.bsSoftClosed and f:GetAlpha() == n.db.combatAlpha and not f.closeX.bsMouseOff and f.bsShield:IsShown(), "opening it again in combat brings it back, faded (" .. tostring(err) .. ")")
	ok = pcall(escape)
	check(ok and f.bsSoftClosed, "and Escape closes it again")
	combat(M, false)
	check(not f:IsShown(), "(after combat, closed)")
	-- opening it from closed in combat isn't possible (the game blocks showing it): it says so, nothing breaks
	combat(M, true)
	ok, err = pcall(DE.Show, DE)
	check(ok and not f:IsShown(), "opening it from closed in combat is refused politely (" .. tostring(err) .. ")")
	combat(M, false)
	-- out of combat it closes normally
	DE:Show(); M.runTimers()
	escape()
	check(not f:IsShown() and not f.bsSoftClosed, "out of combat, Escape closes it normally")

	-- ---- a Disenchant Helper the game doesn't count as protected just closes in combat
	n, M = boot()
	DE = n.Disenchant
	DE:Show(); M.runTimers()
	f = DE.frame
	combat(M, true)
	escape()
	check(not f:IsShown() and not f.bsSoftClosed, "not protected: Escape in combat closes it at once")
	combat(M, false)

	-- ---- the Disenchant button hides itself in combat through its secure guard, and comes back after
	n, M = boot()
	DE = n.Disenchant
	DE:Show(); M.runTimers()
	local b = DE:Button()
	local run = assert(loadstring("return function(self, newstate) " .. b:GetAttribute("_onstate-bscombat") .. " end"))()
	b:Show()
	run(b, "lock")
	check(not b:IsShown() and b:GetAttribute("type") == nil, "combat: the guard hides the button (and disarms it, as before)")
	run(b, "lock")
	run(b, "open")
	check(b:IsShown(), "combat over: it shows again (a repeated lock doesn't lose that)")
	b:Hide(); run(b, "lock"); run(b, "open")
	check(not b:IsShown(), "a button that was hidden before combat stays hidden after")

	-- ---- with combat fading off, nothing fades, and the helper still closes in combat
	n, M = boot({ combatFade = false })
	DE = n.Disenchant
	DE:Show(); M.runTimers()
	f = DE.frame
	protect(f)
	combat(M, true)
	check(f:GetAlpha() == 1, "Fade Windows During Combat off: no fading")
	escape()
	check(f:GetAlpha() == 0 and f.bsSoftClosed, "and Escape still closes the helper as far as you can tell")
	combat(M, false)
	check(not f:IsShown() and f:GetAlpha() == 1, "closing for real after combat")

	-- ---- (beta2) Settings search ranks pages by how well they match (Shweep: "Recent" put Recent Items near the bottom)
	n, M = boot()
	local P = n.SettingsPanel
	P:Show(); M.runTimers()
	local function search(text)
		local box = P.frame.search
		box:SetText(text); box:GetScript("OnTextChanged")(box, true)
	end
	local function yOf(w) for _, pt in ipairs(w.points or {}) do if pt[1] == "TOPLEFT" then return -(pt[5] or 0) end end return 0 end
	-- every shown result widget, top to bottom
	local function shown()
		local out = {}
		for kind, pool in pairs(P.pools) do
			for _, w in ipairs(pool) do if w:IsShown() then out[#out + 1] = { kind = kind, w = w, y = yOf(w) } end end
		end
		table.sort(out, function(a, b) return a.y < b.y end)
		return out
	end
	local function titles()
		local t = {}
		for _, e in ipairs(shown()) do if e.kind == "ptitle" then t[#t + 1] = e.w.text.text end end
		return t
	end
	local function indexOf(list, v) for i, x in ipairs(list) do if x == v then return i end end end
	search("recent")
	local t = titles()
	check(t[1] == "Results:" and t[2] == "Dynamic Sections", "\"recent\": the page whose own setting is named Recent comes first (" .. table.concat(t, ", ") .. ")")
	local rows = shown()
	local firstRow
	for _, e in ipairs(rows) do if e.kind ~= "ptitle" and e.kind ~= "head" and e.w.key then firstRow = e.w.key; break end end
	check(firstRow == "recentSection", "\"recent\": and Recent Items is the first setting in the results (" .. tostring(firstRow) .. ")")
	-- (1.6.0-beta4, by design) the approved Settings wording dropped "a recent roll" from the Disenchant Helper's Skip
	-- Refundable line, so the page that matches only by its text is now Sections ("just under Recent", Pinned Sections)
	local ii, de = indexOf(t, "Item Icons"), indexOf(t, "Sections")
	check(ii and de and ii < de, "a name that contains it (Item Icons: Clear Recent...) comes before text that mentions it (Sections)")
	local seen, dup = {}, false
	for _, e in ipairs(rows) do
		if e.w.key then local k = e.kind .. ":" .. tostring(e.w.key); if seen[k] then dup = true end; seen[k] = true end
	end
	local tseen, tdup = {}, false
	for _, x in ipairs(t) do if tseen[x] then tdup = true end; tseen[x] = true end
	check(not dup and not tdup, "nothing is drawn twice (the ranking's measuring pass leaves nothing behind)")
	search("rec")
	t = titles()
	check(t[2] == "Dynamic Sections", "the start of a word ranks the same way (\"rec\")")
	search("recent items")
	t = titles()
	check(t[2] == "Dynamic Sections", "several words: \"recent items\" puts Dynamic Sections first")
	search("cooldown")
	local found = false
	for _, w in ipairs(P.pools.step) do if w:IsShown() and w.key == "iconSize" then found = true end end
	check(found, "a word only in an info icon's keywords is still found (\"cooldown\": Icon Size)")
	search("zzqxw")
	t = titles()
	check(#t == 1 and t[1] == "Results:", "no matches: just the empty results")
	search("")
	check(not P:Searching(), "clearing the box ends the search")
end)()
