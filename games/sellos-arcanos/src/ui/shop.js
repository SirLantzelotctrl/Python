// Tienda (cristales, tintes, sellos, efectos, ofertas con anuncio) y Pase Arcano.
import { app } from '../app.js';
import { mount, on, ICON, currencies, toast, modal, img, confirmBuy, rewardText } from './ui.js';
import { t, L, fmt } from '../core/i18n.js';
import { state, save, today } from '../core/save.js';
import { CREATURE } from '../data/creatures.js';
import { TINTS, SEALS, EFFECTS, PRODUCTS, PASS_TIERS, PASS_XP_PER_TIER, PASS_PREMIUM_CRYSTALS } from '../data/shop.js';
import { passTier, claimPass, grant } from '../game/progression.js';
import { platform } from '../core/platform.js';
import { sfx } from '../core/audio.js';
import { watchAdForInk } from './menus.js';

const crystalPrice = (n) => `<span class="price">${ICON.crystal.replace('<svg', '<svg style="width:1.1em;height:1.1em"')} ${fmt(n)}</span>`;

export function shopScreen(params = {}) {
  let tab = params.tab || 'tints';
  app.showcase.setTeam([]);
  const render = () => {
    if (state.ads.date !== today()) { state.ads = { date: today(), ink: 0, chest: false }; save(); }
    const tabs = [['crystals', t('getCrystals')], ['tints', t('glowTints')], ['seals', t('sealDesigns')], ['effects', t('summonEffects')], ['free', t('freeOffers')]];
    let content = '';
    if (tab === 'crystals') {
      if (!platform.canBuy()) {
        content = `<div class="frm" style="--c:14px;padding:1.4rem;max-width:40rem;display:flex;flex-direction:column;gap:.6rem"><b style="color:var(--bright);font-size:1.2rem">${t('earnCrystals')}</b><p class="muted" style="margin:0">${t('earnCrystalsHelp')}</p></div>`;
      } else {
        content = `<div class="grid">${PRODUCTS.filter((p) => !(p.once && ((p.sku === 'fundador' && state.purchases.founder) || (p.sku === 'pase_premium' && state.pass.premium) || (p.sku === 'sin_anuncios' && state.purchases.noAds)))).filter((p) => !p.standaloneOnly || platform.name === 'web').map((p) => `
          <div class="item frm ${p.best ? 'featured' : ''}">
            <div class="art">${p.best ? `<span class="ribbon">${t('bestValue')}</span>` : p.tag ? `<span class="ribbon">${t('tag_' + p.tag)}</span>` : ''}
              ${p.sku === 'fundador' ? `<img src="${img('criaturas', state.team[0] || 'fenix')}" alt="">` : p.sku === 'pase_premium' ? `<img src="${img('tintes', 'hidra_eclipsedorado')}" alt="">` : `<span class="swatch" style="color:var(--crystal);background:radial-gradient(circle at 35% 30%, #ffd6f4, #ff4fd2 60%, #6b1a5a)"></span>`}</div>
            <h3>${L(p.name)}</h3>${p.desc ? `<p>${L(p.desc)}</p>` : ''}
            <button class="btn frm primary buy" data-action="iap" data-sku="${p.sku}">US$ ${p.usd.toFixed(2)}</button>
          </div>`).join('')}</div>`;
      }
    } else if (tab === 'tints') {
      const sorted = [...TINTS].sort((a, b) => (b.season ? 1 : 0) - (a.season ? 1 : 0) || (state.creatures[b.creature] ? 1 : 0) - (state.creatures[a.creature] ? 1 : 0));
      content = `<div class="grid">${sorted.map((x) => {
        const c = CREATURE[x.creature];
        const owned = state.cosmetics.tints.includes(x.id);
        const swatchBg = x.color === 'prisma' ? 'conic-gradient(#ff3d3d,#ffd76a,#3dff88,#2ff2d6,#4fb4ff,#b06bff,#ff4fd2,#ff3d3d)' : x.color === 'aurora' ? 'linear-gradient(135deg,#9fefff,#3dff88,#b06bff,#ff4fd2)' : x.color;
        return `<div class="item frm ${x.season ? 'featured' : ''}">
          <div class="art">${x.season ? `<span class="ribbon">${t('seasonEclipse')}</span>` : ''}${x.img ? `<img src="${img('tintes', x.img)}" alt="" loading="lazy">` : `<img src="${img('criaturas', x.creature)}" alt="" loading="lazy" style="filter:saturate(.2) brightness(.7)"><span class="swatch" style="position:absolute;width:30%;background:${swatchBg};color:${x.color.startsWith('#') ? x.color : '#fff'}"></span>`}</div>
          <h3>${L(x.name)}</h3><p>${t('tintFor', { name: L(c.name) })}</p>
          ${owned ? `<button class="btn frm off buy">${t('owned')}</button>` : `<button class="btn frm buy" data-action="buy" data-kind="tint" data-id="${x.id}">${crystalPrice(x.price)}</button>`}
        </div>`;
      }).join('')}</div>`;
    } else if (tab === 'seals') {
      content = `<div class="grid">${SEALS.map((s) => {
        const owned = state.cosmetics.seals.includes(s.id);
        const eq = state.cosmetics.seal === s.id;
        return `<div class="item frm ${s.season ? 'featured' : ''}">
          <div class="art" style="background:radial-gradient(circle,#1d1640,#0d0b1e)">${s.season ? `<span class="ribbon">${t('seasonEclipse')}</span>` : ''}<canvas data-seal="${s.id}" width="256" height="256" style="width:80%;height:80%"></canvas></div>
          <h3>${L(s.name)}</h3><p>${L(s.desc)}</p>
          ${owned ? `<button class="btn frm buy ${eq ? 'off' : 'accent'}" data-action="equip" data-kind="seal" data-id="${s.id}">${eq ? t('equipped') : t('equip')}</button>` : `<button class="btn frm buy" data-action="buy" data-kind="seal" data-id="${s.id}">${crystalPrice(s.price)}</button>`}
        </div>`;
      }).join('')}</div>`;
    } else if (tab === 'effects') {
      content = `<div class="grid">${EFFECTS.map((s) => {
        const owned = state.cosmetics.effects.includes(s.id);
        const eq = state.cosmetics.effect === s.id;
        return `<div class="item frm">
          <div class="art" style="background:radial-gradient(circle,#1d1640,#0d0b1e)"><span class="swatch" style="width:40%;color:#cbb8ff;background:radial-gradient(circle,#fff,#b06bff 60%,transparent 70%)"></span></div>
          <h3>${L(s.name)}</h3><p>${t('effectHelp')}</p>
          ${owned ? `<button class="btn frm buy ${eq ? 'off' : 'accent'}" data-action="equip" data-kind="effect" data-id="${s.id}">${eq ? t('equipped') : t('equip')}</button>` : `<button class="btn frm buy" data-action="buy" data-kind="effect" data-id="${s.id}">${crystalPrice(s.price)}</button>`}
        </div>`;
      }).join('')}</div>`;
    } else if (tab === 'free') {
      const adOk = platform.hasRewarded();
      content = `<div class="grid">
        <div class="item frm"><div class="art"><span class="swatch" style="color:var(--ink-blue);background:radial-gradient(circle,#dff6ff,#8fd8ff 60%,transparent 70%)"></span></div>
          <h3>+3 ${t('ink')}</h3><p>${t('adInkHelp', { n: 3 - state.ads.ink })}</p>
          <button class="btn frm buy ${adOk && state.ads.ink < 3 ? 'primary' : 'off'}" data-action="adInk">${ICON.ad} ${t('watchAd')}</button></div>
        <div class="item frm"><div class="art"><span style="width:45%;color:var(--gold)">${ICON.gift}</span></div>
          <h3>${t('dailyChest')}</h3><p>${t('dailyChestHelp')}</p>
          <button class="btn frm buy ${adOk && !state.ads.chest ? 'gold' : 'off'}" data-action="adChest">${state.ads.chest ? t('claimed') : `${ICON.ad} ${t('watchAd')}`}</button></div>
        <div class="item frm"><div class="art"><span style="width:45%;color:var(--crystal)">${ICON.book}</span></div>
          <h3>${t('bestiaryMilestones')}</h3><p>${t('bestiaryMilestonesHelp')}</p>
          <button class="btn frm buy" data-action="goBestiary">${t('bestiary')}</button></div>
      </div>
      ${adOk ? '' : `<p class="muted">${t('noAdsHere')}</p>`}`;
    }
    const el = mount(`
      <div class="topbar">
        <button class="back frm" data-action="back">${ICON.back}${t('menu')}</button>
        <h1 class="title" style="font-size:2.2rem">${t('shop')}</h1>
        ${currencies()}
      </div>
      <div class="tabs" role="tablist" style="margin:.8rem 0 .2rem">${tabs.map(([k, l]) => `<button class="tab ${tab === k ? 'on' : ''}" data-action="tab" data-t="${k}" role="tab" aria-selected="${tab === k}">${l}</button>`).join('')}</div>
      <div class="rules"><span>${t('rule1')}</span><span>${t('rule2')}</span><span>${t('rule3')}</span><span>${t('rule4')}</span></div>
      <div class="scroll" style="flex:1;min-height:0">${content}</div>`, 's-shop');
    drawSealPreviews(el);
    on(el, {
      back: () => app.go('menu'),
      tab: (b) => { tab = b.dataset.t; render(); },
      buy: (b) => app.buyCosmetic(b.dataset.kind, b.dataset.id, render),
      equip: (b) => {
        if (b.dataset.kind === 'seal') state.cosmetics.seal = b.dataset.id;
        else state.cosmetics.effect = b.dataset.id;
        save();
        sfx.shield();
        render();
      },
      iap: (b) => app.buyProduct(b.dataset.sku),
      adInk: async () => { await watchAdForInk(); render(); },
      adChest: async () => {
        const ok = await platform.rewarded();
        if (ok) {
          state.ads.chest = true;
          grant({ essence: 500, crystals: 5 });
          toast(t('claimedReward') + ' 500 + 5', 'gold');
          sfx.coin();
        } else toast(t('adUnavailable'));
        render();
      },
      goBestiary: () => app.go('bestiary'),
    });
  };
  render();
}

// vista previa 2D de los sellos (usa las mismas texturas que el 3D)
function drawSealPreviews(root) {
  root.querySelectorAll('canvas[data-seal]').forEach((cv) => {
    const id = cv.dataset.seal;
    const design = id === 'propio' ? 'hexagrama' : id;
    import('../engine/assets.js').then(({ assets }) => import('../engine/circles.js').then(({ MagicCircle }) => {
      const mc = new MagicCircle(design, '#cbb8ff', 1);
      const ctx = cv.getContext('2d');
      ctx.globalCompositeOperation = 'lighter';
      for (const layer of mc.layers) {
        const tex = layer.material.map;
        const src = tex && (tex.image || tex.source?.data);
        if (src) ctx.drawImage(src, 0, 0, 256, 256);
      }
      ctx.globalCompositeOperation = 'source-in';
      ctx.fillStyle = id === 'eclipse' ? '#ffd76a' : '#cbb8ff';
      ctx.fillRect(0, 0, 256, 256);
      mc.dispose();
      void assets;
    }));
  });
}

export function passScreen() {
  app.showcase.setTeam([]);
  const render = () => {
    const tier = passTier();
    const xpIn = state.pass.xp % PASS_XP_PER_TIER;
    const rewardLabel = (g) => {
      if (!g) return '';
      if (g.tint) return `${ICON.star}<span>${t('tint')}</span>`;
      if (g.seal) return `${ICON.seal}<span>${t('seal')}</span>`;
      if (g.effect) return `${ICON.star}<span>${t('effect')}</span>`;
      return `<span style="display:flex;flex-direction:column;gap:.2rem;align-items:center">${rewardText(g).split(' · ').map((x) => `<span style="display:flex;align-items:center;gap:.3rem">${x.replace('<svg', '<svg style="width:1.2em;height:1.2em"')}</span>`).join('')}</span>`;
    };
    const el = mount(`
      <div class="topbar">
        <button class="back frm" data-action="back">${ICON.back}${t('menu')}</button>
        <div style="display:flex;flex-direction:column;gap:.2rem;align-items:center;text-align:center">
          <span class="eyebrow" style="color:#c9a0ff">${t('season1')} · ${t('eclipse')}</span>
          <h1 class="title" style="font-size:2.2rem">${t('pass')}</h1>
        </div>
        ${currencies()}
      </div>
      <div style="display:flex;gap:1.4rem;align-items:center;flex-wrap:wrap;margin-top:1rem">
        <div style="display:flex;flex-direction:column;gap:.3rem;min-width:16rem;flex:1">
          <span style="font-weight:800;color:var(--bright)">${t('passLevel', { n: tier, m: PASS_TIERS.length })}</span>
          <div class="bar"><i style="width:${tier >= PASS_TIERS.length ? 100 : xpIn}%;background:#c9a0ff;color:#c9a0ff"></i></div>
          <span class="muted" style="font-size:.9rem">${t('passHelp')}</span>
        </div>
        ${state.pass.premium ? `<span class="eyebrow" style="color:var(--gold)">${ICON.check.replace('<svg', '<svg style="width:1.2em;height:1.2em;vertical-align:-.2em"')} ${t('premiumActive')}</span>` : `
          <button class="btn frm gold" data-action="premium">${t('unlockPremium')} · ${crystalPrice(PASS_PREMIUM_CRYSTALS)}</button>
          ${platform.canBuy() ? `<button class="btn frm" data-action="premiumIap">US$ 4.99</button>` : ''}`}
      </div>
      <div class="pass-track" style="flex:1;min-height:0;align-items:flex-start">
        <div class="tier" style="width:6rem;padding-top:1.6rem"><div class="slot" style="--bc:transparent;--bgc:transparent">${t('free')}</div><div class="slot" style="--bc:transparent;--bgc:transparent;color:var(--gold)">${t('premium')}</div></div>
        ${PASS_TIERS.map((tr) => {
          const reached = tier >= tr.n;
          const fc = state.pass.free.includes(tr.n);
          const pc = state.pass.prem.includes(tr.n);
          return `<div class="tier ${reached ? 'reached' : ''}">
            <span class="n">${tr.n}</span>
            <button class="slot frm ${fc ? 'claimed' : reached ? 'claimable' : ''}" ${reached && !fc ? `data-action="claim" data-n="${tr.n}" data-tr="free"` : ''}>${rewardLabel(tr.free)}</button>
            <button class="slot prem frm ${pc ? 'claimed' : reached && state.pass.premium ? 'claimable' : ''}" ${reached && state.pass.premium && !pc ? `data-action="claim" data-n="${tr.n}" data-tr="prem"` : ''}>${state.pass.premium ? '' : ICON.lock.replace('<svg', '<svg style="width:1rem;height:1rem;opacity:.6"')}${rewardLabel(tr.prem)}</button>
          </div>`;
        }).join('')}
      </div>`, 's-pass');
    on(el, {
      back: () => app.go('menu'),
      claim: (b) => {
        if (claimPass(+b.dataset.n, b.dataset.tr)) { sfx.coin(); render(); }
      },
      premium: async () => {
        if (state.crystals < PASS_PREMIUM_CRYSTALS) {
          toast(t('notEnoughCrystals'));
          app.go('shop', { tab: 'crystals' });
          return;
        }
        if (await confirmBuy(t('passPremium'), crystalPrice(PASS_PREMIUM_CRYSTALS))) {
          state.crystals -= PASS_PREMIUM_CRYSTALS;
          state.pass.premium = true;
          save();
          sfx.sealPerfect();
          render();
        }
      },
      premiumIap: () => app.buyProduct('pase_premium'),
    });
  };
  render();
}

export { modal };
