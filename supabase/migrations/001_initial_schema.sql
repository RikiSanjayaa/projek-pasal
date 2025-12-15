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
