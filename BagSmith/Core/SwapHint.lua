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
--]]
local ADDON, ns = ...
local Hint = {}
ns.SwapHint = Hint

Hint.TEXT = "The game can't swap a bag into the slot of the bag it's stored in. Move the new bag out of that bag first."
local WINDOW = 10     -- seconds a picked-up bag is remembered
local THROTTLE = 3    -- seconds between two hints
local HOLD, FADE = 8, 1.5   -- the on-screen message: full strength, then fading out

local pickup          -- { bag, slot, itemID, t } of the bag picked up from a container
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
			if (not held or held == pickup.itemID) and sameSlot(target, bag) then Hint:Show() end
		end
		return
	end
	local held = cursorItem()
	if held and held ~= i.itemID then return end      -- some other item locked; not the pickup
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
	local srcBag, how
	local hb = heldBagSource()
	if hb then srcBag, how = hb, "on the cursor"
	elseif pickup and GetTime() - pickup.t <= WINDOW then srcBag, how = pickup.bag, "remembered" end
	ns:Debug("Swap hint: dragged bag from %s; pointer over %s", srcBag and ("bag " .. srcBag .. " (" .. how .. ")") or "nothing known", tostring(focusName))
	if sameSlot(target, srcBag) then Hint:Show() end
end
ns:On("UI_ERROR_MESSAGE", function(errType, message)
	local dragging = (pickup and GetTime() - pickup.t <= WINDOW) or cursorItem() ~= nil
	if not dragging then return end
	ns:Debug("Swap hint: game error %q (%s)", tostring(message), tostring(errType))
	local ok, err = pcall(onError, errType, message)
	if not ok then ns:Debug("Swap hint: error route failed: %s", tostring(err)) end
end)
