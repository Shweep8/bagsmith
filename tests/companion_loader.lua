-- Loads a second addon folder (the companion) the way the client would: each Lua file from its TOC, in order,
-- with (addonName, privateNamespace) as its varargs, after BagSmith itself. Returns the companion's namespace.
local function loadCompanion(M, root, name)
	local ns = {}
	for line in io.lines(root .. "/" .. name .. ".toc") do
		if line:match("%.lua%s*$") and not line:match("^#") then
			local path = root .. "/" .. line:gsub("\\", "/"):gsub("%s+$", "")
			local chunk, err = loadfile(path)
			assert(chunk, err)
			chunk(name, ns)
		end
	end
	return ns
end
return loadCompanion
