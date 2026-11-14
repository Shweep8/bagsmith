--[[
	BagSmith - Frames/Scroll.lua
	Everything about scrolling a view's list, in one place. The rules:

	  1. A list ends at the bottom of its last row. Nothing may scroll past
	     it: not the player, not BagSmith's restores, not the game.
	  2. The scrollbar uses that same limit, so its thumb reaches the bottom.
	  3. Every move is labelled by who made it: "you" (wheel or scrollbar),
	     a BagSmith tag (restore, tidy-up, guard, limit, bar sync), or
	     "unknown" (the game).
	  4. Positions chosen by the player or BagSmith are trusted. A move made
	     by the game is undone, back to the trusted position, whenever the
	     pointer is over the list or its rows are holding still.
	  5. After a rebuild the trusted position is restored now and once more
	     on the next frame, because the game updates its own limit a frame
	     late when a list grows.

	With /bs debug on, every move (and every rebuild, in ViewList.lua) is
	logged with its source.
--]]

local ADDON, ns = ...
local View = ns.View

local function nearly(a, b) return math.abs(a - b) <= 0.5 end

-- How far the list may scroll: its last row's bottom on the list's bottom
-- edge, and never further than the game itself allows.
function View:ScrollRange()
	local sf = self.scroll
	local visible = sf and sf.GetHeight and sf:GetHeight() or 0
	local content = self.contentHeight or (self.child and self.child.GetHeight and self.child:GetHeight()) or 0
	local limit = math.max(0, content - visible)
	if sf and sf.GetVerticalScrollRange then
		local ok, gameLimit = pcall(sf.GetVerticalScrollRange, sf)
		if ok and type(gameLimit) == "number" then limit = math.min(limit, math.max(0, gameLimit)) end
	end
	return limit
end

-- Moves the list, labelled as BagSmith's own move.
function View:SetScrollTagged(value, tag)
	local sf = self.scroll
	if not (sf and sf.SetVerticalScroll) then return end
	self.scrollTag = tag
	sf:SetVerticalScroll(value)
	if sf.ScrollBar and sf.ScrollBar.SetValue then sf.ScrollBar:SetValue(value) end
	self.scrollTag = nil
end

-- Rule 2: the scrollbar's track ends where the list ends.
function View:SyncScrollBar()
	local bar = self.scroll and self.scroll.ScrollBar
	if not (bar and bar.SetMinMaxValues) then return end
	local limit = self:ScrollRange()
	local now = self.scroll.GetVerticalScroll and self.scroll:GetVerticalScroll() or 0
	local outerTag = self.scrollTag
	self.syncingBar = true
	self.scrollTag = outerTag or "bar sync"   -- anything this moves is BagSmith's, not the game's
	bar:SetMinMaxValues(0, limit)
	if bar.SetValue then bar:SetValue(math.min(now, limit)) end
	self.scrollTag = outerTag
	self.syncingBar = false
end

-- Rule 4: undo a move the game made.
function View:GuardScroll(offset, previous)
	local limit = self:ScrollRange()
	local protect = self.held or (self.frame.IsMouseOver and self.frame:IsMouseOver())
	local target = protect and math.min(self.trustedScroll or previous or 0, limit) or math.min(offset, limit)
	if nearly(offset, target) then return end
	self:SetScrollTagged(target, "guard")
	-- The game can step a jump over a frame or two; check once more, unless
	-- a newer guard or a scroll by the player came in meanwhile.
	self.guardToken = (self.guardToken or 0) + 1
	local token, startedAt = self.guardToken, GetTime()
	C_Timer.After(0, function()
		if token ~= self.guardToken or (self.userScrollAt or -10) >= startedAt then return end
		local now = self.scroll.GetVerticalScroll and self.scroll:GetVerticalScroll() or target
		if not nearly(now, target) and not self.userDragging then
			self:SetScrollTagged(math.min(target, self:ScrollRange()), "guard")
		end
	end)
end

-- The list's canvas (the scroll child) after the window's scale or size
-- changes. The client can keep a stale picture of a scroll frame's child
-- after a scale change and stop drawing it (seen in icon view: a blank list
-- until the view was switched, after changing Scale, and at the bank).
-- Re-attaching the child and nudging its size makes the client lay it out
-- again. That moves a parent of secure item buttons, so never in combat
-- (deferred until combat ends). /bs debug logs what it found.
function View:RefreshCanvas(why)
	local sf, child = self.scroll, self.child
	if not (sf and child and sf.SetScrollChild and self.frame:IsShown()) then return end
	ns:Safely("canvas" .. self.name, function()
		if not self.frame:IsShown() then return end
		-- (the log line can never stop the fix: it's shielded)
		if ns.db and ns.db.debug then pcall(function()
			local function rect(f)
				local ok, v = pcall(function() return f.IsRectValid and f:IsRectValid() end)
				return (ok and v == false) and "stale" or "ok"
			end
			local function n(v) return math.floor((v or 0) + 0.5) end
			local scale = self.frame.GetScale and self.frame:GetScale() or 1
			ns:Debug("%s canvas (%s): list area %dx%d %s, canvas %dx%d %s, scroll %d of %d, scale %.2f", self.name, why or "?",
				n(sf:GetWidth()), n(sf:GetHeight()), rect(sf), n(child:GetWidth()), n(child:GetHeight()), rect(child),
				n(sf:GetVerticalScroll()), n(self:ScrollRange()), scale)
		end) end
		local keep = sf.GetVerticalScroll and sf:GetVerticalScroll() or 0   -- (1.5.1-beta2) the list stays where it was
		sf:SetScrollChild(child)
		local w, h = child:GetWidth() or 1, child:GetHeight() or 1
		child:SetSize(w, h + 1); child:SetSize(w, h)
		if sf.UpdateScrollChildRect then sf:UpdateScrollChildRect() end
		local want = math.min(keep, self:ScrollRange())
		if sf.GetVerticalScroll and math.abs((sf:GetVerticalScroll() or 0) - want) > 0.5 then self:SetScrollTagged(want, "canvas") end
		self:ClampScroll(why)
	end)
end

-- (1.6.2-beta4, found with Shweep in game) After a /reload, the bags window could open in Icons view with its list area
-- unplaced: no size or position ("list area 0x0 stale" with /bs debug), so nothing drew and nothing took the pointer,
-- until the window was resized or the view switched. Placing the list area again and laying it out drew it at once when
-- done after the window had drawn; done the frame after opening (beta3) it didn't take. So a little after each opening,
-- while the list area is still unplaced, it's placed again and the list laid out: at most PLACE_CHECKS times an opening,
-- through ns:Safely (after combat when opened in combat). A placed list area costs a look and nothing more.
View.PLACE_CHECKS = { 0.1, 0.3, 0.8, 2 }
local function unplaced(sf)
	local ok, invalid = pcall(function() return sf.IsRectValid and not sf:IsRectValid() end)
	return (ok and invalid) or (sf:GetWidth() or 0) < 1
end
View.ListUnplaced = unplaced
function View:ScheduleListPlaced()
	if not (self.scroll and C_Timer and C_Timer.After) then return end
	self.placeToken = (self.placeToken or 0) + 1
	self.placeTries = 0
	local token = self.placeToken
	for i, delay in ipairs(View.PLACE_CHECKS) do
		C_Timer.After(delay, function() if self.placeToken == token then self:EnsureListPlaced(i) end end)
	end
end
function View:EnsureListPlaced(check)
	local sf = self.scroll
	if not (sf and self.frame:IsShown()) then return end
	if not unplaced(sf) then
		if (self.placeTries or 0) > 0 and not self.placeReported then
			self.placeReported = true
			ns:Debug("%s: list area placed (%dx%d) after %d tr%s", self.name, math.floor((sf:GetWidth() or 0) + 0.5),
				math.floor((sf:GetHeight() or 0) + 0.5), self.placeTries, self.placeTries == 1 and "y" or "ies")
		end
		return
	end
	ns:Safely("place" .. self.name, function()
		if not (self.frame:IsShown() and unplaced(sf)) then return end
		self.placeTries = (self.placeTries or 0) + 1
		self.placeReported = false
		ns:Debug("%s: list area unplaced (check %s): placing it again", self.name, tostring(check or "?"))
		self:PlaceScroll()
		ns:Guard("Refresh " .. (self.name or "window"), self.Refresh, self, true, "placed")
	end)
end

function View:ClampScroll(why)
	local sf = self.scroll
	if not (sf and sf.GetVerticalScroll) then return end
	local limit = self:ScrollRange()
	if self.trustedScroll and self.trustedScroll > limit then self.trustedScroll = limit end
	local now = sf:GetVerticalScroll() or 0
	if now > limit + 0.5 then
		ns:Debug("%s: scroll clamped %d -> %d (%s)", self.name, now, limit, why or "?")
		self:SetScrollTagged(limit, "limit")
	end
	if not self.syncingBar then self:SyncScrollBar() end
end

-- Called once per move, from the scroll frame's OnVerticalScroll.
function View:OnScrollMoved(offset)
	local previous = self.lastScroll
	local recentInput = self.userDragging or (GetTime() - (self.userScrollAt or -10)) < 0.3
	local source = self.scrollTag or (recentInput and "you") or "unknown"
	if not nearly(offset, previous or 0) then
		ns:Debug("%s scrolled %d -> %d (by %s)", self.name, previous or 0, offset, source)
	end
	self.lastScroll = offset

	if source == "unknown" then
		self:GuardScroll(offset, previous)          -- rule 4 (also enforces rule 1)
		return
	end
	local limit = self:ScrollRange()
	if offset > limit + 0.5 and source ~= "limit" then
		self:SetScrollTagged(limit, "limit")        -- rule 1
		return
	end
	if source ~= "guard" then self.trustedScroll = offset end   -- rule 4: trusted positions
	if not self.syncingBar then self:SyncScrollBar() end
end

-- Wraps one of our frames' handlers so the player's stamp is set before the handler moves the list.
function View:StampInputFirst(frame, script)
	if not (frame and frame.GetScript and frame.SetScript) then return end
	local orig = frame:GetScript(script)
	frame:SetScript(script, function(f, ...) self.userScrollAt = GetTime(); if orig then return orig(f, ...) end end)
end
-- Hooks the scroll frame once, when the view is built.
function View:SetupScroll(scroll, child)
	self.scroll, self.child = scroll, child
	-- The player's wheel and the scrollbar's buttons move the list inside the game's own handler, and the
	-- resulting OnVerticalScroll reaches OnScrollMoved before any post-hook runs; a post-hook stamp therefore
	-- came too late, the move looked like the game's, and rule 4 undid it (1.0.1). The stamp is set first,
	-- by wrapping those handlers on these frames of ours, then the original handler runs.
	self:StampInputFirst(scroll, "OnMouseWheel")
	local sb = scroll.ScrollBar
	if sb then
		sb:HookScript("OnMouseDown", function() self.userScrollAt = GetTime(); self.userDragging = true end)
		sb:HookScript("OnMouseUp", function() self.userDragging = false; self.userScrollAt = GetTime() end)
		for _, key in ipairs({ "Back", "Forward", "ScrollUpButton", "ScrollDownButton" }) do
			local btn = sb[key] or _G[(sb:GetName() or "") .. key]
			if btn then self:StampInputFirst(btn, "OnClick") end
		end
	end
	-- Rule 1 when the list area changes size (the window grows, Travel Mode
	-- switches off at the bank): never left scrolled past the end, and the
	-- trusted position shrinks with it so no guard puts it back.
	scroll:HookScript("OnSizeChanged", function()
		self:ClampScroll("resize")
		-- and the canvas, once the client has finished this layout pass
		ns:NextFrame("canvas:" .. self.name, function() self:RefreshCanvas("resize") end)
	end)
	scroll:HookScript("OnVerticalScroll", function(sf, offset)
		self:OnScrollMoved(offset or (sf.GetVerticalScroll and sf:GetVerticalScroll()) or 0)
	end)
	-- The template resets the bar's range whenever the game's range changes.
	scroll:HookScript("OnScrollRangeChanged", function() self:SyncScrollBar() end)
end

-- Rule 5: after a rebuild, back to the trusted position (clamped to the
-- new limit), now and again on the next frame.
function View:RestoreScroll(savedScroll, height, visible)
	local sf = self.scroll
	if not sf.SetVerticalScroll then return end
	if sf.UpdateScrollChildRect then sf:UpdateScrollChildRect() end
	local want = math.min(savedScroll, self:ScrollRange())
	local now = sf.GetVerticalScroll and sf:GetVerticalScroll() or 0
	if not nearly(now, want) then self:SetScrollTagged(want, self.refreshTag or "restore") end
	if savedScroll ~= want then
		ns:Debug("%s: scroll clamped %d -> %d (list height %d, visible %d)", self.name, savedScroll, want, height, visible)
	end
	-- Only the newest rebuild's second restore may run, never while rows are
	-- holding, and never after the player has scrolled.
	self.restoreToken = (self.restoreToken or 0) + 1
	local token, startedAt = self.restoreToken, GetTime()
	C_Timer.After(0, function()
		if token ~= self.restoreToken or self.held then return end
		if (self.userScrollAt or -10) >= startedAt or self.userDragging then return end
		local target = math.min(savedScroll, self:ScrollRange())
		if sf.GetVerticalScroll and not nearly(sf:GetVerticalScroll(), target) then
			self:SetScrollTagged(target, "restore (next frame)")
		end
	end)
end

-- Keep scroll-content textures from snapping independently during Modern resizing.
local contentSnapping = setmetatable({}, { __mode = "k" })
local function restoreContentSnapping()
	for texture, original in pairs(contentSnapping) do
		texture:SetSnapToPixelGrid(original.snap)
		texture:SetTexelSnappingBias(original.bias)
		contentSnapping[texture] = nil
	end
end
local function smoothContentTextures(frame)
	if frame.GetRegions then
		for _, texture in ipairs({ frame:GetRegions() }) do
			if texture.SetSnapToPixelGrid and texture.SetTexelSnappingBias
				and texture.IsSnappingToPixelGrid and texture.GetTexelSnappingBias then
				local snap, bias = texture:IsSnappingToPixelGrid(), texture:GetTexelSnappingBias()
				if not contentSnapping[texture] then contentSnapping[texture] = { snap = snap, bias = bias } end
				if snap then texture:SetSnapToPixelGrid(false) end
				if bias ~= 0 then texture:SetTexelSnappingBias(0) end
			end
		end
	end
	if frame.GetChildren then
		for _, child in ipairs({ frame:GetChildren() }) do smoothContentTextures(child) end
	end
end
ns:OnSignal("VIEW_LAYOUT", function(view)
	if not ns.db or ns.db.skin == "classic" then restoreContentSnapping(); return end
	if view.child then smoothContentTextures(view.child) end
end)
ns:OnSignal("SETTINGS_CHANGED", function(key)
	if (key == nil or key == "skin") and ns.db and ns.db.skin == "classic" then restoreContentSnapping() end
end)
