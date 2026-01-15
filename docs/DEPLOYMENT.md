# Panduan Deployment - CariPasal

## Daftar Isi

1. [Setup Supabase](#1-setup-supabase)
2. [Setup Admin Dashboard](#2-setup-admin-dashboard)
3. [Deploy Admin Dashboard](#3-deploy-admin-dashboard)
4. [Setup Mobile App](#4-setup-mobile-app)

---

## 1. Setup Supabase

### 1.1 Buat Akun dan Project

1. Buka [supabase.com](https://supabase.com) dan buat akun
2. Klik "New Project"
3. Isi detail:
   - **Name**: caripasal-production
   - **Database Password**: (simpan dengan aman!)
   - **Region**: Singapore (terdekat dengan Indonesia)
4. Tunggu project selesai dibuat (~2 menit)

### 1.2 Jalankan Migrations

1. Buka **SQL Editor** di Supabase Dashboard
2. Jalankan file-file berikut secara berurutan:

   - `supabase/migrations/001_initial_schema.sql` (schema, soft delete, triggers)
   - `supabase/migrations/002_rls_policies.sql` (row level security)
   - `supabase/migrations/003_search_functions.sql` (search functions)
   - `supabase/migrations/004_pasal_links_audit.sql` (audit trigger untuk links)
   - `supabase/migrations/005_remove_ip_in_audit.sql` (revisi atribut audit)
   - `supabase/migrations/006_fix_get_download_data.sql` (fix download data function)
   - `supabase/migrations/007_fix_pasal_links_rls.sql` (fix RLS pasal_links)
   - `supabase/migrations/008_audit_logs_retention.sql` (retention policy audit logs)
   - `supabase/migrations/009_cascade_uu_is_active.sql` (cascade is_active UU ke pasal)
   - `supabase/migrations/010_sync_check_function.sql` (fungsi sync untuk mobile)
   - `supabase/migrations/011_user_auth_schema.sql` (schema users & user_devices)
   - `supabase/migrations/012_update_rls_for_user_auth.sql` (RLS untuk user auth)
   - `supabase/migrations/013_fix_cascade_uu_is_active.sql` (fix cascade untuk soft delete)
   - `supabase/migrations/014_audit_improvements.sql` (audit untuk users, skip cascade)
   - `supabase/seed.sql` (opsional, untuk data dummy)

#### Opsional: Jalankan Migrations via Supabase CLI

Jika Anda ingin menjalankan migration dan seed menggunakan Supabase CLI (tanpa membuka SQL Editor di Dashboard):

1. Instal atau gunakan CLI via `npx` (tidak wajib install global):

```bash
# pakai npx, tanpa install
npx supabase --version
```

2. Login ke akun Supabase (akan membuka browser untuk otentikasi):

```bash
npx supabase login
```

3. Link folder project lokal ke project Supabase Anda (gunakan `project-ref` dari dashboard):

```bash
# contoh interaktif
npx supabase link --project-ref <YOUR_PROJECT_REF>
```

4. Jalankan migrations dari folder `supabase/migrations` ke project yang sudah linked:

```bash
# akan membaca migration lokal dan menerapkannya ke database linked
npx supabase db push
```

Catatan: `db push` akan menerapkan perubahan schema/migration lokal ke project Supabase yang sudah di-link.

````bash
# menjalankan migration dengan file seed (opsional)
npx supabase db push --include-seed

5. Verifikasi / cek status atau perbedaan sebelum/ sesudah:

```bash
# lihat perbedaan lokal vs remote
npx supabase db diff --linked
````

Jika ada masalah atau perintah di atas tidak tersedia pada versi CLI Anda, jalankan `npx supabase --help` untuk melihat subcommands yang tersedia dan versi terbaru.

### 1.3 Buat `super_admin` User Pertama

1. Buka **Authentication** > **Users** di Supabase Dashboard
2. Klik "Add User" > "Create New User"
3. Isi email dan password admin pertama
4. Copy User ID yang dihasilkan

5. Buka **SQL Editor** dan jalankan:
   ```sql
   INSERT INTO admin_users (id, email, nama, role)
   VALUES (
       'USER_ID_DARI_LANGKAH_4',
       'email@example.com',
       'Nama Admin',
       'super_admin'
   );
   ```

### 1.4 Dapatkan API Keys

1. Buka **Settings** > **API**
2. Catat:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon/public key**: untuk client-side

---

## 2. Setup Admin Dashboard

### 2.1 Prerequisites

- Node.js >= 18
- npm atau pnpm

### 2.2 Install Dependencies

```bash
cd admin-dashboard
npm install
```

### 2.3 Configure Environment

```bash
cp .env.example .env
```

Edit `.env`:

```env
VITE_SUPABASE_URL=https://xxxxx.supabase.co
VITE_SUPABASE_PUBLISHABLE_DEFAULT_KEY=your-publishable-key
VITE_APP_NAME=CariPasal Admin
```

### 2.4 Run Development Server

```bash
npm run dev
```

Buka http://localhost:5173

### 2.5 Deploy Edge Functions

Deploy semua Edge Functions yang diperlukan melalui Supabase CLI:

```bash
# Deploy semua edge functions
npx supabase functions deploy create-admin
npx supabase functions deploy create-user
npx supabase functions deploy create-users-batch
npx supabase functions deploy delete-user
```

**Daftar Edge Functions:**
| Function | Deskripsi |
|----------|-----------|
| `create-admin` | Membuat akun admin baru |
| `create-user` | Membuat akun pengguna mobile baru dengan masa aktif 3 tahun |
| `create-users-batch` | Import batch pengguna mobile dari file XLSX |
| `delete-user` | Menghapus akun pengguna mobile |

**Catatan:** Edge functions memerlukan `SUPABASE_SERVICE_ROLE_KEY` untuk operasi admin (sudah dikonfigurasi otomatis di Supabase Cloud).

---

## 3. Deploy Admin Dashboard

### Opsi A: Vercel (Recommended)

1. Push kode ke GitHub repository
2. Buka [vercel.com](https://vercel.com) dan import project
3. Set root directory ke `admin-dashboard`
4. Add environment variables:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_PUBLISHABLE_DEFAULT_KEY`
5. Deploy!

### Opsi B: Netlify

1. Build project:
   ```bash
   cd admin-dashboard
   npm run build
   ```
2. Upload folder `dist` ke Netlify
3. Set environment variables di Netlify Dashboard

### Opsi C: Self-Hosted (VPS/Server Kampus)

1. Build project:
   ```bash
   npm run build
   ```
2. Upload folder `dist` ke server
3. Configure nginx:

   ```nginx
   server {
       listen 80;
       server_name admin.caripasal.kampus.ac.id;
       root /var/www/caripasal-admin;

       location / {
           try_files $uri $uri/ /index.html;
       }
   }
   ```

---

## 4. Setup Mobile App

### 4.1 Prerequisites

- Flutter SDK >= 3.8
- Android Studio / Xcode

### 4.2 Install Dependencies

```bash
cd pasal_mobile_app
flutter pub get
```

### 4.3 Configure

Copy dan edit file konfigurasi:

```bash
cp lib/core/config/env-example.dart lib/core/config/env.dart
```

Edit `lib/core/config/env.dart`:

```dart
class Env {
  static const supabaseUrl = 'https://xxxxx.supabase.co';
  static const supabaseAnonKey = 'your-anon-key';
}
```

### 4.3 Build

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

---
