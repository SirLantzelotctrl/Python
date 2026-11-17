// Efectos visuales: partículas (un solo Points con shader propio), anillos,
// avisos en el suelo, rayos y números de daño (DOM).
import * as THREE from 'three';
import { getGlowTex } from './circles.js';

const MAX = 3000;

const vert = `
attribute float size;
attribute vec4 pcolor;
varying vec4 vColor;
void main() {
  vColor = pcolor;
  vec4 mv = modelViewMatrix * vec4(position, 1.0);
  gl_PointSize = size * (300.0 / -mv.z);
  gl_Position = projectionMatrix * mv;
}`;
const frag = `
uniform sampler2D map;
varying vec4 vColor;
void main() {
  vec4 t = texture2D(map, gl_PointCoord);
  gl_FragColor = vec4(vColor.rgb * t.a * vColor.a, 1.0);
}`;

export class Particles {
  constructor(scene) {
    this.geo = new THREE.BufferGeometry();
    this.pos = new Float32Array(MAX * 3);
    this.col = new Float32Array(MAX * 4);
    this.size = new Float32Array(MAX);
    this.geo.setAttribute('position', new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage));
    this.geo.setAttribute('pcolor', new THREE.BufferAttribute(this.col, 4).setUsage(THREE.DynamicDrawUsage));
    this.geo.setAttribute('size', new THREE.BufferAttribute(this.size, 1).setUsage(THREE.DynamicDrawUsage));
    this.mat = new THREE.ShaderMaterial({
      uniforms: { map: { value: getGlowTex() } },
      vertexShader: vert,
      fragmentShader: frag,
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
    });
    this.points = new THREE.Points(this.geo, this.mat);
    this.points.frustumCulled = false;
    this.points.renderOrder = 5;
    scene.add(this.points);
    this.p = [];
    for (let i = 0; i < MAX; i++) this.p.push({ life: 0 });
    this.cursor = 0;
  }

  spawn(x, y, z, vx, vy, vz, color, life, size, grav = 0, drag = 0) {
    const p = this.p[this.cursor];
    this.cursor = (this.cursor + 1) % MAX;
    p.x = x; p.y = y; p.z = z; p.vx = vx; p.vy = vy; p.vz = vz;
    p.r = color.r; p.g = color.g; p.b = color.b;
    p.life = life; p.max = life; p.size = size; p.grav = grav; p.drag = drag;
  }

  burst(pos, color, n = 20, speed = 6, life = 0.7, size = 0.6, opts = {}) {
    const c = color.isColor ? color : new THREE.Color(color);
    const up = opts.up ?? 0.5;
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2;
      const e = (Math.random() - 0.3) * Math.PI * up;
      const s = speed * (0.4 + Math.random() * 0.6);
      this.spawn(pos.x, pos.y + (opts.dy ?? 0.5), pos.z,
        Math.cos(a) * Math.cos(e) * s, Math.sin(e) * s + (opts.lift ?? 0), Math.sin(a) * Math.cos(e) * s,
        c, life * (0.6 + Math.random() * 0.6), size * (0.6 + Math.random() * 0.8), opts.grav ?? -4, opts.drag ?? 1.5);
    }
  }

  ring(pos, color, radius, n = 40, life = 0.6, size = 0.5, outward = 3) {
    const c = color.isColor ? color : new THREE.Color(color);
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2;
      this.spawn(pos.x + Math.cos(a) * radius, pos.y + 0.2, pos.z + Math.sin(a) * radius,
        Math.cos(a) * outward, 0.6 + Math.random(), Math.sin(a) * outward, c, life, size, 0, 1);
    }
  }

  pillar(pos, color, height = 8, n = 50, life = 1, size = 0.7) {
    const c = color.isColor ? color : new THREE.Color(color);
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2;
      const r = Math.random() * 0.8;
      this.spawn(pos.x + Math.cos(a) * r, pos.y + Math.random() * 0.5, pos.z + Math.sin(a) * r,
        0, height * (0.5 + Math.random()), 0, c, life * (0.5 + Math.random() * 0.6), size, 0, 0.5);
    }
  }

  update(dt) {
    const P = this.pos, C = this.col, S = this.size;
    for (let i = 0; i < MAX; i++) {
      const p = this.p[i];
      if (p.life <= 0) { S[i] = 0; continue; }
      p.life -= dt;
      const d = Math.max(0, 1 - p.drag * dt);
      p.vx *= d; p.vy = p.vy * d + p.grav * dt; p.vz *= d;
      p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt;
      const k = Math.max(0, p.life / p.max);
      P[i * 3] = p.x; P[i * 3 + 1] = p.y; P[i * 3 + 2] = p.z;
      C[i * 4] = p.r; C[i * 4 + 1] = p.g; C[i * 4 + 2] = p.b; C[i * 4 + 3] = Math.min(1, k * 1.6);
      S[i] = p.size * (0.4 + k * 0.6);
    }
    this.geo.attributes.position.needsUpdate = true;
    this.geo.attributes.pcolor.needsUpdate = true;
    this.geo.attributes.size.needsUpdate = true;
  }

  clear() { for (const p of this.p) p.life = 0; }
}

// --- mallas efímeras: anillos, avisos, rayos, proyectiles -------------------
let _beamTex = null;
function beamTex() {
  if (_beamTex) return _beamTex;
  const c = document.createElement('canvas');
  c.width = 4;
  c.height = 128;
  const ctx = c.getContext('2d');
  const gr = ctx.createLinearGradient(0, 0, 0, 128);
  gr.addColorStop(0, 'rgba(255,255,255,0)');
  gr.addColorStop(0.6, 'rgba(255,255,255,0.35)');
  gr.addColorStop(1, 'rgba(255,255,255,1)');
  ctx.fillStyle = gr;
  ctx.fillRect(0, 0, 4, 128);
  _beamTex = new THREE.CanvasTexture(c);
  return _beamTex;
}
const ringGeo = new THREE.RingGeometry(0.92, 1, 64);
const discGeo = new THREE.CircleGeometry(1, 48);
const sphereGeo = new THREE.IcosahedronGeometry(1, 1);
ringGeo.userData.shared = discGeo.userData.shared = sphereGeo.userData.shared = true;

export class FX {
  constructor(scene) {
    this.scene = scene;
    this.particles = new Particles(scene);
    this.items = [];
  }

  add(obj, life, update) {
    this.scene.add(obj);
    const it = { obj, life, max: life, update };
    this.items.push(it);
    return it;
  }

  shockwave(pos, color, radius, life = 0.45) {
    const m = new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(2), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide });
    const mesh = new THREE.Mesh(ringGeo, m);
    mesh.rotation.x = -Math.PI / 2;
    mesh.position.set(pos.x, 0.15, pos.z);
    this.add(mesh, life, (it, k) => {
      const s = radius * (0.2 + (1 - k) * 0.8);
      mesh.scale.setScalar(s);
      m.opacity = k;
    });
  }

  // aviso en el suelo: círculo o cono que se llena hasta que cae el golpe
  telegraph({ pos, radius, color = '#ff3355', time = 0.8, cone, dir, length, width }) {
    const group = new THREE.Group();
    group.position.set(pos.x, 0.06, pos.z);
    const c = new THREE.Color(color);
    const edgeMat = new THREE.MeshBasicMaterial({ color: c.clone().multiplyScalar(1.6), transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide });
    const fillMat = new THREE.MeshBasicMaterial({ color: c, transparent: true, opacity: 0.22, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide });
    let fill;
    if (cone) {
      const arc = THREE.MathUtils.degToRad(cone);
      const g = new THREE.CircleGeometry(radius, 32, -arc / 2, arc);
      const edge = new THREE.Mesh(g, fillMat);
      edge.rotation.x = -Math.PI / 2;
      group.add(edge);
      fill = new THREE.Mesh(g, edgeMat);
      fill.rotation.x = -Math.PI / 2;
      group.add(fill);
      // CircleGeometry arranca en +X; lo giramos hacia la dirección
      group.rotation.y = -Math.atan2(dir.z, dir.x);
    } else if (length) {
      const g = new THREE.PlaneGeometry(length, width);
      g.translate(length / 2, 0, 0);
      const base = new THREE.Mesh(g, fillMat);
      base.rotation.x = -Math.PI / 2;
      group.add(base);
      fill = new THREE.Mesh(g, edgeMat);
      fill.rotation.x = -Math.PI / 2;
      group.add(fill);
      group.rotation.y = -Math.atan2(dir.z, dir.x);
    } else {
      const base = new THREE.Mesh(discGeo, fillMat);
      base.rotation.x = -Math.PI / 2;
      base.scale.setScalar(radius);
      group.add(base);
      const edge = new THREE.Mesh(ringGeo, edgeMat);
      edge.rotation.x = -Math.PI / 2;
      edge.scale.setScalar(radius);
      group.add(edge);
      fill = new THREE.Mesh(discGeo, edgeMat.clone());
      fill.material.opacity = 0.3;
      fill.rotation.x = -Math.PI / 2;
      group.add(fill);
    }
    return this.add(group, time, (it, k) => {
      const p = 1 - k;
      if (cone || length) fill.scale.set(p, p, 1);
      else fill.scale.setScalar(radius * p);
      edgeMat.opacity = 0.5 + Math.sin(p * 30) * 0.2;
    });
  }

  bolt(from, to, color, life = 0.25) {
    const pts = [];
    const n = 10;
    for (let i = 0; i <= n; i++) {
      const k = i / n;
      const j = i === 0 || i === n ? 0 : 0.6;
      pts.push(new THREE.Vector3(
        from.x + (to.x - from.x) * k + (Math.random() - 0.5) * j,
        from.y + (to.y - from.y) * k + (Math.random() - 0.5) * j,
        from.z + (to.z - from.z) * k + (Math.random() - 0.5) * j));
    }
    const g = new THREE.BufferGeometry().setFromPoints(pts);
    const m = new THREE.LineBasicMaterial({ color: new THREE.Color(color).multiplyScalar(3), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false });
    const line = new THREE.Line(g, m);
    this.add(line, life, (it, k) => { m.opacity = k; if (k <= 0) g.dispose(); });
  }

  orb(color, radius) {
    const m = new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(2.6) });
    const mesh = new THREE.Mesh(sphereGeo, m);
    mesh.scale.setScalar(radius);
    const halo = new THREE.Sprite(new THREE.SpriteMaterial({ map: getGlowTex(), color: new THREE.Color(color), transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false }));
    halo.scale.setScalar(4);
    mesh.add(halo);
    this.scene.add(mesh);
    return mesh;
  }

  removeOrb(mesh) {
    this.scene.remove(mesh);
    mesh.material.dispose();
    mesh.children[0].material.dispose();
  }

  // columna de luz (sellado, invocación, rayos del cielo): se desvanece hacia arriba
  beam(pos, color, height = 12, radius = 0.6, life = 0.6) {
    const g = new THREE.CylinderGeometry(radius * 0.6, radius, height, 20, 1, true);
    g.translate(0, height / 2, 0);
    const m = new THREE.MeshBasicMaterial({ map: beamTex(), color: new THREE.Color(color).multiplyScalar(0.9), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide });
    const mesh = new THREE.Mesh(g, m);
    mesh.position.set(pos.x, 0, pos.z);
    this.add(mesh, life, (it, k) => { m.opacity = Math.min(1, (1 - k) * 6) * k * 0.55; mesh.scale.x = mesh.scale.z = 0.5 + k * 0.5; if (k <= 0) g.dispose(); });
  }

  update(dt) {
    this.particles.update(dt);
    for (let i = this.items.length - 1; i >= 0; i--) {
      const it = this.items[i];
      it.life -= dt;
      const k = Math.max(0, it.life / it.max);
      it.update?.(it, k);
      if (it.life <= 0) {
        this.scene.remove(it.obj);
        it.obj.traverse?.((o) => { if (o.material) o.material.dispose(); });
        this.items.splice(i, 1);
      }
    }
  }

  clear() {
    for (const it of this.items) this.scene.remove(it.obj);
    this.items = [];
    this.particles.clear();
  }
}

// --- números de daño flotantes (DOM, nítidos en cualquier pantalla) -------
export class DamageText {
  constructor(layer, camera) {
    this.layer = layer;
    this.camera = camera;
    this.items = [];
    this.v = new THREE.Vector3();
  }

  show(pos, text, cls = '', life = 0.9) {
    if (this.items.length > 40) {
      const old = this.items.shift();
      old.el.remove();
    }
    const el = document.createElement('div');
    el.className = 'dmg ' + cls;
    el.textContent = text;
    this.layer.appendChild(el);
    this.items.push({ el, pos: pos.clone().add(new THREE.Vector3((Math.random() - 0.5) * 0.8, 0, 0)), life, max: life });
  }

  update(dt) {
    const w = window.innerWidth;
    const h = window.innerHeight;
    for (let i = this.items.length - 1; i >= 0; i--) {
      const it = this.items[i];
      it.life -= dt;
      it.pos.y += dt * 1.8;
      if (it.life <= 0) {
        it.el.remove();
        this.items.splice(i, 1);
        continue;
      }
      this.v.copy(it.pos).project(this.camera);
      const x = (this.v.x * 0.5 + 0.5) * w;
      const y = (-this.v.y * 0.5 + 0.5) * h;
      const k = it.life / it.max;
      it.el.style.transform = `translate(${x}px, ${y}px) translate(-50%, -50%) scale(${0.8 + Math.min(1, (1 - k) * 6) * 0.3})`;
      it.el.style.opacity = Math.min(1, k * 2.5);
    }
  }

  clear() {
    for (const it of this.items) it.el.remove();
    this.items = [];
  }
}
