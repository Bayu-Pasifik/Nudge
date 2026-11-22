import { useRef } from 'react';
import { useProgress } from '../hooks.js';
import { Layer, Note, REPO, RELEASES, BASE } from '../ui.jsx';

export default function Cta() {
  const ref = useRef(null);
  useProgress(ref, 'pass');

  return (
    <footer className="cta" ref={ref}>
      <div className="cta__wall" aria-hidden="true">
        <Layer x="4%" y="14%" depth={110} className="layer--deco">
          <Note color="sky" rotate={-9} className="note--small"><span className="hand">Beli susu</span></Note>
        </Layer>
        <Layer x="80%" y="8%" depth={170} className="layer--deco">
          <Note color="mint" rotate={7} className="note--small"><span className="hand hand--done">Kirim laporan</span></Note>
        </Layer>
        <Layer x="72%" y="70%" depth={90} className="layer--deco">
          <Note color="lavender" rotate={-5} className="note--small"><span className="hand">Minum obat</span></Note>
        </Layer>
      </div>

      <div className="cta__inner">
        <img src={`${BASE}favicon.png`} alt="" width="72" height="72" className="cta__logo" />
        <h2>Pasang Nudge dan centang yang pertama.</h2>
        <p className="lede">
          Tersedia untuk Android dan Windows. Build terbaru ada di halaman Rilis GitHub.
        </p>
        <div className="actions">
          <a className="btn btn--primary" href={RELEASES}>Unduh dari halaman Rilis</a>
          <a className="btn btn--ghost" href={REPO}>Kode sumber</a>
        </div>
        <p className="fine">
          iOS belum tersedia. Data disimpan di project Supabase yang kamu hubungkan sendiri;
          tanpa itu, Nudge tetap berjalan di perangkat ini saja.
        </p>
      </div>
    </footer>
  );
}
