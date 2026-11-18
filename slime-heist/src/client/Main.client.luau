-- Punto de entrada del cliente: inicializa estado, UI y controladores.

local Client = script.Parent
local Modules = Client:WaitForChild("Modules")
local Controllers = Client:WaitForChild("Controllers")
local WindowModules = Client:WaitForChild("Windows")

local State = require(Modules:WaitForChild("State"))
local Purchase = require(Modules:WaitForChild("Purchase"))

local Notifications = require(Controllers:WaitForChild("Notifications"))
local Windows = require(Controllers:WaitForChild("Windows"))
local HUD = require(Controllers:WaitForChild("HUD"))
local Effects = require(Controllers:WaitForChild("Effects"))
local Prompts = require(Controllers:WaitForChild("Prompts"))
local Animator = require(Controllers:WaitForChild("Animator"))
local Combat = require(Controllers:WaitForChild("Combat"))

State.Init()
Notifications.Init()
Purchase.Notify = Notifications.Show

Windows.Init()
for _, name in { "Shop", "Store", "Rebirth", "Index", "Gifts", "Daily", "Codes" } do
	Windows.Register(name, require(WindowModules:WaitForChild(name)))
end

HUD.Init()
Effects.Init()
Prompts.Init()
Animator.Init()
Combat.Init()
