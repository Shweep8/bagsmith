;(function()
	-- 1.1.0-beta3: the five findings of the beta2 audit, each asserting the corrected behavior (they fail on beta2)
	package.loaded.mock = nil
	local M = require("mock")
	M.faithfulVisibility = true   -- real OnShow transition semantics: Show on a shown frame fires nothing
	for s = 1, 2 do M.put(0, s, { id = 7000 + s, name = "Item" .. s, q = 2, count = 1, class = 4, subclass = 1, price = 5, ilvl = 20, equip = "INVTYPE_FEET" }) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "classic" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	-- 4: the share/copy window is built shown and titled afterwards; the chrome follows the title at once, and on reuse
	n.ShareWindow("text", { title = "First diagnostics", help = "Copy this", text = "probe" })
	local share = _G.BagSmithShare
	check(share.classicState.title.text == "First diagnostics", "the first Classic copy window shows its requested title (built shown, titled after)")
	n.ShareWindow("text", { title = "Second subject", help = "Copy this", text = "probe" })
	check(share.classicState.title.text == "Second subject", "repurposing the copy window while it stays open updates the chrome's title")
	share:Hide(); n.ShareWindow("text", { title = "Third subject", help = "h", text = "t" })
	check(share.classicState.title.text == "Third subject", "and reopening it does too")
	n.ShowLink("CurseForge", "https://example.invalid"); n.ShowLink("Discord", "https://example.invalid/2")
	check(_G.BagSmithLink.classicState.title.text == "Discord", "a second link opened over the first retitles the chrome")
	-- 3: the title-bar drag band runs the dialog's own drag handlers, so the Loot Helper saves its position
	local room = n.MakeRoom:Frame()
	room:ClearAllPoints(); room:SetPoint("CENTER", UIParent, "CENTER", 300, 200)
	n.db.makeRoomPos = nil
	local st = room.classicState
	st.drag:GetScript("OnDragStart")(st.drag); st.drag:GetScript("OnDragStop")(st.drag)
	-- (1.3.0: a drag first puts the window on the screen at its own spot, so the saved position is its corner in
	-- screen terms rather than the anchor it had before the drag)
	check(type(n.db.makeRoomPos) == "table" and n.db.makeRoomPos[1] == "TOPLEFT" and n.db.makeRoomPos[4] == math.floor(room:GetLeft() + 0.5) and n.db.makeRoomPos[5] == math.floor(room:GetTop() + 0.5), "a title-bar drag of the Loot Helper saves its position like a frame drag")
	-- 5: a refresh of the open Loot Helper keeps the Classic minimum height
	n.MakeRoom:Show("quest")
	local shownH = room:GetHeight()
	check(shownH >= n.Classic.DIALOG_MIN_H, "(control) the Loot Helper opens at the window-art minimum in Classic")
	n.MakeRoom:Refresh()
	check(room:GetHeight() >= n.Classic.DIALOG_MIN_H and room.classicNaturalH and room.classicNaturalH <= room:GetHeight(), "a refresh while it stays open keeps the minimum, remembering the natural height it asked for")
	-- 2: the Pawn arrow and the multi-set shield both at the bottom-left: the arrow rides above the shield (in List
	-- rows; 1.5.0: in Icons view the icon corners show one of them at a time, checked below)
	local cellB = CreateFrame("Button", nil, UIParent)
	cellB.mode = "cell"; cellB.icon:SetSize(33, 33); cellB.hasItem = true
	local cellRec = { itemID = 7001, link = "item:7001", gearSets = { "Tank", "DPS" } }
	cellB.rec = cellRec
	local oldUp = n.Pawn.IsUpgrade; n.Pawn.IsUpgrade = function() return true end
	n.Buttons:LinkMark(cellB, cellRec); n.Pawn:Decorate(cellB, cellRec)
	check(cellB.pawnArrow:IsShown() and not cellB.linkMark:IsShown(), "Icons view (1.5.0): one mark per corner, the arrow first by default")
	n.Pawn.IsUpgrade = oldUp
	-- (1.5.0-beta3) List rows follow the icon corners too: one mark per corner there as well
	local button = CreateFrame("Button", nil, UIParent)
	button.mode = "row"; button.icon:SetSize(33, 33); button.hasItem = true
	local rec = { itemID = 7001, link = "item:7001", gearSets = { "Tank", "DPS" } }
	button.rec = rec
	local oldUpgrade = n.Pawn.IsUpgrade; n.Pawn.IsUpgrade = function() return true end
	n.Buttons:LinkMark(button, rec); n.Pawn:Decorate(button, rec)
	check(button.pawnArrow:IsShown() and not button.linkMark:IsShown(), "List rows (1.5.0-beta3): one mark per corner, the arrow first by default")
	n.Buttons:LinkMark(button, { itemID = 7001, link = "item:7001" })
	local p = button.pawnArrow.points and button.pawnArrow.points[1]
	check(button.pawnArrow:IsShown() and p and p[4] == 0 and p[5] == 0, "the arrow sits flush in the corner (1.5.0-beta6)")
	n.Pawn.IsUpgrade = oldUpgrade
	-- 1: a long confirmation keeps its anchors and its content-derived height across a skin change, and the Classic minimum
	n.Confirm(nil, string.rep("Long confirmation message. ", 14), function() end)
	local confirm = _G.BagSmithConfirm
	local natural = confirm.classicNaturalH
	check(natural and natural > n.Classic.DIALOG_MIN_H and confirm:GetHeight() == natural and confirm:GetNumPoints() > 0, "(control) a long Classic confirmation is content-sized and anchored")
	n:Set("skin", "modern"); M.runTimers()
	check(confirm:GetNumPoints() > 0 and share:GetNumPoints() > 0, "switching to Modern leaves every dialog's anchors alone")
	check(confirm:GetHeight() == natural, "and the long confirmation keeps its content-derived height, not a creation-time snapshot")
	n.Confirm(nil, "Short?", function() end)
	local shortNatural = confirm.classicNaturalH
	check(shortNatural < n.Classic.DIALOG_MIN_H and confirm:GetHeight() == shortNatural, "a short confirmation in Modern is its natural height")
	n:Set("accent", "abcdef"); M.runTimers()
	check(confirm:GetNumPoints() > 0 and confirm:GetHeight() == shortNatural, "a later Modern skin refresh (an accent change) changes neither anchors nor height")
	n:Set("skin", "classic"); M.runTimers()
	check(confirm:GetHeight() == n.Classic.DIALOG_MIN_H and confirm:GetNumPoints() > 0, "back in Classic the short confirmation grows to the minimum with its anchors intact")
	n.Confirm(nil, string.rep("Long again. ", 20), function() end)
	check(confirm:GetHeight() == confirm.classicNaturalH and confirm:GetHeight() > n.Classic.DIALOG_MIN_H, "a long confirmation in Classic is sized to its content, above the minimum")
end)()

