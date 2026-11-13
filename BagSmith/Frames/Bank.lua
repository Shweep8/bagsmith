--[[
	BagSmith - Frames/Bank.lua
	Bank replacement. Blizzard's bank window is concealed (kept alive but
	invisible and off screen, because hiding it ends the bank session) and
	BagSmith's Bank sheet shows a row of bank bag slots: see, place, swap and
	purchase.

	Two backends, chosen at load:
	  * modern C_Bank (Forever): tabs are purchased with C_Bank, each tab is a
	    bank bag container whose bag lives in an inventory slot.
	  * classic (GetNumBankSlots/PurchaseSlot) where a client still has it.
	Bag placement uses PutItemInBag / PickupBagFromSlot, present on both.
--]]

local ADDON, ns = ...
local Skins = ns.Skins
local Bank = {}
ns.Bank = Bank

local BANK_TYPE = Enum and Enum.BankType and Enum.BankType.Character or 0

local modern = type(C_Bank) == "table" and type(C_Bank.FetchNumPurchasedBankTabs) == "function"
	and type(C_Bank.PurchaseBankTab) == "function"
local classic = type(GetNumBankSlots) == "function" and type(PurchaseSlot) == "function" and type(GetBankSlotCost) == "function"
Bank.supported = (modern or classic) and type(PutItemInBag) == "function" and type(PickupBagFromSlot) == "function"
Bank.backend = modern and "modern" or (classic and "classic" or "none")

local function call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end

-- Purchased tab count, max tabs, and the next tab's price.
function Bank:Info()
	if modern then
		local purchased = call(C_Bank.FetchNumPurchasedBankTabs, BANK_TYPE) or 0
		local max = call(C_Bank.FetchMaxNumBankTabs, BANK_TYPE) or ns.NUM_BANK_BAGS
		local data = call(C_Bank.FetchNextPurchasableBankTabData, BANK_TYPE)
		local cost = type(data) == "table" and (data.tabCost or data.cost or data.price) or nil
		local can = call(C_Bank.CanPurchaseBankTab, BANK_TYPE)
		if can == nil then can = purchased < max end
		return purchased, math.min(max, ns.NUM_BANK_BAGS), cost, can and true or false
	end
	local purchased, full = GetNumBankSlots()
	purchased = purchased or 0
	return purchased, ns.NUM_BANK_BAGS, GetBankSlotCost(purchased), not full
end

-- Purchasing is protected on the modern API: only Blizzard's UI may call it.
-- The buy slot therefore securely clicks Blizzard's own purchase button.
-- In order of preference. 1 is the button inside Blizzard's purchase prompt,
-- whose click shows the "buy this tab" confirmation (retail-proven). 2 is a
-- top-level purchase button present on Forever's bank panel.
local PURCHASE_CANDIDATES = {
	{ "purchase prompt button", function()
		local p = BankFrame and BankFrame.BankPanel
		return p and p.PurchasePrompt and p.PurchasePrompt.TabCostFrame and p.PurchasePrompt.TabCostFrame.PurchaseButton end },
	{ "bank panel purchase button", function() return BankFrame and BankFrame.BankPanel and BankFrame.BankPanel.PurchaseButton end },
	{ "purchase tab", function() return BankFrame and BankFrame.BankPanel and BankFrame.BankPanel.PurchaseTab end },
	{ "classic purchase button", function() return _G.BankFramePurchaseButton end },
}
function Bank:BlizzardPurchaseButton()
	for _, c in ipairs(PURCHASE_CANDIDATES) do
		local ok, b = pcall(c[2])
		if ok and type(b) == "table" and b.GetObjectType and b:GetObjectType() == "Button" then self.pickedName = c[1]; return b end
	end
	-- Last resort: walk the bank frame for a button with "Purchase" or "Buy" in its name.
	local function walk(frame, depth)
		if depth > 5 or not frame or not frame.GetChildren then return nil end
		for key, v in pairs(frame) do
			if type(v) == "table" and v.GetObjectType and v:GetObjectType() == "Button" and type(key) == "string" and key:find("Purchase") then
				self.pickedName = "found by key " .. key; return v
			end
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			local found = walk(child, depth + 1)
			if found then return found end
		end
	end
	return BankFrame and walk(BankFrame, 0) or nil
end

-- Inventory slot holding the bag for bank bag slot i (1-based).
function Bank:InvSlot(i)
	local bag = ns.NUM_BAGS + i
	local inv = call(C_Container.ContainerIDToInventoryID, bag)
	if inv then return inv end
	if modern and C_Bank.BankBagTypeAndIDToInvSlot then
		return call(C_Bank.BankBagTypeAndIDToInvSlot, BANK_TYPE, i) or call(C_Bank.BankBagTypeAndIDToInvSlot, i)
	end
	if type(BankButtonIDToInvSlotID) == "function" then return BankButtonIDToInvSlotID(i, 1) end
end

function Bank:Replacing()
	return self.supported and ns.db and ns.db.replaceBank and true or false
end

------------------------------------------------------------------------
-- Blizzard bank frame visibility
------------------------------------------------------------------------
function Bank:Conceal()
	if not BankFrame or self.concealed or not self:Replacing() then return end
	BankFrame:SetAlpha(0)
	BankFrame:EnableMouse(false)
	-- Remember where Blizzard had it, so Reveal can put it back exactly.
	self.savedPoints = {}
	for i = 1, (BankFrame.GetNumPoints and BankFrame:GetNumPoints() or 0) do self.savedPoints[i] = { BankFrame:GetPoint(i) } end
	pcall(function()
		BankFrame:ClearAllPoints()
		BankFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 4000, -4000)
	end)
	self.concealed = true
end

function Bank:Reveal()
	if not BankFrame or not self.concealed then return end
	BankFrame:SetAlpha(1)
	BankFrame:EnableMouse(true)
	-- Back where Blizzard had it (or its usual spot if it had none).
	pcall(function()
		BankFrame:ClearAllPoints()
		if self.savedPoints and #self.savedPoints > 0 then
			for _, p in ipairs(self.savedPoints) do BankFrame:SetPoint(unpack(p)) end
		else
			BankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
		end
	end)
	self.savedPoints = nil
	self.concealed = false
end

function Bank:OnWindowHidden()
	if ns.atBank and self.concealed and self:Replacing() then
		if modern and C_Bank.CloseBankFrame then C_Bank.CloseBankFrame()
		elseif type(CloseBankFrame) == "function" then CloseBankFrame() end
	end
end

------------------------------------------------------------------------
-- Bank bag slot bar
------------------------------------------------------------------------
local SLOT = 34

local function slotTooltip(btn)
	if not ns.TooltipsOK() then return end
	GameTooltip:SetOwner(btn, "ANCHOR_TOP")
	if btn.purchased then
		if btn.invID and GetInventoryItemLink("player", btn.invID) then
			GameTooltip:SetInventoryItem("player", btn.invID)
		else
			ns.TipText(GameTooltip, "Empty Bank Bag Slot", 1, 1, 1)
			ns.TipLine(GameTooltip, "Drop a bag here", 0.6, 0.6, 0.6)
		end
	elseif btn.forSale then
		ns.TipText(GameTooltip, "Bank Bag Slot for Sale", 1, 1, 1)
		ns.TipLine(GameTooltip, "Click to buy for " .. (btn.cost and GetMoneyString(btn.cost, true) or "?"), 0.6, 0.6, 0.6)
	else
		ns.TipText(GameTooltip, "Bank Bag Slot", 1, 1, 1)
		ns.TipLine(GameTooltip, "Buy the earlier slots first", 0.6, 0.6, 0.6)
	end
	GameTooltip:Show()
end

local function slotClick(btn, button)
	if not btn.purchased then
		if not ns.atBank or not btn.forSale then return end
		-- No Blizzard purchase button to delegate to: show Blizzard's bank so the
		-- player can buy there, and say so.
		Bank:Reveal()
		ns:Print("Buy the bank slot in Blizzard's bank window, shown now.")
		return
	end
	if not btn.invID then return end
	-- (1.7.1-beta1) a bag stored in the bank bag it should replace: BagSmith moves it out first and swaps it in
	if CursorHasItem() then
		if not (ns.SwapHint and ns.SwapHint.Intercept and ns.SwapHint:Intercept(nil, btn.invID)) then PutItemInBag(btn.invID) end
	elseif button == "LeftButton" then PickupBagFromSlot(btn.invID) end
end

local function makeSlot(parent, i)
	local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
	b:SetSize(SLOT, SLOT)
	b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.plus = b:CreateTexture(nil, "OVERLAY")
	b.plus:SetSize(12, 12); b.plus:SetPoint("CENTER")
	b.plus:SetTexture("Interface\\AddOns\\BagSmith\\Media\\ui-plus.tga")
	b.plus:SetVertexColor(0.62, 0.6, 0.55)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnClick", slotClick)
	-- A secure overlay for the purchasable slot: its click is passed to
	-- Blizzard's purchase button, so the purchase runs as Blizzard's code.
	b.secureBuy = CreateFrame("Button", nil, b, "SecureActionButtonTemplate")
	b.secureBuy:SetAllPoints(b)
	b.secureBuy:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
	b.secureBuy:SetAttribute("type", "click")
	b.secureBuy:SetScript("OnEnter", function(s) slotTooltip(s:GetParent()) end)
	b.secureBuy:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b.secureBuy:Hide()
	b:SetScript("OnDragStart", function(self) if self.purchased and self.invID then PickupBagFromSlot(self.invID) end end)
	b:SetScript("OnReceiveDrag", function(self)
		if self.purchased and self.invID and CursorHasItem() then
			if not (ns.SwapHint and ns.SwapHint.Intercept and ns.SwapHint:Intercept(nil, self.invID)) then PutItemInBag(self.invID) end
		end
	end)
	b:SetScript("OnEnter", slotTooltip)
	b:SetScript("OnLeave", function() GameTooltip:Hide(); ResetCursor() end)
	-- Modern hover, from the slot itself or from the purchase overlay on top of it.
	ns.HoverWash(b, 0); ns.HoverWash(b.secureBuy, 0, b)
	b.index = i
	return b
end

-- Fills the bar for the main view. Returns the height the bar needs (0 = hidden).
function Bank:FillBar(bar)
	if not (self.supported and ns.atBank and not ns.ui.owner and self:Replacing()) then
		for _, b in ipairs(bar.slots or {}) do b:Hide() end
		if bar.label then bar.label:Hide(); bar.hint:Hide() end
		return 0
	end
	bar.slots = bar.slots or {}
	if not bar.label then
		bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		bar.label:SetPoint("LEFT", 10, 6)
		bar.hint = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		bar.hint:SetPoint("LEFT", 10, -8)
	end
	local purchased, max, cost, canBuy = self:Info()
	bar.label:SetText("Bank Bags")
	bar.label:SetTextColor(Skins:Color("accent"))
	bar.hint:SetText(("%d of %d slots%s"):format(purchased, max, (canBuy and cost) and (", next " .. GetMoneyString(cost, true)) or ""))
	bar.hint:SetTextColor(Skins:Color("muted"))
	bar.label:Show(); bar.hint:Show()
	local x = math.max(bar.label:GetStringWidth(), bar.hint:GetStringWidth()) + 24
	for i = 1, max do
		local b = bar.slots[i]
		if not b then b = makeSlot(bar, i); bar.slots[i] = b end
		b.purchased = i <= purchased
		b.forSale = (i == purchased + 1) and canBuy
		b.cost = cost
		b.invID = b.purchased and self:InvSlot(i) or nil
		local tex = b.invID and GetInventoryItemTexture("player", b.invID)
		-- Classic: Blizzard's bag-slot frame, like the bags strip, instead of
		-- the flat border (under the plus on the slot for sale); an empty
		-- bought slot shows the empty bag picture, as the bags strip does.
		-- Unbought slots keep their dimming, frame included.
		local classic = ns.Classic and ns.Classic.IsOn and ns.Classic.IsOn() and true or false
		if ns.BagBar then ns.BagBar:ClassicFrame(b, classic, -1) end
		if b.purchased then
			b:SetBackdropColor(0, 0, 0, 0.35); b:SetBackdropBorderColor(1, 1, 1, classic and 0 or 0.12)
			if tex then
				b.icon:SetTexture(tex); b.icon:SetDesaturated(false); b.icon:SetAlpha(1); b.icon:Show()
			elseif classic and ns.BagBar then
				b.icon:SetTexture(ns.BagBar.EMPTY); b.icon:SetDesaturated(true); b.icon:SetAlpha(0.5); b.icon:Show()
			else
				b.icon:SetTexture(nil); b.icon:Hide()
			end
			b.plus:Hide(); b:SetAlpha(1)
		else
			b:SetBackdropColor(0, 0, 0, 0.15); b:SetBackdropBorderColor(1, 1, 1, classic and 0 or 0.06)
			b.icon:Hide()
			b.plus:SetShown(b.forSale and true or false)
			b:SetAlpha(b.forSale and 1 or 0.4)
		end
		-- Wire the secure click-through for the slot that is for sale.
		local target = (b.forSale and not InCombatLockdown()) and self:BlizzardPurchaseButton() or nil
		if target then
			b.secureBuy:SetAttribute("clickbutton", target)
			b.secureBuy:Show()
		else
			b.secureBuy:Hide()
		end
		b:ClearAllPoints(); b:SetPoint("LEFT", bar, "LEFT", x, 0)
		b:Show()
		x = x + SLOT + 4
	end
	for j = max + 1, #bar.slots do bar.slots[j]:Hide() end
	return SLOT + 14
end

------------------------------------------------------------------------
-- Wiring
------------------------------------------------------------------------
ns:OnSignal("BANK_OPENED", function() Bank:Conceal() end)
ns:OnSignal("BANK_CLOSED", function() Bank:Reveal() end)
ns:OnSignal("SETTINGS_CHANGED", function(key)
	if (key == nil or key == "replaceBank") and ns.atBank then
		if ns.db.replaceBank then Bank:Conceal() else Bank:Reveal() end
	end
end)
ns:OnSignal("ADDON_READY", function()
	ns:On("BANK_TABS_CHANGED", function() ns:NextFrame("scan", function() ns:Scan() end) end)
	ns:On("BANK_TAB_SETTINGS_UPDATED", function() ns:NextFrame("scan", function() ns:Scan() end) end)
end)
