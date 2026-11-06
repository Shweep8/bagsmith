;(function()
-- 1.4.0-beta7: the 1.4.0-beta6 audit's P2, as the auditor wrote it (audit_beta6_drop_context.lua, adopted with its
-- prints removed): a pending drop check from a refused All Items drop must not act after a view switch or a profile
-- switch. Fails on beta6 (2 checks).
local function boot()
 package.loaded.mock=nil
 local M=require('mock')
 M.sizes[0]=8; for b=1,5 do M.sizes[b]=0 end
 M.put(0,1,{id=2589,name='Linen Cloth',q=1,count=5,class=7,subclass=5,price=1})
 M.put(0,2,{id=117,name='Tough Jerky',q=1,count=5,class=0,subclass=5,price=1})
 M.put(0,3,{id=2592,name='Wool Cloth',q=1,count=3,class=7,subclass=5,price=2})
 _G.BagSmithCharDB={version=1,firstSeen={}}
 _G.BagSmithDB={version=2,chars={},cache={},profiles={Default={skin='modern',emptySlots=true}}}
 local n=M.loadAddon('BagSmith')
 M.fire('ADDON_LOADED','BagSmith'); M.fire('PLAYER_ENTERING_WORLD'); M.runTimers(); M.runTimers()
 n.Window:Show(); M.runTimers(); M.runTimers()
 local V,S=n.Window.main,n.Sections
 local c=S:Create('Audit'); S:SetPinned(c,true); S:Move(2589,c); S:Move(2592,c)
 V:SetPref('grp','none'); V:SetPref('view','icons'); V:SetPref('sort','off'); n:RefreshViews(true)
 local t=n.Buttons:Get(0,2)
 check(t.inLane=='~all','control: target initially belongs to All Items')
 return n,M,V,S,c,t
end
-- Rejected placement queues a watcher. A later valid drop in By Section must remain in its section.
local n,M,V,S,c,t=boot()
M.cursorItem=2589; M.bags[0][2].locked=true
t:GetScript('OnMouseDown')(t,'LeftButton'); t:GetScript('OnClick')(t,'LeftButton')
M.cursorItem=nil; M.bags[0][2].locked=nil
V:SetPref('grp','type'); n:RefreshViews(true)
check(t.inLane=='Consumables','control: same physical target is now in By Section, outside All Items')
M.bags[0][2],M.bags[0][3]=M.bags[0][3],M.bags[0][2]
M.cursorItem=nil
t:GetScript('OnReceiveDrag')(t)
check(S:MovedTo(2592)==c,'control: By Section drop leaves Wool assigned before old timer fires')
M.runTimers()
check(S:MovedTo(2592)==c,'old rejected All Items gesture must not unassign an unrelated later By Section drop')
-- Repeat across real profile activation; the watcher should not edit a different profile.
n,M,V,S,c,t=boot()
local original=n.db
M.cursorItem=2589
t:GetScript('OnMouseDown')(t,'LeftButton'); t:GetScript('OnClick')(t,'LeftButton')
M.cursorItem=nil
n.Profiles:Use('Other')
check(n.db~=original and S:MovedTo(2592)==c,'control: real profile switch retained the separately cloned assignment')
M.bags[0][2],M.bags[0][3]=M.bags[0][3],M.bags[0][2]
M.runTimers()
check(S:MovedTo(2592)==c,'a watcher from the old profile must not mutate the newly active profile')

end)()

;(function()
	-- 1.4.0-beta7: more interleavings. Each pending check belongs to one gesture and one expected item; newer
	-- gestures, other items, and changes that aren't drops end it. A slow placement with nothing else going on works.
	local function boot()
		package.loaded.mock = nil
		local M = require("mock")
		M.sizes[0] = 8; for b = 1, 5 do M.sizes[b] = 0 end
		M.put(0, 1, { id = 2589, name = "Linen Cloth", q = 1, count = 5, class = 7, subclass = 5, price = 1 })
		M.put(0, 2, { id = 117, name = "Tough Jerky", q = 1, count = 5, class = 0, subclass = 5, price = 1 })
		M.put(0, 3, { id = 2592, name = "Wool Cloth", q = 1, count = 3, class = 7, subclass = 5, price = 2 })
		M.put(0, 4, { id = 159, name = "Spring Water", q = 1, count = 3, class = 0, subclass = 5, price = 1 })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", emptySlots = true } } }
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		n.Window:Show(); M.runTimers(); M.runTimers()
		local V, S = n.Window.main, n.Sections
		local c = S:Create("Audit"); S:SetPinned(c, true); S:Move(2589, c); S:Move(2592, c)
		V:SetPref("grp", "none"); V:SetPref("view", "icons"); V:SetPref("sort", "off"); n:RefreshViews(true); M.runTimers()
		return n, M, V, S, c
	end
	local function rowOf(V, id) for _, b in ipairs(V.used or {}) do if b:IsShown() and b.rec and b.rec.itemID == id then return b end end end
	local function settle(M) for _ = 1, 6 do M.runTimers() end end

	-- a newer gesture ends an older pending check
	local n, M, V, S, c = boot()
	local jerky, water = n.Buttons:Get(0, 2), n.Buttons:Get(0, 4)
	M.cursorItem = 2589
	jerky:GetScript("OnMouseDown")(jerky, "LeftButton"); jerky:GetScript("OnClick")(jerky, "LeftButton")   -- refused: nothing moves
	M.cursorItem = nil
	water:GetScript("OnMouseDown")(water, "LeftButton"); water:GetScript("OnClick")(water, "LeftButton")    -- a newer click (a pick-up)
	M.bags[0][2], M.bags[0][1] = M.bags[0][1], M.bags[0][2]   -- then Linen turns up in the Jerky slot by some other means
	settle(M)
	check(S:MovedTo(2589) == c, "after a newer click, the older pending check doesn't act on Linen turning up later")

	-- a different item landing than the one carried changes nothing
	n, M, V, S, c = boot()
	jerky = n.Buttons:Get(0, 2)
	M.cursorItem = 2589
	jerky:GetScript("OnMouseDown")(jerky, "LeftButton")
	M.cursorItem = nil
	M.bags[0][2], M.bags[0][3] = M.bags[0][3], M.bags[0][2]   -- Wool, not the Linen this click carried, is in the slot
	jerky:GetScript("OnClick")(jerky, "LeftButton"); settle(M)
	check(S:MovedTo(2592) == c and S:MovedTo(2589) == c, "a click carrying Linen judges only Linen: Wool in the slot changes nothing")

	-- an inventory change that isn't a drop: no gesture, no check
	n, M, V, S, c = boot()
	M.bags[0][2], M.bags[0][1] = M.bags[0][1], M.bags[0][2]
	n:RefreshViews(true); settle(M)
	check(S:MovedTo(2589) == c, "Linen moving into an All Items slot without a drop (a sort, say) keeps its section")

	-- a drag from a row is judged by that row's item, even when the cursor says otherwise
	n, M, V, S, c = boot()
	local wool = rowOf(V, 2592)
	wool:GetScript("OnDragStart")(wool)
	jerky = n.Buttons:Get(0, 2)
	M.cursorItem = 2589                                      -- a stale or different cursor
	M.bags[0][2], M.bags[0][3] = M.bags[0][3], M.bags[0][2]   -- Wool lands
	M.cursorItem = 117
	jerky:GetScript("OnReceiveDrag")(jerky); settle(M)
	check(S:MovedTo(2592) == nil and S:MovedTo(2589) == c, "the dragged Wool leaves its pinned section; Linen stays")

	-- a drag from somewhere BagSmith can't identify changes no section
	n, M, V, S, c = boot()
	n.Drop.dragFrom = nil
	jerky = n.Buttons:Get(0, 2)
	M.bags[0][2], M.bags[0][1] = M.bags[0][1], M.bags[0][2]
	jerky:GetScript("OnReceiveDrag")(jerky); settle(M)
	check(S:MovedTo(2589) == c, "a drop with no BagSmith drag behind it changes no section")

	-- a slow placement, with nothing else going on, still counts
	n, M, V, S, c = boot()
	jerky = n.Buttons:Get(0, 2)
	M.cursorItem = 2589
	jerky:GetScript("OnMouseDown")(jerky, "LeftButton")
	M.cursorItem = nil
	jerky:GetScript("OnClick")(jerky, "LeftButton")          -- not settled yet
	M.bags[0][2], M.bags[0][1] = M.bags[0][1], M.bags[0][2]   -- Linen arrives a moment later
	settle(M)
	check(S:MovedTo(2589) == nil, "a placement that settles a moment later, with no newer action, still takes Linen out")
end)()
