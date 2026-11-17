// Las 12 Bestias Primordiales. Datos tomados del documento de diseño y del
// lienzo «Bestiario Mágico» (estadísticas de 300 puntos, colores, lore).
// stats: [Poder, Defensa, Agilidad, Magia]

export const ELEMENTS = {
  vacio: { es: 'Vacío', en: 'Void', domain: 'arcano' },
  fuego: { es: 'Fuego', en: 'Fire', domain: 'igneo' },
  abismo: { es: 'Abismo', en: 'Abyss', domain: 'abisal' },
  rayo: { es: 'Rayo', en: 'Lightning', domain: 'igneo' },
  infierno: { es: 'Infierno', en: 'Inferno', domain: 'igneo' },
  veneno: { es: 'Veneno', en: 'Poison', domain: 'natural' },
  hielo: { es: 'Hielo', en: 'Ice', domain: 'abisal' },
  tierra: { es: 'Tierra', en: 'Earth', domain: 'natural' },
  cosmos: { es: 'Cosmos', en: 'Cosmos', domain: 'abisal' },
  sombra: { es: 'Sombra', en: 'Shadow', domain: 'arcano' },
  luz: { es: 'Luz', en: 'Light', domain: 'arcano' },
  cristal: { es: 'Cristal', en: 'Crystal', domain: 'natural' },
};

// Ciclo de dominios: cada uno vence al siguiente (+30 %).
// Abisal > Ígneo > Natural > Arcano > Abisal
export const DOMAINS = {
  abisal: { es: 'Abisal', en: 'Abyssal', beats: 'igneo', color: '#2ff2d6' },
  igneo: { es: 'Ígneo', en: 'Igneous', beats: 'natural', color: '#ff7a2e' },
  natural: { es: 'Natural', en: 'Natural', beats: 'arcano', color: '#3dff88' },
  arcano: { es: 'Arcano', en: 'Arcane', beats: 'abisal', color: '#b06bff' },
};

export const ROLES = {
  asalto: { es: 'Asalto', en: 'Assault' },
  tanque: { es: 'Tanque', en: 'Tank' },
  hechicero: { es: 'Hechicero', en: 'Sorcerer' },
  soporte: { es: 'Soporte', en: 'Support' },
};

export const FORMS = [
  { es: 'Cría', en: 'Hatchling', scale: 0.62, mult: 1.0 },
  { es: 'Adulta', en: 'Adult', scale: 0.78, mult: 1.12 },
  { es: 'Primordial', en: 'Primordial', scale: 0.92, mult: 1.3 },
];

export function domainMult(attEl, defEl) {
  const a = ELEMENTS[attEl].domain;
  const d = ELEMENTS[defEl].domain;
  if (DOMAINS[a].beats === d) return 1.3;
  if (DOMAINS[d].beats === a) return 0.77;
  return 1;
}

const rgb = (r, g, b) => (r << 16) | (g << 8) | b;

export const CREATURES = [
  {
    id: 'hidra', num: '01', el: 'vacio', role: 'asalto', color: '#b06bff',
    body: rgb(80, 74, 100), bone: rgb(146, 136, 174), stats: [90, 70, 45, 95],
    circle: 'hexagrama', halo: true, island: 11, nodes: 9,
    name: { es: 'Hidra del Vacío', en: 'Void Hydra' },
    sub: { es: 'Jefe colosal · Cinco cabezas', en: 'Colossal boss · Five heads' },
    lore: {
      es: 'Cada cabeza recuerda una estrella que devoró. Si cortas una, el vacío hace crecer dos.',
      en: 'Each head remembers a star it devoured. Cut one off and the void grows two.',
    },
  },
  {
    id: 'fenix', num: '02', el: 'fuego', role: 'soporte', color: '#ff7a2e',
    body: rgb(86, 75, 87), bone: rgb(155, 136, 157), stats: [70, 45, 85, 100],
    circle: 'heptagrama', halo: true, island: 6, nodes: 7,
    name: { es: 'Fénix Solar', en: 'Solar Phoenix' },
    sub: { es: 'Ave legendaria · Renace de su ceniza', en: 'Legendary bird · Reborn from its ashes' },
    lore: {
      es: 'Cuando muere se convierte en amanecer. Sus plumas siguen ardiendo mil años después de caer.',
      en: 'When it dies it becomes a sunrise. Its feathers keep burning a thousand years after they fall.',
    },
  },
  {
    id: 'kraken', num: '03', el: 'abismo', role: 'tanque', color: '#2ff2d6',
    body: rgb(73, 81, 92), bone: rgb(138, 144, 164), stats: [80, 95, 35, 90],
    circle: 'pentagrama', island: 7, nodes: 8,
    name: { es: 'Kraken Abisal', en: 'Abyssal Kraken' },
    sub: { es: 'Titán marino · Ocho brazos', en: 'Sea titan · Eight arms' },
    lore: {
      es: 'Duerme bajo la fosa más honda del océano. Sus ojos son la única luz que ven los barcos hundidos.',
      en: "It sleeps beneath the ocean's deepest trench. Its eyes are the only light sunken ships ever see.",
    },
  },
  {
    id: 'grifo', num: '04', el: 'rayo', role: 'asalto', color: '#4fb4ff',
    body: rgb(74, 78, 97), bone: rgb(139, 141, 170), stats: [95, 55, 100, 50],
    circle: 'hexagrama', island: 4, nodes: 6,
    name: { es: 'Grifo de Tormenta', en: 'Storm Griffin' },
    sub: { es: 'Guardián alado · Cazador del cielo', en: 'Winged guardian · Sky hunter' },
    lore: {
      es: 'Mitad águila, mitad león. Cada batir de alas suelta un relámpago sobre quien ose tocar su nido.',
      en: 'Half eagle, half lion. Every beat of its wings looses lightning on whoever dares touch its nest.',
    },
  },
  {
    id: 'cerbero', num: '05', el: 'infierno', role: 'asalto', color: '#ff3d3d',
    body: rgb(89, 73, 87), bone: rgb(158, 134, 158), stats: [100, 70, 85, 45],
    circle: 'pentagrama', island: 9, nodes: 6,
    name: { es: 'Cerbero Infernal', en: 'Infernal Cerberus' },
    sub: { es: 'Guardián del umbral · Tres cabezas', en: 'Threshold guardian · Three heads' },
    lore: {
      es: 'Una cabeza vigila el pasado, otra el presente y la última el futuro. Ninguna duerme jamás.',
      en: 'One head watches the past, another the present and the last the future. None of them ever sleeps.',
    },
  },
  {
    id: 'basilisco', num: '06', el: 'veneno', role: 'hechicero', color: '#3dff88',
    body: rgb(73, 81, 89), bone: rgb(138, 145, 159), stats: [75, 65, 60, 100],
    circle: 'heptagrama', island: 2, nodes: 7,
    name: { es: 'Basilisco Esmeralda', en: 'Emerald Basilisk' },
    sub: { es: 'Rey de las serpientes · Mirada de piedra', en: 'King of serpents · Stone gaze' },
    lore: {
      es: 'Su corona es de hueso y su mirada, de piedra. Quienes lo enfrentaron siguen en pie, convertidos en estatuas.',
      en: 'Its crown is bone and its gaze is stone. Those who faced it still stand, turned to statues.',
    },
  },
  {
    id: 'wyvern', num: '07', el: 'hielo', role: 'hechicero', color: '#9fefff',
    body: rgb(76, 80, 94), bone: rgb(142, 143, 167), stats: [80, 60, 65, 95],
    circle: 'hexagrama', island: 3, nodes: 6,
    name: { es: 'Wyvern de Escarcha', en: 'Frost Wyvern' },
    sub: { es: 'Dragón bípedo · Aliento helado', en: 'Two-legged dragon · Frost breath' },
    lore: {
      es: 'Anida en los picos donde el viento no deja huellas. Su aliento convierte la lluvia en cristal.',
      en: 'It nests on peaks where the wind leaves no tracks. Its breath turns rain into crystal.',
    },
  },
  {
    id: 'golem', num: '08', el: 'tierra', role: 'tanque', color: '#ffb23e',
    body: rgb(75, 65, 58), bone: rgb(151, 139, 158), stats: [85, 100, 30, 85],
    circle: 'pentagrama', island: 1, nodes: 5,
    name: { es: 'Gólem Rúnico', en: 'Runic Golem' },
    sub: { es: 'Constructo ancestral · Corazón de runas', en: 'Ancient construct · Heart of runes' },
    lore: {
      es: 'Ninguna de sus rocas se toca. Lo mantiene unido una sola runa encendida en el pecho.',
      en: 'None of its rocks touch. A single rune burning in its chest holds it together.',
    },
  },
  {
    id: 'leviatan', num: '09', el: 'cosmos', role: 'hechicero', color: '#7f8cff',
    body: rgb(63, 68, 106), bone: rgb(142, 138, 173), stats: [70, 70, 60, 100],
    circle: 'heptagrama', island: 10, nodes: 8,
    name: { es: 'Leviatán Celeste', en: 'Celestial Leviathan' },
    sub: { es: 'Titán del cielo · Nada entre estrellas', en: 'Sky titan · Swims among stars' },
    lore: {
      es: 'Las constelaciones de su piel cambian cada noche. Los astrónomos antiguos lo confundían con el cielo.',
      en: 'The constellations on its skin change every night. Ancient astronomers mistook it for the sky.',
    },
  },
  {
    id: 'aracna', num: '10', el: 'sombra', role: 'soporte', color: '#ff4fd2',
    body: rgb(87, 73, 95), bone: rgb(156, 134, 167), stats: [75, 55, 90, 80],
    circle: 'hexagrama', island: 8, nodes: 8,
    name: { es: 'Reina Aracna', en: 'Arachne Queen' },
    sub: { es: 'Matriarca · Ocho ojos', en: 'Matriarch · Eight eyes' },
    lore: {
      es: 'Teje sellos en lugar de telarañas. Cada hilo que toca el suelo es un hechizo a punto de cerrarse.',
      en: 'She weaves seals instead of webs. Every thread that touches the ground is a spell about to close.',
    },
  },
  {
    id: 'ciervo', num: '11', el: 'luz', role: 'soporte', color: '#ffd76a',
    body: rgb(83, 79, 85), bone: rgb(149, 141, 158), stats: [55, 65, 90, 90],
    circle: 'heptagrama', island: 0, nodes: 4,
    name: { es: 'Ciervo Astral', en: 'Astral Stag' },
    sub: { es: 'Espíritu del bosque · Astas de cristal', en: 'Forest spirit · Crystal antlers' },
    lore: {
      es: 'Solo aparece en noches sin luna. Donde pisa nacen flores que brillan hasta el amanecer.',
      en: 'It only appears on moonless nights. Where it steps, flowers bloom that glow until dawn.',
    },
  },
  {
    id: 'tortuga', num: '12', el: 'cristal', role: 'tanque', color: '#b4ff4a',
    body: rgb(79, 83, 71), bone: rgb(143, 144, 158), stats: [65, 100, 35, 100],
    circle: 'pentagrama', island: 5, nodes: 6,
    name: { es: 'Tortuga Ancestral', en: 'Ancient Tortoise' },
    sub: { es: 'Titán milenario · Montaña viviente', en: 'Thousand-year titan · Living mountain' },
    lore: {
      es: 'Lleva mil años caminando. Los cristales de su caparazón crecen un palmo cada siglo.',
      en: 'It has been walking for a thousand years. The crystals on its shell grow a handspan every century.',
    },
  },
];

export const CREATURE = Object.fromEntries(CREATURES.map((c) => [c.id, c]));
export const STARTERS = ['fenix', 'kraken', 'basilisco'];
