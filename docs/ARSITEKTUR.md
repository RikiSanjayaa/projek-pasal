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
│  • Tanpa login                │  • Login dengan email/password  │
│  • Search pasal               │  • CRUD pasal                   │
│  • Filter by UU               │  • Bulk import JSON             │
│  • Download offline           │  • View audit log               │
│  • Bookmark lokal             │  • Manage undang-undang         │
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
│  • RPC endpoints untuk fungsi pencarian                         │
│  • Real-time subscriptions (opsional)                           │
│                                                                 │
│  Row Level Security (RLS)                                       │
│  ───────────────────────────                                    │
│  • Public: Read pasal & undang-undang yang aktif                │
│  • Admin: CRUD semua data                                       │
│  • Super Admin: Manage admin users                              │
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

### 1. User Search Flow

```
User Input → Mobile App → Supabase REST API → PostgreSQL FTS → Response
                              │
                              ▼
                    (Cached locally with Drift)
```

### 2. Admin CRUD Flow

```
Admin Login → Auth Check → Dashboard → API Call → RLS Check → Database
                              │                        │
                              │                        ▼
                              │              Trigger → Audit Log
                              ▼
                         UI Update ← Query Invalidation
```

### 3. Offline Sync Flow (masih hanya rencana)

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

| Layer           | Technology         | Justification                                 |
| --------------- | ------------------ | --------------------------------------------- |
| Mobile Frontend | Flutter            | Cross-platform (Android & iOS), sudah dipilih |
| Mobile State    | Riverpod           | Scalable, testable, reactive                  |
| Mobile Local DB | Drift (SQLite)     | Type-safe, migration support                  |
| Mobile HTTP     | Dio                | Interceptors, caching support                 |
| Admin Frontend  | React + TypeScript | Ecosystem besar, Mantine compatible           |
| Admin UI        | Mantine v7         | Modern, lengkap, well-documented              |
| Admin State     | TanStack Query     | Caching, invalidation, optimistic updates     |
| Backend         | Supabase           | BaaS, free tier generous, PostgreSQL          |
| Database        | PostgreSQL         | Full-text search, JSONB, RLS                  |
| Auth            | Supabase Auth      | Built-in, role-based, secure                  |

## Security Considerations

### Authentication

- Admin menggunakan Supabase Auth dengan email/password
- Session dikelola otomatis oleh Supabase
- Token refresh otomatis

### Authorization (Row Level Security)

```sql
-- Contoh RLS Policy
CREATE POLICY "Public: read active pasal"
    ON pasal FOR SELECT
    USING (is_active = true);

CREATE POLICY "Admin: write pasal"
    ON pasal FOR ALL
    TO authenticated
    USING (is_admin());
```

### Data Protection

- Audit log untuk setiap perubahan (termasuk pasal_links)
- Soft delete dengan `is_active` dan `deleted_at` untuk restore capability
- Cascade soft delete untuk pasal_links (otomatis mengikuti pasal)
- Auto cleanup untuk data yang sudah soft delete > 30 hari
- Trash management page untuk restore/permanent delete

## Scalability Notes

### Current Design (1000 users)

- Supabase free tier cukup
- Single region deployment
- Client-side caching via local SQLite

### Future Scaling

- Upgrade ke Supabase Pro jika traffic tinggi
- Implement edge caching (CDN)
- Consider read replicas untuk search-heavy loads
- Implement proper pagination di semua list views

## Folder Structure

```
projek-pasal/
├── supabase/
│   ├── migrations/     # Database migrations
│   └── seed.sql        # Dummy data
├── admin-dashboard/
│   └── src/
│       ├── contexts/   # React contexts (Auth)
│       ├── layouts/    # Layout components
│       ├── lib/        # Supabase client, types
│       └── pages/      # Page components
├── mobile-app/         # Flutter app (akan dibuat)
└── docs/               # Documentation
```
