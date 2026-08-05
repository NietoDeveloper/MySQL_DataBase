-- =====================================================================
-- 005_schema_notifications.sql
-- Functional per-user notification inbox.
-- =====================================================================

CREATE TABLE IF NOT EXISTS notifications (
    id          CHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    user_id     CHAR(36) NOT NULL,
    type        VARCHAR(96) NOT NULL,   -- e.g. 'order.shipped', 'system.alert'
    title       VARCHAR(255) NOT NULL,
    body        TEXT,
    metadata    JSON NOT NULL DEFAULT (JSON_OBJECT()),
    read_at     DATETIME NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_notifications_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE INDEX idx_notifications_user_unread ON notifications (user_id, read_at);
