/* Shared gesture system: drag a sheet down from anywhere to dismiss.
   Locks to vertical after LOCK px, rubber-bands upward, closes on distance or velocity,
   springs back otherwise. The spring runs in JS so the finger can grab it mid-flight. */

const LOCK = 8, CLOSE_DIST = 120, CLOSE_VEL = 0.6;
const NO_DRAG = 'input,textarea,select,[contenteditable],iframe,.arr,.stp,video,.p5.act,[data-nodrag]';
const reduced = () => matchMedia('(prefers-reduced-motion:reduce)').matches;

function blockedByScroll(t, root) {
  for (let el = t; el && el !== root.parentNode; el = el.parentElement) {
    if (el.scrollHeight > el.clientHeight + 1 && el.scrollTop > 0) {
      const oy = getComputedStyle(el).overflowY;
      if (oy === 'auto' || oy === 'scroll') return true;
    }
  }
  return false;
}

export function dragDismiss(o, s, { hap = () => {} } = {}) {
  let st = null, raf = 0, y = 0, vy = 0, armed = false, closed = false;
  s.style.overscrollBehavior = 'contain';

  const paint = () => {
    s.style.transition = 'none';
    s.style.transform = `translate(-50%,${y}px)` + (reduced() ? '' : ` scale(${1 - Math.max(0, y) / 2200})`);
    o.style.background = `rgba(0,0,0,${0.4 * (1 - Math.min(1, Math.max(0, y) / 450))})`;
  };

  const spring = () => {
    cancelAnimationFrame(raf);
    if (reduced()) { y = 0; vy = 0; s.style.transform = ''; o.style.background = ''; return; }
    let last = performance.now();
    const step = now => {
      let dt = Math.min(0.032, (now - last) / 1000); last = now;
      for (; dt > 0; dt -= 1 / 240) {
        const h = Math.min(dt, 1 / 240);
        vy += (-260 * y - 26 * vy) * h; y += vy * h;
      }
      if (Math.abs(y) < 0.3 && Math.abs(vy) < 5) { y = 0; vy = 0; s.style.transform = ''; o.style.background = ''; return }
      paint(); raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
  };

  const start = (t, x0, y0) => {
    if (closed || o.closing || t.closest(NO_DRAG)) return false;
    const sel = getSelection(); if (sel && !sel.isCollapsed) return false;
    if (blockedByScroll(t, s)) return false;
    cancelAnimationFrame(raf);               // grabbing mid-spring: keep current y
    st = { x0, y0, base: y, lock: false, dead: false, samples: [[performance.now(), y0]] };
    return true;
  };

  const move = (x, yy, prevent) => {
    if (!st || st.dead) return;
    const dx = x - st.x0, dy = yy - st.y0;
    if (!st.lock) {
      if (Math.hypot(dx, dy) < LOCK) return;
      if (dy > 0 && dy > Math.abs(dx)) st.lock = true; else { st.dead = true; if (st.base) spring(); return }
    }
    const sel = getSelection(); if (sel && !sel.isCollapsed) { st.dead = true; spring(); return }
    prevent();
    const raw = st.base + dy;
    y = raw >= 0 ? raw : raw * 0.25;       // rubber band above rest position
    const now = performance.now(); st.samples.push([now, yy]);
    while (st.samples.length > 2 && now - st.samples[0][0] > 90) st.samples.shift();
    if (!armed && y > CLOSE_DIST) { armed = true; hap('m') } else if (armed && y <= CLOSE_DIST) armed = false;
    paint();
  };

  const end = () => {
    if (!st) return;
    const { lock, dead, samples } = st; st = null;
    if (!lock || dead) { if (!dead && y) spring(); return }
    const a = samples[0], b = samples[samples.length - 1];
    vy = (b[1] - a[1]) / Math.max(1, b[0] - a[0]) * 1000;   // px/s
    armed = false;
    if (y > CLOSE_DIST || (vy / 1000 > CLOSE_VEL && y > 40)) { closed = true; o.fling() }
    else spring();
  };

  // touch: non-passive move so we can stop the page/scroller once locked vertical
  s.addEventListener('touchstart', e => { if (e.touches.length === 1) start(e.target, e.touches[0].clientX, e.touches[0].clientY); else if (st) st.dead = true }, { passive: true });
  s.addEventListener('touchmove', e => { const t = e.touches[0]; move(t.clientX, t.clientY, () => e.cancelable && e.preventDefault()) }, { passive: false });
  s.addEventListener('touchend', end); s.addEventListener('touchcancel', end);

  // mouse: pointer events with capture once locked
  s.addEventListener('pointerdown', e => { if (e.pointerType === 'mouse' && e.button === 0) start(e.target, e.clientX, e.clientY) });
  s.addEventListener('pointermove', e => {
    if (e.pointerType !== 'mouse') return;
    const was = st && st.lock; move(e.clientX, e.clientY, () => {});
    if (st && st.lock && !was) try { s.setPointerCapture(e.pointerId) } catch {}
  });
  s.addEventListener('pointerup', e => { if (e.pointerType === 'mouse') end() });
  s.addEventListener('pointercancel', e => { if (e.pointerType === 'mouse') end() });
}
