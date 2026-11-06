--[[
	BagSmith.API: the public plugin interface (API 1.0).

	Everything a plugin may rely on is here or documented in docs/plugins.
	Anything else in the addon (ns, the _G.BagSmith internals, the frames)
	is unsupported and may change without notice. Addon code cannot be
	sandboxed; this file defines supported behavior, not isolation.

	Contract summary (docs/plugins/API.md is the reference):
	  API:GetVersion() -> major, minor
	  API:RegisterPlugin(manifest, callbacks) -> handle | nil, code, message
	  context (given to onEnable and held by the handle):
	    GetViewState(viewId), GetTargets(viewId), Subscribe(event, fn),
	    EnsureTargetVisible(viewId, token), CloseView(viewId),
	    ShowTargetTooltip(viewId, token), ReleaseTooltip(lease),
	    ReadPreferences(), ReplacePreferences(value, profileToken, schemaVersion),
	    RegisterOptions(descriptor), RegisterCommand(name, fn),
	    ShowCopyableText(title, help, text)
	  events: VIEW_SHOWN, VIEW_HIDDEN, VIEW_UPDATED, PROFILE_CHANGED
	  codes: API.Codes (stable strings)
	No method performs an item action.
]]
local ADDON, ns = ...
local API = { VERSION = { major = 1, minor = 1 } }   -- 1.1 (BagSmith 1.5.0): icon corner widgets (Core/Corners.lua)
ns.API = API
_G.BagSmith = _G.BagSmith or {}
_G.BagSmith.API = API

API.Codes = {
	NOT_READY = "not-ready", UNSUPPORTED_VIEW = "unsupported-view", STALE_TARGET = "stale-target", HIDDEN = "hidden",
	COMBAT = "combat", STALE_PROFILE = "stale-profile", INCOMPATIBLE_API = "incompatible-api", DUPLICATE_PLUGIN = "duplicate-plugin",
	INVALID_MANIFEST = "invalid-manifest", MANIFEST_MISMATCH = "manifest-mismatch", INVALID_ARGUMENT = "invalid-argument",
	INVALID_DATA = "invalid-data", DUPLICATE_COMMAND = "duplicate-command", RESERVED_COMMAND = "reserved-command",
	DUPLICATE_OPTIONS = "duplicate-options", STALE_LEASE = "stale-lease", UNAVAILABLE = "unavailable", NOT_ACTIVE = "not-active",
}
local C = API.Codes
-- Plugin IDs whose "Official" label is a curated mapping kept here, never self-declared metadata.
API.OFFICIAL = { ["bagsmith-gamepad"] = { addon = "BagSmith_Gamepad", name = "BagSmith Gamepad" } }
API.MARKER, API.MARKER_API, API.MARKER_MINOR = "X-BagSmith-Plugin", "X-BagSmith-API", "X-BagSmith-API-Minor"
API.SUPPORTED_VIEWS = { main = true }
local MAX_ERRORS_SHOWN = 3

local plugins, order = {}, {}
API.plugins = plugins
local function copyPlain(v, depth)
	if type(v) ~= "table" then return v end
	depth = depth or 0
	local out = {}
	for k, x in pairs(v) do
		if type(x) == "table" then if depth < 8 then out[k] = copyPlain(x, depth + 1) end
		else out[k] = x end   -- (false included: never the and/or idiom here)
	end
	return out
end
local function fail(code, msg) return nil, code, msg end

function API:GetVersion() return self.VERSION.major, self.VERSION.minor end
function API:IsReady() return self.ready == true end

------------------------------------------------------------------------
-- Errors: attributed, bounded, never flooding chat.
------------------------------------------------------------------------
local function report(p, what, err)
	p.errorCount = (p.errorCount or 0) + 1
	p.lastError = ("%s: %s"):format(what, tostring(err))
	if p.errorCount <= MAX_ERRORS_SHOWN then
		ns:Print("Plugin %s failed in %s: %s", p.id, what, tostring(err))
		if p.errorCount == MAX_ERRORS_SHOWN then ns:Print("Plugin %s: further errors are kept in Settings > Plugins, not shown here.", p.id) end
	end
end
-- Any error in a plugin's callback (activation, event, command, options) is terminal for that plugin: it is
-- marked failed before anything else of it can run, its API-owned registrations and presentation lease are
-- disposed, and its cleanup callback is invoked once. Other plugins and core dispatch continue.
local failPlugin   -- (defined with Shutdown below)
local function call(p, what, fn, ...)
	if type(fn) ~= "function" then return true end
	local ok, err = pcall(fn, ...)
	if not ok then report(p, what, err); failPlugin(p, what, err) end
	return ok, err
end
-- The same guarded dispatch for core surfaces that run plugin code (the options page): the plugin must be
-- active at the moment of the call, and an error fails it through the one terminal path.
function API:Invoke(id, what, fn, ...)
	local p = plugins[id]
	if not p then return false, C.INVALID_ARGUMENT, "no such plugin" end
	if p.state ~= "active" then return false, C.NOT_ACTIVE, ("plugin %s is %s"):format(id, p.state) end
	local r = { call(p, what, fn, ...) }
	if not r[1] then return false, C.NOT_ACTIVE, r[2] end
	return unpack(r)
end
-- A guarded call that must not re-enter failure handling (the cleanup callback itself).
local function callQuiet(p, what, fn, ...)
	if type(fn) ~= "function" then return true end
	local ok, err = pcall(fn, ...)
	if not ok then report(p, what, err) end
	return ok, err
end

------------------------------------------------------------------------
-- Metadata and discovery: every installed addon that declares the marker,
-- loaded or not, enabled or not, without running any of its Lua.
------------------------------------------------------------------------
local function meta(name, field)
	local f = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
	if type(f) ~= "function" then return nil end
	local ok, v = pcall(f, name, field)
	if ok and type(v) == "string" and v ~= "" then return v end
	return nil
end
local enableStateFor   -- (defined below; used by the dependency check)
local function addonInfo(name)
	local f = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
	if type(f) ~= "function" then return nil end
	local ok, n, title, notes, loadable, reason = pcall(f, name)
	if not ok or type(n) ~= "string" or n == "" then return nil end   -- no such addon (an error or a nil return): explicitly unknown
	return { name = n, title = title, notes = notes, loadable = loadable, reason = reason }
end
-- The character this session manages addons for, as the client's own AddOn List identifies it: the player's
-- GUID (UnitGUID("player")), which EnableAddOn, DisableAddOn, GetAddOnEnableState and IsAddOnLoadable take as
-- their character argument. Nil when the client cannot say; then nothing is mutated. The name is display only.
local function thisCharacter()
	if type(UnitGUID) ~= "function" then return nil end
	local ok, g = pcall(UnitGUID, "player")
	if ok and type(g) == "string" and g ~= "" then return g end
	return nil
end
function API:CharacterName()
	if type(UnitName) ~= "function" then return nil end
	local ok, n = pcall(UnitName, "player")
	if ok and type(n) == "string" and n ~= "" and n ~= "Unknown" then return n end
	return nil
end
function API:AddOnManagement()
	local A = C_AddOns
	return type(A) == "table" and type(A.GetNumAddOns) == "function" and type(A.GetAddOnInfo) == "function" and type(A.GetAddOnMetadata) == "function"
end
function API:CanToggle()
	local A = C_AddOns
	return self:AddOnManagement() and type(A.EnableAddOn) == "function" and type(A.DisableAddOn) == "function" and type(A.GetAddOnEnableState) == "function"
end
enableStateFor = function(name)
	local A = C_AddOns
	if not (type(A) == "table" and type(A.GetAddOnEnableState) == "function") then return nil end
	local char = thisCharacter()
	if not char then return nil end   -- without the character the answer would be the account-wide one: unknown here
	local ok, st = pcall(A.GetAddOnEnableState, name, char)
	if not ok then return nil end
	local E = Enum and Enum.AddOnEnableState
	if type(E) == "table" then
		if st == E.None then return "disabled" elseif st == E.All or st == E.Some then return "enabled" end
	elseif type(st) == "number" then
		return st > 0 and "enabled" or "disabled"
	end
	return nil
end
local function isLoaded(name)
	local f = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
	if type(f) ~= "function" then return nil end
	local ok, v = pcall(f, name)
	if not ok then return nil end
	if v then return true end
	return false
end
-- Loadability of one addon for this character, the way the AddOn List reads it: IsAddOnLoadable(addon, guid)
-- when the client offers it and the character is known; otherwise the account-wide GetAddOnInfo answer
-- (the documented fallback). Returns loadable (true/false/nil for unknown), reason, and which source answered.
local function loadabilityOf(name)
	local A = C_AddOns
	local char = thisCharacter()
	if type(A) == "table" and type(A.IsAddOnLoadable) == "function" and char then
		local ok, loadable, reason = pcall(A.IsAddOnLoadable, name, char)
		if ok and type(loadable) == "boolean" then return loadable, reason, "character" end
		return nil, nil, "character"   -- the per-character query failed: unknown, never assumed
	end
	local info = addonInfo(name)
	if not info then return nil, nil, "none" end
	if type(info.loadable) ~= "boolean" then return nil, info.reason, "account" end
	return info.loadable, info.reason, "account"
end
API.LoadabilityOf = loadabilityOf   -- (for tests)
-- Every required dependency (the whole list, not a fixed few) must be installed and not disabled for this
-- character; a dependency the client cannot report is not assumed present. BagSmith itself is this addon.
-- Returns true for a verified list (an empty one included); otherwise false, the dependency and why:
-- "unverifiable" (the client cannot enumerate dependencies, or the call failed), "missing", "disabled",
-- "unknown" (its enable state or loadability cannot be determined), or "unloadable:<reason>". Nothing
-- here fails open. A dependency that loads on demand (DEMAND_LOADED) is legitimately not yet loaded.
local function dependenciesMet(name)
	local f = C_AddOns and C_AddOns.GetAddOnDependencies
	if type(f) ~= "function" then return false, nil, "unverifiable" end
	local r = { pcall(f, name) }
	if not r[1] then return false, nil, "unverifiable" end
	for i = 2, #r do
		local dep = r[i]
		if type(dep) == "string" and dep ~= "" and dep ~= ADDON then
			local info = addonInfo(dep)
			if not info then return false, dep, "missing" end
			local st = enableStateFor(dep)
			if st == nil then return false, dep, "unknown" end        -- the client could not say: never assumed ready
			if st == "disabled" then return false, dep, "disabled" end
			local loadable, reason = loadabilityOf(dep)   -- for this character when the client can say, as the plugin itself is judged
			if loadable == nil then return false, dep, "unknown" end
			if loadable == false then
				if reason == "DEMAND_LOADED" then                      -- legitimate: loads when asked
				elseif reason == nil or reason == "" then return false, dep, "unknown"
				elseif reason == "DISABLED" then return false, dep, "disabled"
				else return false, dep, "unloadable:" .. tostring(reason) end
			end
		end
	end
	return true, nil
end
-- A version field: omitted means the default; a supplied value must be a finite non-negative integer (a numeric
-- string from a TOC is fine). Returns the number, or nil and why.
local function versionField(v, default, what)
	if v == nil then return default end   -- omitted (a blank TOC field is omitted too: metadata reads return nil for it)
	local n = type(v) == "number" and v or (type(v) == "string" and tonumber(v)) or nil
	if n == nil or n ~= n or n == math.huge or n == -math.huge or n < 0 or math.floor(n) ~= n then return nil, ("%s must be a whole non-negative number, not %s"):format(what, tostring(v)) end
	return n
end
API.VersionField = versionField   -- (for tests)
-- Compatibility of a declared plugin with this API: major must match; minor must be <= ours.
function API:Compatible(major, minor)
	local whyM, whyN
	major, whyM = versionField(major, nil, "the API major")
	if whyM then return false, whyM end
	minor, whyN = versionField(minor, 0, "the API minor")
	if whyN then return false, whyN end
	if not major then return false, "no API major declared" end
	if major ~= self.VERSION.major then return false, ("requires API %d, this BagSmith provides %d"):format(major, self.VERSION.major) end
	if minor and minor > self.VERSION.minor then return false, ("requires API %d.%d, this BagSmith provides %d.%d"):format(major, minor, self.VERSION.major, self.VERSION.minor) end
	return true
end
-- Discovery: cached; refreshed when Settings opens and after our own enable changes. Never during render.
function API:RefreshPlugins()
	local list, byId, byAddon = {}, {}, {}
	if self:AddOnManagement() then
		local okN, n = pcall(C_AddOns.GetNumAddOns)
		for i = 1, (okN and n or 0) do
			local info = addonInfo(i)
			local id = info and meta(info.name, self.MARKER)
			if id then
				local majorV, majorWhy = versionField(meta(info.name, self.MARKER_API), nil, self.MARKER_API)
				local minorV, minorWhy = versionField(meta(info.name, self.MARKER_MINOR), 0, self.MARKER_MINOR)
				local entry = { id = id, addon = info.name, title = info.title or info.name, notes = info.notes or "",
					version = meta(info.name, "Version") or "", author = meta(info.name, "Author") or "",
					apiMajor = majorV, apiMinor = minorV or 0, problem = majorWhy or minorWhy,
					loadable = info.loadable and true or false, reason = info.reason, official = self.OFFICIAL[id] ~= nil and self.OFFICIAL[id].addon == info.name }
				if byId[id] then
					entry.problem = ("duplicate plugin ID %q, also declared by %s"):format(id, byId[id].addon)
					byId[id].problem = byId[id].problem or ("duplicate plugin ID %q, also declared by %s"):format(id, info.name)
				else byId[id] = entry end
				byAddon[info.name] = entry
				list[#list + 1] = entry
			end
		end
	end
	table.sort(list, function(a, b) return (a.title or "") < (b.title or "") end)
	self.discovered, self.discoveredById, self.discoveredByAddon = list, byId, byAddon
	-- the session baseline per addon: whether it loaded at login and what its enable state was before any change
	-- made here (a change is pending only when the current state differs from that baseline)
	self.loadedAtLogin = self.loadedAtLogin or {}
	self.enabledAtLogin = self.enabledAtLogin or {}
	for _, e in ipairs(list) do
		if self.loadedAtLogin[e.addon] == nil then self.loadedAtLogin[e.addon] = isLoaded(e.addon) end
		if self.enabledAtLogin[e.addon] == nil then self.enabledAtLogin[e.addon] = enableStateFor(e.addon) end
	end
	-- the status model, computed here and read by every render until the next refresh
	local cache, cacheById = {}, {}
	local cacheByAddon = {}
	for _, e in ipairs(list) do local item = { entry = e, status = self:PluginStatus(e) }; cache[#cache + 1] = item; cacheById[e.id] = cacheById[e.id] or item; cacheByAddon[e.addon] = item end
	self.listCache, self.listCacheById, self.listCacheByAddon = cache, cacheById, cacheByAddon
	return list
end
-- Status for one discovered entry: plain words; loaded, enabled-for-next-reload and active are distinct.
-- Why the game did not load an enabled addon, in plain words (the client's reason codes).
local LOAD_REASONS = { MISSING_DEPENDENCY = "a dependency is missing", DISABLED = "disabled", INTERFACE_VERSION = "it is written for another game version", INSECURE = "the game refused it", CORRUPT = "its files are damaged", DEP_DISABLED = "a dependency is disabled", DEP_MISSING = "a dependency is missing", DEP_INCOMPATIBLE = "a dependency is for another game version", DEP_INTERFACE_VERSION = "a dependency is for another game version", DEMAND_LOADED = "it loads on demand", INCOMPATIBLE = "it is incompatible with this client" }
-- The addon itself cannot load here (its own reason), or the game says one of its dependencies cannot (DEP_*).
local function wrongClient(entry) local r = entry.reason; return r == "INTERFACE_VERSION" or r == "INCOMPATIBLE" or r == "INSECURE" or r == "CORRUPT" end
local function depBlocked(entry) local r = entry.reason; return type(r) == "string" and (r:sub(1, 4) == "DEP_" or r == "MISSING_DEPENDENCY") end
-- Status for one discovered entry. Installed-addon identity is the addon folder; a runtime registration counts
-- for this row only when it came from this addon (a duplicate declaring the same ID never inherits it).
function API:PluginStatus(entry)
	local id = entry.id
	local reg = plugins[id]
	if reg and reg.addon ~= entry.addon then reg = nil end
	local loaded = isLoaded(entry.addon)
	local enabled = enableStateFor(entry.addon)
	-- loadability for this character (the AddOn List reads it this way), the same helper the dependency check uses;
	-- a per-character query that gave no answer is an unknown, which refuses enabling just as it does for dependencies
	local loadabilityUnknown = false
	do
		local loadable, reason, source = loadabilityOf(entry.addon)
		if source == "character" then
			if loadable == nil then loadabilityUnknown = true
			else entry = { id = entry.id, addon = entry.addon, title = entry.title, notes = entry.notes, version = entry.version, author = entry.author, apiMajor = entry.apiMajor, apiMinor = entry.apiMinor, official = entry.official, problem = entry.problem, loadable = loadable, reason = reason } end
		end
	end
	local wasEnabled = self.enabledAtLogin and self.enabledAtLogin[entry.addon]
	local active = reg ~= nil and reg.state == "active"
	local s = { id = id, addon = entry.addon, loaded = loaded, enabled = enabled, registered = reg ~= nil, state = reg and reg.state or nil, lastError = reg and reg.lastError or nil,
		pending = false, canEnable = true, canDisable = true, options = active and reg.options ~= nil, problem = entry.problem }
	local compatible, why = self:Compatible(entry.apiMajor, entry.apiMinor)
	local depsOk, dep, depWhy = dependenciesMet(entry.addon)
	-- a pending change is a real difference between the current enable state and this session's baseline
	if enabled ~= nil and wasEnabled ~= nil and enabled ~= wasEnabled then
		s.pending = true
		if enabled == "enabled" then s.pendingText = loaded and "Enabled (loaded)" or "Enabled, reload required"
		else s.pendingText = loaded and (active and "Disabled next reload, still active now" or "Disabled next reload, still loaded now") or "Disabled" end
	end
	-- eligibility is judged whether or not the addon is enabled now
	if entry.problem then s.text = "Installed, problem: " .. entry.problem; s.canEnable = false
	elseif not depsOk then
		if depWhy == "unverifiable" then s.text = "Installed, dependencies could not be verified on this client"
		else
			local how = depWhy == "disabled" and "disabled dependency" or depWhy == "missing" and "missing dependency" or depWhy == "unknown" and "dependency of unknown state"
				or ("unusable dependency (" .. (LOAD_REASONS[(depWhy or ""):match("^unloadable:(.*)$") or ""] or tostring((depWhy or ""):match("^unloadable:(.*)$"))) .. ")")
			s.text = ("Installed, %s %s"):format(how, tostring(dep))
		end
		s.canEnable = false
	elseif not compatible then s.text = "Incompatible, " .. why; s.canEnable = false
	elseif wrongClient(entry) then s.text = "Installed, unavailable on this client (" .. (LOAD_REASONS[entry.reason] or tostring(entry.reason)) .. ")"; s.canEnable = false
	elseif loadabilityUnknown and not loaded then s.text = "Installed, loadability unknown for this character (the client gave no answer); enabling is not offered"; s.canEnable = false
	elseif depBlocked(entry) then s.text = "Installed, " .. (LOAD_REASONS[entry.reason] or ("the game reports " .. tostring(entry.reason))); s.canEnable = false
	elseif reg and reg.state == "failed" then s.text = "Failed to start" .. (reg.lastError and (": " .. reg.lastError) or "")
	elseif active then s.text = s.pending and s.pendingText or "Active"
	elseif reg and reg.state == "incompatible" then s.text = "Incompatible, " .. tostring(reg.lastError)
	elseif reg and (reg.state == "registered" or reg.state == "waiting") then s.text = "Registered, waiting for BagSmith"
	elseif loaded and not reg then s.text = s.pending and s.pendingText or "Loaded, not registered with the BagSmith API"
	elseif enabled == "enabled" then
		if s.pending then s.text = s.pendingText
		elseif loaded == false then s.text = "Enabled, not loaded" .. (entry.reason and entry.reason ~= "" and (": " .. (LOAD_REASONS[entry.reason] or tostring(entry.reason))) or " (reload required)")
		else s.text = "Enabled" end
	elseif enabled == "disabled" then s.text = s.pending and s.pendingText or "Disabled"
	else s.text = "Installed (enable state unavailable; use the game's AddOns screen)"; s.canEnable = false; s.canDisable = false end
	if not self:CanToggle() then s.canEnable = false; s.canDisable = false; s.manageElsewhere = true end
	return s
end
-- The cached model (refreshed by RefreshPlugins: when Settings opens, after a toggle here, when a plugin's
-- registration state changes). Rendering reads it and never enumerates the addon list.
function API:PluginList()
	if not self.listCache then self:RefreshPlugins() end
	return self.listCache
end
function API:PluginItem(id)
	if not self.listCacheById then self:RefreshPlugins() end
	return self.listCacheById[id]
end
function API:PluginItemByAddon(addon)
	if not self.listCacheByAddon then self:RefreshPlugins() end
	return self.listCacheByAddon and self.listCacheByAddon[addon] or nil
end
-- Enable or disable for THIS CHARACTER, read back before reporting; takes effect after a user-requested reload.
-- Enable or disable ONE installed addon (by its folder name, the canonical identity of a row) for THIS CHARACTER,
-- read back before reporting; takes effect after a user-requested reload. The character must be known.
function API:SetPluginEnabled(addon, enabled)
	if InCombatLockdown and InCombatLockdown() then return false, C.COMBAT, "Not in combat. Try again when the fight is over." end
	if not self:CanToggle() then return false, C.UNAVAILABLE, "This client offers no addon enable controls here; use the game's AddOns screen." end
	local e = self.discoveredByAddon and self.discoveredByAddon[addon]
	if not e or not addonInfo(addon) then return false, C.INVALID_ARGUMENT, "No installed plugin addon named " .. tostring(addon) .. "." end
	local char = thisCharacter()
	if not char then return false, C.UNAVAILABLE, "The character this change applies to is not known yet; use the game's AddOns screen." end
	local s = self:PluginStatus(e)
	if enabled and not s.canEnable then return false, C.UNAVAILABLE, s.text end
	if not enabled and not s.canDisable then return false, C.UNAVAILABLE, s.text end
	local ok, err = pcall(enabled and C_AddOns.EnableAddOn or C_AddOns.DisableAddOn, e.addon, char)
	if not ok then return false, C.UNAVAILABLE, tostring(err) end
	local now = enableStateFor(e.addon)
	if (enabled and now ~= "enabled") or (not enabled and now ~= "disabled") then return false, C.UNAVAILABLE, "The game did not record the change; check the AddOns screen." end
	self:RefreshPlugins()
	return true, now
end
function API:PendingReloadCount()
	local n = 0
	for _, item in ipairs(self:PluginList()) do if item.status.pending then n = n + 1 end end
	return n
end
function API:RequestReload()
	if InCombatLockdown and InCombatLockdown() then return false, C.COMBAT, "Reloading the interface is not possible in combat. Try again when the fight is over." end
	if type(ReloadUI) ~= "function" then return false, C.UNAVAILABLE, "Reload is not available here." end
	ReloadUI()
	return true
end

------------------------------------------------------------------------
-- Events: dispatch to a snapshot; a listener disposed during a dispatch
-- does not run later in it; one added during a dispatch joins the next.
------------------------------------------------------------------------
local EVENTS = { VIEW_SHOWN = true, VIEW_HIDDEN = true, VIEW_UPDATED = true, PROFILE_CHANGED = true }
API.EVENTS = EVENTS
local listeners = {}   -- event -> array of { fn, plugin, dead }
local function dispatch(event, payload)
	local list = listeners[event]
	if not list or #list == 0 then return end
	local snap = {}
	for i, l in ipairs(list) do snap[i] = l end
	for _, l in ipairs(snap) do
		if not l.dead and l.plugin.state == "active" then call(l.plugin, "event " .. event, l.fn, event, copyPlain(payload)) end
	end
end
local function subscribe(p, event, fn)
	if not EVENTS[event] then return fail(C.INVALID_ARGUMENT, "unknown event " .. tostring(event)) end
	if type(fn) ~= "function" then return fail(C.INVALID_ARGUMENT, "callback must be a function") end
	local l = { fn = fn, plugin = p, dead = false }
	listeners[event] = listeners[event] or {}
	table.insert(listeners[event], l)
	p.subs[#p.subs + 1] = l
	return function()
		if l.dead then return false end
		l.dead = true
		local list = listeners[event]
		for i = #list, 1, -1 do if list[i] == l then table.remove(list, i) end end
		return true
	end
end

------------------------------------------------------------------------
-- Views and targets (v1: the live main bags view only).
------------------------------------------------------------------------
local gen = { main = 0 }
-- Tokens are issued once per (button, bag, slot, item, generation) identity and never re-pointed: when any of
-- those changes, the old record is retired for good and a new token is issued. A later snapshot of the same
-- unchanged presentation returns the same token.
local tokens = {}   -- token -> { token, view, generation, button, bag, slot, link }
local issued = setmetatable({}, { __mode = "k" })   -- button -> its current record
local nextIssue = 0
local function mainView() return ns.Window and ns.Window.main or nil end
local function viewFrame() local v = mainView(); return v and v.frame or nil end
local function viewOpen() local f = viewFrame(); return f ~= nil and f:IsShown() and true or false end
local function inCombat() return InCombatLockdown and InCombatLockdown() or false end
local function checkView(viewId)
	if viewId ~= "main" then return fail(C.UNSUPPORTED_VIEW, "only the live main bags view (\"main\") is supported by API 1.0") end
	if not API.ready then return fail(C.NOT_READY, "BagSmith is not ready yet") end
	return true
end
local function bagSlotOf(b)
	local bag, slot = b.bag, b.slot
	if bag == nil then local ok, p = pcall(b.GetParent, b); if ok and p and p.GetID then local okI, id = pcall(p.GetID, p); if okI then bag = id end end end
	if slot == nil and b.GetID then local ok, id = pcall(b.GetID, b); if ok then slot = id end end
	return bag, slot
end
local function linkOf(bag, slot)
	local f = C_Container and C_Container.GetContainerItemLink
	if type(f) == "function" then local ok, l = pcall(f, bag, slot); if ok and type(l) == "string" then return l end end
	local g = C_Container and C_Container.GetContainerItemInfo
	if type(g) == "function" then local ok, info = pcall(g, bag, slot); if ok and type(info) == "table" and type(info.hyperlink) == "string" then return info.hyperlink end end
	return nil
end
local function underFrame(b, root)
	local p = b
	for _ = 1, 32 do
		if p == root then return true end
		p = p.GetParent and p:GetParent() or nil
		if not p then return false end
	end
	return false
end
local function visible(b, root)
	if not b or not b.IsShown or not b:IsShown() then return false end
	if b.IsVisible and not b:IsVisible() then return false end
	return underFrame(b, root)
end
-- Each edge on its own: a client (or a harness) may report some edges and not others; a missing edge is nil.
local function edge(f, method)
	local fn = f and f[method]
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, f)
	if ok and type(v) == "number" then return v end
	return nil
end
local function rectOf(f) return edge(f, "GetLeft"), edge(f, "GetRight"), edge(f, "GetTop"), edge(f, "GetBottom") end
function API:ViewState(viewId)
	local ok, code, msg = checkView(viewId)
	if not ok then return nil, code, msg end
	return { id = "main", open = viewOpen(), ready = self.ready == true, generation = gen.main, inCombat = inCombat() }
end
-- A detached snapshot of the view's item targets: every item button placed in the view, on screen or not,
-- with geometry in one space (the view's own; compare only within a snapshot) and whether it is inside the
-- scroll window. Each target carries an opaque token bound to this button, this item and this generation.
function API:Targets(viewId)
	local ok, code, msg = checkView(viewId)
	if not ok then return nil, code, msg end
	local root = viewFrame()
	if not root or not root:IsShown() then return fail(C.HIDDEN, "the main bags view is not open") end
	local B = ns.Buttons
	local view = mainView()
	local sf = view and view.scroll
	local vl, vr, vt, vb
	if sf then vl, vr, vt, vb = rectOf(sf) end
	local out = { id = "main", generation = gen.main, open = true, targets = {} }
	local function consider(b)
		if not (b and b.hasItem and visible(b, root)) then return end
		local l, r, t, btm = rectOf(b)
		local okC, cx, cy = pcall(b.GetCenter, b)
		if not (okC and type(cx) == "number" and type(cy) == "number") then return end
		local bag, slot = bagSlotOf(b)
		local link = linkOf(bag, slot)
		local rec = issued[b]
		if not (rec and rec.generation == gen.main and rec.bag == bag and rec.slot == slot and rec.link == link) then
			if rec then tokens[rec.token] = nil end   -- retired for good: this token never means anything again
			nextIssue = nextIssue + 1
			rec = { token = ("main:%d:%d"):format(gen.main, nextIssue), view = "main", generation = gen.main, button = b, bag = bag, slot = slot, link = link }
			issued[b] = rec; tokens[rec.token] = rec
		end
		local token = rec.token
		-- inside the scroll window on every edge that is known (an unknown edge does not exclude)
		local inView = (vl == nil or l == nil or l >= vl - 0.5) and (vr == nil or r == nil or r <= vr + 0.5) and (vt == nil or t == nil or t <= vt + 0.5) and (vb == nil or btm == nil or btm >= vb - 0.5)
		local okS, scale = pcall(b.GetEffectiveScale, b)
		-- an edge the client did not report stays nil, and a size needs both of its edges
		local width = (type(l) == "number" and type(r) == "number") and (r - l) or nil
		local height = (type(t) == "number" and type(btm) == "number") and (t - btm) or nil
		out.targets[#out.targets + 1] = { token = token, bag = bag, slot = slot, link = link, name = link and link:match("%[(.-)%]") or nil,
			x = cx, y = cy, left = l, right = r, top = t, bottom = btm, width = width, height = height,
			scale = okS and scale or nil, inViewport = inView, anchor = b }   -- anchor: borrowed, temporary; never reparent, resize, re-script or activate it
	end
	if B then
		for _, slots in pairs(B.byBag or {}) do for _, b in pairs(slots) do consider(b) end end
		for _, b in ipairs(B.recent or {}) do consider(b) end
	end
	-- a stable order: top to bottom, then left to right
	table.sort(out.targets, function(a, b) if a.y ~= b.y then return a.y > b.y end return a.x < b.x end)
	return out
end
-- Resolve a token to its button only if the same button still shows the same item in the current view.
local function resolve(viewId, token)
	local ok, code, msg = checkView(viewId)
	if not ok then return nil, code, msg end
	local t = type(token) == "string" and tokens[token] or nil
	if not t then return fail(C.STALE_TARGET, "unknown or expired target token") end
	if t.generation ~= gen.main then tokens[token] = nil; if issued[t.button] == t then issued[t.button] = nil end; return fail(C.STALE_TARGET, "the view has been rebuilt since this snapshot") end
	local root = viewFrame()
	if not root or not root:IsShown() then return fail(C.HIDDEN, "the main bags view is not open") end
	local b = t.button
	if not (b and b.hasItem and visible(b, root)) then tokens[token] = nil; if issued[b] == t then issued[b] = nil end; return fail(C.STALE_TARGET, "this target is no longer shown") end
	local bag, slot = bagSlotOf(b)
	if bag ~= t.bag or slot ~= t.slot then tokens[token] = nil; if issued[b] == t then issued[b] = nil end; return fail(C.STALE_TARGET, "this button now shows another slot") end
	local link = linkOf(bag, slot)
	if link ~= t.link then tokens[token] = nil; if issued[b] == t then issued[b] = nil end; return fail(C.STALE_TARGET, "the item in this slot has changed") end
	return t
end
API.ResolveTarget = resolve   -- (for tests and tooling; the contract is the methods below)
-- Scroll the view's list by the smallest amount that shows the target whole, with a one-row margin, within the
-- list's range, through the view's own tagged scroll, stamped as a scroll by the player so a rebuild's deferred
-- restore never undoes it. Refused in combat. Returns ok, changed, state.
function API:EnsureTargetVisible(viewId, token)
	local t, code, msg = resolve(viewId, token)
	if not t then return false, code, msg end
	if inCombat() then return false, C.COMBAT, "not in combat" end
	local view, b = mainView(), t.button
	local sf = view and view.scroll
	if not (sf and view.SetScrollTagged and view.ScrollRange) then return false, C.UNAVAILABLE, "this view does not scroll" end
	local ok, sfTop, sfBottom, bTop, bBottom, bH = pcall(function() return sf:GetTop(), sf:GetBottom(), b:GetTop(), b:GetBottom(), b:GetHeight() end)
	if not ok or type(sfTop) ~= "number" or type(sfBottom) ~= "number" or type(bTop) ~= "number" or type(bBottom) ~= "number" then return false, C.UNAVAILABLE, "no geometry" end
	local margin = (type(bH) == "number" and bH > 0) and bH or 24
	local now = (sf.GetVerticalScroll and sf:GetVerticalScroll()) or 0
	local target = now
	if bTop > sfTop then target = now - (bTop - sfTop) - margin
	elseif bBottom < sfBottom then target = now + (sfBottom - bBottom) + margin
	else return true, false, self:ViewState("main") end
	local range = view:ScrollRange() or 0
	if target < 0 then target = 0 end
	if target > range then target = range end
	if math.abs(target - now) < 0.5 then return true, false, self:ViewState("main") end
	view.userScrollAt = GetTime and GetTime() or 0
	view:SetScrollTagged(target, "plugin")
	return true, true, self:ViewState("main")
end
-- A frame BagSmith owns inside the main view's scroll region, for plugin-owned overlays (a highlight): it is
-- clipped by the list like the item buttons, hidden with the view, and plugins may parent their own frames to
-- it. It is the only frame of BagSmith's a plugin may parent into.
function API:OverlayParent(viewId)
	local ok, code, msg = checkView(viewId)
	if not ok then return nil, code, msg end
	local view = mainView()
	local host = view and view.child or (view and view.scroll) or viewFrame()
	if not host then return nil, C.UNAVAILABLE, "the view has no overlay host" end
	if not view.pluginOverlay then
		local f = CreateFrame("Frame", "BagSmithMainViewOverlay", host)
		f:SetAllPoints(host)
		f:SetFrameLevel((host.GetFrameLevel and host:GetFrameLevel() or 0) + 20)
		f:EnableMouse(false)
		view.pluginOverlay = f
	end
	return view.pluginOverlay
end
function API:CloseView(viewId)
	local ok, code, msg = checkView(viewId)
	if not ok then return false, code, msg end
	if not viewOpen() then return false, C.HIDDEN, "already closed" end
	if ns.Window and ns.Window.Hide then ns.Window:Hide() end
	return true
end

------------------------------------------------------------------------
-- Tooltip lease: hide only the tooltip the plugin showed, never one the
-- mouse opened afterwards, even for the same item frame.
------------------------------------------------------------------------
local tip = { serial = 0, lease = nil }
-- The lease ends on an explicit ownership signal: BagSmith's own item buttons report the mouse entering them
-- (ITEM_MOUSE_ENTER, the same frame included, shown or not), and the tooltip being hidden. Visibility
-- transitions alone are not relied on (no frame-method hooks on this client).
ns:OnSignal("ITEM_MOUSE_ENTER", function() tip.lease = nil end)
local function hookTooltip()
	if tip.hooked or not (GameTooltip and GameTooltip.HookScript) then return end
	tip.hooked = true
	pcall(GameTooltip.HookScript, GameTooltip, "OnHide", function() tip.lease = nil end)
end
function API:ShowTargetTooltip(viewId, token)
	local t, code, msg = resolve(viewId, token)
	if not t then return nil, code, msg end
	if not (GameTooltip and GameTooltip.SetOwner and GameTooltip.SetBagItem) then return nil, C.UNAVAILABLE, "no tooltip" end
	hookTooltip()
	tip.serial = tip.serial + 1
	local lease = { id = tip.serial, token = token, button = t.button, plugin = tip.requester, bag = t.bag, slot = t.slot, link = t.link }
	local ok = pcall(GameTooltip.SetOwner, GameTooltip, t.button, "ANCHOR_RIGHT")
	if ok then ok = pcall(GameTooltip.SetBagItem, GameTooltip, t.bag, t.slot) end
	if ok then pcall(GameTooltip.Show, GameTooltip) end
	if not ok then pcall(GameTooltip.Hide, GameTooltip); return nil, C.UNAVAILABLE, "the tooltip could not be shown" end
	tip.lease = lease
	return lease
end
function API:TooltipLeaseValid(lease) return type(lease) == "table" and tip.lease == lease end
function API:ReleaseTooltip(lease)
	if not self:TooltipLeaseValid(lease) then return false, C.STALE_LEASE, "not the current lease (nothing hidden)" end
	-- the mouse may have taken the same frame: with the hooks, that already ended the lease; without them, the owner check is all there is
	tip.lease = nil
	-- the same-frame case is settled by the item-button signal above; for any other frame the tooltip's owner is the
	-- secondary check, so a tooltip something else owns is never hidden by a release
	if GameTooltip and GameTooltip.GetOwner then
		local ok, owner = pcall(GameTooltip.GetOwner, GameTooltip)
		if ok and owner ~= lease.button then return false, C.STALE_LEASE, "the tooltip belongs to something else now" end
	end
	pcall(GameTooltip.Hide, GameTooltip)
	return true
end
-- After a layout pass the leased presentation may no longer show the leased item: a lease whose button, slot or
-- item changed is released (its tooltip hidden if still on that frame); a lease the mouse has taken is already
-- gone, so a mouse-owned tooltip is never touched here.
function API:ValidateLease()
	local l = tip.lease
	if not l then return end
	local b = l.button
	local root = viewFrame()
	local ok = b and b.hasItem and root and root:IsShown() and visible(b, root)
	if ok then
		local bag, slot = bagSlotOf(b)
		ok = (bag == l.bag and slot == l.slot and linkOf(bag, slot) == l.link)
	end
	if not ok then self:DropLeaseOf(nil) end
end
-- Hide the tooltip only if the current lease is this plugin's and still on its frame (a plugin ending, a profile change).
function API:DropLeaseOf(p)
	local l = tip.lease
	if not l or not (p == nil or l.plugin == p) then return end
	tip.lease = nil
	if GameTooltip and GameTooltip.GetOwner then
		local ok, owner = pcall(GameTooltip.GetOwner, GameTooltip)
		if ok and owner ~= l.button then return end
	end
	pcall(GameTooltip.Hide, GameTooltip)
end

------------------------------------------------------------------------
-- Preferences: a bounded plain-data namespace inside the active profile,
-- copy on read, validated on write, paired with a transient profile token.
------------------------------------------------------------------------
API.profileToken = 1
local function container()
	if not ns.db then return nil end
	if type(ns.db.plugins) ~= "table" then ns.db.plugins = {} end
	return ns.db.plugins
end
local function readPrefs(p)
	local c = container()
	local entry = c and c[p.id]
	local data = entry and type(entry.data) == "table" and copyPlain(entry.data) or {}
	return data, API.profileToken, entry and entry.schemaVersion or nil
end
local function replacePrefs(p, value, token, schemaVersion)
	if token ~= API.profileToken then return false, C.STALE_PROFILE, "the profile changed since these preferences were read" end
	local clean, why, size = ns.ValidatePluginData(value)
	if clean == nil then return false, C.INVALID_DATA, why end
	local c = container()
	if not c then return false, C.NOT_READY, "no active profile" end
	local sv0 = schemaVersion
	if sv0 == nil then sv0 = (c[p.id] and c[p.id].schemaVersion) or 1 end
	if not ns.ValidSchemaVersion(sv0) then return false, C.INVALID_DATA, "schemaVersion must be a finite non-negative integer" end
	-- two bounds: the cheap aggregate cap on plugin data (the validator's measure), and the one that matters for
	-- the guarantee: the share code the whole profile would produce after this write must fit the sharing limit.
	-- Only the new write is refused; nothing already stored or imported is ever trimmed to fit.
	local others = 0
	for id, entry in pairs(c) do if id ~= p.id and type(entry) == "table" then others = others + ns.PluginDataSize(entry.data) end end
	if others + (size or 0) > ns.PLUGIN_DATA_AGGREGATE then return false, C.INVALID_DATA, ("all plugin preferences in this profile together would exceed %d bytes"):format(ns.PLUGIN_DATA_AGGREGATE) end
	if ns.Share and ns.Share.CodeLength and ns.db then
		local previous = c[p.id]
		c[p.id] = { schemaVersion = sv0 or 1, data = clean }
		local len, limit = ns.Share:CodeLength(ns.db)
		c[p.id] = previous
		if len == nil then return false, C.INVALID_DATA, "the profile could not be serialized with this data" end
		if len > limit then return false, C.INVALID_DATA, ("with this data the profile's share code would be %d characters, over the %d limit"):format(len, limit) end
	end
	c[p.id] = { schemaVersion = sv0, data = clean }
	return true
end

------------------------------------------------------------------------
-- Options and commands.
------------------------------------------------------------------------
API.commands = {}
local RESERVED = {}
function API:ReserveCommands(list) for _, n in ipairs(list) do RESERVED[n] = true end end
local function registerCommand(p, name, fn)
	if type(name) ~= "string" or name == "" or name:find("%s") then return fail(C.INVALID_ARGUMENT, "a command name is one word") end
	name = name:lower()
	if RESERVED[name] then return fail(C.RESERVED_COMMAND, ("%q is a BagSmith command"):format(name)) end
	if API.commands[name] and API.commands[name].plugin ~= p then return fail(C.DUPLICATE_COMMAND, ("%q is registered by %s"):format(name, API.commands[name].plugin.id)) end
	if type(fn) ~= "function" then return fail(C.INVALID_ARGUMENT, "callback must be a function") end
	local rec = { plugin = p, fn = fn }
	API.commands[name] = rec
	p.commands[name] = rec
	local disposed = false
	return function()
		if disposed then return false end
		disposed = true
		if API.commands[name] ~= rec then return false end   -- a newer registration owns the name now: untouched
		API.commands[name] = nil
		if p.commands[name] == rec then p.commands[name] = nil end
		return true
	end
end
-- The core slash dispatcher's hook: /bs <name> ... for a registered plugin command.
function API:DispatchCommand(name, arg)
	local c = self.commands[name and name:lower() or ""]
	if not c then return false end
	if c.plugin.state ~= "active" then ns:Print("The %s plugin is not active (%s).", c.plugin.id, c.plugin.state); return true end
	call(c.plugin, "command " .. name, c.fn, arg)
	return true
end
local function registerOptions(p, descriptor)
	if type(descriptor) ~= "table" or type(descriptor.render) ~= "function" then return fail(C.INVALID_ARGUMENT, "options need a render function") end
	if p.options then return fail(C.DUPLICATE_OPTIONS, "options already registered") end
	local rec = { title = type(descriptor.title) == "string" and descriptor.title or p.manifest.name or p.id, render = descriptor.render }
	p.options = rec
	local disposed = false
	return function()
		if disposed then return false end
		disposed = true
		if p.options ~= rec then return false end   -- a newer registration: untouched
		p.options = nil
		if API.listCache then API:RefreshPlugins() end
		return true
	end
end

------------------------------------------------------------------------
-- Registration, readiness and activation.
------------------------------------------------------------------------
local function makeContext(p)
	local ctx = { pluginId = p.id }
	-- Once a plugin is failed or shut down, its retained context keeps only read-only queries and the
	-- release of what it still holds; everything that would register, present or write is refused.
	local function active() if p.state == "active" then return true end return false, C.NOT_ACTIVE, ("plugin %s is %s"):format(p.id, p.state) end
	function ctx:GetViewState(viewId) return API:ViewState(viewId) end
	function ctx:GetTargets(viewId) return API:Targets(viewId) end
	function ctx:GetOverlayParent(viewId) return API:OverlayParent(viewId) end
	function ctx:Subscribe(event, fn) local ok, code, msg = active(); if not ok then return nil, code, msg end return subscribe(p, event, fn) end
	function ctx:EnsureTargetVisible(viewId, token) local ok, code, msg = active(); if not ok then return false, code, msg end return API:EnsureTargetVisible(viewId, token) end
	function ctx:CloseView(viewId) local ok, code, msg = active(); if not ok then return false, code, msg end return API:CloseView(viewId) end
	function ctx:ShowTargetTooltip(viewId, token) local ok, code, msg = active(); if not ok then return nil, code, msg end tip.requester = p; local l, c2, m2 = API:ShowTargetTooltip(viewId, token); tip.requester = nil; return l, c2, m2 end
	function ctx:ReleaseTooltip(lease) return API:ReleaseTooltip(lease) end
	function ctx:ReadPreferences() return readPrefs(p) end
	function ctx:ReplacePreferences(value, token, schemaVersion) local ok, code, msg = active(); if not ok then return false, code, msg end return replacePrefs(p, value, token, schemaVersion) end
	function ctx:RegisterOptions(descriptor) local ok, code, msg = active(); if not ok then return nil, code, msg end return registerOptions(p, descriptor) end
	function ctx:RegisterCommand(name, fn) local ok, code, msg = active(); if not ok then return nil, code, msg end return registerCommand(p, name, fn) end
	function ctx:ShowCopyableText(title, help, text)
		local okA, code, msg = active(); if not okA then return false, code, msg end
		if type(ns.ShareWindow) ~= "function" then return false, C.UNAVAILABLE, "no copy window" end
		ns.ShareWindow("text", { title = tostring(title or ""), help = tostring(help or ""), text = tostring(text or "") })
		return true
	end
	function ctx:GetState() return p.state end
	return ctx
end
local function activate(p)
	if p.state ~= "waiting" and p.state ~= "registered" then return end
	p.state = "active"
	call(p, "onEnable", p.callbacks.onEnable, p.context)   -- (an error here fails the plugin through the one terminal path)
	if API.listCache then API:RefreshPlugins() end
end
local function activateAll()
	for _, id in ipairs(order) do local p = plugins[id]; if p and (p.state == "waiting" or p.state == "registered") then activate(p) end end
end
function API:RegisterPlugin(manifest, callbacks)
	if type(manifest) ~= "table" then return fail(C.INVALID_MANIFEST, "manifest must be a table") end
	local id, addon = manifest.id, manifest.addon
	if type(id) ~= "string" or not id:match("^[%w%-%._]+$") or #id > 64 then return fail(C.INVALID_MANIFEST, "id must be a short identifier (letters, digits, - . _)") end
	if type(addon) ~= "string" or addon == "" then return fail(C.INVALID_MANIFEST, "addon must name the declaring addon folder") end
	callbacks = callbacks or {}
	if type(callbacks) ~= "table" then return fail(C.INVALID_MANIFEST, "callbacks must be a table") end
	-- version fields: malformed values are a manifest error (not an incompatibility); then the host's compatibility
	local mMajor, mWhy = versionField(manifest.apiMajor, nil, "apiMajor")
	if mWhy then return fail(C.INVALID_MANIFEST, mWhy) end
	if mMajor == nil then return fail(C.INVALID_MANIFEST, "apiMajor is required") end
	local mMinor, nWhy = versionField(manifest.apiMinor, 0, "apiMinor")
	if nWhy then return fail(C.INVALID_MANIFEST, nWhy) end
	local okV, why = self:Compatible(mMajor, mMinor)
	if not okV then return fail(C.INCOMPATIBLE_API, why) end
	if plugins[id] then return fail(C.DUPLICATE_PLUGIN, ("plugin %q is already registered by %s"):format(id, plugins[id].addon)) end
	-- the declaring addon's TOC must agree with the runtime manifest: the marker must be present and equal, the
	-- declared API major equal, and a declared minor equal; the plugin the UI describes is the one that activates
	if self:AddOnManagement() then
		-- the client can look addons up: the declaring addon must exist (a wrong name never bypasses the checks)
		if not addonInfo(addon) then return fail(C.INVALID_MANIFEST, ("no installed addon named %q declares this plugin"):format(addon)) end
		local declared = meta(addon, self.MARKER)
		if declared == nil then return fail(C.INVALID_MANIFEST, ("%s declares no %s in its TOC"):format(addon, self.MARKER)) end
		if declared ~= id then return fail(C.MANIFEST_MISMATCH, ("%s declares %s=%q, not %q"):format(addon, self.MARKER, declared, id)) end
		local tocMajorRaw = meta(addon, self.MARKER_API)
		if tocMajorRaw == nil then return fail(C.INVALID_MANIFEST, ("%s declares no %s in its TOC"):format(addon, self.MARKER_API)) end
		local tocMajor, tMajWhy = versionField(tocMajorRaw, nil, self.MARKER_API)
		if tMajWhy then return fail(C.INVALID_MANIFEST, ("%s: %s"):format(addon, tMajWhy)) end
		if tocMajor ~= mMajor then return fail(C.MANIFEST_MISMATCH, ("%s declares %s=%d, the manifest says %d"):format(addon, self.MARKER_API, tocMajor, mMajor)) end
		local tocMinorRaw = meta(addon, self.MARKER_MINOR)
		if tocMinorRaw ~= nil then
			local tocMinor, tMinWhy = versionField(tocMinorRaw, 0, self.MARKER_MINOR)
			if tMinWhy then return fail(C.INVALID_MANIFEST, ("%s: %s"):format(addon, tMinWhy)) end
			if tocMinor ~= mMinor then return fail(C.MANIFEST_MISMATCH, ("%s declares %s=%d, the manifest says %d"):format(addon, self.MARKER_MINOR, tocMinor, mMinor)) end
		end
	end
	local p = { id = id, addon = addon, manifest = copyPlain(manifest), callbacks = callbacks, state = self.ready and "registered" or "waiting", subs = {}, commands = {}, errorCount = 0 }
	p.context = makeContext(p)
	plugins[id] = p
	order[#order + 1] = id
	-- activation is deferred (never inline), once, after readiness; a late registration gets the same path
	if self.ready then ns:NextFrame("api:activate:" .. id, function() activate(p) end) end
	local handle = { id = id, context = p.context }
	function handle:GetState() return p.state end
	return handle
end
-- Shutdown: dispose API-owned subscriptions, options and commands; ask the plugin to clean up (best effort).
-- Ordinary disablement is reload-oriented; this does not unload code.
failPlugin = function(p, what, err)
	if p.state ~= "active" and p.state ~= "registered" and p.state ~= "waiting" then return end
	p.state = "failed"           -- before anything else of this plugin can run, including later listeners in a dispatch
	API:Shutdown(p.id, ("%s: %s"):format(what, tostring(err)))
end
-- The one terminal transition: dispose API-owned subscriptions, options and commands and the plugin's tooltip
-- lease, then ask the plugin to clean up, once. Ordinary disablement is reload-oriented; this unloads no code.
function API:Shutdown(id, reason)
	local p = plugins[id]
	if not p then return false end
	if p.shutDown then return false end
	p.shutDown = true
	p.state = "failed"
	for _, l in ipairs(p.subs) do l.dead = true end
	for event, list in pairs(listeners) do for i = #list, 1, -1 do if list[i].plugin == p then table.remove(list, i) end end end
	p.subs = {}
	for name, rec in pairs(p.commands) do if API.commands[name] == rec then API.commands[name] = nil end end
	p.commands = {}
	p.options = nil
	self:DropLeaseOf(p)
	callQuiet(p, "onShutdown", p.callbacks.onShutdown, p.context, reason)
	if API.listCache then API:RefreshPlugins() end
	ns:Fire("PLUGIN_STATE_CHANGED", id)
	return true
end
function API:Plugin(id) return plugins[id] end

------------------------------------------------------------------------
-- Core wiring: readiness, view events, profile events.
------------------------------------------------------------------------
local function wireView()
	local f = viewFrame()
	if not f or API.viewWired then return end
	API.viewWired = true
	f:HookScript("OnShow", function() gen.main = gen.main + 1; dispatch("VIEW_SHOWN", { viewId = "main", generation = gen.main }) end)
	f:HookScript("OnHide", function() dispatch("VIEW_HIDDEN", { viewId = "main", generation = gen.main }) end)
end
-- A layout pass finished: geometry is valid now; coalesced to one notice per frame.
ns:OnSignal("VIEW_LAYOUT", function(view)
	if not (ns.Window and view == ns.Window.main) then return end
	gen.main = gen.main + 1
	ns:NextFrame("api:view-updated:main", function()
		API:ValidateLease()   -- geometry and identity are current now: a lease on a changed presentation ends before anyone is told
		if viewOpen() then dispatch("VIEW_UPDATED", { viewId = "main", generation = gen.main }) end
	end)
end)
ns:OnSignal("PROFILE_ACTIVATED", function()
	API.profileToken = API.profileToken + 1
	API:DropLeaseOf(nil)   -- a tooltip a plugin still owns goes now; a mouse-owned one is not a lease and stays
	dispatch("PROFILE_CHANGED", { token = API.profileToken })
end)
ns:OnSignal("ADDON_READY", function()
	-- windows exist once every ADDON_READY handler has run; readiness is declared on the next frame, and
	-- activation never happens inline inside RegisterPlugin
	ns:NextFrame("api:ready", function()
		wireView()
		API.ready = true
		activateAll()
		-- the session baseline (loaded and enabled state per declared plugin addon) is taken now, from metadata
		-- only, so a change made later on the game's AddOns screen is seen as pending wherever it was made
		if API:AddOnManagement() then API:RefreshPlugins() end
	end)
end)
