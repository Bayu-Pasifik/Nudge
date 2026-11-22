const SETTINGS = [
  ['Ulangi tiap', '1 menit sampai 1 jam. Bawaannya 10 menit.'],
  ['Makin mendesak', 'Suara keras setelah 3 kali diabaikan, layar penuh setelah 6.'],
  ['Jam tenang', 'Tidak mengulang malam hari. Bawaannya 22:00 sampai 07:00.'],
  ['Tunda', '10 menit, langsung dari notifikasi.'],
  ['Jeda semua', 'Satu jam atau sampai besok pagi, dari satu tombol.'],
  ['Batas', 'Sampai selesai, atau 5 sampai 50 kali lalu ditandai terlewat.'],
  ['Berulang', 'Harian, mingguan, atau bulanan. Selesai berarti siklus berikutnya.'],
];

export default function Control() {
  return (
    <section className="control" aria-labelledby="control-title">
      <h2 id="control-title">Kamu yang menentukan seberapa berisik.</h2>
      <p className="lede">
        Mengingatkan terus itu berguna sampai terasa mengganggu. Jadi semuanya bisa diatur,
        per pengingat atau sebagai pengaturan awal.
      </p>
      <dl className="settings">
        {SETTINGS.map(([term, desc]) => (
          <div key={term} className="settings__row">
            <dt>{term}</dt>
            <dd>{desc}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}
