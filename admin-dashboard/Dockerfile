# --- TAHAP 1: BUILD ---
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package dan lock file
COPY package.json package-lock.json ./

# Install dependencies (termasuk devDependencies seperti typescript & vite)
RUN npm ci

# Copy semua source code
COPY . .

# Build Aplikasi (Jalankan tsc -b && vite build sesuai package.json)
RUN cp .env.docker .env.production && npm run build

# --- TAHAP 2: SERVE (NGINX) ---
FROM nginx:alpine

# Hapus config default
RUN rm /etc/nginx/conf.d/default.conf

# Copy config nginx custom kita
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy hasil build (folder 'dist' adalah default output Vite)
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
