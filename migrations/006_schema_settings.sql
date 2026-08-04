-- =====================================================================
-- 006_schema_settings.sql
-- Functional key/value configuration store — global app settings and


CREATE TABLE IF NOT EXISTS app_settings (
    `key`       VARCHAR(128) NOT NULL PRIMARY KEY,
