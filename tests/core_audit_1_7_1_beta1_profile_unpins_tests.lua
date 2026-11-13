-- 1.7.1-beta2: the 1.7.1-beta1 audit's own probe (currency/profile_unpins.lua), unchanged. Evidence and the report:
-- docs/plugins/audit-1.7.1-beta1/.
;(function()
local function boot(char,account,picks)
 package.loaded.mock=nil;local M=require('mock')
 _G.BagSmithCharDB=char or {version=1};_G.BagSmithDB=account or {version=2,chars={},cache={},profiles={Default={}}}
 M.backpackPicks=picks or {1901,1902}
 C_CurrencyInfo.GetCurrencyInfo=function(id) return {name='Currency '..id,quantity=9,iconFileID=8,quality=1} end
 local n=M.loadAddon('BagSmith');M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');n.Window:Show()
 return n,M
end
local function fav(n,id) return n.Currency:IsFavorite('c:'..id) end
local n,M=boot()
n.Currency:ToggleFavorite('c:1901')
check(n.db.blizzUnpinned[1901] and not fav(n,1901),'unpin recorded')
local code=n.Share:Export();local decoded=n.Share:Decode(code)
check(decoded.blizzUnpinned[1901] and decoded.fav[1]=='c:1902','share code roundtrip carries pins and unpins')
local imported=n.Share:Import(code,'Shared');n.Profiles:Use(imported)
check(n.db.blizzUnpinned[1901] and not fav(n,1901),'share import preserves suppression')
local account,char=BagSmithDB,BagSmithCharDB
n,M=boot(nil,account)
check(n.db.blizzUnpinned[1901] and not fav(n,1901),'new character respects imported profile suppression')
n.Currency:ToggleFavorite('c:1901')
check(not n.db.blizzUnpinned[1901] and fav(n,1901),'repin clears imported suppression')
n.Profiles:Use('Default')
check(n.db.blizzUnpinned[1901] and not fav(n,1901),'import mutation independent from source')
n.Profiles:Use('Copy')
check(n.db.blizzUnpinned[1901],'profile creation copies suppression')
n.Currency:ToggleFavorite('c:1901');n.Profiles:Use('Default')
check(n.db.blizzUnpinned[1901] and not fav(n,1901),'new profile deep copy independent')
n.Profiles:CopyFrom('Copy')
check(not n.db.blizzUnpinned[1901] and fav(n,1901),'CopyFrom replaces both pins and suppression')
n.Currency:ToggleFavorite('c:1901');n.Profiles:Reset()
check(next(n.db.blizzUnpinned)==nil and #n.db.fav==0,'reset removes suppression and pins')
n.Window:Hide();n.Window:Show()
check(not fav(n,1901),'reset does not clear per-character seen')
account=BagSmithDB;n,M=boot(nil,account)
check(fav(n,1901) and fav(n,1902),'new character may import after explicit profile reset')
-- Pin restoration of one pick does not clear unrelated suppression.
n.Currency:ToggleFavorite('c:1901');n.Currency:ToggleFavorite('c:1902')
M.backpackPicks={1901};check(n.Currency:ImportBlizzard()==1,'import current pick only')
check(not n.db.blizzUnpinned[1901] and n.db.blizzUnpinned[1902],'import preserves unrelated unpins')
account,char=BagSmithDB,BagSmithCharDB;n,M=boot(char,account)
check(fav(n,1901) and not fav(n,1902) and n.db.blizzUnpinned[1902],'reload preserves partial restore')
n,M=boot(nil,account)
check(fav(n,1901) and not fav(n,1902),'other character partial restore respected')
-- Manual item pins do not create wallet suppression; unrelated preferences unaffected.
for _,key in ipairs({'i:2589','i:1901'}) do n.Currency:ToggleFavorite(key);n.Currency:ToggleFavorite(key) end
check(n.db.blizzUnpinned[2589]==nil and n.db.blizzUnpinned[1901]==nil,'item unpins not wallet suppression')
-- Legacy prior-version removals cannot be reconstructed, explicitly documented limit.
n,M=boot({version=1,blizzPicksSeen={[1901]=true}},nil,{1901})
check(not fav(n,1901),'legacy character removal remains absent')
account=BagSmithDB;n,M=boot(nil,account,{1901})
check(fav(n,1901),'legacy unrecorded removal may repin for other character')
n.Currency:ToggleFavorite('c:1901');account=BagSmithDB;n,M=boot(nil,account,{1901})
check(not fav(n,1901),'new removal then protects other characters')
-- Validation on saved profiles and share-import path.
for _,bad in ipairs({true,42,'bad'}) do
 n,M=boot(nil,{version=2,chars={},cache={},profiles={Default={blizzUnpinned=bad}}},{1901})
 check(type(n.db.blizzUnpinned)=='table' and fav(n,1901),'malformed saved suppression repaired '..tostring(bad))
end
n,M=boot(nil,nil,{})
local name=n.Profiles:Import('Validation',{fav={},blizzUnpinned={bad=true,['1901']=true,[1901]='yes',[1902]=true}})
n.Profiles:Use(name);M.backpackPicks={1901,1902};n.Window:Hide();n.Window:Show()
check(fav(n,1901) and not fav(n,1902),'import validator preserves only numeric true suppression')
check(n.db.blizzUnpinned.bad==nil and n.db.blizzUnpinned['1901']==nil,'import invalid keys discarded')
-- Many characters sharing one profile must never reintroduce suppression.
for index=1,25 do
 account=BagSmithDB;n,M=boot(nil,account,{1901,1902})
 check(fav(n,1901) and not fav(n,1902),'shared character '..index)
 check(n.cdb.blizzPicksSeen[1902] and n.db.blizzUnpinned[1902],'blocked pick marked seen '..index)
end
end)()
