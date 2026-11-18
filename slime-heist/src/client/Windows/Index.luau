-- Index (colección): todos los slimes por mutación. Los no descubiertos salen como silueta.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Slimes = require(Shared:WaitForChild("Slimes"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local Mutations = require(Shared:WaitForChild("Mutations"))
local Format = require(Shared:WaitForChild("Format"))
local SlimeBuilder = require(Shared:WaitForChild("SlimeBuilder"))

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local State = require(Modules.State)

local Index = {
	Title = "📖 INDEX",
	Color = UI.Colors.Purple,
	Size = UDim2.fromOffset(760, 520),
}

type Cell = { Frame: Frame, Viewport: ViewportFrame, Name: TextLabel, Rarity: TextLabel, Key: string? }

local summary: TextLabel
local cells: { [string]: Cell } = {}
local filterButtons: { [string]: TextButton } = {}
local currentMutation = "Normal"

local function setViewportModel(cell: Cell, slimeId: string, mutation: string, discovered: boolean)
	local key = slimeId .. ":" .. mutation .. ":" .. tostring(discovered)
	if cell.Key == key then
		return
	end
	cell.Key = key
	for _, child in cell.Viewport:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
	local model = SlimeBuilder.Build(slimeId, mutation, { NoEffects = true, Silhouette = not discovered })
	model.Parent = cell.Viewport
	local S, H = SlimeBuilder.GetDimensions(slimeId)
	local camera = cell.Viewport.CurrentCamera
	if camera then
		local distance = S * 2.3 + 1
		camera.CFrame = CFrame.lookAt(Vector3.new(S * 0.55, H * 1.0, -distance), Vector3.new(0, H * 0.55, 0))
	end
end

local function setFilter(mutationName: string)
	currentMutation = mutationName
	for name, button in filterButtons do
		local def = Mutations.Get(name)
		UI.SetButtonColor(button, if name == mutationName then (if name == "Normal" then UI.Colors.Blue else UI.Darken(def.Color, 0.1)) else UI.Colors.Gray)
	end
	if State.Data then
		Index.Refresh(State.Data)
	end
end

function Index.Build(window)
	local content = window.Content
	summary = UI.Text({ Name = "Summary", Text = "", Size = UDim2.new(1, 0, 0, 30), TextColor3 = UI.Colors.Yellow, Parent = content })

	local filters = UI.New("Frame", { Name = "Filters", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 0, 36), Parent = content })
	UI.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center).Parent = filters
	for order, name in Mutations.DisplayOrder do
		local def = Mutations.Get(name)
		local label = if name == "Normal" then "Normal" else def.Icon .. " " .. name
		local button = UI.Button({
			Name = name,
			Text = label,
			Color = UI.Colors.Gray,
			Size = UDim2.fromOffset(132, 42),
			LayoutOrder = order,
			OnClick = function()
				setFilter(name)
			end,
			Parent = filters,
		})
		filterButtons[name] = button
	end

	local scroll = UI.New("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 88),
		Size = UDim2.new(1, 0, 1, -88),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = content,
	})
	UI.Grid(UDim2.fromOffset(124, 150), 10).Parent = scroll
	UI.Padding(4, 12, 8, 4).Parent = scroll

	for order, def in Slimes.List do
		local rarity = Rarities.Get(def.Rarity)
		local frame = UI.Panel({ Name = def.Id, Color = UI.Colors.PanelLight, LayoutOrder = order, Parent = scroll })
		local viewport = UI.New("ViewportFrame", {
			Name = "Viewport",
			BackgroundColor3 = UI.Darken(if rarity.Name == "Secret" then Color3.fromRGB(90, 90, 90) else rarity.Color, 0.55),
			BorderSizePixel = 0,
			Size = UDim2.new(1, -12, 0, 92),
			Position = UDim2.new(0.5, 0, 0, 6),
			AnchorPoint = Vector2.new(0.5, 0),
			Ambient = Color3.fromRGB(200, 200, 200),
			LightColor = Color3.fromRGB(255, 255, 255),
			LightDirection = Vector3.new(-1, -1, 1),
			Parent = frame,
		}, { UI.Corner(10) })
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local nameLabel = UI.Text({ Name = "SlimeName", Text = def.Name, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.new(0.5, 0, 0, 100), AnchorPoint = Vector2.new(0.5, 0), Parent = frame })
		local rarityLabel = UI.Text({ Name = "Rarity", Text = rarity.Name, TextColor3 = rarity.Color, StrokeColor = rarity.StrokeColor, Size = UDim2.new(1, -8, 0, 20), Position = UDim2.new(0.5, 0, 0, 124), AnchorPoint = Vector2.new(0.5, 0), Parent = frame })
		cells[def.Id] = { Frame = frame, Viewport = viewport, Name = nameLabel, Rarity = rarityLabel, Key = nil }
	end

	setFilter(currentMutation)
end

function Index.Refresh(data)
	local index = data.Index or {}
	local count = data.IndexCount or 0
	local total = data.IndexTotal or (#Slimes.List * 5)
	summary.Text = ("Discovered %d/%d  •  Income bonus +%s"):format(count, total, Format.Percent(count * Config.Income.IndexBonusPerEntry))
	for _, def in Slimes.List do
		local cell = cells[def.Id]
		if cell then
			local discovered = index[def.Id] ~= nil and index[def.Id][currentMutation] == true
			setViewportModel(cell, def.Id, currentMutation, discovered)
			cell.Name.Text = if discovered then def.Name else "???"
		end
	end
end

return Index
