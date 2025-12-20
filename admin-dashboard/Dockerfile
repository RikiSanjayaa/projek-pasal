# --- TAHAP 1: BUILD ---
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package dan lock file
COPY package.json package-lock.json ./

# Install dependencies (termasuk devDependencies seperti typescript & vite)
RUN npm ci

# Copy semua source code
COPY . .

# Menerima Variabel Environment dari Docker Compose saat BUILD TIME
# (Vite butuh ini saat menjalankan 'npm run build')
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_PUBLISHABLE_DEFAULT_KEY
ARG VITE_APP_NAME

# Set Environment Variables agar terbaca oleh Vite
ENV VITE_SUPABASE_URL=$VITE_SUPABASE_URL
ENV VITE_SUPABASE_PUBLISHABLE_DEFAULT_KEY=$VITE_SUPABASE_PUBLISHABLE_DEFAULT_KEY
ENV VITE_APP_NAME=$VITE_APP_NAME

# Build Aplikasi (Jalankan tsc -b && vite build sesuai package.json)
RUN npm run build

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