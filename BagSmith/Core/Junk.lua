--[[
	Core/Junk.lua

	Sell Junk + Mark as Junk. Grey items are junk (Blizzard sells them with Sell All
	Junk); a character can also mark other items as junk. Marked items sort
	into the Junk section, show Blizzard's junk coin on their icon, and are
	sold right after Blizzard's own sale: BagSmith watches the game's
	sell-all function (it runs only after the player accepts Blizzard's
	confirmation) and sells the marked items inside that same click.

	If the game won't let BagSmith sell then, or Blizzard's button isn't
	usable (hidden or disabled with no grey items), a Sell Marked button
	appears on the vendor window instead; one click sells them all.

	Marks are per character (BagSmithCharDB.junkMarks, by item ID), kept
	across sessions. Items with no vendor price, and quest items, can't be
	marked; grey items are always junk.
--]]
local ADDON, ns = ...
local J = { blocked = 0 }
ns.Junk = J

local COIN_ATLAS = "bags-junkcoin"                 -- Blizzard's junk coin (bag item buttons)
local POUCH_ATLAS = "SpellIcon-256x256-SellJunk"   -- Blizzard's Sell All Junk button
local function atlasExists(name) return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil end

------------------------------------------------------------------------
-- Art: read from Blizzard where possible, with fallbacks (/bs check says).
------------------------------------------------------------------------
function J:SetCoin(tex)
	if atlasExists(COIN_ATLAS) then tex:SetAtlas(COIN_ATLAS); J.coinArt = "atlas " .. COIN_ATLAS
	else tex:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon"); J.coinArt = "gold coin texture (fallback)" end
end
-- The Junk column's icon: BagSmith's pouch-with-coin, drawn to match the
-- star and wallet beside it. (The Sell Marked button on Blizzard's vendor
-- window keeps Blizzard's own pouch, via SetPouch.)
function J:SetColumnIcon(tex) tex:SetTexture("Interface\\AddOns\\BagSmith\\Media\\ui-pouch.tga") end
J.ON_COLOR = { 0.98, 0.78, 0.46 }   -- every column icon that's "on" (marked, starred, tracked) is gold
function J:SetPouch(tex)
	local b = _G.MerchantSellAllJunkButton
	local icon = b and (b.Icon or b.icon)
	local atlas = icon and icon.GetAtlas and icon:GetAtlas()
	if atlas and atlas ~= "" then tex:SetAtlas(atlas); J.pouchArt = "atlas " .. atlas .. " (from the Sell All Junk button)"; return end
	if atlasExists(POUCH_ATLAS) then tex:SetAtlas(POUCH_ATLAS); J.pouchArt = "atlas " .. POUCH_ATLAS; return end
	tex:SetTexture("Interface\\Icons\\INV_Misc_Bag_10"); J.pouchArt = "bag icon texture (fallback)"
end

------------------------------------------------------------------------
-- What counts as junk
------------------------------------------------------------------------
function J:Marks()
	if not ns.cdb then return {} end
	if type(ns.cdb.junkMarks) ~= "table" then ns.cdb.junkMarks = {} end
	return ns.cdb.junkMarks
end
function J:Marked(itemID) return itemID and ns.cdb and type(ns.cdb.junkMarks) == "table" and ns.cdb.junkMarks[itemID] and true or false end
function J:Sellable(rec) return rec and rec.itemID and not rec.hasNoValue and (rec.sellPrice or 0) > 0 and true or false end
function J:IsGrey(rec) return rec and not rec.empty and rec.quality == 0 and J:Sellable(rec) or false end
-- In one of your gear sets (the game's equipment sets): never junk.
-- A failed read of the game's sets counts as membership: nothing is marked or sold on a guess (1.2.0).
local function inGearSet(rec)
	if not ns.GearSets then return nil end
	if ns.GearSets.readFailed then return { "(gear sets could not be read)" } end
	return ns.GearSets:SetsOf(rec) or nil
end
-- Can this item be marked? Your own items with a vendor price, better than
-- grey, not quest items, not in a gear set.
function J:Markable(rec)
	return rec and not rec.empty and not rec.cached and J:Sellable(rec) and (rec.quality or 0) > 0 and not rec.isQuest and not inGearSet(rec) and true or false
end
-- Junk: grey, or marked (marks are this character's, so another character's saved bags only show greys).
function J:IsJunk(rec)
	if not rec or rec.empty then return false end
	if J:IsGrey(rec) then return true end
	return not rec.cached and J:Marked(rec.itemID)
end

-- Why an item can't be marked (for the Junk column's tooltip).
function J:WhyNot(rec)
	if rec.cached then return "Marks are per character: switch to that character to mark their items." end
	if rec.isQuest then return "Quest items can't be marked as junk." end
	if ns.GearSets and ns.GearSets.readFailed then return "BagSmith couldn't check your gear sets just now, so nothing can be marked as junk. Try again in a moment." end
	local sets = inGearSet(rec)
	if sets then return ("It's in your gear set %s, so it can't be marked as junk."):format(sets[1]) end
	if not J:Sellable(rec) then return "This item can't be sold to a vendor, so it can't be marked as junk." end
	return "This item can't be marked as junk."
end

function J:Toggle(rec)
	if not rec or rec.empty then return end
	if J:IsGrey(rec) then ns:Print("Grey items are always sold with Sell All Junk."); return end
	-- Adding a mark needs an item that can be marked; removing one never does.
	if not J:Markable(rec) and not (not rec.cached and J:Marked(rec.itemID)) then return end
	local m = J:Marks()
	m[rec.itemID] = (not m[rec.itemID]) or nil
	ns:Scan()
	-- Show the change right away on every button for that item, even while
	-- rows hold still under the pointer; the move into Junk follows with the
	-- next full layout.
	for _, list in ipairs({ ns.Buttons.all, ns.Buttons.recent }) do
		for _, b in ipairs(list or {}) do
			if b.rec and b.rec.itemID == rec.itemID and not b.rec.empty and not b.rec.cached then
				b.rec.cat = m[rec.itemID] and "Junk" or b.rec.cat
				J:Decorate(b, b.rec)
			end
		end
	end
	ns:RefreshViews(true)
	J:UpdateSellButton()
end

------------------------------------------------------------------------
-- On the item buttons: the coin, the Junk column's icon, and dimming.
------------------------------------------------------------------------
-- An unmarked item's icon stays in place (so it can always be clicked) but is
-- invisible until you hover the row, faint then, brighter on the icon itself.
-- Moving from the row onto the icon never hides it.
local CELL_FAINT, CELL_HOVER, CELL_BLOCKED = 0.35, 0.8, 0.3
function J:PaintCell(b)
	local jc = b.colJunk
	if not jc then return end
	local state = jc.state or "none"
	local show = b.junkColumn and b.mode == "row" and b.hasItem and state ~= "none"
	jc:SetShown(show and true or false)
	if state == "eligible" then
		local over = jc.hover or b.rowHover or (b.IsMouseOver and b:IsMouseOver())
		jc.tex:SetAlpha(jc.hover and CELL_HOVER or (over and CELL_FAINT or 0))
		jc.tex:SetDesaturated(false); jc.tex:SetVertexColor(1, 1, 1)
	elseif state == "blocked" then
		-- Can't be marked: invisible, faint and greyed only on the icon itself.
		jc.tex:SetAlpha(jc.hover and CELL_BLOCKED or 0)
		jc.tex:SetDesaturated(true); jc.tex:SetVertexColor(1, 1, 1)
	else   -- grey or marked: on
		jc.tex:SetAlpha(1)
		jc.tex:SetDesaturated(false); jc.tex:SetVertexColor(J.ON_COLOR[1], J.ON_COLOR[2], J.ON_COLOR[3])
	end
end
-- Dim Junk Items: darker, not faded (fading let light icons wash out to
-- near white). The greyed icon gets a darkening sepia and stays mostly
-- opaque; row text turns a fixed muted sepia-grey.
local SEPIA = { 0.70, 0.62, 0.50 }
local DIM_ALPHA = 0.9
local DIM_TEXT = { 0.58, 0.53, 0.45 }
J.SEPIA, J.DIM_ALPHA, J.DIM_TEXT = SEPIA, DIM_ALPHA, DIM_TEXT
function J:Decorate(b, rec)
	local junk = rec and J:IsJunk(rec) or false
	if b.junkCoin then
		b.junkCoin:SetShown(junk)
		if junk then
			local w = b.icon and b.icon:GetWidth() or 24
			local s = math.max(10, math.floor((w > 0 and w or 24) * 0.45 + 0.5))
			b.junkCoin:SetSize(s, s)
			b.junkCoin:ClearAllPoints(); b.junkCoin:SetPoint("TOPLEFT", b.icon, "TOPLEFT", 1, -1)
		end
	end
	if b.colJunk then
		local state, reason = "none", nil
		if rec and not rec.empty then
			if J:IsGrey(rec) then state = "grey"
			elseif not rec.cached and J:Marked(rec.itemID) then state = "marked"   -- even if it couldn't be marked now: it can be unmarked
			elseif J:Markable(rec) then state = "eligible"
			else state, reason = "blocked", J:WhyNot(rec) end
		end
		b.colJunk.state, b.colJunk.reason = state, reason
		J:PaintCell(b)
	end
	-- Dim Junk Items: icon greyed and faded, row text faded.
	local dim = junk and ns.db and ns.db.dimJunk and true or false
	b.dimmedJunk = dim
	if b.icon then
		b.icon:SetAlpha(dim and DIM_ALPHA or 1)
		if dim then b.icon:SetDesaturated(true) elseif rec then b.icon:SetDesaturated(rec.isLocked and true or false) end
		if dim then b.icon:SetVertexColor(SEPIA[1], SEPIA[2], SEPIA[3]) else b.icon:SetVertexColor(1, 1, 1) end
	end
	for _, key in ipairs(ns.Buttons.COL_KEYS or {}) do
		local fs = b[key]
		if fs then
			fs:SetAlpha(1)
			local c = dim and DIM_TEXT or fs.baseColor
			if c then fs:SetTextColor(c[1], c[2], c[3]) end
		end
	end
end
function J:RowHover(b, on) b.rowHover = on and true or false; J:PaintCell(b) end
function J:CellEnter(jc)
	jc.hover = true
	local b = jc:GetParent()
	J:PaintCell(b)
	if not ns.TooltipsOK() then return end
	GameTooltip:SetOwner(jc, "ANCHOR_TOP")
	local key = J:Key()
	if jc.state == "blocked" then
		ns.TipText(GameTooltip, "Can't Be Marked as Junk"); ns.TipLine(GameTooltip, jc.reason or "", 0.6, 0.6, 0.6, true)
	elseif jc.state == "grey" then
		ns.TipText(GameTooltip, "Junk"); ns.TipLine(GameTooltip, "Grey items are always sold with Sell All Junk.", 0.6, 0.6, 0.6, true)
	elseif jc.state == "marked" then
		ns.TipText(GameTooltip, "Marked as Junk"); ns.TipLine(GameTooltip, "Sold with Sell All Junk. Click to unmark.", 0.6, 0.6, 0.6, true)
		if key then ns.TipLine(GameTooltip, ("Or press %s with the pointer on the item."):format(key), 0.6, 0.6, 0.6, true) end
	else
		ns.TipText(GameTooltip, "Mark as Junk"); ns.TipLine(GameTooltip, "Click to sell it with Sell All Junk.", 0.6, 0.6, 0.6, true)
		if key then ns.TipLine(GameTooltip, ("Or press %s with the pointer on the item."):format(key), 0.6, 0.6, 0.6, true)
		else ns.TipLine(GameTooltip, "Tip: set a key for this in Settings > Keybindings.", 0.6, 0.6, 0.6, true) end
	end
	GameTooltip:Show()
end
function J:CellLeave(jc)
	jc.hover = false
	local b = jc:GetParent()
	b.rowHover = b.IsMouseOver and b:IsMouseOver() or false
	J:PaintCell(b)
	GameTooltip:Hide()
end
-- The Mark as Junk key, as the game shows it, or nil.
function J:Key() return ns.KeyBinds and ns.KeyBinds:Key("BAGSMITH_MARKJUNK") end
function J:AddTooltipLines(tip, rec)
	if not (tip and rec and not rec.empty and not rec.cached and not J:IsGrey(rec)) then return end
	local marked = J:Marked(rec.itemID)
	if marked then ns.TipLine(tip, "Marked as junk: sold with Sell All Junk.", 0.98, 0.78, 0.46) end
	-- A hint only when a key is bound (no clutter otherwise).
	local key = J:Key()
	if key and (marked or J:Markable(rec)) then
		ns.TipLine(tip, ("Press %s to %s"):format(key, marked and "unmark" or "mark as junk"), 0.6, 0.6, 0.6)
	end
end

------------------------------------------------------------------------
-- Selling
------------------------------------------------------------------------
local function merchantOpen() return MerchantFrame and MerchantFrame:IsShown() and true or false end
J.MerchantOpen = merchantOpen

-- What can be sold right now, read from the bags themselves: grey items
-- and/or marked items ("all" or "marked"). The vendor price is the game's
-- at this moment (not the last scan's, which can be missing for items whose
-- details hadn't loaded yet). Items whose details still aren't loaded are
-- returned separately, after asking the game for them.
local function livePrice(itemID)
	return C_Item and C_Item.GetItemInfo and select(11, C_Item.GetItemInfo(itemID)) or nil
end
-- Junk selling (Blizzard's Sell All Junk, and BagSmith's own, which follows
-- the same rule) includes favorites and items in sections hidden at vendors.
-- That's allowed, but never silent: this says why an item might have been
-- expected to stay, or nil.
function J:ProtectReason(r)
	local parts = {}
	local sets = inGearSet(r)
	if sets then parts[#parts + 1] = ("gear set: %s"):format(sets[1]) end
	if ns.Marks and r.itemID and ns.Marks:IsFavorite(r.itemID) then parts[#parts + 1] = "favorite" end
	local S = ns.Sections
	if S then
		local sec = S:EffectiveSection(r)
		if sec and not S:Shown(sec, "vendor") then parts[#parts + 1] = ("hidden at vendors: %s"):format(S:Label(sec)) end
	end
	if #parts > 0 then return table.concat(parts, "; ") end
end
-- One chat line naming up to three such items, then "and N more".
function J:Remind(list, blizzard)
	if #list == 0 then return end
	local names = {}
	for i = 1, math.min(3, #list) do names[#names + 1] = ("%s (%s)"):format(list[i].name or "an item", list[i].reason) end
	local what = table.concat(names, ", ")
	if #list > 3 then what = what .. (" and %d more"):format(#list - 3) end
	if blizzard then
		ns:Print("Blizzard's Sell All Junk sold %s. Blizzard's button always sells every grey item, even favorites and hidden ones.", what)
	else
		ns:Print("Sold %s. Junk selling includes grey and junk-marked items even when they're favorites or hidden.", what)
	end
end
-- Blizzard's Sell All Junk: the greys it's selling are still in the bags
-- when its button is pressed. Note the ones you might have expected to stay,
-- then name only those that actually left their slots (checked shortly after,
-- and once more later for a big sale).
J.BLIZZ_CHECK = { 1.5, 4 }
function J:RemindBlizzardSale()
	local list = {}
	for _, r in ipairs(ns.items or {}) do
		if r.bag and r.slot and r.itemID and not r.empty and r.quality == 0 then
			local info = C_Container.GetContainerItemInfo(r.bag, r.slot)
			if info and info.itemID == r.itemID and not info.hasNoValue and livePrice(r.itemID) ~= 0 then
				local why = J:ProtectReason(r)
				if why then list[#list + 1] = { bag = r.bag, slot = r.slot, itemID = r.itemID, name = r.name, reason = why } end
			end
		end
	end
	if #list == 0 then return end
	local reported = {}
	local function check(final)
		local sold = {}
		for _, it in ipairs(list) do
			if not reported[it] then
				local info = C_Container.GetContainerItemInfo(it.bag, it.slot)
				if not (info and info.itemID == it.itemID) then sold[#sold + 1] = it; reported[it] = true end
			end
		end
		J:Remind(sold, true)
	end
	C_Timer.After(J.BLIZZ_CHECK[1], function() check(false) end)
	C_Timer.After(J.BLIZZ_CHECK[2], function() check(true) end)
end

function J:Sellables(kind)
	local ready, waiting, skipped = {}, {}, 0
	local kept = ns.Why:New()   -- junk that stays because it's protected (1.3.0: said in chat)
	for _, r in ipairs(ns.items or {}) do
		if r.bag and r.slot and r.itemID and not r.empty then
			local grey = r.quality == 0
			local marked = J:Marked(r.itemID)
			-- Gear set items are never sold by BagSmith (checked against where
			-- the game says set items are right now).
			local inSet, unreadable
			if ns.GearSets then inSet, unreadable = ns.GearSets:SetsAt(r.bag, r.slot) end
			if unreadable then inSet = { "(unreadable)" } end
			if inSet and ((kind == "all" and (grey or marked)) or (kind == "marked" and marked and not grey)) then
				ns.Why:Add(kept, unreadable and "unknown" or "gearset", r.name)
			end
			if not inSet and ((kind == "all" and (grey or marked)) or (kind == "marked" and marked and not grey)) then
				local info = C_Container.GetContainerItemInfo(r.bag, r.slot)
				if info and info.itemID == r.itemID and not info.isLocked then
					local price = livePrice(r.itemID)
					if info.hasNoValue or price == 0 then
						skipped = skipped + 1
					elseif price == nil then
						if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, r.itemID) end
						waiting[#waiting + 1] = { bag = r.bag, slot = r.slot, itemID = r.itemID }
					else
						ready[#ready + 1] = { bag = r.bag, slot = r.slot, itemID = r.itemID, value = price * (info.stackCount or r.count or 1),
							name = r.name, reason = J:ProtectReason(r), grey = grey }
					end
				end
			end
		end
	end
	return ready, waiting, skipped, kept
end
-- Kept for the Sell Marked button's tooltip and visibility.
function J:MarkedInBags() local ready, waiting = J:Sellables("marked"); for _, w in ipairs(waiting) do ready[#ready + 1] = w end; return ready end
function J:JunkInBags() local ready, waiting = J:Sellables("all"); for _, w in ipairs(waiting) do ready[#ready + 1] = w end; return ready end

-- Sell a list now, then check which items actually left the bags. Items
-- still there are reported once, and the Sell Marked button offers a
-- one-click retry; nothing is ever missed silently.
local VERIFY_DELAY, RETRY_DELAY = 0.6, 0.6
-- The check looks again while the server is still finishing (1.3.1): until nothing it sold is locked and the
-- count of what's left has held for one interval, or the last look.
local SETTLE_DELAY, SETTLE_TRIES = 0.6, 6
function J:Sell(kind, how, retried)
	if not merchantOpen() or InCombatLockdown() then return 0 end
	-- Gear set membership straight from the game, right before selling.
	if ns.GearSets and ns.GearSets.Refresh then ns.GearSets:Refresh() end
	local ready, waiting, skipped, kept = J:Sellables(kind)
	-- never silent about what stays: protected junk, and junk the vendor won't pay for
	if kept and kept.total > 0 then ns:Print("Kept %s out of the sale: %s.", kept.total == 1 and "1 item" or (kept.total .. " items"), ns.Why:Phrase(kept)) end
	if skipped > 0 then ns:Print("%d junk %s no vendor price, so %s.", skipped, skipped == 1 and "item has" or "items have", skipped == 1 and "it stays" or "they stay") end
	ns:Debug("Junk sale (%s): selling %d, waiting for item details %d, skipped %d (no vendor price)", how, #ready, #waiting, skipped)
	local before = J.blocked
	local n = 0
	for _, it in ipairs(ready) do
		if not merchantOpen() then break end
		if ns.MarkAction then ns.MarkAction("sell junk") end
		if pcall(C_Container.UseContainerItem, it.bag, it.slot) then n = n + 1 end
	end
	-- Items whose details hadn't loaded: try once more in a moment. The retry
	-- belongs to this merchant session and, for an automatic sale, re-checks
	-- that automatic selling is still allowed right before it sells.
	if #waiting > 0 and not retried then
		local visit, gen = J.visit or 0, J.autoGen or 0
		C_Timer.After(RETRY_DELAY, function()
			if visit ~= (J.visit or 0) or not merchantOpen() then return end
			if how == "auto" and gen ~= (J.autoGen or 0) then return end   -- the setting or profile changed meanwhile
			if how == "auto" and (not (ns.db and ns.db.autoSellJunk) or J.autoBlocked) then return end
			J:Sell(kind, how, true)
		end)
	end
	if #ready == 0 then return 0 end
	-- The check belongs to this merchant visit only (a settings change never
	-- silences the receipt of a sale that was already sent).
	local visit = J.visit or 0
	local tries, lastLeft = 0, nil
	local function check()
		if visit ~= (J.visit or 0) then return end   -- that merchant visit is over: nothing to report or block
		tries = tries + 1
		if tries == 1 and J.blocked > before then
			J.needsClick = true
			if how == "auto" then J.autoBlocked = true; ns:Print("The game needs a click to sell: use Sell All Junk.")
			else ns:Print("The game wants a click to sell marked items: use the Sell Marked button on the vendor window.") end
			J:UpdateSellButton()
			return
		end
		local sold, value, still, pending = 0, 0, {}, 0
		local remind = {}
		for _, it in ipairs(ready) do
			local info = C_Container.GetContainerItemInfo(it.bag, it.slot)
			if info and info.itemID == it.itemID then
				still[#still + 1] = { it = it, count = info.stackCount or 1 }
				if info.isLocked then pending = pending + 1 end
			else
				sold = sold + 1; value = value + it.value
				if it.reason then remind[#remind + 1] = it end
			end
		end
		-- The server may still be finishing: stacks it's selling stay in place (locked) for a moment. Look again until
		-- nothing is locked and what's left has held for one interval, or the last look (1.3.1).
		if #still > 0 and tries < SETTLE_TRIES and (pending > 0 or lastLeft ~= #still) then
			lastLeft = #still
			C_Timer.After(SETTLE_DELAY, check)
			return
		end
		ns:Debug("Junk sale check (%s, look %d): %d left the bags, %d still there (%d locked)", how, tries, sold, #still, pending)
		if sold > 0 then
			local money = GetCoinTextureString and GetCoinTextureString(value) or ns.Money(value)
			local noun = (kind == "marked") and "marked" or "junk"
			local fmt = (how == "after Sell All Junk") and "Also sold %d %s %s for %s." or "Sold %d %s %s for %s."
			ns:Print(fmt, sold, noun, sold == 1 and "item" or "items", money)
		end
		J:Remind(remind, false)
		if #still > 0 then
			-- Name what really didn't sell, and the button that will try again: greys go with Sell Junk, marked
			-- items with Sell Marked.
			local names, grey = {}, false
			for i, s in ipairs(still) do
				if s.it.grey then grey = true end
				if i <= 3 then names[#names + 1] = (s.it.name or "an item") .. ((s.count or 1) > 1 and (" x" .. s.count) or "") end
			end
			local more = #still - #names
			J.retry, J.retryJunk = true, grey
			ns:Print("Didn't sell: %s%s. Click %s (the pouch on the vendor window) to try again.", table.concat(names, ", "),
				more > 0 and (", and %d more"):format(more) or "", grey and "Sell Junk" or "Sell Marked")
		end
		J:UpdateSellButton()
	end
	C_Timer.After(VERIFY_DELAY, check)
	return n
end
function J:SellMarked(fromButton)
	return J:Sell(fromButton and (J.retry and "all" or "marked") or "marked", fromButton and "button" or "after Sell All Junk")
end
function J:AutoSell()
	if not (ns.db and ns.db.autoSellJunk) or J.autoBlocked then return 0 end
	return J:Sell("all", "auto")
end

-- The Sell Marked button: only when you have marked items and Blizzard's
-- button can't take them along (hidden, disabled, or the game wants a click).
function J:SellButton()
	if J.btn ~= nil then return J.btn or nil end
	if not MerchantFrame then J.btn = false; return nil end
	local b = CreateFrame("Button", "BagSmithSellMarkedButton", MerchantFrame)
	b:SetSize(36, 36)
	b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(b)
	J:SetPouch(b.icon)
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	b:SetScript("OnClick", function() J:SellMarked(true) end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		ns.TipText(GameTooltip, J:ButtonTitle())
		local junk = J.retry and J.retryJunk
		local list, value, loading = junk and J:JunkInBags() or J:MarkedInBags(), 0, false
		for _, it in ipairs(list) do if it.value then value = value + it.value else loading = true end end
		ns.TipLine(GameTooltip, ("%d %s %s for %s%s"):format(#list, junk and "junk" or "marked", #list == 1 and "item" or "items",
			GetCoinTextureString and GetCoinTextureString(value) or ns.Money(value), loading and " (some prices still loading)" or ""), 1, 1, 1)
		ns.TipLine(GameTooltip, junk and "Junk that didn't sell last time, with any other junk in your bags." or "Items you marked as junk in BagSmith.", 0.6, 0.6, 0.6, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:Hide()
	J.btn = b
	return b
end
-- What the vendor-window button will do: after junk that didn't sell, it sells all junk; otherwise marked items.
function J:ButtonTitle() return (J.retry and J.retryJunk) and "Sell Junk" or "Sell Marked Items" end
function J:UpdateSellButton()
	local b = J.btn
	if not merchantOpen() then if b then b:Hide() end return end
	local blz = _G.MerchantSellAllJunkButton
	local blzUsable = blz and blz:IsShown() and (not blz.IsEnabled or blz:IsEnabled()) and true or false
	local want = (#J:MarkedInBags() > 0 and (not blzUsable or J.needsClick)) or (J.retry and #J:JunkInBags() > 0)
	if not want then if b then b:Hide() end return end
	b = J:SellButton()
	if not b then return end
	if blz and blz.GetSize then local w, h = blz:GetSize(); if w and w > 0 then b:SetSize(w, h) end end
	b:ClearAllPoints()
	if blzUsable then
		b:SetPoint("LEFT", blz, "RIGHT", 4, 0)          -- beside Blizzard's (which still sells the greys)
	elseif blz and blz.GetNumPoints and blz:GetNumPoints() > 0 then
		for i = 1, blz:GetNumPoints() do b:SetPoint(blz:GetPoint(i)) end   -- in its place
	else
		b:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMLEFT", 170, 32)
	end
	b:SetFrameLevel(((blz and blz.GetFrameLevel and blz:GetFrameLevel()) or MerchantFrame:GetFrameLevel()) + 2)
	b:Show()
end

function J:Install()
	if J.installed then return end
	J.installed = true
	ns.Buttons.InstallTooltipHook()
	if C_MerchantFrame and type(C_MerchantFrame.SellAllJunkItems) == "function" then
		J.hooked = pcall(hooksecurefunc, C_MerchantFrame, "SellAllJunkItems", function() J:RemindBlizzardSale(); J:SellMarked(false) end)
	end
	ns:On("ADDON_ACTION_BLOCKED", function(addon) if addon == ADDON then J.blocked = J.blocked + 1 end end)
	local function later() C_Timer.After(0.2, function() J:UpdateSellButton() end) end
	ns:On("MERCHANT_SHOW", later)
	ns:On("MERCHANT_SHOW", function() C_Timer.After(0.3, function() J:AutoSell() end) end)
	ns:On("MERCHANT_UPDATE", later)
	ns:On("MERCHANT_CLOSED", function() J.visit = (J.visit or 0) + 1; J.needsClick = nil; J.autoBlocked = nil; J.retry = nil; J.retryJunk = nil; if J.btn then J.btn:Hide() end end)
	-- Turning automatic selling off, or a profile change, ends any pending automatic retry
	-- (never the check on a sale that was already sent).
	ns:OnSignal("SETTINGS_CHANGED", function(key) if key == nil or key == "autoSellJunk" then J.autoGen = (J.autoGen or 0) + 1 end end)
	ns:OnSignal("ITEMS_CHANGED", function() if merchantOpen() then J:UpdateSellButton() end end)
end
ns:OnSignal("ADDON_READY", function() J:Install() end)

------------------------------------------------------------------------
-- Keybinding: Mark as Junk (the game's Keybindings, BagSmith section; no default
-- key). Works on the item under the pointer in either view.
------------------------------------------------------------------------
function BagSmith_ToggleJunk()
	local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
	for _, f in ipairs(foci or {}) do
		local x = f
		for _ = 1, 3 do
			if not x then break end
			if x.rec and x.hasItem then J:Toggle(x.rec); return end
			x = x.GetParent and x:GetParent()
		end
	end
end
