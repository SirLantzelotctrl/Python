--!nocheck
-- Ejecuta Meteor Rush completo en el simulador y recorre todas las mecánicas.
-- Uso: lune run tests/run.luau <API-Dump.json> <raíz del proyecto>

local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Sim = require("./sim/Sim")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local failures = {}
local passes = 0

local function check(condition, message)
	if condition then
		passes += 1
		print("  \27[32m✔\27[0m " .. message)
	else
		table.insert(failures, message)
		print("  \27[31m✘ " .. message .. "\27[0m")
	end
end

local function section(name)
	print("\n\27[36m== " .. name .. " ==\27[0m")
end

Sim.Init({ ApiPath = process.args[1] or "API-Dump.json", ProjectRoot = process.args[2] or ".", IsStudio = true })

-- ---------------------------------------------------------------------
section("Arranque del servidor")
Sim.StartServer()
Sim.Step(2)
local Registry = Sim.ServerModule(Sim.ServerFolder:FindFirstChild("Registry"))
check(Registry ~= nil and Registry.MeteorService ~= nil, "servicios cargados")
local workspace = Sim.GetService("Workspace")
local map = workspace:FindFirstChild("Map")
check(map ~= nil and map:FindFirstChild("Nebula") ~= nil, "6 zonas construidas")
local gates = 0
for _ in Registry.MapService.Gates do
	gates += 1
end
check(gates == 5, "5 puertas entre zonas")
check(#Registry.MapService.EggStands == 6, "6 soportes de huevos")
local Shared = Sim.GetService("ReplicatedStorage"):FindFirstChild("Shared")
local Config = Sim.ServerModule(Shared:FindFirstChild("Config"))

-- ---------------------------------------------------------------------
section("Entra Alice")
local alice = Sim.AddPlayer("Alice", 1001)
Sim.Step(6)
local aliceData = Registry.DataService.Get(alice)
check(aliceData ~= nil, "datos cargados")
check(alice.Character ~= nil and alice.Character:FindFirstChildOfClass("Tool") ~= nil, "pico equipado")
check(#aliceData.Quests.List == 3, "3 misiones diarias generadas")
local aliceState = Sim.ClientModule(alice, { "Modules", "State" })
check(aliceState and aliceState.Data and aliceState.Data.HitDamage == 1, "cliente recibió Sync con estadísticas")
check(alice.PlayerGui:FindFirstChild("MeteorRushHUD") ~= nil, "HUD creado")
local clientContext = Sim.ClientContexts[alice]

local function root(player)
	return player.Character:FindFirstChild("HumanoidRootPart")
end

local function landedMeteors(zone)
	local list = {}
	for _, meteor in Registry.MeteorService.GetAll() do
		if meteor.Landed and not meteor.Dead and (zone == nil or meteor.Zone == zone) then
			table.insert(list, meteor)
		end
	end
	return list
end

local function waitForMeteor(zone, maxSeconds)
	local waited = 0
	while waited < maxSeconds do
		local list = landedMeteors(zone)
		if #list > 0 then
			return list[1]
		end
		Sim.Step(0.5, 0.1)
		waited += 0.5
	end
	return nil
end

local function standNear(player, meteor)
	player.Character:PivotTo(CFrame.new(meteor.Position + Vector3.new(meteor.Radius + 3, 3, 0)))
end

-- ---------------------------------------------------------------------
section("Caen meteoritos y se pican")
local meteor = waitForMeteor(1, 30)
check(meteor ~= nil, "cae un meteorito en la Pradera")
check(#workspace.LocalFX:GetChildren() >= 0, "carpeta de efectos locales")
if meteor then
	standNear(alice, meteor)
	local tool = alice.Character:FindFirstChildOfClass("Tool")
	local before = aliceData.Stardust
	local swings = 0
	while not meteor.Dead and swings < 400 do
		Sim.Fire(Sim.ServerContext, tool.Activated)
		Sim.Step(0.42, 0.14)
		swings += 1
	end
	check(meteor.Dead, ("meteorito roto a golpes (%d golpes)"):format(swings))
	check(aliceData.Stardust > before, "da Stardust")
	check(aliceData.Stats.Meteors >= 1, "cuenta meteoritos rotos")
	check(aliceData.Stats.Swings > 0, "cuenta golpes")
end

-- ---------------------------------------------------------------------
section("Tienda de picos")
Registry.DataService.AddStardust(alice, 5_000, false)
local ok, msg = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("BuyPickaxe", { Id = "Iron" })
end)
check(ok == false, "no se puede saltar un pico (" .. tostring(msg) .. ")")
ok = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("BuyPickaxe", { Id = "Stone" })
end)
check(ok == true and aliceData.OwnedPickaxes.Stone, "compra el pico de piedra")
Sim.Step(0.5)
check(alice.Character:FindFirstChildOfClass("Tool").Name == "Stone Pick", "herramienta actualizada")
check(alice:GetAttribute("HitDamage") == 3, "daño por golpe 3")

-- ---------------------------------------------------------------------
section("Huevos y criaturas")
ok = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("Hatch", { Egg = 1, Amount = 1 })
end)
Sim.Step(0.5)
local critterCount = 0
for _ in aliceData.Critters do
	critterCount += 1
end
check(ok == true and critterCount == 1, "eclosiona un huevo")
check(#aliceData.Equipped == 1, "se equipa automáticamente")
check(alice:GetAttribute("Critters") ~= nil and alice:GetAttribute("Critters") ~= "", "atributo de seguidores")
check(alice:GetAttribute("HitDamage") > 3, "la criatura sube el daño")
local followers = workspace:FindFirstChild("LocalCritters")
check(followers ~= nil and #followers:GetChildren() >= 1, "el cliente dibuja la criatura que le sigue")
local ok3, msg3 = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("Hatch", { Egg = 1, Amount = 3 })
end)
check(ok3 == false, "eclosión triple requiere pase (" .. tostring(msg3) .. ")")
local okEgg2 = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("Hatch", { Egg = 2, Amount = 1 })
end)
check(okEgg2 == false, "huevo de zona bloqueada no se puede abrir")
Sim.Step(2)
-- Prompt físico del huevo
local stand = Registry.MapService.EggStands[1]
Sim.Fire(Sim.ServerContext, stand:FindFirstChild("Hatch1").Triggered, alice)
Sim.Step(1.5)
check(aliceData.Stats.Hatched == 2, "prompt del soporte de huevo")

-- ---------------------------------------------------------------------
section("Las criaturas ayudan a picar")
meteor = waitForMeteor(1, 30)
if meteor then
	standNear(alice, meteor)
	local hpBefore = meteor.HP
	Sim.Step(2.5)
	check(meteor.HP < hpBefore or meteor.Dead, "daño de ayudantes sin golpear")
	check(alice:GetAttribute("Target") ~= nil or meteor.Dead, "atributo Target para animar a las criaturas")
end

-- ---------------------------------------------------------------------
section("Zonas")
local okLocked = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("UnlockZone", { Zone = 3 })
end)
check(okLocked == false, "no se puede saltar una zona")
Registry.DataService.AddStardust(alice, 3_000, false)
ok = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("UnlockZone", { Zone = 2 })
end)
check(ok == true and aliceData.Zone == 2, "desbloquea el Desierto")
Sim.RunAndWait(clientContext, function()
	return aliceState.Action("TeleportZone", { Zone = 2 })
end)
Sim.Step(1)
check(alice:GetAttribute("Zone") == 2, "teletransporte a la zona 2")
alice.Character:PivotTo(CFrame.new(Vector3.new(420, 3, 0)))
Sim.Step(1)
check(alice:GetAttribute("Zone") ~= 3, "expulsado de una zona no desbloqueada")
local d2 = waitForMeteor(2, 30)
check(d2 ~= nil, "caen meteoritos en el Desierto con jugadores dentro")

-- ---------------------------------------------------------------------
section("Entra Bob: botín compartido y MVP")
local bob = Sim.AddPlayer("Bob", 1002)
Sim.Step(6)
local bobData = Registry.DataService.Get(bob)
check(bobData ~= nil, "Bob cargado")
Sim.RunAndWait(clientContext, function()
	return aliceState.Action("TeleportZone", { Zone = 1 })
end)
Sim.Step(1)
meteor = waitForMeteor(1, 30)
if meteor then
	standNear(alice, meteor)
	standNear(bob, meteor)
	local aliceBefore, bobBefore = aliceData.Stardust, bobData.Stardust
	local bobTool = bob.Character:FindFirstChildOfClass("Tool")
	local aliceTool = alice.Character:FindFirstChildOfClass("Tool")
	local n = 0
	while not meteor.Dead and n < 300 do
		Sim.Fire(Sim.ServerContext, aliceTool.Activated)
		Sim.Fire(Sim.ServerContext, bobTool.Activated)
		Sim.Step(0.42, 0.14)
		n += 1
	end
	check(meteor.Dead, "meteorito roto entre dos")
	check(aliceData.Stardust > aliceBefore and bobData.Stardust > bobBefore, "ambos reciben botín")
	check(aliceData.Stats.MVPs >= 1, "Alice (más daño) es MVP")
end

-- ---------------------------------------------------------------------
section("Comprar en la UI (Studio simula compras)")
local Windows = Sim.ClientModule(alice, { "Controllers", "Windows" })
Registry.DataService.AddStardust(alice, 1e12, false)
local function clickAll(frame)
	for _, d in frame:GetDescendants() do
		if (d:IsA("TextButton") or d:IsA("ImageButton")) and d.Name ~= "Close" and d.Name ~= "Delete" and d.Name ~= "Supernova" then
			Sim.Fire(clientContext, d.Activated)
			Sim.Step(0.5)
		end
	end
end
for _, name in { "Shop", "Critters", "Zones", "Quests", "Index", "Store", "Gifts", "Daily", "Codes", "Rebirth" } do
	Sim.Run(clientContext, function()
		Windows.Open(name)
	end)
	Sim.Step(1)
	local window = Windows.GetWindow(name)
	check(window ~= nil and window.Frame.Visible, "ventana " .. name)
	if window then
		clickAll(window.Frame)
	end
	Sim.Step(1.5)
	Sim.Run(clientContext, function()
		Windows.Close()
	end)
	Sim.Step(0.5)
end
check(aliceData.OwnedPickaxes.Iron == true, "compra picos desde la tienda")
check((aliceData.Upgrades.Crit or 0) >= 1, "compra mejoras")
check(Registry.MonetizationService.OwnsPass(alice, "AutoMine"), "pase Auto Mine simulado")
check(Registry.MonetizationService.OwnsPass(alice, "GalaxyHammer") and aliceData.Pickaxe == "Galaxy", "Galaxy Hammer equipado")
check(workspace:GetAttribute("ServerLuckEndsAt") ~= nil, "suerte de servidor")
check((aliceData.Boosts.Damage or 0) > 0 and (aliceData.Boosts.Stardust or 0) > 0, "Power Boost activo")
check(aliceData.Zone >= 3, "desbloquea zonas desde la ventana")
Sim.Step(30, 0.2)

-- ---------------------------------------------------------------------
section("Meteorito invocado (reservado)")
Sim.RunAndWait(clientContext, function()
	return aliceState.Action("SimulatePurchase", { Kind = "Product", Key = "SummonMeteor" })
end)
local summoned
for _, m in Registry.MeteorService.GetAll() do
	if m.ReservedFor == alice then
		summoned = m
	end
end
check(summoned ~= nil, "meteorito invocado junto a Alice")
if summoned then
	Sim.Step(Config.Meteors.WarningTime + 0.5)
	check(summoned.Landed, "aterriza")
	standNear(bob, summoned)
	local bobTool = bob.Character:FindFirstChildOfClass("Tool")
	Sim.Fire(Sim.ServerContext, bobTool.Activated)
	Sim.Step(0.3)
	check((summoned.Damage[bob] or 0) == 0, "Bob no puede picarlo mientras está reservado")
end

-- ---------------------------------------------------------------------
section("Cometa gigante")
-- Si había un cometa en marcha (comprado desde la tienda) lo rompemos primero
local function findComet()
	for _, m in Registry.MeteorService.GetAll() do
		if m.Comet then
			return m
		end
	end
	return nil
end
local comet = findComet()
if not comet then
	Sim.Fire(Sim.ServerContext, alice.Chatted, "!comet")
	Sim.Step(1)
	comet = findComet()
end
check(comet ~= nil, "el cometa se lanza")
if comet then
	Sim.Step(Config.Comet.WarningTime + 1, 0.25)
	check(comet.Landed, "el cometa aterriza en la plaza")
	local cometsBefore = aliceData.Stats.Comets
	Sim.Run(Sim.ServerContext, function()
		Registry.MeteorService.Damage(bob, comet, comet.MaxHP * 0.3)
		Registry.MeteorService.Damage(alice, comet, comet.MaxHP)
	end)
	Sim.Step(1)
	check(comet.Dead, "cometa destruido")
	check(aliceData.Stats.Comets == cometsBefore + 1 and bobData.Stats.Comets >= 1, "ambos reciben recompensa del cometa")
	check(workspace:GetAttribute("CometActive") == false, "estado del cometa reiniciado")
end

-- ---------------------------------------------------------------------
section("Misiones")
for index, quest in aliceData.Quests.List do
	Sim.Run(Sim.ServerContext, function()
		Registry.QuestService.Progress(alice, quest.Kind, quest.Target)
	end)
	Sim.Step(0.2)
	local okQuest = Sim.RunAndWait(clientContext, function()
		return aliceState.Action("ClaimQuest", { Index = index })
	end)
	check(okQuest == true or quest.Claimed, "misión " .. index .. " reclamada")
end
local okBonus = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("ClaimQuestBonus")
end)
check(okBonus == true, "premio de las 3 misiones")

-- ---------------------------------------------------------------------
section("Eventos")
for _, name in Registry.EventService.GetEventNames() do
	Sim.Run(Sim.ServerContext, function()
		Registry.EventService.StartEvent(name, 8)
	end)
	Sim.Step(2, 0.2)
	if name == "BloodMoon" then
		check(Registry.EventService.GetLuck() >= 3, "Luna de sangre sube la suerte")
	elseif name == "GoldenHour" then
		check(Registry.EventService.GetStardustMultiplier() == 2, "Hora dorada x2 stardust")
	elseif name == "MeteorShower" then
		check(Registry.EventService.GetSpawnRateMultiplier() == 3, "Lluvia de meteoritos")
	end
	Sim.Step(8, 0.25)
	check(workspace:GetAttribute("EventName") == nil, "evento " .. name .. " termina")
end

-- ---------------------------------------------------------------------
section("Comandos admin")
local function chat(text)
	Sim.Fire(Sim.ServerContext, alice.Chatted, text)
	Sim.Step(0.5)
end
local before = aliceData.Stardust
chat("!stardust 5m")
check(aliceData.Stardust >= before + 5e6 - 1, "!stardust")
chat("!meteor cosmic 1")
chat("!critter mythic shiny")
chat("!luck 3 1")
chat("!event bloodmoon 5")
chat("!zones")
check(aliceData.Zone == 6, "!zones")
chat("!help")
Sim.Step(10, 0.25)

-- ---------------------------------------------------------------------
section("Supernova")
local critters = 0
for _ in aliceData.Critters do
	critters += 1
end
local rebirthsBefore = aliceData.Rebirths
local okRebirth = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("Rebirth")
end)
check(okRebirth == true and aliceData.Rebirths == rebirthsBefore + 1, "supernova")
check(aliceData.Zone == 1, "zonas reiniciadas")
local critters2 = 0
for _ in aliceData.Critters do
	critters2 += 1
end
check(critters2 == critters, "criaturas conservadas")
Sim.Step(2)

-- ---------------------------------------------------------------------
section("Regalos, diario y códigos")
Sim.Step(76 * 60, 1)
local claimed = 0
for index = 1, #Config.PlaytimeGifts do
	local okGift, giftMsg = Sim.RunAndWait(clientContext, function()
		return aliceState.Action("ClaimGift", { Index = index })
	end)
	if okGift or giftMsg == "Already claimed" then
		claimed += 1
	end
	Sim.Step(0.3)
end
check(claimed == #Config.PlaytimeGifts, "todos los regalos")
local okDaily, dailyMsg = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("ClaimDaily")
end)
check(okDaily == true or dailyMsg == "Come back tomorrow!", "diario")
local okCode = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("RedeemCode", { Code = "meteor" })
end)
check(okCode == true, "código METEOR")
local okBad = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("RedeemCode", { Code = "NOPE" })
end)
check(okBad == false, "código inválido rechazado")

-- ---------------------------------------------------------------------
section("Compra real (ProcessReceipt)")
local Products = Sim.ServerModule(Shared:FindFirstChild("Products"))
Products.DevProducts.StardustSmall.Id = 777
local marketplace = Sim.GetService("MarketplaceService")
local beforeReceipt = aliceData.Stardust
local decision = Sim.RunAndWait(Sim.ServerContext, function()
	return marketplace.ProcessReceipt({ PlayerId = 1001, ProductId = 777, PurchaseId = "r-1", CurrencySpent = 25 })
end)
check(decision == roblox.Enum.ProductPurchaseDecision.PurchaseGranted and aliceData.Stardust > beforeReceipt, "recibo concedido")
local afterFirst = aliceData.Stardust
Sim.RunAndWait(Sim.ServerContext, function()
	return marketplace.ProcessReceipt({ PlayerId = 1001, ProductId = 777, PurchaseId = "r-1", CurrencySpent = 25 })
end)
check(aliceData.Stardust <= afterFirst + 1, "recibo repetido no se aplica dos veces")

-- ---------------------------------------------------------------------
section("Salir y volver")
local savedCritters = 0
for _ in aliceData.Critters do
	savedCritters += 1
end
local savedRebirths = aliceData.Rebirths
Sim.RemovePlayer(alice)
Sim.Step(3)
local store = Sim.DataStores[Config.DataStoreName]
check(store and store["Player_1001"] and store["Player_1001"]._Session == nil, "guardado y sesión liberada")
local alice2 = Sim.AddPlayer("Alice", 1001)
Sim.Step(8)
local data2 = Registry.DataService.Get(alice2)
local reloaded = 0
for _ in data2.Critters do
	reloaded += 1
end
check(reloaded == savedCritters and data2.Rebirths == savedRebirths, ("criaturas y supernovas conservadas (%d)"):format(reloaded))
check(alice2:GetAttribute("Critters") ~= nil, "seguidores restaurados")

-- ---------------------------------------------------------------------
section("Partida larga (10 min) + cierre")
Sim.Step(600, 0.5)
Sim.Close()
Sim.Step(5)

print("\n\27[36m== RESUMEN ==\27[0m")
print(("Comprobaciones OK: %d, fallidas: %d"):format(passes, #failures))
print(("Errores de ejecución: %d, avisos: %d"):format(#Sim.Errors, #Sim.Warnings))
local unimplemented = {}
for name, n in Sim.Unimplemented do
	table.insert(unimplemented, name .. " x" .. n)
end
table.sort(unimplemented)
if #unimplemented > 0 then
	print("Métodos sin simular (llamados): " .. table.concat(unimplemented, ", "))
end
for _, failure in failures do
	print("  FALLO: " .. failure)
end
if #failures > 0 or #Sim.Errors > 0 then
	process.exit(1)
end
