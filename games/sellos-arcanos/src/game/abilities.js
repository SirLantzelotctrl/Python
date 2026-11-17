// Ejecutores genéricos de habilidades. Cada habilidad de data/abilities.js
// declara un tipo (melee, projectile, cone, aoe, dash, heal, shield, buff,
// zone, strike, mines, revive) y sus parámetros.
import * as THREE from 'three';
import { sfx } from '../core/audio.js';
import { ARENA_R } from '../engine/arena.js';

const v1 = new THREE.Vector3();
const UP = new THREE.Vector3(0, 1, 0);

export function flatDir(from, to) {
  const d = new THREE.Vector3(to.x - from.x, 0, to.z - from.z);
  const l = d.length();
  return l > 1e-4 ? d.divideScalar(l) : new THREE.Vector3(Math.sin(0), 0, 1);
}

function inCone(src, dir, tgt, range, arcDeg) {
  v1.set(tgt.pos.x - src.pos.x, 0, tgt.pos.z - src.pos.z);
  const d = v1.length();
  if (d > range + tgt.radius) return false;
  if (d < tgt.radius + 0.5) return true;
  v1.divideScalar(d);
  const ang = Math.acos(THREE.MathUtils.clamp(v1.dot(dir), -1, 1));
  return ang <= THREE.MathUtils.degToRad(arcDeg / 2) + Math.atan2(tgt.radius, d);
}

function distXZ(a, b) {
  return Math.hypot(a.x - b.x, a.z - b.z);
}

// --- lanzar una habilidad -------------------------------------------------
// aim: { dir: Vector3 (XZ unitario), pos: Vector3, target: Fighter|null }
export function cast(cb, f, ab, aim) {
  const color = f.visual.glowColor;
  f.facing = Math.atan2(aim.dir.x, aim.dir.z);
  f.visual.attack();
  f.castLock = ab.type === 'cone' && ab.dur ? ab.dur : 0.22;
  const foes = cb.foesOf(f);

  switch (ab.type) {
    case 'melee': {
      sfx.whoosh();
      // acercarse un poco al objetivo si está a tiro de salto
      if (aim.target) {
        const d = distXZ(f.pos, aim.target.pos) - aim.target.radius - f.radius * 0.5;
        if (d > ab.range * 0.7 && d < ab.range + 5) f.dash = { dir: aim.dir.clone(), left: Math.min(5, d - ab.range * 0.5), speed: 30, ab: null, hit: new Set() };
      }
      for (let h = 0; h < (ab.hits || 1); h++) {
        cb.later(h * 0.13, () => {
          if (!f.alive) return;
          f.visual.attack();
          const front = f.pos.clone().addScaledVector(aim.dir, ab.range * 0.55);
          cb.fx.particles.burst(front, color, 8, 5, 0.35, 0.5, { dy: 0.8 });
          for (const t of cb.foesOf(f)) if (inCone(f, aim.dir, t, ab.range + f.radius * 0.5, ab.arc)) cb.damage(f, t, ab.power, ab.stat, ab);
        });
      }
      break;
    }
    case 'projectile': {
      const n = ab.count || 1;
      const spread = THREE.MathUtils.degToRad(ab.spread || 0);
      sfx.shoot();
      for (let i = 0; i < n; i++) {
        const a = n === 1 ? 0 : -spread / 2 + (spread * i) / (n - 1);
        const dir = aim.dir.clone().applyAxisAngle(UP, a);
        cb.spawnProjectile(f, ab, dir, color);
      }
      break;
    }
    case 'cone': {
      sfx.breath();
      const ticks = ab.ticks || 1;
      const dur = ab.dur || 0;
      const dir = aim.dir.clone();
      for (let i = 0; i < ticks; i++) {
        cb.later((dur * i) / ticks, () => {
          if (!f.alive || (f.stunned && dur)) return;
          const d = f.side === 'player' && cb.player === f ? cb.aimDir(f, dir) : dir;
          f.facing = Math.atan2(d.x, d.z);
          coneParticles(cb, f, d, ab, color);
          for (const t of cb.foesOf(f)) {
            if (inCone(f, d, t, ab.range, ab.arc)) {
              cb.damage(f, t, ab.power, ab.stat, ab);
              if (ab.knock) cb.knockback(t, d, ab.knock);
              if (i === ticks - 1 && ab.endStatus) t.addStatus(ab.endStatus, f);
            }
          }
        });
      }
      break;
    }
    case 'aoe': {
      const center = ab.range ? clampTo(aim.pos, f.pos, ab.range) : f.pos.clone();
      const follow = !ab.range;
      const doIt = () => {
        if (!f.alive) return;
        const c = follow ? f.pos.clone() : center;
        sfx.boom();
        cb.fx.shockwave(c, color, ab.radius);
        cb.fx.particles.ring(c, color, ab.radius * 0.6, 36, 0.7, 0.6, ab.radius * 0.8);
        cb.shake(0.25);
        const ticks = ab.ticks || 1;
        for (let i = 0; i < ticks; i++) {
          cb.later(((ab.dur || 0) * i) / ticks, () => {
            const cc = follow ? f.pos : c;
            if (ticks > 1) cb.fx.particles.ring(cc, color, ab.radius * 0.8, 24, 0.5, 0.5, -ab.radius);
            for (const t of cb.foesOf(f)) {
              if (distXZ(t.pos, cc) <= ab.radius + t.radius) {
                if (ab.power) cb.damage(f, t, ab.power, ab.stat, ab);
                else if (ab.status) t.addStatus(ab.status, f);
                if (ab.pull) t.pullTo = { pos: cc, speed: ab.pull, t: Math.max(0.4, ab.dur || 0.5) };
              }
            }
            if (ab.selfHeal) cb.healFx(f, f.maxHp * ab.selfHeal);
          });
        }
        if (ab.final) {
          cb.later((ab.dur || 0) + 0.05, () => {
            const cc = follow ? f.pos : c;
            cb.fx.shockwave(cc, color, ab.radius * 0.6);
            sfx.boom();
            cb.shake(0.4);
            for (const t of cb.foesOf(f)) if (distXZ(t.pos, cc) <= ab.radius * 0.6 + t.radius) cb.damage(f, t, ab.final, ab.stat, ab);
          });
        }
      };
      if (ab.delay) {
        cb.fx.telegraph({ pos: follow ? f.pos : center, radius: ab.radius, color: f.def.color, time: ab.delay });
        cb.later(ab.delay, doIt);
      } else doIt();
      break;
    }
    case 'dash': {
      sfx.whoosh();
      const dist = aim.target ? Math.min(ab.range, distXZ(f.pos, aim.target.pos) + 1.5) : ab.range;
      f.dash = { dir: aim.dir.clone(), left: dist, speed: ab.speed, ab, hit: new Set(), color };
      f.iframes = Math.max(f.iframes, 0.2);
      break;
    }
    case 'heal': {
      sfx.heal();
      const targets = ab.team ? cb.teamOf(f) : [f];
      for (const t of targets) {
        if (ab.cleanse) t.cleanse();
        const amount = t.maxHp * ab.pct;
        if (!ab.dur) cb.healFx(t, amount);
        else {
          const steps = Math.ceil(ab.dur / 0.5);
          for (let i = 1; i <= steps; i++) cb.later(i * 0.5, () => cb.healFx(t, amount / steps, i === 1));
        }
      }
      cb.fx.particles.pillar(f.pos, color, 6, 40, 1, 0.6);
      if (ab.burst) {
        cb.fx.shockwave(f.pos, color, ab.burst.radius);
        for (const t of foes) if (distXZ(t.pos, f.pos) <= ab.burst.radius + t.radius) cb.damage(f, t, ab.burst.power, ab.burst.stat, ab);
      }
      break;
    }
    case 'shield': {
      sfx.shield();
      f.addShield(f.maxHp * ab.pct, ab.dur, ab.reflect || 0);
      cb.fx.shockwave(f.pos, color, f.radius * 2.5, 0.5);
      break;
    }
    case 'buff': {
      sfx.buff();
      f.addBuff(ab);
      cb.fx.particles.pillar(f.pos, color, 8, 50, 0.8, 0.7);
      cb.fx.shockwave(f.pos, color, 4);
      break;
    }
    case 'zone': {
      const center = ab.range ? clampTo(aim.pos, f.pos, ab.range) : f.pos.clone();
      cb.spawnZone(f, ab, center, color);
      sfx.boom();
      break;
    }
    case 'strike': {
      sfx.zap();
      const picks = [];
      const marked = foes.filter((t) => t.has('mark'));
      const pool = marked.length ? marked : foes;
      for (let i = 0; i < ab.count; i++) {
        let p;
        if (ab.area || !pool.length) {
          const base = pool.length ? pool[i % pool.length].pos : f.pos;
          p = new THREE.Vector3(base.x + (Math.random() - 0.5) * 9, 0, base.z + (Math.random() - 0.5) * 9);
        } else {
          const t = pool[i % pool.length];
          p = t.pos.clone().add(new THREE.Vector3((Math.random() - 0.5) * 1.2, 0, (Math.random() - 0.5) * 1.2));
        }
        clampArena(p, 1);
        picks.push(p);
      }
      picks.forEach((p, i) => {
        cb.later(i * (ab.interval || 0.15), () => {
          cb.fx.telegraph({ pos: p, radius: ab.radius, color: f.def.color, time: ab.delay });
          cb.later(ab.delay, () => {
            if (f.id === 'tortuga') cb.crystalTower(p, color);
            else cb.fx.bolt(p.clone().add(new THREE.Vector3(0, 14, 0)), p, color, 0.25);
            cb.fx.beam(p, color, 10, 0.3, 0.3);
            cb.fx.particles.burst(p, color, 16, 7, 0.6, 0.6);
            sfx.zap();
            cb.shake(0.15);
            for (const t of cb.foesOf(f)) if (distXZ(t.pos, p) <= ab.radius + t.radius) cb.damage(f, t, ab.power, ab.stat, ab);
          });
        });
      });
      break;
    }
    case 'mines': {
      sfx.summon(f.def.el);
      for (let i = 0; i < ab.count; i++) {
        const a = f.facing + (i - (ab.count - 1) / 2) * 0.9;
        const p = f.pos.clone().add(new THREE.Vector3(Math.sin(a) * 3, 0, Math.cos(a) * 3));
        clampArena(p, 1);
        cb.spawnMine(f, ab, p, color);
      }
      break;
    }
    case 'revive': {
      sfx.ult();
      if (f.side === 'player') cb.reviveTeam(ab.pct);
      cb.healFx(f, f.maxHp * ab.pct);
      cb.fx.particles.pillar(f.pos, color, 12, 90, 1.4, 0.9);
      cb.fx.shockwave(f.pos, color, ab.radius);
      for (const t of foes) if (distXZ(t.pos, f.pos) <= ab.radius + t.radius) {
        cb.damage(f, t, ab.power, ab.stat, ab);
        t.addStatus({ t: 'burn', dur: 3, val: 0.5 }, f, 10);
      }
      break;
    }
    default:
      break;
  }

  if (ab.also) {
    const a = ab.also;
    if (a.type === 'shield') {
      const targets = ab.key === 'f' || ab.team ? cb.teamOf(f) : [f];
      for (const t of targets) t.addShield(t.maxHp * a.pct, a.dur, a.reflect || 0);
      sfx.shield();
    }
    if (a.type === 'buff') f.addBuff(a);
  }
}

function coneParticles(cb, f, dir, ab, color) {
  const arc = THREE.MathUtils.degToRad(ab.arc);
  for (let i = 0; i < 14; i++) {
    const a = (Math.random() - 0.5) * arc;
    const d = dir.clone().applyAxisAngle(UP, a);
    const s = ab.range * (1.6 + Math.random());
    cb.fx.particles.spawn(f.pos.x + d.x * f.radius, 1 + Math.random() * 0.6, f.pos.z + d.z * f.radius, d.x * s, Math.random() * 1.5, d.z * s, color, 0.45, 0.9, 0, 1.2);
  }
}

export function clampTo(p, from, range) {
  const d = new THREE.Vector3(p.x - from.x, 0, p.z - from.z);
  if (d.length() > range) d.setLength(range);
  return clampArena(new THREE.Vector3(from.x + d.x, 0, from.z + d.z), 1);
}

export function clampArena(p, margin = 0) {
  const r = Math.hypot(p.x, p.z);
  const max = ARENA_R - margin;
  if (r > max) { p.x *= max / r; p.z *= max / r; }
  return p;
}
