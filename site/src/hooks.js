import { useEffect, useState } from 'react';
import { subscribe } from './scroll.js';

const clamp = (v, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, v));

export function useReducedMotion() {
  const [reduced, setReduced] = useState(
    () => typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches,
  );
  useEffect(() => {
    const q = window.matchMedia('(prefers-reduced-motion: reduce)');
    const on = () => setReduced(q.matches);
    q.addEventListener('change', on);
    return () => q.removeEventListener('change', on);
  }, []);
  return reduced;
}

/**
 * Writes `--p` (0..1) on [ref] while the user scrolls.
 *  - mode "pass": 0 when the element's top enters the viewport bottom,
 *    1 when its bottom leaves the top.
 *  - mode "pin": for a tall section holding a sticky stage: 0 when the section
 *    top reaches the viewport top, 1 when its bottom reaches the viewport bottom.
 * [onProgress] receives the same value (for discrete state).
 */
export function useProgress(ref, mode = 'pass', onProgress) {
  useEffect(() => {
    const el = ref.current;
    if (!el) return undefined;
    return subscribe((_, h) => {
      const r = el.getBoundingClientRect();
      const p =
        mode === 'pin'
          ? clamp(-r.top / Math.max(1, r.height - h))
          : clamp((h - r.top) / (h + r.height));
      el.style.setProperty('--p', p.toFixed(4));
      if (onProgress) onProgress(p);
    });
    // onProgress is intentionally excluded: callers pass inline closures.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ref, mode]);
}
