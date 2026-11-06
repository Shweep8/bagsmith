--[[
	Look snapshots for the skin checks. Walks a window's frames and records
	what the player sees: backdrop fill and border colors, text colors,
	texture colors and alpha, and (for the Classic check) positions and sizes.
	Frames the code has explicitly hidden are skipped, so pieces belonging to
	the other skin don't count. The mock starts frames hidden, so "never
	shown" still counts as visible here, as on the real client.
--]]
local L = {}

local function c(t)
	if not t then return nil end
	return ("%.2f,%.2f,%.2f,%.2f"):format(t[1] or 0, t[2] or 0, t[3] or 0, t[4] or 1)
end

-- out: list of lines. roots: { { label, frame, skip = { [frame] = true }, depth = n } }.
-- opts.layout: also record each frame's points and size.
function L.snap(out, roots, opts)
	opts = opts or {}
	local labels, order = {}, {}
	local function index(label, f, depth, root)
		labels[f] = label
		order[#order + 1] = { label = label, f = f }
		if depth >= (root.depth or 6) then return end
		-- Numbered among the frames that count, so a hidden piece of the other
		-- skin created earlier doesn't shift everyone's number.
		local n = 0
		for _, ch in ipairs(f.children or {}) do
			if not ch.lookHidden and not (root.skip and root.skip[ch]) then n = n + 1; index(label .. "." .. n, ch, depth + 1, root) end
		end
	end
	for _, r in ipairs(roots) do if r[2] then index(r[1], r[2], 0, r) end end
	local function name(v)
		if v == nil then return "parent" end
		if type(v) ~= "table" then return tostring(v) end
		return labels[v] or v.name or v.kind or "frame"
	end
	local function points(obj)
		local pts = {}
		for _, p in ipairs(obj.points or {}) do
			if type(p[2]) == "number" or p[2] == nil then p = { p[1], nil, p[1], p[2] or 0, p[3] or 0 } end
			pts[#pts + 1] = ("%s,%s,%s,%s,%s"):format(tostring(p[1]), name(p[2]), tostring(p[3] or p[1]), tostring(p[4] or 0), tostring(p[5] or 0))
		end
		return table.concat(pts, ";")
	end
	for _, e in ipairs(order) do
		local f, label = e.f, e.label
		local parts = {}
		if f.bgColor then parts[#parts + 1] = "bg=" .. c(f.bgColor) end
		if f.borderColor then parts[#parts + 1] = "border=" .. c(f.borderColor) end
		if f.alpha and f.alpha ~= 1 then parts[#parts + 1] = ("alpha=%.2f"):format(f.alpha) end
		if opts.layout then
			parts[#parts + 1] = ("w=%s h=%s at=%s"):format(tostring(f.w), tostring(f.h), points(f))
			if f.level then parts[#parts + 1] = "level=" .. tostring(f.level) end
		end
		if #parts > 0 then out[#out + 1] = "look " .. label .. " " .. table.concat(parts, " ") end
		for i, r in ipairs(f.regions or {}) do
			if r.shown ~= false and (r.parentFrame == nil or r.parentFrame == f) then
				local p = {}
				if r.textColor then p[#p + 1] = "text=" .. c(r.textColor) end
				if r.color then p[#p + 1] = "color=" .. c(r.color) end
				if r.alpha and r.alpha ~= 1 then p[#p + 1] = ("alpha=%.2f"):format(r.alpha) end
				if opts.layout and (r.color or r.atlas or r.texture) then
					p[#p + 1] = ("w=%s h=%s at=%s"):format(tostring(r.w), tostring(r.h), points(r))
					if r.layer then p[#p + 1] = ("layer=%s/%s"):format(tostring(r.layer), tostring(r.sublayer)) end
				end
				if #p > 0 then out[#out + 1] = ("look %s.r%d %s"):format(label, i, table.concat(p, " ")) end
			end
		end
	end
end

return L
