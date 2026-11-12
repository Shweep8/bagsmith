;(function()
	-- 1.2.0-beta10: the six findings of the beta9 audit, each asserting the corrected behavior (they fail on beta9)
	package.loaded.mock = nil
	local M = require("mock")
	local DEID = 13262
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
	M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
	M.put(0, 3, { id = 7003, name = "Rare Chest", q = 3, count = 1, class = 4, subclass = 2, price = 2000, ilvl = 45, equip = "INVTYPE_CHEST" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
	_G.IsSpellKnown = function(id) return id == DEID end
	_G.GetSpellInfo = function(id) if id == DEID then return "Disenchant" end end
	_G.RegisterStateDriver = function() end
	local combat = false; _G.InCombatLockdown = function() return combat end
	_G.LOOT_ITEM_SELF = "You receive loot: %s."; _G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
	_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."; _G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
	local lootNow = {}
	_G.GetNumLootItems = function() return #lootNow end
	_G.GetLootSlotLink = function(i) return lootNow[i] and ("|Hitem:" .. lootNow[i][1] .. ":0|h[m]|h") end
	_G.GetLootSlotInfo = function(i) return nil, "m", lootNow[i] and lootNow[i][2] or 1 end
	local MATNAMES = { [10940] = "Strange Dust", [10939] = "Greater Magic Essence", [10978] = "Small Glimmering Shard", [11083] = "Soul Dust", [11082] = "Greater Astral Essence", [11138] = "Small Glowing Shard", [11177] = "Small Radiant Shard" }
	local realInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(link) local id = tonumber(tostring(link):match("item:(%d+)")) or link; if MATNAMES[id] then return MATNAMES[id] end return realInfo(link) end
	-- the game's popups, for the prompts finding
	local shown, clicks = {}, {}
	_G.StaticPopup_Show = function(which, arg) local f = _G["BagSmithTestPopup_" .. which] or CreateFrame("Frame", "BagSmithTestPopup_" .. which, UIParent); f.which = which; f.text = f.text or { text = "", GetText = function(t) return t.text end, SetText = function(t, v) t.text = v end }; f.text:SetText(arg or ""); f:Show(); shown[#shown + 1] = which; return f end
	_G.StaticPopup_Visible = function(which) local f = _G["BagSmithTestPopup_" .. which]; if f and f:IsShown() then return "BagSmithTestPopup_" .. which end end
	_G.StaticPopup_OnClick = function(dialog, index) clicks[#clicks + 1] = { dialog.which, index, dialog.text:GetText() }; dialog:Hide() end
	local shift = false; _G.IsShiftKeyDown = function() return shift end
	local clock = 1000; _G.GetTime = function() return clock end
	-- the mailbox and the trade window
	_G.MailFrame = CreateFrame("Frame", "MailFrame", UIParent); _G.SendMailFrame = CreateFrame("Frame", "SendMailFrame", MailFrame); MailFrame:Hide(); SendMailFrame:Hide()
	_G.TradeFrame = CreateFrame("Frame", "TradeFrame", UIParent); TradeFrame:Hide()
	_G.ATTACHMENTS_MAX_SEND = 12; _G.MAX_TRADE_ITEMS = 7
	local mailSlots, tradeSlots = {}, {}
	_G.GetSendMailItem = function(i) return mailSlots[i] end
	_G.GetTradePlayerItemInfo = function(i) return tradeSlots[i] end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local DE, P, D = n.Disenchant, n.Prompts, n.Drop
	-- ---- 1 (P1): a newly protected item is never disenchanted
	DE:Show(); DE:Refresh()
	local b = DE:Button()
	local function entryOf(id) for _, e in ipairs(DE.entries) do if e.itemID == id then return e end end end
	DE:Select(entryOf(7001))
	check(DE.current.itemID == 7001 and b:GetAttribute("type") == "spell" and b:GetAttribute("target-slot") == 1, "(setup) the boots are armed")
	n.Marks:ToggleFavorite(DE.current.rec); M.runTimers(); M.runTimers()
	check(DE.current == nil or DE.current.itemID ~= 7001, "favoriting the armed item re-judges the list at once: the boots are no longer the armed item")
	-- even without that refresh, the click itself checks the live item: arm the boots by force, then favorite
	n.Marks:ToggleFavorite({ itemID = 7001, name = "Sturdy Boots", link = "item:7001" })   -- (unfavorite)
	DE:Refresh(); DE:Select(entryOf(7001))
	local liveRec = DE.current.rec
	n.Marks:ToggleFavorite(liveRec)   -- favorite again; the SETTINGS_CHANGED refresh is what the audit found missing: simulate it missing by re-arming after
	DE:Arm(entryOf(7001) or { bag = 0, slot = 1, itemID = 7001, rec = liveRec, name = "Sturdy Boots" })
	check(b:GetAttribute("type") == "spell", "(setup) armed again while the item is a favorite")
	b:GetScript("PreClick")(b)
	check(b:GetAttribute("type") == nil and DE.castingEntry == nil and DE.current == nil and DE.lastDisarm == "that item is a favorite now", "the click disarms itself and arms nothing else inside the click: the live item is a favorite now (" .. tostring(DE.lastDisarm) .. ")")
	M.runTimers()
	check(DE.current ~= nil and DE.current.itemID ~= 7001 and b:GetAttribute("type") == "spell", "the next frame re-judges the list and arms another item")
	n.Marks:ToggleFavorite({ itemID = 7001, name = "Sturdy Boots", link = "item:7001" })
	-- the slot holding a different item than the armed one
	DE:Refresh(); DE:Select(entryOf(7002)); local armed = DE.current
	M.put(0, 2, { id = 7009, name = "Other Sword", q = 2, count = 1, class = 2, subclass = 7, price = 50, ilvl = 20, equip = "INVTYPE_WEAPON" })
	b:GetScript("PreClick")(b)
	check(b:GetAttribute("type") == nil and DE.castingEntry == nil and DE.lastDisarm == "that slot holds a different item now", "the slot holding another item than the armed one disarms the click")
	M.runTimers()
	M.put(0, 2, { id = 7002, name = "Worn Dagger", q = 2, count = 1, class = 2, subclass = 15, price = 800, ilvl = 33, equip = "INVTYPE_WEAPON" })
	n:Scan(); M.runTimers()
	-- a gear-set change re-judges too
	DE:Refresh(); DE:Select(entryOf(7002))
	local okLive = DE:LiveCheck(DE.current)
	check(okLive == true, "(control) the dagger passes the live check")
	local realAvail, realSetsAt = n.GearSets.Available, n.GearSets.SetsAt
	n.GearSets.Available = function() return true end; n.GearSets.SetsAt = function() return { "Tank" } end
	check(select(2, DE:LiveCheck(DE.current)) == "that item is in a gear set now", "an item the game now reports in a gear set fails the live check")
	n.GearSets.Available = realAvail; n.GearSets.SetsAt = realSetsAt
	M.fire("EQUIPMENT_SETS_CHANGED"); M.runTimers()
	check(DE.frame:IsShown(), "(a gear-set change refreshes the open helper without error)")
	-- a locked slot and an unreadable bag fail closed
	M.bags[0][2].locked = true
	check(select(2, DE:LiveCheck(DE.current)) == "that item is locked right now", "a locked slot fails the live check")
	M.bags[0][2].locked = nil
	local realGCII = C_Container.GetContainerItemInfo; C_Container.GetContainerItemInfo = nil
	check(DE:LiveCheck(DE.current) == false, "a bag that cannot be read fails closed")
	C_Container.GetContainerItemInfo = realGCII
	-- in combat the attributes are frozen and the state driver has blanked the button: PreClick leaves them alone
	combat = true; DE:Select(entryOf(7002)); b:GetScript("PreClick")(b); combat = false
	check(true, "(in combat PreClick changes nothing: no error)")
	-- ---- 4 and 5 (P2): loot attribution takes only materials, once per cast whichever source speaks first
	DE:Refresh(); DE:Select(entryOf(7002)); b:GetScript("PreClick")(b)
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", DEID)
	local c = DE.castOpen; local key = c.key
	M.fire("CHAT_MSG_LOOT", "You receive loot: |cff1eff00|Hitem:7004:0:0:0:0:0:0:0|h[Epic Blade]|h|r.")
	check(DE:Log()[key].mats[7004] == nil and (DE.session.mats[7004] == nil), "a pickup that is not a disenchant material is never attributed to the cast")
	M.fire("CHAT_MSG_LOOT", "You receive loot: |cff1eff00|Hitem:11082:0:0:0:0:0:0:0|h[Greater Astral Essence]|h|rx2.")
	lootNow = { { 11082, 2 } }; M.fire("LOOT_OPENED")
	check(DE:Log()[key].mats[11082] == 2 and DE:Log()[key].seen[11082] == 1 and DE.session.mats[11082] == 2, "the chat then the loot window reporting the same two essences count once, not four")
	M.fire("LOOT_CLOSED")
	check(DE.castOpen == nil, "the loot window closing ends the cast's attribution")
	M.fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:10940:0:0:0:0:0:0:0|h[Strange Dust]|h|rx5.")
	check(DE:Log()[key].mats[10940] == nil, "a material line after the attribution closed is not the cast's")
	-- the item leaving its slot closes attribution a second later
	DE:Refresh(); DE:Select(entryOf(7002)); b:GetScript("PreClick")(b)
	M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", DEID)
	M.bags[0][2] = nil; M.fire("BAG_UPDATE_DELAYED")
	check(DE.castOpen ~= nil, "right after the item leaves, loot lines are still the cast's")
	M.runTimers(); M.runTimers(); M.runTimers()
	check(DE.castOpen == nil, "a moment later the attribution closes")
	-- forgetting learned results
	check(DE:LearnedCount() == 2, "(two disenchants on record)")
	DE:ResetLearned()
	check(DE:LearnedCount() == 0 and next(DE:Log()) == nil, "Forget Learned Results empties the record")
	-- ---- 6 (P2): the minimum width fits the columns
	local cols = DE:Columns(DE.MIN_W)
	check(DE.MIN_W >= 612 and cols[#cols][2] + cols[#cols][3] <= DE.MIN_W - 44, "at the minimum width the last column ends inside the list")
	n.db.deSize = { 520, 400 }; DE.frame:Hide(); DE:Show()
	check(DE.frame:GetWidth() == DE.MIN_W, "a saved width below the new minimum is raised to it")
	DE.frame:Hide()
	-- ---- 2 (P2): the deferred confirm re-decides and stays with the box it saw
	n:Set("autoConfirm", true)
	local function box(which, text) local f = StaticPopup_Show(which, text); return f end
	n.MarkAction("gear set"); box("EQUIP_BIND", "Bind Sturdy Boots?"); shift = true; M.runTimers(); M.elapse(); shift = false
	check(#clicks == 0 and P.last.why == "shift", "Shift pressed before the deferred click keeps the box open")
	n.MarkAction("gear set"); box("EQUIP_BIND", "Bind Sturdy Boots?"); n:Set("autoConfirmEquip", false); M.runTimers(); M.elapse(); n:Set("autoConfirmEquip", true)
	check(#clicks == 0 and P.last.why == "group-off", "the kind turned off before the deferred click keeps it open")
	-- the audit's case: the first box is replaced by another while Shift is held; the second's own decision says no
	n.MarkAction("gear set"); box("EQUIP_BIND", "Bind Sturdy Boots?")
	shift = true; local f2 = box("EQUIP_BIND", "Bind Rare Chest?")   -- the replacement, with Shift down
	M.runTimers(); M.elapse(); shift = false
	check(#clicks == 0 and P.last.why == "shift", "a replacement box shown under Shift is not confirmed by the first box's deferred click (" .. tostring(P.last.why) .. ")")
	f2:Hide()
	-- a replacement without Shift: only the replacement's own decision counts, and it is the one confirmed
	n.MarkAction("gear set"); box("EQUIP_BIND", "Bind Sturdy Boots?"); local f3 = box("EQUIP_BIND", "Bind Rare Chest?"); M.runTimers(); M.elapse()
	check(#clicks == 1 and clicks[1][3] == "Bind Rare Chest?", "a replacement allowed by its own decision is confirmed once, as itself")
	n.MarkAction("gear set"); box("EQUIP_BIND", "Bind Sturdy Boots?"); M.runTimers(); M.elapse()
	check(#clicks == 2 and clicks[2][3] == "Bind Sturdy Boots?", "(control) the same box, still allowed at click time, is confirmed")
	n:Set("autoConfirm", false)
	-- ---- 3 (P2): a transfer job dies with its mail or trade session
	for s = 1, 5 do M.put(0, s, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 3 }) end
	n:Set("mergeStacks", true); M.runTimers(); n.Window:Show(); M.runTimers(); M.runTimers()
	local function wool() n:Scan(); M.runTimers(); n.Window.main:Refresh(true, "test"); M.runTimers(); for _, bt in ipairs(n.Buttons.all) do if bt:IsShown() and bt.rec and bt.rec.itemID == 2592 and bt.rec.merged then return bt.rec end end end
	M.fire("MAIL_SHOW"); MailFrame:Show(); SendMailFrame:Show()
	local used = {}
	local realUse = C_Container.UseContainerItem
	-- (1.7.0-beta11, by design) an attached stack stays in its bag slot, locked, as in a trade; the clicked stack's
	-- placement is told from the mail's count at mouse-down
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; mailSlots[#mailSlots + 1] = "Wool Cloth"; M.bags[bag][slot].locked = true end
	local rec = wool()
	D:NoteTradeBaseline(rec)
	mailSlots[1] = "Wool Cloth"; M.bags[0][1].locked = true
	local members = {}; for _, m in ipairs(rec.members) do members[#members + 1] = { bag = m.bag, slot = m.slot, itemID = m.itemID, count = m.count } end
	D:MoveRest({ itemID = 2592, members = members, name = "Wool Cloth", where = "mail", first = { bag = 0, slot = 1 } })
	M.runTimers(); M.runTimers()   -- one stack follows
	-- the mail closes and a new one opens before the next step
	M.fire("MAIL_CLOSED"); MailFrame:Hide(); SendMailFrame:Hide(); mailSlots = {}
	M.fire("MAIL_SHOW"); MailFrame:Show(); SendMailFrame:Show()
	for _ = 1, 12 do M.runTimers() end
	check(#used <= 2 and #mailSlots == 0, "a job started in one mail never continues into the next (" .. #used .. " followed, the new mail has " .. #mailSlots .. ")")
	M.fire("MAIL_CLOSED"); MailFrame:Hide(); SendMailFrame:Hide()
	-- a trade: a lock alone is not proof the window took the stack
	for s = 1, 5 do M.put(0, s, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 3 }) end
	n:Scan(); M.runTimers(); rec = wool()
	M.fire("TRADE_SHOW"); TradeFrame:Show(); tradeSlots = {}
	used = {}
	C_Container.UseContainerItem = function(bag, slot) used[#used + 1] = bag .. ":" .. slot; M.bags[bag][slot].locked = true end   -- the lock, but the window did not take it
	D:NoteTradeBaseline({ itemID = 2592, name = "Wool Cloth" })   -- mouse-down with the trade empty
	tradeSlots[1] = "Wool Cloth"; M.bags[0][1].locked = true   -- the clicked stack placed
	members = {}; for _, m in ipairs(rec.members) do members[#members + 1] = { bag = m.bag, slot = m.slot, itemID = m.itemID, count = m.count } end
	D:MoveRest({ itemID = 2592, members = members, name = "Wool Cloth", where = "trade", first = { bag = 0, slot = 1 } })
	for _ = 1, 14 do M.runTimers() end
	check(#used == 1 and (M.log[#M.log] or ""):find("Moved 1 of 5 stacks", 1, true), "a stack that locks without the trade window gaining an item is not counted as placed, and the job stops (" .. tostring(M.log[#M.log]) .. ")")
	M.fire("TRADE_CLOSED"); TradeFrame:Hide()
	C_Container.UseContainerItem = realUse
end)()

