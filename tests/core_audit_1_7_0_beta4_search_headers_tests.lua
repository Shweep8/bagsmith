-- The 1.7.0-beta4 audit's probes/settings_search_headers.lua (docs/plugins/audit-1.7.0-beta4/), unchanged: on beta4 the
-- three no-orphan checks failed (F3); fixed in 1.7.0-beta5.
;(function()
package.loaded.mock = nil
local M = require('mock')
_G.BagSmithCharDB = { version = 1, firstSeen = {} }
_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = {} } }
local n = M.loadAddon('BagSmith')
M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers(); M.runTimers()
local P = n.SettingsPanel
P:Show(); P:ShowPage('sections'); M.runTimers()
for _, q in ipairs({'highlight','opacity','vendor','highlight opacity'}) do
 n.db.pinnedHighlight = true
 P:SetQuery(q); M.runTimers()
 local headers, lists = 0, 0
 for _, w in ipairs(P.pools.listhead) do if w:IsShown() then headers = headers + 1 end end
 for _, w in ipairs(P.pools.list) do if w:IsShown() then lists = lists + 1 end end
 print(q .. ': headers=' .. headers .. ' lists=' .. lists)
 check(lists > 0 or headers == 0, q .. ': no orphan table headers')
end

end)()
