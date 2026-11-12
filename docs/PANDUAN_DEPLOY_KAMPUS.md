# Panduan Deploy CariPasal di Server Kampus (aaPanel, tanpa Docker)

Untuk tim IT kampus. Server saat ini ada di commit `20c1d99`. Panduan ini memperbarui server ke
`main` terbaru, lalu **mengganti seluruh data hukum lama** dengan data lengkap dari repo. Ikuti
langkah 1 sampai 8 berurutan; tidak ada data yang perlu dicek atau dipilih manual.

| Item | Nilai |
|---|---|
| Domain | `ubgpasal.ubg.ac.id` |
| Folder project (`APP_ROOT`) | `/www/wwwroot/hukum-ubg.ac.id/projek-pasal` |
| Admin dashboard | `https://ubgpasal.ubg.ac.id/admin/` |
| API | `https://ubgpasal.ubg.ac.id/api/` |
| Mobile web | `https://ubgpasal.ubg.ac.id/mobile/` |

Kalau folder atau domain di server berbeda, ganti nilai `APP_ROOT` dan `DOMAIN` di semua perintah.

## Ringkasan

- Kode diperbarui dan 9 migrasi database dijalankan otomatis oleh script deploy.
- Semua pasal lama (format `Pasal 1`, kata kunci lama, link, riwayat) **dihapus permanen** lalu
  diisi ulang dari `data-import/*.xlsx`: KUHP 625 pasal, KUHAP 369, UU ITE 63, KUHPerdata 2124.
  Teks ini hasil pipeline datahukum.com yang sudah dibandingkan dengan PDF resmi JDIH BPK.
- Undang-undang lain selain keempat UU di atas ikut dihapus.
- Akun admin, pengguna mobile, dan alias Smart Search **tetap**.
- Pengguna mobile harus login ulang satu kali. Aplikasi lalu mengunduh ulang seluruh data, jadi
  pasal lama juga hilang dari HP.
- Mobile web `/mobile/` sekarang bisa dipakai offline (PWA) dan butuh blok Nginx baru.
- Server tetap tidak perlu Docker, Flutter, atau Python.

Prosedur ini sudah diuji lokal pada database dari commit `20c1d99`. Konfigurasi aaPanel/Nginx hanya
bisa dicek di server dengan langkah 8.

## 1. Backup

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal
git status                    # harus bersih, tidak ada file yang diubah manual
git log --oneline -1          # harus 20c1d99
grep -E '^DB_(HOST|PORT|DATABASE|USERNAME)=' backend-laravel/.env
```

Backup database (isi nama database/user sesuai output di atas, password diminta):

```bash
pg_dump -h 127.0.0.1 -U caripasal_user -Fc caripasal \
  > ~/caripasal-sebelum-update-$(date +%F).dump
ls -lh ~/caripasal-sebelum-update-*.dump
```

Jika `pg_dump` tidak ditemukan, pakai `/www/server/pgsql/bin/pg_dump` atau menu aaPanel
**Database → PostgreSQL → Backup**. Backup ini satu-satunya salinan data lama.

Jika `git status` menunjukkan file berubah, simpan dulu (`git diff > ~/perubahan-server.diff`), lalu
`git checkout -- .`, karena script memakai `git pull --ff-only`.

## 2. Cek prasyarat server

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal
git pull --ff-only origin main
APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal bash deploy/aapanel-doctor.sh
```

Semua baris harus `[OK]`. Yang dibutuhkan: PHP 8.3/8.4 dengan extension `pdo_pgsql pgsql fileinfo
mbstring openssl curl zip xml gd`, fungsi `putenv` dan `proc_open` tidak di-disable, Composer,
Node.js 22+, PostgreSQL.

Script memakai PHP 8.4 secara default. Jika server memakai PHP 8.3, tambahkan di depan perintah
deploy pada langkah 4 dan 6:

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
    # Import xlsx dari dashboard (KUHPerdata ~2,5 MB) dan unggah PDF naskah resmi.
    client_max_body_size 20m;
    try_files $uri /index.php?$query_string;

    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME
        /www/wwwroot/hukum-ubg.ac.id/projek-pasal/backend-laravel/public/index.php;
    fastcgi_param DOCUMENT_ROOT
        /www/wwwroot/hukum-ubg.ac.id/projek-pasal/backend-laravel/public;
    fastcgi_param SCRIPT_NAME /index.php;
    fastcgi_param REQUEST_URI $request_uri;
    fastcgi_param HTTPS on;
    fastcgi_pass unix:/tmp/php-cgi-84.sock;
}

# Mobile web PWA: header COOP/COEP, tanpa cache entrypoint, 404 untuk aset hilang.
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
`upload_max_filesize = 20M` dan `post_max_size = 24M`, lalu restart PHP.

## 4. Deploy backend dan admin dashboard

Script ini menjalankan pull, composer, migrasi, seeder, build admin, restart PHP-FPM, reload Nginx,
dan health check:

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal

APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal \
DOMAIN=ubgpasal.ubg.ac.id \
bash deploy/aapanel-update.sh
```

Output migrasi menampilkan 9 baris `DONE`, dari
`2026_08_18_000001_include_keywords_in_pasal_search_vector` sampai
`2026_11_12_000001_create_import_sources`. Script selesai dengan `Deployment complete` dan JSON
`{"status":"ok",...}`.

## 5. Ganti data hukum (sekali saja)

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal/backend-laravel
/www/server/php/84/bin/php artisan caripasal:reset-data-hukum
```

(PHP 8.3: `/www/server/php/83/bin/php`.)

Perintah menampilkan data yang akan dihapus, lalu bertanya konfirmasi. Ketik `yes` lalu Enter.
Prosesnya sekitar 15 detik. Hasil yang benar:

```text
Selesai. Semua pasal berstatus "Perlu verifikasi".
+--------+-------+------+---------------+
| Kode   | Pasal | Link | Versi riwayat |
+--------+-------+------+---------------+
| KUHAP  | 369   | 179  | 0             |
| KUHP   | 625   | 348  | 109           |
| KUHPER | 2124  | 418  | 770           |
| UU_ITE | 63    | 41   | 63            |
+--------+-------+------+---------------+
```

Semua langkah berjalan dalam satu transaksi. Jika muncul pesan `Gagal, semua perubahan
dibatalkan`, database masih persis seperti sebelum perintah; kirim pesan error itu ke developer.

Pasal hasil import masuk menu **Verifikasi** dengan status "Perlu verifikasi" dan tetap tampil di
aplikasi dengan label "Belum diverifikasi admin" sampai admin hukum memverifikasinya. Setelah ada
pasal yang diverifikasi, perintah ini menolak berjalan lagi supaya hasil verifikasi tidak terhapus.

## 6. Publish mobile web

Dijalankan setelah langkah 5, supaya HP yang membuka versi baru langsung mendapat data baru:

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal

APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal \
DOMAIN=ubgpasal.ubg.ac.id \
SKIP_GIT=1 \
bash deploy/aapanel-mobile-web-update.sh
```

Script menyalin `mobile-web-dist/` (sudah dibuild developer) ke folder `mobile/`, lalu mengecek
`/mobile/` dan `/api/health`.

## 7. Amankan akun super admin

Akun bawaan `superadmin@caripasal.local` dengan password `ChangeMe123!` tercantum di repo publik.
Akun ini bisa ada di server bila seeder pernah jalan tanpa membaca nilai `.env`. Cek sekali:

1. Login ke Admin dengan `CARIPASAL_SUPER_ADMIN_EMAIL` dan `CARIPASAL_SUPER_ADMIN_PASSWORD` dari
   `backend-laravel/.env`.
2. Buka **Akun Admin**. Jika ada `superadmin@caripasal.local` dan itu bukan akun yang dipakai login,
   klik **Nonaktifkan** pada akun itu.
3. Jika akun yang dipakai login adalah `superadmin@caripasal.local` atau passwordnya `ChangeMe123!`:
   logout, klik **Lupa Password?** di halaman login, lalu atur password baru dari email reset
   (butuh SMTP/Resend di `.env` sudah benar).

## 8. Cek hasil

```bash
curl -s https://ubgpasal.ubg.ac.id/api/health          # {"status":"ok",...}
curl -sI https://ubgpasal.ubg.ac.id/mobile/ | head -n 1 # HTTP 200
curl -sI https://ubgpasal.ubg.ac.id/mobile/caripasal-sw.js | grep -i cross-origin
```

Baris terakhir harus menampilkan `cross-origin-opener-policy` dan `cross-origin-embedder-policy`.
Jika kosong, `include` Nginx pada langkah 3 belum aktif.

Di browser:

- Admin → **Dashboard**: 3181 pasal, 4 undang-undang.
- `https://ubgpasal.ubg.ac.id/mobile/`: login, tunggu unduhan data selesai (3181 pasal), cari
  "pencurian". Hasilnya harus ada dari KUHP.

Jika `curl .../api/health` mengembalikan HTML `Just a moment...`, Cloudflare memberi challenge ke
API. Buat rule: Hostname `ubgpasal.ubg.ac.id` AND URI Path starts with `/api/` → Skip
(Managed Challenge, Bot Fight Mode, Browser Integrity Check). Admin dan `/mobile/` boleh tetap
lewat Cloudflare.

## 9. Update berikutnya

Setiap developer push update:

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal

APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal \
DOMAIN=ubgpasal.ubg.ac.id \
bash deploy/aapanel-update.sh

APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal \
DOMAIN=ubgpasal.ubg.ac.id \
SKIP_GIT=1 \
bash deploy/aapanel-mobile-web-update.sh
```

Langkah 3, 5, dan 7 tidak perlu diulang.

## 10. Rollback

Migrasi baru mengubah struktur tabel, jadi rollback = kembalikan kode dan database bersama-sama:

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal
git checkout 20c1d99
pg_restore -h 127.0.0.1 -U caripasal_user -d caripasal --clean --if-exists \
  ~/caripasal-sebelum-update-YYYY-MM-DD.dump

APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal \
DOMAIN=ubgpasal.ubg.ac.id \
SKIP_GIT=1 \
bash deploy/aapanel-deploy.sh
```

Setelah masalah selesai, kembali ke `main` dengan `git checkout main` lalu ulangi dari langkah 4.

## Masalah yang sering muncul

| Gejala | Penyebab | Solusi |
|---|---|---|
| Script berhenti dengan `Missing PHP extension` | Extension belum aktif | aaPanel → PHP → Install extensions, lalu ulangi |
| `PHP function disabled ... putenv/proc_open` | Fungsi di-disable aaPanel | aaPanel → PHP → Disabled functions → hapus `putenv`, `proc_open` |
| `Not possible to fast-forward` | Ada perubahan manual di server | Simpan `git diff`, lalu `git checkout -- .` dan ulangi |
| Langkah 5: `Dibatalkan: N pasal sudah diverifikasi admin` | Perintah sudah pernah dijalankan dan admin mulai memverifikasi | Normal. Jangan dijalankan lagi |
| Langkah 5: `Harus ada tepat satu file .xlsx` | Folder `data-import/` tidak lengkap | Jalankan `git status` dan `git pull --ff-only origin main`, lalu ulangi |
| Import xlsx dari dashboard gagal `413` | `client_max_body_size` belum ada di `/api/` | Langkah 3 |
| `/admin/` blank atau 404 | `alias` Nginx menunjuk folder lain | `alias` harus `.../projek-pasal/admin/`, folder dibuat oleh script deploy |
| Mobile web masih versi lama | Tab lama masih terbuka | Tutup semua tab/aplikasi CariPasal lalu buka lagi. Jangan hapus data situs, karena data offline ikut terhapus |
| Error `Permission denied` di `storage/logs` | Owner folder salah | `chown -R <user_deploy>:www backend-laravel/storage backend-laravel/bootstrap/cache` |
| Login mobile gagal "batas 3 perangkat aktif" | Akun sudah login di 3 perangkat/browser | Admin → **Akun Admin** (atau **Pengguna Mobile**) → **Perangkat mobile** → **Paksa keluar** perangkat lama |

Catatan:

- `CARIPASAL_SUPER_ADMIN_*` di `.env` hanya dipakai saat akun itu belum ada; deploy tidak lagi
  menimpa passwordnya. Ganti password lewat **Lupa Password?** di halaman login.
- Fitur **Sumber Data** (ambil dari datahukum.com) tetap mati (`DATAHUKUM_FETCH_ENABLED=false`)
  sampai izin data keluar. Selama mati, server tidak butuh queue worker atau Python.
