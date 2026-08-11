# Deploy Flutter Web Mobile ke aaPanel Kampus

Dokumen ini untuk membuat halaman mobile web seperti:

```text
https://ubgpasal.ubg.ac.id/mobile/
```

Target alur:

```text
Laptop build Flutter Web -> hasil build dipush ke GitHub -> server kampus pull -> publish ke /mobile/
```

Dengan cara ini server kampus tidak perlu install Flutter, Android SDK, atau toolchain berat lain.

## Struktur URL Production

```text
https://ubgpasal.ubg.ac.id/admin/       Admin dashboard React
https://ubgpasal.ubg.ac.id/api/         Laravel REST API
https://ubgpasal.ubg.ac.id/mobile/      Flutter Web mobile
```

## 1. Build di Laptop

Jalankan dari root repo:

```powershell
cd "E:\projeck git\projek-pasal"

.\build-mobile-web.ps1 `
  -ApiBaseUrl "https://ubgpasal.ubg.ac.id/api" `
  -WebAppUrl "https://ubgpasal.ubg.ac.id" `
  -BaseHref "/mobile/"
```

Script akan:

- menjalankan `flutter pub get`;
- menjalankan `flutter build web --release`;
- memakai base path `/mobile/`;
- memakai API kampus `https://ubgpasal.ubg.ac.id/api`;
- menyalin hasil build ke folder root repo `mobile-web-dist/`.

Folder yang perlu dipush:

```text
mobile-web-dist/
```

## 2. Push ke GitHub

Setelah build sukses:

```powershell
git status
git add mobile-web-dist build-mobile-web.ps1 deploy/aapanel-publish-mobile-web.sh docs/MOBILE_WEB_AAPANEL.md README.md
git commit -m "docs: tambah panduan deploy mobile web kampus"
git push origin main
```

Untuk update mobile web berikutnya, cukup ulangi:

```powershell
.\build-mobile-web.ps1 `
  -ApiBaseUrl "https://ubgpasal.ubg.ac.id/api" `
  -WebAppUrl "https://ubgpasal.ubg.ac.id" `
  -BaseHref "/mobile/"

git add mobile-web-dist
git commit -m "build: update mobile web kampus"
git push origin main
```

## 3. Pull dan Publish di Server Kampus

Masuk ke server kampus:

```bash
cd /www/wwwroot/hukum-ubg.ac.id/projek-pasal
git pull --ff-only origin main
```

Publish hasil build ke folder `/mobile`:

```bash
APP_ROOT=/www/wwwroot/hukum-ubg.ac.id/projek-pasal \
DOMAIN=ubgpasal.ubg.ac.id \
bash deploy/aapanel-publish-mobile-web.sh
```

Script akan:

- membaca hasil build dari `mobile-web-dist/`;
- menyalin ke `/www/wwwroot/hukum-ubg.ac.id/projek-pasal/mobile/`;
- mengatur permission ke user web aaPanel;
- reload Nginx;
- menampilkan URL `https://ubgpasal.ubg.ac.id/mobile/`.

## 4. Konfigurasi Nginx

Tambahkan blok ini di config Nginx domain `ubgpasal.ubg.ac.id`, di dalam `server { ... }`:

```nginx
location ^~ /mobile/ {
    alias /www/wwwroot/hukum-ubg.ac.id/projek-pasal/mobile/;
    index index.html;
    try_files $uri $uri/ /mobile/index.html;
}

location ~* \.wasm$ {
    default_type application/wasm;
    expires 7d;
}
```

Setelah edit:

```bash
nginx -t
/etc/init.d/nginx reload
```

## 5. Test Setelah Publish

```bash
curl -I https://ubgpasal.ubg.ac.id/mobile/
curl https://ubgpasal.ubg.ac.id/api/health
```

Browser:

```text
https://ubgpasal.ubg.ac.id/mobile/
```

Jika masih tampil versi lama:

- tekan `Ctrl + F5` di desktop;
- di HP, buka private/incognito atau clear cache browser;
- pastikan `mobile-web-dist/index.html` sudah berubah di GitHub;
- pastikan server sudah menjalankan `git pull`.

## 6. Catatan Cloudflare

API mobile web tetap memanggil:

```text
https://ubgpasal.ubg.ac.id/api
```

Pastikan Cloudflare tidak memberi challenge untuk endpoint API:

```text
Hostname equals ubgpasal.ubg.ac.id
AND URI Path starts with /api/
Action: Skip/Allow challenge security features
```

Kalau `/api/*` kena challenge, mobile web dan APK bisa gagal login/sync.

## 7. Bedanya Mobile Web dan APK

Mobile web:

- dibuka lewat browser di `/mobile/`;
- bisa dipakai iPhone dan Android;
- tidak perlu install APK;
- bergantung browser dan koneksi saat membuka aplikasi;
- tetap bisa memakai local storage/browser storage sesuai dukungan browser.

APK:

- khusus Android;
- diinstall ke HP;
- experience lebih mirip aplikasi native;
- perlu build APK baru setiap ada update aplikasi.

Untuk admin kampus yang memakai iPhone, `/mobile/` adalah opsi paling cepat karena tidak perlu build iOS/TestFlight.
