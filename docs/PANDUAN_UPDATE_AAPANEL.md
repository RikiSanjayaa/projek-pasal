# Panduan Update CariPasal di aaPanel (dari `20c1d99` ke `main` terbaru)

Panduan singkat untuk tim IT kampus. Server saat ini berada di commit `20c1d99` ("security: hapus
port mapping postgres:5432 ke host"). Ikuti langkah 1 sampai 10 secara berurutan. Referensi
lengkap (instalasi baru, Nginx, mobile web, email) ada di [AAPANEL_DEPLOYMENT.md](AAPANEL_DEPLOYMENT.md).

Server tetap tidak memakai Docker, Flutter, atau Python. Semua langkah sudah diuji lokal pada
database yang dibuat dari commit `20c1d99`.

## Yang Perlu Diketahui Dulu

| Perubahan | Dampak ke server |
|---|---|
| 9 migration baru (verifikasi pasal, riwayat perubahan, bab, Smart Search, Sumber Data). Kolom kata kunci pasal dihapus. | **Wajib backup database** (langkah 3). Rollback hanya bisa dengan restore backup. |
| Data hukum lama (nomor `Pasal 1`, kata kunci lama) diganti total dengan data lengkap dari repo: KUHP 625 pasal, KUHAP 369, UU ITE 63, KUHPerdata 2124. | Satu perintah (langkah 7). Semua pasal lama dan UU lain di luar keempat UU ini terhapus. Akun admin, pengguna mobile, dan alias Smart Search tetap. |
| Mobile web `/mobile/` sekarang bisa dipakai offline (PWA). | Tambah satu baris `include` di Nginx (langkah 5). |
| Import xlsx dan unggah PDF lewat dashboard mengirim request sampai 20 MB. | `client_max_body_size 20m` di Nginx, `upload_max_filesize`/`post_max_size` di PHP (langkah 5). |
| Login mobile memakai sesi baru. | Pengguna mobile login ulang satu kali, lalu aplikasi mengunduh ulang seluruh data. |

## 1. Isi Variabel

Login SSH, lalu sesuaikan nilai berikut. Semua perintah berikutnya memakai variabel ini, jadi
jalankan di sesi SSH yang sama.

```bash
export DOMAIN=ubgpasal.ubg.ac.id
export APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal
export PHP_BIN=/www/server/php/84/bin/php             # PHP 8.3: .../php/83/bin/php
export PHP_FPM_SERVICE=/etc/init.d/php-fpm-84         # PHP 8.3: php-fpm-83
export PATH=/www/server/pgsql/bin:$PATH               # pg_dump/psql PostgreSQL aaPanel
cd "$APP_ROOT"
```

Script deploy membaca variabel ini langsung, jadi perintah di langkah berikutnya tidak perlu
diberi `DOMAIN=...` lagi.

## 2. Cek Versi Runtime

```bash
$PHP_BIN -v | head -1          # 8.3 atau 8.4
node -v                        # 22 atau lebih baru
git status --short             # sebaiknya kosong
git log --oneline -1           # 20c1d99
bash deploy/aapanel-doctor.sh  # semua baris [OK]
```

- Doctor mengecek extension PHP (`pdo_pgsql pgsql fileinfo mbstring openssl curl zip xml gd`),
  fungsi `putenv` dan `proc_open`, Composer, Node/NPM, dan folder writable Laravel.
- `git status` tidak kosong berarti ada file yang diubah langsung di server. Simpan dulu
  (`git diff > ~/perubahan-server.diff`), lalu `git checkout -- .`, karena langkah 4 memakai
  `git pull --ff-only`.

## 3. Backup

```bash
BACKUP_DIR=/www/backup/caripasal-$(date +%Y%m%d-%H%M)
mkdir -p "$BACKUP_DIR"

# Database (nama, host, dan user diambil dari .env, password diminta interaktif)
DB_HOST=$(grep -E '^DB_HOST=' backend-laravel/.env | cut -d= -f2-)
DB_NAME=$(grep -E '^DB_DATABASE=' backend-laravel/.env | cut -d= -f2-)
DB_USER=$(grep -E '^DB_USERNAME=' backend-laravel/.env | cut -d= -f2-)
pg_dump -h "$DB_HOST" -U "$DB_USER" -Fc "$DB_NAME" > "$BACKUP_DIR/database.dump"

# Konfigurasi
cp backend-laravel/.env "$BACKUP_DIR/env.backup"

# Penanda commit lama untuk rollback
git tag -f sebelum-update-20c1d99 20c1d99

ls -lh "$BACKUP_DIR"
```

Pastikan `database.dump` tidak kosong. Backup ini satu-satunya salinan data hukum lama. Jika
`pg_dump` tidak ditemukan, backup dari aaPanel > Databases > PostgreSQL > Backup.

## 4. Ambil Kode Terbaru

```bash
git fetch origin
git pull --ff-only origin main
git log --oneline -1
```

`git log` harus menampilkan commit terbaru `main`, bukan lagi `20c1d99`.

## 5. Sesuaikan Nginx dan PHP (Sekali Saja)

aaPanel > Website > `ubgpasal.ubg.ac.id` > Config. Di dalam `server { ... }` harus ada blok
berikut. Ganti blok `/admin` dan `/api` yang lama, jangan menduplikasinya. Jika sebelumnya ada blok
`location ^~ /mobile/` buatan manual, hapus; penggantinya baris `include`.

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
    fastcgi_pass unix:/tmp/php-cgi-84.sock;      # PHP 8.3: php-cgi-83.sock
}

# Mobile web PWA: header COOP/COEP, tanpa cache entrypoint, 404 untuk aset hilang.
include /www/wwwroot/hukum-ubg.ac.id/projek-pasal/deploy/aapanel-mobile-web.conf;

location ~ \.php$ {
    return 404;
}
```

Simpan, lalu tes dan reload:

```bash
/www/server/nginx/sbin/nginx -t && /etc/init.d/nginx reload
```

Jika tes gagal, jangan reload. Perbaiki dulu sampai lolos.

PHP: aaPanel > App Store > PHP 8.x > Setting > Configuration file. Set `upload_max_filesize = 20M`
dan `post_max_size = 24M`, lalu restart PHP.

## 6. Deploy

```bash
bash deploy/aapanel-update.sh
```

Script menjalankan composer, migration, seeder, build admin dashboard, restart PHP-FPM, reload
Nginx, dan health check. Output migration menampilkan 9 baris `DONE`, dari
`2026_08_18_000001_include_keywords_in_pasal_search_vector` sampai
`2026_11_12_000001_create_import_sources`. Script selesai dengan `Deployment complete` dan JSON
`{"status":"ok",...}`.

## 7. Ganti Data Hukum (Sekali Saja)

```bash
cd "$APP_ROOT/backend-laravel"
$PHP_BIN artisan caripasal:reset-data-hukum
cd "$APP_ROOT"
```

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

- Semua langkah berjalan dalam satu transaksi. Jika muncul `Gagal, semua perubahan dibatalkan`,
  database masih persis seperti sebelum perintah; kirim pesan error itu ke pengembang.
- Pasal baru berstatus "Perlu verifikasi" dan tetap tampil di aplikasi dengan label "Belum
  diverifikasi admin" sampai admin hukum memverifikasinya di menu Verifikasi.
- Setelah ada pasal yang diverifikasi, perintah ini menolak berjalan lagi supaya hasil verifikasi
  tidak terhapus.

## 8. Publish Mobile Web

Dijalankan setelah langkah 7, supaya HP yang membuka versi baru langsung mendapat data baru:

```bash
SKIP_GIT=1 bash deploy/aapanel-mobile-web-update.sh
```

Script menyalin `mobile-web-dist/` (sudah dibuild pengembang) ke folder `mobile/`, lalu mengecek
`/mobile/` dan `/api/health`.

## 9. Amankan Akun Super Admin

Akun bawaan `superadmin@caripasal.local` dengan password `ChangeMe123!` tercantum di repo publik dan
bisa ada di server bila seeder pernah berjalan tanpa membaca `.env`.

1. Login ke `https://$DOMAIN/admin/` dengan `CARIPASAL_SUPER_ADMIN_EMAIL` dan
   `CARIPASAL_SUPER_ADMIN_PASSWORD` dari `backend-laravel/.env`.
2. Buka Akun Admin. Jika ada `superadmin@caripasal.local` dan itu bukan akun yang dipakai login,
   klik Nonaktifkan.
3. Jika akun yang dipakai login adalah `superadmin@caripasal.local` atau passwordnya `ChangeMe123!`:
   logout, klik Lupa Password? di halaman login, lalu atur password baru dari email reset.

## 10. Verifikasi

```bash
curl -fsS https://$DOMAIN/api/health && echo OK
curl -sI https://$DOMAIN/mobile/ | head -n 1                       # HTTP 200
curl -sI https://$DOMAIN/mobile/caripasal-sw.js | grep -i cross-origin
```

Perintah terakhir harus menampilkan `cross-origin-opener-policy` dan
`cross-origin-embedder-policy`. Jika kosong, `include` Nginx di langkah 5 belum aktif.

Lalu cek di browser:

- [ ] Admin > Dashboard menampilkan 3181 pasal dan 4 undang-undang.
- [ ] Admin > Pasal: tidak ada lagi nomor berformat `Pasal 1`.
- [ ] `https://ubgpasal.ubg.ac.id/mobile/`: login, tunggu unduhan data selesai (3181 pasal).
- [ ] Cari "pencurian": muncul pasal KUHP Tindak Pidana Pencurian.
- [ ] Buka satu pasal, matikan internet, reload halaman: pasal tetap bisa dibaca.

Jika `curl .../api/health` mengembalikan HTML `Just a moment...`, Cloudflare memberi challenge ke
API. Buat rule: Hostname `ubgpasal.ubg.ac.id` AND URI Path starts with `/api/` > Skip (Managed
Challenge, Bot Fight Mode, Browser Integrity Check). Admin dan `/mobile/` boleh tetap lewat
Cloudflare.

## Rollback

Jika aplikasi tidak bisa dipakai setelah update (variabel `$APP_ROOT`, `$PHP_BIN`, `$DB_HOST`,
`$DB_USER`, `$DB_NAME`, `$BACKUP_DIR` berasal dari langkah 1 dan 3; isi ulang bila sesi SSH sudah
berganti):

1. Hapus dulu baris `include .../deploy/aapanel-mobile-web.conf;` dari config Nginx (langkah 5).
   File itu tidak ada di versi lama, dan tanpa dihapus Nginx gagal reload.
2. Jalankan:

```bash
cd "$APP_ROOT"
git reset --hard sebelum-update-20c1d99
cp "$BACKUP_DIR/env.backup" backend-laravel/.env
pg_restore -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" --clean --if-exists \
  "$BACKUP_DIR/database.dump"
SKIP_GIT=1 bash deploy/aapanel-deploy.sh
```

Jangan memakai `migrate:rollback`: migration baru menghapus kolom kata kunci dan tidak bisa
mengembalikan isinya tanpa backup.

Catatan: `--clean` hanya menghapus tabel yang ada di backup; tabel baru dari update tetap ada tetapi
tidak dipakai versi lama. Cara paling bersih: aaPanel > Databases > hapus lalu buat ulang database
dengan nama dan user yang sama, kemudian jalankan `pg_restore` tanpa `--clean`.

## Update Berikutnya

Setelah update ini, setiap update cukup (isi ulang variabel langkah 1 bila sesi SSH baru):

```bash
cd "$APP_ROOT"
bash deploy/aapanel-update.sh
SKIP_GIT=1 bash deploy/aapanel-mobile-web-update.sh
```

Langkah 5, 7, dan 9 tidak perlu diulang. Backup database tetap disarankan sebelum setiap update.

## Masalah Umum

| Gejala | Penyebab dan solusi |
|---|---|
| Doctor `[FAIL] pdo_pgsql not loaded` | aaPanel > PHP > Install extensions, lalu ulangi langkah 2. |
| `PHP function disabled ... putenv/proc_open` | aaPanel > PHP > Disabled functions, hapus `putenv` dan `proc_open`. |
| `Not possible to fast-forward, aborting.` | Ada perubahan manual di server. Simpan `git diff`, jalankan `git checkout -- .`, ulangi langkah 4. |
| `fatal: detected dubious ownership in repository` | Pemilik folder berbeda dengan user SSH. Jalankan `git config --global --add safe.directory $APP_ROOT`. |
| Langkah 7: `Dibatalkan: N pasal sudah diverifikasi admin` | Perintah sudah pernah dijalankan dan admin mulai memverifikasi. Normal, jangan dijalankan lagi. |
| Langkah 7: `Harus ada tepat satu file .xlsx` | Folder `data-import/` tidak lengkap. Cek `git status`, ulangi langkah 4. |
| Import xlsx dari dashboard gagal `413` | `client_max_body_size` belum ada di blok `/api/` (langkah 5). |
| `/admin/` blank atau 404 | `alias` Nginx harus `.../projek-pasal/admin/`; folder dibuat oleh script deploy. |
| Error `Permission denied` di `storage/logs` | `chown -R <user_ssh>:www backend-laravel/storage backend-laravel/bootstrap/cache` |
| Mobile web masih versi lama | Tutup semua tab/aplikasi CariPasal lalu buka lagi. Jangan hapus data situs, karena data offline ikut terhapus. |
| Login mobile gagal "batas 3 perangkat aktif" | Admin > Akun Admin (atau Pengguna Mobile) > Perangkat mobile > Paksa keluar perangkat lama. |

Catatan:

- `CARIPASAL_SUPER_ADMIN_*` di `.env` hanya dipakai saat akun itu belum ada; deploy tidak menimpa
  passwordnya. Ganti password lewat Lupa Password? di halaman login.
- Fitur Sumber Data (ambil dari datahukum.com) tetap mati (`DATAHUKUM_FETCH_ENABLED=false`) sampai
  izin data keluar. Selama mati, server tidak butuh queue worker atau Python.
