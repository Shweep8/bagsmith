## 1.7.3

Changed:
- Modern icons look cleaner: each item's icon is trimmed of its old beveled edge, with a thin, even border in its
  rarity color (or the neutral border, as Rarity Borders sets). Empty slots keep their look, and Classic is unchanged.
  Thanks to Jeor.
- In the Disenchant Helper, each likely result's name is in its rarity color, and hovering it shows the item's
  tooltip.
Fixed:
- With Fit to Items, switching to a smaller sheet no longer moves the bottom tabs out from under your pointer after
  you've dragged the window: the window keeps its bottom edge and grows or shrinks upward. If you moved your window
  before, it may settle a little lower once, the first time you open it after updating. Thanks to Jeor.
- Resizing the bags or bank window, or the Disenchant Helper, by its corner now drags an outline of the new size; the
  window takes that size when you let go. No more flicker, or a blank window, while you resize. Moving a window by its
  title bar no longer briefly pulls it back. Thanks to Jeor.

## 1.7.2

Changed:
- Merge Stacks now shows your Soul Shards as one icon with the total, though the game keeps each shard in its own
  slot.
Fixed:
- Swapping in a bag on the game's own bag bar is more careful in two rare split-second cases: canceling a drag and
  clicking that bag's slot at the same moment, or picking up a second bag of the same kind right after a drop, no
  longer swaps a bag in.

## 1.7.1

Changed:
- Swapping in a bag takes one drag, even when it's stored in the bag it replaces: drop it on that bag's slot (on the
  Bag Bar, the bank's bag strip or the game's own bag bar) and BagSmith moves it to a free slot in another bag first,
  then swaps it in. The old bag's items move into the new one, and chat says which bag the old one is in now. Before,
  the game refused it and you had to move the bag out yourself. If no other bag has a free slot, or the two bags are
  the same kind, chat says so.
- A currency you unpin now stays unpinned for every character sharing your profile: another character's Show on
  Backpack picks no longer pin it again. Import Blizzard Picks still brings them all back.

## 1.7.0

New:
- Lock Windows (Settings > Windows): your bags, bank and bag windows and the Loot and Disenchant Helpers can't be moved
  or resized. Off unless you turn it on.
- Highlight Pinned Sections (Settings > Sections): a light background in your accent color behind each pinned
  section, with Highlight Opacity (15% to start). Off unless you turn it on.
- Full-Width Recent (Settings > Style, under Split View): in Split View, Recent Items spans both columns instead of
  sharing a row with the next section.
- Loot Helper: Protect. Choose an item the Loot Helper suggests letting go and click Protect, beside Destroy ("Don't
  suggest again"). A protected item is never suggested again, and it doesn't have to be a favorite. Settings > Loot
  Helper lists them under Protected Items, where you can take any off. Each character keeps its own.
- Split Gear by Binding (Settings > Sections): Gear becomes Gear: Soulbound (bind on pickup, and bind on equip once
  it's bound to you) and Gear: BoE (bind on equip, not yet bound, so you can still trade it or sell it on the AH). Gear
  that binds when used, or doesn't bind, stays in Gear, which reads Gear: Other while the split is on. Untick either to
  keep it there. Your own moves and Gear Sets still come first. Off unless you turn it on.
- /bs questlog shows what your game reports for your quest log, the way the Loot Helper reads it: each quest, the
  items it asks for, and whether BagSmith could read it all.
- Mail and trade: when you right-click a merged stack at the mailbox or in a trade window, BagSmith sends its fullest
  stack and tops up the partial ones before the rest follow, so full stacks go and fewer slots are used (70 Linen Cloth
  in stacks of 20, 20, 19 and 11 goes as 20, 20, 20 and 10).
Changed:
- Loot Helper: it now shows what it's making room for (the most valuable item waiting, highlighted; click another to
  switch) and one list of every way to do it: free ways first, then items to let go, six at a time, scrolling for the
  rest. Each way's cost is on the right, and the line under the button says what happens next. A slot you free goes to
  that item first.
- Loot Helper: the list is ranked by what you'll miss least, not by price alone. Materials your professions use stay
  longer (BagSmith learns them when you open a profession window), a spare stack of something you carry more of goes
  sooner, and anything a quest still asks you to bring is never offered, unless its heading is collapsed in your quest
  log. If BagSmith can't read your quest log for a moment, it offers nothing until it can. Junk is still always offered,
  whatever it's worth, but ranks by its value with everything else instead of always first. The (i) beside the list's
  heading explains how it decides, and so does Settings > Loot Helper.
- Loot Helper: when the item it's making room for is a quest item, the note says it's a quest item with no price,
  instead of "no price yet".
- Settings > Sections: Section Order is now Move, Pin and Hide Sections, one table with each section's Pin and its
  Vendor and AH boxes on the same row, instead of three long lists of every section.
- Section headers too narrow for their values (V and AH), as in Split View, now show a small coin instead: hover or
  click it to see them. Every header shows them the same way.
- Split Consumables: Other Consumables is now Consumables: Other, to match Gear: Other.
- What's New keeps its size when a release has more to say: the text scrolls, with a scrollbar.
- Currencies you tick Show on Backpack in the game's currency tab are pinned to the bag footer for you, as soon as the
  bags open. Each character's picks are pinned once, so one you unpin stays unpinned, though another character sharing
  your profile can still pin its own picks. Import Blizzard Picks brings them all back.
- Clean Up Bags runs much lighter: while it sorts, BagSmith updates your bags a few times a second instead of every
  frame. Before, it could lag your game for a few seconds, above all with Clean Up Bags When Opened on.
Fixed:
- The Quest Starter mark (the yellow "!") on an item in Recent is now the same size as in its own section, and it
  follows Icon Size.
- Clear Soul Shards never leaves you with fewer than Soul Shards to Keep: it counts your shards right before each one
  goes, so a shard you just used or moved can't throw the count off.
- Turning on Split Consumables by Type with Settings open now lists its sections in Move, Pin and Hide Sections at
  once (Split Gear by Binding too). Before, they showed only after you reopened Settings.
- If the game ever refuses to let BagSmith destroy an item, the Loot Helper and Clear Soul Shards now say so and put it
  back in your bags, instead of leaving it on your cursor or counting it as gone.
- Right-clicking a merged stack at the mailbox now attaches all of its stacks, as many as the mail has room for. Before,
  only the stack you clicked was attached, and chat said nothing had moved.

## 1.6.3

Fixed:
- Split Consumables: an item you move to Food, Drink or another of its sections now stays there after a reload, and
  those sections keep their place in Section Order and their hiding at a vendor or the auction house. A reload undid
  moves made before this fix, so make them once more.
- Split Consumables: while it's off, or that type is unticked, an item you moved to one of its sections shows in
  Consumables, and goes back to its section when you turn it on again.

## 1.6.2

Changed:
- Item cooldowns update only while your bags are open, so BagSmith does less during combat. They catch up the moment
  you open your bags.
- Each bag's own window, and each bank bag's, is built the first time you open it instead of at login.
- List view redraws faster when your items change.

## 1.6.1

Fixed:
- Bank: a bank bag slot you buy shows right away, ready for a bag, instead of when you move the pointer off the bank
  window.

## 1.6.0

New:
- Price Source: BagSmith can take auction prices from Blackthornes Tradeskills as well as Auctionator, for the AH Price
  column and the Loot and Disenchant Helpers. It uses whichever you have installed; with both, choose in
  Settings > General > Price Source (Auctionator until you do). Changing it, or a price addon loading later, updates
  an open Loot Helper and Disenchant Helper at once. A price with no scan date of your own says "Scan date unknown".
- Quest Starter: an item that begins a quest you haven't accepted wears a yellow "!" (with a slight shadow, so it stands
  out on bright icons) in the top left of its icon. Like the stack count, it can be moved to another corner
  (Settings > Item Icons) but not hidden. /bs quest lists them.
- Background Opacity (Settings > Windows > Opacity): the bag windows' frame and background can be see-through, while
  your items and text stay solid. Turn on Whole Window to fade everything.
- Fade While Moving (Settings > Windows > Opacity): the bag windows dim while your character moves, to their own Opacity
  While Moving, and come back when you stop.
- Show Help Tips (Settings > General): turn off the tooltips on BagSmith's buttons, column headers and marks. Item
  tooltips stay.
- Narrower windows: the bags window can be as narrow as 440 pixels (the bank window 500; both were 620). As it narrows,
  the toolbar folds into one Sections button with a menu, a shorter Sort button and small Merge Stacks and List / Icons
  buttons; List view sets aside columns, Type first, then Age, Vendor, AH Price and the rest, and brings them back when
  there's room (Item and Qty are always shown); the title shortens and the character button narrows; pinned currencies
  in the footer fold into "+N" first. Choose which columns are set aside, and in what order, in Settings > Bag Columns
  (or Bank Columns) > Narrow Windows; a column you untick is always kept. Pointing at a column header says what's set
  aside. Keep many columns and the window stops narrowing where they'd no longer fit (the Narrow Windows card says how
  narrow it can go).
- Sheet tabs stay on one row: the ones that don't fit go into a "»" tab with a menu, with New Sheet... at the bottom.
  The tab you're on always stays in view.
- Disenchant Helper: Selling at the AH Must Beat the Vendor By (Settings > Disenchant Helper, 20% to start). Selling at
  the auction house is only suggested when it pays at least this much more than the vendor.
- Disenchant Helper: Leveling Enchanting (Automatic, Always or Never). While you're leveling, materials count at full
  value and disenchanting wins even when it's worth up to 10% less than selling; the helper says "(for leveling)" and
  shows your skill. Automatic does this until your Enchanting reaches its current cap.

Changed:
- Bags and bank windows: the search box now reaches the window's right edge at every width, with Filter at the end,
  and List / Icons sits at the toolbar's right end below it.
- Settings > Windows: one Opacity card for everything see-through (Always, While Moving, In Combat). Fade Windows During
  Combat is now called Fade in Combat.
- Icon Corners explains that marks some addons draw themselves aren't listed there and are set in that addon.
- An addon whose icon mark can't be added to Icon Corners is told why in chat.
- Settings: plainer help text throughout, in everyday words (no setting was renamed or moved).
- Loot Helper: an item is only destroyed at the price it was offered at. If its price changed since (a new scan, another
  price source, or Rank Suggestions By), nothing is destroyed and the Loot Helper updates. Changing Rank Suggestions By
  re-ranks an open Loot Helper at once.
- Loot Helper: the item it suggests by default is always the cheapest as ranked right now, including after switching
  to a profile that ranks differently. A row you choose yourself stays chosen while it's still offered and the ranking
  hasn't changed; once it's no longer offered, even for a moment, the cheapest is suggested again.
- Loot Helper: if the game can't say whether an item is a quest item at that moment, it isn't destroyed (try again).
- Disenchant Helper: auction prices, the item's and its materials', count after the auction house's 5% cut.
- Soulbound items can't be sold at the auction house, so BagSmith no longer gives them an AH value: their AH Price
  cell is empty and section totals leave them out; the Disenchant Helper says "Soulbound" and chooses only between
  Disenchant and Vendor; the Loot Helper counts them (and loot that binds when picked up) at their vendor price.
- Viewing another character: the note after the title says "read only" (the character picker already shows whose bags
  they are), and a long name is cut short so the picker fits.

Fixed:
- Disenchant Helper: during combat it no longer changes at all (clicking a row does nothing until combat ends), so it
  can't cause "action blocked" errors when you click it or when materials arrive.
- Disenchant Helper: closed during combat, it stays closed and its button stays off after combat, even if your bags
  changed in the meantime.
- Disenchant Helper: moving or resizing it when combat starts finishes when combat ends.
- Disenchant Helper: changing the style, accent color or profile during combat no longer touches it until combat ends
  (it could cause an "action blocked" error); it takes the new look then.
- Icon Corners: a corner already holding 16 marks keeps all of them now that Quest Starter joins it.

## 1.5.8

Changed:
- Tooltips wrap their longer lines, so they no longer stretch across the screen.
- Disenchant Helper: Mark as Junk is now a small button showing the pouch icon from List view, so it no longer covers
  the line beside it in narrower windows.
- Disenchant Helper: the results count now reads "in this range", with an info icon explaining that items of the same
  quality and level range share it.

## 1.5.7

Fixed:
- Disenchant Helper: turning it off, or switching to a profile where it's off, now closes it right away (during combat
  too) instead of leaving it open and usable.
- Disenchant Helper: it no longer causes "action blocked" errors when your bags change during combat, or when you try to
  move or resize it during combat (it waits until combat ends).
- Disenchant Helper: if you drop Enchanting while it's open, its button stops offering a disenchant.
- About & Support shows the right release date again (1.5.6 said November 7; it came out on the 8th).

## 1.5.6

Changed:
- Settings search shows the best matches first: a setting named after what you typed comes before one that only
  mentions it. Searching "Recent" now starts with Recent Items.

Fixed:
- Every BagSmith window now fades during combat, as the bags window does: the Disenchant Helper, the Loot Helper, both
  Exclusion List windows, the moved-items list, the Disenchant offer, What's New and Settings (Fade Windows During
  Combat).
- The Disenchant Helper can be closed during combat, with Escape or its close button. It disappears at once and
  finishes closing when combat ends. The game doesn't let it open during combat, and it now says so.

## 1.5.5

Changed:
- Travel Mode: Collapse All Sections now sits at the right end of the search box, so you can fold and unfold every
  section without leaving Travel Mode.
- Icons view no longer leaves empty room at the top for List view's column headers, so your items start higher.

Fixed:
- The search box and the buttons under the title fill the window from the first open of a session. Before, they could
  start out squeezed until you resized the window.

## 1.5.4

Fixed:
- Escape now closes the Loot Helper, the Disenchant Helper, the Disenchant offer (as Ask Later), both Exclusion List
  windows, the moved-items list and What's New, each just as its close button would. The Disenchant Helper waits
  until combat ends.
- Settings: the list of pages on the left can't run into About & Support any more. If it ever has more pages than fit,
  it tightens up, then scrolls with the mouse wheel.

## 1.5.3

Fixed:
- Disenchant Helper: the Disenchant button works in every game language. On a game that wasn't in English, it did
  nothing when clicked.
- Disenchant Helper: on a game that isn't in English, it reads your Enchanting skill again, so items above your skill
  are held back as they should be.

## 1.5.2

Fixed:
- Classic style: the bank window's search box no longer starts under the portrait.
- Loot Helper: after you loot one stack by hand while it's fetching another stack of the same item, it carries on by
  itself instead of waiting for your bags to change.
- Loot Helper: a grey item the game reports as grey only from its saved item details can be destroyed in one click
  again, instead of being offered and then refused.

## 1.5.1

Changed:
- Loot Helper: destroying an item happens at once, with no question, except blue and epic items (and anything whose
  quality the game hasn't reported), which still ask first, as the game does. Two new settings under Automations &
  Actions > Loot Helper: Ask Before Destroying (off) brings the question back for everything but junk, and Always Ask
  for Rare or Better (on) can be unticked so blue and epic items go at once too. Either setting applies at once, even
  to the Loot Helper already open. Junk always goes in one click. Clear Soul Shards follows Ask Before Destroying.

Fixed:
- Loot Helper: after you make room, it loots one item at a time and waits for each to reach your bags before taking
  the next. It no longer asks for an item that won't fit yet, which the game answered with "your bags are full". Two
  stacks of the same item are each waited for, and a stack only counts once all of it has arrived. If the game turns
  an item down, or doesn't answer, it isn't asked for again until your bags or the loot window change.
- Loot Helper: loot with no price (no vendor price, and no AH price yet) now gets suggestions too: your cheapest
  items, junk first, with a line saying why. Before, it offered nothing.
- Loot Helper: when nothing frees a slot, it names the bags the loot can't go in, such as a quiver, or a reagent bag
  for loot that isn't a crafting reagent.
- Loot Helper: it updates as soon as the game finishes loading an item's details, such as its price.
- Loot Helper: a question to destroy something closes if the reason it was offered changes while it's open, and
  nothing is destroyed for a reason that no longer holds. An item with no vendor price is never destroyed.
- The bags window no longer opens empty after a reload until you switch between List and Icons.
- Currencies under a header you've collapsed in the game's currency list stay in what your other characters see,
  even while the game doesn't report them, and update once it does.

## 1.5.0

New:
- Item Icons, a new settings page right below Style, with everything about item icons: Rarity Borders, Icon Size,
  Dim Junk, the Green Dot, Item Level, and the new Icon Corners.
- Icon Corners: choose what shows in each corner of your item icons. Each corner has a dropdown for the mark it
  shows, and you can add backups for items the first one doesn't apply to, so marks never overlap. Choosing a mark
  that's in another corner moves it; None leaves a corner empty; marks in no corner are listed as not shown. Two
  small previews show the result live: your icon and a List view row. It applies to every item icon: Icons
  view, List view, bag windows, the bank and other characters' bags. In List view, Item Level and Stack Count show
  in their columns instead, and the next mark in that corner takes their place. The stack count is protected:
  when an item has a stack it always shows, first in its corner; you can move it, but not hide it.
- Marks from other addons: addon authors can add their own marks through BagSmith's API (version 1.1), in the
  same shape many already use for other bag addons. A new mark takes its corner on its own; a mark you hide stays
  hidden. Each addon's marks keep the size that addon gives them, and show on List rows when the addon supports
  them there. /bs corners lists every mark and where it is.
- Split Consumables by Type (Settings > Sections, off by default): Consumables becomes sections of their own, Food,
  Drink, Potions, Elixirs, Flasks, Scrolls, Bandages, Item Enhancements and Other Consumables. Untick any type to
  keep it in Consumables. Food and Drink are told apart by what you do with them (eating or drinking), in your game's
  language; items that are both go to Food, and alcohol goes to Other Consumables so Drink stays drinks that
  restore mana. The Consumables tab and filters still include them all, and an item you moved to a section of your
  own stays there.
- Search: "food", "drink", "potion", "elixir", "flask", "scroll" and "bandage" find just those, with or without the
  split. /bs consumables shows what your game reports for each consumable.

Changed:
- BagSmith's own marks (the junk coin, the item level, the Pawn upgrade arrow, the gear-set shield and the stack
  count) are now icon corners too, in the same places as before. In Icons view a corner shows one mark at a time:
  an item that's both a Pawn upgrade and in two or more gear sets shows the arrow (or the shield, if you put it
  first). List rows follow the same corners, so hiding or moving a mark applies there too.
- Marks sit flush in their corners and always stay inside their own quarter of the icon. The gear-set shield
  scales with the icon, with its set count as a small badge on the shield.

Fixed:
- Your other characters' gold and currencies, when you view their bags, are right again (the game reports none
  while you log out, which had been saved as 0). Each character corrects itself the next time you play it, and a
  currency you spend or import just before logging out is saved right.
- Currencies under a header you've collapsed in the game's currency list no longer disappear from your pinned
  currencies, or from what your other characters see. Importing your Blizzard backpack currencies shows them at
  once, and unpinning one keeps it in your list.
- Item icons in your bags lose a second frame the game had started drawing (a white frame on common items, a
  heavier rarity border), so they match BagSmith's own look.
- Classic style: no more dark strips hanging below some of the bottom tabs.
- A BagSmith menu opened from Settings now closes when you click elsewhere or press Escape.
- Settings wording: "Icons view" for the view everywhere, and the Item Icons labels drop the repeated "on Icons"
  (Rarity Borders, Item Level (ilvl), Icon Size (Icons View), Green Dot on New Items, Dim Junk). Split View is now
  "Split View (Icons View)". The Show Empty Slots help names By Section (it still said "grouping by type").

## 1.4.2

Fixed:
- Potions, the Hearthstone and other items now show their cooldown on BagSmith's item buttons, in the bags window,
  the bank, individual bag windows and Recent. The time left is sized to fit inside each icon, in List rows and at
  any icon size; on the smallest icons only the darkening sweep shows. The numbers follow the game's own option
  for cooldown numbers.
- No more "Binding header BAGSMITH was attempted to be loaded more than once" warnings.
- Classic style: hovering the buttons at the top right lights the button up, instead of showing a square box
  behind it.

Changed:
- Settings > Style > Size: an info icon beside Icon Size explains that cooldown times show only when they fit
  inside an icon.

## 1.4.1

Fixed:
- After Clean Up Bags, the window redraws right away, even with your pointer over it. Items no longer show in two
  places (their pinned section and All Items) until you move the pointer away.
- Sort: Off in All view: moving an item out of a pinned section or Favorites no longer makes All Items jump. The
  item lands where you drop it and the slot it left goes to the end of All Items until you next open your bags;
  putting an item into a pinned section simply closes its gap. Opening the bags again, Clean Up, or changing the
  sort puts everything back in its true order.
- Shift-click splits a stack in an individual bag window, as in the game's own bags (with a chat box open, it links
  the item instead).

Changed:
- The toolbar keeps "Merge Stacks" at more window widths: when space runs short it hides the Sections and View
  labels first, and shortens Merge Stacks to Merge only if it still doesn't fit.
- Classic style: the grouping buttons (All, By Section, By Bag) and the List and Icons buttons now sit together as
  pairs, so they read as groups even without their labels.
- The Merge Stacks tooltip now explains both views: one row in List view, one icon in Icons.

## 1.4.0

New:
- Sort: Off. The Sort button and Settings > Sorting & Filters have an Off choice that shows items in bag order,
  where they actually sit in your bags, slot by slot (within each section when sections are on). In Icons view
  the empty slots stay where they are too, so the grid matches your bags.
- Pinned sections. Right-click a section's title and choose Pin to Top, or tick it under Settings > Sections >
  Pinned Sections. A pinned section shows at the top, after Recent. In All view its items get their own section
  there instead of the main list. By Bag ignores pins. A pinned custom section always shows, even while it's
  empty, so you can drop items onto its title. To take an item back out, drop it on the All Items title or on
  any slot among All Items.
- Drop into a free slot. In By Section or List view, which show no empty slots, an item you pick up from your
  bags (a split stack, say) can be dropped on the list and goes to the first empty slot that can hold it,
  never back onto its own stack.

Changed:
- The By Type grouping is now called By Section, in the bags window and in settings. In Classic style the
  grouping buttons share their space evenly, so every label has room.

Fixed:
- Disenchant Helper: in combat the Disenchant button and its keybinding now really do nothing. Since 1.2.0 they
  could stay ready on the last item instead of switching off.

## 1.3.1

Fixed:
- After selling junk, BagSmith waits for the vendor to finish before it reports, so a big sale reports one
  total instead of a false "didn't sell" warning for stacks that were still being sold. If something really
  doesn't sell, the message names it and points to the right button (Sell Junk for grey items, Sell Marked for
  marked ones), and the button's tooltip says which it will do.

## 1.3.0

New:
- Loot Helper, redesigned: what's waiting to loot comes first (each with its value and its own Skip and
  Exclude), then ways to free a slot without losing anything (Combine, Clean Up Bags), then the lowest-value
  items to let go. Pick a row and one button acts on it; destroying keeps its confirmation (junk goes in one
  click). A note says when an incoming item is worth less than anything you'd let go, and when nothing can
  free a slot the window says why. It opens beside the loot window, comes forward when clicked, and has a
  close button in the corner.
- Held-back counts: the Disenchant Helper's header and the Loot Helper say how many items they keep out and
  why (favorites, gear sets, quest items, Pawn upgrades, your Exclusion Lists, and the rest), with an info icon
  for the list. Junk selling says what it kept out of a sale.

Changed:
- Never is now Exclude, and the lists are the DE Exclusion List and the Loot Exclusion List. Your existing
  lists carry over.
- Classic style: the search bar and everything below it start at the window's inner margin, under the
  portrait, instead of beside it.
- Settings help lines name what each helper protects.

Fixed:
- A second right-click in a trade while BagSmith was still moving the first merged stack's followers could
  stop them and report "nothing moved" (nothing extra was ever placed).
- A hand-edited saved file with impossible numbers in the Disenchant Helper's learned results could stop
  the helper's window from opening; such entries are dropped on load.
- The Loot Helper now refuses to destroy anything when your gear sets can't be read, or when an item can't be
  told apart from another copy.
- The Loot Helper judges an item only against loot that could use its slot: a quiver's arrows are no longer
  offered to make room for a ring that can't go in a quiver.
- A destroy confirmation closes, and the destroy is refused, when the loot that justified it is gone before
  you click Yes (looted by someone else, or skipped).

## 1.2.0

New:
- Disenchant Helper (Settings > Automations & Actions, off by default): a window that lists the weapons
  and armor in your bags worth considering, with vendor, AH and materials values and a verdict, then
  walks you through it one click per item (or one press of the Disenchant Next Item keybinding). It
  uses Auctionator's prices when you have them, says "no price yet" (and which material) when a price is
  missing, and records every cast's actual results so its estimates become yours over time. Skip passes
  on an item, Never keeps it out for good, Mark as Junk sends a Sell verdict to the vendor path.
  Favorites, gear-set pieces, refundable and still-tradeable items stay out; epics only by setting.
- Auto-confirm prompts (same page, off by default): BagSmith clicks Yes on the yes/no boxes that follow
  its own actions (equipping a gear set, clicking an item, the Disenchant Helper), for the kinds you
  choose; a sub-setting widens it to those boxes wherever they come from. Hold Shift to keep a box open.

## 1.2.0

New:
- Disenchant Helper (Settings > Automations & Actions > Disenchant Helper, off by default): a window that
  lists the weapons and armor in your bags worth considering, with vendor, AH and materials values and a
  recommendation (Disenchant, Sell at AH, Vendor), then walks you through them one click at a time, or one
  press of the Disenchant Next Item keybinding. Skip, Never (with a Manage window), Mark as Junk. Likely
  results per item with rough odds; the helper records what your own disenchants produce and, once a kind of
  item has twenty behind it, estimates from your results. Needs Auctionator for AH prices. A toolbar button
  beside the Gear Sets shield while it is on; characters with Enchanting are offered it once (Add Now, Ask
  Later, Don't Ask Again, with Ask Again in settings). Before every click the helper checks the armed item
  against the live bag and your marks (the same item and instance, not a favorite, not in a gear set, not
  refundable or tradeable) and disarms itself if anything changed.
- Auto-confirm prompts (Settings > Automations & Actions > Prompts, off by default): BagSmith clicks Yes on
  the kinds of box you choose (bind-on-equip, use/loot binding, enchant replacement, loot rolls), only after
  your own BagSmith actions unless Also Outside BagSmith is on; choose which BagSmith actions count;
  Always, or only while Shift, Ctrl or a custom key is held; every confirmation is announced in chat.
- The Loot Helper and the Disenchant Helper have their own settings pages under Automations & Actions.

Changed:
- A merged row right-clicked at the mailbox or in the trade window sends the rest of its stacks after the
  first, as it already did at the bank, up to the window's free slots (chat says if some would not fit).
  Follow-ups are conservative: a job belongs to one mail or trade session, and in a trade a stack counts as
  placed only when the window is seen to take it.
- Settings rows can hold buttons side by side (Manage... and Clear All on the helper pages).
- Classic: new dialogs share the window chrome; the toolbar's new button wears the square frame.

## 1.1.0

New:
- Show Item Level (ilvl) on Icons (Settings > Style > Items, off by default): in the Icons view, weapons and
  armor show their item level in the icon's top-right corner, in a color of your choosing (blue by
  default) so it reads apart from the stack count, drawn under the quality ring, count and markers.

Changed:
- List view: the iLvl column shows a level only for weapons and armor that have one, and a dash
  otherwise; the required-level column is headed "Req lvl".
- Classic skin: every dialog (the copy-link and copy windows, confirmations, the section editor, Moved
  Items and Make Room) now wears the same window frame and background as the bags window, with its title
  in the title bar, so the whole addon looks like one thing; every dialog drags by its title bar (the
  confirm box and the section editor were never movable before). The
  Settings panel's scrollbar shows its arrows in Classic, like the bag window's. The section right-click
  menu keeps its menu border. Modern is unchanged.
- The Pawn upgrade arrow moved to the icon's bottom-left corner (the item level has the top-right); when
  the gear-set shield shares that corner, the arrow sits on the shield's top edge, smaller in compact
  list rows, and never overlaps it or leaves its row.

## 1.0.1

Fixed:
- Scrolling the bag window with the mouse wheel jumped and flickered, and the scrollbar's arrow buttons
  (Classic skin) often did nothing: the wheel's and the buttons' moves were being mistaken for moves the
  game made and undone. Your input is now recognized before the list moves. The scroll distance per
  wheel notch is unchanged.

## 1.0.0

New:
- Plugins: BagSmith can be extended by separate, optional addons through a small public API
  (BagSmith.API 1.0). Settings > Plugins lists installed plugins with their status, lets you enable or
  disable one for the current character (taking effect after a reload you request), and shows the
  official ones. BagSmith is complete without any plugin.
- BagSmith Gamepad, the first official companion, is coming soon: controller browsing of your bags
  under the game's Controller UI. It is in alpha testing; testers will be wanted when it reaches beta
  (see the Discord). Installed separately; browsing stays off until you turn it on in its options.

Changed:
- The controller experiments of the 0.15 development builds left core; the one-press bag opener fix
  from that work stays. A controller-browsing preference set in those builds migrates once into the
  companion's own namespace.

## 0.15.0

New:
- Gear Sets: your gear sets (the game's own equipment sets, from the
  Equipment Manager in your character window) each show as a section in your
  bags, holding the set's items that are in your bags. A set's title shows its
  icon and a muted "Gear Set:" before its name, and an Equip button that puts
  the whole set on with the game's own swap. If something can't come along,
  chat says what, for example "Equipped Tank, except Hands (in your bank)."
  Not during combat. A set you're wearing still shows its title, marked Worn,
  with where its items are on the right (for example "All 10 items worn").
  Right-click a set's title for Equip, Update from What I'm Wearing..., Put on
  Action Bar, and Show Gear Sets at Vendor / at Auction House. Searching a
  set's name finds its items, and the item menu says which sets an item is in.
- Gear Sets has one place in Section Order (at the bottom by default; drag
  any set's title to move them all) and one row in Vendors & Auction House.
- Gear Sets tab: a built-in tab (just before Bank) with every gear set, slot
  by slot from Head to Tabard. Items in your bags are the real items; worn and
  banked pieces show as display-only rows marked Worn or Bank, and a missing
  piece shows as a muted row. Each set's title says where its items are, with
  Equip when some are in your bags. With no sets yet, the tab offers Create
  Gear Set. A shield icon in the top-right row, left of Bank, opens it.
- An item in more than one gear set shows in each set's section, every
  showing working like the item itself, with a small shield and the number of
  sets it's in. Everything else (free slots, selling) still counts it once.
- Settings > Dynamic Sections > Gear Sets: Show Gear Sets as Sections, New
  Gear Set... (saves what you're wearing, shirt and tabard left out), and
  each set with where its items are, Put on Action Bar (click or drag its
  icon), Rename and Delete. Gear sets are managed in Blizzard's Equipment
  Manager.
- Items in a gear set are protected: they can't be marked as junk, BagSmith
  never sells them, and the Loot Helper never offers them. Both check where
  the game says your set items are right before acting. Blizzard's own Sell
  All Junk button still sells grey items, as always.
- Settings search: a box to the right of the profile line (both skins).
  Typing shows one scrollable list: each page with a match under its name,
  then only the matching cards and settings, which work right there. A page
  or card whose name matches shows whole; a setting indented under another
  shows with it; explanation paragraphs show only with their whole card.
  Every word you type has to match. "No results found" when nothing does.
  Clearing the box or opening a page ends the search. About & Support isn't
  searched (it has its own button).

Changed:
- Settings is reorganized: Sections (with Dynamic Sections and Custom
  Sections under it), Columns (Item Menu Button, with Bag Columns and Bank
  Columns under it) and Sheets (Sheets Remember Their View, with Bag Sheets
  and Bank Sheets under it). The list folds: sub-pages show under their page
  while it or one of them is open, with a small arrow on the three. The
  Bags/Bank switches on Columns and Sheets are gone.
- Settings > Bag Columns / Bank Columns: Item shows a dimmed checkmark;
  hovering explains it's always shown but can be moved.
- A saved sheet named "GearSets" (the new tab's name) is renamed
  "GearSets (2)" when you update or import a profile, keeping its filter, tab
  place, hidden state and saved view.
- Recent Items now lists only what came from outside: loot, vendors, mail,
  trades, quest rewards and crafting. Gear you take off (or a gear set swaps
  off), items from the bank (including the first bank visit), and combining
  or splitting stacks no longer count as new, and those items keep their age.
  At the bank, where your bags and the bank update a moment apart, BagSmith
  lets moves settle for a second and works out stack by stack what moved and
  what you actually picked up; a stack split off another takes its age.
- What's New: a tab for each of the last five notable releases, opening on
  the newest (after an update, on that update), one size across tabs,
  stronger zebra stripes, a light line between bullets, and a stronger line
  above the footer, which reads "Previous Updates & Patches: See full
  changelog @ CurseForge:".
- By Type always gives keys their own section, at Keys' place in Section
  Order. The settings read "Keys in Their Own Section (All and By Bag)" and
  "Reagent Bag (Sections: All)".
- The item menu marks an item's own section "(default)" instead of "(usual)".
- Classic skin: the Bank Bags strip in the bank window uses the same frames
  as the bag slots on Blizzard's bag bar. An empty bank bag slot shows the
  empty bag picture; slots you haven't bought stay dimmed.
- /bs check lists your gear sets and what this client offers for them.
  /bs debug logs Pawn's refresh signals, what Pawn was asked and answered,
  and arrows appearing or going.

Fixed:
- Pawn's upgrade arrow could stay missing (items near the bottom of the
  list, an item you just took off) until you switched tabs. BagSmith now
  remembers Pawn's answers, asks only about items still waiting (taking
  turns, so Pawn's time budget isn't spent on items already answered), keeps
  checking more slowly instead of giving up, and re-checks right away when
  Pawn says it has updated, after a gear change, or when a newly shown item
  is waiting. Changing Pawn's scales or settings, or turning its bag advisor
  off or on, now updates the arrows right away whether or not BagSmith
  replaces Blizzard's bags. An arrow no longer flickers off while Pawn is
  still working out its answer. The Loot Helper still asks Pawn fresh right
  before destroying anything.
- The bags list could go blank in icon view after changing Scale (or when
  its area changed size, for example at the bank) until you switched views.
  After any scale or size change, BagSmith now has the game lay the list out
  again, and keeps it from being left scrolled past its end.
- /bs skincheck no longer says the close button is missing when the bags
  window is simply closed.

## 0.14.0

New:
- Custom Sections: make your own sections and move any item into them, or
  into a different built-in section. Drag an item onto a section title
  (Sections By Type; the item stays where it is in your bags), use the item
  menu, or the Move to Section keybinding. Moves apply to every copy of an
  item and belong to the profile. Dropping an item on the Favorites title
  favorites it; on the Junk title marks it. Reset to Its Original Section
  undoes a move. Settings > Sections manages your sections (rename, delete,
  Show When Empty), the moved items (Manage..., Reset All) and explains which
  section an item goes to: a junk mark, then Favorites, then your move, then
  its usual section.
- Item menu: Alt+Left-click an item, or the Item Menu Button (three dots at
  the left of each list row, Settings > Columns), for Move to Section, Reset
  to Its Original Section, Favorite, Mark as Junk and Track as Currency.
- Show at Vendor / Show at Auction House for every section, Favorites
  included (right-click a section title, or Settings > Sections). Hidden
  sections drop out of every view while a vendor or the auction house is
  open; a note at the end of the list offers Show Them and Hide Again, and
  bag windows show hidden items locked. Blizzard's Sell All Junk button
  always sells every grey item, favorites and hidden sections included;
  BagSmith's own junk selling follows the same rule, and chat says so after
  a sale that included one.
- Moving merged stacks at the bank: right-click a merged row (or drag it to
  the other window) and all of that item's stacks move, one at a time, with
  an exact count of what moved. Bank moves only.
- Show Empty Custom Sections (on by default): your sections show their title
  even with nothing in them, ready to drag items onto; each can opt out.
- Search matches a section's name as well as an item's own type.
- Keybindings: setting a key already bound elsewhere asks first and says
  what will be unbound. Settings > Keybindings notes the item menu and any
  of the game's item modifiers that are also on Alt.
- Clear Recent Also Clears Green Dots (Settings > Style, on by default).
- About & Support: the version and release date, a note from the author,
  and links to CurseForge, Buy Me a Coffee and the Discord.

Changed:
- The reagent bag is a place, not a type: with Sections By Type, its items
  sort by type; Reagent Bag: Own Section applies when Sections is All.
- Classic: dialog windows and menus are fully solid, on Blizzard's own dark
  dialog background.
- Custom sections join the built-in types under "Type / Sections" in the
  Filter panel and in Sheets, and the Filter panel keeps up with them.
- Settings: each sub-section sits on its own card, with a hairline between
  settings, so a long page is easier to skim. The Style page is grouped
  (Skin, Colors, Items, Size, Layout); Icon Split View and Show Empty Slots
  moved there from Settings > Sections, and Compact Rows sits with Row
  Height. The scrollbar only shows when a page is taller than the window.
- What's New: a wider card with faint stripes behind every other bullet,
  and a Discord button.
- Classic: the close button and the Travel Mode button beside it sit half a
  pixel lower, in line with the title strip.

Fixed:
- Saved characters' items follow the current profile's sections; a token
  moved out of Tokens stays a currency; the bank window's Clean Up sorts
  the bank; an automatic junk sale's delayed retry re-checks that automatic
  selling is still on; importing a profile keeps its sheets' filters.

## 0.13.2

New:
- About & Support (Settings, bottom left above What's New): BagSmith's icon, the
  version and release date, a note from the author, and links to the
  CurseForge page, Buy Me a Coffee and the BagSmith Discord (for feedback,
  bugs and feature requests). Addons can't open web pages, so each link
  shows its address ready to copy.
- Settings: the scrollbar only shows when a page is taller than the window.

## 0.13.1

New:
- Fade Minimap Button (Settings > General): shows BagSmith's minimap button
  only while the pointer is over the minimap.
- Settings > Style: a Reload Interface button beside the skin choice, for
  peace of mind after switching skins (switching never needs a reload).

Changed:
- The minimap button is now made the standard way (LibDataBroker and
  LibDBIcon), so UI addons and minimap button managers such as MayronUI,
  ElvUI and SexyMap can fade, hide or collect it like other addons' buttons.
  Its look, clicks and position are the same.

## 0.13.0

New:
- Bag Bar: the button left of the counts in the footer opens a strip of
  your bags, in the same order as Blizzard's bag bar: a narrow Keys slot,
  the reagent bag, bags 4 to 1 and the backpack at the far right. Drag a bag
  on to equip or swap it, drag it off to take it out, click a bag to open
  its own window. The Keys slot lists the keys you carry; click it to show
  only them, and again to go back. Works in Travel Mode too. In Classic the
  slots use the frames of Blizzard's bag bar and the Keys slot its keyring
  art. Optional: Hide Blizzard's Bag Bar (Settings > General).
- Sell Junk + Mark as Junk: the Junk column (the pouch) in list view marks
  any item as junk; marked items get the junk coin, move to the Junk
  section, and sell along with your greys at a vendor. Mark as Junk
  keybinding. Optional: Dim Junk Items (Settings > Style) and Sell Junk
  Automatically at Vendors (Settings > Automations & Actions, off by
  default). If the game wants a click to sell, a Sell Marked button appears
  on the vendor window.
- Loot Helper: when loot, or a quest's reward or item, won't fit, a panel
  lists what's waiting and ways to make room: combine stacks, Clean Up Bags
  (only when it helps), and items to destroy, junk first and then the
  cheapest, only from bags the waiting item can use, and never favorites,
  quest items or Pawn upgrades. Junk goes in one click; anything else asks
  first, and nothing is destroyed unless it's still exactly what was
  offered. Loot is picked up once there's room (quests stay your click).
  Skip or Never Ask (manage that list in Settings). Settings > Automations
  & Actions.
- Favorites: the Favorite column (the star). Starred items move into a
  Favorites section at the top; move it in Section Order or turn it off
  under Special Sections. Favorite Item keybinding.
- Track as Currency: the Currency column (the wallet). Tracked items show in
  the currency drawer with their count, even at zero. Add any item from the
  drawer's Add Item box (search, or paste an item link or ID). Track as
  Currency keybinding.
- Clear Soul Shards (Warlock): destroy shards kept in ordinary bags, one
  click each after one confirmation; Soul Shards to Keep sets a minimum.
- Profile Sharing: copy a profile as a code to keep or share, or import one
  as a new profile. Settings > Profile.
- Keybindings: BagSmith has its own section in the game's Keybindings, and a
  Keybindings page in Settings: Mark as Junk, Favorite Item, Track as
  Currency, Toggle Travel Mode, Toggle Currency Drawer. Item tooltips show
  the keys once set.
- Pawn Support: with Pawn's bag upgrade advisor on, its green upgrade arrow
  shows on BagSmith's item icons.
- Clean Up Bags When Opened (off by default) and Leave Travel Mode When
  Trading.

Changed:
- New players start in the Classic skin, with the window set to Scalable
  (the new name for Fixed Size). Existing settings are kept.
- Windows can be up to 1400 wide (and 1200 tall, as before).
- Settings: a new General page first (Open with the Bag Keybind, Show
  Minimap Button, Replace the Bank Window, Hide Blizzard's Bag Bar, Hide the
  Login Message, Show What's New); new Automations & Actions and Keybindings
  pages; Profile sits just before Advanced; "Sorting and Filters" is now
  "Sorting & Filters".
- When the list doesn't scroll, the scrollbar is hidden and the list uses
  its space, so the margins match.
- Currencies shown in the footer are now "pinned", with a push pin in the
  drawer (item Favorites are the star).
- The Favorite, Currency and Junk columns share one set of icons; any that's
  on is gold. Hovering where an icon would be, on an item that can't take
  it, says why.
- The new-item dot sits at the bottom center of the icon, in hunter green.
- Merge Stacks only joins stackable items; different pieces of gear that
  share an item ID keep their own rows.
- Classic: buttons in pop-ups always have the Classic look, and the square
  toolbar buttons are pushed in while on.
- What's New: a line under the title explains the card; the full changelog
  covers every update.

Fixed:
- Resizing the window keeps it where you leave it: no more jumping back,
  away from the screen edge, or to its old size while you drag.
- Switching profiles updates everything that belongs to the profile at once
  (sheets, tracked currencies, window spots and scale, bank window choice).
- Settings: one mouse wheel notch moves about two rows (it skipped
  sections); closing Settings while "Press a key..." is waiting cancels it.
- Key names are spelled out ("Ctrl-J", not "C-J"), and BagSmith's tooltip
  lines no longer vanish when the game refreshes a tooltip.
- The age filter's "at least" no longer also hides items older than 9 hours.
- The Where filter offers the bags the window is actually showing, with a
  saved character's own bag names.
- Dropping an item onto a window says what will really happen.
- In combat, a row whose item is used up is blanked instead of showing it.
- Classic: logging in with Travel Mode on no longer shows the character
  picker's dropdown inside the search box, and item icons whose art runs to
  the edge no longer show a corner outside their frame.
- Blizzard's "You've obtained a reagent bag! Open your bag." tip no longer
  stays up while BagSmith replaces your bags (it waited for Blizzard's own
  bag window, which BagSmith replaces).
- Hardening against edited or damaged saved data and share codes.

## 0.12.0

New:
- Travel Mode: a compact, on-the-go view for adventuring. The signpost
  button beside the close button hides the Filter button, the toolbar and the
  character picker, moves the search box into the title row, and lets your
  items fill the space; the title reads "Your Bags (Travel Mode)". Click it
  again anytime for your full inventory tools. Remembered across a reload and
  logins. Bags window only, in both skins (in Classic, a red button beside the
  close button, pushed in while on).
- Auto Travel Mode (Settings > Window): Travel Mode can switch off while the
  bank, the auction house or a vendor is open, or while you're on a flight
  path, and back on afterwards. Each has its own setting, on by default. The
  signpost's tooltip says why when it's switched off.
- What's New: the card is titled "What's New", with each release's heading in
  the body, and explains that every update, including small fixes, is in the
  full changelog.

Changed:
- Settings > Windows: bag window settings grouped under Bag Windows, the
  currency drawer under its own heading, and Auto Travel Mode as its own
  section.
- Modern: a thin divider separates the tool icons from the Travel Mode and
  close buttons in the bags window's title row.

Fixed (found by an outside code review):
- Reset to Defaults and Delete Profile act on exactly the profile named in
  the question, and changing profiles closes an open confirmation.
- Switching (or resetting, copying or deleting) a profile no longer leaves a
  sheet selected that the new profile doesn't have, which made the bags look
  empty.
- Blizzard's bank window, when shown (Replace the Bank Window turned off, or
  to buy a bank slot), comes back where it belongs instead of staying off
  screen.
- With Merge Stacks and a filter, rows holding still no longer count stacks
  the filter hides.
- A stack whose new-item marker you dismissed shows as new again when it
  grows after being used down.
- An item's category is no longer stuck from before the game supplied all its
  details.
- The Bank tab before your first bank visit no longer shows your bags' slot
  count.
- A scroll right after the list corrected itself is no longer undone.
- Closing the bank right after a change saves the latest bank even with a
  rescan still waiting.

## 0.11.2

Changed:
- Recent Items with Merge Stacks on: once an item shows in Recent, it stays
  there while you still have any of it, even after the newly looted stack is
  used up. It leaves when the item is gone entirely, on Clear Recent, or when
  it falls outside the Last Hour or Last 15 Min window.

Fixed (several found by outside code reviews):
- With Merge Stacks on, while rows hold still under the pointer, a row whose
  stack ran out could show another stack of the item while a click used its
  original bag slot (possibly a newly looted item). Rows now always show
  what's in their own slot, and an item landing in a blank row or empty slot
  shows at once.
- Closing the bank right after moving an item no longer leaves the saved bank
  (what other characters and offline views show) a step behind.
- Bank items' ages no longer reset after logging in away from the bank.
- Tokens kept in the bank count in the currency totals right after a login or
  /reload.
- Token counts in the drawer and footer update on the same refresh as the
  change.
- Viewing another character, or the bank away from it, a money or currency
  change no longer turns the saved free-slot count into 0/0.
- Sheets Remember Their View: renaming a sheet keeps its view, and deleting
  one clears it. Deleting a bank sheet now cleans up the bank's hidden-tab
  list, not the bags window's.

## 0.11.1

Changed:
- Settings > Windows: one choice, "When the Main Window Opens": Open Main
  Window Only, Auto-Open All Bags (every bag, including the reagent bag) or
  Auto-Open Reagent Bag. It replaces the two checkboxes for bag windows and
  the reagent bag's window; your current choice carries over.
- Settings > Sections: Reagent Bag is Mixed In or Own Section. The Own Window
  option is gone; if you used it, your reagent bag is now its own section and
  its window opens with your bags, so nothing disappears. The footer's
  reagent button opens or closes that window in either mode.
- Settings > Sections: in Section Order, Recent Items, Keys and Reagent Bag
  are dimmed with "(off)" when they aren't active, and hovering one says how
  to turn it on. They can still be moved, so their place can be set ahead.
- What's New: the changelog address points to the CurseForge files page, on
  one line with a copy button. Addons can't write to the clipboard, so the
  button selects the address and says to press Ctrl+C (Cmd+C on a Mac).

## 0.11.0

Changes since 0.10.6:

New:
- Recent Items (on by default): what you picked up since logging in, newest
  first, in a section at the top of your bags window. The items also stay in
  their usual section (the header says so), and the copies work exactly like
  the originals. Clear Recent in its header empties the list. Options in
  Settings > Sections: since login, the last hour or the last 15 minutes, and
  how many to show. It sits in Section Order (top by default) and can be
  moved like any section; with Sections set to All, the rest of your items
  get an All Items header below it. Items already in your bags at login don't
  count; a /reload keeps the list. Bags window only.
- Icon Split View (Settings > Sections): in icon view, sections sit side by
  side in two columns, filling left to right, top to bottom. Needs Sections
  By Type or By Bag; a narrow window shows one column.
- AH Price column (Settings > Columns): prices from Auctionator's last scan,
  as the stack's value, or "-" when an item hasn't been scanned. Off until
  ticked; greyed out, with a tooltip explaining why, without Auctionator.
  Sortable, and the item tooltip shows the price each and how old it is.
- Sheets Remember Their View (Settings > Sheets, off by default): each sheet
  tab keeps its own Sections, Sort, View, Merge Stacks and collapsed
  sections. The All tab uses the window's settings.
- What's New: after a notable update, a small card beside the bags window
  shows what's new the first time you open your bags (never at login or in
  combat, not on a first install, once per account). A What's New button at
  the bottom left of Settings, or /bs new, shows it any time. Turn it off on
  the Advanced page.

Changed:
- Section headers show the item count beside the name, "Trade Goods (11)",
  and the section's vendor value on the right ("V: 6s 27c"), plus its AH
  total while the AH Price column is on ("AH: 19s 70c"). Every header in a
  window uses the same format; when space is short they stack as a small
  aligned table. Hovering a header explains the numbers.
- Settings > Sections is grouped into Sections, Layout, Special Sections and
  Section Order. "Keys Get Their Own Section" is now "Keys in Their Own
  Section".
- The Section Order, Columns and Sheets lists in Settings have zebra stripes
  and highlight the row under the pointer.
- While browsing another character, the bag and reagent buttons in the
  footer are greyed out (bag windows show your own bags).

Fixed:
- Closing Settings with Esc no longer leaves its icon lit in the bags window.
- If one window fails to draw, the others still do, and the error shows in
  /bs errors. /bs check now lists each bag window's state, to help with an
  intermittent report of bag windows not showing until a /reload.

## 0.10.6

Both skins:
- Fixed: after opening and closing the game menu, the first press of the bag
  key could play the bag sound but leave the bags open; a second press
  worked. Thanks to the player who reported it with clear steps. One press
  of the bag key now always opens or closes BagSmith exactly once.
- /bs debug now logs every bag call BagSmith hears (what ran, what BagSmith
  did, the window before and after, and what called it), to help with any
  future bag key reports.

## 0.10.5

Both skins:
- The bag count and the reagent count in the footer are buttons now, each
  with its icon and count side by side, so they read as something to click:
  they open the bag windows and the reagent window. Same footer height.
  Modern uses the same chip and hover as the other buttons, with an accent
  border while those windows are open; Classic uses Blizzard's red button
  art, gold while they're open. The bank window's bag count works the same.
- When you try to swap a bag into the slot of the bag it's stored in, which
  the game refuses ("Can't put non-empty bags in other bags."), BagSmith
  explains why and what to do: "The game can't swap a bag into the slot of
  the bag it's stored in. Move the new bag out of that bag first." It shows
  in yellow just below the game's error for about 8 seconds, and in chat.
  Works on Blizzard's bag bar and on BagSmith's Bank Bags strip.
- The gold amount in the footer sits a little further in from the left.
  Favorite currencies still fit at the narrowest window, and once one
  doesn't fit the rest go into "+N" so they stay in order.

## 0.10.4

Everything from the 0.10.4 betas, released. Changes since 0.10.3:

Both skins:
- Column widths: every line between two column headers can be dragged,
  including both lines beside Item. The line follows the pointer and only
  the two columns touching it change; every other column stays put. Item is
  still the only column that grows and shrinks with the window, so rows
  always fill. Limits: 30 to 400 px for a column, 90 px at least for Item.
  Double-click a line to reset both of its columns. Resize the last column
  from its left line (the row's far right edge is no longer a handle).
- Columns always fit the window: when it's too narrow for their widths they
  shrink in proportion (none below 30 px) instead of the last column
  spilling past the window's edge, and a wider window brings your widths
  back. The column header never draws past the row's edge.

Classic:
- The character picker's arrow sits half a pixel higher, evening its gaps
  above and below.

## 0.10.4-beta2 (beta)

Both skins:
- Columns always fit the window. When the window is too narrow for the
  columns' widths, they shrink in proportion (none below 30 px; Item keeps
  its 90 px) instead of the last column spilling past the window's edge.
  Your saved widths are kept, so a wider window brings them back exactly.
  The column header never draws past the row's edge.
- Dragging a line while the columns are squeezed keeps what you see for
  every column first, so the line follows the pointer. (Those squeezed
  widths become that window's saved widths.)

## 0.10.4-beta1 (beta)

Both skins:
- Column widths: every line between two columns can be dragged, and the
  line follows the pointer. Only the two columns touching it change, one
  wider and the other narrower by the same amount; every other column stays
  put. Item is still the only column that grows and shrinks with the window,
  so rows always fill. This gives Item handles too: drag the line on either
  side of it. Limits: 30 to 400 px for a column, 90 px at least for Item.
  Double-click a line to reset both of its columns. The row's far right edge
  is no longer a handle; resize the last column from its left line.
  Before, a grip sat on each column's right edge and changed only that
  column while Item made up the difference, so with Item first the line you
  grabbed stayed put and the column's left edge moved instead.

## 0.10.3

Both skins:
- Columns no longer shrink, and header names no longer vanish, after the
  bank window opens or a window is resized. Right after a window opens or
  changes size the game may report its width as 0 for a moment; BagSmith
  laid the columns out from that and squeezed them into 200 px. A bad read
  now uses the last width it trusted for that window (adjusted for the
  window's size) and lays the columns out again on the next frame, and any
  real change in the list's width re-plans the columns once the resize grip
  is released.
- Dragging a column's edge starts from its real width, so a drag can't save
  a width taken from a squeezed layout. (If a column stayed narrow after this
  bug, double-click the line at its right edge to reset it.)

## 0.10.2

Both skins:
- Item tooltips no longer jump from one side of the item to the other a
  moment after they appear. BagSmith placed them on the right, then
  Blizzard's bag button re-placed them by its own rule a split second later
  (to the left on the right half of the screen, where the bags window sits).
  Tooltips now go where Blizzard's rule puts them from the start, in every
  window: left of items on the right half of the screen, right of the rest.
  /bs check reports which placement is in use.
- Settings > Sheets works like Columns: pick Bags Window or Bank Window,
  then one list for that window, instead of both lists stacked.

## 0.10.1

Both skins:
- Item icons always have a thin frame. With Rarity Borders on Off, or on
  Green and Up for grey and white items, icons now get a dark neutral frame
  in the same style as the rarity border, instead of none. Empty slots stay
  as they are.
- The search box and Filter end where the toolbar ends: Filter's right edge
  lines up with the Icons button at any window width, in the bags and bank
  windows.
- The window's drag area at the top ends exactly where the search row
  begins. In Classic, the bank window's Filter button only responded on its
  lower half, because the drag area covered the rest.

Modern:
- Buttons react to the pointer. Text buttons, tabs, the Sections and View
  buttons, icon buttons, column headers, footer currency chips, bank bag
  slots, favorite stars, Settings categories, the character list and
  section headers all show a clear hover, and return to rest when the
  pointer leaves. Selected buttons keep their accent border on hover.

Classic:
- The arrow on the character picker sits 2 px further right, matching its
  gaps above and below.

## 0.10.0

Everything from the 0.10.0 betas, released. Changes since 0.9.19:

New:
- Classic skin (Settings > Style > Skin): a mimic of Forever's own bag
  frames, drawn from Blizzard's art in the game files: round portrait with
  the BagSmith icon (each bag's own icon on bag windows), gold title strip,
  red close button, red panel buttons, tabs hanging below the window, the
  Appearances background, a flat gold bar and the classic scrollbar.
  Settings, the Filter panel, the currency drawer, the confirm dialog and
  the bag windows are dressed too. Switching skins is live. /bs skincheck
  lists each piece and what this client provided.

Changed:
- Bag windows follow the main Scale. Bag Window Scale now applies on top of
  it (100% matches the main window); before, bag windows ignored Scale.
  If you set both, your bag windows may look a different size.
- Collapse All (and clicking a section header) only affects the window you
  clicked in; the bags and bank windows keep separate lists.
- Labels are Title Case throughout ("Merge Stacks", "By Type", "Import
  Blizzard Picks"); help text and messages stay sentence case.
- The sort button names its order ("Sort: Newest").
- Bank Bags has a little more room below the toolbar.
- Bag windows: the grid sits clear of the header band instead of touching it.

Fixed:
- The bank window's Filter button and "+" did nothing after the bags
  window's Filter panel had been dragged: the bank's panel opened with no
  position and never drew.

## 0.10.0-beta8 (beta branch)

Both skins:
- The bank window's Filter button and "+" (new sheet) open the Filter
  panel again. After dragging the bags window's Filter panel, the bank's
  panel opened with no position at all, so it never drew. Each window's
  panel now remembers on its own that it was moved, and a panel without a
  position is always placed under its window's search box. (Prod 0.9.19
  has the same bug; this ships to prod with Classic.)

Classic:
- Bag windows keep a minimum height, so Blizzard's left border always
  starts below the portrait ring. On one-row bag windows the border ran
  through the ring and the icon: the window was shorter than Blizzard's
  corner pieces need. One-row bags get a little room under their slots;
  taller bags are unchanged. The minimum is the proven height of a two-row
  bag window (160), raised if the frame art reports it needs more.
- The beta7 change that reordered the pieces inside Blizzard's border is
  removed: it wasn't the cause.
- /bs skincheck reports the bag window minimum height (and whether the
  frame art could be measured) and each open bag window's height.

Tests:
- Filter panel placement for the bank through Filter, "+" and the pencil,
  after the other window's panel was moved (these fail on beta7).
- Bag window minimum in Classic, none in Modern, and Modern's height back
  after switching. Classic baseline re-recorded: only the bag window's
  height changed.

## 0.10.0-beta7 (beta branch)

Both skins:
- Bag windows follow the main Scale (Style page). Bag Window Scale now
  applies on top of it, so 100% matches the main window. Before, bag
  windows ignored the main Scale entirely.

Modern:
- The Sections and View groups keep their outline after leaving Classic.
  In a session that started in Classic, switching to Modern could leave
  the group outlines off (bags and bank windows), depending on which piece
  the skin change reached first. Classic now repaints Modern's colors as
  its very last step when it turns off.
- The Filter panel repaints its colors on every skin change. If it was
  first opened in Classic, it kept Classic's gold headings and lines in
  Modern.
- Bag windows: the grid sits 8 px clear of the header band, the same room
  it has at its sides, instead of touching it.

Classic:
- The corner ornaments are dimmed to 40%, so they read as part of the
  stone rather than something the last rows and the scrollbar sit on.
- The gold bar is one flat tone with a thin bronze border, drawn on the
  frame's background layer. Blizzard's inset template is no longer used:
  its edges carried a baked-in shadow, and its fill was covered by the
  background.
- Close buttons on every window take the spot Blizzard's template gives
  its own close button, inside the frame's corner. The bag windows,
  Settings, Filter panel and currency drawer used a fixed spot that hung
  over the right edge.
- The portrait ring always draws above the frame's edges. On some windows
  the left edge crossed over the ring and the icon.
- Currency drawer: the list, its scrollbar and the Import button move in
  clear of the thicker border, and the rows narrow to fit.
- /bs skincheck reports where each close button got its spot, the gold
  bar, the corner strength and the portrait ring layering.

Text:
- "Import Blizzard Picks" is Title Case.

Tests:
- The mock client records colors (backdrops, text, textures), alpha and
  draw layers, so the checks can see a lost outline or a wrong color.
- The Modern comparison checks colors as well as layout and covers the
  currency drawer. Baseline re-recorded from prod 0.9.19; the deliberate
  differences (Bank Bags gap, bag window grid gap) are listed in its header.
- New Classic comparison with its own baseline, so Modern work can't move
  Classic either.

## 0.10.0-beta6 (beta branch)

Both skins:
- Collapse All (and clicking a section header) only affects the window you
  clicked in. The bags and bank windows shared one list of collapsed
  sections, so collapsing in one collapsed matching sections in the other.
  Each window now keeps its own, with or without Remember.
- Bank Bags has a little more room below the toolbar.

Classic:
- Empty slots use Forever's newer slot art, read from Blizzard's own bag
  button template, without the old heavy ring.
- A light shade of Modern's background darkens the Blizzard background so
  rows and text read better.
- The corner ornaments are flipped the right way up.
- The gold bar is flat like Blizzard's backpack bar, without an inner shadow.
- Bag windows no longer clip their last column: the title row only moves
  down to clear the portrait, so the grid stays where it belongs.
- The Filter panel's buttons are red from the first open in a session.
- /bs skincheck reports where the empty-slot art came from.

The permanent prod comparison now also covers the bank window (the Bank Bags
gap is the one deliberate difference).

## 0.10.0-beta5 (beta branch)

Classic for the other windows:
- Settings: Blizzard's window frame with the BagSmith portrait, the title in
  the strip, the red close button, and Blizzard's red buttons for every
  choice, including on pages opened later.
- Filter panel and currency drawer: Blizzard's window frame (no portrait),
  title in the strip, red close button, red buttons.
- Confirm dialog: Blizzard's dialog border with red Yes and Cancel.
- Small bag windows (backpack, each bag, reagent, bank bags): Blizzard's bag
  frame with each bag's own icon in the portrait and its name in the strip,
  like Forever's bags.

Classic fixes:
- The Appearances background now shows: the template's own dark fill and
  BagSmith's fill were covering it. Both step aside when a Blizzard
  background loads, and /bs skincheck lists what was hidden.
- The broom uses BagSmith's own icon in the same square button as Bank,
  Currencies and Settings.

Modern is still untouched: the permanent prod comparison now also covers
Settings, the Filter panel and a bag window, in all three cases.

## 0.10.0-beta4 (beta branch)

Both skins:
- Title Case for everything that names something (window titles, headings,
  buttons, tabs, settings, sections), matching Blizzard. Help text, hints and
  messages stay in sentence case; item names and your own sheet and profile
  names are unchanged.
- The Sort button names its order: Sort: Quality, Newest, Oldest, Name, iLvl.

Classic:
- Bank, Currencies, Settings and back-to-own-bags use Blizzard's square
  buttons with BagSmith's icons in gold.
- The character picker uses Blizzard's dropdown look.
- The Appearances background (warm stone with filigree corners) replaces
  the plain stone when the client has it.
- No more gold outlines around the Sections and View groups.
- /bs skincheck lists the new pieces (square buttons, dropdown, Appearances
  background and corners).

## 0.10.0-beta3 (beta branch)

Modern is protected while Classic is built:
- A session that started in Classic left the tab row's "+" and pencil at
  Classic's size after switching to Modern, so they sat a few pixels low.
  Everything is now created at its Modern size; Classic only adjusts it.
- Classic's code no longer touches a window in Modern unless Classic has
  been on for it this session. Switching back restores the Modern layout as
  it was recorded, instead of values retyped by hand.
- New permanent test: the Modern layout must match prod 0.9.19 exactly in a
  fresh session, after switching to Classic and back, and in a session that
  starts in Classic.

Classic:
- The red close button is raised above Blizzard's frame border (which was
  covering it) and placed where Blizzard's own close button sits.
  /bs skincheck now also says whether it is actually visible.
- The "+" and pencil beside the tabs are tabs themselves.
- The portrait zooms past the icon's own square frame.

## 0.10.0-beta2 (beta branch)

Classic skin fixes from the first look on Forever:
- The red close button now shows (top right of the title strip) and closes
  the window.
- BagSmith's full-color icon fills the round portrait, clipped with
  Blizzard's portrait mask (the game would not crop an addon's icon itself).
- Blizzard's textured stone background behind the content.
- Tabs hang below the window like Blizzard's, the selected tab uses
  Blizzard's selected-tab art, and the gold bar is no longer covered.
- Red buttons are full height so their art isn't squashed; Sections and
  View show as separate buttons with small gaps.
- The bank's empty title row collapses, removing the gap under the strip.

## 0.10.0-beta1 (beta branch)

Classic skin, phase 1: the bags and bank windows now use Blizzard's own
window art, matching Forever's bags.
- Blizzard's window frame: bronze border, slate background, dark title strip
  with the title centered in gold, and the red close button.
- BagSmith's full-color icon in the round portrait, cropped like Blizzard's.
- Red panel buttons for Filter, Sort and Merge stacks and for the Sections
  and View choices (the selected one shows pressed), and Blizzard's tabs.
- Blizzard's cleanup button art for the broom; gold in the recessed bar.
- The scrollbar shows Blizzard's arrow buttons.
- Switching skins is still live. Every piece comes from the game's own files.
- New /bs skincheck lists each Classic piece and whether this client has it;
  anything missing keeps its Modern look.
Not yet: Settings, the Filter panel, the currency drawer, the confirm dialog
and the small bag windows (phase 2).

## 0.9.19

- An item that arrives in the list under your pointer (dropped in or looted)
  now shows after a quarter second instead of waiting until the pointer
  leaves the window. Items leaving still leave a gap until you move away,
  so right-clicking down a column keeps the rows still.

## 0.9.18

- Dragging an item into the other window: while you carry an item from
  somewhere else (the other window, a bag window, your character sheet), the
  list you point at shows a soft overlay, "Drop to put in your bank" (or
  bags) with the free slot count. Let go anywhere on it, headers included:
  the item goes onto a stack of the same item with room, otherwise into the
  first free slot, preferring a matching specialty bag. If there is no room,
  the overlay says so and the item stays on your cursor. Dragging within one
  window works as before, and in icon view the overlay steps aside over a
  slot so you can still drop on an exact slot.

## 0.9.17

- Settings > Advanced lists the troubleshooting commands one per row, with
  the commands lined up in their own column.

## 0.9.16

Cleanup, no change in behavior.
- The bag view code is split into three files: the window itself, the list
  layout, and scrolling. All scroll handling now lives in one place with
  one documented set of rules.
- Retired beta diagnostic commands that have done their job: /bs bankapi,
  /bs bankui, /bs bankbuy and /bs names. /bs check now reports the bank API
  and purchase button instead.
- Removed a classic-only bank purchase dialog Forever never uses, and a few
  unused leftovers.
- Settings > Advanced and the /bs help list only commands that exist.

## 0.9.15

- The scrollbar's thumb reaches the bottom of its track when the list is
  scrolled to its last row. The bar now uses the same limit as the list
  instead of the game's slightly larger one.

## 0.9.14

- Lists can never scroll past their last row. The padding below the last
  row is gone, and the bottom of the last row is a hard limit for your own
  scrolling, BagSmith's restores and the game alike. When a window is taller
  than its list, there is nothing to scroll.

## 0.9.13

- Scrolling: BagSmith now asks the game how far a list can scroll instead
  of working it out, which was a few pixels too far. Lists no longer sit
  slightly past their last row, and the back-and-forth of a few pixels is
  gone.
- When the game jumps a list, the guard returns it to the last position you
  or BagSmith chose, never one the game picked.
- With /bs debug on, every list rebuild logs why it happened and the list's
  height before and after.

## 0.9.12

- Scrolling: the debug log showed the game itself scrolling a list past its
  end when a bottom row was clicked. Lists can no longer sit past their real
  bottom, and while your pointer is over a list, any scroll you did not make
  yourself is undone straight away. Your wheel and scrollbar work as normal,
  and a list that really got shorter settles at its new bottom.
- An item change that waits for you to release the mouse now still holds
  rows still afterwards instead of rebuilding the list.
- Settings: numbers sit in the same spot in every box, with or without a %.

## 0.9.11

- Bottom of the list: a gap left by an item no longer leaves a ghost of its
  icon frame behind. While rows are holding still, the list is pinned: any
  scroll movement you did not make yourself is undone on the next frame.
  Scroll restores can no longer fire late and override a newer position or
  your own scrolling. With /bs debug on, every scroll movement is logged with
  its source (you, a BagSmith restore, the tidy-up, or unknown).
- Settings: percentages show a fixed % inside the number box.

## 0.9.10

- Rows hold still while your pointer is over the bag or bank list: an item
  that leaves leaves a gap, new items wait, and the list tidies up when the
  pointer moves off the window. Searching and toolbar changes still update
  straight away.
- The scroll position is restored a second time on the next frame, after
  the game updates how far the list can scroll.
- Debug messages: new profiles always start with debug off; a test locks in
  that a fresh install starts with it off.
- Number boxes in Settings line up in one column; the size labels say Max.
- New-item dots moved up and left to sit flush in the corner.

## 0.9.9

- Right-clicking the bottom row of a scrolled list now works. Locking an
  item no longer rebuilds the list, nothing rebuilds while a mouse button
  is held over a window, the scroll position is kept across rebuilds, and
  the last row has a little room under it.
- New-item dots sit inside the slot's corner and are never cut off.
- Window size: dragging the corner no longer switches Fit to Fixed. In "Fit
  to items" it sets the largest size; in "Fixed size" it sets the size.
  Clearer names and help text.
- Every number in Settings can be typed: whole numbers only, percentages as
  whole percents, out-of-range values snap to the limit.
- BagSmith appears under Options > AddOns with an Open Settings button.
- "Show minimap button" wording; age filter reads "Time in your bags".

## 0.9.8

- Type column shows "Misc." instead of "Miscellaneous". Searching either
  word still finds those items.
- Search now matches the item type the Type column shows, not only the
  subtype.

## 0.9.7

- Settings: the Look page is now called Style.

## 0.9.6

- Picking your own character in the character list always shows your live
  bags; it could show a stale read-only copy saved right after login before
  the realm was known. Such copies are no longer saved, and old ones are
  cleared.

## 0.9.5

- Two "Bank: Default" windows: Forever keeps the real 48-slot bank in a
  placeholder tab and also exposes an older, empty 32-slot container. When
  the real tab exists and the old container is empty, BagSmith ignores the
  old one: no window, no Where entry, and it no longer inflates the free
  slot count. If the old container ever holds items, it is shown as before.

## 0.9.4

- Bank Where column: Forever's bank tabs hold a hidden placeholder bag named
  "Character Bank Tab Bag (DNT)"; its slots now read "Default" instead of
  that name. Real bank bags keep their names. /bs bankapi lists each bank
  container with the item it resolves to and the name BagSmith shows.

## 0.9.3

- The bank window has its own columns: which are shown, their order and
  their widths, set separately from the bags window. The Bank tab inside
  the bags window uses the bags layout. Settings > Columns has a switch
  between the two, with a note saying so.
- Profiles: "Use" is now "Assign", and the help text explains Assign, Copy
  and Delete.

## 0.9.2

- A bag window's close button closes only that window. The footer icon
  still opens or closes the whole set (and reopens any you closed by hand);
  closing every window one by one turns the set off. Same for bank bag
  windows.

## 0.9.1

- The Filter panel's close button works: its drag bar was catching the click.
  The other drag bands (bag and bank windows, Settings) were already layered
  correctly; tests now check all of them.

## 0.9.0

Bank
- Where column: the bank's own slots read "Default"; bank bags show the name
  of the bag in that tab, with its slot number when two share a name, e.g.
  "Linen Bag (2)". Bag names are read from the right slot on Forever's
  C_Bank tabs.
- Individual bank bag windows: a footer icon in the bank window opens one
  small window per bank bag, titled "Bank: Linen Bag (1)", plus "Bank:
  Default" for the bank's own slots. Drag items in and out; they close when
  you leave the banker.

Filters
- Rarity includes Legendary.
- Age: "In your bags between [0] and [3] hours". Whole hours 0 to 9, a
  reversed range is swapped, empty means any age. Saved with sheets.

Categories
- Items the client has not loaded yet are categorized right away from the
  instant item lookup instead of waiting under Other.
- Quest items and quest starters are found from the container's quest info,
  whatever their item class.
- The crafting-reagent flag files odd materials under Trade goods.
- Item classes use Blizzard's named constants.
- Tokens are recognized by item ID (PvP marks, Darkmoon tickets, Argent
  Dawn tokens, Zul'Gurub coins and bijous, AQ scarabs) instead of English
  name guesses, so it works in every language. /bs dump shows the instant
  and full lookups, quest and reagent flags for each item.
- Categories are cached per item.

Settings
- Plainer wording throughout, starting with Show empty slots.

## 0.8.7

- Age is the age of the newest item in a stack: adding to a stack resets
  its age. Merged rows already showed the newest stack. Splitting a stack
  no longer makes the split-off part look brand new; it keeps the source's
  age.

## 0.8.6

- Item ages no longer reset on reload: the first scan after login could run
  before the client had handed over bag contents, see empty bags, and prune
  every first-seen timestamp. Pruning now waits until 15 seconds after
  login and skips scans that found nothing.

## 0.8.5

- The toolbar adapts to the window width: when the full form would not fit,
  the Sections and View labels are hidden and "Merge stacks" becomes
  "Merge". The minimum window width is 620 so even the compact form
  always fits, and nothing can be pushed off the edge.

## 0.8.4

- Filter panel: the space under Where follows the number of bag rows
  instead of reserving three, so the panel is as tall as it needs to be.

## 0.8.3

- Classic empty slots restored to the 0.8.0 rendering (cropped slot art
  inside Blizzard's Quickslot ring) and used in the bag windows as well as
  the main window.

## 0.8.2

- Classic empties use the client's own empty-slot atlas (the Forever look
  Blizzard's bags draw) in every window; 0.8.1 had forced the classic-era
  art. Falls back to that art only on clients without the atlas.
- Icon rows sit a few pixels below their section header instead of
  touching it.

## 0.8.1

- Empty slots look the same in every window: Modern shows the plain shaded
  square (Blizzard's slot art is cleared from the main window's empties),
  Classic shows Blizzard's clawed-bag art (now drawn in the bag windows too).
- Scrollbars are decided after the window has been sized, so a window that
  grew to fit its list no longer shows a bar it does not need.

## 0.8.0

Bag windows
- New settings under Windows: icons per row (4 to 12), a separate scale for
  the bag and reagent windows, and a max height beyond which a bag scrolls.
  Window width follows the icons-per-row setting.
- Bag windows are always a plain slot grid; a key in the bag no longer
  knocked the window out of grid layout (and blank).

Performance and memory
- Fixed a frame leak: the Filter panel was rebuilt every time it opened
  from a different window than last time, and WoW never frees frames. Each
  window now has one panel, built once; only its bag list updates in place.
  Measured over a long synthetic session: zero frame growth, zero retained
  memory growth at steady state.
- Section headers no longer create new click handlers on every redraw.
- Money and currency changes update footers only, not the whole layout.
- Merged-stack rows are computed once per redraw instead of twice.
- The in-combat refresh indexes items instead of scanning the list per row.
- The character cache is written once things settle (1.5 s after the last
  change, and at logout) rather than on every bag event.
- The currency list and parsed searches are cached until they change; money
  strings are formatted once per value.

## 0.7.4

- New-item dots returned on reopen when Merge stacks was on: the hover
  cleared the merged row's copy but not the records it was built from.
  Dismissing now clears every underlying stack of that item.

## 0.7.3

- New-item dots came back when the bags were reopened. Dismissals were
  remembered by item GUID, which this client may not provide, and the
  client's own flag could not be cleared. Dismissals are now also
  remembered by slot, item and stack count, which works without GUIDs.
  /bs check reports whether GUIDs and RemoveNewItem are available.

## 0.7.2

- Removed the "Animate section reordering" setting; the reorder slide is
  always on.
- New-item setting text now says half a second.

## 0.7.1

- "Show empty slots" now applies to the main and bank windows in icon view
  when sections are off or by bag (empties follow the items), as well as
  the bag windows. Sections by type cannot show empties, since an empty
  slot has no type. Help text corrected.

## 0.7.0

- "Open each bag in its own window" and "Open the reagent bag in its own
  window" are starting states, applied when BagSmith opens. During a session
  the footer icons and each window's close button decide, and closing a bag
  window keeps it closed (previously the next refresh reopened it).
  Reopening BagSmith returns to the settings.
- Housekeeping: removed a stale glyph data file and three unused textures;
  credits updated. Full audit: no frame-method hooks, no addon-written
  bagID fields, no reassigned Blizzard globals, all TGAs in the same
  orientation, every referenced texture present, every Lua file in the TOC.

## 0.6.4

- Combat: faded windows also ignore the mouse. An invisible shield covers
  each BagSmith window so a stray click, drag or scroll does nothing.
  "Ignore clicks while faded" under Combat, on by default.
- Default combat opacity is 15%.
- New-item markers clear after half a second of hovering.

## 0.6.3

- New-item markers: clearing now takes one second, and a bag update during
  the hover no longer cancels it (it matched the record object; it now
  matches the item). Hovering in a bag window clears the marker too.
- Tooltips: while windows are faded for combat, no BagSmith tooltip shows,
  and one already open is hidden when combat starts.
- Confirmation dialog text wraps onto as many lines as it needs; wording
  shortened.
- Leaf icon redrawn with a bold stem and midrib for the footer.
- Bag and reagent windows: the grid sits just under the title; the empty
  column-header space is gone.

## 0.6.2

- Combat fade: every BagSmith window dims during combat (10% by default,
  adjustable from 5% to 100%) and returns when combat ends. "Fade windows
  during combat" under Windows in Settings; off if you prefer.
- Confirmations (delete sheet, delete profile, reset to defaults) use a
  BagSmith dialog with Yes and Cancel, anchored to the button you clicked,
  instead of a second click and a chat line.
- Toolbar groups are drawn as one bordered control with dividers; the
  active segment has a full outline that no longer loses its sides.
- Footer icons are drawn at 16px with more margin in their textures, so
  the bottom edge is no longer trimmed.

## 0.6.1

Sheets
- A plus button after the tabs (bags and bank) opens the Filter panel to
  create a new sheet. Selecting one of your own sheets shows a pencil that
  opens it for editing: rename, change its filters, or delete it (with a
  confirmation). The small delete x on tabs is gone.
- The Filter panel has its own search box mirrored with the window's, so
  it is clear a saved sheet keeps its search. The panel can be dragged
  aside to watch the list change. Bags and bank each have their own.
- Bank sheet tabs can be hidden in Settings, separately from bag tabs.

Toolbar
- Exclusive groups (Sections: All / By type / By bag; View: List / Icons)
  are labelled and joined so they read as one control; Sort and Merge
  stacks stand apart as separate actions.

Settings
- Settings is fully opaque.
- Profiles are a list: each shows Use, Copy and (except Default) Delete,
  with a confirmation, so any profile can be removed from any profile.

Other
- Footer: a plain leaf marks the reagent bag; both footer icons behave the
  same (muted, brighter on hover, accent while their window is open).
- The drag band covers the whole top of every window, edge to edge.
- New-item markers clear after 1.5 seconds of hovering.

## 0.6.0

Icons
- Every generated icon was rendering upside-down: the client reads TGA rows
  top-down regardless of the file's origin flag. All icons are now exported
  to match, which fixes the broom, the section and collapse chevrons, the
  sort arrows, and the brand marks.
- Footer: the reagent bag icon is a simpler silhouette with a green tint at
  rest so it reads apart from the bags icon.

Skins
- Modern: the shaded icon frame now sits inside its cell, and the icon grid
  has a little more air, so frames no longer clip against neighbours in the
  bag windows or icon view.
- Classic: list rows show a plain icon with a thin rarity ring and no slot
  art; icon view and bag windows use Blizzard's regular slot frame with
  Blizzard's rarity border. The additive glow is gone.

Settings
- Settings is now its own window: movable, remembered position, categories
  down the left (Profile, Look, Windows, Sections, Columns, Sheets, Sorting
  and filters, Advanced) with one page at a time on the right, proper
  margins, and help text that never runs under a control. The gear icon,
  /bs settings and right-clicking the minimap button open it.
- "Currency drawer opens to the" replaces the old side-panel option and
  says that it flips automatically when there is no room.
- American spelling throughout (color).

New-item marker
- BagSmith keeps its own record of what you have seen, so a dismissed marker
  stays dismissed across reloads.
- A stack that grows is marked new again.
- Hover an item for three seconds to dismiss its marker; a quick pass does not.

## 0.5.4

- Bank slot purchase: the real cause was a single line, "StaticPopupDialogs
  = StaticPopupDialogs or {}". Assigning that global from an addon marks it
  addon-written, so every Blizzard dialog that read it, including the bank's
  own "buy this tab" confirmation, ran tainted and the purchase was blocked.
  The line is gone; BagSmith only adds a dialog key on the classic path.
- The bank window now honours "Replace the bank window": off means only
  your bags open at a banker. Flipping it while at a banker swaps windows.
- The bank window can save its own sheets, kept apart from bag sheets, with
  its own tab order.

## 0.5.3

- The bank window is independent of the main window: its sections, sort,
  list or icon view and merge-stacks setting are its own (saved separately),
  and so are its search, filters and column sort.
- The bank window has the category tabs (All, Gear, Consumables, Trade
  goods, Quest, Junk). Custom sheets and "Save as sheet" stay with the main
  window; the filter panel adapts to whichever window opened it.

## 0.5.2

- The buy slot now targets the button inside Blizzard's purchase prompt,
  the one whose click shows Blizzard's "buy this tab" confirmation, with
  the bank panel's top-level purchase button as fallback. /bs bankbuy 1 or
  2 switches between them for testing.

## 0.5.1

- Buying a bank slot no longer trips "blocked from an action": purchasing is
  a protected call on this client, so the for-sale slot now securely clicks
  Blizzard's own purchase button, which shows Blizzard's confirmation and
  buys inside Blizzard's code. If that button cannot be found, clicking the
  slot reveals Blizzard's bank window instead and says so. /bs bankui lists
  the bank frame's buttons for wiring.

## 0.5.0

- Dedicated bank window. Visiting a banker opens a separate Bank window
  beside your bags, with its own search, sections, sorting, list or icon
  view, resize grip and remembered position. Closing it ends the bank
  session; closing your bags does not. The main window's Bank sheet is now
  always the saved copy, labelled "Bank (saved)".
- The bank bag section is a clearly separated band with an accent title,
  a slot summary with the next slot's price, and larger slot buttons.

## 0.4.11

- Bank replacement now works on Forever's modern C_Bank API: purchased tab
  count, next tab price and purchase come from C_Bank, each tab maps to its
  bank bag container, and bags are placed or picked up with the inventory
  slot functions the client still has. The classic API remains as a
  fallback. The Settings note about it being unavailable is gone.
- Turning "Open with the bag keybind" off closes Blizzard's parked bag
  frames as it returns them, so the first B press opens Blizzard's bags
  instead of closing invisible ones.

## 0.4.10

- BagSmith no longer changes Blizzard's "One Bag" (combined bags) setting.
  The combined window is parked the same way as the individual bag frames.
  If One Bag is off for you, an earlier build did that; turn it back on in
  Blizzard's options.
- New /bs bankapi prints which bank functions this client has, so bank
  replacement can be built against the real API.

## 0.4.9

- On this client, hooking any method on a Blizzard frame object leaves that
  method nil (SetID and SetBagID both broke). BagSmith no longer hooks
  frame methods at all; it parks Blizzard's bag frames from post-hooks on
  the global ContainerFrame_GenerateFrame and UpdateContainerFrameAnchors
  instead. The mock client now behaves the same way, so the suite would
  catch a frame-method hook if one crept back in.

## 0.4.8

Taint fixes, from the beta taint log
- "Blocked from an action only available to the Blizzard UI" on right-click
  use: BagSmith stored a field named bagID on each item button, which
  Blizzard's GetBagID() reads before falling back to the parent's ID. An
  addon-written field taints the whole item-use path. The field is renamed
  so Blizzard uses the taint-free C-side ID.
- "attempt to call a nil value" inside Blizzard's SetBagID: BagSmith hooked
  SetID, a C widget method, on Blizzard's bag frames, which breaks the method
  on this client. It now hooks SetBagID, a plain Lua function, and only falls
  back to SetID where SetBagID does not exist.

## 0.4.7

- Fixed the one startup error on the Forever beta: PLAYERBANKBAGSLOTS_CHANGED
  does not exist on this client and registering it threw. Unknown events are
  now skipped and listed by /bs check.
- Buying a bank slot refreshes the slot row on its own half a second later,
  since the client may not fire an event for it.

## 0.4.6

- Bag windows and the reagent window: no footer or gold; the slot count
  sits in the title bar beside the close button, and long bag names trim
  rather than crowd it.
- Free-slot counts read "19 / 44" everywhere, without the word free.
- The reagent window reports its own slots instead of 0 / 0.

## 0.4.5

- The new-item marker is a shaded green dot with a dark rim and a soft
  highlight instead of a flat square, sitting just off the icon's corner.

## 0.4.4

- Bag windows and the alt viewer no longer show a pale wash over icons: the
  read-only cells had a leftover white glow texture above the icon. They now
  use the same layering as the main window.

## 0.4.3

- Compact rows: the classic rarity glow is kept within the row height so it
  cannot bleed into neighbouring rows; the modern ring and frame already
  follow the smaller icon.

## 0.4.2

- Rarity borders match the skin. Modern: a crisp one-pixel ring in the
  item's color, set into the shaded frame. Classic: the additive glow
  border classic-era bags used. Blizzard's retail-style border is no longer
  used by either skin.

## 0.4.1

- Settings audit: list rows (sections, sheets, columns) trim long names so
  they never reach the move buttons. Layout verified against fonts up to
  twice the expected width with no overlaps.

## 0.4.0

- "Open with the bag keybind (B)" setting, on by default. Off means B opens
  Blizzard's bags and BagSmith opens only from the minimap icon or /bs.
  Takes effect immediately, no reload.
- Bank replacement, on by default where the client offers the classic bank
  API. At a banker, Blizzard's bank window is concealed and BagSmith's Bank
  sheet shows a row of bank bag slots: see equipped bags, drop a bag into an
  empty slot, pick one up, and buy the next slot (with a confirmation and
  the price). Closing BagSmith ends the bank session. Guild bank is not
  covered and is not planned.
- Modern skin: every item icon sits in a shaded dark square with a faint
  edge, in rows and in the icon grid. Classic keeps Blizzard's slot art.

## 0.3.7

- Equipping a bigger bag after login now works: the button pool grows to
  cover the new slots right away, or after combat ends if you are fighting
  (the footer says so). Previously items in the extra slots were invisible
  until a reload.
- Bag swaps are picked up from the container and equipment events as well
  as the bag update.
- The filter panel rebuilds its Where list when your bags change.

## 0.3.6

- Narrow windows: the favorites strip gives up currencies from the right
  until everything fits, and the "+N" chip only appears when it has room,
  so the footer never overlaps its icon groups.

## 0.3.5

- Footer favorites: a clear gap after the gold, each currency's icon sits
  tight to its count, and neighbouring currencies keep 12px apart.

## 0.3.4

- Footer spacing: the reagent icon and count, and the bags icon and count,
  read as two tight groups with a clear gap between them, and the free count
  no longer runs under the resize grip.

## 0.3.3

- Broom icon flipped so the handle leans the conventional way.

## 0.3.2

- Stepper buttons in Settings use minus and plus icons, and the delete-sheet
  button beside a custom tab uses the close icon. No text glyphs remain.

## 0.3.1

- Every text caret is now a real icon: section collapse arrows, the character
  picker's dropdown arrow, the sort indicator in column headers, and the
  move up/down buttons in Settings and the currency drawer.

## 0.3.0

- Where column: when two bags share a name, the bag slot number is added,
  e.g. "Linen Bag (3)", matching the bag bar.
- Merge stacks: one row per item with the total count, "+N" in Where for
  the extra stacks. Toolbar button for the moment, setting for the default.
- Accent color: pick any color for highlights, active buttons and section
  titles, in either skin, with the game's color picker or a hex box.
- Reagent bag: the footer "R" is now the reagent icon; click it to open the
  reagent bag in its own small window. Its free count sits beside it.
- Sheet tabs wrap onto extra rows and long names are trimmed, so many saved
  sheets never overlap or run off the window.
- Reset to defaults now lives at the bottom of Settings and asks for a
  second click to confirm.

## 0.2.16

- Pressing B to reopen the bags brings the bag windows (and reagent pop-out)
  back with the main window, so the footer icon and what is on screen agree.

## 0.2.15

- The backpack gets a bag window too (a slightly wider grid for its 20 slots).

## 0.2.14

- Opening the bag windows no longer removes those bags from the main window.
  Bag windows now mirror their slots with plain cells: hover for the
  tooltip, drag items out, drop items in, shift-click to link. Only
  right-click-to-use stays in the main window, where the secure buttons are.

## 0.2.13

- The bag-windows toggle moved from the toolbar to the footer: a small
  backpack icon just left of the free-slot count, in the same style as the
  title-bar icons. It lights gold while the bag windows are open.

## 0.2.12

- The Combined/Separate choice is gone. In its place a "Bag windows" toggle
  opens each bag in its own small window: an icon grid showing every slot,
  empties included, so you can drop items into a specific bag. The
  backpack stays in the main window; the other bags leave it while their
  windows are open, since each slot has exactly one secure button.
- Bag windows are placed in a row beside the main window the first time,
  each anchored to the screen. Move one and it stays put; positions are
  saved per bag. They no longer chain to each other.
- Scrollbars appear only when there is something to scroll, which removes
  the thumb that sat over the footer of small windows.
- The bank sheet shows the bank's free-slot count: live at a banker, and
  from the saved bank anywhere else.

## 0.2.11

- Character names show both words where the client provides them. BagSmith
  tries the richer name APIs and accepts a "First Last" result; titles are
  not mistaken for last names. /bs names prints what each API returns so
  the right source can be confirmed on the beta.
- Hovering an item clears its green "new" marker, and tells the client so
  Blizzard's own glow clears too.
- Default columns are now Qty, Item, Type, Bind, Vendor, Where, Age.

## 0.2.10

- Filter panel rebuilt with measured layout: checkboxes wrap by their real
  label width, sections have consistent spacing, nothing runs off the edge,
  and the panel is opaque so the list no longer shows through.
- Keys and Reagent bag sections no longer show a "pinned" tag.
- The collapse/expand-all button uses the same monochrome icon style as the
  title bar (double chevrons, flipping with state).

## 0.2.9

- Settings rows are now laid out from measured text. Help lines word-wrap,
  and a control that would collide with its label drops onto its own line
  (and wraps again if it is wider than the panel). The panel is wider with
  more room at the right edge. A test asserts that no two rows overlap.

## 0.2.8

- Column resizing actually works now. The grip frames lost their height
  when they were positioned, so they could never be clicked. Each header has
  a faint gold line at its right edge; drag it.
- New Age column (off by default): time since BagSmith first saw the item in
  your bags, shown as now / 5m / 3h / 2d / 3w. Sortable, and it carries over
  to the alt viewer.
- "Lanes" are now called "Sections" everywhere a player sees them.
- The All sheet no longer shows a checkbox it could not use.
- Settings rows are taller with more room between sections.

## 0.2.7

- Settings: help text sits on its own line under the label, so it never runs
  into the buttons. Regrouped into Profile, Look, Window, Lanes, Columns,
  Sheets, Sorting and filters, Advanced, with plainer labels.
- Column resizing is discoverable: the grip at each header's right edge is a
  faint gold line at all times, brightens on hover, and every header has a
  tooltip explaining click-to-sort and drag-to-resize.
- The header band now covers the title, search and tools rows as one block,
  ending just above the column headers.

## 0.2.6

Columns
- Every column keeps a 10px gap before the next one, so right-aligned numbers
  no longer hug the neighbouring column.
- Item can be placed anywhere in the column order (its icon moves with it).
  It is the one column that cannot be hidden.
- Drag the right edge of any column header to resize it, Excel style.
  Double-click the edge to reset that column; Settings has "Reset column
  widths" for all of them. Widths are saved in the profile.
- Click any header to sort by that column; click again to flip direction.
  The toolbar sort button shows which column is active and picking a mode
  there clears it.
- Type column reads better: held items show their slot instead of
  "Miscellaneous", and common items no longer say "Junk".

Lanes
- Lane headers stand out: larger gold title, a gold accent bar, a stronger
  background band, and a taller row.

## 0.2.5

- Consistent toolbar: one monochrome icon set for clean up, bank, currencies,
  settings and close, muted at rest, gold when active, even spacing. The side
  panels use the same close button.

## 0.2.4

Fixes from beta testing
- Column checkboxes disappeared for unchecked columns, so columns could not
  be added back. Fixed; there is a test for it now.
- Column separators leaked into icon view. They are list-only now.
- Compact rows: default rows are now 26px and compact is 22px; the icon
  scales with the row so nothing overlaps.
- Stack counts drew on top of the icon in list view. The count now shows on
  the icon only when the Qty column is hidden.
- The scrollbar's arrow buttons rendered as stray icons at the window edge;
  the bar is now a slim track and thumb.
- Reading currencies no longer expands and collapses wallet headers, which
  could re-trigger the currency event indefinitely.
- Free-slot totals cover all bags in the separate-windows layout.
- Viewing another character shows all their bags regardless of layout.
- "Remember collapsed lanes" off now really keeps collapses for the session only.
- Lane and tab drag-reorder resolve their drop target from the mouse, so a
  drop lands even without an item on the cursor.

Polish
- Faint alternating row stripes, header and row column separators, a subtle
  title band, lane headers with a background band, near-opaque backdrop.
- Side panels follow the window when it is moved or resized.
- Minimum window width 540 so the toolbar never wraps.
- /bs errors lists errors recorded this session for reporting.

## 0.2.3

- B needed two presses: Blizzard's ToggleAllBags calls OpenAllBags and
  ToggleBackpack internally and our hooks fired for all of them. Only the
  outermost call toggles now. Merchants, mail, trade and the auction house
  auto-open BagSmith through their events.
- Hearthstone (and other common-quality "Miscellaneous" items) are no longer
  filed as Junk. Junk means grey quality.
- Hiding a column now hides it in every row, not just the header, and rows
  and the header draw faint separators between columns.
- Compact rows works: it sets rows to 20px.
- Removed the chat-link buttons at the right of each row; shift-click links.
- "No lanes" is now "All". Minimap button has a black background. More
  breathing room in Settings.

## 0.2.2

- Fixed a startup error: the settings validator ran tab cleanup on the
  per-character data, which has no tab fields, so the addon stopped loading
  before building anything. Tab cleanup now runs for profiles only.
- Keyring detection no longer collides with the bank. On Forever
  Enum.BagIndex.Keyring reads -1, the same as the bank, so the keyring is
  accepted only when it has a distinct id the container API answers for.
- Bank bag count falls back to Constants.InventoryConstants and then to 6
  when NUM_BANKBAGSLOTS is missing, as it is on the Forever beta.
- /bs check reports the bank id, bank bag count and keyring detection.

## 0.2.1

- Removed `AllowLoadGameType: camelot` from the TOC; if the client did not
  recognize the token the addon could appear enabled while never loading.
- Every event and signal handler is now wrapped: one failing handler reports
  itself in chat and no longer stops the rest.
- Prints a line at login confirming it loaded, with item and button counts.
  Turn it off with /bs quiet.
- New /bs check command reporting version, interface, hooks, counts and any
  missing APIs.

## 0.2.0 (MVP)

- Spreadsheet list and icon views, column choice and order, sorting.
- Swimlanes by type or bag with collapse, reorder, expand/collapse all, pinned Keys and Reagent lanes.
- Reagent bag modes: mixed in, own lane, pop-out window. Separate windows layout.
- Search shortcuts, filter panel, custom sheets, tab order and hiding.
- Bank sheet (live and cached), currency drawer with favorites and Blizzard import.
- Character cache and read-only alt viewing with a searchable picker.
- Modern and Classic skins, scale, fit or fixed sizing, resize grip, minimap button.
- Settings panel for everything, profiles UI.

## 0.1.1

- Profiles with slash commands.

## 0.1.0

- Foundation: detection, scanner, secure button pool, list window, hooks.
