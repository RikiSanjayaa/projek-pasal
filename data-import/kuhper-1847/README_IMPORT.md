# Import KUHPER (Kitab Undang-Undang Hukum Perdata (Burgerlijk Wetboek, Staatsblad 1847 Nomor 23))

File ini dibuat oleh `import-tools/prepare_import.py kuhper-1847`. Jangan edit manual; perbaiki konfigurasi di
`import-tools/laws/` atau mesinnya di `import-tools/datahukum_pipeline.py`, lalu jalankan ulang.

## Isi

- `01_kuhper_1847_ready.xlsx`
  - sheet `import`: 2124 pasal (Pasal 1 sampai 1993 ditambah 126 pasal sisipan).
  - sheet `review`: hasil pemeriksaan tiap pasal.
- Teks sudah dikonsolidasi dengan 53 peraturan perubahan (tabel di bawah):
  - isi pasal diubah (219): 4, 33, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 46, 47, 49, 52, 53, 54, 57, 58, 61, 62, 63, 71, 75, 76, 91, 109, 110, 113, 127, 132, 199, 202, 203, 205, 206, 207, 209, 210, 211, 214, 221, 225, 229, 230, 237, 239, 240, 246, 275, 277, 284, 287, 298, 299, 300, 301, 302, 303, dan 159 lainnya (lihat sheet `review`)
  - pasal sisipan (126): 99a, 184a, 206a, 230a, 230b, 230c, 232a, 246a, 246b, 271a, 319a, 319b, 319c, 319d, 319e, 319f, 319g, 319h, 319i, 319j, 319k, 319m, 329a, 329b, 331a, 331b, 332a, 332b, 338a, 354a, 365a, 381a, 382a, 382b, 382c, 382d, 382e, 382f, 382g, 416a, 776a, 852a, 852b, 902a, 916a, 1146a, 1152bis, 1601a, 1601b, 1601c, 1601d, 1601e, 1601f, 1601g, 1601h, 1601i, 1601j, 1601k, 1601l, 1601m, dan 66 lainnya (lihat sheet `review`)
  - pasal dihapus/dicabut, isinya "Dicabut." (64): 5a, 5b, 6, 7, 8, 9, 10, 11, 12, 17, 18, 19, 20, 21, 22, 23, 24, 25, 55, 56, 68, 226, 230d, 305, 316, 317, 319l, 324, 325, 346, 347, 349, 350, 376, 450, 455, 466, 496, 497, 498, 569, 614, 615, 910, 1161, 1479, 1547, 1549, 1568, 1601y, 1700, 1701, 1703, 1704, 1783, 1828, 1882, 1896, 1897, 1898, dan 4 lainnya (lihat sheet `review`)
- Sheet `riwayat` berisi 770 versi: semua rumusan tiap pasal yang pernah berubah, dari Stb. 1847 No. 23 sampai rumusan yang berlaku, masing-masing dengan sumber dan link naskah resminya (kalau ada). Import menyimpannya sebagai riwayat pasal.
- `judul` diisi judul paragraf/bagian/bab tempat pasal berada (tidak ada judul per pasal).
- Undang-undang ini tidak punya penjelasan resmi.
- 910 pasal diberi catatan berawalan "Catatan CariPasal:" di kolom penjelasan: status
  berlaku menurut undang-undang yang lebih baru (bukan bagian naskah). Aturannya ada di
  `catatan_rules` konfigurasi.
- `bab`: bab tempat pasal berada, dengan buku di depannya kalau ada (mis. "Buku Kedua · Bab XXI · Tentang Hipotek"). Tidak perlu diisi manual.
- `linkN_*` (pasal terkait, 418 link): rujukan ke pasal lain di KUHPER yang disebut di isi
  pasal, misalnya "sebagaimana dimaksud dalam Pasal 54". Rujukan yang diikuti nama undang-undang lain
  dilewati.
  Maksimal 20 per pasal.

### Peraturan perubahan

| Peraturan | Tentang | Diubah | Disisipkan | Dicabut/dihapus |
|---|---|---|---|---|
| Stb. 1872 No. 11 | Kewenangan orang asing untuk bertindak sebagai ahli waris (disahkan 6 November 1871) | 0 | 0 | 2 |
| Stb. 1872 No. 42 | Perubahan dan penambahan terhadap Pasal 335 dan 837 Burgerlijk Wetboek | 1 | 1 | 0 |
| Stb. 1873 No. 229 | Pencabutan Pasal 569 Burgerlijk Wetboek bagi orang Eropa dan mereka yang dipersamakan dengannya | 0 | 0 | 1 |
| Stb. 1875 No. 257 | Penggantian dengan ketentuan-ketentuan lain terhadap Pasal 426, 427, 428, Pasal 430 ayat kedua, dan Pasal 431 Burgerlijk Wetboek (disahkan 18 Agustus 1875) | 5 | 0 | 0 |
| Stb. 1875 No. 258 | Penggantian Pasal 1151–1156 Burgerlijk Wetboek dengan ketentuan-ketentuan lain (disahkan 18 Agustus 1875) | 6 | 1 | 0 |
| Stb. 1881 No. 95 | Pemisahan hak milik (disahkan 1 Februari 1881) | 0 | 0 | 0 |
| Stb. 1893 No. 292 | Penambahan ketentuan pada Pasal 933 dan Pasal 941 Burgerlijk Wetboek untuk Hindia Belanda (disahkan 22 Februari 1893) | 2 | 0 | 0 |
| Stb. 1896 No. 108 | Perubahan Pasal 284 Burgerlijk Wetboek untuk Hindia Belanda dan penetapan suatu ketentuan yang berkaitan dengannya (disahkan 25 Maret 1896) | 1 | 0 | 0 |
| Stb. 1896 No. 115 | Perubahan Pasal 275, 276, dan 278 Burgerlijk Wetboek mengenai pengesahan anak luar kawin yang telah diakui (disahkan 25 Maret 1896) | 1 | 0 | 0 |
| Stb. 1897 No. 53 | Perubahan Pasal 134, 137, dan 138 Reglement tentang Organisasi Kehakiman dan Kebijakan Peradilan di Hindia Belanda serta Pasal 456 dan 462 Burgerlijk Wetboek untuk Hindia Belanda, dan pencabutan Pasal 455 dari Burgerlijk Wetboek tersebut (disahkan 25 Juni 1895) | 2 | 0 | 1 |
| Stb. 1899 No. 512 | Perubahan dan penambahan Pasal 948, 950, dan 951 Burgerlijk Wetboek untuk Hindia Belanda (disahkan 29 September 1899) | 3 | 0 | 0 |
| Stb. 1901 No. 194 | Pengundangan Keputusan Kerajaan yang menetapkan usia dewasa bagi orang Eropa dan mereka yang dipersamakan dengannya di Hindia Belanda menjadi dua puluh satu tahun (disahkan 28 Februari 1901) | 3 | 0 | 0 |
| Stb. 1901 No. 353 | Pengundangan Keputusan Kerajaan tanggal 1 Agustus 1901 No. 53 mengenai pengaturan lebih lanjut tentang penurunan usia dewasa dalam perundang-undangan Hindia Belanda (disahkan 1 Agustus 1901) | 1 | 0 | 0 |
| Stb. 1902 No. 222 | Perubahan Pasal 721, 775, dan 776 Burgerlijk Wetboek untuk Hindia Belanda serta penambahan Pasal 776a baru ke dalam Burgerlijk Wetboek tersebut (disahkan 26 Februari 1904) | 1 | 0 | 0 |
| Stb. 1904 No. 233 | Perubahan Pasal 721, 775, dan 776 Burgerlijk Wetboek untuk Hindia Belanda serta penambahan Pasal 776a baru ke dalam Burgerlijk Wetboek tersebut (disahkan 26 Februari 1904) | 3 | 1 | 0 |
| Stb. 1906 No. 348 | Penetapan waktu mulai berlakunya (undang-undang kepailitan) Faillissementsverordening dalam Staatsblad 1905 No. 217 serta ketentuan-ketentuan hukum yang berkaitan dengannya | 4 | 0 | 2 |
| Stb. 1916 No. 42 | Perubahan dan penambahan Burgerlijk Wetboek untuk Hindia Belanda (disahkan 24 Maret 1915) | 3 | 1 | 0 |
| Stb. 1916 No. 325 | Penunjukan seorang wakil Balai Harta Peninggalan Hindia di Belanda | 1 | 0 | 0 |
| Stb. 1916 No. 338 | Keputusan Kerajaan tanggal 12 Januari 1916 No. 46 tentang perubahan Burgerlijk Wetboek untuk Hindia Belanda (disahkan 12 Januari 1916) | 8 | 0 | 2 |
| Stb. 1916 No. 530 | Perubahan atas | 3 | 0 | 0 |
| Stb. 1917 No. 497 | Penetapan Peraturan Pemberlakuan Kitab Undang-Undang Hukum Pidana untuk Hindia Belanda (Staatsblad Hindia 1917 No. 497) (disahkan 4 Mei 1917) | 25 | 1 | 0 |
| Stb. 1919 No. 603 | Perubahan dan penambahan ketentuan perundang-undangan mengenai kekuatan pembuktian cap ibu jari (disahkan 3 Juni 1919) | 1 | 0 | 0 |
| Stb. 1921 No. 489 | Perubahan Pasal 415 Kitab Undang-Undang Hukum Perdata untuk Hindia Belanda (disahkan 4 Juli 1921) | 1 | 0 | 0 |
| Stb. 1922 No. 573 | Keputusan Kerajaan tanggal 19 Juni 1922 No. 85 tentang perubahan beberapa pasal Kitab Undang-Undang Hukum Perdata untuk Hindia Belanda (disahkan 19 Juni 1922) | 3 | 0 | 0 |
| Stb. 1923 No. 31 | Keputusan Kerajaan tanggal 23 Desember 1922 No. 76 tentang perubahan Kitab Undang-Undang Hukum Perdata untuk Hindia Belanda (Pembatasan larangan untuk menikah kembali) (disahkan 23 Desember 1922) | 2 | 4 | 0 |
| Stb. 1923 No. 287 | Keputusan Kerajaan tanggal 3 April 1923 No. 38 tentang penambahan dan perubahan Kitab Undang-Undang Hukum Perdata dan Reglemen Acara Perdata mengenai ketentuan tentang pembubaran perkawinan setelah pisah meja dan tempat tidur, perceraian, pisah meja dan tempat tidur, serta pemisahan harta kekayaan (disahkan 3 April 1923) | 3 | 0 | 0 |
| Stb. 1925 No. 113 | Keputusan Kerajaan tanggal 26 Februari 1925 No. 33 tentang perubahan dan penambahan Pasal 335, 417, dan 463 Kitab Undang-Undang Hukum Perdata untuk Hindia Belanda serta Pasal 231 Inlandsch Reglement (disahkan 26 Februari 1925) | 3 | 0 | 0 |
| Stb. 1925 No. 199 | Perubahan atas | 2 | 0 | 0 |
| Stb. 1925 No. 525 | Perubahan atas | 8 | 0 | 9 |
| Stb. 1925 No. 678 | Perubahan atas | 2 | 0 | 0 |
| Stb. 1926 No. 335 | Keputusan Kerajaan tanggal 12 Juni 1926 No. 33 tentang pengaturan perjanjian kerja untuk Hindia Belanda (disahkan 12 Juni 1926) | 18 | 77 | 2 |
| Stb. 1927 No. 31 | Keputusan Kerajaan tanggal 6 Desember 1926 No. 1 tentang pemberlakuan perundang-undangan perdata Belanda mengenai anak di Hindia Belanda (disahkan 6 Desember 1926) | 100 | 33 | 14 |
| Stb. 1927 No. 146 | Perubahan ketentuan-ketentuan Kitab Undang-Undang Hukum Dagang mengenai pembukuan pedagang serta ketentuan-ketentuan yang berkaitan dengannya dalam Kitab Undang-Undang Hukum Perdata, Kitab Undang-Undang Hukum Pidana, dan Reglemen Bumiputra (disahkan 7 April 1927) | 0 | 0 | 1 |
| Stb. 1927 No. 456 | Perubahan atas Keputusan Kerajaan dalam Staatsblad Hindia 1927 No. 31 tentang pemberlakuan perundang-undangan perdata Belanda mengenai anak di Hindia Belanda | 3 | 0 | 0 |
| Stb. 1928 No. 210 | Perubahan tarif imbalan bagi Balai Harta Peninggalan di Hindia Belanda dan beberapa pasal Kitab Undang-Undang Hukum Perdata | 2 | 0 | 1 |
| Stb. 1928 No. 533 | Pembebasan dari bea meterai atas surat-surat yang berkaitan dengan perjanjian kerja (disahkan 14 Desember 1928) | 0 | 0 | 1 |
| Stb. 1928 No. 546 | Perubahan atas (disahkan 21 Desember 1928) | 6 | 0 | 0 |
| Stb. 1931 No. 367 | Pelengkapan Kitab Undang-Undang Hukum Perdata dan Reglemen tentang Organisasi Peradilan | 3 | 1 | 0 |
| Stb. 1932 No. 42 | Diperbolehkannya perempuan menjadi saksi dalam akta (disahkan 21 Januari 1932) | 2 | 0 | 0 |
| Stb. 1932 No. 496 | Penambahan ketentuan pada Pasal 1149 angka 4 Burgerlijk Wetboek voor Nederlandsch-Indië dan Pasal 232 angka 5 Faillissementsverordening (disahkan 19 September 1932) | 1 | 0 | 0 |
| Stb. 1933 No. 47 | Perubahan atas KITAB UNDANG-UNDANG HUKUM PERDATA (BURGERLIJK | 2 | 0 | 0 |
| Stb. 1934 No. 214 | Perubahan atas Bab Ketiga dan Bab Keempat Buku Kedua Kitab Undang-Undang Hukum Dagang serta ketentuan-ketentuan peraturan perundang-undangan yang berkaitan dengannya (disahkan 27 April 1934) | 1 | 0 | 0 |
| Stb. 1935 No. 486 | Perubahan dan penambahan ketentuan-ketentuan Burgerlijk Wetboek mengenai pewarisan (disahkan 1 Januari 1936) | 18 | 3 | 0 |
| Stb. 1936 No. 481 | Perubahan dan penambahan ketentuan-ketentuan Kitab Undang-Undang Hukum Perdata mengenai perjanjian untuk melakukan pekerjaan dalam hal pengaturan hari-hari bebas pekerja (disahkan 21 September 1936) | 1 | 0 | 0 |
| Stb. 1937 No. 572 | Pengalihan kepada pejabat yang ditugaskan menjalankan pemerintahan umum atas beberapa kewenangan yang sebelumnya diberikan kepada Gubernur Jenderal | 3 | 0 | 0 |
| Stb. 1937 No. 595 | Perubahan Kitab Undang-Undang Hukum Perdata dan Reglemen mengenai penyelenggaraan register catatan sipil bagi orang Eropa dan orang Tionghoa | 5 | 4 | 1 |
| Stb. 1938 No. 276 | Penghapusan pembedaan antara pedagang dan bukan pedagang serta antara perbuatan perniagaan dan bukan perbuatan perniagaan, dan pencabutan Pasal 1380 ayat (2) Burgerlijk Wetboek | 11 | 1 | 7 |
| Stb. 1938 No. 380 | Perubahan Pasal 1149 angka 4 Burgerlijk Wetboek (disahkan 1 Juli 1938) | 1 | 0 | 0 |
| Stb. 1938 No. 622 | Penyederhanaan ketentuan mengenai tunjangan pemeliharaan yang terutang berdasarkan Burgerlijk Wetboek (disahkan 28 Oktober 1938) | 9 | 4 | 5 |
| Stb. 1939 No. 256 | Penetapan suatu peraturan kecelakaan ("Peraturan Kecelakaan 1939") (disahkan 8 Mei 1939) | 1 | 0 | 0 |
| Stb. 1939 No. 545 | Pengaturan mengenai pemulangan pekerja yang dipekerjakan atau direkrut di luar Hindia Belanda ("Peraturan Pemulangan Pekerja 1939") (disahkan 11 September 1939) | 1 | 0 | 0 |
| Stb. 1939 No. 546 | Pengaturan mengenai jangka waktu pemberitahuan pengakhiran untuk perjanjian kerja yang dibuat untuk waktu tidak tertentu (disahkan 11 September 1939) | 5 | 2 | 0 |
| UU 23/2006 | Administrasi Kependudukan | 0 | 0 | 18 |

## Sumber

1. Teks terstruktur: https://www.datahukum.com/peraturan/STB_23_Tahun_1847-bw.html (pihak ketiga, bukan sumber resmi)

Tidak ada naskah resmi berbahasa Indonesia untuk dibandingkan, jadi kolom `cakupan_*_pdf` kosong.
Pemeriksaan otomatis yang dipakai: semua versi rumusan dipindai untuk sisa teks penerjemah atau chatbot
("Berikut terjemahannya", "File ini", markdown), kata ganti percakapan, kata Belanda yang tertinggal, judul
pasal lain di dalam isi, dan butir ayat/huruf kosong. Temuan ditandai `perlu_review`. Perbaikan per pasal
ada di `text_fixes` (4 perbaikan). Kesalahan terjemahan yang halus tidak bisa dideteksi otomatis.

## Cara import

1. Admin dashboard → menu `Undang-Undang`. Pastikan ada UU kode `KUHPER`:
   - Nama: `Kitab Undang-Undang Hukum Perdata`
   - Nama lengkap: `Kitab Undang-Undang Hukum Perdata (Burgerlijk Wetboek, Staatsblad 1847 Nomor 23)`
   - Tahun: `1847`
   - Link naskah resmi: kosongkan (tidak ada naskah resmi berbahasa Indonesia)
   - Sumber teks: `https://www.datahukum.com/peraturan/STB_23_Tahun_1847-bw.html`
2. Menu `Import Data` → mode XLSX → pilih UU `KUHPER` → upload file xlsx.
3. Import memakai `updateOrCreate` per (UU, nomor): pasal yang sudah ada akan ditimpa,
   pasal lain di UU yang sama tidak dihapus.
4. Nomor disimpan tanpa awalan "Pasal" (contoh `1`, `99a`). Data lama dengan nomor `Pasal 1`
   tidak akan tertimpa dan jadi dobel, jadi hapus dulu pasal lama sebelum import.
5. Pasal baru atau yang teksnya berubah masuk menu `Verifikasi` dengan status "Perlu verifikasi".
   Admin mencocokkan tiap pasal dengan naskah resmi lalu menekan "Verifikasi". Sebelum itu pasal
   tetap tampil di mobile dengan label "Belum diverifikasi admin".

Catatan tampilan: normalizer import menggabungkan anak kalimat penutup setelah daftar huruf
(misalnya "..., pidananya dapat ditambah 1/3") ke butir huruf terakhir. Isi teks tetap lengkap.

## Perlu dicek manual (0 pasal)

| Pasal | Catatan |
|---|---|
| - | - |
