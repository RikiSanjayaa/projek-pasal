# Skema Migrasi Backend ke Laravel + PostgreSQL

> Dokumen ini adalah catatan migrasi historis dari arsitektur lama berbasis Supabase ke implementasi Laravel + PostgreSQL yang sekarang sudah aktif. Untuk setup dan arsitektur terkini, lihat `README.md`, `docs/ARSITEKTUR.md`, dan `docs/DATABASE.md`.

Dokumen ini adalah rancangan migrasi backend CariPasal dari Supabase ke Laravel + PostgreSQL untuk deployment yang lebih mudah di aaPanel dengan satu subdomain.

## Tujuan Migrasi

- Mengganti Supabase Cloud/self-host dengan backend Laravel yang mudah dijalankan di aaPanel.
- Memakai satu subdomain, misalnya `https://pasal.kampus.ac.id`.
- Mempertahankan React admin dashboard dan Flutter mobile app semaksimal mungkin.
- Mempertahankan fitur utama: login, role admin, CRUD pasal, bulk import, audit log, user mobile, device binding, dan sync offline.
- Mengurangi ketergantungan ke fitur Supabase: Auth, RLS, REST auto API, RPC, dan Edge Functions.

## Arsitektur Baru

```text
https://pasal.kampus.ac.id
|
|-- /                 React Admin Dashboard
|-- /api              Laravel REST API
|-- /storage          Laravel public storage, jika diperlukan
|-- /docs             API docs, opsional

Mobile App Flutter
|
|-- HTTPS request ke https://pasal.kampus.ac.id/api
|-- Local offline database tetap memakai Drift/SQLite
```

Komponen:

- `admin-dashboard`: tetap React + Mantine.
- `pasal_mobile_app`: tetap Flutter + Drift.
- `backend-laravel`: aplikasi Laravel baru.
- Database: PostgreSQL, idealnya dari plugin/database manager aaPanel. Jika aaPanel kampus belum menyediakan PostgreSQL yang stabil, PostgreSQL bisa dijalankan via Docker di aaPanel.
- Web server: Nginx/Apache aaPanel.
- Process manager: tidak wajib, kecuali ada queue/worker.

## Kenapa PostgreSQL

PostgreSQL dipilih karena Supabase juga memakai PostgreSQL. Ini membuat migrasi lebih aman dibanding pindah ke MySQL/MariaDB.

Keuntungan utama:

- Schema Supabase lebih mudah dipakai ulang.
- Tipe data `uuid`, `jsonb`, enum, function, dan trigger lebih dekat.
- Data export/import dari Supabase lebih sedikit transformasi.
- Function sync seperti `check_sync_updates` dan `get_sync_updates` bisa dipertahankan sementara atau ditulis ulang bertahap.
- Query search bisa memakai PostgreSQL full-text search.

Yang tetap berubah:

- Supabase Auth tetap diganti Laravel Sanctum/Auth.
- Supabase RLS tetap diganti middleware, policy, dan gate Laravel.
- Supabase Edge Functions tetap diganti Controller/Service Laravel.
- Client React dan Flutter tetap perlu diganti dari Supabase SDK ke REST API Laravel.

## Perubahan Besar

### Dari Supabase ke Laravel

| Supabase saat ini | Pengganti Laravel |
| --- | --- |
| Supabase Auth | Laravel Sanctum token auth |
| `supabase.from(...).select()` | REST API `GET /api/...` |
| `supabase.from(...).insert()` | REST API `POST /api/...` |
| `supabase.from(...).update()` | REST API `PUT/PATCH /api/...` |
| `supabase.from(...).delete()` | REST API `DELETE /api/...` atau soft delete |
| Supabase RLS | Middleware, policy, dan gate Laravel |
| Supabase Edge Functions | Controller/service Laravel |
| Supabase RPC | Endpoint Laravel khusus |
| PostgreSQL functions/triggers | Bisa dipertahankan bila masih relevan, atau dipindah ke Laravel service/observer |

Catatan: karena targetnya tetap PostgreSQL, tidak semua logic database harus langsung dipindah ke PHP. Untuk mengurangi risiko, function/triggers yang sudah stabil bisa dipertahankan dulu, lalu dipindahkan ke Laravel service setelah behavior-nya sudah tertutup test.

## Struktur Folder Baru

```text
projek-pasal/
|-- admin-dashboard/
|-- pasal_mobile_app/
|-- backend-laravel/
|   |-- app/
|   |   |-- Http/
|   |   |   |-- Controllers/
|   |   |   |   |-- Api/
|   |   |   |   |   |-- AuthController.php
|   |   |   |   |   |-- DashboardController.php
|   |   |   |   |   |-- UndangUndangController.php
|   |   |   |   |   |-- PasalController.php
|   |   |   |   |   |-- PasalLinkController.php
|   |   |   |   |   |-- AdminUserController.php
|   |   |   |   |   |-- MobileUserController.php
|   |   |   |   |   |-- SyncController.php
|   |   |   |   |   |-- AuditLogController.php
|   |   |   |-- Middleware/
|   |   |-- Models/
|   |   |-- Services/
|   |   |   |-- AuditService.php
|   |   |   |-- SyncService.php
|   |   |   |-- UserDeviceService.php
|   |   |   |-- ImportPasalService.php
|   |-- database/
|   |   |-- migrations/
|   |   |-- seeders/
|   |-- routes/
|   |   |-- api.php
|   |-- storage/
|   |-- .env
|-- supabase/
|-- docs/
```

Folder `supabase/` sebaiknya tetap disimpan sementara sebagai sumber migrasi schema dan data sampai migrasi selesai.

## Skema Database PostgreSQL

### Extension dan Type

Gunakan extension berikut:

```sql
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

Catatan:

- Supabase migration awal memakai UUID dan beberapa function PostgreSQL. Di Laravel + PostgreSQL, `pgcrypto` memberi `gen_random_uuid()` yang praktis untuk default UUID.
- Type enum lama seperti `admin_role` dan `audit_action` bisa dipertahankan. Alternatif yang lebih sederhana untuk migration Laravel adalah memakai `VARCHAR` lalu validasi nilai di aplikasi.

### 1. `admin_users`

Untuk akun admin dashboard.

Kolom:

- `id` UUID primary key default `gen_random_uuid()`
- `email` VARCHAR(255) unique
- `password` VARCHAR(255)
- `nama` VARCHAR(255)
- `role` admin_role atau VARCHAR(50)
- `is_active` BOOLEAN default true
- `last_login_at` TIMESTAMPTZ nullable
- `created_at` TIMESTAMPTZ nullable
- `updated_at` TIMESTAMPTZ nullable
- `deleted_at` TIMESTAMPTZ nullable

Catatan:

- Di Supabase, admin memakai `auth.users` + `admin_users`. Di Laravel, password admin bisa langsung disimpan hashed di tabel ini.
- Jika ingin satu tabel auth untuk semua user, bisa memakai tabel `users`, tetapi untuk proyek ini lebih rapi dipisah antara admin dan user mobile.
- Jika enum PostgreSQL lama ingin dipertahankan, pakai type `admin_role`. Jika ingin migration Laravel lebih sederhana, pakai `VARCHAR(50)` dengan validasi enum di Laravel.
- Saat migrasi, `admin_users.id` lama dari Supabase harus dipertahankan agar audit log dan relasi `created_by` tetap cocok.

### 2. `undang_undang`

Untuk daftar KUHP, KUHPer, KUHAP, UU ITE, dan lainnya.

Kolom:

- `id` UUID primary key default `gen_random_uuid()`
- `kode` VARCHAR(50)
- `nama` VARCHAR(255)
- `nama_lengkap` TEXT nullable
- `deskripsi` TEXT nullable
- `tahun` INT nullable
- `is_active` BOOLEAN default true
- `created_at` TIMESTAMPTZ nullable
- `updated_at` TIMESTAMPTZ nullable
- `deleted_at` TIMESTAMPTZ nullable

Index:

- index `kode`
- index `tahun`
- index `is_active`
- unique opsional: `kode`

### 3. `pasal`

Untuk data pasal.

Kolom:

- `id` UUID primary key default `gen_random_uuid()`
- `undang_undang_id` UUID foreign key ke `undang_undang.id`
- `nomor` VARCHAR(100)
- `judul` VARCHAR(500) nullable
- `isi` TEXT
- `penjelasan` TEXT nullable
- `keywords` TEXT[] default `{}`
- `search_vector` TSVECTOR nullable
- `is_active` BOOLEAN default true
- `created_by` UUID nullable, foreign key ke `admin_users.id`
- `updated_by` UUID nullable, foreign key ke `admin_users.id`
- `created_at` TIMESTAMPTZ nullable
- `updated_at` TIMESTAMPTZ nullable
- `deleted_at` TIMESTAMPTZ nullable

Index:

- index `undang_undang_id`
- index `nomor`
- index `is_active`
- GIN index `search_vector`
- GIN index `keywords`
- unique opsional: `undang_undang_id`, `nomor`

Catatan:

- PostgreSQL full-text search bisa dipakai untuk pencarian admin yang lebih kuat dan lebih dekat dengan Supabase.
- Untuk pencarian mobile, data tetap disinkronkan ke Drift lalu dicari lokal seperti sekarang.
- Jika ingin search lebih cepat di admin, tambahkan generated/search vector atau GIN index setelah CRUD dasar stabil.
- Supabase schema lama memakai `keywords TEXT[]`, jadi pertahankan format ini agar export/import lebih mudah.

### 4. `pasal_links`

Untuk relasi antar pasal.

Kolom:

- `id` UUID primary key default `gen_random_uuid()`
- `source_pasal_id` UUID foreign key ke `pasal.id`
- `target_pasal_id` UUID foreign key ke `pasal.id`
- `keterangan` TEXT nullable
- `is_active` BOOLEAN default true
- `created_by` UUID nullable, foreign key ke `admin_users.id`
- `created_at` TIMESTAMPTZ nullable
- `updated_at` TIMESTAMPTZ nullable
- `deleted_at` TIMESTAMPTZ nullable

Index:

- index `source_pasal_id`
- index `target_pasal_id`
- index `is_active`
- unique opsional: `source_pasal_id`, `target_pasal_id`
- check constraint: `source_pasal_id != target_pasal_id`

### 5. `mobile_users`

Pengganti tabel `users` Supabase untuk user aplikasi mobile. Nama `mobile_users` dipakai agar tidak bentrok dengan konvensi tabel `users` Laravel.

Kolom:

- `id` UUID primary key default `gen_random_uuid()`
- `email` VARCHAR(255) unique
- `password` VARCHAR(255)
- `nama` VARCHAR(255)
- `is_active` BOOLEAN default true
- `expires_at` TIMESTAMPTZ nullable
- `last_login_at` TIMESTAMPTZ nullable
- `created_by_admin_id` UUID nullable
- `created_at` TIMESTAMPTZ nullable
- `updated_at` TIMESTAMPTZ nullable
- `deleted_at` TIMESTAMPTZ nullable

Index:

- index `email`
- index `is_active`
- index `expires_at`

Catatan:

- Jika user mobile berlaku 3 tahun, set `expires_at = now() + 3 years` saat dibuat.
- Password selalu hash dengan `Hash::make()`.
- Saat import dari Supabase, data `public.users` dipindahkan ke `mobile_users`, sementara akun password dari `auth.users` tidak bisa dipakai langsung kecuali hash auth lama ikut dimigrasikan dengan benar. Cara paling bersih: generate password awal/reset token untuk user mobile.

### 6. `user_devices`

Untuk membatasi/periksa device mobile.

Kolom:

- `id` UUID primary key default `gen_random_uuid()`
- `mobile_user_id` UUID foreign key ke `mobile_users.id`
- `device_id` VARCHAR(255)
- `device_name` VARCHAR(255) nullable
- `platform` VARCHAR(50) nullable
- `is_active` BOOLEAN default true
- `last_active_at` TIMESTAMPTZ nullable
- `created_at` TIMESTAMPTZ nullable
- `updated_at` TIMESTAMPTZ nullable

Index:

- index `mobile_user_id`
- index `device_id`
- unique opsional: `mobile_user_id`, `device_id`

### 7. `admin_devices`

Untuk tracking device admin jika fitur ini tetap dipakai.

Kolom:

- `id` UUID primary key default `gen_random_uuid()`
- `admin_user_id` UUID foreign key ke `admin_users.id`
- `device_id` VARCHAR(255)
- `device_alias` VARCHAR(255) nullable
- `user_agent` TEXT nullable
- `ip_address` VARCHAR(45) nullable
- `is_active` BOOLEAN default true
- `last_active_at` TIMESTAMPTZ nullable
- `created_at` TIMESTAMPTZ nullable
- `updated_at` TIMESTAMPTZ nullable

### 8. `audit_logs`

Untuk catatan perubahan data.

Kolom:

- `id` UUID primary key default `gen_random_uuid()`
- `admin_id` UUID nullable, foreign key ke `admin_users.id`
- `admin_email` VARCHAR(255) nullable
- `actor_type` VARCHAR(50) nullable
- `actor_id` UUID nullable
- `action` audit_action atau VARCHAR(100)
- `table_name` VARCHAR(100)
- `record_id` UUID nullable
- `old_data` JSONB nullable
- `new_data` JSONB nullable
- `metadata` JSONB nullable
- `ip_address` INET nullable
- `user_agent` TEXT nullable
- `created_at` TIMESTAMPTZ nullable

Index:

- index `actor_type`, `actor_id`
- index `table_name`, `record_id`
- index `action`
- index `created_at`

Catatan:

- Audit log lebih baik dibuat dari Laravel service/observer supaya lebih mudah dikontrol, tetapi PostgreSQL trigger dari Supabase bisa dipertahankan sementara jika diperlukan.
- Untuk migration Laravel yang sederhana, `actor_type` bisa dibuat `VARCHAR(50)` dan divalidasi di aplikasi.

### 9. `personal_access_tokens`

Tabel bawaan Laravel Sanctum untuk token API.

Digunakan untuk:

- token login admin dashboard
- token login mobile

## Model Laravel

Model yang diperlukan:

- `AdminUser`
- `UndangUndang`
- `Pasal`
- `PasalLink`
- `MobileUser`
- `UserDevice`
- `AdminDevice`
- `AuditLog`

Trait yang umum dipakai:

- `HasUuids`
- `SoftDeletes`
- `HasApiTokens` untuk model yang bisa login

## Role dan Permission

Role awal:

- `super_admin`
- `admin`
- `mobile_user`

Aturan:

- `super_admin`: semua akses, termasuk kelola admin.
- `admin`: CRUD pasal, UU, relasi pasal, bulk import, kelola user mobile jika diizinkan.
- `mobile_user`: login mobile, sync data aktif, update device info, logout.

Middleware:

- `auth:sanctum`
- `role:super_admin`
- `role:admin,super_admin`
- `mobile.active`
- `mobile.not_expired`
- `device.allowed`

## Endpoint API

Base URL:

```text
https://pasal.kampus.ac.id/api
```

### Auth Admin

```text
POST   /admin/login
POST   /admin/logout
GET    /admin/me
POST   /admin/password/forgot
POST   /admin/password/reset
```

Contoh login:

```json
{
  "email": "admin@example.com",
  "password": "password"
}
```

Response:

```json
{
  "token": "plain-text-sanctum-token",
  "user": {
    "id": "uuid",
    "email": "admin@example.com",
    "nama": "Admin",
    "role": "super_admin"
  }
}
```

### Auth Mobile

```text
POST   /mobile/login
POST   /mobile/logout
GET    /mobile/me
POST   /mobile/device/register
POST   /mobile/device/heartbeat
```

Request login mobile:

```json
{
  "email": "user@example.com",
  "password": "password",
  "device_id": "device-unique-id",
  "device_name": "Samsung A55",
  "platform": "android"
}
```

Validasi login:

- user ada
- password benar
- user aktif
- belum expired
- device valid atau bisa didaftarkan sesuai aturan

### Dashboard

```text
GET /admin/dashboard/summary
```

Response berisi:

- total UU
- total pasal
- total pasal aktif
- total pasal nonaktif
- total admin
- total user mobile
- total audit log terbaru

### Undang-Undang

```text
GET    /admin/undang-undang
POST   /admin/undang-undang
GET    /admin/undang-undang/{id}
PUT    /admin/undang-undang/{id}
DELETE /admin/undang-undang/{id}
PATCH  /admin/undang-undang/{id}/restore
```

Query list:

```text
?search=KUHP&is_active=1&page=1&per_page=20&sort=tahun&direction=desc
```

### Pasal

```text
GET    /admin/pasal
POST   /admin/pasal
GET    /admin/pasal/{id}
PUT    /admin/pasal/{id}
DELETE /admin/pasal/{id}
PATCH  /admin/pasal/{id}/restore
POST   /admin/pasal/bulk-import
```

Query list:

```text
?search=pencurian&undang_undang_id=uuid&is_active=1&page=1&per_page=20
```

### Relasi Pasal

```text
GET    /admin/pasal/{id}/links
POST   /admin/pasal/{id}/links
DELETE /admin/pasal-links/{id}
```

### Admin User

```text
GET    /admin/admin-users
POST   /admin/admin-users
GET    /admin/admin-users/{id}
PUT    /admin/admin-users/{id}
DELETE /admin/admin-users/{id}
PATCH  /admin/admin-users/{id}/activate
PATCH  /admin/admin-users/{id}/deactivate
```

Hanya `super_admin` yang boleh membuat dan menghapus admin.

### Mobile User

```text
GET    /admin/mobile-users
POST   /admin/mobile-users
POST   /admin/mobile-users/bulk-create
GET    /admin/mobile-users/{id}
PUT    /admin/mobile-users/{id}
DELETE /admin/mobile-users/{id}
PATCH  /admin/mobile-users/{id}/activate
PATCH  /admin/mobile-users/{id}/deactivate
PATCH  /admin/mobile-users/{id}/extend
GET    /admin/mobile-users/{id}/devices
DELETE /admin/mobile-users/{id}/devices/{deviceId}
```

Ini menggantikan Edge Functions:

- `create-user`
- `create-users-batch`
- `delete-user`
- sebagian `create-admin`

### Audit Log

```text
GET /admin/audit-logs
GET /admin/audit-logs/{id}
```

Query:

```text
?actor_type=admin&action=update&table_name=pasal&page=1&per_page=20
```

### Sync Mobile

Endpoint ini menggantikan Supabase RPC.

```text
GET /mobile/sync/check?since=2026-01-01T00:00:00Z
GET /mobile/sync/updates?since=2026-01-01T00:00:00Z
GET /mobile/sync/full
```

#### `GET /mobile/sync/check`

Mengganti `check_sync_updates`.

Response:

```json
{
  "has_updates": true,
  "server_time": "2026-05-04T10:00:00Z"
}
```

Aturan:

- cek `undang_undang.updated_at`
- cek `pasal.updated_at`
- cek `pasal_links.updated_at`
- termasuk data yang menjadi nonaktif/soft deleted setelah timestamp

#### `GET /mobile/sync/updates`

Mengganti `get_sync_updates`.

Response:

```json
{
  "server_time": "2026-05-04T10:00:00Z",
  "updated_uu": [],
  "updated_pasal": [],
  "updated_links": [],
  "deleted_uu_ids": [],
  "deleted_pasal_ids": [],
  "deleted_link_ids": []
}
```

Catatan:

- Jika ingin tetap kompatibel dengan Flutter saat ini, `updated_uu` dan `updated_pasal` bisa disamakan bentuknya dengan response RPC Supabase lama.
- Untuk record nonaktif, ada dua pendekatan:
  - kirim record dengan `is_active=false`
  - atau kirim daftar `deleted_*_ids`

#### `GET /mobile/sync/full`

Untuk sync pertama.

Response:

```json
{
  "server_time": "2026-05-04T10:00:00Z",
  "undang_undang": [],
  "pasal": [],
  "pasal_links": []
}
```

Catatan:

- Untuk data besar, endpoint full sync sebaiknya mendukung pagination/chunk:

```text
GET /mobile/sync/full/undang-undang
GET /mobile/sync/full/pasal?undang_undang_id=uuid&page=1&per_page=500
GET /mobile/sync/full/pasal-links?page=1&per_page=1000
```

## Perubahan React Admin

### File yang kemungkinan terdampak

- `admin-dashboard/src/lib/supabase.ts`
- `admin-dashboard/src/contexts/AuthContext.tsx`
- halaman CRUD pasal
- halaman CRUD undang-undang
- halaman manage admin
- halaman manage users
- halaman audit log
- halaman bulk import
- halaman reset password

### Strategi agar perubahan terkendali

Buat API client baru:

```text
admin-dashboard/src/lib/api.ts
```

Isi tanggung jawab:

- base URL dari `.env`
- attach token `Authorization: Bearer ...`
- handle 401
- wrapper `get`, `post`, `put`, `patch`, `delete`

Env baru:

```env
VITE_API_BASE_URL=https://pasal.kampus.ac.id/api
VITE_APP_NAME=CariPasal Admin
```

Setelah itu, ganti pemakaian Supabase per modul.

Urutan aman:

1. Auth admin.
2. Dashboard summary.
3. List undang-undang.
4. CRUD undang-undang.
5. List pasal.
6. CRUD pasal.
7. Pasal links.
8. Bulk import.
9. Manage mobile users.
10. Manage admin users.
11. Audit log.

## Perubahan Flutter Mobile

### File yang kemungkinan terdampak

- `pasal_mobile_app/lib/main.dart`
- `pasal_mobile_app/lib/core/config/env.dart`
- `pasal_mobile_app/lib/core/services/auth_service.dart`
- `pasal_mobile_app/lib/core/services/data_service.dart`
- `pasal_mobile_app/lib/core/services/sync_manager.dart`

### Dependency

Hapus nanti:

```yaml
supabase_flutter
```

Tambah:

```yaml
dio: ^5.0.0
```

atau pakai package `http`.

Env baru:

```dart
class Env {
  static const apiBaseUrl = 'https://pasal.kampus.ac.id/api';
}
```

Auth storage tetap bisa memakai:

- `flutter_secure_storage`
- `shared_preferences`

Local database tetap:

- Drift
- SQLite

## Migrasi Data

Sumber data:

- Supabase PostgreSQL export
- `supabase/full_setup.sql`
- `supabase/seed.sql`
- data production dari Supabase jika sudah ada

Mapping tabel:

| Supabase lama | Laravel + PostgreSQL baru | Catatan |
| --- | --- | --- |
| `public.undang_undang` | `undang_undang` | Pertahankan UUID |
| `public.pasal` | `pasal` | Pertahankan UUID, `keywords TEXT[]`, dan `search_vector` jika dipakai |
| `public.pasal_links` | `pasal_links` | Pertahankan UUID dan relasi |
| `public.admin_users` + `auth.users` | `admin_users` | Password perlu dibuat ulang/hash Laravel |
| `public.users` + `auth.users` | `mobile_users` | Password perlu dibuat ulang/hash Laravel |
| `public.user_devices` | `user_devices` | Rename foreign key dari `user_id` ke `mobile_user_id` |
| `public.admin_devices` | `admin_devices` | Rename foreign key dari `admin_id` ke `admin_user_id` |
| `public.audit_logs` | `audit_logs` | Bisa dipertahankan bentuk lama atau dinormalisasi ke format baru |

Langkah:

1. Freeze perubahan data sementara.
2. Export data dari Supabase/PostgreSQL ke CSV atau SQL.
3. Jalankan migration Laravel di PostgreSQL target.
4. Transform format jika perlu:
   - UUID tetap dipertahankan.
   - `public.users` Supabase dipindah ke `mobile_users`.
   - `user_devices.user_id` dipindah ke `user_devices.mobile_user_id`.
   - `admin_devices.admin_id` dipindah ke `admin_devices.admin_user_id`.
   - enum PostgreSQL lama bisa dipertahankan atau diganti `VARCHAR`.
   - password dari Supabase Auth tidak otomatis kompatibel dengan Laravel, jadi siapkan reset password atau password awal baru.
5. Import ke PostgreSQL.
6. Rebuild search vector jika dipakai.
7. Jalankan validasi jumlah record.
8. Jalankan smoke test admin.
9. Jalankan smoke test mobile sync.

Contoh rebuild search vector:

```sql
UPDATE pasal
SET search_vector =
  setweight(to_tsvector('simple', coalesce(nomor, '')), 'A') ||
  setweight(to_tsvector('simple', coalesce(judul, '')), 'B') ||
  setweight(to_tsvector('simple', coalesce(isi, '')), 'C') ||
  setweight(to_tsvector('simple', coalesce(penjelasan, '')), 'D');
```

Validasi minimal:

```text
jumlah undang_undang sama
jumlah pasal aktif sama
jumlah pasal nonaktif sama
jumlah pasal_links sama
jumlah admin_users sama
jumlah mobile_users sama
sample 10 pasal tampil sama di admin
sample sync mobile menghasilkan data yang sama
```

## Deployment aaPanel

Target satu subdomain:

```text
https://pasal.kampus.ac.id
```

Database PostgreSQL bisa disiapkan dengan salah satu cara:

- Plugin PostgreSQL/PgSQL aaPanel, jika tersedia dan stabil.
- Docker PostgreSQL di aaPanel, lalu Laravel konek ke host/port yang dipetakan.
- PostgreSQL terpisah di server internal kampus, jika kebijakan kampus memisahkan database dari web server.

Rekomendasi:

- Untuk setup awal, pakai PostgreSQL di server yang sama agar deployment sederhana.
- Untuk production kampus, pastikan backup database terjadwal dan restore pernah dites.
- Jangan expose port PostgreSQL ke publik. Cukup Laravel yang bisa mengakses database.

Struktur server contoh:

```text
/www/wwwroot/pasal.kampus.ac.id/
|-- public/              Laravel public folder
|-- app/
|-- bootstrap/
|-- config/
|-- database/
|-- routes/
|-- storage/
|-- vendor/
|-- admin/               hasil build React admin, opsional jika tidak digabung ke Laravel public
```

Ada dua pola deployment:

### Pola A: Laravel serve admin build

React admin di-build lalu file `dist` ditempatkan di:

```text
backend-laravel/public/admin
```

URL:

```text
https://pasal.kampus.ac.id/admin
https://pasal.kampus.ac.id/api
```

Kelebihan:

- Satu website aaPanel.
- Konfigurasi sederhana.

Kekurangan:

- Perlu routing fallback untuk React.

### Pola B: Nginx route root ke React, `/api` ke Laravel

URL:

```text
https://pasal.kampus.ac.id
https://pasal.kampus.ac.id/api
```

Kelebihan:

- Admin dashboard terasa seperti aplikasi utama.

Kekurangan:

- Konfigurasi Nginx sedikit lebih khusus.

Rekomendasi untuk kampus:

```text
Pola A lebih aman: /admin untuk dashboard, /api untuk backend.
```

## Konfigurasi Laravel `.env`

Contoh:

```env
APP_NAME=CariPasal
APP_ENV=production
APP_KEY=base64:...
APP_DEBUG=false
APP_URL=https://pasal.kampus.ac.id

DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=caripasal
DB_USERNAME=caripasal_user
DB_PASSWORD=strong-password

SANCTUM_STATEFUL_DOMAINS=pasal.kampus.ac.id
SESSION_DOMAIN=pasal.kampus.ac.id

FILESYSTEM_DISK=local
QUEUE_CONNECTION=database
CACHE_STORE=file
LOG_CHANNEL=stack
```

Jika PostgreSQL berjalan di Docker, `DB_HOST` bisa berupa IP/hostname container network atau `127.0.0.1` sesuai mapping port aaPanel.

## Keamanan

Wajib:

- HTTPS aktif.
- `APP_DEBUG=false`.
- Password di-hash.
- Token API pakai Sanctum.
- Rate limit login.
- CORS hanya untuk domain admin/mobile yang diperlukan.
- Role middleware untuk semua endpoint admin.
- Mobile endpoint wajib cek token, status user, expired date, dan device.
- Backup database terjadwal di aaPanel.

Disarankan:

- Audit semua create/update/delete.
- Batasi upload XLSX.
- Validasi ukuran file bulk import.
- Simpan log error Laravel.
- Buat endpoint health check:

```text
GET /api/health
```

## Tahapan Implementasi

### Fase 0: Persiapan

Output:

- Buat branch migrasi.
- Buat folder `backend-laravel`.
- Tentukan domain final.
- Tentukan PostgreSQL version di aaPanel.

Checklist:

- [ ] Backup repository.
- [ ] Backup data Supabase.
- [ ] Catat semua env Supabase lama.
- [ ] Catat fitur admin dan mobile yang wajib tetap jalan.

### Fase 1: Backend Laravel Dasar

Output:

- Laravel project jalan lokal.
- Koneksi PostgreSQL jalan.
- Sanctum aktif.
- Endpoint health check aktif.

Checklist:

- [ ] Install Laravel.
- [ ] Setup `.env`.
- [ ] Install Sanctum.
- [ ] Buat migration awal.
- [ ] Buat model.
- [ ] Buat seeder super admin.

### Fase 2: Auth

Output:

- Admin bisa login/logout.
- Mobile user bisa login/logout.
- Token tersimpan dan tervalidasi.

Checklist:

- [ ] `POST /api/admin/login`
- [ ] `GET /api/admin/me`
- [ ] `POST /api/admin/logout`
- [ ] `POST /api/mobile/login`
- [ ] `GET /api/mobile/me`
- [ ] `POST /api/mobile/logout`
- [ ] Middleware role.
- [ ] Middleware active/expired user.

### Fase 3: CRUD Data Inti

Output:

- Admin bisa kelola UU dan pasal lewat API.

Checklist:

- [ ] CRUD `undang_undang`.
- [ ] CRUD `pasal`.
- [ ] CRUD `pasal_links`.
- [ ] Soft delete.
- [ ] Restore.
- [ ] Filter/search/pagination.
- [ ] Audit log create/update/delete.

### Fase 4: Admin Dashboard Integrasi

Output:

- React admin tidak lagi bergantung pada Supabase untuk modul inti.

Checklist:

- [ ] Buat `api.ts`.
- [ ] Ganti AuthContext.
- [ ] Ganti DashboardPage.
- [ ] Ganti UndangUndang pages.
- [ ] Ganti Pasal pages.
- [ ] Ganti PasalLinksSidebar.
- [ ] Ganti BulkImportPage.
- [ ] Ganti AuditLogPage.
- [ ] Ganti ManageUsersPage.
- [ ] Ganti ManageAdminPage.

### Fase 5: Mobile User Management

Output:

- Admin bisa membuat, import, menonaktifkan, dan menghapus user mobile.

Checklist:

- [ ] Create mobile user.
- [ ] Batch create mobile users dari XLSX.
- [ ] Deactivate/activate.
- [ ] Extend expiry.
- [ ] Delete/soft delete.
- [ ] Manage devices.

### Fase 6: Sync Mobile

Output:

- Mobile bisa full sync dan incremental sync tanpa Supabase.

Checklist:

- [ ] `GET /api/mobile/sync/check`
- [ ] `GET /api/mobile/sync/updates`
- [ ] `GET /api/mobile/sync/full`
- [ ] Response kompatibel dengan model Flutter.
- [ ] Test sync pertama.
- [ ] Test update pasal.
- [ ] Test pasal dinonaktifkan.
- [ ] Test relasi pasal.

### Fase 7: Flutter Integrasi

Output:

- Flutter tidak lagi memakai `supabase_flutter`.

Checklist:

- [ ] Ganti `Env.supabaseUrl` ke `Env.apiBaseUrl`.
- [ ] Hapus init Supabase di `main.dart`.
- [ ] Ganti `AuthService`.
- [ ] Ganti `DataService`.
- [ ] Ganti `SyncManager` jika perlu.
- [ ] Pastikan Drift tetap jalan.
- [ ] Test login.
- [ ] Test offline mode.
- [ ] Test full sync.
- [ ] Test incremental sync.

### Fase 8: Deployment aaPanel

Output:

- Aplikasi jalan di satu subdomain.

Checklist:

- [ ] Buat database PostgreSQL.
- [ ] Upload Laravel.
- [ ] Jalankan `composer install --no-dev`.
- [ ] Set `.env`.
- [ ] Jalankan `php artisan key:generate`.
- [ ] Jalankan `php artisan migrate --seed`.
- [ ] Jalankan `php artisan storage:link` jika perlu.
- [ ] Set document root ke `backend-laravel/public`.
- [ ] Build React admin.
- [ ] Upload React build ke `public/admin`.
- [ ] Set HTTPS.
- [ ] Set cron Laravel scheduler jika dipakai.
- [ ] Test `/api/health`.
- [ ] Test `/admin`.

### Fase 9: Cutover

Output:

- Production berpindah dari Supabase ke Laravel.

Checklist:

- [ ] Freeze perubahan data di Supabase.
- [ ] Export data terakhir.
- [ ] Import ke PostgreSQL.
- [ ] Validasi record.
- [ ] Update env admin ke API Laravel.
- [ ] Build admin production.
- [ ] Build APK mobile dengan API Laravel.
- [ ] Smoke test.
- [ ] Backup final.
- [ ] Supabase dinonaktifkan setelah semua valid.

## Estimasi Risiko

Risiko tinggi:

- Auth dan token karena berubah total.
- Sync mobile karena sekarang bergantung pada RPC Supabase.
- Bulk import jika ada banyak validasi tersembunyi.
- Audit log karena sebelumnya sebagian dibantu trigger/function.

Risiko sedang:

- CRUD admin.
- Search/filter/pagination.
- Password reset.

Risiko rendah:

- UI admin.
- UI mobile.
- Local database Drift.
- Tampilan detail pasal.

## Urutan Prioritas yang Disarankan

1. Backend Laravel + schema.
2. Auth admin.
3. CRUD UU dan pasal.
4. Admin dashboard tersambung ke Laravel.
5. Auth mobile.
6. Full sync mobile.
7. Incremental sync mobile.
8. User/device management.
9. Audit log dan hardening.
10. Deployment aaPanel.

## Keputusan Teknis yang Perlu Ditetapkan

Sebelum coding penuh, tentukan:

- Apakah user admin dan mobile mau dipisah tabel atau satu tabel?
- Apakah delete data benar-benar soft delete semua?
- Apakah mobile user boleh login di lebih dari satu device?
- Apakah password reset wajib via email SMTP kampus?
- Apakah admin dashboard akan di `/admin` atau root `/`?
- Apakah full sync dikirim sekaligus atau per halaman/chunk?
- Apakah data lama Supabase sudah production atau masih dummy?

Rekomendasi default:

- Pisah tabel `admin_users` dan `mobile_users`.
- Pakai soft delete.
- Batasi satu user mobile ke satu device, kecuali kampus minta multi-device.
- Admin di `/admin`, API di `/api`.
- Full sync dibuat per chunk untuk lebih aman.
- Pertahankan UUID lama agar data mobile dan relasi tidak rusak.
