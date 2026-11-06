;(function()
	-- 1.4.1-beta4 (Shweep's feedback): Shift-click didn't split a stack in an individual bag window. Those windows'
	-- slots are BagSmith's own buttons; Shift-click now behaves like the game's bags: a link into an open chat box,
	-- otherwise the split-stack box; a modified click never picks the item up.
	package.loaded.mock = nil
	local M = require("mock")
	M.put(1, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 12, stack = 20, class = 7, subclass = 5, price = 1 })
	M.put(1, 2, { id = 9001, name = "Azure Ring", q = 3, count = 1, class = 4, subclass = 0, price = 50, equip = "INVTYPE_FINGER" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local opened, splits, picked = nil, {}, {}
	_G.StackSplitFrame = { OpenStackSplitFrame = function(_, max, parent, a, b) opened = { max = max, parent = parent, a = a, b = b } end }
	C_Container.SplitContainerItem = function(bag, slot, count) splits[#splits + 1] = bag .. ":" .. slot .. "x" .. count end
	local realPick = C_Container.PickupContainerItem
	C_Container.PickupContainerItem = function(bag, slot) picked[#picked + 1] = bag .. ":" .. slot; return realPick(bag, slot) end
	-- a slot of an individual bag window, as the window builds it
	local host = CreateFrame("Frame", nil, UIParent)
	local function slotButton(bag, slot, i)
		local b = n.Buttons:GetMirror(host, i); b:SetID(slot); b.bag = bag
		local rec; for _, r in ipairs(n.items) do if r.bag == bag and r.slot == slot then rec = r end end
		n.Buttons:Fill(b, rec)
		return b
	end
	local linen, ring = slotButton(1, 1, 1), slotButton(1, 2, 2)
	local mods = {}
	_G.IsModifiedClick = function(k) return mods[k] == true end

	-- Shift-click with no chat box open: the split box, for the stack's count
	mods = { CHATLINK = true, SPLITSTACK = true }
	_G.ChatEdit_InsertLink = function() return false end
	linen:GetScript("OnClick")(linen, "LeftButton")
	check(opened and opened.max == 12 and opened.parent == linen and #picked == 0, "Shift-click on a stack of 12 opens the split box, and picks nothing up")
	linen.SplitStack(linen, 5)
	check(splits[1] == "1:1x5", "choosing 5 splits 5 off that slot (" .. tostring(splits[1]) .. ")")
	-- with a chat box open: the link goes into chat instead
	opened = nil
	_G.ChatEdit_InsertLink = function(l) M.lastLink = l; return true end
	linen:GetScript("OnClick")(linen, "LeftButton")
	check(opened == nil and M.lastLink and M.lastLink:find("Linen", 1, true) and #picked == 0, "with a chat box open, Shift-click links the item instead")
	-- a single item: nothing to split, and no pick-up
	_G.ChatEdit_InsertLink = function() return false end
	ring:GetScript("OnClick")(ring, "LeftButton")
	check(opened == nil and #picked == 0, "Shift-click on a single item opens nothing and picks nothing up")
	-- in combat: no split (like picking up from these windows)
	_G.InCombatLockdown = function() return true end
	linen:GetScript("OnClick")(linen, "LeftButton")
	check(opened == nil, "in combat, no split box")
	_G.InCombatLockdown = function() return false end
	-- a plain click still picks the stack up
	mods = {}
	linen:GetScript("OnClick")(linen, "LeftButton")
	check(picked[1] == "1:1", "a plain click still picks the stack up (" .. tostring(picked[1]) .. ")")
end)()
