// Título, elección de inicial, menú principal (Ciudadela), mapa del Velo,
// pantalla de carga, ajustes y pausa.
import { app } from '../app.js';
import { mount, on, ICON, SIGIL, currencies, toast, modal, img, scene, rewardText, $ } from './ui.js';
import { t, L, fmt, getLang, setLang } from '../core/i18n.js';
import { state, save, resetState, tickInk, addInk } from '../core/save.js';
import { CREATURE, CREATURES, STARTERS, ELEMENTS, DOMAINS, ROLES } from '../data/creatures.js';
import { ISLANDS, TIPS } from '../data/islands.js';
import { rankInfo, rankTitle, formsSealed, dailyStatus, claimDaily, ensureContracts, contractText, claimContract, teamSize, passTier, tintColor, bestiaryMilestones } from '../game/progression.js';
import { PASS_TIERS } from '../data/shop.js';
import { sfx, initAudio, setVolumes } from '../core/audio.js';
import { platform } from '../core/platform.js';

const VERSION = 'v1.0';

export function titleScreen() {
  app.showcase.setTeam([]);
  const el = mount(`
    <div style="margin-top:1.4rem">
      <h1 class="logo">${t('gameTitle')}</h1>
      <div class="tagline"><i></i><span>${t('tagline')}</span><i></i></div>
    </div>
    <div class="title-foot">
      <button class="btn frm primary big" data-action="play">${t('play')}</button>
      <span class="muted" style="letter-spacing:.08em">${t('pressStart')}</span>
    </div>
    <div class="title-top">
      <button class="icon-btn frm" data-action="lang" aria-label="${t('language')}" title="${t('language')}">${ICON.globe}</button>
      <button class="icon-btn frm" data-action="settings" aria-label="${t('settings')}">${ICON.settings}</button>
    </div>
    <div class="title-corner l"><span class="eyebrow" style="color:#c9a0ff">${t('season1')}</span><span class="title" style="font-size:1.6rem">${t('eclipse')}</span></div>
    <span class="title-corner r">${VERSION}</span>`, 's-title');
  el.style.backgroundImage = `url(${scene('arte_clave')})`;
  const go = () => {
    initAudio();
    if (!state.starterChosen) starterScreen();
    else app.go('menu');
  };
  on(el, {
    play: go,
    settings: () => settingsModal(),
    lang: () => { setLang(getLang() === 'es' ? 'en' : 'es'); state.settings.lang = getLang(); save(); titleScreen(); },
  });
  const key = (e) => {
    if (e.code === 'Enter' || e.code === 'Space') { document.removeEventListener('keydown', key); sfx.click(); go(); }
  };
  document.addEventListener('keydown', key);
  app.onLeave = () => document.removeEventListener('keydown', key);
}

export function starterScreen() {
  let sel = 1;
  app.showcase.setTeam(STARTERS.map((id) => ({ id, form: 1 })), 'starter');
  const render = () => {
    const el = mount(`
      <div style="display:flex;flex-direction:column;gap:.6rem;align-items:center">
        <span class="eyebrow">${t('orderWelcome')}</span>
        <h1 class="title" style="font-size:2.6rem">${t('chooseFirst')}</h1>
        <p class="muted" style="margin:0;max-width:42rem">${t('chooseFirstHelp')}</p>
      </div>
      <div style="display:flex;flex-direction:column;gap:1rem;align-items:center;width:100%">
        <div class="starter-cards">
          ${STARTERS.map((id, i) => {
            const c = CREATURE[id];
            return `<button class="starter-card frm ${i === sel ? 'sel' : ''}" data-action="pick" data-i="${i}" style="--el:${c.color}">
              <span class="eyebrow" style="color:${c.color}">${L(ELEMENTS[c.el])} · ${L(DOMAINS[ELEMENTS[c.el].domain])} · ${L(ROLES[c.role])}</span>
              <h3>${L(c.name)}</h3>
              <p>${L(c.lore)}</p>
            </button>`;
          }).join('')}
        </div>
        <div style="display:flex;gap:.8rem;align-items:center;flex-wrap:wrap;justify-content:center">
          <input class="name" maxlength="16" placeholder="${t('yourName')}" value="${state.name || ''}" aria-label="${t('yourName')}" style="width:16rem">
          <button class="btn frm primary big" data-action="ok">${t('bindPact')}</button>
        </div>
      </div>`, 's-starter');
    on(el, {
      pick: (b) => { sel = +b.dataset.i; sfx.summon(CREATURE[STARTERS[sel]].el); render(); },
      ok: () => {
        const id = STARTERS[sel];
        state.name = ($('input.name', el).value || '').trim().slice(0, 16) || t('defaultName');
        state.creatures[id] = { form: 0, level: 1, xp: 0, bond: 2, bondXp: 0, tint: '' };
        state.bestiary[id].seen = true;
        state.bestiary[id].forms[0] = true;
        state.team = [id];
        state.starterChosen = true;
        save();
        sfx.sealPerfect();
        app.startExpedition(0, { tutorial: true });
      },
    });
  };
  render();
}

function navItem(action, icon, label, sub, extra = '') {
  return `<button class="nav-item" data-action="${action}"><span class="ico">${icon}</span><span class="txt"><span class="lbl">${label}</span><span class="sub">${sub}</span></span>${extra}</button>`;
}

export function menuScreen() {
  tickInk();
  ensureContracts();
  const r = rankInfo();
  const title = rankTitle(r.rank);
  app.showcase.setTeam(state.team.map((id) => ({ id, form: state.creatures[id].form, glow: tintColor(state.creatures[id].tint, CREATURE[id].color), seal: app.sealFor(id) })));
  const next = Math.min(state.islands.unlocked, ISLANDS.length - 1);
  const daily = dailyStatus();
  const contracts = state.contracts.list;
  const passClaimable = PASS_TIERS.filter((tier) => tier.n <= passTier() && (!state.pass.free.includes(tier.n) || (state.pass.premium && !state.pass.prem.includes(tier.n)))).length;
  const contractsReady = contracts.filter((c) => c.progress >= c.goal && !c.claimed).length;
  const el = mount(`
    <div class="menu-left">
      <span class="brand">${t('gameTitle').toUpperCase()}</span>
      <div class="player-card">
        <div class="sigil frm">${SIGIL}</div>
        <div class="info">
          <div class="row"><span class="name">${escapeHtml(state.name || t('defaultName'))}</span><span class="num muted" style="font-weight:700">${t('rank')} ${r.rank}</span></div>
          <span class="eyebrow" style="color:#cbb8ff">${L(title)}</span>
          <div class="bar"><i style="width:${(r.xp / r.need) * 100}%;background:#cbb8ff;color:#cbb8ff"></i></div>
          <span class="num muted" style="font-size:.9rem">${fmt(r.xp)} / ${fmt(r.need)} ${t('xp')}</span>
        </div>
      </div>
      <nav class="nav scroll" aria-label="${t('mainMenu')}">
        <button class="nav-item frm play" data-action="play"><span class="ico">${ICON.play}</span><span class="txt"><span class="lbl">${t('play')}</span><span class="sub">${L(ISLANDS[next].name)} · ${t('chapter')} ${next + 1}</span></span>${ICON.arrow}</button>
        ${navItem('bestiary', ICON.book, t('bestiary'), t('formsSealed', { n: formsSealed() }))}
        ${navItem('team', ICON.team, t('team'), state.team.map((id) => L(CREATURE[id].name).split(' ')[0]).join(' · '))}
        ${navItem('shop', ICON.shop, t('shop'), t('shopSub'))}
        ${navItem('pass', ICON.pass, t('pass'), t('passSub', { n: passTier() }), passClaimable ? `<span class="badge">${passClaimable}</span>` : '')}
        ${navItem('settings', ICON.settings, t('settings'), t('settingsSub'))}
      </nav>
    </div>
    <div class="menu-right">
      ${currencies()}
      <div class="card daily frm">
        <span style="color:var(--gold);width:2.2rem;height:2.2rem;flex:none">${ICON.gift}</span>
        <div class="body"><span class="ttl">${t('dailyReward')}</span><span class="sub">${t('dayOf', { n: daily.day + 1 })} · ${rewardText(daily.reward)}</span></div>
        <button class="btn frm gold small ${daily.can ? '' : 'off'}" data-action="daily">${daily.can ? t('claim') : t('claimed')}</button>
      </div>
      ${!state.purchases.founder && platform.canBuy() ? `<button class="card frm offer-pill" data-go="shop:crystals"><span style="color:var(--crystal);width:2.2rem;height:2.2rem;flex:none">${ICON.crystal}</span><div class="body"><span class="ttl">${t('founderPack')}</span><span class="sub">${t('founderSub')}</span></div>${ICON.arrow}</button>` : ''}
      <div class="contracts frm">
        <div style="display:flex;justify-content:space-between;align-items:center"><span class="eyebrow">${t('dailyContracts')}</span>${contractsReady ? `<span class="badge">${contractsReady}</span>` : ''}</div>
        ${contracts.map((c, i) => `<div class="contract ${c.progress >= c.goal ? 'done' : ''}">
          <div class="top"><span>${contractText(c, getLang())}</span>${c.claimed ? `<span class="muted">${ICON.check.replace('<svg', '<svg style="width:1em;height:1em"')}</span>` : c.progress >= c.goal ? `<button class="btn frm small gold" data-action="contract" data-i="${i}">+${fmt(c.essence)}</button>` : `<span class="num muted">${c.progress}/${c.goal}</span>`}</div>
          <div class="bar thin"><i style="width:${(c.progress / c.goal) * 100}%;background:var(--ok);color:var(--ok)"></i></div>
        </div>`).join('')}
      </div>
      <div class="team-foot">
        <span class="eyebrow">${t('yourTeam')}</span>
        <button class="btn frm" data-action="leader">${t('viewLeader')}</button>
      </div>
    </div>`, 's-menu');
  on(el, {
    play: () => app.go('map'),
    bestiary: () => app.go('bestiary'),
    team: () => app.go('bestiary', { filter: 'owned' }),
    shop: () => app.go('shop'),
    pass: () => app.go('pass'),
    settings: () => settingsModal(),
    leader: () => app.go('ficha', { id: state.team[0] }),
    daily: () => {
      const r = claimDaily();
      if (r) { sfx.coin(); toast(t('claimedReward') + ' ' + rewardText(r).replace(/<svg[\s\S]*?<\/svg>/g, '').trim(), 'gold'); menuScreen(); }
    },
    contract: (b) => {
      if (claimContract(+b.dataset.i)) { sfx.coin(); menuScreen(); }
    },
  });
  // hitos del bestiario pendientes
  const ms = bestiaryMilestones();
  if (ms.length) setTimeout(() => toast(t('milestone', { n: ms[ms.length - 1].forms, c: ms.reduce((a, m) => a + m.crystals, 0) }), 'gold'), 600);
}

export function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

// posiciones de las islas alrededor de la Ciudadela (en % del mapa)
function islePos(i) {
  const a = -Math.PI / 2 + (i / 12) * Math.PI * 2;
  const rx = 40;
  const ry = 38;
  return [50 + Math.cos(a) * rx, 50 + Math.sin(a) * ry];
}

export function mapScreen(params = {}) {
  app.showcase.setTeam([]);
  let sel = params.sel ?? Math.min(state.islands.unlocked, ISLANDS.length - 1);
  const render = () => {
    const isl = ISLANDS[sel];
    const boss = CREATURE[isl.boss];
    const locked = sel > state.islands.unlocked;
    const cleared = state.islands.cleared.includes(sel);
    const el = mount(`
      <div class="topbar">
        <button class="back frm" data-action="back">${ICON.back}${t('menu')}</button>
        <div style="display:flex;flex-direction:column;align-items:center;gap:.2rem;text-align:center">
          <h1 class="title" style="font-size:2rem">${t('mapTitle')}</h1>
          <span class="muted">${t('mapSub')}</span>
        </div>
        ${currencies()}
      </div>
      <div class="map-wrap">
        <div class="map">
          <svg class="links" viewBox="0 0 100 100" preserveAspectRatio="none">
            ${ISLANDS.map((_, i) => { const [x, y] = islePos(i); return `<line x1="50" y1="50" x2="${x}" y2="${y}" stroke="${i <= state.islands.unlocked ? 'rgba(203,184,255,.35)' : 'rgba(87,81,122,.25)'}" stroke-width=".25" stroke-dasharray="1 1"/>`; }).join('')}
          </svg>
          <div class="citadel"><svg viewBox="0 0 100 100" fill="none" stroke="#cbb8ff" stroke-width="2"><circle cx="50" cy="50" r="44"/><circle cx="50" cy="50" r="36" stroke-dasharray="2 4"/><path d="M50 18L80 74H20z"/><path d="M50 82L20 26h60z"/></svg>${t('citadel')}</div>
          ${ISLANDS.map((s, i) => {
            const [x, y] = islePos(i);
            const c = CREATURE[s.boss];
            const lk = i > state.islands.unlocked;
            const cl = state.islands.cleared.includes(i);
            return `<button class="isle ${lk ? 'locked' : ''} ${i === sel ? 'sel' : ''}" style="left:${x}%;top:${y}%;--el:${c.color}" data-action="sel" data-i="${i}" aria-label="${L(s.name)}">
              <span class="gem"><i></i></span><span class="nm">${L(s.name)}</span><span class="lv">${t('islandN', { n: i + 1 })} · ${t('lvl')} ${s.levels[0]}–${s.levels[1]}${cl ? ' · ✓' : ''}</span></button>`;
          }).join('')}
        </div>
        <div class="isle-panel frm" style="--bc:${boss.color}">
          <span class="eyebrow" style="color:${boss.color}">${t('islandN', { n: sel + 1 })} · ${t('chapter')} ${sel + 1} · ${cleared ? t('completed') : locked ? t('locked') : t('inProgress')}</span>
          <h2 class="title" style="font-size:2rem">${L(isl.name)}</h2>
          <p class="lore" style="margin:0">${L(isl.desc)}</p>
          <div class="facts">
            <span>${t('primordial')}</span><span>${state.bestiary[isl.boss].seen ? L(boss.name) : '???'}</span>
            <span>${t('levels')}</span><span>${isl.levels[0]}–${isl.levels[1]}</span>
            <span>${t('element')}</span><span style="color:${boss.color}">${L(ELEMENTS[boss.el])}</span>
            <span>${t('creatures')}</span><span>${isl.pool.map((p) => state.bestiary[p].seen ? L(CREATURE[p].name).split(' ')[0] : '???').join(' · ')}</span>
            <span>${t('loot')}</span><span>${t('fragmentsOf', { el: L(ELEMENTS[boss.el]) })}</span>
          </div>
          ${locked ? `<button class="btn frm off">${ICON.lock} ${t('clearPrevious')}</button>` : `<button class="btn frm primary big" data-action="travel">${t('travel')}</button>`}
        </div>
      </div>`, 's-map');
    on(el, {
      back: () => app.go('menu'),
      sel: (b) => { sel = +b.dataset.i; render(); },
      travel: () => app.startExpedition(sel),
    });
  };
  render();
}

export function loadingScreen(islandIdx, onEnter) {
  const isl = ISLANDS[islandIdx];
  const boss = CREATURE[isl.boss];
  const tips = TIPS[getLang()];
  const tip = tips[Math.floor(Math.random() * tips.length)];
  const lore = CREATURES[Math.floor(Math.random() * CREATURES.length)];
  const el = mount(`
    <div class="loading-grid">
      <div>
        <span class="eyebrow">${t('travelingTo')}</span>
        <h1 class="title" style="font-size:3rem">${L(isl.name)}</h1>
        <span class="muted">${t('islandN', { n: islandIdx + 1 })} · ${t('levels')} ${isl.levels[0]}–${isl.levels[1]} · <b style="color:${boss.color}">${L(ELEMENTS[boss.el])}</b></span>
        <p class="lore" style="margin:0">${L(isl.desc)}</p>
      </div>
      <div><span class="eyebrow">${t('tip')}</span><p style="margin:0;color:var(--bright);font-size:1.05rem;line-height:1.4">${tip}</p></div>
      <div><span class="eyebrow">${t('fromBestiary')}</span><b style="color:var(--bright)">${state.bestiary[lore.id].seen ? L(lore.name) : '???'}</b><p class="lore" style="margin:0">${L(lore.lore)}</p></div>
      <div style="align-items:flex-end"><span class="eyebrow" style="color:var(--ok)">${t('islandReady')}</span><button class="btn frm primary big" data-action="enter">${t('enter')}</button></div>
    </div>`, 's-loading');
  el.style.backgroundImage = `url(${scene('carga')})`;
  on(el, { enter: onEnter });
  const key = (e) => { if (e.code === 'Enter' || e.code === 'Space') { document.removeEventListener('keydown', key); onEnter(); } };
  document.addEventListener('keydown', key);
  app.onLeave = () => document.removeEventListener('keydown', key);
}

export function settingsModal() {
  const s = state.settings;
  const body = `
    <div class="setting"><span>${t('language')}</span><div class="seg"><button data-lang="es" class="${getLang() === 'es' ? 'on' : ''}">Español</button><button data-lang="en" class="${getLang() === 'en' ? 'on' : ''}">English</button></div></div>
    <div class="setting"><span>${t('music')}</span><input type="range" min="0" max="1" step="0.05" value="${s.music}" data-vol="music" aria-label="${t('music')}"></div>
    <div class="setting"><span>${t('sounds')}</span><input type="range" min="0" max="1" step="0.05" value="${s.sfx}" data-vol="sfx" aria-label="${t('sounds')}"></div>
    <div class="setting"><span>${t('graphics')}</span><div class="seg">${['auto', 'low', 'medium', 'high'].map((q) => `<button data-q="${q}" class="${s.quality === q ? 'on' : ''}">${t('q_' + q)}</button>`).join('')}</div></div>
    <div class="setting"><span>${t('screenShake')}</span><div class="seg"><button data-shake="1" class="${s.shake ? 'on' : ''}">${t('yes')}</button><button data-shake="0" class="${!s.shake ? 'on' : ''}">${t('no')}</button></div></div>
    <div class="setting"><span>${t('fullscreen')}</span><button class="btn frm small" data-fs="1">${ICON.fullscreen}</button></div>
    <details><summary style="cursor:pointer;font-weight:700;color:var(--bright);min-height:44px;display:flex;align-items:center">${t('controls')}</summary>
      <div class="keys" style="margin-top:.5rem">
        <kbd>WASD</kbd><span>${t('k_move')}</span><kbd>Q E R</kbd><span>${t('k_abilities')}</span><kbd>F</kbd><span>${t('k_ult')}</span>
        <kbd>${t('space')}</kbd><span>${t('k_dodge')}</span><kbd>1 2 3</kbd><span>${t('k_switch')}</span><kbd>Tab</kbd><span>${t('k_target')}</span>
        <kbd>G</kbd><span>${t('k_seal')}</span><kbd>Esc</kbd><span>${t('k_pause')}</span>
      </div>
      <p class="muted" style="margin:.6rem 0 0;font-size:.9rem">${t('touchHelp')}</p>
    </details>
    <details><summary style="cursor:pointer;font-weight:700;color:var(--bright);min-height:44px;display:flex;align-items:center">${t('privacy')}</summary><p class="muted" style="font-size:.9rem">${t('privacyText')}</p></details>
    <button class="btn frm small" data-reset="1" style="align-self:flex-start;color:var(--danger)">${t('resetProgress')}</button>`;
  return modal(t('settings'), body, [{ label: t('close'), cls: 'primary', value: true }], {
    scroll: true,
    onMount: (root) => {
      root.addEventListener('input', (e) => {
        const k = e.target.dataset.vol;
        if (k) { s[k] = +e.target.value; setVolumes(s.music, s.sfx); save(); }
      });
      root.addEventListener('click', async (e) => {
        const b = e.target.closest('button');
        if (!b) return;
        if (b.dataset.lang) { setLang(b.dataset.lang); s.lang = b.dataset.lang; save(); root.remove(); app.refresh(); settingsModal(); }
        if (b.dataset.q) { s.quality = b.dataset.q; save(); app.renderer.setQuality(s.quality); root.querySelectorAll('[data-q]').forEach((x) => x.classList.toggle('on', x === b)); }
        if (b.dataset.shake) { s.shake = b.dataset.shake === '1'; save(); root.querySelectorAll('[data-shake]').forEach((x) => x.classList.toggle('on', x === b)); }
        if (b.dataset.fs) { if (!document.fullscreenElement) document.documentElement.requestFullscreen?.().catch(() => {}); else document.exitFullscreen?.(); }
        if (b.dataset.reset) {
          const ok = await modal(t('resetProgress'), `<p>${t('resetConfirm')}</p>`, [{ label: t('cancel'), value: false }, { label: t('reset'), cls: 'primary', value: true }]);
          if (ok) { resetState(); root.remove(); location.reload(); }
        }
      });
    },
  });
}

export function adInkOffer() {
  const can = platform.hasRewarded() && state.ads.ink < 3;
  return can;
}

export async function watchAdForInk() {
  const ok = await platform.rewarded();
  if (ok) {
    state.ads.ink++;
    addInk(3);
    toast(t('inkGained', { n: 3 }), 'good');
  } else toast(t('adUnavailable'));
  return ok;
}

export { teamSize };
