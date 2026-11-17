// Reglas de progresión: niveles, rango, evolución, recompensas, contratos,
// recompensa diaria y Pase Arcano.
import { CREATURE, CREATURES, FORMS, ELEMENTS } from '../data/creatures.js';
import { PASS_TIERS, PASS_XP_PER_TIER, DAILY, TINT } from '../data/shop.js';
import { ISLANDS } from '../data/islands.js';
import { state, save, today, addInk } from '../core/save.js';

export const MAX_LEVEL = 50;
export const MAX_RANK = 60;

export const xpToNext = (l) => Math.round(30 + l * 12 + l * l * 1.2);
export const rankXpFor = (r) => Math.round(80 * r + 6 * r * r); // XP para pasar de r a r+1
export const trainCost = (l) => Math.round(40 + l * l * 3.5);

export function rankInfo() {
  let r = 1;
  let xp = state.rankXp;
  while (r < MAX_RANK && xp >= rankXpFor(r)) {
    xp -= rankXpFor(r);
    r++;
  }
  return { rank: r, xp, need: rankXpFor(r) };
}

export const RANK_TITLES = [
  { min: 1, es: 'Aprendiz', en: 'Apprentice' },
  { min: 10, es: 'Iniciado', en: 'Initiate' },
  { min: 25, es: 'Sellador', en: 'Sealer' },
  { min: 40, es: 'Maestro de Sellos', en: 'Seal Master' },
  { min: 55, es: 'Archisellador', en: 'Archsealer' },
];
export function rankTitle(r) {
  let res = RANK_TITLES[0];
  for (const t of RANK_TITLES) if (r >= t.min) res = t;
  return res;
}
export function teamSize() {
  return rankInfo().rank >= 10 ? 3 : 2;
}

// Estadísticas de combate de una criatura a un nivel y forma dados.
export function computeStats(id, level, form, boss = false) {
  const c = CREATURE[id];
  const [pow, def, agi, mag] = c.stats;
  const lf = 1 + (level - 1) * 0.085;
  const fm = FORMS[form].mult * (boss ? 1.25 : 1);
  return {
    hp: Math.round((150 + def * 2.1) * lf * fm * (boss ? 6 : 1)),
    atk: pow * lf * fm,
    mag: mag * lf * fm,
    def: def * lf * fm,
    spd: 5.6 + agi * 0.022,
    cdr: 1 - agi * 0.0015,
  };
}

export function owned(id) {
  return state.creatures[id];
}

export function markSeen(id) {
  if (!state.bestiary[id].seen) {
    state.bestiary[id].seen = true;
    save();
  }
}

export function formsSealed() {
  let n = 0;
  for (const c of CREATURES) n += state.bestiary[c.id].forms.filter(Boolean).length;
  return n;
}

// Añade la criatura sellada (o convierte el duplicado en recursos).
export function addCreature(id, level, perfect) {
  const c = CREATURE[id];
  const res = { isNew: false, essence: 0, fragments: 0, bondUp: false };
  markSeen(id);
  if (!state.creatures[id]) {
    state.creatures[id] = { form: 0, level: Math.max(1, level), xp: 0, bond: perfect ? 2 : 1, bondXp: 0, tint: '' };
    state.bestiary[id].forms[0] = true;
    res.isNew = true;
    if (state.team.length < teamSize()) state.team.push(id);
  } else {
    const own = state.creatures[id];
    own.bondXp += perfect ? 40 : 20;
    res.bondUp = addBondCheck(own);
  }
  const frag = perfect ? 4 : 3;
  state.fragments[c.el] = (state.fragments[c.el] || 0) + frag;
  res.fragments = frag;
  save();
  return res;
}

export function addBondCheck(own) {
  let up = false;
  while (own.bond < 5 && own.bondXp >= 60 * own.bond) {
    own.bondXp -= 60 * own.bond;
    own.bond++;
    up = true;
  }
  return up;
}

export function giveXp(id, amount) {
  const own = state.creatures[id];
  if (!own) return 0;
  let ups = 0;
  if (own.level >= MAX_LEVEL) return 0;
  own.xp += Math.round(amount);
  while (own.level < MAX_LEVEL && own.xp >= xpToNext(own.level)) {
    own.xp -= xpToNext(own.level);
    own.level++;
    ups++;
  }
  if (own.level >= MAX_LEVEL) own.xp = 0;
  return ups;
}

export function train(id) {
  const own = state.creatures[id];
  if (!own || own.level >= MAX_LEVEL) return false;
  const cost = trainCost(own.level);
  if (state.essence < cost) return false;
  state.essence -= cost;
  own.level++;
  own.xp = 0;
  save();
  return true;
}

// Requisitos de evolución: Cría→Adulta nivel 20 y 30 fragmentos;
// Adulta→Primordial nivel 40 y vencer al jefe de su isla.
export function evolveInfo(id) {
  const own = state.creatures[id];
  const c = CREATURE[id];
  if (!own || own.form >= 2) return null;
  if (own.form === 0) {
    const frags = state.fragments[c.el] || 0;
    return { to: 1, level: 20, frags: 30, haveFrags: frags, boss: false, ok: own.level >= 20 && frags >= 30 };
  }
  const bossDone = state.islands.cleared.includes(c.island);
  return { to: 2, level: 40, frags: 0, boss: true, bossDone, ok: own.level >= 40 && bossDone };
}

export function evolve(id) {
  const info = evolveInfo(id);
  if (!info || !info.ok) return false;
  const own = state.creatures[id];
  const c = CREATURE[id];
  if (info.frags) state.fragments[c.el] -= info.frags;
  own.form = info.to;
  state.bestiary[id].forms[info.to] = true;
  checkTitles();
  save();
  return true;
}

export function checkTitles() {
  for (const c of CREATURES) {
    const key = 'title_' + c.id;
    if (state.bestiary[c.id].forms.every(Boolean) && !state.titles.includes(key)) state.titles.push(key);
  }
}

// Hitos del Bestiario: cristales gratis cada 6 formas.
export function bestiaryMilestones() {
  const n = formsSealed();
  const got = [];
  for (const m of [3, 6, 12, 18, 24, 30, 36]) {
    const key = 'b' + m;
    if (n >= m && !state.milestones.includes(key)) {
      state.milestones.push(key);
      const crystals = m === 36 ? 200 : m >= 18 ? 40 : 20;
      state.crystals += crystals;
      got.push({ forms: m, crystals });
    }
  }
  if (got.length) save();
  return got;
}

export function islandLevel(idx, k = Math.random()) {
  const [a, b] = ISLANDS[idx].levels;
  return Math.round(a + (b - a) * k);
}

export function grant(g, mult = 1) {
  if (!g) return;
  if (g.essence) state.essence += Math.round(g.essence * mult);
  if (g.crystals) state.crystals += g.crystals;
  if (g.ink) addInk(g.ink);
  if (g.fragments) {
    // fragmentos del elemento de tu líder
    const lead = state.team[0] && CREATURE[state.team[0]];
    const el = lead ? lead.el : 'luz';
    state.fragments[el] = (state.fragments[el] || 0) + g.fragments;
  }
  if (g.tint && !state.cosmetics.tints.includes(g.tint)) state.cosmetics.tints.push(g.tint);
  if (g.seal && !state.cosmetics.seals.includes(g.seal)) state.cosmetics.seals.push(g.seal);
  if (g.effect && !state.cosmetics.effects.includes(g.effect)) state.cosmetics.effects.push(g.effect);
  save();
}

// --- Recompensa diaria (ciclo de 7 días) --------------------------------
export function dailyStatus() {
  const can = state.daily.last !== today();
  return { can, day: state.daily.day % 7, reward: DAILY[state.daily.day % 7] };
}

export function claimDaily() {
  const s = dailyStatus();
  if (!s.can) return null;
  grant(s.reward);
  state.daily.day = (state.daily.day + 1) % 7;
  state.daily.last = today();
  save();
  return s.reward;
}

// --- Contratos diarios --------------------------------------------------
const CONTRACT_TYPES = [
  { type: 'seal', goal: 2, es: 'Sella {n} criaturas', en: 'Seal {n} creatures', essence: 400 },
  { type: 'perfect', goal: 1, es: 'Logra {n} trazo perfecto', en: 'Land {n} perfect trace', essence: 450 },
  { type: 'kills', goal: 12, es: 'Derrota a {n} criaturas', en: 'Defeat {n} creatures', essence: 350 },
  { type: 'ult', goal: 3, es: 'Usa la Definitiva {n} veces', en: 'Use your Ultimate {n} times', essence: 350 },
  { type: 'runs', goal: 2, es: 'Completa {n} expediciones', en: 'Complete {n} expeditions', essence: 500 },
  { type: 'advantage', goal: 8, es: 'Golpea {n} veces con ventaja de dominio', en: 'Land {n} hits with domain advantage', essence: 300 },
];

export function ensureContracts() {
  if (state.contracts.date === today() && state.contracts.list.length) return state.contracts.list;
  const pool = [...CONTRACT_TYPES].sort(() => Math.random() - 0.5).slice(0, 3);
  state.contracts = {
    date: today(),
    list: pool.map((c) => ({ type: c.type, goal: c.goal, progress: 0, essence: c.essence, passXp: 60, claimed: false })),
  };
  save();
  return state.contracts.list;
}

export function contractText(c, lang) {
  const def = CONTRACT_TYPES.find((d) => d.type === c.type);
  return (def ? def[lang] : c.type).replace('{n}', c.goal);
}

export function progressContract(type, n = 1) {
  ensureContracts();
  const done = [];
  for (const c of state.contracts.list) {
    if (c.type !== type || c.claimed) continue;
    const before = c.progress;
    c.progress = Math.min(c.goal, c.progress + n);
    if (before < c.goal && c.progress >= c.goal) done.push(c);
  }
  save();
  return done;
}

export function claimContract(i) {
  const c = state.contracts.list[i];
  if (!c || c.claimed || c.progress < c.goal) return false;
  c.claimed = true;
  state.essence += c.essence;
  addPassXp(c.passXp);
  save();
  return true;
}

// --- Pase Arcano --------------------------------------------------------
export function passTier() {
  return Math.min(PASS_TIERS.length, Math.floor(state.pass.xp / PASS_XP_PER_TIER));
}
export function addPassXp(n) {
  state.pass.xp = Math.min(PASS_TIERS.length * PASS_XP_PER_TIER, state.pass.xp + n);
  save();
}
export function claimPass(n, track) {
  const tier = PASS_TIERS[n - 1];
  if (!tier || passTier() < n) return false;
  const list = track === 'prem' ? state.pass.prem : state.pass.free;
  if (list.includes(n)) return false;
  if (track === 'prem' && !state.pass.premium) return false;
  list.push(n);
  grant(track === 'prem' ? tier.prem : tier.free);
  return true;
}

export function tintColor(tintId, base) {
  if (!tintId) return base;
  const t = TINT[tintId];
  return t ? t.color : base;
}

export function elementName(el, lang) {
  return ELEMENTS[el][lang];
}
