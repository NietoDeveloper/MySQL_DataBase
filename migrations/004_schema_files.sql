-- =====================================================================
-- 004_schema_files.sql
-- Functional polymorphic attachments table — link a file (stored in
-- S3, local disk, etc.) to any record in any table without a
-- dedicated join table per entity.
-- =====================================================================

CREATE TABLE IF NOT EXISTS attachments (
    id            CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    owner_table   VARCHAR(64) NOT NULL,   -- e.g. 'users', 'orders'
 