# Arsitektur Sistem CariPasal

## Gambaran Umum

CariPasal adalah aplikasi pencarian pasal hukum Indonesia yang terdiri dari:

1. **Mobile App** (Flutter) - Untuk user biasa mencari pasal
2. **Admin Dashboard** (React + Mantine) - Untuk admin mengelola data
3. **Backend** (Supabase) - Database, Auth, dan API

## Diagram Arsitektur

```
┌─────────────────────────────────────────────────────────────────┐
│                           USERS                                 │
├───────────────────────────────┬─────────────────────────────────┤
│                               │                                 │
│  User Biasa (Mobile)          │  Admin (Web Dashboard)          │
│  ────────────────────────     │  ─────────────────────────      │
│  • Login dengan email/password│  • Login dengan email/password  │
│  • Search pasal               │  • CRUD pasal                   │
│  • Filter by UU               │  • Bulk import XLSX             │
│  • Download offline           │  • View audit log               │
│  • Bookmark lokal             │  • Manage undang-undang         │
│  • Akses 3 tahun + 1 device   │  • Manage pengguna mobile       │
│                               │                                 │
│  Flutter + Drift              │  React + Mantine + Vite         │
│                               │                                 │
└───────────────────────────────┴─────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      SUPABASE BACKEND                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Supabase Auth                                                  │
│  ─────────────────                                              │
│  • Email/Password authentication                                │
│  • Session management                                           │
│  • JWT tokens                                                   │
│                                                                 │
│  REST API (Auto-generated)                                      │
│  ─────────────────────────────                                  │
│  • CRUD endpoints untuk semua tabel                             │
│                                                                 │
│  Row Level Security (RLS)                                       │
│  ───────────────────────────                                    │
│  • User: Read pasal & undang-undang yang aktif (auth required)  │
│  • Admin: CRUD semua data                                       │
│  • Super Admin: Manage admin users & mobile users               │
│                                                                 │
│  PostgreSQL Database                                            │
│  ─────────────────────────                                      │
│  • Full-text search dengan tsvector                             │
│  • JSONB untuk audit log                                        │
│  • Array untuk keywords                                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Flow Diagram

### 1. User Login Flow (Mobile)

```
User Input → Login Screen → Supabase Auth → Verify User Table
                                                │
                    ┌───────────────────────────┴───────────────────────────┐
                    │                                                       │
                    ▼                                                       ▼
            [User Valid & Active]                               [Invalid/Inactive/Expired]
                    │                                                       │
                    ▼                                                       ▼
           Check Device Binding                                     Show Error Message
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
   [Same Device]          [Different Device]
        │                       │
        ▼                       ▼
   Login Success          Device Conflict Error
        │
        ▼
   Store expiry locally
```

### 2. User Search Flow

```
User Input → Mobile App → Supabase REST API → PostgreSQL FTS → Response
                              │
                              ▼
                    (Cached locally with Drift)
```

### 3. Admin CRUD Flow

```
Admin Login → Auth Check → Dashboard → API Call → RLS Check → Database
                              │                        │
                              │                        ▼
                              │              Trigger → Audit Log
                              ▼
                         UI Update ← Query Invalidation
```

### 4. Offline Sync Flow

```
                    ┌─────────────────────────┐
                    │     Mobile App          │
                    └─────────────────────────┘
                              │
                              ▼
                    ┌─────────────────────────┐
                    │  Check Local Data       │
                    └─────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
              ▼                               ▼
     [No Local Data]                 [Has Local Data]
              │                               │
              ▼                               ▼
     Download All UU             Compare updated_at with Server
              │                               │
              │               ┌───────────────┴───────────────┐
              │               │                               │
              │               ▼                               ▼
              │        [Same Data]                  [Different Data]
              │               │                               │
              │               ▼                               ▼
              │        Use Local Data               Show Update Badge
              │                                               │
              │                                               ▼
              │                                     User Clicks Update
              │                                               │
              └───────────────┴───────────────────────────────┘
                              │
                              ▼
                    Save to Local SQLite (Drift)
```

## Technology Stack

| Layer           | Technology                 | Justification                                         |
| --------------- | -------------------------- | ----------------------------------------------------- |
| Mobile Frontend | Flutter                    | Cross-platform (Android & iOS), sudah dipilih         |
| Mobile State    | setState + ValueListenable | Simple, built-in, cukup untuk local-first app         |
| Mobile Local DB | Drift (SQLite)             | Type-safe, migration support                          |
| Mobile HTTP     | supabase_flutter           | Built-in HTTP client, langsung integrate dengan supabase |
| Mobile Auth     | flutter_secure_storage     | Penyimpanan kredensial aman per-device                |
| Mobile Device   | device_info_plus           | Info perangkat untuk one-device policy                |
| Admin Frontend  | React + TypeScript         | Ecosystem besar, Mantine compatible                   |
| Admin UI        | Mantine v7                 | Modern, lengkap, well-documented                      |
| Admin State     | TanStack Query             | Caching, invalidation, optimistic updates             |
| Admin Import    | xlsx                       | Parsing file Excel untuk bulk import                  |
| Backend         | Supabase                   | BaaS, free tier generous, PostgreSQL                  |
| Database        | PostgreSQL                 | Full-text search, JSONB, RLS                          |
| Auth            | Supabase Auth              | Built-in, role-based, secure                          |

## Security Considerations

### Authentication

- Admin menggunakan Supabase Auth dengan email/password
- User mobile menggunakan Supabase Auth dengan email/password (akun dibuat oleh admin)
- Session dikelola otomatis oleh Supabase
- Token refresh otomatis

### User Access Control (Mobile)

- Akun pengguna mobile dibuat oleh admin dengan masa aktif 3 tahun
- Kebijakan satu perangkat per akun (device binding)
- Expiry check saat login dan sebelum sync
- Admin dapat memperpanjang masa aktif atau menonaktifkan pengguna

### Authorization (Row Level Security)

```sql
-- Contoh RLS Policy (versi terbaru - auth required)
CREATE POLICY "User: read active pasal"
    ON pasal FOR SELECT
    TO authenticated
    USING (is_active = true AND (is_admin() OR is_valid_user()));

CREATE POLICY "Admin: write pasal"
    ON pasal FOR ALL
    TO authenticated
    USING (is_admin());
```

### Data Protection

- Audit log untuk setiap perubahan (termasuk pasal_links dan users)
- Soft delete dengan `is_active` dan `deleted_at` untuk restore capability
- Cascade soft delete untuk pasal_links (otomatis mengikuti pasal)
- Cascade is_active dari undang_undang ke semua pasal terkait
- Auto cleanup untuk data pasal yang sudah soft delete > 30 hari
- Trash management page untuk restore/permanent delete data pasal
- Audit log skip saat cascade untuk mencegah log bloat

## Scalability Notes

### Current Design (1000 users)

- Supabase free tier cukup
- Single region deployment
- Client-side caching via local SQLite (mobile user)

### Future Scaling

- Upgrade ke Supabase Pro / self host supabase jika traffic tinggi

## Folder Structure

```
projek-pasal/
├── supabase/
│   ├── functions/           # Edge functions supabase
│   │   ├── create-admin/    # Buat admin baru
│   │   ├── create-user/     # Buat user mobile baru
│   │   ├── create-users-batch/  # Batch import users
│   │   └── delete-user/     # Hapus user mobile
│   ├── migrations/          # Database migrations (001-014)
│   └── seed.sql             # Dummy data
├── admin-dashboard/
│   └── src/
│       ├── components/      # Reusable UI components
│       ├── contexts/        # React contexts (Auth, DataMapping)
│       ├── layouts/         # Layout components
│       ├── lib/             # Supabase client, types
│       └── pages/           # Page components
│           ├── pasal/       # CRUD pasal, trash
│           └── undang-undang/ # List UU
├── pasal_mobile_app/        # Flutter app
│   └── lib/
│       ├── core/
│       │   ├── config/      # Theme, env, colors
│       │   ├── database/    # Drift database
│       │   ├── services/    # Auth, data, sync, archive
│       │   └── utils/       # Search utilities
│       ├── models/          # Data models
│       └── ui/
│           ├── screens/     # Login, home, library, dll
│           ├── widgets/     # Reusable widgets
│           └── utils/       # UI helpers
├── utils/                   # Utility scripts (migrations, etc.)
└── docs/                    # Documentation
```
