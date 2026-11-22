import { useRef } from 'react';
import { useProgress } from '../hooks.js';
import { Ping, Tick } from '../ui.jsx';

/**
 * Scroll-driven story, pinned for a while:
 *   t1: a task typed on the phone flies to the laptop
 *   t2: it is ticked on the laptop and the phone ticks too.
 */
export default function Sync() {
  const ref = useRef(null);
  useProgress(ref, 'pin');

  return (
    <section className="sync" ref={ref} aria-labelledby="sync-title">
      <div className="sync__stage">
        <div className="sync__copy">
          <h2 id="sync-title">Satu akun, semua perangkat.</h2>
          <p className="lede">
            Ubah di HP, muncul di komputer. Selesaikan di satu tempat dan pengingat di
            perangkat lain ikut berhenti. Tanpa internet pun tetap jalan, lalu menyusul
            saat tersambung.
          </p>
        </div>

        <div className="sync__devices" role="img" aria-label="Tugas dibuat di HP, muncul di laptop, lalu dicentang di keduanya">
          <div className="device device--laptop">
            <p className="device__label">Komputer</p>
            <div className="device__item device__item--laptop">
              <span className="device__tick"><Tick done /></span>
              <span className="hand">Siram tanaman</span>
            </div>
          </div>

          <div className="sync__fly" aria-hidden="true">
            <Ping className="sync__ping" />
            <span className="hand">Siram tanaman</span>
          </div>

          <div className="device device--phone">
            <p className="device__label">HP</p>
            <div className="device__item device__item--phone">
              <span className="device__tick"><Tick done /></span>
              <span className="hand">Siram tanaman</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
