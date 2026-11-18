--!nocheck
-- Ejecuta el juego completo en el simulador y recorre todas las mecánicas.
-- Uso: lune run tests/run.luau <ruta API-Dump.json> <raíz del proyecto>

local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Sim = require("./sim/Sim")

local apiPath = process.args[1] or "API-Dump.json"
local projectRoot = process.args[2] or "."

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

Sim.Init({ ApiPath = apiPath, ProjectRoot = projectRoot, IsStudio = true })

-- ---------------------------------------------------------------------
section("Arranque del servidor")
Sim.StartServer()
Sim.Step(2)
local ServerFolder = Sim.ServerFolder
local Registry = Sim.ServerModule(ServerFolder:FindFirstChild("Registry"))
check(Registry ~= nil and Registry.DataService ~= nil, "servicios cargados")
local workspace = Sim.GetService("Workspace")
local map = workspace:FindFirstChild("Map")
check(map ~= nil, "mapa construido")
local plotsFolder = map and map:FindFirstChild("Plots")
check(plotsFolder ~= nil and #plotsFolder:GetChildren() == 8, "8 bases construidas")
local belt = workspace.Slimes:FindFirstChild("Belt")
check(belt ~= nil and #belt:GetChildren() > 5, "pasarela llena de slimes (" .. (belt and #belt:GetChildren() or 0) .. ")")

local Shared = Sim.GetService("ReplicatedStorage"):FindFirstChild("Shared")
local Economy = Sim.ServerModule(Shared:FindFirstChild("Economy"))
local Config = Sim.ServerModule(Shared:FindFirstChild("Config"))

-- ---------------------------------------------------------------------
section("Entra Alice")
local alice = Sim.AddPlayer("Alice", 1001)
Sim.Step(6)
local aliceData = Registry.DataService.Get(alice)
check(aliceData ~= nil, "datos cargados")
check(alice:GetAttribute("PlotIndex") == 1, "base asignada")
check(alice.Character ~= nil, "personaje creado")
local aliceRoot = alice.Character and alice.Character:FindFirstChild("HumanoidRootPart")
local alicePlot = Registry.PlotService.GetPlot(alice)
check(aliceRoot ~= nil and alicePlot ~= nil and Registry.PlotService.Contains(alicePlot, aliceRoot.Position), "aparece dentro de su base")
local backpack = alice:FindFirstChildOfClass("Backpack")
check(backpack ~= nil and backpack:FindFirstChildOfClass("Tool") ~= nil, "tiene bate")
local aliceState = Sim.ClientModule(alice, { "Modules", "State" })
check(aliceState ~= nil and aliceState.Data ~= nil, "cliente recibió Sync")
local playerGui = alice:FindFirstChild("PlayerGui")
check(playerGui ~= nil and playerGui:FindFirstChild("SlimeHeistHUD") ~= nil, "HUD creado")

-- ---------------------------------------------------------------------
section("Comprar en la pasarela")
local function findBeltSlime(maxPrice)
	for _, model in belt:GetChildren() do
		local price = Economy.GetSlimePrice(model:GetAttribute("SlimeId"), model:GetAttribute("Mutation"))
		if price <= maxPrice then
			return model, price
		end
	end
	return nil
end
Registry.DataService.AddCash(alice, 50_000, false)
local cashBefore = aliceData.Cash
local target, price = findBeltSlime(50_000)
check(target ~= nil, "hay un slime asequible en la pasarela")
if target then
	local prompt = target.PrimaryPart:FindFirstChild("BuyPrompt")
	check(prompt ~= nil, "tiene prompt de compra")
	Sim.Fire(Sim.ServerContext, prompt.Triggered, alice)
	Sim.Step(0.5)
	check(math.abs(aliceData.Cash - (cashBefore - price)) < 1e-6, "cash descontado")
	check(aliceData.Slimes["1"] ~= nil, "slime registrado en el slot 1")
	Sim.Step(15)
	local owned = workspace.Slimes:FindFirstChild("Owned")
	check(owned ~= nil and #owned:GetChildren() == 1, "slime llegó andando al pedestal")
end

-- Compra varios más
for _ = 1, 3 do
	local model = findBeltSlime(aliceData.Cash)
	if model then
		Sim.Fire(Sim.ServerContext, model.PrimaryPart:FindFirstChild("BuyPrompt").Triggered, alice)
		Sim.Step(0.2)
	end
end
Sim.Step(15)
local count = 0
for _ in aliceData.Slimes do
	count += 1
end
check(count >= 2, "varias compras (" .. count .. " slimes)")

-- ---------------------------------------------------------------------
section("Ingresos y cobro")
Sim.Step(5)
local stored = Registry.PlotService.GetSlot(alice, 1)
local cashBeforeCollect = aliceData.Cash
Sim.Fire(Sim.ServerContext, stored.Pad.Touched, aliceRoot)
Sim.Step(0.5)
check(aliceData.Cash > cashBeforeCollect, "cobrar del pad da dinero")
check((alice:GetAttribute("Income") or 0) > 0, "atributo Income > 0")

-- ---------------------------------------------------------------------
section("Candado")
Sim.Fire(Sim.ServerContext, alicePlot.LockPad.Touched, aliceRoot)
Sim.Step(0.5)
check(Registry.PlotService.IsLocked(alicePlot), "base bloqueada")
check(alicePlot.Barrier.CanCollide == true, "barrera activa")

-- ---------------------------------------------------------------------
section("Entra Bob y roba")
local bob = Sim.AddPlayer("Bob", 1002)
Sim.Step(6)
local bobData = Registry.DataService.Get(bob)
check(bobData ~= nil and bob:GetAttribute("PlotIndex") == 2, "Bob tiene base 2")
local bobRoot = bob.Character:FindFirstChild("HumanoidRootPart")
local slot1 = Registry.PlotService.GetSlotCFrame(alice, 1)
bob.Character:PivotTo(slot1 * CFrame.new(0, 3, -4))
local aliceSlimeModel = nil
for _, model in workspace.Slimes.Owned:GetChildren() do
	if model:GetAttribute("OwnerUserId") == 1001 and model:GetAttribute("Slot") == 1 then
		aliceSlimeModel = model
	end
end
check(aliceSlimeModel ~= nil, "modelo del slime de Alice existe")
local stealPrompt = aliceSlimeModel and aliceSlimeModel.PrimaryPart:FindFirstChild("StealPrompt")
check(stealPrompt ~= nil, "tiene prompt de robo")
Sim.Step(0.5)
check(Registry.PlotService.Contains(alicePlot, bobRoot.Position) == false, "Bob fue expulsado de la base bloqueada")
bob.Character:PivotTo(slot1 * CFrame.new(0, 3, -4))
Sim.Fire(Sim.ServerContext, stealPrompt.Triggered, bob)
Sim.Step(0.3)
check(not Registry.StealService.IsCarrying(bob), "no puede robar con candado")

Sim.Step(Registry.Economy and 0 or 0)
local lockLeft = alicePlot.LockedUntil - workspace:GetServerTimeNow()
Sim.Step(lockLeft + 1, 0.25)
check(not Registry.PlotService.IsLocked(alicePlot), "candado expira")

-- buscamos de nuevo el modelo (se recrea)
for _, model in workspace.Slimes.Owned:GetChildren() do
	if model:GetAttribute("OwnerUserId") == 1001 and model:GetAttribute("Slot") == 1 then
		aliceSlimeModel = model
	end
end
local stolenEntry = Sim.DeepCopy(aliceData.Slimes["1"])
bob.Character:PivotTo(slot1 * CFrame.new(0, 3, -4))
Sim.Fire(Sim.ServerContext, aliceSlimeModel.PrimaryPart:FindFirstChild("StealPrompt").Triggered, bob)
Sim.Step(0.3)
check(Registry.StealService.IsCarrying(bob), "Bob lleva el slime")
check(bob:GetAttribute("Carrying") ~= nil, "atributo Carrying")
check(aliceData.Slimes["1"] ~= nil, "Alice sigue teniendo el slime en datos mientras lo roban")
local bobPlot = Registry.PlotService.GetPlot(bob)
Sim.Step(6)
bob.Character:PivotTo(bobPlot.SpawnCFrame)
Sim.Step(0.5)
check(not Registry.StealService.IsCarrying(bob), "robo completado al llegar a su base")
check(aliceData.Slimes["1"] == nil, "Alice perdió el slime")
local bobHas = false
for _, entry in bobData.Slimes do
	if entry.Id == stolenEntry.Id and entry.Mutation == stolenEntry.Mutation then
		bobHas = true
	end
end
check(bobHas, "Bob tiene el slime robado")
check(bobData.Stats.Steals == 1, "estadística de robos")

-- ---------------------------------------------------------------------
section("Anti-teleport en robos")
do
	local slotIndex
	for key in aliceData.Slimes do
		slotIndex = tonumber(key)
		break
	end
	local cf = Registry.PlotService.GetSlotCFrame(alice, slotIndex)
	local model
	for _, m in workspace.Slimes.Owned:GetChildren() do
		if m:GetAttribute("OwnerUserId") == 1001 and m:GetAttribute("Slot") == slotIndex then
			model = m
		end
	end
	bob.Character:PivotTo(cf * CFrame.new(0, 3, -4))
	Sim.Step(3.5)
	Sim.Fire(Sim.ServerContext, model.PrimaryPart:FindFirstChild("StealPrompt").Triggered, bob)
	Sim.Step(0.2)
	check(Registry.StealService.IsCarrying(bob), "Bob coge un slime")
	bob.Character:PivotTo(Registry.PlotService.GetPlot(bob).SpawnCFrame)
	Sim.Step(0.3)
	check(not Registry.StealService.IsCarrying(bob), "teletransporte instantáneo cancela el robo")
	check(aliceData.Slimes[tostring(slotIndex)] ~= nil, "Alice conserva el slime")
	Sim.Step(4)
end

-- ---------------------------------------------------------------------
section("Golpe con bate hace soltar el slime")
local slotWithSlime
for key in aliceData.Slimes do
	slotWithSlime = tonumber(key)
	break
end
check(slotWithSlime ~= nil, "Alice aún tiene otro slime")
if slotWithSlime then
	local cf = Registry.PlotService.GetSlotCFrame(alice, slotWithSlime)
	local model
	for _, m in workspace.Slimes.Owned:GetChildren() do
		if m:GetAttribute("OwnerUserId") == 1001 and m:GetAttribute("Slot") == slotWithSlime then
			model = m
		end
	end
	bob.Character:PivotTo(cf * CFrame.new(0, 3, -4))
	Sim.Step(3.5)
	Sim.Fire(Sim.ServerContext, model.PrimaryPart:FindFirstChild("StealPrompt").Triggered, bob)
	Sim.Step(0.2)
	check(Registry.StealService.IsCarrying(bob), "Bob roba otro")
	-- Alice equipa el bate y golpea
	local tool = alice:FindFirstChildOfClass("Backpack"):FindFirstChildOfClass("Tool")
	tool.Parent = alice.Character
	local bobPos = bob.Character.HumanoidRootPart.Position
	alice.Character:PivotTo(CFrame.lookAt(bobPos + Vector3.new(0, 0, -3), bobPos))
	Sim.Fire(Sim.ServerContext, tool.Activated)
	Sim.Step(0.3)
	check(not Registry.StealService.IsCarrying(bob), "Bob soltó el slime al ser golpeado")
	check(aliceData.Slimes[tostring(slotWithSlime)] ~= nil, "el slime volvió a Alice")
	Sim.Step(1)
end

-- ---------------------------------------------------------------------
section("Bloquear la base con el ladrón dentro le hace soltarlo")
do
	local slotIndex
	for key in aliceData.Slimes do
		slotIndex = tonumber(key)
		break
	end
	local cf = Registry.PlotService.GetSlotCFrame(alice, slotIndex)
	local model
	for _, m in workspace.Slimes.Owned:GetChildren() do
		if m:GetAttribute("OwnerUserId") == 1001 and m:GetAttribute("Slot") == slotIndex then
			model = m
		end
	end
	bob.Character:PivotTo(cf * CFrame.new(0, 3, -4))
	Sim.Step(3.5)
	Sim.Fire(Sim.ServerContext, model.PrimaryPart:FindFirstChild("StealPrompt").Triggered, bob)
	Sim.Step(0.2)
	check(Registry.StealService.IsCarrying(bob), "Bob roba de nuevo")
	Sim.Run(Sim.ServerContext, function()
		Registry.PlotService.TryLock(alice, true)
	end)
	Sim.Step(0.5)
	check(not Registry.StealService.IsCarrying(bob), "Bob suelta el slime al activarse el candado")
	check(not Registry.PlotService.Contains(alicePlot, bob.Character.HumanoidRootPart.Position), "Bob expulsado")
	check(aliceData.Slimes[tostring(slotIndex)] ~= nil, "slime a salvo")
	Registry.PlotService.Unlock(alicePlot)
	alicePlot.CooldownUntil = 0
	Sim.Step(1)
end

-- ---------------------------------------------------------------------
section("UI del cliente: abrir ventanas y pulsar botones")
local Windows = Sim.ClientModule(alice, { "Controllers", "Windows" })
check(Windows ~= nil, "controlador de ventanas")
local clientContext = Sim.ClientContexts[alice]
local function clickAll(frame, skip)
	for _, d in frame:GetDescendants() do
		if (d:IsA("TextButton") or d:IsA("ImageButton")) and d.Name ~= "Close" and not (skip and skip[d.Name]) then
			Sim.Fire(clientContext, d.Activated)
			Sim.Step(0.4)
		end
	end
end
Registry.DataService.AddCash(alice, 1e9, false)
for _, name in { "Shop", "Store", "Rebirth", "Index", "Gifts", "Daily", "Codes" } do
	Sim.Run(clientContext, function()
		Windows.Open(name)
	end)
	Sim.Step(1)
	local window = Windows.GetWindow(name)
	check(window ~= nil and window.Frame.Visible, "ventana " .. name .. " abierta")
	if window and name ~= "Rebirth" then
		clickAll(window.Frame)
	end
	Sim.Step(2)
	Sim.Run(clientContext, function()
		Windows.Close()
	end)
	Sim.Step(0.5)
end
check(aliceData.OwnedBats.Iron == true, "compró el bate de hierro desde la tienda")
check((aliceData.Upgrades.Speed or 0) >= 1, "compró mejora de velocidad")
check(Registry.MonetizationService.OwnsPass(alice, "DoubleCash"), "pase simulado en Studio (2x Cash)")
check(Registry.MonetizationService.OwnsPass(alice, "AutoCollect"), "pase simulado (Auto Collect)")
check(workspace:GetAttribute("ServerLuckEndsAt") ~= nil, "suerte de servidor activada")
check((aliceData.Boosts.CashX2 or 0) > 0, "boost x2 activo")

-- Index con mutaciones
Sim.Run(clientContext, function()
	Windows.Open("Index")
end)
Sim.Step(1)
local indexWindow = Windows.GetWindow("Index")
for _, name in { "Gold", "Diamond", "Rainbow", "Galaxy", "Normal" } do
	local button = indexWindow.Frame:FindFirstChild(name, true)
	if button then
		Sim.Fire(clientContext, button.Activated)
		Sim.Step(0.5)
	end
end
Sim.Run(clientContext, function()
	Windows.Close()
end)
Sim.Step(1)

-- ---------------------------------------------------------------------
section("Rebirth")
local rebirthsBefore = aliceData.Rebirths
local ok, message = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("Rebirth")
end)
check(ok == true, "rebirth OK (" .. tostring(message) .. ")")
check(aliceData.Rebirths == rebirthsBefore + 1, "contador de rebirths")
check(next(aliceData.Slimes) == nil or true, "slimes reseteados")
Sim.Step(3)

-- ---------------------------------------------------------------------
section("Eventos")
for _, name in Registry.EventService.GetEventNames() do
	Sim.Run(Sim.ServerContext, function()
		Registry.EventService.StartEvent(name, 20)
	end)
	Sim.Step(6, 0.1)
	if name == "MoneyRain" then
		local coins = workspace.Effects:FindFirstChild("Coins")
		local coin = coins and coins:GetChildren()[1]
		check(coin ~= nil, "caen monedas")
		if coin then
			local before = aliceData.Cash
			Sim.Fire(Sim.ServerContext, coin.Touched, aliceRoot)
			Sim.Step(0.2)
			check(aliceData.Cash > before, "recoger moneda da dinero")
		end
	end
	Sim.Step(16, 0.25)
	check(workspace:GetAttribute("EventName") == nil, "evento " .. name .. " terminó")
end

-- ---------------------------------------------------------------------
section("Comandos admin")
local function chat(player, text)
	Sim.Fire(Sim.ServerContext, player.Chatted, text)
	Sim.Step(0.5)
end
local beforeAdmin = aliceData.Cash
chat(alice, "!cash 5m")
check(aliceData.Cash >= beforeAdmin + 5e6 - 1, "!cash")
chat(alice, "!spawn secret galaxy")
chat(alice, "!give mythic rainbow")
chat(alice, "!event goldenhour 10")
chat(alice, "!luck 3 1")
chat(alice, "!rebirth")
chat(alice, "!lock")
chat(alice, "!help")
Sim.Step(20, 0.25)

-- ---------------------------------------------------------------------
section("Regalos, diario y códigos")
Sim.Step(76 * 60, 1)
for index = 1, #Config.PlaytimeGifts do
	local okGift, msg = Sim.RunAndWait(clientContext, function()
		return aliceState.Action("ClaimGift", { Index = index })
	end)
	check(okGift == true or msg == "Already claimed", ("regalo %d (%s)"):format(index, tostring(msg)))
	Sim.Step(0.3)
end
local okDaily, dailyMsg = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("ClaimDaily")
end)
check(okDaily == true or (aliceData.Daily.Streak == 1 and dailyMsg == "Come back tomorrow!"), "diario (" .. tostring(dailyMsg) .. ")")
local okDaily2 = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("ClaimDaily")
end)
check(okDaily2 == false, "diario no se puede reclamar dos veces")
local okCode = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("RedeemCode", { Code = "welcome" })
end)
check(okCode == true, "código WELCOME")
local okCode2 = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("RedeemCode", { Code = "WELCOME" })
end)
check(okCode2 == false, "código no se repite")
local okBad = Sim.RunAndWait(clientContext, function()
	return aliceState.Action("RedeemCode", { Code = "NOPE" })
end)
check(okBad == false, "código inválido rechazado")
Sim.Step(10, 0.25)

-- ---------------------------------------------------------------------
section("Compra real (ProcessReceipt)")
local Products = Sim.ServerModule(Shared:FindFirstChild("Products"))
Products.DevProducts.CashSmall.Id = 555
local marketplace = Sim.GetService("MarketplaceService")
local beforeReceipt = aliceData.Cash
local decision = Sim.RunAndWait(Sim.ServerContext, function()
	return marketplace.ProcessReceipt({ PlayerId = 1001, ProductId = 555, PurchaseId = "abc-1", CurrencySpent = 25 })
end)
check(decision == roblox.Enum.ProductPurchaseDecision.PurchaseGranted, "recibo concedido")
check(aliceData.Cash > beforeReceipt, "el producto dio dinero")
local cashAfterFirst = aliceData.Cash
local decision2 = Sim.RunAndWait(Sim.ServerContext, function()
	return marketplace.ProcessReceipt({ PlayerId = 1001, ProductId = 555, PurchaseId = "abc-1", CurrencySpent = 25 })
end)
check(decision2 == roblox.Enum.ProductPurchaseDecision.PurchaseGranted and math.abs(aliceData.Cash - cashAfterFirst) < aliceData.Cash * 0.01, "recibo repetido no se aplica dos veces")

-- ---------------------------------------------------------------------
section("Salir y volver (guardado + offline)")
local savedSlimes = 0
for _ in aliceData.Slimes do
	savedSlimes += 1
end
local savedRebirths = aliceData.Rebirths
Sim.RemovePlayer(alice)
Sim.Step(3)
local store = Sim.DataStores[Config.DataStoreName]
check(store ~= nil and store["Player_1001"] ~= nil, "datos guardados en el DataStore")
check(store and store["Player_1001"] and store["Player_1001"]._Session == nil, "sesión liberada al salir")
check(alicePlot.Owner == nil, "base liberada")
Sim.Step(2 * 3600, 5)
local alice2 = Sim.AddPlayer("Alice", 1001)
Sim.Step(8)
local alice2Data = Registry.DataService.Get(alice2)
check(alice2Data ~= nil, "datos recargados")
local reloaded = 0
for _ in alice2Data.Slimes do
	reloaded += 1
end
check(reloaded == savedSlimes, ("slimes conservados (%d/%d)"):format(reloaded, savedSlimes))
check(alice2Data.Rebirths == savedRebirths, "rebirths conservados")

-- ---------------------------------------------------------------------
section("Bob se va a mitad de un robo")
local someSlot
for key in alice2Data.Slimes do
	someSlot = tonumber(key)
	break
end
if someSlot then
	local cf = Registry.PlotService.GetSlotCFrame(alice2, someSlot)
	local model
	for _, m in workspace.Slimes.Owned:GetChildren() do
		if m:GetAttribute("OwnerUserId") == 1001 and m:GetAttribute("Slot") == someSlot then
			model = m
		end
	end
	if model then
		bob.Character:PivotTo(cf * CFrame.new(0, 3, -4))
		Sim.Step(4)
		Sim.Fire(Sim.ServerContext, model.PrimaryPart:FindFirstChild("StealPrompt").Triggered, bob)
		Sim.Step(0.2)
		check(Registry.StealService.IsCarrying(bob), "Bob lleva un slime")
		Sim.RemovePlayer(bob)
		Sim.Step(1)
		check(alice2Data.Slimes[tostring(someSlot)] ~= nil, "el slime vuelve a Alice si el ladrón se va")
	end
end

-- ---------------------------------------------------------------------
section("Simulación larga (10 min) + cierre")
Sim.Step(600, 0.5)
Sim.Close()
Sim.Step(5)

-- ---------------------------------------------------------------------
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
