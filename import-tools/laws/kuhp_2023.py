"""KUHP: UU Nomor 1 Tahun 2023, dikonsolidasi dengan UU Nomor 1 Tahun 2026 (Penyesuaian Pidana)."""

from datahukum_pipeline import Amendment, LawConfig

# Putusan MK yang tercatat di JDIH BPK untuk UU 1/2023 (dicek 2026-11-07).
MK_NOTES = {
    "220": (
        "Catatan Putusan MK Nomor 275/PUU-XXIII/2025: Pasal 220 ayat (1) bertentangan dengan UUD 1945 "
        "dan tidak mempunyai kekuatan hukum mengikat secara bersyarat sepanjang tidak dimaknai "
        '"(1) Tindak Pidana sebagaimana dimaksud dalam Pasal 218 dan Pasal 219 hanya dapat dituntut '
        'berdasarkan aduan oleh Presiden dan/atau Wakil Presiden".'
    ),
    "237": (
        "Catatan Putusan MK Nomor 27/PUU-XXIV/2026: Pasal 237 huruf c bertentangan dengan UUD 1945 "
        "dan tidak mempunyai kekuatan hukum mengikat."
    ),
}

# Typo per pasal: (kolom, teks salah, teks benar). Setiap entri sudah dicek ke PDF resmi
# (BPK untuk rumusan 2023, PDF UU 1/2026 untuk rumusan perubahan). Skrip berhenti
# kalau teks salahnya tidak ditemukan, supaya daftar ini tidak diam-diam basi.
TEXT_FIXES: dict[str, list[tuple[str, str, str]]] = {
    "3": [("isi", "sesuai dengan Tingkat pemeriksaan", "sesuai dengan tingkat pemeriksaan")],
    "46": [("penjelasan", "termasuk yang berkedudukan.\nberkedudukan sebagai", "termasuk yang berkedudukan sebagai")],
    "66": [
        ("isi", "pencabutan izin Tertentu", "pencabutan izin tertentu"),
        ("penjelasan", "perlindongan", "perlindungan"),
    ],
    "76": [
        ("penjelasan", 'Tindak Pidana iti"', 'Tindak Pidana itu"'),
        ("penjelasan", "pemasyarakalan", "pemasyarakatan"),
    ],
    "79": [
        ("penjelasan", "moneter. Penetapan tingkatan", "moneter.\nPenetapan tingkatan"),
        ("penjelasan", "\nc. Maksimum kategori denda", "\na. Maksimum kategori denda"),
        ("penjelasan", "\nd. Untuk kategori II adalah", "\nb. Untuk kategori II adalah"),
        ("penjelasan", "\ne. Untuk kategori V sampai", "\nc. Untuk kategori V sampai"),
    ],
    "81": [("penjelasan", "antara lain\u2022", "antara lain:")],
    "90": [
        ("isi", "\nKetentuan sebagaimana dimaksud pada ayat (1) huruf b", "\n(2) Ketentuan sebagaimana dimaksud pada ayat (1) huruf b"),
        ("isi", "\n(2) Pidana pencabutan hak mulai berlaku", "\n(3) Pidana pencabutan hak mulai berlaku"),
    ],
    "95": [("isi", "d\u00fbakukan", "dilakukan")],
    "103": [("isi", "dan/alan", "dan/atau")],
    "196": [("isi", "den\u011fan", "dengan")],
    "269": [("penjelasan", 'adalah hang atau ruang', 'adalah liang atau ruang')],
    "300": [("isi", "terlulis", "tertulis")],
    "407": [("penjelasan", "contemporariy", "contemporary")],
    "433": [("penjelasan", "kehormalan", "kehormatan")],
    "457": [("isi", "palsu, atar tanpa", "palsu, atau tanpa")],
    "473": [("isi", "memberi atar menjanjikan", "memberi atau menjanjikan")],
    "622": [
        ("isi", "Nomor O Tahun 2023", "Nomor 6 Tahun 2023"),
        ("isi", "tentang Pembahan atas", "tentang Perubahan atas"),
        ("isi", "dalam mtab Undang-Undang", "dalam Kitab Undang-Undang"),
        ("isi", "Nomor l3 Tahun 2006", "Nomor 13 Tahun 2006"),
        ("isi", "Tahun 2023 Nomor 4 1,", "Tahun 2023 Nomor 41,"),
        ("isi", "Nomor 49 19)", "Nomor 4919)"),
        ("isi", "Nomor S 164)", "Nomor 5164)"),
        ("isi", "6OD", "606"),
        ("isi", "\nCC. ", "\ncc. "),
    ],
}

# Pasal yang skor cakupannya rendah tapi sudah dicek manual terhadap PDF (2026-11-07).
# Selisihnya berasal dari OCR PDF (kata hilang di ujung baris rata kanan, huruf rusak).
MANUAL_REVIEW = {
    nomor: "Dicek manual: selisih berasal dari OCR PDF, teks sudah sesuai"
    for nomor in (
        "6", "25", "69", "82", "95", "120", "121", "196", "200", "203", "209",
        "269", "281", "296", "332", "353", "375", "382", "403", "407",
    )
}
MANUAL_REVIEW["90"] = "Dicek manual: penomoran ayat (2) dan (3) diperbaiki sesuai PDF UU 1/2026"


CONFIG = LawConfig(
    slug="kuhp-2023",
    xlsx_name="01_kuhp_2023_konsolidasi_ready.xlsx",
    kode="KUHP",
    label="UU 1/2023",
    nama="Kitab Undang-Undang Hukum Pidana",
    nama_lengkap="Undang-Undang Nomor 1 Tahun 2023 tentang Kitab Undang-Undang Hukum Pidana",
    tahun=2023,
    datahukum_url="https://www.datahukum.com/peraturan/UU_1_Tahun_2023.html",
    bpk_detail_url="https://peraturan.bpk.go.id/Details/234935/uu-no-1-tahun-2023",
    bpk_pdf_url="https://peraturan.bpk.go.id/Download/287456/UU%20Nomor%201%20Tahun%202023.pdf",
    doc_class="uu-12023",
    body_pages=(2, 229),
    penjelasan_pages=(230, 345),
    diundangkan="2023-01-02",
    berlaku_sejak="2026-01-02",
    amendments=(
        Amendment(
            doc_class="uu-12026",
            label="UU 1/2026",
            title="UU 1/2026 (Penyesuaian Pidana)",
            pdf="uu-nomor-1-tahun-2026.pdf",
            pdf_url="https://peraturan.bpk.go.id/Download/400929/UU%20Nomor%201%20Tahun%202026.pdf",
            full_title="Undang-Undang Nomor 1 Tahun 2026 tentang Penyesuaian Pidana",
            official_url="https://peraturan.bpk.go.id/Details/337869/uu-no-1-tahun-2026",
            diundangkan="2026-01-12",
            # Pasal IX UU 1/2026: mulai berlaku 2 Januari 2026, sama dengan KUHP.
            berlaku_sejak="2026-01-02",
            repealed=("615", "616"),
        ),
    ),
    mk_notes=MK_NOTES,
    text_fixes=TEXT_FIXES,
    manual_review=MANUAL_REVIEW,
)
