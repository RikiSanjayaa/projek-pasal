#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="${APP_ROOT:-/www/wwwroot/pasal}"
DOMAIN="${DOMAIN:-pasal.ikydev.site}"
PHP_BIN="${PHP_BIN:-/www/server/php/84/bin/php}"
COMPOSER_BIN="${COMPOSER_BIN:-}"
WEB_USER="${WEB_USER:-www}"
WEB_GROUP="${WEB_GROUP:-www}"
DEPLOY_USER="${DEPLOY_USER:-${SUDO_USER:-$(id -un)}}"
WRITABLE_OWNER="${WRITABLE_OWNER:-$DEPLOY_USER:$WEB_GROUP}"
ADMIN_DIR="${ADMIN_DIR:-$APP_ROOT/admin}"
ADMIN_BASE_PATH="${ADMIN_BASE_PATH:-/admin/}"
API_BASE_URL="${API_BASE_URL:-https://$DOMAIN/api}"
BRANCH="${BRANCH:-main}"
SKIP_GIT="${SKIP_GIT:-0}"
SKIP_NPM_CI="${SKIP_NPM_CI:-0}"
RUN_TESTS="${RUN_TESTS:-0}"
CACHE_ROUTES="${CACHE_ROUTES:-0}"
PHP_FPM_SERVICE="${PHP_FPM_SERVICE:-/etc/init.d/php-fpm-84}"
HEALTH_URL="${HEALTH_URL:-https://$DOMAIN/api/health}"

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

fix_laravel_permissions() {
  local backend_dir="$APP_ROOT/backend-laravel"
  mkdir -p "$backend_dir/storage/logs" "$backend_dir/bootstrap/cache"
  touch "$backend_dir/storage/logs/laravel.log"

  if command -v sudo >/dev/null 2>&1; then
    sudo chown -R "$WRITABLE_OWNER" "$backend_dir/storage" "$backend_dir/bootstrap/cache" || true
  else
    chown -R "$WRITABLE_OWNER" "$backend_dir/storage" "$backend_dir/bootstrap/cache" || true
  fi

  chmod -R 775 "$backend_dir/storage" "$backend_dir/bootstrap/cache" || true
}

log "Checking project"
require_dir "$APP_ROOT"
require_dir "$APP_ROOT/backend-laravel"
require_dir "$APP_ROOT/admin-dashboard"

log "Updating source"
cd "$APP_ROOT"
if [[ "$SKIP_GIT" != "1" ]]; then
  git fetch origin
  git checkout "$BRANCH"
  git pull --ff-only origin "$BRANCH"
else
  printf "Skipping git update because SKIP_GIT=1\n"
fi

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

log "Preparing Laravel writable directories"
fix_laravel_permissions

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
"$PHP_BIN" artisan optimize:clear
"$PHP_BIN" artisan config:cache
if [[ "$CACHE_ROUTES" == "1" ]]; then
  "$PHP_BIN" artisan route:cache
else
  printf "Skipping route cache because CACHE_ROUTES is not 1\n"
fi
"$PHP_BIN" artisan view:cache

if [[ "$RUN_TESTS" == "1" ]]; then
  log "Running Laravel tests"
  "$PHP_BIN" artisan test
fi

log "Building React admin"
cd "$APP_ROOT/admin-dashboard"
cat > .env.production <<EOF
VITE_APP_NAME=CariPasal Admin
VITE_API_BASE_URL=$API_BASE_URL
VITE_APP_BASE_PATH=$ADMIN_BASE_PATH
EOF

if [[ "$SKIP_NPM_CI" == "1" ]]; then
  printf "Skipping npm install because SKIP_NPM_CI=1\n"
elif [[ -f package-lock.json ]]; then
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
fix_laravel_permissions
if command -v sudo >/dev/null 2>&1; then
  sudo chown -R "$WEB_USER:$WEB_GROUP" "$ADMIN_DIR" || true
else
  chown -R "$WEB_USER:$WEB_GROUP" "$ADMIN_DIR" || true
fi

log "Restarting PHP-FPM"
if [[ -x "$PHP_FPM_SERVICE" ]]; then
  if command -v sudo >/dev/null 2>&1; then
    sudo "$PHP_FPM_SERVICE" restart || true
  else
    "$PHP_FPM_SERVICE" restart || true
  fi
else
  printf "PHP-FPM service not found or not executable: %s\n" "$PHP_FPM_SERVICE"
fi

log "Reloading Nginx"
if command -v sudo >/dev/null 2>&1; then
  sudo /etc/init.d/nginx reload || true
else
  /etc/init.d/nginx reload || true
fi

log "Health check"
if command -v curl >/dev/null 2>&1; then
  curl -fsS "$HEALTH_URL" || {
    printf "\nHealth check failed: %s\n" "$HEALTH_URL" >&2
    exit 1
  }
  printf "\n"
else
  printf "curl not found, skipping health check\n"
fi

log "Deployment complete"
printf "Open: %s\n" "$HEALTH_URL"
printf "Open: https://%s/admin\n" "$DOMAIN"
