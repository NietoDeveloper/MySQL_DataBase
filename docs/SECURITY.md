hat you still need to do

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
