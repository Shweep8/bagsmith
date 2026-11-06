# Compatibility policy

Three version numbers are distinct and must not be confused:

| Number | Where | Meaning |
|---|---|---|
| BagSmith release version | `BagSmith.toc` `## Version` | The host addon's release |
| Plugin release version | the plugin's `## Version` | The plugin's own release |
| Public API version | `BagSmith.API:GetVersion()` (major, minor); `X-BagSmith-API` / `-Minor` in a plugin's TOC | The contract between them |

**Supported client:** WoW Forever (`## Interface: 16001`). The API's behavior is validated against the
Forever client's documented functions, not against retail; retail source is a reference only.

**Within a major (1.x):** additive, compatible changes only: new methods, new optional fields in
payloads and snapshots, new event names, new result codes. Nothing documented is removed, renamed or
given a different meaning. A plugin declaring `X-BagSmith-API: 1` with a minor at or below the host's
activates on every 1.x host at or above that minor.

**A new major (2.0):** anything documented may change. A plugin declaring major 1 is listed as
*Incompatible, requires API 1* on a 2.x host and is never activated, even if the game loads it. Hosts
may support more than one major at a time; `GetVersion` reports the newest.

**Unmet requirements:** a plugin whose API major differs, whose minimum minor exceeds the host's, or
whose runtime manifest disagrees with its TOC (marker, ID, API major, declared minor), or that names a
declaring addon the client does not know, is refused at `RegisterPlugin` with a stable code and a
readable message, before any callback runs. (When the client offers no addon lookup at all, the TOC
cross-check cannot be made and is skipped; this is the only fallback.) Dependencies are the game's
responsibility at load time: an addon whose required dependency is missing, disabled or unusable on this
client is not loaded, so it never registers; Settings > Plugins reports that from the addon's metadata
and refuses to enable it. A plugin may be enabled in the game's AddOns list and still never become
active through the API.

**Undocumented internals** (`BagSmith`'s own namespace, `_G.BagSmith` members other than `API`, frame
names, the profile table) are unsupported and may change in any release without notice. They remain
present for existing integrations; no new integration should depend on them.

## API 1.1 (BagSmith 1.5.0)

Adds icon corner widgets (`RegisterCornerWidget`, `IsCornerWidgetActive`, `GetCurrentCornerForWidget`,
`RequestItemButtonsRefresh`). Purely additive: a plugin declaring `X-BagSmith-API-Minor: 0` activates as before.
Check for `api.RegisterCornerWidget` (or a minor of 1 or more) before calling it.
