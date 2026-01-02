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
