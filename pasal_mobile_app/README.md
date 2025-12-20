# CariPasal - Sistem Informasi Pencarian Pasal Hukum Indonesia

CariPasal adalah solusi perangkat lunak komprehensif yang dirancang untuk memudahkan akses, pencarian, dan pengelolaan referensi hukum Indonesia (KUHP, KUHPer, KUHAP, UU ITE, dan lainnya). Sistem ini terdiri dari aplikasi mobile berbasis Flutter yang mendukung penggunaan offline dan panel admin berbasis web untuk pengelolaan data.

## Fitur Utama Aplikasi Mobile

### 1. Arsitektur Offline-First (Penyimpanan Lokal)
Aplikasi memprioritaskan ketersediaan data tanpa ketergantungan pada koneksi internet yang stabil.
* **Hive NoSQL Database:** Seluruh data pasal dan undang-undang disimpan secara lokal dalam perangkat pengguna menggunakan Hive untuk akses instan dengan latensi nol.
* **Persistensi Data:** Data tetap tersedia meskipun aplikasi ditutup atau perangkat di-restart.

### 2. Sinkronisasi Data Cerdas (Smart Sync)
Mekanisme sinkronisasi efisien untuk memastikan data lokal tetap mutakhir tanpa membebani penggunaan data pengguna.
* **Deteksi Perubahan:** Sistem membandingkan *timestamp* `updated_at` antara data lokal dan server Supabase.
* **Toleransi Latensi:** Mengimplementasikan logika toleransi waktu (5 detik) untuk menangani perbedaan presisi waktu antara server PostgreSQL dan penyimpanan lokal, mencegah unduhan ulang yang tidak perlu (redundansi).
* **Pembaruan Inkremental:** Notifikasi pembaruan muncul secara otomatis pada beranda jika terdeteksi perubahan data di server.

### 3. Pencarian Lanjutan & Visualisasi
Mesin pencari yang dioptimalkan untuk relevansi dan kemudahan membaca.
* **Real-time Highlighting:** Kata kunci pencarian ditandai dengan warna latar (highlight) secara langsung pada hasil pencarian dan halaman detail pasal.
* **Deep Search:** Pencarian mencakup nomor pasal, isi pasal, dan kata kunci (tags) terkait.
* **Tipografi Justified:** Teks pasal ditampilkan dengan perataan kanan-kiri (justify) untuk meningkatkan keterbacaan dokumen hukum yang panjang.

### 4. Navigasi & Relasi Antar Pasal
Struktur navigasi yang dirancang untuk studi hukum yang mendalam.
* **Relasi Pasal (Related Articles):** Menampilkan tautan dinamis ke pasal-pasal lain yang memiliki keterkaitan hukum (hubungan satu arah).
* **Pagination Terintegrasi:** Navigasi halaman numerik yang tertanam dalam daftar gulir (scroll view) untuk pengelolaan daftar pasal yang panjang.
* **Navigasi Sekuensial:** Fitur "Sebelumnya" dan "Selanjutnya" pada halaman detail untuk membaca pasal secara berurutan tanpa kembali ke menu utama.

### 5. Alur Pengguna (User Flow)
* **Onboarding Otomatis:** Deteksi instalasi baru atau data kosong untuk memandu pengguna melakukan pengunduhan data awal.
* **Manajemen Status:** Indikator visual untuk proses sinkronisasi dan status ketersediaan data.

---

## Spesifikasi Teknis

### Teknologi yang Digunakan
* **Framework:** Flutter (Dart SDK)
* **Local Database:** Hive (Key-Value Store)
* **Backend Services:** Supabase (PostgreSQL, Authentication, Realtime)
* **Architecture Pattern:** Service-Repository Pattern (DataService dipisahkan dari UI Logic)

### Struktur Proyek Mobile
* `lib/core/services/data_service.dart`: Logika inti untuk sinkronisasi data, manajemen Hive, dan komunikasi API.
* `lib/ui/screens/home_screen.dart`: Antarmuka utama dengan logika pencarian, filter, dan pagination.
* `lib/ui/screens/read_pasal_screen.dart`: Penampil detail pasal dengan fitur highlight teks dan navigasi relasi.
* `lib/models/`: Definisi model data dan generator adapter Hive (`.g.dart`).

---

## Panduan Instalasi & Pengembangan

Ikuti langkah-langkah berikut untuk menjalankan proyek di lingkungan lokal:

### 1. Prasyarat
* Flutter SDK versi terbaru (Stable Channel)
* Dart SDK
* Koneksi ke proyek Supabase yang aktif

### 2. Instalasi Dependensi
Jalankan perintah berikut pada terminal di direktori root proyek mobile:

```bash
flutter pub get
