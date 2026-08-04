-- =====================================================================
-- 002_schema_sessions.sql
-- Auth sessions. The raw refresh token is NEVER stored — only a
-- SHA-256 (or stronger) hash of it, computed at the application layer.
-- A leaked database backup therefore does not leak usable session
-- tokens.
-- =====================================================================

CREATE TABLE IF NOT EXISTS sessions (
    id                 CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    user_id            CHAR(36) NOT NULL,
    refresh_token_hash CHAR(64) NOT NULL,   -- hex-encoded SHA-256 = 64 chars
    user_agent         VARCHAR(255),


    CONSTRAINT uq_sessions_token_hash UNIQUE (refresh_token_hash),
    CONSTRAINT fk_sessions_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT chk_sessions_token_hash_len
