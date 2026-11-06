--[[
	BagSmith - Core/Slash.lua
	/bagsmith and /bs commands.
--]]

local ADDON, ns = ...

local function dump()
	ns:Scan()
	ns:Print("Client: interface %d, build %s, game %s, forever=%s", ns.interface, tostring(ns.build),
		tostring(ns.gameToken), tostring(ns.isForever))
	ns:Print("Bags: %s  reagent slot=%s  keyring=%s", table.concat(ns.BAGS, ","),
		tostring(ns.HAS_REAGENT_SLOT), tostring(ns.KEYRING))
	for _, bag in ipairs(ns.BAGS) do
		local info = ns.bagInfo[bag]
		if info then
			ns:Print("  bag %d %s: %d slots, %d free, family 0x%X", bag, info.name, info.size, info.free, info.family)
		end
	end
	ns:Print("Items (bag/slot  id  class/subclass  instant  quest  reagent  category  name):")
	for _, rec in ipairs(ns.items) do
		local ic, is = "?", "?"
		if C_Item.GetItemInfoInstant then
			local ok, _, _, _, _, _, a, b = pcall(C_Item.GetItemInfoInstant, rec.itemID)
			if ok then ic, is = tostring(a), tostring(b) end
		end
		ns:Print("  %d/%d  %d  %s/%s  %s/%s  %s  %s  %s  %s x%d", rec.bag, rec.slot, rec.itemID, tostring(rec.classID), tostring(rec.subclassID),
			ic, is, rec.isQuest and "quest" or "-", rec.isCraftingReagent and "reagent" or "-", tostring(rec.cat), rec.name, rec.count)
	end
	if ns.pendingInfo then
		ns:Print("Some item data is still loading. Run the dump again in a moment.")
	end
end

-- Research for gear sets: what this client offers for saving and swapping
-- gear and for making macros. Read only; changes nothing. Listed by /bs check.
local probe   -- one frame, made on first use, only to ask whether an event exists
local function eventExists(event)
	if C_EventUtils and type(C_EventUtils.IsEventValid) == "function" then
		local ok, valid = pcall(C_EventUtils.IsEventValid, event)
		if ok then return valid and true or false end
	end
	probe = probe or CreateFrame("Frame")
	local ok = pcall(probe.RegisterEvent, probe, event)
	if ok then pcall(probe.UnregisterEvent, probe, event) end
	return ok
end
local function yesNo(v) return v and "yes" or "no" end
local function listed(names, test)
	local out = {}
	for _, name in ipairs(names) do out[#out + 1] = name .. " " .. yesNo(test(name)) end
	return table.concat(out, ", ")
end
local function isGlobalFn(name) return type(_G[name]) == "function" end
local function wornGuid()
	if not (ItemLocation and type(ItemLocation.CreateFromEquipmentSlot) == "function" and C_Item and type(C_Item.GetItemGUID) == "function") then
		return "can't tell (no ItemLocation:CreateFromEquipmentSlot)"
	end
	if type(GetInventoryItemID) ~= "function" then return "can't tell (no GetInventoryItemID)" end
	for slot = 1, 19 do
		if GetInventoryItemID("player", slot) then
			local okL, loc = pcall(ItemLocation.CreateFromEquipmentSlot, ItemLocation, slot)
			if not okL then return ("no (slot %d: location error)"):format(slot) end
			local okG, guid = pcall(C_Item.GetItemGUID, loc)
			return (okG and guid) and ("yes (slot %d)"):format(slot) or ("no (slot %d)"):format(slot)
		end
	end
	return "nothing worn to test"
end
function ns.GearResearch()
	local out = {}
	local ES = _G.C_EquipmentSet
	if type(ES) == "table" then
		local missing = {}
		for _, fn in ipairs({ "GetEquipmentSetIDs", "GetEquipmentSetInfo", "CreateEquipmentSet", "SaveEquipmentSet",
			"UseEquipmentSet", "PickupEquipmentSet", "CanUseEquipmentSets" }) do
			if type(ES[fn]) ~= "function" then missing[#missing + 1] = fn end
		end
		local canUse, count = "unknown", "unknown"
		if type(ES.CanUseEquipmentSets) == "function" then
			local ok, v = pcall(ES.CanUseEquipmentSets); canUse = ok and yesNo(v) or "error"
		end
		if type(ES.GetNumEquipmentSets) == "function" then
			local ok, v = pcall(ES.GetNumEquipmentSets); count = ok and tostring(v) or "error"
		end
		out[#out + 1] = ("Gear sets (research): C_EquipmentSet found   Missing: %s   Can use sets: %s   Sets saved: %s"):format(
			#missing > 0 and table.concat(missing, ", ") or "none", canUse, count)
	else
		out[#out + 1] = "Gear sets (research): C_EquipmentSet not found"
	end
	local slash
	for k, v in pairs(_G) do
		if type(k) == "string" and type(v) == "string" and k:find("^SLASH_") and v:lower() == "/equipset" then slash = (k:gsub("%d+$", "")); break end
	end
	local window
	for _, name in ipairs({ "PaperDollEquipmentManagerPane", "GearManagerDialog", "GearManagerDialogPopup" }) do
		if _G[name] then window = name; break end
	end
	if not window and type(_G.PaperDollFrame) == "table" and _G.PaperDollFrame.EquipmentManagerPane then window = "PaperDollFrame.EquipmentManagerPane" end
	out[#out + 1] = ("  /equipset command: %s   Equipment Manager window: %s"):format(slash and ("found (" .. slash .. ")") or "not found", window or "not found")
	local equippable = (C_Item and type(C_Item.IsEquippableItem) == "function") or isGlobalFn("IsEquippableItem")
	out[#out + 1] = ("  Equipping: %s, IsEquippableItem %s   GUIDs of worn items: %s"):format(
		listed({ "EquipItemByName", "PickupInventoryItem", "EquipCursorItem", "AutoEquipCursorItem", "GetInventoryItemsForSlot" }, isGlobalFn),
		yesNo(equippable), wornGuid())
	out[#out + 1] = ("  Gear events: %s"):format(listed({ "PLAYER_EQUIPMENT_CHANGED", "EQUIPMENT_SWAP_PENDING", "EQUIPMENT_SWAP_FINISHED", "EQUIPMENT_SETS_CHANGED" }, eventExists))
	local inUse = ""
	if isGlobalFn("GetNumMacros") then
		local ok, account, char = pcall(GetNumMacros)
		if ok then
			inUse = ("   In use: account %s of %s, character %s of %s"):format(tostring(account), tostring(_G.MAX_ACCOUNT_MACROS or "?"),
				tostring(char), tostring(_G.MAX_CHARACTER_MACROS or "?"))
		end
	end
	out[#out + 1] = ("  Macros: %s%s"):format(listed({ "CreateMacro", "EditMacro", "PickupMacro", "GetMacroInfo", "GetMacroIcons" }, isGlobalFn), inUse)
	return out
end

local commands = {
	de = function() if ns.Disenchant then ns.Disenchant:Toggle() end end,
	disenchant = function() if ns.Disenchant then ns.Disenchant:Toggle() end end,
	toggle = function() ns.Window:Toggle() end,
	settings = function() ns.SettingsPanel:Toggle() end,
	currency = function() ns.Window:Show(); ns.Drawer:Toggle() end,
	show = function() ns.Window:Show() end,
	hide = function() ns.Window:Hide() end,
	dump = dump,
	reset = function()
		ns:ResetSettings()
		ns:Print("Settings reset to defaults.")
	end,
	-- (1.5.0-beta9) what this client reports for consumables: the game's consumable types, the names it uses for
	-- eating and drinking, and each consumable in your bags with its type, use spell and where BagSmith puts it
	consumables = function()
		ns:Print("Consumable types this client reports:")
		local parts = {}
		for i = 0, 12 do
			-- (1.5.0-beta10) newer clients keep this lookup under C_Item
			local get = (C_Item and C_Item.GetItemSubClassInfo) or GetItemSubClassInfo
			local name = get and get(ns.ITEM_CLASS.Consumable, i)
			if name and name ~= "" then parts[#parts + 1] = ("%d %s"):format(i, name) end
		end
		ns:Print("  %s", #parts > 0 and table.concat(parts, ", ") or "(none reported)")
		local food = (GetSpellInfo and GetSpellInfo(ns.FOOD_SPELL_ID)) or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(ns.FOOD_SPELL_ID))
		local drink = (GetSpellInfo and GetSpellInfo(ns.DRINK_SPELL_ID)) or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(ns.DRINK_SPELL_ID))
		ns:Print("  Eating is called %q, drinking %q.", tostring(food or "(unknown)"), tostring(drink or "(unknown)"))
		local seen, n = {}, 0
		for _, rec in ipairs(ns.items or {}) do
			if rec.itemID and rec.classID == ns.ITEM_CLASS.Consumable and not seen[rec.itemID] then
				seen[rec.itemID] = true; n = n + 1
				local spell, spellID = ns:ItemUseSpell(rec.itemID)
				ns:Print("  %s: type %s (%s), use spell %s%s, kind %s, section %s", rec.name or "?", tostring(rec.subclassID), rec.itemSubType or "?",
					tostring(spell or "(not loaded)"), spellID and (" " .. spellID) or "", tostring(ns:ConsumableKind(rec) or "(waiting)"), ns.Sections and ns.Sections:Label(rec.cat) or tostring(rec.cat))
			end
		end
		if n == 0 then ns:Print("  No consumables in your bags right now.") end
	end,
	-- (1.5.0-beta4) every icon-corner mark, where it is, and anything wrong with it
	corners = function() if ns.Corners then ns.Corners:Report() end end,
	debug = function()
		ns.db.debug = not ns.db.debug
		ns:Print("Debug output %s.", ns.db.debug and "on" or "off")
	end,
	sort = function(arg)
		if ns:Set("sort", arg) then
			ns:Print("Sorting by %s.", arg)
		else
			ns:Print("Sort options: quality, name, ilvl, newest, oldest.")
		end
	end,
	scale = function(arg)
		local n = tonumber(arg)
		if n and ns:Set("scale", n) then
			ns:Print("Scale set to %.2f.", ns.db.scale)
		else
			ns:Print("Usage: /bs scale 0.5 to 1.5")
		end
	end,
	blizzard = function()
		ns:Set("replaceBlizzardBags", not ns.db.replaceBlizzardBags)
		ns:Print("Opening with the bag keybind: %s.", tostring(ns.db.replaceBlizzardBags))
	end,
	profile = function(arg)
		local sub, name = (arg or ""):match("^(%S*)%s*(.-)$")
		sub = (sub or ""):lower()
		local P = ns.Profiles
		if sub == "" or sub == "list" then
			ns:Print("Active profile: %s", ns.profileName)
			ns:Print("Profiles: %s", table.concat(P:List(), ", "))
			ns:Print("Usage: /bs profile use <name> | copy <name> | delete <name> | reset")
		elseif sub == "use" then
			local ok, err = P:Use(name)
			ns:Print(ok and ("Now using profile %s."):format(ns.profileName) or err)
		elseif sub == "copy" then
			local ok, err = P:CopyFrom(name)
			ns:Print(ok and ("Copied %s into %s."):format(name, ns.profileName) or err)
		elseif sub == "delete" then
			local ok, err = P:Delete(name)
			ns:Print(ok and ("Deleted profile %s."):format(name) or err)
		elseif sub == "reset" then
			P:Reset()
			ns:Print("Profile %s reset to defaults.", ns.profileName)
		else
			ns:Print("Usage: /bs profile use <name> | copy <name> | delete <name> | reset | list")
		end
	end,
	quiet = function()
		ns:Set("quiet", not ns.db.quiet)
		ns:Print("Startup message %s.", ns.db.quiet and "off" or "on")
	end,
	check = function()
		ns:Print("--- BagSmith self check ---")
		ns:Print("Version %s, interface %d, build %s, game token %s", ns.version, ns.interface, tostring(ns.build), tostring(ns.gameToken))
		ns:Print("Detected as Forever: %s", tostring(ns.isForever))
		ns:Print("Settings loaded: %s   Profile: %s", tostring(ns.loaded), tostring(ns.profileName))
		ns:Print("Window built: %s   Buttons: %d   Ready: %s", tostring(ns.Window and ns.Window.main ~= nil),
			ns.Buttons and #ns.Buttons.all or 0, tostring(ns.ready))
		ns:Print("Items scanned: %d   Bank items: %d   At bank: %s", #ns.items, #ns.bankItems, tostring(ns.atBank))
		ns:Print("Replacing Blizzard bags: %s   Hooks installed: %s", tostring(ns.db.replaceBlizzardBags), tostring(ns.Hooks and ns.Hooks.installed))
		ns:Print("Errors so far: %d", ns.errors or 0)
		if ns.Tutorials then ns:Print("Blizzard's reagent bag tip: %s", ns.Tutorials:Status()) end
		ns:Print("Item tooltip placement: %s", type(_G.ContainerFrameItemButton_CalculateItemTooltipAnchors) == "function"
			and "Blizzard's anchor calculation" or "BagSmith's copy of Blizzard's rule (left of items on the right half of the screen)")
		ns:Print("Item GUIDs available: %s   RemoveNewItem: %s", tostring(ns.hasGuids or false), tostring(C_NewItems and type(C_NewItems.RemoveNewItem) == "function"))
		ns:Print("Bank bag %d, bank bags %d, keyring %s (candidate %s)", ns.BANK, ns.NUM_BANK_BAGS,
			tostring(ns.KEYRING), tostring(ns.startup.keyringCandidate))
		if ns.Bank then
			local buy = ns.Bank.supported and ns.Bank:BlizzardPurchaseButton() or nil
			ns:Print("Bank: %s API   Replacing: %s   Purchase button: %s", ns.Bank.backend, tostring(ns.Bank:Replacing()),
				buy and (ns.Bank.pickedName or "found") or "not found (buying opens Blizzard's bank)")
		end
		local missing = {}
		for _, name in ipairs({ "C_Container", "C_Item", "ContainerFrameItemButtonTemplate check", "ToggleAllBags", "ToggleBackpack" }) do
			if name:find("template") or name:find("check") then
				local ok = pcall(CreateFrame, "ItemButton", nil, UIParent, "ContainerFrameItemButtonTemplate")
				if not ok then missing[#missing + 1] = "ContainerFrameItemButtonTemplate" end
			elseif _G[name] == nil then missing[#missing + 1] = name end
		end
		-- Bag windows: what BagSmith wants, and what's actually on screen.
		local W = ns.Window
		if W and W.bagViews then
			local sb, sr = ns.SessionWindows()
			ns:Print("Bag windows: switched on %s   Reagent window %s   Bags window open %s   Sheet %s%s", sb and "yes" or "no", sr and "yes" or "no",
				(W.main and W.main:IsShown()) and "yes" or "no", tostring(ns.ui.sheet), ns.ui.owner and "   (browsing another character)" or "")
			local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
			local bags = {}
			for bag in pairs(W.bagViews) do bags[#bags + 1] = bag end
			table.sort(bags)
			for _, bag in ipairs(bags) do
				local v = W.bagViews[bag]
				local f = v.frame
				local size = ns.bagInfo[bag] and ns.bagInfo[bag].size or 0
				local l, b, w, h = f:GetLeft(), f:GetBottom(), f:GetWidth() or 0, f:GetHeight() or 0
				local s = (f.GetEffectiveScale and f:GetEffectiveScale() or 1) / (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1)
				local onScreen = l and b and (l * s + w * s > 0) and (l * s < sw) and (b * s + h * s > 0) and (b * s < sh)
				ns:Print("  %s: %d slots, %s, %dx%d, %s%s", ns:BagName(bag), size, f:IsShown() and "shown" or "hidden", w, h,
					l and (onScreen and "on screen" or "|cffff6060off screen|r") or "not placed yet",
					(ns.ui.closedBags and ns.ui.closedBags[bag]) and ", closed with its X" or "")
			end
		end
		local J = ns.Junk
		local marks = 0; for _ in pairs(J:Marks()) do marks = marks + 1 end
		ns:Print("Sell Junk + Mark as Junk: watching Blizzard's sale %s   marked items %d   needs a click %s", tostring(J.hooked and true or false), marks, tostring(J.needsClick and true or false))
		ns:Print("Junk art: coin on items %s; Sell Marked button %s", tostring(J.coinArt), tostring(J.pouchArt or "not shown yet"))
		ns:Print("Item tooltip lines added through: %s", tostring(ns.Buttons.tooltipHook or "none"))
		ns:Print("Pawn: %s   bag upgrade advisor %s   arrow art %s", ns.Pawn:Present() and "found" or "not installed",
			ns.Pawn:AdvisorOn() and "on" or "off", tostring(ns.Pawn.art or "not used yet"))
		for _, line in ipairs(ns.GearResearch()) do ns:Print("%s", line) end
		if ns.GearSets and ns.GearSets:Available() then
			local names = {}
			for _, set in ipairs(ns.GearSets:Rebuild()) do names[#names + 1] = ("%s (%d)"):format(set.name, ns.GearSets:Count(set)) end
			ns:Print("Gear sets: %d%s   Shown as sections: %s", #names, #names > 0 and (": " .. table.concat(names, ", ")) or "", ns.GearSets:Showing() and "yes" or "no")
		end
		ns:Print("Missing APIs: %s", #missing > 0 and table.concat(missing, ", ") or "none")
		ns:Print("Events this client does not have: %s", #ns.skippedEvents > 0 and table.concat(ns.skippedEvents, ", ") or "none")
		if not ns.ready then ns:Print("|cffff6060Not ready. Type /console scriptErrors 1 and /reload to see the error.|r") end
	end,
	errors = function()
		local log = ns.errorLog or {}
		if #log == 0 then ns:Print("No errors recorded this session."); return end
		for i, e in ipairs(log) do ns:Print("%d. %s", i, e) end
	end,
	skincheck = function() ns.Classic:Report() end,
	-- What's New. "reset" and "reset skipped" are for testing (not in help).
	new = function(rest)
		rest = tostring(rest or ""):lower()
		if rest:match("^reset") then
			ns.WhatsNew:ResetForTesting(rest:find("skipped") ~= nil)
			ns:Print("What's New will show the next time you open your bags.")
		else
			ns.WhatsNew:ShowLatest()
		end
	end,
	help = function()
		ns:Print("Commands: /bs toggle | settings | currency | check | errors | dump | sort <mode> | scale <n> | profile ... | reset | debug | corners | consumables | quiet | blizzard | skincheck | new")
	end,
}

do local names = {}; for n in pairs(commands) do names[#names + 1] = n end; if ns.API then ns.API:ReserveCommands(names) end end
SLASH_BAGSMITH1 = "/bagsmith"
SLASH_BAGSMITH2 = "/bs"
SlashCmdList.BAGSMITH = function(msg)
	local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()
	if cmd == "" then cmd = "toggle" end
	local fn = commands[cmd]
	if fn then fn(arg); return end
	-- plugin commands (registered through BagSmith.API); "gamepad" is the Gamepad companion's, kept as the
	-- name the diagnostics used, and answered with a plain message when the companion is absent
	if ns.API and ns.API:DispatchCommand(cmd, arg) then return end
	if cmd == "gamepad" then ns:Print("The BagSmith Gamepad companion is not installed or not active. See Settings > Plugins."); return end
	commands.help()
end
