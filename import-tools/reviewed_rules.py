"""Reviewed legal transformations; source metadata lives in the database."""

import re

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