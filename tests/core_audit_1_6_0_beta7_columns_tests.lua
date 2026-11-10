-- 1.6.0-beta8: the 1.6.0-beta7 audit's own probe (column_minimum_probe.lua, unchanged), kept in the suite. Evidence and the report:
-- docs/plugins/audit-1.6.0-beta7/.
-- Independent beta7 enforcement and geometry probes; unchanged addon source.
local function boot(skin, provider)
 package.loaded.mock=nil; local M=require('mock')
 _G.BagSmithCharDB={version=1,firstSeen={}}
 _G.BagSmithDB={version=2,chars={},cache={},profiles={Default={skin=skin,view='list',sizeMode='fixed',fixW=440,bankW=500,grp='type'},Other={skin=skin,view='list',sizeMode='fixed',fixW=440,bankW=500,grp='type'}}}
 _G.Auctionator=provider and {API={v1={GetAuctionPriceByItemID=function()return 1 end,GetAuctionPriceByItemLink=function()return 1 end}}} or nil; _G.BlackthornesTS_API=nil
 local n=M.loadAddon(AUDIT_CORE or 'BagSmith');M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers();n.Window:Show();M.runTimers();M.runTimers()
 return n,M
end
local function allCols(n) local a={};for _,k in ipairs(n.db.colOrder)do if k~='n' then a[#a+1]=k end end;return a end
local function fit(n,V,label)
 V.scroll.w=V.frame:GetWidth()-46; V.trustedRowWidth=nil
 local plan,width=V:ColumnPlan(); local endcol=plan[#plan]; local edge=endcol.colX+endcol.colW
 check(edge<=width,label..': geometry fits ('..edge..' <= '..width..')')
end
for _,skin in ipairs({'modern','classic'})do
 local n,M=boot(skin,true);local all=allCols(n)
 -- Each public mutation route, while windows are hidden as well as shown.
 n.Window.main:Hide(); n.Window.bank:Hide()
 n:Set('cols',all);n:Set('colAside',{});n:Set('bankCols',n.Copy(all));n:Set('bankColAside',{});M.runTimers()
 for _,V in ipairs({n.Window.main,n.Window.bank})do
  check(V.frame:GetWidth()==526 and V.frame.resizeBounds[1]==526,skin..' hidden '..V.name..': widen and enforce 526')
  fit(n,V,skin..' hidden '..V.name)
 end
 n.Window.main:Show();M.runTimers();fit(n,n.Window.main,skin..' open kept columns')
 -- A profile changes all preferences with a nil-key signal.
 n.Profiles:Use('Other');M.runTimers();M.runTimers()
 check(n.Window.main.frame.resizeBounds[1]==440 and n.Window.bank.frame.resizeBounds[1]==500,skin..': profile restores base bounds')
 n.Profiles:Use('Default');M.runTimers();M.runTimers()
 check(n.Window.main.frame.resizeBounds[1]==526 and n.Window.bank.frame.resizeBounds[1]==526,skin..': profile enforces large bounds')
 fit(n,n.Window.main,skin..' profile width')
 -- Provider disappears and then is loaded late. Same column settings.
 _G.Auctionator=nil;n.AH:CheckSource();M.runTimers()
 check(n.Window.main.frame.resizeBounds[1]==496 and n.Window.bank.frame.resizeBounds[1]==500,skin..': missing AH excludes only that column')
 _G.Auctionator={API={v1={GetAuctionPriceByItemID=function()return 1 end,GetAuctionPriceByItemLink=function()return 1 end}}}
 M.fire('ADDON_LOADED','Auctionator');M.runTimers()
 check(n.Window.main.frame.resizeBounds[1]==526 and n.Window.bank.frame.resizeBounds[1]==526,skin..': late AH restores min')
 -- Multiple direct settings in combat: no protected width call, latest preference applies after.
 n:Set('colAside',{'t','age','v','ah'});n:Set('bankColAside',{'t','age','v','ah'});M.runTimers()
 local blocked={}
 for _,V in ipairs({n.Window.main,n.Window.bank})do for _,method in ipairs({'SetWidth','SetResizeBounds'})do
  local old=V.frame[method];if old then V.frame[method]=function(self,...)
   if M.combat then blocked[#blocked+1]=V.name..'.'..method;error('protected width in combat') end
   return old(self,...)
  end end
 end end
 M.combat=true;M.fire('PLAYER_REGEN_DISABLED')
 n:Set('colAside',{});n:Set('bankColAside',{});n:Set('colAside',{'jk'});M.runTimers()
 check(#blocked==0,skin..': combat width mutation safely deferred')
 check(n.Window.main.frame.resizeBounds[1]==440 and n.Window.bank.frame.resizeBounds[1]==500,skin..': bounds remain unchanged in combat')
 M.combat=false;M.fire('PLAYER_REGEN_ENABLED');M.runTimers();M.runTimers()
 check(n.Window.main.frame.resizeBounds[1]==496 and n.Window.bank.frame.resizeBounds[1]==526,skin..': latest combat choices apply independently')
 fit(n,n.Window.main,skin..' post-combat bags');fit(n,n.Window.bank,skin..' post-combat bank')
end
-- Exhaustive Aside subset matrix. All 13 optional columns on, maximum saved widths,
-- Item moved by reversing the normal order. Each permitted
-- drop subset is checked for both windows with and without AH availability.
local configs=0
for _,provider in ipairs({false,true})do
 local n,M=boot('modern',provider);local all=allCols(n)
 n.db.cols=all;n.db.bankCols=n.Copy(all)
 local order={};for i=#n.db.colOrder,1,-1 do order[#order+1]=n.db.colOrder[i] end
 n.db.colOrder=order;n.db.bankColOrder=n.Copy(order)
 for _,k in ipairs(all)do n.db.colWidths[k]=400;n.db.bankColWidths[k]=400 end
 for mask=0,2^#all-1 do
  local aside={};for i,k in ipairs(all)do if math.floor(mask/2^(i-1))%2==1 then aside[#aside+1]=k end end
  n.db.colAside=aside;n.db.bankColAside=aside
  for _,V in ipairs({n.Window.main,n.Window.bank})do
   local min=n.View.MinWidthFor(V.isBank);V.scroll.w=min-46;V.trustedRowWidth=nil
   local plan,width=V:ColumnPlan();local last=plan[#plan];local edge=last.colX+last.colW
   local protected={};for _,k in ipairs(all)do if not n.IndexOf(aside,k) and(k~='ah'or provider)then protected[k]=true end end
   for _,p in ipairs(plan)do protected[p.key]=nil end
   check(edge<=width and next(protected)==nil,'subset '..mask..' provider '..tostring(provider)..' '..V.name..' fits and retains protected columns')
   configs=configs+1
  end
 end
end
print('EXHAUSTIVE_ASIDE_CONFIGS',configs)
