;(function()
	-- 1.5.0-beta2 (Shweep's feedback): a top-level Item Icons page directly below Style, holding everything about an
	-- item's picture and its marks; Style keeps the window. Settings move without changing; one set of words:
	-- Icons view (the view), item icon (an item's picture), mark (anything drawn on it), Icon Corners.
	for _, skin in ipairs({ "modern", "classic" }) do
		package.loaded.mock = nil
		local M = require("mock")
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, border = "unc", iconSize = 40, dimJunk = false, iconItemLevel = true } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local P = n.SettingsPanel
		P:Show()
		-- the menu: Item Icons right below Style
		local navOrder = {}
		for _, b in ipairs(P.navButtons or {}) do
			local t = (b.label and b.label.text) or (b.text and b.text.text) or (b.GetText and b:GetText())
			if b:IsShown() and t then navOrder[#navOrder + 1] = t end
		end
		local nav = table.concat(navOrder, "|")
		check(nav:find("Style|Item Icons|Windows", 1, true) ~= nil, skin .. ": Item Icons is its own page, right below Style (" .. nav .. ")")
		local function page(id)
			P:ShowPage(id)
			local heads, keys, texts = {}, {}, {}
			for kind, pool in pairs(P.pools) do
				for _, w in ipairs(pool) do
					if w:IsShown() then
						if kind == "head" then heads[#heads + 1] = { y = -(w.points[1] and w.points[1][5] or 0), t = w.text.text } end
						if w.key then keys[w.key] = w end
						for _, f in ipairs({ w.text, w.help, w.label }) do if f and f.text then texts[#texts + 1] = f.text end end
					end
				end
			end
			table.sort(heads, function(a, b) return a.y < b.y end)
			local h = {}; for _, x in ipairs(heads) do h[#h + 1] = x.t end
			return table.concat(h, " > "), keys, table.concat(texts, " || ")
		end
		local styleHeads, styleKeys, styleText = page("look")
		check(styleHeads == "Skin > Colors > Size > Layout", skin .. ": Style keeps the window: " .. styleHeads)
		check(not styleKeys.border and not styleKeys.iconSize and not styleKeys.dimJunk and not styleKeys.newdot and not styleKeys.iconItemLevel and styleKeys.scale and styleKeys.rowHeight and styleKeys.splitView, skin .. ": the item-picture settings left Style; scale, rows and layout stayed")
		local iconHeads, iconKeys, iconText = page("icons")
		check(iconHeads == "Appearance > Marks > Icon Corners", skin .. ": Item Icons: " .. iconHeads)
		check(iconKeys.border and iconKeys.iconSize and iconKeys.dimJunk and iconKeys.newdot and iconKeys.iconItemLevel, skin .. ": Rarity Borders, Icon Size, Dim Junk, Green Dot and Item Level are on Item Icons")
		check(n.db.border == "unc" and n.db.iconSize == 40 and n.db.dimJunk == false and n.db.iconItemLevel == true, skin .. ": moving them changed no value")
		-- the words
		local all = styleText .. " || " .. iconText
		check(not all:find("Icon View", 1, true) and not all:find("icon view", 1, true) and not all:find("Icon view", 1, true), skin .. ": no \"Icon View\" or \"icon view\" left: it's Icons view")
		check(all:find("Split View (Icons View)", 1, true) and all:find("Icon Size (Icons View)", 1, true) and all:find("Rarity Borders", 1, true) and all:find("Item Level (ilvl)", 1, true) and all:find("Green Dot on New Items", 1, true), skin .. ": the new labels")
		check(not all:find("on Icons", 1, true), skin .. ": no \"on Icons\" in labels: the page says it")
		check(all:find("Hidden in By Section, where a free space belongs to no section.", 1, true) and not all:find("grouping by type", 1, true), skin .. ": Show Empty Slots no longer says \"grouping by type\" (By Section since 1.4.0)")
		-- search still finds them on their new page
		local box = P.frame.search
		box:SetText("rarity"); box:GetScript("OnTextChanged")(box, true)
		local found = false
		for _, w in ipairs(P.pools.seg) do if w:IsShown() and w.key == "border" then found = true end end
		check(found, skin .. ": searching \"rarity\" finds Rarity Borders")
		box:SetText(""); box:GetScript("OnTextChanged")(box, true)
		P:Hide()
	end
end)()
