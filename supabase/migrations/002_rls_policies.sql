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
