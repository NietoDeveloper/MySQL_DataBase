-- =====================================================================
-- 011_auth_surface.sql
-- Registration and login are structurally different from every other
-- operation in this schema: they happen BEFORE the caller has an
-- authenticated identity, so they cannot be scoped by
-- @app_current_user_id the way v_my_profile and friends are (see
-- 009_security_hardening.sql). Giving app_rw broad SELECT/INSERT on
-- the base `users` table to solve that would defeat the point of the
-- row-scoped views entirely.
--
-- Instead: two narrow, purpose-built views that expose exactly the
-- columns an auth flow needs and nothing else — no direct grant on
-- `users` itself.
-- =====================================================================

-- Login/registration lookup — SELECT only, deliberately not filtered
-- by @app_current_user_id (a login flow searches by email across all
-- accounts by definition). Excludes nothing sensitive that the app
-- doesn't already need: password_hash is required to verify a login.
CREATE OR REPLACE VIEW v_auth_lookup AS
    SELECT id, email, username, password_hash, full_name,
           is_active, is_verified, failed_login_attempts, locked_until
    FROM users
    WHERE deleted_at IS NULL;

-- Registration — INSERT only, restricted to exactly the columns a
-- sign-up form should be able to set. Notably absent: is_active,
-- is_verified, failed_login_attempts, locked_until — a caller cannot
-- self-verify or self-unlock an account through this view even if the
-- INSERT statement tries to set them, because they're not exposed.
CREATE OR REPLACE VIEW v_auth_registration AS
    SELECT id, email, username, password_hash, full_name
    FROM users;

GRANT SELECT ON v_auth_lookup      TO app_rw, app_ro;
GRANT SELECT, INSERT ON v_auth_registration TO app_rw;
