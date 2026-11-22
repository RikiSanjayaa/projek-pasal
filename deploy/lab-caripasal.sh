#!/usr/bin/env bash
set -euo pipefail

TAG=${1:-${TAG:-sha-27dfcf2}}
case "$TAG" in
    sha-[0-9a-f]*) ;;
    *) echo "TAG harus diawali sha-<commit>" >&2; exit 2 ;;
esac

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PROJECT=${LAB_PROJECT:-caripasal-lab}
ADMIN_PORT=${LAB_ADMIN_PORT:-28081}
MOBILE_PORT=${LAB_MOBILE_PORT:-28082}
WORK=$(mktemp -d)
umask 077

# Shell variables would override --env-file; keep the lab run isolated.
unset CARIPASAL_APP_IMAGE CARIPASAL_ADMIN_IMAGE CARIPASAL_MOBILE_IMAGE CARIPASAL_PULL_POLICY \
    ADMIN_BIND ADMIN_PORT MOBILE_BIND MOBILE_PORT
ADMIN_PORT=${LAB_ADMIN_PORT:-28081}
MOBILE_PORT=${LAB_MOBILE_PORT:-28082}

cleanup() {
    docker compose -p "$PROJECT" -f "$WORK/compose.production.yml" --env-file "$WORK/deploy.env" down -v --remove-orphans >/dev/null 2>&1 || true
    rm -rf "$WORK"
}
trap cleanup EXIT

cp "$ROOT/compose.production.yml" "$WORK/"
cp -r "$ROOT/deploy" "$WORK/"

db_password=$(openssl rand -hex 24)
app_key="base64:$(openssl rand -base64 32 | tr -d '\n')"
cat > "$WORK/app.env" <<EOF
APP_NAME=CariPasal
APP_ENV=production
APP_KEY=$app_key
APP_DEBUG=false
APP_URL=http://127.0.0.1:${ADMIN_PORT}
APP_TIMEZONE=Asia/Makassar
APP_LOCALE=id
DB_CONNECTION=pgsql
DB_HOST=db
DB_PORT=5432
DB_DATABASE=caripasal
DB_USERNAME=caripasal
DB_PASSWORD=$db_password
SESSION_DRIVER=database
CACHE_STORE=database
QUEUE_CONNECTION=database
FILESYSTEM_DISK=local
EOF
cat > "$WORK/bootstrap.env" <<EOF
POSTGRES_DB=caripasal
POSTGRES_USER=caripasal
POSTGRES_PASSWORD=$db_password
EOF
cat > "$WORK/deploy.env" <<EOF
CARIPASAL_APP_IMAGE=ghcr.io/rikisanjayaa/caripasal-app:${TAG}
CARIPASAL_ADMIN_IMAGE=ghcr.io/rikisanjayaa/caripasal-admin:${TAG}
CARIPASAL_MOBILE_IMAGE=ghcr.io/rikisanjayaa/caripasal-mobile:${TAG}
CARIPASAL_PULL_POLICY=always
ADMIN_BIND=127.0.0.1
ADMIN_PORT=${ADMIN_PORT}
MOBILE_BIND=127.0.0.1
MOBILE_PORT=${MOBILE_PORT}
EOF

cd "$WORK"
docker compose -p "$PROJECT" --env-file deploy.env -f compose.production.yml pull
docker compose -p "$PROJECT" --env-file deploy.env -f compose.production.yml up -d --remove-orphans

ok=false
for _ in $(seq 1 36); do
    if curl -fsS --max-time 5 "http://127.0.0.1:${ADMIN_PORT}/api/health" | grep -q '"status":"ok"' \
        && curl -fsS --max-time 5 "http://127.0.0.1:${ADMIN_PORT}/" >/dev/null \
        && curl -fsS --max-time 5 "http://127.0.0.1:${MOBILE_PORT}/" >/dev/null; then
        ok=true
        break
    fi
    sleep 5
done

if [ "$ok" != true ]; then
    docker compose -p "$PROJECT" --env-file deploy.env -f compose.production.yml ps || true
    docker compose -p "$PROJECT" --env-file deploy.env -f compose.production.yml logs --no-color --tail=60 || true
    echo "LAB FAIL tag=$TAG" >&2
    exit 1
fi

echo "LAB OK tag=$TAG admin=http://127.0.0.1:${ADMIN_PORT} mobile=http://127.0.0.1:${MOBILE_PORT}"
