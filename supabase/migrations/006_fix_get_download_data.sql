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
