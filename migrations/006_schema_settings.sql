-- =====================================================================
-- 006_schema_settings.sql
-- Functional key/value configuration store — global app settings and
-- per-user preferences, without needing a new table per feature.
-- =====================================================================

CREATE TABLE IF NOT EXISTS app_settings (
    `key`       VARCHAR(128) NOT NULL PRIMARY KEY,
    value       JSON NOT NULL,
    updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS user_settings (
    user_id     CHAR(36) NOT NULL,
    `key`       VARCHAR(128) NOT NULL,
    value       JSON NOT NULL,
    updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, `key`),
    CONSTRAINT fk_user_settings_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
