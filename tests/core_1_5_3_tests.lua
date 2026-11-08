;(function()
	-- 1.5.3: the Disenchant Helper on a game that isn't in English (a player's report: the button did nothing, while
	-- Skip and Exclude worked). This client has no GetSpellInfo, so the button fell back to the English spell name
	-- "Disenchant", which a German game doesn't know (Shweep confirmed it in game by giving the button a German name).
	-- The button now casts by the spell's ID. And the helper found the Enchanting skill by the English name, so on
	-- such a game it couldn't read the skill and stopped holding back items above it; it now uses the profession's
	-- own name from the game (the Enchanting spell's name), English as the last resort.
	local DEID = 13262
	local function boot(o)
		package.loaded.mock = nil
		local M = require("mock")
		M.put(0, 1, { id = 7001, name = "Sturdy Boots", q = 2, count = 1, class = 4, subclass = 1, price = 500, ilvl = 23, equip = "INVTYPE_FEET" })
		M.put(0, 2, { id = 7008, name = "Grand Mace", q = 2, count = 1, class = 2, subclass = 4, price = 3000, ilvl = 63, equip = "INVTYPE_2HWEAPON" })
		_G.BagSmithCharDB = { version = 1, firstSeen = {} }
		_G.BagSmithDB = { version = 2, chars = {}, cache = {}, profiles = { Default = { skin = "modern", deEnabled = true } } }
		_G.IsSpellKnown = function(id) return id == DEID end
		_G.GetNumSkillLines = function() return 2 end
		_G.GetSkillLineInfo = function(i) if i == 1 then return o.header or "Professions", true end return o.skillName, false, nil, 150 end
		_G.GetSpellInfo = o.getSpellInfo   -- nil on this client
		_G.C_Spell = o.cspell
		_G.GetLocale = function() return o.locale end
		_G.RegisterStateDriver = function() end
		_G.UnregisterStateDriver = function() end
		_G.InCombatLockdown = function() return false end
		_G.GetCVar = function(k) if k == "autoLootDefault" then return "1" end end
		local n = M.loadAddon("BagSmith")
		M.fire("ADDON_LOADED", "BagSmith"); M.fire("PLAYER_ENTERING_WORLD"); M.runTimers(); M.runTimers()
		local DE = n.Disenchant
		DE:Show(); M.runTimers()
		return n, M, DE
	end
	local function listed(DE, id) for _, e in ipairs(DE.entries or {}) do if e.itemID == id then return true end end return false end

	-- a German game on this client: no GetSpellInfo; the game's names come from C_Spell
	local de = { [DEID] = "Entzaubern", [7411] = "Verzauberkunst" }
	local n, M, DE = boot({ locale = "deDE", skillName = "Verzauberkunst", header = "Berufe", cspell = { GetSpellName = function(id) return de[id] end } })
	local b = DE.button
	check(b and b:GetAttribute("spell") == DEID, "German game: the Disenchant button casts by the spell's ID, which works in any language (" .. tostring(b and b:GetAttribute("spell")) .. ")")
	check(b:GetAttribute("type") == "spell" and b:GetAttribute("target-bag") == 0, "German game: the button is armed for the first item")
	check(DE:Skill() == 150, "German game: the Enchanting skill is found by the game's own name for it (" .. tostring(DE:Skill()) .. ")")
	check(listed(DE, 7001) and not listed(DE, 7008), "German game: the boots are offered, and the mace above the skill is held back")

	-- a German game on a client that still has GetSpellInfo
	n, M, DE = boot({ locale = "deDE", skillName = "Verzauberkunst", getSpellInfo = function(id) return de[id] end })
	check(DE.button:GetAttribute("spell") == DEID and DE:Skill() == 150, "German game with GetSpellInfo: the spell's ID, and the skill found by name")

	-- English, as on Shweep's client (no GetSpellInfo): unchanged in effect
	local en = { [DEID] = "Disenchant", [7411] = "Enchanting" }
	n, M, DE = boot({ locale = "enUS", skillName = "Enchanting", cspell = { GetSpellName = function(id) return en[id] end } })
	check(DE.button:GetAttribute("spell") == DEID and DE:Skill() == 150 and listed(DE, 7001) and not listed(DE, 7008), "English game: the spell's ID, the skill found, the mace held back")

	-- no way to ask the game for names at all: English as the last resort for the skill
	n, M, DE = boot({ locale = "enUS", skillName = "Enchanting" })
	check(DE:Skill() == 150, "no name lookup at all: the English name still finds the skill")
	-- and a game whose skill name matches nothing stays honest: unknown, not a guess
	n, M, DE = boot({ locale = "frFR", skillName = "Enchantement" })
	check(DE:Skill() == nil, "a skill name nothing can confirm counts as unknown (as before)")
end)()
