local ADDON, ns = ...
--[[
	Prompts: auto-confirming the game's yes/no boxes (1.2.0).

	Some actions bring up a Blizzard confirmation (equipping a bind-on-equip
	piece, using a bind-on-use item, replacing an enchant). With the setting
	on, BagSmith clicks Yes on the kinds you choose, one frame after the box
	appears, the way the AutoNod addon does. Scope is the point: by default it
	only confirms a box that follows a BagSmith action (equipping a gear set,
	clicking an item in the bag, the Disenchant Helper's cast); the sub-setting
	widens it to those boxes wherever they come from. Holding Shift keeps a box
	open. The one dialog whose Yes is a protected call is never touched.
	Off by default; nothing here runs until it is turned on.
]]
local P = {}
ns.Prompts = P

-- The kinds, each with the StaticPopup names it covers and a setting key.
P.GROUPS = {
	{ key = "autoConfirmEquip", label = "Equipping Bind-on-Equip Gear", which = { "EQUIP_BIND" } },
	{ key = "autoConfirmUse", label = "Using or Looting an Item That Binds", which = { "USE_BIND", "ACTION_WILL_BIND_ITEM", "LOOT_BIND" } },
	{ key = "autoConfirmEnchant", label = "Replacing or Binding With an Enchant", which = { "REPLACE_ENCHANT", "TRADE_REPLACE_ENCHANT", "BIND_ENCHANT" } },
	{ key = "autoConfirmRoll", label = "Loot Rolls", which = { "CONFIRM_LOOT_ROLL" } },
}
-- Which BagSmith actions a box may follow, each with its setting key.
P.SOURCES = {
	{ key = "autoConfirmSrcGear", label = "Equipping a Gear Set", what = "gear set" },
	{ key = "autoConfirmSrcItem", label = "Clicking an Item in the Bag", what = "item click" },
	{ key = "autoConfirmSrcJunk", label = "Selling Junk at a Vendor", what = "sell junk" },
	{ key = "autoConfirmSrcDE", label = "The Disenchant Helper", what = "disenchant" },
}
local sourceKey = {}
for _, s in ipairs(P.SOURCES) do sourceKey[s.what] = s.key end
-- The key that must be held for a yes: "always" means none. Shift as the keep-it-open escape applies
-- only in that mode (in the Shift mode it means the opposite).
P.KEYS = { { "always", "Always" }, { "shift", "While Holding Shift" }, { "ctrl", "While Holding Ctrl" }, { "custom", "Custom" } }
P.CUSTOM_HOLD_CAP = 5   -- seconds: a press with no release seen (a client that never reports the release) still ends
function P:CustomKey() return ns.KeyBinds and ns.KeyBinds:Key("BAGSMITH_CONFIRMKEY") or nil end
function P:CustomHeld()
	if not self.customHeld then return false end
	if not self.customUpSeen and (GetTime() - (self.customHeldAt or 0)) > self.CUSTOM_HOLD_CAP then return false end
	return true
end
local keyDown = { shift = function() return IsShiftKeyDown and IsShiftKeyDown() end, ctrl = function() return IsControlKeyDown and IsControlKeyDown() end, custom = function() return P:CustomHeld() end }
-- Its Yes calls a protected function (ADDON_ACTION_BLOCKED): never clicked.
P.PROTECTED = { REPLACE_TRADESKILL_ENCHANT = true }
P.ACTION_WINDOW = 3   -- seconds after a BagSmith action during which a box counts as its follow-up

local groupOf = {}
for _, g in ipairs(P.GROUPS) do for _, w in ipairs(g.which) do groupOf[w] = g end end
P.groupOf = groupOf

-- BagSmith's own actions stamp the clock; a box inside the window is theirs.
function ns.MarkAction(what)
	P.lastAction = GetTime()
	P.lastActionWhat = what
end
function P:InScope()
	if not ns.db then return false end
	if ns.db.autoConfirmEverywhere then return true end
	if self.lastAction == nil or (GetTime() - self.lastAction) > self.ACTION_WINDOW then return false end
	local k = sourceKey[self.lastActionWhat]
	if k and ns.db[k] == false then return false end   -- that kind of BagSmith action is not one you want confirmed
	return true
end
function P:Enabled() return ns.db ~= nil and ns.db.autoConfirm == true end

-- Why a box was or was not confirmed: the last decision, for /bs debug and the tests.
function P:Decide(which)
	if not self:Enabled() then return false, "off" end
	if self.PROTECTED[which] then return false, "protected" end
	local g = groupOf[which]
	if not g then return false, "not-listed" end
	if not ns.db[g.key] then return false, "group-off" end
	local mode = ns.db.autoConfirmKey or "always"
	if mode == "always" then
		if IsShiftKeyDown and IsShiftKeyDown() then return false, "shift" end
	else
		if mode == "custom" and not self:CustomKey() then return false, "no-key" end   -- Custom with no key bound never confirms
		local down = keyDown[mode]
		if not (down and down()) then return false, "key-not-held" end
	end
	if not self:InScope() then return false, "outside" end
	return true, g.key
end

-- One frame after a box shows (it is fully set up by then), click its Yes.
function P:OnShown(which)
	-- every showing of a kind retires that kind's pending callback, allowed or not: a box shown under Shift must
	-- not be confirmed by the callback of the box it replaced
	self.generations = self.generations or {}
	self.generations[which] = (self.generations[which] or 0) + 1
	local gen = self.generations[which]
	local ok, why = self:Decide(which)
	self.last = { which = which, confirmed = ok, why = why, at = GetTime() }
	if not ok then return end
	-- the box this decision was about: its frame, its words and its data, so a replacement is not confirmed on its behalf
	local name0 = StaticPopup_Visible and StaticPopup_Visible(which)
	local dialog0 = name0 and _G[name0]
	local text0 = dialog0 and dialog0.text and dialog0.text.GetText and dialog0.text:GetText() or nil
	local data0, data20 = dialog0 and dialog0.data, dialog0 and dialog0.data2
	local f = C_Timer and C_Timer.After or function(_, fn) fn() end
	f(0, function()
		if gen ~= (self.generations[which] or 0) then return end   -- a newer box of this kind took over this decision
		local okNow, whyNow = self:Decide(which)              -- the full decision again, at the moment of clicking
		if not okNow then self.last = { which = which, confirmed = false, why = whyNow, at = GetTime(), deferred = true }; return end
		local name = StaticPopup_Visible and StaticPopup_Visible(which)
		local dialog = name and _G[name]
		if not dialog or not dialog:IsShown() then return end
		if dialog0 and dialog ~= dialog0 then return end       -- not the frame the decision was made on
		local item = dialog.text and dialog.text.GetText and dialog.text:GetText() or ""
		if text0 ~= nil and item ~= text0 then self.last = { which = which, confirmed = false, why = "replaced", at = GetTime() }; return end
		if dialog.data ~= data0 or dialog.data2 ~= data20 then self.last = { which = which, confirmed = false, why = "replaced", at = GetTime() }; return end
		if type(StaticPopup_OnClick) ~= "function" then return end
		local okClick = pcall(StaticPopup_OnClick, dialog, 1)
		if okClick then
			self.confirmed = (self.confirmed or 0) + 1
			local g = groupOf[which]
			-- never silent: one chat line per confirmed box
			ns:Print("Confirmed for you: %s%s", g and g.label:lower() or which:lower(), item ~= "" and (" (" .. item:gsub("|n", " ") .. ")") or "")
			self.lastConfirmed = { which = which, text = item }
		end
	end)
end

-- Another addon doing the same job: a note on the settings page, nothing more.
function P:AutoNodPresent()
	local A = C_AddOns
	if A and type(A.IsAddOnLoaded) == "function" then local ok, loaded = pcall(A.IsAddOnLoaded, "AutoNod"); return ok and loaded == true end
	if type(IsAddOnLoaded) == "function" then local ok, loaded = pcall(IsAddOnLoaded, "AutoNod"); return ok and loaded == true end
	return false
end

-- The post-hook is installed once, at readiness, and does nothing while the setting is off.
local hooked = false
function P:Install()
	if hooked or type(hooksecurefunc) ~= "function" or type(StaticPopup_Show) ~= "function" then return end
	hooked = true
	hooksecurefunc("StaticPopup_Show", function(which) P:OnShown(which) end)
end
ns:OnSignal("ADDON_READY", function() P:Install() end)
