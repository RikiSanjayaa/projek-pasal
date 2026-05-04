<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement("DO $$ BEGIN CREATE TYPE admin_role AS ENUM ('admin', 'super_admin'); EXCEPTION WHEN duplicate_object THEN NULL; END $$");
        DB::statement("DO $$ BEGIN CREATE TYPE audit_action AS ENUM ('CREATE', 'UPDATE', 'DELETE', 'RESTORE', 'LOGIN', 'LOGOUT', 'IMPORT', 'SYNC'); EXCEPTION WHEN duplicate_object THEN NULL; END $$");

        DB::statement(<<<'SQL'
            CREATE TABLE admin_users (
                id UUID PRIMARY KEY,
                email VARCHAR(255) UNIQUE NOT NULL,
                password VARCHAR(255) NOT NULL,
                nama VARCHAR(255) NOT NULL,
                role admin_role NOT NULL DEFAULT 'admin',
                is_active BOOLEAN NOT NULL DEFAULT true,
                last_login_at TIMESTAMPTZ,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW(),
                deleted_at TIMESTAMPTZ
            )
        SQL);

        DB::statement(<<<'SQL'
            CREATE TABLE undang_undang (
                id UUID PRIMARY KEY,
                kode VARCHAR(50) UNIQUE NOT NULL,
                nama VARCHAR(255) NOT NULL,
                nama_lengkap TEXT,
                deskripsi TEXT,
                tahun INTEGER,
                is_active BOOLEAN NOT NULL DEFAULT true,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW(),
                deleted_at TIMESTAMPTZ
            )
        SQL);

        DB::statement(<<<'SQL'
            CREATE TABLE pasal (
                id UUID PRIMARY KEY,
                undang_undang_id UUID NOT NULL REFERENCES undang_undang(id) ON DELETE CASCADE,
                nomor VARCHAR(100) NOT NULL,
                judul VARCHAR(500),
                isi TEXT NOT NULL,
                penjelasan TEXT,
                keywords TEXT[] NOT NULL DEFAULT '{}',
                search_vector TSVECTOR,
                is_active BOOLEAN NOT NULL DEFAULT true,
                created_by UUID REFERENCES admin_users(id),
                updated_by UUID REFERENCES admin_users(id),
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW(),
                deleted_at TIMESTAMPTZ,
                CONSTRAINT unique_pasal_per_uu UNIQUE(undang_undang_id, nomor)
            )
        SQL);

        DB::statement(<<<'SQL'
            CREATE TABLE pasal_links (
                id UUID PRIMARY KEY,
                source_pasal_id UUID NOT NULL REFERENCES pasal(id) ON DELETE CASCADE,
                target_pasal_id UUID NOT NULL REFERENCES pasal(id) ON DELETE CASCADE,
                keterangan TEXT,
                is_active BOOLEAN NOT NULL DEFAULT true,
                created_by UUID REFERENCES admin_users(id),
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW(),
                deleted_at TIMESTAMPTZ,
                CONSTRAINT unique_pasal_link UNIQUE(source_pasal_id, target_pasal_id),
                CONSTRAINT no_self_link CHECK (source_pasal_id != target_pasal_id)
            )
        SQL);

        DB::statement(<<<'SQL'
            CREATE TABLE mobile_users (
                id UUID PRIMARY KEY,
                email VARCHAR(255) UNIQUE NOT NULL,
                password VARCHAR(255) NOT NULL,
                nama VARCHAR(255) NOT NULL,
                is_active BOOLEAN NOT NULL DEFAULT true,
                expires_at TIMESTAMPTZ,
                last_login_at TIMESTAMPTZ,
                created_by_admin_id UUID REFERENCES admin_users(id),
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW(),
                deleted_at TIMESTAMPTZ
            )
        SQL);

        DB::statement(<<<'SQL'
            CREATE TABLE user_devices (
                id UUID PRIMARY KEY,
                mobile_user_id UUID NOT NULL REFERENCES mobile_users(id) ON DELETE CASCADE,
                device_id VARCHAR(255) NOT NULL,
                device_name VARCHAR(255),
                platform VARCHAR(50),
                is_active BOOLEAN NOT NULL DEFAULT true,
                last_active_at TIMESTAMPTZ DEFAULT NOW(),
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW(),
                CONSTRAINT unique_mobile_user_device UNIQUE(mobile_user_id, device_id)
            )
        SQL);

        DB::statement(<<<'SQL'
            CREATE TABLE admin_devices (
                id UUID PRIMARY KEY,
                admin_user_id UUID NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
                device_id VARCHAR(255) NOT NULL,
                device_alias VARCHAR(255),
                device_name VARCHAR(255),
                user_agent TEXT,
                ip_address INET,
                is_active BOOLEAN NOT NULL DEFAULT true,
                last_active_at TIMESTAMPTZ DEFAULT NOW(),
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW(),
                CONSTRAINT unique_admin_device UNIQUE(admin_user_id, device_id)
            )
        SQL);

        DB::statement(<<<'SQL'
            CREATE TABLE audit_logs (
                id UUID PRIMARY KEY,
                admin_id UUID REFERENCES admin_users(id),
                admin_email VARCHAR(255),
                actor_type VARCHAR(50),
                actor_id UUID,
                action audit_action NOT NULL,
                table_name VARCHAR(100) NOT NULL,
                record_id UUID,
                old_data JSONB,
                new_data JSONB,
                metadata JSONB,
                ip_address INET,
                user_agent TEXT,
                created_at TIMESTAMPTZ DEFAULT NOW()
            )
        SQL);

        foreach ([
            'CREATE INDEX idx_admin_users_email ON admin_users(email)',
            'CREATE INDEX idx_admin_users_active ON admin_users(is_active)',
            'CREATE INDEX idx_undang_undang_kode ON undang_undang(kode)',
            'CREATE INDEX idx_undang_undang_active ON undang_undang(is_active)',
            'CREATE INDEX idx_pasal_undang_undang ON pasal(undang_undang_id)',
            'CREATE INDEX idx_pasal_nomor ON pasal(nomor)',
            'CREATE INDEX idx_pasal_active ON pasal(is_active)',
            'CREATE INDEX idx_pasal_deleted_at ON pasal(deleted_at)',
            'CREATE INDEX idx_pasal_search ON pasal USING GIN(search_vector)',
            'CREATE INDEX idx_pasal_keywords ON pasal USING GIN(keywords)',
            'CREATE INDEX idx_pasal_links_source ON pasal_links(source_pasal_id)',
            'CREATE INDEX idx_pasal_links_target ON pasal_links(target_pasal_id)',
            'CREATE INDEX idx_pasal_links_active ON pasal_links(is_active)',
            'CREATE INDEX idx_mobile_users_email ON mobile_users(email)',
            'CREATE INDEX idx_mobile_users_active ON mobile_users(is_active)',
            'CREATE INDEX idx_mobile_users_expires ON mobile_users(expires_at)',
            'CREATE INDEX idx_user_devices_user ON user_devices(mobile_user_id)',
            'CREATE INDEX idx_user_devices_device ON user_devices(device_id)',
            'CREATE INDEX idx_admin_devices_admin ON admin_devices(admin_user_id)',
            'CREATE INDEX idx_admin_devices_device ON admin_devices(device_id)',
            'CREATE INDEX idx_audit_logs_admin ON audit_logs(admin_id)',
            'CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_type, actor_id)',
            'CREATE INDEX idx_audit_logs_table ON audit_logs(table_name)',
            'CREATE INDEX idx_audit_logs_record ON audit_logs(record_id)',
            'CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC)',
        ] as $statement) {
            DB::statement($statement);
        }

        DB::statement(<<<'SQL'
            CREATE OR REPLACE FUNCTION caripasal_update_updated_at()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.updated_at = NOW();
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql
        SQL);

        foreach (['admin_users', 'undang_undang', 'pasal', 'pasal_links', 'mobile_users', 'user_devices', 'admin_devices'] as $table) {
            DB::statement("CREATE TRIGGER {$table}_updated_at BEFORE UPDATE ON {$table} FOR EACH ROW EXECUTE FUNCTION caripasal_update_updated_at()");
        }

        DB::statement(<<<'SQL'
            CREATE OR REPLACE FUNCTION caripasal_update_pasal_search_vector()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.search_vector =
                    setweight(to_tsvector('simple', coalesce(NEW.nomor, '')), 'A') ||
                    setweight(to_tsvector('simple', coalesce(NEW.judul, '')), 'B') ||
                    setweight(to_tsvector('simple', coalesce(NEW.isi, '')), 'C') ||
                    setweight(to_tsvector('simple', coalesce(NEW.penjelasan, '')), 'D');
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql
        SQL);
        DB::statement('CREATE TRIGGER pasal_search_vector_trigger BEFORE INSERT OR UPDATE ON pasal FOR EACH ROW EXECUTE FUNCTION caripasal_update_pasal_search_vector()');
    }

    public function down(): void
    {
        DB::statement('DROP TABLE IF EXISTS audit_logs CASCADE');
        DB::statement('DROP TABLE IF EXISTS admin_devices CASCADE');
        DB::statement('DROP TABLE IF EXISTS user_devices CASCADE');
        DB::statement('DROP TABLE IF EXISTS mobile_users CASCADE');
        DB::statement('DROP TABLE IF EXISTS pasal_links CASCADE');
        DB::statement('DROP TABLE IF EXISTS pasal CASCADE');
        DB::statement('DROP TABLE IF EXISTS undang_undang CASCADE');
        DB::statement('DROP TABLE IF EXISTS admin_users CASCADE');
        DB::statement('DROP FUNCTION IF EXISTS caripasal_update_pasal_search_vector CASCADE');
        DB::statement('DROP FUNCTION IF EXISTS caripasal_update_updated_at CASCADE');
        DB::statement('DROP TYPE IF EXISTS audit_action CASCADE');
        DB::statement('DROP TYPE IF EXISTS admin_role CASCADE');
    }
};
