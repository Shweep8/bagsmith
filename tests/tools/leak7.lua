-- Gear sets (0.15): the Gear Sets sheet, shared items' copies, sections with Equip buttons, worn sets' titles, set icons, the title menu, Settings
-- rows, outside changes and renames, both skins, at and away from the bank.
package.path = "./tests/?.lua;" .. package.path
local M = require("mock")
M.installEquipmentSets()
M.put(0, 1, { id = 9101, name = "Lionheart Helm", q = 3, class = 4, subclass = 4, price = 900, equip = "INVTYPE_HEAD" })
M.put(0, 2, { id = 9102, name = "Band of Valor", q = 2, class = 4, subclass = 0, price = 300, equip = "INVTYPE_FINGER" })
M.put(0, 3, { id = 9104, name = "Chainmail Vest", q = 2, class = 4, subclass = 3, price = 500, equip = "INVTYPE_CHEST" })
M.addSet("Tank", { [1] = M.bagLoc(0, 1), [11] = M.bagLoc(0, 2) })
M.addSet("PvP", { [5] = M.bagLoc(0, 3), [11] = M.bagLoc(0, 2) })
M.addSet("Worn", { [5] = M.wornLoc(5), [8] = M.wornLoc(8) })   -- a title with nothing in the bags (beta3)
_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
local ns = M.loadAddon("BagSmith")
M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
ToggleAllBags()
local GS, P = ns.GearSets, ns.SettingsPanel
local function regions() local n = 0; for _, f in ipairs(M.frames) do n = n + #(f.regions or {}) end; return n end
local flip = false
local function cycle()
	for _, skin in ipairs({ "classic", "modern" }) do
		ns:Set("skin", skin)
		ns:Set("view", flip and "icons" or "list")
		ns:RefreshViews(true); M.runTimers()
		for _, c in ipairs({ ns.Window.main.child:GetChildren() }) do
			if c.laneId == "~gs:Tank" and c:IsShown() then ns.Sections:SectionMenu(c.laneId, c):Hide() end
		end
		GS:Rename(flip and "Defense" or "Tank", flip and "Tank" or "Defense"); M.runTimers()
		M.fire("EQUIPMENT_SETS_CHANGED"); M.runTimers()
		P:Show(); P:ShowPage("sections")
		local box = P.frame.search
		for _, q in ipairs({ "gear", "the", "zzqx", "" }) do box:SetText(q); box:GetScript("OnTextChanged")(box, true) end   -- Settings search (beta7)
		P:Hide()
		ns.version = "0.15.0-beta9"; ns.WhatsNew:ShowLatest(); for t = 1, 3 do ns.WhatsNew:Select(t) end; ns.WhatsNew:Close()   -- What's New tabs (beta9)
		ns.Window.main.st.sheet = flip and "GearSets" or "All"; ns:RefreshViews(true); M.runTimers()   -- the sheet (beta5)
		M.fire("BANKFRAME_OPENED"); M.runTimers(); M.fire("BANKFRAME_CLOSED"); M.runTimers()
		ns:Set("gearSetSections", false); M.runTimers(); ns:Set("gearSetSections", true); M.runTimers()
		flip = not flip
	end
end
for i = 1, 3 do cycle() end
M.log = {}; collectgarbage("collect"); collectgarbage("collect")
local f0, r0, k0 = #M.frames, regions(), collectgarbage("count")
for i = 1, 40 do cycle() end
M.log = {}; collectgarbage("collect"); collectgarbage("collect")
print(("frames %d -> %d, regions %d -> %d, memory %.0f KB -> %.0f KB"):format(f0, #M.frames, r0, regions(), k0, collectgarbage("count")))
M.removeEquipmentSets()
