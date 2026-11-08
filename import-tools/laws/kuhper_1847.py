"""KUHPerdata: Burgerlijk Wetboek (Staatsblad 1847 Nomor 23), terjemahan datahukum.com.

Teks yang berlaku secara hukum adalah naskah Belanda; tidak ada naskah resmi berbahasa Indonesia untuk
pembanding, jadi pemeriksaan otomatis hanya memindai sisa teks penerjemah dan kata asing. Status teks
disampaikan lewat fitur verifikasi admin (pasal tampil "Belum diverifikasi" sampai dicek).
Daftar perubahan (47 Staatsblad 1872-1939 dan UU 23/2006) diambil dari bagian Riwayat HTML.
Catatan CariPasal (status berlaku menurut UU yang lebih baru) ditambahkan di akhir penjelasan.
"""

from datahukum_pipeline import CatatanRule, LawConfig

# Pasal 66 UU 1/1974: ketentuan KUHPerdata tentang perkawinan "sejauh telah diatur dalam
# Undang-undang ini, dinyatakan tidak berlaku". UU Perkawinan mengatur perkawinan, hak dan kewajiban
# suami istri, harta benda, putusnya perkawinan, kedudukan anak, kekuasaan orang tua, dan perwalian.
PERKAWINAN = (
    "Pasal 66 UU 1/1974 tentang Perkawinan menyatakan ketentuan KUHPerdata tentang perkawinan tidak "
    "berlaku sejauh hal itu telah diatur dalam UU Perkawinan. Periksa UU 1/1974 (diubah UU 16/2019) "
    "sebelum memakai pasal ini."
)

# Diktum UU 5/1960 (UUPA) mencabut "Buku ke-II Kitab Undang-undang Hukum Perdata Indonesia sepanjang
# yang mengenai bumi, air serta kekayaan alam yang terkandung didalamnya, kecuali ketentuan-ketentuan
# mengenai hypotheek".
AGRARIA = (
    "UU 5/1960 tentang Peraturan Dasar Pokok-Pokok Agraria mencabut Buku II KUHPerdata sepanjang mengenai "
    "bumi, air, dan kekayaan alam yang terkandung di dalamnya, kecuali ketentuan hipotek. Untuk tanah, "
    "pasal ini tidak berlaku lagi; hak atas tanah diatur UUPA."
)
AGRARIA_TANAH = (
    "Bab ini mengatur hak dan kewajiban yang berkaitan dengan tanah. UU 5/1960 tentang Peraturan Dasar "
    "Pokok-Pokok Agraria mencabut Buku II KUHPerdata sepanjang mengenai bumi, air, dan kekayaan alam yang "
    "terkandung di dalamnya, sehingga ketentuan bab ini tidak berlaku lagi untuk tanah. Hak atas tanah "
    "sekarang diatur UUPA."
)

# Pasal 29 UU 4/1996: ketentuan Hypotheek dalam Buku II KUHPerdata "sepanjang mengenai pembebanan Hak
# Tanggungan pada hak atas tanah beserta benda-benda yang berkaitan dengan tanah dinyatakan tidak
# berlaku lagi".
HIPOTEK = (
    "Pasal 29 UU 4/1996 tentang Hak Tanggungan menyatakan ketentuan hipotek dalam Buku II KUHPerdata tidak "
    "berlaku lagi sepanjang mengenai pembebanan hak tanggungan pada hak atas tanah beserta benda yang "
    "berkaitan dengan tanah. Untuk hipotek kapal, lihat juga UU 17/2008 tentang Pelayaran."
)

KETENAGAKERJAAN = (
    "Hubungan kerja sekarang terutama diatur dalam UU 13/2003 tentang Ketenagakerjaan beserta "
    "perubahannya. Periksa undang-undang itu sebelum memakai pasal ini."
)

# SEMA 3/1963 menganggap pasal-pasal berikut tidak berlaku lagi. SEMA bukan undang-undang, jadi
# kedudukannya sebagai dasar pencabutan diperdebatkan; catatan ini hanya memberi tahu.
SEMA = (
    "Melalui SEMA Nomor 3 Tahun 1963, Mahkamah Agung menganggap {bagian} tidak berlaku lagi. SEMA bukan "
    "undang-undang, jadi kedudukannya sebagai dasar pencabutan masih diperdebatkan."
)
SEMA_PASAL = {
    "108": "pasal ini",
    "110": "pasal ini",
    "284": "ayat (3) pasal ini",
    "1238": "pasal ini",
    "1460": "pasal ini",
    "1579": "pasal ini",
    "1603x": "ayat (1) dan (2) pasal ini",
    "1682": "pasal ini",
}

CATATAN_RULES = (
    CatatanRule(
        PERKAWINAN,
        buku="BUKU KESATU",
        bab=("BAB IV", "BAB V", "BAB VI", "BAB VII", "BAB VIII", "BAB IX", "BAB X", "BAB XI", "BAB XII", "BAB XIV", "BAB XIVA", "BAB XV"),
    ),
    CatatanRule(AGRARIA_TANAH, buku="BUKU KEDUA", bab=("BAB IV", "BAB V", "BAB VI", "BAB VII", "BAB VIII", "BAB IX")),
    CatatanRule(AGRARIA, buku="BUKU KEDUA", bab=("BAB I", "BAB II", "BAB III", "BAB X", "BAB XI")),
    CatatanRule(HIPOTEK, buku="BUKU KEDUA", bab=("BAB XXI",)),
    CatatanRule(KETENAGAKERJAAN, buku="BUKU KETIGA", bab=("BAB VIIA",)),
    *(CatatanRule(SEMA.format(bagian=bagian), nomor=(nomor,)) for nomor, bagian in SEMA_PASAL.items()),
)

# Per pasal: (kolom, teks salah, teks benar). Skrip berhenti kalau teks salahnya tidak ditemukan.
TEXT_FIXES: dict[str, list[tuple[str, str, str]]] = {
    # Sisa jawaban chatbot penerjemah di sumber; Pasal 913-956 sendiri lengkap di HTML.
    "912": [
        (
            "isi",
            "\nBenar. File yang terakhir ini sebenarnya memuat Pasal 913 sampai Pasal 956. Jadi bagian itu "
            "terlewat. Berikut terjemahannya lengkap dari Pasal 913 sampai pasal terakhir dalam file, yaitu Pasal 956.",
            "",
        )
    ],
    # Judul "Ketentuan Penutup" dari sumber menempel di akhir isi pasal terakhir sebelum bab berikutnya.
    **{nomor: [("isi", "\nKetentuan Penutup", "")] for nomor in ("461", "568", "1992")},
}

CONFIG = LawConfig(
    slug="kuhper-1847",
    xlsx_name="01_kuhper_1847_ready.xlsx",
    kode="KUHPER",
    label="Stb. 1847 No. 23",
    nama="Kitab Undang-Undang Hukum Perdata",
    nama_lengkap="Kitab Undang-Undang Hukum Perdata (Burgerlijk Wetboek, Staatsblad 1847 Nomor 23)",
    tahun=1847,
    datahukum_url="https://www.datahukum.com/peraturan/STB_23_Tahun_1847-bw.html",
    doc_class="stb-231847-bw",
    # Diumumkan 30 April 1847, mulai berlaku 1 Mei 1848.
    diundangkan="1847-04-30",
    berlaku_sejak="1848-05-01",
    amendments_from_html=True,
    amendment_overrides={
        # Riwayat datahukum menulis 24 Desember 2006 dan LN 2013/232 (milik UU 24/2013).
        "uu-232006": {
            "full_title": "Undang-Undang Nomor 23 Tahun 2006 tentang Administrasi Kependudukan",
            "official_url": "https://peraturan.bpk.go.id/Details/40202/uu-no-23-tahun-2006",
            "diundangkan": "2006-12-29",
            "berlaku_sejak": "2006-12-29",
        },
    },
    repealed_text="Dicabut.",
    catatan_rules=CATATAN_RULES,
    text_fixes=TEXT_FIXES,
    no_link_bab_titles=frozenset(),
)
