// Estado persistente del jugador. Se guarda en localStorage y, si la
// plataforma lo ofrece (CrazyGames), también en la nube de la cuenta.
import { CREATURES } from '../data/creatures.js';
import { platform } from './platform.js';

const KEY = 'sellos_arcanos_save_v1';
const INK_MAX = 10;
const INK_MS = 10 * 60 * 1000;

function today() {
  const d = new Date();
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
}

export function freshState() {
  const bestiary = {};
  for (const c of CREATURES) bestiary[c.id] = { seen: false, forms: [false, false, false] };
  return {
    v: 1,
    created: Date.now(),
    name: '',
    starterChosen: false,
    tutorialDone: false,
    rankXp: 0,
    essence: 300,
    crystals: 0,
    ink: INK_MAX,
    inkTs: Date.now(),
    fragments: {}, // elemento -> cantidad
    creatures: {}, // id -> {form, level, xp, bond, bondXp, tint}
    team: [],
    bestiary,
    islands: { unlocked: 0, cleared: [] },
    cosmetics: { tints: [], seals: ['propio'], effects: ['anillo'], seal: 'propio', effect: 'anillo' },
    daily: { day: 0, last: '' },
    contracts: { date: '', list: [] },
    pass: { season: 1, xp: 0, premium: false, free: [], prem: [] },
    ads: { date: '', ink: 0, chest: false },
    purchases: { sessions: [], founder: false, noAds: false },
    settings: { lang: '', music: 0.6, sfx: 0.8, quality: 'auto', shake: true },
    stats: { seals: 0, perfect: 0, kills: 0, runs: 0, bosses: 0, ults: 0, playMs: 0 },
    titles: [],
    milestones: [],
  };
}

export const state = freshState();
let saveTimer = 0;

function merge(target, src) {
  for (const k in src) {
    if (src[k] && typeof src[k] === 'object' && !Array.isArray(src[k]) && target[k] && typeof target[k] === 'object' && !Array.isArray(target[k])) {
      merge(target[k], src[k]);
    } else {
      target[k] = src[k];
    }
  }
}

export async function loadState() {
  let raw = null;
  try {
    raw = await platform.storageGet(KEY);
  } catch (e) { /* sin nube */ }
  if (!raw) {
    try { raw = localStorage.getItem(KEY); } catch (e) { raw = null; }
  }
  if (raw) {
    try {
      const data = JSON.parse(raw);
      merge(state, data);
    } catch (e) {
      console.warn('save corrupto, empezando de nuevo', e);
    }
  }
  tickInk();
  return state;
}

export function saveNow() {
  clearTimeout(saveTimer);
  const raw = JSON.stringify(state);
  try { localStorage.setItem(KEY, raw); } catch (e) { /* modo privado */ }
  platform.storageSet(KEY, raw).catch(() => {});
}

export function save() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(saveNow, 400);
}

export function resetState() {
  const fresh = freshState();
  for (const k of Object.keys(state)) delete state[k];
  Object.assign(state, fresh);
  saveNow();
}

// --- Tinta Rúnica: 1 cada 10 minutos, hasta 10 -------------------------
export function tickInk() {
  const now = Date.now();
  if (state.ink >= INK_MAX) {
    state.inkTs = now;
    return;
  }
  const gained = Math.floor((now - state.inkTs) / INK_MS);
  if (gained > 0) {
    state.ink = Math.min(INK_MAX, state.ink + gained);
    state.inkTs += gained * INK_MS;
    if (state.ink >= INK_MAX) state.inkTs = now;
    save();
  }
}

export function inkNextMs() {
  if (state.ink >= INK_MAX) return 0;
  return Math.max(0, INK_MS - (Date.now() - state.inkTs));
}

export function addInk(n) {
  state.ink = Math.min(INK_MAX + 20, state.ink + n);
  save();
}

export function spendInk() {
  tickInk();
  if (state.ink <= 0) return false;
  if (state.ink >= INK_MAX) state.inkTs = Date.now();
  state.ink -= 1;
  save();
  return true;
}

export { INK_MAX, today };
