-- 1.6.0-beta9: the 1.6.0-beta8 audit's own probe (independent/layout_migration_extension.lua, unchanged), kept in the suite. Evidence and the report:
-- docs/plugins/audit-1.6.0-beta8/.
-- Independent beta8 settings persistence and enabled-column matrix. No addon source writes.
local ALL='t,age,v,ah,w,sl,rq,il,bd,fv,cc,jk'
local function boot(skin,prof,saved)
 package.loaded.mock=nil; local M=require('mock')
 _G.BagSmithCharDB={version=1,firstSeen={}}
 _G.BagSmithDB=saved or {version=2,chars={},cache={},profiles={Default=prof or {}}}
 BagSmithDB.profiles.Default.skin=skin
 _G.Auctionator={API={v1={GetAuctionPriceByItemID=function()return 100 end,GetAuctionPriceByItemLink=function()return 100 end}}};_G.BlackthornesTS_API=nil
 local n=M.loadAddon(AUDIT_CORE or 'BagSmith');M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers();n.Window:Show();M.runTimers();M.runTimers()
 return n,M
end
local function seq(a)return table.concat(a,',') end
for _,skin in ipairs({'modern','classic'})do
 local cases={
 {label='missing',p={},bags=ALL,bank=ALL},
 {label='legacy',p={colAside={'t','age','v','ah'},bankColAside={'ah','t'}},bags='t,age,v,ah',bank='ah,t'},
 {label='empty',p={colAside={},bankColAside={}},bags='',bank=''},
 {label='Qty only',p={colAside={'c'},bankColAside={'c'}},bags='',bank=''},
 {label='mixed invalid',p={colAside={'n','c','t','t','junk','ah'},bankColAside={'jk','c','n','jk'}},bags='t,ah',bank='jk'},
 }
 for _,c in ipairs(cases)do
  local n,M=boot(skin,c.p)
  check(seq(n.db.colAside)==c.bags and seq(n.db.bankColAside)==c.bank,skin..' load '..c.label..': independent lists/migration')
  local saved=n.Copy(BagSmithDB);n,M=boot(skin,nil,saved)
  check(seq(n.db.colAside)==c.bags and seq(n.db.bankColAside)==c.bank,skin..' reload '..c.label)
  local profile=n.Profiles:Import('probe',{colAside={'c','age','v'},bankColAside={},deAhMargin=0.35,deLeveling='never'})
  n.Profiles:Use(profile);M.runTimers()
  check(seq(n.db.colAside)=='age,v' and seq(n.db.bankColAside)=='' and n.db.deAhMargin==0.35 and n.db.deLeveling=='never',skin..' import '..c.label)
  n.Profiles:Use('Default');M.runTimers()
  check(seq(n.db.colAside)==c.bags and seq(n.db.bankColAside)==c.bank,skin..' switch back '..c.label)
  n.Profiles:Use('Copy');n.Profiles:CopyFrom(profile);M.runTimers()
  check(seq(n.db.colAside)=='age,v' and seq(n.db.bankColAside)=='',skin..' copy '..c.label)
  n:Set('colAside',{'c','w','age'});n:Set('bankColAside',{'c','fv'});M.runTimers()
  check(seq(n.db.colAside)=='w,age' and seq(n.db.bankColAside)=='fv',skin..' runtime validation '..c.label)
  n.Profiles:Reset();M.runTimers()
  check(seq(n.db.colAside)==ALL and seq(n.db.bankColAside)==ALL and n.db.deAhMargin==0.2 and n.db.deLeveling=='auto',skin..' reset '..c.label)
 end
end
-- Sweep every enabled-column subset (8192), both windows, provider on/off.
-- Mix legal 30..400 px widths and rotating orders; deterministic alternate allowed-drop sets.
-- This complements the earlier all-enabled/drop-subset matrix, it is not every Cartesian combination.
local configs=0
for _,provider in ipairs({false,true})do
 local n,M=boot('modern')
 if not provider then _G.Auctionator=nil;n.AH:CheckSource();M.runTimers()end
 local all={};for _,c in ipairs(n.COLS)do all[#all+1]=c[1]end
 local original=n.Copy(n.db.colOrder)
 for mask=0,2^#all-1 do
  local enabled,aside,widths={},{},{}
  for i,k in ipairs(all)do
   if math.floor(mask/2^(i-1))%2==1 then enabled[#enabled+1]=k end
   if (mask+i*7)%3~=0 then aside[#aside+1]=k end
   widths[k]=30+(mask*13+i*53)%371
  end
  local order={};local rotation=mask%#original
  for i=1,#original do order[i]=original[(i+rotation-1)%#original+1]end
  n.db.cols=enabled;n.db.bankCols=enabled;n.db.colAside=aside;n.db.bankColAside=aside;n.db.colWidths=widths;n.db.bankColWidths=widths;n.db.colOrder=order;n.db.bankColOrder=order
  for _,V in ipairs({n.Window.main,n.Window.bank})do
   local minimum=n.View.MinWidthFor(V.isBank);V.scroll.w=minimum-46+(mask%3)*97;V.trustedRowWidth=nil
   local plan,w=V:ColumnPlan();local got={};local ok=true;local edge=0
   for _,p in ipairs(plan)do got[p.key]=true;ok=ok and p.colW>=(p.key=='n' and 90 or 30);edge=p.colX+p.colW end
   ok=ok and edge<=w and got.n
   if n.IndexOf(enabled,'c')then ok=ok and got.c end
   for _,k in ipairs(enabled)do if (k=='c' or not n.IndexOf(aside,k))and(k~='ah'or provider)then ok=ok and got[k] end end
   for _,k in ipairs(plan.dropped)do ok=ok and k~='c' and k~='n' end
   check(ok,'enabled subset '..mask..' provider '..tostring(provider)..' '..V.name..': fit, minima, Item/Qty, protected columns')
   configs=configs+1
  end
 end
end
print('ENABLED_COLUMN_CONFIGS',configs)
