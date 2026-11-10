-- 1.6.0-beta6: the 1.6.0-beta5 audit's own probe (price_source_probe.lua; one control adapted, marked), kept in the suite so its findings stay fixed. It failed on
-- beta5 as the audit reported; it must pass from beta6 on. Evidence and the report: docs/plugins/audit-1.6.0-beta5/.
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
 local n=M.loadAddon('BagSmith')
 M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers(); M.runTimers()
 n.Disenchant:Show(); M.runTimers()
 M.fire('LOOT_OPENED'); M.runTimers(); M.runTimers()
 return n,M
end
local function firstShown(rows) for _,r in ipairs(rows or {}) do if r:IsShown() then return r.name.text,r.value.text end end end
for _,skin in ipairs({'modern','classic'}) do
 local n,M=boot(skin); local D=n.Disenchant; local R=n.MakeRoom; local f=R.frame
 check(f and f:IsShown() and D.current and D.current.verdict=='de','setup '..skin..': helpers open, Disenchant recommended')
 local before,beforeValue=firstShown(f.destroyRows)
 check(before=='Sturdy Boots','setup '..skin..': Boots lowest with Auctionator')
 n:Set('priceSource','blackthornes'); M.runTimers(); M.runTimers()
 local fresh=D:Entries()[1]; local _,ds=R:Suggestions(R:Waiting()); local after,afterValue=firstShown(f.destroyRows)
 print(('OBS %s source=%s DE shown=%s live=%s AH shown=%s live=%s MR shown=%s liveFirst=%s'):format(skin,n.AH:Source(),D.current.verdict,fresh.verdict,tostring(D.current.ah),tostring(fresh.ah),after,ds[1].rec.name))
 check(D.current.verdict==fresh.verdict and D.current.ah==fresh.ah,'DE repaints recommendation and prices after Price Source setting changes ('..skin..')')
 check(after==ds[1].rec.name and afterValue~=beforeValue,'Loot Helper repaints rank and prices after Price Source setting changes ('..skin..')')
 -- The stale selected item still meets the broad lower-than-loot rule. The guard does not check cheapest order.
 local clicked=f.act:GetScript('OnClick'); clicked(f.act)
 print(('OBS %s stale default click removedBoots=%s cheaperTrinketRemains=%s'):format(skin,tostring(M.bags[0][1]==nil),tostring(M.bags[0][2]~=nil)))
 check(M.bags[0][1]~=nil,'A source switch must not leave a stale lowest-value default that destroys the newly more valuable Boots ('..skin..')')
 -- Profile changes use a nil SETTINGS_CHANGED key and DO repaint both helpers.
 n,M=boot(skin); D=n.Disenchant; R=n.MakeRoom
 n.Profiles:Use('Other'); M.runTimers(); M.runTimers()
 fresh=D:Entries()[1]; local name=firstShown(R.frame.destroyRows)
 check(D.current.verdict==fresh.verdict and D.current.ah==fresh.ah and name=='Common Trinket','control: profile switch correctly repaints both helpers ('..skin..')')
 -- A price with no own-scan age must not be represented as a known old scan.
 n.db.cols={'ah'}; local lines={}; local tip={AddDoubleLine=function() end,AddLine=function(self,s) lines[#lines+1]=s end}
 n.AH:AddTooltipLines(tip,{itemID=7001,link='item:7001',count=1})
 print('OBS '..skin..' no-age tooltip='..table.concat(lines,' | '))
 check(not table.concat(lines,' '):find('Over 3 weeks old',1,true),'A Blackthornes price with unknown age is not labeled Over 3 weeks old ('..skin..')')
end
-- Source boundary probes: invalid return types, finite values, age conversion, selection, exceptions.
local n,M=boot('modern'); n:Set('priceSource','blackthornes'); local rec={itemID=7001,link='item:7001',count=1}
for _,v in ipairs({'500',false,0,-1,0/0}) do BlackthornesTS_API.GetPrice=function() return v end; check(n.AH:Price(rec)==nil,'BTS invalid price discarded '..tostring(v)) end
BlackthornesTS_API.GetPrice=function() error('source failure') end; check(n.AH:Price(rec)==nil,'BTS source exception discarded')
BlackthornesTS_API.GetPrice=function() return math.huge end
print('OBS BTS positive infinity price='..tostring(n.AH:Price(rec)))
check(n.AH:Price(rec)==nil,'Non-finite positive price is discarded')
BlackthornesTS_API.GetPrice=function() return 123 end
for _,c in ipairs({{0,0},{86399,0},{86400,1},{21*86400,21},{22*86400,false},{-1,false}}) do
 BlackthornesTS_API.GetPriceAge=function() return c[1] end; local age=n.AH:Age(rec); check(age==(c[2] or nil),'age boundary '..c[1])
end
-- Existing final-check safety controls under the new source. These must pass even though display refresh fails.
for _,skin in ipairs({'modern','classic'}) do
 local n,M=boot(skin); local R=n.MakeRoom
 BlackthornesTS_API.GetPrice=function(v) local id=type(v)=='number' and v or tonumber(tostring(v):match('item:(%d+)'));return id==7001 and 2000000 or (id==9001 and 1000000 or 1) end
 n:Set('priceSource','blackthornes');M.runTimers()
 -- (by design in beta6: the source change now refreshes the panel, so the Boots, worth more than the loot, are no longer
 -- offered; the action is for the Trinket, the cheapest now, and destroying it is right. The audit's control asked that
 -- nothing at all be destroyed, which held on beta5 only because the stale Boots offer was refused. The guard itself is
 -- checked directly: the Boots' old offer, from before the switch, is refused.)
 local stale;for _,r in ipairs(n.items) do if r.itemID==7001 then stale=R:Offer(r,false,'priced',600) end end
 R.frame.act:GetScript('OnClick')(R.frame.act)
 check(M.bags[0][1]~=nil,'control: final guard refuses price crossing above waiting loot ('..skin..')')
 check(not R:StillOk(stale) and not R:Destroy(stale,true) and M.bags[0][1]~=nil,'control: the Boots offer from before the switch is refused at the click ('..skin..')')
 n,M=boot(skin); R=n.MakeRoom
 local rec;for _,r in ipairs(n.items) do if r.itemID==7001 then rec=r end end
 local offer=R:Offer(rec,false,'priced')
 local real=C_Item.GetItemInfo
 C_Item.GetItemInfo=function(v) local id=tonumber(tostring(v):match('item:(%d+)')) or v;if id==9001 then return 'Waiting Loot','item:9001',1,1,0,'Misc','Misc',1,'',1,0,15,0 end;return real(v) end
 BlackthornesTS_API.GetPrice=function() return nil end
 n:Set('priceSource','blackthornes');M.runTimers()
 local ok,why=R:StillOk(offer)
 check(not ok and why=='basis','control: priced-to-no-price source change invalidates original offer ('..skin..')')
 check(not R:Destroy(offer,true) and M.bags[0][1]~=nil,'control: retained confirmed offer cannot bypass basis guard ('..skin..')')
 local entry=n.Disenchant:Entries()[1]
 check(entry.mats==nil and entry.verdict=='unknown','control: missing BTS material prices stay conservative ('..skin..')')
end
