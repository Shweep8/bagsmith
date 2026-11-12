-- 1.7.0-beta13: the 1.7.0-beta12 audit's own probe (ui/late_mail_frame.lua), its checks unchanged, kept in the suite. Evidence and the
-- report: docs/plugins/audit-1.7.0-beta12/.
;(function()
	-- ======== 1.7.0-beta12: full stacks into the mail and the trade (Shweep) ========
	-- While the mailbox's send form or a trade window is open, a merged row stands on its fullest stack, so the game's own
	-- attach is a full one; then, before the rest follow, BagSmith tops up the partial stacks still in the bags (the
	-- fullest partial takes what fits from the smallest, one move at a time, each checked), and sends full stacks first,
	-- the leftover last. Shweep's 70 Linen Cloth (20, 20, 19, 11) went as 20, 20, 19, 11; now as 20, 20, 20, 10.
	package.loaded.mock = nil
	local M = require("mock")
	local ID = 2589
	local function linen(slot, count) M.put(0, slot, { id = ID, name = "Linen Cloth", q = 1, count = count, class = 7, subclass = 5, price = 1 }) end
	local function stock(counts) for s = 1, 8 do M.bags[0][s] = nil end; for s, c in ipairs(counts) do linen(s, c) end end
	stock({ 11, 20, 19, 20 })
	_G.BagSmithCharDB = { version = 1, firstSeen = {} }
	_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern" } } }
	_G.MailFrame = nil; _G.SendMailFrame = nil
	_G.TradeFrame = CreateFrame("Frame", "TradeFrame", UIParent); TradeFrame:Hide()
	_G.ATTACHMENTS_MAX_SEND = 12; _G.MAX_TRADE_ITEMS = 7
	local mail, trade = {}, {}
	_G.GetSendMailItem = function(i) local a = mail[i]; if a then return a.name, a.id, 1, a.count end end
	_G.GetSendMailItemLink = function(i) local a = mail[i]; if a and a.id then return "|Hitem:" .. a.id .. ":0|h[" .. a.name .. "]|h" end end
	_G.GetTradePlayerItemInfo = function(i) local a = trade[i]; if a then return a.name end end
	_G.GetTradePlayerItemLink = function(i) local a = trade[i]; if a then return "|Hitem:" .. a.id .. ":0|h[" .. a.name .. "]|h" end end
	local n = M.loadAddon("BagSmith")
	M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
	local D = n.Drop
	n:Set("mergeStacks", true); M.runTimers()
	n.Window:Show(); M.runTimers(); M.runTimers()
	local function row()
		n:Scan(); M.runTimers(); n.Window.main:Refresh(true, "test"); M.runTimers()
		for _, b in ipairs(n.Buttons.all) do if b:IsShown() and b.rec and b.rec.itemID == ID and b.rec.merged then return b end end
	end
	local function at(b) return b and (b.rec.bag .. ":" .. b.rec.slot) or "none" end
	local function said() return M.log[#M.log] or "" end
	local function clearLog() for i = #M.log, 1, -1 do M.log[i] = nil end end
	local function run() for _ = 1, 60 do M.runTimers() end end


local first=row(); check(first.rec.slot==1,'first stack before mail')
_G.MailFrame=CreateFrame('Frame','MailFrame',UIParent);_G.SendMailFrame=CreateFrame('Frame','SendMailFrame',MailFrame)
MailFrame:Show();SendMailFrame:Hide();M.fire('MAIL_SHOW');M.runTimers();M.runTimers()
SendMailFrame:Show();if SendMailFrame.scripts.OnShow then SendMailFrame.scripts.OnShow(SendMailFrame) end
M.runTimers();M.runTimers()
local visible
for _,x in ipairs(n.Buttons.all) do if x:IsShown() and x.rec and x.rec.itemID==ID and x.rec.merged then visible=x end end
print('Late send form hook='..tostring(SendMailFrame.scripts.OnShow~=nil)..' standing='..tostring(D:StandsOnFullest())..' rep='..tostring(visible and visible.rec.slot))
check(visible and visible.rec.slot==2,'late-created mail send form should refresh representative on tab switch')
end)()
