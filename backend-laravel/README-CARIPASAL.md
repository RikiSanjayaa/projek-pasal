# CariPasal Laravel Backend

Backend ini adalah target migrasi dari Supabase ke Laravel + PostgreSQL.

## Setup Lokal

```bash
cd backend-laravel
composer install
cp .env.example .env
php artisan key:generate
```

Edit koneksi PostgreSQL di `.env`:

```env
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=caripasal
DB_USERNAME=caripasal_user
DB_PASSWORD=...
```

Jalankan migration dan seed:

```bash
php artisan migrate --seed
php artisan serve
```

Super admin awal dibuat dari env:

```env
CARIPASAL_SUPER_ADMIN_EMAIL=superadmin@caripasal.local
CARIPASAL_SUPER_ADMIN_PASSWORD=ChangeMe123!
CARIPASAL_SUPER_ADMIN_NAME="Super Admin"
```

Ganti password default sebelum production.

## Endpoint Awal

```text
GET  /api/health
POST /api/admin/login
GET  /api/admin/me
POST /api/mobile/login
GET  /api/mobile/sync/full
```

Route lengkap:

```bash
php artisan route:list --path=api
```

## Catatan Migrasi

- UUID lama dari Supabase harus dipertahankan saat import data.
- Password Supabase Auth tidak dimigrasikan langsung. Gunakan reset password atau password awal baru.
- PostgreSQL jangan diekspos publik; cukup Laravel yang bisa mengakses database.
- Admin dashboard production direncanakan di `/admin`, API di `/api`.
