// Gran Bestiario (36 formas) y ficha de criatura: estadísticas,
// habilidades, evolución, entrenamiento, equipo y tintes.
import { app } from '../app.js';
import { mount, on, ICON, AB_ICON, currencies, toast, modal, img, $ } from './ui.js';
import { t, L, fmt } from '../core/i18n.js';
import { state, save } from '../core/save.js';
import { CREATURES, CREATURE, ELEMENTS, DOMAINS, ROLES, FORMS } from '../data/creatures.js';
import { ABILITIES } from '../data/abilities.js';
import { ISLANDS } from '../data/islands.js';
import { TINTS, TINT } from '../data/shop.js';
import { formsSealed, evolveInfo, evolve, train, trainCost, xpToNext, teamSize, computeStats, tintColor, MAX_LEVEL, bestiaryMilestones } from '../game/progression.js';
import { sfx } from '../core/audio.js';

export function bestiaryScreen(params = {}) {
  let filter = params.filter || 'all';
  app.showcase.setTeam([]);
  const render = () => {
    const list = CREATURES.filter((c) => {
      const b = state.bestiary[c.id];
      if (filter === 'owned') return !!state.creatures[c.id];
      if (filter === 'seen') return b.seen && !state.creatures[c.id];
      if (filter === 'unknown') return !b.seen;
      return true;
    });
    const counts = {
      owned: CREATURES.filter((c) => state.creatures[c.id]).length,
      seen: CREATURES.filter((c) => state.bestiary[c.id].seen && !state.creatures[c.id]).length,
      unknown: CREATURES.filter((c) => !state.bestiary[c.id].seen).length,
    };
    const el = mount(`
      <div class="topbar">
        <button class="back frm" data-action="back">${ICON.back}${t('menu')}</button>
        <div style="display:flex;flex-direction:column;gap:.2rem">
          <h1 class="title" style="font-size:2.2rem">${t('greatBestiary')}</h1>
          <span class="muted">${t('bestiarySub')}</span>
        </div>
        <div style="display:flex;flex-direction:column;align-items:flex-end;gap:.2rem">
          <span class="eyebrow">${t('sealedForms')}</span>
          <span class="title num" style="font-size:2.2rem">${formsSealed()}<small class="muted" style="font-size:1rem"> / 36</small></span>
        </div>
      </div>
      <div class="tabs" role="tablist" style="margin:.8rem 0">
        ${[['all', t('all')], ['owned', `${t('sealedF')} · ${counts.owned}`], ['seen', `${t('seenF')} · ${counts.seen}`], ['unknown', `${t('unknownF')} · ${counts.unknown}`]].map(([k, l]) => `<button class="tab ${filter === k ? 'on' : ''}" data-action="filter" data-f="${k}" role="tab" aria-selected="${filter === k}">${l}</button>`).join('')}
        <span class="muted" style="margin-left:auto;align-self:center;font-size:.9rem">${filter === 'owned' ? t('teamHelp', { n: teamSize() }) : t('titleHelp')}</span>
      </div>
      <div class="scroll" style="flex:1;min-height:0"><div class="grid">
        ${list.map((c) => {
          const b = state.bestiary[c.id];
          const own = state.creatures[c.id];
          const inTeam = state.team.includes(c.id);
          const name = b.seen ? L(c.name) : '???';
          return `<button class="beast frm" data-action="open" data-id="${c.id}" style="--el:${c.color};${own ? `--bc:color-mix(in srgb, ${c.color} 45%, #3b3658)` : ''}">
            <div class="img">${own ? `<img src="${img('criaturas', c.id)}" alt="" loading="lazy">` : `<img class="sil" src="${img('siluetas', c.id)}" alt="" loading="lazy" style="${b.seen ? 'opacity:.55' : ''}">`}
              ${inTeam ? `<span class="tag-team">${t('inTeam')}</span>` : ''}</div>
            <span class="no">Nº ${c.num}</span>
            <span class="nm">${name}</span>
            <span class="muted" style="font-size:.85rem">${own ? `${L(ELEMENTS[c.el])} · ${t('lvl')} ${own.level}` : b.seen ? t('seenNotSealed') : t('undiscovered')}</span>
            <div class="forms">${b.forms.map((f) => `<i class="${f ? 'on' : ''}"></i>`).join('')}<span class="muted" style="font-size:.8rem;margin-left:.4rem">${b.forms.filter(Boolean).length}/3</span></div>
          </button>`;
        }).join('')}
      </div></div>`, 's-bestiary');
    on(el, {
      back: () => app.go('menu'),
      filter: (b) => { filter = b.dataset.f; render(); },
      open: (b) => {
        const id = b.dataset.id;
        if (!state.bestiary[id].seen) { toast(t('notFoundYet', { isle: L(ISLANDS[CREATURE[id].island].name) })); return; }
        app.go('ficha', { id, from: filter });
      },
    });
  };
  render();
}

export function fichaScreen({ id, from }) {
  const c = CREATURE[id];
  const render = () => {
    const own = state.creatures[id];
    const form = own ? own.form : 0;
    const level = own ? own.level : 1;
    const glow = own ? tintColor(own.tint, c.color) : c.color;
    app.showcase.setSingle(id, { form, glow, seal: app.sealFor(id), offsetX: -1 });
    const st = computeStats(id, level, form);
    const evo = own ? evolveInfo(id) : null;
    const inTeam = state.team.includes(id);
    const tints = TINTS.filter((x) => x.creature === id);
    const statNames = [t('power'), t('defense'), t('agility'), t('magic')];
    const el = mount(`
      <div class="ficha-info">
        <div class="topbar" style="justify-content:flex-start">
          <button class="back frm" data-action="back">${ICON.back}${t('bestiary')}</button>
          <span class="eyebrow">Nº ${c.num}</span>
          <span class="el-pill" style="--el:${c.color}">${L(ELEMENTS[c.el])}</span>
        </div>
        <div class="scroll">
          <div style="display:flex;flex-direction:column;gap:.4rem">
            <span class="eyebrow" style="color:${c.color}">${t('domain')} ${L(DOMAINS[ELEMENTS[c.el].domain])} · ${L(ROLES[c.role])} · ${L(c.sub)}</span>
            <h1 class="title" style="font-size:3rem">${L(c.name)}</h1>
            <p class="lore" style="margin:0;font-size:1.15rem">${L(c.lore)}</p>
          </div>
          ${own ? `
          <div style="display:flex;gap:1.2rem;align-items:center;flex-wrap:wrap">
            <div style="display:flex;flex-direction:column;gap:.3rem;min-width:12rem;flex:1">
              <span style="font-weight:800;color:var(--bright)">${t('level')} ${level} · ${L(FORMS[form])}</span>
              <div class="bar"><i style="width:${level >= MAX_LEVEL ? 100 : (own.xp / xpToNext(level)) * 100}%;background:${c.color};color:${c.color}"></i></div>
              <span class="muted num" style="font-size:.85rem">${level >= MAX_LEVEL ? t('maxLevel') : `${fmt(own.xp)} / ${fmt(xpToNext(level))} ${t('xp')}`}</span>
            </div>
            <div style="display:flex;flex-direction:column;gap:.3rem"><span class="eyebrow">${t('bond')}</span><div class="bond" style="--el:${c.color}">${[1, 2, 3, 4, 5].map((n) => `<i class="${n <= own.bond ? 'on' : ''}"></i>`).join('')}</div></div>
          </div>
          <div class="actions">
            <button class="btn frm ${inTeam ? '' : 'accent'}" data-action="team" style="--accent:${c.color}">${inTeam ? t('removeFromTeam') : t('addToTeam')}</button>
            ${level < MAX_LEVEL ? `<button class="btn frm ${state.essence >= trainCost(level) ? '' : 'off'}" data-action="train">${t('train')} · ${ICON.essence.replace('<svg', '<svg style="width:1.1em;height:1.1em"')} ${fmt(trainCost(level))}</button>` : ''}
            ${evo ? `<button class="btn frm ${evo.ok ? 'gold' : 'off'}" data-action="evolve">${t('evolveTo', { f: L(FORMS[evo.to]) })}</button>` : ''}
          </div>
          ${evo && !evo.ok ? `<span class="muted" style="font-size:.9rem">${evo.to === 1 ? t('evoReq1', { have: evo.haveFrags, el: L(ELEMENTS[c.el]) }) : t('evoReq2', { isle: L(ISLANDS[c.island].name) })}</span>` : ''}
          ` : `<div class="frm" style="--c:12px;padding:1rem"><b style="color:var(--bright)">${t('notSealedYet')}</b><p class="muted" style="margin:.3rem 0 0">${t('livesIn', { isle: L(ISLANDS[c.island].name), n: c.island + 1 })}</p></div>`}
          <div style="display:flex;flex-direction:column;gap:.5rem">
            <span class="eyebrow">${t('stats300')}</span>
            <div class="stats">${c.stats.map((v, i) => `<span>${statNames[i]}</span><div class="bar"><i style="width:${v}%;background:${c.color};color:${c.color}"></i></div><span class="num" style="color:var(--bright);font-weight:700">${v}</span>`).join('')}
              <span>${t('hp')}</span><span></span><span class="num" style="color:var(--bright);font-weight:700">${fmt(st.hp)}</span></div>
          </div>
          <div style="display:flex;flex-direction:column;gap:.5rem">
            <span class="eyebrow">${t('abilities')}</span>
            <div class="ab-list">${ABILITIES[id].map((a) => {
              const lockedR = a.key === 'r' && form < 1;
              return `<div class="ab-row ${lockedR ? 'locked' : ''}"><span class="k frm" style="${a.key === 'f' ? `--bc:${c.color}` : ''}">${a.key.toUpperCase()}</span><div><b>${L(a.name)}</b>${a.key === 'f' ? ` <span style="color:${c.color}">· ${t('ultimate')}</span>` : ''}<br><span>${L(a.desc)}${lockedR ? ' · ' + t('unlocksAdult') : ''}</span></div></div>`;
            }).join('')}</div>
          </div>
          <div style="display:flex;flex-direction:column;gap:.5rem">
            <span class="eyebrow">${t('forms')}</span>
            <div class="form-steps" style="--el:${c.color}">${FORMS.map((f, i) => {
              const has = state.bestiary[id].forms[i];
              const sub = has ? (own && own.form === i ? t('currentForm') : t('sealedF')) : i === 0 ? t('notSealedYet') : i === 1 ? t('reqAdult') : t('reqPrimordial');
              return `<div class="form-step frm ${has ? 'on' : ''}"><b>${L(f)}</b><span>${sub}</span></div>`;
            }).join('')}</div>
          </div>
          ${own ? `<div style="display:flex;flex-direction:column;gap:.5rem">
            <span class="eyebrow">${t('glowTints')}</span>
            <div class="tint-row">
              <button class="tint ${!own.tint ? 'on' : ''}" style="background:${c.color}" data-action="tint" data-t="" aria-label="${t('original')}"></button>
              ${tints.map((x) => {
                const ownedT = state.cosmetics.tints.includes(x.id);
                const cls = x.color === 'prisma' ? 'prisma' : x.color === 'aurora' ? 'aurora' : '';
                return `<button class="tint ${cls} ${own.tint === x.id ? 'on' : ''} ${ownedT ? '' : 'lock'}" style="${cls ? '' : `background:${x.color}`}" data-action="tint" data-t="${x.id}" title="${L(x.name)}" aria-label="${L(x.name)}"></button>`;
              }).join('')}
            </div>
          </div>` : ''}
        </div>
      </div>
      <div class="ficha-right">
        ${currencies()}
        <span class="drag-hint">${ICON.globe.replace('<svg', '<svg style="width:1.2em;height:1.2em"')} ${t('dragToRotate')}</span>
      </div>`, 's-ficha');
    on(el, {
      back: () => app.go('bestiary', { filter: from }),
      team: () => {
        if (inTeam) {
          if (state.team.length <= 1) { toast(t('teamMin')); return; }
          state.team = state.team.filter((x) => x !== id);
        } else {
          if (state.team.length >= teamSize()) {
            toast(t('teamFull', { n: teamSize() }));
            return;
          }
          state.team.push(id);
          sfx.summon(c.el);
        }
        save();
        render();
      },
      train: () => {
        if (train(id)) { sfx.levelUp(); render(); } else sfx.error();
      },
      evolve: async () => {
        const info = evolveInfo(id);
        if (!info?.ok) return;
        const ok = await modal(t('evolve'), `<p>${t('evolveConfirm', { name: L(c.name), f: L(FORMS[info.to]) })}</p>`, [{ label: t('cancel'), value: false }, { label: t('evolve'), cls: 'gold', value: true }]);
        if (ok && evolve(id)) {
          sfx.sealPerfect();
          toast(t('evolved', { name: L(c.name), f: L(FORMS[info.to]) }), 'gold');
          bestiaryMilestones();
          render();
        }
      },
      tint: async (b) => {
        const tid = b.dataset.t;
        if (!tid || state.cosmetics.tints.includes(tid)) {
          own.tint = tid;
          save();
          app.showcase.setGlow(tintColor(tid, c.color));
          render();
          return;
        }
        // tinte no comprado: llevar a la tienda con vista previa
        app.showcase.setGlow(TINT[tid].color);
        const go = await modal(L(TINT[tid].name), `<p>${t('tintPreview', { name: L(c.name) })}</p>`, [{ label: t('close'), value: false }, { label: `${t('buy')} · ${TINT[tid].price}`, cls: 'primary', value: true }]);
        app.showcase.setGlow(tintColor(own.tint, c.color));
        if (go) app.buyCosmetic('tint', tid, () => render());
      },
    });
  };
  render();
}
