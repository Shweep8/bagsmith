# Author guidelines

- **Use only the documented API.** Do not read or mutate BagSmith's internals, frames, button pools,
  scroll state or profile table. Snapshots are copies; tokens, leases and profile tokens exist so that
  you never hold a live reference to something BagSmith may recycle.
- **Borrowed anchors are read-only.** A target's `anchor` is BagSmith's item frame. Anchor your own
  frames to it if you must; never reparent, resize, re-script, click, use, move or activate it.
- **No item actions.** The API performs none, and plugins must not drive item use, equipping, moving,
  selling, deleting or sorting through controller input or automation. Showing a tooltip is not an
  action; it is the only presentation bridge provided.
- **Clean up.** Keep the disposers you receive and the leases you hold; release a lease when you are
  done. On `onShutdown`, stop timers and listeners you created yourself: BagSmith disposes what the API
  gave you, not what you built.
- **Expect refusals.** Every method can return a stable failure code (`not-ready`, `unsupported-view`,
  `stale-target`, `hidden`, `combat`, `stale-profile`, `stale-lease`, …). A refusal never runs later;
  retry after the relevant event (`VIEW_SHOWN`, `VIEW_UPDATED`, `PROFILE_CHANGED`).
- **Protected actions and combat.** The API refuses scroll changes in combat and never makes a binding
  call for you. If you bind keys, you own the release, and only the game's secure state driver can
  release them when combat begins. Treat any combat-release design as unverified until it is shown on
  the actual client; never claim a `pcall` undid a protected-action failure.
- **No automatic downloads, remote code or telemetry.** Plugins are installed by the user as folders.
- **No isolation claim.** Addon separation is not a sandbox. Say what your plugin does, and do that.
- **Preferences are plain and bounded:** strings, booleans, finite numbers and plain tables, at most 6
  levels and 64 KB. Store a `schemaVersion` and migrate your own data when it changes.
- **Options and commands are shared surfaces.** Options render only when the user opens your page,
  never during search; command names must not collide with BagSmith's.
