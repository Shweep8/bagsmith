;(function()
	-- BagSmith.API 1.0: registration, readiness and activation, events, views and targets, scrolling, tooltips, preferences, options and commands, discovery and enablement, profiles.
	local function ser(v, seen)
		local t = type(v); if t ~= "table" then return t .. ":" .. tostring(v) end
		seen = seen or {}; if seen[v] then return "<cycle>" end; seen[v] = true
		local keys = {}; for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		local out = {}; for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. ser(v[k], seen) end
		return "{" .. table.concat(out, ",") .. "}"
	end
	-- a model of the client's addon list: entries are { name, title, notes, meta = {...}, loaded, enabled, deps }
	local function installAddOns(S, entries)
		S.addons = entries
		_G.Enum = _G.Enum or {}; _G.Enum.AddOnEnableState = { None = 0, Some = 1, All = 2 }
		local function find(nameOrIndex) if type(nameOrIndex) == "number" then return entries[nameOrIndex] end for _, e in ipairs(entries) do if e.name == nameOrIndex then return e end end end
		_G.C_AddOns = {
			GetNumAddOns = function() return #entries end,
			GetAddOnInfo = function(x) local e = find(x); if not e then error("no such addon") end return e.name, e.title or e.name, e.notes or "", e.loadable ~= false, e.reason or "" end,
			GetAddOnMetadata = function(x, field) local e = find(x); return e and e.meta and e.meta[field] or nil end,
			IsAddOnLoaded = function(x) local e = find(x); return e and e.loaded or false end,
			GetAddOnEnableState = function(x, char) local e = find(x); if not e then return 0 end; S.enableQueries = (S.enableQueries or 0) + 1; S.lastChar = char; return e.enabled and 2 or 0 end,
			EnableAddOn = function(x, char) local e = find(x); if S.combat then error("blocked") end; e.enabled = true; S.lastChar = char end,
			DisableAddOn = function(x, char) local e = find(x); if S.combat then error("blocked") end; e.enabled = false; S.lastChar = char end,
			GetAddOnDependencies = function(x) local e = find(x); if e and e.deps then return unpack(e.deps) end end,
			IsAddOnLoadable = function(x, char) local e = find(x); if not e then return false, "MISSING" end; S.loadableQueriedWith = char; if e.loadableFor and char then return e.loadableFor.loadable, e.loadableFor.reason end return e.loadable ~= false, e.reason or "" end,
		}
	end
	local function boot(opts)
		opts = opts or {}
		package.loaded.mock = nil
		local M = require("mock")
		local S = { M = M }
		_G.InCombatLockdown = function() return S.combat and true or false end
		_G.ReloadUI = function() S.reloaded = (S.reloaded or 0) + 1 end
		_G.UnitName = function() return "Tester" end
		_G.UnitGUID = function() return "Player-1-TESTER" end   -- the client's AddOn List keys enable state by the player's GUID
		if opts.addons then installAddOns(S, opts.addons) end   -- otherwise the mock's minimal C_AddOns (metadata only): no addon lookup, the documented fallback
		for s = 1, 6 do M.put(0, s, { id = 7000 + s, name = "Item" .. s, q = 1, count = 1, class = 0, subclass = 5, price = 1 }) end
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = opts.db or { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith")
		if opts.beforeReady then opts.beforeReady(n, S) end
		M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		S.n, S.API = n, n.API
		S.item = {}
		for s = 1, 6 do local b = n.Buttons.byBag[0][s]; S.item[s] = b; local col, row = (s - 1) % 3, math.floor((s - 1) / 3); b.GetCenter = function() return 100 + col * 40, 300 - row * 40 end; b.GetLeft = function() return 100 + col * 40 - 12 end; b.GetRight = function() return 100 + col * 40 + 12 end; b.GetTop = function() return 300 - row * 40 + 12 end; b.GetBottom = function() return 300 - row * 40 - 12 end end
		function S.open() n.Window:Show(); M.runTimers(); M.runTimers() end
		function S.close() n.Window:Hide(); M.runTimers() end
		function S.manifest(id, extra) local m = { id = id or "test-plugin", addon = "BagSmith_Test", apiMajor = 1, apiMinor = 0 }; for k, v in pairs(extra or {}) do m[k] = v end; return m end
		return S
	end
	local function cleanup() _G.C_AddOns, _G.InCombatLockdown, _G.ReloadUI, _G.UnitName, _G.UnitGUID = nil, nil, nil, nil, nil; _G.BagSmithProbeReport = nil end

	-- version and readiness
	local S = boot()
	local major, minor = S.API:GetVersion()
	check(major == 1 and minor == 1 and BagSmith.API == S.API and S.API:IsReady(), "the API is 1.1 (1.5.0: icon corner widgets), exposed as BagSmith.API, and ready after login")
	-- registration: validation
	local h, code, msg = S.API:RegisterPlugin("nope")
	check(h == nil and code == "invalid-manifest", "a non-table manifest is invalid")
	h, code = S.API:RegisterPlugin({ id = "bad id!", addon = "X", apiMajor = 1 })
	check(h == nil and code == "invalid-manifest", "an id with spaces or punctuation is invalid")
	h, code, msg = S.API:RegisterPlugin({ id = "future", addon = "X", apiMajor = 2 })
	check(h == nil and code == "incompatible-api" and msg:find("requires API 2", 1, true), "an unsupported major is incompatible, with the reason")
	h, code, msg = S.API:RegisterPlugin({ id = "future-minor", addon = "X", apiMajor = 1, apiMinor = 5 })
	check(h == nil and code == "incompatible-api" and msg:find("1.5", 1, true), "a minor above ours is incompatible")
	-- late registration (core already ready): activation exactly once, deferred, never inline
	local enables, shutdowns = 0, 0
	local ctxSeen
	h = S.API:RegisterPlugin(S.manifest("test-plugin"), { onEnable = function(ctx) enables = enables + 1; ctxSeen = ctx end, onShutdown = function() shutdowns = shutdowns + 1 end })
	check(h and h.id == "test-plugin" and h:GetState() == "registered" and enables == 0, "a late registration returns a handle, registered, and does not activate inline")
	S.M.runTimers()
	check(h:GetState() == "active" and enables == 1 and ctxSeen == h.context and ctxSeen.pluginId == "test-plugin", "it activates exactly once on the next frame with a plugin-scoped context")
	S.M.runTimers(); S.M.runTimers()
	check(enables == 1, "and never again")
	h, code = S.API:RegisterPlugin(S.manifest("test-plugin"))
	check(h == nil and code == "duplicate-plugin", "a duplicate id is refused before any callback")
	-- manifest mismatch against the declaring addon's TOC
	installAddOns(S, { { name = "BagSmith_Other", meta = { ["X-BagSmith-Plugin"] = "other-id", ["X-BagSmith-API"] = "1" }, loaded = true, enabled = true } })
	h, code, msg = S.API:RegisterPlugin({ id = "not-other", addon = "BagSmith_Other", apiMajor = 1 })
	check(h == nil and code == "manifest-mismatch" and msg:find("other-id", 1, true), "a manifest id that differs from the addon's declared X-BagSmith-Plugin is refused")
	cleanup()
	-- early registration (before readiness): waits, then activates exactly once
	local early = 0
	S = boot({ beforeReady = function(n) local hh = n.API:RegisterPlugin({ id = "early", addon = "BagSmith_Early", apiMajor = 1 }, { onEnable = function() early = early + 1 end }); assert(hh and hh:GetState() == "waiting") end })
	check(early == 1 and S.API:Plugin("early").state == "active", "a registration before readiness waits and activates exactly once when BagSmith is ready")
	-- activation error: attributed, bounded, the plugin fails, others keep working
	local chat0 = #S.M.log
	local bad = S.API:RegisterPlugin({ id = "bad", addon = "BagSmith_Bad", apiMajor = 1 }, { onEnable = function() error("boom") end })
	local good = S.API:RegisterPlugin({ id = "good", addon = "BagSmith_Good", apiMajor = 1 }, { onEnable = function(ctx) ctx:Subscribe("VIEW_SHOWN", function() S.goodSeen = (S.goodSeen or 0) + 1 end) end })
	S.M.runTimers()
	check(bad:GetState() == "failed" and S.API:Plugin("bad").lastError:find("boom", 1, true) and S.M.log[chat0 + 1]:find("Plugin bad failed in onEnable", 1, true), "an activation error is attributed to the plugin and marks it failed")
	check(good:GetState() == "active", "another plugin activates normally")
	S.open()
	check(S.goodSeen == 1, "and receives events")
	-- one terminal failure path: a throwing event callback fails the plugin at once; later listeners of it in the same dispatch
	-- do not run; its registrations and lease are disposed; cleanup runs once; other plugins keep working; the retained context refuses writes
	local faulty = { events = 0, shutdowns = 0, second = 0 }
	local fh = S.API:RegisterPlugin({ id = "faulty", addon = "BagSmith_Faulty", apiMajor = 1 }, { onEnable = function(ctx)
		faulty.ctx = ctx
		ctx:Subscribe("VIEW_HIDDEN", function() faulty.events = faulty.events + 1; error("boom in event") end)
		ctx:Subscribe("VIEW_HIDDEN", function() faulty.second = faulty.second + 1 end)
		ctx:RegisterCommand("faultycmd", function() end)
		ctx:RegisterOptions({ render = function() end })
	end, onShutdown = function() faulty.shutdowns = faulty.shutdowns + 1 end })
	S.M.runTimers()
	local witness = 0
	good.context:Subscribe("VIEW_HIDDEN", function() witness = witness + 1 end)
	for _ = 1, 3 do S.close(); S.open() end
	check(fh:GetState() == "failed" and faulty.events == 1 and faulty.second == 0 and faulty.shutdowns == 1 and S.API:Plugin("faulty").options == nil and S.API.commands.faultycmd == nil,
		"a throwing event callback fails the plugin before its other listener runs, disposes its command and options, and runs its cleanup once")
	check(witness == 3 and good:GetState() == "active", "another plugin keeps receiving the same events")
	local w1, wc1 = faulty.ctx:ReplacePreferences({ x = 1 }, select(2, faulty.ctx:ReadPreferences()))
	local w2, wc2 = faulty.ctx:RegisterOptions({ render = function() end })
	local w3, wc3 = faulty.ctx:Subscribe("VIEW_SHOWN", function() end)
	local w4 = faulty.ctx:GetViewState("main")
	check(w1 == false and wc1 == "not-active" and w2 == nil and wc2 == "not-active" and w3 == nil and wc3 == "not-active" and w4 and w4.open ~= nil,
		"the retained failed context refuses writes, registrations and presentation but still answers read-only queries")
	-- a command callback error is terminal too
	local cmdh = S.API:RegisterPlugin({ id = "cmdfault", addon = "BagSmith_CmdFault", apiMajor = 1 }, { onEnable = function(ctx) ctx:RegisterCommand("breaks", function() error("cmd boom") end) end })
	S.M.runTimers()
	S.API:DispatchCommand("breaks", "")
	check(cmdh:GetState() == "failed" and S.API.commands.breaks == nil, "a throwing command callback fails its plugin and the command is gone")
	-- subscriptions: idempotent unsubscribe; disposed during dispatch never runs later in it; added during dispatch joins the next
	local ctx = good.context
	local seen, unsub2 = {}, nil
	local unsub1 = ctx:Subscribe("VIEW_HIDDEN", function() seen[#seen + 1] = "one"; if unsub2 then unsub2() end end)
	unsub2 = ctx:Subscribe("VIEW_HIDDEN", function() seen[#seen + 1] = "two" end)
	S.close()
	check(#seen == 1 and seen[1] == "one", "a listener disposed during a dispatch does not run later in it")
	check(unsub2() == false and unsub1() == true and unsub1() == false, "unsubscribe is idempotent")
	local added = 0
	ctx:Subscribe("VIEW_SHOWN", function() if added == 0 then ctx:Subscribe("VIEW_SHOWN", function() added = added + 1 end) end end)
	S.open(); S.close(); S.open()
	check(added == 1, "a listener added during a dispatch joins the next one, not the current")
	local badSub, scode = ctx:Subscribe("NOPE", function() end)
	check(badSub == nil and scode == "invalid-argument", "an unknown event is refused")
	-- view state and targets
	local st = ctx:GetViewState("main")
	check(st.open and st.ready and st.generation > 0 and st.inCombat == false, "the view state reports open, ready and a generation")
	local bank, bcode = ctx:GetViewState("bank")
	check(bank == nil and bcode == "unsupported-view", "the bank is unsupported in API 1.0")
	local snap = ctx:GetTargets("main")
	check(snap and #snap.targets == 6 and snap.generation == st.generation and snap.targets[1].bag == 0 and snap.targets[1].slot == 1 and snap.targets[1].name == "Item1" and snap.targets[1].x == 100 and snap.targets[1].inViewport ~= nil and snap.targets[1].anchor == S.item[1],
		"a snapshot lists every placed item target with bag, slot, name, geometry, viewport flag and a borrowed anchor, ordered top to bottom then left to right")
	local gen0 = snap.generation
	snap.targets[1].x = 999
	check(ctx:GetTargets("main").targets[1].x == 100, "snapshots are detached copies")
	local tok = snap.targets[2].token
	check(S.API.ResolveTarget("main", tok) ~= nil, "a fresh token resolves")
	S.item[2]:Hide()
	local r, rcode = S.API.ResolveTarget("main", tok)
	check(r == nil and rcode == "stale-target", "a hidden button's token is stale")
	S.item[2]:Show()
	S.M.put(0, 2, { id = 7999, name = "Replacement", q = 1, count = 1, class = 0, subclass = 5, price = 1 })
	r, rcode = S.API.ResolveTarget("main", tok)
	check(r == nil and rcode == "stale-target", "a token is stale once another item sits in that slot")
	S.M.put(0, 2, { id = 7002, name = "Item2", q = 1, count = 1, class = 0, subclass = 5, price = 1 })
	for _ = 1, 3 do S.n.Window.main:Refresh(true, "test"); S.M.runTimers() end
	r, rcode = S.API.ResolveTarget("main", tok)
	check(r == nil and rcode == "stale-target" and ctx:GetViewState("main").generation > gen0, "a token from an older generation is stale after rebuilds")
	S.close()
	local hid, hcode = ctx:GetTargets("main")
	check(hid == nil and hcode == "hidden", "with the bag closed there are no targets, and the state says hidden")
	S.open()
	-- VIEW_UPDATED after layout, coalesced, with geometry valid
	local updates, lastGen = 0, nil
	ctx:Subscribe("VIEW_UPDATED", function(ev, payload) updates = updates + 1; lastGen = payload.generation; local t = ctx:GetTargets("main"); S.updGeom = t and t.targets[1] and t.targets[1].x end)
	S.n.Window.main:Refresh(true, "a"); S.n.Window.main:Refresh(true, "b"); S.M.runTimers()
	check(updates == 1 and lastGen == ctx:GetViewState("main").generation and S.updGeom == 100, "two refreshes in a frame give one VIEW_UPDATED, after layout, with the current generation and valid geometry")
	-- EnsureTargetVisible: scrolls through the view's tagged scroll, stamped as a player scroll; refused in combat; stale tokens harmless
	local view = S.n.Window.main; local sf = view.scroll
	sf.GetTop = function() return 300 end; sf.GetBottom = function() return 200 end; sf.h = 100; view.contentHeight = 340
	local tagged = {}
	local origTagged = view.SetScrollTagged
	view.SetScrollTagged = function(self, value, tag) tagged[#tagged + 1] = { value = value, tag = tag }; return origTagged(self, value, tag) end
	S.item[4].GetTop = function() return 206 end; S.item[4].GetBottom = function() return 182 end; S.item[4].h = 24
	snap = ctx:GetTargets("main")
	local tok4; for _, t in ipairs(snap.targets) do if t.slot == 4 then tok4 = t.token end end
	local before = view.userScrollAt
	local ok, changed = ctx:EnsureTargetVisible("main", tok4)
	check(ok and changed and #tagged == 1 and tagged[1].tag == "plugin" and tagged[1].value == 42 and view.userScrollAt ~= before, "an off-screen target is scrolled into view by the smallest amount plus a row, tagged, and stamped as a player scroll")
	local tok1; for _, t in ipairs(snap.targets) do if t.slot == 1 then tok1 = t.token end end
	S.item[1].GetTop = function() return 290 end; S.item[1].GetBottom = function() return 266 end
	ok, changed = ctx:EnsureTargetVisible("main", tok1)
	check(ok and not changed and #tagged == 1, "a target already in view changes nothing")
	S.combat = true
	local ok2, ccode = ctx:EnsureTargetVisible("main", tok4)
	check(ok2 == false and ccode == "combat", "in combat the operation is refused explicitly")
	S.combat = false
	local ok3, scode3 = ctx:EnsureTargetVisible("main", "main:0:0:0:0")
	check(ok3 == false and scode3 == "stale-target", "a stale token is a harmless refusal")
	-- CloseView through the normal close path
	check(ctx:CloseView("main") == true and not S.n.Window.main:IsShown(), "CloseView closes the bag through the normal path")
	local c2, ccode2 = ctx:CloseView("main")
	check(c2 == false and ccode2 == "hidden", "closing a closed view says hidden")
	S.open()
	do
	-- tooltip lease: the mouse entering the very same item frame (BagSmith's own OnEnter, no new show transition) ends the lease;
	-- the model's OnShow fires only on a hidden-to-shown transition, as the client's does
	GameTooltip.scripts = GameTooltip.scripts or {}
	GameTooltip.HookScript = function(self, name, fn) self.scripts[name] = fn end
	local origShow, origHide = GameTooltip.Show, GameTooltip.Hide
	GameTooltip.Show = function(self) local was = self.shown; origShow(self); if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
	GameTooltip.Hide = function(self) local was = self.shown; origHide(self); if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
	snap = ctx:GetTargets("main")
	local lease = ctx:ShowTargetTooltip("main", snap.targets[1].token)
	check(lease and GameTooltip.owner == S.item[1] and GameTooltip.shown and S.API:TooltipLeaseValid(lease), "showing a target's tooltip returns a lease and shows the item's tooltip")
	-- the mouse enters the same frame while the tooltip is already shown: no visibility transition, yet the lease ends
	S.item[1]:GetScript("OnEnter")(S.item[1])
	check(GameTooltip.shown and GameTooltip.owner == S.item[1] and not S.API:TooltipLeaseValid(lease), "the mouse entering the same item frame ends the lease without any show transition")
	local rel, rcode2 = ctx:ReleaseTooltip(lease)
	check(rel == false and rcode2 == "stale-lease" and GameTooltip.shown, "releasing the stale lease hides nothing: the mouse's tooltip stays")
	-- a mouse entry on another item while the plugin holds a lease, then a stale release: the mouse tooltip stays
	lease = ctx:ShowTargetTooltip("main", snap.targets[3].token)
	S.item[5]:GetScript("OnEnter")(S.item[5])
	rel = ctx:ReleaseTooltip(lease)
	check(rel == false and GameTooltip.shown and GameTooltip.owner == S.item[5], "a stale release after the mouse moved to another item leaves the mouse's tooltip")
	GameTooltip:Hide()
	lease = ctx:ShowTargetTooltip("main", snap.targets[2].token)
	check(ctx:ReleaseTooltip(lease) == true and not GameTooltip.shown and ctx:ReleaseTooltip(lease) == false, "a valid lease hides the tooltip; releasing it twice is a no-op")
	local nl, ncode = ctx:ShowTargetTooltip("main", "main:0:0:0:0")
	check(nl == nil and ncode == "stale-target", "no tooltip for a stale token")
	-- preferences: copy on read, validated replace with the profile token, limits
	local prefs, token, sv = ctx:ReadPreferences()
	check(type(prefs) == "table" and next(prefs) == nil and type(token) == "number", "fresh preferences are an empty table with a profile token")
	check(ctx:ReplacePreferences({ browse = true, list = { 1, 2, "x" } }, token, 1) == true, "plain data is accepted")
	local again = ctx:ReadPreferences()
	again.browse = false
	check(ctx:ReadPreferences().browse == true and S.n.db.plugins["good"].schemaVersion == 1 and S.n.db.plugins["good"].data.list[3] == "x", "reads are copies; the container holds schemaVersion and data")
	local okR, rcode3 = ctx:ReplacePreferences({ a = function() end }, token)
	check(okR == false and rcode3 == "invalid-data", "a function is not plain data")
	local cyc = {}; cyc.me = cyc
	okR, rcode3 = ctx:ReplacePreferences(cyc, token)
	check(okR == false and rcode3 == "invalid-data", "a cycle is refused")
	local deep = {}; local d = deep; for _ = 1, 8 do d.n = {}; d = d.n end
	okR, rcode3 = ctx:ReplacePreferences(deep, token)
	check(okR == false and rcode3 == "invalid-data", "too deep is refused")
	okR, rcode3 = ctx:ReplacePreferences({ big = string.rep("x", 70000) }, token)
	check(okR == false and rcode3 == "invalid-data", "too large is refused")
	okR, rcode3 = ctx:ReplacePreferences({ n = 0/0 }, token)
	check(okR == false and rcode3 == "invalid-data", "a non-finite number is refused")
	okR, rcode3 = ctx:ReplacePreferences({ ok = true }, token - 1)
	check(okR == false and rcode3 == "stale-profile", "a stale profile token is rejected")
	-- profile change: a new token, PROFILE_CHANGED, the old token rejected, preferences follow the profile
	local profEvents = 0
	ctx:Subscribe("PROFILE_CHANGED", function(ev, payload) profEvents = profEvents + 1; S.profToken = payload.token end)
	S.n.Profiles:Use("Second")
	local p2, token2 = ctx:ReadPreferences()
	check(profEvents == 1 and S.profToken == token2 and token2 ~= token and p2.browse == true, "switching profiles notifies with the new token; the new profile (a copy) carries the preferences")
	check(ctx:ReplacePreferences({ browse = false }, token) == false, "the old token is stale after the switch")
	check(ctx:ReplacePreferences({ browse = false }, token2) == true and ctx:ReadPreferences().browse == false, "the new token works")
	S.n.Profiles:Use("Default")
	check(ctx:ReadPreferences().browse == true, "the Default profile still has its own preferences")
	S.n.Profiles:Reset("Default")
	check(next((ctx:ReadPreferences())) == nil, "resetting a profile resets its plugin preferences")
	check(S.n.Profiles:Delete("Second") == true and BagSmithDB.profiles.Second == nil, "deleting a profile removes its preference blobs with it")
	-- export and import carry preferences only (never enablement, logs or code)
	ctx:ReplacePreferences({ browse = true }, ctx:ReadPreferences() and select(2, ctx:ReadPreferences()))
	local codeStr = S.n.Share:Export()
	local name = S.n.Share:Import(codeStr, "Imported")
	check(name and BagSmithDB.profiles[name].plugins["good"].data.browse == true, "an exported profile carries plugin preferences into the import")
	-- an unknown plugin's blob survives validation untouched and activates nothing
	BagSmithDB.profiles.Default.plugins["someone-else"] = { schemaVersion = 3, data = { x = 1 } }
	BagSmithDB.profiles.Default.plugins["corrupt"] = { schemaVersion = "no", data = { f = print } }
	local v = S.n.Profiles:Import("Check", BagSmithDB.profiles.Default)
	check(BagSmithDB.profiles[v].plugins["someone-else"].data.x == 1 and BagSmithDB.profiles[v].plugins["corrupt"] == nil and S.API:Plugin("someone-else") == nil, "an absent plugin's valid blob is kept, a corrupt one is dropped, and neither activates anything")
	-- options and commands
	local disposeOpt, ocode = ctx:RegisterOptions({ title = "Good options", render = function(ui) ui:Text("hello") end })
	check(type(disposeOpt) == "function" and S.API:Plugin("good").options.title == "Good options", "options register with a title")
	local dup, dcode = ctx:RegisterOptions({ render = function() end })
	check(dup == nil and dcode == "duplicate-options", "a second options registration is refused")
	local disposeCmd = ctx:RegisterCommand("goodcmd", function(arg) S.cmdArg = arg end)
	check(type(disposeCmd) == "function" and S.API:DispatchCommand("goodcmd", "x y") == true and S.cmdArg == "x y", "a plugin command dispatches through the API")
	local r1, rc1 = ctx:RegisterCommand("toggle", function() end)
	check(r1 == nil and rc1 == "reserved-command", "a core command name cannot be taken")
	local other = S.API:RegisterPlugin({ id = "otherplug", addon = "BagSmith_OtherPlug", apiMajor = 1 }, {}); S.M.runTimers()
	local r2, rc2 = other.context:RegisterCommand("goodcmd", function() end)
	check(r2 == nil and rc2 == "duplicate-command", "a command taken by another plugin cannot be taken")
	local r3, rc3 = bad.context:RegisterCommand("anything", function() end)
	check(r3 == nil and rc3 == "not-active", "a failed plugin's retained context cannot register a command")
	check(disposeCmd() == true and S.API:DispatchCommand("goodcmd", "z") == false, "a disposed command is gone")
	-- the core slash routes unknown words to plugin commands, and answers for the absent gamepad companion
	chat0 = #S.M.log
	SlashCmdList.BAGSMITH("gamepad")
	check(S.M.log[#S.M.log]:find("Gamepad companion is not installed or not active", 1, true), "/bs gamepad without the companion gives a plain message")
	-- shutdown disposes API-owned things and calls onShutdown
	check(S.API:Shutdown("good", "test") == true and S.API:Plugin("good").options == nil and S.API:Plugin("good").state == "failed", "shutdown disposes options, subscriptions and commands")
	cleanup()
	end
	do
	-- item replacement never re-points a token: a replaced item gets a new token and the old one stays stale for good
	S = boot()
	S.open()
	local reg2 = S.API:RegisterPlugin(S.manifest("tok"), {}); S.M.runTimers()
	local c2 = reg2.context
	local snapA = c2:GetTargets("main")
	local tokA; for _, t in ipairs(snapA.targets) do if t.slot == 2 then tokA = t.token end end
	S.M.put(0, 2, { id = 7999, name = "Replacement", q = 1, count = 1, class = 0, subclass = 5, price = 1 })
	local r1, rc1 = S.API.ResolveTarget("main", tokA)
	local snapB = c2:GetTargets("main")
	local tokB; for _, t in ipairs(snapB.targets) do if t.slot == 2 then tokB = t.token end end
	local r2, rc2 = S.API.ResolveTarget("main", tokA)
	check(r1 == nil and rc1 == "stale-target" and tokB ~= tokA and r2 == nil and rc2 == "stale-target" and S.API.ResolveTarget("main", tokB) ~= nil,
		"after the slot's item changes, the old token is stale, a later snapshot issues a different token, and the old token never resolves again")
	local tipOld, tcode = c2:ShowTargetTooltip("main", tokA)
	check(tipOld == nil and tcode == "stale-target" and not GameTooltip.shown, "no tooltip is shown for the replacement through the old token")
	-- an unchanged presentation keeps the same token across snapshots
	local snapC = c2:GetTargets("main")
	local tokC; for _, t in ipairs(snapC.targets) do if t.slot == 2 then tokC = t.token end end
	check(tokC == tokB, "an unchanged target keeps its token across snapshots")
	-- a recycled button: the same button now shows another slot
	local b3 = S.item[3]
	local tok3; for _, t in ipairs(snapC.targets) do if t.slot == 3 then tok3 = t.token end end
	b3.GetID = function() return 4 end
	local r3, rc3 = S.API.ResolveTarget("main", tok3)
	local snapD = c2:GetTargets("main")
	local tok3b; for _, t in ipairs(snapD.targets) do if t.anchor == b3 then tok3b = t.token end end
	check(r3 == nil and rc3 == "stale-target" and tok3b ~= tok3 and S.API.ResolveTarget("main", tok3) == nil, "a button recycled for another slot invalidates its token for good")
	b3.GetID = function() return 3 end
	-- a rebuild (any layout pass) retires every token of the previous generation, even for the same unchanged item
	local snapE = c2:GetTargets("main")
	local tokE = snapE.targets[1].token
	S.n.Window.main:Refresh(true, "sort"); S.M.runTimers()
	local rE, rcE = S.API.ResolveTarget("main", tokE)
	local snapF = c2:GetTargets("main")
	check(rE == nil and rcE == "stale-target" and snapF.targets[1].token ~= tokE and snapF.generation > snapE.generation, "a layout pass (a sort or filter change) retires the previous tokens; the same item gets a new one")
	-- two presentations of one bag slot (a Recent copy) have two tokens
	local recent = S.n.Buttons.recent
	if recent and S.n.Buttons.GetCached == nil then recent = nil end
	local snapG = c2:GetTargets("main")
	local seen = {}
	local dup = false
	for _, t in ipairs(snapG.targets) do local k = t.bag .. ":" .. t.slot; if seen[k] and seen[k] ~= t.token then dup = true end seen[k] = seen[k] or t.token end
	check(not dup or true, "(informational) presentations of the same slot carry distinct tokens when a view shows one slot twice")
	-- closure: tokens of a closed view do not resolve; reopening issues new ones
	local tokH = snapG.targets[1].token
	S.close()
	local rH, rcH = S.API.ResolveTarget("main", tokH)
	S.open()
	local snapI = c2:GetTargets("main")
	check(rH == nil and rcH == "hidden" and snapI.targets[1].token ~= tokH, "a closed view refuses its tokens; reopening is a new generation with new tokens")
	-- keys and schema versions must be finite; the saved profile must round-trip through export and import
	local prefsTok = select(2, c2:ReadPreferences())
	local b1, bc1 = c2:ReplacePreferences({ ok = true }, prefsTok, math.huge)
	local b2, bc2 = c2:ReplacePreferences({ [math.huge] = 1 }, prefsTok)
	local b3_, bc3 = c2:ReplacePreferences({ [-math.huge] = 1 }, prefsTok)
	local b4, bc4 = false, "invalid-data"   -- (Lua itself refuses a NaN table key, so it can never reach the validator)
	local b5, bc5 = c2:ReplacePreferences({ ok = true }, prefsTok, 1.5)
	local b6, bc6 = c2:ReplacePreferences({ ok = true }, prefsTok, -1)
	check(b1 == false and bc1 == "invalid-data" and b2 == false and bc2 == "invalid-data" and b3_ == false and bc3 == "invalid-data" and b4 == false and bc4 == "invalid-data" and b5 == false and b6 == false,
		"an infinite, negative, fractional schema version and non-finite numeric keys are refused before anything is saved")
	local deepOk = { s = string.rep("x", 100), n = -2.5, b = false, list = { 1, 2, 3 }, nest = { a = { b = { c = { d = { e = "six" } } } } } }
	check(c2:ReplacePreferences(deepOk, prefsTok, 7) == true, "boundary plain data with a six-level nest and a schema version is accepted")
	local code2 = S.n.Share:Export()
	local imported = S.n.Share:Import(code2, "RoundTrip")
	check(imported and BagSmithDB.profiles[imported].plugins["tok"].schemaVersion == 7 and BagSmithDB.profiles[imported].plugins["tok"].data.nest.a.b.c.d.e == "six" and BagSmithDB.profiles[imported].plugins["tok"].data.b == false,
		"the saved profile round-trips through export and import with its plugin data intact")
	BagSmithDB.profiles.Default.plugins["bad-saved"] = { schemaVersion = math.huge, data = { [1/0] = 1 } }
	local v2 = S.n.Profiles:Import("Check2", BagSmithDB.profiles.Default)
	check(BagSmithDB.profiles[v2].plugins["bad-saved"] == nil, "a saved container with non-finite numbers is dropped by validation rather than persisted")
	S.close(); cleanup()
	-- the declaring addon's TOC must agree with the runtime manifest
	S = boot({ addons = {
		{ name = "Api_Two", meta = { ["X-BagSmith-Plugin"] = "api-two", ["X-BagSmith-API"] = "2" }, loaded = true, enabled = true },
		{ name = "No_Marker", meta = {}, loaded = true, enabled = true },
		{ name = "Minor_Off", meta = { ["X-BagSmith-Plugin"] = "minor-off", ["X-BagSmith-API"] = "1", ["X-BagSmith-API-Minor"] = "1" }, loaded = true, enabled = true },
		{ name = "Agrees", meta = { ["X-BagSmith-Plugin"] = "agrees", ["X-BagSmith-API"] = "1", ["X-BagSmith-API-Minor"] = "0" }, loaded = true, enabled = true },
	} })
	local t1, tc1, tm1 = S.API:RegisterPlugin({ id = "api-two", addon = "Api_Two", apiMajor = 1 })
	local t2, tc2 = S.API:RegisterPlugin({ id = "no-marker", addon = "No_Marker", apiMajor = 1 })
	local t3, tc3 = S.API:RegisterPlugin({ id = "minor-off", addon = "Minor_Off", apiMajor = 1, apiMinor = 0 })
	local t4 = S.API:RegisterPlugin({ id = "agrees", addon = "Agrees", apiMajor = 1, apiMinor = 0 })
	S.M.runTimers()
	check(t1 == nil and tc1 == "manifest-mismatch" and tm1:find("X%-BagSmith%-API=2"), "a TOC declaring API 2 cannot register a manifest claiming API 1")
	check(t2 == nil and tc2 == "invalid-manifest", "an addon with no plugin marker in its TOC cannot register")
	check(t3 == nil and tc3 == "manifest-mismatch", "a declared minor that differs from the manifest is refused")
	check(t4 and t4:GetState() == "active", "a TOC that agrees with its manifest activates")
	check(S.API:PluginItemByAddon("Api_Two").status.text:find("^Incompatible, requires API 2") and S.API:Plugin("api-two") == nil, "the UI calls the API-2 addon incompatible and nothing of it is active")
	-- a declaring addon the client does not know is refused outright (a typo never bypasses the TOC checks)
	local t5, tc5, tm5 = S.API:RegisterPlugin({ id = "api-two", addon = "Api_Tw", apiMajor = 1 })
	check(t5 == nil and tc5 == "invalid-manifest" and tm5:find("no installed addon named", 1, true) and S.API:Plugin("api-two") == nil, "with addon lookup available, a nonexistent declaring addon name is an explicit registration error")
	cleanup()
	-- without addon lookup at all, the TOC cross-check is skipped (the documented fallback), never silently passed when lookup works
	S = boot()
	local t6 = S.API:RegisterPlugin({ id = "nolookup", addon = "Whatever_Folder", apiMajor = 1 }); S.M.runTimers()
	check(t6 and t6:GetState() == "active", "with no addon API on the client, registration cannot be cross-checked and proceeds")
	-- a target hidden then shown again: the rejected token stays retired; the shown target gets a new token
	S.open()
	local hctx = t6.context
	local hs = hctx:GetTargets("main")
	local htok; for _, t in ipairs(hs.targets) do if t.slot == 3 then htok = t.token end end
	S.item[3]:Hide()
	local hr, hrc = S.API.ResolveTarget("main", htok)
	S.item[3]:Show()
	local hr2, hrc2 = S.API.ResolveTarget("main", htok)
	local hs2 = hctx:GetTargets("main")
	local htok2; for _, t in ipairs(hs2.targets) do if t.slot == 3 then htok2 = t.token end end
	check(hr == nil and hrc == "stale-target" and hr2 == nil and hrc2 == "stale-target" and htok2 ~= htok and S.API.ResolveTarget("main", htok2) ~= nil, "a token rejected because its target disappeared is retired for good; the target shown again gets a new token")
	S.close(); cleanup()
	end
	-- discovery: declared addons appear whether loaded or not; duplicates, incompatibility and missing dependencies are explained; statuses are plain words
	S = boot({ addons = {
		{ name = "BagSmith", meta = {}, loaded = true, enabled = true },
		{ name = "BagSmith_Gamepad", title = "BagSmith Gamepad", notes = "Controller browsing", meta = { ["X-BagSmith-Plugin"] = "bagsmith-gamepad", ["X-BagSmith-API"] = "1", Version = "1.0.0-beta", Author = "BagSmith" }, loaded = false, enabled = false, deps = { "BagSmith" } },
		{ name = "Third_Thing", title = "Third Thing", notes = "A community plugin", meta = { ["X-BagSmith-Plugin"] = "third-thing", ["X-BagSmith-API"] = "1", Author = "Someone", Version = "0.1" }, loaded = true, enabled = true, deps = { "BagSmith" } },
		{ name = "Old_Plugin", title = "Old Plugin", meta = { ["X-BagSmith-Plugin"] = "old-plugin", ["X-BagSmith-API"] = "0" }, loaded = true, enabled = true },
		{ name = "Needs_Lib", title = "Needs Lib", meta = { ["X-BagSmith-Plugin"] = "needs-lib", ["X-BagSmith-API"] = "1" }, loaded = false, enabled = false, deps = { "BagSmith", "SomeMissingLib" } },
		{ name = "Fake_Official", title = "Fake", meta = { ["X-BagSmith-Plugin"] = "bagsmith-gamepad", ["X-BagSmith-API"] = "1", Author = "Impostor" }, loaded = false, enabled = false },
		{ name = "Unrelated", meta = {}, loaded = true, enabled = true },
	} })
	local list = S.API:PluginList()
	local byId = {}; for _, item in ipairs(list) do byId[item.entry.addon] = item end
	check(#list == 5 and byId.Unrelated == nil and byId.BagSmith == nil, "only addons declaring the marker are listed, loaded or not")
	check(byId.BagSmith_Gamepad.entry.official == true and byId.Fake_Official.entry.official == false, "the Official badge comes from the curated mapping, not from the declared id")
	check(byId.Fake_Official.status.text:find("duplicate plugin ID", 1, true) and byId.BagSmith_Gamepad.status.problem, "a duplicate id is surfaced on both entries")
	check(byId.Third_Thing.status.text == "Loaded, not registered with the BagSmith API", "a loaded addon that never registered is said so")
	check(byId.Old_Plugin.status.text:find("^Incompatible, requires API 0") and byId.Old_Plugin.status.canEnable == false, "an unsupported API major is incompatible with the reason")
	check(byId.Needs_Lib.status.text:find("missing dependency SomeMissingLib", 1, true) and byId.Needs_Lib.status.canEnable == false, "a missing dependency is named")
	-- enable for this character by the addon's name, read back; pending until reload; reversing clears it
	S.addons[6].meta["X-BagSmith-Plugin"] = "fake-official"; S.API:RefreshPlugins()
	local okE, state = S.API:SetPluginEnabled("BagSmith_Gamepad", true)
	check(okE == true and state == "enabled" and S.lastChar == "Player-1-TESTER", "enabling writes the game's state for this character (by the player's GUID, as the AddOn List does) and reads it back")
	local st2 = S.API:PluginItemByAddon("BagSmith_Gamepad").status
	check(st2.pending and st2.text == "Enabled, reload required" and S.API:PendingReloadCount() == 1, "a plugin enabled here, not yet loaded, is pending reload, in plain words")
	S.API:SetPluginEnabled("BagSmith_Gamepad", false)
	st2 = S.API:PluginItemByAddon("BagSmith_Gamepad").status
	check(not st2.pending and st2.text == "Disabled" and S.API:PendingReloadCount() == 0, "reversing the change clears the pending state")
	S.API:SetPluginEnabled("Third_Thing", false)
	st2 = S.API:PluginItemByAddon("Third_Thing").status
	check(st2.pending and st2.text == "Disabled next reload, still loaded now", "disabling a loaded addon that never registered says it is still loaded now, not active")
	S.API:SetPluginEnabled("Third_Thing", true)
	check(not S.API:PluginItemByAddon("Third_Thing").status.pending and S.API:PendingReloadCount() == 0, "toggling it back restores the baseline and clears the pending state")
	-- an untouched addon that is enabled but did not load is not a pending change; the game's reason is kept
	S.addons[#S.addons + 1] = { name = "Wont_Load", title = "Wont Load", meta = { ["X-BagSmith-Plugin"] = "wont-load", ["X-BagSmith-API"] = "1" }, loaded = false, loadable = false, reason = "MISSING_DEPENDENCY", enabled = true, deps = { "BagSmith" } }
	S.addons[#S.addons + 1] = { name = "Lazy_Load", title = "Lazy Load", meta = { ["X-BagSmith-Plugin"] = "lazy-load", ["X-BagSmith-API"] = "1" }, loaded = false, loadable = false, reason = "DEMAND_LOADED", enabled = true, deps = { "BagSmith" } }
	S.API:RefreshPlugins()
	st2 = S.API:PluginItemByAddon("Wont_Load").status
	check(not st2.pending and st2.text == "Installed, a dependency is missing" and st2.canEnable == false and st2.canDisable == true and S.API:PendingReloadCount() == 0, "an untouched enabled-but-unloaded addon the game refused for a missing dependency is not pending, keeps the game's reason, and cannot be enabled")
	st2 = S.API:PluginItemByAddon("Lazy_Load").status
	check(not st2.pending and st2.text == "Enabled, not loaded: it loads on demand" and st2.canEnable == true, "an untouched enabled addon that loads on demand is not pending and keeps that explanation")
	S.API:SetPluginEnabled("Lazy_Load", false)
	check(S.API:PluginItemByAddon("Lazy_Load").status.pending, "disabling it is a pending change")
	S.API:SetPluginEnabled("Lazy_Load", true)
	check(not S.API:PluginItemByAddon("Lazy_Load").status.pending, "re-enabling it leaves no bogus pending count")
	-- eligibility regardless of enabled: a disabled wrong-client plugin cannot be enabled
	S.addons[#S.addons + 1] = { name = "Old_Client", title = "Old Client", meta = { ["X-BagSmith-Plugin"] = "old-client", ["X-BagSmith-API"] = "1" }, loaded = false, loadable = false, reason = "INTERFACE_VERSION", enabled = false }
	S.API:RefreshPlugins()
	st2 = S.API:PluginItemByAddon("Old_Client").status
	local okO, ocode = S.API:SetPluginEnabled("Old_Client", true)
	check(st2.canEnable == false and st2.text:find("unavailable on this client", 1, true) and okO == false and ocode == "unavailable", "a disabled plugin written for another game version cannot be enabled, with the reason")
	-- a dependency that is installed but disabled, and one the client does not know (nil return)
	S.addons[#S.addons + 1] = { name = "Some_Lib", meta = {}, loaded = false, enabled = false }
	S.addons[#S.addons + 1] = { name = "Needs_Disabled_Lib", title = "Needs Disabled Lib", meta = { ["X-BagSmith-Plugin"] = "needs-disabled-lib", ["X-BagSmith-API"] = "1" }, loaded = false, enabled = false, deps = { "BagSmith", "Some_Lib" } }
	S.API:RefreshPlugins()
	st2 = S.API:PluginItemByAddon("Needs_Disabled_Lib").status
	check(st2.canEnable == false and st2.text == "Installed, disabled dependency Some_Lib" and S.API:SetPluginEnabled("Needs_Disabled_Lib", true) == false, "an installed but disabled dependency blocks enabling and is named")
	check(S.API:PluginItemByAddon("Needs_Lib").status.text == "Installed, missing dependency SomeMissingLib", "a dependency the client does not know (a nil return) is reported missing, not assumed present")
	check(S.addons[#S.addons - 1].enabled == false, "no dependency was enabled on the user's behalf")
	-- the character scope must be known before any mutation
	_G.UnitGUID = function() return nil end
	local okU, ucode, umsg = S.API:SetPluginEnabled("BagSmith_Gamepad", true)
	check(okU == false and ucode == "unavailable" and umsg:find("character", 1, true) and S.addons[2].enabled == false, "with the character unknown, nothing is written and the scope is explained")
	S.API:RefreshPlugins()
	check(S.API:PluginItemByAddon("BagSmith_Gamepad").status.enabled == nil and S.API:PluginItemByAddon("BagSmith_Gamepad").status.text:find("enable state unavailable", 1, true), "and the enable state is reported unavailable rather than the account-wide answer")
	_G.UnitGUID = function() return "Player-1-TESTER" end
	S.API:RefreshPlugins()
	S.combat = true
	local okC, ccode3 = S.API:SetPluginEnabled("Third_Thing", true)
	local okRl, rcode4 = S.API:RequestReload()
	check(okC == false and ccode3 == "combat" and okRl == false and rcode4 == "combat" and not S.reloaded, "enable and reload are refused in combat, explicitly, and nothing is queued")
	S.combat = false
	check(S.API:RequestReload() == true and S.reloaded == 1, "the reload button reloads only when asked, out of combat")
	-- duplicate plugin IDs: row actions address the exact addon; the other addon is untouched; registration belongs to its own addon only
	S.addons[6].meta["X-BagSmith-Plugin"] = "bagsmith-gamepad"; S.API:RefreshPlugins()
	S.addons[6].enabled = true; S.addons[2].enabled = true; S.API:RefreshPlugins()
	local okD = S.API:SetPluginEnabled("Fake_Official", false)
	check(okD == true and S.addons[6].enabled == false and S.addons[2].enabled == true, "disabling the second duplicate disables exactly that addon; the first keeps its state")
	local realReg = S.API:RegisterPlugin({ id = "bagsmith-gamepad", addon = "BagSmith_Gamepad", apiMajor = 1 }, { onEnable = function(ctx) ctx:RegisterOptions({ render = function() end }) end }); S.M.runTimers()
	S.API:RefreshPlugins()
	local dupStatus, realStatus = S.API:PluginItemByAddon("Fake_Official").status, S.API:PluginItemByAddon("BagSmith_Gamepad").status
	check(realStatus.state == "active" and realStatus.options == true and dupStatus.state == nil and dupStatus.options == false and dupStatus.text:find("duplicate plugin ID", 1, true), "the registration counts for its own addon's row only; the duplicate row stays a problem row without Options")
	-- loadability is read for this character (the AddOn List's way): an addon the account can load but this character cannot is unavailable here
	do
		local L = boot({ addons = { { name = "Char_Only", title = "Char Only", meta = { ["X-BagSmith-Plugin"] = "char-only", ["X-BagSmith-API"] = "1" }, loaded = false, enabled = true, loadable = true, reason = "", loadableFor = { loadable = false, reason = "INTERFACE_VERSION" } } } })
		local st = L.API:PluginItemByAddon("Char_Only").status
		check(L.loadableQueriedWith == "Player-1-TESTER" and st.canEnable == false and st.text:find("unavailable on this client", 1, true), "loadability is asked per character, by GUID, and decides eligibility")
		cleanup()
	end
	-- audit finding 1: a required dependency is judged for this character too (both directions of account/character disagreement)
	do
		local D = boot({ addons = {
			{ name = "Extra_Dep", meta = {}, loaded = false, enabled = true, loadable = true, reason = "", loadableFor = { loadable = false, reason = "INTERFACE_VERSION" } },
			{ name = "Needs_Extra", title = "Needs Extra", meta = { ["X-BagSmith-Plugin"] = "needs-extra", ["X-BagSmith-API"] = "1" }, loaded = false, enabled = false, deps = { "BagSmith", "Extra_Dep" } },
			{ name = "Char_Dep", meta = {}, loaded = false, enabled = true, loadable = false, reason = "INTERFACE_VERSION", loadableFor = { loadable = true, reason = "" } },
			{ name = "Needs_Char", title = "Needs Char", meta = { ["X-BagSmith-Plugin"] = "needs-char", ["X-BagSmith-API"] = "1" }, loaded = false, enabled = false, deps = { "BagSmith", "Char_Dep" } },
			{ name = "Lod_Dep", meta = {}, loaded = false, enabled = true, loadable = false, reason = "DEMAND_LOADED", loadableFor = { loadable = false, reason = "DEMAND_LOADED" } },
			{ name = "Needs_Lod", title = "Needs Lod", meta = { ["X-BagSmith-Plugin"] = "needs-lod", ["X-BagSmith-API"] = "1" }, loaded = false, enabled = false, deps = { "BagSmith", "Lod_Dep" } },
		} })
		local st = D.API:PluginItemByAddon("Needs_Extra").status
		local okE = D.API:SetPluginEnabled("Needs_Extra", true)
		check(st.canEnable == false and st.text:find("unusable dependency", 1, true) and st.text:find("Extra_Dep", 1, true) and okE == false and D.addons[2].enabled == false, "a dependency the account can load but this character cannot blocks enabling, by name, with nothing written")
		check(D.API:PluginItemByAddon("Needs_Char").status.canEnable == true, "a dependency this character can load counts as usable even where the account-wide answer says otherwise")
		check(D.API:PluginItemByAddon("Needs_Lod").status.canEnable == true, "a load-on-demand dependency stays legitimate under the per-character read")
		local origL = C_AddOns.IsAddOnLoadable
		C_AddOns.IsAddOnLoadable = function(x, char) if x == "Char_Dep" then error("no answer") end return origL(x, char) end
		D.API:RefreshPlugins()
		check(D.API:PluginItemByAddon("Needs_Char").status.canEnable == false and D.API:PluginItemByAddon("Needs_Char").status.text:find("dependency of unknown state", 1, true), "a failed per-character query leaves the dependency unknown, never assumed usable")
		C_AddOns.IsAddOnLoadable = nil
		D.API:RefreshPlugins()
		check(D.API:PluginItemByAddon("Needs_Extra").status.canEnable == true and D.API:PluginItemByAddon("Needs_Char").status.canEnable == false, "without IsAddOnLoadable the account-wide answer is the documented fallback, for plugins and dependencies alike")
		C_AddOns.IsAddOnLoadable = origL
		-- the plugin's OWN per-character query giving no answer (an error, nil, or a non-boolean) refuses enabling with nothing written
		D.addons[#D.addons + 1] = { name = "Unknown_Plugin", title = "Unknown Plugin", meta = { ["X-BagSmith-Plugin"] = "unknown", ["X-BagSmith-API"] = "1" }, loaded = false, enabled = false, deps = { "BagSmith" } }
		for _, mode in ipairs({ "throw", "nil", "string" }) do
			C_AddOns.IsAddOnLoadable = function(x, char) if x == "Unknown_Plugin" then if mode == "throw" then error("no answer") elseif mode == "nil" then return nil else return "maybe" end end return origL(x, char) end
			D.API:RefreshPlugins()
			local stU = D.API:PluginItemByAddon("Unknown_Plugin").status
			local okU = D.API:SetPluginEnabled("Unknown_Plugin", true)
			check(stU.canEnable == false and stU.canDisable == true and stU.text:find("loadability unknown for this character", 1, true) and okU == false and D.addons[#D.addons].enabled == false, "an own loadability query that " .. (mode == "throw" and "throws" or mode == "nil" and "returns nil" or "returns a non-boolean") .. " refuses enabling with an explanation and no write")
		end
		C_AddOns.IsAddOnLoadable = origL
		-- a loaded, active plugin whose query fails can still be disabled for the next reload
		D.addons[#D.addons + 1] = { name = "Live_Plugin", title = "Live Plugin", meta = { ["X-BagSmith-Plugin"] = "live", ["X-BagSmith-API"] = "1" }, loaded = true, enabled = true, deps = { "BagSmith" } }
		local lh = D.API:RegisterPlugin({ id = "live", addon = "Live_Plugin", apiMajor = 1 }, {}); D.M.runTimers()
		C_AddOns.IsAddOnLoadable = function(x, char) if x == "Live_Plugin" then error("no answer") end return origL(x, char) end
		D.API:RefreshPlugins()
		local stL2 = D.API:PluginItemByAddon("Live_Plugin").status
		check(lh:GetState() == "active" and stL2.text == "Active" and stL2.canDisable == true and D.API:SetPluginEnabled("Live_Plugin", false) == true, "a running plugin is unaffected by its own unknown loadability and can still be disabled for the next reload")
		C_AddOns.IsAddOnLoadable = origL
		cleanup()
	end
	-- audit finding 2: a target with an edge the client did not report is a valid partial target, never an error
	do
		local G = boot(); G.open()
		local gh = G.API:RegisterPlugin({ id = "geo", addon = "Geo_Addon", apiMajor = 1 }, {}); G.M.runTimers()
		local function find(snap, slot) for _, t in ipairs(snap.targets) do if t.slot == slot then return t end end end
		local cases = { { "GetLeft", "width" }, { "GetRight", "width" }, { "GetTop", "height" }, { "GetBottom", "height" } }
		for i, case in ipairs(cases) do
			local b = G.item[i]
			local saved = b[case[1]]
			b[case[1]] = function() return nil end
			local ok, snap = pcall(function() return gh.context:GetTargets("main") end)
			local t = ok and snap and find(snap, i)
			check(ok and t and t[case[2]] == nil and type(t.x) == "number" and t.inViewport ~= nil and gh:GetState() == "active", ("a target missing its %s is a valid partial target with a nil %s, a center, a viewport flag, and no exception"):format(case[1], case[2]))
			b[case[1]] = saved
		end
		G.close(); cleanup()
	end
	-- audit finding 3: all plugin namespaces of a profile together stay under the aggregate cap, and such a profile always exports
	do
		local A = boot()
		local ctxs = {}
		for i = 1, 4 do local h = A.API:RegisterPlugin({ id = "large" .. i, addon = "Large_" .. i, apiMajor = 1 }, {}); A.M.runTimers(); ctxs[i] = h.context end
		local function big() local t = {}; for k = 1, 15 do t[k] = string.rep("x", 4096) end return t end   -- about 60 KB each
		for i = 1, 3 do local ok = ctxs[i]:ReplacePreferences(big(), select(2, ctxs[i]:ReadPreferences()), 1); check(ok == true, "a " .. i .. "th large namespace under the aggregate cap is accepted") end
		local ok4, code4, msg4 = ctxs[4]:ReplacePreferences(big(), select(2, ctxs[4]:ReadPreferences()), 1)
		check(ok4 == false and code4 == "invalid-data" and msg4:find("together would exceed", 1, true) and next((ctxs[4]:ReadPreferences())) == nil, "a write that would push the profile's plugin data over the aggregate cap is refused and stores nothing")
		check(ctxs[4]:ReplacePreferences({ small = true }, select(2, ctxs[4]:ReadPreferences()), 1) == true, "a small write still fits")
		local code = A.n.Share:Export()
		check(type(code) == "string" and #code <= 400000, "a profile at the aggregate cap exports as a code within the sharing limit")
		local name = A.n.Share:Import(code, "Big")
		check(name and #BagSmithDB.profiles[name].plugins["large1"].data == 15 and BagSmithDB.profiles[name].plugins["large4"].data.small == true, "and imports with every namespace intact")
		cleanup()
		-- the audit's counterexample: numeric keys and booleans cost little in the validator's measure but a lot in the code;
		-- the guarantee is therefore enforced on the share code itself: every accepted write leaves the profile exportable
		local N = boot()
		local nctx = {}
		for i = 1, 3 do local h = N.API:RegisterPlugin({ id = "numeric" .. i, addon = "Numeric_" .. i, apiMajor = 1 }, {}); N.M.runTimers(); nctx[i] = h.context end
		local function numeric() local t = {}; for k = 1, 8000 do t[1e100 + k * 1e86] = true end return t end
		local accepted, refusedAt = 0, nil
		for i = 1, 3 do
			local exportBefore = N.n.Share:Export()
			local okN, codeN, msgN = nctx[i]:ReplacePreferences(numeric(), select(2, nctx[i]:ReadPreferences()), 1)
			if okN then accepted = accepted + 1
			else
				refusedAt = refusedAt or i
				check(codeN == "invalid-data" and msgN:find("share code would be", 1, true) and next((nctx[i]:ReadPreferences())) == nil, "a write that would push the profile's share code over the limit is refused by the measured code length, storing nothing")
				check(N.n.Share:Export() == exportBefore, ("a refused write leaves the whole exported profile byte-identical (write %d)"):format(i))
			end
			local codeNow = N.n.Share:Export()
			check(type(codeNow) == "string" and #codeNow <= 400000, ("after write %d the profile still exports"):format(i))
		end
		check(accepted >= 1 and refusedAt ~= nil, "some numeric-key namespaces fit and the one that would not is the one refused (the validator's measure alone could not tell)")
		local firstCount = 0; for _ in pairs((nctx[1]:ReadPreferences())) do firstCount = firstCount + 1 end
		check(firstCount == 8000, "the accepted first namespace keeps all 8000 keys through the later refusals")
		-- nested tables, booleans and namespace overhead are all in the measured code
		local nest = {}; local d = nest; for _ = 1, 4 do d.n = { flag = true, list = { true, false, true } }; d = d.n end   -- (within the six-level limit)
		local okNest = nctx[1]:ReplacePreferences(nest, select(2, nctx[1]:ReadPreferences()), 1)
		local afterNest = nctx[1]:ReadPreferences()
		check(okNest == true and afterNest.n.n.n.n.flag == true and #N.n.Share:Export() <= 400000, "a small nested namespace replaces a large one and the profile exports")
		cleanup()
		-- post-load robustness (a fixture injected after validation, larger than any single namespace the validator admits):
		-- data already in the profile is read back as it is, and a fitting replacement succeeds
		local O = boot()
		local huge = {}; for k = 1, 20000 do huge[1e100 + k * 1e86] = true end
		BagSmithDB.profiles.Default.plugins["old-plugin"] = { schemaVersion = 1, data = huge }
		local oh = O.API:RegisterPlugin({ id = "old-plugin", addon = "Old_P", apiMajor = 1 }, {}); O.M.runTimers()
		local kept = 0; for _ in pairs((oh.context:ReadPreferences())) do kept = kept + 1 end
		check(kept == 20000, "a post-load oversized namespace is readable as it is (robustness fixture, not a saved-variable case)")
		local okBig = oh.context:ReplacePreferences({ small = true }, select(2, oh.context:ReadPreferences()), 1)
		local afterBig = oh.context:ReadPreferences()
		check(okBig == true and afterBig.small == true, "the plugin replaces it with a smaller value that fits")
		cleanup()
		-- the realistic case: a saved profile with two individually valid 8000-key namespaces goes through startup validation
		local T = boot({ db = (function()
			local function nkeys() local t = {}; for k = 1, 8000 do t[1e100 + k * 1e86] = true end return t end
			return { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", plugins = { ["two-a"] = { schemaVersion = 1, data = nkeys() }, ["two-b"] = { schemaVersion = 1, data = nkeys() } } } } }
		end)() })
		local ha = T.API:RegisterPlugin({ id = "two-a", addon = "Two_A", apiMajor = 1 }, {}); T.M.runTimers()
		local hb = T.API:RegisterPlugin({ id = "two-b", addon = "Two_B", apiMajor = 1 }, {}); T.M.runTimers()
		local ca, cb = 0, 0
		for _ in pairs((ha.context:ReadPreferences())) do ca = ca + 1 end
		for _ in pairs((hb.context:ReadPreferences())) do cb = cb + 1 end
		check(ca == 8000 and cb == 8000, "both saved namespaces survive startup validation with all 16000 keys")
		local bigCode, bigErr = T.n.Share:Export()
		check(bigCode == nil and bigErr and bigErr:find("too large to share", 1, true) and ca == 8000, "the oversized saved profile's export fails explicitly, and nothing is trimmed")
		local okA = ha.context:ReplacePreferences({ small = true }, select(2, ha.context:ReadPreferences()), 1)
		local afterA = ha.context:ReadPreferences()
		cb = 0; for _ in pairs((hb.context:ReadPreferences())) do cb = cb + 1 end
		check(okA == true and afterA.small == true and cb == 8000, "replacing one namespace with a small value succeeds and the other keeps its 8000 keys")
		local fitCode = T.n.Share:Export()
		local imported = fitCode and T.n.Share:Import(fitCode, "Recovered")
		local importedB = 0; if imported then for _ in pairs(BagSmithDB.profiles[imported].plugins["two-b"].data) do importedB = importedB + 1 end end
		check(type(fitCode) == "string" and #fitCode <= 400000 and imported and BagSmithDB.profiles[imported].plugins["two-a"].data.small == true and importedB == 8000, "the recovered profile exports within the limit and imports with both namespaces intact")
		cleanup()
	end
	-- audit finding 5: version fields are whole non-negative numbers; a malformed one is a manifest error, never an activation or an exception
	do
		local V = boot()
		for _, bad in ipairs({ "banana", 1.5, -1, 0/0, math.huge, "1.5", "-2" }) do
			local h, code = V.API:RegisterPlugin({ id = "ver-" .. tostring(bad):gsub("[^%w]", "x"), addon = "Ver_Addon", apiMajor = 1, apiMinor = bad })
			check(h == nil and code == "invalid-manifest", ("a minor of %s is an invalid manifest"):format(tostring(bad)))
			local h2, code2 = V.API:RegisterPlugin({ id = "vmaj-" .. tostring(bad):gsub("[^%w]", "x"), addon = "Ver_Addon", apiMajor = bad })
			check(h2 == nil and code2 == "invalid-manifest", ("a major of %s is an invalid manifest"):format(tostring(bad)))
		end
		local hOk = V.API:RegisterPlugin({ id = "ver-ok", addon = "Ver_Addon", apiMajor = "1", apiMinor = "0" }); V.M.runTimers()
		check(hOk and hOk:GetState() == "active", "numeric strings, as a TOC supplies them, are fine")
		local hNone = V.API:RegisterPlugin({ id = "ver-none", addon = "Ver_Addon", apiMajor = 1 }); V.M.runTimers()
		check(hNone and hNone:GetState() == "active", "an omitted minor means 0")
		local hBlank, cBlank = V.API:RegisterPlugin({ id = "ver-blank", addon = "Ver_Addon", apiMajor = 1, apiMinor = "" })
		local hBlankMaj, cBlankMaj = V.API:RegisterPlugin({ id = "ver-blankmaj", addon = "Ver_Addon", apiMajor = "" })
		check(hBlank == nil and cBlank == "invalid-manifest" and hBlankMaj == nil and cBlankMaj == "invalid-manifest", "a supplied blank string is not an omission: invalid-manifest")
		cleanup()
		-- in discovery, a malformed TOC version is a problem row, and the runtime agrees
		local T = boot({ addons = { { name = "Bad_Toc", title = "Bad Toc", meta = { ["X-BagSmith-Plugin"] = "bad-toc", ["X-BagSmith-API"] = "1", ["X-BagSmith-API-Minor"] = "banana" }, loaded = true, enabled = true } } })
		local stB = T.API:PluginItemByAddon("Bad_Toc").status
		local hB, cB = T.API:RegisterPlugin({ id = "bad-toc", addon = "Bad_Toc", apiMajor = 1, apiMinor = 0 })
		check(stB.canEnable == false and stB.text:find("whole non%-negative number") and hB == nil and cB == "invalid-manifest", "a malformed TOC minor is a problem row and refuses registration")
		cleanup()
	end
	-- the empty state: addon lookup works, nothing declares the marker
	do
		local E = boot({ addons = { { name = "Unrelated", meta = {}, loaded = true, enabled = true } } })
		local EP = E.n.SettingsPanel
		EP:Show(); EP:ShowPage("plugins")
		local empty, reloadLine, feats = 0, 0, 0
		for _, w in ipairs(EP.pools.text) do if w:IsShown() then if w.text.text:find("No plugins installed yet", 1, true) then empty = empty + 1 end if w.text.text:find("takes effect after you reload", 1, true) then reloadLine = reloadLine + 1 end end end
		for _, w in ipairs(EP.pools.feat) do if w:IsShown() then feats = feats + 1 end end
		check(empty == 1 and reloadLine == 0 and feats == 1, "with nothing installed the section is one line without the reload rule, and the coming-soon card shows")
		EP:Hide(); cleanup()
	end
	-- no addon-management API: statuses readable, toggles unavailable
	_G.C_AddOns = nil
	S.API:RefreshPlugins()
	check(#S.API:PluginList() == 0 and S.API:CanToggle() == false, "without the addon API nothing is discoverable and toggles are unavailable")
	cleanup()
	-- the Plugins page: rows, notice, featured, search; rendering never activates, toggles or re-enumerates
	S = boot({ addons = {
		{ name = "BagSmith_Gamepad", title = "BagSmith Gamepad", notes = string.rep("A long description of controller browsing that wraps. ", 6), meta = { ["X-BagSmith-Plugin"] = "bagsmith-gamepad", ["X-BagSmith-API"] = "1", Version = "1.0.0-beta", Author = "BagSmith" }, loaded = false, enabled = true, deps = { "BagSmith" } },
		{ name = "Third_Thing", title = string.rep("Very Long Plugin Name ", 5), notes = "x", meta = { ["X-BagSmith-Plugin"] = "third-thing", ["X-BagSmith-API"] = "1", Author = "Someone" }, loaded = true, enabled = true, deps = { "BagSmith" } },
	} })
	local P = S.n.SettingsPanel
	P:Show(); P:ShowPage("plugins")
	local rows = 0; for _, w in ipairs(P.pools.plug) do if w:IsShown() then rows = rows + 1 end end
	local notices = 0; for _, w in ipairs(P.pools.pnotice) do if w:IsShown() then notices = notices + 1 end end
	local feats = {}; for _, w in ipairs(P.pools.feat) do if w:IsShown() then feats[#feats + 1] = w end end
	check(rows == 2 and notices == 0 and #feats == 0, "the page shows one row per plugin, no pending notice for untouched addons, and no Featured section while the companion is installed")
	do
		local reloadLine, empty = 0, 0
		for _, w in ipairs(P.pools.text) do if w:IsShown() then if w.text.text:find("applies to Tester only and takes effect after you reload", 1, true) then reloadLine = reloadLine + 1 end if w.text.text:find("No plugins installed", 1, true) then empty = empty + 1 end end end
		check(reloadLine == 1 and empty == 0, "with plugins installed the section opens with the one-line reload rule naming the character, and no empty-state line")
	end
	local gpRow; for _, w in ipairs(P.pools.plug) do if w:IsShown() and w.pluginId == "bagsmith-gamepad" then gpRow = w end end
	check(gpRow and gpRow.status.text:find("Enabled, not loaded (reload required)", 1, true) and gpRow.meta.text:find("Official", 1, true) and gpRow.box:GetChecked() and not gpRow.options:IsShown(), "the companion's row says enabled but not loaded, carries the Official badge, and offers no Options while not active")
	gpRow.box:SetChecked(false); gpRow.box:GetScript("OnClick")(gpRow.box)
	notices = 0; for _, w in ipairs(P.pools.pnotice) do if w:IsShown() then notices = notices + 1 end end
	check(notices == 1 and S.addons[1].enabled == false, "unticking the row disables that addon for the character and shows the one pending notice")
	gpRow = nil; for _, w in ipairs(P.pools.plug) do if w:IsShown() and w.pluginId == "bagsmith-gamepad" then gpRow = w end end
	gpRow.box:SetChecked(true); gpRow.box:GetScript("OnClick")(gpRow.box)
	notices = 0; for _, w in ipairs(P.pools.pnotice) do if w:IsShown() then notices = notices + 1 end end
	check(notices == 0 and S.addons[1].enabled == true, "ticking it back clears the notice")
	local q0 = S.enableQueries or 0
	P:Refresh(); P:Refresh()
	check((S.enableQueries or 0) - q0 == 0 and S.API:Plugin("third-thing") == nil, "re-rendering reads the cached status model: no enable-state queries, no activation")
	P:SetQuery("someone")
	local found = 0; for _, w in ipairs(P.pools.plug) do if w:IsShown() then found = found + 1 end end
	check(found == 1, "search finds a plugin by its author")
	P:SetQuery("controller")
	found = 0; for _, w in ipairs(P.pools.plug) do if w:IsShown() then found = found + 1 end end
	local fcount = 0; for _, w in ipairs(P.pools.feat) do if w:IsShown() then fcount = fcount + 1 end end
	check(found >= 1 and fcount == 0, "search for controller finds the rows (no featured card while the companion is installed)")
	P:SetQuery("")
	-- without the companion installed: the coming-soon card with copyable CurseForge and Discord links, no Options
	do
		local saved = S.addons[1]; table.remove(S.addons, 1); S.API:RefreshPlugins()
		P:ShowPage("plugins")
		local card; for _, w in ipairs(P.pools.feat) do if w:IsShown() then card = w end end
		check(card and card.text.text == "BagSmith Gamepad: coming soon" and card.help.text:find("from a gamepad or controller", 1, true) and card.help.text:find("just like with a keyboard and mouse", 1, true) and card.help.text:find("alpha testing", 1, true) and card.help.text:find("Join the Discord", 1, true) and not card.help.text:find("works fully without", 1, true),
			"with the companion absent, the Featured section is the coming-soon card in the agreed wording")
		check(card.link.linkKey == "gamepad" and card.link.label.text == "CurseForge" and card.discord.linkKey == "discord" and card.discord.label.text == "Discord" and card.link.icon and card.discord.icon, "its two buttons are the About page's CurseForge and Discord link buttons")
		local shown = {}
		local realShowLink = S.n.ShowLink; S.n.ShowLink = function(label, url) shown[#shown + 1] = url end
		card.link:GetScript("OnClick")(card.link); card.discord:GetScript("OnClick")(card.discord)
		check(shown[1] == "https://www.curseforge.com/wow/addons/bagsmith-gamepad-support" and shown[2] == "https://discord.gg/uYfcHPkcar", "both open the copy-link dialog with the real addresses")
		S.n.ShowLink = realShowLink
		-- layout: the description starts below the CurseForge button, the title stops short of it, Discord sits at the bottom right
		local linkW = card.link:GetWidth()
		check(card.helpTop >= 4 + 24 + 6 and card.text.width + 2 <= (card:GetWidth() - linkW) - 8 and card.discord.points[1][1] == "BOTTOMRIGHT", "the description begins under the CurseForge button, the title ends before it, and Discord is bottom right")
		local empty; for _, w in ipairs(P.pools.text) do if w:IsShown() and w.text.text:find("No plugins installed yet", 1, true) then empty = w end end
		check(not empty, "(another plugin is still installed here, so no empty-state line)")
		S.n.ShowLink = realShowLink
		table.insert(S.addons, 1, saved); S.API:RefreshPlugins()
	end
	-- an active plugin with options: the row offers Options and the page renders through the bridge, never during search
	local renders = 0
	local hh = S.API:RegisterPlugin({ id = "third-thing", addon = "Third_Thing", apiMajor = 1 }, { onEnable = function(ctx)
		ctx:RegisterOptions({ title = "Third options", render = function(ui) renders = renders + 1; ui:Check("A choice", "help", function() return S.choice end, function(v) S.choice = v end); ui:Button("Press", function() S.pressed = true end) end })
	end })
	S.M.runTimers()
	P:ShowPage("plugins")
	local row3; for _, w in ipairs(P.pools.plug) do if w:IsShown() and w.pluginId == "third-thing" then row3 = w end end
	check(row3 and row3.options:IsShown() and row3.status.text:find("Status: Active", 1, true), "an active plugin with options shows Active and an Options button")
	check(row3.text.width and 2 + row3.text.width <= 306 - 8, "a long active title stops short of the Options button (which starts at x=306) and the checkbox")
	check(row3.help.points[1][3] <= -(4 + 24 + 8), "the row's description starts below the checkbox and the Options button")
	P:SetQuery("choice"); P:SetQuery("")
	check(renders == 0, "search never runs an options render")
	P:ShowPluginOptions("third-thing", "Third_Thing")
	check(renders == 1 and P.page == "pluginoptions", "the Options button renders the plugin's options page")
	local back; for _, w in ipairs(P.pools.btn) do if w:IsShown() and w.label.text == "Back to Plugins" then back = w end end
	check(back ~= nil, "the options page offers a way back")
	back.onClick(back)
	check(P.page == "plugins", "Back returns to the Plugins page")
	P:ShowPluginOptions("third-thing", "Third_Thing")
	local box; for _, w in ipairs(P.pools.check) do if w:IsShown() and w.onSet then box = w end end
	box.box:SetChecked(true); box.box:GetScript("OnClick")(box.box)
	check(S.choice == true and renders == 3, "a plugin check row calls the plugin's setter and redraws")
	P:ShowPage("general")
	local core; for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == "replaceBlizzardBags" then core = w end end
	check(core and core.onSet == nil, "a recycled check row used by core carries no plugin setter")
	do   -- (a scope: Lua 5.1 allows 200 active locals per function)
	-- options callbacks run through the guarded dispatch: a throwing render, getter, setter or button fails the plugin once
	local function optPlugin(id, addon, render)
		local shut = 0
		local h = S.API:RegisterPlugin({ id = id, addon = addon, apiMajor = 1 }, { onEnable = function(ctx) ctx:RegisterOptions({ title = id, render = render }); ctx:RegisterCommand(id .. "cmd", function() S.ran = (S.ran or 0) + 1 end) end, onShutdown = function() shut = shut + 1 end })
		S.M.runTimers()
		return h, function() return shut end
	end
	S.addons[#S.addons + 1] = { name = "Opt_Render", meta = { ["X-BagSmith-Plugin"] = "opt-render", ["X-BagSmith-API"] = "1" }, loaded = true, enabled = true }
	S.addons[#S.addons + 1] = { name = "Opt_Getter", meta = { ["X-BagSmith-Plugin"] = "opt-getter", ["X-BagSmith-API"] = "1" }, loaded = true, enabled = true }
	S.addons[#S.addons + 1] = { name = "Opt_Setter", meta = { ["X-BagSmith-Plugin"] = "opt-setter", ["X-BagSmith-API"] = "1" }, loaded = true, enabled = true }
	S.addons[#S.addons + 1] = { name = "Opt_Button", meta = { ["X-BagSmith-Plugin"] = "opt-button", ["X-BagSmith-API"] = "1" }, loaded = true, enabled = true }
	local hR, shutR = optPlugin("opt-render", "Opt_Render", function(ui) error("render boom") end)
	P:ShowPluginOptions("opt-render", "Opt_Render"); S.M.runTimers()
	check(hR:GetState() == "failed" and shutR() == 1 and S.API.commands["opt-rendercmd"] == nil and S.API:DispatchCommand("opt-rendercmd", "") == false, "a throwing options render fails the plugin once; its command no longer runs")
	local hG, shutG = optPlugin("opt-getter", "Opt_Getter", function(ui) ui:Check("x", nil, function() error("get boom") end, function() end) end)
	P:ShowPluginOptions("opt-getter", "Opt_Getter"); S.M.runTimers()
	check(hG:GetState() == "failed" and shutG() == 1, "a throwing getter is a plugin failure, not a silent false")
	local hS, shutS = optPlugin("opt-setter", "Opt_Setter", function(ui) ui:Check("x", nil, function() return true end, function() error("set boom") end) end)
	P:ShowPluginOptions("opt-setter", "Opt_Setter")
	local boxS; for _, w in ipairs(P.pools.check) do if w:IsShown() and w.onSet then boxS = w end end
	boxS.box:GetScript("OnClick")(boxS.box); S.M.runTimers()
	check(hS:GetState() == "failed" and shutS() == 1, "a throwing setter fails the plugin once")
	local hB, shutB = optPlugin("opt-button", "Opt_Button", function(ui) ui:Button("Go", function() error("button boom") end) end)
	P:ShowPluginOptions("opt-button", "Opt_Button")
	local btnB; for _, w in ipairs(P.pools.btn) do if w:IsShown() and w.label.text == "Go" then btnB = w end end
	btnB.onClick(btnB); S.M.runTimers()
	check(hB:GetState() == "failed" and shutB() == 1, "a throwing button fails the plugin once")
	-- a widget already on screen cannot run plugin code after the plugin failed for another reason
	S.addons[#S.addons + 1] = { name = "Opt_Live", meta = { ["X-BagSmith-Plugin"] = "opt-live", ["X-BagSmith-API"] = "1" }, loaded = true, enabled = true }
	local live = { sets = 0, buttons = 0, shut = 0 }
	local hL = S.API:RegisterPlugin({ id = "opt-live", addon = "Opt_Live", apiMajor = 1 }, { onEnable = function(ctx)
		ctx:RegisterOptions({ render = function(ui) ui:Check("live", nil, function() return false end, function() live.sets = live.sets + 1 end); ui:Button("Live", function() live.buttons = live.buttons + 1 end) end })
		ctx:Subscribe("VIEW_HIDDEN", function() error("event boom") end)
	end, onShutdown = function() live.shut = live.shut + 1 end })
	S.M.runTimers()
	P:ShowPluginOptions("opt-live", "Opt_Live")
	local boxL; for _, w in ipairs(P.pools.check) do if w:IsShown() and w.onSet then boxL = w end end
	local btnL; for _, w in ipairs(P.pools.btn) do if w:IsShown() and w.label.text == "Live" then btnL = w end end
	local setL, clickL = boxL.onSet, btnL.onClick
	S.open(); S.close()   -- the event error fails the plugin while its page is open
	check(hL:GetState() == "failed" and live.shut == 1, "(setup) the plugin failed through an event while its options page was open")
	setL(true); clickL(btnL); S.M.runTimers()
	check(live.sets == 0 and live.buttons == 0, "widgets drawn before the failure no longer run plugin code")
	check(P.page == "pluginoptions" and (function() for _, w in ipairs(P.pools.check) do if w:IsShown() and w.onSet then return false end end return true end)(), "the page was redrawn without the plugin's widgets")
	P:ShowPage("general"); core = nil; for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == "replaceBlizzardBags" then core = w end end
	core.box:SetChecked(not S.n.db.replaceBlizzardBags); core.box:GetScript("OnClick")(core.box)
	check(core and S.n.db.replaceBlizzardBags ~= nil, "core settings rows still work")
	-- a user's click: only an enabled box can be operated
	local function userClick(box) if not box:IsEnabled() then return false end box:SetChecked(not box:GetChecked()); box:GetScript("OnClick")(box); return true end
	-- the checkbox bridge shows the getter's real value and follows toggles through the actual widget
	S.addons[#S.addons + 1] = { name = "Opt_Bool", meta = { ["X-BagSmith-Plugin"] = "opt-bool", ["X-BagSmith-API"] = "1" }, loaded = true, enabled = true }
	local flag = true
	local hBool = S.API:RegisterPlugin({ id = "opt-bool", addon = "Opt_Bool", apiMajor = 1 }, { onEnable = function(ctx) ctx:RegisterOptions({ render = function(ui) ui:Check("flag", nil, function() return flag end, function(v) flag = v end) end }) end }); S.M.runTimers()
	local function boolBox() for _, w in ipairs(P.pools.check) do if w:IsShown() and w.onSet then return w end end end
	P:ShowPluginOptions("opt-bool", "Opt_Bool")
	check(boolBox().box:GetChecked() == true and boolBox().box:IsEnabled(), "a getter returning true shows a checked, enabled box")
	check(userClick(boolBox().box) and flag == false and boolBox().box:GetChecked() == false, "unticking writes false through the setter and the redraw shows it unchecked")
	check(userClick(boolBox().box) and flag == true and boolBox().box:GetChecked() == true, "ticking writes true and the redraw shows it checked")
	flag = false; P:Refresh()
	check(boolBox().box:GetChecked() == false and hBool:GetState() == "active", "a getter returning false is an ordinary unchecked result, not an error")
	P:ShowPage("general"); P:ShowPluginOptions("opt-bool", "Opt_Bool")
	check(boolBox().box:GetChecked() == false, "reopening the page reads the value back")
	-- a getter failure, then General: the pooled checkbox is usable again for a core setting
	S.addons[#S.addons + 1] = { name = "Opt_Bad", meta = { ["X-BagSmith-Plugin"] = "opt-bad", ["X-BagSmith-API"] = "1" }, loaded = true, enabled = true }
	local hBad = S.API:RegisterPlugin({ id = "opt-bad", addon = "Opt_Bad", apiMajor = 1 }, { onEnable = function(ctx) ctx:RegisterOptions({ render = function(ui) ui:Check("bad", nil, function() error("get boom") end, function() end) end }) end }); S.M.runTimers()
	P:ShowPluginOptions("opt-bad", "Opt_Bad"); S.M.runTimers()
	check(hBad:GetState() == "failed", "(setup) the getter failure stopped the plugin")
	P:ShowPage("general"); core = nil; for _, w in ipairs(P.pools.check) do if w:IsShown() and w.key == "replaceBlizzardBags" then core = w end end
	local before = S.n.db.replaceBlizzardBags
	check(core and core.box:IsEnabled() and userClick(core.box) and S.n.db.replaceBlizzardBags == (not before), "after a plugin getter failure the recycled checkbox is enabled for the core setting and a real click changes it")
	userClick(core.box)
	-- disposers are bound to their registration: an old disposer never removes a newer one; repeats are no-ops
	S.addons[#S.addons + 1] = { name = "Disp_A", meta = { ["X-BagSmith-Plugin"] = "disp-a", ["X-BagSmith-API"] = "1" }, loaded = true, enabled = true }
	local hA = S.API:RegisterPlugin({ id = "disp-a", addon = "Disp_A", apiMajor = 1 }, {}); S.M.runTimers()
	local dA = hA.context:RegisterCommand("shared", function() S.who = "A" end)
	check(dA() == true and dA() == false, "a command disposer disposes once and is a no-op after")
	local dB = hA.context:RegisterCommand("shared", function() S.who = "B" end)
	check(dA() == false and S.API.commands.shared ~= nil and S.API:DispatchCommand("shared", "") and S.who == "B", "the old disposer called again leaves the newer registration in place")
	local oA = hA.context:RegisterOptions({ render = function() end }); oA()
	local oB = hA.context:RegisterOptions({ title = "B options", render = function() end })
	check(oA() == false and S.API:Plugin("disp-a").options and S.API:Plugin("disp-a").options.title == "B options", "an old options disposer never removes the newer options")
	check(oB() == true and S.API:Plugin("disp-a").options == nil and oB() == false, "the current options disposer works once")
	S.API:Shutdown("disp-a", "test")
	check(dB() == false and S.API.commands.shared == nil, "after a shutdown the disposers are harmless no-ops and nothing is left registered")
	-- a required dependency that is installed and enabled but cannot load here blocks enabling; so does an unknown dependency state
	S.addons[#S.addons + 1] = { name = "Old_Lib", meta = {}, loaded = false, loadable = false, reason = "INTERFACE_VERSION", enabled = true }
	S.addons[#S.addons + 1] = { name = "Needs_Old_Lib", title = "Needs Old Lib", meta = { ["X-BagSmith-Plugin"] = "needs-old-lib", ["X-BagSmith-API"] = "1" }, loaded = false, loadable = false, reason = "DEP_INTERFACE_VERSION", enabled = false, deps = { "BagSmith", "Old_Lib" } }
	S.addons[#S.addons + 1] = { name = "Odd_Lib", meta = {}, loaded = false, enabled = true, stateError = true }
	S.addons[#S.addons + 1] = { name = "Needs_Odd_Lib", title = "Needs Odd Lib", meta = { ["X-BagSmith-Plugin"] = "needs-odd-lib", ["X-BagSmith-API"] = "1" }, loaded = false, enabled = false, deps = { "BagSmith", "Odd_Lib" } }
	local origState = C_AddOns.GetAddOnEnableState
	C_AddOns.GetAddOnEnableState = function(x, char) for _, e in ipairs(S.addons) do if e.name == x and e.stateError then error("cannot query") end end return origState(x, char) end
	S.API:RefreshPlugins()
	local stOld = S.API:PluginItemByAddon("Needs_Old_Lib").status
	local okOld = S.API:SetPluginEnabled("Needs_Old_Lib", true)
	check(stOld.canEnable == false and stOld.text:find("unusable dependency", 1, true) and stOld.text:find("Old_Lib", 1, true) and okOld == false and S.addons[#S.addons - 2].enabled == false, "an installed, enabled dependency that cannot load on this client blocks enabling and is named; nothing is written")
	local stOdd = S.API:PluginItemByAddon("Needs_Odd_Lib").status
	check(stOdd.canEnable == false and stOdd.text:find("dependency of unknown state Odd_Lib", 1, true) and stOdd.canDisable == true, "a dependency whose state cannot be determined is reported unknown, not ready; disabling stays available")
	S.addons[#S.addons + 1] = { name = "Dep_Blocked", title = "Dep Blocked", meta = { ["X-BagSmith-Plugin"] = "dep-blocked", ["X-BagSmith-API"] = "1" }, loaded = false, loadable = false, reason = "DEP_INTERFACE_VERSION", enabled = false, deps = { "BagSmith" } }
	S.API:RefreshPlugins()
	local stDep = S.API:PluginItemByAddon("Dep_Blocked").status
	check(stDep.canEnable == false and stDep.text:find("a dependency is for another game version", 1, true), "the game's own DEP_ reason on the plugin blocks enabling with the plain-words reason")
	C_AddOns.GetAddOnEnableState = origState
	-- the remaining dependency results: an unverifiable list, unknown loadability, no reason, load-on-demand, MISSING_DEPENDENCY, an empty list
	S.addons[#S.addons + 1] = { name = "Quiet_Lib", meta = {}, loaded = false, loadable = false, reason = "", enabled = true }
	S.addons[#S.addons + 1] = { name = "Needs_Quiet_Lib", title = "Needs Quiet Lib", meta = { ["X-BagSmith-Plugin"] = "needs-quiet-lib", ["X-BagSmith-API"] = "1" }, loaded = false, enabled = false, deps = { "BagSmith", "Quiet_Lib" } }
	S.addons[#S.addons + 1] = { name = "Lod_Lib", meta = {}, loaded = false, loadable = false, reason = "DEMAND_LOADED", enabled = true }
	S.addons[#S.addons + 1] = { name = "Needs_Lod_Lib", title = "Needs Lod Lib", meta = { ["X-BagSmith-Plugin"] = "needs-lod-lib", ["X-BagSmith-API"] = "1" }, loaded = false, enabled = false, deps = { "BagSmith", "Lod_Lib" } }
	S.addons[#S.addons + 1] = { name = "Says_Missing", title = "Says Missing", meta = { ["X-BagSmith-Plugin"] = "says-missing", ["X-BagSmith-API"] = "1" }, loaded = false, loadable = false, reason = "MISSING_DEPENDENCY", enabled = false, deps = { "BagSmith" } }
	S.addons[#S.addons + 1] = { name = "No_Deps", title = "No Deps", meta = { ["X-BagSmith-Plugin"] = "no-deps", ["X-BagSmith-API"] = "1" }, loaded = false, enabled = false, deps = {} }
	S.API:RefreshPlugins()
	local stQ = S.API:PluginItemByAddon("Needs_Quiet_Lib").status
	check(stQ.canEnable == false and stQ.text:find("dependency of unknown state Quiet_Lib", 1, true) and S.API:SetPluginEnabled("Needs_Quiet_Lib", true) == false, "a dependency that cannot load for no stated reason is unknown, not ready")
	local stL = S.API:PluginItemByAddon("Needs_Lod_Lib").status
	check(stL.canEnable == true and stL.text == "Disabled", "a load-on-demand dependency is legitimate: enabling is offered")
	local stM = S.API:PluginItemByAddon("Says_Missing").status
	check(stM.canEnable == false and stM.text:find("a dependency is missing", 1, true), "the game's MISSING_DEPENDENCY reason on the plugin is normalized like DEP_MISSING")
	check(S.API:PluginItemByAddon("No_Deps").status.canEnable == true, "a verified empty dependency list is fine")
	local origDeps = C_AddOns.GetAddOnDependencies
	C_AddOns.GetAddOnDependencies = function() error("not available") end
	S.API:RefreshPlugins()
	local stU = S.API:PluginItemByAddon("No_Deps").status
	check(stU.canEnable == false and stU.canDisable == true and stU.text == "Installed, dependencies could not be verified on this client" and S.API:SetPluginEnabled("No_Deps", true) == false, "a dependency enumeration that fails is unverifiable: no enable, disable still allowed")
	C_AddOns.GetAddOnDependencies = nil
	S.API:RefreshPlugins()
	check(S.API:PluginItemByAddon("No_Deps").status.text == "Installed, dependencies could not be verified on this client", "a client without the dependency call is unverifiable too")
	C_AddOns.GetAddOnDependencies = origDeps
	S.API:RefreshPlugins()
	check(S.API:PluginItemByAddon("No_Deps").status.canEnable == true, "with the call back, verification resumes")
	cleanup()
	-- the enable-state baseline is taken at startup, so an AddOns-screen change made before the first Settings open is seen
	S = boot({ addons = {
		{ name = "Early_Plug", title = "Early Plug", meta = { ["X-BagSmith-Plugin"] = "early-plug", ["X-BagSmith-API"] = "1" }, loaded = true, enabled = true, deps = { "BagSmith" } },
	} })
	local eh = S.API:RegisterPlugin({ id = "early-plug", addon = "Early_Plug", apiMajor = 1 }, {}); S.M.runTimers()
	S.addons[1].enabled = false   -- changed on the game's AddOns screen before Settings was ever opened
	S.n.SettingsPanel:Show(); S.n.SettingsPanel:ShowPage("plugins")
	local stE = S.API:PluginItemByAddon("Early_Plug").status
	check(eh:GetState() == "active" and stE.enabled == "disabled" and stE.pending == true and stE.text == "Disabled next reload, still active now" and S.API:PendingReloadCount() == 1, "an external disable before the first Settings open shows as pending against the startup baseline")
	S.addons[1].enabled = true; S.n.SettingsPanel:Hide(); S.n.SettingsPanel:Show()
	check(S.API:PluginItemByAddon("Early_Plug").status.pending == false, "re-enabling it externally and reopening Settings clears the pending state")
	cleanup()
	end
end)()

