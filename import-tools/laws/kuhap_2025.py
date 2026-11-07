"""KUHAP: UU Nomor 20 Tahun 2025, berlaku 2 Januari 2026, mencabut UU Nomor 8 Tahun 1981."""

from datahukum_pipeline import LawConfig

# Typo per pasal: (kolom, teks salah, teks benar). Setiap entri sudah dicek ke PDF resmi BPK.
TEXT_FIXES: dict[str, list[tuple[str, str, str]]] = {}

# Pasal berskor rendah yang sudah dicek manual terhadap PDF BPK.
MANUAL_REVIEW: dict[str, str] = {}

CONFIG = LawConfig(
    slug="kuhap-2025",
    xlsx_name="01_kuhap_2025_ready.xlsx",
    kode="KUHAP",
    label="UU 20/2025",
    nama="Kitab Undang-Undang Hukum Acara Pidana",
    nama_lengkap="Undang-Undang Nomor 20 Tahun 2025 tentang Kitab Undang-Undang Hukum Acara Pidana",
    tahun=2025,
    datahukum_url="https://www.datahukum.com/peraturan/UU_20_Tahun_2025.html",
    bpk_detail_url="https://peraturan.bpk.go.id/Details/337302/uu-no-20-tahun-2025",
    bpk_pdf_url="https://peraturan.bpk.go.id/Download/400351/UU%20Nomor%2020%20Tahun%202025.pdf",
    doc_class="uu-202025",
    body_pages=(2, 184),
    penjelasan_pages=(185, 238),
    text_fixes=TEXT_FIXES,
    manual_review=MANUAL_REVIEW,
)
