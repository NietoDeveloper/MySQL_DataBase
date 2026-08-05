# Security Hardening Notes

This schema ships with a set of security defaults baked in. This document
explains what they are, what's genuinely different from a Postgres
equivalent, and what still depends on you / your deployment environment.

## What's enforced at the database layer

- **Least-privilege roles.** `009_security_hardening.sql` creates
  `app_rw` (read/write, for the application), `app_ro` (read-only, for
  reporting/analytics), and `app_admin` (back-office bypass). MySQL's
  privilege model is allow-list by default — a fresh role starts with
  zero privileges, no explicit "revoke from PUBLIC" step needed.
  `scripts/create_app_role.sh` creates the actual `app_user` account and
  gives it the `app_rw` role. **The application should never connect
  using the Docker bootstrap/root account** — that account exists only
  to run migrations.
- **Row-scoped access via views, not native RLS.** MySQL has no
  Row-Level Security feature. The closest practical equivalent here is
  four updatable views — `v_my_profile`, `v_my_sessions`,
  `v_my_notifications`, `v_my_settings` — each filtered by a session
  variable (`@app_current_user_id`) and created `WITH CASCADED CHECK
  OPTION` so INSERT/UPDATE through the view is rejected if the row
  wouldn't match the filter. `app_rw` is granted access to the views,
  **not** the underlying `users` / `sessions` / `notifications` /
  `user_settings` tables directly. Your application must run
  `SET @app_current_user_id = '<uuid>';` at the start of each
  connection/request, before any read or write against those views.
  **Read this carefully: this is weaker than Postgres RLS.** A session
  variable is connection-scoped, not transaction-scoped like Postgres'
  `SET LOCAL`, so a pooled connection that forgets to reset the variable
  between requests can leak context across users. If you use a
  connection pool, reset (`SET @app_current_user_id = NULL;`) or
  re-assert it on every checkout, and treat this as a second layer —
  the application layer remains the primary access-control boundary,
  not a replacement for it.
- **Append-only audit log.** `audit_log` grants `SELECT, INSERT` only to
  `app_rw` — `UPDATE` and `DELETE` are simply never granted to any
  application role. Rows are only ever written by the
  `trg_users_audit_*` triggers, which execute with **definer**
  privileges (MySQL's default for triggers/procedures — the equivalent
