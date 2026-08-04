-- =====================================================================
-- 009_security_hardening.sql
-- Defense-in-depth layer: least-privilege roles, row-scoped views
-- (MySQL has no native Row-Level Security — see docs/SECURITY.md for

-- =====================================================================
should never
--    connect as the migration/owner account.
CREATE ROLE IF NOT EXISTS app_rw;
CREATE ROLE IF NOT EXISTS app_ro;


-- 3) Admin/bad audit triggers to the roles
--    that legitimately need them.
GRANT EXECUTE ON PROCEDURE register_failed_login     TO app_rw, app_admin;
GRANT EXECUTE ON PROCEDURE register_successful_login TO app_rw, app_admin;
GRANT EXECUTE ON FUNCTION  is_account_locked         TO app_rw, app_ro, app_admin;

FLUSH PRIVILEGES;
