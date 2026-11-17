-- Partida simulada contra la lógica real del servidor.
local S = M.services

-- módulos con «script» propio y require por instancia
local cache = {}
local function makeModule(parent, name, path, class)
	local m = M.newInstance(class or "ModuleScript")
	m.Name = name
	m._source = path
	m.Parent = parent
	return m
end
local realRequire = require
function require(mod)
	if type(mod) == "table" and mod._source then
		if cache[mod] ~= nil then return cache[mod] end
		local env = setmetatable({ script = mod }, { __index = _G })
		local fn, e = load(readfile(mod._source), "@" .. mod._source, "t", env)
		if not fn then error(e) end
		local res = fn()
		cache[mod] = res
		return res
	end
	return realRequire(mod)
end

local shared = M.newInstance("Folder")
shared.Name = "Shared"
shared.Parent = S.ReplicatedStorage
for _, n in ipairs({ "GameData", "Config", "Formulas", "Net", "Strings" }) do
	makeModule(shared, n, "src/shared/" .. n .. ".lua")
end
local server = M.newInstance("Folder")
server.Name = "Server"
server.Parent = S.ServerScriptService
for _, n in ipairs({ "DataService", "WorldService", "ProgressionService", "CombatCore", "CreatureFactory", "Companions", "Encounters", "ShopService", "Codes" }) do
	makeModule(server, n, "src/server/" .. n .. ".lua")
end
local main = makeModule(server, "Main", "src/server/Main.server.lua", "Script")

-- cliente (StarterPlayerScripts/Client)
local client = M.newInstance("Folder")
client.Name = "Client"
for _, n in ipairs({ "UI", "State", "Hud", "Fx", "Sealing", "Menus" }) do
	makeModule(client, n, "src/client/" .. n .. ".lua")
end
local clientMain = makeModule(client, "Main", "src/client/Main.client.lua", "LocalScript")

-- productos configurados para la prueba
local Config = require(shared.Config)
Config.Products[2].id = 1111
Config.Products[5].id = 5555
Config.GroupId = 777

local function step(seconds)
	local n = math.floor(seconds / (1 / 30))
	for i = 1, n do
		S.RunService.Heartbeat:Fire(1 / 30)
		S.RunService.RenderStepped:Fire(1 / 30)
		M.advance(1 / 30)
		M.physics()
		M.flushClient()
	end
end

local function check(cond, msg)
	if cond then
		print("  ok  " .. msg)
	else
		M.err("FALLO: " .. msg)
	end
end

print("== arranque")
task.spawn(function() require(main) end)
check(workspace:FindFirstChild("Mundo") ~= nil, "se construye el mundo")
local Core = require(server.CombatCore)
local DataService = require(server.DataService)
local Companions = require(server.Companions)
local World = require(server.WorldService)
local GameData = require(shared.GameData)

print("== jugador entra y elige inicial")
local P = M.addPlayer(101, "Tester")
local PG = M.newInstance("PlayerGui")
PG.Name = "PlayerGui"
PG.Parent = P
rawset(S.Players, "LocalPlayer", P)
M.localPlayer = P
step(1)
local prof = DataService.get(P)
check(prof ~= nil, "perfil cargado")

print("== cliente")
task.spawn(function() require(clientMain) end)
step(2)
local UI = require(client.UI)
local Menus = require(client.Menus)
local State = require(client.State)
local Hud = require(client.Hud)
check(P:GetAttribute("ClientReady") == true, "el cliente arranca sin errores")
check(#PG:GetChildren() > 0, "interfaz creada en PlayerGui")
check(State.profile ~= nil, "el cliente recibe el perfil")
check(Menus.current == "starter", "se ofrece elegir criatura inicial")
local function buttonsWithText(t)
	local out = {}
	for _, b in ipairs(M.buttons(PG)) do if b.Text == t and not rawget(b, "_destroyed") then table.insert(out, b) end end
	return out
end
local chooseBtns = buttonsWithText(UI.t("choose"))
check(#chooseBtns == #GameData.Starters, "tres botones de elegir (" .. #chooseBtns .. ")")
M.click(chooseBtns[table.find(GameData.Starters, "basilisco")])
step(1)
check(prof.starterChosen and prof.creatures.basilisco ~= nil, "inicial elegida")
local st = Companions.state(P)
check(st and st.ent and st.ent.alive, "criatura invocada junto al jugador")
check(P:GetAttribute("TeamState") ~= nil, "estado del equipo publicado")

print("== viaje a la isla 1")
World.Hub.portals[1].Triggered:Fire(P)
step(1.5)
check(P:GetAttribute("Island") == 1, "jugador en la isla 1")
step(2)
check(st.ent.island == 1, "la criatura le sigue a la isla")
local wild = {}
for _, e in pairs(Core.entities) do if e.kind == "wild" and e.island == 1 then table.insert(wild, e) end end
check(#wild > 0, "aparecen criaturas salvajes (" .. #wild .. ")")

print("== combate (con las teclas del cliente)")
local target = wild[1]
local function modelOf(e)
	for _, m in ipairs(workspace.Criaturas:GetChildren()) do
		if m:GetAttribute("EntityId") == e.id then return m end
	end
end
check(modelOf(target) ~= nil, "el modelo del enemigo existe en el mundo")
P.Character.HumanoidRootPart.CFrame = CFrame.new(target.pos + Vector3.new(6, 3, 0))
step(0.2)
do
	-- debe apuntar al enemigo más cercano (normalmente el elegido)
	local tm = State.targetModel()
	local root = P.Character.HumanoidRootPart.Position
	local best, bd = nil, math.huge
	for _, m in ipairs(State.foes()) do
		local d = (State.modelPos(m) - root).Magnitude
		if d < bd then best, bd = m, d end
	end
	check(tm ~= nil and tm == best, "el cliente apunta al enemigo más cercano")
	if tm and tm ~= modelOf(target) then
		target = Core.entities[tm:GetAttribute("EntityId")] or target
	end
end
local hp0 = target.hp
for i = 1, 80 do
	M.press(({ "SA_Q", "SA_E", "SA_R", "SA_F" })[i % 4 + 1])
	if i % 7 == 0 then M.press("SA_Dodge") end
	if i % 20 == 0 then M.press("SA_Target") end
	P.Character.HumanoidRootPart.CFrame = CFrame.new(target.pos + Vector3.new(6, 3, 0))
	step(0.25)
	if target.sealable or not target.alive then break end
end
check(target.hp < hp0, "las teclas del cliente hacen daño (" .. math.floor(hp0) .. " → " .. math.floor(target.hp) .. ")")
if target.alive and not target.sealable then
	Core.damage(st.ent, target, 0, "m", nil, { raw = target.hp - target.maxHp * 0.2 })
end
check(target.sealable, "el enemigo queda sellable")
step(0.2)
check(modelOf(target):GetAttribute("Sealable") == true, "el cliente ve que es sellable")

print("== sellado (minijuego del cliente)")
P.Character.HumanoidRootPart.CFrame = CFrame.new(target.pos + Vector3.new(6, 3, 0))
M.press("SA_Seal")
step(0.6)
local sg = PG:FindFirstChild("SA_Sealing")
check(sg ~= nil and State.sealing, "se abre el minijuego de sellado")
local function nodeFrame(i)
	for _, d in ipairs(sg:GetDescendants()) do
		if d.ClassName == "TextLabel" and d.Text == tostring(i) and d.Parent.ClassName == "Frame" then return d.Parent end
	end
end
local nNodes = 0
while sg and nodeFrame(nNodes + 1) do nNodes = nNodes + 1 end
check(nNodes >= 4, "la runa tiene nodos (" .. nNodes .. ")")
local UIS = S.UserInputService
local function at(i)
	local pos = nodeFrame(i).Position
	return Vector3.new(pos.X.Offset, pos.Y.Offset - 36, 0)
end
if nNodes > 0 then
	UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = at(1) })
	for i = 2, nNodes do
		step(1 / 30)
		UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = at(i) })
	end
	UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = at(nNodes) })
end
step(2)
check(prof.creatures[target.creature] ~= nil, "criatura sellada añadida (" .. target.creature .. ")")
check(prof.stats.seals == 1, "estadística de sellos")
check(prof.stats.perfect == 1, "sellado perfecto registrado")
check(PG:FindFirstChild("SA_Sealing") == nil and not State.sealing, "el minijuego se cierra")

print("== combate largo (IA, estados, desmayos)")
for i = 1, 400 do
	local foes = Core.foesOf(st.ent or { island = 1, kind = "companion" })
	local t = foes[1]
	if st.ent and t then
		P.Character.HumanoidRootPart.CFrame = CFrame.new(t.pos + Vector3.new(5, 3, 0))
		S.ReplicatedStorage.Remotes.Cast.OnServerEvent:Fire(P, ({ "q", "e", "f" })[i % 3 + 1], t.id)
	end
	if i % 50 == 0 then S.ReplicatedStorage.Remotes.Switch.OnServerEvent:Fire(P, (i / 50) % 2 + 1) end
	step(0.1)
end
check(prof.stats.kills > 0, "derrotas registradas (" .. prof.stats.kills .. ")")

print("== jefe Primordial")
P.Character.HumanoidRootPart.CFrame = CFrame.new(World.Islands[1].altar + Vector3.new(0, 3, 0))
step(1)
Companions.restore(P)
World.Islands[1].bossPrompt.Triggered:Fire(P)
step(1)
local boss
for _, e in pairs(Core.entities) do if e.kind == "boss" then boss = e end end
check(boss ~= nil, "aparece el jefe")
if boss then
	Core.damage(st.ent or boss, boss, 0, "m", nil, { raw = boss.maxHp * 0.4 })
	step(2)
	check(boss.bossPhase == 2, "fase 2")
	Core.damage(st.ent or boss, boss, 0, "m", nil, { raw = boss.hp - boss.maxHp * 0.3 })
	step(1)
	check(boss.bossPhase == 3 and boss.invuln, "fase 3 con anclas")
	local anchors = {}
	for _, e in pairs(Core.entities) do if e.kind == "anchor" then table.insert(anchors, e) end end
	check(#anchors == 4, "cuatro anclas")
	for _, a in ipairs(anchors) do Core.damage(boss, a, 0, "m", nil, { raw = a.hp + 1 }) end
	step(1)
	check(not boss.invuln, "anclas rotas")
	Core.damage(boss, boss, 0, "m", nil, { raw = boss.hp - boss.maxHp * 0.2 })
	step(0.5)
	check(boss.sealable, "jefe sellable")
	local bp = S.ReplicatedStorage.Remotes.SealRequest.OnServerInvoke(P, boss.id)
	check(bp and bp.boss, "runa del jefe")
	step(2)
	S.ReplicatedStorage.Remotes.SealResult.OnServerEvent:Fire(P, boss.id, { done = true, errors = 1 })
	step(3)
	check(table.find(prof.islands.cleared, 1) ~= nil, "isla 1 completada")
	check(prof.islands.unlocked == 2, "isla 2 desbloqueada")
	check(prof.crystals >= 25, "cristales del primer sellado")
end

print("== menús y tienda")
local Action = S.ReplicatedStorage.Remotes.Action
check(Action.OnServerInvoke(P, "claimDaily") == true, "recompensa diaria")
prof.essence = 100000
check(Action.OnServerInvoke(P, "train", "basilisco") == true, "entrenar")
local other = target.creature
if other ~= "basilisco" then
	check(Action.OnServerInvoke(P, "team", other) == true or #prof.team >= 2, "equipo")
end
prof.crystals = 5000
check(Action.OnServerInvoke(P, "buyCosmetic", "tint", "basilisco_prisma") == true, "comprar tinte")
check(Action.OnServerInvoke(P, "buyCosmetic", "seal", "corona") == true, "comprar sello")
check(Action.OnServerInvoke(P, "equip", "seal", "hexagrama") == false, "no equipa sellos no comprados")
check(Action.OnServerInvoke(P, "passPremiumCrystals") == true, "pase premium con cristales")
prof.pass.xp = 500
check(Action.OnServerInvoke(P, "claimPass", 1, "free") == true, "reclamar pase gratis")
check(Action.OnServerInvoke(P, "claimPass", 1, "prem") == true, "reclamar pase premium")
prof.creatures.basilisco.level = 20
prof.fragments.veneno = 40
check(Action.OnServerInvoke(P, "evolve", "basilisco") == true, "evolucionar a Adulta")
check(prof.creatures.basilisco.form == 2, "forma Adulta")
step(1)

print("== interfaz: abrir menús y pulsar todos los botones")
local function alive(o)
	while o do
		if o == PG then return true end
		if rawget(o, "_destroyed") then return false end
		o = o.Parent
	end
	return false
end
-- abre el menú, pulsa el botón n.º i (reabriendo el menú cada vez, porque
-- muchos botones abren otra ventana) y confirma los diálogos
local function windowButtons()
	local out = {}
	for _, b in ipairs(M.buttons(UI.modalLayer)) do
		if alive(b) and b.Text ~= "✕" then table.insert(out, b) end
	end
	return out
end
prof.crystals = 100000
prof.essence = 1000000
prof.ink = 50
local total = 0
local menus = {
	{ "citadel", function() Menus.citadel() end },
	{ "bestiary", function() Menus.bestiary() end },
	{ "ficha", function() Menus.ficha("basilisco") end },
	{ "ficha2", function() Menus.ficha(other) end },
	{ "shop", function() Menus.shop() end },
	{ "shop-passes", function() Menus.shop("passes") end },
	{ "shop-tints", function() Menus.shop("tints") end },
	{ "shop-seals", function() Menus.shop("seals") end },
	{ "shop-effects", function() Menus.shop("effects") end },
	{ "pass", function() Menus.pass() end },
	{ "settings", function() Menus.settings() end },
}
local before = #M.errors
for _, mn in ipairs(menus) do
	local ok, e = pcall(mn[2])
	if not ok then M.err("menú " .. mn[1] .. ": " .. tostring(e)) end
	step(0.1)
	local n = #windowButtons()
	for i = 1, n do
		UI.closeWindow()
		pcall(mn[2])
		step(0.05)
		local b = windowButtons()[i]
		if b then
			M.click(b)
			total = total + 1
			step(0.05)
			for _, y in ipairs(buttonsWithText(UI.t("yes"))) do
				if alive(y) then M.click(y) step(0.05) end
			end
		end
	end
	UI.closeWindow()
	step(0.1)
end
local menuErrors = #M.errors - before
check(total > 30, "botones de menús pulsados (" .. total .. ")")
-- barra del HUD (abre/cierra menús)
local hudClicks = 0
for _, b in ipairs(M.buttons(PG)) do
	if alive(b) and not alive(UI.modalLayer) or (alive(b) and b:FindFirstAncestorOfClass("Frame") ~= UI.modalLayer) then
		M.click(b)
		hudClicks = hudClicks + 1
		step(0.05)
		UI.closeWindow()
	end
end
check(hudClicks > 0, "botones del HUD (" .. hudClicks .. ")")
check(menuErrors == 0, "sin errores en los menús")
Menus.shop()
step(0.5)
check(#buttonsWithText("R$ 199") >= 2, "la tienda muestra el precio real de Roblox")
check(M.priceQueries <= 4, "los precios se consultan una sola vez (" .. M.priceQueries .. ")")
UI.closeWindow()
for k = 1, 6 do M.press("SA_Sw" .. (k % 3 + 1)) step(0.3) end
check(Hud ~= nil, "HUD activo")

print("== códigos y grupo")
local function redeem(code)
	Menus.shop("codes")
	step(0.1)
	local box
	for _, d in ipairs(UI.modalLayer:GetDescendants()) do if d.Name == "CodeBox" then box = d end end
	box.Text = code
	M.click(buttonsWithText(UI.t("redeem"))[1])
	step(0.1)
end
local c0, e0 = prof.crystals, prof.essence
redeem("  sellos ")
check(prof.crystals == c0 + 25 and prof.essence == e0 + 500, "código SELLOS canjeado (sin distinguir mayúsculas)")
redeem("SELLOS")
check(prof.crystals == c0 + 25, "un código solo se canjea una vez")
redeem("NOEXISTE")
check(prof.crystals == c0 + 25, "código inventado rechazado")
check(Menus.current == "shop" and Menus.shopTab == "codes", "la pestaña de códigos sigue abierta")
-- 3 intentos hechos; el 4.º es válido, 5.º y 6.º fallan y el 7.º queda bloqueado
local inv = S.ReplicatedStorage.Remotes.Action.OnServerInvoke
check(inv(P, "redeem", "PRIMORDIAL") == true, "código PRIMORDIAL")
inv(P, "redeem", "AAAA")
inv(P, "redeem", "BBBB")
local ok1, err1 = inv(P, "redeem", "LANZAMIENTO")
check(ok1 == false and err1 == "codeWait", "límite de intentos contra fuerza bruta (" .. tostring(err1) .. ")")
M.advance(61)
check(inv(P, "redeem", "LANZAMIENTO") == true, "pasado un minuto se puede volver a canjear")
rawset(P, "IsInGroupAsync", function(_, id) return id == 777 end)
Menus.shop("codes")
step(0.1)
local cg = prof.crystals
M.click(buttonsWithText(UI.t("groupClaim"))[1])
step(0.2)
check(prof.crystals == cg + 30 and prof.perks.group, "recompensa por unirse al grupo")
check(#buttonsWithText(UI.t("groupClaim")) == 0, "la recompensa del grupo desaparece al reclamarla")
UI.closeWindow()

do
	local accepted = 0
	for _ = 1, 100 do
		if S.ReplicatedStorage.Remotes.Action.OnServerInvoke(P, "sync") then accepted = accepted + 1 end
	end
	check(accepted <= 40, "límite de acciones por jugador (" .. accepted .. " de 100)")
	M.advance(3)
end

print("== compra con Robux")
local MS = S.MarketplaceService
local before = prof.crystals
local r1 = MS.ProcessReceipt({ PlayerId = 101, ProductId = 1111, PurchaseId = "rec-1" })
local r2 = MS.ProcessReceipt({ PlayerId = 101, ProductId = 1111, PurchaseId = "rec-1" })
check(prof.crystals == before + 550, "cristales concedidos una sola vez")
MS.ProcessReceipt({ PlayerId = 101, ProductId = 5555, PurchaseId = "rec-2" })
check(prof.purchases.founder and table.find(prof.cosmetics.seals, "corona"), "Pack del Fundador")

print("== salida y guardado")
S.Players.PlayerRemoving:Fire(P)
step(1)
check(M.storeData["u_101"] and M.storeData["u_101"].data and M.storeData["u_101"].data.starterChosen, "perfil guardado en DataStore")

print("== reconexión")
local P2 = M.addPlayer(101, "Tester")
step(1)
local prof2 = DataService.get(P2)
check(prof2 and prof2.creatures.basilisco and prof2.creatures.basilisco.form == 2, "progreso recuperado")

local counts = {}
for _, f in ipairs(M.fired) do counts[f.remote] = (counts[f.remote] or 0) + 1 end
local list = {}
for k, v in pairs(counts) do table.insert(list, k .. "=" .. v) end
table.sort(list)
print("mensajes enviados: " .. table.concat(list, ", "))
