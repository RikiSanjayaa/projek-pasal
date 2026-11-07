"""Siapkan file Bulk Import untuk undang-undang yang terdaftar di `laws/`.

Jalankan:
    python -m venv .venv && .venv/bin/pip install pymupdf openpyxl beautifulsoup4
    .venv/bin/python import-tools/prepare_import.py kuhp-2023
    .venv/bin/python import-tools/prepare_import.py all

Sumber HTML dan PDF disimpan di `import-tools/.cache/` (tidak di-commit).
"""

import sys

from datahukum_pipeline import run
from laws import LAWS


def main(argv: list[str]) -> None:
    if len(argv) != 1 or (argv[0] != "all" and argv[0] not in LAWS):
        raise SystemExit(f"Pakai: prepare_import.py <{'|'.join(LAWS)}|all>")
    for slug in LAWS if argv[0] == "all" else [argv[0]]:
        run(LAWS[slug])


if __name__ == "__main__":
    main(sys.argv[1:])
