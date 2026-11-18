-- =====================================================================
--  METEOR RUSH - Configuración general (casi todo el balance está aquí)
-- =====================================================================

local Config = {}

Config.GameName = "Meteor Rush"
Config.Version = "1.0.0"

-- Cambia el sufijo (_v1 -> _v2) para resetear TODOS los datos.
Config.DataStoreName = "MeteorRush_PlayerData_v1"
Config.LeaderboardStorePrefix = "MeteorRush_LB_v1_"

Config.StartingStardust = 25

-- ---------------------------------------------------------------------
-- Meteoritos
-- ---------------------------------------------------------------------
Config.Meteors = {
	SpawnInterval = 6, -- segundos entre meteoritos en cada zona con jugadores
	MaxActivePerZone = 3,
	ExtraPerPlayer = 1, -- +1 meteorito activo por cada jugador en la zona
	MaxActiveCap = 8,
	WarningTime = 4, -- segundos entre el aviso (círculo) y el impacto
	Lifetime = 150, -- si nadie lo rompe, desaparece
	ImpactRadius = 14, -- los jugadores dentro salen volando
	ImpactKnockback = 65,
	MiningReach = 9, -- studs de alcance más allá del radio del meteorito
	ReservedSeconds = 15, -- meteorito invocado: solo su dueño puede picarlo este tiempo
	TeamworkBonus = 0.15, -- +15% de botín total por cada jugador extra que ayuda
	MvpBonus = 0.25, -- +25% de botín para el que más daño hizo
}

-- ---------------------------------------------------------------------
-- Picar
-- ---------------------------------------------------------------------
Config.Mining = {
	CritMultiplier = 2.5,
	BaseCritChance = 0.05,
	CritPerLevel = 0.02,
	HelperDpsFactor = 0.35, -- daño por segundo de cada criatura equipada (fracción de un golpe)
	HelperRange = 24,
	AutoMineInterval = 0.45,
}

-- ---------------------------------------------------------------------
-- Criaturas (mascotas)
-- ---------------------------------------------------------------------
Config.Critters = {
	BaseSlots = 3,
	SlotsPerRebirth = 1,
	MaxSlotsFromRebirth = 3,
	PassSlots = 2,
	InventoryLimit = 80,
	ShinyChance = 1 / 40,
	ShinyMultiplier = 2,
	LuckPerLevel = 0.1, -- mejora "Hatch Luck": +10% probabilidad de rarezas altas por nivel
	LuckyPassMultiplier = 1.5,
	AnnounceMinRarityOrder = 5, -- anuncia eclosiones Legendary o mejores
}

-- ---------------------------------------------------------------------
-- Supernova (rebirth)
-- ---------------------------------------------------------------------
Config.Rebirth = {
	BaseCost = 2_000_000,
	CostGrowth = 6,
	StardustBonus = 0.5, -- +50% stardust por cada supernova
	DamageBonus = 0.25, -- +25% daño por cada supernova
	MaxRebirths = 50,
}

-- ---------------------------------------------------------------------
-- Jugador
-- ---------------------------------------------------------------------
Config.Player = {
	BaseWalkSpeed = 20,
	SpeedPerLevel = 1.5,
	BootsSpeed = 10, -- gamepass Rocket Boots
	BootsJump = 18,
	MoonGravityFactor = 0.35, -- gravedad en la zona Luna (efecto en el cliente)
}

-- ---------------------------------------------------------------------
-- Multiplicadores
-- ---------------------------------------------------------------------
Config.Income = {
	FriendBonus = 0.1,
	MaxFriendBonus = 0.5,
	PremiumBonus = 0.1,
	GroupBonus = 0.1,
	VipStardust = 0.2,
	VipDamage = 0.1,
	DoubleStardust = 2,
	BoostMultiplier = 2,
}

-- ---------------------------------------------------------------------
-- Cometa jefe (evento de todo el servidor)
-- ---------------------------------------------------------------------
Config.Comet = {
	FirstDelay = 6 * 60,
	Interval = 20 * 60,
	WarningTime = 12,
	TargetSeconds = 75, -- la vida del cometa se ajusta al daño del servidor para durar ~esto
	MinHP = 3_000,
	Lifetime = 240,
	RewardMeteors = 60, -- botín = 60 meteoritos medios de tu mejor zona (repartido por daño)
	MinRewardShare = 0.25, -- todos los que participan reciben al menos el 25% de una parte justa
}

-- ---------------------------------------------------------------------
-- Eventos automáticos
-- ---------------------------------------------------------------------
Config.Events = {
	FirstDelay = 180,
	Interval = 9 * 60,
	Duration = 150,
	ShowerMultiplier = 3, -- Lluvia de meteoritos: aparecen 3 veces más rápido
	BloodMoonLuck = 3, -- Luna de sangre: suerte x3
	GoldenMultiplier = 2, -- Hora dorada: x2 stardust
}

Config.ServerLuck = {
	Multiplier = 2,
	MaxStackSeconds = 3 * 3600,
}

Config.GroupId = 0
Config.Admins = {} :: { number }
Config.SimulatePurchasesInStudio = true

-- ---------------------------------------------------------------------
-- Recompensas. Tipos:
--   Stardust = cantidad fija mínima
--   Meteors = vale lo mismo que N meteoritos medios de tu mejor zona (escala con tu progreso)
--   Boost = segundos de x2 stardust      DamageBoost = segundos de x2 daño
--   CritterRarity = criatura de esa rareza (del huevo de tu mejor zona)
-- ---------------------------------------------------------------------
Config.Codes = {
	WELCOME = { Stardust = 100, Meteors = 5 },
	METEOR = { Boost = 15 * 60 },
	COSMIC = { CritterRarity = "Rare" },
	SUPERNOVA = { DamageBoost = 15 * 60, Meteors = 10 },
} :: { [string]: { [string]: any } }

Config.DailyRewards = {
	{ Stardust = 100, Meteors = 8 },
	{ Stardust = 250, Meteors = 15 },
	{ Boost = 10 * 60 },
	{ Stardust = 600, Meteors = 30 },
	{ CritterRarity = "Epic" },
	{ DamageBoost = 20 * 60, Meteors = 50 },
	{ CritterRarity = "Legendary", Boost = 30 * 60 },
} :: { { [string]: any } }

Config.PlaytimeGifts = {
	{ Minutes = 2, Stardust = 60, Meteors = 3 },
	{ Minutes = 5, Stardust = 150, Meteors = 6 },
	{ Minutes = 8, Boost = 5 * 60 },
	{ Minutes = 12, CritterRarity = "Rare" },
	{ Minutes = 16, Stardust = 500, Meteors = 15 },
	{ Minutes = 20, DamageBoost = 10 * 60 },
	{ Minutes = 25, CritterRarity = "Epic" },
	{ Minutes = 30, Stardust = 2_000, Meteors = 30 },
	{ Minutes = 40, Boost = 15 * 60 },
	{ Minutes = 50, CritterRarity = "Legendary" },
	{ Minutes = 60, Stardust = 10_000, Meteors = 80 },
	{ Minutes = 75, CritterRarity = "Mythic" },
} :: { { [string]: any } }

-- Sonidos incluidos en Roblox (rbxasset). Cámbialos por rbxassetid:// de la Creator Store si quieres.
Config.Sounds = {
	Click = "rbxasset://sounds/electronicpingshort.wav",
	Stardust = "rbxasset://sounds/electronicpingshort.wav",
	Buy = "rbxasset://sounds/electronicpingshort.wav",
	Error = "rbxasset://sounds/action_jump_land.mp3",
	Swing = "rbxasset://sounds/swordslash.wav",
	Hit = "rbxasset://sounds/action_jump_land.mp3",
	Crit = "rbxasset://sounds/swordlunge.wav",
	Impact = "rbxasset://sounds/impact_water.mp3",
	Break = "rbxasset://sounds/unsheath.wav",
	Hatch = "rbxasset://sounds/electronicpingshort.wav",
	Announce = "rbxasset://sounds/electronicpingshort.wav",
	Supernova = "rbxasset://sounds/impact_water.mp3",
} :: { [string]: string }

return Config
