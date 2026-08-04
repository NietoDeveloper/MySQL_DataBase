-- =====================================================================
-- 009_security_hardening.sql
-- Defense-in-depth layer: least-privilege roles, row-scoped views
-- (MySQL has no native Row-Level Security — see docs/SECURITY.md for
-- why views + a session variable are the closest equivalent and where
-- that equivalence breaks down), an append-only audit log, and basic

-- =====================================================================

-- 1) Least-privilege roles (MySQL 8.0+). Applications should never
--    connect as the migration/owner account.
CREATE ROLE IF NOT EXISTS app_rw;
CREATE ROLE IF NOT EXISTS app_ro;
CREATE ROLE IF NOT EXISTS app_admin;

-- Baseline: no privileges anywhere until explicitly granted below
-- (MySQL's privilege model is allow-list by default, so there's no
-- REVOKE-everything step equivalent to Postgres' `REVOKE ALL ... FROM
-- PUBLIC` — a fresh role simply starts with nothing).

-- Tables that are NOT row-sE ON permissions      TO app_rw;
 TO app_rw;


-- audit_log is append-only: app_rw gets SELECT + INSERT only. UPDATE,
-- DELETE, and DROP are never granted tgers, which run with the
-- privileges of their DEFINER (the migration account), not the caller.


-- 2) Row-scoped access vpp_user_id(), defined in
--    007_triggers_procedures.sql, since MySQL rejects a raw session
--    variable inside CREATE VIEW). app_rw gets access to the VIEW, not
--    the base table, for these four tables — so a query that "forgets"
--    to set @app_current_user_id sees nothing (fail-closed) instead of
--    every row.
CREATE OR REPLACE VIEW v_my_profile AS
    SELECT * FROM users WHERE id = current_app_user_id()
    WITH CASCADED CHECK OPTION;

CREATE OR REPLACE VIEW v_my_sessions AS
    SELECT * FROM sessions WHERE user_id = current_app_user_id()
    WITH CASCADED CHECK OPTION;

CREATE OR REPLACE VIEW v_my_notifications AS
    SELECT * FROM notifications WHERE user_id = current_app_user_id()
    WITH CASCADED CHECK OPTION;

CREATE OR REPLACE VIEW v_my_settings AS
    SELECT * FROM user_settings WHERE user_id = current_app_user_id()
    WITH CASCADED CHECK OPTION;

GRANT SELECT, INSERT, UPDATE, DELETE ON v_my_profile       TO app_rw;
GRANT SELECT, INSERT, UPDATE, DELETE ON v_my_sessions       TO app_rw;
GRANT SELECT, INSERT, UPDATE, DELETE ON v_my_notifications  TO app_rw;
GRANT SELECT, INSERT, UPDATE, DELETE ON v_my_settings        TO app_rw;
GRANT SELECT ON v_my_profile      TO app_ro;
GRANT SELECT ON v_my_sessions      TO app_ro;
GRANT SELECT ON v_my_notifications TO app_ro;
GRANT SELECT ON v_my_settings      TO app_ro;

-- app_rw does NOT get direct grants on users / sessions / notifications /
-- user_settings — it must go through the views above, which is what
-- actually enforces the row scoping.

-- 3) Admin/back-office role — the intentional bypass, scoped to its
--    own role instead of turning row-scoping off globally.
GRANT SELECT, INSERT, UPDATE, DELETE ON users            TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON sessions         TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON notifications    TO app_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_settings    TO app_admin;
GRANT app_rw TO app_admin;

-- 4) Lock the brute-force helpers and audit triggers to the roles
--    that legitimately need them.
GRANT EXECUTE ON PROCEDURE register_failed_login     TO app_rw, app_admin;
GRANT EXECUTE ON PROCEDURE register_successful_login TO app_rw, app_admin;
GRANT EXECUTE ON FUNCTION  is_account_locked         TO app_rw, app_ro, app_admin;

FLUSH PRIVILEGES;
