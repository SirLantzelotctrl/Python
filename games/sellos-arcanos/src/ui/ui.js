// Utilidades de interfaz: montar pantallas, modales, avisos e iconos.
import { sfx } from '../core/audio.js';
import { t, fmt } from '../core/i18n.js';
import { state, inkNextMs, INK_MAX } from '../core/save.js';
import { url } from '../engine/assets.js';

export const $ = (sel, root = document) => root.querySelector(sel);
export const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
export const uiRoot = () => document.getElementById('ui');
export const img = (kind, id) => url(`assets/img/${kind}/${id}.webp`);
export const scene = (name) => url(`assets/img/escenas/${name}.webp`);

const S = (d, extra = '') => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" ${extra}>${d}</svg>`;

export const ICON = {
  essence: S('<path d="M12 2.5l6.5 9.5-6.5 9.5-6.5-9.5z"/><path d="M5.5 12h13"/><path d="M12 2.5v19"/>', 'style="color:var(--essence)"'),
  ink: S('<path d="M12 3c3.6 4.6 6 7.9 6 11.1a6 6 0 0 1-12 0C6 10.9 8.4 7.6 12 3z"/><path d="M9.5 13.5l2.5 3 2.5-3"/>', 'style="color:var(--ink-blue)"'),
  crystal: S('<path d="M12 2l6 4.5v8L12 22l-6-7.5v-8z"/><path d="M6 6.5l6 4 6-4"/><path d="M12 10.5V22"/>', 'style="color:var(--crystal)"'),
  frag: S('<path d="M12 3l7 9-7 9-7-9z"/><path d="M12 3v18"/>'),
  play: S('<circle cx="12" cy="12" r="9"/><path d="M12 6l4 6-4 6-4-6z"/>'),
  book: S('<path d="M5 4.5A1.5 1.5 0 0 1 6.5 3H19v15H6.5A1.5 1.5 0 0 0 5 19.5z"/><path d="M5 19.5A1.5 1.5 0 0 0 6.5 21H19v-3"/><path d="M12 7l2 3-2 3-2-3z"/>'),
  team: S('<circle cx="8" cy="9" r="3"/><circle cx="16" cy="9" r="3"/><path d="M3 20c0-3 2.5-5 5-5s5 2 5 5"/><path d="M11 20c0-3 2.5-5 5-5s5 2 5 5"/>'),
  shop: S('<path d="M5 8h14l-1.2 12H6.2z"/><path d="M9 8a3 3 0 0 1 6 0"/>'),
  pass: S('<path d="M4 8l4 3 4-6 4 6 4-3-2 11H6z"/>'),
  settings: S('<path d="M4 7h9"/><path d="M17 7h3"/><circle cx="15" cy="7" r="2"/><path d="M4 17h3"/><path d="M11 17h9"/><circle cx="9" cy="17" r="2"/>'),
  gift: S('<rect x="4" y="9" width="16" height="11" rx="1"/><path d="M4 13h16"/><path d="M12 9v11"/><path d="M12 9C10.5 5.5 7 5.5 7.5 8c.3 1 2 1 4.5 1z"/><path d="M12 9c1.5-3.5 5-3.5 4.5-1-.3 1-2 1-4.5 1z"/>'),
  arrow: S('<path d="M5 12h14"/><path d="M13 6l6 6-6 6"/>'),
  back: S('<path d="M19 12H5"/><path d="M11 6l-6 6 6 6"/>'),
  lock: S('<rect x="5" y="11" width="14" height="10" rx="1.5"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>'),
  pause: S('<path d="M9 5v14"/><path d="M15 5v14"/>'),
  star: S('<path d="M12 3l2.6 5.6 6.1.7-4.5 4.2 1.2 6L12 16.6l-5.4 2.9 1.2-6-4.5-4.2 6.1-.7z"/>'),
  ad: S('<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M10 9l5 3-5 3z"/>'),
  check: S('<path d="M5 12l5 5 9-10"/>'),
  close: S('<path d="M6 6l12 12"/><path d="M18 6L6 18"/>'),
  sound: S('<path d="M5 10v4h3l4 3V7L8 10z"/><path d="M16 9a4 4 0 0 1 0 6"/>'),
  swords: S('<path d="M4 4l10 10"/><path d="M4 4h4"/><path d="M4 4v4"/><path d="M20 4L10 14"/><path d="M20 4h-4"/><path d="M20 4v4"/><path d="M7 16l-3 3"/><path d="M17 16l3 3"/>'),
  dodge: S('<path d="M4 17c4 0 6-10 16-10"/><path d="M16 4l4 3-4 3"/>'),
  seal: S('<circle cx="12" cy="12" r="9"/><path d="M12 4l4.9 15.1L4 9.8h16L7.1 19.1z"/>'),
  heart: S('<path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/>'),
  globe: S('<circle cx="12" cy="12" r="9"/><path d="M3 12h18"/><path d="M12 3a14 14 0 0 1 0 18a14 14 0 0 1 0-18"/>'),
  fullscreen: S('<path d="M4 9V4h5"/><path d="M20 9V4h-5"/><path d="M4 15v5h5"/><path d="M20 15v5h-5"/>'),
};

// iconos de habilidades por tipo
export const AB_ICON = {
  melee: S('<path d="M4 7l2.5 8L9 7"/><path d="M9.5 7l2.5 10 2.5-10"/><path d="M15 7l2.5 8L20 7"/>'),
  projectile: S('<path d="M4 20L18 6"/><path d="M14 5h5v5"/><circle cx="6" cy="18" r="1"/>'),
  cone: S('<path d="M4 12l16-7v14z"/>'),
  aoe: S('<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3"/>'),
  dash: S('<path d="M3 12h12"/><path d="M11 6l6 6-6 6"/><path d="M3 8h5"/><path d="M3 16h5"/><path d="M20.5 5v14"/>'),
  heal: S('<path d="M12 5v14"/><path d="M5 12h14"/>'),
  shield: S('<path d="M12 3l7 3v6c0 4-3 7-7 9-4-2-7-5-7-9V6z"/>'),
  buff: S('<path d="M5 12h.01"/><path d="M9 9a4.2 4.2 0 0 1 0 6"/><path d="M12.5 6.5a8 8 0 0 1 0 11"/><path d="M16 4a11.5 11.5 0 0 1 0 16"/>'),
  zone: S('<ellipse cx="12" cy="16" rx="8" ry="3"/><path d="M8 15c0-4 2-6 2-9"/><path d="M14 15c0-3 2-5 1-8"/>'),
  strike: S('<path d="M13 2L5 14h6l-2 8 8-12h-6z"/>'),
  mines: S('<circle cx="7" cy="15" r="2.5"/><circle cx="17" cy="15" r="2.5"/><circle cx="12" cy="7" r="2.5"/>'),
  revive: S('<path d="M12 2.5c1.8 3.6 6 5 6 10.5a6 6 0 0 1-12 0c0-3 1.6-4.6 2.8-7 .9 2 2 3 3.2 3.2-.3-2.3-.7-4.6 0-6.7z"/>'),
};

export const SIGIL = `<svg viewBox="0 0 100 100" fill="none" stroke="#cbb8ff" stroke-width="2.2" aria-hidden="true" style="width:66%;height:66%"><circle cx="50" cy="50" r="46"/><circle cx="50" cy="50" r="40" stroke-dasharray="2 4"/><path d="M50 16L64.75 80.63 23.42 28.8 83.15 57.57H16.85L76.58 28.8 35.25 80.63z" stroke-linejoin="round"/><circle cx="50" cy="50" r="6"/></svg>`;

export function mount(html, cls = '') {
  const root = uiRoot();
  root.innerHTML = '';
  const div = document.createElement('div');
  div.className = 'screen ' + cls;
  div.innerHTML = html;
  root.appendChild(div);
  return div;
}

export function currencies() {
  const next = inkNextMs();
  const mins = Math.ceil(next / 60000);
  return `<div class="chips">
    <div class="chip frm" title="${t('essence')}">${ICON.essence}<span class="sr">${t('essence')}</span><span class="num">${fmt(state.essence)}</span></div>
    <div class="chip frm" title="${t('ink')}${next ? ' · +1 ' + t('inMin', { n: mins }) : ''}">${ICON.ink}<span class="sr">${t('ink')}</span><span class="num">${state.ink}</span><small>/ ${INK_MAX}</small></div>
    <button class="chip frm" data-go="shop:crystals" title="${t('crystals')}">${ICON.crystal}<span class="sr">${t('crystals')}</span><span class="num">${fmt(state.crystals)}</span><span style="color:var(--muted);font-weight:800">+</span></button>
  </div>`;
}

export function toast(text, cls = '') {
  const box = document.getElementById('toast');
  const d = document.createElement('div');
  d.className = 'toast frm ' + cls;
  d.textContent = text;
  box.appendChild(d);
  setTimeout(() => { d.style.opacity = '0'; d.style.transition = 'opacity .3s'; }, 2300);
  setTimeout(() => d.remove(), 2700);
}

// modal(html, [{label, cls, value}]) -> Promise(value)
export function modal(title, body, actions = [{ label: t('ok'), cls: 'primary', value: true }], opts = {}) {
  return new Promise((resolve) => {
    const root = document.getElementById('modal-root');
    const back = document.createElement('div');
    back.className = 'modal-back';
    back.innerHTML = `<div class="modal frm" role="dialog" aria-modal="true" aria-label="${title}">
      ${title ? `<h2>${title}</h2>` : ''}
      <div class="modal-body ${opts.scroll ? 'scroll' : ''}" style="display:flex;flex-direction:column;gap:.8rem">${body}</div>
      <div class="actions">${actions.map((a, i) => `<button class="btn frm ${a.cls || ''}" data-i="${i}">${a.label}</button>`).join('')}</div>
    </div>`;
    root.appendChild(back);
    const close = (v) => { back.remove(); resolve(v); };
    back.addEventListener('click', (e) => {
      const b = e.target.closest('[data-i]');
      if (b) { sfx.click(); close(actions[+b.dataset.i].value); }
      else if (e.target === back && opts.dismiss !== false) close(null);
    });
    opts.onMount?.(back);
    const first = back.querySelector('.btn.primary, .btn.gold') || back.querySelector('.btn');
    first?.focus();
  });
}

export function confirmBuy(name, priceHtml) {
  return modal(t('confirmBuy'), `<p>${t('confirmBuyBody', { name })}</p><p style="font-size:1.3rem;font-weight:800;color:var(--bright)">${priceHtml}</p>`, [
    { label: t('cancel'), value: false },
    { label: t('buy'), cls: 'primary', value: true },
  ]);
}

export function rewardText(g) {
  const parts = [];
  if (g.essence) parts.push(`${ICON.essence} ${fmt(g.essence)}`);
  if (g.ink) parts.push(`${ICON.ink} ${g.ink}`);
  if (g.crystals) parts.push(`${ICON.crystal} ${g.crystals}`);
  if (g.fragments) parts.push(`${ICON.frag} ${g.fragments}`);
  return parts.join(' · ');
}

// delegación de clics por data-action dentro de un nodo
export function on(root, handlers) {
  root.addEventListener('click', (e) => {
    const el = e.target.closest('[data-action]');
    if (!el || !root.contains(el)) return;
    const h = handlers[el.dataset.action];
    if (h) {
      sfx.click();
      h(el, e);
    }
  });
}
