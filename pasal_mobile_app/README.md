# CariPasal Mobile App

Aplikasi pencarian pasal hukum Indonesia berbasis Offline-First (Local Database).

## Struktur Project & Fungsi File

Berikut adalah panduan navigasi struktur kode untuk pengembang:

### Screens (`lib/ui/screens/`)

| File                             | Fungsi Utama                                                                                                                              |
| :------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------- |
| **`splash_screen.dart`**         | Layar pembuka. Mengecek database dan menginisialisasi SyncManager. Jika kosong -> Onboarding. Jika ada -> MainNavigation + cek update.    |
| **`onboarding_screen.dart`**     | Layar download awal database dari server (Supabase) ke HP (Drift/SQLite). Hanya muncul saat instalasi pertama.                            |
| **`../widgets/main_navigation.dart`** | Navigasi Beranda, Pustaka, dan Tersimpan: bar bawah, rail, atau sidebar menurut lebar jendela. Tab yang pernah dibuka mempertahankan state. |
| **`home_screen.dart`**           | **Dashboard Utama**. Fitur: Search Global (hasil dikelompokkan per kecocokan), Filter Bab lalu Judul, Filter Kategori UU, List Pasal Terbaru |
| **`library_screen.dart`**        | Tab Pustaka. Daftar UU dan pilihan UU tetap tersimpan saat resize atau berganti tab. |
| **`detail_uu_screen.dart`**      | Daftar pasal dalam UU beserta pencariannya; layar lebar menampilkan daftar dan pembaca berdampingan. |
| **`read_pasal_screen.dart`**     | Pembaca pasal dengan lebar teks terbatas, pencarian, prev/next, penjelasan, pasal terkait, dan riwayat. Sidebar bab muncul bila ruang panel cukup. `onBack` opsional menutup pembaca inline; pemanggil route tetap kembali lewat Navigator. |
| **`search_screen.dart`**         | _(Legacy/Opsional)_ Halaman pencarian khusus jika menggunakan `showSearch` bawaan Flutter. Saat ini pencarian sudah terintegrasi di Home. |
| **`bab_result_screen.dart`**     | Daftar semua pasal dalam satu bab. Dibuka dari baris bab di layar baca pasal.                                                            |

### Widgets (`lib/ui/widgets/`)

| File                     | Fungsi                                                                                                      |
| :----------------------- | :---------------------------------------------------------------------------------------------------------- |
| **`law_content_formatter.dart`** | Pemformat teks hukum (daftar `(1)`, `a.`, `1.`, indentasi, highlight pencarian). Dipakai untuk **Isi** dan **Penjelasan**; label penjelasan (`Ayat (n)`, `Huruf x`, `Angka n`) menjadi sub-judul. Ekspor PDF memakai logika pemisahan yang sama. |
| **`main_layout.dart`**   | Scaffold, banner pembaruan, SafeArea, dan konten terpusat maksimum 1200 logical px. |
| **`pasal_card.dart`**    | Komponen UI Kartu Pasal. Digunakan berulang-ulang di Home, DetailUU, dan Search Result.                     |
| **`update_banner.dart`** | Banner notifikasi update. Muncul otomatis jika ada data baru di server dan sync sudah lama tidak dilakukan. |
| **`adaptive_pasal_browser.dart`** | Pemilik pilihan pasal dan konteks hasil. Daftar/pembaca tetap mounted saat resize; `PasalCard` memakai browser terdekat, atau route biasa jika tidak ada browser. Back pada panel aktif menutup pasal dahulu, lalu kembali ke pilihan UU. |

### Services (`lib/core/services/`)

| File                    | Fungsi                                                                                                                                            |
| :---------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------ |
| **`data_service.dart`** | **Otak Data**. Jembatan antara UI dengan Database Lokal (Drift) dan Server (Supabase). Termasuk sync data, fetch pasal_links, dan error handling. |
| **`sync_manager.dart`** | **Pengatur Sinkronisasi Otomatis**. Menyimpan timestamp sync terakhir, mengecek apakah perlu update, dan menampilkan status sync.                 |

### Database (`lib/core/database/`)

| File                      | Fungsi                                                                                    |
| :------------------------ | :---------------------------------------------------------------------------------------- |
| **`app_database.dart`**   | Definisi Tabel Database Lokal (SQLite/Drift). Termasuk tabel `undang_undang`, `pasal`, `pasal_links`, dan `pasal_versi` (riwayat). |
| **`app_database.g.dart`** | File auto-generated oleh Drift. Jangan edit manual.                                       |

### Utils & Config

| File                               | Fungsi                                                                                              |
| :--------------------------------- | :-------------------------------------------------------------------------------------------------- |
| **`core/utils/word_diff.dart`**    | Word diff murni Dart (token kata/spasi/tanda baca, pangkas awalan-akhiran, LCS di bagian tengah). Dipakai layar Riwayat perubahan. |
| **`utils/highlight_text.dart`**    | Widget khusus untuk mewarnai teks (kuning) sesuai kata kunci pencarian.                             |
| **`utils/image_helper.dart`**      | Mengatur logika gambar cover buku dan warna tema per buku (Merah untuk KUHP, Hijau untuk ITE, dll). |
| **`config/app_theme.dart`**        | Satu-satunya definisi tema Material 3 (terang + gelap), dibangun dari warna merek di `app_colors.dart`. |
| **`config/theme_controller.dart`** | Mengatur State Dark Mode/Light Mode dan menyimpannya ke memori HP (Shared Preferences).             |
| **`ui/utils/responsive_layout.dart`** | Breakpoint bersama dan `ResponsiveContent` untuk membatasi lebar tanpa membuat scroll atau controller baru. |
| **`config/env.dart`**              | Konfigurasi environment (Supabase URL dan Anon Key).                                                |

### Models (`lib/models/`)

| File                           | Fungsi                                                                         |
| :----------------------------- | :----------------------------------------------------------------------------- |
| **`pasal_model.dart`**         | Model data untuk Pasal. Termasuk `relatedIds` untuk pasal terkait.             |
| **`pasal_versi_model.dart`**   | Satu versi isi pasal (status, sumber, tanggal, naskah resmi, isi, penjelasan). |
| **`undang_undang_model.dart`** | Model data untuk Undang-Undang. Termasuk `deskripsi` untuk informasi tambahan. |

---

## PWA offline dan instalasi

Build web melalui satu entrypoint, bukan `flutter build web` langsung:

```bash
dart run tool/build_web.dart --release --base-href=/mobile/
node --test test/web/*.cjs
```

Builder menonaktifkan CDN runtime Flutter, memakai template `web/flutter_bootstrap.js`, dan menghasilkan `caripasal-sw.js` serta `offline-build.json`. Seluruh file runtime, SQLite/Drift worker, font, dan aset dibubuhi SHA-256. Jangan menambal file setelah generator berjalan. Cache bernama berdasarkan scope dan versi; pemasangan worker baru gagal bila file kurang atau hash berbeda. Worker hanya menangani navigasi aplikasi dan aset yang dikenal, bukan API, token, atau respons autentikasi. Worker cleanup bawaan Flutter tidak dipublikasikan.

Panel offline di Profil/Pengaturan menggabungkan kelengkapan cache app-shell, waktu sinkronisasi yang sudah selesai, keberadaan data di Drift, dan masa akses akun/offline. `Siapkan offline` meminta penyimpanan persisten dari browser dan memperbaiki file cache yang hilang; izin yang ditolak tetap ditampilkan. Aplikasi tetap dapat dipakai tanpa izin persisten, tetapi browser dapat membersihkan penyimpanannya. Masa akses tidak diperpanjang oleh cache atau instalasi.

`Pasang aplikasi` memanggil prompt browser hanya setelah klik dan hanya bila event `beforeinstallprompt` tersedia. Prompt sekali pakai dibuang sesudah digunakan; pembatalan tidak dianggap terpasang. Tanpa prompt, tombol membuka panduan browser/Safari. `appinstalled` atau mode standalone mengubah tombol menjadi status terpasang. Lihat [batas API prompt](https://developer.mozilla.org/en-US/docs/Web/API/Window/beforeinstallprompt_event).

Pembaruan tidak memanggil `skipWaiting`: tab aktif tetap memakai shell lengkap versi lama. Tutup seluruh tab/PWA agar versi baru aktif. Aktivasi menghapus cache shell lama dalam scope yang sama, tidak menyentuh OPFS/IndexedDB, bookmark, atau sesi. Pengujian Chromium desktop tidak membuktikan instalasi/cold launch Safari/iOS atau Android fisik; keduanya tetap memerlukan pemeriksaan perangkat.


## Layout adaptif

Satu aplikasi Flutter untuk ponsel, tablet, dan desktop. Breakpoint memakai lebar jendela dalam logical px, bukan user-agent. Pembagian panel juga memperhitungkan constraints lokal agar pembaca yang sempit tidak dipaksa memiliki sidebar.
Pada lebar ponsel, header memakai jarak vertikal lebih ringkas tanpa mengurangi safe area sistem. Navigasi bawah tetap sama pada iOS dan Android. Konfirmasi ukuran header dan Dynamic Island pada iPhone fisik, termasuk PWA terpasang.


| Lebar jendela | Navigasi | Daftar dan bacaan |
| --- | --- | --- |
| <600 | Bar bawah | Satu panel; tombol kembali membuka daftar yang sama. |
| 600–1023 | Rail 80 px, ikon tanpa label | Satu panel dengan grid mengikuti lebar konten. |
| >=1024 | Sidebar 264 px, bisa diciutkan menjadi 80 px | Daftar memakai seluruh lebar sebelum pasal dipilih; pembaca muncul berdampingan bila konten tersedia minimal 720 px. |

Sidebar punya pembatas, logo brand CariPasal sesuai tema (`logo.png`/`logo-dark.png`), periksa update, dan akses profil langsung. Logo tetap terlihat saat rail diciutkan. Pilihan tema Sistem/Terang/Gelap berada di dialog Profil bersama informasi akun dan aksi logout, bukan di sidebar. Tampilan desktop tidak membuka drawer pengaturan tambahan. Pada ponsel, pengaturan tetap memakai drawer 400 px maksimum dengan kontrol akun/tema yang sama.

Drawer Pengaturan berada di kanan layar dan menetapkan bentuknya sendiri: sudut kiri atas/bawah mengikuti radius sheet, sisi kanan rata. Bentuk ini tidak bergantung pada default drawer kiri Material karena panel dibuka melalui dialog.

Daftar pasal memakai satu sampai tiga kolom sesuai lebar lokal, termasuk ketika kembali dari pembaca. Tinggi kartu dalam satu baris mengikuti kartu tertinggi agar isi pendek tetap rata, tanpa memotong judul panjang. Pengukuran tinggi hanya dilakukan untuk baris grid yang dibangun (maksimal tiga kartu); daftar satu kolom mempertahankan tinggi alami. Jelajahi Pasal memakai pilihan Per halaman: Otomatis, 10, 20, 30, atau 50. Dropdown berada di bawah daftar, berdampingan dengan kontrol pagination, dan tetap tersedia pada hasil satu halaman. Otomatis memuat 30 pasal pada desktop tanpa detail terbuka, dan 10 pada ponsel/tablet atau panel daftar saat detail terbuka. Pilihan manual tersimpan di perangkat dan tidak ditimpa saat resize atau membuka detail; memilih Otomatis menghapus override. Ketika daftar penuh beralih ke panel sempit, halaman menampung pasal yang dibuka, bukan selalu halaman pertama. Dalam mode Otomatis, menutup detail mengembalikan halaman dan posisi scroll daftar sebelumnya. Tersimpan tetap memuat 30 pasal per halaman. Filter UU dan bab langsung terbuka bila lebar panel daftar minimal 740 px; di bawahnya memakai dropdown Filter, termasuk saat pembaca inline mempersempit daftar pada desktop.

Teks dropdown Per halaman, baik nilai terpilih maupun opsi menu, mengikuti gaya teks indikator nomor halaman agar ukurannya konsisten.

Saat ukuran halaman Otomatis berubah karena resize desktop/ponsel, pasal pada baris teratas yang masih terlihat menjadi anchor. Halaman baru dipilih berdasarkan pasal tersebut, lalu barisnya ditampilkan kembali; resize tidak lagi mengembalikan daftar ke awal halaman. Restorasi tetap memakai baris lazy, tanpa membangun seluruh daftar hukum.

Login dibatasi 440 px, bacaan 760 px, konten non-browser 1200 px, sheet 640 px, dan dialog 560 px. Angka tersebut adalah batas maksimum; layar sempit tetap memakai ruang yang tersedia. Pembaca standalone menampilkan daftar bab saat ruang lokal minimal 1100 px. Beranda, Pustaka, dan Tersimpan menggunakan pembaca inline yang sama.

Background dan border bawah pencarian di dalam detail mengikuti seluruh lebar kolom pembaca, dengan padding input di bagian dalam. Batas bacaan 760 px hanya membatasi isi pasal, bukan strip pencarian, sehingga tidak meninggalkan celah kiri/kanan di bawah toolbar.

Pencarian Beranda memakai jarak atas 24 px dari header, sama dengan inset atas card Baca Pasal. Header Jelajahi Pasal memiliki tinggi minimum toolbar agar keduanya sejajar pada tampilan dua panel. Di desktop, tombol Sebelumnya/Selanjutnya tetap ringkas di ujung kiri/kanan panel baca, tidak mengikuti batas card atau bergeser saat sidebar bab muncul. Sneak peek terpisah dari tombol memakai ruang kosong di antaranya, cukup kode UU dan nomor pasal (misalnya `KUHP - Pasal 3`), tanpa judul, isi, atau label urutan. Bila panel desktop menyempit, dua tujuan disusun vertikal di ruang tengah. Ponsel dan tablet di bawah breakpoint desktop tidak menampilkan sneak peek; tombol tetap berlabel Sebelumnya/Selanjutnya, maksimal 180 px, dengan celah minimum 12 px. Tombol di batas awal/akhir daftar atau UU nonaktif.

Shell mempertahankan tab yang pernah dibuka melalui `IndexedStack`. Browser mempertahankan dua subtree daftar/pembaca melalui `Offstage`, sehingga query, pilihan UU/pasal, dan scroll tidak hilang saat resize. Mengganti pilihan pasal membuat state pembaca baru. Prev/next mengikuti daftar saat pasal dibuka: urutan pembaruan di Pasal Terbaru, hasil pencarian, atau daftar UU. Memilih pasal lewat daftar isi secara eksplisit beralih ke urutan nomor pasal dalam UU; urutan itu tidak kembali ke daftar asal saat melewati pasal yang ada di kedua daftar. Ini bukan riwayat kunjungan. Back handler pada tab yang tidak aktif tidak menangkap navigasi kembali.

Regresi memakai SQLite in-memory: query serta offset baca bertahan saat `1365 -> 390 -> 800 -> 1365`, lalu kembali ke daftar. Navigasi memeriksa batas daftar, tujuan lintas UU, serta perpindahan eksplisit dari urutan daftar ke urutan UU. Sneak peek hilang saat beralih ke ponsel, navigasi tetap berfungsi, dan tujuan kembali terlihat saat resize ke desktop. Kartu dengan isi pendek, isi panjang, dan judul panjang diperiksa agar sejajar dalam grid dan tidak dipaksa sama tinggi saat menjadi satu kolom:

```bash
flutter test test/unit/widgets/adaptive_pasal_browser_test.dart
flutter test test/unit/widgets/explore_pasal_results_test.dart
```

Runtime Linux untuk tes membutuhkan `libsqlite3-dev`. Screenshot browser: [desktop](../docs/screenshots/responsive-desktop.webp), [tablet](../docs/screenshots/responsive-tablet.webp), [ponsel](../docs/screenshots/responsive-mobile.webp). Screenshot memakai data sinkronisasi sungguhan; bukan bukti pengujian perangkat fisik.

### Warna dan border

Palet terang/gelap berada di `AppColors`; tema komponen dan ketebalan garis berada di `AppTheme`. Tombol dengan teks putih memakai biru solid `primary`, sedangkan tautan, ikon aktif, dan fokus memakai `accent(isDark)`. Warna teks UU mengikuti tema melalui `UUColorHelper.getColor(kode, isDark: isDark)`; warna terang untuk tema gelap tidak dipasangkan dengan teks putih pada badge solid.

Hanya baris judul Jelajahi Pasal dan header Baca Pasal yang memakai warna bidang header dan garis bawah 1 logical px, tanpa bayangan. Pencarian, filter UU, dan pemilih bab mengikuti latar halaman/list pasal di bawahnya. Kartu, panel, input, sidebar, badge berbingkai, dan divider memakai warna border netral yang sama per tema; pilihan aktif boleh memakai warna aksen, tetapi tetap 1 px.

Fokus keyboard memakai garis 2 px. `InteractiveSurface` mengecat hover di permukaan kontrol dan fokus di atas isinya, sehingga child yang opak tidak menutup state interaksi. Garis fokus tidak menambah padding atau mengubah ukuran kontrol; tombol/chip solid memakai fokus putih agar tetap terlihat di atas biru. Konten harus memiliki inset di dalam area interaksi, bukan tepat di tepi outline: profil dan periksa update memakai inset horizontal 16 px seperti navigasi rail. Aksi pasal/PDF, tautan pasal terkait, dan penghapus filter menggunakan permukaan interaktif yang sama; tombol ikon kecil tetap memiliki padding untuk memisahkan ikon dari hover/fokus.


## Fitur Utama

1. **Offline First:** Bisa mencari pasal tanpa internet setelah sync pertama.
2. **Smart Search:** Pencarian instan berdasarkan nomor, isi, atau judul pasal.
3. **Filter Bab:** Pilih bab (dikelompokkan per UU, urut sesuai naskah), lalu boleh dipersempit ke satu judul bagian di dalam bab itu.
4. **Dark Mode:** Otomatis menyimpan preferensi pengguna.
5. **Auto-Check Update:** Setiap app dibuka, app menanyakan server apakah ada data baru. Banner hanya muncul kalau memang ada perubahan. Pengaturan menampilkan "Data diperbarui" (tanggal terakhir admin mengubah data di server) dan "Sync terakhir" (kapan HP ini terakhir sync). Tidak ada jadwal pembaruan data mingguan. Alias pencarian dari dashboard ikut diperbarui pada pengecekan ini.
6. **Pasal Terkait:** Menampilkan link ke pasal-pasal yang berhubungan (jika ada di database).
7. **Deskripsi UU:** Menampilkan informasi tentang undang-undang di halaman detail.
8. **Riwayat Perubahan Pasal:** Pasal yang pernah diubah, disisipkan, atau dihapus punya chip status di header (contoh "Diubah UU 1/2026") dan kartu "Riwayat perubahan". Kartu membuka daftar versi dari yang tertua ke terbaru (status, sumber, tanggal, tombol "Buka naskah resmi" yang membuka browser lewat `url_launcher`; bila gagal, tautan disalin). Memilih versi menampilkan isi dan penjelasannya; sakelar "Tandai perubahan" (aktif bawaan jika ada versi sebelumnya) menandai selisih kata terhadap versi sebelumnya: dihapus merah dicoret, ditambahkan hijau bergaris bawah. Pasal tanpa riwayat tidak menampilkan chip maupun kartu. Diff kata jatuh kembali ke satu blok hapus + satu blok sisip bila bagian yang berbeda lebih dari 4000 token atau tabel LCS melebihi 4 juta sel.
9. **Status Verifikasi:** Daftar pasal tidak menampilkan label verifikasi. Di layar baca, pasal yang belum diverifikasi admin memiliki ikon peringatan kecil di samping judul; ketuk untuk melihat penjelasannya. Ikon "buka di browser" di header membuka naskah resmi (naskah versi terakhir, atau tautan resmi UU bila tidak ada).
10. **Error Handling:** Pesan error yang jelas dalam Bahasa Indonesia untuk masalah jaringan, server, atau database.

---

## Alur Sinkronisasi Data

```
App Launch
    |
    v
[Splash Screen]
    |
    +-- Pertama kali? --> [Onboarding] --> Sync & simpan timestamp
    |
    +-- Sudah ada data? --> [Home Screen], sambil cek /mobile/sync/check di latar belakang
                                |
                                +-- Ada update? --> Tampilkan UpdateBanner
                                |
                                +-- Tidak ada --> diam (tanggal "Data diperbarui" tetap diperbarui)
```

`/mobile/sync/check`, `/mobile/sync/updates`, dan `/mobile/sync/full` mengembalikan
`data_updated_at`: waktu perubahan terakhir pada undang-undang, pasal, atau relasi pasal.

Riwayat pasal (`pasal_versi`) ikut di `/mobile/sync/full` dan `/mobile/sync/updates`. Sync penuh
mengosongkan lalu mengisi ulang tabel `pasal_versi`. Sync inkremental mengganti seluruh versi lokal
untuk tiap id di `updated_pasal` dan `deleted_pasal_ids` dengan baris dari `pasal_versi` (server
mengirim riwayat lengkap pasal yang berubah). Jika kunci `pasal_versi` tidak ada (server lama),
versi lokal dibiarkan. Skema database lokal versi 6 menambah tabel `pasal_versi` lewat migrasi.

---

## Catatan Pengembang

### Toolchain Flutter

- Flutter **3.47.9** (stable), Dart 3.13. Versi ini dipatok di `Dockerfile` (`ARG FLUTTER_VERSION`,
  tarball resmi). Image `ghcr.io/cirruslabs/flutter:stable` tertinggal, jadi tidak dipakai.
- UI memakai paket mandiri **`material_ui`** (pengganti `package:flutter/material.dart`).
  Impor dengan `import 'package:material_ui/material_ui.dart';`. Aplikasi ini tidak memakai
  widget Cupertino, sehingga `cupertino_ui` hanya masuk sebagai dependensi transitif.
- `showcaseview` dan `printing` masih mengimpor `package:flutter/material.dart`, jadi `main.dart`
  membungkus aplikasi dengan `MaterialUiCompatibilityBridge` di `MaterialApp.builder`. Hapus
  pembungkus itu setelah kedua paket bermigrasi ke `material_ui`.
- Lokalisasi memakai `GlobalMaterialLocalizations.delegates` dengan locale `id`.

Menjalankan analisis/tes tanpa memasang Flutter di host (jalankan pada salinan proyek karena
Docker membuat berkas milik root):

```bash
docker build --target flutter-sdk -t caripasal-flutter:3.47.9 pasal_mobile_app
docker run --rm -v "$PWD/pasal_mobile_app:/app" -w /app caripasal-flutter:3.47.9 \
  sh -c 'flutter pub get && flutter analyze && flutter test'
```

Build web (Docker, stage `build` lalu Nginx): `docker build -t caripasal-mobile-web pasal_mobile_app`.

### Tema

Semua gaya global ada di `lib/core/config/app_theme.dart` (`AppTheme.light` / `AppTheme.dark`):
skema warna dari `ColorScheme.fromSeed` dengan primary/secondary/permukaan dipaksa ke
`AppColors`, skala teks untuk bacaan panjang (badan 16/14 dengan tinggi baris 1.6-1.7), dan bentuk
seragam (kartu 16, tombol 14, input 12, sheet/dialog 20, chip 20). Tambahkan warna baru di
`app_colors.dart`, jangan hardcode di widget.

### Regenerate Database Code

Jika mengubah struktur tabel di `app_database.dart`, wajib jalankan:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Menambah Undang-Undang Baru

Jika menambah UU baru di database, update juga:

- Warna dan cover di `lib/ui/utils/image_helper.dart`
- Asset gambar di `assets/images/`

### Cek Update

Tidak ada interval sync. `SyncManager.checkForUpdates()` dipanggil dari splash screen setiap app
dibuka dan dari tombol "Periksa Update". Request ini kecil (hanya `has_updates` dan
`data_updated_at`); data baru diunduh setelah pengguna menekan "Update".

### API Classes

Untuk menggunakan sync dengan error handling:

```dart
// Smart sync - hanya sync jika perlu
final result = await DataService.smartSync();
if (result.success) {
  print(result.message); // "Data sudah up-to-date" atau "Sync berhasil"
} else {
  print(result.error?.userMessage); // Pesan error dalam Bahasa Indonesia
}

// Cek update manual
final hasUpdate = await syncManager.checkForUpdates();
```

### Struktur SyncResult

```dart
class SyncResult {
  final bool success;    // Apakah operasi berhasil
  final String message;  // Pesan untuk ditampilkan ke user
  final bool synced;     // Apakah benar-benar melakukan sync (atau skip karena up-to-date)
  final SyncError? error; // Detail error jika gagal
}
```

### Tipe Error

| SyncErrorType | Penyebab                         | Pesan User                                                        |
| :------------ | :------------------------------- | :---------------------------------------------------------------- |
| `network`     | Tidak ada internet / timeout     | "Tidak dapat terhubung ke server. Periksa koneksi internet Anda." |
| `server`      | Server Supabase down / error 5xx | "Server sedang mengalami gangguan. Coba lagi nanti."              |
| `database`    | Gagal simpan ke SQLite           | "Gagal menyimpan data ke penyimpanan lokal."                      |
| `unknown`     | Error lainnya                    | "Terjadi kesalahan yang tidak diketahui."                         |
