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

    CONSTRAINT fk_attachments_uploaded_by
        FOREIGN KEY (uploaded_by) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT chk_attachments_size
        CHECK (size_bytes IS NULL OR size_bytes <= 104857600) -- 100MB ceiling
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE INDEX idx_attachments_owner ON attachments (owner_table, owner_id);
