#!/usr/bin/env python3
"""Import a database configuration snapshot using the shared parser.

prepare_import.py --config source.json --json result.json [--refresh] [--previous-count N]
Without --json, produces the existing xlsx/review export for this snapshot.
"""

import argparse
import json
from pathlib import Path
import sys

from datahukum_pipeline import PipelineError, run, run_json
from source_config import load_config


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True, type=Path)
    parser.add_argument('--json', type=Path, metavar='OUT')
    parser.add_argument('--refresh', action='store_true')
    parser.add_argument('--previous-count', type=int)
    args = parser.parse_args(argv)
    try:
        config = load_config(args.config)
        if args.json:
            write_json(args.json, run_json(config, args.refresh, args.previous_count))
        else:
            run(config)
    except PipelineError as error:
        if args.json:
            write_json(args.json, {'error': str(error)})
        print(str(error), file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
