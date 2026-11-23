-- (by design since 1.10.0-beta12: the 1.10 card leads What's New, so every older entry is one place further down)
-- ======== 1.9.8-beta2 (Shweep, 21 Nov) ========
-- "looks good, let's update 'One Thing to Do' to Important and make it that soft red"; "let's show this on next load,
-- while we normally don't in this case we should"; "add a small notes below the bullets few lines down for spacing and
-- say that normally I don't auto open to patches ... but in this case wanted to make this more well known sooner than
-- later"; "reemphasize that if two toons share the same first name, until each is logged into and visits the bank
-- that the global data will not be 100% accurate, apoliges wish this was caught sooner."

local function boot(db, version, prof)
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 13 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = prof or {} } }
	for k, v in pairs(db or {}) do BagSmithDB[k] = v end
	if db == false then _G.BagSmithDB = nil end   -- (no saved data at all: a first install)
	local n = M.loadAddon("BagSmith")
	n.version = version or "1.9.8-beta2"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	return n, M
end
local SEEN_197 = { whatsNewSeen = "1.9.7", whatsNewPatchSeen = { ["1.9.6"] = true, ["1.9.5"] = true, ["1.9.4"] = true, ["1.9.3"] = true, ["1.9.2"] = true, ["1.9.1"] = true }, whatsNewButtonSeen = "1.9.6" }
local function seen() local t = {}; for k, v in pairs(SEEN_197) do t[k] = type(v) == "table" and {} or v; if type(v) == "table" then for a, b in pairs(v) do t[k][a] = b end end end; return t end
local NOTE = "I don't usually open What's New by itself for a patch, since patches are mostly bug fixes that change little. This time I wanted you to know sooner rather than later."

;(function()
	-- The words
	local n = boot(seen())
	local WN = n.WhatsNew
	local e = WN.ENTRIES[2]
	check(e.v == "1.9.8" and #e.items == 2 and e.opens == true, "the 1.9.8 entry: two bullets, and it opens the card by itself")
	check(e.items[2] == "|cfff09595Important:|r if two of your characters share a first name, Global Inventory and tooltips won't be 100% accurate until you've logged in to each of them and visited the bank on each. Apologies, I wish this had been caught sooner.", "Important, word for word, in soft red (as 1.8's Important is)")
	local red = false
	for _, x in ipairs(WN.ENTRIES) do if x.v == "1.8.0" then for _, t in ipairs(x.items) do if t:find("^|cfff09595Important:|r") then red = true end end end end
	check(red, "(the same soft red as 1.8's)")
	check(e.note == NOTE, "the note, word for word")
	local text = table.concat(e.items, " ") .. e.note
	check(not text:find("\226\128\148") and not text:find("\226\128\147"), "no em or en dashes")
	for i = 1, #WN.ENTRIES do if i ~= 2 and (WN.ENTRIES[i].opens or WN.ENTRIES[i].note) then check(false, "no other entry opens by itself or carries a note: " .. WN.ENTRIES[i].v) end end
	check(WN.ENTRIES[3].v == "1.9.7" and not WN.ENTRIES[3].opens, "1.9.7's entry is an ordinary update")
end)()

for _, skin in ipairs({ "modern", "classic" }) do
	-- It opens by itself, once, on its own notes
	local n, M = boot(seen(), nil, { skin = skin })
	local WN, S = n.WhatsNew, skin .. ": "
	check(#WN:UnseenReleases() == 0 and WN:UnseenOpener() == WN.ENTRIES[2] and WN:Pending(), S .. "from 1.9.7, no main release unseen: the 1.9.8 update is waiting to open")
	check(not (BagSmithWhatsNew and BagSmithWhatsNew:IsShown()), S .. "(nothing at login)")
	ToggleAllBags(); M.runTimers(); M.runTimers()
	local f = BagSmithWhatsNew
	check(f and f:IsShown(), S .. "the first time the bags open: the card opens")
	check(f.sub == 1 and f.entries[f.sel].v == "1.9.0", S .. "on the 1.9 tab, on the 1.9.8 update's notes")
	check(BagSmithDB.whatsNewPatchSeen["1.9.8"] == true and not WN:UnseenOpener() and not WN:Pending(), S .. "opening them counts as seen: it won't open again")
	-- the note: under the bullets, set apart, smaller and quieter
	local note, last = f.note, nil
	for _, l in ipairs(f.lines) do if l:IsShown() and l.text and l.text:find("Important:", 1, true) then last = l end end
	check(note and note:IsShown() and note.text == NOTE, S .. "the note is shown under the bullets")
	local function top(r) local p = r.points and r.points[#r.points]; return p and -(p[5] or p[3]) end
	check(last and top(note) and top(last) and top(note) - top(last) >= WN.NOTE_GAP, S .. "a line or two below the last bullet (" .. tostring(top(note) and top(last) and (top(note) - top(last))) .. ")")
	check(f.contentH >= top(note), S .. "and the card's body has room for it")
	-- another update's notes: no note
	WN:SelectPatch(2)
	check(f.entries[f.sel].patches[2].v == "1.9.7" and not note:IsShown(), S .. "1.9.7's notes show no note")
	WN:Select(1)
	check(not note:IsShown(), S .. "nor do the 1.9 release's own")
	WN:SelectPatch(1)
	check(note:IsShown(), S .. "back on 1.9.8's: the note again")
	-- closed, bags reopened: nothing
	WN:Close()
	n.Window.main:Hide(); ToggleAllBags(); M.runTimers(); M.runTimers()
	check(not f:IsShown(), S .. "closed and the bags opened again: it stays closed")
	check((n.errors or 0) == 0, S .. "no errors")
end

;(function()
	-- When it doesn't open
	local n, M = boot(false)   -- a first install
	check(not n.WhatsNew:Pending() and not n.WhatsNew:UnseenOpener(), "a first install: nothing opens")
	n = boot(seen(), nil, { whatsNew = false })
	check(not n.WhatsNew:Pending(), "What's New turned off: nothing opens")
	n = boot(seen(), "1.9.7")
	check(not n.WhatsNew:Pending() and not n.WhatsNew:UnseenOpener(), "running 1.9.7: there's no 1.9.8 update yet")
	n, M = boot(seen())
	M.combat = true
	ToggleAllBags(); M.runTimers(); M.runTimers()
	check(not (BagSmithWhatsNew and BagSmithWhatsNew:IsShown()) and n.WhatsNew:Pending(), "in combat: not now, still waiting")
	M.combat = false
	-- 1.9.7's update, unopened, never opens the card
	local s = seen(); s.whatsNewPatchSeen["1.9.8"] = true
	n = boot(s)
	check(not n.WhatsNew:Pending() and n.WhatsNew:PatchNew(n.WhatsNew:Tabs()[1].patches[2]), "1.9.8's seen, 1.9.7's not: nothing opens (1.9.7's just says NEW)")
	-- a main release unseen as well (straight from 1.8): the update that matters opens, the release is a click away
	n, M = boot({ whatsNewSeen = "1.8.0" })
	ToggleAllBags(); M.runTimers(); M.runTimers()
	local f = BagSmithWhatsNew
	check(f:IsShown() and f.sub == 1 and f.entries[f.sel].v == "1.9.0", "from 1.8: it opens on 1.9.8's notes, under the 1.9 tab")
	n.WhatsNew:Close()
	check(not n.WhatsNew:Pending(), "and closing it settles both")
	-- /bs new reset brings it back, for testing
	n.WhatsNew:ResetForTesting()
	check(n.WhatsNew:Pending() and n.WhatsNew:UnseenOpener() ~= nil, "/bs new reset: it will open again")
	check((n.errors or 0) == 0, "no errors")
end)()
