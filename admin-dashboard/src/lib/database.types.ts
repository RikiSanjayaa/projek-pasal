// Shared frontend data types for the Laravel API/database schema.
// Atau definisikan manual seperti di bawah ini

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type AdminRole = 'admin' | 'super_admin'
export type AuditAction = 'CREATE' | 'UPDATE' | 'DELETE'
export type VerificationStatus = 'perlu_verifikasi' | 'terverifikasi'

export interface Database {
  public: {
    Tables: {
      undang_undang: {
        Row: {
          id: string
          kode: string
          nama: string
          nama_lengkap: string | null
          deskripsi: string | null
          tahun: number | null
          is_active: boolean
          official_url: string | null
          source_url: string | null
          catatan_teks: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          kode: string
          nama: string
          nama_lengkap?: string | null
          deskripsi?: string | null
          tahun?: number | null
          is_active?: boolean
          official_url?: string | null
          source_url?: string | null
          catatan_teks?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          kode?: string
          nama?: string
          nama_lengkap?: string | null
          deskripsi?: string | null
          tahun?: number | null
          is_active?: boolean
          official_url?: string | null
          source_url?: string | null
          catatan_teks?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      pasal: {
        Row: {
          id: string
          undang_undang_id: string
          nomor: string
          judul: string | null
          isi: string
          penjelasan: string | null
          catatan: string | null
          keywords: string[]
          is_active: boolean
          verification_status: VerificationStatus
          verified_by: string | null
          verified_at: string | null
          deleted_at: string | null
          created_at: string
          updated_at: string
          created_by: string | null
          updated_by: string | null
        }
        Insert: {
          id?: string
          undang_undang_id: string
          nomor: string
          judul?: string | null
          isi: string
          penjelasan?: string | null
          catatan?: string | null
          keywords?: string[]
          is_active?: boolean
          deleted_at?: string | null
          created_at?: string
          updated_at?: string
          created_by?: string | null
          updated_by?: string | null
        }
        Update: {
          id?: string
          undang_undang_id?: string
          nomor?: string
          judul?: string | null
          isi?: string
          penjelasan?: string | null
          catatan?: string | null
          keywords?: string[]
          is_active?: boolean
          deleted_at?: string | null
          created_at?: string
          updated_at?: string
          created_by?: string | null
          updated_by?: string | null
        }
      }
      pasal_links: {
        Row: {
          id: string
          source_pasal_id: string
          target_pasal_id: string
          keterangan: string | null
          is_active: boolean
          deleted_at: string | null
          created_at: string
          created_by: string | null
        }
        Insert: {
          id?: string
          source_pasal_id: string
          target_pasal_id: string
          keterangan?: string | null
          is_active?: boolean
          deleted_at?: string | null
          created_at?: string
          created_by?: string | null
        }
        Update: {
          id?: string
          source_pasal_id?: string
          target_pasal_id?: string
          keterangan?: string | null
          is_active?: boolean
          deleted_at?: string | null
          created_at?: string
          created_by?: string | null
        }
      }
      admin_users: {
        Row: {
          id: string
          email: string
          nama: string
          role: AdminRole
          is_active: boolean
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          email: string
          nama: string
          role?: AdminRole
          is_active?: boolean
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          email?: string
          nama?: string
          role?: AdminRole
          is_active?: boolean
          created_at?: string
          updated_at?: string
        }
      }
      audit_logs: {
        Row: {
          id: string
          admin_id: string | null
          admin_email: string | null
          action: AuditAction
          table_name: string
          record_id: string
          old_data: Json | null
          new_data: Json | null
          created_at: string
        }
        Insert: {
          id?: string
          admin_id?: string | null
          admin_email?: string | null
          action: AuditAction
          table_name: string
          record_id: string
          old_data?: Json | null
          new_data?: Json | null
          created_at?: string
        }
        Update: {
          id?: string
          admin_id?: string | null
          admin_email?: string | null
          action?: AuditAction
          table_name?: string
          record_id?: string
          old_data?: Json | null
          new_data?: Json | null
          created_at?: string
        }
      }
      users: {
        Row: {
          id: string
          email: string
          nama: string
          is_active: boolean
          created_at: string
          expires_at: string
          created_by: string | null
          updated_at: string
        }
        Insert: {
          id: string
          email: string
          nama: string
          is_active?: boolean
          created_at?: string
          expires_at: string
          created_by?: string | null
          updated_at?: string
        }
        Update: {
          id?: string
          email?: string
          nama?: string
          is_active?: boolean
          created_at?: string
          expires_at?: string
          created_by?: string | null
          updated_at?: string
        }
      }
      user_devices: {
        Row: {
          id: string
          user_id: string
          device_id: string
          device_name: string | null
          device_alias: string | null
          is_active: boolean
          last_active_at: string
          created_at: string
        }
        Insert: {
          id?: string
          user_id: string
          device_id: string
          device_name?: string | null
          device_alias?: string | null
          is_active?: boolean
          last_active_at?: string
          created_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          device_id?: string
          device_name?: string | null
          device_alias?: string | null
          is_active?: boolean
          last_active_at?: string
          created_at?: string
        }
      }
      admin_devices: {
        Row: {
          id: string
          admin_id: string
          device_id: string
          device_name: string | null
          device_alias: string | null
          is_active: boolean
          last_active_at: string
          created_at: string
        }
        Insert: {
          id?: string
          admin_id: string
          device_id: string
          device_name?: string | null
          device_alias?: string | null
          is_active?: boolean
          last_active_at?: string
          created_at?: string
        }
        Update: {
          id?: string
          admin_id?: string
          device_id?: string
          device_name?: string | null
          device_alias?: string | null
          is_active?: boolean
          last_active_at?: string
          created_at?: string
        }
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      search_pasal: {
        Args: {
          search_query: string
          uu_kode?: string | null
          page_number?: number
          page_size?: number
        }
        Returns: {
          id: string
          undang_undang_id: string
          undang_undang_kode: string
          undang_undang_nama: string
          nomor: string
          judul: string | null
          isi: string
          penjelasan: string | null
          keywords: string[]
          rank: number
          total_count: number
        }[]
      }
      is_admin: {
        Args: Record<string, never>
        Returns: boolean
      }
      is_super_admin: {
        Args: Record<string, never>
        Returns: boolean
      }
    }
    Enums: {
      admin_role: AdminRole
      audit_action: AuditAction
    }
  }
}

// Helper types
export type UndangUndang = Database['public']['Tables']['undang_undang']['Row']
export type UndangUndangInsert = Database['public']['Tables']['undang_undang']['Insert']
export type UndangUndangUpdate = Database['public']['Tables']['undang_undang']['Update']

export type Pasal = Database['public']['Tables']['pasal']['Row']
export type PasalInsert = Database['public']['Tables']['pasal']['Insert']
export type PasalUpdate = Database['public']['Tables']['pasal']['Update']

export type PasalLink = Database['public']['Tables']['pasal_links']['Row']
export type PasalLinkInsert = Database['public']['Tables']['pasal_links']['Insert']

export type AdminUser = Database['public']['Tables']['admin_users']['Row']
export type AuditLog = Database['public']['Tables']['audit_logs']['Row']

export type User = Database['public']['Tables']['users']['Row']
export type UserInsert = Database['public']['Tables']['users']['Insert']
export type UserUpdate = Database['public']['Tables']['users']['Update']

export type UserDevice = Database['public']['Tables']['user_devices']['Row']
export type UserDeviceInsert = Database['public']['Tables']['user_devices']['Insert']
export type UserDeviceUpdate = Database['public']['Tables']['user_devices']['Update']

export type AdminDevice = Database['public']['Tables']['admin_devices']['Row']
export type AdminDeviceInsert = Database['public']['Tables']['admin_devices']['Insert']
export type AdminDeviceUpdate = Database['public']['Tables']['admin_devices']['Update']

// Extended types with relations
export interface PasalWithUndangUndang extends Pasal {
  undang_undang: UndangUndang
  verifier?: Pick<AdminUser, 'id' | 'nama' | 'email'> | null
  /** Versi riwayat terakhir (rumusan berlaku). Null bila pasal belum pernah diubah UU lain. */
  versi_terakhir?: Pick<PasalVersi, 'id' | 'urutan' | 'status' | 'sumber' | 'judul_sumber' | 'naskah_resmi'> &
    Partial<Pick<PasalVersi, 'diundangkan' | 'berlaku_sejak'>> | null
}

export type PasalVersiStatus = 'asli' | 'diubah' | 'disisipkan' | 'dihapus'

/** Baris dari GET /admin/pasal/{id}/riwayat, urut dari yang paling lama. */
export interface PasalVersi {
  id: string
  pasal_id: string
  urutan: number
  status: PasalVersiStatus
  sumber: string
  judul_sumber: string | null
  diundangkan: string | null
  berlaku_sejak: string | null
  naskah_resmi: string | null
  isi: string
  penjelasan: string | null
}

/** Baris dari GET /admin/pasal-verification-summary. */
export interface VerificationSummaryRow {
  undang_undang_id: string
  kode: string
  nama: string
  total: number
  verified: number
}

export interface AuditLogWithAdmin extends AuditLog {
  admin_users?: AdminUser | null
}

export interface UserWithDevices extends User {
  user_devices: UserDevice[]
  created_by_admin?: AdminUser | null
}

export interface AdminWithDevices extends AdminUser {
  admin_devices: AdminDevice[]
}

// --- Import dari datahukum.com (Sumber Data) ---

export type ImportRunStatus = 'queued' | 'running' | 'ready' | 'applied' | 'failed' | 'discarded' | 'needs_config'

export type ImportItemCategory = 'baru' | 'berubah' | 'konflik' | 'diedit_admin' | 'hilang' | 'riwayat'

export interface ImportUserRef {
  id: string
  nama: string
}

export interface ImportRunSummary {
  counts: Record<ImportItemCategory, number>
  selected: number
  total_pasal: number
  large_change: boolean
  pdf_flagged: number
  /** Diisi setelah Terapkan. */
  applied?: { diterapkan: number; dilewati: number; diakui: number; link_ditambah: number; link_dihapus: number }
}

export interface ImportRun {
  id: string
  slug: string
  undang_undang_id: string | null
  status: ImportRunStatus
  requested_by: ImportUserRef | null
  applied_by: ImportUserRef | null
  created_at: string
  started_at: string | null
  finished_at: string | null
  applied_at: string | null
  error: string | null
  warnings: { nomor: string; message: string }[]
  unknown_versions: string[]
  summary: ImportRunSummary | null
  source_url: string | null
  html_sha256: string | null
}

export interface ImportSource {
  slug: string
  kode: string
  nama: string
  label: string
  datahukum_url: string
  undang_undang_id: string | null
  last_run: ImportRun | null
  active_run: ImportRun | null
}

export interface ImportSourcesResponse {
  enabled: boolean
  sources: ImportSource[]
}

export interface ImportSnap {
  judul: string | null
  isi: string | null
  penjelasan: string | null
  /** Catatan redaksi CariPasal; snapshot lama tidak memilikinya (dianggap null). */
  catatan?: string | null
  keywords: string[]
}

export interface ImportRiwayatRow {
  urutan: number
  status: string
  sumber: string
  judul_sumber: string | null
  diundangkan: string | null
  berlaku_sejak: string | null
  naskah_resmi: string | null
  isi: string
  penjelasan: string | null
}

export interface ImportItemReview {
  cakupan_isi_pdf?: number | null
  cakupan_penjelasan_pdf?: number | null
  perlu_review?: boolean
  catatan?: string | null
}

export interface ImportItem {
  id: string
  nomor: string
  pasal_id: string | null
  category: ImportItemCategory
  selected: boolean
  base: ImportSnap | null
  current: ImportSnap | null
  incoming: ImportSnap | null
  incoming_riwayat: ImportRiwayatRow[] | null
  current_riwayat: ImportRiwayatRow[] | null
  review: ImportItemReview | null
  notes: string[]
  applied_at: string | null
}
