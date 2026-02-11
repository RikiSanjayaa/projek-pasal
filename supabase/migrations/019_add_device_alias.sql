-- ============================================================================
-- Migration: 019_add_device_alias
-- Tanggal: 2026-02-11
-- Deskripsi: Add device_alias column to user_devices and admin_devices tables
--            to allow admins to assign custom names to devices.
-- ============================================================================

-- Add device_alias to user_devices if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_devices' AND column_name = 'device_alias') THEN
        ALTER TABLE user_devices ADD COLUMN device_alias VARCHAR(255);
        COMMENT ON COLUMN user_devices.device_alias IS 'Custom alias assigned by admin (e.g., "Rizki Personal Phone")';
    END IF;
END $$;

-- Add device_alias to admin_devices if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'admin_devices' AND column_name = 'device_alias') THEN
        ALTER TABLE admin_devices ADD COLUMN device_alias VARCHAR(255);
        COMMENT ON COLUMN admin_devices.device_alias IS 'Custom alias assigned by admin';
    END IF;
END $$;

-- Policies update (optional, but good to verify)
-- Existing policies for UPDATE on user_devices for admins should cover this new column
-- automatically since they are defined as "FOR ALL" or "FOR UPDATE".

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
