-- =====================================================================
-- 001_schema_core.sql
-- Core identity & access model: users, roles, permissions (RBAC).
-- Hardened: format/length constraints, brute-force lockout fields.
-- Requires MySQL 8.0.16+ (enforced CHECK constraints) / 8.0+ (UUID()
-- =====================================================================

CREATE TABLE IF NOT EXISTS users (
    id                    CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    email                 VARCHAR(255) NOT NULL,
    username              VARCHAR(32),
    password_hash         VARCHAR(255) NOT NULL,
    full_name             VARCHAR(150),
    is_active             BOOLEAN NOT NULL DEFAULT TRUE,
    is_verified           BOOLEAN NOT NULL DEFAULT FALSE,
    failed_login_attempts SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    locked_until          DATETIME NULL,
    last_login_at         DATETIME NULL,
    created_at            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP,
    deleted_at            DATETIME NULL,

    CONSTRAINT uq_users_email    UNIQUE (email),
    CONSTRAINT uq_users_username UNIQUE (username),

    -- Basic shape validation at the data layer (defense in depth —
    -- do not rely on this instead of application-level validation).
    CONSTRAINT chk_users_email_format
        CHECK (email REGEXP '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$'),
    CONSTRAINT chk_users_username_len
        CHECK (username IS NULL OR CHAR_LENGTH(username) BETWEEN 3 AND 32),
    -- Rejects empty/placeholder hashes; does not validate the hashing
    -- algorithm itself (enforce bcrypt/argon2 in the application layer).
    CONSTRAINT chk_users_password_hash_not_blank
        CHECK (CHAR_LENGTH(password_hash) >= 20)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- utf8mb4_0900_ai_ci is accent- and case-insensitive, so `email` and
-- `username` behave like Postgres CITEXT without extra plumbing.

CREATE INDEX idx_users_deleted_at ON users (deleted_at);
CREATE INDEX idx_users_is_active  ON users (is_active, deleted_at);

CREATE TABLE IF NOT EXISTS roles (
    id          SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(64) NOT NULL,
    description VARCHAR(255),
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_roles_name UNIQUE (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS permissions (
    id          SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    code        VARCHAR(96) NOT NULL,   -- e.g. 'users.read', 'orders.write'
    description VARCHAR(255),
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_permissions_code UNIQUE (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS role_permissions (
    role_id       SMALLINT UNSIGNED NOT NULL,
    permission_id SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_role_permissions_role
        FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE CASCADE,
    CONSTRAINT fk_role_permissions_permission
        FOREIGN KEY (permission_id) REFERENCES permissions (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS user_roles (
    user_id CHAR(36) NOT NULL,
    role_id SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_user_roles_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_user_roles_role
        FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
