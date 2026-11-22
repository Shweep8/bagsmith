-- ======== 1.9.8-beta3 (Shweep, 21 Nov) ========
-- "all the new tags are causing the patch buttons to go outside the window": eight updates under 1.9, seven saying
-- NEW, on one row with no wrapping. (1) "yes": the row wraps onto another line. (2) "yes option 1": closing the card
-- counts every update listed as seen, so NEW means "arrived since you last had this open". (3) a cap: "not now".

local CARD_W, PAD = 512, 16
local function boot(db, prof)
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 13 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = prof or {} } }
	for k, v in pairs(db or {}) do BagSmithDB[k] = v end
	local n = M.loadAddon("BagSmith")
	n.version = "1.9.8-beta3"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	return n, M
end
-- a point's offsets, written long ("TOPLEFT", frame, "TOPLEFT", x, y)
local function at(r) local p = r.points and r.points[#r.points]; return p and p[4], p and p[5] end
local function shown(f) local t = {}; for _, b in ipairs(f.subTabs or {}) do if b:IsShown() then t[#t + 1] = b end end; return t end

for _, skin in ipairs({ "modern", "classic" }) do
	-- Nobody clicked an update yet: seven say NEW, and the row wraps
	local n, M = boot({ whatsNewSeen = "1.9.7" }, { skin = skin })
	local WN, S = n.WhatsNew, skin .. ": "
	ToggleAllBags(); M.runTimers(); M.runTimers()
	local f = BagSmithWhatsNew
	check(f and f:IsShown() and f.sub == 1, S .. "(the card opens on the 1.9.8 update)")
	local btns = shown(f)
	local news = 0
	for _, b in ipairs(btns) do if b.newTag and b.newTag:IsShown() then news = news + 1 end end
	check(#btns == 8 and news == 7, S .. "eight update buttons, seven saying NEW (" .. #btns .. ", " .. news .. ")")
	local inside, apart, lastRow = true, true, 0
	for i, b in ipairs(btns) do
		local x, y = at(b)
		if not (x and x >= PAD and x + b.need <= CARD_W - PAD) then inside = false end
		if x ~= b.left then inside = false end
		lastRow = math.max(lastRow, b.row)
		local prev = btns[i - 1]
		if prev and prev.row == b.row and b.left < prev.left + prev.need then apart = false end
		if prev and b.row < prev.row then apart = false end
		if prev and prev.row ~= b.row and b.left ~= PAD then apart = false end
		local py
		if prev then local _, yy = at(prev); py = yy end
		if prev and prev.row ~= b.row and not (y < py) then apart = false end
	end
	check(inside, S .. "every button, with its NEW, is inside the card")
	check(lastRow >= 1, S .. "they take more than one line (" .. (lastRow + 1) .. ")")
	check(apart, S .. "no two overlap, a new line starts at the left, and lines go down")
	check(f.subLines == lastRow + 1, S .. "the card knows how many lines they take")
	local _, introY = at(f.intro)
	local _, lastY = at(btns[#btns])
	check(introY and lastY and introY < lastY - 18, S .. "the text below starts under the last line")
	-- a tab with no updates, an update clicked: nothing below moves
	-- (by design since 1.9.8-beta4, Shweep: "reserving those two rows on all of them is a bit much": a tab keeps room
	-- for one line; the extra lines are the 1.9 tab's own, so the text on another tab starts higher)
	local h1 = f:GetHeight()
	WN:Select(2)
	local _, y2 = at(f.intro)
	check(#shown(f) == 0 and y2 == introY + lastRow * 24 and f:GetHeight() == h1, S .. "another release's tab: one line's room, so its text starts higher; the card is the same size")
	WN:Select(1); WN:SelectPatch(3)
	local _, y3 = at(f.intro)
	check(y3 == introY and not WN:PatchNew(f.entries[1].patches[3]), S .. "an update clicked: its NEW goes, nothing jumps")

	-- Closing counts every update as seen
	check(WN:PatchNew(f.entries[1].patches[2]) and WN:ButtonNew(), S .. "(before closing: 1.9.7 still says NEW, and so does Settings' button)")
	WN:Close()
	local left = 0
	for _, p in ipairs(WN:Tabs()[1].patches) do if WN:PatchNew(p) then left = left + 1 end end
	check(not f:IsShown() and left == 0 and not WN:ButtonNew(), S .. "closed: no update says NEW, nor does Settings' button")
	local seen = BagSmithDB.whatsNewPatchSeen
	check(seen["1.9.8"] and seen["1.9.7"] and seen["1.9.1"], S .. "(every update is recorded as seen)")
	-- opened again: one line now, all inside
	WN:ShowLatest()
	btns = shown(f)
	local oneLine = #btns == 8
	for _, b in ipairs(btns) do
		if b.row ~= 0 or (b.newTag and b.newTag:IsShown()) or b.left + b.need > CARD_W - PAD then oneLine = false end
	end
	check(oneLine and f.subLines == 1, S .. "opened again: eight buttons on one line, none saying NEW")
	-- a later update says NEW again
	seen["1.9.8"] = nil
	check(WN:PatchNew(WN:Tabs()[1].patches[1]) and not WN:PatchNew(WN:Tabs()[1].patches[2]), S .. "an update that arrives later says NEW, the others don't")
	check((n.errors or 0) == 0, S .. "no errors")
end

;(function()
	-- Closing only counts when the card was open; and Settings' button opens on the update that matters
	local n, M = boot({ whatsNewSeen = "1.9.7" })
	local WN = n.WhatsNew
	WN:Close()
	check(WN:PatchNew(WN:Tabs()[1].patches[2]) and WN:UnseenOpener() ~= nil, "a close with nothing open leaves the updates as they were")
	WN:ShowLatest()
	local f = BagSmithWhatsNew
	check(f:IsShown() and f.sub == 1 and not WN:UnseenOpener(), "opened from Settings: on the 1.9.8 update's notes, which counts as opening them")
	WN:Close()
	n.Window.main:Hide(); ToggleAllBags(); M.runTimers(); M.runTimers()
	check(not f:IsShown(), "and it doesn't open by itself afterwards")
	check((n.errors or 0) == 0, "no errors")
end)()
