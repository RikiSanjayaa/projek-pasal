# Database Schema - CariPasal

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  ┌──────────────────┐           ┌──────────────────┐                        │
│  │  undang_undang   │           │   admin_users    │                        │
│  ├──────────────────┤           ├──────────────────┤                        │
│  │ id (PK)          │           │ id (PK, FK→auth) │                        │
│  │ kode             │           │ email            │                        │
│  │ nama             │           │ nama             │                        │
│  │ nama_lengkap     │           │ role             │                        │
│  │ deskripsi        │           │ is_active        │                        │
│  │ tahun            │           │ created_at       │                        │
│  │ is_active        │           │ updated_at       │                        │
│  │ created_at       │           └────────┬─────────┘                        │
│  │ updated_at       │                    │                                  │
│  └────────┬─────────┘                    │ created_by, updated_by           │
│           │                              │                                  │
│           │                              │                                  │
│           │ 1:N                          │                                  │
│           │                              ▼                                  │
│           │           ┌──────────────────────────────────┐                  │
│           │           │              pasal               │                  │
│           │           ├──────────────────────────────────┤                  │
│           └──────────►│ id (PK)                          │                  │
│                       │ undang_undang_id (FK)            │                  │
│                       │ nomor                            │                  │
│                       │ judul                            │                  │
│                       │ isi                              │                  │
│                       │ penjelasan                       │                  │
│                       │ keywords (TEXT[])                │                  │
│                       │ search_vector (TSVECTOR)         │                  │
│                       │ is_active                        │                  │
│                       │ created_at                       │                  │
│                       │ deleted_at                       │                  │
│                       │ updated_at                       │                  │
│                       │ created_by (FK→admin_users)      │                  │
│                       │ updated_by (FK→admin_users)      │                  │
│                       └───────────────────────────┬──────┘                  │
│                                                   │                         │
│                                                   │                         │
│                                                   │                         │
│                                                   │                         │
│            ┌─────────────────────────┐            │                         │
│            │      pasal_links        │            │                         │
│            ├─────────────────────────┤            │                         │
│            │ id (PK)                 │            │                         │
│            │ source_pasal_id (FK)    │            │                         │
│            │ target_pasal_id (FK)    │◄───────────┘                         │
│            │ keterangan              │                                      │
│            │ is_active               │                                      │
│            │ created_at              │                                      │
│            │ deleted_at              │                                      │
│            │ created_by (FK)         │                                      │
│            └─────────────────────────┘                                      │
│                                                                             │
│                                                                             │
│  ┌──────────────────────────┐                                               │
│  │       audit_logs         │                                               │
│  ├──────────────────────────┤                                               │
│  │ id (PK)                  │                                               │
│  │ admin_id (FK)            │                                               │
│  │ admin_email              │                                               │
│  │ action (ENUM)            │                                               │
│  │ table_name               │                                               │
│  │ record_id                │                                               │
│  │ old_data (JSONB)         │                                               │
│  │ new_data (JSONB)         │                                               │
│  │ created_at               │                                               │
│  └──────────────────────────┘                                               │
│                                                                             │
│                                                                             │
│  ┌──────────────────────────┐         ┌──────────────────────────┐          │
│  │         users            │         │      user_devices        │          │
│  ├──────────────────────────┤         ├──────────────────────────┤          │
│  │ id (PK, FK→auth)         │────────►│ id (PK)                  │          │
│  │ email                    │         │ user_id (FK→users)       │          │
│  │ nama                     │         │ device_id                │          │
│  │ is_active                │         │ device_name              │          │
│  │ expires_at               │         │ is_active                │          │
│  │ created_by (FK→admin)    │         │ last_active_at           │          │
│  │ created_at               │         │ created_at               │          │
│  │ updated_at               │         └──────────────────────────┘          │
│  └──────────────────────────┘                                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Tabel Detail

### 1. undang_undang

Menyimpan daftar undang-undang (KUHP, KUHPer, KUHAP, UU ITE).

| Column       | Type         | Nullable | Default           | Description                            |
| ------------ | ------------ | -------- | ----------------- | -------------------------------------- |
| id           | UUID         | NO       | gen_random_uuid() | Primary key                            |
| kode         | VARCHAR(20)  | NO       | -                 | Kode unik: KUHP, KUHPER, KUHAP, UU_ITE |
| nama         | VARCHAR(255) | NO       | -                 | Nama singkat                           |
| nama_lengkap | TEXT         | YES      | NULL              | Nama lengkap resmi                     |
| deskripsi    | TEXT         | YES      | NULL              | Deskripsi singkat                      |
| tahun        | INTEGER      | YES      | NULL              | Tahun berlaku                          |
| is_active    | BOOLEAN      | NO       | true              | Status aktif                           |
| created_at   | TIMESTAMPTZ  | NO       | NOW()             | Waktu dibuat                           |
| updated_at   | TIMESTAMPTZ  | NO       | NOW()             | Waktu diupdate                         |

**Indexes:**

- `idx_undang_undang_kode` - Pencarian by kode
- `idx_undang_undang_active` - Filter aktif

---

### 2. pasal

Menyimpan data pasal dari setiap undang-undang.

| Column           | Type         | Nullable | Default           | Description                       |
| ---------------- | ------------ | -------- | ----------------- | --------------------------------- |
| id               | UUID         | NO       | gen_random_uuid() | Primary key                       |
| undang_undang_id | UUID         | NO       | -                 | FK ke undang_undang               |
| nomor            | VARCHAR(50)  | NO       | -                 | Nomor pasal: "340", "27 ayat (3)" |
| judul            | VARCHAR(500) | YES      | NULL              | Judul pasal (opsional)            |
| isi              | TEXT         | NO       | -                 | Isi lengkap pasal                 |
| penjelasan       | TEXT         | YES      | NULL              | Penjelasan/tafsir                 |
| keywords         | TEXT[]       | NO       | '{}'              | Array kata kunci                  |
| search_vector    | TSVECTOR     | YES      | -                 | Full-text search index            |
| is_active        | BOOLEAN      | NO       | true              | Status aktif (soft delete)        |
| deleted_at       | TIMESTAMPTZ  | YES      | NULL              | Waktu soft delete                 |
| created_at       | TIMESTAMPTZ  | NO       | NOW()             | Waktu dibuat                      |
| updated_at       | TIMESTAMPTZ  | NO       | NOW()             | Waktu diupdate                    |
| created_by       | UUID         | YES      | NULL              | FK ke admin_users                 |
| updated_by       | UUID         | YES      | NULL              | FK ke admin_users                 |

**Indexes:**

- `idx_pasal_undang_undang` - Filter by UU
- `idx_pasal_nomor` - Pencarian by nomor
- `idx_pasal_search` - GIN index untuk full-text search
- `idx_pasal_keywords` - GIN index untuk keyword filter
- `idx_pasal_active` - Filter aktif
- `idx_pasal_deleted_at` - Filter soft delete

**Constraints:**

- `unique_pasal_per_uu` - UNIQUE(undang_undang_id, nomor)

---

### 3. pasal_links

Menyimpan relasi/link antar pasal.

| Column          | Type         | Nullable | Default           | Description                              |
| --------------- | ------------ | -------- | ----------------- | ---------------------------------------- |
| id              | UUID         | NO       | gen_random_uuid() | Primary key                              |
| source_pasal_id | UUID         | NO       | -                 | FK ke pasal (dari)                       |
| target_pasal_id | UUID         | NO       | -                 | FK ke pasal (ke)                         |
| keterangan      | VARCHAR(255) | YES      | NULL              | Keterangan link                          |
| is_active       | BOOLEAN      | NO       | true              | Soft delete flag (cascade dengan pasal)  |
| deleted_at      | TIMESTAMPTZ  | YES      | NULL              | Waktu soft delete (cascade dengan pasal) |
| created_at      | TIMESTAMPTZ  | NO       | NOW()             | Waktu dibuat                             |
| created_by      | UUID         | YES      | NULL              | FK ke admin_users                        |

**Constraints:**

- `unique_pasal_link` - UNIQUE(source_pasal_id, target_pasal_id)
- `no_self_link` - CHECK(source_pasal_id != target_pasal_id)

---

### 4. admin_users

Menyimpan data admin (staf/dosen).

| Column     | Type         | Nullable | Default | Description                      |
| ---------- | ------------ | -------- | ------- | -------------------------------- |
| id         | UUID         | NO       | -       | PK, FK ke auth.users             |
| email      | VARCHAR(255) | NO       | -       | Email admin                      |
| nama       | VARCHAR(255) | NO       | -       | Nama lengkap                     |
| role       | admin_role   | NO       | 'admin' | Role: 'admin' atau 'super_admin' |
| is_active  | BOOLEAN      | NO       | true    | Status aktif                     |
| created_at | TIMESTAMPTZ  | NO       | NOW()   | Waktu dibuat                     |
| updated_at | TIMESTAMPTZ  | NO       | NOW()   | Waktu diupdate                   |

---

### 5. audit_logs

Menyimpan log semua perubahan data.

| Column      | Type         | Nullable | Default           | Description                  |
| ----------- | ------------ | -------- | ----------------- | ---------------------------- |
| id          | UUID         | NO       | gen_random_uuid() | Primary key                  |
| admin_id    | UUID         | YES      | -                 | FK ke admin_users            |
| admin_email | VARCHAR(255) | YES      | -                 | Email admin (denormalized)   |
| action      | audit_action | NO       | -                 | 'CREATE', 'UPDATE', 'DELETE' |
| table_name  | VARCHAR(100) | NO       | -                 | Nama tabel yang diubah       |
| record_id   | UUID         | NO       | -                 | ID record yang diubah        |
| old_data    | JSONB        | YES      | NULL              | Data sebelum perubahan       |
| new_data    | JSONB        | YES      | NULL              | Data setelah perubahan       |
| created_at  | TIMESTAMPTZ  | NO       | NOW()             | Waktu perubahan              |

---

### 6. users

Menyimpan data pengguna aplikasi mobile (bukan admin).

| Column     | Type         | Nullable | Default | Description                                   |
| ---------- | ------------ | -------- | ------- | --------------------------------------------- |
| id         | UUID         | NO       | -       | PK, FK ke auth.users                          |
| email      | VARCHAR(255) | NO       | -       | Email pengguna                                |
| nama       | VARCHAR(255) | NO       | -       | Nama lengkap                                  |
| is_active  | BOOLEAN      | NO       | true    | Status aktif                                  |
| expires_at | TIMESTAMPTZ  | NO       | -       | Waktu kadaluarsa akses (biasanya 3 tahun)     |
| created_by | UUID         | YES      | NULL    | FK ke admin_users (admin yang membuat)        |
| created_at | TIMESTAMPTZ  | NO       | NOW()   | Waktu dibuat                                  |
| updated_at | TIMESTAMPTZ  | NO       | NOW()   | Waktu diupdate                                |

**Indexes:**

- `idx_users_email` - Pencarian by email
- `idx_users_is_active` - Filter aktif
- `idx_users_expires_at` - Filter kadaluarsa

---

### 7. user_devices

Menyimpan binding perangkat untuk kebijakan satu perangkat per pengguna.

| Column         | Type         | Nullable | Default           | Description                          |
| -------------- | ------------ | -------- | ----------------- | ------------------------------------ |
| id             | UUID         | NO       | gen_random_uuid() | Primary key                          |
| user_id        | UUID         | NO       | -                 | FK ke users                          |
| device_id      | VARCHAR(255) | NO       | -                 | UUID perangkat (generated di app)    |
| device_name    | VARCHAR(255) | YES      | NULL              | Nama perangkat: "Samsung Galaxy S21" |
| is_active      | BOOLEAN      | NO       | true              | Status login aktif                   |
| last_active_at | TIMESTAMPTZ  | NO       | NOW()             | Waktu terakhir aktif                 |
| created_at     | TIMESTAMPTZ  | NO       | NOW()             | Waktu pertama login                  |

**Indexes:**

- `idx_user_devices_user_id` - Filter by user
- `idx_user_devices_device_id` - Pencarian by device
- `idx_user_devices_is_active` - Filter aktif

**Constraints:**

- `unique_user_device` - UNIQUE(user_id, device_id)

---

## ENUM Types

### admin_role

```sql
CREATE TYPE admin_role AS ENUM ('admin', 'super_admin');
```

### audit_action

```sql
CREATE TYPE audit_action AS ENUM ('CREATE', 'UPDATE', 'DELETE');
```

---

## Functions

### 1. search_pasal

Pencarian pasal dengan full-text search dan pagination.

```sql
SELECT * FROM search_pasal(
    'pembunuhan berencana',  -- search_query
    'KUHP',                   -- uu_kode (NULL = semua)
    1,                        -- page_number
    20                        -- page_size
);
```

### 2. search_pasal_by_keywords

Pencarian berdasarkan array keywords (exact match).

```sql
SELECT * FROM search_pasal_by_keywords(
    ARRAY['pembunuhan', 'berencana'],  -- keyword_list
    NULL,                               -- uu_kode
    1,                                  -- page_number
    20                                  -- page_size
);
```

### 3. cascade_soft_delete_pasal_links

Otomatis soft delete/restore pasal_links saat pasal di-soft delete/restore.

```sql
-- Trigger otomatis, tidak perlu dipanggil manual
```

### 4. cleanup_soft_deleted_data

Hapus permanen data yang sudah soft delete lebih dari N hari.

```sql
-- Hapus data yang sudah soft delete > 30 hari
SELECT * FROM cleanup_soft_deleted_data(30);
```

### 5. cascade_uu_is_active_to_pasal

Otomatis cascade is_active dari undang_undang ke semua pasal terkait.
Pasal yang sudah soft delete (deleted_at IS NOT NULL) tidak akan ikut diaktifkan kembali.

```sql
-- Trigger otomatis saat undang_undang diupdate
-- Tidak perlu dipanggil manual
```

### 6. check_sync_updates

Cek apakah ada update data UU atau Pasal sejak timestamp tertentu.
Menggunakan SECURITY DEFINER untuk bypass RLS (keperluan sync mobile).

```sql
SELECT check_sync_updates('2026-01-01T00:00:00Z'::TIMESTAMPTZ);
-- Returns: TRUE jika ada update, FALSE jika tidak
```

### 7. get_sync_updates

Ambil semua data yang diupdate sejak timestamp tertentu untuk sinkronisasi.
Menggunakan SECURITY DEFINER untuk bypass RLS.

```sql
SELECT * FROM get_sync_updates('2026-01-01T00:00:00Z'::TIMESTAMPTZ);
-- Returns: updated_uu (JSONB), updated_pasal (JSONB)
```

### 8. is_valid_user

Cek apakah authenticated user adalah pengguna mobile yang valid (aktif dan belum kadaluarsa).

```sql
SELECT is_valid_user();
-- Returns: TRUE jika valid, FALSE jika tidak
```

---

## Triggers

| Trigger                             | Table         | Event                      | Function                          |
| ----------------------------------- | ------------- | -------------------------- | --------------------------------- |
| tr\_\*\_updated_at                  | All           | BEFORE UPDATE              | update_updated_at()               |
| tr_pasal_search_vector              | pasal         | BEFORE INSERT/UPDATE       | update_pasal_search_vector()      |
| tr_pasal_cascade_soft_delete        | pasal         | AFTER UPDATE               | cascade_soft_delete_pasal_links() |
| tr_pasal_audit                      | pasal         | AFTER INSERT/UPDATE/DELETE | log_audit()                       |
| tr_undang_undang_audit              | undang_undang | AFTER INSERT/UPDATE/DELETE | log_audit()                       |
| tr_pasal_links_audit                | pasal_links   | AFTER INSERT/UPDATE/DELETE | log_audit()                       |
| tr_undang_undang_cascade_is_active  | undang_undang | AFTER UPDATE               | cascade_uu_is_active_to_pasal()   |
| users_updated_at_trigger            | users         | BEFORE UPDATE              | update_users_updated_at()         |
| tr_users_audit                      | users         | AFTER INSERT/UPDATE/DELETE | log_audit()                       |

**Catatan:**
- `log_audit()` function akan skip logging jika dalam mode cascade (ditandai dengan setting `app.is_cascade_update`)
- Ini mencegah log bloat saat cascade update dari undang_undang ke pasal
