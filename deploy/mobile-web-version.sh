#!/usr/bin/env bash
# Mencetak ID build mobile web: commit terakhir yang mengubah input build Flutter Web.
# Dipakai workflow .github/workflows/mobile-web.yml (nama file rilis) dan
# deploy/aapanel-publish-mobile-web.sh (file yang diunduh), jadi keduanya selalu sepakat.
# Commit yang hanya mengubah backend/admin tidak mengubah ID, sehingga build lama tetap dipakai.
# Daftar path ini harus sama dengan `paths` di mobile-web.yml.
set -euo pipefail

repo="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
id="$(git -C "$repo" log -1 --format=%H -- \
  pasal_mobile_app \
  .github/workflows/mobile-web.yml \
  deploy/mobile-web-version.sh)"

if [[ -z "$id" ]]; then
  printf 'Tidak bisa menentukan versi mobile web dari riwayat git di %s\n' "$repo" >&2
  exit 1
fi
printf '%s\n' "${id:0:12}"
