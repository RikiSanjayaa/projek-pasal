#!/bin/sh
set -e

if [ ! -f .env ]; then
    if [ -f .env.docker ]; then
        cp .env.docker .env
    else
        cp .env.example .env
    fi
fi

if ! grep -q '^APP_KEY=base64:' .env 2>/dev/null && [ -z "${APP_KEY:-}" ]; then
    php artisan key:generate --force --no-interaction
fi

php artisan config:clear --no-interaction

if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
    php artisan migrate --force --no-interaction
fi

if [ "${RUN_SEEDERS:-true}" = "true" ]; then
    php artisan db:seed --force --no-interaction
fi

exec "$@"
