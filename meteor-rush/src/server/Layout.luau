-- Posiciones del mapa. Las zonas van en fila a lo largo del eje X:
--
--   [HUB + 🌿 Pradera] | [🏜️ Desierto] | [❄️ Tundra] | [🌋 Magma] | [🌙 Luna] | [🌌 Nebulosa]
--    spawn, huevos,      puerta          puerta         ...
--    tienda, cometa

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Zones)

local Layout = {}

Layout.ZoneWidth = 210 -- eje X
Layout.ZoneDepth = 200 -- eje Z
Layout.GateHalfWidth = 14

Layout.SpawnPosition = Vector3.new(-82, 0, 0)
Layout.PlazaCenter = Vector3.new(-42, 0, 0)
Layout.PlazaRadius = 30
Layout.ShopPosition = Vector3.new(-84, 0, 34)
Layout.AltarPosition = Vector3.new(-60, 0, 40)
Layout.LeaderboardX = -100

function Layout.ZoneCenter(index: number): Vector3
	return Vector3.new((index - 1) * Layout.ZoneWidth, 0, 0)
end

-- Rango de X (min, max) de una zona
function Layout.ZoneXRange(index: number): (number, number)
	local center = Layout.ZoneCenter(index).X
	return center - Layout.ZoneWidth / 2, center + Layout.ZoneWidth / 2
end

-- Índice de zona según la posición (0 si está fuera del mapa)
function Layout.ZoneAt(position: Vector3): number
	if math.abs(position.Z) > Layout.ZoneDepth / 2 + 5 then
		return 0
	end
	local index = math.floor((position.X + Layout.ZoneWidth / 2) / Layout.ZoneWidth) + 1
	if index < 1 or index > Zones.Count() then
		return 0
	end
	return index
end

-- Punto de aparición/teletransporte de cada zona (en su borde oeste)
function Layout.ZoneSpawn(index: number): CFrame
	if index <= 1 then
		return CFrame.lookAt(Layout.SpawnPosition + Vector3.new(0, 3, 0), Layout.SpawnPosition + Vector3.new(10, 3, 0))
	end
	local minX = Layout.ZoneXRange(index)
	local position = Vector3.new(minX + 14, 3, 0)
	return CFrame.lookAt(position, position + Vector3.new(1, 0, 0))
end

-- Posición de la puerta que da acceso a la zona `index` (frontera con la anterior)
function Layout.GatePosition(index: number): Vector3
	local minX = Layout.ZoneXRange(index)
	return Vector3.new(minX, 0, 0)
end

-- Soporte del huevo de cada zona
function Layout.EggPosition(index: number): Vector3
	if index <= 1 then
		return Vector3.new(-84, 0, -34)
	end
	local minX = Layout.ZoneXRange(index)
	return Vector3.new(minX + 22, 0, -34)
end

-- Zona donde pueden caer meteoritos (min X, max X, max |Z|)
function Layout.MeteorArea(index: number): (number, number, number)
	local minX, maxX = Layout.ZoneXRange(index)
	if index == 1 then
		return -8, maxX - 14, 82
	end
	return minX + 40, maxX - 14, 82
end

return Layout
