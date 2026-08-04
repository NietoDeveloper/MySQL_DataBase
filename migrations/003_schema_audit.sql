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
    action       ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    old_data     JSON NULL,

    changed_by   CHAR(36) NULL,
    changed_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_audit_log_changed_by
        FOREIGN KEY (changed_by) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utfmb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE INDEX idx_audit_table_record ON audit_log (table_name, record_id);
CREATE INDEX idx_audit_changed_at   ON audit_log (changed_at);
