-- Posiciones fijas del mapa (todo se genera por código).
--
--   Vista desde arriba (X hacia la derecha, Z hacia abajo):
--
--   [Plot1] [Plot2] [Plot3] [Plot4]        <- lado norte (z < 0)
--  PORTAL >>>>>>>>> PASARELA >>>>>>>>> FIN
--   [Plot5] [Plot6] [Plot7] [Plot8]        <- lado sur (z > 0)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Layout = {}

Layout.RunwayY = 1 -- altura de la superficie de la pasarela
Layout.RunwayStart = Vector3.new(-168, 1, 0)
Layout.RunwayEnd = Vector3.new(168, 1, 0)
Layout.RunwayWidth = 16

Layout.SpawnPosition = Vector3.new(-200, 1, 0)
Layout.PortalPosition = Vector3.new(-172, 1, 0)

local PLOT_SPACING = Config.Plots.Width + 8
local PLOT_OFFSET_Z = Layout.RunwayWidth / 2 + 14 + Config.Plots.Depth / 2

Layout.PlotCFrames = {} :: { CFrame }

for side = 1, 2 do
	local zSign = if side == 1 then -1 else 1
	for i = 1, 4 do
		local x = (i - 2.5) * PLOT_SPACING
		local position = Vector3.new(x, 0, zSign * PLOT_OFFSET_Z)
		-- El frente de la base (LookVector) mira hacia la pasarela
		table.insert(Layout.PlotCFrames, CFrame.lookAt(position, Vector3.new(x, 0, 0)))
	end
end

-- Posiciones de los pedestales en coordenadas locales de la base (Y = suelo de la base)
Layout.FloorHeight = 1
Layout.PedestalTop = 2.2

Layout.SlotOffsets = {} :: { Vector3 }
do
	local columns = Config.Plots.Columns
	local rows = Config.Plots.Rows
	local spacingX = 10.5
	local spacingZ = 12
	local backZ = Config.Plots.Depth / 2 - 8
	-- Fila 1 = fondo de la base (lejos de la entrada): los primeros slimes quedan más protegidos
	for row = 1, rows do
		for column = 1, columns do
			local x = (column - (columns + 1) / 2) * spacingX
			local z = backZ - (row - 1) * spacingZ
			table.insert(Layout.SlotOffsets, Vector3.new(x, Layout.PedestalTop, z))
		end
	end
end

return Layout
