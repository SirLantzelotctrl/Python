// Audio 100 % sintetizado con WebAudio: coros suaves y sintetizadores,
// un motivo de cuatro notas por elemento, escala ascendente al trazar
// runas y acorde final en el trazo perfecto (documento de diseño).

let ctx = null;
let master, musicBus, sfxBus, reverb, reverbSend, comp;
let musicVol = 0.6;
let sfxVol = 0.8;
let muted = false;
let musicMode = null;
let schedTimer = 0;
let nextTime = 0;
let step = 0;

const NOTE = (n) => 440 * Math.pow(2, (n - 69) / 12);

// Progresión en re menor: Dm · Bb · Gm · A
const CHORDS = [
  [50, 53, 57], // D F A
  [46, 50, 53], // Bb D F
  [43, 46, 50], // G Bb D
  [45, 49, 52], // A C# E
];
const SCALE = [62, 64, 65, 67, 69, 70, 72, 74, 76, 77, 79, 81, 82, 84];
const ELEMENT_MOTIFS = {
  vacio: [0, 3, 2, 5], fuego: [4, 6, 7, 9], abismo: [0, 2, 4, 1], rayo: [7, 9, 11, 7],
  infierno: [0, 1, 3, 0], veneno: [2, 5, 4, 6], hielo: [9, 7, 11, 13], tierra: [0, 4, 3, 1],
  cosmos: [5, 9, 7, 12], sombra: [3, 1, 2, 0], luz: [7, 9, 12, 11], cristal: [11, 9, 13, 12],
};

function makeImpulse(seconds, decay) {
  const rate = ctx.sampleRate;
  const len = Math.floor(rate * seconds);
  const buf = ctx.createBuffer(2, len, rate);
  for (let ch = 0; ch < 2; ch++) {
    const d = buf.getChannelData(ch);
    for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, decay);
  }
  return buf;
}

let noiseBuf = null;
function noise() {
  if (!noiseBuf) {
    noiseBuf = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
    const d = noiseBuf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  }
  const s = ctx.createBufferSource();
  s.buffer = noiseBuf;
  s.loop = true;
  return s;
}

export function initAudio() {
  if (ctx) {
    if (ctx.state === 'suspended') ctx.resume();
    return;
  }
  const AC = window.AudioContext || window.webkitAudioContext;
  if (!AC) return;
  ctx = new AC();
  comp = ctx.createDynamicsCompressor();
  comp.threshold.value = -14;
  comp.ratio.value = 4;
  master = ctx.createGain();
  master.gain.value = muted ? 0 : 1;
  master.connect(comp).connect(ctx.destination);
  reverb = ctx.createConvolver();
  reverb.buffer = makeImpulse(3.2, 2.6);
  reverbSend = ctx.createGain();
  reverbSend.gain.value = 0.55;
  reverbSend.connect(reverb).connect(master);
  musicBus = ctx.createGain();
  musicBus.gain.value = musicVol * 0.5;
  musicBus.connect(master);
  musicBus.connect(reverbSend);
  sfxBus = ctx.createGain();
  sfxBus.gain.value = sfxVol;
  sfxBus.connect(master);
  const sfxVerb = ctx.createGain();
  sfxVerb.gain.value = 0.25;
  sfxBus.connect(sfxVerb).connect(reverbSend);
  if (musicMode) startScheduler();
}

export function setVolumes(m, s) {
  musicVol = m;
  sfxVol = s;
  if (!ctx) return;
  musicBus.gain.setTargetAtTime(m * 0.5, ctx.currentTime, 0.1);
  sfxBus.gain.setTargetAtTime(s, ctx.currentTime, 0.1);
}

export function setMuted(v) {
  muted = v;
  if (ctx) master.gain.setTargetAtTime(v ? 0 : 1, ctx.currentTime, 0.05);
}

// --- bloques básicos ---------------------------------------------------
function env(g, t, a, peak, d, sustain, r, end) {
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(Math.max(peak, 0.0002), t + a);
  if (sustain !== undefined) g.gain.exponentialRampToValueAtTime(Math.max(sustain, 0.0002), t + a + d);
  g.gain.exponentialRampToValueAtTime(0.0001, end + r);
}

function tone({ f, f2, type = 'sine', t = 0, a = 0.005, dur = 0.2, r = 0.2, peak = 0.3, bus, detune = 0, lp, q = 1 }) {
  if (!ctx) return;
  const now = ctx.currentTime + t;
  const o = ctx.createOscillator();
  o.type = type;
  o.frequency.setValueAtTime(f, now);
  if (f2) o.frequency.exponentialRampToValueAtTime(f2, now + dur);
  o.detune.value = detune;
  const g = ctx.createGain();
  env(g, now, a, peak, 0, undefined, r, now + dur);
  let node = o;
  if (lp) {
    const fl = ctx.createBiquadFilter();
    fl.type = 'lowpass';
    fl.frequency.value = lp;
    fl.Q.value = q;
    o.connect(fl);
    node = fl;
  }
  node.connect(g).connect(bus || sfxBus);
  o.start(now);
  o.stop(now + dur + r + 0.05);
}

function burst({ t = 0, dur = 0.2, peak = 0.3, type = 'bandpass', f = 1200, f2, q = 1, a = 0.005, bus }) {
  if (!ctx) return;
  const now = ctx.currentTime + t;
  const s = noise();
  const fl = ctx.createBiquadFilter();
  fl.type = type;
  fl.frequency.setValueAtTime(f, now);
  if (f2) fl.frequency.exponentialRampToValueAtTime(f2, now + dur);
  fl.Q.value = q;
  const g = ctx.createGain();
  env(g, now, a, peak, 0, undefined, dur * 0.6, now + dur * 0.4);
  s.connect(fl).connect(g).connect(bus || sfxBus);
  s.start(now, Math.random() * 0.5);
  s.stop(now + dur + 0.1);
}

function bell(note, t = 0, peak = 0.12, bus) {
  const f = NOTE(note);
  tone({ f, t, a: 0.003, dur: 0.05, r: 1.6, peak, bus });
  tone({ f: f * 2.01, t, a: 0.003, dur: 0.03, r: 0.9, peak: peak * 0.35, bus });
  tone({ f: f * 3.02, t, a: 0.003, dur: 0.02, r: 0.5, peak: peak * 0.15, bus });
}

// --- efectos ------------------------------------------------------------
const rand = (a, b) => a + Math.random() * (b - a);

export const sfx = {
  click() { bell(88, 0, 0.06); },
  hover() { tone({ f: 2400, dur: 0.02, r: 0.05, peak: 0.015 }); },
  back() { bell(81, 0, 0.05); },
  error() { tone({ f: 140, type: 'square', dur: 0.12, r: 0.08, peak: 0.06, lp: 900 }); },
  hit(strong = false) {
    burst({ f: rand(900, 1500), q: 0.8, dur: strong ? 0.18 : 0.1, peak: strong ? 0.35 : 0.22 });
    tone({ f: strong ? 160 : 220, f2: 50, dur: 0.12, r: 0.08, peak: strong ? 0.4 : 0.22 });
  },
  crit() { this.hit(true); bell(93, 0.02, 0.06); },
  whoosh() { burst({ f: 400, f2: 2600, q: 1.4, dur: 0.25, peak: 0.12 }); },
  dodge() { burst({ f: 1800, f2: 500, q: 2, dur: 0.18, peak: 0.12 }); },
  shoot() { tone({ f: rand(700, 900), f2: 1700, type: 'triangle', dur: 0.08, r: 0.06, peak: 0.07 }); },
  breath() { burst({ type: 'lowpass', f: 1600, f2: 500, dur: 0.9, peak: 0.2, a: 0.05 }); },
  boom() {
    burst({ type: 'lowpass', f: 700, f2: 120, dur: 0.7, peak: 0.45 });
    tone({ f: 90, f2: 35, dur: 0.4, r: 0.3, peak: 0.5 });
  },
  zap() {
    burst({ type: 'highpass', f: 2500, dur: 0.15, peak: 0.25 });
    tone({ f: 1200, f2: 200, type: 'sawtooth', dur: 0.12, r: 0.05, peak: 0.08, lp: 3000 });
  },
  heal() { [74, 78, 81, 86].forEach((n, i) => bell(n, i * 0.07, 0.07)); },
  shield() { [69, 76, 81].forEach((n) => tone({ f: NOTE(n), type: 'triangle', a: 0.04, dur: 0.3, r: 0.6, peak: 0.05 })); },
  buff() { tone({ f: 220, f2: 660, type: 'sawtooth', a: 0.05, dur: 0.4, r: 0.3, peak: 0.07, lp: 1800 }); },
  summon(el) {
    const m = ELEMENT_MOTIFS[el] || ELEMENT_MOTIFS.luz;
    m.forEach((d, i) => bell(SCALE[0] + d, i * 0.11, 0.08));
    burst({ f: 300, f2: 3000, q: 1, dur: 0.5, peak: 0.08, a: 0.1 });
  },
  ult() {
    tone({ f: 110, f2: 440, type: 'sawtooth', a: 0.3, dur: 0.6, r: 0.6, peak: 0.12, lp: 2200 });
    burst({ type: 'lowpass', f: 300, f2: 3000, dur: 0.8, peak: 0.2, a: 0.3 });
    setTimeout(() => this.boom(), 600);
  },
  roar(deep = 1) {
    tone({ f: 95 / deep, f2: 55 / deep, type: 'sawtooth', a: 0.08, dur: 1.1, r: 0.5, peak: 0.35, lp: 700, q: 4 });
    tone({ f: 140 / deep, f2: 70 / deep, type: 'square', a: 0.1, dur: 0.9, r: 0.5, peak: 0.12, lp: 500 });
    burst({ type: 'lowpass', f: 900, f2: 200, dur: 1.2, peak: 0.25, a: 0.08 });
  },
  faint() { tone({ f: 330, f2: 80, type: 'triangle', dur: 0.8, r: 0.4, peak: 0.15 }); },
  sealNode(i) { bell(SCALE[Math.min(i, SCALE.length - 1)], 0, 0.12); },
  sealPerfect() { [74, 78, 81, 86, 90].forEach((n) => bell(n, 0, 0.09)); [62, 66, 69].forEach((n) => tone({ f: NOTE(n), type: 'triangle', a: 0.05, dur: 1, r: 1.5, peak: 0.06 })); },
  sealOk() { [74, 77, 81].forEach((n, i) => bell(n, i * 0.08, 0.09)); },
  sealFail() { tone({ f: NOTE(62), f2: NOTE(55), type: 'triangle', dur: 0.5, r: 0.4, peak: 0.15 }); burst({ f: 500, dur: 0.4, peak: 0.1 }); },
  levelUp() { [69, 73, 76, 81, 85].forEach((n, i) => bell(n, i * 0.06, 0.08)); },
  coin() { bell(91, 0, 0.06); bell(96, 0.07, 0.05); },
  warn() { tone({ f: 440, type: 'square', dur: 0.06, r: 0.04, peak: 0.03, lp: 1500 }); },
  phase() { this.roar(1.3); tone({ f: 55, dur: 1.2, r: 1, peak: 0.4 }); },
  break() { burst({ type: 'highpass', f: 1500, dur: 0.4, peak: 0.3 }); [86, 83, 79].forEach((n, i) => bell(n, i * 0.05, 0.08)); },
};

// --- música generativa ----------------------------------------------------
function pad(notes, t, dur, peak) {
  for (const n of notes) {
    const f = NOTE(n);
    for (const det of [-9, 0, 8]) {
      tone({ f, type: 'sawtooth', t, a: dur * 0.35, dur: dur * 0.6, r: dur * 0.6, peak: peak / 3, bus: musicBus, detune: det, lp: 700 + Math.random() * 300, q: 0.6 });
    }
    // «coro»: seno una octava arriba
    tone({ f: f * 2, type: 'sine', t, a: dur * 0.4, dur: dur * 0.5, r: dur * 0.6, peak: peak * 0.25, bus: musicBus });
  }
}

function scheduleStep() {
  const combat = musicMode === 'combat' || musicMode === 'boss';
  const beat = musicMode === 'boss' ? 0.4 : combat ? 0.48 : 0.75; // segundos por pulso
  const beatsPerChord = combat ? 8 : 8;
  const chord = CHORDS[Math.floor(step / beatsPerChord) % CHORDS.length];
  const tRel = nextTime - ctx.currentTime;
  const inChord = step % beatsPerChord;
  if (inChord === 0) pad(chord, tRel, beat * beatsPerChord, combat ? 0.1 : 0.14);
  if (combat) {
    // bajo y percusión suaves
    const root = chord[0] - 12;
    tone({ f: NOTE(root), type: 'triangle', t: tRel, a: 0.01, dur: beat * 0.4, r: 0.1, peak: 0.16, bus: musicBus, lp: 400 });
    if (step % 2 === 0) tone({ f: 120, f2: 42, t: tRel, dur: 0.18, r: 0.08, peak: musicMode === 'boss' ? 0.5 : 0.35, bus: musicBus });
    else burst({ type: 'highpass', f: 7000, t: tRel, dur: 0.05, peak: 0.05, bus: musicBus });
    if (step % 4 === 2) burst({ type: 'bandpass', f: 1800, q: 0.7, t: tRel, dur: 0.12, peak: 0.08, bus: musicBus });
    if (Math.random() < 0.35) bell(chord[Math.floor(Math.random() * 3)] + 24, tRel + beat / 2, 0.035, musicBus);
  } else if (Math.random() < 0.55) {
    bell(chord[Math.floor(Math.random() * 3)] + 24 + (Math.random() < 0.3 ? 12 : 0), tRel + Math.random() * beat, 0.045, musicBus);
  }
  nextTime += beat;
  step++;
}

function startScheduler() {
  clearInterval(schedTimer);
  if (!ctx || !musicMode) return;
  nextTime = ctx.currentTime + 0.1;
  schedTimer = setInterval(() => {
    if (!ctx || ctx.state !== 'running') return;
    while (nextTime < ctx.currentTime + 0.25) scheduleStep();
  }, 60);
}

export function playMusic(mode) {
  if (musicMode === mode) return;
  musicMode = mode;
  step = 0;
  if (ctx) startScheduler();
}

export function stopMusic() {
  musicMode = null;
  clearInterval(schedTimer);
}

export function suspendAudio() { if (ctx && ctx.state === 'running') ctx.suspend(); }
export function resumeAudio() { if (ctx && ctx.state === 'suspended') ctx.resume(); }
