-- (by design since 1.10.0-beta12: the 1.10 card leads What's New, so every older entry is one place further down)
-- ======== 1.9.7-beta1 (Shweep, 21 Nov) ========
-- "noticed that w/ cleanup turned on when bags open that junk color (maybe others) don't show up at first when the bags
-- open" and "we prob should not auto-cleanup bags when you visit a vendor and are selling junk automatically" ("any
-- vendor makes sense"). (1) The game locks and unlocks an item as it moves, every item a Clean Up touches; on the
-- unlock BagSmith set the icon's grey to the lock state alone, so a dimmed junk icon got its color back until the next
-- redraw (spaced out on purpose during a Clean Up). (2) Clean Up Bags When Opened no longer runs at a vendor.

-- The game's own helper: the mock's is a no-op. "modern" sets the grey only; "older" resets the icon's color too.
local HELPERS = {
	modern = function(b, on) local icon = b and b.icon; if icon then icon:SetDesaturated(on) end end,
	older = function(b, on)
		local icon = b and b.icon
		if not icon then return end
		icon:SetDesaturated(on)
		if on then icon:SetVertexColor(0.5, 0.5, 0.5) else icon:SetVertexColor(1, 1, 1) end
	end,
}
local function boot(prof, helper, marks)
	package.loaded.mock = nil
	local M = require("mock")
	_G.SetItemButtonDesaturated = HELPERS[helper or "modern"]
	M.sizes[1] = 16
	M.put(0, 1, { id = 90001, name = "Broken Fang", q = 0, count = 3, class = 15, subclass = 0, price = 5 })
	M.put(0, 2, { id = 90002, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 13 })
	M.put(0, 3, { id = 90003, name = "Bent Spoon", q = 1, count = 1, class = 15, subclass = 0, price = 7 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {}, junkMarks = marks or { [90003] = true } }
	local p = { view = "icon", dimJunk = true }
	for k, v in pairs(prof or {}) do p[k] = v end
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
	local n = M.loadAddon("BagSmith")
	n.version = "1.9.7-beta1"
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_LOGIN"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	return n, M
end
local function lock(M, slot, on) M.bags[0][slot].locked = on; M.fire("ITEM_LOCK_CHANGED", 0, slot) end
local function dimmed(n, b)
	local J, c = n.Junk, b.icon.color or {}
	return b.dimmedJunk == true and b.icon.desaturated == true and c[1] == J.SEPIA[1] and c[2] == J.SEPIA[2] and c[3] == J.SEPIA[3] and b.icon.alpha == J.DIM_ALPHA
end

for _, view in ipairs({ "icon", "list" }) do
	for _, helper in ipairs({ "modern", "older" }) do
		local n, M = boot({ view = view }, helper)
		local what = view .. " view, the game's " .. helper .. " helper: "
		n.Window:Show(); M.runTimers(); M.runTimers()
		local grey, plain, marked = n.Buttons:Get(0, 1), n.Buttons:Get(0, 2), n.Buttons:Get(0, 3)
		check(dimmed(n, grey) and dimmed(n, marked), what .. "a grey item and a marked one are dimmed when the bags open")
		check(not plain.dimmedJunk and not plain.icon.desaturated, what .. "an ordinary item isn't")
		-- the item moves: locked, then unlocked, with no redraw in between
		lock(M, 1, true)
		check(dimmed(n, grey), what .. "locked: still dimmed")
		lock(M, 1, false)
		check(dimmed(n, grey), what .. "unlocked: still dimmed, with no redraw (it used to get its color back)")
		lock(M, 3, true); lock(M, 3, false)
		check(dimmed(n, marked), what .. "the marked item too")
		-- an ordinary item: greyed while locked, its color back on the unlock, as before
		lock(M, 2, true)
		check(plain.icon.desaturated == true, what .. "an ordinary item is greyed while it's locked")
		lock(M, 2, false)
		check(plain.icon.desaturated == false, what .. "and gets its color back when it unlocks")
		-- the next redraw agrees
		M.fire("BAG_UPDATE", 0); M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
		check(dimmed(n, n.Buttons:Get(0, 1)) and not n.Buttons:Get(0, 2).icon.desaturated, what .. "after the next scan: the same")
		-- Dim Junk turned off: nothing is kept grey any more
		n:Set("dimJunk", false); M.runTimers(); M.runTimers()
		grey = n.Buttons:Get(0, 1)
		check(not grey.dimmedJunk and not grey.icon.desaturated, what .. "Dim Junk off: junk is drawn in color")
		lock(M, 1, true); lock(M, 1, false)
		check(grey.icon.desaturated == false, what .. "and an unlock leaves it in color")
		check((n.errors or 0) == 0, what .. "no errors")
	end
end

;(function()
	-- A Clean Up: every item is locked and unlocked while scans are spaced out; junk stays dimmed throughout
	local n, M = boot({})
	local sorts = 0
	C_Container.SortBags = function() sorts = sorts + 1 end
	n.Window:Show(); M.runTimers(); M.runTimers()
	n.Window.main:CleanUp()
	check(sorts == 1 and n.cleanupUntil ~= nil, "(a Clean Up is running)")
	local ok = true
	for _ = 1, 3 do
		for slot = 1, 3 do
			lock(M, slot, true); lock(M, slot, false)
			if not (dimmed(n, n.Buttons:Get(0, 1)) and dimmed(n, n.Buttons:Get(0, 3))) then ok = false end
		end
	end
	check(ok, "during a Clean Up, junk stays dimmed through every lock and unlock")
	check(n.Buttons:Get(0, 2).icon.desaturated == false, "and an ordinary item ends in color")
	-- KeepDim asks nothing of a button that isn't dimmed, or of nothing at all
	n.Junk:KeepDim(nil); n.Junk:KeepDim({}); n.Junk:KeepDim({ dimmedJunk = true })
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- Clean Up Bags When Opened: not at a vendor
	local n, M = boot({ cleanOnOpen = true, travelMode = false })
	local main = n.Window.main
	local sorts = 0
	C_Container.SortBags = function() sorts = sorts + 1 end
	local function open() main:Hide(); ToggleAllBags(); M.runTimers(); M.runTimers() end
	open()
	check(sorts == 1 and main:IsShown(), "on: opening the bags cleans up, as before")
	-- the vendor opens the bags by itself
	main:Hide()
	M.fire("MERCHANT_SHOW"); M.runTimers(); M.runTimers()
	check(main:IsShown(), "(a vendor opens the bags)")
	check(sorts == 1, "the bags opening at a vendor: no Clean Up")
	local cleaned = n.cleanedOnOpen
	open()
	check(sorts == 1 and n.cleanedOnOpen == cleaned, "opening them by hand while at the vendor: none either")
	-- the button still works there
	main:CleanUp()
	check(sorts == 2, "the Clean Up button still works at a vendor")
	n.cleanupUntil = nil
	-- leaving the vendor
	M.fire("MERCHANT_CLOSED"); M.runTimers(); M.runTimers()
	open()
	check(sorts == 3, "after leaving the vendor: opening the bags cleans up again")
	-- the other exceptions are as they were
	main:Hide(); M.combat = true; ToggleAllBags(); M.runTimers(); M.runTimers(); M.combat = false
	check(sorts == 3, "not during combat (as before)")
	main:Hide(); n.atBank = true; ToggleAllBags(); M.runTimers(); M.runTimers(); n.atBank = false
	check(sorts == 3, "not at the bank (as before)")
	-- and nowhere else is new: the mailbox and the auction house still get a Clean Up
	main:Hide(); M.fire("MAIL_SHOW"); M.runTimers(); M.runTimers()
	check(sorts == 4, "at the mailbox: as before, the bags open and clean up")
	M.fire("MAIL_CLOSED"); M.runTimers()
	-- off: never
	n:Set("cleanOnOpen", false)
	open()
	check(sorts == 4, "off: opening the bags doesn't clean up")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- The setting says so, word for word; no What's New entry for this patch; the changelog's section
	local n, M = boot({})
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("automation"); M.runTimers()
	local row
	for _, w in ipairs(P.pools.check or {}) do if w:IsShown() and w.key == "cleanOnOpen" then row = w end end
	check(row and row.help.text == "Tidies your bags each time you open them, except in combat, at the bank or at a vendor.", "the setting's description names the vendor, word for word")
	-- (by design since 1.9.8-beta1: 1.9.7 was published without a What's New entry, which Shweep wanted; 1.9.8 adds
	-- it, so this set, running as 1.9.7, sees none newer than 1.9.6's, and the entry itself is checked in 1.9.8's set)
	check(n.WhatsNew:Latest()[1].v == "1.9.7" and n.WhatsNew.ENTRIES[4].v == "1.9.7", "1.9.7's What's New entry (added in 1.9.8) is the newest this version sees")   -- (by design since 1.10.1: one more place down, after 1.10.1's entry)
	local f = io.open("BagSmith/CHANGELOG.md"); local log = f:read("*a"); f:close()
	local section = ("\n" .. log):match("\n(## 1%.9%.7\n.-)\n## 1%.9%.6\n") or ""
	check(section:find("Dim Junk") and section:find("at a vendor") and not section:find("\226\128\148") and not section:find("\226\128\147"), "the changelog's 1.9.7 section covers both, with no dashes")
	check((n.errors or 0) == 0, "no errors")
end)()
