-- =====================================================================
CREATE TABLE IF NOT EXISTS users (
    id                    CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    email                 VARCHAR(255) NOT NULL,
    username              VARCHAR(32),
    password_hash         VARCHAR(255) NOT NULL,
    full_name             VARCHAR(150),
    is_active             BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at         DATETIME NULL,
    CONSTRAINT uq_users_email    UNIQUE (email),
 -- do not rely on this instead of application-level validation).
    CONSTRAINT chk_users_email_format
        CHECK (email REGEXP '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$'),
  -- Rejects empty/placeholder hashes; does not validate the hashing
 TABLE IF NOT EXISTS permissions (
    id          SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    code        VARCHAR(96) NOT NULL,   -- e.g. 'users.read', 'orders.write'
    description VARCHAR(255),

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
