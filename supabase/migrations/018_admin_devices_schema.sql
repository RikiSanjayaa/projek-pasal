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
