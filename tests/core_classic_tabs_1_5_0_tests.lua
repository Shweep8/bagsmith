;(function()
	-- 1.5.0-beta6 (Shweep: dark strips below some Classic sheet tabs, most on narrow ones): every piece of the game's
	-- tab art taller than the tab is cropped to the tab's height, keeping the part of its art that showed; refits
	-- never compound; /bs debug on a tab says whether any art reaches below it.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "classic" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V = n.Window.main
	local tab
	for _, b in ipairs(V.tabButtons or {}) do if b:IsShown() and b.classicOn then tab = b; break end end
	check(tab and tab.classic and tab.classic.isTab, "(control) Classic sheet tabs wear the game's tab art")
	local art = tab.classic
	-- the template's pieces, as the game makes them: end pieces 32 px tall, a middle that fits
	local function piece(w, h, coords)
		local t = art:CreateTexture()
		t.SetHeight = function(self, v) self.h = v end   -- (the mock's textures don't model a height change)
		t.GetHeight = function(self) return self.h end
		t.GetWidth = function(self) return self.w end
		t.SetSize = function(self, a, b) self.w, self.h = a, b end
		t:SetSize(w, h); t:Show()
		t.coords = coords
		t.GetTexCoord = function(self) local c = self.coords; return c[1], c[2], c[1], c[3], c[4], c[2], c[4], c[3] end
		t.SetTexCoord = function(self, l, r, top, bottom) self.coords = { l, top, bottom, r } end
		return t
	end
	local left = piece(20, 32, { 0, 0, 1, 0.25 })
	local mid = piece(40, tab:GetHeight(), { 0.25, 0, 1, 0.75 })
	local right = piece(20, 32, { 0.75, 0, 1, 1 })
	art.GetRegions = function() return left, mid, right end
	n.db.debug = true
	tab.classic.LockHighlight = tab.classic.LockHighlight or function() end
	tab:GetScript("OnEnter")(tab)
	local said = false
	for _, l in ipairs(M.log) do if l:find("art reaching below the tab", 1, true) then said = true end end
	check(said, "/bs debug on a tab names art reaching below it")
	n.Classic.FitTabArt(tab)
	local h = tab:GetHeight()
	check(left:GetHeight() == h and right:GetHeight() == h and mid:GetHeight() == h, "the end pieces are cropped to the tab's height (" .. h .. " px); the middle already fit")
	check(math.abs(left.coords[3] - h / 32) < 1e-6 and left.coords[2] == 0 and math.abs(right.coords[3] - h / 32) < 1e-6, "only their lower part is cut off: the art that showed inside the tab is unchanged")
	-- a taller tab, then back: no compounding
	tab:SetHeight(30); n.Classic.FitTabArt(tab)
	check(left:GetHeight() == 30 and math.abs(left.coords[3] - 30 / 32) < 1e-6, "a refit at another height crops from the piece's original art, not from the last crop")
	tab:SetHeight(40); n.Classic.FitTabArt(tab)
	check(left:GetHeight() == 32 and left.coords[3] == 1, "a tab taller than the art gets the piece back whole")
	tab:SetHeight(h); n.Classic.FitTabArt(tab)
	M.log = {}
	tab:GetScript("OnEnter")(tab)
	local fits = false
	for _, l in ipairs(M.log) do if l:find("all its art fits inside the tab", 1, true) then fits = true end end
	check(fits, "and once fitted, /bs debug says it all fits")
	-- Modern: the tab art is off, Modern's own look is untouched
	n:Set("skin", "modern"); M.runTimers()
	check(not tab.classicOn and not art:IsShown(), "Modern: no game tab art on the tabs")
end)()
