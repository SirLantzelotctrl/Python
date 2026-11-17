// Círculos mágicos por capas (exterior, medio, interior) teñidos del color
// del elemento. Los tres diseños originales vienen en texturas; los diseños
// extra de la tienda se dibujan en un canvas.
import * as THREE from 'three';
import { assets } from './assets.js';

const procCache = {};
let glowTex = null;

function seeded(seed) {
  let s = seed >>> 0;
  return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
}

function glyph(ctx, x, y, size, rnd) {
  ctx.beginPath();
  const n = 2 + Math.floor(rnd() * 3);
  let px = x + (rnd() - 0.5) * size;
  let py = y + (rnd() - 0.5) * size;
  ctx.moveTo(px, py);
  for (let i = 0; i < n; i++) {
    px = x + (rnd() - 0.5) * size;
    py = y + (rnd() - 0.5) * size;
    ctx.lineTo(px, py);
  }
  ctx.stroke();
}

function ring(ctx, r, w, dash) {
  ctx.lineWidth = w;
  ctx.setLineDash(dash || []);
  ctx.beginPath();
  ctx.arc(512, 512, r, 0, Math.PI * 2);
  ctx.stroke();
  ctx.setLineDash([]);
}

function starPoly(ctx, n, k, r, rot = -Math.PI / 2) {
  ctx.beginPath();
  for (let i = 0; i <= n; i++) {
    const a = rot + ((i * k) % n) / n * Math.PI * 2;
    const x = 512 + Math.cos(a) * r;
    const y = 512 + Math.sin(a) * r;
    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
  }
  ctx.stroke();
}

function drawProc(design, layer) {
  const c = document.createElement('canvas');
  c.width = c.height = 1024;
  const ctx = c.getContext('2d');
  ctx.strokeStyle = '#fff';
  ctx.fillStyle = '#fff';
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.shadowColor = '#fff';
  ctx.shadowBlur = 6;
  const rnd = seeded(design.length * 977 + layer.length * 131);
  if (layer === 'exterior') {
    ring(ctx, 500, 5);
    ring(ctx, 470, 2.5);
    ring(ctx, 404, 2.5);
    ctx.lineWidth = 2.5;
    for (let i = 0; i < 40; i++) {
      const a = (i / 40) * Math.PI * 2;
      glyph(ctx, 512 + Math.cos(a) * 437, 512 + Math.sin(a) * 437, 26, rnd);
    }
    if (design === 'corona') {
      for (let i = 0; i < 24; i++) {
        const a = (i / 24) * Math.PI * 2;
        ctx.beginPath();
        ctx.moveTo(512 + Math.cos(a - 0.03) * 500, 512 + Math.sin(a - 0.03) * 500);
        ctx.lineTo(512 + Math.cos(a) * 470, 512 + Math.sin(a) * 470);
        ctx.lineTo(512 + Math.cos(a + 0.03) * 500, 512 + Math.sin(a + 0.03) * 500);
        ctx.stroke();
      }
    }
  } else if (layer === 'medio') {
    if (design === 'corona') {
      ring(ctx, 380, 3);
      ring(ctx, 352, 8, [2, 26]);
      for (let i = 0; i < 12; i++) {
        const a = (i / 12) * Math.PI * 2;
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.moveTo(512 + Math.cos(a) * 300, 512 + Math.sin(a) * 300);
        ctx.lineTo(512 + Math.cos(a) * 380, 512 + Math.sin(a) * 380);
        ctx.stroke();
      }
    } else if (design === 'constelacion') {
      ring(ctx, 380, 2, [10, 14]);
      const pts = [];
      for (let i = 0; i < 9; i++) {
        const a = rnd() * Math.PI * 2;
        const r = 230 + rnd() * 140;
        pts.push([512 + Math.cos(a) * r, 512 + Math.sin(a) * r]);
      }
      ctx.lineWidth = 2;
      ctx.beginPath();
      pts.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
      ctx.stroke();
      pts.forEach(([x, y]) => { ctx.beginPath(); ctx.arc(x, y, 9, 0, Math.PI * 2); ctx.fill(); });
    } else {
      ring(ctx, 380, 3);
      ctx.lineWidth = 6;
      for (let i = 0; i < 3; i++) {
        const a = (i / 3) * Math.PI * 2;
        ctx.beginPath();
        ctx.arc(512, 512, 330, a, a + 1.4);
        ctx.stroke();
      }
    }
  } else {
    if (design === 'corona') {
      ctx.lineWidth = 3.5;
      starPoly(ctx, 12, 5, 280);
      ring(ctx, 110, 3);
    } else if (design === 'constelacion') {
      ctx.lineWidth = 3;
      starPoly(ctx, 8, 3, 270);
      for (let i = 0; i < 8; i++) {
        const a = (i / 8) * Math.PI * 2 - Math.PI / 2;
        ctx.beginPath();
        ctx.arc(512 + Math.cos(a) * 270, 512 + Math.sin(a) * 270, 16, 0, Math.PI * 2);
        ctx.stroke();
      }
    } else {
      ring(ctx, 260, 4);
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.arc(560, 490, 200, 0, Math.PI * 2);
      ctx.stroke();
      starPoly(ctx, 7, 3, 240);
    }
    ring(ctx, 30, 6);
  }
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4;
  return t;
}

function layerTex(design, layer) {
  if (['hexagrama', 'heptagrama', 'pentagrama'].includes(design)) return assets.tex[`circulo_${design}_${layer}`];
  const key = design + layer;
  if (!procCache[key]) procCache[key] = drawProc(design, layer);
  return procCache[key];
}

export function getGlowTex() {
  if (glowTex) return glowTex;
  const c = document.createElement('canvas');
  c.width = c.height = 128;
  const ctx = c.getContext('2d');
  const g = ctx.createRadialGradient(64, 64, 0, 64, 64, 64);
  g.addColorStop(0, 'rgba(255,255,255,1)');
  g.addColorStop(0.35, 'rgba(255,255,255,0.35)');
  g.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, 128, 128);
  glowTex = new THREE.CanvasTexture(c);
  return glowTex;
}

const planeGeo = new THREE.PlaneGeometry(1, 1);
planeGeo.userData.shared = true;

export class MagicCircle {
  constructor(design, color, radius = 2) {
    this.group = new THREE.Group();
    this.layers = [];
    this.speed = 1;
    this.intensity = 1;
    this.color = new THREE.Color(color);
    this.design = '';
    const glowMat = new THREE.MeshBasicMaterial({ map: getGlowTex(), color: this.color, transparent: true, opacity: 0.32, blending: THREE.AdditiveBlending, depthWrite: false });
    this.glow = new THREE.Mesh(planeGeo, glowMat);
    this.glow.rotation.x = -Math.PI / 2;
    this.glow.scale.setScalar(radius * 2.6);
    this.glow.renderOrder = 1;
    this.group.add(this.glow);
    for (const l of ['exterior', 'medio', 'interior']) {
      const m = new THREE.MeshBasicMaterial({ transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, color: this.color });
      const mesh = new THREE.Mesh(planeGeo, m);
      mesh.rotation.x = -Math.PI / 2;
      mesh.scale.setScalar(radius * 2);
      mesh.position.y = 0.02 + this.layers.length * 0.004;
      mesh.renderOrder = 2;
      this.group.add(mesh);
      this.layers.push(mesh);
    }
    this.setDesign(design);
    this.setColor(color);
  }

  setDesign(design) {
    if (design === this.design) return;
    this.design = design;
    ['exterior', 'medio', 'interior'].forEach((l, i) => {
      this.layers[i].material.map = layerTex(design, l);
      this.layers[i].material.needsUpdate = true;
    });
  }

  setColor(c) {
    this.color.set(c);
    this.applyIntensity();
  }

  setIntensity(k) {
    this.intensity = k;
    this.applyIntensity();
  }

  applyIntensity() {
    const k = 1.25 * this.intensity;
    for (const l of this.layers) l.material.color.copy(this.color).multiplyScalar(k);
    this.glow.material.color.copy(this.color);
    this.glow.material.opacity = Math.min(0.9, 0.3 * this.intensity);
  }

  setOpacity(o) {
    for (const l of this.layers) { l.material.opacity = o; }
    this.glow.material.opacity = Math.min(0.9, 0.3 * this.intensity) * o;
  }

  update(dt) {
    const s = this.speed;
    this.layers[0].rotation.z += dt * 0.12 * s;
    this.layers[1].rotation.z -= dt * 0.22 * s;
    this.layers[2].rotation.z += dt * 0.4 * s;
  }

  dispose() {
    for (const l of this.layers) l.material.dispose();
    this.glow.material.dispose();
  }
}
