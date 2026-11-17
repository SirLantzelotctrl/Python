// Controles: teclado (WASD · Q E R · F · Espacio · 1 2 3), táctil (joystick
// izquierdo, botones a la derecha, deslizar para esquivar) y mando.

export const input = {
  move: { x: 0, y: 0 },
  keys: new Set(),
  pressed: new Set(), // acciones disparadas en este frame
  touch: false,
  joy: { active: false, id: null, ox: 0, oy: 0, x: 0, y: 0 },
  enabled: true,
};

const KEYMAP = {
  KeyQ: 'q', KeyE: 'e', KeyR: 'r', KeyF: 'f', Space: 'dodge',
  Digit1: 'sw1', Digit2: 'sw2', Digit3: 'sw3', Tab: 'target', KeyG: 'seal', Enter: 'seal',
  Escape: 'pause', KeyP: 'pause', KeyJ: 'q', KeyK: 'e', KeyL: 'r', ShiftLeft: 'dodge',
};

export function press(action) {
  if (input.enabled) input.pressed.add(action);
}

export function initInput(joyEl, knobEl, area) {
  window.addEventListener('keydown', (e) => {
    if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) return;
    input.keys.add(e.code);
    const a = KEYMAP[e.code];
    if (a && !e.repeat) {
      press(a);
      if (e.code === 'Tab' || e.code === 'Space') e.preventDefault();
    }
  });
  window.addEventListener('keyup', (e) => input.keys.delete(e.code));
  window.addEventListener('blur', () => input.keys.clear());

  // joystick dinámico: aparece donde el pulgar toca la mitad izquierda
  const radius = 56;
  let swipe = null;
  area.addEventListener('pointerdown', (e) => {
    if (e.pointerType === 'mouse') return;
    input.touch = true;
    document.body.classList.add('touch');
    if (e.clientX < window.innerWidth * 0.45 && !input.joy.active) {
      input.joy = { active: true, id: e.pointerId, ox: e.clientX, oy: e.clientY, x: 0, y: 0 };
      joyEl.style.left = e.clientX + 'px';
      joyEl.style.top = e.clientY + 'px';
      joyEl.classList.add('on');
      knobEl.style.transform = 'translate(-50%, -50%)';
    } else {
      swipe = { id: e.pointerId, x: e.clientX, y: e.clientY, t: performance.now() };
    }
  });
  area.addEventListener('pointermove', (e) => {
    if (input.joy.active && e.pointerId === input.joy.id) {
      let dx = e.clientX - input.joy.ox;
      let dy = e.clientY - input.joy.oy;
      const d = Math.hypot(dx, dy);
      if (d > radius) { dx = (dx / d) * radius; dy = (dy / d) * radius; }
      input.joy.x = dx / radius;
      input.joy.y = dy / radius;
      knobEl.style.transform = `translate(calc(-50% + ${dx}px), calc(-50% + ${dy}px))`;
    }
  });
  const end = (e) => {
    if (input.joy.active && e.pointerId === input.joy.id) {
      input.joy.active = false;
      input.joy.x = input.joy.y = 0;
      joyEl.classList.remove('on');
    }
    if (swipe && e.pointerId === swipe.id) {
      const dx = e.clientX - swipe.x;
      const dy = e.clientY - swipe.y;
      if (Math.hypot(dx, dy) > 50 && performance.now() - swipe.t < 350) {
        input.swipeDir = { x: dx, y: dy };
        press('dodge');
      }
      swipe = null;
    }
  };
  area.addEventListener('pointerup', end);
  area.addEventListener('pointercancel', end);
}

let padPrev = [];
const PAD = { 2: 'q', 3: 'e', 1: 'r', 5: 'f', 7: 'f', 0: 'dodge', 14: 'sw1', 12: 'sw2', 15: 'sw3', 9: 'pause', 4: 'target', 6: 'seal' };

export function pollInput() {
  let x = 0;
  let y = 0;
  const k = input.keys;
  if (k.has('KeyA') || k.has('ArrowLeft')) x -= 1;
  if (k.has('KeyD') || k.has('ArrowRight')) x += 1;
  if (k.has('KeyW') || k.has('ArrowUp')) y -= 1;
  if (k.has('KeyS') || k.has('ArrowDown')) y += 1;
  if (input.joy.active) { x += input.joy.x; y += input.joy.y; }
  const pads = navigator.getGamepads ? navigator.getGamepads() : [];
  for (const p of pads) {
    if (!p) continue;
    const ax = p.axes[0] || 0;
    const ay = p.axes[1] || 0;
    if (Math.hypot(ax, ay) > 0.2) { x += ax; y += ay; }
    p.buttons.forEach((b, i) => {
      if (b.pressed && !padPrev[i] && PAD[i]) press(PAD[i]);
      padPrev[i] = b.pressed;
    });
    break;
  }
  const len = Math.hypot(x, y);
  if (len > 1) { x /= len; y /= len; }
  input.move.x = x;
  input.move.y = y;
}

export function consume(action) {
  if (input.pressed.has(action)) {
    input.pressed.delete(action);
    return true;
  }
  return false;
}

export function clearPressed() {
  input.pressed.clear();
}
