#!/usr/bin/env bash
set -euo pipefail

# Unduh build Flutter Web dari rilis GitHub lalu salin ke $APP_ROOT/mobile.
# Build dibuat oleh .github/workflows/mobile-web.yml; server tidak butuh Flutter.

APP_ROOT="${APP_ROOT:-/www/wwwroot/hukum-ubg.ac.id/projek-pasal}"
DOMAIN="${DOMAIN:-ubgpasal.ubg.ac.id}"
MOBILE_DIR="${MOBILE_DIR:-$APP_ROOT/mobile}"
WEB_USER="${WEB_USER:-www}"
WEB_GROUP="${WEB_GROUP:-www}"
RELOAD_NGINX="${RELOAD_NGINX:-1}"
GITHUB_REPO="${GITHUB_REPO:-RikiSanjayaa/projek-pasal}"
MOBILE_WEB_RELEASE="${MOBILE_WEB_RELEASE:-mobile-web}"
MOBILE_WEB_VERSION="${MOBILE_WEB_VERSION:-$(bash "$APP_ROOT/deploy/mobile-web-version.sh" "$APP_ROOT")}"

log() {
  printf "\n[%s] %s\n" "$(date '+%H:%M:%S')" "$1"
}

for tool in curl tar sha256sum; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'Perintah %s tidak ditemukan di server.\n' "$tool" >&2
    exit 1
  }
done

name="caripasal-mobile-web-$MOBILE_WEB_VERSION.tar.gz"
url="https://github.com/$GITHUB_REPO/releases/download/$MOBILE_WEB_RELEASE/$name"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "Mengunduh mobile web build $MOBILE_WEB_VERSION"
if ! curl -fsSL --retry 3 -o "$tmp/$name" "$url" || ! curl -fsSL --retry 3 -o "$tmp/$name.sha256" "$url.sha256"; then
  printf '\nBuild mobile web %s belum tersedia di %s\n' "$MOBILE_WEB_VERSION" "$url" >&2
  printf 'Build dibuat otomatis oleh GitHub Actions beberapa menit setelah push ke main.\n' >&2
  printf 'Cek https://github.com/%s/actions/workflows/mobile-web.yml lalu ulangi perintah ini.\n' "$GITHUB_REPO" >&2
  exit 1
fi
(cd "$tmp" && sha256sum -c "$name.sha256" >/dev/null) || {
  printf 'Checksum %s tidak cocok; file rusak saat diunduh. Ulangi perintah ini.\n' "$name" >&2
  exit 1
}

mkdir "$tmp/web"
tar -xzf "$tmp/$name" -C "$tmp/web"
for asset in index.html caripasal-sw.js offline.js offline-build.json; do
  if [[ ! -s "$tmp/web/$asset" ]]; then
    printf 'Build %s tidak lengkap: %s tidak ada.\n' "$MOBILE_WEB_VERSION" "$asset" >&2
    exit 1
  fi
done

log "Publishing Flutter Web mobile build"
mkdir -p "$MOBILE_DIR"
rm -rf "${MOBILE_DIR:?}"/*
cp -r "$tmp/web"/. "$MOBILE_DIR"/

log "Fixing permissions"
if command -v sudo >/dev/null 2>&1; then
  sudo chown -R "$WEB_USER:$WEB_GROUP" "$MOBILE_DIR" || true
else
  chown -R "$WEB_USER:$WEB_GROUP" "$MOBILE_DIR" || true
fi
chmod -R 755 "$MOBILE_DIR" || true

if [[ "$RELOAD_NGINX" == "1" ]]; then
  log "Reloading Nginx"
  if command -v sudo >/dev/null 2>&1; then
    sudo /etc/init.d/nginx reload || true
  else
    /etc/init.d/nginx reload || true
  fi
fi

log "Mobile web $MOBILE_WEB_VERSION published"
printf "Open: https://%s/mobile/\n" "$DOMAIN"
