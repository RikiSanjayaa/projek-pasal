-- ============================================================================
-- Migration: 011_user_auth_schema
-- Tanggal: 2026-01-10
-- Deskripsi: Create users and user_devices tables for mobile app authentication
--            with 3-year expiry and one-device policy
-- ============================================================================

-- ============================================================================
-- TABLE: users
-- Mobile app users (separate from admin_users)
-- ============================================================================

CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    nama VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,  -- User access expires at this timestamp
    created_by UUID REFERENCES admin_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_is_active ON users(is_active);
CREATE INDEX idx_users_expires_at ON users(expires_at);

-- Comments
COMMENT ON TABLE users IS 'Mobile app users with 3-year access expiry';
COMMENT ON COLUMN users.expires_at IS 'User access expires at this timestamp (typically created_at + 3 years)';
COMMENT ON COLUMN users.created_by IS 'Admin who created this user';

-- Trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_users_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at_trigger
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_users_updated_at();

-- ============================================================================
-- TABLE: user_devices
-- Tracks device binding for one-device policy
-- ============================================================================

CREATE TABLE user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id VARCHAR(255) NOT NULL,  -- UUID generated on first app install
    device_name VARCHAR(255),         -- Human readable: "Samsung Galaxy S21", "iPhone 14"
    is_active BOOLEAN DEFAULT true,
    last_active_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Each user can only register a device_id once
    CONSTRAINT unique_user_device UNIQUE(user_id, device_id)
);

-- Indexes for common queries
CREATE INDEX idx_user_devices_user_id ON user_devices(user_id);
CREATE INDEX idx_user_devices_device_id ON user_devices(device_id);
CREATE INDEX idx_user_devices_is_active ON user_devices(is_active);

-- Comments
COMMENT ON TABLE user_devices IS 'Device binding for mobile app users (one active device per user)';
COMMENT ON COLUMN user_devices.device_id IS 'UUID generated on first app install, stored in flutter_secure_storage';
COMMENT ON COLUMN user_devices.device_name IS 'Human-readable device name from device_info_plus';

-- ============================================================================
-- HELPER FUNCTION: is_valid_user
-- Check if current authenticated user is a valid mobile app user
-- ============================================================================

CREATE OR REPLACE FUNCTION is_valid_user()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid()
        AND is_active = true
        AND expires_at > NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION is_valid_user IS 'Returns TRUE if authenticated user is a valid, non-expired mobile app user';

-- ============================================================================
-- RLS: Enable Row Level Security on new tables
-- ============================================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- POLICIES: users table
-- ============================================================================

-- Admins can read all users
CREATE POLICY "Admin: read users"
    ON users
    FOR SELECT
    TO authenticated
    USING (is_admin());

-- Admins can create new users
CREATE POLICY "Admin: insert users"
    ON users
    FOR INSERT
    TO authenticated
    WITH CHECK (is_admin());

-- Admins can update users (toggle active, re-provision expiry)
CREATE POLICY "Admin: update users"
    ON users
    FOR UPDATE
    TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

-- Admins can delete users
CREATE POLICY "Admin: delete users"
    ON users
    FOR DELETE
    TO authenticated
    USING (is_admin());

-- Users can read their own profile (for checking expiry on login)
CREATE POLICY "User: read own profile"
    ON users
    FOR SELECT
    TO authenticated
    USING (id = auth.uid());

-- ============================================================================
-- POLICIES: user_devices table
-- ============================================================================

-- Admins can manage all user devices
CREATE POLICY "Admin: manage user_devices"
    ON user_devices
    FOR ALL
    TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

-- Users can read their own devices
CREATE POLICY "User: read own devices"
    ON user_devices
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Users can insert their own device (on login)
CREATE POLICY "User: insert own device"
    ON user_devices
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- Users can update their own device (last_active_at, is_active for logout)
CREATE POLICY "User: update own device"
    ON user_devices
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
