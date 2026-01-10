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
