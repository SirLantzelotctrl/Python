// Genera src/shared/GameData.lua a partir de los datos del juego (fuente única
// compartida con la versión web en ../sellos-arcanos/src/data).
// Las distancias se convierten a studs de Roblox (1 unidad web = STUD studs).
import { writeFileSync } from 'node:fs';
import { CREATURES, ELEMENTS, DOMAINS, ROLES } from '../../sellos-arcanos/src/data/creatures.js';
import { ABILITIES } from '../../sellos-arcanos/src/data/abilities.js';
import { ISLANDS, TIPS } from '../../sellos-arcanos/src/data/islands.js';
import { TINTS, SEALS, EFFECTS, PASS_TIERS, PASS_XP_PER_TIER, DAILY } from '../../sellos-arcanos/src/data/shop.js';

const STUD = 2.4;
const SCALE_KEYS = new Set(['range', 'radius', 'speed', 'width', 'knock', 'pull', 'explode']);

const ident = /^[A-Za-z_][A-Za-z0-9_]*$/;
const LUA_KEYWORDS = new Set(['and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while', 'continue']);

function lua(v, ind = '') {
  const next = ind + '\t';
  if (v === null || v === undefined) return 'nil';
  if (typeof v === 'number') return Number.isInteger(v) ? String(v) : String(Math.round(v * 1000) / 1000);
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  if (typeof v === 'string') return JSON.stringify(v);
  if (Array.isArray(v)) {
    if (!v.length) return '{}';
    const simple = v.every((x) => typeof x !== 'object');
    if (simple) return '{ ' + v.map((x) => lua(x)).join(', ') + ' }';
    return '{\n' + v.map((x) => next + lua(x, next) + ',').join('\n') + '\n' + ind + '}';
  }
  const keys = Object.keys(v).filter((k) => v[k] !== undefined);
  if (!keys.length) return '{}';
  return '{\n' + keys.map((k) => {
    const key = ident.test(k) && !LUA_KEYWORDS.has(k) ? k : `[${JSON.stringify(k)}]`;
    return `${next}${key} = ${lua(v[k], next)},`;
  }).join('\n') + '\n' + ind + '}';
}

const hex = (n) => '#' + n.toString(16).padStart(6, '0');
const FILES = { hidra: 'Hidra', fenix: 'Fenix', kraken: 'Kraken', grifo: 'Grifo', cerbero: 'Cerbero', basilisco: 'Basilisco', wyvern: 'Wyvern', golem: 'Golem', leviatan: 'Leviatan', aracna: 'Aracna', ciervo: 'Ciervo', tortuga: 'Tortuga' };

function scaleAbility(a) {
  const out = {};
  for (const [k, v] of Object.entries(a)) {
    if (SCALE_KEYS.has(k) && typeof v === 'number') out[k] = v * STUD;
    else if (v && typeof v === 'object' && !Array.isArray(v) && (k === 'also' || k === 'burst')) out[k] = scaleAbility(v);
    else out[k] = v;
  }
  return out;
}

const creatures = CREATURES.map((c) => ({
  id: c.id, num: c.num, file: FILES[c.id], el: c.el, role: c.role, color: c.color,
  body: hex(c.body), bone: hex(c.bone),
  stats: { pow: c.stats[0], def: c.stats[1], agi: c.stats[2], mag: c.stats[3] },
  circle: c.circle, halo: !!c.halo, island: c.island + 1, nodes: c.nodes,
  name: c.name, sub: c.sub, lore: c.lore,
  abilities: ABILITIES[c.id].map(scaleAbility),
}));

const islands = ISLANDS.map((s, i) => ({ index: i + 1, id: s.id, name: s.name, desc: s.desc, levels: s.levels, boss: s.boss, pool: s.pool, props: s.props }));

const out = `-- GENERADO por tools/gen_shared.mjs a partir de los datos del juego. No editar a mano:
-- cambia ../sellos-arcanos/src/data y ejecuta \`npm run gen\`.
-- Distancias en studs (STUD = ${STUD} studs por unidad del diseño).

local GameData = {}

GameData.STUD = ${STUD}

GameData.Elements = ${lua(ELEMENTS)}

GameData.Domains = ${lua(DOMAINS)}

GameData.Roles = ${lua(ROLES)}

GameData.Creatures = ${lua(creatures)}

GameData.Islands = ${lua(islands)}

GameData.Tips = ${lua(TIPS)}

GameData.Tints = ${lua(TINTS)}

GameData.Seals = ${lua(SEALS)}

GameData.Effects = ${lua(EFFECTS)}

GameData.PassTiers = ${lua(PASS_TIERS)}

GameData.PassXpPerTier = ${PASS_XP_PER_TIER}

GameData.Daily = ${lua(DAILY)}

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
`;
writeFileSync(new URL('../src/shared/GameData.lua', import.meta.url), out);
console.log('GameData.lua', out.length, 'bytes');
