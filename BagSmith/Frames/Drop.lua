--[[
	BagSmith - Frames/Drop.lua
	Dragging an item into the other window. In list view every row is an
	occupied slot and headers take nothing, so there is nowhere obvious to
	let go. While you carry an item from somewhere else (the other window,
	a bag window, your character sheet), the list you point at shows a soft
	overlay: "Drop to put in your bank". Letting go anywhere on it places
	the item: onto a stack of the same item with room, else into the first
	free slot, preferring a matching specialty bag.

	  * Dragging within the same window keeps the normal behavior.
	  * In icon view the overlay steps aside over a slot, so you can still
	    drop on an exact slot; it covers headers, gaps and empty space.
	  * If there is no room it says so, and the item stays on your cursor.
--]]

local ADDON, ns = ...
local Skins = ns.Skins
local Drop = {}
ns.Drop = Drop

local band = (bit and bit.band) or function(a, b)
	local r, p = 0, 1
	while a > 0 and b > 0 do
		if a % 2 == 1 and b % 2 == 1 then r = r + p end
		a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
	end
	return r
end

local FADE = 8   -- alpha per second

------------------------------------------------------------------------
-- What is on the cursor, and where it came from
------------------------------------------------------------------------
local function cursorItem()
	if not (CursorHasItem and CursorHasItem()) then return nil end
	if GetCursorInfo then
		local kind, itemID = GetCursorInfo()
		if kind == "item" and itemID then return itemID end
	end
	return nil
end

-- The bag the carried item was picked up from (its slot is locked while
-- it is on the cursor), or nil if it came from outside the bags.
local function sourceBag(itemID)
	for _, list in ipairs({ ns.items or {}, ns.bankItems or {} }) do
		for _, r in ipairs(list) do
			if r.itemID == itemID and r.isLocked then return r.bag end
		end
	end
end

local function viewHasBag(view, bag)
	if bag == nil then return false end
	for _, b in ipairs(view:Bags()) do if b == bag then return true end end
	return false
end

-- Lists that can take a drop: the bags window, and the bank window while
-- at a banker. Never a read-only alt view or the saved bank.
local function canTake(view)
	return view.big and view:IsShown() and not view:IsCached() and not ns.ui.owner
end

------------------------------------------------------------------------
-- Placing the item
------------------------------------------------------------------------
local function maxStack(itemID)
	if C_Item.GetItemMaxStackSizeByID then
		local ok, n = pcall(C_Item.GetItemMaxStackSizeByID, itemID)
		if ok and n then return n end
	end
	local n = select(8, C_Item.GetItemInfo(itemID))
	return n or 1
end

local function freeSlot(bag)
	if C_Container.GetContainerFreeSlots then
		local ok, slots = pcall(C_Container.GetContainerFreeSlots, bag)
		if ok and type(slots) == "table" and slots[1] then return slots[1] end
	end
	local size = C_Container.GetContainerNumSlots(bag) or 0
	for slot = 1, size do
		if not C_Container.GetContainerItemInfo(bag, slot) then return slot end
	end
end

-- Returns bag, slot to drop on, or nil if the window has no room.
-- emptyOnly (1.4.0-beta2): an item from the window's own bags (a split stack, say) goes only to an empty slot; it
-- never rejoins a stack of its own kind, since separating it was the point.
function Drop:Target(view, itemID, emptyOnly)
	local bank = view.isBank
	local live = bank and ns.bankItems or ns.items
	local bags = {}
	for _, b in ipairs(view:Bags()) do
		local info = ns.bagInfo[b]
		if info and info.size > 0 and b ~= ns.KEYRING then bags[#bags + 1] = b end
	end
	-- 1. A stack of the same item with room.
	local cap = maxStack(itemID)
	if cap > 1 and not emptyOnly then
		for _, r in ipairs(live) do
			if r.itemID == itemID and not r.isLocked and (r.count or 1) < cap and viewHasBag(view, r.bag) then
				return r.bag, r.slot
			end
		end
	end
	-- 2. A matching specialty bag (reagent bag for crafting materials,
	--    profession bags by item family), then any general bag.
	local family = (C_Item.GetItemFamily and C_Item.GetItemFamily(itemID)) or 0
	local isReagent = select(17, C_Item.GetItemInfo(itemID)) and true or false
	for _, b in ipairs(bags) do
		local bf = ns.bagInfo[b].family or 0
		local fits = (ns:IsReagentBag(b) and isReagent) or (bf ~= 0 and not ns:IsReagentBag(b) and band(bf, family) ~= 0)
		if fits and (ns.bagInfo[b].free or 0) > 0 then
			local slot = freeSlot(b)
			if slot then return b, slot end
		end
	end
	for _, b in ipairs(bags) do
		if (ns.bagInfo[b].family or 0) == 0 and not ns:IsReagentBag(b) and (ns.bagInfo[b].free or 0) > 0 then
			local slot = freeSlot(b)
			if slot then return b, slot end
		end
	end
	return nil
end

function Drop:Place(view)
	-- (1.5.0-beta5, audit F5) a drop on the overlay is a gesture too: it cancels older pending section-drop checks
	if ns.Sections and ns.Sections.NoteGesture then ns.Sections:NoteGesture() end
	local itemID = cursorItem()
	if not itemID then return false end
	local own = viewHasBag(view, sourceBag(itemID))
	local bag, slot = self:Target(view, itemID, own)
	if not bag then
		ns:Print(own and (view.isBank and "No free slot in your bank." or "No free slot in your bags.") or (view.isBank and "Your bank is full." or "Your bags are full."))
		return false
	end
	-- The row this drag started from (its gesture ticket, exact members),
	-- if it was a genuinely merged row of this item and is really being
	-- carried (its slot is locked).
	local from = self.dragFrom
	self.dragFrom = nil
	if from then
		local src = C_Container.GetContainerItemInfo(from.bag, from.slot)
		if not (src and src.itemID == itemID and src.isLocked) or from.token ~= self.gesture then from = nil end
	end
	local before = C_Container.GetContainerItemInfo(bag, slot)
	local destBefore = (before and before.itemID == itemID) and (before.stackCount or 0) or 0
	C_Container.PickupContainerItem(bag, slot)
	if not (from and from.merged and ns.atBank) then return true end
	if from.fromBank == (view.isBank and true or false) then return true end   -- (dropped back on its own side)
	-- Confirm the first stack from evidence, never from the cursor alone: the
	-- whole stack left its source slot, the chosen destination gained at
	-- least that many, and nothing is carried. A partial merge (some items
	-- stay on the cursor) or anything put back fails this, so nothing follows.
	local token, tries = from.token, 0
	local function state()
		local src = C_Container.GetContainerItemInfo(from.bag, from.slot)
		local dst = C_Container.GetContainerItemInfo(bag, slot)
		local srcHas = (src and src.itemID == itemID) and (src.stackCount or 0) or 0
		local dstHas = (dst and dst.itemID == itemID) and (dst.stackCount or 0) or 0
		return srcHas, dstHas
	end
	local function confirmed()
		if CursorHasItem and CursorHasItem() then return false end
		local srcHas, dstHas = state()
		return srcHas == 0 and dstHas >= destBefore + from.count
	end
	local function poll()
		if token ~= self.gesture then return end   -- cancelled or replaced: this drag is over
		tries = tries + 1
		if confirmed() then
			self:MoveRest({ itemID = itemID, members = from.members, fromBank = from.fromBank, name = from.name,
				first = { bag = from.bag, slot = from.slot, confirmed = true }, token = token })
		elseif tries < 15 then
			C_Timer.After(0.1, poll)
		elseif CursorHasItem and CursorHasItem() then
			ns:Print("The first stack of %s didn't settle, so the rest weren't moved.", from.name or "that item")
		end
		-- (otherwise: returned, or only partly moved: nothing else moves, quietly)
	end
	C_Timer.After(0.1, poll)
	return true
end

-- Every drag or click is a gesture with its own ticket; callbacks from an
-- older gesture do nothing.
Drop.gesture = 0
-- A new gesture voids any drag still waiting to confirm. A job already running keeps running: a second move
-- while one runs is refused with a note (see MoveRest), and only the bank closing, combat, or the mail or
-- trade session ending cancels a running job (CancelMoves, BumpSession). That is the defined behavior.
function Drop:NewGesture() self.gesture = self.gesture + 1; return self.gesture end

-- Remember the row a drag starts from (called by the item buttons).
function Drop:NoteDrag(btn)
	local rec = btn and btn.rec
	self:NewGesture()
	if not (rec and rec.itemID) or rec.empty then self.dragFrom = nil return end
	local fromBank = false
	for _, r in ipairs(ns.bankItems or {}) do if r.bag == rec.bag and r.slot == rec.slot then fromBank = true; break end end
	local members = {}
	for _, m in ipairs(rec.members or {}) do members[#members + 1] = { bag = m.bag, slot = m.slot, itemID = m.itemID, count = m.count } end
	-- The dragged stack's own count (the row's total covers every member).
	local own = rec.count or 1
	for _, m in ipairs(members) do if m.bag == rec.bag and m.slot == rec.slot then own = m.count or own end end
	local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(rec.bag, rec.slot)
	if info and info.itemID == rec.itemID and info.stackCount then own = info.stackCount end
	self.dragFrom = { token = self.gesture, itemID = rec.itemID, bag = rec.bag, slot = rec.slot, name = rec.name, count = own,
		merged = rec.merged and (rec.stacks or 1) > 1 and #members > 1, fromBank = fromBank, members = members }
end

-- Merged stacks at the bank: one row stands for several stacks, but a click
-- or drop moves only the stack behind it. This moves the row's other
-- members (exactly the stacks it showed, captured at the gesture) to the
-- other side, one at a time. Rules: one job at a time (a late callback never
-- starts or replaces one); before EVERY action the job's ticket, the bank
-- being open, being out of combat, an empty cursor and the member's identity
-- are rechecked; the bank closing or combat starting cancels the job; a lock
-- is waited on, never counted; only confirmed moves count; if some stay,
-- chat says how many of how many moved and why. Bank moves only.
--   job = { itemID, members = { {bag, slot, itemID, count}... }, fromBank, name,
--           first = { bag, slot, confirmed }, token }
Drop.MOVE_STEP, Drop.LOCK_TRIES = 0.25, 8
-- Where a right-clicked stack goes right now: the bank, the mailbox's send form, or the trade window; nil elsewhere.
function Drop:Where()
	if ns.atBank then return "bank" end
	if SendMailFrame and SendMailFrame.IsShown and SendMailFrame:IsShown() and MailFrame and MailFrame:IsShown() then return "mail" end
	if TradeFrame and TradeFrame.IsShown and TradeFrame:IsShown() then return "trade" end
	return nil
end
-- Free slots the destination still has: twelve attachments on a mail, six items in a trade; the bank has
-- no fixed count (its own fullness shows as a stack that stays).
function Drop:FreeSlots(where)
	if where == "mail" then
		local max = ATTACHMENTS_MAX_SEND or 12
		local free = 0
		for i = 1, max do local name = GetSendMailItem and GetSendMailItem(i); if not name then free = free + 1 end end
		return free
	elseif where == "trade" then
		local max = (MAX_TRADE_ITEMS or 7) - 1   -- the last slot is "will not be traded"
		local free = 0
		for i = 1, max do local name = GetTradePlayerItemInfo and GetTradePlayerItemInfo(i); if not name then free = free + 1 end end
		return free
	end
	return nil
end
Drop.WHERE_NAME = { bank = "the bank", mail = "the mail", trade = "the trade window" }
-- How many of an item the trade window holds right now (by link, or by name where links are unavailable).
function Drop:InTrade(itemID, name)
	local max = (MAX_TRADE_ITEMS or 7) - 1
	local n = 0
	for i = 1, max do
		local slotName = GetTradePlayerItemInfo and GetTradePlayerItemInfo(i)
		local link = GetTradePlayerItemLink and GetTradePlayerItemLink(i)
		local id = link and tonumber(link:match("item:(%d+)"))
		if slotName and (id == itemID or (not id and slotName == name)) then n = n + 1 end
	end
	return n
end
-- Taken on mouse-down, before the game places the clicked stack: the trade's count of that item. The
-- clicked stack counts as placed only when the count has grown past this baseline.
function Drop:NoteTradeBaseline(rec)
	if self:Where() ~= "trade" or not (rec and rec.itemID) then self.tradeBaseline = nil; return end
	self.tradeBaseline = { itemID = rec.itemID, count = self:InTrade(rec.itemID, rec.name), at = GetTime() }
end
-- Each mail form or trade window is its own session: a job started in one never continues into another.
Drop.session = { mail = 0, trade = 0 }
function Drop:BumpSession(where)
	self.session[where] = (self.session[where] or 0) + 1
	if self.active and self.active.where == where then self:CancelMoves(("%s closed."):format(self.WHERE_NAME[where])) end
end
ns:OnSignal("ADDON_READY", function()
	ns:On("MAIL_SHOW", function() Drop:BumpSession("mail") end)
	ns:On("MAIL_CLOSED", function() Drop:BumpSession("mail") end)
	ns:On("MAIL_SEND_SUCCESS", function() Drop:BumpSession("mail") end)
	ns:On("TRADE_SHOW", function() Drop:BumpSession("trade") end)
	ns:On("TRADE_CLOSED", function() Drop:BumpSession("trade") end)
	ns:On("TRADE_REQUEST_CANCEL", function() Drop:BumpSession("trade") end)
end)
function Drop:MoveRest(job)
	job = job or {}
	local where = job.where or "bank"
	if not (job.itemID and job.members) or InCombatLockdown() then return end
	if where == "bank" and not ns.atBank then return end
	if where ~= "bank" and self:Where() ~= where then return end
	if job.token and job.token ~= self.gesture then return end   -- an older gesture
	if self.active then
		ns:Print("Still moving %s; try again in a moment.", self.active.name or "the last item")
		return
	end
	local first = job.first or {}
	local todo = {}
	for _, m in ipairs(job.members) do
		if not (m.bag == first.bag and m.slot == first.slot) then todo[#todo + 1] = { bag = m.bag, slot = m.slot } end
	end
	if #todo == 0 then return end
	-- a mail or a trade holds only so many: the stacks that will not fit are left, and said so
	local left = 0
	local free = self:FreeSlots(where)
	if free then
		if free < #todo then left = #todo - free; for i = #todo, free + 1, -1 do todo[i] = nil end end
		if #todo == 0 then ns:Print("%s has no free slots for the rest of %s.", (self.WHERE_NAME[where]:gsub("^%l", string.upper)), job.name or "that item"); return end
	end
	self.moveToken = (self.moveToken or 0) + 1
	local token = self.moveToken
	-- The trade's pre-click count is this job's evidence from here on: taken now and consumed, so a later
	-- mouse-down (another click while this job runs) cannot rewrite it (1.3.0).
	local base = nil
	if where == "trade" then base = self.tradeBaseline; self.tradeBaseline = nil end
	local name = job.name or "that item"
	local total, moved, why = #todo + 1, 0, nil
	local session = self.session[where]   -- (nil for the bank)
	self.active = { name = name, token = token, where = where }
	local function finish()
		if self.active and self.active.token == token then self.active = nil end
		if moved < total then ns:Print("Moved %d of %d stacks of %s; %s", moved, total, name, why or "the rest stayed.")
		elseif left > 0 then ns:Print("Moved %d stacks of %s; %d more would not fit in %s.", moved, name, left, self.WHERE_NAME[where]) end
	end
	local function live(it) return C_Container.GetContainerItemInfo(it.bag, it.slot) end
	local function here(info) return info and info.itemID == job.itemID end
	-- a stack "went" when it left its slot (bank, mail), or when the trade window took it: it stays, locked, and the
	-- window now holds one more of that very item (a lock alone, or any occupied slot, proves nothing)
	local inTradeBefore
	local function inTrade() return self:InTrade(job.itemID, job.name) end
	-- in a trade a stack that is no longer in its slot is ambiguous (placed stacks stay put): not a success
	local function went(after)
		if where == "trade" then
			if not here(after) then return false end
			return after.isLocked == true and inTradeBefore ~= nil and inTrade() > inTradeBefore
		end
		return not here(after)
	end
	-- The guard before any action, after any wait.
	local function ok()
		if token ~= self.moveToken then return false end
		if where == "bank" and not ns.atBank then why = "the rest stayed (the bank closed)."; return false end
		if where ~= "bank" and self:Where() ~= where then why = ("the rest stayed (%s closed)."):format(self.WHERE_NAME[where]); return false end
		if session ~= nil and self.session[where] ~= session then why = ("the rest stayed (%s was closed and reopened)."):format(self.WHERE_NAME[where]); return false end
		if InCombatLockdown() then why = "the rest stayed (combat started)."; return false end
		if CursorHasItem and CursorHasItem() then why = "the rest stayed (something is on your cursor)."; return false end
		return true
	end
	local function settle(it, fn, n)
		n = n or 0
		local info = live(it)
		-- a locked stack is the game still working on it (bank, mail); in a trade a locked stack is one the window took
		if where ~= "trade" and here(info) and info.isLocked and n < Drop.LOCK_TRIES then
			C_Timer.After(Drop.MOVE_STEP, function() if token == self.moveToken then settle(it, fn, n + 1) end end)
			return
		end
		fn(info)
	end
	local i = 0
	local step
	step = function()
		if token ~= self.moveToken then return end
		if not ok() then return finish() end
		i = i + 1
		local it = todo[i]
		if not it then return finish() end
		settle(it, function(info)
			if token ~= self.moveToken then return end
			if not ok() then return finish() end
			if not here(info) then total = total - 1; return C_Timer.After(0, step) end   -- gone already: not ours to count
			if info.isLocked then
				if where == "trade" then total = total - 1; return C_Timer.After(0, step) end   -- already in the trade window
				why = "the rest stayed (a stack stayed locked)."; return finish()
			end
			if where == "trade" then inTradeBefore = inTrade() end
			pcall(C_Container.UseContainerItem, it.bag, it.slot)
			C_Timer.After(Drop.MOVE_STEP, function()
				if token ~= self.moveToken then return end
				settle(it, function(after)
					if token ~= self.moveToken then return end
					if not went(after) then
						why = (where == "trade" and not here(after) and "the rest stayed (a stack could not be found after its click).")
							or (after and after.isLocked and "the rest stayed (a stack stayed locked).")
							or (where == "mail" and "the rest stayed (the mail may be full, or the game wants a click for each).")
							or (where == "trade" and "the rest stayed (the trade window may be full, or the game wants a click for each).")
							or (job.fromBank and "the rest stayed (your bags may be full, or the game wants a click for each)."
							or "the rest stayed (your bank may be full, or the game wants a click for each).")
						return finish()
					end
					moved = moved + 1
					C_Timer.After(0, step)
				end)
			end)
		end)
	end
	if first.confirmed then
		moved = 1
		C_Timer.After(Drop.MOVE_STEP, step)
	else
		C_Timer.After(Drop.MOVE_STEP, function()
			if token ~= self.moveToken then return end
			settle(first, function(info)
				if token ~= self.moveToken then return end
				-- in a trade the clicked stack counts as placed only when it is locked in its slot and the window holds that
				-- very item (a lock alone, or some other item in the window, is not proof); a clicked stack that cannot be
				-- found is ambiguous, and ambiguity ends the job
				local placed
				if where == "trade" then
					if not (info and here(info)) then why = "nothing moved (the clicked stack could not be found)."; return finish() end
					-- the trade's count of this item before the click, from mouse-down; without it nothing can be told
					if not (base and base.itemID == job.itemID and (GetTime() - (base.at or 0)) < 10) then why = "nothing moved (the clicked stack's placement could not be confirmed)."; return finish() end
					placed = info.isLocked == true and inTrade() > base.count
				else placed = went(info) end
				if not placed then
					why = (info and info.isLocked) and "nothing moved (the stack stayed locked)."
						or (job.fromBank and "nothing moved (your bags may be full)." or "nothing moved (your bank may be full).")
					return finish()
				end
				moved = 1
				step()
			end)
		end)
	end
end
-- The bank closing or combat starting cancels a running job (it reports what moved).
function Drop:CancelMoves(reason)
	-- Any drag still waiting to confirm is over too: its ticket is voided.
	self:NewGesture()
	self.dragFrom = nil
	if not self.active then return end
	local a = self.active
	self.active = nil
	self.moveToken = (self.moveToken or 0) + 1
	ns:Print("Stopped moving %s: %s", a.name or "the last item", reason)
end
ns:OnSignal("ADDON_READY", function()
	ns:On("BANKFRAME_CLOSED", function() Drop:CancelMoves("the bank closed.") end)
	ns:On("PLAYER_REGEN_DISABLED", function() Drop:CancelMoves("combat started.") end)
end)

------------------------------------------------------------------------
-- The overlay
------------------------------------------------------------------------
local function overlayFor(view)
	if view.dropOverlay then return view.dropOverlay end
	local o = CreateFrame("Frame", nil, view.frame, "BackdropTemplate")
	o:SetPoint("TOPLEFT", view.scroll, "TOPLEFT", -2, 2)
	o:SetPoint("BOTTOMRIGHT", view.scroll, "BOTTOMRIGHT", 2, -2)
	o:SetFrameLevel((view.scroll:GetFrameLevel() or 1) + 40)
	o:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
	o.label = o:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	o.label:SetPoint("CENTER", 0, 10)
	o.sub = o:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	o.sub:SetPoint("TOP", o.label, "BOTTOM", 0, -6)
	o:EnableMouse(true)
	o:SetScript("OnReceiveDrag", function() if Drop:Place(view) then Drop:Hide(view, true) end end)
	o:SetScript("OnMouseUp", function() if Drop:Place(view) then Drop:Hide(view, true) end end)
	o:SetAlpha(0)
	o:Hide()
	o.alpha, o.want = 0, 0
	view.dropOverlay = o
	return o
end

function Drop:Fill(view, o, own)
	local r, g, b = Skins:Accent()
	o:SetBackdropColor(r, g, b, 0.14)
	o:SetBackdropBorderColor(r, g, b, 0.75)
	local free, total, rfree = ns:FreeSlots(view:Bags())
	free = free + (rfree or 0)
	-- What actually happens to the item on the cursor decides the message.
	local itemID
	if GetCursorInfo then local kind, id = GetCursorInfo(); if kind == "item" then itemID = id end end
	-- From this window's own bags (1.4.0-beta2): an empty slot or nothing.
	if own then
		if itemID and Drop:Target(view, itemID, true) then
			o.label:SetText("Drop to put it in a free slot"); o.label:SetTextColor(r, g, b)
			o.sub:SetText("It goes to an empty slot, not back onto its stack")
		else
			o.label:SetText("No free slot"); o.label:SetTextColor(0.94, 0.58, 0.58)
			o.sub:SetText(view.isBank and "Your bank has no empty slot that can hold it" or "Your bags have no empty slot that can hold it")
		end
		o.sub:SetTextColor(Skins:Color("muted"))
		return
	end
	local target = itemID and Drop:Target(view, itemID)
	if itemID and target and free == 0 then
		o.label:SetText(view.isBank and "Drop to put in your bank" or "Drop to put in your bags")
		o.label:SetTextColor(r, g, b)
		o.sub:SetText("It joins a stack that has room")
		o.sub:SetTextColor(Skins:Color("muted"))
	elseif itemID and not target and free > 0 then
		o.label:SetText("No room for this item")
		o.label:SetTextColor(0.94, 0.58, 0.58)
		o.sub:SetText("The free slots are in bags that can't hold it")
		o.sub:SetTextColor(Skins:Color("muted"))
	elseif free > 0 then
		o.label:SetText(view.isBank and "Drop to put in your bank" or "Drop to put in your bags")
		o.label:SetTextColor(r, g, b)
		o.sub:SetText(("%d free slot%s"):format(free, free == 1 and "" or "s"))
		o.sub:SetTextColor(Skins:Color("muted"))
	else
		o.label:SetText(view.isBank and "Your bank is full" or "Your bags are full")
		o.label:SetTextColor(0.94, 0.58, 0.58)
		o.sub:SetText("The item stays on your cursor")
		o.sub:SetTextColor(Skins:Color("muted"))
	end
end

function Drop:Hide(view, now)
	local o = view.dropOverlay
	if not o then return end
	o.want = 0
	if now then o.alpha = 0; o:SetAlpha(0); o:Hide() end
end

-- In icon view, step aside while the pointer is over a slot.
-- Over any item (a cell or a list row), or any section title (1.4.0-beta2): an item from the window's own bags
-- keeps the game's swap or stack there, and a custom section's title keeps its move-to-section drop.
local function overItem(view)
	for _, b in ipairs(view.used or {}) do
		if b:IsShown() and b.IsMouseOver and b:IsMouseOver() then return true end
	end
	return false
end
local function overHeader(view)
	local lanes = ns.Buttons and ns.Buttons.lanes and ns.Buttons.lanes[view.child]
	for _, h in pairs(lanes or {}) do
		if type(h) == "table" and h.IsShown and h:IsShown() and h.IsMouseOver and h:IsMouseOver() then return true end
	end
	return false
end
local function overSlot(view)
	if view:Pref("view") ~= "icons" then return false end
	for _, b in ipairs(view.used or {}) do
		if b.mode == "cell" and b:IsShown() and b.IsMouseOver and b:IsMouseOver() then return true end
	end
	return false
end

------------------------------------------------------------------------
-- Watching the cursor: only while an item is on it.
------------------------------------------------------------------------
local watcher, watching
local function tick(_, elapsed)
	elapsed = elapsed or 0.016
	local itemID = cursorItem()
	local any = false
	local from = itemID and sourceBag(itemID)
	for _, view in pairs(ns.views) do
		if view.big then
			local show = false
			-- An item from another window, as before; or (1.4.0-beta2) one from this window's own bags while the view
			-- shows no empty slots (By Section, List view), so a split stack has somewhere to go.
			local own = itemID and viewHasBag(view, from)
			if itemID and canTake(view) and (not own or not view.emptyShown) and not InCombatLockdown() then
				local o = overlayFor(view)
				local over = view.scroll.IsMouseOver and view.scroll:IsMouseOver()
				show = over and not overSlot(view) and not (own and (overItem(view) or overHeader(view)))
				if show then Drop:Fill(view, o, own) end
			end
			local o = view.dropOverlay
			if o then
				o.want = show and 1 or 0
				if o.want > 0 then o:Show() end
				if o.alpha ~= o.want then
					local step = FADE * elapsed
					o.alpha = o.want > o.alpha and math.min(o.want, o.alpha + step) or math.max(o.want, o.alpha - step)
					o:SetAlpha(o.alpha)
				end
				if o.alpha <= 0 and o.want == 0 then o:Hide() end
				if o:IsShown() then any = true end
			end
		end
	end
	if not itemID and not any then watcher:SetScript("OnUpdate", nil); watching = false end
end

function Drop:Watch()
	if watching then return end
	watcher = watcher or CreateFrame("Frame")   -- one frame for the session
	watching = true
	watcher:SetScript("OnUpdate", tick)
end

ns:OnSignal("ADDON_READY", function()
	-- Different clients name the cursor event differently; unknown ones are skipped.
	ns:On("CURSOR_CHANGED", function() Drop:Watch() end)
	ns:On("CURSOR_UPDATE", function() Drop:Watch() end)
	ns:On("ITEM_LOCK_CHANGED", function() Drop:Watch() end)
end)
