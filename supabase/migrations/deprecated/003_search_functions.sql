-- ============================================================================
-- CARIPASAL - Search Functions
-- Versi: 1.0.0
-- Tanggal: 2025-12-12
-- Deskripsi: Fungsi-fungsi untuk pencarian pasal
-- ============================================================================

-- ============================================================================
-- SEARCH FUNCTIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function: search_pasal
-- Deskripsi: Pencarian pasal dengan exact word match dan filter
-- Parameter:
--   - search_query: kata kunci pencarian (bisa multiple words)
--   - uu_kode: filter berdasarkan kode undang-undang (NULL = semua)
--   - page_number: halaman hasil (default 1)
--   - page_size: jumlah hasil per halaman (default 20)
-- Return: Daftar pasal yang cocok dengan ranking
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION search_pasal(
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
) AS $$
DECLARE
    search_tsquery TSQUERY;
    offset_val INTEGER;
BEGIN
    -- Validasi input
    IF search_query IS NULL OR TRIM(search_query) = '' THEN
        RETURN;
    END IF;
    
    -- Hitung offset
    offset_val := (page_number - 1) * page_size;
    
    -- Konversi search query ke tsquery (exact word match)
    -- Menggunakan plainto_tsquery untuk exact match
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
        FROM pasal p
        INNER JOIN undang_undang uu ON p.undang_undang_id = uu.id
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
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- Function: search_pasal_by_keywords
-- Deskripsi: Pencarian pasal berdasarkan keywords (exact match)
-- Parameter:
--   - keyword_list: array kata kunci yang harus ada SEMUA (AND logic)
--   - uu_kode: filter berdasarkan kode undang-undang (NULL = semua)
-- Return: Daftar pasal yang memiliki SEMUA keywords
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION search_pasal_by_keywords(
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
) AS $$
DECLARE
    offset_val INTEGER;
BEGIN
    -- Validasi input
    IF keyword_list IS NULL OR array_length(keyword_list, 1) IS NULL THEN
        RETURN;
    END IF;
    
    -- Hitung offset
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
            -- Keywords yang cocok
            ARRAY(
                SELECT unnest(keyword_list) 
                INTERSECT 
                SELECT unnest(p.keywords)
            ) AS matched_keywords
        FROM pasal p
        INNER JOIN undang_undang uu ON p.undang_undang_id = uu.id
        WHERE 
            p.is_active = true
            AND uu.is_active = true
            -- Semua keyword harus ada di array keywords pasal
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
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- Function: get_all_keywords
-- Deskripsi: Mendapatkan daftar semua keywords unik (untuk autocomplete)
-- Return: Daftar keywords dengan jumlah pasal yang menggunakannya
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_all_keywords(
    uu_kode TEXT DEFAULT NULL
)
RETURNS TABLE (
    keyword TEXT,
    count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        unnest(p.keywords) AS keyword,
        COUNT(*) AS count
    FROM pasal p
    INNER JOIN undang_undang uu ON p.undang_undang_id = uu.id
    WHERE 
        p.is_active = true
        AND uu.is_active = true
        AND (uu_kode IS NULL OR uu.kode = uu_kode)
    GROUP BY unnest(p.keywords)
    ORDER BY count DESC, keyword ASC;
END;
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- Function: get_pasal_with_links
-- Deskripsi: Mendapatkan detail pasal beserta pasal-pasal terkait
-- Return: Detail pasal + array pasal terkait
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_pasal_with_links(
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
) AS $$
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
                FROM pasal_links pl
                INNER JOIN pasal lp ON pl.target_pasal_id = lp.id
                INNER JOIN undang_undang luu ON lp.undang_undang_id = luu.id
                WHERE pl.source_pasal_id = p.id
                AND lp.is_active = true
            ),
            '[]'::JSONB
        ) AS linked_pasal
    FROM pasal p
    INNER JOIN undang_undang uu ON p.undang_undang_id = uu.id
    WHERE 
        p.id = pasal_id
        AND p.is_active = true
        AND uu.is_active = true;
END;
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- Function: get_download_data
-- Deskripsi: Mendapatkan semua pasal dari satu undang-undang untuk download offline
-- Return: Semua pasal dengan metadata
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_download_data(
    uu_kode TEXT
)
RETURNS TABLE (
    undang_undang JSONB,
    pasal_list JSONB,
    version INTEGER,
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
            uu.tahun,
            uu.version
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
        uu.version,
        COALESCE(pd.total_pasal, 0) AS total_pasal
    FROM uu_data uu
    CROSS JOIN pasal_data pd;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- GRANT EXECUTE PERMISSIONS
-- ============================================================================

-- Fungsi pencarian bisa diakses oleh siapa saja (termasuk anon)
GRANT EXECUTE ON FUNCTION search_pasal TO anon, authenticated;
GRANT EXECUTE ON FUNCTION search_pasal_by_keywords TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_all_keywords TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_pasal_with_links TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_download_data TO anon, authenticated;

-- ============================================================================
-- END OF SEARCH FUNCTIONS
-- ============================================================================
