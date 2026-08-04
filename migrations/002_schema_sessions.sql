-- =====================================================================
-- 002_schema_sessions.sql
-- Auth sessions. The raw refresh token is NEVER stored — only a
-- SHA-256 (or stronger) hash of it, computed at the application layer.
-- A leaked database backup therefore does not leak usable session
-- tokens.
-- =====================================================================

CREATE TABLE IF NOT EXISTS sessions (
    id                 CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
s