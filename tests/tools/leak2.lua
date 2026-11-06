package.path = "./tests/?.lua;" .. package.path
local M = require("mock")
_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
local ns = M.loadAddon("BagSmith")
M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
ToggleAllBags()
local function cycle()
  for _, skin in ipairs({ "classic", "modern" }) do ns:Set("recentSection", true); ns:Set("splitView", true); ns:Set("sheetViews", true); ns:Set("view", "icons"); ns.cdb.recentSince = time() - 100; for _, r in ipairs(ns.items) do ns.cdb.firstSeen[r.guid] = time() - 10 end; ns.Window.main.st.sheet = (ns.Window.main.st.sheet == "Gear") and "All" or "Gear"
    ns:Set("skin", skin)
    ns.SettingsPanel:Show(); for _, p in ipairs({ "profile", "look", "window", "sections" }) do ns.SettingsPanel:ShowPage(p) end; ns.SettingsPanel:Hide()
    ns.Popups:OpenFilters(ns.Window.main, "browse"); ns.Popups.filter:Hide()
    ns.Drawer:Show(); ns.Drawer:Hide()
    ns.ui.bagWindows = true; ns:RefreshViews(true); ns.ui.bagWindows = false; ns:RefreshViews(true)
    M.fire("BANKFRAME_OPENED"); M.runTimers(); M.fire("BANKFRAME_CLOSED"); M.runTimers()
  end
end
local function regions() local n = 0; for _, f in ipairs(M.frames) do n = n + #(f.regions or {}) end; return n end
for i = 1, 3 do cycle() end
M.log = {}; collectgarbage("collect"); collectgarbage("collect")
local f0, r0, k0 = #M.frames, regions(), collectgarbage("count")
for i = 1, 60 do cycle() end
M.log = {}; collectgarbage("collect"); collectgarbage("collect")
print(("frames %d -> %d, regions %d -> %d, memory %.0f KB -> %.0f KB"):format(f0, #M.frames, r0, regions(), k0, collectgarbage("count")))
