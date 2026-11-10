-- 1.6.0: the 1.6.0-beta11 audit's own probe (ui/title_lifecycle_probe.lua, its checks unchanged), kept in the suite. Evidence and the report:
-- docs/plugins/audit-1.6.0-beta11/.
-- (Run by the suite's runner, which has no AUDIT_CORE: the working copy's BagSmith. The only line added to the probe.)
AUDIT_CORE = AUDIT_CORE or "BagSmith"
-- Independent lifecycle/geometry extension. Uses the supplied anchor resolver, new assertions and matrix.
	local function natural(r)
		if r.GetStringWidth then
			local sw = r:GetStringWidth() or 0
			if r.width and r.width > 0 then return math.min(r.width, sw) end
			return sw
		end
		return r.w
	end
	local function parentOf(r) return r.parentFrame or r.parent end
	local span
	local function anchorX(rel, rp, root, depth)
		local l, rr = span(rel, root, depth + 1)
		if not l then return nil end
		if rp:find("LEFT") then return l elseif rp:find("RIGHT") then return rr end
		return (l + rr) / 2
	end
	span = function(r, root, depth)
		depth = depth or 0
		if r == root then return 0, root.w or root:GetWidth() end
		if depth > 40 or not r then return nil end
		local L, R, C
		for _, p in ipairs(r.points or {}) do
			local point, rel, rp, x = p[1], p[2], p[3], p[4]
			if type(rel) ~= "table" then rel, rp, x = parentOf(r), point, rel end
			local ax = anchorX(rel, rp or point, root, depth)
			if not ax then return nil end
			ax = ax + (tonumber(x) or 0)
			if point:find("LEFT") then L = ax elseif point:find("RIGHT") then R = ax else C = ax end
		end
		local w = natural(r)
		if L and R then return L, R end
		if not w then return nil end
		if L then return L, L + w end
		if R then return R - w, R end
		if C then return C - w / 2, C + w / 2 end
		return nil
	end
	local function sized(V, W)
		V.frame.w = W
		for _, r in ipairs({ V.title, V.tools, V.footer }) do
			local l, rr = span(r, V.frame)
			if l then r.w = rr - l end
		end
		V:LayoutTools(); V:UpdateFooter(); V:LayoutTitleRow()
		for _, r in ipairs({ V.title, V.tools, V.footer }) do
			local l, rr = span(r, V.frame)
			if l then r.w = rr - l end
		end
		V:LayoutTools(); V:UpdateFooter(); V:LayoutTitleRow()
	end
	local function overlaps(list)
		table.sort(list, function(a, b) return a.l < b.l end)
		for i = 2, #list do if list[i].l < list[i - 1].r - 0.01 then return list[i - 1].name .. " / " .. list[i].name end end
	end

	local function fmt(x) return x and ("%.0f"):format(x) or "?" end
	local function sized(V, W)
		V.frame.w = W
		for _ = 1, 2 do
			for _, r in ipairs({ V.title, V.tools, V.footer }) do local l, rr = span(r, V.frame); if l then r.w = rr - l end end
			V:LayoutTools(); V:UpdateFooter(); V:LayoutTitleRow()
		end
	end
	-- game-like text widths (the mock counts characters): the title in its larger font, the note in the small one
	local function gameWidths(V)
		local function w(fs, per) fs.GetUnboundedStringWidth = function(self) return #(self.text or "") * per end; fs.GetStringWidth = fs.GetUnboundedStringWidth end
		w(V.titleText, 10); w(V.subText, 6)
	end
	local function firstIcon(V)
		local best, name = math.huge, "?"
		for _, k in ipairs({ "btnLanesTravel", "btnClean", "btnDisenchant", "btnGearSets", "btnBank", "btnCurrency", "btnSettings" }) do
			local b = V[k]
			if b and b:IsShown() then local l = span(b, V.frame); if l and l < best then best, name = l, k end end
		end
		return best, name
	end


local configs = 0
for _, startSkin in ipairs({'modern','classic'}) do
 package.loaded.mock=nil
 local M=require('mock')
 _G.Auctionator=nil;_G.BlackthornesTS_API=nil
 _G.BagSmithCharDB={version=1,firstSeen={}}
 local key='Extremely Long Character Name - Forever'
 _G.BagSmithDB={version=2,chars={},profiles={Default={skin=startSkin,view='icons',deEnabled=true}},cache={
 [key]={name='Extremely Long Character Name',realm='Forever',class='MAGE',level=60,gold=0,updated=time()-30,bags={},items={},currencies={}}}}
 local n=M.loadAddon(AUDIT_CORE or 'BagSmith')
 M.fire('ADDON_LOADED','BagSmith');M.fire('PLAYER_ENTERING_WORLD');M.runTimers();M.runTimers();n.Window:Show();M.runTimers();M.runTimers()
 local V=n.Window.main
 gameWidths(V)
 local originalLevel=V.charLevel
 for _,skin in ipairs({startSkin,startSkin=='modern' and 'classic' or 'modern',startSkin}) do
  n:Set('skin',skin);M.runTimers();M.runTimers()
  for _,travel in ipairs({false,true,false}) do
   n:Set('travelMode',travel);M.runTimers();M.runTimers()
   for _,de in ipairs({true,false}) do
    n:Set('deEnabled',de);M.runTimers()
    for _,width in ipairs({440,500,900,440}) do
     for _,owner in ipairs({key,false}) do
      V:SetOwner(owner or nil);M.runTimers()
      V.st.sheet=owner and 'Bank' or 'All'
      V:UpdateChrome({},137,nil,owner and true or false)
      sized(V,width)
      local label=table.concat({startSkin,skin,tostring(travel),tostring(de),tostring(width),tostring(owner)},'/')
      configs=configs+1
      check(V.charLevel==originalLevel,label..': stable level allocation')
      if travel then
       local l,r=span(V.search,V.frame);local icon=firstIcon(V)
       check(l and r and r-l>=119.99 and r<=icon+0.01,label..': search minimum and icon clearance')
       check(not V.charBtn:IsShown() and not V.charReset:IsShown(),label..': picker and reset hidden in Travel')
      else
       local l,r=span(V.charBtn,V.frame);local icon=firstIcon(V)
       local _,rr=span(V.charReset,V.frame)
       check(l and r and r-l>=109.99 and r<=icon+0.01 and (not owner or (rr and rr<=icon+0.01)),label..': picker and reset fit')
       check(V.charReset:IsShown()==(owner and true or false),label..': reset matches owner')
       local p={V.charBtn:GetPoint(1)}
       check(p[2]==V.subText and p[3]==(V.subText:IsShown() and 'RIGHT' or 'LEFT'),label..': anchor follows shown state')
      end
      local lp={V.charLevel:GetPoint(1)}
      local inset=(V.classicApplied and V.classicDropdown) and 28 or 18
      check(lp[4]==-inset,label..': live skin inset')
      if owner and not travel then check(V.subText.text=='read only, saved bank, 0 of 137 shown',label..': exact cached bank/filter note') elseif travel then check(n.ui.owner==nil,label..': Travel refuses cached owner') end
     end
    end
   end
  end
 end
end
print('TITLE_LIFECYCLE_CONFIGURATIONS',configs)
