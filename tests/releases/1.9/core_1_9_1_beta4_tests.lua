-- ======== 1.9.1-beta4 (Shweep, 18 Nov) ========
-- "in automation please move BagScleanup, Vendors and Warlock to be first 3 followed by Travel Mode and then prompts":
-- Settings > Automations reads Bag Cleanup, Vendors, Clear Soul Shards, Auto Travel Mode, Prompts. Nothing else moves.

for _, skin in ipairs({ "modern", "classic" }) do
	local S = skin .. ": "
	package.loaded.mock = nil
	local M = require("mock")
	M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("automation"); M.runTimers()
	local heads = {}
	for _, h in ipairs(P.pools.head) do if h:IsShown() then heads[#heads + 1] = { text = h.text.text, y = h.points and h.points[1] and h.points[1][5] or 0 } end end
	table.sort(heads, function(a, b) return a.y > b.y end)
	local order = {}
	for _, h in ipairs(heads) do order[#order + 1] = h.text end
	-- (by design since 1.11.0-beta2: Auto-Open and Auto-Close joins the page, just above Auto Travel Mode, where he placed it)
	check(table.concat(order, "|") == "Bag Cleanup|Vendors|Clear Soul Shards|Auto-Open and Auto-Close|Auto Travel Mode|Prompts", S .. "the headings in Shweep's order: " .. table.concat(order, "|"))
	-- each section's settings still under its heading
	local function rowY(pool, key) for _, w in ipairs(P.pools[pool] or {}) do if w:IsShown() and w.key == key then return w.points[1][5] end end end
	local function headY(text) for _, h in ipairs(heads) do if h.text == text then return h.y end end end
	check(rowY("check", "cleanOnOpen") < headY("Bag Cleanup") and rowY("check", "cleanOnOpen") > headY("Vendors"), S .. "Clean Up Bags When Opened under Bag Cleanup")
	check(rowY("check", "autoSellJunk") < headY("Vendors") and rowY("check", "autoSellJunk") > headY("Clear Soul Shards"), S .. "Sell Junk Automatically under Vendors")
	check(rowY("step", "shardKeep") < headY("Clear Soul Shards") and rowY("step", "shardKeep") > headY("Auto Travel Mode"), S .. "Soul Shards to Keep under Clear Soul Shards")
	check(rowY("check", "travelLeaveBank") < headY("Auto Travel Mode") and rowY("check", "travelLeaveTrade") > headY("Prompts"), S .. "the six Leave Travel Mode settings under Auto Travel Mode")
	check(rowY("check", "autoConfirm") < headY("Prompts"), S .. "Auto-Confirm Prompts under Prompts, last")
	P:Hide()
	check((n.errors or 0) == 0, S .. "no errors")
end
