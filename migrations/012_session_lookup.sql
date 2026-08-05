-- =====================================================================
-- 012_session_lookup.sql
-- Refresh-token verification has the same structural problem as login
-- (011_auth_surface.sql): the caller doesn't know their own user_id
-- yet — they only hold an opaque refresh token — so the lookup cannot
-- be scoped by @app_current_user_id the way v_my_sessions is. This
-- narrow, SELECT-only view exposes exactly what a refresh/logout flow
-- needs to find a session by its token hash, without granting app_rw
-- direct access to the `sessions` table.
--
-- Once the caller's user_id is known from this lookup, actually
-- creating or revoking a session goes back through v_my_sessions under
-- withUserContext() — see client/src/queries.ts — so mutation stays
-- row-scoped even though this one lookup step cannot be.
-- =====================================================================

CREATE OR REPLACE VIEW v_session_lookup AS
    SELECT id, user_id, refresh_token_hash, expires_at, revoked_at, created_at
    FROM sessions;

GRANT SELECT ON v_session_lookup TO app_rw, app_ro;
