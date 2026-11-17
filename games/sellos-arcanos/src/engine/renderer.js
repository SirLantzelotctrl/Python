import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';

export const NIGHT = new THREE.Color('#090817');
export const RENDER = { bloom: true };

const isMobile = /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent) || (navigator.maxTouchPoints > 1 && window.innerWidth < 1100);

export const QUALITY = {
  low: { dpr: 1, bloom: false, aa: false, shadows: false },
  medium: { dpr: 1.5, bloom: true, bloomScale: 0.5, aa: false },
  high: { dpr: 2, bloom: true, bloomScale: 0.5, aa: true },
};

export class Renderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.qualityName = 'auto';
    this.q = isMobile ? QUALITY.medium : QUALITY.high;
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: !isMobile, powerPreference: 'high-performance', alpha: false, preserveDrawingBuffer: false });
    this.renderer.setClearColor(NIGHT, 1);
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.05;
    this.scene = null;
    this.camera = null;
    this.composer = null;
    this.bloom = null;
    this.fpsSamples = [];
    this.autoChecked = false;
    window.addEventListener('resize', () => this.resize());
    this.resize();
  }

  get isMobile() { return isMobile; }

  setQuality(name) {
    this.qualityName = name;
    this.q = name === 'auto' ? (isMobile ? QUALITY.medium : QUALITY.high) : QUALITY[name];
    this.autoChecked = name !== 'auto';
    this.buildComposer();
    this.resize();
  }

  setScene(scene, camera) {
    this.scene = scene;
    this.camera = camera;
    this.buildComposer();
    this.resize();
  }

  buildComposer() {
    if (!this.scene) return;
    if (this.composer) this.composer.dispose();
    this.composer = null;
    RENDER.bloom = !!this.q.bloom;
    if (!this.q.bloom) return;
    const size = this.renderer.getSize(new THREE.Vector2());
    this.composer = new EffectComposer(this.renderer);
    this.composer.addPass(new RenderPass(this.scene, this.camera));
    this.bloom = new UnrealBloomPass(new THREE.Vector2(size.x * this.q.bloomScale, size.y * this.q.bloomScale), 0.9, 0.5, 0.62);
    this.composer.addPass(this.bloom);
    this.composer.addPass(new OutputPass());
  }

  resize() {
    const w = window.innerWidth;
    const h = window.innerHeight;
    const dpr = Math.min(window.devicePixelRatio || 1, this.q.dpr);
    this.renderer.setPixelRatio(dpr);
    this.renderer.setSize(w, h, false);
    if (this.camera) {
      this.camera.aspect = w / h;
      // en vertical abrimos el campo de visión para que quepa la arena
      this.camera.fov = w < h ? 62 : 45;
      this.camera.updateProjectionMatrix();
    }
    if (this.composer) {
      this.composer.setPixelRatio(dpr);
      this.composer.setSize(w, h);
    }
  }

  render(dt) {
    if (!this.scene || !this.camera) return;
    if (this.composer) this.composer.render(dt);
    else this.renderer.render(this.scene, this.camera);
    this.adapt(dt);
  }

  // Calidad automática: si el móvil no llega a ~40 fps, baja a «low».
  adapt(dt) {
    if (this.autoChecked || this.qualityName !== 'auto') return;
    this.fpsSamples.push(dt);
    if (this.fpsSamples.length < 180) return;
    const avg = this.fpsSamples.reduce((a, b) => a + b, 0) / this.fpsSamples.length;
    this.fpsSamples = [];
    if (avg > 1 / 28) {
      if (this.q === QUALITY.high) this.q = QUALITY.medium;
      else if (this.q === QUALITY.medium) { this.q = QUALITY.low; this.autoChecked = true; }
      this.buildComposer();
      this.resize();
    } else {
      this.autoChecked = true;
    }
  }
}
