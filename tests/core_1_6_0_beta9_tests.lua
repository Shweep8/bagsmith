;(function()
	-- 1.6.0-beta9: the 1.6.0-beta8 audit's B8 R1 (the Disenchant Helper's comparisons are exact: a tie is a tie, and
	-- counts as enough), and Shweep's look at the Quest Starter mark (a slight drop shadow for contrast).

	-- ---- B8 R1: ties and one copper either side, both margins
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true, deLeveling = "never" } } }
	_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function() return 1 end, GetAuctionPriceByItemID = function() return 1 end } } }
	_G.BlackthornesTS_API = nil
	local skill = { rank = 120, max = 150 }
	_G.GetNumSkillLines = function() return 1 end
	_G.GetSkillLineInfo = function() return "Enchanting", false, nil, skill.rank, 0, 0, skill.max end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE = n.Disenchant
	local function v(vendor, ah, mats) return DE:Verdict({ vendor = vendor, ah = ah, mats = mats }) end
	check(n.db.deMargin == 0.10 and n.db.deAhMargin == 0.20 and n.db.deLeveling == "never", "(setup) margins 10% and 20%, not leveling")
	-- the AH margin (20%): 24c after the cut is 22.8c, exactly 19c plus 20%
	check(v(19, 24, 0) == "ah", "the audit's tie: 19c at the vendor, 24c on the AH (22.8c after the cut, 19c plus 20% exactly): Sell at AH")
	check(v(19, 23, 0) == "vendor" and v(19, 25, 0) == "ah", "a copper either side: 23c Vendor, 25c Sell at AH")
	check(v(95, 120, 0) == "ah" and v(95, 119, 0) == "vendor", "another tie (95c, 1s 20c after the cut is 1s 14c) and a copper under")
	check(v(9500000, 12000000, 0) == "ah" and v(9500000, 11999999, 0) == "vendor", "large prices stay exact (950g against 1200g, and a copper under)")
	-- strictly more than the vendor, even at a 0% margin
	n:Set("deAhMargin", 0)
	check(v(19, 20, 0) == "vendor" and v(19, 21, 0) == "ah", "at 0%, 20c (19c after the cut) only ties the vendor's 19c: Vendor; 21c: Sell at AH")
	n:Set("deAhMargin", 0.20)
	-- the Disenchant margin (20%) with the same cut on both sides: the item's and the materials' ratio is kept
	n:Set("deMargin", 0.20)
	for _, pair in ipairs({ { 20, 24 }, { 40, 48 }, { 80, 96 }, { 100, 120 }, { 200, 240 } }) do
		check(v(0, pair[1], pair[2]) == "de", ("AH %dc, materials %dc, 20%%: the same ratio after the cut, so Disenchant (as beta7 said)"):format(pair[1], pair[2]))
	end
	check(v(0, 20, 23) == "ah" and v(0, 20, 25) == "de", "a copper either side of 20c and 24c: 23c Sell at AH, 25c Disenchant")
	-- the Disenchant margin (10%) against the vendor: 22c of materials is 20.9c after the cut, exactly 19c plus 10%
	n:Set("deMargin", 0.10)
	check(v(19, 0, 22) == "de" and v(19, 0, 21) == "vendor" and v(19, 0, 23) == "de", "19c at the vendor, materials 22c (a tie at 10%): Disenchant; 21c Vendor; 23c Disenchant")
	-- nothing from nothing
	check(v(0, 0, 0) == "vendor", "no materials value: never Disenchant, even at 0c against 0c")
	-- leveling: materials at full value, no margin: a tie is enough
	n:Set("deLeveling", "always")
	-- (1.6.0-beta10, by design: Shweep) leveling allows up to 10% less than selling; the ties move with it
	check(v(100, 0, 90) == "de" and v(100, 0, 89) == "vendor", "leveling: 90c of materials against 1s at the vendor is enough (the 10% tie); 89c isn't")
	check(v(0, 20, 18) == "de" and v(0, 20, 17) == "ah", "leveling: 18c of materials against 20c on the AH (19c after the cut, 17.1c less 10%) is enough; 17c isn't")
	n:Set("deLeveling", "never")
	-- margins are whole percents (the Settings steps are 5%); a saved value off the step rounds to the nearest one
	n.db.deAhMargin = 0.2000000001
	check(v(19, 24, 0) == "ah", "a saved 20.00000001% counts as 20%: still the tie")
	n.db.deAhMargin = 0.196
	check(v(19, 24, 0) == "ah", "19.6% counts as 20%")
	n.db.deAhMargin = 0.20
	-- unchanged: a missing material price, no price addon
	check(DE:Verdict({ vendor = 19, ah = 24, mats = nil }) == "unknown", "a missing material price is still No price yet")
	_G.Auctionator = nil; n.AH:CheckSource(); M.runTimers()
	check(v(19, 24, 22) == "call", "no price addon: still Your call")
end)()

;(function()
	-- ---- the Quest Starter mark's shadow
	local quests = { [1] = { questID = 101, isActive = false }, [2] = { questID = 102, isActive = true } }
	local function bootQ(prof)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 3000, name = "Torn Note", q = 1, count = 1, class = 12, subclass = 0, price = 0 })
		M.put(0, 2, { id = 3001, name = "Bloody Tusk", q = 1, count = 1, class = 12, subclass = 0, price = 0 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local pr = { view = "icons" }
		for k, val in pairs(prof or {}) do pr[k] = val end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = pr } }
		_G.Auctionator = nil; _G.BlackthornesTS_API = nil
		local n = M.loadAddon("BagSmith")
		C_Container.GetContainerItemQuestInfo = function(bag, slot) return quests[slot] or { isQuestItem = false } end
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); M.runTimers(); M.runTimers()
		return n, M
	end
	local function btn(n, id) for _, b in ipairs(n.Window.main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then return b end end end
	for _, skin in ipairs({ "modern", "classic" }) do
		for _, view in ipairs({ "icons", "list" }) do
			local who = skin .. " " .. view
			quests[1] = { questID = 101, isActive = false }
			local n, M = bootQ({ skin = skin, view = view })
			local C = n.Corners
			local b1, b2 = btn(n, 3000), btn(n, 3001)
			if b1 then C:Apply(b1, true) end; if b2 then C:Apply(b2, true) end
			local mk, sh = b1 and b1.questMark, b1 and b1.questShade
			check(mk and mk:IsShown() and sh and sh:IsShown(), who .. ": the mark shows, with its shadow")
			check(sh and sh.texture == C.QUEST_ART and sh.color and sh.color[1] == 0 and sh.color[2] == 0 and sh.color[3] == 0 and sh.color[4] == 0.8,
				who .. ": the shadow is the same art in black at 80%")
			check(sh and sh.layer == "OVERLAY" and mk.layer == "OVERLAY" and sh.sublayer == 5 and mk.sublayer == 6, who .. ": just under the mark")
			local p1 = sh and { sh:GetPoint(1) } or {}
			local p2 = sh and { sh:GetPoint(2) } or {}
			check(sh and sh:GetNumPoints() == 2 and p1[1] == "TOPLEFT" and p1[2] == mk and p1[3] == "TOPLEFT" and p1[4] == 1 and p1[5] == -1
				and p2[1] == "BOTTOMRIGHT" and p2[2] == mk and p2[3] == "BOTTOMRIGHT" and p2[4] == 1 and p2[5] == -1,
				who .. ": 1 px down and right of the mark by two corners, so it follows the mark's size and corner")
			check(not (b2 and b2.questShade and b2.questShade:IsShown()), who .. ": no shadow on an item that isn't a quest starter")
			-- moved to another corner: the shadow comes along (it's anchored to the mark)
			C:PlaceAt("quest_start", "bottom_left"); C:Apply(b1, true)
			check(mk:IsShown() and sh:IsShown() and select(2, sh:GetPoint(1)) == mk, who .. ": moved to the bottom left, the shadow comes along")
			-- the quest accepted: mark and shadow go
			quests[1] = { questID = 101, isActive = true }
			M.fire("BAG_UPDATE_DELAYED"); M.runTimers(); M.runTimers()
			b1 = btn(n, 3000)
			if b1 then C:Apply(b1, true) end
			check(b1 and not (b1.questMark and b1.questMark:IsShown()) and not (b1.questShade and b1.questShade:IsShown()), who .. ": once the quest is accepted, mark and shadow both go")
		end
	end
	-- the Icon Corners preview shows the shadow too
	quests[1] = { questID = 101, isActive = false }
	local n = bootQ({ skin = "modern" })
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("icons")
	local b = P.pools.cornerCards[1].preview
	check(b and b.previewShown.top_left == "quest_start" and b.questMark:IsShown() and b.questShade and b.questShade:IsShown(), "the Icon Corners preview shows the mark with its shadow")
	n.Corners:PlaceAt("quest_start", "top_right"); n.Corners:DrawPreview(b, "cell")
	check(b.previewShown.top_right == "quest_start" and b.questShade:IsShown() and select(2, b.questShade:GetPoint(1)) == b.questMark, "moved on the preview, the shadow follows")
	P:Hide()
end)()
