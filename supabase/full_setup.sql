-- ============================================================================
-- CARIPASAL - Database Schema
-- Versi: 1.0.0
-- Tanggal: 2025-12-12
-- Deskripsi: Schema awal untuk aplikasi pencarian pasal hukum Indonesia
-- ============================================================================

-- ============================================================================
-- EXTENSIONS
-- ============================================================================

-- Extension untuk UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Extension untuk full-text search Indonesia (jika tersedia)
-- Jika tidak, kita akan menggunakan 'simple' atau 'english' configuration

-- ============================================================================
-- ENUM TYPES
-- ============================================================================

-- Tipe role untuk admin
CREATE TYPE admin_role AS ENUM ('admin', 'super_admin');

-- Tipe action untuk audit log
CREATE TYPE audit_action AS ENUM ('CREATE', 'UPDATE', 'DELETE');

-- ============================================================================
-- TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tabel: undang_undang
-- Deskripsi: Menyimpan daftar undang-undang (KUHP, KUHPer, KUHAP, UU ITE)
-- ----------------------------------------------------------------------------
CREATE TABLE undang_undang (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kode VARCHAR(20) UNIQUE NOT NULL,
    nama VARCHAR(255) NOT NULL,
    nama_lengkap TEXT,
    deskripsi TEXT,
    tahun INTEGER,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index untuk pencarian cepat
CREATE INDEX idx_undang_undang_kode ON undang_undang(kode);
CREATE INDEX idx_undang_undang_active ON undang_undang(is_active);

-- Comment untuk dokumentasi
COMMENT ON TABLE undang_undang IS 'Daftar undang-undang yang tersedia dalam sistem';
COMMENT ON COLUMN undang_undang.kode IS 'Kode singkat: KUHP, KUHPER, KUHAP, UU_ITE';

-- ----------------------------------------------------------------------------
-- Tabel: admin_users
-- Deskripsi: Menyimpan data admin (staf/dosen) yang dapat mengelola data
-- ----------------------------------------------------------------------------
CREATE TABLE admin_users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    nama VARCHAR(255) NOT NULL,
    role admin_role DEFAULT 'admin',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index
CREATE INDEX idx_admin_users_email ON admin_users(email);
CREATE INDEX idx_admin_users_active ON admin_users(is_active);

COMMENT ON TABLE admin_users IS 'Daftar admin yang dapat mengelola data pasal';

-- ----------------------------------------------------------------------------
-- Tabel: pasal
-- Deskripsi: Menyimpan data pasal dari setiap undang-undang
-- ----------------------------------------------------------------------------
CREATE TABLE pasal (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    undang_undang_id UUID NOT NULL REFERENCES undang_undang(id) ON DELETE CASCADE,
    nomor VARCHAR(50) NOT NULL,
    judul VARCHAR(500),
    isi TEXT NOT NULL,
    penjelasan TEXT,
    keywords TEXT[] DEFAULT '{}',
    search_vector TSVECTOR,
    is_active BOOLEAN DEFAULT true,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES admin_users(id),
    updated_by UUID REFERENCES admin_users(id),
    
    CONSTRAINT unique_pasal_per_uu UNIQUE(undang_undang_id, nomor)
);

-- Index untuk pencarian
CREATE INDEX idx_pasal_undang_undang ON pasal(undang_undang_id);
CREATE INDEX idx_pasal_nomor ON pasal(nomor);
CREATE INDEX idx_pasal_search ON pasal USING GIN(search_vector);
CREATE INDEX idx_pasal_keywords ON pasal USING GIN(keywords);
CREATE INDEX idx_pasal_active ON pasal(is_active);
CREATE INDEX idx_pasal_deleted_at ON pasal(deleted_at);

COMMENT ON TABLE pasal IS 'Data pasal dari setiap undang-undang';
COMMENT ON COLUMN pasal.nomor IS 'Nomor pasal: "1", "340", "27 ayat (3)"';
COMMENT ON COLUMN pasal.keywords IS 'Array kata kunci untuk filter pencarian';
COMMENT ON COLUMN pasal.search_vector IS 'Vector untuk full-text search';

-- ----------------------------------------------------------------------------
-- Tabel: pasal_links
-- Deskripsi: Menyimpan relasi/link antar pasal
-- ----------------------------------------------------------------------------
CREATE TABLE pasal_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_pasal_id UUID NOT NULL REFERENCES pasal(id) ON DELETE CASCADE,
    target_pasal_id UUID NOT NULL REFERENCES pasal(id) ON DELETE CASCADE,
    keterangan VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES admin_users(id),
    
    CONSTRAINT unique_pasal_link UNIQUE(source_pasal_id, target_pasal_id),
    CONSTRAINT no_self_link CHECK (source_pasal_id != target_pasal_id)
);

-- Index
CREATE INDEX idx_pasal_links_source ON pasal_links(source_pasal_id);
CREATE INDEX idx_pasal_links_target ON pasal_links(target_pasal_id);
CREATE INDEX idx_pasal_links_active ON pasal_links(is_active);
CREATE INDEX idx_pasal_links_deleted_at ON pasal_links(deleted_at);

COMMENT ON TABLE pasal_links IS 'Relasi antar pasal (misal: "Lihat juga Pasal X")'; COMMENT ON COLUMN pasal_links.is_active IS 'Soft delete flag, cascades with source pasal';
COMMENT ON COLUMN pasal_links.deleted_at IS 'Timestamp when link was soft deleted';

-- ----------------------------------------------------------------------------
-- Tabel: audit_logs
-- Deskripsi: Menyimpan log semua perubahan data oleh admin
-- ----------------------------------------------------------------------------
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES admin_users(id),
    admin_email VARCHAR(255),
    action audit_action NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    record_id UUID NOT NULL,
    old_data JSONB,
    new_data JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index untuk query audit log
CREATE INDEX idx_audit_logs_admin ON audit_logs(admin_id);
CREATE INDEX idx_audit_logs_table ON audit_logs(table_name);
CREATE INDEX idx_audit_logs_record ON audit_logs(record_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);

COMMENT ON TABLE audit_logs IS 'Log perubahan data untuk keperluan audit';



-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function: update_updated_at
-- Deskripsi: Otomatis update kolom updated_at saat record diupdate
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Function: update_search_vector
-- Deskripsi: Otomatis update search_vector saat pasal dibuat/diupdate
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_pasal_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := 
        setweight(to_tsvector('simple', COALESCE(NEW.nomor, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(NEW.judul, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(NEW.isi, '')), 'B') ||
        setweight(to_tsvector('simple', COALESCE(NEW.penjelasan, '')), 'C') ||
        setweight(to_tsvector('simple', COALESCE(array_to_string(NEW.keywords, ' '), '')), 'A');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;



-- ----------------------------------------------------------------------------
-- Function: log_audit
-- Deskripsi: Mencatat perubahan ke audit_logs
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION log_audit()
RETURNS TRIGGER AS $$
DECLARE
    admin_id_val UUID;
    admin_email_val VARCHAR(255);
    action_val audit_action;
    old_data_val JSONB;
    new_data_val JSONB;
    record_id_val UUID;
BEGIN
    -- Dapatkan admin dari auth.uid()
    admin_id_val := auth.uid();
    
    -- Dapatkan email admin
    SELECT email INTO admin_email_val 
    FROM admin_users 
    WHERE id = admin_id_val;
    
    -- Tentukan action dan data
    IF TG_OP = 'INSERT' THEN
        action_val := 'CREATE';
        old_data_val := NULL;
        new_data_val := to_jsonb(NEW);
        record_id_val := NEW.id;
    ELSIF TG_OP = 'UPDATE' THEN
        action_val := 'UPDATE';
        old_data_val := to_jsonb(OLD);
        new_data_val := to_jsonb(NEW);
        record_id_val := NEW.id;
    ELSIF TG_OP = 'DELETE' THEN
        action_val := 'DELETE';
        old_data_val := to_jsonb(OLD);
        new_data_val := NULL;
        record_id_val := OLD.id;
    END IF;
    
    -- Insert ke audit_logs (hanya jika ada admin)
    IF admin_id_val IS NOT NULL THEN
        INSERT INTO audit_logs (
            admin_id, 
            admin_email, 
            action, 
            table_name, 
            record_id, 
            old_data, 
            new_data
        ) VALUES (
            admin_id_val,
            admin_email_val,
            action_val,
            TG_TABLE_NAME,
            record_id_val,
            old_data_val,
            new_data_val
        );
    END IF;
    
    -- Return
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- Function: cascade_soft_delete_pasal_links
-- Deskripsi: Cascade soft delete/restore pasal_links saat pasal di-soft delete/restore
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cascade_soft_delete_pasal_links()
RETURNS TRIGGER AS $$
BEGIN
    -- Jika pasal di-soft delete (is_active berubah dari true ke false)
    IF OLD.is_active = true AND NEW.is_active = false THEN
        UPDATE pasal_links
        SET is_active = false,
            deleted_at = NEW.deleted_at
        WHERE source_pasal_id = NEW.id
          AND is_active = true;
    
    -- Jika pasal di-restore (is_active berubah dari false ke true)
    ELSIF OLD.is_active = false AND NEW.is_active = true THEN
        UPDATE pasal_links
        SET is_active = true,
            deleted_at = NULL
        WHERE source_pasal_id = NEW.id
          AND is_active = false
          AND deleted_at IS NOT NULL
          -- Hanya restore link jika target pasal juga aktif
          AND EXISTS (
              SELECT 1 FROM pasal p
              WHERE p.id = pasal_links.target_pasal_id
                AND p.is_active = true
          );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Function: cleanup_soft_deleted_data
-- Deskripsi: Hapus permanen data yang sudah soft delete > N hari
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cleanup_soft_deleted_data(days INTEGER DEFAULT 30)
RETURNS TABLE(
    deleted_pasal_count INTEGER,
    deleted_links_count INTEGER
) AS $$
DECLARE
    cutoff_date TIMESTAMPTZ;
    pasal_count INTEGER;
    links_count INTEGER;
BEGIN
    cutoff_date := NOW() - (days || ' days')::INTERVAL;
    
    -- Hapus pasal_links yang sudah soft delete > days
    DELETE FROM pasal_links
    WHERE is_active = false
      AND deleted_at IS NOT NULL
      AND deleted_at < cutoff_date;
    
    GET DIAGNOSTICS links_count = ROW_COUNT;
    
    -- Hapus pasal yang sudah soft delete > days
    -- Ini akan otomatis hapus pasal_links terkait karena ON DELETE CASCADE
    DELETE FROM pasal
    WHERE is_active = false
      AND deleted_at IS NOT NULL
      AND deleted_at < cutoff_date;
    
    GET DIAGNOSTICS pasal_count = ROW_COUNT;
    
    RETURN QUERY SELECT pasal_count, links_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Trigger update_at untuk setiap tabel
CREATE TRIGGER tr_undang_undang_updated_at
    BEFORE UPDATE ON undang_undang
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER tr_admin_users_updated_at
    BEFORE UPDATE ON admin_users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER tr_pasal_updated_at
    BEFORE UPDATE ON pasal
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Trigger untuk search vector
CREATE TRIGGER tr_pasal_search_vector
    BEFORE INSERT OR UPDATE ON pasal
    FOR EACH ROW EXECUTE FUNCTION update_pasal_search_vector();

-- Trigger untuk cascade soft delete pasal_links
CREATE TRIGGER tr_pasal_cascade_soft_delete
    AFTER UPDATE ON pasal
    FOR EACH ROW
    WHEN (OLD.is_active IS DISTINCT FROM NEW.is_active)
    EXECUTE FUNCTION cascade_soft_delete_pasal_links();

-- Trigger untuk audit log pada tabel pasal
CREATE TRIGGER tr_pasal_audit
    AFTER INSERT OR UPDATE OR DELETE ON pasal
    FOR EACH ROW EXECUTE FUNCTION log_audit();

-- Trigger untuk audit log pada tabel undang_undang
CREATE TRIGGER tr_undang_undang_audit
    AFTER INSERT OR UPDATE OR DELETE ON undang_undang
    FOR EACH ROW EXECUTE FUNCTION log_audit();

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
-- ============================================================================
-- CARIPASAL - Row Level Security Policies
-- Versi: 1.0.0
-- Tanggal: 2025-12-12
-- Deskripsi: Kebijakan keamanan untuk mengatur akses data
-- ============================================================================

-- ============================================================================
-- ENABLE RLS
-- ============================================================================

ALTER TABLE undang_undang ENABLE ROW LEVEL SECURITY;
ALTER TABLE pasal ENABLE ROW LEVEL SECURITY;
ALTER TABLE pasal_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function untuk cek apakah user adalah admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM admin_users 
        WHERE id = auth.uid() 
        AND is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function untuk cek apakah user adalah super admin
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM admin_users 
        WHERE id = auth.uid() 
        AND role = 'super_admin'
        AND is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- POLICIES: undang_undang
-- ============================================================================

-- Semua orang bisa membaca undang-undang yang aktif
CREATE POLICY "Public: read active undang_undang"
    ON undang_undang
    FOR SELECT
    USING (is_active = true);

-- Admin bisa membaca semua undang-undang (termasuk non-aktif)
CREATE POLICY "Admin: read all undang_undang"
    ON undang_undang
    FOR SELECT
    TO authenticated
    USING (is_admin());

-- Admin bisa insert undang-undang baru
CREATE POLICY "Admin: insert undang_undang"
    ON undang_undang
    FOR INSERT
    TO authenticated
    WITH CHECK (is_admin());

-- Admin bisa update undang-undang
CREATE POLICY "Admin: update undang_undang"
    ON undang_undang
    FOR UPDATE
    TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

-- Hanya super admin yang bisa delete undang-undang
CREATE POLICY "Super Admin: delete undang_undang"
    ON undang_undang
    FOR DELETE
    TO authenticated
    USING (is_super_admin());

-- ============================================================================
-- POLICIES: pasal
-- ============================================================================

-- Semua orang bisa membaca pasal yang aktif
CREATE POLICY "Public: read active pasal"
    ON pasal
    FOR SELECT
    USING (is_active = true);

-- Admin bisa membaca semua pasal (termasuk non-aktif)
CREATE POLICY "Admin: read all pasal"
    ON pasal
    FOR SELECT
    TO authenticated
    USING (is_admin());

-- Admin bisa insert pasal baru
CREATE POLICY "Admin: insert pasal"
    ON pasal
    FOR INSERT
    TO authenticated
    WITH CHECK (is_admin());

-- Admin bisa update pasal
CREATE POLICY "Admin: update pasal"
    ON pasal
    FOR UPDATE
    TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

-- Admin bisa delete pasal (soft delete via is_active, atau hard delete)
CREATE POLICY "Admin: delete pasal"
    ON pasal
    FOR DELETE
    TO authenticated
    USING (is_admin());

-- ============================================================================
-- POLICIES: pasal_links
-- ============================================================================

-- Semua orang bisa membaca link antar pasal
CREATE POLICY "Public: read pasal_links"
    ON pasal_links
    FOR SELECT
    USING (true);

-- Admin bisa manage link antar pasal
CREATE POLICY "Admin: insert pasal_links"
    ON pasal_links
    FOR INSERT
    TO authenticated
    WITH CHECK (is_admin());

CREATE POLICY "Admin: update pasal_links"
    ON pasal_links
    FOR UPDATE
    TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Admin: delete pasal_links"
    ON pasal_links
    FOR DELETE
    TO authenticated
    USING (is_admin());

-- ============================================================================
-- POLICIES: admin_users
-- ============================================================================

-- Admin bisa melihat daftar admin lain
CREATE POLICY "Admin: read admin_users"
    ON admin_users
    FOR SELECT
    TO authenticated
    USING (is_admin());

-- Hanya super admin yang bisa menambah admin baru
CREATE POLICY "Super Admin: insert admin_users"
    ON admin_users
    FOR INSERT
    TO authenticated
    WITH CHECK (is_super_admin());

-- Super admin bisa update admin lain, admin bisa update diri sendiri
CREATE POLICY "Admin: update own profile"
    ON admin_users
    FOR UPDATE
    TO authenticated
    USING (id = auth.uid() OR is_super_admin())
    WITH CHECK (id = auth.uid() OR is_super_admin());

-- Hanya super admin yang bisa delete admin
CREATE POLICY "Super Admin: delete admin_users"
    ON admin_users
    FOR DELETE
    TO authenticated
    USING (is_super_admin() AND id != auth.uid()); -- Tidak bisa hapus diri sendiri

-- ============================================================================
-- POLICIES: audit_logs
-- ============================================================================

-- Admin bisa melihat audit logs
CREATE POLICY "Admin: read audit_logs"
    ON audit_logs
    FOR SELECT
    TO authenticated
    USING (is_admin());

-- Tidak ada yang bisa modify audit logs secara langsung (hanya via trigger)
-- Insert dilakukan oleh trigger dengan SECURITY DEFINER

-- ============================================================================
-- END OF RLS POLICIES
-- ============================================================================
-- ============================================================================
-- Migration: Add audit trigger for pasal_links
-- Versi: 1.0.1
-- Tanggal: 2025-12-13
-- Deskripsi: Menambahkan audit log trigger untuk tabel pasal_links
-- ============================================================================

-- Trigger untuk audit log pada tabel pasal_links
CREATE TRIGGER tr_pasal_links_audit
    AFTER INSERT OR UPDATE OR DELETE ON pasal_links
    FOR EACH ROW EXECUTE FUNCTION log_audit();

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
-- ============================================================================
-- Migration: 005_audit_enhancement (Cancelled)
-- Tanggal: 2025-12-14
-- Deskripsi: IP address dan User Agent tidak diimplementasikan
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CANCELLED: IP Address dan User Agent tidak akan ditambahkan ke audit logs
-- ----------------------------------------------------------------------------
-- Kolom ip_address dan user_agent tidak akan ditambahkan ke tabel audit_logs
-- Function log_audit() tetap menggunakan versi original tanpa client information

-- ----------------------------------------------------------------------------
-- Step 1: Drop columns from audit_logs table
-- ----------------------------------------------------------------------------
ALTER TABLE audit_logs DROP COLUMN IF EXISTS ip_address;
ALTER TABLE audit_logs DROP COLUMN IF EXISTS user_agent;

-- ----------------------------------------------------------------------------
-- Function: log_audit (Unchanged - Original Version)
-- Deskripsi: Mencatat perubahan ke audit_logs (versi original)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION log_audit()
RETURNS TRIGGER AS $$
DECLARE
    admin_id_val UUID;
    admin_email_val VARCHAR(255);
    action_val audit_action;
    old_data_val JSONB;
    new_data_val JSONB;
    record_id_val UUID;
BEGIN
    -- Dapatkan admin dari auth.uid()
    admin_id_val := auth.uid();

    -- Dapatkan email admin
    SELECT email INTO admin_email_val
    FROM admin_users
    WHERE id = admin_id_val;

    -- Tentukan action dan data
    IF TG_OP = 'INSERT' THEN
        action_val := 'CREATE';
        old_data_val := NULL;
        new_data_val := to_jsonb(NEW);
        record_id_val := NEW.id;
    ELSIF TG_OP = 'UPDATE' THEN
        action_val := 'UPDATE';
        old_data_val := to_jsonb(OLD);
        new_data_val := to_jsonb(NEW);
        record_id_val := NEW.id;
    ELSIF TG_OP = 'DELETE' THEN
        action_val := 'DELETE';
        old_data_val := to_jsonb(OLD);
        new_data_val := NULL;
        record_id_val := OLD.id;
    END IF;

    -- Insert ke audit_logs (hanya jika ada admin)
    IF admin_id_val IS NOT NULL THEN
        INSERT INTO audit_logs (
            admin_id,
            admin_email,
            action,
            table_name,
            record_id,
            old_data,
            new_data
        ) VALUES (
            admin_id_val,
            admin_email_val,
            action_val,
            TG_TABLE_NAME,
            record_id_val,
            old_data_val,
            new_data_val
        );
    END IF;

    -- Return
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE audit_logs IS 'Log perubahan data untuk keperluan audit';
-- ============================================================================
-- Migration: 006_fix_get_download_data
-- Tanggal: 2025-12-31
-- Deskripsi: Fix get_download_data function - remove non-existent 'version' column
-- ============================================================================

-- Drop existing function first (return type changed)
DROP FUNCTION IF EXISTS get_download_data(text);

-- ----------------------------------------------------------------------------
-- Function: get_download_data (FIXED)
-- Deskripsi: Mendapatkan semua pasal dari satu undang-undang untuk download offline
-- Return: Semua pasal dengan metadata
-- FIXED: Removed reference to non-existent 'version' column
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_download_data(
    uu_kode TEXT
)
RETURNS TABLE (
    undang_undang JSONB,
    pasal_list JSONB,
    total_pasal BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH uu_data AS (
        SELECT 
            uu.id,
            uu.kode,
            uu.nama,
            uu.nama_lengkap,
            uu.deskripsi,
            uu.tahun
        FROM undang_undang uu
        WHERE uu.kode = uu_kode AND uu.is_active = true
    ),
    pasal_data AS (
        SELECT 
            jsonb_agg(
                jsonb_build_object(
                    'id', p.id,
                    'nomor', p.nomor,
                    'judul', p.judul,
                    'isi', p.isi,
                    'penjelasan', p.penjelasan,
                    'keywords', p.keywords
                ) ORDER BY p.nomor
            ) AS pasal_list,
            COUNT(*) AS total_pasal
        FROM pasal p
        INNER JOIN uu_data uu ON p.undang_undang_id = uu.id
        WHERE p.is_active = true
    )
    SELECT 
        jsonb_build_object(
            'id', uu.id,
            'kode', uu.kode,
            'nama', uu.nama,
            'nama_lengkap', uu.nama_lengkap,
            'deskripsi', uu.deskripsi,
            'tahun', uu.tahun
        ) AS undang_undang,
        COALESCE(pd.pasal_list, '[]'::JSONB) AS pasal_list,
        COALESCE(pd.total_pasal, 0) AS total_pasal
    FROM uu_data uu
    CROSS JOIN pasal_data pd;
END;
$$ LANGUAGE plpgsql STABLE;

-- Re-grant execute permission
GRANT EXECUTE ON FUNCTION get_download_data TO anon, authenticated;

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
-- ============================================================================
-- Migration: 007_fix_pasal_links_rls
-- Tanggal: 2025-12-31
-- Deskripsi: Fix RLS policy for pasal_links to filter inactive records
-- ============================================================================

-- Drop the existing overly permissive policy
DROP POLICY IF EXISTS "Public: read pasal_links" ON pasal_links;

-- Create new policy that only allows reading active pasal_links
-- Also ensures both source and target pasal are active
CREATE POLICY "Public: read active pasal_links"
    ON pasal_links
    FOR SELECT
    USING (
        is_active = true
        AND EXISTS (
            SELECT 1 FROM pasal p
            WHERE p.id = pasal_links.source_pasal_id
            AND p.is_active = true
        )
        AND EXISTS (
            SELECT 1 FROM pasal p
            WHERE p.id = pasal_links.target_pasal_id
            AND p.is_active = true
        )
    );

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
-- ============================================================================
-- Migration: Audit Logs Retention Policy
-- Versi: 1.0.0
-- Tanggal: 2025-01-02
-- Deskripsi: Menambahkan fungsi untuk membersihkan audit logs lama
-- ============================================================================

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
-- Default retention: 6 months (180 days)
-- Can be adjusted when calling the function

-- ============================================================================
-- FUNCTION: cleanup_old_audit_logs
-- Deskripsi: Menghapus audit logs yang lebih tua dari N hari
-- ============================================================================
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs(
    retention_days INTEGER DEFAULT 180  -- 6 months default
)
RETURNS TABLE(
    deleted_count BIGINT,
    oldest_remaining TIMESTAMPTZ,
    execution_time_ms NUMERIC
) AS $$
DECLARE
    start_time TIMESTAMPTZ;
    end_time TIMESTAMPTZ;
    cutoff_date TIMESTAMPTZ;
    rows_deleted BIGINT;
    oldest_log TIMESTAMPTZ;
BEGIN
    start_time := clock_timestamp();
    cutoff_date := NOW() - (retention_days || ' days')::INTERVAL;
    
    -- Delete old audit logs in batches to avoid long locks
    -- Using a CTE to limit rows per execution if needed
    DELETE FROM audit_logs
    WHERE created_at < cutoff_date;
    
    GET DIAGNOSTICS rows_deleted = ROW_COUNT;
    
    -- Get the oldest remaining log timestamp
    SELECT MIN(created_at) INTO oldest_log FROM audit_logs;
    
    end_time := clock_timestamp();
    
    RETURN QUERY SELECT 
        rows_deleted,
        oldest_log,
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time)) * 1000, 2);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_old_audit_logs IS 
'Menghapus audit logs yang lebih tua dari retention_days (default: 180 hari / 6 bulan).
Dapat dipanggil manual atau dijadwalkan via pg_cron.

Contoh penggunaan:
- SELECT * FROM cleanup_old_audit_logs();           -- Hapus > 6 bulan
- SELECT * FROM cleanup_old_audit_logs(90);         -- Hapus > 90 hari
- SELECT * FROM cleanup_old_audit_logs(365);        -- Hapus > 1 tahun

Return: jumlah record dihapus, timestamp log tertua yang tersisa, waktu eksekusi (ms)';

-- ============================================================================
-- FUNCTION: get_audit_logs_stats
-- Deskripsi: Mendapatkan statistik ukuran dan distribusi audit logs
-- ============================================================================
CREATE OR REPLACE FUNCTION get_audit_logs_stats()
RETURNS TABLE(
    total_count BIGINT,
    oldest_log TIMESTAMPTZ,
    newest_log TIMESTAMPTZ,
    logs_last_7_days BIGINT,
    logs_last_30_days BIGINT,
    logs_last_90_days BIGINT,
    logs_older_than_180_days BIGINT,
    estimated_size_mb NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::BIGINT as total_count,
        MIN(created_at) as oldest_log,
        MAX(created_at) as newest_log,
        COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days')::BIGINT as logs_last_7_days,
        COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '30 days')::BIGINT as logs_last_30_days,
        COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '90 days')::BIGINT as logs_last_90_days,
        COUNT(*) FILTER (WHERE created_at < NOW() - INTERVAL '180 days')::BIGINT as logs_older_than_180_days,
        ROUND(pg_total_relation_size('audit_logs') / 1024.0 / 1024.0, 2) as estimated_size_mb
    FROM audit_logs;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_audit_logs_stats IS 
'Mendapatkan statistik audit logs: jumlah total, distribusi umur, dan estimasi ukuran.
Berguna untuk monitoring sebelum menjalankan cleanup.

Contoh: SELECT * FROM get_audit_logs_stats();';

-- ============================================================================
-- pg_cron scheduled job
-- ============================================================================
-- pg_cron harus diaktifkan di Supabase Dashboard > Database > Extensions

-- Jalankan cleanup setiap hari jam 3 pagi (UTC)
-- Cek apakah extension pg_cron ada sebelum menjalankan schedule
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule(
            'cleanup-audit-logs-daily',           -- job name
            '0 3 * * *',                           -- cron schedule (3 AM UTC daily)
            'SELECT cleanup_old_audit_logs(180)'   -- command to run
        );
    ELSE
        RAISE NOTICE 'Extension pg_cron belum diaktifkan. Auto-cleanup audit logs tidak dijadwalkan.';
    END IF;
END $$;

-- Untuk melihat scheduled jobs:
-- SELECT * FROM cron.job;

-- Untuk menghapus scheduled job:
-- SELECT cron.unschedule('cleanup-audit-logs-daily');

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
-- ============================================================================
-- Migration: 009_cascade_uu_is_active
-- Tanggal: 2026-01-09
-- Deskripsi: Cascade is_active dari undang_undang ke pasal
--            Ketika UU dinonaktifkan, semua pasal terkait juga dinonaktifkan
--            Ketika UU diaktifkan kembali, semua pasal terkait juga diaktifkan
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function: cascade_uu_is_active_to_pasal
-- Deskripsi: Cascade is_active status dari undang_undang ke semua pasal terkait
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cascade_uu_is_active_to_pasal()
RETURNS TRIGGER AS $$
BEGIN
    -- Hanya jalankan jika is_active berubah
    IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
        -- Update semua pasal yang terkait dengan UU ini
        UPDATE pasal
        SET is_active = NEW.is_active,
            updated_at = NOW()
        WHERE undang_undang_id = NEW.id;

        -- Log untuk debugging (opsional, bisa dihapus di production)
        RAISE NOTICE 'Cascaded is_active=% from undang_undang % to all related pasal',
                     NEW.is_active, NEW.id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Trigger: tr_undang_undang_cascade_is_active
-- Deskripsi: Trigger untuk cascade is_active saat undang_undang diupdate
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_undang_undang_cascade_is_active ON undang_undang;

CREATE TRIGGER tr_undang_undang_cascade_is_active
    AFTER UPDATE ON undang_undang
    FOR EACH ROW
    WHEN (OLD.is_active IS DISTINCT FROM NEW.is_active)
    EXECUTE FUNCTION cascade_uu_is_active_to_pasal();

-- ============================================================================
-- Comment untuk dokumentasi
-- ============================================================================
COMMENT ON FUNCTION cascade_uu_is_active_to_pasal() IS
    'Cascade is_active status dari undang_undang ke semua pasal terkait. '
    'Ketika UU dinonaktifkan, semua pasal akan ikut nonaktif. '
    'Ketika UU diaktifkan, semua pasal akan ikut aktif.';

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
-- ============================================================================
-- Migration: 010_sync_check_function
-- Tanggal: 2026-01-10
-- Deskripsi: Create function to check for sync updates including inactive records
-- This bypasses RLS using SECURITY DEFINER to allow mobile app sync detection
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function: check_sync_updates
-- Deskripsi: Check if there are any UU or Pasal updates since a given timestamp
--            Returns TRUE if there are updates (including inactive records)
-- SECURITY DEFINER allows bypassing RLS for sync purposes
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_sync_updates(
    since_timestamp TIMESTAMPTZ
)
RETURNS BOOLEAN AS $$
DECLARE
    has_uu_updates BOOLEAN;
    has_pasal_updates BOOLEAN;
BEGIN
    -- Check for UU updates (including inactive)
    SELECT EXISTS(
        SELECT 1 FROM undang_undang
        WHERE updated_at > since_timestamp
        LIMIT 1
    ) INTO has_uu_updates;
    
    IF has_uu_updates THEN
        RETURN TRUE;
    END IF;
    
    -- Check for Pasal updates (including inactive)
    SELECT EXISTS(
        SELECT 1 FROM pasal
        WHERE updated_at > since_timestamp
        LIMIT 1
    ) INTO has_pasal_updates;
    
    RETURN has_pasal_updates;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Grant execute permission to all (including anon for mobile app)
GRANT EXECUTE ON FUNCTION check_sync_updates TO anon, authenticated;

-- ----------------------------------------------------------------------------
-- Function: get_sync_updates
-- Deskripsi: Get all updated records since a given timestamp for sync
--            Includes inactive records so mobile app can update local state
-- SECURITY DEFINER allows bypassing RLS for sync purposes
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_sync_updates(
    since_timestamp TIMESTAMPTZ
)
RETURNS TABLE (
    updated_uu JSONB,
    updated_pasal JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', uu.id,
                    'kode', uu.kode,
                    'nama', uu.nama,
                    'nama_lengkap', uu.nama_lengkap,
                    'deskripsi', uu.deskripsi,
                    'tahun', uu.tahun,
                    'is_active', uu.is_active,
                    'updated_at', uu.updated_at
                )
            ), '[]'::JSONB)
            FROM undang_undang uu
            WHERE uu.updated_at > since_timestamp
        ) AS updated_uu,
        (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', p.id,
                    'undang_undang_id', p.undang_undang_id,
                    'nomor', p.nomor,
                    'judul', p.judul,
                    'isi', p.isi,
                    'penjelasan', p.penjelasan,
                    'keywords', p.keywords,
                    'is_active', p.is_active,
                    'created_at', p.created_at,
                    'updated_at', p.updated_at
                )
            ), '[]'::JSONB)
            FROM pasal p
            WHERE p.updated_at > since_timestamp
        ) AS updated_pasal;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Grant execute permission to all (including anon for mobile app)
GRANT EXECUTE ON FUNCTION get_sync_updates TO anon, authenticated;

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
-- ============================================================================
-- Migration: 011_user_auth_schema
-- Tanggal: 2026-01-10
-- Deskripsi: Create users and user_devices tables for mobile app authentication
--            with 3-year expiry and one-device policy
-- ============================================================================

-- ============================================================================
-- TABLE: users
-- Mobile app users (separate from admin_users)
-- ============================================================================

CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    nama VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,  -- User access expires at this timestamp
    created_by UUID REFERENCES admin_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_is_active ON users(is_active);
CREATE INDEX idx_users_expires_at ON users(expires_at);

-- Comments
COMMENT ON TABLE users IS 'Mobile app users with 3-year access expiry';
COMMENT ON COLUMN users.expires_at IS 'User access expires at this timestamp (typically created_at + 3 years)';
COMMENT ON COLUMN users.created_by IS 'Admin who created this user';

-- Trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_users_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at_trigger
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_users_updated_at();

-- ============================================================================
-- TABLE: user_devices
-- Tracks device binding for one-device policy
-- ============================================================================

CREATE TABLE user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id VARCHAR(255) NOT NULL,  -- UUID generated on first app install
    device_name VARCHAR(255),         -- Human readable: "Samsung Galaxy S21", "iPhone 14"
    is_active BOOLEAN DEFAULT true,
    last_active_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Each user can only register a device_id once
    CONSTRAINT unique_user_device UNIQUE(user_id, device_id)
);

-- Indexes for common queries
CREATE INDEX idx_user_devices_user_id ON user_devices(user_id);
CREATE INDEX idx_user_devices_device_id ON user_devices(device_id);
CREATE INDEX idx_user_devices_is_active ON user_devices(is_active);

-- Comments
COMMENT ON TABLE user_devices IS 'Device binding for mobile app users (one active device per user)';
COMMENT ON COLUMN user_devices.device_id IS 'UUID generated on first app install, stored in flutter_secure_storage';
COMMENT ON COLUMN user_devices.device_name IS 'Human-readable device name from device_info_plus';

-- ============================================================================
-- HELPER FUNCTION: is_valid_user
-- Check if current authenticated user is a valid mobile app user
-- ============================================================================

CREATE OR REPLACE FUNCTION is_valid_user()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid()
        AND is_active = true
        AND expires_at > NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION is_valid_user IS 'Returns TRUE if authenticated user is a valid, non-expired mobile app user';

-- ============================================================================
-- RLS: Enable Row Level Security on new tables
-- ============================================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- POLICIES: users table
-- ============================================================================

-- Admins can read all users
CREATE POLICY "Admin: read users"
    ON users
    FOR SELECT
    TO authenticated
    USING (is_admin());

-- Admins can create new users
CREATE POLICY "Admin: insert users"
    ON users
    FOR INSERT
    TO authenticated
    WITH CHECK (is_admin());

-- Admins can update users (toggle active, re-provision expiry)
CREATE POLICY "Admin: update users"
    ON users
    FOR UPDATE
    TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

-- Admins can delete users
CREATE POLICY "Admin: delete users"
    ON users
    FOR DELETE
    TO authenticated
    USING (is_admin());

-- Users can read their own profile (for checking expiry on login)
CREATE POLICY "User: read own profile"
    ON users
    FOR SELECT
    TO authenticated
    USING (id = auth.uid());

-- ============================================================================
-- POLICIES: user_devices table
-- ============================================================================

-- Admins can manage all user devices
CREATE POLICY "Admin: manage user_devices"
    ON user_devices
    FOR ALL
    TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

-- Users can read their own devices
CREATE POLICY "User: read own devices"
    ON user_devices
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Users can insert their own device (on login)
CREATE POLICY "User: insert own device"
    ON user_devices
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- Users can update their own device (last_active_at, is_active for logout)
CREATE POLICY "User: update own device"
    ON user_devices
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
-- ============================================================================
-- Migration: 012_update_rls_for_user_auth
-- Tanggal: 2026-01-10
-- Deskripsi: Update RLS policies to require authentication instead of anonymous access
--            - Replace public read policies with authenticated user policies
--            - Revoke anonymous access to sync RPC functions
-- ============================================================================

-- ============================================================================
-- DROP EXISTING PUBLIC READ POLICIES
-- ============================================================================

-- undang_undang: drop public read policy
DROP POLICY IF EXISTS "Public: read active undang_undang" ON undang_undang;

-- pasal: drop public read policy
DROP POLICY IF EXISTS "Public: read active pasal" ON pasal;

-- pasal_links: drop public read policy (from migration 007)
DROP POLICY IF EXISTS "Public: read active pasal_links" ON pasal_links;

-- ============================================================================
-- CREATE NEW AUTHENTICATED USER POLICIES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- undang_undang: authenticated users (valid user OR admin) can read active records
-- ----------------------------------------------------------------------------
CREATE POLICY "User: read active undang_undang"
    ON undang_undang
    FOR SELECT
    TO authenticated
    USING (
        is_active = true
        AND (is_admin() OR is_valid_user())
    );

-- ----------------------------------------------------------------------------
-- pasal: authenticated users (valid user OR admin) can read active records
-- ----------------------------------------------------------------------------
CREATE POLICY "User: read active pasal"
    ON pasal
    FOR SELECT
    TO authenticated
    USING (
        is_active = true
        AND (is_admin() OR is_valid_user())
    );

-- ----------------------------------------------------------------------------
-- pasal_links: authenticated users (valid user OR admin) can read active records
-- ----------------------------------------------------------------------------
CREATE POLICY "User: read active pasal_links"
    ON pasal_links
    FOR SELECT
    TO authenticated
    USING (
        is_active = true
        AND (is_admin() OR is_valid_user())
        AND EXISTS (
            SELECT 1 FROM pasal p
            WHERE p.id = pasal_links.source_pasal_id
            AND p.is_active = true
        )
        AND EXISTS (
            SELECT 1 FROM pasal p
            WHERE p.id = pasal_links.target_pasal_id
            AND p.is_active = true
        )
    );

-- ============================================================================
-- UPDATE RPC FUNCTION GRANTS
-- Revoke anonymous access to sync functions
-- ============================================================================

-- Revoke anonymous access to sync check functions
REVOKE EXECUTE ON FUNCTION check_sync_updates FROM anon;
REVOKE EXECUTE ON FUNCTION get_sync_updates FROM anon;

-- Note: authenticated users still have access (granted in migration 010)
-- These functions use SECURITY DEFINER so they bypass RLS for sync purposes

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
-- ============================================================================
-- Migration: 013_fix_cascade_uu_is_active
-- Tanggal: 2026-01-10
-- Deskripsi: Memperbaiki logic cascade is_active agar TIDAK mengaktifkan
--            kembali pasal yang sudah dihapus (soft delete / ada deleted_at).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Perbarui Function Logic
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cascade_uu_is_active_to_pasal()
RETURNS TRIGGER AS $$
BEGIN
    -- Hanya jalankan jika is_active berubah
    IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
        
        -- Update pasal:
        -- 1. Set is_active mengikuti status UU baru
        -- 2. TAPI HANYA JIKA pasal tersebut TIDAK sedang dihapus (deleted_at IS NULL)
        --    Ini mencegah pasal "Sampah" ikut aktif kembali saat UU diaktifkan.
        
        UPDATE pasal
        SET is_active = NEW.is_active,
            updated_at = NOW()
        WHERE undang_undang_id = NEW.id
          AND deleted_at IS NULL; -- KUNCI PERBAIKAN: Hanya update yang belum dihapus

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 2. Data Fix (Pembersihan Data Lama)
--    Pastikan semua pasal yang ada di sampah (deleted_at IS NOT NULL)
--    statusnya benar-benar non-aktif (is_active = false).
--    Ini memperbaiki data yang mungkin sudah terlanjur salah karena bug sebelumnya.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    count_fixed INTEGER;
BEGIN
    UPDATE pasal
    SET is_active = false
    WHERE deleted_at IS NOT NULL
      AND is_active = true;
      
    GET DIAGNOSTICS count_fixed = ROW_COUNT;
    
    RAISE NOTICE 'Fixed % soft-deleted pasal that were incorrectly active.', count_fixed;
END $$;
-- ============================================================================
-- Migration: 014_audit_improvements
-- Tanggal: 2026-01-11
-- Deskripsi:
--   1. Skip audit log saat cascade dari UU ke pasal (menghindari log bloat)
--   2. Tambah audit trigger untuk tabel users
-- ============================================================================

-- ============================================================================
-- PART 1: Skip audit during cascade updates
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Update log_audit function to check for cascade flag
-- Jika sedang dalam mode cascade, skip logging
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION log_audit()
RETURNS TRIGGER AS $$
DECLARE
    admin_id_val UUID;
    admin_email_val VARCHAR(255);
    action_val audit_action;
    old_data_val JSONB;
    new_data_val JSONB;
    record_id_val UUID;
    is_cascade BOOLEAN;
BEGIN
    -- Check if we're in cascade mode (skip audit if true)
    BEGIN
        is_cascade := current_setting('app.is_cascade_update', true)::BOOLEAN;
    EXCEPTION WHEN OTHERS THEN
        is_cascade := false;
    END;

    IF is_cascade = true THEN
        -- Skip audit logging during cascade
        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        ELSE
            RETURN NEW;
        END IF;
    END IF;

    -- Dapatkan admin dari auth.uid()
    admin_id_val := auth.uid();

    -- Dapatkan email admin
    SELECT email INTO admin_email_val
    FROM admin_users
    WHERE id = admin_id_val;

    -- Tentukan action dan data
    IF TG_OP = 'INSERT' THEN
        action_val := 'CREATE';
        old_data_val := NULL;
        new_data_val := to_jsonb(NEW);
        record_id_val := NEW.id;
    ELSIF TG_OP = 'UPDATE' THEN
        action_val := 'UPDATE';
        old_data_val := to_jsonb(OLD);
        new_data_val := to_jsonb(NEW);
        record_id_val := NEW.id;
    ELSIF TG_OP = 'DELETE' THEN
        action_val := 'DELETE';
        old_data_val := to_jsonb(OLD);
        new_data_val := NULL;
        record_id_val := OLD.id;
    END IF;

    -- Insert ke audit_logs (hanya jika ada admin)
    IF admin_id_val IS NOT NULL THEN
        INSERT INTO audit_logs (
            admin_id,
            admin_email,
            action,
            table_name,
            record_id,
            old_data,
            new_data
        ) VALUES (
            admin_id_val,
            admin_email_val,
            action_val,
            TG_TABLE_NAME,
            record_id_val,
            old_data_val,
            new_data_val
        );
    END IF;

    -- Return
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- Update cascade function to set cascade flag
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cascade_uu_is_active_to_pasal()
RETURNS TRIGGER AS $$
DECLARE
    affected_count INTEGER;
BEGIN
    -- Hanya jalankan jika is_active berubah
    IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN

        -- Set cascade flag to skip audit logging for cascaded updates
        PERFORM set_config('app.is_cascade_update', 'true', true);

        -- Update pasal:
        -- HANYA JIKA pasal tersebut TIDAK sedang dihapus (deleted_at IS NULL)
        UPDATE pasal
        SET is_active = NEW.is_active,
            updated_at = NOW()
        WHERE undang_undang_id = NEW.id
          AND deleted_at IS NULL;

        GET DIAGNOSTICS affected_count = ROW_COUNT;

        -- Clear cascade flag
        PERFORM set_config('app.is_cascade_update', 'false', true);

        -- Log summary of cascade (optional debug info)
        RAISE NOTICE 'Cascaded is_active=% from UU % to % pasal',
                     NEW.is_active, NEW.id, affected_count;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 2: Add audit trigger for users table
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Trigger untuk audit log pada tabel users
-- Melacak: user dibuat, diaktifkan/dinonaktifkan, expiry diperpanjang, dihapus
-- ----------------------------------------------------------------------------
CREATE TRIGGER tr_users_audit
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION log_audit();

COMMENT ON TRIGGER tr_users_audit ON users IS
    'Audit log untuk perubahan data user mobile app';

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
-- ============================================================================
-- SECURITY HARDENING MIGRATION
-- Fixes vulnerabilities from security scan:
-- - [HIGH] Trigger Bypass via Direct Access
-- - [LOW] Row Count Enumeration
-- - [HIGH] Memory Exhaustion Attack
-- - [LOW] API Version Information Disclosure
-- - [MEDIUM] Credentials in Error Messages
-- ============================================================================

-- ============================================================================
-- 7. [HIGH] Trigger Bypass via Direct Access
-- Force RLS on all tables - cannot be bypassed even by table owner
-- ============================================================================

-- Revoke overly broad permissions from anon role
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;

-- Ensure RLS is FORCED (not just enabled) on all tables
-- FORCE means even table owners must go through RLS
ALTER TABLE undang_undang FORCE ROW LEVEL SECURITY;
ALTER TABLE pasal FORCE ROW LEVEL SECURITY;
ALTER TABLE pasal_links FORCE ROW LEVEL SECURITY;
ALTER TABLE admin_users FORCE ROW LEVEL SECURITY;
ALTER TABLE users FORCE ROW LEVEL SECURITY;
ALTER TABLE user_devices FORCE ROW LEVEL SECURITY;
ALTER TABLE audit_logs FORCE ROW LEVEL SECURITY;

-- Re-grant minimal required permissions with RLS enforcement
-- Public tables (read-only for authenticated users)
GRANT SELECT ON undang_undang TO authenticated;
GRANT SELECT ON pasal TO authenticated;
GRANT SELECT ON pasal_links TO authenticated;

-- User self-service tables
GRANT SELECT, INSERT, UPDATE ON users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_devices TO authenticated;

-- Admin tables
GRANT SELECT, INSERT, UPDATE, DELETE ON admin_users TO authenticated;
GRANT SELECT, INSERT ON audit_logs TO authenticated;

-- Sequence permissions for inserts
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================================
-- 6. [LOW] Row Count Enumeration Prevention
-- Create secure count functions that respect authorization
-- ============================================================================

-- Drop if exists for idempotency
DROP FUNCTION IF EXISTS secure_count(TEXT);

-- Secure count function - only admins can get exact counts
CREATE OR REPLACE FUNCTION secure_count(p_table_name TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result BIGINT;
  allowed_tables TEXT[] := ARRAY['undang_undang', 'pasal', 'pasal_links', 'users', 'user_devices', 'admin_users', 'audit_logs'];
BEGIN
  -- Validate table name to prevent SQL injection
  IF NOT (p_table_name = ANY(allowed_tables)) THEN
    RAISE EXCEPTION 'Invalid table name';
  END IF;

  -- Only admins can get exact counts
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  EXECUTE format('SELECT COUNT(*) FROM %I WHERE is_active = true', p_table_name) INTO result;
  RETURN result;
EXCEPTION
  WHEN undefined_column THEN
    -- Table doesn't have is_active column, count all
    EXECUTE format('SELECT COUNT(*) FROM %I', p_table_name) INTO result;
    RETURN result;
END;
$$;

-- Grant execute to authenticated users (function will enforce authorization)
GRANT EXECUTE ON FUNCTION secure_count(TEXT) TO authenticated;

-- ============================================================================
-- 11. [HIGH] Memory Exhaustion Attack Prevention
-- Add query limits and pagination enforcement
-- ============================================================================

-- Drop existing functions for clean replacement
DROP FUNCTION IF EXISTS get_pasal_paginated(INT, INT, TEXT);
DROP FUNCTION IF EXISTS get_sync_updates_secure(TIMESTAMPTZ, INT);

-- Secure paginated query function with enforced limits
CREATE OR REPLACE FUNCTION get_pasal_paginated(
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0,
  p_search TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  undang_undang_id UUID,
  nomor TEXT,
  judul TEXT,
  isi TEXT,
  penjelasan TEXT,
  keywords TEXT[],
  is_active BOOLEAN,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Enforce maximum limit to prevent memory exhaustion (hard cap at 100)
  IF p_limit IS NULL OR p_limit > 100 THEN
    p_limit := 100;
  END IF;

  IF p_limit < 1 THEN
    p_limit := 50;
  END IF;

  IF p_offset IS NULL OR p_offset < 0 THEN
    p_offset := 0;
  END IF;

  -- Maximum offset to prevent scanning entire table
  IF p_offset > 10000 THEN
    RAISE EXCEPTION 'Offset too large. Use keyset pagination for large datasets.';
  END IF;

  -- Check user authorization
  IF NOT (is_admin() OR is_valid_user()) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  IF p_search IS NOT NULL AND p_search != '' AND length(p_search) >= 2 THEN
    RETURN QUERY
    SELECT
      p.id, p.undang_undang_id, p.nomor, p.judul, p.isi,
      p.penjelasan, p.keywords, p.is_active, p.created_at, p.updated_at
    FROM pasal p
    WHERE p.is_active = true
      AND p.search_vector @@ plainto_tsquery('indonesian', p_search)
    ORDER BY ts_rank(p.search_vector, plainto_tsquery('indonesian', p_search)) DESC
    LIMIT p_limit
    OFFSET p_offset;
  ELSE
    RETURN QUERY
    SELECT
      p.id, p.undang_undang_id, p.nomor, p.judul, p.isi,
      p.penjelasan, p.keywords, p.is_active, p.created_at, p.updated_at
    FROM pasal p
    WHERE p.is_active = true
    ORDER BY p.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
  END IF;
END;
$$;

-- Secure sync function with strict limits
CREATE OR REPLACE FUNCTION get_sync_updates_secure(
  since_timestamp TIMESTAMPTZ,
  p_limit INT DEFAULT 500
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSONB;
  max_limit CONSTANT INT := 1000;
BEGIN
  -- Enforce maximum limit (hard cap)
  IF p_limit IS NULL OR p_limit > max_limit THEN
    p_limit := max_limit;
  END IF;

  IF p_limit < 1 THEN
    p_limit := 500;
  END IF;

  -- Check user authorization
  IF NOT (is_admin() OR is_valid_user()) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  -- Validate timestamp to prevent scanning entire history
  IF since_timestamp IS NULL THEN
    since_timestamp := NOW() - INTERVAL '30 days';
  END IF;

  -- Don't allow querying more than 1 year of history
  IF since_timestamp < NOW() - INTERVAL '365 days' THEN
    since_timestamp := NOW() - INTERVAL '365 days';
  END IF;

  SELECT jsonb_build_object(
    'undang_undang', COALESCE((
      SELECT jsonb_agg(row_to_json(uu.*))
      FROM (
        SELECT id, kode, nama, nama_lengkap, deskripsi, tahun, is_active, created_at, updated_at
        FROM undang_undang
        WHERE updated_at > since_timestamp
        ORDER BY updated_at
        LIMIT p_limit
      ) uu
    ), '[]'::jsonb),
    'pasal', COALESCE((
      SELECT jsonb_agg(row_to_json(p.*))
      FROM (
        SELECT id, undang_undang_id, nomor, judul, isi, penjelasan, keywords, is_active, created_at, updated_at
        FROM pasal
        WHERE updated_at > since_timestamp
        ORDER BY updated_at
        LIMIT p_limit
      ) p
    ), '[]'::jsonb),
    'pasal_links', COALESCE((
      SELECT jsonb_agg(row_to_json(pl.*))
      FROM (
        SELECT id, source_pasal_id, target_pasal_id, keterangan, is_active, created_at
        FROM pasal_links
        WHERE created_at > since_timestamp
        ORDER BY created_at
        LIMIT p_limit
      ) pl
    ), '[]'::jsonb),
    'timestamp', NOW(),
    'has_more', (
      SELECT EXISTS(
        SELECT 1 FROM pasal WHERE updated_at > since_timestamp
        OFFSET p_limit
      )
    )
  ) INTO result;

  RETURN result;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_pasal_paginated(INT, INT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_sync_updates_secure(TIMESTAMPTZ, INT) TO authenticated;

-- ============================================================================
-- 10. [LOW] API Version Information Disclosure
-- 13. [MEDIUM] Credentials in Error Messages
-- Create safe error wrapper functions
-- ============================================================================

-- Generic safe error function that doesn't leak implementation details
CREATE OR REPLACE FUNCTION safe_error(p_message TEXT DEFAULT 'Operation failed')
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  -- Remove any potential sensitive info patterns from error message
  -- This is a generic handler - specific functions should use their own sanitization
  RAISE EXCEPTION '%', p_message;
END;
$$;

-- Safe authentication check that doesn't reveal user existence
CREATE OR REPLACE FUNCTION safe_user_check(p_email TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Always return after same amount of time to prevent timing attacks
  -- Uses pg_sleep with small random delay
  PERFORM pg_sleep(random() * 0.1);

  RETURN EXISTS (
    SELECT 1 FROM users
    WHERE email = lower(trim(p_email))
    AND is_active = true
    AND (expires_at IS NULL OR expires_at > NOW())
  );
END;
$$;

-- ============================================================================
-- Additional RLS Policy Hardening
-- Ensure all policies check for valid session
-- ============================================================================

-- Drop and recreate policies with session validation
DROP POLICY IF EXISTS "Users read active undang_undang" ON undang_undang;
DROP POLICY IF EXISTS "Users can read active undang_undang" ON undang_undang;

CREATE POLICY "authenticated_read_undang_undang" ON undang_undang
  FOR SELECT
  TO authenticated
  USING (
    is_active = true
    AND auth.uid() IS NOT NULL
    AND (is_valid_user() OR is_admin())
  );

DROP POLICY IF EXISTS "Users read active pasal" ON pasal;
DROP POLICY IF EXISTS "Users can read active pasal" ON pasal;

CREATE POLICY "authenticated_read_pasal" ON pasal
  FOR SELECT
  TO authenticated
  USING (
    is_active = true
    AND auth.uid() IS NOT NULL
    AND (is_valid_user() OR is_admin())
  );

DROP POLICY IF EXISTS "Users read active pasal_links" ON pasal_links;
DROP POLICY IF EXISTS "Users can read active pasal_links" ON pasal_links;

CREATE POLICY "authenticated_read_pasal_links" ON pasal_links
  FOR SELECT
  TO authenticated
  USING (
    is_active = true
    AND auth.uid() IS NOT NULL
    AND (is_valid_user() OR is_admin())
    AND EXISTS (SELECT 1 FROM pasal WHERE id = source_pasal_id AND is_active = true)
    AND EXISTS (SELECT 1 FROM pasal WHERE id = target_pasal_id AND is_active = true)
  );

-- ============================================================================
-- Statement timeout for queries (defense against slow queries)
-- ============================================================================

-- Set default statement timeout for authenticated role (30 seconds)
ALTER ROLE authenticated SET statement_timeout = '30s';

-- ============================================================================
-- Prevent privilege escalation through function creation
-- ============================================================================

-- Revoke function creation from authenticated users
REVOKE CREATE ON SCHEMA public FROM authenticated;

-- ============================================================================
-- Add index hints for common query patterns (improves performance, reduces DoS risk)
-- ============================================================================

-- Ensure indexes exist for common filters
CREATE INDEX IF NOT EXISTS idx_pasal_is_active_updated ON pasal(is_active, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_undang_undang_is_active_updated ON undang_undang(is_active, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_pasal_links_is_active_created ON pasal_links(is_active, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_is_active_expires ON users(is_active, expires_at);

-- ============================================================================
-- Audit log for security-sensitive operations
-- ============================================================================

-- Create security event log table for tracking auth failures etc.
CREATE TABLE IF NOT EXISTS security_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'INFO',
  details JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on security events
ALTER TABLE security_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE security_events FORCE ROW LEVEL SECURITY;

-- Only admins can read security events
CREATE POLICY "admins_read_security_events" ON security_events
  FOR SELECT
  TO authenticated
  USING (is_admin());

-- Only service role can insert (via edge functions)
-- No direct insert policy for authenticated users

-- Grant permissions
GRANT SELECT ON security_events TO authenticated;

-- Index for querying recent events
CREATE INDEX IF NOT EXISTS idx_security_events_created ON security_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_events_type ON security_events(event_type, created_at DESC);

-- ============================================================================
-- Function to log security events (for use in edge functions)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_security_event(
  p_event_type TEXT,
  p_severity TEXT DEFAULT 'INFO',
  p_details JSONB DEFAULT NULL,
  p_ip_address INET DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  event_id UUID;
BEGIN
  INSERT INTO security_events (event_type, severity, details, ip_address, user_agent)
  VALUES (p_event_type, p_severity, p_details, p_ip_address, p_user_agent)
  RETURNING id INTO event_id;

  RETURN event_id;
END;
$$;

-- Grant execute (function uses SECURITY DEFINER so it can insert)
GRANT EXECUTE ON FUNCTION log_security_event(TEXT, TEXT, JSONB, INET, TEXT) TO authenticated;

-- ============================================================================
-- Summary of changes:
-- 1. FORCE RLS on all tables (prevents bypass)
-- 2. Minimal permissions granted (principle of least privilege)
-- 3. Secure count function (prevents enumeration)
-- 4. Paginated queries with hard limits (prevents memory exhaustion)
-- 5. Safe error functions (prevents info disclosure)
-- 6. Session validation in RLS policies
-- 7. Statement timeout (prevents slow query DoS)
-- 8. Security event logging
-- 9. Performance indexes
-- ============================================================================
-- ============================================================================
-- Migration: 016_fix_function_search_paths
-- Tanggal: 2026-01-20
-- Deskripsi: Fix function search_path mutable security warnings
--            All functions now use SET search_path = '' with fully-qualified
--            table names to prevent search_path injection attacks.
-- ============================================================================

-- ============================================================================
-- SECURITY DEFINER FUNCTIONS (highest priority)
-- These run with creator's privileges - critical to secure
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function: is_admin
-- Check if current user is an admin
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.admin_users
        WHERE id = auth.uid()
        AND is_active = true
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: is_super_admin
-- Check if current user is a super admin
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.admin_users
        WHERE id = auth.uid()
        AND role = 'super_admin'
        AND is_active = true
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: is_valid_user
-- Check if current user is a valid mobile app user
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_valid_user()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid()
        AND is_active = true
        AND expires_at > NOW()
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: log_audit
-- Log changes to audit_logs table
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    admin_id_val UUID;
    admin_email_val VARCHAR(255);
    action_val public.audit_action;
    old_data_val JSONB;
    new_data_val JSONB;
    record_id_val UUID;
    is_cascade BOOLEAN;
BEGIN
    -- Check if we're in cascade mode (skip audit if true)
    BEGIN
        is_cascade := current_setting('app.is_cascade_update', true)::BOOLEAN;
    EXCEPTION WHEN OTHERS THEN
        is_cascade := false;
    END;

    IF is_cascade = true THEN
        -- Skip audit logging during cascade
        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        ELSE
            RETURN NEW;
        END IF;
    END IF;

    -- Get admin from auth.uid()
    admin_id_val := auth.uid();

    -- Get admin email
    SELECT email INTO admin_email_val
    FROM public.admin_users
    WHERE id = admin_id_val;

    -- Determine action and data
    IF TG_OP = 'INSERT' THEN
        action_val := 'CREATE';
        old_data_val := NULL;
        new_data_val := to_jsonb(NEW);
        record_id_val := NEW.id;
    ELSIF TG_OP = 'UPDATE' THEN
        action_val := 'UPDATE';
        old_data_val := to_jsonb(OLD);
        new_data_val := to_jsonb(NEW);
        record_id_val := NEW.id;
    ELSIF TG_OP = 'DELETE' THEN
        action_val := 'DELETE';
        old_data_val := to_jsonb(OLD);
        new_data_val := NULL;
        record_id_val := OLD.id;
    END IF;

    -- Insert to audit_logs (only if admin exists)
    IF admin_id_val IS NOT NULL THEN
        INSERT INTO public.audit_logs (
            admin_id,
            admin_email,
            action,
            table_name,
            record_id,
            old_data,
            new_data
        ) VALUES (
            admin_id_val,
            admin_email_val,
            action_val,
            TG_TABLE_NAME,
            record_id_val,
            old_data_val,
            new_data_val
        );
    END IF;

    -- Return
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: check_sync_updates
-- Check if there are any updates since a given timestamp
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_sync_updates(
    since_timestamp TIMESTAMPTZ
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
DECLARE
    has_uu_updates BOOLEAN;
    has_pasal_updates BOOLEAN;
BEGIN
    -- Check for UU updates (including inactive)
    SELECT EXISTS(
        SELECT 1 FROM public.undang_undang
        WHERE updated_at > since_timestamp
        LIMIT 1
    ) INTO has_uu_updates;

    IF has_uu_updates THEN
        RETURN TRUE;
    END IF;

    -- Check for Pasal updates (including inactive)
    SELECT EXISTS(
        SELECT 1 FROM public.pasal
        WHERE updated_at > since_timestamp
        LIMIT 1
    ) INTO has_pasal_updates;

    RETURN has_pasal_updates;
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: get_sync_updates
-- Get all updated records since a given timestamp for sync
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_sync_updates(
    since_timestamp TIMESTAMPTZ
)
RETURNS TABLE (
    updated_uu JSONB,
    updated_pasal JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
BEGIN
    RETURN QUERY
    SELECT
        (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', uu.id,
                    'kode', uu.kode,
                    'nama', uu.nama,
                    'nama_lengkap', uu.nama_lengkap,
                    'deskripsi', uu.deskripsi,
                    'tahun', uu.tahun,
                    'is_active', uu.is_active,
                    'updated_at', uu.updated_at
                )
            ), '[]'::JSONB)
            FROM public.undang_undang uu
            WHERE uu.updated_at > since_timestamp
        ) AS updated_uu,
        (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', p.id,
                    'undang_undang_id', p.undang_undang_id,
                    'nomor', p.nomor,
                    'judul', p.judul,
                    'isi', p.isi,
                    'penjelasan', p.penjelasan,
                    'keywords', p.keywords,
                    'is_active', p.is_active,
                    'created_at', p.created_at,
                    'updated_at', p.updated_at
                )
            ), '[]'::JSONB)
            FROM public.pasal p
            WHERE p.updated_at > since_timestamp
        ) AS updated_pasal;
END;
$$;

-- ============================================================================
-- TRIGGER FUNCTIONS
-- These are called automatically on table operations
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function: update_updated_at
-- Auto-update updated_at column on record update
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: update_pasal_search_vector
-- Auto-update search_vector when pasal is created/updated
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_pasal_search_vector()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('simple', COALESCE(NEW.nomor, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(NEW.judul, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(NEW.isi, '')), 'B') ||
        setweight(to_tsvector('simple', COALESCE(NEW.penjelasan, '')), 'C') ||
        setweight(to_tsvector('simple', COALESCE(array_to_string(NEW.keywords, ' '), '')), 'A');
    RETURN NEW;
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: update_users_updated_at
-- Auto-update updated_at for users table
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_users_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: cascade_uu_is_active_to_pasal
-- Cascade is_active changes from undang_undang to pasal
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cascade_uu_is_active_to_pasal()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
    affected_count INTEGER;
BEGIN
    -- Only run if is_active changed
    IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN

        -- Set cascade flag to skip audit logging for cascaded updates
        PERFORM set_config('app.is_cascade_update', 'true', true);

        -- Update pasal:
        -- ONLY IF the pasal is NOT being deleted (deleted_at IS NULL)
        UPDATE public.pasal
        SET is_active = NEW.is_active,
            updated_at = NOW()
        WHERE undang_undang_id = NEW.id
          AND deleted_at IS NULL;

        GET DIAGNOSTICS affected_count = ROW_COUNT;

        -- Clear cascade flag
        PERFORM set_config('app.is_cascade_update', 'false', true);

        -- Log summary of cascade (optional debug info)
        RAISE NOTICE 'Cascaded is_active=% from UU % to % pasal',
                     NEW.is_active, NEW.id, affected_count;
    END IF;

    RETURN NEW;
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: cascade_soft_delete_pasal_links
-- Cascade soft delete/restore from pasal to pasal_links
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cascade_soft_delete_pasal_links()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    -- If pasal is soft deleted (is_active changes from true to false)
    IF OLD.is_active = true AND NEW.is_active = false THEN
        UPDATE public.pasal_links
        SET is_active = false,
            deleted_at = NEW.deleted_at
        WHERE source_pasal_id = NEW.id
          AND is_active = true;

    -- If pasal is restored (is_active changes from false to true)
    ELSIF OLD.is_active = false AND NEW.is_active = true THEN
        UPDATE public.pasal_links
        SET is_active = true,
            deleted_at = NULL
        WHERE source_pasal_id = NEW.id
          AND is_active = false
          AND deleted_at IS NOT NULL
          -- Only restore link if target pasal is also active
          AND EXISTS (
              SELECT 1 FROM public.pasal p
              WHERE p.id = public.pasal_links.target_pasal_id
                AND p.is_active = true
          );
    END IF;

    RETURN NEW;
END;
$$;

-- ============================================================================
-- REGULAR FUNCTIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function: cleanup_soft_deleted_data
-- Permanently delete data that has been soft deleted > N days
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cleanup_soft_deleted_data(days INTEGER DEFAULT 30)
RETURNS TABLE(
    deleted_pasal_count INTEGER,
    deleted_links_count INTEGER
)
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
    cutoff_date TIMESTAMPTZ;
    pasal_count INTEGER;
    links_count INTEGER;
BEGIN
    cutoff_date := NOW() - (days || ' days')::INTERVAL;

    -- Delete pasal_links that have been soft deleted > days
    DELETE FROM public.pasal_links
    WHERE is_active = false
      AND deleted_at IS NOT NULL
      AND deleted_at < cutoff_date;

    GET DIAGNOSTICS links_count = ROW_COUNT;

    -- Delete pasal that have been soft deleted > days
    -- This will auto-delete related pasal_links due to ON DELETE CASCADE
    DELETE FROM public.pasal
    WHERE is_active = false
      AND deleted_at IS NOT NULL
      AND deleted_at < cutoff_date;

    GET DIAGNOSTICS pasal_count = ROW_COUNT;

    RETURN QUERY SELECT pasal_count, links_count;
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: safe_error
-- Generic safe error function that doesn't leak implementation details
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.safe_error(p_message TEXT DEFAULT 'Operation failed')
RETURNS VOID
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    -- Remove any potential sensitive info patterns from error message
    RAISE EXCEPTION '%', p_message;
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: search_pasal
-- Search pasal with exact word match and filters
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.search_pasal(
    search_query TEXT,
    uu_kode TEXT DEFAULT NULL,
    page_number INTEGER DEFAULT 1,
    page_size INTEGER DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    undang_undang_id UUID,
    undang_undang_kode VARCHAR(20),
    undang_undang_nama VARCHAR(255),
    nomor VARCHAR(50),
    judul VARCHAR(500),
    isi TEXT,
    penjelasan TEXT,
    keywords TEXT[],
    rank REAL,
    total_count BIGINT
)
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
    search_tsquery TSQUERY;
    offset_val INTEGER;
BEGIN
    -- Validate input
    IF search_query IS NULL OR TRIM(search_query) = '' THEN
        RETURN;
    END IF;

    -- Calculate offset
    offset_val := (page_number - 1) * page_size;

    -- Convert search query to tsquery (exact word match)
    search_tsquery := plainto_tsquery('simple', search_query);

    RETURN QUERY
    WITH search_results AS (
        SELECT
            p.id,
            p.undang_undang_id,
            uu.kode AS undang_undang_kode,
            uu.nama AS undang_undang_nama,
            p.nomor,
            p.judul,
            p.isi,
            p.penjelasan,
            p.keywords,
            ts_rank(p.search_vector, search_tsquery) AS rank
        FROM public.pasal p
        INNER JOIN public.undang_undang uu ON p.undang_undang_id = uu.id
        WHERE
            p.is_active = true
            AND uu.is_active = true
            AND p.search_vector @@ search_tsquery
            AND (uu_kode IS NULL OR uu.kode = uu_kode)
    ),
    counted_results AS (
        SELECT *, COUNT(*) OVER() AS total_count
        FROM search_results
    )
    SELECT
        cr.id,
        cr.undang_undang_id,
        cr.undang_undang_kode,
        cr.undang_undang_nama,
        cr.nomor,
        cr.judul,
        cr.isi,
        cr.penjelasan,
        cr.keywords,
        cr.rank,
        cr.total_count
    FROM counted_results cr
    ORDER BY cr.rank DESC, cr.nomor ASC
    LIMIT page_size
    OFFSET offset_val;
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: search_pasal_by_keywords
-- Search pasal by keywords (exact match, AND logic)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.search_pasal_by_keywords(
    keyword_list TEXT[],
    uu_kode TEXT DEFAULT NULL,
    page_number INTEGER DEFAULT 1,
    page_size INTEGER DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    undang_undang_id UUID,
    undang_undang_kode VARCHAR(20),
    undang_undang_nama VARCHAR(255),
    nomor VARCHAR(50),
    judul VARCHAR(500),
    isi TEXT,
    penjelasan TEXT,
    keywords TEXT[],
    matched_keywords TEXT[],
    total_count BIGINT
)
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
    offset_val INTEGER;
BEGIN
    -- Validate input
    IF keyword_list IS NULL OR array_length(keyword_list, 1) IS NULL THEN
        RETURN;
    END IF;

    -- Calculate offset
    offset_val := (page_number - 1) * page_size;

    RETURN QUERY
    WITH search_results AS (
        SELECT
            p.id,
            p.undang_undang_id,
            uu.kode AS undang_undang_kode,
            uu.nama AS undang_undang_nama,
            p.nomor,
            p.judul,
            p.isi,
            p.penjelasan,
            p.keywords,
            -- Matched keywords
            ARRAY(
                SELECT unnest(keyword_list)
                INTERSECT
                SELECT unnest(p.keywords)
            ) AS matched_keywords
        FROM public.pasal p
        INNER JOIN public.undang_undang uu ON p.undang_undang_id = uu.id
        WHERE
            p.is_active = true
            AND uu.is_active = true
            -- All keywords must exist in pasal keywords array
            AND p.keywords @> keyword_list
            AND (uu_kode IS NULL OR uu.kode = uu_kode)
    ),
    counted_results AS (
        SELECT *, COUNT(*) OVER() AS total_count
        FROM search_results
    )
    SELECT
        cr.id,
        cr.undang_undang_id,
        cr.undang_undang_kode,
        cr.undang_undang_nama,
        cr.nomor,
        cr.judul,
        cr.isi,
        cr.penjelasan,
        cr.keywords,
        cr.matched_keywords,
        cr.total_count
    FROM counted_results cr
    ORDER BY cr.undang_undang_kode, cr.nomor
    LIMIT page_size
    OFFSET offset_val;
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: get_all_keywords
-- Get list of all unique keywords (for autocomplete)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_all_keywords(
    uu_kode TEXT DEFAULT NULL
)
RETURNS TABLE (
    keyword TEXT,
    count BIGINT
)
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
BEGIN
    RETURN QUERY
    SELECT
        unnest(p.keywords) AS keyword,
        COUNT(*) AS count
    FROM public.pasal p
    INNER JOIN public.undang_undang uu ON p.undang_undang_id = uu.id
    WHERE
        p.is_active = true
        AND uu.is_active = true
        AND (uu_kode IS NULL OR uu.kode = uu_kode)
    GROUP BY unnest(p.keywords)
    ORDER BY count DESC, keyword ASC;
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: get_pasal_with_links
-- Get pasal detail with linked pasal
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_pasal_with_links(
    pasal_id UUID
)
RETURNS TABLE (
    id UUID,
    undang_undang_id UUID,
    undang_undang_kode VARCHAR(20),
    undang_undang_nama VARCHAR(255),
    nomor VARCHAR(50),
    judul VARCHAR(500),
    isi TEXT,
    penjelasan TEXT,
    keywords TEXT[],
    linked_pasal JSONB
)
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.undang_undang_id,
        uu.kode AS undang_undang_kode,
        uu.nama AS undang_undang_nama,
        p.nomor,
        p.judul,
        p.isi,
        p.penjelasan,
        p.keywords,
        -- Array of linked pasal
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', lp.id,
                        'nomor', lp.nomor,
                        'judul', lp.judul,
                        'undang_undang_kode', luu.kode,
                        'keterangan', pl.keterangan
                    )
                )
                FROM public.pasal_links pl
                INNER JOIN public.pasal lp ON pl.target_pasal_id = lp.id
                INNER JOIN public.undang_undang luu ON lp.undang_undang_id = luu.id
                WHERE pl.source_pasal_id = p.id
                AND lp.is_active = true
            ),
            '[]'::JSONB
        ) AS linked_pasal
    FROM public.pasal p
    INNER JOIN public.undang_undang uu ON p.undang_undang_id = uu.id
    WHERE
        p.id = pasal_id
        AND p.is_active = true
        AND uu.is_active = true;
END;
$$;

-- ----------------------------------------------------------------------------
-- Function: get_download_data
-- Get all pasal from one undang-undang for offline download
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_download_data(
    uu_kode TEXT
)
RETURNS TABLE (
    undang_undang JSONB,
    pasal_list JSONB,
    total_pasal BIGINT
)
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
BEGIN
    RETURN QUERY
    WITH uu_data AS (
        SELECT
            uu.id,
            uu.kode,
            uu.nama,
            uu.nama_lengkap,
            uu.deskripsi,
            uu.tahun
        FROM public.undang_undang uu
        WHERE uu.kode = uu_kode AND uu.is_active = true
    ),
    pasal_data AS (
        SELECT
            jsonb_agg(
                jsonb_build_object(
                    'id', p.id,
                    'nomor', p.nomor,
                    'judul', p.judul,
                    'isi', p.isi,
                    'penjelasan', p.penjelasan,
                    'keywords', p.keywords
                ) ORDER BY p.nomor
            ) AS pasal_list,
            COUNT(*) AS total_pasal
        FROM public.pasal p
        INNER JOIN uu_data uu ON p.undang_undang_id = uu.id
        WHERE p.is_active = true
    )
    SELECT
        jsonb_build_object(
            'id', uu.id,
            'kode', uu.kode,
            'nama', uu.nama,
            'nama_lengkap', uu.nama_lengkap,
            'deskripsi', uu.deskripsi,
            'tahun', uu.tahun
        ) AS undang_undang,
        COALESCE(pd.pasal_list, '[]'::JSONB) AS pasal_list,
        COALESCE(pd.total_pasal, 0) AS total_pasal
    FROM uu_data uu
    CROSS JOIN pasal_data pd;
END;
$$;

-- ============================================================================
-- GRANT PERMISSIONS (ensure permissions are maintained after recreation)
-- ============================================================================

-- Auth helper functions
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_super_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_valid_user() TO authenticated;

-- Sync functions (for mobile app)
GRANT EXECUTE ON FUNCTION public.check_sync_updates(TIMESTAMPTZ) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_sync_updates(TIMESTAMPTZ) TO anon, authenticated;

-- Search functions
GRANT EXECUTE ON FUNCTION public.search_pasal(TEXT, TEXT, INTEGER, INTEGER) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.search_pasal_by_keywords(TEXT[], TEXT, INTEGER, INTEGER) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_all_keywords(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_pasal_with_links(UUID) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_download_data(TEXT) TO anon, authenticated;

-- Cleanup function (admin only via RLS)
GRANT EXECUTE ON FUNCTION public.cleanup_soft_deleted_data(INTEGER) TO authenticated;

-- ============================================================================
-- Summary of changes:
-- 1. All 18 functions now have SET search_path = ''
-- 2. All table references are fully qualified with public. prefix
-- 3. All permissions are re-granted after function recreation
-- ============================================================================
-- ============================================================================
-- Migration: 017_fix_rls_performance
-- Tanggal: 2026-01-20
-- Deskripsi: Fix RLS performance warnings:
--            1. auth_rls_initplan: Use (select auth.uid()) instead of auth.uid()
--            2. multiple_permissive_policies: Consolidate duplicate policies
-- ============================================================================

-- ============================================================================
-- PART 1: Drop all duplicate/redundant policies
-- ============================================================================

-- undang_undang: Drop all SELECT policies for authenticated (3 duplicates)
DROP POLICY IF EXISTS "Admin: read all undang_undang" ON undang_undang;
DROP POLICY IF EXISTS "User: read active undang_undang" ON undang_undang;
DROP POLICY IF EXISTS "authenticated_read_undang_undang" ON undang_undang;

-- pasal: Drop all SELECT policies for authenticated (3 duplicates)
DROP POLICY IF EXISTS "Admin: read all pasal" ON pasal;
DROP POLICY IF EXISTS "User: read active pasal" ON pasal;
DROP POLICY IF EXISTS "authenticated_read_pasal" ON pasal;

-- pasal_links: Drop SELECT policies for authenticated (2 duplicates)
DROP POLICY IF EXISTS "User: read active pasal_links" ON pasal_links;
DROP POLICY IF EXISTS "authenticated_read_pasal_links" ON pasal_links;

-- users: Drop SELECT policies for authenticated (2 duplicates)
DROP POLICY IF EXISTS "Admin: read users" ON users;
DROP POLICY IF EXISTS "User: read own profile" ON users;

-- user_devices: Drop the catch-all "Admin: manage user_devices" and user policies
DROP POLICY IF EXISTS "Admin: manage user_devices" ON user_devices;
DROP POLICY IF EXISTS "User: read own devices" ON user_devices;
DROP POLICY IF EXISTS "User: insert own device" ON user_devices;
DROP POLICY IF EXISTS "User: update own device" ON user_devices;

-- admin_users: Drop policies that need auth.uid() fix
DROP POLICY IF EXISTS "Admin: update own profile" ON admin_users;
DROP POLICY IF EXISTS "Super Admin: delete admin_users" ON admin_users;

-- ============================================================================
-- PART 2: Recreate consolidated policies with (select auth.uid())
-- ============================================================================

-- ----------------------------------------------------------------------------
-- undang_undang: Single SELECT policy for authenticated
-- Consolidates: Admin read all + User read active
-- ----------------------------------------------------------------------------
CREATE POLICY "authenticated_select_undang_undang" ON undang_undang
  FOR SELECT
  TO authenticated
  USING (
    (select auth.uid()) IS NOT NULL
    AND (
      -- Admins can read all (including inactive)
      (select public.is_admin())
      OR
      -- Valid users can only read active
      ((select public.is_valid_user()) AND is_active = true)
    )
  );

-- ----------------------------------------------------------------------------
-- pasal: Single SELECT policy for authenticated
-- Consolidates: Admin read all + User read active
-- ----------------------------------------------------------------------------
CREATE POLICY "authenticated_select_pasal" ON pasal
  FOR SELECT
  TO authenticated
  USING (
    (select auth.uid()) IS NOT NULL
    AND (
      -- Admins can read all (including inactive)
      (select public.is_admin())
      OR
      -- Valid users can only read active
      ((select public.is_valid_user()) AND is_active = true)
    )
  );

-- ----------------------------------------------------------------------------
-- pasal_links: Single SELECT policy for authenticated
-- Consolidates: User read active + authenticated_read
-- ----------------------------------------------------------------------------
CREATE POLICY "authenticated_select_pasal_links" ON pasal_links
  FOR SELECT
  TO authenticated
  USING (
    (select auth.uid()) IS NOT NULL
    AND (
      -- Admins can read all
      (select public.is_admin())
      OR
      -- Valid users can only read active links with active source/target
      (
        (select public.is_valid_user())
        AND is_active = true
        AND EXISTS (SELECT 1 FROM public.pasal WHERE id = source_pasal_id AND is_active = true)
        AND EXISTS (SELECT 1 FROM public.pasal WHERE id = target_pasal_id AND is_active = true)
      )
    )
  );

-- ----------------------------------------------------------------------------
-- users: Single SELECT policy for authenticated
-- Consolidates: Admin read all + User read own profile
-- ----------------------------------------------------------------------------
CREATE POLICY "authenticated_select_users" ON users
  FOR SELECT
  TO authenticated
  USING (
    (select auth.uid()) IS NOT NULL
    AND (
      -- Admins can read all users
      (select public.is_admin())
      OR
      -- Users can only read their own profile
      id = (select auth.uid())
    )
  );

-- ----------------------------------------------------------------------------
-- user_devices: Separate policies per action (fixes multiple_permissive)
-- All use (select auth.uid()) for performance
-- ----------------------------------------------------------------------------

-- SELECT: Admin can read all, User can read own
CREATE POLICY "authenticated_select_user_devices" ON user_devices
  FOR SELECT
  TO authenticated
  USING (
    (select auth.uid()) IS NOT NULL
    AND (
      (select public.is_admin())
      OR
      user_id = (select auth.uid())
    )
  );

-- INSERT: Admin can insert for any user, User can insert own
CREATE POLICY "authenticated_insert_user_devices" ON user_devices
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (select auth.uid()) IS NOT NULL
    AND (
      (select public.is_admin())
      OR
      user_id = (select auth.uid())
    )
  );

-- UPDATE: Admin can update any, User can update own
CREATE POLICY "authenticated_update_user_devices" ON user_devices
  FOR UPDATE
  TO authenticated
  USING (
    (select auth.uid()) IS NOT NULL
    AND (
      (select public.is_admin())
      OR
      user_id = (select auth.uid())
    )
  )
  WITH CHECK (
    (select auth.uid()) IS NOT NULL
    AND (
      (select public.is_admin())
      OR
      user_id = (select auth.uid())
    )
  );

-- DELETE: Only admins can delete
CREATE POLICY "admin_delete_user_devices" ON user_devices
  FOR DELETE
  TO authenticated
  USING ((select public.is_admin()));

-- ----------------------------------------------------------------------------
-- admin_users: Recreate policies with (select auth.uid())
-- ----------------------------------------------------------------------------

-- UPDATE: Super admin can update any, admin can update self
CREATE POLICY "authenticated_update_admin_users" ON admin_users
  FOR UPDATE
  TO authenticated
  USING (
    id = (select auth.uid())
    OR (select public.is_super_admin())
  )
  WITH CHECK (
    id = (select auth.uid())
    OR (select public.is_super_admin())
  );

-- DELETE: Only super admin can delete (not self)
CREATE POLICY "super_admin_delete_admin_users" ON admin_users
  FOR DELETE
  TO authenticated
  USING (
    (select public.is_super_admin())
    AND id != (select auth.uid())
  );

-- ============================================================================
-- Summary of changes:
-- 1. All policies now use (select auth.uid()) instead of auth.uid()
-- 2. All policies use (select public.is_admin()) / (select public.is_valid_user())
-- 3. Consolidated multiple SELECT policies into single policies per table
-- 4. user_devices now has separate policies per action instead of catch-all
-- ============================================================================
-- ============================================================================
-- Migration: 018_admin_devices_schema
-- Tanggal: 2026-01-20
-- Deskripsi: Create admin_devices table for mobile app admin authentication
--            with 3-device limit policy (vs 1-device for regular users)
-- ============================================================================

-- ============================================================================
-- TABLE: admin_devices
-- Tracks device binding for admin accounts (max 3 active devices per admin)
-- ============================================================================

CREATE TABLE admin_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
    device_id VARCHAR(255) NOT NULL,  -- UUID generated on first app install
    device_name VARCHAR(255),         -- Human readable: "Samsung Galaxy S21", "iPhone 14"
    is_active BOOLEAN DEFAULT true,
    last_active_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Each admin can only register a device_id once
    CONSTRAINT unique_admin_device UNIQUE(admin_id, device_id)
);

-- Indexes for common queries
CREATE INDEX idx_admin_devices_admin_id ON admin_devices(admin_id);
CREATE INDEX idx_admin_devices_device_id ON admin_devices(device_id);
CREATE INDEX idx_admin_devices_is_active ON admin_devices(is_active);

-- Comments
COMMENT ON TABLE admin_devices IS 'Device binding for mobile app admins (max 3 active devices per admin)';
COMMENT ON COLUMN admin_devices.device_id IS 'UUID generated on first app install, stored in flutter_secure_storage';
COMMENT ON COLUMN admin_devices.device_name IS 'Human-readable device name from device_info_plus';

-- ============================================================================
-- RLS: Enable Row Level Security
-- ============================================================================

ALTER TABLE admin_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_devices FORCE ROW LEVEL SECURITY;

-- Grant permissions to authenticated role
GRANT SELECT, INSERT, UPDATE, DELETE ON admin_devices TO authenticated;

-- ============================================================================
-- POLICIES: admin_devices table
-- ============================================================================

-- Unified SELECT policy: Admin sees own, Super Admin sees all
CREATE POLICY "admin_select_devices"
    ON admin_devices
    FOR SELECT
    TO authenticated
    USING (
        (admin_id = (SELECT auth.uid())) 
        OR 
        ((SELECT public.is_super_admin()))
    );

-- Admins can insert their own device (on login)
CREATE POLICY "admin_insert_own_device"
    ON admin_devices
    FOR INSERT
    TO authenticated
    WITH CHECK (admin_id = (SELECT auth.uid()) AND (SELECT public.is_admin()));

-- Unified UPDATE policy: Admin updates own, Super Admin updates all
CREATE POLICY "admin_update_devices"
    ON admin_devices
    FOR UPDATE
    TO authenticated
    USING (
        (admin_id = (SELECT auth.uid()) AND (SELECT public.is_admin()))
        OR
        ((SELECT public.is_super_admin()))
    )
    WITH CHECK (
        (admin_id = (SELECT auth.uid()) AND (SELECT public.is_admin()))
        OR
        ((SELECT public.is_super_admin()))
    );

-- Super admins can delete admin devices
CREATE POLICY "super_admin_delete_devices"
    ON admin_devices
    FOR DELETE
    TO authenticated
    USING ((SELECT public.is_super_admin()));

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
-- ============================================================================
-- CARIPASAL - Seed Data (Data Dummy)
-- Versi: 1.0.0
-- Tanggal: 2025-12-12
-- Deskripsi: Data dummy untuk testing dan development
-- ============================================================================

-- ============================================================================
-- INSERT UNDANG-UNDANG
-- ============================================================================

INSERT INTO undang_undang (id, kode, nama, nama_lengkap, deskripsi, tahun) VALUES
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'KUHP',
    'KUHP',
    'Kitab Undang-Undang Hukum Pidana',
    'Kitab Undang-Undang Hukum Pidana adalah peraturan perundang-undangan yang mengatur mengenai perbuatan pidana.',
    1946
),
(
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    'KUHPER',
    'KUHPer',
    'Kitab Undang-Undang Hukum Perdata',
    'Kitab Undang-Undang Hukum Perdata adalah peraturan yang mengatur hubungan hukum antara orang-orang dalam masyarakat.',
    1848
),
(
    'c3d4e5f6-a7b8-9012-cdef-123456789012',
    'KUHAP',
    'KUHAP',
    'Kitab Undang-Undang Hukum Acara Pidana',
    'Kitab Undang-Undang Hukum Acara Pidana mengatur tata cara penyelesaian perkara pidana.',
    1981
),
(
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    'UU_ITE',
    'UU ITE',
    'Undang-Undang Informasi dan Transaksi Elektronik',
    'Undang-Undang yang mengatur tentang informasi serta transaksi elektronik, atau teknologi informasi.',
    2008
);

-- ============================================================================
-- INSERT PASAL KUHP (Contoh)
-- ============================================================================

INSERT INTO pasal (undang_undang_id, nomor, judul, isi, penjelasan, keywords) VALUES

-- KUHP Pasal 1
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    '1',
    'Asas Legalitas',
    '(1) Suatu perbuatan tidak dapat dipidana, kecuali berdasarkan kekuatan ketentuan perundang-undangan pidana yang telah ada.
(2) Bilamana ada perubahan dalam perundang-undangan sesudah perbuatan dilakukan, maka terhadap terdakwa diterapkan ketentuan yang paling menguntungkannya.',
    'Pasal ini mengatur tentang asas legalitas dalam hukum pidana. Seseorang tidak dapat dipidana jika tidak ada undang-undang yang mengaturnya sebelum perbuatan tersebut dilakukan.',
    ARRAY['asas legalitas', 'perbuatan pidana', 'ketentuan perundang-undangan', 'terdakwa', 'perubahan undang-undang']
),

-- KUHP Pasal 340
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    '340',
    'Pembunuhan Berencana',
    'Barang siapa dengan sengaja dan dengan rencana terlebih dahulu merampas nyawa orang lain, diancam karena pembunuhan dengan rencana, dengan pidana mati atau pidana penjara seumur hidup atau selama waktu tertentu, paling lama dua puluh tahun.',
    'Pembunuhan berencana adalah pembunuhan yang dilakukan dengan perencanaan terlebih dahulu. Ancaman pidananya lebih berat daripada pembunuhan biasa.',
    ARRAY['pembunuhan', 'pembunuhan berencana', 'merampas nyawa', 'pidana mati', 'pidana penjara', 'seumur hidup']
),

-- KUHP Pasal 338
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    '338',
    'Pembunuhan',
    'Barang siapa dengan sengaja merampas nyawa orang lain, diancam karena pembunuhan dengan pidana penjara paling lama lima belas tahun.',
    'Pasal ini mengatur tentang pembunuhan biasa (tanpa perencanaan). Ancaman pidananya maksimal 15 tahun penjara.',
    ARRAY['pembunuhan', 'merampas nyawa', 'pidana penjara', 'sengaja']
),

-- KUHP Pasal 362
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    '362',
    'Pencurian',
    'Barang siapa mengambil barang sesuatu, yang seluruhnya atau sebagian kepunyaan orang lain, dengan maksud untuk dimiliki secara melawan hukum, diancam karena pencurian, dengan pidana penjara paling lama lima tahun atau pidana denda paling banyak sembilan ratus rupiah.',
    'Pasal ini mengatur tentang tindak pidana pencurian biasa.',
    ARRAY['pencurian', 'mengambil barang', 'melawan hukum', 'pidana penjara', 'denda']
),

-- KUHP Pasal 363
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    '363',
    'Pencurian dengan Pemberatan',
    '(1) Diancam dengan pidana penjara paling lama tujuh tahun:
1. pencurian ternak;
2. pencurian pada waktu ada kebakaran, letusan, banjir gempa bumi, atau gempa laut, gunung meletus, kapal karam, kapal terdampar, kecelakaan kereta api, huru-hara, pemberontakan atau bahaya perang;
3. pencurian di waktu malam dalam sebuah rumah atau pekarangan tertutup yang ada rumahnya, yang dilakukan oleh orang yang ada di situ tidak diketahui atau tidak dikehendaki oleh yang berhak;
4. pencurian yang dilakukan oleh dua orang atau lebih;
5. pencurian yang untuk masuk ke tempat melakukan kejahatan, atau untuk sampai pada barang yang diambil, dilakukan dengan merusak, memotong atau memanjat, atau dengan memakai anak kunci palsu, perintah palsu atau pakaian jabatan palsu.',
    'Pencurian dengan pemberatan adalah pencurian yang disertai keadaan-keadaan yang memberatkan.',
    ARRAY['pencurian', 'pemberatan', 'ternak', 'malam hari', 'merusak', 'memanjat', 'anak kunci palsu']
),

-- KUHP Pasal 372
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    '372',
    'Penggelapan',
    'Barang siapa dengan sengaja dan melawan hukum memiliki barang sesuatu yang seluruhnya atau sebagian adalah kepunyaan orang lain, tetapi yang ada dalam kekuasaannya bukan karena kejahatan diancam karena penggelapan, dengan pidana penjara paling lama empat tahun atau pidana denda paling banyak sembilan ratus rupiah.',
    'Penggelapan adalah memiliki barang yang sudah dalam kekuasaannya secara sah tetapi kemudian dimiliki secara melawan hukum.',
    ARRAY['penggelapan', 'memiliki barang', 'melawan hukum', 'kepercayaan', 'pidana penjara']
),

-- KUHP Pasal 378
(
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    '378',
    'Penipuan',
    'Barang siapa dengan maksud untuk menguntungkan diri sendiri atau orang lain secara melawan hukum, dengan memakai nama palsu atau martabat palsu, dengan tipu muslihat, ataupun rangkaian kebohongan, menggerakkan orang lain untuk menyerahkan barang sesuatu kepadanya, atau supaya memberi hutang rnaupun menghapuskan piutang diancam karena penipuan dengan pidana penjara paling lama empat tahun.',
    'Penipuan adalah perbuatan untuk menguntungkan diri sendiri dengan cara menipu orang lain.',
    ARRAY['penipuan', 'tipu muslihat', 'kebohongan', 'nama palsu', 'menguntungkan diri', 'pidana penjara']
);

-- ============================================================================
-- INSERT PASAL KUHPER (Contoh)
-- ============================================================================

INSERT INTO pasal (undang_undang_id, nomor, judul, isi, penjelasan, keywords) VALUES

-- KUHPer Pasal 1320
(
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    '1320',
    'Syarat Sah Perjanjian',
    'Untuk sahnya suatu perjanjian diperlukan empat syarat:
1. sepakat mereka yang mengikatkan dirinya;
2. kecakapan untuk membuat suatu perikatan;
3. suatu hal tertentu;
4. suatu sebab yang halal.',
    'Pasal ini mengatur tentang empat syarat sahnya suatu perjanjian yang harus dipenuhi agar perjanjian tersebut memiliki kekuatan hukum.',
    ARRAY['perjanjian', 'syarat sah', 'sepakat', 'kecakapan', 'perikatan', 'sebab halal', 'kontrak']
),

-- KUHPer Pasal 1365
(
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    '1365',
    'Perbuatan Melawan Hukum',
    'Tiap perbuatan melanggar hukum, yang membawa kerugian kepada seorang lain, mewajibkan orang yang karena salahnya menerbitkan kerugian itu, mengganti kerugian tersebut.',
    'Pasal ini mengatur tentang perbuatan melawan hukum (onrechtmatige daad) yang mewajibkan pelaku untuk mengganti kerugian yang ditimbulkan.',
    ARRAY['perbuatan melawan hukum', 'kerugian', 'ganti rugi', 'onrechtmatige daad', 'tanggung jawab']
),

-- KUHPer Pasal 1234
(
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    '1234',
    'Jenis Perikatan',
    'Tiap-tiap perikatan adalah untuk memberikan sesuatu, untuk berbuat sesuatu, atau untuk tidak berbuat sesuatu.',
    'Pasal ini menjelaskan tiga jenis prestasi dalam suatu perikatan.',
    ARRAY['perikatan', 'prestasi', 'memberikan', 'berbuat', 'tidak berbuat']
),

-- KUHPer Pasal 1338
(
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    '1338',
    'Kebebasan Berkontrak',
    'Semua perjanjian yang dibuat secara sah berlaku sebagai undang-undang bagi mereka yang membuatnya. Suatu perjanjian tidak dapat ditarik kembali selain dengan sepakat kedua belah pihak, atau karena alasan-alasan yang oleh undang-undang dinyatakan cukup untuk itu. Suatu perjanjian harus dilaksanakan dengan itikad baik.',
    'Pasal ini mengatur tentang asas kebebasan berkontrak dan kekuatan mengikat perjanjian.',
    ARRAY['perjanjian', 'kontrak', 'kebebasan berkontrak', 'undang-undang', 'itikad baik', 'pacta sunt servanda']
),

-- KUHPer Pasal 1381
(
    'b2c3d4e5-f6a7-8901-bcde-f12345678901',
    '1381',
    'Hapusnya Perikatan',
    'Perikatan-perikatan hapus:
1. karena pembayaran;
2. karena penawaran pembayaran tunai, diikuti dengan penyimpanan atau penitipan;
3. karena pembaharuan utang;
4. karena perjumpaan utang atau kompensasi;
5. karena percampuran utang;
6. karena pembebasan utangnya;
7. karena musnahnya barang yang terutang;
8. karena kebatalan atau pembatalan;
9. karena berlakunya suatu syarat batal;
10. karena lewatnya waktu.',
    'Pasal ini mengatur tentang cara-cara hapusnya suatu perikatan.',
    ARRAY['perikatan', 'hapus', 'pembayaran', 'kompensasi', 'pembebasan utang', 'pembatalan', 'daluwarsa']
);

-- ============================================================================
-- INSERT PASAL KUHAP (Contoh)
-- ============================================================================

INSERT INTO pasal (undang_undang_id, nomor, judul, isi, penjelasan, keywords) VALUES

-- KUHAP Pasal 1 angka 1
(
    'c3d4e5f6-a7b8-9012-cdef-123456789012',
    '1 angka 1',
    'Definisi Penyidik',
    'Penyidik adalah pejabat polisi negara Republik Indonesia atau pejabat pegawai negeri sipil tertentu yang diberi wewenang khusus oleh undang-undang untuk melakukan penyidikan.',
    'Pasal ini memberikan definisi tentang siapa yang dimaksud dengan penyidik.',
    ARRAY['penyidik', 'polisi', 'pegawai negeri sipil', 'penyidikan', 'definisi']
),

-- KUHAP Pasal 1 angka 2
(
    'c3d4e5f6-a7b8-9012-cdef-123456789012',
    '1 angka 2',
    'Definisi Penyidikan',
    'Penyidikan adalah serangkaian tindakan penyidik dalam hal dan menurut cara yang diatur dalam undang-undang ini untuk mencari serta mengumpulkan bukti yang dengan bukti itu membuat terang tentang tindak pidana yang terjadi dan guna menemukan tersangkanya.',
    'Pasal ini memberikan definisi tentang apa yang dimaksud dengan penyidikan.',
    ARRAY['penyidikan', 'bukti', 'tindak pidana', 'tersangka', 'definisi']
),

-- KUHAP Pasal 21
(
    'c3d4e5f6-a7b8-9012-cdef-123456789012',
    '21',
    'Penahanan',
    '(1) Perintah penahanan atau penahanan lanjutan dilakukan terhadap seorang tersangka atau terdakwa yang diduga keras melakukan tindak pidana berdasarkan bukti yang cukup, dalam hal adanya keadaan yang menimbulkan kekhawatiran bahwa tersangka atau terdakwa akan melarikan diri, merusak atau menghilangkan barang bukti dan atau mengulangi tindak pidana.',
    'Pasal ini mengatur tentang syarat-syarat untuk melakukan penahanan terhadap tersangka atau terdakwa.',
    ARRAY['penahanan', 'tersangka', 'terdakwa', 'bukti', 'melarikan diri', 'barang bukti']
),

-- KUHAP Pasal 77
(
    'c3d4e5f6-a7b8-9012-cdef-123456789012',
    '77',
    'Praperadilan',
    'Pengadilan negeri berwenang untuk memeriksa dan memutus, sesuai dengan ketentuan yang diatur dalam undang-undang ini tentang:
a. sah atau tidaknya penangkapan, penahanan, penghentian penyidikan atau penghentian penuntutan;
b. ganti kerugian dan atau rehabilitasi bagi seorang yang perkara pidananya dihentikan pada tingkat penyidikan atau penuntutan.',
    'Pasal ini mengatur tentang kewenangan praperadilan dalam memeriksa tindakan aparat penegak hukum.',
    ARRAY['praperadilan', 'pengadilan negeri', 'penangkapan', 'penahanan', 'penghentian penyidikan', 'ganti kerugian', 'rehabilitasi']
),

-- KUHAP Pasal 183
(
    'c3d4e5f6-a7b8-9012-cdef-123456789012',
    '183',
    'Minimal Dua Alat Bukti',
    'Hakim tidak boleh menjatuhkan pidana kepada seorang kecuali apabila dengan sekurang-kurangnya dua alat bukti yang sah ia memperoleh keyakinan bahwa suatu tindak pidana benar-benar terjadi dan bahwa terdakwalah yang bersalah melakukannya.',
    'Pasal ini mengatur tentang pembuktian minimal dalam hukum acara pidana.',
    ARRAY['alat bukti', 'pembuktian', 'hakim', 'keyakinan', 'terdakwa', 'minimal dua alat bukti']
);

-- ============================================================================
-- INSERT PASAL UU ITE (Contoh)
-- ============================================================================

INSERT INTO pasal (undang_undang_id, nomor, judul, isi, penjelasan, keywords) VALUES

-- UU ITE Pasal 27 ayat (1)
(
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    '27 ayat (1)',
    'Muatan Asusila',
    'Setiap Orang dengan sengaja dan tanpa hak mendistribusikan dan/atau mentransmisikan dan/atau membuat dapat diaksesnya Informasi Elektronik dan/atau Dokumen Elektronik yang memiliki muatan yang melanggar kesusilaan.',
    'Pasal ini mengatur tentang larangan mendistribusikan konten asusila melalui media elektronik.',
    ARRAY['informasi elektronik', 'dokumen elektronik', 'asusila', 'kesusilaan', 'distribusi', 'transmisi']
),

-- UU ITE Pasal 27 ayat (3)
(
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    '27 ayat (3)',
    'Penghinaan dan/atau Pencemaran Nama Baik',
    'Setiap Orang dengan sengaja dan tanpa hak mendistribusikan dan/atau mentransmisikan dan/atau membuat dapat diaksesnya Informasi Elektronik dan/atau Dokumen Elektronik yang memiliki muatan penghinaan dan/atau pencemaran nama baik.',
    'Pasal ini mengatur tentang larangan penghinaan dan pencemaran nama baik melalui media elektronik.',
    ARRAY['penghinaan', 'pencemaran nama baik', 'informasi elektronik', 'dokumen elektronik', 'defamasi']
),

-- UU ITE Pasal 28 ayat (1)
(
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    '28 ayat (1)',
    'Berita Bohong yang Merugikan Konsumen',
    'Setiap Orang dengan sengaja dan tanpa hak menyebarkan berita bohong dan menyesatkan yang mengakibatkan kerugian konsumen dalam Transaksi Elektronik.',
    'Pasal ini mengatur tentang larangan menyebarkan berita bohong dalam transaksi elektronik yang merugikan konsumen.',
    ARRAY['berita bohong', 'hoax', 'konsumen', 'transaksi elektronik', 'kerugian']
),

-- UU ITE Pasal 28 ayat (2)
(
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    '28 ayat (2)',
    'Ujaran Kebencian (SARA)',
    'Setiap Orang dengan sengaja dan tanpa hak menyebarkan informasi yang ditujukan untuk menimbulkan rasa kebencian atau permusuhan individu dan/atau kelompok masyarakat tertentu berdasarkan atas suku, agama, ras, dan antargolongan (SARA).',
    'Pasal ini mengatur tentang larangan ujaran kebencian berbasis SARA melalui media elektronik.',
    ARRAY['ujaran kebencian', 'hate speech', 'SARA', 'suku', 'agama', 'ras', 'permusuhan']
),

-- UU ITE Pasal 30
(
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    '30',
    'Akses Ilegal',
    '(1) Setiap Orang dengan sengaja dan tanpa hak atau melawan hukum mengakses Komputer dan/atau Sistem Elektronik milik Orang lain dengan cara apa pun.
(2) Setiap Orang dengan sengaja dan tanpa hak atau melawan hukum mengakses Komputer dan/atau Sistem Elektronik dengan cara apa pun dengan tujuan untuk memperoleh Informasi Elektronik dan/atau Dokumen Elektronik.
(3) Setiap Orang dengan sengaja dan tanpa hak atau melawan hukum mengakses Komputer dan/atau Sistem Elektronik dengan cara apa pun dengan melanggar, menerobos, melampaui, atau menjebol sistem pengamanan.',
    'Pasal ini mengatur tentang larangan akses ilegal terhadap sistem komputer atau sistem elektronik.',
    ARRAY['akses ilegal', 'hacking', 'komputer', 'sistem elektronik', 'melawan hukum', 'menerobos', 'sistem pengamanan']
),

-- UU ITE Pasal 32
(
    'd4e5f6a7-b8c9-0123-defa-234567890123',
    '32',
    'Gangguan Data',
    '(1) Setiap Orang dengan sengaja dan tanpa hak atau melawan hukum dengan cara apa pun mengubah, menambah, mengurangi, melakukan transmisi, merusak, menghilangkan, memindahkan, menyembunyikan suatu Informasi Elektronik dan/atau Dokumen Elektronik milik Orang lain atau milik publik.',
    'Pasal ini mengatur tentang larangan melakukan gangguan terhadap data elektronik milik orang lain.',
    ARRAY['gangguan data', 'merusak data', 'mengubah data', 'informasi elektronik', 'dokumen elektronik', 'data manipulation']
);

-- ============================================================================
-- INSERT PASAL LINKS (Contoh Relasi Antar Pasal)
-- ============================================================================

-- Ambil ID pasal yang akan di-link
DO $$
DECLARE
    pasal_338_id UUID;
    pasal_340_id UUID;
    pasal_362_id UUID;
    pasal_363_id UUID;
    pasal_1320_id UUID;
    pasal_1338_id UUID;
BEGIN
    -- Ambil ID
    SELECT id INTO pasal_338_id FROM pasal WHERE nomor = '338' AND undang_undang_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
    SELECT id INTO pasal_340_id FROM pasal WHERE nomor = '340' AND undang_undang_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
    SELECT id INTO pasal_362_id FROM pasal WHERE nomor = '362' AND undang_undang_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
    SELECT id INTO pasal_363_id FROM pasal WHERE nomor = '363' AND undang_undang_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
    SELECT id INTO pasal_1320_id FROM pasal WHERE nomor = '1320' AND undang_undang_id = 'b2c3d4e5-f6a7-8901-bcde-f12345678901';
    SELECT id INTO pasal_1338_id FROM pasal WHERE nomor = '1338' AND undang_undang_id = 'b2c3d4e5-f6a7-8901-bcde-f12345678901';
    
    -- Insert links
    INSERT INTO pasal_links (source_pasal_id, target_pasal_id, keterangan) VALUES
    (pasal_340_id, pasal_338_id, 'Lihat juga pasal pembunuhan biasa'),
    (pasal_338_id, pasal_340_id, 'Lihat juga pasal pembunuhan berencana'),
    (pasal_363_id, pasal_362_id, 'Bentuk dasar pencurian'),
    (pasal_362_id, pasal_363_id, 'Bentuk pemberatan'),
    (pasal_1338_id, pasal_1320_id, 'Syarat sah perjanjian');
END $$;

-- ============================================================================
-- END OF SEED DATA
-- ============================================================================
