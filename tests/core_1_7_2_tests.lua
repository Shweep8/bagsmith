-- 1.7.2: the 1.7.2-beta2 audit's F1: at the bank a merged Soul Shard row's tooltip promised "Right-click: move all N
-- stacks", which the follow-up deliberately doesn't do. The hint and the move now ask the same check (ns.CanMoveRest).
-- Through the real tooltip extras on the view's own row buttons. The setup is the 1.7.2-beta1 set's.
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
	local function rowButton(id)
		for _, b in ipairs(main.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then return b end end
	end
	n:Set("view", "list"); n:Set("grp", "type"); n:Set("mergeStacks", true); n:RefreshViews(true); M.runTimers()
	local function hint(id)
		local b = rowButton(id)
		local lines = {}
		local realTip = n.TipLine
		n.TipLine = function(_, line) lines[#lines + 1] = line end
		n.Buttons.AddTooltipExtras({ GetOwner = function() return b end })
		n.TipLine = realTip
		return table.concat(lines, "\n"):match("Right%-click: move all %d+ stacks")
	end
	n.atBank = true
	check(rowButton(6265) and rowButton(6265).rec.merged and not hint(6265), "at the bank, the merged shards' tooltip has no \"move all\" hint")
	check(hint(2589) == "Right-click: move all 2 stacks", "a merged stack of cloth keeps its hint")
	check(n.CanMoveRest and n.CanMoveRest(2589) and not n.CanMoveRest(6265), "one check answers for both the hint and the move")
	n.atBank = false
	check(not hint(2589), "away from the bank, no hint (as before)")
	_G.UnitClass = function() return "Warrior", "WARRIOR" end
	C_Container.GetContainerNumFreeSlots = realFree
	_G.BagSmithDB = nil
end)()
