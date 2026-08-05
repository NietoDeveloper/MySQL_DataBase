-- =====================================================================
-- 010_performance_scalability.sql
-- Indexing, housekeeping, and scheduled maintenance aimed at keeping
-- write/read latency flat as tables grow. Safe to run after 001-009.
-- =====================================================================

-- 1) Composite indexes for the query patterns the schema actually
--    supports (auth checks, session cleanup, inbox pagination). A
--    single-column index on a low-selectivity boolean is often
--    useless on its own — pair it with what it's usually filtered
--    alongside.
CREATE INDEX idx_users_email_active
    ON users (email, is_active, deleted_at);

CREATE INDEX idx_sessions_cleanup
    ON sessions (expires_at, revoked_at);

CREATE INDEX idx_notifications_inbox
    ON notifications (user_id, created_at DESC);

CREATE INDEX idx_attachments_owner_created
    ON attachments (owner_table, owner_id, created_at DESC);

-- 2) Housekeeping procedures. Expired sessions and old audit rows are
--    the two tables that grow unbounded by default — prune them on a
--    schedule instead of letting them bloat the buffer pool and slow
--    down every index scan that touches nearby pages.
DELIMITER $$

CREATE PROCEDURE cleanup_expired_sessions()
BEGIN
    DELETE FROM sessions
    WHERE expires_at < NOW()
       OR (revoked_at IS NOT NULL AND revoked_at < DATE_SUB(NOW(), INTERVAL 30 DAY))
    LIMIT 5000; -- bounded batch size: avoids one huge transaction/lock
END$$

-- Archival, not deletion: audit_log is compliance-relevant, so this
-- only trims rows past a retention window you control by calling it
-- with your own value — nothing runs automatically against audit_log.
CREATE PROCEDURE archive_audit_log_older_than(IN p_days INT)
BEGIN
    DELETE FROM audit_log
    WHERE changed_at < DATE_SUB(NOW(), INTERVAL p_days DAY)
    LIMIT 5000;
END$$

DELIMITER ;

-- 3) Scheduled cleanup. Requires the MySQL event scheduler to be on
--    (SET GLOBAL event_scheduler = ON; — already set in
--    docker-compose.yml for the bundled image). Sessions are the only
--    table auto-pruned; audit_log retention is a deliberate, manual
--    call by design (see the procedure above).
CREATE EVENT IF NOT EXISTS ev_cleanup_expired_sessions
    ON SCHEDULE EVERY 1 DAY
    STARTS (TIMESTAMP(CURRENT_DATE) + INTERVAL 1 DAY + INTERVAL 3 HOUR)
    DO CALL cleanup_expired_sessions();

GRANT EXECUTE ON PROCEDURE cleanup_expired_sessions TO app_admin;
GRANT EXECUTE ON PROCEDURE archive_audit_log_older_than TO app_admin;
