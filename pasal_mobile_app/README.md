# CariPasal Mobile App 🇮🇩

Aplikasi pencarian pasal hukum Indonesia berbasis Offline-First (Local Database).

## Struktur Project & Fungsi File

Berikut adalah panduan navigasi struktur kode untuk pengembang:

### Screens (`lib/ui/screens/`)

| File | Fungsi Utama |
| :--- | :--- |
| **`splash_screen.dart`** | Layar pembuka. Mengecek apakah database kosong. Jika kosong -> ke Onboarding. Jika ada -> ke MainNavigation. |
| **`onboarding_screen.dart`** | Layar download awal database dari server (Supabase) ke HP (Drift/SQLite). Hanya muncul saat instalasi pertama. |
| **`main_navigation.dart`** | Mengatur Bottom Navigation Bar (Tab Home vs Tab Pustaka). |
| **`home_screen.dart`** | **Dashboard Utama**. Fitur: Search Global, Filter Dropdown Keyword, Filter Kategori UU, dan List Pasal Terbaru. |
| **`library_screen.dart`** | **Tab Pustaka**. Menampilkan daftar "Buku/Kitab UU" (KUHP, ITE, dll) dalam bentuk Grid. |
| **`detail_uu_screen.dart`** | Halaman isi buku. Muncul saat buku di Pustaka diklik. Menampilkan daftar pasal dalam 1 buku spesifik. |
| **`read_pasal_screen.dart`** | **Mode Baca Detail**. Muncul saat kartu pasal diklik. Fitur: Next/Prev Pasal, Highlight Teks, dan Share. |
| **`search_screen.dart`** | *(Legacy/Opsional)* Halaman pencarian khusus jika menggunakan `showSearch` bawaan Flutter. Saat ini pencarian sudah terintegrasi di Home. |
| **`keyword_result_screen.dart`** | Halaman hasil klik tag/chip. Menampilkan semua pasal yang memiliki tagar yang sama. |

### Widgets (`lib/ui/widgets/`)

| File | Fungsi |
| :--- | :--- |
| **`main_layout.dart`** | Wrapper utama semua halaman. Menghandle Background Color & Dark Mode Listener agar konsisten. |
| **`pasal_card.dart`** | Komponen UI Kartu Pasal. Digunakan berulang-ulang di Home, DetailUU, dan Search Result. |

### 🛠 Utils & Config

| File | Fungsi |
| :--- | :--- |
| **`utils/highlight_text.dart`** | Widget khusus untuk mewarnai teks (kuning) sesuai kata kunci pencarian. |
| **`utils/image_helper.dart`** | Mengatur logika gambar cover buku dan warna tema per buku (Merah untuk KUHP, Hijau untuk ITE, dll). |
| **`config/theme_controller.dart`** | Mengatur State Dark Mode/Light Mode dan menyimpannya ke memori HP (Shared Preferences). |
| **`services/data_service.dart`** | **Otak Data**. Jembatan antara UI dengan Database Lokal (Drift) dan Server (Supabase). |
| **`database/app_database.dart`** | Definisi Tabel Database Lokal (SQLite/Drift). |

---

## Fitur Utama

1.  **Offline First:** Bisa mencari pasal tanpa internet.
2.  **Smart Search:** Pencarian instan (nomor, isi, atau judul).
3.  **Strict Keyword Filter:** Filter menggunakan Tag (AND Logic). "Judi" + "Online" hanya menampilkan pasal yang mengandung KEDUANYA.
4.  **Dark Mode:** Otomatis menyimpan preferensi pengguna.
5.  **Sync Data:** Fitur update database OTA (Over The Air) tanpa perlu update aplikasi di PlayStore.

## Catatan Pengembang

* **Database:** Menggunakan `drift` (SQLite). Jika mengubah struktur tabel, wajib jalankan:
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```
* **Warna Buku:** Jika menambah UU baru, jangan lupa update warna dan covernya di `lib/ui/utils/image_helper.dart`.