// Catálogo de la tienda. Reglas fijas del diseño:
// - Lo que se compra con dinero real solo es apariencia o comodidad.
// - Ninguna compra tiene resultado aleatorio (sin cajas de botín).
// - El precio se ve antes de comprar y toda compra pide confirmación.

const TINT_NAMES = {
  '#ffd76a': { es: 'Oro Astral', en: 'Astral Gold' },
  '#ff3d3d': { es: 'Carmesí', en: 'Crimson' },
  '#4fb4ff': { es: 'Azur', en: 'Azure' },
  '#b06bff': { es: 'Violeta del Vacío', en: 'Void Violet' },
  '#3dff88': { es: 'Esmeralda', en: 'Emerald' },
  '#2ff2d6': { es: 'Turquesa', en: 'Turquoise' },
  '#ff7a2e': { es: 'Ascua', en: 'Ember' },
  '#9fefff': { es: 'Escarcha', en: 'Frost' },
  '#ffb23e': { es: 'Ámbar', en: 'Amber' },
  '#ff4fd2': { es: 'Magenta', en: 'Magenta' },
  '#b4ff4a': { es: 'Lima', en: 'Lime' },
  '#7f8cff': { es: 'Índigo', en: 'Indigo' },
  '#ffffff': { es: 'Nieve', en: 'Snow' },
};

const BASIC = {
  hidra: ['#ff3d3d', '#2ff2d6', '#ff4fd2'],
  fenix: ['#ffd76a', '#ff3d3d', '#4fb4ff'],
  kraken: ['#4fb4ff', '#b06bff', '#3dff88'],
  grifo: ['#9fefff', '#ffd76a', '#b06bff'],
  cerbero: ['#ff7a2e', '#b06bff', '#3dff88'],
  basilisco: ['#b4ff4a', '#2ff2d6', '#ff4fd2'],
  wyvern: ['#4fb4ff', '#7f8cff', '#ffffff'],
  golem: ['#ff3d3d', '#2ff2d6', '#b06bff'],
  leviatan: ['#b06bff', '#2ff2d6', '#ffd76a'],
  aracna: ['#b06bff', '#ff3d3d', '#3dff88'],
  ciervo: ['#9fefff', '#ff4fd2', '#3dff88'],
  tortuga: ['#2ff2d6', '#ffb23e', '#ff4fd2'],
};

// Tintes de la temporada 1 «Eclipse» (renders/tintes del paquete de arte).
const SEASON = [
  { id: 'hidra_eclipse', creature: 'hidra', color: '#ffcf5a', img: 'hidra_eclipsedorado', price: 400,
    name: { es: 'Eclipse Dorado', en: 'Golden Eclipse' } },
  { id: 'cerbero_llamaazul', creature: 'cerbero', color: '#3d9bff', img: 'cerbero_llamaazul', price: 250,
    name: { es: 'Llama Azul', en: 'Blue Flame' } },
  { id: 'fenix_jade', creature: 'fenix', color: '#5dffb0', img: 'fenix_jade', price: 250,
    name: { es: 'Fénix de Jade', en: 'Jade Phoenix' } },
  { id: 'wyvern_aurora', creature: 'wyvern', color: 'aurora', img: 'wyvern_aurora', price: 250,
    name: { es: 'Aurora', en: 'Aurora' } },
];

export const TINTS = [];
for (const [creature, colors] of Object.entries(BASIC)) {
  colors.forEach((color) => {
    TINTS.push({ id: `${creature}_${color.slice(1)}`, creature, color, price: 150, name: TINT_NAMES[color] });
  });
  TINTS.push({ id: `${creature}_prisma`, creature, color: 'prisma', price: 600, premium: true,
    name: { es: 'Prisma', en: 'Prism' } });
}
for (const s of SEASON) TINTS.push({ ...s, season: true });
export const TINT = Object.fromEntries(TINTS.map((t) => [t.id, t]));

export const SEALS = [
  { id: 'propio', price: 0, name: { es: 'Sello propio', en: 'Own seal' }, desc: { es: 'El círculo original de cada criatura.', en: 'Each creature’s original circle.' } },
  { id: 'hexagrama', price: 150, name: { es: 'Hexagrama', en: 'Hexagram' }, desc: { es: 'Seis puntas para todas tus criaturas.', en: 'Six points for all your creatures.' } },
  { id: 'heptagrama', price: 150, name: { es: 'Heptagrama', en: 'Heptagram' }, desc: { es: 'Siete puntas para todas tus criaturas.', en: 'Seven points for all your creatures.' } },
  { id: 'pentagrama', price: 150, name: { es: 'Pentagrama', en: 'Pentagram' }, desc: { es: 'Cinco puntas para todas tus criaturas.', en: 'Five points for all your creatures.' } },
  { id: 'corona', price: 300, name: { es: 'Corona Solar', en: 'Solar Crown' }, desc: { es: 'Rayos que giran como un sol.', en: 'Rays that spin like a sun.' } },
  { id: 'constelacion', price: 300, name: { es: 'Constelación', en: 'Constellation' }, desc: { es: 'Estrellas unidas por hilos de luz.', en: 'Stars joined by threads of light.' } },
  { id: 'eclipse', price: 450, season: true, name: { es: 'Sello del Eclipse', en: 'Eclipse Seal' }, desc: { es: 'Exclusivo de la temporada Eclipse.', en: 'Eclipse season exclusive.' } },
];
export const SEAL = Object.fromEntries(SEALS.map((s) => [s.id, s]));

export const EFFECTS = [
  { id: 'anillo', price: 0, name: { es: 'Anillo rúnico', en: 'Rune ring' } },
  { id: 'estrellas', price: 200, name: { es: 'Lluvia de estrellas', en: 'Starfall' } },
  { id: 'pilar', price: 200, name: { es: 'Pilar de luz', en: 'Pillar of light' } },
  { id: 'espiral', price: 250, name: { es: 'Espiral arcana', en: 'Arcane spiral' } },
];
export const EFFECT = Object.fromEntries(EFFECTS.map((e) => [e.id, e]));

// Productos con dinero real (precios en USD; Stripe los cobra en la moneda que elijas).
export const PRODUCTS = [
  { sku: 'fundador', usd: 2.99, once: true, best: true,
    name: { es: 'Pack del Fundador', en: 'Founder Pack' },
    desc: { es: '600 Cristales + tinte Prisma para tu inicial + Corona Solar + Lluvia de estrellas', en: '600 Crystals + Prism tint for your starter + Solar Crown + Starfall' },
    grant: { crystals: 600, starterPrism: true, seals: ['corona'], effects: ['estrellas'] } },
  { sku: 'cristales_120', usd: 0.99, name: { es: '120 Cristales', en: '120 Crystals' }, grant: { crystals: 120 } },
  { sku: 'cristales_650', usd: 4.99, tag: 'popular', name: { es: '650 Cristales', en: '650 Crystals' }, grant: { crystals: 650 } },
  { sku: 'cristales_1400', usd: 9.99, tag: 'bonus', name: { es: '1400 Cristales', en: '1400 Crystals' }, grant: { crystals: 1400 } },
  { sku: 'cristales_3000', usd: 19.99, tag: 'value', name: { es: '3000 Cristales', en: '3000 Crystals' }, grant: { crystals: 3000 } },
  { sku: 'pase_premium', usd: 4.99, once: true,
    name: { es: 'Pase Arcano Premium', en: 'Arcane Pass Premium' },
    desc: { es: 'Desbloquea la pista premium de la temporada Eclipse', en: 'Unlocks the Eclipse season premium track' },
    grant: { passPremium: true } },
  { sku: 'sin_anuncios', usd: 3.99, once: true, standaloneOnly: true,
    name: { es: 'Sin anuncios', en: 'No ads' },
    desc: { es: 'Quita los anuncios entre partidas. Los anuncios opcionales con premio siguen disponibles.', en: 'Removes ads between runs. Optional reward ads stay available.' },
    grant: { noAds: true } },
];
export const PRODUCT = Object.fromEntries(PRODUCTS.map((p) => [p.sku, p]));
export const PASS_PREMIUM_CRYSTALS = 800;

// Pase Arcano: 30 niveles, 1 nivel cada 100 XP de pase.
export const PASS_TIERS = Array.from({ length: 30 }, (_, i) => {
  const n = i + 1;
  const free = n % 5 === 0 ? { crystals: 15 } : n % 3 === 0 ? { ink: 2 } : { essence: 150 + n * 20 };
  let prem;
  if (n === 30) prem = { seal: 'eclipse' };
  else if (n === 25) prem = { effect: 'espiral' };
  else if (n === 20) prem = { tint: 'hidra_eclipse' };
  else if (n === 15) prem = { effect: 'pilar' };
  else if (n === 10) prem = { tint: 'wyvern_aurora' };
  else if (n === 5) prem = { seal: 'constelacion' };
  else if (n % 2 === 0) prem = { crystals: 40 };
  else prem = { essence: 400 + n * 30, ink: 1 };
  return { n, free, prem };
});
export const PASS_XP_PER_TIER = 100;

export const DAILY = [
  { essence: 200 },
  { ink: 2 },
  { essence: 300, fragments: 5 },
  { essence: 400, ink: 3 },
  { crystals: 10 },
  { essence: 600 },
  { crystals: 30, ink: 5 },
];
