-- 1.7.0-beta14: the 1.7.0-beta13 audit's own probe (ui/pooling_lifecycle.lua), its checks unchanged, kept in the suite. Evidence and the
-- report: docs/plugins/audit-1.7.0-beta13/.
package.loaded.mock=nil
local M=require('mock')
_G.BagSmithCharDB={version=1,firstSeen={}}
_G.BagSmithDB={version=2,chars={},cache={},profiles={Default={}}}
_G.MailFrame=nil;_G.SendMailFrame=nil
local n=M.loadAddon('BagSmith');M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers()
local writer
for i=1,100 do local name,v=debug.getupvalue(n.View.Layout,i);if not name then break end;if name=='writeHeaderValues' then writer=v end end
assert(writer,'actual writer upvalue')
local function header(name)
 local h=CreateFrame('Button',nil,UIParent)
 for _,k in ipairs({'text','count','sub','vLabel','vAmt','aLabel','aAmt','wornTag'}) do h[k]=h:CreateFontString();h[k]:Hide() end
 h.text:SetText(name);h.count:SetText('(9)');h.text:Show();h.count:Show()
 h.equipSet=CreateFrame('Button',nil,h);h.equipSet:SetWidth(70);h.equipSet:Hide()
 h.clearRecent=CreateFrame('Button',nil,h);h.clearRecent.label=h.clearRecent:CreateFontString();h.clearRecent:Hide()
 return h
end
local infos={}
for i=1,5 do infos[i]={h=header('Section '..i),v='12g 50s 25c',ah='25g 80s 99c',colW=400} end
local modes={ 'normal','recent','emptyCustom','emptySet','gearSet'}
for cycle=1,4 do
 for _,mode in ipairs(modes) do
  for _,width in ipairs({90,220,350,700,220,90,700}) do
   for i,x in ipairs(infos) do
    x.colW=width;x.recent=nil;x.emptyCustom=nil;x.emptySet=nil;x.emptyHint=nil;x.setNote=nil
    x.h.equipSet:Hide();x.h.wornTag:Hide()
    if i%2==0 then
     if mode=='gearSet' then x.h.equipSet:Show();x.h.wornTag:SetText('Worn');x.h.wornTag:Show()
     elseif mode~='normal' then x[mode]=true;x.emptyHint=true;x.setNote='Worn or in bank' end
    end
   end
   writer(infos)
   for _,x in ipairs(infos) do
    local h=x.h;local coin=h.valCoin and h.valCoin:IsShown();local tab=h.vAmt:IsShown() or h.aAmt:IsShown() or h.vLabel:IsShown() or h.aLabel:IsShown();local sub=h.sub:IsShown()
    check((coin and 1 or 0)+(tab and 1 or 0)+(sub and 1 or 0)<=1,'one format after reuse '..mode)
    if x.recent or x.emptyCustom or x.emptySet then check(not coin and not tab,'special header clears values '..mode) end
    if coin then check(h.valCoin.v==x.v and h.valCoin.ah==x.ah,'coin refreshed') end
   end
  end
 end
end
-- late frame discovery and idempotence, preserving an existing handler
local count,old=0,0
_G.MailFrame=CreateFrame('Frame','MailFrame',UIParent);_G.SendMailFrame=CreateFrame('Frame','SendMailFrame',MailFrame)
SendMailFrame:SetScript('OnShow',function() old=old+1 end)
local hook=SendMailFrame.HookScript
SendMailFrame.HookScript=function(self,ev,f) count=count+1;return hook(self,ev,f) end
for j=1,10 do M.fire('MAIL_SHOW');M.runTimers();M.fire('MAIL_CLOSED');M.runTimers() end
check(count==2,'one show and one hide hook across ten sessions')
SendMailFrame.scripts.OnShow(SendMailFrame);M.runTimers();check(old==1,'preexisting OnShow preserved')
check(n.Drop.sendFormHooked==SendMailFrame,'correct late frame remembered')
