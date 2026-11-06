# Quick start: a minimal BagSmith plugin

Three files make a plugin: a folder, a `.toc` and one Lua file. The complete working version of this
example is `BagSmith_ExamplePlugin/` (not shipped inside BagSmith; install it beside it to try it).

## 1. The TOC

```
## Interface: 16001
## Title: My Plugin
## Notes: What it does, in one line. No item actions.
## Version: 1.0.0
## Author: You
## Dependencies: BagSmith
## X-BagSmith-Plugin: my-plugin
## X-BagSmith-API: 1
## X-BagSmith-API-Minor: 0

MyPlugin.lua
```

`X-BagSmith-Plugin` is a stable, unique **ID** (letters, digits, `-`, `.`, `_`; not a display title).
`X-BagSmith-API` is the API **major** version you were written against; `X-BagSmith-API-Minor` is the
smallest minor you need (optional; 0 when omitted). BagSmith discovers plugins from these fields, loaded
or not, and refuses to activate a mismatched major or an unmet minor.

## 2. Registering

Register when your own saved variables are available (your `ADDON_LOADED`), with the same ID the TOC
declares. Registration never activates you inline; `onEnable` runs once, later, when BagSmith is ready,
whether you registered before or after that moment.

```lua
local ADDON = ...
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
	if name ~= ADDON then return end
	local api = BagSmith and BagSmith.API
	if not (api and api.RegisterPlugin) then print("My Plugin needs BagSmith with API 1.0"); return end
	local handle, code, msg = api:RegisterPlugin(
		{ id = "my-plugin", addon = ADDON, apiMajor = 1, apiMinor = 0, name = "My Plugin", version = "1.0.0" },
		{ onEnable = function(ctx) MyPlugin:Start(ctx) end, onShutdown = function(ctx, reason) MyPlugin:Stop(reason) end })
	if not handle then print("My Plugin could not register: " .. tostring(code) .. " " .. tostring(msg)) end
end)
```

## 3. A harmless lifecycle use case

```lua
MyPlugin = {}
function MyPlugin:Start(ctx)
	self.ctx = ctx
	self.unsub = ctx:Subscribe("VIEW_SHOWN", function(event, payload)
		local snap = ctx:GetTargets("main")          -- a detached snapshot, or nil + code
		if snap then print(#snap.targets .. " items in the bags") end
	end)
	ctx:RegisterCommand("mine", function(arg) print("hello from /bs mine " .. tostring(arg)) end)
	ctx:RegisterOptions({ title = "My Plugin", render = function(ui)
		ui:Check("Say hello", "Prints a line when the bags open", function() return self.ctx:ReadPreferences().hello end,
			function(v) local data, token = self.ctx:ReadPreferences(); data.hello = v; self.ctx:ReplacePreferences(data, token, 1) end)
	end })
end
function MyPlugin:Stop(reason) self.ctx = nil end   -- BagSmith disposes your subscriptions, command and options
```

## 4. Trying it

Copy the folder beside `BagSmith`, reload, open **Settings > Plugins**: your plugin appears with its
status; *Options* opens the page you registered. `/bs mine` runs your command.

## 5. Testing it

This repository's `tests` folder includes `tests/plugins_example_tests.lua`,
which shows how the example is tested against a mock client: load BagSmith, load your folder with
`tests/companion_loader.lua`, fire the two `ADDON_LOADED` events, and assert through the API. Run it with
`python3 tools/run_tests.py tests/plugins_example_tests.lua`.