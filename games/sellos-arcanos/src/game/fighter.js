// Un combatiente en la arena: estadísticas, vida, Energía arcana, barra de
// Sello, enfriamientos y estados alterados.
import * as THREE from 'three';
import { CREATURE } from '../data/creatures.js';
import { ABILITIES } from '../data/abilities.js';
import { computeStats } from './progression.js';
import { CreatureVisual } from '../engine/creatureMesh.js';

const CC = new Set(['stun', 'freeze', 'petrify']);
const NEG = new Set(['burn', 'poison', 'slow', 'stun', 'freeze', 'petrify', 'root', 'blind', 'mark']);
const TINTS = {
  freeze: new THREE.Color('#9fefff'), petrify: new THREE.Color('#8a8a8a'), poison: new THREE.Color('#3dff88'),
  burn: new THREE.Color('#ff7a2e'), stun: new THREE.Color('#fff2a0'), root: new THREE.Color('#ff4fd2'),
};

let uid = 0;

export class Fighter {
  constructor(id, { side, level = 1, form = 0, boss = false, glow, seal, owned } = {}) {
    this.uid = ++uid;
    this.id = id;
    this.def = CREATURE[id];
    this.side = side;
    this.level = level;
    this.form = form;
    this.boss = boss;
    this.owned = owned || null;
    this.stats = computeStats(id, level, form, boss);
    this.maxHp = this.stats.hp;
    this.hp = this.maxHp;
    this.energy = 100;
    this.seal = 0;
    this.cds = { q: 0, e: 0, r: 0 };
    this.statuses = [];
    this.shield = 0;
    this.shieldT = 0;
    this.reflect = 0;
    this.buffs = [];
    this.pos = new THREE.Vector3();
    this.vel = new THREE.Vector3();
    this.facing = 0;
    this.alive = true;
    this.fainted = false;
    this.iframes = 0;
    this.dodgeCd = 0;
    this.castLock = 0;
    this.channel = null;
    this.dash = null;
    this.windup = null;
    this.sealable = false;
    this.invuln = false;
    this.moving = 0;
    this.knock = new THREE.Vector3();
    this.pullTo = null;
    this.aiT = Math.random();
    this.aiGcd = 1 + Math.random();
    this.strafe = Math.random() < 0.5 ? 1 : -1;
    this.target = null;
    this.usedRevive = false;
    this.abilities = ABILITIES[id];
    this.visual = new CreatureVisual(id, { glow, form, boss, seal });
    this.radius = this.visual.radius;
    this.color = new THREE.Color(this.def.color);
  }

  ability(key) {
    return this.abilities.find((a) => a.key === key);
  }

  // Las Crías tienen Q, E y la Definitiva; la forma Adulta añade R.
  hasAbility(key) {
    if (key === 'r') return this.form >= 1 || this.boss;
    return true;
  }

  has(t) { return this.statuses.some((s) => s.t === t); }
  get stunned() { return this.statuses.some((s) => CC.has(s.t)); }
  get rooted() { return this.stunned || this.has('root'); }

  get speedMul() {
    let m = 1;
    for (const s of this.statuses) if (s.t === 'slow') m = Math.min(m, 1 - s.val);
    for (const b of this.buffs) if (b.spd) m *= 1 + b.spd;
    return m;
  }
  get atkMul() {
    let m = 1;
    for (const b of this.buffs) if (b.atk) m *= 1 + b.atk;
    if (this.has('blind')) m *= 0.5;
    return m;
  }
  get cdrMul() {
    let m = this.stats.cdr;
    for (const b of this.buffs) if (b.cdr) m *= 1 - b.cdr;
    return m;
  }
  get lifesteal() {
    let l = 0;
    for (const b of this.buffs) if (b.lifesteal) l += b.lifesteal;
    return l;
  }

  addStatus(st, src, baseDmg = 0) {
    let dur = st.dur;
    if (this.boss && (CC.has(st.t) || st.t === 'root')) dur *= 0.35;
    if (this.anchor) return;
    const existing = this.statuses.find((s) => s.t === st.t);
    const entry = { t: st.t, dur, val: st.val || 0, src, tickT: 0.5 };
    if (st.t === 'burn' || st.t === 'poison') entry.dps = (baseDmg * (st.val || 0.5) * 2) / Math.max(1, st.dur);
    if (existing) Object.assign(existing, entry);
    else this.statuses.push(entry);
  }

  cleanse() {
    this.statuses = this.statuses.filter((s) => !NEG.has(s.t));
  }

  addShield(amount, dur, reflect = 0) {
    this.shield = Math.max(this.shield, amount);
    this.shieldT = Math.max(this.shieldT, dur);
    this.reflect = Math.max(this.reflect, reflect);
  }

  addBuff(b) {
    this.buffs.push({ ...b, t: b.dur });
  }

  heal(amount) {
    if (!this.alive) return 0;
    const before = this.hp;
    this.hp = Math.min(this.maxHp, this.hp + amount);
    return this.hp - before;
  }

  // Avanza enfriamientos y estados. Devuelve el daño por tick de estados (para el combate).
  tick(dt, onDot) {
    for (const k of ['q', 'e', 'r']) this.cds[k] = Math.max(0, this.cds[k] - dt);
    this.energy = Math.min(100, this.energy + dt * 10);
    this.iframes = Math.max(0, this.iframes - dt);
    this.dodgeCd = Math.max(0, this.dodgeCd - dt);
    this.castLock = Math.max(0, this.castLock - dt);
    if (this.shieldT > 0) {
      this.shieldT -= dt;
      if (this.shieldT <= 0) { this.shield = 0; this.reflect = 0; }
    }
    for (let i = this.buffs.length - 1; i >= 0; i--) {
      this.buffs[i].t -= dt;
      if (this.buffs[i].t <= 0) this.buffs.splice(i, 1);
    }
    let tint = null;
    for (let i = this.statuses.length - 1; i >= 0; i--) {
      const s = this.statuses[i];
      s.dur -= dt;
      if (s.dps) {
        s.tickT -= dt;
        if (s.tickT <= 0) {
          s.tickT += 0.5;
          onDot?.(this, s.dps * 0.5, s);
        }
      }
      if (TINTS[s.t] && !tint) tint = TINTS[s.t];
      if (s.dur <= 0) this.statuses.splice(i, 1);
    }
    this.visual.statusTint = tint;
  }

  dispose() {
    this.visual.dispose();
  }
}
