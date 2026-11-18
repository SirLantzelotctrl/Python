-- Punto de entrada del cliente: estado, interfaz y controladores.

local Client = script.Parent
local Modules = Client:WaitForChild("Modules")
local Controllers = Client:WaitForChild("Controllers")
local WindowModules = Client:WaitForChild("Windows")

local State = require(Modules:WaitForChild("State"))
local Purchase = require(Modules:WaitForChild("Purchase"))

local Notifications = require(Controllers:WaitForChild("Notifications"))
local Windows = require(Controllers:WaitForChild("Windows"))
local Hatch = require(Controllers:WaitForChild("Hatch"))
local HUD = require(Controllers:WaitForChild("HUD"))
local Effects = require(Controllers:WaitForChild("Effects"))
local World = require(Controllers:WaitForChild("World"))
local Followers = require(Controllers:WaitForChild("Followers"))
local Combat = require(Controllers:WaitForChild("Combat"))

State.Init()
Notifications.Init()
Purchase.Notify = Notifications.Show

Windows.Init()
for _, name in { "Shop", "Critters", "Zones", "Quests", "Rebirth", "Index", "Store", "Gifts", "Daily", "Codes" } do
	Windows.Register(name, require(WindowModules:WaitForChild(name)))
end

Hatch.Init()
HUD.Init()
Effects.Init()
World.Init()
Followers.Init()
Combat.Init()
