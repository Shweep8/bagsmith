-- ======== 1.12.0 (Shweep, 28 Nov: "Approve production") ========
-- The production build: 1.12.0-beta7 plus the version (the TOC's version, and the pin in tests/run.lua). No code
-- changes, and none to the changelog: its 1.12.0 section was written with each beta this time (1.11.0's lesson) and
-- already says what the release holds, entry for entry as the release notes do. This set pins that section and the
-- What's New card as the release ships them.

local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function slurp(p) local f = assert(io.open(p, "r")); local s = f:read("*a"); f:close(); return s end
local function boot(seen, version)
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 13 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } }, whatsNewSeen = seen }
	_G.BagSmithWhatsNew = nil
	local n = M.loadAddon("BagSmith")
	n.version = version   -- (the mock's own version is a stand-in; What's New goes by the running one)
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	return n, M
end

------------------------------------------------------------------------
-- The changelog's 1.12.0 section, as the release ships it
------------------------------------------------------------------------
do
	local log = slurp("BagSmith/CHANGELOG.md")
	local top = ("\n" .. log):match("\n## 1%.12%.0\n(.-)\n## 1%.11%.0\n")
	check(top ~= nil, "the changelog has 1.12.0, above 1.11.0")
	top = top or ""
	local flat = top:gsub("\n  ", " ")
	check(flat:find("\n- A Pawn column for List view (Settings > Bag Columns or Bank Columns, with Pawn installed). Beside a green arrow it shows how much of an upgrade Pawn says each item is for you, such as +15%, or the arrow alone when Pawn gives no number. Click its heading to sort by it. It starts unticked, right after Item in the list, so your columns stay as they are until you tick it.\n", 1, true),
		"New: the Pawn column, where to tick it, what a cell shows, and that nothing moves until it is ticked")
	check(flat:find("\n- With Sections: By Bag, each bag's section shows that bag's icon beside its name.\n", 1, true), "New: bag icons on By Bag sections")
	check(flat:find("\n- Other addons can add columns to List view. One that does shows up in Settings > Bag Columns and Bank Columns, unticked, for you to tick, move, resize and sort by like any other. (For addon authors: BagSmith.API 1.2.)\n", 1, true),
		"New: columns from other addons, and the API version for their authors")
	check(flat:find("\n- Right-click a bag in your bags when every bag slot is full, and BagSmith offers a menu of the bags you are wearing, smallest first, to swap it in for. Before, the game only said there was no slot.\n", 1, true),
		"New: the menu for a right-clicked bag")
	check((flat .. "\n"):find("\n- The Disenchant Helper's Results had an empty band above its tabs. Results now starts right under the title.\n", 1, true), "Fixed: the Helper's Results")
	local a, b = top:find("^\nNew:\n"), top:find("\n\nFixed:\n")
	check(a and b and a < b and not top:find("\nChanged:\n"), "New, then Fixed; nothing under Changed")
	local entries = 0
	for _ in ("\n" .. top):gmatch("\n%- ") do entries = entries + 1 end
	check(entries == 5, "five entries (four new, one fixed)")
	local long, dash = false, false
	for line in (top .. "\n"):gmatch("(.-)\n") do
		if #line > 120 then long = true end
		if line:find("\226\128\148") or line:find("\226\128\147") then dash = true end
	end
	check(not long, "no line over 120 characters")
	check(not dash, "no em or en dashes")
	check(not log:find("## 1%.12%.0%-beta") and not log:find("## 1%.12%.0%-rc"), "one 1.12.0 section, no beta entries")
	-- what the entries name is what the addon says
	check(slurp("BagSmith/Core/API.lua"):find("VERSION = { major = 1, minor = 2 }", 1, true), "BagSmith.API is 1.2, as the entry tells addon authors")
end

------------------------------------------------------------------------
-- The What's New card, on the release itself
------------------------------------------------------------------------
do
	-- someone updating from 1.11.0
	local n = boot("1.11.0", "1.12.0")
	local WN = n.WhatsNew
	local e = WN.ENTRIES[1]
	check(e.v == "1.12.0" and e.heading == "BagSmith 1.12" and #e.items == 4, "the 1.12 card leads What's New, four bullets (Shweep, 28 Nov, asked if it reads right: \"yes\")")
	check(plain(e.items[1]):find("^A Pawn Column: ") and plain(e.items[2]):find("^Swap Bags With a Right%-Click: ") and plain(e.items[3]):find("^Columns From Other Addons: ") and plain(e.items[4]):find("^Bag Icons on By Bag Sections: "),
		"its four bullets, in the order he read them")
	check(WN:Pending() and WN:UnseenReleases()[1].v == "1.12.0", "running 1.12.0 after 1.11.0: the card is waiting")
	-- someone who saw it during the betas (a beta counts as its release for this) is not shown it again
	local n2 = boot("1.12.0", "1.12.0")
	check(not n2.WhatsNew:Pending(), "a beta tester who has seen the card does not get it again from the release")
	check((n.errors or 0) == 0 and (n2.errors or 0) == 0, "no errors")
end

------------------------------------------------------------------------
-- The version
------------------------------------------------------------------------
do
	-- The exact version is pinned in tests/run.lua. What holds from this build on: the TOC is at 1.12.0 or later,
	-- 1.12.0 itself carries no beta mark any more, and there is no development marker.
	local toc = slurp("BagSmith/BagSmith.toc")
	local ver = toc:match("\n## Version: ([^\n]+)\n") or ""
	local major, minor = ver:match("^(%d+)%.(%d+)%.%d+")
	major, minor = tonumber(major) or 0, tonumber(minor) or 0
	check(major > 1 or (major == 1 and minor >= 12), "the TOC's version is 1.12.0 or later: " .. ver)
	check(not ver:find("^1%.12%.0%-"), "and 1.12.0 has no beta mark: " .. ver)
	check(not toc:find("X%-BagSmith%-Dev"), "no development marker")
end
