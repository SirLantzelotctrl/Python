--!nocheck
-- Exporta la escena real (mapa + una base llena de slimes + pasarela) a JSON.
-- Uso: lune run tests/tools/export_scene.luau <API-Dump.json> <raíz proyecto> <salida.json>
local Sim = require("../sim/Sim")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local process = require("@lune/process")
local Enum = require("@lune/roblox").Enum

Sim.Init({ ApiPath = process.args[1], ProjectRoot = process.args[2], IsStudio = true })
Sim.StartServer()
Sim.Step(2)
local Registry = Sim.ServerModule(Sim.ServerFolder:FindFirstChild("Registry"))
local players = {}
for i, name in { "SlimeKing", "GooGirl" } do
	players[i] = Sim.AddPlayer(name, 3000 + i)
end
Sim.Step(6)
local ids = {
	{ "omega_slime", "Normal" }, { "void_emperor", "Normal" }, { "celestia_goo", "Normal" }, { "angel_ooze", "Normal" },
	{ "kraken_jelly", "Normal" }, { "phoenix_puddle", "Normal" }, { "dragoo", "Gold" }, { "king_gooberius", "Normal" },
	{ "witchy_wub", "Normal" }, { "pirate_plap", "Diamond" }, { "sir_jiggles", "Normal" }, { "zappy_zorp", "Normal" },
	{ "lava_lump", "Normal" }, { "frosty_flop", "Normal" },
}
Sim.RunAndWait(Sim.ServerContext, function()
	local data = Registry.DataService.Get(players[1])
	data.Rebirths = 3
	Registry.SlimeService.RefreshAll(players[1])
	for _, entry in ids do
		Registry.SlimeService.AddSlime(players[1], entry[1], entry[2])
	end
	for _, entry in { { "blobby", "Normal" }, { "wobblet", "Normal" }, { "mossy_mo", "Normal" }, { "bubble_bob", "Rainbow" }, { "gloop_jr", "Normal" } } do
		Registry.SlimeService.AddSlime(players[2], entry[1], entry[2])
	end
end)
Sim.Step(8)
local out = {}
local workspace = Sim.GetService("Workspace")
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "Root" and d.Name ~= "Boundary" then
		local kind = "block"
		local mesh = d:FindFirstChildOfClass("SpecialMesh")
		if mesh then
			kind = "ellipsoid"
		elseif d:IsA("Part") and d.Shape == Enum.PartType.Cylinder then
			kind = "cylinder"
		elseif d:IsA("Part") and d.Shape == Enum.PartType.Ball then
			kind = "ellipsoid"
		end
		local size = d.Size
		if d:IsA("Part") and d.Shape == Enum.PartType.Ball then
			local m = math.min(size.X, size.Y, size.Z)
			size = Vector3 and size or size
			size = { m, m, m }
		else
			size = { size.X, size.Y, size.Z }
		end
		table.insert(out, {
			name = d.Name, kind = kind, cf = { d.CFrame:GetComponents() }, size = size,
			color = { d.Color.R, d.Color.G, d.Color.B }, transparency = d.Transparency,
			neon = d.Material == Enum.Material.Neon,
		})
	end
end
fs.writeFile(process.args[3], serde.encode("json", out))
print("exported parts", #out)
