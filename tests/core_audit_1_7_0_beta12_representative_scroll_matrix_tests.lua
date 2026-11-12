-- 1.7.0-beta13: the 1.7.0-beta12 audit's own probe (ui/representative_scroll_matrix.lua), its checks unchanged, kept in the suite. Evidence and the
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
	_G.MailFrame = CreateFrame("Frame", "MailFrame", UIParent); _G.SendMailFrame = CreateFrame("Frame", "SendMailFrame", MailFrame); MailFrame:Hide(); SendMailFrame:Hide()
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


for _,ctx in ipairs({'none','mail','trade','inbox'}) do
 MailFrame:Hide();SendMailFrame:Hide();TradeFrame:Hide()
 if ctx=='mail' or ctx=='inbox' then MailFrame:Show() end
 if ctx=='mail' then SendMailFrame:Show() end
 if ctx=='trade' then TradeFrame:Show() end
 D:CheckFullest();M.runTimers()
 for a=1,20,3 do for b=1,20,4 do
  for mask=0,3 do
   stock({a,b,20});M.bags[0][1].locked=mask%2==1;M.bags[0][2].locked=mask>=2
   local bt=row();local expected=1
   if ctx=='mail' or ctx=='trade' then
    local best=M.bags[0][1]
    for i=1,3 do local r=M.bags[0][i];if not r.locked and (best.locked or r.count>best.count) then expected=i;best=r end end
   end
   check(bt.rec.slot==expected,ctx..' correct representative')
   check(bt:GetID()==expected,ctx..' secure button matches representative')
   check(bt.rec.count==a+b+20 and bt.rec.stacks==3 and #bt.rec.members==3,ctx..' counts preserved')
  end
 end end
end
MailFrame:Hide();SendMailFrame:Hide();TradeFrame:Hide()
local WN=n.WhatsNew
n.version="1.7.0-beta12"
for _,skin in ipairs({'modern','classic'}) do
 n:Set('skin',skin);M.runTimers()
 for _,height in ipairs({420,480,600,768,1080}) do
  UIParent:SetHeight(height);WN:ShowLatest();M.runTimers()
  local c=WN.Card();local fixed=c:GetHeight()
  for cycle=1,3 do for i=1,#c.entries do
   WN:Select(i)
   check(c:GetHeight()==fixed and c:GetHeight()<=height,'card height stable')
   check(c.bodyH<=360 and c.bodyH>0,'body capped')
   check(c.body:GetVerticalScroll()==0,'tab resets scroll')
   local wheel=c.body:GetScript('OnMouseWheel');wheel(c.body,-10000)
   check(c.body:GetVerticalScroll()==math.max(0,c.contentH-c.bodyH),'scroll lower bound')
   wheel(c.body,10000);check(c.body:GetVerticalScroll()==0,'scroll upper bound')
   check(c.body.ScrollBar:IsShown()==(c.contentH>c.bodyH),'scrollbar visibility')
  end end
  WN:Close()
 end
end
UIParent:SetHeight(768)
end)()
