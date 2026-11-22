# PRD — Nudge

Versi: 0.2 (draft) · Tanggal: 2026-11-22
Perubahan dari 0.1: stack diganti ke Flutter; konsep diperluas menjadi gabungan **Trello + sticky note + alarm** dengan pengingat yang terus berulang sampai tugas ditandai selesai.

## 1. Ringkasan

Aplikasi to-do bergaya Trello (board → list → kartu) yang **menempel** di layar seperti sticky note dan **terus mengingatkan seperti alarm** selama tugas belum dicentang. Berjalan di Android, iOS, dan desktop (Windows/macOS/Linux) dari satu codebase Flutter. Data disimpan di Supabase sehingga edit di HP muncul di desktop dan sebaliknya, dan menyelesaikan tugas di satu perangkat menghentikan peringatan di semua perangkat.

Tiga pilar:
1. **Trello:** board, list, kartu, checklist, drag-and-drop.
2. **Sticky note:** tugas penting bisa di-*pin* dan terlihat terus (widget layar utama Android, notifikasi menetap, jendela sticky di desktop). Todo bisa dicentang langsung dari sana.
3. **Alarm/nagging:** tugas yang belum selesai terus memunculkan peringatan dengan interval dan eskalasi yang bisa diatur, sampai ditandai selesai.

## 2. Masalah & Tujuan

**Masalah:** Pengingat biasa cukup sekali bunyi lalu terlupakan. Pengguna butuh sistem yang menuntut tindakan: tugas tetap terlihat dan terus mengganggu sampai selesai.

**Tujuan v1:**
1. Kelola todo dengan board/list/kartu dan checklist, bisa diedit penuh di HP maupun desktop.
2. Peringatan berulang (nag) sampai tugas dicentang, dengan eskalasi (tenang → keras → layar penuh).
3. Tugas ter-pin terlihat terus: widget Android, notifikasi menetap, sticky window desktop.
4. Sinkron real-time antar perangkat; tetap berfungsi offline.
5. Data privat per pengguna lewat Supabase Auth + RLS.

**Bukan tujuan v1:** kolaborasi tim penuh, integrasi pihak ketiga, lampiran besar, billing.

## 3. Pengguna

Utama: pemilik aplikasi (pengguna tunggal). Desain data multi-user (RLS per `user_id`) agar berbagi board bisa ditambah di v2.

## 4. Keputusan Teknis

| Area | Pilihan | Alasan |
|---|---|---|
| Framework | **Flutter** (Dart), satu codebase Android/iOS/Windows/macOS/Linux | Permintaan pengguna; UI konsisten, desktop native |
| Backend | Supabase: Postgres, Auth, Realtime, Edge Functions, pg_cron | Sesuai permintaan |
| Klien Supabase | `supabase_flutter` | Resmi |
| State | Riverpod | Sederhana, mudah diuji |
| Penyimpanan lokal/offline | `drift` (SQLite) + antrean mutasi | Baca offline, tulis ditunda lalu disinkron |
| Navigasi | `go_router` | Deep link dari notifikasi |
| Notifikasi lokal | `flutter_local_notifications` (+ `timezone`) | Terjadwal, aksi tombol, ongoing |
| Push | Firebase Cloud Messaging (Android/iOS) via Edge Function | Cadangan dan sinkron lintas perangkat |
| Widget layar utama | `home_widget` (Android; iOS WidgetKit jika iOS dipakai) | Sticky note di home screen |
| Desktop | `window_manager`, `tray_manager`, `launch_at_startup`, `local_notifier` | Tray, always-on-top, notifikasi native, autostart |
| Drag & drop | `ReorderableListView` / `drag_and_drop_lists` atau kustom dengan `Draggable` | Native Flutter |
| i18n | `flutter_localizations` + `intl` (id/en) | |

### Mesin pengingat (nag engine) — inti teknis

Prinsip: **jadwal dibuat di perangkat (lokal), server hanya cadangan.** Notifikasi lokal tetap bunyi walau tidak ada internet dan app tertutup.

- Setiap tugas yang belum selesai punya rangkaian kejadian: `T0` (waktu pengingat), lalu `T0 + n × interval` sampai `maks_nag` atau selesai.
- Saat dicentang di perangkat mana pun: batalkan semua notifikasi terjadwal tugas itu di perangkat ini, kirim perubahan ke Supabase, perangkat lain menerima Realtime/push "silent" lalu membatalkan jadwal lokalnya.
- **Android (andal):** alarm tepat waktu (`SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`), channel prioritas tinggi, notifikasi `ongoing` (tidak bisa digeser) untuk tugas ter-pin, opsi *full-screen intent* untuk eskalasi tertinggi, dan penjadwalan ulang setelah reboot (`RECEIVE_BOOT_COMPLETED`). Perlu panduan pengecualian optimasi baterai.
- **iOS (terbatas, perlu transparan ke pengguna):** iOS tidak mengizinkan notifikasi menetap dan membatasi 64 notifikasi lokal terjadwal. Strategi: jadwalkan rantai pendek (mis. 10–20 pengingat berikutnya) per tugas aktif dengan level *Time Sensitive*, isi ulang saat app dibuka dan lewat push silent. *Critical Alerts* (menembus Jangan Ganggu) butuh entitlement khusus dari Apple, jadi dianggap opsional.
- **Desktop:** notifikasi native + jendela pop-up always-on-top untuk eskalasi; nag hanya berjalan saat app hidup, maka app berjalan di system tray dan autostart saat login.
- **Cadangan server:** pg_cron memicu Edge Function tiap menit; fungsi mencari tugas yang jatuh tempo nag-nya dan belum selesai, lalu kirim push FCM. Berguna jika jadwal lokal terhapus (mis. app dipaksa tutup di beberapa perangkat Android).

## 5. Fitur & Kebutuhan Fungsional

### 5.1 Autentikasi (P0)
Email+password dan magic link; Google OAuth opsional (P2). Sesi tersimpan aman (`flutter_secure_storage`). Keluar dan hapus akun.

### 5.2 Board & List (P0)
Buat, ubah, urutkan, arsipkan, hapus board dan list. Warna board. Daftar board urut terakhir dibuka.

### 5.3 Kartu / Todo (P0)
- Judul, deskripsi, jatuh tempo, label, **checklist** (item dapat ditambah, diedit, dicentang, diurutkan).
- Edit penuh dari HP: tambah/ubah/hapus kartu dan item checklist, pindah antar list lewat drag atau menu "Pindahkan ke…".
- Tandai selesai (satu ketukan). Opsi: kartu otomatis selesai saat semua item checklist tercentang.
- Quick add di bawah list; quick add global dari notifikasi menetap/widget (P1).

### 5.4 Pengingat & Nagging (P0 — fitur inti)
Per kartu:
- **Waktu pengingat** (absolut atau relatif ke jatuh tempo) dan pengulangan tugas (harian/mingguan/bulanan).
- **Kebijakan nag:** aktif/tidak, interval (1, 5, 10, 15, 30, 60 mnt; default 10), maksimum jumlah nag atau "sampai selesai", jam tenang (mis. 22:00–07:00, bisa dikecualikan untuk tugas penting).
- **Eskalasi** (opsional, bertahap): level 1 notifikasi biasa → level 2 suara keras + getar panjang → level 3 layar penuh/pop-up always-on-top (Android full-screen intent, desktop jendela). Pemicu: setelah N kali nag diabaikan.
- **Aksi di notifikasi:** **Selesai**, **Tunda** (5/15/60 mnt/besok), **Buka**. Tunda menggeser rantai nag, bukan menghapusnya.
- Nag berhenti hanya saat: ditandai selesai, diarsip/dihapus, atau batas nag tercapai (kemudian tugas ditandai "terlewat" dan tetap tampil merah).
- Pengaturan default global (interval, eskalasi, jam tenang) yang bisa ditimpa per kartu.

### 5.5 Sticky / Pin (P0 untuk Android & desktop, P1 iOS)
- Kartu dapat di-**pin**. Kartu ter-pin tampil di:
  - **Widget layar utama Android:** daftar tugas ter-pin dengan checklist yang bisa dicentang langsung dari widget.
  - **Notifikasi menetap Android** (ongoing) berisi ringkasan "3 tugas belum selesai" dengan aksi cepat.
  - **Sticky window desktop:** jendela kecil tanpa bingkai, always-on-top, warna ala sticky note, bisa diseret dan diubah ukuran, menampilkan kartu ter-pin dan checklist yang bisa dicentang.
  - **iOS:** widget WidgetKit (P1) dan Live Activity (P2); tanpa notifikasi menetap.
- Layar **Hari ini**: semua tugas belum selesai (terlambat, hari ini, ter-pin) dalam satu daftar.

### 5.6 Sinkronisasi (P0)
Supabase Realtime untuk perubahan antar perangkat dalam hitungan detik. Optimistic update dengan rollback. Offline: cache lokal + antrean mutasi. Konflik: last-write-wins per field via `updated_at`. **Penyelesaian tugas harus diutamakan**: status selesai selalu menang atas edit lain agar nag tidak berlanjut karena konflik.

### 5.7 Pencarian & filter (P1)
Cari judul/deskripsi; filter label, jatuh tempo, ter-pin, belum selesai.

### 5.8 Lainnya
Tema terang/gelap (P1); pintasan keyboard desktop (P1); ekspor JSON (P2); berbagi board (v2).

## 6. Model Data (Supabase / Postgres)

Semua tabel: `id uuid pk default gen_random_uuid()`, `created_at`, `updated_at`.

- `boards`: `user_id`, `title`, `color`, `position`, `archived_at`
- `lists`: `board_id`, `title`, `position numeric`, `archived_at`
- `cards`: `list_id`, `board_id`, `user_id`, `title`, `description`, `due_at`, `position numeric`, `completed_at`, `archived_at`, `pinned bool default false`, `sticky_color text`, `auto_complete_on_checklist bool`
- `labels`, `card_labels`
- `checklist_items`: `card_id`, `text`, `done bool`, `done_at`, `position`
- `reminders`: `card_id`, `user_id`, `remind_at timestamptz`, `rrule text null`, `offset_minutes int null`, `nag_enabled bool default true`, `nag_interval_minutes int default 10`, `nag_max_count int null`, `escalation jsonb null` (mis. `[{"after":3,"level":2},{"after":6,"level":3}]`), `quiet_hours jsonb null`, `snoozed_until timestamptz null`, `nag_count int default 0`, `last_nag_at timestamptz null`, `state text` (`scheduled | nagging | done | missed`)
- `user_settings`: `user_id pk`, `default_nag_interval`, `default_escalation jsonb`, `quiet_hours jsonb`, `timezone`, `theme`, `locale`
- `devices`: `user_id`, `platform`, `push_token`, `last_seen_at`

Ketentuan:
- Posisi numeric dengan fractional indexing; sisip di antara dua nilai.
- Trigger `updated_at`; soft delete via `archived_at`.
- Trigger: saat `cards.completed_at` terisi, set `reminders.state = 'done'` untuk kartu itu.
- **RLS aktif di semua tabel** berbasis `auth.uid()`.
- Realtime aktif untuk `boards`, `lists`, `cards`, `checklist_items`, `reminders`.
- Edge Function `nag-dispatcher` (dijadwalkan pg_cron tiap menit) memakai service role di sisi server saja.

## 7. Kebutuhan Non-Fungsional

- Keandalan: pengingat tidak boleh terlewat; jadwal dibangun ulang saat app dibuka, reboot, ganti zona waktu, atau data berubah.
- Latensi: perubahan tersinkron < 3 dtk; status selesai menghentikan nag lintas perangkat < 5 dtk saat online.
- Performa: buka board < 1 dtk dari cache; drag 60 fps.
- Keamanan: RLS ketat; service key tidak pernah ada di klien; token di secure storage.
- Aksesibilitas: target sentuh ≥ 44 px, kontras AA, dukung screen reader, ukuran font sistem hingga 200%.
- Kenyamanan pengguna: nag bisa sangat mengganggu, jadi wajib ada jam tenang, batas nag, dan tombol "jeda semua pengingat" yang jelas.
- Zona waktu: simpan UTC, tampil lokal. Bahasa: Indonesia dan Inggris.

## 8. Alur Utama

1. Buka app → masuk → daftar board → buka board.
2. Tambah kartu, isi checklist, set pengingat + nag, pin kartu.
3. Kartu ter-pin muncul di widget/sticky window dan notifikasi menetap.
4. Waktu tiba → notifikasi; tidak diindahkan → nag berulang dengan eskalasi.
5. Centang selesai dari notifikasi, widget, atau app → semua perangkat berhenti mengingatkan.
6. Edit checklist di HP kapan saja → tersinkron ke desktop.

## 9. Metrik Keberhasilan

- ≥ 99% nag berbunyi dalam ±1 menit dari jadwal (Android fisik, app tertutup) selama uji 2 minggu.
- 0 kasus nag berlanjut setelah tugas selesai.
- Sinkron antar perangkat < 3 dtk; crash-free session > 99%.

## 10. Risiko & Mitigasi

| Risiko | Mitigasi |
|---|---|
| Android menghemat baterai dan membunuh app/alarm | Alarm tepat waktu, panduan pengecualian baterai, cadangan push dari server |
| Aturan Play Store untuk `USE_EXACT_ALARM` dan full-screen intent | Posisikan app sebagai alarm/pengingat; siapkan fallback `SCHEDULE_EXACT_ALARM` (izin dari pengguna); full-screen hanya untuk eskalasi akhir |
| **iOS tidak mendukung notifikasi menetap dan membatasi 64 notifikasi** | Rantai nag pendek + isi ulang + push; widget; jelaskan keterbatasan; Critical Alerts butuh persetujuan Apple |
| Desktop mati saat app ditutup | Tray, autostart, push sebagai cadangan |
| Nag terasa menyebalkan | Jam tenang, batas nag, eskalasi bertahap, tombol jeda global |
| Konflik offline membuat tugas selesai "hidup lagi" | Status selesai selalu menang; uji dua perangkat |
| Ukuran/kompleksitas Flutter desktop plugin | Spike awal untuk tray, always-on-top, dan notifikasi |

## 11. Pertanyaan Terbuka

1. Perlu iOS? Jika ya, terima keterbatasan notifikasi menetap dan 64 jadwal (butuh akun Apple Developer berbayar).
2. Desktop: Windows saja, atau juga macOS/Linux?
3. Perlu berbagi board dengan orang lain di v1?
4. Eskalasi layar penuh: mau default aktif atau harus dinyalakan per kartu?
5. Cek ketersediaan nama "Nudge" di Play Store, App Store, dan domain sebelum menetapkan application ID (mis. `com.<namamu>.nudge`).
