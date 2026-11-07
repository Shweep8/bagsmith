;(function()
	-- 1.5.0-beta4 (Shweep's feedback on beta3): gold and currencies survive logout; the gear-set shield fits; the stack
	-- count is protected; other addons' marks keep their own size; bag-window slots answer bag and slot; the game's
	-- rarity border stays invisible on bag slots; /bs debug and /bs corners help find problems.
	local function boot(prefs)
		package.loaded.mock = nil
		local M = require("mock")
		M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
		M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 12, class = 7, subclass = 5, price = 1 })
		M.put(0, 2, { id = 9001, name = "Azure Ring", q = 2, count = 1, class = 4, subclass = 0, ilvl = 24, price = 50, equip = "INVTYPE_FINGER" })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local profile = { skin = "modern" }
		for k, v in pairs(prefs or {}) do profile[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = profile } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M
	end
	local function said(M, pat) for _, l in ipairs(M.log) do if l:find(pat, 1, true) then return true end end end

	-- ---- 1. gold and currencies at logout
	local n, M = boot()
	local money = 23400
	_G.GetMoney = function() return money end
	-- (1.5.0: the wallet is modelled through the mock game's currency list, as the logout save now takes the wallet
	-- only from BagSmith's capture of that list)
	M.currencies = { { name = "Honor", id = 1, quantity = 77, icon = 1, quality = 1 } }
	n.Currency:Invalidate()
	n:SaveCache()
	local key = n:CharKey()
	check(BagSmithDB.cache[key].gold == 23400 and BagSmithDB.cache[key].currencies["c:1"], "(control) a save during play has the gold and currencies")
	money = 0; M.currencies = {}   -- the game reports nothing while you log out
	M.fire("PLAYER_LOGOUT")
	check(BagSmithDB.cache[key].gold == 23400 and BagSmithDB.cache[key].currencies["c:1"] and BagSmithDB.cache[key].currencies["c:1"].count == 77, "a logout that reports 0 gold and no currencies keeps what play saw")
	n.loggingOut = nil   -- (a later session in this test)
	money = 0; M.fire("PLAYER_MONEY"); M.runTimers()   -- you really spent it all, during play
	M.fire("PLAYER_LOGOUT")
	check(BagSmithDB.cache[key].gold == 0, "gold really spent down to 0 during play is saved as 0")
	n.loggingOut = nil
	money = 99; M.fire("PLAYER_LOGOUT")
	check(BagSmithDB.cache[key].gold == 99, "a real amount at logout is saved as it is")

	-- ---- 2. the gear-set shield: about 40% of the icon, inside its quarter, its count a badge on the shield
	n.Window:Show(); M.runTimers(); M.runTimers()
	local V = n.Window.main
	V:SetPref("view", "icons"); V:SetPref("grp", "none"); n:RefreshViews(true); M.runTimers()
	local P = n.SettingsPanel
	local ok = true
	for _, size in ipairs({ 24, 37, 48 }) do
		n:Set("iconSize", size); P:Show(); P:ShowPage("icons")
		-- (1.5.0-beta8: the editor's preview is a fixed large sample; draw it at each icon size for this check)
		local b = P.pools.cornerCards[1].preview
		b:SetSize(size, size); n.Corners:DrawPreview(b, "cell", size - 4)
		local px = size - 4
		local s = b.linkMark:GetWidth()
		-- (1.5.0-beta6: flush in its corner, cropped to the drawn part of the image, so a little narrower than tall)
		local tall = math.max(9, math.floor(px * 0.40 + 0.5))
		local want = math.min(math.floor(tall * (52 / 64) + 0.5), math.floor(px / 2))
		local p = b.linkMark.points[1]
		local bp = b.linkCount.points[1]
		if not (b.linkMark:IsShown() and s == want and p[1] == "BOTTOMLEFT" and p[4] == 0 and p[5] == 0 and bp[1] == "CENTER" and bp[2] == b.linkMark and bp[3] == "TOPRIGHT") then ok = false end
		-- every picture mark stays inside its quarter of the icon
		for _, k in ipairs({ "junkCoin", "pawnArrow", "linkMark" }) do
			local r = b[k]
			if r and r:IsShown() and r:GetWidth() > math.floor(px / 2) then ok = false end
		end
		P:Hide()
	end
	check(ok, "the shield scales with the icon (about 40%), sits inside its corner, its count a badge on it; picture marks stay inside their quarter, at Icon Size 24, 37 and 48")

	-- ---- 3. the stack count is protected
	local C = n.Corners
	C:Remove("quantity")
	check(C:CornerOf("quantity") == "bottom_right", "the stack count can't be hidden")
	BagSmith.API.RegisterCornerWidget("BR Mark", "br_first", function() return true end, function(btn) return btn:CreateTexture() end, { corner = "bottom_right", priority = 1 })
	check(n.db.iconCorners.bottom_right[1] == "quantity" and n.db.iconCorners.bottom_right[2] == "br_first", "an addon asking for first place in its corner goes after the stack count")
	C:Move("br_first", -1)
	check(n.db.iconCorners.bottom_right[1] == "quantity", "nothing moves above it")
	C:Place("quantity", "top_left")
	check(n.db.iconCorners.top_left[1] == "quantity", "it can move to another corner, and goes first there")
	C:Reset()
	n.db.iconCorners.bottom_right = {}; C:Normalize()
	check(C:CornerOf("quantity") == "bottom_right" and n.db.iconCorners.bottom_right[1] == "quantity", "saved settings missing it get it back, first in the bottom right")
	P:Show(); P:ShowPage("icons")
	-- (1.5.0-beta10) its dropdown: locked (no menu, a lock instead of x), and it isn't offered as another corner's backup
	local qrow
	for _, r in ipairs(P.pools.cornerCards[1].groups.bottom_right.rows) do if r:IsShown() and r.id == "quantity" then qrow = r end end
	local addItems = P.CornerChoices("top_left", 2, nil, true)
	local offered = false; for _, it in ipairs(addItems) do if it.text:find("Stack Count", 1, true) then offered = true end end
	local firstItems = P.CornerChoices("top_left", 1, "junk", false)
	local canMove = false; for _, it in ipairs(firstItems) do if it.text == "Stack Count (in Bottom Right)" then canMove = true end end
	check(qrow and qrow.drop.locked and not qrow.drop.onPick and qrow.lock:IsShown() and not qrow.remove:IsShown() and not offered and canMove, "its dropdown is locked; it isn't offered as a backup, but another corner's first dropdown can move it there")
	P:Hide()

	-- ---- 4. other addons' marks keep their own size; scaled only if they ask
	local made = {}
	BagSmith.API.RegisterCornerWidget("Own Size", "own_size", function() return true end, function(btn) local t = btn:CreateTexture(); t:SetSize(14, 14); made.own = made.own or t; return t end, { corner = "top_right", priority = 1 })
	BagSmith.API.RegisterCornerWidget("Scaled", "scaled", function() return true end, function(btn) local t = btn:CreateTexture(); t:SetSize(14, 14); t.bagsmithScale = true; made.scaled = made.scaled or t; return t end, { corner = "top_left", priority = 1 })
	n:Set("iconSize", 24); n:RefreshViews(true); M.runTimers()
	local ring
	for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == 9001 then ring = b end end
	local own, scaled = ring.cornerWidgets.own_size, ring.cornerWidgets.scaled
	check(own and own:GetWidth() == 14, "a mark that sizes itself keeps its size (" .. tostring(own and own:GetWidth()) .. ")")
	check(scaled and scaled:GetWidth() < 14, "a mark that asks (bagsmithScale) is scaled with the icon (" .. tostring(scaled and scaled:GetWidth()) .. ")")

	-- ---- 5. bag-window slots answer bag and slot
	local host = CreateFrame("Frame", nil, UIParent)
	local mb = n.Buttons:GetMirror(host, 1); mb:SetID(4); mb.bag = 2
	check(mb.GetBagID and mb:GetBagID() == 2 and mb:GetID() == 4, "a bag window's slot answers its bag and slot, like a real bag slot")

	-- ---- 6. the game's rarity border stays invisible; the diagnostic
	local sb = n.Buttons:Get(0, 1)
	check(sb.IconBorder and sb.IconBorder.alpha == 0, "the game's rarity border is fully transparent on bag slots")
	sb.IconBorder:Show(); sb.IconBorder:SetVertexColor(1, 1, 1)   -- the template shows it again on its own
	check(sb.IconBorder.alpha == 0, "and stays invisible when the game's own updates show it again")
	n.db.debug = true
	local stray = sb:CreateTexture(); stray:SetTexture("Interface\\\\Common\\\\WhiteIconFrame"); stray:Show(); sb.SomeOverlay = stray
	sb.GetRegions = function() return sb.icon, stray end
	sb.templateReported = nil
	sb:GetScript("OnEnter")(sb)
	check(said(M, "game template pieces still visible: SomeOverlay"), "with /bs debug on, hovering a slot names a game template piece still showing")
	stray:Hide(); sb.templateReported = nil
	sb:GetScript("OnEnter")(sb)
	check(said(M, "no game template pieces visible"), "and says so when there are none")

	-- ---- 7. /bs corners
	SlashCmdList.BAGSMITH("corners")
	check(said(M, "Icon corners:") and said(M, "Stack Count (quantity): Bottom Right, 1 of") and said(M, "Own Size (own_size): Top Right") and said(M, "Icons view only"), "/bs corners lists every mark, where it is, and List support")
end)()
