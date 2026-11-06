;(function()
	-- 1.3.0: the 1.2.0 audit's findings, asserting the corrected behavior (they fail on 1.2.0)
	package.loaded.mock = nil
	local M = require("mock")
	for s = 1, 3 do M.put(0, s, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 3 }) end
	-- a hand-edited saved file with impossible numbers beside a good record
	_G.BagSmithCharDB = { version = 1, firstSeen = {}, deResultsVersion = 3,
		deResults = { ["2:5:w"] = { n = math.huge, mats = { [10940] = 4 } }, ["2:3:a"] = { n = 4, mats = { [10940] = 0/0 } }, ["2:4:a"] = { n = 6, mats = { [10940] = -math.huge } },
			["3:5"] = { n = 2, mats = { [11138] = 2 }, seen = { [11138] = math.huge } } } }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", mergeStacks = true } } }
	_G.TradeFrame = CreateFrame("Frame", "TradeFrame", UIParent); TradeFrame:Hide()
	_G.MAX_TRADE_ITEMS = 7
	local tradeSlots = {}
	_G.GetTradePlayerItemInfo = function(i) local t = tradeSlots[i]; if t then return t.name, nil, t.count end end
	_G.GetTradePlayerItemLink = function(i) local t = tradeSlots[i]; return t and ("|Hitem:" .. t.id .. ":0|h[" .. t.name .. "]|h") end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	-- ---- finding 2: non-finite learned results are dropped on load
	local log = n.Disenchant:Log()
	check(log["2:5:w"] == nil and log["2:3:a"] == nil and log["2:4:a"] == nil, "learned records with an infinite count or a NaN or infinite material count are dropped")
	check(log["3:5"] and log["3:5"].n == 2 and log["3:5"].mats[11138] == 2 and log["3:5"].seen[11138] == nil, "a good record survives, minus a non-finite 'seen' count")
	-- ---- finding 1: a second right mouse-down while a trade job runs cannot rewrite that job's evidence
	n.Window:Show(); M.runTimers(); M.runTimers()
	local function woolButton() n:Scan(); M.runTimers(); n.Window.main:Refresh(true, "test"); M.runTimers(); for _, bt in ipairs(n.Buttons.all) do if bt:IsShown() and bt.rec and bt.rec.itemID == 2592 and bt.rec.merged then return bt end end end
	M.fire("TRADE_SHOW"); TradeFrame:Show(); tradeSlots = {}
	local used = {}
	local realUse = C_Container.UseContainerItem
	-- the game: a stack used in a trade locks in its bag slot and appears in the window
	C_Container.UseContainerItem = function(bag, slot)
		local it = M.bags[bag] and M.bags[bag][slot]
		if it and not it.locked then used[#used + 1] = bag .. ":" .. slot; it.locked = true; tradeSlots[#tradeSlots + 1] = { id = 2592, name = "Wool Cloth", count = 20 } end
	end
	local btn = woolButton()
	check(btn ~= nil, "(setup) a merged Wool Cloth row in the bags")
	btn:GetScript("OnMouseDown")(btn, "RightButton")            -- the baseline: none in the trade yet
	C_Container.UseContainerItem(btn.rec.bag, btn.rec.slot)      -- the game places the clicked stack
	used = {}
	btn:GetScript("OnClick")(btn, "RightButton")                 -- BagSmith accepts the follow-up job
	check(n.Drop.active ~= nil, "(the first click's job is running)")
	-- before the job's first check, another right mouse-down and click arrive
	btn:GetScript("OnMouseDown")(btn, "RightButton")            -- would note one Wool in the trade
	btn:GetScript("OnClick")(btn, "RightButton")
	local refused = false; for _, l in ipairs(M.log) do if l:find("Still moving Wool Cloth", 1, true) then refused = true end end
	check(refused, "the second click is refused while the first job runs")
	for _ = 1, 14 do M.runTimers() end
	local nothing = false; for _, l in ipairs(M.log) do if l:find("nothing moved", 1, true) then nothing = true end end
	check(#used == 2 and not nothing, "the first job keeps its own evidence: both followers move and nothing claims 'nothing moved' (" .. #used .. " followed)")
	M.fire("TRADE_CLOSED"); TradeFrame:Hide()
	C_Container.UseContainerItem = realUse
end)()
