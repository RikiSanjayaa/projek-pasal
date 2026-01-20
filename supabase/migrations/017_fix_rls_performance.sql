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
