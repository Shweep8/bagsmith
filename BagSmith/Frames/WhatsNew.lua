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
	-- (1.10.1-beta1) drafted with the beta for Shweep to keep, change or strike (the convention since 1.9.8). An
	-- update under 1.10's tab: it never opens the card by itself.
	-- (1.10.1-beta2) the fix's bullet says who had it (the game's Use Combined Bags off); a bullet for the new setting
	{ v = "1.10.1", heading = "BagSmith 1.10.1", items = {
		"|cfffac775Bags at Vendors:|r with the game's Use Combined Bags turned off, your bags could stay shut at vendors, the mailbox, trades and the auction house, though the bag key opened them fine. They open there now.",
		"|cfffac775Auto-Close Bags I Opened:|r a new switch in Settings > General. Turn it off and bags you opened yourself stay open when you leave a vendor or the mailbox.",
		"|cfffac775Your Bag Key in Settings:|r Settings > General names the key your bags are on, such as Tab, instead of always saying B.",
	} },
	-- (1.10.0-beta12) the 1.10 card, first written as nine bullets.
	-- (1.10.0-beta16, Shweep, 23 Nov: "our what's new card is not player friendly, it's more technical than sells the
	-- new features"; on the rewrite: "rest looks better tho, ty") Seven bullets, each leading with what the player
	-- gets. The ItemTree sentence keeps the two exceptions the beta12 audit asked for (F8). The Disenchant Helper and
	-- junk line left the card; it is in the changelog. The reminder below is as it was ("we lost the reminder": it
	-- stays).
	{ v = "1.10.0", heading = "BagSmith 1.10", items = {
		"|cfffac775Sections That Sort Themselves:|r done dragging every new item to the right spot? Tell a section what belongs in it, like cloth, or gear that binds when equipped, and your loot files itself from then on. Click the pencil beside a section in Settings > Custom Sections. You'll see what lands there before you save.",
		"|cfffac775Start in One Click:|r Alt+Left-click any item and pick New Section From This Item, and BagSmith sets up a section for things like it. Or pick a ready-made one in Settings > Custom Sections: Cloth, Herbs, Gear to Sell, or Food and Drink.",
		"|cfffac775Simpler Filters:|r the Filters window is rebuilt around the same rules. Narrow your bags down in a couple of clicks, and when you like what you see, Save as Section keeps it for good.",
		"|cfffac775Tabs Your Way:|r show a section on every tab or only the ones you pick, so Cloth, Leather and Herbs can break up your Trade Goods tab while All stays tidy. Your Gear, Consumables, Trade Goods, Quest and Junk tabs now show everything of their kind, too.",
		"|cfffac775All Items, Where You Want It:|r using Sections: All? Drag the All Items title to put your pinned sections and Favorites above or below it. Pin to Top is now called Pin Section.",
		"|cfffac775Friends With Your Other Addons:|r have ItemTree? Your sections can sort by what it knows, like Used by My Professions or Needed for a Quest, and the Loot Helper and Disenchant Helper won't offer what it says to keep, apart from your junk and gear it keeps for its dust. Everything BagSmith does with Auctionator, Blackthornes Tradeskills, ItemTree and Pawn now lives in Settings > Addon Sources, each with its own switch. Auction Price Source moved there too. All of it is optional.",
		"|cfffac775A Cleaner Classic Look:|r sharper item icons and borders in the Classic skin. Thanks to Jeor!",
	},
	-- (1.10.0-beta13, the beta12 audit's F6; Shweep: "yes as a reminder") Someone who comes straight from 1.9.7 or
	-- earlier never saw 1.9.8's note: this card opens instead, and closing it marks that note seen. They get it here,
	-- in his own words, as one more bullet. Nobody else does (WN:Items).
	remind = { before = "1.9.8", text = "|cfff09595Reminder:|r if two of your characters share a first name, Global Inventory and tooltips won't be 100% accurate until you've logged in to each of them and visited the bank on each. Apologies, I wish this had been caught sooner." } },
	-- (1.9.2-beta1, Shweep) a release's updates have entries of their own, shown under its tab: 1.9.2 (Jeor's red tint)
	-- and 1.9.1 (which had no card), as Shweep approved them
	-- (1.9.8-beta1, after Shweep's "this should have had a card in what's new" on 1.9.7: an entry is drafted for every
	-- release a player can notice) two characters sharing a first name shared one saved record
	-- (1.9.8-beta2, Shweep: "One Thing to Do" becomes "Important", in the soft red 1.8's entry uses; "let's show this on
	-- next load, while we normally don't in this case we should" (opens = true: the one update that opens the card by
	-- itself); "a small notes below the bullets few lines down" in his own voice (note); and the reminder, with his
	-- apology, that Global Inventory isn't fully accurate until each such character has logged in and visited the bank)
	{ v = "1.9.8", heading = "BagSmith 1.9.8", opens = true, items = {
		"|cfffac775Shared First Names:|r two characters with the same first name, like Mara Swift and Mara Stone, no longer write over each other's saved bags, bank and gold. Each shows on its own in Global Inventory and tooltips.",
		"|cfff09595Important:|r if two of your characters share a first name, Global Inventory and tooltips won't be 100% accurate until you've logged in to each of them and visited the bank on each. Apologies, I wish this had been caught sooner.",
	}, note = "I don't usually open What's New by itself for a patch, since patches are mostly bug fixes that change little. This time I wanted you to know sooner rather than later." },
	-- (1.9.8-beta1) 1.9.7's entry, added afterwards as Shweep asked (1.9.7 was already published without one)
	{ v = "1.9.7", heading = "BagSmith 1.9.7", items = {
		"|cfffac775No Clean Up at Vendors:|r Clean Up Bags When Opened no longer runs when your bags open at a vendor, so your items stay put while you sell. The Clean Up button still works there.",
		"|cfffac775Junk Stays Dimmed:|r with Dim Junk on, junk keeps its greyed look while your bags are being cleaned up.",
	} },
	-- (1.9.6-beta1; Shweep asked whether What's New should warn players to log into every alt) no warning needed, a
	-- reassurance: client build 71037 stopped giving the realm, which hid every alt (Core/Init.lua)
	{ v = "1.9.6", heading = "BagSmith 1.9.6", items = {
		"|cfffac775Your Characters Are Back:|r a recent game update hid your other characters from tooltips, Global Inventory and your gold totals. That's fixed, and nothing was lost.",
		"|cfffac775Catching Up:|r each character shows what it had the last time you played it before the update. Log in to it once and it's up to date again.",
	} },
	-- (1.9.5, Shweep: "I do think a What's New would be nice, it's technically relevant")
	{ v = "1.9.5", heading = "BagSmith 1.9.5", items = {
		"|cfffac775Faster and Lighter:|r Global Inventory searches and redraws faster, and BagSmith takes up about a third less space.",
	} },
	-- (1.9.4-beta2, Shweep: "let's also add a what's new entry"; wording as he chose it)
	{ v = "1.9.4", heading = "BagSmith 1.9.4", items = {
		"|cfffac775Section Values in Compact View:|r Compact View now shows what each section is worth, too. Just hover over or click the little coin on a section's header.",
		"|cfffac775Show Section Values:|r prefer clean headers? Turn the values off in Settings > Sections. You can still hover a section's name to see them.",
	} },
	-- (1.9.5, Shweep: "should we just also back add 1.9.3?", "go") 1.9.3's fix, added afterwards
	{ v = "1.9.3", heading = "BagSmith 1.9.3", items = {
		"|cfffac775Unusable Weapons Too:|r the red tint now also marks weapons, shields and librams, idols or totems your class can't use, like guns and swords on a priest.",
	} },
	{ v = "1.9.2", heading = "BagSmith 1.9.2", items = {
		"|cfffac775Unusable Items in Red:|r gear, recipes and consumables your character can't use yet get a soft red tint, like armor above your level or a recipe you don't have the skill for. Turn it off in Settings > Item Icons > Appearance if you'd rather not see it. Thanks to Jeor!",
	} },
	{ v = "1.9.1", heading = "BagSmith 1.9.1", items = {
		"|cfffac775Gold at the Bank:|r hover your gold in the bank window to see every character's gold on this ruleset, just like in your bags. Hold Shift for your whole account.",
		"|cfffac775Who Has Which Currency:|r hover a pinned currency, or a row in the currency drawer, to see how many each of your characters has.",
		"|cfffac775Full-Width Pinned:|r give each pinned section a full-width row of its own in Split View and Compact View, in Settings > Style > Layout.",
	} },
	-- (1.9.0-beta9) the 1.9 card: Shweep approved the draft (16 Nov: "make sure the wording of it is easy to understand
	-- and does not sound like AI")
	{ v = "1.9.0", heading = "BagSmith 1.9", items = {
		-- (beta10, Shweep: "realm" to "ruleset", a more human last sentence; the second bullet about tooltips and alts;
		-- beta20, Shweep approved: currencies in the drawer, the same as items)
		"|cfffac775Global Inventory:|r click the globe at the top of your bags to see everything your characters on this ruleset are carrying, in one list. It shows who has each item and where it is: bags, bank or worn. Click an item more than one character has to see how many each of them has, and the same goes for currencies in the currency drawer. Down at the bottom, the Total tells you what it's all worth.",
		"|cfffac775Alts in Your Tooltips:|r item tooltips now show how many you and your alts have, and where: bags, bank or worn. That's any item tooltip, whether the item is in your bags, at the auction house, at a vendor or in a chat link. Hover your gold to see each alt's gold too. Don't want the counts? Turn them off in Settings > General > Tooltips.",
		"|cfffac775Compact View:|r in Icons view, sections can now share rows, each only as wide as it needs, so more fits on screen. Pick Full Width, Split View or Compact View in Settings > Style > Layout. Thanks to Jeor!",
		"|cfffac775Shared Disenchanting:|r what one of your characters learns from disenchanting now helps all of them.",
		-- (beta20, Shweep approved: "yeah these are good") the fonts with it: the header's buttons, and every font listed
		"|cfffac775Text and Fonts:|r make your gold, pinned currencies and free slots bigger or smaller on their own, in Settings > Style > Size. The font you pick there now shows on the buttons along the top of your bags too, and every font you have now shows up in the list.",
		"|cfffac775Bolder Borders:|r give your item icons thicker borders in Settings > Item Icons > Appearance. Thanks to Jeor!",
		"|cfffac775Count Every Free Slot:|r your free-slot count leaves out quivers, herb bags and other special bags. Prefer the full count? Change Bag Slot Count in Settings > Windows > Main Window.",
	} },
	-- (1.8.0-beta2) the 1.8 card: Shweep approved the draft (15 Nov) with BagSmith's own fonts added
	{ v = "1.8.0", heading = "BagSmith 1.8", items = {
		-- (1.8.0-beta8, Shweep: friendlier wording for all four; beta18: titles renamed, Quick Tip removed, and each
		-- "Settings > ..." names the heading it opens to)
		"|cfffac775Fonts:|r make the text in your bags, bank and helpers bigger or smaller, and pick a font you like. BagSmith now comes with nine fonts of its own, like Inter, Fira Condensed and Marcellus, and you'll find them in your other addons too. Try it in Settings > Style > Size.",
		"|cfffac775A Disenchant Helper That Learns:|r the first time a disenchant gives you something it hasn't seen, it remembers it. For higher-level gear, it learns from your own results as you go.",
		"|cfffac775Special Bag Indicators:|r your free-slot count now shows the space anything can go in. Hover it to see what's left in your quiver, herb bag, soul bag and more. Want them to stand out? Give each kind of bag its own color, as a soft glow or a colored frame, in Settings > Item Icons > Special Bag Slot Indicators.",
		-- (1.8.0-beta16, Shweep) the icon work (Jeor's PR #9), the gold quest frames
		"|cfffac775Crisper Icons:|r icons and their borders line up cleanly at any scale, and quest items now wear a gold frame (you can turn it off in Settings > Item Icons). In Classic, icons fill their slots just like the game's own bags. Thanks to Jeor!",
		"|cfffac775Profile Sharing Improved:|r like one profile on all your characters, but want each to keep its own favorites, currencies or sheets? Just uncheck them in Settings > Profile > Shared Between Characters.",
		-- (1.8.0-beta8, Shweep) in soft red, so nobody misses it
		"|cfff09595Important:|r each character now keeps its own favorites, pinned sections, custom currencies and pinned currencies. Yours carried over, so nothing is lost, but changes you make now stay with that character. Want them shared again? Check them in Settings > Profile > Shared Between Characters.",
	} },
	-- (1.7.0-beta6) the 1.7 card; (1.7.0-beta12) its text approved by Shweep (12 Nov)
	-- (1.7.0-beta8, the beta7 audit's F2; Shweep's choice) the quest promise says what it can't see, as the (i) does
	{ v = "1.7.0", heading = "BagSmith 1.7", items = {
		-- (1.7.0-beta12, Shweep's review) nine bullets: the switch and "the list's heading" in the first, Mail and Trade,
		-- Gear: Other and Consumables: Other, the header coin and Clean Up; the body scrolls when it's taller than the card
		"|cfffac775A Smarter Loot Helper:|r when your bags are full, the Loot Helper shows what it's making room for and every way to do it: free ways first, then what you'd miss least. Click another waiting item to make room for it instead. It keeps things you craft with a little longer and never offers what you still need for a quest, unless its heading is collapsed in your quest log. Hover the (i) beside the list's heading to see how it decides.",
		"|cfffac775Protect:|r the Loot Helper keeps suggesting something you'd rather keep? Choose it and click Protect, beside Destroy, and it won't suggest it again. Settings > Loot Helper lists what you've protected.",
		"|cfffac775Mail and Trade:|r right-click a merged stack at the mailbox and all of its stacks now attach, not just the one you clicked. BagSmith also tops up partial stacks as it goes, so the mail or trade window gets full stacks and uses fewer slots.",
		"|cfffac775Split Gear by Binding:|r keep the gear you can still trade apart from what's bound to you. Turn on Split Gear by Binding in Settings > Sections and Gear becomes Gear: Soulbound and Gear: BoE, with the rest in Gear: Other. Split Consumables' leftover section is now Consumables: Other to match.",
		"|cfffac775Lock Windows:|r stop your bags, bank and helpers from being moved or resized by accident. Turn it on in Settings > Windows.",
		"|cfffac775Pinned Sections Stand Out:|r Highlight Pinned Sections puts a light background in your accent color behind them (Settings > Sections). In Split View, Recent can span the whole window too: Full-Width Recent, in Settings > Style.",
		"|cfffac775Simpler Section Settings:|r Settings > Sections has one table now, where you move, pin and hide each section, instead of three long lists.",
		"|cfffac775Section Values at Any Width:|r when a section header is too narrow for its values (V and AH), as in Split View, it shows a small coin instead. Hover or click it to see them.",
		"|cfffac775Smoother Clean Up:|r Clean Up Bags no longer makes your game stutter while it sorts, even with Clean Up Bags When Opened on.",
	} },
	{ v = "1.6.0", heading = "BagSmith 1.6", items = {
		"|cfffac775Blackthornes Tradeskills Prices:|r BagSmith can now take auction prices from Blackthornes Tradeskills as well as Auctionator. It uses whichever you have; with both, pick one in Settings > Addon Sources > Auction Prices.",
		"|cfffac775Quest Starters:|r an item that begins a quest now wears a yellow \"!\" in the top left of its icon until you accept the quest. You can move it to another corner in Settings > Item Icons.",
		"|cfffac775See-Through Windows:|r turn down Background Opacity to let the world show through your bags' frame (or the whole window), and turn on Fade While Moving to dim your bags while you run. Both are in Settings > Windows > Opacity.",
		"|cfffac775Fewer Tips:|r know your way around? Turn off Show Help Tooltips in Settings > General to stop the tooltips on BagSmith's buttons and columns. Item tooltips stay.",
		"|cfffac775Narrower Windows:|r your bags can now be as narrow as 440 pixels. Drag the corner in: the toolbar folds into a few small buttons, and List view sets a few columns aside until there's room for them again (you choose which in Settings > Bag Columns).",
		"|cfffac775Smarter Disenchant Advice:|r the Disenchant Helper counts the AH's cut and leans toward disenchanting while you level Enchanting (Settings > Disenchant Helper).",
	} },
	{ v = "1.5.1", heading = "BagSmith 1.5.1", items = {
		"|cfffac775Faster Destroying:|r when the Loot Helper helps you make room, choosing an item and pressing Destroy now removes it right away. Blue and epic items, and anything whose quality the game hasn't shown yet, still ask first, just like the game does. Junk is still one click.",
		"|cfffac775Your Choice:|r prefer to be asked every time? Turn on Ask Before Destroying in Settings > Automations > Loot Helper. Want blue and epic items gone at once too? Untick Always Ask for Rare or Better.",
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
		"|cfffac775Fewer Yes/No Boxes:|r tired of confirming every bind-on-equip piece you put on? BagSmith can click Yes for you on the kinds of box you choose, only after your own BagSmith actions unless you widen it, with a key to hold if you'd rather be asked. Off by default, under Automations.",
		"|cfffac775Mail and Trade:|r right-click a merged stack at the mailbox or in a trade window and the rest of its stacks follow, the way they already did at the bank.",
		"|cfffac775Settings:|r the Loot Helper and the Disenchant Helper have their own pages under Automations.",
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
		"|cfffac775Sell Junk + Mark as Junk:|r mark any item as junk in the new Junk column (or with a keybinding) and it sells along with your greys. You can also sell junk automatically at vendors: Settings > Automations.",
		"|cfffac775Loot Helper:|r when your bags are too full for loot or a quest reward, it suggests what to combine, clean up or destroy, then finishes the looting for you. Settings > Automations.",
		"|cfffac775Favorites and Track as Currency:|r star items to pin them in a Favorites section at the top, and use the wallet column (or Add Item in the currency drawer) to track any item as a currency.",
		"|cfffac775Profile Sharing:|r copy your profile as a code to keep or share, or import someone else's. Settings > Profile.",
		"|cfffac775Keybindings:|r BagSmith has its own section in the game's Keybindings, plus Settings > Keybindings for Mark as Junk, Favorite Item and the rest.",
		"|cfffac775Pawn Support:|r with Pawn installed and its bag upgrade advisor on, Pawn's green upgrade arrows show on your items in BagSmith.",
	} },
	{ v = "0.12.0", heading = "BagSmith 0.12", items = {
		"|cfffac775Travel Mode:|r a compact, on-the-go view for when you're out adventuring. Click the signpost next to the close button and the toolbar and filters tuck away, leaving your items and search. Click it again anytime to get your full inventory tools back.",
		"|cfffac775Auto Travel Mode:|r if you want, Travel Mode can switch off on its own when it's time to manage your bags (at the bank, the auction house or a vendor, or while you're on a flight path) and back on when you're done. Choose which in Settings > Automations.",
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
-- 440 since 0.14: bullets wrap less, the card is shorter; (1.9.0-beta11, Shweep: "5-10% wider") 476, about 8% more;
-- (1.9.0-beta23, Shweep: "extend What's New about 5-10% in width") 512, about 7.5% more
local WIDTH, PAD, LOGO = 512, 16, 32

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

-- (1.9.2-beta1, Shweep: "a second set of button under a primary release that each contain the smaller releases") A
-- release and its updates: entries sharing x.y are one tab, its x.y.0 entry (or its oldest) on the tab itself, the
-- others (patches) on a second row under it, newest first. A tab reads as its main entry (v, heading, items).
local function minorOf(v) local p = parse(v); return p[1] * 1000 + p[2] end
local function groups(list)
	local order, by = {}, {}
	for _, e in ipairs(list) do
		local k = minorOf(e.v)
		if not by[k] then by[k] = {}; order[#order + 1] = k end
		table.insert(by[k], e)
	end
	local out = {}
	for _, k in ipairs(order) do
		local list2 = by[k]
		local primary = list2[#list2]
		for _, e in ipairs(list2) do if parse(e.v)[3] == 0 then primary = e end end
		local patches = {}
		for _, e in ipairs(list2) do if e ~= primary then patches[#patches + 1] = e end end
		out[#out + 1] = setmetatable({ primary = primary, patches = patches }, { __index = primary })
	end
	return out
end
WN.Groups = groups

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
-- (1.9.2-beta1, Shweep: "only open the What's New window automatically on primary") main releases not seen yet, newest
-- first: only these open the card on their own; an update never does
function WN:UnseenReleases()
	local seen, out = BagSmithDB.whatsNewSeen or "0.0.0", {}
	for _, g in ipairs(groups(self:Latest())) do if newer(g.primary.v, seen) then out[#out + 1] = g end end
	return out
end
-- (1.9.8-beta2, Shweep: "while we normally don't in this case we should") An update marked opens = true opens the
-- card by itself, once, like a main release: while its release is the newest one, until its notes have been opened.
-- Every other update still waits to be clicked.
function WN:UnseenOpener()
	local newest = groups(self:Latest())[1]
	local seen = BagSmithDB.whatsNewPatchSeen
	for j, p in ipairs(newest and newest.patches or {}) do
		if p.opens and not (type(seen) == "table" and seen[base(p.v)]) then return p, j end
	end
end
function WN:Pending()
	return ns.db and ns.db.whatsNew ~= false and (#self:UnseenReleases() > 0 or self:UnseenOpener() ~= nil)
end
function WN:MarkSeen() BagSmithDB.whatsNewSeen = base(ns.version) end
-- (1.10.0-beta13) A card's bullets for this player: its own, and its reminder when they came here straight from a
-- version older than the one the reminder is from (WN.owed).
WN.owed = {}
function WN:Items(e)
	local r = e and e.remind
	if not (r and self.owed[r.before]) then return e.items end
	local out = {}
	for i, text in ipairs(e.items) do out[i] = text end
	out[#out + 1] = r.text
	return out
end
-- Which reminders are owed, noted at load before anything is marked seen: the last What's New this account closed was
-- older than the release a reminder is from. Nothing is saved: it lasts until the next load, by when the card that
-- carries it has been seen and closed (or is still waiting, and it is noted again).
function WN:NoteReminders()
	self.owed = {}
	local seen = type(BagSmithDB) == "table" and BagSmithDB.whatsNewSeen or nil
	if type(seen) ~= "string" then return end   -- (a first install: nothing was skipped)
	for _, e in ipairs(self.ENTRIES) do
		local r = e.remind
		if r and newer(r.before, seen) and not newer(e.v, ns.version) then self.owed[r.before] = true end
	end
end
-- An update's notes you haven't opened: NEW on its button, for the newest release's updates only (never an old one's)
function WN:PatchNew(e)
	local newest = groups(self:Latest())[1]
	if not (newest and e) then return false end
	local mine = false
	for _, p in ipairs(newest.patches) do if p.v == e.v then mine = true end end
	local seen = BagSmithDB.whatsNewPatchSeen
	return mine and not (type(seen) == "table" and seen[base(e.v)]) or false
end
function WN:MarkPatchSeen(e)
	if not e then return end
	if type(BagSmithDB.whatsNewPatchSeen) ~= "table" then BagSmithDB.whatsNewPatchSeen = {} end
	BagSmithDB.whatsNewPatchSeen[base(e.v)] = true
end
-- NEW on Settings' What's New button: an update you haven't opened, since the button was last clicked
function WN:ButtonNew()
	local newest = groups(self:Latest())[1]
	local last = BagSmithDB.whatsNewButtonSeen or "0.0.0"
	for _, p in ipairs(newest and newest.patches or {}) do if self:PatchNew(p) and newer(p.v, last) then return true end end
	return false
end
function WN:MarkButtonSeen() BagSmithDB.whatsNewButtonSeen = base(ns.version) end
-- Everything up to the running version counts as seen (a first install).
function WN:MarkAllSeen()
	self:MarkSeen(); self:MarkButtonSeen()
	for _, e in ipairs(self:Latest()) do if parse(e.v)[3] > 0 then self:MarkPatchSeen(e) end end
end

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
	-- The body (version headings and bullets) scrolls inside the card when the
	-- open release is taller than the body (WN.MAX_BODY, or less on a small
	-- screen). (1.7.0-beta12) With a scrollbar, the same kind as the Loot
	-- Helper's list (Blizzard's, dressed for Classic; hidden when nothing
	-- scrolls); the text narrows to make room for it.
	f.body = CreateFrame("ScrollFrame", "BagSmithWhatsNewBody", f, "UIPanelScrollFrameTemplate")
	f.body.scrollBarHideable = true
	f.content = CreateFrame("Frame", nil, f.body)
	f.content:SetSize(WIDTH, 10)
	f.body:SetScrollChild(f.content)
	-- (1.8.0-beta18) The bullets' "Settings > ..." links: clicking one opens Settings there. The body still drags the card.
	if f.content.SetHyperlinksEnabled then f.content:SetHyperlinksEnabled(true) end
	f.content:EnableMouse(true); f.content:RegisterForDrag("LeftButton")
	f.content:SetScript("OnDragStart", function() f:StartMoving() end)
	f.content:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
	f.content:SetScript("OnHyperlinkClick", function(_, link) WN.OnLink(link) end)
	f.content:SetScript("OnHyperlinkEnter", function(self, link)
		if ns.HelpTipsOK() and tostring(link):find("^bagsmith:settings:") then
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR"); ns.TipText(GameTooltip, "Click to go there in Settings"); GameTooltip:Show()
		end
	end)
	f.content:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
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
		if ns.HelpTipsOK() then GameTooltip:SetOwner(b, "ANCHOR_TOP"); ns.TipText(GameTooltip, WN.URL, 1, 1, 1); ns.TipLine(GameTooltip, "Click to copy", 0.6, 0.6, 0.6); GameTooltip:Show() end
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
	ns:CombatWindow(f)   -- (1.5.6) fades in combat like the bags window
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
-- (1.10.0-beta16) Classic: the portrait is 58 px, hanging 5 px left of the window and reaching 51 px down. The tab row
-- starts to its right, under Blizzard's title strip; the first thing at the left edge after it starts 64 down.
local CLASSIC_TAB_X, CLASSIC_TAB_Y, CLASSIC_BELOW_PORTRAIT = 60, 30, 64
local SUB_H = 18   -- (1.9.2-beta1) an update's button, under its release's tab
local SUB_GAP = 6   -- between update buttons, and between their lines (1.9.8-beta3)
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
local NOTE_GAP = 22   -- (1.9.8-beta2) the room above an entry's note: set apart from the bullets, a line or two down
WN.NOTE_GAP = NOTE_GAP
-- (1.7.0-beta12, Shweep) The body is at most this tall (about what the 1.6 release needs), so the card keeps the size
-- players know; a longer release scrolls. BAR_W: the room its scrollbar takes on the right while it scrolls.
WN.MAX_BODY = 360
local BAR_W = 32
-- One release's body height (heading and bullets) at this width, measured
-- with one hidden string (so the card can be as tall as the tallest tab).
local function measure(f, e, textW)
	local m = f.measure
	if not m then m = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); m:SetWordWrap(true); m:Hide(); f.measure = m end
	m:SetFontObject(GameFontNormal); m:SetWidth(textW); m:SetText(e.heading or ("BagSmith " .. tostring(e.v)))
	local y = m:GetStringHeight() + 2
	m:SetFontObject(GameFontHighlight); m:SetWidth(textW - INDENT)
	for _, text in ipairs(WN:Items(e)) do m:SetText(text); y = y + ITEM_GAP + m:GetStringHeight() end
	if e.note then m:SetFontObject(GameFontHighlightSmall); m:SetWidth(textW); m:SetText(e.note); y = y + NOTE_GAP + m:GetStringHeight() end
	return y + 4
end

-- (1.8.0-beta18, Shweep) Directions in a bullet ("Settings > Style > Size") show in soft blue and open Settings right
-- there: the page, scrolled to the heading when the direction names one (or the sub-page it names). The bullets stay
-- plain text; the links are added as they're drawn. A direction naming no page Settings has stays as it is.
WN.LINK_COLOR = "|cff8cc8ff"
local function pageAt(s, i, labels)
	local best
	for _, p in ipairs(labels) do
		local L = p[2]
		if s:sub(i, i + #L - 1) == L and not s:sub(i + #L, i + #L):find("^[%w]") and (not best or #L > #best[2]) then best = p end
	end
	return best
end
function WN.Linkify(text)
	local P = ns.SettingsPanel
	local labels = P and P.PageLabels and P:PageLabels()
	if type(text) ~= "string" or not labels then return text end
	local out, pos = {}, 1
	while true do
		local a, b = text:find("Settings > ", pos, true)
		if not a then break end
		local page = pageAt(text, b + 1, labels)
		if not page then
			out[#out + 1] = text:sub(pos, b); pos = b + 1
		else
			local stop = b + #page[2]
			local key, heading = page[1], ""
			-- " > " and then a sub-page of that page, or a heading (words that start with a capital, or "&")
			if text:sub(stop + 1, stop + 3) == " > " then
				local sub
				for _, p in ipairs(labels) do
					if p[3] == key and text:sub(stop + 4, stop + 3 + #p[2]) == p[2] and not text:sub(stop + 4 + #p[2], stop + 4 + #p[2]):find("^[%w]") then sub = p end
				end
				if sub then
					key, stop = sub[1], stop + 3 + #sub[2]
				else
					local words = text:match("^%u[%w']*", stop + 4)
					if words then
						local j = stop + 4 + #words
						while true do
							local more = text:match("^ [%u&][%w']*", j)
							if not more then break end
							words, j = words .. more, j + #more
						end
						heading, stop = words, j - 1
					end
				end
			end
			out[#out + 1] = text:sub(pos, a - 1)
			out[#out + 1] = ("%s|Hbagsmith:settings:%s:%s|h%s|h|r"):format(WN.LINK_COLOR, key, heading, text:sub(a, stop))
			pos = stop + 1
		end
	end
	out[#out + 1] = text:sub(pos)
	return table.concat(out)
end
-- A direction's link: open Settings on its page (and heading).
function WN.OnLink(link)
	local page, heading = tostring(link or ""):match("^bagsmith:settings:([%w]+):(.*)$")
	if not page or not ns.SettingsPanel then return false end
	return ns.SettingsPanel:Open(page, heading ~= "" and heading or nil)
end

function WN:Select(i)
	if not card or not card.entries or not card.entries[i] then return end
	self:Fill(card.entries, i)
end
-- (1.9.2-beta1) one of the open release's updates; opening it clears its NEW
function WN:SelectPatch(j)
	local g = card and card.entries and card.entries[card.sel]
	local p = g and g.patches and g.patches[j]
	if not p then return end
	self:MarkPatchSeen(p)
	self:Fill(card.entries, card.sel, j)
end

-- entries: the releases with a tab, newest first; sel: the one shown; sub: one of its updates (nil: its own notes).
function WN:Fill(entries, sel, sub)
	local f = create()
	f.entries = entries
	sel = math.max(1, math.min(sel or f.sel or 1, math.max(1, #entries)))
	f.sel = sel
	local patches = entries[sel] and entries[sel].patches or {}
	f.sub = patches[sub or 0] and sub or nil
	local classic = ns.Classic.IsOn()
	local sk = ns.Skins:Current()
	f.title:SetText("What's New")
	-- Classic shows the title in Blizzard's strip, which is only written when
	-- the window is dressed (before this text existed): update it now.
	ns.Classic:Retitle(f, f.title:GetText())
	-- Modern: the logo and title row. Classic: the title sits in Blizzard's
	-- strip and the portrait hangs over the corner.
	-- (1.10.0-beta16, Shweep: "in classic style we waste a ton of space at top", with screenshots) In Classic the tabs
	-- started at the left edge, so they had to sit under the portrait (60 down), with an empty band between the title
	-- strip and them. They now start beside the portrait, just under the strip, and what follows starts where the
	-- portrait ends: about 28 px back for the notes.
	local top = classic and CLASSIC_TAB_Y or (PAD + LOGO + 6)
	local textW = WIDTH - PAD * 2
	-- The tabs: one per release, newest first.
	local x = classic and CLASSIC_TAB_X or PAD
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
	if classic then top = math.max(top, CLASSIC_BELOW_PORTRAIT) end   -- (what follows starts at the left edge, clear of the portrait)
	-- (1.9.2-beta1) the open release's updates, newest first, on a second row; its height kept on every tab (when any
	-- release shown has updates), so switching tabs doesn't jump. An update not opened yet says NEW.
	-- (1.9.8-beta3, Shweep: "all the new tags are causing the patch buttons to go outside the window", eight updates
	-- under 1.9, seven saying NEW) The row wraps: a button, with its NEW, that wouldn't fit starts the next line.
	-- (1.9.8-beta4, Shweep: "reserving those two rows on all of them is a bit much") Every tab keeps room for one line,
	-- as before; a release whose updates need more takes the rest from the room under its own notes (the body starts
	-- that much lower and is that much shorter), so the card and Got It never move. A NEW that was showing when the
	-- card opened keeps its room once clicked: the buttons don't shuffle, and the notes don't shift, while it's open.
	f.subTabs = f.subTabs or {}
	local function subButton(j)
		local b = f.subTabs[j]
		if not b then
			b = ns.TextButton(f, "", 48, function(btn) WN:SelectPatch(btn.index) end)
			b:SetHeight(SUB_H)
			f.subTabs[j] = b
		end
		return b
	end
	local SP = ns.SettingsPanel
	local right = WIDTH - PAD
	local function tagRoom(b) return 4 + ((b.newTag and SP and SP.NewTagWidth and SP.NewTagWidth(b.newTag)) or 30) end
	local anyPatches = false
	for _, g in ipairs(entries) do if g.patches and #g.patches > 0 then anyPatches = true end end
	f.subRoom = f.subRoom or {}
	local sx, row = PAD, 0
	for j, p in ipairs(patches) do
		local b = subButton(j)
		b.index = j
		b.label:SetText(tabLabel(p))
		local w = math.max(48, math.ceil(b.label:GetStringWidth()) + 18)
		b:SetWidth(w)
		if b.SetClassic then b:SetClassic(classic) end
		b:SetActive(j == f.sub)
		b.tip = p.heading or ("BagSmith " .. tostring(p.v))
		local new = WN:PatchNew(p)
		if SP and SP.NewTag then SP.NewTag(b, new, b, w + 4) end
		if new then f.subRoom[p.v] = tagRoom(b) end
		local need = w + (f.subRoom[p.v] or 0)
		if sx > PAD and sx + need > right then row = row + 1; sx = PAD end
		b:ClearAllPoints(); b:SetPoint("TOPLEFT", f, "TOPLEFT", sx, -(top - 4 + row * (SUB_H + SUB_GAP)))
		b.row, b.left, b.need = row, sx, need
		b:Show()
		sx = sx + need + SUB_GAP
	end
	for j = #patches + 1, #f.subTabs do
		f.subTabs[j]:Hide()
		if f.subTabs[j].newTag then f.subTabs[j].newTag:Hide() end
	end
	f.subLines = #patches > 0 and (row + 1) or 0   -- the lines this release's updates take
	local kept = anyPatches and 1 or 0           -- the line every tab keeps room for
	top = top + kept * (SUB_H + SUB_GAP)
	local shift = math.max(0, f.subLines - kept) * (SUB_H + SUB_GAP)   -- this tab's extra lines: its notes start lower
	f.subShift = shift
	-- The intro line, then the body below it.
	f.intro:SetWidth(textW)
	f.intro:SetText(WN.INTRO)
	f.intro:ClearAllPoints(); f.intro:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(top + shift))
	f.intro:SetTextColor(unpack(sk.muted))
	top = top + f.intro:GetStringHeight() + 10
	-- The body: the selected release's heading, then its bullets with a
	-- hanging indent (wrapped lines line up with the text, not the dash), a
	-- stripe behind every other bullet and a light line between bullets.
	local e = f.sub and patches[f.sub] or entries[sel]
	-- (1.7.0-beta12) The body's height first: as tall as the tallest release, at most WN.MAX_BODY, and never more than
	-- the screen allows (MAX_SCREEN, with the footer). A release taller than that scrolls, laid out narrower beside its
	-- scrollbar; one that fits uses the full width and shows no bar.
	local tallest = 0
	for _, other in ipairs(entries) do
		tallest = math.max(tallest, measure(f, other, textW))
		for _, p in ipairs(other.patches or {}) do tallest = math.max(tallest, measure(f, p, textW)) end   -- (1.9.2-beta1)
	end
	f.more:SetWidth(textW)
	f.more:SetText(WN.CHANGELOG_LINE)
	local footerH = 16 + 2 + 10 + f.more:GetStringHeight() + 4 + 22 + 16 + 12 + 22 + PAD
	local screenH = (UIParent and UIParent:GetHeight()) or 768
	local maxBody = math.max(80, math.min(WN.MAX_BODY, math.floor(screenH * MAX_SCREEN) - top - footerH))
	local bodyH = math.min(tallest, maxBody)
	-- (1.9.8-beta4) this tab's own height: less by its extra lines of update buttons (never less than a few lines)
	local bodyHere = math.max(60, bodyH - shift)
	local scrolling = e ~= nil and measure(f, e, textW) > bodyHere
	local contentW = WIDTH - (scrolling and BAR_W or 0)
	local fullW = textW
	textW = contentW - PAD * 2
	f.content:SetSize(contentW, 10)
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
		for bi, text in ipairs(WN:Items(e)) do
			n = n + 1
			local s2 = line(f, n)
			s2:SetFontObject(GameFontHighlight); s2:SetTextColor(1, 1, 1); s2:SetWidth(textW - INDENT); s2:SetText(WN.Linkify(text))
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
		-- (1.9.8-beta2, Shweep) an entry's note: under the bullets, set apart, smaller and quieter, no dash or stripe
		if e.note then
			if not f.note then
				f.note = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				f.note:SetJustifyH("LEFT"); f.note:SetWordWrap(true)
			end
			y = y + NOTE_GAP
			f.note:SetWidth(textW); f.note:SetText(e.note); f.note:SetTextColor(unpack(sk.muted))
			f.note:ClearAllPoints(); f.note:SetPoint("TOPLEFT", f.content, "TOPLEFT", PAD, -y); f.note:Show()
			y = y + f.note:GetStringHeight()
		end
	end
	if f.note and not (e and e.note) then f.note:Hide() end
	for i = n + 1, #f.lines do f.lines[i]:Hide() end
	for i = ns2 + 1, #f.stripes do f.stripes[i]:Hide() end
	for i = nsep + 1, #f.seps do f.seps[i]:Hide() end
	-- Dashes only beside bullets (the heading shares the line pool but has none).
	for i, d in pairs(f.dashes) do d:SetShown(i >= 2 and i <= n) end   -- sparse: only bullet positions have one
	for _, d in ipairs(f.dividers) do d:Hide() end
	local contentH = y + 4
	textW = fullW   -- (the footer below uses the card's full width)
	-- A steady size: every release the same height (bodyH, above); the open one scrolls if it's taller.
	f.contentH, f.bodyH = contentH, bodyHere
	f.content:SetSize(contentW, contentH)
	f.body:ClearAllPoints(); f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(top + shift)); f.body:SetSize(contentW, bodyHere)
	f.body:SetVerticalScroll(0)
	f.scrolls = contentH > bodyHere
	if ns.Classic and ns.Classic.DressScrollBar then ns.Classic:DressScrollBar(f.body, classic) end
	if f.body.ScrollBar then f.body.ScrollBar:SetShown(f.scrolls) end
	y = top + math.max(bodyH, shift + bodyHere)   -- (the same on every tab: the extra lines came out of the body)
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
	f.subRoom = nil   -- (1.9.8-beta4) which updates said NEW is noted afresh each time the card opens
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
	local list, out = groups(self:Latest()), {}   -- (1.9.2-beta1) a tab per release, its updates under it
	for i = 1, math.min(#list, self.MAX_SHOWN) do out[i] = list[i] end
	return out
end
function WN:ShowLatest()
	self:Open(self:Tabs(), 1)
	-- (1.9.8-beta3) an update that opens the card and hasn't been read is what it opens on, from Settings too
	local opener, j = self:UnseenOpener()
	if opener then self:SelectPatch(j) end
end

-- (1.9.8-beta3, Shweep) Closing it, by Got It, the X or Escape, also counts every update listed as seen: NEW then
-- means "arrived since you last had this open", so the tags no longer pile up for someone who never clicks them.
function WN:Close()
	local shown = card and card:IsShown()
	if card then card:Hide() end
	self:MarkSeen()
	if shown then
		for _, e in ipairs(self:Latest()) do if parse(e.v)[3] > 0 then self:MarkPatchSeen(e) end end
	end
end

-- The first bag open after updating.
function WN:Check()
	if not self:Pending() or InCombatLockdown() then return end
	-- Opens on the newest release you haven't seen (the update you just got).
	-- (1.9.2-beta1) on that release's own notes ("we always open on the primary"); its updates are a click away
	local unseen, tabs = self:UnseenReleases(), self:Tabs()
	-- (1.9.8-beta2) an update that opens the card: on its own notes, which counts as opening them (its NEW goes)
	local opener, j = self:UnseenOpener()
	if opener then
		self:Open(tabs, 1)
		self:SelectPatch(j)
		return
	end
	local sel = 1
	for i, e in ipairs(tabs) do if unseen[1] and e.v == unseen[1].v then sel = i end end
	self:Open(tabs, sel)
end

-- Hidden testing: make the next bag open behave as the first after updating.
function WN:ResetForTesting(skipped)
	-- The newest release for the running version (or, for "skipped", the oldest). (1.9.2-beta1) its main release, not
	-- its newest update: only a main release opens the card, so one step before 1.9.2 (1.9.1) would show nothing
	local list = groups(self:Latest())
	local pick = list[skipped and #list or 1]
	local p = parse(pick and pick.primary.v or ns.version)
	-- One step before that release (never empty, which would count as a first install).
	if p[3] > 0 then p[3] = p[3] - 1 elseif p[2] > 0 then p[2] = p[2] - 1 else p[1] = math.max(0, p[1] - 1) end
	BagSmithDB.whatsNewSeen = ("%d.%d.%d"):format(p[1], p[2], p[3])
	BagSmithDB.whatsNewPatchSeen, BagSmithDB.whatsNewButtonSeen = nil, nil   -- (1.9.2-beta1) the updates' NEW tags too
	self:NoteReminders()   -- (1.10.0-beta13) and what a player updating from there would be reminded of
end

ns:OnSignal("ADDON_READY", function()
	WN:NoteReminders()   -- (1.10.0-beta13) before anything is marked seen
	-- A first install has nothing to compare against: mark this version seen.
	if BagSmithDB.whatsNewSeen == nil then
		WN:MarkAllSeen()   -- (1.9.2-beta1) the updates' notes too
		-- (1.8.0-beta19, after FlareUI) and nothing in Settings is NEW to them either
		if ns.SettingsPanel and ns.SettingsPanel.MarkAllNewSeen then ns.SettingsPanel:MarkAllNewSeen() end
	end
end)
-- Hooked once the bags window exists.
ns:On("PLAYER_ENTERING_WORLD", function()
	local main = ns.Window and ns.Window.main
	if not main or WN.hooked then return end
	WN.hooked = true
	-- Shielded: a failure here is recorded (/bs errors) and never holds up the bags.
	main.frame:HookScript("OnShow", function() if ns.ready then ns:Guard("What's New", WN.Check, WN) end end)
end)
