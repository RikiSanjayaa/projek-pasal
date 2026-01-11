-- ============================================================================
-- Migration: 014_audit_improvements
-- Tanggal: 2026-01-11
-- Deskripsi:
--   1. Skip audit log saat cascade dari UU ke pasal (menghindari log bloat)
--   2. Tambah audit trigger untuk tabel users
-- ============================================================================

-- ============================================================================
-- PART 1: Skip audit during cascade updates
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Update log_audit function to check for cascade flag
-- Jika sedang dalam mode cascade, skip logging
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

-- ----------------------------------------------------------------------------
-- Update cascade function to set cascade flag
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cascade_uu_is_active_to_pasal()
RETURNS TRIGGER AS $$
DECLARE
    affected_count INTEGER;
BEGIN
    -- Hanya jalankan jika is_active berubah
    IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN

        -- Set cascade flag to skip audit logging for cascaded updates
        PERFORM set_config('app.is_cascade_update', 'true', true);

        -- Update pasal:
        -- HANYA JIKA pasal tersebut TIDAK sedang dihapus (deleted_at IS NULL)
        UPDATE pasal
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
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 2: Add audit trigger for users table
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Trigger untuk audit log pada tabel users
-- Melacak: user dibuat, diaktifkan/dinonaktifkan, expiry diperpanjang, dihapus
-- ----------------------------------------------------------------------------
CREATE TRIGGER tr_users_audit
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION log_audit();

COMMENT ON TRIGGER tr_users_audit ON users IS
    'Audit log untuk perubahan data user mobile app';

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
