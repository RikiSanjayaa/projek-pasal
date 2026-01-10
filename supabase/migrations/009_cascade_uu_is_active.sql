-- ============================================================================
-- Migration: 009_cascade_uu_is_active
-- Tanggal: 2026-01-09
-- Deskripsi: Cascade is_active dari undang_undang ke pasal
--            Ketika UU dinonaktifkan, semua pasal terkait juga dinonaktifkan
--            Ketika UU diaktifkan kembali, semua pasal terkait juga diaktifkan
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Function: cascade_uu_is_active_to_pasal
-- Deskripsi: Cascade is_active status dari undang_undang ke semua pasal terkait
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cascade_uu_is_active_to_pasal()
RETURNS TRIGGER AS $$
BEGIN
    -- Hanya jalankan jika is_active berubah
    IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
        -- Update semua pasal yang terkait dengan UU ini
        UPDATE pasal
        SET is_active = NEW.is_active,
            updated_at = NOW()
        WHERE undang_undang_id = NEW.id;

        -- Log untuk debugging (opsional, bisa dihapus di production)
        RAISE NOTICE 'Cascaded is_active=% from undang_undang % to all related pasal',
                     NEW.is_active, NEW.id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Trigger: tr_undang_undang_cascade_is_active
-- Deskripsi: Trigger untuk cascade is_active saat undang_undang diupdate
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS tr_undang_undang_cascade_is_active ON undang_undang;

CREATE TRIGGER tr_undang_undang_cascade_is_active
    AFTER UPDATE ON undang_undang
    FOR EACH ROW
    WHEN (OLD.is_active IS DISTINCT FROM NEW.is_active)
    EXECUTE FUNCTION cascade_uu_is_active_to_pasal();

-- ============================================================================
-- Comment untuk dokumentasi
-- ============================================================================
COMMENT ON FUNCTION cascade_uu_is_active_to_pasal() IS
    'Cascade is_active status dari undang_undang ke semua pasal terkait. '
    'Ketika UU dinonaktifkan, semua pasal akan ikut nonaktif. '
    'Ketika UU diaktifkan, semua pasal akan ikut aktif.';

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
