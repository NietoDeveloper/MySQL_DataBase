-- =====================================================================
CREATE TABLE IF NOT EXISTS users (
    id                    CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    email                 VARCHAR(255) NOT NULL,
    username              VARCHAR(32),
    password_hash         VARCHAR(255) NOT NULL,
    full_name             VARCHAR(150),
    is_active             BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at         DATETIME NULL,
    CONSTRAINT uq_users_email    UNIQUE 