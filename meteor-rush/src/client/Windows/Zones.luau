-- Zonas: desbloquear la siguiente y teletransportarte a las que ya tienes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared:WaitForChild("Zones"))
local Format = require(Shared:WaitForChild("Format"))

local Modules = script.Parent.Parent.Modules
local UI = require(Modules.UI)
local State = require(Modules.State)

local Windows = require(script.Parent.Parent.Controllers.Windows)
local Notifications = require(script.Parent.Parent.Controllers.Notifications)

local ZonesWindow = {
	Title = "🗺️ ZONES",
	Color = UI.Colors.Blue,
	Size = UDim2.fromOffset(640, 500),
}

local rows: { [number]: { Button: TextButton, Label: TextLabel, Info: TextLabel } } = {}

function ZonesWindow.Build(window)
	local scroll = UI.New("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		Parent = window.Content,
	})
	UI.List(Enum.FillDirection.Vertical, 8).Parent = scroll
	UI.Padding(4, 12, 8, 4).Parent = scroll
	for _, zone in Zones.List do
		local frame = UI.Panel({ Name = zone.Id, Color = UI.Darken(zone.GroundColor, 0.45), Size = UDim2.new(1, 0, 0, 70), LayoutOrder = zone.Index, Parent = scroll })
		UI.Text({ Name = "Icon", Text = zone.Icon, Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), StrokeThickness = 0, Parent = frame })
		UI.Text({ Name = "ZoneName", Text = zone.Name, Size = UDim2.new(1, -260, 0, 30), Position = UDim2.new(0, 72, 0, 8), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = zone.AccentColor, Parent = frame })
		local info = UI.Text({ Name = "Info", Text = "", Size = UDim2.new(1, -260, 0, 22), Position = UDim2.new(0, 72, 0, 40), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.SubText, Parent = frame })
		local button, label = UI.Button({
			Name = "Action",
			Text = "",
			Size = UDim2.fromOffset(170, 50),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			OnClick = function()
				local data = State.Data
				if not data then
					return
				end
				if zone.Index <= (data.Zone or 1) then
					local ok, message = State.Action("TeleportZone", { Zone = zone.Index })
					if ok then
						Windows.Close()
					elseif message then
						Notifications.Show(message, "Error")
					end
				else
					local ok, message = State.Action("UnlockZone", { Zone = zone.Index })
					if message then
						Notifications.Show(message, if ok then "Success" else "Error")
					end
				end
			end,
			Parent = frame,
		})
		rows[zone.Index] = { Button = button, Label = label, Info = info }
	end
end

function ZonesWindow.Refresh(data)
	local unlocked = data.Zone or 1
	local stardust = State.Stardust()
	for index, refs in rows do
		local zone = Zones.Get(index)
		refs.Info.Text = ("Meteor HP from %s  •  loot from %s ⭐"):format(Format.Abbreviate(zone.BaseHP), Format.Abbreviate(zone.BaseLoot))
		if index <= unlocked then
			refs.Label.Text = "🚀 TELEPORT"
			UI.SetButtonColor(refs.Button, UI.Colors.Blue)
		elseif index == unlocked + 1 then
			refs.Label.Text = "🔓 " .. Format.Abbreviate(zone.Cost) .. " ⭐"
			UI.SetButtonColor(refs.Button, if stardust >= zone.Cost then UI.Colors.Green else UI.Colors.Red)
		else
			refs.Label.Text = "🔒 " .. Format.Abbreviate(zone.Cost)
			UI.SetButtonColor(refs.Button, UI.Colors.Gray)
		end
	end
end

function ZonesWindow.Tick()
	if State.Data then
		ZonesWindow.Refresh(State.Data)
	end
end

return ZonesWindow
