// Escenario: isla flotante facetada sobre el Abismo, cielo nocturno con
// estrellas, islas lejanas y decorado procedural según la isla.
import * as THREE from 'three';
import { NIGHT } from './renderer.js';
import { MagicCircle } from './circles.js';

export const ARENA_R = 17;

function jitter(geo, amt, keepTop = true) {
  const p = geo.attributes.position;
  for (let i = 0; i < p.count; i++) {
    if (keepTop && p.getY(i) > 0.55) continue;
    p.setXYZ(i, p.getX(i) + (Math.random() - 0.5) * amt, p.getY(i) + (Math.random() - 0.5) * amt, p.getZ(i) + (Math.random() - 0.5) * amt);
  }
  geo.computeVertexNormals();
  return geo;
}

function stoneMat(hex) {
  return new THREE.MeshStandardMaterial({ color: new THREE.Color(hex), roughness: 0.92, metalness: 0.05, flatShading: true });
}

function glowMat(color, k = 2) {
  return new THREE.MeshBasicMaterial({ color: new THREE.Color(color).multiplyScalar(k) });
}

export function makeStars(n = 900, radius = 140) {
  const g = new THREE.BufferGeometry();
  const pos = new Float32Array(n * 3);
  for (let i = 0; i < n; i++) {
    const u = Math.random() * 2 - 1;
    const a = Math.random() * Math.PI * 2;
    const r = radius * (0.7 + Math.random() * 0.3);
    const s = Math.sqrt(1 - u * u);
    pos[i * 3] = Math.cos(a) * s * r;
    pos[i * 3 + 1] = Math.abs(u) * r * 0.9 - 10;
    pos[i * 3 + 2] = Math.sin(a) * s * r;
  }
  g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const m = new THREE.PointsMaterial({ color: 0xcfc8ff, size: 1.6, sizeAttenuation: false, transparent: true, opacity: 0.8, depthWrite: false });
  return new THREE.Points(g, m);
}

export function setupLights(scene) {
  scene.background = NIGHT.clone();
  scene.fog = new THREE.FogExp2(NIGHT, 0.014);
  const hemi = new THREE.HemisphereLight(0x8d84c8, 0x15122a, 1.6);
  scene.add(hemi);
  const key = new THREE.DirectionalLight(0xe8e0ff, 1.7);
  key.position.set(-6, 14, 10);
  scene.add(key);
  const rim = new THREE.DirectionalLight(0x8a7dff, 1.2);
  rim.position.set(8, 6, -12);
  scene.add(rim);
  // reserva fija de luces de color (cambiar el número de luces recompila shaders)
  const pool = [];
  for (let i = 0; i < 4; i++) {
    const l = new THREE.PointLight(0xffffff, 0, 14, 1.6);
    scene.add(l);
    pool.push(l);
  }
  return { hemi, key, rim, pool };
}

export function buildArena(scene, island, color) {
  const root = new THREE.Group();
  const c = new THREE.Color(color);
  // tapa de la isla
  const top = jitter(new THREE.CylinderGeometry(ARENA_R + 2.5, ARENA_R + 1.5, 1.4, 48, 2), 0.5);
  const ground = new THREE.Mesh(top, stoneMat('#1d1936'));
  ground.position.y = -0.7;
  root.add(ground);
  // raíz de roca colgando sobre el Abismo
  const under = jitter(new THREE.ConeGeometry(ARENA_R + 1.6, 16, 18, 4), 1.6, false);
  under.rotateX(Math.PI);
  const rock = new THREE.Mesh(under, stoneMat('#141127'));
  rock.position.y = -9.3;
  root.add(rock);
  // borde de luz
  const rim = new THREE.Mesh(new THREE.TorusGeometry(ARENA_R + 2.3, 0.04, 6, 120), glowMat(c, 0.55));
  rim.rotation.x = Math.PI / 2;
  rim.position.y = 0.02;
  root.add(rim);
  // gran sello del suelo (el del Primordial de la isla), muy tenue
  const floorSeal = new MagicCircle(island.sealDesign || 'hexagrama', color, ARENA_R + 1);
  floorSeal.setIntensity(0.035);
  floorSeal.speed = 0.25;
  floorSeal.group.position.y = 0.005;
  root.add(floorSeal.group);

  // islas lejanas
  for (let i = 0; i < 9; i++) {
    const r = 3 + Math.random() * 6;
    const g = jitter(new THREE.ConeGeometry(r, r * 2.2, 7, 2), r * 0.25, false);
    g.rotateX(Math.PI);
    const m = new THREE.Mesh(g, stoneMat('#16132b'));
    const a = (i / 9) * Math.PI * 2 + Math.random() * 0.4;
    const d = 48 + Math.random() * 40;
    m.position.set(Math.cos(a) * d, -6 + Math.random() * 14, Math.sin(a) * d);
    root.add(m);
    const capG = new THREE.CylinderGeometry(r * 1.05, r, 0.6, 7);
    const cap = new THREE.Mesh(capG, stoneMat('#221d40'));
    cap.position.copy(m.position).add(new THREE.Vector3(0, r * 1.1, 0));
    root.add(cap);
  }

  addProps(root, island.props, c);
  root.add(makeStars());
  scene.add(root);
  return { root, floorSeal, update: (dt) => floorSeal.update(dt) };
}

function ringPos(minR, maxR) {
  const a = Math.random() * Math.PI * 2;
  const r = minR + Math.random() * (maxR - minR);
  return [Math.cos(a) * r, Math.sin(a) * r];
}

function addProps(root, type, color) {
  const glow = glowMat(color, 1.1);
  const n = 14;
  for (let i = 0; i < n; i++) {
    const [x, z] = ringPos(ARENA_R - 0.5, ARENA_R + 2);
    let mesh;
    switch (type) {
      case 'flores': {
        mesh = new THREE.Group();
        for (let k = 0; k < 5; k++) {
          const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.04, 0.6 + Math.random() * 0.5, 4), stoneMat('#2e3a35'));
          stem.position.set((Math.random() - 0.5) * 1.6, 0.35, (Math.random() - 0.5) * 1.6);
          const bloom = new THREE.Mesh(new THREE.OctahedronGeometry(0.14), glow);
          bloom.position.copy(stem.position).add(new THREE.Vector3(0, 0.38, 0));
          mesh.add(stem, bloom);
        }
        break;
      }
      case 'pilares':
      case 'estatuas': {
        const h = 2 + Math.random() * 3;
        const g = jitter(new THREE.BoxGeometry(1, h, 1, 1, 3, 1), 0.15, false);
        g.translate(0, h / 2, 0);
        mesh = new THREE.Mesh(g, stoneMat(type === 'estatuas' ? '#4a5552' : '#2b2648'));
        if (type === 'pilares') {
          const strip = new THREE.Mesh(new THREE.BoxGeometry(1.04, 0.08, 1.04), glow);
          strip.position.y = h * 0.6;
          mesh.add(strip);
        } else {
          const head = new THREE.Mesh(new THREE.IcosahedronGeometry(0.45, 0), stoneMat('#4a5552'));
          head.position.y = h + 0.35;
          mesh.add(head);
        }
        mesh.rotation.y = Math.random() * Math.PI;
        mesh.rotation.z = (Math.random() - 0.5) * 0.25;
        break;
      }
      case 'hielo':
      case 'corales':
      case 'cristales': {
        mesh = new THREE.Group();
        const col = type === 'hielo' ? '#a8dff0' : null;
        for (let k = 0; k < 3; k++) {
          const h = 1 + Math.random() * 2.6;
          const g = new THREE.ConeGeometry(0.3 + Math.random() * 0.3, h, 5);
          g.translate(0, h / 2, 0);
          const m = type === 'cristales' || type === 'corales'
            ? new THREE.Mesh(g, glowMat(color, 1.1))
            : new THREE.Mesh(g, new THREE.MeshStandardMaterial({ color: col, roughness: 0.2, metalness: 0.1, flatShading: true, transparent: true, opacity: 0.85 }));
          m.position.set((Math.random() - 0.5) * 1.2, 0, (Math.random() - 0.5) * 1.2);
          m.rotation.set((Math.random() - 0.5) * 0.5, 0, (Math.random() - 0.5) * 0.5);
          mesh.add(m);
        }
        break;
      }
      case 'lava': {
        const g = new THREE.BoxGeometry(3 + Math.random() * 3, 0.05, 0.12);
        mesh = new THREE.Mesh(g, glowMat('#ff7a2e', 2));
        mesh.position.y = 0.02;
        mesh.rotation.y = Math.random() * Math.PI;
        const [ix, iz] = ringPos(5, ARENA_R - 2);
        mesh.position.x = ix;
        mesh.position.z = iz;
        root.add(mesh);
        mesh = new THREE.Mesh(jitter(new THREE.DodecahedronGeometry(0.8 + Math.random()), 0.2, false), stoneMat('#241c2a'));
        break;
      }
      case 'telas': {
        mesh = new THREE.Group();
        const post = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.2, 3.5, 5), stoneMat('#2a2140'));
        post.position.y = 1.75;
        mesh.add(post);
        const pts = [];
        for (let k = 0; k < 6; k++) pts.push(new THREE.Vector3(0, 3.3, 0), new THREE.Vector3(Math.cos(k) * 2.5, 0.1, Math.sin(k) * 2.5));
        const lg = new THREE.BufferGeometry().setFromPoints(pts);
        mesh.add(new THREE.LineSegments(lg, new THREE.LineBasicMaterial({ color: new THREE.Color(color).multiplyScalar(1.4) })));
        break;
      }
      default: {
        // rocas, estrellas, vacío: rocas flotantes
        mesh = new THREE.Mesh(jitter(new THREE.DodecahedronGeometry(0.6 + Math.random() * 1.2), 0.25, false), stoneMat(type === 'vacio' ? '#2a1d45' : '#231f3d'));
        mesh.position.y = 1 + Math.random() * 3;
        mesh.userData.float = Math.random() * 6;
        if (type === 'estrellas' || type === 'vacio') {
          const s = new THREE.Mesh(new THREE.OctahedronGeometry(0.12), glow);
          s.position.y = 1.2;
          mesh.add(s);
        }
      }
    }
    mesh.position.x = x;
    mesh.position.z = z;
    root.add(mesh);
  }
}
