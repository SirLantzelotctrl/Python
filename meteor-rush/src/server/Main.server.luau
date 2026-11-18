-- Punto de entrada del servidor: carga servicios, construye el mapa y gestiona
-- la entrada y salida de jugadores en el orden correcto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Shared.Remotes) -- crea los Remotes

local Registry = require(script.Parent.Registry)
local Actions = require(script.Parent.Actions)
local Net = require(script.Parent.Net)
local Services = script.Parent.Services

local SERVICE_ORDER = {
	"DataService",
	"MapService",
	"MonetizationService",
	"EventService",
	"StatsService",
	"ZoneService",
	"MeteorService",
	"CometService",
	"MiningService",
	"CritterService",
	"QuestService",
	"ShopService",
	"RebirthService",
	"RewardService",
	"PlayerService",
	"LeaderboardService",
	"AdminService",
}

for _, name in SERVICE_ORDER do
	Registry[name] = require(Services:FindFirstChild(name) :: ModuleScript)
end
for _, name in SERVICE_ORDER do
	local service = Registry[name]
	if service.Init then
		service.Init()
	end
end

Registry.MapService.Build()

Actions.Start()
for _, name in SERVICE_ORDER do
	local service = Registry[name]
	if service.Start then
		service.Start()
	end
end

local joined: { [Player]: boolean } = {}

local function onPlayerAdded(player: Player)
	if joined[player] then
		return
	end
	joined[player] = true
	local passesThread = task.spawn(Registry.MonetizationService.LoadPlayer, player)
	local data = Registry.DataService.Load(player)
	if not data or player.Parent ~= Players then
		return
	end
	while coroutine.status(passesThread) ~= "dead" do
		task.wait(0.1)
	end
	Registry.StatsService.Invalidate(player)
	Registry.CritterService.UpdateFollowers(player)
	Registry.QuestService.EnsureToday(player)
	Registry.RewardService.OnJoin(player)
	Registry.PlayerService.SetupPlayer(player)
	Registry.AdminService.SetupPlayer(player)
	Registry.DataService.MarkDirty(player)
	if not Registry.DataService.IsPersistent() then
		task.delay(3, function()
			Net.Notify(player, "⚠️ Data saving is OFF (Studio without API access). Progress won't save.", "Warning")
		end)
	end
end

local function onPlayerRemoving(player: Player)
	if not joined[player] then
		return
	end
	joined[player] = nil
	for _, step in {
		function()
			Registry.RewardService.OnPlayerRemoving(player)
		end,
		function()
			Registry.PlayerService.OnPlayerRemoving(player)
		end,
		function()
			Registry.LeaderboardService.OnPlayerRemoving(player)
		end,
	} do
		local ok, err = pcall(step)
		if not ok then
			warn("[Main] Error al salir " .. player.Name .. ": " .. tostring(err))
		end
	end
	Registry.DataService.Release(player)
	Registry.MonetizationService.OnPlayerRemoving(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

print(("[%s] Servidor listo ✅"):format(require(ReplicatedStorage.Shared.Config).GameName))
