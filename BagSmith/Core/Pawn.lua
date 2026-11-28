--[[
	Core/Pawn.lua

	Pawn support. With the Pawn addon installed and its "Show bag upgrade
	advisor" option on, BagSmith shows Pawn's green upgrade arrow on the
	icons it draws for your own items (the bags window, Recent, bag windows,
	the bank window, the Loot Helper). Not on another character's saved bags:
	Pawn compares against the current character's gear.

	Pawn is asked per item, through pcall, the way Pawn's own notes for bag
	addons describe (see the comment above P:Present). Its upgrade check
	budgets its own time, so it can answer nil ("not yet"): the last known
	answer is kept and BagSmith asks again shortly.

	(1.12.0-beta1) A Pawn column for List view (Settings > Bag Columns, Bank
	Columns), off until ticked: how much of an upgrade Pawn says an item is.
	It reads the answers the arrows already have and asks nothing itself
	(see P:Amount and the column at the end of this file).
--]]
local ADDON, ns = ...
local P = {}
ns.Pawn = P

local ARROW_ATLAS = "bags-greenarrow"                          -- Blizzard's own upgrade arrow (what Pawn uses in the default bags)
local ARROW_FILE = "Interface\\AddOns\\Pawn\\Textures\\UpgradeArrow"   -- Pawn's, if the atlas is missing
local SIZE = 0.45                                              -- of the icon, like the junk coin

-- Pawn's own guidance for bag addons (PawnBags.lua): ask
-- PawnShouldItemLinkHaveUpgradeArrow(link, true) for each item; nil means
-- Pawn can't answer yet (it budgets its own time, so a burst of questions,
-- such as redrawing every row on a resize, gets nil for some), so check
-- back soon on a timer; and register with PawnRegisterThirdPartyBag to be
-- told when every arrow should be refreshed (settings or scales changed).
function P:Present() return type(_G.PawnShouldItemLinkHaveUpgradeArrow) == "function" end
-- Pawn's own switch for its bag arrows.
function P:AdvisorOn()
	local c = _G.PawnCommon
	if type(c) == "table" and c.ShowBagUpgradeAdvisor == false then return false end
	return true
end
function P:Active() return self:Present() and self:AdvisorOn() and _G.PawnIsInitialized ~= false end

-- Pawn's last yes/no per item link: a nil answer keeps it, so arrows don't
-- vanish while Pawn is busy. Cleared when gear or Pawn's settings change.
P.memory = {}
-- Re-check passes ask Pawn only about items still waiting for an answer.
-- Pawn budgets its own work (about 8 ms every quarter second), so asking
-- about everything each time spent the budget on items already answered
-- and starved the last ones (gear set sections at the bottom). Passes start
-- where the last one left off and never give up; they slow down instead.
local BACKOFF = { 0.25, 0.5, 1, 2, 4, 5 }   -- s between passes while items wait
P.amount = {}   -- (1.12.0-beta1) per link, for an upgrade: Pawn's number for it, or false when it gave none (P:Amount)
function P:Forget()
	P.memory = {}
	P.amount = {}
	P.level, P.lastUnknown = 1, nil
end

-- One pass over the items on screen. Items Pawn already answered keep that
-- answer (nothing is asked); the rest are asked, starting after the last
-- item asked in the previous pass, so no item is always last in line.
P.waiting = {}   -- links still waiting for an answer
function P:Pass()
	P.unknown, P.inPass, P.passWaiting = 0, true, {}
	local debug = ns.db and ns.db.debug
	local said = debug and {} or nil
	local list = {}
	ns.Buttons:EachLive(function(b) if b:IsShown() and b.hasItem and b.rec then list[#list + 1] = b end end)
	local n = #list
	local start = n > 0 and ((P.cursor or 0) % n) or 0
	for i = 1, n do
		local idx = ((start + i - 1) % n) + 1
		local b = list[idx]
		local waiting = b.rec.link and P.memory[b.rec.link] == nil
		P:Decorate(b, b.rec)
		if waiting then
			P.cursor = idx
			if said and #said < 8 then
				local a = P.memory[b.rec.link]
				said[#said + 1] = ("%s: %s"):format(b.rec.name or "?", a == true and "yes" or a == false and "no" or "not yet")
			end
		end
	end
	P.waiting = P.passWaiting
	if said and #said > 0 then ns:Debug("Pawn: asked %s", table.concat(said, ", ")) end
	-- (1.12.0-beta1) the Pawn column: rows on screen show answers that came in this pass, and a window sorted by the
	-- column sorts again. Only when something was answered, so a pass that learned nothing redraws nothing.
	if (P.answered or 0) ~= (P.answeredSeen or 0) then
		P.answeredSeen = P.answered
		if ns.Columns then ns.Columns:Changed("pawn") end
	end
	local mr = ns.MakeRoom
	if mr and mr.frame and mr.frame:IsShown() then mr:Paint() end
	-- (1.10.0-beta8) the Disenchant Helper's list, while it holds Pawn upgrades back, follows a changed answer
	local de = ns.Disenchant
	if de and de.PawnPass then de:PawnPass() end
	P.inPass = false
end
-- After a gear change Pawn may still answer from your old gear for a moment
-- (a firm "no" that wouldn't be asked again until the next redraw), so the
-- items on screen are asked again shortly after, whatever they said first.
P.GEAR_RECHECK = { 0.5, 1.5 }
function P:AfterGearChange()
	P:Forget()
	P:ScheduleRecheck(true)
	-- (each follow-up forgets again, so it asks fresh rather than keeping a
	-- "no" Pawn gave from the old gear)
	-- Like every other re-check, a follow-up that couldn't get every answer
	-- (Pawn rations its time) keeps checking.
	for _, delay in ipairs(P.GEAR_RECHECK) do
		C_Timer.NewTimer(delay, function()
			if not P:Present() then return end
			P:Forget(); P:Pass()
			if (P.unknown or 0) > 0 then P:ScheduleRecheck(true) end
		end)
	end
end
-- urgent: Pawn's refresh signal, a gear change or a newly shown item still
-- waiting: re-check within a quarter second, replacing a slower one pending.
function P:ScheduleRecheck(urgent)
	if urgent then
		P.level, P.lastUnknown = 1, nil
		P.recheckToken = (P.recheckToken or 0) + 1
		P.recheckPending = false
	end
	if P.recheckPending then return end
	P.recheckPending = true
	local token = P.recheckToken or 0
	local delay = BACKOFF[P.level or 1] or BACKOFF[#BACKOFF]
	C_Timer.After(delay, function()
		if token ~= (P.recheckToken or 0) then return end   -- replaced by a sooner one
		P.recheckPending = false
		P:Pass()
		local unknown = P.unknown or 0
		ns:Debug("Pawn: %d items not answered yet", unknown)
		if unknown == 0 then P.level, P.lastUnknown = 1, nil; return end
		-- Progress: keep the pace; none: slow down (never stop).
		if P.lastUnknown and unknown >= P.lastUnknown then P.level = math.min((P.level or 1) + 1, #BACKOFF) end
		P.lastUnknown = unknown
		P:ScheduleRecheck()
	end)
end

local function ask(link)
	if not link or not P:Active() then return nil, false end
	local ok, res = pcall(_G.PawnShouldItemLinkHaveUpgradeArrow, link, true)   -- true: check the player's level
	if not ok or res == nil then return nil, true end
	return res and true or false, false
end
-- Is this item an upgrade, per Pawn? true / false, or nil when Pawn can't say
-- yet and there's no earlier answer. (A remembered false stays false.)
function P:IsUpgrade(rec)
	if not rec or rec.empty or rec.cached or not rec.link or not self:Active() then return nil end
	return self:IsUpgradeLink(rec.link)
end
-- fresh: ask Pawn now, never a remembered answer (the Loot Helper, right
-- before destroying something).
function P:IsUpgradeLink(link, fresh)
	if not link or not self:Active() then return nil end
	-- Answered before: kept until gear, level or Pawn's settings change (Forget).
	local known = P.memory[link]
	if known ~= nil and not fresh then return known end
	local answer, pending = ask(link)
	if pending then
		P.unknown = (P.unknown or 0) + 1   -- (returns nil, true below: "not yet", not "no")
		if P.inPass then
			P.passWaiting[link] = true
		else
			-- Newly waiting: check soon, whatever the pace for items waiting all along.
			local new = not P.waiting[link]
			P.waiting[link] = true
			self:ScheduleRecheck(new)
		end
		return nil, true
	end
	if not fresh then P.waiting[link] = nil end
	-- (a fresh safety check answers only itself; what icons show stays as remembered)
	if answer ~= nil and not fresh then
		if P.memory[link] ~= answer then P.answered = (P.answered or 0) + 1 end   -- (1.12.0-beta1) for the column, see P:Pass
		P.memory[link] = answer
	end
	return answer
end

-- (1.12.0-beta1) How much of an upgrade, for an item Pawn has already called one. Two of Pawn's own functions, both
-- described in Pawn.lua for callers: PawnGetItemData(link) gives its record of the item, and
-- PawnIsItemAnUpgrade(item, true) a list with one entry per scale the item is an upgrade for, each with a
-- PercentUpgrade (0.15 is 15%); "true" asks it not to rescan the player's gear for this. The largest is kept. Pawn
-- uses a huge number (PawnBigUpgradeThreshold, 100) when there is nothing in the slot to compare with, and gives no
-- list at all for an item that is only a higher item level: both come back here as "an upgrade, no number".
-- Asked once per item until Pawn's answers are forgotten (gear, level or Pawn's settings changed). Nothing of
-- Pawn's is copied; a Pawn without these two functions gives no numbers and the column says Upgrade.
-- Returns: a number (0.15), or true for an upgrade without one.
function P:Amount(link)
	if not link then return nil end
	local known = P.amount[link]
	if known ~= nil then return known or true end
	local out = false
	if type(_G.PawnGetItemData) == "function" and type(_G.PawnIsItemAnUpgrade) == "function" then
		local ok, item = pcall(_G.PawnGetItemData, link)
		if ok and type(item) == "table" then
			local ok2, info = pcall(_G.PawnIsItemAnUpgrade, item, true)
			if ok2 and type(info) == "table" then
				local big = tonumber(_G.PawnBigUpgradeThreshold) or 100
				for _, u in ipairs(info) do
					local pct = type(u) == "table" and tonumber(u.PercentUpgrade) or nil
					if pct and pct == pct and pct > 0 and pct < big and (not out or pct > out) then out = pct end
				end
			end
		end
	end
	P.amount[link] = out
	return out or true
end
-- (1.12.0-beta2, Shweep: "Think a small green up arrow beside this would be good", "Yes in the cell") The arrow the
-- icons carry, as a picture inside the cell's text, sized by the text itself (size 0), so it follows Text Size: the
-- game's own art when the client has it, Pawn's file otherwise, the same choice P:SetArt makes for the icons.
function P:ArrowMarkup()
	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ARROW_ATLAS) then return "|A:" .. ARROW_ATLAS .. ":0:0|a" end
	return "|T" .. ARROW_FILE .. ":0|t"
end
-- The column's cell: the arrow and "+15%"; the arrow alone for an upgrade Pawn gives no number for (beta1 wrote
-- "Upgrade" there: the word and an arrow don't both fit); empty for anything that isn't an upgrade,
-- and nil ("not yet") while Pawn hasn't answered. It reads what the arrows already know (P.memory) and asks nothing:
-- every row that shows this cell is also decorated (P:Decorate), which does the asking, and a pass repaints the cell
-- when an answer comes in. Another character's saved items get nothing, as with the arrows.
function P:ColumnText(rec)
	if not rec or rec.empty or rec.cached or not rec.link or not self:Active() then return "" end
	local up = P.memory[rec.link]
	if up == nil then return nil end
	if not up then return "" end
	local amount = self:Amount(rec.link)
	if type(amount) == "number" then return ("%s +%d%%"):format(self:ArrowMarkup(), math.max(1, math.floor(amount * 100 + 0.5))) end
	return self:ArrowMarkup()
end
-- Sorting by the column: bigger upgrades first, then upgrades without a number, then everything else.
function P:ColumnSort(rec)
	if not rec or rec.empty or rec.cached or not rec.link or not self:Active() then return 0 end
	if not P.memory[rec.link] then return 0 end
	local amount = self:Amount(rec.link)
	if type(amount) == "number" then return 1 + amount end
	return 1
end

-- Registering with Pawn makes Pawn skip its own arrows on Blizzard's bags,
-- so BagSmith registers only while it stands in for them, and unregisters
-- when that's turned off (Pawn's arrows on Blizzard's bags come back).
function P:Register()
	local want = ns.db and ns.db.replaceBlizzardBags and true or false
	if want and not P.registered and type(_G.PawnRegisterThirdPartyBag) == "function" then
		local ok = pcall(_G.PawnRegisterThirdPartyBag, "BagSmith", { RefreshAll = function() P:OnPawnRefresh("registered") end })
		P.registered = ok and true or false
	elseif not want and P.registered and type(_G.PawnUnregisterThirdPartyBag) == "function" then
		pcall(_G.PawnUnregisterThirdPartyBag, "BagSmith")
		P.registered = false
	end
end

-- Pawn refreshed its bag arrows (scales or settings changed, gear
-- re-checked, its advisor toggled): forget every answer and repaint soon.
-- With the advisor off, the repaint hides the arrows.
function P:OnPawnRefresh(how)
	ns:Debug("Pawn: refresh from Pawn (%s; answers cleared)", how or "?")
	P:Forget()
	P:ScheduleRecheck(true)
end
-- Pawn calls PawnBags:RefreshAll() on every reset (PawnResetBags) and when
-- its advisor is toggled; registered bag addons only hear the first, and
-- only while registered (BagSmith registers only while it replaces
-- Blizzard's bags). Hooking it hears both, in either bag mode.
function P:HookPawn()
	if P.hooked then return end
	local pb = _G.PawnBags
	if type(pb) == "table" and type(pb.RefreshAll) == "function" then
		hooksecurefunc(pb, "RefreshAll", function() P:OnPawnRefresh("Pawn's bags") end)
		P.hooked = "PawnBags:RefreshAll"
	elseif type(_G.PawnResetBags) == "function" then
		hooksecurefunc("PawnResetBags", function() P:OnPawnRefresh("Pawn's reset") end)
		P.hooked = "PawnResetBags"
	end
end

function P:SetArt(tex)
	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ARROW_ATLAS) then tex:SetAtlas(ARROW_ATLAS); P.art = "atlas " .. ARROW_ATLAS
	else tex:SetTexture(ARROW_FILE); P.art = "Pawn's arrow texture" end
end

-- On an item button: the arrow in Blizzard's corner (top-left), sized with
-- the icon; if the junk coin is there too, the arrow takes the top-right.
function P:Decorate(b, rec)
	local up, pending
	if rec then up, pending = self:IsUpgrade(rec) end
	-- Pawn hasn't answered yet ("not yet", not "no"): the same item keeps what
	-- it showed, so arrows don't blink while Pawn works; a button now showing
	-- a different item starts without one.
	if up == nil and pending and rec.link and b.pawnLink == rec.link then up = b.pawnUp end
	up = up and true or false
	-- /bs debug: an arrow appearing or going on the same item.
	if rec and rec.link and b.pawnLink == rec.link and (b.pawnUp or false) ~= (up and true or false) and ns.db and ns.db.debug then
		ns:Debug("Pawn: arrow %s on %s", up and "shown" or "hidden", rec.name or "?")
	end
	b.pawnLink, b.pawnUp = rec and rec.link, up and true or false
	if up and not b.pawnArrow then
		b.pawnArrow = b:CreateTexture(nil, "OVERLAY", nil, 6)
		self:SetArt(b.pawnArrow)
	end
	if not b.pawnArrow then return P:AfterDecorate(b) end
	b.pawnArrow:SetShown(up)
	if not up then return P:AfterDecorate(b) end
	local icon = b.icon
	local w = icon and icon:GetWidth() or 24
	local s = math.max(10, math.floor((w > 0 and w or 24) * SIZE + 0.5))
	b.pawnArrow:SetSize(s, s)
	b.pawnArrow:ClearAllPoints()
	-- Bottom-left (1.1.0): the junk coin has the top-left, the item level the top-right, the count the
	-- bottom-right and the new-item dot the bottom center. The multi-set shield also uses the bottom-left
	-- (15 px in cells, 12 in rows, at -2,-2 with its count to the right): when it shows, the arrow sits
	-- directly on the shield's top edge, and it shrinks to the room there is above the shield, so it never
	-- overlaps the shield and never leaves its cell or its row (a list row's icon is centered in the row,
	-- so the row's margin above the icon counts). Compact rows get a smaller arrow rather than one that
	-- spills into the row above.
	-- (1.5.0) the icon corners give a corner to one mark at a time, in both views: no stacking above the shield
	local shield = false
	if shield then
		local shieldTop = (b.linkMark:GetHeight() or 15) - 2
		local h = (icon and icon:GetHeight()) or w
		if not h or h <= 0 then h = w end
		local limit = h
		if b.mode == "row" then
			local rowH = b.GetHeight and b:GetHeight() or h
			if rowH and rowH > h then limit = h + (rowH - h) / 2 end
		end
		local avail = math.floor(limit - shieldTop)
		if avail < s then s = math.max(6, avail) end
		b.pawnArrow:SetSize(s, s)
		b.pawnArrow:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 1, shieldTop)
	else
		b.pawnArrow:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 1, 1)
	end
	P:AfterDecorate(b)
end
-- (1.5.0) when Pawn answers later (not during a fill), the icon corners decide again what shows where
function P:AfterDecorate(b)
	if ns.Corners and not b.inFill and (b.mode == "cell" or b.mode == "row") then ns.Corners:Apply(b) end
end
-- On a plain icon texture (the Loot Helper's rows).
function P:DecorateIcon(holder, icon, up)
	if up and not holder.pawnArrow then
		holder.pawnArrow = holder:CreateTexture(nil, "OVERLAY", nil, 6)
		self:SetArt(holder.pawnArrow)
	end
	if not holder.pawnArrow then return end
	holder.pawnArrow:SetShown(up and true or false)
	if up then
		local w = icon:GetWidth() or 18
		local s = math.max(8, math.floor((w > 0 and w or 18) * 0.6 + 0.5))
		holder.pawnArrow:SetSize(s, s)
		holder.pawnArrow:ClearAllPoints(); holder.pawnArrow:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
	end
end
function P:AddTooltipLines() end   -- Pawn adds its own

-- (1.12.0-beta1) The Pawn column. Listed in Bag Columns and Bank Columns whether or not Pawn is installed (greyed
-- without it, as AH Price is without a price addon), and unticked until the player ticks it.
-- (1.12.0-beta2, Shweep on beta1's sentence: "This is far too long.."; his pick of three)
P.COLUMN_TIP = "Pawn's upgrade amount."
if ns.Columns then
	ns.Columns:Register("pawn", {
		label = "Pawn", owner = "Pawn", width = 64, numeric = true,   -- (beta2: 58 before the arrow; room for the arrow and "+250%")
		color = { 0.1, 1, 0.1 },   -- the game's green, as Pawn's own upgrade lines are
		text = function(rec) return P:ColumnText(rec) end,
		sort = function(rec) return P:ColumnSort(rec) end,
		available = function()
			if not P:Present() then return false, "Shows when Pawn is installed." end
			if not P:Active() then return false, "Pawn's bag upgrade advisor is off, so there is nothing to show. You can turn it on in Pawn's options." end
			return true
		end,
		tip = P.COLUMN_TIP,
	})
end

ns:OnSignal("ADDON_READY", function()
	-- Gear changes change what's an upgrade.
	ns:On("PLAYER_EQUIPMENT_CHANGED", function() if P:Present() then P:AfterGearChange(); ns:RefreshViews(true) end end)
	ns:On("EQUIPMENT_SWAP_FINISHED", function() if P:Present() then P:AfterGearChange() end end)
	-- A new level can make items usable (and upgrades) that weren't.
	ns:On("PLAYER_LEVEL_UP", function() if P:Present() then P:AfterGearChange(); ns:RefreshViews(true) end end)
	-- Pawn is an optional dependency, so it normally loads first; if not, register when it does.
	P:Register(); P:HookPawn()
	ns:On("ADDON_LOADED", function(name) if name == "Pawn" then P:Register(); P:HookPawn() end end)
	ns:On("PLAYER_LOGIN", function() P:Register(); P:HookPawn() end)
	ns:OnSignal("SETTINGS_CHANGED", function(key) if key == nil or key == "replaceBlizzardBags" then P:Register() end end)
end)
