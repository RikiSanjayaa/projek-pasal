# CariPasal

CariPasal adalah aplikasi pencarian dan pengelolaan pasal hukum Indonesia.

Arsitektur production diarahkan ke satu subdomain:

```text
https://pasal.kampus.ac.id/admin  -> React admin dashboard
https://pasal.kampus.ac.id/api    -> Laravel REST API
```

## Stack

- Backend: Laravel + PostgreSQL + Sanctum
- Admin: React + Mantine
- Mobile: Flutter + Drift/offline sync
- Local dev: Docker Compose
- Deploy target: aaPanel + Nginx + PHP-FPM

## Struktur Folder

```text
projek-pasal/
  backend-laravel/      Laravel REST API
  admin-dashboard/      React admin dashboard
  pasal_mobile_app/     Flutter mobile app
  deploy/               Script dan konfigurasi aaPanel
  docs/                 Dokumentasi teknis
```

## Fitur Utama

- Admin login dengan Laravel Sanctum
- CRUD undang-undang dan pasal
- Trash/restore pasal
- Relasi antar pasal
- Bulk import Excel
- OCR import dari foto halaman buku hukum
- Kelola user mobile dan admin
- Reset password via SMTP/Mailpit/Resend
- Mobile sync full dan incremental untuk mode offline

## Development Dengan Docker

### Layout Env

```text
/.env                               -> hanya untuk Docker Compose
backend-laravel/.env.docker         -> env backend untuk container Docker
backend-laravel/.env                -> env backend jika jalan manual
admin-dashboard/.env.docker         -> env frontend untuk build Docker
admin-dashboard/.env                -> env frontend jika jalan manual
```

### Setup Awal

```powershell
copy .env.example .env
copy backend-laravel\.env.docker.example backend-laravel\.env.docker
copy admin-dashboard\.env.docker.example admin-dashboard\.env.docker
docker compose up -d --build
```

Stack lokal default:

```text
Admin dashboard: http://127.0.0.1:8080
Laravel API:     http://127.0.0.1:8000/api
PostgreSQL:      127.0.0.1:55432
Mailpit:         http://127.0.0.1:8025
```

Seeder membuat super admin awal:

```text
email:    superadmin@caripasal.local
password: ChangeMe123!
```

Untuk test reset password saat development:

1. buka `http://127.0.0.1:8025`
2. kirim reset password dari halaman login admin
3. buka email di Mailpit

## Alternatif Non-Docker

### Backend Laravel

```powershell
cd backend-laravel
composer install
copy .env.example .env
php artisan key:generate
php artisan migrate --seed
php artisan serve --host=127.0.0.1 --port=8000
```

Jika backend dijalankan manual, sesuaikan `DB_*`, `MAIL_*`, dan reset URL di `backend-laravel/.env`.

### Admin Dashboard

```powershell
cd admin-dashboard
npm install
npm run dev
```

Admin lokal:

```text
http://127.0.0.1:5173
```

Health check API lokal:

```text
http://127.0.0.1:8000/api/health
```

### Mobile Emulator

Untuk Android emulator, base URL API lokal:

```text
http://10.0.2.2:8000/api
```

## Dokumentasi Teknis

- [Arsitektur Sistem](docs/ARSITEKTUR.md)
- [Database Schema](docs/DATABASE.md)
- [Deploy CariPasal di aaPanel](docs/AAPANEL_DEPLOYMENT.md)
- [Catatan Migrasi Historis](docs/LARAVEL_POSTGRESQL_MIGRATION_PLAN.md)

## Deploy aaPanel

Update rutin:

```bash
cd /www/wwwroot/pasal
DOMAIN=pasal.kampus.ac.id bash deploy/aapanel-update.sh
```

Cek prasyarat server:

```bash
cd /www/wwwroot/pasal
bash deploy/aapanel-doctor.sh
```

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

- Jangan commit file env yang berisi credential production.
- Root `.env` jangan dipakai sebagai sumber konfigurasi Laravel/frontend production.
- Pastikan `APP_DEBUG=false`.
- PostgreSQL jangan dibuka ke publik.
- Backup database sebelum update besar.
- Jika SMTP Gmail timeout dari aaPanel, gunakan `MAIL_MAILER=resend` karena Resend memakai HTTPS port 443.

## Lisensi

Hak Cipta 2026. Seluruh hak dilindungi.
