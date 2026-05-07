# CariPasal

CariPasal adalah aplikasi pencarian dan pengelolaan pasal hukum Indonesia.

Arsitektur saat ini sudah diarahkan ke deployment kampus dengan satu subdomain:

```text
https://pasal.kampus.ac.id/admin  -> React admin dashboard
https://pasal.kampus.ac.id/api    -> Laravel REST API
```

## Stack

- Backend: Laravel + PostgreSQL + Sanctum
- Admin: React + Mantine
- Mobile: Flutter + local database/offline sync
- Deploy target: aaPanel + Nginx + PHP-FPM

## Struktur Folder

```text
projek-pasal/
  backend-laravel/      Laravel REST API
  admin-dashboard/      React admin dashboard
  pasal_mobile_app/     Flutter mobile app
  deploy/               Script dan konfigurasi aaPanel
  docs/                 Dokumentasi teknis
  supabase/             Arsip schema lama sampai migrasi final selesai
```

## Fitur Utama

- Admin login dengan Laravel Sanctum
- CRUD undang-undang dan pasal
- Trash/restore pasal
- Relasi antar pasal
- Bulk import Excel
- OCR import dari foto halaman buku hukum
- Kelola user mobile dan admin
- Batas 3 perangkat aktif untuk user mobile
- Reset password via SMTP/Resend
- Mobile sync full/incremental untuk mode offline

## Local Development

### 1. Jalankan PostgreSQL lokal

```powershell
docker compose -f docker-compose.local.yml up -d
```

### 2. Jalankan backend Laravel

```powershell
cd backend-laravel
composer install
copy .env.example .env
php artisan key:generate
php artisan migrate --seed
php artisan serve --host=127.0.0.1 --port=8000
```

### 3. Jalankan admin dashboard

```powershell
cd admin-dashboard
npm install
npm run dev
```

Admin lokal:

```text
http://127.0.0.1:5173/admin
```

API lokal:

```text
http://127.0.0.1:8000/api/health
```

### 4. Jalankan mobile emulator

Untuk Android emulator, mobile memakai API lokal lewat:

```text
http://10.0.2.2:8000/api
```

## Deploy aaPanel

Dokumentasi utama:

- [Deploy CariPasal di aaPanel](docs/AAPANEL_DEPLOYMENT.md)

Setelah prasyarat server siap, update rutin cukup:

```bash
cd /www/wwwroot/pasal
DOMAIN=pasal.kampus.ac.id bash deploy/aapanel-update.sh
```

Sebelum deploy pertama atau saat pindah server, jalankan doctor:

```bash
cd /www/wwwroot/pasal
bash deploy/aapanel-doctor.sh
```

## Script Deploy

- `deploy/aapanel-doctor.sh`: cek PHP, Composer, Node, extension PostgreSQL, fungsi PHP, socket aaPanel, dan path project.
- `deploy/aapanel-deploy.sh`: pull kode, install dependency, migrate, cache Laravel, build admin, publish `/admin`, restart PHP-FPM, reload Nginx, dan health check.
- `deploy/aapanel-update.sh`: wrapper pendek untuk update rutin.

Variabel yang sering dipakai:

```bash
DOMAIN=pasal.kampus.ac.id
APP_ROOT=/www/wwwroot/pasal
BRANCH=main
PHP_BIN=/www/server/php/84/bin/php
PHP_FPM_SERVICE=/etc/init.d/php-fpm-84
RUN_TESTS=1
CACHE_ROUTES=1
SKIP_GIT=1
SKIP_NPM_CI=1
```

Catatan aaPanel: script deploy menyiapkan permission `storage` dan `bootstrap/cache` sebelum Composer berjalan. Default `route:cache` dimatikan agar aman di aaPanel; aktifkan hanya jika server sudah teruji dengan `CACHE_ROUTES=1`.

## Verifikasi

Backend:

```bash
cd backend-laravel
php artisan test
```

Admin:

```bash
cd admin-dashboard
npm run build
```

Mobile:

```bash
cd pasal_mobile_app
flutter analyze
flutter build apk --release
```

## Catatan Production

- Jangan commit `.env`.
- Pastikan `APP_DEBUG=false`.
- PostgreSQL jangan dibuka ke publik.
- Backup database sebelum update besar.
- Build APK baru diperlukan jika ada perubahan di folder `pasal_mobile_app`.
- Jika SMTP Gmail timeout dari aaPanel, gunakan `MAIL_MAILER=resend` karena Resend memakai HTTPS port 443.

## Lisensi

Hak Cipta 2026. Seluruh hak dilindungi.
