-- Registro de servicios del servidor. Main.server.luau lo rellena al arrancar.
-- Los servicios acceden a otros con Registry.NombreServicio DENTRO de funciones
-- (nunca al cargar el módulo) para evitar dependencias circulares.

local Registry = {} :: { [string]: any }

return Registry
