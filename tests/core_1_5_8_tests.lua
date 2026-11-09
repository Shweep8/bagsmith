;(function()
	-- 1.5.8 (Shweep): long tooltip lines took up too much of the screen; the Disenchant Helper's Mark as Junk button ran
	-- past the panel's vertical rule over "DE estimate, 3 of 20 of your disenchants" (narrower windows); and that count
	-- read as if it were per item. Tooltips now wrap at about ns.TIP_CHARS characters; Mark as Junk is the List view
	-- rows' pouch icon; the line reads "... in this range" with an (i) that explains the shared count.
	local DEID = 13262
	local function boot()
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 7001, name = "Cheese Knife", q = 2, count = 1, class = 2, subclass = 15, price = 294, ilvl = 18, equip = "INVTYPE_WEAPON" })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
		_G.IsSpellKnown = function(id) return id == DEID end
		_G.GetNumSkillLines = function() return 2 end
		_G.GetSkillLineInfo = function(i) if i == 1 then return "Professions", true end return "Enchanting", false, nil, 150 end
		_G.RegisterStateDriver = function() end
		_G.UnregisterStateDriver = function() end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M
	end
	local n, M = boot()
	-- the shared mock's tooltip is a plain table: give it what these checks need (the Disenchant row tooltip also uses
	-- ClearLines and SetHyperlink), and record every line with its arguments
	local tt = GameTooltip
	tt.ClearLines = tt.ClearLines or function() end
	tt.SetHyperlink = tt.SetHyperlink or function() end
	local hooks = {}
	tt.HookScript = function(self, ev, fn) hooks[ev] = hooks[ev] or {}; table.insert(hooks[ev], fn) end
	tt.SetMinimumWidth = function(self, w) self.minW = w end
	tt.Hide = function(self) self.shown = false; for _, fn in ipairs(hooks.OnHide or {}) do fn(self) end end
	local rec = {}
	local realAdd, realSet = tt.AddLine, tt.SetText
	tt.AddLine = function(self, text, r, g, b, wrap) rec[#rec + 1] = { kind = "line", text = text, wrap = wrap }; return realAdd(self, text, r, g, b, wrap) end
	tt.SetText = function(self, text, r, g, b, a, wrap) rec[#rec + 1] = { kind = "title", text = text, r = r, wrap = wrap }; return realSet(self, text, r, g, b, a, wrap) end
	local function fresh() tt:Hide(); rec = {} end

	-- ---- the game wraps; BagSmith only switches wrapping on for longer lines and gives the tooltip a natural width
	check(n.TIP_SHORT == 40 and n.TIP_WIDTH == 280, "a line longer than 40 characters wraps, in a tooltip at least 280 wide")
	local long = "Items of the same quality and level range share this count. Uncommon weapons and armor count separately."
	fresh(); n.TipLine(tt, long, 0.9, 0.9, 0.9)
	check(rec[1].text == long and rec[1].wrap == true, "a long line goes to the game whole, with wrapping on (no breaks of BagSmith's own)")
	check(tt.minW == 280, "and the tooltip gets its minimum width")
	fresh()
	check(tt.minW == 0, "the width is reset when the tooltip hides, so other tooltips are untouched")
	n.TipLine(tt, "Mark as Junk")
	check(rec[1].wrap == nil and tt.minW == 0, "a short line passes through as given, and sets no width")
	local coloured = "|cffff8000" .. string.rep("ab ", 12) .. "|r"   -- 36 visible
	fresh(); n.TipLine(tt, coloured)
	check(rec[1].wrap == nil, "colour codes don't count toward the length")
	fresh(); n.TipText(tt, long)
	check(rec[1].kind == "title" and rec[1].wrap == true and rec[1].r == 1 and tt.minW == 280, "a long single-line tooltip wraps too, in white")
	fresh(); n.TipText(tt, "BagSmith", 1, 0.8, 0)
	check(rec[1].wrap == nil and rec[1].r == 1, "a short title passes through as given")

	-- ---- real tooltips: nothing broken up by BagSmith, the game told to wrap the long lines
	local DE = n.Disenchant
	DE:Show(); M.runTimers()
	local f = DE.frame
	fresh()
	local r = f.rows and f.rows[1]
	if r and r:GetScript("OnEnter") then r:GetScript("OnEnter")(r) end
	local broken, unwrapped = false, false
	for _, e in ipairs(rec) do
		if type(e.text) == "string" and e.text:find("\n") then broken = true end
		if n.TipIsLong(e.text) and e.wrap ~= true then unwrapped = true end
	end
	check(#rec > 0 and not broken and not unwrapped, "the Disenchant row tooltip: no inserted breaks, every long line wrapped by the game")

	-- ---- the count's wording and its (i)
	check(f.cur.basis:GetText() == "DE estimate, 0 of 20 in this range", "the line reads \"DE estimate, 0 of 20 in this range\" (" .. tostring(f.cur.basis:GetText()) .. ")")
	local info = f.cur.info
	check(info and info:IsShown() and info.points[1][2] == f.cur.basis and info.points[1][3] == "RIGHT", "an (i) sits right after that line")
	check(info and info.title == "Your Disenchant Results" and #(info.lines or {}) == 2, "the (i) is titled Your Disenchant Results, with two short lines")
	fresh()
	if info then info:GetScript("OnEnter")(info) end
	local texts, allWrap = {}, true
	for _, e in ipairs(rec) do texts[#texts + 1] = tostring(e.text); if e.kind == "line" and e.wrap ~= true then allWrap = false end end
	local joined = table.concat(texts, " ")
	check(joined:find("share this count", 1, true) and joined:find("weapons and armor", 1, true) and joined:find("20", 1, true), "it explains the shared count, the weapon and armor split, and the 20")
	check(allWrap and not joined:find("\n") and tt.minW == 280, "its lines are whole, wrapped by the game in a tooltip of natural width")

	-- ---- Mark as Junk: a button like its neighbours, the List view pouch as its label, its tooltip, its click, its room
	DE.current.verdict = "vendor"; DE:Paint()
	local j = f.junk
	check(j:IsShown() and j.SetClassic and j.label and tostring(j.label.text or j.label:GetText()):find("ui%-pouch%.tga"), "Mark as Junk is a text button like Skip and Exclude, with the pouch as its label")
	check(j:GetWidth() == 30 and j:GetHeight() == f.skip:GetHeight(), "30 wide, as tall as its neighbours")
	check(j.tip == "Mark as Junk" and j.tipSub == "Sell Junk will sell it at your next vendor.", "its tooltip: Mark as Junk, and what that does")
	fresh(); j:GetScript("OnEnter")(j)
	check(rec[1] and rec[1].text == "Mark as Junk" and rec[2] and rec[2].text == "Sell Junk will sell it at your next vendor.", "hovering shows both lines (text buttons now take a second line too)")
	f:SetWidth(DE.MIN_W); DE:Layout(); DE:Paint()
	local function rightOf(fr)
		local x, guard = fr:GetWidth(), 0
		while fr and fr ~= f.cur and guard < 10 do
			local p = fr.points[1]
			if p[1] == "BOTTOMLEFT" and p[2] == f.cur then return x + (p[4] or 0) end
			x = x + (p[4] or 0) + p[2]:GetWidth(); fr = p[2]; guard = guard + 1
		end
		return x
	end
	local ruleX = f.cur.rule.points[1][4]
	local jr = rightOf(j)
	check(jr + 4 <= ruleX, ("at the narrowest window the button row ends before the vertical rule (%d, rule at %d)"):format(jr, ruleX))
	n:Set("skin", "classic"); M.runTimers()
	check(j.classic and f.skip.classic, "in Classic it wears the same red button as Skip and Exclude")
	n:Set("skin", "modern"); M.runTimers()
	j:GetScript("OnClick")(j); M.runTimers()
	check(n.Junk:Marked(7001) and not j:IsShown(), "clicking it marks the item as junk, and the button goes away")
end)()
