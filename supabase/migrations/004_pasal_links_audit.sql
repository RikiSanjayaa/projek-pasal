-- ============================================================================
-- Migration: Add audit trigger for pasal_links
-- Versi: 1.0.1
-- Tanggal: 2025-12-13
-- Deskripsi: Menambahkan audit log trigger untuk tabel pasal_links
-- ============================================================================

-- Trigger untuk audit log pada tabel pasal_links
CREATE TRIGGER tr_pasal_links_audit
    AFTER INSERT OR UPDATE OR DELETE ON pasal_links
    FOR EACH ROW EXECUTE FUNCTION log_audit();

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
