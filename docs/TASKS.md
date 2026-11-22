# TASKS — Nudge (Flutter)

Legenda: `[ ]` belum · `[x]` selesai · **P0** wajib v1 · **P1** sebaiknya v1 · **P2** nanti.
Setiap fase punya kriteria selesai (DoD) yang bisa diuji. Platform target awal: **Android + Windows**; iOS dan macOS/Linux mengikuti keputusan PRD §11.

---

## Fase 0 — Spike risiko (1–3 hari, lakukan paling awal)

Tujuan: membuktikan bagian paling berisiko sebelum membangun yang lain.

- [ ] **T0.1 (P0)** App Flutter minimal yang menjadwalkan notifikasi lokal tepat waktu dan berulang tiap 1 menit; uji di HP Android fisik dengan app **dimatikan** dan layar terkunci.
- [ ] **T0.2 (P0)** Uji izin Android: `POST_NOTIFICATIONS`, exact alarm, boot receiver; amati perilaku di merek agresif (Xiaomi/Oppo/Vivo/Samsung) dan catat langkah pengecualian baterai.
- [ ] **T0.3 (P0)** Notifikasi dengan tombol aksi **Selesai**/**Tunda** yang berjalan di background isolate (tanpa membuka app).
- [ ] **T0.4 (P0)** Windows: jendela tanpa bingkai always-on-top (`window_manager`), ikon tray (`tray_manager`), notifikasi native, autostart.
- [ ] **T0.5 (P1)** Widget layar utama Android dengan `home_widget` yang menampilkan daftar dan menerima ketukan centang.
- [ ] **T0.6 (P1)** Uji full-screen intent Android untuk eskalasi.

**DoD:** Nag 1-menit berbunyi ≥ 30 kali berturut-turut di HP fisik saat app tertutup; aksi Selesai menghentikannya; jendela sticky Windows tampil di atas jendela lain.

---

## Fase 1 — Fondasi proyek

- [ ] **T1.1 (P0)** Buat proyek Supabase dev dan prod terpisah; simpan URL dan anon key di `--dart-define`/`.env` (jangan commit).
- [ ] **T1.2 (P0)** `flutter create` dengan target android, windows (+ ios/macos jika dipilih); struktur `lib/features/*`, `lib/core/*`.
- [ ] **T1.3 (P0)** Dependensi: `supabase_flutter`, `flutter_riverpod`, `go_router`, `drift`, `flutter_local_notifications`, `timezone`, `flutter_secure_storage`, `intl`.
- [ ] **T1.4 (P0)** Lint (`flutter_lints`), `dart format`, `flutter analyze`, CI sederhana.
- [ ] **T1.5 (P0)** Tema dari STYLE.md: `ThemeExtension` untuk token warna/jarak/radius, tema terang dan gelap.
- [ ] **T1.6 (P1)** Setup i18n (id/en) dan penanganan galat global.

**DoD:** App kosong bertema berjalan di Android dan Windows; `flutter analyze` bersih.

---

## Fase 2 — Backend Supabase

- [ ] **T2.1 (P0)** Supabase CLI + folder `supabase/` (migrasi, seed, config).
- [ ] **T2.2 (P0)** Migrasi tabel sesuai PRD §6: `boards`, `lists`, `cards` (termasuk `pinned`, `sticky_color`), `labels`, `card_labels`, `checklist_items`, `reminders` (kolom nag), `user_settings`, `devices`.
- [ ] **T2.3 (P0)** Trigger `updated_at`; trigger "kartu selesai → reminders.state = done"; indeks (`board_id`, `list_id`, `position`, `remind_at`, `state`).
- [ ] **T2.4 (P0)** RLS di semua tabel berbasis `auth.uid()`; tabel anak memeriksa lewat induk.
- [ ] **T2.5 (P0)** Tes RLS: pengguna A tidak bisa membaca/menulis data pengguna B.
- [ ] **T2.6 (P0)** Aktifkan Realtime untuk tabel inti.
- [ ] **T2.7 (P0)** Konfigurasi Auth (email+password, magic link, redirect URL mobile & desktop).
- [ ] **T2.8 (P1)** RPC `move_card` atomik + rebalance posisi.

**DoD:** Tes RLS lulus; login lewat klien uji bekerja; Realtime mengirim event perubahan.

---

## Fase 3 — Autentikasi di klien

- [ ] **T3.1 (P0)** Inisialisasi Supabase dengan penyimpanan sesi aman.
- [ ] **T3.2 (P0)** Layar masuk/daftar/lupa password/magic link + validasi.
- [ ] **T3.3 (P0)** Route guard (`go_router`): belum login → auth.
- [ ] **T3.4 (P0)** Keluar; hapus akun (Edge Function).
- [ ] **T3.5 (P0)** Deep link magic link di Android dan Windows (protocol handler).

**DoD:** Daftar → keluar → masuk; sesi bertahan setelah app ditutup di Android dan Windows.

---

## Fase 4 — Board, list, kartu, checklist (CRUD + edit di HP)

- [ ] **T4.1 (P0)** Lapisan data: repository + provider Riverpod, optimistic update dengan rollback.
- [ ] **T4.2 (P0)** Layar daftar board; CRUD board.
- [ ] **T4.3 (P0)** Tampilan board: list horizontal (mobile: satu list per halaman dengan peek); CRUD list.
- [ ] **T4.4 (P0)** Widget kartu sesuai STYLE.md; quick add di footer list.
- [ ] **T4.5 (P0)** Detail kartu: judul, deskripsi, jatuh tempo, tandai selesai, arsip, hapus.
- [ ] **T4.6 (P0)** **Checklist**: tambah, edit inline, centang, hapus, urutkan; opsi "kartu selesai otomatis saat semua tercentang".
- [ ] **T4.7 (P0)** Util `positionBetween(a, b)` + unit test (awal/tengah/akhir/rebalance).
- [ ] **T4.8 (P0)** Drag-and-drop kartu antar list dan urutan list (sentuh dan mouse).
- [ ] **T4.9 (P0)** Menu "Pindahkan ke…" sebagai alternatif aksesibel.
- [ ] **T4.10 (P1)** Label (CRUD + pasang ke kartu).
- [ ] **T4.11 (P1)** Skeleton loading, empty state, snackbar "Urungkan".

**DoD:** Dari HP, buat board → list → kartu → checklist → edit → pindah → selesai; terlihat sama di Windows setelah sinkron.

---

## Fase 5 — Mesin pengingat & nagging (fitur inti)

- [ ] **T5.1 (P0)** Model domain `NagPlan`: dari `reminders` hitung daftar waktu kejadian berikutnya (interval, jam tenang, batas, eskalasi, tunda). Murni Dart, **unit test lengkap** (jam tenang, lintas tengah malam, tunda, batas maks, zona waktu/DST).
- [ ] **T5.2 (P0)** UI pemilih pengingat: pintasan ("10 menit lagi", "Nanti malam", "Besok pagi"), tanggal/jam, ulang, relatif ke jatuh tempo.
- [ ] **T5.3 (P0)** UI kebijakan nag: aktif, interval, maksimum, eskalasi, jam tenang; default global di Pengaturan, dapat ditimpa per kartu.
- [ ] **T5.4 (P0)** Layanan penjadwal `NagScheduler.rescheduleAll()` yang menerjemahkan `NagPlan` menjadi notifikasi lokal; dipanggil saat app dibuka, data berubah, reboot, ganti zona waktu.
- [ ] **T5.5 (P0)** Android: channel per level eskalasi (prioritas, suara, getar), exact alarm, boot receiver, penjadwalan ulang setelah reboot.
- [ ] **T5.6 (P0)** Aksi notifikasi **Selesai**/**Tunda**/**Buka** di background (isolate), menulis ke DB lokal lalu menyinkronkan; deep link ke kartu.
- [ ] **T5.7 (P0)** **Penyelesaian lintas perangkat:** saat selesai, batalkan notifikasi lokal; kirim ke Supabase; perangkat lain menerima Realtime/push silent dan membatalkan jadwalnya. Tes dua perangkat.
- [ ] **T5.8 (P0)** Eskalasi: level 2 (suara keras/getar panjang) dan level 3 (full-screen intent Android; pop-up always-on-top di desktop).
- [ ] **T5.9 (P0)** Status `missed` saat batas nag tercapai; tampil merah di kartu dan layar Hari ini.
- [ ] **T5.10 (P0)** Layar **Hari ini** (Terlambat, Hari ini, Ter-pin) dan **Mendatang**.
- [ ] **T5.11 (P0)** Tombol "Jeda semua pengingat" (1 jam / sampai besok) yang mudah ditemukan.
- [ ] **T5.12 (P0)** Layar izin dan panduan: notifikasi, exact alarm, pengecualian baterai, full-screen intent; deteksi saat izin belum diberikan dan tampilkan peringatan jelas.
- [ ] **T5.13 (P1)** Edge Function `nag-dispatcher` + pg_cron tiap menit: kirim push FCM untuk nag jatuh tempo yang belum selesai (cadangan); tabel `devices` + pendaftaran/pembersihan token.
- [ ] **T5.14 (P1)** Pengulangan tugas (harian/mingguan/bulanan): buat kejadian berikutnya saat selesai.
- [ ] **T5.15 (P1, jika iOS)** iOS: rantai notifikasi pendek (≤ 64 total), level *Time Sensitive*, isi ulang saat app dibuka dan lewat push silent; dokumentasikan keterbatasan di layar izin.
- [ ] **T5.16 (P0)** Uji lapangan: nag 10 menit selama 3 jam di HP fisik, app tertutup; selesai di desktop menghentikan nag di HP.

**DoD:** Tugas belum selesai terus mengingatkan sesuai interval dan eskalasi, berhenti seketika saat dicentang di perangkat mana pun, tidak ada nag di jam tenang, unit test `NagPlan` lulus.

---

## Fase 6 — Sticky note & pin

- [ ] **T6.1 (P0)** Fitur pin pada kartu dan pemilih warna sticky; kartu ter-pin tampil di bagian atas layar Hari ini.
- [ ] **T6.2 (P0)** Android: notifikasi `ongoing` ringkasan tugas ter-pin ("3 belum selesai") dengan aksi cepat dan tidak bisa digeser; diperbarui saat data berubah.
- [ ] **T6.3 (P0)** Android: widget layar utama (`home_widget`) — daftar kartu ter-pin + checklist yang bisa dicentang langsung dari widget; sinkron ke Supabase di background.
- [ ] **T6.4 (P0)** Windows/desktop: **sticky window** tanpa bingkai, always-on-top, warna sticky, bisa diseret dan diubah ukuran, menampilkan kartu ter-pin dan checklist yang bisa dicentang; posisi/ukuran tersimpan.
- [ ] **T6.5 (P0)** Desktop: system tray (buka, jeda pengingat, keluar), minimize-to-tray, autostart saat login.
- [ ] **T6.6 (P1)** Beberapa sticky window (satu per kartu) dan mode "klik tembus" opsional.
- [ ] **T6.7 (P1, jika iOS)** Widget WidgetKit untuk kartu ter-pin.
- [ ] **T6.8 (P2)** Live Activity iOS untuk tugas yang sedang nagging.

**DoD:** Dari widget Android dan sticky window Windows, tugas bisa dicentang dan status tersinkron ke perangkat lain; notifikasi menetap Android selalu terlihat selama ada tugas ter-pin yang belum selesai.

---

## Fase 7 — Sinkronisasi real-time & offline

- [ ] **T7.1 (P0)** Langganan Realtime per board dan untuk `reminders`; gabungkan ke DB lokal (drift).
- [ ] **T7.2 (P0)** Cegah echo dari perangkat sendiri (`client_id`).
- [ ] **T7.3 (P0)** Cache lokal drift sebagai sumber UI; buka offline.
- [ ] **T7.4 (P0)** Antrean mutasi offline + retry backoff; indikator "Menyinkronkan/Offline".
- [ ] **T7.5 (P0)** Resolusi konflik LWW per field; **status selesai selalu menang**; tes dua perangkat mengedit kartu yang sama saat offline.
- [ ] **T7.6 (P1)** Sinkron penuh saat app kembali ke foreground.

**DoD:** Edit di HP muncul di desktop < 3 dtk; edit saat mode pesawat tersinkron setelah online tanpa membuat tugas selesai "hidup lagi".

---

## Fase 8 — Desktop poles

- [ ] **T8.1 (P0)** Tata letak desktop: sidebar, header board, panel detail kartu (STYLE.md §7).
- [ ] **T8.2 (P1)** Pintasan keyboard dan palet perintah (`Ctrl/Cmd+K`).
- [ ] **T8.3 (P0)** Installer Windows (MSIX atau Inno Setup); macOS/Linux sesuai keputusan.
- [ ] **T8.4 (P1)** Pembaruan otomatis.

**DoD:** Installer terpasang, login, nag native muncul dari tray.

---

## Fase 9 — Pencarian, pengaturan, aksesibilitas

- [ ] **T9.1 (P1)** Pencarian dan filter (label, jatuh tempo, ter-pin, belum selesai).
- [ ] **T9.2 (P1)** Pengaturan: tema, bahasa, zona waktu, default nag, jam tenang.
- [ ] **T9.3 (P1)** Audit aksesibilitas (kontras, Semantics, font 200%); hormati `MediaQuery.disableAnimations`.
- [ ] **T9.4 (P2)** Ekspor JSON.

**DoD:** Tidak ada temuan blocker pada audit aksesibilitas.

---

## Fase 10 — Kualitas & rilis

- [ ] **T10.1 (P0)** Tes unit (posisi, `NagPlan`, antrean sinkron), widget test, integration test alur utama.
- [ ] **T10.2 (P0)** Pelaporan crash (Sentry/Crashlytics) dan logging jadwal nag untuk debugging.
- [ ] **T10.3 (P0)** Tinjau keamanan: RLS, tanpa service key di klien, rate limit Edge Function.
- [ ] **T10.4 (P0)** Backup Supabase terjadwal.
- [ ] **T10.5 (P0)** Build rilis Android (APK/AAB), tanda tangan, uji di beberapa merek HP.
- [ ] **T10.6 (P1, jika iOS)** Build iOS + TestFlight.
- [ ] **T10.7 (P0)** Dogfooding 2 minggu; catat setiap nag yang terlewat atau berlanjut setelah selesai.

**DoD:** Metrik PRD §9 terpenuhi.

---

## Jalur tercepat ke versi yang berguna (MVP)

1. **Fase 0** (spike) → 1 → 2 → 3 → 4.
2. **Fase 5** (nag) lalu **Fase 6** (sticky) — ini nilai inti, dahulukan sebelum offline penuh.
3. Fase 7 → 8 → 9 → 10.

MVP minimum: **T0.1–T0.4 + T1 + T2 + T3 + T4.1–4.8 + T5.1–5.12 + T6.2–T6.5** di Android + Windows.
