-- ============================================================================
-- Migration: Audit Logs Retention Policy
-- Versi: 1.0.0
-- Tanggal: 2025-01-02
-- Deskripsi: Menambahkan fungsi untuk membersihkan audit logs lama
-- ============================================================================

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
-- Default retention: 6 months (180 days)
-- Can be adjusted when calling the function

-- ============================================================================
-- FUNCTION: cleanup_old_audit_logs
-- Deskripsi: Menghapus audit logs yang lebih tua dari N hari
-- ============================================================================
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs(
    retention_days INTEGER DEFAULT 180  -- 6 months default
)
RETURNS TABLE(
    deleted_count BIGINT,
    oldest_remaining TIMESTAMPTZ,
    execution_time_ms NUMERIC
) AS $$
DECLARE
    start_time TIMESTAMPTZ;
    end_time TIMESTAMPTZ;
    cutoff_date TIMESTAMPTZ;
    rows_deleted BIGINT;
    oldest_log TIMESTAMPTZ;
BEGIN
    start_time := clock_timestamp();
    cutoff_date := NOW() - (retention_days || ' days')::INTERVAL;
    
    -- Delete old audit logs in batches to avoid long locks
    -- Using a CTE to limit rows per execution if needed
    DELETE FROM audit_logs
    WHERE created_at < cutoff_date;
    
    GET DIAGNOSTICS rows_deleted = ROW_COUNT;
    
    -- Get the oldest remaining log timestamp
    SELECT MIN(created_at) INTO oldest_log FROM audit_logs;
    
    end_time := clock_timestamp();
    
    RETURN QUERY SELECT 
        rows_deleted,
        oldest_log,
        ROUND(EXTRACT(EPOCH FROM (end_time - start_time)) * 1000, 2);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_old_audit_logs IS 
'Menghapus audit logs yang lebih tua dari retention_days (default: 180 hari / 6 bulan).
Dapat dipanggil manual atau dijadwalkan via pg_cron.

Contoh penggunaan:
- SELECT * FROM cleanup_old_audit_logs();           -- Hapus > 6 bulan
- SELECT * FROM cleanup_old_audit_logs(90);         -- Hapus > 90 hari
- SELECT * FROM cleanup_old_audit_logs(365);        -- Hapus > 1 tahun

Return: jumlah record dihapus, timestamp log tertua yang tersisa, waktu eksekusi (ms)';

-- ============================================================================
-- FUNCTION: get_audit_logs_stats
-- Deskripsi: Mendapatkan statistik ukuran dan distribusi audit logs
-- ============================================================================
CREATE OR REPLACE FUNCTION get_audit_logs_stats()
RETURNS TABLE(
    total_count BIGINT,
    oldest_log TIMESTAMPTZ,
    newest_log TIMESTAMPTZ,
    logs_last_7_days BIGINT,
    logs_last_30_days BIGINT,
    logs_last_90_days BIGINT,
    logs_older_than_180_days BIGINT,
    estimated_size_mb NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::BIGINT as total_count,
        MIN(created_at) as oldest_log,
        MAX(created_at) as newest_log,
        COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days')::BIGINT as logs_last_7_days,
        COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '30 days')::BIGINT as logs_last_30_days,
        COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '90 days')::BIGINT as logs_last_90_days,
        COUNT(*) FILTER (WHERE created_at < NOW() - INTERVAL '180 days')::BIGINT as logs_older_than_180_days,
        ROUND(pg_total_relation_size('audit_logs') / 1024.0 / 1024.0, 2) as estimated_size_mb
    FROM audit_logs;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_audit_logs_stats IS 
'Mendapatkan statistik audit logs: jumlah total, distribusi umur, dan estimasi ukuran.
Berguna untuk monitoring sebelum menjalankan cleanup.

Contoh: SELECT * FROM get_audit_logs_stats();';

-- ============================================================================
-- pg_cron scheduled job
-- ============================================================================
-- pg_cron harus diaktifkan di Supabase Dashboard > Database > Extensions

-- Jalankan cleanup setiap hari jam 3 pagi (UTC)
SELECT cron.schedule(
    'cleanup-audit-logs-daily',           -- job name
    '0 3 * * *',                           -- cron schedule (3 AM UTC daily)
    $$SELECT cleanup_old_audit_logs(180)$$ -- 6 months retention
);

-- Untuk melihat scheduled jobs:
-- SELECT * FROM cron.job;

-- Untuk menghapus scheduled job:
-- SELECT cron.unschedule('cleanup-audit-logs-daily');

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
