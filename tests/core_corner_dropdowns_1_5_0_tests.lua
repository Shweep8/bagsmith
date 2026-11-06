;(function()
	-- 1.5.0-beta10 (Shweep: "MUCH better"): Icon Corners as dropdowns. Two small previews at the top, side by side (your
	-- real icon and a List row's icon, each magnified as a whole); a group per corner with a dropdown for the mark that
	-- shows and "then" backups (+ adds, x removes); a mark in another corner moves when chosen; None empties a corner;
	-- the stack count locked first (choosing it in another corner's first dropdown moves it there, ahead of what was
	-- there); marks in no corner listed as not shown, other addons' new ones flagged.
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local P, C = n.SettingsPanel, n.Corners
	local API = BagSmith.API
	API.RegisterCornerWidget("Polestar: a deliberately long upgrade arrow", "ps_arrow", function() return true end, function(b) return b:CreateTexture() end, { corner = "top_right", priority = 9 })
	API.RegisterCornerWidget("Forever Buddy: bag mark", "fb_mark", function() return true end, function(b) return b:CreateTexture() end)
	P:Show(); P:ShowPage("icons")
	local function w() return P.pools.cornerCards[1] end
	local function rows(k) local t = {}; for _, r in ipairs(w().groups[k].rows) do if r:IsShown() then t[#t + 1] = r end end return t end
	-- the previews
	local size = n.db.iconSize or 37
	check(w().iconsLabel.text == "Icons view" and w().listLabel.text == "List view" and w().preview:GetWidth() == size and math.abs((w().preview.scale or 1) * size - 56) < 0.01, "two previews at the top: your icon at your Icon Size, magnified to about 56 px, and a List view row")
	check(w().listQty.text == "20" and w().listName.text == "Sample" and w().previewList:IsShown(), "the List view row has its Qty column, icon and name")
	-- the groups: below the previews, full width, inside the page's 416 px
	local g = w().groups.top_left
	local gp = g.points[1]
	check(gp[4] == 0 and -gp[5] >= 84 and g:GetWidth() == w():GetWidth() and w():GetWidth() <= 416, "the corner groups sit below the previews, full width, inside 416 px")
	check(g.title.text == "Top Left" and g.dot:IsShown(), "each group is labelled, with a small corner glyph")
	-- a long name fits whole in its dropdown
	local long
	for _, r in ipairs(rows("top_right")) do if r.id == "ps_arrow" then long = r end end
	local room = w():GetWidth() - 4 - 34 - 48 - 8 - 22
	check(long and long.drop.label.text == "Polestar: a deliberately long upgrade arrow" and long.drop.label:GetStringWidth() <= room, "a long name from another addon fits whole in its dropdown")
	-- the stack count moves ahead of what's there; the displaced mark becomes the first backup
	local items = P.CornerChoices("top_left", 1, "junk", false)
	for _, it in ipairs(items) do if it.text == "Stack Count (in Bottom Right)" then it.onClick() end end
	check(n.db.iconCorners.top_left[1] == "quantity" and n.db.iconCorners.top_left[2] == "junk" and C:CornerOf("quantity") == "top_left", "choosing the stack count in another corner moves it there, first; the mark there becomes the first backup")
	local q = rows("top_left")[1]
	check(q.drop.locked and q.lock:IsShown() and rows("top_left")[2].thenLabel:IsShown(), "it's locked there, with the junk coin as its backup")
	C:Reset(); P:Refresh()
	-- a new mark from another addon is flagged until placed
	check(w().unused.text:find("Forever Buddy: bag mark (new)", 1, true), "an unplaced mark from another addon is listed as not shown, flagged new")
	local addItems = P.CornerChoices("bottom_right", 2, nil, true)
	local fb
	for _, it in ipairs(addItems) do if it.text == "Forever Buddy: bag mark (new)" then fb = it end end
	check(fb ~= nil, "and the + menu offers it, flagged new")
	fb.onClick()
	check(C:CornerOf("fb_mark") == "bottom_right" and not w().unused.text:find("Forever Buddy", 1, true) and n.db.iconCornersSeen.fb_mark, "added as a backup, it's no longer new (remembered)")
	local fbRow
	for _, r in ipairs(rows("bottom_right")) do if r.id == "fb_mark" then fbRow = r end end
	check(fbRow and fbRow.thenLabel:IsShown() and fbRow.remove:IsShown() and fbRow.add:IsShown(), "its row says then, with x to remove and + to add another")
	-- hovering a group lights its corner up on the sample
	local tl = w().groups.top_left
	tl:GetScript("OnEnter")(tl)
	local lit = w().hi.top_left:IsShown()
	tl.IsMouseOver = function() return false end
	tl:GetScript("OnLeave")(tl)
	check(lit and not w().hi.top_left:IsShown(), "hovering a corner's group lights it up on the sample")
	-- a search finds a mark by name
	local box = P.frame.search
	box:SetText("buddy"); box:GetScript("OnTextChanged")(box, true)
	local found = false
	for _, h in ipairs(P.pools.head) do if h:IsShown() and h.text.text == "Icon Corners" then found = true end end
	check(found, "searching a mark's name finds Icon Corners")
	box:SetText(""); box:GetScript("OnTextChanged")(box, true)
	-- every label BagSmith shows in Settings uses characters the game's fonts draw
	local bad = {}
	local function scan(t)
		if type(t) ~= "string" or t == "" then return end
		local s = t:gsub("\226\128[\152\153\156\157\166]", "")
		if s:find("[\128-\255]") then bad[#bad + 1] = t end
	end
	for _, nb in ipairs(P.navButtons or {}) do
		if nb.page then
			P:ShowPage(nb.page)
			for _, pool in pairs(P.pools) do
				for _, wd in ipairs(pool) do
					if wd:IsShown() then
						for _, f in ipairs({ wd.text, wd.help, wd.label, wd.title, wd.unused }) do if type(f) == "table" then scan(f.text) end end
						for _, grp in pairs(wd.groups or {}) do for _, r in ipairs(grp.rows or {}) do scan(r.drop and r.drop.label.text); scan(r.thenLabel and r.thenLabel.text) end end
					end
				end
			end
		end
	end
	check(#bad == 0, "every Settings label uses characters the game's fonts can draw (" .. table.concat(bad, " | ") .. ")")
	P:Hide()
end)()

;(function()
	-- Classic: the selected tab's pieces keep their full height; only the normal pieces are cropped
	package.loaded.mock = nil
	local M = require("mock")
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "classic" } } }
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local tab
	for _, b in ipairs(n.Window.main.tabButtons or {}) do if b:IsShown() and b.classicOn then tab = b; break end end
	local art = tab.classic
	local function piece(h)
		local t = art:CreateTexture()
		t.SetHeight = function(self, v) self.h = v end; t.GetHeight = function(self) return self.h end
		t.GetWidth = function(self) return self.w end; t.SetSize = function(self, a, b) self.w, self.h = a, b end
		t.coords = { 0, 0, 1, 1 }
		t.GetTexCoord = function(self) local c = self.coords; return c[1], c[2], c[1], c[3], c[4], c[2], c[4], c[3] end
		t.SetTexCoord = function(self, l, r, top, bottom) self.coords = { l, top, bottom, r } end
		t:SetSize(20, h); t:Show()
		return t
	end
	art.Left, art.Right = piece(32), piece(32)
	art.LeftActive, art.RightActive = piece(36), piece(36)
	art.LeftDisabled = piece(36)
	art.GetRegions = function() return art.Left, art.Right, art.LeftActive, art.RightActive, art.LeftDisabled end
	n.Classic.FitTabArt(tab)
	local h = tab:GetHeight()
	check(art.Left:GetHeight() == h and art.Right:GetHeight() == h, "Classic: the normal tab pieces are cropped to the tab")
	check(art.LeftActive:GetHeight() == 36 and art.RightActive:GetHeight() == 36 and art.LeftDisabled:GetHeight() == 36 and art.LeftActive.coords[3] == 1, "the selected tab's pieces keep their full height and art (its gold bottom edge)")
end)()
