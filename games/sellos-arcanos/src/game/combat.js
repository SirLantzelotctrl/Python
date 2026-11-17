// Combate en tiempo real: una criatura invocada a la vez (equipo de 3,
// cambio con 1·2·3), enemigos con IA y avisos en el suelo, jefes con tres
// fases y cuatro anclas rúnicas, sellado al bajar del 25 % de vida.
import * as THREE from 'three';
import { Fighter } from './fighter.js';
import { cast, flatDir, clampArena } from './abilities.js';
import { FX, DamageText } from '../engine/fx.js';
import { buildArena, setupLights, ARENA_R } from '../engine/arena.js';
import { input, consume } from '../engine/input.js';
import { domainMult, CREATURE } from '../data/creatures.js';
import { ISLANDS } from '../data/islands.js';
import { sfx, playMusic } from '../core/audio.js';
import { state } from '../core/save.js';
import { tintColor, islandLevel, markSeen, progressContract } from './progression.js';
import { EFFECT } from '../data/shop.js';
import { t as tr } from '../core/i18n.js';

const tmp = new THREE.Vector3();

export class Combat {
  constructor(renderer, dmgLayer, events) {
    this.renderer = renderer;
    this.events = events; // {hud, banner, sealPrompt, choice, defeat, end, sealStart}
    this.dmgLayer = dmgLayer;
  }

  // config: { islandIdx, team: [ids], waves: n, tutorial }
  start(config) {
    this.config = config;
    this.island = ISLANDS[config.islandIdx];
    this.islandIdx = config.islandIdx;
    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(45, innerWidth / innerHeight, 0.1, 400);
    this.lights = setupLights(this.scene);
    const bossDef = CREATURE[this.island.boss];
    this.arena = buildArena(this.scene, { ...this.island, sealDesign: bossDef.circle }, bossDef.color);
    this.fx = new FX(this.scene);
    this.dmg = new DamageText(this.dmgLayer, this.camera);
    this.renderer.setScene(this.scene, this.camera);
    this.time = 0;
    this.timers = [];
    this.projectiles = [];
    this.zones = [];
    this.mines = [];
    this.stars = [];
    this.enemies = [];
    this.paused = false;
    this.over = false;
    this.shakeAmt = 0;
    this.camPos = new THREE.Vector3(0, 16, 16);
    this.camLook = new THREE.Vector3();
    this.switchCd = 0;
    this.waveIdx = -1;
    this.waveCount = config.waves || 4;
    this.waveSizes = config.tutorial ? [1, 1, 2] : [1, 2, 2, 3, 3].slice(0, this.waveCount);
    this.waveCount = this.waveSizes.length;
    this.phase = 0;
    this.boss = null;
    this.anchors = [];
    this.bossStage = false;
    this.rewards = { essence: 0, xp: 0, kills: 0, sealed: [], fragments: {}, crystals: 0, bossSealed: false, perfect: 0, waves: 0, stars: 0 };
    this.fought = new Set();
    this.waitingNext = 0;
    this.revivesUsed = 0;

    // equipo del jugador
    this.team = config.team.map((id) => {
      const own = state.creatures[id];
      const f = new Fighter(id, { side: 'player', level: own.level, form: own.form, glow: tintColor(own.tint, CREATURE[id].color), seal: this.sealDesign(id), owned: own });
      return f;
    });
    this.activeIdx = 0;
    this.player = this.team[0];
    this.player.pos.set(0, 0, 6);
    this.player.facing = Math.PI;
    this.summon(this.player, true);
    this.fought.add(this.player.id);
    playMusic('combat');
    this.nextWave();
  }

  sealDesign(id) {
    const s = state.cosmetics.seal;
    return s && s !== 'propio' ? s : CREATURE[id].circle;
  }

  // --- utilidades para las habilidades ------------------------------------
  later(t, fn) { this.timers.push({ t: this.time + t, fn }); }
  foesOf(f) {
    if (f.side === 'player') return [...this.enemies, ...this.anchors].filter((e) => e.alive && !e.sealing);
    return this.player && this.player.alive ? [this.player] : [];
  }
  teamOf(f) {
    if (f.side === 'player') return this.team.filter((t) => !t.fainted);
    return [f];
  }
  shake(a) { if (state.settings.shake) this.shakeAmt = Math.max(this.shakeAmt, a); }

  aimDir(f, fallback) {
    const tgt = this.currentTarget();
    if (tgt) return flatDir(f.pos, tgt.pos);
    const m = input.move;
    if (Math.hypot(m.x, m.y) > 0.2) return new THREE.Vector3(m.x, 0, m.y).normalize();
    return fallback || new THREE.Vector3(Math.sin(f.facing), 0, Math.cos(f.facing));
  }

  knockback(t, dir, amount) {
    if (t.boss || t.anchor) amount *= 0.2;
    t.knock.addScaledVector(dir, amount * 4);
  }

  healFx(t, amount, show = true) {
    const h = t.heal(amount);
    if (h > 0 && show && t.visual.group.parent) {
      this.dmg.show(tmp.copy(t.pos).setY(t.visual.height + 0.6), '+' + Math.round(h), 'heal');
      this.fx.particles.burst(t.pos, '#7dffb0', 8, 3, 0.8, 0.5, { lift: 2, grav: 0 });
    }
  }

  reviveTeam(pct) {
    for (const t of this.team) {
      if (t.fainted) {
        t.fainted = false;
        t.alive = true;
        t.hp = t.maxHp * pct;
        t.statuses = [];
      }
    }
  }

  // --- daño ----------------------------------------------------------------
  damage(src, tgt, power, stat, ab, opts = {}) {
    if (!tgt.alive || this.over) return 0;
    if (tgt.iframes > 0 && !opts.dot) {
      this.dmg.show(tmp.copy(tgt.pos).setY(tgt.visual.height + 0.4), tr('dodged'), 'miss');
      return 0;
    }
    if (tgt.invuln) {
      if (!opts.dot && Math.random() < 0.3) this.dmg.show(tmp.copy(tgt.pos).setY(tgt.visual.height + 0.4), tr('immune'), 'miss');
      return 0;
    }
    const statVal = stat === 'm' ? src.stats.mag : src.stats.atk;
    const defBase = tgt.def.stats[1];
    const elem = opts.dot ? 1 : domainMult(src.def.el, tgt.def.el);
    const crit = !opts.dot && Math.random() < 0.05 + src.def.stats[2] * 0.001;
    let dmg = opts.raw ?? power * statVal * 0.06 * (170 / (100 + defBase));
    if (!opts.raw) dmg *= elem * (crit ? 1.5 : 1) * src.atkMul * (0.92 + Math.random() * 0.16);
    if (tgt.has('mark')) dmg *= 1.15;
    if (tgt.anchor) dmg = Math.max(dmg, tgt.maxHp * 0.04);
    if (this.config.tutorial && tgt.side === 'player') dmg *= 0.6;
    dmg = Math.max(1, dmg);
    // escudo
    if (tgt.shield > 0) {
      const absorbed = Math.min(tgt.shield, dmg);
      tgt.shield -= absorbed;
      dmg -= absorbed;
      if (tgt.reflect && !opts.dot && src.alive && src !== tgt) {
        const r = absorbed * tgt.reflect;
        if (r > 1) this.later(0.05, () => this.damage(tgt, src, 0, 'm', null, { raw: r, dot: true }));
      }
      if (dmg <= 0) {
        this.dmg.show(tmp.copy(tgt.pos).setY(tgt.visual.height + 0.4), Math.round(absorbed), 'shield');
        return 0;
      }
    }
    // los jefes no caen: hay que sellarlos
    if (tgt.boss && !tgt.sealed) dmg = Math.min(dmg, tgt.hp - 1);
    tgt.hp -= dmg;
    if (dmg > 0) {
      const ls = src.lifesteal;
      if (ls && !opts.dot) src.heal(dmg * ls);
      if (!opts.dot) {
        tgt.visual.hit(src.def.color);
        sfx.hit(crit || power > 7);
        this.fx.particles.burst(tgt.pos, src.visual.glowColor, crit ? 14 : 7, 5, 0.45, 0.55, { dy: tgt.visual.height * 0.5 });
      }
      const cls = opts.dot ? 'dot' : crit ? 'crit' : elem > 1 ? 'adv' : tgt.side === 'player' ? 'taken' : '';
      this.dmg.show(tmp.copy(tgt.pos).setY(tgt.visual.height + 0.4), Math.round(dmg) + (crit ? '!' : ''), cls);
      // barra de Sello: se llena al golpear (y un poco al recibir)
      if (!opts.dot) {
        if (src.side === 'player') src.seal = Math.min(100, src.seal + (ab && ab.key === 'f' ? 0 : 2.6));
        if (tgt.side === 'player') tgt.seal = Math.min(100, tgt.seal + (dmg / tgt.maxHp) * 30);
        if (tgt.boss && src.side === 'player') this.shake(0.05);
      }
      if (src.side === 'player' && elem > 1 && !opts.dot) progressContract('advantage');
    }
    if (ab && ab.status && !opts.dot) tgt.addStatus(ab.status, src, dmg);
    if (tgt.side === 'enemy' && !tgt.boss && !tgt.anchor && tgt.hp > 0 && tgt.hp / tgt.maxHp < 0.25 && !tgt.sealable) {
      tgt.sealable = true;
      tgt.visual.circle?.setIntensity(1.7);
      if (tgt.visual.circle) tgt.visual.circle.speed = 3;
      this.events.banner(tr('sealOpen'), 'seal', 1.6);
      sfx.sealNode(4);
    }
    if (tgt.boss && tgt.phaseReady3 && tgt.hp / tgt.maxHp < 0.25 && !tgt.sealable && !tgt.invuln) {
      tgt.sealable = true;
      tgt.visual.circle?.setIntensity(1.8);
      this.events.banner(tr('bossSealOpen'), 'seal', 2);
    }
    if (tgt.hp <= 0) this.onDown(tgt, src);
    return dmg;
  }

  onDown(f, src) {
    if (!f.alive) return;
    f.alive = false;
    f.hp = 0;
    const p = f.pos.clone();
    this.fx.particles.burst(p, f.visual.glowColor, 40, 8, 1, 0.8, { dy: 1 });
    this.fx.shockwave(p, f.def.color, 3);
    if (f.anchor) {
      sfx.break();
      this.scene.remove(f.mesh);
      this.scene.remove(f.beamLine);
      this.anchors = this.anchors.filter((a) => a !== f);
      if (!this.anchors.length && this.boss) {
        this.boss.invuln = false;
        this.boss.phaseReady3 = true;
        this.boss.addStatus({ t: 'stun', dur: 9 }, f);
        this.events.banner(tr('anchorsBroken'), 'gold', 2.2);
        this.shake(0.6);
      }
      return;
    }
    if (f.side === 'enemy') {
      sfx.faint();
      this.removeFighter(f);
      const lvl = f.level;
      this.rewards.kills++;
      this.rewards.xp += 10 + lvl * 6;
      this.rewards.essence += 15 + lvl * 4;
      state.stats.kills++;
      progressContract('kills');
    } else {
      sfx.faint();
      f.fainted = true;
      this.scene.remove(f.visual.group);
      const next = this.team.findIndex((t) => !t.fainted);
      if (next < 0) {
        this.later(0.8, () => this.events.defeat());
        this.paused = false;
        this.defeated = true;
      } else {
        this.later(0.7, () => this.switchTo(next, true));
      }
    }
  }

  removeFighter(f) {
    const v = f.visual;
    const t0 = this.time;
    const shrink = () => {
      const k = 1 - (this.time - t0) / 0.5;
      if (k <= 0) {
        this.scene.remove(v.group);
        f.dispose();
        return;
      }
      v.group.scale.setScalar(k);
      v.setOpacity(k);
      this.later(0.016, shrink);
    };
    shrink();
    this.enemies = this.enemies.filter((e) => e !== f);
  }

  // --- invocación y cambio ------------------------------------------------
  summon(f, first = false) {
    this.scene.add(f.visual.group);
    f.visual.group.position.copy(f.pos);
    f.iframes = 0.6;
    const effect = f.side === 'player' ? state.cosmetics.effect || 'anillo' : 'anillo';
    const c = f.visual.glowColor;
    if (effect === 'estrellas') {
      for (let i = 0; i < 24; i++) this.fx.particles.spawn(f.pos.x + (Math.random() - 0.5) * 4, 8 + Math.random() * 4, f.pos.z + (Math.random() - 0.5) * 4, 0, -14, 0, c, 0.6, 0.8, 0, 0);
    } else if (effect === 'pilar') {
      this.fx.beam(f.pos, c, 16, 1.4, 0.8);
    } else if (effect === 'espiral') {
      for (let i = 0; i < 60; i++) {
        const a = i * 0.4;
        this.fx.particles.spawn(f.pos.x + Math.cos(a) * 2, i * 0.08, f.pos.z + Math.sin(a) * 2, -Math.sin(a) * 4, 2, Math.cos(a) * 4, c, 0.9, 0.6, 0, 0.5);
      }
    }
    this.fx.particles.pillar(f.pos, c, 9, 40, 0.8, 0.6);
    this.fx.shockwave(f.pos, f.def.color, 4);
    if (!first || f.side === 'player') sfx.summon(f.def.el);
    markSeen(f.id);
  }

  switchTo(idx, forced = false) {
    if (idx === this.activeIdx && !forced) return;
    const next = this.team[idx];
    if (!next || next.fainted) { sfx.error(); return; }
    if (!forced && this.switchCd > 0) { sfx.error(); return; }
    const prev = this.player;
    if (prev && prev.alive && !prev.fainted) {
      this.fx.particles.burst(prev.pos, prev.visual.glowColor, 20, 4, 0.5, 0.6);
      this.scene.remove(prev.visual.group);
      prev.channel = null;
      prev.dash = null;
    }
    next.pos.copy(prev ? prev.pos : new THREE.Vector3());
    next.facing = prev ? prev.facing : 0;
    next.alive = true;
    this.player = next;
    this.activeIdx = idx;
    this.switchCd = 1.5;
    this.fought.add(next.id);
    this.summon(next);
  }

  // --- oleadas ---------------------------------------------------------
  nextWave() {
    this.waveIdx++;
    if (this.waveIdx >= this.waveCount) {
      this.events.choice();
      return;
    }
    const n = this.waveSizes[this.waveIdx];
    const cleared = state.islands.cleared.includes(this.islandIdx);
    this.events.banner(tr('wave', { a: this.waveIdx + 1, b: this.waveCount }), '', 1.8);
    for (let i = 0; i < n; i++) {
      this.timers.push({ t: this.time + 0.6 + i * 0.45, wave: true, fn: () => {
        const pool = this.island.pool;
        const id = pool[Math.floor(Math.random() * pool.length)];
        const k = cleared ? Math.random() : Math.min(1, (this.waveIdx / this.waveCount) * 0.7 + Math.random() * 0.3);
        const lvl = this.config.tutorial ? 1 : islandLevel(this.islandIdx, k);
        const e = new Fighter(id, { side: 'enemy', level: lvl, form: 0 });
        const a = Math.random() * Math.PI * 2;
        e.pos.set(this.player.pos.x + Math.cos(a) * 9, 0, this.player.pos.z + Math.sin(a) * 9);
        clampArena(e.pos, 2);
        e.facing = Math.atan2(this.player.pos.x - e.pos.x, this.player.pos.z - e.pos.z);
        e.aiGcd = 1.2 + Math.random();
        this.enemies.push(e);
        this.summon(e);
      } });
    }
  }

  // Lluvia de Estrellas: estrellas que caen y dan Esencia al recogerlas
  starShower() {
    this.events.banner(tr('starShower'), 'gold', 2);
    this.starT = 9;
    for (let i = 0; i < 14; i++) {
      this.later(i * 0.45, () => {
        const p = new THREE.Vector3((Math.random() - 0.5) * 2 * (ARENA_R - 3), 14, (Math.random() - 0.5) * 2 * (ARENA_R - 3));
        clampArena(p, 2);
        const mesh = this.fx.orb('#ffd76a', 0.32);
        mesh.position.copy(p);
        this.stars.push({ mesh, pos: p, landed: false, life: 8 });
      });
    }
  }

  startBoss() {
    this.bossStage = true;
    const id = this.island.boss;
    const cleared = state.islands.cleared.includes(this.islandIdx);
    // nivel adaptado al equipo la primera vez; más duro al repetir
    const [lo, hi] = this.island.levels;
    const avg = this.team.reduce((a, f) => a + f.level, 0) / this.team.length;
    const lvl = cleared ? hi + 2 : Math.round(Math.max(lo, Math.min(hi, avg + 1)));
    const b = new Fighter(id, { side: 'enemy', level: lvl, form: 2, boss: true });
    b.pos.set(0, 0, -7);
    b.facing = 0;
    b.aiGcd = 2.5;
    this.boss = b;
    this.enemies.push(b);
    this.summon(b);
    this.fx.beam(b.pos, b.def.color, 26, 1.1, 1.1);
    this.shake(0.8);
    sfx.roar();
    playMusic('boss');
    this.events.banner(b.def.name, 'boss', 3, true);
    this.phase = 1;
  }

  bossPhase(n) {
    const b = this.boss;
    this.phase = n;
    sfx.phase();
    this.shake(0.7);
    this.events.banner(tr('phase', { n }), 'boss', 2);
    if (n === 2) {
      // cambia el patrón de su círculo y sus ataques
      const designs = ['hexagrama', 'heptagrama', 'pentagrama'].filter((d) => d !== b.def.circle);
      b.visual.setSeal(designs[0]);
      if (b.visual.circle) b.visual.circle.speed = 2.5;
      for (let i = 0; i < 2; i++) {
        this.later(1 + i * 0.6, () => {
          const pool = this.island.pool.filter((p) => p !== b.id);
          const id = pool[i % pool.length] || b.id;
          const e = new Fighter(id, { side: 'enemy', level: Math.max(1, b.level - 4), form: 0 });
          const a = Math.random() * Math.PI * 2;
          e.pos.set(Math.cos(a) * 10, 0, Math.sin(a) * 10);
          this.enemies.push(e);
          this.summon(e);
        });
      }
    }
    if (n === 3) {
      b.invuln = true;
      b.visual.setSeal(b.def.circle);
      if (b.visual.circle) b.visual.circle.speed = 4;
      this.events.banner(tr('anchors'), 'boss', 2.6);
      for (let i = 0; i < 4; i++) {
        const a = Math.PI / 4 + (i * Math.PI) / 2;
        this.spawnAnchor(new THREE.Vector3(Math.cos(a) * 12, 0, Math.sin(a) * 12));
      }
    }
  }

  spawnAnchor(pos) {
    const b = this.boss;
    const color = new THREE.Color(b.def.color);
    const g = new THREE.OctahedronGeometry(1, 0);
    g.scale(0.9, 2.6, 0.9);
    const mat = new THREE.MeshBasicMaterial({ color: color.clone().multiplyScalar(1.8) });
    const mesh = new THREE.Mesh(g, mat);
    mesh.position.set(pos.x, 2.8, pos.z);
    this.scene.add(mesh);
    const lg = new THREE.BufferGeometry().setFromPoints([mesh.position.clone(), b.pos.clone().setY(2)]);
    const beamLine = new THREE.Line(lg, new THREE.LineBasicMaterial({ color: color.clone().multiplyScalar(1.2), transparent: true, opacity: 0.6 }));
    this.scene.add(beamLine);
    const hp = Math.round(b.maxHp * 0.045);
    const a = {
      anchor: true, alive: true, side: 'enemy', id: b.id, def: b.def, pos: pos.clone(), radius: 1.2, hp, maxHp: hp,
      mesh, beamLine, statuses: [], shield: 0, iframes: 0, invuln: false, knock: new THREE.Vector3(),
      visual: { height: 5, hit: () => { mat.color.setRGB(3, 3, 3); this.later(0.08, () => mat.color.copy(color).multiplyScalar(1.8)); }, glowColor: color },
      has: () => false, addStatus: () => {}, heal: () => 0, atkMul: 1,
    };
    this.anchors.push(a);
    this.fx.beam(pos, b.def.color, 12, 0.5, 0.8);
  }

  // --- proyectiles, zonas y minas -------------------------------------------
  spawnProjectile(f, ab, dir, color) {
    const mesh = this.fx.orb(color, ab.radius * 0.35);
    const pos = f.pos.clone().addScaledVector(dir, f.radius * 0.8).setY(Math.min(2.2, f.visual.height * 0.5));
    mesh.position.copy(pos);
    this.projectiles.push({ f, ab, dir, pos, mesh, left: ab.range, hit: new Set(), color, side: f.side });
  }

  spawnZone(f, ab, center, color) {
    const ring = this.fx.telegraph({ pos: center, radius: ab.radius, color: f.def.color, time: ab.dur });
    this.fx.particles.ring(center, color, ab.radius, 40, 0.8, 0.6, 1);
    this.zones.push({ f, ab, pos: center, t: ab.dur, tickT: 0, inside: new Map(), color, ring });
  }

  spawnMine(f, ab, pos, color) {
    const mesh = this.fx.orb(color, 0.35);
    mesh.position.copy(pos).setY(0.4);
    this.mines.push({ f, ab, pos, mesh, arm: 0.6, life: 12, color });
  }

  crystalTower(p, color) {
    const g = new THREE.ConeGeometry(0.8, 4, 5);
    g.translate(0, 2, 0);
    const m = new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(1.5), transparent: true });
    const mesh = new THREE.Mesh(g, m);
    mesh.position.set(p.x, 0, p.z);
    this.fx.add(mesh, 2.5, (it, k) => { m.opacity = Math.min(1, k * 3); mesh.scale.y = Math.min(1, (1 - k) * 8); });
  }

  // --- turno del jugador ----------------------------------------------------
  currentTarget() {
    const foes = this.foesOf(this.player);
    if (!foes.length) return null;
    if (this.lockTarget && foes.includes(this.lockTarget)) return this.lockTarget;
    let best = null;
    let bd = Infinity;
    for (const e of foes) {
      const d = Math.hypot(e.pos.x - this.player.pos.x, e.pos.z - this.player.pos.z);
      if (d < bd) { bd = d; best = e; }
    }
    return best;
  }

  nearestSealable() {
    let best = null;
    let bd = Infinity;
    for (const e of this.enemies) {
      if (!e.alive || !e.sealable || e.sealing) continue;
      const d = Math.hypot(e.pos.x - this.player.pos.x, e.pos.z - this.player.pos.z);
      if (d < bd) { bd = d; best = e; }
    }
    return best;
  }

  tryCast(key) {
    const p = this.player;
    if (!p || !p.alive || p.stunned || p.castLock > 0 || p.dash || this.defeated) return false;
    const ab = p.ability(key);
    if (!ab || !p.hasAbility(key)) return false;
    if (key === 'f') {
      if (p.seal < 100) { sfx.error(); return false; }
      p.seal = 0;
      state.stats.ults++;
      progressContract('ult');
      sfx.ult();
      this.events.banner(ab.name, 'ult', 1.4, true);
      this.shake(0.4);
    } else {
      if (p.cds[key] > 0 || p.energy < (ab.cost || 0)) { sfx.error(); return false; }
      p.energy -= ab.cost || 0;
      p.cds[key] = ab.cd * p.cdrMul;
    }
    const target = this.currentTarget();
    const dir = this.aimDir(p);
    cast(this, p, ab, { dir, pos: target ? target.pos.clone() : p.pos.clone().addScaledVector(dir, 6), target });
    return true;
  }

  playerUpdate(dt) {
    const p = this.player;
    if (!p || !p.alive) return;
    // acciones
    if (consume('q')) this.tryCast('q');
    if (consume('e')) this.tryCast('e');
    if (consume('r')) this.tryCast('r');
    if (consume('f')) this.tryCast('f');
    for (let i = 0; i < 3; i++) if (consume('sw' + (i + 1))) this.switchTo(i);
    if (consume('target')) {
      const foes = this.foesOf(p);
      if (foes.length) {
        const i = foes.indexOf(this.lockTarget);
        this.lockTarget = foes[(i + 1) % foes.length];
      }
    }
    if (consume('seal')) {
      const s = this.nearestSealable();
      if (s) this.events.sealStart(s);
    }
    // esquivar
    if (consume('dodge') && p.dodgeCd <= 0 && !p.rooted) {
      let dir;
      if (input.swipeDir) {
        dir = new THREE.Vector3(input.swipeDir.x, 0, input.swipeDir.y).normalize();
        input.swipeDir = null;
      } else if (Math.hypot(input.move.x, input.move.y) > 0.1) dir = new THREE.Vector3(input.move.x, 0, input.move.y).normalize();
      else dir = new THREE.Vector3(-Math.sin(p.facing), 0, -Math.cos(p.facing));
      p.dash = { dir, left: 5.5, speed: 26, ab: null, hit: new Set(), dodge: true };
      p.iframes = 0.4;
      p.dodgeCd = 1.0;
      p.channel = null;
      sfx.dodge();
      this.fx.particles.burst(p.pos, p.visual.glowColor, 12, 3, 0.4, 0.5);
    }
    // movimiento
    if (!p.dash && !p.rooted) {
      const m = input.move;
      const mag = Math.hypot(m.x, m.y);
      const slow = p.castLock > 0 ? 0.35 : 1;
      if (mag > 0.05) {
        const spd = p.stats.spd * p.speedMul * slow;
        p.pos.x += m.x * spd * dt;
        p.pos.z += m.y * spd * dt;
        if (p.castLock <= 0) p.facing = Math.atan2(m.x, m.y);
      }
      p.moving = Math.min(1, mag);
    } else p.moving = 0;
  }

  // --- IA de los enemigos ---------------------------------------------------
  aiUpdate(e, dt) {
    const p = this.player;
    if (!p || !p.alive || e.stunned || this.defeated) { e.moving = 0; return; }
    if (e.windup) {
      e.windup.t -= dt;
      e.moving = 0;
      e.facing = Math.atan2(e.windup.dir.x, e.windup.dir.z);
      if (e.windup.t <= 0) {
        const w = e.windup;
        e.windup = null;
        cast(this, e, w.ab, { dir: w.dir, pos: w.pos, target: p });
      }
      return;
    }
    const toP = flatDir(e.pos, p.pos);
    const dist = Math.hypot(p.pos.x - e.pos.x, p.pos.z - e.pos.z);
    const meleeish = e.abilities[0].type === 'melee' || e.abilities[0].type === 'dash';
    const want = (meleeish ? 2.2 : 7.5) + e.radius + p.radius;
    e.aiGcd -= dt;
    // decidir habilidad
    if (e.aiGcd <= 0 && e.castLock <= 0 && !e.dash) {
      const keys = e.boss ? ['f', 'r', 'e', 'q'] : e.form >= 1 ? ['r', 'e', 'q'] : ['e', 'q'];
      for (const k of keys) {
        const ab = e.ability(k);
        if (!ab) continue;
        if (k === 'f' && e.seal < 100) continue;
        if (k !== 'f' && e.cds[k] > 0) continue;
        const range = ab.range || 6;
        if (['heal', 'shield', 'buff'].includes(ab.type)) {
          if (ab.type === 'heal' && e.hp / e.maxHp > 0.6) continue;
        } else if (dist > range + p.radius + 1) continue;
        // usar
        if (k === 'f') e.seal = 0;
        else e.cds[k] = ab.cd * (e.boss ? (this.phase >= 2 ? 1.3 : 1.6) : 2.2);
        const pos = p.pos.clone();
        const telegraphed = ['cone', 'aoe', 'strike', 'dash', 'zone'].includes(ab.type) || (k === 'f');
        const wind = e.boss ? (this.phase >= 3 ? 0.5 : 0.65) : 0.75;
        if (telegraphed && ab.type !== 'strike') {
          e.windup = { ab, dir: toP.clone(), pos, t: wind };
          if (ab.type === 'cone') this.fx.telegraph({ pos: e.pos, radius: ab.range, cone: ab.arc, dir: toP, time: wind, color: '#ff3355' });
          else if (ab.type === 'dash') this.fx.telegraph({ pos: e.pos, dir: toP, length: ab.range, width: ab.width * 1.6, time: wind, color: '#ff3355' });
          else if (ab.type === 'aoe') this.fx.telegraph({ pos: ab.range ? pos : e.pos, radius: ab.radius, time: wind, color: '#ff3355' });
          else if (ab.type === 'zone') this.fx.telegraph({ pos, radius: ab.radius, time: wind, color: '#ff3355' });
          else if (ab.type === 'revive') this.fx.telegraph({ pos: e.pos, radius: ab.radius, time: wind, color: '#ff3355' });
          sfx.warn();
        } else if (ab.type === 'melee' || ab.type === 'projectile') {
          e.windup = { ab, dir: toP.clone(), pos, t: 0.28 };
        } else {
          cast(this, e, ab, { dir: toP, pos, target: p });
        }
        e.aiGcd = e.boss ? (this.phase >= 2 ? 0.9 : 1.2) : 1.4 + Math.random() * 1.2;
        if (e.boss) e.seal = Math.min(100, e.seal + 12);
        return;
      }
    }
    // moverse
    if (e.rooted || e.dash) { e.moving = 0; return; }
    const spd = e.stats.spd * e.speedMul * (e.boss ? 0.7 : 0.62);
    let mx = 0;
    let mz = 0;
    if (dist > want + 0.5) { mx = toP.x; mz = toP.z; }
    else if (dist < want - 1.5) { mx = -toP.x; mz = -toP.z; }
    e.aiT += dt;
    if (!e.boss) {
      // rodear al jugador
      mx += -toP.z * e.strafe * 0.5;
      mz += toP.x * e.strafe * 0.5;
      if (Math.random() < dt * 0.3) e.strafe *= -1;
    }
    const l = Math.hypot(mx, mz);
    if (l > 0.01) {
      e.pos.x += (mx / l) * spd * dt;
      e.pos.z += (mz / l) * spd * dt;
      e.moving = 1;
    } else e.moving = 0;
    e.facing = Math.atan2(toP.x, toP.z);
  }

  // --- bucle principal ------------------------------------------------------
  update(dt) {
    if (this.paused || !this.scene) return;
    dt = Math.min(dt, 0.05);
    this.time += dt;
    this.switchCd = Math.max(0, this.switchCd - dt);
    // temporizadores
    if (this.timers.length) {
      const due = this.timers.filter((t) => t.t <= this.time);
      this.timers = this.timers.filter((t) => t.t > this.time);
      for (const t of due) t.fn();
    }
    if (!this.over) this.playerUpdate(dt);
    const all = [...this.team.filter((f) => f === this.player && f.alive), ...this.enemies];
    for (const f of all) {
      f.tick(dt, (ff, amount, s) => this.damage(s.src && s.src.alive !== undefined ? s.src : ff, ff, 0, 'm', null, { raw: amount, dot: true }));
      if (f.side === 'enemy' && f.alive && !this.over) this.aiUpdate(f, dt);
      // embestidas y esquivas
      if (f.dash) {
        const step = Math.min(f.dash.left, f.dash.speed * dt);
        f.pos.addScaledVector(f.dash.dir, step);
        f.dash.left -= step;
        f.facing = Math.atan2(f.dash.dir.x, f.dash.dir.z);
        if (f.dash.ab) {
          for (const t of this.foesOf(f)) {
            if (f.dash.hit.has(t)) continue;
            if (Math.hypot(t.pos.x - f.pos.x, t.pos.z - f.pos.z) < t.radius + f.dash.ab.width) {
              f.dash.hit.add(t);
              this.damage(f, t, f.dash.ab.power, f.dash.ab.stat, f.dash.ab);
              if (f.dash.ab.knock) this.knockback(t, f.dash.dir, f.dash.ab.knock);
            }
          }
          this.fx.particles.spawn(f.pos.x, 0.8, f.pos.z, 0, 1, 0, f.dash.color || f.visual.glowColor, 0.4, 0.8, 0, 0);
        }
        if (f.dash.left <= 0.01) f.dash = null;
      }
      // empujones y atracciones
      if (f.knock.lengthSq() > 0.01) {
        f.pos.addScaledVector(f.knock, dt);
        f.knock.multiplyScalar(Math.max(0, 1 - dt * 6));
      }
      if (f.pullTo) {
        const d = flatDir(f.pos, f.pullTo.pos);
        const dist = Math.hypot(f.pos.x - f.pullTo.pos.x, f.pos.z - f.pullTo.pos.z);
        if (dist > 1.2) f.pos.addScaledVector(d, Math.min(dist - 1.2, f.pullTo.speed * dt * (f.boss ? 0.15 : 1)));
        f.pullTo.t -= dt;
        if (f.pullTo.t <= 0) f.pullTo = null;
      }
      clampArena(f.pos, f.radius * 0.5);
    }
    // separación entre criaturas
    for (let i = 0; i < all.length; i++) {
      for (let j = i + 1; j < all.length; j++) {
        const a = all[i];
        const b = all[j];
        const dx = b.pos.x - a.pos.x;
        const dz = b.pos.z - a.pos.z;
        const d = Math.hypot(dx, dz);
        const min = (a.radius + b.radius) * 0.75;
        if (d < min && d > 0.001) {
          const push = (min - d) / 2;
          const wa = a.boss ? 0.1 : 1;
          const wb = b.boss ? 0.1 : 1;
          a.pos.x -= (dx / d) * push * wa; a.pos.z -= (dz / d) * push * wa;
          b.pos.x += (dx / d) * push * wb; b.pos.z += (dz / d) * push * wb;
        }
      }
    }
    // fases del jefe
    if (this.boss && this.boss.alive) {
      const k = this.boss.hp / this.boss.maxHp;
      if (this.phase === 1 && k < 0.66) this.bossPhase(2);
      else if (this.phase === 2 && k < 0.34) this.bossPhase(3);
    }
    this.updateProjectiles(dt);
    this.updateZones(dt);
    this.updateMines(dt);
    this.updateStars(dt);
    // visuales
    for (const f of all) {
      f.visual.group.position.copy(f.pos);
      f.visual.update(dt, { moving: f.dash ? 1 : f.moving, heading: f.facing, stunned: f.stunned });
    }
    for (const a of this.anchors) {
      a.mesh.rotation.y += dt;
      a.mesh.position.y = 2.8 + Math.sin(this.time * 2 + a.pos.x) * 0.2;
    }
    this.arena.update(dt);
    this.assignLights();
    // fin de oleada
    if (!this.over && !this.bossStage && this.waveIdx < this.waveCount && this.enemies.length === 0 && !this.timers.some((t) => t.wave)) {
      if (this.waitingNext <= 0) {
        this.waitingNext = 2.2;
        this.rewards.waves++;
        this.rewards.essence += 20 * (this.waveIdx + 1);
        for (const t of this.team) if (!t.fainted) t.heal(t.maxHp * 0.15);
        if (this.waveIdx === 1 && !this.config.tutorial && Math.random() < 0.55) { this.starShower(); this.waitingNext = 9.5; }
      }
    }
    if (this.waitingNext > 0) {
      this.waitingNext -= dt;
      if (this.waitingNext <= 0) this.nextWave();
    }
    this.updateCamera(dt);
    this.fx.update(dt);
    this.dmg.update(dt);
    this.events.hud(this);
  }

  updateProjectiles(dt) {
    for (let i = this.projectiles.length - 1; i >= 0; i--) {
      const pr = this.projectiles[i];
      const step = pr.ab.speed * dt;
      pr.pos.addScaledVector(pr.dir, step);
      pr.left -= step;
      pr.mesh.position.copy(pr.pos);
      if (Math.random() < 0.6) this.fx.particles.spawn(pr.pos.x, pr.pos.y, pr.pos.z, 0, 0.3, 0, pr.color, 0.3, pr.ab.radius * 1.2, 0, 0);
      let done = pr.left <= 0;
      const foes = pr.side === 'player' ? this.foesOf(this.player) : this.player && this.player.alive ? [this.player] : [];
      for (const t of foes) {
        if (pr.hit.has(t)) continue;
        if (Math.hypot(t.pos.x - pr.pos.x, t.pos.z - pr.pos.z) < t.radius + pr.ab.radius) {
          pr.hit.add(t);
          // escudo con reflejo devuelve proyectiles
          if (t.reflect && t.shield > 0 && pr.f.alive) {
            pr.dir.negate();
            pr.side = t.side;
            pr.f = t;
            pr.left = pr.ab.range;
            pr.hit.clear();
            this.dmg.show(tmp.copy(t.pos).setY(t.visual.height + 0.4), tr('reflected'), 'shield');
            break;
          }
          if (pr.ab.explode) {
            this.fx.shockwave(pr.pos, pr.color, pr.ab.explode);
            sfx.boom();
            for (const o of foes) if (Math.hypot(o.pos.x - pr.pos.x, o.pos.z - pr.pos.z) < pr.ab.explode + o.radius) this.damage(pr.f, o, pr.ab.power, pr.ab.stat, pr.ab);
          } else this.damage(pr.f, t, pr.ab.power, pr.ab.stat, pr.ab);
          if (pr.ab.pullBack && t.alive) t.pullTo = { pos: pr.f.pos.clone(), speed: 22, t: 0.5 };
          if (!pr.ab.pierce) { done = true; break; }
        }
      }
      if (done) {
        this.fx.particles.burst(pr.pos, pr.color, 6, 3, 0.3, 0.4, { dy: 0 });
        this.fx.removeOrb(pr.mesh);
        this.projectiles.splice(i, 1);
      }
    }
  }

  updateZones(dt) {
    for (let i = this.zones.length - 1; i >= 0; i--) {
      const z = this.zones[i];
      z.t -= dt;
      z.tickT -= dt;
      if (Math.random() < 0.7) {
        const a = Math.random() * Math.PI * 2;
        const r = Math.random() * z.ab.radius;
        this.fx.particles.spawn(z.pos.x + Math.cos(a) * r, 0.2, z.pos.z + Math.sin(a) * r, 0, 2 + Math.random() * 2, 0, z.color, 0.6, 0.6, 0, 0.5);
      }
      if (z.tickT <= 0) {
        z.tickT += z.ab.tick || 0.5;
        if (z.ab.heal) {
          for (const t of this.teamOf(z.f)) {
            if (t.visual.group.parent && Math.hypot(t.pos.x - z.pos.x, t.pos.z - z.pos.z) < z.ab.radius + t.radius) this.healFx(t, t.maxHp * z.ab.heal);
          }
        } else {
          for (const t of this.foesOf(z.f)) {
            if (Math.hypot(t.pos.x - z.pos.x, t.pos.z - z.pos.z) < z.ab.radius + t.radius) {
              this.damage(z.f, t, z.ab.power, z.ab.stat, z.ab, { zone: true });
              if (z.ab.freezeAfter) {
                const tin = (z.inside.get(t) || 0) + (z.ab.tick || 0.5);
                z.inside.set(t, tin);
                if (tin >= z.ab.freezeAfter && !t.has('freeze')) t.addStatus({ t: 'freeze', dur: 1.5 }, z.f);
              }
            }
          }
        }
      }
      if (z.t <= 0) this.zones.splice(i, 1);
    }
  }

  updateMines(dt) {
    for (let i = this.mines.length - 1; i >= 0; i--) {
      const m = this.mines[i];
      m.arm -= dt;
      m.life -= dt;
      m.mesh.position.y = 0.4 + Math.abs(Math.sin(this.time * 6 + i)) * 0.3;
      let boom = m.life <= 0;
      if (m.arm <= 0) {
        for (const t of this.foesOf(m.f)) if (Math.hypot(t.pos.x - m.pos.x, t.pos.z - m.pos.z) < m.ab.radius + t.radius) boom = true;
      }
      if (boom) {
        this.fx.shockwave(m.pos, m.color, m.ab.radius * 1.4);
        this.fx.particles.burst(m.pos, m.color, 18, 6, 0.5, 0.6);
        sfx.boom();
        for (const t of this.foesOf(m.f)) if (Math.hypot(t.pos.x - m.pos.x, t.pos.z - m.pos.z) < m.ab.radius * 1.4 + t.radius) this.damage(m.f, t, m.ab.power, m.ab.stat, m.ab);
        this.fx.removeOrb(m.mesh);
        this.mines.splice(i, 1);
      }
    }
  }

  updateStars(dt) {
    for (let i = this.stars.length - 1; i >= 0; i--) {
      const s = this.stars[i];
      if (!s.landed) {
        s.pos.y -= dt * 9;
        if (s.pos.y <= 0.8) { s.pos.y = 0.8; s.landed = true; this.fx.shockwave(s.pos, '#ffd76a', 1.5); }
      } else s.pos.y = 0.8 + Math.sin(this.time * 4 + i) * 0.15;
      s.mesh.position.copy(s.pos);
      s.life -= dt;
      const p = this.player;
      if (p && s.landed && Math.hypot(p.pos.x - s.pos.x, p.pos.z - s.pos.z) < 1.8 + p.radius) {
        const v = 25 + this.island.levels[0] * 3;
        this.rewards.essence += v;
        this.rewards.stars++;
        this.dmg.show(s.pos.clone().setY(2), '+' + v, 'gold');
        sfx.coin();
        this.fx.particles.burst(s.pos, '#ffd76a', 12, 4, 0.6, 0.5);
        this.fx.removeOrb(s.mesh);
        this.stars.splice(i, 1);
      } else if (s.life <= 0) {
        this.fx.removeOrb(s.mesh);
        this.stars.splice(i, 1);
      }
    }
  }

  assignLights() {
    const pool = this.lights.pool;
    const list = [this.player, ...this.enemies.filter((e) => e.boss), ...this.enemies.filter((e) => !e.boss)].filter((f) => f && f.alive);
    for (let i = 0; i < pool.length; i++) {
      const f = list[i];
      if (f) {
        pool[i].color.copy(f.visual.glowColor);
        pool[i].intensity = f.boss ? 26 : i === 0 ? 11 : 7;
        pool[i].distance = f.boss ? 22 : 12;
        pool[i].position.set(f.pos.x, f.visual.height * 0.6 + 0.8, f.pos.z + 0.5);
      } else pool[i].intensity = 0;
    }
  }

  updateCamera(dt) {
    const p = this.player;
    if (!p) return;
    const portrait = innerWidth < innerHeight;
    const off = portrait ? new THREE.Vector3(0, 17, 12.5) : new THREE.Vector3(0, 10.5, 11);
    const tgt = this.currentTarget();
    const look = p.pos.clone();
    if (tgt) look.lerp(tgt.pos, 0.25);
    if (this.boss && this.boss.alive) look.lerp(this.boss.pos, 0.15);
    const desired = look.clone().add(off);
    this.camPos.lerp(desired, Math.min(1, dt * 4));
    this.camLook.lerp(look.setY(1), Math.min(1, dt * 5));
    this.camera.position.copy(this.camPos);
    if (this.shakeAmt > 0) {
      this.camera.position.x += (Math.random() - 0.5) * this.shakeAmt;
      this.camera.position.y += (Math.random() - 0.5) * this.shakeAmt;
      this.shakeAmt = Math.max(0, this.shakeAmt - dt * 1.8);
    }
    this.camera.lookAt(this.camLook);
  }

  // --- sellado ------------------------------------------------------------
  sealResult(enemy, result) {
    enemy.sealing = false;
    if (result === 'fail') {
      enemy.heal(enemy.maxHp * 0.1);
      if (enemy.hp / enemy.maxHp >= 0.25) {
        enemy.sealable = false;
        enemy.visual.circle?.setIntensity(1);
        if (enemy.visual.circle) enemy.visual.circle.speed = enemy.boss ? 4 : 1;
      }
      this.dmg.show(tmp.copy(enemy.pos).setY(enemy.visual.height + 0.6), tr('sealFailed'), 'taken');
      return;
    }
    const perfect = result === 'perfect';
    enemy.sealed = true;
    this.fx.beam(enemy.pos, enemy.def.color, 20, 1.6, 1.4);
    this.fx.particles.pillar(enemy.pos, enemy.visual.glowColor, 14, 120, 1.4, 1);
    this.fx.shockwave(enemy.pos, enemy.def.color, 8);
    this.shake(0.4);
    state.stats.seals++;
    if (perfect) { state.stats.perfect++; this.rewards.perfect++; progressContract('perfect'); }
    progressContract('seal');
    const lvl = enemy.level;
    const ess = Math.round((25 + lvl * 6) * (perfect ? 1.5 : 1));
    this.rewards.essence += ess;
    this.rewards.xp += Math.round((10 + lvl * 6) * 1.2);
    this.rewards.sealed.push({ id: enemy.id, level: enemy.boss ? Math.max(1, lvl - 30) : lvl, perfect, boss: !!enemy.boss, essence: ess });
    enemy.alive = false;
    this.removeFighter(enemy);
    if (enemy.boss) {
      this.rewards.bossSealed = true;
      this.rewards.xp += 200 + lvl * 20;
      this.rewards.essence += 600 + lvl * 25;
      this.over = true;
      for (const e of this.enemies) e.alive = false;
      for (const e of [...this.enemies]) this.removeFighter(e);
      this.later(2.2, () => this.finish(true));
    }
  }

  // --- final ------------------------------------------------------------
  finish(victory) {
    if (this.ended) return;
    this.ended = true;
    this.over = true;
    this.events.end(victory, this.rewards, [...this.fought]);
  }

  revive() {
    this.defeated = false;
    this.revivesUsed++;
    this.reviveTeam(0.5);
    const idx = this.team.findIndex((t) => !t.fainted);
    this.player = null;
    this.switchTo(idx, true);
    for (const e of this.enemies) e.addStatus({ t: 'stun', dur: 1.5 }, this.player);
  }

  dispose() {
    this.fx?.clear();
    this.dmg?.clear();
    for (const f of [...this.team, ...this.enemies]) f.dispose();
    this.scene?.traverse((o) => {
      if (o.geometry && !o.geometry.userData?.shared) o.geometry.dispose?.();
    });
    this.scene = null;
  }
}
