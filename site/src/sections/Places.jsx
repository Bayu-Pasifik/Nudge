import { useRef } from 'react';
import { useProgress } from '../hooks.js';
import { Layer, Note, Ping, Tick } from '../ui.jsx';

function Shade() {
  return (
    <div className="mock mock--shade" role="img" aria-label="Notifikasi menetap di Android dengan tombol Selesai">
      <div className="shade__bar">
        <Ping className="shade__ping" /> Nudge
        <span className="shade__chip">menetap</span>
      </div>
      <div className="shade__row">
        <div>
          <b>Beli susu</b>
          <span>1/3 selesai · Rumah › Todo</span>
        </div>
        <span className="shade__btn">Selesai</span>
      </div>
      <div className="shade__row">
        <div>
          <b>Telepon bank</b>
          <span>Rumah › Todo</span>
        </div>
        <span className="shade__btn">Selesai</span>
      </div>
    </div>
  );
}

function Widget() {
  return (
    <div className="mock mock--widget" role="img" aria-label="Widget layar utama dengan dua kartu ter-pin">
      <p className="widget__head">Nudge · 2 belum selesai</p>
      <div className="widget__row"><Tick /> <span>Kirim laporan</span></div>
      <div className="widget__row"><Tick /> <span>Bayar pajak</span></div>
    </div>
  );
}

function Desk() {
  return (
    <div className="mock mock--desk" role="img" aria-label="Jendela sticky kecil yang selalu di atas jendela lain">
      <div className="desk__back">
        <i /><i /><i /><i />
      </div>
      <div className="desk__sticky">
        <div className="desk__title">
          <Ping className="desk__ping" /> Sticky
        </div>
        <Note color="mint" rotate={0} className="note--tiny">
          <div className="desk__item"><Tick done /> <span className="hand hand--done">Cek meteran</span></div>
          <div className="desk__item"><Tick /> <span className="hand">Transfer ke PLN</span></div>
        </Note>
        <Note color="peach" rotate={0} className="note--tiny">
          <div className="desk__item"><Tick /> <span className="hand">Telepon bank</span></div>
        </Note>
      </div>
    </div>
  );
}

const ROWS = [
  {
    id: 'shade',
    title: 'Tetap terlihat di notifikasi',
    text:
      'Kartu yang kamu pin muncul sebagai notifikasi menetap di Android. Tidak bisa digeser pergi, dan bisa dicentang langsung dari sana.',
    mock: <Shade />,
    deco: { color: 'lavender', r: 8, x: '78%', y: '-8%', d: 140 },
  },
  {
    id: 'widget',
    title: 'Di layar utama',
    text:
      'Widget menampilkan sampai lima kartu ter-pin. Ketuk lingkarannya untuk menyelesaikan tanpa membuka app.',
    mock: <Widget />,
    deco: { color: 'sky', r: -10, x: '-6%', y: '62%', d: 120 },
  },
  {
    id: 'desk',
    title: 'Di atas jendela lain',
    text:
      'Di Windows, mode sticky mengecilkan Nudge jadi jendela kecil yang selalu di atas, lengkap dengan checklist yang bisa dicentang.',
    mock: <Desk />,
    deco: { color: 'peach', r: 6, x: '84%', y: '68%', d: 150 },
  },
];

function Row({ row, flip }) {
  const ref = useRef(null);
  useProgress(ref, 'pass');
  return (
    <article className={`place${flip ? ' place--flip' : ''}`} ref={ref} aria-labelledby={`p-${row.id}`}>
      <div className="place__copy">
        <h3 id={`p-${row.id}`}>{row.title}</h3>
        <p>{row.text}</p>
      </div>
      <div className="place__art">
        <Layer x={row.deco.x} y={row.deco.y} depth={row.deco.d} className="layer--deco">
          <Note color={row.deco.color} rotate={row.deco.r} className="note--small" />
        </Layer>
        <Layer x="0" y="0" depth={-60} className="layer--flow">
          {row.mock}
        </Layer>
      </div>
    </article>
  );
}

export default function Places() {
  return (
    <section className="places" aria-labelledby="places-title">
      <h2 id="places-title">Menempel di tempat yang kamu lihat.</h2>
      {ROWS.map((row, i) => (
        <Row key={row.id} row={row} flip={i % 2 === 1} />
      ))}
    </section>
  );
}
