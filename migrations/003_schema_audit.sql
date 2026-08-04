-- =====================================================================
-- 003_schema_audit.sql
-- Functional audit trail. Captures who changed what, when, and how.
-- Unlike Postgres' to_jsonb(NEW)/to_jsonb(OLD), MySQL triggers have no
-- generic row-to-JSON cast, so the JSON payload is built explicitly,
-- per table, inside each trigger in 007_triggers.sql.
-- =====================================================================

CREATE TABLE IF NOT EXISTS audit_log (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    table_name   VARCHAR(64) NOT NULL,
    record_id    VARCHAR(64) NOT NULL,


    changed_by   CHAR(36) NULL,
    changed_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,


