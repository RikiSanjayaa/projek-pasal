# --- TAHAP 1: BUILD ---
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package dan lock file
COPY package.json package-lock.json ./

# Install dependencies (termasuk devDependencies seperti typescript & vite)
RUN npm ci

# Copy semua source code
COPY . .

# Build Aplikasi (Jalankan tsc -b && vite build sesuai package.json).
# .env.docker bersifat lokal; CI memakai contoh yang di-track.
RUN if [ -f .env.docker ]; then cp .env.docker .env.production; else cp .env.docker.example .env.production; fi \
    && npm run build

# --- TAHAP 2: SERVE (NGINX) ---
FROM nginx:alpine

ARG VCS_REF=dev
LABEL org.opencontainers.image.revision=$VCS_REF

# Hapus config default
RUN rm /etc/nginx/conf.d/default.conf

# Copy config nginx custom kita
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy hasil build (folder 'dist' adalah default output Vite)
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
