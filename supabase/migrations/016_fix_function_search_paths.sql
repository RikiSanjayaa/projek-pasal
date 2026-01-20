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
