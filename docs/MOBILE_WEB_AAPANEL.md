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
- menjalankan `dart run tool/build_web.dart --release`, yang membangun Flutter dengan runtime lokal lalu menghasilkan worker/cache manifest berversi;
- memakai base path `/mobile/`;
- memakai API kampus `https://ubgpasal.ubg.ac.id/api`;
- menyalin hasil build ke folder root repo `mobile-web-dist/`.

Jangan mengubah `index.html`, bootstrap, font manifest, atau aset setelah generator selesai: SHA-256 pada worker harus tetap cocok dengan byte yang dipublikasikan. Publikasikan seluruh bundle bersama `caripasal-sw.js`, `offline.js`, dan `offline-build.json`; skrip publish menolak bundle lama tanpa ketiganya. Pemanggilan `flutter build web` langsung tidak menyiapkan cache offline.

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
include /www/wwwroot/hukum-ubg.ac.id/projek-pasal/deploy/aapanel-mobile-web.conf;
```

Sesuaikan `root` di file include bila APP_ROOT berbeda. Konfigurasi memberi header COOP/COEP untuk database web, mencegah cache HTTP entrypoint/worker yang tertinggal, serta mengembalikan 404 untuk aset yang tidak ada. Nginx harus mengenali `.wasm` sebagai `application/wasm`. Worker yang hilang tidak boleh mendapat respons `index.html` dari fallback SPA.

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

- sambungkan internet dan buka Profil/Pengaturan; periksa pemberitahuan versi baru;
- tutup seluruh tab CariPasal dan aplikasi terpasang, lalu buka kembali agar worker baru dapat aktif;
- pastikan `offline-build.json` serta seluruh bundle berasal dari build yang sama dan server sudah menjalankan `git pull`/publish;
- jangan menyarankan hapus data situs atau incognito untuk memakai data offline yang sudah diunduh. Keduanya memakai atau membuat penyimpanan berbeda; hapus data situs menghapus data lokal.

Uji setelah login dan sinkronisasi selesai: status harus **Siap digunakan offline**, matikan jaringan, reload, tutup/buka tab, lalu cari pasal dan periksa bookmark. Batas akses tetap maksimal 30 hari dan tidak melewati masa aktif akun. Uji instalasi/cold launch juga pada Android dan Safari/iOS fisik sebelum menjanjikan dukungan perangkat tersebut.

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
- bisa reload/buka ulang tanpa jaringan setelah file aplikasi, data hukum, dan metadata akses siap tersimpan;
- masih tunduk pada kebijakan penyimpanan browser dan batas akses akun/offline. Status terpasang saja tidak menjamin kesiapan data.

APK:

- khusus Android;
- diinstall ke HP;
- experience lebih mirip aplikasi native;
- perlu build APK baru setiap ada update aplikasi.

Untuk admin kampus yang memakai iPhone, `/mobile/` adalah opsi paling cepat karena tidak perlu build iOS/TestFlight.
