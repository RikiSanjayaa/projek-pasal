"""Siapkan file Bulk Import untuk undang-undang yang terdaftar di `laws/`.

Jalankan:
    python -m venv .venv && .venv/bin/pip install -r import-tools/requirements.txt
    .venv/bin/python import-tools/prepare_import.py kuhp-2023
    .venv/bin/python import-tools/prepare_import.py all

Mode JSON (dipakai backend Laravel untuk impor dari dashboard admin):
    prepare_import.py --list --json                      daftar UU terdaftar (JSON ke stdout)
    prepare_import.py <slug> --json out.json [--refresh] hasil pipeline sebagai JSON, tanpa xlsx/README

Sumber HTML dan PDF disimpan di `import-tools/.cache/` (tidak di-commit), atau di folder
`IMPORT_CACHE_DIR` kalau variabel itu diisi.
"""

import argparse
import json
import sys
from pathlib import Path

from datahukum_pipeline import PipelineError, run, run_json
from laws import LAWS


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("slug", nargs="?", help=f"{'|'.join(LAWS)}|all")
    parser.add_argument("--list", action="store_true", help="tampilkan UU terdaftar (butuh --json)")
    parser.add_argument("--json", nargs="?", const="-", metavar="OUT", help="mode JSON; OUT = file hasil")
    parser.add_argument("--refresh", action="store_true", help="unduh ulang HTML datahukum (PDF tetap dari cache)")
    parser.add_argument("--previous-count", type=int, help="jumlah pasal impor sebelumnya; gagal kalau turun >2%%")
    args = parser.parse_args(argv)

    if args.list:
        if args.json is None:
            parser.error("--list hanya didukung bersama --json")
        listing = [
            {
                "slug": law.slug,
                "kode": law.kode,
                "nama": law.nama,
                "label": law.label,
                "datahukum_url": law.datahukum_url,
                "bpk_detail_url": law.bpk_detail_url,
            }
            for law in LAWS.values()
        ]
        print(json.dumps(listing, ensure_ascii=False))
        return 0

    if args.json is not None:
        if args.slug not in LAWS or args.json == "-":
            parser.error(f"pakai: prepare_import.py <{'|'.join(LAWS)}> --json OUT")
        out = Path(args.json)
        try:
            write_json(out, run_json(LAWS[args.slug], args.refresh, args.previous_count))
        except PipelineError as error:
            write_json(out, {"error": str(error)})
            print(f"[{args.slug}] gagal: {error}", file=sys.stderr)
            return 2
        return 0

    if args.slug is None or (args.slug != "all" and args.slug not in LAWS):
        parser.error(f"pakai: prepare_import.py <{'|'.join(LAWS)}|all>")
    for slug in LAWS if args.slug == "all" else [args.slug]:
        run(LAWS[slug])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
