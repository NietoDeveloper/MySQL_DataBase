-- =====================================================================
CREATE TABLE IF NOT EXISTS users (
    id                    CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    email                 VARCHAR(255) NOT