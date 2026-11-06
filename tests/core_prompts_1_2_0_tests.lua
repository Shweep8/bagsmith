;(function()
	-- 1.2.0: auto-confirming the game's yes/no boxes, scoped to BagSmith actions unless widened
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	-- the game's popup surface: a dialog frame per shown box, clicks recorded
	local shown, clicks = {}, {}
	_G.StaticPopup_Show = function(which, arg) local f = _G["BagSmithTestPopup_" .. which] or CreateFrame("Frame", "BagSmithTestPopup_" .. which, UIParent); f.which = which; f:Show(); shown[#shown + 1] = which; return f end
	_G.StaticPopup_Visible = function(which) local f = _G["BagSmithTestPopup_" .. which]; if f and f:IsShown() then return "BagSmithTestPopup_" .. which end end
	_G.StaticPopup_OnClick = function(dialog, index) clicks[#clicks + 1] = { dialog.which, index }; dialog:Hide() end
	local shift = false; _G.IsShiftKeyDown = function() return shift end
	local clock = 1000; _G.GetTime = function() return clock end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local P = n.Prompts
	local function box(which) StaticPopup_Show(which); M.runTimers(); M.elapse(); return clicks[#clicks] end
	local function lastClick() return clicks[#clicks] and clicks[#clicks][1] end
	-- off by default: nothing is clicked, ever
	n.MarkAction("gear set"); local c0 = #clicks
	box("EQUIP_BIND")
	check(n.db.autoConfirm == false and #clicks == c0 and P.last and P.last.why == "off", "off by default: a bind box after a BagSmith action is left alone")
	-- on, scoped: a box right after a BagSmith action is confirmed; one out of the blue is not
	n:Set("autoConfirm", true)
	n.MarkAction("gear set"); box("EQUIP_BIND")
	check(lastClick() == "EQUIP_BIND" and clicks[#clicks][2] == 1 and P.last.why == "autoConfirmEquip", "on: the equip-bind box after a gear-set equip gets its Yes clicked")
	clock = clock + 10; local c1 = #clicks
	box("EQUIP_BIND")
	check(#clicks == c1 and P.last.why == "outside", "a box with no BagSmith action behind it is left alone")
	-- the window: just inside and just outside
	n.MarkAction("item click"); clock = clock + P.ACTION_WINDOW; box("USE_BIND")
	check(lastClick() == "USE_BIND", "a box at the edge of the action window still counts")
	n.MarkAction("item click"); clock = clock + P.ACTION_WINDOW + 0.5; local c2 = #clicks; box("USE_BIND")
	check(#clicks == c2, "a box past the window does not")
	-- everywhere widens it
	n:Set("autoConfirmEverywhere", true); clock = clock + 100
	box("LOOT_BIND")
	check(lastClick() == "LOOT_BIND", "Also Outside BagSmith: a loot-bind box with no action behind it is confirmed")
	-- kinds: rolls are off by default; the protected dialog is never clicked; unknown boxes are ignored
	local c3 = #clicks; box("CONFIRM_LOOT_ROLL")
	check(#clicks == c3 and P.last.why == "group-off", "loot rolls are a kind that is off by default")
	n:Set("autoConfirmRoll", true); box("CONFIRM_LOOT_ROLL")
	check(lastClick() == "CONFIRM_LOOT_ROLL", "turned on, a roll confirmation is clicked")
	local c4 = #clicks; box("REPLACE_TRADESKILL_ENCHANT")
	check(#clicks == c4 and P.last.why == "protected", "the one dialog whose Yes is a protected call is never clicked")
	local c5 = #clicks; box("DELETE_GOOD_ITEM")
	check(#clicks == c5 and P.last.why == "not-listed", "a box of no listed kind (deleting an item) is never clicked")
	-- Shift keeps a box open
	shift = true; local c6 = #clicks; box("EQUIP_BIND")
	check(#clicks == c6 and P.last.why == "shift", "holding Shift keeps the box open")
	shift = false
	-- a box that closed on its own before the frame passed is not clicked
	local f = StaticPopup_Show("EQUIP_BIND"); f:Hide(); local c7 = #clicks; M.runTimers(); M.elapse()
	check(#clicks == c7, "a box gone before the next frame is not clicked after the fact")
	-- turning the setting off mid-flight
	n:Set("autoConfirm", false); local c8 = #clicks; box("EQUIP_BIND")
	check(#clicks == c8 and P.last.why == "off", "off again: nothing is clicked")
	-- BagSmith's own actions stamp the clock: a gear-set equip, a junk sale, an item click
	n:Set("autoConfirm", true); n:Set("autoConfirmEverywhere", false)
	clock = clock + 100
	local b = n.Buttons.byBag[0][1]; b.hasItem = true
	b:GetScript("OnClick")(b, "LeftButton")
	check(P.lastAction == clock and P.lastActionWhat == "item click", "clicking an item in the bag counts as a BagSmith action")
	-- safeguards: which BagSmith actions count
	n:Set("autoConfirmSrcGear", false); clock = clock + 100
	n.MarkAction("gear set"); local c9 = #clicks; box("EQUIP_BIND")
	check(#clicks == c9 and P.last.why == "outside", "a gear-set equip no longer counts when its source is off")
	n.MarkAction("item click"); box("EQUIP_BIND")
	check(lastClick() == "EQUIP_BIND", "an item click still does")
	n:Set("autoConfirmSrcGear", true)
	-- the key mode: only while the chosen key is held
	n:Set("autoConfirmKey", "ctrl"); clock = clock + 100
	local ctrl = false; _G.IsControlKeyDown = function() return ctrl end
	n.MarkAction("item click"); local c10 = #clicks; box("USE_BIND")
	check(#clicks == c10 and P.last.why == "key-not-held", "with Ctrl chosen, a box without Ctrl held is left alone")
	ctrl = true; n.MarkAction("item click"); box("USE_BIND")
	check(lastClick() == "USE_BIND", "with Ctrl held it is confirmed")
	shift = true; n.MarkAction("item click"); box("USE_BIND")
	check(lastClick() == "USE_BIND", "in a key mode Shift is not the keep-it-open escape")
	shift = false; ctrl = false
	n:Set("autoConfirmKey", "shift"); n.MarkAction("item click"); local c11 = #clicks; box("USE_BIND")
	check(#clicks == c11, "Shift chosen: without Shift, left alone")
	shift = true; n.MarkAction("item click"); box("USE_BIND"); shift = false
	check(lastClick() == "USE_BIND", "Shift chosen: with Shift held, confirmed")
	-- Custom: the key you bind; no key, nothing confirmed; held through the binding's press and release
	n:Set("autoConfirmKey", "custom")
	check(n:Set("autoConfirmKey", "alt") == false and n.db.autoConfirmKey == "custom", "Alt is gone: the modes are Always, Shift, Ctrl, Custom")
	n.MarkAction("item click"); local c12 = #clicks; box("USE_BIND")
	check(#clicks == c12 and P.last.why == "no-key", "Custom with no key bound never confirms")
	local keys = { BAGSMITH_CONFIRMKEY = "F" }
	_G.GetBindingKey = function(action) return keys[action] end
	n.MarkAction("item click"); local c13 = #clicks; box("USE_BIND")
	check(#clicks == c13 and P.last.why == "key-not-held", "with F bound but not held, left alone")
	BagSmith_ConfirmKey("down"); n.MarkAction("item click"); box("USE_BIND")
	check(lastClick() == "USE_BIND", "with F held, confirmed")
	BagSmith_ConfirmKey("up"); n.MarkAction("item click"); local c14 = #clicks; box("USE_BIND")
	check(#clicks == c14 and P.last.why == "key-not-held", "released: left alone again")
	-- a client that never reports the release: the held state still ends after the cap
	P.customUpSeen = nil; BagSmith_ConfirmKey("down"); clock = clock + P.CUSTOM_HOLD_CAP + 1
	n.MarkAction("item click"); local c15 = #clicks; box("USE_BIND")
	check(#clicks == c15 and P.last.why == "key-not-held", "a press with no release seen stops counting after the cap")
	P.customHeld = nil
	_G.GetBindingKey = nil
	n:Set("autoConfirmKey", "always")
	-- never silent: a chat line per confirmed box
	local said = {}
	local realPrint = n.Print; n.Print = function(self, fmt, ...) said[#said + 1] = fmt:format(...) end
	n.MarkAction("item click"); box("EQUIP_BIND")
	n.Print = realPrint
	check(said[#said] and said[#said]:find("^Confirmed for you: equipping bind%-on%-equip gear"), "every confirmation is announced in chat (" .. tostring(said[#said]) .. ")")
	-- the settings page shows the kinds under the setting, and nothing about AutoNod unless it is there
	local SP = n.SettingsPanel; SP:Show(); SP:ShowPage("automation")
	local kinds, sources, note, seg = 0, 0, false, nil
	for _, w in ipairs(SP.pools.check) do if w:IsShown() then if tostring(w.key):find("^autoConfirmSrc") then sources = sources + 1 elseif tostring(w.key):find("^autoConfirm") and w.key ~= "autoConfirm" and w.key ~= "autoConfirmEverywhere" then kinds = kinds + 1 end end end
	for _, w in ipairs(SP.pools.text) do if w:IsShown() and w.text.text:find("AutoNod", 1, true) then note = true end end
	for _, w in ipairs(SP.pools.seg) do if w:IsShown() and w.key == "autoConfirmKey" then seg = w end end
	check(kinds == #P.GROUPS and sources == #P.SOURCES and seg ~= nil and not note, "the Prompts section lists every source, the key choice and every kind, with no AutoNod text")
	local customLabel; for _, b in ipairs(seg.btns or {}) do if b.value == "custom" or (b.label and b.label.text and b.label.text:find("^Custom")) then customLabel = b.label.text end end
	check(customLabel == "Custom: no key set", "the Custom choice shows that no key is set (" .. tostring(customLabel) .. ")")
	local bindRow; for _, w in ipairs(SP.pools.bind) do if w:IsShown() and w.action == "BAGSMITH_CONFIRMKEY" then bindRow = w end end
	check(bindRow == nil, "no Set Key row while another mode is chosen")
	n:Set("autoConfirmKey", "custom"); SP:Refresh()
	for _, w in ipairs(SP.pools.bind) do if w:IsShown() and w.action == "BAGSMITH_CONFIRMKEY" then bindRow = w end end
	check(bindRow ~= nil, "Custom chosen: the Set Key row appears beside it")
	local listed; for _, kb in ipairs(n.KeyBinds.LIST) do if kb[1] == "BAGSMITH_CONFIRMKEY" then listed = kb[2] end end
	check(listed == "Confirm Prompts (hold)" and BINDING_NAME_BAGSMITH_CONFIRMKEY == "Confirm Prompts (hold)", "and the binding is on the Keybindings page")
	n:Set("autoConfirmKey", "always")
	SP:Hide()
end)()

