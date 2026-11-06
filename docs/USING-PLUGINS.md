# Using plugins in BagSmith

BagSmith plugins are separate, optional addons that extend BagSmith through a small public interface,
`BagSmith.API` (version 1.1). BagSmith itself is complete without any plugin: inventory scanning,
sections, sorting, layouts, item buttons, skins, profiles, mouse and keyboard, opening and closing its
windows all live in core and work with no plugin installed.

## Installing a plugin

A plugin is an ordinary addon folder under `Interface\AddOns\`, with its own `.toc` that depends on
BagSmith. Copy the folder there like any addon and restart the game or reload the UI. BagSmith lists
installed plugins under **Settings > Plugins**, whether they are enabled or not.

## Enabling, disabling, reloading

**Settings > Plugins** shows one row per installed plugin: name, version, author (with an *Official*
badge for the addons BagSmith itself curates), description and a status in plain words:

| Status | Meaning |
|---|---|
| Active | Loaded and registered with the BagSmith API; working now |
| Enabled, reload required | Turned on here for this character; it will load after you reload the interface |
| Enabled, not loaded: … | Was enabled at login but the game did not load it, for the reason shown |
| Disabled next reload, still active now | Turned off here for this character; it keeps running until you reload |
| Disabled next reload, still loaded now | The same, for an addon that loaded but never registered |
| Disabled | Off for this character |
| Loaded, not registered with the BagSmith API | The addon runs but never registered (an old or broken plugin) |
| Incompatible, requires API … | Built for another BagSmith API major version; it will not activate |
| Installed, missing dependency … | A dependency it declares is not installed |
| Failed to start: … | Its activation callback raised an error; the message is shown |
| Installed, unavailable on this client | The game refuses to load it (interface version) |

The checkbox changes the **game's addon enable state for the current character only** and takes
effect after a reload you request with the *Reload UI* button; nothing reloads by itself, nothing is
unloaded while you play, and reversing a change before reloading clears it. A plugin that cannot work
here (another game version, a missing or disabled dependency, another API version, two addons declaring
the same plugin ID) says why and cannot be enabled from this page, though it can still be disabled. If
the client offers no addon-management calls, or cannot name the current character, the page still
shows status and points you to the game's AddOns screen.

## Alpha and beta limitations

Plugins run as addon code in the same UI as BagSmith. Separation into another folder is a product
boundary, not a security boundary: a plugin can do anything any addon can. BagSmith attributes errors
to the plugin that raised them and stops calling a failed plugin, but it cannot undo side effects or
clear protected state a plugin created. Enable only plugins you trust.

The first official plugin, **BagSmith Gamepad**, is coming soon and in alpha testing: controller
browsing of the open bags (a D-pad highlight, item tooltips, East to close). Testers will be wanted when
it reaches beta; the Discord is the place to say so. Its hand-back of the D-pad when combat begins is
implemented through the game's secure state driver but has not yet been verified in the Forever client;
until it has, use it out of combat. It performs no item actions. Its CurseForge page:
https://www.curseforge.com/wow/addons/bagsmith-gamepad-support (the Plugins page offers it as a
copyable link while the companion is not installed).
