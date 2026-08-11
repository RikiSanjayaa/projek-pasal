#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="${APP_ROOT:-/www/wwwroot/hukum-ubg.ac.id/projek-pasal}"
DOMAIN="${DOMAIN:-ubgpasal.ubg.ac.id}"
MOBILE_DIST_DIR="${MOBILE_DIST_DIR:-$APP_ROOT/mobile-web-dist}"
MOBILE_DIR="${MOBILE_DIR:-$APP_ROOT/mobile}"
WEB_USER="${WEB_USER:-www}"
WEB_GROUP="${WEB_GROUP:-www}"
RELOAD_NGINX="${RELOAD_NGINX:-1}"

log() {
  printf "\n[%s] %s\n" "$(date '+%H:%M:%S')" "$1"
}

if [[ ! -f "$MOBILE_DIST_DIR/index.html" ]]; then
  printf "Mobile web build not found: %s\n" "$MOBILE_DIST_DIR/index.html" >&2
  printf "Build it on laptop with: ./build-mobile-web.ps1\n" >&2
  exit 1
fi

log "Publishing Flutter Web mobile build"
mkdir -p "$MOBILE_DIR"
rm -rf "$MOBILE_DIR"/*
cp -r "$MOBILE_DIST_DIR"/* "$MOBILE_DIR"/

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

log "Mobile web published"
printf "Open: https://%s/mobile/\n" "$DOMAIN"
