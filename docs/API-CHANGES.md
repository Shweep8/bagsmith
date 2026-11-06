# BagSmith.API changes

The public API has its own version, separate from BagSmith's release number. A minor version only adds; nothing
that worked before changes. See [COMPATIBILITY.md](COMPATIBILITY.md) for the policy.

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
read-only discovery and status. Unchanged in 1.1.
