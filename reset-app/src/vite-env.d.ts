/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL: string
  readonly VITE_SUPABASE_PUBLISHABLE_DEFAULT_KEY: string
  readonly APP_STORE_URL?: string
  readonly PLAY_STORE_URL?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
