# CariPasal Mobile App

Aplikasi pencarian pasal hukum Indonesia berbasis Offline-First (Local Database).

## Struktur Project & Fungsi File

Berikut adalah panduan navigasi struktur kode untuk pengembang:

### Screens (`lib/ui/screens/`)

| File                             | Fungsi Utama                                                                                                                              |
| :------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------- |
| **`splash_screen.dart`**         | Layar pembuka. Mengecek database dan menginisialisasi SyncManager. Jika kosong -> Onboarding. Jika ada -> MainNavigation + cek update.    |
| **`onboarding_screen.dart`**     | Layar download awal database dari server (Supabase) ke HP (Drift/SQLite). Hanya muncul saat instalasi pertama.                            |
| **`main_navigation.dart`**       | Mengatur Bottom Navigation Bar (Tab Home vs Tab Pustaka).                                                                                 |
| **`home_screen.dart`**           | **Dashboard Utama**. Fitur: Search Global, Filter Dropdown Keyword, Filter Kategori UU, List Pasal Terbaru                                |
| **`library_screen.dart`**        | **Tab Pustaka**. Menampilkan daftar "Buku/Kitab UU" (KUHP, ITE, dll) dalam bentuk Grid.                                                   |
| **`detail_uu_screen.dart`**      | Halaman isi buku. Muncul saat buku di Pustaka diklik. Menampilkan daftar pasal + deskripsi UU jika tersedia.                              |
| **`read_pasal_screen.dart`**     | **Mode Baca Detail**. Muncul saat kartu pasal diklik. Fitur: Next/Prev Pasal, Highlight Teks, Pasal Terkait, dan Share.                   |
| **`search_screen.dart`**         | _(Legacy/Opsional)_ Halaman pencarian khusus jika menggunakan `showSearch` bawaan Flutter. Saat ini pencarian sudah terintegrasi di Home. |
| **`keyword_result_screen.dart`** | Halaman hasil klik tag/chip. Menampilkan semua pasal yang memiliki tagar yang sama.                                                       |

### Widgets (`lib/ui/widgets/`)

| File                     | Fungsi                                                                                                      |
| :----------------------- | :---------------------------------------------------------------------------------------------------------- |
| **`main_layout.dart`**   | Wrapper utama semua halaman. Menghandle Background Color & Dark Mode Listener agar konsisten.               |
| **`pasal_card.dart`**    | Komponen UI Kartu Pasal. Digunakan berulang-ulang di Home, DetailUU, dan Search Result.                     |
| **`update_banner.dart`** | Banner notifikasi update. Muncul otomatis jika ada data baru di server dan sync sudah lama tidak dilakukan. |

### Services (`lib/core/services/`)

| File                    | Fungsi                                                                                                                                            |
| :---------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------ |
| **`data_service.dart`** | **Otak Data**. Jembatan antara UI dengan Database Lokal (Drift) dan Server (Supabase). Termasuk sync data, fetch pasal_links, dan error handling. |
| **`sync_manager.dart`** | **Pengatur Sinkronisasi Otomatis**. Menyimpan timestamp sync terakhir, mengecek apakah perlu update, dan menampilkan status sync.                 |

### Database (`lib/core/database/`)

| File                      | Fungsi                                                                                    |
| :------------------------ | :---------------------------------------------------------------------------------------- |
| **`app_database.dart`**   | Definisi Tabel Database Lokal (SQLite/Drift). Termasuk tabel `undang_undang` dan `pasal`. |
| **`app_database.g.dart`** | File auto-generated oleh Drift. Jangan edit manual.                                       |

### Utils & Config

| File                               | Fungsi                                                                                              |
| :--------------------------------- | :-------------------------------------------------------------------------------------------------- |
| **`utils/highlight_text.dart`**    | Widget khusus untuk mewarnai teks (kuning) sesuai kata kunci pencarian.                             |
| **`utils/image_helper.dart`**      | Mengatur logika gambar cover buku dan warna tema per buku (Merah untuk KUHP, Hijau untuk ITE, dll). |
| **`config/theme_controller.dart`** | Mengatur State Dark Mode/Light Mode dan menyimpannya ke memori HP (Shared Preferences).             |
| **`config/env.dart`**              | Konfigurasi environment (Supabase URL dan Anon Key).                                                |

### Models (`lib/models/`)

| File                           | Fungsi                                                                         |
| :----------------------------- | :----------------------------------------------------------------------------- |
| **`pasal_model.dart`**         | Model data untuk Pasal. Termasuk `relatedIds` untuk pasal terkait.             |
| **`undang_undang_model.dart`** | Model data untuk Undang-Undang. Termasuk `deskripsi` untuk informasi tambahan. |

---

## Fitur Utama

1. **Offline First:** Bisa mencari pasal tanpa internet setelah sync pertama.
2. **Smart Search:** Pencarian instan berdasarkan nomor, isi, atau judul pasal.
3. **Strict Keyword Filter:** Filter menggunakan Tag (AND Logic). "Judi" + "Online" hanya menampilkan pasal yang mengandung keduanya.
4. **Dark Mode:** Otomatis menyimpan preferensi pengguna.
5. **Auto-Sync:** Otomatis mengecek update saat app dibuka. Jika sync terakhir > 7 hari dan ada data baru, akan muncul banner notifikasi.
6. **Pasal Terkait:** Menampilkan link ke pasal-pasal yang berhubungan (jika ada di database).
7. **Deskripsi UU:** Menampilkan informasi tentang undang-undang di halaman detail.
8. **Error Handling:** Pesan error yang jelas dalam Bahasa Indonesia untuk masalah jaringan, server, atau database.

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
    +-- Sudah ada data? --> Cek apakah sync sudah > 7 hari
                                |
                                +-- Belum waktunya --> [Home Screen]
                                |
                                +-- Sudah waktunya --> Cek server
                                                          |
                                                          +-- Ada update? --> Tampilkan UpdateBanner
                                                          |
                                                          +-- Tidak ada --> [Home Screen]
```

---

## Catatan Pengembang

### Regenerate Database Code

Jika mengubah struktur tabel di `app_database.dart`, wajib jalankan:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Menambah Undang-Undang Baru

Jika menambah UU baru di database, update juga:

- Warna dan cover di `lib/ui/utils/image_helper.dart`
- Asset gambar di `assets/images/`

### Konfigurasi Sync Interval

Default sync interval adalah 7 hari. Untuk mengubah:

```dart
// Di sync_manager.dart
static const int defaultSyncIntervalDays = 7; // Ubah sesuai kebutuhan
```

### API Classes

Untuk menggunakan sync dengan error handling:

```dart
// Smart sync - hanya sync jika perlu
final result = await syncManager.smartSync();
if (result.success) {
  print(result.message); // "Data sudah up-to-date" atau "Sync berhasil"
} else {
  print(result.error?.userMessage); // Pesan error dalam Bahasa Indonesia
}

// Force check update
final hasUpdate = await syncManager.forceCheckUpdates();
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
