--[[
	BagSmith Example Plugin: the smallest useful plugin, written only against BagSmith.API 1.0.

	What it does: when the bag view opens or its layout changes, it counts the item targets in the view and,
	if the "announce" preference is on, prints the count once per opening. It registers an options page with
	that one checkbox and a /bs example command that prints the count on demand. It never touches an item.

	Everything here is the documented public surface: registration with a manifest, a plugin context, view
	state and target snapshots, lifecycle subscriptions, copy-on-read preferences with a profile token, an
	options page and a command. Nothing of BagSmith's internals is read.
]]
local ADDON, ns = ...
local Example = {}
ns.Example = Example
_G.BagSmithExamplePlugin = ns   -- (for the example's own test; not a public contract)

local function print_(fmt, ...)
	local msg = (select("#", ...) > 0) and fmt:format(...) or fmt
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("|cff8ec5ffBagSmith Example:|r " .. msg) else print("BagSmith Example: " .. msg) end
end

-- Preferences: the plugin owns its own schema and defaults. Reads are copies; writes carry the profile token.
local SCHEMA = 1
function Example:Prefs()
	local data, token = self.ctx:ReadPreferences()
	if type(data.announce) ~= "boolean" then data.announce = false end   -- the default: quiet
	return data, token
end
function Example:SetAnnounce(on)
	local data, token = self:Prefs()
	data.announce = on and true or false
	local ok, code, msg = self.ctx:ReplacePreferences(data, token, SCHEMA)
	if not ok then print_("Could not save the preference (%s): %s", tostring(code), tostring(msg)) end
	return ok
end

-- The count: every item target in the open main view, on screen or not.
function Example:Count()
	local snap, code = self.ctx:GetTargets("main")
	if not snap then return nil, code end
	return #snap.targets, snap.generation
end

function Example:Activate(ctx)
	self.ctx = ctx
	self.counts = 0
	-- lifecycle: VIEW_SHOWN carries the view id and generation; VIEW_UPDATED follows every layout pass with valid geometry
	self.unsubShown = ctx:Subscribe("VIEW_SHOWN", function(_, payload)
		local n = self:Count()
		self.lastCount = n
		self.counts = self.counts + 1
		if self:Prefs().announce and n then print_("%d item%s in your bags.", n, n == 1 and "" or "s") end
	end)
	self.unsubUpdated = ctx:Subscribe("VIEW_UPDATED", function(_, payload) self.lastCount = self:Count(); self.lastGeneration = payload.generation end)
	self.unsubProfile = ctx:Subscribe("PROFILE_CHANGED", function() self.profileChanges = (self.profileChanges or 0) + 1 end)
	-- a command and an options page; both are disposed by BagSmith if the plugin is shut down
	self.disposeCommand = ctx:RegisterCommand("example", function()
		local n, code = self:Count()
		if n then print_("%d item%s in the open bags.", n, n == 1 and "" or "s") else print_("The bags are not open (%s).", tostring(code)) end
	end)
	self.disposeOptions = ctx:RegisterOptions({ title = "Example Plugin", render = function(ui)
		ui:Text("A starter plugin: it counts the items in the open bag view. It never uses, moves, sells or deletes anything.")
		ui:Check("Announce the count when the bags open", "Prints one line in chat each time the bag window opens.", function() return self:Prefs().announce end, function(v) self:SetAnnounce(v) end)
		ui:Button("Count now", function() local n = self:Count(); print_(n and (n .. " items") or "the bags are not open") end)
	end })
end
function Example:Shutdown(reason)
	-- best effort: BagSmith disposes API-owned subscriptions, options and commands; our own state is cleared here
	self.ctx = nil
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
	if name ~= ADDON then return end
	local api = _G.BagSmith and _G.BagSmith.API
	if not (api and api.RegisterPlugin) then print_("BagSmith with plugin API 1.0 is required; the example is idle."); return end
	local handle, code, msg = api:RegisterPlugin({ id = "bagsmith-example", addon = ADDON, apiMajor = 1, apiMinor = 0, name = "BagSmith Example Plugin", version = "1.0.0" },
		{ onEnable = function(ctx) Example:Activate(ctx) end, onShutdown = function(_, reason) Example:Shutdown(reason) end })
	if not handle then print_("Could not register with BagSmith (%s): %s", tostring(code), tostring(msg)) end
	Example.handle = handle
	-- An icon corner widget (API 1.1, BagSmith 1.5.0): a small star on epic items, top right by default. BagSmith
	-- places and shows it; the widget only says whether it has something for an item. Optional: an addon can
	-- register a corner widget without registering as a plugin.
	if api.RegisterCornerWidget then
		api.RegisterCornerWidget("Example: Epic Star", "bagsmith-example-star",
			function(widget, details) return details.quality == 4 end,   -- true: show; false: nothing here; nil: not ready yet
			function(button)
				local t = button:CreateTexture(nil, "OVERLAY")
				t:SetSize(12, 12); t:SetTexture("Interface\\AddOns\\BagSmith\\Media\\ui-star.tga")
				return t
			end,
			{ corner = "top_right", priority = 2 }, true)
	end
end)
