import { useRef } from 'react';
import { useProgress } from '../hooks.js';
import { Layer, Note, Ping, REPO, RELEASES, BASE, Tick } from '../ui.jsx';

// Far notes are big and blurred, near ones are small and sharp: different
// depths so they drift at different speeds while scrolling.
const FAR = [
  { x: '-4%', y: '8%', c: 'peach', r: -12, w: 300, d: -40 },
  { x: '62%', y: '-6%', c: 'sky', r: 9, w: 340, d: -30 },
  { x: '84%', y: '52%', c: 'mint', r: -7, w: 280, d: -50 },
  { x: '30%', y: '70%', c: 'lavender', r: 14, w: 320, d: -35 },
];

const MID = [
  { x: '50%', y: '82%', c: 'yellow', r: -6, d: 70, t: 'Telepon bank', done: false },
  { x: '46%', y: '8%', c: 'mint', r: 5, d: 130, t: 'Beli susu', done: true },
  { x: '88%', y: '18%', c: 'peach', r: -9, d: 90, t: 'Kirim laporan', done: false },
  { x: '70%', y: '78%', c: 'sky', r: 7, d: 150, t: 'Siram tanaman', done: false },
  { x: '3%', y: '85%', c: 'lavender', r: 8, d: 110, t: 'Minum obat', done: false },
];

export default function Hero() {
  const ref = useRef(null);
  useProgress(ref, 'pass');

  return (
    <header className="hero" ref={ref}>
      <div className="hero__wall" aria-hidden="true">
        {FAR.map((n) => (
          <Layer key={n.t ?? `${n.x}${n.y}`} x={n.x} y={n.y} depth={n.d} className="layer--far">
            <Note color={n.c} rotate={n.r} style={{ width: n.w, height: n.w * 0.92 }} />
          </Layer>
        ))}
        {MID.map((n) => (
          <Layer key={n.t} x={n.x} y={n.y} depth={n.d} className="layer--mid">
            <Note color={n.c} rotate={n.r} className="note--small">
              <span className={`hand${n.done ? ' hand--done' : ''}`}>{n.t}</span>
            </Note>
          </Layer>
        ))}
      </div>

      <nav className="topbar" aria-label="Utama">
        <a className="brand" href={BASE} aria-label="Nudge, ke atas">
          <img src={`${BASE}favicon.png`} alt="" width="36" height="36" />
          <span>Nudge</span>
        </a>
        <a className="topbar__link" href={REPO}>GitHub</a>
      </nav>

      <div className="hero__inner">
        <div className="hero__copy">
          <h1>Todo yang menempel dan terus mengingatkan.</h1>
          <p className="lede">
            Board ala Trello, sticky note, dan alarm dalam satu app. Tugas yang belum
            dicentang tidak dibiarkan lupa, di Android dan Windows, dengan data yang sama
            di semua perangkat.
          </p>
          <div className="actions">
            <a className="btn btn--primary" href={RELEASES}>Unduh Nudge</a>
            <a className="btn btn--ghost" href={REPO}>Lihat kodenya</a>
          </div>
        </div>

        <Layer x="0" y="0" depth={-70} className="layer--flow hero__hero-note">
          <div className="hero-note">
          <Ping className="hero-note__ping" />
          <Note color="yellow" rotate={-5} className="note--hero">
            <p className="hand hand--big">Bayar listrik</p>
            <ul className="mini-check">
              <li><Tick done /> <span className="hand hand--done">Cek meteran</span></li>
              <li><Tick /> <span className="hand">Transfer ke PLN</span></li>
            </ul>
            <p className="note__meta">Ingatkan tiap 10 menit sampai selesai</p>
          </Note>
          </div>
        </Layer>
      </div>
    </header>
  );
}
