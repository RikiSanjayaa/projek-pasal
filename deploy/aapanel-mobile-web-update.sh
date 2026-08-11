#!/usr/bin/env bash
set -euo pipefail

# One-command updater for the Flutter Web mobile page.
# This intentionally does not build Flutter on the server. The server only pulls
# the committed mobile-web-dist artifact and publishes it to /mobile/.

APP_ROOT="${APP_ROOT:-/www/wwwroot/hukum-ubg.ac.id/projek-pasal}"
DOMAIN="${DOMAIN:-ubgpasal.ubg.ac.id}"
BRANCH="${BRANCH:-main}"
SKIP_GIT="${SKIP_GIT:-0}"
MOBILE_URL="${MOBILE_URL:-https://$DOMAIN/mobile/}"
API_HEALTH_URL="${API_HEALTH_URL:-https://$DOMAIN/api/health}"

log() {
  printf "\n[%s] %s\n" "$(date '+%H:%M:%S')" "$1"
}

require_dir() {
  if [[ ! -d "$1" ]]; then
    printf "Missing required directory: %s\n" "$1" >&2
    exit 1
  fi
}

require_file() {
  if [[ ! -f "$1" ]]; then
    printf "Missing required file: %s\n" "$1" >&2
    exit 1
  fi
}

log "Checking project"
require_dir "$APP_ROOT"
require_dir "$APP_ROOT/deploy"

cd "$APP_ROOT"

if [[ "$SKIP_GIT" != "1" ]]; then
  log "Updating source from GitHub"
  git fetch origin
  git checkout "$BRANCH"
  git pull --ff-only origin "$BRANCH"
else
  log "Skipping git update because SKIP_GIT=1"
fi

require_file "$APP_ROOT/mobile-web-dist/index.html"
require_file "$APP_ROOT/deploy/aapanel-publish-mobile-web.sh"

log "Publishing mobile web"
APP_ROOT="$APP_ROOT" \
DOMAIN="$DOMAIN" \
bash "$APP_ROOT/deploy/aapanel-publish-mobile-web.sh"

if command -v curl >/dev/null 2>&1; then
  log "Checking mobile URL"
  curl -fsSI "$MOBILE_URL" >/dev/null || {
    printf "Mobile web check failed: %s\n" "$MOBILE_URL" >&2
    exit 1
  }

  log "Checking API health"
  curl -fsS "$API_HEALTH_URL" || {
    printf "\nAPI health check failed: %s\n" "$API_HEALTH_URL" >&2
    exit 1
  }
  printf "\n"
else
  log "curl not found, skipping URL checks"
fi

log "Mobile web update complete"
printf "Open: %s\n" "$MOBILE_URL"
