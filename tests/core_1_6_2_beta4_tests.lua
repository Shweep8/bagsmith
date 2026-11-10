;(function()
	-- 1.6.2-beta4 (found with Shweep in game, on beta1 to beta3): after a /reload, Icons view opened blank, with no
	-- tooltips, until the window was resized or the view switched. /bs debug: "list area 0x0 stale"; the list area had no
	-- valid rect. PlaceScroll() then Refresh(true), run by hand after the window had drawn, drew it at once; the same two
	-- steps the frame after opening (beta3) left it unplaced ("0 0 false"). Not the cooldown refresh (switched off: still
	-- blank) and not the bag windows built late. The harness can't produce the client's unplaced rect, so it's modeled:
	-- the list area reports no valid rect and no width until the repair (View:EnsureListPlaced, in Frames/Scroll.lua)
	-- places it. The repair runs a little after each opening, only while the list area is unplaced, at most
	-- #View.PLACE_CHECKS times an opening, after combat when opened in combat.
	for _, view in ipairs({ "icons", "list" }) do
		for _, skin in ipairs({ "classic", "modern" }) do
			local who = skin .. ", " .. view
			package.loaded.mock = nil
			local M = require("mock")
			M.put(0, 1, { id = 118, name = "Minor Healing Potion", q = 1, count = 3, class = 0, subclass = 1, price = 5 })
			M.put(0, 2, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
			M.put(1, 1, { id = 2318, name = "Light Leather", q = 1, count = 2, class = 7, subclass = 6, price = 2 })
			_G.BagSmithCharDB = { version = 1, firstSeen = {} }
			_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, view = view } } }
			local n = M.loadAddon("BagSmith")
			M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
			local V = n.Window.main
			V.frame.IsMouseOver = function() return false end
			check(n.View.PLACE_CHECKS and #n.View.PLACE_CHECKS == 4 and n.View.PLACE_CHECKS[1] > 0, who .. ": (setup) the checks run after a delay")
			-- the client's state after the reload: the list area has no place until the repair places it (in game, the
			-- layouts that ran on opening, which can re-place it on their own paths, didn't give it one)
			-- the client's clock (this set's own): callbacks queued for the next frame run, then the window draws, then the
			-- delayed ones; a place given before the window has drawn doesn't hold (in game, beta3's repair at the next
			-- frame left it unplaced; by hand, later, it took)
			local now, later, drawn = {}, {}, false
			C_Timer.After = function(d, fn) if (tonumber(d) or 0) <= 0 then now[#now + 1] = fn else later[#later + 1] = fn end end
			local function frame()
				for _ = 1, 3 do local q = now; now = {}; for _, fn in ipairs(q) do fn() end end
				if V.frame:IsShown() then drawn = true end
			end
			local function settle() frame(); local l = later; later = {}; for _, fn in ipairs(l) do fn(); frame() end; frame() end
			local function open() drawn = false; n.Window:Show() end
			local sc = V.scroll
			local placed, fixes, places, afterPlace = false, true, 0, 0
			local width = sc.GetWidth
			sc.IsRectValid = function() return placed end
			sc.GetWidth = function(self) if placed then return width(self) end return 0 end
			local place = V.PlaceScroll
			V.PlaceScroll = function(self, ...)
				local from = debug.getinfo(2, "S")
				if from and tostring(from.short_src):find("Scroll%.lua") then places = places + 1; if fixes and drawn then placed = true end end
				return place(self, ...)
			end
			local refresh = V.Refresh
			V.Refresh = function(self, ...) if placed then afterPlace = afterPlace + 1 end; return refresh(self, ...) end
			local lines = {}
			local debug = n.Debug
			n.Debug = function(_, fmt, ...) lines[#lines + 1] = (select("#", ...) > 0 and fmt:format(...) or tostring(fmt)); return debug(n, fmt, ...) end
			n.db.debug = true
			open()
			check(places == 0, who .. ": nothing is placed while the window opens (" .. places .. ")")
			settle()
			local log = table.concat(lines, "\n")
			check(placed and places == 1, who .. ": a little after opening, once it has drawn, the unplaced list area is placed again, once (" .. places .. ")")
			check(afterPlace >= 1, who .. ": and the list is laid out once it's placed (" .. afterPlace .. ")")
			check(log:find("list area unplaced (check 1): placing it again", 1, true) and log:find("list area placed (", 1, true) and log:find("after 1 try", 1, true),
				who .. ": /bs debug says so, then that it took")
			-- placed: reopening costs a look and nothing more
			n.Window:Hide(); settle()
			places = 0
			open(); settle()
			check(places == 0, who .. ": with the list area placed, opening doesn't place it again (" .. places .. ")")
			-- a list area that never takes a place: tried once per check, no more
			n.Window:Hide(); settle()
			placed, fixes, places = false, false, 0
			open(); settle(); settle()
			check(places >= 1 and places <= #n.View.PLACE_CHECKS, who .. ": a list area that stays unplaced is tried at most " .. #n.View.PLACE_CHECKS .. " times an opening (" .. places .. ")")
			-- closed before the checks run: nothing placed
			n.Window:Hide(); settle()
			placed, fixes, places = false, true, 0
			open(); frame(); n.Window:Hide(); settle()
			check(places == 0, who .. ": a window closed before the checks run isn't touched (" .. places .. ")")
			-- opened in combat: placed when combat ends
			M.combat = true; M.fire("PLAYER_REGEN_DISABLED"); frame()
			local ok, err = pcall(function() open(); settle() end)
			check(ok and places == 0, who .. ": opened in combat, nothing is placed then (" .. tostring(err or places) .. ")")
			M.combat = false; M.fire("PLAYER_REGEN_ENABLED"); settle()
			check(placed and places >= 1, who .. ": and the list area is placed again when combat ends (" .. places .. ")")
			n.db.debug = false
			n.Window:Hide(); settle()
		end
	end
	-- beta1's extra cooldown refresh on opening is gone; opening still shows a cooldown that started while closed
	-- (the opening's full layout fills every button): checked in core_1_6_2_beta1_tests.lua.
	local src = io.open("BagSmith/Frames/View.lua"):read("*a")
	check(not src:find('NextFrame("cooldowns:show"', 1, true), "no extra cooldown refresh on opening (as 1.6.1)")
end)()
