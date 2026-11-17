-- GENERADO por tools/gen_shared.mjs a partir de los datos del juego. No editar a mano:
-- cambia ../sellos-arcanos/src/data y ejecuta `npm run gen`.
-- Distancias en studs (STUD = 2.4 studs por unidad del diseño).

local GameData = {}

GameData.STUD = 2.4

GameData.Elements = {
	vacio = {
		es = "Vacío",
		en = "Void",
		domain = "arcano",
	},
	fuego = {
		es = "Fuego",
		en = "Fire",
		domain = "igneo",
	},
	abismo = {
		es = "Abismo",
		en = "Abyss",
		domain = "abisal",
	},
	rayo = {
		es = "Rayo",
		en = "Lightning",
		domain = "igneo",
	},
	infierno = {
		es = "Infierno",
		en = "Inferno",
		domain = "igneo",
	},
	veneno = {
		es = "Veneno",
		en = "Poison",
		domain = "natural",
	},
	hielo = {
		es = "Hielo",
		en = "Ice",
		domain = "abisal",
	},
	tierra = {
		es = "Tierra",
		en = "Earth",
		domain = "natural",
	},
	cosmos = {
		es = "Cosmos",
		en = "Cosmos",
		domain = "abisal",
	},
	sombra = {
		es = "Sombra",
		en = "Shadow",
		domain = "arcano",
	},
	luz = {
		es = "Luz",
		en = "Light",
		domain = "arcano",
	},
	cristal = {
		es = "Cristal",
		en = "Crystal",
		domain = "natural",
	},
}

GameData.Domains = {
	abisal = {
		es = "Abisal",
		en = "Abyssal",
		beats = "igneo",
		color = "#2ff2d6",
	},
	igneo = {
		es = "Ígneo",
		en = "Igneous",
		beats = "natural",
		color = "#ff7a2e",
	},
	natural = {
		es = "Natural",
		en = "Natural",
		beats = "arcano",
		color = "#3dff88",
	},
	arcano = {
		es = "Arcano",
		en = "Arcane",
		beats = "abisal",
		color = "#b06bff",
	},
}

GameData.Roles = {
	asalto = {
		es = "Asalto",
		en = "Assault",
	},
	tanque = {
		es = "Tanque",
		en = "Tank",
	},
	hechicero = {
		es = "Hechicero",
		en = "Sorcerer",
	},
	soporte = {
		es = "Soporte",
		en = "Support",
	},
}

GameData.Creatures = {
	{
		id = "hidra",
		num = "01",
		file = "Hidra",
		el = "vacio",
		role = "asalto",
		color = "#b06bff",
		body = "#504a64",
		bone = "#9288ae",
		stats = {
			pow = 90,
			def = 70,
			agi = 45,
			mag = 95,
		},
		circle = "hexagrama",
		halo = true,
		island = 12,
		nodes = 9,
		name = {
			es = "Hidra del Vacío",
			en = "Void Hydra",
		},
		sub = {
			es = "Jefe colosal · Cinco cabezas",
			en = "Colossal boss · Five heads",
		},
		lore = {
			es = "Cada cabeza recuerda una estrella que devoró. Si cortas una, el vacío hace crecer dos.",
			en = "Each head remembers a star it devoured. Cut one off and the void grows two.",
		},
		abilities = {
			{
				key = "q",
				name = {
					es = "Mordisco múltiple",
					en = "Multi-bite",
				},
				desc = {
					es = "Tres mordiscos rápidos en arco.",
					en = "Three quick bites in an arc.",
				},
				type = "melee",
				stat = "p",
				power = 3.2,
				hits = 3,
				range = 8.16,
				arc = 120,
				cd = 0.9,
				cost = 0,
			},
			{
				key = "e",
				name = {
					es = "Aliento abisal",
					en = "Abyssal Breath",
				},
				desc = {
					es = "Aliento en cono que ralentiza.",
					en = "Cone breath that slows.",
				},
				type = "cone",
				stat = "m",
				power = 2.2,
				ticks = 6,
				dur = 1.2,
				range = 21.6,
				arc = 50,
				cd = 6,
				cost = 25,
				status = {
					t = "slow",
					dur = 2,
					val = 0.45,
				},
			},
			{
				key = "r",
				name = {
					es = "Regenerar cabeza",
					en = "Regrow Head",
				},
				desc = {
					es = "Recupera el 25 % de vida y gana +20 % de poder.",
					en = "Restores 25% HP and gains +20% power.",
				},
				type = "heal",
				pct = 0.25,
				dur = 3,
				cd = 14,
				cost = 35,
				buff = {
					atk = 0.2,
					dur = 6,
				},
			},
			{
				key = "f",
				name = {
					es = "Devorar estrellas",
					en = "Devour the Stars",
				},
				desc = {
					es = "Cinco alientos en abanico que atraviesan.",
					en = "Five piercing breaths in a fan.",
				},
				type = "projectile",
				stat = "m",
				power = 9,
				count = 5,
				spread = 70,
				speed = 52.8,
				range = 43.2,
				radius = 3.12,
				pierce = true,
				cd = 0,
			},
		},
	},
	{
		id = "fenix",
		num = "02",
		file = "Fenix",
		el = "fuego",
		role = "soporte",
		color = "#ff7a2e",
		body = "#564b57",
		bone = "#9b889d",
		stats = {
			pow = 70,
			def = 45,
			agi = 85,
			mag = 100,
		},
		circle = "heptagrama",
		halo = true,
		island = 7,
		nodes = 7,
		name = {
			es = "Fénix Solar",
			en = "Solar Phoenix",
		},
		sub = {
			es = "Ave legendaria · Renace de su ceniza",
			en = "Legendary bird · Reborn from its ashes",
		},
		lore = {
			es = "Cuando muere se convierte en amanecer. Sus plumas siguen ardiendo mil años después de caer.",
			en = "When it dies it becomes a sunrise. Its feathers keep burning a thousand years after they fall.",
		},
		abilities = {
			{
				key = "q",
				name = {
					es = "Pluma ígnea",
					en = "Fire Feather",
				},
				desc = {
					es = "Tres plumas que queman.",
					en = "Three feathers that burn.",
				},
				type = "projectile",
				stat = "m",
				power = 2.4,
				count = 3,
				spread = 22,
				speed = 57.6,
				range = 38.4,
				radius = 1.68,
				cd = 0.8,
				cost = 0,
				status = {
					t = "burn",
					dur = 3,
					val = 0.5,
				},
			},
			{
				key = "e",
				name = {
					es = "Muro de llamas",
					en = "Wall of Flames",
				},
				desc = {
					es = "Zona de fuego frente al enemigo.",
					en = "A zone of fire on the enemy.",
				},
				type = "zone",
				stat = "m",
				power = 1.6,
				range = 28.8,
				radius = 7.68,
				dur = 4,
				tick = 0.5,
				cd = 8,
				cost = 25,
				status = {
					t = "burn",
					dur = 2,
					val = 0.5,
				},
			},
			{
				key = "r",
				name = {
					es = "Calor vital",
					en = "Vital Warmth",
				},
				desc = {
					es = "Cura al equipo un 20 % en 5 s.",
					en = "Heals your team 20% over 5 s.",
				},
				type = "heal",
				pct = 0.2,
				dur = 5,
				team = true,
				cd = 15,
				cost = 35,
			},
			{
				key = "f",
				name = {
					es = "Renacer",
					en = "Rebirth",
				},
				desc = {
					es = "Revive al equipo con el 50 % de vida y estalla en llamas.",
					en = "Revives the team at 50% HP and bursts into flame.",
				},
				type = "revive",
				pct = 0.5,
				stat = "m",
				power = 8,
				radius = 16.8,
				cd = 0,
			},
		},
	},
	{
		id = "kraken",
		num = "03",
		file = "Kraken",
		el = "abismo",
		role = "tanque",
		color = "#2ff2d6",
		body = "#49515c",
		bone = "#8a90a4",
		stats = {
			pow = 80,
			def = 95,
			agi = 35,
			mag = 90,
		},
		circle = "pentagrama",
		halo = false,
		island = 8,
		nodes = 8,
		name = {
			es = "Kraken Abisal",
			en = "Abyssal Kraken",
		},
		sub = {
			es = "Titán marino · Ocho brazos",
			en = "Sea titan · Eight arms",
		},
		lore = {
			es = "Duerme bajo la fosa más honda del océano. Sus ojos son la única luz que ven los barcos hundidos.",
			en = "It sleeps beneath the ocean's deepest trench. Its eyes are the only light sunken ships ever see.",
		},
		abilities = {
			{
				key = "q",
				name = {
					es = "Latigazo",
					en = "Lash",
				},
				desc = {
					es = "Golpe amplio de tentáculo.",
					en = "A wide tentacle strike.",
				},
				type = "melee",
				stat = "p",
				power = 6,
				hits = 1,
				range = 11.04,
				arc = 150,
				cd = 1,
				cost = 0,
			},
			{
				key = "e",
				name = {
					es = "Agarre",
					en = "Grab",
				},
				desc = {
					es = "Atrae al objetivo y lo aturde.",
					en = "Pulls the target in and stuns it.",
				},
				type = "projectile",
				stat = "p",
				power = 6,
				count = 1,
				speed = 62.4,
				range = 28.8,
				radius = 2.4,
				cd = 7,
				cost = 25,
				pullBack = true,
				status = {
					t = "stun",
					dur = 1,
				},
			},
			{
				key = "r",
				name = {
					es = "Tinta cegadora",
					en = "Blinding Ink",
				},
				desc = {
					es = "Ciega a los enemigos cercanos y te escuda.",
					en = "Blinds nearby enemies and shields you.",
				},
				type = "aoe",
				stat = "m",
				power = 2,
				range = 0,
				radius = 14.4,
				delay = 0,
				cd = 12,
				cost = 35,
				status = {
					t = "blind",
					dur = 4,
				},
				also = {
					type = "shield",
					pct = 0.2,
					dur = 5,
				},
			},
			{
				key = "f",
				name = {
					es = "Remolino",
					en = "Maelstrom",
				},
				desc = {
					es = "Arrastra a todos al centro y los golpea.",
					en = "Drags everyone to the center and crushes them.",
				},
				type = "aoe",
				stat = "m",
				power = 2.4,
				range = 0,
				radius = 24,
				ticks = 6,
				dur = 2,
				pull = 21.6,
				final = 10,
				cd = 0,
			},
		},
	},
	{
		id = "grifo",
		num = "04",
		file = "Grifo",
		el = "rayo",
		role = "asalto",
		color = "#4fb4ff",
		body = "#4a4e61",
		bone = "#8b8daa",
		stats = {
			pow = 95,
			def = 55,
			agi = 100,
			mag = 50,
		},
		circle = "hexagrama",
		halo = false,
		island = 5,
		nodes = 6,
		name = {
			es = "Grifo de Tormenta",
			en = "Storm Griffin",
		},
		sub = {
			es = "Guardián alado · Cazador del cielo",
			en = "Winged guardian · Sky hunter",
		},
		lore = {
			es = "Mitad águila, mitad león. Cada batir de alas suelta un relámpago sobre quien ose tocar su nido.",
			en = "Half eagle, half lion. Every beat of its wings looses lightning on whoever dares touch its nest.",
		},
		abilities = {
			{
				key = "q",
				name = {
					es = "Picado",
					en = "Dive",
				},
				desc = {
					es = "Se lanza sobre el objetivo.",
					en = "Dives onto the target.",
				},
				type = "dash",
				stat = "p",
				power = 5.5,
				range = 21.6,
				speed = 81.6,
				width = 4.32,
				cd = 1.1,
				cost = 0,
			},
			{
				key = "e",
				name = {
					es = "Garra eléctrica",
					en = "Shock Claw",
				},
				desc = {
					es = "Tres zarpazos que marcan al enemigo.",
					en = "Three slashes that mark the enemy.",
				},
				type = "melee",
				stat = "p",
				power = 3.4,
				hits = 3,
				range = 8.16,
				arc = 110,
				cd = 5,
				cost = 25,
				status = {
					t = "mark",
					dur = 8,
				},
			},
			{
				key = "r",
				name = {
					es = "Vendaval",
					en = "Gale",
				},
				desc = {
					es = "Ráfaga en cono que empuja y ralentiza.",
					en = "A cone gust that knocks back and slows.",
				},
				type = "cone",
				stat = "p",
				power = 5,
				ticks = 1,
				dur = 0,
				range = 19.2,
				arc = 70,
				knock = 14.4,
				cd = 9,
				cost = 30,
				status = {
					t = "slow",
					dur = 2.5,
					val = 0.5,
				},
			},
			{
				key = "f",
				name = {
					es = "Tormenta",
					en = "Storm",
				},
				desc = {
					es = "Seis rayos sobre los enemigos marcados.",
					en = "Six bolts on marked enemies.",
				},
				type = "strike",
				stat = "p",
				power = 7,
				count = 6,
				radius = 5.28,
				delay = 0.25,
				interval = 0.18,
				cd = 0,
			},
		},
	},
	{
		id = "cerbero",
		num = "05",
		file = "Cerbero",
		el = "infierno",
		role = "asalto",
		color = "#ff3d3d",
		body = "#594957",
		bone = "#9e869e",
		stats = {
			pow = 100,
			def = 70,
			agi = 85,
			mag = 45,
		},
		circle = "pentagrama",
		halo = false,
		island = 10,
		nodes = 6,
		name = {
			es = "Cerbero Infernal",
			en = "Infernal Cerberus",
		},
		sub = {
			es = "Guardián del umbral · Tres cabezas",
			en = "Threshold guardian · Three heads",
		},
		lore = {
			es = "Una cabeza vigila el pasado, otra el presente y la última el futuro. Ninguna duerme jamás.",
			en = "One head watches the past, another the present and the last the future. None of them ever sleeps.",
		},
		abilities = {
			{
				key = "q",
				name = {
					es = "Triple mordida",
					en = "Triple Bite",
				},
				desc = {
					es = "Tres mordiscos feroces.",
					en = "Three ferocious bites.",
				},
				type = "melee",
				stat = "p",
				power = 3,
				hits = 3,
				range = 7.68,
				arc = 110,
				cd = 0.8,
				cost = 0,
			},
			{
				key = "e",
				name = {
					es = "Carga",
					en = "Charge",
				},
				desc = {
					es = "Embiste en línea y aturde.",
					en = "Charges in a line and stuns.",
				},
				type = "dash",
				stat = "p",
				power = 8,
				range = 26.4,
				speed = 72,
				width = 5.28,
				cd = 6,
				cost = 25,
				status = {
					t = "stun",
					dur = 0.7,
				},
			},
			{
				key = "r",
				name = {
					es = "Aullido",
					en = "Howl",
				},
				desc = {
					es = "+35 % de poder y frena a los enemigos.",
					en = "+35% power and slows enemies.",
				},
				type = "aoe",
				stat = "p",
				power = 0,
				range = 0,
				radius = 21.6,
				delay = 0,
				cd = 13,
				cost = 30,
				status = {
					t = "slow",
					dur = 3,
					val = 0.5,
				},
				also = {
					type = "buff",
					atk = 0.35,
					dur = 6,
				},
			},
			{
				key = "f",
				name = {
					es = "Furia de tres cabezas",
					en = "Three-Headed Fury",
				},
				desc = {
					es = "8 s de ataques en cadena con robo de vida.",
					en = "8 s of chained attacks with lifesteal.",
				},
				type = "buff",
				atk = 0.3,
				spd = 0.35,
				cdr = 0.7,
				lifesteal = 0.2,
				dur = 8,
				cd = 0,
			},
		},
	},
	{
		id = "basilisco",
		num = "06",
		file = "Basilisco",
		el = "veneno",
		role = "hechicero",
		color = "#3dff88",
		body = "#495159",
		bone = "#8a919f",
		stats = {
			pow = 75,
			def = 65,
			agi = 60,
			mag = 100,
		},
		circle = "heptagrama",
		halo = false,
		island = 3,
		nodes = 7,
		name = {
			es = "Basilisco Esmeralda",
			en = "Emerald Basilisk",
		},
		sub = {
			es = "Rey de las serpientes · Mirada de piedra",
			en = "King of serpents · Stone gaze",
		},
		lore = {
			es = "Su corona es de hueso y su mirada, de piedra. Quienes lo enfrentaron siguen en pie, convertidos en estatuas.",
			en = "Its crown is bone and its gaze is stone. Those who faced it still stand, turned to statues.",
		},
		abilities = {
			{
				key = "q",
				name = {
					es = "Colmillo tóxico",
					en = "Toxic Fang",
				},
				desc = {
					es = "Proyectil que envenena.",
					en = "A projectile that poisons.",
				},
				type = "projectile",
				stat = "m",
				power = 4.6,
				count = 1,
				speed = 52.8,
				range = 36,
				radius = 1.92,
				cd = 0.85,
				cost = 0,
				status = {
					t = "poison",
					dur = 4,
					val = 0.45,
				},
			},
			{
				key = "e",
				name = {
					es = "Capucha espejo",
					en = "Mirror Hood",
				},
				desc = {
					es = "Escudo que refleja la mitad del daño.",
					en = "A shield that reflects half the damage.",
				},
				type = "shield",
				pct = 0.25,
				dur = 4,
				reflect = 0.5,
				cd = 9,
				cost = 25,
			},
			{
				key = "r",
				name = {
					es = "Constricción",
					en = "Constrict",
				},
				desc = {
					es = "Inmoviliza y aprieta en una zona.",
					en = "Roots and squeezes in an area.",
				},
				type = "aoe",
				stat = "m",
				power = 2,
				range = 26.4,
				radius = 8.16,
				delay = 0.5,
				ticks = 4,
				dur = 2,
				cd = 10,
				cost = 30,
				status = {
					t = "root",
					dur = 2,
				},
			},
			{
				key = "f",
				name = {
					es = "Mirada de piedra",
					en = "Stone Gaze",
				},
				desc = {
					es = "Petrifica 3 s en un cono.",
					en = "Petrifies for 3 s in a cone.",
				},
				type = "cone",
				stat = "m",
				power = 9,
				ticks = 1,
				dur = 0,
				range = 31.2,
				arc = 65,
				cd = 0,
				status = {
					t = "petrify",
					dur = 3,
				},
			},
		},
	},
	{
		id = "wyvern",
		num = "07",
		file = "Wyvern",
		el = "hielo",
		role = "hechicero",
		color = "#9fefff",
		body = "#4c505e",
		bone = "#8e8fa7",
		stats = {
			pow = 80,
			def = 60,
			agi = 65,
			mag = 95,
		},
		circle = "hexagrama",
		halo = false,
		island = 4,
		nodes = 6,
		name = {
			es = "Wyvern de Escarcha",
			en = "Frost Wyvern",
		},
		sub = {
			es = "Dragón bípedo · Aliento helado",
			en = "Two-legged dragon · Frost breath",
		},
		lore = {
			es = "Anida en los picos donde el viento no deja huellas. Su aliento convierte la lluvia en cristal.",
			en = "It nests on peaks where the wind leaves no tracks. Its breath turns rain into crystal.",
		},
		abilities = {
			{
				key = "q",
				name = {
					es = "Esquirlas",
					en = "Shards",
				},
				desc = {
					es = "Tres esquirlas que ralentizan.",
					en = "Three slowing shards.",
				},
				type = "projectile",
				stat = "m",
				power = 2.3,
				count = 3,
				spread = 16,
				speed = 67.2,
				range = 38.4,
				radius = 1.44,
				cd = 0.75,
				cost = 0,
				status = {
					t = "slow",
					dur = 1.5,
					val = 0.3,
				},
			},
			{
				key = "e",
				name = {
					es = "Aliento helado",
					en = "Frost Breath",
				},
				desc = {
					es = "Aliento que acaba congelando.",
					en = "A breath that ends up freezing.",
				},
				type = "cone",
				stat = "m",
				power = 2,
				ticks = 6,
				dur = 1.4,
				range = 21.6,
				arc = 50,
				cd = 7,
				cost = 25,
				status = {
					t = "slow",
					dur = 2,
					val = 0.5,
				},
				endStatus = {
					t = "freeze",
					dur = 1.2,
				},
			},
			{
				key = "r",
				name = {
					es = "Vuelo rasante",
					en = "Low Flight",
				},
				desc = {
					es = "Pasa en vuelo dañando todo a su paso.",
					en = "Swoops through, damaging everything.",
				},
				type = "dash",
				stat = "m",
				power = 6.5,
				range = 28.8,
				speed = 76.8,
				width = 6.24,
				cd = 8,
				cost = 30,
			},
			{
				key = "f",
				name = {
					es = "Ventisca",
					en = "Blizzard",
				},
				desc = {
					es = "Zona que congela a quien se quede.",
					en = "A zone that freezes whoever stays.",
				},
				type = "zone",
				stat = "m",
				power = 2.2,
				range = 28.8,
				radius = 14.4,
				dur = 6,
				tick = 0.5,
				cd = 0,
				status = {
					t = "slow",
					dur = 1,
					val = 0.6,
				},
				freezeAfter = 2,
			},
		},
	},
	{
		id = "golem",
		num = "08",
		file = "Golem",
		el = "tierra",
		role = "tanque",
		color = "#ffb23e",
		body = "#4b413a",
		bone = "#978b9e",
		stats = {
			pow = 85,
			def = 100,
			agi = 30,
			mag = 85,
		},
		circle = "pentagrama",
		halo = false,
		island = 2,
		nodes = 5,
		name = {
			es = "Gólem Rúnico",
			en = "Runic Golem",
		},
		sub = {
			es = "Constructo ancestral · Corazón de runas",
			en = "Ancient construct · Heart of runes",
		},
		lore = {
			es = "Ninguna de sus rocas se toca. Lo mantiene unido una sola runa encendida en el pecho.",
			en = "None of its rocks touch. A single rune burning in its chest holds it together.",
		},
		abilities = {
			{
				key = "q",
				name = {
					es = "Puñetazo sísmico",
					en = "Seismic Punch",
				},
				desc = {
					es = "Golpe pesado con onda.",
					en = "A heavy punch with a shockwave.",
				},
				type = "melee",
				stat = "p",
				power = 7.2,
				hits = 1,
				range = 8.64,
				arc = 130,
				cd = 1.15,
				cost = 0,
			},
			{
				key = "e",
				name = {
					es = "Escudo de rocas",
					en = "Rock Shield",
				},
				desc = {
					es = "Escudo del 30 % de tu vida.",
					en = "A shield worth 30% of your HP.",
				},
				type = "shield",
				pct = 0.3,
				dur = 6,
				cd = 10,
				cost = 25,
			},
			{
				key = "r",
				name = {
					es = "Atraer",
					en = "Pull",
				},
				desc = {
					es = "Atrae a los enemigos cercanos.",
					en = "Pulls nearby enemies in.",
				},
				type = "aoe",
				stat = "p",
				power = 3,
				range = 0,
				radius = 24,
				delay = 0,
				pull = 33.6,
				cd = 11,
				cost = 30,
				status = {
					t = "slow",
					dur = 2,
					val = 0.4,
				},
			},
			{
				key = "f",
				name = {
					es = "Núcleo desatado",
					en = "Core Unleashed",
				},
				desc = {
					es = "Onda que aturde y escuda al equipo.",
					en = "A wave that stuns and shields the team.",
				},
				type = "aoe",
				stat = "p",
				power = 10,
				range = 0,
				radius = 21.6,
				delay = 0,
				cd = 0,
				status = {
					t = "stun",
					dur = 2,
				},
				also = {
					type = "shield",
					pct = 0.3,
					dur = 6,
				},
			},
		},
	},
	{
		id = "leviatan",
		num = "09",
		file = "Leviatan",
		el = "cosmos",
		role = "hechicero",
		color = "#7f8cff",
		body = "#3f446a",
		bone = "#8e8aad",
		stats = {
			pow = 70,
			def = 70,
			agi = 60,
			mag = 100,
		},
		circle = "heptagrama",
		halo = false,
		island = 11,
		nodes = 8,
		name = {
			es = "Leviatán Celeste",
			en = "Celestial Leviathan",
		},
		sub = {
			es = "Titán del cielo · Nada entre estrellas",
			en = "Sky titan · Swims among stars",
		},
		lore = {
			es = "Las constelaciones de su piel cambian cada noche. Los astrónomos antiguos lo confundían con el cielo.",
			en = "The constellations on its skin change every night. Ancient astronomers mistook it for the sky.",
		},
		abilities = {
			{
				key = "q",
				name = {
					es = "Cometa",
					en = "Comet",
				},
				desc = {
					es = "Cometa que estalla al impactar.",
					en = "A comet that explodes on impact.",
				},
				type = "projectile",
				stat = "m",
				power = 5,
				count = 1,
				speed = 48,
				range = 38.4,
				radius = 2.16,
				explode = 5.76,
				cd = 1,
				cost = 0,
			},
			{
				key = "e",
				name = {
					es = "Canto estelar",
					en = "Star Song",
				},
				desc = {
					es = "Pulso que daña y te cura.",
					en = "A pulse that damages and heals you.",
				},
				type = "aoe",
				stat = "m",
				power = 2.2,
				range = 0,
				radius = 15.6,
				delay = 0,
				ticks = 3,
				dur = 1.5,
				cd = 8,
				cost = 25,
				selfHeal = 0.04,
			},
			{
				key = "r",
				name = {
					es = "Corriente astral",
					en = "Astral Current",
				},
				desc = {
					es = "Se desliza y gana velocidad.",
					en = "Glides and gains speed.",
				},
				type = "dash",
				stat = "m",
				power = 3,
				range = 24,
				speed = 72,
				width = 4.8,
				cd = 7,
				cost = 20,
				also = {
					type = "buff",
					spd = 0.4,
					dur = 3,
				},
			},
			{
				key = "f",
				name = {
					es = "Lluvia de meteoritos",
					en = "Meteor Shower",
				},
				desc = {
					es = "Meteoritos sobre toda la zona.",
					en = "Meteors rain over the whole area.",
				},
				type = "strike",
				stat = "m",
				power = 6.5,
				count = 12,
				radius = 7.2,
				delay = 0.7,
				interval = 0.15,
				area = true,
				cd = 0,
			},
		},
	},
	{
		id = "aracna",
		num = "10",
		file = "Aracna",
		el = "sombra",
		role = "soporte",
		color = "#ff4fd2",
		body = "#57495f",
		bone = "#9c86a7",
		stats = {
			pow = 75,
			def = 55,
			agi = 90,
			mag = 80,
		},
		circle = "hexagrama",
		halo = false,
		island = 9,
		nodes = 8,
		name = {
			es = "Reina Aracna",
			en = "Arachne Queen",
		},
		sub = {
			es = "Matriarca · Ocho ojos",
			en = "Matriarch · Eight eyes",
		},
		lore = {
			es = "Teje sellos en lugar de telarañas. Cada hilo que toca el suelo es un hechizo a punto de cerrarse.",
			en = "She weaves seals instead of webs. Every thread that touches the ground is a spell about to close.",
		},
		abilities = {
			{
				key = "q",
				name = {
					es = "Red rúnica",
					en = "Rune Web",
				},
				desc = {
					es = "Red que ralentiza.",
					en = "A web that slows.",
				},
				type = "projectile",
				stat = "m",
				power = 4,
				count = 1,
				speed = 48,
				range = 33.6,
				radius = 2.64,
				cd = 0.8,
				cost = 0,
				status = {
					t = "slow",
					dur = 2,
					val = 0.4,
				},
			},
			{
				key = "e",
				name = {
					es = "Veneno de sombra",
					en = "Shadow Venom",
				},
				desc = {
					es = "Charco que envenena.",
					en = "A pool that poisons.",
				},
				type = "zone",
				stat = "m",
				power = 1.4,
				range = 28.8,
				radius = 8.16,
				dur = 4,
				tick = 0.5,
				cd = 7,
				cost = 25,
				status = {
					t = "poison",
					dur = 3,
					val = 0.5,
				},
			},
			{
				key = "r",
				name = {
					es = "Crías trampa",
					en = "Trap Spawn",
				},
				desc = {
					es = "Tres crías que estallan al contacto.",
					en = "Three spawn that burst on contact.",
				},
				type = "mines",
				stat = "m",
				power = 6,
				count = 3,
				radius = 5.76,
				cd = 10,
				cost = 30,
			},
			{
				key = "f",
				name = {
					es = "Gran sello",
					en = "Great Seal",
				},
				desc = {
					es = "Atrapa a todos dentro del círculo.",
					en = "Traps everyone inside the circle.",
				},
				type = "aoe",
				stat = "m",
				power = 8,
				range = 0,
				radius = 26.4,
				delay = 0.3,
				cd = 0,
				status = {
					t = "root",
					dur = 3,
				},
			},
		},
	},
	{
		id = "ciervo",
		num = "11",
		file = "Ciervo",
		el = "luz",
		role = "soporte",
		color = "#ffd76a",
		body = "#534f55",
		bone = "#958d9e",
		stats = {
			pow = 55,
			def = 65,
			agi = 90,
			mag = 90,
		},
		circle = "heptagrama",
		halo = false,
		island = 1,
		nodes = 4,
		name = {
			es = "Ciervo Astral",
			en = "Astral Stag",
		},
		sub = {
			es = "Espíritu del bosque · Astas de cristal",
			en = "Forest spirit · Crystal antlers",
		},
		lore = {
			es = "Solo aparece en noches sin luna. Donde pisa nacen flores que brillan hasta el amanecer.",
			en = "It only appears on moonless nights. Where it steps, flowers bloom that glow until dawn.",
		},
		abilities = {
			{
				key = "q",
				name = {
					es = "Destello",
					en = "Flash",
				},
				desc = {
					es = "Rayo de luz veloz.",
					en = "A swift ray of light.",
				},
				type = "projectile",
				stat = "m",
				power = 4.2,
				count = 1,
				speed = 81.6,
				range = 38.4,
				radius = 1.68,
				cd = 0.7,
				cost = 0,
			},
			{
				key = "e",
				name = {
					es = "Flores curativas",
					en = "Healing Flowers",
				},
				desc = {
					es = "Jardín que cura mientras estés dentro.",
					en = "A garden that heals while you stand in it.",
				},
				type = "zone",
				heal = 0.035,
				range = 0,
				radius = 9.6,
				dur = 5,
				tick = 0.5,
				cd = 10,
				cost = 25,
			},
			{
				key = "r",
				name = {
					es = "Carga de astas",
					en = "Antler Charge",
				},
				desc = {
					es = "Embestida que empuja.",
					en = "A charge that knocks back.",
				},
				type = "dash",
				stat = "p",
				power = 7,
				range = 24,
				speed = 72,
				width = 5.28,
				knock = 12,
				cd = 8,
				cost = 30,
			},
			{
				key = "f",
				name = {
					es = "Amanecer",
					en = "Dawn",
				},
				desc = {
					es = "Cura total y quita efectos negativos.",
					en = "Full heal and removes negative effects.",
				},
				type = "heal",
				pct = 1,
				dur = 0,
				team = true,
				cleanse = true,
				burst = {
					stat = "m",
					power = 6,
					radius = 19.2,
				},
				cd = 0,
			},
		},
	},
	{
		id = "tortuga",
		num = "12",
		file = "Tortuga",
		el = "cristal",
		role = "tanque",
		color = "#b4ff4a",
		body = "#4f5347",
		bone = "#8f909e",
		stats = {
			pow = 65,
			def = 100,
			agi = 35,
			mag = 100,
		},
		circle = "pentagrama",
		halo = false,
		island = 6,
		nodes = 6,
		name = {
			es = "Tortuga Ancestral",
			en = "Ancient Tortoise",
		},
		sub = {
			es = "Titán milenario · Montaña viviente",
			en = "Thousand-year titan · Living mountain",
		},
		lore = {
			es = "Lleva mil años caminando. Los cristales de su caparazón crecen un palmo cada siglo.",
			en = "It has been walking for a thousand years. The crystals on its shell grow a handspan every century.",
		},
		abilities = {
			{
				key = "q",
				name = {
					es = "Embestida",
					en = "Ram",
				},
				desc = {
					es = "Embestida corta.",
					en = "A short ram.",
				},
				type = "dash",
				stat = "p",
				power = 5.2,
				range = 12,
				speed = 52.8,
				width = 5.28,
				cd = 1.1,
				cost = 0,
			},
			{
				key = "e",
				name = {
					es = "Muro de cristal",
					en = "Crystal Wall",
				},
				desc = {
					es = "Escudo que refleja proyectiles.",
					en = "A shield that reflects projectiles.",
				},
				type = "shield",
				pct = 0.32,
				dur = 5,
				reflect = 0.3,
				cd = 9,
				cost = 25,
			},
			{
				key = "r",
				name = {
					es = "Refugio",
					en = "Refuge",
				},
				desc = {
					es = "Escudo y regeneración para el equipo.",
					en = "Shield and regeneration for the team.",
				},
				type = "heal",
				pct = 0.18,
				dur = 5,
				team = true,
				cd = 14,
				cost = 35,
				also = {
					type = "shield",
					pct = 0.15,
					dur = 5,
				},
			},
			{
				key = "f",
				name = {
					es = "Montaña viva",
					en = "Living Mountain",
				},
				desc = {
					es = "Torres de cristal que cierran el paso.",
					en = "Crystal towers that block the way.",
				},
				type = "strike",
				stat = "m",
				power = 8,
				count = 6,
				radius = 6.24,
				delay = 0.5,
				interval = 0.12,
				status = {
					t = "root",
					dur = 2,
				},
				cd = 0,
			},
		},
	},
}

GameData.Islands = {
	{
		index = 1,
		id = "arboleda",
		name = {
			es = "Arboleda Astral",
			en = "Astral Grove",
		},
		desc = {
			es = "Bosque nocturno con flores que brillan.",
			en = "A night forest with glowing flowers.",
		},
		levels = { 1, 8 },
		boss = "ciervo",
		pool = { "ciervo", "golem" },
		props = "flores",
	},
	{
		index = 2,
		id = "cantera",
		name = {
			es = "Cantera Rúnica",
			en = "Runic Quarry",
		},
		desc = {
			es = "Ruinas con runas que abren atajos.",
			en = "Ruins whose runes open shortcuts.",
		},
		levels = { 6, 14 },
		boss = "golem",
		pool = { "golem", "tortuga", "ciervo" },
		props = "pilares",
	},
	{
		index = 3,
		id = "pantano",
		name = {
			es = "Pantano Esmeralda",
			en = "Emerald Marsh",
		},
		desc = {
			es = "Niebla tóxica y estatuas de aventureros petrificados.",
			en = "Toxic fog and petrified adventurers.",
		},
		levels = { 12, 20 },
		boss = "basilisco",
		pool = { "basilisco", "aracna", "golem" },
		props = "estatuas",
	},
	{
		index = 4,
		id = "picos",
		name = {
			es = "Picos Helados",
			en = "Frozen Peaks",
		},
		desc = {
			es = "Suelo resbaladizo y ventiscas que tapan la vista.",
			en = "Slippery ground and blinding blizzards.",
		},
		levels = { 18, 26 },
		boss = "wyvern",
		pool = { "wyvern", "grifo", "tortuga" },
		props = "hielo",
	},
	{
		index = 5,
		id = "nido",
		name = {
			es = "Nido de Tormentas",
			en = "Storm Nest",
		},
		desc = {
			es = "Islotes unidos por corrientes de viento.",
			en = "Islets joined by wind currents.",
		},
		levels = { 22, 30 },
		boss = "grifo",
		pool = { "grifo", "wyvern", "fenix" },
		props = "rocas",
	},
	{
		index = 6,
		id = "desierto",
		name = {
			es = "Desierto de Cristal",
			en = "Crystal Desert",
		},
		desc = {
			es = "Dunas que se mueven y cristales que reflejan ataques.",
			en = "Shifting dunes and mirror crystals.",
		},
		levels = { 26, 34 },
		boss = "tortuga",
		pool = { "tortuga", "basilisco", "cerbero" },
		props = "cristales",
	},
	{
		index = 7,
		id = "forja",
		name = {
			es = "Forja Solar",
			en = "Solar Forge",
		},
		desc = {
			es = "Volcán con ríos de luz y plataformas que arden.",
			en = "A volcano with rivers of light.",
		},
		levels = { 30, 38 },
		boss = "fenix",
		pool = { "fenix", "cerbero", "golem" },
		props = "lava",
	},
	{
		index = 8,
		id = "fosa",
		name = {
			es = "Fosa Abisal",
			en = "Abyssal Trench",
		},
		desc = {
			es = "Medio sumergida: la única luz es la de las criaturas.",
			en = "Half-sunken: the only light is the creatures’.",
		},
		levels = { 34, 42 },
		boss = "kraken",
		pool = { "kraken", "leviatan", "wyvern" },
		props = "corales",
	},
	{
		index = 9,
		id = "telar",
		name = {
			es = "Telar Umbrío",
			en = "Shadow Loom",
		},
		desc = {
			es = "Telarañas-sello que hay que cortar para avanzar.",
			en = "Seal-webs you must cut to advance.",
		},
		levels = { 38, 46 },
		boss = "aracna",
		pool = { "aracna", "basilisco", "hidra" },
		props = "telas",
	},
	{
		index = 10,
		id = "puertas",
		name = {
			es = "Puertas del Inframundo",
			en = "Underworld Gates",
		},
		desc = {
			es = "Arena de fuego con tres puertas y tres guardianes.",
			en = "A fire arena with three gates.",
		},
		levels = { 42, 50 },
		boss = "cerbero",
		pool = { "cerbero", "fenix", "aracna" },
		props = "lava",
	},
	{
		index = 11,
		id = "mar",
		name = {
			es = "Mar de Estrellas",
			en = "Sea of Stars",
		},
		desc = {
			es = "Islas en el cielo; se viaja montado en criaturas.",
			en = "Islands in the sky, travelled on creatures.",
		},
		levels = { 46, 55 },
		boss = "leviatan",
		pool = { "leviatan", "grifo", "kraken" },
		props = "estrellas",
	},
	{
		index = 12,
		id = "corazon",
		name = {
			es = "Corazón del Vacío",
			en = "Heart of the Void",
		},
		desc = {
			es = "Incursión final: el suelo se rompe en cada fase.",
			en = "Final raid: the ground breaks each phase.",
		},
		levels = { 55, 60 },
		boss = "hidra",
		pool = { "hidra", "aracna", "leviatan" },
		props = "vacio",
	},
}

GameData.Tips = {
	es = { "Lleva tres dominios distintos en tu equipo: así nunca te quedarás sin ventaja.", "Abisal vence a Ígneo, Ígneo a Natural, Natural a Arcano y Arcano a Abisal.", "Una criatura se puede sellar cuando su vida baja del 25 %.", "Un trazo perfecto da +50 % de Esencia y un vínculo inicial alto.", "La Tinta Rúnica se recarga sola: 1 cada 10 minutos, hasta 10.", "Golpear llena la barra de Sello. Al 100 % libera la Definitiva (F).", "Esquiva (Espacio) te vuelve intocable durante un instante.", "Cambia de criatura (1 · 2 · 3) para aprovechar la ventaja de dominio.", "Los círculos rojos en el suelo avisan de un ataque: sal de ellos.", "En la tercera fase, rompe las cuatro anclas rúnicas para poder sellar al Primordial.", "Las Crías evolucionan a Adultas en el nivel 20 con 30 Fragmentos de su elemento.", "Completa contratos diarios para ganar Esencia y avanzar el Pase Arcano." },
	en = { "Bring three different domains: you will never run out of advantage.", "Abyssal beats Igneous, Igneous beats Natural, Natural beats Arcane and Arcane beats Abyssal.", "A creature can be sealed once its HP drops below 25%.", "A perfect trace grants +50% Essence and a strong starting bond.", "Runic Ink refills on its own: 1 every 10 minutes, up to 10.", "Hitting fills the Seal bar. At 100% it unleashes the Ultimate (F).", "Dodge (Space) makes you untouchable for an instant.", "Switch creatures (1 · 2 · 3) to exploit domain advantage.", "Red circles on the ground warn of an attack: get out of them.", "In the third phase, break the four rune anchors to seal the Primordial.", "Hatchlings evolve into Adults at level 20 with 30 Fragments of their element.", "Finish daily contracts to earn Essence and progress the Arcane Pass." },
}

GameData.Tints = {
	{
		id = "hidra_ff3d3d",
		creature = "hidra",
		color = "#ff3d3d",
		price = 150,
		name = {
			es = "Carmesí",
			en = "Crimson",
		},
	},
	{
		id = "hidra_2ff2d6",
		creature = "hidra",
		color = "#2ff2d6",
		price = 150,
		name = {
			es = "Turquesa",
			en = "Turquoise",
		},
	},
	{
		id = "hidra_ff4fd2",
		creature = "hidra",
		color = "#ff4fd2",
		price = 150,
		name = {
			es = "Magenta",
			en = "Magenta",
		},
	},
	{
		id = "hidra_prisma",
		creature = "hidra",
		color = "prisma",
		price = 600,
		premium = true,
		name = {
			es = "Prisma",
			en = "Prism",
		},
	},
	{
		id = "fenix_ffd76a",
		creature = "fenix",
		color = "#ffd76a",
		price = 150,
		name = {
			es = "Oro Astral",
			en = "Astral Gold",
		},
	},
	{
		id = "fenix_ff3d3d",
		creature = "fenix",
		color = "#ff3d3d",
		price = 150,
		name = {
			es = "Carmesí",
			en = "Crimson",
		},
	},
	{
		id = "fenix_4fb4ff",
		creature = "fenix",
		color = "#4fb4ff",
		price = 150,
		name = {
			es = "Azur",
			en = "Azure",
		},
	},
	{
		id = "fenix_prisma",
		creature = "fenix",
		color = "prisma",
		price = 600,
		premium = true,
		name = {
			es = "Prisma",
			en = "Prism",
		},
	},
	{
		id = "kraken_4fb4ff",
		creature = "kraken",
		color = "#4fb4ff",
		price = 150,
		name = {
			es = "Azur",
			en = "Azure",
		},
	},
	{
		id = "kraken_b06bff",
		creature = "kraken",
		color = "#b06bff",
		price = 150,
		name = {
			es = "Violeta del Vacío",
			en = "Void Violet",
		},
	},
	{
		id = "kraken_3dff88",
		creature = "kraken",
		color = "#3dff88",
		price = 150,
		name = {
			es = "Esmeralda",
			en = "Emerald",
		},
	},
	{
		id = "kraken_prisma",
		creature = "kraken",
		color = "prisma",
		price = 600,
		premium = true,
		name = {
			es = "Prisma",
			en = "Prism",
		},
	},
	{
		id = "grifo_9fefff",
		creature = "grifo",
		color = "#9fefff",
		price = 150,
		name = {
			es = "Escarcha",
			en = "Frost",
		},
	},
	{
		id = "grifo_ffd76a",
		creature = "grifo",
		color = "#ffd76a",
		price = 150,
		name = {
			es = "Oro Astral",
			en = "Astral Gold",
		},
	},
	{
		id = "grifo_b06bff",
		creature = "grifo",
		color = "#b06bff",
		price = 150,
		name = {
			es = "Violeta del Vacío",
			en = "Void Violet",
		},
	},
	{
		id = "grifo_prisma",
		creature = "grifo",
		color = "prisma",
		price = 600,
		premium = true,
		name = {
			es = "Prisma",
			en = "Prism",
		},
	},
	{
		id = "cerbero_ff7a2e",
		creature = "cerbero",
		color = "#ff7a2e",
		price = 150,
		name = {
			es = "Ascua",
			en = "Ember",
		},
	},
	{
		id = "cerbero_b06bff",
		creature = "cerbero",
		color = "#b06bff",
		price = 150,
		name = {
			es = "Violeta del Vacío",
			en = "Void Violet",
		},
	},
	{
		id = "cerbero_3dff88",
		creature = "cerbero",
		color = "#3dff88",
		price = 150,
		name = {
			es = "Esmeralda",
			en = "Emerald",
		},
	},
	{
		id = "cerbero_prisma",
		creature = "cerbero",
		color = "prisma",
		price = 600,
		premium = true,
		name = {
			es = "Prisma",
			en = "Prism",
		},
	},
	{
		id = "basilisco_b4ff4a",
		creature = "basilisco",
		color = "#b4ff4a",
		price = 150,
		name = {
			es = "Lima",
			en = "Lime",
		},
	},
	{
		id = "basilisco_2ff2d6",
		creature = "basilisco",
		color = "#2ff2d6",
		price = 150,
		name = {
			es = "Turquesa",
			en = "Turquoise",
		},
	},
	{
		id = "basilisco_ff4fd2",
		creature = "basilisco",
		color = "#ff4fd2",
		price = 150,
		name = {
			es = "Magenta",
			en = "Magenta",
		},
	},
	{
		id = "basilisco_prisma",
		creature = "basilisco",
		color = "prisma",
		price = 600,
		premium = true,
		name = {
			es = "Prisma",
			en = "Prism",
		},
	},
	{
		id = "wyvern_4fb4ff",
		creature = "wyvern",
		color = "#4fb4ff",
		price = 150,
		name = {
			es = "Azur",
			en = "Azure",
		},
	},
	{
		id = "wyvern_7f8cff",
		creature = "wyvern",
		color = "#7f8cff",
		price = 150,
		name = {
			es = "Índigo",
			en = "Indigo",
		},
	},
	{
		id = "wyvern_ffffff",
		creature = "wyvern",
		color = "#ffffff",
		price = 150,
		name = {
			es = "Nieve",
			en = "Snow",
		},
	},
	{
		id = "wyvern_prisma",
		creature = "wyvern",
		color = "prisma",
		price = 600,
		premium = true,
		name = {
			es = "Prisma",
			en = "Prism",
		},
	},
	{
		id = "golem_ff3d3d",
		creature = "golem",
		color = "#ff3d3d",
		price = 150,
		name = {
			es = "Carmesí",
			en = "Crimson",
		},
	},
	{
		id = "golem_2ff2d6",
		creature = "golem",
		color = "#2ff2d6",
		price = 150,
		name = {
			es = "Turquesa",
			en = "Turquoise",
		},
	},
	{
		id = "golem_b06bff",
		creature = "golem",
		color = "#b06bff",
		price = 150,
		name = {
			es = "Violeta del Vacío",
			en = "Void Violet",
		},
	},
	{
		id = "golem_prisma",
		creature = "golem",
		color = "prisma",
		price = 600,
		premium = true,
		name = {
			es = "Prisma",
			en = "Prism",
		},
	},
	{
		id = "leviatan_b06bff",
		creature = "leviatan",
		color = "#b06bff",
		price = 150,
		name = {
			es = "Violeta del Vacío",
			en = "Void Violet",
		},
	},
	{
		id = "leviatan_2ff2d6",
		creature = "leviatan",
		color = "#2ff2d6",
		price = 150,
		name = {
			es = "Turquesa",
			en = "Turquoise",
		},
	},
	{
		id = "leviatan_ffd76a",
		creature = "leviatan",
		color = "#ffd76a",
		price = 150,
		name = {
			es = "Oro Astral",
			en = "Astral Gold",
		},
	},
	{
		id = "leviatan_prisma",
		creature = "leviatan",
		color = "prisma",
		price = 600,
		premium = true,
		name = {
			es = "Prisma",
			en = "Prism",
		},
	},
	{
		id = "aracna_b06bff",
		creature = "aracna",
		color = "#b06bff",
		price = 150,
		name = {
			es = "Violeta del Vacío",
			en = "Void Violet",
		},
	},
	{
		id = "aracna_ff3d3d",
		creature = "aracna",
		color = "#ff3d3d",
		price = 150,
		name = {
			es = "Carmesí",
			en = "Crimson",
		},
	},
	{
		id = "aracna_3dff88",
		creature = "aracna",
		color = "#3dff88",
		price = 150,
		name = {
			es = "Esmeralda",
			en = "Emerald",
		},
	},
	{
		id = "aracna_prisma",
		creature = "aracna",
		color = "prisma",
		price = 600,
		premium = true,
		name = {
			es = "Prisma",
			en = "Prism",
		},
	},
	{
		id = "ciervo_9fefff",
		creature = "ciervo",
		color = "#9fefff",
		price = 150,
		name = {
			es = "Escarcha",
			en = "Frost",
		},
	},
	{
		id = "ciervo_ff4fd2",
		creature = "ciervo",
		color = "#ff4fd2",
		price = 150,
		name = {
			es = "Magenta",
			en = "Magenta",
		},
	},
	{
		id = "ciervo_3dff88",
		creature = "ciervo",
		color = "#3dff88",
		price = 150,
		name = {
			es = "Esmeralda",
			en = "Emerald",
		},
	},
	{
		id = "ciervo_prisma",
		creature = "ciervo",
		color = "prisma",
		price = 600,
		premium = true,
		name = {
			es = "Prisma",
			en = "Prism",
		},
	},
	{
		id = "tortuga_2ff2d6",
		creature = "tortuga",
		color = "#2ff2d6",
		price = 150,
		name = {
			es = "Turquesa",
			en = "Turquoise",
		},
	},
	{
		id = "tortuga_ffb23e",
		creature = "tortuga",
		color = "#ffb23e",
		price = 150,
		name = {
			es = "Ámbar",
			en = "Amber",
		},
	},
	{
		id = "tortuga_ff4fd2",
		creature = "tortuga",
		color = "#ff4fd2",
		price = 150,
		name = {
			es = "Magenta",
			en = "Magenta",
		},
	},
	{
		id = "tortuga_prisma",
		creature = "tortuga",
		color = "prisma",
		price = 600,
		premium = true,
		name = {
			es = "Prisma",
			en = "Prism",
		},
	},
	{
		id = "hidra_eclipse",
		creature = "hidra",
		color = "#ffcf5a",
		img = "hidra_eclipsedorado",
		price = 400,
		name = {
			es = "Eclipse Dorado",
			en = "Golden Eclipse",
		},
		season = true,
	},
	{
		id = "cerbero_llamaazul",
		creature = "cerbero",
		color = "#3d9bff",
		img = "cerbero_llamaazul",
		price = 250,
		name = {
			es = "Llama Azul",
			en = "Blue Flame",
		},
		season = true,
	},
	{
		id = "fenix_jade",
		creature = "fenix",
		color = "#5dffb0",
		img = "fenix_jade",
		price = 250,
		name = {
			es = "Fénix de Jade",
			en = "Jade Phoenix",
		},
		season = true,
	},
	{
		id = "wyvern_aurora",
		creature = "wyvern",
		color = "aurora",
		img = "wyvern_aurora",
		price = 250,
		name = {
			es = "Aurora",
			en = "Aurora",
		},
		season = true,
	},
}

GameData.Seals = {
	{
		id = "propio",
		price = 0,
		name = {
			es = "Sello propio",
			en = "Own seal",
		},
		desc = {
			es = "El círculo original de cada criatura.",
			en = "Each creature’s original circle.",
		},
	},
	{
		id = "hexagrama",
		price = 150,
		name = {
			es = "Hexagrama",
			en = "Hexagram",
		},
		desc = {
			es = "Seis puntas para todas tus criaturas.",
			en = "Six points for all your creatures.",
		},
	},
	{
		id = "heptagrama",
		price = 150,
		name = {
			es = "Heptagrama",
			en = "Heptagram",
		},
		desc = {
			es = "Siete puntas para todas tus criaturas.",
			en = "Seven points for all your creatures.",
		},
	},
	{
		id = "pentagrama",
		price = 150,
		name = {
			es = "Pentagrama",
			en = "Pentagram",
		},
		desc = {
			es = "Cinco puntas para todas tus criaturas.",
			en = "Five points for all your creatures.",
		},
	},
	{
		id = "corona",
		price = 300,
		name = {
			es = "Corona Solar",
			en = "Solar Crown",
		},
		desc = {
			es = "Rayos que giran como un sol.",
			en = "Rays that spin like a sun.",
		},
	},
	{
		id = "constelacion",
		price = 300,
		name = {
			es = "Constelación",
			en = "Constellation",
		},
		desc = {
			es = "Estrellas unidas por hilos de luz.",
			en = "Stars joined by threads of light.",
		},
	},
	{
		id = "eclipse",
		price = 450,
		season = true,
		name = {
			es = "Sello del Eclipse",
			en = "Eclipse Seal",
		},
		desc = {
			es = "Exclusivo de la temporada Eclipse.",
			en = "Eclipse season exclusive.",
		},
	},
}

GameData.Effects = {
	{
		id = "anillo",
		price = 0,
		name = {
			es = "Anillo rúnico",
			en = "Rune ring",
		},
	},
	{
		id = "estrellas",
		price = 200,
		name = {
			es = "Lluvia de estrellas",
			en = "Starfall",
		},
	},
	{
		id = "pilar",
		price = 200,
		name = {
			es = "Pilar de luz",
			en = "Pillar of light",
		},
	},
	{
		id = "espiral",
		price = 250,
		name = {
			es = "Espiral arcana",
			en = "Arcane spiral",
		},
	},
}

GameData.PassTiers = {
	{
		n = 1,
		free = {
			essence = 170,
		},
		prem = {
			essence = 430,
			ink = 1,
		},
	},
	{
		n = 2,
		free = {
			essence = 190,
		},
		prem = {
			crystals = 40,
		},
	},
	{
		n = 3,
		free = {
			ink = 2,
		},
		prem = {
			essence = 490,
			ink = 1,
		},
	},
	{
		n = 4,
		free = {
			essence = 230,
		},
		prem = {
			crystals = 40,
		},
	},
	{
		n = 5,
		free = {
			crystals = 15,
		},
		prem = {
			seal = "constelacion",
		},
	},
	{
		n = 6,
		free = {
			ink = 2,
		},
		prem = {
			crystals = 40,
		},
	},
	{
		n = 7,
		free = {
			essence = 290,
		},
		prem = {
			essence = 610,
			ink = 1,
		},
	},
	{
		n = 8,
		free = {
			essence = 310,
		},
		prem = {
			crystals = 40,
		},
	},
	{
		n = 9,
		free = {
			ink = 2,
		},
		prem = {
			essence = 670,
			ink = 1,
		},
	},
	{
		n = 10,
		free = {
			crystals = 15,
		},
		prem = {
			tint = "wyvern_aurora",
		},
	},
	{
		n = 11,
		free = {
			essence = 370,
		},
		prem = {
			essence = 730,
			ink = 1,
		},
	},
	{
		n = 12,
		free = {
			ink = 2,
		},
		prem = {
			crystals = 40,
		},
	},
	{
		n = 13,
		free = {
			essence = 410,
		},
		prem = {
			essence = 790,
			ink = 1,
		},
	},
	{
		n = 14,
		free = {
			essence = 430,
		},
		prem = {
			crystals = 40,
		},
	},
	{
		n = 15,
		free = {
			crystals = 15,
		},
		prem = {
			effect = "pilar",
		},
	},
	{
		n = 16,
		free = {
			essence = 470,
		},
		prem = {
			crystals = 40,
		},
	},
	{
		n = 17,
		free = {
			essence = 490,
		},
		prem = {
			essence = 910,
			ink = 1,
		},
	},
	{
		n = 18,
		free = {
			ink = 2,
		},
		prem = {
			crystals = 40,
		},
	},
	{
		n = 19,
		free = {
			essence = 530,
		},
		prem = {
			essence = 970,
			ink = 1,
		},
	},
	{
		n = 20,
		free = {
			crystals = 15,
		},
		prem = {
			tint = "hidra_eclipse",
		},
	},
	{
		n = 21,
		free = {
			ink = 2,
		},
		prem = {
			essence = 1030,
			ink = 1,
		},
	},
	{
		n = 22,
		free = {
			essence = 590,
		},
		prem = {
			crystals = 40,
		},
	},
	{
		n = 23,
		free = {
			essence = 610,
		},
		prem = {
			essence = 1090,
			ink = 1,
		},
	},
	{
		n = 24,
		free = {
			ink = 2,
		},
		prem = {
			crystals = 40,
		},
	},
	{
		n = 25,
		free = {
			crystals = 15,
		},
		prem = {
			effect = "espiral",
		},
	},
	{
		n = 26,
		free = {
			essence = 670,
		},
		prem = {
			crystals = 40,
		},
	},
	{
		n = 27,
		free = {
			ink = 2,
		},
		prem = {
			essence = 1210,
			ink = 1,
		},
	},
	{
		n = 28,
		free = {
			essence = 710,
		},
		prem = {
			crystals = 40,
		},
	},
	{
		n = 29,
		free = {
			essence = 730,
		},
		prem = {
			essence = 1270,
			ink = 1,
		},
	},
	{
		n = 30,
		free = {
			crystals = 15,
		},
		prem = {
			seal = "eclipse",
		},
	},
}

GameData.PassXpPerTier = 100

GameData.Daily = {
	{
		essence = 200,
	},
	{
		ink = 2,
	},
	{
		essence = 300,
		fragments = 5,
	},
	{
		essence = 400,
		ink = 3,
	},
	{
		crystals = 10,
	},
	{
		essence = 600,
	},
	{
		crystals = 30,
		ink = 5,
	},
}

-- índices por id
GameData.CreatureById = {}
for _, c in ipairs(GameData.Creatures) do
	GameData.CreatureById[c.id] = c
	c.abilityByKey = {}
	for _, a in ipairs(c.abilities) do
		c.abilityByKey[a.key] = a
	end
end
GameData.TintById = {}
for _, t in ipairs(GameData.Tints) do
	GameData.TintById[t.id] = t
end
GameData.SealById = {}
for _, s in ipairs(GameData.Seals) do
	GameData.SealById[s.id] = s
end
GameData.EffectById = {}
for _, e in ipairs(GameData.Effects) do
	GameData.EffectById[e.id] = e
end
GameData.Starters = { "fenix", "kraken", "basilisco" }

return GameData
