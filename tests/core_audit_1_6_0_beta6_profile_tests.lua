-- 1.6.0-beta7: the 1.6.0-beta6 audit's own probe (profile_price_probe.lua, unchanged), kept in the suite so its findings stay fixed. It failed on
-- beta6 as the audit reported; it must pass from beta7 on. Evidence and the report: docs/plugins/audit-1.6.0-beta6/.
-- Independent release audit. Run from the unmodified candidate repository with tools/run_tests.py.
-- This file intentionally fails unmet requirements; it never invokes native inventory APIs.
local function boot(skin)
 package.loaded.mock=nil
 local M=require('mock')
 for b=0,5 do M.sizes[b]=0 end; M.sizes[0]=2
 M.maxStack={[7001]=1,[7002]=1,[9001]=1}
 M.put(0,1,{id=7001,name='Sturdy Boots',q=2,count=1,class=4,subclass=1,price=500,ilvl=23,equip='INVTYPE_FEET'})
 M.put(0,2,{id=7002,name='Common Trinket',q=1,count=1,class=15,subclass=0,price=5})
 _G.BagSmithCharDB={version=1,firstSeen={}}
 _G.BagSmithDB={version=2,chars={},cache={},profiles={Default={skin=skin,deEnabled=true,makeRoom=true,priceSource='auctionator',makeRoomValue='ah'},Other={skin=skin,deEnabled=true,makeRoom=true,priceSource='blackthornes',makeRoomValue='ah'}}}
 _G.IsSpellKnown=function(id) return id==13262 end
 _G.GetNumSkillLines=function() return 1 end
 _G.GetSkillLineInfo=function() return 'Enchanting',false,nil,150 end
 _G.RegisterStateDriver=function() end; _G.UnregisterStateDriver=function() end
 _G.UnitClass=function() return 'Warrior','WARRIOR' end
 local function idOf(v) return type(v)=='number' and v or tonumber(tostring(v):match('item:(%d+)')) end
 local function ap(v) local id=idOf(v); if id==7001 then return 600 elseif id==7002 then return 1000 elseif id==9001 then return 1000000 else return 10000 end end
 local function bp(v) local id=idOf(v); if id==7001 then return 100000 elseif id==7002 then return 1 elseif id==9001 then return 1000000 else return 10 end end
 _G.Auctionator={API={v1={GetAuctionPriceByItemLink=function(c,l) return ap(l) end,GetAuctionPriceByItemID=function(c,id) return ap(id) end}}}
 _G.BlackthornesTS_API={version=1,GetPrice=bp,GetPriceAge=function() return nil end}
 local real=C_Item.GetItemInfo
 C_Item.GetItemInfo=function(v) if idOf(v)==9001 then return 'Waiting Loot','item:9001',1,1,0,'Misc','Misc',1,'',1,1000000,15,0 end; return real(v) end
 _G.GetNumLootItems=function() return 1 end
 _G.GetLootSlotType=function() return 1 end
 _G.GetLootSlotLink=function() return '|Hitem:9001:0|h[Waiting Loot]|h' end
 _G.GetLootSlotInfo=function() return 'icon','Waiting Loot',1,nil,1 end
 _G.LootSlot=function() M.lootRequested=true end
 C_Container.PickupContainerItem=function(bag,slot) local it=M.bags[bag] and M.bags[bag][slot]; M.cursorItem=it and it.id; M.cursorFrom={bag,slot} end
 _G.ClearCursor=function() M.cursorItem=nil; M.cursorFrom=nil end
 _G.DeleteCursorItem=function() if M.cursorFrom then M.bags[M.cursorFrom[1]][M.cursorFrom[2]]=nil end; M.cursorItem=nil; M.deleted=(M.deleted or 0)+1 end
 local n=M.loadAddon(AUDIT_CORE or 'BagSmith')
 M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers(); M.runTimers()
 n.Disenchant:Show(); M.runTimers()
 M.fire('LOOT_OPENED'); M.runTimers(); M.runTimers()
 return n,M
end
local function firstShown(rows) for _,r in ipairs(rows or {}) do if r:IsShown() then return r.name.text,r.value.text end end end

for _,skin in ipairs({'modern','classic'}) do
 local n,M=boot(skin); local R=n.MakeRoom
 local raw=n.Copy(n.db);raw.makeRoomValue='vendor'
 local prof=n.Profiles:Import('VendorRank',raw)
 print('OBS profile before',skin,R.chosen.label,R.frame.foot.text)
 n.Profiles:Use(prof);M.runTimers();M.runTimers()
 local _,ds=R:Suggestions(R:Waiting())
 print('OBS profile after',skin,R.chosen.label,R.frame.foot.text,firstShown(R.frame.destroyRows),ds[1].rec.name)
 check(R.chosen.row.name.text==ds[1].rec.name,'Profile rank change clears automatic selection ('..skin..')')
 R.frame.act:GetScript('OnClick')(R.frame.act)
 print('OBS profile click',skin,'Boots retained',M.bags[0][1]~=nil,'Trinket retained',M.bags[0][2]~=nil)
 check(M.bags[0][1]~=nil,'Profile rank change does not retain more costly Boots as default ('..skin..')')
 n,M=boot(skin);R=n.MakeRoom;n:Set('makeRoomValue','vendor');M.runTimers();M.runTimers()
 check(R.chosen.row.name.text=='Common Trinket','Direct rank setting chooses cheapest ('..skin..')')
 n,M=boot(skin); R=n.MakeRoom
 local rec;for _,r in ipairs(n.items) do if r.itemID==7001 then rec=r end end
 local v=R:Values(rec.itemID,rec.count,rec.link)
 local o=R:Offer(rec,false,'priced',R:Rank(v))
 Auctionator.API.v1.GetAuctionPriceByItemLink=function(c,v) local id=tonumber(tostring(v):match('item:(%d+)'));return id==7001 and 900 or 1000000 end
 Auctionator.API.v1.GetAuctionPriceByItemID=function(c,id) return id==7001 and 900 or 1000000 end
 local ok,why=R:StillOk(o)
 check(not ok and why=='price','Fresh provider value invalidates retained offer ('..skin..')')
 check(not R:Destroy(o,true) and M.bags[0][1]~=nil,'Confirmation cannot bypass price guard ('..skin..')')
end
