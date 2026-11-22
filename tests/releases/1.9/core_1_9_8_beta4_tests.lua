-- ======== 1.9.8-beta4 (Shweep, 21 Nov) ========
-- "This works, but problem now is we are reserving the same extra space for patch button w/ every minor we click into
-- leaving a ton of extra space below those buttons. I'd let it go when just one row, but now two and then reserving
-- those two rows on all of them is a bit much." Every tab keeps room for one line of update buttons, as before
-- beta3; a release whose updates need more takes the rest from the room under its own notes, so the card and Got It
-- never move. A NEW showing when the card opened keeps its room once clicked, so nothing shuffles while it's open.

local ROW = 18 + 6   -- an update button's height and the gap under it
local function boot(db, prof)
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 13 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = prof or {} } }
	for k, v in pairs(db or {}) do BagSmithDB[k] = v end
	local n = M.loadAddon("BagSmith")
	n.version = "1.9.8-beta4"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	return n, M
end
local function at(r) local p = r.points and r.points[#r.points]; return p and p[4], p and p[5] end
local function shown(f) local t = {}; for _, b in ipairs(f.subTabs or {}) do if b:IsShown() then t[#t + 1] = b end end; return t end
local function state(f)
	local _, intro = at(f.intro)
	local _, body = at(f.body)
	local _, foot = at(f.footLine)
	return { intro = intro, body = body, bodyH = f.bodyH, foot = foot, card = f:GetHeight(), lines = f.subLines, shift = f.subShift }
end

for _, skin in ipairs({ "modern", "classic" }) do
	local n, M = boot({ whatsNewSeen = "1.9.7" }, { skin = skin })
	local WN, S = n.WhatsNew, skin .. ": "
	ToggleAllBags(); M.runTimers(); M.runTimers()
	local f = BagSmithWhatsNew
	-- the 1.9 tab, seven updates saying NEW: more than one line
	local a = state(f)
	check(f:IsShown() and a.lines >= 2 and a.shift == (a.lines - 1) * ROW, S .. "the 1.9 tab's updates take " .. tostring(a.lines) .. " lines; one is everyone's, the rest its own")
	check(not f.scrolls and f.contentH <= a.bodyH, S .. "its notes still fit under them, with no scrollbar")
	-- another release's tab: one line's room, no more
	WN:Select(2)
	local b = state(f)
	check(#shown(f) == 0 and b.lines == 0 and b.shift == 0, S .. "(the 1.8 tab has no updates)")
	check(b.intro == a.intro + a.shift and b.body == a.body + a.shift, S .. "its text starts higher: only one line's room is kept above it")
	check(b.bodyH == a.bodyH + a.shift, S .. "and it has the room the 1.9 tab's extra lines took")
	check(b.card == a.card and b.foot == a.foot, S .. "the card is the same size, and what's under the notes (the line, the link, Got It) hasn't moved")
	local tabs = {}
	for _, t in ipairs(f.tabs) do if t:IsShown() then tabs[#tabs + 1] = t end end
	local _, tabY = at(tabs[1])
	check(tabY - b.intro == 22 + 10 + ROW, S .. "one line's room between the release tabs and the text (" .. tostring(tabY - b.intro) .. ")")
	-- every other tab the same as that one
	local same = true
	for i = 3, #f.entries do
		WN:Select(i)
		local c = state(f)
		if c.intro ~= b.intro or c.card ~= b.card or c.foot ~= b.foot then same = false end
	end
	check(same, S .. "every other tab: the same place, the same size")
	-- back on 1.9: as it was; an update clicked: its NEW goes and nothing moves, buttons included
	WN:Select(1); WN:SelectPatch(1)
	local c = state(f)
	check(c.intro == a.intro and c.card == a.card and c.lines == a.lines, S .. "back on the 1.9 tab: as it was")
	local before = {}
	for i, btn in ipairs(shown(f)) do before[i] = { btn.left, btn.row } end
	WN:SelectPatch(4); WN:SelectPatch(2)
	local moved = false
	for i, btn in ipairs(shown(f)) do if btn.left ~= before[i][1] or btn.row ~= before[i][2] then moved = true end end
	local d = state(f)
	local p = f.entries[1].patches
	check(not WN:PatchNew(p[4]) and not WN:PatchNew(p[2]) and not (f.subTabs[4].newTag and f.subTabs[4].newTag:IsShown()), S .. "two updates clicked: their NEW is gone")
	check(not moved and d.intro == a.intro and d.lines == a.lines, S .. "no button changed place and the text didn't shift")
	-- closed and opened again: one line, nothing extra anywhere
	WN:Close(); WN:ShowLatest()
	local e = state(f)
	check(e.lines == 1 and e.shift == 0 and e.intro == b.intro and e.card == a.card, S .. "opened again with no NEW left: one line, the 1.9 tab's text where every other tab's is")
	WN:Select(2)
	local g = state(f)
	check(g.intro == e.intro and g.card == e.card, S .. "and switching tabs moves nothing")
	check((n.errors or 0) == 0, S .. "no errors")
end
