;(function()
	-- 1.0.2: in Classic every dialog wears the window chrome and background; Modern is untouched
	package.loaded.mock = nil
	local M = require("mock")
	for s = 1, 4 do M.put(0, s, { id = 7000 + s, name = "Item" .. s, q = 1, count = 1, class = 0, subclass = 5, price = 1 }) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "classic" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	-- open what can be opened directly
	n.ShowLink("CurseForge", "https://example.invalid")
	n.ShareWindow("text", { title = "Controller Diagnostics", help = "h", text = "t" })
	n.Confirm(nil, "Delete this section?", function() end)
	n.Prompt("Rename Section", "Gear", function() end, 24)
	pcall(function() n.MakeRoom:Show() end)
	pcall(function() n.MakeRoom:ShowShards() end)
	local dialogs = { "BagSmithLink", "BagSmithShare", "BagSmithConfirm", "BagSmithPrompt", "BagSmithMakeRoom", "BagSmithMovedItems" }
	local seen, chromes, titled, hiddenTitles = 0, 0, 0, 0
	for _, name in ipairs(dialogs) do
		local f = _G[name]
		if f and f.classicSpec then
			seen = seen + 1
			local st = f.classicState
			if st and st.chrome and not f.classicSpec.template then chromes = chromes + 1 end
			local want = f.title and f.title.text or "Confirm"
			if st and st.title and st.title.text == want then titled = titled + 1 end
			if not f.title or not f.title:IsShown() then hiddenTitles = hiddenTitles + 1 end
		end
	end
	check(seen >= 3 and chromes == seen, ("every open dialog (%d) is dressed with the window chrome, none with the plain dialog border"):format(seen))
	check(titled == seen and hiddenTitles == seen, "each dialog's own title is shown in the chrome's title bar and hidden where it was")
	local confirm = _G.BagSmithConfirm
	check(confirm and confirm.text.points[1][1] == "TOPLEFT" and confirm.text.points[1][3] == -30, "the confirm text sits below the title bar in Classic")
	check(_G.BagSmithMenu == nil or (_G.BagSmithMenu.classicSpec.template == "DialogBorderTemplate"), "the section context menu keeps the plain border: it is a menu, not a window")
	-- a dialog can be moved: its title bar is a drag band above the chrome, and the chrome's child frames take no mouse
	local link = _G.BagSmithLink
	local st = link.classicState
	check(st.drag and st.drag:IsShown() and st.drag.scripts.OnDragStart and st.drag:GetFrameLevel() > st.chrome:GetFrameLevel(), "a dialog has a drag band above the chrome")
	link.moved = 0; link:SetScript("OnDragStart", function() link.moved = link.moved + 1 end)   -- (the band runs the dialog's own handler)
	st.drag.scripts.OnDragStart(st.drag)
	check(link:IsMovable() and link.moved == 1, "dragging the band moves the dialog through its own drag handler")
	-- every dressed dialog is movable, the confirm box and the section editor included (they were not, so their bands did nothing)
	local immovable = {}
	for _, name in ipairs({ "BagSmithLink", "BagSmithShare", "BagSmithConfirm", "BagSmithMakeRoom", "BagSmithMovedItems", "BagSmithPrompt" }) do
		local f = _G[name]
		if f and f.classicState and not f:IsMovable() then immovable[#immovable + 1] = name end
	end
	check(#immovable == 0, "every dialog with a title bar is movable (" .. table.concat(immovable, ",") .. ")")
	confirm.moved = 0; confirm:SetScript("OnDragStart", function() confirm.moved = confirm.moved + 1 end)
	confirm.classicState.drag.scripts.OnDragStart(confirm.classicState.drag)
	check(confirm.moved == 1, "dragging the confirm box's title bar moves it")
	local mouseOn = 0; for _, c in ipairs({ st.chrome:GetChildren() }) do if c ~= st.chrome.CloseButton and c.mouseEnabled then mouseOn = mouseOn + 1 end end
	check(mouseOn == 0, "no chrome child frame intercepts the mouse")
	-- a short dialog grows to the frame art's minimum height in Classic and shrinks back in Modern
	check(confirm:GetHeight() == n.Classic.DIALOG_MIN_H, ("the confirm dialog (96 px) is %d px tall in Classic so the frame art fits"):format(n.Classic.DIALOG_MIN_H))
	check(_G.BagSmithShare:GetHeight() == 270, "a dialog already taller than the minimum keeps its height")
	-- the Settings panel's scrollbar shows Blizzard's arrows in Classic, like the bag window's; Modern hides them again
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("look")
	local sb = P.scroll.ScrollBar
	local function arrows() local vis = 0; for _, key in ipairs({ "ScrollUpButton", "ScrollDownButton", "Back", "Forward" }) do local b = sb[key] or _G[(sb:GetName() or "") .. key]; if b and (b.alpha == nil or b.alpha > 0) and b.mouseEnabled ~= false then vis = vis + 1 end end return vis end
	local hasArrows = (sb.ScrollUpButton or _G[(sb:GetName() or "") .. "ScrollUpButton"]) ~= nil   -- (the mock's template has none)
	check(sb.classicSnap ~= nil and sb.points[1][2] == P.scroll and sb.points[1][5] == -16 and (not hasArrows or arrows() >= 1), "in Classic the Settings scrollbar is placed with room for Blizzard's arrows, which are shown when the template has them")
	-- the chrome close button sits half a pixel left of the template's spot
	local lst = P.frame.classicState
	-- (the mock's template has no CloseButton anchor, so the fallback anchor is used: TOPRIGHT -4,-4; the nudge applies to the
	-- template path, which the helper reports; both are asserted by the helper's own words)
	check(lst and lst.close and lst.close.points[1] and (n.Classic.closeFrom["BagSmith Settings"] or ""):find("fallback") ~= nil or (n.Classic.closeFrom["BagSmith Settings"] or ""):find("x %-0%.5") ~= nil, "the close button placement reports the half-pixel nudge on the template path")
	P:Hide()
	-- Modern: everything back where it was
	n:Set("skin", "modern"); M.runTimers()
	local restored = 0
	for _, name in ipairs(dialogs) do local f = _G[name]; if f and f.classicState and not f.classicState.on and (not f.title or f.title:IsShown()) then restored = restored + 1 end end
	check(restored == seen and confirm.text.points[1][3] == -14 and confirm:GetHeight() == confirm.classicNaturalH and confirm:GetHeight() < n.Classic.DIALOG_MIN_H and not confirm.classicState.drag:IsShown(), "switching to Modern restores the dialogs' own titles, the confirm text position, its own content-derived height, and hides the drag band")
	P:Show(); P:ShowPage("look")
	check(arrows() == 0 and (sb.points[1] == nil or sb.points[1][5] ~= -16), "in Modern the Settings scrollbar is back where it was, arrows hidden")
	P:Hide()
	n:Set("skin", "classic"); M.runTimers()
	check(confirm.classicState.on and confirm.text.points[1][3] == -30 and confirm:GetHeight() == n.Classic.DIALOG_MIN_H, "and back to Classic dresses them again")
end)()

