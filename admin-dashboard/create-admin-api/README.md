# create-admin-api

Singkat: server kecil berbasis Express yang menyediakan endpoint aman untuk membuat akun admin (melalui Supabase Admin API / service role).

Mengapa diperlukan

- Pembuatan akun auth di Supabase membutuhkan `service_role` key yang sangat sensitif — tidak boleh diekspos di frontend.
- `server.js` menjalankan logika server-side untuk membuat user auth, menambahkan baris ke tabel `admin_users`, dan melakukan rollback jika perlu.
- Endpoint ini juga memeriksa bahwa pemanggil adalah `super_admin` sebelum mengizinkan pembuatan akun.

Konfigurasi (environment variables di directory create-admin-api)

- `SUPABASE_URL` — URL project Supabase.
- `SUPABASE_SERVICE_ROLE_KEY` — Service Role key (harus disimpan aman, hanya di server).
- `PORT` — (opsional) port server, default `3001`.

Cara menjalankan bersamaan dengan Vite (frontend)

- Di direktori `admin-dashboard` tersedia script di `package.json`:

  - `npm run dev` — menjalankan Vite (frontend)
  - `npm run dev:admin-api` — menjalankan `create-admin-api/server.js` dengan `nodemon`

- Jalankan kedua perintah di terminal terpisah, atau gunakan tool seperti `concurrently` jika ingin satu perintah saja. Frontend akan memanggil endpoint `POST /api/create-admin` untuk membuat akun admin.

Keamanan & catatan

- Simpan `SUPABASE_SERVICE_ROLE_KEY` di server/CI/CD secrets — jangan commit ke repo.
- Hanya `super_admin` yang bisa memanggil endpoint ini; pastikan token Authorization dikirim oleh frontend sebagai `Bearer <access_token>` milik super_admin.
- Endpoint mencoba rollback (menghapus auth user) jika memasukkan baris `admin_users` gagal.

Contoh singkat (curl)

```
curl -X POST http://localhost:3001/api/create-admin \
  -H "Authorization: Bearer <SUPER_ADMIN_ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"email":"newadmin@example.com","nama":"Nama Admin"}'
```
