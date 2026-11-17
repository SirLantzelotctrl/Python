// Escena 3D de los menús: el equipo sobre sus círculos (como el arte del
// menú), una criatura sola para el Bestiario y la ficha (se gira arrastrando)
// o las tres iniciales para elegir.
import * as THREE from 'three';
import { CreatureVisual } from './creatureMesh.js';
import { setupLights, makeStars } from './arena.js';
import { CREATURE } from '../data/creatures.js';
import { getGlowTex } from './circles.js';

export class Showcase {
  constructor(renderer) {
    this.renderer = renderer;
    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(40, innerWidth / innerHeight, 0.1, 300);
    this.lights = setupLights(this.scene);
    this.scene.fog.density = 0.02;
    this.scene.add(makeStars(700, 120));
    this.items = [];
    this.mode = '';
    this.drag = { on: false, x: 0, rot: 0, vel: 0 };
    this.motes = this.makeMotes();
    this.scene.add(this.motes);
    this.t = 0;
    this.camTarget = new THREE.Vector3();
    this.camPos = new THREE.Vector3(0, 3, 12);
  }

  makeMotes() {
    const n = 160;
    const g = new THREE.BufferGeometry();
    const p = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) {
      p[i * 3] = (Math.random() - 0.5) * 30;
      p[i * 3 + 1] = Math.random() * 10;
      p[i * 3 + 2] = (Math.random() - 0.5) * 20;
    }
    g.setAttribute('position', new THREE.BufferAttribute(p, 3));
    const m = new THREE.PointsMaterial({ map: getGlowTex(), color: 0xcfc8ff, size: 0.22, transparent: true, opacity: 0.6, blending: THREE.AdditiveBlending, depthWrite: false });
    return new THREE.Points(g, m);
  }

  activate() {
    this.renderer.setScene(this.scene, this.camera);
  }

  clear() {
    for (const it of this.items) {
      this.scene.remove(it.v.group);
      it.v.dispose();
    }
    this.items = [];
  }

  // specs: [{id, form, glow, seal}]
  setTeam(specs, layout = 'menu') {
    const key = layout + JSON.stringify(specs);
    if (this.mode === key) return;
    this.mode = key;
    this.clear();
    const portrait = innerWidth < innerHeight;
    const slots = layout === 'starter'
      ? portrait ? [[-2.7, 0, 0], [0, 0, -1.4], [2.7, 0, 0]] : [[-5.2, 0, 0], [0, 0, -0.6], [5.2, 0, 0]]
      : portrait
        ? [[0, 0, 1.6], [-3.2, 0, -2.2], [3.2, 0, -2.6]]
        : [[3.2, 0, 1.8], [0.4, 0, -2.2], [6.6, 0, -1.6]];
    specs.forEach((s, i) => {
      const v = new CreatureVisual(s.id, { form: Math.max(1, s.form ?? 1), glow: s.glow, seal: s.seal });
      const [x, y, z] = slots[i] || [i * 3, 0, 0];
      v.group.position.set(x, y, z);
      v.pivot.rotation.y = layout === 'starter' ? 0 : -0.5 + i * 0.1;
      this.scene.add(v.group);
      this.items.push({ v, base: new THREE.Vector3(x, y, z), heading: v.pivot.rotation.y });
    });
    if (layout === 'starter' && portrait) {
      this.camPos.set(0, 3.5, 17);
      this.camTarget.set(0, -2.2, 0);
    } else if (layout === 'starter') {
      this.camPos.set(0, 4.2, 15);
      this.camTarget.set(0, 1.6, 0);
    } else if (portrait) {
      this.camPos.set(0, 6, 16);
      this.camTarget.set(0, 5, 0);
    } else {
      this.camPos.set(-2.5, 4.4, 13.5);
      this.camTarget.set(1.2, 1.6, 0);
    }
  }

  setSingle(id, { form = 1, glow, seal, offsetX = 0 } = {}) {
    const key = 'single' + id + form + glow + seal + offsetX;
    if (this.mode === key) return;
    this.mode = key;
    this.clear();
    const v = new CreatureVisual(id, { form: 1, glow: glow || CREATURE[id].color, seal, scale: form === 2 ? 0.95 : form === 1 ? 0.8 : 0.66 });
    v.group.position.set(0, 0, 0);
    this.scene.add(v.group);
    this.items.push({ v, base: new THREE.Vector3(), heading: 0.5 });
    this.drag.rot = 0.5;
    const h = v.height;
    const portrait = innerWidth < innerHeight;
    // la criatura queda a la derecha: la cámara mira un poco a su izquierda
    const ox = portrait ? 0 : offsetX * (h * 0.35 + 0.8);
    this.camPos.set(ox, h * 0.75 + 1, portrait ? h * 3.2 + 7 : h * 2.4 + 4.5);
    this.camTarget.set(ox, portrait ? -h * 0.55 : h * 0.45, 0);
    this.singleOffset = offsetX;
  }

  setGlow(glow) {
    for (const it of this.items) it.v.setGlow(glow);
  }

  bindDrag(el) {
    el.addEventListener('pointerdown', (e) => {
      if (!this.mode.startsWith('single')) return;
      this.drag.on = true;
      this.drag.x = e.clientX;
    });
    window.addEventListener('pointermove', (e) => {
      if (!this.drag.on) return;
      const dx = e.clientX - this.drag.x;
      this.drag.x = e.clientX;
      this.drag.rot += dx * 0.012;
      this.drag.vel = dx * 0.012;
    });
    window.addEventListener('pointerup', () => { this.drag.on = false; });
  }

  update(dt) {
    this.t += dt;
    this.camera.position.lerp(this.camPos, Math.min(1, dt * 3));
    this.camera.lookAt(this.camTarget);
    const single = this.mode.startsWith('single');
    if (single && !this.drag.on) {
      this.drag.rot += this.drag.vel;
      this.drag.vel *= 0.94;
      this.drag.rot += dt * 0.25;
    }
    this.items.forEach((it, i) => {
      const heading = single ? this.drag.rot : it.heading + Math.sin(this.t * 0.4 + i) * 0.15;
      it.v.pivot.rotation.y = heading;
      it.v.update(dt, {});
    });
    const pool = this.lights.pool;
    for (let i = 0; i < pool.length; i++) {
      const it = this.items[i];
      if (it) {
        pool[i].color.copy(it.v.glowColor);
        pool[i].intensity = 12;
        pool[i].distance = 14;
        pool[i].position.set(it.v.group.position.x, it.v.height * 0.6 + 1, it.v.group.position.z + 1.2);
      } else pool[i].intensity = 0;
    }
    const pos = this.motes.geometry.attributes.position;
    for (let i = 0; i < pos.count; i++) {
      let y = pos.getY(i) + dt * 0.35;
      if (y > 10) y = 0;
      pos.setY(i, y);
    }
    pos.needsUpdate = true;
  }
}
