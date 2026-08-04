-- =====================================================================
-- 007_triggers_procedures.sql
-- Reusable procedures/functions + the audit trigger set for `users`.
count, not the application role.
-- =====================================================================



CREATE TRIGGER trg_users_audit_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, record_id, action, old_data, new_data, changed_by)
    VALUES (
        'users_active', OLD.is_active, 'is_verified', OLD.is_verified,
            'deleted_at', OLD.deleted_at
        ),ted_at', NEW.deleted_at


CREATE TRIGGER trg_users_audit_delete
AFTER DELETE ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, record_id, action, old_data, changed_by)
    VALUES (
        'users', OLD.id, 'DELETE',
        JSON_OBJECT(
            'id', OLD.id, 'email', OLD.email, 'username', OLD.username,
            'full_name', OLD.full_name
        ),
        NULLIF(@app_current_user_id, '')
    );
END$$

DELIMITER ;
