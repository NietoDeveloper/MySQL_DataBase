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
  of Postgres `SECURITY DEFINER`), so `app_rw` can trigger a write
  indirectly without holding the underlying privilege itself.
- **Table-specific audit triggers.** Unlike Postgres' generic
  `to_jsonb(NEW)`, MySQL triggers have no row-to-JSON cast, so the audit
  trigger is written explicitly per table (see `007_triggers_procedures.sql`,
  wired onto `users`). Wire additional tables by copying the three
  trigger stubs and adjusting the `JSON_OBJECT(...)` column list —
  it does not happen automatically for new tables.
- **Hashed session tokens.** `sessions.refresh_token_hash` stores a
  SHA-256 (or stronger) hash computed by the application — never the
  raw refresh token. A leaked backup does not leak usable sessions.
- **Brute-force lockout.** `users.failed_login_attempts` /
  `users.locked_until`, managed via `register_failed_login()`,
  `register_successful_login()`, and `is_account_locked()` — call these
  instead of writing to the columns directly so the lockout policy stays
  in one place.
- **Data-shape constraints.** `CHECK` constraints (MySQL 8.0.16+,
  actually enforced — earlier versions silently ignore them) on email
  format, username length, and password-hash length catch obviously
  malformed data before it lands in the table. Defense in depth, not a
  substitute for application-level validation.
- **Per-account resource limits.** `scripts/create_app_role.sh` sets
  `MAX_USER_CONNECTIONS` on `app_user` so one misbehaving service can't
  exhaust every connection slot.

## What's genuinely different from the PostgreSQL edition of this project

| Concern | PostgreSQL | MySQL (this repo) |
|---|---|---|
| Row-level security | Native `ROW LEVEL SECURITY` + `POLICY`, enforced per-transaction | Filtered updatable views + a connection-scoped session variable — weaker isolation, documented above |
| Generic audit trigger | One function (`to_jsonb(NEW)`) reused on any table | Per-table triggers with an explicit column list |
| `SET LOCAL` (per-transaction context) | Yes | No — MySQL session variables persist for the connection, not just the transaction |
| Statement/idle timeouts per role | `ALTER ROLE ... SET statement_timeout` | No per-role equivalent; enforce at the connection-pool/driver layer instead (see below) |

## What you still need to do

- **Never commit real credentials.** `.env.example` ships with empty
  passwords on purpose — generate strong ones (`openssl rand -base64 32`)
  per environment and keep `.env` out of version control (already in
  `.gitignore`).
- **Require TLS in any non-local environment.** Add
  `--ssl-mode=REQUIRED` (or `VERIFY_IDENTITY` with a CA bundle) to every
  connection once this database isn't running on `localhost`.
- **Enforce statement/idle timeouts at the connection-pool or driver
  layer.** MySQL has no per-role `statement_timeout`; set it in your
  ORM/driver config (e.g. `mysql2`'s `connectTimeout`, or a proxy like
  ProxySQL) instead.
- **Reset `@app_current_user_id` on every pooled-connection checkout** —
  see the RLS caveat above. This is the single most important operational
  rule in this document.
- **Rotate `APP_DB_PASSWORD` periodically** by re-running
  `scripts/create_app_role.sh` with a new value.
- **Don't publish the MySQL port publicly.** `docker-compose.yml` binds
  to `127.0.0.1` by default — keep it that way unless you have a
  specific, firewalled reason not to.
- **Consider enabling the `validate_password` component** on the server
  for any environment that allows password-based account creation
  outside this repo's scripted flow.
- **Extend the audit trigger set deliberately.** It's opt-in per table
  by design — copying it onto every table "just in case" adds write
  overhead without adding safety.



















- **Least-privilege roles.** `009_security_hardening.sql` creates
  `app_rw` (read/write, for the application), `app_ro` (read-only, for
  reporting/analytics), and `app_admin` (back-office bypass). MySQL's
  privilege model is allow-list by default — a fresh role starts with
  zero privileges, no explicit "revoke from PUBLIC" step needed.
  `scripts/create_app_role.sh` creates the actual `app_user` 
- **Row-scoped access viviews, not native RLS.** MySQL has no
  Row-Level Security feature. The closest practical equivalent here is
  _my_noatch tnderlying `users` / `sessions` / `notifications` /
  `user_settings` tables direc Your application must run
  `SET @app_current_user_id = '<uuid>';` at the start of each
  connection/request, before any read or write against those views.
  **Read this carefully: this is weaker than Postres RLS.** A session
  variable is connection-scoped, not transaction-scoped like Postgres'
  `SET LOCAL`, so a pooled connection that forgets to reset the variable
  between requests can leak context across users. If you use a
  connection pool, reset (`SET @app_current_user_id = NULL;`) or
  re-assert it on every checkout, and treat this as a second layer —
 `app_rw` — `UPDATE` and `DELETE` are simply never granted to any
