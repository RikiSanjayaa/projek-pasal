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
