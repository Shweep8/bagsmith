-- (by design since 1.10.0-beta12) this set tests the NEW tags with 1.9's list, which the panel's own list (each
-- release's) replaced: 1.9's, as it stood at 1.9.8, is put back after the addon loads
local function NEW19()
	return { release = "1.9",
		pages = { general = true, window = true, icons = true, look = true, sections = true, columns = true, sheets = true,
			globalsections = true, globalcols = true, globalsheets = true },
		heads = {},
		keys = { tipInventory = "general", tipAHPrice = "general", bagSlotCount = "window", borderWeight = "icons", iconLayout = "look", footerTextScale = "look", globalResize = "window" },
		added = {
			["1.9.1"] = { keys = { splitViewPinnedWide = "look" } },
			["1.9.2"] = { keys = { unusableOverlay = "icons" } },
			["1.9.4"] = { keys = { sectionValues = "sections" } },
		} }
end
-- (by design since 1.10.0-beta12: the 1.10 card leads What's New, so every older entry is one place further down)
-- ======== 1.9.4-beta2 (Shweep, 19 Nov) ========
-- "let's make that a setting to turn showing V and AH in section headers as a setting": Show Section Values (Settings >
-- Sections, on by default). Off, no section header shows its values, no words and no coin, in List and in all three
-- Icon Layouts, the bank and Global Inventory; hovering a section's name shows them instead. A NEW tag for 1.9.4, and a
-- What's New entry ("let's also add a what's new entry"), its wording as Shweep chose it.

local function boot(prof, db)
	package.loaded.mock = nil
	local M = require("mock")
	M.sizes[0] = 40
	for s = 1, 20 do
		local class = s == 1 and 15 or (s <= 12 and 0 or 7)
		M.put(0, s, { id = 81000 + s, name = "Sample " .. s, q = 1, class = class, subclass = 0, price = 12 })
	end
	M.put(-1, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, type = "Tradeskill", sub = "Cloth", price = 13 })
	M.put(-1, 2, { id = 81050, name = "Sample Potion", q = 1, class = 0, subclass = 0, price = 12 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	local p = { view = "icons", grp = "type", sizeMode = "fixed", fixW = 720, recentSection = false, mergeStacks = false }
	for k, v in pairs(prof or {}) do p[k] = v end
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = p } }
	for k, v in pairs(db or {}) do BagSmithDB[k] = v end
	local n = M.loadAddon("BagSmith"); n.SettingsPanel.NEW = NEW19()
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.version = "1.9.4-beta2"
	n.Window:Show(); M.runTimers(); M.runTimers()
	n.Window.main.frame.IsMouseOver = function() return false end
	return n, M, n.Window.main
end
local function headers(V)
	local out = {}
	for _, h in ipairs(V.used or {}) do if h.laneId and h.text and h:IsShown() and h.laneId ~= "~recent" then out[#out + 1] = h end end
	return out
end
-- what a header shows on the right: "words", "stacked", "coin" or "none"
local function shows(h)
	if h.valCoin and h.valCoin:IsShown() then return "coin" end
	if h.vAmt:IsShown() or h.aAmt:IsShown() or h.vLabel:IsShown() then return "stacked" end
	if h.sub:IsShown() and (h.sub:GetText() or ""):find("V: ", 1, true) then return "words" end
	return "none"
end
local function all(V, what)
	local bad = {}
	for _, h in ipairs(headers(V)) do if shows(h) ~= what then bad[#bad + 1] = tostring(h.laneId) .. "=" .. shows(h) end end
	return #headers(V) > 0 and #bad == 0, table.concat(bad, ", ")
end
local function nameHover(V)
	local h = headers(V)[1]
	GameTooltip:Hide(); GameTooltip.lines = {}
	h.scripts.OnEnter(h)
	return GameTooltip.shown and table.concat(GameTooltip.lines or {}, " "):find("V: ", 1, true) ~= nil
end

;(function()
	-- the setting
	local n, M = boot()
	check(n.db.sectionValues == true, "Show Section Values: on by default")
	local P = n.SettingsPanel
	P:Show(); P:ShowPage("sections"); M.runTimers()
	local c
	for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == "sectionValues" then c = w end end
	check(c and c.text.text == "Show Section Values", "Settings > Sections: Show Section Values")
	-- (by design since 1.9.4: Shweep's sentence at the end, with the coin drawn inline)
	check(c and c.help.text == "Each section's header shows what its items are worth: V for vendor, and AH while the AH Price column is on. Turn it off to keep headers clean; you can still hover a section's name to see them. At smaller widths this is displayed as a coin |TInterface\\MoneyFrame\\UI-GoldIcon:0|t.", "its help, as planned, with Shweep's sentence about the coin")
	check(c and c.help.text:find("|TInterface\\MoneyFrame\\UI-GoldIcon:0|t", 1, true) and c.help.text:find("UI-GoldIcon", 1, true) and select(2, c.help.text:gsub("|T", "")) == 1, "the coin in it: the same gold coin texture the headers use, once")
	local r
	for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == "remember" then r = w end end
	check(c and r and c.points[1][5] < r.points[1][5], "right after Remember Which Sections Are Collapsed")
	check(P:InRelease("keys", "sectionValues"), "on the NEW list for 1.9.4")
	n.version = "1.9.3"
	check(not P:InRelease("keys", "sectionValues"), "(not in 1.9.3)")
	P:Hide()
	check((n.errors or 0) == 0, "no errors")
end)()

for _, skin in ipairs({ "modern", "classic" }) do
	local S = skin .. ": "
	for _, layout in ipairs({ "list", "full", "split", "compact" }) do
		local prof = { skin = skin }
		if layout == "list" then prof.view = "list" else prof.splitView = layout == "split"; prof.compactCategories = layout == "compact" end
		local n, M, V = boot(prof)
		local L = S .. layout .. ": "
		local on = layout == "compact" and "coin" or nil
		if on then
			local ok, bad = all(V, on)
			check(ok, L .. "on: the coin on every header" .. (bad ~= "" and (" (" .. bad .. ")") or ""))
		else
			local h = headers(V)[1]
			check(h and shows(h) ~= "none", L .. "on: values shown (" .. tostring(h and shows(h)) .. ")")
		end
		n:Set("sectionValues", false); M.runTimers()
		local ok, bad = all(V, "none")
		check(ok, L .. "off: no header shows values, no words and no coin" .. (bad ~= "" and (" (" .. bad .. ")") or ""))
		check(nameHover(V), L .. "off: hovering a section's name shows them")
		n:Set("sectionValues", true); M.runTimers()
		local h = headers(V)[1]
		check(h and shows(h) ~= "none", L .. "on again: back without a reload (" .. tostring(h and shows(h)) .. ")")
		check((n.errors or 0) == 0, L .. "no errors")
	end
end

;(function()
	-- Compact View, off: no room kept for a coin that isn't there (the same layout as with no coin room at all)
	local n, M, V = boot({ compactCategories = true })
	local function signature()
		local out = {}
		for _, h in ipairs(headers(V)) do local p = h.points[1]; out[#out + 1] = table.concat({ h.laneId, h:GetWidth(), p[4], p[5] }, ":") end
		return table.concat(out, "|")
	end
	local room = n.View.COMPACT_COIN_ROOM
	n.View.COMPACT_COIN_ROOM = 0; V:Refresh(); M.runTimers()
	local noRoom = signature()
	n.View.COMPACT_COIN_ROOM = room; V:Refresh(); M.runTimers()
	local withCoin = signature()
	n:Set("sectionValues", false); M.runTimers()
	check(signature() == noRoom, "Compact View, off: laid out as if there were no coin")
	check(noRoom ~= withCoin, "(in this window the coin's room does change the layout, so the check above means something)")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- Recent keeps its button and words either way
	local n, M, V = boot()
	n.RecentRecords = function() return { n.items[1] } end
	n:Set("recentSection", true); M.runTimers()
	n:Set("sectionValues", false); M.runTimers()
	local recent
	for _, h in ipairs(V.used or {}) do if h.laneId == "~recent" and h:IsShown() then recent = h end end
	check(recent and recent.clearRecent and recent.clearRecent:IsShown(), "off: Recent keeps Clear Recent")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- the bank and Global Inventory
	local n, M, V = boot()
	n:Set("sectionValues", false); M.runTimers()
	M.fire("BANKFRAME_OPENED"); M.runTimers(); M.runTimers()
	local B = n.Window.bank
	check(B and B.used and #headers(B) >= 2, "(setup) the bank window, with sections")
	local okB, badB = all(B, "none")
	check(okB, "the bank, off: no values" .. (badB ~= "" and (" (" .. badB .. ")") or ""))
	M.fire("BANKFRAME_CLOSED"); M.runTimers()
	-- (by design since 1.11.0-beta3, Shweep's "1": Always Close closes the bags at every place, whether they opened for it or were open already): opened again for Global Inventory
	n.Window:Show(); M.runTimers()
	V:SetGlobal(true); M.runTimers(); M.runTimers()
	local ok, bad = all(V, "none")
	check(ok, "Global Inventory, off: no values" .. (bad ~= "" and (" (" .. bad .. ")") or ""))
	n:Set("sectionValues", true); M.runTimers()
	local h = headers(V)[1]
	check(h and shows(h) ~= "none", "Global Inventory, on: values back (" .. tostring(h and shows(h)) .. ")")
	check((n.errors or 0) == 0, "no errors")
end)()

;(function()
	-- What's New: 1.9.4's entry, under 1.9 as an update
	local n, M = boot(nil, { whatsNewSeen = "1.9.3", whatsNewPatchSeen = { ["1.9.2"] = true, ["1.9.1"] = true }, whatsNewButtonSeen = "1.9.2" })
	local WN = n.WhatsNew
	local e = WN.ENTRIES[9]   -- (by design since 1.9.8: four places down, after 1.9.8's, 1.9.7's, 1.9.6's and 1.9.5's entries)   -- (by design since 1.10.1: one more place down, after 1.10.1's entry)   -- (by design since 1.12.0-beta4: one more place down, after the 1.12 card)
	check(e.v == "1.9.4" and e.heading == "BagSmith 1.9.4" and #e.items == 2, "the 1.9.4 entry, two bullets")
	check(e.items[1] == "|cfffac775Section Values in Compact View:|r Compact View now shows what each section is worth, too. Just hover over or click the little coin on a section's header.", "Section Values in Compact View, word for word as chosen")
	check(e.items[2] == "|cfffac775Show Section Values:|r prefer clean headers? Turn the values off in Settings > Sections. You can still hover a section's name to see them.", "Show Section Values, word for word as chosen")
	local text = table.concat(e.items, " ")
	check(not text:find("\226\128\148") and not text:find("\226\128\147"), "no em or en dashes")
	local tabs = WN:Tabs()
	-- (by design since 1.9.5: 1.9.3 got an entry afterwards)
	check(tabs[1].v == "1.9.0" and #tabs[1].patches == 4 and tabs[1].patches[1].v == "1.9.4" and tabs[1].patches[2].v == "1.9.3" and tabs[1].patches[3].v == "1.9.2" and tabs[1].patches[4].v == "1.9.1", "the 1.9 tab: 1.9.4, 1.9.3, 1.9.2 and 1.9.1 under it")
	check(not WN:Pending(), "from 1.9.3: no pop-up (an update)")
	check(WN:PatchNew(tabs[1].patches[1]) and not WN:PatchNew(tabs[1].patches[3]), "1.9.4 says NEW; 1.9.2, already opened, doesn't")
	check(WN:ButtonNew(), "Settings' What's New button: NEW")
	n.version = "1.9.3"
	check(#WN:Tabs()[1].patches == 3, "(running 1.9.3: no 1.9.4 entry yet; 1.9.3, 1.9.2, 1.9.1)")
	check((n.errors or 0) == 0, "no errors")
end)()
