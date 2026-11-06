package.path = "./tests/?.lua;" .. package.path
local fails = {}
local function check(ok, msg) if not ok then fails[#fails + 1] = msg end end
dofile("tests/lifecycle.lua")(check)
for _, f in ipairs(fails) do print("FAIL: " .. f) end
print(#fails .. " failed")
