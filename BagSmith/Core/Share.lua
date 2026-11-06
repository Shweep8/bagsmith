--[[
	Core/Share.lua

	Profile Sharing: a profile becomes a text code you can copy, keep, or
	give to someone; importing a code creates a new profile.

	The code is "BS1:" + the profile in a simple text form, encoded with
	letters, digits, "+" and "/", then ":" and a short checksum. It is only
	ever read as data (a small parser below; nothing is ever run), and the
	imported profile goes through the same checks as saved settings at
	login, so a damaged or edited code is rejected and unknown settings are
	dropped.

	Format inside the encoding: t ... e = table (key then value, repeated),
	s<len>:<bytes> = string, n<number>; = number, T / F = true / false.
--]]
local ADDON, ns = ...
local Share = {}
ns.Share = Share

local VERSION = 1
local PREFIX = "BS" .. VERSION .. ":"
local MAX_DEPTH = 12
local MAX_LEN = 400000

------------------------------------------------------------------------
-- Serialize / parse
------------------------------------------------------------------------
local function serialize(v, out, depth)
	local t = type(v)
	if t == "table" then
		if depth > MAX_DEPTH then error("too deep") end
		out[#out + 1] = "t"
		-- Keys in a stable order, so the same profile always gives the same code.
		local keys = {}
		for k in pairs(v) do if type(k) == "string" or type(k) == "number" then keys[#keys + 1] = k end end
		table.sort(keys, function(a, b)
			if type(a) == type(b) then return a < b end
			return type(a) == "number"
		end)
		for _, k in ipairs(keys) do
			local val = v[k]
			local vt = type(val)
			if vt == "table" or vt == "string" or vt == "number" or vt == "boolean" then
				serialize(k, out, depth + 1); serialize(val, out, depth + 1)
			end
		end
		out[#out + 1] = "e"
	elseif t == "string" then
		out[#out + 1] = "s" .. #v .. ":" .. v
	elseif t == "number" then
		out[#out + 1] = "n" .. string.format("%.17g", v) .. ";"
	elseif t == "boolean" then
		out[#out + 1] = v and "T" or "F"
	end
end

local function parse(s)
	local pos = 1
	local function value(depth)
		if depth > MAX_DEPTH then error("too deep") end
		local c = s:sub(pos, pos)
		if c == "t" then
			pos = pos + 1
			local tbl = {}
			while true do
				if pos > #s then error("unfinished table") end
				if s:sub(pos, pos) == "e" then pos = pos + 1; return tbl end
				local k = value(depth + 1)
				if type(k) ~= "string" and type(k) ~= "number" then error("bad key") end
				tbl[k] = value(depth + 1)
			end
		elseif c == "s" then
			local colon = s:find(":", pos + 1, true)
			if not colon then error("bad string") end
			local digits = s:sub(pos + 1, colon - 1)
			local len = digits:match("^%d+$") and tonumber(digits)
			if not len or colon + len > #s then error("bad string length") end
			local str = s:sub(colon + 1, colon + len)
			pos = colon + len + 1
			return str
		elseif c == "n" then
			local semi = s:find(";", pos + 1, true)
			if not semi then error("bad number") end
			local n = tonumber(s:sub(pos + 1, semi - 1))
			if not n or n ~= n or n == math.huge or n == -math.huge then error("bad number") end
			pos = semi + 1
			return n
		elseif c == "T" then pos = pos + 1; return true
		elseif c == "F" then pos = pos + 1; return false
		end
		error("unexpected data")
	end
	local v = value(0)
	if pos <= #s then error("extra data") end
	return v
end

------------------------------------------------------------------------
-- Text-safe encoding (base64) and checksum, plain arithmetic only.
------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DEC = {}
for i = 1, 64 do DEC[B64:sub(i, i)] = i - 1 end

local function encode(s)
	local out = {}
	for i = 1, #s, 3 do
		local a, b, c = s:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1, c2 = math.floor(n / 262144) % 64, math.floor(n / 4096) % 64
		local c3, c4 = math.floor(n / 64) % 64, n % 64
		out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
			.. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
	end
	return table.concat(out)
end

local function decode(s)
	s = s:gsub("%s", "")
	if #s % 4 ~= 0 then return nil end
	local out = {}
	for i = 1, #s, 4 do
		local q = { s:byte(i, i + 3) }
		local v = {}
		for j = 1, 4 do
			local ch = string.char(q[j])
			if ch == "=" then v[j] = nil else v[j] = DEC[ch]; if not v[j] then return nil end end
		end
		if not (v[1] and v[2]) then return nil end
		local n = v[1] * 262144 + v[2] * 4096 + (v[3] or 0) * 64 + (v[4] or 0)
		out[#out + 1] = string.char(math.floor(n / 65536) % 256)
		if v[3] then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
		if v[4] then out[#out + 1] = string.char(n % 256) end
	end
	return table.concat(out)
end

local function checksum(s)
	local h = 0
	for i = 1, #s do h = (h * 31 + s:byte(i)) % 16777213 end
	return string.format("%06x", h)
end

------------------------------------------------------------------------
-- Public
------------------------------------------------------------------------
-- The code for a profile (the active one if no name is given).
-- The length of the share code a profile table would produce (the same serializer, encoder and framing as
-- Export), and the limit; nil when the table cannot be serialized. The plugin API uses this to refuse a
-- preference write that would make the active profile unsharable.
function Share:CodeLength(prof)
	if type(prof) ~= "table" then return nil, "not a profile" end
	local copy = {}
	for k, v in pairs(prof) do if k ~= "debug" then copy[k] = v end end
	local out = {}
	local ok, err = pcall(serialize, copy, out, 0)
	if not ok then return nil, tostring(err) end
	local body = encode(table.concat(out))
	return #PREFIX + #body + 1 + #checksum(body), MAX_LEN
end
function Share:Export(name)
	name = name or ns.profileName
	local prof = BagSmithDB and BagSmithDB.profiles and BagSmithDB.profiles[name]
	if not prof then return nil, "No profile named " .. tostring(name) .. "." end
	local copy = {}
	for k, v in pairs(prof) do if k ~= "debug" then copy[k] = v end end   -- a tester's debug switch never travels
	local out = {}
	local ok, err = pcall(serialize, copy, out, 0)
	if not ok then return nil, "Couldn't make a code for this profile (" .. tostring(err) .. ")." end
	local body = encode(table.concat(out))
	local code = PREFIX .. body .. ":" .. checksum(body)
	if #code > MAX_LEN then return nil, "This profile is too large to share as a code." end
	return code
end

-- Read a code: the profile table, or nil and a plain message.
function Share:Decode(code)
	code = tostring(code or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if code == "" then return nil, "Paste a profile code first." end
	if #code > MAX_LEN then return nil, "That code is too long to be a BagSmith profile." end
	local ver, body, sum = code:match("^BS(%d+):([%w%+/=%s]+):(%x+)$")
	if not ver then return nil, "That isn't a BagSmith profile code." end
	if tonumber(ver) > VERSION then return nil, "That code is from a newer BagSmith. Update BagSmith to import it." end
	body = body:gsub("%s", "")
	if checksum(body) ~= sum:lower() then return nil, "That code is damaged (it may have been cut off when copied)." end
	local raw = decode(body)
	if not raw then return nil, "That code is damaged." end
	local ok, data = pcall(parse, raw)
	if not ok or type(data) ~= "table" then return nil, "That code is damaged." end
	return data
end

-- Import a code as a new profile. Returns the profile's name, or nil and a message.
function Share:Import(code, name)
	local data, err = self:Decode(code)
	if not data then return nil, err end
	return ns.Profiles:Import(name, data)
end
