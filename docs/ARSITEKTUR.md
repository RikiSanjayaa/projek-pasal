# Arsitektur Sistem CariPasal

## Gambaran Umum

CariPasal terdiri dari 3 aplikasi utama:

1. `admin-dashboard` untuk admin web
2. `backend-laravel` untuk REST API, autentikasi, audit, dan business logic
3. `pasal_mobile_app` untuk aplikasi mobile Flutter dengan penyimpanan offline

## Arsitektur Saat Ini

```text
Admin Dashboard (React + Mantine)  --->
                                      Laravel API + Sanctum + PostgreSQL
Mobile App (Flutter + Drift)      --->
```

Backend menangani:

- autentikasi admin dan mobile
- manajemen undang-undang dan pasal
- relasi antar pasal
- audit log
- manajemen perangkat user/admin
- sinkronisasi data mobile
- reset password via email

## Flow Utama

### Admin Login

```text
Login Form -> POST /api/admin/login -> Sanctum token -> frontend simpan token
```

### Admin CRUD

```text
Dashboard -> API Laravel -> Controller/Service -> PostgreSQL -> Audit Log
```

### Mobile Sync

```text
Flutter App -> /api/mobile/login
            -> /api/mobile/sync/check
            -> /api/mobile/sync/updates atau /api/mobile/sync/full
            -> simpan hasil ke Drift lokal
```

### Reset Password

```text
Login Page -> /api/password/forgot -> simpan token reset -> kirim email SMTP
Reset Page -> /api/password/reset -> update password -> hapus token Sanctum lama
```

## Otorisasi

- Admin dashboard memakai tabel `admin_users`
- Mobile app memakai tabel `mobile_users`
- Endpoint admin dilindungi `auth:sanctum` dan middleware role
- Endpoint mobile dilindungi `auth:sanctum`, status user, expiry, dan validasi device

## Komponen Data Inti

- `undang_undang`
- `pasal`
- `pasal_links`
- `admin_users`
- `mobile_users`
- `user_devices`
- `admin_devices`
- `audit_logs`
- `password_reset_tokens`
- `personal_access_tokens`

## Development Lokal

Mode development default memakai Docker Compose dari root project.

```text
/.env                           -> hanya untuk Compose/port mapping
backend-laravel/.env.docker     -> env backend dalam container
admin-dashboard/.env.docker     -> env build frontend dalam container
```

Service lokal default:

- Admin: `http://127.0.0.1:8080`
- API: `http://127.0.0.1:8000/api`
- Mailpit: `http://127.0.0.1:8025`
- PostgreSQL: `127.0.0.1:55432`

## Catatan

- Dokumen lama berbasis Supabase sudah tidak merepresentasikan runtime aktif proyek.
- Dokumen `LARAVEL_POSTGRESQL_MIGRATION_PLAN.md` dipertahankan sebagai catatan migrasi historis.
