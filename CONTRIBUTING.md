# Contributing to BagSmith

Thanks for wanting to help. BagSmith is maintained by Shweep, and pull requests are welcome. Here's how they're
handled, so yours gets in smoothly.

## Before you start

- **Ask first for anything that changes BagSmith for everyone**: a default, where a window sits, what a click does, a
  new setting. Open an issue or ask in the [BagSmith Discord](https://discord.gg/uYfcHPkcar), so the approach is
  agreed before you write it. Bug fixes and small polish can go straight to a pull request.
- **One change per pull request**, kept small. Several small pull requests are easier to review and test than one
  large one.

## What to include

- What it changes and why, in a sentence or two.
- How to see it in game: the steps, and a screenshot for anything visual (in both skins, Modern and Classic, where it
  applies).
- That the tests pass: run `python3 tools/run_tests.py` from the repository root (see "Running the tests" in the
  README). Add or adjust a test in `tests/` when it makes sense; the existing sets show how.

## House style

- **Text players see:** plain and warm, short sentences, no em dashes. Settings labels are in Title Case; a setting's
  help line is one sentence.
- **Code:** follow the file you're in. A few things that have cost us time on this client:
  - Use `HookScript` on frames, not `hooksecurefunc` on a frame's methods (it breaks here).
  - Anchor a window that can move to the screen, not to another frame.
  - Prefer item and spell IDs to names (the game translates names).
  - When the game's answer can't be read, treat it as "no", never as "yes".
- **No code copied from other addons** unless their licence allows it; say where it came from.

## How a pull request gets in

- Open it against the **`dev`** branch (`main` holds the release that's out now).
- The test suite runs on it automatically; a red check means something to fix before review.
- Shweep reviews it and may ask for changes. Small adaptations (style, a test, an edge case) may
  be made on the way; if it changes much, you'll hear why.
- Once accepted, it's merged into `dev` and ships in the next beta, where it's tested in game, then in the next
  release. Your GitHub name goes in that release's notes.

## Licence for contributions

BagSmith itself is all rights reserved (see [LICENSE](LICENSE)). You may fork this repository and change the code in
order to propose changes back to it. By opening a pull request, you confirm that the work is your own, or that you
have the right to submit it, and you agree that Shweep may use, change and distribute it as part of BagSmith, under
BagSmith's licence now or any licence it has later. Contributions to the plugin docs (`docs/`) and the example plugin
(`BagSmith_ExamplePlugin/`) are under their MIT License.
