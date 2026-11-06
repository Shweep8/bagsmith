;(function()
	-- 1.4.2-beta2 (Shweep's feedback on beta1): the game's cooldown number ("53m") was drawn at full-slot size and
	-- spilled out of List rows and small icons. Each button's number now uses a font fitted to its icon by width and
	-- height, inside the picture with a margin on every side; it hides when nothing legible fits; it follows the game's
	-- cooldown-numbers option; a cooldown-text addon keeps control.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 6948, name = "Hearthstone", q = 1, count = 1, class = 15, subclass = 0, price = 0 })
	M.put(0, 2, { id = 118, name = "Minor Healing Potion", q = 1, count = 3, class = 0, subclass = 1, price = 5 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	M.cvars.countdownForCooldowns = "1"
	-- fonts the way the game draws them: a font object per size, and text whose width grows with the size
	_G.CreateFont = function(name)
		local f = { name = name }
		f.SetFont = function(self, path, size, flags) self.size = size end
		_G[name] = f
		return f
	end
	C_Container.GetContainerItemCooldown = function(bag, slot) if bag == 0 and slot == 1 then return 100, 3600, 1 end return 0, 0, 1 end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local B = n.Buttons
	local measure = UIParent:CreateFontString(nil, "OVERLAY")
	measure.SetFont = function(self, path, size) self.size = size end
	measure.GetStringWidth = function(self) return #tostring(self.text or "") * (self.size or 12) * 0.62 + 2 end
	B.measure = measure
	B:ResetCountdownFonts()
	local function widthAt(size) local w = 0; for _, s in ipairs(B.COUNTDOWN_SAMPLES) do w = math.max(w, #s * size * 0.62 + 2) end return w end

	-- ---- the fit, by width and height, at several icon sizes
	local allFit, allHeight, shown, hidden = true, true, 0, 0
	for _, icon in ipairs({ 44, 37, 30, 24, 20, 16, 14 }) do
		local name = B:CountdownFontFor(icon)
		if name then
			shown = shown + 1
			local size = _G[name].size
			if widthAt(size) + 2 * B.COUNTDOWN_MARGIN > icon then allFit = false end
			if size > icon * B.COUNTDOWN_HEIGHT then allHeight = false end
			-- and it's the largest that fits: one size up would not
			if size + 1 <= math.floor(icon * B.COUNTDOWN_HEIGHT) and widthAt(size + 1) + 2 * B.COUNTDOWN_MARGIN <= icon then allFit = false end
		else
			hidden = hidden + 1
			if widthAt(B.COUNTDOWN_MIN) + 2 * B.COUNTDOWN_MARGIN <= icon and B.COUNTDOWN_MIN <= icon * B.COUNTDOWN_HEIGHT then allFit = false end
		end
	end
	check(allFit, "at every icon size the widest timer, with its margins, fits inside the picture (and is the largest that does)")
	check(allHeight, "and stays under 40% of the icon's height")
	check(shown > 0 and hidden > 0, "big icons get a number, the smallest only the sweep (" .. shown .. " shown, " .. hidden .. " hidden)")

	-- ---- on real buttons, in Icons and List, in both skins
	local function watchCooldowns()
		for _, b in ipairs(B.all or {}) do
			local cd = b.Cooldown
			if cd and not cd.watched then
				cd.watched = true
				cd.SetHideCountdownNumbers = function(self, hide) self.hideNumbers = hide end
				cd.SetCountdownFont = function(self, font) self.font = font end
			end
		end
	end
	watchCooldowns()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V = n.Window.main
	local function hearthButton() for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 6948 then return b end end end
	for _, skin in ipairs({ "modern", "classic" }) do
		n:Set("skin", skin); M.runTimers()
		for _, view in ipairs({ "icons", "list" }) do
			V:SetPref("view", view); n:RefreshViews(true); M.runTimers(); watchCooldowns(); n:RefreshViews(true); M.runTimers()
			local b = hearthButton()
			local want = B:CountdownFontFor(B:IconPx(b))
			local cd = b.Cooldown
			local ok = want and (cd.hideNumbers == false and cd.font == want) or (not want and cd.hideNumbers == true)
			check(ok, skin .. " " .. view .. ": the Hearthstone's number uses the font fitted to its " .. B:IconPx(b) .. " px icon (" .. tostring(cd.font) .. ")")
		end
	end
	-- ---- the game's own option off: no numbers on BagSmith's items; on again: back (in Icons, where one fits)
	V:SetPref("view", "icons"); n:RefreshViews(true); M.runTimers(); watchCooldowns(); n:RefreshViews(true); M.runTimers()
	check(B:CountdownFontFor(B:IconPx(hearthButton())) ~= false, "(in Icons a number fits at " .. B:IconPx(hearthButton()) .. " px)")
	M.cvars.countdownForCooldowns = "0"
	M.fire("CVAR_UPDATE", "countdownForCooldowns"); M.runTimers()
	local b = hearthButton()
	check(b.Cooldown.hideNumbers == true, "with the game's cooldown-numbers option off, the number hides")
	M.cvars.countdownForCooldowns = "1"
	M.fire("CVAR_UPDATE", "countdownForCooldowns"); M.runTimers()
	check(b.Cooldown.hideNumbers == false, "and it comes back when the option is turned on")
	-- ---- a cooldown-text addon keeps control: BagSmith leaves the numbers alone
	_G.C_AddOns = _G.C_AddOns or {}
	local realLoaded = C_AddOns.IsAddOnLoaded
	C_AddOns.IsAddOnLoaded = function(name) return name == "OmniCC" end
	b.Cooldown.hideNumbers, b.Cooldown.font = "untouched", "untouched"
	B:RefreshCooldowns()
	check(b.Cooldown.hideNumbers == "untouched" and b.Cooldown.font == "untouched", "with OmniCC loaded, BagSmith doesn't touch the numbers")
	C_AddOns.IsAddOnLoaded = realLoaded
end)()
