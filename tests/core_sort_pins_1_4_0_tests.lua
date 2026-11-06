;(function()
	-- 1.4.0: Sort: Off (bag order), "By Section", and pinned sections
	local function boot(profile)
		package.loaded.mock = nil
		local M = require("mock")
		-- deliberately out of quality and name order in the bag
		M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
		M.put(0, 2, { id = 117, name = "Tough Jerky", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
		M.put(0, 3, { id = 9001, name = "Azure Ring", q = 3, count = 1, class = 4, subclass = 0, price = 50, equip = "INVTYPE_FINGER" })
		M.put(0, 4, { id = 2592, name = "Wool Cloth", q = 1, count = 3, class = 7, subclass = 5, price = 2 })
		M.put(0, 5, { id = 9002, name = "Broken Fang", q = 0, count = 1, class = 15, subclass = 0, price = 3 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = profile or { skin = "modern" } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); M.runTimers(); M.runTimers()
		return n, M
	end
	local function order(V)
		local t = {}
		for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and not b.rec.empty then t[#t + 1] = b.rec.name end end
		return t
	end
	local function header(n, V, id)
		for _, h in pairs(n.Buttons.lanes[V.child] or {}) do if type(h) == "table" and h.IsShown and h:IsShown() and h.laneId == id then return h end end
	end
	local function laneOrder(V) return table.concat(V.laneIds or {}, ",") end

	-- ---- Sort: Off
	local n, M = boot()
	local V = n.Window.main
	V:SetPref("grp", "none"); V:SetPref("view", "list"); V:SetPref("sort", "quality"); n:RefreshViews(true); M.runTimers()
	check(order(V)[1] == "Azure Ring", "(control) by quality the rare ring leads")
	-- the button walks the modes and ends on Off
	V:SetPref("sort", "oldest"); V:SyncTools()
	V.btnSort:GetScript("OnClick")(V.btnSort); M.runTimers()
	check(V:Pref("sort") == "off" and V.btnSort.label.text == "Sort: Off", "after Oldest the Sort button reaches Off, and says so")
	check(table.concat(order(V), ",") == "Linen Cloth,Tough Jerky,Azure Ring,Wool Cloth,Broken Fang", "Off shows items in bag order, slot by slot (" .. table.concat(order(V), ",") .. ")")
	V.btnSort:GetScript("OnClick")(V.btnSort); M.runTimers()
	check(V:Pref("sort") == "quality", "and the next click goes back to Quality")
	-- a column click sorts for the moment; choosing Off clears it
	V:SetPref("sort", "oldest"); n:SortByColumn(V.st, "n"); n:RefreshViews(true); M.runTimers()
	check(V.st.colSort ~= nil, "(a column sort is active)")
	V.btnSort:GetScript("OnClick")(V.btnSort); M.runTimers()
	check(V.st.colSort == nil and V:Pref("sort") == "off", "choosing Off clears the column sort")
	-- the setting and its validators
	check(n:Set("sort", "off") ~= false and n.db.sort == "off", "Off is a valid default sort")
	check(n:Set("sort", "bogus") == false and n.db.sort == "off", "unknown sorts are refused")
	local SP = n.SettingsPanel; SP:Show(); SP:ShowPage("sorting")
	local seg; for _, w in ipairs(SP.pools.seg) do if w:IsShown() and w.key == "sort" then seg = w end end
	local offBtn = false; for _, b in ipairs(seg and seg.btns or {}) do if b:IsShown() and b.label.text == "Off" then offBtn = true end end
	check(offBtn and seg.help.text:find("bag order", 1, true), "Sorting & Filters offers Off, and says it means bag order")
	SP:Hide()

	-- ---- By Section
	local labels = {}
	for _, box in ipairs(V.segBoxes or {}) do for _, b in ipairs(box.btns or {}) do if b.label then labels[#labels + 1] = b.label.text end end end
	local all = table.concat(labels, "|")
	check(all:find("All|By Section|By Bag", 1, true) and not all:find("By Type", 1, true), "the grouping row reads All, By Section, By Bag (" .. all .. ")")

	-- ---- pinned sections
	n, M = boot()
	V = n.Window.main
	V:SetPref("view", "list"); V:SetPref("sort", "quality")
	local S = n.Sections
	check(S:Pinnable("TradeGoods") and not S:Pinnable("~recent") and not S:Pinnable("~fav") and not S:Pinnable("~gs:Tank") and not S:Pinnable(""), "item sections can be pinned; Recent, Favorites, gear sets and All Items can't")
	-- All view: the pinned section near the top, its items not repeated below
	V:SetPref("grp", "none"); S:SetPinned("TradeGoods", true); M.runTimers(); M.runTimers()
	check(laneOrder(V) == "TradeGoods,~all", "All view: the pinned section, then All Items (" .. laneOrder(V) .. ")")
	local trade = 0; for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.cat == "TradeGoods" then trade = trade + 1 end end
	check(trade == 2, "its two items appear once, in the pinned section, not again in All Items (" .. trade .. ")")
	local h = header(n, V, "TradeGoods")
	check(h and h.count.text:find("Pinned", 1, true) and h.count.text:find("ui%-pin"), "the pinned header says Pinned, with the pin")
	-- Recent keeps the very top
	n:Set("recentSection", true)
	n.ui.recentSince = 0
	for _, r in ipairs(n.items) do r.firstSeen = time() end
	n:RefreshViews(true); M.runTimers()
	local ids = V.laneIds or {}
	if ids[1] == "~recent" then check(ids[2] == "TradeGoods", "below Recent, the pinned section comes first (" .. laneOrder(V) .. ")")
	else check(ids[1] == "TradeGoods", "the pinned section leads when there's no Recent (" .. laneOrder(V) .. ")") end
	n:Set("recentSection", false); M.runTimers()
	-- By Section: the pinned section moves up, as it is
	V:SetPref("grp", "type"); n:RefreshViews(true); M.runTimers()
	check((V.laneIds or {})[1] == "TradeGoods", "By Section: the pinned section comes first (" .. laneOrder(V) .. ")")
	h = header(n, V, "TradeGoods")
	check(h and h.count.text:find("Pinned", 1, true), "and says Pinned there too")
	-- By Bag ignores pins
	V:SetPref("grp", "bag"); n:RefreshViews(true); M.runTimers()
	local anyPinned = false; for _, id in ipairs(V.laneIds or {}) do if id == "TradeGoods" then anyPinned = true end end
	check(not anyPinned, "By Bag ignores pins")
	-- the header menu: Unpin for a pinned section, Pin to Top for others, nothing for Recent
	V:SetPref("grp", "type"); n:RefreshViews(true); M.runTimers()
	local function menuTexts() local t = {}; for _, r in ipairs(n.menuFrame and n.menuFrame.rows or {}) do if r:IsShown() then t[#t + 1] = r.text.text end end return table.concat(t, "|") end
	S:SectionMenu("TradeGoods", header(n, V, "TradeGoods"))
	check(menuTexts():find("Unpin", 1, true), "a pinned section's menu offers Unpin")
	S:SectionMenu("Consumables", header(n, V, "Consumables"))
	check(menuTexts():find("Pin to Top", 1, true), "another section's menu offers Pin to Top")
	S:SectionMenu("~recent", nil)
	check(not menuTexts():find("Pin to Top", 1, true) and not menuTexts():find("Unpin", 1, true), "Recent's menu has no pin")
	if n.menuFrame then n.menuFrame:Hide() end
	-- the settings rows
	SP = n.SettingsPanel; SP:Show(); SP:ShowPage("sections")
	local rows = {}; for _, w in ipairs(SP.pools.pin) do if w:IsShown() then rows[w.id] = w end end
	check(rows.TradeGoods and rows.TradeGoods.box:GetChecked() and rows.Consumables and not rows.Consumables.box:GetChecked() and not rows["~recent"], "Sections settings list every item section with its pin")
	rows.Consumables.box:SetChecked(true); rows.Consumables.box:GetScript("OnClick")(rows.Consumables.box); M.runTimers()
	check(S:Pinned("Consumables"), "ticking a row pins that section")
	SP:Hide()
	-- two pinned sections follow Section Order
	n:RefreshViews(true); M.runTimers()
	local iC, iT; for i, id in ipairs(V.laneIds or {}) do if id == "Consumables" then iC = i elseif id == "TradeGoods" then iT = i end end
	check(iC and iT and iC < iT and iT == 2, "two pinned sections lead in their Section Order (" .. laneOrder(V) .. ")")
	S:SetPinned("Consumables", false); S:SetPinned("TradeGoods", false); M.runTimers()
	check(not next(S:PinnedSet()), "unpinning clears them")

	-- ---- saved: pins are validated and survive a reload
	n, M = boot({ skin = "modern", pinnedSections = { TradeGoods = true, ["~recent"] = true, Gear = "yes", [5] = true } })
	check(n.Sections:Pinned("TradeGoods") and not n.Sections:Pinned("~recent") and not n.Sections:Pinned("Gear") and n.db.pinnedSections[5] == nil, "saved pins keep only item sections marked true")
end)()
