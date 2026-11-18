-- Gestor de ventanas (una abierta a la vez) con el marco común: cabecera, título y botón de cerrar.

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local State = require(Modules.State)

local Windows = {}

export type Window = {
	Name: string,
	Frame: Frame,
	Content: Frame,
	Header: Frame,
	Title: TextLabel,
	Scale: UIScale,
}

export type WindowModule = {
	Title: string,
	Color: Color3,
	Size: UDim2?,
	Build: (window: Window) -> (),
	Refresh: ((data: { [string]: any }) -> ())?,
	Tick: (() -> ())?,
	OnOpen: (() -> ())?,
}

type Entry = { Module: WindowModule, Window: Window? }

local entries: { [string]: Entry } = {}
local current: string? = nil
local root: Frame
local dim: TextButton

Windows.Opened = nil :: ((name: string?) -> ())?

local function createWindow(name: string, module: WindowModule): Window
	local frame = UI.Panel({
		Name = name,
		Size = module.Size or UDim2.fromOffset(660, 450),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = UI.Colors.Panel,
		CornerRadius = 20,
		Visible = false,
		ZIndex = 2,
		Parent = root,
	})
	UI.Gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 215, 228)).Parent = frame

	local header = UI.New("Frame", {
		Name = "Header",
		BackgroundColor3 = module.Color,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 60),
		ZIndex = 2,
		Parent = frame,
	})
	UI.Corner(20).Parent = header
	UI.Gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190)).Parent = header
	-- Relleno para que las esquinas de abajo de la cabecera queden rectas
	UI.New("Frame", {
		Name = "Filler",
		BackgroundColor3 = module.Color,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		ZIndex = 2,
		Parent = header,
	}, { UI.Gradient(Color3.fromRGB(205, 205, 205), Color3.fromRGB(190, 190, 190)) })

	local title = UI.Text({
		Name = "Title",
		Text = module.Title,
		Size = UDim2.new(1, -90, 0, 40),
		Position = UDim2.new(0, 20, 0, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		ZIndex = 3,
		Parent = header,
	})

	local close = UI.Button({
		Name = "Close",
		Text = "X",
		Color = UI.Colors.Red,
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(1, -10, 0, 7),
		AnchorPoint = Vector2.new(1, 0),
		OnClick = function()
			Windows.Close()
		end,
		Parent = header,
	})
	close.ZIndex = 3

	local content = UI.New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 72),
		Size = UDim2.new(1, -32, 1, -86),
		ZIndex = 2,
		Parent = frame,
	})

	local scale = UI.New("UIScale", { Scale = 1, Parent = frame })
	return { Name = name, Frame = frame, Content = content, Header = header, Title = title, Scale = scale }
end

function Windows.Register(name: string, module: WindowModule)
	entries[name] = { Module = module, Window = nil }
end

function Windows.GetWindow(name: string): Window?
	local entry = entries[name]
	return entry and entry.Window
end

function Windows.IsOpen(name: string): boolean
	return current == name
end

function Windows.Open(name: string)
	local entry = entries[name]
	if not entry or current == name then
		return
	end
	if current then
		Windows.Close(true)
	end
	if not entry.Window then
		entry.Window = createWindow(name, entry.Module)
		entry.Module.Build(entry.Window :: Window)
	end
	local window = entry.Window :: Window
	current = name
	dim.Visible = true
	UI.Tween(dim, 0.2, { BackgroundTransparency = 0.55 })
	window.Frame.Visible = true
	window.Scale.Scale = 0.6
	UI.Tween(window.Scale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
	if entry.Module.OnOpen then
		entry.Module.OnOpen()
	end
	if entry.Module.Refresh and State.Data then
		entry.Module.Refresh(State.Data)
	end
	if Windows.Opened then
		Windows.Opened(name)
	end
end

function Windows.Close(instant: boolean?)
	if not current then
		return
	end
	local entry = entries[current]
	current = nil
	local window = entry and entry.Window
	if window then
		if instant then
			window.Frame.Visible = false
		else
			local tween = UI.Tween(window.Scale, 0.15, { Scale = 0.7 })
			tween.Completed:Once(function()
				if current ~= window.Name then
					window.Frame.Visible = false
				end
			end)
		end
	end
	if not instant then
		UI.Tween(dim, 0.15, { BackgroundTransparency = 1 })
		task.delay(0.16, function()
			if not current then
				dim.Visible = false
			end
		end)
	end
	if Windows.Opened then
		Windows.Opened(nil)
	end
end

function Windows.Toggle(name: string)
	if current == name then
		Windows.Close()
	else
		Windows.Open(name)
	end
end

-- Ventana de mensaje genérica (ganancias offline, avisos...)
local messageModule: WindowModule
local messageBody: TextLabel
local messageButton: TextButton
local messageButtonLabel: TextLabel
local messageCallback: (() -> ())? = nil

messageModule = {
	Title = "MESSAGE",
	Color = UI.Colors.Blue,
	Size = UDim2.fromOffset(500, 300),
	Build = function(window)
		messageBody = UI.Text({
			Name = "Body",
			Text = "",
			Size = UDim2.new(1, -20, 0, 120),
			Position = UDim2.new(0.5, 0, 0, 10),
			AnchorPoint = Vector2.new(0.5, 0),
			TextWrapped = true,
			Parent = window.Content,
		})
		messageButton, messageButtonLabel = UI.Button({
			Text = "OK",
			Color = UI.Colors.Green,
			Size = UDim2.fromOffset(200, 56),
			Position = UDim2.new(0.5, 0, 1, -8),
			AnchorPoint = Vector2.new(0.5, 1),
			OnClick = function()
				Windows.Close()
				if messageCallback then
					messageCallback()
				end
			end,
			Parent = window.Content,
		})
	end,
}

function Windows.ShowMessage(title: string, body: string, buttonText: string?, color: Color3?, callback: (() -> ())?)
	if current == "Message" then
		Windows.Close(true)
	end
	Windows.Open("Message")
	local window = Windows.GetWindow("Message")
	if not window then
		return
	end
	window.Title.Text = title
	window.Header.BackgroundColor3 = color or UI.Colors.Blue
	local filler = window.Header:FindFirstChild("Filler")
	if filler and filler:IsA("Frame") then
		filler.BackgroundColor3 = color or UI.Colors.Blue
	end
	messageBody.Text = body
	messageButtonLabel.Text = buttonText or "OK"
	messageCallback = callback
	local _ = messageButton
end

function Windows.Init()
	local _, screenRoot = UI.Screen("SlimeHeistWindows", 10)
	root = screenRoot
	dim = UI.New("TextButton", {
		Name = "Dim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Visible = false,
		ZIndex = 1,
		Parent = root,
	})
	dim.Activated:Connect(function()
		Windows.Close()
	end)

	Windows.Register("Message", messageModule)

	State.Changed:Connect(function(data)
		if current then
			local entry = entries[current]
			if entry and entry.Window and entry.Module.Refresh then
				entry.Module.Refresh(data)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			if current then
				local entry = entries[current]
				if entry and entry.Window and entry.Module.Tick then
					local ok, err = pcall(entry.Module.Tick)
					if not ok then
						warn("[Windows] Tick error: " .. tostring(err))
					end
				end
			end
		end
	end)
end

return Windows
