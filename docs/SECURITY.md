Rotate `APP_DB_PASSWORD` periodically** by re-running
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
