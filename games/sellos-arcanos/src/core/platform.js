// Capa de plataforma: un mismo build funciona en la web propia (Vercel),
// CrazyGames, Poki, GameDistribution e itch.io. Se detecta por el dominio
// o con ?platform=crazygames|poki|gamedistribution|web en la URL.
//
// Anuncios: solo los del SDK del portal (requisito de los portales) o
// Google H5 Games Ads (adBreak) en la web propia si VITE_ADSENSE_CLIENT existe.
// Pagos: Stripe Checkout en la web propia (api/checkout.js + api/verify.js).

const params = new URLSearchParams(location.search);
const env = import.meta.env || {};

function detect() {
  const forced = params.get('platform');
  if (forced) return forced;
  const h = location.hostname + ' ' + document.referrer;
  if (/crazygames/.test(h)) return 'crazygames';
  if (/poki/.test(h)) return 'poki';
  if (/gamedistribution|gdgames/.test(h)) return 'gamedistribution';
  if (/itch\.io|itch\.zone|hwcdn/.test(h)) return 'itch';
  return env.VITE_PLATFORM || 'web';
}

function loadScript(src) {
  return new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = src;
    s.async = true;
    s.onload = resolve;
    s.onerror = reject;
    document.head.appendChild(s);
  });
}

const hooks = { pause: () => {}, resume: () => {} };
const API_BASE = env.VITE_API_BASE || '';
const ADSENSE = env.VITE_ADSENSE_CLIENT || '';
const fakeAds = params.has('fakeads');

let lastInterstitial = Date.now();
const INTERSTITIAL_GAP = 180000; // 3 minutos entre anuncios no opcionales

export const platform = {
  name: detect(),
  sdk: null,
  adsReady: false,
  iapReady: false,
  noAds: false, // comprado «Sin anuncios» (solo web propia)

  setHooks(h) { Object.assign(hooks, h); },

  async init() {
    try {
      if (this.name === 'crazygames') {
        await loadScript('https://sdk.crazygames.com/crazygames-sdk-v3.js');
        await window.CrazyGames.SDK.init();
        this.sdk = window.CrazyGames.SDK;
        this.adsReady = this.sdk.environment !== 'disabled';
      } else if (this.name === 'poki') {
        await loadScript('https://game-cdn.poki.com/scripts/v2/poki-sdk.js');
        await window.PokiSDK.init();
        this.sdk = window.PokiSDK;
        this.adsReady = true;
      } else if (this.name === 'gamedistribution') {
        await new Promise((resolve) => {
          window.GD_OPTIONS = {
            gameId: env.VITE_GD_GAME_ID || '',
            onEvent: (ev) => {
              if (ev.name === 'SDK_READY') resolve();
              if (ev.name === 'SDK_GAME_PAUSE') hooks.pause();
              if (ev.name === 'SDK_GAME_START') hooks.resume();
            },
          };
          loadScript('https://html5.api.gamedistribution.com/main.min.js').catch(resolve);
          setTimeout(resolve, 5000);
        });
        this.sdk = window.gdsdk;
        this.adsReady = !!this.sdk;
      } else if (this.name === 'web' && ADSENSE) {
        window.adsbygoogle = window.adsbygoogle || [];
        window.adBreak = window.adConfig = function (o) { window.adsbygoogle.push(o); };
        const s = document.createElement('script');
        s.async = true;
        s.dataset.adClient = ADSENSE;
        if (env.DEV) s.dataset.adbreakTest = 'on';
        s.src = 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=' + ADSENSE;
        s.crossOrigin = 'anonymous';
        document.head.appendChild(s);
        window.adConfig({ preloadAdBreaks: 'on', sound: 'on' });
        this.adsReady = true;
      }
    } catch (e) {
      console.warn('SDK de plataforma no disponible', e);
      this.sdk = null;
      this.adsReady = false;
    }
    if (fakeAds) this.adsReady = true;
    if (this.name === 'web' || this.name === 'itch') {
      try {
        const r = await fetch(API_BASE + '/api/checkout', { method: 'GET' });
        const j = await r.json();
        this.iapReady = !!j.enabled;
      } catch (e) {
        this.iapReady = false;
      }
    }
  },

  // --- ciclo de juego (lo piden los portales para medir y colocar anuncios)
  loadingStart() { if (this.name === 'crazygames') this.sdk?.game?.loadingStart?.(); },
  loadingStop() {
    if (this.name === 'crazygames') this.sdk?.game?.loadingStop?.();
    if (this.name === 'poki') this.sdk?.gameLoadingFinished?.();
  },
  gameplayStart() {
    if (this.name === 'crazygames') this.sdk?.game?.gameplayStart?.();
    if (this.name === 'poki') this.sdk?.gameplayStart?.();
  },
  gameplayStop() {
    if (this.name === 'crazygames') this.sdk?.game?.gameplayStop?.();
    if (this.name === 'poki') this.sdk?.gameplayStop?.();
  },
  happytime() { if (this.name === 'crazygames') this.sdk?.game?.happytime?.(); },

  // --- guardado en la nube (CrazyGames lo sincroniza con la cuenta)
  async storageGet(key) {
    if (this.name === 'crazygames' && this.sdk?.data) return this.sdk.data.getItem(key);
    return null;
  },
  async storageSet(key, value) {
    if (this.name === 'crazygames' && this.sdk?.data) this.sdk.data.setItem(key, value);
  },

  // --- anuncios
  hasRewarded() { return this.adsReady; },

  // Devuelve true si el jugador vio el anuncio completo y merece el premio.
  rewarded() {
    if (!this.adsReady) return Promise.resolve(false);
    hooks.pause();
    const done = (ok) => { hooks.resume(); lastInterstitial = Date.now(); return ok; };
    if (fakeAds) return new Promise((r) => setTimeout(() => r(done(true)), 1200));
    if (this.name === 'crazygames') {
      return new Promise((resolve) => {
        this.sdk.ad.requestAd('rewarded', {
          adStarted: () => {},
          adFinished: () => resolve(done(true)),
          adError: () => resolve(done(false)),
        });
      });
    }
    if (this.name === 'poki') {
      return this.sdk.rewardedBreak(() => {}).then((ok) => done(!!ok)).catch(() => done(false));
    }
    if (this.name === 'gamedistribution') {
      return this.sdk.showAd('rewarded').then(() => done(true)).catch(() => done(false));
    }
    if (this.name === 'web' && ADSENSE) {
      return new Promise((resolve) => {
        let granted = false;
        window.adBreak({
          type: 'reward',
          name: 'reward',
          beforeReward: (showAdFn) => showAdFn(),
          adViewed: () => { granted = true; },
          adDismissed: () => { granted = false; },
          adBreakDone: () => resolve(done(granted)),
        });
      });
    }
    return Promise.resolve(done(false));
  },

  // Anuncio entre partidas: como mucho uno cada 3 minutos y nunca a mitad de combate.
  interstitial() {
    if (!this.adsReady || this.noAds || fakeAds) return Promise.resolve();
    if (Date.now() - lastInterstitial < INTERSTITIAL_GAP) return Promise.resolve();
    lastInterstitial = Date.now();
    hooks.pause();
    const done = () => hooks.resume();
    if (this.name === 'crazygames') {
      return new Promise((resolve) => {
        this.sdk.ad.requestAd('midgame', { adStarted: () => {}, adFinished: () => { done(); resolve(); }, adError: () => { done(); resolve(); } });
      });
    }
    if (this.name === 'poki') return this.sdk.commercialBreak(() => {}).then(done, done);
    if (this.name === 'gamedistribution') return this.sdk.showAd().then(done, done);
    if (this.name === 'web' && ADSENSE) {
      return new Promise((resolve) => {
        window.adBreak({ type: 'next', name: 'between_runs', adBreakDone: () => { done(); resolve(); } });
      });
    }
    done();
    return Promise.resolve();
  },

  // --- pagos con dinero real (web propia + Stripe)
  canBuy() { return this.iapReady; },

  async buy(sku, lang) {
    const r = await fetch(API_BASE + '/api/checkout', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ sku, lang, returnUrl: location.href.split('?')[0].split('#')[0] }),
    });
    const j = await r.json();
    if (!r.ok || !j.url) throw new Error(j.error || 'checkout');
    location.href = j.url;
  },

  // Al volver de Stripe: ?purchase=ok&session_id=cs_...
  async consumeReturn() {
    const sid = params.get('session_id');
    if (!sid || params.get('purchase') !== 'ok') return null;
    history.replaceState(null, '', location.pathname);
    const r = await fetch(API_BASE + '/api/verify?session_id=' + encodeURIComponent(sid));
    const j = await r.json();
    if (!j.paid) return null;
    return { sku: j.sku, session: sid };
  },
};
