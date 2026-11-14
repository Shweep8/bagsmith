-- 1.7.2-beta2: Soul Shards never leave the bags (Shweep: they can't be mailed, traded, sold or banked), so a merged
-- shard row right-clicked at the bank, the mailbox or a trade starts no follow-up (beta1 added a "Moved 0 of 6" line).
-- Through the item button's own right-click hook. The setup is the beta1 set's.
;(function()
	-- ======== 1.7.2-beta1: Soul Shards merged by Merge Stacks (a player's request via Shweep) ========
	-- The game keeps one Soul Shard to a slot (stack size 1), so Merge Stacks used to show every one. Every shard is
	-- the same, so they now show once with the total. Nothing wider: other one-to-a-slot items keep their own rows.
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0], M.sizes[1], M.sizes[2], M.sizes[3], M.sizes[4], M.sizes[5] = 8, 4, 4, 0, 0, 0
	M.maxStack = { [6265] = 1, [4632] = 1 }
	local function shard() return { id = 6265, name = "Soul Shard", q = 1, class = 15, subclass = 0, price = 0 } end
	-- bag 1 is a soul bag (3 shards); bag 2 an ordinary bag (2 shards); the backpack: 1 shard, two lockboxes, cloth
	for s = 1, 3 do M.put(1, s, shard()) end
	M.put(2, 1, shard()); M.put(2, 2, shard())
	M.put(0, 1, shard())
	M.put(0, 2, { id = 4632, name = "Ornate Bronze Lockbox", q = 1, class = 15, subclass = 0, price = 1 })
	M.put(0, 3, { id = 4632, name = "Ornate Bronze Lockbox", q = 1, class = 15, subclass = 0, price = 1 })
	M.put(0, 4, { id = 2589, name = "Linen Cloth", q = 1, count = 10, class = 7, subclass = 5, price = 1 })
	M.put(0, 5, { id = 2589, name = "Linen Cloth", q = 1, count = 4, class = 7, subclass = 5, price = 1 })
	_G.UnitClass = function() return "Warlock", "WARLOCK" end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local realFree = C_Container.GetContainerNumFreeSlots
	C_Container.GetContainerNumFreeSlots = function(bag) local free = realFree(bag); return free, bag == 1 and 4 or 0 end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers()
	local main = n.Window.main
	local function rows(id)
		local out = {}
		for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then out[#out + 1] = b end end
		return out
	end
	n:Set("view", "list"); n:Set("grp", "type"); n:Set("mergeStacks", true); n:RefreshViews(true); M.runTimers()
	local D = n.Drop
	local started = 0
	local realRest = D.MoveRestJob
	D.MoveRestJob = function(self, job) started = started + 1; return realRest(self, job) end
	local mark = 0
	local function rightClick(id)
		mark = #M.log
		local b = rows(id)[1]
		b:GetScript("OnClick")(b, "RightButton")
		for _ = 1, 20 do M.runTimers() end
	end
	local function said() local o = {} for i = mark + 1, #M.log do o[#o + 1] = M.log[i] end return table.concat(o, "|") end
	-- at the bank: the game refuses the shard; BagSmith starts no follow-up and adds no line
	n.atBank = true
	rightClick(6265)
	check(started == 0 and D.active == nil and not said():find("Moved 0 of", 1, true),
		"a right-click on the merged shards at the bank: no follow-up, no \"Moved 0 of\" line")
	-- a merged stackable item still has its follow-up there
	rightClick(2589)
	check(started == 1, "a merged stack of cloth still starts its follow-up at the bank")
	n.atBank = false
	-- the mailbox's send form and a trade: the same for shards
	_G.MailFrame = CreateFrame("Frame", "MailFrame", UIParent); _G.SendMailFrame = CreateFrame("Frame", "SendMailFrame", MailFrame)
	MailFrame:Show(); SendMailFrame:Show()
	started = 0
	rightClick(6265)
	check(started == 0 and not said():find("Moved 0 of", 1, true), "at the mailbox: no follow-up for the shards")
	MailFrame:Hide(); _G.MailFrame, _G.SendMailFrame = nil, nil
	_G.TradeFrame = CreateFrame("Frame", "TradeFrame", UIParent); TradeFrame:Show()
	rightClick(6265)
	check(started == 0, "in a trade: no follow-up for the shards")
	TradeFrame:Hide(); _G.TradeFrame = nil
	D.MoveRestJob = realRest
	_G.UnitClass = function() return "Warrior", "WARRIOR" end
	C_Container.GetContainerNumFreeSlots = realFree
	_G.BagSmithDB = nil
end)()
