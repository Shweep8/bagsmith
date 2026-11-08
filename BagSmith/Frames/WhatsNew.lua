--[[
	BagSmith - Frames/WhatsNew.lua

	A small "What's New" card for notable releases. Shown once per notable
	version, the first time the bags open after updating (never at login,
	never in combat, never on a first install), beside the bags window.
	"Got It" or the close button marks it seen. Remembered per account, so
	alts don't see it again. Reopen any time from the "What's New" button at
	the bottom left of Settings, or /bs new. Bug-fix releases add no entry,
	so nothing appears for them.

	The card has a tab for each of the last five notable releases, newest
	first, opening on the newest (after an update, on that update). It's
	sized to the tallest of them, so switching tabs doesn't jump.

	Testing (hidden, not in /bs help): "/bs new reset" makes the next bag open
	behave as the first after updating; "/bs new reset skipped" goes back
	far enough that all tabbed releases count as unseen.
--]]
local ADDON, ns = ...
local WN = {}
ns.WhatsNew = WN

-- Newest first. Only notable releases get an entry; keep a handful of short
-- bullets that say what it is and where to turn it on.
WN.ENTRIES = {
	{ v = "1.5.1", heading = "BagSmith 1.5.1", items = {
		"|cfffac775Faster Destroying:|r when the Loot Helper helps you make room, choosing an item and pressing Destroy now removes it right away. Blue and epic items, and anything whose quality the game hasn't shown yet, still ask first, just like the game does. Junk is still one click.",
		"|cfffac775Your Choice:|r prefer to be asked every time? Turn on Ask Before Destroying in Settings > Automations & Actions > Loot Helper. Want blue and epic items gone at once too? Untick Always Ask for Rare or Better.",
		"|cfffac775Smoother Looting:|r after you make room, the Loot Helper takes one item at a time and waits for each to land in your bags, so it no longer runs into \"your bags are full\". Loot with no price gets suggestions too.",
	} },
	{ v = "1.5.0", heading = "BagSmith 1.5", items = {
		"|cfffac775Icon Corners:|r you choose what shows in each corner of your item icons. Pick a mark for each corner, and add a backup for items the first one doesn't apply to, so marks never pile on top of each other. It's all in Settings > Item Icons, a new page with everything about item icons.",
		"|cfffac775Marks from Other Addons:|r addons can now add their own marks to BagSmith's icons, the same way many already do for other bag addons. When one does, its mark shows up in a corner on its own, and you can move it like the rest.",
		"|cfffac775Split Consumables:|r want your drinks apart from your food, or potions in their own section? Turn on Split Consumables by Type (Settings > Sections) and Consumables becomes Food, Drink, Potions and more. Untick any you'd rather keep together. Searching “drink” or “potion” finds just those, too.",
	} },
	{ v = "1.4.0", heading = "BagSmith 1.4", items = {
		"|cfffac775Sort: Off:|r want your items exactly where you put them? Set Sort to Off and the window shows them in bag order, slot by slot, with the empty slots right where they are. It's on the Sort button and under Sorting & Filters.",
		"|cfffac775Pinned Sections:|r right-click a section's title and choose Pin to Top. It stays at the top, just under Recent, and in All view its items get their own section there. Drop an item on All Items to take it back out. You can also pin from Settings > Sections.",
		"|cfffac775Drop into a Free Slot:|r split a stack while you're in By Section or List view and drop it on the list: it goes to a free slot instead of back onto its stack.",
		"|cfffac775By Section:|r the By Type grouping has a clearer name, since it groups by all your sections, custom ones included.",
	} },
	{ v = "1.3.0", heading = "BagSmith 1.3", items = {
		"|cfffac775Loot Helper:|r a cleaner, calmer Loot Helper. What's waiting to loot comes first, with what it's worth and its own Skip and Exclude. Ways to free a slot without losing anything are listed before anything you'd let go; pick a row and one button does it. It even tells you when something you're picking up is worth less than what you'd give up for it.",
		"|cfffac775Why Things Are Left Out:|r when BagSmith keeps items out of a helper (favorites, gear sets, quest items, Pawn upgrades), it now says how many and why. Hover the small info icon for the list.",
		"|cfffac775Exclusion Lists:|r Never is now Exclude, and the lists are your DE Exclusion List and Loot Exclusion List, each under its helper's settings.",
		"|cfffac775Classic Style:|r the search bar and everything below it now start under the portrait, so the list gets more room.",
	} },
	{ v = "1.2.0", heading = "BagSmith 1.2", items = {
		"|cfffac775Disenchant Helper:|r enchanters, this one's for you. A new window lists the gear in your bags worth disenchanting, shows what it sells for, what it's worth on the AH, and what its materials should bring, and tells you which is the better call. Then it walks you through the pile one click at a time (or one press of a keybinding). Skip what you want to keep, Exclude for things it should stop asking about, and it learns from your own results as you go. Find it beside the Gear Sets shield once it's on, or say yes when BagSmith offers it to a character with Enchanting.",
		"|cfffac775Fewer Yes/No Boxes:|r tired of confirming every bind-on-equip piece you put on? BagSmith can click Yes for you on the kinds of box you choose, only after your own BagSmith actions unless you widen it, with a key to hold if you'd rather be asked. Off by default, under Automations & Actions.",
		"|cfffac775Mail and Trade:|r right-click a merged stack at the mailbox or in a trade window and the rest of its stacks follow, the way they already did at the bank.",
		"|cfffac775Settings:|r the Loot Helper and the Disenchant Helper have their own pages under Automations & Actions.",
	} },
	{ v = "1.1.0", heading = "BagSmith 1.1", items = {
		"|cfffac775Item Level on Icons:|r want to see gear levels at a glance? Turn on Show Item Level (ilvl) on Icons in Settings > Style > Items. Weapons and armor will show their item level in the corner of their icon, in a color you choose, so it's easy to tell apart from a stack count.",
		"|cfffac775List View:|r the iLvl column only shows a number for weapons and armor now. Everything else gets a dash. The Req column is now called Req lvl.",
		"|cfffac775Classic Style:|r all the windows and pop-ups use the same frame and background now, so everything matches. Pop-ups can be dragged by their title bar, scrollbars have their up and down arrows back, and a few small things line up better.",
		"|cfffac775Smoother Scrolling:|r the mouse wheel and the scrollbar arrows now scroll the bag window the right amount, every time.",
		"|cfffac775Pawn Arrow:|r the Pawn upgrade arrow has its own corner of the icon now, so it won't cover an item level or a gear set badge.",
	} },
	{ v = "1.0.0", heading = "BagSmith 1.0", items = {
		"|cfffac775Thank you:|r to everyone who has been using and loving BagSmith through every beta, this one's for you. BagSmith 1.0 is the first full release. Come say hello on our new Discord: the link is in Settings > About & Support.",
		"|cfffac775Plugins:|r BagSmith can now grow with optional plugins, separate add-ons that build on it without changing your everyday bags. Settings > Plugins shows what you have and lets you switch plugins on or off. Use none, and nothing changes.",
		"|cfffac775Coming soon, BagSmith Gamepad Plugin:|r browse your bags from a gamepad or controller, friendly and easy to use, just like with a keyboard and mouse. It's in alpha testing right now; when it reaches beta we'll be looking for testers, so if that's you, join the Discord.",
	} },
	{ v = "0.15.0", heading = "BagSmith 0.15", items = {
		"|cfffac775Gear Sets:|r each of your equipment sets (from the game's Equipment Manager) gets its own section, with an Equip button on its title. Settings > Dynamic Sections.",
		"|cfffac775Gear Sets Tab:|r every set slot by slot, including pieces you're wearing or keeping in the bank. Open it from the tabs, or the shield at the top right.",
		"|cfffac775Shared Pieces:|r an item in more than one set shows in each, with a small shield and the number of sets.",
		"|cfffac775Set Items Are Safe:|r they can't be marked as junk, and BagSmith never sells them or offers them in the Loot Helper.",
		"|cfffac775Recent Items:|r now only what you actually got: loot, vendors, mail, trades, quest rewards and crafting. Gear you take off and items from the bank no longer count.",
		"|cfffac775Settings Search:|r type in the box at the top of Settings to find any setting.",
		"|cfffac775Tidier Settings:|r Sections, Columns and Sheets each open into their own pages, with separate pages for your bags and your bank.",
	} },
	{ v = "0.14.0", heading = "BagSmith 0.14", items = {
		"|cfffac775Custom Sections:|r make your own sections, like Professions or Raid Night, and put any item where you want it. Drag an item onto a section title, or use the item menu. Settings > Custom Sections.",
		"|cfffac775Item Menu:|r Alt+Left-click any item, or click the three dots at the left of a row, for Move to Section, Favorite, Mark as Junk and Track as Currency in one place.",
		"|cfffac775Hide Sections at Vendors and the AH:|r keep Favorites or any section out of sight while you sell. Right-click a section title, or Settings > Sections.",
		"|cfffac775Move Every Stack at Once:|r with Merge Stacks on, right-click a merged row at the bank and all of its stacks move together.",
		"|cfffac775Search Finds Sections Too:|r type a section's name to see everything in it.",
		"|cfffac775Classic Skin Polish:|r solid, Blizzard-style dialog windows and menus.",
		"|cfffac775A Tidier Settings:|r every page is organized into cards, with a light line between settings, so it's easier to skim.",
		"|cfffac775Join the Discord:|r BagSmith has a Discord now. Come say hello, share ideas or report a bug. Links are in Settings > About & Support.",
	} },
	{ v = "0.13.0", heading = "BagSmith 0.13", items = {
		"|cfffac775Bag Bar:|r gain access to your Bag Bar from within BagSmith. A new button beside the bag counts in the bottom right brings it up. You can also hide Blizzard's Bag Bar in Settings > General.",
		"|cfffac775Sell Junk + Mark as Junk:|r mark any item as junk in the new Junk column (or with a keybinding) and it sells along with your greys. You can also sell junk automatically at vendors: Settings > Automations & Actions.",
		"|cfffac775Loot Helper:|r when your bags are too full for loot or a quest reward, it suggests what to combine, clean up or destroy, then finishes the looting for you. Settings > Automations & Actions.",
		"|cfffac775Favorites and Track as Currency:|r star items to pin them in a Favorites section at the top, and use the wallet column (or Add Item in the currency drawer) to track any item as a currency.",
		"|cfffac775Profile Sharing:|r copy your profile as a code to keep or share, or import someone else's. Settings > Profile.",
		"|cfffac775Keybindings:|r BagSmith has its own section in the game's Keybindings, plus Settings > Keybindings for Mark as Junk, Favorite Item and the rest.",
		"|cfffac775Pawn Support:|r with Pawn installed and its bag upgrade advisor on, Pawn's green upgrade arrows show on your items in BagSmith.",
	} },
	{ v = "0.12.0", heading = "BagSmith 0.12", items = {
		"|cfffac775Travel Mode:|r a compact, on-the-go view for when you're out adventuring. Click the signpost next to the close button and the toolbar and filters tuck away, leaving your items and search. Click it again anytime to get your full inventory tools back.",
		"|cfffac775Auto Travel Mode:|r if you want, Travel Mode can switch off on its own when it's time to manage your bags (at the bank, the auction house or a vendor, or while you're on a flight path) and back on when you're done. Choose which in Settings > Automations & Actions.",
	} },
	{ v = "0.11.0", heading = "BagSmith 0.11", items = {
		"|cfffac775Recent Items:|r what you picked up since logging in, at the top of your bags (also kept in their usual sections). On by default; Settings > Dynamic Sections.",
		"|cfffac775Icon Split View:|r in icon view, sections can sit side by side. Settings > Style.",
		"|cfffac775AH Prices:|r with Auctionator installed, add an AH Price column in Settings > Bag Columns.",
		"|cfffac775Sheets Remember Their View:|r each tab can keep its own sections, sort and view. Settings > Sheets.",
	} },
}
WN.MAX_SHOWN = 5   -- releases with a tab (five fit on one row in both skins)
WN.URL = "https://www.curseforge.com/wow/addons/bagsmith/files/all"
local WIDTH, PAD, LOGO = 440, 16, 32   -- 440 since 0.14: bullets wrap less, the card is shorter

-- "0.11.0-beta2" -> { 0, 11, 0 }; a beta counts as its release.
local function parse(v)
	local a, b, c = tostring(v or ""):match("^(%d+)%.(%d+)%.?(%d*)")
	if not a then return { 0, 0, 0 } end
	return { tonumber(a), tonumber(b), tonumber(c) or 0 }
end
local function newer(x, y)   -- is x newer than y
	local p, q = parse(x), parse(y)
	for i = 1, 3 do if p[i] ~= q[i] then return p[i] > q[i] end end
	return false
end
WN.Newer = newer
local function base(v) local p = parse(v); return ("%d.%d.%d"):format(p[1], p[2], p[3]) end

-- Entries not seen yet (newer than seen, up to the running version).
function WN:Unseen()
	local seen, current = BagSmithDB.whatsNewSeen or "0.0.0", ns.version
	local out = {}
	for _, e in ipairs(self.ENTRIES) do
		if newer(e.v, seen) and not newer(e.v, current) then out[#out + 1] = e end
	end
	return out
end
-- The latest entries for the running version, for reopening.
function WN:Latest()
	local out = {}
	for _, e in ipairs(self.ENTRIES) do if not newer(e.v, ns.version) then out[#out + 1] = e end end
	return out
end
function WN:Pending()
	return ns.db and ns.db.whatsNew ~= false and #self:Unseen() > 0
end
function WN:MarkSeen() BagSmithDB.whatsNewSeen = base(ns.version) end

------------------------------------------------------------------------
-- The card: created once, reused.
------------------------------------------------------------------------
local card
local function create()
	if card then return card end
	local f = CreateFrame("Frame", "BagSmithWhatsNew", UIParent, "BackdropTemplate")
	f:SetSize(WIDTH, 200)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	-- The white BagSmith mark beside the title (Modern; Classic shows the portrait).
	f.logo = f:CreateTexture(nil, "ARTWORK")
	f.logo:SetSize(LOGO, LOGO)
	f.logo:SetTexture("Interface\\AddOns\\BagSmith\\Media\\mark128.tga")
	f.logo:SetPoint("TOPLEFT", PAD, -PAD)
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	f.title:SetPoint("LEFT", f.logo, "RIGHT", 10, 0); f.title:SetPoint("RIGHT", f, "RIGHT", -36, 0); f.title:SetJustifyH("LEFT")
	f.close = ns.IconButton(f, "Interface\\AddOns\\BagSmith\\Media\\ui-close.tga", "Close", function() WN:Close() end)
	f.close:SetSize(22, 22); f.close:SetPoint("TOPRIGHT", -8, -8)
	f.lines = {}
	-- A line under the title saying what the card is.
	f.intro = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.intro:SetJustifyH("LEFT"); f.intro:SetWordWrap(true)
	-- The body (version headings and bullets) scrolls inside the card only if
	-- the card would be taller than the screen (a big UI scale or font).
	f.body = CreateFrame("ScrollFrame", nil, f)
	f.content = CreateFrame("Frame", nil, f.body)
	f.content:SetSize(WIDTH, 10)
	f.body:SetScrollChild(f.content)
	f.body:EnableMouseWheel(true)
	f.body:SetScript("OnMouseWheel", function(sf, delta)
		local max = math.max(0, (f.contentH or 0) - (f.bodyH or 0))
		sf:SetVerticalScroll(math.min(max, math.max(0, (sf:GetVerticalScroll() or 0) - delta * 30)))
	end)
	f.dashes, f.dividers = {}, {}
	f.more = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.more:SetJustifyH("LEFT"); f.more:SetWordWrap(true)
	-- A stronger line above the footer (the way to older updates).
	f.footLine = f:CreateTexture(nil, "ARTWORK"); f.footLine:SetTexture("Interface\\Buttons\\WHITE8X8"); f.footLine:SetHeight(2)
	f.tabs, f.seps = {}, {}
	-- The address: shown as one line of text, shortened with "..." if it
	-- doesn't fit (any scale or font), with a copy button beside it. Addons
	-- can't write to the clipboard, so copying swaps in an edit box with the
	-- whole address selected and says to press Ctrl+C (Cmd+C on a Mac); when
	-- that key is pressed it says "Copied!" and returns to the short view.
	local fieldW = WIDTH - PAD * 2 - 30 - 28   -- room for the copy and Discord buttons
	f.field = CreateFrame("Button", nil, f, "BackdropTemplate")
	f.field:SetSize(fieldW, 22)
	f.fieldText = f.field:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.fieldText:SetPoint("LEFT", 6, 0); f.fieldText:SetPoint("RIGHT", -6, 0)
	f.fieldText:SetJustifyH("LEFT"); f.fieldText:SetWordWrap(false)
	f.field:SetScript("OnClick", function() WN:StartCopy() end)
	f.field:SetScript("OnEnter", function(b)
		if ns.TooltipsOK() then GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText(WN.URL, 1, 1, 1); GameTooltip:AddLine("Click to copy", 0.6, 0.6, 0.6); GameTooltip:Show() end
	end)
	f.field:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.copy = ns.IconButton(f, "Interface\\AddOns\\BagSmith\\Media\\ui-copy.tga", "Copy the address", function() WN:StartCopy() end)
	f.copy:SetSize(22, 22)
	-- The Discord: an icon (the address shows, ready to copy, like the About page's).
	f.discord = ns.IconButton(f, "Interface\\AddOns\\BagSmith\\Media\\ui-discord.tga", "Join the BagSmith Discord", function()
		local L = ns.SettingsPanel and ns.SettingsPanel.LINKS and ns.SettingsPanel.LINKS.discord
		ns.ShowLink("Discord", L and L.url or "https://discord.gg/uYfcHPkcar")
	end)
	f.discord:SetSize(22, 22)
	if f.discord.icon and f.discord.icon.SetVertexColor then f.discord.icon:SetVertexColor(1, 1, 1) end
	f.copyHint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.copyHint:SetJustifyH("LEFT")
	f.copyHint:Hide()
	f.url = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	f.url:SetSize(fieldW - 6, 20); f.url:SetAutoFocus(false)
	f.url:Hide()
	-- Read only: always shows the address, selected for copying.
	f.url:SetScript("OnTextChanged", function(box) if box:GetText() ~= WN.URL then box:SetText(WN.URL) end end)
	f.url:SetScript("OnEditFocusGained", function(box) box:HighlightText() end)
	f.url:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
	f.url:SetScript("OnEditFocusLost", function() if not f.copied then WN:EndCopy() end end)
	-- Ctrl+C (Cmd+C): the game copies the selection itself; BagSmith just confirms.
	f.url:SetScript("OnKeyDown", function(box, key)
		if key == "C" and ((IsControlKeyDown and IsControlKeyDown()) or (IsMetaKeyDown and IsMetaKeyDown())) then
			f.copied = true
			f.copyHint:SetText("Copied!")
			local token = f.copyToken   -- this copy request only (a newer one keeps its own field)
			C_Timer.After(1.2, function() if f.copyToken ~= token then return end f.copied = nil; box:ClearFocus(); WN:EndCopy() end)
		end
	end)
	f.gotIt = ns.TextButton(f, "Got It", 90, function() WN:Close() end)
	f.gotIt:SetHeight(22)
	f.gotIt:SetPoint("BOTTOMRIGHT", -PAD, PAD)
	f.classicSpec = {
		portrait = function() return "Interface\\AddOns\\BagSmith\\Media\\icon.tga" end,
		title = function() return f.title:GetText() end,
		close = function() WN:Close() end,
		hide = { f.title, f.close, f.logo },
		restore = function() ns.Skins:ApplyBackdrop(f) end,
	}
	-- Saved and hidden before registering with the skins: registering repaints
	-- at once, and the game starts every frame shown, so a repaint that asked
	-- for the card before it was saved would build cards endlessly.
	card = f
	f:Hide()
	ns:CloseOnEscape(f, function() WN:Close() end)   -- (1.5.4) Escape closes it and marks it seen, as its close does
	ns.Skins:Register(f, function(fr)
		ns.Skins:ApplyBackdrop(fr)
		ns.Classic:Dress(fr, fr.classicSpec, ns.Classic.IsOn())
		if fr:IsShown() and fr.entries then WN:Fill(fr.entries) end
	end)
	return f
end
WN.Card = function() return card end

local function pooled(f, list, i, make)
	local x = list[i]
	if not x then x = make(); list[i] = x end
	return x
end
local function line(f, i)
	return pooled(f, f.lines, i, function()
		local s = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		s:SetJustifyH("LEFT"); s:SetWordWrap(true)
		return s
	end)
end
local function dash(f, i)
	return pooled(f, f.dashes, i, function()
		local s = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); s:SetText("-")
		return s
	end)
end
local function divider(f, i)
	return pooled(f, f.dividers, i, function() return f.content:CreateTexture(nil, "ARTWORK") end)
end
-- A faint fill behind every other bullet, like the Settings lists' stripes.
local STRIPE_MODERN, STRIPE_CLASSIC = 0.065, 0.15   -- (Modern 6.5% since rc2: 8.5% was a tad bright)
local function stripe(f, i)
	return pooled(f, f.stripes, i, function()
		local t = f.content:CreateTexture(nil, "BACKGROUND")
		t:SetTexture("Interface\\Buttons\\WHITE8X8")
		return t
	end)
end
-- A very light line between bullets, like the hairlines between settings.
local function sep(f, i)
	return pooled(f, f.seps, i, function()
		local t = f.content:CreateTexture(nil, "ARTWORK")
		t:SetTexture("Interface\\Buttons\\WHITE8X8"); t:SetHeight(1)
		return t
	end)
end
-- A tab per release (BagSmith's choice buttons; Blizzard's red buttons in Classic).
local TAB_H = 22
local function tab(f, i)
	return pooled(f, f.tabs, i, function()
		local b = ns.TextButton(f, "", 56, function(btn) WN:Select(btn.index) end)
		b:SetHeight(TAB_H)
		return b
	end)
end
local function tabLabel(e)
	local p = parse(e.v)
	if p[3] > 0 then return ("%d.%d.%d"):format(p[1], p[2], p[3]) end
	return ("%d.%d"):format(p[1], p[2])
end
WN.INTRO = "Highlights from recent major updates."   -- (no count: fine while fewer than five exist)
WN.CHANGELOG_LINE = "|cfffac775Previous Updates & Patches:|r See full changelog @ CurseForge:"
local ITEM_GAP, INDENT, MAX_SCREEN = 6, 10, 0.85
-- One release's body height (heading and bullets) at this width, measured
-- with one hidden string (so the card can be as tall as the tallest tab).
local function measure(f, e, textW)
	local m = f.measure
	if not m then m = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); m:SetWordWrap(true); m:Hide(); f.measure = m end
	m:SetFontObject(GameFontNormal); m:SetWidth(textW); m:SetText(e.heading or ("BagSmith " .. tostring(e.v)))
	local y = m:GetStringHeight() + 2
	m:SetFontObject(GameFontHighlight); m:SetWidth(textW - INDENT)
	for _, text in ipairs(e.items) do m:SetText(text); y = y + ITEM_GAP + m:GetStringHeight() end
	return y + 4
end

function WN:Select(i)
	if not card or not card.entries or not card.entries[i] then return end
	self:Fill(card.entries, i)
end

-- entries: the releases with a tab, newest first; sel: the one shown.
function WN:Fill(entries, sel)
	local f = create()
	f.entries = entries
	sel = math.max(1, math.min(sel or f.sel or 1, math.max(1, #entries)))
	f.sel = sel
	local classic = ns.Classic.IsOn()
	local sk = ns.Skins:Current()
	f.title:SetText("What's New")
	-- Classic shows the title in Blizzard's strip, which is only written when
	-- the window is dressed (before this text existed): update it now.
	ns.Classic:Retitle(f, f.title:GetText())
	-- Modern: the logo and title row. Classic: the title sits in Blizzard's
	-- strip and the portrait hangs over the corner, so the body starts lower.
	local top = classic and 60 or (PAD + LOGO + 6)
	local textW = WIDTH - PAD * 2
	-- The tabs: one per release, newest first.
	local x = PAD
	for i, e in ipairs(entries) do
		local b = tab(f, i)
		b.index = i
		b.label:SetText(tabLabel(e))
		local w = math.max(56, math.ceil(b.label:GetStringWidth()) + 24)
		b:SetWidth(w)
		b:ClearAllPoints(); b:SetPoint("TOPLEFT", f, "TOPLEFT", x, -top)
		if b.SetClassic then b:SetClassic(classic) end
		b:SetActive(i == sel)
		b.tip = e.heading or ("BagSmith " .. tostring(e.v))
		b:Show()
		x = x + w + 6
	end
	for i = #entries + 1, #f.tabs do f.tabs[i]:Hide() end
	if #entries > 0 then top = top + TAB_H + 10 end
	-- The intro line, then the body below it.
	f.intro:SetWidth(textW)
	f.intro:SetText(WN.INTRO)
	f.intro:ClearAllPoints(); f.intro:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -top)
	f.intro:SetTextColor(unpack(sk.muted))
	top = top + f.intro:GetStringHeight() + 10
	-- The body: the selected release's heading, then its bullets with a
	-- hanging indent (wrapped lines line up with the text, not the dash), a
	-- stripe behind every other bullet and a light line between bullets.
	local e = entries[sel]
	local y, n, ns2, nsep = 0, 0, 0, 0
	f.stripes = f.stripes or {}
	local lr, lg, lb = sk.line[1], sk.line[2], sk.line[3]
	if e then
		n = 1
		local h = line(f, n)
		h:SetFontObject(GameFontNormal); h:SetWidth(textW); h:SetText(e.heading or ("BagSmith " .. tostring(e.v)))
		h:SetTextColor(1, 0.82, 0)
		h:ClearAllPoints(); h:SetPoint("TOPLEFT", f.content, "TOPLEFT", PAD, -y); h:Show()
		y = y + h:GetStringHeight() + 2
		for bi, text in ipairs(e.items) do
			n = n + 1
			local s2 = line(f, n)
			s2:SetFontObject(GameFontHighlight); s2:SetTextColor(1, 1, 1); s2:SetWidth(textW - INDENT); s2:SetText(text)
			s2:ClearAllPoints(); s2:SetPoint("TOPLEFT", f.content, "TOPLEFT", PAD + INDENT, -(y + ITEM_GAP)); s2:Show()
			local ds = dash(f, n)
			ds:ClearAllPoints(); ds:SetPoint("TOPLEFT", f.content, "TOPLEFT", PAD, -(y + ITEM_GAP)); ds:Show()
			local hText = s2:GetStringHeight()
			if bi > 1 then
				nsep = nsep + 1
				local t = sep(f, nsep)
				t:ClearAllPoints()
				t:SetPoint("TOPLEFT", f.content, "TOPLEFT", PAD - 6, -(y + ITEM_GAP / 2))
				t:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -(PAD - 6), -(y + ITEM_GAP / 2))
				t:SetVertexColor(lr, lg, lb, 0.45)
				t:Show()
			end
			-- every other bullet, from the heading's first
			if bi % 2 == 1 then
				ns2 = ns2 + 1
				local st = stripe(f, ns2)
				st:ClearAllPoints()
				st:SetPoint("TOPLEFT", f.content, "TOPLEFT", PAD - 6, -(y + ITEM_GAP / 2))
				st:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -(PAD - 6), -(y + ITEM_GAP / 2))
				st:SetHeight(hText + ITEM_GAP)
				if classic then st:SetVertexColor(0, 0, 0, STRIPE_CLASSIC) else st:SetVertexColor(1, 1, 1, STRIPE_MODERN) end
				st:Show()
			end
			y = y + ITEM_GAP + hText
		end
	end
	for i = n + 1, #f.lines do f.lines[i]:Hide() end
	for i = ns2 + 1, #f.stripes do f.stripes[i]:Hide() end
	for i = nsep + 1, #f.seps do f.seps[i]:Hide() end
	-- Dashes only beside bullets (the heading shares the line pool but has none).
	for i, d in pairs(f.dashes) do d:SetShown(i >= 2 and i <= n) end   -- sparse: only bullet positions have one
	for _, d in ipairs(f.dividers) do d:Hide() end
	local contentH = y + 4
	-- A steady size: as tall as the tallest release.
	local tallest = contentH
	for _, other in ipairs(entries) do tallest = math.max(tallest, measure(f, other, textW)) end

	-- Below the body: a stronger line, the changelog line, the address and Got It.
	f.more:SetWidth(textW)
	f.more:SetText(WN.CHANGELOG_LINE)
	local footerH = 16 + 2 + 10 + f.more:GetStringHeight() + 4 + 22 + 16 + 12 + 22 + PAD
	local screenH = (UIParent and UIParent:GetHeight()) or 768
	local maxBody = math.max(80, math.floor(screenH * MAX_SCREEN) - top - footerH)
	local bodyH = math.min(tallest, maxBody)
	f.contentH, f.bodyH = contentH, bodyH
	f.content:SetSize(WIDTH, contentH)
	f.body:ClearAllPoints(); f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -top); f.body:SetSize(WIDTH, bodyH)
	f.body:SetVerticalScroll(0)
	f.scrolls = contentH > bodyH
	y = top + bodyH
	f.footLine:ClearAllPoints(); f.footLine:SetHeight(2)
	f.footLine:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(y + 16)); f.footLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(y + 16))
	if classic then f.footLine:SetVertexColor(0.62, 0.48, 0.25, 0.95) else f.footLine:SetVertexColor(lr, lg, lb, 1) end
	f.footLine:Show()
	y = y + 16 + 2
	f.more:ClearAllPoints(); f.more:SetPoint("TOPLEFT", PAD, -(y + 10))
	y = y + 10 + f.more:GetStringHeight()
	f.fieldText:SetText(WN.URL)
	f.field:ClearAllPoints(); f.field:SetPoint("TOPLEFT", PAD, -(y + 4))
	f.copy:ClearAllPoints(); f.copy:SetPoint("LEFT", f.field, "RIGHT", 6, 0)
	f.discord:ClearAllPoints(); f.discord:SetPoint("LEFT", f.copy, "RIGHT", 6, 0)
	f.url:ClearAllPoints(); f.url:SetPoint("LEFT", f.field, "LEFT", 6, 0)
	f.copyHint:ClearAllPoints(); f.copyHint:SetPoint("TOPLEFT", f.field, "BOTTOMLEFT", 2, -3)
	y = y + 4 + 22 + 16   -- the field, and room for the copy hint under it
	if f.field.SetBackdrop then
		f.field:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
		f.field:SetBackdropColor(0, 0, 0, 0.35)
		f.field:SetBackdropBorderColor(unpack(sk.line))
	end
	f.copyHint:SetTextColor(unpack(sk.muted))
	f:SetHeight(y + 12 + 22 + PAD)
end

-- Copying the address (see the field above).
function WN:StartCopy()
	local f = create()
	f.copied = nil
	f.copyToken = (f.copyToken or 0) + 1
	f.field:Hide()
	f.url:SetText(WN.URL); f.url:Show(); f.url:SetFocus(); f.url:HighlightText()
	f.copyHint:SetText((IsMacClient and IsMacClient()) and "Press Cmd+C to copy" or "Press Ctrl+C to copy")
	f.copyHint:Show()
end
function WN:EndCopy()
	if not card then return end
	card.url:Hide(); card.field:Show(); card.copyHint:Hide()
end

function WN:Open(entries, sel)
	local f = create()
	self:Fill(entries, sel)
	-- Beside whatever it was opened from: Settings if that's showing (so the
	-- two don't overlap), otherwise the bags window.
	f:ClearAllPoints()
	local settings = ns.SettingsPanel and ns.SettingsPanel.frame
	local main = ns.Window and ns.Window.main and ns.Window.main.frame
	if settings and settings:IsShown() then f:SetPoint("TOPLEFT", settings, "TOPRIGHT", 10, 0)
	elseif main and main:IsShown() then f:SetPoint("TOPRIGHT", main, "TOPLEFT", -10, 0)
	else f:SetPoint("CENTER", UIParent, "CENTER", 0, 80) end
	f:Show()
	-- Settings brings itself to the front when shown; the card does the same.
	f:Raise()
end

-- From Settings or /bs new: the latest notable entries, nothing changes.
-- A tab for each of the last five releases (up to the running version).
function WN:Tabs()
	local list, out = self:Latest(), {}
	for i = 1, math.min(#list, self.MAX_SHOWN) do out[i] = list[i] end
	return out
end
function WN:ShowLatest() self:Open(self:Tabs(), 1) end

function WN:Close()
	if card then card:Hide() end
	self:MarkSeen()
end

-- The first bag open after updating.
function WN:Check()
	if not self:Pending() or InCombatLockdown() then return end
	-- Opens on the newest release you haven't seen (the update you just got).
	local unseen, tabs = self:Unseen(), self:Tabs()
	local sel = 1
	for i, e in ipairs(tabs) do if unseen[1] and e.v == unseen[1].v then sel = i end end
	self:Open(tabs, sel)
end

-- Hidden testing: make the next bag open behave as the first after updating.
function WN:ResetForTesting(skipped)
	-- The newest entry for the running version (or, for "skipped", the oldest).
	local list = self:Latest()
	local pick = list[skipped and #list or 1]
	local p = parse(pick and pick.v or ns.version)
	-- One step before that release (never empty, which would count as a first install).
	if p[3] > 0 then p[3] = p[3] - 1 elseif p[2] > 0 then p[2] = p[2] - 1 else p[1] = math.max(0, p[1] - 1) end
	BagSmithDB.whatsNewSeen = ("%d.%d.%d"):format(p[1], p[2], p[3])
end

ns:OnSignal("ADDON_READY", function()
	-- A first install has nothing to compare against: mark this version seen.
	if BagSmithDB.whatsNewSeen == nil then WN:MarkSeen() end
end)
-- Hooked once the bags window exists.
ns:On("PLAYER_ENTERING_WORLD", function()
	local main = ns.Window and ns.Window.main
	if not main or WN.hooked then return end
	WN.hooked = true
	-- Shielded: a failure here is recorded (/bs errors) and never holds up the bags.
	main.frame:HookScript("OnShow", function() if ns.ready then ns:Guard("What's New", WN.Check, WN) end end)
end)
