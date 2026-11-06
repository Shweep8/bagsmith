--[[
	BagSmith - Frames/Classic.lua
	The Classic skin, built from Blizzard's own frame art as Forever draws its
	bags: bronze border, slate background, a round portrait over the top-left
	corner (BagSmith's full-color icon), a dark title strip with gold text,
	the red close button, red panel buttons and tabs, a recessed bar for gold,
	and the classic scrollbar with its arrows.

	Nothing is copied into the addon: every piece is drawn from the game's own
	files by template, path or atlas. Each piece is created once, on the first
	switch to Classic, then only shown or hidden, so switching skins is live
	and creates no new frames. If the client lacks a piece, that piece keeps
	its Modern look and /bs skincheck says so.

	Covers the bags and bank windows, Settings, the Filter panel, the
	currency drawer, the confirm dialog and the small bag windows.
--]]

local ADDON, ns = ...
local Classic = {}
ns.Classic = Classic

local ICON = "Interface\\AddOns\\BagSmith\\Media\\icon.tga"

-- What loaded, for /bs skincheck.
Classic.status = {}
local function note(piece, ok) if Classic.status[piece] == nil or ok then Classic.status[piece] = ok and true or false end end

local function tryFrame(kind, parent, template, piece)
	local ok, f = pcall(CreateFrame, kind, nil, parent, template)
	note(piece or template, ok and f ~= nil)
	return ok and f or nil
end

-- Modern's own colors, painted again after Classic turns off. Guarded so a
-- window's skin callback that switches Classic off can't loop back here.
local repainting = {}
local function repaint(frame)
	if repainting[frame] then return end
	repainting[frame] = true
	ns.Skins:RefreshWithin(frame)
	repainting[frame] = nil
end

-- Blizzard's red close button, placed where the template puts its own: in
-- the frame's top-right corner, inside the border. Every Classic window uses
-- this, so none can hang off the edge. Returns where the spot came from.
-- The template's own anchor sits a hair high on Forever: nudged down.
local CLOSE_NUDGE = -0.5
local CLOSE_NUDGE_X = -0.5   -- (1.1.0: the X sat half a pixel right of the frame's corner)
Classic.CLOSE_NUDGE_X = CLOSE_NUDGE_X
local function placeClose(close, chrome, frame)
	close:ClearAllPoints()
	local blizz = chrome and chrome.CloseButton
	local point, rel, relPoint, x, y
	if blizz and blizz.GetPoint then point, rel, relPoint, x, y = blizz:GetPoint(1) end
	if point then
		close:SetPoint(point, rel or chrome, relPoint or point, (x or 0) + CLOSE_NUDGE_X, (y or 0) + CLOSE_NUDGE)
		return ("template, nudged %s px (x %s)"):format(tostring(CLOSE_NUDGE), tostring(CLOSE_NUDGE_X))
	end
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
	return "fallback"
end
Classic.closeFrom = {}
Classic.PlaceClose = placeClose
Classic.CLOSE_NUDGE = CLOSE_NUDGE


local function atlasExists(name)
	return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- Blizzard's bottom tabs, by whichever name this client uses.
local tabTemplate
function Classic.TabTemplate()
	if tabTemplate ~= nil then return tabTemplate or nil end
	for _, name in ipairs({ "PanelTabButtonTemplate", "CharacterFrameTabButtonTemplate" }) do
		local ok, f = pcall(CreateFrame, "Button", nil, UIParent, name)
		if ok and f then f:Hide(); tabTemplate = name; note("Bottom tabs (" .. name .. ")", true); return name end
	end
	tabTemplate = false
	note("Bottom tabs", false)
	return nil
end

-- (1.5.0-beta6) The game's bottom-tab art, fitted to BagSmith's tabs. The template's end pieces keep a fixed height
-- of their own, taller than BagSmith's tabs, so their lower part hung below the tab as a dark strip (most visible on
-- narrow tabs, which are mostly end pieces). Each piece taller than the tab is cropped to the tab's height: the
-- part of its art that showed inside the tab stays exactly as it was. Done again whenever the tab's height changes.
-- (1.5.0-beta7) Only the normal tab's pieces (and their hover highlight) are cropped. The selected tab's pieces
-- (the template's "Active" ones, or "Disabled" in the older template, where the selected tab is the disabled one)
-- are deliberately taller: their lower part is the gold trim that joins the selected tab to the window, so they keep
-- their full height.
local function selectedPiece(art, r)
	for k, v in pairs(art) do
		if v == r and type(k) == "string" and (k:find("Active") or k:find("Disabled") or k:find("Selected")) then return true end
	end
	return false
end
local function texturesOf(art)
	local out = {}
	if not (art and art.GetRegions) then return out end
	for _, r in ipairs({ art:GetRegions() }) do
		if r and r.SetTexCoord and r.GetHeight and (not r.GetObjectType or r:GetObjectType() == "Texture") and not selectedPiece(art, r) then out[#out + 1] = r end
	end
	return out
end
function Classic.FitTabArt(btn)
	local art = btn and btn.classic
	if not (art and art.isTab) then return end
	local h = btn.GetHeight and btn:GetHeight() or 0
	if h <= 0 then return end
	for _, r in ipairs(texturesOf(art)) do
		-- the piece's own size and art, recorded once (before any crop) so refits never compound
		if not r.bsTabFit then
			local coords = r.GetTexCoord and { r:GetTexCoord() } or nil
			r.bsTabFit = { h = r:GetHeight() or 0, coords = (coords and #coords >= 8) and coords or nil }
		end
		local f = r.bsTabFit
		if f.h > h + 0.5 then
			r:SetHeight(h)
			if f.coords then
				local c = f.coords
				local top, bottom = c[2], c[4]   -- upper-left y, lower-left y
				local cut = top + (bottom - top) * (h / f.h)
				r:SetTexCoord(c[1], c[5], top, cut)
			end
		elseif f.h > 0 and (r:GetHeight() or 0) ~= f.h then
			r:SetHeight(f.h)
			if f.coords then local c = f.coords; r:SetTexCoord(c[1], c[5], c[2], c[4]) end
		end
	end
end
-- /bs debug: hovering a tab lists any piece of its art that reaches below the tab.
function Classic.TabArtReport(btn)
	if not (ns.db and ns.db.debug and ns.Debug and btn and btn.classic and btn.classic.isTab) then return end
	local h = btn:GetHeight() or 0
	local out = {}
	for _, r in ipairs(texturesOf(btn.classic)) do
		if r.IsShown and r:IsShown() and (r:GetHeight() or 0) > h + 0.5 then
			out[#out + 1] = ("%s %dx%d"):format((r.GetDebugName and r:GetDebugName()) or "piece", math.floor((r:GetWidth() or 0) + 0.5), math.floor((r:GetHeight() or 0) + 0.5))
		end
	end
	ns:Debug("Tab %q (%d px tall): %s", btn.label and btn.label.GetText and (btn.label:GetText() or "") or "?", math.floor(h + 0.5),
		#out > 0 and ("art reaching below the tab: " .. table.concat(out, ", ")) or "all its art fits inside the tab")
end

-- The highest frame layer used anywhere in a frame's children.
function Classic.TopLevel(frame, depth)
	depth = depth or 0
	local top = frame.GetFrameLevel and frame:GetFrameLevel() or 0
	if depth < 3 and frame.GetChildren then
		for _, child in ipairs({ frame:GetChildren() }) do top = math.max(top, Classic.TopLevel(child, depth + 1)) end
	end
	return top
end

-- Recording the Modern layout the first time Classic turns on, so leaving
-- Classic puts back exactly what was there (not values retyped by hand).
local function grab(f)
	if not f then return nil end
	local s = { h = f.GetHeight and f:GetHeight(), w = f.GetWidth and f:GetWidth(), shown = f.IsShown and f:IsShown(), points = {} }
	local n = f.GetNumPoints and f:GetNumPoints() or 0
	for i = 1, n do s.points[i] = { f:GetPoint(i) } end
	return s
end
local function put(f, s, size)
	if not (f and s) then return end
	f:ClearAllPoints()
	for _, p in ipairs(s.points) do f:SetPoint(unpack(p)) end
	if size == "both" then f:SetSize(s.w, s.h) elseif size == "height" then f:SetHeight(s.h) end
end
local function record(view)
	local snap = {
		title = grab(view.title), subText = grab(view.subText), tabs = grab(view.tabs), scroll = grab(view.scroll),
		bar = grab(view.scroll and view.scroll.ScrollBar), btnSort = grab(view.btnSort), btnMerge = grab(view.btnMerge),
		segs = {}, boxes = {}, items = {},
	}
	for i, b in ipairs(view.segButtons or {}) do snap.segs[i] = grab(b); snap.segs[i].divider = b.divider and b.divider:IsShown() end
	for i, box in ipairs(view.segBoxes or {}) do snap.boxes[i] = grab(box) end
	for i, item in ipairs(view.toolItems or {}) do snap.items[i] = item.width end
	return snap
end
local function restore(view, snap)
	put(view.title, snap.title, "height")
	put(view.subText, snap.subText)
	put(view.tabs, snap.tabs)
	put(view.scroll, snap.scroll)
	put(view.scroll and view.scroll.ScrollBar, snap.bar)
	put(view.btnSort, snap.btnSort, "height")
	put(view.btnMerge, snap.btnMerge, "height")
	for i, b in ipairs(view.segButtons or {}) do
		local s = snap.segs[i]
		if s then put(b, s, "both"); if b.divider then b.divider:SetShown(s.divider and true or false) end end   -- (beta8: Classic widens some)
	end
	for i, box in ipairs(view.segBoxes or {}) do put(box, snap.boxes[i], "both") end
	for i, item in ipairs(view.toolItems or {}) do if snap.items[i] then item.width = snap.items[i] end end
	if view.LayoutTools then view:LayoutTools() end
end

------------------------------------------------------------------------
-- Building the pieces (once per window)
------------------------------------------------------------------------
local BAR_FILL = { 0.035, 0.03, 0.025, 0.55 }   -- a little darker than the stone, even all over
local BAR_EDGE = { 0.45, 0.36, 0.22, 0.85 }     -- muted bronze, like the frame's trim
local function buildChrome(view)
	local f = view.frame
	local chrome = tryFrame("Frame", f, "PortraitFrameTemplate", "Window frame (PortraitFrameTemplate)")
	if not chrome then return nil end
	chrome:SetAllPoints(f)
	chrome:SetFrameLevel(f:GetFrameLevel())   -- behind everything BagSmith draws
	chrome:EnableMouse(false)

	-- Portrait: BagSmith's full-color icon, cropped round like Blizzard's.
	local portrait = (chrome.PortraitContainer and chrome.PortraitContainer.portrait) or chrome.portrait
	if not portrait then
		portrait = chrome:CreateTexture(nil, "OVERLAY")
		portrait:SetSize(58, 58)
		portrait:SetPoint("TOPLEFT", -5, 7)
	end
	-- The game won't crop an addon's icon with SetPortraitToTexture, so set
	-- the icon and clip it with Blizzard's round portrait mask instead.
	portrait:SetTexture(ICON)
	portrait:SetTexCoord(0.12, 0.88, 0.12, 0.88)   -- zoom past the icon's own square frame
	local masked = false
	if chrome.CreateMaskTexture and portrait.AddMaskTexture then
		local mask = chrome:CreateMaskTexture()
		mask:SetAllPoints(portrait)
		local ok = pcall(mask.SetTexture, mask, "Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		if ok then portrait:AddMaskTexture(mask); masked = true end
	end
	note("Round portrait", masked)
	view.classicPortrait = portrait

	Classic.Background(view, chrome, view.footer)

	-- Title in the strip.
	local title = (chrome.TitleContainer and chrome.TitleContainer.TitleText) or chrome.TitleText
	if not title then
		title = chrome:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOP", 0, -5)
	end
	view.classicTitle = title

	-- Blizzard's close button. The template's own one didn't show on Forever,
	-- so BagSmith adds one on the window itself, above its drag band.
	local blizzClose = chrome.CloseButton
	local close = tryFrame("Button", f, "UIPanelCloseButton", "Close button")
	if close then
		Classic.closeFrom[view.opts.title or "window"] = placeClose(close, chrome, f)
		-- Blizzard's border pieces sit on a high layer; go above all of them.
		close:SetFrameLevel(math.max(view.dragArea:GetFrameLevel(), Classic.TopLevel(chrome)) + 10)
		close:SetScript("OnClick", function()
			local fn = view.closeBtn:GetScript("OnClick")
			if fn then fn(view.closeBtn) end
		end)
	end
	if blizzClose then blizzClose:Hide() end
	view.classicClose = close
	note("Close button", close ~= nil)

	-- The bar behind the gold: one flat tone with a thin border, no shadow.
	-- Drawn on the frame art's own background layer (above the stone, below
	-- the footer's text), so nothing can cover it or draw under it by chance.
	-- Blizzard's inset template was used before; its edges carry a baked-in
	-- shadow, and its fill was covered by the background.
	local bar = { fill = chrome:CreateTexture(nil, "BACKGROUND", nil, 5) }
	bar.fill:SetPoint("TOPLEFT", view.footer, "TOPLEFT", -4, 1)
	bar.fill:SetPoint("BOTTOMRIGHT", view.footer, "BOTTOMRIGHT", 4, -2)
	bar.fill:SetColorTexture(BAR_FILL[1], BAR_FILL[2], BAR_FILL[3], BAR_FILL[4])
	local function edge(p1, p2, horizontal)
		local t = chrome:CreateTexture(nil, "BACKGROUND", nil, 6)
		t:SetPoint(p1, bar.fill, p1); t:SetPoint(p2, bar.fill, p2)
		if horizontal then t:SetHeight(1) else t:SetWidth(1) end
		t:SetColorTexture(BAR_EDGE[1], BAR_EDGE[2], BAR_EDGE[3], BAR_EDGE[4])
		return t
	end
	bar.top = edge("TOPLEFT", "TOPRIGHT", true); bar.bottom = edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
	bar.left = edge("TOPLEFT", "BOTTOMLEFT"); bar.right = edge("TOPRIGHT", "BOTTOMRIGHT")
	view.classicBar = bar
	note("Gold bar (flat, on the background layer)", true)

	return chrome
end

------------------------------------------------------------------------
-- Square buttons (Bank, Currencies, Settings, back-to-own-bags), dropdown
-- art for the character picker, and the Appearances background
------------------------------------------------------------------------
-- (1.4.2) The hover is the soft glow Blizzard's own square buttons use; the square-button highlight file, stretched
-- over the whole button, showed as a flat box larger than the art.
local SQUARE_UP, SQUARE_DOWN, SQUARE_HL = "Interface\\Buttons\\UI-SquareButton-Up", "Interface\\Buttons\\UI-SquareButton-Down", "Interface\\Buttons\\UI-Common-MouseHilight"
local SQUARE_HL_INSET = 3   -- the art's transparent margin at 26 px: the glow stays inside the frame
local WHITE = "Interface\\Buttons\\WHITE8X8"
local GOLD = { 1, 0.82, 0 }

local function squareButton(b, on)
	if not b then return end
	if on and b.squareBg == nil then
		local bg = b:CreateTexture(nil, "BACKGROUND")
		local ok = bg:SetTexture(SQUARE_UP)
		if ok == false then bg:Hide(); b.squareBg = false; note("Square buttons", false); return end
		note("Square buttons", true)
		bg:SetAllPoints(b)
		b.squareBg = bg
		b.modernSize = { b:GetWidth(), b:GetHeight() }
		b.modernTex = { b.tex:GetWidth(), b.tex:GetHeight() }
		b:HookScript("OnMouseDown", function(s) if s.squareOn then s.squareBg:SetTexture(SQUARE_DOWN) end end)
		-- Released: back to its state (pushed in while on).
		b:HookScript("OnMouseUp", function(s) if s.squareOn then s.squareBg:SetTexture(s.active and SQUARE_DOWN or SQUARE_UP) end end)
		-- Same states as the Travel Mode button: on = pushed in with a white
		-- icon, off = raised with a gold one. (Our own button: safe to wrap.)
		local baseSetActive = b.SetActive
		b.SetActive = function(s, active)
			baseSetActive(s, active)
			if s.squareOn then
				s.squareBg:SetTexture(active and SQUARE_DOWN or SQUARE_UP)
				if active then s.tex:SetVertexColor(1, 1, 1) else s.tex:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]) end
			end
		end
	end
	if not b.squareBg then return end
	b.squareOn = on
	b.squareBg:SetShown(on)
	if on then
		b:SetSize(26, 26); b.tex:SetSize(14, 14)
		b:SetHighlightTexture(SQUARE_HL, "ADD")
		local hl = b:GetHighlightTexture()
		if hl then
			hl:ClearAllPoints(); hl:SetPoint("TOPLEFT", SQUARE_HL_INSET, -SQUARE_HL_INSET); hl:SetPoint("BOTTOMRIGHT", -SQUARE_HL_INSET, SQUARE_HL_INSET)
			if hl.SetVertexColor then hl:SetVertexColor(1, 1, 1, 1) end
		end
		b.restColor = GOLD
	else
		b:SetSize(b.modernSize[1], b.modernSize[2]); b.tex:SetSize(b.modernTex[1], b.modernTex[2])
		b:SetHighlightTexture(WHITE)
		b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
		b:GetHighlightTexture():ClearAllPoints(); b:GetHighlightTexture():SetAllPoints(b)   -- (1.4.2) Modern's flat hover, the full button
		b.restColor = nil
	end
	b:SetActive(b.active)
end

-- A red button to match Blizzard's red close button, for the Travel Mode
-- signpost. The close button's art has its X drawn in, so, in order:
--  1. a blank face from the same red button set, if this client has one;
--  2. the map's maximize/minimize button art (same set: same rim, face and
--     pressed look as the X), with its arrow covered by a patch cut from a
--     plain part of the same art's red face;
--  3. Blizzard's red panel button art cut to a square, inside a dark bronze
--     rim like the close button's.
-- Art names are guesses until tested; /bs skincheck says which was used. The
-- signpost sits on top in gold, the same size as the close button's face.
local RED_BLANK = { { "RedButton-Blank", "RedButton-Blank-Pressed" }, { "128-RedButton-Blank", "128-RedButton-Blank-Pressed" },
	{ "RedButton-Empty", "RedButton-Empty-Pressed" }, { "common-button-square-red-up", "common-button-square-red-down" } }
local RED_FAMILY = { { "RedButton-Expand", "RedButton-Expand-Pressed" }, { "RedButton-Condense", "RedButton-Condense-Pressed" },
	{ "128-RedButton-Expand", "128-RedButton-Expand-Pressed" } }
local PANEL_UP, PANEL_DOWN = "Interface\\Buttons\\UI-Panel-Button-Up", "Interface\\Buttons\\UI-Panel-Button-Down"
-- The close button's red face sits a little above the middle of its frame
-- (transparent padding), so the signpost is raised to line up with the face.
local TRAVEL_LIFT = 0
local TRAVEL_SIZE = 24                  -- the close button's red face
local PATCH_INSET = 0.22                -- the rim's share of each side (the patch covers what's inside)
local PATCH_FROM = { 0.24, 0.40 }       -- the plain part of the face the patch is cut from (top-left, clear of the arrow)
local RIM = { 0.24, 0.16, 0.08 }        -- dark bronze, like the close button's rim
Classic.TRAVEL_LIFT, Classic.TRAVEL_SIZE = TRAVEL_LIFT, TRAVEL_SIZE

local function atlasRegion(name)
	local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)
	if not info then return nil end
	local file = info.file or info.filename
	local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
	if not (file and l and r and t and b) then return nil end
	return file, l, r, t, b
end

local function redButton(b, on, size)
	if not b then return end
	size = size or TRAVEL_SIZE
	if on and b.redArt == nil then
		local art = { pieces = {} }
		for _, names in ipairs(RED_BLANK) do
			if atlasExists(names[1]) then art.atlas, art.atlasDown = names[1], atlasExists(names[2]) and names[2] or names[1]; break end
		end
		if art.atlas then
			local t = b:CreateTexture(nil, "BACKGROUND"); t:SetAllPoints(b); t:SetAtlas(art.atlas)
			art.pieces[1] = t
			note("Travel Mode button: blank red button art (" .. art.atlas .. ")", true)
		else
			for _, names in ipairs(RED_FAMILY) do
				local file, l, r, t, bt = atlasRegion(names[1])
				if file then art.atlas, art.atlasDown = names[1], atlasExists(names[2]) and names[2] or names[1]; art.patchFile, art.patchCoords = file, { l, r, t, bt }; break end
			end
			if art.atlas then
				local face = b:CreateTexture(nil, "BACKGROUND"); face:SetAllPoints(b); face:SetAtlas(art.atlas)
				local patch = b:CreateTexture(nil, "BACKGROUND", nil, 1)
				local l, r, t, bt = unpack(art.patchCoords)
				local function at(lo, hi, f) return lo + (hi - lo) * f end
				patch:SetTexture(art.patchFile)
				patch:SetTexCoord(at(l, r, PATCH_FROM[1]), at(l, r, PATCH_FROM[2]), at(t, bt, PATCH_FROM[1]), at(t, bt, PATCH_FROM[2]))
				art.pieces[1], art.pieces[2], art.patch = face, patch, patch
				note("Travel Mode button: the map button's red art (" .. art.atlas .. ") with its arrow covered", true)
			else
				-- The panel button's left and right ends make a small square, inside a bronze rim.
				local rim = b:CreateTexture(nil, "BACKGROUND", nil, -1); rim:SetColorTexture(RIM[1], RIM[2], RIM[3], 1)
				rim:SetPoint("TOPLEFT", -2, 2); rim:SetPoint("BOTTOMRIGHT", 2, -2)
				local lt = b:CreateTexture(nil, "BACKGROUND"); lt:SetTexture(PANEL_UP)
				lt:SetPoint("TOPLEFT"); lt:SetPoint("BOTTOMRIGHT", b, "BOTTOM"); lt:SetTexCoord(0, 0.09375, 0, 0.6875)
				local rt = b:CreateTexture(nil, "BACKGROUND"); rt:SetTexture(PANEL_UP)
				rt:SetPoint("TOPRIGHT"); rt:SetPoint("BOTTOMLEFT", b, "BOTTOM"); rt:SetTexCoord(0.53125, 0.625, 0, 0.6875)
				art.pieces[1], art.pieces[2], art.pieces[3], art.panel = rim, lt, rt, true
				note("Travel Mode button: red panel button art in a bronze rim (no red button art found)", true)
			end
		end
		b.redArt = art
		b.modernSize = b.modernSize or { b:GetWidth(), b:GetHeight() }
		b.modernTex = b.modernTex or { b.tex:GetWidth(), b.tex:GetHeight() }
		local function press(s, down)
			local a = s.redArt
			if not (a and s.redOn) then return end
			if a.atlas then a.pieces[1]:SetAtlas(down and a.atlasDown or a.atlas)
			else for i = 2, 3 do a.pieces[i]:SetTexture(down and PANEL_DOWN or PANEL_UP) end end
		end
		b.redPress = press
		b:HookScript("OnMouseDown", function(s) press(s, true) end)
		-- Released: back to the state it's in (pushed in while on).
		b:HookScript("OnMouseUp", function(s) press(s, s.active and true or false) end)
		-- On: pushed in, white signpost. Off: raised, gold signpost. (Our own
		-- button, so wrapping its method is safe.)
		local baseSetActive = b.SetActive
		b.SetActive = function(s, on)
			baseSetActive(s, on)
			if s.redOn then
				press(s, on and true or false)
				if on then s.tex:SetVertexColor(1, 1, 1) else s.tex:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]) end
			end
		end
	end
	if not b.redArt then return end
	b.redOn = on
	for _, t in ipairs(b.redArt.pieces) do t:SetShown(on) end
	if on then
		b:SetSize(size, size); b.tex:SetSize(14, 14)
		if b.redArt.patch then
			local inset = math.floor(size * PATCH_INSET + 0.5)
			b.redArt.patch:ClearAllPoints()
			b.redArt.patch:SetPoint("TOPLEFT", inset, -inset); b.redArt.patch:SetPoint("BOTTOMRIGHT", -inset, inset)
		end
		b.restColor = GOLD
	else
		b:SetSize(b.modernSize[1], b.modernSize[2]); b.tex:SetSize(b.modernTex[1], b.modernTex[2])
		b.restColor = nil
	end
	b:SetActive(b.active)
end
Classic.RedButton = redButton

local DROPDOWN_ARROW_NUDGE = 2   -- px right of the template's spot
local DROPDOWN_ARROW_LIFT = 0.5  -- above it, so the gaps above and below match (1 was too high in game)
local DROPDOWNS = { { "WowStyle1DropdownTemplate", { "DropdownButton", "Button" } }, { "UIDropDownMenuTemplate", { "Frame" } } }
-- The dropdown look follows the picker button's own shown state. Set it
-- directly whenever the picker is shown or hidden: a button hidden while its
-- window is closed never sends OnHide, so the hooks alone can miss it.
function Classic.SyncDropdown(view)
	local art = view and view.classicDropdown
	if art and view.charBtn then art:SetShown((view.classicApplied and view.charBtn:IsShown()) and true or false) end
end
local function dropdownArt(view, on)
	local btn = view.charBtn
	if not btn then return end
	if on and view.classicDropdown == nil then
		local art
		for _, d in ipairs(DROPDOWNS) do
			for _, kind in ipairs(d[2]) do
				local ok, f = pcall(CreateFrame, kind, nil, view.title, d[1])
				if ok and f then art = f; note("Dropdown (" .. d[1] .. ")", true); break end
			end
			if art then break end
		end
		if not art then view.classicDropdown = false; note("Dropdown", false); return end
		-- Behind the picker (a sibling one layer down), so the picker keeps its
		-- icon, name and clicks; the art only provides the look.
		art:ClearAllPoints(); art:SetAllPoints(btn)
		art:SetFrameLevel(view.title:GetFrameLevel())
		art:EnableMouse(false)
		if art.Text and art.Text.SetText then art.Text:SetText("") end
		if art.Button and art.Button.EnableMouse then art.Button:EnableMouse(false) end
		-- The arrow sits 2 px further right and 0.5 px higher than the template
		-- puts it, so its gaps to the right, top and bottom edges match. Read
		-- from the template's own spot.
		local arrow = art.Arrow or art.Button
		local nudged = false
		if arrow and arrow.GetPoint and arrow.SetPoint then
			local p = { arrow:GetPoint(1) }
			if p[1] then
				if type(p[2]) == "number" then p = { p[1], art, p[1], p[2], p[3] } end
				arrow:ClearAllPoints()
				arrow:SetPoint(p[1], p[2] or art, p[3] or p[1], (p[4] or 0) + DROPDOWN_ARROW_NUDGE, (p[5] or 0) + DROPDOWN_ARROW_LIFT)
				nudged = true
			end
		end
		note("Dropdown arrow 2 px right, 0.5 px up", nudged)
		art:Hide()
		view.classicDropdown = art
		-- The picker only shows when there is more than one character; follow it.
		btn:HookScript("OnShow", function() if view.classicApplied then art:Show() end end)
		btn:HookScript("OnHide", function() art:Hide() end)
		local modernActive = btn.SetActive
		btn.SetActive = function(s, active)
			s.active = active
			if view.classicApplied and view.classicDropdown then
				s:SetBackdropColor(0, 0, 0, 0); s:SetBackdropBorderColor(0, 0, 0, 0)
				s.label:SetTextColor(1, 1, 1)
			else
				modernActive(s, active)
			end
		end
	end
	local art = view.classicDropdown
	if not art then return end
	art:SetShown(on and btn:IsShown())
	if view.charArrow then view.charArrow:SetShown(not on) end
	btn:SetActive(btn.active)
end

local function atlasOrFile(tex, atlases, files, useSize)
	for _, a in ipairs(atlases) do
		if atlasExists(a) then tex:SetAtlas(a, useSize); return true end
	end
	for _, f in ipairs(files) do
		if tex:SetTexture(f, "REPEAT", "REPEAT") ~= false then return true end
	end
	return false
end

-- Blizzard's own background for any Classic window: the Appearances stone
-- (or the plain stone), with the corner filigree. Earlier builds drew it
-- under the template's own dark fill, which covered it; that fill is hidden
-- now and the background sits on a higher sublayer. Returns true if a
-- Blizzard background loaded, so the caller can drop BagSmith's own fill.
local CORNER_ALPHA = 0.4
function Classic.Background(holder, chrome, cornerAnchor)
	holder.hiddenFills = {}
	local function hideFill(tex, name)
		if tex and tex.Hide then tex:Hide(); holder.hiddenFills[#holder.hiddenFills + 1] = name end
	end
	hideFill(chrome.Bg, "Bg"); hideFill(chrome.Background, "Background")
	if chrome.NineSlice then hideFill(chrome.NineSlice.Center, "NineSlice.Center") end
	hideFill(chrome.TopTileStreaks, "TopTileStreaks")

	local stone = chrome:CreateTexture(nil, "BACKGROUND", nil, 1)
	stone:SetPoint("TOPLEFT", 4, -4); stone:SetPoint("BOTTOMRIGHT", -4, 4)
	local okStone = stone:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT") ~= false
	if stone.SetHorizTile then stone:SetHorizTile(true); stone:SetVertTile(true) end
	note("Stone background", okStone)
	if not okStone then stone:Hide() end
	holder.classicStone = stone

	local tile = chrome:CreateTexture(nil, "BACKGROUND", nil, 2)
	tile:SetPoint("TOPLEFT", 4, -4); tile:SetPoint("BOTTOMRIGHT", -4, 4)
	local ok = atlasOrFile(tile, { "collections-background-tile" }, { "Interface\\Collections\\CollectionsBackgroundTile" }, false)
	if tile.SetHorizTile then tile:SetHorizTile(true); tile:SetVertTile(true) end
	note("Appearances background", ok)
	if not ok then tile:Hide(); holder.classicBgLoaded = okStone; return okStone end
	holder.classicTile = tile
	stone:Hide()
	holder.classicBgLoaded = true
	-- A thin layer of Modern's background over it, so rows and text read well.
	local shade = chrome:CreateTexture(nil, "BACKGROUND", nil, 4)
	shade:SetPoint("TOPLEFT", 4, -4); shade:SetPoint("BOTTOMRIGHT", -4, 4)
	shade:SetColorTexture(0.075, 0.07, 0.06, 0.35)
	holder.classicShade = shade
	if not cornerAnchor then return true end
	-- The filigree corner ornaments, just above the gold bar.
	local corners = {}
	for _, side in ipairs({ "left", "right" }) do
		local c = chrome:CreateTexture(nil, "BACKGROUND", nil, 3)
		local okc = atlasOrFile(c, { "collections-background-corner", "collections-background-corner-bottomleft" }, {}, true)
		if not okc then c:Hide(); corners = nil; break end
		if c:GetWidth() < 2 then c:SetSize(96, 96) end
		-- Dimmed so they read as part of the stone, not an ornament the
		-- list's last rows and the scrollbar sit on.
		c:SetAlpha(CORNER_ALPHA)
		-- These are the top-corner ornaments; flip them to sit at the bottom.
		if side == "left" then c:SetPoint("BOTTOMLEFT", cornerAnchor, "TOPLEFT", -6, 2); c:SetTexCoord(0, 1, 1, 0)
		else c:SetPoint("BOTTOMRIGHT", cornerAnchor, "TOPRIGHT", 6, 2); c:SetTexCoord(1, 0, 1, 0) end
		corners[#corners + 1] = c
	end
	note("Appearances corners", corners ~= nil)
	holder.classicCorners = corners
	return true
end

-- Segment buttons (Sections and View groups) get Blizzard button art too.
local function decorateSegment(b)
	if b.classicArt ~= nil then return end
	local ok, art = pcall(CreateFrame, "Button", nil, b, "UIPanelButtonTemplate")
	if not ok or not art then b.classicArt = false; return end
	art:SetAllPoints(b); art:EnableMouse(false)
	if art.SetText then art:SetText("") end
	art:Hide()
	b.classicArt = art
	local modernActive = b.SetActive
	b.SetActive = function(s, on)
		s.active = on
		if s.classicOn then
			art:SetButtonState(on and "PUSHED" or "NORMAL", on and true or false)
			s.label:SetTextColor(on and 1 or 0.95, on and 0.82 or 0.9, on and 0 or 0.8)
			s:SetBackdropColor(0, 0, 0, 0); s:SetBackdropBorderColor(0, 0, 0, 0)
		else
			modernActive(s, on)
		end
	end
	b:HookScript("OnEnter", function(s) if s.classicOn then art:LockHighlight() end end)
	b:HookScript("OnLeave", function(s) if s.classicOn then art:UnlockHighlight() end end)
end

------------------------------------------------------------------------
-- Switching a window between Modern and Classic (live)
------------------------------------------------------------------------
local PAD = 12
local C = ns.View.C

-- Sections and View groups: separate full-height buttons with small gaps in
-- Classic; joined segments in Modern.
local function layoutSegments(view, on)
	for _, box in ipairs(view.segBoxes or {}) do
		local btns = box.btns or {}
		-- (1.4.0-beta8) Classic's separate buttons share the group's Modern width so every label gets the same room on
		-- each side ("By Section" had almost none). The total stays the same, so the toolbar keeps its layout; if the
		-- labels are too wide to share it that way, the Modern widths stay.
		for _, b in ipairs(btns) do b.modernW = b.modernW or b:GetWidth() end
		local widths, total, labels = {}, 0, 0
		for i, b in ipairs(btns) do
			widths[i] = b.modernW
			total = total + b.modernW
			labels = labels + ((b.label and b.label.GetStringWidth and b.label:GetStringWidth()) or b.modernW)
		end
		local pad = #btns > 0 and math.floor((total - labels) / #btns) or 0
		if on and pad >= 12 then
			local used = 0
			for i, b in ipairs(btns) do
				widths[i] = math.floor(((b.label and b.label.GetStringWidth and b.label:GetStringWidth()) or 0) + pad)
				used = used + widths[i]
			end
			widths[#btns] = widths[#btns] + (total - used)   -- the rounding goes to the last button
		end
		local x = on and 0 or 1
		for i, b in ipairs(btns) do
			local w = widths[i]
			b:SetWidth(w)
			b:SetHeight(on and 22 or 18)
			b:ClearAllPoints(); b:SetPoint("LEFT", box, "LEFT", x, 0)
			x = x + w   -- (1.4.1) Classic: a group's buttons touch, so a pair reads as a pair even with its label hidden
			if b.divider then b.divider:SetShown(not on) end
		end
		local total = on and x or (x + 1)
		box:SetSize(total, on and 24 or 20)
		for _, item in ipairs(view.toolItems or {}) do if item.frame == box then item.width = total end end
	end
	if view.LayoutTools then view:LayoutTools() end
end

function Classic:Apply(view, on)
	local was = view.classicApplied
	if on and not view.modernSnapshot then view.modernSnapshot = record(view) end
	if on and view.classicChrome == nil then view.classicChrome = buildChrome(view) or false end
	local chrome = view.classicChrome or nil
	on = on and chrome ~= nil
	view.classicApplied = on

	chrome = view.classicChrome or nil
	if chrome then chrome:SetShown(on) end
	if view.classicClose then view.classicClose:SetShown(on) end   -- it lives on the window, not on the chrome

	-- BagSmith's own frame art steps aside.
	if on then
		-- Keep a slate fill underneath in case the template brings no background
		-- of its own; if it does, it draws over this.
		view.frame:SetBackdropColor(0.09, 0.09, 0.1, view.classicBgLoaded and 0 or 0.96)
		view.frame:SetBackdropBorderColor(0, 0, 0, 0)
	end
	view.title.band:SetShown(not on)
	view.mark:SetShown(not on)
	view.closeBtn:SetShown(not on)
	if view.footer.line then view.footer.line:SetShown(not on) end

	-- The title moves into Blizzard's strip; BagSmith's title row (character
	-- picker, icons) moves below it, clear of the portrait.
	if on then
		view.title:ClearAllPoints()
		view.title:SetPoint("TOPLEFT", view.frame, "TOPLEFT", 60, -26)
		view.title:SetPoint("TOPRIGHT", view.frame, "TOPRIGHT", -10, -26)
		view.subText:ClearAllPoints(); view.subText:SetPoint("LEFT", view.title, "LEFT", 2, 0)
	end
	-- Only the title row needs to clear the portrait: from the search row down, the rows start at the window's
	-- inner margin, under the portrait's lower half (1.3.0).
	if view.PlaceBelow then view:PlaceBelow(on and (PAD - 60) or 0) end
	if view.classicTitle then
		view.classicTitle:SetText(on and (view.opts.title or "") or "")
	end

	-- The bank has nothing on its title row in Classic: collapse it.
	if on then view.title:SetHeight(view.isBank and 1 or C.TITLE_H) end

	-- Buttons: full height so Blizzard's art isn't squashed.
	local function each(list, fn) for _, b in pairs(list or {}) do fn(b) end end
	local buttons = { view.btnFilter, view.btnSort, view.btnMerge, view.btnBags, view.btnReagent, view.btnBagBar }
	each(buttons, function(b)
		if b and b.SetClassic then
			b:SetClassic(on)
			-- Toolbar buttons go full height; the footer's count buttons keep
			-- 20 px so the gold bar keeps its height.
			if on and b ~= view.btnFilter and not b.isCount and not b.inFooter then b:SetHeight(22) end
		end
	end)

	-- Tabs hang below the window like Blizzard's; the gold bar stays inside.
	if view.tabs and on then
		view.tabs:ClearAllPoints()
		view.tabs:SetPoint("TOPLEFT", view.frame, "BOTTOMLEFT", PAD, 3)
		view.tabs:SetPoint("TOPRIGHT", view.frame, "BOTTOMRIGHT", -PAD, 3)
		-- The list now ends at the gold bar instead of the tabs.
		view:PlaceScroll(true)   -- the list ends at the gold bar (and keeps the scrollbar's lane only when it scrolls)
	end
	each(view.tabButtons, function(b)
		if b.SetClassic then b:SetClassic(on, Classic.TabTemplate()) end
	end)
	each(view.segButtons, function(b)
		if on then decorateSegment(b) end
		if b.classicArt then
			b.classicOn = on
			b.classicArt:SetShown(on)
			b.label:SetParent(on and b.classicArt or b)
		end
		b:SetActive(b.active)
	end)
	each(view.segBoxes, function(box)
		if on then box:SetBackdropColor(0, 0, 0, 0); box:SetBackdropBorderColor(0, 0, 0, 0) end
	end)
	if on then layoutSegments(view, true) end

	-- Bank, Currencies, Settings and back-to-own-bags: Blizzard's square
	-- buttons with BagSmith's icons in gold. The character picker: Blizzard's
	-- dropdown look.
	squareButton(view.btnBank, on); if view.btnGearSets then squareButton(view.btnGearSets, on) end; squareButton(view.btnCurrency, on); squareButton(view.btnSettings, on); squareButton(view.charReset, on)
	dropdownArt(view, on)

	-- Broom: BagSmith's own icon in the same square button as the others.
	squareButton(view.btnClean, on)
	if view.btnDisenchant then squareButton(view.btnDisenchant, on) end

	-- Travel Mode: beside Blizzard's red close button in the title strip (the
	-- close button's art has its X drawn in, so the signpost goes on the same
	-- square button the other icons use). The other icons stay on the row below.
	if view.btnTravel then
		-- The size of the red close button's face, right beside it.
		redButton(view.btnTravel, on, TRAVEL_SIZE)
		view.btnTravel:ClearAllPoints()
		view.btnSettings:ClearAllPoints()
		if view.titleDivider then view.titleDivider:SetShown(not on) end
		if on and view.classicClose then
			view.btnTravel:SetPoint("RIGHT", view.classicClose, "LEFT", -1, TRAVEL_LIFT)
			view.btnTravel:SetFrameLevel(view.classicClose:GetFrameLevel())
			note(("Travel Mode button %d px, %d px up, in line with the close button's face"):format(TRAVEL_SIZE, TRAVEL_LIFT), true)
			view.btnSettings:SetPoint("RIGHT", view.closeBtn, "LEFT", 0, 0)
		else
			view.btnTravel:SetPoint("RIGHT", view.closeBtn, "LEFT", 0, 0)
			view.btnTravel:SetFrameLevel(view.title:GetFrameLevel() + 1)
			view.btnSettings:SetPoint("RIGHT", view.titleDivider or view.btnTravel, "LEFT", view.titleDivider and -4 or 0, 0)
		end
	end

	-- Scrollbar: Blizzard's arrows back on, with room for them.
	local bar = view.scroll and view.scroll.ScrollBar
	if bar then
		for _, key in ipairs({ "Back", "Forward", "ScrollUpButton", "ScrollDownButton" }) do
			local btn = bar[key] or _G[(bar:GetName() or "") .. key]
			if btn then btn:SetAlpha(on and 1 or 0); btn:EnableMouse(on) end
		end
		if on then
			bar:ClearAllPoints()
			bar:SetPoint("TOPLEFT", view.scroll, "TOPRIGHT", 6, -16)
			bar:SetPoint("BOTTOMLEFT", view.scroll, "BOTTOMRIGHT", 6, 16)
		end
		if bar.Track and bar.Track.Thumb then bar.Track.Thumb:SetAlpha(on and 1 or 0.6) end
	end
	-- Leaving Classic: put back exactly what Modern had.
	if not on and view.modernSnapshot then restore(view, view.modernSnapshot) end
	if on then view.classicEverApplied = true end
	if view.big and view.UpdateTabs and view.tabButtons then view:UpdateTabs() end
	-- Last step on the way out: Modern repaints its own colors now that
	-- Classic has stepped aside (the group outlines were left off before).
	if was and not on then repaint(view.frame) end
end

------------------------------------------------------------------------
-- Classic for any other window (Settings, Filter panel, currency drawer,
-- confirm dialog, small bag windows). Same rules as the bags window: built
-- the first time Classic is on, never touches a window in Modern unless
-- Classic has been on for it, and puts back the recorded Modern layout.
--   spec.template  "PortraitFrameTemplate" (default) or e.g. "DialogBorderTemplate"
--   spec.portrait  function returning a texture path (omit for no portrait)
--   spec.title     function returning the title for the strip
--   spec.close     function to close the window (adds Blizzard's red X)
--   spec.hide      BagSmith pieces to hide in Classic
--   spec.moves     { region, function that positions it for Classic }
--   spec.restore   function that repaints the window's Modern look
--   spec.corners   frame the corner ornaments sit above (optional)
------------------------------------------------------------------------
local function setPortrait(tex, path, chrome)
	tex:SetTexture(path or ICON)
	tex:SetTexCoord(0.12, 0.88, 0.12, 0.88)
	if not tex.bsMasked and chrome.CreateMaskTexture and tex.AddMaskTexture then
		local mask = chrome:CreateMaskTexture()
		mask:SetAllPoints(tex)
		if pcall(mask.SetTexture, mask, "Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") then
			tex:AddMaskTexture(mask); tex.bsMasked = true
		end
	end
end

local function hidePortrait(chrome)
	if ButtonFrameTemplate_HidePortrait and pcall(ButtonFrameTemplate_HidePortrait, chrome) then return end
	if chrome.PortraitContainer then chrome.PortraitContainer:Hide() end
	if chrome.portrait then chrome.portrait:Hide() end
end

-- Every Classic window built on Blizzard's dialog frame shares one dark fill
-- over its see-through background (menus, Loot Helper, Never Ask, Moved
-- Items, confirmations, prompts, the link box, Profile Sharing).
Classic.DIALOG_SOLID = 1.0
Classic.DIALOG_ART = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"

-- 1.1.0: a scrollbar outside the views (the Settings panel's) gets the same Classic treatment as the bag
-- window's: Blizzard's arrows back on, with room for them; Modern puts back what it had.
function Classic:DressScrollBar(scroll, on)
	local bar = scroll and scroll.ScrollBar
	if not bar then return end
	if not bar.classicSnap then bar.classicSnap = grab(bar) end
	for _, key in ipairs({ "Back", "Forward", "ScrollUpButton", "ScrollDownButton" }) do
		local btn = bar[key] or _G[(bar:GetName() or "") .. key]
		if btn then btn:SetAlpha(on and 1 or 0); btn:EnableMouse(on) end
	end
	if on then
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, -16)
		bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 16)
	else put(bar, bar.classicSnap) end
	if bar.Track and bar.Track.Thumb then bar.Track.Thumb:SetAlpha(on and 1 or 0.6) end
end
-- 1.0.2: a dialog dressed like the windows. The same window frame and the same window background as the bags
-- window (no portrait: dialogs have no room beside their first line), the dialog's own title text shown in the
-- title bar and hidden where it was, the chrome's close button hiding the dialog. Regions that would sit under
-- the title bar are passed as moves. Modern is untouched: the spec applies only when Classic is on.
Classic.DIALOG_BAR = 26        -- the window frame's title bar, which a dialog's content must clear
Classic.DIALOG_MIN_H = 132     -- below this the window frame's corner art no longer fits a dialog
-- The chrome's title follows the dialog's own title whenever it is set (a copy window reused for a new
-- subject while it stays open, a share window built shown and titled afterwards).
function Classic:RefreshTitle(f)
	local st = f and f.classicState
	if st and st.on and st.title then st.title:SetText((f.classicSpec and f.classicSpec.title and f.classicSpec.title()) or "") end
end
function Classic.DialogSpec(f, opts)
	opts = opts or {}
	-- A short dialog grows to the frame art's minimum in Classic and keeps its own, content-derived height in
	-- Modern: the dialog's SetHeight/SetSize record the natural height it asked for, and apply the minimum
	-- while Classic is on, whenever the dialog is sized (on show, on a refresh, on a longer message). No
	-- anchor is touched by this, and leaving Classic restores the natural height the dialog last asked for.
	if not f.classicHeightWrapped and f.SetHeight and f.SetSize then
		f.classicHeightWrapped = true
		local origH, origS = f.SetHeight, f.SetSize
		local function want(self, h)
			self.classicNaturalH = h
			local st = self.classicState
			if st and st.on and type(h) == "number" and h < Classic.DIALOG_MIN_H then return Classic.DIALOG_MIN_H end
			return h
		end
		f.SetHeight = function(self, h) origH(self, want(self, h)) end
		f.SetSize = function(self, w, h) origS(self, w, want(self, h)) end
	end
	local moves = {}
	for _, m in ipairs(opts.moves or {}) do moves[#moves + 1] = m end
	-- a dialog's title changes per use (a link's label, a share window's subject): the bar follows it on show
	if f.HookScript and not f.classicTitleHooked then
		f.classicTitleHooked = true
		f:HookScript("OnShow", function()
			local st = f.classicState
			if not (st and st.on) then return end
			if st.title then st.title:SetText((f.classicSpec and f.classicSpec.title and f.classicSpec.title()) or "") end
			-- a dialog that sizes itself to its content on show (the confirm box) still keeps the frame art's minimum
			for _, m in ipairs(st.moves or {}) do m.apply() end
		end)
	end
	return {
		title = opts.title or function() return (f.title and f.title.GetText and f.title:GetText()) or "" end,
		close = opts.close or function() f:Hide() end,
		hideFn = function() local t = {}; if f.title then t[#t + 1] = f.title end; for _, r in ipairs(opts.hide or {}) do t[#t + 1] = r end; return t end,
		moves = moves,
		dialog = true,
		restore = opts.restore,
	}
end
function Classic:Dress(frame, spec, on)
	local st = frame.classicState
	if not on and not st then return end          -- never dressed: Modern is left exactly as built
	if on and not st then
		st = { moves = {}, hidden = {} }
		frame.classicState = st
		for _, m in ipairs(spec.moves or {}) do st.moves[#st.moves + 1] = { region = m[1], snap = grab(m[1]), apply = m[2], size = m[3] } end
		local template = spec.template or "PortraitFrameTemplate"
		local chrome = tryFrame("Frame", frame, template, template == "PortraitFrameTemplate" and "Window frame (PortraitFrameTemplate)" or ("Dialog frame (" .. template .. ")"))
		if chrome then
			chrome:SetAllPoints(frame)
			chrome:SetFrameLevel(frame:GetFrameLevel())
			chrome:EnableMouse(false)
			if spec.dialog then
				-- the template's child frames (title container, nine-slice, portrait) must not take the mouse from a
				-- dialog that drags itself; the chrome's close button stays clickable
				for _, child in ipairs({ chrome:GetChildren() }) do
					if child ~= chrome.CloseButton and child.EnableMouse then child:EnableMouse(false) end
				end
				-- the title bar drags the dialog, like the windows' own drag band
				if not st.drag and frame.StartMoving then
					local drag = CreateFrame("Frame", nil, frame)
					drag:SetPoint("TOPLEFT", 0, 0); drag:SetPoint("TOPRIGHT", -30, 0); drag:SetHeight(Classic.DIALOG_BAR)
					drag:SetFrameLevel(chrome:GetFrameLevel() + 5)
					drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
					drag:SetScript("OnDragStart", function()
						if not (frame.IsMovable and frame:IsMovable()) then return end
						local own = frame:GetScript("OnDragStart"); if own then own(frame) else frame:StartMoving() end
					end)
					drag:SetScript("OnDragStop", function()
						local own = frame:GetScript("OnDragStop"); if own then own(frame) else frame:StopMovingOrSizing() end
					end)
					st.drag = drag
				end
			end
			if template == "PortraitFrameTemplate" then
				local portrait = (chrome.PortraitContainer and chrome.PortraitContainer.portrait) or chrome.portrait
				if spec.portrait then
					if not portrait then
						portrait = chrome:CreateTexture(nil, "OVERLAY"); portrait:SetSize(58, 58); portrait:SetPoint("TOPLEFT", -5, 7)
					end
					st.portrait = portrait
				else
					hidePortrait(chrome)
				end
				local title = (chrome.TitleContainer and chrome.TitleContainer.TitleText) or chrome.TitleText
				if not title then title = chrome:CreateFontString(nil, "OVERLAY", "GameFontNormal"); title:SetPoint("TOP", 0, -5) end
				st.title = title
				if chrome.CloseButton then chrome.CloseButton:Hide() end
				if spec.close then
					local close = tryFrame("Button", frame, "UIPanelCloseButton", "Close button")
					if close then
						Classic.closeFrom[(spec.title and spec.title()) or (frame.GetName and frame:GetName()) or "window"] = placeClose(close, chrome, frame)
						close:SetFrameLevel(Classic.TopLevel(chrome) + 10)
						close:SetScript("OnClick", spec.close)
						st.close = close
					end
				end
				Classic.Background(st, chrome, spec.corners)
						end
			-- A window that asks for it gets a dark fill over the template's
			-- background, so less of the world shows through.
			local solid = (template == "DialogBorderTemplate") and Classic.DIALOG_SOLID or spec.solid
			if solid then
				local fill = chrome:CreateTexture(nil, "BACKGROUND", nil, 7)
				-- Fully solid: Blizzard's own dark dialog background (the art classic
				-- dialogs and menus use), tiled; plain black if that art is missing.
				local art = template == "DialogBorderTemplate" and solid >= 1
				local okArt = false
				if art then
					local ok = pcall(fill.SetTexture, fill, Classic.DIALOG_ART, "REPEAT", "REPEAT")
					okArt = ok and fill:GetTexture() ~= nil
					if okArt then
						fill:SetHorizTile(true); fill:SetVertTile(true)
						fill:SetVertexColor(1, 1, 1, 1)
					end
				end
				if not okArt then fill:SetColorTexture(0, 0, 0, solid) end
				if art then note("Dialog background", okArt) end
				fill:SetPoint("TOPLEFT", 6, -6); fill:SetPoint("BOTTOMRIGHT", -6, 6)
				st.solid = fill
			end
			st.chrome = chrome
		end
	end
	if not st.chrome then return end
	if st.drag then st.drag:SetShown(on) end
	-- moves added to the spec after the first dressing (a dialog that builds its regions after registering with
	-- the skins) join with their own snapshots
	for i = #st.moves + 1, #(spec.moves or {}) do local m = spec.moves[i]; if m and m[1] then st.moves[i] = { region = m[1], snap = grab(m[1]), apply = m[2], size = m[3] } end end
	st.chrome:SetShown(on)
	if st.close then st.close:SetShown(on) end
	local hideList = spec.hide or (spec.hideFn and spec.hideFn()) or {}
	for _, r in ipairs(hideList) do
		if on then
			if not st.hidden[r] then st.hidden[r] = { shown = r:IsShown() } end
			r:Hide()
		elseif st.hidden[r] then
			r:SetShown(st.hidden[r].shown); st.hidden[r] = nil
		end
	end
	for _, m in ipairs(st.moves) do
		-- Classic only moves these; restore positions (and a size, when the move changed one).
		if on then m.apply() else put(m.region, m.snap, m.size) end
	end
	if on then
		if st.title and spec.title then st.title:SetText(spec.title() or "") end
		if st.portrait and spec.portrait then setPortrait(st.portrait, spec.portrait(), st.chrome) end
		if frame.SetBackdropColor then
			frame:SetBackdropColor(0.09, 0.09, 0.1, (st.classicBgLoaded or spec.template) and 0 or 0.96)
			frame:SetBackdropBorderColor(0, 0, 0, 0)
		end
	elseif spec.restore then
		spec.restore()
	end
	local was = st.on
	st.on = on
	if spec.dialog and frame.classicHeightWrapped then frame:SetHeight(frame.classicNaturalH or frame:GetHeight()) end
	Classic:DressButtons(frame, on)
	if was and not on then repaint(frame) end
end

-- Every BagSmith text button inside a dressed window becomes a Blizzard red
-- button in Classic (and back in Modern). Run again after a window creates
-- new buttons, e.g. when a Settings page opens.
function Classic:DressButtons(frame, on)
	local st = frame and frame.classicState
	if not st then return end
	if on == nil then on = st.on end
	local function walk(f, depth)
		if depth > 7 or not f.GetChildren then return end
		for _, child in ipairs({ f:GetChildren() }) do
			if child.SetClassic and child ~= st.close then child:SetClassic(on) end
			walk(child, depth + 1)
		end
	end
	walk(frame, 0)
end

-- Keeps the strip title (and portrait) current while dressed.
function Classic:Retitle(frame, text, portrait)
	local st = frame and frame.classicState
	if not (st and st.on) then return end
	if st.title and text then st.title:SetText(text) end
	if st.portrait and portrait then setPortrait(st.portrait, portrait, st.chrome) end
end

function Classic.IsOn() return ns.db and ns.db.skin == "classic" end

-- Small bag windows: Blizzard's bag frame, with the bag's own icon in the
-- portrait (as Forever draws its bags) and the bag's name in the strip.
local function bagIcon(view)
	local bag = view.opts.bags and view.opts.bags[1]
	if bag == nil then return ICON end
	if bag == ns.BACKPACK then return "Interface\\Buttons\\Button-Backpack-Up" end
	local info = ns.bagInfo[bag]
	if bag == ns.BANK or (info and info.name == "Default") then return ICON end
	local inv
	local ok, r = pcall(C_Container.ContainerIDToInventoryID, bag)
	if ok then inv = r end
	if not inv and view.opts.bank and ns.Bank and ns.Bank.InvSlot then inv = ns.Bank:InvSlot(bag - ns.NUM_BAGS) end
	return (inv and GetInventoryItemTexture("player", inv)) or ICON
end
Classic.BagIcon = bagIcon

-- Classic bag windows have a minimum height. Blizzard's frame builds its
-- left border from the top-left piece (the portrait ring), the bottom-left
-- piece and an edge strip stretched between them; in a window shorter than
-- those pieces need, the strip starts too high and runs through the ring
-- (seen on every one-row bag window, never on taller ones). The minimum is
-- the proven height of a two-row bag window, raised further if the frame
-- art itself says it needs more.
local BAG_MIN_PROVEN = 160
local function measuredMinHeight(st)
	local chrome = st and st.chrome
	local nine = chrome and chrome.NineSlice
	if not nine then return nil end
	local function bottomBelowTop(tex)
		if not (tex and tex.GetHeight and tex.GetPoint) then return nil end
		local point, _, _, _, y = tex:GetPoint(1)
		if type(y) ~= "number" then local _, a, b = tex:GetPoint(1); if type(a) == "number" then y = b end end
		local h = tex:GetHeight()
		if not (point and point:find("^TOP") and h and h > 0) then return nil end
		return h - (y or 0)
	end
	local function topAboveBottom(tex)
		if not (tex and tex.GetHeight and tex.GetPoint) then return nil end
		local point, _, _, _, y = tex:GetPoint(1)
		if type(y) ~= "number" then local _, a, b = tex:GetPoint(1); if type(a) == "number" then y = b end end
		local h = tex:GetHeight()
		if not (point and point:find("^BOTTOM") and h and h > 0) then return nil end
		return h + (y or 0)
	end
	local ring = bottomBelowTop(nine.TopLeftCorner)
	local portrait = bottomBelowTop(st.portrait)
	if portrait and (not ring or portrait > ring) then ring = portrait end
	local base = topAboveBottom(nine.BottomLeftCorner)
	if not (ring and base) then return nil end
	local h = math.floor(ring + base + 8 + 0.5)
	if h < 60 or h > 400 then return nil end
	return h
end
-- The height a dressed bag window must keep (nil when it isn't in Classic).
function Classic.BagMinHeight(view)
	local st = view and view.frame and view.frame.classicState
	if not (st and st.on) then return nil end
	local measured = measuredMinHeight(st)
	Classic.bagMin = { measured = measured, proven = BAG_MIN_PROVEN }
	return math.max(measured or 0, BAG_MIN_PROVEN)
end

function Classic:DressSmall(view, on)
	if not view.classicSpecSmall then
		local f = view.frame
		view.classicSpecSmall = {
			portrait = function() return bagIcon(view) end,
			title = function() return view.opts.title or "" end,
			close = function() local fn = view.closeBtn:GetScript("OnClick"); if fn then fn(view.closeBtn) end end,
			hide = { view.mark, view.titleText, view.closeBtn, view.title.band },
			-- The title row (just the slot count) keeps its left edge and only
			-- moves down, so the grid below it isn't pushed right and clipped.
			moves = {
				{ view.title, function()
					view.title:ClearAllPoints()
					view.title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -34)
					view.title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -34)
				end },
				-- Modern gives the grid room under its header band; Classic
				-- keeps its own spacing under the slot count.
				{ view.scroll, function()
					view:PlaceScroll(true)
				end },
			},
			restore = function() ns.Skins:ApplyBackdrop(f) end,
		}
	end
	self:Dress(view.frame, view.classicSpecSmall, on)
end

------------------------------------------------------------------------
-- /bs skincheck
------------------------------------------------------------------------
function Classic:Report()
	Classic.TabTemplate()
	ns:Print("--- Classic skin check ---")
	local names = {}
	for k in pairs(Classic.status) do names[#names + 1] = k end
	table.sort(names)
	if #names == 0 then ns:Print("Switch to the Classic skin once, then run this again.") return end
	for _, k in ipairs(names) do
		ns:Print("  %s: %s", k, Classic.status[k] and "|cff60ff60ok|r" or "|cffff6060missing (Modern look used)|r")
	end
	if ns.BagBar then
		ns:Print("  Keys slot art: %s", ns.BagBar:KeyArt() == "blizzard" and "|cff60ff60Blizzard's keyring button|r" or "BagSmith's drawn key (Blizzard's keyring art not found)")
		local sf = ns.BagBar:SlotFrameArt()
		ns:Print("  Bag strip slot frames (bags and bank): %s", sf.atlas and ("|cff60ff60from " .. sf.from .. "|r") or (sf.from:find("UI%-Quickslot2") and sf.from or ("|cff60ff60from " .. sf.from .. "|r")))
	end
	local slotArt = ns.Buttons.TemplateSlotArt()
	ns:Print("  Empty slot art: %s", slotArt and ("|cff60ff60Forever's, from " .. slotArt.from .. "|r") or "|cffff6060classic-era fallback|r")
	local main = ns.Window and ns.Window.main
	if main and main.hiddenFills then
		ns:Print("  Template fills hidden so the background shows: %s", #main.hiddenFills > 0 and table.concat(main.hiddenFills, ", ") or "none found")
	end
	if main and main.classicClose and main.classicChrome then
		local close = main.classicClose
		local visible = close.IsVisible and close:IsVisible()
		-- (it follows its window: with the bags window closed there's nothing to judge)
		local state = visible and "|cff60ff60yes|r" or (main:IsShown() and "|cffff6060no|r" or "can't tell, the bags window is closed")
		ns:Print("  Close button visible: %s (layer %d, frame border up to %d)", state,
			close:GetFrameLevel(), Classic.TopLevel(main.classicChrome))
	end
	-- Where each window's close button got its spot: "template" is Blizzard's
	-- own corner spot; "fallback" means the template had no close button.
	local wins = {}
	for k, v in pairs(Classic.closeFrom) do wins[#wins + 1] = ("%s (%s)"):format(k, v) end
	table.sort(wins)
	if #wins > 0 then ns:Print("  Close button placement: %s", table.concat(wins, ", ")) end
	if main and main.classicBar then
		ns:Print("  Gold bar: flat, drawn on the frame art's background layer (no inset template)")
	end
	ns:Print("  Corner filigree strength: %d%%", CORNER_ALPHA * 100)
	local bm = Classic.bagMin
	if bm then
		ns:Print("  Bag window minimum height: %d (proven two-row height %d; from the frame art: %s)",
			math.max(bm.measured or 0, bm.proven), bm.proven, bm.measured and tostring(bm.measured) or "not readable")
	end
	local open = {}
	for _, v in pairs(ns.Window and ns.Window.bagViews or {}) do
		if v.frame and v.frame:IsShown() then open[#open + 1] = ("%s %d"):format(v.opts.title or "?", math.floor((v.frame:GetHeight() or 0) + 0.5)) end
	end
	table.sort(open)
	if #open > 0 then ns:Print("  Open bag window heights: %s", table.concat(open, ", ")) end
end
