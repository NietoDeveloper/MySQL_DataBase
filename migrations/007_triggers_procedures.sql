-- =====================================================================
-- 007_triggers_procedures.sql
-- Reusable procedures/functions + the audit trigger set for `users`.
count, not the application role.
-- =====================================================================



CREATE TRIGGER trg_users_audit_update
AFTER UPDATE ON users
FOR EACH ROW

