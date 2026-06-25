import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const apiBaseUrl = env.VITE_API_BASE_URL || '/api'
  const apiProxyTarget = env.VITE_API_PROXY_TARGET || 'http://127.0.0.1:8000'

  return {
    base: env.VITE_APP_BASE_PATH || '/',
    plugins: [react()],
    server:
      apiBaseUrl === '/api'
        ? {
            proxy: {
              '/api': {
                target: apiProxyTarget,
                changeOrigin: true,
              },
            },
          }
        : undefined,
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src'),
      },
    },
    build: {
      rollupOptions: {
        output: {
          manualChunks(id) {
            if (!id.includes('node_modules')) return undefined
            if (id.includes('tesseract.js')) return 'vendor-ocr'
            if (id.includes('xlsx')) return 'vendor-xlsx'
            if (id.includes('@mantine')) return 'vendor-mantine'
            if (id.includes('@tanstack')) return 'vendor-tanstack'
            if (id.includes('recharts')) return 'vendor-charts'
            if (id.includes('@tabler/icons-react')) return 'vendor-icons'
            if (id.includes('react') || id.includes('react-dom') || id.includes('react-router-dom')) return 'vendor-react'
            return 'vendor'
          },
        },
      },
    },
  }
})
