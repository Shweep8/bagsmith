-- 1.6.0-beta7: the 1.6.0-beta6 audit's own probe (narrow_columns_probe.lua; one check adapted, marked), kept in the suite so its findings stay fixed. It failed on
-- beta6 as the audit reported; it must pass from beta7 on. Evidence and the report: docs/plugins/audit-1.6.0-beta6/.
-- Independent beta6 Narrow Windows checks, against untouched candidate and supplied mock.
local function boot(skin)
 package.loaded.mock=nil; local M=require('mock')
 _G.BagSmithCharDB={version=1,firstSeen={}}
 _G.BagSmithDB={version=2,chars={},cache={},profiles={Default={skin=skin,view='list',grp='type'}}}
 _G.Auctionator={API={v1={GetAuctionPriceByItemID=function()return 1 end,GetAuctionPriceByItemLink=function()return 1 end}}}; _G.BlackthornesTS_API=nil
 local n=M.loadAddon(AUDIT_CORE or 'BagSmith');M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers();n.Window:Show();M.runTimers();M.runTimers()
 return n,M
end
for _,skin in ipairs({'modern','classic'}) do
 local n,M=boot(skin)
 local all={};for _,k in ipairs(n.db.colOrder)do if k~='n' then all[#all+1]=k end end
 n:Set('cols',all);n:Set('bankCols',n.Copy(all));n:Set('colAside',{});n:Set('bankColAside',{});M.runTimers();M.runTimers()
 for _,context in ipairs({{n.Window.main,394,'bags'},{n.Window.bank,454,'bank'}}) do
  local V,w,label=unpack(context);V.scroll.w=w;V.trustedRowWidth=nil
  local plan,width=V:ColumnPlan();local last=plan[#plan];local edge=last.colX+last.colW
  print('OBS',skin,label,'row width',width,'column count',#plan,'right edge',edge,'overflow',edge-width,'last column',last.key,'dropped',#plan.dropped)
  check(#plan==#n.db.colOrder and #plan.dropped==0,skin..' '..label..': unticked columns remain planned')
  -- (adapted by design in beta7, Shweep's choice for R3: the window stops narrowing where the kept columns stop fitting,
  -- so a 394/454 row can't occur with every column kept. The check is the same promise at the narrowest row this
  -- configuration allows: the window's own minimum width, less the list's margins and scrollbar lane.)
  check(V.minWidth and V.minWidth>(V.isBank and 500 or 440),skin..' '..label..': keeping every column raises the window minimum ('..tostring(V.minWidth)..')')
  V.scroll.w=V.minWidth-46;V.trustedRowWidth=nil
  plan,width=V:ColumnPlan();last=plan[#plan];edge=last.colX+last.colW
  check(#plan==#n.db.colOrder and #plan.dropped==0 and edge<=width,skin..' '..label..': all unticked columns fit the narrowest row the window allows ('..edge..' in '..width..')')
  V.scroll.w=w;V.trustedRowWidth=nil
  -- Default dropping is the passing control.
  n.db[V.isBank and 'bankColAside' or 'colAside']={'t','age','v','ah'}
  plan,width=V:ColumnPlan();last=plan[#plan]
  check(last.colX+last.colW<=width,skin..' '..label..': default drop list fits same row')
  n.db[V.isBank and 'bankColAside' or 'colAside']={};V.scroll.w=900;V.trustedRowWidth=nil
  plan,width=V:ColumnPlan();last=plan[#plan]
  check(last.colX+last.colW<=width,skin..' '..label..': unticked columns fit wide row')
 end
end
