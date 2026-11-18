-- Aplica el empujón (knockback) cuando otro jugador te golpea con el bate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local Modules = script.Parent.Parent.Modules
local Sound = require(Modules.Sound)

local Combat = {}

local player = Players.LocalPlayer
local stunnedUntil = 0

function Combat.Init()
	Remotes.Event("Knockback").OnClientEvent:Connect(function(velocity)
		if typeof(velocity) ~= "Vector3" then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid then
			return
		end
		Sound.Play("Hit", 0.6)
		stunnedUntil = os.clock() + 1.1
		humanoid.PlatformStand = true
		root.AssemblyLinearVelocity = velocity
		root.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-4, 4), math.random(-8, 8))
		task.delay(1.15, function()
			if os.clock() >= stunnedUntil and humanoid.Parent then
				humanoid.PlatformStand = false
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end)
end

return Combat
