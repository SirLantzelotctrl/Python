-- Utilidades de interfaz: paleta del diseño, marcos, textos, botones, barras,
-- avisos, carteles y ventanas. Todo se dibuja en una resolución de diseño de
-- 1280×720 y un UIScale lo adapta a móvil, tableta, PC y consola.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared.Strings)

local UI = {}
local player = Players.LocalPlayer

UI.C = {
	night = Color3.fromHex("#090817"),
	panel = Color3.fromRGB(15, 12, 32),
	panel2 = Color3.fromRGB(30, 25, 58),
	line = Color3.fromHex("#3b3658"),
	line2 = Color3.fromHex("#57517a"),
	ink = Color3.fromHex("#c4bfdc"),
	bright = Color3.fromHex("#f4f1fb"),
	muted = Color3.fromHex("#9e99bd"),
	dim = Color3.fromHex("#7d789c"),
	gold = Color3.fromHex("#ffd76a"),
	ok = Color3.fromHex("#7dffb0"),
	danger = Color3.fromHex("#ff6b7d"),
	inkBlue = Color3.fromHex("#8fd8ff"),
	crystal = Color3.fromHex("#ff9ee6"),
	essence = Color3.fromHex("#e3d4ff"),
	accent = Color3.fromHex("#b06bff"),
}
UI.F = {
	title = Enum.Font.Garamond,
	bold = Enum.Font.GothamBold,
	medium = Enum.Font.GothamMedium,
	body = Enum.Font.Gotham,
	lore = Enum.Font.SourceSansItalic,
}

UI.lang = "es"
local loc = string.lower(player.LocaleId or "es")
if string.sub(loc, 1, 2) ~= "es" then
	UI.lang = "en"
end

function UI.t(key, vars)
	return Strings.get(key, UI.lang, vars)
end

function UI.L(obj)
	if type(obj) ~= "table" then
		return tostring(obj)
	end
	return obj[UI.lang] or obj.es or ""
end

function UI.fmt(n)
	n = math.floor((n or 0) + 0.5)
	local s = tostring(n)
	local out = string.reverse(string.gsub(string.reverse(s), "(%d%d%d)", "%1 "))
	return (string.gsub(out, "^ ", ""))
end

-- --- raíz -----------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SellosArcanosUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
UI.gui = gui

local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundTransparency = 1
root.Size = UDim2.fromScale(1, 1)
root.Parent = gui
local scale = Instance.new("UIScale")
scale.Parent = root
UI.root = root

local function rescale()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local v = cam.ViewportSize
	local k = math.min(v.X / 1280, v.Y / 720)
	scale.Scale = math.clamp(k, 0.62, 1.5)
	-- el marco interior mide la pantalla dividida por la escala
	root.Size = UDim2.fromOffset(v.X / scale.Scale, v.Y / scale.Scale)
end
rescale()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

function UI.isTouch()
	local UIS = game:GetService("UserInputService")
	return UIS.TouchEnabled and not UIS.KeyboardEnabled
end

-- --- constructores ----------------------------------------------------------------
function UI.new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end

function UI.corner(o, r)
	UI.new("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o)
end

function UI.stroke(o, color, thick, transp)
	return UI.new("UIStroke", { Color = color or UI.C.line, Thickness = thick or 1.5, Transparency = transp or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end

function UI.pad(o, l, t, r, b)
	UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, l or 10), PaddingTop = UDim.new(0, t or l or 10),
		PaddingRight = UDim.new(0, r or l or 10), PaddingBottom = UDim.new(0, b or t or l or 10),
	}, o)
end

function UI.list(o, dir, gap, align)
	return UI.new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	}, o)
end

function UI.panel(parent, props)
	local f = UI.new("Frame", {
		BackgroundColor3 = UI.C.panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}, parent)
	for k, v in pairs(props or {}) do
		if k ~= "StrokeColor" then
			f[k] = v
		end
	end
	UI.corner(f, 8)
	UI.stroke(f, (props and props.StrokeColor) or UI.C.line, 1.5)
	return f
end

function UI.label(parent, text, size, font, color, props)
	local l = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text or "",
		TextSize = size or 16,
		Font = font or UI.F.medium,
		TextColor3 = color or UI.C.ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, (size or 16) + 6),
		TextWrapped = false,
		RichText = true,
	}, parent)
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end

function UI.button(parent, text, props, onClick)
	local primary = props and props.Primary
	local b = UI.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = primary and UI.C.bright or UI.C.panel2,
		BackgroundTransparency = 0.02,
		Text = text or "",
		TextSize = 15,
		Font = UI.F.bold,
		TextColor3 = primary and Color3.fromRGB(18, 15, 38) or UI.C.bright,
		Size = UDim2.fromOffset(160, 40),
		BorderSizePixel = 0,
	}, parent)
	for k, v in pairs(props or {}) do
		if k ~= "Primary" and k ~= "StrokeColor" then
			b[k] = v
		end
	end
	UI.corner(b, 6)
	local st = UI.stroke(b, (props and props.StrokeColor) or (primary and UI.C.bright or UI.C.line2), 1.5)
	b.MouseEnter:Connect(function()
		st.Color = UI.C.bright
	end)
	b.MouseLeave:Connect(function()
		st.Color = (props and props.StrokeColor) or (primary and UI.C.bright or UI.C.line2)
	end)
	if onClick then
		b.Activated:Connect(function()
			UI.click()
			onClick(b)
		end)
	end
	return b
end

function UI.bar(parent, color, height, props)
	local back = UI.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height or 6),
		ClipsDescendants = true,
	}, parent)
	for k, v in pairs(props or {}) do
		back[k] = v
	end
	local fill = UI.new("Frame", { BackgroundColor3 = color or UI.C.bright, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, back)
	return back, fill
end

function UI.setBar(fill, k)
	fill.Size = UDim2.fromScale(math.clamp(k or 0, 0, 1), 1)
end

-- --- sonido de interfaz -------------------------------------------------------------
local clickSound = UI.new("Sound", { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.25 }, gui)
function UI.click()
	clickSound.PlaybackSpeed = 1.4
	clickSound:Play()
end

-- --- avisos y carteles ---------------------------------------------------------------
local toastBox = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 300), Position = UDim2.new(0, 0, 0, 92), ZIndex = 50 }, root)
UI.list(toastBox, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)

function UI.toast(text, kind)
	local color = (kind == "gold" and UI.C.gold) or (kind == "good" and UI.C.ok) or (kind == "bad" and UI.C.danger) or UI.C.line2
	local f = UI.panel(toastBox, { AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), ZIndex = 50 })
	f:FindFirstChildOfClass("UIStroke").Color = color
	UI.pad(f, 14, 8)
	local l = UI.label(f, text, 16, UI.F.bold, UI.C.bright, { AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), ZIndex = 51, TextWrapped = true })
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(720, 200) }, l)
	task.delay(3.2, function()
		local tw = TweenService:Create(f, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
		tw:Play()
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end
		task.wait(0.35)
		f:Destroy()
	end)
end

local bannerLabel = UI.label(root, "", 44, UI.F.title, UI.C.bright, {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.new(1, 0, 0, 60),
	TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, TextStrokeColor3 = UI.C.night, TextTransparency = 1, ZIndex = 40,
})
local bannerSub = UI.label(root, "", 16, UI.F.bold, UI.C.muted, {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.3, 40), Size = UDim2.new(1, 0, 0, 22),
	TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 40,
})
local bannerToken = 0
function UI.banner(text, kind, sub, dur)
	bannerToken = bannerToken + 1
	local my = bannerToken
	bannerLabel.Text = string.upper(text)
	bannerLabel.TextColor3 = (kind == "gold" or kind == "seal") and UI.C.gold or UI.C.bright
	bannerLabel.TextSize = (kind == "boss") and 54 or 42
	bannerSub.Text = sub and string.upper(sub) or ""
	bannerLabel.TextTransparency = 0
	bannerSub.TextTransparency = 0
	bannerLabel.Position = UDim2.fromScale(0.5, 0.28)
	TweenService:Create(bannerLabel, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.3) }):Play()
	task.delay(dur or 2, function()
		if my == bannerToken then
			TweenService:Create(bannerLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(bannerSub, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

-- --- ventanas -------------------------------------------------------------------------
local modalLayer = UI.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 20, Active = true }, root)
UI.modalLayer = modalLayer
local current = nil

function UI.closeWindow()
	if current then
		current:Destroy()
		current = nil
	end
	modalLayer.Visible = false
	modalLayer.BackgroundTransparency = 1
	if UI.onWindowClosed then
		UI.onWindowClosed()
	end
end

-- ventana grande con título y botón de cerrar; devuelve el contenedor del cuerpo
function UI.window(title, w, h)
	UI.closeWindow()
	modalLayer.Visible = true
	modalLayer.BackgroundTransparency = 0.45
	local f = UI.panel(modalLayer, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(math.min(0.94, (w or 1000) / 1280 * 1.15), 0, math.min(0.92, (h or 600) / 720 * 1.12), 0),
		ZIndex = 21, BackgroundTransparency = 0.02,
	})
	local sizeLimit = UI.new("UISizeConstraint", { MaxSize = Vector2.new(w or 1000, h or 600) }, f)
	local _ = sizeLimit
	current = f
	UI.label(f, title, 30, UI.F.title, UI.C.bright, { Position = UDim2.fromOffset(22, 12), Size = UDim2.new(1, -110, 0, 38), ZIndex = 22 })
	local close = UI.button(f, "✕", { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -52, 0, 12), ZIndex = 23, TextSize = 18 }, function()
		UI.closeWindow()
	end)
	local _2 = close
	local body = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 62), Size = UDim2.new(1, -44, 1, -80), ZIndex = 22 }, f)
	return body, f
end

function UI.scroll(parent, props)
	local s = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = UI.C.line2,
		ZIndex = 22,
	}, parent)
	for k, v in pairs(props or {}) do
		s[k] = v
	end
	return s
end

-- confirmación sencilla dentro de la ventana actual
function UI.confirm(text, onYes)
	local layer = UI.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), ZIndex = 60, Active = true }, root)
	local f = UI.panel(layer, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, 170), ZIndex = 61 })
	UI.label(f, text, 18, UI.F.bold, UI.C.bright, { Position = UDim2.fromOffset(20, 18), Size = UDim2.new(1, -40, 0, 70), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 62 })
	UI.button(f, UI.t("no"), { Position = UDim2.new(1, -310, 1, -58), Size = UDim2.fromOffset(140, 42), ZIndex = 62 }, function()
		layer:Destroy()
	end)
	UI.button(f, UI.t("yes"), { Primary = true, Position = UDim2.new(1, -160, 1, -58), Size = UDim2.fromOffset(140, 42), ZIndex = 62 }, function()
		layer:Destroy()
		onYes()
	end)
end

-- ZIndex a todos los descendientes (los elementos dentro de ventanas)
function UI.z(o, z)
	if o:IsA("GuiObject") then
		o.ZIndex = z
	end
	for _, d in ipairs(o:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = z
		end
	end
end

return UI
