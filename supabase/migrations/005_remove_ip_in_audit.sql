-- ============================================================================
-- Migration: 005_audit_enhancement (Cancelled)
-- Tanggal: 2025-12-14
-- Deskripsi: IP address dan User Agent tidak diimplementasikan
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CANCELLED: IP Address dan User Agent tidak akan ditambahkan ke audit logs
-- ----------------------------------------------------------------------------
-- Kolom ip_address dan user_agent tidak akan ditambahkan ke tabel audit_logs
-- Function log_audit() tetap menggunakan versi original tanpa client information

-- ----------------------------------------------------------------------------
-- Step 1: Drop columns from audit_logs table
-- ----------------------------------------------------------------------------
ALTER TABLE audit_logs DROP COLUMN IF EXISTS ip_address;
ALTER TABLE audit_logs DROP COLUMN IF EXISTS user_agent;

-- ----------------------------------------------------------------------------
-- Function: log_audit (Unchanged - Original Version)
-- Deskripsi: Mencatat perubahan ke audit_logs (versi original)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION log_audit()
RETURNS TRIGGER AS $$
DECLARE
    admin_id_val UUID;
    admin_email_val VARCHAR(255);
    action_val audit_action;
    old_data_val JSONB;
    new_data_val JSONB;
    record_id_val UUID;
BEGIN
    -- Dapatkan admin dari auth.uid()
    admin_id_val := auth.uid();

    -- Dapatkan email admin
    SELECT email INTO admin_email_val
    FROM admin_users
    WHERE id = admin_id_val;

    -- Tentukan action dan data
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

    -- Insert ke audit_logs (hanya jika ada admin)
    IF admin_id_val IS NOT NULL THEN
        INSERT INTO audit_logs (
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE audit_logs IS 'Log perubahan data untuk keperluan audit';