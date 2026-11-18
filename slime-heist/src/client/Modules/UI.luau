-- Mini librería de UI: estilo cartoon (FredokaOne, bordes gruesos, degradados).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Sound = require(script.Parent.Sound)

local UI = {}

UI.Font = Enum.Font.FredokaOne

UI.Colors = {
	Panel = Color3.fromRGB(36, 40, 66),
	PanelLight = Color3.fromRGB(52, 58, 92),
	PanelDark = Color3.fromRGB(24, 27, 46),
	Stroke = Color3.fromRGB(12, 13, 24),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(190, 196, 225),
	Green = Color3.fromRGB(60, 210, 95),
	Blue = Color3.fromRGB(60, 150, 255),
	Red = Color3.fromRGB(240, 70, 85),
	Yellow = Color3.fromRGB(255, 200, 50),
	Orange = Color3.fromRGB(255, 145, 50),
	Purple = Color3.fromRGB(165, 95, 255),
	Pink = Color3.fromRGB(255, 95, 185),
	Cyan = Color3.fromRGB(50, 215, 230),
	Gray = Color3.fromRGB(110, 116, 140),
	Cash = Color3.fromRGB(120, 255, 140),
}

function UI.Darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function UI.Lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

-- Crea una instancia con propiedades e hijos
function UI.New(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UI.Corner(radius: number?): UICorner
	return UI.New("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UI.Stroke(thickness: number?, color: Color3?, border: boolean?): UIStroke
	return UI.New("UIStroke", {
		Thickness = thickness or 3,
		Color = color or UI.Colors.Stroke,
		ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function UI.Gradient(top: Color3, bottom: Color3, rotation: number?): UIGradient
	return UI.New("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

function UI.Padding(top: number, right: number?, bottom: number?, left: number?): UIPadding
	return UI.New("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right or top),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or right or top),
	})
end

function UI.List(direction: Enum.FillDirection?, padding: number?, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?): UIListLayout
	return UI.New("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 8),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function UI.Grid(cellSize: UDim2, padding: number?): UIGridLayout
	return UI.New("UIGridLayout", {
		CellSize = cellSize,
		CellPadding = UDim2.fromOffset(padding or 10, padding or 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
end

-- Texto con borde
function UI.Text(props: { [string]: any }): TextLabel
	local strokeThickness = props.StrokeThickness
	local strokeColor = props.StrokeColor
	props.StrokeThickness = nil
	props.StrokeColor = nil
	local label = UI.New("TextLabel", {
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextScaled = true,
		TextColor3 = UI.Colors.Text,
		Size = UDim2.fromScale(1, 1),
	})
	for key, value in props do
		if key ~= "Parent" then
			(label :: any)[key] = value
		end
	end
	if strokeThickness ~= 0 then
		UI.Stroke(strokeThickness or 2, strokeColor or UI.Colors.Stroke).Parent = label
	end
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

-- Panel con fondo, esquinas y borde
function UI.Panel(props: { [string]: any }): Frame
	local color = props.Color or UI.Colors.Panel
	local radius = props.CornerRadius or 14
	props.Color = nil
	props.CornerRadius = nil
	local frame = UI.New("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	})
	for key, value in props do
		if key ~= "Parent" then
			(frame :: any)[key] = value
		end
	end
	UI.Corner(radius).Parent = frame
	UI.Stroke(3, UI.Colors.Stroke, true).Parent = frame
	if props.Parent then
		frame.Parent = props.Parent
	end
	return frame
end

export type ButtonProps = {
	Name: string?,
	Text: string?,
	Color: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	TextSizeScale: number?,
	OnClick: (() -> ())?,
	Parent: Instance?,
}

-- Botón cartoon con animación al pasar/pulsar
function UI.Button(props: ButtonProps): (TextButton, TextLabel)
	local color = props.Color or UI.Colors.Green
	local button = UI.New("TextButton", {
		Name = props.Name or "Button",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromOffset(160, 50),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		LayoutOrder = props.LayoutOrder or 0,
	})
	UI.Corner(12).Parent = button
	local stroke = UI.Stroke(3, UI.Darken(color, 0.55), true)
	stroke.Name = "Border"
	stroke.Parent = button
	UI.Gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 200), 90).Parent = button
	local scale = UI.New("UIScale", { Scale = 1, Parent = button })

	local textScale = props.TextSizeScale or 0.72
	local label = UI.Text({
		Name = "Label",
		Text = props.Text or "",
		Size = UDim2.new(1, -12, textScale, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = button,
	})

	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.93 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		Sound.Play("Click", 0.35)
		if props.OnClick then
			task.spawn(props.OnClick)
		end
	end)
	if props.Parent then
		button.Parent = props.Parent
	end
	return button, label
end

function UI.SetButtonColor(button: GuiObject, color: Color3)
	button.BackgroundColor3 = color
	local stroke = button:FindFirstChild("Border")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = UI.Darken(color, 0.55)
	end
end

function UI.Tween(instance: Instance, duration: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	tween:Play()
	return tween
end

-- ScreenGui con escala automática según el tamaño de pantalla (móvil/PC).
-- Truco estándar: un Frame raíz de tamaño 1/escala con un UIScale = escala
-- ocupa exactamente la pantalla y escala todo su contenido.
local scales: { { Scale: UIScale, Root: Frame } } = {}

local function computeScale(): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 760)
	if viewport.X <= 1 or viewport.Y <= 1 then
		return 1
	end
	return math.clamp(math.min(viewport.X / 1280, viewport.Y / 760), 0.52, 1.2)
end

local function applyScale(entry: { Scale: UIScale, Root: Frame }, value: number)
	entry.Scale.Scale = value
	entry.Root.Size = UDim2.fromScale(1 / value, 1 / value)
end

local function updateScales()
	local value = computeScale()
	for _, entry in scales do
		applyScale(entry, value)
	end
end

local cameraConnection: RBXScriptConnection? = nil
local function watchCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScales)
	updateScales()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

function UI.GetScale(): number
	return computeScale()
end

function UI.Screen(name: string, displayOrder: number): (ScreenGui, Frame)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = UI.New("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder,
		Parent = playerGui,
	})
	-- Contenedor escalado (lo escalamos entero para que todo quede proporcionado)
	local root = UI.New("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screen,
	})
	local entry = { Scale = UI.New("UIScale", { Parent = root }), Root = root }
	applyScale(entry, computeScale())
	table.insert(scales, entry)
	return screen, root
end

return UI
