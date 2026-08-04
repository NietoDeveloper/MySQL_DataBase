-- =====================================================================
-- 004_schema_files.sql
-- Functional polymorphic attachments table — link a file (stored in
-- S3, local disk, etc.) to any record in any table without a
-- dedicated join table per entity.
-- =====================================================================

CREATE TABLE IF NOT EXISTS attachments (
    id            CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    owner_table   VARCHAR(64) NOT NULL,   -- e.g. 'users', 'orders'
    owner_id      VARCHAR(64) NOT NULL,   -- polymorphic FK (cast as needed)
    file_name     VARCHAR(255) NOT NULL,
    file_url      VARCHAR(2048) NOT NULL,
    mime_type     VARCHAR(127),
    size_bytes    BIGINT UNSIGNED,
    uploaded_by   CHAR(36) NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at    DATETIME NULL,

CREATE INDEX idx_attachments_owner ON attachments (owner_table, owner_id);
