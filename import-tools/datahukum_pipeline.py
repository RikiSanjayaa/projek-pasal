"""Mesin import undang-undang dari datahukum.com untuk Bulk Import admin.

Alur per undang-undang (lihat konfigurasi di `laws/`):
1. Ambil HTML terstruktur datahukum.com (buku/bab/bagian/paragraf, ayat, huruf, penjelasan).
2. Kalau UU pernah diubah, pakai rumusan versi perubahan yang tersedia di HTML yang sama.
3. Bandingkan tiap pasal dengan PDF resmi JDIH BPK (hasil scan + OCR) dan PDF UU perubahan.
4. Tulis xlsx siap upload (sheet `import`), hasil cek (sheet `review`), dan README_IMPORT.md.

`keywords` diisi topik (judul bab dan bagian), `linkN_*` diisi rujukan ke pasal lain di UU yang
sama yang disebut dalam isi pasal. Tidak ada kolom yang perlu diisi manual.
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
SCRIPT = "import-tools/prepare_import.py"

REVIEW_COVERAGE_THRESHOLD = 0.90

# Sama dengan MAX_LINKS_PER_PASAL di admin-dashboard/src/pages/BulkImportPage.tsx.
MAX_LINKS_PER_PASAL = 20

# Typo OCR yang berulang pada rumusan perubahan di sumber HTML.
OCR_FIXES = {
    r"\bbarn\b": "baru",
    r"\bbam\b": "baru",
}

SMALL_WORDS = {
    "dan", "atau", "yang", "di", "ke", "dari", "dalam", "untuk", "oleh", "dengan", "tentang",
    "pada", "bagi", "serta", "terhadap", "atas", "sebagai", "secara", "tanpa", "kepada",
}

ORIGINAL = "asli"
INSERTED = "disisipkan"


@dataclass(frozen=True)
class Amendment:
    """UU yang mengubah UU utama dan rumusannya tersedia di HTML datahukum.com."""

    doc_class: str  # class section versi perubahan di HTML, contoh "uu-12026"
    label: str  # contoh "UU 1/2026"
    title: str  # contoh "UU 1/2026 (Penyesuaian Pidana)"
    pdf: Path  # PDF resmi UU perubahan, pembanding rumusan baru


@dataclass(frozen=True)
class LawConfig:
    slug: str  # nama folder output dan argumen CLI, contoh "kuhp-2023"
    xlsx_name: str
    kode: str
    label: str  # sebutan singkat, contoh "UU 1/2023"
    nama: str
    nama_lengkap: str
    tahun: int
    datahukum_url: str
    bpk_detail_url: str
    bpk_pdf_url: str
    doc_class: str  # class section versi asli di HTML, contoh "uu-12023"
    body_pages: tuple[int, int]  # halaman PDF BPK (1-based) batang tubuh
    penjelasan_pages: tuple[int, int]  # halaman PDF BPK (1-based) penjelasan
    amendment: Amendment | None = None
    mk_notes: dict[str, str] = field(default_factory=dict)
    # (kolom, teks salah, teks benar); skrip berhenti kalau teks salahnya tidak ditemukan.
    text_fixes: dict[str, list[tuple[str, str, str]]] = field(default_factory=dict)
    # Pasal berskor rendah yang sudah dicek manual ke PDF.
    manual_review: dict[str, str] = field(default_factory=dict)
    # Bab yang isinya memetakan pasal UU lain, jadi nomornya tidak dibaca sebagai rujukan internal.
    no_link_bab_titles: frozenset[str] = frozenset({"KETENTUAN PERALIHAN", "KETENTUAN PENUTUP"})
    readme_notes: tuple[str, ...] = ()

    @property
    def output_dir(self) -> Path:
        return ROOT / "data-import" / self.slug


@dataclass
class Heading:
    kind: str
    label: str
    title: str


@dataclass
class PasalRecord:
    nomor: str
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


def letters(text: str) -> str:
    return re.sub(r"[^a-z0-9]", "", text.lower())


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


# --- Render HTML ke teks ----------------------------------------------------------------


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


def render_section(parent: Tag | None, doc_class: str | None, clean: TextCleaner) -> str:
    if parent is None or doc_class is None:
        return ""
    section = parent.find("section", class_=doc_class, recursive=False)
    return "\n".join(tidy_lines(render_flow(section, clean))) if section else ""


def parse_heading(tag: Tag) -> Heading:
    # Judul bisa berupa anak langsung (<h2>) atau dibungkus <section> (format HTML yang lebih baru).
    header = None
    for child in tag.find_all(True, recursive=False):
        if child.name in {"h1", "h2", "h3", "h4"}:
            header = child
        elif child.name == "section":
            header = child.find(["h1", "h2", "h3", "h4"])
        if header is not None or child.name == "div":
            break
    text = squash(header.get_text(" ")) if header else ""
    label, _, title = text.partition(" - ")
    kind = {"buku": "buku", "bab": "bab", "bag": "bagian", "para": "paragraf"}[tag["class"][0]]
    return Heading(kind=kind, label=label.strip(), title=title.strip())


def parse_datahukum(path: Path, config: LawConfig) -> list[PasalRecord]:
    soup = BeautifulSoup(path.read_text(encoding="utf-8"), "html.parser")
    clean = TextCleaner(soup.select_one("div.batangtubuh").get_text(" "))
    structure = soup.select("div.buku, div.bab, div.bag, div.para")
    headings = {tag["data-node-id"]: parse_heading(tag) for tag in structure}
    parents = {tag["data-node-id"]: tag.get("data-parent-id", "") for tag in structure}
    amended_class = config.amendment.doc_class if config.amendment else None

    records: list[PasalRecord] = []
    for pasal in soup.select("div.pasal"):
        nomor = squash(pasal.select_one(".pasal-header h5").get_text(" ")).removeprefix("Pasal ").strip()

        chain = []
        parent = pasal.get("data-parent-id", "")
        while parent:
            chain.append(headings[parent])
            parent = parents.get(parent, "")
        chain.reverse()
        if not chain and records:
            # Pasal sisipan (contoh 599A) tidak punya induk di HTML; ikut struktur pasal sebelumnya.
            chain = list(records[-1].headings)

        content = pasal.select_one("div.content")
        explanation = pasal.select_one("div.penjelasan")
        isi_original = render_section(content, config.doc_class, clean)
        isi_amended = render_section(content, amended_class, clean)
        pj_original = render_section(explanation, config.doc_class, clean)
        pj_amended = render_section(explanation, amended_class, clean)

        # Sumber HTML menyalin ulang isi pasal ke versi perubahan walau yang diubah hanya penjelasannya.
        isi_changed = bool(isi_original and isi_amended) and letters(isi_original) != letters(isi_amended)
        pj_changed = bool(pj_amended) and letters(pj_original) != letters(pj_amended)
        if isi_amended and not isi_original:
            status = INSERTED
        elif isi_changed and pj_changed:
            status = "isi & penjelasan diubah"
        elif isi_changed:
            status = "isi diubah"
        elif pj_changed:
            status = "penjelasan diubah"
        else:
            status = ORIGINAL

        fields = {
            "isi": isi_amended if (isi_changed or not isi_original) else isi_original,
            "penjelasan": pj_amended if pj_changed else pj_original,
        }
        for column, wrong, right in config.text_fixes.get(nomor, []):
            if wrong not in fields[column]:
                raise ValueError(f"text_fixes Pasal {nomor}: {wrong!r} tidak ditemukan di {column}")
            fields[column] = fields[column].replace(wrong, right)
        penjelasan = fields["penjelasan"]
        mk_note = config.mk_notes.get(nomor)
        if mk_note:
            penjelasan = f"{penjelasan}\n{mk_note}".strip()

        records.append(
            PasalRecord(
                nomor=nomor,
                headings=chain,
                isi=fields["isi"],
                penjelasan=penjelasan,
                status=status,
                original_isi=isi_original,
                original_penjelasan=pj_original,
                notes=[mk_note.split(":")[0]] if mk_note else [],
            )
        )
    return records


# --- Pembanding PDF resmi -------------------------------------------------------------

PDF_HEADER = re.compile(r"^\s*Pa\s?[s5]\s?a\s?[l1I|i]\s+([0-9lIOoSB]{1,3})\s*([A-Z])?\s*$")
OCR_CONFUSABLE = str.maketrans({"1": "l", "i": "l", "0": "o", "5": "s"})


def ocr_digits(value: str) -> str:
    return value.translate(str.maketrans({"l": "1", "I": "1", "i": "1", "O": "0", "o": "0", "S": "5", "B": "8"}))


def ocr_fold(text: str) -> str:
    """Huruf/angka saja, dengan karakter yang sering tertukar OCR (1/l/I, 0/O, 5/S) disamakan."""
    return letters(text).translate(OCR_CONFUSABLE)


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
        if nomor not in order:
            return None
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


# --- Kolom turunan: judul, topik, pasal terkait -----------------------------------------


def title_case(text: str) -> str:
    words = text.lower().split()
    return " ".join(w if (i and w in SMALL_WORDS) else w[:1].upper() + w[1:] for i, w in enumerate(words))


def judul_for(record: PasalRecord) -> str:
    for heading in reversed(record.headings):
        if heading.kind in {"paragraf", "bagian", "bab"} and heading.title:
            return heading.title if heading.kind != "bab" else title_case(heading.title)
    return ""


def keywords_for(record: PasalRecord) -> str:
    """Topik pasal = judul bab dan bagian tempat pasal berada (huruf kecil)."""
    topics = []
    for heading in record.headings:
        if heading.kind in {"bab", "bagian"} and heading.title:
            # Koma adalah pemisah keyword di format import, jadi dibuang dari judul.
            topic = heading.title.lower().replace(",", "")
            if topic not in topics:
                topics.append(topic)
    return ", ".join(topics)


PASAL_MENTION = re.compile(r"\bPasal\s+(\d+[A-Z]?)\b((?:\s+ayat\s*\(\d+[a-z]?\))?(?:\s+huruf\s+[a-z]{1,2}\b)?(?:\s+angka\s+\d+\b)?)")
CHAIN_GAP = re.compile(
    r"(?:\s*(?:ayat\s*\(\d+[a-z]?\)|huruf\s+[a-z]{1,2}\b|angka\s+\d+\b|,|dan/atau|dan|atau|serta|sampai\s+dengan)\s*)*",
    re.I,
)
EXTERNAL_LAW = re.compile(r"\s*(?:Undang-Undang|UU\b|Peraturan|Kitab|Ordonnantie|Wetboek|Staatsblad|Stbl|Perppu)", re.I)


def cross_references(record: PasalRecord, known: set[str], config: LawConfig) -> list[tuple[str, str]]:
    """Rujukan ke pasal lain di UU yang sama yang disebut dalam isi: [(nomor_tujuan, potongan_rujukan)].

    Sebutan yang berurutan ("Pasal 218 dan Pasal 219", "Pasal 51 sampai dengan Pasal 54") dibaca
    sebagai satu rangkaian. Rangkaian yang langsung diikuti nama undang-undang lain dilewati.
    """
    if any(h.kind == "bab" and h.title in config.no_link_bab_titles for h in record.headings):
        return []
    mentions = list(PASAL_MENTION.finditer(record.isi))
    chains: list[list[re.Match[str]]] = []
    for mention in mentions:
        if chains and CHAIN_GAP.fullmatch(record.isi[chains[-1][-1].end() : mention.start()]):
            chains[-1].append(mention)
        else:
            chains.append([mention])

    found: list[tuple[str, str]] = []
    for chain in chains:
        tail = record.isi[chain[-1].end() :]
        tail = tail[CHAIN_GAP.match(tail).end() :]
        if EXTERNAL_LAW.match(tail):
            continue
        targets: list[tuple[str, str]] = []
        for index, mention in enumerate(chain):
            targets.append((mention.group(1), squash(mention.group(0))))
            following = chain[index + 1] if index + 1 < len(chain) else None
            gap = record.isi[mention.end() : following.start()] if following else ""
            if following and re.search(r"sampai\s+dengan", gap, re.I) and mention.group(1).isdigit() and following.group(1).isdigit():
                start, end = int(mention.group(1)), int(following.group(1))
                phrase = f"Pasal {start} sampai dengan Pasal {end}"
                targets[-1] = (mention.group(1), phrase)
                if 0 < end - start <= 10:
                    targets.extend((str(n), phrase) for n in range(start + 1, end))
        for nomor, phrase in targets:
            if nomor != record.nomor and nomor in known and nomor not in {n for n, _ in found}:
                found.append((nomor, phrase))
    return found[:MAX_LINKS_PER_PASAL]


# --- Output ---------------------------------------------------------------------------


def status_label(record: PasalRecord, config: LawConfig) -> str:
    if record.status == ORIGINAL:
        return f"asli {config.label}"
    return f"{record.status} {config.amendment.label}" if config.amendment else record.status


def write_xlsx(config: LawConfig, records: list[PasalRecord], review: list[dict[str, object]]) -> dict[str, list]:
    wb = Workbook()
    ws = wb.active
    ws.title = "import"
    known = {record.nomor for record in records}
    links = {record.nomor: cross_references(record, known, config) for record in records}
    link_slots = max((len(found) for found in links.values()), default=0)
    headers = ["nomor", "judul", "isi", "penjelasan", "keywords"]
    for slot in range(1, link_slots + 1):
        headers += [f"link{slot}_targetUU", f"link{slot}_targetNomor", f"link{slot}_keterangan"]
    ws.append(headers)
    for record in records:
        row = [record.nomor, judul_for(record), record.isi, record.penjelasan, keywords_for(record)]
        for nomor, phrase in links[record.nomor]:
            row += [config.kode, nomor, f"Disebut dalam isi: {phrase}"]
        ws.append(row)

    review_ws = wb.create_sheet("review")
    review_headers = ["nomor", "status_teks", "bab", "cakupan_isi_pdf", "cakupan_penjelasan_pdf", "perlu_review", "catatan"]
    review_ws.append(review_headers)
    for row in review:
        review_ws.append([row[h] for h in review_headers])

    meta = wb.create_sheet("catatan")
    suffix = f" (konsolidasi dengan {config.amendment.label})" if config.amendment else ""
    meta.append(["Judul", config.nama_lengkap + suffix])
    meta.append(["Jumlah pasal", len(records)])
    meta.append(["Sumber teks", config.datahukum_url])
    meta.append(["Pembanding resmi", config.bpk_detail_url])
    meta.append(["Catatan", f"Upload sheet pertama ('import') lewat menu Import Data. Pilih UU kode {config.kode} sebelum import."])

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

    config.output_dir.mkdir(parents=True, exist_ok=True)
    wb.save(config.output_dir / config.xlsx_name)
    return links


def write_readme(config: LawConfig, records: list[PasalRecord], review: list[dict[str, object]], links: dict[str, list]) -> None:
    flagged = [row for row in review if row["perlu_review"] == "ya"]
    flagged_lines = "\n".join(f"| {row['nomor']} | {row['catatan']} |" for row in flagged) or "| - | - |"
    inserted = [r.nomor for r in records if r.status == INSERTED]
    numbered = [r.nomor for r in records if r.status != INSERTED]
    span = f"Pasal {numbered[0]} sampai {numbered[-1]}" + (f" ditambah Pasal {', '.join(inserted)}" if inserted else "")
    link_count = sum(len(found) for found in links.values())

    consolidation = ""
    sources = [
        f"1. Teks terstruktur: {config.datahukum_url} (pihak ketiga, bukan sumber resmi)",
        f"2. Pembanding resmi: {config.bpk_detail_url} (PDF salinan, hasil scan/OCR)",
    ]
    if config.amendment:
        isi_changed = [r.nomor for r in records if r.status.startswith("isi")]
        pj_changed = [r.nomor for r in records if r.status == "penjelasan diubah"]
        consolidation = (
            f"- Teks sudah dikonsolidasi dengan {config.amendment.title}:\n"
            f"  - isi pasal diubah ({len(isi_changed)}): {', '.join(isi_changed)}\n"
            f"  - hanya penjelasan diubah ({len(pj_changed)}): {', '.join(pj_changed)}\n"
            f"  - pasal sisipan ({len(inserted)}): {', '.join(inserted)}\n"
        )
        sources.append(f"3. Rumusan perubahan {config.amendment.title}: `{config.amendment.pdf.name}`")
    mk = ""
    if config.mk_notes:
        mk = f"- Pasal {', '.join(config.mk_notes)} diberi catatan Putusan MK di kolom penjelasan.\n"
    extra = "".join(f"- {note}\n" for note in config.readme_notes)
    no_link = " dan ".join(title_case(t) for t in sorted(config.no_link_bab_titles))
    comparison = (
        f"BPK, rumusan perubahan ke PDF {config.amendment.label})" if config.amendment else "BPK)"
    )

    readme = f"""# Import {config.kode} ({config.nama_lengkap})

File ini dibuat oleh `{SCRIPT} {config.slug}`. Jangan edit manual; perbaiki konfigurasi di
`import-tools/laws/` atau mesinnya di `import-tools/datahukum_pipeline.py`, lalu jalankan ulang.

## Isi

- `{config.xlsx_name}`
  - sheet `import`: {len(records)} pasal ({span}).
  - sheet `review`: hasil pembandingan tiap pasal dengan PDF resmi.
{consolidation}- `judul` diisi judul paragraf/bagian/bab tempat pasal berada (tidak ada judul per pasal).
- `penjelasan` diisi penjelasan resmi.
{mk}- `keywords` (topik): judul bab dan bagian tempat pasal berada. Tidak perlu diisi manual.
- `linkN_*` (pasal terkait, {link_count} link): rujukan ke pasal lain di {config.kode} yang disebut di isi
  pasal, misalnya "sebagaimana dimaksud dalam Pasal 54". Rujukan yang diikuti nama undang-undang lain
  dilewati, begitu juga Bab {no_link} (isinya memetakan pasal UU lain).
  Maksimal {MAX_LINKS_PER_PASAL} per pasal.
{extra}
## Sumber

{chr(10).join(sources)}

Kesalahan sumber HTML yang diperbaiki otomatis: butir ayat/huruf yang hilang, label penjelasan yang
menempel ke paragraf lain, kalimat yang terpotong jadi dua paragraf, dan judul bagian yang tergeser satu
pasal (dicek ke PDF). Typo per pasal ada di `text_fixes` ({sum(len(v) for v in config.text_fixes.values())} perbaikan, tiap entri dicek ke PDF).
Typo dicari dari kata yang tidak dikenal kamus dan tidak ada di PDF. Typo yang kebetulan membentuk kata
lain yang sah tidak bisa dipastikan otomatis, jadi verifikasi admin terhadap PDF resmi tetap diperlukan.

`cakupan_*_pdf` = porsi huruf pada teks kita yang ditemukan di PDF resmi (rumusan asli dicek ke PDF
{comparison}. Nilai di bawah {REVIEW_COVERAGE_THRESHOLD:.0%} atau butir ayat/huruf yang kosong ditandai
`perlu_review`. PDF resmi adalah hasil scan, jadi skor rendah biasanya berasal dari OCR PDF (kata hilang
di ujung baris). Pasal berskor rendah yang sudah dicek manual tercatat di `manual_review` dan kolom
`catatan`.

## Cara import

1. Admin dashboard → menu `Undang-Undang`. Pastikan ada UU kode `{config.kode}`:
   - Nama: `{config.nama}`
   - Nama lengkap: `{config.nama_lengkap}`
   - Tahun: `{config.tahun}`
   - Link naskah resmi: `{config.bpk_detail_url}`
   - Sumber teks: `{config.datahukum_url}`
2. Menu `Import Data` → mode XLSX → pilih UU `{config.kode}` → upload file xlsx.
3. Import memakai `updateOrCreate` per (UU, nomor): pasal yang sudah ada akan ditimpa,
   pasal lain di UU yang sama tidak dihapus.
4. Nomor disimpan tanpa awalan "Pasal" (contoh `1`, `599A`). Data lama dengan nomor `Pasal 1`
   tidak akan tertimpa dan jadi dobel, jadi hapus dulu pasal lama sebelum import.
5. Pasal baru atau yang teksnya berubah masuk menu `Verifikasi` dengan status "Perlu verifikasi".
   Admin mencocokkan tiap pasal dengan naskah resmi lalu menekan "Verifikasi". Sebelum itu pasal
   tetap tampil di mobile dengan label "Belum diverifikasi admin".

Catatan tampilan: normalizer import menggabungkan anak kalimat penutup setelah daftar huruf
(misalnya "..., pidananya dapat ditambah 1/3") ke butir huruf terakhir. Isi teks tetap lengkap.

## Perlu dicek manual ({len(flagged)} pasal)

| Pasal | Catatan |
|---|---|
{flagged_lines}
"""
    (config.output_dir / "README_IMPORT.md").write_text(readme, encoding="utf-8")


def run(config: LawConfig) -> None:
    html_path = fetch(config.datahukum_url, CACHE_DIR / f"datahukum_{config.slug}.html")
    pdf_path = fetch(config.bpk_pdf_url, CACHE_DIR / f"bpk_{config.slug}.pdf")
    if config.amendment and not config.amendment.pdf.exists():
        raise FileNotFoundError(f"PDF {config.amendment.label} tidak ditemukan: {config.amendment.pdf}")

    records = parse_datahukum(html_path, config)
    original_order = [r.nomor for r in records if r.status != INSERTED]

    pages = [page.get_text() for page in pymupdf.open(pdf_path)]
    body = index_pdf(pages[config.body_pages[0] - 1 : config.body_pages[1]], original_order)
    explanation = index_pdf(pages[config.penjelasan_pages[0] - 1 : config.penjelasan_pages[1]], original_order)
    amendment_folded = (
        ocr_fold("\n".join(page.get_text() for page in pymupdf.open(config.amendment.pdf))) if config.amendment else ""
    )
    heading_fixes = fix_heading_placement(records, body)

    review = []
    for record in records:
        notes = list(record.notes)
        if record.nomor in heading_fixes:
            notes.append(heading_fixes[record.nomor])

        # Rumusan asli dicek ke PDF BPK, rumusan perubahan ke PDF UU perubahan.
        isi_cov = official_coverage(record.original_isi, body, record.nomor, original_order) if record.original_isi else 1.0
        if config.amendment and (record.status.startswith("isi") or record.status == INSERTED):
            amended = fragment_coverage(record.isi, amendment_folded)
            notes.append(f"Isi versi {config.amendment.label} cocok {amended:.0%} dengan PDF {config.amendment.label}")
            isi_cov = min(isi_cov, amended)

        pj_cov = (
            official_coverage(record.original_penjelasan, explanation, record.nomor, original_order)
            if record.original_penjelasan
            else 1.0
        )
        if config.amendment and ("penjelasan" in record.status or (record.status == INSERTED and record.penjelasan)):
            amended = fragment_coverage(record.penjelasan, amendment_folded)
            notes.append(f"Penjelasan versi {config.amendment.label} cocok {amended:.0%} dengan PDF {config.amendment.label}")
            pj_cov = min(pj_cov, amended)

        empty_item = bool(re.search(r"^(\(\d+[a-z]?\)|[a-z]\.|\d+\.)$", record.isi + "\n" + record.penjelasan, re.M))
        if empty_item:
            notes.append("Ada butir ayat/huruf kosong")
        low = min(isi_cov, pj_cov) < REVIEW_COVERAGE_THRESHOLD
        if low:
            notes.append("Cakupan teks terhadap PDF rendah")
        needs_review = low or empty_item
        if record.nomor in config.manual_review:
            notes.append(config.manual_review[record.nomor])
            needs_review = empty_item
        bab = next((h for h in record.headings if h.kind == "bab"), None)
        review.append(
            {
                "nomor": record.nomor,
                "status_teks": status_label(record, config),
                "bab": f"{bab.label} {title_case(bab.title)}" if bab else "",
                "cakupan_isi_pdf": round(isi_cov, 3),
                "cakupan_penjelasan_pdf": round(pj_cov, 3),
                "perlu_review": "ya" if needs_review else "tidak",
                "catatan": "; ".join(notes),
            }
        )

    links = write_xlsx(config, records, review)
    write_readme(config, records, review, links)

    flagged = sum(1 for row in review if row["perlu_review"] == "ya")
    print(f"[{config.slug}] output: {config.output_dir}")
    print(f"[{config.slug}] pasal: {len(records)} | link: {sum(len(v) for v in links.values())} | perlu review: {flagged}")
    print(f"[{config.slug}] header pasal terbaca di PDF: batang tubuh {len(body.starts)}, penjelasan {len(explanation.starts)}")
