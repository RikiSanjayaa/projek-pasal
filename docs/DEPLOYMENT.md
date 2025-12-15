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
   - `supabase/seed.sql` (opsional, untuk data dummy)

### 1.3 Buat Super Admin User Pertama

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
   - **service_role key**: JANGAN share, hanya untuk server

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
VITE_SUPABASE_PUBLISHABLE_DEFAULT_KEY=your-key
VITE_APP_NAME=CariPasal Admin
CREATE_ADMIN_API_URL=http://localhost:3001
```

`CREATE_ADMIN_API_URL` adalah base URL yang digunakan frontend untuk memanggil server pembuatan admin (`create-admin-api`). Pada development biasanya `http://localhost:3001`. Jangan masukkan service role key ke file frontend — hanya `create-admin-api` yang menggunakan `SUPABASE_SERVICE_ROLE_KEY` di server-side.

### 2.4 Run Development Server

```bash
npm run dev
```

Buka http://localhost:5173

### 2.5 create-admin-api (server untuk pembuatan admin)

Proyek ini menyertakan server kecil `create-admin-api/server.js` yang digunakan untuk membuat akun admin di Supabase menggunakan service role key. Karena `service_role` key sangat sensitif, operasi pembuatan user harus dijalankan di server — bukan dari frontend.

- Letakkan environment variables untuk server terpisah dari variabel frontend. yang diperlukan:

```bash
# di folder admin-dashboard/create-admin-api
cp .env.example .env
```

Edit `.env`:

- `SUPABASE_URL` — Supabase project URL (sama dengan VITE_SUPABASE_URL)
- `SUPABASE_SERVICE_ROLE_KEY` — Service role key (harus dijaga rapat, hanya di server)
- `PORT` — (opsional) port server, default `3001`

- Cara menjalankan server saat development (dijalankan terpisah dari Vite):

```bash
# di folder admin-dashboard
npm run dev:admin-api
```

- `npm run dev:admin-api` menjalankan `create-admin-api/server.js` (menggunakan `nodemon`) dan menyediakan endpoint `POST /api/create-admin`.
- Jalankan server ini di terminal terpisah bersama `npm run dev` (Vite). Alternatif: gunakan tool seperti `concurrently` atau process manager untuk menjalankan keduanya dalam satu perintah.

Keamanan & deployment

- Jangan deploy `SUPABASE_SERVICE_ROLE_KEY` ke lingkungan yang dapat diakses publik. Untuk deployment produksi, host `create-admin-api` pada server yang Anda kontrol (VPS, Cloud Run, atau serverless dengan secret management) dan pastikan hanya endpoint yang aman dapat diakses.
- Frontend akan memanggil endpoint ini dengan header `Authorization: Bearer <SUPER_ADMIN_ACCESS_TOKEN>`. Server memverifikasi bahwa pemanggil adalah `super_admin` sebelum membuat akun.

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

_(Akan dikembangkan di fase berikutnya)_

### 4.1 Prerequisites

- Flutter SDK >= 3.0
- Android Studio / Xcode

### 4.2 Configure

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
