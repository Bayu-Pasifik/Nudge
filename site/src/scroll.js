// One scroll listener for the whole page. Every parallax layer reads CSS
// variables, so scrolling costs a few style writes per frame and no React
// re-renders.
const subscribers = new Set();
let queued = false;

function frame() {
  queued = false;
  const y = window.scrollY;
  const h = window.innerHeight;
  document.documentElement.style.setProperty('--sy', String(Math.round(y)));
  subscribers.forEach((fn) => fn(y, h));
}

function schedule() {
  if (queued) return;
  queued = true;
  requestAnimationFrame(frame);
}

export function subscribe(fn) {
  if (subscribers.size === 0) {
    window.addEventListener('scroll', schedule, { passive: true });
    window.addEventListener('resize', schedule);
  }
  subscribers.add(fn);
  schedule();
  return () => {
    subscribers.delete(fn);
    if (subscribers.size === 0) {
      window.removeEventListener('scroll', schedule);
      window.removeEventListener('resize', schedule);
    }
  };
}
