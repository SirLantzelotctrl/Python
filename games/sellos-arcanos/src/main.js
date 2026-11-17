import './styles.css';
import { app } from './app.js';
import { platform } from './core/platform.js';
import { loadState, state, save, tickInk, today } from './core/save.js';
import { detectLang, setLang, t, L } from './core/i18n.js';
import { setVolumes, suspendAudio, resumeAudio, setMuted, initAudio } from './core/audio.js';
import { Renderer } from './engine/renderer.js';
import { loadAssets } from './engine/assets.js';
import { Showcase } from './engine/showcase.js';
import { initInput, pollInput, clearPressed, consume, input } from './engine/input.js';
import { toast } from './ui/ui.js';
import { PRODUCT } from './data/shop.js';

const bootTxt = document.getElementById('boot-txt');

function fail(msg) {
  bootTxt.textContent = msg;
  document.querySelector('#boot .ring')?.remove();
}

async function boot() {
  platform.setHooks({
    pause: () => { setMuted(true); if (app.combat) app.combat.paused = true; },
    resume: () => { setMuted(false); if (app.combat && !document.querySelector('.modal-back, .sealing')) app.combat.paused = false; },
  });
  platform.loadingStart?.();
  const platformReady = platform.init();
  await platformReady;
  await loadState();
  setLang(detectLang(state.settings.lang));
  if (state.ads.date !== today()) state.ads = { date: today(), ink: 0, chest: false };
  platform.noAds = !!state.purchases.noAds;
  setVolumes(state.settings.music, state.settings.sfx);

  const canvas = document.getElementById('gl');
  let renderer;
  try {
    renderer = new Renderer(canvas);
  } catch (e) {
    fail(t('noWebgl'));
    return;
  }
  if (state.settings.quality !== 'auto') renderer.setQuality(state.settings.quality);
  app.renderer = renderer;

  await loadAssets((p) => { bootTxt.textContent = `${t('loading')} ${Math.round(p * 100)} %`; });
  app.showcase = new Showcase(renderer);
  app.showcase.activate();
  app.showcase.bindDrag(document.getElementById('ui'));
  initInput(document.getElementById('joy'), document.getElementById('knob'), document.getElementById('area'));

  // primer gesto: desbloquea el audio
  const unlock = () => { initAudio(); window.removeEventListener('pointerdown', unlock); window.removeEventListener('keydown', unlock); };
  window.addEventListener('pointerdown', unlock);
  window.addEventListener('keydown', unlock);

  // pausa al cambiar de pestaña
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      suspendAudio();
      if (app.combat && !app.combat.paused && !app.combat.over) app.pause();
      save();
    } else resumeAudio();
  });
  window.addEventListener('pagehide', () => save());

  // métricas de visitas en la web propia (Vercel Web Analytics; sin cookies)
  if (platform.name === 'web') import('@vercel/analytics').then((m) => m.inject({ mode: 'production' })).catch(() => {});
  document.getElementById('boot').remove();
  platform.loadingStop();

  // vuelta de Stripe
  try {
    const ret = await platform.consumeReturn();
    if (ret && app.grantProduct(ret.sku, ret.session)) {
      setTimeout(() => toast(t('purchaseDone', { name: L(PRODUCT[ret.sku].name) }), 'gold'), 600);
    }
  } catch (e) { /* sin backend */ }

  app.go('title');

  let last = performance.now();
  let inkTimer = 0;
  let pausedFrame = 0;
  const frame = (now) => {
    const dt = Math.min(0.1, (now - last) / 1000);
    last = now;
    pollInput();
    if (app.combat) {
      if (consume('pause') && !app.combat.paused) app.pause();
      app.combat.update(dt);
    } else {
      app.showcase.update(dt);
    }
    // en pausa (sellado, menús) el 3D se redibuja a menor ritmo para dar
    // todo el rendimiento al minijuego en móviles modestos
    pausedFrame = app.combat && app.combat.paused ? pausedFrame + 1 : 0;
    if (pausedFrame % 4 === 0) renderer.render(dt);
    clearPressed();
    inkTimer += dt;
    if (inkTimer > 5) {
      inkTimer = 0;
      tickInk();
      state.stats.playMs += 5000;
    }
    if (!capture) requestAnimationFrame(frame);
  };
  // ?capture=1: el juego avanza solo cuando se llama a window.__tick(dt) (grabar tráilers sin tirones)
  const capture = new URLSearchParams(location.search).has('capture');
  if (capture) {
    let vt = performance.now();
    window.__manual = [];
    window.__tick = (dt) => {
      vt += dt * 1000;
      last = vt - dt * 1000;
      frame(vt);
      const q = window.__manual.splice(0);
      for (const fn of q) fn(vt);
    };
  } else requestAnimationFrame(frame);
}

boot().catch((e) => {
  console.error(e);
  fail('Error: ' + (e && e.message ? e.message : e));
});

// depuración y pruebas automáticas
window.__sa = { app, state, input };
