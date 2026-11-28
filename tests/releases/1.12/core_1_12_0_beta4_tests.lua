-- ======== 1.12.0-beta4 (Shweep, 28 Nov: "all tested beautifully! one UI fix ... and give me everything for an audit") ========
-- The candidate that goes to audit: beta3 plus
--   1. "we have excess space at top in DE helper when in results screen": Results starts right under the title.
--   2. the 1.12 What's New card, drafted for him to keep, change or strike (the convention: with the candidate).
-- Settings' NEW tags are left as they are: 1.12 adds no setting to tag, and 1.11's list shows nothing in 1.12.

local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function slurp(p) local f = assert(io.open(p, "r")); local s = f:read("*a"); f:close(); return s end
local function boot(db)
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 13 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
	for k, v in pairs(db or {}) do BagSmithDB[k] = v end
	_G.BagSmithWhatsNew = nil
	local n = M.loadAddon("BagSmith")
	n.version = "1.12.0-beta4"   -- (the mock's own version is a stand-in; What's New and the NEW tags go by the running one)
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	return n, M
end

------------------------------------------------------------------------
-- 1. The Disenchant Helper's Results: no empty band above its tabs
------------------------------------------------------------------------
for _, skin in ipairs({ "modern", "classic" }) do
	local n, M = boot()
	n:Set("skin", skin); M.runTimers()
	local DE = n.Disenchant
	local f = DE:Frame()
	local R = f.results
	local top = R.points[1]
	check(DE.RESULTS_TOP == -34 and top[1] == "TOPLEFT" and top[2] == 12 and top[3] == -34, skin .. ": Results starts 34 px down, right under the title (it was 52)")
	check(-DE.RESULTS_TOP >= n.Classic.DIALOG_BAR + 6, skin .. ": clear of the window's own title bar in the Classic look (" .. n.Classic.DIALOG_BAR .. " px)")
	local bottom = R.points[2]
	check(bottom[1] == "BOTTOMRIGHT" and bottom[2] == -12 and bottom[3] == 40, skin .. ": its bottom edge is where it was: the room gained goes to the results")
	check(R.tabSession.points[1][1] == "TOPLEFT" and R.tabSession.points[1][3] == 0 and R.back.points[1][1] == "TOPRIGHT" and R.scroll.points[1][3] == -32, skin .. ": the tabs, Back to List and the list under them keep their places inside it")
	-- the title's own place, and the line under it that Results hides
	check(f.title.points[1][3] == -12 and f.sub.points[1][2] == f.title and f.sub.points[1][5] == -3, skin .. ": (the title at 12 px, the count line anchored under it)")
	DE.view = "results"; DE:Paint()
	check(R:IsShown() and not f.sub:IsShown() and not f.scroll:IsShown() and not f.cur:IsShown(), skin .. ": in Results the count line, the list and the item panel are put away")
	DE.view = nil; DE:Paint()
	check(not R:IsShown() and f.empty:IsShown(), skin .. ": back in the list (nothing to offer here: its card), Results is put away")
	check((n.errors or 0) == 0, skin .. ": no errors")
end

------------------------------------------------------------------------
-- 2. The 1.12 What's New card
------------------------------------------------------------------------
do
	local n = boot({ whatsNewSeen = "1.11.0" })
	local WN = n.WhatsNew
	local e = WN.ENTRIES[1]
	check(e.v == "1.12.0" and e.heading == "BagSmith 1.12" and #e.items == 4, "the 1.12 card leads What's New, four bullets")
	check(plain(e.items[1]) == "A Pawn Column: in List view, see how much of an upgrade Pawn says each item is, beside a green arrow, and sort by it. Tick Pawn in Settings > Bag Columns or Bank Columns.", "the Pawn column, and where to tick it")
	check(plain(e.items[2]) == "Swap Bags With a Right-Click: right-click a bag when every bag slot is full, and pick which of the bags you're wearing it should replace.", "the bag menu")
	check(plain(e.items[3]) == "Columns From Other Addons: other addons can add their own columns to List view now. Tick one in Settings > Bag Columns like any other.", "columns from other addons")
	check(plain(e.items[4]) == "Bag Icons on By Bag Sections: with Sections: By Bag, each bag's section shows that bag's icon beside its name.", "bag icons on By Bag sections")
	local lead, dash = true, false
	for _, item in ipairs(e.items) do
		if not item:find("^|cfffac775[^|]+:|r ") then lead = false end
		if item:find("\226\128\148") or item:find("\226\128\147") then dash = true end
	end
	check(lead and not dash, "each bullet leads with what you get, in the accent; no dashes")
	check(WN.ENTRIES[2].v == "1.11.0" and #WN.ENTRIES[2].items == 8, "1.11's card is under it, its eight bullets as they were")
	check(WN:Pending() and WN:UnseenReleases()[1].v == "1.12.0", "someone updating from 1.11 has the 1.12 card waiting")
	-- someone who has seen it has nothing waiting
	local n2 = boot({ whatsNewSeen = "1.12.0" })
	check(not n2.WhatsNew:Pending(), "once seen, it doesn't open again")
	-- Settings' NEW tags: 1.11's list is left in place and shows nothing in 1.12
	local P = n.SettingsPanel
	check(P.NEW.release == "1.11" and tostring(n.version):match("^1%.12"), "Settings' NEW list is still 1.11's, and this is 1.12: nothing in Settings is tagged NEW")
	check((n.errors or 0) == 0 and (n2.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- 3. The changelog and the version
------------------------------------------------------------------------
do
	local top = slurp("BagSmith/CHANGELOG.md"):match("^## 1%.12%.0\n(.-)\n## 1%.11%.0\n")
	top = (top or ""):gsub("\n  ", " ")
	check(top:find("\n\nFixed:\n- The Disenchant Helper's Results had an empty band above its tabs. Results now starts right under the title.", 1, true) ~= nil, "the changelog's 1.12.0 has the fix, under Fixed")
	local a, b = top:find("\nNew:\n", 1, true), top:find("\n\nFixed:\n", 1, true)
	local entries = 0
	for _ in ("\n" .. top):gmatch("\n%- ") do entries = entries + 1 end
	check(a and b and a < b and entries == 5, "New, then Fixed: four new, one fixed")
	check(not top:find("\226\128\148") and not top:find("\226\128\147"), "no dashes")
	check(slurp("BagSmith/BagSmith.toc"):find("\n## Version: 1%.12%.0"), "the TOC version is 1.12.0's (the exact one is pinned in tests/run.lua)")
	check(not slurp("BagSmith/BagSmith.toc"):find("X%-BagSmith%-Dev"), "no development marker in the TOC")
end
