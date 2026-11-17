-- Códigos canjeables. Están en el servidor (ServerScriptService) para que nadie
-- pueda leerlos desde el cliente: así puedes dar códigos exclusivos a cada
-- creador de contenido y medir cuál funciona mejor.
--
-- Escribe el código en MAYÚSCULAS y sin espacios. Cada cuenta puede canjear cada
-- código una vez. «expires» (opcional) es el último día válido, en UTC.
-- Recompensas posibles: crystals, essence, ink.
return {
	SELLOS = { essence = 500, crystals = 25 },
	LANZAMIENTO = { crystals = 100, expires = "2027-03-31" },
	PRIMORDIAL = { essence = 1500, ink = 5 },
	-- Ejemplo de código para un creador de contenido (cámbialo por su nombre):
	-- CREADOR1 = { crystals = 60 },
}
