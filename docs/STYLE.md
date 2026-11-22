# STYLE — Panduan Desain Nudge

Arah visual: **tenang, fokus, seperti kertas catatan**. Bukan klon Trello biru. Permukaan hangat, aksen tunggal yang jelas, kepadatan informasi sedang, gerak halus dan fungsional.

## 1. Prinsip

1. **Pengingat adalah bintangnya.** Waktu jatuh tempo dan status pengingat selalu terbaca sekilas di kartu.
2. **Satu aksen.** Warna aksen hanya untuk aksi utama, fokus, dan status aktif. Sisanya netral.
3. **Konsisten lintas platform.** Token sama di mobile dan desktop; hanya tata letak dan interaksi yang menyesuaikan.
4. **Cepat ditangkap.** Menambah kartu maksimal dua ketukan.
5. **Gerak bermakna.** Animasi hanya untuk menjelaskan perubahan (pindah, muncul, selesai), tidak dekoratif.

## 2. Warna (design tokens)

### Terang
| Token | Nilai | Pemakaian |
|---|---|---|
| `bg.app` | `#F6F3EE` | Latar aplikasi (putih hangat) |
| `bg.surface` | `#FFFFFF` | Kartu, sheet, modal |
| `bg.list` | `#EDE9E1` | Kolom list |
| `bg.hover` | `#E4DFD5` | Hover/pressed |
| `text.primary` | `#1E1B16` | Teks utama |
| `text.secondary` | `#6B655A` | Teks pendukung |
| `text.disabled` | `#A8A196` | Nonaktif |
| `border.subtle` | `#DDD7CB` | Garis tipis |
| `accent` | `#3B5BDB` | Aksi utama, fokus |
| `accent.hover` | `#2F49B5` | Hover aksen |
| `accent.soft` | `#E3E9FD` | Latar aksen lembut |

### Gelap
| Token | Nilai |
|---|---|
| `bg.app` | `#141310` |
| `bg.surface` | `#1F1D19` |
| `bg.list` | `#191814` |
| `bg.hover` | `#2A2823` |
| `text.primary` | `#F2EEE6` |
| `text.secondary` | `#A9A294` |
| `border.subtle` | `#33302A` |
| `accent` | `#7C97FF` |
| `accent.soft` | `#22294A` |

### Semantik
| Token | Terang | Gelap | Pemakaian |
|---|---|---|---|
| `success` | `#2F9E62` | `#4CC38A` | Selesai |
| `warning` | `#D98A0B` | `#F0A93A` | Jatuh tempo hari ini |
| `danger` | `#D63C3C` | `#FF6B6B` | Terlambat, hapus |

### Warna label (8, dipakai pada board & label)
`#E5484D` merah · `#F76B15` oranye · `#F5C400` kuning · `#30A46C` hijau · `#12A594` teal · `#3E63DD` biru · `#8E4EC6` ungu · `#E93D82` merah muda. Label selalu disertai teks/ikon, tidak hanya warna.

Aturan kontras: teks biasa ≥ 4.5:1, teks besar dan ikon ≥ 3:1. Verifikasi sebelum menambah warna baru.

## 3. Tipografi

- Font utama: **Inter** (fallback: system-ui). Judul board boleh memakai **Instrument Serif** untuk sentuhan editorial (opsional, hanya judul besar).
- Angka waktu memakai `font-variant-numeric: tabular-nums`.

| Gaya | Ukuran/Line | Berat | Pemakaian |
|---|---|---|---|
| `display` | 28/34 | 600 | Judul board |
| `title` | 20/26 | 600 | Judul layar, modal |
| `heading` | 16/22 | 600 | Judul list |
| `body` | 15/22 | 400 | Teks kartu, deskripsi |
| `body-strong` | 15/22 | 600 | Penekanan |
| `caption` | 13/18 | 500 | Meta, tanggal, label |
| `micro` | 11/14 | 600 | Lencana, hitungan |

Mobile boleh menaikkan `body` ke 16 untuk mencegah zoom otomatis pada input iOS.

## 4. Jarak, Bentuk, Elevasi

- Skala jarak (px): 2, 4, 8, 12, 16, 24, 32, 48.
- Radius: `sm` 6 (lencana), `md` 10 (kartu, input), `lg` 14 (list, sheet), `full` 999 (chip, avatar).
- Garis: 1 px `border.subtle`. Hindari bayangan berat.
- Elevasi: `e0` tanpa; `e1` `0 1px 2px rgba(30,27,22,.08)` kartu; `e2` `0 8px 24px rgba(30,27,22,.14)` menu/modal; kartu yang diseret memakai `e2` + rotasi 2°.
- Target sentuh minimum 44×44 px; jarak antar target ≥ 8 px.

## 5. Ikon

Satu keluarga ikon garis 1.75 px (Lucide). Ukuran 16 (inline), 20 (default), 24 (navigasi). Ikon pengingat: lonceng; selesai: centang; tunda: jam; jatuh tempo: kalender.

## 6. Komponen

### Kartu
- Latar `bg.surface`, radius `md`, `e1`, padding 12.
- Baris atas: strip label (tinggi 6, pill) bila ada.
- Judul `body`, maksimal 3 baris.
- Baris meta (`caption`): chip jatuh tempo, ikon lonceng bila ada pengingat, progres checklist `2/5`, ikon deskripsi.
- Chip jatuh tempo: netral (jauh), `warning` (hari ini), `danger` (terlambat), `success` (selesai, judul dicoret).
- Lingkaran centang di kiri judul untuk menyelesaikan cepat.

### List (kolom)
- Lebar 280 px di desktop; di mobile satu list selebar layar dengan peek 16 px list berikutnya.
- Header: judul `heading` + jumlah kartu `micro` + menu ⋯.
- Footer: tombol "+ Tambah kartu" (ghost, lebar penuh).

### Tombol
- Primer: latar `accent`, teks putih, tinggi 40 (mobile 48), radius `md`.
- Sekunder: latar `bg.hover`, teks `text.primary`.
- Ghost: tanpa latar, teks `text.secondary`, hover `bg.hover`.
- Destruktif: teks/latar `danger`, selalu dengan konfirmasi.
- Fokus: cincin 2 px `accent` dengan offset 2.

### Input
Tinggi 40/48, radius `md`, garis `border.subtle`, fokus garis `accent` + cincin `accent.soft`. Label di atas, bukan placeholder-only. Pesan galat di bawah dengan `danger` + ikon.

### Pemilih pengingat
Bottom sheet (mobile) / popover (desktop): pintasan cepat ("10 menit lagi", "Nanti malam", "Besok pagi", "Pilih sendiri…"), lalu pemilih tanggal/jam, opsi ulang, dan daftar pengingat yang sudah ada.

### Notifikasi
Judul = judul kartu. Isi = nama board › list + waktu. Aksi: **Selesai**, **Tunda**. Ikon kecil monokrom, warna aksen.

### Lainnya
- Toast di bawah (mobile) / kanan bawah (desktop), 4 dtk, dengan aksi "Urungkan".
- Empty state: ilustrasi garis sederhana + satu kalimat + satu tombol.
- Skeleton loading berbentuk kartu, bukan spinner penuh layar.

## 7. Tata Letak per Platform

### Mobile (< 768 px)
- Bottom tab: **Hari ini · Board · Cari · Profil**.
- Board: list horizontal dengan snap per list; tahan-lama pada kartu untuk drag; tombol "+" melayang di kanan bawah.
- Detail kartu: halaman penuh yang naik dari bawah (sheet 92%).
- Aman area: hormati notch dan home indicator.

### Tablet/Desktop (≥ 768 px)
- Sidebar kiri 240 px (daftar board, Hari ini, Mendatang, Cari), dapat dilipat.
- Area board: scroll horizontal, header board sticky dengan judul, filter, dan menu.
- Detail kartu: modal tengah 720 px atau panel kanan 420 px.
- Pintasan keyboard ditampilkan di tooltip dan palet perintah (`Ctrl/Cmd + K`).
- Bilah judul jendela desktop: native, atau kustom (`window_manager`) dengan warna `bg.app`.

## 8. Gerak

| Aksi | Durasi | Easing |
|---|---|---|
| Hover/pressed | 120 ms | ease-out |
| Buka modal/sheet | 220 ms | cubic-bezier(.2,.8,.2,1) |
| Pindah kartu (settle) | 180 ms | spring (damping 20) |
| Centang selesai | 240 ms | ease-out + coret judul |
| Toast masuk/keluar | 200 ms | ease-out |

Hormati pengaturan sistem "kurangi gerakan" (`MediaQuery.disableAnimations`): ganti dengan fade 100 ms, matikan rotasi drag.

## 9. Konten & Nada Bahasa

Singkat, ramah, tidak menggurui. Contoh: "Belum ada kartu. Tambahkan yang pertama." Galat menjelaskan apa yang terjadi dan apa yang bisa dilakukan: "Tidak ada koneksi. Perubahanmu disimpan dan akan dikirim saat online." Format tanggal relatif ("Hari ini 14:00", "Besok", "Sen, 24 Nov") sesuai lokal.

## 10. Aksesibilitas

- Semua kontrol punya nama aksesibel; drag-and-drop punya alternatif menu "Pindahkan ke…".
- Urutan fokus mengikuti urutan visual; modal menjebak fokus dan mengembalikannya saat ditutup.
- Status tidak hanya lewat warna (selalu ada ikon/teks).
- Dukung ukuran font sistem hingga 200% tanpa terpotong.

## 11. Sticky Note & Status Nagging

### Warna sticky (kartu ter-pin dan jendela sticky desktop)
Latar pastel hangat, teks tetap `text.primary` gelap (kontras ≥ 4.5:1, termasuk di tema gelap: sticky tetap terang).
| Nama | Latar | Tepi |
|---|---|---|
| Kuning | `#FFF3B0` | `#E8D35F` |
| Persik | `#FFD9C2` | `#E9A988` |
| Mint | `#D3F1DE` | `#8CCBA6` |
| Langit | `#D6E6FF` | `#8FB3EE` |
| Lavender | `#E6DCFA` | `#B6A2E3` |

- Bentuk: radius `md`, bayangan `e1`, lipatan sudut kanan bawah kecil sebagai penanda ter-pin (ikon pin di kiri atas).
- Judul `body-strong`, checklist `body`, tulisan item selesai dicoret dan diberi `text.secondary`.
- Jendela sticky desktop: tanpa bingkai, tepi tipis, tombol kecil muncul saat hover (pin/lepas, warna, tutup), area tarik di bagian atas, tinggi menyesuaikan jumlah item.
- Widget Android: ukuran 2×2 (satu kartu) dan 4×3 (daftar), checkbox 44 px yang bisa diketuk.

### Status nagging pada kartu
| Status | Tampilan |
|---|---|
| Terjadwal | Ikon lonceng `text.secondary` + waktu |
| Sedang nag | Lonceng `warning` dengan denyut halus (hilang jika reduced motion) + "Nag ke-3" |
| Eskalasi level 2/3 | Tepi kartu `danger` 2 px, lonceng `danger` |
| Terlewat (missed) | Chip `danger` "Terlewat", judul tetap tidak dicoret |
| Selesai | Centang `success`, judul dicoret, tepi netral |

### Layar peringatan penuh (eskalasi level 3)
Latar `danger` lembut atau warna sticky kartu, judul besar (`display`), checklist yang bisa dicentang, dua tombol besar: **Selesai** (primer) dan **Tunda** (sekunder). Wajib bisa ditutup dengan jelas; tidak boleh menjebak pengguna.

## 12. Implementasi Token (Flutter)

Satu berkas `lib/core/theme/tokens.dart` sebagai sumber tunggal: kelas `AppColors`, `AppSpacing`, `AppRadius`, `AppTextStyles`. Dibungkus sebagai `ThemeExtension` (`AppTokens`) pada `ThemeData` terang dan gelap, dibaca lewat `Theme.of(context).extension<AppTokens>()`. Tema dipilih lewat `ThemeMode.system` dengan penimpaan manual di Pengaturan. Font Inter dimasukkan sebagai aset (bukan diunduh saat runtime) agar tampil benar saat offline. Ikon: paket `lucide_icons`.
