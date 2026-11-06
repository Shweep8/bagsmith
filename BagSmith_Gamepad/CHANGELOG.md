## 0.1.1 (alpha; with BagSmith 1.4.0-beta6)

- Fixed: asking for the diagnostics status (`/bs gamepad nav`, then `/bs gamepad probe`) could switch the
  companion off until a reload. A status question no longer creates settings, and the probe commands check for a
  real probe key before using it.
- Fixed: if the bags were first opened during combat, controller browsing didn't start when combat ended (closing
  and reopening the bags was needed). It now starts once combat is over, if the bags are still open.
- Still an alpha: the native-client checks (above all the secure combat hand-back) remain open.

## 0.1.0 (alpha; unreleased; review candidate 4)

- First release as a separate companion addon, extracted from the BagSmith 0.15 development builds and
  rewritten against BagSmith.API 1.0: D-pad navigation (Icons and List), auto-scroll respecting newer
  player scrolling, inset unclipped highlight, focused-item tooltip through a lease, East to close,
  yielding to other windows and text entry, verified releases, separate Observer diagnostics.
- Controller browsing is an option on the companion's page (off by default); a 0.15 development-build
  preference migrates once. Reports move to `BagSmithGamepadDB` with a verified one-time copy of the
  legacy report.
- Combat hand-back through the secure state driver: implemented, unverified in the client.
- Candidate 2: an active latch gates every controller entry point (browsing, Observer, probe and
  navigation arming, binding installation, profile-triggered starts, combat-end reacquisition); cleanup
  of installed bindings still completes after a shutdown and never rearms anything. The highlight lives
  in BagSmith's clipped overlay frame for the view. Tooltip hand-off uses BagSmith's item-button mouse
  signal, not visibility transitions.
- Candidate 3: a focused slot whose item is replaced by a real inventory refresh is treated as a
  background replacement (the old controller tooltip ends; no tooltip is shown until the next move).
- Candidate 4: release version 0.1.0 alpha (the public API stays 1.0); the options checkbox shows the
  saved state again (candidate 3 displayed every true value as unchecked).
- Candidate 10: an icon for the game's AddOn List (Media/icon.tga).
- Candidate 9: a saved diagnostics report that ended normally is restored for /bs gamepad show without
  showing its card at login; a failure or an interrupted run still shows the card, which now has a close
  button.
- Candidate 11: switching into the Controller UI with the bag already open starts opted-in browsing.
