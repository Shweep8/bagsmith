-- 1.7.0: the 1.7.0-beta14 audit's own probe (currency/currency_lifecycle.lua), kept in the suite; one check turned round
-- by design in 1.7.1-beta1 (marked). Evidence and the
-- report: docs/plugins/audit-1.7.0-beta14/.
;(function()
local function boot(char, account, picks)
 package.loaded.mock=nil
 local M=require('mock')
 _G.BagSmithCharDB=char or {version=1, firstSeen={}}
 _G.BagSmithDB=account or {version=2, chars={},cache={},profiles={Default={fav={}}}}
 M.backpackPicks=picks or {}
 C_CurrencyInfo.GetCurrencyInfo=function(id) return {name='Currency '..id,quantity=9,iconFileID=8,quality=1} end
 local n=M.loadAddon('BagSmith'); M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD')
 return n,M
end
local function drain(M) for _=1,8 do M.runTimers() end end
local function open(n) n.Window:Hide();n.Window:Show() end
local function fav(n,id) return n.Currency:IsFavorite('c:'..id) end
local n,M=boot(nil,nil,{1901,1902,1901})
open(n)
check(fav(n,1901) and fav(n,1902) and #n.db.fav==2,'first open imports duplicates once')
check(n.Window.main.favShown==2,'first draw shows both before timer')
check(n.cdb.blizzPicksSeen[1901] and n.cdb.blizzPicksSeen[1902],'first draw saved seen')
for i=1,10 do open(n);M.fire('CURRENCY_DISPLAY_UPDATE');drain(M) end
check(#n.db.fav==2,'repeated opens/events idempotent')
n.Currency:ToggleFavorite('c:1901')
M.backpackPicks={1902};M.fire('CURRENCY_DISPLAY_UPDATE');drain(M)
M.backpackPicks={1901,1902};open(n);M.fire('CURRENCY_DISPLAY_UPDATE');drain(M)
check(not fav(n,1901),'untick/retick does not override manual unpin')
-- New profile intentionally copies current settings; previous seen data remains character-wide.
n.Profiles:Use('Copy')
check(not fav(n,1901) and fav(n,1902),'new profile copies pins not Blizzard picks')
M.backpackPicks={1901,1902,1903};open(n)
check(fav(n,1903),'new pick goes to currently active profile')
n.Profiles:Use('Default');open(n)
check(not fav(n,1903) and not fav(n,1901),'switch does not import picks already seen in another profile')
check(n.Currency:ImportBlizzard()==2 and fav(n,1901) and fav(n,1903),'manual import restores absent current picks to profile')
check(n.Currency:ImportBlizzard()==0,'manual import idempotent')
n.Profiles:Reset();open(n)
check(#n.db.fav==0,'reset profile does not reset character seen')
check(n.cdb.blizzPicksSeen[1903],'seen survives profile reset')
check(n.Currency:ImportBlizzard()==3,'button restores picks after reset')
local imported=n.Profiles:Import('Empty',{fav={}});n.Profiles:Use(imported);open(n)
check(#n.db.fav==0,'imported empty profile remains empty after open')
-- Character reload preserves removals; new character can populate a shared profile.
n.Currency:ImportBlizzard();n.Currency:ToggleFavorite('c:1901')
local account,char=BagSmithDB,BagSmithCharDB
n,M=boot(char,account,{1901,1902,1903});open(n)
check(not fav(n,1901),'reload preserves user unpin')
n,M=boot(nil,account,{1901,1902,1903});open(n)
-- (1.7.1-beta1, by design: the audit's advisory, option 2) an unpin is remembered in the profile, so a new character
-- sharing it doesn't pin it again (its own seen set still records the pick)
check(not fav(n,1901) and n.cdb.blizzPicksSeen[1901],'new character sharing the profile does not repin a currency unpinned there')
-- No answer/API: do not mark seen. Answer arriving with bags closed is imported by event.
n,M=boot(nil,nil,{})
local get=C_CurrencyInfo.GetBackpackCurrencyInfo
C_CurrencyInfo.GetBackpackCurrencyInfo=nil
check(n.Currency:SyncBlizzardPicks()==0 and next(n.cdb.blizzPicksSeen)==nil,'absent API is inert')
C_CurrencyInfo.GetBackpackCurrencyInfo=get
open(n);n.Window:Hide();M.backpackPicks={1901}
M.fire('CURRENCY_DISPLAY_UPDATE');drain(M)
check(fav(n,1901) and n.cdb.blizzPicksSeen[1901],'late API result imports with bags closed')
open(n);check(n.Window.main.favShown==1,'late pick visible on next draw')
-- Disabling replacement is not disabling currency integration (no auto-import opt-out exists).
n:Set('replaceBlizzardBags',false);n.Window:Hide();M.backpackPicks={1901,1902}
M.fire('CURRENCY_DISPLAY_UPDATE');drain(M)
check(fav(n,1902),'replacement disabled still processes currency events')
-- A full addon disable cannot run code; simulate accumulated choices on the next addon load.
account,char=BagSmithDB,BagSmithCharDB
n,M=boot(char,account,{1901,1902,1903});open(n)
check(fav(n,1903),'next load imports pick made while addon was disabled')
-- Saved-data validation: malformed container and malformed entries; numeric-only predicate is existing common validator.
for _,bad in ipairs({'bad',true,42}) do
 n,M=boot({version=1,blizzPicksSeen=bad},nil,{1901});open(n)
 check(type(n.cdb.blizzPicksSeen)=='table' and fav(n,1901),'malformed seen container repairs '..tostring(bad))
end
n,M=boot({version=1,blizzPicksSeen={[1901]=true,['1902']=true,[1903]='true',bad=true,[-1]=true,[1.5]=true}},nil,{1901,1902,1903});open(n)
check(not fav(n,1901) and fav(n,1902) and fav(n,1903),'only numeric true saved values suppress picks')
check(n.cdb.blizzPicksSeen.bad==nil and n.cdb.blizzPicksSeen['1902']==nil,'invalid strings removed')
check(n.cdb.blizzPicksSeen[-1] and n.cdb.blizzPicksSeen[1.5],'validator permits irrelevant negative/fractional numeric keys (observation)')
-- Ordering and duplicate stress, only valid API IDs. User order kept; new picks appended once.
for count=0,20 do
 local picks={};for id=1,count do picks[#picks+1]=2000+id end
 n,M=boot(nil,{version=2,chars={},cache={},profiles={Default={fav={'i:2589','c:1999'}}}},picks);open(n)
 check(#n.db.fav==count+2,'count '..count)
 check(n.db.fav[1]=='i:2589' and n.db.fav[2]=='c:1999','existing order '..count)
 for id=1,count do check(n.db.fav[id+2]=='c:'..(2000+id),'append order '..count..':'..id) end
 for id=1,count do n.Currency:ToggleFavorite('c:'..(2000+id)) end
 M.fire('CURRENCY_DISPLAY_UPDATE');drain(M);open(n)
 check(#n.db.fav==2,'unpin all durable '..count)
 check(n.Currency:ImportBlizzard()==count,'explicit restore count '..count)
end
print('Independent currency lifecycle matrix complete')
end)()
