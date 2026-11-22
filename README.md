# Nudge

Todo yang menempel dan terus mengingatkan: gabungan Trello (board, list, kartu),
sticky note, dan alarm. Satu codebase Flutter untuk Android dan desktop, data
disimpan di Supabase supaya HP dan desktop selalu sama.

Dokumen produk ada di [`docs/`](docs): [PRD](docs/PRD.md), [STYLE](docs/STYLE.md),
[TASKS](docs/TASKS.md).

## Status

| Area | Status |
|---|---|
| Board, list, kartu, checklist, drag and drop | Selesai, teruji di emulator Android |
| Pengingat + nag berulang, eskalasi, jam tenang, tunda | Selesai, teruji (notifikasi asli + tombol asli di emulator) |
| Layar Hari ini, jeda semua pengingat, peringatan izin | Selesai, teruji |
| Pin / sticky note (kartu berwarna, notifikasi menetap Android) | Selesai, teruji (notifikasi asli, flag `ONGOING`, tombol Selesai) |
| Offline-first + sync (LWW, tombstone, antrean otomatis) | Selesai, teruji terhadap server tiruan dengan dua perangkat |
| Login (email+password, magic link, reset), Pengaturan, tema | Selesai, teruji dengan backend auth tiruan |
| Skema Supabase, RLS, trigger, grants | Teruji di Supabase asli: 20 pemeriksaan (`tool/live_check.dart`) |
| Sync dua perangkat lewat Supabase asli + realtime | Teruji di emulator (`integration_test/e2e_supabase_test.dart`) |
| Widget layar utama Android, sticky window desktop, tray | Lihat `docs/TASKS.md` |
| iOS | Belum (butuh Mac + akun Apple Developer) |

## Menjalankan

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # kode drift
flutter run                                                # mode lokal, tanpa login
```

Tanpa konfigurasi Supabase, app berjalan dalam **mode lokal**: tidak ada login,
data hanya di perangkat.

## Menghubungkan Supabase

1. Buat project di [supabase.com](https://supabase.com).
2. Jalankan migrasi di `supabase/migrations/` secara berurutan (SQL Editor di
   dashboard, atau `supabase db push`). `..._grants.sql` wajib: tanpa itu muncul
   `permission denied for table`.
3. (Opsional, disarankan) jalankan `supabase test db` untuk tes RLS di
   `supabase/tests/rls_test.sql`.
4. Authentication > URL Configuration: tambahkan redirect `com.bayu.nudge://login-callback/`.
5. Jalankan app dengan kunci project:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://XXXX.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Kunci publishable/anon aman ada di klien; keamanan data dijaga RLS. **Jangan
pernah** menaruh `service_role` key di app.

## Tes

```bash
flutter analyze
flutter test                                           # unit test murni
flutter test integration_test -d <emulator-id>         # tes UI + database di perangkat
```

Tes end-to-end dengan notifikasi Android asli (butuh emulator/HP, tidak ikut
suite biasa):

```bash
# terminal 1
flutter test integration_test/e2e_sticky_test.dart --dart-define=NUDGE_E2E=true -d emulator-5554
# terminal 2: menekan tombol notifikasi lewat adb
powershell -File tool/drive_notification_actions.ps1 -Steps Selesai
```

## Catatan platform

- **Android**: alarm tepat waktu (`USE_EXACT_ALARM`), 3 channel eskalasi,
  notifikasi menetap untuk kartu ter-pin. Beberapa merek HP (Xiaomi, Oppo,
  Vivo) agresif mematikan app di latar belakang; beri pengecualian baterai.
  `USE_EXACT_ALARM` ditinjau kebijakan Google Play.
- **iOS** tidak mendukung notifikasi menetap dan membatasi 64 notifikasi
  terjadwal; nag di iOS tidak akan seandal Android.
- **Desktop** hanya bisa mengingatkan saat app berjalan (tray + autostart).
- Konflik sync: *last write wins* per baris berdasarkan `updated_at`.
  Penyelesaian tugas yang dilakukan sebelum edit lain tetap menang karena edit
  lama ditolak server.
