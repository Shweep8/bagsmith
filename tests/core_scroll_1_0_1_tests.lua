;(function()
	-- 1.0.1: the wheel and the scrollbar's buttons are the player's input even though their OnVerticalScroll arrives inside the game's own handler
	package.loaded.mock = nil
	local M = require("mock")
	for s = 1, 6 do M.put(0, s, { id = 7000 + s, name = "Item" .. s, q = 1, count = 1, class = 0, subclass = 5, price = 1 }) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "classic", debug = true } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local clock = 5000
	_G.GetTime = function() return clock end   -- a pinned session clock: each phase advances it explicitly
	local function later() clock = clock + 1 end
	local view = n.Window.main; local sf = view.scroll
	view.contentHeight = 600; sf.h = 100   -- a list that scrolls (range 500)
	view.frame.IsMouseOver = function() return true end   -- the pointer is over the window, as it is when you wheel or click its scrollbar
	-- the game: every SetVerticalScroll fires OnVerticalScroll synchronously (the guard's own moves included), and the
	-- wheel and arrow handlers scroll inside themselves, before any post-hook
	local origSet = sf.SetVerticalScroll
	sf.SetVerticalScroll = function(self, v) origSet(self, v); local h = self:GetScript("OnVerticalScroll"); if h then h(self, v) end end
	local function gameScrolls(to) sf:SetVerticalScroll(to) end
	local function last(k) local out = {}; for i = math.max(1, #M.log - k + 1), #M.log do out[#out + 1] = M.log[i] end return table.concat(out, " || ") end
	local function moves() local t = {}; for _, l in ipairs(M.log) do local a, b, by = l:match("scrolled (%d+) %-> (%d+) %(by (%w+)%)"); if a then t[#t + 1] = a .. ">" .. b .. ":" .. by end end return table.concat(t, ",") end
	-- the log's sequence before the fix: a wheel notch moved the list, was undone by rule 4, then moved again; now the wheel handler stamps first
	local wheel = sf:GetScript("OnMouseWheel")
	check(type(wheel) == "function", "(setup) the view's wheel handler is installed")
	M.log = {}
	later()   -- (well past any earlier stamp)
	-- the game's wheel handler is not modeled by the harness, so the sequence is played as the game plays it: the
	-- handler starts (our stamp), then its own scroll fires OnVerticalScroll in the same frame, before any post-hook
	wheel(sf, -1); gameScrolls(133)
	M.runTimers()
	check(moves() == "0>133:you" and sf:GetVerticalScroll() == 133, "a wheel notch is the player's move: it stands, nothing is undone (" .. moves() .. ")")
	-- the former order (a post-hook stamp after the scroll) is what the log showed: the move counted as the game's and was undone
	M.log = {}; later()
	gameScrolls(266); view.userScrollAt = GetTime()
	M.runTimers()
	check(moves():find("^133>266:unknown,266>133:guard") and sf:GetVerticalScroll() == 133, "(the pre-1.0.1 order, for the record: scroll first, stamp after, is undone: " .. moves() .. ")")
	-- the scrollbar's arrow button: a button whose click scrolls inside its own handler, wrapped the same way
	local down = CreateFrame("Button", "FakeScrollDownButton", sf.ScrollBar)
	down:SetScript("OnClick", function() gameScrolls(300) end)
	view:StampInputFirst(down, "OnClick")
	M.log = {}; later()
	down:GetScript("OnClick")(down, "LeftButton")
	M.runTimers()
	check(moves() == "133>300:you" and sf:GetVerticalScroll() == 300, "an arrow click is the player's move: it stands (" .. moves() .. ")")
	-- a move with no input behind it (the game resetting the list) is still undone by rule 4
	M.log = {}; later()
	gameScrolls(0)
	M.runTimers()
	check(moves():find("^300>0:unknown,0>300:guard") and sf:GetVerticalScroll() == 300, "a move the game made on its own is still undone (" .. moves() .. ")")
end)()

