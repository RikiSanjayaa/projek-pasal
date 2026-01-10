-- ============================================================================
-- Migration: 013_fix_cascade_uu_is_active
-- Tanggal: 2026-01-10
-- Deskripsi: Memperbaiki logic cascade is_active agar TIDAK mengaktifkan
--            kembali pasal yang sudah dihapus (soft delete / ada deleted_at).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Perbarui Function Logic
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cascade_uu_is_active_to_pasal()
RETURNS TRIGGER AS $$
BEGIN
    -- Hanya jalankan jika is_active berubah
    IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
        
        -- Update pasal:
        -- 1. Set is_active mengikuti status UU baru
        -- 2. TAPI HANYA JIKA pasal tersebut TIDAK sedang dihapus (deleted_at IS NULL)
        --    Ini mencegah pasal "Sampah" ikut aktif kembali saat UU diaktifkan.
        
        UPDATE pasal
        SET is_active = NEW.is_active,
            updated_at = NOW()
        WHERE undang_undang_id = NEW.id
          AND deleted_at IS NULL; -- KUNCI PERBAIKAN: Hanya update yang belum dihapus

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 2. Data Fix (Pembersihan Data Lama)
--    Pastikan semua pasal yang ada di sampah (deleted_at IS NOT NULL)
--    statusnya benar-benar non-aktif (is_active = false).
--    Ini memperbaiki data yang mungkin sudah terlanjur salah karena bug sebelumnya.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    count_fixed INTEGER;
BEGIN
    UPDATE pasal
    SET is_active = false
    WHERE deleted_at IS NOT NULL
      AND is_active = true;
      
    GET DIAGNOSTICS count_fixed = ROW_COUNT;
    
    RAISE NOTICE 'Fixed % soft-deleted pasal that were incorrectly active.', count_fixed;
END $$;