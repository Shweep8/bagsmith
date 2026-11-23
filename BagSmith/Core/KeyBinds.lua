--[[
	Core/KeyBinds.lua

	BagSmith's key bindings: its own section in the game's Keybindings
	(Bindings.xml uses a BagSmith category rather than the general AddOns
	group), and the Keybindings page in BagSmith's Settings, which edits the
	same bindings: Set Key captures the next key press (with Shift, Ctrl or
	Alt), Esc cancels, Clear removes it. Saved with the player's bindings.
--]]
local ADDON, ns = ...
local KB = {}
ns.KeyBinds = KB

BINDING_CATEGORY_BAGSMITH = "BagSmith"
BINDING_HEADER_BAGSMITH = "BagSmith"
BINDING_NAME_BAGSMITH_MARKJUNK = "Mark as Junk"
BINDING_NAME_BAGSMITH_TRAVEL = "Toggle Travel Mode"
BINDING_NAME_BAGSMITH_CURRENCY = "Toggle Currency Drawer"
BINDING_NAME_BAGSMITH_FAVORITE = "Favorite Item"
BINDING_NAME_BAGSMITH_CURRENCYITEM = "Track as Currency"
BINDING_NAME_BAGSMITH_MOVESECTION = "Move to Section"
BINDING_NAME_BAGSMITH_CONFIRMKEY = "Confirm Prompts (hold)"

KB.LIST = {
	{ "BAGSMITH_MARKJUNK", "Mark as Junk", "The item under the pointer, in either view." },
	{ "BAGSMITH_FAVORITE", "Favorite Item", "The item under the pointer, in either view." },
	{ "BAGSMITH_CURRENCYITEM", "Track as Currency", "The item under the pointer, in either view." },
	{ "BAGSMITH_MOVESECTION", "Move to Section", "Opens the item menu for the item under the pointer (the same as Alt+Left-click)." },
	{ "BAGSMITH_TRAVEL", "Toggle Travel Mode" },
	{ "BAGSMITH_CURRENCY", "Toggle Currency Drawer" },
	{ "CLICK BagSmithDisenchantButton:LeftButton", "Disenchant Next Item", "In the Disenchant Helper: the same as clicking its Disenchant button." },
	{ "BAGSMITH_CONFIRMKEY", "Confirm Prompts (hold)", "With Confirm set to Custom (Automations > Prompts): a yes/no box that appears while this key is held is confirmed." },
}
-- The custom confirm key: the binding runs on press and release, so BagSmith knows when it is held.
function BagSmith_ConfirmKey(keystate)
	local P = ns.Prompts
	if not P then return end
	P.customHeld = keystate == "down"
	P.customHeldAt = GetTime()
	if keystate == "up" then P.customUpSeen = true end
end

function BagSmith_ToggleTravel() if ns.ready then ns:ToggleTravel() end end
function BagSmith_ToggleCurrency() if ns.ready then ns.Window:Show(); ns.Drawer:Toggle() end end

-- A key's name spelled out: "CTRL-SHIFT-J" -> "Ctrl-Shift-J", "SPACE" ->
-- "Space". (The game's own GetBindingText abbreviates on this client:
-- "c-J".) Modifiers in the usual order, then the game's name for the key.
local MOD = { CTRL = "Ctrl", SHIFT = "Shift", ALT = "Alt", META = "Cmd" }
local ORDER = { "CTRL", "SHIFT", "ALT", "META" }
function KB:Pretty(key)
	if not key or key == "" then return nil end
	local mods, rest = {}, key
	while true do
		local m, tail = rest:match("^(%u+)%-(.+)$")
		if m and MOD[m] then mods[m] = true; rest = tail else break end
	end
	local parts = {}
	for _, m in ipairs(ORDER) do if mods[m] then parts[#parts + 1] = MOD[m] end end
	local name = _G["KEY_" .. rest]
	parts[#parts + 1] = (type(name) == "string" and name ~= "") and name or rest
	return table.concat(parts, "-")
end

-- The key bound to an action, spelled out ("Ctrl-J"), or nil.
function KB:Key(action)
	local key = GetBindingKey and GetBindingKey(action)
	if not key or key == "" then return nil end
	return KB:Pretty(key)
end

local function actionName(action)
	return _G["BINDING_NAME_" .. action] or (GetBindingName and GetBindingName(action)) or action
end

-- (1.10.1-beta1, Shweep: "will our settings update to show what their keybind is? so if not B", and "what if they
-- have a secondary keybind for it and there is a keybind for opening bags and reagent bag") Every key that opens
-- BagSmith in place of Blizzard's bags, spelled out ("Tab", "Shift-B"), each once: both keys of each of the game's
-- bag actions. A bag's own key counts when BagSmith stands in for that bag (Hooks.Covers: its hook on ToggleBag acts
-- for the same bags). An empty list when none has a key; nil where the game can't be asked (Settings then says B,
-- as before).
-- (1.10.1-beta2, Shweep's screenshot of Forever's own keys: Toggle Backpack on B and F12, Toggle Reagent Bag unbound,
-- Toggle Bag 1 to 4 on F8 to F11, Open All Bags on Shift-B) Toggle Backpack leads: its first key is the one a player
-- thinks of as the bag key. Beta1 led with Open All Bags and read "(Shift-B, B and 5 more)" on those defaults.
KB.BAG_ACTIONS = {   -- the game's action, and the bag its key toggles where it is one bag's
	{ "TOGGLEBACKPACK" }, { "OPENALLBAGS" },
	{ "TOGGLEREAGENTBAG1", 5 }, { "TOGGLEBAG1", 4 }, { "TOGGLEBAG2", 3 }, { "TOGGLEBAG3", 2 }, { "TOGGLEBAG4", 1 },
}
function KB:BagKeys()
	if type(GetBindingKey) ~= "function" then return nil end
	local out, seen = {}, {}
	for _, a in ipairs(KB.BAG_ACTIONS) do
		if not a[2] or (ns.Hooks and ns.Hooks.Covers(a[2])) then
			for _, key in ipairs({ GetBindingKey(a[1]) }) do
				local name = KB:Pretty(key)
				if name and not seen[name] then seen[name] = true; out[#out + 1] = name end
			end
		end
	end
	return out
end
-- The words for Settings > General: the setting's name with the main bag key in it, and its help line, which says
-- when there are others. The main key is the first of the list above (Toggle Backpack's, then Open All Bags', then a
-- single bag's) that isn't a bare function key: the game's stock second key for the backpack is F12 and for the bags
-- F8 to F11, so a player whose own key is on Open All Bags (Tab, say) with F12 left on Toggle Backpack reads Tab, not
-- F12. With nothing but function keys, the first of them.
KB.BAG_LABEL = "Open with the Bag Keybind (%s)"
function KB:MainBagKey(keys)
	for _, k in ipairs(keys) do if not k:match("^F%d+$") then return k end end
	return keys[1]
end
local function gameName(action, fallback)
	local name = actionName(action)
	return (type(name) == "string" and name ~= "" and name ~= action) and name or fallback
end
function KB:BagKeyWords()
	local keys = KB:BagKeys() or { "B" }
	local where = "You can still open BagSmith from the minimap button or /bs."
	if #keys == 0 then
		return KB.BAG_LABEL:format("Not Set"),
			("No key opens your bags right now. Set one in the game's Key Bindings, under %s or %s. %s"):format(
				gameName("TOGGLEBACKPACK", "Toggle Backpack"), gameName("OPENALLBAGS", "Open All Bags"), where)
	end
	local main = KB:MainBagKey(keys)
	return KB.BAG_LABEL:format(main),
		("Turn off to keep Blizzard's bags on %s%s. %s"):format(main, #keys > 1 and " and your other bag keys" or "", where)
end

-- Bind a key (the game's form, "ALT-CTRL-SHIFT-K") to an action, replacing
-- the action's old keys. Returns a message to show, or nil.
function KB:Set(action, key)
	if InCombatLockdown() then return "Key bindings can't be changed during combat." end
	local old = GetBindingAction and GetBindingAction(key)
	local previous = {}
	for _, k in ipairs({ GetBindingKey(action) }) do if k and k ~= "" then previous[#previous + 1] = k end end
	for _, k in ipairs(previous) do SetBinding(k, nil) end
	if SetBinding(key, action) == false then
		-- The game refused the key: put the old binding back, save nothing.
		for _, k in ipairs(previous) do SetBinding(k, action) end
		if old and old ~= "" then SetBinding(key, old) end
		return "That key can't be used for this."
	end
	SaveBindings(GetCurrentBindingSet())
	if old and old ~= "" and old ~= action then
		return ("%s was %s; it's now %s."):format(KB:Pretty(key), actionName(old), actionName(action))
	end
end
function KB:Clear(action)
	if InCombatLockdown() then return "Key bindings can't be changed during combat." end
	for _, k in ipairs({ GetBindingKey(action) }) do if k and k ~= "" then SetBinding(k, nil) end end
	SaveBindings(GetCurrentBindingSet())
end

-- Key capture: one frame, made once, that takes the next key press.
local MODIFIER = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true }
-- Stop waiting for a key (Settings closed, another page, another profile):
-- nothing is bound and nothing saved.
function KB:CancelCapture()
	local f = KB.capture
	if not f then return end
	local cb = f.done
	f.done, f.action = nil, nil
	f:EnableKeyboard(false); f:Hide()
	if cb then cb(nil) end
end
function KB:Capture(action, done)
	local f = KB.capture
	if not f then
		f = CreateFrame("Frame", "BagSmithKeyCapture", UIParent)
		f:SetAllPoints(UIParent); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:EnableMouse(false)
		f:SetScript("OnKeyDown", function(self, key)
			if MODIFIER[key] then return end
			self:EnableKeyboard(false); self:Hide()
			local cb, act = self.done, self.action
			self.done, self.action = nil, nil
			if key == "ESCAPE" then if cb then cb(nil) end return end
			local function down(fn) return fn and fn() end
			local full = (down(IsAltKeyDown) and "ALT-" or "") .. (down(IsControlKeyDown) and "CTRL-" or "") .. (down(IsShiftKeyDown) and "SHIFT-" or "")
				.. (down(IsMetaKeyDown) and "META-" or "") .. key
			-- Already bound to something else: say what would change, and ask.
			local existing = GetBindingAction and GetBindingAction(full)
			if existing and existing ~= "" and existing ~= act and ns.Confirm then
				local was, now = actionName(existing), actionName(act)
				ns.Confirm(nil, ("%s is bound to %s. Bind it to %s instead? %s will be unbound."):format(KB:Pretty(full), was, now, was),
					function() local msg = KB:Set(act, full); if cb then cb(msg or true) end end,
					function() if cb then cb(nil) end end)
				return
			end
			local msg = KB:Set(act, full)
			if cb then cb(msg or true) end
		end)
		f:Hide()
		KB.capture = f
	end
	f.action, f.done = action, done
	f:Show(); f:EnableKeyboard(true)
	if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(false) end
end
