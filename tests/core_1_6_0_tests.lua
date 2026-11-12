;(function()
	-- 1.6.0 (a player's request, via Shweep): Blackthornes Tradeskills as an alternative to Auctionator for auction
	-- prices, through its documented public API (BlackthornesTS_API: version, GetPrice(item) in copper, GetPriceAge(item)
	-- in seconds since your own scan saw it). Price Source: Automatic (whichever is installed; Auctionator when both, so
	-- nobody's numbers change on update), Auctionator, or Blackthornes Tradeskills; a chosen source that isn't installed
	-- falls back to the other. Everything that named Auctionator names the source in use.
	local function boot(opts)
		opts = opts or {}
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 2592, name = "Wool Cloth", q = 1, count = 20, class = 7, subclass = 5, price = 3 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", priceSource = opts.source } } }
		_G.Auctionator = nil; _G.BlackthornesTS_API = nil
		if opts.auctionator then
			_G.Auctionator = { API = { v1 = {
				GetAuctionPriceByItemLink = function(caller, link) return opts.auctionator[tonumber(link:match("item:(%d+)"))] end,
				GetAuctionPriceByItemID = function(caller, id) return opts.auctionator[id] end,
				GetAuctionAgeByItemLink = function() return 1 end,
				GetAuctionAgeByItemID = function() return 1 end,
			} } }
		end
		if opts.bts then
			_G.BlackthornesTS_API = { version = opts.btsVersion or 1,
				GetPrice = opts.btsPrice or function(item) local id = type(item) == "number" and item or tonumber(tostring(item):match("item:(%d+)")); return opts.bts[id] end,
				GetPriceAge = function(item) return opts.btsAge end,
			}
		end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		return n, M
	end
	local wool = { itemID = 2592, link = "|cffffffff|Hitem:2592::::::::1:::::::|h[Wool Cloth]|h|r", count = 20 }

	-- ---- neither installed
	local n, M = boot()
	check(not n.AH:Available() and n.AH:Source() == nil and n.AH:Price(wool) == nil, "neither installed: no prices, no source")
	check(n.AH.INSTALL_HINT:find("Auctionator", 1, true) and n.AH.INSTALL_HINT:find("Blackthornes Tradeskills", 1, true), "the install hint names both")
	check(n.db.priceSource == "auto", "Price Source defaults to Automatic")

	-- ---- Auctionator only: as before
	n, M = boot({ auctionator = { [2592] = 40 } })
	check(n.AH:Source() == "auctionator" and n.AH:SourceName() == "Auctionator" and n.AH:Price(wool) == 40 and n.AH:StackValue(wool) == 800, "Auctionator only: its prices, as before")
	check(n.AH:NoPriceText("Wool Cloth"):find("Auctionator has no price for Wool Cloth yet", 1, true), "its no-price hint names it")

	-- ---- Blackthornes only
	n, M = boot({ bts = { [2592] = 55 }, btsAge = 2 * 86400 + 600 })
	check(n.AH:Source() == "blackthornes" and n.AH:SourceName() == "Blackthornes Tradeskills" and n.AH:Price(wool) == 55, "Blackthornes only: its prices, automatically")
	check(n.AH:Price({ itemID = 2592 }) == 55 and n.AH:Price({ itemID = 2592, link = "item:2592" }) == 55, "by item ID, and by the short links the Disenchant Helper uses for materials")
	check(n.AH:Age(wool) == 2, "its age (seconds since your own scan) becomes days, like Auctionator's")
	check(n.AH:NoPriceText("Wool Cloth"):find("Blackthornes Tradeskills has no price for Wool Cloth yet", 1, true) and n.AH:NoPriceText("x"):find("/bts scan", 1, true), "its no-price hint names it and how to scan")
	n, M = boot({ bts = { [2592] = 55 }, btsAge = 25 * 86400 })
	check(n.AH:Age(wool) == nil, "over 21 days counts as not seen, as with Auctionator")
	n, M = boot({ bts = { [2592] = 55 }, btsAge = nil })
	check(n.AH:Price(wool) == 55 and n.AH:Age(wool) == nil, "a price from guild data or another addon has no age: priced, age blank")

	-- ---- both installed
	n, M = boot({ auctionator = { [2592] = 40 }, bts = { [2592] = 55 } })
	check(n.AH:Source() == "auctionator" and n.AH:Price(wool) == 40, "both installed, Automatic: Auctionator, so nobody's numbers change on update")
	local refreshed = 0
	local realRefresh = n.RefreshViews
	n.RefreshViews = function(self, ...) refreshed = refreshed + 1; return realRefresh(self, ...) end
	n:Set("priceSource", "blackthornes"); M.runTimers()
	check(n.AH:Source() == "blackthornes" and n.AH:Price(wool) == 55, "choosing Blackthornes Tradeskills uses its prices")
	check(refreshed > 0, "and the windows repaint with them")
	n:Set("priceSource", "auctionator"); M.runTimers()
	check(n.AH:Price(wool) == 40, "and back to Auctionator")
	-- the helpers follow the chosen source
	n:Set("priceSource", "blackthornes"); M.runTimers()
	local DE = n.Disenchant
	check(DE.NoPriceTip("Wool Cloth"):find("Blackthornes Tradeskills", 1, true), "the Disenchant Helper's no-price tip names the source in use")
	check(DE.NO_AUCTIONATOR:find("Blackthornes Tradeskills", 1, true), "its install note names both")

	-- ---- a chosen source that isn't installed falls back to the other
	n, M = boot({ auctionator = { [2592] = 40 }, source = "blackthornes" })
	check(n.AH:Source() == "auctionator" and n.AH:Price(wool) == 40, "Blackthornes chosen but not installed: Auctionator, rather than no prices")

	-- ---- a source that misbehaves never breaks BagSmith
	n, M = boot({ bts = {}, btsPrice = function() error("boom") end })
	local ok, v = pcall(n.AH.Price, n.AH, wool)
	check(ok and v == nil, "a price call that errors gives no price, quietly")
	n, M = boot({ bts = {}, btsPrice = function() return 0 end })
	check(n.AH:Price(wool) == nil, "a zero price counts as none")
	n, M = boot({ bts = {}, btsPrice = function() return -5 end })
	check(n.AH:Price(wool) == nil, "a negative price counts as none")
	n, M = boot({ bts = { [2592] = 55 }, btsVersion = 0 })
	check(not n.AH:Available(), "an API without a version isn't used")

	-- ---- the setting, its validation, its row
	n, M = boot({ source = "tsm" })
	check(n.db.priceSource == "auto", "a saved value that isn't a source becomes Automatic")
	n, M = boot({ auctionator = { [2592] = 40 }, bts = { [2592] = 55 } })
	local P = n.SettingsPanel
	P:Show(); M.runTimers(); P:ShowPage("general"); M.runTimers()
	local seg
	for _, w in ipairs(P.pools.seg or {}) do if w:IsShown() and w.key == "priceSource" then seg = w end end
	check(seg ~= nil, "(beta2) the General page has the Price Source row")
	check(seg and seg.help and tostring(seg.help.text):find("Auctionator", 1, true), "its help line says which source is in use")

	-- ---- the TOC loads both before BagSmith
	local toc = io.open("BagSmith/BagSmith.toc"):read("*a")
	local deps = toc:match("## OptionalDeps:%s*([^\r\n]+)") or ""
	check(deps:find("Auctionator", 1, true) and deps:find("Blackthornes_TS", 1, true), "both are optional dependencies, so they load first (" .. deps .. ")")
	P:ShowPage("columns"); M.runTimers()
	local onColumns = false
	for _, w in ipairs(P.pools.seg or {}) do if w:IsShown() and w.key == "priceSource" then onColumns = true end end
	check(not onColumns, "(beta2) and no longer on the Columns page")

	-- ======== beta2 ========
	-- ---- Quest Starter: a locked corner mark for items that begin a quest you haven't accepted
	local quests = {}
	local function bootQ(prof)
		package.loaded.mock = nil
		local M2 = require("mock")
		M2.put(0, 1, { id = 3000, name = "Torn Note", q = 1, count = 1, class = 12, subclass = 0, price = 0 })
		M2.put(0, 2, { id = 3001, name = "Bloody Tusk", q = 1, count = 1, class = 12, subclass = 0, price = 0 })
		M2.put(0, 3, { id = 3002, name = "Quest Hide", q = 1, count = 1, class = 12, subclass = 0, price = 0 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		local pr = { skin = "modern", view = "icons" }
		for k, v in pairs(prof or {}) do pr[k] = v end
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = pr } }
		_G.Auctionator = nil; _G.BlackthornesTS_API = nil
		local n2 = M2.loadAddon("BagSmith")
		C_Container.GetContainerItemQuestInfo = function(bag, slot) return quests[slot] or { isQuestItem = false } end
		M2.fire("ADDON_LOADED", "BagSmith"); M2.fire("PLAYER_ENTERING_WORLD"); M2.runTimers(); M2.runTimers()
		return n2, M2
	end
	quests = { [1] = { questID = 101, isActive = false }, [2] = { questID = 102, isActive = true }, [3] = { isQuestItem = true } }
	local n2, M2 = bootQ()
	local C = n2.Corners
	local byId = {}
	for _, rec in ipairs(n2.items) do byId[rec.itemID] = rec end
	check(byId[3000].questStart and not byId[3001].questStart and not byId[3002].questStart, "the scanner marks a quest starter you haven't accepted, not an accepted one, not a plain quest item")
	check(n2.db.iconCorners.top_left[1] == "quest_start" and n2.db.iconCorners.top_left[2] == "junk", "Quest Starter sits first in the top left by default, ahead of the junk coin")
	n2.Window:Show(); M2.runTimers(); M2.runTimers()
	local V2 = n2.Window.main
	local function btn(id) for _, b in ipairs(V2.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then return b end end end
	local b1, b2, b3 = btn(3000), btn(3001), btn(3002)
	if b1 then C:Apply(b1, true) end; if b2 then C:Apply(b2, true) end; if b3 then C:Apply(b3, true) end
	check(b1 and b1.questMark and b1.questMark:IsShown(), "the starter's icon wears the mark")
	check(b1 and b1.questMark and b1.questMark.texture == C.QUEST_ART, "the game's yellow quest mark")
	check(not (b2 and b2.questMark and b2.questMark:IsShown()) and not (b3 and b3.questMark and b3.questMark:IsShown()), "an accepted quest's item and a plain quest item don't")
	check(C:IsLocked("quest_start") and C:IsLocked("quantity"), "it's locked, like the stack count")
	C:Remove("quest_start")
	check(C:CornerOf("quest_start") == "top_left", "it can't be hidden")
	C:Move("junk", -1)
	check(n2.db.iconCorners.top_left[1] == "quest_start", "nothing moves above it")
	C:PlaceAt("quest_start", "bottom_left")
	check(n2.db.iconCorners.bottom_left[1] == "quest_start" and not n2.IndexOf(n2.db.iconCorners.top_left, "quest_start"), "it can move to another corner, first there")
	C:PlaceAt("quest_start", "bottom_right")
	check(n2.db.iconCorners.bottom_right[1] == "quest_start" and n2.db.iconCorners.bottom_right[2] == "quantity", "sharing a corner with the stack count, both stay ahead of everything else")
	check(C:PreviewWinner("bottom_right", "cell") == "quest_start", "the Icon Corners preview shows it, so you can see it without a quest item")
	-- an existing profile, saved before 1.6.0, gets it
	n2, M2 = bootQ({ iconCorners = { top_left = { "junk" }, top_right = { "item_level" }, bottom_left = { "pawn", "equipment_set" }, bottom_right = { "quantity" } } })
	check(n2.db.iconCorners.top_left[1] == "quest_start" and n2.db.iconCorners.top_left[2] == "junk", "a profile saved before 1.6.0 gets it in the top left on load")
	local said = {}
	local realPrint = n2.Print
	n2.Print = function(self, fmt, ...) said[#said + 1] = tostring(fmt):format(...); return realPrint(self, fmt, ...) end
	SlashCmdList.BAGSMITH("quest")
	check(said[#said] and said[#said]:find("begin a quest", 1, true) and said[#said]:find("Torn Note", 1, true), "/bs quest lists the starters in your bags (" .. tostring(said[#said]) .. ")")

	-- ---- refused corner registrations say why, once
	said = {}
	local fn = function() return true end
	local api = n2.API or (BagSmith and BagSmith.API)
	check(api.RegisterCornerWidget("Bad", "bad id!", fn, fn) == false, "(setup) an id with a space is refused")
	check(#said == 1 and said[1]:find("couldn't be added to Icon Corners", 1, true), "and chat says why (" .. tostring(said[1]) .. ")")
	api.RegisterCornerWidget("Bad", "bad id!", fn, fn)
	check(#said == 1, "only once a session")
	check(api.RegisterCornerWidget("Mine", "mine.mark", fn, fn) == true and api.RegisterCornerWidget("Mine", "mine.mark", fn, fn) == false, "(setup) a second mark with the same id is refused")
	check(said[#said]:find("already registered", 1, true), "and says so")

	-- ---- Background Opacity and Fade While Moving: independent
	n, M = boot()
	local V = n.Window.main
	n.Window:Show(); M.runTimers(); M.runTimers()
	local skin = n.Skins:Current()
	n:Set("bgOpacity", 0.5); M.runTimers()
	check(V.frame.bgColor and math.abs(V.frame.bgColor[4] - (skin.bg[4] or 1) * 0.5) < 0.001, "Background Opacity fades the window's backdrop (" .. tostring(V.frame.bgColor and V.frame.bgColor[4]) .. ")")
	check(V.frame:GetAlpha() == 1, "but not the window itself: items and text stay solid")
	local hover = {}
	_G.MouseIsOver = function(f) return hover[f] end
	M.fire("PLAYER_STARTED_MOVING"); M.runTimers()
	check(V.frame:GetAlpha() == 1, "Fade While Moving is off by default: moving changes nothing")
	n:Set("fadeMoving", true); M.runTimers()
	check(V.frame:GetAlpha() == 0.5, "on, the window dims to Opacity While Moving while you move")
	hover[V.frame] = true; n:ApplyCombatFade(false)
	check(V.frame:GetAlpha() == 0.5, "(beta3) pointing at it doesn't matter: it stays dim until you stop")
	hover[V.frame] = nil; n:ApplyCombatFade(false)
	n:Set("movingAlpha", 0.3); M.runTimers()
	check(V.frame:GetAlpha() == 0.3, "Opacity While Moving sets how far")
	check(math.abs(V.frame.bgColor[4] - (skin.bg[4] or 1) * 0.5) < 0.001, "Background Opacity is untouched by moving: they're independent")
	M.combat = true; M.fire("PLAYER_REGEN_DISABLED"); M.runTimers()
	check(V.frame:GetAlpha() == n.db.combatAlpha, "in combat the combat fade wins")
	M.combat = false; M.fire("PLAYER_REGEN_ENABLED"); M.runTimers()
	local lw = n.MakeRoom:NeverWindow(); lw:Show()
	n:ApplyCombatFade(false)
	check(lw:GetAlpha() == 1 and V.frame:GetAlpha() == 0.3, "only the bag windows fade while moving, not the helper windows")
	M.fire("PLAYER_STOPPED_MOVING"); M.runTimers()
	check(V.frame:GetAlpha() == 1, "stopping brings it back")
	_G.MouseIsOver = nil
	-- (beta3) Whole Window: the whole bag window follows Background Opacity, and no fade makes it brighter than that
	n:Set("bgWhole", true); M.runTimers()
	check(V.frame:GetAlpha() == 0.5, "Whole Window: the whole bag window takes Background Opacity")
	check(V.frame.bgColor and math.abs(V.frame.bgColor[4] - (skin.bg[4] or 1)) < 0.001, "and its frame isn't faded twice")
	check(lw:GetAlpha() == 1, "helper windows aren't part of it")
	M.fire("PLAYER_STARTED_MOVING"); M.runTimers()
	check(V.frame:GetAlpha() == 0.3, "moving dims it further, to Opacity While Moving")
	n:Set("movingAlpha", 0.8); M.runTimers()
	check(V.frame:GetAlpha() == 0.5, "but never makes it brighter than Background Opacity")
	M.combat = true; M.fire("PLAYER_REGEN_DISABLED"); M.runTimers()
	check(V.frame:GetAlpha() == n.db.combatAlpha and lw:GetAlpha() == n.db.combatAlpha, "combat: every window at the combat opacity (lower than the window's own)")
	M.combat = false; M.fire("PLAYER_REGEN_ENABLED"); M.fire("PLAYER_STOPPED_MOVING"); M.runTimers()
	n:Set("bgWhole", false); M.runTimers()
	check(V.frame:GetAlpha() == 1 and math.abs(V.frame.bgColor[4] - (skin.bg[4] or 1) * 0.5) < 0.001, "Whole Window off: back to the frame only")
	-- (beta3) Classic: BagSmith's own background layers fade too (only the game frame's pieces underneath did)
	n, M = boot()
	n:Set("skin", "classic"); M.runTimers(); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	V = n.Window.main
	n:Set("bgOpacity", 0.4); M.runTimers()
	local layers, faded = 0, 0
	-- each from its own designed opacity (the corner filigree is drawn at 40%)
	local function scaled(r) return math.abs((r:GetAlpha() or 1) - (r.bsBaseAlpha or 1) * 0.4) < 0.001 end
	for _, k in ipairs({ "classicStone", "classicTile", "classicShade" }) do local r = V[k]; if r then layers = layers + 1; if scaled(r) then faded = faded + 1 end end end
	for _, r in ipairs(V.classicCorners or {}) do layers = layers + 1; if scaled(r) then faded = faded + 1 end end
	check(layers > 0 and faded == layers, ("Classic: BagSmith's stone, shade and corner art fade with Background Opacity, each from its own opacity (%d of %d)"):format(faded, layers))
	local corner = (V.classicCorners or {})[1]
	check(not corner or math.abs((corner.bsBaseAlpha or 0) - 0.4) < 0.001, "the corner filigree's designed 40% is what it scales from")
	n:Set("bgOpacity", 1); M.runTimers()
	check(not corner or math.abs(corner:GetAlpha() - 0.4) < 0.001, "back at 100%, the window looks exactly as before")
	check(V.frame:GetAlpha() == 1, "and the window itself stays solid")

	-- ---- Show Help Tips
	n, M = boot()
	n.Window:Show(); M.runTimers()
	V = n.Window.main
	local function hoverShows(fr) GameTooltip.shown = false; GameTooltip.owner = nil; local f = fr:GetScript("OnEnter"); if f then f(fr) end; return GameTooltip.shown and GameTooltip.owner == fr end
	check(hoverShows(V.btnClean), "(setup) a button's tip shows")
	n:Set("helpTips", false); M.runTimers()
	check(n.TooltipsOK() and not n.HelpTipsOK(), "off: control tips are off, other tooltips aren't")
	check(not hoverShows(V.btnClean) and not hoverShows(V.btnMerge), "off: buttons show no tips")
	local info = n.Why.InfoButton(V.frame); info.title = "T"; info.lines = { "L" }
	check(hoverShows(info), "the (i) icons still explain")
	n:Set("helpTips", true); M.runTimers()
	check(hoverShows(V.btnClean), "on again: tips are back")

	-- ---- What's New 1.6
	local WN = n.WhatsNew
	-- (1.7.0-beta6, by design) the 1.7 card leads now; 1.6's is second
	local e = WN.ENTRIES[2]
	local text = table.concat(e.items, " ")
	-- (beta4, by design) a fifth bullet: Narrower Windows
	-- (1.6.0-beta10, by design: Shweep) a sixth bullet, Smarter Disenchant Advice
	check(e.v == "1.6.0" and e.heading == "BagSmith 1.6" and #e.items == 6, "the 1.6 card, with six bullets")
	check(text:find("Narrower Windows:", 1, true) and text:find("440 pixels", 1, true), "and the fifth is Narrower Windows")
	check(text:find("Blackthornes", 1, true) and text:find("Quest Starters", 1, true) and text:find("Fade While Moving", 1, true) and text:find("Show Help Tips", 1, true), "Blackthornes prices, Quest Starters, opacity, help tips")
	check(not text:find("\226\128\148"), "no em dashes")
	check(WN.ENTRIES[1].v == "1.7.0" and WN.ENTRIES[3].v == "1.5.1", "after the 1.7 card, and 1.5.1's follows")

	-- ---- Icon Corners: marks other addons draw themselves (beta3: on its own line, with weight)
	local P2 = n.SettingsPanel
	P2:Show(); M.runTimers(); P2:ShowPage("icons"); M.runTimers()
	local warn
	for _, w in ipairs(P2.pools.text or {}) do if w:IsShown() and tostring(w.text.text or ""):find("can cover the marks you set above", 1, true) then warn = w end end
	check(warn and warn.emphasis == "heading", "a line in the heading colour says some addons draw their own marks, which can cover yours and are changed in that addon")

	-- ---- (beta3) the Opacity card: three parts, plain names
	P2:ShowPage("window"); M.runTimers()
	local subs = {}
	for _, w in ipairs(P2.pools.sub or {}) do if w:IsShown() then subs[#subs + 1] = { y = -(w.points[1][5] or 0), t = w.label } end end
	table.sort(subs, function(a, b) return a.y < b.y end)
	local names = {}
	for _, x in ipairs(subs) do names[#names + 1] = x.t end
	check(table.concat(names, " | ") == "Always | While Moving | In Combat", "the Opacity card has three parts: Always, While Moving, In Combat (" .. table.concat(names, " | ") .. ")")
	local labels = {}
	for _, w in ipairs(P2.pools.check or {}) do if w:IsShown() and w.key then labels[w.key] = w.text.text end end
	check(labels.bgWhole == "Whole Window" and labels.combatFade == "Fade in Combat" and labels.fadeMoving == "Fade While Moving", "Whole Window under Background Opacity; Fade in Combat; Fade While Moving")
	P2:Hide()
end)()
