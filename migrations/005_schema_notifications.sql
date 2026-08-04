-- =====================================================================
-- 005_schema_notifications.sql
-- Functional per-user notification inbox.
-- =====================================================================

CREATE TABLE IF NOT EXISTS notifications (
    id          CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
