--[[
	BagSmith - Core/Init.lua
	Namespace, client detection, shared constants, event dispatcher, combat queue.
--]]

local ADDON, ns = ...
_G.BagSmith = ns   -- (BagSmith's namespace, for its own tests and tooling; not a public contract: other addons use BagSmith.API)

ns.name = ADDON
ns.version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"

------------------------------------------------------------------------
-- Client detection. Forever reports WOW_PROJECT_MAINLINE, so use the
-- interface number and the [Game] TOC variable ("Camelot").
------------------------------------------------------------------------
local _, build, _, interface = GetBuildInfo()
ns.startup = {}
ns.build = build
ns.interface = tonumber(interface) or 0
ns.gameToken = C_AddOns.GetAddOnMetadata(ADDON, "X-Game")
ns.isForever = (ns.gameToken == "Camelot") or (ns.interface >= 16000 and ns.interface < 20000)

------------------------------------------------------------------------
-- Bag constants
------------------------------------------------------------------------
ns.BACKPACK = Enum.BagIndex and Enum.BagIndex.Backpack or 0
ns.NUM_BAGS = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
ns.REAGENT_BAG = (Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
ns.HAS_REAGENT_SLOT = ns.NUM_BAGS >= ns.REAGENT_BAG
ns.BANK = BANK_CONTAINER or (Enum.BagIndex and Enum.BagIndex.Bank) or -1

-- Bank bag slots: the constant is missing on some clients, so fall back to
-- the modern constants table and finally to the classic count of 6.
ns.NUM_BANK_BAGS = NUM_BANKBAGSLOTS
	or (Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBankBagSlots)
	or (Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumCharacterBankSlots)
	or 6

-- Keyring. Only trust it when the client gives us a real, distinct bag ID:
-- on Forever, Enum.BagIndex.Keyring reads -1, which is the bank.
ns.KEYRING = nil
do
	local candidate = KEYRING_CONTAINER or (Enum.BagIndex and Enum.BagIndex.Keyring)
	local usable = candidate and candidate ~= ns.BANK and candidate ~= ns.BACKPACK
		and (type(GetKeyRingSize) == "function" or type(HasKey) == "function")
	if usable then
		-- Final proof: the container API must answer for it.
		local ok, slots = pcall(C_Container.GetContainerNumSlots, candidate)
		if ok and type(slots) == "number" then ns.KEYRING = candidate end
	end
	ns.startup.keyringCandidate = candidate
end

ns.BAGS = {}
for bag = ns.BACKPACK, ns.NUM_BAGS do ns.BAGS[#ns.BAGS + 1] = bag end
if ns.KEYRING then ns.BAGS[#ns.BAGS + 1] = ns.KEYRING end

ns.BANK_BAGS = { ns.BANK }
for i = 1, ns.NUM_BANK_BAGS do ns.BANK_BAGS[#ns.BANK_BAGS + 1] = ns.NUM_BAGS + i end

ns.ALL_BAGS = {}
for _, b in ipairs(ns.BAGS) do ns.ALL_BAGS[#ns.ALL_BAGS + 1] = b end
for _, b in ipairs(ns.BANK_BAGS) do ns.ALL_BAGS[#ns.ALL_BAGS + 1] = b end

ns.MAX_SLOTS_FLOOR = 18

function ns:IsReagentBag(bag) return ns.HAS_REAGENT_SLOT and bag == ns.REAGENT_BAG end
function ns:IsBankBag(bag)
	if bag == ns.BANK then return true end
	return bag > ns.NUM_BAGS and bag <= ns.NUM_BAGS + ns.NUM_BANK_BAGS
end

function ns:BagName(bag)
	if bag == ns.BACKPACK then return BACKPACK_TOOLTIP or "Backpack" end
	if bag == ns.KEYRING then return KEYRING or "Keyring" end
	-- The bank's own slots: the window already says "Bank".
	if bag == ns.BANK then return "Default" end
	local ok, invID = pcall(C_Container.ContainerIDToInventoryID, bag)
	if not ok then invID = nil end
	-- Forever's C_Bank tabs: the bag in each tab lives in its own inventory slot.
	if not invID and ns:IsBankBag(bag) and ns.Bank and ns.Bank.InvSlot then invID = ns.Bank:InvSlot(bag - ns.NUM_BAGS) end
	local link = invID and GetInventoryItemLink("player", invID)
	if link then
		local name = link:match("%[(.-)%]")
		-- Forever's bank tabs hold a hidden placeholder "bag" marked (DNT);
		-- those are the bank's own slots, not a bag the player placed.
		if name and ns:IsBankBag(bag) and (name:find("%(DNT%)") or name:find("Bank Tab Bag")) then return "Default" end
		if name and name ~= "" then return name end
	end
	if ns:IsReagentBag(bag) then return "Reagent bag" end
	if ns:IsBankBag(bag) then return ("Bank bag %d"):format(bag - ns.NUM_BAGS) end
	return ("Bag %d"):format(bag)
end

-- Forever characters have a first and a last name. The plain UnitName API
-- returns only the first word, so try the richer APIs and accept a result
-- that looks like "First Last" (two words, both capitalised, no title
-- punctuation). Falls back to the first name.
function ns:DisplayName(unit)
	unit = unit or "player"
	local first = UnitName(unit) or "Unknown"
	local candidates = {}
	if C_PlayerInfo then
		for _, fn in ipairs({ "GetPlayerFullName", "GetFullName", "GetPlayerName" }) do
			if type(C_PlayerInfo[fn]) == "function" then
				local ok, v = pcall(C_PlayerInfo[fn], unit)
				if ok and type(v) == "string" then candidates[#candidates + 1] = v end
			end
		end
	end
	if type(UnitFullName) == "function" then
		local ok, v = pcall(UnitFullName, unit)
		if ok and type(v) == "string" then candidates[#candidates + 1] = v end
	end
	if type(GetUnitName) == "function" then
		local ok, v = pcall(GetUnitName, unit, false)
		if ok and type(v) == "string" then candidates[#candidates + 1] = v end
	end
	if type(UnitPVPName) == "function" then
		local ok, v = pcall(UnitPVPName, unit)
		if ok and type(v) == "string" then candidates[#candidates + 1] = v end
	end
	for _, v in ipairs(candidates) do
		local a, b = v:match("^(%S+) (%S+)$")
		if a and b and a == first and not b:find("[,%.]") and b:sub(1, 1) ~= b:sub(1, 1):lower() then
			return v
		end
	end
	return first
end

function ns:CharKey(name, realm)
	return (name or UnitName("player") or "Unknown") .. " - " .. (realm or GetRealmName() or "Unknown")
end

------------------------------------------------------------------------
-- Output
------------------------------------------------------------------------
local PREFIX = "|cfffac775BagSmith|r "
function ns:Print(fmt, ...)
	local msg = select("#", ...) > 0 and fmt:format(...) or tostring(fmt)
	local cf = DEFAULT_CHAT_FRAME or ChatFrame1
	cf:AddMessage(PREFIX .. msg)
end
function ns:Debug(fmt, ...)
	if ns.db and ns.db.debug then
		ns:Print("|cff8f8c83" .. (select("#", ...) > 0 and fmt:format(...) or tostring(fmt)) .. "|r")
	end
end

-- Money strings are formatted once per distinct value (bounded cache).
local moneyCache, moneyCount = {}, 0
function ns.Money(copper)
	if not copper or copper <= 0 then return "" end
	local s = moneyCache[copper]
	if not s then
		s = GetMoneyString(copper, true)
		if moneyCount > 400 then moneyCache, moneyCount = {}, 0 end
		moneyCache[copper] = s; moneyCount = moneyCount + 1
	end
	return s
end

------------------------------------------------------------------------
-- Events and signals
------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local handlers, signals = {}, {}
-- Handlers are wrapped: one failing handler must never stop the others, and
-- the first error of each kind is reported so a silent failure is impossible.
local reported = {}
function ns:Guard(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		ns.errorLog = ns.errorLog or {}
		if #ns.errorLog < 20 then ns.errorLog[#ns.errorLog + 1] = label .. ": " .. tostring(err) end
		if not reported[label] then
			reported[label] = true
			ns.errors = (ns.errors or 0) + 1
			ns:Print("|cffff6060Error in %s:|r %s", label, tostring(err))
			ns:Print("Type /bs errors to list them, and please report them.")
		end
	end
	return ok
end

frame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do ns:Guard(event, list[i], ...) end
end)
-- Events differ between clients; an unknown one must not stop the rest of
-- a handler from registering. Skipped names are listed by /bs check.
ns.skippedEvents = {}
function ns:On(event, fn)
	if not handlers[event] then
		local ok = pcall(frame.RegisterEvent, frame, event)
		if not ok then
			ns.skippedEvents[#ns.skippedEvents + 1] = event
			return false
		end
		handlers[event] = {}
	end
	table.insert(handlers[event], fn)
	return true
end
function ns:OnSignal(name, fn)
	signals[name] = signals[name] or {}
	table.insert(signals[name], fn)
end
function ns:Fire(name, ...)
	local list = signals[name]
	if not list then return end
	for i = 1, #list do ns:Guard(name, list[i], ...) end
end

------------------------------------------------------------------------
-- Combat-safe queue and next-frame coalescing
------------------------------------------------------------------------
local queue, order = {}, {}
-- (1.5.8) Longer tooltip lines wrap (Shweep: they took up too much of the screen). The game does the wrapping, since only
-- it knows the tooltip's font and size (beta1 broke lines by counting characters, and lines the game also wrapped came
-- out ragged): a line longer than TIP_SHORT visible characters is added with wrapping on, and the tooltip gets a minimum
-- width of TIP_WIDTH so wrapped lines sit at a natural width instead of squeezing to a short title. The width is reset
-- when the tooltip hides, so the game's own tooltips and other addons' are untouched. Short lines pass through as given.
-- Every BagSmith tooltip line goes through TipLine or TipText.
ns.TIP_SHORT, ns.TIP_WIDTH = 40, 280
local function visibleLen(s)
	return #(s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "WW"):gsub("|A.-|a", "WW"):gsub("|H.-|h", ""):gsub("|h", ""))
end
function ns.TipIsLong(text) return type(text) == "string" and visibleLen(text) > ns.TIP_SHORT end
function ns.TipWidth(tt)
	if not (tt and tt.SetMinimumWidth) or tt.bsMinWidth then return end
	tt:SetMinimumWidth(ns.TIP_WIDTH); tt.bsMinWidth = true
	if not tt.bsWidthHook and tt.HookScript then
		tt.bsWidthHook = true
		tt:HookScript("OnHide", function(self) if self.bsMinWidth then self.bsMinWidth = nil; self:SetMinimumWidth(0) end end)
	end
end
function ns.TipLine(tt, text, r, g, b, wrap, ...)
	if ns.TipIsLong(text) then ns.TipWidth(tt); return tt:AddLine(text, r, g, b, true, ...) end
	return tt:AddLine(text, r, g, b, wrap, ...)
end
function ns.TipText(tt, text, r, g, b, a, wrap, ...)
	if ns.TipIsLong(text) then ns.TipWidth(tt); return tt:SetText(text, r or 1, g or 1, b or 1, a or 1, true, ...) end
	return tt:SetText(text, r, g, b, a, wrap, ...)
end

-- (1.5.4) Escape closes a BagSmith window by running that window's own close action, what its close button does. A
-- small invisible stand-in goes on the game's Escape list (UISpecialFrames): it's shown while the window is, and when
-- Escape hides it, the close action runs. The game never hides the window itself, so a window holding a secure button
-- can wait out combat (its close action uses ns:Safely), and a window whose close does more than hide (What's New marks
-- itself seen; the Disenchant offer answers Ask Later) does that too. Hiding the whole interface (Alt+Z) isn't Escape.
function ns:CloseOnEscape(frame, close)
	if not (frame and UISpecialFrames and close) or frame.bsEscape then return end
	local name = (frame:GetName() or "BagSmithWindow") .. "Escape"
	local proxy = CreateFrame("Frame", name, UIParent)
	proxy:Hide()
	proxy:SetScript("OnHide", function(p)
		if p.syncing or p:IsShown() then return end   -- following the window, or hidden with the whole interface
		if frame:IsShown() then close() end
	end)
	frame:HookScript("OnShow", function() proxy.syncing = true; proxy:Show(); proxy.syncing = nil end)
	frame:HookScript("OnHide", function()
		if frame:IsShown() then return end              -- hidden with the whole interface, not closed
		proxy.syncing = true; proxy:Hide(); proxy.syncing = nil
	end)
	if frame:IsShown() then proxy.syncing = true; proxy:Show(); proxy.syncing = nil end
	table.insert(UISpecialFrames, name)
	frame.bsEscape = proxy
end
function ns:Safely(key, fn)
	if InCombatLockdown() then
		if not queue[key] then order[#order + 1] = key end
		queue[key] = fn
		return false
	end
	fn()
	return true
end
ns:On("PLAYER_REGEN_ENABLED", function()
	local pending, keys = queue, order
	queue, order = {}, {}
	for _, key in ipairs(keys) do
		local fn = pending[key]
		if fn then fn() end
	end
	ns:Fire("COMBAT_ENDED")
end)
ns:On("PLAYER_REGEN_DISABLED", function() ns:Fire("COMBAT_STARTED") end)

local nextFrame = {}
function ns:NextFrame(key, fn)
	if nextFrame[key] then return end
	nextFrame[key] = true
	C_Timer.After(0, function() nextFrame[key] = nil; fn() end)
end

------------------------------------------------------------------------
-- Tooltips are suppressed while BagSmith is faded for combat.
------------------------------------------------------------------------
function ns.TooltipsOK()
	return not (InCombatLockdown() and ns.db and ns.db.combatFade)
end
-- (1.6.0) Tooltips that explain BagSmith's own controls (buttons, the toolbar, column headers, the star, wallet and pouch
-- cells, the item menu's dots, section headers' numbers): off with Show Help Tips. Item, bag and currency tooltips, the
-- (i) icons and the Settings window's help always show (they use TooltipsOK).
function ns.HelpTipsOK()
	return ns.TooltipsOK() and not (ns.db and ns.db.helpTips == false)
end

------------------------------------------------------------------------
-- Small utilities
------------------------------------------------------------------------
function ns.Copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and ns.Copy(v) or v end
	return out
end
function ns.IndexOf(list, value)
	for i, v in ipairs(list) do if v == value then return i end end
	return nil
end
function ns.Move(list, from, to)
	if from == to or not list[from] or not list[to] then return false end
	local v = table.remove(list, from)
	table.insert(list, to, v)
	return true
end
-- Returns the value of `field` on whichever frame is under the cursor, if any.
function ns.FrameUnderCursor(field)
	local frames
	if GetMouseFoci then frames = GetMouseFoci() elseif GetMouseFocus then frames = { GetMouseFocus() } end
	for _, f in ipairs(frames or {}) do
		local cur = f
		while cur do
			if cur[field] ~= nil then return cur[field] end
			cur = cur.GetParent and cur:GetParent()
		end
	end
	return nil
end

function ns.ClassColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 0.8, 0.8, 0.8
end
