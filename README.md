# CariPasal - Aplikasi Pencarian Pasal Hukum Indonesia

Aplikasi untuk mencari dan mengelola pasal-pasal dari:

- **KUHP** (Kitab Undang-Undang Hukum Pidana)
- **KUHPer** (Kitab Undang-Undang Hukum Perdata)
- **KUHAP** (Kitab Undang-Undang Hukum Acara Pidana)
- **UU ITE** (Undang-Undang Informasi dan Transaksi Elektronik)

## Arsitektur

```
┌─────────────────────────────────────────────────────────────┐
│                        CLIENTS                              │
├─────────────────────────┬───────────────────────────────────┤
│  Mobile App             │  Admin Dashboard                  │
│  (Flutter)              │  (React + Mantine)                │
│  - User biasa           │  - CRUD pasal                     │
│  - Login dengan email   │  - Bulk import XLSX               │
│  - Offline support      │  - Audit log                      │
└─────────────────────────┴───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    BACKEND (Supabase)                       │
│  - PostgreSQL Database                                      │
│  - Authentication                                           │
│  - Auto-generated REST API                                  │
│  - Row Level Security                                       │
└─────────────────────────────────────────────────────────────┘
```

## Struktur Folder

```
projek-pasal/
├── supabase/           # Database migrations & config edge function
├── admin-dashboard/    # React + Mantine admin panel
├── pasal_mobile_app/   # Flutter mobile application
├── utils/              # Utility scripts (migrations, etc.)
└── docs/               # Dokumentasi lengkap
```

## Quick Start

### Prerequisites

- Node.js >= 18
- Flutter >= 3.8
- Supabase CLI (opsional untuk local development)

### Setup Supabase

1. Buat akun di [supabase.com](https://supabase.com)
2. Buat project baru
3. Copy URL dan key ke environment variables
4. Jalankan migrations
5. Jalankan Edge functions yang ada di /supabase/functions/create-admin/index.ts
6. buat akun super_admin pertama, contoh ada di [Panduan Deployment](docs/DEPLOYMENT.md)

### Setup Admin Dashboard

```bash
cd admin-dashboard
npm install
cp .env.example .env.local
# Edit .env.local dengan Supabase credentials
npm run dev
```

### Setup Mobile App

```bash
cd pasal_mobile_app
flutter pub get
# Copy dan edit env config:
cp lib/core/config/env-example.dart lib/core/config/env.dart
# Edit lib/core/config/env.dart dengan Supabase credentials
flutter run
```

## Dokumentasi

- [Arsitektur Sistem](docs/ARSITEKTUR.md)
- [Database Schema](docs/DATABASE.md)
- [Panduan Deployment](docs/DEPLOYMENT.md)

## Roles & Permissions

| Role            | Akses                                        |
| --------------- | -------------------------------------------- |
| **User Biasa**  | Read pasal, search, filter, download offline |
| **Admin**       | CRUD pasal, bulk import, view audit log      |
| **Super Admin** | Semua + manage admin users                   |

## Lisensi

Hak Cipta © 2025 Universitas Bumigora. Seluruh hak dilindungi.

---

Dikembangkan oleh mahasiswa Universitas Bumigora untuk kemudahan akses informasi hukum.
