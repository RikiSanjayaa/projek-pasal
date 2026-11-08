# Database Schema - CariPasal

Dokumen ini merangkum schema database backend Laravel yang aktif saat ini.

## Tabel Inti

### `admin_users`

Menyimpan akun admin dashboard.

Kolom penting:

- `id` UUID primary key
- `email` unik
- `password` hashed
- `nama`
- `role` enum `admin | super_admin`
- `is_active`
- `last_login_at`
- `created_at`, `updated_at`, `deleted_at`

### `undang_undang`

Master data undang-undang.

Kolom penting:

- `id` UUID primary key
- `kode` unik, misalnya `KUHP`, `KUHAP`, `UU_ITE`
- `nama`
- `nama_lengkap`
- `deskripsi`
- `tahun`
- `is_active`
- `created_at`, `updated_at`, `deleted_at`

### `pasal`

Data pasal per undang-undang.

Kolom penting:

- `id` UUID primary key
- `undang_undang_id` FK ke `undang_undang`
- `nomor`
- `judul`
- `isi`
- `penjelasan`
- `keywords` tipe `TEXT[]`
- `search_vector` tipe `TSVECTOR`
- `is_active`
- `created_by`, `updated_by` FK ke `admin_users`
- `created_at`, `updated_at`, `deleted_at`

Constraint:

- `UNIQUE(undang_undang_id, nomor)`

### `pasal_links`

Relasi antar pasal.

Kolom penting:

- `id` UUID primary key
- `source_pasal_id` FK ke `pasal`
- `target_pasal_id` FK ke `pasal`
- `keterangan`
- `is_active`
- `created_by` FK ke `admin_users`
- `created_at`, `updated_at`, `deleted_at`

Constraint:

- `UNIQUE(source_pasal_id, target_pasal_id)`
- tidak boleh self-link

### `mobile_users`

Akun pengguna aplikasi mobile.

Kolom penting:

- `id` UUID primary key
- `email` unik
- `password` hashed
- `nama`
- `is_active`
- `expires_at`
- `last_login_at`
- `created_by_admin_id` FK ke `admin_users`
- `created_at`, `updated_at`, `deleted_at`

### `user_devices`

Pencatatan perangkat user mobile.

Kolom penting:

- `id` UUID primary key
- `mobile_user_id` FK ke `mobile_users`
- `device_id`
- `device_name`
- `platform`
- `is_active`
- `last_active_at`
- `created_at`, `updated_at`

Constraint:

- `UNIQUE(mobile_user_id, device_id)`

### `admin_devices`

Pencatatan perangkat admin.

Kolom penting:

- `id` UUID primary key
- `admin_user_id` FK ke `admin_users`
- `device_id`
- `device_alias`
- `device_name`
- `user_agent`
- `ip_address`
- `is_active`
- `last_active_at`
- `created_at`, `updated_at`

### `audit_logs`

Log aktivitas admin.

Kolom penting:

- `id` UUID primary key
- `admin_id`
- `admin_email`
- `actor_type`, `actor_id`
- `action` enum audit
- `table_name`
- `record_id`
- `old_data` JSONB
- `new_data` JSONB
- `metadata` JSONB
- `ip_address`
- `user_agent`
- `created_at`

### `password_reset_tokens`

Token reset password untuk admin dan mobile.

Kolom penting:

- `id`
- `email`
- `user_type`
- `token` hashed
- `created_at`
- `expires_at`
- `used_at`

### `personal_access_tokens`

Tabel bawaan Laravel Sanctum untuk token API.

## Relasi Ringkas

```text
admin_users 1 --- N pasal
admin_users 1 --- N pasal_links
admin_users 1 --- N mobile_users
admin_users 1 --- N admin_devices
undang_undang 1 --- N pasal
pasal 1 --- N pasal_links (source)
pasal 1 --- N pasal_links (target)
mobile_users 1 --- N user_devices
```

## Index Penting

- index `kode` dan `is_active` pada `undang_undang`
- index `undang_undang_id`, `nomor`, `is_active`, `deleted_at` pada `pasal`
- GIN index `search_vector` dan `keywords` pada `pasal`
- index perangkat pada `user_devices` dan `admin_devices`
- index audit pada `audit_logs`

## Sumber Kebenaran

Schema aktual didefinisikan di:

- `backend-laravel/database/migrations/2026_05_04_030000_create_caripasal_schema.php`
- `backend-laravel/database/migrations/2026_05_04_080000_create_password_reset_tokens_table.php`

Jika ada perbedaan antara dokumen ini dan migration, migration adalah sumber kebenaran utama.
