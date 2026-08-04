-- =====================================================================
-- 007_triggers_procedures.sql
-- Reusable procedures/functions + the audit trigger set for `users`.
count, not the application role.
-- =====================================================================

DELIMITER $$

-- 0) MySQL views cannot reference a user-defined variable (@var)
--    directly in their SELECT — CREATE VIEW rejects it with error 1351.
--    This tiny wrapper function is the workaround: views call the

    WHERE id = p_user_id;
END$$


-- 3) Audit trigger set for `users`. Copy this pattern per table you

    INSERT INTO audit_log (table_name, record_id, action, new_data, changed_by)
    VALUES (
        'users', NEW.id, 'INSERT',
        JSON_OBJECT(
            'id', NEW.id, 'email', NEW.email, 'username', NEW.username,
            'full_name', NEW.full_name, 'is_active', NEW.is_active,
            'is_verified', NEW.is_verified
        ),
        NULLIF(@app_current_user_id, '')
    );
END$$

CREATE TRIGGER trg_users_audit_update
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, record_id, action, old_data, new_data, changed_by)
    VALUES (
        'users', NEW.id, 'UPDATE',
        JSON_OBJECT(
            'email', OLD.email, 'username', OLD.username, 'full_name', OLD.full_name,
            'is_active', OLD.is_active, 'is_verified', OLD.is_verified,
            'deleted_at', OLD.deleted_at
        ),
        JSON_OBJECT(
            'email', NEW.email, 'username', NEW.username, 'full_name', NEW.full_name,
            'is_active', NEW.is_active, 'is_verified', NEW.is_verified,
            'deleted_at', NEW.deleted_at
        ),
        NULLIF(@app_current_user_id, '')
    );
END$$

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
