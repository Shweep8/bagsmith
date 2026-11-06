# BagSmith.API 1.1 reference

1.1 (BagSmith 1.5.0) adds icon corner widgets; everything from 1.0 is unchanged.

`BagSmith.API` (also `_G.BagSmith.API`) is the only supported surface. Everything else is unsupported.
No method performs an item action. Every failure is `nil` (or `false`) followed by a stable code from
`API.Codes` and a readable message; a refusal never executes later.

## Versions and registration

`API:GetVersion() -> major, minor` (1, 0).

`API:RegisterPlugin(manifest, callbacks) -> handle | nil, code, message`

- `manifest`: `{ id, addon, apiMajor, apiMinor?, name?, version? }`. `id` is the stable plugin ID
  (letters, digits, `-`, `.`, `_`, up to 64), `addon` the declaring addon folder, `apiMajor` the API
  major the plugin needs (1), `apiMinor` the minimum minor (omitting it means 0; a blank TOC field reads as omitted). A version
  field that is supplied, in the manifest or in the TOC, must be a whole non-negative number (numeric
  strings are fine); anything else, a blank string included, is `invalid-manifest`, and in discovery a
  malformed TOC value is a problem row.
- `callbacks`: `{ onEnable = function(context), onShutdown = function(context, reason) }`.
  `onShutdown` is guarded best-effort cleanup, not an unload.
- Refused before any callback with `invalid-manifest`, `incompatible-api` (major differs or minor
  above the host's), `duplicate-plugin` (the ID is registered; the first keeps it), or
  `manifest-mismatch` (the addon's TOC `X-BagSmith-Plugin` names another ID).
- Returns a handle `{ id, context, GetState() }`. States: `registered` (host ready, activation pending),
  `waiting` (host not ready yet), `active`, `failed`, `incompatible`.
- **Activation runs exactly once**, deferred to the frame after BagSmith's own `ADDON_LOADED` handlers
  have run (its saved variables are validated, its profile is active and its window objects exist).
  That can be **before** `PLAYER_LOGIN` and `PLAYER_ENTERING_WORLD`: readiness guarantees the host's
  objects and API, not that the player is in the world, that the bag is open, or that every
  asynchronous item-data query has finished. Registration before or after readiness gets the same
  behavior; no plugin needs to catch an already-fired event. The exact startup ordering on the Forever
  client is to be verified live.
- The TOC and the manifest must agree: the addon's `X-BagSmith-Plugin` must be present and equal to
  `manifest.id`, its `X-BagSmith-API` equal to `apiMajor`, and a declared `X-BagSmith-API-Minor` equal to
  `apiMinor`; otherwise `invalid-manifest` or `manifest-mismatch`. (When the client cannot report addon
  metadata at all, this cross-check is skipped.) Dependencies are not checked at registration: a
  plugin whose required dependency is missing or disabled is not loaded by the game in the first place,
  and the Plugins page explains that from the addon's metadata.

**Failure is terminal.** An error in any callback (activation, an event listener, a command, an
options render) is caught and attributed (`Plugin <id> failed in <operation>: …`, the first three in
chat, all of them in Settings > Plugins), and the plugin is marked `failed` **before anything else of it
runs**: its remaining listeners in the current dispatch are skipped, its subscriptions, command and
options registrations are disposed, a tooltip lease it holds is released, and `onShutdown` is called
once. Other plugins and core dispatch continue. A retained context of a failed plugin answers read-only
queries (`GetViewState`, `GetTargets`, `ReadPreferences`, `GetOverlayParent`) and `ReleaseTooltip`;
everything that registers, presents or writes returns `not-active`. `pcall` does not undo side effects,
remove taint or clear protected bindings.

## The context

Given to `onEnable` and held by the handle. All methods are `context:Method(...)`.

### Views and targets

API 1.0 supports one view: `"main"`, the live main bags view. The bank and cached-character inventory
return `unsupported-view`.

`GetViewState(viewId) -> { id, open, ready, generation, inCombat } | nil, code`

`GetOverlayParent(viewId) -> frame | nil, code`: a frame BagSmith owns inside the view's scroll region,
clipped by the list like the item buttons and hidden with the view. A plugin may parent its own overlay
frames (a highlight) to it; it is the only BagSmith frame a plugin may parent into.

`GetTargets(viewId) -> snapshot | nil, code` where `snapshot = { id, generation, open = true, targets = { … } }`.
Refused with `hidden` when the view is closed. Each target:

| Field | Meaning |
|---|---|
| `token` | Opaque; bound to this button, this item and this generation |
| `bag`, `slot` | Inventory location (the same bag/slot can appear in more than one button) |
| `link`, `name` | The item link at snapshot time and its name |
| `x`, `y`, `left`, `right`, `top`, `bottom`, `width`, `height`, `scale` | Geometry in the view's own space (compare only within one snapshot); `scale` is the button's effective scale |
| `inViewport` | Inside the list's scroll window on every known edge |
| `anchor` | **Borrowed, temporary**: the item frame, for anchoring a plugin-owned overlay only. Never reparent, resize, re-script, click or activate it |

The list is every item button placed in the view, **on screen or not**, ordered top to bottom then
left to right, in both Icons and List views, with the current sorting and filters. Snapshots are
detached copies.

**Token lifetime.** A token is issued once for one (button, bag, slot, item, generation) identity and is
never re-pointed: when the button is hidden, recycled for another slot, shows another item, or the view
has a new generation (any layout pass, including a sort or filter change, and every show), the record is
retired for good and a later snapshot issues a different token. An unchanged presentation keeps the
same token across snapshots. A token rejected because its target disappeared (hidden, recycled, or its
item changed) is retired at that moment; the target shown again later carries a new token. A stale token
is a harmless `stale-target`: nothing is scrolled or shown for whatever now occupies the frame. A closed
view refuses all tokens with `hidden`.

`EnsureTargetVisible(viewId, token) -> true, changed, state | false, code`
Scrolls the list by the smallest amount that shows the target whole, with a one-row margin, within the
list's range, through BagSmith's own tagged scroll, stamped as a scroll by the player so a rebuild's
deferred restore never undoes it. `changed` is false when nothing had to move. Refused with
`stale-target`, `hidden`, or `combat` (never a silent success in combat).

`CloseView(viewId) -> true | false, code` closes through BagSmith's normal close path (`hidden` if
already closed).

### Tooltip lease

`ShowTargetTooltip(viewId, token) -> lease | nil, code` shows the item's tooltip the way the mouse
would, never running the item's click or any action. The lease is the plugin's claim on that tooltip.

`ReleaseTooltip(lease) -> true | false, code` hides the tooltip only if the lease is still the current
one and the tooltip is still on the lease's frame. The lease ends on an explicit ownership signal: the
mouse entering **any BagSmith item button, the leased frame included and whether or not the tooltip was
already showing** (BagSmith's own `OnEnter`, not a visibility transition); the tooltip being hidden; a
profile change (the host hides a still-leased tooltip itself first); the plugin failing. For a tooltip
some other frame owns, the owner check is the secondary test. After every layout pass the host also
checks the lease against its presentation and item: a lease whose frame no longer shows the leased
item (hidden, recycled, replaced in place) is released before `VIEW_UPDATED` is delivered, with its
tooltip hidden if still on that frame; a mouse-owned tooltip is not a lease and is never touched. A stale
release is a harmless no-op (`stale-lease`). Show on an intentional focus change or a reacquisition;
never on a timer.

### Events

`Subscribe(eventName, callback) -> unsubscribe | nil, code`. `unsubscribe()` is idempotent (true the
first time, false after). Callbacks receive `(eventName, payload)` with a detached payload.

| Event | Payload | When |
|---|---|---|
| `VIEW_SHOWN` | `{ viewId, generation }` | The view was shown; the generation is new |
| `VIEW_HIDDEN` | `{ viewId, generation }` | The view was hidden |
| `VIEW_UPDATED` | `{ viewId, generation }` | A layout pass finished and geometry is valid; several passes in one frame give one notice |
| `PROFILE_CHANGED` | `{ token }` | The active preference context was replaced (switch, copy, reset, delete, login); carries no other plugin's data |

Ordering: a listener unsubscribed during a dispatch does not run later in that dispatch; a listener
added during a dispatch joins the next one. Only active plugins receive events. Late registration gets
the current state through `GetViewState`/`GetTargets`, not a replay of past events.

### Preferences

`ReadPreferences() -> data, profileToken, schemaVersion` returns a **copy** of the plugin's namespace in
the active profile (`{}` when none) and a transient token identifying that profile context.

`ReplacePreferences(value, profileToken, schemaVersion?) -> true | false, code`. The whole namespace is
replaced with a validated copy. Refused with `stale-profile` when the token is not the current one (a
delayed write after a profile switch), or `invalid-data` when the value is not plain bounded data:
strings (≤ 4096 bytes), booleans, finite numbers, plain tables with string or **finite** number keys, at
most 6 levels and 64 KB in total; no functions, userdata, threads, cycles or metatables. Strings are
never evaluated. `schemaVersion` must be a finite non-negative integer; it is stored with the data for
the plugin's own migrations. Two bounds apply to a write. First, all plugin namespaces of one profile
together are capped at 192 KB in the validator's measure. Second, and this is the one the guarantee rests
on, the write is applied only if the share code the whole profile would then produce (BagSmith's own
serializer and encoder, with the profile's core settings and every namespace included) fits the share
limit of 400,000 characters; otherwise the write is refused with `invalid-data` and stores nothing. So
every profile BagSmith accepts a write into can be exported and imported intact. Data already stored or
imported is never trimmed to fit: an older, oversized profile keeps everything it has, exports only if it
fits (the failure is explicit and loses nothing), and its plugin may replace its namespace with a smaller
one. Saved containers that fail the validation rules are dropped by validation.

Profiles carry the namespace through switch, copy, rename, reset (back to empty), delete (removed with
the profile), export and import (preferences only; never addon enablement, logs or code). Data of an
absent or disabled plugin is kept untouched and activates nothing. Corrupt entries are dropped one by
one without affecting the rest of the profile.

### Options and commands

`RegisterOptions({ title?, render = function(ui) }) -> dispose | nil, code` (`duplicate-options` if
already registered). The Plugins page shows *Options* only for an active plugin with options. `render`
runs only when the user opens the page, never during settings search, with a small bridge:
`ui:Head(text)`, `ui:Text(text)`, `ui:Check(label, help, get, set)`, `ui:Button(label, onClick)`.
Every callback the page holds (render, getter, setter, button) runs through the same guarded dispatch as
events: the plugin must be active at the moment of the click, an error is terminal for the plugin, a
failing getter is a failure (never a silent false), and when a plugin fails while its page is open the
page is redrawn so no widget keeps plugin code.

`RegisterCommand(name, fn) -> dispose | nil, code` registers `/bs <name> …`; `fn(arg)`. Refused with
`reserved-command` (a BagSmith command) or `duplicate-command` (another plugin's). Commands of inactive
plugins answer with a message instead of running.

Disposers are bound to the exact registration they came from and latch after their first call: calling
one again, or after a newer registration took the same name or options slot, is a harmless no-op that
never removes the newer registration.

`ShowCopyableText(title, help, text) -> true | false, code` opens BagSmith's read-only copy window with
the text (the generic helper for reports).

`GetState() -> state`.

## Icon corner widgets (1.1)

Each corner of an item icon (Icons view, bag windows, the bank, Recent's and gear sets' copies, other characters'
bags, and List view for widgets that opt in) has a priority list. For each item, the first widget in a corner's list that has something
to show is drawn there; the others wait. Players order the lists under Settings > Item Icons > Icon Corners. An addon
doesn't need to register as a plugin to add a corner widget.

```lua
local api = BagSmith and BagSmith.API
if api and api.RegisterCornerWidget then
  api.RegisterCornerWidget("My Addon: Mark", "myaddon_mark",
    function(widget, details)            -- per item
      return MyAddon:HasMark(details.itemLink)   -- true: show; false: nothing here; nil: not ready yet
    end,
    function(itemButton)                 -- once per item button, outside combat
      local t = itemButton:CreateTexture(nil, "OVERLAY")
      t:SetSize(14, 14); t:SetAtlas("my-atlas")
      return t                           -- BagSmith places it, shows it and hides it
    end,
    { corner = "top_right", priority = 1 },  -- optional default position
    false)                               -- isFast (optional)
end
```

If you already support another bag addon's corner widgets with the same arguments, the same functions work here:
the calls take the same arguments and return values. BagSmith's calls accept a dot or a colon.

| Function | Notes |
|---|---|
| `RegisterCornerWidget(label, id, onUpdate, onInit, defaultPosition, isFast, options)` | Returns true, or false if refused: a missing label, an id that isn't letters, digits and `_ - . :` (64 at most), a missing function, or an id already taken. It never raises an error. |
| `IsCornerWidgetActive(id)` | True when the widget is in one of the four corners (in the active profile). |
| `GetCurrentCornerForWidget(id)` | `"top_left"`, `"top_right"`, `"bottom_left"`, `"bottom_right"` or nil. |
| `RequestItemButtonsRefresh()` | Ask BagSmith to draw the icons again (any arguments are ignored). |

- **onInit(itemButton)** returns the frame or region to show. BagSmith parents it to a holder above the icon and
  the cooldown sweep and positions it in its corner 2 px in (times `widget.padding`, if set). **It keeps the size
  you give it**, as in other bag addons: size it from `itemButton:GetWidth()` and your own settings. Set
  `widget.sizeFont = true` or `widget.bagsmithScale = true` if you'd rather BagSmith scale it with the icon. The
  settings' preview never runs your code: it shows a small neutral tag in your widget's corner.
- **options** (BagSmith only, optional): `{ listRows = true }` shows your widget on List rows too. In List view a
  BagSmith item button is the whole row, so for rows your onInit gets an **icon-sized slot** instead: a frame over
  the row's icon, with `slot.itemButton` (the row's button), `slot:GetBagID()` and `slot:GetID()` forwarded, and
  `slot.bagsmithRowSlot = true`. Without it your widget shows in Icons view only, and BagSmith's settings say so. `sizeFont` is accepted. Init runs outside combat: a widget registered during combat appears when
  combat ends.
- **onUpdate(widget, details)** returns true (show), false (nothing here: the next widget in the corner is asked)
  or nil (not ready: asked again on later frames while the button shows the same item, and when item data
  arrives). Widgets not marked `isFast` share a per-frame time budget and may be asked a frame later.
- **details** (read-only): `itemLink`, `itemID`, `itemName`, `quality`, `itemLevel`, `isBound`, `itemCount`,
  `icon`, `isJunk` (BagSmith's own junk marks), `classID`, `subClassID`, `bagID` and `slotID` and `itemLocation`
  (your own items only), `tooltipGetter()` and `tooltipInfo` (built only if read, where the client provides it).
  Other characters' items have no `bagID`, `slotID` or `itemLocation`.
- **defaultPosition** places a new widget once per profile: at the priority it asks for in a corner the player
  hasn't arranged, or at the end of a corner they have. A widget the player hides stays hidden. With no default
  position, it waits under Not Shown until the player places it.
- **Errors** in your functions are caught. A widget that keeps failing is switched off until the next reload, with
  one chat line.
- BagSmith's own widgets use the ids `junk`, `item_level`, `pawn`, `equipment_set` and `quantity`, so
  `IsCornerWidgetActive("pawn")` tells you whether Pawn's arrow is shown. The stack count (`quantity`) is
  protected: when an item has a stack it always shows, first in its corner, so a widget asking for first place in
  that corner goes after it.
- Item buttons in BagSmith's bag windows answer `GetBagID()` and `GetID()` like real bag slots.
- **`/bs corners`** lists every mark BagSmith knows, which corner it's in, whether it shows on List rows, and any
  errors. With `/bs debug` on, errors in your functions are printed as they happen.

### Examples

See [EXAMPLES.md](EXAMPLES.md): a single badge, several badges in one corner, a ring or glow around the whole slot,
List rows, and combat.

## Discovery and status (read-only, for tooling)

`API:RefreshPlugins()`, `API:PluginList() -> { { entry, status } }`, `API:PluginItemByAddon(addon)`,
`API:PluginItem(id)`: the cached model behind Settings > Plugins, built from addon metadata of every
installed addon declaring `X-BagSmith-Plugin`, without running any of their Lua. Installed-addon
identity is the addon folder; a runtime registration counts for a row only when it came from that
addon (two addons declaring one ID are both shown as problem rows, and only the one that registered
can be active). `API:SetPluginEnabled(addonName, bool)` and `API:RequestReload()` are the page's
controls: the current character must be known (it is identified by the player's GUID, exactly as the
game's own AddOn List does; the name is display only), eligibility is judged whether or not the addon is
enabled (API major; every required dependency installed, not disabled, loadable on this client and of a
known state; the addon's own load reason, including the game's `DEP_*` reasons), the result is read
back, and both are refused in combat. A change is *pending* only when the current enable state differs
from the baseline taken at BagSmith's startup discovery (from metadata only), so a change made on the
game's AddOns screen before Settings is first opened is seen as pending too; an addon that was enabled
but did not load keeps the game's reason instead of being called pending.

Per-character loadability is read with `C_AddOns.IsAddOnLoadable(addon, guid)` when the client offers it,
as the AddOn List does, for the plugin and for each of its required dependencies alike, falling back
to the account-wide answer from `GetAddOnInfo` when the client has no per-character call. A failed
per-character query is an unknown, never an assumed yes: for a required dependency and for the plugin
itself, an unknown refuses enabling with an explanation and writes nothing, while a plugin that is
already running keeps its status and can still be disabled for the next reload.

## What is verified on the target client, and what is only modeled

Verified on the Forever client (0.15 development builds): the one-press bag opener, override bindings
set and cleared with readback, `GetBindingAction` with the gamepad context, the native frame manager's
state reads, `GameTooltip:SetBagItem`, `SetScrollTagged` scrolling. Seen once in the client (20 October 2026):
the Plugins page rendering, and a disable attempt that the client refused while the character was passed
by name, which is why the GUID is used now (the fix itself is not yet seen live). Modeled only in the
test harness: `C_AddOns` discovery and per-character enable state, `ReloadUI`, the secure state-driver
combat release, the overlay parent's clipping, and the item-button mouse signal's effect on a live
tooltip.
