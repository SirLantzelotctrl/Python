import * as THREE from 'three';

const BASE = import.meta.env.BASE_URL || './';
export const url = (p) => BASE + p;

export const assets = {
  geo: {}, // id -> [{mat, geometry}]
  tex: {},
  bbox: {},
};

const texLoader = new THREE.TextureLoader();

function loadTex(name, onDone) {
  return new Promise((resolve) => {
    texLoader.load(url(`assets/tex/${name}.webp`), (t) => {
      t.colorSpace = THREE.SRGBColorSpace;
      t.anisotropy = 4;
      assets.tex[name] = t;
      onDone();
      resolve(t);
    }, undefined, () => { onDone(); resolve(null); });
  });
}

export async function loadAssets(onProgress) {
  const texNames = ['halo'];
  for (const d of ['hexagrama', 'heptagrama', 'pentagrama']) {
    for (const l of ['exterior', 'medio', 'interior', 'completo']) texNames.push(`circulo_${d}_${l}`);
  }
  let done = 0;
  const total = texNames.length + 2;
  const tick = () => { done++; onProgress?.(done / total); };

  const [manifest, bin] = await Promise.all([
    fetch(url('assets/creatures.json')).then((r) => r.json()).finally(tick),
    fetch(url('assets/creatures.bin')).then((r) => r.arrayBuffer()).finally(tick),
  ]);
  for (const [id, m] of Object.entries(manifest)) {
    const parts = [];
    for (const p of m.parts) {
      const q = new Int16Array(bin, p.po, p.v * 3);
      const pos = new Float32Array(p.v * 3);
      for (let i = 0; i < p.v; i++) {
        for (let k = 0; k < 3; k++) pos[i * 3 + k] = (q[i * 3 + k] + 32768) * m.scale[k] + m.min[k];
      }
      const idx = new Uint16Array(bin, p.io, p.i);
      const g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
      g.setIndex(new THREE.BufferAttribute(idx, 1));
      g.computeBoundingSphere();
      g.userData.shared = true;
      parts.push({ mat: p.mat, geometry: g });
    }
    assets.geo[id] = parts;
    assets.bbox[id] = { min: m.min, max: m.max };
  }
  await Promise.all(texNames.map((n) => loadTex(n, tick)));
}
