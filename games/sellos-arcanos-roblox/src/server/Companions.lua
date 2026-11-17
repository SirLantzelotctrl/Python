-- Equipo de cada jugador: la criatura activa le acompaña, combate cuando hay
-- un objetivo y responde a Q · E · R · F, esquiva y cambio 1 · 2 · 3.
-- La vida del resto del equipo se guarda aquí mientras están en el grimorio.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameData = require(Shared.GameData)
local Formulas = require(Shared.Formulas)
local Net = require(Shared.Net)

local Core = require(script.Parent.CombatCore)
local DataService = require(script.Parent.DataService)
local Progression = require(script.Parent.ProgressionService)
local World = require(script.Parent.WorldService)

local Companions = {}
local teams = {} -- player -> {slots = {{id, hp, maxHp, fainted, energy, seal}}, active = idx, ent, target, lastCast, switchCd}

local function pstate(player)
	return teams[player]
end
Companions.state = pstate

local function hrp(player)
	local ch = player.Character
	return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function glowFor(p, id)
	local own = p.creatures[id]
	return Formulas.tintColor(own and own.tint, GameData.CreatureById[id].color)
end

local function sealFor(p, id)
	local s = p.cosmetics.seal
	if s and s ~= "propio" and s ~= "" then
		if s == "corona" or s == "constelacion" or s == "eclipse" then
			return "heptagrama"
		end
		return s
	end
	return GameData.CreatureById[id].circle
end

-- estado del equipo para la interfaz (atributo en el jugador)
function Companions.publish(player)
	local st = teams[player]
	if not st then
		return
	end
	local out = { active = st.active, slots = {} }
	for i, s in ipairs(st.slots) do
		local hp, maxHp, energy, seal = s.hp, s.maxHp, s.energy, s.seal
		local cds = { q = 0, e = 0, r = 0 }
		local shield = 0
		if i == st.active and st.ent and st.ent.alive then
			hp, maxHp, energy, seal = st.ent.hp, st.ent.maxHp, st.ent.energy, st.ent.seal
			cds = st.ent.cds
			shield = st.ent.shield
		end
		table.insert(out.slots, {
			id = s.id, hp = math.floor(hp), maxHp = maxHp, fainted = s.fainted, energy = math.floor(energy),
			seal = math.floor(seal), level = s.level, form = s.form, shield = math.floor(shield),
			cq = math.ceil(cds.q * 10) / 10, ce = math.ceil(cds.e * 10) / 10, cr = math.ceil(cds.r * 10) / 10,
		})
	end
	out.target = st.target and st.target.alive and st.target.id or ""
	local json = HttpService:JSONEncode(out)
	if player:GetAttribute("TeamState") ~= json then
		player:SetAttribute("TeamState", json)
	end
end

local function saveActive(st)
	local s = st.slots[st.active]
	if s and st.ent then
		s.hp = st.ent.hp
		s.energy = st.ent.energy
		s.seal = st.ent.seal
	end
end

-- reconstruye el equipo desde el perfil (al entrar o al cambiar el equipo)
function Companions.rebuild(player, keepHp)
	local p = DataService.get(player)
	if not p then
		return
	end
	local old = teams[player]
	local oldHp = {}
	if old and keepHp then
		saveActive(old)
		for _, s in ipairs(old.slots) do
			oldHp[s.id] = s
		end
	end
	local st = { slots = {}, active = 1, switchCd = 0, lastCast = 0 }
	for _, id in ipairs(p.team) do
		local own = p.creatures[id]
		if own then
			local stats = Formulas.stats(id, own.level, own.form, false)
			local prev = oldHp[id]
			table.insert(st.slots, {
				id = id, level = own.level, form = own.form, maxHp = stats.hp,
				hp = prev and math.min(prev.hp, stats.hp) or stats.hp, fainted = prev and prev.fainted or false,
				energy = prev and prev.energy or 100, seal = prev and prev.seal or 0,
			})
		end
	end
	if old and old.ent then
		Core.despawn(old.ent, false)
	end
	if old then
		st.target = nil
	end
	teams[player] = st
	for i, s in ipairs(st.slots) do
		if not s.fainted then
			st.active = i
			break
		end
	end
	Companions.summon(player)
end

function Companions.summon(player)
	local st = teams[player]
	local p = DataService.get(player)
	local root = hrp(player)
	if not st or not p or not root or #st.slots == 0 then
		return
	end
	local s = st.slots[st.active]
	if not s or s.fainted then
		return
	end
	if st.ent then
		Core.despawn(st.ent, false)
	end
	local island = World.islandAt(root.Position) or 0
	local look = root.CFrame.LookVector
	local pos = World.clampToIsland(island, root.Position - look * 6 + root.CFrame.RightVector * 5, 4)
	local ent = Core.spawn({
		creature = s.id, kind = "companion", level = s.level, form = s.form, owner = player,
		island = island, pos = pos, facing = math.atan2(-look.X, -look.Z), hp = s.hp,
		glow = glowFor(p, s.id), seal = sealFor(p, s.id), effect = p.cosmetics.effect,
	})
	ent.energy = s.energy
	ent.seal = s.seal
	ent.slot = st.active
	st.ent = ent
	Progression.markSeen(player, s.id)
	Companions.publish(player)
end

function Companions.switch(player, slot)
	local st = teams[player]
	if not st or type(slot) ~= "number" then
		return
	end
	slot = math.floor(slot)
	local s = st.slots[slot]
	if not s or s.fainted or slot == st.active or st.switchCd > 0 then
		return
	end
	saveActive(st)
	local oldPos = st.ent and st.ent.pos
	st.active = slot
	st.switchCd = 1.5
	Companions.summon(player)
	if oldPos and st.ent then
		st.ent.pos = oldPos
	end
end

-- toda la vida y la energía de vuelta (Fuente del Sello, al volver a la Ciudadela)
function Companions.restore(player)
	local st = teams[player]
	if not st then
		return
	end
	for _, s in ipairs(st.slots) do
		s.hp = s.maxHp
		s.fainted = false
		s.energy = 100
	end
	if st.ent and st.ent.alive then
		st.ent.hp = st.ent.maxHp
		st.ent.statuses = {}
		st.ent.model:SetAttribute("HP", st.ent.hp)
	else
		for i, s in ipairs(st.slots) do
			if not s.fainted then
				st.active = i
				break
			end
		end
		Companions.summon(player)
	end
	Companions.publish(player)
end

function Companions.onFaint(ent)
	local player = ent.owner
	local st = teams[player]
	if not st then
		return
	end
	local s = st.slots[ent.slot]
	if s then
		s.hp = 0
		s.fainted = true
	end
	Core.fx(ent.island, { t = "burst", p = ent.pos + Vector3.new(0, ent.height * 0.5, 0), c = ent.def.color, n = 30 })
	Core.despawn(ent, false)
	st.ent = nil
	local nextIdx = nil
	for i, sl in ipairs(st.slots) do
		if not sl.fainted then
			nextIdx = i
			break
		end
	end
	if nextIdx then
		st.active = nextIdx
		task.delay(0.8, function()
			if teams[player] == st and not st.ent then
				Companions.summon(player)
			end
		end)
	else
		-- equipo caído: vuelta a la Ciudadela, la Fuente los restaura
		Progression.toast(player, "teamFell", {}, "bad")
		task.delay(1.2, function()
			if Companions.toHub then
				Companions.toHub(player)
			end
			Companions.restore(player)
		end)
	end
	Companions.publish(player)
end

-- Renacer (Fénix): revive al equipo en el grimorio
function Companions.reviveTeam(ent, pct)
	local st = teams[ent.owner]
	if not st then
		return
	end
	for _, s in ipairs(st.slots) do
		if s.fainted then
			s.fainted = false
			s.hp = s.maxHp * pct
		end
	end
end

-- curas de equipo (Calor vital, Refugio, Amanecer): la activa recibe la cura real,
-- el resto del grimorio se cura directamente
function Companions.teamEntities(ent)
	local st = teams[ent.owner]
	if not st then
		return { ent }
	end
	local list = { ent }
	for i, s in ipairs(st.slots) do
		if i ~= st.active and not s.fainted then
			-- objeto ligero que recibe las curas de equipo (CombatCore.heal lo reconoce)
			local proxy = {
				alive = true, kind = "bench", benchSlot = s, hp = s.hp, maxHp = s.maxHp, island = ent.island,
				pos = ent.pos, height = ent.height, statuses = {}, buffs = {}, shield = 0, shieldT = 0, reflect = 0,
				radius = ent.radius, def = GameData.CreatureById[s.id],
			}
			table.insert(list, proxy)
		end
	end
	return list
end

-- objetivo: el que pidió el cliente si es válido; si no, el más cercano
local function pickTarget(st, wantedId)
	local ent = st.ent
	if not ent then
		return nil
	end
	local foes = Core.foesOf(ent)
	if wantedId and wantedId ~= "" then
		for _, f in ipairs(foes) do
			if f.id == wantedId and Core.dist(f.pos, ent.pos) < 120 then
				return f
			end
		end
	end
	if st.target and st.target.alive and st.target.island == ent.island then
		return st.target
	end
	local best, bd = nil, 70
	for _, f in ipairs(foes) do
		local d = Core.dist(f.pos, ent.pos)
		if d < bd then
			best, bd = f, d
		end
	end
	return best
end

function Companions.cast(player, key, targetId)
	local st = teams[player]
	if not st or not st.ent or not st.ent.alive then
		return
	end
	local ent = st.ent
	if type(key) ~= "string" or Core.stunned(ent) or ent.castLock > 0 or ent.dash then
		return
	end
	local ab = ent.def.abilityByKey[key]
	if not ab then
		return
	end
	if key == "r" and ent.form < 2 then
		return
	end
	local target = pickTarget(st, targetId)
	st.target = target
	st.lastCast = Core.time
	if key == "f" then
		if ent.seal < 100 then
			return
		end
		ent.seal = 0
		local p = DataService.get(player)
		p.stats.ults = p.stats.ults + 1
		Progression.progress(player, "ult")
		Net.get("Banner"):FireClient(player, "ult", { id = ent.creature }, "ult")
	else
		if ent.cds[key] > 0 or ent.energy < (ab.cost or 0) then
			return
		end
		ent.energy = ent.energy - (ab.cost or 0)
		ent.cds[key] = ab.cd * Core.cdrMul(ent)
	end
	local dir
	if target then
		dir = Core.dirTo(ent.pos, target.pos)
	else
		local r = hrp(player)
		local lv = r and r.CFrame.LookVector or Vector3.new(0, 0, -1)
		dir = Vector3.new(lv.X, 0, lv.Z).Unit
	end
	Core.cast(ent, ab, { dir = dir, pos = target and target.pos or (ent.pos + dir * 15), target = target })
	Companions.publish(player)
end

function Companions.dodge(player, dir)
	local st = teams[player]
	if not st or not st.ent or not st.ent.alive then
		return
	end
	local ent = st.ent
	if ent.dodgeCd > 0 or Core.rooted(ent) then
		return
	end
	local d = (typeof(dir) == "Vector3" and dir.Magnitude > 0.1) and Vector3.new(dir.X, 0, dir.Z).Unit or Vector3.new(-math.sin(ent.facing), 0, -math.cos(ent.facing))
	ent.dash = { dir = d, left = 13, speed = 62, hit = {} }
	ent.iframes = 0.4
	ent.dodgeCd = 1
	Core.fx(ent.island, { t = "trail", id = ent.id, c = ent.def.color, time = 0.25 })
end

-- movimiento y ataque automático de la criatura activa
function Companions.step(dt)
	for player, st in pairs(teams) do
		st.switchCd = math.max(0, (st.switchCd or 0) - dt)
		local ent = st.ent
		local root = hrp(player)
		if ent and ent.alive and root then
			local island = World.islandAt(root.Position)
			if island ~= nil and island ~= ent.island then
				-- el jugador cambió de isla: la criatura le sigue
				ent.island = island
				ent.pos = World.clampToIsland(island, root.Position, 4)
				ent.root.CFrame = CFrame.new(ent.pos + Vector3.new(0, 2, 0))
				ent.model:SetAttribute("Island", island)
				st.target = nil
			end
			if st.target and (not st.target.alive or st.target.island ~= ent.island or Core.dist(st.target.pos, root.Position) > 110) then
				st.target = nil
			end
			-- regeneración fuera de combate
			if not ent.lastHit or Core.time - ent.lastHit > 6 then
				if ent.hp < ent.maxHp then
					ent.hp = math.min(ent.maxHp, ent.hp + ent.maxHp * 0.05 * dt)
					ent.model:SetAttribute("HP", ent.hp)
				end
			end
			if not ent.dash and not Core.rooted(ent) and ent.castLock <= 0 then
				local goal
				local t = st.target
				if t and Core.time - st.lastCast < 12 then
					local q = ent.def.abilityByKey.q
					local want = ((q.type == "melee" or q.type == "dash") and (q.range * 0.8) or 18) + t.radius
					local d = Core.dist(ent.pos, t.pos)
					local dirT = Core.dirTo(ent.pos, t.pos)
					if d > want then
						goal = t.pos - dirT * want
					else
						goal = ent.pos
					end
					ent.facing = math.atan2(-dirT.X, -dirT.Z)
					-- ataque básico automático (Q) mientras dura el combate
					if ent.cds.q <= 0 and d <= (q.range or 18) + t.radius + 4 then
						ent.cds.q = q.cd * Core.cdrMul(ent)
						Core.cast(ent, q, { dir = dirT, pos = t.pos, target = t })
					end
				else
					local cf = root.CFrame
					goal = cf.Position - cf.LookVector * 7 + cf.RightVector * 5
					local dd = Core.flat(goal - ent.pos)
					if dd.Magnitude > 1 then
						ent.facing = math.atan2(-dd.Unit.X, -dd.Unit.Z)
					end
				end
				local delta = Core.flat(goal - ent.pos)
				local m = delta.Magnitude
				if m > 0.5 then
					local speed = math.max(ent.stats.speed * Core.speedMul(ent), 22)
					if m > 40 then
						speed = speed * 2.5
					end
					ent.pos = ent.pos + delta.Unit * math.min(m, speed * dt)
					ent.moving = true
				else
					ent.moving = false
				end
				ent.pos = World.clampToIsland(ent.island, ent.pos, 3)
			end
		end
	end
end

-- actualiza nivel y estadísticas sin volver a invocar (al subir de nivel o entrenar)
function Companions.refreshLevels(player)
	local st = teams[player]
	local p = DataService.get(player)
	if not st or not p then
		return
	end
	for i, s in ipairs(st.slots) do
		local own = p.creatures[s.id]
		if own and own.level ~= s.level then
			local stats = Formulas.stats(s.id, own.level, own.form, false)
			local ratio = (s.maxHp > 0) and (s.hp / s.maxHp) or 1
			s.level = own.level
			s.maxHp = stats.hp
			s.hp = stats.hp * ratio
			if i == st.active and st.ent and st.ent.alive then
				local e = st.ent
				local r = e.hp / e.maxHp
				e.level = own.level
				e.stats = stats
				e.maxHp = stats.hp
				e.hp = stats.hp * r
				e.model:SetAttribute("Level", e.level)
				e.model:SetAttribute("MaxHP", e.maxHp)
				e.model:SetAttribute("HP", e.hp)
			end
		end
	end
	Companions.publish(player)
end

-- publicación del estado del equipo a ~6 Hz
local acc = 0
function Companions.publishAll(dt)
	acc = acc + dt
	if acc < 0.16 then
		return
	end
	acc = 0
	for player in pairs(teams) do
		Companions.publish(player)
	end
end

function Companions.remove(player)
	local st = teams[player]
	if st and st.ent then
		Core.despawn(st.ent, false)
	end
	teams[player] = nil
end

function Companions.init()
	Core.hooks.teamOf = Companions.teamEntities
	Core.hooks.reviveTeam = Companions.reviveTeam
	Net.get("Cast").OnServerEvent:Connect(Companions.cast)
	Net.get("Switch").OnServerEvent:Connect(Companions.switch)
	Net.get("Dodge").OnServerEvent:Connect(Companions.dodge)
end

Companions.Players = Players
return Companions
