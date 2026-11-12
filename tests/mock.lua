-- Minimal mock of the WoW client API, enough to load BagSmith and drive it.
local M = { childrenStartShown = true, allStartShown = true, combat = false, log = {}, frames = {}, hooks = {}, cvars = { combinedBags = "1" } }
_G.MOCK = M

local function noop() end
local function frameMethods(f)
	local shown = f.startShown or false
	f.scripts, f.events, f.points, f.children = {}, {}, {}, {}
	f.SetScript = function(self, k, fn) self.scripts[k] = fn end
	f.GetScript = function(self, k) return self.scripts[k] end
	f.HookScript = function(self, k, fn) local old = self.scripts[k]; self.scripts[k] = function(...) if old then old(...) end fn(...) end end
	f.RegisterEvent = function(self, e) if M.unknownEvents and M.unknownEvents[e] then error("Frame:RegisterEvent(): Attempt to register unknown event \"" .. e .. "\"") end self.events[e] = true end
	f.UnregisterEvent = function(self, e) self.events[e] = nil end
	f.UnregisterAllEvents = function(self) self.events = {} end
	f.RegisterForDrag, f.RegisterForClicks = noop, noop
	-- M.faithfulVisibility: like the game, OnShow/OnHide fire only when the
	-- frame actually becomes visible or stops being visible (a frame hidden
	-- while its window is closed gets no OnHide). Off by default.
	f.Show = function(self)
		if M.combat and self.protected then error("ADDON_ACTION_BLOCKED Show") end
		local was = M.faithfulVisibility and self:IsVisible()
		shown = true; self.lookHidden = false
		if self.scripts.OnShow and (not M.faithfulVisibility or (not was and self:IsVisible())) then self.scripts.OnShow(self) end
	end
	f.Hide = function(self)
		if M.combat and self.protected then error("ADDON_ACTION_BLOCKED Hide") end
		local was = M.faithfulVisibility and self:IsVisible()
		shown = false; self.lookHidden = true
		if self.scripts.OnHide and (not M.faithfulVisibility or was) then self.scripts.OnHide(self) end
	end
	f.IsShown = function() return shown end
	f.SetPoint = function(self, ...) if M.combat and self.protected then error("ADDON_ACTION_BLOCKED SetPoint") end self.points[#self.points + 1] = { ... } end
	f.ClearAllPoints = function(self) if M.combat and self.protected then error("ADDON_ACTION_BLOCKED ClearAllPoints") end self.points = {} end
	f.GetPoint = function(self, i) local p = self.points[i or 1]; if p then return unpack(p) end end
	f.GetNumPoints = function(self) return #self.points end
	f.IsVisible = function(self) local x = self; while x do if x.IsShown and not x:IsShown() then return false end x = x.parent end return true end
	f.SetSize = function(self, w, h) if M.combat and self.protected then error("ADDON_ACTION_BLOCKED SetSize") end self.w, self.h = w, h end
	f.SetWidth = function(self, w) self.w = w end
	f.SetHeight = function(self, h) self.h = h end
	f.GetWidth = function(self) return self.w or 600 end
	f.GetHeight = function(self) return self.h or 500 end
	f.SetAllPoints = noop
	f.SetParent = function(self, p) if M.combat and self.protected then error("ADDON_ACTION_BLOCKED SetParent") end self.parent = p end
	f.GetParent = function(self) return self.parent end
	f.SetID = function(self, id) self.id = id end
	f.GetID = function(self) return self.id or 0 end
	f.SetAlpha = function(self, a) self.alpha = a end
	f.GetAlpha = function(self) return self.alpha or 1 end
	f.EnableMouseWheel = noop
	f.SetBackdropColor = function(self, r, g, b, a) self.bgColor = { r, g, b, a } end
	f.SetBackdropBorderColor = function(self, r, g, b, a) self.borderColor = { r, g, b, a } end
	f.CreateMaskTexture = function(self) local mk = M.tex(); return mk end
	f.SetButtonState = function(self, s, locked) self.buttonState, self.stateLocked = s, locked end
	f.LockHighlight = function(self) self.highlightLocked = true end
	f.UnlockHighlight = function(self) self.highlightLocked = false end
	f.SetMinMaxValues = function(self, lo, hi) self.minV, self.maxV = lo, hi end
	f.SetValue = f.SetValue or function(self, v) self.value = v end
	f.GetMinMaxValues = function(self) return self.minV, self.maxV end
	f.SetTextInsets = function(self, l, r) self.insets = l .. "," .. r end
	f.IsMouseOver = f.IsMouseOver or function() return false end
	f.EnableMouse, f.SetClampedToScreen = noop, noop
	f.SetToplevel = function(self, v) self.toplevel = v and true or false end
	f.SetFrameStrata = function(self, v) self.strata = v end
	f.GetFrameStrata = function(self) return self.strata or "MEDIUM" end
	f.SetMovable = function(self, v) self.movable = v and true or false end
	f.IsMovable = function(self) return self.movable == true end
	f.Raise = function(self) M.raiseCount = (M.raiseCount or 0) + 1; self.raisedAt = M.raiseCount end
	f.StartMoving, f.StopMovingOrSizing = noop, noop
	f.SetBackdrop = noop   -- backdrop colors are recorded above (look checks)
	f.SetClipsChildren = function(self, on) self.clipsChildren = on end
	f.Enable = function(self) self.enabled = true end
	f.Disable = function(self) self.enabled = false end
	f.IsEnabled = function(self) return self.enabled ~= false end
	f.SetScale = function(self, s) self.scale = s end
	f.SetNormalTexture, f.SetPushedTexture, f.SetHighlightTexture = noop, noop, noop
	f.GetHighlightTexture = function() return M.tex() end
	f.GetNormalTexture = function() return M.tex() end
	f.GetPushedTexture = function() return M.tex() end
	f.SetScrollChild = function(self, c) self.child = c end
	f.SetVerticalScroll = function(self, v) self.verticalScroll = v end
	f.GetVerticalScroll = function(self) return self.verticalScroll or 0 end
	f.SetAutoFocus, f.ClearFocus, f.SetMaxLetters, f.SetFocus, f.SetNumeric, f.SetJustifyH = noop, noop, noop, noop, noop, noop
	f.SetMultiLine = f.SetMultiLine or noop
	f.EnableKeyboard = f.EnableKeyboard or function(self, on) self.keyboard = on end
	f.SetPropagateKeyboardInput = f.SetPropagateKeyboardInput or noop
	f.SetFontObject = f.SetFontObject or noop
	f.GetText = f.GetText or function(self) return self.text or "" end
	f.HighlightText = function(self) self.highlighted = true end
	f.attributes = {}
	f.SetAttribute = function(self, k, v) self.attributes[k] = v end
	f.GetAttribute = function(self, k) return self.attributes[k] end
	f.GetObjectType = function(self) return self.kind or "Frame" end
	f.GetName = function(self) return self.name end
	f.GetChildren = function(self) return unpack(self.children) end
	f.SetText = function(self, t) self.text = t end
	f.GetText = function(self) return self.text or "" end
	f.regions = {}
	-- Regions are remembered on their frame so the look checks can read them.
	f.CreateTexture = function(self, _, layer, _, sub) local t = M.tex(); t.parentFrame, t.layer, t.sublayer = self, layer, sub; self.regions[#self.regions + 1] = t; return t end
	f.CreateFontString = function(self) local s = M.fs(); s.parentFrame = self; self.regions[#self.regions + 1] = s; return s end
	f.icon, f.IconBorder, f.Count, f.Cooldown = M.tex(), M.tex(), M.fs(), M.tex()
	f.NewItemTexture, f.BattlepayItemTexture, f.UpgradeIcon, f.JunkIcon = M.tex(), M.tex(), M.tex(), M.tex()
	return f
end

function M.tex()
	local t = { SetTexture = noop, SetAtlas = noop, SetVertexColor = noop, SetSize = noop, SetPoint = noop,
		ClearAllPoints = noop, SetAllPoints = noop, SetTexCoord = noop,
		SetHeight = noop, SetWidth = noop, SetDesaturated = noop, shown = true }
	t.SetBlendMode = noop
	t.SetDesaturated = function(self, on) self.desaturated = on and true or false end
	-- Colors and alpha are recorded for the look checks.
	t.SetVertexColor = function(self, r, g, b, a) self.color = { r, g, b, a or 1 } end
	t.SetColorTexture = function(self, r, g, b, a) self.color = { r, g, b, a or 1 }; self.colorTexture = true end
	t.SetAlpha = function(self, a) self.alpha = a end
	t.GetAlpha = function(self) return self.alpha or 1 end
	t.SetDrawLayer = function(self, layer, sub) self.layer, self.sublayer = layer, sub end
	t.GetDrawLayer = function(self) return self.layer or "ARTWORK", self.sublayer or 0 end
	t.SetAtlas = function(self, a) self.atlas = a end
	t.SetTexture = function(self, path) self.texture = path end
	t.SetTexCoord = function(self, ...) self.texCoord = { ... } end
	t.SetParent = function(self, p) self.parentFrame = p end
	t.AddMaskTexture = function(self, mk) self.mask = mk end
	t.SetHorizTile, t.SetVertTile = noop, noop
	t.GetParent = function(self) return self.parentFrame end
	t.GetWidth = function(self) return self.w or 20 end
	t.GetHeight = function(self) return self.h or 14 end
	t.GetNumPoints = function(self) return #(self.points or {}) end
	t.GetPoint = function(self, i) local p = (self.points or {})[i or 1]; if p then return unpack(p) end end
	t.SetSize = function(self, w, h) self.w, self.h = w, h end
	t.SetPoint = function(self, ...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
	t.ClearAllPoints = function(self) self.points = {} end
	t.Hide = function(self) self.shown = false end
	t.Show = function(self) self.shown = true end
	t.IsShown = function(self) return self.shown end
	t.SetShown = function(self, v) self.shown = v and true or false end
	return t
end
function M.fs()
	local s = M.tex()
	s.SetText = function(self, t) self.text = t end
	s.GetText = function(self) return self.text end
	s.SetWordWrap, s.SetFontObject, s.SetNonSpaceWrap, s.SetJustifyV = noop, noop, noop, noop
	-- 1.7.0-beta11: the justification is recorded (a fontstring given a width centers its text unless set to LEFT)
	function s:SetJustifyH(j) self.justifyH = j end
	function s:GetJustifyH() return self.justifyH or "CENTER" end
	s.SetTextColor = function(self, r, g, b, a) self.textColor = { r, g, b, a or 1 } end
	s.GetTextColor = function(self) local c = self.textColor; if c then return c[1], c[2], c[3], c[4] end return 1, 1, 1, 1 end
	s.SetWidth = function(self, w) self.width = w end
	s.SetHeight = function(self, h) self.h = h end
	return s
end

function _G.CreateFrame(kind, name, parent, template)
	-- The real client starts every frame shown. The mock starts them hidden,
	-- except when a check asks for child frames to start shown like the client
	-- (M.childrenStartShown), so "hide, then put back as it was" behaves as in game.
	local startShown = M.allStartShown or (M.childrenStartShown and parent ~= nil and parent ~= _G.UIParent) or nil
	local f = frameMethods({ kind = kind, name = name, parent = parent, template = template, startShown = startShown })
	if parent and parent.children then parent.children[#parent.children + 1] = f end
	if template == "ContainerFrameItemButtonTemplate" then f.protected = true end
	if kind == "ScrollFrame" then f.ScrollBar = frameMethods({ kind = "Slider" }); f.ScrollBar.GetName = function() return nil end; f.ScrollBar.SetShown = function(self, v) if v then self:Show() else self:Hide() end end end
	if name then _G[name] = f end
	M.frames[#M.frames + 1] = f
	return f
end

-- Globals
_G.UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(1920, 1080)   -- a common screen, as GetScreenWidth reports
_G.BankFrame = CreateFrame("Frame", "BankFrame")
BankFrame.BankPanel = CreateFrame("Frame", nil, BankFrame)
BankFrame.BankPanel.PurchaseButton = CreateFrame("Button", nil, BankFrame.BankPanel)
BankFrame.BankPanel.PurchasePrompt = CreateFrame("Frame", nil, BankFrame.BankPanel)
BankFrame.BankPanel.PurchasePrompt.TabCostFrame = CreateFrame("Frame", nil, BankFrame.BankPanel.PurchasePrompt)
BankFrame.BankPanel.PurchasePrompt.TabCostFrame.PurchaseButton = CreateFrame("Button", nil, BankFrame.BankPanel.PurchasePrompt.TabCostFrame)
_G.ContainerFrameContainer = CreateFrame("Frame", "ContainerFrameContainer")
for i = 1, 13 do
	local cf = CreateFrame("Frame", "ContainerFrame" .. i)
	cf.SetBagID = function(self, id) self:SetID(id) end
	cf.hookSetIDBreaks = true
end
_G.ContainerFrameMixin = { SetBagID = function() end }
_G.ContainerFrame_GenerateFrame = function(frame, size, id) frame:SetBagID(id); frame:Show() end
_G.UpdateContainerFrameAnchors = function() end
_G.GameTooltip = { shown = false, owner = nil, SetOwner = function(self, o, anchor) self.owner = o; self.anchor = anchor; self.lines = {} end, AddDoubleLine = function(self, l, r) self.lines = self.lines or {}; self.lines[#self.lines + 1] = tostring(l) .. " " .. tostring(r) end, SetAnchorType = function(self, a) self.anchor = a end, IsOwned = function(self, o) return self.owner == o end, GetOwner = function(self) return self.owner end, SetBagItem = noop, Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end, IsShown = function(self) return self.shown end, SetText = noop, AddLine = function(self, l) self.lines = self.lines or {}; self.lines[#self.lines + 1] = tostring(l) end, SetHyperlink = noop, SetInventoryItem = noop }
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) M.log[#M.log + 1] = m end }
_G.UISpecialFrames = {}
_G.SOUNDKIT = { IG_BACKPACK_OPEN = 1, IG_BACKPACK_CLOSE = 2 }
_G.PlaySound, _G.CursorUpdate, _G.ResetCursor = noop, noop, noop
_G.SetItemButtonTexture, _G.SetItemButtonCount, _G.SetItemButtonQuality, _G.SetItemButtonDesaturated = noop, noop, noop, noop
_G.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
_G.NUM_CONTAINER_FRAMES = 13
_G.BACKPACK_TOOLTIP = "Backpack"
_G.Enum = { BagIndex = { Backpack = 0, ReagentBag = 5, Keyring = -1 }, TooltipDataType = { Item = 0 } }
-- The modern client's tooltip post-processing: setting an item tooltip (or
-- rebuilding it, M.rebuildTooltip) runs every registered post-call.
M.tipPost = {}
_G.TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) if kind == 0 then M.tipPost[#M.tipPost + 1] = fn end end }
local function runTipPost() for _, fn in ipairs(M.tipPost) do fn(GameTooltip, {}) end end
GameTooltip.SetBagItem = function(self, bag, slot) self.lines = {}; self.item = { bag = bag, slot = slot }; runTipPost() end
GameTooltip.SetHyperlink = function(self, link) self.lines = {}; self.item = { link = link }; runTipPost() end
-- A rebuild: the game sets the tooltip again from scratch (lines added once on hover are lost).
function M.rebuildTooltip() if GameTooltip.item then GameTooltip.lines = {}; runTipPost() end end
_G.Constants = { InventoryConstants = { NumBankBagSlots = 8 } }
_G.InCombatLockdown = function() return M.combat end
_G.GetBuildInfo = function() return "1.60.1", "70009", "Sep 22 2026", 16001 end
_G.C_AddOns = { GetAddOnMetadata = function(_, k) return ({ Version = "0.1.0", ["X-Game"] = "Camelot", ["X-Family"] = "Mainline" })[k] end }
_G.C_Timer = { After = function(_, fn) M.timers = M.timers or {}; M.timers[#M.timers + 1] = fn end,
	NewTimer = function(secs, fn) local t = { secs = secs, fn = fn, cancelled = false }; t.Cancel = function(self) self.cancelled = true; for i = #(M.newTimers or {}), 1, -1 do if M.newTimers[i] == self then table.remove(M.newTimers, i) end end end; M.newTimers = M.newTimers or {}; M.newTimers[#M.newTimers + 1] = t; return t end }
function M.tick() for _, f in ipairs(M.frames) do local s = f.scripts and f.scripts.OnUpdate; if s then s(f, 0.016) end end end
function M.elapse() local ts = M.newTimers or {}; M.newTimers = {}; for _, t in ipairs(ts) do if not t.cancelled then t.fn() end end end
-- A steady clock: time() only moves when a test moves it (M.now), so nothing
-- depends on the wall clock ticking over a second mid-test (the Recent
-- section counts items first seen after the session began).
M.now = 1790000000
_G.time = function(t) if t then return os.time(t) end return M.now end
_G.UnitName = function() return ((M.charName or "Aldren Thorne"):match("^(%S+)")) end
_G.GetRealmName = function() return "Forever" end
_G.GetMoney = function() return 123456 end
_G.GetMoneyString = function(c) return tostring(c) .. "c" end
_G.GetInventoryItemLink = function(_, inv) local bag = inv - 19; local n = M.bagNames[bag]; return n and ("|Hitem:1|h[" .. n .. "]|h") or nil end
_G.debugstack = function() return debug.traceback() end
_G.C_CVar = { GetCVarBool = function(k) return M.cvars[k] == "1" end, SetCVar = function(k, v) M.cvars[k] = v end }
_G.SlashCmdList = {}
_G.PanelTemplates_SelectTab = function(tab) tab.tabSelected = true end
_G.PanelTemplates_DeselectTab = function(tab) tab.tabSelected = false end
-- GetTime (the session clock) has its own counter, so it never moves time().
M.gameTime = 1000
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.IsAltKeyDown = _G.IsAltKeyDown or function() return false end
_G.IsShiftKeyDown = _G.IsShiftKeyDown or function() return false end
_G.GetTime = function() M.gameTime = M.gameTime + 0.1; return M.gameTime end
M.settingsCategories = {}
_G.Settings = {
	RegisterCanvasLayoutCategory = function(frame, name) return { frame = frame, name = name } end,
	RegisterAddOnCategory = function(cat) M.settingsCategories[#M.settingsCategories + 1] = cat end,
}
_G.SettingsPanel = nil
_G.StaticPopupDialogs = {}
M.spdTable = _G.StaticPopupDialogs
_G.ColorPickerFrame = frameMethods({}); ColorPickerFrame.SetupColorPickerAndShow = function(self, info) M.picker = info end; ColorPickerFrame.GetColorRGB = function() return M.pickRGB and M.pickRGB[1] or 1, M.pickRGB and M.pickRGB[2] or 0, M.pickRGB and M.pickRGB[3] or 0 end
_G.strsplit = function(d, s) local out = {}; for p in (s .. d):gmatch("(.-)" .. d:gsub("%p", "%%%0")) do out[#out + 1] = p end return unpack(out) end

function _G.hooksecurefunc(a, b, c)
	local tbl, name, fn = _G, a, b
	if type(a) == "table" then tbl, name, fn = a, b, c end
	if type(a) == "table" and a.hookSetIDBreaks then a[name] = nil; return end   -- this client: hooking any frame method leaves it nil
	local orig = tbl[name] or noop
	tbl[name] = function(...) local r = { orig(...) }; fn(...); return unpack(r) end
	M.hooks[name] = true
end
-- Each outermost bag call is a new key press, so it starts on a new frame:
-- timers queued by the last press (C_Timer.After(0)) have run, as in game.
local function press(fn)
	return function(...)
		if (M.pressDepth or 0) == 0 then M.runTimers() end
		M.pressDepth = (M.pressDepth or 0) + 1
		local r = { pcall(fn, ...) }
		M.pressDepth = M.pressDepth - 1
		if not r[1] then error(r[2], 0) end
		return unpack(r, 2)
	end
end
_G.OpenBackpack, _G.CloseBackpack, _G.OpenBag, _G.CloseBag = noop, noop, noop, noop
_G.OpenAllBags = press(function() OpenBackpack(); for i = 1, 5 do OpenBag(i) end end)
_G.CloseAllBags = press(function() CloseBackpack(); for i = 1, 5 do CloseBag(i) end M.blizOpen = false end)
_G.ToggleBackpack = press(function() if M.blizOpen then CloseBackpack() else OpenBackpack() end end)
_G.ToggleBag = press(function(i) if M.blizOpen then CloseBag(i) else OpenBag(i) end end)
_G.ToggleAllBags = press(function()
	local was = M.blizOpen
	if was then CloseAllBags() else OpenAllBags() end
	M.blizOpen = not was
end)

-- Bags: bag -> list of slots; each slot nil or { id, name, q, count, ilvl, type, sub, class, subclass, price, equip }
M.bags = { [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {} }
M.sizes = { [0] = 16, [1] = 6, [2] = 6, [3] = 6, [4] = 0, [5] = 6 }
M.bagNames = { [1] = "Linen Bag", [2] = "Linen Bag", [3] = "Small Brown Pouch" }
M.uncached = {}
local nextGuid = 1
function M.put(bag, slot, item)
	item.guid = item.guid or ("guid" .. nextGuid); nextGuid = nextGuid + 1
	M.bags[bag][slot] = item
end
M.unknownEvents = { PLAYERBANKBAGSLOTS_CHANGED = true }
M.pickups = {}
M.bankSlots = 2
_G.C_Bank = {
	FetchNumPurchasedBankTabs = function(bt) return M.bankSlots end,
	FetchMaxNumBankTabs = function() return 8 end,
	FetchNextPurchasableBankTabData = function() return { tabCost = (M.bankSlots + 1) * 1000 } end,
	CanPurchaseBankTab = function() return M.bankSlots < 8 end,
	PurchaseBankTab = function(bt) M.bankSlots = M.bankSlots + 1; M.purchased = (M.purchased or 0) + 1 end,
	CloseBankFrame = function() M.bankClosed = (M.bankClosed or 0) + 1 end,
}
_G.GetInventoryItemTexture = function(_, inv) return inv == 25 and 123 or nil end
_G.PutItemInBag = function(inv) M.putInBag = inv end
_G.PickupBagFromSlot = function(inv) M.pickedBag = inv end
_G.StaticPopup_Show = function(which, arg) M.popup = { which = which, arg = arg } end
_G.YES, _G.NO = "Yes", "No"
_G.CursorHasItem = function() return M.cursorItem ~= nil end
_G.GetCursorInfo = function() if M.cursorItem then return "item", M.cursorItem end end
_G.C_Container = {
	PickupContainerItem = function(bag, slot) M.pickups[#M.pickups + 1] = bag .. ":" .. slot end,
	GetContainerNumSlots = function(bag) return M.sizes[bag] or 0 end,
	GetContainerNumFreeSlots = function(bag)
		local used = 0
		for _ in pairs(M.bags[bag] or {}) do used = used + 1 end
		return (M.sizes[bag] or 0) - used, bag == 5 and 0 or 0
	end,
	GetContainerItemInfo = function(bag, slot)
		local it = M.bags[bag] and M.bags[bag][slot]
		if not it then return nil end
		return { itemID = it.id, hyperlink = "|cff00ff00|Hitem:" .. it.id .. "|h[" .. it.name .. "]|h|r", iconFileID = 1,
			quality = it.q, stackCount = it.count or 1, isLocked = it.locked or false, isBound = it.bound or false, hasNoValue = (it.price or 0) == 0 }
	end,
	ContainerIDToInventoryID = function(bag) return 19 + bag end,
	SortBags = noop,
	GetContainerFreeSlots = function(bag)
		local out = {}
		for s = 1, (M.sizes[bag] or 0) do if not (M.bags[bag] and M.bags[bag][s]) then out[#out + 1] = s end end
		return out
	end,
	GetContainerItemQuestInfo = function(bag, slot) local it = M.bags[bag] and M.bags[bag][slot]; return { isQuestItem = it and it.quest or false } end,
}
_G.C_Item = {
	GetItemInfo = function(link)
		local id = tonumber(tostring(link):match("item:(%d+)")) or link
		if M.uncached[id] then return nil end
		for bag, slots in pairs(M.bags) do
			for _, it in pairs(slots) do
				if it.id == id then
					return it.name, link, it.q, it.ilvl, it.req or 0, it.type, it.sub, (M.maxStack and M.maxStack[id]) or 20, it.equip or "", 1, it.price or 0,
						it.class, it.subclass, it.bind or 0, 0, nil, it.craftReagent or false
				end
			end
		end
		return nil
	end,
	GetItemQualityColor = function(q) return 1, 1, 1 end,
	GetItemFamily = function(id) return 0 end,
	GetItemMaxStackSizeByID = function(id) return (M.maxStack and M.maxStack[id]) or 20 end,
	GetItemInfoInstant = function(id)
		for _, slots in pairs(M.bags) do for _, it in pairs(slots) do
			if it.id == id and it.class then return it.id, it.type, it.sub, it.equip or "", 1, it.class, it.subclass end
		end end
		return nil
	end,
	GetDetailedItemLevelInfo = function(link) return nil end,
	RequestLoadItemDataByID = noop,
	GetItemGUID = function(loc) return loc.item and loc.item.guid end,
	DoesItemExist = function(loc) return loc.item ~= nil end,
}
_G.ItemLocation = { CreateFromBagAndSlot = function(self, bag, slot) return { item = M.bags[bag] and M.bags[bag][slot] } end }

-- Addon loading
function M.loadAddon(root)
	local ns = {}
	for line in io.lines(root .. "/BagSmith.toc") do
		if line:match("%.lua%s*$") and not line:match("^#") then
			local path = root .. "/" .. line:gsub("\\", "/"):gsub("%s+$", "")
			local chunk, err = loadfile(path)
			assert(chunk, err)
			chunk("BagSmith", ns)
		end
	end
	return ns
end

function M.fire(event, ...)
	for _, f in ipairs(M.frames) do
		if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
	end
end

function M.runTimers()
	local t = M.timers or {}; M.timers = {}
	for _, fn in ipairs(t) do fn() end
end


-- ---- Additions for the full MVP ----
_G.UnitClass = function() return "Warrior", "WARRIOR" end
_G.UnitLevel = function() return 23 end
_G.UnitIsDead = function() return false end
_G.RAID_CLASS_COLORS = { WARRIOR = { r = .78, g = .61, b = .43 }, PRIEST = { r = 1, g = 1, b = 1 } }
_G.CLASS_ICON_TCOORDS = { WARRIOR = { 0, .25, 0, .25 }, PRIEST = { .5, .75, .25, .5 } }
_G.NUM_BANKGENERIC_SLOTS = 48
_G.BANK_CONTAINER = -1
_G.BreakUpLargeNumbers = function(n) return tostring(n) end
_G.IsModifiedClick = function() return false end
_G.ChatEdit_InsertLink = function(l) M.lastLink = l; return true end
_G.GetCursorPosition = function() return 100, 100 end
UIParent.GetEffectiveScale = function() return 1 end
_G.Minimap = CreateFrame("Frame", "Minimap"); Minimap.GetCenter = function() return 0, 0 end; Minimap.GetEffectiveScale = function() return 1 end; Minimap.w = 140
local ATLASES = { ["bags-item-slot"] = { width = 64 }, ["collections-background-tile"] = { width = 256 }, ["collections-background-corner"] = { width = 96 } }
_G.GetScreenWidth = function() return 1920 end
_G.C_Texture = { GetAtlasInfo = function(name) return ATLASES[name] end }
_G.C_NewItems = { IsNewItem = function(bag, slot) return M.newItems and M.newItems[bag .. ":" .. slot] or false end, RemoveNewItem = function(bag, slot) if M.newItems then M.newItems[bag .. ":" .. slot] = nil end end }
_G.UnitPVPName = function() return M.pvpName or M.charName or "Aldren Thorne" end
M.currencies = { { name = "Merchant's Favor", id = 3402, quantity = 85, icon = 7, quality = 3 }, { name = "Honor", id = 1901, quantity = 1250, icon = 8, quality = 4 } }
_G.C_CurrencyInfo = {
	GetCurrencyListSize = function() return #M.currencies + 1 end,
	GetCurrencyListInfo = function(i)
		if i == 1 then return { name = "Header", isHeader = true, isHeaderExpanded = true } end
		local c = M.currencies[i - 1]
		return c and { name = c.name, isHeader = false, quantity = c.quantity, iconFileID = c.icon, quality = c.quality, currencyID = c.id }
	end,
	ExpandCurrencyList = noop,
	-- (1.7.0-beta14, by design) the game's Show on Backpack picks: none unless a test sets M.backpackPicks (BagSmith now
	-- pins new picks when the bags open, so a pick in every test would pin a currency in every test)
	GetBackpackCurrencyInfo = function(i) local id = M.backpackPicks and M.backpackPicks[i]; return id and { currencyTypesID = id } or nil end,
}
_G.C_Container.SortBankBags = noop
M.sizes[-1] = 48
for i = 6, 13 do M.sizes[i] = 0; M.bags[i] = {} end
M.bags[-1] = {}
-- frame extras used by the full UI
local oldCreate = _G.CreateFrame
_G.CreateFrame = function(kind, name, parent, template)
	local f = oldCreate(kind, name, parent, template)
	f.SetResizable, f.StartSizing = noop, noop
	f.SetResizeBounds = function(self, ...) self.resizeBounds = { ... } end
	f.GetLeft = function() return 400 end
	f.GetBottom = function() return 200 end
	f.GetTop = function() return 700 end
	f.GetRight = function(self) return 400 + (self.w or 600) end
	f.GetCenter = function() return 500, 300 end
	f.GetEffectiveScale = function() return 1 end
	f.SetChecked = function(self, v) self.checked = v end
	f.GetChecked = function(self) return self.checked end
	f.SetFrameLevel, f.SetHitRectInsets = function(self, l) self.level = l end, noop
	f.GetFrameLevel = function(self) return self.level or 1 end
	f.SetShown = function(self, v) if v then self:Show() else self:Hide() end end
	f.CreateAnimationGroup = function()
		local g = { Stop = noop, Play = noop, IsPlaying = function() return false end, SetToFinalAlpha = noop, SetScript = noop }
		g.CreateAnimation = function() return { SetDuration = noop, SetSmoothing = noop, SetOffset = noop, SetFromAlpha = noop, SetToAlpha = noop, SetStartDelay = noop, SetOrder = noop } end
		return g
	end
	-- (for LibDBIcon's button)
	f.SetFixedFrameStrata, f.SetFixedFrameLevel = noop, noop
	return f
end
-- Each fresh mock is a fresh client: embedded libraries load anew.
_G.LibStub = nil
-- The previous boot's world is garbage now; free it before the next one (the
-- suite boots the addon well over a hundred times).
collectgarbage("collect")
local oldTex, oldFs = M.tex, M.fs
M.tex = function()
	local t = oldTex(); t.GetTexture = noop
	t.GetVertexColor = function(self) local c = self.color or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
	t.SetSnapToPixelGrid, t.SetTexelSnappingBias = noop, noop
	return t
end
M.fs = function() local s = oldFs(); s.GetStringWidth = function(self) return #tostring(self.text or "") * 6 end; s.GetStringHeight = function(self) local w = self.width or 300; local n = #tostring(self.text or '') * 6; return 14 * math.max(1, math.ceil(n / math.max(w, 1))) end; return s end
UIParent.GetWidth = function() return 1920 end

-- The game's equipment sets (opt in: M.installEquipmentSets(); tests call
-- M.removeEquipmentSets() when done). Locations use the game's encoding:
-- M.bagLoc(bag, slot), M.bankBagLoc(bag, slot), M.wornLoc(invSlot); -1 is
-- missing, 0 empty, 1 ignored. Nothing fires on its own: BagSmith refreshes
-- after its own calls, and tests fire EQUIPMENT_SETS_CHANGED for outside ones.
function M.bagLoc(bag, slot) return 0x00100000 + 0x00200000 + bag * 256 + slot end
function M.bankBagLoc(bag, slot) return 0x00400000 + 0x00200000 + (bag - 5) * 256 + slot end
function M.wornLoc(inv) return 0x00100000 + inv end
function M.installEquipmentSets()
	M.eqSets, M.eqNext, M.eqCalls, M.eqIgnore, M.worn = {}, 0, {}, {}, M.worn or {}
	local function log(...) M.eqCalls[#M.eqCalls + 1] = { ... } end
	local function count() local n = 0; for _ in pairs(M.eqSets) do n = n + 1 end; return n end
	local function snapshot()
		local slots = {}
		for inv = 1, 19 do
			if M.eqIgnore[inv] then slots[inv] = 1
			elseif M.worn[inv] then slots[inv] = M.wornLoc(inv) else slots[inv] = 0 end
		end
		return slots
	end
	_G.C_EquipmentSet = {
		CanUseEquipmentSets = function() return true end,
		GetNumEquipmentSets = count,
		GetEquipmentSetIDs = function() local t = {}; for id in pairs(M.eqSets) do t[#t + 1] = id end; table.sort(t); return t end,
		GetEquipmentSetInfo = function(id)
			local s = M.eqSets[id]; if not s then return nil end
			return s.name, s.icon, id, s.isEquipped or false, 0, 0, 0, 0, 0
		end,
		GetEquipmentSetID = function(name) for id, s in pairs(M.eqSets) do if s.name == name then return id end end end,
		GetItemLocations = function(id) local s = M.eqSets[id]; if not s then return nil end; local t = {}; for k, v in pairs(s.slots) do t[k] = v end; return t end,
		GetIgnoredSlots = function(id) local s = M.eqSets[id]; local t = {}; for k, v in pairs(s and s.slots or {}) do t[k] = v == 1 end; return t end,
		ClearIgnoredSlotsForSave = function() log("clearIgnored"); M.eqIgnore = {} end,
		IgnoreSlotForSave = function(slot) log("ignore", slot); M.eqIgnore[slot] = true end,
		UnignoreSlotForSave = function(slot) log("unignore", slot); M.eqIgnore[slot] = nil end,
		CreateEquipmentSet = function(name, icon)
			log("create", name, icon)
			M.eqSets[M.eqNext] = { name = name, icon = icon or 134400, slots = snapshot() }
			M.eqNext = M.eqNext + 1
		end,
		SaveEquipmentSet = function(id, icon) log("save", id); local s = M.eqSets[id]; if s then s.slots = snapshot() end end,
		ModifyEquipmentSet = function(id, name, icon) log("modify", id, name, icon); local s = M.eqSets[id]; if s then s.name = name; s.icon = icon or s.icon end end,
		DeleteEquipmentSet = function(id) log("delete", id); M.eqSets[id] = nil end,
		UseEquipmentSet = function(id) log("use", id); return M.eqUseResult ~= false end,
		PickupEquipmentSet = function(id) log("pickup", id); M.cursorSet = id end,
		EquipmentSetContainsLockedItems = function() return M.eqLocked and true or false end,
	}
	_G.MAX_EQUIPMENT_SETS_PER_PLAYER = 10
end
-- A set as the game would hold it: slots = { [invSlot] = location }.
function M.addSet(name, slots, icon)
	local id = M.eqNext
	M.eqSets[id] = { name = name, icon = icon or 134400, slots = slots or {} }
	M.eqNext = M.eqNext + 1
	return id
end
function M.removeEquipmentSets() _G.C_EquipmentSet = nil; _G.MAX_EQUIPMENT_SETS_PER_PLAYER = nil; M.eqSets = nil end
M.fire_ = M.fire

return M
