# Panduan Admin Kampus - Uji Coba CariPasal Mobile Web

Dokumen ini untuk admin server kampus yang ingin mencoba halaman mobile web:

```text
https://ubgpasal.ubg.ac.id/mobile/
```

Mobile web ini adalah hasil build Flutter Web yang sudah dipush ke GitHub di folder:

```text
mobile-web-dist/
```

Jadi server kampus tidak perlu install Flutter, Android SDK, atau build apa pun. Server cukup menjalankan satu script untuk pull dari GitHub lalu publish hasil build ke folder `/mobile`.

## Ringkasan URL

```text
https://ubgpasal.ubg.ac.id/admin/       Admin dashboard
https://ubgpasal.ubg.ac.id/api/health   Cek backend Laravel
https://ubgpasal.ubg.ac.id/mobile/      Mobile web untuk uji coba HP/browser
```

## 1. Cara Paling Mudah

Masuk ke server kampus, lalu jalankan:

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal

APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal \
DOMAIN=ubgpasal.ubg.ac.id \
bash deploy/aapanel-mobile-web-update.sh
```

Script ini akan otomatis:

- pull update terbaru dari GitHub;
- mengecek folder `mobile-web-dist/`;
- publish hasil build ke folder `mobile/`;
- mengatur permission file;
- reload Nginx;
- mengecek `https://ubgpasal.ubg.ac.id/mobile/`;
- mengecek `https://ubgpasal.ubg.ac.id/api/health`.

Kalau script selesai tanpa error, buka:

```text
https://ubgpasal.ubg.ac.id/mobile/
```

## 2. Cara Manual Jika Script Utama Bermasalah

Bagian ini hanya dipakai kalau script satu perintah di atas gagal.

Update source dari GitHub:

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal
git pull --ff-only origin main
```

Pastikan folder build mobile web ada:

```bash
ls -la mobile-web-dist
ls -la mobile-web-dist/index.html
```

Publish Mobile Web ke `/mobile/`:

Jalankan:

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal

APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal \
DOMAIN=ubgpasal.ubg.ac.id \
bash deploy/aapanel-publish-mobile-web.sh
```

Script ini akan:

- menyalin isi `mobile-web-dist/` ke folder `mobile/`;
- mengatur permission file agar bisa dibaca Nginx/aaPanel;
- reload Nginx;
- menampilkan URL `https://ubgpasal.ubg.ac.id/mobile/`.

## 3. Config Nginx yang Dibutuhkan Sekali Saja

Di aaPanel, buka config Nginx untuk domain:

```text
ubgpasal.ubg.ac.id
```

Tambahkan blok ini di dalam `server { ... }`:

```nginx
location ^~ /mobile/ {
    alias /www/wwwroot/hukum-ubg.ac.id/projek-pasal/mobile/;
    index index.html;
    try_files $uri $uri/ /mobile/index.html;
}
```

Jika belum ada MIME untuk `.wasm`, tambahkan juga:

```nginx
location ~* \.wasm$ {
    default_type application/wasm;
    expires 7d;
}
```

Setelah edit config:

```bash
nginx -t
/etc/init.d/nginx reload
```

Kalau `nginx -t` gagal, jangan reload dulu. Perbaiki error config sampai test berhasil.

## 4. Test dari Server

```bash
curl -I https://ubgpasal.ubg.ac.id/mobile/
curl https://ubgpasal.ubg.ac.id/api/health
```

Hasil yang diharapkan:

```text
HTTP/1.1 200 OK
```

Untuk API health, response seharusnya JSON seperti:

```json
{"status":"ok"}
```

## 5. Test dari Browser/HP

Buka:

```text
https://ubgpasal.ubg.ac.id/mobile/
```

Jika tampil blank atau masih versi lama:

- buka mode private/incognito;
- clear cache browser;
- pastikan `git pull` sudah mengambil commit terbaru;
- pastikan script `deploy/aapanel-publish-mobile-web.sh` sudah dijalankan;
- cek file `mobile/index.html` ada di server.

## 6. Apakah Perlu Setting Cloudflare?

Untuk publish `/mobile/`, tidak perlu setting Cloudflare baru.

Yang penting: endpoint API jangan kena Cloudflare challenge, karena mobile web dan APK login/sync lewat:

```text
https://ubgpasal.ubg.ac.id/api
```

Jika `curl https://ubgpasal.ubg.ac.id/api/health` sudah mengembalikan JSON, berarti aman.

Jika yang muncul HTML seperti `Just a moment...` dari Cloudflare, berarti `/api/*` masih kena challenge. Atur Cloudflare agar `/api/*` tidak diberi challenge:

```text
Hostname equals ubgpasal.ubg.ac.id
AND URI Path starts with /api/
Action: Skip/Allow challenge security features
```

Fitur yang perlu di-skip untuk `/api/*` jika tersedia:

```text
Managed Challenge
Bot Fight Mode / Super Bot Fight Mode
Browser Integrity Check
WAF Managed Rules yang memblokir API
```

Admin dashboard dan `/mobile/` boleh tetap lewat Cloudflare. Yang tidak boleh kena challenge adalah `/api/*`.

## 7. Update Berikutnya

Kalau developer sudah push update baru ke GitHub, admin server cukup jalankan satu perintah ini:

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal

APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal \
DOMAIN=ubgpasal.ubg.ac.id \
bash deploy/aapanel-mobile-web-update.sh
```

Kalau update juga menyentuh backend/admin dashboard, jalankan script deploy utama:

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal

APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal \
DOMAIN=ubgpasal.ubg.ac.id \
bash deploy/aapanel-update.sh
```

Setelah itu publish mobile web lagi:

```bash
APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal \
DOMAIN=ubgpasal.ubg.ac.id \
bash deploy/aapanel-mobile-web-update.sh
```
