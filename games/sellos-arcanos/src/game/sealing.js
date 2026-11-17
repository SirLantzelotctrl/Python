// Minijuego de sellado: une los nodos de la runa en orden antes de que el
// círculo se apague. Trazo perfecto: sin errores y con tiempo de sobra.
import { sfx } from '../core/audio.js';
import { input } from '../engine/input.js';
import { t } from '../core/i18n.js';

function gcd(a, b) { return b ? gcd(b, a % b) : a; }

// Runa: N nodos alrededor del círculo recorridos como un polígono estrellado.
function runePoints(n, seed) {
  let s = seed;
  const rnd = () => ((s = (s * 9301 + 49297) % 233280) / 233280);
  let k = Math.max(1, Math.floor(n / 2) - (n % 2 === 0 ? 1 : 0));
  while (gcd(n, k) !== 1 && k > 1) k--;
  const rot = rnd() * Math.PI * 2;
  const pts = [];
  for (let i = 0; i < n; i++) {
    const idx = (i * k) % n;
    const a = rot + (idx / n) * Math.PI * 2;
    const r = 0.5 + rnd() * 0.32;
    pts.push({ bx: Math.cos(a) * r, by: Math.sin(a) * r, ph: rnd() * 10 });
  }
  return pts;
}

const schedule = (fn) => (window.__manual ? window.__manual.push(fn) : requestAnimationFrame(fn));

export function openSealing({ root, color, name, nodes, moving, time = 5, boss = false, ink, onDone }) {
  const el = document.createElement('div');
  el.className = 'sealing';
  el.innerHTML = `
    <canvas></canvas>
    <div class="seal-head">
      <span class="eyebrow" style="color:${color}">${t('sealing')}</span>
      <h1>${t('traceSeal', { name })}</h1>
      <p>${t('traceHelp')}</p>
    </div>
    <div class="seal-side seal-left">${boss ? '' : `<span class="eyebrow">${t('ink')}</span><div class="big num">${ink}<small> / 10</small> <em>−1</em></div><p>${t('inkHelp')}</p>`}</div>
    <div class="seal-side seal-right"><span class="eyebrow">${t('time')}</span><div class="big num timer" style="text-shadow:0 0 22px ${color}">${time.toFixed(1)} s</div><div class="bar"><i style="background:${color}"></i></div><p>${t('struggle')}</p></div>
    <div class="seal-result"></div>`;
  root.appendChild(el);
  const cv = el.querySelector('canvas');
  const ctx = cv.getContext('2d');
  const timerEl = el.querySelector('.timer');
  const barEl = el.querySelector('.bar i');
  const resEl = el.querySelector('.seal-result');
  const pts = runePoints(nodes, Math.floor(Math.random() * 100000));
  const state = { idx: 0, errors: 0, left: time, done: false, down: false, px: 0, py: 0, intro: 0.45, shake: 0, flash: 0 };
  let W = 0, H = 0, R = 0, cx = 0, cy = 0, dpr = 1;
  const resize = () => {
    dpr = Math.min(2, window.devicePixelRatio || 1);
    W = el.clientWidth; H = el.clientHeight;
    cv.width = W * dpr; cv.height = H * dpr;
    cv.style.width = W + 'px'; cv.style.height = H + 'px';
    R = Math.min(W, H) * (W < 700 || H < 500 ? 0.4 : 0.34);
    cx = W / 2; cy = H / 2 + (H < 500 ? 12 : 30);
  };
  resize();
  window.addEventListener('resize', resize);

  const nodePos = (p, tt) => {
    let x = cx + p.bx * R;
    let y = cy + p.by * R;
    const tremble = boss ? 3.5 : 2.5;
    x += Math.sin(tt * 37 + p.ph) * tremble;
    y += Math.cos(tt * 41 + p.ph) * tremble;
    if (moving) {
      x += Math.sin(tt * 0.9 + p.ph) * R * 0.08;
      y += Math.cos(tt * 0.7 + p.ph * 2) * R * 0.08;
    }
    return [x, y];
  };
  const hitR = () => Math.max(26, R * 0.09);
  let tt = 0;
  const path = [];

  const finish = (result) => {
    if (state.done) return;
    state.done = true;
    window.__seal = null;
    if (result === 'perfect') sfx.sealPerfect();
    else if (result === 'ok') sfx.sealOk();
    else sfx.sealFail();
    resEl.innerHTML = `<div class="res ${result}">${result === 'perfect' ? t('perfectTrace') : result === 'ok' ? t('sealed') : t('sealResists')}</div>${result === 'perfect' ? `<p>${t('perfectBonus')}</p>` : ''}`;
    resEl.classList.add('on');
    setTimeout(() => {
      window.removeEventListener('resize', resize);
      if (!window.__manual) cancelAnimationFrame(raf);
      state.stopped = true;
      el.classList.add('out');
      setTimeout(() => el.remove(), 300);
      onDone(result);
    }, result === 'fail' ? 1100 : 1300);
  };

  const tryNode = (x, y) => {
    for (let i = 0; i < pts.length; i++) {
      if (i < state.idx) continue;
      const [nx, ny] = nodePos(pts[i], tt);
      if (Math.hypot(nx - x, ny - y) < hitR()) {
        if (i === state.idx) {
          state.idx++;
          path.push(i);
          sfx.sealNode(state.idx);
          if (state.idx >= pts.length) {
            const perfect = state.errors === 0 && state.left / time >= (boss ? 0.3 : 0.4);
            finish(perfect ? 'perfect' : 'ok');
          }
        } else if (i > state.idx && !state.lastWrong?.includes(i)) {
          state.errors++;
          state.shake = 0.3;
          state.flash = 1;
          state.lastWrong = [i];
          sfx.error();
          if (state.errors >= 3) finish('fail');
        }
        return;
      }
    }
    state.lastWrong = null;
  };

  const local = (e) => {
    const r = cv.getBoundingClientRect();
    return [e.clientX - r.left, e.clientY - r.top];
  };
  cv.addEventListener('pointerdown', (e) => {
    if (state.done) return;
    cv.setPointerCapture(e.pointerId);
    state.down = true;
    [state.px, state.py] = local(e);
    tryNode(state.px, state.py);
  });
  cv.addEventListener('pointermove', (e) => {
    if (!state.down || state.done) return;
    [state.px, state.py] = local(e);
    tryNode(state.px, state.py);
  });
  const up = () => { state.down = false; };
  cv.addEventListener('pointerup', up);
  cv.addEventListener('pointercancel', up);

  // también se puede trazar con WASD / flechas / stick: mueve un cursor
  let useStick = false;
  let last = performance.now();
  let raf = 0;
  const frame = (now) => {
    if (state.stopped) return;
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    tt += dt;
    if (state.intro > 0) state.intro -= dt;
    else if (!state.done) {
      state.left -= dt;
      if (state.left <= 0) { state.left = 0; finish('fail'); }
    }
    const m = input.move;
    if (Math.hypot(m.x, m.y) > 0.2 && !state.done) {
      if (!useStick) {
        useStick = true;
        const p0 = pts[Math.max(0, state.idx - 1)];
        [state.px, state.py] = state.idx ? nodePos(p0, tt) : [cx, cy];
      }
      state.px += m.x * dt * Math.max(500, R * 2.2);
      state.py += m.y * dt * Math.max(500, R * 2.2);
      tryNode(state.px, state.py);
    }
    timerEl.textContent = state.left.toFixed(1).replace('.', t('decimal')) + ' s';
    barEl.style.width = (state.left / time) * 100 + '%';
    draw();
    raf = schedule(frame);
  };

  const draw = () => {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, W, H);
    const sx = state.shake > 0 ? (Math.random() - 0.5) * 10 : 0;
    state.shake = Math.max(0, state.shake - 0.016);
    state.flash = Math.max(0, state.flash - 0.05);
    ctx.save();
    ctx.translate(sx, 0);
    const k = Math.max(0, Math.min(1, 1 - state.intro / 0.45));
    ctx.globalAlpha = k;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    // anillos
    ctx.strokeStyle = color;
    ctx.globalAlpha = k * 0.16;
    ctx.lineWidth = 5;
    ctx.beginPath(); ctx.arc(cx, cy, R * 1.04, 0, Math.PI * 2); ctx.stroke();
    ctx.globalAlpha = k;
    ctx.shadowColor = color;
    ctx.shadowBlur = 16;
    ctx.beginPath(); ctx.arc(cx, cy, R * 1.04, -Math.PI / 2, -Math.PI / 2 + (state.left / time) * Math.PI * 2); ctx.stroke();
    ctx.shadowBlur = 0;
    ctx.globalAlpha = k * 0.5;
    ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.arc(cx, cy, R * 0.99, 0, Math.PI * 2); ctx.stroke();
    ctx.setLineDash([1.5, R * 0.12]);
    ctx.lineWidth = 9;
    ctx.globalAlpha = k * 0.45;
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(tt * 0.2);
    ctx.beginPath(); ctx.arc(0, 0, R * 0.96, 0, Math.PI * 2); ctx.stroke();
    ctx.restore();
    ctx.setLineDash([2, 10]);
    ctx.lineWidth = 1;
    ctx.globalAlpha = k * 0.3;
    ctx.beginPath(); ctx.arc(cx, cy, R * 0.92, 0, Math.PI * 2); ctx.stroke();
    ctx.setLineDash([]);
    ctx.globalAlpha = k * 0.18;
    ctx.beginPath(); ctx.arc(cx, cy, R * 0.4, 0, Math.PI * 2); ctx.stroke();
    // camino pendiente (guía punteada)
    const P = pts.map((p) => nodePos(p, tt));
    ctx.globalAlpha = k * 0.4;
    ctx.lineWidth = 2;
    ctx.setLineDash([5, 9]);
    ctx.beginPath();
    for (let i = Math.max(0, state.idx - 1); i < P.length; i++) (i === Math.max(0, state.idx - 1) ? ctx.moveTo : ctx.lineTo).call(ctx, P[i][0], P[i][1]);
    ctx.stroke();
    ctx.setLineDash([]);
    // trazo hecho
    if (state.idx > 0) {
      ctx.globalAlpha = k * 0.32;
      ctx.lineWidth = 18;
      ctx.beginPath();
      for (let i = 0; i < state.idx; i++) (i ? ctx.lineTo : ctx.moveTo).call(ctx, P[i][0], P[i][1]);
      if (state.down || useStick) ctx.lineTo(state.px, state.py);
      ctx.stroke();
      ctx.globalAlpha = k;
      ctx.strokeStyle = '#ffffff';
      ctx.shadowColor = color;
      ctx.shadowBlur = 20;
      ctx.lineWidth = 4;
      ctx.stroke();
      ctx.shadowBlur = 0;
      ctx.strokeStyle = color;
    }
    // nodos
    ctx.font = `800 ${Math.max(13, R * 0.045)}px "Alegreya Sans", sans-serif`;
    for (let i = 0; i < P.length; i++) {
      const [x, y] = P[i];
      const done = i < state.idx;
      const next = i === state.idx;
      ctx.globalAlpha = k;
      if (next) {
        const pulse = 0.5 + Math.sin(tt * 8) * 0.5;
        ctx.globalAlpha = k * (0.5 + pulse * 0.5);
        ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(x, y, hitR() * 1.15, 0, Math.PI * 2); ctx.stroke();
        ctx.globalAlpha = k;
        ctx.fillStyle = '#06180e';
        ctx.lineWidth = 3.5;
        ctx.beginPath(); ctx.arc(x, y, hitR() * 0.6, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      } else if (done) {
        ctx.fillStyle = '#ffffff';
        ctx.lineWidth = 3;
        ctx.shadowColor = color; ctx.shadowBlur = 14;
        ctx.beginPath(); ctx.arc(x, y, hitR() * 0.48, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
        ctx.shadowBlur = 0;
      } else {
        ctx.globalAlpha = k * 0.7;
        ctx.fillStyle = '#06100c';
        ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(x, y, hitR() * 0.42, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      }
      ctx.globalAlpha = k * (done || next ? 1 : 0.6);
      ctx.fillStyle = '#f4f1fb';
      ctx.fillText(String(i + 1), x + hitR() * 0.75, y - hitR() * 0.6);
    }
    if (useStick || state.down) {
      ctx.globalAlpha = k;
      ctx.strokeStyle = '#f4f1fb';
      ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(state.px, state.py, 16, 0, Math.PI * 2); ctx.stroke();
      ctx.fillStyle = '#f4f1fb';
      ctx.beginPath(); ctx.arc(state.px, state.py, 4, 0, Math.PI * 2); ctx.fill();
    }
    if (state.flash > 0) {
      ctx.globalAlpha = state.flash * 0.25;
      ctx.fillStyle = '#ff3355';
      ctx.fillRect(-20, 0, W + 40, H);
    }
    ctx.restore();
  };
  raf = schedule(frame);
  // gancho para pruebas automáticas
  window.__seal = { nodes: () => pts.map((p) => nodePos(p, tt)), idx: () => state.idx, done: () => state.done };
}
