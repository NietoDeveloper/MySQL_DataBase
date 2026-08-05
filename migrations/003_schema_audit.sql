-- =====================================================================
-- 003_schema_audit.sql
-- Functional audit trail. Captures who changed what, when, and how.
-- Unlike Postgres' to_jsonb(NEW)/to_jsonb(OLD), MySQL triggers have no
-- generic row-to-JSON cast, so the JSON payload is built explicitly,
-- per table, inside each trigger in 007_triggers.sql.
-- =====================================================================

CREATE IND