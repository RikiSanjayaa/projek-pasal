# Deployment CariPasal di aaPanel

Dokumen ini menjelaskan deployment CariPasal untuk aaPanel dengan Nginx, PHP-FPM, dan PostgreSQL,
tanpa Docker. Node.js hanya dipakai untuk build admin dashboard di server; Flutter tidak dipasang
di server.

Server yang sudah berjalan dan ingin update ke versi terbaru: ikuti
[PANDUAN_UPDATE_AAPANEL.md](PANDUAN_UPDATE_AAPANEL.md).

## Ringkasan

- Backend: Laravel 13, PHP 8.3 atau 8.4, Sanctum untuk token admin dan mobile.
- Admin dashboard: React 19 + Vite 7, dibuild di server oleh script deploy dengan base path
  `/admin/`.
- Mobile web: Flutter Web (PWA offline), dibuild pengembang di laptop dan di-commit ke
  `mobile-web-dist/`. Server hanya menyalinnya ke `/mobile/`.
- Aplikasi Android (APK): dibuild pengembang, memanggil API yang sama.
- Database: PostgreSQL. Migration memakai SQL khusus PostgreSQL (enum, array, trigger, jsonb).
- Queue/cache/session: driver `database`, tabelnya dibuat migration.
- Queue worker hanya dibutuhkan bila fitur Sumber Data dinyalakan (lihat bagian akhir). Tidak ada
  scheduler, jadi tidak perlu cron.
- Email reset password dikirim langsung saat request (SMTP kampus atau Resend).
- Data hukum awal: KUHP 625 pasal, KUHAP 369, UU ITE 63, KUHPerdata 2124, dari
  `data-import/*.xlsx`.

## Arsitektur yang Direkomendasikan

Satu subdomain, tiga path:

```text
https://pasal.kampus.ac.id/admin/    React admin dashboard
https://pasal.kampus.ac.id/api/      Laravel REST API
https://pasal.kampus.ac.id/mobile/   Flutter Web mobile (PWA)
```

Struktur folder di server:

```text
/www/wwwroot/pasal
├── backend-laravel/       Laravel API (.env ada di sini)
├── admin-dashboard/       source React, dibuild oleh script deploy
├── admin/                 hasil build admin, dibuat script deploy
├── mobile-web-dist/       hasil build Flutter Web dari repo
├── mobile/                salinan mobile-web-dist, dibuat script publish
├── data-import/           xlsx data hukum
└── deploy/                script dan potongan config aaPanel
```

## Requirement Server

- aaPanel dengan Nginx dan SSL Let's Encrypt.
- PHP 8.3 atau 8.4, dengan extension `pdo_pgsql`, `pgsql`, `fileinfo`, `mbstring`, `openssl`,
  `curl`, `zip`, `xml`, `gd`. Fungsi `putenv` dan `proc_open` tidak boleh di-disable (dipakai
  Composer).
- PHP `upload_max_filesize = 20M` dan `post_max_size = 24M` (unggah PDF naskah resmi).
- Composer 2.
- Node.js 22 atau lebih baru (build Vite 7).
- PostgreSQL, hanya bisa diakses dari server (jangan dibuka ke publik).
- Git dan Bash.

## Setup Pertama

Isi variabel di sesi SSH. Semua perintah di dokumen ini memakainya, dan script deploy membacanya
langsung:

```bash
export DOMAIN=pasal.kampus.ac.id
export APP_ROOT=/www/wwwroot/pasal
export PHP_BIN=/www/server/php/84/bin/php             # PHP 8.3: .../php/83/bin/php
export PHP_FPM_SERVICE=/etc/init.d/php-fpm-84         # PHP 8.3: php-fpm-83
```

1. Buat website di aaPanel dengan domain `$DOMAIN` dan pasang SSL.
2. Clone repo:

   ```bash
   git clone https://github.com/RikiSanjayaa/projek-pasal.git "$APP_ROOT"
   cd "$APP_ROOT"
   ```

3. Buat database dan user PostgreSQL (aaPanel > Databases > PostgreSQL, atau lewat `psql`):

   ```sql
   CREATE USER caripasal_user WITH PASSWORD 'ganti_password_database';
   CREATE DATABASE caripasal OWNER caripasal_user ENCODING 'UTF8' TEMPLATE template0;
   \c caripasal
   GRANT ALL ON SCHEMA public TO caripasal_user;
   ```

4. Jalankan script deploy sekali. Karena `.env` belum ada, script membuatnya dari
   `.env.production.example`, membuat `APP_KEY`, lalu berhenti:

   ```bash
   bash deploy/aapanel-deploy.sh
   ```

5. Edit `backend-laravel/.env`:

   ```env
   APP_URL=https://pasal.kampus.ac.id
   APP_DEBUG=false

   DB_HOST=127.0.0.1
   DB_DATABASE=caripasal
   DB_USERNAME=caripasal_user
   DB_PASSWORD=ganti_password_database

   CARIPASAL_SUPER_ADMIN_EMAIL=superadmin@kampus.ac.id
   CARIPASAL_SUPER_ADMIN_PASSWORD=ganti_password_awal_yang_kuat

   MAIL_MAILER=smtp
   MAIL_HOST=smtp.kampus.ac.id
   MAIL_USERNAME=pasal@kampus.ac.id
   MAIL_PASSWORD=ganti_password_email
   MAIL_FROM_ADDRESS=pasal@kampus.ac.id

   ADMIN_PASSWORD_RESET_URL=https://pasal.kampus.ac.id/admin/reset-password
   MOBILE_PASSWORD_RESET_URL=https://pasal.kampus.ac.id/admin/reset-password

   DATAHUKUM_FETCH_ENABLED=false
   ```

   `CARIPASAL_SUPER_ADMIN_*` hanya dipakai seeder saat akun itu belum ada. Setelah itu password
   diganti lewat Lupa Password? di halaman login.

## Precheck Server

```bash
cd "$APP_ROOT"
bash deploy/aapanel-doctor.sh
```

Doctor mengecek PHP, Composer, Node/NPM, Git, extension PHP, fungsi `putenv`/`proc_open`, folder
writable Laravel, socket PHP-FPM aaPanel di `/tmp`, dan service PHP-FPM. Semua baris harus `[OK]`.

## Deploy

```bash
cd "$APP_ROOT"
bash deploy/aapanel-deploy.sh
```

Script menjalankan berurutan:

- `git pull --ff-only` branch `main`;
- `composer install --no-dev --optimize-autoloader`;
- `php artisan migrate --force` dan `db:seed --force` (super admin dan data UU dasar);
- `optimize:clear`, `config:cache`, `view:cache`;
- membuat `admin-dashboard/.env.production`, `npm ci`, `npm run build`, lalu menyalin hasilnya ke
  `$APP_ROOT/admin`;
- memperbaiki permission `storage` dan `bootstrap/cache`;
- restart PHP-FPM, reload Nginx, health check `https://$DOMAIN/api/health`.

Variabel opsional:

| Variabel | Default | Fungsi |
|---|---|---|
| `BRANCH` | `main` | Branch yang di-pull |
| `SKIP_GIT=1` | `0` | Tidak menjalankan `git pull` |
| `SKIP_NPM_CI=1` | `0` | Tidak menjalankan `npm ci` |
| `RUN_TESTS=1` | `0` | Menjalankan `php artisan test` |
| `CACHE_ROUTES=1` | `0` | Menjalankan `route:cache` (sebagian kombinasi PHP aaPanel gagal membuatnya) |
| `WRITABLE_OWNER` | `user_ssh:www` | Owner `storage` dan `bootstrap/cache` |

`deploy/aapanel-update.sh` adalah pembungkus singkat untuk update rutin dan memanggil script yang
sama.

## Isi Data Hukum

Sekali setelah deploy pertama:

```bash
cd "$APP_ROOT/backend-laravel"
$PHP_BIN artisan caripasal:reset-data-hukum
```

Ketik `yes` saat diminta. Perintah menghapus permanen semua pasal (termasuk pasal contoh dari
seeder), mengaktifkan KUHP, KUHAP, KUHPerdata, dan UU ITE, lalu mengimport
`data-import/<slug>/*.xlsx` dalam satu transaksi. Hasilnya 3181 pasal, 986 link antarpasal, dan
942 versi riwayat, semuanya berstatus "Perlu verifikasi". Bila ada error, tidak ada yang berubah.
Setelah admin mulai memverifikasi pasal, perintah ini menolak berjalan lagi.

Untuk menambah atau memperbarui data berikutnya, pakai Admin > Import Data (xlsx) atau Admin >
Sumber Data.

## Mobile Web

Server tidak membuild Flutter. Pengembang membuild di laptop lalu commit `mobile-web-dist/`:

```powershell
.\build-mobile-web.ps1 -ApiBaseUrl "https://pasal.kampus.ac.id/api" `
  -WebAppUrl "https://pasal.kampus.ac.id" -BaseHref "/mobile/"
```

Di server, setelah deploy:

```bash
cd "$APP_ROOT"
SKIP_GIT=1 bash deploy/aapanel-mobile-web-update.sh
```

Script menolak build yang belum punya file offline (`caripasal-sw.js`, `offline.js`,
`offline-build.json`), menyalin `mobile-web-dist/` ke `$APP_ROOT/mobile`, reload Nginx, lalu
mengecek `/mobile/` dan `/api/health`. Detail build dan pengujian offline:
[MOBILE_WEB_AAPANEL.md](MOBILE_WEB_AAPANEL.md).

APK Android dibuild pengembang dengan `--dart-define=API_BASE_URL=https://$DOMAIN/api` dan
`--dart-define=WEB_APP_URL=https://$DOMAIN`.

## Nginx aaPanel

aaPanel > Website > domain > Config. Tambahkan di dalam `server { ... }`, sesuaikan path dengan
`$APP_ROOT` dan socket dengan versi PHP (`ls /tmp/php-cgi-*.sock`):

```nginx
location = /admin {
    return 301 /admin/;
}

location ^~ /admin/ {
    alias /www/wwwroot/pasal/admin/;
    try_files $uri $uri/ /admin/index.html;
}

location ^~ /api/ {
    # Import xlsx dari dashboard (KUHPerdata ~2,5 MB) dan unggah PDF naskah resmi.
    client_max_body_size 20m;
    try_files $uri /index.php?$query_string;

    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME /www/wwwroot/pasal/backend-laravel/public/index.php;
    fastcgi_param DOCUMENT_ROOT /www/wwwroot/pasal/backend-laravel/public;
    fastcgi_param SCRIPT_NAME /index.php;
    fastcgi_param REQUEST_URI $request_uri;
    fastcgi_param HTTPS on;
    fastcgi_pass unix:/tmp/php-cgi-84.sock;
}

location = /mobile {
    return 301 /mobile/;
}

location ^~ /mobile/ {
    root /www/wwwroot/pasal;
    index index.html;
    try_files $uri $uri/ /mobile/index.html;
    add_header Cache-Control "no-cache, no-store, must-revalidate" always;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Aset precache yang hilang harus 404, bukan halaman SPA.
    location ~* \.(js|wasm|json|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|otf|eot|bin)$ {
        try_files $uri =404;
    }
}

location ~ \.php$ {
    return 404;
}
```

- Blok `/admin/` dan `/api/` juga ada di `deploy/aapanel-nginx.conf`; blok `/mobile/` di
  `deploy/aapanel-mobile-web.conf`. Server kampus dengan `APP_ROOT`
  `/www/wwwroot/hukum-ubg.ac.id/projek-pasal` cukup memakai
  `include .../deploy/aapanel-mobile-web.conf;`. Server dengan path lain menyalin bloknya seperti di
  atas; jangan mengedit file di repo, karena `git pull --ff-only` akan gagal.
- Header COOP/COEP wajib untuk database offline di browser. `.wasm` harus dikirim sebagai
  `application/wasm`; cek dengan `curl -sI https://$DOMAIN/mobile/sqlite3.wasm | grep -i content-type`.

Tes dan reload:

```bash
/www/server/nginx/sbin/nginx -t && /etc/init.d/nginx reload
```

Cloudflare: endpoint `/api/` tidak boleh diberi challenge (Managed Challenge, Bot Fight Mode,
Browser Integrity Check), karena aplikasi mobile tidak bisa menyelesaikannya. Admin dan `/mobile/`
boleh tetap lewat Cloudflare.

## Email Reset Password

Pakai SMTP kampus di `.env` bila tersedia. Jika SMTP Gmail atau server lain timeout dari aaPanel,
port keluar `465/587` diblokir; pakai Resend yang berjalan lewat HTTPS port 443:

```env
MAIL_MAILER=resend
RESEND_API_KEY=re_xxxxxxxxx
MAIL_FROM_ADDRESS=onboarding@resend.dev
MAIL_FROM_NAME="CariPasal"
```

Setelah mengubah `.env`:

```bash
cd "$APP_ROOT/backend-laravel"
$PHP_BIN artisan optimize:clear
$PHP_BIN artisan config:cache
$PHP_FPM_SERVICE restart
```

Tes kirim email:

```bash
$PHP_BIN artisan tinker --execute='Mail::raw("Tes email CariPasal", fn ($m) => $m->to("emailtujuan@gmail.com")->subject("Tes Email CariPasal")); echo "sent\n";'
```

## Opsional: Sumber Data

Admin > Sumber Data mengambil pembaruan dari datahukum.com lewat queue. Fitur ini mati
(`DATAHUKUM_FETCH_ENABLED=false`) sampai izin pemakaian data keluar. Bila nanti dinyalakan:

1. Pasang Python 3, lalu buat venv:

   ```bash
   python3 -m venv /opt/import-venv
   /opt/import-venv/bin/pip install -r "$APP_ROOT/import-tools/requirements.txt"
   ```

2. Isi `.env`, lalu jalankan ulang deploy:

   ```env
   DATAHUKUM_FETCH_ENABLED=true
   IMPORT_PYTHON=/opt/import-venv/bin/python
   IMPORT_TOOLS_DIR=/www/wwwroot/pasal/import-tools
   ```

3. Jalankan worker lewat aaPanel > Supervisor, dengan user `www` dan folder
   `$APP_ROOT/backend-laravel`:

   ```bash
   /www/server/php/84/bin/php artisan queue:work --queue=imports,default --timeout=900
   ```

## Troubleshooting

| Gejala | Penyebab dan solusi |
|---|---|
| Script berhenti `Missing PHP extension` | aaPanel > PHP > Install extensions, lalu ulangi. |
| `PHP function disabled ... putenv/proc_open` | aaPanel > PHP > Disabled functions, hapus `putenv` dan `proc_open`. |
| Script berhenti `Created backend-laravel/.env` | Normal pada deploy pertama. Isi `.env`, lalu jalankan ulang. |
| Migration gagal `permission denied for schema public` | PostgreSQL 15+: `GRANT ALL ON SCHEMA public TO caripasal_user;` |
| `/api/health` 404 atau 502 | Socket `fastcgi_pass` tidak sesuai versi PHP. Cek `ls /tmp/php-cgi-*.sock`. |
| `/admin/` blank atau 404 | `alias` harus menunjuk `$APP_ROOT/admin/`; folder dibuat script deploy. |
| Import xlsx gagal `413` | `client_max_body_size 20m` belum ada di blok `/api/`. |
| Mobile web tidak bisa offline | Header COOP/COEP tidak terkirim. Cek `curl -sI https://$DOMAIN/mobile/caripasal-sw.js`. |
| Login mobile gagal "batas 3 perangkat aktif" | Admin > Akun Admin atau Pengguna Mobile > Perangkat mobile > Paksa keluar. |
| `/api/health` mengembalikan `Just a moment...` | Cloudflare challenge di `/api/`. Buat rule Skip untuk path tersebut. |
| Email reset tidak terkirim | Cek `backend-laravel/storage/logs/laravel.log`; port SMTP diblokir, pakai Resend. |

Catatan keamanan: jangan commit `.env`, wajib `APP_DEBUG=false`, PostgreSQL jangan dibuka ke
publik, dan backup database sebelum update besar.
