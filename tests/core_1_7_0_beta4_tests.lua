;(function()
	-- ======== 1.7.0-beta4 ========
	-- ---- Settings > Sections (Shweep: "extremely long scrollable lists"): one table, each section once in Section Order,
	-- with its Pin, Vendor and AH boxes on the same row, instead of three lists of every section
	local function boot(skin, prof)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
		M.put(0, 2, { id = 118, name = "Minor Healing Potion", q = 1, count = 3, class = 0, subclass = 1, price = 5 })
		M.installEquipmentSets()
		M.put(0, 3, { id = 9301, name = "Iron Helm", q = 2, class = 4, subclass = 4, price = 100, equip = "INVTYPE_HEAD" })
		M.addSet("Tank", { [1] = M.bagLoc(0, 3) }, 135000)
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local pr = { skin = skin }
		for k, v in pairs(prof or {}) do pr[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = pr } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M
	end
	local function table_(P)
		local lists = {}
		for _, l in ipairs(P.pools.list) do if l:IsShown() then lists[#lists + 1] = l end end
		return lists
	end
	local function rowsOf(l) local out, order = {}, {}; for _, r in ipairs(l.rows) do if r:IsShown() then out[r.id] = r; order[#order + 1] = r.id end end return out, order end
	local function box(r, key) local b = r.cols and r.cols[key]; return b and b:IsShown() and b or nil end
	for _, skin in ipairs({ "modern", "classic" }) do
		local S = skin .. ": "
		local n, M = boot(skin)
		local Sx = n.Sections
		local custom = Sx:Create("Professions")
		local P = n.SettingsPanel; P:Show(); P:ShowPage("sections"); M.runTimers()
		local heads = {}
		for _, w in ipairs(P.pools.head) do if w:IsShown() then heads[#heads + 1] = w.text.text end end
		-- (1.7.0-beta5, by design) the card's name: Move, Pin and Hide Sections
		check(table.concat(heads, "|") == "Sections|Which Section an Item Goes To|Keys & Reagent Bag|Consumables|Gear|Move, Pin and Hide Sections", S .. "no Pinned Sections or Vendors & Auction House lists: " .. table.concat(heads, "|"))   -- (1.7.0-beta6, by design: the Gear card)
		local lists = table_(P)
		check(#lists == 1, S .. "one list of sections on the page (" .. #lists .. ")")
		local rows, order = rowsOf(lists[1])
		local seen, dup = {}, false
		for _, id in ipairs(order) do if seen[id] then dup = true end; seen[id] = true end
		check(not dup and #order == #n.db.laneOrder, S .. "each section once, in Section Order (" .. #order .. " of " .. #n.db.laneOrder .. ")")
		for i, id in ipairs(order) do if n.db.laneOrder[i] ~= id then check(false, S .. "row " .. i .. " is " .. id .. ", Section Order has " .. tostring(n.db.laneOrder[i])) break end end
		-- the headings over the columns, each box under its heading
		local head
		for _, w in ipairs(P.pools.listhead) do if w:IsShown() then head = w end end
		local labels = {}
		for _, t in ipairs(head and head.labels or {}) do if t:IsShown() then labels[#labels + 1] = t end end
		check(#labels == 3 and labels[1].text == "Pin" and labels[2].text == "Vendor" and labels[3].text == "AH", S .. "Pin, Vendor and AH headings")
		local g = rows.Gear
		for i, key in ipairs({ "pin", "vendor", "ah" }) do
			local b = box(g, key)
			check(b and b.points[1][1] == "CENTER" and b.points[1][3] == "RIGHT" and labels[i] and labels[i].points[1][4] == b.points[1][4], S .. key .. ": its box sits under its heading")
		end
		-- which rows have which boxes
		check(box(g, "pin") and box(g, "vendor") and box(g, "ah"), S .. "an item section: pin, vendor and AH")
		check(box(rows[custom], "pin") and box(rows[custom], "vendor") and box(rows[custom], "ah"), S .. "a custom section too")
		check(rows["~recent"] and not box(rows["~recent"], "pin") and not box(rows["~recent"], "vendor") and not box(rows["~recent"], "ah"), S .. "Recent Items: just its place in the order")
		check(rows["~fav"] and not box(rows["~fav"], "pin") and box(rows["~fav"], "vendor") and box(rows["~fav"], "ah"), S .. "Favorites: hidden at vendors or the AH, but not pinned")
		check(rows["~gs"] and rows["~gs"].text.text == "Gear Sets" and not box(rows["~gs"], "pin") and box(rows["~gs"], "vendor"), S .. "one Gear Sets row with its Vendor and AH boxes")
		check(rows["~ky"] and not box(rows["~ky"], "vendor") and rows["~rb"] and not box(rows["~rb"], "vendor"), S .. "Keys and Reagent Bag: no hiding, as before")
		-- the names keep the room left of the boxes
		local r1 = rows.Gear
		local p2 = r1.text.points[2]
		check((p2[4] or p2[2]) < -54 - 2 * 52, S .. "a section's name ends left of the boxes")
		-- using it
		box(rows.Consumables, "pin"):SetChecked(true); box(rows.Consumables, "pin"):GetScript("OnClick")(box(rows.Consumables, "pin")); M.runTimers()
		check(Sx:Pinned("Consumables"), S .. "Pin pins the section")
		lists = table_(P); rows = rowsOf(lists[1])
		check(box(rows.Consumables, "pin"):GetChecked(), S .. "and the table shows it pinned")
		local v = box(rows.Gear, "vendor"); v:SetChecked(false); v:GetScript("OnClick")(v); M.runTimers()
		local a = box(rowsOf(table_(P)[1]).Gear, "ah"); a:SetChecked(false); a:GetScript("OnClick")(a); M.runTimers()
		check(not Sx:Shown("Gear", "vendor") and not Sx:Shown("Gear", "ah"), S .. "Vendor and AH unticked: hidden at both")
		rows = rowsOf(table_(P)[1])
		check(not box(rows.Gear, "vendor"):GetChecked() and not box(rows.Gear, "ah"):GetChecked(), S .. "and the boxes show it")
		-- the arrows still reorder, the boxes follow their section
		local iC = n.IndexOf(n.db.laneOrder, "Consumables")
		rows.Consumables.down:GetScript("OnClick")(rows.Consumables.down); M.runTimers()
		check(n.IndexOf(n.db.laneOrder, "Consumables") == iC + 1, S .. "the arrows still move a section")
		rows = rowsOf(table_(P)[1])
		check(box(rows.Consumables, "pin"):GetChecked() and not box(rows.Gear, "vendor"):GetChecked(), S .. "and each row's boxes stay with its section")
		-- a box explains itself
		local shown
		local realText = n.TipText
		n.TipText = function(tip, text, ...) shown = text; return realText(tip, text, ...) end
		box(rows.Gear, "vendor"):GetScript("OnEnter")(box(rows.Gear, "vendor"))
		check(shown == "Shown at vendors. Untick to hide it while a vendor is open.", S .. "the Vendor box's tooltip (" .. tostring(shown) .. ")")
		n.TipText = realText; GameTooltip:Hide()
		-- the explanation, and the highlight setting after the table
		local txt = {}
		for _, w in ipairs(P.pools.text) do if w:IsShown() then txt[#txt + 1] = w.text.text end end
		local all = table.concat(txt, "\n")
		check(all:find("Pin keeps a section at the top, just under Recent.", 1, true) and all:find("Untick Vendor or AH to hide a section while you're at a vendor or the auction house.", 1, true), S .. "the card says what Pin, Vendor and AH do")
		local hl
		for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == "pinnedHighlight" then hl = w end end
		check(hl, S .. "Highlight Pinned Sections is still on the page")
		-- Junk left out of the order still gets its row, last, without arrows
		local i = n.IndexOf(n.db.laneOrder, "Junk"); table.remove(n.db.laneOrder, i)
		P:Refresh(); M.runTimers()
		rows, order = rowsOf(table_(P)[1])
		check(order[#order] == "Junk" and box(rows.Junk, "pin") and box(rows.Junk, "vendor") and not rows.Junk.up:IsShown() and not rows.Junk.down:IsShown(), S .. "Junk outside the order: its own last row, pin and hiding, no arrows")
		table.insert(n.db.laneOrder, "Junk")
		-- search finds the table by its columns
		for _, q in ipairs({ "pin", "vendor", "auction" }) do
			P.frame.search:SetText(q); P.frame.search:GetScript("OnTextChanged")(P.frame.search); M.runTimers()
			local found = false
			for _, l in ipairs(P.pools.list) do if l:IsShown() then for _, r in ipairs(l.rows) do if r:IsShown() and r.id == "Gear" and box(r, "vendor") then found = true end end end end
			check(found, S .. "searching \"" .. q .. "\" finds the Section Order table")
		end
		P.frame.search:SetText(""); P.frame.search:GetScript("OnTextChanged")(P.frame.search)
		P:Hide()
	end

	-- ---- the Loot Helper's wording (Shweep's): the footer says what the list does, its (i) how it decides; Settings >
	-- Loot Helper says the same
	local loot = { { id = 9740, name = "Rough Gem" } }
	_G.GetNumLootItems = function() return #loot end
	_G.GetLootSlotType = function(i) return loot[i] and 1 or 0 end
	_G.GetLootSlotLink = function(i) return loot[i] and ("|Hitem:" .. loot[i].id .. ":0|h[" .. loot[i].name .. "]|h") end
	_G.GetLootSlotInfo = function(i) local l = loot[i]; if l then return "icon", l.name, 1, nil, 1 end end
	for _, basis in ipairs({ "vendor", "ah" }) do
		package.loaded.mock = nil
		local M = require("mock")
		for b = 1, 5 do M.sizes[b] = 0 end
		M.sizes[0] = 2
		M.put(0, 1, { id = 9801, name = "Trinket", q = 1, class = 15, subclass = 0, price = 2 })
		M.put(0, 2, { id = 9802, name = "Bauble", q = 1, class = 15, subclass = 0, price = 3 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", makeRoom = true, makeRoomValue = basis } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local realInfo = C_Item.GetItemInfo
		C_Item.GetItemInfo = function(id) local num = tonumber(tostring(id):match("item:(%d+)")) or id; if num == 9740 then return "Rough Gem", nil, 1, nil, nil, nil, nil, 1, nil, nil, 50 end return realInfo(id) end
		if basis == "ah" then n.AH.Available = function() return true end end
		M.fire("LOOT_OPENED"); M.runTimers()
		local f = n.MakeRoom.frame
		-- (1.7.0-beta10, by design: Shweep's layout) the (i) sits by the list's heading; the footer says what happens next
		check(f and f:IsShown() and f.foot.text == "Then Rough Gem goes in your bags." and f.footInfo:IsShown(), basis .. ": the footer says what happens next, and the (i) is by the list")
		local L = f.footInfo.lines
		check(f.footInfo.title == "How it decides" and #L == 5
			and L[1] == "Mostly it goes by price, cheapest first. Things you craft with stay further down, and if you have two stacks of something, the smaller one goes first."
			and L[2] == "Junk always shows up, even when it's worth more than what you're looting."
			and L[3] == "Anything you still need for a quest is never on the list, unless its heading is collapsed in your quest log."   -- (1.7.0-beta5, by design: F2)
			and L[4] == (basis == "ah" and "Prices come from the AH when it has one, otherwise the vendor." or "Prices come from the vendor.")
			and L[5] == "It learns what you craft with when you open your profession window.", basis .. ": its (i), in Shweep's words")
		f:Hide()
		local P = n.SettingsPanel; P:Show(); P:ShowPage("loothelper"); M.runTimers()
		local txt = {}
		for _, w in ipairs(P.pools.text) do if w:IsShown() then txt[#txt + 1] = w.text.text end end
		local subs = {}
		for _, w in ipairs(P.pools.sub) do if w:IsShown() then subs[#subs + 1] = w.text.text end end
		local all = table.concat(txt, "\n")
		check(table.concat(subs, "|"):find("What Shows Up First", 1, true)
			and all:find("It makes room for the most valuable item waiting, or the one you click. Free ways come first, then what you'd miss least. Mostly it goes by price, cheapest first.", 1, true)   -- (1.7.0-beta10, by design)
			and all:find("It learns what you craft with when you open your profession window.", 1, true)
			and all:find("Junk always shows up, even when it's worth more than what you're looting. Anything you still need for a quest is never on the list, unless its heading is collapsed in your quest log.", 1, true),   -- (1.7.0-beta5, by design: F2)
			basis .. ": Settings > Loot Helper explains it the same way")
		local seg
		for _, w in ipairs(P.pools.seg) do if w:IsShown() and w.key == "makeRoomValue" then seg = w end end
		check(seg and seg.help.text == "The prices it goes by. Where there's no AH price, it uses the vendor's.", basis .. ": Rank Suggestions By says what it's for")
		P:Hide()
	end
	_G.GetNumLootItems, _G.GetLootSlotType, _G.GetLootSlotLink, _G.GetLootSlotInfo = nil, nil, nil, nil
end)()
