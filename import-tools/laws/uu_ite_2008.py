"""UU ITE: UU Nomor 11 Tahun 2008, dikonsolidasi dengan UU 19/2016, UU 1/2024, dan UU 1/2026.

Daftar perubahan dibaca dari bagian Riwayat HTML datahukum; metadata dan PDF resminya dikoreksi
lewat `amendment_overrides` (tanggal dan link JDIH BPK, dicek 2026-11-08).

Versi UU 1/2026 di HTML datahukum keliru (mencabut ayat yang tidak disebut, misalnya Pasal 28 ayat (1)
dan Pasal 45 ayat (2), (4)-(7), dan memakai kembali rumusan UU 19/2016 untuk Pasal 45A ayat (1) dan
Pasal 45B). Versi itu diabaikan dan disusun ulang dari naskah UU 1/2026 lewat `_derive_2026`.
"""

import re

from datahukum_pipeline import CatatanRule, LawConfig

_UU_2024 = "Undang-Undang Nomor 1 Tahun 2024 tentang Perubahan Kedua atas Undang-Undang Nomor 11 Tahun 2008"

# Putusan MK yang tercatat di JDIH BPK untuk UU 11/2008 dan UU 1/2024 (dicek 2026-11-08). Amar
# dikutip dari salinan putusan (peraturan.bpk.go.id/DownloadUjiMateri).
_MK_20_2016 = (
    "Catatan Putusan MK Nomor 20/PUU-XIV/2016: frasa \"Informasi Elektronik dan/atau Dokumen Elektronik\" "
    "dalam Pasal 5 ayat (1) dan ayat (2) serta Pasal 44 huruf b UU 11/2008 bertentangan dengan UUD 1945 dan "
    "tidak mempunyai kekuatan hukum mengikat sepanjang tidak dimaknai khususnya frasa \"Informasi Elektronik "
    "dan/atau Dokumen Elektronik\" sebagai alat bukti dilakukan dalam rangka penegakan hukum atas permintaan "
    "kepolisian, kejaksaan, dan/atau institusi penegak hukum lainnya yang ditetapkan berdasarkan undang-undang "
    "sebagaimana ditentukan dalam Pasal 31 ayat (3) UU 11/2008."
)
_MK_105_2024_27A = (
    "Catatan Putusan MK Nomor 105/PUU-XXII/2024: dalam Pasal 27A dan Pasal 45 ayat (4) UU 1/2024, frasa "
    "\"orang lain\" bertentangan dengan UUD 1945 dan tidak mempunyai kekuatan hukum mengikat secara bersyarat "
    "sepanjang tidak dimaknai \"kecuali lembaga pemerintah, sekelompok orang dengan identitas spesifik atau "
    "tertentu, institusi, korporasi, profesi atau jabatan\"; frasa \"suatu hal\" bertentangan dengan UUD 1945 "
    "dan tidak mempunyai kekuatan hukum mengikat secara bersyarat sepanjang tidak dimaknai \"suatu perbuatan "
    "yang merendahkan kehormatan atau nama baik seseorang\"."
)
_MK_105_2024_28 = (
    "Catatan Putusan MK Nomor 105/PUU-XXII/2024: dalam Pasal 28 ayat (2) dan Pasal 45A ayat (2) UU 1/2024, frasa "
    "\"mendistribusikan dan/atau mentransmisikan informasi elektronik dan/atau dokumen elektronik yang sifatnya "
    "menghasut, mengajak, atau memengaruhi orang lain sehingga menimbulkan rasa kebencian atau permusuhan "
    "terhadap individu dan/atau kelompok masyarakat tertentu\" bertentangan dengan UUD 1945 dan tidak mempunyai "
    "kekuatan hukum mengikat secara bersyarat sepanjang tidak dimaknai \"hanya Informasi Elektronik dan/atau "
    "Dokumen Elektronik yang secara substantif memuat tindakan/penyebaran kebencian berdasar identitas tertentu "
    "yang dilakukan secara sengaja dan di depan umum, yang menimbulkan risiko nyata terhadap diskriminasi, "
    "permusuhan, atau kekerasan\"."
)
_MK_115_2024 = (
    "Catatan Putusan MK Nomor 115/PUU-XXII/2024: kata \"kerusuhan\" dalam Pasal 28 ayat (3) dan Pasal 45A ayat (3) "
    "UU 1/2024 bertentangan dengan UUD 1945 dan tidak mempunyai kekuatan hukum mengikat secara bersyarat "
    "sepanjang tidak dimaknai \"kerusuhan adalah kondisi yang mengganggu ketertiban umum di ruang fisik, bukan "
    "kondisi di ruang digital/siber\"."
)
MK_NOTES = {
    "5": _MK_20_2016,
    "44": _MK_20_2016,
    "27A": _MK_105_2024_27A,
    # Pasal 45 hanya terkena putusan 105/PUU-XXII/2024 lewat ayat (4).
    "45": _MK_105_2024_27A,
    "28": f"{_MK_105_2024_28}\n{_MK_115_2024}",
    "45A": f"{_MK_105_2024_28}\n{_MK_115_2024}",
}

# UU 1/2026 (daftar ketentuan yang dicabut, halaman 41-43 salinan JDIH BPK): dicabut "Pasal 27 ayat (1), Pasal 27
# ayat (3), Pasal 28 ayat (2), Pasal 30, Pasal 31 ayat (1), Pasal 31 ayat (2), Pasal 36, Pasal 45 ayat (1),
# Pasal 45 ayat (3), Pasal 45A ayat (2), Pasal 46, Pasal 47, dan Pasal 51 ayat (2) UU 11/2008 sebagaimana telah
# beberapa kali diubah terakhir dengan UU 1/2024". Pasal 27 tidak lagi punya ayat (3) sejak UU 1/2024, jadi
# bagian itu tidak mengenai ayat mana pun.
REPEALED_PASAL = ("30", "36", "46", "47")
REPEALED_AYAT = {"27": ("1", "3"), "28": ("2",), "31": ("1", "2"), "45": ("1", "3"), "45A": ("2",), "51": ("2",)}

# Lampiran UU 1/2026 (angka 56 untuk UU 11/2008, angka 182 untuk UU 1/2024): ancaman pidana setelah penyesuaian.
# Kunci ayat "" = pasal tanpa ayat.
PENYESUAIAN = {
    "48": {
        "1": "dipidana dengan pidana penjara paling lama 8 (delapan) tahun dan/atau pidana denda paling banyak kategori V",
        "2": "dipidana dengan pidana penjara paling lama 9 (sembilan) tahun dan/atau pidana denda paling banyak kategori VI",
        "3": "dipidana dengan pidana penjara paling lama 10 (sepuluh) tahun dan/atau pidana denda paling banyak kategori VI",
    },
    "49": {"": "dipidana dengan pidana penjara paling lama 10 (sepuluh) tahun dan/atau pidana denda paling banyak kategori VI"},
    "50": {"": "dipidana dengan pidana penjara paling lama 10 (sepuluh) tahun dan/atau pidana denda paling banyak kategori VI"},
    "51": {"1": "dipidana dengan pidana penjara paling lama 12 (dua belas) tahun dan/atau pidana denda paling banyak kategori VII"},
    "45": {
        "8": "dipidana dengan pidana penjara paling lama 6 (enam) tahun dan/atau pidana denda paling banyak kategori V",
        "10": "dipidana dengan pidana penjara paling lama 6 (enam) tahun dan/atau pidana denda paling banyak kategori V",
    },
    "45A": {"1": "dipidana dengan pidana penjara paling lama 6 (enam) tahun dan/atau pidana denda paling banyak kategori V"},
    "45B": {"": "dipidana dengan pidana penjara paling lama 4 (empat) tahun dan/atau pidana denda paling banyak kategori IV"},
}

_AYAT = re.compile(r"^\((\d+)\)\s")
_ANCAMAN = re.compile(r"dipidana dengan pidana penjara paling lama (\d+ \([a-z ]+\) tahun) dan/atau denda paling banyak Rp\s?[\d.,lI]+ \([^)]*rupiah\)")


def _blocks(isi: str) -> list[tuple[str, list[str]]]:
    """Pisahkan isi per ayat: [(nomor ayat atau "", baris)]; butir huruf ikut ayat di atasnya."""
    blocks: list[tuple[str, list[str]]] = []
    for line in isi.split("\n"):
        match = _AYAT.match(line)
        if match or not blocks:
            blocks.append((match.group(1) if match else "", [line]))
        else:
            blocks[-1][1].append(line)
    return blocks


def _derive_2026(nomor: str, isi: str) -> str | None:
    """Rumusan setelah UU 1/2026: ayat yang dicabut jadi "Dicabut.", ancaman denda jadi kategori."""
    revoked = REPEALED_AYAT.get(nomor, ())
    adjusted = PENYESUAIAN.get(nomor, {})
    if not revoked and not adjusted:
        return None
    out = []
    seen: set[str] = set()
    for ayat, lines in _blocks(isi):
        seen.add(ayat)
        if ayat in revoked:
            out.append(f"({ayat}) Dicabut.")
            continue
        text = "\n".join(lines)
        if ayat in adjusted:
            match = _ANCAMAN.search(text)
            new = adjusted[ayat]
            if match is None or match.group(1) not in new:
                raise ValueError(f"UU 1/2026 Pasal {nomor} ayat ({ayat or '-'}): ancaman pidana lama tidak dikenali")
            text = text[: match.start()] + new + text[match.end() :]
        out.append(text)
    expected = set(adjusted) | set(revoked)
    if nomor == "27":
        expected.discard("3")  # lihat catatan penomoran di atas REPEALED_PASAL
    missing = expected - seen
    if missing:
        raise ValueError(f"UU 1/2026 Pasal {nomor}: ayat {sorted(missing)} tidak ditemukan")
    return "\n".join(out)


# Penomoran ayat di UU 1/2026 berasal dari UU 19/2016. Dalam rumusan UU 1/2024, Pasal 27 tidak punya
# ayat (3) dan Pasal 45 ayat (3) mengatur ancaman perjudian, jadi pencabutannya perlu dicek.
CATATAN_RULES = (
    CatatanRule(
        "UU 1/2026 mencabut Pasal 27 ayat (1) dan ayat (3) serta Pasal 45 ayat (1) dan ayat (3) UU ITE "
        "sebagaimana diubah terakhir dengan UU 1/2024. Penomoran itu mengikuti UU 19/2016: dalam rumusan "
        "UU 1/2024, Pasal 27 tidak lagi punya ayat (3) dan Pasal 45 ayat (3) memuat ancaman pidana perjudian. "
        "Periksa naskah resmi UU 1/2026 sebelum memakai ketentuan ini.",
        nomor=("27", "45"),
    ),
)

# Artefak OCR di HTML datahukum untuk UU ini (dicek ke PDF BPK UU 11/2008, UU 19/2016, UU 1/2024).
OCR_FIXES = (
    ("\u0131", "i"),  # ı: "Sertifıkasi", "verifıkasi"
    ("\u00cd", "t"),  # Í: "KeÍentuan", "SisÍem", "juÍa"
    ("\u011f", "gj"),  # ğ: "dipertanggunğawabkan"
    ("\u044a", ""),  # ъ: "ъintuk"
    ("-?\u00ac-?", "-"),  # ¬: "Undang¬Undang", "Perundang¬-undangan"
    (r"\n?TAMBAHAN LEMBARAN NEGARA REPUBLIK INDONESIA NOMOR \d+", ""),
    (r"\n?Agar setiap orang mengetahuinya, memerintahkan pengundangan[^\n]*", ""),
)

# Typo per versi: (class versi, kolom, teks salah, teks benar). Setiap entri dicek ke PDF resmi versi
# itu (2026-11-08). Versi UU 1/2026 disusun dari versi UU 1/2024 yang sudah diperbaiki.
VERSION_FIXES: dict[str, list[tuple[str, str, str, str]]] = {
    "1": [
        ("uu-192016", "isi", "eiectronic data interchonpe", "electronic data interchange"),
        ("uu-192016", "isi", "surat elektronik\n!electronic mni9,", "surat elektronik (electronic mail),"),
        ("uu-192016", "isi", "yang bempa kode", "yang berupa kode"),
        ("uu-192016", "isi", "subjek hakum", "subjek hukum"),
    ],
    "5": [("uu-12024", "penjelasan", "danJ atau", "dan/atau")],
    "6": [("uu-112008", "penjelasan", "termasuk medial elektronik", "termasuk media elektronik")],
    "13": [("uu-12024", "isi", "untuk pemboatan", "untuk pembuatan")],
    "13A": [
        ("uu-12024", "isi", "danJ atau", "dan/atau"),
        ("uu-12024", "penjelasan", "bukti lerkait", "bukti terkait"),
    ],
    "15": [("uu-12024", "penjelasan", "memenohi", "memenuhi")],
    "16A": [
        ("uu-12024", "isi", "pelindongan", "pelindungan"),
        ("uu-12024", "penjelasan", "dan fAur yang", "dan fitur yang"),
        ("uu-12024", "penjelasan", "maupon psikis", "maupun psikis"),
    ],
    "16B": [("uu-12024", "isi", "semenlara", "sementara")],
    "17": [("uu-12024", "isi", "Seriifikat", "Sertifikat")],
    "18": [("uu-112008", "penjelasan", "menekankan panda tempat", "menekankan pada tempat")],
    "18A": [
        ("uu-12024", "isi", "Transalxsi", "Transaksi"),
        ("uu-12024", "penjelasan", "klausola baku", "klausula baku"),
    ],
    "23": [("uu-112008", "isi", "harus di dasarkan", "harus didasarkan")],
    "26": [
        ("uu-192016", "isi", "pemndang-undangan", "perundang-undangan"),
        ("uu-192016", "penjelasan", "pribadi mempakan", "pribadi merupakan"),
    ],
    "27": [
        ("uu-12024", "isi", "memperlunjukkan", "mempertunjukkan"),
        ("uu-12024", "penjelasan", "disesoaikan", "disesuaikan"),
        ("uu-12024", "penjelasan", "oleh kompulan orang", "oleh kumpulan orang"),
    ],
    "40": [
        ("uu-192016", "isi", "Dokomen Elektronik", "Dokumen Elektronik"),
        ("uu-192016", "penjelasan", "masyarakat has,", "masyarakat luas,"),
        ("uu-12024", "isi", "perundang-ondangan", "perundang-undangan"),
        ("uu-12024", "penjelasan", "Cokup jelas", "Cukup jelas"),
    ],
    "40A": [
        ("uu-12024", "penjelasan", "penambahan fltur", "penambahan fitur"),
        ("uu-12024", "penjelasan", "me ujudkan", "mewujudkan"),
    ],
    "42": [("uu-112008", "isi", "dimaksud. dalam", "dimaksud dalam")],
    "43": [
        ("uu-192016", "isi", "saksi sehobungan", "saksi sehubungan"),
        ("uu-12024", "isi", "kepada Penontut Umum", "kepada Penuntut Umum"),
        ("uu-12024", "isi", "yang patot diduga", "yang patut diduga"),
        ("uu-12024", "isi", "bekerja sanna", "bekerja sama"),
        ("uu-12024", "penjelasan", "bidang komonikasi", "bidang komunikasi"),
    ],
    "45": [
        ("uu-12024", "isi", "ilmo pengetahuan", "ilmu pengetahuan"),
        ("uu-12024", "isi", "kehormatan atas nama baik", "kehormatan atau nama baik"),
        ("uu-12024", "isi", "(empat) tahon", "(empat) tahun"),
        ("uu-12024", "isi", "mengyntungkan", "menguntungkan"),
        ("uu-12024", "penjelasan", "dilakukan intuk kepentingan", "dilakukan untuk kepentingan"),
    ],
    # Rumusan UU 1/2024 di HTML menomori ayat kedua sebagai "(3)" (li value="3"); PDF resmi: ayat (2).
    "45A": [
        ("uu-192016", "isi", "Rpl.000.000.000,00", "Rp1.000.000.000,00"),
        ("uu-192016", "isi", "mengakibatkan kemgian", "mengakibatkan kerugian"),
        (
            "uu-12024",
            "isi",
            "(3) Setiap Orang yang dengan sengaja dan tanpa hak mendistribusikan",
            "(2) Setiap Orang yang dengan sengaja dan tanpa hak mendistribusikan",
        ),
    ],
    "45B": [
        (
            "uu-192016",
            "penjelasan",
            "!cyber btt!Iying) yang mengandurig susar ancaman kekerasan atau meriakut-nakuti",
            "(cyber bullying) yang mengandung unsur ancaman kekerasan atau menakut-nakuti",
        ),
    ],
}

TEXT_FIXES: dict[str, list[tuple[str, str, str]]] = {}

# Pasal berskor rendah yang sudah dicek kata per kata ke PDF (2026-11-08). PDF UU 19/2016 dan UU 1/2024
# adalah hasil scan; selisih yang tersisa berasal dari OCR PDF ("dimalsud", "bagr", "tqjuh") atau dari
# penjelasan yang di PDF dipenggal antarhalaman, bukan dari teks kita.
MANUAL_REVIEW: dict[str, str] = {
    nomor: "Dicek manual: selisih berasal dari OCR PDF perubahan, teks sudah sesuai"
    for nomor in ("1", "5", "13", "13A", "15", "16A", "16B", "18A", "26", "27A", "27B", "28", "29", "40", "40A", "43", "45")
}

CONFIG = LawConfig(
    slug="uu-ite-2008",
    xlsx_name="01_uu_ite_2008_konsolidasi_ready.xlsx",
    kode="UU-ITE",
    label="UU 11/2008",
    nama="Undang-Undang Informasi dan Transaksi Elektronik",
    nama_lengkap="Undang-Undang Nomor 11 Tahun 2008 tentang Informasi dan Transaksi Elektronik",
    tahun=2008,
    datahukum_url="https://www.datahukum.com/peraturan/UU_11_Tahun_2008.html",
    bpk_detail_url="https://peraturan.bpk.go.id/Details/37589/uu-no-11-tahun-2008",
    bpk_pdf_url="https://peraturan.bpk.go.id/Download/26683/UU%20Nomor%2011%20Tahun%202008.pdf",
    doc_class="uu-112008",
    body_pages=(1, 25),
    penjelasan_pages=(26, 38),
    # Pasal 54 ayat (1): mulai berlaku pada tanggal diundangkan.
    diundangkan="2008-04-21",
    berlaku_sejak="2008-04-21",
    amendments_from_html=True,
    amendment_overrides={
        "uu-192016": {
            "full_title": "Undang-Undang Nomor 19 Tahun 2016 tentang Perubahan atas Undang-Undang Nomor 11 Tahun 2008 "
            "tentang Informasi dan Transaksi Elektronik",
            "official_url": "https://peraturan.bpk.go.id/Details/37582/uu-no-19-tahun-2016",
            "diundangkan": "2016-11-25",
            "berlaku_sejak": "2016-11-25",
            "pdf": "uu-nomor-19-tahun-2016.pdf",
            "pdf_url": "https://peraturan.bpk.go.id/Download/26676/UU%20Nomor%20%2019%20Tahun%202016.pdf",
        },
        "uu-12024": {
            "full_title": f"{_UU_2024} tentang Informasi dan Transaksi Elektronik",
            "official_url": "https://peraturan.bpk.go.id/Details/274494/uu-no-1-tahun-2024",
            "diundangkan": "2024-01-02",
            "berlaku_sejak": "2024-01-02",
            "pdf": "uu-nomor-1-tahun-2024.pdf",
            "pdf_url": "https://peraturan.bpk.go.id/Download/332870/UU%20Nomor%201%20Tahun%202024.pdf",
        },
        # Sama dengan konfigurasi KUHP: diundangkan 12 Januari 2026, berlaku 2 Januari 2026. PDF-nya tidak
        # dipakai sebagai pembanding: UU 1/2026 memuat daftar pencabutan dan tabel ancaman, bukan rumusan pasal.
        "uu-12026": {
            "full_title": "Undang-Undang Nomor 1 Tahun 2026 tentang Penyesuaian Pidana",
            "official_url": "https://peraturan.bpk.go.id/Details/337869/uu-no-1-tahun-2026",
            "diundangkan": "2026-01-12",
            "berlaku_sejak": "2026-01-02",
            "repealed": REPEALED_PASAL,
            "derive": _derive_2026,
        },
    },
    repealed_text="Dicabut.",
    catatan_rules=CATATAN_RULES,
    mk_notes=MK_NOTES,
    text_fixes=TEXT_FIXES,
    version_fixes=VERSION_FIXES,
    ocr_fixes=OCR_FIXES,
    manual_review=MANUAL_REVIEW,
)
