-- Personajes: aparecer en tu mejor zona, velocidad/salto, etiqueta sobre la cabeza
-- y bonus de amigos/grupo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)

local Registry = require(script.Parent.Parent.Registry)
local Actions = require(script.Parent.Parent.Actions)
local Net = require(script.Parent.Parent.Net)

local PlayerService = {}

local friendCounts: { [Player]: number } = {}
local friendPairs: { [Player]: { [Player]: boolean } } = {}
local groupMembers: { [Player]: boolean } = {}

function PlayerService.UpdateMovement(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local data = Registry.DataService.Get(player)
	if not humanoid or not data then
		return
	end
	local boots = Registry.MonetizationService.OwnsPass(player, "RocketBoots")
	humanoid.WalkSpeed = Economy.GetWalkSpeed(data.Upgrades.Speed or 0, boots)
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 7.2 + (if boots then Config.Player.BootsJump else 0)
end

function PlayerService.UpdateOverhead(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local data = Registry.DataService.Get(player)
	if not head or not data then
		return
	end
	local existing = head:FindFirstChild("Overhead")
	if existing then
		existing:Destroy()
	end
	local isVip = Registry.MonetizationService.OwnsPass(player, "VIP")
	if not isVip and data.Rebirths <= 0 then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Overhead"
	gui.Size = UDim2.new(6, 0, 0.9, 0)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 70
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	local parts = {}
	if isVip then
		table.insert(parts, "👑 VIP")
	end
	if data.Rebirths > 0 then
		table.insert(parts, "🌟 " .. data.Rebirths)
	end
	label.Text = table.concat(parts, "  ")
	label.TextColor3 = if isVip then Color3.fromRGB(255, 215, 60) else Color3.fromRGB(255, 160, 230)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = head
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then
		return
	end
	task.wait(0.1)
	if player.Character ~= character then
		return
	end
	Registry.ZoneService.Teleport(player, Registry.ZoneService.GetUnlocked(player))
	Registry.MiningService.GivePickaxe(player)
	PlayerService.UpdateMovement(player)
	PlayerService.UpdateOverhead(player)
end

function PlayerService.GetFriendCount(player: Player): number
	return friendCounts[player] or 0
end

function PlayerService.IsInGroup(player: Player): boolean
	return groupMembers[player] == true
end

local function checkFriends(player: Player)
	friendPairs[player] = friendPairs[player] or {}
	for _, other in Players:GetPlayers() do
		if other ~= player and friendPairs[other] and not friendPairs[player][other] then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWith(other.UserId)
			end)
			if ok and isFriend and player.Parent and other.Parent then
				friendPairs[player][other] = true
				friendPairs[other][player] = true
				friendCounts[player] = (friendCounts[player] or 0) + 1
				friendCounts[other] = (friendCounts[other] or 0) + 1
				Registry.StatsService.Invalidate(other)
				Net.Notify(other, ("👋 Your friend %s joined! +%d%% stardust"):format(player.DisplayName, math.floor(Config.Income.FriendBonus * 100)), "Success")
			end
		end
	end
	Registry.StatsService.Invalidate(player)
end

function PlayerService.Init()
	Actions.Register("RequestSync", function(player)
		Registry.DataService.MarkDirty(player)
		return true
	end)
end

function PlayerService.SetupPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	task.spawn(checkFriends, player)
	if Config.GroupId > 0 then
		task.spawn(function()
			local ok, inGroup = pcall(function()
				return player:IsInGroup(Config.GroupId)
			end)
			if ok and inGroup then
				groupMembers[player] = true
				Registry.StatsService.Invalidate(player)
			end
		end)
	end
end

function PlayerService.OnPlayerRemoving(player: Player)
	local friends = friendPairs[player]
	if friends then
		for other in friends do
			if friendPairs[other] then
				friendPairs[other][player] = nil
				friendCounts[other] = math.max(0, (friendCounts[other] or 1) - 1)
				Registry.StatsService.Invalidate(other)
			end
		end
	end
	friendPairs[player] = nil
	friendCounts[player] = nil
	groupMembers[player] = nil
end

return PlayerService
