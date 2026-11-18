-- Dibuja (solo en local) las criaturas equipadas de cada jugador: le siguen flotando
-- y, cuando su dueño pica un meteorito, saltan a su alrededor "atacándolo".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Models = require(Shared:WaitForChild("Models"))
local Critters = require(Shared:WaitForChild("Critters"))

local Followers = {}

type Entry = { Key: string, Models: { Model }, Player: Player }

local entries: { [Player]: Entry } = {}
local folder: Folder
local meteorCache: { [number]: Model } = {}
local lastCache = 0

local function parse(value: any): { { Id: string, Shiny: boolean } }
	local list = {}
	if typeof(value) ~= "string" or value == "" then
		return list
	end
	for _, item in string.split(value, ",") do
		local id, shiny = string.match(item, "^([%w_]+):([01])$")
		if id and Critters.Exists(id) then
			table.insert(list, { Id = id, Shiny = shiny == "1" })
		end
	end
	return list
end

local function rebuild(player: Player)
	local value = player:GetAttribute("Critters")
	local key = if typeof(value) == "string" then value else ""
	local entry = entries[player]
	if entry and entry.Key == key then
		return
	end
	if entry then
		for _, model in entry.Models do
			model:Destroy()
		end
	end
	entry = { Key = key, Models = {}, Player = player }
	for _, item in parse(value) do
		local model = Models.BuildCritter(item.Id, { Shiny = item.Shiny, Scale = 1.1 })
		model.Parent = folder
		table.insert(entry.Models, model)
	end
	entries[player] = entry
end

local function watch(player: Player)
	rebuild(player)
	player:GetAttributeChangedSignal("Critters"):Connect(function()
		rebuild(player)
	end)
end

local function refreshMeteorCache()
	table.clear(meteorCache)
	local meteors = Workspace:FindFirstChild("Meteors")
	if not meteors then
		return
	end
	for _, child in meteors:GetChildren() do
		local id = child:GetAttribute("MeteorId")
		if child:IsA("Model") and typeof(id) == "number" then
			meteorCache[id] = child
		end
	end
end

function Followers.Init()
	folder = Instance.new("Folder")
	folder.Name = "LocalCritters"
	folder.Parent = Workspace

	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		local entry = entries[player]
		if entry then
			for _, model in entry.Models do
				model:Destroy()
			end
			entries[player] = nil
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		if t - lastCache > 0.5 then
			lastCache = t
			refreshMeteorCache()
		end
		local camera = Workspace.CurrentCamera
		local cameraPos = if camera then camera.CFrame.Position else Vector3.zero
		local alpha = 1 - math.exp(-dt * 7)
		for player, entry in entries do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and (root.Position - cameraPos).Magnitude < 220 then
				local targetId = player:GetAttribute("Target")
				local meteor = if typeof(targetId) == "number" then meteorCache[targetId] else nil
				local meteorPos = meteor and meteor:GetPivot().Position
				if meteorPos and (meteorPos - root.Position).Magnitude > 60 then
					meteorPos = nil
				end
				local count = #entry.Models
				for index, model in entry.Models do
					local primary = model.PrimaryPart
					if primary then
						local goal: CFrame
						if meteorPos and meteor then
							local radius = (meteor:GetAttribute("Radius") :: number?) or 4
							local angle = (index / math.max(count, 1)) * math.pi * 2 + t * 0.8
							local pos = meteorPos + Vector3.new(math.cos(angle) * (radius + 2.5), math.abs(math.sin(t * 9 + index)) * 1.6, math.sin(angle) * (radius + 2.5))
							goal = CFrame.lookAt(pos, Vector3.new(meteorPos.X, pos.Y, meteorPos.Z))
						else
							local spread = (index - (count + 1) / 2) * 3
							local offset = root.CFrame * CFrame.new(spread, -2.6 + math.sin(t * 3 + index) * 0.35 + 0.8, 4 + math.abs(spread) * 0.3)
							goal = CFrame.new(offset.Position) * root.CFrame.Rotation
						end
						primary.CFrame = primary.CFrame:Lerp(goal, alpha)
					end
				end
			end
		end
	end)
end

return Followers
