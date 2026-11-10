-- 1.6.0-beta8: the 1.6.0-beta7 audit's own probe (independent/empty_options_selection_probe.lua; its last check adapted, marked), kept in the suite. Evidence and the report:
-- docs/plugins/audit-1.6.0-beta7/.
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
 local n,M=boot(skin);local R=n.MakeRoom
 -- Explicitly pick the costlier item (the item must exist to select it).
 for _,r in ipairs(R.frame.destroyRows) do if r.name.text=='Common Trinket' then r.onPick() end end
 print('OBS before no-options',skin,R.chosen.label,tostring(R.selPicked))
 -- No eligible suggestions, then both return. Update through actual marks signal.
 for _,r in ipairs(n.items) do if r.itemID==7001 or r.itemID==7002 then n.Marks:ToggleFavorite(r) end end
 n:Fire('ITEMS_CHANGED')
 print('OBS no-options',skin,tostring(R.chosen),tostring(R.selPicked))
 check(R.chosen==nil,skin..' no options fixture established')
 for _,r in ipairs(n.items) do if r.itemID==7001 or r.itemID==7002 then n.Marks:ToggleFavorite(r) end end
 n:Fire('ITEMS_CHANGED')
 print('OBS after no-options',skin,R.chosen.label,tostring(R.selPicked))
 check(R.chosen.row.name.text=='Sturdy Boots' and not R.selPicked,skin..' no-longer-offered manual choice should not revive after empty options')
 R.frame.act:GetScript('OnClick')(R.frame.act)
 print('OBS click',skin,'Boots retained',M.bags[0][1]~=nil,'Trinket retained',M.bags[0][2]~=nil)
 -- (adapted by design in beta8, the A1 fix: with the pick ended, the action names the Boots, the cheapest, and the click
 -- destroys that item and nothing else; the audit's line recorded beta7's revived Trinket)
 check(M.bags[0][1]==nil and M.bags[0][2]~=nil,skin..' actual click deletes the displayed item (the Boots) only')
end
