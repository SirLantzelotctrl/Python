--!nocheck
-- Escenario: servidor en vivo (no Studio) SIN DataStores disponibles.
local process = require("@lune/process")
local Sim = require("./sim/Sim")
Sim.Init({ ApiPath = process.args[1] or "API-Dump.json", ProjectRoot = process.args[2] or ".", IsStudio = false, DataStoreFail = true })
Sim.StartServer()
Sim.Step(2)
local Registry = Sim.ServerModule(Sim.ServerFolder:FindFirstChild("Registry"))
local ok = true
local function check(cond, msg)
	print((cond and "  ✔ " or "  ✘ ") .. msg)
	ok = ok and cond
end
check(Registry.DataService.IsPersistent() == false, "detecta DataStore no disponible")
local p = Sim.AddPlayer("Carla", 2001)
Sim.Step(6)
check(Registry.DataService.Get(p) ~= nil, "juega igualmente con datos temporales")
local state = Sim.ClientModule(p, { "Modules", "State" })
local okSim = Sim.RunAndWait(Sim.ClientContexts[p], function()
	return state.Action("SimulatePurchase", { Kind = "Pass", Key = "VIP" })
end)
check(okSim == false, "simular compras desactivado fuera de Studio")
Sim.Fire(Sim.ServerContext, p.Chatted, "!stardust 1b")
Sim.Step(1)
check(Registry.DataService.Get(p).Stardust < 1e9, "comandos admin bloqueados para no-admins")
Sim.Step(120, 0.5)
Sim.RemovePlayer(p)
Sim.Step(3)
print(("Errores: %d, avisos: %d"):format(#Sim.Errors, #Sim.Warnings))
if not ok or #Sim.Errors > 0 then
	process.exit(1)
end
