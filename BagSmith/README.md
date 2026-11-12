# BagSmith

Spreadsheet-style bags for World of Warcraft: Forever.

## What BagSmith has

- Replaces Blizzard's bag windows. B, the bag bar, merchants and the bank open BagSmith.
- Spreadsheet list view: item, quantity, item level, required level, type, slot, bind, vendor value, bag, age,
  and an AH Price column from Auctionator's last scan when Auctionator is installed.
  Choose which columns show and their order in Settings, and drag the line between headers to resize.
- Icon view, with a real slot grid (empty slots included) for separate bag windows.
- Sections by type or by bag, collapsible, reorderable (drag a section header or use Settings),
  with an expand/collapse-all button. Keys and the reagent bag can have their own sections.
  Icon Split View puts sections side by side in two columns in icon view.
  Headers show each section's item count and vendor value (and AH total with Auctionator).
- Recent Items: what you got since logging in (loot, vendors, mail, trades, quest rewards, crafting), in a section at the top
  (also kept in its usual section). Gear you take off and items from the bank don't count.
- Reagent bag: mixed in, or its own section.
- Optional small window per bag and for the reagent bag: icon grids with every slot, placed where you leave
  them, with their own icons-per-row, max height and a scale applied on top of the main Scale. Windows fade and ignore clicks during combat.
- Search shortcuts: plain words, `boe`, `bop`, `new`, `q:rare`, `t:herb`, `il>20`.
- Filter panel (rarity, category, bind, bag, new only) and "Save as sheet": your own tabs.
- Sheet tabs: reorder by dragging, hide in Settings. Optionally, each sheet remembers its own view.
- What's New: a short card after notable updates, with a tab for each recent release; reopen it from Settings or `/bs new`.
- Sell Junk + Mark as Junk: mark items as junk (Junk column or a keybinding) and they're sold with Blizzard's Sell All Junk. Optional Dim Junk Items.
- Profile Sharing: copy a profile as a code, or import someone else's as a new profile.
- Loot Helper: when loot won't fit, suggestions to free space (combine stacks, clean up, destroy junk or cheap items), then BagSmith finishes looting. Warlocks can clear Soul Shards from ordinary bags.
- Keybindings (own section in the game's Keybindings, and Settings > Keybindings): Mark as Junk, Favorite Item, Track as Currency, Toggle Travel Mode, Toggle Currency Drawer.
- Favorites: star items to pin them in a Favorites section at the top.
- Gear Sets: each of your equipment sets (from the game's Equipment Manager) shows as a section with an Equip button,
  and a Gear Sets tab lists every set slot by slot, worn and banked pieces included. Set items are never marked as junk,
  sold by BagSmith or offered by the Loot Helper.
- Settings search: find any setting from the box at the top of Settings.
- Track as Currency: show any item in the currency drawer (the wallet column, or Add Item in the drawer), kept even when you have none.
- Pawn support: Pawn's upgrade arrow on BagSmith's item icons.
- Travel Mode: a compact, on-the-go view. The signpost beside the close button hides the toolbar and filters (search moves into the title row); click it again for the full tools. Auto Travel Mode can switch it off at the bank, the auction house, vendors and on flight paths, and back on afterwards.
- Sorting: rarity, name, item level, newest, oldest, or click any column header. Merge stacks into one row.
- Bank: at a banker a dedicated Bank window opens beside your bags, replacing Blizzard's, with a bank bag
  section to view, place, swap and buy bank bags. Away from the bank, the Bank sheet is a saved copy.
- Currency drawer: wallet currencies plus token items counted from bags and bank; pin the ones
  you want in the footer, as many as fit. Currencies you tick Show on Backpack in the game are pinned for you.
- Character picker: browse any character's cached bags, bank, gold and currencies, read only.
  Reopening the bags always returns to your own character.
- Two skins: Modern, and Classic, a mimic of Forever's own bag frames built from Blizzard's art.
  Switching is live. Custom accent color.
- Scale, fit-content or fixed size, and a drag-to-resize grip.
- Minimap button (drag it around the ring), plus the addon compartment entry.
- Profiles: shared Default profile, optional per-character profiles.
- Rows are Blizzard's own secure item buttons: right-click uses or equips, shift-click links,
  drag to action bars. All combat safe: layout waits for combat to end.

Not covered: the guild bank.

## Install

1. Unzip.
2. Copy the `BagSmith` folder into your game's `Interface\AddOns` folder.
3. Enable BagSmith in the AddOns list at character select.
4. Log in and press B. Settings are behind the gear icon in the bag window, `/bs settings`, or a
   right-click on the minimap button.

## Commands

    /bs                toggle the window
    /bs check          self check: version, client, hooks, counts, missing APIs
    /bs errors         list errors recorded this session
    /bs settings       open settings
    /bs currency       open the currency drawer
    /bs dump           print bag layout and every item's class, subclass and category
    /bs sort <mode>    quality | name | ilvl | newest | oldest
    /bs scale <n>      0.5 to 1.5
    /bs profile ...    list | use <name> | copy <name> | delete <name> | reset
    /bs reset          reset the active profile
    /bs debug          toggle debug messages
    /bs quiet          toggle the login message
    /bs blizzard       toggle opening BagSmith with the bag keybind (B)
    /bs skincheck      Classic skin: list each piece and what this client provided
    /bs new            show what's new in this version

## If nothing happens

1. `/console scriptErrors 1` then `/reload`. Lua errors are hidden by default,
   so a crash at login looks exactly like the addon doing nothing.
2. `/bs check` prints what loaded and what did not.
3. `/bs` opens the window directly. If that works but B does not, the bag hooks
   are the problem; `/bs blizzard` then `/reload` turns the replacement off.

## If you see "blocked from an action only available to the Blizzard UI"

`/console taintLog 1`, `/reload`, reproduce it, `/reload` again, then send the last
lines of `Logs\taint.log`. It names the blocked call and the addon code that tainted it.

## Reporting a problem

Bug reports are welcome in the BagSmith Discord (Settings > About & Support) or on CurseForge.
Please include:

- What you did and what happened, step by step.
- The output of `/bs check` (version, client and what loaded).
- Any errors from `/bs errors`.
- A screenshot, if it's something you can see.
