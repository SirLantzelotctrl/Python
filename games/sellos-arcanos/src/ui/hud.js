// HUD de combate (PC y móvil), avisos, pausa y pantalla de resultados.
import { app } from '../app.js';
import { mount, on, ICON, AB_ICON, toast, modal, img, $ } from './ui.js';
import { t, L, fmt } from '../core/i18n.js';
import { state } from '../core/save.js';
import { CREATURE, ELEMENTS, DOMAINS, FORMS, domainMult } from '../data/creatures.js';
import { press } from '../engine/input.js';
import { platform } from '../core/platform.js';
import { xpToNext } from '../game/progression.js';
import { contractText } from '../game/progression.js';
import { getLang } from '../core/i18n.js';

let root = null;
let refs = {};
let bannerTimer = 0;
let lastActive = null;

export function hudScreen(combat) {
  const uiEl = document.getElementById('ui');
  uiEl.innerHTML = '';
  root = document.createElement('div');
  root.className = 'hud';
  root.innerHTML = `
    <div class="self">
      <div class="portrait frm" data-el><div class="pclip"><img data-pimg alt=""></div></div>
      <div>
        <div class="bars">
          <div class="nm"><span data-pname></span><span class="num" data-plvl></span></div>
          <div class="bar"><i data-php style="background:var(--bright);color:var(--bright)"></i></div>
          <div class="lbl"><span>${t('hp')}</span><span class="num" data-phpt></span></div>
          <div class="bar en"><i data-pen style="background:var(--ink-blue);color:var(--ink-blue)"></i></div>
          <div class="bar sl"><i data-psl></i></div>
          <div class="lbl"><span>${t('energy')} · ${t('sealBar')}</span><span class="num" data-pslt></span></div>
        </div>
        <div class="bench" data-bench></div>
      </div>
    </div>
    <div class="target" data-target style="display:none">
      <div class="row"><span class="nm"><span class="diamond" data-tdot></span><span data-tname></span></span><span class="num muted" data-tlvl style="font-weight:700"></span></div>
      <div class="bar"><i data-thp></i></div>
      <div class="row"><span class="adv" data-tadv></span><span class="sealable" data-tseal></span></div>
    </div>
    <div class="tr">
      <div class="chip frm">${ICON.ink}<span class="sr">${t('ink')}</span><span class="num" data-ink></span></div>
      <button class="icon-btn frm" data-action="pause" aria-label="${t('pause')}">${ICON.pause}</button>
    </div>
    <div class="wave-info">
      <span class="eyebrow" data-wave></span>
      <span class="muted" style="font-size:.9rem" data-contract></span>
    </div>
    <div class="joy-hint">${t('move')}</div>
    <div class="abilities" data-abs></div>
    <div class="seal-prompt" data-sealp style="display:none">
      <button class="btn frm" data-action="seal">${ICON.seal} ${t('traceSealBtn')}</button>
      <small data-sealsub></small>
    </div>
    <div data-banner></div>
    <span class="swipe-hint">${t('swipeDodge')}</span>`;
  uiEl.appendChild(root);
  refs = {};
  root.querySelectorAll('*').forEach((n) => {
    for (const a of n.getAttributeNames()) if (a.startsWith('data-') && !['data-action', 'data-k'].includes(a)) refs[a.slice(5)] = n;
  });
  on(root, {
    pause: () => app.pause(),
    seal: () => press('seal'),
    ab: (b) => press(b.dataset.k),
    sw: (b) => press('sw' + b.dataset.i),
  });
  // los botones de habilidad responden al tocar (sin esperar al clic)
  root.addEventListener('pointerdown', (e) => {
    const b = e.target.closest('[data-k]');
    if (b && e.pointerType !== 'mouse') { e.preventDefault(); press(b.dataset.k); }
  });
  lastActive = null;
  updateHud(combat);
}

function buildAbilities(p) {
  const abs = p.abilities;
  const html = ['q', 'e', 'r'].map((k) => {
    const a = abs.find((x) => x.key === k);
    const locked = !p.hasAbility(k);
    return `<button class="ab frm ${locked ? 'locked' : ''}" data-action="ab" data-k="${k}" aria-label="${L(a.name)}" title="${L(a.name)} — ${L(a.desc)}">
      <span class="key">${k.toUpperCase()}</span>${AB_ICON[a.type] || AB_ICON.aoe}<span class="nm">${L(a.name)}</span><span class="cd" data-cd-${k} style="display:none"></span></button>`;
  }).join('');
  const f = abs.find((x) => x.key === 'f');
  refs.abs.innerHTML = `<button class="ab frm dodge" data-action="ab" data-k="dodge" aria-label="${t('dodge')}"><span class="key">${t('spaceShort')}</span>${AB_ICON.dash.replace('<path d="M20.5 5v14"/>', '')}<span class="cd" data-cd-dodge style="display:none"></span></button>${html}
    <button class="ab frm ult" data-action="ab" data-k="f" style="--el:${p.def.color}" aria-label="${L(f.name)}" title="${L(f.name)} — ${L(f.desc)}"><span class="fill"></span><span class="key" style="z-index:1">F</span><span style="z-index:1;display:flex">${AB_ICON.revive}</span><span class="nm" style="z-index:1">${L(f.name)}</span></button>`;
  refs.abs.querySelectorAll('[class^="cd"], .cd').forEach((n) => {
    for (const a of n.getAttributeNames()) if (a.startsWith('data-cd-')) refs['cd-' + a.slice(8)] = n;
  });
  refs.ult = refs.abs.querySelector('.ult');
}

function buildBench(c) {
  refs.bench.innerHTML = c.team.map((f, i) => `<button class="frm ${f.fainted ? 'fainted' : ''}" data-action="sw" data-i="${i + 1}" style="--bc:${f === c.player ? f.def.color : 'var(--line2)'}" aria-label="${t('switchTo', { name: L(f.def.name) })}">
    <div class="pclip" style="width:100%;height:100%;overflow:hidden;clip-path:polygon(6px 0,100% 0,100% calc(100% - 6px),calc(100% - 6px) 100%,0 100%,0 6px)"><img src="${img('criaturas', f.id)}" alt="" style="width:100%;height:100%;object-fit:cover;transform:scale(1.5)"></div>
    <span class="hp"><i style="width:${(f.hp / f.maxHp) * 100}%"></i></span><span class="k">${i + 1}</span></button>`).join('');
}

let benchSig = '';
export function updateHud(c) {
  if (!root || !c.player) return;
  const p = c.player;
  if (lastActive !== p) {
    lastActive = p;
    refs.el.style.setProperty('--el', p.def.color);
    refs.pimg.src = img('criaturas', p.id);
    refs.pname.textContent = L(p.def.name).split(' ')[0];
    refs.psl.style.background = p.def.color;
    refs.psl.style.color = p.def.color;
    buildAbilities(p);
  }
  refs.plvl.textContent = `${t('lvl')} ${p.level}`;
  refs.php.style.width = (p.hp / p.maxHp) * 100 + '%';
  refs.php.style.background = p.hp / p.maxHp < 0.3 ? 'var(--danger)' : 'var(--bright)';
  refs.phpt.textContent = `${fmt(p.hp)} / ${fmt(p.maxHp)}${p.shield > 1 ? ` (+${fmt(p.shield)})` : ''}`;
  refs.pen.style.width = p.energy + '%';
  refs.psl.style.width = p.seal + '%';
  refs.pslt.textContent = `${Math.floor(p.energy)} · ${Math.floor(p.seal)} %`;
  refs.ink.textContent = state.ink;
  const sig = c.team.map((f) => `${f.id}${f.fainted}${Math.round((f.hp / f.maxHp) * 20)}`).join() + c.player.id;
  if (sig !== benchSig) { benchSig = sig; buildBench(c); }
  for (const k of ['q', 'e', 'r']) {
    const el = refs['cd-' + k];
    if (!el) continue;
    const cd = p.cds[k];
    const a = p.ability(k);
    const noEnergy = p.energy < (a.cost || 0);
    el.style.display = cd > 0 || noEnergy ? 'flex' : 'none';
    el.textContent = cd > 0 ? Math.ceil(cd) : '';
  }
  if (refs['cd-dodge']) {
    refs['cd-dodge'].style.display = p.dodgeCd > 0 ? 'flex' : 'none';
    refs['cd-dodge'].textContent = '';
  }
  if (refs.ult) {
    refs.ult.style.setProperty('--p', p.seal + '%');
    refs.ult.classList.toggle('ready', p.seal >= 100);
  }
  // objetivo
  const tg = c.boss && c.boss.alive ? c.boss : c.currentTarget();
  if (tg && !tg.anchor) {
    refs.target.style.display = 'flex';
    refs.target.classList.toggle('boss', !!tg.boss);
    refs.tdot.style.color = tg.def.color;
    refs.tname.textContent = L(tg.def.name);
    refs.tlvl.textContent = `${t('lvl')} ${tg.level} · ${L(FORMS[tg.form])}`;
    refs.thp.style.width = (tg.hp / tg.maxHp) * 100 + '%';
    refs.thp.style.background = tg.def.color;
    refs.thp.style.color = tg.def.color;
    const m = domainMult(p.def.el, tg.def.el);
    const da = DOMAINS[ELEMENTS[p.def.el].domain];
    const db = DOMAINS[ELEMENTS[tg.def.el].domain];
    refs.tadv.className = 'adv ' + (m > 1 ? 'good' : m < 1 ? 'bad' : '');
    refs.tadv.textContent = m > 1 ? `${L(da)} ${t('beats')} ${L(db)} · +30 %` : m < 1 ? `${L(db)} ${t('beats')} ${L(da)} · −23 %` : `${L(da)} · ${L(db)}`;
    refs.tseal.textContent = tg.invuln ? t('shieldedAnchors', { n: c.anchors.length }) : tg.sealable ? t('sealable') : '';
  } else if (tg && tg.anchor) {
    refs.target.style.display = 'flex';
    refs.tname.textContent = t('runeAnchor');
    refs.tlvl.textContent = `${c.anchors.length} / 4`;
    refs.thp.style.width = (tg.hp / tg.maxHp) * 100 + '%';
    refs.tadv.textContent = '';
    refs.tseal.textContent = t('breakAnchors');
  } else refs.target.style.display = 'none';
  // aviso de sellado
  const s = c.nearestSealable();
  if (s && !c.over) {
    refs.sealp.style.display = 'flex';
    refs.sealsub.textContent = s.boss ? t('bossSealFree') : state.ink > 0 ? t('sealCost', { n: state.ink }) : t('noInk');
  } else refs.sealp.style.display = 'none';
  refs.wave.textContent = c.bossStage ? (c.boss ? L(c.boss.def.name) : '') : t('wave', { a: Math.min(c.waveIdx + 1, c.waveCount), b: c.waveCount });
  const ct = state.contracts.list.find((x) => !x.claimed && x.progress < x.goal);
  refs.contract.textContent = ct ? `${t('contract')}: ${contractText(ct, getLang())} · ${ct.progress}/${ct.goal}` : '';
}

export function showBanner(text, cls = '', dur = 1.6, sub = false) {
  if (!refs.banner) return;
  const isObj = typeof text === 'object';
  refs.banner.innerHTML = `<div class="banner ${cls}">${isObj ? L(text) : text}${sub && cls === 'boss' ? `<small>${t('primordial')}</small>` : sub && cls === 'ult' ? `<small>${t('ultimate')}</small>` : ''}</div>`;
  clearTimeout(bannerTimer);
  bannerTimer = setTimeout(() => { if (refs.banner) refs.banner.innerHTML = ''; }, dur * 1000);
}

export function hideHud() {
  root = null;
  refs = {};
  benchSig = '';
}

// --- resultados -------------------------------------------------------
export function resultsScreen(res) {
  app.showcase.setTeam([]);
  const r = res.rewards;
  const firstSealed = r.sealed[0];
  const sc = firstSealed ? CREATURE[firstSealed.id] : null;
  const title = res.victory ? (r.bossSealed ? t('primordialSealed') : t('expeditionDone')) : t('retreated');
  const el = mount(`
    <div class="results">
      <div class="hero">
        <span class="eyebrow" style="color:${sc ? sc.color : 'var(--gold)'}">${res.newEntries ? t('newEntry', { n: res.newEntries }) : res.victory ? t('victory') : t('withdrawal')}</span>
        <h1 class="title">${title}</h1>
        ${res.unlocked ? `<p style="margin:0;color:var(--gold);font-weight:800">${t('islandUnlocked', { isle: res.unlocked })}</p>` : ''}
        ${r.sealed.map((s) => {
          const c = CREATURE[s.id];
          return `<div class="sealed-card frm" style="--el:${c.color}"><img src="${img('criaturas', s.id)}" alt="">
            <div style="display:flex;flex-direction:column;gap:.2rem"><b style="color:var(--bright);font-size:1.1rem">${L(c.name)}</b>
            <span class="muted">${s.boss ? t('primordial') : L(FORMS[0])} · ${t('lvl')} ${s.level}${s.perfect ? ` · <b style="color:var(--gold)">${t('perfectTrace')}</b>` : ''}</span>
            <span class="muted" style="font-size:.85rem">${s.isNew ? `<b style="color:var(--ok)">${t('newCreature')}</b>` : t('duplicateBonus')}</span></div></div>`;
        }).join('')}
        <div style="display:flex;flex-direction:column;gap:.4rem;width:100%">
          <span class="eyebrow">${t('teamXp')}</span>
          ${res.xp.map((x) => `<div class="xp-row"><img src="${img('criaturas', x.id)}" alt="" style="clip-path:polygon(5px 0,100% 0,100% calc(100% - 5px),calc(100% - 5px) 100%,0 100%,0 5px)"><b style="color:var(--bright)">${L(CREATURE[x.id].name).split(' ')[0]}</b><span class="num muted">${t('lvl')} ${x.level}</span><span class="num" style="color:var(--bright)">+${fmt(x.xp)} ${t('xp')}</span>${x.ups ? `<span class="lvup">▲ ${x.ups}</span>` : ''}</div>`).join('')}
        </div>
      </div>
      <div style="display:flex;flex-direction:column;gap:1rem;justify-content:center">
        <div class="reward-list">
          <div class="reward frm"><span class="v num">+${fmt(res.essence)}</span><div class="t"><b>${t('essence')}</b><span>${r.perfect ? t('inclPerfect') : t('essenceHelp')}</span></div></div>
          ${res.fragments ? `<div class="reward frm"><span class="v num">+${res.fragments}</span><div class="t"><b>${t('fragments')}</b><span>${t('fragmentsHelp')}</span></div></div>` : ''}
          ${res.crystals ? `<div class="reward frm" style="--bc:var(--crystal)"><span class="v num">+${res.crystals}</span><div class="t"><b>${t('crystals')}</b><span>${t('firstClear')}</span></div></div>` : ''}
          <div class="reward frm"><span class="v num">+${res.passXp}</span><div class="t"><b>${t('passXp')}</b><span>${t('passXpHelp')}</span></div></div>
          ${res.contractsDone.map((c) => `<div class="reward frm" style="--bc:var(--ok)"><span class="v">${ICON.check.replace('<svg', '<svg style="width:2rem;height:2rem;color:var(--ok)"')}</span><div class="t"><b>${t('contractDone')}</b><span>${contractText(c, getLang())}</span></div></div>`).join('')}
        </div>
        <div class="actions">
          ${res.canDouble ? `<button class="btn frm gold" data-action="double">${ICON.ad} ${t('doubleEssence')}</button>` : ''}
          <button class="btn frm primary big" data-action="cont">${t('continue')}</button>
        </div>
      </div>
    </div>`, 's-results');
  on(el, {
    double: async (b) => {
      b.classList.add('off');
      const ok = await platform.rewarded();
      if (ok) {
        state.essence += res.essence;
        toast(t('doubled', { n: fmt(res.essence) }), 'gold');
        b.remove();
      } else { toast(t('adUnavailable')); b.classList.remove('off'); }
    },
    cont: async () => {
      await platform.interstitial();
      app.go(res.victory && r.bossSealed ? 'map' : 'menu', res.victory && r.bossSealed ? { sel: Math.min(state.islands.unlocked, 11) } : {});
    },
  });
}

export { xpToNext };
