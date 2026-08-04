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
    ip_address         VARCHAR(45),          -- IPv4 or IPv6 text form
    expires_at         DATETIME NOT NULL,


    CONSTRAINT uq_sessions_token_hash UNIQUE (refresh_token_hash),
    CONSTRAINT fk_sessions_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT chk_sessions_token_hash_len
        CHECK (CHAR_LENGTH(refresh_token_hash) = 64)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE INDEX idx_sessions_user_id ON sessions (user_id);
CREATE INDEX idx_sessions_expires ON sessions (expires_at);
CREATE INDEX idx_sessions_active  ON sessions (user_id, revoked_at);
