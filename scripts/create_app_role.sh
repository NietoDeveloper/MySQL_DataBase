#!/usr/bin/env bash
# Creates (or rotates the password of) the least-privilege LOGIN account

set -euo pipefail

: "${MYSQL_HOST:?Set MYSQL_HOST}"
: "${MYSQL_PORT:?Set MYSQL_PORT}"
: "${MYSQL_USER:?Set MYSQL_USER (bootstrap/admin account)}"
: "${MYSQL_PASSWORD:?Set MYSQL_PASSWORD}"
: "${MYSQL_DATABASE:?Set MYSQL_DATABASE}"
: "${APP_DB_PASSWORD:?Set APP_DB_PASSWORD to a strong, generated password for app_user}"

mysql --host="$MYSQL_HOST" --port="$MYSQL_PORT" --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" <<SQL
CREATE USER IF NOT EXISTS 'app_user'@'%'

         MAX_UPDATES_PER_HOUR 0;
ALTER USER 'app_user'@'%' IDENTIFIED BY '${APP_DB_PASSWORD}';
GRANT app_rw TO 'app_user'@'%';
SET DEFAULT ROLE app_rw TO 'app_user'@'%';
FLUSH PRIVILEGES;
SQL

echo "app_user is ready (default role app_rw). Rotate APP_DB_PASSWORD periodically."
