# BagSmith

[![CurseForge](https://img.shields.io/badge/CurseForge-Download-F16436?style=for-the-badge&logo=curseforge&logoColor=white)](https://www.curseforge.com/wow/addons/bagsmith) [![Buy Me a Coffee](https://img.shields.io/badge/Buy_Me_a_Coffee-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/shweepy) [![Discord](https://img.shields.io/badge/Discord-Join_the_Community-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/uYfcHPkcar)

Spreadsheet-style bags for WoW Forever.

BagSmith replaces the game's bags with one window you can arrange your way: everything in a list or a grid of
icons, sorted into sections, searchable, with your bank and your other characters' bags a click away.

**Get it on [CurseForge](https://www.curseforge.com/wow/addons/bagsmith).** This repository is BagSmith's source,
its plugin documentation and its tests. The main branch holds the latest development build; finished versions
are on CurseForge and under this repository's Releases.

## Features

- **List or Icons view**, in a Classic look that matches the game or a flat Modern one.
- **Sections:** items grouped by type, by bag, or all together; sections of your own, pinned sections, and an
  optional split of Consumables into Food, Drink, Potions and more.
- **Sorting, Merge Stacks and search,** with filters and saved views as tabs (sheets).
- **Your bank and other characters,** including their bags, gold and currencies.
- **Item icons that tell you more:** item level, junk, gear sets, Pawn upgrades and cooldowns, with Icon Corners
  to choose what shows where, and marks from other addons too.
- **Helpers:** marking and selling junk, a Disenchant Helper for enchanters, and optional auto-confirm for some
  yes/no boxes, all off until you turn them on.
- **Plugins:** a public API for other addons, and a gamepad companion, BagSmith Gamepad (in alpha).

## Installing

From CurseForge, or download a release here and put the `BagSmith` folder in your game's `Interface/AddOns`
folder (the `BagSmith_Gamepad` folder too, if you want the companion). Then `/bs settings` opens Settings, and
`/bs new` shows what's new.

## For addon authors

Start with [docs/README.md](docs/README.md): adding marks to BagSmith's item icons, writing a plugin, the full API,
and a starter plugin in [BagSmith_ExamplePlugin](BagSmith_ExamplePlugin). The docs and the example plugin are
MIT licensed.

## Running the tests

BagSmith's tests run outside the game against a mock WoW client. You need Python 3 and the `lupa` package:

    pip install lupa
    python3 tools/run_tests.py                     # everything (about ten minutes)
    python3 tools/run_tests.py tests/some_set.lua  # one or more sets

Run them from the repository root (the folder holding `BagSmith/`). Mock results show the code's behaviour, not
the real game client's.

## Support and feedback

- Bugs and requests: open an issue here, or comment on CurseForge.
- Chat: the [BagSmith Discord](https://discord.gg/uYfcHPkcar).
- If BagSmith saves you time: [Buy Me a Coffee](https://buymeacoffee.com/shweepy).

## License

BagSmith is copyright (c) 2026 Shweep, all rights reserved. The plugin docs and the example plugin are MIT
licensed, and the bundled libraries and two toolbar icons keep their own licenses. See [LICENSE](LICENSE).
