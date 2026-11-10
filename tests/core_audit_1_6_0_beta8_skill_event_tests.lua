-- 1.6.0-beta9: the 1.6.0-beta8 audit's own probe (independent/skill_event_beta8.lua, unchanged), kept in the suite. Evidence and the report:
-- docs/plugins/audit-1.6.0-beta8/.
-- Independent current-cap transition test through the real SKILL_LINES_CHANGED handler.
for _,skin in ipairs({'modern','classic'})do
 package.loaded.mock=nil;local M=require('mock')
 M.put(0,1,{id=7001,name='Sturdy Boots',q=2,count=1,class=4,subclass=1,price=500,ilvl=23,equip='INVTYPE_FEET'})
 _G.BagSmithCharDB={version=1,firstSeen={}}
 _G.BagSmithDB={version=2,chars={},cache={},profiles={Default={skin=skin,deEnabled=true,deLeveling='auto',deMargin=.1,deAhMargin=.2}}}
 _G.Auctionator={API={v1={GetAuctionPriceByItemLink=function()return 600 end,GetAuctionPriceByItemID=function()return 600 end}}};_G.BlackthornesTS_API=nil
 local skill={rank=149,cap=150}
 _G.IsSpellKnown=function(id)return id==13262 end
 _G.GetNumSkillLines=function()return 1 end
 _G.GetSkillLineInfo=function()return 'Enchanting',false,nil,skill.rank,0,0,skill.cap end
 _G.RegisterStateDriver=function()end;_G.UnregisterStateDriver=function()end
 local n=M.loadAddon(AUDIT_CORE or 'BagSmith');M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers()
 local D=n.Disenchant;D.MatsValue=function()return 600 end;D:Show();M.runTimers()
 for _,state in ipairs({{149,150,true},{150,150,false},{150,225,true},{224,225,true},{225,225,false},{225,300,true},{300,300,false},{150,false,false},{149,false,true}})do
  skill.rank=state[1];skill.cap=state[2]or nil;M.fire('SKILL_LINES_CHANGED');M.runTimers()
  local lv=state[3];local label=skin..' skill event '..skill.rank..'/'..tostring(skill.cap)
  check(D.current and D.current.itemID==7001 and D.current.verdict==(lv and 'de'or'vendor'),label..' reprices verdict')
  check((D.frame.cur.verdict.text:find('(for leveling)',1,true)~=nil)==lv,label..' label agrees')
  check((D.frame.status.text:find('Leveling Enchanting',1,true)~=nil)==lv,label..' note agrees')
  check(D.button:GetAttribute('type')=='spell' and D.button:GetAttribute('target-slot')==1,label..' correct current item still armed')
 end
 check(not n.errorLog or #n.errorLog==0,skin..' skill transition no callback errors')
end
