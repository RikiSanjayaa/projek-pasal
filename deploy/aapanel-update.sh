#!/usr/bin/env bash
set -euo pipefail

# Thin wrapper for routine aaPanel updates.
# Edit DOMAIN when deploying to the campus server, or pass DOMAIN=... before this script.

DOMAIN="${DOMAIN:-pasal.ikydev.site}"
APP_ROOT="${APP_ROOT:-/www/wwwroot/pasal}"
BRANCH="${BRANCH:-main}"

cd "$APP_ROOT"

DOMAIN="$DOMAIN" \
APP_ROOT="$APP_ROOT" \
BRANCH="$BRANCH" \
bash deploy/aapanel-deploy.sh
