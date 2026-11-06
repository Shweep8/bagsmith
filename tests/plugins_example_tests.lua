;(function()
	-- The starter example works on the documented API alone: registration, lifecycle, counting, preferences, options and a command.
	package.loaded.mock = nil
	local M = require("mock")
	_G.UnitName = function() return "Tester" end
	for s = 1, 4 do M.put(0, s, { id = 7000 + s, name = "Item" .. s, q = 1, count = 1, class = 0, subclass = 5, price = 1 }) end
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local core = M.loadAddon("BagSmith")
	local ex = dofile("tests/companion_loader.lua")(M, "BagSmith_ExamplePlugin", "BagSmith_ExamplePlugin")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("ADDON_LOADED", "BagSmith_ExamplePlugin"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local E = ex.Example
	check(E.handle and E.handle:GetState() == "active" and E.ctx ~= nil, "the example registers and is activated once BagSmith is ready")
	check(core.API:Plugin("bagsmith-example").options.title == "Example Plugin" and core.API.commands.example ~= nil, "it registered its options page and its command")
	local chat0 = #M.log
	core.Window:Show(); M.runTimers(); M.runTimers()
	check(E.counts == 1 and E.lastCount == 4 and #M.log == chat0, "opening the bags counts four items and, with announce off by default, says nothing")
	check(E:SetAnnounce(true) == true and core.db.plugins["bagsmith-example"].data.announce == true and core.db.plugins["bagsmith-example"].schemaVersion == 1, "its preference is stored in the profile's plugin namespace with its schema version")
	core.Window:Hide(); M.runTimers(); core.Window:Show(); M.runTimers(); M.runTimers()
	check(E.counts == 2 and M.log[#M.log]:find("4 items in your bags", 1, true), "with announce on, reopening announces the count")
	SlashCmdList.BAGSMITH("example")
	check(M.log[#M.log]:find("4 items in the open bags", 1, true), "/bs example prints the count through the plugin command")
	core.Window:Hide(); M.runTimers()
	SlashCmdList.BAGSMITH("example")
	check(M.log[#M.log]:find("not open (hidden)", 1, true), "with the bags closed the command reports the API's hidden result")
	core.Profiles:Use("Other")
	check(E.profileChanges == 1 and E:Prefs().announce == true, "a profile switch is notified once; the new profile (a copy) carries the preference")
	-- the example never reads internals: its file names none of them
	local src = io.open("BagSmith_ExamplePlugin/Example.lua"):read("*a")
	check(not src:find("ns%.Buttons") and not src:find("ns%.Window") and not src:find("ns%.db") and not src:find("_G%.BagSmith%.[A-Z][a-z]*%.") and src:find("BagSmith.API", 1, true), "the example's source touches only BagSmith.API")
	_G.UnitName = nil
end)()

