-- Configuración del juego. Lo único que tienes que rellenar al publicar son los
-- ID de los productos de Robux y de los pases (ver GUIA_PUBLICAR.md).
local Config = {}

Config.Version = "1.0"
Config.DataStoreName = "SellosArcanos_Perfiles_v1"

-- Productos para desarrolladores (Creator Dashboard → tu experiencia →
-- Monetización → Productos para desarrolladores). Crea uno por fila con el precio
-- indicado y pega su ID en `id`. Con id = 0 el producto no aparece en la tienda.
Config.Products = {
	{ key = "cristales_100", id = 0, robux = 49, crystals = 100 },
	{ key = "cristales_550", id = 0, robux = 249, crystals = 550, tag = "popular" },
	{ key = "cristales_1200", id = 0, robux = 499, crystals = 1200, tag = "bonus" },
	{ key = "cristales_2600", id = 0, robux = 999, crystals = 2600, tag = "value" },
	-- Pack del Fundador: se compra una sola vez por cuenta (se controla en el perfil).
	{ key = "pack_fundador", id = 0, robux = 149, crystals = 500, once = true, founder = true },
}

-- Pases del juego (Monetización → Pases). Pega el ID; con 0 no se ofrecen.
Config.GamePasses = {
	-- Pista premium del Pase Arcano de la temporada actual.
	pase_premium = { id = 0, robux = 399 },
	-- Sellador VIP: sello dorado exclusivo, título VIP y +5 Cristales al día.
	vip = { id = 0, robux = 299 },
}

-- Cristales que cuesta desbloquear el pase premium sin Robux.
Config.PassPremiumCrystals = 800
-- Regalo diario a suscriptores de Roblox Premium (ayuda a los Premium Payouts).
Config.PremiumDailyCrystals = 5
Config.VipDailyCrystals = 5

-- Recursos opcionales (IDs de imagen o audio que subas tú). Con 0 el juego usa
-- su versión procedural: círculos hechos con piezas de neón y sin música.
Config.Assets = {
	music = 0,
	circles = { hexagrama = 0, heptagrama = 0, pentagrama = 0 },
	halo = 0,
}

-- Tinta Rúnica: 1 cada 10 minutos, hasta 10 (documento de diseño).
Config.InkMax = 10
Config.InkSeconds = 600

-- Mundo
Config.WildPerIsland = 6
Config.WildRespawn = 14
Config.AggroRange = 34
Config.LeashRange = 90
Config.TeamSizeBase = 2 -- 3 desde el rango 10

-- Tamaño de las criaturas en studs (LEEME: Cría 3-4, jefe Primordial 12-20).
Config.FormHeights = { 4.2, 6, 8 }
Config.BossHeight = 17

return Config
