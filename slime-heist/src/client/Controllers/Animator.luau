-- Animaciones locales (no cuestan red): slimes que botan, arcoíris, glitch,
-- textos con degradado animado y monedas girando.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Animator = {}

type BodyEntry = { Mesh: SpecialMesh, Part: BasePart, Phase: number, Speed: number }

local bodies: { [BasePart]: BodyEntry } = {}
local rainbowParts: { [BasePart]: number } = {}
local glitchParts: { [BasePart]: boolean } = {}
local gradients: { [UIGradient]: boolean } = {}
local coins: { [BasePart]: CFrame } = {}

local MAX_ANIM_DISTANCE = 140

local function track(tagName: string, onAdded: (Instance) -> (), onRemoved: (Instance) -> ())
	CollectionService:GetInstanceAddedSignal(tagName):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal(tagName):Connect(onRemoved)
	for _, instance in CollectionService:GetTagged(tagName) do
		onAdded(instance)
	end
end

function Animator.Init()
	track("SlimeBody", function(instance)
		if instance:IsA("BasePart") then
			local mesh = instance:FindFirstChildOfClass("SpecialMesh")
			if mesh then
				bodies[instance] = { Mesh = mesh, Part = instance, Phase = math.random() * math.pi * 2, Speed = 3 + math.random() * 1.5 }
			end
		end
	end, function(instance)
		bodies[instance :: BasePart] = nil
	end)

	track("RainbowPart", function(instance)
		if instance:IsA("BasePart") then
			rainbowParts[instance] = math.random()
		end
	end, function(instance)
		rainbowParts[instance :: BasePart] = nil
	end)

	track("GlitchPart", function(instance)
		if instance:IsA("BasePart") then
			glitchParts[instance] = true
		end
	end, function(instance)
		glitchParts[instance :: BasePart] = nil
	end)

	track("RainbowGradient", function(instance)
		if instance:IsA("UIGradient") then
			gradients[instance] = true
		end
	end, function(instance)
		gradients[instance :: UIGradient] = nil
	end)

	track("Coin", function(instance)
		if instance:IsA("BasePart") then
			coins[instance] = instance.CFrame
		end
	end, function(instance)
		coins[instance :: BasePart] = nil
	end)

	local glitchTimer = 0
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local camera = Workspace.CurrentCamera
		local cameraPos = if camera then camera.CFrame.Position else Vector3.zero

		for part, entry in bodies do
			if part.Parent == nil then
				bodies[part] = nil
			elseif (part.Position - cameraPos).Magnitude < MAX_ANIM_DISTANCE then
				local s = math.sin(t * entry.Speed + entry.Phase) * 0.06
				entry.Mesh.Scale = Vector3.new(1 + s, 1 - s, 1 + s)
			end
		end

		for part, offset in rainbowParts do
			if part.Parent == nil then
				rainbowParts[part] = nil
			else
				part.Color = Color3.fromHSV((t * 0.25 + offset) % 1, 0.65, 1)
			end
		end

		for gradient in gradients do
			if gradient.Parent == nil then
				gradients[gradient] = nil
			else
				gradient.Offset = Vector2.new(((t * 0.6) % 2) - 1, 0)
			end
		end

		for coin in coins do
			if coin.Parent == nil then
				coins[coin] = nil
			else
				coin.CFrame = CFrame.new(coin.Position) * CFrame.Angles(0, t * 3, 0)
			end
		end

		glitchTimer += dt
		if glitchTimer > 0.12 then
			glitchTimer = 0
			for part in glitchParts do
				if part.Parent == nil then
					glitchParts[part] = nil
				else
					part.Transparency = if math.random() < 0.3 then 1 else 0
				end
			end
		end
	end)
end

return Animator
