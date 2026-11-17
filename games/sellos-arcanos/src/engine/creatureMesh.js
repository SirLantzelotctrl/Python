// Visual de una criatura: modelo facetado + neón del elemento + círculo
// mágico + halo. Los modelos son estáticos, así que la vida viene de la
// animación procedural (respirar, saltar al andar, embestir, latido del brillo).
import * as THREE from 'three';
import { assets } from './assets.js';
import { MagicCircle, getGlowTex } from './circles.js';
import { CREATURE, FORMS } from '../data/creatures.js';
import { RENDER } from './renderer.js';

const GLOW_PARTS = new Set(['Brillo', 'Plumas', 'Estrellas', 'Cristal']);
const FLYERS = new Set(['fenix', 'grifo', 'wyvern', 'leviatan']);
const tmpColor = new THREE.Color();

export function resolveGlow(glow, t) {
  if (glow === 'prisma') return tmpColor.setHSL((t * 0.12) % 1, 0.95, 0.62);
  if (glow === 'aurora') {
    const stops = ['#9fefff', '#3dff88', '#b06bff', '#ff4fd2'];
    const x = (t * 0.25) % stops.length;
    const i = Math.floor(x);
    return tmpColor.set(stops[i]).lerp(new THREE.Color(stops[(i + 1) % stops.length]), x - i);
  }
  return tmpColor.set(glow);
}

export class CreatureVisual {
  constructor(id, { glow, form = 0, boss = false, seal, circle = true, scale } = {}) {
    const def = CREATURE[id];
    this.id = id;
    this.def = def;
    this.glowId = glow || def.color;
    this.group = new THREE.Group();
    this.pivot = new THREE.Group();
    this.group.add(this.pivot);
    this.flyer = FLYERS.has(id);
    this.t = Math.random() * 10;
    this.flash = 0;
    this.flashColor = new THREE.Color(1, 1, 1);
    this.lunge = 0;
    this.squash = 0;
    this.tilt = 0;
    this.moveAmt = 0;
    this.statusTint = null;
    this.opacity = 1;
    this.glowPulse = 1;

    const bb = assets.bbox[id];
    const height = bb.max[1] - bb.min[1];
    const norm = Math.pow(3.6 / height, 0.55);
    const s = (scale ?? FORMS[form].scale * (boss ? 1.75 : 1)) * norm;
    this.scale = s;
    this.height = height * s;
    this.radius = Math.max(-bb.min[0], bb.max[0], -bb.min[2], bb.max[2]) * s * 0.62;

    const body = new THREE.Color(def.body);
    const bone = new THREE.Color(def.bone);
    this.bodyMats = [];
    this.glowMats = [];
    this.model = new THREE.Group();
    this.model.scale.setScalar(s);
    for (const part of assets.geo[id]) {
      let mat;
      if (GLOW_PARTS.has(part.mat)) {
        mat = new THREE.MeshBasicMaterial({ color: 0xffffff });
        mat.userData.k = part.mat === 'Cristal' ? 1.6 : 2.4;
        this.glowMats.push(mat);
      } else if (part.mat === 'Ojos') {
        mat = new THREE.MeshBasicMaterial({ color: 0xffffff });
        mat.userData.k = 3.2;
        mat.userData.eyes = true;
        this.glowMats.push(mat);
      } else if (part.mat === 'CristalTenue') {
        mat = new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.42, depthWrite: false });
        mat.userData.k = 0.9;
        this.glowMats.push(mat);
      } else {
        let c = body.clone();
        if (part.mat === 'Hueso') c = bone.clone();
        else if (part.mat === 'Cuerpo2' || part.mat === 'Plumaje') c.multiplyScalar(1.22);
        else if (part.mat === 'Oscuro') c.multiplyScalar(0.6);
        else if (part.mat === 'Membrana') c.multiplyScalar(1.1);
        mat = new THREE.MeshStandardMaterial({ color: c, roughness: 0.72, metalness: 0.18, flatShading: true, emissive: 0x000000, side: part.mat === 'Membrana' ? THREE.DoubleSide : THREE.FrontSide });
        mat.userData.base = c.clone();
        this.bodyMats.push(mat);
      }
      const mesh = new THREE.Mesh(part.geometry, mat);
      this.model.add(mesh);
    }
    this.pivot.add(this.model);

    if (circle) {
      this.circle = new MagicCircle(seal || def.circle, def.color, Math.max(1.4, this.radius * 1.9));
      this.group.add(this.circle.group);
    }
    if (def.halo) {
      const hm = new THREE.SpriteMaterial({ map: assets.tex.halo, color: 0xffffff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false });
      this.halo = new THREE.Sprite(hm);
      this.halo.scale.setScalar(this.height * 0.55);
      this.halo.position.set(0, this.height * 0.82, -0.35 * s);
      this.pivot.add(this.halo);
    }
    // halo suave del elemento sobre la criatura (da el «resplandor» del lienzo)
    const am = new THREE.SpriteMaterial({ map: getGlowTex(), transparent: true, opacity: 0.09, blending: THREE.AdditiveBlending, depthWrite: false });
    this.aura = new THREE.Sprite(am);
    this.aura.scale.setScalar(this.height * 1.4);
    this.aura.position.y = this.height * 0.5;
    this.pivot.add(this.aura);
    this.applyGlow();
  }

  setGlow(glow) {
    this.glowId = glow || this.def.color;
    this.applyGlow();
  }

  setSeal(design) {
    if (this.circle) this.circle.setDesign(design || this.def.circle);
  }

  applyGlow() {
    const c = resolveGlow(this.glowId, this.t);
    const boost = RENDER.bloom ? 1 : 1.35;
    this.aura.material.opacity = (RENDER.bloom ? 0.09 : 0.2) * this.opacity;
    for (const m of this.glowMats) {
      if (m.userData.eyes) m.color.copy(c).lerp(new THREE.Color(1, 1, 1), 0.6).multiplyScalar(m.userData.k * this.glowPulse * boost);
      else m.color.copy(c).multiplyScalar(m.userData.k * this.glowPulse * boost);
    }
    if (this.circle) this.circle.setColor(c);
    if (this.halo) this.halo.material.color.copy(c).multiplyScalar(1.6);
    this.aura.material.color.copy(c);
  }

  get glowColor() { return resolveGlow(this.glowId, this.t).clone(); }

  hit(color) {
    this.flash = 1;
    if (color) this.flashColor.set(color); else this.flashColor.setRGB(1, 1, 1);
    this.squash = 0.12;
  }

  attack() { this.lunge = 1; }

  setOpacity(o) {
    this.opacity = o;
    const tr = o < 1;
    for (const m of [...this.bodyMats, ...this.glowMats]) {
      if (m.userData.k === 0.9) continue;
      m.transparent = tr;
      m.opacity = o;
      m.depthWrite = !tr;
    }
    if (this.circle) this.circle.setOpacity(o);
    this.aura.material.opacity = 0.09 * o;
    if (this.halo) this.halo.material.opacity = o;
  }

  // moving: 0..1  heading: radianes
  update(dt, { moving = 0, heading, stunned = false } = {}) {
    this.t += dt;
    const t = this.t;
    this.moveAmt += (moving - this.moveAmt) * Math.min(1, dt * 8);
    const m = this.moveAmt;
    // respirar
    const breath = 1 + Math.sin(t * 2.2) * 0.018 * (1 - m);
    const hop = Math.abs(Math.sin(t * 9)) * 0.12 * m * this.scale * 2;
    const fly = this.flyer ? 0.35 * this.scale * 2 + Math.sin(t * 1.8) * 0.12 * this.scale * 2 : 0;
    this.pivot.position.y = hop + fly;
    this.squash = Math.max(0, this.squash - dt * 0.8);
    const sq = this.squash * Math.sin(t * 60);
    this.model.scale.set(this.scale * (1 + sq), this.scale * breath * (1 - sq), this.scale * (1 + sq));
    // embestida al atacar
    this.lunge = Math.max(0, this.lunge - dt * 4);
    const lz = Math.sin(this.lunge * Math.PI) * 0.6 * this.scale * 2;
    this.model.position.z = lz;
    if (heading !== undefined) {
      let d = heading - this.pivot.rotation.y;
      while (d > Math.PI) d -= Math.PI * 2;
      while (d < -Math.PI) d += Math.PI * 2;
      this.pivot.rotation.y += d * Math.min(1, dt * 10);
      this.tilt += (Math.max(-0.25, Math.min(0.25, d * 0.6)) * m - this.tilt) * Math.min(1, dt * 6);
    }
    this.pivot.rotation.z = -this.tilt;
    this.pivot.rotation.x = m * 0.06;
    if (stunned) this.pivot.rotation.z += Math.sin(t * 30) * 0.03;
    // latido del brillo y destello al recibir golpes
    this.glowPulse = 1 + Math.sin(t * 3.4) * 0.12;
    this.flash = Math.max(0, this.flash - dt * 5);
    for (const mat of this.bodyMats) {
      if (this.statusTint) mat.emissive.copy(this.statusTint).multiplyScalar(0.35);
      else mat.emissive.setRGB(0, 0, 0);
      if (this.flash > 0) mat.emissive.lerp(this.flashColor, this.flash * 0.8);
    }
    this.applyGlow();
    if (this.circle) this.circle.update(dt);
    if (this.halo) this.halo.material.rotation += dt * 0.15;
  }

  dispose() {
    for (const m of [...this.bodyMats, ...this.glowMats]) m.dispose();
    this.circle?.dispose();
    this.aura.material.dispose();
    this.halo?.material.dispose();
  }
}
