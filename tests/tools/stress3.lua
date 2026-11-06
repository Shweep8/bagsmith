package.path = "./tests/?.lua;" .. package.path
local W = ...
local M = require("mock")
_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
-- Gear sets on (0.15): the Sections page lists them, with long names too.
M.installEquipmentSets(); M.addSet("Tank", { [1] = M.bagLoc(0, 1) }); M.addSet("Sixteen Letters!", {}); M.addSet("PvP", {})
local ns = M.loadAddon("BagSmith")
M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
local oldfs = M.fs
M.fs = function() local s = oldfs(); s.GetStringWidth = function(self) return #tostring(self.text or "") * W end; s.GetStringHeight = function(self) local w = self.width or 300; local n = #tostring(self.text or '') * W; return 14 * math.max(1, math.ceil(n / math.max(w, 1))) end; return s end
ToggleAllBags()
local sp = ns.SettingsPanel
local bad = {}
for _, skin in ipairs({ "modern", "classic" }) do ns:Set("recentSection", true)
  ns:Set("skin", skin)
  sp:Show()
  for _, page in ipairs({ "general", "look", "window", "sections", "dynamic", "custom", "columns", "bagcols", "bankcols", "sheets", "bagsheets", "banksheets", "sorting", "automation", "keys", "profile", "advanced", "about" }) do
    if pcall(sp.ShowPage, sp, page) then
      local rows = {}
      for _, c in ipairs(sp.scroll.child.children) do
        -- (cards sit behind their rows by design: skip them)
        local isCard = false
        for _, card in ipairs(sp.pools.card or {}) do if card == c then isCard = true end end
        if not c.lookHidden and c.points[1] and not isCard then
          local p = c.points[1]; local y = type(p[2]) == "number" and p[3] or p[5]
          rows[#rows + 1] = { y = -(y or 0), h = c.h or 0 }
        end
      end
      table.sort(rows, function(a, b) return a.y < b.y end)
      for i = 2, #rows do if rows[i].y < rows[i - 1].y + rows[i - 1].h - 0.01 then bad[#bad + 1] = skin .. "/" .. page .. " row " .. i end end
    end
  end
  sp:Hide()
end
local n = #sp.scroll.child.children; return (#bad == 0 and "no overlaps" or table.concat(bad, ", ")) .. " (" .. n .. " rows on the page host; window page help: ok)" or table.concat(bad, ", ")
