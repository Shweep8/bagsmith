-- 1.7.0-beta13: the 1.7.0-beta12 audit's own probe (ui/header_coin_transition.lua), its checks unchanged, kept in the suite. Evidence and the
-- report: docs/plugins/audit-1.7.0-beta12/.
;(function()
	-- ======== 1.7.0-beta10: section header values: one format for every header, the coin last (Shweep) ========
	for _, skin in ipairs({ "modern", "classic" }) do
		local S = skin .. ": "
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 9401, name = "Sword", q = 2, class = 2, subclass = 7, price = 500, equip = "INVTYPE_WEAPON", bind = 1, bound = true })
		M.put(0, 2, { id = 9402, name = "Axe", q = 2, class = 2, subclass = 0, price = 300, equip = "INVTYPE_WEAPON", bind = 2 })
		M.put(0, 3, { id = 9403, name = "Bread", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
		M.put(0, 4, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = skin, view = "icons", grp = "type", splitView = true, splitGear = true, sizeMode = "fixed", fixW = 440, recentSection = false } } }
		_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function() return nil end,
			GetAuctionPriceByItemID = function(_, id) return ({ [9401] = 10000, [9402] = 5000, [2589] = 20 })[id] end } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		table.insert(n.db.cols, "ah"); table.insert(n.db.iconCols or {}, "ah")
		n.Window:Show(); n:RefreshViews(true); M.runTimers(); M.runTimers()
		local V = n.Window.main
		local function headers() local l = {}; for _, h in pairs(n.Buttons.lanes[V.child] or {}) do if h:IsShown() and h.laneId and h.laneId ~= "~recent" then l[#l + 1] = h end end; return l end
		local function lane(id) for _, h in ipairs(headers()) do if h.laneId == id then return h end end end
		check(V.twoColumn and lane("GearSoulbound") and lane("GearBoE"), S .. "(setup) Split View, narrow, with the gear split")
		-- (mock text is 6 px a letter: one long title stands in for a column too narrow, as in Split View at 440)
		local realW
		local function setTitle(id, w)
			local h = lane(id)
			realW = realW or h.text.GetStringWidth
			h.text.GetStringWidth = w and function() return w end or realW
		end
		local all = headers()
		check(#all >= 4 and lane("GearBoE").sub:IsShown() and lane("GearBoE").sub.text == "V: " .. n.Money(300) .. ", AH: " .. n.Money(5000), S .. "(control) with room: one line")
		setTitle("GearSoulbound", 260); n:RefreshViews(true); M.runTimers()
		all = headers()
		local coins = 0
		for _, h in ipairs(all) do if h.valCoin and h.valCoin:IsShown() and not h.sub:IsShown() and not h.vAmt:IsShown() then coins = coins + 1 end end
		check(coins == #all, S .. "one header too narrow for its values: every header shows the coin (" .. coins .. " of " .. #all .. ")")
		local boe = lane("GearBoE")
		check(boe.valCoin.v == n.Money(300) and boe.valCoin.ah == n.Money(5000), S .. "the coin holds that section's V and AH")
		boe.valCoin:GetScript("OnEnter")(boe.valCoin)
		local tip = table.concat(GameTooltip.lines or {}, " ")
		check(tip:find("V: " .. n.Money(300), 1, true) and tip:find("AH: " .. n.Money(5000), 1, true), S .. "hovering it shows them (" .. tip .. ")")
		boe.valCoin:GetScript("OnLeave")(boe.valCoin)
		local collapsedBefore = n.db.collapsed and n.db.collapsed.GearBoE
		GameTooltip:Hide()
		boe.valCoin:GetScript("OnClick")(boe.valCoin, "LeftButton")
		tip = table.concat(GameTooltip.lines or {}, " ")
		check(tip:find("V: " .. n.Money(300), 1, true) and (n.db.collapsed and n.db.collapsed.GearBoE) == collapsedBefore, S .. "clicking it shows the same, and doesn't collapse the section")
		GameTooltip:Hide()
		local sw = lane("GearSoulbound")
		check(sw.valCoin.ah == "-", S .. "soulbound gear has no AH value: its coin says AH: -")
		for w=0,250,5 do
            setTitle("GearSoulbound",260); n:RefreshViews(true); M.runTimers()
            setTitle("GearSoulbound",w); n:RefreshViews(true); M.runTimers()
            local stacked, stale=0,0
            for _,h in ipairs(headers()) do
                if h.vAmt:IsShown() then stacked=stacked+1; if h.valCoin and h.valCoin:IsShown() then stale=stale+1 end end
            end
            if stale>0 then print('STALE COINS '..skin..' width='..w..' stacked='..stacked..' stale='..stale) end
            check(stale==0, skin..' no coin over stacked values at title width '..w)
        end
		setTitle("GearSoulbound", nil); n:RefreshViews(true); M.runTimers()
		-- room enough: one line in every header, no coin
		local one = 0
		all = headers()
		for _, h in ipairs(all) do if h.sub:IsShown() and h.sub.text:find("^V: ") and not (h.valCoin and h.valCoin:IsShown()) then one = one + 1 end end
		check(#all > 0 and one == #all, S .. "with room: every header shows its values on one line, no coin (" .. one .. " of " .. #all .. ")")
		_G.Auctionator = nil
	end
	_G.BagSmithDB = nil
end)()

