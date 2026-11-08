"""Mesin import undang-undang dari datahukum.com untuk Bulk Import admin.

Alur per undang-undang (lihat konfigurasi di `laws/`):
1. Ambil HTML terstruktur datahukum.com (buku/bab/bagian/paragraf, ayat, huruf, penjelasan).
2. Kalau UU pernah diubah, susun semua versi rumusan per pasal dari HTML yang sama. Daftar
   peraturan perubahan berasal dari konfigurasi atau dari bagian "Riwayat" di HTML.
3. Kalau ada PDF resmi (JDIH BPK), bandingkan tiap pasal dengan PDF itu dan PDF UU perubahan.
   Semua teks juga dipindai untuk sisa teks penerjemah/chatbot dan kata asing.
4. Tulis xlsx siap upload (sheet `import`), hasil cek (sheet `review`), dan README_IMPORT.md.

`keywords` diisi topik (judul bab dan bagian), `linkN_*` diisi rujukan ke pasal lain di UU yang
sama yang disebut dalam isi pasal. Tidak ada kolom yang perlu diisi manual.
"""

from __future__ import annotations

import difflib
import hashlib
import html
import os
import re
import urllib.request
from datetime import datetime, timezone
from dataclasses import dataclass, field
from pathlib import Path

import pymupdf
from bs4 import BeautifulSoup, Tag
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill


ROOT = Path(__file__).resolve().parents[1]
CACHE_DIR = Path(os.environ.get("IMPORT_CACHE_DIR") or Path(__file__).resolve().parent / ".cache")
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
REPEALED = "dihapus"
REPEALED_TEXT = "Dihapus."
CHANGED = "diubah"


@dataclass(frozen=True)
class Amendment:
    """Peraturan yang mengubah UU utama; rumusannya tersedia di HTML datahukum.com."""

    doc_class: str  # class section versi perubahan di HTML, contoh "uu-12026"
    label: str  # contoh "UU 1/2026"
    title: str  # contoh "UU 1/2026 (Penyesuaian Pidana)"
    full_title: str  # contoh "Undang-Undang Nomor 1 Tahun 2026 tentang Penyesuaian Pidana"
    official_url: str = ""  # halaman naskah resmi (JDIH BPK); kosong kalau tidak ada
    diundangkan: str = ""  # YYYY-MM-DD
    berlaku_sejak: str = ""  # YYYY-MM-DD
    # PDF resmi pembanding rumusan baru (nama file di cache + sumber unduhan). Kosong = tidak dicek.
    pdf: str = ""
    pdf_url: str = ""
    # Pasal yang dihapus/dicabut peraturan ini. Teks lama di HTML untuk pasal ini diabaikan.
    repealed: tuple[str, ...] = ()


@dataclass(frozen=True)
class CatatanRule:
    """Catatan redaksi untuk pasal di buku/bab tertentu atau pasal tertentu (kolom `catatan`).

    Kosong berarti tidak membatasi. Label dibandingkan persis dengan judul di HTML ("BUKU KEDUA", "BAB IV").
    """

    text: str
    buku: str = ""
    bab: tuple[str, ...] = ()
    nomor: tuple[str, ...] = ()

    def matches(self, record: PasalRecord) -> bool:
        labels = {h.kind: h.label for h in record.headings}
        return (
            (not self.buku or labels.get("buku") == self.buku)
            and (not self.bab or labels.get("bab") in self.bab)
            and (not self.nomor or record.nomor in self.nomor)
        )


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
    doc_class: str  # class section versi asli di HTML, contoh "uu-12023"
    bpk_detail_url: str = ""  # halaman naskah resmi; kosong kalau tidak ada naskah resmi berbahasa Indonesia
    bpk_pdf_url: str = ""  # PDF resmi pembanding; kosong = cakupan PDF tidak dihitung
    body_pages: tuple[int, int] = (0, 0)  # halaman PDF BPK (1-based) batang tubuh
    penjelasan_pages: tuple[int, int] = (0, 0)  # halaman PDF BPK (1-based) penjelasan
    amendments: tuple[Amendment, ...] = ()  # urut kronologis
    # Ambil daftar perubahan dari bagian "Riwayat" HTML (dipakai kalau perubahannya banyak).
    amendments_from_html: bool = False
    # Koreksi metadata perubahan dari HTML, per class: {"label": ..., "diundangkan": ..., ...}.
    amendment_overrides: dict[str, dict[str, str]] = field(default_factory=dict)
    diundangkan: str = ""  # YYYY-MM-DD, untuk sheet riwayat
    berlaku_sejak: str = ""  # YYYY-MM-DD, untuk sheet riwayat
    repealed_text: str = REPEALED_TEXT  # isi pasal yang dihapus/dicabut
    mk_notes: dict[str, str] = field(default_factory=dict)
    # (kolom, teks salah, teks benar); skrip berhenti kalau teks salahnya tidak ditemukan.
    text_fixes: dict[str, list[tuple[str, str, str]]] = field(default_factory=dict)
    # Pasal berskor rendah atau bertanda QA yang sudah dicek manual.
    manual_review: dict[str, str] = field(default_factory=dict)
    # Bab yang isinya memetakan pasal UU lain, jadi nomornya tidak dibaca sebagai rujukan internal.
    no_link_bab_titles: frozenset[str] = frozenset({"KETENTUAN PERALIHAN", "KETENTUAN PENUTUP"})
    # Catatan status teks untuk seluruh UU (diisi admin di menu Undang-Undang, dicatat di README).
    catatan_teks: str = ""
    catatan_rules: tuple[CatatanRule, ...] = ()
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
class Version:
    status: str  # ORIGINAL, CHANGED, INSERTED, REPEALED
    amendment: Amendment | None  # None = rumusan asli
    isi: str
    penjelasan: str


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
    versions: list[Version] = field(default_factory=list)
    catatan: str = ""


class PipelineError(Exception):
    """Kegagalan struktural; pesannya (bahasa Indonesia) ditampilkan ke admin di mode --json."""


def download(url: str, path: Path) -> Path:
    """Unduh `url` ke `path` lewat file sementara, jadi unduhan yang gagal tidak merusak cache."""
    path.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (CariPasal import tool)"})
    partial = path.with_name(path.name + ".part")
    with urllib.request.urlopen(request, timeout=120) as response:
        partial.write_bytes(response.read())
    os.replace(partial, path)
    return path


def fetch(url: str, path: Path) -> Path:
    if path.exists() and path.stat().st_size > 0:
        return path
    return download(url, path)


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
    # Judul bisa berupa anak langsung (<h2>) atau dibungkus <section> per versi (format HTML yang
    # lebih baru). Kalau judulnya pernah diubah, section versi terakhir yang berlaku.
    header = None
    for child in tag.find_all(True, recursive=False):
        if child.name == "div":
            break
        if child.name in {"h1", "h2", "h3", "h4"}:
            header = child
            break
        if child.name == "section":
            header = child.find(["h1", "h2", "h3", "h4"]) or header
    text = squash(header.get_text(" ")) if header else ""
    label, _, title = text.partition(" - ")
    kind = {"buku": "buku", "bab": "bab", "bag": "bagian", "para": "paragraf"}[tag["class"][0]]
    return Heading(kind=kind, label=label.strip(), title=title.strip())


def version_classes(parent: Tag | None) -> set[str]:
    """Class versi dari section anak langsung `parent`."""
    if parent is None:
        return set()
    return {name for section in parent.find_all("section", recursive=False) for name in section.get("class", [])}


MONTHS = {
    name: index
    for index, name in enumerate(
        ["januari", "februari", "maret", "april", "mei", "juni", "juli", "agustus", "september", "oktober", "november", "desember"],
        start=1,
    )
}
REGULATION_TITLE = re.compile(r"^\d+\.\s*(Staatsblad|UU)\s+No\.\s*(\d+)\s+Tahun\s+(\d{4})(?:\s+tentang\s+(.*))?$", re.S)


def indonesian_date(text: str) -> str:
    """"6 November 1871" -> "1871-11-06"; kosong kalau tidak terbaca."""
    match = re.search(r"(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})", text)
    if not match or match.group(2).lower() not in MONTHS:
        return ""
    return f"{match.group(3)}-{MONTHS[match.group(2).lower()]:02d}-{int(match.group(1)):02d}"


def format_date(iso: str) -> str:
    """"1871-11-06" -> "6 November 1871"."""
    year, month, day = iso.split("-")
    return f"{int(day)} {list(MONTHS)[int(month) - 1].capitalize()} {year}"

def nomor_key(nomor: str) -> str:
    return nomor.strip().lower()


def amendments_from_html(soup: BeautifulSoup, config: LawConfig, warnings: list[dict[str, str]]) -> tuple[Amendment, ...]:
    """Daftar perubahan dari bagian "Riwayat Perundang-Undangan" HTML datahukum, urut seperti di sumber."""
    amendments = []
    for article in soup.select("div.riwayat article.uu--amendment"):
        doc_class = next(c for c in article["class"] if c not in {"uu", "uu--amendment"})
        header = squash(article.select_one(".uu-header h5").get_text(" "))
        match = REGULATION_TITLE.match(header)
        if match is None:
            raise PipelineError(f"Judul peraturan perubahan tidak dikenali di bagian Riwayat: {header!r}")
        kind, number, year, about = match.groups()
        about = (about or "").rstrip(". ")
        meta = {p.get_text(" ").split(":", 1)[0].strip(): p.get_text(" ").split(":", 1)[-1] for p in article.select(".uu-meta p")}
        disahkan = indonesian_date(meta.get("Disahkan", ""))
        diundangkan = indonesian_date(meta.get("Diundangkan", ""))
        for name, value in (("disahkan", disahkan), ("diundangkan", diundangkan)):
            # Sumber kadang salah ketik abad (contoh "31 agustus 1973" untuk Staatsblad 1873). Selisih
            # beberapa tahun wajar: Staatsblad bisa terbit lama setelah keputusannya disahkan.
            if value and abs(int(value[:4]) - int(year)) > 5:
                warnings.append({"nomor": "", "message": f"Tanggal {name} {header[:60]!r} ({value}) tidak cocok dengan tahunnya; diabaikan."})
                if name == "disahkan":
                    disahkan = ""
                else:
                    diundangkan = ""
        if kind == "Staatsblad":
            label = f"Stb. {year} No. {number}"
            full_title = f"Staatsblad Tahun {year} Nomor {number}" + (f" tentang {about}" if about else "")
        else:
            label = f"UU {number}/{year}"
            full_title = f"Undang-Undang Nomor {number} Tahun {year}" + (f" tentang {about}" if about else "")
        if disahkan and not diundangkan:
            full_title += f" (disahkan {format_date(disahkan)})"
        cabut = article.select_one("p.action-list.cabut")
        repealed = tuple(
            nomor_key(item.strip().removeprefix("Pasal "))
            for item in (cabut.get_text().split(",") if cabut else [])
            if item.strip()
        )
        fields = {
            "doc_class": doc_class,
            "label": label,
            "title": label,
            "full_title": full_title,
            "diundangkan": diundangkan,
            "repealed": repealed,
        } | config.amendment_overrides.get(doc_class, {})
        amendments.append(Amendment(**fields))
    unknown = set(config.amendment_overrides) - {a.doc_class for a in amendments}
    if unknown:
        raise PipelineError(f"amendment_overrides untuk class yang tidak ada di Riwayat: {', '.join(sorted(unknown))}")
    return tuple(amendments)


def build_versions(
    nomor: str,
    content: Tag | None,
    explanation: Tag | None,
    config: LawConfig,
    amendments: tuple[Amendment, ...],
    clean: TextCleaner,
) -> list[Version]:
    """Semua rumusan pasal dari yang tertua ke yang berlaku, tanpa versi yang tidak mengubah teks."""
    versions: list[Version] = []
    isi = render_section(content, config.doc_class, clean)
    if isi:
        versions.append(Version(ORIGINAL, None, isi, render_section(explanation, config.doc_class, clean)))
    for amendment in amendments:
        previous = versions[-1] if versions else None
        if nomor_key(nomor) in {nomor_key(n) for n in amendment.repealed}:
            # HTML kadang masih memuat teks lama di versi peraturan yang mencabutnya.
            if previous is not None and previous.status != REPEALED:
                versions.append(Version(REPEALED, amendment, config.repealed_text, ""))
            continue
        isi = render_section(content, amendment.doc_class, clean)
        penjelasan = render_section(explanation, amendment.doc_class, clean)
        if not isi and not penjelasan:
            continue
        if previous is None or previous.status == REPEALED:
            if isi:
                versions.append(Version(INSERTED, amendment, isi, penjelasan))
            continue
        # Sumber menyalin ulang isi pasal ke versi perubahan walau yang diubah hanya penjelasannya,
        # dan penjelasan yang tidak diubah tidak disalin.
        isi = isi or previous.isi
        penjelasan = penjelasan or previous.penjelasan
        if letters(isi) == letters(previous.isi) and letters(penjelasan) == letters(previous.penjelasan):
            continue
        versions.append(Version(CHANGED, amendment, isi, penjelasan))
    return versions


def summary_status(versions: list[Version]) -> str:
    """Status teks untuk sheet review: perubahan antara rumusan pertama dan yang berlaku."""
    first, last = versions[0], versions[-1]
    if last.status == REPEALED:
        return REPEALED
    if first.status != ORIGINAL:
        return INSERTED
    isi_changed = letters(first.isi) != letters(last.isi)
    pj_changed = letters(first.penjelasan) != letters(last.penjelasan)
    if isi_changed and pj_changed:
        return "isi & penjelasan diubah"
    if isi_changed:
        return "isi diubah"
    if pj_changed:
        return "penjelasan diubah"
    return ORIGINAL


def parse_datahukum(
    path: Path,
    config: LawConfig,
    warnings: list[dict[str, str]],
    unknown_versions: set[str],
    strict_fixes: bool,
) -> tuple[list[PasalRecord], tuple[Amendment, ...]]:
    """Baca HTML datahukum: pasal beserta semua versi rumusannya, dan daftar peraturan perubahan.

    Dengan `strict_fixes` (mode xlsx), typo di `text_fixes` yang tidak cocok adalah error. Tanpanya
    (mode --json) perbaikan itu dilewati dan dicatat di `warnings`. `unknown_versions` diisi class
    versi yang bukan versi asli maupun versi perubahan yang dikenal.
    """
    soup = BeautifulSoup(path.read_text(encoding="utf-8"), "html.parser")
    body = soup.select_one("div.batangtubuh")
    if body is None:
        raise PipelineError("Struktur HTML datahukum.com berubah: elemen div.batangtubuh tidak ditemukan.")
    if not soup.select("div.pasal"):
        raise PipelineError("Struktur HTML datahukum.com berubah: tidak ada elemen div.pasal.")
    amendments = amendments_from_html(soup, config, warnings) if config.amendments_from_html else config.amendments
    known_classes = {config.doc_class} | {a.doc_class for a in amendments}
    clean = TextCleaner(body.get_text(" "))
    structure = soup.select("div.buku, div.bab, div.bag, div.para")
    headings = {tag["data-node-id"]: parse_heading(tag) for tag in structure}
    parents = {tag["data-node-id"]: tag.get("data-parent-id", "") for tag in structure}

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
        unknown_versions |= (version_classes(content) | version_classes(explanation)) - known_classes
        versions = build_versions(nomor, content, explanation, config, amendments, clean)
        if not versions:
            raise PipelineError(f"Pasal {nomor} tidak punya rumusan yang bisa dibaca.")
        latest = versions[-1]
        # Rumusan asli mentah untuk pembanding PDF; status dihitung sebelum text_fixes dan catatan MK.
        first = versions[0]
        original_isi, original_penjelasan = (first.isi, first.penjelasan) if first.status == ORIGINAL else ("", "")
        status = summary_status(versions)

        fields = {"isi": latest.isi, "penjelasan": latest.penjelasan}
        for column, wrong, right in config.text_fixes.get(nomor, []):
            if wrong not in fields[column]:
                if not strict_fixes:
                    warnings.append({"nomor": nomor, "message": f"Perbaikan teks ({column}) dilewati karena {wrong!r} tidak ditemukan; periksa text_fixes."})
                    continue
                raise ValueError(f"text_fixes Pasal {nomor}: {wrong!r} tidak ditemukan di {column}")
            fields[column] = fields[column].replace(wrong, right)
        penjelasan = fields["penjelasan"]
        mk_note = config.mk_notes.get(nomor)
        if mk_note:
            penjelasan = f"{penjelasan}\n{mk_note}".strip()
        # Riwayat menampilkan rumusan yang berlaku persis seperti isi pasal.
        latest.isi, latest.penjelasan = fields["isi"], penjelasan

        record = PasalRecord(
            nomor=nomor,
            headings=chain,
            isi=fields["isi"],
            penjelasan=penjelasan,
            status=status,
            original_isi=original_isi,
            original_penjelasan=original_penjelasan,
            notes=[mk_note.split(":")[0]] if mk_note else [],
            versions=versions,
        )
        if record.status != REPEALED:
            record.catatan = "\n\n".join(rule.text for rule in config.catatan_rules if rule.matches(record))
        records.append(record)
    check_catatan_rules(config, records)
    return records, amendments


def check_catatan_rules(config: LawConfig, records: list[PasalRecord]) -> None:
    """Aturan catatan yang tidak mengenai satu pasal pun berarti label/nomornya salah ketik."""
    known = {r.nomor for r in records}
    for rule in config.catatan_rules:
        missing = [n for n in rule.nomor if n not in known]
        if missing:
            raise PipelineError(f"catatan_rules: Pasal {', '.join(missing)} tidak ada.")
        for bab in rule.bab or (None,):
            single = CatatanRule(rule.text, rule.buku, (bab,) if bab else (), rule.nomor)
            if not any(single.matches(r) for r in records):
                raise PipelineError(f"catatan_rules: tidak ada pasal di {rule.buku} {bab or ''}".strip() + ".")


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


# Nomor sisipan: "599A" (UU baru) atau "1601a"/"1152bis" (KUHPerdata).
PASAL_MENTION = re.compile(r"\bPasal\s+(\d+(?:[A-Z]|[a-z]{1,3})?)\b((?:\s+ayat\s*\(\d+[a-z]?\))?(?:\s+huruf\s+[a-z]{1,2}\b)?(?:\s+angka\s+\d+\b)?)")
CHAIN_GAP = re.compile(
    r"(?:\s*(?:ayat\s*\(\d+[a-z]?\)|huruf\s+[a-z]{1,2}\b|angka\s+\d+\b|,|dan/atau|dan|atau|serta|sampai\s+dengan)\s*)*",
    re.I,
)
EXTERNAL_LAW = re.compile(
    r"\s*(?:Undang-Undang|UU\b|Peraturan|Kitab|Ordonnantie|Ordonansi|Wetboek|Staatsblad|Stbl|Perppu"
    r"|Ketentuan-Ketentuan Umum|Reglemen|Reglement|Faillissements)",
    re.I,
)


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
    amendment = record.versions[-1].amendment
    return f"{record.status} {amendment.label}" if amendment else record.status


RIWAYAT_HEADERS = [
    "nomor",
    "urutan",
    "status",
    "sumber",
    "judul_sumber",
    "diundangkan",
    "berlaku_sejak",
    "naskah_resmi",
    "isi",
    "penjelasan",
]


def has_history(record: PasalRecord) -> bool:
    return len(record.versions) > 1 or record.versions[0].status != ORIGINAL


def history_rows(config: LawConfig, records: list[PasalRecord]) -> list[dict[str, object]]:
    """Semua versi pasal yang pernah berubah, dari rumusan asli sampai rumusan yang berlaku."""
    rows: list[dict[str, object]] = []
    for record in records:
        if not has_history(record):
            continue
        for urutan, version in enumerate(record.versions, start=1):
            amendment = version.amendment
            rows.append(
                {
                    "nomor": record.nomor,
                    "urutan": urutan,
                    "status": version.status,
                    "sumber": amendment.label if amendment else config.label,
                    "judul_sumber": amendment.full_title if amendment else config.nama_lengkap,
                    "diundangkan": amendment.diundangkan if amendment else config.diundangkan,
                    "berlaku_sejak": amendment.berlaku_sejak if amendment else config.berlaku_sejak,
                    "naskah_resmi": amendment.official_url if amendment else config.bpk_detail_url,
                    "isi": version.isi,
                    "penjelasan": version.penjelasan,
                }
            )
    return rows


def consolidation_label(amendments: tuple[Amendment, ...]) -> str:
    if len(amendments) <= 3:
        return ", ".join(a.label for a in amendments)
    return f"{len(amendments)} peraturan perubahan, terakhir {amendments[-1].label}"


def write_xlsx(
    config: LawConfig,
    records: list[PasalRecord],
    review: list[dict[str, object]],
    amendments: tuple[Amendment, ...],
) -> dict[str, list]:
    wb = Workbook()
    ws = wb.active
    ws.title = "import"
    known = {record.nomor for record in records}
    links = {record.nomor: cross_references(record, known, config) for record in records}
    link_slots = max((len(found) for found in links.values()), default=0)
    # Kolom catatan hanya ada kalau UU ini punya catatan redaksi; tanpa kolom, import tidak
    # menyentuh catatan yang diisi admin.
    with_catatan = bool(config.catatan_rules)
    headers = ["nomor", "judul", "isi", "penjelasan", *(["catatan"] if with_catatan else []), "keywords"]
    for slot in range(1, link_slots + 1):
        headers += [f"link{slot}_targetUU", f"link{slot}_targetNomor", f"link{slot}_keterangan"]
    ws.append(headers)
    for record in records:
        row = [record.nomor, judul_for(record), record.isi, record.penjelasan]
        row += [record.catatan] if with_catatan else []
        row += [keywords_for(record)]
        for nomor, phrase in links[record.nomor]:
            row += [config.kode, nomor, f"Disebut dalam isi: {phrase}"]
        ws.append(row)

    review_ws = wb.create_sheet("review")
    review_headers = ["nomor", "status_teks", "bab", "cakupan_isi_pdf", "cakupan_penjelasan_pdf", "perlu_review", "catatan"]
    review_ws.append(review_headers)
    for row in review:
        review_ws.append([row[h] for h in review_headers])

    history = history_rows(config, records)
    history_ws = None
    if history:
        history_ws = wb.create_sheet("riwayat")
        history_ws.append(RIWAYAT_HEADERS)
        for row in history:
            history_ws.append([row[h] for h in RIWAYAT_HEADERS])

    meta = wb.create_sheet("catatan")
    suffix = f" (konsolidasi dengan {consolidation_label(amendments)})" if amendments else ""
    meta.append(["Judul", config.nama_lengkap + suffix])
    meta.append(["Jumlah pasal", len(records)])
    meta.append(["Sumber teks", config.datahukum_url])
    if config.bpk_detail_url:
        meta.append(["Pembanding resmi", config.bpk_detail_url])
    if config.catatan_teks:
        meta.append(["Status teks", config.catatan_teks])
    meta.append(["Catatan", f"Upload file ini lewat menu Import Data. Pilih UU kode {config.kode} sebelum import."])
    if history_ws is not None:
        meta.append(["Riwayat", "Sheet 'riwayat' ikut dibaca saat import: semua versi rumusan tiap pasal yang pernah berubah."])

    header_fill = PatternFill("solid", fgColor="1F4E78")
    for sheet in (ws, review_ws, history_ws):
        if sheet is None:
            continue
        for cell in sheet[1]:
            cell.font = Font(bold=True, color="FFFFFF")
            cell.fill = header_fill
            cell.alignment = Alignment(horizontal="center")
        for row in sheet.iter_rows(min_row=2):
            for cell in row:
                cell.alignment = Alignment(vertical="top", wrap_text=True)
        sheet.freeze_panes = "A2"
    widths = [10, 48, 90, 70, *([60] if with_catatan else []), 42]
    for index, width in enumerate(widths):
        ws.column_dimensions[chr(ord("A") + index)].width = width
    for column, width in {"A": 10, "B": 22, "C": 48, "D": 16, "E": 20, "F": 12, "G": 90}.items():
        review_ws.column_dimensions[column].width = width
    if history_ws is not None:
        for column, width in {"A": 10, "B": 8, "C": 12, "D": 12, "E": 48, "F": 14, "G": 14, "H": 40, "I": 90, "J": 70}.items():
            history_ws.column_dimensions[column].width = width
    meta.column_dimensions["A"].width = 20
    meta.column_dimensions["B"].width = 100

    config.output_dir.mkdir(parents=True, exist_ok=True)
    wb.save(config.output_dir / config.xlsx_name)
    return links


def listing(nomors: list[str], limit: int = 60) -> str:
    if len(nomors) <= limit:
        return ", ".join(nomors)
    return f"{', '.join(nomors[:limit])}, dan {len(nomors) - limit} lainnya (lihat sheet `review`)"


def amendment_table(records: list[PasalRecord], amendments: tuple[Amendment, ...]) -> str:
    counts = {a.doc_class: {CHANGED: 0, INSERTED: 0, REPEALED: 0} for a in amendments}
    for record in records:
        for version in record.versions:
            if version.amendment is not None:
                counts[version.amendment.doc_class][version.status] += 1
    rows = [
        f"| {a.label} | {a.full_title.split(' tentang ', 1)[-1] if ' tentang ' in a.full_title else '-'} | "
        f"{counts[a.doc_class][CHANGED]} | {counts[a.doc_class][INSERTED]} | {counts[a.doc_class][REPEALED]} |"
        for a in amendments
    ]
    return "| Peraturan | Tentang | Diubah | Disisipkan | Dicabut/dihapus |\n|---|---|---|---|---|\n" + "\n".join(rows)


def write_readme(
    config: LawConfig,
    records: list[PasalRecord],
    review: list[dict[str, object]],
    links: dict[str, list],
    amendments: tuple[Amendment, ...],
) -> None:
    flagged = [row for row in review if row["perlu_review"] == "ya"]
    flagged_lines = "\n".join(f"| {row['nomor']} | {row['catatan']} |" for row in flagged) or "| - | - |"
    inserted = [r.nomor for r in records if r.status == INSERTED]
    numbered = [r.nomor for r in records if r.status != INSERTED]
    span = f"Pasal {numbered[0]} sampai {numbered[-1]}"
    if inserted:
        span += f" ditambah Pasal {', '.join(inserted)}" if len(inserted) <= 10 else f" ditambah {len(inserted)} pasal sisipan"
    link_count = sum(len(found) for found in links.values())
    with_pdf = bool(config.bpk_pdf_url)

    consolidation = ""
    sources = [f"1. Teks terstruktur: {config.datahukum_url} (pihak ketiga, bukan sumber resmi)"]
    if config.bpk_detail_url:
        sources.append(f"{len(sources) + 1}. Pembanding resmi: {config.bpk_detail_url} (PDF salinan, hasil scan/OCR)")
    if amendments:
        isi_changed = [r.nomor for r in records if r.status.startswith("isi")]
        pj_changed = [r.nomor for r in records if r.status == "penjelasan diubah"]
        repealed = [r.nomor for r in records if r.status == REPEALED]
        history_count = len(history_rows(config, records))
        title = amendments[0].title if len(amendments) == 1 else f"{len(amendments)} peraturan perubahan (tabel di bawah)"
        consolidation = (
            f"- Teks sudah dikonsolidasi dengan {title}:\n"
            f"  - isi pasal diubah ({len(isi_changed)}): {listing(isi_changed)}\n"
            + (f"  - hanya penjelasan diubah ({len(pj_changed)}): {listing(pj_changed)}\n" if any(r.penjelasan for r in records) else "")
            + f"  - pasal sisipan ({len(inserted)}): {listing(inserted)}\n"
            f"  - pasal dihapus/dicabut, isinya \"{config.repealed_text}\" ({len(repealed)}): {listing(repealed)}\n"
            f"- Sheet `riwayat` berisi {history_count} versi: semua rumusan tiap pasal yang pernah berubah, dari "
            f"{config.label} sampai rumusan yang berlaku, masing-masing dengan sumber dan link naskah resminya (kalau ada). "
            "Import menyimpannya sebagai riwayat pasal.\n"
        )
        for amendment in amendments:
            if amendment.pdf:
                sources.append(f"{len(sources) + 1}. Rumusan perubahan {amendment.title}: `{amendment.pdf}`")
    mk = ""
    if config.mk_notes:
        mk = f"- Pasal {', '.join(config.mk_notes)} diberi catatan Putusan MK di kolom penjelasan.\n"
    catatan = ""
    if config.catatan_rules:
        noted = [r.nomor for r in records if r.catatan]
        catatan = (
            f"- `catatan` (catatan CariPasal, bukan bagian naskah) diisi untuk {len(noted)} pasal: status berlaku\n"
            "  menurut undang-undang yang lebih baru. Aturannya ada di `catatan_rules` konfigurasi.\n"
        )
    penjelasan = "- `penjelasan` diisi penjelasan resmi.\n" if any(r.penjelasan for r in records) else "- `penjelasan` kosong: undang-undang ini tidak punya penjelasan resmi.\n"
    extra = "".join(f"- {note}\n" for note in config.readme_notes)
    no_link_titles = " dan ".join(title_case(t) for t in sorted(config.no_link_bab_titles))
    no_link = f", begitu juga Bab {no_link_titles} (isinya memetakan pasal UU lain)" if no_link_titles else ""
    fixes = sum(len(v) for v in config.text_fixes.values())

    if with_pdf:
        amended_pdfs = [a.label for a in amendments if a.pdf]
        comparison = f"BPK, rumusan perubahan ke PDF {', '.join(amended_pdfs)})" if amended_pdfs else "BPK)"
        checks = f"""Kesalahan sumber HTML yang diperbaiki otomatis: butir ayat/huruf yang hilang, label penjelasan yang
menempel ke paragraf lain, kalimat yang terpotong jadi dua paragraf, dan judul bagian yang tergeser satu
pasal (dicek ke PDF). Typo per pasal ada di `text_fixes` ({fixes} perbaikan, tiap entri dicek ke PDF).
Typo dicari dari kata yang tidak dikenal kamus dan tidak ada di PDF. Typo yang kebetulan membentuk kata
lain yang sah tidak bisa dipastikan otomatis, jadi verifikasi admin terhadap PDF resmi tetap diperlukan.

`cakupan_*_pdf` = porsi huruf pada teks kita yang ditemukan di PDF resmi (rumusan asli dicek ke PDF
{comparison}. Nilai di bawah {REVIEW_COVERAGE_THRESHOLD:.0%} atau butir ayat/huruf yang kosong ditandai
`perlu_review`. PDF resmi adalah hasil scan, jadi skor rendah biasanya berasal dari OCR PDF (kata hilang
di ujung baris). Pasal berskor rendah yang sudah dicek manual tercatat di `manual_review` dan kolom
`catatan`."""
    else:
        checks = f"""Tidak ada naskah resmi berbahasa Indonesia untuk dibandingkan, jadi kolom `cakupan_*_pdf` kosong.
Pemeriksaan otomatis yang dipakai: semua versi rumusan dipindai untuk sisa teks penerjemah atau chatbot
("Berikut terjemahannya", "File ini", markdown), kata ganti percakapan, kata Belanda yang tertinggal, judul
pasal lain di dalam isi, dan butir ayat/huruf kosong. Temuan ditandai `perlu_review`. Perbaikan per pasal
ada di `text_fixes` ({fixes} perbaikan). Kesalahan terjemahan yang halus tidak bisa dideteksi otomatis."""

    official = (
        f"`{config.bpk_detail_url}`" if config.bpk_detail_url else "kosongkan (tidak ada naskah resmi berbahasa Indonesia)"
    )
    status_teks = f"\n   - Catatan status teks: `{config.catatan_teks}`" if config.catatan_teks else ""
    example = inserted[0] if inserted else numbered[-1]
    table = f"\n### Peraturan perubahan\n\n{amendment_table(records, amendments)}\n" if len(amendments) > 1 else ""

    readme = f"""# Import {config.kode} ({config.nama_lengkap})

File ini dibuat oleh `{SCRIPT} {config.slug}`. Jangan edit manual; perbaiki konfigurasi di
`import-tools/laws/` atau mesinnya di `import-tools/datahukum_pipeline.py`, lalu jalankan ulang.

## Isi

- `{config.xlsx_name}`
  - sheet `import`: {len(records)} pasal ({span}).
  - sheet `review`: hasil pemeriksaan tiap pasal{" dengan PDF resmi" if with_pdf else ""}.
{consolidation}- `judul` diisi judul paragraf/bagian/bab tempat pasal berada (tidak ada judul per pasal).
{penjelasan}{mk}{catatan}- `keywords` (topik): judul bab dan bagian tempat pasal berada. Tidak perlu diisi manual.
- `linkN_*` (pasal terkait, {link_count} link): rujukan ke pasal lain di {config.kode} yang disebut di isi
  pasal, misalnya "sebagaimana dimaksud dalam Pasal 54". Rujukan yang diikuti nama undang-undang lain
  dilewati{no_link}.
  Maksimal {MAX_LINKS_PER_PASAL} per pasal.
{extra}{table}
## Sumber

{chr(10).join(sources)}

{checks}

## Cara import

1. Admin dashboard → menu `Undang-Undang`. Pastikan ada UU kode `{config.kode}`:
   - Nama: `{config.nama}`
   - Nama lengkap: `{config.nama_lengkap}`
   - Tahun: `{config.tahun}`
   - Link naskah resmi: {official}
   - Sumber teks: `{config.datahukum_url}`{status_teks}
2. Menu `Import Data` → mode XLSX → pilih UU `{config.kode}` → upload file xlsx.
3. Import memakai `updateOrCreate` per (UU, nomor): pasal yang sudah ada akan ditimpa,
   pasal lain di UU yang sama tidak dihapus.
4. Nomor disimpan tanpa awalan "Pasal" (contoh `1`, `{example}`). Data lama dengan nomor `Pasal 1`
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


# Sisa teks penerjemah/chatbot dan kata asing yang tidak semestinya ada di naskah pasal.
ARTEFACT_PATTERNS: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"\bterjemahannya\b|\bBerikut (?:ini )?(?:adalah )?terjemah", re.I), "sisa teks penerjemah"),
    (re.compile(r"(?:^|\n)(?:Benar|Baik|Tentu|Oke|Siap)[.,!]\s"), "kalimat pembuka percakapan"),
    (re.compile(r"\b(?:file|File|FILE)\b"), "kata 'file'"),
    (re.compile(r"\bterlewat\b", re.I), "kata 'terlewat'"),
    (re.compile(r"\b(?:saya|Anda|kamu)\b"), "kata ganti percakapan"),
    (re.compile(r"\*\*|```|^#{1,6}\s", re.M), "format markdown"),
    (re.compile(r"(?:^|\n)Pasal \d+[A-Za-z]*\s*(?:\n|$)"), "judul pasal di dalam isi"),
)
DUTCH_WORDS = re.compile(r"\b(?:het|een|niet|zijn|wordt|worden|ingevolge|bij|tot|ook|naar|deze|welke|zal|kan)\b")


def artefact_findings(record: PasalRecord) -> list[str]:
    """Temuan QA di semua versi rumusan pasal (versi lama juga tampil di riwayat)."""
    found: list[str] = []
    for version in record.versions:
        text = f"{version.isi}\n{version.penjelasan}"
        for pattern, label in ARTEFACT_PATTERNS:
            if pattern.search(text) and label not in found:
                found.append(label)
        dutch = set(DUTCH_WORDS.findall(text))
        if len(dutch) >= 3 and "kata Belanda tertinggal" not in found:
            found.append("kata Belanda tertinggal")
    return found


@dataclass
class Analysis:
    records: list[PasalRecord]
    amendments: tuple[Amendment, ...]
    review: list[dict[str, object]]
    body: PdfIndex | None
    explanation: PdfIndex | None
    warnings: list[dict[str, str]]
    unknown_versions: list[str]


@dataclass
class OfficialPdfs:
    body: Path | None  # PDF BPK UU utama
    amendments: dict[str, Path]  # doc_class -> PDF UU perubahan


def official_pdfs(config: LawConfig) -> OfficialPdfs:
    """Unduh (atau ambil dari cache) PDF resmi pembanding. Daftar perubahan dari HTML tidak punya PDF."""
    body = fetch(config.bpk_pdf_url, CACHE_DIR / f"bpk_{config.slug}.pdf") if config.bpk_pdf_url else None
    amendments = {a.doc_class: fetch(a.pdf_url, CACHE_DIR / a.pdf) for a in config.amendments if a.pdf}
    return OfficialPdfs(body, amendments)


def analyze(config: LawConfig, html_path: Path, pdfs: OfficialPdfs, lenient: bool) -> Analysis:
    """Parse HTML, bandingkan dengan PDF resmi bila ada, pindai artefak. `lenient` = mode --json."""
    warnings: list[dict[str, str]] = []
    unknown: set[str] = set()
    records, amendments = parse_datahukum(html_path, config, warnings, unknown, strict_fixes=not lenient)
    original_order = [r.nomor for r in records if r.status != INSERTED]

    body = explanation = None
    heading_fixes: dict[str, str] = {}
    if pdfs.body is not None:
        pages = [page.get_text() for page in pymupdf.open(pdfs.body)]
        body = index_pdf(pages[config.body_pages[0] - 1 : config.body_pages[1]], original_order)
        explanation = index_pdf(pages[config.penjelasan_pages[0] - 1 : config.penjelasan_pages[1]], original_order)
        heading_fixes = fix_heading_placement(records, body)
    amended_folded = {
        doc_class: ocr_fold("\n".join(page.get_text() for page in pymupdf.open(path)))
        for doc_class, path in pdfs.amendments.items()
    }

    review = []
    for record in records:
        notes = list(record.notes)
        if record.nomor in heading_fixes:
            notes.append(heading_fixes[record.nomor])
        latest = record.versions[-1].amendment
        if record.status == REPEALED:
            notes.append(f"Dihapus/dicabut oleh {latest.label}; teks lama di HTML diabaikan")

        # Rumusan asli dicek ke PDF BPK, rumusan perubahan ke PDF UU perubahan.
        isi_cov: float | None = None
        pj_cov: float | None = None
        if body is not None and explanation is not None:
            isi_cov = official_coverage(record.original_isi, body, record.nomor, original_order) if record.original_isi else 1.0
            pj_cov = (
                official_coverage(record.original_penjelasan, explanation, record.nomor, original_order)
                if record.original_penjelasan
                else 1.0
            )
        folded = amended_folded.get(latest.doc_class) if latest else None
        if folded is not None and (record.status.startswith("isi") or record.status == INSERTED):
            amended = fragment_coverage(record.isi, folded)
            notes.append(f"Isi versi {latest.label} cocok {amended:.0%} dengan PDF {latest.label}")
            isi_cov = amended if isi_cov is None else min(isi_cov, amended)
        if folded is not None and ("penjelasan" in record.status or (record.status == INSERTED and record.penjelasan)):
            amended = fragment_coverage(record.penjelasan, folded)
            notes.append(f"Penjelasan versi {latest.label} cocok {amended:.0%} dengan PDF {latest.label}")
            pj_cov = amended if pj_cov is None else min(pj_cov, amended)

        empty_item = bool(re.search(r"^(\(\d+[a-z]?\)|[a-z]\.|\d+\.)$", record.isi + "\n" + record.penjelasan, re.M))
        if empty_item:
            notes.append("Ada butir ayat/huruf kosong")
        low = any(cov is not None and cov < REVIEW_COVERAGE_THRESHOLD for cov in (isi_cov, pj_cov))
        if low:
            notes.append("Cakupan teks terhadap PDF rendah")
        artefacts = artefact_findings(record)
        if artefacts:
            notes.append(f"Periksa teks: {', '.join(artefacts)}")
        needs_review = low or empty_item or bool(artefacts)
        if record.nomor in config.manual_review:
            notes.append(config.manual_review[record.nomor])
            needs_review = empty_item
        bab = next((h for h in record.headings if h.kind == "bab"), None)
        review.append(
            {
                "nomor": record.nomor,
                "status_teks": status_label(record, config),
                "bab": f"{bab.label} {title_case(bab.title)}" if bab else "",
                "cakupan_isi_pdf": round(isi_cov, 3) if isi_cov is not None else None,
                "cakupan_penjelasan_pdf": round(pj_cov, 3) if pj_cov is not None else None,
                "perlu_review": "ya" if needs_review else "tidak",
                "catatan": "; ".join(notes),
            }
        )
    return Analysis(records, amendments, review, body, explanation, warnings, sorted(unknown))


def run(config: LawConfig) -> None:
    html_path = fetch(config.datahukum_url, CACHE_DIR / f"datahukum_{config.slug}.html")
    analysis = analyze(config, html_path, official_pdfs(config), lenient=False)
    records, review = analysis.records, analysis.review

    links = write_xlsx(config, records, review, analysis.amendments)
    write_readme(config, records, review, links, analysis.amendments)

    flagged = sum(1 for row in review if row["perlu_review"] == "ya")
    print(f"[{config.slug}] output: {config.output_dir}")
    print(f"[{config.slug}] pasal: {len(records)} | link: {sum(len(v) for v in links.values())} | perlu review: {flagged}")
    if analysis.body is not None and analysis.explanation is not None:
        print(f"[{config.slug}] header pasal terbaca di PDF: batang tubuh {len(analysis.body.starts)}, penjelasan {len(analysis.explanation.starts)}")
    for warning in analysis.warnings:
        print(f"[{config.slug}] peringatan: {warning['message']}")
    if analysis.unknown_versions:
        print(f"[{config.slug}] class versi tidak dikenal: {', '.join(analysis.unknown_versions)}")


def run_json(config: LawConfig, refresh: bool, previous_count: int | None = None) -> dict[str, object]:
    """Hasil pipeline sebagai dict JSON (Contract A). Tidak menulis xlsx/README."""
    html_path = CACHE_DIR / f"datahukum_{config.slug}.html"
    try:
        if refresh or not (html_path.exists() and html_path.stat().st_size > 0):
            # Unduhan baru dipakai (dan menggantikan cache) hanya kalau lolos parse.
            candidate = download(config.datahukum_url, html_path.with_name(html_path.name + ".new"))
        else:
            candidate = html_path
        pdfs = official_pdfs(config)
    except OSError as error:
        raise PipelineError(f"Gagal mengunduh sumber: {error}") from error

    try:
        analysis = analyze(config, candidate, pdfs, lenient=True)
        if previous_count and len(analysis.records) < previous_count * 0.98:
            raise PipelineError(
                f"Jumlah pasal turun dari {previous_count} menjadi {len(analysis.records)} (lebih dari 2%); "
                "kemungkinan struktur sumber berubah."
            )
    except PipelineError:
        if candidate != html_path:
            candidate.unlink(missing_ok=True)
        raise
    except Exception as error:
        if candidate != html_path:
            candidate.unlink(missing_ok=True)
        raise PipelineError(f"Gagal membaca sumber: {type(error).__name__}: {error}") from error
    if candidate != html_path:
        os.replace(candidate, html_path)

    records = analysis.records
    known = {record.nomor for record in records}
    history: dict[str, list[dict[str, object]]] = {}
    for row in history_rows(config, records):
        history.setdefault(str(row["nomor"]), []).append({k: v for k, v in row.items() if k != "nomor"})
    reviews = {str(row["nomor"]): row for row in analysis.review}

    pasal = []
    for record in records:
        review = reviews[record.nomor]
        pasal.append(
            {
                "nomor": record.nomor,
                "judul": judul_for(record),
                "isi": record.isi,
                "penjelasan": record.penjelasan,
                "catatan": record.catatan or None,
                "keywords": [k for k in keywords_for(record).split(", ") if k],
                "links": [
                    {"targetUU": config.kode, "targetNomor": nomor, "keterangan": f"Disebut dalam isi: {phrase}"}
                    for nomor, phrase in cross_references(record, known, config)
                ],
                "riwayat": history.get(record.nomor, []),
                "status_teks": record.status,
                "review": {
                    "cakupan_isi_pdf": review["cakupan_isi_pdf"],
                    "cakupan_penjelasan_pdf": review["cakupan_penjelasan_pdf"],
                    "perlu_review": review["perlu_review"] == "ya",
                    "catatan": review["catatan"],
                },
            }
        )
    fetched = datetime.fromtimestamp(html_path.stat().st_mtime, tz=timezone.utc)
    return {
        "slug": config.slug,
        "kode": config.kode,
        "source_url": config.datahukum_url,
        "fetched_at": fetched.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "html_sha256": hashlib.sha256(html_path.read_bytes()).hexdigest(),
        "unknown_versions": analysis.unknown_versions,
        "metrics": {"pasal_count": len(records)},
        "warnings": analysis.warnings,
        "pasal": pasal,
    }
