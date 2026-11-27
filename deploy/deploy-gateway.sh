#!/usr/bin/env bash
# Forced command for the GitHub Actions deploy key.
# Accepts exactly: deploy <caripasal|sita> sha-<hex>
# Anything else is refused before a shell is spawned.
set -euo pipefail

read -r verb app tag extra <<<"${SSH_ORIGINAL_COMMAND:-}"

if [ "${verb:-}" != "deploy" ] || [ -n "${extra:-}" ]; then
    echo "ditolak: perintah harus 'deploy <app> sha-<commit>'" >&2
    exit 64
fi

if ! printf '%s' "${tag:-}" | grep -Eq '^sha-[0-9a-f]{7,40}$'; then
    echo "ditolak: tag tidak valid" >&2
    exit 65
fi

case "${app:-}" in
    caripasal)
        exec env TAG="$tag" /home/aji/deployments/caripasal/deploy/deploy-caripasal.sh
        ;;
    sita)
        exec env TAG="$tag" /home/aji/deployments/sita/deploy-sita.sh
        ;;
    *)
        echo "ditolak: app tidak dikenal" >&2
        exit 66
        ;;
esac
