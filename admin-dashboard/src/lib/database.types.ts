// Database types generated from Supabase schema
// Jalankan: npx supabase gen types typescript --project-id YOUR_PROJECT_ID > src/lib/database.types.ts
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
          keywords: string[]
          is_active: boolean
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
          is_active: boolean
          last_active_at: string
          created_at: string
        }
        Insert: {
          id?: string
          user_id: string
          device_id: string
          device_name?: string | null
          is_active?: boolean
          last_active_at?: string
          created_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          device_id?: string
          device_name?: string | null
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

// Extended types with relations
export interface PasalWithUndangUndang extends Pasal {
  undang_undang: UndangUndang
}

export interface AuditLogWithAdmin extends AuditLog {
  admin_users?: AdminUser | null
}

export interface UserWithDevices extends User {
  user_devices: UserDevice[]
  created_by_admin?: AdminUser | null
}
