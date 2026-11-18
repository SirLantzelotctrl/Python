--!nocheck
-- Exporta la geometría de criaturas, huevos y meteoritos a JSON (para tests/tools/render.py sheet)
-- Uso: lune run tests/tools/export_models.luau <API-Dump.json> <raíz> <salida.json> [critters|eggs|meteors]
local Sim = require("../sim/Sim")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local process = require("@lune/process")
local Enum = require("@lune/roblox").Enum

Sim.Init({ ApiPath = process.args[1], ProjectRoot = process.args[2], IsStudio = true })
local Shared = Sim.GetService("ReplicatedStorage"):FindFirstChild("Shared")
local what = process.args[4] or "critters"
local out = {}

local function dump(model, label, mutation, rarity)
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" and d.Name ~= "LightPillar" and d.Transparency < 0.95 then
			local kind = "block"
			if d:FindFirstChildOfClass("SpecialMesh") then
				kind = "ellipsoid"
			elseif d.Shape == Enum.PartType.Cylinder then
				kind = "cylinder"
			elseif d.Shape == Enum.PartType.Ball then
				kind = "ellipsoid"
			end
			table.insert(parts, {
				name = d.Name, kind = kind, cf = { d.CFrame:GetComponents() }, size = { d.Size.X, d.Size.Y, d.Size.Z },
				color = { d.Color.R, d.Color.G, d.Color.B }, transparency = d.Transparency, neon = d.Material == Enum.Material.Neon,
			})
		end
	end
	-- "Body" usado por el renderizador para encuadrar
	table.insert(out, { name = label, mutation = mutation or "Normal", rarity = rarity or "", parts = parts })
end

Sim.RunAndWait(Sim.ServerContext, function()
	local Models = Sim.Require(Shared:FindFirstChild("Models"))
	local Critters = Sim.Require(Shared:FindFirstChild("Critters"))
	local Rarities = Sim.Require(Shared:FindFirstChild("Rarities"))
	if what == "critters" then
		for _, def in Critters.List do
			dump(Models.BuildCritter(def.Id), def.Name, "Normal", def.Rarity)
		end
		dump(Models.BuildCritter("glimmerfox", { Shiny = true }), "Glimmerfox", "Shiny", "Legendary")
		dump(Models.BuildCritter("moon_dragon", { Silhouette = true }), "Moon Dragon", "Silhouette", "Mythic")
	elseif what == "eggs" then
		for _, egg in Critters.Eggs do
			dump(Models.BuildEgg(egg.Index), egg.Name, "Normal", "")
		end
	else
		for zone = 1, 6 do
			local rarity = Rarities.List[math.min(zone + 1, #Rarities.List)]
			dump(Models.BuildMeteor(rarity.Name, zone), rarity.Name .. " Z" .. zone, "Normal", rarity.Name)
		end
		dump(Models.BuildMeteor("Cosmic", 6), "Cosmic", "Normal", "Cosmic")
		dump(Models.BuildMeteor("Mythic", 1, { Comet = true }), "COMET", "Normal", "Boss")
	end
end)
fs.writeFile(process.args[3], serde.encode("json", out))
print("exported", #out)
