   locked_until = CASE
            WHEN failed_login_attempts + 1 >= p_max_attempts
                THEN DATE_ADD(NOW(), INTERVAL p_lock_minutes MINUTE)
            ELSE locked_until
        END
    WHERE id = p_user_id;
END$$

CREATE PROCEDURE register_successful_login(IN p_user_id CHAR(36))
BEGIN
    UPDATE users
    SET failed_login_attempts = 0,
        locked_until = NULL,
        last_login_at = NOW()
    WHERE id = p_user_id;
END$$

CREATE FUNCTION is_account_locked(p_user_id CHAR(36))
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_locked_until DATETIME;
    SELECT locked_until INTO v_locked_until FROM users WHERE id = p_user_id;
    RETURN v_locked_until IS NOT NULL AND v_locked_until > NOW();
END$$

-- 2) Soft-delete helper — call instead of DELETE to preserve history.
CREATE PROCEDURE soft_delete_user(IN p_user_id CHAR(36))
BEGIN
    UPDATE users SET deleted_at = NOW() WHERE id = p_user_id AND deleted_at IS NULL;
END$$

-- 3) Audit trigger set for `users`. Copy this pattern per table you
--    want audited — see the note above.
CREATE TRIGGER trg_users_audit_insert
AFTER INSERT ON users
FOR EACH ROW
BEGIN
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
