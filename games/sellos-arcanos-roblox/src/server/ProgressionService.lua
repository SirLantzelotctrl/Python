-- Progresión: experiencia, niveles, entrenamiento, evolución, vínculo,
-- recompensa diaria, contratos, Pase Arcano, Bestiario y compras con cristales.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameData = require(Shared.GameData)
local Formulas = require(Shared.Formulas)
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local Codes = require(script.Parent.Codes)

local Progression = {}

local function toast(player, key, vars, kind)
	Net.get("Toast"):FireClient(player, key, vars or {}, kind or "")
end
Progression.toast = toast

function Progression.markSeen(player, id)
	local p = DataService.get(player)
	if p and p.bestiary[id] and not p.bestiary[id].seen then
		p.bestiary[id].seen = true
		DataService.sync(player)
	end
end

function Progression.addBond(own, amount)
	own.bondXp = own.bondXp + amount
	local up = false
	while own.bond < 5 and own.bondXp >= 60 * own.bond do
		own.bondXp = own.bondXp - 60 * own.bond
		own.bond = own.bond + 1
		up = true
	end
	return up
end

function Progression.giveXp(own, amount)
	if own.level >= Formulas.MaxLevel then
		return 0
	end
	own.xp = own.xp + math.floor(amount + 0.5)
	local ups = 0
	while own.level < Formulas.MaxLevel and own.xp >= Formulas.xpToNext(own.level) do
		own.xp = own.xp - Formulas.xpToNext(own.level)
		own.level = own.level + 1
		ups = ups + 1
	end
	if own.level >= Formulas.MaxLevel then
		own.xp = 0
	end
	return ups
end

-- Añade una criatura sellada o convierte el duplicado en vínculo y fragmentos.
function Progression.addCreature(player, id, level, perfect)
	local p = DataService.get(player)
	local c = GameData.CreatureById[id]
	local res = { isNew = false, fragments = perfect and 4 or 3 }
	p.bestiary[id].seen = true
	if not p.creatures[id] then
		p.creatures[id] = { form = 1, level = math.max(1, level), xp = 0, bond = perfect and 2 or 1, bondXp = 0, tint = "" }
		p.bestiary[id].forms[1] = true
		res.isNew = true
		if #p.team < Formulas.teamSize(p.rankXp) then
			table.insert(p.team, id)
		end
	else
		Progression.addBond(p.creatures[id], perfect and 40 or 20)
	end
	p.fragments[c.el] = (p.fragments[c.el] or 0) + res.fragments
	Progression.milestones(player)
	return res
end

function Progression.milestones(player)
	local p = DataService.get(player)
	local n = Formulas.formsSealed(p)
	for _, m in ipairs({ 3, 6, 12, 18, 24, 30, 36 }) do
		local k = "b" .. m
		if n >= m and not table.find(p.milestones, k) then
			table.insert(p.milestones, k)
			local crystals = (m == 36 and 200) or (m >= 18 and 40) or 20
			p.crystals = p.crystals + crystals
			toast(player, "milestone", { n = m, c = crystals }, "gold")
		end
	end
	for _, c in ipairs(GameData.Creatures) do
		local b = p.bestiary[c.id]
		local key = "title_" .. c.id
		if b.forms[1] and b.forms[2] and b.forms[3] and not table.find(p.titles, key) then
			table.insert(p.titles, key)
		end
	end
end

function Progression.grant(player, g)
	local p = DataService.get(player)
	if not g then
		return
	end
	if g.essence then
		p.essence = p.essence + g.essence
	end
	if g.crystals then
		p.crystals = p.crystals + g.crystals
	end
	if g.ink then
		p.ink = math.min(Config.InkMax + 20, p.ink + g.ink)
	end
	if g.fragments then
		local lead = p.team[1] and GameData.CreatureById[p.team[1]]
		local el = lead and lead.el or "luz"
		p.fragments[el] = (p.fragments[el] or 0) + g.fragments
	end
	if g.tint and not table.find(p.cosmetics.tints, g.tint) then
		table.insert(p.cosmetics.tints, g.tint)
	end
	if g.seal and not table.find(p.cosmetics.seals, g.seal) then
		table.insert(p.cosmetics.seals, g.seal)
	end
	if g.effect and not table.find(p.cosmetics.effects, g.effect) then
		table.insert(p.cosmetics.effects, g.effect)
	end
end

function Progression.addRankXp(player, amount)
	local p = DataService.get(player)
	local before = Formulas.rankInfo(p.rankXp).rank
	p.rankXp = p.rankXp + math.floor(amount)
	local after = Formulas.rankInfo(p.rankXp).rank
	if after > before then
		toast(player, "rankUp", { n = after }, "gold")
		if after >= 10 and before < 10 then
			toast(player, "thirdSlot", {}, "gold")
		end
	end
end

function Progression.addPassXp(player, amount)
	local p = DataService.get(player)
	p.pass.xp = math.min(#GameData.PassTiers * GameData.PassXpPerTier, p.pass.xp + amount)
end

-- --- contratos diarios -------------------------------------------------
local CONTRACTS = {
	{ type = "seal", goal = 2, essence = 400 },
	{ type = "perfect", goal = 1, essence = 450 },
	{ type = "kills", goal = 12, essence = 350 },
	{ type = "ult", goal = 3, essence = 350 },
	{ type = "boss", goal = 1, essence = 600 },
	{ type = "advantage", goal = 8, essence = 300 },
}

function Progression.ensureContracts(p)
	if p.contracts.date == DataService.today() and #p.contracts.list > 0 then
		return
	end
	local pool = table.clone(CONTRACTS)
	local list = {}
	for i = 1, 3 do
		local idx = math.random(1, #pool)
		local c = table.remove(pool, idx)
		table.insert(list, { type = c.type, goal = c.goal, progress = 0, essence = c.essence, passXp = 60, claimed = false })
	end
	p.contracts = { date = DataService.today(), list = list }
end

function Progression.progress(player, ctype, n)
	local p = DataService.get(player)
	if not p then
		return
	end
	Progression.ensureContracts(p)
	for _, c in ipairs(p.contracts.list) do
		if c.type == ctype and not c.claimed and c.progress < c.goal then
			c.progress = math.min(c.goal, c.progress + (n or 1))
			if c.progress >= c.goal then
				toast(player, "contractDone", { t = c.type }, "good")
			end
		end
	end
end

-- --- regalos diarios (Premium / VIP) -----------------------------------
function Progression.dailyPerks(player, isVip)
	local p = DataService.get(player)
	local day = DataService.today()
	if player.MembershipType == Enum.MembershipType.Premium and p.perks.lastPremiumGift ~= day then
		p.perks.lastPremiumGift = day
		p.crystals = p.crystals + Config.PremiumDailyCrystals
		toast(player, "premiumGift", { n = Config.PremiumDailyCrystals }, "gold")
	end
	if isVip and p.perks.lastVipGift ~= day then
		p.perks.lastVipGift = day
		p.crystals = p.crystals + Config.VipDailyCrystals
		toast(player, "vipGift", { n = Config.VipDailyCrystals }, "gold")
	end
end

-- --- acciones de menú (RemoteFunction «Action») --------------------------
local Actions = {}

function Actions.train(player, p, id)
	local own = p.creatures[id]
	if not own or own.level >= Formulas.MaxLevel then
		return false
	end
	local cost = Formulas.trainCost(own.level)
	if p.essence < cost then
		return false, "notEnoughEssence"
	end
	p.essence = p.essence - cost
	own.level = own.level + 1
	own.xp = 0
	return true
end

function Actions.evolve(player, p, id)
	local info = Formulas.evolveInfo(p, id)
	if not info or not info.ok then
		return false
	end
	local c = GameData.CreatureById[id]
	if info.frags then
		p.fragments[c.el] = p.fragments[c.el] - info.frags
	end
	p.creatures[id].form = info.to
	p.bestiary[id].forms[info.to] = true
	Progression.milestones(player)
	return true
end

function Actions.team(player, p, id)
	if not p.creatures[id] then
		return false
	end
	local idx = table.find(p.team, id)
	if idx then
		if #p.team <= 1 then
			return false, "teamMin"
		end
		table.remove(p.team, idx)
	else
		if #p.team >= Formulas.teamSize(p.rankXp) then
			return false, "teamFull"
		end
		table.insert(p.team, id)
	end
	return true
end

function Actions.leader(player, p, id)
	local idx = table.find(p.team, id)
	if not idx then
		return false
	end
	table.remove(p.team, idx)
	table.insert(p.team, 1, id)
	return true
end

function Actions.claimDaily(player, p)
	if p.daily.last == DataService.today() then
		return false
	end
	local reward = GameData.Daily[(p.daily.day % 7) + 1]
	Progression.grant(player, reward)
	p.daily.day = (p.daily.day + 1) % 7
	p.daily.last = DataService.today()
	return true
end

function Actions.claimContract(player, p, i)
	Progression.ensureContracts(p)
	local c = p.contracts.list[i]
	if not c or c.claimed or c.progress < c.goal then
		return false
	end
	c.claimed = true
	p.essence = p.essence + c.essence
	Progression.addPassXp(player, c.passXp)
	return true
end

function Actions.claimPass(player, p, n, track)
	local tier = GameData.PassTiers[n]
	if not tier or Formulas.passTier(p.pass.xp) < n then
		return false
	end
	local list = track == "prem" and p.pass.prem or p.pass.free
	if table.find(list, n) then
		return false
	end
	if track == "prem" and not p.pass.premium then
		return false
	end
	table.insert(list, n)
	Progression.grant(player, track == "prem" and tier.prem or tier.free)
	return true
end

function Actions.passPremiumCrystals(player, p)
	if p.pass.premium or p.crystals < Config.PassPremiumCrystals then
		return false, "notEnoughCrystals"
	end
	p.crystals = p.crystals - Config.PassPremiumCrystals
	p.pass.premium = true
	return true
end

-- compras con Cristales Arcanos (solo cosméticos)
function Actions.buyCosmetic(player, p, kind, id)
	local item, list
	if kind == "tint" then
		item, list = GameData.TintById[id], p.cosmetics.tints
	elseif kind == "seal" then
		item, list = GameData.SealById[id], p.cosmetics.seals
	elseif kind == "effect" then
		item, list = GameData.EffectById[id], p.cosmetics.effects
	end
	if not item or table.find(list, id) then
		return false
	end
	if p.crystals < item.price then
		return false, "notEnoughCrystals"
	end
	p.crystals = p.crystals - item.price
	table.insert(list, id)
	if kind == "tint" and p.creatures[item.creature] then
		p.creatures[item.creature].tint = id
	elseif kind == "seal" then
		p.cosmetics.seal = id
	elseif kind == "effect" then
		p.cosmetics.effect = id
	end
	return true
end

function Actions.equip(player, p, kind, id)
	if kind == "seal" and table.find(p.cosmetics.seals, id) then
		p.cosmetics.seal = id
		return true
	elseif kind == "effect" and table.find(p.cosmetics.effects, id) then
		p.cosmetics.effect = id
		return true
	elseif kind == "tint" then
		local t = GameData.TintById[id]
		if id == "" then
			return false
		end
		if t and table.find(p.cosmetics.tints, id) and p.creatures[t.creature] then
			p.creatures[t.creature].tint = id
			return true
		end
	end
	return false
end

function Actions.untint(player, p, creatureId)
	if p.creatures[creatureId] then
		p.creatures[creatureId].tint = ""
		return true
	end
	return false
end

function Actions.settings(player, p, music, sfx)
	if type(music) == "number" and type(sfx) == "number" then
		p.settings.music = math.clamp(music, 0, 1)
		p.settings.sfx = math.clamp(sfx, 0, 1)
		return true
	end
	return false
end

-- --- códigos y grupo ---------------------------------------------------------------
local function grantReward(p, r)
	p.crystals = p.crystals + (r.crystals or 0)
	p.essence = p.essence + (r.essence or 0)
	if r.ink then
		p.ink = math.min(Config.InkMax * 2, p.ink + r.ink)
	end
	return { crystals = r.crystals, essence = r.essence, ink = r.ink }
end

-- límite de intentos para que no se puedan adivinar códigos a la fuerza
local attempts = {}
function Actions.redeem(player, p, code)
	local now = os.clock()
	local a = attempts[player]
	if not a or now - a.t > 60 then
		a = { t = now, n = 0 }
		attempts[player] = a
	end
	a.n = a.n + 1
	if a.n > 6 then
		return false, "codeWait"
	end
	if type(code) ~= "string" or #code > 40 then
		return false, "codeInvalid"
	end
	code = string.upper((string.gsub(code, "%s", "")))
	local def = Codes[code]
	if not def then
		return false, "codeInvalid"
	end
	if def.expires and os.date("!%Y-%m-%d") > def.expires then
		return false, "codeExpired"
	end
	p.codes = p.codes or {}
	if p.codes[code] then
		return false, "codeUsed"
	end
	p.codes[code] = os.time()
	return true, grantReward(p, def)
end

function Actions.groupReward(player, p)
	if not Config.GroupId or Config.GroupId == 0 then
		return false, "codeInvalid"
	end
	if p.perks.group then
		return false, "codeUsed"
	end
	local ok, inGroup = pcall(function()
		return player:IsInGroupAsync(Config.GroupId)
	end)
	if not ok or not inGroup then
		return false, "groupJoin"
	end
	p.perks.group = true
	return true, grantReward(p, Config.GroupReward)
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	attempts[player] = nil
end)

-- el cliente pide el perfil al arrancar (por si el primer envío llegó antes
-- de que estuviera escuchando)
function Actions.sync()
	return true
end

Progression.Actions = Actions
Progression.onChange = nil -- lo asigna Main para refrescar criaturas en el mundo

function Progression.init()
	-- como mucho 40 acciones cada 2 s por jugador (nadie pulsa tan rápido)
	local rate = {}
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		rate[player] = nil
	end)
	Net.get("Action").OnServerInvoke = function(player, name, a, b, c)
		local now = os.clock()
		local r = rate[player]
		if not r or now - r.t > 2 then
			r = { t = now, n = 0 }
			rate[player] = r
		end
		r.n = r.n + 1
		if r.n > 40 then
			return false
		end
		local p = DataService.get(player)
		local fn = Actions[name]
		if not p or not fn or type(name) ~= "string" then
			return false
		end
		local ok, err = fn(player, p, a, b, c)
		if ok then
			DataService.sync(player)
			if Progression.onChange then
				Progression.onChange(player, name)
			end
		end
		return ok, err
	end
end

return Progression
