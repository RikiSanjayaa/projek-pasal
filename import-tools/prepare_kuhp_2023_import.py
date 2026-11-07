"""Siapkan file import KUHP (UU Nomor 1 Tahun 2023) untuk Bulk Import admin.

Sumber teks:
- datahukum.com: HTML terstruktur (buku/bab/bagian/paragraf, ayat, huruf, penjelasan)
  yang memuat rumusan asli UU 1/2023 dan rumusan setelah diubah UU 1/2026.
- JDIH BPK: PDF salinan resmi UU 1/2023 (hasil scan + OCR), dipakai sebagai pembanding.

Output (data-import/kuhp-2023/):
- 01_kuhp_2023_konsolidasi_ready.xlsx  sheet "import" siap upload, sheet "review" hasil cek.
- README_IMPORT.md                      cara import + daftar pasal yang perlu dicek manual.

Jalankan:
    python -m venv .venv && .venv/bin/pip install pymupdf openpyxl beautifulsoup4
    .venv/bin/python import-tools/prepare_kuhp_2023_import.py
"""

from __future__ import annotations

import difflib
import html
import re
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

import pymupdf
from bs4 import BeautifulSoup, Tag
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill


ROOT = Path(__file__).resolve().parents[1]
CACHE_DIR = Path(__file__).resolve().parent / ".cache"
OUTPUT_DIR = ROOT / "data-import" / "kuhp-2023"

DATAHUKUM_URL = "https://www.datahukum.com/peraturan/UU_1_Tahun_2023.html"
BPK_DETAIL_URL = "https://peraturan.bpk.go.id/Details/234935/uu-no-1-tahun-2023"
BPK_PDF_URL = "https://peraturan.bpk.go.id/Download/287456/UU%20Nomor%201%20Tahun%202023.pdf"
UU_2026_PDF = ROOT / "uu-nomor-1-tahun-2026.pdf"

# Halaman PDF BPK (1-based): batang tubuh 2-229, penjelasan 230-345.
PDF_BODY_PAGES = (2, 229)
PDF_PENJELASAN_PAGES = (230, 345)

UU_RECORD = {
    "kode": "KUHP",
    "nama": "Kitab Undang-Undang Hukum Pidana",
    "nama_lengkap": "Undang-Undang Nomor 1 Tahun 2023 tentang Kitab Undang-Undang Hukum Pidana",
    "tahun": 2023,
}

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

# Typo OCR yang berulang pada rumusan UU 1/2026 di sumber HTML.
OCR_FIXES = {
    r"\bbarn\b": "baru",
    r"\bbam\b": "baru",
}

# Typo per pasal: (kolom, teks salah, teks benar). Setiap entri sudah dicek ke PDF resmi
# (BPK untuk rumusan 2023, uu-nomor-1-tahun-2026.pdf untuk rumusan perubahan). Skrip berhenti
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

SMALL_WORDS = {
    "dan", "atau", "yang", "di", "ke", "dari", "dalam", "untuk", "oleh", "dengan", "tentang",
    "pada", "bagi", "serta", "terhadap", "atas", "sebagai", "secara", "tanpa", "kepada",
}

REVIEW_COVERAGE_THRESHOLD = 0.90


@dataclass
class Heading:
    kind: str
    label: str
    title: str


@dataclass
class PasalRecord:
    nomor: str
    order: int
    headings: list[Heading]
    isi: str
    penjelasan: str
    status: str
    original_isi: str = ""
    original_penjelasan: str = ""
    notes: list[str] = field(default_factory=list)


def fetch(url: str, path: Path) -> Path:
    if path.exists() and path.stat().st_size > 0:
        return path
    path.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (CariPasal import tool)"})
    with urllib.request.urlopen(request, timeout=120) as response:
        path.write_bytes(response.read())
    return path


def squash(text: str) -> str:
    text = html.unescape(text).replace("\u00a0", " ")
    text = text.replace("\u201c", '"').replace("\u201d", '"').replace("\u2018", "'").replace("\u2019", "'")
    return re.sub(r"\s+", " ", text).strip()


class TextCleaner:
    """Gabungkan pemenggalan kata ("perundang- undangan") memakai kosakata korpus sendiri."""

    def __init__(self, corpus: str) -> None:
        self.vocab = {w.lower() for w in re.findall(r"[A-Za-z]+", re.sub(r"\w+- \w+", " ", corpus))}

    def __call__(self, text: str) -> str:
        text = squash(text)
        for pattern, replacement in OCR_FIXES.items():
            text = re.sub(pattern, replacement, text)

        def join(match: re.Match[str]) -> str:
            left, right = match.group(1), match.group(2)
            if (left + right).lower() in self.vocab:
                return left + right
            return f"{left}-{right}"

        text = re.sub(r"([A-Za-z]+)- ([A-Za-z]+)", join, text)
        text = re.sub(r"\s+([,.;:])", r"\1", text)
        text = re.sub(r"(\w)/ (\w)", r"\1/\2", text)
        text = re.sub(r"\( ", "(", text)
        text = re.sub(r" \)", ")", text)
        return text


def list_marker(ol: Tag, index: int, li: Tag) -> str:
    raw_value = li.get("value")
    number = int(raw_value) if raw_value and str(raw_value).isdigit() else index + 1
    if ol.get("type") == "a":
        return f"{chr(ord('a') + number - 1)}."
    if "ayat-list" in ol.get("class", []):
        return f"({number})"
    return f"{number}."


BLOCK_TAGS = {"p", "ol", "ul", "div", "section", "h4"}


def render_flow(container: Tag, clean: TextCleaner) -> list[str]:
    """Ubah HTML pasal/penjelasan jadi baris teks: satu baris per paragraf, ayat, huruf, atau angka."""
    lines: list[str] = []
    inline: list[str] = []

    def flush() -> None:
        text = clean(" ".join(inline))
        inline.clear()
        if text:
            lines.append(text)

    for child in container.children:
        if not isinstance(child, Tag):
            inline.append(str(child))
            continue
        if child.name not in BLOCK_TAGS:
            inline.append(child.get_text(" "))
            continue
        flush()
        classes = child.get("class", [])
        if child.name == "h4" or "penjelasan-label" in classes:
            continue
        if child.name == "div" and "penjelasan-block" in classes:
            label_tag = child.find("p", class_="penjelasan-label", recursive=False)
            label = clean(label_tag.get_text(" ")) if label_tag else ""
            body = render_flow(child, clean)
            if label and body:
                lines.append(f"{label} {body[0]}")
                lines.extend(body[1:])
            elif label:
                lines.append(label)
            else:
                lines.extend(body)
        elif child.name in {"ol", "ul"}:
            lines.extend(render_ol(child, clean))
        elif child.name == "p":
            text = clean(child.get_text(" "))
            if text:
                lines.append(text)
        else:
            lines.extend(render_flow(child, clean))
    flush()
    return lines


def render_ol(ol: Tag, clean: TextCleaner) -> list[str]:
    lines: list[str] = []
    for index, li in enumerate(ol.find_all("li", recursive=False)):
        item = render_flow(li, clean)
        marker = list_marker(ol, index, li)
        if item:
            lines.append(f"{marker} {item[0]}")
            lines.extend(item[1:])
        else:
            lines.append(marker)
    return lines


PENJELASAN_LABEL_AT_END = re.compile(r"^(.*[.:;])\s+(Ayat \(\d+[a-z]?\)|Huruf [a-z]{1,2}|Angka \d+[a-z]?)$")
LIST_MARKER = re.compile(r"^(\(\d+[a-z]?\)|[a-z]{1,2}\.|\d+\.)(\s|$)")


def tidy_lines(lines: list[str]) -> list[str]:
    """Perbaiki salah potong di sumber HTML.

    - Label penjelasan yang menempel di ujung paragraf sebelumnya ("... relatif. Huruf a")
      dipindah ke awal baris berikutnya.
    - Kata yang terpotong di tanda hubung ("Undang-" / "Undang ini") disambung.
    - Kalimat yang terpotong jadi dua paragraf (baris sebelumnya tidak diakhiri tanda baca,
      baris berikutnya diawali huruf kecil dan bukan butir) disambung lagi.
    """
    result: list[str] = []
    carry = ""
    for line in lines:
        if carry:
            line = f"{carry} {line}"
            carry = ""
        label = PENJELASAN_LABEL_AT_END.match(line)
        if label:
            line, carry = label.group(1), label.group(2)
        if result and re.search(r"\w-$", result[-1]) and line[:1].isalpha():
            result[-1] = f"{result[-1]}{line}"
        elif result and line[:1].islower() and not LIST_MARKER.match(line) and not re.search(r"[.:;,]$", result[-1]):
            result[-1] = f"{result[-1]} {line}"
        else:
            result.append(line)
    if carry:
        result.append(carry)
    return result


def render_section(parent: Tag | None, doc_class: str, clean: TextCleaner) -> str:
    section = parent.find("section", class_=doc_class, recursive=False) if parent else None
    return "\n".join(tidy_lines(render_flow(section, clean))) if section else ""


def letters(text: str) -> str:
    return re.sub(r"[^a-z0-9]", "", text.lower())



def parse_heading(tag: Tag) -> Heading:
    header = tag.find(["h1", "h2", "h3", "h4"], recursive=False)
    text = squash(header.get_text(" ")) if header else ""
    label, _, title = text.partition(" - ")
    kind = {"buku": "buku", "bab": "bab", "bag": "bagian", "para": "paragraf"}[tag["class"][0]]
    return Heading(kind=kind, label=label.strip(), title=title.strip())


def parse_datahukum(path: Path) -> list[PasalRecord]:
    soup = BeautifulSoup(path.read_text(encoding="utf-8"), "html.parser")
    clean = TextCleaner(soup.select_one("div.batangtubuh").get_text(" "))
    headings = {tag["data-node-id"]: parse_heading(tag) for tag in soup.select("div.buku, div.bab, div.bag, div.para")}
    parents = {
        tag["data-node-id"]: tag.get("data-parent-id", "")
        for tag in soup.select("div.buku, div.bab, div.bag, div.para")
    }

    records = []
    for order, pasal in enumerate(soup.select("div.pasal")):
        nomor = squash(pasal.select_one(".pasal-header h5").get_text(" ")).removeprefix("Pasal ").strip()

        chain = []
        parent = pasal.get("data-parent-id", "")
        while parent:
            chain.append(headings[parent])
            parent = parents.get(parent, "")
        chain.reverse()
        if not chain and records:
            # Pasal sisipan (599A) tidak punya induk di HTML; ikut struktur pasal sebelumnya.
            chain = list(records[-1].headings)

        content = pasal.select_one("div.content")
        explanation = pasal.select_one("div.penjelasan")
        isi_original = render_section(content, "uu-12023", clean)
        isi_amended = render_section(content, "uu-12026", clean)
        pj_original = render_section(explanation, "uu-12023", clean)
        pj_amended = render_section(explanation, "uu-12026", clean)

        # Sumber HTML menyalin ulang isi pasal ke versi 2026 walau yang diubah hanya penjelasannya.
        isi_changed = bool(isi_original and isi_amended) and letters(isi_original) != letters(isi_amended)
        pj_changed = bool(pj_amended) and letters(pj_original) != letters(pj_amended)
        if isi_amended and not isi_original:
            status = "disisipkan UU 1/2026"
        elif isi_changed and pj_changed:
            status = "isi & penjelasan diubah UU 1/2026"
        elif isi_changed:
            status = "isi diubah UU 1/2026"
        elif pj_changed:
            status = "penjelasan diubah UU 1/2026"
        else:
            status = "asli UU 1/2023"

        fields = {
            "isi": isi_amended if (isi_changed or not isi_original) else isi_original,
            "penjelasan": pj_amended if pj_changed else pj_original,
        }
        for column, wrong, right in TEXT_FIXES.get(nomor, []):
            if wrong not in fields[column]:
                raise ValueError(f"TEXT_FIXES Pasal {nomor}: {wrong!r} tidak ditemukan di {column}")
            fields[column] = fields[column].replace(wrong, right)
        isi, penjelasan = fields["isi"], fields["penjelasan"]
        if nomor in MK_NOTES:
            penjelasan = f"{penjelasan}\n{MK_NOTES[nomor]}".strip()

        records.append(
            PasalRecord(
                nomor=nomor,
                order=order,
                headings=chain,
                isi=isi,
                penjelasan=penjelasan,
                status=status,
                original_isi=isi_original,
                original_penjelasan=pj_original,
                notes=[MK_NOTES[nomor].split(":")[0]] if nomor in MK_NOTES else [],
            )
        )
    return records


# --- Pembanding PDF resmi -------------------------------------------------------------

PDF_HEADER = re.compile(r"^\s*Pa\s?[s5]\s?a\s?[l1I|i]\s+([0-9lIOoSB]{1,3})\s*([A-Z])?\s*$")


def ocr_digits(value: str) -> str:
    return value.translate(str.maketrans({"l": "1", "I": "1", "i": "1", "O": "0", "o": "0", "S": "5", "B": "8"}))


@dataclass
class PdfIndex:
    lines: list[str]
    starts: dict[str, int]

    def __post_init__(self) -> None:
        self.folded = ocr_fold("\n".join(self.lines))

    def window(self, nomor: str, order: list[str], spread: int = 2) -> str:
        """Teks PDF sekitar pasal (beberapa header sebelum/sesudah) karena urutan OCR kadang melompat."""
        position = order.index(nomor)
        before = [order[i] for i in range(max(0, position - spread), position + 1) if order[i] in self.starts]
        after = next((order[i] for i in range(position + spread + 1, len(order)) if order[i] in self.starts), None)
        start = self.starts[before[0]] if before else 0
        end = self.starts[after] if after else len(self.lines)
        return "\n".join(self.lines[start:end])

    def chunk(self, nomor: str, order: list[str]) -> list[str] | None:
        """Baris dari header pasal ini sampai header pasal berikutnya, kalau keduanya terbaca."""
        position = order.index(nomor)
        if position + 1 >= len(order) or nomor not in self.starts or order[position + 1] not in self.starts:
            return None
        return self.lines[self.starts[nomor] : self.starts[order[position + 1]]]


def index_pdf(pages: list[str], expected: list[str]) -> PdfIndex:
    lines = [line.strip() for line in "\n".join(pages).split("\n")]
    headers = []
    for number, line in enumerate(lines):
        match = PDF_HEADER.match(line)
        if match:
            headers.append((number, ocr_digits(match.group(1)) + (match.group(2) or "")))

    starts: dict[str, int] = {}
    cursor = 0
    for nomor in expected:
        probe = cursor
        while probe < len(headers) and probe < cursor + 8 and headers[probe][1] != nomor:
            probe += 1
        if probe < len(headers) and headers[probe][1] == nomor:
            starts[nomor] = headers[probe][0]
            cursor = probe + 1
    return PdfIndex(lines=lines, starts=starts)


def char_coverage(ours: str, official: str) -> float:
    """Porsi huruf teks kita yang ditemukan berurutan di teks PDF (spasi/tanda baca diabaikan)."""
    a, b = letters(ours), letters(official)
    if not a:
        return 1.0
    matcher = difflib.SequenceMatcher(None, a, b, autojunk=False)
    return sum(block.size for block in matcher.get_matching_blocks()) / len(a)


OCR_CONFUSABLE = str.maketrans({"1": "l", "i": "l", "0": "o", "5": "s"})


def ocr_fold(text: str) -> str:
    """Huruf/angka saja, dengan karakter yang sering tertukar OCR (1/l/I, 0/O, 5/S) disamakan."""
    return letters(text).translate(OCR_CONFUSABLE)


def fragment_coverage(ours: str, haystack_folded: str, size: int = 25, step: int = 40) -> float:
    """Porsi potongan teks kita yang muncul persis di mana saja dalam PDF."""
    text = ocr_fold(ours)
    if len(text) <= size:
        return 1.0 if text in haystack_folded else 0.0
    fragments = [text[i : i + size] for i in range(0, len(text) - size + 1, step)]
    return sum(1 for fragment in fragments if fragment in haystack_folded) / len(fragments)


def official_coverage(ours: str, pdf: PdfIndex, nomor: str, order: list[str]) -> float:
    if not ours:
        return 1.0
    return max(char_coverage(ours, pdf.window(nomor, order)), fragment_coverage(ours, pdf.folded))


def title_score(title: str, lines: list[str]) -> float:
    """Porsi judul yang muncul sebagai potongan panjang (>= 8 huruf) di baris PDF."""
    target = re.sub(r"[^a-z]", "", title.lower())
    haystack = re.sub(r"[^a-z]", "", " ".join(lines).lower())
    matcher = difflib.SequenceMatcher(None, target, haystack, autojunk=False)
    matched = sum(block.size for block in matcher.get_matching_blocks() if block.size >= 8)
    return matched / max(1, len(target))


def fix_heading_placement(records: list[PasalRecord], body: PdfIndex) -> dict[str, str]:
    """Sumber HTML kadang menaruh judul bab/bagian/paragraf satu pasal terlambat.

    Judul untuk pasal F tercetak di ekor potongan pasal sebelumnya (F-1). Kalau judul itu tidak ada
    di ekor F-1 tapi ada di ekor F-2, berarti judul sebenarnya dimulai di F-1: pindahkan F-1.
    Pemindahan hanya dilakukan kalau judul lama F-1 tetap punya pasal lain.
    """
    order = [r.nomor for r in records]
    fixes: dict[str, str] = {}
    for position in range(2, len(records)):
        record, previous, before_previous = records[position], records[position - 1], records[position - 2]
        for level, heading in enumerate(record.headings):
            if level < len(previous.headings) and previous.headings[level] == heading:
                continue
            if heading.kind == "buku" or not heading.title:
                break
            if previous.headings[: level + 1] != before_previous.headings[: level + 1]:
                break
            tail_prev = body.chunk(previous.nomor, order)
            tail_prev2 = body.chunk(before_previous.nomor, order)
            if tail_prev is None or tail_prev2 is None:
                break
            here = title_score(heading.title, tail_prev[-10:])
            earlier = title_score(heading.title, tail_prev2[-10:])
            if here < 0.6 and earlier >= 0.85:
                previous.headings = record.headings[: level + 1]
                fixes[previous.nomor] = f"Judul {heading.label} '{heading.title}' dipindah ke Pasal {previous.nomor} sesuai PDF"
            break
    return fixes


# --- Output ---------------------------------------------------------------------------


def title_case(text: str) -> str:
    words = text.lower().split()
    return " ".join(w if (i and w in SMALL_WORDS) else w[:1].upper() + w[1:] for i, w in enumerate(words))


def judul_for(record: PasalRecord) -> str:
    for heading in reversed(record.headings):
        if heading.kind in {"paragraf", "bagian", "bab"} and heading.title:
            return heading.title if heading.kind != "bab" else title_case(heading.title)
    return ""


def keywords_for(record: PasalRecord) -> str:
    words = ["KUHP 2023"]
    bab = next((h for h in record.headings if h.kind == "bab"), None)
    if bab:
        # Koma adalah pemisah keyword di format import, jadi dibuang dari judul bab.
        words.append(title_case(bab.title).lower().replace(",", ""))
    if record.status != "asli UU 1/2023":
        words.append("UU 1 2026")
    return ", ".join(words)


def write_xlsx(path: Path, records: list[PasalRecord], review: list[dict[str, object]]) -> None:
    wb = Workbook()
    ws = wb.active
    ws.title = "import"
    headers = ["nomor", "judul", "isi", "penjelasan", "keywords"]
    ws.append(headers)
    for record in records:
        ws.append([record.nomor, judul_for(record), record.isi, record.penjelasan, keywords_for(record)])

    review_ws = wb.create_sheet("review")
    review_headers = ["nomor", "status_teks", "bab", "cakupan_isi_pdf", "cakupan_penjelasan_pdf", "perlu_review", "catatan"]
    review_ws.append(review_headers)
    for row in review:
        review_ws.append([row[h] for h in review_headers])

    meta = wb.create_sheet("catatan")
    meta.append(["Judul", UU_RECORD["nama_lengkap"] + " (konsolidasi dengan UU 1/2026)"])
    meta.append(["Jumlah pasal", len(records)])
    meta.append(["Sumber teks", DATAHUKUM_URL])
    meta.append(["Pembanding resmi", BPK_DETAIL_URL])
    meta.append(["Catatan", "Upload sheet pertama ('import') lewat menu Import Data. Pilih UU kode KUHP sebelum import."])

    header_fill = PatternFill("solid", fgColor="1F4E78")
    for sheet in (ws, review_ws):
        for cell in sheet[1]:
            cell.font = Font(bold=True, color="FFFFFF")
            cell.fill = header_fill
            cell.alignment = Alignment(horizontal="center")
        for row in sheet.iter_rows(min_row=2):
            for cell in row:
                cell.alignment = Alignment(vertical="top", wrap_text=True)
        sheet.freeze_panes = "A2"
    for column, width in {"A": 10, "B": 48, "C": 90, "D": 70, "E": 42}.items():
        ws.column_dimensions[column].width = width
    for column, width in {"A": 10, "B": 22, "C": 48, "D": 16, "E": 20, "F": 12, "G": 90}.items():
        review_ws.column_dimensions[column].width = width
    meta.column_dimensions["A"].width = 20
    meta.column_dimensions["B"].width = 100

    path.parent.mkdir(parents=True, exist_ok=True)
    wb.save(path)


def write_readme(records: list[PasalRecord], review: list[dict[str, object]]) -> None:
    flagged = [row for row in review if row["perlu_review"] == "ya"]
    isi_changed = [r.nomor for r in records if r.status.startswith("isi")]
    pj_changed = [r.nomor for r in records if r.status == "penjelasan diubah UU 1/2026"]
    inserted = [r.nomor for r in records if r.status == "disisipkan UU 1/2026"]
    flagged_lines = "\n".join(f"| {row['nomor']} | {row['catatan']} |" for row in flagged) or "| - | - |"
    readme = f"""# Import KUHP (UU Nomor 1 Tahun 2023)

File ini dibuat oleh `import-tools/prepare_kuhp_2023_import.py`. Jangan edit manual; perbaiki
skripnya lalu jalankan ulang.

## Isi

- `01_kuhp_2023_konsolidasi_ready.xlsx`
  - sheet `import`: {len(records)} pasal (Pasal 1 sampai 624 ditambah Pasal 599A).
  - sheet `review`: hasil pembandingan tiap pasal dengan PDF resmi JDIH BPK.
- Teks sudah dikonsolidasi dengan UU 1/2026 (Penyesuaian Pidana):
  - isi pasal diubah ({len(isi_changed)}): {", ".join(isi_changed)}
  - hanya penjelasan diubah ({len(pj_changed)}): {", ".join(pj_changed)}
  - pasal sisipan ({len(inserted)}): {", ".join(inserted)}
- `judul` diisi judul paragraf/bagian/bab tempat pasal berada (KUHP tidak punya judul per pasal).
- `penjelasan` diisi penjelasan resmi. Pasal 220 dan 237 diberi catatan Putusan MK.
- `keywords`: `KUHP 2023`, judul bab, dan `UU 1 2026` untuk pasal yang tersentuh perubahan.

## Sumber

1. Teks terstruktur: {DATAHUKUM_URL} (pihak ketiga, bukan sumber resmi)
2. Pembanding resmi: {BPK_DETAIL_URL} (PDF salinan, hasil scan/OCR)
3. Rumusan perubahan: `uu-nomor-1-tahun-2026.pdf` (Penyesuaian Pidana)

Kesalahan sumber HTML yang diperbaiki skrip: butir ayat/huruf yang hilang, label penjelasan yang
menempel ke paragraf lain, judul bagian yang tergeser satu pasal (dicek ke PDF), dan typo OCR pada
rumusan UU 1/2026 (`TEXT_FIXES`, tiap entri dicek ke PDF).

`cakupan_*_pdf` = porsi huruf pada teks kita yang ditemukan di PDF resmi (rumusan asli dicek ke PDF
BPK, rumusan perubahan ke PDF UU 1/2026). Nilai di bawah {REVIEW_COVERAGE_THRESHOLD:.0%} atau butir
ayat/huruf yang kosong ditandai `perlu_review`. PDF resmi adalah hasil scan, jadi skor rendah biasanya
berasal dari OCR PDF (kata hilang di ujung baris). Pasal dengan skor rendah yang sudah dicek manual
tercatat di `MANUAL_REVIEW` dan kolom `catatan`.

## Cara import

1. Admin dashboard → menu `Undang-Undang`. Pastikan ada UU kode `{UU_RECORD['kode']}`:
   - Nama: `{UU_RECORD['nama']}`
   - Nama lengkap: `{UU_RECORD['nama_lengkap']}`
   - Tahun: `{UU_RECORD['tahun']}`
2. Menu `Import Data` → mode XLSX → pilih UU `KUHP` → upload file xlsx.
3. Import memakai `updateOrCreate` per (UU, nomor): pasal yang sudah ada akan ditimpa,
   pasal lain di UU yang sama tidak dihapus.
4. Nomor disimpan tanpa awalan "Pasal" (contoh `1`, `599A`). Data lama dengan nomor `Pasal 1`
   tidak akan tertimpa dan jadi dobel, jadi hapus dulu pasal KUHP lama sebelum import.

Catatan tampilan: normalizer import menggabungkan anak kalimat penutup setelah daftar huruf
(misalnya "..., pidananya dapat ditambah 1/3") ke butir huruf terakhir. Isi teks tetap lengkap.

## Perlu dicek manual ({len(flagged)} pasal)

| Pasal | Catatan |
|---|---|
{flagged_lines}
"""
    (OUTPUT_DIR / "README_IMPORT.md").write_text(readme, encoding="utf-8")


def main() -> None:
    html_path = fetch(DATAHUKUM_URL, CACHE_DIR / "datahukum_uu_1_2023.html")
    pdf_path = fetch(BPK_PDF_URL, CACHE_DIR / "bpk_uu_1_2023.pdf")
    if not UU_2026_PDF.exists():
        raise FileNotFoundError(f"PDF UU 1/2026 tidak ditemukan: {UU_2026_PDF}")

    records = parse_datahukum(html_path)
    original_order = [r.nomor for r in records if r.status != "disisipkan UU 1/2026"]

    pdf = pymupdf.open(pdf_path)
    pages = [page.get_text() for page in pdf]
    body = index_pdf(pages[PDF_BODY_PAGES[0] - 1 : PDF_BODY_PAGES[1]], original_order)
    explanation = index_pdf(pages[PDF_PENJELASAN_PAGES[0] - 1 : PDF_PENJELASAN_PAGES[1]], original_order)
    uu_2026_folded = ocr_fold("\n".join(page.get_text() for page in pymupdf.open(UU_2026_PDF)))
    heading_fixes = fix_heading_placement(records, body)

    review = []
    for record in records:
        notes = list(record.notes)
        if record.nomor in heading_fixes:
            notes.append(heading_fixes[record.nomor])

        # Bandingkan rumusan asli 2023 dengan PDF BPK, rumusan baru dengan PDF UU 1/2026.
        if record.original_isi:
            isi_cov = official_coverage(record.original_isi, body, record.nomor, original_order)
        else:
            isi_cov = 1.0
        if record.status.startswith("isi") or record.status == "disisipkan UU 1/2026":
            amended = fragment_coverage(record.isi, uu_2026_folded)
            notes.append(f"Isi versi UU 1/2026 cocok {amended:.0%} dengan PDF UU 1/2026")
            isi_cov = min(isi_cov, amended)

        if record.original_penjelasan:
            pj_cov = official_coverage(record.original_penjelasan, explanation, record.nomor, original_order)
        else:
            pj_cov = 1.0
        if "penjelasan" in record.status or (record.status == "disisipkan UU 1/2026" and record.penjelasan):
            amended = fragment_coverage(record.penjelasan, uu_2026_folded)
            notes.append(f"Penjelasan versi UU 1/2026 cocok {amended:.0%} dengan PDF UU 1/2026")
            pj_cov = min(pj_cov, amended)

        if re.search(r"^(\(\d+[a-z]?\)|[a-z]\.|\d+\.)$", record.isi + "\n" + record.penjelasan, re.M):
            notes.append("Ada butir ayat/huruf kosong")
        low = min(isi_cov, pj_cov) < REVIEW_COVERAGE_THRESHOLD
        if low:
            notes.append("Cakupan teks terhadap PDF rendah")
        empty_item = "Ada butir ayat/huruf kosong" in notes
        needs_review = low or empty_item
        if record.nomor in MANUAL_REVIEW:
            notes.append(MANUAL_REVIEW[record.nomor])
            needs_review = empty_item
        bab = next((h for h in record.headings if h.kind == "bab"), None)
        review.append(
            {
                "nomor": record.nomor,
                "status_teks": record.status,
                "bab": f"{bab.label} {title_case(bab.title)}" if bab else "",
                "cakupan_isi_pdf": round(isi_cov, 3),
                "cakupan_penjelasan_pdf": round(pj_cov, 3),
                "perlu_review": "ya" if needs_review else "tidak",
                "catatan": "; ".join(notes),
            }
        )

    write_xlsx(OUTPUT_DIR / "01_kuhp_2023_konsolidasi_ready.xlsx", records, review)
    write_readme(records, review)

    flagged = sum(1 for row in review if row["perlu_review"] == "ya")
    print(f"Output: {OUTPUT_DIR}")
    print(f"Pasal: {len(records)} | perlu review: {flagged}")
    print(f"Header pasal terbaca di PDF: batang tubuh {len(body.starts)}, penjelasan {len(explanation.starts)}")


if __name__ == "__main__":
    main()
