--!nocheck
-- Exporta una escena real del juego (zona 1 con meteoritos, cometa, jugadores y criaturas) a JSON.
-- Uso: lune run tests/tools/export_scene.luau <API-Dump.json> <raíz> <salida.json>
local Sim = require("../sim/Sim")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Enum, CFrame, Vector3 = roblox.Enum, roblox.CFrame, roblox.Vector3

Sim.Init({ ApiPath = process.args[1], ProjectRoot = process.args[2], IsStudio = true })
Sim.StartServer()
Sim.Step(2)
local Registry = Sim.ServerModule(Sim.ServerFolder:FindFirstChild("Registry"))
local players = {}
for i, name in { "Nova", "Rex", "Luna" } do
	players[i] = Sim.AddPlayer(name, 4000 + i)
end
Sim.Step(6)
Sim.RunAndWait(Sim.ServerContext, function()
	for i, player in players do
		for _, id in ({ { "glimmerfox", "buzzby", "starfawn" }, { "sphinxlet", "mirage_gecko", "dewdrop" }, { "frostwyrm", "aurora_owl", "icicub" } })[i] do
			Registry.CritterService.AddCritter(player, id, id == "glimmerfox")
		end
	end
	Registry.MeteorService.Spawn(1, "Legendary", { Position = Vector3.new(30, 0, -20) })
	Registry.MeteorService.Spawn(1, "Epic", { Position = Vector3.new(55, 0, 25) })
	Registry.MeteorService.Spawn(1, "Cosmic", { Position = Vector3.new(10, 0, 40) })
	Registry.MeteorService.Spawn(1, "Rare", { Position = Vector3.new(70, 0, -45) })
	Registry.CometService.Launch(nil)
end)
Sim.Step(14, 0.1)
-- Colocar jugadores picando
local spots = { Vector3.new(36, 3, -14), Vector3.new(25, 3, -26), Vector3.new(-30, 3, 10) }
for i, player in players do
	player.Character:PivotTo(CFrame.lookAt(spots[i], Vector3.new(30, 3, -20)))
end
for _, meteor in Registry.MeteorService.GetAll() do
	if meteor.Rarity == "Legendary" and not meteor.Comet then
		Sim.Run(Sim.ServerContext, function()
			Registry.MeteorService.Damage(players[1], meteor, meteor.MaxHP * 0.3)
			Registry.MeteorService.Damage(players[2], meteor, meteor.MaxHP * 0.2)
		end)
		players[1]:SetAttribute("Target", meteor.Id)
		players[2]:SetAttribute("Target", meteor.Id)
	end
end
-- Un meteorito cayendo (marcador + bola de fuego del cliente)
Sim.Run(Sim.ServerContext, function()
	Registry.MeteorService.Spawn(1, "Mythic", { Position = Vector3.new(80, 0, 10), WarningTime = 10 })
end)
Sim.Step(5, 0.05)

local out = {}
local workspace = Sim.GetService("Workspace")
local function add(name, kind, cf, size, color, transparency, neon)
	table.insert(out, { name = name, kind = kind, cf = { cf:GetComponents() }, size = size, color = color, transparency = transparency, neon = neon })
end
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "Root" and d.Name ~= "Boundary" and d.Name ~= "HumanoidRootPart" and d.Name ~= "Head" then
		local kind = "block"
		if d:FindFirstChildOfClass("SpecialMesh") or (d:IsA("Part") and d.Shape == Enum.PartType.Ball) then
			kind = "ellipsoid"
		elseif d:IsA("Part") and d.Shape == Enum.PartType.Cylinder then
			kind = "cylinder"
		end
		local size = { d.Size.X, d.Size.Y, d.Size.Z }
		if d:IsA("Part") and d.Shape == Enum.PartType.Ball then
			local m = math.min(d.Size.X, d.Size.Y, d.Size.Z)
			size = { m, m, m }
		end
		local transparency = d.Transparency
		if d.Material == Enum.Material.ForceField then
			transparency = math.max(transparency, 0.6)
		end
		add(d.Name, kind, d.CFrame, size, { d.Color.R, d.Color.G, d.Color.B }, transparency, d.Material == Enum.Material.Neon)
	end
end
-- Avatares sencillos para los jugadores
local skin = { 1, 0.8, 0.6 }
local shirts = { { 0.2, 0.5, 1 }, { 1, 0.35, 0.3 }, { 0.3, 0.8, 0.4 } }
for i, player in players do
	local cf = player.Character.HumanoidRootPart.CFrame
	add("Torso", "block", cf, { 2, 2, 1 }, shirts[i], 0, false)
	add("Head", "ellipsoid", cf * CFrame.new(0, 1.6, 0), { 1.3, 1.3, 1.3 }, skin, 0, false)
	add("LegL", "block", cf * CFrame.new(-0.5, -2, 0), { 0.9, 2, 0.9 }, { 0.2, 0.2, 0.3 }, 0, false)
	add("LegR", "block", cf * CFrame.new(0.5, -2, 0), { 0.9, 2, 0.9 }, { 0.2, 0.2, 0.3 }, 0, false)
	add("ArmL", "block", cf * CFrame.new(-1.5, 0, 0), { 0.9, 2, 0.9 }, skin, 0, false)
	add("ArmR", "block", cf * CFrame.new(1.5, 0.3, -0.6) * CFrame.Angles(math.rad(70), 0, 0), { 0.9, 2, 0.9 }, skin, 0, false)
end
fs.writeFile(process.args[3], serde.encode("json", out))
print("exported parts", #out, "errors", #Sim.Errors)
