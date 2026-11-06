# QA tools

Run from `/home/claude` (the folder holding `BagSmith/` and `tests/`), with `lupa`:

- `leak.lua` ... `leak6.lua`: leak probes. Each cycles windows, skins and features many times and prints frames, regions and memory before and after; all three must stay flat. `leak6.lua` covers the most (Travel Mode, junk marks, the share window, trades, Make Room, the new Settings pages).
  `python3 -c "from lupa.lua51 import LuaRuntime; l=LuaRuntime(unpack_returned_tuples=True); l.execute(open('tests/tools/leak6.lua').read())"`
- `leak7.lua`: gear sets (0.15): set sections with their Equip buttons, the title menu, Settings rows, renames and outside changes, both skins, bank open and closed. Frames and regions must stay flat.
- `stress3.lua`: Settings layout stress. Returns a function taking a character width (use 6 and 9); walks every Settings page in both skins and reports overlapping rows (with three gear sets, so the Sections page lists them). Keep its page list in step with `PAGES` in SettingsPanel.lua.
- `lc_only.lua`: runs just the lifecycle scenarios (`tests/lifecycle.lua`) and prints failures; handy for red checks against an older build (copy the current tests into the old build's folder).
- `snapall.py`: `python3 tests/tools/snapall.py modern_check.lua fresh` (or `classic_check.lua classic toClassic`) writes the current layout snapshot to `/tmp/snap_<scenario>.txt`, to diff against the baselines when re-recording.
- `capture010.lua`: captures saved variables from a prod build (run inside an unzipped prod folder with the tests copied in) to make an upgrade fixture.
