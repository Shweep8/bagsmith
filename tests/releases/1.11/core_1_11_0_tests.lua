-- ======== 1.11.0 (Shweep, 27 Nov: "approve prod") ========
-- The production build: 1.11.0-beta9 plus the version, and the changelog's 1.11.0 section brought up to what the
-- release holds. That section was last written at beta4, before the Helper showed what it holds back (beta6 to
-- beta8) and before Results' comparison was made careful (beta5, beta6). Its wording is the wording Shweep was shown
-- in each beta's notes as "the upcoming release". No code changes.

local function slurp(p) local f = assert(io.open(p, "r")); local s = f:read("*a"); f:close(); return s end

do
	local log = slurp("BagSmith/CHANGELOG.md")
	local top = ("\n" .. log):match("\n## 1%.11%.0\n(.-)\n## 1%.10%.1\n")   -- (by design since 1.12.0-beta1: 1.12.0's section now leads the file)
	check(top ~= nil, "the changelog has 1.11.0, above 1.10.1")
	top = top or ""
	local flat = top:gsub("\n  ", " ")
	check(flat:find("\n- See what the Disenchant Helper holds back: a Held Back line at the end of its list shows those items when you click it, each with a lock, its reason and its vendor, auction and materials values.", 1, true),
		"New: what the Helper holds back, shown from the Held Back line")
	check(flat:find("Disenchant Anyway puts one piece in the list when you would rather decide for yourself (asked first for a favorite, a gear set piece, an epic, your Exclusion List, and refundable or tradeable items), and Hold Back takes it out again.", 1, true),
		"Disenchant Anyway and Hold Back, by the names on their buttons, with what is asked first")
	check(flat:find("An offer is for that one piece and ends when you close the Helper.", 1, true), "and how long an offer lasts")
	check(flat:find("The sold-instead lines count disenchants from this version on, compare only the ones whose materials BagSmith saw, take the auction house's 5% cut off both sides, and name no winner when an item had no auction price at the time.", 1, true),
		"Disenchant Results: what its comparison counts, the cut, and when it names no winner")
	check(flat:find("The Helper's own count now says how many you disenchanted just now and how many this session.", 1, true), "the Helper's two counts, as before")
	check(not top:find("Offer Anyway"), "the button's earlier name (beta6 and beta7) is nowhere in it")
	-- the three headings, once each and in order, and thirteen entries
	local a, b, c = top:find("^\nNew:\n"), top:find("\n\nChanged:\n"), top:find("\n\nFixed:\n")
	check(a and b and c and a < b and b < c, "New, Changed, Fixed, in that order")
	local entries = 0
	for _ in ("\n" .. top):gmatch("\n%- ") do entries = entries + 1 end
	check(entries == 13, "thirteen entries (six new, six changed, one fixed)")
	local long, dash = false, false
	for line in (top .. "\n"):gmatch("(.-)\n") do
		if #line > 120 then long = true end
		if line:find("\226\128\148") or line:find("\226\128\147") then dash = true end
	end
	check(not long, "no line over 120 characters")
	check(not dash, "no em or en dashes")
	check(not log:find("## 1%.11%.0%-beta") and not log:find("## 1%.11%.0%-rc"), "one 1.11.0 section, no beta entries")
end

do
	-- the names the changelog uses are the ones on the Helper's buttons and band
	local src = slurp("BagSmith/Core/Disenchant.lua")
	check(src:find('ns.TextButton(f.cur, "Disenchant Anyway"', 1, true) and src:find('ns.TextButton(f.cur, "Hold Back"', 1, true) and src:find('"Held Back (%d)"', 1, true),
		"Disenchant Anyway, Hold Back and Held Back are what the Helper itself says")
end

do
	-- (by design since 1.12.0-beta1) This block was the production gate's own check, on 1.11.0's source: the TOC said
	-- 1.11.0 with no beta mark. The next release's betas carry one, so that half can only hold on a production
	-- build; what still holds on every build is that the TOC is at 1.11.0 or later and has no development marker.
	-- The exact version is pinned in tests/run.lua.
	local toc = slurp("BagSmith/BagSmith.toc")
	check(toc:find("\n## Version: 1%.1[1-9]%.%d"), "the TOC's version is 1.11.0 or later")
	check(not toc:find("X%-BagSmith%-Dev"), "and no development marker")
end
