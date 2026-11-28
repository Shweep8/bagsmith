# BagSmith.API changes

The public API has its own version, separate from BagSmith's release number. A minor version only adds; nothing
that worked before changes. See [COMPATIBILITY.md](COMPATIBILITY.md) for the policy.

## 1.2 (BagSmith 1.12.0)

Adds List view columns: a short text per item under a heading the player can sort by, from any addon, with no plugin
registration.

- `RegisterColumn(label, id, onUpdate, options)`
- `RefreshColumn(id)`
- `IsColumnShown(id)`

A column starts unticked in Settings > Bag Columns and Bank Columns; the player ticks, moves, resizes and sorts by it
like BagSmith's own. An answer is remembered per item until `RefreshColumn`. Details in [API.md](API.md).

## 1.1 (BagSmith 1.5.0)

Adds icon corner widgets: marks other addons can put on BagSmith's item icons, in the same shape many addons
already use for other bag addons.

- `RegisterCornerWidget(label, id, onUpdate, onInit, defaultPosition, isFast, options)`
- `IsCornerWidgetActive(id)`
- `GetCurrentCornerForWidget(id)`
- `RequestItemButtonsRefresh()`

Widgets keep the size you give them (opt in to scaling with `sizeFont` or `bagsmithScale`); List rows are opt-in
with `options.listRows`. Players place, reorder or hide marks under Settings > Item Icons > Icon Corners, and
`/bs corners` shows what BagSmith sees. Details in [API.md](API.md) and [EXAMPLES.md](EXAMPLES.md).

## 1.0

The original contract: views and targets, the tooltip lease, events, preferences, options and commands, and
read-only discovery and status. Unchanged in 1.1 and 1.2.
