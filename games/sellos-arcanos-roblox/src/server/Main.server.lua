-- Sellos Arcanos · arranque del servidor
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameData = require(Shared.GameData)
local Net = require(Shared.Net)
Net.init()

local DataService = require(script.Parent.DataService)
local World = require(script.Parent.WorldService)
local Progression = require(script.Parent.ProgressionService)
local Core = require(script.Parent.CombatCore)
local Companions = require(script.Parent.Companions)
local Encounters = require(script.Parent.Encounters)
local Shop = require(script.Parent.ShopService)

World.init()
DataService.init()
Progression.init()
Companions.init()
Encounters.init()
Shop.init()

-- cambios en el perfil que afectan a la criatura en el mundo
local REBUILD = { evolve = true, team = true, leader = true, equip = true, buyCosmetic = true, untint = true }
Progression.onChange = function(player, action)
	if REBUILD[action] then
		Companions.rebuild(player, true)
	elseif action == "train" then
		Companions.refreshLevels(player)
	end
end
Shop.onGranted = function(player)
	Companions.rebuild(player, true)
end

-- elegir la primera criatura
Net.get("ChooseStarter").OnServerEvent:Connect(function(player, id)
	local p = DataService.get(player)
	if not p or p.starterChosen or type(id) ~= "string" or not table.find(GameData.Starters, id) then
		return
	end
	p.creatures[id] = { form = 1, level = 1, xp = 0, bond = 2, bondXp = 0, tint = "" }
	p.bestiary[id].seen = true
	p.bestiary[id].forms[1] = true
	p.team = { id }
	p.starterChosen = true
	DataService.sync(player)
	Companions.rebuild(player, false)
	Progression.toast(player, "goPortal", {}, "gold")
end)

local function onCharacter(player)
	task.wait(0.3)
	player:SetAttribute("Island", 0)
	if DataService.get(player) and DataService.get(player).starterChosen then
		Companions.rebuild(player, true)
		Companions.restore(player)
	end
end

local function onPlayer(player)
	local p = DataService.load(player)
	Progression.ensureContracts(p)
	player:SetAttribute("Island", 0)
	Shop.loadPasses(player)
	Progression.dailyPerks(player, Shop.ownsPass(player, "vip"))
	DataService.sync(player)
	player.CharacterAdded:Connect(function()
		onCharacter(player)
	end)
	if player.Character then
		task.spawn(onCharacter, player)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, pl)
end
Players.PlayerRemoving:Connect(function(player)
	Companions.remove(player)
	DataService.release(player)
end)

-- isla de cada jugador (para enviar efectos solo a quien los ve)
task.spawn(function()
	while true do
		for _, pl in ipairs(Players:GetPlayers()) do
			local ch = pl.Character
			local root = ch and ch:FindFirstChild("HumanoidRootPart")
			if root then
				local island = World.islandAt(root.Position)
				if island ~= nil and pl:GetAttribute("Island") ~= island then
					pl:SetAttribute("Island", island)
					if island == 0 then
						Companions.restore(pl)
					end
				end
			end
		end
		task.wait(0.5)
	end
end)

-- bucle de simulación a 20 Hz
local STEP = 1 / 20
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc = acc + math.min(dt, 0.25)
	while acc >= STEP do
		acc = acc - STEP
		Companions.step(STEP)
		Encounters.step(STEP)
		Core.step(STEP)
		Companions.publishAll(STEP)
	end
end)

print("[Sellos Arcanos] servidor listo · " .. #GameData.Creatures .. " criaturas · " .. #GameData.Islands .. " islas")
