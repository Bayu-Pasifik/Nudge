export const REPO = 'https://github.com/Bayu-Pasifik/Nudge';
export const RELEASES = `${REPO}/releases`;
export const BASE = import.meta.env.BASE_URL;

/** A sticky note: paper with a folded bottom-right corner, like the logo. */
export function Note({ color = 'yellow', rotate = 0, className = '', style, children }) {
  return (
    <div
      className={`note note--${color} ${className}`.trim()}
      style={{ '--rot': `${rotate}deg`, ...style }}
    >
      <div className="note__paper">{children}</div>
      <span className="note__fold" aria-hidden="true" />
    </div>
  );
}

/** Absolutely positioned layer that drifts with scroll (reads --p from its section). */
export function Layer({ x, y, depth = 0, className = '', children }) {
  return (
    <div
      className={`layer ${className}`.trim()}
      style={{ left: x, top: y, '--depth': depth }}
    >
      {children}
    </div>
  );
}

export function Tick({ done = false }) {
  return (
    <span className={`tick${done ? ' tick--done' : ''}`} aria-hidden="true">
      <svg viewBox="0 0 24 24" width="100%" height="100%">
        <path d="M6 12.5l4 4 8-9" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    </span>
  );
}

/** The two ping arcs from the logo. */
export function Ping({ className = '' }) {
  return (
    <svg className={`ping ${className}`.trim()} viewBox="0 0 120 120" aria-hidden="true">
      <path d="M 14 56 A 36 36 0 0 1 50 92" fill="none" stroke="currentColor" strokeWidth="10" strokeLinecap="round" />
      <path d="M 14 20 A 78 78 0 0 1 100 106" fill="none" stroke="currentColor" strokeWidth="10" strokeLinecap="round" opacity="0.55" />
    </svg>
  );
}
