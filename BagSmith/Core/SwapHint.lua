--[[
	BagSmith - Core/SwapHint.lua

	The game won't swap a bag into the slot of the bag it is stored in: the
	bag being replaced would have to hold itself while it is swapped out. The
	game refuses ("Can't put non-empty bags in other bags."). BagSmith adds a
	plain explanation of why and what to do, on screen and in chat.

	Detected without touching Blizzard's frames:
	1. The refused drop (the route that works on Forever): the dragged bag's
	   own slot unlocks while the cursor is empty or still holds that bag,
	   and the pointer is over the slot of the bag it is stored in
	   (Blizzard's bag bar, CharacterBag0Slot to CharacterBag3Slot, or
	   BagSmith's Bank Bags strip). Dropping a bag on its own bag's slot can
	   only be refused, so that is exactly the failed swap. Forever leaves
	   the refused bag on the cursor, and its red message does not come
	   through UI_ERROR_MESSAGE.
	2. A game error (UI_ERROR_MESSAGE) while the pointer is over that slot,
	   for clients that do send it. The game's wording is never matched.
	The dragged bag is the one that was on the cursor when it was picked
	up, so items the game locks during the attempt can't replace it.

	/bs debug traces each step for a dragged bag: remembered, released,
	forgotten, and any game error while it is being dragged.

	(1.7.1-beta1, Shweep, from a player's review) BagSmith now does the swap
	instead of only explaining it: the new bag is first moved to a free slot
	in another bag, then put in the bag's slot, so the game swaps them (see
	Hint:SwapIn). BagSmith's Bag Bar and Bank Bags strip do it before the
	game can refuse (Hint:Intercept). (1.7.1-beta2, the 1.7.1-beta1 audit's
	F1) Blizzard's bag bar does it only from a real drop or click on its bag
	buttons (Hint:OnBagButton, post-hooks); routes 1 and 2 above explain
	only, as in 1.7.0, since they can't tell a drop from a cancel.
	(1.7.1-beta4) On Forever route 1 comes inside the bag button's own
	handler, just before the hook, which claims it (see Hint:OnBagButton).
--]]
local ADDON, ns = ...
local Hint = {}
ns.SwapHint = Hint

Hint.TEXT = "The game can't swap a bag into the slot of the bag it's stored in. Move the new bag out of that bag first."
local WINDOW = 10     -- seconds a picked-up bag is remembered
local THROTTLE = 3    -- seconds between two hints
local HOLD, FADE = 8, 1.5   -- the on-screen message: full strength, then fading out

local pickup          -- { bag, slot, itemID, t } of the bag picked up from a container
local refused         -- (1.7.1-beta4) { bag, slot, id, t, taken }: a refusal just noticed (route 1), for the bag button
local lastShown = -math.huge

local function info(bag, slot)
	return C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
end

local function isBag(itemID)
	local getInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
	if not (itemID and getInfo) then return false end
	local _, _, _, equipLoc, _, classID = getInfo(itemID)
	return equipLoc == "INVTYPE_BAG" or equipLoc == "INVTYPE_QUIVER" or classID == 1 or classID == 11
end

local function cursorItem()
	if not GetCursorInfo then return nil end
	local kind, id = GetCursorInfo()
	if kind == "item" then return id end
end

local function invSlotOf(bag)
	if not (C_Container and C_Container.ContainerIDToInventoryID) then return nil end
	local ok, inv = pcall(C_Container.ContainerIDToInventoryID, bag)
	return ok and inv or nil
end

-- The bags a dragged bag can be stored in: the character's bags, and the
-- bank's bags while the bank is open.
local function sameSlot(target, srcBag)
	if not target or not srcBag or srcBag == 0 then return false end
	return (target.bag and target.bag == srcBag) or (target.inv and target.inv == invSlotOf(srcBag)) or false
end

local function containers()
	local list = { 1, 2, 3, 4 }
	if ns.atBank then for _, b in ipairs(ns.BANK_BAGS or {}) do list[#list + 1] = b end end
	return list
end

-- Where the bag on the cursor is stored: its slot stays locked while it is
-- held. Returns bag, slot, or nil.
local function heldBagSource()
	local id = cursorItem()
	if not (id and isBag(id)) then return nil end
	for _, bag in ipairs(containers()) do
		local n = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
		for slot = 1, n do
			local i = info(bag, slot)
			if i and i.itemID == id and i.isLocked then return bag, slot end
		end
	end
end
Hint.HeldBagSource = heldBagSource

-- Which equipped bag's slot is under the pointer: { bag = id } for
-- Blizzard's bag bar, { inv = slot } for BagSmith's Bank Bags strip.
local function slotUnderPointer()
	local list
	if GetMouseFoci then list = GetMouseFoci() elseif GetMouseFocus then list = { GetMouseFocus() } end
	for _, f in ipairs(list or {}) do
		if type(f) == "table" then
			if f.invID then return { inv = f.invID }, "Bank Bags slot" end
			local name = f.GetName and f:GetName()
			local n = name and name:match("^CharacterBag(%d)Slot$")
			if n then return { bag = tonumber(n) + 1 }, name end
			if name then return nil, name end
			return nil, "an unnamed frame"
		end
	end
	return nil, "nothing"
end
Hint.SlotUnderPointer = slotUnderPointer

-- BagSmith's own on-screen message, just below the game's error area. The
-- game's error display fades everything quickly, and lengthening it would
-- make every red error linger too, so BagSmith shows its own: created once,
-- reused, held for HOLD seconds, then faded out over FADE seconds. Showing
-- it again restarts the timer.
local notice
local function noticeFrame()
	if notice then return notice end
	notice = CreateFrame("Frame", nil, UIParent)
	notice:SetSize(900, 30)
	notice:SetFrameStrata("HIGH")
	if UIErrorsFrame then notice:SetPoint("TOP", UIErrorsFrame, "BOTTOM", 0, -4)
	else notice:SetPoint("TOP", UIParent, "TOP", 0, -190) end
	notice.text = notice:CreateFontString(nil, "OVERLAY")
	notice.text:SetFontObject(_G.ErrorFont or GameFontNormalLarge)
	notice.text:SetAllPoints()
	notice.text:SetJustifyH("CENTER")
	notice.text:SetTextColor(1, 0.82, 0)
	notice:SetScript("OnUpdate", function(f, elapsed)
		f.t = f.t + (elapsed or 0)
		if f.t >= HOLD + FADE then f:Hide()
		elseif f.t > HOLD then f:SetAlpha(1 - (f.t - HOLD) / FADE) end
	end)
	notice:Hide()
	return notice
end
function Hint:Notice(text)
	local f = noticeFrame()
	f.text:SetText(text)
	f.t = 0
	f:SetAlpha(1)
	f:Show()
end
Hint.HOLD, Hint.FADE = HOLD, FADE
Hint.NoticeFrame = function() return notice end

function Hint:Show()
	local now = GetTime()
	if now - lastShown < THROTTLE then return end
	lastShown = now
	self:Notice(Hint.TEXT)
	ns:Print(Hint.TEXT)
	Hint.shown = (Hint.shown or 0) + 1
end

------------------------------------------------------------------------
-- (1.7.1-beta1) The swap in one drag. The new bag (N) is stored in the bag it should replace (X). BagSmith:
--   1. puts N back where it came from if it's on the cursor (X's slot), so every route starts the same way;
--   2. moves N to a free slot in another general bag (Y), and waits for the game to confirm it;
--   3. picks N up there and puts it in X's slot; the game swaps them (X's contents move into N, X goes where N came
--      from, Y's slot); if the game hands X back on the cursor instead, X is set down in that same free slot;
--   4. confirms N is in the bag slot, and says where X went (only a place it has just seen).
-- One swap at a time; never in combat. BagSmith holds the cursor only between its own pick-up and place, and only
-- its own item is ever put back. Each step runs protected (ns:Guard, kept for /bs errors). Whatever the game refuses
-- is said in chat and on screen, and N is left in Y's slot, from where the player's own drag works.
------------------------------------------------------------------------
Hint.SWAP_STEP, Hint.SWAP_TRIES = 0.25, 12
local SWAP_LABEL = "Swapping bags"
Hint.NO_ROOM = "To swap in %s, BagSmith first moves it out of %s, so it needs a free slot in another bag. Free one and drop it again."
Hint.REFUSED = "The game didn't swap the bags (%s may be too small for what %s holds)."   -- (where N is: only if seen)
Hint.IN_COMBAT = "Bags can't be swapped in combat. Try again after the fight."
Hint.SAME = "%s is the same kind of bag as the one in that slot, so there's nothing to swap."
local function itemName(id)
	local n = id and C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(id)
	return n or "the new bag"
end
local function bagLabel(bag) return (ns.BagName and ns:BagName(bag)) or ("bag " .. tostring(bag)) end
local function equipped(inv) return inv and GetInventoryItemID and GetInventoryItemID("player", inv) or nil end
-- Where a bag can be set down first: a general bag (not a profession bag, quiver or keyring) other than X.
local function swapRoom(x)
	local list = {}
	for _, b in ipairs(ns.BAGS or { 0, 1, 2, 3, 4 }) do if b ~= ns.KEYRING then list[#list + 1] = b end end
	if ns.atBank then for _, b in ipairs(ns.BANK_BAGS or {}) do list[#list + 1] = b end end
	for _, bag in ipairs(list) do
		if bag ~= x then
			local okF, free, family = pcall(C_Container.GetContainerNumFreeSlots, bag)
			if okF and (free or 0) > 0 and (family or 0) == 0 then
				local n = C_Container.GetContainerNumSlots(bag) or 0
				for slot = 1, n do if not info(bag, slot) then return bag, slot end end
			end
		end
	end
end
-- The container whose bag sits in an inventory slot (a bag slot or a bank bag slot).
local function bagOfInv(inv)
	for _, bag in ipairs(containers()) do if invSlotOf(bag) == inv then return bag end end
end
local function say(text, onScreen)
	ns:Print(text)
	if onScreen then Hint:Notice(text) end
end
local function located(id, bag, slot)
	if not (id and bag and slot) then return false end
	local i = info(bag, slot)
	return i and i.itemID == id or false
end
-- (1.7.1-beta2, the 1.7.1-beta1 audit's F2) Only a place BagSmith has just seen is named: the exact slot it used,
-- holding the item and settled (a locked item may be on someone's cursor or still moving).
local function seen(id, bag, slot)
	if not (id and bag and slot) then return false end
	local i = info(bag, slot)
	return i and i.itemID == id and not i.isLocked or false
end
function Hint:SwapIn(x, inv, srcSlot, newID)
	if self.swapping then return true end
	if InCombatLockdown() then say(Hint.IN_COMBAT, true); return true end
	inv = inv or invSlotOf(x)
	local oldID = equipped(inv)
	if not (x and inv and srcSlot and newID and oldID) then return false end
	local nName, xName = itemName(newID), itemName(oldID)
	-- (1.7.1-beta4) a bag of the same kind as the one it would replace: nothing to swap, and said so
	if oldID == newID then
		if cursorItem() == newID then pcall(ClearCursor) end   -- (its own: back where it came from)
		say(Hint.SAME:format(nName), true)
		return true
	end
	local y, ys = swapRoom(x)
	if not y then
		if cursorItem() == newID then pcall(ClearCursor) end   -- (its own: back where it came from)
		say(Hint.NO_ROOM:format(nName, xName), true)
		return true
	end
	-- (1.7.1-beta2, the audit's advisory B) a swap that uses a bank bag belongs to this visit to the bank
	local bankJob = (ns.IsBankBag and (ns:IsBankBag(x) or ns:IsBankBag(y))) or false
	local session = Hint.bankSession
	local job = { x = x, inv = inv, y = y, ys = ys, newID = newID, oldID = oldID, bank = bankJob }
	self.swapping = job
	lastShown = GetTime()   -- (the refusal's own notices say nothing while BagSmith swaps)
	local holding = nil     -- the item ID BagSmith has on the cursor right now, if any
	local over = false
	local function finish(text, onScreen)
		if over then return end
		over = true
		if self.swapping == job then self.swapping = nil end
		if text then say(text, onScreen) end
	end
	-- only the new bag is ever put back by clearing the cursor: the old bag's own slot is taken by then
	local function putBack()
		if holding == newID and cursorItem() == newID then pcall(ClearCursor) end
		holding = nil
	end
	-- the new bag's place, named only where BagSmith sees it: the free slot it used, or its own slot
	local function withNew(text)
		local w = (seen(newID, y, ys) and bagLabel(y)) or (seen(newID, x, srcSlot) and bagLabel(x))
		return w and (text .. " " .. ("%s is in your %s now."):format(nName, w)) or text
	end
	-- (1.7.1-beta2, the audit's advisory A) one way out after an error: said once, kept for /bs errors (ns:Guard),
	-- the new bag put back if BagSmith holds it, the swap ended
	local function fail()
		pcall(putBack)
		local ok, held = pcall(cursorItem)
		if ok and held == oldID then
			finish(("Something went wrong swapping the bags; %s is on your cursor: set it down in a free slot. See /bs errors."):format(xName), true)
		else
			finish("Something went wrong swapping the bags; see /bs errors.", true)
		end
	end
	-- every step, check, continuation and timeout runs protected, and nothing runs once the swap is over
	local function protect(fn)
		return function(...)
			if over then return end
			if not ns:Guard(SWAP_LABEL, fn, ...) then fail() end
		end
	end
	local function bankGone() return bankJob and (not ns.atBank or Hint.bankSession ~= session) end
	local function stopBank()
		putBack()
		finish(withNew(("Stopped swapping in %s: the bank closed."):format(nName)), true)
	end
	job.stop = protect(function() if bankGone() then stopBank() end end)
	-- wait for a condition, then run the next step (called only from protected code; each try is protected too)
	local function await(test, nextStep, onTimeout, n)
		n = n or 0
		if bankGone() then return stopBank() end
		if test() then return nextStep() end
		if n >= Hint.SWAP_TRIES then return onTimeout() end
		C_Timer.After(Hint.SWAP_STEP, protect(function() await(test, nextStep, onTimeout, n + 1) end))
	end
	local step2, step3, step4
	-- 1. N back in its own slot
	local function step1()
		if cursorItem() == newID then holding = newID; ClearCursor(); holding = nil end
		await(function() return located(newID, x, srcSlot) and not info(x, srcSlot).isLocked and not CursorHasItem() end, step2,
			function() finish(("Couldn't swap in %s: it didn't settle back in your %s."):format(nName, bagLabel(x)), true) end)
	end
	-- 2. N to the free slot in another bag
	step2 = function()
		if bankGone() then return stopBank() end
		if InCombatLockdown() then return finish(Hint.IN_COMBAT, true) end
		local outcome
		if info(y, ys) or CursorHasItem() then outcome = "taken"
		else
			holding = newID
			C_Container.PickupContainerItem(x, srcSlot)
			if cursorItem() ~= newID then outcome = "pickup"
			else
				C_Container.PickupContainerItem(y, ys)
				if CursorHasItem() then outcome = "place" else holding = nil; outcome = "moved" end
			end
		end
		if outcome ~= "moved" then
			putBack()
			return finish(withNew(("Couldn't move %s out of your %s to swap it in. Try the drag again."):format(nName, bagLabel(x))), true)
		end
		await(function() return located(newID, y, ys) and not info(y, ys).isLocked end, step3,
			function() finish(withNew(("Couldn't swap in %s: the game didn't confirm moving it to your %s."):format(nName, bagLabel(y))), true) end)
	end
	-- 3. N into X's slot
	step3 = function()
		if bankGone() then return stopBank() end
		if InCombatLockdown() then return finish(withNew(Hint.IN_COMBAT), true) end
		local outcome
		if CursorHasItem() or equipped(inv) ~= oldID then outcome = "changed"
		else
			holding = newID
			C_Container.PickupContainerItem(y, ys)
			if cursorItem() ~= newID then outcome = "pickup"
			else
				PutItemInBag(inv)
				local held = cursorItem()
				if held == newID then outcome = "refused"
				else
					holding = nil
					if held == oldID then
						-- the old bag handed back on the cursor: set it down in the slot N came from
						holding = oldID
						C_Container.PickupContainerItem(y, ys)
						if cursorItem() == oldID then outcome = "oldheld" else holding = nil; outcome = "put" end
					elseif held then outcome = "other"
					else outcome = "put" end
				end
			end
		end
		if outcome == "refused" then putBack(); return finish(withNew(Hint.REFUSED:format(nName, xName)), true) end
		if outcome == "oldheld" then
			-- (never put the old bag back by clearing the cursor: it may have nowhere to go; the player sets it down)
			holding = nil
			return finish(("Swapped in %s; %s is on your cursor: set it down in a free slot."):format(nName, xName), true)
		end
		if outcome ~= "put" then
			putBack()
			return finish(withNew(("Couldn't swap in %s. Drag it to the bag slot again."):format(nName)), true)
		end
		-- (1.7.1-beta2, F2) the swap is done when the bag slot holds N, whatever the player has picked up meanwhile
		await(function() return equipped(inv) == newID end, step4,
			function() finish(withNew(Hint.REFUSED:format(nName, xName)), true) end)
	end
	-- 4. say where the old bag went, only where it's seen: settled in the free slot, or on the cursor; else nowhere
	local function report()
		if seen(oldID, y, ys) then finish(("Swapped in %s; %s is in your %s now."):format(nName, xName, bagLabel(y)))
		elseif cursorItem() == oldID then
			finish(("Swapped in %s; %s is on your cursor: set it down in a free slot."):format(nName, xName), true)
		else finish(("Swapped in %s."):format(nName)) end
	end
	step4 = function()
		await(function() return seen(oldID, y, ys) or cursorItem() == oldID end, report, report)
	end
	protect(step1)()
	return true
end
-- BagSmith's own bag slots (the Bag Bar, the Bank Bags strip): a bag on the cursor dropped on the slot of the bag
-- it's stored in is swapped in by BagSmith before the game can refuse it. True when BagSmith took the drop.
function Hint:Intercept(bag, inv)
	local id = cursorItem()
	if not (id and isBag(id)) then return false end
	bag = bag or (inv and bagOfInv(inv))
	if not bag or bag == 0 then return false end
	local srcBag, srcSlot = heldBagSource()
	if srcBag ~= bag then return false end
	return self:SwapIn(bag, inv or invSlotOf(bag), srcSlot, id)
end

-- (1.7.1-beta2, the 1.7.1-beta1 audit's F1) The game's bag bar: a swap starts only from a real drop or click on one of
-- its bag buttons, never from the hint's clues alone (a remembered pick-up, the pointer, an error), which explain
-- only. Each button's OnReceiveDrag and OnClick are post-hooked (HookScript: the game's own handler runs first, and
-- refuses a bag stored in that bag). Then, on the next frame, if nothing newer happened meanwhile (a generation token)
-- and the bag is on the cursor or back in its slot with nothing else held, the swap starts:
--   a. the bag the player dropped is still on the cursor, stored in that button's bag; or
--   b. (1.7.1-beta4, from Shweep's /bs debug on beta3) the game's handler has already refused it: on Forever the
--      refusal comes inside the handler (the bag's slot unlocks while the bag is still on the cursor: route 1 below,
--      which notes it as `refused` and holds its explanation for one frame), and the handler returns with the cursor
--      empty and the bag back in its slot. The hook claims that refusal (same bag, this moment, the bag back in its
--      slot) and the explanation isn't shown. A refusal noticed with no handler call (a cancel over the button) is
--      never claimed: it's explained on the next frame, and forgotten then.
-- Anything else (another item, a bag from another bag) gets the game's own handling and, at most, the explanation. With
-- /bs debug on, each drop on those slots says what BagSmith saw and did.
local REFUSE_WINDOW = 0.5   -- seconds (on Forever the refusal and the hook share a frame)
local hookGen = 0
local queued                -- (1.7.2-beta1) { bag, slot }: the source of the swap waiting for the next frame
local hooked = {}
-- Where the cursor's bag came from: its locked slot, or the pick-up just remembered (the game may unlock it first).
local function sourceOf(id)
	local b, s = heldBagSource()
	if b then return b, s end
	if pickup and pickup.itemID == id and GetTime() - pickup.t <= WINDOW and located(id, pickup.bag, pickup.slot) then
		return pickup.bag, pickup.slot
	end
end
-- The swap's start on the next frame, if this is still the newest drop and the bag is still the player's to give.
-- (1.7.2-beta1, the 1.7.1-beta4 audit's advisory B) the start belongs to the very bag dropped: a newer pick-up from
-- another slot cancels it (the lock handler below), and at the start a bag on the cursor must be that one, held from
-- its own slot, not another of the same kind.
local function startSoon(bag, inv, srcSlot, id)
	hookGen = hookGen + 1
	local mine = hookGen
	queued = { bag = bag, slot = srcSlot }
	lastShown = GetTime()   -- (the refusal's own notices say nothing meanwhile)
	C_Timer.After(0, function()
		if mine ~= hookGen or Hint.swapping then return end
		queued = nil
		ns:Guard(SWAP_LABEL, function()
			local held = cursorItem()
			if held and held ~= id then ns:Debug("Swap: another item is on the cursor now; not swapping"); return end
			-- a bag held from another slot isn't the one dropped; with none held (the game may unlock the dropped one
			-- while it's still on the cursor), the dropped one must still be in its slot
			local hb, hs = nil, nil
			if held then hb, hs = heldBagSource() end
			if hb and (hb ~= bag or hs ~= srcSlot) then ns:Debug("Swap: the bag on the cursor isn't the one dropped; not swapping"); return end
			if not hb and not located(id, bag, srcSlot) then ns:Debug("Swap: the bag isn't in its slot now; not swapping"); return end
			if not Hint:SwapIn(bag, inv, srcSlot, id) then lastShown = -math.huge; Hint:Show() end
		end)
	end)
end
Hint.StartSoon = startSoon
local function describe(id)
	if not id then return "empty" end
	return ("%s (%s)"):format(itemName(id), isBag(id) and "a bag" or "not a bag")
end
function Hint:OnBagButton(btn, how)
	local name = btn and btn.GetName and btn:GetName()
	local n = name and name:match("^CharacterBag(%d)Slot$")
	if not n then return end
	local bag = tonumber(n) + 1
	local id = cursorItem()
	local p = pickup and GetTime() - pickup.t <= WINDOW and pickup or nil
	local pi = p and info(p.bag, p.slot)
	local r = refused and refused.bag == bag and refused.claim and not refused.taken and GetTime() - refused.t <= REFUSE_WINDOW and refused or nil
	ns:Debug("Swap: %s on the game's slot for bag %d; cursor %s; bag last picked up: %s; refused just now: %s", how or "a drop", bag, describe(id),
		p and ("%s from bag %d slot %d, %s"):format(itemName(p.itemID), p.bag, p.slot,
			not (pi and pi.itemID == p.itemID) and "gone from that slot" or (pi.isLocked and "still held" or "back, not held")) or "none",
		r and "yes" or "no")
	if self.swapping then ns:Debug("Swap: a swap is already running"); return end
	local inv = invSlotOf(bag)
	if id then
		-- a. the bag still on the cursor
		if not isBag(id) then return end
		local srcBag, srcSlot = sourceOf(id)
		if srcBag ~= bag then ns:Debug("Swap: that bag isn't stored in bag %d: the game's own swap", bag); return end
		if r then r.taken = true end
		ns:Debug("Swap: the bag is still on the cursor: swapping it in")
		return startSoon(bag, inv, srcSlot, id)
	end
	-- b. the cursor empty: the game's handler has refused the bag and put it back (Forever)
	if not r then
		if refused and refused.bag == bag and not refused.claim then
			ns:Debug("Swap: bag %d's bag came back with the cursor empty (a cancel, not a refusal): nothing to do", bag)
		else
			ns:Debug("Swap: the game refused nothing from bag %d just now: nothing to do", bag)
		end
		return
	end
	if not seen(r.id, r.bag, r.slot) then ns:Debug("Swap: the refused bag isn't back in its slot: nothing to do"); return end
	r.taken = true; refused = nil
	ns:Debug("Swap: the game refused %s and put it back: swapping it in", itemName(r.id))
	return startSoon(bag, inv, r.slot, r.id)
end
function Hint:HookBagButtons()
	local count = 0
	for i = 0, (ns.NUM_BAGS or 4) - 1 do
		local b = _G["CharacterBag" .. i .. "Slot"]
		if b and b.HookScript and not hooked[b] then
			hooked[b] = true
			b:HookScript("OnReceiveDrag", function(self) ns:Guard(SWAP_LABEL, Hint.OnBagButton, Hint, self, "a drop") end)
			b:HookScript("OnClick", function(self) ns:Guard(SWAP_LABEL, Hint.OnBagButton, Hint, self, "a click") end)
		end
		if hooked[b] then count = count + 1 end
	end
	ns:Debug("Swap: watching %d of the game's bag slots", count)
	return count
end
-- (advisory B) each visit to the bank is its own session; closing it ends a swap that uses a bank bag
Hint.bankSession = 0
ns:OnSignal("BANK_OPENED", function() Hint.bankSession = Hint.bankSession + 1 end)
ns:OnSignal("BANK_CLOSED", function()
	Hint.bankSession = Hint.bankSession + 1
	local job = Hint.swapping
	if job and job.bank and job.stop then job.stop() end
end)
ns:OnSignal("ADDON_READY", function() Hint:HookBagButtons() end)

-- A lock change on a container slot. Only the item actually on the cursor
-- counts as a pickup: a bag is remembered, anything else replaces it. Locks
-- on other items (the game locks the old bag's contents while it tries the
-- swap) are ignored.
ns:On("ITEM_LOCK_CHANGED", function(bag, slot)
	if not (bag and slot) then return end
	local i = info(bag, slot)
	if not (i and i.itemID) then return end
	if not i.isLocked then
		-- Route 1: the dragged bag released back into its own slot.
		if pickup and pickup.bag == bag and pickup.slot == slot and pickup.itemID == i.itemID and GetTime() - pickup.t <= WINDOW then
			local target, focusName = slotUnderPointer()
			local held = cursorItem()
			ns:Debug("Swap hint: the bag was released back into bag %d slot %d; cursor %s; pointer over %s",
				bag, slot, not held and "empty" or (held == pickup.itemID and "still holds the bag" or "holds another item"), tostring(focusName))
			-- On Forever the refused bag stays on the cursor while its slot
			-- unlocks (seen in game); elsewhere the cursor may be empty. A
			-- held item's slot otherwise stays locked, so either way this is
			-- the refused drop. A different item on the cursor is not.
			-- (1.7.1-beta2, the 1.7.1-beta1 audit's F1) explained only, as in 1.7.0: these clues can't tell a drop from a
			-- cancel, so they never move anything (the swap starts from the bag buttons' own handlers, above).
			-- (1.7.1-beta4) On Forever this comes inside the game's bag button handler, just before the hook: the
			-- refusal is noted for it, and the explanation waits one frame; if the hook claims it, none is shown.
			if not Hint.swapping and (not held or held == pickup.itemID) and sameSlot(target, bag) then
				-- (1.7.2-beta1, the 1.7.1-beta4 audit's advisory A) claimable only when the bag was still on the cursor as
				-- its slot unlocked: Forever's refusal (Shweep's trace on 1.7.1-beta3). A cancel empties the cursor first,
				-- so a click right after one can't claim it.
				local rec = { bag = bag, slot = slot, id = pickup.itemID, t = GetTime(), claim = held == pickup.itemID }
				refused = rec
				C_Timer.After(0, function()
					if refused == rec then refused = nil end
					if not rec.taken and not Hint.swapping then Hint:Show() end
				end)
			end
		end
		return
	end
	local held = cursorItem()
	if held and held ~= i.itemID then return end      -- some other item locked; not the pickup
	-- (1.7.2-beta1, advisory B) a pick-up from another slot (the item on the cursor: the game's own locks on other
	-- items, the old bag's contents during a swap, aren't pick-ups) cancels a swap waiting for the next frame
	if queued and held and not (queued.bag == bag and queued.slot == slot) then
		hookGen = hookGen + 1; queued = nil
		ns:Debug("Swap: another item was picked up; not swapping")
	end
	if isBag(i.itemID) then
		pickup = { bag = bag, slot = slot, itemID = i.itemID, t = GetTime() }
		ns:Debug("Swap hint: remembered the bag from bag %d slot %d", bag, slot)
	elseif held then
		if pickup then ns:Debug("Swap hint: forgot the bag (another item was picked up)") end
		pickup = nil
	end
end)

-- Route 2: a game error while the pointer is over the slot. Logged first,
-- and shielded, so a failure inside is reported rather than silent.
local function onError(errType, message)
	local target, focusName = slotUnderPointer()
	local srcBag, srcSlot, srcID, how
	local hb, hs = heldBagSource()
	if hb then srcBag, srcSlot, srcID, how = hb, hs, cursorItem(), "on the cursor"
	elseif pickup and GetTime() - pickup.t <= WINDOW then srcBag, srcSlot, srcID, how = pickup.bag, pickup.slot, pickup.itemID, "remembered" end
	ns:Debug("Swap hint: dragged bag from %s; pointer over %s", srcBag and ("bag " .. srcBag .. " (" .. how .. ")") or "nothing known", tostring(focusName))
	if not Hint.swapping and sameSlot(target, srcBag) then Hint:Show() end   -- (1.7.1-beta2, F1) explained only
end
ns:On("UI_ERROR_MESSAGE", function(errType, message)
	local dragging = (pickup and GetTime() - pickup.t <= WINDOW) or cursorItem() ~= nil
	if not dragging then return end
	ns:Debug("Swap hint: game error %q (%s)", tostring(message), tostring(errType))
	local ok, err = pcall(onError, errType, message)
	if not ok then ns:Debug("Swap hint: error route failed: %s", tostring(err)) end
end)
