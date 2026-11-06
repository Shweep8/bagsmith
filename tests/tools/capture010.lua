package.path = "./tests/?.lua;" .. package.path
local M = require("mock")
_G.BagSmithCharDB = { version = 1, firstSeen = {} }; _G.BagSmithDB = nil
local ns = M.loadAddon("BagSmith")
M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
ToggleAllBags()
-- A player who has used prod: changed settings, saved sheets, collapsed sections, visited the bank.
ns:Set("scale", 1.2); ns:Set("bagScale", 0.8); ns:Set("bagCols", 5); ns:Set("remember", true)
ns:Set("accent", "33aaff"); ns:Set("view", "icons"); ns:Set("skin", "classic"); ns:Set("border", "unc")
ns.Window.main.st.filters.q[3] = true; ns:SaveSheet("Rares", ns.Window.main)
M.fire("BANKFRAME_OPENED"); M.runTimers()
ns.Window.bank.st.filters.text = "ore"; ns:SaveSheet("Ore", ns.Window.bank)
ns.Window.main:ToggleAllLanes()
M.fire("BANKFRAME_CLOSED"); M.runTimers()
local function ser(v, ind)
  ind = ind or ""
  if type(v) == "table" then
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = { "{\n" }
    for _, k in ipairs(keys) do
      local kk = type(k) == "string" and ("[%q]"):format(k) or ("[%s]"):format(tostring(k))
      if type(v[k]) ~= "function" and type(v[k]) ~= "userdata" then out[#out + 1] = ind .. "\t" .. kk .. " = " .. ser(v[k], ind .. "\t") .. ",\n" end
    end
    out[#out + 1] = ind .. "}"
    return table.concat(out)
  elseif type(v) == "string" then return ("%q"):format(v)
  else return tostring(v) end
end
return "-- Saved variables written by prod 0.10.0 in the mock after typical use\n-- (settings changed, sheets saved in bags and bank, sections collapsed).\n-- The suite loads them into the current build to prove the upgrade is clean.\nreturn " .. ser({ db = BagSmithDB, cdb = BagSmithCharDB }) .. "\n"
