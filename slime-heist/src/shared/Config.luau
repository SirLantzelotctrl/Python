--!strict
-- =====================================================================
--  SLIME HEIST - Configuración general
--  Casi todo el balance del juego se ajusta desde aquí.
-- =====================================================================

local Config = {}

Config.GameName = "Slime Heist"
Config.Version = "1.0.0"

-- Cambia el sufijo (_v1 -> _v2) si quieres resetear TODOS los datos de jugadores.
Config.DataStoreName = "SlimeHeist_PlayerData_v1"
Config.LeaderboardStorePrefix = "SlimeHeist_LB_v1_"

-- Dinero con el que empieza un jugador nuevo (suficiente para 2-3 slimes comunes)
Config.StartingCash = 100

-- ---------------------------------------------------------------------
-- Bases (plots)
-- ---------------------------------------------------------------------
Config.Plots = {
	Count = 8, -- pon "Max Players" del servidor en 8 en Game Settings
	Width = 64,
	Depth = 72,
	Columns = 6,
	Rows = 5, -- Columns * Rows = slots físicos máximos (30)
	WallHeight = 3.5,
}

Config.Slots = {
	Base = 8, -- slots al empezar
	PerRebirth = 2, -- slots extra por cada rebirth
	MaxFromRebirths = 24, -- tope de slots ganados con rebirths
	ExtraFromPass = 6, -- slots extra del gamepass (24 + 6 = 30)
}

-- ---------------------------------------------------------------------
-- Pasarela (conveyor) donde aparecen los slimes
-- ---------------------------------------------------------------------
Config.Conveyor = {
	SpawnInterval = 2.4, -- segundos entre cada slime
	Speed = 8, -- studs por segundo
	WalkSpeed = 26, -- velocidad del slime cuando camina hacia tu base tras comprarlo
	BuyHoldDuration = 0.2,
}

-- ---------------------------------------------------------------------
-- Robar
-- ---------------------------------------------------------------------
Config.Steal = {
	HoldDuration = 1.5, -- segundos manteniendo E para robar
	CarrySpeedMultiplier = 0.72, -- el ladrón va más lento cargando el slime
	Timeout = 75, -- si no llega a su base en este tiempo, el slime vuelve
	FailCooldown = 3, -- segundos antes de poder volver a robar tras fallar
	AnnounceMinRarityOrder = 5, -- anuncia en todo el servidor robos de Legendary o mejor
}

-- ---------------------------------------------------------------------
-- Candado de la base
-- ---------------------------------------------------------------------
Config.Lock = {
	BaseDuration = 45,
	PerRebirth = 5,
	PerUpgradeLevel = 5,
	PassBonus = 30, -- gamepass "Longer Lock"
	Cooldown = 15, -- tiempo vulnerable obligatorio entre candados
}

Config.Sell = {
	Ratio = 0.5, -- vender devuelve el 50% del precio
}

-- ---------------------------------------------------------------------
-- Rebirth
-- ---------------------------------------------------------------------
Config.Rebirth = {
	BaseCost = 400_000,
	CostGrowth = 4,
	IncomeBonus = 0.5, -- +50% de ingresos por rebirth (se suma)
	MaxRebirths = 99,
}

-- ---------------------------------------------------------------------
-- Ingresos y multiplicadores
-- ---------------------------------------------------------------------
Config.Income = {
	IndexBonusPerEntry = 0.005, -- +0.5% por cada slime/mutación descubierto en el Index
	FriendBonus = 0.1, -- +10% por cada amigo en el servidor
	MaxFriendBonus = 0.5,
	PremiumBonus = 0.1, -- Roblox Premium
	GroupBonus = 0.1, -- miembros del grupo (Config.GroupId)
	VipBonus = 0.25,
	DoubleCash = 2,
	BoostMultiplier = 2, -- boost temporal x2
}

-- Ganancias offline (cuando vuelves al juego)
Config.Offline = {
	Rate = 0.25, -- 25% de lo que generarías online
	MaxSeconds = 6 * 3600,
	MinSeconds = 60,
}

Config.Player = {
	BaseWalkSpeed = 18,
	SpeedPassBonus = 8,
}

-- ---------------------------------------------------------------------
-- Eventos automáticos del servidor
-- ---------------------------------------------------------------------
Config.Events = {
	FirstDelay = 240, -- primer evento a los 4 minutos
	Interval = 600, -- después cada 10 minutos
	Duration = 150,
	LuckMultiplier = 2,
	MutationMultiplier = 3,
	FrenzySpawnMultiplier = 2.5,
	MoneyRainCoins = 45,
}

Config.ServerLuck = {
	Multiplier = 2,
	MaxStackSeconds = 3 * 3600,
}

-- Grupo de Roblox (0 = desactivado). Los miembros reciben +10% de cash.
Config.GroupId = 0

-- UserIds de administradores (además del creador del juego).
Config.Admins = {} :: { number }

-- En Studio, si un producto tiene Id = 0, la tienda simula la compra para que puedas probar todo.
Config.SimulatePurchasesInStudio = true

-- ---------------------------------------------------------------------
-- Códigos (en mayúsculas). Tipos: Cash (dinero fijo), IncomeSeconds (segundos de ingresos),
-- Boost (segundos de x2 cash), SlimeRarity (slime aleatorio de esa rareza)
-- ---------------------------------------------------------------------
Config.Codes = {
	WELCOME = { Cash = 1_000 },
	SLIMY = { Boost = 15 * 60 },
	HEIST = { SlimeRarity = "Epic" },
	RICH = { IncomeSeconds = 600, Cash = 5_000 },
} :: { [string]: { [string]: any } }

-- ---------------------------------------------------------------------
-- Recompensas diarias (ciclo de 7 días)
-- Cash = mínimo fijo, IncomeSeconds = segundos de tus ingresos (se usa el mayor)
-- ---------------------------------------------------------------------
Config.DailyRewards = {
	{ Cash = 500, IncomeSeconds = 120 },
	{ Cash = 1_500, IncomeSeconds = 300 },
	{ Boost = 10 * 60 },
	{ Cash = 5_000, IncomeSeconds = 600 },
	{ SlimeRarity = "Epic" },
	{ Cash = 20_000, IncomeSeconds = 1_200 },
	{ SlimeRarity = "Legendary", Boost = 30 * 60 },
} :: { { [string]: any } }

-- ---------------------------------------------------------------------
-- Regalos por tiempo jugado en la sesión (minutos)
-- ---------------------------------------------------------------------
Config.PlaytimeGifts = {
	{ Minutes = 2, Cash = 250, IncomeSeconds = 60 },
	{ Minutes = 5, Cash = 600, IncomeSeconds = 120 },
	{ Minutes = 8, Boost = 5 * 60 },
	{ Minutes = 12, SlimeRarity = "Rare" },
	{ Minutes = 16, Cash = 2_500, IncomeSeconds = 300 },
	{ Minutes = 20, Boost = 10 * 60 },
	{ Minutes = 25, SlimeRarity = "Epic" },
	{ Minutes = 30, Cash = 10_000, IncomeSeconds = 600 },
	{ Minutes = 40, Boost = 15 * 60 },
	{ Minutes = 50, SlimeRarity = "Legendary" },
	{ Minutes = 60, Cash = 50_000, IncomeSeconds = 1_800 },
	{ Minutes = 75, SlimeRarity = "Mythic" },
} :: { { [string]: any } }

-- ---------------------------------------------------------------------
-- Sonidos. Los "rbxasset://" vienen con Roblox y funcionan siempre.
-- Puedes cambiarlos por "rbxassetid://ID" de la Creator Store.
-- ---------------------------------------------------------------------
Config.Sounds = {
	Click = "rbxasset://sounds/electronicpingshort.wav",
	Cash = "rbxasset://sounds/electronicpingshort.wav",
	Buy = "rbxasset://sounds/electronicpingshort.wav",
	Error = "rbxasset://sounds/action_jump_land.mp3",
	Swing = "rbxasset://sounds/swordslash.wav",
	Hit = "rbxasset://sounds/swordlunge.wav",
	Alarm = "rbxasset://sounds/electronicpingshort.wav",
	Steal = "rbxasset://sounds/unsheath.wav",
	Rebirth = "rbxasset://sounds/impact_water.mp3",
	Announce = "rbxasset://sounds/electronicpingshort.wav",
	Lock = "rbxasset://sounds/action_jump_land.mp3",
} :: { [string]: string }

return Config
