-- Fórmulas compartidas por servidor y cliente: estadísticas, experiencia,
-- rango, entrenamiento y ventaja de dominio.
local GameData = require(script.Parent.GameData)
local Config = require(script.Parent.Config)

local Formulas = {}

Formulas.MaxLevel = 50
Formulas.MaxRank = 60

Formulas.Forms = {
	{ es = "Cría", en = "Hatchling", mult = 1.0 },
	{ es = "Adulta", en = "Adult", mult = 1.12 },
	{ es = "Primordial", en = "Primordial", mult = 1.3 },
}

Formulas.RankTitles = {
	{ min = 1, es = "Aprendiz", en = "Apprentice" },
	{ min = 10, es = "Iniciado", en = "Initiate" },
	{ min = 25, es = "Sellador", en = "Sealer" },
	{ min = 40, es = "Maestro de Sellos", en = "Seal Master" },
	{ min = 55, es = "Archisellador", en = "Archsealer" },
}

function Formulas.xpToNext(level)
	return math.floor(30 + level * 12 + level * level * 1.2 + 0.5)
end

function Formulas.rankXpFor(rank)
	return math.floor(80 * rank + 6 * rank * rank + 0.5)
end

function Formulas.trainCost(level)
	return math.floor(40 + level * level * 3.5 + 0.5)
end

function Formulas.rankInfo(rankXp)
	local r = 1
	local xp = rankXp or 0
	while r < Formulas.MaxRank and xp >= Formulas.rankXpFor(r) do
		xp = xp - Formulas.rankXpFor(r)
		r = r + 1
	end
	return { rank = r, xp = xp, need = Formulas.rankXpFor(r) }
end

function Formulas.rankTitle(rank)
	local res = Formulas.RankTitles[1]
	for _, t in ipairs(Formulas.RankTitles) do
		if rank >= t.min then
			res = t
		end
	end
	return res
end

function Formulas.teamSize(rankXp)
	if Formulas.rankInfo(rankXp).rank >= 10 then
		return 3
	end
	return Config.TeamSizeBase
end

-- form: 1 Cría, 2 Adulta, 3 Primordial
function Formulas.stats(id, level, form, boss)
	local c = GameData.CreatureById[id]
	local s = c.stats
	local lf = 1 + (level - 1) * 0.085
	local fm = Formulas.Forms[form].mult
	if boss then
		fm = fm * 1.25
	end
	local hpMult = 1
	if boss then
		hpMult = 6
	end
	return {
		hp = math.floor((150 + s.def * 2.1) * lf * fm * hpMult + 0.5),
		atk = s.pow * lf * fm,
		mag = s.mag * lf * fm,
		def = s.def * lf * fm,
		speed = 15 + s.agi * 0.06, -- studs/s
		cdr = 1 - s.agi * 0.0015,
	}
end

-- Abisal > Ígneo > Natural > Arcano > Abisal (+30 % / −23 %)
function Formulas.domainMult(attEl, defEl)
	local a = GameData.Elements[attEl].domain
	local d = GameData.Elements[defEl].domain
	if GameData.Domains[a].beats == d then
		return 1.3
	end
	if GameData.Domains[d].beats == a then
		return 0.77
	end
	return 1
end

-- Requisitos de evolución
function Formulas.evolveInfo(profile, id)
	local own = profile.creatures[id]
	if not own or own.form >= 3 then
		return nil
	end
	local c = GameData.CreatureById[id]
	if own.form == 1 then
		local frags = profile.fragments[c.el] or 0
		return { to = 2, level = 20, frags = 30, have = frags, ok = own.level >= 20 and frags >= 30 }
	end
	local bossDone = table.find(profile.islands.cleared, c.island) ~= nil
	return { to = 3, level = 40, boss = true, bossDone = bossDone, ok = own.level >= 40 and bossDone }
end

function Formulas.formsSealed(profile)
	local n = 0
	for _, c in ipairs(GameData.Creatures) do
		local b = profile.bestiary[c.id]
		if b then
			for i = 1, 3 do
				if b.forms[i] then
					n = n + 1
				end
			end
		end
	end
	return n
end

function Formulas.passTier(passXp)
	return math.min(#GameData.PassTiers, math.floor((passXp or 0) / GameData.PassXpPerTier))
end

function Formulas.tintColor(tintId, base)
	if tintId and tintId ~= "" then
		local t = GameData.TintById[tintId]
		if t then
			return t.color
		end
	end
	return base
end

-- Color animado de los tintes «prisma» y «aurora»
function Formulas.resolveColor(colorStr, t)
	if colorStr == "prisma" then
		return Color3.fromHSV((t * 0.12) % 1, 0.8, 1)
	elseif colorStr == "aurora" then
		local stops = { Color3.fromHex("#9fefff"), Color3.fromHex("#3dff88"), Color3.fromHex("#b06bff"), Color3.fromHex("#ff4fd2") }
		local x = (t * 0.25) % #stops
		local i = math.floor(x)
		return stops[i + 1]:Lerp(stops[(i + 1) % #stops + 1], x - i)
	end
	return Color3.fromHex(colorStr)
end

return Formulas
