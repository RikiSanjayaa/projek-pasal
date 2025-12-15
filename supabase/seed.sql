-- ============================================================================
-- CARIPASAL - Seed Data (Data Dummy)
-- Versi: 1.0.0
-- Tanggal: 2025-12-12
-- Deskripsi: Data dummy untuk testing dan development
-- ============================================================================

-- ============================================================================
-- INSERT UNDANG-UNDANG
-- ============================================================================

INSERT INTO undang_undang (id, kode, nama, nama_lengkap, deskripsi, tahun) VALUES
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'KUHP',
    'KUHP',
    'Kitab Undang-Undang Hukum Pidana',
    'Kitab Undang-Undang Hukum Pidana adalah peraturan perundang-undangan yang mengatur mengenai perbuatan pidana.',
    1946
),
(
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    'KUHPER',
    'KUHPer',
    'Kitab Undang-Undang Hukum Perdata',
    'Kitab Undang-Undang Hukum Perdata adalah peraturan yang mengatur hubungan hukum antara orang-orang dalam masyarakat.',
    1848
),
(
    'c3d4e5f6-a7b8-9012-cdef-123456789012',
    'KUHAP',
    'KUHAP',
    'Kitab Undang-Undang Hukum Acara Pidana',
    'Kitab Undang-Undang Hukum Acara Pidana mengatur tata cara penyelesaian perkara pidana.',
    1981
),
(
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    'UU_ITE',
    'UU ITE',
    'Undang-Undang Informasi dan Transaksi Elektronik',
    'Undang-Undang yang mengatur tentang informasi serta transaksi elektronik, atau teknologi informasi.',
    2008
);

-- ============================================================================
-- INSERT PASAL KUHP (Contoh)
-- ============================================================================

INSERT INTO pasal (undang_undang_id, nomor, judul, isi, penjelasan, keywords) VALUES

-- KUHP Pasal 1
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    '1',
    'Asas Legalitas',
    '(1) Suatu perbuatan tidak dapat dipidana, kecuali berdasarkan kekuatan ketentuan perundang-undangan pidana yang telah ada.
(2) Bilamana ada perubahan dalam perundang-undangan sesudah perbuatan dilakukan, maka terhadap terdakwa diterapkan ketentuan yang paling menguntungkannya.',
    'Pasal ini mengatur tentang asas legalitas dalam hukum pidana. Seseorang tidak dapat dipidana jika tidak ada undang-undang yang mengaturnya sebelum perbuatan tersebut dilakukan.',
    ARRAY['asas legalitas', 'perbuatan pidana', 'ketentuan perundang-undangan', 'terdakwa', 'perubahan undang-undang']
),

-- KUHP Pasal 340
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    '340',
    'Pembunuhan Berencana',
    'Barang siapa dengan sengaja dan dengan rencana terlebih dahulu merampas nyawa orang lain, diancam karena pembunuhan dengan rencana, dengan pidana mati atau pidana penjara seumur hidup atau selama waktu tertentu, paling lama dua puluh tahun.',
    'Pembunuhan berencana adalah pembunuhan yang dilakukan dengan perencanaan terlebih dahulu. Ancaman pidananya lebih berat daripada pembunuhan biasa.',
    ARRAY['pembunuhan', 'pembunuhan berencana', 'merampas nyawa', 'pidana mati', 'pidana penjara', 'seumur hidup']
),

-- KUHP Pasal 338
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    '338',
    'Pembunuhan',
    'Barang siapa dengan sengaja merampas nyawa orang lain, diancam karena pembunuhan dengan pidana penjara paling lama lima belas tahun.',
    'Pasal ini mengatur tentang pembunuhan biasa (tanpa perencanaan). Ancaman pidananya maksimal 15 tahun penjara.',
    ARRAY['pembunuhan', 'merampas nyawa', 'pidana penjara', 'sengaja']
),

-- KUHP Pasal 362
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    '362',
    'Pencurian',
    'Barang siapa mengambil barang sesuatu, yang seluruhnya atau sebagian kepunyaan orang lain, dengan maksud untuk dimiliki secara melawan hukum, diancam karena pencurian, dengan pidana penjara paling lama lima tahun atau pidana denda paling banyak sembilan ratus rupiah.',
    'Pasal ini mengatur tentang tindak pidana pencurian biasa.',
    ARRAY['pencurian', 'mengambil barang', 'melawan hukum', 'pidana penjara', 'denda']
),

-- KUHP Pasal 363
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    '363',
    'Pencurian dengan Pemberatan',
    '(1) Diancam dengan pidana penjara paling lama tujuh tahun:
1. pencurian ternak;
2. pencurian pada waktu ada kebakaran, letusan, banjir gempa bumi, atau gempa laut, gunung meletus, kapal karam, kapal terdampar, kecelakaan kereta api, huru-hara, pemberontakan atau bahaya perang;
3. pencurian di waktu malam dalam sebuah rumah atau pekarangan tertutup yang ada rumahnya, yang dilakukan oleh orang yang ada di situ tidak diketahui atau tidak dikehendaki oleh yang berhak;
4. pencurian yang dilakukan oleh dua orang atau lebih;
5. pencurian yang untuk masuk ke tempat melakukan kejahatan, atau untuk sampai pada barang yang diambil, dilakukan dengan merusak, memotong atau memanjat, atau dengan memakai anak kunci palsu, perintah palsu atau pakaian jabatan palsu.',
    'Pencurian dengan pemberatan adalah pencurian yang disertai keadaan-keadaan yang memberatkan.',
    ARRAY['pencurian', 'pemberatan', 'ternak', 'malam hari', 'merusak', 'memanjat', 'anak kunci palsu']
),

-- KUHP Pasal 372
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    '372',
    'Penggelapan',
    'Barang siapa dengan sengaja dan melawan hukum memiliki barang sesuatu yang seluruhnya atau sebagian adalah kepunyaan orang lain, tetapi yang ada dalam kekuasaannya bukan karena kejahatan diancam karena penggelapan, dengan pidana penjara paling lama empat tahun atau pidana denda paling banyak sembilan ratus rupiah.',
    'Penggelapan adalah memiliki barang yang sudah dalam kekuasaannya secara sah tetapi kemudian dimiliki secara melawan hukum.',
    ARRAY['penggelapan', 'memiliki barang', 'melawan hukum', 'kepercayaan', 'pidana penjara']
),

-- KUHP Pasal 378
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    '378',
    'Penipuan',
    'Barang siapa dengan maksud untuk menguntungkan diri sendiri atau orang lain secara melawan hukum, dengan memakai nama palsu atau martabat palsu, dengan tipu muslihat, ataupun rangkaian kebohongan, menggerakkan orang lain untuk menyerahkan barang sesuatu kepadanya, atau supaya memberi hutang rnaupun menghapuskan piutang diancam karena penipuan dengan pidana penjara paling lama empat tahun.',
    'Penipuan adalah perbuatan untuk menguntungkan diri sendiri dengan cara menipu orang lain.',
    ARRAY['penipuan', 'tipu muslihat', 'kebohongan', 'nama palsu', 'menguntungkan diri', 'pidana penjara']
);

-- ============================================================================
-- INSERT PASAL KUHPER (Contoh)
-- ============================================================================

INSERT INTO pasal (undang_undang_id, nomor, judul, isi, penjelasan, keywords) VALUES

-- KUHPer Pasal 1320
(
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    '1320',
    'Syarat Sah Perjanjian',
    'Untuk sahnya suatu perjanjian diperlukan empat syarat:
1. sepakat mereka yang mengikatkan dirinya;
2. kecakapan untuk membuat suatu perikatan;
3. suatu hal tertentu;
4. suatu sebab yang halal.',
    'Pasal ini mengatur tentang empat syarat sahnya suatu perjanjian yang harus dipenuhi agar perjanjian tersebut memiliki kekuatan hukum.',
    ARRAY['perjanjian', 'syarat sah', 'sepakat', 'kecakapan', 'perikatan', 'sebab halal', 'kontrak']
),

-- KUHPer Pasal 1365
(
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    '1365',
    'Perbuatan Melawan Hukum',
    'Tiap perbuatan melanggar hukum, yang membawa kerugian kepada seorang lain, mewajibkan orang yang karena salahnya menerbitkan kerugian itu, mengganti kerugian tersebut.',
    'Pasal ini mengatur tentang perbuatan melawan hukum (onrechtmatige daad) yang mewajibkan pelaku untuk mengganti kerugian yang ditimbulkan.',
    ARRAY['perbuatan melawan hukum', 'kerugian', 'ganti rugi', 'onrechtmatige daad', 'tanggung jawab']
),

-- KUHPer Pasal 1234
(
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    '1234',
    'Jenis Perikatan',
    'Tiap-tiap perikatan adalah untuk memberikan sesuatu, untuk berbuat sesuatu, atau untuk tidak berbuat sesuatu.',
    'Pasal ini menjelaskan tiga jenis prestasi dalam suatu perikatan.',
    ARRAY['perikatan', 'prestasi', 'memberikan', 'berbuat', 'tidak berbuat']
),

-- KUHPer Pasal 1338
(
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    '1338',
    'Kebebasan Berkontrak',
    'Semua perjanjian yang dibuat secara sah berlaku sebagai undang-undang bagi mereka yang membuatnya. Suatu perjanjian tidak dapat ditarik kembali selain dengan sepakat kedua belah pihak, atau karena alasan-alasan yang oleh undang-undang dinyatakan cukup untuk itu. Suatu perjanjian harus dilaksanakan dengan itikad baik.',
    'Pasal ini mengatur tentang asas kebebasan berkontrak dan kekuatan mengikat perjanjian.',
    ARRAY['perjanjian', 'kontrak', 'kebebasan berkontrak', 'undang-undang', 'itikad baik', 'pacta sunt servanda']
),

-- KUHPer Pasal 1381
(
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    '1381',
    'Hapusnya Perikatan',
    'Perikatan-perikatan hapus:
1. karena pembayaran;
2. karena penawaran pembayaran tunai, diikuti dengan penyimpanan atau penitipan;
3. karena pembaharuan utang;
4. karena perjumpaan utang atau kompensasi;
5. karena percampuran utang;
6. karena pembebasan utangnya;
7. karena musnahnya barang yang terutang;
8. karena kebatalan atau pembatalan;
9. karena berlakunya suatu syarat batal;
10. karena lewatnya waktu.',
    'Pasal ini mengatur tentang cara-cara hapusnya suatu perikatan.',
    ARRAY['perikatan', 'hapus', 'pembayaran', 'kompensasi', 'pembebasan utang', 'pembatalan', 'daluwarsa']
);

-- ============================================================================
-- INSERT PASAL KUHAP (Contoh)
-- ============================================================================

INSERT INTO pasal (undang_undang_id, nomor, judul, isi, penjelasan, keywords) VALUES

-- KUHAP Pasal 1 angka 1
(
    'c3d4e5f6-a7b8-9012-cdef-123456789012',
    '1 angka 1',
    'Definisi Penyidik',
    'Penyidik adalah pejabat polisi negara Republik Indonesia atau pejabat pegawai negeri sipil tertentu yang diberi wewenang khusus oleh undang-undang untuk melakukan penyidikan.',
    'Pasal ini memberikan definisi tentang siapa yang dimaksud dengan penyidik.',
    ARRAY['penyidik', 'polisi', 'pegawai negeri sipil', 'penyidikan', 'definisi']
),

-- KUHAP Pasal 1 angka 2
(
    'c3d4e5f6-a7b8-9012-cdef-123456789012',
    '1 angka 2',
    'Definisi Penyidikan',
    'Penyidikan adalah serangkaian tindakan penyidik dalam hal dan menurut cara yang diatur dalam undang-undang ini untuk mencari serta mengumpulkan bukti yang dengan bukti itu membuat terang tentang tindak pidana yang terjadi dan guna menemukan tersangkanya.',
    'Pasal ini memberikan definisi tentang apa yang dimaksud dengan penyidikan.',
    ARRAY['penyidikan', 'bukti', 'tindak pidana', 'tersangka', 'definisi']
),

-- KUHAP Pasal 21
(
    'c3d4e5f6-a7b8-9012-cdef-123456789012',
    '21',
    'Penahanan',
    '(1) Perintah penahanan atau penahanan lanjutan dilakukan terhadap seorang tersangka atau terdakwa yang diduga keras melakukan tindak pidana berdasarkan bukti yang cukup, dalam hal adanya keadaan yang menimbulkan kekhawatiran bahwa tersangka atau terdakwa akan melarikan diri, merusak atau menghilangkan barang bukti dan atau mengulangi tindak pidana.',
    'Pasal ini mengatur tentang syarat-syarat untuk melakukan penahanan terhadap tersangka atau terdakwa.',
    ARRAY['penahanan', 'tersangka', 'terdakwa', 'bukti', 'melarikan diri', 'barang bukti']
),

-- KUHAP Pasal 77
(
    'c3d4e5f6-a7b8-9012-cdef-123456789012',
    '77',
    'Praperadilan',
    'Pengadilan negeri berwenang untuk memeriksa dan memutus, sesuai dengan ketentuan yang diatur dalam undang-undang ini tentang:
a. sah atau tidaknya penangkapan, penahanan, penghentian penyidikan atau penghentian penuntutan;
b. ganti kerugian dan atau rehabilitasi bagi seorang yang perkara pidananya dihentikan pada tingkat penyidikan atau penuntutan.',
    'Pasal ini mengatur tentang kewenangan praperadilan dalam memeriksa tindakan aparat penegak hukum.',
    ARRAY['praperadilan', 'pengadilan negeri', 'penangkapan', 'penahanan', 'penghentian penyidikan', 'ganti kerugian', 'rehabilitasi']
),

-- KUHAP Pasal 183
(
    'c3d4e5f6-a7b8-9012-cdef-123456789012',
    '183',
    'Minimal Dua Alat Bukti',
    'Hakim tidak boleh menjatuhkan pidana kepada seorang kecuali apabila dengan sekurang-kurangnya dua alat bukti yang sah ia memperoleh keyakinan bahwa suatu tindak pidana benar-benar terjadi dan bahwa terdakwalah yang bersalah melakukannya.',
    'Pasal ini mengatur tentang pembuktian minimal dalam hukum acara pidana.',
    ARRAY['alat bukti', 'pembuktian', 'hakim', 'keyakinan', 'terdakwa', 'minimal dua alat bukti']
);

-- ============================================================================
-- INSERT PASAL UU ITE (Contoh)
-- ============================================================================

INSERT INTO pasal (undang_undang_id, nomor, judul, isi, penjelasan, keywords) VALUES

-- UU ITE Pasal 27 ayat (1)
(
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    '27 ayat (1)',
    'Muatan Asusila',
    'Setiap Orang dengan sengaja dan tanpa hak mendistribusikan dan/atau mentransmisikan dan/atau membuat dapat diaksesnya Informasi Elektronik dan/atau Dokumen Elektronik yang memiliki muatan yang melanggar kesusilaan.',
    'Pasal ini mengatur tentang larangan mendistribusikan konten asusila melalui media elektronik.',
    ARRAY['informasi elektronik', 'dokumen elektronik', 'asusila', 'kesusilaan', 'distribusi', 'transmisi']
),

-- UU ITE Pasal 27 ayat (3)
(
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    '27 ayat (3)',
    'Penghinaan dan/atau Pencemaran Nama Baik',
    'Setiap Orang dengan sengaja dan tanpa hak mendistribusikan dan/atau mentransmisikan dan/atau membuat dapat diaksesnya Informasi Elektronik dan/atau Dokumen Elektronik yang memiliki muatan penghinaan dan/atau pencemaran nama baik.',
    'Pasal ini mengatur tentang larangan penghinaan dan pencemaran nama baik melalui media elektronik.',
    ARRAY['penghinaan', 'pencemaran nama baik', 'informasi elektronik', 'dokumen elektronik', 'defamasi']
),

-- UU ITE Pasal 28 ayat (1)
(
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    '28 ayat (1)',
    'Berita Bohong yang Merugikan Konsumen',
    'Setiap Orang dengan sengaja dan tanpa hak menyebarkan berita bohong dan menyesatkan yang mengakibatkan kerugian konsumen dalam Transaksi Elektronik.',
    'Pasal ini mengatur tentang larangan menyebarkan berita bohong dalam transaksi elektronik yang merugikan konsumen.',
    ARRAY['berita bohong', 'hoax', 'konsumen', 'transaksi elektronik', 'kerugian']
),

-- UU ITE Pasal 28 ayat (2)
(
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    '28 ayat (2)',
    'Ujaran Kebencian (SARA)',
    'Setiap Orang dengan sengaja dan tanpa hak menyebarkan informasi yang ditujukan untuk menimbulkan rasa kebencian atau permusuhan individu dan/atau kelompok masyarakat tertentu berdasarkan atas suku, agama, ras, dan antargolongan (SARA).',
    'Pasal ini mengatur tentang larangan ujaran kebencian berbasis SARA melalui media elektronik.',
    ARRAY['ujaran kebencian', 'hate speech', 'SARA', 'suku', 'agama', 'ras', 'permusuhan']
),

-- UU ITE Pasal 30
(
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    '30',
    'Akses Ilegal',
    '(1) Setiap Orang dengan sengaja dan tanpa hak atau melawan hukum mengakses Komputer dan/atau Sistem Elektronik milik Orang lain dengan cara apa pun.
(2) Setiap Orang dengan sengaja dan tanpa hak atau melawan hukum mengakses Komputer dan/atau Sistem Elektronik dengan cara apa pun dengan tujuan untuk memperoleh Informasi Elektronik dan/atau Dokumen Elektronik.
(3) Setiap Orang dengan sengaja dan tanpa hak atau melawan hukum mengakses Komputer dan/atau Sistem Elektronik dengan cara apa pun dengan melanggar, menerobos, melampaui, atau menjebol sistem pengamanan.',
    'Pasal ini mengatur tentang larangan akses ilegal terhadap sistem komputer atau sistem elektronik.',
    ARRAY['akses ilegal', 'hacking', 'komputer', 'sistem elektronik', 'melawan hukum', 'menerobos', 'sistem pengamanan']
),

-- UU ITE Pasal 32
(
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    '32',
    'Gangguan Data',
    '(1) Setiap Orang dengan sengaja dan tanpa hak atau melawan hukum dengan cara apa pun mengubah, menambah, mengurangi, melakukan transmisi, merusak, menghilangkan, memindahkan, menyembunyikan suatu Informasi Elektronik dan/atau Dokumen Elektronik milik Orang lain atau milik publik.',
    'Pasal ini mengatur tentang larangan melakukan gangguan terhadap data elektronik milik orang lain.',
    ARRAY['gangguan data', 'merusak data', 'mengubah data', 'informasi elektronik', 'dokumen elektronik', 'data manipulation']
);

-- ============================================================================
-- INSERT PASAL LINKS (Contoh Relasi Antar Pasal)
-- ============================================================================

-- Ambil ID pasal yang akan di-link
DO $$
DECLARE
    pasal_338_id UUID;
    pasal_340_id UUID;
    pasal_362_id UUID;
    pasal_363_id UUID;
    pasal_1320_id UUID;
    pasal_1338_id UUID;
BEGIN
    -- Ambil ID
    SELECT id INTO pasal_338_id FROM pasal WHERE nomor = '338' AND undang_undang_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
    SELECT id INTO pasal_340_id FROM pasal WHERE nomor = '340' AND undang_undang_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
    SELECT id INTO pasal_362_id FROM pasal WHERE nomor = '362' AND undang_undang_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
    SELECT id INTO pasal_363_id FROM pasal WHERE nomor = '363' AND undang_undang_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
    SELECT id INTO pasal_1320_id FROM pasal WHERE nomor = '1320' AND undang_undang_id = 'b2c3d4e5-f6a7-8901-bcde-f12345678901';
    SELECT id INTO pasal_1338_id FROM pasal WHERE nomor = '1338' AND undang_undang_id = 'b2c3d4e5-f6a7-8901-bcde-f12345678901';
    
    -- Insert links
    INSERT INTO pasal_links (source_pasal_id, target_pasal_id, keterangan) VALUES
    (pasal_340_id, pasal_338_id, 'Lihat juga pasal pembunuhan biasa'),
    (pasal_338_id, pasal_340_id, 'Lihat juga pasal pembunuhan berencana'),
    (pasal_363_id, pasal_362_id, 'Bentuk dasar pencurian'),
    (pasal_362_id, pasal_363_id, 'Bentuk pemberatan'),
    (pasal_1338_id, pasal_1320_id, 'Syarat sah perjanjian');
END $$;

-- ============================================================================
-- END OF SEED DATA
-- ============================================================================
