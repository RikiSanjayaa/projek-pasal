#!/usr/bin/env bash
set -u

APP_ROOT="${APP_ROOT:-/www/wwwroot/pasal}"
PHP_BIN="${PHP_BIN:-/www/server/php/84/bin/php}"
COMPOSER_BIN="${COMPOSER_BIN:-}"

if [[ -z "$COMPOSER_BIN" ]]; then
  if [[ -x /usr/local/bin/composer ]]; then
    COMPOSER_BIN=/usr/local/bin/composer
  elif [[ -x "$HOME/bin/composer" ]]; then
    COMPOSER_BIN="$HOME/bin/composer"
  else
    COMPOSER_BIN=composer
  fi
fi

section() {
  printf "\n== %s ==\n" "$1"
}

check_command() {
  local label="$1"
  shift
  if "$@" >/tmp/aapanel-doctor.out 2>/tmp/aapanel-doctor.err; then
    printf "[OK] %s\n" "$label"
    sed -n '1,3p' /tmp/aapanel-doctor.out
  else
    printf "[FAIL] %s\n" "$label"
    sed -n '1,5p' /tmp/aapanel-doctor.err
  fi
}

section "Runtime"
check_command "PHP" "$PHP_BIN" -v
check_command "Composer" "$PHP_BIN" "$COMPOSER_BIN" -V
check_command "Node" node -v
check_command "NPM" npm -v

section "PHP Extensions"
for ext in pdo_pgsql pgsql fileinfo mbstring openssl curl zip xml gd; do
  if "$PHP_BIN" -m | grep -q "^${ext}$"; then
    printf "[OK] %s\n" "$ext"
  else
    printf "[FAIL] %s not loaded\n" "$ext"
  fi
done

section "PHP Functions Needed By Composer"
for fn in putenv proc_open; do
  if "$PHP_BIN" -r "exit(function_exists('$fn') ? 0 : 1);" >/dev/null 2>&1; then
    printf "[OK] %s enabled\n" "$fn"
  else
    printf "[FAIL] %s disabled\n" "$fn"
  fi
done

section "Project Paths"
for path in "$APP_ROOT" "$APP_ROOT/backend-laravel" "$APP_ROOT/admin-dashboard"; do
  if [[ -d "$path" ]]; then
    printf "[OK] %s\n" "$path"
  else
    printf "[FAIL] %s missing\n" "$path"
  fi
done

section "Laravel Migration Compatibility"
schema="$APP_ROOT/backend-laravel/database/migrations/2026_05_04_030000_create_caripasal_schema.php"
if [[ -f "$schema" ]] && grep -Eq 'CREATE EXTENSION|gen_random_uuid' "$schema"; then
  printf "[FAIL] migration still requires PostgreSQL server extensions\n"
else
  printf "[OK] migration does not require pgcrypto/uuid-ossp\n"
fi

section "Nginx Socket"
ls /tmp/php-cgi-*.sock 2>/dev/null || printf "No aaPanel PHP socket found in /tmp\n"

