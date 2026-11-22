import { useRef, useState } from 'react';
import { useProgress, useReducedMotion } from '../hooks.js';
import { Note, Ping, Tick } from '../ui.jsx';

// Mirrors the app's defaults: nag every 10 minutes, louder after the 3rd
// ignored reminder, full screen after the 6th.
const INTERVAL = 10;
const START = 9 * 60;
const LAST = 7; // index of the last nag shown
const LEVEL_AT = (k) => (k >= 6 ? 3 : k >= 3 ? 2 : 1);

const LEVEL_COPY = {
  1: { name: 'Pengingat biasa', text: 'Notifikasi pertama muncul tepat waktu.' },
  2: { name: 'Suara keras', text: 'Sudah tiga kali diabaikan. Suaranya naik dan getarnya memanjang.' },
  3: { name: 'Layar penuh', text: 'Enam kali diabaikan. Peringatan memenuhi layar sampai tugasnya dicentang.' },
};

const clock = (k) => {
  const m = START + k * INTERVAL;
  return `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
};

function Notification({ k, depth }) {
  const level = LEVEL_AT(k);
  return (
    <article
      className={`notif notif--l${level}`}
      style={{ '--i': depth }}
      aria-label={`Pengingat ke-${k + 1}`}
    >
      <div className="notif__head">
        <Ping className="notif__ping" />
        <span>Nudge</span>
        <time>{clock(k)}</time>
      </div>
      <h3>Bayar listrik</h3>
      <p>
        {k === 0 ? 'Rumah › Todo' : `Belum selesai · pengingat ke-${k} · Rumah › Todo`}
      </p>
      {level === 3 ? (
        <div className="notif__actions">
          <span className="btn btn--solid">Selesai</span>
          <span className="btn btn--line">Tunda 10 mnt</span>
        </div>
      ) : null}
    </article>
  );
}

/** Reduced motion: the same story as a static list, no pinned scrolling. */
function StaticStory() {
  return (
    <section className="nag nag--static" aria-labelledby="nag-title">
      <div className="nag__static-inner">
        <h2 id="nag-title">Dia tidak berhenti sampai kamu centang.</h2>
        <p className="lede">
          Pengingat biasa bunyi sekali lalu terlupakan. Nudge mengulang, makin mendesak,
          sampai tugasnya selesai.
        </p>
        <div className="nag__static-list">
          {[0, 3, 6].map((k) => (
            <div key={k} className="nag__static-item">
              <h3>{LEVEL_COPY[LEVEL_AT(k)].name}</h3>
              <p>{LEVEL_COPY[LEVEL_AT(k)].text}</p>
              <Notification k={k} depth={0} />
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

export default function NagSequence() {
  const ref = useRef(null);
  const reduced = useReducedMotion();
  // Discrete stage 0..LAST, or "done": state only changes when the stage does.
  const [stage, setStage] = useState(0);

  useProgress(ref, 'pin', (p) => {
    const next = p >= 0.9 ? 'done' : Math.min(LAST, Math.floor((p / 0.9) * (LAST + 1)));
    setStage(next);
  });

  if (reduced) return <StaticStory />;

  const done = stage === 'done';
  const k = done ? LAST : stage;
  const level = done ? 0 : LEVEL_AT(k);
  const copy = LEVEL_COPY[level];
  const shown = [];
  for (let i = Math.max(0, k - 3); i <= k; i += 1) shown.push(i);

  return (
    <section
      className="nag"
      ref={ref}
      data-level={level}
      aria-labelledby="nag-title"
    >
      <div className="nag__stage">
        <div className="nag__copy">
          <h2 id="nag-title">Dia tidak berhenti sampai kamu centang.</h2>
          <p className="lede">
            Pengingat biasa bunyi sekali lalu terlupakan. Nudge mengulang, makin
            mendesak, sampai tugasnya selesai. Gulir untuk melihat waktu berjalan.
          </p>

          <div className="nag__readout" aria-live="polite">
            <div className="nag__clock">{done ? 'Selesai' : clock(k)}</div>
            <div className="nag__level">
              <strong>{done ? 'Sunyi lagi' : copy.name}</strong>
              <span>
                {done
                  ? 'Dicentang di satu perangkat, semua perangkat berhenti mengingatkan.'
                  : copy.text}
              </span>
            </div>
          </div>
        </div>

        <div className="nag__device">
          {done ? (
            <Note color="yellow" rotate={-3} className="note--done">
              <div className="done-row">
                <Tick done />
                <p className="hand hand--big hand--done">Bayar listrik</p>
              </div>
              <p className="note__meta">Selesai. Pengingat berikutnya dibatalkan di semua perangkat.</p>
            </Note>
          ) : (
            <div className="stack">
              {shown
                .slice()
                .reverse()
                .map((idx, depth) => (
                  <Notification key={idx} k={idx} depth={depth} />
                ))}
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
