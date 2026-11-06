package.path = "./tests/?.lua;" .. package.path
local M = require("mock")
M.sizes[0] = 12; for b = 1, 5 do M.sizes[b] = 0 end
M.put(0, 1, { id = 117, name = "Tough Jerky", q = 1, count = 7, stack = 20, class = 0, subclass = 5, price = 1 })
M.put(0, 4, { id = 117, name = "Tough Jerky", q = 1, count = 9, stack = 20, class = 0, subclass = 5, price = 1 })
M.put(0, 6, { id = 4540, name = "Tough Hunk of Bread", q = 1, count = 4, stack = 20, class = 0, subclass = 5, price = 1 })
M.put(0, 8, { id = 159, name = "Spring Water", q = 1, count = 3, stack = 20, class = 0, subclass = 5, price = 1 })
_G.BagSmithCharDB = { version = 1, firstSeen = {} }
_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "classic", emptySlots = true } } }
local n = M.loadAddon("BagSmith")
M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
n.Window:Show(); M.runTimers(); M.runTimers()
local V, S = n.Window.main, n.Sections
local c = S:Create("Test"); S:Move(117, c); S:Move(4540, c); S:SetPinned(c, true)
V:SetPref("grp", "none"); V:SetPref("view", "icons"); V:SetPref("sort", "off"); V:SetPref("mergeStacks", false); n:RefreshViews(true); M.runTimers()
local function dump(tag)
  local t = {}
  for _, b in ipairs(V.used or {}) do
    if b:IsShown() and b.rec and b.mode == "cell" then
      t[#t+1] = (b.inLane or "?") .. ":" .. b.rec.bag .. ":" .. b.rec.slot .. (b.rec.placeholder and "p" or (b.rec.empty and "*" or ("=" .. (b.rec.name or "?") .. "x" .. tostring(b.rec.count)))) .. (b.secure and "" or "[d]")
    end
  end
  print(tag, table.concat(t, "  "))
end
dump("off/merge-off")
V:SetPref("mergeStacks", true); n:RefreshViews(true); M.runTimers()
dump("off/merge-on")
