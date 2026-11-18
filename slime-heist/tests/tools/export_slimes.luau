-- Exporta la geometría de todos los slimes a JSON (para renderizarlos con render.py)
-- Uso: lune run tests/tools/export_slimes.luau <API-Dump.json> <raíz proyecto> <salida.json>
local Sim = require("../sim/Sim")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local process = require("@lune/process")
Sim.Init({ ApiPath = process.args[1], ProjectRoot = process.args[2], IsStudio = true })
local Shared = Sim.GetService("ReplicatedStorage"):FindFirstChild("Shared")
local out = {}
local Enum = require("@lune/roblox").Enum
Sim.RunAndWait(Sim.ServerContext, function()
	local SlimeBuilder = Sim.Require(Shared:FindFirstChild("SlimeBuilder"))
	local Slimes = Sim.Require(Shared:FindFirstChild("Slimes"))
	local list = {}
	for _, def in Slimes.List do
		table.insert(list, { def.Id, "Normal" })
	end
	for _, mut in { "Gold", "Diamond", "Rainbow", "Galaxy" } do
		table.insert(list, { "blobby", mut })
	end
	table.insert(list, { "dragoo", "Normal", true })
	for _, item in list do
		local model = SlimeBuilder.Build(item[1], item[2], { Silhouette = item[3] })
		local parts = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "Root" then
				local kind = "block"
				if d:FindFirstChildOfClass("SpecialMesh") then
					kind = "ellipsoid"
				elseif d:IsA("Part") and d.Shape == Enum.PartType.Cylinder then
					kind = "cylinder"
				elseif d:IsA("Part") and d.Shape == Enum.PartType.Ball then
					kind = "ellipsoid"
				end
				local cf = d.CFrame
				local c = { cf:GetComponents() }
				table.insert(parts, {
					name = d.Name, kind = kind,
					cf = c,
					size = { d.Size.X, d.Size.Y, d.Size.Z },
					color = { d.Color.R, d.Color.G, d.Color.B },
					transparency = d.Transparency,
					neon = d.Material == Enum.Material.Neon,
				})
			end
		end
		table.insert(out, { id = item[1], mutation = item[2], name = model.Name, rarity = model:GetAttribute("Rarity"), parts = parts })
	end
end)
fs.writeFile(process.args[3], serde.encode("json", out))
print("exported", #out)
