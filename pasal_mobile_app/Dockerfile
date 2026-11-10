# Stage 1a: Flutter toolchain (also usable on its own for analyze/test:
#   docker build --target flutter-sdk -t caripasal-flutter:3.47.9 .)
FROM debian:bookworm-slim AS flutter-sdk

ARG FLUTTER_VERSION=3.47.9
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

# libsqlite3-dev: tes drift in-memory (NativeDatabase) butuh libsqlite3 di image toolchain.
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl git xz-utils unzip libsqlite3-dev && \
    rm -rf /var/lib/apt/lists/*

# Official Flutter tarball (pinned; the cirruslabs "stable" image lags behind).
RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      | tar -xJ -C /opt && \
    git config --global --add safe.directory "${FLUTTER_HOME}" && \
    flutter config --no-analytics --no-cli-animations && \
    flutter precache --web

# Stage 1b: Build Flutter Web
FROM flutter-sdk AS build

WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the app
COPY . .

# Choose Docker-specific env if available, otherwise use tracked example.
RUN if [ -f .env.docker ]; then cp .env.docker /tmp/mobile.env; else cp .env.docker.example /tmp/mobile.env; fi

# Save custom web assets before flutter create overwrites them
RUN cp -r web /tmp/web-custom

# Ensure web platform is fully configured
RUN flutter create . --platforms web

# Restore custom web assets (favicon, icons, manifest, drift files)
RUN cp -r /tmp/web-custom/* web/

# Build for web release
RUN set -a && . /tmp/mobile.env && set +a && dart run tool/build_web.dart --release --no-tree-shake-icons --dart-define=API_BASE_URL="$API_BASE_URL" --dart-define=WEB_APP_URL="$WEB_APP_URL"


# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy custom nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy built web app to nginx html directory
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
