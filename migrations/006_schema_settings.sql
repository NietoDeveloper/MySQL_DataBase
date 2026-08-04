-- =====================================================================
-- 006_schema_settings.sql
-- Functional key/value configuration store — global app settings and


CREATE TABLE IF NOT EXISTS app_settings (
    `key`       VARCHAR(128) NOT NULL PRIMARY KEY,
    value       JSON NOT NULL,
    updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP
