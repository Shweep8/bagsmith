;(function()
	-- 1.6.0-beta10: the 1.6.0-beta9 audit's findings (B9 R1 an emptied slot keeping the quest mark and its shadow; B9 R2 a
	-- 14.5% margin used as 14%; B9 A1 a fractional price missing a tie), and Shweep's changes: a 10% leeway while leveling
	-- Enchanting, its wording, and What's New's Smarter Disenchant Advice.

	-- ---- B9 R1: an emptied slot shows no quest mark or shadow
	local quests
	local function boot(skin, view, empty)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 3000, name = "Torn Note", q = 1, count = 1, class = 12, subclass = 0, price = 0 })
		M.put(0, 2, { id = 3001, name = "Linen Cloth", q = 1, count = 4, class = 7, subclass = 5, price = 1 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, view = view, emptySlots = empty, grp = "none" } } }
		_G.Auctionator = nil; _G.BlackthornesTS_API = nil
		quests = { [1] = { questID = 101, isActive = false } }
		local n = M.loadAddon("BagSmith")
		C_Container.GetContainerItemQuestInfo = function(bag, slot) return bag == 0 and quests[slot] or { isQuestItem = false } end
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); M.runTimers(); M.runTimers()
		return n, M
	end
	local function shows(b) return b.questMark and b.questMark:IsShown() or false, b.questShade and b.questShade:IsShown() or false end
	for _, skin in ipairs({ "modern", "classic" }) do
		-- Icons view with empty slots shown: the slot stays on screen, empty
		local n, M = boot(skin, "icons", true)
		local b = n.Buttons:Get(0, 1); n.Corners:Apply(b, true)
		local mk, sh = shows(b)
		check(mk and sh, skin .. " icons, empty slots shown: (setup) the quest starter wears the mark and its shadow")
		M.bags[0][1] = nil; quests[1] = nil
		M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
		mk, sh = shows(b)
		check(b:IsShown() and not b.hasItem and not mk and not sh, skin .. " icons: the item gone, its empty square shows neither the mark nor the shadow")
		M.put(0, 1, { id = 3002, name = "Stained Map", q = 1, count = 1, class = 12, subclass = 0, price = 0 }); quests[1] = { questID = 102, isActive = false }
		M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
		b = n.Buttons:Get(0, 1); n.Corners:Apply(b, true)
		mk, sh = shows(b)
		check(b.hasItem and mk and sh, skin .. " icons: another quest starter in that slot wears them again")
		local c = n.Buttons:Get(0, 2); n.Corners:Apply(c, true)
		mk, sh = shows(c)
		check(not mk and not sh, skin .. " icons: (and the cloth beside it never did)")
		-- blanked in combat, in both views
		for _, view in ipairs({ "icons", "list" }) do
			n, M = boot(skin, view, false)
			b = n.Buttons:Get(0, 1); n.Corners:Apply(b, true)
			mk, sh = shows(b)
			check(mk and sh, skin .. " " .. view .. ": (setup) the mark and its shadow")
			M.combat = true; M.fire("PLAYER_REGEN_DISABLED")
			M.bags[0][1] = nil; quests[1] = nil
			M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
			mk, sh = shows(b)
			check(not b.hasItem and not mk and not sh, skin .. " " .. view .. ": the item gone in combat, the blanked slot shows neither")
			M.combat = false; M.fire("PLAYER_REGEN_ENABLED"); M.runTimers(); M.runTimers()
			mk, sh = shows(b)
			check(not (b:IsVisible() and (mk or sh)), skin .. " " .. view .. ": nor after combat")
		end
	end
	-- blanking makes nothing new: it only hides what's there
	do
		local n, M = boot("modern", "icons", true)
		local c = n.Buttons:Get(0, 2)
		local before = #(c.regions or {})
		M.bags[0][2] = nil
		M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
		check(not c.hasItem and #(c.regions or {}) == before, "emptying a slot makes no new textures (" .. before .. " before, " .. #(c.regions or {}) .. " after)")
	end
end)()

;(function()
	-- ---- the Disenchant Helper: fractional prices (B9 A1), off-step margins (B9 R2), the leveling leeway
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true, deLeveling = "never" } } }
	local quote = 8.8
	_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function() return quote end, GetAuctionPriceByItemID = function() return quote end } } }
	_G.BlackthornesTS_API = nil
	local skill = { rank = 120, max = 150 }
	_G.GetNumSkillLines = function() return 1 end
	_G.GetSkillLineInfo = function() return "Enchanting", false, nil, skill.rank, 0, 0, skill.max end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE = n.Disenchant
	local function v(vendor, ah, mats) return DE:Verdict({ vendor = vendor, ah = ah, mats = mats }) end
	-- B9 A1: compared to a hundredth of a copper
	n:Set("deMargin", 0.25)
	check(v(0, 8.8, 11) == "de", "the audit's case: 8.8c on the AH, 11c of materials at 25% is an exact tie: Disenchant")
	check(v(0, 8.8, 10.99) == "ah" and v(0, 8.81, 11) == "ah", "a hundredth of a copper either side: Sell at AH")
	check(n.AH:Price({ itemID = 7001, link = "item:7001" }) == 8.8, "the quote itself isn't rounded: the AH column and the Loot Helper see 8.8c, as before")
	n:Set("deMargin", 0.10)
	-- B9 R2: margins off the steps round half up
	n:Set("deMargin", 0.145)
	check(n.db.deMargin == 0.145, "an imported 14.5% is kept as saved")
	check(v(95, 0, 114) == "vendor", "and counts as 15%: 95c at the vendor, 1s 14c of materials (1s 08c after the cut) is short of it")
	n:Set("deMargin", 0.144)
	check(v(95, 0, 114) == "de", "14.4% counts as 14%: the same item is a tie, so Disenchant")
	n:Set("deMargin", 0.155)
	check(v(95, 0, 115) == "vendor" and v(95, 0, 116) == "de", "15.5% counts as 16%: 1s 15c short, 1s 16c enough")
	n:Set("deMargin", 0.10)
	n:Set("deAhMargin", 0.145)
	check(v(95, 114, 0) == "vendor", "an AH margin of 14.5% counts as 15%: 1s 14c on the AH (1s 08c after the cut) against 95c is short")
	n:Set("deAhMargin", 0.144)
	check(v(95, 114, 0) == "ah", "14.4% counts as 14%: a tie, so Sell at AH")
	n:Set("deAhMargin", 0.20)
	check(v(19, 24, 0) == "ah" and v(19, 23, 0) == "vendor", "(the beta8 audit's tie still holds, and a copper under)")
	-- Shweep's 10% leeway while leveling
	n:Set("deLeveling", "auto")
	check(DE:Leveling() == true, "(setup) Enchanting 120 of 150: leveling")
	check(v(100, 0, 90) == "de" and v(100, 0, 89) == "vendor", "leveling: 90c of materials against 1s at the vendor is enough (10% less); 89c isn't")
	check(v(0, 20, 18) == "de" and v(0, 20, 17) == "ah", "leveling: 18c against 20c on the AH (19c after the cut; 17.1c is 10% less) is enough; 17c isn't")
	check(v(10, 0, 9) == "de" and v(10, 0, 8.99) == "vendor", "leveling: 9c against 10c is the tie; a hundredth under isn't")
	check(v(2000000000, 0, 1800000000) == "de" and v(2000000000, 0, 1799999999) == "vendor", "near the gold cap: 180,000g against 200,000g is the tie, a copper under isn't")
	check(v(0, 0, 0) == "vendor" and v(0, 0, 1) == "de", "leveling: nothing from nothing; any materials against nothing to sell")
	n:Set("deLeveling", "never")
	check(v(100, 0, 90) == "vendor" and v(100, 0, 116) == "de" and v(100, 0, 115) == "vendor", "Never: the 10% margin after the cut, as before (1s 16c enough, 1s 15c not)")
	n:Set("deLeveling", "always")
	skill.rank = 300
	check(v(100, 0, 90) == "de", "Always: the leeway at any skill")
	n:Set("deLeveling", "auto")
	check(v(100, 0, 90) == "vendor", "Automatic at 300: no leeway")
	-- the wording
	local P = n.SettingsPanel
	P:Show(); M.runTimers(); P:ShowPage("dehelper"); M.runTimers()
	local help
	for _, w in ipairs(P.pools.seg or {}) do if w:IsShown() and w.key == "deLeveling" then help = w.help and w.help.text end end
	check(help == "While you're leveling, materials count at full value and disenchanting wins even when it's worth up to 10% less than selling. Automatic does this until your Enchanting reaches its current cap.",
		"Settings > Disenchant Helper: Leveling Enchanting's help (Shweep's wording): " .. tostring(help))
	P:Hide()
	-- What's New: the sixth bullet
	local e = n.WhatsNew.ENTRIES[2]   -- (1.7.0-beta6, by design) the 1.7 card leads now
	check(e.v == "1.6.0" and #e.items == 6 and e.items[6] == "|cfffac775Smarter Disenchant Advice:|r the Disenchant Helper counts the AH's cut and leans toward disenchanting while you level Enchanting (Settings > Disenchant Helper).",
		"What's New: the 1.6 card's sixth bullet, Smarter Disenchant Advice")
end)()
