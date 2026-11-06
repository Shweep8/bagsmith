# BagSmith Gamepad 0.1.1 (alpha)

Optional controller browsing for BagSmith under the game's Controller UI: a D-pad highlight over bag
items in both views, auto-scrolling, the focused item's tooltip, and closing the bag with East.
No item actions. Requires BagSmith with plugin API 1.0 (the Settings > Plugins page).

Install beside `BagSmith`. In Settings > Plugins the companion shows as *Active*; open its *Options*
and tick "Controller browsing (alpha)". Being installed does not turn browsing on.

**Alpha:** the feature set is incomplete and nothing has been verified in the Forever client yet.

**Combat limitation:** the hand-back of the D-pad to the game when combat begins is implemented through
the game's secure state driver but is not yet verified in the Forever client; use it out of combat.

Diagnostics (optional): `/bs gamepad` in the keyboard-and-mouse style; the Observer keybinding under
BagSmith in the game's key bindings. Reports live in `BagSmithGamepadDB`.

Credits: see CREDITS.txt (BagSmith). Design inspiration only, no code reused: Improved Forever (markg),
Easy Controller - Forever (moust4ki).
