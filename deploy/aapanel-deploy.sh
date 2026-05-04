#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="${APP_ROOT:-/www/wwwroot/pasal}"
DOMAIN="${DOMAIN:-pasal.ikydev.site}"
PHP_BIN="${PHP_BIN:-/www/server/php/84/bin/php}"
COMPOSER_BIN="${COMPOSER_BIN:-}"
WEB_USER="${WEB_USER:-www}"
WEB_GROUP="${WEB_GROUP:-www}"
ADMIN_DIR="${ADMIN_DIR:-$APP_ROOT/admin}"
ADMIN_BASE_PATH="${ADMIN_BASE_PATH:-/admin/}"
API_BASE_URL="${API_BASE_URL:-https://$DOMAIN/api}"

if [[ -z "$COMPOSER_BIN" ]]; then
  if [[ -x /usr/local/bin/composer ]]; then
    COMPOSER_BIN=/usr/local/bin/composer
  elif [[ -x "$HOME/bin/composer" ]]; then
    COMPOSER_BIN="$HOME/bin/composer"
  else
    COMPOSER_BIN=composer
  fi
fi

log() {
  printf "\n[%s] %s\n" "$(date '+%H:%M:%S')" "$1"
}

require_file() {
  if [[ ! -f "$1" ]]; then
    printf "Missing required file: %s\n" "$1" >&2
    exit 1
  fi
}

require_dir() {
  if [[ ! -d "$1" ]]; then
    printf "Missing required directory: %s\n" "$1" >&2
    exit 1
  fi
}

log "Checking project"
require_dir "$APP_ROOT"
require_dir "$APP_ROOT/backend-laravel"
require_dir "$APP_ROOT/admin-dashboard"

log "Updating source from main"
cd "$APP_ROOT"
git fetch origin
git checkout main
git pull --ff-only origin main

log "Checking PHP runtime"
"$PHP_BIN" -v
for ext in pdo_pgsql pgsql fileinfo mbstring openssl curl zip xml gd; do
  "$PHP_BIN" -m | grep -q "^${ext}$" || {
    printf "Missing PHP extension: %s\n" "$ext" >&2
    exit 1
  }
done
for fn in putenv proc_open; do
  "$PHP_BIN" -r "exit(function_exists('$fn') ? 0 : 1);" || {
    printf "PHP function disabled but required for deploy: %s\n" "$fn" >&2
    exit 1
  }
done

log "Installing Laravel dependencies"
cd "$APP_ROOT/backend-laravel"
"$PHP_BIN" "$COMPOSER_BIN" install --no-dev --optimize-autoloader --no-interaction

if [[ ! -f .env ]]; then
  cp .env.production.example .env
  "$PHP_BIN" artisan key:generate
  printf "\nCreated backend-laravel/.env. Edit DB, mail, and super admin values, then rerun this script.\n" >&2
  exit 2
fi

log "Running Laravel migrations and caches"
"$PHP_BIN" artisan migrate --force
"$PHP_BIN" artisan db:seed --force
"$PHP_BIN" artisan config:cache
"$PHP_BIN" artisan route:cache
"$PHP_BIN" artisan view:cache

log "Building React admin"
cd "$APP_ROOT/admin-dashboard"
cat > .env.production <<EOF
VITE_APP_NAME=CariPasal Admin
VITE_API_BASE_URL=$API_BASE_URL
VITE_APP_BASE_PATH=$ADMIN_BASE_PATH
EOF

if [[ -f package-lock.json ]]; then
  npm ci
else
  npm install
fi
npm run build

log "Publishing admin build"
mkdir -p "$ADMIN_DIR"
rm -rf "$ADMIN_DIR"/*
cp -r dist/* "$ADMIN_DIR"/

log "Fixing permissions"
cd "$APP_ROOT"
if command -v sudo >/dev/null 2>&1; then
  sudo chown -R "$WEB_USER:$WEB_GROUP" backend-laravel/storage backend-laravel/bootstrap/cache "$ADMIN_DIR" || true
else
  chown -R "$WEB_USER:$WEB_GROUP" backend-laravel/storage backend-laravel/bootstrap/cache "$ADMIN_DIR" || true
fi
chmod -R 775 backend-laravel/storage backend-laravel/bootstrap/cache || true

log "Reloading Nginx"
if command -v sudo >/dev/null 2>&1; then
  sudo /etc/init.d/nginx reload || true
else
  /etc/init.d/nginx reload || true
fi

log "Deployment complete"
printf "Open: https://%s/api/health\n" "$DOMAIN"
printf "Open: https://%s/admin\n" "$DOMAIN"

