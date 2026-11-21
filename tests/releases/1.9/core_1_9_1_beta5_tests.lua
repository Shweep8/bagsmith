-- ======== 1.9.1-beta5 (Shweep, 18 Nov) ========
-- "can we cleanup these descriptions, especially the warlock one" (and "clear shards button where? that needs context.
-- Also does it auto destroy any that exceed that count?"); and "descriptions in settings like this one where the word
-- wrap seems excessive": beside a wide control, the help runs the full width under it when that makes the row shorter.

local function boot(skin)
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	return n, M, n.SettingsPanel
end
-- a point's y offset, written short ("TOPLEFT", x, y) or long ("TOPLEFT", frame, "TOPLEFT", x, y)
local function py(r) local p = r.points and r.points[1]; if not p then return nil end return type(p[2]) == "number" and p[3] or p[5] end
local function row(P, pool, key) for _, w in ipairs(P.pools[pool] or {}) do if w:IsShown() and w.key == key then return w end end end

for _, skin in ipairs({ "modern", "classic" }) do
	local S = skin .. ": "
	local n, M, P = boot(skin)
	P:Show(); P:ShowPage("automation"); M.runTimers()
	-- the three help lines
	-- (by design since 1.9.7-beta1: "or at a vendor" joins the exceptions)
	check(row(P, "check", "cleanOnOpen").help.text == "Tidies your bags each time you open them, except in combat, at the bank or at a vendor.", S .. "Clean Up Bags When Opened: the new help")
	check(row(P, "check", "autoSellJunk").help.text == "Sells your grey and junk-marked items whenever you visit a vendor, grey favorites included. You can buy back the last 12.", S .. "Sell Junk Automatically: the new help")
	check(row(P, "step", "shardKeep").help.text == "|cff8788eeWarlocks|r only. Soul Shards are only cleared when you click Clear Shards (on their section in your bags) or use the Loot Helper, and you always keep this many. Shards in your soul bag count toward it and are never cleared.",
		S .. "Soul Shards to Keep: where Clear Shards is, nothing cleared on its own, the soul bag")
	-- a checkbox row keeps its help beside the box
	local c = row(P, "check", "cleanOnOpen")
	check(not c.helpBelow and py(c.help) > -30, S .. "a checkbox row: its help beside the box, as before (" .. tostring(py(c.help)) .. ")")

	-- Price Source: the help under the three buttons, the full width
	P:ShowPage("general"); M.runTimers()
	local ps = row(P, "seg", "priceSource")
	check(ps and ps.helpBelow, S .. "Price Source: its help runs under the buttons")
	local top = -py(ps.help)
	check(top >= 4 + 22 + 4, S .. "below the buttons, not over them (" .. top .. ")")
	local total = 0
	for _, b in ipairs(ps.btns) do if b:IsShown() then total = total + b.w + 2 end end
	local beside = ps:GetWidth() - total - 16
	check((ps.help.width or 0) > beside + 100, S .. "and much wider than the room the buttons left (" .. tostring(ps.help.width) .. " vs " .. beside .. ")")
	-- every row that moved its help: below its control, and shorter than beside
	local moved, bad = 0, {}
	for _, page in ipairs({ "general", "look", "window", "icons", "automation", "sorting" }) do
		P:ShowPage(page); M.runTimers()
		for _, pool in ipairs({ "seg", "dropdown", "step", "check" }) do
			for _, w in ipairs(P.pools[pool] or {}) do
				if w:IsShown() and w.helpBelow then
					moved = moved + 1
					if -py(w.help) < 30 then bad[#bad + 1] = tostring(w.key) end
				end
			end
		end
	end
	check(moved >= 1 and #bad == 0, S .. moved .. " rows with their help under the control, none over it" .. (#bad > 0 and (": " .. table.concat(bad, ", ")) or ""))
	P:Hide()
	check((n.errors or 0) == 0, S .. "no errors")
end
