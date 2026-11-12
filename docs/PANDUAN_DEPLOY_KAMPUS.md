# Panduan Deploy CariPasal di Server Kampus (aaPanel, tanpa Docker)

Untuk tim IT kampus. Server saat ini ada di commit `20c1d99`. Panduan ini memperbarui server ke
`main` terbaru dan mengisi data hukum lengkap. Migrasi dari database `20c1d99`, seeder, import
keempat file, admin dashboard, dan mobile web (login, sinkronisasi, buka ulang offline) sudah diuji
lokal. Konfigurasi aaPanel/Nginx hanya bisa dicek di server dengan langkah 6.

| Item | Nilai |
|---|---|
| Domain | `ubgpasal.ubg.ac.id` |
| Folder project (`APP_ROOT`) | `/www/wwwroot/hukum-ubg.ac.id/projek-pasal` |
| Admin dashboard | `https://ubgpasal.ubg.ac.id/admin/` |
| API | `https://ubgpasal.ubg.ac.id/api/` |
| Mobile web | `https://ubgpasal.ubg.ac.id/mobile/` |

Kalau folder atau domain di server berbeda, ganti nilai `APP_ROOT` dan `DOMAIN` di semua perintah.

## Yang berubah sejak `20c1d99`

- 9 migrasi database baru: verifikasi pasal, riwayat perubahan, Sumber Data, bab, dan Smart Search.
  Migrasi dijalankan otomatis oleh script deploy.
- Data hukum lengkap: KUHP 625 pasal, KUHAP 369, UU ITE 63, KUHPerdata 2124. Data diimport lewat
  admin dashboard (langkah 5).
- Mobile web `/mobile/` sekarang bisa dibuka offline (PWA), jadi butuh blok Nginx baru.
- Import KUHPerdata mengirim request sekitar 2,5 MB ke `/api/`, jadi Nginx perlu
  `client_max_body_size 20m`.
- Pengguna mobile harus login ulang satu kali setelah update.

Server tetap tidak perlu Docker, Flutter, atau Python.

## 1. Backup dulu

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal
git status                    # harus bersih, tidak ada file yang diubah manual
git log --oneline -1          # harus 20c1d99
grep -E '^DB_(HOST|PORT|DATABASE|USERNAME)=' backend-laravel/.env
```

Backup database (isi nama database/user sesuai output di atas, password diminta):

```bash
pg_dump -h 127.0.0.1 -U caripasal_user -Fc caripasal > ~/caripasal-sebelum-update-$(date +%F).dump
ls -lh ~/caripasal-sebelum-update-*.dump
```

Jika `pg_dump` tidak ditemukan, pakai `/www/server/pgsql/bin/pg_dump` atau menu aaPanel
**Database → PostgreSQL → Backup**.

Jika `git status` menunjukkan file berubah, catat dulu perubahannya (`git diff > ~/perubahan-server.diff`)
sebelum lanjut, karena script memakai `git pull --ff-only`.

## 2. Cek prasyarat server

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal
git pull --ff-only origin main
APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal bash deploy/aapanel-doctor.sh
```

Semua baris harus `[OK]`. Yang dibutuhkan: PHP 8.3/8.4 dengan extension `pdo_pgsql pgsql fileinfo
mbstring openssl curl zip xml gd`, fungsi `putenv` dan `proc_open` tidak di-disable, Composer,
Node.js 22+, PostgreSQL.

Script memakai PHP 8.4 secara default. Jika server memakai PHP 8.3, tambahkan di depan setiap
perintah deploy pada langkah 4:

```bash
PHP_BIN=/www/server/php/83/bin/php PHP_FPM_SERVICE=/etc/init.d/php-fpm-83
```

## 3. Konfigurasi Nginx dan PHP (sekali saja)

aaPanel → **Website** → `ubgpasal.ubg.ac.id` → **Config**. Di dalam `server { ... }` harus ada
blok berikut. Ganti blok `/admin` dan `/api` yang lama, jangan menduplikasinya:

```nginx
location = /admin {
    return 301 /admin/;
}

location ^~ /admin/ {
    alias /www/wwwroot/hukum-ubg.ac.id/projek-pasal/admin/;
    try_files $uri $uri/ /admin/index.html;
}

location ^~ /api/ {
    # Import xlsx KUHPerdata dikirim sebagai satu JSON sekitar 2,5 MB.
    client_max_body_size 20m;
    try_files $uri /index.php?$query_string;

    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME /www/wwwroot/hukum-ubg.ac.id/projek-pasal/backend-laravel/public/index.php;
    fastcgi_param DOCUMENT_ROOT /www/wwwroot/hukum-ubg.ac.id/projek-pasal/backend-laravel/public;
    fastcgi_param SCRIPT_NAME /index.php;
    fastcgi_param REQUEST_URI $request_uri;
    fastcgi_param HTTPS on;
    fastcgi_pass unix:/tmp/php-cgi-84.sock;
}

# Mobile web PWA: header COOP/COEP, tanpa cache entrypoint, 404 untuk aset yang tidak ada.
include /www/wwwroot/hukum-ubg.ac.id/projek-pasal/deploy/aapanel-mobile-web.conf;

location ~ \.php$ {
    return 404;
}
```

- PHP 8.3: ganti socket menjadi `/tmp/php-cgi-83.sock` (cek dengan `ls /tmp/php-cgi-*.sock`).
- Jika sebelumnya ada blok `location ^~ /mobile/` buatan manual, hapus. Penggantinya adalah baris
  `include` di atas.

Simpan, lalu:

```bash
nginx -t && /etc/init.d/nginx reload
```

Jika `nginx -t` gagal, jangan reload. Perbaiki dulu sampai lolos.

PHP: aaPanel → **App Store** → PHP 8.x → **Setting** → **Configuration file**. Set
`upload_max_filesize = 20M` dan `post_max_size = 24M`, lalu restart PHP. Nilai ini dipakai fitur
unggah PDF naskah resmi di menu Undang-Undang.

## 4. Deploy

Backend + admin dashboard (pull, composer, migrasi, seeder, build admin, restart PHP-FPM, reload
Nginx, health check):

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal

APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal \
DOMAIN=ubgpasal.ubg.ac.id \
bash deploy/aapanel-update.sh
```

Output migrasi harus menampilkan 9 baris `DONE`, dari
`2026_08_18_000001_include_keywords_in_pasal_search_vector` sampai
`2026_11_12_000001_create_import_sources`. Script selesai dengan `Deployment complete` dan JSON
`{"status":"ok",...}`.

Mobile web (salin `mobile-web-dist/` yang sudah dibuild developer ke folder `mobile/`):

```bash
APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal \
DOMAIN=ubgpasal.ubg.ac.id \
bash deploy/aapanel-mobile-web-update.sh
```

Script ini menolak build lama yang belum punya file offline (`caripasal-sw.js`, `offline.js`,
`offline-build.json`). Jika muncul `Incomplete offline build`, hubungi developer untuk push ulang
`mobile-web-dist/`.

## 5. Isi data hukum (sekali saja)

File data ada di folder `data-import/` dalam repo. Upload dari laptop yang membuka admin dashboard,
jadi unduh dulu keempat file `.xlsx` dari GitHub atau salin dari server.

### 5.1 Pindahkan pasal format lama ke Sampah

Seeder dan import versi lama menyimpan nomor dengan awalan (`Pasal 1`), sedangkan data baru tanpa
awalan (`1`). Kalau tidak dibersihkan, pasal akan muncul dobel di aplikasi.

Cek (read-only):

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal/backend-laravel
/www/server/php/84/bin/php artisan tinker --execute='foreach (App\Models\UndangUndang::withCount(["pasal as total", "pasal as format_lama" => fn ($q) => $q->where("nomor", "like", "Pasal %")])->orderBy("kode")->get() as $u) echo str_pad($u->kode, 8), " total=", $u->total, " format_lama=", $u->format_lama, PHP_EOL;'
```

Jika ada `format_lama` lebih dari 0, pindahkan ke Sampah. Data tidak hilang dan bisa dipulihkan
dari **Pasal → Sampah**:

```bash
/www/server/php/84/bin/php artisan tinker --execute='echo App\Models\Pasal::whereHas("undangUndang", fn ($q) => $q->whereIn("kode", ["KUHP", "KUHAP", "UU_ITE", "KUHPER"]))->where("nomor", "like", "Pasal %")->delete(), " pasal format lama dipindah ke Sampah", PHP_EOL;'
```

Pasal contoh dari seeder tidak dibuat ulang pada deploy berikutnya.

### 5.2 Aktifkan KUHPerdata

Admin → **Undang-Undang** → baris `KUHPER` → **Edit** → nyalakan **Aktif** → **Simpan**. UU ini
dibuat otomatis oleh migrasi dalam keadaan nonaktif, dan UU nonaktif tidak muncul di pilihan import.

### 5.3 Import empat file

Admin → **Import Data** → tab **Excel** → pilih UU → upload file → **Import Data**. Tunggu sampai
muncul **Hasil Import**. KUHPerdata butuh sekitar 1–2 menit.

| Pilih UU | File | Hasil yang benar |
|---|---|---|
| `KUHP` | `data-import/kuhp-2023/01_kuhp_2023_konsolidasi_ready.xlsx` | Pasal 625, Link 348, riwayat 109 versi |
| `KUHAP` | `data-import/kuhap-2025/01_kuhap_2025_ready.xlsx` | Pasal 369, Link 179 |
| `UU_ITE` | `data-import/uu-ite-2008/01_uu_ite_2008_konsolidasi_ready.xlsx` | Pasal 63, Link 41, riwayat 63 versi |
| `KUHPER` | `data-import/kuhper-1847/01_kuhper_1847_ready.xlsx` | Pasal 2124, Link 418, riwayat 770 versi |

Import aman diulang: pasal dicocokkan per (UU, nomor) lalu ditimpa, tidak dobel.

Semua pasal hasil import masuk menu **Verifikasi** dengan status "Perlu verifikasi". Pasal tetap
tampil di aplikasi dengan label "Belum diverifikasi admin" sampai admin hukum memverifikasinya.

## 6. Cek hasil

```bash
curl -s https://ubgpasal.ubg.ac.id/api/health          # {"status":"ok",...}
curl -sI https://ubgpasal.ubg.ac.id/mobile/ | head -n 1 # HTTP 200
curl -sI https://ubgpasal.ubg.ac.id/mobile/caripasal-sw.js | grep -i cross-origin
```

Baris terakhir harus menampilkan `cross-origin-opener-policy` dan `cross-origin-embedder-policy`.
Jika kosong, `include` Nginx pada langkah 3 belum aktif.

Di browser:

- Admin → **Dashboard**: 3181 pasal (lebih jika kampus menambah pasal sendiri), 4 undang-undang.
- `https://ubgpasal.ubg.ac.id/mobile/`: login, tunggu sinkronisasi selesai, cari "pencurian".
  Hasilnya harus ada dari KUHP.

Jika `curl .../api/health` mengembalikan HTML `Just a moment...`, Cloudflare memberi challenge ke
API. Buat rule: Hostname `ubgpasal.ubg.ac.id` AND URI Path starts with `/api/` → Skip
(Managed Challenge, Bot Fight Mode, Browser Integrity Check). Admin dan `/mobile/` boleh tetap
lewat Cloudflare.

## 7. Update berikutnya

Setiap developer push update:

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal

APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal DOMAIN=ubgpasal.ubg.ac.id bash deploy/aapanel-update.sh
APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal DOMAIN=ubgpasal.ubg.ac.id SKIP_GIT=1 bash deploy/aapanel-mobile-web-update.sh
```

Langkah 3 dan 5 tidak perlu diulang.

## 8. Rollback

Migrasi baru mengubah struktur tabel, jadi rollback = kembalikan kode dan database bersama-sama:

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal
git checkout 20c1d99
pg_restore -h 127.0.0.1 -U caripasal_user -d caripasal --clean --if-exists ~/caripasal-sebelum-update-YYYY-MM-DD.dump
APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal DOMAIN=ubgpasal.ubg.ac.id SKIP_GIT=1 bash deploy/aapanel-deploy.sh
```

Setelah masalah selesai, kembali ke `main` dengan `git checkout main` lalu ulangi langkah 4.

## Masalah yang sering muncul

| Gejala | Penyebab | Solusi |
|---|---|---|
| Script berhenti dengan `Missing PHP extension` | Extension belum aktif | aaPanel → PHP → Install extensions, lalu ulangi |
| `PHP function disabled ... putenv/proc_open` | Fungsi di-disable aaPanel | aaPanel → PHP → Disabled functions → hapus `putenv`, `proc_open` |
| `Not possible to fast-forward` | Ada perubahan manual di server | Simpan `git diff`, lalu `git checkout -- .` dan ulangi |
| Import KUHPerdata gagal `413` | `client_max_body_size` belum ada di `/api/` | Langkah 3 |
| `/admin/` blank atau 404 | `alias` Nginx menunjuk folder lain | `alias` harus `.../projek-pasal/admin/`, folder dibuat oleh script deploy |
| Mobile web masih versi lama | Tab lama masih terbuka | Tutup semua tab/aplikasi CariPasal lalu buka lagi. Jangan hapus data situs, karena data offline ikut terhapus |
| Error `Permission denied` di `storage/logs` | Owner folder salah | `chown -R <user_deploy>:www backend-laravel/storage backend-laravel/bootstrap/cache` |
| Login mobile gagal "batas 3 perangkat aktif" | Akun sudah login di 3 perangkat/browser | Admin → **Akun Admin** (atau **Pengguna Mobile**) → **Perangkat mobile** → **Paksa keluar** perangkat lama |

Catatan:

- Password super admin diambil dari `CARIPASAL_SUPER_ADMIN_PASSWORD` di `backend-laravel/.env` dan
  diterapkan ulang setiap deploy. Ganti password super admin di `.env`, bukan dari dashboard.
- Fitur **Sumber Data** (ambil dari datahukum.com) tetap mati (`DATAHUKUM_FETCH_ENABLED=false`)
  sampai izin data keluar. Selama mati, server tidak butuh queue worker atau Python.
